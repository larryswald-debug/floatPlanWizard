component extends="testbox.system.BaseSpec" output="false" {

  variables.datasource = "fpw";
  variables.fixturePrefix = "codex-scheduled-actual-route-draft-";

  function beforeAll() {
    cleanupFixtures();
  }

  function afterAll() {
    cleanupFixtures();
  }

  function run() {
    describe("Scheduled versus actual departure Draft route assignment", function() {

      beforeEach(function() {
        cleanupFixtures();
        variables.routeBuilder = createObject("component", "fpw.api.v1.routeBuilder");
        makePublic(
          variables.routeBuilder,
          "buildFloatPlansFromRoute",
          "buildFloatPlansFromRouteForTest"
        );
        variables.floatPlanService = createObject("component", "fpw.api.v1.floatplan");
        makePublic(
          variables.floatPlanService,
          "ensureCleanRouteInstanceForActivation",
          "ensureCleanRouteInstanceForActivationForTest"
        );
      });

      afterEach(function() {
        cleanupFixtures();
      });

      it("keeps one clean unstarted source route for a new Draft group", function() {
        var fixture = createRouteFixture(
          label = "clean-source",
          routeStarted = false,
          progressStarted = false,
          createClosedPlan = false
        );
        var routeCountBefore = countUserRouteInstances(fixture.userId);
        var result = variables.routeBuilder.buildFloatPlansFromRouteForTest(
          userId = fixture.userId,
          routeInstanceId = fixture.sourceRouteInstanceId,
          routeCode = fixture.routeCode,
          mode = "SINGLE_MASTER",
          vesselId = fixture.vesselId,
          rebuild = false
        );
        var groupState = loadPlanGroupState(fixture.userId, result.FLOATPLAN_IDS);
        var sourceState = loadRouteState(fixture.userId, fixture.sourceRouteInstanceId);
        var progressState = loadProgressState(fixture.userId, fixture.sourceRouteInstanceId);

        expect(result.SUCCESS).toBeTrue();
        expect(arrayLen(result.FLOATPLAN_IDS)).toBeGT(0);
        expect(val(result.ROUTE_INSTANCE_ID)).toBe(fixture.sourceRouteInstanceId);
        expect(countUserRouteInstances(fixture.userId)).toBe(routeCountBefore);
        expect(val(groupState.plan_count[1])).toBe(arrayLen(result.FLOATPLAN_IDS));
        expect(val(groupState.draft_count[1])).toBe(arrayLen(result.FLOATPLAN_IDS));
        expect(val(groupState.distinct_route_count[1])).toBe(1);
        expect(val(groupState.min_route_instance_id[1])).toBe(fixture.sourceRouteInstanceId);
        expect(val(groupState.max_route_instance_id[1])).toBe(fixture.sourceRouteInstanceId);
        expect(val(sourceState.started_is_null[1])).toBe(1);
        expect(uCase(trim(toString(sourceState.status[1])))).toBe("PLANNED");
        assertCleanProgress(progressState, 2);
      });

      it("assigns every new Draft to one fresh clean route when the selected source has already started", function() {
        var fixture = createRouteFixture(
          label = "started-history",
          routeStarted = true,
          progressStarted = true,
          createClosedPlan = true
        );
        var routeCountBefore = countUserRouteInstances(fixture.userId);
        var result = variables.routeBuilder.buildFloatPlansFromRouteForTest(
          userId = fixture.userId,
          routeInstanceId = fixture.sourceRouteInstanceId,
          routeCode = fixture.routeCode,
          mode = "SINGLE_MASTER",
          vesselId = fixture.vesselId,
          rebuild = false
        );
        var preparedRouteInstanceId = val(result.ROUTE_INSTANCE_ID);
        var groupState = loadPlanGroupState(fixture.userId, result.FLOATPLAN_IDS);
        var sourceState = loadRouteState(fixture.userId, fixture.sourceRouteInstanceId);
        var freshState = loadRouteState(fixture.userId, preparedRouteInstanceId);
        var sourceProgress = loadProgressState(fixture.userId, fixture.sourceRouteInstanceId);
        var freshProgress = loadProgressState(fixture.userId, preparedRouteInstanceId);
        var historicalPlan = loadPlanState(fixture.userId, fixture.historicalFloatPlanId);
        var routeCountBeforeActivationSafety = 0;
        var activationSafety = {};
        var sourceScopedGroup = {};
        var routeCountBeforeReuse = 0;
        var reuseResult = {};
        var routeBuilderSource = readRepoFile("api/v1/routeBuilder.cfc");

        expect(result.SUCCESS).toBeTrue();
        expect(arrayLen(result.FLOATPLAN_IDS)).toBeGT(0);
        expect(preparedRouteInstanceId).notToBe(fixture.sourceRouteInstanceId);
        expect(countUserRouteInstances(fixture.userId)).toBe(routeCountBefore + 1);
        expect(val(groupState.plan_count[1])).toBe(arrayLen(result.FLOATPLAN_IDS));
        expect(val(groupState.draft_count[1])).toBe(arrayLen(result.FLOATPLAN_IDS));
        expect(val(groupState.distinct_route_count[1])).toBe(1);
        expect(val(groupState.min_route_instance_id[1])).toBe(preparedRouteInstanceId);
        expect(val(groupState.max_route_instance_id[1])).toBe(preparedRouteInstanceId);
        expect(val(sourceState.started_is_null[1])).toBe(0);
        expect(val(sourceProgress.operational_count[1])).toBeGT(0);
        expect(val(freshState.started_is_null[1])).toBe(1);
        expect(uCase(trim(toString(freshState.status[1])))).toBe("PLANNED");
        expect(val(freshProgress.leg_count[1])).toBe(val(sourceProgress.leg_count[1]));
        assertCleanProgress(freshProgress, 2);
        expect(historicalPlan.recordCount).toBe(1);
        expect(uCase(trim(toString(historicalPlan.status[1])))).toBe("CLOSED");
        expect(val(historicalPlan.route_instance_id[1])).toBe(fixture.sourceRouteInstanceId);
        expect(findNoCase("prepareDraftRouteInstanceForEditing", routeBuilderSource)).toBeGT(0);

        sourceScopedGroup = variables.floatPlanService.resolveCurrentRouteFloatPlanGroup(
          fixture.userId,
          fixture.sourceRouteInstanceId
        );
        expect(sourceScopedGroup.SUCCESS).toBeTrue();
        expect(sourceScopedGroup.HAS_CURRENT_GROUP).toBeTrue();
        expect(sourceScopedGroup.IS_DRAFT).toBeTrue();
        expect(sourceScopedGroup.IS_ROUTE_MATCH).toBeTrue();
        expect(val(sourceScopedGroup.FLOATPLANID)).toBe(val(result.FLOATPLAN_IDS[1]));
        expect(val(sourceScopedGroup.ROUTE_INSTANCE_ID)).toBe(preparedRouteInstanceId);

        routeCountBeforeReuse = countUserRouteInstances(fixture.userId);
        reuseResult = variables.routeBuilder.buildFloatPlansFromRouteForTest(
          userId = fixture.userId,
          routeInstanceId = fixture.sourceRouteInstanceId,
          routeCode = fixture.routeCode,
          mode = "SINGLE_MASTER",
          vesselId = fixture.vesselId,
          rebuild = false
        );
        expect(reuseResult.SUCCESS).toBeTrue();
        expect(reuseResult.REUSED_EXISTING).toBeTrue();
        expect(arrayLen(reuseResult.FLOATPLAN_IDS)).toBe(1);
        expect(val(reuseResult.FLOATPLAN_IDS[1])).toBe(val(result.FLOATPLAN_IDS[1]));
        expect(val(reuseResult.ROUTE_INSTANCE_ID)).toBe(preparedRouteInstanceId);
        expect(countUserRouteInstances(fixture.userId)).toBe(routeCountBeforeReuse);

        routeCountBeforeActivationSafety = countUserRouteInstances(fixture.userId);
        activationSafety = variables.floatPlanService.ensureCleanRouteInstanceForActivationForTest(
          userId = fixture.userId,
          floatPlanId = val(result.FLOATPLAN_IDS[1]),
          routeInstanceId = preparedRouteInstanceId
        );
        expect(activationSafety.SUCCESS).toBeTrue();
        expect(activationSafety.CREATED_FRESH).toBeFalse();
        expect(val(activationSafety.ROUTE_INSTANCE_ID)).toBe(preparedRouteInstanceId);
        expect(countUserRouteInstances(fixture.userId)).toBe(routeCountBeforeActivationSafety);
      });

      it("retains activation-time repair for a legacy Draft linked directly to a route-start-only source", function() {
        var fixture = createRouteFixture(
          label = "legacy-route-start-only",
          routeStarted = true,
          progressStarted = false,
          createClosedPlan = false
        );
        var draftFloatPlanId = createDraftPlan(
          fixture,
          "Legacy Draft linked to started route"
        );
        var routeCountBefore = countUserRouteInstances(fixture.userId);
        var result = variables.floatPlanService.ensureCleanRouteInstanceForActivationForTest(
          userId = fixture.userId,
          floatPlanId = draftFloatPlanId,
          routeInstanceId = fixture.sourceRouteInstanceId
        );
        var freshRouteInstanceId = val(result.ROUTE_INSTANCE_ID);
        var draftState = loadPlanState(fixture.userId, draftFloatPlanId);
        var sourceState = loadRouteState(fixture.userId, fixture.sourceRouteInstanceId);
        var freshState = loadRouteState(fixture.userId, freshRouteInstanceId);
        var sourceProgress = loadProgressState(fixture.userId, fixture.sourceRouteInstanceId);
        var freshProgress = loadProgressState(fixture.userId, freshRouteInstanceId);
        var floatPlanSource = readRepoFile("api/v1/floatplan.cfc");

        expect(result.SUCCESS).toBeTrue();
        expect(result.CREATED_FRESH).toBeTrue();
        expect(val(result.ORIGINAL_ROUTE_INSTANCE_ID)).toBe(fixture.sourceRouteInstanceId);
        expect(freshRouteInstanceId).notToBe(fixture.sourceRouteInstanceId);
        expect(countUserRouteInstances(fixture.userId)).toBe(routeCountBefore + 1);
        expect(draftState.recordCount).toBe(1);
        expect(uCase(trim(toString(draftState.status[1])))).toBe("DRAFT");
        expect(val(draftState.route_instance_id[1])).toBe(freshRouteInstanceId);
        expect(val(sourceState.started_is_null[1])).toBe(0);
        assertCleanProgress(sourceProgress, 2);
        expect(val(freshState.started_is_null[1])).toBe(1);
        expect(uCase(trim(toString(freshState.status[1])))).toBe("PLANNED");
        assertCleanProgress(freshProgress, 2);
        expect(findNoCase(
          "routeActivationResult = ensureCleanRouteInstanceForActivation(",
          floatPlanSource
        )).toBeGT(0);
        expect(findNoCase(
          "routeInstanceId = routeActivationResult.ROUTE_INSTANCE_ID",
          floatPlanSource
        )).toBeGT(0);
      });

    });
  }

  private struct function createRouteFixture(
    required string label,
    required boolean routeStarted,
    required boolean progressStarted,
    required boolean createClosedPlan
  ) {
    var token = lCase(reReplace(createUUID(), "[^A-Za-z0-9]", "", "all"));
    var marker = variables.fixturePrefix & token;
    var email = marker & "@example.test";
    var routeCode = left("SADR_" & token, 40);
    var routeName = left(marker & "-route", 160);
    var qUser = queryNew("");
    var qVessel = queryNew("");
    var qRoute = queryNew("");
    var qInstance = queryNew("");
    var qSection = queryNew("");
    var qHistoricalPlan = queryNew("");
    var fixture = {};
    var legOrder = 0;

    queryExecute(
      "INSERT INTO users (fName, lName, email, password, passwordCreated, created)
       VALUES ('Codex', 'Route Draft', :email, :password, UTC_TIMESTAMP(), UTC_TIMESTAMP())",
      {
        email = { value = email, cfsqltype = "cf_sql_varchar" },
        password = { value = hash(marker, "SHA-256"), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    qUser = queryExecute(
      "SELECT userId FROM users WHERE email = :email LIMIT 1",
      { email = { value = email, cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );

    queryExecute(
      "INSERT INTO vessels (userId, vesselName, hailingPort, isDefaultVessel, timezone)
       VALUES (:userId, :vesselName, 'Test Harbor', 1, 'America/New_York')",
      {
        userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" },
        vesselName = { value = left(marker & "-vessel", 255), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    qVessel = queryExecute(
      "SELECT vesselID FROM vessels WHERE userId = :userId ORDER BY vesselID DESC LIMIT 1",
      { userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );

    queryExecute(
      "INSERT INTO loop_routes
          (code, name, short_code, description, is_active, version, is_default, total_nm, total_locks)
       VALUES
          (:routeCode, :routeName, :routeCode, :description, 1, 1, 0, 24.50, 0)",
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
           status, started_at)
       VALUES
          (:userId, :routeCode, :routeId, :routeCode,
           'CCW', 'POINT_TO_POINT', 'Test Start', 'Test Finish', :inputsJson,
           :status, :startedAt)",
      {
        userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" },
        routeCode = { value = routeCode, cfsqltype = "cf_sql_varchar" },
        routeId = { value = val(qRoute.id[1]), cfsqltype = "cf_sql_integer" },
        inputsJson = {
          value = serializeJSON({ fixture_marker = marker }),
          cfsqltype = "cf_sql_longvarchar"
        },
        status = {
          value = arguments.routeStarted ? "ACTIVE" : "PLANNED",
          cfsqltype = "cf_sql_varchar"
        },
        startedAt = {
          value = dateAdd("n", -30, now()),
          cfsqltype = "cf_sql_timestamp",
          null = !arguments.routeStarted
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
       VALUES (:routeInstanceId, 1, 'Test Section', 1)",
      {
        routeInstanceId = { value = val(qInstance.id[1]), cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );
    qSection = queryExecute(
      "SELECT id FROM route_instance_sections
       WHERE route_instance_id = :routeInstanceId AND section_order = 1 LIMIT 1",
      {
        routeInstanceId = { value = val(qInstance.id[1]), cfsqltype = "cf_sql_integer" }
      },
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
            value = legOrder EQ 1 ? "Test Start" : "Test Midpoint",
            cfsqltype = "cf_sql_varchar"
          },
          endName = {
            value = legOrder EQ 1 ? "Test Midpoint" : "Test Finish",
            cfsqltype = "cf_sql_varchar"
          },
          distanceNm = { value = legOrder EQ 1 ? 12.00 : 12.50, cfsqltype = "cf_sql_decimal" }
        },
        { datasource = variables.datasource }
      );
      queryExecute(
        "INSERT INTO route_instance_leg_progress
            (user_id, route_instance_id, leg_order, status, leg_started_at, completed_at)
         VALUES
            (:userId, :routeInstanceId, :legOrder, :status, :legStartedAt, NULL)",
        {
          userId = { value = val(qUser.userId[1]), cfsqltype = "cf_sql_integer" },
          routeInstanceId = { value = val(qInstance.id[1]), cfsqltype = "cf_sql_integer" },
          legOrder = { value = legOrder, cfsqltype = "cf_sql_integer" },
          status = {
            value = (arguments.progressStarted AND legOrder EQ 1) ? "IN_PROGRESS" : "NOT_STARTED",
            cfsqltype = "cf_sql_varchar"
          },
          legStartedAt = {
            value = dateAdd("n", -30, now()),
            cfsqltype = "cf_sql_timestamp",
            null = !(arguments.progressStarted AND legOrder EQ 1)
          }
        },
        { datasource = variables.datasource }
      );
    }

    fixture = {
      marker = marker,
      email = email,
      userId = val(qUser.userId[1]),
      vesselId = val(qVessel.vesselID[1]),
      routeCode = routeCode,
      routeId = val(qRoute.id[1]),
      sourceRouteInstanceId = val(qInstance.id[1]),
      historicalFloatPlanId = 0
    };

    if (arguments.createClosedPlan) {
      queryExecute(
        "INSERT INTO floatplans
            (userId, floatPlanName, vesselId, dateCreated, lastUpdate,
             departing, `returning`, departureTime, departureTimeUTC,
             departTimezone, departureTZ, status, lastUpdateStatus,
             activatedAt, initialSentAt, closedAt, route_instance_id, route_day_number)
         VALUES
            (:userId, :planName, :vesselId, UTC_TIMESTAMP(), UTC_TIMESTAMP(),
             'Test Start', 'Test Finish', DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 HOUR),
             DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 HOUR), 'America/New_York',
             'America/New_York', 'CLOSED', UTC_TIMESTAMP(),
             DATE_SUB(UTC_TIMESTAMP(), INTERVAL 2 HOUR),
             DATE_SUB(UTC_TIMESTAMP(), INTERVAL 2 HOUR), UTC_TIMESTAMP(),
             :routeInstanceId, 1)",
        {
          userId = { value = toString(fixture.userId), cfsqltype = "cf_sql_varchar" },
          planName = { value = left(marker & "-closed", 255), cfsqltype = "cf_sql_varchar" },
          vesselId = { value = fixture.vesselId, cfsqltype = "cf_sql_integer" },
          routeInstanceId = { value = fixture.sourceRouteInstanceId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      qHistoricalPlan = queryExecute(
        "SELECT floatPlanId FROM floatplans
         WHERE userId = :userId AND floatPlanName = :planName
         ORDER BY floatPlanId DESC LIMIT 1",
        {
          userId = { value = toString(fixture.userId), cfsqltype = "cf_sql_varchar" },
          planName = { value = left(marker & "-closed", 255), cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
      fixture.historicalFloatPlanId = val(qHistoricalPlan.floatPlanId[1]);
    }

    return fixture;
  }

  private numeric function createDraftPlan(required struct fixture, required string planLabel) {
    var planName = left(arguments.fixture.marker & "-" & arguments.planLabel, 255);
    var qPlan = queryNew("");

    queryExecute(
      "INSERT INTO floatplans
          (userId, floatPlanName, vesselId, dateCreated, lastUpdate,
           departing, `returning`, status, lastUpdateStatus,
           route_instance_id, route_day_number)
       VALUES
          (:userId, :planName, :vesselId, UTC_TIMESTAMP(), UTC_TIMESTAMP(),
           'Test Start', 'Test Finish', 'DRAFT', UTC_TIMESTAMP(),
           :routeInstanceId, 1)",
      {
        userId = { value = toString(arguments.fixture.userId), cfsqltype = "cf_sql_varchar" },
        planName = { value = planName, cfsqltype = "cf_sql_varchar" },
        vesselId = { value = arguments.fixture.vesselId, cfsqltype = "cf_sql_integer" },
        routeInstanceId = {
          value = arguments.fixture.sourceRouteInstanceId,
          cfsqltype = "cf_sql_integer"
        }
      },
      { datasource = variables.datasource }
    );
    qPlan = queryExecute(
      "SELECT floatPlanId FROM floatplans
       WHERE userId = :userId AND floatPlanName = :planName
       ORDER BY floatPlanId DESC LIMIT 1",
      {
        userId = { value = toString(arguments.fixture.userId), cfsqltype = "cf_sql_varchar" },
        planName = { value = planName, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    return val(qPlan.floatPlanId[1]);
  }

  private query function loadPlanGroupState(required numeric userId, required array floatPlanIds) {
    if (!arrayLen(arguments.floatPlanIds)) {
      throw(type = "FPW.RouteDraftTest", message = "The build returned no float plan ids.");
    }
    return queryExecute(
      "SELECT
          COUNT(*) AS plan_count,
          SUM(UPPER(TRIM(`status`)) = 'DRAFT') AS draft_count,
          COUNT(DISTINCT route_instance_id) AS distinct_route_count,
          MIN(route_instance_id) AS min_route_instance_id,
          MAX(route_instance_id) AS max_route_instance_id
       FROM floatplans
       WHERE userId = :userId
         AND floatPlanId IN (:floatPlanIds)",
      {
        userId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" },
        floatPlanIds = {
          value = arrayToList(arguments.floatPlanIds),
          cfsqltype = "cf_sql_integer",
          list = true
        }
      },
      { datasource = variables.datasource }
    );
  }

  private query function loadPlanState(required numeric userId, required numeric floatPlanId) {
    return queryExecute(
      "SELECT floatPlanId, route_instance_id, `status`, activatedAt, closedAt
       FROM floatplans
       WHERE floatPlanId = :floatPlanId AND userId = :userId
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        userId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
  }

  private query function loadRouteState(required numeric userId, required numeric routeInstanceId) {
    return queryExecute(
      "SELECT id, generated_route_id, generated_route_code, `status`, started_at,
              (started_at IS NULL) AS started_is_null
       FROM route_instances
       WHERE id = :routeInstanceId AND user_id = :userId
       LIMIT 1",
      {
        routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" },
        userId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
  }

  private query function loadProgressState(required numeric userId, required numeric routeInstanceId) {
    return queryExecute(
      "SELECT
          COUNT(DISTINCT ril.id) AS leg_count,
          COUNT(DISTINCT rilp.id) AS progress_count,
          SUM(
            CASE
              WHEN rilp.id IS NOT NULL
               AND UPPER(TRIM(COALESCE(rilp.status, ''))) = 'NOT_STARTED'
               AND rilp.leg_started_at IS NULL
               AND rilp.completed_at IS NULL
              THEN 1 ELSE 0
            END
          ) AS clean_count,
          SUM(
            CASE
              WHEN rilp.id IS NOT NULL
               AND (
                 rilp.leg_started_at IS NOT NULL
                 OR rilp.completed_at IS NOT NULL
                 OR UPPER(TRIM(COALESCE(rilp.status, ''))) <> 'NOT_STARTED'
               )
              THEN 1 ELSE 0
            END
          ) AS operational_count
       FROM route_instance_legs ril
       LEFT JOIN route_instance_leg_progress rilp
         ON rilp.route_instance_id = ril.route_instance_id
        AND rilp.leg_order = ril.leg_order
        AND rilp.user_id = :userId
       WHERE ril.route_instance_id = :routeInstanceId",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );
  }

  private void function assertCleanProgress(required query progressState, required numeric expectedLegCount) {
    expect(val(arguments.progressState.leg_count[1])).toBe(arguments.expectedLegCount);
    expect(val(arguments.progressState.progress_count[1])).toBe(arguments.expectedLegCount);
    expect(val(arguments.progressState.clean_count[1])).toBe(arguments.expectedLegCount);
    expect(val(arguments.progressState.operational_count[1])).toBe(0);
  }

  private numeric function countUserRouteInstances(required numeric userId) {
    var qCount = queryExecute(
      "SELECT COUNT(*) AS route_count
       FROM route_instances
       WHERE user_id = :userId",
      {
        userId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    return val(qCount.route_count[1]);
  }

  private string function readRepoFile(required string relativePath) {
    return fileRead(expandPath("/fpw/" & arguments.relativePath), "utf-8");
  }

  private void function cleanupFixtures() {
    var params = {
      fixturePattern = {
        value = variables.fixturePrefix & "%",
        cfsqltype = "cf_sql_varchar"
      }
    };

    queryExecute(
      "DELETE FROM route_instance_leg_progress
       WHERE route_instance_id IN (
         SELECT id FROM route_instances
         WHERE CAST(user_id AS UNSIGNED) IN (
           SELECT userId FROM users WHERE email LIKE :fixturePattern
         )
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM route_instance_legs
       WHERE route_instance_id IN (
         SELECT id FROM route_instances
         WHERE CAST(user_id AS UNSIGNED) IN (
           SELECT userId FROM users WHERE email LIKE :fixturePattern
         )
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM route_instance_sections
       WHERE route_instance_id IN (
         SELECT id FROM route_instances
         WHERE CAST(user_id AS UNSIGNED) IN (
           SELECT userId FROM users WHERE email LIKE :fixturePattern
         )
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM floatplans
       WHERE CAST(userId AS UNSIGNED) IN (
         SELECT userId FROM users WHERE email LIKE :fixturePattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM route_instances
       WHERE CAST(user_id AS UNSIGNED) IN (
         SELECT userId FROM users WHERE email LIKE :fixturePattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM loop_routes WHERE name LIKE :fixturePattern",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM vessels
       WHERE CAST(userId AS UNSIGNED) IN (
         SELECT userId FROM users WHERE email LIKE :fixturePattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM users WHERE email LIKE :fixturePattern",
      params,
      { datasource = variables.datasource }
    );
  }

}
