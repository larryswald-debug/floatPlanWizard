component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.api = new fpw.tests.support.FpwApiSupport().init(
      authEmail = "detroit@email.com",
      authPassword = "changeIt"
    );
    variables.naming = new fpw.tests.support.FpwNamingSupport();
    variables.routeProgressService = new fpw.api.v1.RouteProgressService().init();
    variables.sessionApiUser = createSessionApiUser();
  }

  function afterAll() {
    cleanupSessionApiUser();
    structDelete( url, "testUserId", false );
  }

  function run() {
    describe( "Route progress close gating", function() {
      it( "blocks Arrived close when no active leg exists and the final leg is not completed", function() {
        var prefix = variables.naming.buildPrefix( "route-progress-close", "blocks-no-active-leg" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var asset = {};
        var planState = {};
        var qLegs = queryNew( "" );
        var firstLegOrder = 0;
        var finalLegOrder = 0;
        var closePayload = {};
        var qFinalLeg = queryNew( "" );
        var planAfter = {};
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          markPlanActive( asset.floatPlanId );
          planState = loadRoutePlanState( asset.floatPlanId );
          qLegs = loadRouteLegOrders( planState.route_instance_id );
          expect( qLegs.recordCount ).toBeGT( 1 );
          ensureOpenMonitoringRow( asset.floatPlanId, planState.user_id );

          firstLegOrder = val( qLegs.leg_order[ 1 ] );
          finalLegOrder = val( qLegs.leg_order[ qLegs.recordCount ] );

          clearRouteProgress( planState.user_id, planState.route_instance_id );
          seedCompletedLeg( planState.user_id, planState.route_instance_id, firstLegOrder );

          closePayload = sessionApi.checkinFloatPlan( asset.floatPlanId );
          qFinalLeg = loadLegProgress( planState.user_id, planState.route_instance_id, finalLegOrder );
          planAfter = loadRoutePlanState( asset.floatPlanId );

          expect( closePayload.SUCCESS ).toBeFalse( serializeJSON( closePayload ) );
          expect( trim( toString( closePayload.ERROR ?: "" ) ) ).toBe( "CLOSE_TRIP_BLOCKED" );
          expect( trim( toString( closePayload.MESSAGE ?: "" ) ) ).toBe( "Close Trip is only available once the final leg is active." );
          expect( planAfter.status ).toBe( "ACTIVE" );
          expect( qFinalLeg.recordCount ).toBe( 0 );
        } finally {
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "allows Arrived close when the final leg is active and marks it complete", function() {
        var prefix = variables.naming.buildPrefix( "route-progress-close", "allows-final-leg-active" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var asset = {};
        var planState = {};
        var qLegs = queryNew( "" );
        var finalLegOrder = 0;
        var closePayload = {};
        var qFinalLeg = queryNew( "" );
        var planAfter = {};
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          markPlanActive( asset.floatPlanId );
          planState = loadRoutePlanState( asset.floatPlanId );
          qLegs = loadRouteLegOrders( planState.route_instance_id );
          expect( qLegs.recordCount ).toBeGT( 0 );
          ensureOpenMonitoringRow( asset.floatPlanId, planState.user_id );

          finalLegOrder = val( qLegs.leg_order[ qLegs.recordCount ] );

          clearRouteProgress( planState.user_id, planState.route_instance_id );
          seedStartedLeg( planState.user_id, planState.route_instance_id, finalLegOrder );

          closePayload = sessionApi.checkinFloatPlan( asset.floatPlanId );
          qFinalLeg = loadLegProgress( planState.user_id, planState.route_instance_id, finalLegOrder );
          planAfter = loadRoutePlanState( asset.floatPlanId );

          expect( closePayload.SUCCESS ).toBeTrue( serializeJSON( closePayload ) );
          expect( uCase( planAfter.status ) ).toBe( "CLOSED" );
          expect( qFinalLeg.recordCount ).toBe( 1 );
          expect( trim( toString( qFinalLeg.status[ 1 ] ) ) ).toBe( "COMPLETED" );
        } finally {
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );
    } );
  }

  private any function buildSessionApiSupport() {
    return new fpw.tests.support.FpwApiSupport().init(
      baseUrl = variables.api.getBaseUrl(),
      authEmail = variables.sessionApiUser.email,
      authPassword = variables.sessionApiUser.password
    );
  }

  private struct function createSessionApiUser() {
    var signupApi = new fpw.tests.support.FpwApiSupport().init(
      baseUrl = variables.api.getBaseUrl()
    );
    var uniqueEmail = "fpw-stage3-" & replace( createUUID(), "-", "", "all" ) & "@example.com";
    var payload = signupApi.postJson( "/api/v1/join.cfc?method=handle", {
      firstName = "FPW",
      lastName = "Stage3",
      email = uniqueEmail,
      password = "changeIt"
    }, false );

    expect( payload.SUCCESS ).toBeTrue( serializeJSON( payload ) );
    expect( val( payload.USERID ?: 0 ) ).toBeGT( 0, serializeJSON( payload ) );

    return {
      userId = val( payload.USERID ),
      email = uniqueEmail,
      password = "changeIt"
    };
  }

  private void function cleanupSessionApiUser() {
    var userId = 0;

    if ( !structKeyExists( variables, "sessionApiUser" ) || !isStruct( variables.sessionApiUser ) ) {
      return;
    }

    userId = val( variables.sessionApiUser.userId ?: 0 );
    if ( userId LTE 0 ) {
      return;
    }

    queryExecute(
      "DELETE FROM users_address WHERE userId = :userId",
      {
        userId = { value = userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM users WHERE userId = :userId",
      {
        userId = { value = userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private struct function createRouteLinkedDraftForApi( required any apiSupport, required string prefix, required struct created ) {
    var vesselPayload = arguments.apiSupport.saveVessel( {
      vesselId = 0,
      vesselName = variables.naming.buildName( arguments.prefix, "Lifecycle Vessel" ),
      type = "Cruiser",
      length = 34,
      color = "White"
    } );
    var vesselId = val( vesselPayload.VESSELID ?: 0 );
    var options = arguments.apiSupport.routeBuilder( "routegen_getoptions", {
      template_code = "GULF-WEST",
      direction = "CCW"
    } );
    ensureSuccess( vesselPayload, "save vessel" );
    ensureSuccess( options, "load route template options" );

    var generate = arguments.apiSupport.routeBuilder( "routegen_generate", {
      route_name = variables.naming.buildName( arguments.prefix, "Lifecycle Route" ),
      template_code = "GULF-WEST",
      direction = "CCW",
      start_segment_id = options.DATA.startOptions[ 1 ].segment_id,
      end_segment_id = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].segment_id,
      start_location_label = options.DATA.startOptions[ 1 ].label,
      end_location_label = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].label,
      start_date = "2026-04-09",
      optional_stop_flags = [ "ship_island_out_and_back" ]
    } );
    ensureSuccess( generate, "generate route" );

    var routeCode = trim( toString( generate.ROUTE_CODE ?: generate.DATA.route_code ?: "" ) );
    var buildPayload = arguments.apiSupport.routeBuilder( "buildFloatPlansFromRoute", {
      routeCode = routeCode,
      mode = "DAILY",
      vesselId = vesselId,
      rebuild = 0
    } );
    ensureSuccess( buildPayload, "build route-linked float plans" );

    var floatPlanId = val( buildPayload.FLOATPLAN_IDS[ 1 ] ?: 0 );
    expect( floatPlanId ).toBeGT( 0, serializeJSON( buildPayload ) );

    arrayAppend( arguments.created.vesselIds, vesselId );
    arrayAppend( arguments.created.routeCodes, routeCode );
    for ( var id in buildPayload.FLOATPLAN_IDS ) {
      arrayAppend( arguments.created.floatPlanIds, val( id ) );
    }

    return {
      vesselId = vesselId,
      routeCode = routeCode,
      floatPlanId = floatPlanId
    };
  }

  private void function cleanupRouteLinkedAssetsForApi( required any apiSupport, required struct created ) {
    var cleanupSupport = new fpw.tests.support.FpwCleanupSupport().init( arguments.apiSupport );
    for ( var i = arrayLen( arguments.created.floatPlanIds ); i GTE 1; i-- ) {
      try {
        cleanupSupport.cleanupFloatPlan( arguments.created.floatPlanIds[ i ] );
      } catch ( any ignoredFloatPlanCleanup ) {}
      forceDeleteFloatPlanRecords( arguments.created.floatPlanIds[ i ] );
    }
    for ( var j = arrayLen( arguments.created.routeCodes ); j GTE 1; j-- ) {
      try {
        cleanupSupport.cleanupRoute( arguments.created.routeCodes[ j ] );
      } catch ( any ignoredRouteCleanup ) {}
    }
    for ( var k = arrayLen( arguments.created.vesselIds ); k GTE 1; k-- ) {
      try {
        cleanupSupport.cleanupVessel( arguments.created.vesselIds[ k ] );
      } catch ( any ignoredVesselCleanup ) {}
    }
  }

  private void function markPlanActive( required numeric floatPlanId ) {
    queryExecute(
      "UPDATE floatplans
       SET `status` = 'ACTIVE',
           activatedAt = UTC_TIMESTAMP(),
           checkedInAt = NULL,
           checkin_context = NULL,
           closedAt = NULL,
           lastUpdateStatus = UTC_TIMESTAMP()
       WHERE floatplanId = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private struct function loadRoutePlanState( required numeric floatPlanId ) {
    var qPlan = queryExecute(
      "SELECT userId, route_instance_id, `status`
       FROM floatplans
       WHERE floatplanId = :floatPlanId
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    expect( qPlan.recordCount ).toBe( 1 );
    return {
      user_id = val( qPlan.userId[ 1 ] ),
      route_instance_id = val( qPlan.route_instance_id[ 1 ] ),
      status = trim( toString( qPlan.status[ 1 ] ) )
    };
  }

  private query function loadRouteLegOrders( required numeric routeInstanceId ) {
    return queryExecute(
      "SELECT leg_order
       FROM route_instance_legs
       WHERE route_instance_id = :routeInstanceId
       ORDER BY leg_order ASC, id ASC",
      {
        routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function clearRouteProgress( required numeric userId, required numeric routeInstanceId ) {
    queryExecute(
      "DELETE FROM route_instance_leg_progress
       WHERE user_id = :userId
         AND route_instance_id = :routeInstanceId",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function seedCompletedLeg( required numeric userId, required numeric routeInstanceId, required numeric legOrder ) {
    queryExecute(
      "INSERT INTO route_instance_leg_progress (user_id, route_instance_id, leg_order, status, leg_started_at, completed_at)
       VALUES (:userId, :routeInstanceId, :legOrder, 'COMPLETED', UTC_TIMESTAMP(), UTC_TIMESTAMP())",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" },
        legOrder = { value = arguments.legOrder, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function seedStartedLeg( required numeric userId, required numeric routeInstanceId, required numeric legOrder ) {
    queryExecute(
      "INSERT INTO route_instance_leg_progress (user_id, route_instance_id, leg_order, status, leg_started_at)
       VALUES (:userId, :routeInstanceId, :legOrder, 'STARTED', UTC_TIMESTAMP())",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" },
        legOrder = { value = arguments.legOrder, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private query function loadLegProgress( required numeric userId, required numeric routeInstanceId, required numeric legOrder ) {
    return queryExecute(
      "SELECT status, leg_started_at, completed_at
       FROM route_instance_leg_progress
       WHERE user_id = :userId
         AND route_instance_id = :routeInstanceId
         AND leg_order = :legOrder
       ORDER BY id DESC
       LIMIT 1",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" },
        legOrder = { value = arguments.legOrder, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function ensureOpenMonitoringRow( required numeric floatPlanId, required numeric userId, string monitorState = "ACTIVE" ) {
    var qMonitoring = queryExecute(
      "SELECT id
       FROM floatplan_monitoring
       WHERE float_plan_id = :floatPlanId
         AND is_monitoring_enabled = 1
         AND UPPER(TRIM(monitor_state)) <> 'CLOSED'
       ORDER BY id DESC
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );

    if ( qMonitoring.recordCount GT 0 ) {
      return;
    }

    queryExecute(
      "INSERT INTO floatplan_monitoring (
          float_plan_id,
          user_id,
          monitoring_mode,
          monitor_state,
          is_monitoring_enabled,
          expected_checkin_at,
          grace_expires_at,
          missed_at,
          escalated_at,
          resolved_at,
          closed_at,
          last_checkin_at,
          last_checkin_status,
          secure_for_night,
          secure_for_night_until,
          escalation_delay_minutes,
          grace_window_minutes,
          next_monitor_eval_at,
          last_monitor_eval_at,
          last_captain_alert_at,
          last_contact_alert_at,
          created_at,
          updated_at
       ) VALUES (
          :floatPlanId,
          :userId,
          'active_route',
          :monitorState,
          1,
          DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR),
          DATE_ADD(UTC_TIMESTAMP(), INTERVAL 2 HOUR),
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          0,
          NULL,
          120,
          60,
          DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR),
          NULL,
          NULL,
          NULL,
          UTC_TIMESTAMP(),
          UTC_TIMESTAMP()
       )",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        monitorState = { value = uCase( trim( arguments.monitorState ) ), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
  }

  private void function forceDeleteFloatPlanRecords( required numeric floatPlanId ) {
    queryExecute(
      "DELETE FROM floatplan_monitor_events WHERE float_plan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM floatplan_monitoring WHERE float_plan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM floatplan_passengers WHERE floatPlanId = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM floatplan_contacts WHERE floatPlanId = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM floatplan_waypoints WHERE floatPlanId = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM floatplans WHERE floatPlanId = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function ensureSuccess( required struct payload, required string label ) {
    if ( !structKeyExists( arguments.payload, "SUCCESS" ) OR arguments.payload.SUCCESS NEQ true ) {
      throw( message = "Route progress lifecycle test setup failed: " & arguments.label, detail = serializeJSON( arguments.payload ) );
    }
  }
}
