component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.ctx = {};

    if ( structKeyExists( CGI, "SCRIPT_NAME" ) && findNoCase( "/testbox/", CGI.SCRIPT_NAME ) ) {
      variables.ctx.sessionReady = false;
      variables.ctx.apiReady = false;
      variables.ctx.apiCheck = {
        ok = false,
        raw = "Session scope not available under /testbox runner.",
        status = ""
      };
      return;
    }

    // Build a base URL that works in Docker/local (same host serving runner.cfm)
    // Example result: http://localhost:8500  OR https://www.floatplanwizard.com
    var scheme = ( structKeyExists( CGI, "https" ) && CGI.https == "on" ) ? "https" : "http";
    var host   = CGI.server_name;
    var port   = CGI.server_port;

    // Avoid adding :80 or :443
    var portPart = "";
    if ( !( scheme == "http"  && port == 80 ) && !( scheme == "https" && port == 443 ) ) {
      portPart = ":" & port;
    }

    variables.ctx.baseUrl = scheme & "://" & host & portPart;
    variables.ctx.saveUrl = variables.ctx.baseUrl & "/fpw/api/v1/floatplan.cfc?method=handle&action=save";
    variables.ctx.getUrl  = variables.ctx.baseUrl & "/fpw/api/v1/floatplan.cfc?method=handle&action=bootstrap";
    variables.ctx.operatorUrl = variables.ctx.baseUrl & "/fpw/api/v1/operator.cfc?method=handle";
    ensureSessionUser();
    if ( structKeyExists( variables.ctx, "sessionError" ) ) {
      variables.ctx.sessionReady = false;
      variables.ctx.apiCheck = {
        ok = false,
        raw = "Session scope not available. " & variables.ctx.sessionError,
        status = ""
      };
      variables.ctx.apiReady = false;
      return;
    }
    variables.ctx.sessionReady = true;

    variables.ctx.authHeaderName = structKeyExists( url, "authHeaderName" ) ? trim( url.authHeaderName ) : "";
    variables.ctx.authHeaderValue = structKeyExists( url, "authHeaderValue" ) ? trim( url.authHeaderValue ) : "";
    variables.ctx.forceVesselId = structKeyExists( url, "testVesselId" ) && isNumeric( url.testVesselId )
      ? val( url.testVesselId )
      : 0;

    variables.ctx.apiCheck = apiCheck( variables.ctx.getUrl & "&id=0" );
    variables.ctx.apiReady = variables.ctx.apiCheck.ok;
    if ( variables.ctx.apiReady ) {
      var bootstrapRes = apiGetJson( variables.ctx.getUrl );
      variables.ctx.operatorId = extractOperatorId( bootstrapRes );
      if ( variables.ctx.operatorId LTE 0 ) {
        variables.ctx.operatorId = ensureOperator();
      }
    }

    // If your API requires auth headers/tokens, wire them here (kept optional)
    // variables.ctx.authHeaderName  = "X-Auth-Token";
    // variables.ctx.authHeaderValue = "";
  }

  function run( testResults, testBox ) {

    describe( "FPW FloatPlan Save time regression (no 5-hour shift)", function() {

      it( "Save preserves DEPARTURE_TIME and RETURN_TIME (no -5h shift)", function() {
        if ( !structKeyExists( variables.ctx, "sessionReady" ) || !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }
        if ( !variables.ctx.apiReady ) {
          fail( "API not reachable or not returning JSON. status=#variables.ctx.apiCheck.status# raw=#variables.ctx.apiCheck.raw#" );
        }

        // Known values (seconds=0)
        var expectedDeparture = createDateTime( 2026, 01, 04, 10, 15, 00 );
        var expectedReturn    = createDateTime( 2026, 01, 04, 15, 45, 00 );

        var bootstrapRes = apiGetJson( variables.ctx.getUrl );
        var vesselId = variables.ctx.forceVesselId > 0 ? variables.ctx.forceVesselId : extractVesselId( bootstrapRes );
        if ( vesselId LTE 0 ) {
          skip( "No vessel found for test user. Provide testVesselId or ensure a vessel exists. Raw: #serializeJSON(bootstrapRes)#" );
        }
        if ( !structKeyExists( variables.ctx, "operatorId" ) || variables.ctx.operatorId LTE 0 ) {
          variables.ctx.operatorId = ensureOperator();
        }

        var payload = buildFloatPlanPayload(
          "TestBox Time Shift Spec",
          vesselId,
          expectedDeparture,
          expectedReturn
        );

        // --- SAVE ---
        var saveRes = apiPostJson( variables.ctx.saveUrl, payload );

        // No more "SUCCESS is undefined" — we ALWAYS reference saveRes.success (and fail loudly if missing)
        expect( isStruct( saveRes ) ).toBeTrue( "Save did not return a struct. Raw: #serializeJSON(saveRes)#" );
        var saveSuccess = pickFirst( saveRes, [ "success", "SUCCESS" ] );
        expect( saveSuccess ).toBeTrue( "Save failed. Raw: #serializeJSON(saveRes)#" );

        var floatPlanId = extractId( saveRes );
        expect( len( floatPlanId ) ).toBeGT( 0, "Could not extract floatPlanId from save response: #serializeJSON(saveRes)#" );

        // --- GET ---
        var getRes = apiGetJson( variables.ctx.getUrl & "&id=" & urlEncodedFormat( floatPlanId ) );

        expect( isStruct( getRes ) ).toBeTrue( "Get did not return a struct. Raw: #serializeJSON(getRes)#" );
        var getSuccess = pickFirst( getRes, [ "success", "SUCCESS" ] );
        if ( len( toString( getSuccess ) ) ) {
          expect( getSuccess ).toBeTrue( "Get failed. Raw: #serializeJSON(getRes)#" );
        }

        var plan = extractPlan( getRes );
        expect( isStruct( plan ) ).toBeTrue( "Could not extract plan data. Raw: #serializeJSON(getRes)#" );

        var gotDeparture = parseAsDate( pickFirst( plan, [ "DEPARTURE_TIME", "departure_time", "departureTime" ] ) );
        var gotReturn    = parseAsDate( pickFirst( plan, [ "RETURN_TIME", "return_time", "returnTime" ] ) );

        expect( isDate( gotDeparture ) ).toBeTrue( "Departure is not a date. Got: #serializeJSON(gotDeparture)# Plan: #serializeJSON(plan)#" );
        expect( isDate( gotReturn ) ).toBeTrue( "Return is not a date. Got: #serializeJSON(gotReturn)# Plan: #serializeJSON(plan)#" );

        // Compare at minute precision — catches -5h shift while avoiding tiny format differences
        expect( normDT( gotDeparture ) ).toBe( normDT( expectedDeparture ),
          "Departure mismatch. expected=#normDT(expectedDeparture)# got=#normDT(gotDeparture)#"
        );
        expect( normDT( gotReturn ) ).toBe( normDT( expectedReturn ),
          "Return mismatch. expected=#normDT(expectedReturn)# got=#normDT(gotReturn)#"
        );

      } );

      it( "Edit+save preserves times (no shift after update)", function() {
        if ( !structKeyExists( variables.ctx, "sessionReady" ) || !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }
        if ( !variables.ctx.apiReady ) {
          fail( "API not reachable or not returning JSON. status=#variables.ctx.apiCheck.status# raw=#variables.ctx.apiCheck.raw#" );
        }

        var expectedDeparture = createDateTime( 2026, 01, 05, 09, 00, 00 );
        var expectedReturn    = createDateTime( 2026, 01, 05, 13, 30, 00 );

        var bootstrapRes = apiGetJson( variables.ctx.getUrl );
        var vesselId = variables.ctx.forceVesselId > 0 ? variables.ctx.forceVesselId : extractVesselId( bootstrapRes );
        if ( vesselId LTE 0 ) {
          skip( "No vessel found for test user. Provide testVesselId or ensure a vessel exists. Raw: #serializeJSON(bootstrapRes)#" );
        }
        if ( !structKeyExists( variables.ctx, "operatorId" ) || variables.ctx.operatorId LTE 0 ) {
          variables.ctx.operatorId = ensureOperator();
        }

        // First save (create)
        var createRes = apiPostJson(
          variables.ctx.saveUrl,
          buildFloatPlanPayload( "TestBox Time Shift Edit Spec", vesselId, expectedDeparture, expectedReturn )
        );
        var createSuccess = pickFirst( createRes, [ "success", "SUCCESS" ] );
        expect( createSuccess ).toBeTrue( "Create failed. Raw: #serializeJSON(createRes)#" );

        var floatPlanId = extractId( createRes );
        expect( len( floatPlanId ) ).toBeGT( 0, "Could not extract floatPlanId from create response: #serializeJSON(createRes)#" );

        // Re-save (edit) using same times
        var updatePayload = buildFloatPlanPayload(
          "TestBox Time Shift Edit Spec",
          vesselId,
          expectedDeparture,
          expectedReturn
        );
        updatePayload.FLOATPLAN.floatPlanId = floatPlanId;
        updatePayload.FLOATPLAN.FLOATPLANID = floatPlanId;

        var updateRes = apiPostJson( variables.ctx.saveUrl, updatePayload );
        var updateSuccess = pickFirst( updateRes, [ "success", "SUCCESS" ] );
        expect( updateSuccess ).toBeTrue( "Update failed. Raw: #serializeJSON(updateRes)#" );

        var getRes = apiGetJson( variables.ctx.getUrl & "&id=" & urlEncodedFormat( floatPlanId ) );
        var plan = extractPlan( getRes );

        var gotDeparture = parseAsDate( pickFirst( plan, [ "DEPARTURE_TIME", "departure_time", "departureTime" ] ) );
        var gotReturn    = parseAsDate( pickFirst( plan, [ "RETURN_TIME", "return_time", "returnTime" ] ) );

        expect( isDate( gotDeparture ) ).toBeTrue( "Departure is not a date. Got: #serializeJSON(gotDeparture)# Plan: #serializeJSON(plan)#" );
        expect( isDate( gotReturn ) ).toBeTrue( "Return is not a date. Got: #serializeJSON(gotReturn)# Plan: #serializeJSON(plan)#" );

        expect( normDT( gotDeparture ) ).toBe( normDT( expectedDeparture ),
          "Departure mismatch after update. expected=#normDT(expectedDeparture)# got=#normDT(gotDeparture)#"
        );
        expect( normDT( gotReturn ) ).toBe( normDT( expectedReturn ),
          "Return mismatch after update. expected=#normDT(expectedReturn)# got=#normDT(gotReturn)#"
        );
      } );

    } );
  }

  /* --------------------------
     HTTP helpers (working)
  -------------------------- */

  private struct function apiPostJson( required string url, required struct body ) {
    var sessionCookies = getSessionCookies();
    var res = {};
    cfhttp(
      method="POST",
      url=arguments.url,
      timeout="60",
      result="res"
    ) {
      cfhttpparam(type="header", name="Accept", value="application/json");
      cfhttpparam(type="header", name="Content-Type", value="application/json; charset=utf-8");

      // Optional auth header wiring
      if ( structKeyExists( variables, "ctx" ) && len( variables.ctx.authHeaderName ) ) {
        cfhttpparam(type="header", name=variables.ctx.authHeaderName, value=variables.ctx.authHeaderValue);
      }

      cfhttpparam(type="body", value=serializeJSON( arguments.body ));

      for ( var cookiePair in sessionCookies ) {
        cfhttpparam(type="cookie", name=cookiePair.name, value=cookiePair.value);
      }
    };
    return decodeJsonResponse( res );
  }

  private struct function apiGetJson( required string url ) {
    var sessionCookies = getSessionCookies();
    var res = {};
    cfhttp(
      method="GET",
      url=arguments.url,
      timeout="60",
      result="res"
    ) {
      cfhttpparam(type="header", name="Accept", value="application/json");

      // Optional auth header wiring
      if ( structKeyExists( variables, "ctx" ) && len( variables.ctx.authHeaderName ) ) {
        cfhttpparam(type="header", name=variables.ctx.authHeaderName, value=variables.ctx.authHeaderValue);
      }

      for ( var cookiePair in sessionCookies ) {
        cfhttpparam(type="cookie", name=cookiePair.name, value=cookiePair.value);
      }
    };
    return decodeJsonResponse( res );
  }

  private struct function apiCheck( required string url ) {
    try {
      var sessionCookies = getSessionCookies();
      var res = {};
      cfhttp(
        method="GET",
        url=arguments.url,
        timeout="10",
        result="res"
      ) {
        cfhttpparam(type="header", name="Accept", value="application/json");
        if ( structKeyExists( variables, "ctx" ) && len( variables.ctx.authHeaderName ) ) {
          cfhttpparam(type="header", name=variables.ctx.authHeaderName, value=variables.ctx.authHeaderValue);
        }
        for ( var cookiePair in sessionCookies ) {
          cfhttpparam(type="cookie", name=cookiePair.name, value=cookiePair.value);
        }
      };
      var raw = "";
      if ( structKeyExists( res, "fileContent" ) ) raw = res.fileContent;
      var status = structKeyExists( res, "statusCode" ) ? res.statusCode : "";
      if ( !len( trim( raw ) ) ) return { ok=false, raw=raw, status=status };
      var parsed = deserializeJSON( raw );
      var ok = ( isStruct( parsed ) || isArray( parsed ) );
      return { ok=ok, raw=raw, status=status };
    } catch ( any e ) {
      return { ok=false, raw=e.message, status="" };
    }
  }

  private void function ensureSessionUser() {
    try {
      if ( !structKeyExists( session, "user" ) || !isStruct( session.user ) ) {
        session.user = {};
      }
      if ( !structKeyExists( session.user, "userId" ) || !isNumeric( session.user.userId ) ) {
        var fallbackId = structKeyExists( url, "testUserId" ) ? url.testUserId : 1;
        session.user.userId = val( fallbackId );
        session.user.id = session.user.userId;
        session.user.USERID = session.user.userId;
      }
      if ( structKeyExists( url, "testUserEmail" ) ) {
        session.user.email = trim( url.testUserEmail );
      }
    } catch ( any e ) {
      variables.ctx.sessionError = e.message;
    }
  }

  private array function getSessionCookies() {
    var cookiePairs = [];
    var cookieNames = [ "CFID", "CFTOKEN", "JSESSIONID" ];
    for ( var name in cookieNames ) {
      if ( structKeyExists( cookie, name ) ) {
        arrayAppend( cookiePairs, { name = name, value = cookie[ name ] } );
      }
    }
    return cookiePairs;
  }

  private struct function decodeJsonResponse( required struct httpRes ) {
    // ColdFusion cfhttp wrapper returns various keys; fileContent is the body
    var raw = "";
    if ( structKeyExists( arguments.httpRes, "fileContent" ) ) raw = arguments.httpRes.fileContent;
    else if ( structKeyExists( arguments.httpRes, "responseHeader" ) ) raw = toString( arguments.httpRes.responseHeader );

    // If the endpoint accidentally returns HTML/errors, fail in a controlled way
    try {
      var parsed = deserializeJSON( raw );
      // Ensure struct return
      if ( isStruct( parsed ) ) return parsed;
      return { success=false, message="JSON was not a struct", raw=raw, parsed=parsed };
    } catch ( any e ) {
      return { success=false, message="Response was not JSON", raw=raw, error=e.message };
    }
  }

  /* --------------------------
     Data helpers
  -------------------------- */

  private string function dtString( required any dt ) {
    if ( !isDate( arguments.dt ) ) {
      throw( message="dtString requires a date value", detail="Got: #serializeJSON(arguments.dt)#" );
    }
    return dateTimeFormat( arguments.dt, "yyyy-mm-dd" ) & " " & timeFormat( arguments.dt, "HH:mm:ss" );
  }

  private string function normDT( required any dt ) {
    if ( !isDate( arguments.dt ) ) {
      throw( message="normDT requires a date value", detail="Got: #serializeJSON(arguments.dt)#" );
    }
    return dateTimeFormat( arguments.dt, "yyyy-mm-dd" ) & " " & timeFormat( arguments.dt, "HH:mm" );
  }

  private any function pickFirst( required struct s, required array keys ) {
    for ( var k in arguments.keys ) {
      if ( structKeyExists( arguments.s, k ) ) return arguments.s[ k ];
    }
    return "";
  }

  private any function parseAsDate( required any v ) {
    if ( isDate( arguments.v ) ) return arguments.v;
    if ( isSimpleValue( arguments.v ) && len( trim( arguments.v ) ) ) {
      try { return parseDateTime( arguments.v ); } catch ( any e ) {}
    }
    return arguments.v;
  }

  private string function extractId( required struct saveRes ) {
    // Common patterns supported
    if ( structKeyExists( arguments.saveRes, "id" ) ) return toString( arguments.saveRes.id );
    if ( structKeyExists( arguments.saveRes, "floatPlanId" ) ) return toString( arguments.saveRes.floatPlanId );
    if ( structKeyExists( arguments.saveRes, "FLOATPLANID" ) ) return toString( arguments.saveRes.FLOATPLANID );
    if ( structKeyExists( arguments.saveRes, "data" ) && isStruct( arguments.saveRes.data ) ) {
      if ( structKeyExists( arguments.saveRes.data, "id" ) ) return toString( arguments.saveRes.data.id );
      if ( structKeyExists( arguments.saveRes.data, "floatPlanId" ) ) return toString( arguments.saveRes.data.floatPlanId );
    }
    return "";
  }

  private struct function extractPlan( required struct getRes ) {
    // Common patterns supported
    if ( structKeyExists( arguments.getRes, "data" ) && isStruct( arguments.getRes.data ) ) return arguments.getRes.data;
    if ( structKeyExists( arguments.getRes, "floatPlan" ) && isStruct( arguments.getRes.floatPlan ) ) return arguments.getRes.floatPlan;
    if ( structKeyExists( arguments.getRes, "FLOATPLAN" ) && isStruct( arguments.getRes.FLOATPLAN ) ) return arguments.getRes.FLOATPLAN;

    // Sometimes API returns a list:
    if ( structKeyExists( arguments.getRes, "data" ) && isArray( arguments.getRes.data ) && arrayLen( arguments.getRes.data ) ) {
      if ( isStruct( arguments.getRes.data[1] ) ) return arguments.getRes.data[1];
    }

    return arguments.getRes;
  }

  private struct function buildFloatPlanPayload(
    required string planName,
    required numeric vesselId,
    required any departure,
    required any returnAt
  ) {
    var departureString = dtString( arguments.departure );
    var returnString = dtString( arguments.returnAt );
    return {
      FLOATPLAN : {
        floatPlanName    : arguments.planName,
        vesselId         : arguments.vesselId,
        operatorId       : structKeyExists( variables, "ctx" ) ? variables.ctx.operatorId : 0,
        departureTime    : departureString,
        returnTime       : returnString,
        DEPARTURE_TIME   : departureString,
        RETURN_TIME      : returnString,
        DEPARTURE_TIMEZONE : "America/New_York",
        RETURN_TIMEZONE    : "America/New_York"
      }
    };
  }

  private numeric function extractVesselId( required struct bootstrapRes ) {
    if ( structKeyExists( arguments.bootstrapRes, "VESSELS" ) && isArray( arguments.bootstrapRes.VESSELS ) ) {
      for ( var vessel in arguments.bootstrapRes.VESSELS ) {
        if ( isStruct( vessel ) && structKeyExists( vessel, "VESSELID" ) && isNumeric( vessel.VESSELID ) ) {
          return val( vessel.VESSELID );
        }
      }
    }
    return 0;
  }

  private numeric function extractOperatorId( required struct bootstrapRes ) {
    if ( structKeyExists( arguments.bootstrapRes, "OPERATORS" ) && isArray( arguments.bootstrapRes.OPERATORS ) ) {
      for ( var op in arguments.bootstrapRes.OPERATORS ) {
        if ( isStruct( op ) && structKeyExists( op, "OPERATORID" ) && isNumeric( op.OPERATORID ) ) {
          return val( op.OPERATORID );
        }
      }
    }
    return 0;
  }

  private numeric function ensureOperator() {
    if ( structKeyExists( variables, "ctx" ) && val( variables.ctx.operatorId ) ) {
      return variables.ctx.operatorId;
    }
    var suffix = dateTimeFormat( now(), "yyyymmddHHnnss" ) & "-" & right( createUUID(), 6 );
    var operatorRes = apiPostJson( variables.ctx.operatorUrl, {
      action = "save",
      OPERATOR = {
        OPERATORNAME = "Test Operator " & suffix,
        PHONE = "555-555-1414",
        NOTES = "Test operator"
      }
    } );
    variables.ctx.operatorId = val( operatorRes.OPERATORID ?: 0 );
    return variables.ctx.operatorId;
  }

}
