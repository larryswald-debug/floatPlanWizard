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
    variables.ctx.generateRouteUrl = variables.ctx.baseUrl & "/fpw/api/v1/routeBuilder.cfc?method=handle&action=generateRoute";
    variables.ctx.floatPlanSaveUrl = variables.ctx.baseUrl & "/fpw/api/v1/floatplan.cfc?method=handle&action=save";
    variables.ctx.floatPlanBootstrapUrl = variables.ctx.baseUrl & "/fpw/api/v1/floatplan.cfc?method=handle&action=bootstrap";
    variables.ctx.forceVesselId = structKeyExists( url, "testVesselId" ) && isNumeric( url.testVesselId )
      ? val( url.testVesselId )
      : 0;
    variables.ctx.forceUserId = structKeyExists( url, "testUserId" ) && isNumeric( url.testUserId )
      ? val( url.testUserId )
      : 187;

    ensureSessionUser();
    variables.ctx.sessionReady = !structKeyExists( variables.ctx, "sessionError" );
  }

  function run() {
    describe( "Route Generator 2.0 Phase 1 linkage", function() {
      it( "creates route_instance on generateRoute and persists link on floatplan save", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var bootstrap = apiGetJson( variables.ctx.floatPlanBootstrapUrl & "&id=0" );
        var vesselId = variables.ctx.forceVesselId > 0
          ? variables.ctx.forceVesselId
          : extractIdFromList( bootstrap, "VESSELS", "VESSELID" );
        if ( vesselId LTE 0 ) {
          skip( "No vessel available for test user. Provide testVesselId." );
        }

        var genRes = apiPostJson( variables.ctx.generateRouteUrl, {
          startDate = dateFormat( now(), "yyyy-mm-dd" ),
          startLocation = "Chicago",
          endLocation = "Ludington",
          direction = "CCW",
          tripType = "POINT_TO_POINT"
        } );
        expect( pickBool( genRes, "SUCCESS" ) ).toBeTrue( "generateRoute failed: #serializeJSON(genRes)#" );

        var routeInstanceId = val( pickFirst( genRes, [ "ROUTE_INSTANCE_ID", "route_instance_id", "routeInstanceId" ], 0 ) );
        expect( routeInstanceId ).toBeGT( 0, "Expected ROUTE_INSTANCE_ID in generateRoute response: #serializeJSON(genRes)#" );

        var departDt = dateAdd( "h", 2, now() );
        var returnDt = dateAdd( "h", 6, now() );
        var saveRes = apiPostJson( variables.ctx.floatPlanSaveUrl, {
          FLOATPLAN = {
            floatPlanName = "Route Instance Link Spec " & uniqueSuffix(),
            vesselId = vesselId,
            departingFrom = "Test Dock",
            departureTime = dtString( departDt ),
            departureTimezone = "America/New_York",
            returningTo = "Test Dock",
            returnTime = dtString( returnDt ),
            returnTimezone = "America/New_York",
            routeInstanceId = routeInstanceId,
            routeDayNumber = 1
          }
        } );
        expect( pickBool( saveRes, "SUCCESS" ) ).toBeTrue( "Floatplan save failed: #serializeJSON(saveRes)#" );

        var floatPlanId = extractId( saveRes );
        expect( len( floatPlanId ) ).toBeGT( 0, "Could not extract floatPlanId from save response: #serializeJSON(saveRes)#" );

        var getRes = apiGetJson( variables.ctx.floatPlanBootstrapUrl & "&id=" & urlEncodedFormat( floatPlanId ) );
        var plan = structKeyExists( getRes, "FLOATPLAN" ) && isStruct( getRes.FLOATPLAN ) ? getRes.FLOATPLAN : {};
        expect( isStruct( plan ) ).toBeTrue( "Could not extract FLOATPLAN from bootstrap response: #serializeJSON(getRes)#" );

        var savedRouteInstanceId = val( pickFirst( plan, [ "ROUTE_INSTANCE_ID", "route_instance_id", "routeInstanceId" ], 0 ) );
        var savedRouteDayNumber = val( pickFirst( plan, [ "ROUTE_DAY_NUMBER", "route_day_number", "routeDayNumber" ], 0 ) );
        expect( savedRouteInstanceId ).toBe( routeInstanceId );
        expect( savedRouteDayNumber ).toBe( 1 );
      } );
    } );
  }

  private void function ensureSessionUser() {
    try {
      if ( !structKeyExists( session, "user" ) || !isStruct( session.user ) ) {
        session.user = {};
      }
      if ( !structKeyExists( session.user, "userId" ) || !isNumeric( session.user.userId ) ) {
        var fallbackId = structKeyExists( variables, "ctx" ) && structKeyExists( variables.ctx, "forceUserId" )
          ? variables.ctx.forceUserId
          : 187;
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

  private any function pickFirst( required struct source, required array keys, any defaultValue = "" ) {
    for ( var key in arguments.keys ) {
      if ( structKeyExists( arguments.source, key ) ) {
        return arguments.source[ key ];
      }
    }
    return arguments.defaultValue;
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
