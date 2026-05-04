component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.api = new fpw.tests.support.FpwApiSupport().init(
      authEmail = "detroit@email.com",
      authPassword = "changeIt"
    );
    variables.naming = new fpw.tests.support.FpwNamingSupport();
    variables.companionService = new fpw.api.v1.CompanionViewModelService().init("fpw");
    variables.hadOriginalTestUserId = structKeyExists(url, "testUserId");
    variables.originalTestUserId = variables.hadOriginalTestUserId ? url.testUserId : "";
    variables.sessionApiUser = createSessionApiUser();
    url.testUserId = variables.sessionApiUser.userId;
  }

  function afterAll() {
    cleanupSessionApiUser();
    if (variables.hadOriginalTestUserId) {
      url.testUserId = variables.originalTestUserId;
    } else {
      structDelete(url, "testUserId", false);
    }
  }

  function run() {
    describe("FPW companion active trip API", function() {
      it("returns an authenticated no-active-plan response when the user has no active route-backed trip", function() {
        var sessionApi = buildSessionApiSupport();
        var cleanupSupport = new fpw.tests.support.FpwCleanupSupport().init(sessionApi);
        var model = {};

        cleanupSupport.cleanupCurrentRouteFloatPlanGroup(variables.sessionApiUser.userId);
        model = variables.companionService.getCurrentActiveCompanionModel(variables.sessionApiUser.userId);

        expect(model.SUCCESS).toBeFalse(serializeJSON(model));
        expect(model.success).toBeFalse(serializeJSON(model));
        expect(model.AUTH).toBeTrue(serializeJSON(model));
        expect(model.HAS_ACTIVE_PLAN).toBeFalse(serializeJSON(model));
        expect(model.ERROR).toBe("NO_ACTIVE_PLAN", serializeJSON(model));
      });

      it("returns the compact active trip read model and check-in action metadata from existing authorities", function() {
        var prefix = variables.naming.buildPrefix("companion", "active-model");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var model = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
          model = variables.companionService.getCurrentActiveCompanionModel(variables.sessionApiUser.userId);

          expect(model.SUCCESS).toBeTrue(serializeJSON(model));
          expect(model.success).toBeTrue(serializeJSON(model));
          expect(model.AUTH).toBeTrue(serializeJSON(model));
          expect(model.HAS_ACTIVE_PLAN).toBeTrue(serializeJSON(model));
          expect(model.activeFloatPlan.floatPlanId).toBe(asset.floatPlanId, serializeJSON(model.activeFloatPlan));
          expect(model.activeFloatPlan.routeInstanceId).toBeGT(0, serializeJSON(model.activeFloatPlan));
          expect(model.route.routeInstanceId).toBe(model.activeFloatPlan.routeInstanceId, serializeJSON(model.route));
          expect(structKeyExists(model.monitoring, "expectedCheckinAtUtc")).toBeTrue(serializeJSON(model.monitoring));
          expect(structKeyExists(model.monitoring, "lastCheckinStatus")).toBeTrue(serializeJSON(model.monitoring));
          expect(arrayLen(model.checkIn.allowedStatusOptions)).toBe(5, serializeJSON(model.checkIn));
          expect(structKeyExists(model.actions, "checkIn")).toBeTrue(serializeJSON(model.actions));
          expect(model.actions.checkIn.endpoint).toBe("/api/v1/floatplan.cfc?method=handle&action=checkin&returnFormat=json");
          expect(model.actions.checkIn.payload.floatPlanId).toBe(asset.floatPlanId, serializeJSON(model.actions.checkIn));
          expect(model.storageAuthority.activePlanGuard).toBe("floatplan.resolveCurrentRouteFloatPlanGroup", serializeJSON(model.storageAuthority));
          expect(model.storageAuthority.readModel).toBe("ActiveCruiseViewModelService", serializeJSON(model.storageAuthority));
          expect(model.storageAuthority.checkInWrite).toBe("floatplan.cfc?action=checkin", serializeJSON(model.storageAuthority));
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("serves the same compact current active trip model through the companion endpoint", function() {
        var prefix = variables.naming.buildPrefix("companion", "endpoint");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var response = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
          response = sessionApi.getJson("/api/v1/companion.cfc?method=handle&action=current&returnFormat=json");

          expect(response.SUCCESS).toBeTrue(serializeJSON(response));
          expect(response.success).toBeTrue(serializeJSON(response));
          expect(response.AUTH).toBeTrue(serializeJSON(response));
          expect(response.HAS_ACTIVE_PLAN).toBeTrue(serializeJSON(response));
          expect(response.activeFloatPlan.floatPlanId).toBe(asset.floatPlanId, serializeJSON(response.activeFloatPlan));
          expect(structKeyExists(response.actions, "checkIn")).toBeTrue(serializeJSON(response.actions));
          expect(response.actions.checkIn.payload.floatPlanId).toBe(asset.floatPlanId, serializeJSON(response.actions.checkIn));
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });
    });
  }

  private any function buildSessionApiSupport() {
    return new fpw.tests.support.FpwApiSupport().init(
      baseUrl = variables.api.getBaseUrl(),
      authEmail = variables.sessionApiUser.email,
      authPassword = variables.sessionApiUser.password
    );
  }

  private struct function newCreatedTracker() {
    return { vesselIds = [], routeCodes = [], floatPlanIds = [], contactIds = [] };
  }

  private struct function createSessionApiUser() {
    var signupApi = new fpw.tests.support.FpwApiSupport().init(
      baseUrl = variables.api.getBaseUrl()
    );
    var uniqueEmail = "fpw-companion-" & replace(createUUID(), "-", "", "all") & "@example.com";
    var payload = signupApi.postJson("/api/v1/join.cfc?method=handle", {
      firstName = "FPW",
      lastName = "Companion",
      email = uniqueEmail,
      password = "changeIt"
    }, false);

    expect(payload.SUCCESS).toBeTrue(serializeJSON(payload));
    expect(val(payload.USERID ?: 0)).toBeGT(0, serializeJSON(payload));

    return {
      userId = val(payload.USERID),
      email = uniqueEmail,
      password = "changeIt"
    };
  }

  private void function cleanupSessionApiUser() {
    var userId = 0;

    if (!structKeyExists(variables, "sessionApiUser") || !isStruct(variables.sessionApiUser)) {
      return;
    }

    userId = val(variables.sessionApiUser.userId ?: 0);
    if (userId LTE 0) {
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

  private struct function createActivatedScheduledTrip(required any apiSupport, required string prefix, required struct created) {
    var asset = createRouteLinkedDraftForApi(arguments.apiSupport, arguments.prefix, arguments.created);
    var futureDeparture = dateTimeFormat(dateAdd("h", 3, now()), "yyyy-mm-dd HH:nn:ss");
    var futureReturn = dateTimeFormat(dateAdd("h", 9, now()), "yyyy-mm-dd HH:nn:ss");
    var sendResult = {};

    attachContactToPlan(arguments.apiSupport, asset.floatPlanId, arguments.prefix, arguments.created);
    setPlanSchedule(asset.floatPlanId, futureDeparture, futureReturn, "UTC");
    sendResult = sendFloatPlanWithApi(arguments.apiSupport, asset.floatPlanId);
    expect(isSuccessPayload(sendResult)).toBeTrue(serializeJSON(sendResult));
    expect(countMonitoringRows(asset.floatPlanId)).toBe(1);
    return asset;
  }

  private struct function createRouteLinkedDraftForApi(required any apiSupport, required string prefix, required struct created) {
    var cleanupSupport = new fpw.tests.support.FpwCleanupSupport().init(arguments.apiSupport);
    cleanupSupport.cleanupCurrentRouteFloatPlanGroup();

    var vesselPayload = arguments.apiSupport.saveVessel({
      vesselId = 0,
      vesselName = variables.naming.buildName(arguments.prefix, "Companion Vessel"),
      type = "Cruiser",
      length = 34,
      color = "White"
    });
    var vesselId = val(vesselPayload.VESSELID ?: 0);
    var options = arguments.apiSupport.routeBuilder("routegen_getoptions", {
      template_code = "GULF-WEST",
      direction = "CCW"
    });
    ensureSuccess(vesselPayload, "save vessel");
    ensureSuccess(options, "load route template options");

    var generate = arguments.apiSupport.routeBuilder("routegen_generate", {
      route_name = variables.naming.buildName(arguments.prefix, "Companion Route"),
      template_code = "GULF-WEST",
      direction = "CCW",
      start_segment_id = options.DATA.startOptions[1].segment_id,
      end_segment_id = options.DATA.endOptions[arrayLen(options.DATA.endOptions)].segment_id,
      start_location_label = options.DATA.startOptions[1].label,
      end_location_label = options.DATA.endOptions[arrayLen(options.DATA.endOptions)].label,
      start_date = "2026-04-09",
      optional_stop_flags = [ "ship_island_out_and_back" ]
    });
    ensureSuccess(generate, "generate route");

    var routeCode = trim(toString(generate.ROUTE_CODE ?: generate.DATA.route_code ?: ""));
    var buildPayload = arguments.apiSupport.routeBuilder("buildFloatPlansFromRoute", {
      routeCode = routeCode,
      mode = "DAILY",
      vesselId = vesselId,
      rebuild = 0
    });
    ensureSuccess(buildPayload, "build route-linked float plans");

    var floatPlanId = val(buildPayload.FLOATPLAN_IDS[1] ?: 0);
    expect(floatPlanId).toBeGT(0, serializeJSON(buildPayload));

    arrayAppend(arguments.created.vesselIds, vesselId);
    arrayAppend(arguments.created.routeCodes, routeCode);
    for (var id in buildPayload.FLOATPLAN_IDS) {
      arrayAppend(arguments.created.floatPlanIds, val(id));
    }

    return {
      vesselId = vesselId,
      routeCode = routeCode,
      floatPlanId = floatPlanId
    };
  }

  private void function attachContactToPlan(required any apiSupport, required numeric floatPlanId, required string prefix, required struct created) {
    var contactPayload = arguments.apiSupport.saveContact({
      contactId = 0,
      name = variables.naming.buildName(arguments.prefix, "Companion Contact"),
      phone = "5555551212",
      email = "fpw-companion-contact-" & lCase(replace(createUUID(), "-", "", "all")) & "@example.com"
    });
    var contactId = val(contactPayload.CONTACTID ?: 0);

    ensureSuccess(contactPayload, "save contact");
    expect(contactId).toBeGT(0, serializeJSON(contactPayload));
    arrayAppend(arguments.created.contactIds, contactId);

    queryExecute(
      "INSERT INTO floatplan_contacts (floatPlanId, contactId)
       VALUES (:floatPlanId, :contactId)",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        contactId = { value = contactId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function setPlanSchedule(
    required numeric floatPlanId,
    required string departureUtc,
    required string returnUtc,
    required string timeZoneId
  ) {
    queryExecute(
      "UPDATE floatplans
       SET departureTime = CONVERT_TZ(:departureUtc, :timeZoneId, 'UTC'),
           departTimezone = :timeZoneId,
           departureTZ = :timeZoneId,
           returnTime = CONVERT_TZ(:returnUtc, :timeZoneId, 'UTC'),
           returnTimezone = :timeZoneId,
           returnTZ = :timeZoneId,
           dailyStartLocalTime = '08:00:00',
           activatedAt = NULL,
           checkedInAt = NULL,
           checkin_context = NULL,
           closedAt = NULL,
           lastUpdateStatus = UTC_TIMESTAMP(),
           `status` = 'DRAFT'
       WHERE floatplanId = :floatPlanId",
      {
        departureUtc = { value = arguments.departureUtc, cfsqltype = "cf_sql_timestamp" },
        returnUtc = { value = arguments.returnUtc, cfsqltype = "cf_sql_timestamp" },
        timeZoneId = { value = arguments.timeZoneId, cfsqltype = "cf_sql_varchar" },
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    deleteMonitoringRows(arguments.floatPlanId);
  }

  private struct function sendFloatPlanWithApi(required any apiSupport, required numeric floatPlanId) {
    return arguments.apiSupport.postJson("/api/v1/floatplan.cfc?method=handle&action=send", {
      floatPlanId = arguments.floatPlanId
    });
  }

  private void function cleanupRouteLinkedAssetsForApi(required any apiSupport, required struct created) {
    var cleanupSupport = new fpw.tests.support.FpwCleanupSupport().init(arguments.apiSupport);
    for (var i = arrayLen(arguments.created.floatPlanIds); i GTE 1; i--) {
      try {
        deleteVoyageStreamsForFloatPlan(arguments.created.floatPlanIds[i]);
      } catch (any ignoredStreamCleanup) {}
      try {
        cleanupSupport.cleanupFloatPlan(arguments.created.floatPlanIds[i]);
      } catch (any ignoredFloatPlanCleanup) {}
      forceDeleteFloatPlanRecords(arguments.created.floatPlanIds[i]);
    }
    for (var j = arrayLen(arguments.created.routeCodes); j GTE 1; j--) {
      try {
        cleanupSupport.cleanupRoute(arguments.created.routeCodes[j]);
      } catch (any ignoredRouteCleanup) {}
      forceDeleteRouteInstanceRecords(arguments.created.routeCodes[j]);
    }
    for (var c = arrayLen(arguments.created.contactIds); c GTE 1; c--) {
      try {
        cleanupSupport.cleanupContact(arguments.created.contactIds[c]);
      } catch (any ignoredContactCleanup) {
        queryExecute(
          "DELETE FROM contacts WHERE contactId = :contactId",
          {
            contactId = { value = arguments.created.contactIds[c], cfsqltype = "cf_sql_integer" }
          },
          { datasource = "fpw" }
        );
      }
    }
    for (var k = arrayLen(arguments.created.vesselIds); k GTE 1; k--) {
      try {
        cleanupSupport.cleanupVessel(arguments.created.vesselIds[k]);
      } catch (any ignoredVesselCleanup) {}
    }
  }

  private void function forceDeleteFloatPlanRecords(required numeric floatPlanId) {
    deleteMonitoringRows(arguments.floatPlanId);
    queryExecute(
      "DELETE FROM floatplan_activity_segments WHERE floatplan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM floatplan_events WHERE floatplan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
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
      "DELETE FROM floatplans WHERE floatPlanId = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function forceDeleteRouteInstanceRecords(required string routeCode) {
    queryExecute(
      "DELETE rilp
       FROM route_instance_leg_progress rilp
       INNER JOIN route_instances ri
          ON ri.id = rilp.route_instance_id
       WHERE ri.generated_route_code = :routeCode",
      {
        routeCode = { value = arguments.routeCode, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE ril
       FROM route_instance_legs ril
       INNER JOIN route_instances ri
          ON ri.id = ril.route_instance_id
       WHERE ri.generated_route_code = :routeCode",
      {
        routeCode = { value = arguments.routeCode, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM route_instances
       WHERE generated_route_code = :routeCode",
      {
        routeCode = { value = arguments.routeCode, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
  }

  private void function deleteVoyageStreamsForFloatPlan(required numeric floatPlanId) {
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

  private numeric function countMonitoringRows(required numeric floatPlanId) {
    var qRows = queryExecute(
      "SELECT COUNT(*) AS row_count
       FROM floatplan_monitoring
       WHERE float_plan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    return val(qRows.row_count[1]);
  }

  private void function deleteMonitoringRows(required numeric floatPlanId) {
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

  private boolean function isSuccessPayload(required struct payload) {
    if (structKeyExists(arguments.payload, "SUCCESS") AND arguments.payload.SUCCESS EQ true) {
      return true;
    }
    if (structKeyExists(arguments.payload, "success") AND arguments.payload.success EQ true) {
      return true;
    }
    return false;
  }

  private void function ensureSuccess(required struct payload, required string label) {
    if (!isSuccessPayload(arguments.payload)) {
      throw(message = "Companion API setup failed: " & arguments.label, detail = serializeJSON(arguments.payload));
    }
  }
}
