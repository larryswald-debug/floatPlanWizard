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
    variables.ctx.generateRouteUrl = variables.ctx.baseUrl & "/fpw/api/v1/routeBuilder.cfc?method=handle&action=generateRoute";
    variables.ctx.buildFloatPlansUrl = variables.ctx.baseUrl & "/fpw/api/v1/routeBuilder.cfc?method=handle&action=buildFloatPlansFromRoute";
    variables.ctx.floatPlanBootstrapUrl = variables.ctx.baseUrl & "/fpw/api/v1/floatplan.cfc?method=handle&action=bootstrap";
    variables.ctx.floatPlanDeleteUrl = variables.ctx.baseUrl & "/fpw/api/v1/floatplan.cfc?method=handle&action=delete";
    variables.ctx.forceVesselId = structKeyExists( url, "testVesselId" ) && isNumeric( url.testVesselId )
      ? val( url.testVesselId )
      : 0;
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
    var i = 0;
    for ( i = 1; i LTE arrayLen( variables.ctx.createdPlanIds ); i++ ) {
      apiPostJson( variables.ctx.floatPlanDeleteUrl, { floatPlanId = variables.ctx.createdPlanIds[ i ] } );
    }
  }

  function run() {
    describe( "Route Generator 2.0 route-to-floatplan builder", function() {
      it( "builds draft float plans from a route instance and supports explicit rebuild", function() {
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
        var routeCode = trim( toString( pickFirst( genRes, [ "ROUTE_CODE", "route_code", "routeCode" ], "" ) ) );
        expect( len( routeCode ) ).toBeGT( 0, "Expected ROUTE_CODE in generateRoute response: #serializeJSON(genRes)#" );

        var buildRes = apiPostJson( variables.ctx.buildFloatPlansUrl, {
          routeCode = routeCode,
          mode = "DAILY",
          vesselId = vesselId
        } );
        expect( pickBool( buildRes, "SUCCESS" ) ).toBeTrue( "buildFloatPlansFromRoute failed: #serializeJSON(buildRes)#" );

        var createdCount = val( pickFirst( buildRes, [ "CREATED_COUNT", "created_count" ], 0 ) );
        expect( createdCount ).toBeGT( 0, "Expected CREATED_COUNT > 0: #serializeJSON(buildRes)#" );

        var firstPlanId = extractFirstArrayId( buildRes, [ "FLOATPLAN_IDS", "floatplan_ids" ] );
        expect( firstPlanId ).toBeGT( 0, "Expected FLOATPLAN_IDS in response: #serializeJSON(buildRes)#" );
        stashCreatedIds( buildRes );

        var bootRes = apiGetJson( variables.ctx.floatPlanBootstrapUrl & "&id=" & firstPlanId );
        var plan = structKeyExists( bootRes, "FLOATPLAN" ) && isStruct( bootRes.FLOATPLAN ) ? bootRes.FLOATPLAN : {};
        expect( isStruct( plan ) ).toBeTrue( "Could not extract FLOATPLAN from bootstrap response: #serializeJSON(bootRes)#" );
        expect( val( pickFirst( plan, [ "ROUTE_INSTANCE_ID", "route_instance_id" ], 0 ) ) ).toBe( routeInstanceId );
        expect( val( pickFirst( plan, [ "ROUTE_DAY_NUMBER", "route_day_number" ], 0 ) ) ).toBeGT( 0 );

        var secondBuildRes = apiPostJson( variables.ctx.buildFloatPlansUrl, {
          routeCode = routeCode,
          mode = "DAILY",
          vesselId = vesselId
        } );
        expect( pickBool( secondBuildRes, "SUCCESS" ) ).toBeFalse( "Expected duplicate build to fail: #serializeJSON(secondBuildRes)#" );
        expect( uCase( toString( pickNested( secondBuildRes, [ "ERROR", "CODE" ], "" ) ) ) ).toBe( "FLOATPLANS_ALREADY_EXIST" );

        var rebuildRes = apiPostJson( variables.ctx.buildFloatPlansUrl, {
          routeCode = routeCode,
          mode = "DAILY",
          vesselId = vesselId,
          rebuild = true
        } );
        expect( pickBool( rebuildRes, "SUCCESS" ) ).toBeTrue( "Expected rebuild=true to succeed: #serializeJSON(rebuildRes)#" );
        expect( val( pickFirst( rebuildRes, [ "CREATED_COUNT", "created_count" ], 0 ) ) ).toBeGT( 0 );
        stashCreatedIds( rebuildRes );
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

  private void function stashCreatedIds( required struct payload ) {
    var ids = pickFirst( arguments.payload, [ "FLOATPLAN_IDS", "floatplan_ids" ], [] );
    if ( !isArray( ids ) ) return;
    for ( var planId in ids ) {
      var n = val( planId );
      if ( n LTE 0 ) continue;
      if ( arrayFind( variables.ctx.createdPlanIds, n ) EQ 0 ) {
        arrayAppend( variables.ctx.createdPlanIds, n );
      }
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

  private any function pickNested( required struct source, required array keys, any fallback = "" ) {
    var cur = arguments.source;
    for ( var key in arguments.keys ) {
      if ( !isStruct( cur ) || !structKeyExists( cur, key ) ) {
        return arguments.fallback;
      }
      cur = cur[ key ];
    }
    return cur;
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

  private numeric function extractFirstArrayId( required struct payload, required array keys ) {
    var values = pickFirst( arguments.payload, arguments.keys, [] );
    if ( !isArray( values ) || !arrayLen( values ) ) return 0;
    return val( values[ 1 ] );
  }

}
