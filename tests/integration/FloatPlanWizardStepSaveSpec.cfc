component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.ctx = {};

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
    variables.ctx.saveUrl = variables.ctx.baseUrl & "/fpw/api/v1/floatplan.cfc?method=handle";
    variables.ctx.bootstrapUrl = variables.ctx.baseUrl & "/fpw/api/v1/floatplan.cfc?method=handle&action=bootstrap";

    variables.ctx.contactUrl = variables.ctx.baseUrl & "/fpw/api/v1/contact.cfc?method=handle";
    variables.ctx.passengerUrl = variables.ctx.baseUrl & "/fpw/api/v1/passenger.cfc?method=handle";
    variables.ctx.waypointUrl = variables.ctx.baseUrl & "/fpw/api/v1/waypoint.cfc?method=handle";
    variables.ctx.operatorUrl = variables.ctx.baseUrl & "/fpw/api/v1/operator.cfc?method=handle";

    variables.ctx.forceVesselId = structKeyExists( url, "testVesselId" ) && isNumeric( url.testVesselId )
      ? val( url.testVesselId )
      : 0;
    variables.ctx.forceOperatorId = structKeyExists( url, "testOperatorId" ) && isNumeric( url.testOperatorId )
      ? val( url.testOperatorId )
      : 0;

    ensureSessionUser();
    variables.ctx.sessionReady = !structKeyExists( variables.ctx, "sessionError" );

    variables.ctx.bootstrap = variables.ctx.sessionReady ? apiGetJson( variables.ctx.bootstrapUrl ) : {};
    variables.ctx.vesselId = variables.ctx.forceVesselId > 0 ? variables.ctx.forceVesselId : extractIdFromList( variables.ctx.bootstrap, "VESSELS", "VESSELID" );
    variables.ctx.operatorId = variables.ctx.forceOperatorId > 0 ? variables.ctx.forceOperatorId : extractIdFromList( variables.ctx.bootstrap, "OPERATORS", "OPERATORID" );
    variables.ctx.rescueCenterId = extractIdFromList( variables.ctx.bootstrap, "RESCUE_CENTERS", "RESCUE_CENTERID" );

    variables.ctx.created = { contactId = 0, passengerId = 0, waypointId = 0 };
  }

  function afterAll() {
    if ( !structKeyExists( variables, "ctx" ) || !variables.ctx.sessionReady ) {
      return;
    }
    if ( val( variables.ctx.created.contactId ) ) {
      apiPostJson( variables.ctx.contactUrl, { action = "delete", contactId = variables.ctx.created.contactId } );
    }
    if ( val( variables.ctx.created.passengerId ) ) {
      apiPostJson( variables.ctx.passengerUrl, { action = "delete", passengerId = variables.ctx.created.passengerId } );
    }
    if ( val( variables.ctx.created.waypointId ) ) {
      apiPostJson( variables.ctx.waypointUrl, { action = "delete", waypointId = variables.ctx.created.waypointId } );
    }
  }

  function run() {

    describe( "Float Plan Wizard save across all steps", function() {

      it( "rejects missing name", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }
        if ( variables.ctx.vesselId LTE 0 ) {
          skip( "No vessel available for test user. Provide testVesselId." );
        }

        var res = apiPostJson( variables.ctx.saveUrl, {
          action = "save",
          FLOATPLAN = {
            vesselId = variables.ctx.vesselId
          }
        } );

        expect( pickBool( res, "SUCCESS" ) ).toBeFalse();
        expect( findNoCase( "Float plan name is required", toString( res.MESSAGE ?: "" ) ) ).toBeGT( 0 );
      } );

      it( "rejects missing vessel", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var res = apiPostJson( variables.ctx.saveUrl, {
          action = "save",
          FLOATPLAN = {
            floatPlanName = "Missing Vessel"
          }
        } );

        expect( pickBool( res, "SUCCESS" ) ).toBeFalse();
        expect( findNoCase( "Please select a vessel", toString( res.MESSAGE ?: "" ) ) ).toBeGT( 0 );
      } );

      it( "saves at each step payload", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }
        if ( variables.ctx.vesselId LTE 0 ) {
          skip( "No vessel available for test user. Provide testVesselId." );
        }
        if ( variables.ctx.operatorId LTE 0 ) {
          variables.ctx.operatorId = ensureOperator();
        }

        var suffix = uniqueSuffix();
        var nowDt = now();
        var departDt = dateAdd( "h", 1, nowDt );
        var returnDt = dateAdd( "h", 4, nowDt );

        // Step 1 payload
        var step1 = {
          action = "save",
          FLOATPLAN = {
            floatPlanName = "Wizard Step Test " & suffix,
            vesselId = variables.ctx.vesselId,
            operatorId = variables.ctx.operatorId
          }
        };
        var res1 = apiPostJson( variables.ctx.saveUrl, step1 );
        expect( pickBool( res1, "SUCCESS" ) ).toBeTrue( "Step 1 save failed: #serializeJSON(res1)#" );
        var planId = extractId( res1 );
        expect( len( planId ) ).toBeGT( 0 );

        // Step 2 payload (add depart/return)
        var step2 = duplicate( step1 );
        step2.FLOATPLAN.floatPlanId = planId;
        step2.FLOATPLAN.departingFrom = "Test Dock";
        step2.FLOATPLAN.departureTime = dtString( departDt );
        step2.FLOATPLAN.departureTimezone = "America/New_York";
        step2.FLOATPLAN.returningTo = "Test Dock";
        step2.FLOATPLAN.returnTime = dtString( returnDt );
        step2.FLOATPLAN.returnTimezone = "America/New_York";
        var res2 = apiPostJson( variables.ctx.saveUrl, step2 );
        expect( pickBool( res2, "SUCCESS" ) ).toBeTrue( "Step 2 save failed: #serializeJSON(res2)#" );
        expect( extractId( res2 ) ).toBe( planId );

        // Step 3 payload (rescue authority)
        var step3 = duplicate( step2 );
        step3.FLOATPLAN.rescueAuthority = "USCG";
        step3.FLOATPLAN.rescueAuthorityPhone = "555-555-1212";
        step3.FLOATPLAN.rescueCenterId = variables.ctx.rescueCenterId;
        var res3 = apiPostJson( variables.ctx.saveUrl, step3 );
        expect( pickBool( res3, "SUCCESS" ) ).toBeTrue( "Step 3 save failed: #serializeJSON(res3)#" );
        expect( extractId( res3 ) ).toBe( planId );

        // Step 4 payload (passengers + contacts)
        ensureSelections();
        var step4 = duplicate( step3 );
        step4.PASSENGERS = [ { PASSENGERID = variables.ctx.created.passengerId } ];
        step4.CONTACTS = [ { CONTACTID = variables.ctx.created.contactId } ];
        var res4 = apiPostJson( variables.ctx.saveUrl, step4 );
        expect( pickBool( res4, "SUCCESS" ) ).toBeTrue( "Step 4 save failed: #serializeJSON(res4)#" );
        expect( extractId( res4 ) ).toBe( planId );

        // Step 5 payload (waypoints)
        var step5 = duplicate( step4 );
        step5.WAYPOINTS = [ { WAYPOINTID = variables.ctx.created.waypointId } ];
        var res5 = apiPostJson( variables.ctx.saveUrl, step5 );
        expect( pickBool( res5, "SUCCESS" ) ).toBeTrue( "Step 5 save failed: #serializeJSON(res5)#" );
        expect( extractId( res5 ) ).toBe( planId );

        // Step 6 payload (full review save)
        var step6 = duplicate( step5 );
        var res6 = apiPostJson( variables.ctx.saveUrl, step6 );
        expect( pickBool( res6, "SUCCESS" ) ).toBeTrue( "Step 6 save failed: #serializeJSON(res6)#" );
        expect( extractId( res6 ) ).toBe( planId );
      } );

    } );

  }

  private void function ensureSelections() {
    if ( val( variables.ctx.created.contactId ) && val( variables.ctx.created.passengerId ) && val( variables.ctx.created.waypointId ) ) {
      return;
    }
    var suffix = uniqueSuffix();
    var contactRes = apiPostJson( variables.ctx.contactUrl, {
      action = "save",
      CONTACT = {
        CONTACTNAME = "Wizard Contact " & suffix,
        PHONE = "555-555-1212",
        EMAIL = "wizard-contact-" & suffix & "@example.com"
      }
    } );
    variables.ctx.created.contactId = val( contactRes.CONTACTID ?: 0 );

    var passengerRes = apiPostJson( variables.ctx.passengerUrl, {
      action = "save",
      PASSENGER = {
        PASSENGERNAME = "Wizard Passenger " & suffix,
        PHONE = "555-555-1313",
        AGE = "35",
        GENDER = "Other",
        NOTES = "Wizard test"
      }
    } );
    variables.ctx.created.passengerId = val( passengerRes.PASSENGERID ?: 0 );

    var waypointRes = apiPostJson( variables.ctx.waypointUrl, {
      action = "save",
      WAYPOINT = {
        WAYPOINTNAME = "Wizard Waypoint " & suffix,
        LATITUDE = "42.3601",
        LONGITUDE = "-71.0589",
        NOTES = "Wizard test"
      }
    } );
    variables.ctx.created.waypointId = val( waypointRes.WAYPOINTID ?: 0 );
  }

  private numeric function ensureOperator() {
    if ( val( variables.ctx.operatorId ) ) {
      return variables.ctx.operatorId;
    }
    var suffix = uniqueSuffix();
    var operatorRes = apiPostJson( variables.ctx.operatorUrl, {
      action = "save",
      OPERATOR = {
        OPERATORNAME = "Wizard Operator " & suffix,
        PHONE = "555-555-1414",
        NOTES = "Wizard test"
      }
    } );
    variables.ctx.operatorId = val( operatorRes.OPERATORID ?: 0 );
    return variables.ctx.operatorId;
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

  private struct function apiPostJson( required string url, required struct body ) {
    var sessionCookies = getSessionCookies();
    var res = {};
    cfhttp( method="POST", url=arguments.url, timeout="60", result="res" ) {
      cfhttpparam( type="header", name="Accept", value="application/json" );
      cfhttpparam( type="header", name="Content-Type", value="application/json; charset=utf-8" );
      cfhttpparam( type="body", value=serializeJSON( arguments.body ) );
      for ( var cookiePair in sessionCookies ) {
        cfhttpparam( type="cookie", name=cookiePair.name, value=cookiePair.value );
      }
    }
    return decodeJsonResponse( res );
  }

  private struct function apiGetJson( required string url ) {
    var sessionCookies = getSessionCookies();
    var res = {};
    cfhttp( method="GET", url=arguments.url, timeout="60", result="res" ) {
      cfhttpparam( type="header", name="Accept", value="application/json" );
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

  private boolean function pickBool( required struct payload, required string key ) {
    return structKeyExists( arguments.payload, arguments.key ) ? !!arguments.payload[ arguments.key ] : false;
  }

  private string function extractId( required struct saveRes ) {
    if ( structKeyExists( arguments.saveRes, "floatPlanId" ) ) return toString( arguments.saveRes.floatPlanId );
    if ( structKeyExists( arguments.saveRes, "FLOATPLANID" ) ) return toString( arguments.saveRes.FLOATPLANID );
    if ( structKeyExists( arguments.saveRes, "id" ) ) return toString( arguments.saveRes.id );
    return "";
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
