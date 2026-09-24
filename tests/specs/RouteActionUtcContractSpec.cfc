component extends="testbox.system.BaseSpec" output="false" {
  variables.datasource = "fpw";

  function run() {
    describe("Route action UTC timestamp contract", function() {
      it("preserves explicit UTC text without CF or JDBC timezone conversion", function() {
        withClockContext("America/Chicago", "-05:00", function() {
          var clock = queryExecute(
            "SELECT UTC_TIMESTAMP() AS utc_date_value,
                    DATE_FORMAT(UTC_TIMESTAMP(), '%Y-%m-%d %H:%i:%s') AS utc_value,
                    TIMESTAMPDIFF(SECOND, NOW(), UTC_TIMESTAMP()) AS offset_seconds",
            {}, { datasource=variables.datasource }
          );
          var roundTrip = queryExecute(
            "SELECT DATE_FORMAT(CAST(:stamp AS DATETIME), '%Y-%m-%d %H:%i:%s') AS rebound_value",
            { stamp={value=clock.utc_value[1], cfsqltype="cf_sql_varchar"} },
            { datasource=variables.datasource }
          );
          expect(val(clock.offset_seconds[1])).toBe(18000);
          expect(roundTrip.rebound_value[1]).toBe(clock.utc_value[1]);
          var wallPattern = "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$";
          expect(reFind(wallPattern, toString(now()))).toBe(0);
          expect(reFind(wallPattern, toString(clock.utc_date_value[1]))).toBe(0);
        });
      });

      it("preserves existing date-object and nullable parameter behavior", function() {
        withClockContext("America/Chicago", "-05:00", function() {
          var writer = new fpw.api.v1.TripActivityWriterService().init(variables.datasource);
          makePublic(writer, "utcTimestampParameter", "utcTimestampParameterForTest");
          var nativeDate = now();
          var jdbcDate = queryExecute("SELECT UTC_TIMESTAMP() AS utc_date_value",
            {}, {datasource=variables.datasource}).utc_date_value[1];
          for (var dateValue in [nativeDate, jdbcDate]) {
            var parameter = writer.utcTimestampParameterForTest(dateValue);
            expect(parameter.cfsqltype).toBe("cf_sql_timestamp");
            expect(parameter.value).toBe(dateValue);
            expect(parameter.null).toBeFalse();
          }
          var utcValue = "2026-09-23 23:46:00";
          var parameter = writer.utcTimestampParameterForTest(utcValue);
          expect(parameter.cfsqltype).toBe("cf_sql_varchar");
          expect(parameter.value).toBe(utcValue);
          expect(parameter.null).toBeFalse();
          var emptyParameter = writer.utcTimestampParameterForTest("", true);
          expect(emptyParameter.cfsqltype).toBe("cf_sql_timestamp");
          expect(emptyParameter.null).toBeTrue();
        });
      });

      it("completes the first leg and starts the second at one UTC time per action outside UTC", function() {
        withClockContext("America/Chicago", "-05:00", function() {
          exerciseTwoLegSequence();
        });
      });

      it("keeps the same two-leg contract in UTC", function() {
        withClockContext("UTC", "+00:00", function() {
          exerciseTwoLegSequence();
        });
      });

      it("does not write timestamps for denied initial or locked access", function() {
        withClockContext("America/Chicago", "-05:00", function() {
          var fixture = createFixture();
          var before = loadProgress(fixture);
          for (var denyAt in ["initial", "locked"]) {
            var service = routeService(denyAt);
            var completed = service.markCompletionFromFloatPlanCheckin(
              userId=fixture.userId, floatPlanId=fixture.floatPlanId,
              datasource=variables.datasource, completionMode="active_leg", expectedLegOrder=1
            );
            expect(completed.SUCCESS).toBeFalse();
            expect(structKeyExists(completed, "ACTION_AT_UTC")).toBeFalse();
            expect(serializeJSON(loadProgress(fixture))).toBe(serializeJSON(before));
          }
          queryExecute("UPDATE route_instance_leg_progress SET status='COMPLETED', completed_at=UTC_TIMESTAMP()
                        WHERE route_instance_id=:routeId AND leg_order=1",
            {routeId={value=fixture.routeInstanceId,cfsqltype="cf_sql_integer"}}, {datasource=variables.datasource});
          before = loadProgress(fixture);
          for (var denyAt in ["initial", "locked"]) {
            var service = routeService(denyAt);
            var started = service.startNextPendingLegForFloatPlan(
              userId=fixture.userId, floatPlanId=fixture.floatPlanId, datasource=variables.datasource
            );
            expect(started.SUCCESS).toBeFalse();
            expect(structKeyExists(started, "ACTION_AT_UTC")).toBeFalse();
            expect(serializeJSON(loadProgress(fixture))).toBe(serializeJSON(before));
          }
        });
      });

      it("passes the saved action timestamp to both endpoint activity writes", function() {
        var source = fileRead(expandPath("/fpw/api/v1/floatplan.cfc"), "utf-8");
        for (var action in ["completeleg", "startnextleg"]) {
          var start = findNoCase('<cfcase value="' & action & '">', source);
          var finish = findNoCase("</cfcase>", source, start);
          var block = mid(source, start, finish-start);
          var resultName = (action EQ "completeleg" ? "completeLegResult" : "startNextLegResult");
          expect(start).toBeGT(0);
          expect(findNoCase("occurredAtUtc=" & resultName & ".ACTION_AT_UTC", reReplace(block, "\s", "", "all"))).toBeGT(0);
          expect(findNoCase("occurredAtUtc=now()", reReplace(block, "\s", "", "all"))).toBe(0);
        }
      });
    });
  }

  private void function exerciseTwoLegSequence() {
    var fixture = createFixture();
    var service = routeService();
    var writer = new fpw.api.v1.TripActivityWriterService().init(variables.datasource);
    var projection = new fpw.api.v1.TripProgressProjectionService().init(variables.datasource);
    var completed = service.markCompletionFromFloatPlanCheckin(
      userId=fixture.userId, floatPlanId=fixture.floatPlanId,
      datasource=variables.datasource, completionMode="active_leg", expectedLegOrder=1
    );
    expect(completed.SUCCESS).toBeTrue();
    expect(completed.COMPLETED).toBeTrue();
    expect(isDate(completed.ACTION_AT_UTC)).toBeTrue();
    var event = writeAction(writer, fixture, completed, "ROUTE_LEG_COMPLETED", 1);
    expect(event.SUCCESS).toBeTrue(event.MESSAGE ?: "");
    var completionState = actionState(fixture, 1, event.EVENT_ID);
    expect(completionState.completed_at[1]).toBe(completed.ACTION_AT_UTC);
    expect(completionState.event_at[1]).toBe(completed.ACTION_AT_UTC);
    expect(completionState.segment_ended_at[1]).toBe(completed.ACTION_AT_UTC);
    expect(abs(val(completionState.age_seconds[1]))).toBeLT(5);
    var repeatComplete = service.markCompletionFromFloatPlanCheckin(
      userId=fixture.userId, floatPlanId=fixture.floatPlanId,
      datasource=variables.datasource, completionMode="active_leg", expectedLegOrder=1
    );
    expect(repeatComplete.ALREADY_COMPLETE).toBeTrue();
    expect(structKeyExists(repeatComplete, "ACTION_AT_UTC")).toBeFalse();

    var started = service.startNextPendingLegForFloatPlan(
      userId=fixture.userId, floatPlanId=fixture.floatPlanId, datasource=variables.datasource
    );
    expect(started.SUCCESS).toBeTrue();
    expect(started.STARTED).toBeTrue();
    expect(started.LEG_ORDER).toBe(2);
    event = writeAction(writer, fixture, started, "ROUTE_LEG_STARTED", 2);
    expect(event.SUCCESS).toBeTrue(event.MESSAGE ?: "");
    var startState = actionState(fixture, 2, event.EVENT_ID);
    expect(startState.started_at[1]).toBe(started.ACTION_AT_UTC);
    expect(startState.event_at[1]).toBe(started.ACTION_AT_UTC);
    expect(startState.segment_started_at[1]).toBe(started.ACTION_AT_UTC);
    expect(abs(val(startState.age_seconds[1]))).toBeLT(5);
    expect(find(started.ACTION_AT_UTC, replace(startState.payload_json[1], "T", " ", "all"))).toBeGT(0);

    expect(right(startState.idempotency_key[1], 20)).toBe(replace(started.ACTION_AT_UTC, " ", "T") & "Z");

    var atStart = projection.getProjection(fixture.floatPlanId, started.ACTION_AT_UTC);
    var afterMinute = projection.getProjection(
      fixture.floatPlanId, dateTimeFormat(dateAdd("s", 60, started.ACTION_AT_UTC), "yyyy-mm-dd HH:nn:ss")
    );
    expect(atStart.success).toBeTrue();
    expect(atStart.currentLeg.routeLegOrder).toBe(2);
    expect(atStart.currentLeg.status).toBe("STARTED");
    expect(atStart.currentLegProgress.underwaySeconds).toBe(0);
    expect(atStart.currentLegProgress.percentComplete).toBe(0);
    expect(afterMinute.currentLegProgress.underwaySeconds).toBe(60);
    expect(afterMinute.currentLegProgress.percentComplete).toBeGT(0);
    expect(afterMinute.currentLegProgress.percentComplete).toBeLT(100);
    expect(afterMinute.currentLegProgress.remainingNm).toBeGT(0);

    var beforeRepeat = loadProgress(fixture);
    var repeated = service.startNextPendingLegForFloatPlan(
      userId=fixture.userId, floatPlanId=fixture.floatPlanId, datasource=variables.datasource
    );
    expect(repeated.SUCCESS).toBeFalse();
    expect(repeated.ERROR).toBe("LEG_ALREADY_ACTIVE");
    expect(structKeyExists(repeated, "ACTION_AT_UTC")).toBeFalse();
    expect(serializeJSON(loadProgress(fixture))).toBe(serializeJSON(beforeRepeat));
  }

  private any function routeService(string denyAt="") {
    var denied = {allowed=false, response={ERROR={CODE="TEST_ACCESS_DENIED"}, MESSAGE="Controlled test denial"}};
    var gate = createStub()
      .$("requireTripOperationalAccess", arguments.denyAt EQ "initial" ? denied : {allowed=true})
      .$("requireTripOperationalAccessForUpdate", arguments.denyAt EQ "locked" ? denied : {allowed=true});
    return prepareMock(new fpw.api.v1.RouteProgressService().init()).$("getMemberAccessGateService", gate);
  }

  private struct function writeAction(required any writer, required struct fixture, required struct result,
                                      required string eventType, required numeric legOrder) {
    return arguments.writer.recordActiveCruiseRouteAction(
      floatPlanId=arguments.fixture.floatPlanId, userId=arguments.fixture.userId,
      eventType=arguments.eventType, actionLabel=arguments.eventType,
      occurredAtUtc=arguments.result.ACTION_AT_UTC,
      routeInstanceId=arguments.fixture.routeInstanceId, routeLegOrder=arguments.legOrder,
      endpointResult=arguments.result
    );
  }

  private query function actionState(required struct fixture, required numeric legOrder, required numeric eventId) {
    return queryExecute(
      "SELECT DATE_FORMAT(p.leg_started_at, '%Y-%m-%d %H:%i:%s') AS started_at,
              DATE_FORMAT(p.completed_at, '%Y-%m-%d %H:%i:%s') AS completed_at,
              DATE_FORMAT(e.occurred_at_utc, '%Y-%m-%d %H:%i:%s') AS event_at,
              DATE_FORMAT(s.started_at_utc, '%Y-%m-%d %H:%i:%s') AS segment_started_at,
              DATE_FORMAT(s.ended_at_utc, '%Y-%m-%d %H:%i:%s') AS segment_ended_at,
              TIMESTAMPDIFF(SECOND, e.occurred_at_utc, UTC_TIMESTAMP()) AS age_seconds, e.payload_json, e.idempotency_key
       FROM route_instance_leg_progress p
       INNER JOIN floatplan_events e ON e.id=:eventId
       INNER JOIN floatplan_activity_segments s
         ON s.floatplan_id=:planId AND s.route_leg_order=p.leg_order
       WHERE p.route_instance_id=:routeId AND p.leg_order=:legOrder",
      {eventId={value=arguments.eventId,cfsqltype="cf_sql_bigint"},
       planId={value=arguments.fixture.floatPlanId,cfsqltype="cf_sql_integer"},
       routeId={value=arguments.fixture.routeInstanceId,cfsqltype="cf_sql_integer"},
       legOrder={value=arguments.legOrder,cfsqltype="cf_sql_integer"}},
      {datasource=variables.datasource}
    );
  }

  private query function loadProgress(required struct fixture) {
    return queryExecute(
      "SELECT leg_order,status,DATE_FORMAT(leg_started_at,'%Y-%m-%d %H:%i:%s') AS started_at,
              DATE_FORMAT(completed_at,'%Y-%m-%d %H:%i:%s') AS completed_at
       FROM route_instance_leg_progress WHERE route_instance_id=:routeId ORDER BY leg_order",
      {routeId={value=arguments.fixture.routeInstanceId,cfsqltype="cf_sql_integer"}},
      {datasource=variables.datasource});
  }

  private struct function createFixture() {
    var marker = "codex-route-utc-" & left(lCase(replace(createUUID(), "-", "", "all")), 12);
    queryExecute("INSERT INTO users(fName,lName,email,password,passwordCreated,created)
                  VALUES('Codex','RouteUTC',:email,:password,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
      {email={value=marker & "@example.test",cfsqltype="cf_sql_varchar"},
       password={value=hash(marker,"SHA-256"),cfsqltype="cf_sql_varchar"}}, {datasource=variables.datasource});
    var userId = queryExecute("SELECT LAST_INSERT_ID() AS id",{}, {datasource=variables.datasource}).id[1];
    queryExecute("INSERT INTO loop_routes(code,name,short_code,description,is_active)
                  VALUES(:code,'UTC regression',:code,:code,1)",
      {code={value=marker,cfsqltype="cf_sql_varchar"}}, {datasource=variables.datasource});
    var routeId = queryExecute("SELECT LAST_INSERT_ID() AS id",{}, {datasource=variables.datasource}).id[1];
    queryExecute("INSERT INTO route_instances(user_id,template_route_code,generated_route_id,generated_route_code,
                  direction,trip_type,start_location,end_location,routegen_inputs_json,status,started_at)
                  VALUES(:userId,:code,:routeId,:code,'CCW','POINT_TO_POINT','Home','Home',:inputs,'ACTIVE',DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 MINUTE))",
      {userId={value=userId,cfsqltype="cf_sql_integer"},code={value=marker,cfsqltype="cf_sql_varchar"},
       routeId={value=routeId,cfsqltype="cf_sql_integer"},
       inputs={value=serializeJSON({effective_speed_kn=22,weather_factor_pct=0}),cfsqltype="cf_sql_longvarchar"}},
      {datasource=variables.datasource});
    var routeInstanceId = queryExecute("SELECT LAST_INSERT_ID() AS id",{}, {datasource=variables.datasource}).id[1];
    queryExecute("INSERT INTO route_instance_legs(route_instance_id,leg_order,start_name,end_name,base_dist_nm,lock_count)
                  VALUES(:routeId,1,'Home','Anchorage',5,0),(:routeId,2,'Anchorage','Home',5,0)",
      {routeId={value=routeInstanceId,cfsqltype="cf_sql_integer"}}, {datasource=variables.datasource});
    queryExecute("INSERT INTO route_instance_leg_progress(user_id,route_instance_id,leg_order,status,leg_started_at)
                  VALUES(:userId,:routeId,1,'STARTED',DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 MINUTE)),
                        (:userId,:routeId,2,'NOT_STARTED',NULL)",
      {userId={value=userId,cfsqltype="cf_sql_integer"},routeId={value=routeInstanceId,cfsqltype="cf_sql_integer"}},
      {datasource=variables.datasource});
    queryExecute("INSERT INTO floatplans(userId,floatPlanName,dateCreated,lastUpdate,status,lastUpdateStatus,
                  route_instance_id,route_day_number,activatedAt,departureTZ,departTimezone)
                  VALUES(:userId,:name,UTC_TIMESTAMP(),UTC_TIMESTAMP(),'ACTIVE',UTC_TIMESTAMP(),
                         :routeId,1,DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 MINUTE),'America/New_York','America/New_York')",
      {userId={value=userId,cfsqltype="cf_sql_integer"},name={value=marker,cfsqltype="cf_sql_varchar"},
       routeId={value=routeInstanceId,cfsqltype="cf_sql_integer"}}, {datasource=variables.datasource});
    var floatPlanId = queryExecute("SELECT LAST_INSERT_ID() AS id",{}, {datasource=variables.datasource}).id[1];
    queryExecute("INSERT INTO floatplan_activity_segments(floatplan_id,user_id,route_instance_id,route_leg_order,
                  local_timezone,segment_type,started_at_utc)
                  VALUES(:planId,:userId,:routeId,1,'America/New_York','UNDERWAY',DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 MINUTE))",
      {planId={value=floatPlanId,cfsqltype="cf_sql_integer"},userId={value=userId,cfsqltype="cf_sql_integer"},
       routeId={value=routeInstanceId,cfsqltype="cf_sql_integer"}}, {datasource=variables.datasource});
    return {userId=val(userId),routeInstanceId=val(routeInstanceId),floatPlanId=val(floatPlanId)};
  }

  // Hold one database connection; restore its timezone before rolling back fixture data.
  private void function withClockContext(required string requestZone, required string databaseZone, required any body) {
    var previousRequestZone = getTimeZone().timezone;
    var previousDatabaseZone = "";
    var restoredDatabaseZone = "";
    var restoredRequestZone = "";
    transaction {
      previousDatabaseZone = queryExecute(
        "SELECT @@session.time_zone AS time_zone", {}, {datasource=variables.datasource}
      ).time_zone[1];
      try {
        setTimeZone(arguments.requestZone);
        queryExecute("SET SESSION time_zone = :zone",
          {zone={value=arguments.databaseZone,cfsqltype="cf_sql_varchar"}},
          {datasource=variables.datasource});
        arguments.body();
      } finally {
        queryExecute("SET SESSION time_zone = :zone",
          {zone={value=previousDatabaseZone,cfsqltype="cf_sql_varchar"}},
          {datasource=variables.datasource});
        restoredDatabaseZone = queryExecute("SELECT @@session.time_zone AS time_zone",
          {}, {datasource=variables.datasource}).time_zone[1];
        setTimeZone(previousRequestZone);
        restoredRequestZone = getTimeZone().timezone;
        transaction action="rollback";
      }
    }
    expect(restoredDatabaseZone).toBe(previousDatabaseZone);
    expect(restoredRequestZone).toBe(previousRequestZone);
  }
}
