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
    variables.ctx.forceUserId = structKeyExists( url, "testUserId" ) && isNumeric( url.testUserId )
      ? val( url.testUserId )
      : 187;

    ensureSessionUser();
    variables.ctx.sessionReady = !structKeyExists( variables.ctx, "sessionError" );
  }

  function run() {
    describe( "Route Builder leg override APIs", function() {
      it( "saves and clears user leg geometry override", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var optionsRes = routeBuilderPost( "routegen_getoptions", {
          direction = "CCW",
          tripType = "POINT_TO_POINT"
        } );
        expect( pickBool( optionsRes, "SUCCESS" ) ).toBeTrue( "routegen_getoptions failed: #serializeJSON(optionsRes)#" );

        var optionsData = ( structKeyExists( optionsRes, "DATA" ) && isStruct( optionsRes.DATA ) )
          ? optionsRes.DATA
          : {};
        var templateRow = ( structKeyExists( optionsData, "template" ) && isStruct( optionsData.template ) )
          ? optionsData.template
          : {};
        var templateCode = trim( toString( pickFirst( templateRow, [ "code", "CODE", "short_code", "SHORT_CODE" ], "" ) ) );
        var startOptions = ( structKeyExists( optionsData, "startOptions" ) && isArray( optionsData.startOptions ) )
          ? optionsData.startOptions
          : [];
        var endOptions = ( structKeyExists( optionsData, "endOptions" ) && isArray( optionsData.endOptions ) )
          ? optionsData.endOptions
          : [];
        expect( len( templateCode ) ).toBeGT( 0, "routegen_getoptions returned no template code: #serializeJSON(optionsRes)#" );
        expect( arrayLen( startOptions ) ).toBeGT( 0, "routegen_getoptions returned no start options: #serializeJSON(optionsRes)#" );
        expect( arrayLen( endOptions ) ).toBeGT( 0, "routegen_getoptions returned no end options: #serializeJSON(optionsRes)#" );

        var startSegmentId = val( pickFirst( startOptions[ 1 ], [ "segment_id", "SEGMENT_ID" ], 0 ) );
        var endChoiceIndex = ( arrayLen( endOptions ) GTE 5 ? 5 : arrayLen( endOptions ) );
        var endSegmentId = val( pickFirst( endOptions[ endChoiceIndex ], [ "segment_id", "SEGMENT_ID" ], 0 ) );
        if ( endSegmentId LTE 0 ) endSegmentId = startSegmentId;
        if ( endSegmentId EQ startSegmentId AND arrayLen( endOptions ) GTE 2 ) {
          endSegmentId = val( pickFirst( endOptions[ 2 ], [ "segment_id", "SEGMENT_ID" ], endSegmentId ) );
        }
        expect( startSegmentId ).toBeGT( 0, "Invalid start segment from routegen_getoptions: #serializeJSON(optionsRes)#" );
        expect( endSegmentId ).toBeGT( 0, "Invalid end segment from routegen_getoptions: #serializeJSON(optionsRes)#" );

        var generateRes = routeBuilderPost( "routegen_generate", {
          template_code = templateCode,
          start_segment_id = startSegmentId,
          end_segment_id = endSegmentId,
          start_date = dateFormat( now(), "yyyy-mm-dd" ),
          direction = "CCW"
        } );
        expect( pickBool( generateRes, "SUCCESS" ) ).toBeTrue( "routegen_generate failed: #serializeJSON(generateRes)#" );

        var routeCode = trim( toString( pickFirst( generateRes, [ "ROUTE_CODE", "route_code", "routeCode" ], "" ) ) );
        expect( len( routeCode ) ).toBeGT( 0, "Missing routeCode from routegen_generate: #serializeJSON(generateRes)#" );

        var editContextRes = routeBuilderPost( "routegen_geteditcontext", {
          route_code = routeCode
        } );
        expect( pickBool( editContextRes, "SUCCESS" ) ).toBeTrue( "routegen_geteditcontext failed: #serializeJSON(editContextRes)#" );

        var inputs = ( structKeyExists( editContextRes, "DATA" ) && isStruct( editContextRes.DATA ) && structKeyExists( editContextRes.DATA, "inputs" ) )
          ? duplicate( editContextRes.DATA.inputs )
          : {};
        inputs.route_code = routeCode;

        var previewRes = routeBuilderPost( "routegen_preview", inputs );
        expect( pickBool( previewRes, "SUCCESS" ) ).toBeTrue( "routegen_preview failed: #serializeJSON(previewRes)#" );

        var legs = ( structKeyExists( previewRes, "DATA" ) && isStruct( previewRes.DATA ) && structKeyExists( previewRes.DATA, "legs" ) && isArray( previewRes.DATA.legs ) )
          ? previewRes.DATA.legs
          : [];
        expect( arrayLen( legs ) ).toBeGT( 0, "routegen_preview returned no legs: #serializeJSON(previewRes)#" );

        var firstLeg = legs[ 1 ];
        var routeLegId = val( pickFirst( firstLeg, [ "route_leg_id", "ROUTE_LEG_ID" ], 0 ) );
        var legOrder = val( pickFirst( firstLeg, [ "order_index", "ORDER_INDEX" ], 0 ) );
        var segmentId = val( pickFirst( firstLeg, [ "segment_id", "SEGMENT_ID" ], 0 ) );

        expect( routeLegId ).toBeGT( 0, "Expected preview leg to include route_leg_id: #serializeJSON(firstLeg)#" );
        expect( legOrder ).toBeGT( 0, "Expected preview leg order index: #serializeJSON(firstLeg)#" );

        var saveRes = routeBuilderPost( "routegen_savelegoverride", {
          route_code = routeCode,
          route_leg_id = routeLegId,
          leg_order = legOrder,
          segment_id = segmentId,
          geometry = [
            { lat = 41.900000, lon = -87.600000 },
            { lat = 42.050000, lon = -87.100000 },
            { lat = 42.200000, lon = -86.700000 }
          ]
        } );
        expect( pickBool( saveRes, "SUCCESS" ) ).toBeTrue( "routegen_savelegoverride failed: #serializeJSON(saveRes)#" );

        var savedNm = val( pickNested( saveRes, [ "DATA", "computed_nm" ], 0 ) );
        expect( savedNm ).toBeGT( 0, "Expected computed_nm > 0 from save: #serializeJSON(saveRes)#" );

        var getRes = routeBuilderPost( "routegen_getleggeometry", {
          route_code = routeCode,
          route_leg_id = routeLegId,
          leg_order = legOrder,
          segment_id = segmentId
        } );
        expect( pickBool( getRes, "SUCCESS" ) ).toBeTrue( "routegen_getleggeometry failed: #serializeJSON(getRes)#" );
        expect( !!pickNested( getRes, [ "DATA", "has_override" ], false ) ).toBeTrue( "Expected has_override=true after save: #serializeJSON(getRes)#" );

        var clearRes = routeBuilderPost( "routegen_clearlegoverride", {
          route_code = routeCode,
          route_leg_id = routeLegId
        } );
        expect( pickBool( clearRes, "SUCCESS" ) ).toBeTrue( "routegen_clearlegoverride failed: #serializeJSON(clearRes)#" );

        var getAfterClearRes = routeBuilderPost( "routegen_getleggeometry", {
          route_code = routeCode,
          route_leg_id = routeLegId,
          leg_order = legOrder,
          segment_id = segmentId
        } );
        expect( pickBool( getAfterClearRes, "SUCCESS" ) ).toBeTrue( "routegen_getleggeometry(after clear) failed: #serializeJSON(getAfterClearRes)#" );
        expect( !!pickNested( getAfterClearRes, [ "DATA", "has_override" ], true ) ).toBeFalse( "Expected has_override=false after clear: #serializeJSON(getAfterClearRes)#" );
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

  private struct function routeBuilderPost( required string action, required struct body ) {
    var urlPath = variables.ctx.baseUrl & "/fpw/api/v1/routeBuilder.cfc?method=handle&action=" & urlEncodedFormat( arguments.action );
    var sessionCookies = getSessionCookies();
    var res = {};

    cfhttp( method="POST", url=urlPath, timeout="60", result="res" ) {
      cfhttpparam( type="header", name="Accept", value="application/json" );
      cfhttpparam( type="header", name="Content-Type", value="application/json; charset=utf-8" );
      cfhttpparam( type="body", value=serializeJSON( arguments.body ) );
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
}
