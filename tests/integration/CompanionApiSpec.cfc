component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
      variables.api = new fpw.tests.support.FpwApiSupport().init(
        authEmail = "detroit@email.com",
        authPassword = "changeIt"
      );
      variables.naming = new fpw.tests.support.FpwNamingSupport();
      variables.companionService = new fpw.api.v1.CompanionViewModelService().init("fpw");
      variables.companionAuthService = new fpw.api.v1.CompanionAuthService().init("fpw");
      variables.activeCruiseViewModelService = new fpw.api.v1.ActiveCruiseViewModelService().init("fpw");
      variables.monitorService = new fpw.api.v1.monitor().init();
      variables.hadOriginalTestUserId = structKeyExists(url, "testUserId");
    variables.originalTestUserId = variables.hadOriginalTestUserId ? url.testUserId : "";
    variables.sessionApiUser = createSessionApiUser();
    url.testUserId = variables.sessionApiUser.userId;
  }

  function afterAll() {
    cleanupCompanionAuthRows(variables.sessionApiUser.userId);
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
          expect(structKeyExists(model.actions.checkIn, "actions")).toBeTrue(serializeJSON(model.actions.checkIn));
          expect(model.actions.checkIn.endpoint).toBe("/fpw/api/v1/companion.cfc?method=handle&action=checkin&returnFormat=json");
          expect(model.actions.checkIn.returnsRefreshedCompanionModel).toBeTrue(serializeJSON(model.actions.checkIn));
          expect(model.refresh.endpoint).toBe("/fpw/api/v1/companion.cfc?method=handle&action=current&returnFormat=json");
          expect(model.storageAuthority.activePlanGuard).toBe("floatplan.resolveCurrentRouteFloatPlanGroup", serializeJSON(model.storageAuthority));
          expect(model.storageAuthority.readModel).toBe("ActiveCruiseViewModelService", serializeJSON(model.storageAuthority));
          expect(model.storageAuthority.checkInWrite).toBe("companion.cfc?action=checkin", serializeJSON(model.storageAuthority));
          expect(model.storageAuthority.canonicalCheckInAuthority).toBe("floatplan.cfc?action=checkin", serializeJSON(model.storageAuthority));
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("exposes mobile companion check-in action contracts and separate Start Next Leg metadata", function() {
        var prefix = variables.naming.buildPrefix("companion", "action-contract");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var model = {};
        var checkInActions = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
          model = variables.companionService.getCurrentActiveCompanionModel(variables.sessionApiUser.userId);
          checkInActions = model.actions.checkIn.actions;

          expect(structKeyExists(checkInActions, "onTrack")).toBeTrue(serializeJSON(model.actions.checkIn));
          expect(structKeyExists(checkInActions, "delayed")).toBeTrue(serializeJSON(model.actions.checkIn));
          expect(structKeyExists(checkInActions, "changedPlan")).toBeTrue(serializeJSON(model.actions.checkIn));
          expect(structKeyExists(checkInActions, "secureForNight")).toBeTrue(serializeJSON(model.actions.checkIn));
          expect(structKeyExists(checkInActions, "assistanceNeeded")).toBeTrue(serializeJSON(model.actions.checkIn));

          assertMobileCheckInAction(checkInActions.onTrack, "onTrack", "On Track", "", asset.floatPlanId);
          assertMobileCheckInAction(checkInActions.delayed, "delayed", "Delayed", "", asset.floatPlanId);
          assertMobileCheckInAction(checkInActions.changedPlan, "changedPlan", "Changed Plan", "", asset.floatPlanId);
          assertMobileCheckInAction(checkInActions.secureForNight, "secureForNight", "Secure for the Night", "overnight", asset.floatPlanId);
          assertMobileCheckInAction(checkInActions.assistanceNeeded, "assistanceNeeded", "Assistance Needed", "", asset.floatPlanId);

          expect(checkInActions.assistanceNeeded.requiresConfirm).toBeTrue(serializeJSON(checkInActions.assistanceNeeded));
          expect(findNoCase("contacts may be notified", checkInActions.assistanceNeeded.confirmMessage)).toBeGT(0, serializeJSON(checkInActions.assistanceNeeded));
          expect(checkInActions.secureForNight.requiresConfirm).toBeTrue(serializeJSON(checkInActions.secureForNight));
          expect(structKeyExists(checkInActions.delayed.payload, "manualDelayMinutes")).toBeFalse(serializeJSON(checkInActions.delayed.payload));
          expect(structKeyExists(model.actions, "startNextLeg")).toBeTrue(serializeJSON(model.actions));
          expect(model.actions.startNextLeg.endpoint).toBe("/fpw/api/v1/floatplan.cfc?method=handle&action=startnextleg&returnFormat=json", serializeJSON(model.actions.startNextLeg));
          expect(model.actions.startNextLeg.payload.floatPlanId).toBe(asset.floatPlanId, serializeJSON(model.actions.startNextLeg));
          expect(structKeyExists(model.actions, "unavailableActions")).toBeTrue(serializeJSON(model.actions));
          expect(structKeyExists(model.actions.unavailableActions, "arrived")).toBeTrue(serializeJSON(model.actions.unavailableActions));
          expect(model.actions.unavailableActions.arrived.enabled).toBeFalse(serializeJSON(model.actions.unavailableActions.arrived));
          expect(model.actions.unavailableActions.arrived.disabledReason).toBe("Final arrival/close flow is not part of companion MVP.", serializeJSON(model.actions.unavailableActions.arrived));
          expect(structKeyExists(checkInActions, "arrived")).toBeFalse(serializeJSON(checkInActions));
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
          expect(response.actions.checkIn.actions.onTrack.payload.floatPlanId).toBe(asset.floatPlanId, serializeJSON(response.actions.checkIn));
          } finally {
            cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
          }
        });

        it("pairs one companion device with a hashed scoped token and revokes it per device", function() {
          var sessionApi = buildSessionApiSupport();
          var pairingResponse = {};
          var exchangeResponse = {};
          var duplicateResponse = {};
          var resolved = {};
          var listResponse = {};
          var revokeResponse = {};
          var revokedResolve = {};
          var deviceRow = {};

          try {
            pairingResponse = sessionApi.postJson("/api/v1/companionAuth.cfc?method=handle&action=createPairingCode&returnFormat=json", {});

            expect(pairingResponse.SUCCESS).toBeTrue(serializeJSON(pairingResponse));
            expect(pairingResponse.AUTH).toBeTrue(serializeJSON(pairingResponse));
            expect(len(trim(pairingResponse.PAIRING_CODE))).toBeGT(0, serializeJSON(pairingResponse));

            exchangeResponse = postJsonNoSession("/api/v1/companionAuth.cfc?method=handle&action=exchangePairingCode&returnFormat=json", {
              pairingCode = pairingResponse.PAIRING_CODE,
              device = {
                deviceUuid = "test-device-" & variables.sessionApiUser.userId,
                deviceName = "Companion Test Phone",
                platform = "ios",
                appVersion = "1.0.0"
              }
            });

            expect(exchangeResponse.SUCCESS).toBeTrue(serializeJSON(exchangeResponse));
            expect(exchangeResponse.AUTH).toBeTrue(serializeJSON(exchangeResponse));
            expect(len(trim(exchangeResponse.TOKEN))).toBeGT(40, serializeJSON(exchangeResponse));
            expect(exchangeResponse.SCOPES).toBe("companion:current,companion:checkin", serializeJSON(exchangeResponse));
            expect(val(exchangeResponse.DEVICE.id ?: 0)).toBeGT(0, serializeJSON(exchangeResponse));

            duplicateResponse = postJsonNoSession("/api/v1/companionAuth.cfc?method=handle&action=exchangePairingCode&returnFormat=json", {
              pairingCode = pairingResponse.PAIRING_CODE,
              device = {
                deviceUuid = "duplicate-device-" & variables.sessionApiUser.userId,
                platform = "ios",
                appVersion = "1.0.0"
              }
            });
            expect(duplicateResponse.SUCCESS).toBeFalse(serializeJSON(duplicateResponse));
            expect(duplicateResponse.ERROR).toBe("PAIRING_CODE_USED", serializeJSON(duplicateResponse));

            deviceRow = loadCompanionDevice(val(exchangeResponse.DEVICE.id));
            expect(deviceRow.token_prefix).toBe(exchangeResponse.DEVICE.tokenPrefix, serializeJSON(deviceRow));
            expect(deviceRow.token_hash).notToBe(exchangeResponse.TOKEN, serializeJSON(deviceRow));
            expect(len(trim(deviceRow.token_hash))).toBe(64, serializeJSON(deviceRow));
            expect(deviceRow.device_uuid).toBe("test-device-" & variables.sessionApiUser.userId, serializeJSON(deviceRow));

            resolved = variables.companionAuthService.resolveBearerToken("Bearer " & exchangeResponse.TOKEN, "companion:current");
            expect(resolved.SUCCESS).toBeTrue(serializeJSON(resolved));
            expect(resolved.userId).toBe(variables.sessionApiUser.userId, serializeJSON(resolved));
            expect(resolved.companionDeviceId).toBe(val(exchangeResponse.DEVICE.id), serializeJSON(resolved));

            listResponse = sessionApi.getJson("/api/v1/companionAuth.cfc?method=handle&action=listDevices&returnFormat=json");
            expect(listResponse.SUCCESS).toBeTrue(serializeJSON(listResponse));
            expect(arrayLen(listResponse.DEVICES)).toBe(1, serializeJSON(listResponse));
            expect(structKeyExists(listResponse.DEVICES[1], "tokenHash")).toBeFalse(serializeJSON(listResponse.DEVICES[1]));

            revokeResponse = sessionApi.postJson("/api/v1/companionAuth.cfc?method=handle&action=revokeDevice&returnFormat=json", {
              deviceId = val(exchangeResponse.DEVICE.id),
              reason = "test revoke"
            });
            expect(revokeResponse.SUCCESS).toBeTrue(serializeJSON(revokeResponse));

            revokedResolve = variables.companionAuthService.resolveBearerToken("Bearer " & exchangeResponse.TOKEN, "companion:current");
            expect(revokedResolve.SUCCESS).toBeFalse(serializeJSON(revokedResolve));
            expect(revokedResolve.ERROR).toBe("TOKEN_REVOKED", serializeJSON(revokedResolve));
          } finally {
            cleanupCompanionAuthRows(variables.sessionApiUser.userId);
          }
        });

        it("revokes the current companion token through bearer auth", function() {
          var pairingResponse = variables.companionAuthService.createPairingCode(variables.sessionApiUser.userId);
          var exchangeResponse = {};
          var revokeCurrentResponse = {};
          var resolved = {};

          try {
            exchangeResponse = variables.companionAuthService.exchangePairingCode(pairingResponse.PAIRING_CODE, {
              deviceUuid = "logout-device-" & variables.sessionApiUser.userId,
              platform = "android",
              appVersion = "1.0.0"
            });
            expect(exchangeResponse.SUCCESS).toBeTrue(serializeJSON(exchangeResponse));

            revokeCurrentResponse = postJsonNoSession(
              "/api/v1/companionAuth.cfc?method=handle&action=revokeCurrent&returnFormat=json",
              { reason = "test app logout" },
              "Bearer " & exchangeResponse.TOKEN
            );
            expect(revokeCurrentResponse.SUCCESS).toBeTrue(serializeJSON(revokeCurrentResponse));

            resolved = variables.companionAuthService.resolveBearerToken("Bearer " & exchangeResponse.TOKEN, "companion:current");
            expect(resolved.SUCCESS).toBeFalse(serializeJSON(resolved));
            expect(resolved.ERROR).toBe("TOKEN_REVOKED", serializeJSON(resolved));
          } finally {
            cleanupCompanionAuthRows(variables.sessionApiUser.userId);
          }
        });

        it("serves current through bearer token auth without returning token secrets", function() {
          var prefix = variables.naming.buildPrefix("companion", "bearer-current");
          var sessionApi = buildSessionApiSupport();
          var localCreated = newCreatedTracker();
          var asset = {};
          var exchangeResponse = {};
          var response = {};
          var responseJson = "";

          try {
            url.testUserId = variables.sessionApiUser.userId;
            asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
            exchangeResponse = issueCompanionToken("bearer-current");

            response = getJsonNoSession(
              "/api/v1/companion.cfc?method=handle&action=current&returnFormat=json",
              "Bearer " & exchangeResponse.TOKEN
            );
            responseJson = serializeJSON(response);

            expect(response.SUCCESS).toBeTrue(responseJson);
            expect(response.success).toBeTrue(responseJson);
            expect(response.AUTH).toBeTrue(responseJson);
            expect(response.HAS_ACTIVE_PLAN).toBeTrue(responseJson);
            expect(response.activeFloatPlan.floatPlanId).toBe(asset.floatPlanId, serializeJSON(response.activeFloatPlan));
            expect(find(exchangeResponse.TOKEN, responseJson)).toBe(0, responseJson);
            expect(findNoCase("token_hash", responseJson)).toBe(0, responseJson);
          } finally {
            cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
            cleanupCompanionAuthRows(variables.sessionApiUser.userId);
          }
        });

        it("records and deduplicates bearer-token companion check-ins through the canonical path", function() {
          var prefix = variables.naming.buildPrefix("companion", "bearer-checkin");
          var sessionApi = buildSessionApiSupport();
          var localCreated = newCreatedTracker();
          var asset = {};
          var exchangeResponse = {};
          var mobileId = buildMobileSubmissionId("bearer-checkin");
          var payload = {};
          var beforeCanonicalCount = 0;
          var response = {};
          var duplicateResponse = {};
          var eventRow = {};
          var responseJson = "";

          try {
            url.testUserId = variables.sessionApiUser.userId;
            asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
            exchangeResponse = issueCompanionToken("bearer-checkin");
            payload = {
              mobileSubmissionId = mobileId,
              floatPlanId = asset.floatPlanId,
              status = "On Track",
              note = "Bearer companion check-in"
            };
            beforeCanonicalCount = countCanonicalCheckinEvents(asset.floatPlanId);

            response = postJsonNoSession(
              "/api/v1/companion.cfc?method=handle&action=checkin&returnFormat=json",
              payload,
              "Bearer " & exchangeResponse.TOKEN
            );
            responseJson = serializeJSON(response);

            expect(response.SUCCESS).toBeTrue(responseJson);
            expect(response.success).toBeTrue(responseJson);
            expect(response.AUTH).toBeTrue(responseJson);
            expect(response.duplicate).toBeFalse(responseJson);
            expect(find(exchangeResponse.TOKEN, responseJson)).toBe(0, responseJson);
            eventRow = loadCompanionEventByMobileId(mobileId);
            expect(eventRow.process_status).toBe("PROCESSED", serializeJSON(eventRow));
            expect(eventRow.canonical_status).toBe("On Track", serializeJSON(eventRow));
            expect(val(eventRow.companion_device_id ?: 0)).toBe(val(exchangeResponse.DEVICE.id), serializeJSON(eventRow));
            expect(countCanonicalCheckinEvents(asset.floatPlanId)).toBe(beforeCanonicalCount + 1);

            duplicateResponse = postJsonNoSession(
              "/api/v1/companion.cfc?method=handle&action=checkin&returnFormat=json",
              payload,
              "Bearer " & exchangeResponse.TOKEN
            );
            expect(duplicateResponse.SUCCESS).toBeTrue(serializeJSON(duplicateResponse));
            expect(duplicateResponse.duplicate).toBeTrue(serializeJSON(duplicateResponse));
            expect(countCompanionEventsByMobileId(mobileId)).toBe(1);
            expect(countCanonicalCheckinEvents(asset.floatPlanId)).toBe(beforeCanonicalCount + 1);
          } finally {
            cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
            deleteCompanionEventsByMobileId(mobileId);
            cleanupCompanionAuthRows(variables.sessionApiUser.userId);
          }
        });

        it("returns focused bearer auth errors for missing, malformed, invalid, revoked, and expired tokens", function() {
          var missingResponse = {};
          var malformedResponse = {};
          var invalidResponse = {};
          var revokedExchange = {};
          var revokedResponse = {};
          var expiredExchange = {};
          var expiredResponse = {};

          try {
            missingResponse = getJsonNoSession("/api/v1/companion.cfc?method=handle&action=current&returnFormat=json");
            expect(missingResponse.SUCCESS).toBeFalse(serializeJSON(missingResponse));
            expect(missingResponse.AUTH).toBeFalse(serializeJSON(missingResponse));
            expect(missingResponse.ERROR).toBe("NOT_LOGGED_IN", serializeJSON(missingResponse));

            malformedResponse = getJsonNoSession(
              "/api/v1/companion.cfc?method=handle&action=current&returnFormat=json",
              "Bearer"
            );
            expect(malformedResponse.SUCCESS).toBeFalse(serializeJSON(malformedResponse));
            expect(malformedResponse.ERROR).toBe("TOKEN_INVALID", serializeJSON(malformedResponse));

            invalidResponse = getJsonNoSession(
              "/api/v1/companion.cfc?method=handle&action=current&returnFormat=json",
              "Bearer fpwc_invalid.notavalidtoken"
            );
            expect(invalidResponse.SUCCESS).toBeFalse(serializeJSON(invalidResponse));
            expect(invalidResponse.ERROR).toBe("TOKEN_INVALID", serializeJSON(invalidResponse));

            revokedExchange = issueCompanionToken("bearer-revoked");
            variables.companionAuthService.revokeDevice(variables.sessionApiUser.userId, val(revokedExchange.DEVICE.id), "test revoked token");
            revokedResponse = getJsonNoSession(
              "/api/v1/companion.cfc?method=handle&action=current&returnFormat=json",
              "Bearer " & revokedExchange.TOKEN
            );
            expect(revokedResponse.SUCCESS).toBeFalse(serializeJSON(revokedResponse));
            expect(revokedResponse.ERROR).toBe("TOKEN_REVOKED", serializeJSON(revokedResponse));

            expiredExchange = issueCompanionToken("bearer-expired");
            expireCompanionDevice(val(expiredExchange.DEVICE.id));
            expiredResponse = getJsonNoSession(
              "/api/v1/companion.cfc?method=handle&action=current&returnFormat=json",
              "Bearer " & expiredExchange.TOKEN
            );
            expect(expiredResponse.SUCCESS).toBeFalse(serializeJSON(expiredResponse));
            expect(expiredResponse.ERROR).toBe("TOKEN_EXPIRED", serializeJSON(expiredResponse));
          } finally {
            cleanupCompanionAuthRows(variables.sessionApiUser.userId);
          }
        });

        it("denies bearer scope mismatch and non-approved companion actions", function() {
          var currentOnlyExchange = {};
          var scopeDeniedResponse = {};
          var invalidActionResponse = {};

          try {
            currentOnlyExchange = issueCompanionToken("scope-current-only", variables.sessionApiUser.userId, "companion:current");

            scopeDeniedResponse = postJsonNoSession(
              "/api/v1/companion.cfc?method=handle&action=checkin&returnFormat=json",
              {
                mobileSubmissionId = buildMobileSubmissionId("scope-denied"),
                floatPlanId = 1,
                status = "On Track"
              },
              "Bearer " & currentOnlyExchange.TOKEN
            );
            expect(scopeDeniedResponse.SUCCESS).toBeFalse(serializeJSON(scopeDeniedResponse));
            expect(scopeDeniedResponse.AUTH).toBeFalse(serializeJSON(scopeDeniedResponse));
            expect(scopeDeniedResponse.ERROR).toBe("COMPANION_SCOPE_DENIED", serializeJSON(scopeDeniedResponse));

            invalidActionResponse = getJsonNoSession(
              "/api/v1/companion.cfc?method=handle&action=listDevices&returnFormat=json",
              "Bearer " & currentOnlyExchange.TOKEN
            );
            expect(invalidActionResponse.SUCCESS).toBeFalse(serializeJSON(invalidActionResponse));
            expect(invalidActionResponse.AUTH).toBeFalse(serializeJSON(invalidActionResponse));
            expect(invalidActionResponse.ERROR).toBe("COMPANION_SCOPE_DENIED", serializeJSON(invalidActionResponse));
          } finally {
            cleanupCompanionAuthRows(variables.sessionApiUser.userId);
          }
        });

        it("rejects bearer-token check-in for another user's active float plan", function() {
          var prefix = variables.naming.buildPrefix("companion", "bearer-cross-user");
          var sessionApi = buildSessionApiSupport();
          var tokenUserCreated = newCreatedTracker();
          var otherUser = {};
          var otherApi = {};
          var otherCreated = newCreatedTracker();
          var tokenUserAsset = {};
          var otherAsset = {};
          var exchangeResponse = {};
          var mobileId = buildMobileSubmissionId("bearer-cross-user");
          var response = {};

          try {
            url.testUserId = variables.sessionApiUser.userId;
            tokenUserAsset = createActivatedScheduledTrip(sessionApi, prefix & "-token-user", tokenUserCreated);
            exchangeResponse = issueCompanionToken("bearer-cross-user");

            otherUser = createDisposableApiUser("other");
            otherApi = buildApiSupportForUser(otherUser);
            url.testUserId = otherUser.userId;
            otherAsset = createActivatedScheduledTrip(otherApi, prefix & "-other-user", otherCreated);
            url.testUserId = variables.sessionApiUser.userId;

            response = postJsonNoSession(
              "/api/v1/companion.cfc?method=handle&action=checkin&returnFormat=json",
              {
                mobileSubmissionId = mobileId,
                floatPlanId = otherAsset.floatPlanId,
                status = "On Track"
              },
              "Bearer " & exchangeResponse.TOKEN
            );

            expect(response.SUCCESS).toBeFalse(serializeJSON(response));
            expect(response.ERROR).toBe("ACTIVE_PLAN_MISMATCH", serializeJSON(response));
            expect(countCompanionEventsByMobileId(mobileId)).toBe(0);
            expect(loadPlanStatus(tokenUserAsset.floatPlanId)).toBe("ACTIVE");
          } finally {
            url.testUserId = variables.sessionApiUser.userId;
            cleanupRouteLinkedAssetsForApi(sessionApi, tokenUserCreated);
            if (isObject(otherApi)) {
              if (isStruct(otherUser) AND structKeyExists(otherUser, "userId") AND val(otherUser.userId) GT 0) {
                url.testUserId = otherUser.userId;
              }
              cleanupRouteLinkedAssetsForApi(otherApi, otherCreated);
            }
            url.testUserId = variables.sessionApiUser.userId;
            deleteCompanionEventsByMobileId(mobileId);
            cleanupCompanionAuthRows(variables.sessionApiUser.userId);
            cleanupDisposableApiUser(otherUser);
          }
        });

        it("rejects companion check-in when there is no active route-backed trip", function() {
          var sessionApi = buildSessionApiSupport();
          var cleanupSupport = new fpw.tests.support.FpwCleanupSupport().init(sessionApi);
          var mobileId = buildMobileSubmissionId("no-active");
          var response = {};

          try {
            cleanupSupport.cleanupCurrentRouteFloatPlanGroup(variables.sessionApiUser.userId);
            response = postCompanionCheckinWithApi(sessionApi, {
              mobileSubmissionId = mobileId,
              floatPlanId = 99999999,
              status = "On Track",
              note = "No active trip should reject this check-in."
            });

            expect(response.SUCCESS).toBeFalse(serializeJSON(response));
            expect(response.success).toBeFalse(serializeJSON(response));
            expect(response.AUTH).toBeTrue(serializeJSON(response));
            expect(response.ERROR).toBe("NO_ACTIVE_PLAN", serializeJSON(response));
            expect(countCompanionEventsByMobileId(mobileId)).toBe(0);
          } finally {
            deleteCompanionEventsByMobileId(mobileId);
          }
        });

        it("records an On Track companion check-in with GPS and returns duplicate retries without duplicate canonical side effects", function() {
          var prefix = variables.naming.buildPrefix("companion", "checkin-gps");
          var sessionApi = buildSessionApiSupport();
          var localCreated = newCreatedTracker();
          var asset = {};
          var mobileId = buildMobileSubmissionId("gps");
          var payload = {};
          var beforeCanonicalCount = 0;
          var response = {};
          var duplicateResponse = {};
          var eventRow = {};

          try {
            url.testUserId = variables.sessionApiUser.userId;
            asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
            payload = {
              mobileSubmissionId = mobileId,
              floatPlanId = asset.floatPlanId,
              status = "On Track",
              note = "Companion GPS check-in",
              checkinContext = "",
              location = {
                latitude = 29.1234567,
                longitude = -83.1234567,
                accuracyMeters = 12.5,
                altitudeMeters = 1.2,
                speedKnots = 7.4,
                headingDegrees = 145,
                capturedAtUtc = "2026-05-04T16:30:00Z"
              },
              device = {
                deviceUuid = "device-" & mobileId,
                platform = "ios",
                appVersion = "1.0.0"
              },
              offlineCreatedAtUtc = "2026-05-04T16:29:30Z"
            };
            beforeCanonicalCount = countCanonicalCheckinEvents(asset.floatPlanId);

            response = postCompanionCheckinWithApi(sessionApi, payload);

            expect(response.SUCCESS).toBeTrue(serializeJSON(response));
            expect(response.success).toBeTrue(serializeJSON(response));
            expect(response.AUTH).toBeTrue(serializeJSON(response));
            expect(response.duplicate).toBeFalse(serializeJSON(response));
            expect(val(response.eventId ?: 0)).toBeGT(0, serializeJSON(response));
            expect(structKeyExists(response, "companion")).toBeTrue(serializeJSON(response));
            expect(response.companion.SUCCESS).toBeTrue(serializeJSON(response.companion));

            eventRow = loadCompanionEventByMobileId(mobileId);
            expect(eventRow.process_status).toBe("PROCESSED", serializeJSON(eventRow));
            expect(eventRow.event_type).toBe("CHECKIN", serializeJSON(eventRow));
            expect(eventRow.canonical_status).toBe("On Track", serializeJSON(eventRow));
            expect(val(eventRow.floatplan_id)).toBe(asset.floatPlanId, serializeJSON(eventRow));
            expect(val(eventRow.route_instance_id)).toBeGT(0, serializeJSON(eventRow));
            expect(val(eventRow.leg_order)).toBeGT(0, serializeJSON(eventRow));
            expect(numberFormat(val(eventRow.latitude), "0.0000000")).toBe("29.1234567", serializeJSON(eventRow));
            expect(numberFormat(val(eventRow.longitude), "0.0000000")).toBe("-83.1234567", serializeJSON(eventRow));
            expect(numberFormat(val(eventRow.gps_accuracy_meters), "0.0")).toBe("12.5", serializeJSON(eventRow));
            expect(val(eventRow.companion_device_id ?: 0)).toBe(0, serializeJSON(eventRow));
            expect(eventRow.device_platform).toBe("ios", serializeJSON(eventRow));
            expect(countCanonicalCheckinEvents(asset.floatPlanId)).toBe(beforeCanonicalCount + 1);

            duplicateResponse = postCompanionCheckinWithApi(sessionApi, payload);
            expect(duplicateResponse.SUCCESS).toBeTrue(serializeJSON(duplicateResponse));
            expect(duplicateResponse.duplicate).toBeTrue(serializeJSON(duplicateResponse));
            expect(val(duplicateResponse.eventId ?: 0)).toBe(val(response.eventId ?: 0), serializeJSON(duplicateResponse));
            expect(countCompanionEventsByMobileId(mobileId)).toBe(1);
            expect(countCanonicalCheckinEvents(asset.floatPlanId)).toBe(beforeCanonicalCount + 1);
          } finally {
            cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
            deleteCompanionEventsByMobileId(mobileId);
          }
        });

        it("submits companion check-in through the internal canonical handoff without session headers", function() {
          var prefix = variables.naming.buildPrefix("companion", "internal-handoff");
          var sessionApi = buildSessionApiSupport();
          var localCreated = newCreatedTracker();
          var asset = {};
          var mobileId = buildMobileSubmissionId("internal-handoff");
          var payload = {};
          var beforeCanonicalCount = 0;
          var response = {};
          var eventRow = {};
          var checkinService = new fpw.api.v1.CompanionCheckinService().init("fpw");

          try {
            url.testUserId = variables.sessionApiUser.userId;
            asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
            payload = {
              mobileSubmissionId = mobileId,
              floatPlanId = asset.floatPlanId,
              status = "On Track",
              note = "Companion internal canonical handoff check-in"
            };
            beforeCanonicalCount = countCanonicalCheckinEvents(asset.floatPlanId);

            response = checkinService.submitCheckin(variables.sessionApiUser.userId, payload, {
              baseUrl = "http://localhost:4200/fpw",
              cookieHeader = "",
              testUserIdHeader = ""
            });

            expect(response.SUCCESS).toBeTrue(serializeJSON(response));
            expect(response.success).toBeTrue(serializeJSON(response));
            expect(response.AUTH).toBeTrue(serializeJSON(response));
            expect(response.duplicate).toBeFalse(serializeJSON(response));
            expect(val(response.eventId ?: 0)).toBeGT(0, serializeJSON(response));
            expect(structKeyExists(response, "companion")).toBeTrue(serializeJSON(response));

            eventRow = loadCompanionEventByMobileId(mobileId);
            expect(eventRow.process_status).toBe("PROCESSED", serializeJSON(eventRow));
            expect(eventRow.canonical_status).toBe("On Track", serializeJSON(eventRow));
            expect(val(eventRow.floatplan_id)).toBe(asset.floatPlanId, serializeJSON(eventRow));
            expect(countCanonicalCheckinEvents(asset.floatPlanId)).toBe(beforeCanonicalCount + 1);
          } finally {
            cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
            deleteCompanionEventsByMobileId(mobileId);
          }
        });

        it("rejects invalid GPS before creating a companion event or canonical check-in", function() {
          var sessionApi = buildSessionApiSupport();
          var mobileId = buildMobileSubmissionId("invalid-gps");
          var response = {};

          try {
            response = postCompanionCheckinWithApi(sessionApi, {
              mobileSubmissionId = mobileId,
              floatPlanId = 1,
              status = "On Track",
              location = {
                latitude = 120,
                longitude = -83.1234567
              }
            });

            expect(response.SUCCESS).toBeFalse(serializeJSON(response));
            expect(response.ERROR).toBe("INVALID_LOCATION", serializeJSON(response));
            expect(countCompanionEventsByMobileId(mobileId)).toBe(0);
          } finally {
            deleteCompanionEventsByMobileId(mobileId);
          }
        });

        it("rejects a float plan id that is not the authenticated user's active plan", function() {
          var prefix = variables.naming.buildPrefix("companion", "wrong-plan");
          var sessionApi = buildSessionApiSupport();
          var localCreated = newCreatedTracker();
          var asset = {};
          var mobileId = buildMobileSubmissionId("wrong-plan");
          var response = {};

          try {
            url.testUserId = variables.sessionApiUser.userId;
            asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
            response = postCompanionCheckinWithApi(sessionApi, {
              mobileSubmissionId = mobileId,
              floatPlanId = asset.floatPlanId + 999999,
              status = "On Track"
            });

            expect(response.SUCCESS).toBeFalse(serializeJSON(response));
            expect(response.ERROR).toBe("ACTIVE_PLAN_MISMATCH", serializeJSON(response));
            expect(countCompanionEventsByMobileId(mobileId)).toBe(0);
          } finally {
            cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
            deleteCompanionEventsByMobileId(mobileId);
          }
        });

        it("submits Secure for the Night through the canonical check-in path and refreshes the secure state", function() {
          var prefix = variables.naming.buildPrefix("companion", "secure-night");
          var sessionApi = buildSessionApiSupport();
          var localCreated = newCreatedTracker();
          var asset = {};
          var onTrackId = buildMobileSubmissionId("secure-start");
          var secureId = buildMobileSubmissionId("secure");
          var startResponse = {};
          var secureResponse = {};
          var secureEvent = {};

          try {
            url.testUserId = variables.sessionApiUser.userId;
            asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
            startResponse = postCompanionCheckinWithApi(sessionApi, {
              mobileSubmissionId = onTrackId,
              floatPlanId = asset.floatPlanId,
              status = "On Track"
            });
            expect(startResponse.SUCCESS).toBeTrue(serializeJSON(startResponse));

            secureResponse = postCompanionCheckinWithApi(sessionApi, {
              mobileSubmissionId = secureId,
              floatPlanId = asset.floatPlanId,
              status = "Secure for the Night"
            });

            expect(secureResponse.SUCCESS).toBeTrue(serializeJSON(secureResponse));
            expect(secureResponse.duplicate).toBeFalse(serializeJSON(secureResponse));
            expect(secureResponse.companion.monitoring.secureForNight).toBeTrue(serializeJSON(secureResponse.companion.monitoring));
            secureEvent = loadCompanionEventByMobileId(secureId);
            expect(secureEvent.process_status).toBe("PROCESSED", serializeJSON(secureEvent));
            expect(secureEvent.canonical_status).toBe("Secure for the Night", serializeJSON(secureEvent));
            expect(secureEvent.checkin_context).toBe("overnight", serializeJSON(secureEvent));
          } finally {
            cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
            deleteCompanionEventsByMobileId(onTrackId);
            deleteCompanionEventsByMobileId(secureId);
          }
        });

        it("submits Delayed through canonical check-in behavior without mutating manual delay minutes", function() {
          var prefix = variables.naming.buildPrefix("companion", "delayed");
          var sessionApi = buildSessionApiSupport();
          var localCreated = newCreatedTracker();
          var asset = {};
          var onTrackId = buildMobileSubmissionId("delayed-start");
          var delayedId = buildMobileSubmissionId("delayed");
          var startResponse = {};
          var beforeDelayMinutes = 0;
          var delayedResponse = {};
          var delayedEvent = {};
          var activeCruiseModel = {};

          try {
            url.testUserId = variables.sessionApiUser.userId;
            asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
            startResponse = postCompanionCheckinWithApi(sessionApi, {
              mobileSubmissionId = onTrackId,
              floatPlanId = asset.floatPlanId,
              status = "On Track"
            });
            expect(startResponse.SUCCESS).toBeTrue(serializeJSON(startResponse));
            beforeDelayMinutes = getManualDelayMinutesTotal(asset.floatPlanId);

            delayedResponse = postCompanionCheckinWithApi(sessionApi, {
              mobileSubmissionId = delayedId,
              floatPlanId = asset.floatPlanId,
              status = "Delayed",
              note = "Traffic delay"
            });

            expect(delayedResponse.SUCCESS).toBeTrue(serializeJSON(delayedResponse));
            expect(getManualDelayMinutesTotal(asset.floatPlanId)).toBe(beforeDelayMinutes);
            expect(findOpenActivitySegmentType(asset.floatPlanId)).toBe("PAUSED_DELAYED");
            activeCruiseModel = variables.activeCruiseViewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);
            expect(activeCruiseModel.success).toBeTrue(serializeJSON(activeCruiseModel));
            expect(activeCruiseModel.motionState).toBe("paused_delayed", serializeJSON(activeCruiseModel));
            expect(activeCruiseModel.tripState).toBe("paused_delayed", serializeJSON(activeCruiseModel));
            expect(activeCruiseModel.hero.status).toBe("Delayed", serializeJSON(activeCruiseModel.hero));
            delayedEvent = loadCompanionEventByMobileId(delayedId);
            expect(delayedEvent.process_status).toBe("PROCESSED", serializeJSON(delayedEvent));
            expect(delayedEvent.canonical_status).toBe("Delayed", serializeJSON(delayedEvent));
          } finally {
            cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
            deleteCompanionEventsByMobileId(onTrackId);
            deleteCompanionEventsByMobileId(delayedId);
          }
        });

        it("resumes underway when On Track follows a companion Delayed pause", function() {
          var prefix = variables.naming.buildPrefix("companion", "delayed-resume");
          var sessionApi = buildSessionApiSupport();
          var localCreated = newCreatedTracker();
          var asset = {};
          var onTrackId = buildMobileSubmissionId("resume-start");
          var delayedId = buildMobileSubmissionId("resume-delayed");
          var resumeId = buildMobileSubmissionId("resume-on-track");
          var startResponse = {};
          var delayedResponse = {};
          var resumeResponse = {};
          var activeCruiseModel = {};

          try {
            url.testUserId = variables.sessionApiUser.userId;
            asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
            startResponse = postCompanionCheckinWithApi(sessionApi, {
              mobileSubmissionId = onTrackId,
              floatPlanId = asset.floatPlanId,
              status = "On Track"
            });
            delayedResponse = postCompanionCheckinWithApi(sessionApi, {
              mobileSubmissionId = delayedId,
              floatPlanId = asset.floatPlanId,
              status = "Delayed"
            });
            resumeResponse = postCompanionCheckinWithApi(sessionApi, {
              mobileSubmissionId = resumeId,
              floatPlanId = asset.floatPlanId,
              status = "On Track"
            });
            activeCruiseModel = variables.activeCruiseViewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);

            expect(startResponse.SUCCESS).toBeTrue(serializeJSON(startResponse));
            expect(delayedResponse.SUCCESS).toBeTrue(serializeJSON(delayedResponse));
            expect(resumeResponse.SUCCESS).toBeTrue(serializeJSON(resumeResponse));
            expect(findOpenActivitySegmentType(asset.floatPlanId)).toBe("UNDERWAY");
            expect(activeCruiseModel.success).toBeTrue(serializeJSON(activeCruiseModel));
            expect(activeCruiseModel.motionState).toBe("underway", serializeJSON(activeCruiseModel));
            expect(activeCruiseModel.tripState).toBe("underway", serializeJSON(activeCruiseModel));
          } finally {
            cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
            deleteCompanionEventsByMobileId(onTrackId);
            deleteCompanionEventsByMobileId(delayedId);
            deleteCompanionEventsByMobileId(resumeId);
          }
        });

        it("moves from companion Delayed pause to Secure for the Night without preserving delayed as the open segment", function() {
          var prefix = variables.naming.buildPrefix("companion", "delayed-secure");
          var sessionApi = buildSessionApiSupport();
          var localCreated = newCreatedTracker();
          var asset = {};
          var onTrackId = buildMobileSubmissionId("secure-start");
          var delayedId = buildMobileSubmissionId("secure-delayed");
          var secureId = buildMobileSubmissionId("secure-after-delayed");
          var startResponse = {};
          var delayedResponse = {};
          var secureResponse = {};
          var activeCruiseModel = {};

          try {
            url.testUserId = variables.sessionApiUser.userId;
            asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
            startResponse = postCompanionCheckinWithApi(sessionApi, {
              mobileSubmissionId = onTrackId,
              floatPlanId = asset.floatPlanId,
              status = "On Track"
            });
            delayedResponse = postCompanionCheckinWithApi(sessionApi, {
              mobileSubmissionId = delayedId,
              floatPlanId = asset.floatPlanId,
              status = "Delayed"
            });
            secureResponse = postCompanionCheckinWithApi(sessionApi, {
              mobileSubmissionId = secureId,
              floatPlanId = asset.floatPlanId,
              status = "Secure for the Night"
            });
            activeCruiseModel = variables.activeCruiseViewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);

            expect(startResponse.SUCCESS).toBeTrue(serializeJSON(startResponse));
            expect(delayedResponse.SUCCESS).toBeTrue(serializeJSON(delayedResponse));
            expect(secureResponse.SUCCESS).toBeTrue(serializeJSON(secureResponse));
            expect(findOpenActivitySegmentType(asset.floatPlanId)).toBe("PAUSED_SECURE_FOR_NIGHT");
            expect(activeCruiseModel.success).toBeTrue(serializeJSON(activeCruiseModel));
            expect(activeCruiseModel.motionState).toBe("paused_overnight", serializeJSON(activeCruiseModel));
            expect(activeCruiseModel.tripState).toBe("paused_overnight", serializeJSON(activeCruiseModel));
          } finally {
            cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
            deleteCompanionEventsByMobileId(onTrackId);
            deleteCompanionEventsByMobileId(delayedId);
            deleteCompanionEventsByMobileId(secureId);
          }
        });

        it("submits Changed Plan only through the canonical check-in behavior", function() {
          var prefix = variables.naming.buildPrefix("companion", "changed-plan");
          var sessionApi = buildSessionApiSupport();
          var localCreated = newCreatedTracker();
          var asset = {};
          var onTrackId = buildMobileSubmissionId("changed-start");
          var changedId = buildMobileSubmissionId("changed");
          var startResponse = {};
          var response = {};
          var eventRow = {};

          try {
            url.testUserId = variables.sessionApiUser.userId;
            asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
            startResponse = postCompanionCheckinWithApi(sessionApi, {
              mobileSubmissionId = onTrackId,
              floatPlanId = asset.floatPlanId,
              status = "On Track"
            });
            expect(startResponse.SUCCESS).toBeTrue(serializeJSON(startResponse));

            response = postCompanionCheckinWithApi(sessionApi, {
              mobileSubmissionId = changedId,
              floatPlanId = asset.floatPlanId,
              status = "Changed Plan",
              note = "Captain reports plan changed"
            });

            expect(response.SUCCESS).toBeTrue(serializeJSON(response));
            eventRow = loadCompanionEventByMobileId(changedId);
            expect(eventRow.process_status).toBe("PROCESSED", serializeJSON(eventRow));
            expect(eventRow.canonical_status).toBe("Changed Plan", serializeJSON(eventRow));
          } finally {
            cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
            deleteCompanionEventsByMobileId(onTrackId);
            deleteCompanionEventsByMobileId(changedId);
          }
        });

        it("submits Assistance Needed through the canonical path without requiring a real recipient in this notification-safe setup", function() {
          var prefix = variables.naming.buildPrefix("companion", "assistance");
          var sessionApi = buildSessionApiSupport();
          var localCreated = newCreatedTracker();
          var asset = {};
          var assistanceId = buildMobileSubmissionId("assistance");
          var response = {};
          var eventRow = {};

          try {
            url.testUserId = variables.sessionApiUser.userId;
            asset = createActiveMonitoredTripWithoutContacts(sessionApi, prefix, localCreated);
            response = postCompanionCheckinWithApi(sessionApi, {
              mobileSubmissionId = assistanceId,
              floatPlanId = asset.floatPlanId,
              status = "Assistance Needed",
              note = "Notification-safe test check-in with no attached contacts"
            });

            expect(response.SUCCESS).toBeTrue(serializeJSON(response));
            eventRow = loadCompanionEventByMobileId(assistanceId);
            expect(eventRow.process_status).toBe("PROCESSED", serializeJSON(eventRow));
            expect(eventRow.canonical_status).toBe("Assistance Needed", serializeJSON(eventRow));
            expect(loadMonitoringRow(asset.floatPlanId).last_checkin_status).toBe("NEED_ATTENTION");
          } finally {
            cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
            deleteCompanionEventsByMobileId(assistanceId);
          }
        });

        it("rejects Arrived without invoking the final close flow", function() {
          var prefix = variables.naming.buildPrefix("companion", "arrived");
          var sessionApi = buildSessionApiSupport();
          var localCreated = newCreatedTracker();
          var asset = {};
          var mobileId = buildMobileSubmissionId("arrived");
          var response = {};

          try {
            url.testUserId = variables.sessionApiUser.userId;
            asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
            response = postCompanionCheckinWithApi(sessionApi, {
              mobileSubmissionId = mobileId,
              floatPlanId = asset.floatPlanId,
              status = "Arrived"
            });

            expect(response.SUCCESS).toBeFalse(serializeJSON(response));
            expect(response.ERROR).toBe("UNSUPPORTED_STATUS", serializeJSON(response));
            expect(countCompanionEventsByMobileId(mobileId)).toBe(0);
            expect(loadPlanStatus(asset.floatPlanId)).toBe("ACTIVE");
          } finally {
            cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
            deleteCompanionEventsByMobileId(mobileId);
          }
        });
      });
  }

  private void function assertMobileCheckInAction(
    required struct action,
    required string expectedKey,
    required string expectedStatus,
    required string expectedCheckinContext,
    required numeric expectedFloatPlanId
  ) {
    expect(arguments.action.key).toBe(arguments.expectedKey, serializeJSON(arguments.action));
    expect(arguments.action.label).toBe(arguments.expectedStatus, serializeJSON(arguments.action));
    expect(arguments.action.endpoint).toBe("/fpw/api/v1/companion.cfc?method=handle&action=checkin&returnFormat=json", serializeJSON(arguments.action));
    expect(arguments.action.method).toBe("POST", serializeJSON(arguments.action));
    expect(arguments.action.requiresMobileSubmissionId).toBeTrue(serializeJSON(arguments.action));
    expect(arguments.action.supportsLocation).toBeTrue(serializeJSON(arguments.action));
    expect(arguments.action.supportsDeviceMetadata).toBeTrue(serializeJSON(arguments.action));
    expect(arguments.action.supportsOfflineCreatedAt).toBeTrue(serializeJSON(arguments.action));
    expect(structKeyExists(arguments.action, "enabled")).toBeTrue(serializeJSON(arguments.action));
    expect(structKeyExists(arguments.action, "disabledReason")).toBeTrue(serializeJSON(arguments.action));
    expect(structKeyExists(arguments.action, "requiresConfirm")).toBeTrue(serializeJSON(arguments.action));
    expect(structKeyExists(arguments.action, "confirmMessage")).toBeTrue(serializeJSON(arguments.action));
    expect(arguments.action.payload.mobileSubmissionId).toBe("", serializeJSON(arguments.action.payload));
    expect(arguments.action.payload.floatPlanId).toBe(arguments.expectedFloatPlanId, serializeJSON(arguments.action.payload));
    expect(arguments.action.payload.status).toBe(arguments.expectedStatus, serializeJSON(arguments.action.payload));
    expect(arguments.action.payload.note).toBe("", serializeJSON(arguments.action.payload));
    expect(arguments.action.payload.checkinContext).toBe(arguments.expectedCheckinContext, serializeJSON(arguments.action.payload));
    expect(findNoCase('"location":null', serializeJSON(arguments.action.payload))).toBeGT(0, serializeJSON(arguments.action.payload));
    expect(findNoCase('"device":null', serializeJSON(arguments.action.payload))).toBeGT(0, serializeJSON(arguments.action.payload));
    expect(arguments.action.payload.offlineCreatedAtUtc).toBe("", serializeJSON(arguments.action.payload));
  }

  private any function buildSessionApiSupport() {
    return new fpw.tests.support.FpwApiSupport().init(
      baseUrl = variables.api.getBaseUrl(),
      authEmail = variables.sessionApiUser.email,
      authPassword = variables.sessionApiUser.password
    );
  }

  private any function buildApiSupportForUser(required struct apiUser) {
    return new fpw.tests.support.FpwApiSupport().init(
      baseUrl = variables.api.getBaseUrl(),
      authEmail = arguments.apiUser.email,
      authPassword = arguments.apiUser.password
    );
  }

  private struct function newCreatedTracker() {
    return { vesselIds = [], routeCodes = [], floatPlanIds = [], contactIds = [] };
  }

  private struct function createDisposableApiUser(required string label) {
    var signupApi = new fpw.tests.support.FpwApiSupport().init(
      baseUrl = variables.api.getBaseUrl()
    );
    var uniqueEmail = "fpw-companion-" & arguments.label & "-" & replace(createUUID(), "-", "", "all") & "@example.com";
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

  private void function cleanupDisposableApiUser(required any apiUser) {
    var userId = 0;

    if (!isStruct(arguments.apiUser)) {
      return;
    }

    userId = val(arguments.apiUser.userId ?: 0);
    if (userId LTE 0) {
      return;
    }

    cleanupCompanionAuthRows(userId);

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

  private void function cleanupSessionApiUser() {
    var userId = 0;

    if (!structKeyExists(variables, "sessionApiUser") || !isStruct(variables.sessionApiUser)) {
      return;
    }

    userId = val(variables.sessionApiUser.userId ?: 0);
    if (userId LTE 0) {
      return;
    }

    cleanupCompanionAuthRows(userId);

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

    private void function cleanupCompanionAuthRows(required numeric userId) {
      queryExecute(
        "DELETE FROM companion_pairing_codes WHERE user_id = :userId",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
      queryExecute(
        "DELETE FROM companion_devices WHERE user_id = :userId",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
    }

    private struct function issueCompanionToken(required string label, numeric userId=0, string scopes="companion:current,companion:checkin") {
      var targetUserId = arguments.userId GT 0 ? arguments.userId : variables.sessionApiUser.userId;
      var pairingResponse = variables.companionAuthService.createPairingCode(targetUserId);
      var exchangeResponse = {};

      expect(pairingResponse.SUCCESS).toBeTrue(serializeJSON(pairingResponse));
      exchangeResponse = variables.companionAuthService.exchangePairingCode(pairingResponse.PAIRING_CODE, {
        deviceUuid = left("bearer-" & arguments.label & "-" & targetUserId, 128),
        deviceName = "Bearer Test Device",
        platform = "ios",
        appVersion = "1.0.0"
      });
      expect(exchangeResponse.SUCCESS).toBeTrue(serializeJSON(exchangeResponse));
      expect(len(trim(exchangeResponse.TOKEN))).toBeGT(40, serializeJSON(exchangeResponse));

      if (arguments.scopes NEQ "companion:current,companion:checkin") {
        updateCompanionDeviceScopes(val(exchangeResponse.DEVICE.id), arguments.scopes);
      }

      return exchangeResponse;
    }

    private void function updateCompanionDeviceScopes(required numeric deviceId, required string scopes) {
      queryExecute(
        "UPDATE companion_devices
         SET scopes = :scopes,
             updated_utc = UTC_TIMESTAMP()
         WHERE id = :deviceId",
        {
          deviceId = { value = arguments.deviceId, cfsqltype = "cf_sql_bigint" },
          scopes = { value = arguments.scopes, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = "fpw" }
      );
    }

    private void function expireCompanionDevice(required numeric deviceId) {
      queryExecute(
        "UPDATE companion_devices
         SET expires_at_utc = DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 MINUTE),
             updated_utc = UTC_TIMESTAMP()
         WHERE id = :deviceId",
        {
          deviceId = { value = arguments.deviceId, cfsqltype = "cf_sql_bigint" }
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

    private struct function createActiveMonitoredTripWithoutContacts(required any apiSupport, required string prefix, required struct created) {
      var asset = createRouteLinkedDraftForApi(arguments.apiSupport, arguments.prefix, arguments.created);
      var futureDeparture = dateTimeFormat(dateAdd("h", 3, now()), "yyyy-mm-dd HH:nn:ss");
      var futureReturn = dateTimeFormat(dateAdd("h", 9, now()), "yyyy-mm-dd HH:nn:ss");
      var monitoringResult = {};

      setPlanSchedule(asset.floatPlanId, futureDeparture, futureReturn, "UTC");
      markPlanActive(asset.floatPlanId);
      monitoringResult = variables.monitorService.startMonitoringForFloatPlan(asset.floatPlanId, "active_route");
      ensureSuccess(monitoringResult, "start active route monitoring without contacts");
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

    private struct function postCompanionCheckinWithApi(required any apiSupport, required struct payload) {
      return arguments.apiSupport.postJson("/api/v1/companion.cfc?method=handle&action=checkin&returnFormat=json", arguments.payload);
    }

    private struct function postJsonNoSession(required string path, struct payload={}, string authorizationHeader="") {
      var httpResult = {};
      var fullUrl = buildUrl(arguments.path);
      cfhttp(url = fullUrl, method = "post", result = "httpResult", charset = "utf-8") {
        cfhttpparam(type = "header", name = "Content-Type", value = "application/json");
        if (len(arguments.authorizationHeader)) {
          cfhttpparam(type = "header", name = "Authorization", value = arguments.authorizationHeader);
        }
        cfhttpparam(type = "body", value = serializeJSON(arguments.payload));
      }
      return parseJsonResponse(httpResult);
    }

    private struct function getJsonNoSession(required string path, string authorizationHeader="") {
      var httpResult = {};
      var fullUrl = buildUrl(arguments.path);
      cfhttp(url = fullUrl, method = "get", result = "httpResult", charset = "utf-8") {
        if (len(arguments.authorizationHeader)) {
          cfhttpparam(type = "header", name = "Authorization", value = arguments.authorizationHeader);
        }
      }
      return parseJsonResponse(httpResult);
    }

    private string function buildUrl(required string path) {
      if (left(arguments.path, 1) EQ "/") {
        return variables.api.getBaseUrl() & arguments.path;
      }
      return variables.api.getBaseUrl() & "/" & arguments.path;
    }

    private struct function parseJsonResponse(required struct httpResult) {
      var raw = structKeyExists(arguments.httpResult, "fileContent") ? trim(arguments.httpResult.fileContent) : "";
      if (!len(raw)) {
        return {};
      }
      try {
        return deserializeJSON(raw, false);
      } catch (any parseError) {
        return {
          SUCCESS = false,
          ERROR = "NON_JSON",
          RAW = raw
        };
      }
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
      queryExecute(
        "DELETE FROM floatplan_companion_events WHERE floatplan_id = :floatPlanId",
        {
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
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

    private void function markPlanActive(required numeric floatPlanId) {
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

    private string function buildMobileSubmissionId(required string label) {
      return lCase(left("test-" & arguments.label & "-" & replace(createUUID(), "-", "", "all"), 128));
    }

    private numeric function countCompanionEventsByMobileId(required string mobileSubmissionId) {
      var qCount = queryExecute(
        "SELECT COUNT(*) AS row_count
         FROM floatplan_companion_events
         WHERE mobile_submission_id = :mobileSubmissionId",
        {
          mobileSubmissionId = { value = arguments.mobileSubmissionId, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = "fpw" }
      );
      return val(qCount.row_count[1]);
    }

    private void function deleteCompanionEventsByMobileId(required string mobileSubmissionId) {
      queryExecute(
        "DELETE FROM floatplan_companion_events
         WHERE mobile_submission_id = :mobileSubmissionId",
        {
          mobileSubmissionId = { value = arguments.mobileSubmissionId, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = "fpw" }
      );
    }

    private struct function loadCompanionEventByMobileId(required string mobileSubmissionId) {
      var qRow = queryExecute(
        "SELECT *
         FROM floatplan_companion_events
         WHERE mobile_submission_id = :mobileSubmissionId
         LIMIT 1",
        {
          mobileSubmissionId = { value = arguments.mobileSubmissionId, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = "fpw" }
      );

      if (qRow.recordCount EQ 0) {
        return {};
      }

      return queryRowToStruct(qRow);
    }

    private struct function loadCompanionDevice(required numeric deviceId) {
      var qRow = queryExecute(
        "SELECT *
         FROM companion_devices
         WHERE id = :deviceId
         LIMIT 1",
        {
          deviceId = { value = arguments.deviceId, cfsqltype = "cf_sql_bigint" }
        },
        { datasource = "fpw" }
      );

      if (qRow.recordCount EQ 0) {
        return {};
      }

      return queryRowToStruct(qRow);
    }

    private numeric function countCanonicalCheckinEvents(required numeric floatPlanId) {
      var qCount = queryExecute(
        "SELECT COUNT(*) AS row_count
         FROM floatplan_events
         WHERE floatplan_id = :floatPlanId
           AND event_type = 'CHECKIN_RECEIVED'
           AND source = 'active_cruise_checkin'
           AND voided_at_utc IS NULL",
        {
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
      return val(qCount.row_count[1]);
    }

    private numeric function getManualDelayMinutesTotal(required numeric floatPlanId) {
      var qRow = queryExecute(
        "SELECT COALESCE(manual_delay_minutes_total, 0) AS manual_delay_minutes_total
         FROM floatplans
         WHERE floatplanId = :floatPlanId
         LIMIT 1",
        {
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
      if (qRow.recordCount EQ 0) {
        return 0;
      }
      return val(qRow.manual_delay_minutes_total[1]);
    }

    private string function findOpenActivitySegmentType(required numeric floatPlanId) {
      var qSegment = queryExecute(
        "SELECT segment_type
         FROM floatplan_activity_segments
         WHERE floatplan_id = :floatPlanId
           AND ended_at_utc IS NULL
         ORDER BY started_at_utc DESC, id DESC
         LIMIT 1",
        {
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
      if (qSegment.recordCount EQ 0) {
        return "";
      }
      return uCase(trim(toString(qSegment.segment_type[1])));
    }

    private string function loadPlanStatus(required numeric floatPlanId) {
      var qRow = queryExecute(
        "SELECT `status`
         FROM floatplans
         WHERE floatplanId = :floatPlanId
         LIMIT 1",
        {
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
      if (qRow.recordCount EQ 0) {
        return "";
      }
      return trim(toString(qRow.status[1]));
    }

    private struct function loadMonitoringRow(required numeric floatPlanId) {
      var qRow = queryExecute(
        "SELECT *
         FROM floatplan_monitoring
         WHERE float_plan_id = :floatPlanId
         LIMIT 1",
        {
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
      if (qRow.recordCount EQ 0) {
        return {};
      }
      return queryRowToStruct(qRow);
    }

    private struct function queryRowToStruct(required query qRow) {
      var row = {};
      var columnName = "";
      for (columnName in listToArray(arguments.qRow.columnList)) {
        row[columnName] = isNull(arguments.qRow[columnName][1]) ? "" : arguments.qRow[columnName][1];
      }
      return row;
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
