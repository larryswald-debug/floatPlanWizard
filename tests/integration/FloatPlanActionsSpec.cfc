component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.ctx = {
      createdPlanIds = []
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
  }

  function afterAll() {
    if ( !structKeyExists( variables, "ctx" ) || !variables.ctx.sessionReady ) {
      return;
    }

    for ( var i = 1; i LTE arrayLen( variables.ctx.createdPlanIds ); i++ ) {
      floatPlanPost( "delete", { floatPlanId = variables.ctx.createdPlanIds[ i ] } );
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

        var sendRes = floatPlanPost( "send", { floatPlanId = plan.planId } );
        expect( pickBool( sendRes, "SUCCESS" ) ).toBeFalse( "send should fail when no contacts are selected: #serializeJSON(sendRes)#" );
        var sendCode = uCase( toString( pickFirst( sendRes, [ "ERROR", "error" ], "" ) ) );
        var sendMessage = lCase( toString( pickFirst( sendRes, [ "MESSAGE", "message" ], "" ) ) );
        var hasExpectedSendFailure = ( sendCode EQ "NO_CONTACTS" || sendCode EQ "NO_EMAILS" || findNoCase( "contact", sendMessage ) GT 0 );
        expect( hasExpectedSendFailure ).toBeTrue( "Unexpected send failure reason: #serializeJSON(sendRes)#" );

        var checkinRes = floatPlanPost( "checkin", { floatPlanId = plan.planId } );
        expect( pickBool( checkinRes, "SUCCESS" ) ).toBeTrue( "checkin failed: #serializeJSON(checkinRes)#" );
        expect( val( pickFirst( checkinRes, [ "FLOATPLANID", "floatPlanId", "id" ], 0 ) ) ).toBe( plan.planId );

        var cloneRes = floatPlanPost( "clone", { floatPlanId = plan.planId } );
        expect( pickBool( cloneRes, "SUCCESS" ) ).toBeTrue( "clone failed: #serializeJSON(cloneRes)#" );
        var cloneId = val( pickFirst( cloneRes, [ "FLOATPLANID", "floatPlanId", "id" ], 0 ) );
        expect( cloneId ).toBeGT( 0, "clone did not return a plan id: #serializeJSON(cloneRes)#" );
        rememberCreatedPlanId( cloneId );

        var deleteCloneRes = floatPlanPost( "delete", { floatPlanId = cloneId } );
        expect( pickBool( deleteCloneRes, "SUCCESS" ) ).toBeTrue( "delete clone failed: #serializeJSON(deleteCloneRes)#" );
        forgetCreatedPlanId( cloneId );

        var deleteSourceRes = floatPlanPost( "delete", { floatPlanId = plan.planId } );
        expect( pickBool( deleteSourceRes, "SUCCESS" ) ).toBeTrue( "delete source failed: #serializeJSON(deleteSourceRes)#" );
        forgetCreatedPlanId( plan.planId );
      } );

      it( "covers bulk-delete guardrails", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var invalidTargetRes = floatPlanPost( "deleteallbyuser", { targetUserId = 0 } );
        expect( pickBool( invalidTargetRes, "SUCCESS" ) ).toBeFalse( "deleteallbyuser should reject missing target user id: #serializeJSON(invalidTargetRes)#" );
        expect( uCase( toString( pickFirst( invalidTargetRes, [ "ERROR", "error" ], "" ) ) ) ).toBe( "INVALID_USER_ID" );

        var noPlansRes = floatPlanPost( "deleteallbyuser", { targetUserId = 999999 } );
        expect( pickBool( noPlansRes, "SUCCESS" ) ).toBeTrue( "deleteallbyuser for empty user should succeed: #serializeJSON(noPlansRes)#" );
        expect( val( pickFirst( noPlansRes, [ "DELETED_COUNT", "deleted_count" ], 0 ) ) ).toBe( 0 );

        var originalSessionUser = structKeyExists( session, "user" ) && isStruct( session.user ) ? duplicate( session.user ) : {};
        try {
          if ( !structKeyExists( session, "user" ) || !isStruct( session.user ) ) {
            session.user = {};
          }
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
