component extends="testbox.system.BaseSpec" output="false" {

  variables.datasource = "fpw";
  variables.fixtureEmailPrefix = "codex-route-archive-contract-";

  function beforeAll() {
    cleanupFixtures();
  }

  function afterAll() {
    cleanupFixtures();
  }

  function run() {
    describe("Generated route archive contract", function() {

      beforeEach(function() {
        cleanupFixtures();
        variables.routeBuilder = createObject("component", "fpw.api.v1.routeBuilder");
        makePublic(variables.routeBuilder, "archiveRoute", "archiveRouteForTest");
        makePublic(variables.routeBuilder, "deleteRoute", "deleteRouteForTest");
      });

      afterEach(function() {
        cleanupFixtures();
      });

      it("archives a protected inactive route without deleting retained Premium Send records", function() {
        var fixture = createFixture("protected-inactive", true, "CANCELLED");
        var blockedDelete = variables.routeBuilder.deleteRouteForTest(
          fixture.userId,
          fixture.routeCode
        );
        var archived = variables.routeBuilder.archiveRouteForTest(
          fixture.userId,
          fixture.routeCode
        );
        var state = loadFixtureState(fixture);

        expect(blockedDelete.SUCCESS).toBeFalse();
        expect(blockedDelete.ERROR.CODE).toBe("PREMIUM_SEND_HISTORY_DELETE_BLOCKED");
        expect(archived.SUCCESS).toBeTrue();
        expect(archived.ROUTE_CODE).toBe(fixture.routeCode);
        expect(val(state.is_active[1])).toBe(0);
        expect(val(state.route_instance_count[1])).toBe(1);
        expect(val(state.float_plan_count[1])).toBe(1);
        expect(val(state.credit_count[1])).toBe(1);
        expect(val(state.receipt_count[1])).toBe(1);
      });

      it("refuses to archive a route whose attached float plan is active", function() {
        var fixture = createFixture("protected-active", true, "ACTIVE");
        var archived = variables.routeBuilder.archiveRouteForTest(
          fixture.userId,
          fixture.routeCode
        );
        var state = loadFixtureState(fixture);

        expect(archived.SUCCESS).toBeFalse();
        expect(archived.ERROR.CODE).toBe("ACTIVE_ROUTE_ARCHIVE_BLOCKED");
        expect(val(state.is_active[1])).toBe(1);
        expect(val(state.route_instance_count[1])).toBe(1);
        expect(val(state.float_plan_count[1])).toBe(1);
        expect(val(state.credit_count[1])).toBe(1);
        expect(val(state.receipt_count[1])).toBe(1);
      });

      it("keeps archive limited to routes that require retained Premium Send history", function() {
        var fixture = createFixture("ordinary-route", false, "CANCELLED");
        var archived = variables.routeBuilder.archiveRouteForTest(
          fixture.userId,
          fixture.routeCode
        );
        var state = loadFixtureState(fixture);

        expect(archived.SUCCESS).toBeFalse();
        expect(archived.ERROR.CODE).toBe("ROUTE_ARCHIVE_NOT_REQUIRED");
        expect(val(state.is_active[1])).toBe(1);
        expect(val(state.route_instance_count[1])).toBe(1);
        expect(val(state.float_plan_count[1])).toBe(0);
        expect(val(state.credit_count[1])).toBe(0);
        expect(val(state.receipt_count[1])).toBe(0);
      });

      it("publishes archive policy metadata and excludes archived routes from the normal list query", function() {
        var source = fileRead(expandPath("/fpw/api/v1/routeBuilder.cfc"), "utf-8");
        var listStart = findNoCase('<cffunction name="listUserRoutes"', source);
        var listEnd = findNoCase("</cffunction>", source, listStart);
        var listSource = mid(source, listStart, listEnd - listStart);

        expect(listStart).toBeGT(0);
        expect(listEnd).toBeGT(listStart);
        expect(findNoCase("AND lr.is_active = 1", listSource)).toBeGT(0);
        expect(findNoCase('"CAN_DELETE"=canDelete', listSource)).toBeGT(0);
        expect(findNoCase('"CAN_ARCHIVE"=canArchive', listSource)).toBeGT(0);
        expect(findNoCase('"HAS_PREMIUM_SEND_HISTORY"=hasPremiumSendHistory', listSource)).toBeGT(0);
        expect(findNoCase("deleteroute,archiveroute,gettimeline", source)).toBeGT(0);
      });
    });
  }

  private struct function createFixture(
    required string label,
    required boolean withPremiumHistory,
    required string planStatus
  ) {
    var token = lCase(replace(createUUID(), "-", "", "all"));
    var marker = variables.fixtureEmailPrefix & token;
    var email = marker & "@example.test";
    var qUser = queryNew("");
    var qRoute = queryNew("");
    var qRouteInstance = queryNew("");
    var qPlan = queryNew("");
    var qCredit = queryNew("");
    var fixture = {};

    queryExecute(
      "INSERT INTO users (
         fName,
         lName,
         email,
         password,
         passwordCreated,
         created
       ) VALUES (
         'Codex Route Archive',
         'Contract Test',
         :email,
         :password,
         UTC_TIMESTAMP(),
         UTC_TIMESTAMP()
       )",
      {
        email = { value=email, cfsqltype="cf_sql_varchar" },
        password = { value=hash("not-a-login-" & token, "SHA-256"), cfsqltype="cf_sql_varchar" }
      },
      { datasource=variables.datasource }
    );

    qUser = queryExecute(
      "SELECT userId FROM users WHERE email = :email LIMIT 1",
      { email = { value=email, cfsqltype="cf_sql_varchar" } },
      { datasource=variables.datasource }
    );
    if (qUser.recordCount NEQ 1) {
      throw(type="FPW.RouteArchiveFixture", message="Disposable route archive user was not created.");
    }

    fixture = {
      marker=marker,
      email=email,
      userId=val(qUser.userId[1])
    };
    fixture.routeCode = "USER_ROUTE_" & fixture.userId & "_ARC_" & left(token, 10);

    queryExecute(
      "INSERT INTO loop_routes (code, name, short_code, description, is_active)
       VALUES (:code, :name, :shortCode, :description, 1)",
      {
        code = { value=fixture.routeCode, cfsqltype="cf_sql_varchar" },
        name = { value="Route Archive " & arguments.label, cfsqltype="cf_sql_varchar" },
        shortCode = { value=fixture.routeCode, cfsqltype="cf_sql_varchar" },
        description = { value=marker, cfsqltype="cf_sql_varchar" }
      },
      { datasource=variables.datasource }
    );
    qRoute = queryExecute(
      "SELECT id FROM loop_routes WHERE short_code = :shortCode LIMIT 1",
      { shortCode = { value=fixture.routeCode, cfsqltype="cf_sql_varchar" } },
      { datasource=variables.datasource }
    );
    fixture.routeId = val(qRoute.id[1]);

    queryExecute(
      "INSERT INTO route_instances (
         user_id,
         template_route_code,
         generated_route_id,
         generated_route_code,
         direction,
         trip_type,
         start_location,
         end_location,
         status
       ) VALUES (
         :userId,
         :routeCode,
         :routeId,
         :routeCode,
         'CCW',
         'POINT_TO_POINT',
         'Archive Test Start',
         'Archive Test End',
         'PLANNED'
       )",
      {
        userId = { value=toString(fixture.userId), cfsqltype="cf_sql_varchar" },
        routeCode = { value=fixture.routeCode, cfsqltype="cf_sql_varchar" },
        routeId = { value=fixture.routeId, cfsqltype="cf_sql_integer" }
      },
      { datasource=variables.datasource }
    );
    qRouteInstance = queryExecute(
      "SELECT id
       FROM route_instances
       WHERE user_id = :userId
         AND generated_route_id = :routeId
       ORDER BY id DESC
       LIMIT 1",
      {
        userId = { value=toString(fixture.userId), cfsqltype="cf_sql_varchar" },
        routeId = { value=fixture.routeId, cfsqltype="cf_sql_integer" }
      },
      { datasource=variables.datasource }
    );
    fixture.routeInstanceId = val(qRouteInstance.id[1]);
    fixture.floatPlanId = 0;
    fixture.creditId = 0;

    if (!arguments.withPremiumHistory) {
      return fixture;
    }

    queryExecute(
      "INSERT INTO floatplans (
         userId,
         floatPlanName,
         dateCreated,
         lastUpdate,
         status,
         lastUpdateStatus,
         route_instance_id,
         route_day_number
       ) VALUES (
         :userId,
         :planName,
         UTC_TIMESTAMP(),
         UTC_TIMESTAMP(),
         :planStatus,
         UTC_TIMESTAMP(),
         :routeInstanceId,
         1
       )",
      {
        userId = { value=toString(fixture.userId), cfsqltype="cf_sql_varchar" },
        planName = { value="Route Archive " & arguments.label, cfsqltype="cf_sql_varchar" },
        planStatus = { value=uCase(trim(arguments.planStatus)), cfsqltype="cf_sql_varchar" },
        routeInstanceId = { value=fixture.routeInstanceId, cfsqltype="cf_sql_integer" }
      },
      { datasource=variables.datasource }
    );
    qPlan = queryExecute(
      "SELECT floatPlanId
       FROM floatplans
       WHERE userId = :userId
         AND route_instance_id = :routeInstanceId
       ORDER BY floatPlanId DESC
       LIMIT 1",
      {
        userId = { value=toString(fixture.userId), cfsqltype="cf_sql_varchar" },
        routeInstanceId = { value=fixture.routeInstanceId, cfsqltype="cf_sql_integer" }
      },
      { datasource=variables.datasource }
    );
    fixture.floatPlanId = val(qPlan.floatPlanId[1]);

    queryExecute(
      "INSERT INTO premium_send_credits (
         user_id,
         source,
         status,
         consumed_float_plan_id,
         idempotency_key,
         granted_at_utc,
         consumed_at_utc,
         created_at_utc,
         updated_at_utc
       ) VALUES (
         :userId,
         'complimentary_signup',
         'CONSUMED',
         :floatPlanId,
         :idempotencyKey,
         UTC_TIMESTAMP(6),
         UTC_TIMESTAMP(6),
         UTC_TIMESTAMP(6),
         UTC_TIMESTAMP(6)
       )",
      {
        userId = { value=fixture.userId, cfsqltype="cf_sql_integer" },
        floatPlanId = { value=fixture.floatPlanId, cfsqltype="cf_sql_integer" },
        idempotencyKey = { value=marker & ":credit", cfsqltype="cf_sql_varchar" }
      },
      { datasource=variables.datasource }
    );
    qCredit = queryExecute(
      "SELECT id FROM premium_send_credits WHERE idempotency_key = :idempotencyKey LIMIT 1",
      { idempotencyKey = { value=marker & ":credit", cfsqltype="cf_sql_varchar" } },
      { datasource=variables.datasource }
    );
    fixture.creditId = val(qCredit.id[1]);

    queryExecute(
      "INSERT INTO premium_send_receipts (
         user_id,
         float_plan_id,
         credit_id,
         access_source,
         access_started_at_utc,
         access_expires_at_utc,
         recipient_count,
         original_response_json,
         committed_at_utc,
         created_at_utc
       ) VALUES (
         :userId,
         :floatPlanId,
         :creditId,
         'premium_send_credit',
         UTC_TIMESTAMP(6),
         DATE_ADD(UTC_TIMESTAMP(6), INTERVAL 21 DAY),
         1,
         :responseJson,
         UTC_TIMESTAMP(6),
         UTC_TIMESTAMP(6)
       )",
      {
        userId = { value=fixture.userId, cfsqltype="cf_sql_integer" },
        floatPlanId = { value=fixture.floatPlanId, cfsqltype="cf_sql_integer" },
        creditId = { value=fixture.creditId, cfsqltype="cf_sql_bigint" },
        responseJson = { value=serializeJSON({ SUCCESS=true, marker=marker }), cfsqltype="cf_sql_longvarchar" }
      },
      { datasource=variables.datasource }
    );

    return fixture;
  }

  private query function loadFixtureState(required struct fixture) {
    return queryExecute(
      "SELECT
          lr.is_active,
          (SELECT COUNT(*) FROM route_instances ri WHERE ri.id = :routeInstanceId) AS route_instance_count,
          (SELECT COUNT(*) FROM floatplans fp WHERE fp.route_instance_id = :routeInstanceId) AS float_plan_count,
          (SELECT COUNT(*) FROM premium_send_credits psc WHERE psc.user_id = :userId) AS credit_count,
          (SELECT COUNT(*) FROM premium_send_receipts psr WHERE psr.user_id = :userId) AS receipt_count
       FROM loop_routes lr
       WHERE lr.id = :routeId
       LIMIT 1",
      {
        routeInstanceId = { value=arguments.fixture.routeInstanceId, cfsqltype="cf_sql_integer" },
        userId = { value=arguments.fixture.userId, cfsqltype="cf_sql_integer" },
        routeId = { value=arguments.fixture.routeId, cfsqltype="cf_sql_integer" }
      },
      { datasource=variables.datasource }
    );
  }

  private void function cleanupFixtures() {
    var emailPattern = variables.fixtureEmailPrefix & "%";
    var params = {
      emailPattern = { value=emailPattern, cfsqltype="cf_sql_varchar" }
    };

    queryExecute(
      "DELETE FROM premium_send_receipts
       WHERE user_id IN (SELECT userId FROM users WHERE email LIKE :emailPattern)",
      params,
      { datasource=variables.datasource }
    );
    queryExecute(
      "DELETE FROM premium_send_credits
       WHERE user_id IN (SELECT userId FROM users WHERE email LIKE :emailPattern)",
      params,
      { datasource=variables.datasource }
    );
    queryExecute(
      "DELETE FROM floatplans
       WHERE CAST(userId AS UNSIGNED) IN (
         SELECT userId FROM users WHERE email LIKE :emailPattern
       )",
      params,
      { datasource=variables.datasource }
    );
    queryExecute(
      "DELETE FROM route_instances
       WHERE CAST(user_id AS UNSIGNED) IN (
         SELECT userId FROM users WHERE email LIKE :emailPattern
       )",
      params,
      { datasource=variables.datasource }
    );
    queryExecute(
      "DELETE FROM loop_routes
       WHERE description LIKE :emailPattern",
      params,
      { datasource=variables.datasource }
    );
    queryExecute(
      "DELETE FROM users WHERE email LIKE :emailPattern",
      params,
      { datasource=variables.datasource }
    );
  }
}
