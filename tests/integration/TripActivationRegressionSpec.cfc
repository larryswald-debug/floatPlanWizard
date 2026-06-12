component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.api = new fpw.tests.support.FpwApiSupport().init(
      authEmail = "detroit@email.com",
      authPassword = "changeIt"
    );
    variables.naming = new fpw.tests.support.FpwNamingSupport();
    variables.monitorService = new fpw.api.v1.monitor().init();
    variables.viewModelService = new fpw.api.v1.ActiveCruiseViewModelService().init("fpw");
    variables.entitlements = new fpw.api.v1.MemberEntitlementService().init("fpw");
    variables.hadOriginalTestUserId = structKeyExists( url, "testUserId" );
    variables.originalTestUserId = variables.hadOriginalTestUserId ? url.testUserId : "";
    variables.sessionApiUser = createSessionApiUser();
    url.testUserId = variables.sessionApiUser.userId;
    variables.entitlements.createAdminCompEntitlement(variables.sessionApiUser.userId);
  }

  function afterAll() {
    cleanupSessionApiUser();
    if ( variables.hadOriginalTestUserId ) {
      url.testUserId = variables.originalTestUserId;
    } else {
      structDelete( url, "testUserId", false );
    }
  }

  function run() {
    describe( "Trip activation regression contract", function() {
      it( "route-backed send activation defers monitoring until explicit start", function() {
        var prefix = variables.naming.buildPrefix( "trip-activation-regression", "send-scheduled" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var sendResult = {};
        var planState = {};
        var progressCounts = {};
        var secondStartResult = {};
        var futureDeparture = dateTimeFormat( dateAdd( "h", 3, now() ), "yyyy-mm-dd HH:nn:ss" );
        var futureReturn = dateTimeFormat( dateAdd( "h", 9, now() ), "yyyy-mm-dd HH:nn:ss" );

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          attachContactToPlan( sessionApi, asset.floatPlanId, prefix, localCreated );
          setPlanSchedule( asset.floatPlanId, futureDeparture, futureReturn, "UTC" );

          sendResult = sendFloatPlanWithApi( sessionApi, asset.floatPlanId );
          planState = loadPlanState( asset.floatPlanId );
          progressCounts = loadRouteProgressCounts( asset.floatPlanId );
          secondStartResult = variables.monitorService.startScheduledRouteMonitoringForFloatPlan( asset.floatPlanId );

          expect( isSuccessPayload( sendResult ) ).toBeTrue( serializeJSON( sendResult ) );
          expect( planState.status ).toBe( "ACTIVE" );
          expect( planState.route_instance_id ).toBeGT( 0 );
          expect( listFindNoCase( "PLANNED,SCHEDULED", planState.route_status ) ).toBeGT( 0, serializeJSON( planState ) );
          expect( progressCounts.route_leg_count ).toBeGT( 0 );
          expect( progressCounts.progress_row_count ).toBe( progressCounts.route_leg_count );
          expect( progressCounts.not_started_rows ).toBe( progressCounts.progress_row_count );
          expect( progressCounts.started_rows ).toBe( 0 );
          expect( countMonitoringRows( asset.floatPlanId ) ).toBe( 0 );
          expect( isSuccessPayload( secondStartResult ) ).toBeTrue( serializeJSON( secondStartResult ) );
          expect( secondStartResult.DEFERRED ?: false ).toBeTrue( serializeJSON( secondStartResult ) );
          expect( countMonitoringRows( asset.floatPlanId ) ).toBe( 0 );
        } finally {
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "route-generated save stores submitted UTC schedule anchors", function() {
        var prefix = variables.naming.buildPrefix( "trip-activation-regression", "submitted-utc-authority" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var bootstrap = {};
        var saveResult = {};
        var schedule = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          bootstrap = sessionApi.bootstrapFloatPlan( asset.floatPlanId );

          saveResult = sessionApi.saveFloatPlan( {
            FLOATPLANID = asset.floatPlanId,
            floatPlanId = asset.floatPlanId,
            ROUTE_INSTANCE_ID = val( bootstrap.FLOATPLAN.ROUTE_INSTANCE_ID ?: 0 ),
            routeInstanceId = val( bootstrap.FLOATPLAN.ROUTE_INSTANCE_ID ?: 0 ),
            ROUTE_DAY_NUMBER = val( bootstrap.FLOATPLAN.ROUTE_DAY_NUMBER ?: 0 ),
            routeDayNumber = val( bootstrap.FLOATPLAN.ROUTE_DAY_NUMBER ?: 0 ),
            NAME = variables.naming.buildName( prefix, "Submitted UTC Authority Plan" ),
            NOTES = trim( toString( bootstrap.FLOATPLAN.NOTES ?: "" ) ),
            VESSELID = asset.vesselId,
            OPERATORID = val( bootstrap.FLOATPLAN.OPERATORID ?: 0 ),
            DEPARTING_FROM = "Mobile",
            DEPARTURE_TIME = "2026-05-21 12:00:00",
            DEPARTURE_TIMEZONE = "US/Eastern",
            DEPARTURE_TIME_UTC = "2026-05-21 16:00:00",
            RETURNING_TO = "Pensacola",
            RETURN_TIME = "2026-05-21 17:00:00",
            RETURN_TIMEZONE = "US/Eastern",
            RETURN_TIME_UTC = "2026-05-21 21:00:00",
            EMAIL = "submitted-utc-authority@example.com",
            RESCUE_AUTHORITY = "USCG",
            RESCUE_AUTHORITY_PHONE = "5555551212"
          } );

          expect( isSuccessPayload( saveResult ) ).toBeTrue( serializeJSON( saveResult ) );
          schedule = loadPlanScheduleValues( asset.floatPlanId );

          expect( schedule.departure_time_local ).toBe( "2026-05-21 12:00:00", serializeJSON( schedule ) );
          expect( schedule.departure_tz ).toBe( "US/Eastern", serializeJSON( schedule ) );
          expect( schedule.departure_time_utc ).toBe( "2026-05-21 16:00:00", serializeJSON( schedule ) );
          expect( schedule.return_time_local ).toBe( "2026-05-21 17:00:00", serializeJSON( schedule ) );
          expect( schedule.return_tz ).toBe( "US/Eastern", serializeJSON( schedule ) );
          expect( schedule.return_time_utc ).toBe( "2026-05-21 21:00:00", serializeJSON( schedule ) );
          expect( findNoCase( "Auto-generated from route", schedule.notes ) ).toBeGT( 0, serializeJSON( schedule ) );
          expect( findNoCase( "SINGLE_MASTER", schedule.notes ) ).toBeGT( 0, serializeJSON( schedule ) );
        } finally {
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "route-backed send creates a fresh route instance when a reusable route has operational history", function() {
        var prefix = variables.naming.buildPrefix( "trip-activation-regression", "reactivation-clean-instance" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var firstPlanState = {};
        var checkinResult = {};
        var completeResult = {};
        var firstProgressAfterComplete = {};
        var cancelResult = {};
        var buildPayload = {};
        var secondFloatPlanId = 0;
        var secondDraftState = {};
        var oldBehaviorResult = {};
        var oldBehaviorPlanState = {};
        var oldBehaviorMonitoringRows = 0;
        var sendResult = {};
        var secondPlanState = {};
        var oldRouteProgressAfterSend = {};
        var newRouteProgressAfterSend = {};
        var activeCruiseModel = {};
        var routesPayload = {};
        var projectedSourceRoute = {};
        var freshRouteInputs = {};
        var futureDeparture = dateTimeFormat( dateAdd( "h", 3, now() ), "yyyy-mm-dd HH:nn:ss" );
        var futureReturn = dateTimeFormat( dateAdd( "h", 9, now() ), "yyyy-mm-dd HH:nn:ss" );

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip( sessionApi, prefix, futureDeparture, futureReturn, localCreated );
          firstPlanState = loadPlanState( asset.floatPlanId );

          checkinResult = postActiveCruiseCheckinWithApi( sessionApi, asset.floatPlanId, "On Track" );
          completeResult = postCompleteLegWithApi( sessionApi, asset.floatPlanId, 1 );
          firstProgressAfterComplete = loadRouteProgressCounts( asset.floatPlanId );
          cancelResult = cancelFloatPlanWithApi( sessionApi, asset.floatPlanId );

          buildPayload = sessionApi.routeBuilder( "buildFloatPlansFromRoute", {
            routeCode = asset.routeCode,
            mode = "DAILY",
            vesselId = asset.vesselId,
            rebuild = 0
          } );
          ensureSuccess( buildPayload, "rebuild route-linked draft from reusable route" );
          secondFloatPlanId = val( buildPayload.FLOATPLAN_IDS[ 1 ] ?: 0 );
          expect( secondFloatPlanId ).toBeGT( 0, serializeJSON( buildPayload ) );
          arrayAppend( localCreated.floatPlanIds, secondFloatPlanId );
          attachContactToPlan( sessionApi, secondFloatPlanId, prefix, localCreated );
          setPlanSchedule( secondFloatPlanId, futureDeparture, futureReturn, "UTC" );
          secondDraftState = loadPlanState( secondFloatPlanId );

          markPlanActive( secondFloatPlanId );
          oldBehaviorResult = variables.monitorService.startScheduledRouteMonitoringForFloatPlan( secondFloatPlanId );
          oldBehaviorPlanState = loadPlanState( secondFloatPlanId );
          oldBehaviorMonitoringRows = countMonitoringRows( secondFloatPlanId );
          setPlanSchedule( secondFloatPlanId, futureDeparture, futureReturn, "UTC" );

          sendResult = sendFloatPlanWithApi( sessionApi, secondFloatPlanId );
          secondPlanState = loadPlanState( secondFloatPlanId );
          appendRouteCodeIfMissing( localCreated, loadRouteCodeForFloatPlan( secondFloatPlanId ) );
          oldRouteProgressAfterSend = loadRouteProgressCountsByRouteInstance( variables.sessionApiUser.userId, firstPlanState.route_instance_id );
          newRouteProgressAfterSend = loadRouteProgressCounts( secondFloatPlanId );
          freshRouteInputs = loadRouteInputs( secondPlanState.route_instance_id );
          activeCruiseModel = variables.viewModelService.getActiveCruiseViewModel( variables.sessionApiUser.userId, secondFloatPlanId );
          routesPayload = sessionApi.routeBuilder( "listUserRoutes" );
          ensureSuccess( routesPayload, "list dashboard routes after fresh operational activation" );
          for ( var routeRow in routesPayload.ROUTES ) {
            if ( compareNoCase( trim( toString( routeRow.SHORT_CODE ?: "" ) ), asset.routeCode ) EQ 0 ) {
              projectedSourceRoute = routeRow;
              break;
            }
          }

          expect( isSuccessPayload( checkinResult ) ).toBeTrue( serializeJSON( checkinResult ) );
          expect( isSuccessPayload( completeResult ) ).toBeTrue( serializeJSON( completeResult ) );
          expect( firstProgressAfterComplete.completed_rows ).toBe( 1, serializeJSON( firstProgressAfterComplete ) );
          expect( isSuccessPayload( cancelResult ) ).toBeTrue( serializeJSON( cancelResult ) );
          expect( secondDraftState.status ).toBe( "DRAFT", serializeJSON( secondDraftState ) );
          expect( secondDraftState.route_instance_id ).toBe( firstPlanState.route_instance_id, serializeJSON( secondDraftState ) );
          expect( isSuccessPayload( oldBehaviorResult ) ).toBeTrue( serializeJSON( oldBehaviorResult ) );
          expect( oldBehaviorResult.DEFERRED ?: false ).toBeTrue( serializeJSON( oldBehaviorResult ) );
          expect( oldBehaviorPlanState.status ).toBe( "ACTIVE", serializeJSON( oldBehaviorPlanState ) );
          expect( oldBehaviorMonitoringRows ).toBe( 0 );

          expect( isSuccessPayload( sendResult ) ).toBeTrue( serializeJSON( sendResult ) );
          expect( secondPlanState.status ).toBe( "ACTIVE", serializeJSON( secondPlanState ) );
          expect( secondPlanState.route_instance_id ).toBeGT( 0 );
          expect( secondPlanState.route_instance_id ).notToBe( firstPlanState.route_instance_id, serializeJSON( secondPlanState ) );
          expect( oldRouteProgressAfterSend.completed_rows ).toBe( 1, serializeJSON( oldRouteProgressAfterSend ) );
          expect( oldRouteProgressAfterSend.started_rows ).toBe( 1, serializeJSON( oldRouteProgressAfterSend ) );
          expect( newRouteProgressAfterSend.route_leg_count ).toBe( oldRouteProgressAfterSend.route_leg_count, serializeJSON( newRouteProgressAfterSend ) );
          expect( newRouteProgressAfterSend.progress_row_count ).toBe( newRouteProgressAfterSend.route_leg_count, serializeJSON( newRouteProgressAfterSend ) );
          expect( newRouteProgressAfterSend.not_started_rows ).toBe( newRouteProgressAfterSend.progress_row_count, serializeJSON( newRouteProgressAfterSend ) );
          expect( newRouteProgressAfterSend.started_rows ).toBe( 0, serializeJSON( newRouteProgressAfterSend ) );
          expect( newRouteProgressAfterSend.completed_rows ).toBe( 0, serializeJSON( newRouteProgressAfterSend ) );
          expect( freshRouteInputs.source_route_instance_id ?: 0 ).toBe( firstPlanState.route_instance_id, serializeJSON( freshRouteInputs ) );
          expect( freshRouteInputs.source_route_code ?: "" ).toBe( asset.routeCode, serializeJSON( freshRouteInputs ) );
          expect( structKeyExists( freshRouteInputs, "ACTIVE_TRIP_FLOATPLAN_ID" ) ).toBeFalse( serializeJSON( freshRouteInputs ) );
          expect( structKeyExists( freshRouteInputs, "ACTIVE_TRIP_UPDATED_AT_UTC" ) ).toBeFalse( serializeJSON( freshRouteInputs ) );
          expect( countMonitoringRows( secondFloatPlanId ) ).toBe( 0 );
          expect( activeCruiseModel.success ).toBeTrue( serializeJSON( activeCruiseModel ) );
          expect( activeCruiseModel.displayAuthority.monitoring ).toBe( "scheduled_not_started", serializeJSON( activeCruiseModel.displayAuthority ) );
          expect( structCount( projectedSourceRoute ) ).toBeGT( 0, serializeJSON( routesPayload ) );
          expect( val( projectedSourceRoute.ROUTE_INSTANCE_ID ?: 0 ) ).toBe( firstPlanState.route_instance_id, serializeJSON( projectedSourceRoute ) );
          expect( projectedSourceRoute.HAS_CURRENT_GROUP ?: false ).toBeTrue( serializeJSON( projectedSourceRoute ) );
          expect( trim( toString( projectedSourceRoute.CURRENT_GROUP.CURRENT_STATE ?: "" ) ) ).toBe( "ACTIVE", serializeJSON( projectedSourceRoute ) );
          expect( val( projectedSourceRoute.CURRENT_GROUP.ROUTE_INSTANCE_ID ?: 0 ) ).toBe( secondPlanState.route_instance_id, serializeJSON( projectedSourceRoute ) );
        } finally {
          if ( secondFloatPlanId GT 0 ) {
            try {
              appendRouteCodeIfMissing( localCreated, loadRouteCodeForFloatPlan( secondFloatPlanId ) );
            } catch ( any ignoredFreshRouteTrack ) {}
          }
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "route-backed send compares canonical UTC return time when display-local return is before UTC now", function() {
        var prefix = variables.naming.buildPrefix( "trip-activation-regression", "utc-return-display-local" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var bootstrap = {};
        var sendResult = {};
        var planState = {};
        var probe = queryNew( "" );

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          attachContactToPlan( sessionApi, asset.floatPlanId, prefix, localCreated );
          setPlanScheduleStoredUtcWithDisplayZone( asset.floatPlanId, -1, 3, "US/Eastern" );

          bootstrap = sessionApi.bootstrapFloatPlan( asset.floatPlanId );
          probe = queryExecute(
            "SELECT returnTime, returnTimeUTC, returnTimezone, returnTZ, UTC_TIMESTAMP() AS utcNow
             FROM floatplans
             WHERE floatplanId = :floatPlanId",
            {
              floatPlanId = { value = asset.floatPlanId, cfsqltype = "cf_sql_integer" }
            },
            { datasource = "fpw" }
          );
          sendResult = sendFloatPlanWithApi( sessionApi, asset.floatPlanId );
          planState = loadPlanState( asset.floatPlanId );

          expect( probe.recordCount ).toBe( 1 );
          expect( trim( toString( probe.returnTimezone[ 1 ] ) ) ).toBe( "UTC" );
          expect( trim( toString( probe.returnTZ[ 1 ] ) ) ).toBe( "US/Eastern" );
          expect( dateCompare( probe.returnTime[ 1 ], probe.utcNow[ 1 ], "s" ) ).toBeLT( 0, serializeJSON( probe ) );
          expect( dateCompare( probe.returnTimeUTC[ 1 ], probe.utcNow[ 1 ], "s" ) ).toBeGT( 0, serializeJSON( probe ) );
          expect( bootstrap.FLOATPLAN.RETURN_TIMEZONE ).toBe( "US/Eastern", serializeJSON( bootstrap ) );
          expect( dateCompare( bootstrap.FLOATPLAN.RETURN_TIME, probe.utcNow[ 1 ], "s" ) ).toBeLT( 0, serializeJSON( bootstrap.FLOATPLAN ) );
          expect( isSuccessPayload( sendResult ) ).toBeTrue( serializeJSON( sendResult ) );
          expect( planState.status ).toBe( "ACTIVE" );
          expect( countMonitoringRows( asset.floatPlanId ) ).toBe( 0 );
        } finally {
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "route-backed send rejects truly past canonical UTC return time", function() {
        var prefix = variables.naming.buildPrefix( "trip-activation-regression", "past-utc-return" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var sendResult = {};
        var planState = {};
        var probe = queryNew( "" );

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          attachContactToPlan( sessionApi, asset.floatPlanId, prefix, localCreated );
          setPlanScheduleStoredUtcWithDisplayZone( asset.floatPlanId, -6, -1, "US/Eastern" );

          probe = queryExecute(
            "SELECT returnTime, returnTimezone, returnTZ, UTC_TIMESTAMP() AS utcNow
             FROM floatplans
             WHERE floatplanId = :floatPlanId",
            {
              floatPlanId = { value = asset.floatPlanId, cfsqltype = "cf_sql_integer" }
            },
            { datasource = "fpw" }
          );
          sendResult = sendFloatPlanWithApi( sessionApi, asset.floatPlanId );
          planState = loadPlanState( asset.floatPlanId );

          expect( probe.recordCount ).toBe( 1 );
          expect( trim( toString( probe.returnTimezone[ 1 ] ) ) ).toBe( "UTC" );
          expect( dateCompare( probe.returnTime[ 1 ], probe.utcNow[ 1 ], "s" ) ).toBeLT( 0, serializeJSON( sendResult ) );
          expect( isSuccessPayload( sendResult ) ).toBeFalse( serializeJSON( sendResult ) );
          expect( pickString( sendResult, [ "ERROR", "error" ] ) ).toBe( "RETURN_TIME_PAST", serializeJSON( sendResult ) );
          expect( planState.status ).toBe( "DRAFT" );
          expect( countMonitoringRows( asset.floatPlanId ) ).toBe( 0 );
        } finally {
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "scheduled activation does not auto-start route progress when departure is due", function() {
        var prefix = variables.naming.buildPrefix( "trip-activation-regression", "due-no-autostart" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var sendResult = {};
        var progressCounts = {};
        var pastDeparture = dateTimeFormat( dateAdd( "h", -2, now() ), "yyyy-mm-dd HH:nn:ss" );
        var futureReturn = dateTimeFormat( dateAdd( "h", 8, now() ), "yyyy-mm-dd HH:nn:ss" );

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          attachContactToPlan( sessionApi, asset.floatPlanId, prefix, localCreated );
          setPlanSchedule( asset.floatPlanId, pastDeparture, futureReturn, "UTC" );

          sendResult = sendFloatPlanWithApi( sessionApi, asset.floatPlanId );
          progressCounts = loadRouteProgressCounts( asset.floatPlanId );

          expect( isSuccessPayload( sendResult ) ).toBeTrue( serializeJSON( sendResult ) );
          expect( progressCounts.progress_row_count ).toBe( progressCounts.route_leg_count );
          expect( progressCounts.not_started_rows ).toBe( progressCounts.progress_row_count );
          expect( progressCounts.started_rows ).toBe( 0 );
          expect( progressCounts.completed_rows ).toBe( 0 );
          expect( countMonitoringRows( asset.floatPlanId ) ).toBe( 0 );
        } finally {
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "pre-departure On Track starts operational route progress explicitly", function() {
        var prefix = variables.naming.buildPrefix( "trip-activation-regression", "ontrack-starts" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var checkinResult = {};
        var progressCountsBefore = {};
        var progressCountsAfter = {};
        var planStateBefore = {};
        var planStateAfter = {};
        var secondCheckinResult = {};
        var planStateSecond = {};
        var firstLeg = {};
        var futureLegCounts = {};
        var monitoringRow = {};
        var futureDeparture = dateTimeFormat( dateAdd( "h", 3, now() ), "yyyy-mm-dd HH:nn:ss" );
        var futureReturn = dateTimeFormat( dateAdd( "h", 9, now() ), "yyyy-mm-dd HH:nn:ss" );

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip( sessionApi, prefix, futureDeparture, futureReturn, localCreated );
          progressCountsBefore = loadRouteProgressCounts( asset.floatPlanId );
          planStateBefore = loadPlanState( asset.floatPlanId );

          checkinResult = postActiveCruiseCheckinWithApi( sessionApi, asset.floatPlanId, "On Track" );
          progressCountsAfter = loadRouteProgressCounts( asset.floatPlanId );
          firstLeg = loadLegProgress( asset.floatPlanId, 1 );
          futureLegCounts = loadFutureLegProgressCounts( asset.floatPlanId, 1 );
          monitoringRow = loadMonitoringRow( asset.floatPlanId );
          planStateAfter = loadPlanState( asset.floatPlanId );
          secondCheckinResult = postActiveCruiseCheckinWithApi( sessionApi, asset.floatPlanId, "On Track" );
          planStateSecond = loadPlanState( asset.floatPlanId );

          expect( progressCountsBefore.started_rows ).toBe( 0 );
          expect( progressCountsBefore.completed_rows ).toBe( 0 );
          expect( listFindNoCase( "PLANNED,SCHEDULED", planStateBefore.route_status ) ).toBeGT( 0, serializeJSON( planStateBefore ) );
          expect( isDate( planStateBefore.route_started_at ) ).toBeFalse( serializeJSON( planStateBefore ) );
          expect( isSuccessPayload( checkinResult ) ).toBeTrue( serializeJSON( checkinResult ) );
          expect( progressCountsAfter.started_rows ).toBe( 1, serializeJSON( checkinResult ) );
          expect( progressCountsAfter.completed_rows ).toBe( 0, serializeJSON( checkinResult ) );
          expect( firstLeg.status ).toBe( "STARTED", serializeJSON( firstLeg ) );
          expect( isDate( firstLeg.leg_started_at ) ).toBeTrue( serializeJSON( firstLeg ) );
          expect( planStateAfter.route_status ).toBe( "ACTIVE", serializeJSON( planStateAfter ) );
          expect( isDate( planStateAfter.route_started_at ) ).toBeTrue( serializeJSON( planStateAfter ) );
          expect( normalizeDbDateTime( planStateAfter.route_started_at ) ).toBe( normalizeDbDateTime( firstLeg.leg_started_at ) );
          expect( futureLegCounts.future_rows ).toBe( progressCountsAfter.progress_row_count - 1, serializeJSON( futureLegCounts ) );
          expect( futureLegCounts.not_started_rows ).toBe( futureLegCounts.future_rows, serializeJSON( futureLegCounts ) );
          expect( futureLegCounts.started_rows ).toBe( 0, serializeJSON( futureLegCounts ) );
          expect( futureLegCounts.started_status_rows ).toBe( 0, serializeJSON( futureLegCounts ) );
          expect( futureLegCounts.completed_rows ).toBe( 0, serializeJSON( futureLegCounts ) );
          expect( monitoringRow.last_checkin_status ).toBe( "ON_TRACK" );
          expect( pickString( checkinResult, [ "MESSAGE", "message" ] ) ).notToBe( "Float plan API error." );
          expect( isSuccessPayload( secondCheckinResult ) ).toBeTrue( serializeJSON( secondCheckinResult ) );
          expect( planStateSecond.route_status ).toBe( "ACTIVE", serializeJSON( planStateSecond ) );
          expect( normalizeDbDateTime( planStateSecond.route_started_at ) ).toBe( normalizeDbDateTime( planStateAfter.route_started_at ) );
        } finally {
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "pre-departure unsupported statuses return controlled errors without starting route progress", function() {
        var prefix = variables.naming.buildPrefix( "trip-activation-regression", "unsupported-statuses" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var futureDeparture = dateTimeFormat( dateAdd( "h", 3, now() ), "yyyy-mm-dd HH:nn:ss" );
        var futureReturn = dateTimeFormat( dateAdd( "h", 9, now() ), "yyyy-mm-dd HH:nn:ss" );
        var statusCases = [
          { status = "Delayed", error = "PRE_DEPARTURE_DELAY_REQUIRES_NEW_TIME" },
          { status = "Changed Plan", error = "PRE_DEPARTURE_PLAN_CHANGE_REQUIRES_UPDATE" },
          { status = "Secure for the Night", error = "PRE_DEPARTURE_SECURE_NOT_ALLOWED" }
        ];
        var statusCase = {};
        var checkinResult = {};
        var progressCounts = {};
        var planState = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip( sessionApi, prefix, futureDeparture, futureReturn, localCreated );

          for ( statusCase in statusCases ) {
            checkinResult = postActiveCruiseCheckinWithApi( sessionApi, asset.floatPlanId, statusCase.status );
            progressCounts = loadRouteProgressCounts( asset.floatPlanId );
            planState = loadPlanState( asset.floatPlanId );

            expect( isSuccessPayload( checkinResult ) ).toBeFalse( serializeJSON( checkinResult ) );
            expect( pickString( checkinResult, [ "ERROR", "error" ] ) ).toBe( statusCase.error, serializeJSON( checkinResult ) );
            expect( pickString( checkinResult, [ "MESSAGE", "message" ] ) ).notToBe( "Float plan API error." );
            expect( progressCounts.started_rows ).toBe( 0, serializeJSON( checkinResult ) );
            expect( progressCounts.completed_rows ).toBe( 0, serializeJSON( checkinResult ) );
            expect( listFindNoCase( "PLANNED,SCHEDULED", planState.route_status ) ).toBeGT( 0, serializeJSON( planState ) );
            expect( isDate( planState.route_started_at ) ).toBeFalse( serializeJSON( planState ) );
          }
        } finally {
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "pre-departure Assistance Needed returns a controlled start-required error", function() {
        var prefix = variables.naming.buildPrefix( "trip-activation-regression", "assistance-no-start" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var checkinResult = {};
        var progressCounts = {};
        var planState = {};
        var futureDeparture = dateTimeFormat( dateAdd( "h", 3, now() ), "yyyy-mm-dd HH:nn:ss" );
        var futureReturn = dateTimeFormat( dateAdd( "h", 9, now() ), "yyyy-mm-dd HH:nn:ss" );

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip( sessionApi, prefix, futureDeparture, futureReturn, localCreated );

          checkinResult = postActiveCruiseCheckinWithApi( sessionApi, asset.floatPlanId, "Assistance Needed" );
          progressCounts = loadRouteProgressCounts( asset.floatPlanId );
          planState = loadPlanState( asset.floatPlanId );

          expect( isSuccessPayload( checkinResult ) ).toBeFalse( serializeJSON( checkinResult ) );
          expect( pickString( checkinResult, [ "ERROR", "error" ] ) ).toBe( "PRE_DEPARTURE_ASSISTANCE_REQUIRES_START", serializeJSON( checkinResult ) );
          expect( pickString( checkinResult, [ "MESSAGE", "message" ] ) ).notToBe( "Float plan API error." );
          expect( progressCounts.started_rows ).toBe( 0, serializeJSON( checkinResult ) );
          expect( progressCounts.completed_rows ).toBe( 0, serializeJSON( checkinResult ) );
          expect( listFindNoCase( "PLANNED,SCHEDULED", planState.route_status ) ).toBeGT( 0, serializeJSON( planState ) );
          expect( isDate( planState.route_started_at ) ).toBeFalse( serializeJSON( planState ) );
        } finally {
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "missing monitoring on an active scheduled route-backed plan does not return the generic API error", function() {
        var prefix = variables.naming.buildPrefix( "trip-activation-regression", "missing-monitoring" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var checkinResult = {};
        var progressCounts = {};
        var futureDeparture = dateTimeFormat( dateAdd( "h", 3, now() ), "yyyy-mm-dd HH:nn:ss" );
        var futureReturn = dateTimeFormat( dateAdd( "h", 9, now() ), "yyyy-mm-dd HH:nn:ss" );
        var errorVal = "";

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          setPlanSchedule( asset.floatPlanId, futureDeparture, futureReturn, "UTC" );
          markPlanActive( asset.floatPlanId );
          deleteMonitoringRows( asset.floatPlanId );

          checkinResult = postActiveCruiseCheckinWithApi( sessionApi, asset.floatPlanId, "On Track" );
          progressCounts = loadRouteProgressCounts( asset.floatPlanId );
          errorVal = pickString( checkinResult, [ "ERROR", "error" ] );

          expect( pickString( checkinResult, [ "MESSAGE", "message" ] ) ).notToBe( "Float plan API error." );
          if ( isSuccessPayload( checkinResult ) ) {
            expect( countMonitoringRows( asset.floatPlanId ) ).toBe( 1, serializeJSON( checkinResult ) );
            expect( progressCounts.started_rows ).toBeGT( 0, serializeJSON( checkinResult ) );
          } else {
            expect( errorVal ).toBe( "MONITORING_INIT_REQUIRED_DATA_MISSING", serializeJSON( checkinResult ) );
            expect( progressCounts.started_rows ).toBe( 0, serializeJSON( checkinResult ) );
          }
        } finally {
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );
    } );
  }

  private struct function createActivatedScheduledTrip(
    required any apiSupport,
    required string prefix,
    required string departureUtc,
    required string returnUtc,
    required struct created
  ) {
    var asset = createRouteLinkedDraftForApi( arguments.apiSupport, arguments.prefix, arguments.created );
    var sendResult = {};
    attachContactToPlan( arguments.apiSupport, asset.floatPlanId, arguments.prefix, arguments.created );
    setPlanSchedule( asset.floatPlanId, arguments.departureUtc, arguments.returnUtc, "UTC" );
    sendResult = sendFloatPlanWithApi( arguments.apiSupport, asset.floatPlanId );
    expect( isSuccessPayload( sendResult ) ).toBeTrue( serializeJSON( sendResult ) );
    return asset;
  }

  private any function buildSessionApiSupport() {
    return new fpw.tests.support.FpwApiSupport().init(
      baseUrl = variables.api.getBaseUrl(),
      authEmail = variables.sessionApiUser.email,
      authPassword = variables.sessionApiUser.password
    );
  }

  private struct function newCreatedTracker() {
    return { vesselIds = [], routeCodes = [], floatPlanIds = [], contactIds = [] };
  }

  private struct function createSessionApiUser() {
    var signupApi = new fpw.tests.support.FpwApiSupport().init(
      baseUrl = variables.api.getBaseUrl()
    );
    var uniqueEmail = "fpw-trip-activation-" & replace( createUUID(), "-", "", "all" ) & "@example.com";
    var payload = signupApi.postJson( "/api/v1/join.cfc?method=handle", {
      firstName = "FPW",
      lastName = "TripActivation",
      email = uniqueEmail,
      password = "changeIt",
      confirmPassword = "changeIt",
      termsAccepted = true
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
    var cleanupSupport = new fpw.tests.support.FpwCleanupSupport().init( arguments.apiSupport );
    cleanupSupport.cleanupCurrentRouteFloatPlanGroup();

    var vesselPayload = arguments.apiSupport.saveVessel( {
      vesselId = 0,
      vesselName = variables.naming.buildName( arguments.prefix, "Trip Activation Vessel" ),
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
      route_name = variables.naming.buildName( arguments.prefix, "Trip Activation Route" ),
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

  private void function attachContactToPlan( required any apiSupport, required numeric floatPlanId, required string prefix, required struct created ) {
    var contactPayload = arguments.apiSupport.saveContact( {
      contactId = 0,
      name = variables.naming.buildName( arguments.prefix, "Activation Contact" ),
      phone = "5555551212",
      email = "fpw-trip-activation-contact-" & lCase( replace( createUUID(), "-", "", "all" ) ) & "@example.com"
    } );
    var contactId = val( contactPayload.CONTACTID ?: 0 );

    ensureSuccess( contactPayload, "save contact" );
    expect( contactId ).toBeGT( 0, serializeJSON( contactPayload ) );
    arrayAppend( arguments.created.contactIds, contactId );

    queryExecute(
      "INSERT INTO floatplan_contacts (floatPlanId, contactId)
       VALUES (:floatPlanId, :contactId)",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        contactId = { value = contactId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private struct function sendFloatPlanWithApi( required any apiSupport, required numeric floatPlanId ) {
    return arguments.apiSupport.postJson( "/api/v1/floatplan.cfc?method=handle&action=send", {
      floatPlanId = arguments.floatPlanId
    } );
  }

  private struct function postActiveCruiseCheckinWithApi( required any apiSupport, required numeric floatPlanId, required string statusValue, string note = "" ) {
    return arguments.apiSupport.postJson( "/api/v1/floatplan.cfc?method=handle&action=checkin", {
      floatPlanId = arguments.floatPlanId,
      status = arguments.statusValue,
      note = arguments.note
    } );
  }

  private struct function postCompleteLegWithApi( required any apiSupport, required numeric floatPlanId, required numeric expectedLegOrder ) {
    return arguments.apiSupport.postJson( "/api/v1/floatplan.cfc?method=handle&action=completeleg", {
      floatPlanId = arguments.floatPlanId,
      expectedLegOrder = arguments.expectedLegOrder
    } );
  }

  private struct function cancelFloatPlanWithApi( required any apiSupport, required numeric floatPlanId ) {
    return arguments.apiSupport.postJson( "/api/v1/floatplan.cfc?method=handle&action=cancel", {
      floatPlanId = arguments.floatPlanId
    } );
  }

  private void function setPlanScheduleStoredUtcWithDisplayZone(
    required numeric floatPlanId,
    required numeric departureOffsetHours,
    required numeric returnOffsetHours,
    required string displayTimeZoneId
  ) {
    var departureOffsetHoursVal = int( arguments.departureOffsetHours );
    var returnOffsetHoursVal = int( arguments.returnOffsetHours );
    var qNow = queryExecute(
      "SELECT DATE_FORMAT(UTC_TIMESTAMP(), '%Y-%m-%d %H:%i:%s') AS utc_now",
      {},
      { datasource = "fpw" }
    );
    var javaLocalDateTimeClass = createObject( "java", "java.time.LocalDateTime" );
    var javaZoneIdClass = createObject( "java", "java.time.ZoneId" );
    var javaZoneOffsetClass = createObject( "java", "java.time.ZoneOffset" );
    var javaDateTimeFormatterClass = createObject( "java", "java.time.format.DateTimeFormatter" );
    var formatter = javaDateTimeFormatterClass.ofPattern( "yyyy-MM-dd HH:mm:ss" );
    var utcZone = javaZoneOffsetClass.UTC;
    var displayZone = javaZoneIdClass.of( arguments.displayTimeZoneId );
    var nowUtc = javaLocalDateTimeClass.parse( replace( trim( toString( qNow.utc_now[ 1 ] ) ), " ", "T", "one" ) ).atZone( utcZone );
    var departureInstant = nowUtc.plusHours( javacast( "long", departureOffsetHoursVal ) ).toInstant();
    var returnInstant = nowUtc.plusHours( javacast( "long", returnOffsetHoursVal ) ).toInstant();
    var departureUtc = formatter.withZone( utcZone ).format( departureInstant );
    var returnUtc = formatter.withZone( utcZone ).format( returnInstant );
    var departureLocal = formatter.withZone( displayZone ).format( departureInstant );
    var returnLocal = formatter.withZone( displayZone ).format( returnInstant );

    queryExecute(
      "UPDATE floatplans
       SET departureTime = :departureLocal,
           departureTimeUTC = :departureUtc,
           departTimezone = 'UTC',
           departureTZ = :displayTimeZoneId,
           returnTime = :returnLocal,
           returnTimeUTC = :returnUtc,
           returnTimezone = 'UTC',
           returnTZ = :displayTimeZoneId,
           dailyStartLocalTime = '08:00:00',
           activatedAt = NULL,
           checkedInAt = NULL,
           checkin_context = NULL,
           closedAt = NULL,
           lastUpdateStatus = UTC_TIMESTAMP(),
           `status` = 'DRAFT'
       WHERE floatplanId = :floatPlanId",
      {
        departureLocal = { value = departureLocal, cfsqltype = "cf_sql_varchar" },
        departureUtc = { value = departureUtc, cfsqltype = "cf_sql_varchar" },
        returnLocal = { value = returnLocal, cfsqltype = "cf_sql_varchar" },
        returnUtc = { value = returnUtc, cfsqltype = "cf_sql_varchar" },
        displayTimeZoneId = { value = arguments.displayTimeZoneId, cfsqltype = "cf_sql_varchar" },
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    deleteMonitoringRows( arguments.floatPlanId );
  }

  private void function setPlanSchedule(
    required numeric floatPlanId,
    required string departureUtc,
    required string returnUtc,
    required string timeZoneId
  ) {
    queryExecute(
      "UPDATE floatplans
       SET departureTime = CONVERT_TZ(:departureUtc, :timeZoneId, 'UTC'),
           departureTimeUTC = :departureUtc,
           departTimezone = :timeZoneId,
           departureTZ = :timeZoneId,
           returnTime = CONVERT_TZ(:returnUtc, :timeZoneId, 'UTC'),
           returnTimeUTC = :returnUtc,
           returnTimezone = :timeZoneId,
           returnTZ = :timeZoneId,
           dailyStartLocalTime = '08:00:00',
           activatedAt = NULL,
           checkedInAt = NULL,
           checkin_context = NULL,
           closedAt = NULL,
           lastUpdateStatus = UTC_TIMESTAMP(),
           `status` = 'DRAFT'
       WHERE floatplanId = :floatPlanId",
      {
        departureUtc = { value = arguments.departureUtc, cfsqltype = "cf_sql_timestamp" },
        returnUtc = { value = arguments.returnUtc, cfsqltype = "cf_sql_timestamp" },
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

  private struct function loadPlanScheduleValues( required numeric floatPlanId ) {
    var qRow = queryExecute(
      "SELECT
          DATE_FORMAT(departureTime, '%Y-%m-%d %H:%i:%s') AS departure_time_local,
          departureTZ,
          DATE_FORMAT(departureTimeUTC, '%Y-%m-%d %H:%i:%s') AS departure_time_utc,
          DATE_FORMAT(returnTime, '%Y-%m-%d %H:%i:%s') AS return_time_local,
          returnTZ,
          DATE_FORMAT(returnTimeUTC, '%Y-%m-%d %H:%i:%s') AS return_time_utc,
          notes
       FROM floatplans
       WHERE floatPlanId = :floatPlanId
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    expect( qRow.recordCount ).toBe( 1 );
    return {
      departure_time_local = isNull( qRow.departure_time_local[ 1 ] ) ? "" : trim( toString( qRow.departure_time_local[ 1 ] ) ),
      departure_tz = isNull( qRow.departureTZ[ 1 ] ) ? "" : trim( toString( qRow.departureTZ[ 1 ] ) ),
      departure_time_utc = isNull( qRow.departure_time_utc[ 1 ] ) ? "" : trim( toString( qRow.departure_time_utc[ 1 ] ) ),
      return_time_local = isNull( qRow.return_time_local[ 1 ] ) ? "" : trim( toString( qRow.return_time_local[ 1 ] ) ),
      return_tz = isNull( qRow.returnTZ[ 1 ] ) ? "" : trim( toString( qRow.returnTZ[ 1 ] ) ),
      return_time_utc = isNull( qRow.return_time_utc[ 1 ] ) ? "" : trim( toString( qRow.return_time_utc[ 1 ] ) ),
      notes = isNull( qRow.notes[ 1 ] ) ? "" : trim( toString( qRow.notes[ 1 ] ) )
    };
  }

  private struct function loadPlanState( required numeric floatPlanId ) {
    var qRow = queryExecute(
      "SELECT
          fp.floatPlanId,
          UPPER(TRIM(fp.`status`)) AS status_value,
          fp.route_instance_id,
          fp.departureTime,
          UPPER(TRIM(COALESCE(ri.status, ''))) AS route_status,
          ri.started_at AS route_started_at
       FROM floatplans fp
       LEFT JOIN route_instances ri
         ON ri.id = fp.route_instance_id
       WHERE fp.floatPlanId = :floatPlanId
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    expect( qRow.recordCount ).toBe( 1 );
    return {
      floatPlanId = val( qRow.floatPlanId[ 1 ] ),
      status = trim( toString( qRow.status_value[ 1 ] ) ),
      route_instance_id = val( qRow.route_instance_id[ 1 ] ),
      departureTime = isNull( qRow.departureTime[ 1 ] ) ? "" : qRow.departureTime[ 1 ],
      route_status = isNull( qRow.route_status[ 1 ] ) ? "" : trim( toString( qRow.route_status[ 1 ] ) ),
      route_started_at = isNull( qRow.route_started_at[ 1 ] ) ? "" : qRow.route_started_at[ 1 ]
    };
  }

  private struct function loadRouteProgressCounts( required numeric floatPlanId ) {
    var qCounts = queryExecute(
      "SELECT
          COUNT(DISTINCT ril.id) AS route_leg_count,
          COUNT(DISTINCT rilp.id) AS progress_row_count,
          SUM(CASE WHEN UPPER(TRIM(COALESCE(rilp.status, ''))) = 'NOT_STARTED' THEN 1 ELSE 0 END) AS not_started_rows,
          SUM(CASE WHEN rilp.leg_started_at IS NOT NULL THEN 1 ELSE 0 END) AS started_rows,
          SUM(CASE WHEN rilp.completed_at IS NOT NULL OR UPPER(TRIM(COALESCE(rilp.status, ''))) = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_rows
       FROM floatplans fp
       LEFT JOIN route_instance_legs ril
         ON ril.route_instance_id = fp.route_instance_id
       LEFT JOIN route_instance_leg_progress rilp
         ON rilp.route_instance_id = fp.route_instance_id
        AND rilp.leg_order = ril.leg_order
        AND rilp.user_id = fp.userId
       WHERE fp.floatPlanId = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    expect( qCounts.recordCount ).toBe( 1 );
    return {
      route_leg_count = val( qCounts.route_leg_count[ 1 ] ),
      progress_row_count = val( qCounts.progress_row_count[ 1 ] ),
      not_started_rows = val( qCounts.not_started_rows[ 1 ] ),
      started_rows = val( qCounts.started_rows[ 1 ] ),
      completed_rows = val( qCounts.completed_rows[ 1 ] )
    };
  }

  private struct function loadRouteProgressCountsByRouteInstance( required numeric userId, required numeric routeInstanceId ) {
    var qCounts = queryExecute(
      "SELECT
          COUNT(DISTINCT ril.id) AS route_leg_count,
          COUNT(DISTINCT rilp.id) AS progress_row_count,
          SUM(CASE WHEN UPPER(TRIM(COALESCE(rilp.status, ''))) = 'NOT_STARTED' THEN 1 ELSE 0 END) AS not_started_rows,
          SUM(CASE WHEN rilp.leg_started_at IS NOT NULL THEN 1 ELSE 0 END) AS started_rows,
          SUM(CASE WHEN rilp.completed_at IS NOT NULL OR UPPER(TRIM(COALESCE(rilp.status, ''))) = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_rows
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
      { datasource = "fpw" }
    );
    expect( qCounts.recordCount ).toBe( 1 );
    return {
      route_leg_count = val( qCounts.route_leg_count[ 1 ] ),
      progress_row_count = val( qCounts.progress_row_count[ 1 ] ),
      not_started_rows = val( qCounts.not_started_rows[ 1 ] ),
      started_rows = val( qCounts.started_rows[ 1 ] ),
      completed_rows = val( qCounts.completed_rows[ 1 ] )
    };
  }

  private struct function loadRouteInputs( required numeric routeInstanceId ) {
    var qRoute = queryExecute(
      "SELECT routegen_inputs_json
       FROM route_instances
       WHERE id = :routeInstanceId
       LIMIT 1",
      {
        routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    var rawInputs = "";

    expect( qRoute.recordCount ).toBe( 1 );
    rawInputs = isNull( qRoute.routegen_inputs_json[ 1 ] ) ? "" : trim( toString( qRoute.routegen_inputs_json[ 1 ] ) );
    if ( !len( rawInputs ) ) {
      return {};
    }
    try {
      return deserializeJSON( rawInputs );
    } catch ( any parseErr ) {
      return {};
    }
  }

  private string function loadRouteCodeForFloatPlan( required numeric floatPlanId ) {
    var qRoute = queryExecute(
      "SELECT ri.generated_route_code
       FROM floatplans fp
       INNER JOIN route_instances ri
          ON ri.id = fp.route_instance_id
       WHERE fp.floatPlanId = :floatPlanId
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    if ( qRoute.recordCount NEQ 1 ) {
      return "";
    }
    return trim( toString( qRoute.generated_route_code[ 1 ] ) );
  }

  private void function appendRouteCodeIfMissing( required struct created, required string routeCode ) {
    var routeCodeVal = trim( arguments.routeCode );
    var i = 0;

    if ( !len( routeCodeVal ) ) {
      return;
    }

    for ( i = 1; i LTE arrayLen( arguments.created.routeCodes ); i++ ) {
      if ( compareNoCase( trim( toString( arguments.created.routeCodes[ i ] ) ), routeCodeVal ) EQ 0 ) {
        return;
      }
    }

    arrayAppend( arguments.created.routeCodes, routeCodeVal );
  }

  private struct function loadLegProgress( required numeric floatPlanId, required numeric legOrder ) {
    var qRow = queryExecute(
      "SELECT rilp.status, rilp.leg_started_at, rilp.completed_at
       FROM floatplans fp
       INNER JOIN route_instance_leg_progress rilp
          ON rilp.route_instance_id = fp.route_instance_id
         AND rilp.user_id = fp.userId
       WHERE fp.floatPlanId = :floatPlanId
         AND rilp.leg_order = :legOrder
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        legOrder = { value = arguments.legOrder, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    expect( qRow.recordCount ).toBe( 1 );
    return {
      status = isNull( qRow.status[ 1 ] ) ? "" : trim( toString( qRow.status[ 1 ] ) ),
      leg_started_at = isNull( qRow.leg_started_at[ 1 ] ) ? "" : qRow.leg_started_at[ 1 ],
      completed_at = isNull( qRow.completed_at[ 1 ] ) ? "" : qRow.completed_at[ 1 ]
    };
  }

  private struct function loadFutureLegProgressCounts( required numeric floatPlanId, required numeric currentLegOrder ) {
    var qCounts = queryExecute(
      "SELECT
          COUNT(*) AS future_rows,
          SUM(CASE WHEN UPPER(TRIM(COALESCE(rilp.status, ''))) = 'NOT_STARTED' THEN 1 ELSE 0 END) AS not_started_rows,
          SUM(CASE WHEN UPPER(TRIM(COALESCE(rilp.status, ''))) = 'STARTED' THEN 1 ELSE 0 END) AS started_status_rows,
          SUM(CASE WHEN rilp.leg_started_at IS NOT NULL THEN 1 ELSE 0 END) AS started_rows,
          SUM(CASE WHEN rilp.completed_at IS NOT NULL OR UPPER(TRIM(COALESCE(rilp.status, ''))) = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_rows
       FROM floatplans fp
       INNER JOIN route_instance_leg_progress rilp
          ON rilp.route_instance_id = fp.route_instance_id
         AND rilp.user_id = fp.userId
       WHERE fp.floatPlanId = :floatPlanId
         AND rilp.leg_order > :currentLegOrder",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        currentLegOrder = { value = arguments.currentLegOrder, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    expect( qCounts.recordCount ).toBe( 1 );
    return {
      future_rows = val( qCounts.future_rows[ 1 ] ),
      not_started_rows = val( qCounts.not_started_rows[ 1 ] ),
      started_status_rows = val( qCounts.started_status_rows[ 1 ] ),
      started_rows = val( qCounts.started_rows[ 1 ] ),
      completed_rows = val( qCounts.completed_rows[ 1 ] )
    };
  }

  private numeric function countMonitoringRows( required numeric floatPlanId ) {
    var qRows = queryExecute(
      "SELECT COUNT(*) AS row_count
       FROM floatplan_monitoring
       WHERE float_plan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    return val( qRows.row_count[ 1 ] );
  }

  private struct function loadMonitoringRow( required numeric floatPlanId ) {
    var qRow = queryExecute(
      "SELECT
          monitoring_mode,
          monitor_state,
          is_monitoring_enabled,
          expected_checkin_at,
          grace_expires_at,
          next_monitor_eval_at,
          last_checkin_at,
          last_checkin_status,
          grace_window_minutes
       FROM floatplan_monitoring
       WHERE float_plan_id = :floatPlanId
       ORDER BY id DESC
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    expect( qRow.recordCount ).toBe( 1 );
    return {
      monitoring_mode = trim( toString( qRow.monitoring_mode[ 1 ] ) ),
      monitor_state = trim( toString( qRow.monitor_state[ 1 ] ) ),
      is_monitoring_enabled = val( qRow.is_monitoring_enabled[ 1 ] ),
      expected_checkin_at = isNull( qRow.expected_checkin_at[ 1 ] ) ? "" : qRow.expected_checkin_at[ 1 ],
      grace_expires_at = isNull( qRow.grace_expires_at[ 1 ] ) ? "" : qRow.grace_expires_at[ 1 ],
      next_monitor_eval_at = isNull( qRow.next_monitor_eval_at[ 1 ] ) ? "" : qRow.next_monitor_eval_at[ 1 ],
      last_checkin_at = isNull( qRow.last_checkin_at[ 1 ] ) ? "" : qRow.last_checkin_at[ 1 ],
      last_checkin_status = isNull( qRow.last_checkin_status[ 1 ] ) ? "" : trim( toString( qRow.last_checkin_status[ 1 ] ) ),
      grace_window_minutes = val( qRow.grace_window_minutes[ 1 ] )
    };
  }

  private void function deleteMonitoringRows( required numeric floatPlanId ) {
    queryExecute(
      "DELETE FROM floatplan_alert_history WHERE floatPlanId = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
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

  private void function cleanupRouteLinkedAssetsForApi( required any apiSupport, required struct created ) {
    var cleanupSupport = new fpw.tests.support.FpwCleanupSupport().init( arguments.apiSupport );
    for ( var i = arrayLen( arguments.created.floatPlanIds ); i GTE 1; i-- ) {
      try {
        deleteVoyageStreamsForFloatPlan( arguments.created.floatPlanIds[ i ] );
      } catch ( any ignoredStreamCleanup ) {}
      try {
        cleanupSupport.cleanupFloatPlan( arguments.created.floatPlanIds[ i ] );
      } catch ( any ignoredFloatPlanCleanup ) {}
      forceDeleteFloatPlanRecords( arguments.created.floatPlanIds[ i ] );
    }
    for ( var j = arrayLen( arguments.created.routeCodes ); j GTE 1; j-- ) {
      try {
        cleanupSupport.cleanupRoute( arguments.created.routeCodes[ j ] );
      } catch ( any ignoredRouteCleanup ) {}
      forceDeleteRouteInstanceRecords( arguments.created.routeCodes[ j ] );
    }
    for ( var c = arrayLen( arguments.created.contactIds ); c GTE 1; c-- ) {
      try {
        cleanupSupport.cleanupContact( arguments.created.contactIds[ c ] );
      } catch ( any ignoredContactCleanup ) {
        queryExecute(
          "DELETE FROM contacts WHERE contactId = :contactId",
          {
            contactId = { value = arguments.created.contactIds[ c ], cfsqltype = "cf_sql_integer" }
          },
          { datasource = "fpw" }
        );
      }
    }
    for ( var k = arrayLen( arguments.created.vesselIds ); k GTE 1; k-- ) {
      try {
        cleanupSupport.cleanupVessel( arguments.created.vesselIds[ k ] );
      } catch ( any ignoredVesselCleanup ) {}
    }
  }

  private void function forceDeleteFloatPlanRecords( required numeric floatPlanId ) {
    deleteMonitoringRows( arguments.floatPlanId );
    queryExecute(
      "DELETE FROM floatplan_activity_segments WHERE floatplan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM floatplan_events WHERE floatplan_id = :floatPlanId",
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

  private void function forceDeleteRouteInstanceRecords( required string routeCode ) {
    queryExecute(
      "DELETE rilp
       FROM route_instance_leg_progress rilp
       INNER JOIN route_instances ri
          ON ri.id = rilp.route_instance_id
       WHERE ri.generated_route_code = :routeCode",
      {
        routeCode = { value = arguments.routeCode, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE ril
       FROM route_instance_legs ril
       INNER JOIN route_instances ri
          ON ri.id = ril.route_instance_id
       WHERE ri.generated_route_code = :routeCode",
      {
        routeCode = { value = arguments.routeCode, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM route_instances
       WHERE generated_route_code = :routeCode",
      {
        routeCode = { value = arguments.routeCode, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
  }

  private void function deleteVoyageStreamsForFloatPlan( required numeric floatPlanId ) {
    queryExecute(
      "DELETE FROM voyage_reactions WHERE post_id IN (
          SELECT id FROM voyage_posts WHERE stream_id IN (
            SELECT id FROM voyage_streams WHERE floatplan_id = :floatPlanId
          )
       )",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM voyage_comments WHERE post_id IN (
          SELECT id FROM voyage_posts WHERE stream_id IN (
            SELECT id FROM voyage_streams WHERE floatplan_id = :floatPlanId
          )
       )",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM voyage_posts WHERE stream_id IN (
          SELECT id FROM voyage_streams WHERE floatplan_id = :floatPlanId
       )",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM voyage_followers WHERE stream_id IN (
          SELECT id FROM voyage_streams WHERE floatplan_id = :floatPlanId
       )",
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
  }

  private boolean function isSuccessPayload( required struct payload ) {
    if ( structKeyExists( arguments.payload, "SUCCESS" ) AND arguments.payload.SUCCESS EQ true ) {
      return true;
    }
    if ( structKeyExists( arguments.payload, "success" ) AND arguments.payload.success EQ true ) {
      return true;
    }
    return false;
  }

  private string function pickString( required struct payload, required array keys, string defaultValue = "" ) {
    for ( var keyName in arguments.keys ) {
      if ( structKeyExists( arguments.payload, keyName ) AND !isNull( arguments.payload[ keyName ] ) ) {
        return trim( toString( arguments.payload[ keyName ] ) );
      }
    }
    return arguments.defaultValue;
  }

  private string function normalizeDbDateTime( required any value ) {
    if ( !isDate( arguments.value ) ) {
      return "";
    }
    return dateTimeFormat( arguments.value, "yyyy-mm-dd HH:nn:ss" );
  }

  private void function ensureSuccess( required struct payload, required string label ) {
    if ( !isSuccessPayload( arguments.payload ) ) {
      throw( message = "Trip activation regression setup failed: " & arguments.label, detail = serializeJSON( arguments.payload ) );
    }
  }
}
