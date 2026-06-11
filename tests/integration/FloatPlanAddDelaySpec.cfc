component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    ensureManualDelayColumnExists();
    variables.api = new fpw.tests.support.FpwApiSupport().init(
      authEmail = "detroit@email.com",
      authPassword = "changeIt"
    );
    variables.naming = new fpw.tests.support.FpwNamingSupport();
    variables.monitorService = new fpw.api.v1.monitor().init();
    variables.sessionApiUser = createSessionApiUser();
  }

  function afterAll() {
    cleanupSessionApiUser();
    structDelete( url, "testUserId", false );
  }

  function run() {
    describe( "Float plan adddelay action", function() {
      it( "proves the manual delay schema exists", function() {
        var qColumn = loadManualDelayColumn();
        expect( qColumn.recordCount ).toBe( 1 );
        expect( lCase( trim( toString( qColumn.data_type[ 1 ] ) ) ) ).toBe( "int" );
        expect( trim( toString( qColumn.is_nullable[ 1 ] ) ) ).toBe( "NO" );
        expect( val( qColumn.column_default[ 1 ] ) ).toBe( 0 );
      } );

      it( "increments and accumulates manual delay minutes without changing monitoring cadence", function() {
        var sessionApi = buildSessionApiSupport();
        var created = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var prefix = variables.naming.buildPrefix( "float-plan-adddelay", "accumulate" );
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";
        var asset = {};
        var startMonitoringResult = {};
        var monitoringBefore = {};
        var monitoringAfter = {};
        var add15 = {};
        var add30 = {};
        var delayState = {};
        var qDelayEvents = queryNew( "" );

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, created );
          setPlanSchedule( asset.floatPlanId, "2026-04-15 09:00:00", "2026-04-16 20:00:00", "US/Eastern" );
          markPlanActive( asset.floatPlanId );
          startMonitoringResult = variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" );
          ensureSuccess( startMonitoringResult, "start active_route monitor" );

          monitoringBefore = loadMonitoringRow( asset.floatPlanId );

          add15 = postAddDelayWithApi( sessionApi, asset.floatPlanId, 15 );
          add30 = postAddDelayWithApi( sessionApi, asset.floatPlanId, 30 );

          delayState = loadDelayState( asset.floatPlanId );
          monitoringAfter = loadMonitoringRow( asset.floatPlanId );
          qDelayEvents = loadDelayEvents( asset.floatPlanId );

          expect( add15.SUCCESS ).toBeTrue( serializeJSON( add15 ) );
          expect( val( add15.ADDED_MINUTES ?: 0 ) ).toBe( 15 );
          expect( val( add15.MANUAL_DELAY_MINUTES_TOTAL ?: 0 ) ).toBe( 15 );
          expect( add15.EVENT_LOGGED ?: false ).toBeTrue();

          expect( add30.SUCCESS ).toBeTrue( serializeJSON( add30 ) );
          expect( val( add30.ADDED_MINUTES ?: 0 ) ).toBe( 30 );
          expect( val( add30.MANUAL_DELAY_MINUTES_TOTAL ?: 0 ) ).toBe( 45 );
          expect( add30.EVENT_LOGGED ?: false ).toBeTrue();

          expect( delayState.manual_delay_minutes_total ).toBe( 45 );

          expect( monitoringAfter.monitor_state ).toBe( monitoringBefore.monitor_state );
          expect( monitoringAfter.is_monitoring_enabled ).toBe( monitoringBefore.is_monitoring_enabled );
          expect( normalizeDbDateTime( monitoringAfter.expected_checkin_at ) ).toBe( normalizeDbDateTime( monitoringBefore.expected_checkin_at ) );
          expect( normalizeDbDateTime( monitoringAfter.grace_expires_at ) ).toBe( normalizeDbDateTime( monitoringBefore.grace_expires_at ) );
          expect( normalizeDbDateTime( monitoringAfter.next_monitor_eval_at ) ).toBe( normalizeDbDateTime( monitoringBefore.next_monitor_eval_at ) );

          expect( qDelayEvents.recordCount ).toBe( 2 );
          expect( trim( toString( qDelayEvents.title[ 1 ] ) ) ).toBe( "Delay added: 30 minutes" );
          expect( trim( toString( qDelayEvents.title[ 2 ] ) ) ).toBe( "Delay added: 15 minutes" );
        } finally {
          cleanupRouteLinkedAssetsForApi( sessionApi, created );
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
        }
      } );

      it( "clears manual delay minutes back to zero for the canonical active float plan", function() {
        var sessionApi = buildSessionApiSupport();
        var created = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var prefix = variables.naming.buildPrefix( "float-plan-adddelay", "clear" );
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";
        var asset = {};
        var startMonitoringResult = {};
        var addDelayResult = {};
        var clearDelayResult = {};
        var delayState = {};
        var monitoringBefore = {};
        var monitoringAfter = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, created );
          setPlanSchedule( asset.floatPlanId, "2026-04-15 09:00:00", "2026-04-16 20:00:00", "US/Eastern" );
          markPlanActive( asset.floatPlanId );
          startMonitoringResult = variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" );
          ensureSuccess( startMonitoringResult, "start active_route monitor" );

          monitoringBefore = loadMonitoringRow( asset.floatPlanId );
          addDelayResult = postAddDelayWithApi( sessionApi, asset.floatPlanId, 30 );
          clearDelayResult = postClearDelayWithApi( sessionApi, asset.floatPlanId );
          delayState = loadDelayState( asset.floatPlanId );
          monitoringAfter = loadMonitoringRow( asset.floatPlanId );

          expect( addDelayResult.SUCCESS ).toBeTrue( serializeJSON( addDelayResult ) );
          expect( clearDelayResult.SUCCESS ).toBeTrue( serializeJSON( clearDelayResult ) );
          expect( structKeyExists( clearDelayResult, "MANUAL_DELAY_MINUTES_TOTAL" ) ).toBeTrue( serializeJSON( clearDelayResult ) );
          expect( val( clearDelayResult.MANUAL_DELAY_MINUTES_TOTAL ) ).toBe( 0 );
          expect( delayState.manual_delay_minutes_total ).toBe( 0 );
          expect( monitoringAfter.monitor_state ).toBe( monitoringBefore.monitor_state );
          expect( normalizeDbDateTime( monitoringAfter.expected_checkin_at ) ).toBe( normalizeDbDateTime( monitoringBefore.expected_checkin_at ) );
          expect( normalizeDbDateTime( monitoringAfter.grace_expires_at ) ).toBe( normalizeDbDateTime( monitoringBefore.grace_expires_at ) );
          expect( normalizeDbDateTime( monitoringAfter.next_monitor_eval_at ) ).toBe( normalizeDbDateTime( monitoringBefore.next_monitor_eval_at ) );
        } finally {
          cleanupRouteLinkedAssetsForApi( sessionApi, created );
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
        }
      } );

      it( "rejects invalid minutes and leaves the accumulator unchanged", function() {
        var sessionApi = buildSessionApiSupport();
        var created = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var prefix = variables.naming.buildPrefix( "float-plan-adddelay", "invalid" );
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";
        var asset = {};
        var startMonitoringResult = {};
        var invalidPayloads = [
          { value = "", label = "blank" },
          { value = "abc", label = "nonnumeric" },
          { value = 0, label = "zero" },
          { value = -10, label = "negative" }
        ];
        var invalidResult = {};
        var delayState = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, created );
          setPlanSchedule( asset.floatPlanId, "2026-04-15 09:00:00", "2026-04-16 20:00:00", "US/Eastern" );
          markPlanActive( asset.floatPlanId );
          startMonitoringResult = variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" );
          ensureSuccess( startMonitoringResult, "start active_route monitor" );

          for ( var invalidPayload in invalidPayloads ) {
            invalidResult = postAddDelayWithApi( sessionApi, asset.floatPlanId, invalidPayload.value );
            expect( invalidResult.SUCCESS ?: false ).toBeFalse( serializeJSON( invalidResult ) );
            expect( uCase( trim( toString( invalidResult.ERROR ?: "" ) ) ) ).toBe( "INVALID_MINUTES" );
          }

          delayState = loadDelayState( asset.floatPlanId );
          expect( delayState.manual_delay_minutes_total ).toBe( 0 );
        } finally {
          cleanupRouteLinkedAssetsForApi( sessionApi, created );
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
        }
      } );

      it( "rejects adddelay and cleardelay when no canonical active float plan is available", function() {
        var sessionApi = buildSessionApiSupport();
        var created = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var prefix = variables.naming.buildPrefix( "float-plan-adddelay", "no-active-plan" );
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";
        var asset = {};
        var addDelayResult = {};
        var clearDelayResult = {};
        var delayState = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, created );
          setPlanSchedule( asset.floatPlanId, "2026-04-15 09:00:00", "2026-04-16 20:00:00", "US/Eastern" );

          addDelayResult = postAddDelayWithApi( sessionApi, asset.floatPlanId, 15 );
          clearDelayResult = postClearDelayWithApi( sessionApi, asset.floatPlanId );
          delayState = loadDelayState( asset.floatPlanId );

          expect( addDelayResult.SUCCESS ?: false ).toBeFalse( serializeJSON( addDelayResult ) );
          expect( uCase( trim( toString( addDelayResult.ERROR ?: "" ) ) ) ).toBe( "NO_ACTIVE_PLAN" );
          expect( clearDelayResult.SUCCESS ?: false ).toBeFalse( serializeJSON( clearDelayResult ) );
          expect( uCase( trim( toString( clearDelayResult.ERROR ?: "" ) ) ) ).toBe( "NO_ACTIVE_PLAN" );
          expect( delayState.manual_delay_minutes_total ).toBe( 0 );
        } finally {
          cleanupRouteLinkedAssetsForApi( sessionApi, created );
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
        }
      } );
    } );
  }

  private void function ensureManualDelayColumnExists() {
    var qColumn = loadManualDelayColumn();
    if ( qColumn.recordCount EQ 0 ) {
      queryExecute(
        "ALTER TABLE floatplans ADD COLUMN manual_delay_minutes_total INT NOT NULL DEFAULT 0 AFTER overnight_pause_minutes_total",
        {},
        { datasource = "fpw" }
      );
    }
  }

  private query function loadManualDelayColumn() {
    return queryExecute(
      "SELECT column_name, data_type, is_nullable, column_default
       FROM information_schema.columns
       WHERE table_schema = DATABASE()
         AND table_name = 'floatplans'
         AND column_name = 'manual_delay_minutes_total'
       LIMIT 1",
      {},
      { datasource = "fpw" }
    );
  }

  private struct function buildSessionApiSupport() {
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
    var uniqueEmail = "fpw-adddelay-" & replace( createUUID(), "-", "", "all" ) & "@example.com";
    var payload = signupApi.postJson( "/api/v1/join.cfc?method=handle", {
      firstName = "FPW",
      lastName = "AddDelay",
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
      vesselName = variables.naming.buildName( arguments.prefix, "Delay Vessel" ),
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
      route_name = variables.naming.buildName( arguments.prefix, "Delay Route" ),
      template_code = "GULF-WEST",
      direction = "CCW",
      start_segment_id = options.DATA.startOptions[ 1 ].segment_id,
      end_segment_id = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].segment_id,
      start_location_label = options.DATA.startOptions[ 1 ].label,
      end_location_label = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].label,
      start_date = "2026-04-15",
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

  private void function setPlanSchedule(
    required numeric floatPlanId,
    required string departureLocal,
    required string returnLocal,
    required string timeZoneId
  ) {
    queryExecute(
      "UPDATE floatplans
       SET departureTime = CONVERT_TZ(:departureLocal, :timeZoneId, 'UTC'),
           departTimezone = :timeZoneId,
           departureTZ = :timeZoneId,
           returnTime = CONVERT_TZ(:returnLocal, :timeZoneId, 'UTC'),
           returnTimezone = :timeZoneId,
           returnTZ = :timeZoneId,
           activatedAt = NULL,
           checkedInAt = NULL,
           checkin_context = NULL,
           closedAt = NULL,
           lastUpdateStatus = UTC_TIMESTAMP(),
           `status` = 'DRAFT'
       WHERE floatplanId = :floatPlanId",
      {
        departureLocal = { value = arguments.departureLocal, cfsqltype = "cf_sql_timestamp" },
        returnLocal = { value = arguments.returnLocal, cfsqltype = "cf_sql_timestamp" },
        timeZoneId = { value = arguments.timeZoneId, cfsqltype = "cf_sql_varchar" },
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    deleteMonitoringRows( arguments.floatPlanId );
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

  private struct function loadDelayState( required numeric floatPlanId ) {
    var qRow = queryExecute(
      "SELECT manual_delay_minutes_total
       FROM floatplans
       WHERE floatplanId = :floatPlanId
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    expect( qRow.recordCount ).toBe( 1 );
    return {
      manual_delay_minutes_total = val( qRow.manual_delay_minutes_total[ 1 ] )
    };
  }

  private struct function loadMonitoringRow( required numeric floatPlanId ) {
    var qRow = queryExecute(
      "SELECT monitor_state, is_monitoring_enabled, expected_checkin_at, grace_expires_at, next_monitor_eval_at
       FROM floatplan_monitoring
       WHERE float_plan_id = :floatPlanId
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    expect( qRow.recordCount ).toBe( 1 );
    return {
      monitor_state = trim( toString( qRow.monitor_state[ 1 ] ) ),
      is_monitoring_enabled = val( qRow.is_monitoring_enabled[ 1 ] ) NEQ 0,
      expected_checkin_at = isNull( qRow.expected_checkin_at[ 1 ] ) ? "" : qRow.expected_checkin_at[ 1 ],
      grace_expires_at = isNull( qRow.grace_expires_at[ 1 ] ) ? "" : qRow.grace_expires_at[ 1 ],
      next_monitor_eval_at = isNull( qRow.next_monitor_eval_at[ 1 ] ) ? "" : qRow.next_monitor_eval_at[ 1 ]
    };
  }

  private query function loadDelayEvents( required numeric floatPlanId ) {
    return queryExecute(
      "SELECT vp.title, vp.body
       FROM voyage_posts vp
       INNER JOIN voyage_streams vs ON vs.id = vp.stream_id
       WHERE vs.floatplan_id = :floatPlanId
         AND vp.event_type = 'delay_added'
       ORDER BY vp.created_utc DESC, vp.id DESC",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private string function normalizeDbDateTime( any value ) {
    if ( isDate( arguments.value ) ) {
      return dateTimeFormat( arguments.value, "yyyy-mm-dd HH:nn:ss" );
    }
    return "";
  }

  private void function deleteMonitoringRows( required numeric floatPlanId ) {
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
  }

  private void function forceDeleteFloatPlanRecords( required numeric floatPlanId ) {
    deleteMonitoringRows( arguments.floatPlanId );
    queryExecute(
      "DELETE FROM voyage_posts WHERE stream_id IN (SELECT id FROM voyage_streams WHERE floatplan_id = :floatPlanId)",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM voyage_streams WHERE floatplan_id = :floatPlanId",
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
      throw( message = "AddDelay test setup failed: " & arguments.label, detail = serializeJSON( arguments.payload ) );
    }
  }

  private struct function postAddDelayWithApi( required any apiSupport, required numeric floatPlanId, required any minutesValue ) {
    return arguments.apiSupport.postJson( "/api/v1/floatplan.cfc?method=handle&action=adddelay", {
      floatPlanId = arguments.floatPlanId,
      minutes = arguments.minutesValue
    } );
  }

  private struct function postClearDelayWithApi( required any apiSupport, required numeric floatPlanId ) {
    return arguments.apiSupport.postJson( "/api/v1/floatplan.cfc?method=handle&action=cleardelay", {
      floatPlanId = arguments.floatPlanId
    } );
  }
}
