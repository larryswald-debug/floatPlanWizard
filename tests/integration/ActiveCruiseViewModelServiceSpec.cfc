component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.api = new fpw.tests.support.FpwApiSupport().init(
      authEmail = "detroit@email.com",
      authPassword = "changeIt"
    );
    variables.naming = new fpw.tests.support.FpwNamingSupport();
    variables.viewModelService = new fpw.api.v1.ActiveCruiseViewModelService().init("fpw");
    variables.projectionService = new fpw.api.v1.TripProgressProjectionService().init("fpw");
    variables.activityWriterService = new fpw.api.v1.TripActivityWriterService().init("fpw");
    variables.entitlements = new fpw.api.v1.MemberEntitlementService().init("fpw");
    variables.voyageService = new fpw.api.v1.voyage();
    variables.hadOriginalTestUserId = structKeyExists(url, "testUserId");
    variables.originalTestUserId = variables.hadOriginalTestUserId ? url.testUserId : "";
    variables.sessionApiUser = createSessionApiUser();
    url.testUserId = variables.sessionApiUser.userId;
    variables.activeCruisePremiumEntitlement = variables.entitlements.createAdminCompEntitlement(variables.sessionApiUser.userId);
  }

  function afterAll() {
    queryExecute(
      "DELETE FROM member_entitlements WHERE user_id = :userId",
      {
        userId = { value = variables.sessionApiUser.userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    cleanupSessionApiUser();
    if (variables.hadOriginalTestUserId) {
      url.testUserId = variables.originalTestUserId;
    } else {
      structDelete(url, "testUserId", false);
    }
  }

  function run() {
    describe("Active Cruise V2 backend view model", function() {
      it("returns scheduled state from scheduled_projection for a pre-departure route-backed active plan", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "scheduled");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var model = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
          model = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);

          expect(model.success).toBeTrue(serializeJSON(model));
          expect(model.tripState).toBe("scheduled");
          expect(model.motionState).toBe("scheduled");
          expect(model.displayAuthority.primary).toBe("scheduled_projection");
          expect(model.displayAuthority.routeTimeline).toBe("scheduled_projection");
          expect(model.routeTimeline.available).toBeTrue(serializeJSON(model.routeTimeline));
          expect(model.routeTimeline.authority).toBe("scheduled_projection");
          expect(arrayLen(model.routeTimeline.legs)).toBeGT(0);
          expect(model.actions.checkIn.enabled).toBeTrue(serializeJSON(model.actions.checkIn));
          expect(model.actions.completeLeg.enabled).toBeFalse(serializeJSON(model.actions.completeLeg));
          expect(model.actions.completeLeg.reason).toBe("Complete Current Leg is available after the cruise is underway.");
          expect(model.actions.startNextLeg.enabled).toBeFalse(serializeJSON(model.actions.startNextLeg));
          expect(model.actions.startNextLeg.reason).toBe("Start Next Leg is available after the current leg is completed.");
          expect(findStatusOption(model, "On Track").enabled).toBeTrue();
          expect(findStatusOption(model, "Assistance Needed").enabled).toBeTrue();
          expect(findStatusOption(model, "Delayed").enabled).toBeFalse(serializeJSON(model.checkIn.allowedStatusOptions));
          expect(findStatusOption(model, "Delayed").validationError).toBe("PRE_DEPARTURE_DELAY_REQUIRES_NEW_TIME");
          expect(len(findStatusOption(model, "Delayed").disabledReason)).toBeGT(0);
          expect(findStatusOption(model, "Changed Plan").enabled).toBeFalse(serializeJSON(model.checkIn.allowedStatusOptions));
          expect(findStatusOption(model, "Changed Plan").validationError).toBe("PRE_DEPARTURE_PLAN_CHANGE_REQUIRES_UPDATE");
          expect(findStatusOption(model, "Secure for the Night").enabled).toBeFalse(serializeJSON(model.checkIn.allowedStatusOptions));
          expect(findStatusOption(model, "Secure for the Night").validationError).toBe("PRE_DEPARTURE_SECURE_NOT_ALLOWED");
          expect(hasLegacyRoutePlanAuthority(model)).toBeFalse(serializeJSON(model.displayAuthority));
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("keeps persisted lock details visible without adding operational lock time to scheduled route timeline legs", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "lock-detail");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var model = {};
        var firstLeg = {};
        var cruiseSeconds = 0;
        var lockSeconds = 0;
        var projectedSeconds = 0;

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedLockedScheduledTrip(sessionApi, prefix, localCreated);
          model = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);

          expect(model.success).toBeTrue(serializeJSON(model));
          expect(model.routeTimeline.available).toBeTrue(serializeJSON(model.routeTimeline));
          expect(arrayLen(model.routeTimeline.legs)).toBeGT(0, serializeJSON(model.routeTimeline));

          firstLeg = model.routeTimeline.legs[1];
          expect(structKeyExists(firstLeg, "lockSummary")).toBeTrue(serializeJSON(firstLeg));
          expect(structKeyExists(firstLeg, "locks")).toBeTrue(serializeJSON(firstLeg));
          expect(firstLeg.lockSummary.hasLocks).toBeTrue(serializeJSON(firstLeg.lockSummary));
          expect(firstLeg.lockSummary.lockCount).toBe(2, serializeJSON(firstLeg.lockSummary));
          expect(firstLeg.lockSummary.baseCycleMinutes).toBeGT(0, serializeJSON(firstLeg.lockSummary));
          expect(firstLeg.lockSummary.bestDelayMinutes).toBe(14, serializeJSON(firstLeg.lockSummary));
          expect(firstLeg.lockSummary.typicalDelayMinutes).toBe(20, serializeJSON(firstLeg.lockSummary));
          expect(firstLeg.lockSummary.worstDelayMinutes).toBe(75, serializeJSON(firstLeg.lockSummary));
          expect(firstLeg.lockSummary.operationalLockTimeMinutes).toBe(firstLeg.lockSummary.baseCycleMinutes + firstLeg.lockSummary.typicalDelayMinutes, serializeJSON(firstLeg.lockSummary));
          expect(arrayLen(firstLeg.locks)).toBe(2, serializeJSON(firstLeg.locks));
          expect(firstLeg.locks[1].lockCode).toBe("CHICAGO_LOCK", serializeJSON(firstLeg.locks[1]));
          expect(firstLeg.locks[1].name).toBe("Chicago Harbor Lock", serializeJSON(firstLeg.locks[1]));
          expect(firstLeg.locks[1].waterway).toBe("Chicago River / CAWS", serializeJSON(firstLeg.locks[1]));
          expect(firstLeg.locks[2].lockCode).toBe("OBRIEN_LOCK", serializeJSON(firstLeg.locks[2]));

          cruiseSeconds = round((firstLeg.distanceNm / model.routeTimeline.effectiveSpeedKn) * 3600);
          lockSeconds = round(firstLeg.lockSummary.operationalLockTimeMinutes * 60);
          projectedSeconds = dateDiff("s", parseUtcForTest(firstLeg.departureUtc), parseUtcForTest(firstLeg.etaUtc));
          expect(lockSeconds).toBeGT(0, serializeJSON(firstLeg.lockSummary));
          expect(projectedSeconds).toBe(cruiseSeconds, serializeJSON(firstLeg));
          expect(firstLeg.estimatedDurationSeconds).toBe(cruiseSeconds, serializeJSON(firstLeg));
          expect(firstLeg.remainingDurationSeconds).toBe(firstLeg.estimatedDurationSeconds, serializeJSON(firstLeg));
          expect(len(firstLeg.estimatedDurationLabel)).toBeGT(0, serializeJSON(firstLeg));
          expect(len(firstLeg.remainingDurationLabel)).toBeGT(0, serializeJSON(firstLeg));
          expect(firstLeg.durationAuthority).toBe("scheduled_projection", serializeJSON(firstLeg));
          expect(firstLeg.arrivalSource).toBe("scheduled_projection", serializeJSON(firstLeg));
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("keeps operational lock timing scoped to AC-V2 projection opt-in", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "lock-eta");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var checkinResult = {};
        var asOfUtc = now();
        var defaultProjection = {};
        var lockAwareProjection = {};
        var defaultCurrentLeg = {};
        var lockAwareCurrentLeg = {};
        var lockSeconds = 0;
        var completedResult = {};
        var completedDefaultProjection = {};
        var completedLockAwareProjection = {};
        var completedDefaultLeg = {};
        var completedLockAwareLeg = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedLockedScheduledTrip(sessionApi, prefix, localCreated);
          checkinResult = postActiveCruiseCheckinWithApi(sessionApi, asset.floatPlanId, "On Track");
          expect(isSuccessPayload(checkinResult)).toBeTrue(serializeJSON(checkinResult));

          defaultProjection = variables.projectionService.getProjection(asset.floatPlanId, asOfUtc);
          lockAwareProjection = variables.projectionService.getProjection(asset.floatPlanId, asOfUtc, { "includeOperationalLockTime" = true });
          expect(defaultProjection.routeTimeline.available).toBeTrue(serializeJSON(defaultProjection.routeTimeline));
          expect(lockAwareProjection.routeTimeline.available).toBeTrue(serializeJSON(lockAwareProjection.routeTimeline));

          defaultCurrentLeg = defaultProjection.routeTimeline.legs[1];
          lockAwareCurrentLeg = lockAwareProjection.routeTimeline.legs[1];
          lockSeconds = round(lockAwareCurrentLeg.lockSummary.operationalLockTimeMinutes * 60);
          expect(lockSeconds).toBeGT(0, serializeJSON(lockAwareCurrentLeg.lockSummary));
          expect(dateDiff("s", parseUtcForTest(defaultCurrentLeg.etaUtc), parseUtcForTest(lockAwareCurrentLeg.etaUtc))).toBe(lockSeconds, serializeJSON(lockAwareCurrentLeg));
          expect(defaultCurrentLeg.arrivalSource).toBe("etaProjection.etaUtc", serializeJSON(defaultCurrentLeg));
          expect(lockAwareCurrentLeg.arrivalSource).toBe("etaProjection.etaUtc_plus_operational_lock_time", serializeJSON(lockAwareCurrentLeg));
          expect(arrayLen(lockAwareCurrentLeg.warnings)).toBeGT(0, serializeJSON(lockAwareCurrentLeg));
          expect(findLegWarning(lockAwareCurrentLeg, "LOCK_TIME_NOT_POSITION_AWARE")).toBeTrue(serializeJSON(lockAwareCurrentLeg.warnings));

          completedResult = postCompleteLegWithApi(sessionApi, asset.floatPlanId, lockAwareCurrentLeg.routeLegOrder);
          expect(isSuccessPayload(completedResult)).toBeTrue(serializeJSON(completedResult));
          completedDefaultProjection = variables.projectionService.getProjection(asset.floatPlanId, asOfUtc);
          completedLockAwareProjection = variables.projectionService.getProjection(asset.floatPlanId, asOfUtc, { "includeOperationalLockTime" = true });
          completedDefaultLeg = completedDefaultProjection.routeTimeline.legs[1];
          completedLockAwareLeg = completedLockAwareProjection.routeTimeline.legs[1];
          expect(completedDefaultLeg.isCompleted).toBeTrue(serializeJSON(completedDefaultLeg));
          expect(completedLockAwareLeg.isCompleted).toBeTrue(serializeJSON(completedLockAwareLeg));
          expect(completedLockAwareLeg.etaUtc).toBe(completedDefaultLeg.etaUtc, serializeJSON(completedLockAwareLeg));
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("persists active-trip pace overrides and updates canonical leg ETA projections", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "pace");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var checkinResult = {};
        var invalidResult = {};
        var baselineProjection = {};
        var baselineCompletedNm = 0;
        var baselineCurrentLeg = {};
        var baselineCurrentEtaUtc = "";
        var baselineCurrentRemainingDurationSeconds = 0;
        var baselineFutureLeg = {};
        var baselineFutureArrivalUtc = "";
        var baselineFutureEstimatedDurationSeconds = 0;
        var relaxedResult = {};
        var relaxedModel = {};
        var relaxedInputs = {};
        var relaxedCurrentLeg = {};
        var relaxedFutureLeg = {};
        var activeCruiseHero = {};
        var followBootstrap = {};
        var balancedResult = {};
        var balancedProjection = {};
        var aggressiveResult = {};
        var aggressiveProjection = {};
        var completedResult = {};
        var completedBefore = {};
        var completedAfter = {};
        var staleProjection = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
          seedRouteInputsForPaceTest(asset.floatPlanId, {
            "pace" = "BALANCED",
            "cruising_speed" = 20,
            "vessel_most_efficient_speed_kn" = 8,
            "weather_factor_pct" = 25,
            "fuel_burn_gph" = 10,
            "reserve_pct" = 33,
            "underway_hours_per_day" = 6.5
          });

          checkinResult = postActiveCruiseCheckinWithApi(sessionApi, asset.floatPlanId, "On Track", "pace test");
          expect(isSuccessPayload(checkinResult)).toBeTrue(serializeJSON(checkinResult));
          setActiveLegStartedAtForPaceTest(asset.floatPlanId, dateAdd("n", -30, now()));

          baselineProjection = variables.projectionService.getProjection(asset.floatPlanId, now(), { "includeOperationalLockTime" = true });
          expect(baselineProjection.routeTimeline.available).toBeTrue(serializeJSON(baselineProjection.routeTimeline));
          expect(roundTo2Numeric(baselineProjection.routeTimeline.effectiveSpeedKn)).toBe(20);
          baselineCompletedNm = roundTo2Numeric(baselineProjection.currentLegProgress.completedNm);
          baselineCurrentLeg = findCurrentTimelineLegForTest(baselineProjection.routeTimeline);
          baselineFutureLeg = findFirstFutureTimelineLegForTest(baselineProjection.routeTimeline);
          baselineCurrentEtaUtc = baselineCurrentLeg.etaUtc ?: "";
          baselineCurrentRemainingDurationSeconds = baselineCurrentLeg.remainingDurationSeconds ?: 0;
          baselineFutureArrivalUtc = baselineFutureLeg.etaUtc ?: "";
          baselineFutureEstimatedDurationSeconds = baselineFutureLeg.estimatedDurationSeconds ?: 0;
          expect(baselineCompletedNm).toBeGT(0, serializeJSON(baselineProjection.currentLegProgress));
          expect(len(baselineCurrentEtaUtc)).toBeGT(0, serializeJSON(baselineCurrentLeg));
          expect(baselineCurrentRemainingDurationSeconds).toBeGT(0, serializeJSON(baselineCurrentLeg));
          expect(len(baselineFutureArrivalUtc)).toBeGT(0, serializeJSON(baselineProjection.routeTimeline));
          expect(baselineFutureEstimatedDurationSeconds).toBeGT(0, serializeJSON(baselineFutureLeg));

          invalidResult = postActiveCruisePaceWithApi(sessionApi, asset.floatPlanId, "FAST");
          expect(isSuccessPayload(invalidResult)).toBeFalse(serializeJSON(invalidResult));
          expect(invalidResult.ERROR ?: "").toBe("INVALID_PACE", serializeJSON(invalidResult));

          relaxedResult = postActiveCruisePaceWithApi(sessionApi, asset.floatPlanId, "RELAXED");
          expect(isSuccessPayload(relaxedResult)).toBeTrue(serializeJSON(relaxedResult));
          relaxedInputs = loadRouteInputsForFloatPlan(asset.floatPlanId);
          expect(relaxedInputs.pace).toBe("BALANCED", serializeJSON(relaxedInputs));
          expect(relaxedInputs.active_trip_pace).toBe("RELAXED", serializeJSON(relaxedInputs));
          expect(val(relaxedInputs.active_trip_floatplan_id)).toBe(asset.floatPlanId, serializeJSON(relaxedInputs));
          expect(roundTo2Numeric(relaxedInputs.active_trip_effective_speed_kn)).toBe(5);
          expect(roundTo2Numeric(relaxedInputs.active_trip_weather_adjusted_speed_kn)).toBe(3.75);

          relaxedModel = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);
          expect(relaxedModel.success).toBeTrue(serializeJSON(relaxedModel));
          expect(relaxedModel.pace.currentValue).toBe("RELAXED", serializeJSON(relaxedModel.pace));
          expect(relaxedModel.pace.isActiveTripOverride).toBeTrue(serializeJSON(relaxedModel.pace));
          expect(roundTo2Numeric(relaxedModel.routeTimeline.effectiveSpeedKn)).toBe(3.75, serializeJSON(relaxedModel.routeTimeline));
          relaxedCurrentLeg = findCurrentTimelineLegForTest(relaxedModel.routeTimeline);
          relaxedFutureLeg = findFirstFutureTimelineLegForTest(relaxedModel.routeTimeline);
          expect(abs(roundTo2Numeric(relaxedModel.currentLeg.completedNm) - baselineCompletedNm)).toBeLTE(0.2, serializeJSON(relaxedModel.currentLeg));
          expect(roundTo2Numeric(relaxedModel.currentLeg.completedNm)).toBe(roundTo2Numeric(relaxedCurrentLeg.completedNm), serializeJSON(relaxedCurrentLeg));
          expect(relaxedModel.currentLeg.etaUtc).toBe(relaxedCurrentLeg.etaUtc, serializeJSON(relaxedCurrentLeg));
          expect(relaxedModel.currentLeg.remainingDurationLabel).toBe(relaxedCurrentLeg.remainingDurationLabel, serializeJSON(relaxedCurrentLeg));
          expect(roundTo2Numeric(relaxedCurrentLeg.remainingDurationSeconds)).notToBe(roundTo2Numeric(baselineCurrentRemainingDurationSeconds), serializeJSON(relaxedCurrentLeg));
          expect(roundTo2Numeric(relaxedFutureLeg.estimatedDurationSeconds)).notToBe(roundTo2Numeric(baselineFutureEstimatedDurationSeconds), serializeJSON(relaxedFutureLeg));
          expect(relaxedFutureLeg.remainingDurationSeconds).toBe(relaxedFutureLeg.estimatedDurationSeconds, serializeJSON(relaxedFutureLeg));
          expect(len(relaxedCurrentLeg.remainingDurationLabel)).toBeGT(0, serializeJSON(relaxedCurrentLeg));
          expect(len(relaxedFutureLeg.estimatedDurationLabel)).toBeGT(0, serializeJSON(relaxedFutureLeg));
          expect(relaxedModel.currentLeg.etaUtc).notToBe(baselineCurrentEtaUtc, serializeJSON(relaxedModel.currentLeg));
          expect(relaxedFutureLeg.etaUtc ?: "").notToBe(baselineFutureArrivalUtc, serializeJSON(relaxedFutureLeg));
          expect(dateDiff("n", parseUtcForTest(baselineProjection.routeTimeline.summary.finalArrivalUtc), parseUtcForTest(relaxedModel.routeTimeline.summary.finalArrivalUtc))).toBeGT(0);
          activeCruiseHero = loadActiveCruiseHeroForTest(asset.floatPlanId);
          followBootstrap = loadFollowBootstrapForTest(sessionApi, asset.floatPlanId);
          expect(activeCruiseHero.heroEtaUtc).toBe(relaxedModel.currentLeg.etaUtc, serializeJSON(activeCruiseHero));
          expect(followBootstrap.topCards.eta_utc ?: "").toBe(relaxedModel.currentLeg.etaUtc, serializeJSON(followBootstrap.topCards ?: {}));

          balancedResult = postActiveCruisePaceWithApi(sessionApi, asset.floatPlanId, "BALANCED");
          expect(isSuccessPayload(balancedResult)).toBeTrue(serializeJSON(balancedResult));
          balancedProjection = variables.projectionService.getProjection(asset.floatPlanId, now(), { "includeOperationalLockTime" = true });
          expect(roundTo2Numeric(balancedProjection.routeTimeline.effectiveSpeedKn)).toBe(6, serializeJSON(balancedProjection.pace));
          expect(balancedProjection.pace.speedSource).toBe("vessel_most_efficient", serializeJSON(balancedProjection.pace));

          aggressiveResult = postActiveCruisePaceWithApi(sessionApi, asset.floatPlanId, "AGGRESSIVE");
          expect(isSuccessPayload(aggressiveResult)).toBeTrue(serializeJSON(aggressiveResult));
          aggressiveProjection = variables.projectionService.getProjection(asset.floatPlanId, now(), { "includeOperationalLockTime" = true });
          expect(roundTo2Numeric(aggressiveProjection.routeTimeline.effectiveSpeedKn)).toBe(15, serializeJSON(aggressiveProjection.pace));

          completedResult = postCompleteLegWithApi(sessionApi, asset.floatPlanId, aggressiveProjection.routeTimeline.currentLegOrder);
          expect(isSuccessPayload(completedResult)).toBeTrue(serializeJSON(completedResult));
          completedBefore = variables.projectionService.getProjection(asset.floatPlanId, now(), { "includeOperationalLockTime" = true }).routeTimeline.legs[1];
          expect(completedBefore.isCompleted).toBeTrue(serializeJSON(completedBefore));
          expect(completedBefore.remainingDurationSeconds).toBe(0, serializeJSON(completedBefore));
          relaxedResult = postActiveCruisePaceWithApi(sessionApi, asset.floatPlanId, "RELAXED");
          expect(isSuccessPayload(relaxedResult)).toBeTrue(serializeJSON(relaxedResult));
          completedAfter = variables.projectionService.getProjection(asset.floatPlanId, now(), { "includeOperationalLockTime" = true }).routeTimeline.legs[1];
          expect(completedAfter.isCompleted).toBeTrue(serializeJSON(completedAfter));
          expect(completedAfter.etaUtc).toBe(completedBefore.etaUtc, serializeJSON(completedAfter));
          expect(completedAfter.remainingDurationSeconds).toBe(0, serializeJSON(completedAfter));

          forceStaleActiveTripPaceOverride(asset.floatPlanId, "RELAXED", asset.floatPlanId + 999);
          staleProjection = variables.projectionService.getProjection(asset.floatPlanId, now(), { "includeOperationalLockTime" = true });
          expect(staleProjection.pace.isActiveTripOverride).toBeFalse(serializeJSON(staleProjection.pace));
          expect(roundTo2Numeric(staleProjection.routeTimeline.effectiveSpeedKn)).toBe(20, serializeJSON(staleProjection.pace));
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("preserves active-trip pace overrides when route updates rewrite route inputs", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "pace-route-update");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var seedInputs = {};
        var paceResult = {};
        var beforeInputs = {};
        var editContext = {};
        var updatePayload = {};
        var updateResult = {};
        var afterInputs = {};
        var model = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
          seedInputs = loadRouteInputsForFloatPlan(asset.floatPlanId);
          seedInputs.pace = "RELAXED";
          seedInputs.cruising_speed = 20;
          seedInputs.vessel_most_efficient_speed_kn = 8;
          seedInputs.weather_factor_pct = 0;
          seedInputs.fuel_burn_gph = 10;
          seedInputs.reserve_pct = 33;
          seedInputs.underway_hours_per_day = 6.5;
          seedRouteInputsForPaceTest(asset.floatPlanId, seedInputs);

          paceResult = postActiveCruisePaceWithApi(sessionApi, asset.floatPlanId, "BALANCED");
          expect(isSuccessPayload(paceResult)).toBeTrue(serializeJSON(paceResult));
          beforeInputs = loadRouteInputsForFloatPlan(asset.floatPlanId);
          expect(beforeInputs.pace).toBe("RELAXED", serializeJSON(beforeInputs));
          expect(beforeInputs.active_trip_pace).toBe("BALANCED", serializeJSON(beforeInputs));
          expect(val(beforeInputs.active_trip_floatplan_id)).toBe(asset.floatPlanId, serializeJSON(beforeInputs));
          expect(roundTo2Numeric(beforeInputs.active_trip_effective_speed_kn)).toBe(8, serializeJSON(beforeInputs));

          editContext = sessionApi.routeBuilder("routegen_geteditcontext", { "route_code" = asset.routeCode });
          ensureSuccess(editContext, "load route edit context");
          updatePayload = duplicate(editContext.DATA.inputs);
          updatePayload.route_code = asset.routeCode;
          updatePayload.route_name = trim(toString(editContext.DATA.route.route_name));
          updatePayload.weather_factor_pct = 42;

          updateResult = sessionApi.routeBuilder("routegen_update", updatePayload);
          ensureSuccess(updateResult, "routegen weather factor update");

          afterInputs = loadRouteInputsForFloatPlan(asset.floatPlanId);
          expect(roundTo2Numeric(afterInputs.weather_factor_pct)).toBe(42, serializeJSON(afterInputs));
          expect(afterInputs.pace).toBe("RELAXED", serializeJSON(afterInputs));
          expect(afterInputs.active_trip_pace).toBe("BALANCED", serializeJSON(afterInputs));
          expect(val(afterInputs.active_trip_floatplan_id)).toBe(asset.floatPlanId, serializeJSON(afterInputs));
          expect(roundTo2Numeric(afterInputs.active_trip_effective_speed_kn)).toBe(roundTo2Numeric(beforeInputs.active_trip_effective_speed_kn), serializeJSON(afterInputs));
          expect(afterInputs.active_trip_speed_source).toBe(beforeInputs.active_trip_speed_source, serializeJSON(afterInputs));

          model = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);
          expect(model.success).toBeTrue(serializeJSON(model));
          expect(model.pace.currentValue).toBe("BALANCED", serializeJSON(model.pace));
          expect(model.pace.currentLabel).toBe("Efficient Speed", serializeJSON(model.pace));
          expect(model.pace.isActiveTripOverride).toBeTrue(serializeJSON(model.pace));
          expect(roundTo2Numeric(model.pace.weatherFactorPct)).toBe(42, serializeJSON(model.pace));
          expect(roundTo2Numeric(model.pace.weatherAdjustedSpeedKn)).toBe(4.64, serializeJSON(model.pace));
          expect(roundTo2Numeric(model.routeTimeline.effectiveSpeedKn)).toBe(4.64, serializeJSON(model.routeTimeline));
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("returns underway after an early On Track check-in starts canonical trip activity", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "early-ontrack");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var checkinResult = {};
        var model = {};
        var noteText = "V2 check-in history note";

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
          checkinResult = postActiveCruiseCheckinWithApi(sessionApi, asset.floatPlanId, "On Track", noteText);
          model = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);

          expect(isSuccessPayload(checkinResult)).toBeTrue(serializeJSON(checkinResult));
          expect(model.success).toBeTrue(serializeJSON(model));
          expect(model.tripState).toBe("underway", serializeJSON(model.hero));
          expect(model.motionState).toBe("underway", serializeJSON(model));
          expect(model.hero.status).notToBe("Scheduled");
          expect(model.displayAuthority.primary).toBe("canonical_projection");
          expect(model.routeTimeline.authority).toBe("canonical_projection");
          expect(hasWarning(model, "RAW_ROUTE_INSTANCE_STATUS_CONTRADICTS_CANONICAL_MOTION")).toBeFalse(serializeJSON(model.warnings));
          expect(model.actions.checkIn.enabled).toBeTrue(serializeJSON(model.actions.checkIn));
          expect(len(model.actions.checkIn.endpoint)).toBeGT(0);
          expect(model.actions.checkIn.payload.floatPlanId).toBe(asset.floatPlanId);
          expect(model.actions.completeLeg.enabled).toBeTrue(serializeJSON(model.actions.completeLeg));
          expect(model.actions.completeLeg.payload.expectedLegOrder).toBe(model.currentLeg.order);
          expect(model.actions.startNextLeg.enabled).toBeFalse(serializeJSON(model.actions.startNextLeg));
          expect(model.actions.startNextLeg.reason).toBe("A route leg is already underway.");
          expect(findStatusOption(model, "Secure for the Night").enabled).toBeTrue(serializeJSON(model.checkIn.allowedStatusOptions));
          expect(model.checkInHistory.available).toBeTrue(serializeJSON(model.checkInHistory));
          expect(model.checkInHistory.storageAuthority).toBe("floatplan_events", serializeJSON(model.checkInHistory));
          expect(arrayLen(model.checkInHistory.items)).toBeGT(0, serializeJSON(model.checkInHistory));
          expect(model.checkInHistory.items[1].status).toBe("ON_TRACK", serializeJSON(model.checkInHistory.items[1]));
          expect(model.checkInHistory.items[1].statusLabel).toBe("On Track", serializeJSON(model.checkInHistory.items[1]));
          expect(model.checkInHistory.items[1].note).toBe(noteText, serializeJSON(model.checkInHistory.items[1]));
          expect(model.checkInHistory.items[1].storageAuthority).toBe("floatplan_events", serializeJSON(model.checkInHistory.items[1]));
          expect(model.privateTimeline.available).toBeTrue(serializeJSON(model.privateTimeline));
          expect(model.privateTimeline.storageAuthority).toBe("floatplan_events", serializeJSON(model.privateTimeline));
          expect(findTimelineItem(model, "CHECKIN_RECEIVED").note).toBe(noteText, serializeJSON(model.privateTimeline));
          expect(hasLegacyRoutePlanAuthority(model)).toBeFalse(serializeJSON(model.displayAuthority));
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("exposes shared route map geometry with saved leg overrides for AC-V2 map rendering", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "map-override");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var overrideContext = {};
        var overridePoints = [];
        var routeMapService = new fpw.api.v1.RouteMapGeometryService().init("fpw");
        var routeMap = {};
        var model = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
          overrideContext = loadFirstRouteMapOverrideContext(asset.floatPlanId);
          overridePoints = buildOverrideGeometryPoints(overrideContext);
          saveRouteLegOverrideForTest(overrideContext, overridePoints);

          routeMap = routeMapService.buildRouteMapData(
            overrideContext.route_instance_id,
            variables.sessionApiUser.userId,
            0
          );
          model = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);

          expect(structKeyExists(routeMap, "route_geo")).toBeTrue(serializeJSON(routeMap));
          expect(arrayLen(routeMap.route_geo.coordinates)).toBeGT(0, serializeJSON(routeMap.route_geo));
          expect(arrayLen(routeMap.route_geo.coordinates[1])).toBe(arrayLen(overridePoints), serializeJSON(routeMap.route_geo.coordinates[1]));
          expect(routeMap.route_geo.coordinates[1][2][1]).toBe(overridePoints[2].lon, serializeJSON(routeMap.route_geo.coordinates[1]));
          expect(routeMap.route_geo.coordinates[1][2][2]).toBe(overridePoints[2].lat, serializeJSON(routeMap.route_geo.coordinates[1]));

          expect(model.success).toBeTrue(serializeJSON(model));
          expect(model.map.geometryAuthority).toBe("route_map_geometry_service", serializeJSON(model.map));
          expect(model.map.overrideAuthority).toBe("route_leg_user_overrides", serializeJSON(model.map));
          expect(structKeyExists(model.map, "routeGeo")).toBeTrue(serializeJSON(model.map));
          expect(arrayLen(model.map.routeGeo.coordinates)).toBeGT(0, serializeJSON(model.map.routeGeo));
          expect(arrayLen(model.map.routeGeo.coordinates[1])).toBe(arrayLen(overridePoints), serializeJSON(model.map.routeGeo.coordinates[1]));
          expect(model.map.routeGeo.coordinates[1][2][1]).toBe(overridePoints[2].lon, serializeJSON(model.map.routeGeo.coordinates[1]));
          expect(model.map.routeGeo.coordinates[1][2][2]).toBe(overridePoints[2].lat, serializeJSON(model.map.routeGeo.coordinates[1]));
          expect(arrayLen(model.map.pins)).toBeGT(0, serializeJSON(model.map.pins));
        } finally {
          if (structKeyExists(overrideContext, "route_id")) {
            deleteRouteLegOverrideForTest(overrideContext);
          }
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("records private canonical check-in history and pauses AC-V2 canonically for Delayed", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "checkin-history");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var onTrackResult = {};
        var delayedResult = {};
        var duplicateDelayedResult = {};
        var changedPlanResult = {};
        var needAttentionResult = {};
        var secureResult = {};
        var delayedAt = "";
        var beforeDelayedSegments = 0;
        var beforeChangedSegments = 0;
        var beforeAttentionSegments = 0;
        var afterDelayedSegments = 0;
        var model = {};
        var delayedModel = {};
        var delayedPayload = {};
        var changedPayload = {};
        var needAttentionPayload = {};
        var securePayload = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);

          onTrackResult = recordCanonicalCheckin(asset.floatPlanId, "ON_TRACK", "On Track", "history note on track", 1);
          expect(onTrackResult.SUCCESS).toBeTrue(serializeJSON(onTrackResult));
          expect(arrayFindNoCase(onTrackResult.EVENTS, "CHECKIN_RECEIVED")).toBeGT(0, serializeJSON(onTrackResult));
          expect(arrayFindNoCase(onTrackResult.SEGMENTS, "OPENED_UNDERWAY")).toBeGT(0, serializeJSON(onTrackResult));

          beforeDelayedSegments = countActivitySegments(asset.floatPlanId);
          delayedAt = dateAdd("n", 2, now());
          delayedResult = recordCanonicalCheckin(asset.floatPlanId, "DELAYED", "Delayed", "history note delayed", 2, delayedAt);
          expect(delayedResult.SUCCESS).toBeTrue(serializeJSON(delayedResult));
          expect(arrayFindNoCase(delayedResult.EVENTS, "CHECKIN_RECEIVED")).toBeGT(0, serializeJSON(delayedResult));
          expect(arrayFindNoCase(delayedResult.EVENTS, "DELAYED_PAUSE")).toBeGT(0, serializeJSON(delayedResult));
          expect(arrayFindNoCase(delayedResult.SEGMENTS, "CLOSED_UNDERWAY")).toBeGT(0, serializeJSON(delayedResult));
          expect(arrayFindNoCase(delayedResult.SEGMENTS, "OPENED_PAUSED_DELAYED")).toBeGT(0, serializeJSON(delayedResult));
          expect(countActivitySegments(asset.floatPlanId)).toBe(beforeDelayedSegments + 1);
          expect(findOpenActivitySegmentType(asset.floatPlanId)).toBe("PAUSED_DELAYED");

          afterDelayedSegments = countActivitySegments(asset.floatPlanId);
          duplicateDelayedResult = recordCanonicalCheckin(asset.floatPlanId, "DELAYED", "Delayed", "history note delayed", 2, delayedAt);
          expect(duplicateDelayedResult.SUCCESS).toBeTrue(serializeJSON(duplicateDelayedResult));
          expect(duplicateDelayedResult.SKIPPED).toBeTrue(serializeJSON(duplicateDelayedResult));
          expect(arrayLen(duplicateDelayedResult.SEGMENTS)).toBe(0, serializeJSON(duplicateDelayedResult));
          expect(countActivitySegments(asset.floatPlanId)).toBe(afterDelayedSegments);
          expect(findOpenActivitySegmentType(asset.floatPlanId)).toBe("PAUSED_DELAYED");

          delayedModel = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);
          expect(delayedModel.success).toBeTrue(serializeJSON(delayedModel));
          expect(delayedModel.motionState).toBe("paused_delayed", serializeJSON(delayedModel));
          expect(delayedModel.tripState).toBe("paused_delayed", serializeJSON(delayedModel));
          expect(delayedModel.hero.status).toBe("Delayed", serializeJSON(delayedModel.hero));
          expect(delayedModel.hero.statusDetail).toBe("Trip progress is paused by the latest Delayed check-in. Monitoring remains active.", serializeJSON(delayedModel.hero));
          expect(findStatusOption(delayedModel, "Secure for the Night").enabled).toBeTrue(serializeJSON(delayedModel.checkIn.allowedStatusOptions));
          expect(delayedModel.actions.completeLeg.enabled).toBeFalse(serializeJSON(delayedModel.actions.completeLeg));

          beforeChangedSegments = countActivitySegments(asset.floatPlanId);
          changedPlanResult = recordCanonicalCheckin(asset.floatPlanId, "CHANGED_PLAN", "Changed Plan", "history note changed", 3);
          expect(changedPlanResult.SUCCESS).toBeTrue(serializeJSON(changedPlanResult));
          expect(arrayFindNoCase(changedPlanResult.EVENTS, "CHECKIN_RECEIVED")).toBeGT(0, serializeJSON(changedPlanResult));
          expect(arrayLen(changedPlanResult.SEGMENTS)).toBe(0, serializeJSON(changedPlanResult));
          expect(countActivitySegments(asset.floatPlanId)).toBe(beforeChangedSegments);

          beforeAttentionSegments = countActivitySegments(asset.floatPlanId);
          needAttentionResult = recordCanonicalCheckin(asset.floatPlanId, "NEED_ATTENTION", "Assistance Needed", "history note assistance", 4);
          expect(needAttentionResult.SUCCESS).toBeTrue(serializeJSON(needAttentionResult));
          expect(arrayFindNoCase(needAttentionResult.EVENTS, "CHECKIN_RECEIVED")).toBeGT(0, serializeJSON(needAttentionResult));
          expect(arrayLen(needAttentionResult.SEGMENTS)).toBe(0, serializeJSON(needAttentionResult));
          expect(countActivitySegments(asset.floatPlanId)).toBe(beforeAttentionSegments);

          secureResult = recordCanonicalCheckin(asset.floatPlanId, "SECURE_FOR_NIGHT", "Secure for the Night", "history note secure", 5);
          expect(secureResult.SUCCESS).toBeTrue(serializeJSON(secureResult));
          expect(arrayFindNoCase(secureResult.EVENTS, "CHECKIN_RECEIVED")).toBeGT(0, serializeJSON(secureResult));
          expect(arrayFindNoCase(secureResult.SEGMENTS, "CLOSED_PAUSED_DELAYED")).toBeGT(0, serializeJSON(secureResult));
          expect(arrayFindNoCase(secureResult.SEGMENTS, "OPENED_PAUSED_SECURE_FOR_NIGHT")).toBeGT(0, serializeJSON(secureResult));
          expect(findOpenActivitySegmentType(asset.floatPlanId)).toBe("PAUSED_SECURE_FOR_NIGHT");

          delayedPayload = findCheckinEventPayload(asset.floatPlanId, "DELAYED");
          changedPayload = findCheckinEventPayload(asset.floatPlanId, "CHANGED_PLAN");
          needAttentionPayload = findCheckinEventPayload(asset.floatPlanId, "NEED_ATTENTION");
          securePayload = findCheckinEventPayload(asset.floatPlanId, "SECURE_FOR_NIGHT");

          expect(delayedPayload.note_body).toBe("history note delayed", serializeJSON(delayedPayload));
          expect(changedPayload.note_body).toBe("history note changed", serializeJSON(changedPayload));
          expect(needAttentionPayload.note_body).toBe("history note assistance", serializeJSON(needAttentionPayload));
          expect(securePayload.note_body).toBe("history note secure", serializeJSON(securePayload));

          model = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);
          expect(model.checkInHistory.available).toBeTrue(serializeJSON(model.checkInHistory));
          expect(model.checkInHistory.storageAuthority).toBe("floatplan_events", serializeJSON(model.checkInHistory));
          expect(model.checkInHistory.count).toBe(5, serializeJSON(model.checkInHistory));
          expect(model.checkInHistory.items[1].status).toBe("SECURE_FOR_NIGHT", serializeJSON(model.checkInHistory.items));
          expect(findHistoryItem(model, "ON_TRACK").note).toBe("history note on track", serializeJSON(model.checkInHistory));
          expect(findHistoryItem(model, "DELAYED").statusLabel).toBe("Delayed", serializeJSON(model.checkInHistory));
          expect(findHistoryItem(model, "CHANGED_PLAN").title).toBe("Check-in: Changed Plan", serializeJSON(model.checkInHistory));
          expect(findHistoryItem(model, "NEED_ATTENTION").statusLabel).toBe("Assistance Needed", serializeJSON(model.checkInHistory));
          expect(findHistoryItem(model, "SECURE_FOR_NIGHT").note).toBe("history note secure", serializeJSON(model.checkInHistory));
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("resumes underway from a canonical delayed pause on On Track", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "delayed-resume");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var onTrackResult = {};
        var delayedResult = {};
        var resumedResult = {};
        var model = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);

          onTrackResult = recordCanonicalCheckin(asset.floatPlanId, "ON_TRACK", "On Track", "resume setup on track", 1);
          delayedResult = recordCanonicalCheckin(asset.floatPlanId, "DELAYED", "Delayed", "resume setup delayed", 2);
          resumedResult = recordCanonicalCheckin(asset.floatPlanId, "ON_TRACK", "On Track", "resume after delayed", 3);
          model = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);

          expect(onTrackResult.SUCCESS).toBeTrue(serializeJSON(onTrackResult));
          expect(delayedResult.SUCCESS).toBeTrue(serializeJSON(delayedResult));
          expect(arrayFindNoCase(delayedResult.SEGMENTS, "OPENED_PAUSED_DELAYED")).toBeGT(0, serializeJSON(delayedResult));
          expect(resumedResult.SUCCESS).toBeTrue(serializeJSON(resumedResult));
          expect(arrayFindNoCase(resumedResult.EVENTS, "RESUMED_UNDERWAY")).toBeGT(0, serializeJSON(resumedResult));
          expect(arrayFindNoCase(resumedResult.SEGMENTS, "CLOSED_PAUSED_DELAYED")).toBeGT(0, serializeJSON(resumedResult));
          expect(arrayFindNoCase(resumedResult.SEGMENTS, "OPENED_UNDERWAY")).toBeGT(0, serializeJSON(resumedResult));
          expect(findOpenActivitySegmentType(asset.floatPlanId)).toBe("UNDERWAY");
          expect(model.success).toBeTrue(serializeJSON(model));
          expect(model.motionState).toBe("underway", serializeJSON(model));
          expect(model.tripState).toBe("underway", serializeJSON(model));
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("keeps secure-for-night authoritative when a Delayed check-in reaches the writer while already secure", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "delayed-while-secure");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var onTrackResult = {};
        var secureResult = {};
        var beforeDelayedSegments = 0;
        var delayedResult = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);

          onTrackResult = recordCanonicalCheckin(asset.floatPlanId, "ON_TRACK", "On Track", "secure setup on track", 1);
          secureResult = recordCanonicalCheckin(asset.floatPlanId, "SECURE_FOR_NIGHT", "Secure for the Night", "secure setup", 2);
          beforeDelayedSegments = countActivitySegments(asset.floatPlanId);
          delayedResult = recordCanonicalCheckin(asset.floatPlanId, "DELAYED", "Delayed", "delayed while secure", 3);

          expect(onTrackResult.SUCCESS).toBeTrue(serializeJSON(onTrackResult));
          expect(secureResult.SUCCESS).toBeTrue(serializeJSON(secureResult));
          expect(findOpenActivitySegmentType(asset.floatPlanId)).toBe("PAUSED_SECURE_FOR_NIGHT");
          expect(delayedResult.SUCCESS).toBeTrue(serializeJSON(delayedResult));
          expect(arrayFindNoCase(delayedResult.EVENTS, "CHECKIN_RECEIVED")).toBeGT(0, serializeJSON(delayedResult));
          expect(arrayLen(delayedResult.SEGMENTS)).toBe(0, serializeJSON(delayedResult));
          expect(countActivitySegments(asset.floatPlanId)).toBe(beforeDelayedSegments);
          expect(findOpenActivitySegmentType(asset.floatPlanId)).toBe("PAUSED_SECURE_FOR_NIGHT");
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("enables Start Next Leg after the current leg is completed and a pending leg exists", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "start-next-leg");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var checkinResult = {};
        var startedModel = {};
        var completeResult = {};
        var model = {};
        var completeRoutePayload = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
          checkinResult = postActiveCruiseCheckinWithApi(sessionApi, asset.floatPlanId, "On Track");
          startedModel = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);
          completeResult = postCompleteLegWithApi(sessionApi, asset.floatPlanId, startedModel.currentLeg.order);
          model = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);

          expect(isSuccessPayload(checkinResult)).toBeTrue(serializeJSON(checkinResult));
          expect(isSuccessPayload(completeResult)).toBeTrue(serializeJSON(completeResult));
          expect(completeResult.COMPLETED ?: false).toBeTrue(serializeJSON(completeResult));
          expect(model.success).toBeTrue(serializeJSON(model));
          expect(model.routeTimeline.available).toBeTrue(serializeJSON(model.routeTimeline));
          expect(model.actions.startNextLeg.enabled).toBeTrue(serializeJSON(model.actions.startNextLeg));
          expect(findNoCase("action=startnextleg", model.actions.startNextLeg.endpoint)).toBeGT(0, serializeJSON(model.actions.startNextLeg));
          expect(model.actions.startNextLeg.payload.floatPlanId).toBe(asset.floatPlanId);
          expect(model.actions.startNextLeg.reason).toBe("");
          expect(countRouteActionEvents(asset.floatPlanId, "ROUTE_LEG_COMPLETED")).toBe(1);
          completeRoutePayload = findRouteActionEventPayload(asset.floatPlanId, "ROUTE_LEG_COMPLETED");
          expect(completeRoutePayload.leg_order).toBe(startedModel.currentLeg.order, serializeJSON(completeRoutePayload));
          expect(completeRoutePayload.endpoint_leg_order).toBe(startedModel.currentLeg.order, serializeJSON(completeRoutePayload));
          expect(completeRoutePayload.action_label).toBe("Complete Current Leg / Arrived", serializeJSON(completeRoutePayload));
          expect(len(completeRoutePayload.from_name)).toBeGT(0, serializeJSON(completeRoutePayload));
          expect(len(completeRoutePayload.to_name)).toBeGT(0, serializeJSON(completeRoutePayload));
          expect(findTimelineItem(model, "ROUTE_LEG_COMPLETED").title).toBe("Complete Current Leg / Arrived", serializeJSON(model.privateTimeline));
          expect(hasLegacyRoutePlanAuthority(model)).toBeFalse(serializeJSON(model.displayAuthority));
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("records private route-action history for Start Next Leg and merges it with check-ins", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "route-action-start");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var checkinResult = {};
        var startedModel = {};
        var completeResult = {};
        var startResult = {};
        var model = {};
        var startedPayload = {};
        var startedTimeline = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
          checkinResult = postActiveCruiseCheckinWithApi(sessionApi, asset.floatPlanId, "On Track", "merged timeline check-in");
          startedModel = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);
          completeResult = postCompleteLegWithApi(sessionApi, asset.floatPlanId, startedModel.currentLeg.order);
          startResult = postStartNextLegWithApi(sessionApi, asset.floatPlanId);
          model = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);

          expect(isSuccessPayload(checkinResult)).toBeTrue(serializeJSON(checkinResult));
          expect(isSuccessPayload(completeResult)).toBeTrue(serializeJSON(completeResult));
          expect(isSuccessPayload(startResult)).toBeTrue(serializeJSON(startResult));
          expect(startResult.STARTED ?: false).toBeTrue(serializeJSON(startResult));
          expect(countRouteActionEvents(asset.floatPlanId, "ROUTE_LEG_STARTED")).toBe(1);
          startedPayload = findRouteActionEventPayload(asset.floatPlanId, "ROUTE_LEG_STARTED");
          expect(startedPayload.leg_order).toBe(startResult.LEG_ORDER, serializeJSON(startedPayload));
          expect(startedPayload.endpoint_leg_order).toBe(startResult.LEG_ORDER, serializeJSON(startedPayload));
          expect(startedPayload.action_label).toBe("Start Next Leg", serializeJSON(startedPayload));
          expect(model.privateTimeline.available).toBeTrue(serializeJSON(model.privateTimeline));
          expect(model.privateTimeline.storageAuthority).toBe("floatplan_events", serializeJSON(model.privateTimeline));
          expect(findTimelineItem(model, "CHECKIN_RECEIVED").note).toBe("merged timeline check-in", serializeJSON(model.privateTimeline));
          startedTimeline = findTimelineItem(model, "ROUTE_LEG_STARTED");
          expect(startedTimeline.title).toBe("Start Next Leg", serializeJSON(model.privateTimeline));
          expect(startedTimeline.storageAuthority).toBe("floatplan_events", serializeJSON(startedTimeline));
          expect(model.privateTimeline.items[1].eventType).toBe("ROUTE_LEG_STARTED", serializeJSON(model.privateTimeline.items));
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("does not record route-action history when a route action fails validation", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "route-action-fail");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var completeResult = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
          completeResult = postCompleteLegWithApi(sessionApi, asset.floatPlanId, 1);

          expect(isSuccessPayload(completeResult)).toBeFalse(serializeJSON(completeResult));
          expect(countRouteActionEvents(asset.floatPlanId)).toBe(0);
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("records a private route-action event after successful float plan close", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "route-action-close");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var preCloseModel = {};
        var closeResult = {};
        var closePayload = {};
        var closeState = {};
        var progressCounts = {};
        var model = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
          markAllLegsCompleted(asset.floatPlanId);
          preCloseModel = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);
          closeResult = sessionApi.postJson(preCloseModel.actions.closeFloatPlan.endpoint, preCloseModel.actions.closeFloatPlan.payload);
          model = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);
          closeState = loadFinalCloseState(asset.floatPlanId);
          progressCounts = loadRouteProgressCounts(asset.floatPlanId);

          expect(preCloseModel.success).toBeTrue(serializeJSON(preCloseModel));
          expect(preCloseModel.actions.closeFloatPlan.enabled).toBeTrue(serializeJSON(preCloseModel.actions.closeFloatPlan));
          expect(findNoCase("action=checkin", preCloseModel.actions.closeFloatPlan.endpoint)).toBeGT(0, serializeJSON(preCloseModel.actions.closeFloatPlan));
          expect(preCloseModel.actions.closeFloatPlan.payload.status).toBe("Arrived", serializeJSON(preCloseModel.actions.closeFloatPlan.payload));
          expect(isSuccessPayload(closeResult)).toBeTrue(serializeJSON(closeResult));
          expect(closeResult.STATUS ?: "").toBe("CLOSED", serializeJSON(closeResult));
          expect(closeState.status).toBe("CLOSED", serializeJSON(closeState));
          expect(closeState.closed_at_present).toBeTrue(serializeJSON(closeState));
          expect(closeState.monitor_state).toBe("CLOSED", serializeJSON(closeState));
          expect(closeState.monitor_closed_at_present).toBeTrue(serializeJSON(closeState));
          expect(progressCounts.completed_rows).toBe(progressCounts.progress_row_count, serializeJSON(progressCounts));
          expect(countRouteActionEvents(asset.floatPlanId, "FLOATPLAN_CLOSED")).toBe(1);
          closePayload = findRouteActionEventPayload(asset.floatPlanId, "FLOATPLAN_CLOSED");
          expect(closePayload.action_label).toBe("Close Float Plan", serializeJSON(closePayload));
          expect(closePayload.status_label).toBe("Float plan closed", serializeJSON(closePayload));
          expect(findTimelineItem(model, "FLOATPLAN_CLOSED").title).toBe("Close Float Plan", serializeJSON(model.privateTimeline));
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("exposes supporting panel contracts without page-local authority", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "supporting-panels");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var model = {};
        var firstMapLeg = {};
        var firstContact = {};
        var weatherStart = {};
        var weatherEnd = {};
        var weatherLookup = {};
        var dailyStartAction = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
          model = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);

          expect(model.success).toBeTrue(serializeJSON(model));
          expect(structKeyExists(model.map, "available")).toBeTrue(serializeJSON(model.map));
          expect(model.map.geometryAuthority).toBe("route_map_geometry_service", serializeJSON(model.map));
          expect(model.map.overrideAuthority).toBe("route_leg_user_overrides", serializeJSON(model.map));
          expect(isArray(model.map.legs)).toBeTrue(serializeJSON(model.map));
          expect(arrayLen(model.map.legs)).toBeGT(0, serializeJSON(model.map));
          firstMapLeg = model.map.legs[1];
          expect(structKeyExists(firstMapLeg, "from")).toBeTrue(serializeJSON(firstMapLeg));
          expect(structKeyExists(firstMapLeg, "to")).toBeTrue(serializeJSON(firstMapLeg));
          expect(structKeyExists(model.map, "bounds")).toBeTrue(serializeJSON(model.map));
          expect(structKeyExists(model.map, "center")).toBeTrue(serializeJSON(model.map));
          expect(structKeyExists(model.map.currentPosition, "available")).toBeTrue(serializeJSON(model.map.currentPosition));
          expect(model.map.currentPosition.available).toBeFalse(serializeJSON(model.map.currentPosition));

          expect(model.weather.authority).toBe("ActiveCruiseViewModelService.weather_lookup_contract", serializeJSON(model.weather));
          expect(model.weather.source).toBe("voyage.getActiveCruiseWeatherCanonical");
          expect(model.weather.available).toBeFalse(serializeJSON(model.weather));
          expect(structKeyExists(model.weather, "lookupEndpoint")).toBeFalse(serializeJSON(model.weather));
          expect(structKeyExists(model.weather, "lookup")).toBeTrue(serializeJSON(model.weather));
          weatherLookup = model.weather.lookup;
          expect(weatherLookup.available).toBeTrue(serializeJSON(model.weather));
          expect(weatherLookup.method).toBe("POST", serializeJSON(weatherLookup));
          expect(findNoCase("action=getactivecruiseweather", weatherLookup.endpoint)).toBeGT(0, serializeJSON(weatherLookup));
          expect(weatherLookup.payload.floatPlanId).toBe(asset.floatPlanId, serializeJSON(weatherLookup));
          expect(weatherLookup.payload.point).toBe("", serializeJSON(weatherLookup));
          expect(isArray(weatherLookup.allowedPoints)).toBeTrue(serializeJSON(weatherLookup));
          expect(arrayFindNoCase(weatherLookup.allowedPoints, "start")).toBeGT(0, serializeJSON(weatherLookup));
          expect(arrayFindNoCase(weatherLookup.allowedPoints, "end")).toBeGT(0, serializeJSON(weatherLookup));
          expect(structKeyExists(model.weather, "points")).toBeTrue(serializeJSON(model.weather));
          expect(structKeyExists(model.weather.points, "start")).toBeTrue(serializeJSON(model.weather));
          expect(structKeyExists(model.weather.points, "end")).toBeTrue(serializeJSON(model.weather));
          weatherStart = model.weather.points.start;
          weatherEnd = model.weather.points.end;
          expect(weatherStart.point).toBe("start", serializeJSON(weatherStart));
          expect(weatherEnd.point).toBe("end", serializeJSON(weatherEnd));
          expect(len(weatherStart.label)).toBeGT(0, serializeJSON(weatherStart));
          expect(len(weatherEnd.label)).toBeGT(0, serializeJSON(weatherEnd));
          expect(weatherStart.available).toBeTrue(serializeJSON(weatherStart));
          expect(weatherEnd.available).toBeTrue(serializeJSON(weatherEnd));
          expect(isNumeric(weatherStart.lat)).toBeTrue(serializeJSON(weatherStart));
          expect(isNumeric(weatherStart.lng)).toBeTrue(serializeJSON(weatherStart));
          expect(isNumeric(weatherEnd.lat)).toBeTrue(serializeJSON(weatherEnd));
          expect(isNumeric(weatherEnd.lng)).toBeTrue(serializeJSON(weatherEnd));
          expect(structKeyExists(weatherStart, "wind")).toBeFalse(serializeJSON(weatherStart));
          expect(structKeyExists(weatherStart, "marine")).toBeFalse(serializeJSON(weatherStart));
          expect(structKeyExists(weatherStart, "visibility")).toBeFalse(serializeJSON(weatherStart));
          expect(structKeyExists(weatherStart, "forecast")).toBeFalse(serializeJSON(weatherStart));
          expect(isArray(model.weather.alerts)).toBeTrue(serializeJSON(model.weather));
          expect(isArray(model.weather.warnings)).toBeTrue(serializeJSON(model.weather));
          expect(arrayLen(model.weather.alerts)).toBe(0, serializeJSON(model.weather));
          expect(len(model.weather.message)).toBeGT(0, serializeJSON(model.weather));
          expect(structKeyExists(model.weather, "weatherFactor")).toBeFalse(serializeJSON(model.weather));
          expect(structKeyExists(model.weather, "applyEndpoint")).toBeFalse(serializeJSON(model.weather));
          expect(structKeyExists(model.weather, "apply")).toBeTrue(serializeJSON(model.weather));
          weatherApply = model.weather.apply;
          expect(weatherApply.available).toBeTrue(serializeJSON(model.weather));
          expect(weatherApply.method).toBe("POST", serializeJSON(weatherApply));
          expect(weatherApply.routeCode).toBe(model.route.routeCode, serializeJSON(weatherApply));
          expect(structKeyExists(weatherApply, "endpoints")).toBeTrue(serializeJSON(weatherApply));
          expect(findNoCase("action=routegen_geteditcontext", weatherApply.endpoints.editContext)).toBeGT(0, serializeJSON(weatherApply));
          expect(findNoCase("action=routegen_preview", weatherApply.endpoints.generatedPreview)).toBeGT(0, serializeJSON(weatherApply));
          expect(findNoCase("action=previewuserroute", weatherApply.endpoints.myRoutePreview)).toBeGT(0, serializeJSON(weatherApply));
          expect(findNoCase("action=routegen_update", weatherApply.endpoints.update)).toBeGT(0, serializeJSON(weatherApply));
          expect(weatherApply.payload.routeCode).toBe(model.route.routeCode, serializeJSON(weatherApply));

          expect(structKeyExists(model.floatPlanInfo, "departure")).toBeTrue(serializeJSON(model.floatPlanInfo));
          expect(structKeyExists(model.floatPlanInfo, "return")).toBeTrue(serializeJSON(model.floatPlanInfo));
          expect(structKeyExists(model.floatPlanInfo, "rescueAuthority")).toBeTrue(serializeJSON(model.floatPlanInfo));
          expect(structKeyExists(model.floatPlanInfo, "supplies")).toBeTrue(serializeJSON(model.floatPlanInfo));
          expect(model.floatPlanInfo.download.available).toBeFalse(serializeJSON(model.floatPlanInfo.download));

          expect(model.contacts.authority).toBe("floatplan_contacts,floatplan_passengers");
          expect(model.contacts.roleAuthority).toBe("table_membership");
          expect(model.contacts.count).toBeGT(0, serializeJSON(model.contacts));
          firstContact = model.contacts.items[1];
          expect(firstContact.role).toBe("notification_contact", serializeJSON(firstContact));
          expect(firstContact.category).toBe("notification_contact", serializeJSON(firstContact));

          expect(model.captainLog.available).toBeTrue(serializeJSON(model.captainLog));
          expect(model.captainLog.storageAuthority).toBe("floatplan_captain_log_entries");
          expect(model.captainLog.writeAvailable).toBeTrue(serializeJSON(model.captainLog));
          expect(model.captainLog.writeAction).toBe("actions.captainLog.save", serializeJSON(model.captainLog));
          expect(structKeyExists(model.actions, "captainLog")).toBeTrue(serializeJSON(model.actions));
          expect(structKeyExists(model.actions.captainLog, "save")).toBeTrue(serializeJSON(model.actions.captainLog));
          expect(model.actions.captainLog.save.enabled).toBeTrue(serializeJSON(model.actions.captainLog.save));
          expect(model.actions.captainLog.save.method).toBe("POST", serializeJSON(model.actions.captainLog.save));
          expect(findNoCase("action=savecaptainlogentry", model.actions.captainLog.save.endpoint)).toBeGT(0, serializeJSON(model.actions.captainLog.save));
          expect(model.actions.captainLog.save.payload.floatPlanId).toBe(asset.floatPlanId, serializeJSON(model.actions.captainLog.save));
          expect(structKeyExists(model.actions.captainLog.save.payload, "noteBody")).toBeTrue(serializeJSON(model.actions.captainLog.save.payload));
          expect(structKeyExists(model.actions.captainLog.save.payload, "noteTag")).toBeTrue(serializeJSON(model.actions.captainLog.save.payload));
          expect(structKeyExists(model.actions.captainLog.save.payload, "postToFollowStream")).toBeTrue(serializeJSON(model.actions.captainLog.save.payload));
          expect(model.actions.captainLog.save.inputRequirements.noteBody.required).toBeTrue(serializeJSON(model.actions.captainLog.save.inputRequirements));

          expect(structKeyExists(model.actions.checkIn, "inputRequirements")).toBeTrue(serializeJSON(model.actions.checkIn));
          expect(model.actions.checkIn.inputRequirements.status.required).toBeTrue(serializeJSON(model.actions.checkIn));
          expect(structKeyExists(model.actions.completeLeg, "confirmationRequired")).toBeTrue(serializeJSON(model.actions.completeLeg));
          expect(findStatusOption(model, "Delayed").inputRequirements.newExpectedDepartureTime.required).toBeTrue(serializeJSON(model.checkIn.allowedStatusOptions));
          expect(findStatusOption(model, "Assistance Needed").confirmationRequired).toBeTrue(serializeJSON(model.checkIn.allowedStatusOptions));
          expect(structKeyExists(model.actions, "timing")).toBeTrue(serializeJSON(model.actions));
          expect(model.actions.timing.addDelay.endpoint).toBe("/api/v1/floatplan.cfc?method=handle&action=adddelay&returnFormat=json", serializeJSON(model.actions.timing.addDelay));
          expect(model.actions.timing.clearDelay.endpoint).toBe("/api/v1/floatplan.cfc?method=handle&action=cleardelay&returnFormat=json", serializeJSON(model.actions.timing.clearDelay));
          dailyStartAction = model.actions.timing.updateDailyStart;
          expect(dailyStartAction.enabled).toBeTrue(serializeJSON(dailyStartAction));
          expect(dailyStartAction.method).toBe("POST", serializeJSON(dailyStartAction));
          expect(dailyStartAction.endpoint).toBe("/api/v1/floatplan.cfc?method=handle&action=updatedailystart&returnFormat=json", serializeJSON(dailyStartAction));
          expect(dailyStartAction.payload.floatPlanId).toBe(asset.floatPlanId, serializeJSON(dailyStartAction.payload));
          expect(structKeyExists(dailyStartAction.payload, "dailyStartLocalTime")).toBeTrue(serializeJSON(dailyStartAction.payload));
          expect(dailyStartAction.inputRequirements.dailyStartLocalTime.required).toBeTrue(serializeJSON(dailyStartAction.inputRequirements));
          expect(hasLegacyRoutePlanAuthority(model)).toBeFalse(serializeJSON(model.displayAuthority));
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("updates daily start override through the AC-V2 timing action contract", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "daily-start");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var modelBefore = {};
        var modelAfter = {};
        var invalidResult = {};
        var validResult = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
          modelBefore = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);
          expect(modelBefore.success).toBeTrue(serializeJSON(modelBefore));
          expect(normalizeDailyStartForTest(modelBefore.monitoring.dailyStartLocalTime)).toBe("08:00", serializeJSON(modelBefore.monitoring));

          invalidResult = postActiveCruiseDailyStartWithApi(sessionApi, asset.floatPlanId, "25:99");
          expect(isSuccessPayload(invalidResult)).toBeFalse(serializeJSON(invalidResult));
          expect(invalidResult.ERROR ?: "").toBe("INVALID_DAILY_START", serializeJSON(invalidResult));
          expect(normalizeDailyStartForTest(loadDailyStartLocalTimeForFloatPlan(asset.floatPlanId))).toBe("08:00");

          validResult = postActiveCruiseDailyStartWithApi(sessionApi, asset.floatPlanId, "09:30");
          expect(isSuccessPayload(validResult)).toBeTrue(serializeJSON(validResult));
          expect(normalizeDailyStartForTest(validResult.DAILYSTARTLOCALTIME ?: "")).toBe("09:30", serializeJSON(validResult));
          expect(normalizeDailyStartForTest(loadDailyStartLocalTimeForFloatPlan(asset.floatPlanId))).toBe("09:30");

          modelAfter = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);
          expect(modelAfter.success).toBeTrue(serializeJSON(modelAfter));
          expect(normalizeDailyStartForTest(modelAfter.monitoring.dailyStartLocalTime)).toBe("09:30", serializeJSON(modelAfter.monitoring));
          expect(normalizeDailyStartForTest(modelAfter.actions.timing.updateDailyStart.payload.dailyStartLocalTime)).toBe("09:30", serializeJSON(modelAfter.actions.timing.updateDailyStart));
          expect(modelAfter.actions.timing.addDelay.endpoint).toBe(modelBefore.actions.timing.addDelay.endpoint, serializeJSON(modelAfter.actions.timing.addDelay));
          expect(modelAfter.actions.timing.clearDelay.endpoint).toBe(modelBefore.actions.timing.clearDelay.endpoint, serializeJSON(modelAfter.actions.timing.clearDelay));
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("lets explicit started-leg proof win over the scheduled clock when canonical routeTimeline is unavailable", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "started-proof");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var model = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
          markFirstLegStarted(asset.floatPlanId);
          model = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);

          expect(model.tripState).toBe("underway", serializeJSON(model));
          expect(model.motionState).toBe("underway", serializeJSON(model));
          expect(model.hero.status).notToBe("Scheduled");
          expect(model.displayAuthority.primary).toBe("route_instance_leg_progress_start_proof");
          expect(hasWarning(model, "RAW_ROUTE_INSTANCE_STATUS_CONTRADICTS_CANONICAL_MOTION")).toBeTrue(serializeJSON(model.warnings));
          expect(hasLegacyRoutePlanAuthority(model)).toBeFalse(serializeJSON(model.displayAuthority));
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("represents secure for the night as paused_overnight from monitoring authority", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "secure-night");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var checkinResult = {};
        var model = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
          checkinResult = postActiveCruiseCheckinWithApi(sessionApi, asset.floatPlanId, "On Track");
          markMonitoringSecureForNight(asset.floatPlanId);
          model = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);

          expect(isSuccessPayload(checkinResult)).toBeTrue(serializeJSON(checkinResult));
          expect(model.success).toBeTrue(serializeJSON(model));
          expect(model.tripState).toBe("paused_overnight", serializeJSON(model));
          expect(model.motionState).toBe("paused_overnight", serializeJSON(model));
          expect(model.monitoring.secureForNight).toBeTrue();
          expect(len(model.monitoring.secureForNightUntilUtc)).toBeGT(0);
          expect(model.displayAuthority.monitoring).toBe("floatplan_monitoring");
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("overlays late missed and escalated monitoring states without changing scheduled motion", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "safety-overlay");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var stateCase = {};
        var model = {};
        var stateCases = [
          { monitorState = "LATE", tripState = "late" },
          { monitorState = "MISSED", tripState = "missed" },
          { monitorState = "ESCALATED", tripState = "escalated" }
        ];

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);

          for (stateCase in stateCases) {
            setMonitoringState(asset.floatPlanId, stateCase.monitorState);
            model = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);

            expect(model.success).toBeTrue(serializeJSON(model));
            expect(model.tripState).toBe(stateCase.tripState, serializeJSON(model));
            expect(model.safetyState).toBe(stateCase.tripState, serializeJSON(model));
            expect(model.motionState).toBe("scheduled", serializeJSON(model));
            expect(model.displayAuthority.monitoring).toBe("floatplan_monitoring");
          }
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("represents Assistance Needed as a safety overlay without starting route progress", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "assistance");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var model = {};
        var progressCounts = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
          markAssistanceNeeded(asset.floatPlanId);
          model = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);
          progressCounts = loadRouteProgressCounts(asset.floatPlanId);

          expect(model.success).toBeTrue(serializeJSON(model));
          expect(model.tripState).toBe("assistance_needed", serializeJSON(model));
          expect(model.safetyState).toBe("assistance_needed");
          expect(model.motionState).toBe("scheduled");
          expect(progressCounts.started_rows).toBe(0);
          expect(progressCounts.completed_rows).toBe(0);
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("exposes arrived and closed terminal states from route progress and float plan closure", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "terminal");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var arrivedModel = {};
        var closedModel = {};
        var cancelledModel = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
          markAllLegsCompleted(asset.floatPlanId);
          arrivedModel = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);
          markPlanClosed(asset.floatPlanId);
          closedModel = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);

          expect(arrivedModel.success).toBeTrue(serializeJSON(arrivedModel));
          expect(arrivedModel.tripState).toBe("arrived", serializeJSON(arrivedModel));
          expect(arrivedModel.motionState).toBe("arrived", serializeJSON(arrivedModel));
          expect(arrivedModel.actions.startNextLeg.enabled).toBeFalse(serializeJSON(arrivedModel.actions.startNextLeg));
          expect(len(arrivedModel.actions.startNextLeg.reason)).toBeGT(0);
          expect(arrivedModel.currentLeg.order).toBeLTE(arrivedModel.route.totalLegs, serializeJSON(arrivedModel.currentLeg));
          expect(arrivedModel.currentLeg.order).toBe(arrivedModel.route.totalLegs, serializeJSON(arrivedModel.currentLeg));
          expect(arrivedModel.actions.closeFloatPlan.enabled).toBeTrue(serializeJSON(arrivedModel.actions.closeFloatPlan));
          expect(findNoCase("action=checkin", arrivedModel.actions.closeFloatPlan.endpoint)).toBeGT(0, serializeJSON(arrivedModel.actions.closeFloatPlan));
          expect(arrivedModel.actions.closeFloatPlan.payload.status).toBe("Arrived", serializeJSON(arrivedModel.actions.closeFloatPlan.payload));
          expect(closedModel.success).toBeTrue(serializeJSON(closedModel));
          expect(closedModel.tripState).toBe("closed", serializeJSON(closedModel));
          expect(closedModel.motionState).toBe("closed", serializeJSON(closedModel));
          expect(closedModel.actions.closeFloatPlan.enabled).toBeFalse(serializeJSON(closedModel.actions.closeFloatPlan));
          markPlanCancelled(asset.floatPlanId);
          cancelledModel = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);
          expect(cancelledModel.success).toBeTrue(serializeJSON(cancelledModel));
          expect(cancelledModel.actions.closeFloatPlan.enabled).toBeFalse(serializeJSON(cancelledModel.actions.closeFloatPlan));
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("returns unknown_error with warnings when required canonical route data is unavailable", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "bad-data");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var model = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
          deleteRouteLegRows(asset.floatPlanId);
          model = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);

          expect(model.success).toBeFalse(serializeJSON(model));
          expect(model.tripState).toBe("unknown_error", serializeJSON(model));
          expect(model.routeTimeline.available).toBeFalse();
          expect(model.displayAuthority.routeTimeline).toBe("unavailable");
          expect(hasWarning(model, "ACTIVE_CRUISE_ROUTE_TIMELINE_UNAVAILABLE")).toBeTrue(serializeJSON(model.warnings));
          expect(hasLegacyRoutePlanAuthority(model)).toBeFalse(serializeJSON(model.displayAuthority));
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });

      it("does not expose ROUTEPLAN activeCruiseView or activeCruiseHooks fields as display authority", function() {
        var prefix = variables.naming.buildPrefix("active-cruise-v2", "no-legacy");
        var sessionApi = buildSessionApiSupport();
        var localCreated = newCreatedTracker();
        var asset = {};
        var model = {};

        try {
          url.testUserId = variables.sessionApiUser.userId;
          asset = createActivatedScheduledTrip(sessionApi, prefix, localCreated);
          model = variables.viewModelService.getActiveCruiseViewModel(variables.sessionApiUser.userId, asset.floatPlanId);

          expect(structKeyExists(model, "ROUTEPLAN")).toBeFalse();
          expect(structKeyExists(model, "routePlan")).toBeFalse();
          expect(structKeyExists(model, "activeCruiseView")).toBeFalse();
          expect(structKeyExists(model, "activeCruiseHooks")).toBeFalse();
          expect(model.displayAuthority.primary).notToBe("ROUTEPLAN");
          expect(model.displayAuthority.routeTimeline).notToBe("ROUTEPLAN");
          expect(hasLegacyRoutePlanAuthority(model)).toBeFalse(serializeJSON(model.displayAuthority));
        } finally {
          cleanupRouteLinkedAssetsForApi(sessionApi, localCreated);
        }
      });
    });
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

  private struct function createActivatedLockedScheduledTrip(required any apiSupport, required string prefix, required struct created) {
    var asset = createLockedRouteLinkedDraftForApi(arguments.apiSupport, arguments.prefix, arguments.created);
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
    var uniqueEmail = "fpw-active-cruise-v2-" & replace(createUUID(), "-", "", "all") & "@example.com";
    var payload = signupApi.postJson("/api/v1/join.cfc?method=handle", {
      firstName = "FPW",
      lastName = "ActiveCruiseV2",
      email = uniqueEmail,
      password = "changeIt",
      confirmPassword = "changeIt",
      termsAccepted = true
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

  private struct function createRouteLinkedDraftForApi(required any apiSupport, required string prefix, required struct created) {
    var cleanupSupport = new fpw.tests.support.FpwCleanupSupport().init(arguments.apiSupport);
    cleanupSupport.cleanupCurrentRouteFloatPlanGroup();

    var vesselPayload = arguments.apiSupport.saveVessel({
      vesselId = 0,
      vesselName = variables.naming.buildName(arguments.prefix, "AC V2 Vessel"),
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
      route_name = variables.naming.buildName(arguments.prefix, "AC V2 Route"),
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

  private struct function createLockedRouteLinkedDraftForApi(required any apiSupport, required string prefix, required struct created) {
    var cleanupSupport = new fpw.tests.support.FpwCleanupSupport().init(arguments.apiSupport);
    cleanupSupport.cleanupCurrentRouteFloatPlanGroup();

    var vesselPayload = arguments.apiSupport.saveVessel({
      vesselId = 0,
      vesselName = variables.naming.buildName(arguments.prefix, "AC V2 Locked Vessel"),
      type = "Cruiser",
      length = 34,
      color = "White"
    });
    var vesselId = val(vesselPayload.VESSELID ?: 0);
    var options = arguments.apiSupport.routeBuilder("routegen_getoptions", {
      template_code = "GL_REUSE_V2",
      direction = "CCW"
    });
    ensureSuccess(vesselPayload, "save locked-route vessel");
    ensureSuccess(options, "load locked route template options");
    expect(arrayLen(options.DATA.startOptions)).toBeGT(0, serializeJSON(options));
    expect(arrayLen(options.DATA.endOptions)).toBeGT(0, serializeJSON(options));

    var generate = arguments.apiSupport.routeBuilder("routegen_generate", {
      route_name = variables.naming.buildName(arguments.prefix, "AC V2 Locked Route"),
      template_code = "GL_REUSE_V2",
      direction = "CCW",
      start_segment_id = options.DATA.startOptions[1].segment_id,
      end_segment_id = options.DATA.endOptions[1].segment_id,
      start_location_label = options.DATA.startOptions[1].label,
      end_location_label = options.DATA.endOptions[1].label,
      start_date = "2026-04-09",
      optional_stop_flags = []
    });
    ensureSuccess(generate, "generate locked route");

    var routeCode = trim(toString(generate.ROUTE_CODE ?: generate.DATA.route_code ?: ""));
    var buildPayload = arguments.apiSupport.routeBuilder("buildFloatPlansFromRoute", {
      routeCode = routeCode,
      mode = "DAILY",
      vesselId = vesselId,
      rebuild = 0
    });
    ensureSuccess(buildPayload, "build locked route-linked float plans");

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
      name = variables.naming.buildName(arguments.prefix, "AC V2 Contact"),
      phone = "5555551212",
      email = "fpw-active-cruise-v2-contact-" & lCase(replace(createUUID(), "-", "", "all")) & "@example.com"
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

  private struct function loadFirstRouteMapOverrideContext(required numeric floatPlanId) {
    var qContext = queryExecute(
      "SELECT
          fp.userId AS user_id,
          fp.route_instance_id,
          ri.generated_route_id,
          ril.id AS route_leg_id,
          ril.leg_order,
          ril.segment_id,
          ril.start_lat,
          ril.start_lng,
          ril.end_lat,
          ril.end_lng
       FROM floatplans fp
       INNER JOIN route_instances ri
          ON ri.id = fp.route_instance_id
       INNER JOIN route_instance_legs ril
          ON ril.route_instance_id = fp.route_instance_id
       WHERE fp.floatPlanId = :floatPlanId
       ORDER BY ril.leg_order ASC, ril.id ASC
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );

    expect(qContext.recordCount).toBe(1);
    expect(val(qContext.generated_route_id[1])).toBeGT(0, serializeJSON(qContext));
    expect(val(qContext.route_leg_id[1])).toBeGT(0, serializeJSON(qContext));
    expect(isNumeric(qContext.start_lat[1])).toBeTrue(serializeJSON(qContext));
    expect(isNumeric(qContext.start_lng[1])).toBeTrue(serializeJSON(qContext));
    expect(isNumeric(qContext.end_lat[1])).toBeTrue(serializeJSON(qContext));
    expect(isNumeric(qContext.end_lng[1])).toBeTrue(serializeJSON(qContext));

    return {
      user_id = val(qContext.user_id[1]),
      route_instance_id = val(qContext.route_instance_id[1]),
      route_id = val(qContext.generated_route_id[1]),
      route_leg_id = val(qContext.route_leg_id[1]),
      route_leg_order = val(qContext.leg_order[1]),
      segment_id = val(qContext.segment_id[1]),
      start_lat = val(qContext.start_lat[1]),
      start_lng = val(qContext.start_lng[1]),
      end_lat = val(qContext.end_lat[1]),
      end_lng = val(qContext.end_lng[1])
    };
  }

  private array function buildOverrideGeometryPoints(required struct overrideContext) {
    var midLat = ((arguments.overrideContext.start_lat + arguments.overrideContext.end_lat) / 2) + 0.05;
    var midLng = ((arguments.overrideContext.start_lng + arguments.overrideContext.end_lng) / 2) + 0.05;

    return [
      { lon = arguments.overrideContext.start_lng, lat = arguments.overrideContext.start_lat },
      { lon = midLng, lat = midLat },
      { lon = arguments.overrideContext.end_lng, lat = arguments.overrideContext.end_lat }
    ];
  }

  private void function saveRouteLegOverrideForTest(required struct overrideContext, required array overridePoints) {
    queryExecute(
      "INSERT INTO route_leg_user_overrides
          (user_id, route_id, route_leg_id, route_leg_order, segment_id, geometry_json, computed_nm, override_fields_json)
       VALUES
          (:userId, :routeId, :routeLegId, :routeLegOrder, :segmentId, :geometryJson, :computedNm, NULL)
       ON DUPLICATE KEY UPDATE
          route_leg_order = VALUES(route_leg_order),
          segment_id = VALUES(segment_id),
          geometry_json = VALUES(geometry_json),
          computed_nm = VALUES(computed_nm),
          override_fields_json = NULL,
          updated_at = NOW()",
      {
        userId = { value = arguments.overrideContext.user_id, cfsqltype = "cf_sql_integer" },
        routeId = { value = arguments.overrideContext.route_id, cfsqltype = "cf_sql_integer" },
        routeLegId = { value = arguments.overrideContext.route_leg_id, cfsqltype = "cf_sql_integer" },
        routeLegOrder = { value = arguments.overrideContext.route_leg_order, cfsqltype = "cf_sql_integer" },
        segmentId = { value = arguments.overrideContext.segment_id, cfsqltype = "cf_sql_integer", null = (arguments.overrideContext.segment_id LTE 0) },
        geometryJson = { value = serializeJSON(arguments.overridePoints), cfsqltype = "cf_sql_longvarchar" },
        computedNm = { value = 12.34, cfsqltype = "cf_sql_decimal", scale = 2 }
      },
      { datasource = "fpw" }
    );
  }

  private void function deleteRouteLegOverrideForTest(required struct overrideContext) {
    queryExecute(
      "DELETE FROM route_leg_user_overrides
       WHERE user_id = :userId
         AND route_id = :routeId
         AND route_leg_id = :routeLegId",
      {
        userId = { value = arguments.overrideContext.user_id, cfsqltype = "cf_sql_integer" },
        routeId = { value = arguments.overrideContext.route_id, cfsqltype = "cf_sql_integer" },
        routeLegId = { value = arguments.overrideContext.route_leg_id, cfsqltype = "cf_sql_integer" }
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

  private struct function postActiveCruiseCheckinWithApi(required any apiSupport, required numeric floatPlanId, required string statusValue, string note = "") {
    return arguments.apiSupport.postJson("/api/v1/floatplan.cfc?method=handle&action=checkin", {
      floatPlanId = arguments.floatPlanId,
      status = arguments.statusValue,
      note = arguments.note
    });
  }

  private struct function postCompleteLegWithApi(required any apiSupport, required numeric floatPlanId, required numeric expectedLegOrder) {
    return arguments.apiSupport.postJson("/api/v1/floatplan.cfc?method=handle&action=completeleg", {
      floatPlanId = arguments.floatPlanId,
      expectedLegOrder = arguments.expectedLegOrder
    });
  }

  private struct function postStartNextLegWithApi(required any apiSupport, required numeric floatPlanId) {
    return arguments.apiSupport.postJson("/api/v1/floatplan.cfc?method=handle&action=startnextleg", {
      floatPlanId = arguments.floatPlanId
    });
  }

  private struct function postActiveCruisePaceWithApi(required any apiSupport, required numeric floatPlanId, required string paceValue) {
    return arguments.apiSupport.postJson("/api/v1/floatplan.cfc?method=handle&action=updateactivepace", {
      floatPlanId = arguments.floatPlanId,
      pace = arguments.paceValue
    });
  }

  private struct function postActiveCruiseDailyStartWithApi(required any apiSupport, required numeric floatPlanId, required string dailyStartLocalTime) {
    return arguments.apiSupport.postJson("/api/v1/floatplan.cfc?method=handle&action=updatedailystart", {
      floatPlanId = arguments.floatPlanId,
      dailyStartLocalTime = arguments.dailyStartLocalTime
    });
  }

  private string function loadDailyStartLocalTimeForFloatPlan(required numeric floatPlanId) {
    var qDailyStart = queryExecute(
      "SELECT dailyStartLocalTime
       FROM floatplans
       WHERE floatPlanId = :floatPlanId
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    if (qDailyStart.recordCount EQ 0) {
      return "";
    }
    return normalizeDailyStartForTest(qDailyStart.dailyStartLocalTime[1]);
  }

  private string function normalizeDailyStartForTest(required any value) {
    var raw = "";
    if (isNull(arguments.value)) {
      return "";
    }
    if (isDate(arguments.value)) {
      return timeFormat(arguments.value, "HH:mm");
    }
    raw = trim(toString(arguments.value));
    if (len(raw) GTE 5) {
      return left(raw, 5);
    }
    return raw;
  }

  private void function seedRouteInputsForPaceTest(required numeric floatPlanId, required struct routeInputs) {
    var routeInstanceId = loadRouteInstanceIdForFloatPlan(arguments.floatPlanId);
    expect(routeInstanceId).toBeGT(0);
    queryExecute(
      "UPDATE route_instances
       SET routegen_inputs_json = :routeInputsJson
       WHERE id = :routeInstanceId",
      {
        routeInputsJson = { value = serializeJSON(arguments.routeInputs), cfsqltype = "cf_sql_longvarchar" },
        routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private struct function loadRouteInputsForFloatPlan(required numeric floatPlanId) {
    var qInputs = queryExecute(
      "SELECT ri.routegen_inputs_json
       FROM floatplans fp
       INNER JOIN route_instances ri
          ON ri.id = fp.route_instance_id
       WHERE fp.floatPlanId = :floatPlanId
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    if (qInputs.recordCount EQ 0 OR isNull(qInputs.routegen_inputs_json[1]) OR !len(trim(toString(qInputs.routegen_inputs_json[1])))) {
      return {};
    }
    return deserializeJSON(qInputs.routegen_inputs_json[1]);
  }

  private struct function loadActiveCruiseHeroForTest(required numeric floatPlanId) {
    var payload = variables.voyageService.getActiveCruiseHeroCanonical(variables.sessionApiUser.userId, arguments.floatPlanId);
    expect(payload.SUCCESS ?: false).toBeTrue(serializeJSON(payload));
    return payload;
  }

  private struct function loadFollowBootstrapForTest(required any apiSupport, required numeric floatPlanId) {
    var ensureStream = arguments.apiSupport.postJson("/api/v1/voyage.cfc?method=handle&action=ownerensurestream", {});
    var qStream = queryExecute(
      "SELECT id
       FROM voyage_streams
       WHERE floatplan_id = :floatPlanId
         AND owner_user_id = :ownerUserId
       ORDER BY id DESC
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        ownerUserId = { value = variables.sessionApiUser.userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    var streamId = 0;
    var payload = {};

    expect(ensureStream.SUCCESS ?: false).toBeTrue(serializeJSON(ensureStream));
    expect(qStream.recordCount).toBe(1);
    streamId = val(qStream.id[1]);
    payload = arguments.apiSupport.getJson("/api/v1/voyage.cfc?method=handle&action=getStreamBootstrap&stream_id=" & streamId);
    expect(payload.SUCCESS ?: false).toBeTrue(serializeJSON(payload));
    return payload;
  }

  private void function forceStaleActiveTripPaceOverride(required numeric floatPlanId, required string paceValue, required numeric staleFloatPlanId) {
    var inputs = loadRouteInputsForFloatPlan(arguments.floatPlanId);
    inputs.active_trip_pace = arguments.paceValue;
    inputs.active_trip_effective_speed_kn = 5;
    inputs.active_trip_weather_adjusted_speed_kn = 3.75;
    inputs.active_trip_speed_source = "test_stale_override";
    inputs.active_trip_floatplan_id = arguments.staleFloatPlanId;
    seedRouteInputsForPaceTest(arguments.floatPlanId, inputs);
  }

  private numeric function loadRouteInstanceIdForFloatPlan(required numeric floatPlanId) {
    var qRoute = queryExecute(
      "SELECT route_instance_id
       FROM floatplans
       WHERE floatPlanId = :floatPlanId
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    if (qRoute.recordCount EQ 0 OR isNull(qRoute.route_instance_id[1]) OR !isNumeric(qRoute.route_instance_id[1])) {
      return 0;
    }
    return val(qRoute.route_instance_id[1]);
  }

  private struct function recordCanonicalCheckin(
    required numeric floatPlanId,
    required string statusValue,
    required string statusLabel,
    required string note,
    required numeric minuteOffset,
    any occurredAtUtc = ""
  ) {
    var occurredAt = (isDate(arguments.occurredAtUtc) ? arguments.occurredAtUtc : dateAdd("n", arguments.minuteOffset, now()));
    return variables.activityWriterService.recordActiveCruiseCheckin(
      floatPlanId = arguments.floatPlanId,
      userId = variables.sessionApiUser.userId,
      status = arguments.statusValue,
      checkinContext = "active_route",
      occurredAtUtc = occurredAt,
      monitoringId = 0,
      sourcePostId = 0,
      payload = {
        "status_label" = arguments.statusLabel,
        "monitoring_status" = arguments.statusValue,
        "checkin_context" = "active_route",
        "note_body" = arguments.note,
        "source_post_id" = 0
      }
    );
  }

  private void function markFirstLegStarted(required numeric floatPlanId) {
    queryExecute(
      "UPDATE route_instance_leg_progress rilp
       INNER JOIN floatplans fp
          ON fp.route_instance_id = rilp.route_instance_id
         AND fp.userId = rilp.user_id
       SET rilp.status = 'STARTED',
           rilp.leg_started_at = UTC_TIMESTAMP()
       WHERE fp.floatPlanId = :floatPlanId
         AND rilp.leg_order = 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function setActiveLegStartedAtForPaceTest(required numeric floatPlanId, required any startedAtUtc) {
    queryExecute(
      "UPDATE route_instance_leg_progress rilp
       INNER JOIN floatplans fp
          ON fp.route_instance_id = rilp.route_instance_id
         AND fp.userId = rilp.user_id
       SET rilp.status = 'STARTED',
           rilp.leg_started_at = :startedAtUtc
       WHERE fp.floatPlanId = :floatPlanId
         AND rilp.leg_order = 1",
      {
        startedAtUtc = { value = arguments.startedAtUtc, cfsqltype = "cf_sql_timestamp" },
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );

    queryExecute(
      "UPDATE floatplan_activity_segments
       SET started_at_utc = :startedAtUtc
       WHERE floatplan_id = :floatPlanId
         AND ended_at_utc IS NULL
         AND UPPER(TRIM(segment_type)) = 'UNDERWAY'",
      {
        startedAtUtc = { value = arguments.startedAtUtc, cfsqltype = "cf_sql_timestamp" },
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function markMonitoringSecureForNight(required numeric floatPlanId) {
    queryExecute(
      "UPDATE floatplan_monitoring
       SET secure_for_night = 1,
           secure_for_night_until = DATE_ADD(UTC_TIMESTAMP(), INTERVAL 12 HOUR),
           last_checkin_status = 'SECURE_FOR_NIGHT',
           last_checkin_at = COALESCE(last_checkin_at, UTC_TIMESTAMP())
       WHERE float_plan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function setMonitoringState(required numeric floatPlanId, required string monitorState) {
    queryExecute(
      "UPDATE floatplan_monitoring
       SET monitor_state = :monitorState,
           missed_at = CASE WHEN :monitorState IN ('MISSED', 'ESCALATED') THEN COALESCE(missed_at, UTC_TIMESTAMP()) ELSE missed_at END,
           escalated_at = CASE WHEN :monitorState = 'ESCALATED' THEN COALESCE(escalated_at, UTC_TIMESTAMP()) ELSE escalated_at END
       WHERE float_plan_id = :floatPlanId",
      {
        monitorState = { value = arguments.monitorState, cfsqltype = "cf_sql_varchar" },
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function markAssistanceNeeded(required numeric floatPlanId) {
    queryExecute(
      "UPDATE floatplan_monitoring
       SET monitor_state = 'ACTIVE',
           last_checkin_status = 'NEED_ATTENTION',
           last_checkin_at = UTC_TIMESTAMP()
       WHERE float_plan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function markAllLegsCompleted(required numeric floatPlanId) {
    queryExecute(
      "UPDATE route_instance_leg_progress rilp
       INNER JOIN floatplans fp
          ON fp.route_instance_id = rilp.route_instance_id
         AND fp.userId = rilp.user_id
       SET rilp.status = 'COMPLETED',
           rilp.leg_started_at = COALESCE(rilp.leg_started_at, UTC_TIMESTAMP()),
           rilp.completed_at = UTC_TIMESTAMP()
       WHERE fp.floatPlanId = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function markPlanClosed(required numeric floatPlanId) {
    queryExecute(
      "UPDATE floatplans
       SET status = 'CLOSED',
           closedAt = UTC_TIMESTAMP()
       WHERE floatPlanId = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "UPDATE floatplan_monitoring
       SET monitor_state = 'CLOSED',
           closed_at = UTC_TIMESTAMP()
       WHERE float_plan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function markPlanCancelled(required numeric floatPlanId) {
    queryExecute(
      "UPDATE floatplans
       SET status = 'CANCELLED',
           closedAt = UTC_TIMESTAMP()
       WHERE floatPlanId = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "UPDATE floatplan_monitoring
       SET monitor_state = 'CLOSED',
           closed_at = UTC_TIMESTAMP()
       WHERE float_plan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function deleteRouteLegRows(required numeric floatPlanId) {
    queryExecute(
      "DELETE ril
       FROM route_instance_legs ril
       INNER JOIN floatplans fp
          ON fp.route_instance_id = ril.route_instance_id
       WHERE fp.floatPlanId = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private struct function loadRouteProgressCounts(required numeric floatPlanId) {
    var qCounts = queryExecute(
      "SELECT
          COUNT(DISTINCT rilp.id) AS progress_row_count,
          SUM(CASE WHEN rilp.leg_started_at IS NOT NULL THEN 1 ELSE 0 END) AS started_rows,
          SUM(CASE WHEN rilp.completed_at IS NOT NULL OR UPPER(TRIM(COALESCE(rilp.status, ''))) = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_rows
       FROM floatplans fp
       LEFT JOIN route_instance_leg_progress rilp
          ON rilp.route_instance_id = fp.route_instance_id
         AND rilp.user_id = fp.userId
       WHERE fp.floatPlanId = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    expect(qCounts.recordCount).toBe(1);
    return {
      progress_row_count = val(qCounts.progress_row_count[1]),
      started_rows = val(qCounts.started_rows[1]),
      completed_rows = val(qCounts.completed_rows[1])
    };
  }

  private numeric function countActivitySegments(required numeric floatPlanId) {
    var qSegments = queryExecute(
      "SELECT COUNT(*) AS segment_count
       FROM floatplan_activity_segments
       WHERE floatplan_id = :floatPlanId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    return val(qSegments.segment_count[1]);
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

  private struct function findCheckinEventPayload(required numeric floatPlanId, required string statusValue) {
    var qEvent = queryExecute(
      "SELECT payload_json
       FROM floatplan_events
       WHERE floatplan_id = :floatPlanId
         AND event_type = 'CHECKIN_RECEIVED'
         AND source = 'active_cruise_checkin'
         AND event_status = :statusValue
         AND voided_at_utc IS NULL
       ORDER BY occurred_at_utc DESC, id DESC
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        statusValue = { value = arguments.statusValue, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    if (qEvent.recordCount EQ 0 OR !len(trim(toString(qEvent.payload_json[1])))) {
      return {};
    }
    return deserializeJSON(qEvent.payload_json[1]);
  }

  private numeric function countRouteActionEvents(required numeric floatPlanId, string eventType = "") {
    var sql = "
      SELECT COUNT(*) AS event_count
      FROM floatplan_events
      WHERE floatplan_id = :floatPlanId
        AND source = 'active_cruise_route_action'
        AND voided_at_utc IS NULL";
    var params = {
      floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
    };
    var qEvents = queryNew("");
    if (len(trim(arguments.eventType))) {
      sql &= " AND event_type = :eventType";
      params.eventType = { value = arguments.eventType, cfsqltype = "cf_sql_varchar" };
    }
    qEvents = queryExecute(sql, params, { datasource = "fpw" });
    return val(qEvents.event_count[1]);
  }

  private struct function findRouteActionEventPayload(required numeric floatPlanId, required string eventType) {
    var qEvent = queryExecute(
      "SELECT payload_json
       FROM floatplan_events
       WHERE floatplan_id = :floatPlanId
         AND event_type = :eventType
         AND source = 'active_cruise_route_action'
         AND voided_at_utc IS NULL
       ORDER BY occurred_at_utc DESC, id DESC
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        eventType = { value = arguments.eventType, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    if (qEvent.recordCount EQ 0 OR !len(trim(toString(qEvent.payload_json[1])))) {
      return {};
    }
    return deserializeJSON(qEvent.payload_json[1]);
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

  private struct function loadFinalCloseState(required numeric floatPlanId) {
    var qState = queryExecute(
      "SELECT
          UPPER(TRIM(COALESCE(fp.status, ''))) AS status_value,
          fp.closedAt AS fp_closed_at,
          UPPER(TRIM(COALESCE(m.monitor_state, ''))) AS monitor_state_value,
          m.closed_at AS monitor_closed_at
       FROM floatplans fp
       LEFT JOIN floatplan_monitoring m
         ON m.float_plan_id = fp.floatPlanId
       WHERE fp.floatPlanId = :floatPlanId
       ORDER BY m.id DESC
       LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    expect(qState.recordCount).toBe(1);
    return {
      status = trim(toString(qState.status_value[1])),
      closed_at_present = isDate(qState.fp_closed_at[1]),
      monitor_state = trim(toString(qState.monitor_state_value[1])),
      monitor_closed_at_present = isDate(qState.monitor_closed_at[1])
    };
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

  private boolean function isSuccessPayload(required struct payload) {
    if (structKeyExists(arguments.payload, "SUCCESS") AND arguments.payload.SUCCESS EQ true) {
      return true;
    }
    if (structKeyExists(arguments.payload, "success") AND arguments.payload.success EQ true) {
      return true;
    }
    return false;
  }

  private boolean function hasWarning(required struct model, required string warningCode) {
    for (var warningItem in arguments.model.warnings) {
      if (isStruct(warningItem) AND structKeyExists(warningItem, "code") AND compareNoCase(warningItem.code, arguments.warningCode) EQ 0) {
        return true;
      }
    }
    return false;
  }

  private struct function findStatusOption(required struct model, required string statusName) {
    for (var statusOption in arguments.model.checkIn.allowedStatusOptions) {
      if (isStruct(statusOption) AND structKeyExists(statusOption, "status") AND compareNoCase(statusOption.status, arguments.statusName) EQ 0) {
        return statusOption;
      }
    }
    return {};
  }

  private struct function findHistoryItem(required struct model, required string statusValue) {
    for (var historyItem in arguments.model.checkInHistory.items) {
      if (isStruct(historyItem) AND structKeyExists(historyItem, "status") AND compareNoCase(historyItem.status, arguments.statusValue) EQ 0) {
        return historyItem;
      }
    }
    return {};
  }

  private struct function findTimelineItem(required struct model, required string eventType) {
    for (var timelineItem in arguments.model.privateTimeline.items) {
      if (isStruct(timelineItem) AND structKeyExists(timelineItem, "eventType") AND compareNoCase(timelineItem.eventType, arguments.eventType) EQ 0) {
        return timelineItem;
      }
    }
    return {};
  }

  private boolean function findLegWarning(required struct leg, required string warningCode) {
    if (!structKeyExists(arguments.leg, "warnings") OR !isArray(arguments.leg.warnings)) {
      return false;
    }
    for (var warningItem in arguments.leg.warnings) {
      if (isStruct(warningItem) AND structKeyExists(warningItem, "code") AND compareNoCase(warningItem.code, arguments.warningCode) EQ 0) {
        return true;
      }
    }
    return false;
  }

  private struct function findCurrentTimelineLegForTest(required struct routeTimeline) {
    if (!structKeyExists(arguments.routeTimeline, "legs") OR !isArray(arguments.routeTimeline.legs)) {
      return {};
    }
    for (var leg in arguments.routeTimeline.legs) {
      if (isStruct(leg) AND structKeyExists(leg, "isCurrent") AND leg.isCurrent EQ true) {
        return leg;
      }
    }
    return {};
  }

  private struct function findFirstFutureTimelineLegForTest(required struct routeTimeline) {
    if (!structKeyExists(arguments.routeTimeline, "legs") OR !isArray(arguments.routeTimeline.legs)) {
      return {};
    }
    for (var leg in arguments.routeTimeline.legs) {
      if (isStruct(leg) AND structKeyExists(leg, "state") AND compareNoCase(leg.state, "future") EQ 0) {
        return leg;
      }
    }
    return {};
  }

  private date function parseUtcForTest(required string utcValue) {
    var normalized = replace(replace(trim(arguments.utcValue), "T", " ", "one"), "Z", "", "one");
    return parseDateTime(normalized);
  }

  private numeric function roundTo2Numeric(required any value) {
    if (!isNumeric(arguments.value)) {
      return 0;
    }
    return round(val(arguments.value) * 100) / 100;
  }

  private boolean function hasLegacyRoutePlanAuthority(required struct model) {
    var display = serializeJSON(arguments.model.displayAuthority);
    if (findNoCase('"ROUTEPLAN"', display) GT 0) {
      return true;
    }
    if (structKeyExists(arguments.model, "routeTimeline") AND isStruct(arguments.model.routeTimeline) AND structKeyExists(arguments.model.routeTimeline, "authority")) {
      return compareNoCase(arguments.model.routeTimeline.authority, "ROUTEPLAN") EQ 0;
    }
    return false;
  }

  private void function ensureSuccess(required struct payload, required string label) {
    if (!isSuccessPayload(arguments.payload)) {
      throw(message = "Active Cruise V2 view model setup failed: " & arguments.label, detail = serializeJSON(arguments.payload));
    }
  }
}
