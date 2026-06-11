component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    var baseUrl = "";
    variables.api = new fpw.tests.support.FpwApiSupport().init();
    baseUrl = variables.api.getBaseUrl();
    variables.sessionApiUser = createSessionApiUser( baseUrl );
    url.testUserId = variables.sessionApiUser.userId;
    variables.api = new fpw.tests.support.FpwApiSupport().init(
      baseUrl = baseUrl,
      authEmail = variables.sessionApiUser.email,
      authPassword = variables.sessionApiUser.password
    );
    variables.naming = new fpw.tests.support.FpwNamingSupport();
    variables.cleanup = new fpw.tests.support.FpwCleanupSupport();
    variables.cleanup.init( variables.api );
    variables.created = {
      vesselId = 0,
      operatorId = 0,
      contactId = 0,
      floatPlanIds = [],
      routeCodes = []
    };
  }

  function afterAll() {
    try {
      variables.cleanup.cleanupCurrentRouteFloatPlanGroup( variables.sessionApiUser.userId );
    } catch ( any ignoredCurrentGroupCleanup ) {}
    for ( var j = arrayLen( variables.created.routeCodes ); j GTE 1; j-- ) {
      try {
        variables.cleanup.cleanupRoute( variables.created.routeCodes[ j ] );
      } catch ( any ignoredRouteCleanup ) {}
    }
    for ( var i = arrayLen( variables.created.floatPlanIds ); i GTE 1; i-- ) {
      try {
        variables.cleanup.cleanupFloatPlan( variables.created.floatPlanIds[ i ] );
      } catch ( any ignoredFloatPlanCleanup ) {}
    }
    if ( variables.created.contactId GT 0 ) variables.cleanup.cleanupContact( variables.created.contactId );
    if ( variables.created.operatorId GT 0 ) variables.cleanup.cleanupOperator( variables.created.operatorId );
    if ( variables.created.vesselId GT 0 ) variables.cleanup.cleanupVessel( variables.created.vesselId );
    structDelete( url, "testUserId", false );
    cleanupSessionApiUser();
  }

  function run() {
    describe( "Float plan lifecycle contracts", function() {
      it( "enforces route-backed activation, blocks active route delete, and preserves CLOSED history after final close", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-lifecycle", "route-backed-activation-close" );
        var bootstrap = variables.api.bootstrapFloatPlan();
        var routePlan = {};
        var activationPayload = {};
        var activeRouteDeletePayload = {};
        var activeRouteDeleteError = {};
        var closePayload = {};
        var closedBootstrap = {};
        var planState = {};
        var qLegs = queryNew( "" );
        var finalLegOrder = 0;

        variables.created.vesselId = createVessel( prefix );
        variables.created.operatorId = createOperator( prefix );
        variables.created.contactId = createContact( prefix );

        expect( bootstrap.SUCCESS ).toBeTrue( serializeJSON( bootstrap ) );
        expect( structKeyExists( bootstrap, "FLOATPLAN" ) ).toBeTrue();

        routePlan = createRouteLinkedDraftPlan( prefix & "-route-a" );
        activationPayload = variables.api.sendFloatPlan( routePlan.planId );
        expect( activationPayload.SUCCESS ).toBeTrue( serializeJSON( activationPayload ) );

        var activeBootstrap = variables.api.bootstrapFloatPlan( routePlan.planId );
        expect( uCase( trim( toString( activeBootstrap.FLOATPLAN.STATUS ?: "" ) ) ) ).toBe( "ACTIVE" );

        activeRouteDeletePayload = variables.api.routeBuilder( "deleteRoute", { routeCode = routePlan.routeCode } );
        expect( activeRouteDeletePayload.SUCCESS ).toBeFalse( serializeJSON( activeRouteDeletePayload ) );
        expect( trim( toString( activeRouteDeletePayload.MESSAGE ?: "" ) ) ).toBe( "Route is attached to an active float plan." );
        activeRouteDeleteError = isStruct( activeRouteDeletePayload.ERROR ?: "" ) ? activeRouteDeletePayload.ERROR : {};
        expect( trim( toString( activeRouteDeleteError.CODE ?: "" ) ) ).toBe( "ACTIVE_ROUTE_DELETE_BLOCKED" );
        expect( trim( toString( activeRouteDeleteError.MESSAGE ?: "" ) ) ).toBe( "End the active route/float-plan group through Close or Cancel before deleting this route." );

        var conflictingOptions = variables.api.routeBuilder( "routegen_getoptions", {
          template_code = "GULF-WEST",
          direction = "CCW"
        } );
        var conflictingGenerate = variables.api.routeBuilder( "routegen_generate", {
          route_name = variables.naming.buildName( prefix & "-route-b", "Lifecycle Route" ),
          template_code = "GULF-WEST",
          direction = "CCW",
          start_segment_id = conflictingOptions.DATA.startOptions[ 1 ].segment_id,
          end_segment_id = conflictingOptions.DATA.endOptions[ arrayLen( conflictingOptions.DATA.endOptions ) ].segment_id,
          start_location_label = conflictingOptions.DATA.startOptions[ 1 ].label,
          end_location_label = conflictingOptions.DATA.endOptions[ arrayLen( conflictingOptions.DATA.endOptions ) ].label,
          start_date = dateFormat( dateAdd( "d", 2, now() ), "yyyy-mm-dd" ),
          optional_stop_flags = [ "ship_island_out_and_back" ]
        } );
        var conflictingRouteCode = trim( toString( conflictingGenerate.ROUTE_CODE ?: conflictingGenerate.DATA.route_code ?: "" ) );

        expect( conflictingOptions.SUCCESS ).toBeTrue( serializeJSON( conflictingOptions ) );
        expect( conflictingGenerate.SUCCESS ).toBeTrue( serializeJSON( conflictingGenerate ) );
        arrayAppend( variables.created.routeCodes, conflictingRouteCode );

        conflictingActivationPayload = variables.api.routeBuilder( "buildFloatPlansFromRoute", {
          routeCode = conflictingRouteCode,
          mode = "DAILY",
          vesselId = variables.created.vesselId,
          rebuild = 0
        } );
        expect( conflictingActivationPayload.SUCCESS ).toBeFalse( serializeJSON( conflictingActivationPayload ) );
        expect( trim( toString( conflictingActivationPayload.ERROR.CODE ?: "" ) ) ).toBe( "ACTIVE_GROUP_EXISTS" );
        expect( val( conflictingActivationPayload.EXISTING_FLOATPLANID ?: 0 ) ).toBe( routePlan.planId );

        planState = loadRoutePlanState( routePlan.planId );
        qLegs = loadRouteLegOrders( planState.route_instance_id );
        expect( qLegs.recordCount ).toBeGT( 0 );
        finalLegOrder = val( qLegs.leg_order[ qLegs.recordCount ] );
        ensureOpenMonitoringRow( routePlan.planId, planState.user_id );
        clearRouteProgress( planState.user_id, planState.route_instance_id );
        seedStartedLeg( planState.user_id, planState.route_instance_id, finalLegOrder );

        closePayload = variables.api.checkinFloatPlan( routePlan.planId );
        expect( closePayload.SUCCESS ).toBeTrue( serializeJSON( closePayload ) );
        expect( uCase( trim( toString( closePayload.STATUS ?: "" ) ) ) ).toBe( "CLOSED" );

        closedBootstrap = variables.api.bootstrapFloatPlan( routePlan.planId );
        expect( uCase( trim( toString( closedBootstrap.FLOATPLAN.STATUS ?: "" ) ) ) ).toBe( "CLOSED" );
      } );

      it( "allows route deletion once the attached float plan is no longer active", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-lifecycle", "historical-route-delete" );
        var routePlan = {};
        var planState = {};
        var qLegs = queryNew( "" );
        var finalLegOrder = 0;
        var activationPayload = {};
        var closePayload = {};
        var closedBootstrap = {};
        var historicalRouteDeletePayload = {};
        var deletePayload = {};
        var routeIdx = 0;

        if ( variables.created.vesselId LTE 0 ) variables.created.vesselId = createVessel( prefix );
        if ( variables.created.operatorId LTE 0 ) variables.created.operatorId = createOperator( prefix );
        if ( variables.created.contactId LTE 0 ) variables.created.contactId = createContact( prefix );

        routePlan = createRouteLinkedDraftPlan( prefix & "-route" );
        activationPayload = variables.api.sendFloatPlan( routePlan.planId );
        expect( activationPayload.SUCCESS ).toBeTrue( serializeJSON( activationPayload ) );

        planState = loadRoutePlanState( routePlan.planId );
        qLegs = loadRouteLegOrders( planState.route_instance_id );
        expect( qLegs.recordCount ).toBeGT( 0 );
        finalLegOrder = val( qLegs.leg_order[ qLegs.recordCount ] );
        ensureOpenMonitoringRow( routePlan.planId, planState.user_id );
        clearRouteProgress( planState.user_id, planState.route_instance_id );
        seedStartedLeg( planState.user_id, planState.route_instance_id, finalLegOrder );

        closePayload = variables.api.checkinFloatPlan( routePlan.planId );
        expect( closePayload.SUCCESS ).toBeTrue( serializeJSON( closePayload ) );
        expect( uCase( trim( toString( closePayload.STATUS ?: "" ) ) ) ).toBe( "CLOSED" );

        closedBootstrap = variables.api.bootstrapFloatPlan( routePlan.planId );
        expect( uCase( trim( toString( closedBootstrap.FLOATPLAN.STATUS ?: "" ) ) ) ).toBe( "CLOSED" );

        historicalRouteDeletePayload = variables.api.routeBuilder( "deleteRoute", { routeCode = routePlan.routeCode } );
        expect( historicalRouteDeletePayload.SUCCESS ).toBeTrue( serializeJSON( historicalRouteDeletePayload ) );
        routeIdx = arrayFind( variables.created.routeCodes, routePlan.routeCode );
        if ( routeIdx GT 0 ) {
          arrayDeleteAt( variables.created.routeCodes, routeIdx );
        }
        forgetCreatedPlanId( routePlan.planId );
      } );

      it( "rejects route-linked active close attempts when route progress is not in a closable state", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-lifecycle", "no-monitor-close-blocked" );
        var routePlan = {};
        var closePayload = {};

        if ( variables.created.vesselId LTE 0 ) variables.created.vesselId = createVessel( prefix );
        if ( variables.created.operatorId LTE 0 ) variables.created.operatorId = createOperator( prefix );
        if ( variables.created.contactId LTE 0 ) variables.created.contactId = createContact( prefix );

        routePlan = createRouteLinkedDraftPlan( prefix & "-route" );

        try {
          markPlanActive( routePlan.planId );
          deleteMonitoringRows( routePlan.planId );

          closePayload = variables.api.checkinFloatPlan( routePlan.planId );
          expect( closePayload.SUCCESS ).toBeFalse( serializeJSON( closePayload ) );
          expect( trim( toString( closePayload.ERROR ?: "" ) ) ).toBe( "CLOSE_TRIP_BLOCKED" );
          expect( len( trim( toString( closePayload.MESSAGE ?: "" ) ) ) ).toBeGT( 0 );
        } finally {
          deleteMonitoringRows( routePlan.planId );
          restorePlanToDraft( routePlan.planId );
        }
      } );
    } );
  }

  private numeric function createVessel( required string prefix ) {
    return val( variables.api.saveVessel( {
      vesselId = 0,
      vesselName = variables.naming.buildName( prefix, "Lifecycle Vessel" ),
      type = "Cruiser",
      length = 36,
      color = "White"
    } ).VESSELID ?: 0 );
  }

  private numeric function createOperator( required string prefix ) {
    return val( variables.api.saveOperator( {
      operatorId = 0,
      name = variables.naming.buildName( prefix, "Lifecycle Operator" )
    } ).OPERATORID ?: 0 );
  }

  private numeric function createContact( required string prefix ) {
    return val( variables.api.saveContact( {
      contactId = 0,
      name = variables.naming.buildName( prefix, "Lifecycle Contact" ),
      phone = "5555551212",
      email = variables.naming.buildEmail( prefix, "lifecycle-contact" )
    } ).CONTACTID ?: 0 );
  }

  private numeric function saveDraftPlan( required string prefix, required boolean includeContact ) {
    var contactSelections = arguments.includeContact ? [ { CONTACTID = variables.created.contactId, SORT_ORDER = 1 } ] : [];
    var departureTime = buildDateTimeLocal( 2, 9 );
    var returnTime = buildDateTimeLocal( 2, 18 );
    var savePayload = variables.api.saveFloatPlan( {
      FLOATPLANID = 0,
      NAME = variables.naming.buildName( prefix, includeContact ? "Blocked Route-less Draft" : "Blocked Draft" ),
      VESSELID = variables.created.vesselId,
      OPERATORID = variables.created.operatorId,
      DEPARTING_FROM = "Lifecycle Dock",
      DEPARTURE_TIME = departureTime,
      DEPARTURE_TIMEZONE = "America/New_York",
      RETURNING_TO = "Lifecycle Dock",
      RETURN_TIME = returnTime,
      RETURN_TIMEZONE = "America/New_York",
      EMAIL = includeContact ? variables.naming.buildEmail( prefix, "underway" ) : "",
      RESCUE_AUTHORITY = "USCG",
      RESCUE_AUTHORITY_PHONE = "5555551212"
    }, [], contactSelections, [] );
    return val( savePayload.FLOATPLAN.FLOATPLANID ?: savePayload.FLOATPLANID ?: 0 );
  }

  private struct function createRouteLinkedDraftPlan( required string prefix ) {
    variables.cleanup.cleanupCurrentRouteFloatPlanGroup( variables.sessionApiUser.userId );
    var options = variables.api.routeBuilder( "routegen_getoptions", {
      template_code = "GULF-WEST",
      direction = "CCW"
    } );
    var generate = {};
    var routeCode = "";
    var buildPayload = {};
    var planId = 0;
    var routeLink = {};
    var savePayload = {};
    var departureTime = buildDateTimeLocal( 2, 9 );
    var returnTime = buildDateTimeLocal( 2, 18 );

    expect( options.SUCCESS ).toBeTrue( serializeJSON( options ) );

    generate = variables.api.routeBuilder( "routegen_generate", {
      route_name = variables.naming.buildName( prefix, "Lifecycle Route" ),
      template_code = "GULF-WEST",
      direction = "CCW",
      start_segment_id = options.DATA.startOptions[ 1 ].segment_id,
      end_segment_id = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].segment_id,
      start_location_label = options.DATA.startOptions[ 1 ].label,
      end_location_label = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].label,
      start_date = dateFormat( dateAdd( "d", 2, now() ), "yyyy-mm-dd" ),
      optional_stop_flags = [ "ship_island_out_and_back" ]
    } );
    expect( generate.SUCCESS ).toBeTrue( serializeJSON( generate ) );

    routeCode = trim( toString( generate.ROUTE_CODE ?: generate.DATA.route_code ?: "" ) );
    buildPayload = variables.api.routeBuilder( "buildFloatPlansFromRoute", {
      routeCode = routeCode,
      mode = "DAILY",
      vesselId = variables.created.vesselId,
      rebuild = 0
    } );
    expect( buildPayload.SUCCESS ).toBeTrue( serializeJSON( buildPayload ) );

    planId = val( buildPayload.FLOATPLAN_IDS[ 1 ] ?: 0 );
    expect( planId ).toBeGT( 0, serializeJSON( buildPayload ) );

    arrayAppend( variables.created.routeCodes, routeCode );
    for ( var id in buildPayload.FLOATPLAN_IDS ) {
      rememberCreatedPlanId( val( id ) );
    }

    routeLink = loadRouteLink( planId );
    saveRouteLinkedDraftPlan( planId, prefix );

    return {
      planId = planId,
      routeCode = routeCode,
      routeInstanceId = routeLink.route_instance_id
    };
  }

  private void function saveRouteLinkedDraftPlan( required numeric planId, required string prefix ) {
    var routeLink = loadRouteLink( arguments.planId );
    var departureTime = buildDateTimeLocal( 2, 9 );
    var returnTime = buildDateTimeLocal( 2, 18 );
    var savePayload = variables.api.saveFloatPlan( {
      FLOATPLANID = arguments.planId,
      NAME = variables.naming.buildName( arguments.prefix, "Route-backed Draft" ),
      VESSELID = variables.created.vesselId,
      OPERATORID = variables.created.operatorId,
      DEPARTING_FROM = "Lifecycle Dock",
      DEPARTURE_TIME = departureTime,
      DEPARTURE_TIMEZONE = "UTC",
      DEPARTURE_TIME_UTC = departureTime,
      RETURNING_TO = "Lifecycle Dock",
      RETURN_TIME = returnTime,
      RETURN_TIMEZONE = "UTC",
      RETURN_TIME_UTC = returnTime,
      EMAIL = variables.naming.buildEmail( arguments.prefix, "route-underway" ),
      RESCUE_AUTHORITY = "USCG",
      RESCUE_AUTHORITY_PHONE = "5555551212",
      ROUTE_INSTANCE_ID = routeLink.route_instance_id,
      ROUTE_DAY_NUMBER = routeLink.route_day_number
    }, [], [ { CONTACTID = variables.created.contactId, SORT_ORDER = 1 } ], [] );
    expect( savePayload.SUCCESS ).toBeTrue( serializeJSON( savePayload ) );
  }

  private struct function loadRouteLink( required numeric planId ) {
    var qPlan = queryExecute(
      "SELECT route_instance_id, route_day_number
       FROM floatplans
       WHERE floatplanId = :floatPlanId
       LIMIT 1",
      {
        floatPlanId = { value = arguments.planId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    expect( qPlan.recordCount ).toBe( 1 );
    return {
      route_instance_id = val( qPlan.route_instance_id[ 1 ] ),
      route_day_number = isNull( qPlan.route_day_number[ 1 ] ) ? 0 : val( qPlan.route_day_number[ 1 ] )
    };
  }

  private struct function loadRoutePlanState( required numeric planId ) {
    var qPlan = queryExecute(
      "SELECT userId, route_instance_id, `status`
       FROM floatplans
       WHERE floatplanId = :floatPlanId
       LIMIT 1",
      {
        floatPlanId = { value = arguments.planId, cfsqltype = "cf_sql_integer" }
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

  private array function loadRoutePlanIdsByRouteInstance( required numeric routeInstanceId ) {
    var qPlans = queryExecute(
      "SELECT floatplanId
       FROM floatplans
       WHERE route_instance_id = :routeInstanceId
       ORDER BY floatplanId ASC",
      {
        routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    var ids = [];
    for ( var rowIdx = 1; rowIdx LTE qPlans.recordCount; rowIdx++ ) {
      arrayAppend( ids, val( qPlans.floatplanId[ rowIdx ] ) );
    }
    return ids;
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

  private void function markPlanActive( required numeric planId ) {
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
        floatPlanId = { value = arguments.planId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function restorePlanToDraft( required numeric planId ) {
    queryExecute(
      "UPDATE floatplans
       SET `status` = 'DRAFT',
           activatedAt = NULL,
           checkedInAt = NULL,
           checkin_context = NULL,
           closedAt = NULL,
           lastUpdateStatus = UTC_TIMESTAMP()
       WHERE floatplanId = :floatPlanId",
      {
        floatPlanId = { value = arguments.planId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function seedMonitoringRow( required numeric floatPlanId, required numeric userId, string monitorState = "ACTIVE" ) {
    deleteMonitoringRows( arguments.floatPlanId );
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

    if ( qMonitoring.recordCount EQ 0 ) {
      seedMonitoringRow( arguments.floatPlanId, arguments.userId, arguments.monitorState );
    }
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

  private void function rememberCreatedPlanId( required numeric planId ) {
    if ( arguments.planId LTE 0 ) {
      return;
    }
    if ( arrayFind( variables.created.floatPlanIds, arguments.planId ) EQ 0 ) {
      arrayAppend( variables.created.floatPlanIds, arguments.planId );
    }
  }

  private void function forgetCreatedPlanId( required numeric planId ) {
    var idx = arrayFind( variables.created.floatPlanIds, arguments.planId );
    if ( idx GT 0 ) {
      arrayDeleteAt( variables.created.floatPlanIds, idx );
    }
  }

  private struct function createSessionApiUser( required string baseUrl ) {
    var signupApi = new fpw.tests.support.FpwApiSupport().init( baseUrl = arguments.baseUrl );
    var uniqueEmail = "fpw-lifecycle-" & replace( createUUID(), "-", "", "all" ) & "@example.com";
    var payload = signupApi.postJson( "/api/v1/join.cfc?method=handle", {
      firstName = "FPW",
      lastName = "Lifecycle",
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

  private string function buildDateTimeLocal( required numeric daysFromNow, required numeric hour ) {
    var value = now();
    value = dateAdd( "d", arguments.daysFromNow, value );
    value = createDateTime( year( value ), month( value ), day( value ), arguments.hour, 0, 0 );
    return dateTimeFormat( value, "yyyy-mm-dd" ) & "T" & timeFormat( value, "HH:mm" );
  }
}
