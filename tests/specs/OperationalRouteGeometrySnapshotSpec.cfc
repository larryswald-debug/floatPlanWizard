component extends="testbox.system.BaseSpec" output="false" {

  variables.datasource = "fpw";
  variables.fixturePrefix = "codex-operational-route-geometry-";

  function beforeAll() {
    cleanupFixtures();
  }

  function afterAll() {
    cleanupFixtures();
  }

  function run() {
    describe("Operational route geometry snapshots", function() {

      beforeEach(function() {
        cleanupFixtures();
        variables.floatPlanService = createObject("component", "fpw.api.v1.floatplan");
        makePublic(
          variables.floatPlanService,
          "ensureCleanRouteInstanceForActivation",
          "ensureCleanRouteInstanceForActivationForTest"
        );
        variables.geometryService = createObject(
          "component",
          "fpw.api.v1.RouteMapGeometryService"
        ).init(variables.datasource);
      });

      afterEach(function() {
        cleanupFixtures();
      });

      it("preserves seven-decimal endpoint precision when activation creates a fresh route instance", function() {
        var fixture = createRouteFixture(
          label = "clone-precision",
          routeStarted = true,
          createHistoricalPlan = true,
          currentPlanStatus = "DRAFT",
          integerEndpoints = false
        );
        var result = variables.floatPlanService.ensureCleanRouteInstanceForActivationForTest(
          userId = fixture.userId,
          floatPlanId = fixture.currentFloatPlanId,
          routeInstanceId = fixture.sourceRouteInstanceId
        );
        var freshRouteInstanceId = val(result.ROUTE_INSTANCE_ID);
        var qFreshLegs = loadLegEndpointStrings(freshRouteInstanceId);

        expect(result.SUCCESS).toBeTrue();
        expect(result.CREATED_FRESH).toBeTrue();
        expect(freshRouteInstanceId).notToBe(fixture.sourceRouteInstanceId);
        expect(qFreshLegs.recordCount).toBe(2);
        expect(toString(qFreshLegs.start_lat_value[1])).toBe("28.2334921");
        expect(toString(qFreshLegs.start_lng_value[1])).toBe("-82.7421574");
        expect(toString(qFreshLegs.end_lat_value[1])).toBe("28.1493712");
        expect(toString(qFreshLegs.end_lng_value[1])).toBe("-82.8272763");
        expect(toString(qFreshLegs.start_lat_value[2])).toBe("28.1493712");
        expect(toString(qFreshLegs.start_lng_value[2])).toBe("-82.8272763");
        expect(toString(qFreshLegs.end_lat_value[2])).toBe("28.1004567");
        expect(toString(qFreshLegs.end_lng_value[2])).toBe("-82.9007654");
        expect(countSnapshots(freshRouteInstanceId)).toBe(0);
      });

      it("creates one immutable snapshot whose line and ordered markers are anchored to saved endpoints", function() {
        var fixture = createRouteFixture(
          label = "snapshot-authority",
          routeStarted = false,
          createHistoricalPlan = false,
          currentPlanStatus = "ACTIVE",
          integerEndpoints = false
        );
        var firstCreate = variables.geometryService.ensureOperationalGeometrySnapshot(
          routeInstanceId = fixture.sourceRouteInstanceId,
          ownerUserId = fixture.userId
        );
        var firstRow = loadSnapshotRow(fixture.sourceRouteInstanceId);
        var firstMap = variables.geometryService.buildRouteMapData(
          routeInstanceId = fixture.sourceRouteInstanceId,
          ownerUserId = fixture.userId
        );
        var firstCoordinatesJson = serializeJSON(firstMap.route_geo.coordinates);
        var firstPinsJson = serializePinAuthority(firstMap.pins);
        var secondCreate = {};
        var secondRow = queryNew("");
        var secondMap = {};
        var snapshotOnlyMap = {};

        expect(firstCreate.SUCCESS).toBeTrue();
        expect(firstCreate.CREATED).toBeTrue();
        expect(firstCreate.REUSED).toBeFalse();
        expect(val(firstCreate.LEG_COUNT)).toBe(2);
        expect(val(firstCreate.MARKER_COUNT)).toBe(3);
        expect(firstRow.recordCount).toBe(1);
        expect(val(firstRow.snapshot_version[1])).toBe(1);
        expect(firstMap.geometry_authority).toBe("route_instance_geometry_snapshot");
        expect(firstMap.snapshot_status).toBe("valid");
        expect(firstMap.operational_snapshot_used).toBeTrue();
        expect(firstMap.legacy_geometry_fallback).toBeFalse();
        expect(arrayLen(firstMap.route_geo.coordinates)).toBe(2);
        expect(arrayLen(firstMap.pins)).toBe(3);

        assertCoordinate(firstMap.route_geo.coordinates[1][1], -82.7421574, 28.2334921);
        assertCoordinate(
          firstMap.route_geo.coordinates[1][arrayLen(firstMap.route_geo.coordinates[1])],
          -82.8272763,
          28.1493712
        );
        assertCoordinate(firstMap.route_geo.coordinates[2][1], -82.8272763, 28.1493712);
        assertCoordinate(
          firstMap.route_geo.coordinates[2][arrayLen(firstMap.route_geo.coordinates[2])],
          -82.9007654,
          28.1004567
        );
        assertPin(firstMap.pins[1], 1, "start", "start", 1, 28.2334921, -82.7421574);
        assertPin(firstMap.pins[2], 2, "leg_end", "end", 1, 28.1493712, -82.8272763);
        assertPin(firstMap.pins[3], 3, "end", "end", 2, 28.1004567, -82.9007654);

        secondCreate = variables.geometryService.ensureOperationalGeometrySnapshot(
          routeInstanceId = fixture.sourceRouteInstanceId,
          ownerUserId = fixture.userId
        );
        secondRow = loadSnapshotRow(fixture.sourceRouteInstanceId);
        expect(secondCreate.SUCCESS).toBeTrue();
        expect(secondCreate.CREATED).toBeFalse();
        expect(secondCreate.REUSED).toBeTrue();
        expect(countSnapshots(fixture.sourceRouteInstanceId)).toBe(1);
        expect(toString(secondRow.snapshot_json[1])).toBe(toString(firstRow.snapshot_json[1]));
        expect(toString(secondRow.created_at_utc[1])).toBe(toString(firstRow.created_at_utc[1]));

        replaceUnderlyingOverrideGeometry(fixture);
        secondMap = variables.geometryService.buildRouteMapData(
          routeInstanceId = fixture.sourceRouteInstanceId,
          ownerUserId = fixture.userId
        );
        secondRow = loadSnapshotRow(fixture.sourceRouteInstanceId);
        expect(serializeJSON(secondMap.route_geo.coordinates)).toBe(firstCoordinatesJson);
        expect(serializePinAuthority(secondMap.pins)).toBe(firstPinsJson);
        expect(toString(secondRow.snapshot_json[1])).toBe(toString(firstRow.snapshot_json[1]));
        expect(secondMap.geometry_authority).toBe("route_instance_geometry_snapshot");
        expect(secondMap.operational_snapshot_used).toBeTrue();

        queryExecute(
          "DELETE FROM route_instance_legs WHERE route_instance_id = :routeInstanceId",
          {
            routeInstanceId = {
              value = fixture.sourceRouteInstanceId,
              cfsqltype = "cf_sql_integer"
            }
          },
          { datasource = variables.datasource }
        );
        snapshotOnlyMap = variables.geometryService.buildRouteMapData(
          routeInstanceId = fixture.sourceRouteInstanceId,
          ownerUserId = fixture.userId
        );
        secondRow = loadSnapshotRow(fixture.sourceRouteInstanceId);
        expect(snapshotOnlyMap.geometry_authority).toBe("route_instance_geometry_snapshot");
        expect(snapshotOnlyMap.operational_snapshot_used).toBeTrue();
        expect(serializeJSON(snapshotOnlyMap.route_geo.coordinates)).toBe(firstCoordinatesJson);
        expect(serializePinAuthority(snapshotOnlyMap.pins)).toBe(firstPinsJson);
        expect(toString(secondRow.snapshot_json[1])).toBe(toString(firstRow.snapshot_json[1]));
      });

      it("normalizes reversed stored geometry before anchoring the saved endpoints", function() {
        var fixture = createRouteFixture(
          label = "reversed-geometry",
          routeStarted = false,
          createHistoricalPlan = false,
          currentPlanStatus = "ACTIVE",
          integerEndpoints = false
        );
        var createResult = {};
        var mapData = {};
        var firstSegment = [];
        var secondSegment = [];

        reverseUnderlyingOverrideGeometry(fixture);
        createResult = variables.geometryService.ensureOperationalGeometrySnapshot(
          routeInstanceId = fixture.sourceRouteInstanceId,
          ownerUserId = fixture.userId
        );
        mapData = variables.geometryService.buildRouteMapData(
          routeInstanceId = fixture.sourceRouteInstanceId,
          ownerUserId = fixture.userId
        );
        firstSegment = mapData.route_geo.coordinates[1];
        secondSegment = mapData.route_geo.coordinates[2];

        expect(createResult.SUCCESS).toBeTrue();
        expect(createResult.CREATED).toBeTrue();
        expect(mapData.operational_snapshot_used).toBeTrue();
        assertCoordinate(firstSegment[1], -82.7421574, 28.2334921);
        assertCoordinate(firstSegment[2], -82.7449040, 28.2384640);
        assertCoordinate(firstSegment[arrayLen(firstSegment) - 1], -82.8300000, 28.1500000);
        assertCoordinate(firstSegment[arrayLen(firstSegment)], -82.8272763, 28.1493712);
        assertCoordinate(secondSegment[1], -82.8272763, 28.1493712);
        assertCoordinate(secondSegment[2], -82.8250000, 28.1480000);
        assertCoordinate(secondSegment[arrayLen(secondSegment) - 1], -82.9050000, 28.1040000);
        assertCoordinate(secondSegment[arrayLen(secondSegment)], -82.9007654, 28.1004567);
      });

      it("uses the read-only legacy fallback for an operational route with no snapshot and integer endpoints", function() {
        var fixture = createRouteFixture(
          label = "legacy-integer",
          routeStarted = true,
          createHistoricalPlan = false,
          currentPlanStatus = "ACTIVE",
          integerEndpoints = true
        );
        var firstMap = variables.geometryService.buildRouteMapData(
          routeInstanceId = fixture.sourceRouteInstanceId,
          ownerUserId = fixture.userId
        );
        var secondMap = variables.geometryService.buildRouteMapData(
          routeInstanceId = fixture.sourceRouteInstanceId,
          ownerUserId = fixture.userId
        );

        expect(countSnapshots(fixture.sourceRouteInstanceId)).toBe(0);
        expect(firstMap.snapshot_status).toBe("missing");
        expect(firstMap.geometry_authority).toBe("legacy_route_geometry_fallback");
        expect(firstMap.operational_snapshot_used).toBeFalse();
        expect(firstMap.legacy_geometry_fallback).toBeTrue();
        expect(firstMap.legacy_endpoint_fallback_used).toBeTrue();
        expect(arrayLen(firstMap.route_geo.coordinates)).toBe(2);
        expect(arrayLen(firstMap.pins)).toBeGT(1);
        assertCoordinate(firstMap.route_geo.coordinates[1][1], -82.7449040, 28.2384640);
        expect(countSnapshots(fixture.sourceRouteInstanceId)).toBe(0);
        expect(secondMap.geometry_authority).toBe("legacy_route_geometry_fallback");
        expect(secondMap.legacy_endpoint_fallback_used).toBeTrue();
      });

      it("keeps a non-operational Draft snapshot-free and resolves later route edits live", function() {
        var fixture = createRouteFixture(
          label = "draft-live",
          routeStarted = false,
          createHistoricalPlan = false,
          currentPlanStatus = "DRAFT",
          integerEndpoints = false
        );
        var firstMap = variables.geometryService.buildRouteMapData(
          routeInstanceId = fixture.sourceRouteInstanceId,
          ownerUserId = fixture.userId
        );
        var firstPoint = duplicate(firstMap.route_geo.coordinates[1][1]);
        var secondMap = {};

        expect(firstMap.snapshot_status).toBe("missing");
        expect(firstMap.geometry_authority).toBe("live_route_geometry_resolver");
        expect(firstMap.operational_snapshot_used).toBeFalse();
        expect(firstMap.legacy_geometry_fallback).toBeFalse();
        expect(countSnapshots(fixture.sourceRouteInstanceId)).toBe(0);

        replaceUnderlyingOverrideGeometry(fixture);
        secondMap = variables.geometryService.buildRouteMapData(
          routeInstanceId = fixture.sourceRouteInstanceId,
          ownerUserId = fixture.userId
        );
        expect(secondMap.geometry_authority).toBe("live_route_geometry_resolver");
        expect(secondMap.snapshot_status).toBe("missing");
        expect(countSnapshots(fixture.sourceRouteInstanceId)).toBe(0);
        expect(
          abs(val(secondMap.route_geo.coordinates[1][1][1]) - val(firstPoint[1])) GT 0.01
        ).toBeTrue();
        assertCoordinate(secondMap.route_geo.coordinates[1][1], -82.5000000, 28.5000000);
      });

      it("captures geometry after the final route activation precheck and before the ACTIVE update", function() {
        var source = readRepoFile("api/v1/floatplan.cfc");
        var precheckNeedle = "routeActivationResult = ensureCleanRouteInstanceForActivation(";
        var snapshotPosition = findNoCase(
          "operationalGeometrySnapshotResult = createObject(",
          source
        );
        var precheckPosition = findLastNoCaseBefore(
          needle = precheckNeedle,
          haystack = source,
          beforePosition = snapshotPosition
        );
        var preparedRoutePosition = findNoCase(
          "routeInstanceId = routeActivationResult.ROUTE_INSTANCE_ID;",
          source,
          precheckPosition
        );
        var activeUpdatePosition = findNoCase(
          "`status` = 'ACTIVE',",
          source,
          snapshotPosition
        );

        expect(precheckPosition).toBeGT(0);
        expect(preparedRoutePosition).toBeGT(precheckPosition);
        expect(snapshotPosition).toBeGT(preparedRoutePosition);
        expect(activeUpdatePosition).toBeGT(snapshotPosition);
      });

    });
  }

  private struct function createRouteFixture(
    required string label,
    required boolean routeStarted,
    required boolean createHistoricalPlan,
    required string currentPlanStatus,
    required boolean integerEndpoints
  ) {
    var token = lCase(reReplace(createUUID(), "[^A-Za-z0-9]", "", "all"));
    var marker = variables.fixturePrefix & token;
    var email = marker & "@example.test";
    var routeCode = left("ORG_" & token, 40);
    var routeName = left(marker & "-route", 160);
    var qUser = queryNew("");
    var qVessel = queryNew("");
    var qUserRoute = queryNew("");
    var qUserRouteLegs = queryNew("");
    var qLoopRoute = queryNew("");
    var qRouteInstance = queryNew("");
    var qSection = queryNew("");
    var qCurrentPlan = queryNew("");
    var qHistoricalPlan = queryNew("");
    var routeInstanceId = 0;
    var userId = 0;
    var vesselId = 0;
    var userRouteId = 0;
    var loopRouteId = 0;
    var sectionId = 0;
    var legOrder = 0;
    var startLat = 0.0;
    var startLng = 0.0;
    var endLat = 0.0;
    var endLng = 0.0;
    var geometry = [];

    queryExecute(
      "INSERT INTO users (fName, lName, email, password, passwordCreated, created)
       VALUES ('Codex', 'Geometry Snapshot', :email, :password, UTC_TIMESTAMP(), UTC_TIMESTAMP())",
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
    userId = val(qUser.userId[1]);

    queryExecute(
      "INSERT INTO vessels (userId, vesselName, hailingPort, isDefaultVessel, timezone)
       VALUES (:userId, :vesselName, 'Test Harbor', 1, 'America/New_York')",
      {
        userId = { value = toString(userId), cfsqltype = "cf_sql_varchar" },
        vesselName = { value = left(marker & "-vessel", 255), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    qVessel = queryExecute(
      "SELECT vesselID FROM vessels WHERE userId = :userId ORDER BY vesselID DESC LIMIT 1",
      { userId = { value = toString(userId), cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );
    vesselId = val(qVessel.vesselID[1]);

    queryExecute(
      "INSERT INTO user_routes (user_id, route_name, start_waypoint_id, is_active)
       VALUES (:userId, :routeName, NULL, 1)",
      {
        userId = { value = userId, cfsqltype = "cf_sql_integer" },
        routeName = { value = left(marker & "-custom", 255), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    qUserRoute = queryExecute(
      "SELECT id FROM user_routes
       WHERE user_id = :userId AND route_name = :routeName
       ORDER BY id DESC LIMIT 1",
      {
        userId = { value = userId, cfsqltype = "cf_sql_integer" },
        routeName = { value = left(marker & "-custom", 255), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    userRouteId = val(qUserRoute.id[1]);

    for (legOrder = 1; legOrder LTE 2; legOrder++) {
      queryExecute(
        "INSERT INTO user_route_legs
            (user_route_id, order_index, segment_id, start_waypoint_id, end_waypoint_id)
         VALUES (:routeId, :legOrder, NULL, NULL, NULL)",
        {
          routeId = { value = userRouteId, cfsqltype = "cf_sql_integer" },
          legOrder = { value = legOrder, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
    }
    qUserRouteLegs = queryExecute(
      "SELECT id, order_index FROM user_route_legs
       WHERE user_route_id = :routeId
       ORDER BY order_index ASC",
      { routeId = { value = userRouteId, cfsqltype = "cf_sql_integer" } },
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
    qLoopRoute = queryExecute(
      "SELECT id FROM loop_routes WHERE short_code = :routeCode LIMIT 1",
      { routeCode = { value = routeCode, cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );
    loopRouteId = val(qLoopRoute.id[1]);

    queryExecute(
      "INSERT INTO route_instances
          (user_id, template_route_code, generated_route_id, generated_route_code,
           direction, trip_type, start_location, end_location, routegen_inputs_json,
           status, started_at)
       VALUES
          (:userId, 'MY_ROUTE', :routeId, :routeCode,
           'CCW', 'POINT_TO_POINT', 'Saved Start', 'Saved Finish', :inputsJson,
           :status, :startedAt)",
      {
        userId = { value = toString(userId), cfsqltype = "cf_sql_varchar" },
        routeId = { value = loopRouteId, cfsqltype = "cf_sql_integer" },
        routeCode = { value = routeCode, cfsqltype = "cf_sql_varchar" },
        inputsJson = {
          value = serializeJSON({ route_id = userRouteId, fixture_marker = marker }),
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
    qRouteInstance = queryExecute(
      "SELECT id FROM route_instances
       WHERE user_id = :userId AND generated_route_code = :routeCode
       ORDER BY id DESC LIMIT 1",
      {
        userId = { value = toString(userId), cfsqltype = "cf_sql_varchar" },
        routeCode = { value = routeCode, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    routeInstanceId = val(qRouteInstance.id[1]);

    queryExecute(
      "INSERT INTO route_instance_sections (route_instance_id, section_order, name, phase_num)
       VALUES (:routeInstanceId, 1, 'Snapshot Test Section', 1)",
      { routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer" } },
      { datasource = variables.datasource }
    );
    qSection = queryExecute(
      "SELECT id FROM route_instance_sections
       WHERE route_instance_id = :routeInstanceId AND section_order = 1 LIMIT 1",
      { routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer" } },
      { datasource = variables.datasource }
    );
    sectionId = val(qSection.id[1]);

    for (legOrder = 1; legOrder LTE 2; legOrder++) {
      if (arguments.integerEndpoints) {
        startLat = 28;
        startLng = -83;
        endLat = 28;
        endLng = -83;
      } else if (legOrder EQ 1) {
        startLat = 28.2334921;
        startLng = -82.7421574;
        endLat = 28.1493712;
        endLng = -82.8272763;
      } else {
        startLat = 28.1493712;
        startLng = -82.8272763;
        endLat = 28.1004567;
        endLng = -82.9007654;
      }

      queryExecute(
        "INSERT INTO route_instance_legs
            (route_instance_id, route_instance_section_id, leg_order,
             segment_id, source_loop_segment_id, is_reversed, is_optional,
             start_name, end_name, start_lat, start_lng, end_lat, end_lng,
             base_dist_nm, lock_count)
         VALUES
            (:routeInstanceId, :sectionId, :legOrder,
             NULL, NULL, 0, 0,
             :startName, :endName, :startLat, :startLng, :endLat, :endLng,
             12.25, 0)",
        {
          routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer" },
          sectionId = { value = sectionId, cfsqltype = "cf_sql_integer" },
          legOrder = { value = legOrder, cfsqltype = "cf_sql_integer" },
          startName = {
            value = legOrder EQ 1 ? "Saved Start" : "Saved Midpoint",
            cfsqltype = "cf_sql_varchar"
          },
          endName = {
            value = legOrder EQ 1 ? "Saved Midpoint" : "Saved Finish",
            cfsqltype = "cf_sql_varchar"
          },
          startLat = { value = startLat, cfsqltype = "cf_sql_decimal", scale = 7 },
          startLng = { value = startLng, cfsqltype = "cf_sql_decimal", scale = 7 },
          endLat = { value = endLat, cfsqltype = "cf_sql_decimal", scale = 7 },
          endLng = { value = endLng, cfsqltype = "cf_sql_decimal", scale = 7 }
        },
        { datasource = variables.datasource }
      );
      queryExecute(
        "INSERT INTO route_instance_leg_progress
            (user_id, route_instance_id, leg_order, status, leg_started_at, completed_at)
         VALUES (:userId, :routeInstanceId, :legOrder, 'NOT_STARTED', NULL, NULL)",
        {
          userId = { value = userId, cfsqltype = "cf_sql_integer" },
          routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer" },
          legOrder = { value = legOrder, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );

      geometry = (
        legOrder EQ 1
          ? [
              { lat = 28.2384640, lng = -82.7449040 },
              { lat = 28.1900000, lng = -82.7850000 },
              { lat = 28.1500000, lng = -82.8300000 }
            ]
          : [
              { lat = 28.1480000, lng = -82.8250000 },
              { lat = 28.1250000, lng = -82.8650000 },
              { lat = 28.1040000, lng = -82.9050000 }
            ]
      );
      queryExecute(
        "INSERT INTO route_leg_user_overrides
            (user_id, route_id, route_leg_id, route_leg_order, segment_id,
             geometry_json, computed_nm, override_fields_json)
         VALUES
            (:userId, :routeId, :routeLegId, :legOrder, NULL,
             :geometryJson, 12.25, NULL)",
        {
          userId = { value = userId, cfsqltype = "cf_sql_integer" },
          routeId = { value = userRouteId, cfsqltype = "cf_sql_integer" },
          routeLegId = {
            value = val(qUserRouteLegs.id[legOrder]),
            cfsqltype = "cf_sql_integer"
          },
          legOrder = { value = legOrder, cfsqltype = "cf_sql_integer" },
          geometryJson = { value = serializeJSON(geometry), cfsqltype = "cf_sql_longvarchar" }
        },
        { datasource = variables.datasource }
      );
    }

    insertFloatPlan(
      userId = userId,
      vesselId = vesselId,
      routeInstanceId = routeInstanceId,
      planName = left(marker & "-current", 255),
      status = uCase(trim(arguments.currentPlanStatus))
    );
    qCurrentPlan = queryExecute(
      "SELECT floatPlanId FROM floatplans
       WHERE userId = :userId AND floatPlanName = :planName
       ORDER BY floatPlanId DESC LIMIT 1",
      {
        userId = { value = toString(userId), cfsqltype = "cf_sql_varchar" },
        planName = { value = left(marker & "-current", 255), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );

    if (arguments.createHistoricalPlan) {
      insertFloatPlan(
        userId = userId,
        vesselId = vesselId,
        routeInstanceId = routeInstanceId,
        planName = left(marker & "-historical", 255),
        status = "CLOSED"
      );
      qHistoricalPlan = queryExecute(
        "SELECT floatPlanId FROM floatplans
         WHERE userId = :userId AND floatPlanName = :planName
         ORDER BY floatPlanId DESC LIMIT 1",
        {
          userId = { value = toString(userId), cfsqltype = "cf_sql_varchar" },
          planName = { value = left(marker & "-historical", 255), cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
    }

    return {
      marker = marker,
      email = email,
      userId = userId,
      vesselId = vesselId,
      userRouteId = userRouteId,
      loopRouteId = loopRouteId,
      sourceRouteInstanceId = routeInstanceId,
      currentFloatPlanId = val(qCurrentPlan.floatPlanId[1]),
      historicalFloatPlanId = (
        qHistoricalPlan.recordCount GT 0 ? val(qHistoricalPlan.floatPlanId[1]) : 0
      )
    };
  }

  private void function insertFloatPlan(
    required numeric userId,
    required numeric vesselId,
    required numeric routeInstanceId,
    required string planName,
    required string status
  ) {
    var isOperational = listFindNoCase("ACTIVE,CLOSED", arguments.status) GT 0;
    var isClosed = compareNoCase(arguments.status, "CLOSED") EQ 0;

    queryExecute(
      "INSERT INTO floatplans
          (userId, floatPlanName, vesselId, dateCreated, lastUpdate,
           departing, `returning`, departureTime, departureTimeUTC,
           departTimezone, departureTZ, status, lastUpdateStatus,
           activatedAt, initialSentAt, closedAt, route_instance_id, route_day_number)
       VALUES
          (:userId, :planName, :vesselId, UTC_TIMESTAMP(), UTC_TIMESTAMP(),
           'Saved Start', 'Saved Finish', DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR),
           DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR), 'America/New_York',
           'America/New_York', :status, UTC_TIMESTAMP(),
           :activatedAt, :initialSentAt, :closedAt, :routeInstanceId, 1)",
      {
        userId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" },
        planName = { value = arguments.planName, cfsqltype = "cf_sql_varchar" },
        vesselId = { value = arguments.vesselId, cfsqltype = "cf_sql_integer" },
        status = { value = arguments.status, cfsqltype = "cf_sql_varchar" },
        activatedAt = {
          value = dateAdd("n", -10, now()),
          cfsqltype = "cf_sql_timestamp",
          null = !isOperational
        },
        initialSentAt = {
          value = dateAdd("n", -10, now()),
          cfsqltype = "cf_sql_timestamp",
          null = !isOperational
        },
        closedAt = {
          value = now(),
          cfsqltype = "cf_sql_timestamp",
          null = !isClosed
        },
        routeInstanceId = {
          value = arguments.routeInstanceId,
          cfsqltype = "cf_sql_integer"
        }
      },
      { datasource = variables.datasource }
    );
  }

  private query function loadLegEndpointStrings(required numeric routeInstanceId) {
    return queryExecute(
      "SELECT
          leg_order,
          CAST(start_lat AS CHAR) AS start_lat_value,
          CAST(start_lng AS CHAR) AS start_lng_value,
          CAST(end_lat AS CHAR) AS end_lat_value,
          CAST(end_lng AS CHAR) AS end_lng_value
       FROM route_instance_legs
       WHERE route_instance_id = :routeInstanceId
       ORDER BY leg_order ASC, id ASC",
      {
        routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );
  }

  private query function loadSnapshotRow(required numeric routeInstanceId) {
    return queryExecute(
      "SELECT route_instance_id, snapshot_version, snapshot_json, created_at_utc
       FROM route_instance_geometry_snapshots
       WHERE route_instance_id = :routeInstanceId
       LIMIT 1",
      {
        routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );
  }

  private numeric function countSnapshots(required numeric routeInstanceId) {
    var qCount = queryExecute(
      "SELECT COUNT(*) AS snapshot_count
       FROM route_instance_geometry_snapshots
       WHERE route_instance_id = :routeInstanceId",
      {
        routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );
    return val(qCount.snapshot_count[1]);
  }

  private void function replaceUnderlyingOverrideGeometry(required struct fixture) {
    var replacement = [
      { lat = 28.5000000, lng = -82.5000000 },
      { lat = 28.5500000, lng = -82.5500000 },
      { lat = 28.6000000, lng = -82.6000000 }
    ];

    queryExecute(
      "UPDATE route_leg_user_overrides
       SET geometry_json = :geometryJson,
           computed_nm = 99.99,
           updated_at = DATE_ADD(NOW(), INTERVAL 1 SECOND)
       WHERE user_id = :userId
         AND route_id = :routeId
         AND route_leg_order = 1",
      {
        geometryJson = {
          value = serializeJSON(replacement),
          cfsqltype = "cf_sql_longvarchar"
        },
        userId = { value = arguments.fixture.userId, cfsqltype = "cf_sql_integer" },
        routeId = { value = arguments.fixture.userRouteId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );
  }

  private void function reverseUnderlyingOverrideGeometry(required struct fixture) {
    var qOverrides = queryNew("");
    var rowIndex = 0;
    var pointIndex = 0;
    var points = [];
    var reversedPoints = [];

    qOverrides = queryExecute(
      "SELECT id, geometry_json
       FROM route_leg_user_overrides
       WHERE user_id = :userId
         AND route_id = :routeId
       ORDER BY route_leg_order ASC, id ASC",
      {
        userId = { value = arguments.fixture.userId, cfsqltype = "cf_sql_integer" },
        routeId = { value = arguments.fixture.userRouteId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );

    expect(qOverrides.recordCount).toBe(2);
    for (rowIndex = 1; rowIndex LTE qOverrides.recordCount; rowIndex++) {
      points = deserializeJSON(toString(qOverrides.geometry_json[rowIndex]), false);
      reversedPoints = [];
      for (pointIndex = arrayLen(points); pointIndex GTE 1; pointIndex--) {
        arrayAppend(reversedPoints, points[pointIndex]);
      }
      queryExecute(
        "UPDATE route_leg_user_overrides
         SET geometry_json = :geometryJson,
             updated_at = DATE_ADD(NOW(), INTERVAL 1 SECOND)
         WHERE id = :overrideId",
        {
          geometryJson = {
            value = serializeJSON(reversedPoints),
            cfsqltype = "cf_sql_longvarchar"
          },
          overrideId = { value = val(qOverrides.id[rowIndex]), cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
    }
  }

  private void function assertCoordinate(
    required array coordinate,
    required numeric expectedLng,
    required numeric expectedLat
  ) {
    expect(arrayLen(arguments.coordinate)).toBeGT(1);
    expect(abs(val(arguments.coordinate[1]) - arguments.expectedLng) LT 0.00000005).toBeTrue();
    expect(abs(val(arguments.coordinate[2]) - arguments.expectedLat) LT 0.00000005).toBeTrue();
  }

  private void function assertPin(
    required struct pin,
    required numeric expectedSequence,
    required string expectedType,
    required string expectedEndpointRole,
    required numeric expectedLegOrder,
    required numeric expectedLat,
    required numeric expectedLng
  ) {
    expect(val(arguments.pin.seq)).toBe(arguments.expectedSequence);
    expect(val(arguments.pin.sequence)).toBe(arguments.expectedSequence);
    expect(lCase(toString(arguments.pin.type))).toBe(arguments.expectedType);
    expect(lCase(toString(arguments.pin.endpoint_role))).toBe(arguments.expectedEndpointRole);
    expect(val(arguments.pin.leg_order)).toBe(arguments.expectedLegOrder);
    expect(abs(val(arguments.pin.lat) - arguments.expectedLat) LT 0.00000005).toBeTrue();
    expect(abs(val(arguments.pin.lng) - arguments.expectedLng) LT 0.00000005).toBeTrue();
  }

  private string function serializePinAuthority(required array pins) {
    var normalized = [];
    var index = 0;
    var pin = {};

    for (index = 1; index LTE arrayLen(arguments.pins); index++) {
      pin = arguments.pins[index];
      arrayAppend(normalized, [
        val(pin.lat),
        val(pin.lng),
        val(pin.sequence),
        lCase(toString(pin.type)),
        val(pin.leg_order),
        lCase(toString(pin.endpoint_role))
      ]);
    }
    return serializeJSON(normalized);
  }

  private string function readRepoFile(required string relativePath) {
    return fileRead(expandPath("/fpw/" & arguments.relativePath), "utf-8");
  }

  private numeric function findLastNoCaseBefore(
    required string needle,
    required string haystack,
    required numeric beforePosition
  ) {
    var lastPosition = 0;
    var searchPosition = 1;
    var candidate = 0;

    while (searchPosition LT arguments.beforePosition) {
      candidate = findNoCase(arguments.needle, arguments.haystack, searchPosition);
      if (candidate LTE 0 OR candidate GTE arguments.beforePosition) {
        break;
      }
      lastPosition = candidate;
      searchPosition = candidate + 1;
    }
    return lastPosition;
  }

  private void function cleanupFixtures() {
    var params = {
      fixturePattern = {
        value = variables.fixturePrefix & "%",
        cfsqltype = "cf_sql_varchar"
      }
    };

    queryExecute(
      "DELETE FROM route_instance_geometry_snapshots
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
      "DELETE FROM route_leg_user_overrides
       WHERE user_id IN (
         SELECT userId FROM users WHERE email LIKE :fixturePattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM user_route_legs
       WHERE user_route_id IN (
         SELECT id FROM user_routes
         WHERE user_id IN (
           SELECT userId FROM users WHERE email LIKE :fixturePattern
         )
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM user_routes
       WHERE user_id IN (
         SELECT userId FROM users WHERE email LIKE :fixturePattern
       )",
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
