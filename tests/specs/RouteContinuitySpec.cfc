component extends="testbox.system.BaseSpec" output="false" {

  variables.datasource = "fpw";
  variables.fixtureEmailPrefix = "codex-route-continuity-";

  function beforeAll() {
    cleanupFixtures();
  }

  function afterAll() {
    cleanupFixtures();
  }

  function run() {
    describe("My Route continuity invariant", function() {

      beforeEach(function() {
        cleanupFixtures();
        variables.routeBuilder = createObject("component", "fpw.api.v1.routeBuilder");
        makePublic(variables.routeBuilder, "removeLegFromUserRoute", "removeLegForTest");
        makePublic(variables.routeBuilder, "reorderUserRouteLegs", "reorderLegsForTest");
        makePublic(variables.routeBuilder, "getUserRoute", "getUserRouteForTest");
        makePublic(variables.routeBuilder, "previewUserRoute", "previewUserRouteForTest");
        makePublic(variables.routeBuilder, "routegenValidateUserRouteContinuity", "validateContinuityForTest");
      });

      afterEach(function() {
        cleanupFixtures();
      });

      it("reconnects the following leg when a middle appended waypoint is removed", function() {
        var fixture = createFixture("middle-delete", 4);
        var result = {};
        var legs = queryNew("");
        var reopened = {};
        var validation = {};
        var overrideCount = queryNew("");

        addLegOverride(fixture, fixture.legIds[3]);
        result = variables.routeBuilder.removeLegForTest(
          fixture.userId,
          fixture.routeId,
          fixture.legIds[2]
        );
        legs = loadLegs(fixture.routeId);
        reopened = variables.routeBuilder.getUserRouteForTest(fixture.userId, fixture.routeId);
        validation = variables.routeBuilder.validateContinuityForTest(fixture.userId, fixture.routeId);
        overrideCount = queryExecute(
          "SELECT COUNT(*) AS total
           FROM route_leg_user_overrides
           WHERE user_id = :userId
             AND route_id = :routeId",
          {
            userId = { value=fixture.userId, cfsqltype="cf_sql_integer" },
            routeId = { value=fixture.routeId, cfsqltype="cf_sql_integer" }
          },
          { datasource=variables.datasource }
        );

        expect(result.SUCCESS).toBeTrue();
        expect(legs.recordCount).toBe(2);
        expect(val(legs.id[1])).toBe(fixture.legIds[1]);
        expect(val(legs.id[2])).toBe(fixture.legIds[3]);
        expect(val(legs.order_index[1])).toBe(1);
        expect(val(legs.order_index[2])).toBe(2);
        expect(val(legs.start_waypoint_id[1])).toBe(fixture.waypointIds[1]);
        expect(val(legs.end_waypoint_id[1])).toBe(fixture.waypointIds[2]);
        expect(val(legs.start_waypoint_id[2])).toBe(fixture.waypointIds[2]);
        expect(val(legs.end_waypoint_id[2])).toBe(fixture.waypointIds[4]);
        expect(isNull(legs.segment_id[2]) OR val(legs.segment_id[2]) EQ 0).toBeTrue();
        expect(val(overrideCount.total[1])).toBe(0);
        expect(validation.VALID).toBeTrue();
        expect(validation.LEG_COUNT).toBe(2);
        expect(validation.WAYPOINT_COUNT).toBe(3);
        expect(reopened.SUCCESS).toBeTrue();
        expect(arrayLen(reopened.DATA.legs)).toBe(2);
      });

      it("rejects a disconnected save candidate and leaves the valid route unchanged", function() {
        var fixture = createFixture("negative-save", 4);
        var previewResult = {};
        var rollbackSeen = false;
        var legs = queryNew("");

        try {
          transaction {
            queryExecute(
              "UPDATE user_route_legs
               SET start_waypoint_id = :disconnectedStart
               WHERE id = :routeLegId
                 AND user_route_id = :routeId",
              {
                disconnectedStart = { value=fixture.waypointIds[4], cfsqltype="cf_sql_integer" },
                routeLegId = { value=fixture.legIds[2], cfsqltype="cf_sql_integer" },
                routeId = { value=fixture.routeId, cfsqltype="cf_sql_integer" }
              },
              { datasource=variables.datasource }
            );
            previewResult = variables.routeBuilder.previewUserRouteForTest(
              fixture.userId,
              fixture.routeId,
              previewInput()
            );
            throw(type="FPW.RouteContinuityFixtureRollback", message="Rollback the malformed disposable route.");
          }
        } catch (any rollbackErr) {
          if (rollbackErr.type NEQ "FPW.RouteContinuityFixtureRollback") rethrow;
          rollbackSeen = true;
        }

        legs = loadLegs(fixture.routeId);
        expect(rollbackSeen).toBeTrue();
        expect(previewResult.SUCCESS).toBeFalse();
        expect(previewResult.STATUS_CODE).toBe(409);
        expect(previewResult.ERROR.CODE).toBe("ROUTE_CONTINUITY_INVALID");
        expect(legs.recordCount).toBe(3);
        expect(val(legs.start_waypoint_id[2])).toBe(fixture.waypointIds[2]);
        expect(variables.routeBuilder.validateContinuityForTest(fixture.userId, fixture.routeId).VALID).toBeTrue();
      });

      it("keeps terminal deletion valid", function() {
        var fixture = createFixture("terminal-delete", 4);
        var result = variables.routeBuilder.removeLegForTest(
          fixture.userId,
          fixture.routeId,
          fixture.legIds[3]
        );
        var legs = loadLegs(fixture.routeId);
        var validation = variables.routeBuilder.validateContinuityForTest(fixture.userId, fixture.routeId);

        expect(result.SUCCESS).toBeTrue();
        expect(legs.recordCount).toBe(2);
        expect(val(legs.id[1])).toBe(fixture.legIds[1]);
        expect(val(legs.id[2])).toBe(fixture.legIds[2]);
        expect(val(legs.end_waypoint_id[1])).toBe(val(legs.start_waypoint_id[2]));
        expect(validation.VALID).toBeTrue();
        expect(validation.LEG_COUNT).toBe(2);
        expect(validation.WAYPOINT_COUNT).toBe(3);
      });

      it("reopens the reconnected route with stable order endpoints and metadata", function() {
        var fixture = createFixture("reopen", 4);
        var removed = variables.routeBuilder.removeLegForTest(
          fixture.userId,
          fixture.routeId,
          fixture.legIds[2]
        );
        var reopenedFirst = variables.routeBuilder.getUserRouteForTest(fixture.userId, fixture.routeId);
        var reopenedSecond = variables.routeBuilder.getUserRouteForTest(fixture.userId, fixture.routeId);
        var firstDistance = 0;
        var secondDistance = 0;

        expect(removed.SUCCESS).toBeTrue();
        expect(reopenedFirst.SUCCESS).toBeTrue();
        expect(reopenedSecond.SUCCESS).toBeTrue();
        expect(arrayLen(reopenedFirst.DATA.legs)).toBe(2);
        expect(arrayLen(reopenedSecond.DATA.legs)).toBe(2);
        expect(reopenedFirst.DATA.legs[1].end_waypoint_id).toBe(reopenedFirst.DATA.legs[2].start_waypoint_id);
        expect(reopenedSecond.DATA.legs[1].end_waypoint_id).toBe(reopenedSecond.DATA.legs[2].start_waypoint_id);
        expect(reopenedFirst.DATA.legs[2].end_waypoint_id).toBe(fixture.waypointIds[4]);
        expect(reopenedSecond.DATA.legs[2].route_leg_id).toBe(fixture.legIds[3]);

        firstDistance = val(reopenedFirst.DATA.legs[1].dist_nm) + val(reopenedFirst.DATA.legs[2].dist_nm);
        secondDistance = val(reopenedSecond.DATA.legs[1].dist_nm) + val(reopenedSecond.DATA.legs[2].dist_nm);
        expect(firstDistance).toBeGT(0);
        expect(secondDistance).toBe(firstDistance);
      });
    });
  }

  private struct function createFixture(required string label, required numeric waypointCount) {
    var token = lCase(replace(createUUID(), "-", "", "all"));
    var email = variables.fixtureEmailPrefix & token & "@example.test";
    var marker = variables.fixtureEmailPrefix & arguments.label & "-" & token;
    var fixture = {
      email=email,
      marker=marker,
      userId=0,
      routeId=0,
      waypointIds=[],
      legIds=[]
    };
    var qUser = queryNew("");
    var qRoute = queryNew("");
    var qWaypoints = queryNew("");
    var qLegs = queryNew("");
    var i = 0;

    queryExecute(
      "INSERT INTO users (fName, lName, email, password, passwordCreated, created)
       VALUES ('Codex Route', 'Continuity Test', :email, :password, UTC_TIMESTAMP(), UTC_TIMESTAMP())",
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
    fixture.userId = val(qUser.userId[1]);

    for (i = 1; i LTE arguments.waypointCount; i++) {
      queryExecute(
        "INSERT INTO waypoints (name, latitude, longitude, userId, notes)
         VALUES (:name, :latitude, :longitude, :userId, :notes)",
        {
          name = { value="QA3-001 " & chr(64 + i), cfsqltype="cf_sql_varchar" },
          latitude = { value=numberFormat(28 + (i / 100), "0.0000000"), cfsqltype="cf_sql_varchar" },
          longitude = { value=numberFormat(-82 - (i / 100), "0.0000000"), cfsqltype="cf_sql_varchar" },
          userId = { value=toString(fixture.userId), cfsqltype="cf_sql_varchar" },
          notes = { value=marker, cfsqltype="cf_sql_longvarchar" }
        },
        { datasource=variables.datasource }
      );
    }
    qWaypoints = queryExecute(
      "SELECT wpId
       FROM waypoints
       WHERE CAST(userId AS UNSIGNED) = :userId
         AND notes = :marker
       ORDER BY wpId ASC",
      {
        userId = { value=fixture.userId, cfsqltype="cf_sql_integer" },
        marker = { value=marker, cfsqltype="cf_sql_varchar" }
      },
      { datasource=variables.datasource }
    );
    for (i = 1; i LTE qWaypoints.recordCount; i++) {
      arrayAppend(fixture.waypointIds, val(qWaypoints.wpId[i]));
    }

    queryExecute(
      "INSERT INTO user_routes (user_id, route_name, start_waypoint_id, is_active)
       VALUES (:userId, :routeName, :startWaypointId, 1)",
      {
        userId = { value=fixture.userId, cfsqltype="cf_sql_integer" },
        routeName = { value=marker, cfsqltype="cf_sql_varchar" },
        startWaypointId = { value=fixture.waypointIds[1], cfsqltype="cf_sql_integer" }
      },
      { datasource=variables.datasource }
    );
    qRoute = queryExecute(
      "SELECT id FROM user_routes WHERE user_id = :userId AND route_name = :routeName LIMIT 1",
      {
        userId = { value=fixture.userId, cfsqltype="cf_sql_integer" },
        routeName = { value=marker, cfsqltype="cf_sql_varchar" }
      },
      { datasource=variables.datasource }
    );
    fixture.routeId = val(qRoute.id[1]);

    for (i = 1; i LT arrayLen(fixture.waypointIds); i++) {
      queryExecute(
        "INSERT INTO user_route_legs
            (user_route_id, order_index, segment_id, start_waypoint_id, end_waypoint_id)
         VALUES
            (:routeId, :orderIndex, NULL, :startWaypointId, :endWaypointId)",
        {
          routeId = { value=fixture.routeId, cfsqltype="cf_sql_integer" },
          orderIndex = { value=i, cfsqltype="cf_sql_integer" },
          startWaypointId = { value=fixture.waypointIds[i], cfsqltype="cf_sql_integer" },
          endWaypointId = { value=fixture.waypointIds[i + 1], cfsqltype="cf_sql_integer" }
        },
        { datasource=variables.datasource }
      );
    }
    qLegs = loadLegs(fixture.routeId);
    for (i = 1; i LTE qLegs.recordCount; i++) {
      arrayAppend(fixture.legIds, val(qLegs.id[i]));
    }
    return fixture;
  }

  private void function addLegOverride(required struct fixture, required numeric routeLegId) {
    var qLeg = queryExecute(
      "SELECT order_index FROM user_route_legs WHERE id = :routeLegId LIMIT 1",
      { routeLegId = { value=arguments.routeLegId, cfsqltype="cf_sql_integer" } },
      { datasource=variables.datasource }
    );
    queryExecute(
      "INSERT INTO route_leg_user_overrides
          (user_id, route_id, route_leg_id, route_leg_order, segment_id, geometry_json, computed_nm)
       VALUES
          (:userId, :routeId, :routeLegId, :routeLegOrder, NULL, :geometryJson, 1.25)",
      {
        userId = { value=arguments.fixture.userId, cfsqltype="cf_sql_integer" },
        routeId = { value=arguments.fixture.routeId, cfsqltype="cf_sql_integer" },
        routeLegId = { value=arguments.routeLegId, cfsqltype="cf_sql_integer" },
        routeLegOrder = { value=val(qLeg.order_index[1]), cfsqltype="cf_sql_integer" },
        geometryJson = { value='[{"lat":28.03,"lon":-82.03},{"lat":28.04,"lon":-82.04}]', cfsqltype="cf_sql_longvarchar" }
      },
      { datasource=variables.datasource }
    );
  }

  private query function loadLegs(required numeric routeId) {
    return queryExecute(
      "SELECT id, order_index, segment_id, start_waypoint_id, end_waypoint_id
       FROM user_route_legs
       WHERE user_route_id = :routeId
       ORDER BY order_index ASC, id ASC",
      { routeId = { value=arguments.routeId, cfsqltype="cf_sql_integer" } },
      { datasource=variables.datasource }
    );
  }

  private struct function previewInput() {
    return {
      start_date=dateFormat(dateAdd("d", 1, now()), "yyyy-mm-dd"),
      pace="cruise",
      cruising_speed=10,
      underway_hours_per_day=8,
      fuel_burn_gph="",
      fuel_burn_gph_input="",
      fuel_burn_basis="MAX_SPEED",
      idle_burn_gph="",
      idle_hours_total="",
      weather_factor_pct=0,
      reserve_pct=20,
      reserve_mode="percentage",
      fuel_price_per_gal="",
      comfort_profile="PREFER_INSIDE"
    };
  }

  private void function cleanupFixtures() {
    var emailPattern = variables.fixtureEmailPrefix & "%";
    var params = {
      emailPattern = { value=emailPattern, cfsqltype="cf_sql_varchar" }
    };

    queryExecute(
      "DELETE FROM route_leg_user_overrides
       WHERE user_id IN (SELECT userId FROM users WHERE email LIKE :emailPattern)",
      params,
      { datasource=variables.datasource }
    );
    queryExecute(
      "DELETE FROM user_route_legs
       WHERE user_route_id IN (
         SELECT id FROM user_routes
         WHERE user_id IN (SELECT userId FROM users WHERE email LIKE :emailPattern)
       )",
      params,
      { datasource=variables.datasource }
    );
    queryExecute(
      "DELETE FROM user_routes
       WHERE user_id IN (SELECT userId FROM users WHERE email LIKE :emailPattern)",
      params,
      { datasource=variables.datasource }
    );
    queryExecute(
      "DELETE FROM waypoints
       WHERE CAST(userId AS UNSIGNED) IN (
         SELECT userId FROM users WHERE email LIKE :emailPattern
       )",
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
