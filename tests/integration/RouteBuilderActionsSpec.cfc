component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.ctx = {
      createdRouteCodes = []
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
    variables.ctx.routeBuilderActionBase = variables.ctx.baseUrl & "/fpw/api/v1/routeBuilder.cfc?method=handle&action=";
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

    for ( var i = 1; i LTE arrayLen( variables.ctx.createdRouteCodes ); i++ ) {
      routeBuilderPost( "deleteRoute", { routeCode = variables.ctx.createdRouteCodes[ i ] } );
    }
  }

  function run() {
    describe( "Route Builder API action coverage", function() {
      it( "lists leg overrides before and after save/clear", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var legCtx = buildRouteLegContext();
        expect( legCtx.routeLegId ).toBeGT( 0, "route leg setup failed: #serializeJSON(legCtx)#" );

        var listBefore = routeBuilderPost( "routegen_listlegoverrides", {
          route_code = legCtx.routeCode
        } );
        expect( pickBool( listBefore, "SUCCESS" ) ).toBeTrue( "routegen_listlegoverrides before save failed: #serializeJSON(listBefore)#" );

        var saveRes = routeBuilderPost( "routegen_savelegoverride", {
          route_code = legCtx.routeCode,
          route_leg_id = legCtx.routeLegId,
          leg_order = legCtx.legOrder,
          segment_id = legCtx.segmentId,
          geometry = [
            { lat = 41.890000, lon = -87.620000 },
            { lat = 42.040000, lon = -87.200000 },
            { lat = 42.190000, lon = -86.900000 }
          ]
        } );
        expect( pickBool( saveRes, "SUCCESS" ) ).toBeTrue( "routegen_savelegoverride failed: #serializeJSON(saveRes)#" );

        var listAfterSave = routeBuilderPost( "routegen_listlegoverrides", {
          route_code = legCtx.routeCode
        } );
        expect( pickBool( listAfterSave, "SUCCESS" ) ).toBeTrue( "routegen_listlegoverrides after save failed: #serializeJSON(listAfterSave)#" );
        expect( listContainsLeg( listAfterSave, legCtx.routeLegId ) ).toBeTrue( "Saved leg override not found in list: #serializeJSON(listAfterSave)#" );

        var clearRes = routeBuilderPost( "routegen_clearlegoverride", {
          route_code = legCtx.routeCode,
          route_leg_id = legCtx.routeLegId
        } );
        expect( pickBool( clearRes, "SUCCESS" ) ).toBeTrue( "routegen_clearlegoverride failed: #serializeJSON(clearRes)#" );

        var listAfterClear = routeBuilderPost( "routegen_listlegoverrides", {
          route_code = legCtx.routeCode
        } );
        expect( pickBool( listAfterClear, "SUCCESS" ) ).toBeTrue( "routegen_listlegoverrides after clear failed: #serializeJSON(listAfterClear)#" );
        expect( listContainsLeg( listAfterClear, legCtx.routeLegId ) ).toBeFalse( "Cleared leg override still present: #serializeJSON(listAfterClear)#" );
      } );

      it( "returns lock detail payload for a selected leg", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var legCtx = buildRouteLegContext();
        var locksRes = routeBuilderPost( "routegen_getleglocks", {
          route_code = legCtx.routeCode,
          template_code = legCtx.templateCode,
          route_leg_id = legCtx.routeLegId,
          leg_order = legCtx.legOrder,
          segment_id = legCtx.segmentId
        } );
        expect( pickBool( locksRes, "SUCCESS" ) ).toBeTrue( "routegen_getleglocks failed: #serializeJSON(locksRes)#" );

        var data = structKeyExists( locksRes, "DATA" ) && isStruct( locksRes.DATA ) ? locksRes.DATA : {};
        expect( isStruct( data ) ).toBeTrue( "routegen_getleglocks missing DATA object: #serializeJSON(locksRes)#" );
        expect( structKeyExists( data, "lock_count" ) || structKeyExists( data, "LOCK_COUNT" ) ).toBeTrue( "lock_count missing from lock payload: #serializeJSON(locksRes)#" );
        expect( structKeyExists( data, "locks" ) || structKeyExists( data, "LOCKS" ) ).toBeTrue( "locks array missing from lock payload: #serializeJSON(locksRes)#" );
      } );

      it( "updates an existing route from edit-context inputs", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var legCtx = buildRouteLegContext();
        var updateInput = duplicate( legCtx.inputs );
        updateInput.route_code = legCtx.routeCode;
        updateInput.route_name = "Route Update Spec " & uniqueSuffix();
        updateInput.direction = ( uCase( toString( updateInput.direction ) ) EQ "CW" ? "CCW" : "CW" );

        var updateRes = routeBuilderPost( "routegen_update", updateInput );
        expect( pickBool( updateRes, "SUCCESS" ) ).toBeTrue( "routegen_update failed: #serializeJSON(updateRes)#" );
        expect( toString( pickFirst( updateRes, [ "ROUTE_CODE", "route_code", "routeCode" ], "" ) ) ).toBe( legCtx.routeCode );

        var editContextAfter = routeBuilderPost( "routegen_geteditcontext", {
          route_code = legCtx.routeCode
        } );
        expect( pickBool( editContextAfter, "SUCCESS" ) ).toBeTrue( "routegen_geteditcontext failed after update: #serializeJSON(editContextAfter)#" );
      } );

      it( "returns route-not-found and unauthorized errors for guarded actions", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var badRouteRes = routeBuilderPost( "routegen_update", {
          route_code = "USER_ROUTE_999999_DOES_NOT_EXIST",
          template_code = "GL_REUSE_V2",
          start_segment_id = 1,
          end_segment_id = 1,
          start_date = dateFormat( now(), "yyyy-mm-dd" ),
          direction = "CCW"
        } );
        expect( pickBool( badRouteRes, "SUCCESS" ) ).toBeFalse( "routegen_update should reject unknown route: #serializeJSON(badRouteRes)#" );
        expect( findNoCase( "route not found", lCase( toString( pickFirst( badRouteRes, [ "MESSAGE", "message" ], "" ) ) ) ) GT 0 ).toBeTrue();

        var anonListRes = routeBuilderPostAnonymous( "routegen_listlegoverrides", {
          route_code = "USER_ROUTE_999999_FAKE"
        } );
        expect( pickBool( anonListRes, "SUCCESS" ) ).toBeFalse( "anonymous routegen_listlegoverrides should fail: #serializeJSON(anonListRes)#" );
        expect( !!pickFirst( anonListRes, [ "AUTH", "auth" ], true ) ).toBeFalse( "anonymous call should return AUTH=false: #serializeJSON(anonListRes)#" );
      } );
    } );
  }

  private struct function buildRouteLegContext() {
    var optionsRes = routeBuilderPost( "routegen_getoptions", {
      direction = "CCW",
      tripType = "POINT_TO_POINT"
    } );
    if ( !pickBool( optionsRes, "SUCCESS" ) ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "routegen_getoptions failed",
        detail = serializeJSON( optionsRes )
      );
    }

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

    if ( !len( templateCode ) || !arrayLen( startOptions ) || !arrayLen( endOptions ) ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "Route options missing required fields",
        detail = serializeJSON( optionsRes )
      );
    }

    var startSegmentId = val( pickFirst( startOptions[ 1 ], [ "segment_id", "SEGMENT_ID" ], 0 ) );
    var endChoiceIndex = ( arrayLen( endOptions ) GTE 4 ? 4 : arrayLen( endOptions ) );
    var endSegmentId = val( pickFirst( endOptions[ endChoiceIndex ], [ "segment_id", "SEGMENT_ID" ], 0 ) );
    if ( endSegmentId LTE 0 ) endSegmentId = startSegmentId;
    if ( endSegmentId EQ startSegmentId AND arrayLen( endOptions ) GTE 2 ) {
      endSegmentId = val( pickFirst( endOptions[ 2 ], [ "segment_id", "SEGMENT_ID" ], endSegmentId ) );
    }

    var generateRes = routeBuilderPost( "routegen_generate", {
      template_code = templateCode,
      start_segment_id = startSegmentId,
      end_segment_id = endSegmentId,
      start_date = dateFormat( now(), "yyyy-mm-dd" ),
      direction = "CCW"
    } );
    if ( !pickBool( generateRes, "SUCCESS" ) ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "routegen_generate failed",
        detail = serializeJSON( generateRes )
      );
    }

    var routeCode = trim( toString( pickFirst( generateRes, [ "ROUTE_CODE", "route_code", "routeCode" ], "" ) ) );
    if ( !len( routeCode ) ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "routegen_generate returned no route code",
        detail = serializeJSON( generateRes )
      );
    }
    rememberCreatedRouteCode( routeCode );

    var editContextRes = routeBuilderPost( "routegen_geteditcontext", {
      route_code = routeCode
    } );
    if ( !pickBool( editContextRes, "SUCCESS" ) ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "routegen_geteditcontext failed",
        detail = serializeJSON( editContextRes )
      );
    }

    var inputs = (
      structKeyExists( editContextRes, "DATA" )
      && isStruct( editContextRes.DATA )
      && structKeyExists( editContextRes.DATA, "inputs" )
      && isStruct( editContextRes.DATA.inputs )
    ) ? duplicate( editContextRes.DATA.inputs ) : {};
    inputs.route_code = routeCode;

    var previewRes = routeBuilderPost( "routegen_preview", inputs );
    if ( !pickBool( previewRes, "SUCCESS" ) ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "routegen_preview failed",
        detail = serializeJSON( previewRes )
      );
    }

    var legs = ( structKeyExists( previewRes, "DATA" ) && isStruct( previewRes.DATA ) && structKeyExists( previewRes.DATA, "legs" ) && isArray( previewRes.DATA.legs ) )
      ? previewRes.DATA.legs
      : [];
    if ( !arrayLen( legs ) ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "routegen_preview returned no legs",
        detail = serializeJSON( previewRes )
      );
    }

    var firstLeg = legs[ 1 ];
    return {
      routeCode = routeCode,
      templateCode = templateCode,
      routeLegId = val( pickFirst( firstLeg, [ "route_leg_id", "ROUTE_LEG_ID" ], 0 ) ),
      legOrder = val( pickFirst( firstLeg, [ "order_index", "ORDER_INDEX" ], 0 ) ),
      segmentId = val( pickFirst( firstLeg, [ "segment_id", "SEGMENT_ID" ], 0 ) ),
      inputs = inputs
    };
  }

  private boolean function listContainsLeg( required struct payload, required numeric routeLegId ) {
    var data = structKeyExists( arguments.payload, "DATA" ) && isStruct( arguments.payload.DATA )
      ? arguments.payload.DATA
      : {};
    var overrides = structKeyExists( data, "overrides" ) && isArray( data.overrides )
      ? data.overrides
      : [];
    for ( var row in overrides ) {
      if ( !isStruct( row ) ) continue;
      var legId = val( pickFirst( row, [ "route_leg_id", "ROUTE_LEG_ID" ], 0 ) );
      if ( legId EQ arguments.routeLegId ) return true;
    }
    return false;
  }

  private void function rememberCreatedRouteCode( required string routeCode ) {
    var normalized = trim( arguments.routeCode );
    if ( !len( normalized ) ) return;
    if ( arrayFindNoCase( variables.ctx.createdRouteCodes, normalized ) EQ 0 ) {
      arrayAppend( variables.ctx.createdRouteCodes, normalized );
    }
  }

  private void function ensureSessionUser() {
    try {
      if ( !structKeyExists( session, "user" ) || !isStruct( session.user ) ) {
        session.user = {};
      }
      if ( !structKeyExists( session.user, "userId" ) || !isNumeric( session.user.userId ) ) {
        session.user.userId = variables.ctx.forceUserId;
        session.user.id = session.user.userId;
        session.user.USERID = session.user.userId;
      }
    } catch ( any e ) {
      variables.ctx.sessionError = e.message;
    }
  }

  private struct function routeBuilderPost( required string action, struct body = {} ) {
    return apiPostJson( variables.ctx.routeBuilderActionBase & arguments.action, body, true );
  }

  private struct function routeBuilderPostAnonymous( required string action, struct body = {} ) {
    return apiPostJson( variables.ctx.routeBuilderActionBase & arguments.action, body, false );
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

  private struct function apiPostJson( required string url, struct body = {}, boolean includeCookies = true ) {
    var payload = isStruct( arguments.body ) ? arguments.body : {};
    var sessionCookies = arguments.includeCookies ? getSessionCookies() : [];
    var res = {};
    cfhttp( method="POST", url=arguments.url, timeout="60", result="res" ) {
      cfhttpparam( type="header", name="Accept", value="application/json" );
      cfhttpparam( type="header", name="Content-Type", value="application/json; charset=utf-8" );
      cfhttpparam( type="body", value=serializeJSON( payload ) );
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

  private string function uniqueSuffix() {
    return dateTimeFormat( now(), "yyyymmddHHnnss" ) & "-" & right( createUUID(), 6 );
  }

}
