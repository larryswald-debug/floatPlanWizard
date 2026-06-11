component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    ensureManualDelayColumnExists();
    variables.api = new fpw.tests.support.FpwApiSupport().init(
      authEmail = "detroit@email.com",
      authPassword = "changeIt"
    );
    variables.naming = new fpw.tests.support.FpwNamingSupport();
    variables.voyageService = new fpw.api.v1.voyage();
    variables.sessionApiUser = createSessionApiUser();
  }

  function afterAll() {
    cleanupSessionApiUser();
    structDelete( url, "testUserId", false );
  }

  function run() {
    describe( "Float plan manual delay timing consumers", function() {
      it( "preserves prior timing when manual delay total is zero", function() {
        var sessionApi = buildSessionApiSupport();
        var created = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var prefix = variables.naming.buildPrefix( "float-plan-manual-delay-timing", "zero" );
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";
        var asset = {};
        var heroBefore = {};
        var heroAfter = {};
        var bootstrapBefore = {};
        var bootstrapAfter = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createStartedRouteFixture( sessionApi, prefix, created );

          heroBefore = loadActiveCruiseHero( asset.floatPlanId );
          bootstrapBefore = loadFollowBootstrap( sessionApi, asset.floatPlanId );

          setManualDelayMinutes( asset.floatPlanId, 0 );

          heroAfter = loadActiveCruiseHero( asset.floatPlanId );
          bootstrapAfter = loadFollowBootstrap( sessionApi, asset.floatPlanId );

          assertEtaAvailable( heroBefore.heroEtaUtc, "hero baseline ETA UTC" );
          assertEtaAvailable( bootstrapBefore.topCards.eta_utc ?: "", "follow baseline ETA UTC" );

          expect( heroAfter.heroEtaUtc ).toBe( heroBefore.heroEtaUtc );
          expect( bootstrapAfter.topCards.eta_utc ?: "" ).toBe( bootstrapBefore.topCards.eta_utc ?: "" );
          expect( roundTo2Numeric( bootstrapAfter.timeline.summary.total_hours ?: 0 ) ).toBe(
            roundTo2Numeric( bootstrapBefore.timeline.summary.total_hours ?: 0 )
          );
        } finally {
          cleanupRouteLinkedAssetsForApi( sessionApi, created );
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
        }
      } );

      it( "adds manual delay to active cruise hero and follow timing consumers", function() {
        var sessionApi = buildSessionApiSupport();
        var created = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var prefix = variables.naming.buildPrefix( "float-plan-manual-delay-timing", "additive" );
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";
        var asset = {};
        var addDelayResult = {};
        var heroBefore = {};
        var heroAfter = {};
        var bootstrapBefore = {};
        var bootstrapAfter = {};
        var firstFutureLegBefore = {};
        var firstFutureLegAfter = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createStartedRouteFixture( sessionApi, prefix, created );

          heroBefore = loadActiveCruiseHero( asset.floatPlanId );
          bootstrapBefore = loadFollowBootstrap( sessionApi, asset.floatPlanId );
          firstFutureLegBefore = firstIncompleteLeg( bootstrapBefore.timeline.legs ?: [] );

          addDelayResult = postAddDelayWithApi( sessionApi, asset.floatPlanId, 30 );
          heroAfter = loadActiveCruiseHero( asset.floatPlanId );
          bootstrapAfter = loadFollowBootstrap( sessionApi, asset.floatPlanId );
          firstFutureLegAfter = firstIncompleteLeg( bootstrapAfter.timeline.legs ?: [] );

          expect( addDelayResult.SUCCESS ).toBeTrue( serializeJSON( addDelayResult ) );
          assertEtaAvailable( heroBefore.heroEtaUtc, "hero ETA before adddelay" );
          assertEtaAvailable( heroAfter.heroEtaUtc, "hero ETA after adddelay" );
          assertEtaAvailable( bootstrapBefore.topCards.eta_utc ?: "", "follow ETA before adddelay" );
          assertEtaAvailable( bootstrapAfter.topCards.eta_utc ?: "", "follow ETA after adddelay" );

          expect( diffUtcMinutes( heroBefore.heroEtaUtc, heroAfter.heroEtaUtc ) ).toBe( 30 );
          expect( diffUtcMinutes( bootstrapBefore.topCards.eta_utc ?: "", bootstrapAfter.topCards.eta_utc ?: "" ) ).toBe( 30 );
          expect(
            roundTo2Numeric( val( bootstrapAfter.timeline.summary.total_hours ?: 0 ) - val( bootstrapBefore.timeline.summary.total_hours ?: 0 ) )
          ).toBe( 0.5 );

          expect( firstFutureLegBefore.leg_order ).toBeGT( 0 );
          expect( firstFutureLegAfter.leg_order ).toBe( firstFutureLegBefore.leg_order );
          expect(
            roundTo2Numeric( val( firstFutureLegAfter.cumulative_hours ?: 0 ) - val( firstFutureLegBefore.cumulative_hours ?: 0 ) )
          ).toBe( 0.5 );
          expect( roundTo2Numeric( firstFutureLegAfter.hours ?: 0 ) ).toBe( roundTo2Numeric( firstFutureLegBefore.hours ?: 0 ) );
        } finally {
          cleanupRouteLinkedAssetsForApi( sessionApi, created );
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
        }
      } );

      it( "restores canonical timing when manual delay is cleared back to zero", function() {
        var sessionApi = buildSessionApiSupport();
        var created = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var prefix = variables.naming.buildPrefix( "float-plan-manual-delay-timing", "clear" );
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";
        var asset = {};
        var addDelayResult = {};
        var clearDelayResult = {};
        var heroBefore = {};
        var heroAfterAdd = {};
        var heroAfterClear = {};
        var bootstrapBefore = {};
        var bootstrapAfterAdd = {};
        var bootstrapAfterClear = {};
        var firstFutureLegBefore = {};
        var firstFutureLegAfterAdd = {};
        var firstFutureLegAfterClear = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createStartedRouteFixture( sessionApi, prefix, created );

          heroBefore = loadActiveCruiseHero( asset.floatPlanId );
          bootstrapBefore = loadFollowBootstrap( sessionApi, asset.floatPlanId );
          firstFutureLegBefore = firstIncompleteLeg( bootstrapBefore.timeline.legs ?: [] );

          addDelayResult = postAddDelayWithApi( sessionApi, asset.floatPlanId, 30 );
          heroAfterAdd = loadActiveCruiseHero( asset.floatPlanId );
          bootstrapAfterAdd = loadFollowBootstrap( sessionApi, asset.floatPlanId );
          firstFutureLegAfterAdd = firstIncompleteLeg( bootstrapAfterAdd.timeline.legs ?: [] );

          clearDelayResult = postClearDelayWithApi( sessionApi, asset.floatPlanId );
          heroAfterClear = loadActiveCruiseHero( asset.floatPlanId );
          bootstrapAfterClear = loadFollowBootstrap( sessionApi, asset.floatPlanId );
          firstFutureLegAfterClear = firstIncompleteLeg( bootstrapAfterClear.timeline.legs ?: [] );

          expect( addDelayResult.SUCCESS ).toBeTrue( serializeJSON( addDelayResult ) );
          expect( clearDelayResult.SUCCESS ).toBeTrue( serializeJSON( clearDelayResult ) );
          expect( structKeyExists( clearDelayResult, "MANUAL_DELAY_MINUTES_TOTAL" ) ).toBeTrue( serializeJSON( clearDelayResult ) );
          expect( val( clearDelayResult.MANUAL_DELAY_MINUTES_TOTAL ) ).toBe( 0 );

          assertEtaAvailable( heroBefore.heroEtaUtc, "hero ETA before clear" );
          assertEtaAvailable( heroAfterAdd.heroEtaUtc, "hero ETA after add before clear" );
          assertEtaAvailable( heroAfterClear.heroEtaUtc, "hero ETA after clear" );
          assertEtaAvailable( bootstrapBefore.topCards.eta_utc ?: "", "follow ETA before clear" );
          assertEtaAvailable( bootstrapAfterAdd.topCards.eta_utc ?: "", "follow ETA after add before clear" );
          assertEtaAvailable( bootstrapAfterClear.topCards.eta_utc ?: "", "follow ETA after clear" );

          expect( diffUtcMinutes( heroBefore.heroEtaUtc, heroAfterAdd.heroEtaUtc ) ).toBe( 30 );
          expect( diffUtcMinutes( heroBefore.heroEtaUtc, heroAfterClear.heroEtaUtc ) ).toBe( 0 );
          expect( diffUtcMinutes( bootstrapBefore.topCards.eta_utc ?: "", bootstrapAfterAdd.topCards.eta_utc ?: "" ) ).toBe( 30 );
          expect( diffUtcMinutes( bootstrapBefore.topCards.eta_utc ?: "", bootstrapAfterClear.topCards.eta_utc ?: "" ) ).toBe( 0 );
          expect(
            roundTo2Numeric( val( bootstrapAfterAdd.timeline.summary.total_hours ?: 0 ) - val( bootstrapBefore.timeline.summary.total_hours ?: 0 ) )
          ).toBe( 0.5 );
          expect(
            roundTo2Numeric( val( bootstrapAfterClear.timeline.summary.total_hours ?: 0 ) - val( bootstrapBefore.timeline.summary.total_hours ?: 0 ) )
          ).toBe( 0 );
          expect( firstFutureLegBefore.leg_order ).toBeGT( 0 );
          expect( firstFutureLegAfterAdd.leg_order ).toBe( firstFutureLegBefore.leg_order );
          expect( firstFutureLegAfterClear.leg_order ).toBe( firstFutureLegBefore.leg_order );
          expect(
            roundTo2Numeric( val( firstFutureLegAfterAdd.cumulative_hours ?: 0 ) - val( firstFutureLegBefore.cumulative_hours ?: 0 ) )
          ).toBe( 0.5 );
          expect(
            roundTo2Numeric( val( firstFutureLegAfterClear.cumulative_hours ?: 0 ) - val( firstFutureLegBefore.cumulative_hours ?: 0 ) )
          ).toBe( 0 );
          expect( roundTo2Numeric( firstFutureLegAfterClear.hours ?: 0 ) ).toBe( roundTo2Numeric( firstFutureLegBefore.hours ?: 0 ) );
        } finally {
          cleanupRouteLinkedAssetsForApi( sessionApi, created );
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
        }
      } );

      it( "keeps overnight offset additive when manual delay is added", function() {
        var sessionApi = buildSessionApiSupport();
        var created = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var prefix = variables.naming.buildPrefix( "float-plan-manual-delay-timing", "overnight" );
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";
        var asset = {};
        var addDelayResult = {};
        var heroWithOvernight = {};
        var heroWithBoth = {};
        var bootstrapWithOvernight = {};
        var bootstrapWithBoth = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createStartedRouteFixture( sessionApi, prefix, created );
          setOvernightPauseMinutes( asset.floatPlanId, 120 );

          heroWithOvernight = loadActiveCruiseHero( asset.floatPlanId );
          bootstrapWithOvernight = loadFollowBootstrap( sessionApi, asset.floatPlanId );

          addDelayResult = postAddDelayWithApi( sessionApi, asset.floatPlanId, 30 );

          heroWithBoth = loadActiveCruiseHero( asset.floatPlanId );
          bootstrapWithBoth = loadFollowBootstrap( sessionApi, asset.floatPlanId );

          expect( addDelayResult.SUCCESS ).toBeTrue( serializeJSON( addDelayResult ) );
          assertEtaAvailable( heroWithOvernight.heroEtaUtc, "hero ETA with overnight offset" );
          assertEtaAvailable( heroWithBoth.heroEtaUtc, "hero ETA with overnight + manual delay" );
          assertEtaAvailable( bootstrapWithOvernight.topCards.eta_utc ?: "", "follow ETA with overnight offset" );
          assertEtaAvailable( bootstrapWithBoth.topCards.eta_utc ?: "", "follow ETA with overnight + manual delay" );

          expect( diffUtcMinutes( heroWithOvernight.heroEtaUtc, heroWithBoth.heroEtaUtc ) ).toBe( 30 );
          expect(
            diffUtcMinutes( bootstrapWithOvernight.topCards.eta_utc ?: "", bootstrapWithBoth.topCards.eta_utc ?: "" )
          ).toBe( 30 );
          expect(
            roundTo2Numeric( val( bootstrapWithBoth.timeline.summary.total_hours ?: 0 ) - val( bootstrapWithOvernight.timeline.summary.total_hours ?: 0 ) )
          ).toBe( 0.5 );
        } finally {
          cleanupRouteLinkedAssetsForApi( sessionApi, created );
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
        }
      } );

      it( "updates the dashboard float-plan return time with overnight and manual delay offsets", function() {
        var sessionApi = buildSessionApiSupport();
        var created = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var prefix = variables.naming.buildPrefix( "float-plan-manual-delay-timing", "dashboard" );
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";
        var asset = {};
        var baselineEntry = {};
        var overnightEntry = {};
        var combinedEntry = {};
        var addDelayResult = {};
        var timingState = {};
        var heroBefore = {};
        var bootstrapBefore = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createStartedRouteFixture( sessionApi, prefix, created );

          heroBefore = loadActiveCruiseHero( asset.floatPlanId );
          bootstrapBefore = loadFollowBootstrap( sessionApi, asset.floatPlanId );
          baselineEntry = loadFloatPlanListEntry( sessionApi, asset.floatPlanId );
          setOvernightPauseMinutes( asset.floatPlanId, 120 );
          overnightEntry = loadFloatPlanListEntry( sessionApi, asset.floatPlanId );
          addDelayResult = postAddDelayWithApi( sessionApi, asset.floatPlanId, 30 );
          combinedEntry = loadFloatPlanListEntry( sessionApi, asset.floatPlanId );
          timingState = loadDashboardTimingState( asset.floatPlanId );

          expect( addDelayResult.SUCCESS ).toBeTrue( serializeJSON( addDelayResult ) );
          assertEtaAvailable( heroBefore.heroEtaUtc, "hero ETA before dashboard adddelay" );
          assertEtaAvailable( bootstrapBefore.topCards.eta_utc ?: "", "follow ETA before dashboard adddelay" );
          expect( diffAnyMinutes( timingState.raw_return_time_utc, baselineEntry.return_date_time_utc ) ).toBe( 0 );
          expect( diffAnyMinutes( timingState.raw_return_time_utc, overnightEntry.return_date_time_utc ) ).toBe( 120 );
          expect( diffAnyMinutes( overnightEntry.return_date_time_utc, combinedEntry.return_date_time_utc ) ).toBe( 30 );
          expect( diffAnyMinutes( timingState.raw_return_time_utc, combinedEntry.return_date_time_utc ) ).toBe( 150 );
          expect( uCase( trim( combinedEntry.status ) ) ).toBe( "ACTIVE" );
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
    var uniqueEmail = "fpw-manualdelaytiming-" & replace( createUUID(), "-", "", "all" ) & "@example.com";
    var payload = signupApi.postJson( "/api/v1/join.cfc?method=handle", {
      firstName = "FPW",
      lastName = "DelayTiming",
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

  private struct function createStartedRouteFixture( required any apiSupport, required string prefix, required struct created ) {
    var asset = createRouteLinkedDraftForApi( arguments.apiSupport, arguments.prefix, arguments.created );
    var departureLocal = dateTimeFormat( dateAdd( "d", -1, now() ), "yyyy-mm-dd" ) & " 08:00:00";
    var returnLocal = dateTimeFormat( dateAdd( "d", 1, now() ), "yyyy-mm-dd" ) & " 20:00:00";

    setPlanSchedule( asset.floatPlanId, departureLocal, returnLocal, "US/Eastern" );
    markPlanActive( asset.floatPlanId );
    setManualDelayMinutes( asset.floatPlanId, 0 );
    setOvernightPauseMinutes( asset.floatPlanId, 0 );
    markFirstLegStarted( asset.floatPlanId, variables.sessionApiUser.userId );
    ensureOpenMonitoringRow( asset.floatPlanId, variables.sessionApiUser.userId );

    return asset;
  }

  private struct function createRouteLinkedDraftForApi( required any apiSupport, required string prefix, required struct created ) {
    var vesselPayload = arguments.apiSupport.saveVessel( {
      vesselId = 0,
      vesselName = variables.naming.buildName( arguments.prefix, "Delay Timing Vessel" ),
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
      route_name = variables.naming.buildName( arguments.prefix, "Delay Timing Route" ),
      template_code = "GULF-WEST",
      direction = "CCW",
      start_segment_id = options.DATA.startOptions[ 1 ].segment_id,
      end_segment_id = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].segment_id,
      start_location_label = options.DATA.startOptions[ 1 ].label,
      end_location_label = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].label,
      start_date = dateFormat( now(), "yyyy-mm-dd" ),
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
           overnight_pause_minutes_total = 0,
           manual_delay_minutes_total = 0,
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

  private void function ensureOpenMonitoringRow( required numeric floatPlanId, required numeric ownerUserId ) {
    var qPlan = queryExecute(
      "SELECT floatplanId, returnTime
       FROM floatplans
       WHERE floatplanId = :floatPlanId
         AND userId = :ownerUserId
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        ownerUserId = { value = arguments.ownerUserId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    var expectedCheckInAt = "";

    expect( qPlan.recordCount ).toBe( 1 );

    if ( !isNull( qPlan.returnTime[ 1 ] ) AND isDate( qPlan.returnTime[ 1 ] ) ) {
      expectedCheckInAt = qPlan.returnTime[ 1 ];
    } else {
      expectedCheckInAt = dateAdd( "h", 12, now() );
    }

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
      "INSERT INTO floatplan_monitoring (
          float_plan_id,
          user_id,
          monitoring_mode,
          monitor_state,
          is_monitoring_enabled,
          expected_checkin_at,
          next_monitor_eval_at,
          created_at,
          updated_at
       ) VALUES (
          :floatPlanId,
          :ownerUserId,
          'basic',
          'ACTIVE',
          1,
          :expectedCheckInAt,
          :expectedCheckInAt,
          UTC_TIMESTAMP(),
          UTC_TIMESTAMP()
       )",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        ownerUserId = { value = arguments.ownerUserId, cfsqltype = "cf_sql_integer" },
        expectedCheckInAt = { value = expectedCheckInAt, cfsqltype = "cf_sql_timestamp" }
      },
      { datasource = "fpw" }
    );
  }

  private void function setManualDelayMinutes( required numeric floatPlanId, required numeric minutesTotal ) {
    queryExecute(
      "UPDATE floatplans
       SET manual_delay_minutes_total = :minutesTotal
       WHERE floatplanId = :floatPlanId",
      {
        minutesTotal = { value = arguments.minutesTotal, cfsqltype = "cf_sql_integer" },
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function setOvernightPauseMinutes( required numeric floatPlanId, required numeric minutesTotal ) {
    queryExecute(
      "UPDATE floatplans
       SET overnight_pause_minutes_total = :minutesTotal
       WHERE floatplanId = :floatPlanId",
      {
        minutesTotal = { value = arguments.minutesTotal, cfsqltype = "cf_sql_integer" },
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function markFirstLegStarted( required numeric floatPlanId, required numeric ownerUserId ) {
    var routeInfo = loadRouteIdentity( arguments.floatPlanId );
    var qLegs = queryExecute(
      "SELECT leg_order
       FROM route_instance_leg_progress
       WHERE route_instance_id = :routeInstanceId
         AND user_id = :ownerUserId
       ORDER BY leg_order ASC, id ASC",
      {
        routeInstanceId = { value = routeInfo.route_instance_id, cfsqltype = "cf_sql_integer" },
        ownerUserId = { value = arguments.ownerUserId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );

    expect( qLegs.recordCount ).toBeGT( 0 );

    queryExecute(
      "UPDATE route_instance_leg_progress
       SET status = CASE WHEN leg_order = :firstLegOrder THEN 'STARTED' ELSE '' END,
           leg_started_at = CASE WHEN leg_order = :firstLegOrder THEN DATE_SUB(UTC_TIMESTAMP(), INTERVAL 45 MINUTE) ELSE NULL END,
           completed_at = NULL,
           updated_at = UTC_TIMESTAMP()
       WHERE route_instance_id = :routeInstanceId
         AND user_id = :ownerUserId",
      {
        firstLegOrder = { value = val( qLegs.leg_order[ 1 ] ), cfsqltype = "cf_sql_integer" },
        routeInstanceId = { value = routeInfo.route_instance_id, cfsqltype = "cf_sql_integer" },
        ownerUserId = { value = arguments.ownerUserId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private struct function loadRouteIdentity( required numeric floatPlanId ) {
    var qPlan = queryExecute(
      "SELECT floatplanId, route_instance_id, userId
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
      floatPlanId = val( qPlan.floatplanId[ 1 ] ),
      route_instance_id = val( qPlan.route_instance_id[ 1 ] ),
      userId = val( qPlan.userId[ 1 ] )
    };
  }

  private struct function loadActiveCruiseHero( required numeric floatPlanId ) {
    var payload = variables.voyageService.getActiveCruiseHeroCanonical( variables.sessionApiUser.userId, arguments.floatPlanId );
    expect( payload.SUCCESS ?: false ).toBeTrue( serializeJSON( payload ) );
    return payload;
  }

  private struct function loadFollowBootstrap( required any apiSupport, required numeric floatPlanId ) {
    var ensureStream = arguments.apiSupport.postJson( "/api/v1/voyage.cfc?method=handle&action=ownerensurestream", {} );
    var qStream = queryExecute(
      "SELECT id
       FROM voyage_streams
       WHERE floatplan_id = :floatPlanId
         AND owner_user_id = :ownerUserId
       ORDER BY id DESC
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        ownerUserId = { value = variables.sessionApiUser.userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    var streamId = 0;
    var payload = {};

    expect( ensureStream.SUCCESS ?: false ).toBeTrue( serializeJSON( ensureStream ) );
    expect( qStream.recordCount ).toBe( 1 );

    streamId = val( qStream.id[ 1 ] );
    payload = arguments.apiSupport.getJson(
      "/api/v1/voyage.cfc?method=handle&action=getStreamBootstrap&stream_id=" & streamId
    );
    expect( payload.SUCCESS ?: false ).toBeTrue( serializeJSON( payload ) );
    return payload;
  }

  private struct function firstIncompleteLeg( required array legs ) {
    var leg = {};
    for ( leg in arguments.legs ) {
      if ( !isStruct( leg ) ) {
        continue;
      }
      if ( !structKeyExists( leg, "progress" ) || !isStruct( leg.progress ) ) {
        return leg;
      }
      if ( val( leg.progress.percent_complete ?: 0 ) LT 100 ) {
        return leg;
      }
    }
    return {};
  }

  private struct function loadFloatPlanListEntry( required any apiSupport, required numeric floatPlanId ) {
    var payload = arguments.apiSupport.listFloatPlans( 100 );
    var plans = [];
    var plan = {};
    var i = 0;

    expect( payload.SUCCESS ?: false ).toBeTrue( serializeJSON( payload ) );
    plans = isArray( payload.PLANS ?: "" ) ? payload.PLANS : [];

    for ( i = 1; i LTE arrayLen( plans ); i++ ) {
      plan = isStruct( plans[ i ] ) ? plans[ i ] : {};
      if ( val( plan.FLOATPLANID ?: 0 ) EQ arguments.floatPlanId ) {
        return {
          floatPlanId = val( plan.FLOATPLANID ?: 0 ),
          status = trim( toString( plan.STATUS ?: "" ) ),
          return_date_time_utc = plan.RETURNDATETIME ?: ""
        };
      }
    }

    throw( message = "Float plan was not returned by the dashboard list API.", detail = "floatPlanId=" & arguments.floatPlanId );
  }

  private struct function loadDashboardTimingState( required numeric floatPlanId ) {
    var qRow = queryExecute(
      "SELECT returnTime, overnight_pause_minutes_total, manual_delay_minutes_total, status
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
      raw_return_time_utc = isNull( qRow.returnTime[ 1 ] ) ? "" : qRow.returnTime[ 1 ],
      overnight_pause_minutes_total = val( qRow.overnight_pause_minutes_total[ 1 ] ),
      manual_delay_minutes_total = val( qRow.manual_delay_minutes_total[ 1 ] ),
      status = trim( toString( qRow.status[ 1 ] ) )
    };
  }

  private numeric function diffUtcMinutes( required string beforeValue, required string afterValue ) {
    var beforeDt = parseUtcString( arguments.beforeValue );
    var afterDt = parseUtcString( arguments.afterValue );
    expect( isDate( beforeDt ) ).toBeTrue( arguments.beforeValue );
    expect( isDate( afterDt ) ).toBeTrue( arguments.afterValue );
    return dateDiff( "n", beforeDt, afterDt );
  }

  private any function parseUtcString( required string value ) {
    var raw = trim( arguments.value );
    if ( !len( raw ) ) {
      return "";
    }
    raw = replace( raw, "T", " ", "all" );
    raw = reReplace( raw, "Z$", "", "all" );
    try {
      return parseDateTime( raw );
    } catch ( any parseErr ) {
      return "";
    }
  }

  private numeric function diffAnyMinutes( required any beforeValue, required any afterValue ) {
    var beforeDt = parseAnyDate( arguments.beforeValue );
    var afterDt = parseAnyDate( arguments.afterValue );
    expect( isDate( beforeDt ) ).toBeTrue( serializeJSON( arguments.beforeValue ) );
    expect( isDate( afterDt ) ).toBeTrue( serializeJSON( arguments.afterValue ) );
    return dateDiff( "n", beforeDt, afterDt );
  }

  private any function parseAnyDate( required any value ) {
    var raw = "";
    if ( isDate( arguments.value ) ) {
      return arguments.value;
    }
    raw = trim( toString( arguments.value ) );
    if ( !len( raw ) ) {
      return "";
    }
    raw = replace( raw, "T", " ", "all" );
    raw = reReplace( raw, "Z$", "", "all" );
    try {
      return parseDateTime( raw );
    } catch ( any parseErr ) {
      return "";
    }
  }

  private numeric function roundTo2Numeric( required any value ) {
    var n = ( isNumeric( arguments.value ) ? val( arguments.value ) : 0 );
    return int( n * 100 + 0.5 ) / 100;
  }

  private void function assertEtaAvailable( required string value, required string label ) {
    expect( len( trim( arguments.value ) ) ).toBeGT( 0, arguments.label );
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
      throw( message = "FloatPlanManualDelayTimingSpec setup failed: " & arguments.label, detail = serializeJSON( arguments.payload ) );
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
