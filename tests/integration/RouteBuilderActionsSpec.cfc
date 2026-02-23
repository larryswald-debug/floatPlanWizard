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

        // C) Alias key present => route_inputs_alias
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
        expect( toString( pickFirst( aliasMeta, [ "fuel_source" ], "" ) ) ).toBe( "route_inputs_alias" );
        expect( toString( pickFirst( aliasMeta, [ "fuel_key" ], "" ) ) ).toBe( "maxBurnGph" );
        expect( val( pickFirst( aliasMeta, [ "fuel_burn_gph" ], 0 ) ) ).toBeGT( 0 );
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
        expect( val( pickFirst( aliasDays[ 1 ], [ "reserve_gallons" ], 0 ) ) ).toBeGT( 0 );
      } );

      it( "uses weather-adjusted speed for timeline hours and day bucketing", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var legCtx = buildRouteLegContext();
        var startDate = dateFormat( now(), "yyyy-mm-dd" );

        var previewRes = routeBuilderPost( "routegen_preview", legCtx.inputs );
        expect( pickBool( previewRes, "SUCCESS" ) ).toBeTrue( "routegen_preview failed for weather hours test: #serializeJSON(previewRes)#" );
        var previewData = ( structKeyExists( previewRes, "DATA" ) && isStruct( previewRes.DATA ) )
          ? previewRes.DATA
          : {};
        var previewLegs = ( structKeyExists( previewData, "legs" ) && isArray( previewData.legs ) )
          ? duplicate( previewData.legs )
          : [];
        expect( arrayLen( previewLegs ) ).toBeGT( 0, "No preview legs returned for weather hours test: #serializeJSON(previewRes)#" );

        var baseRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = startDate,
          maxHoursPerDay = 6.5,
          previewLegs = previewLegs,
          inputOverrides = {
            pace = "BALANCED",
            cruising_speed = 20,
            weather_factor_pct = 0,
            fuel_burn_gph = 8,
            reserve_pct = 20
          }
        } );
        expect( !!pickFirst( baseRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( "base weather timeline failed: #serializeJSON(baseRes)#" );
        var baseDays = ( structKeyExists( baseRes, "days" ) && isArray( baseRes.days ) ) ? baseRes.days : [];
        var baseSummary = ( structKeyExists( baseRes, "route_summary" ) && isStruct( baseRes.route_summary ) ) ? baseRes.route_summary : {};
        expect( arrayLen( baseDays ) ).toBeGT( 0, "Base timeline days missing: #serializeJSON(baseRes)#" );
        var baseTotalHours = sumTimelineEstHours( baseDays );
        var baseTotalDays = val( pickFirst( baseSummary, [ "total_days" ], arrayLen( baseDays ) ) );

        var weatherRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = startDate,
          maxHoursPerDay = 6.5,
          previewLegs = previewLegs,
          inputOverrides = {
            pace = "BALANCED",
            cruising_speed = 20,
            weather_factor_pct = 30,
            fuel_burn_gph = 8,
            reserve_pct = 20
          }
        } );
        expect( !!pickFirst( weatherRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( "weather timeline failed: #serializeJSON(weatherRes)#" );
        var weatherDays = ( structKeyExists( weatherRes, "days" ) && isArray( weatherRes.days ) ) ? weatherRes.days : [];
        var weatherSummary = ( structKeyExists( weatherRes, "route_summary" ) && isStruct( weatherRes.route_summary ) ) ? weatherRes.route_summary : {};
        expect( arrayLen( weatherDays ) ).toBeGT( 0, "Weather timeline days missing: #serializeJSON(weatherRes)#" );
        var weatherTotalHours = sumTimelineEstHours( weatherDays );
        var weatherTotalDays = val( pickFirst( weatherSummary, [ "total_days" ], arrayLen( weatherDays ) ) );

        expect( weatherTotalHours ).toBeGT( baseTotalHours );
        expect( weatherTotalDays GTE baseTotalDays ).toBeTrue( "Higher weather factor should not reduce day count." );

        var weatherMeta = ( structKeyExists( weatherRes, "timeline_meta" ) && isStruct( weatherRes.timeline_meta ) )
          ? weatherRes.timeline_meta
          : {};
        expect( toString( pickFirst( weatherMeta, [ "hours_source", "HOURS_SOURCE" ], "" ) ) ).toBe( "weather_adjusted_speed" );
      } );

      it( "applies generateCruiseTimeline inputOverrides without persisting route inputs", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }
        if ( !routeInstancesHasInputsJsonColumn() ) {
          skip( "route_instances.routegen_inputs_json not present in this environment." );
        }

        var legCtx = buildRouteLegContext();
        var startDate = dateFormat( now(), "yyyy-mm-dd" );

        setRouteInstanceInputsJson( legCtx.routeId, {
          fuel_burn_gph = 8,
          reserve_pct = 20,
          weather_factor_pct = 0,
          pace = "RELAXED",
          cruising_speed = 20
        } );

        var baseRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = startDate,
          maxHoursPerDay = 6.5
        } );
        expect( !!pickFirst( baseRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( "baseline timeline failed: #serializeJSON(baseRes)#" );
        var baseSummary = ( structKeyExists( baseRes, "route_summary" ) && isStruct( baseRes.route_summary ) )
          ? baseRes.route_summary
          : {};
        var baseRequiredFuel = val( pickFirst( baseSummary, [ "total_required_fuel" ], 0 ) );
        expect( baseRequiredFuel ).toBeGT( 0 );

        var overrideRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = startDate,
          maxHoursPerDay = 6.5,
          inputOverrides = {
            fuel_burn_gph = 16,
            reserve_pct = 35,
            weather_factor_pct = 10,
            pace = "BALANCED",
            cruising_speed = 22
          }
        } );
        expect( !!pickFirst( overrideRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( "override timeline failed: #serializeJSON(overrideRes)#" );
        var overrideSummary = ( structKeyExists( overrideRes, "route_summary" ) && isStruct( overrideRes.route_summary ) )
          ? overrideRes.route_summary
          : {};
        var overrideRequiredFuel = val( pickFirst( overrideSummary, [ "total_required_fuel" ], 0 ) );
        expect( overrideRequiredFuel ).toBeGT( baseRequiredFuel );

        var overrideMeta = ( structKeyExists( overrideRes, "timeline_meta" ) && isStruct( overrideRes.timeline_meta ) )
          ? overrideRes.timeline_meta
          : {};
        expect( val( pickFirst( overrideMeta, [ "fuel_burn_gph" ], 0 ) ) ).toBeGT( 8 );

        var baseAgainRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = startDate,
          maxHoursPerDay = 6.5
        } );
        expect( !!pickFirst( baseAgainRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( "baseline timeline after override failed: #serializeJSON(baseAgainRes)#" );
        var baseAgainSummary = ( structKeyExists( baseAgainRes, "route_summary" ) && isStruct( baseAgainRes.route_summary ) )
          ? baseAgainRes.route_summary
          : {};
        expect( val( pickFirst( baseAgainSummary, [ "total_required_fuel" ], -1 ) ) ).toBe( baseRequiredFuel );
      } );

      it( "uses previewLegs as the distance source for timeline totals when provided", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var legCtx = buildRouteLegContext();
        var startDate = dateFormat( now(), "yyyy-mm-dd" );

        var baselineRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = startDate,
          maxHoursPerDay = 6.5
        } );
        expect( !!pickFirst( baselineRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( "baseline timeline failed: #serializeJSON(baselineRes)#" );
        var baselineSummary = ( structKeyExists( baselineRes, "route_summary" ) && isStruct( baselineRes.route_summary ) )
          ? baselineRes.route_summary
          : {};
        var baselineNm = val( pickFirst( baselineSummary, [ "total_nm", "TOTAL_NM" ], 0 ) );

        var previewRes = routeBuilderPost( "routegen_preview", legCtx.inputs );
        expect( pickBool( previewRes, "SUCCESS" ) ).toBeTrue( "routegen_preview failed for previewLegs test: #serializeJSON(previewRes)#" );
        var previewData = ( structKeyExists( previewRes, "DATA" ) && isStruct( previewRes.DATA ) )
          ? previewRes.DATA
          : {};
        var previewLegs = ( structKeyExists( previewData, "legs" ) && isArray( previewData.legs ) )
          ? duplicate( previewData.legs )
          : [];
        expect( arrayLen( previewLegs ) ).toBeGT( 0, "No preview legs returned for previewLegs timeline test: #serializeJSON(previewRes)#" );

        var firstDist = val( pickFirst( previewLegs[ 1 ], [ "dist_nm", "DIST_NM" ], 0 ) );
        previewLegs[ 1 ].dist_nm = round( ( firstDist + 7.5 ) * 10 ) / 10;

        var expectedNm = 0;
        for ( var i = 1; i LTE arrayLen( previewLegs ); i++ ) {
          expectedNm += val( pickFirst( previewLegs[ i ], [ "dist_nm", "DIST_NM" ], 0 ) );
        }
        expectedNm = round( expectedNm * 100 ) / 100;

        var previewTimelineRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = startDate,
          maxHoursPerDay = 6.5,
          previewLegs = previewLegs
        } );
        expect( !!pickFirst( previewTimelineRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( "previewLegs timeline failed: #serializeJSON(previewTimelineRes)#" );
        var previewSummary = ( structKeyExists( previewTimelineRes, "route_summary" ) && isStruct( previewTimelineRes.route_summary ) )
          ? previewTimelineRes.route_summary
          : {};
        var previewNm = val( pickFirst( previewSummary, [ "total_nm", "TOTAL_NM" ], 0 ) );
        expect( previewNm ).toBe( expectedNm );
        expect( previewNm ).toBeGT( baselineNm );

        var previewMeta = ( structKeyExists( previewTimelineRes, "timeline_meta" ) && isStruct( previewTimelineRes.timeline_meta ) )
          ? previewTimelineRes.timeline_meta
          : {};
        expect( toString( pickFirst( previewMeta, [ "distance_source", "DISTANCE_SOURCE" ], "" ) ) ).toBe( "preview_legs" );

        var ignoredPreviewRes = routeBuilderPost( "generateCruiseTimeline", {
          routeId = legCtx.routeId,
          startDate = startDate,
          maxHoursPerDay = 6.5,
          previewLegs = [ { foo = "bar" } ]
        } );
        expect( !!pickFirst( ignoredPreviewRes, [ "success", "SUCCESS" ], false ) ).toBeTrue( "invalid previewLegs should fallback to persisted rows: #serializeJSON(ignoredPreviewRes)#" );
        var ignoredMeta = ( structKeyExists( ignoredPreviewRes, "timeline_meta" ) && isStruct( ignoredPreviewRes.timeline_meta ) )
          ? ignoredPreviewRes.timeline_meta
          : {};
        expect( toString( pickFirst( ignoredMeta, [ "distance_source", "DISTANCE_SOURCE" ], "" ) ) ).toBe( "route_instance_legs" );
        expect( !!pickFirst( ignoredMeta, [ "preview_legs_ignored", "PREVIEW_LEGS_IGNORED" ], false ) ).toBeTrue();
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
