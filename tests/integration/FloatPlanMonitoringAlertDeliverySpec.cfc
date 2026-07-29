component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.api = new fpw.tests.support.FpwApiSupport().init(
      authEmail = 'detroit@email.com',
      authPassword = 'changeIt'
    );
    variables.naming = new fpw.tests.support.FpwNamingSupport();
    variables.monitorService = new fpw.api.v1.monitor().init();
    variables.entitlements = new fpw.api.v1.MemberEntitlementService().init( 'fpw' );
    variables.hadOriginalTestUserId = structKeyExists( url, 'testUserId' );
    variables.originalTestUserId = variables.hadOriginalTestUserId ? url.testUserId : '';
    variables.hadOriginalSessionUser = structKeyExists( session, 'user' );
    variables.originalSessionUser = ( variables.hadOriginalSessionUser && isStruct( session.user ) ) ? duplicate( session.user ) : {};
    variables.sessionApiUser = createSessionApiUser();
    url.testUserId = variables.sessionApiUser.userId;
    setMonitoringSessionUser( variables.sessionApiUser.userId );
    variables.api = buildSessionApiSupport( variables.sessionApiUser );
  }

  function afterAll() {
    cleanupSessionApiUser( variables.sessionApiUser );
    if ( variables.hadOriginalTestUserId ) {
      url.testUserId = variables.originalTestUserId;
    } else {
      structDelete( url, 'testUserId', false );
    }
    restoreMonitoringSessionUser();
  }

  function run() {
    describe( 'Float plan monitoring alert delivery', function() {
      it( 'MISSED sends once to the owner/captain and repeated evaluator runs do not duplicate the same cycle alert', function() {
        var prefix = variables.naming.buildPrefix( 'float-plan-monitoring', 'missed-owner-alert' );
        var localCreated = { vesselIds = [], routeCodes = [], floatPlanIds = [], contactIds = [] };
        var asset = {};
        var startResult = {};
        var firstEval = {};
        var secondEval = {};
        var monitoringRow = {};
        var captainAlertEvents = queryNew( '' );
        var historyRows = queryNew( '' );

        try {
          asset = createRouteLinkedDraftForApi( variables.api, prefix, localCreated );
          setPlanSchedule( asset.floatPlanId, '2026-04-09 09:00:00', '2026-04-10 20:00:00', 'US/Eastern' );
          ensureSuccess( startActiveRouteMonitoringWithStartProof( asset.floatPlanId ), 'start active_route monitor' );

          expect( countSelectedContacts( asset.floatPlanId ) ).toBe( 0 );

          updateMonitoringTimes( asset.floatPlanId, {
            monitor_state = 'LATE',
            expected_checkin_at_sql = 'DATE_SUB(UTC_TIMESTAMP(), INTERVAL 120 MINUTE)',
            grace_expires_at_sql = 'DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE)',
            next_monitor_eval_at_sql = 'DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE)'
          } );

          firstEval = variables.monitorService.evaluateMonitoringCycle( asset.floatPlanId );
          secondEval = variables.monitorService.evaluateMonitoringCycle( asset.floatPlanId );
          monitoringRow = loadMonitoringRow( asset.floatPlanId );
          captainAlertEvents = loadMonitoringEvents( asset.floatPlanId, 'CAPTAIN_ALERTED' );
          historyRows = loadAlertHistoryRows( asset.floatPlanId, 'MISSED_OWNER_' );

          expect( firstEval.SUCCESS ).toBeTrue( serializeJSON( firstEval ) );
          expect( secondEval.SUCCESS ).toBeTrue( serializeJSON( secondEval ) );
          expect( monitoringRow.monitor_state ).toBe( 'MISSED' );
          expect( isDate( monitoringRow.last_captain_alert_at ) ).toBeTrue();
          expect( captainAlertEvents.recordCount ).toBe( 1 );
          expect( historyRows.recordCount ).toBe( 1 );
          expect( trim( toString( historyRows.status[ 1 ] ) ) ).toBe( 'SENT' );
          expect( val( historyRows.attemptCount[ 1 ] ) ).toBe( 1 );
        } finally {
          cleanupRouteLinkedAssetsForApi( variables.api, localCreated );
          cleanupContactsForApi( variables.api, localCreated.contactIds );
        }
      } );

      it( 'recovery and a later missed cycle send a new owner/captain alert', function() {
        var prefix = variables.naming.buildPrefix( 'float-plan-monitoring', 'missed-owner-repeat-cycle' );
        var localCreated = { vesselIds = [], routeCodes = [], floatPlanIds = [], contactIds = [] };
        var asset = {};
        var firstEval = {};
        var recoveryResult = {};
        var secondEval = {};
        var historyRows = queryNew( '' );

        try {
          asset = createRouteLinkedDraftForApi( variables.api, prefix, localCreated );
          setPlanSchedule( asset.floatPlanId, '2026-04-09 09:00:00', '2026-04-10 20:00:00', 'US/Eastern' );
          ensureSuccess( startActiveRouteMonitoringWithStartProof( asset.floatPlanId ), 'start active_route monitor' );

          updateMonitoringTimes( asset.floatPlanId, {
            monitor_state = 'LATE',
            expected_checkin_at_sql = 'DATE_SUB(UTC_TIMESTAMP(), INTERVAL 120 MINUTE)',
            grace_expires_at_sql = 'DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE)',
            next_monitor_eval_at_sql = 'DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE)'
          } );

          firstEval = variables.monitorService.evaluateMonitoringCycle( asset.floatPlanId );
          expect( firstEval.SUCCESS ).toBeTrue( serializeJSON( firstEval ) );
          expect( loadAlertHistoryRows( asset.floatPlanId, 'MISSED_OWNER_' ).recordCount ).toBe( 1 );

          recoveryResult = variables.monitorService.recordMonitoringCheckin( asset.floatPlanId, 'ON_TRACK' );
          expect( recoveryResult.SUCCESS ).toBeTrue( serializeJSON( recoveryResult ) );

          pauseForNextCycle();

          updateMonitoringTimes( asset.floatPlanId, {
            monitor_state = 'LATE',
            expected_checkin_at_sql = 'DATE_SUB(UTC_TIMESTAMP(), INTERVAL 120 MINUTE)',
            grace_expires_at_sql = 'DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE)',
            next_monitor_eval_at_sql = 'DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE)'
          } );

          secondEval = variables.monitorService.evaluateMonitoringCycle( asset.floatPlanId );
          historyRows = loadAlertHistoryRows( asset.floatPlanId, 'MISSED_OWNER_' );

          expect( secondEval.SUCCESS ).toBeTrue( serializeJSON( secondEval ) );
          expect( historyRows.recordCount ).toBe( 2 );
          expect( trim( toString( historyRows.status[ 1 ] ) ) ).toBe( 'SENT' );
          expect( trim( toString( historyRows.status[ 2 ] ) ) ).toBe( 'SENT' );
          expect( trim( toString( historyRows.alertType[ 1 ] ) ) ).notToBe( trim( toString( historyRows.alertType[ 2 ] ) ) );
        } finally {
          cleanupRouteLinkedAssetsForApi( variables.api, localCreated );
          cleanupContactsForApi( variables.api, localCreated.contactIds );
        }
      } );

      it( 'ESCALATED sends once to selected contacts without owner fallback', function() {
        var prefix = variables.naming.buildPrefix( 'float-plan-monitoring', 'escalated-selected-contacts' );
        var localCreated = { vesselIds = [], routeCodes = [], floatPlanIds = [], contactIds = [] };
        var sessionUser = {};
        var sessionApi = '';
        var asset = {};
        var selectedContact = {};
        var firstEval = {};
        var secondEval = {};
        var monitoringRow = {};
        var contactAlertEvents = queryNew( '' );
        var historyRows = queryNew( '' );

        try {
          sessionUser = createSessionApiUser();
          sessionApi = buildSessionApiSupport( sessionUser );
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          setPlanSchedule( asset.floatPlanId, '2026-04-09 09:00:00', '2026-04-10 20:00:00', 'US/Eastern' );
          ensureSuccess( startActiveRouteMonitoringWithStartProof( asset.floatPlanId ), 'start active_route monitor' );

          selectedContact = createSelectedContactForApi( sessionApi, asset.floatPlanId, prefix, localCreated.contactIds );
          expect( countSelectedContacts( asset.floatPlanId ) ).toBe( 1 );

          updateUserEmail( sessionUser.userId, '' );
          updateMonitoringTimes( asset.floatPlanId, {
            monitor_state = 'MISSED',
            missed_at_sql = 'DATE_SUB(UTC_TIMESTAMP(), INTERVAL 121 MINUTE)',
            next_monitor_eval_at_sql = 'DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE)'
          } );

          firstEval = variables.monitorService.evaluateMonitoringCycle( asset.floatPlanId );
          secondEval = variables.monitorService.evaluateMonitoringCycle( asset.floatPlanId );
          monitoringRow = loadMonitoringRow( asset.floatPlanId );
          contactAlertEvents = loadMonitoringEvents( asset.floatPlanId, 'CONTACT_ALERTED' );
          historyRows = loadAlertHistoryRows( asset.floatPlanId, 'ESCALATED_CONTACTS_' );

          expect( firstEval.SUCCESS ).toBeTrue( serializeJSON( firstEval ) );
          expect( secondEval.SUCCESS ).toBeTrue( serializeJSON( secondEval ) );
          expect( monitoringRow.monitor_state ).toBe( 'ESCALATED' );
          expect( isDate( monitoringRow.last_contact_alert_at ) ).toBeTrue();
          expect( contactAlertEvents.recordCount ).toBe( 1 );
          expect( historyRows.recordCount ).toBe( 1 );
          expect( trim( toString( historyRows.status[ 1 ] ) ) ).toBe( 'SENT' );
          expect( val( historyRows.attemptCount[ 1 ] ) ).toBe( 1 );
          expect( trim( toString( selectedContact.email ) ) ).notToBe( '' );
        } finally {
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
          cleanupContactsForApi( sessionApi, localCreated.contactIds );
          cleanupSessionApiUser( sessionUser );
        }
      } );

      it( 'ESCALATED without selected contacts records FAILED history and does not fallback to owner', function() {
        var prefix = variables.naming.buildPrefix( 'float-plan-monitoring', 'escalated-no-contacts' );
        var localCreated = { vesselIds = [], routeCodes = [], floatPlanIds = [], contactIds = [] };
        var sessionUser = {};
        var sessionApi = '';
        var asset = {};
        var firstEval = {};
        var secondEval = {};
        var historyRows = queryNew( '' );
        var contactAlertEvents = queryNew( '' );

        try {
          sessionUser = createSessionApiUser();
          sessionApi = buildSessionApiSupport( sessionUser );
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          setPlanSchedule( asset.floatPlanId, '2026-04-09 09:00:00', '2026-04-10 20:00:00', 'US/Eastern' );
          ensureSuccess( startActiveRouteMonitoringWithStartProof( asset.floatPlanId ), 'start active_route monitor' );

          updateUserEmail( sessionUser.userId, '' );
          updateMonitoringTimes( asset.floatPlanId, {
            monitor_state = 'MISSED',
            missed_at_sql = 'DATE_SUB(UTC_TIMESTAMP(), INTERVAL 121 MINUTE)',
            next_monitor_eval_at_sql = 'DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE)'
          } );

          firstEval = variables.monitorService.evaluateMonitoringCycle( asset.floatPlanId );
          secondEval = variables.monitorService.evaluateMonitoringCycle( asset.floatPlanId );
          historyRows = loadAlertHistoryRows( asset.floatPlanId, 'ESCALATED_CONTACTS_' );
          contactAlertEvents = loadMonitoringEvents( asset.floatPlanId, 'CONTACT_ALERTED' );

          expect( firstEval.SUCCESS ).toBeTrue( serializeJSON( firstEval ) );
          expect( secondEval.SUCCESS ).toBeTrue( serializeJSON( secondEval ) );
          expect( contactAlertEvents.recordCount ).toBe( 1 );
          expect( historyRows.recordCount ).toBe( 1 );
          expect( trim( toString( historyRows.status[ 1 ] ) ) ).toBe( 'FAILED' );
          expect( val( historyRows.attemptCount[ 1 ] ) ).toBe( 1 );
          expect( findNoCase( 'No selected contact emails found', trim( toString( historyRows.lastError[ 1 ] ) ) ) ).toBeGT( 0 );
        } finally {
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
          cleanupContactsForApi( sessionApi, localCreated.contactIds );
          cleanupSessionApiUser( sessionUser );
        }
      } );
    } );
  }

  private void function pauseForNextCycle() {
    queryExecute( 'SELECT SLEEP(1) AS waited', {}, { datasource = 'fpw' } );
  }

  private query function loadAlertHistoryRows( required numeric floatPlanId, required string alertTypePrefix ) {
    return queryExecute(
      'SELECT id, alertType, status, attemptCount, lastError, sentAtUTC, lastAttemptAtUTC
       FROM floatplan_alert_history
       WHERE floatPlanId = :floatPlanId
         AND alertType LIKE :alertTypePrefix
       ORDER BY id ASC',
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = 'cf_sql_integer' },
        alertTypePrefix = { value = arguments.alertTypePrefix & '%', cfsqltype = 'cf_sql_varchar' }
      },
      { datasource = 'fpw' }
    );
  }

  private numeric function countSelectedContacts( required numeric floatPlanId ) {
    var qCount = queryExecute(
      'SELECT COUNT(*) AS totalCount
       FROM floatplan_contacts
       WHERE floatPlanId = :floatPlanId',
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = 'cf_sql_integer' }
      },
      { datasource = 'fpw' }
    );
    return qCount.recordCount EQ 1 ? val( qCount.totalCount[ 1 ] ) : 0;
  }

  private struct function createSelectedContactForApi( required any apiSupport, required numeric floatPlanId, required string prefix, required array contactIds ) {
    var uniqueSuffix = lCase( replace( createUUID(), '-', '', 'all' ) );
    var email = left( reReplace( arguments.prefix, '[^A-Za-z0-9]+', '-', 'all' ), 40 ) & '-contact-' & left( uniqueSuffix, 10 ) & '@example.com';
    var payload = arguments.apiSupport.saveContact( {
      contactId = 0,
      name = 'Monitoring Contact ' & left( uniqueSuffix, 6 ),
      phone = '555-0101',
      email = email
    } );
    var contactId = val( payload.CONTACTID ?: 0 );

    ensureSuccess( payload, 'save contact' );
    expect( contactId ).toBeGT( 0, serializeJSON( payload ) );

    queryExecute(
      'INSERT INTO floatplan_contacts ( floatPlanId, contactId )
       VALUES ( :floatPlanId, :contactId )',
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = 'cf_sql_integer' },
        contactId = { value = contactId, cfsqltype = 'cf_sql_integer' }
      },
      { datasource = 'fpw' }
    );

    arrayAppend( arguments.contactIds, contactId );

    return {
      contactId = contactId,
      email = email
    };
  }

  private void function cleanupContactsForApi( any apiSupport = '', array contactIds = [] ) {
    var cleanupSupport = '';
    var i = 0;

    if ( !isObject( arguments.apiSupport ) || !arrayLen( arguments.contactIds ) ) {
      return;
    }

    cleanupSupport = new fpw.tests.support.FpwCleanupSupport().init( arguments.apiSupport );
    for ( i = arrayLen( arguments.contactIds ); i GTE 1; i-- ) {
      try {
        cleanupSupport.cleanupContact( arguments.contactIds[ i ] );
      } catch ( any ignoredCleanup ) {}
    }
  }

  private void function updateUserEmail( required numeric userId, required string email ) {
    queryExecute(
      'UPDATE users
       SET email = :email
       WHERE userId = :userId',
      {
        email = { value = arguments.email, cfsqltype = 'cf_sql_varchar' },
        userId = { value = arguments.userId, cfsqltype = 'cf_sql_integer' }
      },
      { datasource = 'fpw' }
    );
  }

  private void function setPlanSchedule(
    required numeric floatPlanId,
    required string departureLocal,
    required string returnLocal,
    required string timeZoneId
  ) {
    queryExecute(
      'UPDATE floatplans
       SET departureTime = CONVERT_TZ(:departureLocal, :timeZoneId, ''UTC''),
           departTimezone = :timeZoneId,
           departureTZ = :timeZoneId,
           returnTime = CONVERT_TZ(:returnLocal, :timeZoneId, ''UTC''),
           returnTimezone = :timeZoneId,
           returnTZ = :timeZoneId,
           activatedAt = NULL,
           checkedInAt = NULL,
           checkin_context = NULL,
           closedAt = NULL,
           lastUpdateStatus = UTC_TIMESTAMP(),
           status = ''DRAFT''
       WHERE floatPlanId = :floatPlanId',
      {
        departureLocal = { value = arguments.departureLocal, cfsqltype = 'cf_sql_timestamp' },
        returnLocal = { value = arguments.returnLocal, cfsqltype = 'cf_sql_timestamp' },
        timeZoneId = { value = arguments.timeZoneId, cfsqltype = 'cf_sql_varchar' },
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = 'cf_sql_integer' }
      },
      { datasource = 'fpw' }
    );
    deleteMonitoringRows( arguments.floatPlanId );
  }

  private struct function startActiveRouteMonitoringWithStartProof( required numeric floatPlanId ) {
    var startedUtc = setFirstLegStartedAtFromPlanSchedule( arguments.floatPlanId );
    return variables.monitorService.startMonitoringForFloatPlan( arguments.floatPlanId, 'active_route', {
      baseAt = startedUtc
    } );
  }

  private any function setFirstLegStartedAtFromPlanSchedule( required numeric floatPlanId ) {
    var qLeg = queryExecute(
      'SELECT fp.userId,
              fp.route_instance_id,
              COALESCE(fp.departureTimeUTC, fp.departureTime) AS start_at,
              MIN(rilp.leg_order) AS leg_order
       FROM floatplans fp
       INNER JOIN route_instance_leg_progress rilp
          ON rilp.route_instance_id = fp.route_instance_id
         AND rilp.user_id = fp.userId
       WHERE fp.floatplanId = :floatPlanId
       GROUP BY fp.userId, fp.route_instance_id, fp.departureTimeUTC, fp.departureTime',
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = 'cf_sql_integer' }
      },
      { datasource = 'fpw' }
    );
    var startedUtc = '';

    expect( qLeg.recordCount ).toBe( 1 );
    expect( val( qLeg.leg_order[ 1 ] ) ).toBeGT( 0 );
    expect( isDate( qLeg.start_at[ 1 ] ) ).toBeTrue( serializeJSON( qLeg ) );
    startedUtc = qLeg.start_at[ 1 ];

    queryExecute(
      'UPDATE route_instance_leg_progress
       SET status = CASE
               WHEN UPPER(TRIM(COALESCE(status, ''''))) = ''NOT_STARTED'' THEN ''STARTED''
               ELSE status
           END,
           leg_started_at = COALESCE(leg_started_at, :startedUtc)
       WHERE route_instance_id = :routeInstanceId
         AND user_id = :userId
         AND leg_order = :legOrder',
      {
        startedUtc = { value = startedUtc, cfsqltype = 'cf_sql_timestamp' },
        routeInstanceId = { value = val( qLeg.route_instance_id[ 1 ] ), cfsqltype = 'cf_sql_integer' },
        userId = { value = val( qLeg.userId[ 1 ] ), cfsqltype = 'cf_sql_integer' },
        legOrder = { value = val( qLeg.leg_order[ 1 ] ), cfsqltype = 'cf_sql_integer' }
      },
      { datasource = 'fpw' }
    );
    queryExecute(
      'UPDATE route_instances
       SET status = CASE
               WHEN UPPER(TRIM(COALESCE(status, ''''))) = ''PLANNED'' THEN ''ACTIVE''
               ELSE status
           END,
           started_at = COALESCE(started_at, :startedUtc)
       WHERE id = :routeInstanceId
         AND user_id = :userId',
      {
        startedUtc = { value = startedUtc, cfsqltype = 'cf_sql_timestamp' },
        routeInstanceId = { value = val( qLeg.route_instance_id[ 1 ] ), cfsqltype = 'cf_sql_integer' },
        userId = { value = val( qLeg.userId[ 1 ] ), cfsqltype = 'cf_sql_integer' }
      },
      { datasource = 'fpw' }
    );

    return startedUtc;
  }

  private void function updateMonitoringTimes( required numeric floatPlanId, required struct updates ) {
    var assignments = [];
    if ( structKeyExists( arguments.updates, 'monitor_state' ) ) arrayAppend( assignments, 'monitor_state = ''' & arguments.updates.monitor_state & '''' );
    if ( structKeyExists( arguments.updates, 'expected_checkin_at_sql' ) ) arrayAppend( assignments, 'expected_checkin_at = ' & arguments.updates.expected_checkin_at_sql );
    if ( structKeyExists( arguments.updates, 'grace_expires_at_sql' ) ) arrayAppend( assignments, 'grace_expires_at = ' & arguments.updates.grace_expires_at_sql );
    if ( structKeyExists( arguments.updates, 'missed_at_sql' ) ) arrayAppend( assignments, 'missed_at = ' & arguments.updates.missed_at_sql );
    if ( structKeyExists( arguments.updates, 'escalated_at_sql' ) ) arrayAppend( assignments, 'escalated_at = ' & arguments.updates.escalated_at_sql );
    if ( structKeyExists( arguments.updates, 'next_monitor_eval_at_sql' ) ) arrayAppend( assignments, 'next_monitor_eval_at = ' & arguments.updates.next_monitor_eval_at_sql );
    if ( structKeyExists( arguments.updates, 'last_captain_alert_at_sql' ) ) arrayAppend( assignments, 'last_captain_alert_at = ' & arguments.updates.last_captain_alert_at_sql );
    if ( structKeyExists( arguments.updates, 'last_contact_alert_at_sql' ) ) arrayAppend( assignments, 'last_contact_alert_at = ' & arguments.updates.last_contact_alert_at_sql );
    if ( !arrayLen( assignments ) ) {
      return;
    }
    queryExecute(
      'UPDATE floatplan_monitoring
       SET #arrayToList( assignments, ', ' )#
       WHERE float_plan_id = :floatPlanId',
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = 'cf_sql_integer' }
      },
      { datasource = 'fpw' }
    );
  }

  private struct function loadMonitoringRow( required numeric floatPlanId ) {
    var qRow = queryExecute(
      'SELECT
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
       LIMIT 1',
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = 'cf_sql_integer' }
      },
      { datasource = 'fpw' }
    );
    expect( qRow.recordCount ).toBe( 1 );
    return {
      monitoring_mode = trim( toString( qRow.monitoring_mode[ 1 ] ) ),
      monitor_state = trim( toString( qRow.monitor_state[ 1 ] ) ),
      is_monitoring_enabled = val( qRow.is_monitoring_enabled[ 1 ] ) NEQ 0,
      expected_checkin_at = isNull( qRow.expected_checkin_at[ 1 ] ) ? '' : qRow.expected_checkin_at[ 1 ],
      grace_expires_at = isNull( qRow.grace_expires_at[ 1 ] ) ? '' : qRow.grace_expires_at[ 1 ],
      missed_at = isNull( qRow.missed_at[ 1 ] ) ? '' : qRow.missed_at[ 1 ],
      escalated_at = isNull( qRow.escalated_at[ 1 ] ) ? '' : qRow.escalated_at[ 1 ],
      resolved_at = isNull( qRow.resolved_at[ 1 ] ) ? '' : qRow.resolved_at[ 1 ],
      closed_at = isNull( qRow.closed_at[ 1 ] ) ? '' : qRow.closed_at[ 1 ],
      last_checkin_at = isNull( qRow.last_checkin_at[ 1 ] ) ? '' : qRow.last_checkin_at[ 1 ],
      last_checkin_status = isNull( qRow.last_checkin_status[ 1 ] ) ? '' : trim( toString( qRow.last_checkin_status[ 1 ] ) ),
      secure_for_night = val( qRow.secure_for_night[ 1 ] ) NEQ 0,
      secure_for_night_until = isNull( qRow.secure_for_night_until[ 1 ] ) ? '' : qRow.secure_for_night_until[ 1 ],
      next_monitor_eval_at = isNull( qRow.next_monitor_eval_at[ 1 ] ) ? '' : qRow.next_monitor_eval_at[ 1 ],
      last_monitor_eval_at = isNull( qRow.last_monitor_eval_at[ 1 ] ) ? '' : qRow.last_monitor_eval_at[ 1 ],
      last_captain_alert_at = isNull( qRow.last_captain_alert_at[ 1 ] ) ? '' : qRow.last_captain_alert_at[ 1 ],
      last_contact_alert_at = isNull( qRow.last_contact_alert_at[ 1 ] ) ? '' : qRow.last_contact_alert_at[ 1 ]
    };
  }

  private query function loadMonitoringEvents( required numeric floatPlanId, string eventType = '' ) {
    if ( len( arguments.eventType ) ) {
      return queryExecute(
        'SELECT event_type, from_state, to_state, checkin_status
         FROM floatplan_monitor_events
         WHERE float_plan_id = :floatPlanId
           AND event_type = :eventType
         ORDER BY id ASC',
        {
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = 'cf_sql_integer' },
          eventType = { value = arguments.eventType, cfsqltype = 'cf_sql_varchar' }
        },
        { datasource = 'fpw' }
      );
    }
    return queryExecute(
      'SELECT event_type, from_state, to_state, checkin_status
       FROM floatplan_monitor_events
       WHERE float_plan_id = :floatPlanId
       ORDER BY id ASC',
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = 'cf_sql_integer' }
      },
      { datasource = 'fpw' }
    );
  }

  private void function deleteMonitoringRows( required numeric floatPlanId ) {
    queryExecute(
      'DELETE FROM floatplan_alert_history WHERE floatPlanId = :floatPlanId',
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = 'cf_sql_integer' }
      },
      { datasource = 'fpw' }
    );
    queryExecute(
      'DELETE FROM floatplan_monitor_events WHERE float_plan_id = :floatPlanId',
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = 'cf_sql_integer' }
      },
      { datasource = 'fpw' }
    );
    queryExecute(
      'DELETE FROM floatplan_monitoring WHERE float_plan_id = :floatPlanId',
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = 'cf_sql_integer' }
      },
      { datasource = 'fpw' }
    );
  }

  private void function forceDeleteFloatPlanRecords( required numeric floatPlanId ) {
    deleteMonitoringRows( arguments.floatPlanId );
    queryExecute(
      'DELETE FROM floatplan_passengers WHERE floatPlanId = :floatPlanId',
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = 'cf_sql_integer' }
      },
      { datasource = 'fpw' }
    );
    queryExecute(
      'DELETE FROM floatplan_contacts WHERE floatPlanId = :floatPlanId',
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = 'cf_sql_integer' }
      },
      { datasource = 'fpw' }
    );
    queryExecute(
      'DELETE FROM floatplan_waypoints WHERE floatPlanId = :floatPlanId',
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = 'cf_sql_integer' }
      },
      { datasource = 'fpw' }
    );
    queryExecute(
      'DELETE FROM floatplans WHERE floatPlanId = :floatPlanId',
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = 'cf_sql_integer' }
      },
      { datasource = 'fpw' }
    );
  }

  private void function ensureSuccess( required struct payload, required string label ) {
    if ( !structKeyExists( arguments.payload, 'SUCCESS' ) || arguments.payload.SUCCESS NEQ true ) {
      throw( message = 'Monitoring alert delivery test setup failed: ' & arguments.label, detail = serializeJSON( arguments.payload ) );
    }
  }

  private struct function buildSessionApiSupport( required struct sessionUser ) {
    return new fpw.tests.support.FpwApiSupport().init(
      baseUrl = variables.api.getBaseUrl(),
      authEmail = arguments.sessionUser.email,
      authPassword = arguments.sessionUser.password
    );
  }

  private struct function createSessionApiUser() {
    var signupApi = new fpw.tests.support.FpwApiSupport().init(
      baseUrl = variables.api.getBaseUrl()
    );
    var uniqueEmail = 'fpw-monitoring-' & replace( createUUID(), '-', '', 'all' ) & '@example.com';
    var payload = signupApi.postJson( '/api/v1/join.cfc?method=handle', {
      firstName = 'FPW',
      lastName = 'Monitoring',
      email = uniqueEmail,
      password = 'changeIt',
      confirmPassword = 'changeIt',
      termsAccepted = true
    }, false );

    expect( payload.SUCCESS ).toBeTrue( serializeJSON( payload ) );
    expect( val( payload.USERID ?: 0 ) ).toBeGT( 0, serializeJSON( payload ) );
    variables.entitlements.createAdminCompEntitlement( val( payload.USERID ) );

    return {
      userId = val( payload.USERID ),
      email = uniqueEmail,
      password = 'changeIt'
    };
  }

  private void function cleanupSessionApiUser( struct sessionUser = {} ) {
    var userId = 0;

    if ( !isStruct( arguments.sessionUser ) || !structKeyExists( arguments.sessionUser, 'userId' ) ) {
      return;
    }

    userId = val( arguments.sessionUser.userId );
    if ( userId LTE 0 ) {
      return;
    }

    queryExecute(
      'DELETE FROM member_entitlements WHERE user_id = :userId',
      {
        userId = { value = userId, cfsqltype = 'cf_sql_integer' }
      },
      { datasource = 'fpw' }
    );
    queryExecute(
      'DELETE FROM users_address WHERE userId = :userId',
      {
        userId = { value = userId, cfsqltype = 'cf_sql_integer' }
      },
      { datasource = 'fpw' }
    );
    queryExecute(
      'DELETE FROM users WHERE userId = :userId',
      {
        userId = { value = userId, cfsqltype = 'cf_sql_integer' }
      },
      { datasource = 'fpw' }
    );
  }

  private struct function createRouteLinkedDraftForApi( required any apiSupport, required string prefix, required struct created ) {
    url.testUserId = variables.sessionApiUser.userId;
    setMonitoringSessionUser( variables.sessionApiUser.userId );
    var vesselPayload = arguments.apiSupport.saveVessel( {
      vesselId = 0,
      vesselName = variables.naming.buildName( arguments.prefix, 'Monitoring Vessel' ),
      type = 'Cruiser',
      length = 34,
      color = 'White'
    } );
    var vesselId = val( vesselPayload.VESSELID ?: 0 );
    var options = arguments.apiSupport.routeBuilder( 'routegen_getoptions', {
      template_code = 'GULF-WEST',
      direction = 'CCW'
    } );

    ensureSuccess( vesselPayload, 'save vessel' );
    ensureSuccess( options, 'load route template options' );

    var generate = arguments.apiSupport.routeBuilder( 'routegen_generate', {
      route_name = variables.naming.buildName( arguments.prefix, 'Monitoring Route' ),
      template_code = 'GULF-WEST',
      direction = 'CCW',
      start_segment_id = options.DATA.startOptions[ 1 ].segment_id,
      end_segment_id = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].segment_id,
      start_location_label = options.DATA.startOptions[ 1 ].label,
      end_location_label = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].label,
      start_date = '2026-04-09',
      optional_stop_flags = [ 'ship_island_out_and_back' ]
    } );
    ensureSuccess( generate, 'generate route' );

    var routeCode = trim( toString( generate.ROUTE_CODE ?: generate.DATA.route_code ?: '' ) );
    var buildPayload = arguments.apiSupport.routeBuilder( 'buildFloatPlansFromRoute', {
      routeCode = routeCode,
      mode = 'DAILY',
      vesselId = vesselId,
      rebuild = 0
    } );
    ensureSuccess( buildPayload, 'build route-linked float plans' );

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

  private void function setMonitoringSessionUser( required numeric userId ) {
    if ( !structKeyExists( session, 'user' ) || !isStruct( session.user ) ) {
      session.user = {};
    }
    session.user.userId = arguments.userId;
    session.user.id = arguments.userId;
    session.user.USERID = arguments.userId;
  }

  private void function restoreMonitoringSessionUser() {
    if ( variables.hadOriginalSessionUser ) {
      session.user = variables.originalSessionUser;
    } else {
      structDelete( session, 'user', false );
    }
  }

  private void function cleanupRouteLinkedAssetsForApi( any apiSupport = '', struct created = {} ) {
    var cleanupSupport = '';
    var i = 0;
    var j = 0;
    var k = 0;

    if ( !isObject( arguments.apiSupport ) || !isStruct( arguments.created ) ) {
      return;
    }

    cleanupSupport = new fpw.tests.support.FpwCleanupSupport().init( arguments.apiSupport );

    for ( i = arrayLen( arguments.created.floatPlanIds ?: [] ); i GTE 1; i-- ) {
      try {
        cleanupSupport.cleanupFloatPlan( arguments.created.floatPlanIds[ i ] );
      } catch ( any ignoredFloatPlanCleanup ) {}
      forceDeleteFloatPlanRecords( arguments.created.floatPlanIds[ i ] );
    }
    for ( j = arrayLen( arguments.created.routeCodes ?: [] ); j GTE 1; j-- ) {
      try {
        cleanupSupport.cleanupRoute( arguments.created.routeCodes[ j ] );
      } catch ( any ignoredRouteCleanup ) {}
    }
    for ( k = arrayLen( arguments.created.vesselIds ?: [] ); k GTE 1; k-- ) {
      try {
        cleanupSupport.cleanupVessel( arguments.created.vesselIds[ k ] );
      } catch ( any ignoredVesselCleanup ) {}
    }
  }
}
