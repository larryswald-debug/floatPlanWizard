component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.api = new fpw.tests.support.FpwApiSupport().init();
    variables.gate = new fpw.api.v1.MemberAccessGateService().init("fpw");
    variables.entitlements = new fpw.api.v1.MemberEntitlementService().init("fpw");
    variables.activeCruiseViewModel = new fpw.api.v1.ActiveCruiseViewModelService().init("fpw");
    variables.userSeed = 902000000 + randRange(1000, 99999);
    variables.createdUserIds = [];
    variables.createdVesselIds = [];
    variables.createdContactIds = [];
    variables.createdWaypointIds = [];
	    ensureMemberEntitlementsTable();
	    ensureBasicOperationalColumns();
	    ensureBasicDetailsTable();
  }

  function afterEach() {
    cleanupCreatedData();
  }

  function run() {
    describe("Basic operational-only float plans", function() {
      it("saves route-less Basic operational float plans with stored waypoints and no route records", function() {
        var userId = nextTestUserId();
	        var fixtures = createFixtures(userId, 2);
        var payload = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = fixtures.waypointIds,
          departureAt = dateAdd("h", 8, now()),
          returnAt = dateAdd("h", 10, now())
        );

        var saveRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", payload);
        expect(saveRes.SUCCESS).toBeTrue("savebasic failed: " & serializeJSON(saveRes));

        var planId = val(saveRes.FLOATPLANID);
        expect(planId).toBeGT(0);

        var qPlan = queryExecute(
          "SELECT route_instance_id, route_origin, is_reusable, is_visible_in_route_library
             FROM floatplans
            WHERE floatplanId = :planId
              AND userId = :userId",
          {
            planId = { value = planId, cfsqltype = "cf_sql_integer" },
            userId = { value = userId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = "fpw" }
        );
        var qWaypoints = queryExecute(
          "SELECT COUNT(*) AS waypoint_count
             FROM floatplan_waypoints
            WHERE floatPlanId = :planId",
          { planId = { value = planId, cfsqltype = "cf_sql_integer" } },
          { datasource = "fpw" }
        );
        var qRouteInstances = queryExecute(
          "SELECT COUNT(*) AS route_count
             FROM route_instances
            WHERE user_id = :userId",
          { userId = { value = toString(userId), cfsqltype = "cf_sql_varchar" } },
          { datasource = "fpw" }
        );

        expect(qPlan.recordCount).toBe(1);
        expect(isNull(qPlan.route_instance_id[1]) OR val(qPlan.route_instance_id[1]) LTE 0).toBeTrue("Basic route-less plans must not link a route instance.");
        expect(qPlan.route_origin[1]).toBe("basic_float_plan");
        expect(val(qPlan.is_reusable[1])).toBe(0);
        expect(val(qPlan.is_visible_in_route_library[1])).toBe(0);
	        expect(val(qWaypoints.waypoint_count[1])).toBe(2);
	        expect(val(qRouteInstances.route_count[1])).toBe(0);
	        var qDetails = queryExecute(
	          "SELECT vessel_name, operator_name, captain_name, captain_email, notification_contact_email, authority_id, authority_phone_snapshot
	             FROM floatplan_basic_details
	            WHERE floatplan_id = :planId",
	          { planId = { value = planId, cfsqltype = "cf_sql_integer" } },
	          { datasource = "fpw" }
	        );
	        var qContacts = queryExecute(
	          "SELECT COUNT(*) AS contact_count
	             FROM floatplan_contacts
	            WHERE floatPlanId = :planId",
	          { planId = { value = planId, cfsqltype = "cf_sql_integer" } },
	          { datasource = "fpw" }
	        );
		        expect(qDetails.recordCount).toBe(1);
		        var qAuthority = queryExecute(
		          "SELECT rcPhone
		             FROM rescuecenters
		            WHERE recId = :authorityId
	            LIMIT 1",
		          { authorityId = { value = val(qDetails.authority_id[1]), cfsqltype = "cf_sql_integer" } },
		          { datasource = "fpw" }
		        );
		        expect(trim(qDetails.vessel_name[1])).toBe("Basic Test Vessel " & fixtures.suffix);
	        expect(trim(qDetails.notification_contact_email[1])).toBe("basic-operational-" & fixtures.suffix & "@example.com");
	        expect(qAuthority.recordCount).toBe(1);
	        expect(trim(qDetails.authority_phone_snapshot[1])).toBe(trim(qAuthority.rcPhone[1]));
        expect(val(qContacts.contact_count[1])).toBe(0);
      });

      it("saves and sends Basic operational float plans with an IANA timezone", function() {
        var userId = nextTestUserId();
        var fixtures = createFixtures(userId, 1);
        var payload = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = fixtures.waypointIds,
          departureAt = dateAdd("h", 8, now()),
          returnAt = dateAdd("h", 10, now()),
          timeZone = "America/New_York"
        );

        var saveRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", payload);
        expect(saveRes.SUCCESS).toBeTrue("savebasic with America/New_York failed: " & serializeJSON(saveRes));

        var planId = val(saveRes.FLOATPLANID);
        var qPlan = queryExecute(
          "SELECT
              DATE_FORMAT(departureTime, '%Y-%m-%d %H:%i:%s') AS departure_time_local,
              DATE_FORMAT(departureTimeUTC, '%Y-%m-%d %H:%i:%s') AS departure_time_utc,
              departTimezone,
              departureTZ,
              DATE_FORMAT(returnTime, '%Y-%m-%d %H:%i:%s') AS return_time_local,
              DATE_FORMAT(returnTimeUTC, '%Y-%m-%d %H:%i:%s') AS return_time_utc,
              returnTimezone,
              returnTZ
             FROM floatplans
            WHERE floatplanId = :planId
              AND userId = :userId",
          {
            planId = { value = planId, cfsqltype = "cf_sql_integer" },
            userId = { value = userId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = "fpw" }
        );
        expect(qPlan.recordCount).toBe(1);
        expect(trim(qPlan.departure_time_local[1])).toBe(payload.FLOATPLAN.departureTime);
        expect(trim(qPlan.departure_time_utc[1])).toBe(utcIsoToSql(payload.FLOATPLAN.departureTimeUtc));
        expect(trim(qPlan.departTimezone[1])).toBe("America/New_York");
        expect(trim(qPlan.departureTZ[1])).toBe("America/New_York");
        expect(trim(qPlan.return_time_local[1])).toBe(payload.FLOATPLAN.returnTime);
        expect(trim(qPlan.return_time_utc[1])).toBe(utcIsoToSql(payload.FLOATPLAN.returnTimeUtc));
        expect(trim(qPlan.returnTimezone[1])).toBe("America/New_York");
        expect(trim(qPlan.returnTZ[1])).toBe("America/New_York");

        var sendRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=sendbasic", {
          action = "sendbasic",
          floatPlanId = planId
        });
        expect(sendRes.SUCCESS).toBeTrue("sendbasic with America/New_York failed: " & serializeJSON(sendRes));
      });

      it("rejects sending a Basic operational float plan with an IANA timezone return time in the past", function() {
        var userId = nextTestUserId();
        var fixtures = createFixtures(userId, 1);
        var payload = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = fixtures.waypointIds,
          departureAt = dateAdd("h", -26, now()),
          returnAt = dateAdd("h", -24, now()),
          timeZone = "America/New_York"
        );

        var saveRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", payload);
        expect(saveRes.SUCCESS).toBeTrue("past savebasic with America/New_York failed: " & serializeJSON(saveRes));

        var sendRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=sendbasic", {
          action = "sendbasic",
          floatPlanId = val(saveRes.FLOATPLANID)
        });
        expect(sendRes.SUCCESS).toBeFalse(serializeJSON(sendRes));
        expect(sendRes.ERROR).toBe("RETURN_TIME_PAST");
      });

      it("returns empty Basic current state when no Basic operational plan exists", function() {
        var userId = nextTestUserId();
        var currentRes = getBasicCurrentAsUser(userId);

        expect(currentRes.SUCCESS).toBeTrue(serializeJSON(currentRes));
        expect(currentRes.HAS_BASIC_PLAN).toBeFalse(serializeJSON(currentRes));
        expect(currentRes.STATE).toBe("empty");
      });

      it("returns the latest Basic draft with resume selections", function() {
        var userId = nextTestUserId();
	        var fixtures = createFixtures(userId, 2);
        var payload = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = fixtures.waypointIds,
          departureAt = dateAdd("h", 8, now()),
          returnAt = dateAdd("h", 10, now())
        );
        var saveRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", payload);
        expect(saveRes.SUCCESS).toBeTrue("savebasic failed: " & serializeJSON(saveRes));

        var currentRes = getBasicCurrentAsUser(userId);

        expect(currentRes.SUCCESS).toBeTrue(serializeJSON(currentRes));
        expect(currentRes.HAS_DRAFT).toBeTrue(serializeJSON(currentRes));
        expect(currentRes.STATE).toBe("draft");
        expect(val(currentRes.FLOATPLANID)).toBe(val(saveRes.FLOATPLANID));
	        expect(arrayLen(currentRes.PLAN_WAYPOINTS)).toBe(2);
	        expect(arrayLen(currentRes.PLAN_CONTACTS)).toBe(1);
	        expect(currentRes.BASIC_PLAN.WAYPOINT_COUNT).toBe(2);
        expect(currentRes.BASIC_PLAN.CONTACT_COUNT).toBe(1);
        expect(len(trim(currentRes.BASIC_PLAN.WAYPOINT_SUMMARY))).toBeGT(0);
      });

      it("updates the existing Basic draft and rejects duplicate draft creation", function() {
        var userId = nextTestUserId();
	        var fixtures = createFixtures(userId, 2);
        var payload = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = fixtures.waypointIds,
          departureAt = dateAdd("h", 8, now()),
          returnAt = dateAdd("h", 10, now())
        );
        var saveRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", payload);
        expect(saveRes.SUCCESS).toBeTrue("savebasic failed: " & serializeJSON(saveRes));

        payload.FLOATPLAN.floatPlanId = val(saveRes.FLOATPLANID);
        payload.FLOATPLAN.floatPlanName = "Updated Basic Operational " & fixtures.suffix;
        payload.WAYPOINTS = [ payload.WAYPOINTS[1], payload.WAYPOINTS[2] ];
        var updateRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", payload);
        expect(updateRes.SUCCESS).toBeTrue("same draft update failed: " & serializeJSON(updateRes));
        expect(val(updateRes.FLOATPLANID)).toBe(val(saveRes.FLOATPLANID));

        var duplicatePayload = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = [ fixtures.waypointIds[1] ],
          departureAt = dateAdd("h", 11, now()),
          returnAt = dateAdd("h", 12, now())
        );
        var duplicateRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", duplicatePayload);
        expect(duplicateRes.SUCCESS).toBeFalse(serializeJSON(duplicateRes));
        expect(duplicateRes.ERROR).toBe("BASIC_DRAFT_EXISTS");
        expect(val(duplicateRes.EXISTING_FLOATPLANID)).toBe(val(saveRes.FLOATPLANID));
      });

      it("rejects new Basic draft creation when an Active Basic plan exists", function() {
        var userId = nextTestUserId();
        var fixtures = createFixtures(userId, 2);
        var activePayload = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = fixtures.waypointIds,
          departureAt = dateAdd("h", 8, now()),
          returnAt = dateAdd("h", 10, now())
        );
        var activeSave = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", activePayload);
        expect(activeSave.SUCCESS).toBeTrue("active savebasic failed: " & serializeJSON(activeSave));

        var sendRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=sendbasic", {
          action = "sendbasic",
          floatPlanId = val(activeSave.FLOATPLANID)
        });
        expect(sendRes.SUCCESS).toBeTrue("sendbasic failed: " & serializeJSON(sendRes));

        var draftPayload = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = [ fixtures.waypointIds[1] ],
          departureAt = dateAdd("h", 11, now()),
          returnAt = dateAdd("h", 12, now())
        );
        var draftSave = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", draftPayload);
        expect(draftSave.SUCCESS).toBeFalse(serializeJSON(draftSave));
        expect(draftSave.ERROR).toBe("BASIC_ACTIVE_PLAN_EXISTS");
        expect(val(draftSave.EXISTING_FLOATPLANID)).toBe(val(activeSave.FLOATPLANID));

        var currentRes = getBasicCurrentAsUser(userId);

        expect(currentRes.SUCCESS).toBeTrue(serializeJSON(currentRes));
        expect(currentRes.HAS_ACTIVE_PLAN).toBeTrue(serializeJSON(currentRes));
        expect(currentRes.STATE).toBe("active");
        expect(val(currentRes.FLOATPLANID)).toBe(val(activeSave.FLOATPLANID));
        expect(currentRes.BASIC_PLAN.MONITORING_MODE).toBe("basic");
      });

      it("does not return Premium route-backed or another user's Basic plan as Basic current state", function() {
        var userId = nextTestUserId();
        var otherUserId = nextTestUserId();
        var otherFixtures = createFixtures(otherUserId, 1);
        var otherPayload = buildBasicPayload(
          fixtures = otherFixtures,
          waypointIds = otherFixtures.waypointIds,
          departureAt = dateAdd("h", 8, now()),
          returnAt = dateAdd("h", 9, now())
        );
        var otherSave = postAsUser(otherUserId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", otherPayload);
        expect(otherSave.SUCCESS).toBeTrue("other savebasic failed: " & serializeJSON(otherSave));

        insertPremiumScopedFloatPlan(userId);

        var currentRes = getBasicCurrentAsUser(userId);

        expect(currentRes.SUCCESS).toBeTrue(serializeJSON(currentRes));
        expect(currentRes.HAS_BASIC_PLAN).toBeFalse(serializeJSON(currentRes));
        expect(currentRes.STATE).toBe("empty");
      });

      it("sends a resumed Basic draft and returns Active basic monitoring as current state", function() {
        var userId = nextTestUserId();
        var fixtures = createFixtures(userId, 2);
        var payload = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = fixtures.waypointIds,
          departureAt = dateAdd("h", 8, now()),
          returnAt = dateAdd("h", 10, now())
        );
        var saveRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", payload);
        expect(saveRes.SUCCESS).toBeTrue("savebasic failed: " & serializeJSON(saveRes));

        var draftRes = getBasicCurrentAsUser(userId);
        expect(draftRes.STATE).toBe("draft");
        expect(arrayLen(draftRes.PLAN_WAYPOINTS)).toBe(2);

        var sendRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=sendbasic", {
          action = "sendbasic",
          floatPlanId = val(draftRes.FLOATPLANID)
        });
        expect(sendRes.SUCCESS).toBeTrue("sendbasic failed: " & serializeJSON(sendRes));

        var activeRes = getBasicCurrentAsUser(userId);

        expect(activeRes.SUCCESS).toBeTrue(serializeJSON(activeRes));
        expect(activeRes.STATE).toBe("active");
        expect(val(activeRes.FLOATPLANID)).toBe(val(saveRes.FLOATPLANID));
        expect(activeRes.MONITORING.MONITORING_MODE).toBe("basic");
        expect(activeRes.MONITORING.MONITOR_STATE).toBe("ACTIVE");
      });

      it("rejects sending a different Basic draft when another Basic plan is active", function() {
        var userId = nextTestUserId();
        var fixtures = createFixtures(userId, 2);
        var payload = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = fixtures.waypointIds,
          departureAt = dateAdd("h", 8, now()),
          returnAt = dateAdd("h", 10, now())
        );
        var saveRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", payload);
        expect(saveRes.SUCCESS).toBeTrue("savebasic failed: " & serializeJSON(saveRes));

        var sendRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=sendbasic", {
          action = "sendbasic",
          floatPlanId = val(saveRes.FLOATPLANID)
        });
        expect(sendRes.SUCCESS).toBeTrue("sendbasic failed: " & serializeJSON(sendRes));

        var secondDraftId = insertBasicScopedDraft(userId);
        var secondSend = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=sendbasic", {
          action = "sendbasic",
          floatPlanId = secondDraftId
        });

        expect(secondSend.SUCCESS).toBeFalse(serializeJSON(secondSend));
        expect(secondSend.ERROR).toBe("BASIC_ACTIVE_PLAN_EXISTS");
        expect(val(secondSend.EXISTING_FLOATPLANID)).toBe(val(saveRes.FLOATPLANID));
      });

      it("closes an active Basic operational plan, ends monitoring, and allows a new Basic draft", function() {
        var userId = nextTestUserId();
        var fixtures = createFixtures(userId, 2);
        var payload = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = fixtures.waypointIds,
          departureAt = dateAdd("h", 8, now()),
          returnAt = dateAdd("h", 10, now())
        );
        var saveRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", payload);
        expect(saveRes.SUCCESS).toBeTrue("savebasic failed: " & serializeJSON(saveRes));

        var sendRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=sendbasic", {
          action = "sendbasic",
          floatPlanId = val(saveRes.FLOATPLANID)
        });
        expect(sendRes.SUCCESS).toBeTrue("sendbasic failed: " & serializeJSON(sendRes));

        var closeRes = closeBasicAsUser(userId, val(saveRes.FLOATPLANID));
        expect(closeRes.SUCCESS).toBeTrue("closebasic failed: " & serializeJSON(closeRes));
        expect(closeRes.STATUS).toBe("CLOSED");

        var qClosed = queryExecute(
          "SELECT fp.status, fp.closedAt, fm.monitor_state, fm.is_monitoring_enabled, fm.closed_at
             FROM floatplans fp
             LEFT JOIN floatplan_monitoring fm ON fm.float_plan_id = fp.floatplanId
            WHERE fp.floatplanId = :planId
              AND fp.userId = :userId",
          {
            planId = { value = val(saveRes.FLOATPLANID), cfsqltype = "cf_sql_integer" },
            userId = { value = userId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = "fpw" }
        );
        expect(qClosed.recordCount).toBe(1);
        expect(ucase(trim(qClosed.status[1]))).toBe("CLOSED");
        expect(isNull(qClosed.closedAt[1])).toBeFalse("closedAt should be set.");
        expect(ucase(trim(qClosed.monitor_state[1]))).toBe("CLOSED");
        expect(val(qClosed.is_monitoring_enabled[1])).toBe(0);
        expect(isNull(qClosed.closed_at[1])).toBeFalse("monitoring closed_at should be set.");

        var currentRes = getBasicCurrentAsUser(userId);
        expect(currentRes.SUCCESS).toBeTrue(serializeJSON(currentRes));
        expect(currentRes.STATE).toBe("empty");

        var newPayload = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = [ fixtures.waypointIds[1] ],
          departureAt = dateAdd("h", 12, now()),
          returnAt = dateAdd("h", 13, now())
        );
        var newSave = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", newPayload);
        expect(newSave.SUCCESS).toBeTrue("new savebasic after close failed: " & serializeJSON(newSave));
      });

      it("rejects unauthorized, other-user, and Premium route-backed Basic close requests", function() {
        var userId = nextTestUserId();
        var otherUserId = nextTestUserId();
        var fixtures = createFixtures(userId, 1);
        var payload = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = fixtures.waypointIds,
          departureAt = dateAdd("h", 8, now()),
          returnAt = dateAdd("h", 9, now())
        );
        var saveRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", payload);
        expect(saveRes.SUCCESS).toBeTrue("savebasic failed: " & serializeJSON(saveRes));
        var sendRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=sendbasic", {
          action = "sendbasic",
          floatPlanId = val(saveRes.FLOATPLANID)
        });
        expect(sendRes.SUCCESS).toBeTrue("sendbasic failed: " & serializeJSON(sendRes));

        var anonRes = postAnonymous("/api/v1/floatplan.cfc?method=handle&action=closebasic", {
          action = "closebasic",
          floatPlanId = val(saveRes.FLOATPLANID)
        });
        expect(anonRes.AUTH).toBeFalse(serializeJSON(anonRes));
        expect(anonRes.ERROR).toBe("NOT_LOGGED_IN");

        var otherRes = closeBasicAsUser(otherUserId, val(saveRes.FLOATPLANID));
        expect(otherRes.SUCCESS).toBeFalse(serializeJSON(otherRes));
        expect(otherRes.ERROR).toBe("PLAN_NOT_FOUND");

        var premiumPlanId = insertPremiumScopedFloatPlan(userId);
        var premiumRes = closeBasicAsUser(userId, premiumPlanId);
        expect(premiumRes.SUCCESS).toBeFalse(serializeJSON(premiumRes));
        expect(premiumRes.ERROR.CODE).toBe("BASIC_SAVED_ROUTE_RESTRICTED");
      });

      it("downloads the active Basic operational PDF for the owner only", function() {
        var userId = nextTestUserId();
        var otherUserId = nextTestUserId();
        var fixtures = createFixtures(userId, 2);
        var payload = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = fixtures.waypointIds,
          departureAt = dateAdd("h", 8, now()),
          returnAt = dateAdd("h", 10, now())
        );
        var saveRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", payload);
        expect(saveRes.SUCCESS).toBeTrue("savebasic failed: " & serializeJSON(saveRes));

        var sendRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=sendbasic", {
          action = "sendbasic",
          floatPlanId = val(saveRes.FLOATPLANID)
        });
        expect(sendRes.SUCCESS).toBeTrue("sendbasic failed: " & serializeJSON(sendRes));

        var pdfRes = getBasicPdfAsUser(userId, val(saveRes.FLOATPLANID));
        expect(findNoCase("200", pdfRes.STATUS_CODE)).toBeGT(0, serializeJSON(pdfRes));
        expect(findNoCase("application/pdf", pdfRes.CONTENT_TYPE)).toBeGT(0, serializeJSON(pdfRes));
        expect(findNoCase("attachment", pdfRes.CONTENT_DISPOSITION)).toBeGT(0, serializeJSON(pdfRes));
        expect(len(pdfRes.FILECONTENT)).toBeGT(0);

        var otherRes = getBasicPdfAsUser(otherUserId, val(saveRes.FLOATPLANID));
        var otherJson = parseMaybeJson(otherRes.FILECONTENT);
        expect(findNoCase("application/pdf", otherRes.CONTENT_TYPE)).toBe(0, serializeJSON(otherRes));
        expect(otherJson.SUCCESS).toBeFalse(serializeJSON(otherJson));
        expect(otherJson.ERROR).toBe("PLAN_NOT_FOUND");
      });

      it("does not download Basic drafts, Premium route-backed plans, or anonymous requests through the Basic PDF endpoint", function() {
        var userId = nextTestUserId();
        var fixtures = createFixtures(userId, 1);
        var payload = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = fixtures.waypointIds,
          departureAt = dateAdd("h", 8, now()),
          returnAt = dateAdd("h", 9, now())
        );
        var saveRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", payload);
        expect(saveRes.SUCCESS).toBeTrue("savebasic failed: " & serializeJSON(saveRes));

        var draftRes = getBasicPdfAsUser(userId, val(saveRes.FLOATPLANID));
        var draftJson = parseMaybeJson(draftRes.FILECONTENT);
        expect(findNoCase("application/pdf", draftRes.CONTENT_TYPE)).toBe(0, serializeJSON(draftRes));
        expect(draftJson.SUCCESS).toBeFalse(serializeJSON(draftJson));
        expect(draftJson.ERROR).toBe("BASIC_PDF_UNAVAILABLE");

        var premiumPlanId = insertPremiumScopedFloatPlan(userId);
        var premiumRes = getBasicPdfAsUser(userId, premiumPlanId);
        var premiumJson = parseMaybeJson(premiumRes.FILECONTENT);
        expect(findNoCase("application/pdf", premiumRes.CONTENT_TYPE)).toBe(0, serializeJSON(premiumRes));
        expect(premiumJson.SUCCESS).toBeFalse(serializeJSON(premiumJson));
        expect(premiumJson.ERROR.CODE).toBe("BASIC_SAVED_ROUTE_RESTRICTED");

        var anonRes = getBasicPdfAnonymous(val(saveRes.FLOATPLANID));
        var anonJson = parseMaybeJson(anonRes.FILECONTENT);
        expect(findNoCase("application/pdf", anonRes.CONTENT_TYPE)).toBe(0, serializeJSON(anonRes));
        expect(anonJson.AUTH).toBeFalse(serializeJSON(anonJson));
        expect(anonJson.ERROR).toBe("NOT_LOGGED_IN");
      });

      it("sends Basic operational float plans with basic monitoring only and no Follow stream", function() {
        var userId = nextTestUserId();
        var fixtures = createFixtures(userId, 2);
        var payload = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = fixtures.waypointIds,
          departureAt = dateAdd("h", 8, now()),
          returnAt = dateAdd("h", 10, now())
        );
        var saveRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", payload);
        expect(saveRes.SUCCESS).toBeTrue("savebasic failed: " & serializeJSON(saveRes));

        var sendRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=sendbasic", {
          action = "sendbasic",
          floatPlanId = val(saveRes.FLOATPLANID)
        });
        expect(sendRes.SUCCESS).toBeTrue("sendbasic failed: " & serializeJSON(sendRes));
        expect(sendRes.MONITORING_MODE).toBe("basic");

        var qState = queryExecute(
          "SELECT fp.status, fm.monitoring_mode, fm.monitor_state,
                  (SELECT COUNT(*) FROM voyage_streams vs WHERE vs.floatplan_id = fp.floatplanId) AS stream_count
             FROM floatplans fp
             LEFT JOIN floatplan_monitoring fm ON fm.float_plan_id = fp.floatplanId
            WHERE fp.floatplanId = :planId
              AND fp.userId = :userId",
          {
            planId = { value = val(saveRes.FLOATPLANID), cfsqltype = "cf_sql_integer" },
            userId = { value = userId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = "fpw" }
        );

        expect(qState.recordCount).toBe(1);
        expect(ucase(trim(qState.status[1]))).toBe("ACTIVE");
        expect(trim(qState.monitoring_mode[1])).toBe("basic");
        expect(ucase(trim(qState.monitor_state[1]))).toBe("ACTIVE");
        expect(val(qState.stream_count[1])).toBe(0);
      });

      it("keeps Basic operational plans out of reusable route library persistence", function() {
        var userId = nextTestUserId();
        var fixtures = createFixtures(userId, 1);
        var payload = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = fixtures.waypointIds,
          departureAt = dateAdd("h", 8, now()),
          returnAt = dateAdd("h", 9, now())
        );
        var saveRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", payload);
        expect(saveRes.SUCCESS).toBeTrue("savebasic failed: " & serializeJSON(saveRes));

        var qRouteRecords = queryExecute(
          "SELECT
              (SELECT COUNT(*) FROM route_instances WHERE user_id = :userId) AS route_instance_count,
              (SELECT COUNT(*)
                 FROM floatplans
                WHERE userId = :numericUserId
                  AND floatplanId = :planId
                  AND route_origin = 'basic_float_plan'
                  AND is_reusable = 0
                  AND is_visible_in_route_library = 0) AS basic_scope_count",
          {
            userId = { value = toString(userId), cfsqltype = "cf_sql_varchar" },
            numericUserId = { value = userId, cfsqltype = "cf_sql_integer" },
            planId = { value = val(saveRes.FLOATPLANID), cfsqltype = "cf_sql_integer" }
          },
          { datasource = "fpw" }
        );

        expect(val(qRouteRecords.route_instance_count[1])).toBe(0);
        expect(val(qRouteRecords.basic_scope_count[1])).toBe(1);
      });

	      it("rejects Basic operational save over 2 saved waypoints and over 1 day", function() {
        var userId = nextTestUserId();
        var fixtures = createFixtures(userId, 4);
        var tooManyWaypoints = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = fixtures.waypointIds,
          departureAt = dateAdd("h", 8, now()),
          returnAt = dateAdd("h", 10, now())
        );
	        var waypointRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", tooManyWaypoints);
	        expect(waypointRes.SUCCESS).toBeFalse(serializeJSON(waypointRes));
	        expect(responseErrorCode(waypointRes)).toBe("BASIC_WAYPOINT_LIMIT");

	        var validFixtureIds = [ fixtures.waypointIds[1], fixtures.waypointIds[2] ];
        var tooLong = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = validFixtureIds,
          departureAt = dateAdd("h", 8, now()),
          returnAt = dateAdd("h", 33, now())
        );
	        var durationRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", tooLong);
	        expect(durationRes.SUCCESS).toBeFalse(serializeJSON(durationRes));
	        expect(responseErrorCode(durationRes)).toBe("BASIC_TRIP_DAY_LIMIT");
      });

      it("blocks active_route monitoring for Basic operational float plans", function() {
        var userId = nextTestUserId();
        var fixtures = createFixtures(userId, 1);
        var payload = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = fixtures.waypointIds,
          departureAt = dateAdd("h", 8, now()),
          returnAt = dateAdd("h", 9, now())
        );
        var saveRes = postAsUser(userId, "/api/v1/floatplan.cfc?method=handle&action=savebasic", payload);
        expect(saveRes.SUCCESS).toBeTrue("savebasic failed: " & serializeJSON(saveRes));

        var monitoringRes = new fpw.api.v1.monitor().init("fpw").startMonitoringForFloatPlan(val(saveRes.FLOATPLANID), "active_route");
        expect(monitoringRes.SUCCESS).toBeFalse(serializeJSON(monitoringRes));
        expect(monitoringRes.ERROR.CODE).toBe("BASIC_ADVANCED_MONITORING_RESTRICTED");
      });

      it("keeps Active Cruise and Follow Page authority Premium-only for Basic owners", function() {
        var userId = nextTestUserId();
        var activeModel = variables.activeCruiseViewModel.getActiveCruiseViewModel(userId, 1);
        var followAuthority = variables.activeCruiseViewModel.getPublicFollowAuthority(userId, 1);

        expect(activeModel.success).toBeFalse(serializeJSON(activeModel));
        expect(activeModel.errorCode).toBe("BASIC_ACTIVE_CRUISE_RESTRICTED");
        expect(followAuthority.errorCode).toBe("BASIC_FOLLOW_RESTRICTED");
      });

	      it("keeps Premium sources allowed through saved route gates", function() {
        var sources = [ "stripe_subscription", "three_day_pass", "admin_comp" ];
        var i = 0;

        for (i = 1; i <= arrayLen(sources); i++) {
          var userId = nextTestUserId();
          createEntitlementForSource(userId, sources[i]);
          var gateRes = variables.gate.requirePremium(
            userId = userId,
            errorCode = "BASIC_SAVED_ROUTE_RESTRICTED",
            message = "Premium required."
          );
          expect(gateRes.allowed).toBeTrue(sources[i] & ": " & serializeJSON(gateRes));
	        }
	      });

	      it("blocks Basic reusable vessel, operator, and contact saves while allowing passengers and waypoints", function() {
	        var basicUserId = nextTestUserId();
	        var premiumUserId = nextTestUserId();
	        createEntitlementForSource(premiumUserId, "stripe_subscription");

	        var vesselPayload = {
	          action = "save",
	          vessel = {
	            vesselName = "Reusable Vessel " & createUUID(),
	            type = "Power",
	            length = "25",
	            color = "White"
	          }
	        };
	        var operatorPayload = {
	          action = "save",
	          operator = {
	            name = "Reusable Operator " & createUUID(),
	            phone = "555-0101"
	          }
	        };
	        var contactPayload = {
	          action = "save",
	          contact = {
	            name = "Reusable Contact " & createUUID(),
	            phone = "555-0102",
	            email = "reusable-contact-" & createUUID() & "@example.com"
	          }
	        };
	        var passengerPayload = {
	          action = "save",
	          passenger = {
	            name = "Allowed Basic Passenger " & createUUID(),
	            phone = "555-0103"
	          }
	        };
        var waypointPayload = {
          action = "save",
          waypoint = {
            name = "Allowed Basic WP " & left(replace(createUUID(), "-", "", "all"), 24),
            latitude = "28.01",
            longitude = "-82.01"
          }
	        };

	        var basicVessel = postAsUser(basicUserId, "/api/v1/vessel.cfc?method=handle", duplicate(vesselPayload));
	        var basicOperator = postAsUser(basicUserId, "/api/v1/operator.cfc?method=handle", duplicate(operatorPayload));
	        var basicContact = postAsUser(basicUserId, "/api/v1/contact.cfc?method=handle", duplicate(contactPayload));
	        var basicPassenger = postAsUser(basicUserId, "/api/v1/passenger.cfc?method=handle", duplicate(passengerPayload));
	        var basicWaypoint = postAsUser(basicUserId, "/api/v1/waypoint.cfc?method=handle", duplicate(waypointPayload));

	        expect(basicVessel.SUCCESS).toBeFalse(serializeJSON(basicVessel));
	        expect(basicVessel.ERROR.CODE).toBe("BASIC_REUSABLE_VESSEL_RESTRICTED");
	        expect(basicOperator.SUCCESS).toBeFalse(serializeJSON(basicOperator));
	        expect(basicOperator.ERROR.CODE).toBe("BASIC_REUSABLE_OPERATOR_RESTRICTED");
	        expect(basicContact.SUCCESS).toBeFalse(serializeJSON(basicContact));
	        expect(basicContact.ERROR.CODE).toBe("BASIC_REUSABLE_CONTACT_RESTRICTED");
	        expect(basicPassenger.SUCCESS).toBeTrue("Basic passenger save should remain allowed: " & serializeJSON(basicPassenger));
	        expect(basicWaypoint.SUCCESS).toBeTrue("Basic waypoint save should remain allowed: " & serializeJSON(basicWaypoint));

	        var premiumVessel = postAsUser(premiumUserId, "/api/v1/vessel.cfc?method=handle", duplicate(vesselPayload));
	        var premiumOperator = postAsUser(premiumUserId, "/api/v1/operator.cfc?method=handle", duplicate(operatorPayload));
	        var premiumContact = postAsUser(premiumUserId, "/api/v1/contact.cfc?method=handle", duplicate(contactPayload));

	        expect(premiumVessel.SUCCESS).toBeTrue("Premium vessel save failed: " & serializeJSON(premiumVessel));
	        expect(premiumOperator.SUCCESS).toBeTrue("Premium operator save failed: " & serializeJSON(premiumOperator));
	        expect(premiumContact.SUCCESS).toBeTrue("Premium contact save failed: " & serializeJSON(premiumContact));
	      });

	      it("rejects anonymous Basic operational save", function() {
        var userId = nextTestUserId();
        var fixtures = createFixtures(userId, 1);
        var payload = buildBasicPayload(
          fixtures = fixtures,
          waypointIds = fixtures.waypointIds,
          departureAt = dateAdd("h", 8, now()),
          returnAt = dateAdd("h", 9, now())
        );
        var res = postAnonymous("/api/v1/floatplan.cfc?method=handle&action=savebasic", payload);

        expect(res.AUTH).toBeFalse(serializeJSON(res));
        expect(res.ERROR).toBe("NOT_LOGGED_IN");
      });
    });
  }

  private numeric function nextTestUserId() {
    variables.userSeed++;
    arrayAppend(variables.createdUserIds, variables.userSeed);
    return variables.userSeed;
  }

  private struct function createFixtures(required numeric userId, required numeric waypointCount) {
    var suffix = replace(createUUID(), "-", "", "all");
    var vesselId = insertAndReturnId(
      "INSERT INTO vessels (userId, vesselName, hailingPort, isDefaultVessel)
       VALUES (:userId, :vesselName, :hailingPort, 1)",
      {
        userId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" },
        vesselName = { value = "Basic Test Vessel " & suffix, cfsqltype = "cf_sql_varchar" },
        hailingPort = { value = "Test Port", cfsqltype = "cf_sql_varchar" }
      }
    );
    var contactId = insertAndReturnId(
      "INSERT INTO contacts (name, phone, userId, email)
       VALUES (:name, :phone, :userId, :email)",
      {
        name = { value = "Basic Test Contact " & suffix, cfsqltype = "cf_sql_varchar" },
        phone = { value = "555-0100", cfsqltype = "cf_sql_varchar" },
        userId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" },
        email = { value = "basic-operational-" & suffix & "@example.com", cfsqltype = "cf_sql_varchar" }
      }
    );
    var waypointIds = [];
    var i = 0;

    arrayAppend(variables.createdVesselIds, vesselId);
    arrayAppend(variables.createdContactIds, contactId);

    for (i = 1; i <= arguments.waypointCount; i++) {
      var waypointId = insertAndReturnId(
        "INSERT INTO waypoints (name, latitude, longitude, userId, notes)
         VALUES (:name, :latitude, :longitude, :userId, :notes)",
        {
          name = { value = "Basic Test Waypoint " & i & " " & suffix, cfsqltype = "cf_sql_varchar" },
          latitude = { value = "28." & numberFormat(i, "00"), cfsqltype = "cf_sql_varchar" },
          longitude = { value = "-82." & numberFormat(i, "00"), cfsqltype = "cf_sql_varchar" },
          userId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" },
          notes = { value = "Basic operational test waypoint", cfsqltype = "cf_sql_longvarchar" }
        }
      );
      arrayAppend(variables.createdWaypointIds, waypointId);
      arrayAppend(waypointIds, waypointId);
    }

    return {
      vesselId = vesselId,
      contactId = contactId,
      waypointIds = waypointIds,
      suffix = suffix
    };
  }

	  private struct function buildBasicPayload(required struct fixtures, required array waypointIds, required any departureAt, required any returnAt, string timeZone = "US/Eastern") {
	    var waypoints = [];
	    var i = 0;
	    var authority = getFirstRescueAuthority();
	    var departureUtc = clientUtcIso(arguments.departureAt, arguments.timeZone);
	    var returnUtc = clientUtcIso(arguments.returnAt, arguments.timeZone);
	    for (i = 1; i <= arrayLen(arguments.waypointIds); i++) {
      arrayAppend(waypoints, {
        WAYPOINTID = arguments.waypointIds[i],
        REASON_FOR_STOP = "Stop " & i,
        DEPART_MODE = "planned",
        ARRIVAL_TIME = "",
        DEPARTURE_TIME = ""
      });
    }

    return {
      action = "savebasic",
      FLOATPLAN = {
	        floatPlanId = 0,
	        floatPlanName = "Basic Operational " & arguments.fixtures.suffix,
	        vesselId = 0,
	        operatorId = 0,
	        email = "captain-" & arguments.fixtures.suffix & "@example.com",
	        rescueCenterId = authority.id,
	        rescueAuthorityPhone = "555-0199",
	        departingFrom = "Test Marina",
	        departureTime = dtString(arguments.departureAt),
	        departureTimezone = arguments.timeZone,
	        departureTimeUtc = departureUtc,
        returningTo = "Test Marina",
        returnTime = dtString(arguments.returnAt),
	        returnTimezone = arguments.timeZone,
	        returnTimeUtc = returnUtc,
        foodDaysPerPerson = "1",
        waterDaysPerPerson = "1",
        notes = "Basic operational test",
        routeInstanceId = 0,
	        routeDayNumber = 0
	      },
	      BASIC_DETAILS = {
	        VESSEL_NAME = "Basic Test Vessel " & arguments.fixtures.suffix,
	        OPERATOR_NAME = "Basic Test Operator " & arguments.fixtures.suffix,
	        CAPTAIN_NAME = "Basic Test Captain " & arguments.fixtures.suffix,
	        CAPTAIN_EMAIL = "captain-" & arguments.fixtures.suffix & "@example.com",
	        NOTIFICATION_CONTACT_NAME = "Basic Test Contact " & arguments.fixtures.suffix,
	        NOTIFICATION_CONTACT_EMAIL = "basic-operational-" & arguments.fixtures.suffix & "@example.com",
	        NOTIFICATION_CONTACT_PHONE = "555-0100",
	        LAUNCH_LOCATION = "Test Marina",
	        DESTINATION_LOCATION = "Test Sandbar",
	        AUTHORITY_ID = authority.id
	      },
	      CONTACTS = [],
	      WAYPOINTS = waypoints
	    };
	  }

	  private struct function getFirstRescueAuthority() {
	    var qAuthority = queryExecute(
	      "SELECT recId, rcPhone
	         FROM rescuecenters
	        WHERE recId IS NOT NULL
	        ORDER BY recId ASC
	        LIMIT 1",
	      {},
	      { datasource = "fpw" }
	    );
	    expect(qAuthority.recordCount).toBeGT(0, "rescuecenters must contain at least one authority for Basic tests.");
	    return {
	      id = val(qAuthority.recId[1]),
	      phone = isNull(qAuthority.rcPhone[1]) ? "" : trim(qAuthority.rcPhone[1])
	    };
	  }

  private string function clientUtcIso(required any localAt, required string timeZone) {
    var normalizedTimeZone = trim(arguments.timeZone);
    var localText = dtString(arguments.localAt);
    if (!len(normalizedTimeZone) OR !len(localText)) {
      return "";
    }
    try {
      if (listFindNoCase("UTC,Etc/UTC,GMT", normalizedTimeZone)) {
        return replace(localText, " ", "T", "one") & ".000Z";
      }
      var formatter = createObject("java", "java.time.format.DateTimeFormatter").ofPattern("yyyy-MM-dd HH:mm:ss");
      var localDateTime = createObject("java", "java.time.LocalDateTime").parse(localText, formatter);
      var zoneId = createObject("java", "java.time.ZoneId").of(normalizedTimeZone);
      return toString(localDateTime.atZone(zoneId).toInstant());
    } catch (any utcErr) {
      return "";
    }
  }

  private string function utcIsoToSql(required string value) {
    var raw = trim(arguments.value);
    raw = replace(raw, "T", " ", "one");
    raw = reReplace(raw, "Z$", "", "one");
    raw = reReplace(raw, "\.[0-9]+$", "", "one");
    if (len(raw) EQ 16) {
      raw &= ":00";
    }
    return left(raw, 19);
  }

  private struct function postAsUser(required numeric userId, required string path, required struct payload) {
    var authContext = applyTestSessionUser(arguments.userId);
    try {
      return variables.api.postJson(arguments.path, arguments.payload);
    } finally {
      restoreTestSessionUser(authContext);
    }
  }

  private struct function getBasicCurrentAsUser(required numeric userId) {
    var authContext = applyTestSessionUser(arguments.userId);
    try {
      return variables.api.getJson("/api/v1/floatplan.cfc?method=handle&action=getbasiccurrent");
    } finally {
      restoreTestSessionUser(authContext);
    }
  }

  private struct function closeBasicAsUser(required numeric userId, required numeric floatPlanId) {
    var authContext = applyTestSessionUser(arguments.userId);
    try {
      return variables.api.postJson("/api/v1/floatplan.cfc?method=handle&action=closebasic", {
        action = "closebasic",
        floatPlanId = arguments.floatPlanId
      });
    } finally {
      restoreTestSessionUser(authContext);
    }
  }

  private struct function getBasicPdfAsUser(required numeric userId, required numeric floatPlanId) {
    url.testUserId = arguments.userId;
    return getRawApi(
      path = "/api/v1/floatplan.cfc?method=handle&action=downloadbasicpdf&id=" & arguments.floatPlanId,
      requireSession = true,
      testUserId = arguments.userId
    );
  }

  private struct function getBasicPdfAnonymous(required numeric floatPlanId) {
    return getRawApi(
      path = "/api/v1/floatplan.cfc?method=handle&action=downloadbasicpdf&id=" & arguments.floatPlanId,
      requireSession = false,
      testUserId = 0
    );
  }

  private struct function getRawApi(required string path, boolean requireSession=true, numeric testUserId=0) {
    var httpResult = {};
    var authContext = {};
    if (arguments.requireSession AND arguments.testUserId GT 0) {
      authContext = applyTestSessionUser(arguments.testUserId);
    }
    if (arguments.requireSession) {
      variables.api.ensureApprovedSession();
    }
    try {
      cfhttp(url = variables.api.getBaseUrl() & arguments.path, method = "get", result = "httpResult", charset = "utf-8") {
        if (arguments.requireSession AND len(variables.api.getCookieHeader())) {
          cfhttpparam(type = "header", name = "Cookie", value = variables.api.getCookieHeader());
        }
        if (arguments.testUserId GT 0) {
          cfhttpparam(type = "header", name = "X-FPW-Test-UserId", value = arguments.testUserId);
        }
      }
    } finally {
      if (structCount(authContext)) {
        restoreTestSessionUser(authContext);
      }
    }

    return {
      STATUS_CODE = structKeyExists(httpResult, "statusCode") ? httpResult.statusCode : "",
      CONTENT_TYPE = responseHeaderValue(httpResult, "Content-Type"),
      CONTENT_DISPOSITION = responseHeaderValue(httpResult, "Content-Disposition"),
      FILECONTENT = structKeyExists(httpResult, "fileContent") ? httpResult.fileContent : ""
    };
  }

  private struct function applyTestSessionUser(required numeric userId) {
    var context = {
      hadUrlUser = structKeyExists(url, "testUserId"),
      priorUrlUser = structKeyExists(url, "testUserId") ? url.testUserId : "",
      hadSessionUser = structKeyExists(session, "user"),
      priorSessionUser = (structKeyExists(session, "user") AND isStruct(session.user)) ? duplicate(session.user) : {}
    };
    url.testUserId = arguments.userId;
    if (!structKeyExists(session, "user") OR !isStruct(session.user)) {
      session.user = {};
    }
    session.user.userId = arguments.userId;
    session.user.id = arguments.userId;
    session.user.USERID = arguments.userId;
    return context;
  }

  private void function restoreTestSessionUser(required struct context) {
    if (arguments.context.hadUrlUser) {
      url.testUserId = arguments.context.priorUrlUser;
    } else {
      structDelete(url, "testUserId", false);
    }
    if (arguments.context.hadSessionUser) {
      session.user = arguments.context.priorSessionUser;
    } else {
      structDelete(session, "user", false);
    }
  }

  private string function responseHeaderValue(required struct httpResult, required string headerName) {
    var headers = structKeyExists(arguments.httpResult, "responseHeader") ? arguments.httpResult.responseHeader : {};
    var key = "";
    var value = "";
    if (!isStruct(headers)) {
      return "";
    }
    for (key in headers) {
      if (compareNoCase(key, arguments.headerName) EQ 0) {
        value = headers[key];
        if (isArray(value)) {
          return arrayToList(value, ", ");
        }
        return toString(value);
      }
    }
    return "";
  }

	  private struct function parseMaybeJson(required any raw) {
	    try {
	      return deserializeJSON(toString(arguments.raw), false);
	    } catch (any err) {
	      return {};
	    }
	  }

	  private string function responseErrorCode(required struct response) {
	    if (structKeyExists(arguments.response, "errorCode")) {
	      return toString(arguments.response.errorCode);
	    }
	    if (structKeyExists(arguments.response, "ERROR")) {
	      if (isStruct(arguments.response.ERROR) AND structKeyExists(arguments.response.ERROR, "CODE")) {
	        return toString(arguments.response.ERROR.CODE);
	      }
	      return toString(arguments.response.ERROR);
	    }
	    return "";
	  }

	  private struct function postAnonymous(required string path, required struct payload) {
    var hadUrlUser = structKeyExists(url, "testUserId");
    var priorUrlUser = hadUrlUser ? url.testUserId : "";
    var hadSessionUser = structKeyExists(session, "user");
    var priorSessionUser = hadSessionUser ? duplicate(session.user) : {};
    structDelete(url, "testUserId");
    structDelete(session, "user");
    try {
      var anonApi = new fpw.tests.support.FpwApiSupport().init();
      return anonApi.postJson(arguments.path, arguments.payload, false);
    } finally {
      if (hadUrlUser) {
        url.testUserId = priorUrlUser;
      }
      if (hadSessionUser) {
        session.user = priorSessionUser;
      }
    }
  }

  private numeric function insertAndReturnId(required string sqlText, required struct params) {
    queryExecute(arguments.sqlText, arguments.params, { datasource = "fpw" });
    var qNewId = queryExecute("SELECT LAST_INSERT_ID() AS new_id", {}, { datasource = "fpw" });
    return qNewId.recordCount ? val(qNewId.new_id[1]) : 0;
  }

  private void function createEntitlementForSource(required numeric userId, required string source) {
    if (arguments.source EQ "stripe_subscription") {
      variables.entitlements.createSubscriptionEntitlement(arguments.userId, {
        stripeSubscriptionId = "sub_basic_operational_" & arguments.userId,
        stripeCustomerId = "cus_basic_operational_" & arguments.userId
      });
    } else if (arguments.source EQ "three_day_pass") {
      variables.entitlements.createThreeDayPassEntitlement(arguments.userId);
    } else if (arguments.source EQ "admin_comp") {
      variables.entitlements.createAdminCompEntitlement(arguments.userId);
    }
  }

  private numeric function insertPremiumScopedFloatPlan(required numeric userId) {
    return insertAndReturnId(
      "INSERT INTO floatplans
        (userId, floatPlanName, status, route_origin, is_reusable, is_visible_in_route_library, dateCreated, lastUpdate)
       VALUES
        (:userId, :planName, 'Draft', 'premium_saved_route', 1, 1, NOW(), NOW())",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        planName = { value = "Premium scoped test " & createUUID(), cfsqltype = "cf_sql_varchar" }
      }
    );
  }

  private numeric function insertBasicScopedDraft(required numeric userId) {
    return insertAndReturnId(
      "INSERT INTO floatplans
        (userId, floatPlanName, status, route_origin, is_reusable, is_visible_in_route_library, route_instance_id, dateCreated, lastUpdate)
       VALUES
        (:userId, :planName, 'Draft', 'basic_float_plan', 0, 0, NULL, NOW(), NOW())",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        planName = { value = "Secondary Basic draft " & createUUID(), cfsqltype = "cf_sql_varchar" }
      }
    );
  }

  private void function cleanupCreatedData() {
    var userIdList = arrayLen(variables.createdUserIds) ? arrayToList(variables.createdUserIds) : "";
    var planIdList = "";
    if (len(userIdList)) {
      var qPlans = queryExecute(
        "SELECT floatplanId
           FROM floatplans
          WHERE userId IN (:userIds)",
        {
          userIds = { value = userIdList, cfsqltype = "cf_sql_integer", list = true }
        },
        { datasource = "fpw" }
      );
      for (var i = 1; i <= qPlans.recordCount; i++) {
        planIdList = listAppend(planIdList, qPlans.floatplanId[i]);
      }

      if (len(planIdList)) {
        queryExecute("DELETE FROM floatplan_monitor_events WHERE float_plan_id IN (:planIds)", { planIds = { value = planIdList, cfsqltype = "cf_sql_integer", list = true } }, { datasource = "fpw" });
        queryExecute("DELETE FROM floatplan_monitoring WHERE float_plan_id IN (:planIds)", { planIds = { value = planIdList, cfsqltype = "cf_sql_integer", list = true } }, { datasource = "fpw" });
        queryExecute("DELETE FROM floatplan_alert_history WHERE floatPlanId IN (:planIds)", { planIds = { value = planIdList, cfsqltype = "cf_sql_integer", list = true } }, { datasource = "fpw" });
        queryExecute("DELETE FROM floatplan_history WHERE floatPlanId IN (:planIds)", { planIds = { value = planIdList, cfsqltype = "cf_sql_integer", list = true } }, { datasource = "fpw" });
        queryExecute("DELETE FROM floatplan_notification_log WHERE floatplanId IN (:planIds)", { planIds = { value = planIdList, cfsqltype = "cf_sql_integer", list = true } }, { datasource = "fpw" });
        queryExecute("DELETE FROM floatplan_notifications WHERE floatplanId IN (:planIds)", { planIds = { value = planIdList, cfsqltype = "cf_sql_integer", list = true } }, { datasource = "fpw" });
	        queryExecute("DELETE FROM floatplan_contacts WHERE floatPlanId IN (:planIds)", { planIds = { value = planIdList, cfsqltype = "cf_sql_integer", list = true } }, { datasource = "fpw" });
	        queryExecute("DELETE FROM floatplan_passengers WHERE floatPlanId IN (:planIds)", { planIds = { value = planIdList, cfsqltype = "cf_sql_integer", list = true } }, { datasource = "fpw" });
	        queryExecute("DELETE FROM floatplan_waypoints WHERE floatPlanId IN (:planIds)", { planIds = { value = planIdList, cfsqltype = "cf_sql_integer", list = true } }, { datasource = "fpw" });
	        queryExecute("DELETE FROM floatplan_basic_details WHERE floatplan_id IN (:planIds)", { planIds = { value = planIdList, cfsqltype = "cf_sql_integer", list = true } }, { datasource = "fpw" });
	        queryExecute("DELETE FROM floatplans WHERE floatPlanId IN (:planIds) AND userId IN (:userIds)", {
          planIds = { value = planIdList, cfsqltype = "cf_sql_integer", list = true },
          userIds = { value = userIdList, cfsqltype = "cf_sql_integer", list = true }
        }, { datasource = "fpw" });
      }

	      queryExecute("DELETE FROM member_entitlements WHERE user_id IN (:userIds)", { userIds = { value = userIdList, cfsqltype = "cf_sql_integer", list = true } }, { datasource = "fpw" });
	      queryExecute("DELETE FROM vessels WHERE userId IN (:userIds)", { userIds = { value = userIdList, cfsqltype = "cf_sql_varchar", list = true } }, { datasource = "fpw" });
	      queryExecute("DELETE FROM operators WHERE userId IN (:userIds)", { userIds = { value = userIdList, cfsqltype = "cf_sql_varchar", list = true } }, { datasource = "fpw" });
	      queryExecute("DELETE FROM contacts WHERE userId IN (:userIds)", { userIds = { value = userIdList, cfsqltype = "cf_sql_varchar", list = true } }, { datasource = "fpw" });
	      queryExecute("DELETE FROM passengers WHERE userId IN (:userIds)", { userIds = { value = userIdList, cfsqltype = "cf_sql_varchar", list = true } }, { datasource = "fpw" });
	      queryExecute("DELETE FROM waypoints WHERE userId IN (:userIds)", { userIds = { value = userIdList, cfsqltype = "cf_sql_varchar", list = true } }, { datasource = "fpw" });
    }

    variables.createdUserIds = [];
    variables.createdVesselIds = [];
    variables.createdContactIds = [];
    variables.createdWaypointIds = [];
  }

  private void function ensureMemberEntitlementsTable() {
    queryExecute(
      "CREATE TABLE IF NOT EXISTS member_entitlements (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        user_id INT NOT NULL,
        entitlement_type VARCHAR(40) NOT NULL DEFAULT 'premium',
        source VARCHAR(40) NOT NULL,
        status VARCHAR(40) NOT NULL DEFAULT 'active',
        starts_at_utc DATETIME NOT NULL,
        expires_at_utc DATETIME NULL,
        stripe_customer_id VARCHAR(255) NULL,
        stripe_subscription_id VARCHAR(255) NULL,
        stripe_checkout_session_id VARCHAR(255) NULL,
        stripe_payment_intent_id VARCHAR(255) NULL,
        created_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY idx_member_entitlements_user_access (user_id, entitlement_type, status, starts_at_utc, expires_at_utc),
        KEY idx_member_entitlements_pass_expiry (source, status, expires_at_utc),
        KEY idx_member_entitlements_stripe_customer (stripe_customer_id),
        KEY idx_member_entitlements_stripe_subscription (stripe_subscription_id),
        KEY idx_member_entitlements_stripe_checkout (stripe_checkout_session_id),
        KEY idx_member_entitlements_stripe_payment (stripe_payment_intent_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
      {},
      { datasource = "fpw" }
    );
  }

	  private void function ensureBasicOperationalColumns() {
	    ensureColumn("route_origin", "ALTER TABLE floatplans ADD COLUMN route_origin VARCHAR(40) NOT NULL DEFAULT 'premium_saved_route' AFTER route_day_number");
	    ensureColumn("is_reusable", "ALTER TABLE floatplans ADD COLUMN is_reusable TINYINT(1) NOT NULL DEFAULT 1 AFTER route_origin");
	    ensureColumn("is_visible_in_route_library", "ALTER TABLE floatplans ADD COLUMN is_visible_in_route_library TINYINT(1) NOT NULL DEFAULT 1 AFTER is_reusable");
	  }

	  private void function ensureBasicDetailsTable() {
	    queryExecute(
	      "CREATE TABLE IF NOT EXISTS floatplan_basic_details (
	        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
	        floatplan_id INT NOT NULL,
	        vessel_name VARCHAR(255) NOT NULL,
	        operator_name VARCHAR(255) NOT NULL,
	        captain_name VARCHAR(255) NOT NULL,
	        captain_email VARCHAR(255) NOT NULL,
	        notification_contact_name VARCHAR(255) NOT NULL,
	        notification_contact_email VARCHAR(255) NOT NULL,
	        notification_contact_phone VARCHAR(45) NULL,
	        launch_location VARCHAR(255) NOT NULL,
	        destination_location VARCHAR(255) NOT NULL,
	        authority_id INT NULL,
	        authority_name_snapshot VARCHAR(255) NOT NULL,
	        authority_phone_snapshot VARCHAR(45) NOT NULL,
	        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
	        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	        PRIMARY KEY (id),
	        UNIQUE KEY uq_floatplan_basic_details_plan (floatplan_id),
	        KEY idx_floatplan_basic_details_authority (authority_id),
	        KEY idx_floatplan_basic_details_contact_email (notification_contact_email)
	      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
	      {},
	      { datasource = "fpw" }
	    );
	  }

	  private void function ensureColumn(required string columnName, required string alterSql) {
    var qCol = queryExecute(
      "SELECT COUNT(*) AS col_count
         FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'floatplans'
          AND column_name = :columnName",
      {
        columnName = { value = arguments.columnName, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    if (qCol.recordCount EQ 1 AND val(qCol.col_count[1]) EQ 0) {
      queryExecute(arguments.alterSql, {}, { datasource = "fpw" });
    }
  }

  private string function dtString(required any value) {
    return dateFormat(arguments.value, "yyyy-mm-dd") & " " & timeFormat(arguments.value, "HH:mm:ss");
  }
}
