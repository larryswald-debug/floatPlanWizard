component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.api = new fpw.tests.support.FpwApiSupport().init(
      authEmail = "detroit@email.com",
      authPassword = "changeIt"
    );
    variables.naming = new fpw.tests.support.FpwNamingSupport();
    variables.entitlements = new fpw.api.v1.MemberEntitlementService().init( "fpw" );
    variables.hadOriginalTestUserId = structKeyExists( url, "testUserId" );
    variables.originalTestUserId = variables.hadOriginalTestUserId ? url.testUserId : "";
    variables.hadOriginalSessionUser = structKeyExists( session, "user" );
    variables.originalSessionUser = ( variables.hadOriginalSessionUser && isStruct( session.user ) ) ? duplicate( session.user ) : {};
    variables.sessionApiUser = createSessionApiUser();
    setActiveCruiseSessionUser( variables.sessionApiUser.userId );
  }

  function afterAll() {
    cleanupSessionApiUser();
    if ( variables.hadOriginalTestUserId ) {
      url.testUserId = variables.originalTestUserId;
    } else {
      structDelete( url, "testUserId", false );
    }
    restoreActiveCruiseSessionUser();
  }

  function run() {
    describe( "Active Cruise On Track check-in contract", function() {
      it( "On Track Active Cruise check-in succeeds with a live-derived active_route monitoring row", function() {
        var prefix = variables.naming.buildPrefix( "active-cruise-ontrack", "api-success" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var asset = {};
        var checkinResult = {};
        var monitoringRow = {};
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern", "08:00:00" );
          markPlanActive( asset.floatPlanId );
          seedMonitoringRow( asset.floatPlanId, variables.sessionApiUser.userId );

          checkinResult = postActiveCruiseCheckinWithApi( sessionApi, asset.floatPlanId, "On Track" );
          monitoringRow = loadMonitoringRow( asset.floatPlanId );

          expect( checkinResult.success ).toBeTrue( serializeJSON( checkinResult ) );
          expect( monitoringRow.monitor_state ).toBe( "ACTIVE" );
          expect( monitoringRow.last_checkin_status ).toBe( "ON_TRACK" );
          expect( isDate( monitoringRow.expected_checkin_at ) ).toBeTrue();
          expect( isDate( monitoringRow.grace_expires_at ) ).toBeTrue();
        } finally {
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "On Track Active Cruise check-in stores optional GPS in the canonical activity payload", function() {
        var prefix = variables.naming.buildPrefix( "active-cruise-ontrack", "gps-payload" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var asset = {};
        var checkinResult = {};
        var monitoringRow = {};
        var canonicalPayload = {};
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";
        var location = {
          latitude = 29.1234567,
          longitude = -82.9876543,
          accuracyMeters = 18.4,
          altitudeMeters = 2.5,
          speedKnots = 6.2,
          headingDegrees = 142,
          capturedAtUtc = "2026-05-11T13:15:00Z",
          source = "ACTIVE_CRUISE_WEB"
        };

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern", "08:00:00" );
          markPlanActive( asset.floatPlanId );
          seedMonitoringRow( asset.floatPlanId, variables.sessionApiUser.userId );

          checkinResult = postActiveCruiseCheckinWithApi( sessionApi, asset.floatPlanId, "On Track", "GPS check-in", location );
          monitoringRow = loadMonitoringRow( asset.floatPlanId );
          canonicalPayload = loadLatestCanonicalCheckinPayload( asset.floatPlanId );

          expect( checkinResult.success ).toBeTrue( serializeJSON( checkinResult ) );
          expect( monitoringRow.monitor_state ).toBe( "ACTIVE" );
          expect( monitoringRow.last_checkin_status ).toBe( "ON_TRACK" );
          expect( structKeyExists( canonicalPayload, "location" ) ).toBeTrue( serializeJSON( canonicalPayload ) );
          expect( canonicalPayload.location.source ).toBe( "ACTIVE_CRUISE_WEB" );
          expect( numberFormat( val( canonicalPayload.location.latitude ), "0.0000000" ) ).toBe( "29.1234567" );
          expect( numberFormat( val( canonicalPayload.location.longitude ), "0.0000000" ) ).toBe( "-82.9876543" );
          expect( numberFormat( val( canonicalPayload.location.accuracyMeters ), "0.0" ) ).toBe( "18.4" );
          expect( canonicalPayload.location.capturedAtUtc ).toBe( "2026-05-11T13:15:00Z" );
        } finally {
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "On Track Active Cruise check-in still resolves active-route timezone and local day start rule live", function() {
        var prefix = variables.naming.buildPrefix( "active-cruise-ontrack", "derived-timing" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var asset = {};
        var checkinResult = {};
        var monitoringRow = {};
        var timeZoneId = pickAfterEveningTimeZoneId();
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", timeZoneId, "07:15:00" );
          markPlanActive( asset.floatPlanId );
          seedMonitoringRow( asset.floatPlanId, variables.sessionApiUser.userId );

          checkinResult = postActiveCruiseCheckinWithApi( sessionApi, asset.floatPlanId, "On Track" );
          monitoringRow = loadMonitoringRow( asset.floatPlanId );

          expect( checkinResult.success ).toBeTrue( serializeJSON( checkinResult ) );
          expect( right( toLocalStamp( monitoringRow.expected_checkin_at, timeZoneId ), 8 ) ).toBe( "07:15:00" );
        } finally {
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "Dashboard active-trip resolution uses the canonical monitoring row instead of legacy float plan status tiers", function() {
        var prefix = variables.naming.buildPrefix( "active-cruise-ontrack", "dashboard-canonical" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var asset = {};
        var routesPayload = {};
        var activeTrip = {};
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern", "08:00:00" );
          markPlanActive( asset.floatPlanId );
          seedMonitoringRow( asset.floatPlanId, variables.sessionApiUser.userId, "ACTIVE" );

          routesPayload = sessionApi.routeBuilder( "listUserRoutes" );
          activeTrip = isStruct( routesPayload.ACTIVE_TRIP ?: "" ) ? routesPayload.ACTIVE_TRIP : {};

          expect( routesPayload.SUCCESS ).toBeTrue( serializeJSON( routesPayload ) );
          expect( activeTrip.SUCCESS ?: false ).toBeTrue( serializeJSON( routesPayload ) );
          expect( val( activeTrip.FLOATPLAN_ID ?: 0 ) ).toBe( asset.floatPlanId );
          expect( val( activeTrip.ROUTE_INSTANCE_ID ?: 0 ) ).toBeGT( 0 );
          expect( trim( toString( activeTrip.ROUTE_CODE ?: "" ) ) ).toBe( asset.routeCode );
          expect( uCase( trim( toString( activeTrip.STATUS ?: "" ) ) ) ).toBe( "ACTIVE" );
        } finally {
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "Active Cruise bootstrap resolves the canonical monitoring row and shows specific canonical monitor labels", function() {
        var prefix = variables.naming.buildPrefix( "active-cruise-ontrack", "page-canonical" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var asset = {};
        var pageHtml = "";
        var monitorCases = [
          { state = "LATE", label = "Late" },
          { state = "MISSED", label = "Missed" },
          { state = "ESCALATED", label = "Escalated" }
        ];
        var monitorCase = {};
        var tripStartCardPos = 0;
        var currentLegCardPos = 0;
        var tripStartCardSegment = "";
        var contactRefs = {};
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern", "08:00:00" );
          markPlanActive( asset.floatPlanId );
          contactRefs = seedActiveCruiseContactReferences( asset.floatPlanId, variables.sessionApiUser.userId, prefix );

          for ( monitorCase in monitorCases ) {
            deleteMonitoringRows( asset.floatPlanId );
            seedMonitoringRow( asset.floatPlanId, variables.sessionApiUser.userId, monitorCase.state );
            pageHtml = sessionApi.getPlain( "/app/active-cruise.cfm?floatPlanId=" & asset.floatPlanId );
            tripStartCardPos = findNoCase( 'data-fpw-field="hero.tripStart"', pageHtml );
            currentLegCardPos = findNoCase( 'data-fpw-field="hero.currentLegSummary"', pageHtml );
            tripStartCardSegment = mid( pageHtml, max( tripStartCardPos, 1 ), 240 );

            expect( findNoCase( "Float Plan " & asset.floatPlanId, pageHtml ) ).toBeGT( 0, pageHtml );
            expect( findNoCase( 'data-fpw-field="monitor.status"', pageHtml ) ).toBeGT( 0, pageHtml );
            expect( findNoCase( ">Scheduled Departure<", pageHtml ) ).toBeGT( 0, pageHtml );
            expect( tripStartCardPos ).toBeGT( 0, pageHtml );
            expect( findNoCase( "2026", tripStartCardSegment ) ).toBeGT( 0, tripStartCardSegment );
            expect( findNoCase( ">--<", tripStartCardSegment ) ).toBe( 0, tripStartCardSegment );
            expect( currentLegCardPos ).toBeGT( tripStartCardPos, pageHtml );
            expect( findNoCase( "Crew &amp; Passengers", pageHtml ) ).toBeGT( 0, pageHtml );
            expect( findNoCase( ">1 listed<", pageHtml ) ).toBeGT( 0, pageHtml );
            expect( findNoCase( contactRefs.crewName, pageHtml ) ).toBeGT( 0, pageHtml );
            expect( findNoCase( 'data-fpw-field="monitor.emergencyContact"', pageHtml ) ).toBeGT( 0, pageHtml );
            expect( findNoCase( contactRefs.monitorName, pageHtml ) ).toBeGT( 0, pageHtml );
            expect( findNoCase( 'data-fpw-field="contacts.monitor.phoneLink"', pageHtml ) ).toBeGT( 0, pageHtml );
            expect( findNoCase( 'data-fpw-field="contacts.monitor.emailLink"', pageHtml ) ).toBeGT( 0, pageHtml );
            expect( findNoCase( 'href="' & encodeForHtmlAttribute( "tel:7275550148" ) & '"', pageHtml ) ).toBeGT( 0, pageHtml );
            expect( findNoCase( 'href="' & encodeForHtmlAttribute( "mailto:" & contactRefs.monitorEmail ) & '"', pageHtml ) ).toBeGT( 0, pageHtml );
            expect( findNoCase( 'id="fpwV2ActionPanel"', pageHtml ) ).toBeGT( 0, pageHtml );
            expect( findNoCase( 'href="/fpw/app/float-plan.cfm', pageHtml ) ).toBe( 0, pageHtml );
            expect( findNoCase( ">" & monitorCase.label & "<", pageHtml ) ).toBeGT( 0, pageHtml );
            expect( findNoCase( ">Overdue<", pageHtml ) ).toBe( 0, pageHtml );
          }
        } finally {
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
          cleanupActiveCruiseContactReferences( contactRefs );
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "Active Cruise direct request without a session renders the unavailable fallback", function() {
        var httpResult = {};
        var pageHtml = "";
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";

        try {
          structDelete( url, "testUserId", false );

          cfhttp( url = variables.api.getBaseUrl() & "/app/active-cruise.cfm", method = "get", result = "httpResult", charset = "utf-8" ) {}
          pageHtml = structKeyExists( httpResult, "fileContent" ) ? trim( toString( httpResult.fileContent ) ) : "";

          expect( find( "200", toString( httpResult.statusCode ?: "" ) ) ).toBeGT( 0, serializeJSON( httpResult ) );
          expect( len( pageHtml ) ).toBeGT( 0, serializeJSON( httpResult ) );
          expect( findNoCase( "Sign in to view Active Cruise V2.", pageHtml ) ).toBeGT( 0, pageHtml );
          expect( findNoCase( "Active Cruise Unavailable", pageHtml ) ).toBeGT( 0, pageHtml );
        } finally {
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
        }
      } );

      it( "Follow bootstrap succeeds when canonical monitoring has exactly one open monitored float plan even if stale ACTIVE lifecycle rows exist", function() {
        var prefix = variables.naming.buildPrefix( "active-cruise-ontrack", "follow-canonical-stale" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var asset = {};
        var streamRow = {};
        var bootstrap = {};
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern", "08:00:00" );
          markPlanActive( asset.floatPlanId );
          seedMonitoringRow( asset.floatPlanId, variables.sessionApiUser.userId, "ACTIVE" );
          streamRow = createVoyageStreamRow( asset.floatPlanId, variables.sessionApiUser.userId, prefix );

          bootstrap = getFollowBootstrapWithApi( sessionApi, streamRow );

          expect( bootstrap.SUCCESS ).toBeTrue( serializeJSON( bootstrap ) );
          expect( val( bootstrap.stream.id ?: 0 ) ).toBe( streamRow.id );
          expect( val( bootstrap.stream.owner_user_id ?: 0 ) ).toBe( variables.sessionApiUser.userId );
        } finally {
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
          if ( structKeyExists( asset, "floatPlanId" ) ) {
            deleteVoyageStreamsForFloatPlan( asset.floatPlanId );
          }
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "Follow bootstrap stays accessible with unavailable monitoring when the active group exists but no monitoring row is open", function() {
        var prefix = variables.naming.buildPrefix( "active-cruise-ontrack", "follow-no-canonical" );
        var sessionApi = buildSessionApiSupport();
        var localCreated = { vesselIds = [], routeCodes = [], floatPlanIds = [] };
        var asset = {};
        var streamRow = {};
        var bootstrap = {};
        var hadOriginalTestUserId = structKeyExists( url, "testUserId" );
        var originalTestUserId = hadOriginalTestUserId ? url.testUserId : "";

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createRouteLinkedDraftForApi( sessionApi, prefix, localCreated );
          setPlanSchedule( asset.floatPlanId, "2026-04-09 09:00:00", "2026-04-10 20:00:00", "US/Eastern", "08:00:00" );
          markPlanActive( asset.floatPlanId );
          seedMonitoringRow( asset.floatPlanId, variables.sessionApiUser.userId, "ACTIVE" );
          streamRow = createVoyageStreamRow( asset.floatPlanId, variables.sessionApiUser.userId, prefix );
          deleteMonitoringRows( asset.floatPlanId );

          bootstrap = getFollowBootstrapWithApi( sessionApi, streamRow );
          expect( bootstrap.SUCCESS ).toBeTrue( serializeJSON( bootstrap ) );
          expect( trim( toString( bootstrap.sidebar.monitor_state_label ?: "" ) ) ).toBe( "Unavailable" );
          expect( trim( toString( bootstrap.sidebar.monitoring_summary ?: "" ) ) ).toBe( "Monitoring unavailable" );
        } finally {
          if ( hadOriginalTestUserId ) {
            url.testUserId = originalTestUserId;
          } else {
            structDelete( url, "testUserId", false );
          }
          if ( structKeyExists( asset, "floatPlanId" ) ) {
            deleteVoyageStreamsForFloatPlan( asset.floatPlanId );
          }
          cleanupRouteLinkedAssetsForApi( sessionApi, localCreated );
        }
      } );

      it( "Dashboard and wizard source no longer rely on legacy overdue-tier float-plan delete assumptions", function() {
        var dashboardSource = fileRead( expandPath( "/fpw/assets/js/app/dashboard/floatplans.js" ) );
        var wizardSource = fileRead( expandPath( "/fpw/assets/js/app/floatplanWizard.js" ) );

        expect( findNoCase( "OVERDUE_1H", dashboardSource ) ).toBe( 0, dashboardSource );
        expect( findNoCase( "OVERDUE_24H", dashboardSource ) ).toBe( 0, dashboardSource );
        expect( findNoCase( "Active or overdue float plans cannot be deleted.", dashboardSource ) ).toBe( 0, dashboardSource );
        expect( findNoCase( 'normalizedStatus === "ACTIVE"', dashboardSource ) ).toBeGT( 0, dashboardSource );
        expect( findNoCase( "Only draft or closed float plans can be deleted.", dashboardSource ) ).toBeGT( 0, dashboardSource );

        expect( findNoCase( 'statusVal === "OVERDUE"', wizardSource ) ).toBe( 0, wizardSource );
        expect( findNoCase( "Active or overdue float plans cannot be deleted.", wizardSource ) ).toBe( 0, wizardSource );
        expect( findNoCase( "Only draft or closed float plans can be deleted.", wizardSource ) ).toBeGT( 0, wizardSource );
      } );
    } );
  }

  private any function buildSessionApiSupport() {
    return new fpw.tests.support.FpwApiSupport().init(
      baseUrl = variables.api.getBaseUrl(),
      authEmail = variables.sessionApiUser.email,
      authPassword = variables.sessionApiUser.password
    );
  }

  private struct function createSessionApiUser() {
    var signupApi = new fpw.tests.support.FpwApiSupport().init(
      baseUrl = variables.api.getBaseUrl()
    );
    var uniqueEmail = "fpw-ontrack-" & replace( createUUID(), "-", "", "all" ) & "@example.com";
    var payload = signupApi.postJson( "/api/v1/join.cfc?method=handle", {
      firstName = "FPW",
      lastName = "OnTrack",
      email = uniqueEmail,
      password = "changeIt",
      confirmPassword = "changeIt",
      termsAccepted = true
    }, false );

    expect( payload.SUCCESS ).toBeTrue( serializeJSON( payload ) );
    expect( val( payload.USERID ?: 0 ) ).toBeGT( 0, serializeJSON( payload ) );
    variables.entitlements.createAdminCompEntitlement( val( payload.USERID ) );

    return {
      userId = val( payload.USERID ),
      email = uniqueEmail,
      password = "changeIt"
    };
  }

  private void function cleanupSessionApiUser() {
    var userId = 0;

    if ( !structKeyExists( variables, "sessionApiUser" ) || !isStruct( variables.sessionApiUser ) ) {
      return;
    }

    userId = val( variables.sessionApiUser.userId ?: 0 );
    if ( userId LTE 0 ) {
      return;
    }

    queryExecute(
      "DELETE FROM member_entitlements WHERE user_id = :userId",
      {
        userId = { value = userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
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

  private struct function createRouteLinkedDraftForApi( required any apiSupport, required string prefix, required struct created ) {
    setActiveCruiseSessionUser( variables.sessionApiUser.userId );
    var vesselPayload = arguments.apiSupport.saveVessel( {
      vesselId = 0,
      vesselName = variables.naming.buildName( arguments.prefix, "On Track Vessel" ),
      type = "Cruiser",
      length = 34,
      color = "White"
    } );
    var vesselId = val( vesselPayload.VESSELID ?: 0 );
    var options = arguments.apiSupport.routeBuilder( "routegen_getoptions", {
      template_code = "GULF-WEST",
      direction = "CCW"
    } );
    ensureSuccess( vesselPayload, "save vessel" );
    ensureSuccess( options, "load route template options" );

    var generate = arguments.apiSupport.routeBuilder( "routegen_generate", {
      route_name = variables.naming.buildName( arguments.prefix, "On Track Route" ),
      template_code = "GULF-WEST",
      direction = "CCW",
      start_segment_id = options.DATA.startOptions[ 1 ].segment_id,
      end_segment_id = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].segment_id,
      start_location_label = options.DATA.startOptions[ 1 ].label,
      end_location_label = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].label,
      start_date = "2026-04-09",
      optional_stop_flags = [ "ship_island_out_and_back" ]
    } );
    ensureSuccess( generate, "generate route" );

    var routeCode = trim( toString( generate.ROUTE_CODE ?: generate.DATA.route_code ?: "" ) );
    var buildPayload = arguments.apiSupport.routeBuilder( "buildFloatPlansFromRoute", {
      routeCode = routeCode,
      mode = "DAILY",
      vesselId = vesselId,
      rebuild = 0
    } );
    ensureSuccess( buildPayload, "build route-linked float plans" );

    var floatPlanId = val( buildPayload.FLOATPLAN_IDS[ 1 ] ?: 0 );
    expect( floatPlanId ).toBeGT( 0, serializeJSON( buildPayload ) );

    arrayAppend( arguments.created.vesselIds, vesselId );
    arrayAppend( arguments.created.routeCodes, routeCode );
    for ( var id in buildPayload.FLOATPLAN_IDS ) {
      arrayAppend( arguments.created.floatPlanIds, val( id ) );
    }

    return {
      vesselId = vesselId,
      routeCode = routeCode,
      floatPlanId = floatPlanId
    };
  }

  private void function setActiveCruiseSessionUser( required numeric userId ) {
    url.testUserId = arguments.userId;
    if ( !structKeyExists( session, "user" ) OR !isStruct( session.user ) ) {
      session.user = {};
    }
    session.user.userId = arguments.userId;
    session.user.id = arguments.userId;
    session.user.USERID = arguments.userId;
  }

  private void function restoreActiveCruiseSessionUser() {
    if ( variables.hadOriginalSessionUser ) {
      session.user = variables.originalSessionUser;
    } else {
      structDelete( session, "user", false );
    }
  }

  private void function cleanupRouteLinkedAssetsForApi( required any apiSupport, required struct created ) {
    var cleanupSupport = new fpw.tests.support.FpwCleanupSupport().init( arguments.apiSupport );
    for ( var i = arrayLen( arguments.created.floatPlanIds ); i GTE 1; i-- ) {
      try {
        cleanupSupport.cleanupFloatPlan( arguments.created.floatPlanIds[ i ] );
      } catch ( any ignoredFloatPlanCleanup ) {}
      forceDeleteFloatPlanRecords( arguments.created.floatPlanIds[ i ] );
    }
    for ( var j = arrayLen( arguments.created.routeCodes ); j GTE 1; j-- ) {
      try {
        cleanupSupport.cleanupRoute( arguments.created.routeCodes[ j ] );
      } catch ( any ignoredRouteCleanup ) {}
    }
    for ( var k = arrayLen( arguments.created.vesselIds ); k GTE 1; k-- ) {
      try {
        cleanupSupport.cleanupVessel( arguments.created.vesselIds[ k ] );
      } catch ( any ignoredVesselCleanup ) {}
    }
  }

  private void function setPlanSchedule(
    required numeric floatPlanId,
    required string departureLocal,
    required string returnLocal,
    required string timeZoneId,
    required string dailyStartLocalTime
  ) {
    queryExecute(
      "UPDATE floatplans
       SET departureTime = CONVERT_TZ(:departureLocal, :timeZoneId, 'UTC'),
           departTimezone = :timeZoneId,
           departureTZ = :timeZoneId,
           returnTime = CONVERT_TZ(:returnLocal, :timeZoneId, 'UTC'),
           returnTimezone = :timeZoneId,
           returnTZ = :timeZoneId,
           dailyStartLocalTime = :dailyStartLocalTime,
           activatedAt = NULL,
           checkedInAt = NULL,
           checkin_context = NULL,
           closedAt = NULL,
           lastUpdateStatus = UTC_TIMESTAMP(),
           `status` = 'DRAFT'
       WHERE floatplanId = :floatPlanId",
      {
        departureLocal = { value = arguments.departureLocal, cfsqltype = "cf_sql_timestamp" },
        returnLocal = { value = arguments.returnLocal, cfsqltype = "cf_sql_timestamp" },
        timeZoneId = { value = arguments.timeZoneId, cfsqltype = "cf_sql_varchar" },
        dailyStartLocalTime = { value = arguments.dailyStartLocalTime, cfsqltype = "cf_sql_varchar" },
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    deleteMonitoringRows( arguments.floatPlanId );
  }

  private void function markPlanActive( required numeric floatPlanId ) {
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
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function seedMonitoringRow( required numeric floatPlanId, required numeric userId, string monitorState = "ACTIVE" ) {
    deleteMonitoringRows( arguments.floatPlanId );
    queryExecute(
      "INSERT INTO floatplan_monitoring (
          float_plan_id,
          user_id,
          monitoring_mode,
          monitor_state,
          is_monitoring_enabled,
          expected_checkin_at,
          grace_expires_at,
          missed_at,
          escalated_at,
          resolved_at,
          closed_at,
          last_checkin_at,
          last_checkin_status,
          secure_for_night,
          secure_for_night_until,
          escalation_delay_minutes,
          grace_window_minutes,
          next_monitor_eval_at,
          last_monitor_eval_at,
          last_captain_alert_at,
          last_contact_alert_at,
          created_at,
          updated_at
       ) VALUES (
          :floatPlanId,
          :userId,
          'active_route',
          :monitorState,
          1,
          DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR),
          DATE_ADD(UTC_TIMESTAMP(), INTERVAL 2 HOUR),
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          0,
          NULL,
          120,
          60,
          DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR),
          NULL,
          NULL,
          NULL,
          UTC_TIMESTAMP(),
          UTC_TIMESTAMP()
       )",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        monitorState = { value = uCase( trim( arguments.monitorState ) ), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
  }

  private struct function loadMonitoringRow( required numeric floatPlanId ) {
    var qRow = queryExecute(
      "SELECT
          monitor_state,
          expected_checkin_at,
          grace_expires_at,
          last_checkin_status
       FROM floatplan_monitoring
       WHERE float_plan_id = :floatPlanId
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    expect( qRow.recordCount ).toBe( 1 );
    return {
      monitor_state = trim( toString( qRow.monitor_state[ 1 ] ) ),
      expected_checkin_at = isNull( qRow.expected_checkin_at[ 1 ] ) ? "" : qRow.expected_checkin_at[ 1 ],
      grace_expires_at = isNull( qRow.grace_expires_at[ 1 ] ) ? "" : qRow.grace_expires_at[ 1 ],
      last_checkin_status = isNull( qRow.last_checkin_status[ 1 ] ) ? "" : trim( toString( qRow.last_checkin_status[ 1 ] ) )
    };
  }

  private void function deleteMonitoringRows( required numeric floatPlanId ) {
    queryExecute(
      "DELETE FROM floatplan_alert_history WHERE floatPlanId = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM floatplan_monitor_events WHERE float_plan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM floatplan_monitoring WHERE float_plan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function forceDeleteFloatPlanRecords( required numeric floatPlanId ) {
    deleteMonitoringRows( arguments.floatPlanId );
    queryExecute(
      "DELETE FROM floatplan_passengers WHERE floatPlanId = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM floatplan_contacts WHERE floatPlanId = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM floatplan_waypoints WHERE floatPlanId = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM floatplans WHERE floatplanId = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private struct function postActiveCruiseCheckinWithApi( required any apiSupport, required numeric floatPlanId, required string statusValue, string note = "", any location = "" ) {
    var payload = {
      floatPlanId = arguments.floatPlanId,
      status = arguments.statusValue,
      note = arguments.note
    };
    if ( isStruct( arguments.location ) ) {
      payload.location = arguments.location;
    }
    return arguments.apiSupport.postJson( "/api/v1/floatplan.cfc?method=handle&action=checkin", payload );
  }

  private struct function loadLatestCanonicalCheckinPayload( required numeric floatPlanId ) {
    var qEvent = queryExecute(
      "SELECT payload_json
       FROM floatplan_events
       WHERE floatplan_id = :floatPlanId
         AND event_type = 'CHECKIN_RECEIVED'
         AND source = 'active_cruise_checkin'
         AND voided_at_utc IS NULL
       ORDER BY occurred_at_utc DESC, id DESC
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );

    expect( qEvent.recordCount ).toBe( 1 );
    expect( len( trim( toString( qEvent.payload_json[ 1 ] ) ) ) ).toBeGT( 0 );
    return deserializeJSON( qEvent.payload_json[ 1 ] );
  }

  private struct function getFollowBootstrapWithApi( required any apiSupport, required struct streamPayload ) {
    var streamIdVal = val( arguments.streamPayload.id ?: 0 );
    var slugVal = trim( toString( arguments.streamPayload.slug ?: "" ) );
    var tokenVal = trim( toString( arguments.streamPayload.share_token ?: "" ) );

    return arguments.apiSupport.getJson(
      "/api/v1/voyage.cfc?method=handle&action=getStreamBootstrap&stream_id=" & streamIdVal & "&slug=" & urlEncodedFormat( slugVal ) & "&t=" & urlEncodedFormat( tokenVal )
    );
  }

  private struct function createVoyageStreamRow( required numeric floatPlanId, required numeric ownerUserId, required string prefix ) {
    var slugVal = lCase( reReplace( arguments.prefix, "[^a-zA-Z0-9]+", "-", "all" ) ) & "-" & lCase( left( replace( createUUID(), "-", "", "all" ), 12 ) );
    var shareTokenVal = createUUID();
    var qRow = queryNew( "" );

    queryExecute(
      "INSERT INTO voyage_streams (
          floatplan_id,
          owner_user_id,
          slug,
          share_token,
          privacy_mode,
          allow_interactions
       ) VALUES (
          :floatPlanId,
          :ownerUserId,
          :slugVal,
          :shareTokenVal,
          'public',
          1
       )",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        ownerUserId = { value = arguments.ownerUserId, cfsqltype = "cf_sql_integer" },
        slugVal = { value = slugVal, cfsqltype = "cf_sql_varchar" },
        shareTokenVal = { value = shareTokenVal, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );

    qRow = queryExecute(
      "SELECT id, slug, share_token
       FROM voyage_streams
       WHERE floatplan_id = :floatPlanId
         AND owner_user_id = :ownerUserId
         AND slug = :slugVal
       ORDER BY id DESC
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        ownerUserId = { value = arguments.ownerUserId, cfsqltype = "cf_sql_integer" },
        slugVal = { value = slugVal, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    expect( qRow.recordCount ).toBe( 1 );

    return {
      id = val( qRow.id[ 1 ] ),
      slug = trim( toString( qRow.slug[ 1 ] ) ),
      share_token = trim( toString( qRow.share_token[ 1 ] ) )
    };
  }

  private void function deleteVoyageStreamsForFloatPlan( required numeric floatPlanId ) {
    queryExecute(
      "DELETE FROM voyage_reactions WHERE post_id IN (
          SELECT id FROM voyage_posts WHERE stream_id IN (
            SELECT id FROM voyage_streams WHERE floatplan_id = :floatPlanId
          )
       )",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM voyage_comments WHERE post_id IN (
          SELECT id FROM voyage_posts WHERE stream_id IN (
            SELECT id FROM voyage_streams WHERE floatplan_id = :floatPlanId
          )
       )",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM voyage_posts WHERE stream_id IN (
          SELECT id FROM voyage_streams WHERE floatplan_id = :floatPlanId
       )",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM voyage_followers WHERE stream_id IN (
          SELECT id FROM voyage_streams WHERE floatplan_id = :floatPlanId
       )",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM voyage_streams WHERE floatplan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private string function toLocalStamp( required any utcDateTime, required string timeZoneId ) {
    if ( !isDate( arguments.utcDateTime ) ) {
      return "";
    }
    var qLocal = queryExecute(
      "SELECT CONVERT_TZ(:utcDateTime, 'UTC', :timeZoneId) AS localDateTime",
      {
        utcDateTime = { value = arguments.utcDateTime, cfsqltype = "cf_sql_timestamp" },
        timeZoneId = { value = arguments.timeZoneId, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    if ( qLocal.recordCount EQ 0 OR isNull( qLocal.localDateTime[ 1 ] ) ) {
      return "";
    }
    return dateTimeFormat( qLocal.localDateTime[ 1 ], "yyyy-mm-dd HH:nn:ss" );
  }

  private string function pickAfterEveningTimeZoneId() {
    var qPick = queryExecute(
      "SELECT tz
       FROM (
         SELECT 'Pacific/Kiritimati' AS tz
         UNION ALL SELECT 'Pacific/Auckland'
         UNION ALL SELECT 'Asia/Tokyo'
         UNION ALL SELECT 'Asia/Kolkata'
         UNION ALL SELECT 'Europe/Berlin'
         UNION ALL SELECT 'UTC'
         UNION ALL SELECT 'America/New_York'
         UNION ALL SELECT 'America/Los_Angeles'
         UNION ALL SELECT 'Pacific/Honolulu'
       ) candidates
       WHERE HOUR(CONVERT_TZ(UTC_TIMESTAMP(), 'UTC', tz)) >= 18
       ORDER BY HOUR(CONVERT_TZ(UTC_TIMESTAMP(), 'UTC', tz)) DESC
       LIMIT 1",
      {},
      { datasource = "fpw" }
    );
    expect( qPick.recordCount ).toBe( 1 );
    return trim( toString( qPick.tz[ 1 ] ) );
  }

  private struct function seedActiveCruiseContactReferences( required numeric floatPlanId, required numeric userId, required string prefix ) {
    var refs = {
      floatPlanId = arguments.floatPlanId,
      passengerId = 0,
      contactId = 0,
      crewName = variables.naming.buildName( arguments.prefix, "Crew Passenger" ),
      monitorName = variables.naming.buildName( arguments.prefix, "Emergency Monitor" ),
      monitorEmail = "fpw-monitor-" & lCase( reReplace( createUUID(), "-", "", "all" ) ) & "@example.com"
    };
    var qPassenger = queryNew( "" );
    var qContact = queryNew( "" );

    queryExecute(
      "INSERT INTO passengers (userId, name, phone)
       VALUES (:userId, :name, :phone)",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        name = { value = refs.crewName, cfsqltype = "cf_sql_varchar" },
        phone = { value = "", cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    qPassenger = queryExecute(
      "SELECT passId
       FROM passengers
       WHERE userId = :userId
         AND name = :name
       ORDER BY passId DESC
       LIMIT 1",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        name = { value = refs.crewName, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    expect( qPassenger.recordCount ).toBe( 1 );
    refs.passengerId = val( qPassenger.passId[ 1 ] );

    queryExecute(
      "INSERT INTO floatplan_passengers (passId, floatPlanId)
       VALUES (:passengerId, :floatPlanId)",
      {
        passengerId = { value = refs.passengerId, cfsqltype = "cf_sql_integer" },
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );

    queryExecute(
      "INSERT INTO contacts (name, phone, userId, email)
       VALUES (:name, :phone, :userId, :email)",
      {
        name = { value = refs.monitorName, cfsqltype = "cf_sql_varchar" },
        phone = { value = "(727) 555-0148", cfsqltype = "cf_sql_varchar" },
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        email = { value = refs.monitorEmail, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    qContact = queryExecute(
      "SELECT contactId
       FROM contacts
       WHERE userId = :userId
         AND email = :email
       ORDER BY contactId DESC
       LIMIT 1",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        email = { value = refs.monitorEmail, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    expect( qContact.recordCount ).toBe( 1 );
    refs.contactId = val( qContact.contactId[ 1 ] );

    queryExecute(
      "INSERT INTO floatplan_contacts (contactId, floatPlanId)
       VALUES (:contactId, :floatPlanId)",
      {
        contactId = { value = refs.contactId, cfsqltype = "cf_sql_integer" },
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );

    return refs;
  }

  private void function cleanupActiveCruiseContactReferences( required struct refs ) {
    var floatPlanId = structKeyExists( arguments.refs, "floatPlanId" ) ? val( arguments.refs.floatPlanId ) : 0;
    var passengerId = structKeyExists( arguments.refs, "passengerId" ) ? val( arguments.refs.passengerId ) : 0;
    var contactId = structKeyExists( arguments.refs, "contactId" ) ? val( arguments.refs.contactId ) : 0;

    if ( passengerId GT 0 ) {
      queryExecute(
        "DELETE FROM floatplan_passengers
         WHERE passId = :passengerId",
        {
          passengerId = { value = passengerId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
      queryExecute(
        "DELETE FROM passengers
         WHERE passId = :passengerId",
        {
          passengerId = { value = passengerId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
    }

    if ( contactId GT 0 ) {
      queryExecute(
        "DELETE FROM floatplan_contacts
         WHERE contactId = :contactId",
        {
          contactId = { value = contactId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
      queryExecute(
        "DELETE FROM contacts
         WHERE contactId = :contactId",
        {
          contactId = { value = contactId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
    }

    if ( floatPlanId GT 0 ) {
      queryExecute(
        "DELETE FROM floatplan_passengers
         WHERE floatPlanId = :floatPlanId
           AND passId = :passengerId",
        {
          floatPlanId = { value = floatPlanId, cfsqltype = "cf_sql_integer" },
          passengerId = { value = passengerId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
      queryExecute(
        "DELETE FROM floatplan_contacts
         WHERE floatPlanId = :floatPlanId
           AND contactId = :contactId",
        {
          floatPlanId = { value = floatPlanId, cfsqltype = "cf_sql_integer" },
          contactId = { value = contactId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
    }
  }

  private void function ensureSuccess( required struct payload, required string label ) {
    if ( !structKeyExists( arguments.payload, "SUCCESS" ) OR arguments.payload.SUCCESS NEQ true ) {
      throw( message = "On Track test setup failed: " & arguments.label, detail = serializeJSON( arguments.payload ) );
    }
  }
}
