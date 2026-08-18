component extends="testbox.system.BaseSpec" output="false" {

  variables.datasource = "fpw";
  variables.fixturePrefix = "codex-qa6004-";

  function beforeAll() {
    cleanupFixtures();
  }

  function afterAll() {
    cleanupFixtures();
  }

  function run() {
    describe("QA6-004 route instance closure contract", function() {

      beforeEach(function() {
        cleanupFixtures();
        variables.service = createObject("component", "fpw.api.v1.RouteProgressService").init();
      });

      afterEach(function() {
        cleanupFixtures();
      });

      it("finalizes only the operational route instance after every expected leg is complete", function() {
        var fixture = createFixture("normal", ["COMPLETED", "COMPLETED", "COMPLETED"]);
        var result = variables.service.finalizeCompletedRouteInstanceForFloatPlan(
          userId = fixture.userId,
          floatPlanId = fixture.floatPlanId,
          datasource = variables.datasource
        );
        var state = loadState(fixture);

        expect(result.SUCCESS).toBeTrue();
        expect(result.FINALIZED).toBeTrue();
        expect(result.ALREADY_COMPLETE).toBeFalse();
        expect(result.ROUTE_INSTANCE_ID).toBe(fixture.operationalRouteInstanceId);
        expect(result.EXPECTED_LEG_COUNT).toBe(3);
        expect(result.COMPLETED_LEG_COUNT).toBe(3);
        expect(state.operational_status[1]).toBe("COMPLETED");
        expect(state.operational_completed_at[1]).notToBeNull();
        expect(dateTimeFormat(state.operational_completed_at[1], "yyyy-mm-dd HH:nn:ss")).toBe(
          dateTimeFormat(state.final_leg_completed_at[1], "yyyy-mm-dd HH:nn:ss")
        );
        expect(state.source_status[1]).toBe("PLANNED");
        expect(len(trim(toString(state.source_completed_at[1])))).toBe(0);
        expect(val(state.route_instance_count[1])).toBe(2);
      });

      it("is idempotent and preserves the original operational completion timestamp", function() {
        var fixture = createFixture("repeat", ["COMPLETED", "COMPLETED", "COMPLETED"]);
        var first = variables.service.finalizeCompletedRouteInstanceForFloatPlan(
          userId = fixture.userId,
          floatPlanId = fixture.floatPlanId,
          datasource = variables.datasource
        );
        var firstState = loadState(fixture);
        var second = variables.service.finalizeCompletedRouteInstanceForFloatPlan(
          userId = fixture.userId,
          floatPlanId = fixture.floatPlanId,
          datasource = variables.datasource
        );
        var secondState = loadState(fixture);

        expect(first.SUCCESS).toBeTrue();
        expect(first.FINALIZED).toBeTrue();
        expect(second.SUCCESS).toBeTrue();
        expect(second.ALREADY_COMPLETE).toBeTrue();
        expect(second.FINALIZED).toBeFalse();
        expect(dateTimeFormat(secondState.operational_completed_at[1], "yyyy-mm-dd HH:nn:ss")).toBe(
          dateTimeFormat(firstState.operational_completed_at[1], "yyyy-mm-dd HH:nn:ss")
        );
        expect(val(secondState.route_instance_count[1])).toBe(2);
      });

      it("refuses finalization while any expected leg remains incomplete", function() {
        var fixture = createFixture("incomplete", ["COMPLETED", "NOT_STARTED", "NOT_STARTED"]);
        var result = variables.service.finalizeCompletedRouteInstanceForFloatPlan(
          userId = fixture.userId,
          floatPlanId = fixture.floatPlanId,
          datasource = variables.datasource
        );
        var state = loadState(fixture);

        expect(result.SUCCESS).toBeFalse();
        expect(result.ERROR).toBe("ROUTE_PROGRESS_INCOMPLETE");
        expect(result.COMPLETED_LEG_COUNT).toBe(1);
        expect(state.operational_status[1]).toBe("ACTIVE");
        expect(len(trim(toString(state.operational_completed_at[1])))).toBe(0);
        expect(state.source_status[1]).toBe("PLANNED");
      });

      it("refuses finalization while a non-completed leg retains started state", function() {
        var fixture = createFixture("started", ["COMPLETED", "IN_PROGRESS", "NOT_STARTED"]);
        var result = variables.service.finalizeCompletedRouteInstanceForFloatPlan(
          userId = fixture.userId,
          floatPlanId = fixture.floatPlanId,
          datasource = variables.datasource
        );
        var state = loadState(fixture);

        expect(result.SUCCESS).toBeFalse();
        expect(result.ERROR).toBe("ROUTE_PROGRESS_INCOMPLETE");
        expect(result.ACTIVE_LEG_COUNT).toBe(1);
        expect(state.operational_status[1]).toBe("ACTIVE");
        expect(len(trim(toString(state.operational_completed_at[1])))).toBe(0);
      });

      it("accepts an already-completed operational route instance without changing its timestamp", function() {
        var fixture = createFixture("already", ["COMPLETED", "COMPLETED", "COMPLETED"], true);
        var beforeState = loadState(fixture);
        var result = variables.service.finalizeCompletedRouteInstanceForFloatPlan(
          userId = fixture.userId,
          floatPlanId = fixture.floatPlanId,
          datasource = variables.datasource
        );
        var afterState = loadState(fixture);

        expect(result.SUCCESS).toBeTrue();
        expect(result.ALREADY_COMPLETE).toBeTrue();
        expect(result.FINALIZED).toBeFalse();
        expect(dateTimeFormat(afterState.operational_completed_at[1], "yyyy-mm-dd HH:nn:ss")).toBe(
          dateTimeFormat(beforeState.operational_completed_at[1], "yyyy-mm-dd HH:nn:ss")
        );
        expect(stateSafeString(afterState.source_status[1])).toBe("PLANNED");
      });

      it("hooks finalization inside the existing float-plan close transaction before CLOSED is persisted", function() {
        var source = fileRead(expandPath("/fpw/api/v1/floatplan.cfc"), "utf-8");
        var functionStart = findNoCase('<cffunction name="checkInFloatPlan"', source);
        var functionEnd = findNoCase("</cffunction>", source, functionStart + 10);
        var closureSource = functionStart GT 0 AND functionEnd GT functionStart
          ? mid(source, functionStart, functionEnd - functionStart)
          : "";
        var transactionPosition = findNoCase("transaction {", closureSource);
        var finalizationPosition = findNoCase("finalizeCompletedRouteInstanceForFloatPlan", closureSource);
        var closeUpdatePosition = findNoCase("`status` = 'CLOSED'", closureSource);

        expect(functionStart).toBeGT(0);
        expect(functionEnd).toBeGT(functionStart);
        expect(transactionPosition).toBeGT(0);
        expect(finalizationPosition).toBeGT(transactionPosition);
        expect(closeUpdatePosition).toBeGT(finalizationPosition);
        expect(findNoCase("SOURCE_ROUTE_INSTANCE_ID", closureSource)).toBe(0);
      });
    });
  }

  private struct function createFixture(
    required string label,
    required array progressStatuses,
    boolean alreadyCompleted=false
  ) {
    var token = lCase(replace(createUUID(), "-", "", "all"));
    var marker = variables.fixturePrefix & token;
    var email = marker & "@example.test";
    var sourceCode = "QA6004_SRC_" & left(token, 12);
    var operationalCode = "QA6004_OP_" & left(token, 12);
    var qUser = queryNew("");
    var qSourceRoute = queryNew("");
    var qOperationalRoute = queryNew("");
    var qSourceInstance = queryNew("");
    var qOperationalInstance = queryNew("");
    var qSection = queryNew("");
    var qPlan = queryNew("");
    var finalCompletedAt = dateAdd("n", -5, now());
    var legOrder = 0;
    var statusValue = "";
    var completedAt = "";
    var startedAt = "";
    var fixture = {};

    if (arrayLen(arguments.progressStatuses) NEQ 3) {
      throw(type="FPW.QA6004Fixture", message="Exactly three progress statuses are required.");
    }

    queryExecute(
      "INSERT INTO users (fName, lName, email, password, passwordCreated, created)
       VALUES ('Codex', 'QA6-004', :email, :password, UTC_TIMESTAMP(), UTC_TIMESTAMP())",
      {
        email = { value=email, cfsqltype="cf_sql_varchar" },
        password = { value=hash(marker, "SHA-256"), cfsqltype="cf_sql_varchar" }
      },
      { datasource=variables.datasource }
    );
    qUser = queryExecute(
      "SELECT userId FROM users WHERE email = :email LIMIT 1",
      { email = { value=email, cfsqltype="cf_sql_varchar" } },
      { datasource=variables.datasource }
    );

    queryExecute(
      "INSERT INTO loop_routes (code, name, short_code, description, is_active)
       VALUES (:sourceCode, :sourceName, :sourceCode, :marker, 1),
              (:operationalCode, :operationalName, :operationalCode, :marker, 1)",
      {
        sourceCode = { value=sourceCode, cfsqltype="cf_sql_varchar" },
        sourceName = { value="QA6-004 Source " & arguments.label, cfsqltype="cf_sql_varchar" },
        operationalCode = { value=operationalCode, cfsqltype="cf_sql_varchar" },
        operationalName = { value="QA6-004 Operational " & arguments.label, cfsqltype="cf_sql_varchar" },
        marker = { value=marker, cfsqltype="cf_sql_varchar" }
      },
      { datasource=variables.datasource }
    );
    qSourceRoute = queryExecute(
      "SELECT id FROM loop_routes WHERE short_code = :code LIMIT 1",
      { code = { value=sourceCode, cfsqltype="cf_sql_varchar" } },
      { datasource=variables.datasource }
    );
    qOperationalRoute = queryExecute(
      "SELECT id FROM loop_routes WHERE short_code = :code LIMIT 1",
      { code = { value=operationalCode, cfsqltype="cf_sql_varchar" } },
      { datasource=variables.datasource }
    );

    queryExecute(
      "INSERT INTO route_instances
          (user_id, template_route_code, generated_route_id, generated_route_code,
           direction, trip_type, start_location, end_location, routegen_inputs_json,
           status, started_at, completed_at)
       VALUES
          (:userId, :sourceCode, :sourceRouteId, :sourceCode,
           'CCW', 'POINT_TO_POINT', 'A', 'D', :sourceInputs,
           'PLANNED', NULL, NULL),
          (:userId, :sourceCode, :operationalRouteId, :operationalCode,
           'CCW', 'POINT_TO_POINT', 'A', 'D', :operationalInputs,
           :operationalStatus, DATE_SUB(UTC_TIMESTAMP(), INTERVAL 3 HOUR), :routeCompletedAt)",
      {
        userId = { value=toString(val(qUser.userId[1])), cfsqltype="cf_sql_varchar" },
        sourceCode = { value=sourceCode, cfsqltype="cf_sql_varchar" },
        sourceRouteId = { value=val(qSourceRoute.id[1]), cfsqltype="cf_sql_integer" },
        operationalRouteId = { value=val(qOperationalRoute.id[1]), cfsqltype="cf_sql_integer" },
        operationalCode = { value=operationalCode, cfsqltype="cf_sql_varchar" },
        sourceInputs = { value=serializeJSON({ fixture_marker=marker }), cfsqltype="cf_sql_longvarchar" },
        operationalInputs = {
          value=serializeJSON({ fixture_marker=marker, source_route_instance_id=0 }),
          cfsqltype="cf_sql_longvarchar"
        },
        operationalStatus = {
          value=arguments.alreadyCompleted ? "COMPLETED" : "ACTIVE",
          cfsqltype="cf_sql_varchar"
        },
        routeCompletedAt = {
          value=finalCompletedAt,
          null=!arguments.alreadyCompleted,
          cfsqltype="cf_sql_timestamp"
        }
      },
      { datasource=variables.datasource }
    );
    qSourceInstance = queryExecute(
      "SELECT id FROM route_instances WHERE generated_route_code = :code LIMIT 1",
      { code = { value=sourceCode, cfsqltype="cf_sql_varchar" } },
      { datasource=variables.datasource }
    );
    qOperationalInstance = queryExecute(
      "SELECT id FROM route_instances WHERE generated_route_code = :code LIMIT 1",
      { code = { value=operationalCode, cfsqltype="cf_sql_varchar" } },
      { datasource=variables.datasource }
    );

    queryExecute(
      "UPDATE route_instances
       SET routegen_inputs_json = :inputsJson
       WHERE id = :routeInstanceId",
      {
        inputsJson = {
          value=serializeJSON({
            fixture_marker=marker,
            source_route_instance_id=val(qSourceInstance.id[1])
          }),
          cfsqltype="cf_sql_longvarchar"
        },
        routeInstanceId = { value=val(qOperationalInstance.id[1]), cfsqltype="cf_sql_integer" }
      },
      { datasource=variables.datasource }
    );

    queryExecute(
      "INSERT INTO route_instance_sections (route_instance_id, section_order, name, phase_num)
       VALUES (:routeInstanceId, 1, 'QA6-004 Section', 1)",
      { routeInstanceId = { value=val(qOperationalInstance.id[1]), cfsqltype="cf_sql_integer" } },
      { datasource=variables.datasource }
    );
    qSection = queryExecute(
      "SELECT id FROM route_instance_sections
       WHERE route_instance_id = :routeInstanceId AND section_order = 1 LIMIT 1",
      { routeInstanceId = { value=val(qOperationalInstance.id[1]), cfsqltype="cf_sql_integer" } },
      { datasource=variables.datasource }
    );

    for (legOrder = 1; legOrder LTE 3; legOrder++) {
      statusValue = uCase(trim(toString(arguments.progressStatuses[legOrder])));
      completedAt = dateAdd("n", -5 * (4 - legOrder), finalCompletedAt);
      startedAt = dateAdd("n", -15 * (4 - legOrder), finalCompletedAt);
      queryExecute(
        "INSERT INTO route_instance_legs
            (route_instance_id, route_instance_section_id, leg_order,
             is_reversed, is_optional, start_name, end_name, base_dist_nm, lock_count)
         VALUES
            (:routeInstanceId, :sectionId, :legOrder, 0, 0,
             :startName, :endName, 10.00, 0)",
        {
          routeInstanceId = { value=val(qOperationalInstance.id[1]), cfsqltype="cf_sql_integer" },
          sectionId = { value=val(qSection.id[1]), cfsqltype="cf_sql_integer" },
          legOrder = { value=legOrder, cfsqltype="cf_sql_integer" },
          startName = { value=chr(64 + legOrder), cfsqltype="cf_sql_varchar" },
          endName = { value=chr(65 + legOrder), cfsqltype="cf_sql_varchar" }
        },
        { datasource=variables.datasource }
      );
      queryExecute(
        "INSERT INTO route_instance_leg_progress
            (user_id, route_instance_id, leg_order, status, leg_started_at, completed_at)
         VALUES
            (:userId, :routeInstanceId, :legOrder, :status, :startedAt, :completedAt)",
        {
          userId = { value=val(qUser.userId[1]), cfsqltype="cf_sql_integer" },
          routeInstanceId = { value=val(qOperationalInstance.id[1]), cfsqltype="cf_sql_integer" },
          legOrder = { value=legOrder, cfsqltype="cf_sql_integer" },
          status = { value=statusValue, cfsqltype="cf_sql_varchar" },
          startedAt = {
            value=startedAt,
            null=(statusValue EQ "NOT_STARTED"),
            cfsqltype="cf_sql_timestamp"
          },
          completedAt = {
            value=(legOrder EQ 3 ? finalCompletedAt : completedAt),
            null=(statusValue NEQ "COMPLETED"),
            cfsqltype="cf_sql_timestamp"
          }
        },
        { datasource=variables.datasource }
      );
    }

    queryExecute(
      "INSERT INTO floatplans
          (userId, floatPlanName, dateCreated, lastUpdate, status,
           lastUpdateStatus, route_instance_id, route_day_number, activatedAt)
       VALUES
          (:userId, :planName, UTC_TIMESTAMP(), UTC_TIMESTAMP(), 'ACTIVE',
           UTC_TIMESTAMP(), :routeInstanceId, 1, DATE_SUB(UTC_TIMESTAMP(), INTERVAL 3 HOUR))",
      {
        userId = { value=toString(val(qUser.userId[1])), cfsqltype="cf_sql_varchar" },
        planName = { value="QA6-004 " & arguments.label, cfsqltype="cf_sql_varchar" },
        routeInstanceId = { value=val(qOperationalInstance.id[1]), cfsqltype="cf_sql_integer" }
      },
      { datasource=variables.datasource }
    );
    qPlan = queryExecute(
      "SELECT floatPlanId FROM floatplans
       WHERE userId = :userId AND route_instance_id = :routeInstanceId
       ORDER BY floatPlanId DESC LIMIT 1",
      {
        userId = { value=toString(val(qUser.userId[1])), cfsqltype="cf_sql_varchar" },
        routeInstanceId = { value=val(qOperationalInstance.id[1]), cfsqltype="cf_sql_integer" }
      },
      { datasource=variables.datasource }
    );

    fixture = {
      marker=marker,
      email=email,
      userId=val(qUser.userId[1]),
      sourceRouteInstanceId=val(qSourceInstance.id[1]),
      operationalRouteInstanceId=val(qOperationalInstance.id[1]),
      floatPlanId=val(qPlan.floatPlanId[1])
    };
    return fixture;
  }

  private query function loadState(required struct fixture) {
    return queryExecute(
      "SELECT
          UPPER(TRIM(op.status)) AS operational_status,
          op.completed_at AS operational_completed_at,
          UPPER(TRIM(src.status)) AS source_status,
          src.completed_at AS source_completed_at,
          final_progress.completed_at AS final_leg_completed_at,
          (SELECT COUNT(*) FROM route_instances WHERE user_id = :userId) AS route_instance_count
       FROM route_instances op
       INNER JOIN route_instances src ON src.id = :sourceRouteInstanceId
       INNER JOIN route_instance_leg_progress final_progress
          ON final_progress.route_instance_id = op.id
         AND final_progress.leg_order = 3
         AND final_progress.user_id = :userId
       WHERE op.id = :operationalRouteInstanceId
         AND op.user_id = :userId
       LIMIT 1",
      {
        userId = { value=arguments.fixture.userId, cfsqltype="cf_sql_integer" },
        sourceRouteInstanceId = {
          value=arguments.fixture.sourceRouteInstanceId,
          cfsqltype="cf_sql_integer"
        },
        operationalRouteInstanceId = {
          value=arguments.fixture.operationalRouteInstanceId,
          cfsqltype="cf_sql_integer"
        }
      },
      { datasource=variables.datasource }
    );
  }

  private string function stateSafeString(required any value) {
    return trim(toString(arguments.value));
  }

  private void function cleanupFixtures() {
    queryExecute(
      "DELETE FROM floatplans
       WHERE userId IN (
         SELECT userId FROM users WHERE email LIKE :emailPrefix
       )",
      { emailPrefix = { value=variables.fixturePrefix & "%", cfsqltype="cf_sql_varchar" } },
      { datasource=variables.datasource }
    );
    queryExecute(
      "DELETE FROM route_instance_leg_progress
       WHERE user_id IN (
         SELECT userId FROM users WHERE email LIKE :emailPrefix
       )",
      { emailPrefix = { value=variables.fixturePrefix & "%", cfsqltype="cf_sql_varchar" } },
      { datasource=variables.datasource }
    );
    queryExecute(
      "DELETE FROM route_instance_legs
       WHERE route_instance_id IN (
         SELECT id FROM route_instances
         WHERE user_id IN (
           SELECT userId FROM users WHERE email LIKE :emailPrefix
         )
       )",
      { emailPrefix = { value=variables.fixturePrefix & "%", cfsqltype="cf_sql_varchar" } },
      { datasource=variables.datasource }
    );
    queryExecute(
      "DELETE FROM route_instance_sections
       WHERE route_instance_id IN (
         SELECT id FROM route_instances
         WHERE user_id IN (
           SELECT userId FROM users WHERE email LIKE :emailPrefix
         )
       )",
      { emailPrefix = { value=variables.fixturePrefix & "%", cfsqltype="cf_sql_varchar" } },
      { datasource=variables.datasource }
    );
    queryExecute(
      "DELETE FROM route_instances
       WHERE user_id IN (
         SELECT userId FROM users WHERE email LIKE :emailPrefix
       )",
      { emailPrefix = { value=variables.fixturePrefix & "%", cfsqltype="cf_sql_varchar" } },
      { datasource=variables.datasource }
    );
    queryExecute(
      "DELETE FROM loop_routes WHERE description LIKE :descriptionPrefix",
      { descriptionPrefix = { value=variables.fixturePrefix & "%", cfsqltype="cf_sql_varchar" } },
      { datasource=variables.datasource }
    );
    queryExecute(
      "DELETE FROM users WHERE email LIKE :emailPrefix",
      { emailPrefix = { value=variables.fixturePrefix & "%", cfsqltype="cf_sql_varchar" } },
      { datasource=variables.datasource }
    );
  }
}
