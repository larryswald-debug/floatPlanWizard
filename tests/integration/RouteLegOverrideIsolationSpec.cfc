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
    describe( "Route Builder exact override isolation", function() {
      it( "allows the same user to keep different exact overrides for the same segment across routes", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var seed = buildRouteSeed();
        var routeA = buildGeneratedRouteContext( seed );
        var routeB = buildGeneratedRouteContext( seed, routeA.segmentId );

        expect( routeA.segmentId ).toBeGT( 0, "Route A did not resolve a segment id: #serializeJSON(routeA)#" );
        expect( routeB.segmentId ).toBe( routeA.segmentId, "Route B did not resolve the same segment as Route A: #serializeJSON(routeB)#" );
        expect( routeA.routeCode EQ routeB.routeCode ).toBeFalse( "Generated routes should be distinct." );

        var geometryA1 = [
          { lat = 41.901000, lon = -87.601000 },
          { lat = 42.061000, lon = -87.071000 },
          { lat = 42.241000, lon = -86.681000 }
        ];
        var geometryB1 = [
          { lat = 41.901000, lon = -87.601000 },
          { lat = 41.951000, lon = -87.401000 },
          { lat = 42.001000, lon = -87.161000 }
        ];
        var geometryA2 = [
          { lat = 41.901000, lon = -87.601000 },
          { lat = 42.141000, lon = -86.981000 },
          { lat = 42.381000, lon = -86.321000 }
        ];

        var saveA1 = saveExactOverride( routeA, geometryA1 );
        var saveB1 = saveExactOverride( routeB, geometryB1 );

        routeA.routeId = val( pickNested( saveA1, [ "DATA", "route_id" ], 0 ) );
        routeB.routeId = val( pickNested( saveB1, [ "DATA", "route_id" ], 0 ) );

        expect( routeA.routeId ).toBeGT( 0, "Route A save did not return route_id: #serializeJSON(saveA1)#" );
        expect( routeB.routeId ).toBeGT( 0, "Route B save did not return route_id: #serializeJSON(saveB1)#" );
        expect( routeA.routeId EQ routeB.routeId ).toBeFalse( "Exact isolation proof requires two distinct route ids." );

        var rowsAfterInitialSave = readExactOverrideRows( variables.ctx.forceUserId, routeA.routeId, routeB.routeId, routeA.segmentId );
        expect( arrayLen( rowsAfterInitialSave ) ).toBe( 2, "Expected two exact override rows after initial save: #serializeJSON(rowsAfterInitialSave)#" );

        var rowA1 = findOverrideRowByRouteId( rowsAfterInitialSave, routeA.routeId );
        var rowB1 = findOverrideRowByRouteId( rowsAfterInitialSave, routeB.routeId );

        expect( structCount( rowA1 ) ).toBeGT( 0, "Route A exact row missing after save: #serializeJSON(rowsAfterInitialSave)#" );
        expect( structCount( rowB1 ) ).toBeGT( 0, "Route B exact row missing after save: #serializeJSON(rowsAfterInitialSave)#" );
        expect( rowA1.routeLegId ).toBe( routeA.routeLegId, "Route A exact row bound to wrong route_leg_id: #serializeJSON(rowA1)#" );
        expect( rowB1.routeLegId ).toBe( routeB.routeLegId, "Route B exact row bound to wrong route_leg_id: #serializeJSON(rowB1)#" );
        expect( rowA1.geometryHash EQ rowB1.geometryHash ).toBeFalse( "Two routes should be able to hold different exact geometry for the same segment." );

        var getA1 = getLegGeometry( routeA );
        var getB1 = getLegGeometry( routeB );
        assertExactGeometryResponse( getA1, geometryA1, "Route A after first save" );
        assertExactGeometryResponse( getB1, geometryB1, "Route B after first save" );

        var saveA2 = saveExactOverride( routeA, geometryA2 );
        expect( pickBool( saveA2, "SUCCESS" ) ).toBeTrue( "Route A second save failed: #serializeJSON(saveA2)#" );

        var rowsAfterRouteAEdit = readExactOverrideRows( variables.ctx.forceUserId, routeA.routeId, routeB.routeId, routeA.segmentId );
        expect( arrayLen( rowsAfterRouteAEdit ) ).toBe( 2, "Expected two exact rows after editing Route A: #serializeJSON(rowsAfterRouteAEdit)#" );

        var rowA2 = findOverrideRowByRouteId( rowsAfterRouteAEdit, routeA.routeId );
        var rowB2 = findOverrideRowByRouteId( rowsAfterRouteAEdit, routeB.routeId );

        expect( rowA2.geometryHash EQ rowA1.geometryHash ).toBeFalse( "Editing Route A should change only Route A exact geometry hash." );
        expect( rowB2.geometryHash ).toBe( rowB1.geometryHash, "Editing Route A must not overwrite Route B exact geometry hash." );
        expect( rowB2.routeLegId ).toBe( rowB1.routeLegId, "Editing Route A must not rebind Route B exact row." );
        expect( rowB2.computedNm ).toBe( rowB1.computedNm, "Editing Route A must not alter Route B computed_nm." );

        var getA2 = getLegGeometry( routeA );
        var getB2 = getLegGeometry( routeB );
        assertExactGeometryResponse( getA2, geometryA2, "Route A after second save" );
        assertExactGeometryResponse( getB2, geometryB1, "Route B after Route A second save" );
      } );
    } );
  }

  private struct function buildRouteSeed() {
    var optionsRes = routeBuilderPost( "routegen_getoptions", {
      direction = "CCW",
      tripType = "POINT_TO_POINT"
    } );
    if ( !pickBool( optionsRes, "SUCCESS" ) ) {
      throw(
        type = "RouteLegOverrideIsolationSpec.Setup",
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
        type = "RouteLegOverrideIsolationSpec.Setup",
        message = "Route options missing required data",
        detail = serializeJSON( optionsRes )
      );
    }

    var startSegmentId = val( pickFirst( startOptions[ 1 ], [ "segment_id", "SEGMENT_ID" ], 0 ) );
    var endChoiceIndex = ( arrayLen( endOptions ) GTE 5 ? 5 : arrayLen( endOptions ) );
    var endSegmentId = val( pickFirst( endOptions[ endChoiceIndex ], [ "segment_id", "SEGMENT_ID" ], 0 ) );
    if ( endSegmentId LTE 0 ) endSegmentId = startSegmentId;
    if ( endSegmentId EQ startSegmentId AND arrayLen( endOptions ) GTE 2 ) {
      endSegmentId = val( pickFirst( endOptions[ 2 ], [ "segment_id", "SEGMENT_ID" ], endSegmentId ) );
    }

    if ( startSegmentId LTE 0 || endSegmentId LTE 0 ) {
      throw(
        type = "RouteLegOverrideIsolationSpec.Setup",
        message = "Invalid start/end segment ids",
        detail = serializeJSON( optionsRes )
      );
    }

    return {
      templateCode = templateCode,
      startSegmentId = startSegmentId,
      endSegmentId = endSegmentId,
      startDate = dateFormat( now(), "yyyy-mm-dd" ),
      direction = "CCW"
    };
  }

  private struct function buildGeneratedRouteContext( required struct seed, numeric requiredSegmentId = 0 ) {
    var generateRes = routeBuilderPost( "routegen_generate", {
      route_name = "Route Isolation " & replace( createUUID(), "-", "", "all" ),
      template_code = arguments.seed.templateCode,
      start_segment_id = arguments.seed.startSegmentId,
      end_segment_id = arguments.seed.endSegmentId,
      start_date = arguments.seed.startDate,
      direction = arguments.seed.direction
    } );
    if ( !pickBool( generateRes, "SUCCESS" ) ) {
      throw(
        type = "RouteLegOverrideIsolationSpec.Setup",
        message = "routegen_generate failed",
        detail = serializeJSON( generateRes )
      );
    }

    var routeCode = trim( toString( pickFirst( generateRes, [ "ROUTE_CODE", "route_code", "routeCode" ], "" ) ) );
    if ( !len( routeCode ) ) {
      throw(
        type = "RouteLegOverrideIsolationSpec.Setup",
        message = "routegen_generate returned no route code",
        detail = serializeJSON( generateRes )
      );
    }

    var editContextRes = routeBuilderPost( "routegen_geteditcontext", {
      route_code = routeCode
    } );
    if ( !pickBool( editContextRes, "SUCCESS" ) ) {
      throw(
        type = "RouteLegOverrideIsolationSpec.Setup",
        message = "routegen_geteditcontext failed",
        detail = serializeJSON( editContextRes )
      );
    }

    var inputs = ( structKeyExists( editContextRes, "DATA" ) && isStruct( editContextRes.DATA ) && structKeyExists( editContextRes.DATA, "inputs" ) )
      ? duplicate( editContextRes.DATA.inputs )
      : {};
    inputs.route_code = routeCode;

    var previewRes = routeBuilderPost( "routegen_preview", inputs );
    if ( !pickBool( previewRes, "SUCCESS" ) ) {
      throw(
        type = "RouteLegOverrideIsolationSpec.Setup",
        message = "routegen_preview failed",
        detail = serializeJSON( previewRes )
      );
    }

    var legs = extractPreviewLegs( previewRes );
    if ( !arrayLen( legs ) ) {
      throw(
        type = "RouteLegOverrideIsolationSpec.Setup",
        message = "routegen_preview returned no legs",
        detail = serializeJSON( previewRes )
      );
    }

    var selectedLeg = {};
    if ( arguments.requiredSegmentId GT 0 ) {
      selectedLeg = findPreviewLegBySegmentId( previewRes, arguments.requiredSegmentId );
    }
    if ( !structCount( selectedLeg ) ) {
      for ( var leg in legs ) {
        if ( val( pickFirst( leg, [ "segment_id", "SEGMENT_ID" ], 0 ) ) GT 0 ) {
          selectedLeg = leg;
          break;
        }
      }
    }
    if ( !structCount( selectedLeg ) ) {
      throw(
        type = "RouteLegOverrideIsolationSpec.Setup",
        message = "No usable preview leg was found",
        detail = serializeJSON( previewRes )
      );
    }

    return {
      routeCode = routeCode,
      routeId = 0,
      routeLegId = val( pickFirst( selectedLeg, [ "route_leg_id", "ROUTE_LEG_ID" ], 0 ) ),
      legOrder = val( pickFirst( selectedLeg, [ "order_index", "ORDER_INDEX" ], 0 ) ),
      segmentId = val( pickFirst( selectedLeg, [ "segment_id", "SEGMENT_ID" ], 0 ) )
    };
  }

  private struct function saveExactOverride( required struct routeCtx, required array geometry ) {
    var res = routeBuilderPost( "routegen_savelegoverride", {
      route_code = arguments.routeCtx.routeCode,
      route_leg_id = arguments.routeCtx.routeLegId,
      leg_order = arguments.routeCtx.legOrder,
      segment_id = arguments.routeCtx.segmentId,
      geometry = arguments.geometry,
      override_fields = {}
    } );
    expect( pickBool( res, "SUCCESS" ) ).toBeTrue( "routegen_savelegoverride failed: #serializeJSON(res)#" );
    return res;
  }

  private struct function getLegGeometry( required struct routeCtx ) {
    var res = routeBuilderPost( "routegen_getleggeometry", {
      route_code = arguments.routeCtx.routeCode,
      route_leg_id = arguments.routeCtx.routeLegId,
      leg_order = arguments.routeCtx.legOrder,
      segment_id = arguments.routeCtx.segmentId
    } );
    expect( pickBool( res, "SUCCESS" ) ).toBeTrue( "routegen_getleggeometry failed: #serializeJSON(res)#" );
    return res;
  }

  private void function assertExactGeometryResponse( required struct geometryRes, required array expectedGeometry, required string label ) {
    var data = structKeyExists( arguments.geometryRes, "DATA" ) && isStruct( arguments.geometryRes.DATA )
      ? arguments.geometryRes.DATA
      : {};
    var points = structKeyExists( data, "points" ) && isArray( data.points ) ? data.points : [];

    expect( !!pickFirst( data, [ "has_override", "HAS_OVERRIDE" ], false ) ).toBeTrue( "#arguments.label# should report has_override=true: #serializeJSON(arguments.geometryRes)#" );
    expect( !!pickFirst( data, [ "has_effective_override", "HAS_EFFECTIVE_OVERRIDE" ], false ) ).toBeTrue( "#arguments.label# should report has_effective_override=true: #serializeJSON(arguments.geometryRes)#" );
    expect( trim( toString( pickFirst( data, [ "source", "SOURCE" ], "" ) ) ) ).toBe( "user_override", "#arguments.label# should resolve exact override source: #serializeJSON(arguments.geometryRes)#" );
    expect( arrayLen( points ) ).toBe( arrayLen( arguments.expectedGeometry ), "#arguments.label# point count mismatch: #serializeJSON(arguments.geometryRes)#" );
    expect( val( points[ 1 ].lat ) ).toBe( val( arguments.expectedGeometry[ 1 ].lat ), "#arguments.label# first point lat mismatch." );
    expect( val( points[ 1 ].lon ) ).toBe( val( arguments.expectedGeometry[ 1 ].lon ), "#arguments.label# first point lon mismatch." );
    expect( val( points[ arrayLen( points ) ].lat ) ).toBe( val( arguments.expectedGeometry[ arrayLen( arguments.expectedGeometry ) ].lat ), "#arguments.label# last point lat mismatch." );
    expect( val( points[ arrayLen( points ) ].lon ) ).toBe( val( arguments.expectedGeometry[ arrayLen( arguments.expectedGeometry ) ].lon ), "#arguments.label# last point lon mismatch." );
  }

  private array function readExactOverrideRows( required numeric userId, required numeric routeIdA, required numeric routeIdB, required numeric segmentId ) {
    var q = queryExecute(
      "SELECT
          route_id,
          route_leg_id,
          route_leg_order,
          segment_id,
          computed_nm,
          MD5(COALESCE(geometry_json, '')) AS geometry_md5
       FROM route_leg_user_overrides
       WHERE user_id = :uid
         AND segment_id = :segmentId
         AND route_id IN (:routeIdA, :routeIdB)
       ORDER BY route_id ASC",
      {
        uid = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        segmentId = { value = arguments.segmentId, cfsqltype = "cf_sql_integer" },
        routeIdA = { value = arguments.routeIdA, cfsqltype = "cf_sql_integer" },
        routeIdB = { value = arguments.routeIdB, cfsqltype = "cf_sql_integer" }
      },
      { datasource = application.dsn }
    );
    var out = [];
    for ( var i = 1; i LTE q.recordCount; i++ ) {
      arrayAppend( out, {
        routeId = val( q.route_id[ i ] ),
        routeLegId = val( q.route_leg_id[ i ] ),
        routeLegOrder = val( q.route_leg_order[ i ] ),
        segmentId = val( q.segment_id[ i ] ),
        computedNm = val( q.computed_nm[ i ] ),
        geometryHash = lCase( trim( toString( q.geometry_md5[ i ] ) ) )
      } );
    }
    return out;
  }

  private struct function findOverrideRowByRouteId( required array rows, required numeric routeId ) {
    for ( var row in arguments.rows ) {
      if ( val( row.routeId ) EQ arguments.routeId ) {
        return row;
      }
    }
    return {};
  }

  private array function extractPreviewLegs( required struct previewRes ) {
    if (
      structKeyExists( arguments.previewRes, "DATA" )
      && isStruct( arguments.previewRes.DATA )
      && structKeyExists( arguments.previewRes.DATA, "legs" )
      && isArray( arguments.previewRes.DATA.legs )
    ) {
      return arguments.previewRes.DATA.legs;
    }
    return [];
  }

  private struct function findPreviewLegBySegmentId( required struct previewRes, required numeric segmentId ) {
    var legs = extractPreviewLegs( arguments.previewRes );
    for ( var leg in legs ) {
      if ( val( pickFirst( leg, [ "segment_id", "SEGMENT_ID" ], 0 ) ) EQ arguments.segmentId ) {
        return leg;
      }
    }
    return {};
  }

  private void function ensureSessionUser() {
    try {
      if ( !structKeyExists( session, "user" ) || !isStruct( session.user ) ) {
        session.user = {};
      }
      if ( !structKeyExists( session.user, "userId" ) || !isNumeric( session.user.userId ) || val( session.user.userId ) LTE 0 ) {
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

  private struct function routeBuilderPost( required string action, required struct body ) {
    var urlPath = variables.ctx.baseUrl & "/fpw/api/v1/routeBuilder.cfc?method=handle&action=" & urlEncodedFormat( arguments.action );
    var sessionCookies = getSessionCookies();
    var testHeaderUserId = ( structKeyExists( variables, "ctx" ) && structKeyExists( variables.ctx, "forceUserId" ) ) ? val( variables.ctx.forceUserId ) : 0;
    var res = {};

    cfhttp( method = "POST", url = urlPath, timeout = "60", result = "res" ) {
      cfhttpparam( type = "header", name = "Accept", value = "application/json" );
      cfhttpparam( type = "header", name = "Content-Type", value = "application/json; charset=utf-8" );
      if ( testHeaderUserId GT 0 ) {
        cfhttpparam( type = "header", name = "X-FPW-Test-UserId", value = toString( testHeaderUserId ) );
      }
      cfhttpparam( type = "body", value = serializeJSON( arguments.body ) );
      for ( var cookiePair in sessionCookies ) {
        cfhttpparam( type = "cookie", name = cookiePair.name, value = cookiePair.value );
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
      return { success = false, message = "JSON was not a struct", raw = raw, parsed = parsed };
    } catch ( any e ) {
      return {
        success = false,
        message = "Failed to decode JSON response",
        raw = raw,
        error = e.message
      };
    }
  }

  private any function pickFirst( required struct source, required array keys, any defaultValue = "" ) {
    for ( var key in arguments.keys ) {
      if ( structKeyExists( arguments.source, key ) ) {
        return arguments.source[ key ];
      }
    }
    return arguments.defaultValue;
  }

  private any function pickNested( required struct source, required array path, any defaultValue = "" ) {
    var cursor = arguments.source;
    for ( var key in arguments.path ) {
      if ( !isStruct( cursor ) || !structKeyExists( cursor, key ) ) {
        return arguments.defaultValue;
      }
      cursor = cursor[ key ];
    }
    return cursor;
  }

  private boolean function pickBool( required struct source, required string key, boolean defaultValue = false ) {
    if ( structKeyExists( arguments.source, arguments.key ) ) {
      return !!arguments.source[ arguments.key ];
    }
    return arguments.defaultValue;
  }
}
