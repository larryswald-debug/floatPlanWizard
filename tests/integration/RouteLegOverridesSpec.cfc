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
          route_name = "Route Leg Override " & replace( createUUID(), "-", "", "all" ),
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

      it( "saves and clears generator segment overrides in canonical table", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var previewCtx = buildGeneratorPreviewContext();
        if ( !previewCtx.hasCleanSegment ) {
          skip( "No preview leg without an existing segment override was available for this user." );
        }

        var saveRes = routeBuilderPost( "routegen_savesegmentoverride", {
          segment_id = previewCtx.segmentId,
          geometry = [
            { lat = 41.860000, lon = -87.610000 },
            { lat = 41.970000, lon = -87.180000 },
            { lat = 42.120000, lon = -86.830000 }
          ],
          override_fields = {}
        } );
        expect( pickBool( saveRes, "SUCCESS" ) ).toBeTrue( "routegen_savesegmentoverride failed: #serializeJSON(saveRes)#" );
        expect( !!pickNested( saveRes, [ "DATA", "has_effective_override" ], false ) ).toBeTrue( "Expected effective override truth from segment save: #serializeJSON(saveRes)#" );

        var saveState = readSegmentOverrideDbState( variables.ctx.forceUserId, previewCtx.segmentId );
        expect( saveState.canonicalCount ).toBe( 1, "Segment override should persist in user_segment_overrides: #serializeJSON(saveState)#" );
        expect( saveState.legacyCount ).toBe( 0, "Segment override should not create a legacy synthetic route_id=0 row: #serializeJSON(saveState)#" );

        var previewAfterSaveRes = routeBuilderPost( "routegen_preview", duplicate( previewCtx.input ) );
        expect( pickBool( previewAfterSaveRes, "SUCCESS" ) ).toBeTrue( "routegen_preview(after segment save) failed: #serializeJSON(previewAfterSaveRes)#" );
        var previewSavedLeg = findPreviewLegBySegmentId( previewAfterSaveRes, previewCtx.segmentId );
        expect( structCount( previewSavedLeg ) ).toBeGT( 0, "Could not find saved segment leg in preview payload: #serializeJSON(previewAfterSaveRes)#" );
        expect( !!pickFirst( previewSavedLeg, [ "has_effective_override", "HAS_EFFECTIVE_OVERRIDE" ], false ) ).toBeTrue( "Preview leg should surface effective override after segment save: #serializeJSON(previewSavedLeg)#" );
        expect( trim( toString( pickFirst( previewSavedLeg, [ "override_source", "OVERRIDE_SOURCE" ], "" ) ) ) ).toBe( "user_segment", "Preview leg should identify segment override source: #serializeJSON(previewSavedLeg)#" );

        var clearRes = routeBuilderPost( "routegen_clearsegmentoverride", {
          segment_id = previewCtx.segmentId
        } );
        expect( pickBool( clearRes, "SUCCESS" ) ).toBeTrue( "routegen_clearsegmentoverride failed: #serializeJSON(clearRes)#" );

        var clearState = readSegmentOverrideDbState( variables.ctx.forceUserId, previewCtx.segmentId );
        expect( clearState.canonicalCount ).toBe( 0, "Segment override clear should remove canonical row: #serializeJSON(clearState)#" );
        expect( clearState.legacyCount ).toBe( 0, "Segment override clear should leave no legacy synthetic row: #serializeJSON(clearState)#" );

        var previewAfterClearRes = routeBuilderPost( "routegen_preview", duplicate( previewCtx.input ) );
        expect( pickBool( previewAfterClearRes, "SUCCESS" ) ).toBeTrue( "routegen_preview(after segment clear) failed: #serializeJSON(previewAfterClearRes)#" );
        var previewClearedLeg = findPreviewLegBySegmentId( previewAfterClearRes, previewCtx.segmentId );
        expect( structCount( previewClearedLeg ) ).toBeGT( 0, "Could not find cleared segment leg in preview payload: #serializeJSON(previewAfterClearRes)#" );
        expect( !!pickFirst( previewClearedLeg, [ "has_effective_override", "HAS_EFFECTIVE_OVERRIDE" ], true ) ).toBeFalse( "Preview leg should return to default truth after segment clear: #serializeJSON(previewClearedLeg)#" );
      } );

      it( "applies request-scoped draft preview truth and promotes drafts on generate", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var previewCtx = buildGeneratorPreviewContext();
        if ( !previewCtx.hasCleanSegment ) {
          skip( "No preview leg without an existing segment override was available for this user." );
        }

        var draftPayload = buildLegOverrideDraftPayload(
          previewCtx.segmentId,
          [
            { lat = 41.810000, lon = -87.640000 },
            { lat = 41.940000, lon = -87.160000 },
            { lat = 42.140000, lon = -86.780000 }
          ]
        );
        var draftPreviewInput = duplicate( previewCtx.input );
        draftPreviewInput.leg_override_drafts = draftPayload;

        var previewWithDraftRes = routeBuilderPost( "routegen_preview", draftPreviewInput );
        expect( pickBool( previewWithDraftRes, "SUCCESS" ) ).toBeTrue( "routegen_preview(with draft override) failed: #serializeJSON(previewWithDraftRes)#" );
        var previewDraftLeg = findPreviewLegBySegmentId( previewWithDraftRes, previewCtx.segmentId );
        expect( structCount( previewDraftLeg ) ).toBeGT( 0, "Could not find draft leg in preview payload: #serializeJSON(previewWithDraftRes)#" );
        expect( !!pickFirst( previewDraftLeg, [ "has_user_override", "HAS_USER_OVERRIDE" ], true ) ).toBeFalse( "Draft preview should not report an exact route override: #serializeJSON(previewDraftLeg)#" );
        expect( !!pickFirst( previewDraftLeg, [ "has_effective_override", "HAS_EFFECTIVE_OVERRIDE" ], false ) ).toBeTrue( "Draft preview should report effective override truth: #serializeJSON(previewDraftLeg)#" );
        expect( trim( toString( pickFirst( previewDraftLeg, [ "override_source", "OVERRIDE_SOURCE" ], "" ) ) ) ).toBe( "draft_override", "Draft preview should report draft override source: #serializeJSON(previewDraftLeg)#" );

        var draftGeometryInput = duplicate( draftPreviewInput );
        draftGeometryInput.leg_order = previewCtx.legOrder;
        draftGeometryInput.segment_id = previewCtx.segmentId;
        var draftGeometryRes = routeBuilderPost( "routegen_getleggeometry", draftGeometryInput );
        expect( pickBool( draftGeometryRes, "SUCCESS" ) ).toBeTrue( "routegen_getleggeometry(with draft override) failed: #serializeJSON(draftGeometryRes)#" );
        expect( !!pickNested( draftGeometryRes, [ "DATA", "has_override" ], true ) ).toBeFalse( "Draft geometry should not claim an exact route override: #serializeJSON(draftGeometryRes)#" );
        expect( !!pickNested( draftGeometryRes, [ "DATA", "has_effective_override" ], false ) ).toBeTrue( "Draft geometry should report effective override truth: #serializeJSON(draftGeometryRes)#" );
        expect( trim( toString( pickNested( draftGeometryRes, [ "DATA", "source" ], "" ) ) ) ).toBe( "draft_override", "Draft geometry should report draft override source: #serializeJSON(draftGeometryRes)#" );

        var generateRes = routeBuilderPost( "routegen_generate", draftPreviewInput );
        expect( pickBool( generateRes, "SUCCESS" ) ).toBeTrue( "routegen_generate(with draft override) failed: #serializeJSON(generateRes)#" );
        var generatedRouteCode = trim( toString( pickFirst( generateRes, [ "ROUTE_CODE", "route_code", "routeCode" ], "" ) ) );
        var generatedRouteId = val(
          structKeyExists( generateRes, "ROUTE_ID" )
            ? generateRes.ROUTE_ID
            : pickNested( generateRes, [ "DATA", "route_id" ], 0 )
        );
        expect( len( generatedRouteCode ) ).toBeGT( 0, "Generated route code missing from draft generate response: #serializeJSON(generateRes)#" );
        expect( generatedRouteId ).toBeGT( 0, "Generated route id missing from draft generate response: #serializeJSON(generateRes)#" );

        var exactOverrideCount = readExactRouteOverrideCount( variables.ctx.forceUserId, generatedRouteId, previewCtx.segmentId );
        expect( exactOverrideCount ).toBe( 1, "Draft generate should persist one exact route-leg override row: routeId=#generatedRouteId# segmentId=#previewCtx.segmentId#" );

        var segmentStateAfterGenerate = readSegmentOverrideDbState( variables.ctx.forceUserId, previewCtx.segmentId );
        expect( segmentStateAfterGenerate.canonicalCount ).toBe( 0, "Draft generate should not create a reusable segment override row: #serializeJSON(segmentStateAfterGenerate)#" );
        expect( segmentStateAfterGenerate.legacyCount ).toBe( 0, "Draft generate should not create a legacy synthetic segment override row: #serializeJSON(segmentStateAfterGenerate)#" );

        var editContextRes = routeBuilderPost( "routegen_geteditcontext", {
          route_code = generatedRouteCode
        } );
        expect( pickBool( editContextRes, "SUCCESS" ) ).toBeTrue( "routegen_geteditcontext(after draft generate) failed: #serializeJSON(editContextRes)#" );

        var savedInputs = ( structKeyExists( editContextRes, "DATA" ) && isStruct( editContextRes.DATA ) && structKeyExists( editContextRes.DATA, "inputs" ) )
          ? duplicate( editContextRes.DATA.inputs )
          : {};
        savedInputs.route_code = generatedRouteCode;

        var savedPreviewRes = routeBuilderPost( "routegen_preview", savedInputs );
        expect( pickBool( savedPreviewRes, "SUCCESS" ) ).toBeTrue( "routegen_preview(after draft generate) failed: #serializeJSON(savedPreviewRes)#" );
        var savedLeg = findPreviewLegBySegmentId( savedPreviewRes, previewCtx.segmentId );
        expect( structCount( savedLeg ) ).toBeGT( 0, "Could not find generated draft leg in saved preview payload: #serializeJSON(savedPreviewRes)#" );
        expect( !!pickFirst( savedLeg, [ "has_user_override", "HAS_USER_OVERRIDE" ], false ) ).toBeTrue( "Generated draft leg should become an exact route override after save: #serializeJSON(savedLeg)#" );
        expect( !!pickFirst( savedLeg, [ "has_effective_override", "HAS_EFFECTIVE_OVERRIDE" ], false ) ).toBeTrue( "Generated draft leg should keep effective override truth after save: #serializeJSON(savedLeg)#" );
        expect( trim( toString( pickFirst( savedLeg, [ "override_source", "OVERRIDE_SOURCE" ], "" ) ) ) ).toBe( "user_override", "Generated draft leg should report exact route override source after save: #serializeJSON(savedLeg)#" );
      } );

      it( "rejects malformed geometry and invalid leg references", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var legCtx = buildRouteLegContext();
        expect( legCtx.routeLegId ).toBeGT( 0, "Setup route_leg_id missing: #serializeJSON(legCtx)#" );

        var malformedRes = routeBuilderPost( "routegen_savelegoverride", {
          route_code = legCtx.routeCode,
          route_leg_id = legCtx.routeLegId,
          leg_order = legCtx.legOrder,
          segment_id = legCtx.segmentId,
          geometry = { lat = 41.9, lon = -87.6 }
        } );
        expect( pickBool( malformedRes, "SUCCESS" ) ).toBeFalse( "Malformed geometry should fail: #serializeJSON(malformedRes)#" );
        expect(
          findNoCase(
            "Geometry",
            toString( pickNested( malformedRes, [ "ERROR", "MESSAGE" ], "" ) )
          ) GT 0
        ).toBeTrue( "Expected geometry validation message: #serializeJSON(malformedRes)#" );

        var outOfRangeRes = routeBuilderPost( "routegen_savelegoverride", {
          route_code = legCtx.routeCode,
          route_leg_id = legCtx.routeLegId,
          leg_order = legCtx.legOrder,
          segment_id = legCtx.segmentId,
          geometry = [
            { lat = 91.000000, lon = -87.600000 },
            { lat = 92.000000, lon = -87.100000 }
          ]
        } );
        expect( pickBool( outOfRangeRes, "SUCCESS" ) ).toBeFalse( "Out-of-range latitude should fail: #serializeJSON(outOfRangeRes)#" );
        expect(
          findNoCase(
            "latitude out of range",
            lCase( toString( pickNested( outOfRangeRes, [ "ERROR", "MESSAGE" ], "" ) ) )
          ) GT 0
        ).toBeTrue( "Expected latitude range validation message: #serializeJSON(outOfRangeRes)#" );

        var badLegIdRes = routeBuilderPost( "routegen_savelegoverride", {
          route_code = legCtx.routeCode,
          route_leg_id = legCtx.routeLegId + 999999,
          leg_order = legCtx.legOrder,
          segment_id = legCtx.segmentId,
          geometry = [
            { lat = 41.900000, lon = -87.600000 },
            { lat = 42.050000, lon = -87.100000 }
          ]
        } );
        expect( pickBool( badLegIdRes, "SUCCESS" ) ).toBeFalse( "Unknown route_leg_id should fail: #serializeJSON(badLegIdRes)#" );
        expect(
          findNoCase(
            "not found",
            lCase( toString( pickNested( badLegIdRes, [ "ERROR", "MESSAGE" ], "" ) ) )
          ) GT 0
        ).toBeTrue( "Expected leg-not-found message: #serializeJSON(badLegIdRes)#" );
      } );

      it( "requires authenticated session for route override endpoints", function() {
        var anonRes = routeBuilderPostAnonymous( "routegen_getleggeometry", {
          route_code = "NON_EXISTENT_ROUTE",
          route_leg_id = 1,
          leg_order = 1,
          segment_id = 1
        } );
        expect( pickBool( anonRes, "SUCCESS" ) ).toBeFalse( "Anonymous request should not succeed: #serializeJSON(anonRes)#" );
        expect( !!pickFirst( anonRes, [ "AUTH", "auth" ], true ) ).toBeFalse( "Anonymous request should have AUTH=false: #serializeJSON(anonRes)#" );
        expect(
          findNoCase(
            "unauthorized",
            lCase( toString( pickFirst( anonRes, [ "MESSAGE", "message" ], "" ) ) )
          ) GT 0
        ).toBeTrue( "Anonymous request should return unauthorized message: #serializeJSON(anonRes)#" );
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
        type = "RouteLegOverridesSpec.Setup",
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
        type = "RouteLegOverridesSpec.Setup",
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
        type = "RouteLegOverridesSpec.Setup",
        message = "Invalid start/end segment ids",
        detail = serializeJSON( optionsRes )
      );
    }

    var generateRes = routeBuilderPost( "routegen_generate", {
      route_name = "Route Leg Override " & replace( createUUID(), "-", "", "all" ),
      template_code = templateCode,
      start_segment_id = startSegmentId,
      end_segment_id = endSegmentId,
      start_date = dateFormat( now(), "yyyy-mm-dd" ),
      direction = "CCW"
    } );
    if ( !pickBool( generateRes, "SUCCESS" ) ) {
      throw(
        type = "RouteLegOverridesSpec.Setup",
        message = "routegen_generate failed",
        detail = serializeJSON( generateRes )
      );
    }

    var routeCode = trim( toString( pickFirst( generateRes, [ "ROUTE_CODE", "route_code", "routeCode" ], "" ) ) );
    if ( !len( routeCode ) ) {
      throw(
        type = "RouteLegOverridesSpec.Setup",
        message = "routegen_generate returned no route code",
        detail = serializeJSON( generateRes )
      );
    }

    var editContextRes = routeBuilderPost( "routegen_geteditcontext", {
      route_code = routeCode
    } );
    if ( !pickBool( editContextRes, "SUCCESS" ) ) {
      throw(
        type = "RouteLegOverridesSpec.Setup",
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
        type = "RouteLegOverridesSpec.Setup",
        message = "routegen_preview failed",
        detail = serializeJSON( previewRes )
      );
    }

    var legs = ( structKeyExists( previewRes, "DATA" ) && isStruct( previewRes.DATA ) && structKeyExists( previewRes.DATA, "legs" ) && isArray( previewRes.DATA.legs ) )
      ? previewRes.DATA.legs
      : [];
    if ( !arrayLen( legs ) ) {
      throw(
        type = "RouteLegOverridesSpec.Setup",
        message = "routegen_preview returned no legs",
        detail = serializeJSON( previewRes )
      );
    }

    var firstLeg = legs[ 1 ];
    return {
      routeCode = routeCode,
      routeLegId = val( pickFirst( firstLeg, [ "route_leg_id", "ROUTE_LEG_ID" ], 0 ) ),
      legOrder = val( pickFirst( firstLeg, [ "order_index", "ORDER_INDEX" ], 0 ) ),
      segmentId = val( pickFirst( firstLeg, [ "segment_id", "SEGMENT_ID" ], 0 ) )
    };
  }

  private struct function buildGeneratorPreviewContext() {
    var optionsRes = routeBuilderPost( "routegen_getoptions", {
      direction = "CCW",
      tripType = "POINT_TO_POINT"
    } );
    if ( !pickBool( optionsRes, "SUCCESS" ) ) {
      throw(
        type = "RouteLegOverridesSpec.Setup",
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
        type = "RouteLegOverridesSpec.Setup",
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
        type = "RouteLegOverridesSpec.Setup",
        message = "Invalid start/end segment ids",
        detail = serializeJSON( optionsRes )
      );
    }

    var input = {
      route_name = "Route Draft Override " & replace( createUUID(), "-", "", "all" ),
      template_code = templateCode,
      start_segment_id = startSegmentId,
      end_segment_id = endSegmentId,
      start_date = dateFormat( now(), "yyyy-mm-dd" ),
      direction = "CCW"
    };
    var previewRes = routeBuilderPost( "routegen_preview", input );
    if ( !pickBool( previewRes, "SUCCESS" ) ) {
      throw(
        type = "RouteLegOverridesSpec.Setup",
        message = "routegen_preview failed",
        detail = serializeJSON( previewRes )
      );
    }

    var legs = extractPreviewLegs( previewRes );
    if ( !arrayLen( legs ) ) {
      throw(
        type = "RouteLegOverridesSpec.Setup",
        message = "routegen_preview returned no legs",
        detail = serializeJSON( previewRes )
      );
    }

    var blockedSegments = getExistingSegmentOverrideMap( variables.ctx.forceUserId );
    var selectedLeg = {};
    for ( var leg in legs ) {
      var segmentId = val( pickFirst( leg, [ "segment_id", "SEGMENT_ID" ], 0 ) );
      if ( segmentId GT 0 && !structKeyExists( blockedSegments, toString( segmentId ) ) ) {
        selectedLeg = leg;
        break;
      }
    }
    if ( !structCount( selectedLeg ) ) {
      selectedLeg = legs[ 1 ];
    }

    var selectedSegmentId = val( pickFirst( selectedLeg, [ "segment_id", "SEGMENT_ID" ], 0 ) );
    return {
      input = input,
      legs = legs,
      leg = selectedLeg,
      legOrder = val( pickFirst( selectedLeg, [ "order_index", "ORDER_INDEX" ], 0 ) ),
      segmentId = selectedSegmentId,
      hasCleanSegment = !structKeyExists( blockedSegments, toString( selectedSegmentId ) )
    };
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

  private struct function buildLegOverrideDraftPayload( required numeric segmentId, required array geometry ) {
    return {
      "#arguments.segmentId#" = {
        segment_id = arguments.segmentId,
        geometry = arguments.geometry,
        override_fields = {}
      }
    };
  }

  private struct function getExistingSegmentOverrideMap( required numeric userId ) {
    var out = {};
    var q = queryExecute(
      "SELECT DISTINCT segment_id
       FROM (
         SELECT segment_id
         FROM user_segment_overrides
         WHERE user_id = :uid
           AND segment_id IS NOT NULL
           AND segment_id > 0
         UNION
         SELECT segment_id
         FROM route_leg_user_overrides
         WHERE user_id = :uid
           AND route_id = 0
           AND segment_id IS NOT NULL
           AND segment_id > 0
       ) override_segments",
      {
        uid = { value=arguments.userId, cfsqltype="cf_sql_integer" }
      },
      { datasource = application.dsn }
    );
    for ( var i = 1; i LTE q.recordCount; i++ ) {
      out[ toString( val( q.segment_id[ i ] ) ) ] = true;
    }
    return out;
  }

  private struct function readSegmentOverrideDbState( required numeric userId, required numeric segmentId ) {
    var q = queryExecute(
      "SELECT
          (SELECT COUNT(*)
           FROM user_segment_overrides
           WHERE user_id = :uid
             AND segment_id = :segmentId) AS canonical_count,
          (SELECT COUNT(*)
           FROM route_leg_user_overrides
           WHERE user_id = :uid
             AND route_id = 0
             AND segment_id = :segmentId) AS legacy_count",
      {
        uid = { value=arguments.userId, cfsqltype="cf_sql_integer" },
        segmentId = { value=arguments.segmentId, cfsqltype="cf_sql_integer" }
      },
      { datasource = application.dsn }
    );
    return {
      canonicalCount = ( q.recordCount ? val( q.canonical_count[ 1 ] ) : 0 ),
      legacyCount = ( q.recordCount ? val( q.legacy_count[ 1 ] ) : 0 )
    };
  }

  private numeric function readExactRouteOverrideCount( required numeric userId, required numeric routeId, required numeric segmentId ) {
    var q = queryExecute(
      "SELECT COUNT(*) AS exact_count
       FROM route_leg_user_overrides
       WHERE user_id = :uid
         AND route_id = :routeId
         AND segment_id = :segmentId",
      {
        uid = { value=arguments.userId, cfsqltype="cf_sql_integer" },
        routeId = { value=arguments.routeId, cfsqltype="cf_sql_integer" },
        segmentId = { value=arguments.segmentId, cfsqltype="cf_sql_integer" }
      },
      { datasource = application.dsn }
    );
    return ( q.recordCount ? val( q.exact_count[ 1 ] ) : 0 );
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

    cfhttp( method="POST", url=urlPath, timeout="60", result="res" ) {
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

  private struct function routeBuilderPostAnonymous( required string action, required struct body ) {
    var urlPath = variables.ctx.baseUrl & "/fpw/api/v1/routeBuilder.cfc?method=handle&action=" & urlEncodedFormat( arguments.action );
    var res = {};

    cfhttp( method="POST", url=urlPath, timeout="60", result="res" ) {
      cfhttpparam( type="header", name="Accept", value="application/json" );
      cfhttpparam( type="header", name="Content-Type", value="application/json; charset=utf-8" );
      cfhttpparam( type="body", value=serializeJSON( arguments.body ) );
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
