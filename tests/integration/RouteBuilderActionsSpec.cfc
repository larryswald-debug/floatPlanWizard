component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.ctx = {
      createdRouteCodes = [],
      createdMyRouteIds = [],
      createdWaypointIds = []
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
    for ( var j = 1; j LTE arrayLen( variables.ctx.createdMyRouteIds ); j++ ) {
      routeBuilderPost( "deleteUserRoute", { route_id = variables.ctx.createdMyRouteIds[ j ] } );
    }
    for ( var k = 1; k LTE arrayLen( variables.ctx.createdWaypointIds ); k++ ) {
      queryExecute(
        "DELETE FROM waypoints
         WHERE wpId = :wpId
           AND userId = :uid",
        {
          wpId = { value = variables.ctx.createdWaypointIds[ k ], cfsqltype = "cf_sql_integer" },
          uid = { value = variables.ctx.forceUserId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = application.dsn }
      );
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

        var updateRes = routeBuilderPost( "routegen_update", updateInput );
        expect( pickBool( updateRes, "SUCCESS" ) ).toBeTrue( "routegen_update failed: #serializeJSON(updateRes)#" );
        expect( toString( pickFirst( updateRes, [ "ROUTE_CODE", "route_code", "routeCode" ], "" ) ) ).toBe( legCtx.routeCode );

        var editContextAfter = routeBuilderPost( "routegen_geteditcontext", {
          route_code = legCtx.routeCode
        } );
        expect( pickBool( editContextAfter, "SUCCESS" ) ).toBeTrue( "routegen_geteditcontext failed after update: #serializeJSON(editContextAfter)#" );
      } );

      it( "generates cruise timeline day rollups and validates bad input", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var legCtx = buildRouteLegContext();
        expect( legCtx.routeId ).toBeGT( 0, "routeId setup failed: #serializeJSON(legCtx)#" );

        var timelineRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = dateFormat( now(), "yyyy-mm-dd" ),
          maxHoursPerDay = 6.5
        } );
        expect( !!pickFirst( timelineRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( "generateCruiseTimeline failed: #serializeJSON(timelineRes)#" );

        var routeSummary = structKeyExists( timelineRes, "route_summary" ) && isStruct( timelineRes.route_summary )
          ? timelineRes.route_summary
          : {};
        expect( val( pickFirst( routeSummary, [ "total_days" ], 0 ) ) ).toBeGT( 0, "route_summary.total_days should be > 0: #serializeJSON(timelineRes)#" );

        var days = structKeyExists( timelineRes, "days" ) && isArray( timelineRes.days )
          ? timelineRes.days
          : [];
        expect( arrayLen( days ) ).toBeGT( 0, "days should be populated: #serializeJSON(timelineRes)#" );
        expect( structKeyExists( days[ 1 ], "date" ) ).toBeTrue();
        expect( structKeyExists( days[ 1 ], "segment_ids" ) ).toBeTrue();
        expect( structKeyExists( days[ 1 ], "segment_slices" ) ).toBeTrue();
        expect( structKeyExists( days[ 1 ], "risk_color" ) ).toBeTrue();
        expect( structKeyExists( days[ 1 ], "fuel_confidence_score" ) ).toBeTrue();

        var minBoundRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = dateFormat( now(), "yyyy-mm-dd" ),
          maxHoursPerDay = 4
        } );
        expect( !!pickFirst( minBoundRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( "generateCruiseTimeline min bound failed: #serializeJSON(minBoundRes)#" );

        var maxBoundRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = dateFormat( now(), "yyyy-mm-dd" ),
          maxHoursPerDay = 12
        } );
        expect( !!pickFirst( maxBoundRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( "generateCruiseTimeline max bound failed: #serializeJSON(maxBoundRes)#" );

        var zeroHoursRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = dateFormat( now(), "yyyy-mm-dd" ),
          maxHoursPerDay = 0
        } );
        expect( !!pickFirst( zeroHoursRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( "generateCruiseTimeline zero hours should default to 6.5: #serializeJSON(zeroHoursRes)#" );

        var negativeHoursRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = dateFormat( now(), "yyyy-mm-dd" ),
          maxHoursPerDay = -2
        } );
        expect( !!pickFirst( negativeHoursRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( "generateCruiseTimeline negative hours should default to 6.5: #serializeJSON(negativeHoursRes)#" );

        var overMaxHoursRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = dateFormat( now(), "yyyy-mm-dd" ),
          maxHoursPerDay = 100
        } );
        expect( !!pickFirst( overMaxHoursRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( "generateCruiseTimeline >max hours should clamp to 12: #serializeJSON(overMaxHoursRes)#" );

        var zeroSummary = structKeyExists( zeroHoursRes, "route_summary" ) && isStruct( zeroHoursRes.route_summary )
          ? zeroHoursRes.route_summary
          : {};
        var negativeSummary = structKeyExists( negativeHoursRes, "route_summary" ) && isStruct( negativeHoursRes.route_summary )
          ? negativeHoursRes.route_summary
          : {};
        var maxSummary = structKeyExists( maxBoundRes, "route_summary" ) && isStruct( maxBoundRes.route_summary )
          ? maxBoundRes.route_summary
          : {};
        var overMaxSummary = structKeyExists( overMaxHoursRes, "route_summary" ) && isStruct( overMaxHoursRes.route_summary )
          ? overMaxHoursRes.route_summary
          : {};
        expect( val( pickFirst( zeroSummary, [ "total_days" ], 0 ) ) ).toBe( val( pickFirst( routeSummary, [ "total_days" ], 0 ) ) );
        expect( val( pickFirst( negativeSummary, [ "total_days" ], 0 ) ) ).toBe( val( pickFirst( routeSummary, [ "total_days" ], 0 ) ) );
        expect( val( pickFirst( overMaxSummary, [ "total_days" ], 0 ) ) ).toBe( val( pickFirst( maxSummary, [ "total_days" ], 0 ) ) );

        var badDateRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = "02/21/2026"
        } );
        expect( !!pickFirst( badDateRes, [ "success", "SUCCESS" ], true ) ).toBeFalse( "invalid startDate should fail: #serializeJSON(badDateRes)#" );

        var badRouteRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = 0,
          startDate = dateFormat( now(), "yyyy-mm-dd" )
        } );
        expect( !!pickFirst( badRouteRes, [ "success", "SUCCESS" ], true ) ).toBeFalse( "routeId=0 should fail: #serializeJSON(badRouteRes)#" );
      } );

      it( "defaults missing reserve_pct to 33 for preview and timeline flows", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }
        if ( !routeInstancesHasInputsJsonColumn() ) {
          skip( "route_instances.routegen_inputs_json not present in this environment." );
        }

        var legCtx = buildRouteLegContext();
        var previewInput = duplicate( legCtx.inputs );
        structDelete( previewInput, "reserve_pct" );
        structDelete( previewInput, "RESERVE_PCT" );
        previewInput.start_date = dateFormat( now(), "yyyy-mm-dd" );

        var previewRes = routeBuilderPost( "routegen_preview", previewInput );
        expect( pickBool( previewRes, "SUCCESS" ) ).toBeTrue( "routegen_preview default reserve failed: #serializeJSON(previewRes)#" );
        var previewData = ( structKeyExists( previewRes, "DATA" ) && isStruct( previewRes.DATA ) )
          ? previewRes.DATA
          : {};
        var previewTotals = ( structKeyExists( previewData, "totals" ) && isStruct( previewData.totals ) )
          ? previewData.totals
          : {};
        expect( val( pickFirst( previewTotals, [ "reserve_pct", "RESERVE_PCT" ], 0 ) ) ).toBe( 33 );

        setRouteInstanceInputsJson( legCtx.routeId, {
          pace = "RELAXED",
          cruising_speed = 20,
          fuel_burn_gph = 8
        } );

        var timelineRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = dateFormat( now(), "yyyy-mm-dd" ),
          maxHoursPerDay = 6.5
        } );
        expect( !!pickFirst( timelineRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( "generateCruiseTimeline default reserve failed: #serializeJSON(timelineRes)#" );

        setRouteInstanceInputsJson( legCtx.routeId, {
          pace = "RELAXED",
          cruising_speed = 20,
          fuel_burn_gph = 8,
          reserve_pct = 33
        } );

        var explicitTimelineRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = dateFormat( now(), "yyyy-mm-dd" ),
          maxHoursPerDay = 6.5
        } );
        expect( !!pickFirst( explicitTimelineRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( "generateCruiseTimeline explicit 33 reserve failed: #serializeJSON(explicitTimelineRes)#" );

        var timelineSummary = ( structKeyExists( timelineRes, "route_summary" ) && isStruct( timelineRes.route_summary ) )
          ? timelineRes.route_summary
          : {};
        var explicitTimelineSummary = ( structKeyExists( explicitTimelineRes, "route_summary" ) && isStruct( explicitTimelineRes.route_summary ) )
          ? explicitTimelineRes.route_summary
          : {};
        expect(
          abs(
            val( pickFirst( timelineSummary, [ "total_required_fuel", "TOTAL_REQUIRED_FUEL" ], 0 ) )
            - val( pickFirst( explicitTimelineSummary, [ "total_required_fuel", "TOTAL_REQUIRED_FUEL" ], 0 ) )
          ) LTE 0.01
        ).toBeTrue();
      } );

      it( "applies reserve-threshold badge colors with one-level long-day downgrade", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var legCtx = buildRouteLegContext();
        var startDate = dateFormat( now(), "yyyy-mm-dd" );
        var scenarios = [
          { routeLegId = 9401, segmentId = 8401, reservePct = 33, distNm = 80, expectedColor = "GREEN", expectedHours = 8 },
          { routeLegId = 9402, segmentId = 8402, reservePct = 33, distNm = 90, expectedColor = "YELLOW", expectedHours = 9 },
          { routeLegId = 9403, segmentId = 8403, reservePct = 20, distNm = 80, expectedColor = "YELLOW", expectedHours = 8 },
          { routeLegId = 9404, segmentId = 8404, reservePct = 20, distNm = 90, expectedColor = "RED", expectedHours = 9 },
          { routeLegId = 9405, segmentId = 8405, reservePct = 15, distNm = 80, expectedColor = "RED", expectedHours = 8 },
          { routeLegId = 9406, segmentId = 8406, reservePct = 15, distNm = 90, expectedColor = "RED", expectedHours = 9 }
        ];

        for ( var scenario in scenarios ) {
          var timelineRes = routeBuilderPost( "generateCruiseTimeline", {
            routeId = legCtx.routeId,
            startDate = startDate,
            maxHoursPerDay = 12,
            inputOverrides = {
              pace = "AGGRESSIVE",
              cruising_speed = 10,
              underway_hours_per_day = 12,
              weather_factor_pct = 0,
              fuel_burn_gph = 8,
              reserve_pct = scenario.reservePct
            },
            previewLegs = [
              buildTimelinePreviewLeg(
                1,
                scenario.routeLegId,
                scenario.segmentId,
                "Alpha",
                "Bravo",
                scenario.distNm,
                0
              )
            ]
          } );

          expect( !!pickFirst( timelineRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( "reserve threshold timeline failed: #serializeJSON(timelineRes)#" );
          var days = ( structKeyExists( timelineRes, "days" ) && isArray( timelineRes.days ) )
            ? timelineRes.days
            : [];
          expect( arrayLen( days ) ).toBe( 1 );
          expect( abs( val( pickFirst( days[ 1 ], [ "est_hours", "EST_HOURS" ], 0 ) ) - scenario.expectedHours ) LTE 0.05 ).toBeTrue();
          expect( toString( pickFirst( days[ 1 ], [ "risk_color", "RISK_COLOR" ], "" ) ) ).toBe( scenario.expectedColor );
        }
      } );

      it( "resolves timeline fuel from route input keys and returns timeline_meta", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }
        if ( !routeInstancesHasInputsJsonColumn() ) {
          skip( "route_instances.routegen_inputs_json not present in this environment." );
        }

        var startDate = dateFormat( now(), "yyyy-mm-dd" );

        // A) Canonical key present => route_inputs
        var canonicalCtx = buildRouteLegContext();
        setRouteInstanceInputsJson( canonicalCtx.routeId, {
          fuel_burn_gph = 12.5,
          reserve_pct = 20,
          pace = "RELAXED",
          cruising_speed = 20
        } );
        var canonicalRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = canonicalCtx.routeId,
          startDate = startDate,
          maxHoursPerDay = 6.5
        } );
        expect( !!pickFirst( canonicalRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( "generateCruiseTimeline canonical failed: #serializeJSON(canonicalRes)#" );
        var canonicalMeta = ( structKeyExists( canonicalRes, "timeline_meta" ) && isStruct( canonicalRes.timeline_meta ) )
          ? canonicalRes.timeline_meta
          : {};
        expect( toString( pickFirst( canonicalMeta, [ "fuel_source" ], "" ) ) ).toBe( "route_inputs" );
        expect( toString( pickFirst( canonicalMeta, [ "fuel_key" ], "" ) ) ).toBe( "fuel_burn_gph" );
        expect( val( pickFirst( canonicalMeta, [ "fuel_burn_gph" ], 0 ) ) ).toBeGT( 0 );
        expect( !!pickFirst( canonicalMeta, [ "fuel_resolved" ], false ) ).toBeTrue();
        var canonicalSummary = ( structKeyExists( canonicalRes, "route_summary" ) && isStruct( canonicalRes.route_summary ) )
          ? canonicalRes.route_summary
          : {};
        expect( val( pickFirst( canonicalSummary, [ "total_required_fuel" ], 0 ) ) ).toBeGT( 0 );
        var canonicalDays = ( structKeyExists( canonicalRes, "days" ) && isArray( canonicalRes.days ) )
          ? canonicalRes.days
          : [];
        expect( arrayLen( canonicalDays ) ).toBeGT( 0 );
        expect( val( pickFirst( canonicalDays[ 1 ], [ "required_fuel_gallons" ], 0 ) ) ).toBeGT( 0 );
        expect( val( pickFirst( canonicalDays[ 1 ], [ "reserve_gallons" ], 0 ) ) ).toBeGT( 0 );

        // B) Missing fuel keys => missing
        var missingCtx = buildRouteLegContext();
        setRouteInstanceInputsJson( missingCtx.routeId, {
          reserve_pct = 20,
          pace = "RELAXED",
          cruising_speed = 20
        } );
        var missingRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = missingCtx.routeId,
          startDate = startDate,
          maxHoursPerDay = 6.5
        } );
        expect( !!pickFirst( missingRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( "generateCruiseTimeline missing failed: #serializeJSON(missingRes)#" );
        var missingMeta = ( structKeyExists( missingRes, "timeline_meta" ) && isStruct( missingRes.timeline_meta ) )
          ? missingRes.timeline_meta
          : {};
        expect( toString( pickFirst( missingMeta, [ "fuel_source" ], "" ) ) ).toBe( "missing" );
        expect( val( pickFirst( missingMeta, [ "fuel_burn_gph" ], -1 ) ) ).toBe( 0 );
        expect( !!pickFirst( missingMeta, [ "fuel_resolved" ], true ) ).toBeFalse();
        expect( toString( pickFirst( missingMeta, [ "burn_model" ], "" ) ) ).toBe( "legacy" );
        var missingSummary = ( structKeyExists( missingRes, "route_summary" ) && isStruct( missingRes.route_summary ) )
          ? missingRes.route_summary
          : {};
        expect( val( pickFirst( missingSummary, [ "total_required_fuel" ], -1 ) ) ).toBe( 0 );
        var missingDays = ( structKeyExists( missingRes, "days" ) && isArray( missingRes.days ) )
          ? missingRes.days
          : [];
        expect( arrayLen( missingDays ) ).toBeGT( 0 );
        expect( val( pickFirst( missingDays[ 1 ], [ "required_fuel_gallons" ], -1 ) ) ).toBe( 0 );
        expect( val( pickFirst( missingDays[ 1 ], [ "reserve_gallons" ], -1 ) ) ).toBe( 0 );

        // C) Alias key present => canonical route_inputs
        var aliasCtx = buildRouteLegContext();
        setRouteInstanceInputsJson( aliasCtx.routeId, {
          maxBurnGph = 11.25,
          reserve_pct = 20,
          pace = "RELAXED",
          cruising_speed = 20
        } );
        var aliasRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = aliasCtx.routeId,
          startDate = startDate,
          maxHoursPerDay = 6.5
        } );
        expect( !!pickFirst( aliasRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( "generateCruiseTimeline alias failed: #serializeJSON(aliasRes)#" );
        var aliasMeta = ( structKeyExists( aliasRes, "timeline_meta" ) && isStruct( aliasRes.timeline_meta ) )
          ? aliasRes.timeline_meta
          : {};
        expect( toString( pickFirst( aliasMeta, [ "fuel_source" ], "" ) ) ).toBe( "route_inputs" );
        expect( toString( pickFirst( aliasMeta, [ "fuel_key" ], "" ) ) ).toBe( "fuel_burn_gph" );
        expect( abs( val( pickFirst( aliasMeta, [ "fuel_burn_gph" ], 0 ) ) - 11.25 ) LTE 0.0001 ).toBeTrue();
        expect( !!pickFirst( aliasMeta, [ "fuel_resolved" ], false ) ).toBeTrue();
        var aliasSummary = ( structKeyExists( aliasRes, "route_summary" ) && isStruct( aliasRes.route_summary ) )
          ? aliasRes.route_summary
          : {};
        expect( val( pickFirst( aliasSummary, [ "total_required_fuel" ], 0 ) ) ).toBeGT( 0 );
        var aliasDays = ( structKeyExists( aliasRes, "days" ) && isArray( aliasRes.days ) )
          ? aliasRes.days
          : [];
        expect( arrayLen( aliasDays ) ).toBeGT( 0 );
        expect( val( pickFirst( aliasDays[ 1 ], [ "required_fuel_gallons" ], 0 ) ) ).toBeGT( 0 );
      } );

      it( "uses vessel defaults for preview summary and timeline when explicit speed/fuel are missing", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }
        if ( !routeInstancesHasInputsJsonColumn() ) {
          skip( "route_instances.routegen_inputs_json not present in this environment." );
        }
        if ( !routeInstancesHasVesselIdColumn() ) {
          skip( "route_instances.vessel_id is not present in this environment." );
        }

        var prefix = "routebuilder-default-vessel-" & uniqueSuffix();
        var vesselPayload = saveVesselForSpec( {
          vesselName = "Default Vessel " & prefix,
          type = "Cruiser",
          length = 36,
          color = "White",
          maxSpeed = 28,
          maxBurnGph = 14.25
        } );
        expect( pickBool( vesselPayload, "SUCCESS" ) ).toBeTrue( serializeJSON( vesselPayload ) );
        var vesselId = val( pickFirst( vesselPayload, [ "VESSELID", "vesselId" ], 0 ) );
        expect( vesselId ).toBeGT( 0, serializeJSON( vesselPayload ) );

        var options = routeBuilderPost( "routegen_getoptions", {
          template_code = "GULF-WEST",
          direction = "CCW"
        } );
        expect( pickBool( options, "SUCCESS" ) ).toBeTrue( serializeJSON( options ) );

        var generateRes = routeBuilderPost( "routegen_generate", {
          route_name = "Default Vessel Route " & prefix,
          template_code = "GULF-WEST",
          direction = "CCW",
          start_segment_id = options.DATA.startOptions[ 1 ].segment_id,
          end_segment_id = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].segment_id,
          start_location_label = options.DATA.startOptions[ 1 ].label,
          end_location_label = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].label,
          start_date = dateFormat( now(), "yyyy-mm-dd" )
        } );
        expect( pickBool( generateRes, "SUCCESS" ) ).toBeTrue( serializeJSON( generateRes ) );

        var routeId = val( pickFirst( generateRes, [ "ROUTE_ID", "route_id" ], 0 ) );
        if ( routeId LTE 0 && structKeyExists( generateRes, "DATA" ) && isStruct( generateRes.DATA ) ) {
          routeId = val( pickFirst( generateRes.DATA, [ "route_id", "ROUTE_ID" ], 0 ) );
        }
        expect( routeId ).toBeGT( 0, serializeJSON( generateRes ) );
        rememberCreatedRouteCode( trim( toString( pickFirst( generateRes, [ "ROUTE_CODE", "route_code", "routeCode" ], "" ) ) ) );

        queryExecute(
          "UPDATE route_instances
           SET vessel_id = :vesselId,
               routegen_inputs_json = :inputsJson
           WHERE generated_route_id = :routeId
             AND user_id = :uid",
          {
            vesselId = { value = vesselId, cfsqltype = "cf_sql_integer" },
            inputsJson = { value = serializeJSON( { reserve_pct = 20 } ), cfsqltype = "cf_sql_longvarchar" },
            routeId = { value = routeId, cfsqltype = "cf_sql_integer" },
            uid = { value = toString( variables.ctx.forceUserId ), cfsqltype = "cf_sql_varchar" }
          },
          { datasource = application.dsn }
        );

        var previewRes = routeBuilderPost( "routegen_preview", {
          route_id = routeId,
          routeCode = pickFirst( generateRes, [ "ROUTE_CODE", "route_code", "routeCode" ], "" )
        } );
        expect( pickBool( previewRes, "SUCCESS" ) ).toBeTrue( serializeJSON( previewRes ) );
        var previewData = ( structKeyExists( previewRes, "DATA" ) && isStruct( previewRes.DATA ) )
          ? previewRes.DATA
          : {};
        var previewTimelineMeta = ( structKeyExists( previewData, "timeline_meta" ) && isStruct( previewData.timeline_meta ) )
          ? previewData.timeline_meta
          : {};
        expect( abs( val( pickFirst( previewTimelineMeta, [ "fuel_burn_gph" ], 0 ) ) - 14.25 ) LTE 0.0001 ).toBeTrue();
        expect( abs( val( pickFirst( previewTimelineMeta, [ "cruising_speed" ], 0 ) ) - 28 ) LTE 0.0001 ).toBeTrue();
        expect( toString( pickFirst( previewTimelineMeta, [ "fuel_source" ], "missing" ) ) ).notToBe( "missing" );
        expect( toString( pickFirst( previewTimelineMeta, [ "speed_source" ], "missing" ) ) ).notToBe( "missing" );
        expect( toString( pickFirst( previewTimelineMeta, [ "fuel_source" ], "" ) ) ).notToBe( "route_inputs" );
        expect( toString( pickFirst( previewTimelineMeta, [ "speed_source" ], "" ) ) ).notToBe( "route_inputs" );

        var previewTotals = ( structKeyExists( previewData, "totals" ) && isStruct( previewData.totals ) )
          ? previewData.totals
          : {};
        expect( val( pickFirst( previewTotals, [ "reserve_pct" ], 0 ) ) ).toBe( 20 );
        expect( val( pickFirst( previewTotals, [ "total_required_fuel", "TOTAL_REQUIRED_FUEL" ], 0 ) ) ).toBeGT( 0 );

        var timelineRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = routeId,
          startDate = dateFormat( now(), "yyyy-mm-dd" ),
          maxHoursPerDay = 6.5
        } );
        expect( !!pickFirst( timelineRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( serializeJSON( timelineRes ) );
        var timelineMeta = ( structKeyExists( timelineRes, "timeline_meta" ) && isStruct( timelineRes.timeline_meta ) )
          ? timelineRes.timeline_meta
          : {};
        expect( abs( val( pickFirst( timelineMeta, [ "fuel_burn_gph" ], 0 ) ) - 14.25 ) LTE 0.0001 ).toBeTrue();
        expect( abs( val( pickFirst( timelineMeta, [ "cruising_speed" ], 0 ) ) - 28 ) LTE 0.0001 ).toBeTrue();
        expect( toString( pickFirst( timelineMeta, [ "fuel_source" ], "missing" ) ) ).notToBe( "missing" );
        expect( toString( pickFirst( timelineMeta, [ "speed_source" ], "missing" ) ) ).notToBe( "missing" );
        expect( toString( pickFirst( timelineMeta, [ "fuel_source" ], "" ) ) ).notToBe( "route_inputs" );
        expect( toString( pickFirst( timelineMeta, [ "speed_source" ], "" ) ) ).notToBe( "route_inputs" );

        var routeSummary = ( structKeyExists( timelineRes, "route_summary" ) && isStruct( timelineRes.route_summary ) )
          ? timelineRes.route_summary
          : {};
        expect( val( pickFirst( routeSummary, [ "total_required_fuel" ], 0 ) ) ).toBeGT( 0 );
        var days = ( structKeyExists( timelineRes, "days" ) && isArray( timelineRes.days ) )
          ? timelineRes.days
          : [];
        expect( arrayLen( days ) ).toBeGT( 0 );
        expect( val( pickFirst( days[ 1 ], [ "required_fuel_gallons" ], 0 ) ) ).toBeGT( 0 );
      } );

      it( "keeps route input speed/fuel precedence over vessel defaults", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }
        if ( !routeInstancesHasInputsJsonColumn() ) {
          skip( "route_instances.routegen_inputs_json not present in this environment." );
        }
        if ( !routeInstancesHasVesselIdColumn() ) {
          skip( "route_instances.vessel_id is not present in this environment." );
        }

        var prefix = "routebuilder-input-priority-" & uniqueSuffix();
        var vesselPayload = saveVesselForSpec( {
          vesselName = "Priority Vessel " & prefix,
          type = "Cruiser",
          length = 36,
          color = "White",
          maxSpeed = 29,
          maxBurnGph = 18
        } );
        expect( pickBool( vesselPayload, "SUCCESS" ) ).toBeTrue( serializeJSON( vesselPayload ) );
        var vesselId = val( pickFirst( vesselPayload, [ "VESSELID", "vesselId" ], 0 ) );
        expect( vesselId ).toBeGT( 0, serializeJSON( vesselPayload ) );

        var options = routeBuilderPost( "routegen_getoptions", {
          template_code = "GULF-WEST",
          direction = "CCW"
        } );
        expect( pickBool( options, "SUCCESS" ) ).toBeTrue( serializeJSON( options ) );

        var generateRes = routeBuilderPost( "routegen_generate", {
          route_name = "Priority Route " & prefix,
          template_code = "GULF-WEST",
          direction = "CCW",
          start_segment_id = options.DATA.startOptions[ 1 ].segment_id,
          end_segment_id = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].segment_id,
          start_location_label = options.DATA.startOptions[ 1 ].label,
          end_location_label = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].label,
          start_date = dateFormat( now(), "yyyy-mm-dd" )
        } );
        expect( pickBool( generateRes, "SUCCESS" ) ).toBeTrue( serializeJSON( generateRes ) );

        var routeId = val( pickFirst( generateRes, [ "ROUTE_ID", "route_id" ], 0 ) );
        if ( routeId LTE 0 && structKeyExists( generateRes, "DATA" ) && isStruct( generateRes.DATA ) ) {
          routeId = val( pickFirst( generateRes.DATA, [ "route_id", "ROUTE_ID" ], 0 ) );
        }
        expect( routeId ).toBeGT( 0, serializeJSON( generateRes ) );
        rememberCreatedRouteCode( trim( toString( pickFirst( generateRes, [ "ROUTE_CODE", "route_code", "routeCode" ], "" ) ) ) );

        queryExecute(
          "UPDATE route_instances
           SET vessel_id = :vesselId,
               routegen_inputs_json = :inputsJson
           WHERE generated_route_id = :routeId
             AND user_id = :uid",
          {
            vesselId = { value = vesselId, cfsqltype = "cf_sql_integer" },
            inputsJson = { value = serializeJSON( {
              maxBurnGph = 10.75,
              maxSpeed = 22,
              reserve_pct = 20
            } ), cfsqltype = "cf_sql_longvarchar" },
            routeId = { value = routeId, cfsqltype = "cf_sql_integer" },
            uid = { value = toString( variables.ctx.forceUserId ), cfsqltype = "cf_sql_varchar" }
          },
          { datasource = application.dsn }
        );

        var timelineRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = routeId,
          startDate = dateFormat( now(), "yyyy-mm-dd" ),
          maxHoursPerDay = 6.5
        } );
        expect( !!pickFirst( timelineRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( serializeJSON( timelineRes ) );
        var timelineMeta = ( structKeyExists( timelineRes, "timeline_meta" ) && isStruct( timelineRes.timeline_meta ) )
          ? timelineRes.timeline_meta
          : {};
        expect( toString( pickFirst( timelineMeta, [ "fuel_source" ], "" ) ) ).toBe( "route_inputs" );
        expect( toString( pickFirst( timelineMeta, [ "fuel_key" ], "" ) ) ).toBe( "fuel_burn_gph" );
        expect( abs( val( pickFirst( timelineMeta, [ "fuel_burn_gph" ], 0 ) ) - 10.75 ) LTE 0.0001 ).toBeTrue();
        expect( toString( pickFirst( timelineMeta, [ "speed_source" ], "" ) ) ).toBe( "route_inputs" );
        expect( toString( pickFirst( timelineMeta, [ "speed_key" ], "" ) ) ).toBe( "cruising_speed" );
        expect( abs( val( pickFirst( timelineMeta, [ "cruising_speed" ], 0 ) ) - 22 ) LTE 0.0001 ).toBeTrue();
      } );

      it( "uses weather-adjusted speed for timeline hours and day bucketing", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var legCtx = buildRouteLegContext();
        var timelineRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = dateFormat( now(), "yyyy-mm-dd" ),
          maxHoursPerDay = 6.5,
          inputOverrides = {
            cruising_speed = 20,
            weather_factor_pct = 25,
            fuel_burn_gph = 8,
            reserve_pct = 20
          },
          previewLegs = [
            buildTimelinePreviewLeg( 1, 9101, 8101, "A", "B", 300, 0 )
          ]
        } );
        expect( !!pickFirst( timelineRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( serializeJSON( timelineRes ) );
        var timelineMeta = ( structKeyExists( timelineRes, "timeline_meta" ) && isStruct( timelineRes.timeline_meta ) )
          ? timelineRes.timeline_meta
          : {};
        expect( val( pickFirst( timelineMeta, [ "effective_speed_kn" ], 0 ) ) ).toBeGT( 0 );
        expect( val( pickFirst( timelineMeta, [ "effective_speed_kn" ], 0 ) ) ).toBeLT( 20 );
        expect( val( pickFirst( timelineMeta, [ "effective_weather_pct_max" ], 0 ) ) ).toBeGT( 0 );

        var days = ( structKeyExists( timelineRes, "days" ) && isArray( timelineRes.days ) )
          ? timelineRes.days
          : [];
        expect( arrayLen( days ) ).toBeGT( 3 );
        expect( sumTimelineEstHours( days ) ).toBeGT( 15 );
        expect( abs( val( pickFirst( days[ 1 ], [ "est_hours", "EST_HOURS" ], 0 ) ) - 6.5 ) LTE 0.05 ).toBeTrue();
        expect( val( pickFirst( days[ arrayLen( days ) ], [ "est_hours", "EST_HOURS" ], 0 ) ) ).toBeGT( 0 );
        expect( val( pickFirst( days[ arrayLen( days ) ], [ "est_hours", "EST_HOURS" ], 0 ) ) ).toBeLT( 6.5 );
      } );

      it( "applies exposure override levels to weather-adjusted timeline hours", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }
        if ( !segmentLibraryHasExposureLevelColumn() ) {
          skip( "segment_library.exposure_level not present in this environment." );
        }

        var legCtx = buildRouteLegContext();
        var segmentId = getRouteInstanceFirstSegmentId( legCtx.routeId );
        expect( segmentId ).toBeGT( 0, "No segment_id found for generated route instance: #serializeJSON(legCtx)#" );

        var originalExposure = readSegmentExposureLevel( segmentId );
        try {
          writeSegmentExposureLevel( segmentId, 3 );

          var aggressiveRes = routeBuilderPost( "generateCruiseTimeline", {
            routeId = legCtx.routeId,
            startDate = dateFormat( now(), "yyyy-mm-dd" ),
            maxHoursPerDay = 6.5,
            inputOverrides = {
              cruising_speed = 20,
              fuel_burn_gph = 8,
              reserve_pct = 20,
              pace = "AGGRESSIVE"
            },
            previewLegs = [
              buildTimelinePreviewLeg( 1, legCtx.routeLegId, segmentId, "Alpha", "Bravo", 240, 0 )
            ]
          } );
          expect( !!pickFirst( aggressiveRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( serializeJSON( aggressiveRes ) );
          var aggressiveMeta = ( structKeyExists( aggressiveRes, "timeline_meta" ) && isStruct( aggressiveRes.timeline_meta ) )
            ? aggressiveRes.timeline_meta
            : {};
          if ( val( pickFirst( aggressiveMeta, [ "exposure_max_level" ], 0 ) ) LTE 0 ) {
            skip( "generateCruiseTimeline does not surface exposure_max_level in this environment." );
          }
          expect( val( pickFirst( aggressiveMeta, [ "exposure_max_level" ], 0 ) ) ).toBe( 3 );
          expect( val( pickFirst( aggressiveMeta, [ "effective_weather_pct_max" ], 0 ) ) ).toBeGT( 0 );
          expect( val( pickFirst( aggressiveMeta, [ "effective_speed_kn" ], 0 ) ) ).toBeGT( 0 );
          expect( val( pickFirst( aggressiveMeta, [ "effective_speed_kn" ], 0 ) ) ).toBeLT( 20 );

          var days = ( structKeyExists( aggressiveRes, "days" ) && isArray( aggressiveRes.days ) )
            ? aggressiveRes.days
            : [];
          expect( arrayLen( days ) ).toBeGT( 1 );
          expect( sumTimelineEstHours( days ) ).toBeGT( 12 );
          expect( abs( val( pickFirst( days[ 1 ], [ "est_hours", "EST_HOURS" ], 0 ) ) - 6.5 ) LTE 0.05 ).toBeTrue();
        } finally {
          if ( !originalExposure.found ) {
            writeSegmentExposureLevel( segmentId, javacast( "null", "" ) );
          } else if ( originalExposure.isNull ) {
            writeSegmentExposureLevel( segmentId, javacast( "null", "" ) );
          } else {
            writeSegmentExposureLevel( segmentId, originalExposure.value );
          }
        }
      } );

      it( "applies generateCruiseTimeline inputOverrides without persisting route inputs", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }
        if ( !routeInstancesHasInputsJsonColumn() ) {
          skip( "route_instances.routegen_inputs_json not present in this environment." );
        }

        var legCtx = buildRouteLegContext();
        setRouteInstanceInputsJson( legCtx.routeId, {
          pace = "AGGRESSIVE",
          cruising_speed = 20,
          underway_hours_per_day = 8,
          weather_factor_pct = 0,
          fuel_burn_gph = 8,
          reserve_pct = 20
        } );

        var baselineRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = dateFormat( now(), "yyyy-mm-dd" ),
          maxHoursPerDay = 8
        } );
        expect( !!pickFirst( baselineRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( serializeJSON( baselineRes ) );
        var baselineDays = ( structKeyExists( baselineRes, "days" ) && isArray( baselineRes.days ) )
          ? baselineRes.days
          : [];
        var baselineHours = sumTimelineEstHours( baselineDays );
        expect( baselineHours ).toBeGT( 0 );
        var baselineMeta = ( structKeyExists( baselineRes, "timeline_meta" ) && isStruct( baselineRes.timeline_meta ) )
          ? baselineRes.timeline_meta
          : {};
        expect( !!pickFirst( baselineMeta, [ "fuel_resolved" ], false ) ).toBeTrue();
        expect( toString( pickFirst( baselineMeta, [ "fuel_source" ], "" ) ) ).toBe( "route_inputs" );
        expect( val( pickFirst( baselineMeta, [ "fuel_burn_gph" ], 0 ) ) ).toBe( 8 );
        expect( toString( pickFirst( baselineMeta, [ "speed_source" ], "" ) ) ).toBe( "route_inputs" );

        var overrideRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = dateFormat( now(), "yyyy-mm-dd" ),
          maxHoursPerDay = 8,
          inputOverrides = {
            cruising_speed = 10,
            fuel_burn_gph = 6,
            reserve_pct = 10,
            pace = "RELAXED",
            weather_factor_pct = 0
          }
        } );
        expect( !!pickFirst( overrideRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( serializeJSON( overrideRes ) );
        var overrideDays = ( structKeyExists( overrideRes, "days" ) && isArray( overrideRes.days ) )
          ? overrideRes.days
          : [];
        expect( sumTimelineEstHours( overrideDays ) ).toBeGT( baselineHours );
        var overrideMeta = ( structKeyExists( overrideRes, "timeline_meta" ) && isStruct( overrideRes.timeline_meta ) )
          ? overrideRes.timeline_meta
          : {};
        expect( !!pickFirst( overrideMeta, [ "fuel_resolved" ], false ) ).toBeTrue();
        expect( toString( pickFirst( overrideMeta, [ "fuel_source" ], "" ) ) ).toBe( "route_inputs" );
        expect( val( pickFirst( overrideMeta, [ "fuel_burn_gph" ], 0 ) ) ).toBe( 6 );
        expect( toString( pickFirst( overrideMeta, [ "speed_source" ], "" ) ) ).toBe( "route_inputs" );

        var postOverrideRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = dateFormat( now(), "yyyy-mm-dd" ),
          maxHoursPerDay = 8
        } );
        expect( !!pickFirst( postOverrideRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( serializeJSON( postOverrideRes ) );
        var postOverrideDays = ( structKeyExists( postOverrideRes, "days" ) && isArray( postOverrideRes.days ) )
          ? postOverrideRes.days
          : [];
        expect( abs( sumTimelineEstHours( postOverrideDays ) - baselineHours ) LTE 0.05 ).toBeTrue();
        var postOverrideMeta = ( structKeyExists( postOverrideRes, "timeline_meta" ) && isStruct( postOverrideRes.timeline_meta ) )
          ? postOverrideRes.timeline_meta
          : {};
        expect( toString( pickFirst( postOverrideMeta, [ "fuel_source" ], "" ) ) ).toBe( "route_inputs" );
        expect( val( pickFirst( postOverrideMeta, [ "fuel_burn_gph" ], 0 ) ) ).toBe( 8 );
        expect( toString( pickFirst( postOverrideMeta, [ "speed_source" ], "" ) ) ).toBe( "route_inputs" );
      } );

      it( "uses previewLegs as the distance source for timeline totals when provided", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var legCtx = buildRouteLegContext();
        var baselineRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = dateFormat( now(), "yyyy-mm-dd" ),
          maxHoursPerDay = 8,
          inputOverrides = buildDeterministicTimelineOverrides(),
          previewLegs = [
            buildTimelinePreviewLeg( 1, 9201, 8201, "A", "B", 40, 0 ),
            buildTimelinePreviewLeg( 2, 9202, 8202, "B", "C", 20, 0 )
          ]
        } );
        expect( !!pickFirst( baselineRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( serializeJSON( baselineRes ) );
        var baselineMeta = ( structKeyExists( baselineRes, "timeline_meta" ) && isStruct( baselineRes.timeline_meta ) )
          ? baselineRes.timeline_meta
          : {};
        var baselineDays = ( structKeyExists( baselineRes, "days" ) && isArray( baselineRes.days ) )
          ? baselineRes.days
          : [];
        expect( toString( pickFirst( baselineMeta, [ "distance_source" ], "" ) ) ).toBe( "preview_legs" );
        expect( arrayLen( baselineDays ) ).toBe( 1 );
        expect( arrayLen( timelineDaySlices( baselineDays[ 1 ] ) ) ).toBe( 2 );

        var truncatedRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = dateFormat( now(), "yyyy-mm-dd" ),
          maxHoursPerDay = 8,
          inputOverrides = buildDeterministicTimelineOverrides(),
          previewLegs = [
            buildTimelinePreviewLeg( 1, 9201, 8201, "A", "B", 40, 0 )
          ]
        } );
        expect( !!pickFirst( truncatedRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( serializeJSON( truncatedRes ) );
        var truncatedMeta = ( structKeyExists( truncatedRes, "timeline_meta" ) && isStruct( truncatedRes.timeline_meta ) )
          ? truncatedRes.timeline_meta
          : {};
        var truncatedDays = ( structKeyExists( truncatedRes, "days" ) && isArray( truncatedRes.days ) )
          ? truncatedRes.days
          : [];
        expect( toString( pickFirst( truncatedMeta, [ "distance_source" ], "" ) ) ).toBe( "preview_legs" );
        expect( arrayLen( truncatedDays ) ).toBe( 1 );
        expect( arrayLen( timelineDaySlices( truncatedDays[ 1 ] ) ) ).toBe( 1 );
      } );

      it( "splits an oversized first preview leg across multiple timeline days", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var legCtx = buildRouteLegContext();
        var timelineRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = dateFormat( now(), "yyyy-mm-dd" ),
          maxHoursPerDay = 8,
          inputOverrides = buildDeterministicTimelineOverrides(),
          previewLegs = [
            buildTimelinePreviewLeg( 1, 9301, 8301, "A", "B", 100, 0 )
          ]
        } );
        expect( !!pickFirst( timelineRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( serializeJSON( timelineRes ) );
        var timelineMeta = ( structKeyExists( timelineRes, "timeline_meta" ) && isStruct( timelineRes.timeline_meta ) )
          ? timelineRes.timeline_meta
          : {};
        var days = ( structKeyExists( timelineRes, "days" ) && isArray( timelineRes.days ) )
          ? timelineRes.days
          : [];
        expect( toString( pickFirst( timelineMeta, [ "distance_source" ], "" ) ) ).toBe( "preview_legs" );
        expect( arrayLen( days ) ).toBe( 2 );
        expect( countTimelineDaysForRouteLeg( days, 9301 ) ).toBe( 2 );

        var dayOneSlices = timelineDaySlices( days[ 1 ] );
        var dayTwoSlices = timelineDaySlices( days[ 2 ] );
        expect( arrayLen( dayOneSlices ) ).toBe( 1 );
        expect( arrayLen( dayTwoSlices ) ).toBe( 1 );
      } );

      it( "splits an oversized later preview leg while preserving earlier same-day legs", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var legCtx = buildRouteLegContext();
        var timelineRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = dateFormat( now(), "yyyy-mm-dd" ),
          maxHoursPerDay = 8,
          inputOverrides = buildDeterministicTimelineOverrides(),
          previewLegs = [
            buildTimelinePreviewLeg( 1, 9301, 8301, "A", "B", 40, 0 ),
            buildTimelinePreviewLeg( 2, 9302, 8302, "B", "C", 60, 0 )
          ]
        } );
        expect( !!pickFirst( timelineRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( serializeJSON( timelineRes ) );
        var timelineMeta = ( structKeyExists( timelineRes, "timeline_meta" ) && isStruct( timelineRes.timeline_meta ) )
          ? timelineRes.timeline_meta
          : {};
        var days = ( structKeyExists( timelineRes, "days" ) && isArray( timelineRes.days ) )
          ? timelineRes.days
          : [];
        expect( toString( pickFirst( timelineMeta, [ "distance_source" ], "" ) ) ).toBe( "preview_legs" );
        expect( arrayLen( days ) ).toBe( 2 );

        var dayOneSlices = timelineDaySlices( days[ 1 ] );
        var dayTwoSlices = timelineDaySlices( days[ 2 ] );
        expect( arrayLen( dayOneSlices ) ).toBe( 2 );
        expect( arrayLen( dayTwoSlices ) ).toBe( 1 );
        expect( countTimelineDaysForRouteLeg( days, 9301 ) ).toBe( 1 );
        expect( countTimelineDaysForRouteLeg( days, 9302 ) ).toBe( 2 );
      } );

      it( "keeps an exact-boundary preview leg in a single timeline day", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var legCtx = buildRouteLegContext();
        var timelineRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = dateFormat( now(), "yyyy-mm-dd" ),
          maxHoursPerDay = 8,
          inputOverrides = buildDeterministicTimelineOverrides(),
          previewLegs = [
            buildTimelinePreviewLeg( 1, 9301, 8301, "A", "B", 80, 0 )
          ]
        } );
        expect( !!pickFirst( timelineRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( serializeJSON( timelineRes ) );
        var timelineMeta = ( structKeyExists( timelineRes, "timeline_meta" ) && isStruct( timelineRes.timeline_meta ) )
          ? timelineRes.timeline_meta
          : {};
        var days = ( structKeyExists( timelineRes, "days" ) && isArray( timelineRes.days ) )
          ? timelineRes.days
          : [];
        expect( toString( pickFirst( timelineMeta, [ "distance_source" ], "" ) ) ).toBe( "preview_legs" );
        expect( arrayLen( days ) ).toBe( 1 );
        var dayOneSlices = timelineDaySlices( days[ 1 ] );
        expect( arrayLen( dayOneSlices ) ).toBe( 1 );
        expect( countTimelineDaysForRouteLeg( days, 9301 ) ).toBe( 1 );
      } );

      it( "supports My Routes leg geometry overrides and enforces per-user ownership", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }
        if ( !hasUserRouteTables() ) {
          skip( "user_routes tables are not present in this environment." );
        }
        if ( !hasUserRouteWaypointColumns() ) {
          skip( "user route waypoint columns are not present in this environment." );
        }

        var myRouteCtx = buildMyRouteContext();
        expect( myRouteCtx.routeId ).toBeGT( 0 );
        expect( myRouteCtx.routeLegId ).toBeGT( 0 );

        var getBefore = routeBuilderPost( "getRouteLegOverrideGeometry", {
          route_id = myRouteCtx.routeId,
          route_leg_id = myRouteCtx.routeLegId
        } );
        expect( pickBool( getBefore, "SUCCESS" ) ).toBeTrue( serializeJSON( getBefore ) );
        var getBeforeData = ( structKeyExists( getBefore, "DATA" ) && isStruct( getBefore.DATA ) )
          ? getBefore.DATA
          : {};
        expect( !!pickFirst( getBeforeData, [ "has_override", "HAS_OVERRIDE" ], true ) ).toBeFalse();

        var saveRes = routeBuilderPost( "saveRouteLegOverrideGeometry", {
          route_id = myRouteCtx.routeId,
          route_leg_id = myRouteCtx.routeLegId,
          points = [
            { lat = 41.900000, lon = -87.620000 },
            { lat = 41.950000, lon = -87.300000 },
            { lat = 42.020000, lon = -87.050000 }
          ]
        } );
        expect( pickBool( saveRes, "SUCCESS" ) ).toBeTrue( serializeJSON( saveRes ) );

        var getAfterSave = routeBuilderPost( "getRouteLegOverrideGeometry", {
          route_id = myRouteCtx.routeId,
          route_leg_id = myRouteCtx.routeLegId
        } );
        expect( pickBool( getAfterSave, "SUCCESS" ) ).toBeTrue( serializeJSON( getAfterSave ) );
        var getAfterSaveData = ( structKeyExists( getAfterSave, "DATA" ) && isStruct( getAfterSave.DATA ) )
          ? getAfterSave.DATA
          : {};
        expect( !!pickFirst( getAfterSaveData, [ "has_override", "HAS_OVERRIDE" ], false ) ).toBeTrue();

        var clearRes = routeBuilderPost( "clearRouteLegOverrideGeometry", {
          route_id = myRouteCtx.routeId,
          route_leg_id = myRouteCtx.routeLegId
        } );
        expect( pickBool( clearRes, "SUCCESS" ) ).toBeTrue( serializeJSON( clearRes ) );

        var getAfterClear = routeBuilderPost( "getRouteLegOverrideGeometry", {
          route_id = myRouteCtx.routeId,
          route_leg_id = myRouteCtx.routeLegId
        } );
        expect( pickBool( getAfterClear, "SUCCESS" ) ).toBeTrue( serializeJSON( getAfterClear ) );
        var getAfterClearData = ( structKeyExists( getAfterClear, "DATA" ) && isStruct( getAfterClear.DATA ) )
          ? getAfterClear.DATA
          : {};
        expect( !!pickFirst( getAfterClearData, [ "has_override", "HAS_OVERRIDE" ], true ) ).toBeFalse();

        var unauthorizedUserId = createTestUser();
        try {
          var unauthorizedSave = routeBuilderPostAsUser( "saveRouteLegOverrideGeometry", {
            route_id = myRouteCtx.routeId,
            route_leg_id = myRouteCtx.routeLegId,
            points = [
              { lat = 41.900000, lon = -87.620000 },
              { lat = 41.950000, lon = -87.300000 }
            ]
          }, unauthorizedUserId );
          expect( pickBool( unauthorizedSave, "SUCCESS" ) ).toBeFalse( serializeJSON( unauthorizedSave ) );
          expect( len( extractErrorMessage( unauthorizedSave ) ) ).toBeGT( 0 );

          var unauthorizedGet = routeBuilderPostAsUser( "getRouteLegOverrideGeometry", {
            route_id = myRouteCtx.routeId,
            route_leg_id = myRouteCtx.routeLegId
          }, unauthorizedUserId );
          expect( pickBool( unauthorizedGet, "SUCCESS" ) ).toBeFalse( serializeJSON( unauthorizedGet ) );
          expect( len( extractErrorMessage( unauthorizedGet ) ) ).toBeGT( 0 );
        } finally {
          deleteTestUser( unauthorizedUserId );
        }
      } );

      it( "returns route-not-found and unauthorized errors for guarded actions", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var missingLockRes = routeBuilderPost( "routegen_getleglocks", {
          route_code = "RB-NOPE-" & uniqueSuffix(),
          route_leg_id = 0,
          leg_order = 0,
          segment_id = 0
        } );
        expect( pickBool( missingLockRes, "SUCCESS" ) ).toBeFalse( serializeJSON(missingLockRes) );
        expect( findNoCase( "ROUTE NOT FOUND", uCase( extractErrorMessage( missingLockRes ) ) ) GT 0 ).toBeTrue();

        var missingUpdateRes = routeBuilderPost( "routegen_update", {
          route_code = "RB-NOPE-" & uniqueSuffix(),
          route_name = "Missing Route",
          template_code = "GULF-WEST",
          direction = "CCW"
        } );
        expect( pickBool( missingUpdateRes, "SUCCESS" ) ).toBeFalse( serializeJSON(missingUpdateRes) );
        expect( findNoCase( "ROUTE NOT FOUND", uCase( extractErrorMessage( missingUpdateRes ) ) ) GT 0 ).toBeTrue();

        var unauthorizedPayload = routeBuilderPostAnonymous( "routegen_getoptions", {
          template_code = "GULF-WEST",
          direction = "CCW"
        } );
        expect( pickBool( unauthorizedPayload, "SUCCESS" ) ).toBeFalse( serializeJSON( unauthorizedPayload ) );
        expect( !!pickFirst( unauthorizedPayload, [ "AUTH", "auth" ], true ) ).toBeFalse();
      } );
    } );
  }

  private struct function buildRouteLegContext() {
    var optionsRes = routeBuilderPost( "routegen_getoptions", {
      template_code = "GULF-WEST",
      direction = "CCW"
    } );
    if ( !pickBool( optionsRes, "SUCCESS" ) ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "routegen_getoptions failed",
        detail = serializeJSON( optionsRes )
      );
    }

    var optionsData = structKeyExists( optionsRes, "DATA" ) && isStruct( optionsRes.DATA ) ? optionsRes.DATA : {};
    var startOptions = structKeyExists( optionsData, "startOptions" ) && isArray( optionsData.startOptions ) ? optionsData.startOptions : [];
    var endOptions = structKeyExists( optionsData, "endOptions" ) && isArray( optionsData.endOptions ) ? optionsData.endOptions : [];
    if ( !arrayLen( startOptions ) || !arrayLen( endOptions ) ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "routegen_getoptions returned no start/end options",
        detail = serializeJSON( optionsRes )
      );
    }

    var templateCode = trim( toString( pickFirst( optionsData, [ "templateCode", "TEMPLATE_CODE", "template_code" ], "GULF-WEST" ) ) );
    var startRow = startOptions[ 1 ];
    var endRow = endOptions[ arrayLen( endOptions ) ];
    var startDate = dateFormat( now(), "yyyy-mm-dd" );
    var routeName = "Route Builder Spec " & uniqueSuffix();

    var generateRes = routeBuilderPost( "routegen_generate", {
      route_name = routeName,
      template_code = templateCode,
      direction = "CCW",
      start_segment_id = pickFirst( startRow, [ "segment_id", "SEGMENT_ID" ], 0 ),
      end_segment_id = pickFirst( endRow, [ "segment_id", "SEGMENT_ID" ], 0 ),
      start_location_label = pickFirst( startRow, [ "label", "LABEL" ], "" ),
      end_location_label = pickFirst( endRow, [ "label", "LABEL" ], "" ),
      start_date = startDate,
      optional_stop_flags = [ "ship_island_out_and_back" ]
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
    var routeId = val( pickFirst( generateRes, [ "ROUTE_ID", "route_id" ], 0 ) );
    if ( routeId LTE 0 && structKeyExists( generateRes, "DATA" ) && isStruct( generateRes.DATA ) ) {
      routeId = val( pickFirst( generateRes.DATA, [ "route_id", "ROUTE_ID" ], 0 ) );
    }

    return {
      routeId = routeId,
      routeCode = routeCode,
      templateCode = templateCode,
      routeLegId = val( pickFirst( firstLeg, [ "route_leg_id", "ROUTE_LEG_ID" ], 0 ) ),
      legOrder = val( pickFirst( firstLeg, [ "order_index", "ORDER_INDEX" ], 0 ) ),
      segmentId = val( pickFirst( firstLeg, [ "segment_id", "SEGMENT_ID" ], 0 ) ),
      inputs = inputs
    };
  }

  private struct function saveVesselForSpec( required struct vessel ) {
    return apiPostJson( variables.ctx.baseUrl & "/fpw/api/v1/vessel.cfc?method=handle", {
      action = "save",
      vessel = arguments.vessel
    }, true );
  }

  private struct function buildMyRouteContext() {
    var waypointStartId = createWaypointForUser(
      variables.ctx.forceUserId,
      "Spec Start " & uniqueSuffix(),
      41.880000,
      -87.620000
    );
    var waypointEndId = createWaypointForUser(
      variables.ctx.forceUserId,
      "Spec End " & uniqueSuffix(),
      42.100000,
      -87.100000
    );
    if ( waypointStartId LTE 0 || waypointEndId LTE 0 ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "Failed to create setup waypoints for My Route",
        detail = "start=#waypointStartId#, end=#waypointEndId#"
      );
    }

    var routeName = "Spec My Route " & uniqueSuffix();
    var createRes = routeBuilderPost( "createUserRoute", { route_name = routeName } );
    if ( !pickBool( createRes, "SUCCESS" ) ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "createUserRoute failed",
        detail = serializeJSON( createRes )
      );
    }
    var routeData = ( structKeyExists( createRes, "DATA" ) && isStruct( createRes.DATA ) )
      ? createRes.DATA
      : {};
    var routeId = val( pickFirst( routeData, [ "route_id", "ROUTE_ID" ], 0 ) );
    if ( routeId LTE 0 ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "createUserRoute returned invalid route_id",
        detail = serializeJSON( createRes )
      );
    }
    rememberCreatedMyRouteId( routeId );

    var setStartRes = routeBuilderPost( "setUserRouteStartWaypoint", {
      route_id = routeId,
      start_waypoint_id = waypointStartId
    } );
    if ( !pickBool( setStartRes, "SUCCESS" ) ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "setUserRouteStartWaypoint failed",
        detail = serializeJSON( setStartRes )
      );
    }

    var addLegRes = routeBuilderPost( "addWaypointLegToUserRoute", {
      route_id = routeId,
      end_waypoint_id = waypointEndId
    } );
    if ( !pickBool( addLegRes, "SUCCESS" ) ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "addWaypointLegToUserRoute failed",
        detail = serializeJSON( addLegRes )
      );
    }
    var addLegData = ( structKeyExists( addLegRes, "DATA" ) && isStruct( addLegRes.DATA ) )
      ? addLegRes.DATA
      : {};
    var legs = ( structKeyExists( addLegData, "legs" ) && isArray( addLegData.legs ) )
      ? addLegData.legs
      : [];
    if ( !arrayLen( legs ) ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "My Route returned no legs after add",
        detail = serializeJSON( addLegRes )
      );
    }
    var firstLeg = legs[ 1 ];
    return {
      routeId = routeId,
      routeLegId = val( pickFirst( firstLeg, [ "route_leg_id", "ROUTE_LEG_ID" ], 0 ) ),
      segmentId = val( pickFirst( firstLeg, [ "segment_id", "SEGMENT_ID" ], 0 ) ),
      startWaypointId = waypointStartId,
      endWaypointId = waypointEndId,
      defaultNm = val( pickFirst( firstLeg, [ "dist_nm", "DIST_NM" ], 0 ) )
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

  private numeric function sumTimelineEstHours( required array days ) {
    var total = 0;
    if ( !isArray( arguments.days ) ) return 0;
    for ( var row in arguments.days ) {
      if ( !isStruct( row ) ) continue;
      total += val( pickFirst( row, [ "est_hours", "EST_HOURS" ], 0 ) );
    }
    return round( total * 100 ) / 100;
  }

  private numeric function sumTimelineMetric( required array days, required string key ) {
    var total = 0;
    var upperKey = uCase( arguments.key );
    if ( !isArray( arguments.days ) ) return 0;
    for ( var row in arguments.days ) {
      if ( !isStruct( row ) ) continue;
      total += val( pickFirst( row, [ arguments.key, upperKey ], 0 ) );
    }
    return round( total * 100 ) / 100;
  }

  private numeric function sumTimelineDaySliceMetric( required struct day, required string key ) {
    var total = 0;
    var keys = [ arguments.key, uCase( arguments.key ) ];
    if ( lCase( arguments.key ) EQ "distance_nm" ) {
      arrayAppend( keys, "dist_nm" );
      arrayAppend( keys, "DIST_NM" );
    }
    var slices = timelineDaySlices( arguments.day );
    for ( var slice in slices ) {
      if ( !isStruct( slice ) ) continue;
      total += val( pickFirst( slice, keys, 0 ) );
    }
    return round( total * 100 ) / 100;
  }

  private numeric function sumTimelineSliceMetric( required array days, required string key ) {
    var total = 0;
    if ( !isArray( arguments.days ) ) return 0;
    for ( var day in arguments.days ) {
      if ( !isStruct( day ) ) continue;
      total += sumTimelineDaySliceMetric( day, arguments.key );
    }
    return round( total * 100 ) / 100;
  }

  private numeric function maxTimelineEstHours( required array days ) {
    var maxVal = 0;
    if ( !isArray( arguments.days ) ) return 0;
    for ( var row in arguments.days ) {
      if ( !isStruct( row ) ) continue;
      var estHoursVal = val( pickFirst( row, [ "est_hours", "EST_HOURS" ], 0 ) );
      if ( estHoursVal GT maxVal ) {
        maxVal = estHoursVal;
      }
    }
    return round( maxVal * 100 ) / 100;
  }

  private array function timelineDaySlices( required struct day ) {
    var slices = pickFirst( arguments.day, [ "segment_slices", "SEGMENT_SLICES" ], [] );
    return isArray( slices ) ? slices : [];
  }

  private numeric function countTimelineDaysForRouteLeg( required array days, required numeric routeLegId ) {
    var matches = 0;
    if ( !isArray( arguments.days ) || val( arguments.routeLegId ) LTE 0 ) return 0;
    for ( var day in arguments.days ) {
      if ( !isStruct( day ) ) continue;
      var slices = timelineDaySlices( day );
      for ( var slice in slices ) {
        if ( !isStruct( slice ) ) continue;
        if ( val( pickFirst( slice, [ "route_leg_id", "ROUTE_LEG_ID" ], 0 ) ) EQ val( arguments.routeLegId ) ) {
          matches += 1;
          break;
        }
      }
    }
    return matches;
  }

  private struct function buildDeterministicTimelineOverrides() {
    return {
      pace = "AGGRESSIVE",
      cruising_speed = 10,
      underway_hours_per_day = 8,
      weather_factor_pct = 0,
      fuel_burn_gph = 8,
      reserve_pct = 20
    };
  }

  private struct function buildTimelinePreviewLeg(
    required numeric orderIndex,
    required numeric routeLegId,
    required numeric segmentId,
    required string startName,
    required string endName,
    required numeric distNm,
    numeric lockCount = 0
  ) {
    return {
      order_index = int( val( arguments.orderIndex ) ),
      route_leg_id = int( val( arguments.routeLegId ) ),
      segment_id = int( val( arguments.segmentId ) ),
      start_name = arguments.startName,
      end_name = arguments.endName,
      dist_nm = round( val( arguments.distNm ) * 100 ) / 100,
      lock_count = int( val( arguments.lockCount ) )
    };
  }

  private boolean function routeInstancesHasInputsJsonColumn() {
    var qCol = queryExecute(
      "SELECT COUNT(*) AS cnt
       FROM information_schema.columns
       WHERE table_schema = DATABASE()
         AND table_name = 'route_instances'
         AND column_name = 'routegen_inputs_json'",
      {},
      { datasource = application.dsn }
    );
    return ( qCol.recordCount GT 0 && val( qCol.cnt[ 1 ] ) GT 0 );
  }

  private boolean function routeInstancesHasVesselIdColumn() {
    var qCol = queryExecute(
      "SELECT COUNT(*) AS cnt
       FROM information_schema.columns
       WHERE table_schema = DATABASE()
         AND table_name = 'route_instances'
         AND column_name = 'vessel_id'",
      {},
      { datasource = application.dsn }
    );
    return ( qCol.recordCount GT 0 && val( qCol.cnt[ 1 ] ) GT 0 );
  }

  private boolean function segmentLibraryHasExposureLevelColumn() {
    var qCol = queryExecute(
      "SELECT COUNT(*) AS cnt
       FROM information_schema.columns
       WHERE table_schema = DATABASE()
         AND table_name = 'segment_library'
         AND column_name = 'exposure_level'",
      {},
      { datasource = application.dsn }
    );
    return ( qCol.recordCount GT 0 && val( qCol.cnt[ 1 ] ) GT 0 );
  }

  private boolean function hasUserRouteTables() {
    var qTbl = queryExecute(
      "SELECT COUNT(*) AS cnt
       FROM information_schema.tables
       WHERE table_schema = DATABASE()
         AND table_name IN ('user_routes', 'user_route_legs')",
      {},
      { datasource = application.dsn }
    );
    return ( qTbl.recordCount GT 0 && val( qTbl.cnt[ 1 ] ) GTE 2 );
  }

  private boolean function hasUserRouteWaypointColumns() {
    var qCol = queryExecute(
      "SELECT COUNT(*) AS cnt
       FROM information_schema.columns
       WHERE table_schema = DATABASE()
         AND (
           (table_name = 'user_routes' AND column_name = 'start_waypoint_id')
           OR (table_name = 'user_route_legs' AND column_name IN ('start_waypoint_id', 'end_waypoint_id'))
         )",
      {},
      { datasource = application.dsn }
    );
    return ( qCol.recordCount GT 0 && val( qCol.cnt[ 1 ] ) GTE 3 );
  }

  private numeric function getRouteInstanceFirstSegmentId( required numeric routeId ) {
    var routeIdVal = val( arguments.routeId );
    if ( routeIdVal LTE 0 ) return 0;
    var qSeg = queryExecute(
      "SELECT ril.segment_id
       FROM route_instance_legs ril
       INNER JOIN route_instances ri ON ri.id = ril.route_instance_id
       WHERE ri.generated_route_id = :routeId
         AND ri.user_id = :uid
         AND ril.segment_id IS NOT NULL
         AND COALESCE(ril.base_dist_nm, 0) > 0
       ORDER BY ril.leg_order ASC, ril.id ASC
       LIMIT 1",
      {
        routeId = { value = routeIdVal, cfsqltype = "cf_sql_integer" },
        uid = { value = toString( variables.ctx.forceUserId ), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = application.dsn }
    );
    if ( qSeg.recordCount EQ 0 || isNull( qSeg.segment_id[ 1 ] ) ) return 0;
    return val( qSeg.segment_id[ 1 ] );
  }

  private struct function readSegmentExposureLevel( required numeric segmentId ) {
    var segIdVal = val( arguments.segmentId );
    if ( segIdVal LTE 0 ) return { found = false, isNull = true, value = 0 };
    var qSeg = queryExecute(
      "SELECT exposure_level
       FROM segment_library
       WHERE id = :segmentId
       LIMIT 1",
      {
        segmentId = { value = segIdVal, cfsqltype = "cf_sql_integer" }
      },
      { datasource = application.dsn }
    );
    if ( qSeg.recordCount EQ 0 ) return { found = false, isNull = true, value = 0 };
    if ( isNull( qSeg.exposure_level[ 1 ] ) ) {
      return { found = true, isNull = true, value = 0 };
    }
    return {
      found = true,
      isNull = false,
      value = int( val( qSeg.exposure_level[ 1 ] ) )
    };
  }

  private void function writeSegmentExposureLevel( required numeric segmentId, required any exposureLevel ) {
    var segIdVal = val( arguments.segmentId );
    if ( segIdVal LTE 0 ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "writeSegmentExposureLevel requires segmentId > 0",
        detail = serializeJSON( arguments )
      );
    }
    var isNullLevel = isNull( arguments.exposureLevel );
    var levelVal = ( isNullLevel ? 0 : int( val( arguments.exposureLevel ) ) );
    if ( !isNullLevel ) {
      if ( levelVal LT 0 ) levelVal = 0;
      if ( levelVal GT 3 ) levelVal = 3;
    }
    queryExecute(
      "UPDATE segment_library
       SET exposure_level = :exposureLevel
       WHERE id = :segmentId",
      {
        exposureLevel = isNullLevel
          ? { value = 0, null = true, cfsqltype = "cf_sql_tinyint" }
          : { value = levelVal, cfsqltype = "cf_sql_tinyint" },
        segmentId = { value = segIdVal, cfsqltype = "cf_sql_integer" }
      },
      { datasource = application.dsn }
    );
  }

  private void function setRouteInstanceInputsJson( required numeric routeId, required struct routeInputs ) {
    var routeIdVal = val( arguments.routeId );
    if ( routeIdVal LTE 0 ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "setRouteInstanceInputsJson requires routeId > 0",
        detail = serializeJSON( arguments )
      );
    }

    var qInst = queryExecute(
      "SELECT id
       FROM route_instances
       WHERE generated_route_id = :routeId
         AND user_id = :uid
       ORDER BY id DESC
       LIMIT 1",
      {
        routeId = { value = routeIdVal, cfsqltype = "cf_sql_integer" },
        uid = { value = toString( variables.ctx.forceUserId ), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = application.dsn }
    );
    if ( qInst.recordCount EQ 0 ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "No route_instances row found for generated route",
        detail = "routeId=#routeIdVal#, userId=#variables.ctx.forceUserId#"
      );
    }

    queryExecute(
      "UPDATE route_instances
       SET routegen_inputs_json = :inputsJson
       WHERE id = :id",
      {
        inputsJson = { value = serializeJSON( isStruct( arguments.routeInputs ) ? arguments.routeInputs : {} ), cfsqltype = "cf_sql_longvarchar" },
        id = { value = val( qInst.id[ 1 ] ), cfsqltype = "cf_sql_integer" }
      },
      { datasource = application.dsn }
    );
  }

  private void function rememberCreatedRouteCode( required string routeCode ) {
    var normalized = trim( arguments.routeCode );
    if ( !len( normalized ) ) return;
    if ( arrayFindNoCase( variables.ctx.createdRouteCodes, normalized ) EQ 0 ) {
      arrayAppend( variables.ctx.createdRouteCodes, normalized );
    }
  }

  private void function rememberCreatedMyRouteId( required numeric routeId ) {
    var rid = val( arguments.routeId );
    if ( rid LTE 0 ) return;
    if ( arrayFind( variables.ctx.createdMyRouteIds, rid ) EQ 0 ) {
      arrayAppend( variables.ctx.createdMyRouteIds, rid );
    }
  }

  private void function rememberCreatedWaypointId( required numeric waypointId ) {
    var wid = val( arguments.waypointId );
    if ( wid LTE 0 ) return;
    if ( arrayFind( variables.ctx.createdWaypointIds, wid ) EQ 0 ) {
      arrayAppend( variables.ctx.createdWaypointIds, wid );
    }
  }

  private numeric function createWaypointForUser(
    required numeric userId,
    required string name,
    required any latitude,
    required any longitude,
    string notes = ""
  ) {
    var uid = val( arguments.userId );
    var waypointName = trim( toString( arguments.name ) );
    var latText = trim( toString( arguments.latitude ) );
    var lngText = trim( toString( arguments.longitude ) );
    var noteText = trim( toString( arguments.notes ) );
    var insertRes = {};
    var waypointId = 0;

    if ( uid LTE 0 ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "createWaypointForUser requires userId > 0",
        detail = serializeJSON( arguments )
      );
    }
    if ( !len( waypointName ) ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "createWaypointForUser requires waypoint name",
        detail = serializeJSON( arguments )
      );
    }
    if ( !isNumeric( latText ) || !isNumeric( lngText ) ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "createWaypointForUser requires numeric latitude and longitude",
        detail = serializeJSON( arguments )
      );
    }

    queryExecute(
      "INSERT INTO waypoints (userId, name, latitude, longitude, notes)
       VALUES (:uid, :name, :latitude, :longitude, :notes)",
      {
        uid = { value = uid, cfsqltype = "cf_sql_integer" },
        name = { value = left( waypointName, 255 ), cfsqltype = "cf_sql_varchar" },
        latitude = { value = latText, cfsqltype = "cf_sql_varchar" },
        longitude = { value = lngText, cfsqltype = "cf_sql_varchar" },
        notes = { value = noteText, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = application.dsn, result = "insertRes" }
    );

    waypointId = val( structKeyExists( insertRes, "generatedKey" ) ? insertRes.generatedKey : 0 );
    if ( waypointId LTE 0 ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "createWaypointForUser failed to return generated waypoint id",
        detail = serializeJSON( insertRes )
      );
    }
    rememberCreatedWaypointId( waypointId );
    return waypointId;
  }

  private void function ensureSessionUser() {
    try {
      if ( !structKeyExists( session, "user" ) || !isStruct( session.user ) ) {
        session.user = {};
      }
      session.user.userId = variables.ctx.forceUserId;
      session.user.id = variables.ctx.forceUserId;
      session.user.USERID = variables.ctx.forceUserId;
    } catch ( any e ) {
      variables.ctx.sessionError = e.message;
    }
  }

  private struct function routeBuilderPost( required string action, struct body = {} ) {
    return apiPostJson( variables.ctx.routeBuilderActionBase & arguments.action, body, true );
  }

  private struct function routeBuilderPostAsUser( required string action, struct body = {}, required numeric userId ) {
    var originalUser = {};
    if ( structKeyExists( session, "user" ) && isStruct( session.user ) ) {
      originalUser = duplicate( session.user );
    }
    session.user = {
      userId = val( arguments.userId ),
      id = val( arguments.userId ),
      USERID = val( arguments.userId )
    };
    try {
      return routeBuilderPost( arguments.action, arguments.body );
    } finally {
      if ( structCount( originalUser ) ) {
        session.user = originalUser;
      } else {
        session.user = {
          userId = variables.ctx.forceUserId,
          id = variables.ctx.forceUserId,
          USERID = variables.ctx.forceUserId
        };
      }
    }
  }

  private struct function routeBuilderPostAnonymous( required string action, struct body = {} ) {
    return apiPostJson( variables.ctx.routeBuilderActionBase & arguments.action, body, false );
  }

  private numeric function createTestUser() {
    var uniqueEmail = "fpw-routebuilder-" & replace( createUUID(), "-", "", "all" ) & "@example.com";
    var payload = apiPostJson( variables.ctx.baseUrl & "/fpw/api/v1/join.cfc?method=handle", {
      firstName = "FPW",
      lastName = "RouteBuilder",
      email = uniqueEmail,
      password = "changeIt"
    }, false );
    if ( !pickBool( payload, "SUCCESS" ) ) {
      throw(
        type = "RouteBuilderActionsSpec.Setup",
        message = "createTestUser failed",
        detail = serializeJSON( payload )
      );
    }
    return val( pickFirst( payload, [ "USERID", "userId" ], 0 ) );
  }

  private void function deleteTestUser( required numeric userId ) {
    var userIdVal = val( arguments.userId );
    if ( userIdVal LTE 0 ) return;
    queryExecute(
      "DELETE FROM users_address WHERE userId = :userId",
      {
        userId = { value = userIdVal, cfsqltype = "cf_sql_integer" }
      },
      { datasource = application.dsn }
    );
    queryExecute(
      "DELETE FROM users WHERE userId = :userId",
      {
        userId = { value = userIdVal, cfsqltype = "cf_sql_integer" }
      },
      { datasource = application.dsn }
    );
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

  private struct function apiPostJson( required string url, struct body = {}, boolean includeCookies = true ) {
    var payload = isStruct( arguments.body ) ? arguments.body : {};
    var sessionCookies = arguments.includeCookies ? getSessionCookies() : [];
    var testHeaderUserId = resolveTestHeaderUserId( arguments.includeCookies );
    var res = {};
    cfhttp( method="POST", url=arguments.url, timeout="60", result="res" ) {
      cfhttpparam( type="header", name="Accept", value="application/json" );
      cfhttpparam( type="header", name="Content-Type", value="application/json; charset=utf-8" );
      if ( testHeaderUserId GT 0 ) {
        cfhttpparam( type="header", name="X-FPW-Test-UserId", value=toString( testHeaderUserId ) );
      }
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

  private string function extractErrorMessage( required struct payload ) {
    var errVal = pickFirst( arguments.payload, [ "ERROR", "error" ], {} );
    if ( isStruct( errVal ) ) {
      return trim( toString( pickFirst( errVal, [ "MESSAGE", "message" ], pickFirst( arguments.payload, [ "MESSAGE", "message" ], "" ) ) ) );
    }
    return trim( toString( errVal ) );
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
