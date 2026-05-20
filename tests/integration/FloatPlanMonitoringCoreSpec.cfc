component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.api = new fpw.tests.support.FpwApiSupport().init(
      authEmail = "detroit@email.com",
      authPassword = "changeIt"
    );
    variables.naming = new fpw.tests.support.FpwNamingSupport();
    variables.cleanup = new fpw.tests.support.FpwCleanupSupport();
    variables.cleanup.init( variables.api );
    variables.monitorService = new fpw.api.v1.monitor().init();
    variables.entitlements = new fpw.api.v1.MemberEntitlementService().init("fpw");
    variables.created = { vesselIds = [], routeCodes = [], floatPlanIds = [], contactIds = [] };
    variables.hadOriginalTestUserId = structKeyExists( url, "testUserId" );
    variables.originalTestUserId = variables.hadOriginalTestUserId ? url.testUserId : "";
    variables.sessionApiUser = createSessionApiUser();
    url.testUserId = variables.sessionApiUser.userId;
    variables.monitoringPremiumEntitlement = variables.entitlements.createAdminCompEntitlement(variables.sessionApiUser.userId);
  }

  function afterAll() {
    for ( var i = arrayLen( variables.created.floatPlanIds ); i GTE 1; i-- ) {
      forceDeleteFloatPlanRecords( variables.created.floatPlanIds[ i ] );
    }
    for ( var j = arrayLen( variables.created.routeCodes ); j GTE 1; j-- ) {
      try {
        variables.cleanup.cleanupRoute( variables.created.routeCodes[ j ] );
      } catch ( any ignoredRouteCleanup ) {}
    }
    for ( var c = arrayLen( variables.created.contactIds ); c GTE 1; c-- ) {
      try {
        variables.cleanup.cleanupContact( variables.created.contactIds[ c ] );
      } catch ( any ignoredContactCleanup ) {}
    }
    for ( var k = arrayLen( variables.created.vesselIds ); k GTE 1; k-- ) {
      try {
        variables.cleanup.cleanupVessel( variables.created.vesselIds[ k ] );
      } catch ( any ignoredVesselCleanup ) {}
    }
    queryExecute(
      "DELETE FROM member_entitlements WHERE user_id = :userId",
      {
        userId = { value = variables.sessionApiUser.userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    cleanupSessionApiUser();
    if ( variables.hadOriginalTestUserId ) {
      url.testUserId = variables.originalTestUserId;
    } else {
      structDelete( url, "testUserId", false );
    }
  }

  function run() {
    describe( "Float plan monitoring core", function() {
      it( "start monitoring initializes active_route with same-day 18:00 local when trip start is before 18:00", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "start-active-route-before-18" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern" );

        var startResult = variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" );
        var monitoringRow = loadMonitoringRow( asset.floatPlanId );
        var startedEvents = loadMonitoringEvents( asset.floatPlanId, "MONITORING_STARTED" );

        expect( startResult.SUCCESS ).toBeTrue( serializeJSON( startResult ) );
        expect( monitoringRow.monitor_state ).toBe( "ACTIVE" );
        expect( monitoringRow.monitoring_mode ).toBe( "active_route" );
        expect( toLocalStamp( monitoringRow.expected_checkin_at, "US/Eastern" ) ).toBe( "2026-04-09 18:00:00" );
        expect( toLocalStamp( monitoringRow.grace_expires_at, "US/Eastern" ) ).toBe( "2026-04-09 19:00:00" );
        expect( startedEvents.recordCount ).toBe( 1 );
      } );

      it( "active_route uses next-day 08:00 local when trip start is at or after 18:00", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "start-active-route-after-18" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 18:00:00", "2026-04-10 20:00:00", "US/Eastern" );

        var startResult = variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" );
        var monitoringRow = loadMonitoringRow( asset.floatPlanId );

        expect( startResult.SUCCESS ).toBeTrue( serializeJSON( startResult ) );
        expect( toLocalStamp( monitoringRow.expected_checkin_at, "US/Eastern" ) ).toBe( "2026-04-10 08:00:00" );
      } );

      it( "basic mode uses only the final return time", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "start-basic" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 18:30:00", "US/Central" );

        var startResult = variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "basic" );
        var monitoringRow = loadMonitoringRow( asset.floatPlanId );

        expect( startResult.SUCCESS ).toBeTrue( serializeJSON( startResult ) );
        expect( monitoringRow.monitoring_mode ).toBe( "basic" );
        expect( toLocalStamp( monitoringRow.expected_checkin_at, "US/Central" ) ).toBe( "2026-04-10 18:30:00" );
        expect( toLocalStamp( monitoringRow.grace_expires_at, "US/Central" ) ).toBe( "2026-04-10 19:30:00" );
      } );

      it( "basic mode preserves same-day planned return as the expected checkpoint", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "basic-same-day-return" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 08:00:00", "2026-04-09 15:00:00", "US/Eastern" );

        var startResult = variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "basic" );
        var monitoringRow = loadMonitoringRow( asset.floatPlanId );

        expect( startResult.SUCCESS ).toBeTrue( serializeJSON( startResult ) );
        expect( monitoringRow.monitoring_mode ).toBe( "basic" );
        expect( toLocalStamp( monitoringRow.expected_checkin_at, "US/Eastern" ) ).toBe( "2026-04-09 15:00:00" );
        expect( toLocalStamp( monitoringRow.grace_expires_at, "US/Eastern" ) ).toBe( "2026-04-09 16:00:00" );
      } );

      it( "active_route uses same-day planned return after actual leg-start proof when it is before daily check-in", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "active-route-planned-return-before-daily" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 07:30:00", "2026-04-09 15:00:00", "US/Eastern" );
        ensureSuccess( variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" ), "start active_route monitor" );
        setFirstLegStartedAt( asset.floatPlanId, "2026-04-09 08:00:00", "US/Eastern" );

        var refreshResult = variables.monitorService.refreshActiveRouteCheckpointFromLegStart( asset.floatPlanId );
        var monitoringRow = loadMonitoringRow( asset.floatPlanId );

        expect( refreshResult.SUCCESS ).toBeTrue( serializeJSON( refreshResult ) );
        expect( refreshResult.UPDATED ).toBeTrue( serializeJSON( refreshResult ) );
        expect( toLocalStamp( monitoringRow.expected_checkin_at, "US/Eastern" ) ).toBe( "2026-04-09 15:00:00" );
        expect( normalizeDbDateTime( monitoringRow.expected_checkin_at ) ).toBe( "2026-04-09 19:00:00" );
        expect( normalizeDbDateTime( monitoringRow.expected_checkin_at ) EQ "2026-04-09 15:00:00" ).toBeFalse();
        expect( toLocalStamp( monitoringRow.grace_expires_at, "US/Eastern" ) ).toBe( "2026-04-09 16:00:00" );
      } );

      it( "active_route uses next-morning planned return after evening leg-start proof when it is before morning checkpoint", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "active-route-next-morning-return-before-morning" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 19:00:00", "2026-04-10 04:00:00", "US/Eastern" );
        ensureSuccess( variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" ), "start active_route monitor" );
        setFirstLegStartedAt( asset.floatPlanId, "2026-04-09 19:00:00", "US/Eastern" );

        var refreshResult = variables.monitorService.refreshActiveRouteCheckpointFromLegStart( asset.floatPlanId );
        var monitoringRow = loadMonitoringRow( asset.floatPlanId );

        expect( refreshResult.SUCCESS ).toBeTrue( serializeJSON( refreshResult ) );
        expect( refreshResult.UPDATED ).toBeTrue( serializeJSON( refreshResult ) );
        expect( toLocalStamp( monitoringRow.expected_checkin_at, "US/Eastern" ) ).toBe( "2026-04-10 04:00:00" );
        expect( normalizeDbDateTime( monitoringRow.expected_checkin_at ) ).toBe( "2026-04-10 08:00:00" );
        expect( normalizeDbDateTime( monitoringRow.expected_checkin_at ) EQ "2026-04-10 04:00:00" ).toBeFalse();
        expect( toLocalStamp( monitoringRow.grace_expires_at, "US/Eastern" ) ).toBe( "2026-04-10 05:00:00" );
      } );

      it( "active_route planned return checkpoint feeds the existing missed and escalated evaluator cycle", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "planned-return-evaluator-cycle" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 07:30:00", "2026-04-09 15:00:00", "US/Eastern" );
        ensureSuccess( variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" ), "start active_route monitor" );
        setFirstLegStartedAt( asset.floatPlanId, "2026-04-09 08:00:00", "US/Eastern" );
        ensureSuccess( variables.monitorService.refreshActiveRouteCheckpointFromLegStart( asset.floatPlanId ), "refresh from actual leg start" );

        var checkpointRow = loadMonitoringRow( asset.floatPlanId );
        expect( toLocalStamp( checkpointRow.expected_checkin_at, "US/Eastern" ) ).toBe( "2026-04-09 15:00:00" );

        var missedResult = variables.monitorService.evaluateMonitoringCycle( asset.floatPlanId );
        var missedRow = loadMonitoringRow( asset.floatPlanId );
        var missedEvents = loadMonitoringEvents( asset.floatPlanId, "CHECKIN_MISSED" );
        expect( missedResult.SUCCESS ).toBeTrue( serializeJSON( missedResult ) );
        expect( missedRow.monitor_state ).toBe( "MISSED" );
        expect( missedEvents.recordCount ).toBe( 1 );

        updateMonitoringTimes( asset.floatPlanId, {
          monitor_state = "MISSED",
          missed_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 121 MINUTE)",
          next_monitor_eval_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE)"
        } );
        var escalatedResult = variables.monitorService.evaluateMonitoringCycle( asset.floatPlanId );
        var escalatedRow = loadMonitoringRow( asset.floatPlanId );
        var contactAlertEvents = loadMonitoringEvents( asset.floatPlanId, "CONTACT_ALERTED" );
        expect( escalatedResult.SUCCESS ).toBeTrue( serializeJSON( escalatedResult ) );
        expect( escalatedRow.monitor_state ).toBe( "ESCALATED" );
        expect( contactAlertEvents.recordCount ).toBe( 1 );
      } );

      it( "active_route keeps daily check-in when planned return is after the daily checkpoint", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "active-route-return-after-daily" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 07:30:00", "2026-04-09 20:00:00", "US/Eastern" );
        ensureSuccess( variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" ), "start active_route monitor" );
        setFirstLegStartedAt( asset.floatPlanId, "2026-04-09 08:00:00", "US/Eastern" );

        var refreshResult = variables.monitorService.refreshActiveRouteCheckpointFromLegStart( asset.floatPlanId );
        var monitoringRow = loadMonitoringRow( asset.floatPlanId );

        expect( refreshResult.SUCCESS ).toBeTrue( serializeJSON( refreshResult ) );
        expect( refreshResult.UPDATED ).toBeTrue( serializeJSON( refreshResult ) );
        expect( toLocalStamp( monitoringRow.expected_checkin_at, "US/Eastern" ) ).toBe( "2026-04-09 18:00:00" );
        expect( toLocalStamp( monitoringRow.grace_expires_at, "US/Eastern" ) ).toBe( "2026-04-09 19:00:00" );
      } );

      it( "scheduled active_route monitoring does not use planned return before actual start proof", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "scheduled-return-before-start-proof" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 08:00:00", "2026-04-09 15:00:00", "US/Eastern" );
        markPlanActive( asset.floatPlanId );

        var startResult = variables.monitorService.startScheduledRouteMonitoringForFloatPlan( asset.floatPlanId );
        var monitoringRow = loadMonitoringRow( asset.floatPlanId );

        expect( startResult.SUCCESS ).toBeTrue( serializeJSON( startResult ) );
        expect( monitoringRow.monitoring_mode ).toBe( "active_route" );
        expect( toLocalStamp( monitoringRow.expected_checkin_at, "US/Eastern" ) ).toBe( "2026-04-09 08:00:00" );
        expect( toLocalStamp( monitoringRow.grace_expires_at, "US/Eastern" ) ).toBe( "2026-04-09 09:00:00" );
      } );

      it( "active_route ignores planned return while Secure for Night is active", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "secure-over-planned-return" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 07:30:00", "2026-04-09 15:00:00", "US/Eastern" );
        ensureSuccess( variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" ), "start active_route monitor" );
        setMonitoringSecureForNight( asset.floatPlanId, "2026-04-10 08:00:00", "US/Eastern" );
        setFirstLegStartedAt( asset.floatPlanId, "2026-04-09 08:00:00", "US/Eastern" );

        var refreshResult = variables.monitorService.refreshActiveRouteCheckpointFromLegStart( asset.floatPlanId );
        var monitoringRow = loadMonitoringRow( asset.floatPlanId );

        expect( refreshResult.SUCCESS ).toBeTrue( serializeJSON( refreshResult ) );
        expect( refreshResult.UPDATED ).toBeTrue( serializeJSON( refreshResult ) );
        expect( toLocalStamp( monitoringRow.expected_checkin_at, "US/Eastern" ) ).toBe( "2026-04-09 18:00:00" );
        expect( toLocalStamp( monitoringRow.expected_checkin_at, "US/Eastern" ) EQ "2026-04-09 15:00:00" ).toBeFalse();
      } );

      it( "scheduled route monitoring initializes departure as the first expected captain action and is idempotent", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "scheduled-start" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern" );
        markPlanActive( asset.floatPlanId );

        var startResult = variables.monitorService.startScheduledRouteMonitoringForFloatPlan( asset.floatPlanId );
        var secondStartResult = variables.monitorService.startScheduledRouteMonitoringForFloatPlan( asset.floatPlanId );
        var monitoringRow = loadMonitoringRow( asset.floatPlanId );
        var startedEvents = loadMonitoringEvents( asset.floatPlanId, "MONITORING_STARTED" );

        expect( startResult.SUCCESS ).toBeTrue( serializeJSON( startResult ) );
        expect( secondStartResult.SUCCESS ).toBeTrue( serializeJSON( secondStartResult ) );
        expect( countMonitoringRows( asset.floatPlanId ) ).toBe( 1 );
        expect( monitoringRow.monitor_state ).toBe( "ACTIVE" );
        expect( monitoringRow.monitoring_mode ).toBe( "active_route" );
        expect( monitoringRow.is_monitoring_enabled ).toBeTrue();
        expect( toLocalStamp( monitoringRow.expected_checkin_at, "US/Eastern" ) ).toBe( "2026-04-09 09:00:00" );
        expect( toLocalStamp( monitoringRow.grace_expires_at, "US/Eastern" ) ).toBe( "2026-04-09 10:00:00" );
        expect( normalizeDbDateTime( monitoringRow.next_monitor_eval_at ) ).toBe( normalizeDbDateTime( monitoringRow.expected_checkin_at ) );
        expect( len( trim( monitoringRow.last_checkin_at & "" ) ) ).toBe( 0 );
        expect( len( trim( monitoringRow.last_checkin_status & "" ) ) ).toBe( 0 );
        expect( startedEvents.recordCount ).toBe( 1 );
      } );

      it( "sending a route-backed scheduled float plan creates scheduled monitoring without starting route progress", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "scheduled-send" );
        var asset = createRouteLinkedDraft( prefix );
        var contactPayload = variables.api.saveContact( {
          contactId = 0,
          name = variables.naming.buildName( prefix, "Monitoring Contact" ),
          phone = "5555551212",
          email = variables.naming.buildEmail( prefix, "monitoring-contact" )
        } );
        var contactId = val( contactPayload.CONTACTID ?: 0 );
        var sendResult = {};
        var monitoringRow = {};
        var futureDeparture = dateTimeFormat( dateAdd( "h", 3, now() ), "yyyy-mm-dd HH:nn:ss" );
        var futureReturn = dateTimeFormat( dateAdd( "h", 9, now() ), "yyyy-mm-dd HH:nn:ss" );

        expect( contactPayload.SUCCESS ).toBeTrue( serializeJSON( contactPayload ) );
        expect( contactId ).toBeGT( 0, serializeJSON( contactPayload ) );
        arrayAppend( variables.created.contactIds, contactId );
        queryExecute(
          "INSERT INTO floatplan_contacts (floatPlanId, contactId)
           VALUES (:floatPlanId, :contactId)",
          {
            floatPlanId = { value = asset.floatPlanId, cfsqltype = "cf_sql_integer" },
            contactId = { value = contactId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = "fpw" }
        );
        setPlanSchedule( asset.floatPlanId, futureDeparture, futureReturn, "UTC" );

        sendResult = variables.api.postJson( "/api/v1/floatplan.cfc?method=handle&action=send", {
          floatPlanId = asset.floatPlanId
        } );

        expect( sendResult.SUCCESS ).toBeTrue( serializeJSON( sendResult ) );
        expect( structKeyExists( sendResult, "SENT_COUNT" ) ).toBeTrue( serializeJSON( sendResult ) );
        expect( countMonitoringRows( asset.floatPlanId ) ).toBe( 1, "sendResult=" & serializeJSON( sendResult ) & "; planState=" & serializeJSON( loadPlanState( asset.floatPlanId ) ) );
        monitoringRow = loadMonitoringRow( asset.floatPlanId );
        expect( monitoringRow.monitor_state ).toBe( "ACTIVE" );
        expect( monitoringRow.monitoring_mode ).toBe( "active_route" );
        expect( normalizeDbDateTime( monitoringRow.expected_checkin_at ) ).toBe( normalizeDbDateTime( loadPlanState( asset.floatPlanId ).departureTime ) );
        expect( normalizeDbDateTime( monitoringRow.next_monitor_eval_at ) ).toBe( normalizeDbDateTime( monitoringRow.expected_checkin_at ) );
        expect( countStartedRouteProgressRows( asset.floatPlanId ) ).toBe( 0 );
      } );

      it( "scheduled route monitoring does not reset an existing underway monitoring row", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "scheduled-preserve-underway" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern" );
        markPlanActive( asset.floatPlanId );
        ensureSuccess( variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" ), "start active_route monitor" );
        queryExecute(
          "UPDATE floatplan_monitoring
           SET last_checkin_at = UTC_TIMESTAMP(),
               last_checkin_status = 'ON_TRACK'
           WHERE float_plan_id = :floatPlanId",
          {
            floatPlanId = { value = asset.floatPlanId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = "fpw" }
        );
        var monitoringBefore = loadMonitoringRow( asset.floatPlanId );

        var scheduledResult = variables.monitorService.startScheduledRouteMonitoringForFloatPlan( asset.floatPlanId );
        var monitoringAfter = loadMonitoringRow( asset.floatPlanId );

        expect( scheduledResult.SUCCESS ).toBeTrue( serializeJSON( scheduledResult ) );
        expect( scheduledResult.SKIPPED ?: false ).toBeTrue( serializeJSON( scheduledResult ) );
        expect( countMonitoringRows( asset.floatPlanId ) ).toBe( 1 );
        expect( normalizeDbDateTime( monitoringAfter.expected_checkin_at ) ).toBe( normalizeDbDateTime( monitoringBefore.expected_checkin_at ) );
        expect( monitoringAfter.last_checkin_status ).toBe( "ON_TRACK" );
      } );

      it( "scheduled route monitoring follows the existing ACTIVE to LATE to MISSED evaluator rules", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "scheduled-evaluator" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern" );
        markPlanActive( asset.floatPlanId );
        ensureSuccess( variables.monitorService.startScheduledRouteMonitoringForFloatPlan( asset.floatPlanId ), "start scheduled route monitor" );

        updateMonitoringTimes( asset.floatPlanId, {
          monitor_state = "ACTIVE",
          expected_checkin_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 MINUTE)",
          grace_expires_at_sql = "DATE_ADD(UTC_TIMESTAMP(), INTERVAL 30 MINUTE)",
          next_monitor_eval_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE)"
        } );
        var lateResult = variables.monitorService.evaluateMonitoringCycle( asset.floatPlanId );
        var lateRow = loadMonitoringRow( asset.floatPlanId );

        updateMonitoringTimes( asset.floatPlanId, {
          monitor_state = "LATE",
          expected_checkin_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 120 MINUTE)",
          grace_expires_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE)",
          next_monitor_eval_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE)"
        } );
        var missedResult = variables.monitorService.evaluateMonitoringCycle( asset.floatPlanId );
        var missedRow = loadMonitoringRow( asset.floatPlanId );

        expect( lateResult.SUCCESS ).toBeTrue( serializeJSON( lateResult ) );
        expect( lateRow.monitor_state ).toBe( "LATE" );
        expect( missedResult.SUCCESS ).toBeTrue( serializeJSON( missedResult ) );
        expect( missedRow.monitor_state ).toBe( "MISSED" );
      } );

      it( "ACTIVE transitions to LATE after expected time passes but before grace expires", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "late" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern" );
        ensureSuccess( variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" ), "start active_route monitor" );
        updateMonitoringTimes( asset.floatPlanId, {
          monitor_state = "ACTIVE",
          expected_checkin_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 MINUTE)",
          grace_expires_at_sql = "DATE_ADD(UTC_TIMESTAMP(), INTERVAL 30 MINUTE)",
          next_monitor_eval_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE)"
        } );

        var evalResult = variables.monitorService.evaluateMonitoringCycle( asset.floatPlanId );
        var monitoringRow = loadMonitoringRow( asset.floatPlanId );
        var lateEvents = loadMonitoringEvents( asset.floatPlanId, "CHECKIN_LATE" );

        expect( evalResult.SUCCESS ).toBeTrue( serializeJSON( evalResult ) );
        expect( monitoringRow.monitor_state ).toBe( "LATE" );
        expect( lateEvents.recordCount ).toBe( 1 );
      } );

      it( "LATE transitions to MISSED after grace expires", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "missed" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern" );
        ensureSuccess( variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" ), "start active_route monitor" );
        updateMonitoringTimes( asset.floatPlanId, {
          monitor_state = "LATE",
          expected_checkin_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 120 MINUTE)",
          grace_expires_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE)",
          next_monitor_eval_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE)"
        } );

        var evalResult = variables.monitorService.evaluateMonitoringCycle( asset.floatPlanId );
        var monitoringRow = loadMonitoringRow( asset.floatPlanId );
        var missedEvents = loadMonitoringEvents( asset.floatPlanId, "CHECKIN_MISSED" );
        var captainAlertEvents = loadMonitoringEvents( asset.floatPlanId, "CAPTAIN_ALERTED" );

        expect( evalResult.SUCCESS ).toBeTrue( serializeJSON( evalResult ) );
        expect( monitoringRow.monitor_state ).toBe( "MISSED" );
        expect( isDate( monitoringRow.missed_at ) ).toBeTrue();
        expect( missedEvents.recordCount ).toBe( 1 );
        expect( captainAlertEvents.recordCount ).toBe( 1 );
      } );

      it( "MISSED transitions to ESCALATED after the escalation delay", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "escalated" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern" );
        ensureSuccess( variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" ), "start active_route monitor" );
        updateMonitoringTimes( asset.floatPlanId, {
          monitor_state = "MISSED",
          missed_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 121 MINUTE)",
          next_monitor_eval_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE)"
        } );

        var evalResult = variables.monitorService.evaluateMonitoringCycle( asset.floatPlanId );
        var monitoringRow = loadMonitoringRow( asset.floatPlanId );
        var contactAlertEvents = loadMonitoringEvents( asset.floatPlanId, "CONTACT_ALERTED" );

        expect( evalResult.SUCCESS ).toBeTrue( serializeJSON( evalResult ) );
        expect( monitoringRow.monitor_state ).toBe( "ESCALATED" );
        expect( isDate( monitoringRow.escalated_at ) ).toBeTrue();
        expect( contactAlertEvents.recordCount ).toBe( 1 );
      } );

      it( "a valid captain check-in resolves MISSED and returns the row to ACTIVE", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "resolve-missed" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern" );
        ensureSuccess( variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" ), "start active_route monitor" );
        updateMonitoringTimes( asset.floatPlanId, {
          monitor_state = "MISSED",
          missed_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 10 MINUTE)",
          last_captain_alert_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 10 MINUTE)",
          last_contact_alert_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 10 MINUTE)"
        } );

        var recordResult = variables.monitorService.recordMonitoringCheckin( asset.floatPlanId, "ON_TRACK" );
        var monitoringRow = loadMonitoringRow( asset.floatPlanId );
        var resolvedEvents = loadMonitoringEvents( asset.floatPlanId, "RESOLVED" );

        expect( recordResult.SUCCESS ).toBeTrue( serializeJSON( recordResult ) );
        expect( monitoringRow.monitor_state ).toBe( "ACTIVE" );
        expect( monitoringRow.last_checkin_status ).toBe( "ON_TRACK" );
        expect( isDate( monitoringRow.resolved_at ) ).toBeTrue();
        expect( len( trim( monitoringRow.missed_at & "" ) ) ).toBe( 0 );
        expect( len( trim( monitoringRow.escalated_at & "" ) ) ).toBe( 0 );
        expect( len( trim( monitoringRow.last_captain_alert_at & "" ) ) ).toBe( 0 );
        expect( len( trim( monitoringRow.last_contact_alert_at & "" ) ) ).toBe( 0 );
        expect( resolvedEvents.recordCount ).toBe( 1 );
      } );

      it( "a valid captain check-in resolves ESCALATED and returns the row to ACTIVE", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "resolve-escalated" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern" );
        ensureSuccess( variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" ), "start active_route monitor" );
        updateMonitoringTimes( asset.floatPlanId, {
          monitor_state = "ESCALATED",
          missed_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 150 MINUTE)",
          escalated_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 20 MINUTE)",
          last_captain_alert_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 20 MINUTE)",
          last_contact_alert_at_sql = "DATE_SUB(UTC_TIMESTAMP(), INTERVAL 20 MINUTE)"
        } );

        var recordResult = variables.monitorService.recordMonitoringCheckin( asset.floatPlanId, "DELAYED" );
        var monitoringRow = loadMonitoringRow( asset.floatPlanId );

        expect( recordResult.SUCCESS ).toBeTrue( serializeJSON( recordResult ) );
        expect( monitoringRow.monitor_state ).toBe( "ACTIVE" );
        expect( monitoringRow.last_checkin_status ).toBe( "DELAYED" );
        expect( isDate( monitoringRow.resolved_at ) ).toBeTrue();
        expect( len( trim( monitoringRow.missed_at & "" ) ) ).toBe( 0 );
        expect( len( trim( monitoringRow.escalated_at & "" ) ) ).toBe( 0 );
      } );

      it( "Assistance Needed Active Cruise check-in maps to NEED_ATTENTION and keeps monitoring ACTIVE", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "assistance-needed" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var asset = {};
        var checkinResult = {};
        var monitoringRow = {};
        var latestCheckinEvent = queryNew( "" );
        var assistanceAlertService = createObject( "component", "fpw.api.v1.OverdueAlertService" ).init();
        var assistanceRecipients = [];
        var assistanceAlertHistory = {};
        var streamRow = queryNew( "" );
        var bootstrapPayload = {};
        var heroPayload = {};
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern" );
          markPlanActive( asset.floatPlanId );
          ensureSuccess( variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" ), "start active_route monitor" );
          assistanceRecipients = assistanceAlertService.getRecipientEmails( asset.floatPlanId );

          checkinResult = postActiveCruiseCheckinWithApi(
            sessionApi,
            asset.floatPlanId,
            "Assistance Needed",
            "Need immediate support"
          );
          assistanceAlertHistory = assistanceAlertService.getHistory( asset.floatPlanId, "ASSISTANCE_NEEDED" );
          monitoringRow = loadMonitoringRow( asset.floatPlanId );
          heroPayload = createObject( "component", "fpw.api.v1.voyage" ).getActiveCruiseHeroCanonical(
            variables.sessionApiUser.userId,
            asset.floatPlanId
          );
          streamRow = queryExecute(
            "SELECT id, slug
             FROM voyage_streams
             WHERE floatplan_id = :floatPlanId
             ORDER BY id DESC
             LIMIT 1",
            {
              floatPlanId = { value = asset.floatPlanId, cfsqltype = "cf_sql_integer" }
            },
            { datasource = "fpw" }
          );
          bootstrapPayload = sessionApi.postJson( "/api/v1/voyage.cfc?method=handle&action=getStreamBootstrap", {
            stream_id = val( streamRow.id[ 1 ] ),
            slug = trim( toString( streamRow.slug[ 1 ] ) )
          } );
          latestCheckinEvent = queryExecute(
            "SELECT vp.title, vp.body
             FROM voyage_posts vp
             INNER JOIN voyage_streams vs ON vs.id = vp.stream_id
             WHERE vs.floatplan_id = :floatPlanId
               AND vp.event_type = 'checkin'
             ORDER BY vp.created_utc DESC, vp.id DESC
             LIMIT 1",
            {
              floatPlanId = { value = asset.floatPlanId, cfsqltype = "cf_sql_integer" }
            },
            { datasource = "fpw" }
          );

          expect( checkinResult.success ).toBeTrue( serializeJSON( checkinResult ) );
          expect( arrayLen( assistanceRecipients ) ).toBeGTE( 1 );
          expect( structKeyExists( checkinResult, "ALERT_SENT" ) ).toBeTrue( serializeJSON( checkinResult ) );
          expect( listFindNoCase( "SENT,FAILED", assistanceAlertHistory.status ) ).toBeGT( 0, serializeJSON( assistanceAlertHistory ) );
          expect( monitoringRow.monitor_state ).toBe( "ACTIVE" );
          expect( monitoringRow.last_checkin_status ).toBe( "NEED_ATTENTION" );
          expect( heroPayload.SUCCESS ).toBeTrue( serializeJSON( heroPayload ) );
          expect( trim( toString( heroPayload.heroVoyageStatus ?: "" ) ) ).toBe( "Assistance Needed" );
          expect( trim( toString( heroPayload.heroVoyageStatusVariant ?: "" ) ) ).toBe( "danger" );
          expect( streamRow.recordCount ).toBe( 1 );
          expect( bootstrapPayload.SUCCESS ).toBeTrue( serializeJSON( bootstrapPayload ) );
          expect( trim( toString( bootstrapPayload.topCards.voyage_progress_status ?: "" ) ) ).toBe( "Assistance Needed" );
          expect( trim( toString( bootstrapPayload.topCards.voyage_progress_status_variant ?: "" ) ) ).toBe( "danger" );
          expect( trim( toString( bootstrapPayload.body.voyage_progress_status_copy ?: "" ) ) ).toBe( "Latest check-in reported Assistance Needed." );
          expect( latestCheckinEvent.recordCount ).toBe( 1 );
          expect( trim( toString( latestCheckinEvent.title[ 1 ] ) ) ).toBe( "Check-in: Assistance Needed" );
          expect( trim( toString( latestCheckinEvent.body[ 1 ] ) ) ).toBe( "Need immediate support" );
        } finally {
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "Active Cruise hero uses canonical last check-in status for Delayed and Changed Plan warning states", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "hero-warning-statuses" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var asset = {};
        var delayedResult = {};
        var changedPlanResult = {};
        var delayedHero = {};
        var changedPlanHero = {};
        var monitoringRow = {};
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern" );
          markPlanActive( asset.floatPlanId );
          ensureSuccess( variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" ), "start active_route monitor" );

          delayedResult = postActiveCruiseCheckinWithApi( sessionApi, asset.floatPlanId, "Delayed" );
          delayedHero = createObject( "component", "fpw.api.v1.voyage" ).getActiveCruiseHeroCanonical(
            variables.sessionApiUser.userId,
            asset.floatPlanId
          );

          changedPlanResult = postActiveCruiseCheckinWithApi( sessionApi, asset.floatPlanId, "Changed Plan" );
          changedPlanHero = createObject( "component", "fpw.api.v1.voyage" ).getActiveCruiseHeroCanonical(
            variables.sessionApiUser.userId,
            asset.floatPlanId
          );
          monitoringRow = loadMonitoringRow( asset.floatPlanId );

          expect( delayedResult.success ).toBeTrue( serializeJSON( delayedResult ) );
          expect( delayedHero.SUCCESS ).toBeTrue( serializeJSON( delayedHero ) );
          expect( trim( toString( delayedHero.heroVoyageStatus ?: "" ) ) ).toBe( "Delayed" );
          expect( trim( toString( delayedHero.heroVoyageStatusVariant ?: "" ) ) ).toBe( "warning" );

          expect( changedPlanResult.success ).toBeTrue( serializeJSON( changedPlanResult ) );
          expect( changedPlanHero.SUCCESS ).toBeTrue( serializeJSON( changedPlanHero ) );
          expect( trim( toString( changedPlanHero.heroVoyageStatus ?: "" ) ) ).toBe( "Changed Plan" );
          expect( trim( toString( changedPlanHero.heroVoyageStatusVariant ?: "" ) ) ).toBe( "warning" );
          expect( monitoringRow.monitor_state ).toBe( "ACTIVE" );
          expect( monitoringRow.last_checkin_status ).toBe( "CHANGED_PLAN" );
        } finally {
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "pre-departure On Track initializes monitoring, starts route progress early, and succeeds", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "predeparture-ontrack" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var asset = {};
        var checkinResult = {};
        var monitoringRow = {};
        var futureDeparture = dateTimeFormat( dateAdd( "h", 3, now() ), "yyyy-mm-dd HH:nn:ss" );
        var futureReturn = dateTimeFormat( dateAdd( "h", 9, now() ), "yyyy-mm-dd HH:nn:ss" );
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          setPlanSchedule( asset.floatPlanId, futureDeparture, futureReturn, "UTC" );
          markPlanActive( asset.floatPlanId );
          deleteMonitoringRows( asset.floatPlanId );

          checkinResult = postActiveCruiseCheckinWithApi( sessionApi, asset.floatPlanId, "On Track" );
          monitoringRow = loadMonitoringRow( asset.floatPlanId );

          expect( checkinResult.success ).toBeTrue( serializeJSON( checkinResult ) );
          expect( countMonitoringRows( asset.floatPlanId ) ).toBe( 1 );
          expect( monitoringRow.monitor_state ).toBe( "ACTIVE" );
          expect( monitoringRow.last_checkin_status ).toBe( "ON_TRACK" );
          expect( countStartedRouteProgressRows( asset.floatPlanId ) ).toBeGT( 0 );
        } finally {
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "due scheduled On Track initializes monitoring, starts route progress by captain action, and succeeds", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "scheduled-due-ontrack" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var asset = {};
        var checkinResult = {};
        var monitoringRow = {};
        var pastDeparture = dateTimeFormat( dateAdd( "h", -1, now() ), "yyyy-mm-dd HH:nn:ss" );
        var futureReturn = dateTimeFormat( dateAdd( "h", 8, now() ), "yyyy-mm-dd HH:nn:ss" );
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          setPlanSchedule( asset.floatPlanId, pastDeparture, futureReturn, "UTC" );
          markPlanActive( asset.floatPlanId );
          deleteMonitoringRows( asset.floatPlanId );

          checkinResult = postActiveCruiseCheckinWithApi( sessionApi, asset.floatPlanId, "On Track" );
          monitoringRow = loadMonitoringRow( asset.floatPlanId );

          expect( checkinResult.success ).toBeTrue( serializeJSON( checkinResult ) );
          expect( countMonitoringRows( asset.floatPlanId ) ).toBe( 1 );
          expect( monitoringRow.monitor_state ).toBe( "ACTIVE" );
          expect( monitoringRow.last_checkin_status ).toBe( "ON_TRACK" );
          expect( countStartedRouteProgressRows( asset.floatPlanId ) ).toBeGT( 0 );
        } finally {
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "pre-departure status guardrails do not start route progress", function() {
        var statuses = [
          { label = "Delayed", error = "PRE_DEPARTURE_DELAY_REQUIRES_NEW_TIME" },
          { label = "Changed Plan", error = "PRE_DEPARTURE_PLAN_CHANGE_REQUIRES_UPDATE" },
          { label = "Secure for the Night", error = "PRE_DEPARTURE_SECURE_NOT_ALLOWED" }
        ];
        var statusCase = {};
        var sessionApi = buildSessionApiSupport();
        var localCreated = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var asset = {};
        var checkinResult = {};
        var futureDeparture = dateTimeFormat( dateAdd( "h", 3, now() ), "yyyy-mm-dd HH:nn:ss" );
        var futureReturn = dateTimeFormat( dateAdd( "h", 9, now() ), "yyyy-mm-dd HH:nn:ss" );
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";

        try {
          url.testUserId = variables.sessionApiUser.userId;
          for ( statusCase in statuses ) {
            asset = createRouteLinkedDraftForApi( sessionApi, variables.naming.buildPrefix( "float-plan-monitoring", "predeparture-" & lCase( replace( statusCase.label, " ", "-", "all" ) ) ), localCreated );
            setPlanSchedule( asset.floatPlanId, futureDeparture, futureReturn, "UTC" );
            markPlanActive( asset.floatPlanId );
            deleteMonitoringRows( asset.floatPlanId );

            checkinResult = postActiveCruiseCheckinWithApi( sessionApi, asset.floatPlanId, statusCase.label );

            expect( checkinResult.success ?: checkinResult.SUCCESS ?: false ).toBeFalse( serializeJSON( checkinResult ) );
            expect( trim( toString( checkinResult.ERROR ?: "" ) ) ).toBe( statusCase.error );
            expect( countMonitoringRows( asset.floatPlanId ) ).toBe( 1 );
            expect( countStartedRouteProgressRows( asset.floatPlanId ) ).toBe( 0 );
          }
        } finally {
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "pre-departure Assistance Needed initializes monitoring, preserves assistance handling, and does not start route progress", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "predeparture-assistance" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var asset = {};
        var checkinResult = {};
        var monitoringRow = {};
        var futureDeparture = dateTimeFormat( dateAdd( "h", 3, now() ), "yyyy-mm-dd HH:nn:ss" );
        var futureReturn = dateTimeFormat( dateAdd( "h", 9, now() ), "yyyy-mm-dd HH:nn:ss" );
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          setPlanSchedule( asset.floatPlanId, futureDeparture, futureReturn, "UTC" );
          markPlanActive( asset.floatPlanId );
          deleteMonitoringRows( asset.floatPlanId );

          checkinResult = postActiveCruiseCheckinWithApi( sessionApi, asset.floatPlanId, "Assistance Needed", "Need help before departure" );
          monitoringRow = loadMonitoringRow( asset.floatPlanId );

          expect( checkinResult.success ).toBeTrue( serializeJSON( checkinResult ) );
          expect( structKeyExists( checkinResult, "ALERT_SENT" ) ).toBeTrue( serializeJSON( checkinResult ) );
          expect( countMonitoringRows( asset.floatPlanId ) ).toBe( 1 );
          expect( monitoringRow.last_checkin_status ).toBe( "NEED_ATTENTION" );
          expect( countStartedRouteProgressRows( asset.floatPlanId ) ).toBe( 0 );
        } finally {
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "SECURE_FOR_NIGHT suppresses overnight late and missed escalation until the next 08:00 local checkpoint", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "secure-for-night" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern" );
        ensureSuccess( variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" ), "start active_route monitor" );

        var recordResult = variables.monitorService.recordMonitoringCheckin( asset.floatPlanId, "SECURE_FOR_NIGHT" );
        var monitoringRowBeforeEval = loadMonitoringRow( asset.floatPlanId );
        var evalResult = variables.monitorService.evaluateMonitoringCycle( asset.floatPlanId );
        var monitoringRowAfterEval = loadMonitoringRow( asset.floatPlanId );

        expect( recordResult.SUCCESS ).toBeTrue( serializeJSON( recordResult ) );
        expect( monitoringRowBeforeEval.monitor_state ).toBe( "ACTIVE" );
        expect( monitoringRowBeforeEval.secure_for_night ).toBeTrue();
        expect( right( toLocalStamp( monitoringRowBeforeEval.secure_for_night_until, "US/Eastern" ), 8 ) ).toBe( "08:00:00" );
        expect( evalResult.SUCCESS ).toBeTrue( serializeJSON( evalResult ) );
        expect( evalResult.REASON ).toBe( "OVERNIGHT_SUPPRESSED" );
        expect( monitoringRowAfterEval.monitor_state ).toBe( "ACTIVE" );
      } );

      it( "literal Secure for the Night Active Cruise status maps to SECURE_FOR_NIGHT and preserves overnight suppression", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "secure-for-night-literal-status" );
        var localSessionApiUser = {};
        var sessionApi = {};
        var localCreated = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var asset = {};
        var checkinResult = {};
        var monitoringRowBeforeEval = {};
        var secureEvents = queryNew( "" );
        var evalResult = {};
        var monitoringRowAfterEval = {};
        var planRow = {};
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";

        try {
          localSessionApiUser = createSessionApiUser();
          sessionApi = new fpw.tests.support.FpwApiSupport().init(
            baseUrl = variables.api.getBaseUrl(),
            authEmail = localSessionApiUser.email,
            authPassword = localSessionApiUser.password
          );
          url.testUserId = localSessionApiUser.userId;
          variables.entitlements.createAdminCompEntitlement(localSessionApiUser.userId);
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern" );
          markPlanActive( asset.floatPlanId );
          ensureSuccess( variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" ), "start active_route monitor" );

          checkinResult = postActiveCruiseCheckinWithApi( sessionApi, asset.floatPlanId, "Secure for the Night" );
          monitoringRowBeforeEval = loadMonitoringRow( asset.floatPlanId );
          secureEvents = loadMonitoringEvents( asset.floatPlanId, "SECURE_FOR_NIGHT_SET" );
          evalResult = variables.monitorService.evaluateMonitoringCycle( asset.floatPlanId );
          monitoringRowAfterEval = loadMonitoringRow( asset.floatPlanId );
          planRow = loadFloatPlanState( asset.floatPlanId );

          expect( checkinResult.success ).toBeTrue( serializeJSON( checkinResult ) );
          expect( monitoringRowBeforeEval.last_checkin_status ).toBe( "SECURE_FOR_NIGHT" );
          expect( monitoringRowBeforeEval.secure_for_night ).toBeTrue();
          expect( secureEvents.recordCount ).toBe( 1 );
          expect( planRow.checkin_context ).toBe( "overnight" );
          expect( evalResult.SUCCESS ).toBeTrue( serializeJSON( evalResult ) );
          expect( evalResult.REASON ).toBe( "OVERNIGHT_SUPPRESSED" );
          expect( monitoringRowAfterEval.monitor_state ).toBe( "ACTIVE" );
        } finally {
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
          if ( structKeyExists( localSessionApiUser, "userId" ) && val( localSessionApiUser.userId ) GT 0 ) {
            queryExecute(
              "DELETE FROM member_entitlements WHERE user_id = :userId",
              {
                userId = { value = localSessionApiUser.userId, cfsqltype = "cf_sql_integer" }
              },
              { datasource = "fpw" }
            );
          }
          cleanupApiUser( localSessionApiUser );
        }
      } );

      it( "ARRIVED is rejected as a regular monitoring check-in and requires the explicit final-close path", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "arrived-requires-close-path" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern" );
        ensureSuccess( variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" ), "start active_route monitor" );

        var recordResult = variables.monitorService.recordMonitoringCheckin( asset.floatPlanId, "ARRIVED" );
        var monitoringRow = loadMonitoringRow( asset.floatPlanId );

        expect( recordResult.SUCCESS ).toBeFalse( serializeJSON( recordResult ) );
        expect( recordResult.ERROR ).toBe( "FINAL_CLOSE_REQUIRED" );
        expect( monitoringRow.monitor_state ).toBe( "ACTIVE" );
      } );

      it( "ARRIVED through the explicit final-close path closes monitoring", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "close" );
        var asset = createRouteLinkedDraft( prefix );
        setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern" );
        ensureSuccess( variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" ), "start active_route monitor" );

        var closeResult = variables.monitorService.closeMonitoringForFloatPlan( asset.floatPlanId, "final_arrival" );
        var monitoringRow = loadMonitoringRow( asset.floatPlanId );
        var closeEvents = loadMonitoringEvents( asset.floatPlanId, "MONITORING_CLOSED" );

        expect( closeResult.SUCCESS ).toBeTrue( serializeJSON( closeResult ) );
        expect( monitoringRow.monitor_state ).toBe( "CLOSED" );
        expect( monitoringRow.is_monitoring_enabled ).toBeFalse();
        expect( len( trim( monitoringRow.next_monitor_eval_at & "" ) ) ).toBe( 0 );
        expect( closeEvents.recordCount ).toBe( 1 );
      } );

      it( "scheduler wrapper rejects missing and invalid tokens", function() {
        var missingTokenResult = callMonitoringSchedulerWrapper( "", 10 );
        var invalidTokenResult = callMonitoringSchedulerWrapper( "invalid-token", 10 );

        expect( missingTokenResult.SUCCESS ).toBeFalse( serializeJSON( missingTokenResult ) );
        expect( missingTokenResult.ERROR ).toBe( "UNAUTHORIZED" );
        expect( invalidTokenResult.SUCCESS ).toBeFalse( serializeJSON( invalidTokenResult ) );
        expect( invalidTokenResult.ERROR ).toBe( "UNAUTHORIZED" );
      } );

      it( "scheduler wrapper returns success with zero processed rows when nothing is due", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-monitoring", "scheduler-zero-due" );
        var asset = createRouteLinkedDraft( prefix );
        var suppressedDueRows = [];
        setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern" );
        ensureSuccess( variables.monitorService.startMonitoringForFloatPlan( asset.floatPlanId, "active_route" ), "start active_route monitor" );
        updateMonitoringTimes( asset.floatPlanId, {
          next_monitor_eval_at_sql = "DATE_ADD(UTC_TIMESTAMP(), INTERVAL 2 HOUR)"
        } );
        suppressedDueRows = suppressExternalDueRows( [ asset.floatPlanId ] );

        try {
          var schedulerResult = callMonitoringSchedulerWrapper( application.monitorToken, 10 );
          var monitoringRow = loadMonitoringRow( asset.floatPlanId );

          expect( schedulerResult.SUCCESS ).toBeTrue( serializeJSON( schedulerResult ) );
          expect( schedulerResult.PROCESSED_COUNT ).toBe( 0 );
          expect( arrayLen( schedulerResult.FLOAT_PLAN_IDS ) ).toBe( 0 );
          expect( monitoringRow.monitor_state ).toBe( "ACTIVE" );
        } finally {
          restoreSuppressedDueRows( suppressedDueRows );
        }
      } );

    } );
  }

  private struct function createRouteLinkedDraft( required string prefix ) {
    variables.cleanup.cleanupCurrentRouteFloatPlanGroup();
    var vesselPayload = variables.api.saveVessel( {
      vesselId = 0,
      vesselName = variables.naming.buildName( arguments.prefix, "Monitoring Vessel" ),
      type = "Cruiser",
      length = 34,
      color = "White"
    } );
    var vesselId = val( vesselPayload.VESSELID ?: 0 );
    var options = variables.api.routeBuilder( "routegen_getoptions", {
      template_code = "GULF-WEST",
      direction = "CCW"
    } );
    ensureSuccess( options, "load route template options" );
    var generate = variables.api.routeBuilder( "routegen_generate", {
      route_name = variables.naming.buildName( arguments.prefix, "Monitoring Route" ),
      template_code = "GULF-WEST",
      direction = "CCW",
      start_segment_id = options.DATA.startOptions[ 1 ].segment_id,
      end_segment_id = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].segment_id,
      start_location_label = options.DATA.startOptions[ 1 ].label,
      end_location_label = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].label,
      start_date = "2026-04-09",
      optional_stop_flags = [ "ship_island_out_and_back" ]
    } );
    var routeCode = trim( toString( generate.ROUTE_CODE ?: generate.DATA.route_code ?: "" ) );
    var buildPayload = variables.api.routeBuilder( "buildFloatPlansFromRoute", {
      routeCode = routeCode,
      mode = "DAILY",
      vesselId = vesselId,
      rebuild = 0
    } );
    ensureSuccess( vesselPayload, "save vessel" );
    ensureSuccess( generate, "generate route" );
    ensureSuccess( buildPayload, "build route-linked float plans" );
    var floatPlanId = val( buildPayload.FLOATPLAN_IDS[ 1 ] ?: 0 );
    expect( floatPlanId ).toBeGT( 0, serializeJSON( buildPayload ) );

    arrayAppend( variables.created.vesselIds, vesselId );
    arrayAppend( variables.created.routeCodes, routeCode );
    for ( var id in buildPayload.FLOATPLAN_IDS ) {
      arrayAppend( variables.created.floatPlanIds, val( id ) );
    }

    return {
      vesselId = vesselId,
      routeCode = routeCode,
      floatPlanId = floatPlanId
    };
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

  private void function updateMonitoringTimes( required numeric floatPlanId, required struct updates ) {
    var assignments = [];
    if ( structKeyExists( arguments.updates, "monitor_state" ) ) arrayAppend( assignments, "monitor_state = '#arguments.updates.monitor_state#'" );
    if ( structKeyExists( arguments.updates, "expected_checkin_at_sql" ) ) arrayAppend( assignments, "expected_checkin_at = " & arguments.updates.expected_checkin_at_sql );
    if ( structKeyExists( arguments.updates, "grace_expires_at_sql" ) ) arrayAppend( assignments, "grace_expires_at = " & arguments.updates.grace_expires_at_sql );
    if ( structKeyExists( arguments.updates, "missed_at_sql" ) ) arrayAppend( assignments, "missed_at = " & arguments.updates.missed_at_sql );
    if ( structKeyExists( arguments.updates, "escalated_at_sql" ) ) arrayAppend( assignments, "escalated_at = " & arguments.updates.escalated_at_sql );
    if ( structKeyExists( arguments.updates, "next_monitor_eval_at_sql" ) ) arrayAppend( assignments, "next_monitor_eval_at = " & arguments.updates.next_monitor_eval_at_sql );
    if ( structKeyExists( arguments.updates, "last_captain_alert_at_sql" ) ) arrayAppend( assignments, "last_captain_alert_at = " & arguments.updates.last_captain_alert_at_sql );
    if ( structKeyExists( arguments.updates, "last_contact_alert_at_sql" ) ) arrayAppend( assignments, "last_contact_alert_at = " & arguments.updates.last_contact_alert_at_sql );
    if ( !arrayLen( assignments ) ) return;
    queryExecute(
      "UPDATE floatplan_monitoring
       SET #arrayToList( assignments, ', ' )#
       WHERE float_plan_id = :floatPlanId",
      {
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

  private any function setFirstLegStartedAt(
    required numeric floatPlanId,
    required string startedLocal,
    required string timeZoneId
  ) {
    var qLeg = queryExecute(
      "SELECT fp.userId,
              fp.route_instance_id,
              MIN(rilp.leg_order) AS leg_order
       FROM floatplans fp
       INNER JOIN route_instance_leg_progress rilp
          ON rilp.route_instance_id = fp.route_instance_id
         AND rilp.user_id = fp.userId
       WHERE fp.floatplanId = :floatPlanId
       GROUP BY fp.userId, fp.route_instance_id",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    expect( qLeg.recordCount ).toBe( 1 );
    expect( val( qLeg.leg_order[ 1 ] ) ).toBeGT( 0 );
    queryExecute(
      "UPDATE route_instance_leg_progress
       SET status = 'STARTED',
           leg_started_at = CONVERT_TZ(:startedLocal, :timeZoneId, 'UTC'),
           completed_at = NULL
       WHERE route_instance_id = :routeInstanceId
         AND user_id = :userId
         AND leg_order = :legOrder",
      {
        startedLocal = { value = arguments.startedLocal, cfsqltype = "cf_sql_timestamp" },
        timeZoneId = { value = arguments.timeZoneId, cfsqltype = "cf_sql_varchar" },
        routeInstanceId = { value = val( qLeg.route_instance_id[ 1 ] ), cfsqltype = "cf_sql_integer" },
        userId = { value = val( qLeg.userId[ 1 ] ), cfsqltype = "cf_sql_integer" },
        legOrder = { value = val( qLeg.leg_order[ 1 ] ), cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    var qStarted = queryExecute(
      "SELECT leg_started_at
       FROM route_instance_leg_progress
       WHERE route_instance_id = :routeInstanceId
         AND user_id = :userId
         AND leg_order = :legOrder
       LIMIT 1",
      {
        routeInstanceId = { value = val( qLeg.route_instance_id[ 1 ] ), cfsqltype = "cf_sql_integer" },
        userId = { value = val( qLeg.userId[ 1 ] ), cfsqltype = "cf_sql_integer" },
        legOrder = { value = val( qLeg.leg_order[ 1 ] ), cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    expect( qStarted.recordCount ).toBe( 1 );
    expect( isDate( qStarted.leg_started_at[ 1 ] ) ).toBeTrue();
    return qStarted.leg_started_at[ 1 ];
  }

  private void function setMonitoringSecureForNight(
    required numeric floatPlanId,
    required string secureUntilLocal,
    required string timeZoneId
  ) {
    queryExecute(
      "UPDATE floatplan_monitoring
       SET secure_for_night = 1,
           secure_for_night_until = CONVERT_TZ(:secureUntilLocal, :timeZoneId, 'UTC'),
           expected_checkin_at = CONVERT_TZ(:secureUntilLocal, :timeZoneId, 'UTC'),
           grace_expires_at = DATE_ADD(CONVERT_TZ(:secureUntilLocal, :timeZoneId, 'UTC'), INTERVAL grace_window_minutes MINUTE),
           next_monitor_eval_at = CONVERT_TZ(:secureUntilLocal, :timeZoneId, 'UTC')
       WHERE float_plan_id = :floatPlanId",
      {
        secureUntilLocal = { value = arguments.secureUntilLocal, cfsqltype = "cf_sql_timestamp" },
        timeZoneId = { value = arguments.timeZoneId, cfsqltype = "cf_sql_varchar" },
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private struct function loadMonitoringRow( required numeric floatPlanId ) {
    var qRow = queryExecute(
      "SELECT
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
          next_monitor_eval_at,
          last_monitor_eval_at,
          last_captain_alert_at,
          last_contact_alert_at
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
      monitoring_mode = trim( toString( qRow.monitoring_mode[ 1 ] ) ),
      monitor_state = trim( toString( qRow.monitor_state[ 1 ] ) ),
      is_monitoring_enabled = val( qRow.is_monitoring_enabled[ 1 ] ) NEQ 0,
      expected_checkin_at = isNull( qRow.expected_checkin_at[ 1 ] ) ? "" : qRow.expected_checkin_at[ 1 ],
      grace_expires_at = isNull( qRow.grace_expires_at[ 1 ] ) ? "" : qRow.grace_expires_at[ 1 ],
      missed_at = isNull( qRow.missed_at[ 1 ] ) ? "" : qRow.missed_at[ 1 ],
      escalated_at = isNull( qRow.escalated_at[ 1 ] ) ? "" : qRow.escalated_at[ 1 ],
      resolved_at = isNull( qRow.resolved_at[ 1 ] ) ? "" : qRow.resolved_at[ 1 ],
      closed_at = isNull( qRow.closed_at[ 1 ] ) ? "" : qRow.closed_at[ 1 ],
      last_checkin_at = isNull( qRow.last_checkin_at[ 1 ] ) ? "" : qRow.last_checkin_at[ 1 ],
      last_checkin_status = isNull( qRow.last_checkin_status[ 1 ] ) ? "" : trim( toString( qRow.last_checkin_status[ 1 ] ) ),
      secure_for_night = val( qRow.secure_for_night[ 1 ] ) NEQ 0,
      secure_for_night_until = isNull( qRow.secure_for_night_until[ 1 ] ) ? "" : qRow.secure_for_night_until[ 1 ],
      next_monitor_eval_at = isNull( qRow.next_monitor_eval_at[ 1 ] ) ? "" : qRow.next_monitor_eval_at[ 1 ],
      last_monitor_eval_at = isNull( qRow.last_monitor_eval_at[ 1 ] ) ? "" : qRow.last_monitor_eval_at[ 1 ],
      last_captain_alert_at = isNull( qRow.last_captain_alert_at[ 1 ] ) ? "" : qRow.last_captain_alert_at[ 1 ],
      last_contact_alert_at = isNull( qRow.last_contact_alert_at[ 1 ] ) ? "" : qRow.last_contact_alert_at[ 1 ]
    };
  }

  private numeric function countMonitoringRows( required numeric floatPlanId ) {
    var qCount = queryExecute(
      "SELECT COUNT(*) AS row_count
       FROM floatplan_monitoring
       WHERE float_plan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    return val( qCount.row_count[ 1 ] );
  }

  private struct function loadPlanState( required numeric floatPlanId ) {
    var qPlan = queryExecute(
      "SELECT floatplanId,
              userId,
              `status`,
              route_instance_id,
              departureTime,
              returnTime
       FROM floatplans
       WHERE floatplanId = :floatPlanId
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    if ( qPlan.recordCount EQ 0 ) {
      return { exists = false };
    }
    return {
      exists = true,
      floatPlanId = val( qPlan.floatplanId[ 1 ] ),
      userId = val( qPlan.userId[ 1 ] ),
      status = trim( toString( qPlan.status[ 1 ] ) ),
      routeInstanceId = isNull( qPlan.route_instance_id[ 1 ] ) ? 0 : val( qPlan.route_instance_id[ 1 ] ),
      departureTime = isNull( qPlan.departureTime[ 1 ] ) ? "" : qPlan.departureTime[ 1 ],
      returnTime = isNull( qPlan.returnTime[ 1 ] ) ? "" : qPlan.returnTime[ 1 ]
    };
  }

  private numeric function countStartedRouteProgressRows( required numeric floatPlanId ) {
    var qCount = queryExecute(
      "SELECT COUNT(*) AS row_count
       FROM floatplans fp
       INNER JOIN route_instance_leg_progress rilp
          ON rilp.route_instance_id = fp.route_instance_id
         AND rilp.user_id = fp.userId
       WHERE fp.floatplanId = :floatPlanId
         AND (
             rilp.leg_started_at IS NOT NULL
             OR rilp.completed_at IS NOT NULL
             OR UPPER(TRIM(rilp.status)) = 'COMPLETED'
         )",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    return val( qCount.row_count[ 1 ] );
  }

  private query function loadMonitoringEvents( required numeric floatPlanId, string eventType = "" ) {
    if ( len( arguments.eventType ) ) {
      return queryExecute(
        "SELECT event_type, from_state, to_state, checkin_status
         FROM floatplan_monitor_events
         WHERE float_plan_id = :floatPlanId
           AND event_type = :eventType
         ORDER BY id ASC",
        {
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
          eventType = { value = arguments.eventType, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = "fpw" }
      );
    }
    return queryExecute(
      "SELECT event_type, from_state, to_state, checkin_status
       FROM floatplan_monitor_events
       WHERE float_plan_id = :floatPlanId
       ORDER BY id ASC",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private struct function loadFloatPlanState( required numeric floatPlanId ) {
    var qRow = queryExecute(
      "SELECT checkin_context
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
      checkin_context = isNull( qRow.checkin_context[ 1 ] ) ? "" : trim( toString( qRow.checkin_context[ 1 ] ) )
    };
  }

  private string function toLocalStamp( required any utcDateTime, required string timeZoneId ) {
    if ( !isDate( arguments.utcDateTime ) ) {
      return "";
    }
    var qLocal = queryExecute(
      "SELECT CONVERT_TZ(:utcDateTime, 'UTC', :timeZoneId) AS localDateTime",
      {
        utcDateTime = { value = arguments.utcDateTime, cfsqltype = "cf_sql_timestamp" },
        timeZoneId = { value = arguments.timeZoneId, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    if ( qLocal.recordCount EQ 0 OR isNull( qLocal.localDateTime[ 1 ] ) ) {
      return "";
    }
    return dateTimeFormat( qLocal.localDateTime[ 1 ], "yyyy-mm-dd HH:nn:ss" );
  }

  private string function normalizeDbDateTime( required any value ) {
    if ( !isDate( arguments.value ) ) {
      return "";
    }
    return dateTimeFormat( arguments.value, "yyyy-mm-dd HH:nn:ss" );
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

  private array function suppressExternalDueRows( array keepFloatPlanIds = [] ) {
    var keepLookup = {};
    var qRows = queryExecute(
      "SELECT id, float_plan_id, next_monitor_eval_at
       FROM floatplan_monitoring
       WHERE is_monitoring_enabled = 1
         AND monitor_state <> 'CLOSED'
         AND next_monitor_eval_at IS NOT NULL
         AND next_monitor_eval_at <= UTC_TIMESTAMP()
       ORDER BY next_monitor_eval_at ASC, id ASC",
      {},
      { datasource = "fpw" }
    );
    var suppressed = [];
    var i = 0;
    var floatPlanId = 0;

    for ( floatPlanId in arguments.keepFloatPlanIds ) {
      keepLookup[ toString( val( floatPlanId ) ) ] = true;
    }

    for ( i = 1; i LTE qRows.recordCount; i++ ) {
      floatPlanId = val( qRows.float_plan_id[ i ] );
      if ( structKeyExists( keepLookup, toString( floatPlanId ) ) ) {
        continue;
      }
      arrayAppend( suppressed, {
        id = val( qRows.id[ i ] ),
        next_monitor_eval_at = qRows.next_monitor_eval_at[ i ]
      } );
      queryExecute(
        "UPDATE floatplan_monitoring
         SET next_monitor_eval_at = DATE_ADD(UTC_TIMESTAMP(), INTERVAL 4 HOUR)
         WHERE id = :monitoringId",
        {
          monitoringId = { value = val( qRows.id[ i ] ), cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
    }

    return suppressed;
  }

  private void function restoreSuppressedDueRows( required array suppressedRows ) {
    var i = 0;
    var row = {};

    for ( i = 1; i LTE arrayLen( arguments.suppressedRows ); i++ ) {
      row = arguments.suppressedRows[ i ];
      queryExecute(
        "UPDATE floatplan_monitoring
         SET next_monitor_eval_at = :nextMonitorEvalAt
         WHERE id = :monitoringId",
        {
          nextMonitorEvalAt = { value = row.next_monitor_eval_at, cfsqltype = "cf_sql_timestamp" },
          monitoringId = { value = row.id, cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
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

  private void function ensureSuccess( required struct payload, required string label ) {
    if ( !structKeyExists( arguments.payload, "SUCCESS" ) OR arguments.payload.SUCCESS NEQ true ) {
      throw( message = "Monitoring test setup failed: " & arguments.label, detail = serializeJSON( arguments.payload ) );
    }
  }

  private struct function callMonitoringSchedulerWrapper( string token = "", numeric limit = 100 ) {
    var httpResult = {};
    var endpoint = variables.api.getBaseUrl() & "/api/v1/monitor.cfc?method=runMonitoringEvaluator&limit=" & arguments.limit;
    if ( len( arguments.token ) ) {
      endpoint &= "&token=" & urlEncodedFormat( arguments.token );
    }
    cfhttp( url = endpoint, method = "get", result = "httpResult", charset = "utf-8" ) {}
    expect( structKeyExists( httpResult, "fileContent" ) ).toBeTrue();
    return deserializeJSON( trim( httpResult.fileContent ) );
  }

  private struct function postActiveCruiseCheckin( required numeric floatPlanId, required string statusValue, string note = "" ) {
    return variables.api.postJson( "/api/v1/floatplan.cfc?method=handle&action=checkin", {
      floatPlanId = arguments.floatPlanId,
      status = arguments.statusValue,
      note = arguments.note
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
    var uniqueEmail = "fpw-assistance-" & replace( createUUID(), "-", "", "all" ) & "@example.com";
    var payload = signupApi.postJson( "/api/v1/join.cfc?method=handle", {
      firstName = "FPW",
      lastName = "Assistance",
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
    cleanupApiUser( variables.sessionApiUser );
  }

  private void function cleanupApiUser( any apiUser = {} ) {
    var userId = 0;

    if ( !isStruct( arguments.apiUser ) ) {
      return;
    }

    userId = val( arguments.apiUser.userId ?: 0 );
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
      vesselName = variables.naming.buildName( arguments.prefix, "Monitoring Vessel" ),
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
      route_name = variables.naming.buildName( arguments.prefix, "Monitoring Route" ),
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

  private struct function postActiveCruiseCheckinWithApi( required any apiSupport, required numeric floatPlanId, required string statusValue, string note = "" ) {
    return arguments.apiSupport.postJson( "/api/v1/floatplan.cfc?method=handle&action=checkin", {
      floatPlanId = arguments.floatPlanId,
      status = arguments.statusValue,
      note = arguments.note
    } );
  }
}
