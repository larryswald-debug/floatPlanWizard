component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.ctx = {
      createdPlanIds = [],
      createdRouteCodes = [],
      createdVesselIds = []
    };

    if ( structKeyExists( CGI, "SCRIPT_NAME" ) && findNoCase( "/testbox/", CGI.SCRIPT_NAME ) ) {
      variables.ctx.sessionReady = false;
      return;
    }

    var scheme = ( structKeyExists( CGI, "https" ) && CGI.https == "on" ) ? "https" : "http";
    var host   = CGI.server_name;
    var port   = CGI.server_port;
    var portPart = "";
    if ( !( scheme == "http" && port == 80 ) && !( scheme == "https" && port == 443 ) ) {
      portPart = ":" & port;
    }

    variables.ctx.baseUrl = scheme & "://" & host & portPart;
    variables.ctx.floatPlanHandleUrl = variables.ctx.baseUrl & "/fpw/api/v1/floatplan.cfc?method=handle";
    variables.ctx.floatPlanBootstrapUrl = variables.ctx.floatPlanHandleUrl & "&action=bootstrap";
    variables.ctx.forceUserId = structKeyExists( url, "testUserId" ) && isNumeric( url.testUserId )
      ? val( url.testUserId )
      : 187;

    ensureSessionUser();
    variables.ctx.sessionReady = !structKeyExists( variables.ctx, "sessionError" );
    variables.ctx.monitorService = new fpw.api.v1.monitor().init();
    variables.ctx.apiSupport = new fpw.tests.support.FpwApiSupport().init( baseUrl = variables.ctx.baseUrl & "/fpw" );
    variables.ctx.cleanupSupport = new fpw.tests.support.FpwCleanupSupport().init( variables.ctx.apiSupport );
    variables.ctx.namingSupport = new fpw.tests.support.FpwNamingSupport();
  }

  function afterAll() {
    if ( !structKeyExists( variables, "ctx" ) || !variables.ctx.sessionReady ) {
      return;
    }

    for ( var i = 1; i LTE arrayLen( variables.ctx.createdPlanIds ); i++ ) {
      deleteMonitoringRows( variables.ctx.createdPlanIds[ i ] );
      floatPlanPost( "delete", { floatPlanId = variables.ctx.createdPlanIds[ i ] } );
    }
    for ( var j = arrayLen( variables.ctx.createdRouteCodes ); j GTE 1; j-- ) {
      try {
        variables.ctx.cleanupSupport.cleanupRoute( variables.ctx.createdRouteCodes[ j ] );
      } catch ( any ignoredRouteCleanup ) {}
    }
    for ( var k = arrayLen( variables.ctx.createdVesselIds ); k GTE 1; k-- ) {
      try {
        variables.ctx.cleanupSupport.cleanupVessel( variables.ctx.createdVesselIds[ k ] );
      } catch ( any ignoredVesselCleanup ) {}
    }
  }

  function run() {
    describe( "Float plan API action coverage", function() {
      it( "returns bootstrap payload and rejects unsupported action", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var bootstrapRes = apiGetJson( variables.ctx.floatPlanBootstrapUrl & "&id=0" );
        expect( pickBool( bootstrapRes, "SUCCESS" ) ).toBeTrue( "bootstrap failed: #serializeJSON(bootstrapRes)#" );
        expect( !!pickFirst( bootstrapRes, [ "AUTH", "auth" ], false ) ).toBeTrue( "bootstrap should be AUTH=true: #serializeJSON(bootstrapRes)#" );
        expect( structKeyExists( bootstrapRes, "FLOATPLAN" ) ).toBeTrue( "bootstrap missing FLOATPLAN: #serializeJSON(bootstrapRes)#" );
        expect( structKeyExists( bootstrapRes, "VESSELS" ) && isArray( bootstrapRes.VESSELS ) ).toBeTrue( "bootstrap missing VESSELS array: #serializeJSON(bootstrapRes)#" );

        var invalidRes = floatPlanPost( "does_not_exist", {} );
        expect( pickBool( invalidRes, "SUCCESS" ) ).toBeFalse( "invalid action should fail: #serializeJSON(invalidRes)#" );
        expect( !!pickFirst( invalidRes, [ "AUTH", "auth" ], false ) ).toBeTrue( "invalid action should still be AUTH=true for logged-in user: #serializeJSON(invalidRes)#" );
        expect( uCase( toString( pickFirst( invalidRes, [ "ERROR", "error" ], "" ) ) ) ).toBe( "INVALID_ACTION" );
      } );

      it( "covers send validation, check-in, clone, and delete", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var plan = createDraftPlan( "Action lifecycle" );
        expect( plan.planId ).toBeGT( 0, "Unable to create draft plan: #serializeJSON(plan)#" );
        queryExecute(
          "DELETE FROM floatplan_contacts WHERE floatplanId = :floatPlanId",
          {
            floatPlanId = { value = plan.planId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = "fpw" }
        );

        var sendRes = floatPlanPost( "send", { floatPlanId = plan.planId } );
        expect( pickBool( sendRes, "SUCCESS" ) ).toBeFalse( "send should fail when no contacts are selected: #serializeJSON(sendRes)#" );
        var sendCode = uCase( toString( pickFirst( sendRes, [ "ERROR", "error" ], "" ) ) );
        var sendMessage = lCase( toString( pickFirst( sendRes, [ "MESSAGE", "message" ], "" ) ) );
        var hasExpectedSendFailure = ( sendCode EQ "NO_CONTACTS" || sendCode EQ "NO_EMAILS" || findNoCase( "contact", sendMessage ) GT 0 );
        expect( hasExpectedSendFailure ).toBeTrue( "Unexpected send failure reason: #serializeJSON(sendRes)#" );

        var invalidCheckinRes = floatPlanPost( "checkin", { floatPlanId = plan.planId } );
        expect( pickBool( invalidCheckinRes, "SUCCESS" ) ).toBeFalse( "route-less draft check-in should fail: #serializeJSON(invalidCheckinRes)#" );
        expect( uCase( toString( pickFirst( invalidCheckinRes, [ "ERROR", "error" ], "" ) ) ) ).toBe( "NO_ACTIVE_PLAN" );

        var routePlan = createRouteLinkedPlan( "active-checkin" );
        var activeDepartureAt = dateAdd( "h", -1, now() );
        var activeReturnAt = dateAdd( "h", 6, activeDepartureAt );
        expect( routePlan.planId ).toBeGT( 0, "Unable to create route-backed plan: #serializeJSON(routePlan)#" );
        setPlanSchedule( routePlan.planId, dtString( activeDepartureAt ), dtString( activeReturnAt ), "US/Eastern" );
        markPlanActive( routePlan.planId );
        var startMonitoringRes = variables.ctx.monitorService.startMonitoringForFloatPlan( routePlan.planId, "active_route" );
        expect( pickBool( startMonitoringRes, "SUCCESS" ) ).toBeTrue( "start monitoring failed: #serializeJSON(startMonitoringRes)#" );

        var checkinRes = floatPlanPost( "checkin", {
          floatPlanId = routePlan.planId,
          status = "On Track",
          note = "Route-backed lifecycle check-in"
        } );
        expect( pickBool( checkinRes, "SUCCESS" ) ).toBeTrue( "active route-backed check-in failed: #serializeJSON(checkinRes)#" );
        queryExecute(
          "UPDATE floatplans
           SET `status` = 'CLOSED',
               checkedInAt = UTC_TIMESTAMP(),
               checkin_context = NULL,
               closedAt = UTC_TIMESTAMP(),
               lastUpdateStatus = UTC_TIMESTAMP()
           WHERE floatplanId = :floatPlanId",
          {
            floatPlanId = { value = routePlan.planId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = "fpw" }
        );
        deleteMonitoringRows( routePlan.planId );

        var cloneRes = floatPlanPost( "clone", { floatPlanId = plan.planId } );
        expect( pickBool( cloneRes, "SUCCESS" ) ).toBeFalse( "clone should be disabled: #serializeJSON(cloneRes)#" );
        expect( uCase( toString( pickFirst( cloneRes, [ "ERROR", "error" ], "" ) ) ) ).toBe( "CLONE_DISABLED" );

        var deleteSourceRes = floatPlanPost( "delete", { floatPlanId = plan.planId } );
        expect( pickBool( deleteSourceRes, "SUCCESS" ) ).toBeTrue( "delete source failed: #serializeJSON(deleteSourceRes)#" );
        forgetCreatedPlanId( plan.planId );
      } );

      it( "routes Arrived through the existing close path and closes monitoring", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var plan = createRouteLinkedPlan( "arrived-lifecycle" );
        expect( plan.planId ).toBeGT( 0, "Unable to create draft plan: #serializeJSON(plan)#" );

        setPlanSchedule( plan.planId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern" );
        markPlanActive( plan.planId );
        var startMonitoringRes = variables.ctx.monitorService.startMonitoringForFloatPlan( plan.planId, "active_route" );
        expect( pickBool( startMonitoringRes, "SUCCESS" ) ).toBeTrue( "start monitoring failed: #serializeJSON(startMonitoringRes)#" );

        var arrivedRes = floatPlanPost( "checkin", {
          floatPlanId = plan.planId,
          status = "Arrived",
          note = "Arrived through Active Cruise"
        } );
        var planRow = loadPlanRow( plan.planId );
        var monitoringRow = loadMonitoringRow( plan.planId );

        expect( pickBool( arrivedRes, "SUCCESS" ) ).toBeTrue( "Arrived close failed: #serializeJSON(arrivedRes)#" );
        expect( planRow.status_value ).toBe( "CLOSED" );
        expect( planRow.checkin_context ).toBe( "" );
        expect( isDate( planRow.closed_at ) ).toBeTrue();
        expect( monitoringRow.monitor_state ).toBe( "CLOSED" );
        expect( monitoringRow.is_monitoring_enabled ).toBeFalse();
      } );

      it( "covers bulk-delete guardrails", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var originalSessionUser = structKeyExists( session, "user" ) && isStruct( session.user ) ? duplicate( session.user ) : {};
        try {
          if ( !structKeyExists( session, "user" ) || !isStruct( session.user ) ) {
            session.user = {};
          }
          session.user.userId = 9999;
          session.user.id = 9999;
          session.user.USERID = 9999;

          var invalidTargetRes = floatPlanPost( "deleteallbyuser", { targetUserId = 0 } );
          expect( pickBool( invalidTargetRes, "SUCCESS" ) ).toBeFalse( "deleteallbyuser should reject missing target user id before auth: #serializeJSON(invalidTargetRes)#" );
          expect( uCase( toString( pickFirst( invalidTargetRes, [ "ERROR", "error" ], "" ) ) ) ).toBe( "INVALID_USER_ID" );

          session.user.userId = 187;
          session.user.id = 187;
          session.user.USERID = 187;

          var noPlansRes = floatPlanPost( "deleteallbyuser", { targetUserId = 999999 } );
          expect( pickBool( noPlansRes, "SUCCESS" ) ).toBeTrue( "deleteallbyuser for empty user should succeed: #serializeJSON(noPlansRes)#" );
          expect( val( pickFirst( noPlansRes, [ "DELETED_COUNT", "deleted_count" ], 0 ) ) ).toBe( 0 );

          session.user.userId = 9999;
          session.user.id = 9999;
          session.user.USERID = 9999;

          var forbiddenRes = floatPlanPost( "deleteallbyuser", { targetUserId = variables.ctx.forceUserId } );
          expect( pickBool( forbiddenRes, "SUCCESS" ) ).toBeFalse( "deleteallbyuser should require admin user id: #serializeJSON(forbiddenRes)#" );
          expect( uCase( toString( pickFirst( forbiddenRes, [ "ERROR", "error" ], "" ) ) ) ).toBe( "FORBIDDEN" );
        } finally {
          session.user = originalSessionUser;
        }
      } );

      it( "requires authenticated session for float plan actions", function() {
        var anonRes = apiPostJson(
          variables.ctx.floatPlanHandleUrl,
          { action = "bootstrap" },
          false
        );
        expect( pickBool( anonRes, "SUCCESS" ) ).toBeFalse( "anonymous call should fail: #serializeJSON(anonRes)#" );
        expect( !!pickFirst( anonRes, [ "AUTH", "auth" ], true ) ).toBeFalse( "anonymous call should return AUTH=false: #serializeJSON(anonRes)#" );
        expect( findNoCase( "not logged", lCase( toString( pickFirst( anonRes, [ "MESSAGE", "message" ], "" ) ) ) ) GT 0 ).toBeTrue();
      } );
    } );
  }

  private struct function createDraftPlan( string namePrefix = "Action Spec Plan" ) {
    var bootstrapRes = apiGetJson( variables.ctx.floatPlanBootstrapUrl & "&id=0" );
    if ( !pickBool( bootstrapRes, "SUCCESS" ) ) {
      throw(
        type = "FloatPlanActionsSpec.Setup",
        message = "bootstrap failed while creating draft plan",
        detail = serializeJSON( bootstrapRes )
      );
    }

    var vesselId = extractIdFromList( bootstrapRes, "VESSELS", "VESSELID" );
    if ( vesselId LTE 0 ) {
      throw(
        type = "FloatPlanActionsSpec.Setup",
        message = "No vessel available for test user",
        detail = serializeJSON( bootstrapRes )
      );
    }

    var operatorId = extractIdFromList( bootstrapRes, "OPERATORS", "OPERATORID" );
    var departureAt = dateAdd( "h", 1, now() );
    var returnAt = dateAdd( "h", 6, departureAt );
    var planName = arguments.namePrefix & " " & uniqueSuffix();

    var saveRes = floatPlanPost( "save", {
      FLOATPLAN = {
        floatPlanName = planName,
        vesselId = vesselId,
        operatorId = operatorId,
        departingFrom = "Spec Dock",
        departureTime = dtString( departureAt ),
        departureTimezone = "America/New_York",
        returningTo = "Spec Dock",
        returnTime = dtString( returnAt ),
        returnTimezone = "America/New_York",
        rescueAuthority = "USCG",
        rescueAuthorityPhone = "5555551212"
      }
    } );

    if ( !pickBool( saveRes, "SUCCESS" ) ) {
      throw(
        type = "FloatPlanActionsSpec.Setup",
        message = "save failed while creating draft plan",
        detail = serializeJSON( saveRes )
      );
    }

    var planId = val( pickFirst( saveRes, [ "FLOATPLANID", "floatPlanId", "id" ], 0 ) );
    if ( planId LTE 0 ) {
      throw(
        type = "FloatPlanActionsSpec.Setup",
        message = "save response missing float plan id",
        detail = serializeJSON( saveRes )
      );
    }

    rememberCreatedPlanId( planId );
    return {
      planId = planId,
      name = planName
    };
  }

  private struct function createRouteLinkedPlan( required string scenarioSlug ) {
    var prefix = variables.ctx.namingSupport.buildPrefix( "float-plan-actions", arguments.scenarioSlug );
    var vesselPayload = variables.ctx.apiSupport.saveVessel( {
      vesselId = 0,
      vesselName = variables.ctx.namingSupport.buildName( prefix, "Actions Vessel" ),
      type = "Cruiser",
      length = 34,
      color = "White"
    } );
    var vesselId = val( vesselPayload.VESSELID ?: 0 );
    var options = variables.ctx.apiSupport.routeBuilder( "routegen_getoptions", {
      template_code = "GULF-WEST",
      direction = "CCW"
    } );
    var generate = {};
    var routeCode = "";
    var buildPayload = {};
    var planId = 0;

    expect( pickBool( vesselPayload, "SUCCESS" ) ).toBeTrue( serializeJSON( vesselPayload ) );
    expect( pickBool( options, "SUCCESS" ) ).toBeTrue( serializeJSON( options ) );

    generate = variables.ctx.apiSupport.routeBuilder( "routegen_generate", {
      route_name = variables.ctx.namingSupport.buildName( prefix, "Actions Route" ),
      template_code = "GULF-WEST",
      direction = "CCW",
      start_segment_id = options.DATA.startOptions[ 1 ].segment_id,
      end_segment_id = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].segment_id,
      start_location_label = options.DATA.startOptions[ 1 ].label,
      end_location_label = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].label,
      start_date = dateFormat( now(), "yyyy-mm-dd" ),
      optional_stop_flags = [ "ship_island_out_and_back" ]
    } );
    expect( pickBool( generate, "SUCCESS" ) ).toBeTrue( serializeJSON( generate ) );

    routeCode = trim( toString( generate.ROUTE_CODE ?: generate.DATA.route_code ?: "" ) );
    buildPayload = variables.ctx.apiSupport.routeBuilder( "buildFloatPlansFromRoute", {
      routeCode = routeCode,
      mode = "DAILY",
      vesselId = vesselId,
      rebuild = 0
    } );
    expect( pickBool( buildPayload, "SUCCESS" ) ).toBeTrue( serializeJSON( buildPayload ) );

    planId = val( buildPayload.FLOATPLAN_IDS[ 1 ] ?: 0 );
    expect( planId ).toBeGT( 0, serializeJSON( buildPayload ) );

    arrayAppend( variables.ctx.createdVesselIds, vesselId );
    arrayAppend( variables.ctx.createdRouteCodes, routeCode );
    for ( var id in buildPayload.FLOATPLAN_IDS ) {
      rememberCreatedPlanId( val( id ) );
    }

    return {
      planId = planId,
      routeCode = routeCode,
      vesselId = vesselId
    };
  }

  private void function rememberCreatedPlanId( required numeric planId ) {
    if ( arguments.planId LTE 0 ) return;
    if ( arrayFind( variables.ctx.createdPlanIds, arguments.planId ) EQ 0 ) {
      arrayAppend( variables.ctx.createdPlanIds, arguments.planId );
    }
  }

  private void function forgetCreatedPlanId( required numeric planId ) {
    var idx = arrayFind( variables.ctx.createdPlanIds, arguments.planId );
    if ( idx GT 0 ) {
      arrayDeleteAt( variables.ctx.createdPlanIds, idx );
    }
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

  private void function setPlanSchedule(
    required numeric planId,
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
           checkedInAt = NULL,
           checkin_context = NULL,
           closedAt = NULL,
           lastUpdateStatus = UTC_TIMESTAMP()
       WHERE floatplanId = :floatPlanId",
      {
        departureLocal = { value = arguments.departureLocal, cfsqltype = "cf_sql_timestamp" },
        returnLocal = { value = arguments.returnLocal, cfsqltype = "cf_sql_timestamp" },
        timeZoneId = { value = arguments.timeZoneId, cfsqltype = "cf_sql_varchar" },
        floatPlanId = { value = arguments.planId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private struct function loadPlanRow( required numeric planId ) {
    var qPlan = queryExecute(
      "SELECT
          UPPER(TRIM(`status`)) AS status_value,
          checkin_context,
          closedAt
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
      status_value = trim( toString( qPlan.status_value[ 1 ] ) ),
      checkin_context = isNull( qPlan.checkin_context[ 1 ] ) ? "" : trim( toString( qPlan.checkin_context[ 1 ] ) ),
      closed_at = isNull( qPlan.closedAt[ 1 ] ) ? "" : qPlan.closedAt[ 1 ]
    };
  }

  private struct function loadMonitoringRow( required numeric planId ) {
    var qRow = queryExecute(
      "SELECT monitor_state, is_monitoring_enabled
       FROM floatplan_monitoring
       WHERE float_plan_id = :floatPlanId
       LIMIT 1",
      {
        floatPlanId = { value = arguments.planId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    expect( qRow.recordCount ).toBe( 1 );
    return {
      monitor_state = trim( toString( qRow.monitor_state[ 1 ] ) ),
      is_monitoring_enabled = val( qRow.is_monitoring_enabled[ 1 ] ) NEQ 0
    };
  }

  private void function deleteMonitoringRows( required numeric planId ) {
    queryExecute(
      "DELETE FROM floatplan_monitor_events WHERE float_plan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.planId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM floatplan_monitoring WHERE float_plan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.planId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function ensureSessionUser() {
    try {
      if ( !structKeyExists( session, "user" ) || !isStruct( session.user ) ) {
        session.user = {};
      }
      if ( !structKeyExists( session.user, "userId" ) || !isNumeric( session.user.userId ) || val( session.user.userId ) LTE 0 ) {
        session.user.userId = variables.ctx.forceUserId;
        session.user.id = session.user.userId;
        session.user.USERID = session.user.userId;
      }
    } catch ( any e ) {
      variables.ctx.sessionError = e.message;
    }
  }

  private struct function floatPlanPost( required string action, struct payload = {} ) {
    var body = isStruct( arguments.payload ) ? duplicate( arguments.payload ) : {};
    body.action = arguments.action;
    return apiPostJson( variables.ctx.floatPlanHandleUrl, body, true );
  }

  private array function getSessionCookies() {
    var cookiePairs = [];
    var cookieNames = [ "CFID", "CFTOKEN", "JSESSIONID" ];
    var runtimeCfid = "";
    var runtimeCftoken = "";
    try { runtimeCfid = trim( toString( CFID ) ); } catch ( any _cfidErr ) {}
    try { runtimeCftoken = trim( toString( CFTOKEN ) ); } catch ( any _cftErr ) {}

    for ( var name in cookieNames ) {
      var cookieVal = "";
      if ( structKeyExists( cookie, name ) ) {
        cookieVal = trim( toString( cookie[ name ] ) );
      } else if ( name EQ "CFID" && len( runtimeCfid ) ) {
        cookieVal = runtimeCfid;
      } else if ( name EQ "CFTOKEN" && len( runtimeCftoken ) ) {
        cookieVal = runtimeCftoken;
      } else if ( name EQ "JSESSIONID" && structKeyExists( session, "sessionid" ) ) {
        cookieVal = trim( toString( session.sessionid ) );
      }
      if ( len( cookieVal ) ) {
        arrayAppend( cookiePairs, { name = name, value = cookieVal } );
      }
    }

    return cookiePairs;
  }

  private struct function apiPostJson( required string url, required struct body, boolean includeCookies = true ) {
    var sessionCookies = arguments.includeCookies ? getSessionCookies() : [];
    var testHeaderUserId = resolveTestHeaderUserId( arguments.includeCookies );
    var res = {};
    cfhttp( method="POST", url=arguments.url, timeout="60", result="res" ) {
      cfhttpparam( type="header", name="Accept", value="application/json" );
      cfhttpparam( type="header", name="Content-Type", value="application/json; charset=utf-8" );
      if ( testHeaderUserId GT 0 ) {
        cfhttpparam( type="header", name="X-FPW-Test-UserId", value=toString( testHeaderUserId ) );
      }
      cfhttpparam( type="body", value=serializeJSON( arguments.body ) );
      for ( var cookiePair in sessionCookies ) {
        cfhttpparam( type="cookie", name=cookiePair.name, value=cookiePair.value );
      }
    }
    return decodeJsonResponse( res );
  }

  private struct function apiGetJson( required string url ) {
    var sessionCookies = getSessionCookies();
    var testHeaderUserId = resolveTestHeaderUserId( true );
    var res = {};
    cfhttp( method="GET", url=arguments.url, timeout="60", result="res" ) {
      cfhttpparam( type="header", name="Accept", value="application/json" );
      if ( testHeaderUserId GT 0 ) {
        cfhttpparam( type="header", name="X-FPW-Test-UserId", value=toString( testHeaderUserId ) );
      }
      for ( var cookiePair in sessionCookies ) {
        cfhttpparam( type="cookie", name=cookiePair.name, value=cookiePair.value );
      }
    }
    return decodeJsonResponse( res );
  }

  private struct function decodeJsonResponse( required struct httpRes ) {
    var raw = "";
    if ( structKeyExists( arguments.httpRes, "fileContent" ) ) raw = arguments.httpRes.fileContent;
    else if ( structKeyExists( arguments.httpRes, "responseHeader" ) ) raw = toString( arguments.httpRes.responseHeader );
    try {
      var parsed = deserializeJSON( raw );
      if ( isStruct( parsed ) ) return parsed;
      return { success=false, message="JSON was not a struct", raw=raw, parsed=parsed };
    } catch ( any e ) {
      return { success=false, message="Response was not JSON", raw=raw, error=e.message };
    }
  }

  private numeric function resolveTestHeaderUserId( boolean includeCookies = true ) {
    var userId = 0;
    if ( arguments.includeCookies
      && structKeyExists( session, "user" )
      && isStruct( session.user )
      && structKeyExists( session.user, "userId" )
      && isNumeric( session.user.userId ) ) {
      userId = val( session.user.userId );
    }
    if ( userId LTE 0 && arguments.includeCookies && structKeyExists( variables, "ctx" ) && structKeyExists( variables.ctx, "forceUserId" ) && isNumeric( variables.ctx.forceUserId ) ) {
      userId = val( variables.ctx.forceUserId );
    }
    return ( userId GT 0 ? userId : 0 );
  }

  private boolean function pickBool( required struct payload, required string key ) {
    return structKeyExists( arguments.payload, arguments.key ) ? !!arguments.payload[ arguments.key ] : false;
  }

  private any function pickFirst( required struct source, required array keys, any defaultValue = "" ) {
    for ( var key in arguments.keys ) {
      if ( structKeyExists( arguments.source, key ) ) {
        return arguments.source[ key ];
      }
    }
    return arguments.defaultValue;
  }

  private numeric function extractIdFromList( required struct payload, required string listKey, required string idKey ) {
    if ( !structKeyExists( arguments.payload, arguments.listKey ) || !isArray( arguments.payload[ arguments.listKey ] ) ) {
      return 0;
    }
    for ( var item in arguments.payload[ arguments.listKey ] ) {
      if ( isStruct( item ) && structKeyExists( item, arguments.idKey ) && isNumeric( item[ arguments.idKey ] ) ) {
        return val( item[ arguments.idKey ] );
      }
    }
    return 0;
  }

  private string function dtString( required any dt ) {
    if ( !isDate( arguments.dt ) ) {
      throw( message="dtString requires a date value", detail="Got: #serializeJSON(arguments.dt)#" );
    }
    return dateTimeFormat( arguments.dt, "yyyy-mm-dd" ) & " " & timeFormat( arguments.dt, "HH:mm:ss" );
  }

  private string function uniqueSuffix() {
    return dateTimeFormat( now(), "yyyymmddHHnnss" ) & "-" & right( createUUID(), 6 );
  }

}
