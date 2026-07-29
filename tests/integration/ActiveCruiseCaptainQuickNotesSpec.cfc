component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.ctx = {
      createdPlanIds = [],
      createdRouteCodes = [],
      createdVesselIds = [],
      hadOriginalTestUserId = structKeyExists( url, "testUserId" ),
      originalTestUserId = structKeyExists( url, "testUserId" ) ? url.testUserId : "",
      originalSessionUser = ( structKeyExists( session, "user" ) && isStruct( session.user ) ) ? duplicate( session.user ) : {}
    };

    if ( structKeyExists( CGI, "SCRIPT_NAME" ) && findNoCase( "/testbox/", CGI.SCRIPT_NAME ) ) {
      variables.ctx.sessionReady = false;
      return;
    }

    var scheme = ( structKeyExists( CGI, "https" ) && CGI.https == "on" ) ? "https" : "http";
    var host = CGI.server_name;
    var port = CGI.server_port;
    var portPart = "";
    if ( !( scheme == "http" && port == 80 ) && !( scheme == "https" && port == 443 ) ) {
      portPart = ":" & port;
    }
    variables.ctx.baseUrl = scheme & "://" & host & portPart;
    variables.ctx.floatPlanHandleUrl = variables.ctx.baseUrl & "/fpw/api/v1/floatplan.cfc?method=handle";
    variables.ctx.sessionApiUser = createSessionApiUser();
    variables.ctx.forceUserId = variables.ctx.sessionApiUser.userId;
    url.testUserId = variables.ctx.forceUserId;
    setSessionUser( variables.ctx.forceUserId );
    variables.ctx.sessionReady = true;
    variables.ctx.monitorService = new fpw.api.v1.monitor().init();
    variables.ctx.apiSupport = new fpw.tests.support.FpwApiSupport().init(
      baseUrl = variables.ctx.baseUrl & "/fpw",
      authEmail = variables.ctx.sessionApiUser.email,
      authPassword = variables.ctx.sessionApiUser.password
    );
    variables.ctx.cleanupSupport = new fpw.tests.support.FpwCleanupSupport().init( variables.ctx.apiSupport );
  }

  function afterAll() {
    if ( structKeyExists( variables, "ctx" ) && structKeyExists( variables.ctx, "sessionReady" ) && variables.ctx.sessionReady ) {
      setSessionUser( variables.ctx.forceUserId );
      for ( var i = 1; i LTE arrayLen( variables.ctx.createdPlanIds ); i++ ) {
        cleanupCaptainLogArtifacts( variables.ctx.createdPlanIds[ i ] );
        deleteMonitoringRows( variables.ctx.createdPlanIds[ i ] );
        try { floatPlanPost( "delete", { floatPlanId = variables.ctx.createdPlanIds[ i ] } ); } catch ( any ignoredPlanCleanup ) {}
      }
      for ( var j = arrayLen( variables.ctx.createdRouteCodes ); j GTE 1; j-- ) {
        try { variables.ctx.cleanupSupport.cleanupRoute( variables.ctx.createdRouteCodes[ j ] ); } catch ( any ignoredRouteCleanup ) {}
      }
      for ( var k = arrayLen( variables.ctx.createdVesselIds ); k GTE 1; k-- ) {
        try { variables.ctx.cleanupSupport.cleanupVessel( variables.ctx.createdVesselIds[ k ] ); } catch ( any ignoredVesselCleanup ) {}
      }
      cleanupSessionApiUser();
    }

    if ( structKeyExists( variables, "ctx" ) && structKeyExists( variables.ctx, "originalSessionUser" ) && isStruct( variables.ctx.originalSessionUser ) && structCount( variables.ctx.originalSessionUser ) ) {
      session.user = variables.ctx.originalSessionUser;
    } else {
      structDelete( session, "user", false );
    }

    if ( structKeyExists( variables, "ctx" ) && structKeyExists( variables.ctx, "hadOriginalTestUserId" ) && variables.ctx.hadOriginalTestUserId ) {
      url.testUserId = variables.ctx.originalTestUserId;
    } else {
      structDelete( url, "testUserId", false );
    }
  }

  function run() {
    describe( "Active Cruise captain quick notes", function() {
      it( "saves private notes by default and posts publicly only when requested", function() {
        if ( !variables.ctx.sessionReady ) {
          skip( "Session scope not enabled for this runner. Use /fpw/tests/runner.cfm for integration tests." );
        }

        var plan = createRouteLinkedPlan( "captain-quick-notes" );
        expect( plan.planId ).toBeGT( 0, "Unable to create route-backed plan: #serializeJSON(plan)#" );

        setPlanSchedule( plan.planId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern" );
        markPlanActive( plan.planId );
        var startMonitoringRes = variables.ctx.monitorService.startMonitoringForFloatPlan( plan.planId, "active_route" );
        expect( pickBool( startMonitoringRes, "SUCCESS" ) ).toBeTrue( "start monitoring failed: #serializeJSON(startMonitoringRes)#" );

        var planState = loadRoutePlanState( plan.planId );
        var qLegs = loadRouteLegOrders( planState.route_instance_id );
        expect( qLegs.recordCount ).toBeGT( 0 );
        var firstLegOrder = val( qLegs.leg_order[ 1 ] );
        var privateNoteBody = "Private captain note " & uniqueSuffix();
        var postedNoteBody = "Posted captain note " & uniqueSuffix();

        var privateRes = floatPlanPost( "savecaptainlogentry", {
          floatPlanId = plan.planId,
          routeInstanceId = planState.route_instance_id,
          routeLegOrder = firstLegOrder,
          noteBody = privateNoteBody,
          noteTag = "All good",
          postToFollowStream = false
        } );
        expect( pickBool( privateRes, "SUCCESS" ) ).toBeTrue( "private captain note save failed: #serializeJSON(privateRes)#" );

        var qPrivateLog = loadCaptainLogRows( plan.planId, privateNoteBody );
        var qPrivatePosts = loadVoyagePostsForBody( plan.planId, privateNoteBody );
        expect( qPrivateLog.recordCount ).toBe( 1 );
        expect( val( qPrivateLog.posted_to_stream[ 1 ] ) ).toBe( 0 );
        expect( isNull( qPrivateLog.voyage_post_id[ 1 ] ) || val( qPrivateLog.voyage_post_id[ 1 ] ) EQ 0 ).toBeTrue();
        expect( qPrivatePosts.recordCount ).toBe( 0, "private note must not create voyage_posts row" );

        var activeCruiseHtml = apiGetPlain( variables.ctx.baseUrl & "/fpw/app/active-cruise.cfm" );
        expect( findNoCase( privateNoteBody, activeCruiseHtml ) GT 0 ).toBeTrue( "Active Cruise did not render saved private note" );
        expect( findNoCase( "Timeline", activeCruiseHtml ) GT 0 AND findNoCase( "Scheduled departure", activeCruiseHtml ) GT 0 ).toBeTrue( "Today's Timeline baseline content should remain present" );

        var postedRes = floatPlanPost( "savecaptainlogentry", {
          floatPlanId = plan.planId,
          routeInstanceId = planState.route_instance_id,
          routeLegOrder = firstLegOrder,
          noteBody = postedNoteBody,
          noteTag = "Marina call",
          postToFollowStream = true
        } );
        expect( pickBool( postedRes, "SUCCESS" ) ).toBeTrue( "posted captain note save failed: #serializeJSON(postedRes)#" );

        var qPostedLog = loadCaptainLogRows( plan.planId, postedNoteBody );
        var qPostedPosts = loadVoyagePostsForBody( plan.planId, postedNoteBody );
        expect( qPostedLog.recordCount ).toBe( 1 );
        expect( val( qPostedLog.posted_to_stream[ 1 ] ) ).toBe( 1 );
        expect( val( qPostedLog.voyage_post_id[ 1 ] ) ).toBeGT( 0 );
        expect( qPostedPosts.recordCount ).toBe( 1, "posted note should create exactly one voyage_posts row" );
        expect( val( qPostedPosts.id[ 1 ] ) ).toBe( val( qPostedLog.voyage_post_id[ 1 ] ) );

        var originalSessionUser = duplicate( session.user );
        try {
          setSessionUser( 999999 );
          var crossUserRes = floatPlanPost( "savecaptainlogentry", {
            floatPlanId = plan.planId,
            noteBody = "Cross-user captain note " & uniqueSuffix(),
            noteTag = "Mechanical"
          } );
          expect( pickBool( crossUserRes, "SUCCESS" ) ).toBeFalse( "cross-user note save should fail: #serializeJSON(crossUserRes)#" );
          expect( uCase( toString( pickFirst( crossUserRes, [ "ERROR", "error" ], "" ) ) ) ).toBe( "NOT_FOUND" );
        } finally {
          session.user = originalSessionUser;
        }
      } );
    } );
  }

  private struct function createRouteLinkedPlan( required string scenarioSlug ) {
    var prefix = "captain-notes-" & arguments.scenarioSlug & "-" & uniqueSuffix();
    var vesselPayload = variables.ctx.apiSupport.saveVessel( {
      vesselId = 0,
      vesselName = prefix & " Vessel",
      type = "Cruiser",
      length = 34,
      color = "White"
    } );
    expect( pickBool( vesselPayload, "SUCCESS" ) ).toBeTrue( serializeJSON( vesselPayload ) );
    var vesselId = val( vesselPayload.VESSELID ?: 0 );
    rememberCreatedVesselId( vesselId );

    var options = variables.ctx.apiSupport.routeBuilder( "routegen_getoptions", {
      template_code = "GULF-WEST",
      direction = "CCW"
    } );
    expect( pickBool( options, "SUCCESS" ) ).toBeTrue( serializeJSON( options ) );

    var generate = variables.ctx.apiSupport.routeBuilder( "routegen_generate", {
      route_name = prefix & " Route",
      template_code = "GULF-WEST",
      direction = "CCW",
      start_segment_id = options.DATA.startOptions[ 1 ].segment_id,
      end_segment_id = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].segment_id,
      start_location_label = options.DATA.startOptions[ 1 ].label,
      end_location_label = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].label,
      start_date = dateFormat( now(), "yyyy-mm-dd" ),
      optional_stop_flags = [ "ship_island_out_and_back" ]
    } );
    expect( pickBool( generate, "SUCCESS" ) ).toBeTrue( serializeJSON( generate ) );

    var routeCode = trim( toString( generate.ROUTE_CODE ?: generate.DATA.route_code ?: "" ) );
    arrayAppend( variables.ctx.createdRouteCodes, routeCode );

    var buildPayload = variables.ctx.apiSupport.routeBuilder( "buildFloatPlansFromRoute", {
      routeCode = routeCode,
      mode = "DAILY",
      vesselId = vesselId,
      rebuild = 0
    } );
    expect( pickBool( buildPayload, "SUCCESS" ) ).toBeTrue( serializeJSON( buildPayload ) );

    var planId = val( buildPayload.FLOATPLAN_IDS[ 1 ] ?: 0 );
    expect( planId ).toBeGT( 0, serializeJSON( buildPayload ) );
    rememberCreatedPlanId( planId );

    return {
      planId = planId,
      routeCode = routeCode,
      vesselId = vesselId
    };
  }

  private void function rememberCreatedPlanId( required numeric planId ) {
    if ( arguments.planId GT 0 && arrayFind( variables.ctx.createdPlanIds, arguments.planId ) EQ 0 ) {
      arrayAppend( variables.ctx.createdPlanIds, arguments.planId );
    }
  }

  private void function rememberCreatedVesselId( required numeric vesselId ) {
    if ( arguments.vesselId GT 0 && arrayFind( variables.ctx.createdVesselIds, arguments.vesselId ) EQ 0 ) {
      arrayAppend( variables.ctx.createdVesselIds, arguments.vesselId );
    }
  }

  private void function setSessionUser( required numeric userId ) {
    if ( !structKeyExists( session, "user" ) || !isStruct( session.user ) ) {
      session.user = {};
    }
    session.user.userId = arguments.userId;
    session.user.id = arguments.userId;
    session.user.USERID = arguments.userId;
  }

  private void function markPlanActive( required numeric planId ) {
    queryExecute(
      "UPDATE floatplans
       SET `status` = 'ACTIVE',
           activatedAt = UTC_TIMESTAMP(),
           checkedInAt = NULL,
           checkin_context = NULL,
           closedAt = NULL,
           lastUpdateStatus = UTC_TIMESTAMP()
       WHERE floatplanId = :floatPlanId",
      {
        floatPlanId = { value = arguments.planId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function setPlanSchedule(
    required numeric planId,
    required string departureLocal,
    required string returnLocal,
    required string timeZoneId
  ) {
    queryExecute(
      "UPDATE floatplans
       SET departureTime = CONVERT_TZ(:departureLocal, :timeZoneId, 'UTC'),
           departTimezone = :timeZoneId,
           departureTZ = :timeZoneId,
           returnTime = CONVERT_TZ(:returnLocal, :timeZoneId, 'UTC'),
           returnTimezone = :timeZoneId,
           returnTZ = :timeZoneId,
           checkedInAt = NULL,
           checkin_context = NULL,
           closedAt = NULL,
           lastUpdateStatus = UTC_TIMESTAMP()
       WHERE floatplanId = :floatPlanId",
      {
        departureLocal = { value = arguments.departureLocal, cfsqltype = "cf_sql_timestamp" },
        returnLocal = { value = arguments.returnLocal, cfsqltype = "cf_sql_timestamp" },
        timeZoneId = { value = arguments.timeZoneId, cfsqltype = "cf_sql_varchar" },
        floatPlanId = { value = arguments.planId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private struct function loadRoutePlanState( required numeric planId ) {
    var qPlan = queryExecute(
      "SELECT userId, route_instance_id, `status`
       FROM floatplans
       WHERE floatplanId = :floatPlanId
       LIMIT 1",
      {
        floatPlanId = { value = arguments.planId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    expect( qPlan.recordCount ).toBe( 1 );
    return {
      user_id = val( qPlan.userId[ 1 ] ),
      route_instance_id = val( qPlan.route_instance_id[ 1 ] ),
      status = trim( toString( qPlan.status[ 1 ] ) )
    };
  }

  private query function loadRouteLegOrders( required numeric routeInstanceId ) {
    return queryExecute(
      "SELECT leg_order
       FROM route_instance_legs
       WHERE route_instance_id = :routeInstanceId
       ORDER BY leg_order ASC, id ASC",
      {
        routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private query function loadCaptainLogRows( required numeric planId, required string noteBody ) {
    return queryExecute(
      "SELECT id, posted_to_stream, voyage_post_id, note_tag, note_body
       FROM floatplan_captain_log_entries
       WHERE floatplan_id = :floatPlanId
         AND note_body = :noteBody
         AND deleted_utc IS NULL
       ORDER BY id DESC",
      {
        floatPlanId = { value = arguments.planId, cfsqltype = "cf_sql_integer" },
        noteBody = { value = arguments.noteBody, cfsqltype = "cf_sql_longvarchar" }
      },
      { datasource = "fpw" }
    );
  }

  private query function loadVoyagePostsForBody( required numeric planId, required string postBody ) {
    return queryExecute(
      "SELECT vp.id, vp.stream_id, vp.author_type, vp.post_type, vp.event_type, vp.body
       FROM voyage_posts vp
       INNER JOIN voyage_streams vs ON vs.id = vp.stream_id
       WHERE vs.floatplan_id = :floatPlanId
         AND vp.body = :postBody
       ORDER BY vp.id DESC",
      {
        floatPlanId = { value = arguments.planId, cfsqltype = "cf_sql_integer" },
        postBody = { value = arguments.postBody, cfsqltype = "cf_sql_longvarchar" }
      },
      { datasource = "fpw" }
    );
  }

  private void function deleteMonitoringRows( required numeric planId ) {
    queryExecute(
      "DELETE FROM floatplan_monitor_events WHERE float_plan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.planId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM floatplan_monitoring WHERE float_plan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.planId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function cleanupCaptainLogArtifacts( required numeric planId ) {
    var qStreams = queryExecute(
      "SELECT id
       FROM voyage_streams
       WHERE floatplan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.planId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );

    queryExecute(
      "DELETE FROM floatplan_captain_log_entries
       WHERE floatplan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.planId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );

    for ( var i = 1; i LTE qStreams.recordCount; i++ ) {
      queryExecute(
        "DELETE vr
         FROM voyage_reactions vr
         INNER JOIN voyage_posts vp ON vp.id = vr.post_id
         WHERE vp.stream_id = :streamId",
        {
          streamId = { value = qStreams.id[ i ], cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
      queryExecute(
        "DELETE vc
         FROM voyage_comments vc
         INNER JOIN voyage_posts vp ON vp.id = vc.post_id
         WHERE vp.stream_id = :streamId",
        {
          streamId = { value = qStreams.id[ i ], cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
      queryExecute(
        "DELETE FROM voyage_posts
         WHERE stream_id = :streamId",
        {
          streamId = { value = qStreams.id[ i ], cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
      queryExecute(
        "DELETE FROM voyage_followers
         WHERE stream_id = :streamId",
        {
          streamId = { value = qStreams.id[ i ], cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
      queryExecute(
        "DELETE FROM voyage_streams
         WHERE id = :streamId",
        {
          streamId = { value = qStreams.id[ i ], cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
    }
  }

  private struct function createSessionApiUser() {
    var uniqueEmail = "fpw-captain-notes-" & replace( createUUID(), "-", "", "all" ) & "@example.com";
    var payload = apiPostJson(
      variables.ctx.baseUrl & "/fpw/api/v1/join.cfc?method=handle",
      {
        firstName = "FPW",
        lastName = "CaptainNotes",
        email = uniqueEmail,
        password = "changeIt"
      },
      false
    );

    if ( !structKeyExists( payload, "SUCCESS" ) || payload.SUCCESS NEQ true ) {
      throw( message = "ActiveCruiseCaptainQuickNotesSpec setup failed: createSessionApiUser", detail = serializeJSON( payload ) );
    }

    return {
      userId = val( payload.USERID ?: 0 ),
      email = uniqueEmail,
      password = "changeIt"
    };
  }

  private void function cleanupSessionApiUser() {
    var userId = val( variables.ctx.sessionApiUser.userId ?: 0 );
    if ( userId LTE 0 ) {
      return;
    }
    queryExecute(
      "DELETE FROM users_address WHERE userId = :userId",
      {
        userId = { value = userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM users WHERE userId = :userId",
      {
        userId = { value = userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private struct function floatPlanPost( required string action, struct payload = {} ) {
    var body = isStruct( arguments.payload ) ? duplicate( arguments.payload ) : {};
    body.action = arguments.action;
    return apiPostJson( variables.ctx.floatPlanHandleUrl, body, true );
  }

  private string function apiGetPlain( required string url ) {
    var sessionCookies = getSessionCookies();
    var res = {};
    cfhttp( method="GET", url=arguments.url, timeout="60", result="res" ) {
      cfhttpparam( type="header", name="Accept", value="text/html" );
      for ( var cookiePair in sessionCookies ) {
        cfhttpparam( type="cookie", name=cookiePair.name, value=cookiePair.value );
      }
    }
    return structKeyExists( res, "fileContent" ) ? toString( res.fileContent ) : "";
  }

  private struct function apiPostJson( required string url, required struct body, boolean includeCookies = true ) {
    var sessionCookies = arguments.includeCookies ? getSessionCookies() : [];
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
