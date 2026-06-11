component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.hadOriginalTestUserId = structKeyExists( url, "testUserId" );
    variables.originalTestUserId = variables.hadOriginalTestUserId ? url.testUserId : "";
    variables.sessionApiUser = createSessionApiUser();
    url.testUserId = variables.sessionApiUser.userId;
    variables.api = new fpw.tests.support.FpwApiSupport().init(
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
      floatPlanId = 0,
      routeCode = "",
      pdfPrefix = ""
    };
  }

  function afterAll() {
    if ( len( variables.created.pdfPrefix ) ) variables.cleanup.cleanupPdfPrefix( variables.created.pdfPrefix );
    if ( len( variables.created.routeCode ) ) {
      variables.cleanup.cleanupRoute( variables.created.routeCode );
    } else if ( variables.created.floatPlanId GT 0 ) {
      variables.cleanup.cleanupFloatPlan( variables.created.floatPlanId );
    }
    if ( variables.created.contactId GT 0 ) variables.cleanup.cleanupContact( variables.created.contactId );
    if ( variables.created.operatorId GT 0 ) variables.cleanup.cleanupOperator( variables.created.operatorId );
    if ( variables.created.vesselId GT 0 ) variables.cleanup.cleanupVessel( variables.created.vesselId );
    cleanupSessionApiUser();
    if ( variables.hadOriginalTestUserId ) {
      url.testUserId = variables.originalTestUserId;
    } else {
      structDelete( url, "testUserId", false );
    }
  }

  function run() {
    describe( "Float plan direct-send and PDF output", function() {
      it( "creates a PDF file and moves the float plan to ACTIVE on send", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-email-output", "send-pdf" );
        var vesselId = createVessel( prefix );
        var operatorId = createOperator( prefix );
        var contact = createContact( prefix );
        var routePlan = createRouteLinkedDraftPlan( prefix, vesselId, operatorId, contact );

        variables.created.vesselId = vesselId;
        variables.created.operatorId = operatorId;
        variables.created.contactId = contact.contactId;
        variables.created.floatPlanId = routePlan.planId;
        variables.created.routeCode = routePlan.routeCode;
        variables.created.pdfPrefix = rereplace( routePlan.planName, "[^A-Za-z0-9_-]+", "_", "all" );

        var sendPayload = variables.api.sendFloatPlan( variables.created.floatPlanId );
        expect( sendPayload.SUCCESS ).toBeTrue( serializeJSON( sendPayload ) );

        var bootstrap = variables.api.bootstrapFloatPlan( variables.created.floatPlanId );
        expect( uCase( bootstrap.FLOATPLAN.STATUS ) ).toBe( "ACTIVE" );

        var pdfFile = trim( variables.api.createFloatPlanPdf( variables.created.floatPlanId ) );
        expect( right( pdfFile, 4 ) ).toBe( ".pdf" );
        expect( fileExists( expandPath( "/fpw/floatPlans/user_float_plans/" & pdfFile ) ) ).toBeTrue();

        var qLegs = queryExecute(
          "SELECT leg_order
           FROM route_instance_legs
           WHERE route_instance_id = :routeInstanceId
           ORDER BY leg_order ASC, id ASC",
          {
            routeInstanceId = { value = routePlan.routeInstanceId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = "fpw" }
        );
        expect( qLegs.recordCount ).toBeGT( 0 );

        var finalLegOrder = val( qLegs.leg_order[ qLegs.recordCount ] );
        ensureOpenMonitoringRow( variables.created.floatPlanId, variables.sessionApiUser.userId );
        queryExecute(
          "DELETE FROM route_instance_leg_progress
           WHERE user_id = :userId
             AND route_instance_id = :routeInstanceId",
          {
            userId = { value = variables.sessionApiUser.userId, cfsqltype = "cf_sql_integer" },
            routeInstanceId = { value = routePlan.routeInstanceId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = "fpw" }
        );
        queryExecute(
          "INSERT INTO route_instance_leg_progress (user_id, route_instance_id, leg_order, status, leg_started_at)
           VALUES (:userId, :routeInstanceId, :legOrder, 'STARTED', UTC_TIMESTAMP())",
          {
            userId = { value = variables.sessionApiUser.userId, cfsqltype = "cf_sql_integer" },
            routeInstanceId = { value = routePlan.routeInstanceId, cfsqltype = "cf_sql_integer" },
            legOrder = { value = finalLegOrder, cfsqltype = "cf_sql_integer" }
          },
          { datasource = "fpw" }
        );

        var closePayload = variables.api.checkinFloatPlan( variables.created.floatPlanId );
        expect( closePayload.SUCCESS ).toBeTrue( serializeJSON( closePayload ) );
        expect( uCase( trim( toString( closePayload.STATUS ?: "" ) ) ) ).toBe( "CLOSED" );
      } );
    } );
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

  private numeric function createVessel( required string prefix ) {
    var payload = variables.api.saveVessel( {
      vesselId = 0,
      vesselName = variables.naming.buildName( prefix, "Email Vessel" ),
      type = "Cruiser",
      length = 33,
      color = "White"
    } );
    return val( payload.VESSELID ?: 0 );
  }

  private numeric function createOperator( required string prefix ) {
    var payload = variables.api.saveOperator( {
      operatorId = 0,
      name = variables.naming.buildName( prefix, "Email Operator" )
    } );
    return val( payload.OPERATORID ?: 0 );
  }

  private struct function createContact( required string prefix ) {
    var email = variables.naming.buildEmail( prefix, "email-contact" );
    var payload = variables.api.saveContact( {
      contactId = 0,
      name = variables.naming.buildName( prefix, "Email Contact" ),
      phone = "5555551212",
      email = email
    } );
    return {
      contactId = val( payload.CONTACTID ?: 0 ),
      email = email
    };
  }

  private struct function createRouteLinkedDraftPlan(
    required string prefix,
    required numeric vesselId,
    required numeric operatorId,
    required struct contact
  ) {
    var options = variables.api.routeBuilder( "routegen_getoptions", {
      template_code = "GULF-WEST",
      direction = "CCW"
    } );
    var generate = {};
    var routeCode = "";
    var buildPayload = {};
    var planId = 0;
    var routeLink = {};
    var planName = variables.naming.buildName( arguments.prefix, "Email Plan" );
    var departureTime = buildDateTimeLocal( 2, 9 );
    var returnTime = buildDateTimeLocal( 2, 18 );
    var savePayload = {};

    expect( options.SUCCESS ).toBeTrue( serializeJSON( options ) );

    generate = variables.api.routeBuilder( "routegen_generate", {
      route_name = variables.naming.buildName( arguments.prefix, "Email Route" ),
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
      vesselId = arguments.vesselId,
      rebuild = 0
    } );
    expect( buildPayload.SUCCESS ).toBeTrue( serializeJSON( buildPayload ) );

    planId = val( buildPayload.FLOATPLAN_IDS[ 1 ] ?: 0 );
    expect( planId ).toBeGT( 0, serializeJSON( buildPayload ) );

    routeLink = loadRouteLink( planId );
    savePayload = variables.api.saveFloatPlan(
      {
        FLOATPLANID = planId,
        NAME = planName,
        VESSELID = arguments.vesselId,
        OPERATORID = arguments.operatorId,
        DEPARTING_FROM = "Email Dock",
        DEPARTURE_TIME = departureTime,
        DEPARTURE_TIMEZONE = "America/New_York",
        RETURNING_TO = "Email Dock",
        RETURN_TIME = returnTime,
        RETURN_TIMEZONE = "America/New_York",
        EMAIL = arguments.contact.email,
        RESCUE_AUTHORITY = "USCG",
        RESCUE_AUTHORITY_PHONE = "5555551212",
        ROUTE_INSTANCE_ID = routeLink.route_instance_id,
        ROUTE_DAY_NUMBER = routeLink.route_day_number
      },
      [],
      [ { CONTACTID = arguments.contact.contactId, SORT_ORDER = 1 } ],
      []
    );
    expect( savePayload.SUCCESS ).toBeTrue( serializeJSON( savePayload ) );

    return {
      planId = planId,
      planName = planName,
      routeCode = routeCode,
      routeInstanceId = routeLink.route_instance_id
    };
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

  private string function buildDateTimeLocal( required numeric daysFromNow, required numeric hour ) {
    var value = now();
    value = dateAdd( "d", arguments.daysFromNow, value );
    value = createDateTime( year( value ), month( value ), day( value ), arguments.hour, 0, 0 );
    return dateTimeFormat( value, "yyyy-mm-dd" ) & "T" & timeFormat( value, "HH:mm" );
  }

  private struct function createSessionApiUser() {
    var signupApi = new fpw.tests.support.FpwApiSupport().init();
    var uniqueEmail = "fpw-email-output-" & replace( createUUID(), "-", "", "all" ) & "@example.com";
    var payload = signupApi.postJson( "/api/v1/join.cfc?method=handle", {
      firstName = "FPW",
      lastName = "EmailOutput",
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
}
