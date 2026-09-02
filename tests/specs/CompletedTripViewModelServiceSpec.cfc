component extends="testbox.system.BaseSpec" output="false" {

  variables.datasource = "fpw";
  variables.fixturePrefix = "codex-completed-trip-view-";

  function beforeAll() {
    cleanupFixtures();
  }

  function afterAll() {
    cleanupFixtures();
  }

  function run() {
    describe("Completed Trip view model service", function() {

      beforeEach(function() {
        cleanupFixtures();
        variables.service = createObject("component", "fpw.api.v1.CompletedTripViewModelService").init(variables.datasource);
      });

      afterEach(function() {
        cleanupFixtures();
      });

      it("loads a closed owner-owned route trip from completed trip-specific sources", function() {
        var fixture = createCompletedTripFixture(
          label = "owner",
          addContact = true,
          addGeometrySnapshot = true
        );
        var result = variables.service.getCompletedTripViewModel(
          userId = fixture.userId,
          floatPlanId = fixture.floatPlanId
        );

        expect(result.SUCCESS).toBeTrue();
        expect(result.found).toBeTrue();
        expect(result.statusCode).toBe(200);
        expect(result.trip.name).toBe(fixture.planName);
        expect(result.trip.status).toBe("Completed");
        expect(result.trip.departureLocation).toBe("Test Marina");
        expect(result.trip.destination).toBe("Test Anchorage");
        expect(result.trip.tripType).toBe("Point To Point");
        expect(result.vessel.name).toBe(fixture.vesselName);
        expect(result.vessel.isHistoricalSnapshot).toBeFalse();
        expect(result.shoreContact.displayed).toBeFalse();
        expect(result.shoreContact.associatedCount).toBe(1);
        expect(result.route.available).toBeTrue();
        expect(result.route.routeInstanceId).toBe(fixture.routeInstanceId);
        expect(result.route.status).toBe("COMPLETED");
        expect(result.route.legCount).toBe(2);
        expect(result.route.waypointCount).toBe(3);
        expect(result.route.distanceLabel).toBe("10.0 NM");
        expect(result.route.geometrySnapshot.available).toBeTrue();
        expect(result.completion.routeCompleted).toBeTrue();
        expect(result.timing.actualCompletion.timezone).toBe("America/New_York");
        expect(findNoCase("America/New_York", result.timing.actualCompletion.localLabel)).toBeGT(0);
        expect(len(result.completion.completedAtUtc)).toBeGT(0);
        expect(result.monitoring.closed).toBeTrue();
        expect(result.follow.available).toBeFalse();
        expect(hasWarning(result, "VESSEL_NAME_CURRENT_PROFILE_MUTABLE")).toBeTrue();
        expect(hasWarning(result, "SHORE_CONTACT_DETAILS_SUPPRESSED")).toBeTrue();
      });

      it("does not return another member's completed trip", function() {
        var fixture = createCompletedTripFixture(label = "owner-only");
        var otherUserId = createUser("other-member");
        var result = variables.service.getCompletedTripViewModel(
          userId = otherUserId,
          floatPlanId = fixture.floatPlanId
        );

        expect(result.SUCCESS).toBeFalse();
        expect(result.found).toBeFalse();
        expect(result.errorCode).toBe("COMPLETED_TRIP_NOT_FOUND");
        expect(result.statusCode).toBe(404);
        expect(structKeyExists(result, "trip")).toBeFalse();
      });

      it("rejects draft, scheduled, and active plans", function() {
        var statuses = ["DRAFT", "SCHEDULED", "ACTIVE"];
        var i = 0;

        for (i = 1; i LTE arrayLen(statuses); i++) {
          var fixture = createCompletedTripFixture(
            label = "not-closed-" & lCase(statuses[i]),
            planStatus = statuses[i],
            routeStatus = "ACTIVE",
            closed = false
          );
          var result = variables.service.getCompletedTripViewModel(
            userId = fixture.userId,
            floatPlanId = fixture.floatPlanId
          );

          expect(result.SUCCESS).toBeFalse();
          expect(result.found).toBeFalse();
          expect(result.errorCode).toBe("COMPLETED_TRIP_NOT_FOUND");
        }
      });

      it("rejects a closed float plan whose route instance is not completed", function() {
        var fixture = createCompletedTripFixture(
          label = "route-open",
          planStatus = "CLOSED",
          routeStatus = "ACTIVE",
          closed = true
        );
        var result = variables.service.getCompletedTripViewModel(
          userId = fixture.userId,
          floatPlanId = fixture.floatPlanId
        );

        expect(result.SUCCESS).toBeFalse();
        expect(result.errorCode).toBe("ROUTE_INSTANCE_NOT_COMPLETED");
        expect(result.statusCode).toBe(404);
      });

      it("keeps trip and route-specific fields stable when current vessel profile data changes", function() {
        var fixture = createCompletedTripFixture(label = "mutable-vessel");
        var before = variables.service.getCompletedTripViewModel(
          userId = fixture.userId,
          floatPlanId = fixture.floatPlanId
        );
        var changedName = fixture.marker & "-renamed-vessel";
        var after = {};

        queryExecute(
          "UPDATE vessels SET vesselName = :vesselName WHERE vesselID = :vesselId AND userId = :userId",
          {
            vesselName = { value = left(changedName, 255), cfsqltype = "cf_sql_varchar" },
            vesselId = { value = fixture.vesselId, cfsqltype = "cf_sql_integer" },
            userId = { value = toString(fixture.userId), cfsqltype = "cf_sql_varchar" }
          },
          { datasource = variables.datasource }
        );

        after = variables.service.getCompletedTripViewModel(
          userId = fixture.userId,
          floatPlanId = fixture.floatPlanId
        );

        expect(before.SUCCESS).toBeTrue();
        expect(after.SUCCESS).toBeTrue();
        expect(after.trip.name).toBe(before.trip.name);
        expect(after.trip.departureLocation).toBe(before.trip.departureLocation);
        expect(after.trip.destination).toBe(before.trip.destination);
        expect(after.route.routeInstanceId).toBe(before.route.routeInstanceId);
        expect(after.route.distanceLabel).toBe(before.route.distanceLabel);
        expect(after.timing.actualCompletion.utc).toBe(before.timing.actualCompletion.utc);
        expect(after.vessel.name).toBe(left(changedName, 255));
        expect(hasWarning(after, "VESSEL_NAME_CURRENT_PROFILE_MUTABLE")).toBeTrue();
      });

      it("remains attached to the original completed route when a new draft uses a fresh route instance", function() {
        var fixture = createCompletedTripFixture(label = "route-reuse");
        var draftRouteId = createDraftFromCompletedRoute(fixture);
        var result = variables.service.getCompletedTripViewModel(
          userId = fixture.userId,
          floatPlanId = fixture.floatPlanId
        );

        expect(result.SUCCESS).toBeTrue();
        expect(result.route.routeInstanceId).toBe(fixture.routeInstanceId);
        expect(result.route.routeInstanceId).notToBe(draftRouteId);
        expect(result.route.status).toBe("COMPLETED");
        expect(result.trip.status).toBe("Completed");
      });

      it("builds the stable completed-trip URL with the supplied environment base path", function() {
        expect(variables.service.buildCompletedTripUrl(123, "/fpw")).toBe("/fpw/app/completed-trip.cfm?id=123");
        expect(variables.service.buildCompletedTripUrl(123, "/")).toBe("/app/completed-trip.cfm?id=123");
        expect(variables.service.buildCompletedTripUrl(123, "")).toBe("/app/completed-trip.cfm?id=123");
      });
    });
  }

  private struct function createCompletedTripFixture(
    required string label,
    string planStatus = "CLOSED",
    string routeStatus = "COMPLETED",
    boolean closed = true,
    boolean addContact = false,
    boolean addGeometrySnapshot = true
  ) {
    var token = lCase(reReplace(createUUID(), "[^A-Za-z0-9]", "", "all"));
    var marker = left(variables.fixturePrefix & token, 180);
    var routeCode = left("CTV_" & token, 40);
    var routeName = left(marker & "-route", 160);
    var planName = left(marker & "-" & arguments.label, 255);
    var vesselName = left(marker & "-vessel", 255);
    var qUser = queryNew("");
    var qVessel = queryNew("");
    var qRoute = queryNew("");
    var qInstance = queryNew("");
    var qSection = queryNew("");
    var qPlan = queryNew("");
    var qContact = queryNew("");
    var finalCompletedAt = dateAdd("n", -20, now());
    var startedAt = dateAdd("h", -4, finalCompletedAt);
    var plannedDepartAt = dateAdd("h", -5, finalCompletedAt);
    var plannedReturnAt = dateAdd("n", 10, finalCompletedAt);
    var legOrder = 0;
    var progressStatus = arguments.routeStatus EQ "COMPLETED" ? "COMPLETED" : "IN_PROGRESS";
    var fixture = {};

    qUser = insertUser(marker, arguments.label);

    queryExecute(
      "INSERT INTO vessels (userId, vesselName, hailingPort, isDefaultVessel, timezone)
       VALUES (:userId, :vesselName, 'Test Harbor', 1, 'America/New_York')",
      {
        userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" },
        vesselName = { value = vesselName, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    qVessel = queryExecute(
      "SELECT vesselID FROM vessels WHERE userId = :userId AND vesselName = :vesselName ORDER BY vesselID DESC LIMIT 1",
      {
        userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" },
        vesselName = { value = vesselName, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );

    queryExecute(
      "INSERT INTO loop_routes
          (code, name, short_code, description, is_active, version, is_default, total_nm, total_locks)
       VALUES
          (:routeCode, :routeName, :routeCode, :description, 1, 1, 0, 10.00, 0)",
      {
        routeCode = { value = routeCode, cfsqltype = "cf_sql_varchar" },
        routeName = { value = routeName, cfsqltype = "cf_sql_varchar" },
        description = { value = marker, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    qRoute = queryExecute(
      "SELECT id FROM loop_routes WHERE short_code = :routeCode LIMIT 1",
      { routeCode = { value = routeCode, cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );

    queryExecute(
      "INSERT INTO route_instances
          (user_id, template_route_code, generated_route_id, generated_route_code,
           direction, trip_type, start_location, end_location, routegen_inputs_json,
           status, started_at, completed_at)
       VALUES
          (:userId, :routeCode, :routeId, :routeCode,
           'CCW', 'POINT_TO_POINT', 'Test Marina', 'Test Anchorage', :inputsJson,
           :routeStatus, :startedAt, :completedAt)",
      {
        userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" },
        routeCode = { value = routeCode, cfsqltype = "cf_sql_varchar" },
        routeId = { value = val(qRoute.id[1]), cfsqltype = "cf_sql_integer" },
        inputsJson = { value = serializeJSON({ fixture_marker = marker }), cfsqltype = "cf_sql_longvarchar" },
        routeStatus = { value = arguments.routeStatus, cfsqltype = "cf_sql_varchar" },
        startedAt = {
          value = startedAt,
          null = !arguments.closed,
          cfsqltype = "cf_sql_timestamp"
        },
        completedAt = {
          value = finalCompletedAt,
          null = (arguments.routeStatus NEQ "COMPLETED"),
          cfsqltype = "cf_sql_timestamp"
        }
      },
      { datasource = variables.datasource }
    );
    qInstance = queryExecute(
      "SELECT id FROM route_instances
       WHERE user_id = :userId AND generated_route_code = :routeCode
       ORDER BY id DESC LIMIT 1",
      {
        userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" },
        routeCode = { value = routeCode, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );

    queryExecute(
      "INSERT INTO route_instance_sections (route_instance_id, section_order, name, phase_num)
       VALUES (:routeInstanceId, 1, 'Completed Trip View Test Section', 1)",
      { routeInstanceId = { value = val(qInstance.id[1]), cfsqltype = "cf_sql_integer" } },
      { datasource = variables.datasource }
    );
    qSection = queryExecute(
      "SELECT id FROM route_instance_sections WHERE route_instance_id = :routeInstanceId AND section_order = 1 LIMIT 1",
      { routeInstanceId = { value = val(qInstance.id[1]), cfsqltype = "cf_sql_integer" } },
      { datasource = variables.datasource }
    );

    for (legOrder = 1; legOrder LTE 2; legOrder++) {
      queryExecute(
        "INSERT INTO route_instance_legs
            (route_instance_id, route_instance_section_id, leg_order,
             is_reversed, is_optional, start_name, end_name, base_dist_nm, lock_count)
         VALUES
            (:routeInstanceId, :sectionId, :legOrder,
             0, 0, :startName, :endName, :distanceNm, 0)",
        {
          routeInstanceId = { value = val(qInstance.id[1]), cfsqltype = "cf_sql_integer" },
          sectionId = { value = val(qSection.id[1]), cfsqltype = "cf_sql_integer" },
          legOrder = { value = legOrder, cfsqltype = "cf_sql_integer" },
          startName = {
            value = legOrder EQ 1 ? "Test Marina" : "Test Midpoint",
            cfsqltype = "cf_sql_varchar"
          },
          endName = {
            value = legOrder EQ 1 ? "Test Midpoint" : "Test Anchorage",
            cfsqltype = "cf_sql_varchar"
          },
          distanceNm = { value = legOrder EQ 1 ? 4.25 : 5.75, cfsqltype = "cf_sql_decimal" }
        },
        { datasource = variables.datasource }
      );
      queryExecute(
        "INSERT INTO route_instance_leg_progress
            (user_id, route_instance_id, leg_order, status, leg_started_at, completed_at)
         VALUES
            (:userId, :routeInstanceId, :legOrder, :status, :startedAt, :completedAt)",
        {
          userId = { value = val(qUser.userId[1]), cfsqltype = "cf_sql_integer" },
          routeInstanceId = { value = val(qInstance.id[1]), cfsqltype = "cf_sql_integer" },
          legOrder = { value = legOrder, cfsqltype = "cf_sql_integer" },
          status = { value = progressStatus, cfsqltype = "cf_sql_varchar" },
          startedAt = {
            value = dateAdd("n", 30 * legOrder, startedAt),
            null = !arguments.closed,
            cfsqltype = "cf_sql_timestamp"
          },
          completedAt = {
            value = dateAdd("n", 45 * legOrder, startedAt),
            null = (progressStatus NEQ "COMPLETED"),
            cfsqltype = "cf_sql_timestamp"
          }
        },
        { datasource = variables.datasource }
      );
    }

    if (arguments.addGeometrySnapshot) {
      queryExecute(
        "INSERT INTO route_instance_geometry_snapshots
            (route_instance_id, snapshot_version, snapshot_json, created_at_utc)
         VALUES
            (:routeInstanceId, 1, :snapshotJson, UTC_TIMESTAMP())",
        {
          routeInstanceId = { value = val(qInstance.id[1]), cfsqltype = "cf_sql_integer" },
          snapshotJson = {
            value = serializeJSON({
              schema_version = 1,
              route_instance_id = val(qInstance.id[1]),
              segments = [],
              markers = [
                { label = "Test Marina", lat = 28.15, lng = -82.75 },
                { label = "Test Midpoint", lat = 28.2, lng = -82.7 },
                { label = "Test Anchorage", lat = 28.24, lng = -82.66 }
              ]
            }),
            cfsqltype = "cf_sql_longvarchar"
          }
        },
        { datasource = variables.datasource }
      );
    }

    queryExecute(
      "INSERT INTO floatplans
          (userId, floatPlanName, vesselId, dateCreated, lastUpdate,
           departing, `returning`, departureTime, departureTimeUTC, departTimezone,
           departureTZ, returnTime, returnTimeUTC, returnTimezone, returnTZ, status,
           lastUpdateStatus, activatedAt, checkedInAt, closedAt, route_instance_id,
           route_day_number, route_origin, is_reusable, is_visible_in_route_library)
       VALUES
          (:userId, :planName, :vesselId, UTC_TIMESTAMP(), UTC_TIMESTAMP(),
           'Test Marina', 'Test Anchorage', :departureTime, :departureTimeUTC,
           'America/New_York', 'America/New_York', :returnTime, :returnTimeUTC,
           'America/New_York', 'America/New_York', :planStatus, UTC_TIMESTAMP(),
           :activatedAt, :checkedInAt, :closedAt, :routeInstanceId,
           1, 'premium_saved_route', 1, 1)",
      {
        userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" },
        planName = { value = planName, cfsqltype = "cf_sql_varchar" },
        vesselId = { value = val(qVessel.vesselID[1]), cfsqltype = "cf_sql_integer" },
        departureTime = { value = plannedDepartAt, cfsqltype = "cf_sql_timestamp" },
        departureTimeUTC = { value = plannedDepartAt, cfsqltype = "cf_sql_timestamp" },
        returnTime = { value = plannedReturnAt, cfsqltype = "cf_sql_timestamp" },
        returnTimeUTC = { value = plannedReturnAt, cfsqltype = "cf_sql_timestamp" },
        planStatus = { value = arguments.planStatus, cfsqltype = "cf_sql_varchar" },
        activatedAt = {
          value = startedAt,
          null = !arguments.closed,
          cfsqltype = "cf_sql_timestamp"
        },
        checkedInAt = {
          value = finalCompletedAt,
          null = !arguments.closed,
          cfsqltype = "cf_sql_timestamp"
        },
        closedAt = {
          value = finalCompletedAt,
          null = !arguments.closed,
          cfsqltype = "cf_sql_timestamp"
        },
        routeInstanceId = { value = val(qInstance.id[1]), cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );
    qPlan = queryExecute(
      "SELECT floatPlanId FROM floatplans
       WHERE userId = :userId AND floatPlanName = :planName
       ORDER BY floatPlanId DESC LIMIT 1",
      {
        userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" },
        planName = { value = planName, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );

    if (arguments.addContact) {
      queryExecute(
        "INSERT INTO contacts (name, phone, userId, email)
         VALUES (:name, '555-0100', :userId, :email)",
        {
          name = { value = left(marker & "-contact", 255), cfsqltype = "cf_sql_varchar" },
          userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" },
          email = { value = left(marker & "-contact@example.test", 255), cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
      qContact = queryExecute(
        "SELECT contactId FROM contacts WHERE userId = :userId AND name = :name ORDER BY contactId DESC LIMIT 1",
        {
          userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" },
          name = { value = left(marker & "-contact", 255), cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
      queryExecute(
        "INSERT INTO floatplan_contacts (contactId, floatPlanId)
         VALUES (:contactId, :floatPlanId)",
        {
          contactId = { value = val(qContact.contactId[1]), cfsqltype = "cf_sql_integer" },
          floatPlanId = { value = val(qPlan.floatPlanId[1]), cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
    }

    if (arguments.closed) {
      queryExecute(
        "INSERT INTO floatplan_monitoring
            (float_plan_id, user_id, monitoring_mode, monitor_state, is_monitoring_enabled, closed_at, created_at, updated_at)
         VALUES
            (:floatPlanId, :userId, 'active_route', 'CLOSED', 0, :closedAt, UTC_TIMESTAMP(), UTC_TIMESTAMP())",
        {
          floatPlanId = { value = val(qPlan.floatPlanId[1]), cfsqltype = "cf_sql_integer" },
          userId = { value = val(qUser.userId[1]), cfsqltype = "cf_sql_integer" },
          closedAt = { value = finalCompletedAt, cfsqltype = "cf_sql_timestamp" }
        },
        { datasource = variables.datasource }
      );
    }

    fixture = {
      marker = marker,
      userId = val(qUser.userId[1]),
      vesselId = val(qVessel.vesselID[1]),
      vesselName = vesselName,
      routeCode = routeCode,
      routeInstanceId = val(qInstance.id[1]),
      floatPlanId = val(qPlan.floatPlanId[1]),
      planName = planName
    };
    return fixture;
  }

  private numeric function createUser(required string label) {
    var marker = left(variables.fixturePrefix & lCase(reReplace(createUUID(), "[^A-Za-z0-9]", "", "all")), 180);
    var qUser = insertUser(marker, arguments.label);
    return val(qUser.userId[1]);
  }

  private query function insertUser(required string marker, required string label) {
    var email = left(arguments.marker & "-" & arguments.label & "@example.test", 255);
    queryExecute(
      "INSERT INTO users (fName, lName, email, password, passwordCreated, created)
       VALUES ('Codex', 'Completed Trip', :email, :password, UTC_TIMESTAMP(), UTC_TIMESTAMP())",
      {
        email = { value = email, cfsqltype = "cf_sql_varchar" },
        password = { value = hash(arguments.marker, "SHA-256"), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    return queryExecute(
      "SELECT userId FROM users WHERE email = :email ORDER BY userId DESC LIMIT 1",
      { email = { value = email, cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );
  }

  private numeric function createDraftFromCompletedRoute(required struct fixture) {
    var draftCode = left("CTV_DRAFT_" & lCase(reReplace(createUUID(), "[^A-Za-z0-9]", "", "all")), 40);
    var qDraft = queryNew("");

    queryExecute(
      "INSERT INTO route_instances
          (user_id, template_route_code, generated_route_id, generated_route_code,
           direction, trip_type, start_location, end_location, routegen_inputs_json,
           status, started_at, completed_at)
       VALUES
          (:userId, :routeCode, 0, :draftCode,
           'CCW', 'POINT_TO_POINT', 'Draft Start', 'Draft Finish', :inputsJson,
           'PLANNED', NULL, NULL)",
      {
        userId = { value = toString(arguments.fixture.userId), cfsqltype = "cf_sql_varchar" },
        routeCode = { value = arguments.fixture.routeCode, cfsqltype = "cf_sql_varchar" },
        draftCode = { value = draftCode, cfsqltype = "cf_sql_varchar" },
        inputsJson = {
          value = serializeJSON({
            fixture_marker = arguments.fixture.marker,
            source_route_instance_id = arguments.fixture.routeInstanceId
          }),
          cfsqltype = "cf_sql_longvarchar"
        }
      },
      { datasource = variables.datasource }
    );
    qDraft = queryExecute(
      "SELECT id FROM route_instances WHERE user_id = :userId AND generated_route_code = :draftCode ORDER BY id DESC LIMIT 1",
      {
        userId = { value = toString(arguments.fixture.userId), cfsqltype = "cf_sql_varchar" },
        draftCode = { value = draftCode, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );

    queryExecute(
      "INSERT INTO floatplans
          (userId, floatPlanName, vesselId, dateCreated, lastUpdate,
           departing, `returning`, status, lastUpdateStatus, route_instance_id,
           route_day_number, route_origin, is_reusable, is_visible_in_route_library)
       VALUES
          (:userId, :planName, :vesselId, UTC_TIMESTAMP(), UTC_TIMESTAMP(),
           'Draft Start', 'Draft Finish', 'DRAFT', UTC_TIMESTAMP(), :routeInstanceId,
           1, 'premium_saved_route', 1, 1)",
      {
        userId = { value = toString(arguments.fixture.userId), cfsqltype = "cf_sql_varchar" },
        planName = { value = left(arguments.fixture.marker & "-draft-reuse", 255), cfsqltype = "cf_sql_varchar" },
        vesselId = { value = arguments.fixture.vesselId, cfsqltype = "cf_sql_integer" },
        routeInstanceId = { value = val(qDraft.id[1]), cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );

    return val(qDraft.id[1]);
  }

  private boolean function hasWarning(required struct result, required string code) {
    var i = 0;
    if (!structKeyExists(arguments.result, "warnings") OR !isArray(arguments.result.warnings)) {
      return false;
    }
    for (i = 1; i LTE arrayLen(arguments.result.warnings); i++) {
      if (
        isStruct(arguments.result.warnings[i])
        AND structKeyExists(arguments.result.warnings[i], "code")
        AND arguments.result.warnings[i].code EQ arguments.code
      ) {
        return true;
      }
    }
    return false;
  }

  private void function cleanupFixtures() {
    var params = {
      emailPrefix = { value = variables.fixturePrefix & "%", cfsqltype = "cf_sql_varchar" },
      markerPrefix = { value = variables.fixturePrefix & "%", cfsqltype = "cf_sql_varchar" }
    };

    queryExecute(
      "DELETE FROM floatplan_monitor_events
       WHERE float_plan_id IN (
         SELECT floatPlanId FROM floatplans WHERE floatPlanName LIKE :markerPrefix
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM floatplan_monitoring
       WHERE float_plan_id IN (
         SELECT floatPlanId FROM floatplans WHERE floatPlanName LIKE :markerPrefix
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM floatplan_events
       WHERE floatplan_id IN (
         SELECT floatPlanId FROM floatplans WHERE floatPlanName LIKE :markerPrefix
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM floatplan_contacts
       WHERE floatPlanId IN (
         SELECT floatPlanId FROM floatplans WHERE floatPlanName LIKE :markerPrefix
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM floatplan_vessels
       WHERE floatPlanId IN (
         SELECT floatPlanId FROM floatplans WHERE floatPlanName LIKE :markerPrefix
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM floatplans WHERE floatPlanName LIKE :markerPrefix",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM route_instance_geometry_snapshots
       WHERE route_instance_id IN (
         SELECT id FROM route_instances
         WHERE generated_route_code LIKE 'CTV_%'
           AND user_id IN (SELECT userId FROM users WHERE email LIKE :emailPrefix)
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM route_instance_leg_progress
       WHERE route_instance_id IN (
         SELECT id FROM route_instances
         WHERE generated_route_code LIKE 'CTV_%'
           AND user_id IN (SELECT userId FROM users WHERE email LIKE :emailPrefix)
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM route_instance_legs
       WHERE route_instance_id IN (
         SELECT id FROM route_instances
         WHERE generated_route_code LIKE 'CTV_%'
           AND user_id IN (SELECT userId FROM users WHERE email LIKE :emailPrefix)
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM route_instance_sections
       WHERE route_instance_id IN (
         SELECT id FROM route_instances
         WHERE generated_route_code LIKE 'CTV_%'
           AND user_id IN (SELECT userId FROM users WHERE email LIKE :emailPrefix)
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM route_instances
       WHERE generated_route_code LIKE 'CTV_%'
         AND user_id IN (SELECT userId FROM users WHERE email LIKE :emailPrefix)",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM loop_routes WHERE description LIKE :markerPrefix",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM contacts WHERE userId IN (SELECT userId FROM users WHERE email LIKE :emailPrefix)",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM vessels WHERE userId IN (SELECT userId FROM users WHERE email LIKE :emailPrefix)",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM users WHERE email LIKE :emailPrefix",
      params,
      { datasource = variables.datasource }
    );
  }
}
