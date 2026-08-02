<cfcomponent output="false">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfscript>
      variables.datasource = arguments.datasource;
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="getActiveCruiseViewModel" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      var model = baseModel();
      var qPlan = queryNew("");
      var qMonitoring = queryNew("");
      var qProgress = queryNew("");
      var projection = {};
      var routeTimeline = {};
      var routeTimelineAvailable = false;
      var routeTimelineAuthority = "";
      var motionState = "unknown";
      var safetyState = "normal";
      var tripState = "unknown_error";
      var progressSummary = {};
      var explicitStartProof = false;
      var memberGateResult = {};

      model.generatedAtUtc = formatUtc(now());

      if (arguments.userId LTE 0 OR arguments.floatPlanId LTE 0) {
        model.message = "userId and floatPlanId are required.";
        addWarning(model, "ACTIVE_CRUISE_VIEW_MODEL_INVALID_INPUT", model.message, "view_model");
        finalizeAuthorityWarnings(model);
        return model;
      }

      memberGateResult = getMemberAccessGateService().requireTripOperationalAccess(
        arguments.userId,
        arguments.floatPlanId
      );
      if (structKeyExists(memberGateResult, "tripAccess") AND isStruct(memberGateResult.tripAccess)) {
        model.tripAccess = duplicate(memberGateResult.tripAccess);
      }
      if (!memberGateResult.allowed) {
        model.message = memberGateResult.response.MESSAGE;
        model.errorCode = memberGateResult.response.ERROR.CODE;
        if (model.errorCode EQ "TRIP_ACCESS_EXPIRED") {
          model.tripState = "expired_access";
          model.floatPlan = { "id" = arguments.floatPlanId };
        }
        addWarning(model, memberGateResult.response.ERROR.CODE, memberGateResult.response.MESSAGE, "member_entitlements");
        finalizeAuthorityWarnings(model);
        return model;
      }

      qPlan = loadPlanContext(arguments.userId, arguments.floatPlanId);
      if (qPlan.recordCount EQ 0) {
        model.message = "Active cruise float plan was not found for this user.";
        addWarning(model, "ACTIVE_CRUISE_FLOATPLAN_NOT_FOUND", model.message, "floatplans");
        finalizeAuthorityWarnings(model);
        return model;
      }

      model.floatPlan = buildFloatPlanSection(qPlan);
      model.route = buildRouteSection(qPlan);
      model.checkInHistory = loadCheckInHistory(arguments.userId, arguments.floatPlanId, qPlan);
      model.map = buildMapSection(qPlan, model.checkInHistory);
      model.floatPlanInfo = buildFloatPlanInfoSection(qPlan);
      model.contacts = loadContacts(arguments.floatPlanId);
      model.captainLog = loadCaptainLog(arguments.userId, arguments.floatPlanId);
      model.privateTimeline = loadPrivateTimeline(arguments.userId, arguments.floatPlanId, qPlan);

      if (safeNumber(qPlan.route_instance_id[1]) LTE 0) {
        model.message = "Active Cruise V2 requires a route-backed active float plan.";
        addWarning(model, "ACTIVE_CRUISE_ROUTE_INSTANCE_MISSING", model.message, "floatplans.route_instance_id");
        finalizeAuthorityWarnings(model);
        return model;
      }

      qMonitoring = loadMonitoring(arguments.userId, arguments.floatPlanId);
      model.monitoring = buildMonitoringSection(qMonitoring, qPlan);
      model.floatPlanMonitor = buildFloatPlanMonitorSection(qPlan, qMonitoring);
      qProgress = loadRouteProgress(safeNumber(qPlan.route_instance_id[1]), arguments.userId);
      progressSummary = summarizeRouteProgress(qProgress);

      projection = loadProjection(arguments.floatPlanId, model);
      routeTimeline = extractRouteTimeline(projection);
      routeTimeline = enrichRouteTimelineFuel(qPlan, routeTimeline);
      routeTimelineAvailable = structKeyExists(routeTimeline, "available") AND routeTimeline.available EQ true;
      routeTimelineAuthority = (structKeyExists(routeTimeline, "authority") ? safeString(routeTimeline.authority) : "unavailable");

      model.routeTimeline = routeTimeline;
      model.currentLeg = buildCurrentLegSection(qPlan, projection, routeTimeline);
      model.currentLeg.fuel = buildCurrentLegFuelSection(qPlan, routeTimeline, model.currentLeg);
      model.weather = buildWeatherSection(qPlan, model.map, model.currentLeg);
      model.pace = buildPaceSection(qPlan, projection, routeTimeline);

      explicitStartProof = hasExplicitStartProof(qPlan, projection, progressSummary);
      motionState = deriveMotionState(qPlan, qMonitoring, projection, routeTimeline, progressSummary, explicitStartProof);
      safetyState = deriveSafetyState(qMonitoring);
      tripState = deriveTripState(motionState, safetyState);
      model.checkIn = buildCheckInSection(qPlan, model.monitoring, tripState, motionState);
      model.actions = buildActionsSection(model.monitoring, model.currentLeg, routeTimeline, qPlan, tripState, motionState, progressSummary);

      if (routeTimelineAvailable) {
        model.displayAuthority.routeTimeline = routeTimelineAuthority;
      } else {
        model.displayAuthority.routeTimeline = "unavailable";
        addWarning(model, "ACTIVE_CRUISE_ROUTE_TIMELINE_UNAVAILABLE", "Canonical projection routeTimeline is unavailable. Active Cruise V2 must not fall back to legacy ROUTEPLAN.", "TripProgressProjectionService.routeTimeline");
      }

      if (structKeyExists(projection, "success") AND projection.success EQ true) {
        if (routeTimelineAvailable AND routeTimelineAuthority EQ "canonical_projection") {
          model.displayAuthority.primary = "canonical_projection";
        } else if (explicitStartProof) {
          model.displayAuthority.primary = "route_instance_leg_progress_start_proof";
        } else if (routeTimelineAvailable AND routeTimelineAuthority EQ "scheduled_projection") {
          model.displayAuthority.primary = "scheduled_projection";
        } else {
          model.displayAuthority.primary = "projection_unavailable";
        }
      } else if (explicitStartProof) {
        model.displayAuthority.primary = "route_instance_leg_progress_start_proof";
      } else {
        model.displayAuthority.primary = "projection_unavailable";
      }

      if (model.monitoring.available) {
        model.displayAuthority.monitoring = "floatplan_monitoring";
      } else if (motionState EQ "scheduled" AND !explicitStartProof) {
        model.displayAuthority.monitoring = "scheduled_not_started";
      } else {
        model.displayAuthority.monitoring = "unavailable";
        addWarning(model, "ACTIVE_CRUISE_MONITORING_UNAVAILABLE", "Monitoring row is unavailable for this route-backed active float plan.", "floatplan_monitoring");
      }

      addProjectionWarnings(model, projection);
      addConsistencyWarnings(model, qPlan, projection, routeTimeline, progressSummary, explicitStartProof);

      model.tripState = tripState;
      model.motionState = motionState;
      model.safetyState = safetyState;
      model.hero = buildHeroSection(model);
      model.success = (tripState NEQ "unknown_error");
      model.message = (model.success ? "Active Cruise V2 view model generated." : "Active Cruise V2 view model could not be generated from canonical authorities.");
      finalizeAuthorityWarnings(model);
      return model;
    </cfscript>
  </cffunction>

  <cffunction name="getPublicFollowAuthority" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      var out = basePublicFollowAuthority();
      var authorityModel = baseModel();
      var qPlan = queryNew("");
      var qMonitoring = queryNew("");
      var qProgress = queryNew("");
      var projection = {};
      var routeTimeline = {};
      var routeSummary = {};
      var floatPlan = {};
      var route = {};
      var monitoring = {};
      var currentLeg = {};
      var todayProgress = {};
      var motionState = "unknown";
      var safetyState = "normal";
      var tripState = "unknown_error";
      var progressSummary = {};
      var explicitStartProof = false;
      var timezone = "UTC";
      var publicHealth = {};
      var currentLegLabel = "";
      var memberGateResult = {};

      if (arguments.userId LTE 0 OR arguments.floatPlanId LTE 0) {
        return out;
      }

      memberGateResult = getMemberAccessGateService().requireTripOperationalAccess(
        arguments.userId,
        arguments.floatPlanId
      );
      if (!memberGateResult.allowed) {
        out.errorCode = memberGateResult.response.ERROR.CODE;
        out.message = memberGateResult.response.MESSAGE;
        return out;
      }

      qPlan = loadPlanContext(arguments.userId, arguments.floatPlanId);
      if (qPlan.recordCount EQ 0 OR safeNumber(qPlan.route_instance_id[1]) LTE 0) {
        return out;
      }

      authorityModel.generatedAtUtc = formatUtc(now());
      floatPlan = buildFloatPlanSection(qPlan);
      route = buildRouteSection(qPlan);
      timezone = safeString(floatPlan.timezone);
      if (!len(timezone)) {
        timezone = resolveTimezone(qPlan);
      }

      qMonitoring = loadMonitoring(arguments.userId, arguments.floatPlanId);
      monitoring = buildMonitoringSection(qMonitoring, qPlan);
      qProgress = loadRouteProgress(safeNumber(qPlan.route_instance_id[1]), arguments.userId);
      progressSummary = summarizeRouteProgress(qProgress);
      projection = loadProjection(arguments.floatPlanId, authorityModel);
      routeTimeline = extractRouteTimeline(projection);
      routeSummary = (
        structKeyExists(routeTimeline, "summary")
        AND isStruct(routeTimeline.summary)
        ? routeTimeline.summary
        : {}
      );
      currentLeg = buildCurrentLegSection(qPlan, projection, routeTimeline);
      todayProgress = (
        structKeyExists(projection, "todayProgress")
        AND isStruct(projection.todayProgress)
        ? projection.todayProgress
        : {}
      );

      explicitStartProof = hasExplicitStartProof(qPlan, projection, progressSummary);
      motionState = deriveMotionState(qPlan, qMonitoring, projection, routeTimeline, progressSummary, explicitStartProof);
      safetyState = deriveSafetyState(qMonitoring);
      tripState = deriveTripState(motionState, safetyState);
      publicHealth = buildPublicFollowHealth(monitoring);

      currentLegLabel = firstNonEmpty([
        safeString(currentLeg.fromName) & (len(safeString(currentLeg.fromName)) AND len(safeString(currentLeg.toName)) ? " to " : "") & safeString(currentLeg.toName),
        safeString(currentLeg.statusLabel)
      ]);

      out.identity = {
        "floatPlanId" = safeNumber(floatPlan.id),
        "routeInstanceId" = safeNumber(route.routeInstanceId),
        "routeCode" = safeString(route.routeCode),
        "routeName" = safeString(route.routeName),
        "streamId" = safeNumber(route.streamId),
        "streamSlug" = safeString(route.streamSlug),
        "vesselName" = safeString(qPlan.vesselName[1]),
        "departureName" = firstNonEmpty([ safeString(qPlan.departing[1]), safeString(route.startLocation) ]),
        "destinationName" = firstNonEmpty([ safeString(qPlan.returning[1]), safeString(route.endLocation) ])
      };

      out.progress = {
        "routeProgressPercent" = (structKeyExists(routeSummary, "percentComplete") ? safeNumber(routeSummary.percentComplete) : 0),
        "legProgressPercent" = (structKeyExists(currentLeg, "percentComplete") ? safeNumber(currentLeg.percentComplete) : 0),
        "completedNm" = (structKeyExists(routeSummary, "completedNm") ? safeNumber(routeSummary.completedNm) : 0),
        "remainingNm" = (structKeyExists(routeSummary, "remainingNm") ? safeNumber(routeSummary.remainingNm) : 0),
        "totalNm" = (structKeyExists(routeSummary, "totalNm") ? safeNumber(routeSummary.totalNm) : 0),
        "currentLegOrder" = (structKeyExists(currentLeg, "order") ? safeNumber(currentLeg.order) : 0),
        "completedLegs" = countPublicFollowCompletedLegs(routeTimeline),
        "totalLegs" = safeNumber(route.totalLegs)
      };

      out.currentLeg = {
        "order" = (structKeyExists(currentLeg, "order") ? safeNumber(currentLeg.order) : 0),
        "fromName" = (structKeyExists(currentLeg, "fromName") ? safeString(currentLeg.fromName) : ""),
        "toName" = (structKeyExists(currentLeg, "toName") ? safeString(currentLeg.toName) : ""),
        "label" = currentLegLabel,
        "statusLabel" = (structKeyExists(currentLeg, "statusLabel") ? safeString(currentLeg.statusLabel) : ""),
        "distanceNm" = (structKeyExists(currentLeg, "distanceNm") ? safeNumber(currentLeg.distanceNm) : 0),
        "completedNm" = (structKeyExists(currentLeg, "completedNm") ? safeNumber(currentLeg.completedNm) : 0),
        "remainingNm" = (structKeyExists(currentLeg, "remainingNm") ? safeNumber(currentLeg.remainingNm) : 0),
        "etaUtc" = (structKeyExists(currentLeg, "etaUtc") ? safeString(currentLeg.etaUtc) : ""),
        "etaLocalLabel" = formatPublicFollowLocalLabel((structKeyExists(currentLeg, "etaUtc") ? currentLeg.etaUtc : ""), timezone)
      };

      out.timing = {
        "etaUtc" = out.currentLeg.etaUtc,
        "etaLocalLabel" = out.currentLeg.etaLocalLabel,
        "finalArrivalUtc" = (structKeyExists(routeSummary, "finalArrivalUtc") ? safeString(routeSummary.finalArrivalUtc) : ""),
        "finalArrivalLocalLabel" = formatPublicFollowLocalLabel((structKeyExists(routeSummary, "finalArrivalUtc") ? routeSummary.finalArrivalUtc : ""), timezone),
        "milesTodayNm" = (structKeyExists(todayProgress, "milesTodayNm") ? safeNumber(todayProgress.milesTodayNm) : 0),
        "hoursToday" = (structKeyExists(todayProgress, "hoursToday") ? safeNumber(todayProgress.hoursToday) : 0),
        "dailyStartLocalLabel" = (structKeyExists(monitoring, "dailyStartLabel") ? safeString(monitoring.dailyStartLabel) : ""),
        "manualDelayLabel" = (structKeyExists(monitoring, "manualDelayLabel") ? safeString(monitoring.manualDelayLabel) : "")
      };

      out.monitoring = {
        "state" = (structKeyExists(monitoring, "state") ? safeString(monitoring.state) : ""),
        "mode" = (structKeyExists(monitoring, "mode") ? safeString(monitoring.mode) : ""),
        "publicHealthLabel" = safeString(publicHealth.label),
        "publicHealthVariant" = safeString(publicHealth.variant),
        "lastCheckinStatus" = (structKeyExists(monitoring, "lastCheckinStatus") ? safeString(monitoring.lastCheckinStatus) : ""),
        "lastCheckinUtc" = (structKeyExists(monitoring, "lastCheckinAtUtc") ? safeString(monitoring.lastCheckinAtUtc) : ""),
        "lastCheckinLocalLabel" = formatPublicFollowLocalLabel((structKeyExists(monitoring, "lastCheckinAtUtc") ? monitoring.lastCheckinAtUtc : ""), timezone),
        "nextExpectedCheckinUtc" = (structKeyExists(monitoring, "expectedCheckinAtUtc") ? safeString(monitoring.expectedCheckinAtUtc) : ""),
        "nextExpectedCheckinLocalLabel" = formatPublicFollowLocalLabel((structKeyExists(monitoring, "expectedCheckinAtUtc") ? monitoring.expectedCheckinAtUtc : ""), timezone),
        "secureForNight" = (structKeyExists(monitoring, "secureForNight") AND monitoring.secureForNight EQ true),
        "secureUntilUtc" = (structKeyExists(monitoring, "secureForNightUntilUtc") ? safeString(monitoring.secureForNightUntilUtc) : ""),
        "secureUntilLocalLabel" = formatPublicFollowLocalLabel((structKeyExists(monitoring, "secureForNightUntilUtc") ? monitoring.secureForNightUntilUtc : ""), timezone)
      };

      out.tripState = {
        "code" = tripState,
        "motionState" = motionState,
        "safetyState" = safetyState,
        "label" = stateLabel(tripState),
        "helperText" = publicFollowTripStateHelperText(tripState, motionState, safetyState)
      };

      return out;
    </cfscript>
  </cffunction>

  <cffunction name="basePublicFollowAuthority" access="private" returntype="struct" output="false">
    <cfscript>
      return {
        "version" = 1,
        "source" = "ActiveCruiseViewModelService.publicFollowAuthority",
        "identity" = {},
        "progress" = {},
        "currentLeg" = {},
        "timing" = {},
        "monitoring" = {},
        "tripState" = {}
      };
    </cfscript>
  </cffunction>

  <cffunction name="baseModel" access="private" returntype="struct" output="false">
    <cfscript>
      return {
        "success" = false,
        "message" = "",
        "errorCode" = "",
        "generatedAtUtc" = "",
        "tripState" = "unknown_error",
        "motionState" = "unknown",
        "safetyState" = "normal",
        "tripAccess" = {},
        "displayAuthority" = {
          "primary" = "unavailable",
          "routeTimeline" = "unavailable",
          "monitoring" = "unavailable",
          "warnings" = []
        },
        "floatPlan" = {},
        "route" = {},
        "currentLeg" = {},
        "routeTimeline" = unavailableRouteTimeline(),
        "monitoring" = { "available" = false },
        "floatPlanMonitor" = { "available" = false },
        "checkIn" = {},
        "hero" = {},
        "weather" = {},
        "pace" = {},
        "map" = {},
        "floatPlanInfo" = {},
        "contacts" = { "items" = [], "count" = 0 },
        "captainLog" = { "items" = [], "count" = 0 },
        "checkInHistory" = { "items" = [], "count" = 0, "available" = false },
        "privateTimeline" = { "items" = [], "count" = 0, "available" = false },
        "warnings" = [],
        "actions" = {}
      };
    </cfscript>
  </cffunction>

  <cffunction name="getMemberAccessGateService" access="private" returntype="any" output="false">
    <cfscript>
      try {
        return createObject("component", "fpw.api.v1.MemberAccessGateService").init(variables.datasource);
      } catch (any e1) {
        return createObject("component", "api.v1.MemberAccessGateService").init(variables.datasource);
      }
    </cfscript>
  </cffunction>

  <cffunction name="loadPlanContext" access="private" returntype="query" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      return queryExecute("
        SELECT
          fp.floatPlanId,
          fp.userId,
          fp.floatPlanName,
          fp.status,
          fp.vesselId,
          fp.operatorId,
          fp.departing,
          fp.departureLat,
          fp.departureLon,
          fp.`returning`,
          fp.returnLat,
          fp.returnLon,
          fp.departureTime,
          DATE_FORMAT(fp.departureTime, '%Y-%m-%d %H:%i:%s') AS departureTimeLocalRaw,
          fp.departureTimeUTC,
          DATE_FORMAT(fp.departureTimeUTC, '%Y-%m-%d %H:%i:%s') AS departureTimeUtcRaw,
          fp.departureTZ,
          fp.departTimezone,
          fp.returnTime,
          DATE_FORMAT(fp.returnTime, '%Y-%m-%d %H:%i:%s') AS returnTimeLocalRaw,
          fp.returnTimeUTC,
          DATE_FORMAT(fp.returnTimeUTC, '%Y-%m-%d %H:%i:%s') AS returnTimeUtcRaw,
          fp.returnTZ,
          fp.returnTimezone,
          TIME_FORMAT(fp.dailyStartLocalTime, '%H:%i:%s') AS dailyStartLocalTime,
          fp.manual_delay_minutes_total,
          fp.activatedAt,
          fp.checkedInAt,
          fp.checkin_context,
          fp.closedAt,
          fp.route_instance_id,
          fp.food,
          fp.water,
          fp.notes,
          fp.floatPlanEmail,
          fp.rescueAuthority,
          fp.rescueAuthorityPhone,
          fp.rescueCenterId,
          fp.opHasPfd,
          ri.status AS route_status,
          ri.started_at AS route_started_at,
          ri.completed_at AS route_completed_at,
          ri.generated_route_code,
          ri.template_route_code,
          ri.routegen_inputs_json,
          ri.start_location,
          ri.end_location,
          lr.name AS template_route_name,
          lr.short_code AS template_route_short_code,
          vs.id AS stream_id,
          vs.slug AS stream_slug,
          v.vesselName,
          v.hailingPort,
          v.registration,
          v.yearBuilt,
          v.make,
          v.model,
          v.typeOfVessel,
          v.lengthOfVessel,
          v.draft,
          v.hullMaterial,
          v.hullColor,
          v.prominentFeatures,
          v.callSignNumber,
          v.DSCMMSI,
          v.mobilePhone AS vessel_mobile_phone,
          v.max_speed,
          v.most_efficient_speed,
          v.fuel_capacity,
          v.primaryPropulsion,
          v.primaryPropulsionType,
          v.primaryFuelCapacity,
          v.navigation,
          v.visualDistressSignals,
          v.audibleDistressSignals,
          v.aepirb,
          v.anchor,
          v.food AS vessel_food,
          v.water AS vessel_water,
          v.timezone AS vessel_timezone,
          o.name AS operator_name,
          o.address AS operator_address,
          o.city AS operator_city,
          o.state AS operator_state,
          o.zip AS operator_zip,
          o.homePhone AS operator_home_phone,
          o.age AS operator_age,
          o.gender AS operator_gender,
          o.expWithVessel AS operator_experience_with_vessel,
          o.expWithBoatingArea AS operator_experience_with_area,
          o.vehicle AS operator_vehicle,
          o.vehicleLIcensePlate AS operator_vehicle_license_plate,
          o.vehicleParkedAt AS operator_vehicle_parked_at,
          o.notes AS operator_notes,
          (
            SELECT COUNT(*)
            FROM route_instance_legs ril
            WHERE ril.route_instance_id = fp.route_instance_id
          ) AS total_legs
        FROM floatplans fp
        LEFT JOIN route_instances ri
          ON ri.id = fp.route_instance_id
        LEFT JOIN loop_routes lr
          ON lr.code = ri.template_route_code
        LEFT JOIN voyage_streams vs
          ON vs.id = (
            SELECT MAX(vs2.id)
            FROM voyage_streams vs2
            WHERE vs2.floatplan_id = fp.floatPlanId
          )
        LEFT JOIN vessels v
          ON v.vesselID = fp.vesselId
        LEFT JOIN operators o
          ON o.opId = fp.operatorId
        WHERE fp.floatPlanId = :floatPlanId
          AND fp.userId = :userId
        LIMIT 1
      ", {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      }, { datasource = variables.datasource });
    </cfscript>
  </cffunction>

  <cffunction name="loadRouteMapLegs" access="private" returntype="array" output="false">
    <cfargument name="routeInstanceId" type="numeric" required="true">
    <cfscript>
      var qLegs = queryNew("");
      var legs = [];
      var i = 0;
      var startPoint = {};
      var endPoint = {};
      if (arguments.routeInstanceId LTE 0) {
        return legs;
      }

      qLegs = queryExecute("
        SELECT
          id,
          leg_order,
          start_name,
          end_name,
          start_lat,
          start_lng,
          end_lat,
          end_lng,
          base_dist_nm,
          lock_count
        FROM route_instance_legs
        WHERE route_instance_id = :routeInstanceId
        ORDER BY leg_order ASC, id ASC
      ", {
        routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" }
      }, { datasource = variables.datasource });

      for (i = 1; i LTE qLegs.recordCount; i++) {
        startPoint = buildCoordinatePoint(qLegs.start_name[i], qLegs.start_lat[i], qLegs.start_lng[i]);
        endPoint = buildCoordinatePoint(qLegs.end_name[i], qLegs.end_lat[i], qLegs.end_lng[i]);
        arrayAppend(legs, {
          "routeLegId" = safeNumber(qLegs.id[i]),
          "order" = safeNumber(qLegs.leg_order[i]),
          "fromName" = safeString(qLegs.start_name[i]),
          "toName" = safeString(qLegs.end_name[i]),
          "distanceNm" = safeNumber(qLegs.base_dist_nm[i]),
          "lockCount" = safeNumber(qLegs.lock_count[i]),
          "from" = startPoint,
          "to" = endPoint,
          "hasGeometry" = (startPoint.available AND endPoint.available)
        });
      }
      return legs;
    </cfscript>
  </cffunction>

  <cffunction name="loadMonitoring" access="private" returntype="query" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      return queryExecute("
        SELECT
          id,
          monitoring_mode,
          monitor_state,
          is_monitoring_enabled,
          expected_checkin_at,
          DATE_FORMAT(expected_checkin_at, '%Y-%m-%d %H:%i:%s') AS expected_checkin_at_raw,
          grace_expires_at,
          DATE_FORMAT(grace_expires_at, '%Y-%m-%d %H:%i:%s') AS grace_expires_at_raw,
          missed_at,
          escalated_at,
          resolved_at,
          closed_at,
          last_checkin_at,
          DATE_FORMAT(last_checkin_at, '%Y-%m-%d %H:%i:%s') AS last_checkin_at_raw,
          last_checkin_status,
          secure_for_night,
          secure_for_night_until,
          DATE_FORMAT(secure_for_night_until, '%Y-%m-%d %H:%i:%s') AS secure_for_night_until_raw,
          escalation_delay_minutes,
          grace_window_minutes,
          next_monitor_eval_at,
          DATE_FORMAT(next_monitor_eval_at, '%Y-%m-%d %H:%i:%s') AS next_monitor_eval_at_raw,
          last_monitor_eval_at,
          last_captain_alert_at,
          last_contact_alert_at
        FROM floatplan_monitoring
        WHERE float_plan_id = :floatPlanId
          AND user_id = :userId
        ORDER BY id DESC
        LIMIT 1
      ", {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      }, { datasource = variables.datasource });
    </cfscript>
  </cffunction>

  <cffunction name="loadRouteProgress" access="private" returntype="query" output="false">
    <cfargument name="routeInstanceId" type="numeric" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      if (arguments.routeInstanceId LTE 0 OR arguments.userId LTE 0) {
        return queryNew("");
      }
      return queryExecute("
        SELECT id, leg_order, UPPER(TRIM(COALESCE(status, ''))) AS status_value, leg_started_at, completed_at
        FROM route_instance_leg_progress
        WHERE route_instance_id = :routeInstanceId
          AND user_id = :userId
        ORDER BY leg_order ASC, id ASC
      ", {
        routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" },
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      }, { datasource = variables.datasource });
    </cfscript>
  </cffunction>

  <cffunction name="loadProjection" access="private" returntype="struct" output="false">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfargument name="model" type="struct" required="true">
    <cfscript>
      var service = "";
      try {
        service = createObject("component", "fpw.api.v1.TripProgressProjectionService").init(variables.datasource);
      } catch (any primaryPathErr) {
        service = createObject("component", "api.v1.TripProgressProjectionService").init(variables.datasource);
      }
      try {
        return service.getProjection(arguments.floatPlanId, "", { "includeOperationalLockTime" = false });
      } catch (any projectionErr) {
        addWarning(arguments.model, "ACTIVE_CRUISE_PROJECTION_ERROR", projectionErr.message, "TripProgressProjectionService");
        return {
          "success" = false,
          "message" = projectionErr.message,
          "authorityWarnings" = [],
          "routeTimeline" = unavailableRouteTimeline(),
          "currentLeg" = {},
          "currentLegProgress" = {},
          "dailyWindow" = {},
          "activitySegments" = [],
          "eventLedger" = { "count" = 0 }
        };
      }
    </cfscript>
  </cffunction>

  <cffunction name="createRouteMapGeometryService" access="private" returntype="any" output="false">
    <cfscript>
      try {
        return createObject("component", "fpw.api.v1.RouteMapGeometryService").init(variables.datasource);
      } catch (any primaryPathErr) {
        return createObject("component", "api.v1.RouteMapGeometryService").init(variables.datasource);
      }
    </cfscript>
  </cffunction>

  <cffunction name="extractRouteTimeline" access="private" returntype="struct" output="false">
    <cfargument name="projection" type="struct" required="true">
    <cfscript>
      if (structKeyExists(arguments.projection, "routeTimeline") AND isStruct(arguments.projection.routeTimeline)) {
        return duplicate(arguments.projection.routeTimeline);
      }
      return unavailableRouteTimeline();
    </cfscript>
  </cffunction>

  <cffunction name="unavailableRouteTimeline" access="private" returntype="struct" output="false">
    <cfscript>
      return {
        "available" = false,
        "authority" = "unavailable",
        "summary" = {},
        "legs" = [],
        "warnings" = []
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildFloatPlanSection" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfscript>
      var tz = resolveTimezone(arguments.qPlan);
      return {
        "id" = safeNumber(arguments.qPlan.floatPlanId[1]),
        "status" = safeString(arguments.qPlan.status[1]),
        "name" = safeString(arguments.qPlan.floatPlanName[1]),
        "scheduledDepartureUtc" = safeString(arguments.qPlan.departureTimeUtcRaw[1]),
        "scheduledDepartureLocalRaw" = safeString(arguments.qPlan.departureTimeLocalRaw[1]),
        "scheduledDepartureLocal" = safeString(arguments.qPlan.departureTimeLocalRaw[1]),
        "scheduledDepartureTimezone" = tz,
        "timezone" = tz,
        "checkedInAtUtc" = formatUtc(arguments.qPlan.checkedInAt[1]),
        "checkinContext" = safeString(arguments.qPlan.checkin_context[1]),
        "activatedAtUtc" = formatUtc(arguments.qPlan.activatedAt[1]),
        "closedAtUtc" = formatUtc(arguments.qPlan.closedAt[1])
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildRouteSection" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfscript>
      var code = safeString(arguments.qPlan.generated_route_code[1]);
      var name = safeString(arguments.qPlan.template_route_name[1]);
      if (!len(code)) {
        code = safeString(arguments.qPlan.template_route_code[1]);
      }
      if (!len(name)) {
        name = safeString(arguments.qPlan.floatPlanName[1]);
      }
      if (!len(name)) {
        name = safeString(arguments.qPlan.start_location[1]) & " to " & safeString(arguments.qPlan.end_location[1]);
      }
      return {
        "routeInstanceId" = safeNumber(arguments.qPlan.route_instance_id[1]),
        "routeCode" = code,
        "routeName" = trim(name),
        "status" = safeString(arguments.qPlan.route_status[1]),
        "startLocation" = safeString(arguments.qPlan.start_location[1]),
        "endLocation" = safeString(arguments.qPlan.end_location[1]),
        "totalLegs" = safeNumber(arguments.qPlan.total_legs[1]),
        "streamId" = safeNumber(arguments.qPlan.stream_id[1]),
        "streamSlug" = safeString(arguments.qPlan.stream_slug[1])
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildMonitoringSection" access="private" returntype="struct" output="false">
    <cfargument name="qMonitoring" type="query" required="true">
    <cfargument name="qPlan" type="query" required="true">
    <cfscript>
      var timingFields = buildTimingFields(arguments.qPlan);
      var expectedCheckinLocalLabel = "";
      var expectedCheckinRaw = "";
      var graceExpiresRaw = "";
      var secureForNightUntilRaw = "";
      var nextMonitorEvalRaw = "";
      if (arguments.qMonitoring.recordCount EQ 0) {
        timingFields.available = false;
        timingFields.expectedCheckinLocalLabel = "";
        return timingFields;
      }
      expectedCheckinRaw = safeString(arguments.qMonitoring.expected_checkin_at_raw[1]);
      graceExpiresRaw = safeString(arguments.qMonitoring.grace_expires_at_raw[1]);
      secureForNightUntilRaw = safeString(arguments.qMonitoring.secure_for_night_until_raw[1]);
      nextMonitorEvalRaw = safeString(arguments.qMonitoring.next_monitor_eval_at_raw[1]);
      expectedCheckinLocalLabel = formatUtcSqlStringAsLocalDisplay(expectedCheckinRaw, resolveTimezone(arguments.qPlan));
      return {
        "available" = true,
        "id" = safeNumber(arguments.qMonitoring.id[1]),
        "mode" = safeString(arguments.qMonitoring.monitoring_mode[1]),
        "state" = safeString(arguments.qMonitoring.monitor_state[1]),
        "isEnabled" = (safeNumber(arguments.qMonitoring.is_monitoring_enabled[1]) EQ 1),
        "expectedCheckinAtUtc" = formatRawUtc(expectedCheckinRaw),
        "expectedCheckinLocalLabel" = expectedCheckinLocalLabel,
        "graceExpiresAtUtc" = formatRawUtc(graceExpiresRaw),
        "nextMonitorEvalAtUtc" = formatRawUtc(nextMonitorEvalRaw),
        "lastMonitorEvalAtUtc" = formatUtc(arguments.qMonitoring.last_monitor_eval_at[1]),
        "lastCheckinAtUtc" = formatRawUtc(arguments.qMonitoring.last_checkin_at_raw[1]),
        "lastCheckinStatus" = safeString(arguments.qMonitoring.last_checkin_status[1]),
        "secureForNight" = (safeNumber(arguments.qMonitoring.secure_for_night[1]) EQ 1),
        "secureForNightUntilUtc" = formatRawUtc(secureForNightUntilRaw),
        "missedAtUtc" = formatUtc(arguments.qMonitoring.missed_at[1]),
        "escalatedAtUtc" = formatUtc(arguments.qMonitoring.escalated_at[1]),
        "resolvedAtUtc" = formatUtc(arguments.qMonitoring.resolved_at[1]),
        "closedAtUtc" = formatUtc(arguments.qMonitoring.closed_at[1]),
        "graceWindowMinutes" = safeNumber(arguments.qMonitoring.grace_window_minutes[1]),
        "escalationDelayMinutes" = safeNumber(arguments.qMonitoring.escalation_delay_minutes[1]),
        "lastCaptainAlertAtUtc" = formatUtc(arguments.qMonitoring.last_captain_alert_at[1]),
        "lastContactAlertAtUtc" = formatUtc(arguments.qMonitoring.last_contact_alert_at[1]),
        "manualDelayMinutesTotal" = timingFields.manualDelayMinutesTotal,
        "manualDelayLabel" = timingFields.manualDelayLabel,
        "dailyStartLocalTime" = timingFields.dailyStartLocalTime,
        "dailyStartLabel" = timingFields.dailyStartLabel
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildFloatPlanMonitorSection" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfargument name="qMonitoring" type="query" required="true">
    <cfscript>
      var monitorContact = loadFloatPlanMonitorContact(safeNumber(arguments.qPlan.floatPlanId[1]));
      var rawState = "";
      var statusLabel = "";
      var statusColor = "var(--muted)";
      var streamLive = false;

      if (arguments.qMonitoring.recordCount GT 0) {
        rawState = safeString(arguments.qMonitoring.monitor_state[1]);
      }
      statusLabel = formatMonitorStatusLabel(rawState, "Normal");
      if (!len(statusLabel)) {
        statusLabel = "Unknown";
      }

      if (uCase(statusLabel) EQ "OVERDUE") {
        statusColor = "var(--warn)";
      } else if (uCase(statusLabel) EQ "UNKNOWN") {
        statusColor = "var(--muted)";
      } else {
        statusColor = "var(--good)";
      }

      streamLive = (
        safeNumber(arguments.qPlan.stream_id[1]) GT 0
        OR len(safeString(arguments.qPlan.stream_slug[1])) GT 0
      );

      return {
        "available" = true,
        "authority" = "ActiveCruiseViewModelService.floatPlanMonitor",
        "attachmentLabel" = "Attached",
        "statusLabel" = statusLabel,
        "statusColor" = statusColor,
        "tripPageLabel" = (streamLive ? "Live" : "Not linked"),
        "tripPageAvailable" = streamLive,
        "streamId" = safeNumber(arguments.qPlan.stream_id[1]),
        "streamSlug" = safeString(arguments.qPlan.stream_slug[1]),
        "monitorContact" = monitorContact
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildTimingFields" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfscript>
      var manualDelayMinutes = safeNumber(arguments.qPlan.manual_delay_minutes_total[1]);
      var dailyStartRaw = safeString(arguments.qPlan.dailyStartLocalTime[1]);
      return {
        "manualDelayMinutesTotal" = manualDelayMinutes,
        "manualDelayLabel" = formatMinutesLabel(manualDelayMinutes),
        "dailyStartLocalTime" = dailyStartRaw,
        "dailyStartLabel" = formatLocalTimeLabel(dailyStartRaw, "8:00 AM")
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildCurrentLegSection" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfargument name="projection" type="struct" required="true">
    <cfargument name="routeTimeline" type="struct" required="true">
    <cfscript>
      var currentLeg = (structKeyExists(arguments.projection, "currentLeg") AND isStruct(arguments.projection.currentLeg) ? arguments.projection.currentLeg : {});
      var currentProgress = (structKeyExists(arguments.projection, "currentLegProgress") AND isStruct(arguments.projection.currentLegProgress) ? arguments.projection.currentLegProgress : {});
      var timelineLeg = findCurrentTimelineLeg(arguments.routeTimeline);
      var orderVal = (structKeyExists(timelineLeg, "routeLegOrder") ? safeNumber(timelineLeg.routeLegOrder) : (structKeyExists(currentLeg, "routeLegOrder") ? safeNumber(currentLeg.routeLegOrder) : 0));
      var routeInputs = parseRouteInputsFromPlan(arguments.qPlan);
      var adjustedSpeedKn = firstNumber([
        (structKeyExists(arguments.routeTimeline, "effectiveSpeedKn") ? arguments.routeTimeline.effectiveSpeedKn : 0),
        (structKeyExists(currentProgress, "speedKn") ? currentProgress.speedKn : 0),
        (structKeyExists(arguments.projection, "etaProjection") AND isStruct(arguments.projection.etaProjection) AND structKeyExists(arguments.projection.etaProjection, "speedKn") ? arguments.projection.etaProjection.speedKn : 0)
      ]);
      var weatherFactorPct = (
        structKeyExists(routeInputs, "weather_factor_pct")
        AND !isNull(routeInputs.weather_factor_pct)
        AND isNumeric(routeInputs.weather_factor_pct)
        ? safeNumber(routeInputs.weather_factor_pct)
        : 0
      );

      return {
        "order" = orderVal,
        "fromName" = firstNonEmpty([
          (structKeyExists(timelineLeg, "fromName") ? timelineLeg.fromName : ""),
          (structKeyExists(currentLeg, "startName") ? currentLeg.startName : "")
        ]),
        "toName" = firstNonEmpty([
          (structKeyExists(timelineLeg, "toName") ? timelineLeg.toName : ""),
          (structKeyExists(currentLeg, "endName") ? currentLeg.endName : "")
        ]),
        "distanceNm" = firstNumber([
          (structKeyExists(timelineLeg, "distanceNm") ? timelineLeg.distanceNm : 0),
          (structKeyExists(currentLeg, "distanceNm") ? currentLeg.distanceNm : 0)
        ]),
        "completedNm" = (structKeyExists(currentProgress, "completedNm") ? safeNumber(currentProgress.completedNm) : (structKeyExists(timelineLeg, "completedNm") ? safeNumber(timelineLeg.completedNm) : 0)),
        "remainingNm" = (structKeyExists(currentProgress, "remainingNm") ? safeNumber(currentProgress.remainingNm) : (structKeyExists(timelineLeg, "remainingNm") ? safeNumber(timelineLeg.remainingNm) : 0)),
        "percentComplete" = (structKeyExists(currentProgress, "percentComplete") ? safeNumber(currentProgress.percentComplete) : (structKeyExists(timelineLeg, "percentComplete") ? safeNumber(timelineLeg.percentComplete) : 0)),
        "etaUtc" = firstNonEmpty([
          (structKeyExists(timelineLeg, "etaUtc") ? timelineLeg.etaUtc : ""),
          (structKeyExists(arguments.projection, "etaProjection") AND isStruct(arguments.projection.etaProjection) AND structKeyExists(arguments.projection.etaProjection, "etaUtc") ? arguments.projection.etaProjection.etaUtc : "")
        ]),
        "estimatedDurationSeconds" = (structKeyExists(timelineLeg, "estimatedDurationSeconds") ? safeNumber(timelineLeg.estimatedDurationSeconds) : 0),
        "estimatedDurationLabel" = (structKeyExists(timelineLeg, "estimatedDurationLabel") ? safeString(timelineLeg.estimatedDurationLabel) : ""),
        "remainingDurationSeconds" = firstNumber([
          (structKeyExists(timelineLeg, "remainingDurationSeconds") ? timelineLeg.remainingDurationSeconds : 0),
          (structKeyExists(arguments.projection, "etaProjection") AND isStruct(arguments.projection.etaProjection) AND structKeyExists(arguments.projection.etaProjection, "remainingDurationSeconds") ? arguments.projection.etaProjection.remainingDurationSeconds : 0)
        ]),
        "remainingDurationLabel" = firstNonEmpty([
          (structKeyExists(timelineLeg, "remainingDurationLabel") ? timelineLeg.remainingDurationLabel : ""),
          (structKeyExists(arguments.projection, "etaProjection") AND isStruct(arguments.projection.etaProjection) AND structKeyExists(arguments.projection.etaProjection, "remainingDurationLabel") ? arguments.projection.etaProjection.remainingDurationLabel : "")
        ]),
        "durationAuthority" = (structKeyExists(timelineLeg, "durationAuthority") ? safeString(timelineLeg.durationAuthority) : ""),
        "adjustedSpeedKn" = adjustedSpeedKn,
        "adjustedSpeedLabel" = formatSpeedKnLabel(adjustedSpeedKn),
        "weatherFactorPct" = weatherFactorPct,
        "weatherFactorLabel" = formatWeatherFactorLabel(weatherFactorPct),
        "status" = (structKeyExists(currentLeg, "status") ? safeString(currentLeg.status) : (structKeyExists(timelineLeg, "status") ? safeString(timelineLeg.status) : "")),
        "statusLabel" = (structKeyExists(currentProgress, "statusLabel") ? safeString(currentProgress.statusLabel) : deriveLegStatusLabel(timelineLeg, currentLeg)),
        "authority" = "TripProgressProjectionService"
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildRouteTimelineLegFuelUnavailable" access="private" returntype="struct" output="false">
    <cfargument name="reason" type="string" required="false" default="Fuel data is not available.">
    <cfscript>
      var cleanReason = trim(arguments.reason);
      if (!len(cleanReason)) {
        cleanReason = "Fuel data is not available.";
      }
      return {
        "isAvailable" = false,
        "unavailableReason" = cleanReason,
        "authority" = "routeBuilder.routegenEstimateFuelForDistance",
        "totalFuelGallons" = 0,
        "totalFuelLabel" = "Not available",
        "fuelWithReserveGallons" = 0,
        "fuelWithReserveLabel" = "Not available",
        "legFuelNeededGallons" = 0,
        "legFuelNeededLabel" = "Not available"
      };
    </cfscript>
  </cffunction>

  <cffunction name="assignRouteTimelineFuelUnavailable" access="private" returntype="struct" output="false">
    <cfargument name="routeTimeline" type="struct" required="true">
    <cfargument name="reason" type="string" required="true">
    <cfscript>
      var out = duplicate(arguments.routeTimeline);
      var i = 0;
      if (!structKeyExists(out, "legs") OR !isArray(out.legs)) {
        return out;
      }
      for (i = 1; i LTE arrayLen(out.legs); i++) {
        out.legs[i].fuel = buildRouteTimelineLegFuelUnavailable(arguments.reason);
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="enrichRouteTimelineFuel" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfargument name="routeTimeline" type="struct" required="true">
    <cfscript>
      var out = duplicate(arguments.routeTimeline);
      var routeInputs = {};
      var routeSummary = {};
      var totalDistanceNm = 0;
      var routeBuilderService = "";
      var totalFuelResult = {};
      var totalEstimate = {};
      var totalFuelGallons = 0;
      var fuelWithReserveGallons = 0;
      var baseFuel = {};
      var legDistanceNm = 0;
      var legFuelResult = {};
      var legEstimate = {};
      var legFuel = {};
      var legFuelNeededGallons = 0;
      var i = 0;

      if (!structKeyExists(out, "legs") OR !isArray(out.legs) OR arrayLen(out.legs) EQ 0) {
        return out;
      }

      routeInputs = parseRouteInputsFromPlan(arguments.qPlan);
      if (!structCount(routeInputs)) {
        return assignRouteTimelineFuelUnavailable(out, "Route generator fuel inputs are unavailable.");
      }

      routeSummary = (
        structKeyExists(out, "summary")
        AND isStruct(out.summary)
        ? out.summary
        : {}
      );
      totalDistanceNm = (structKeyExists(routeSummary, "totalNm") ? safeNumber(routeSummary.totalNm) : 0);
      if (totalDistanceNm LTE 0) {
        return assignRouteTimelineFuelUnavailable(out, "Route distance is unavailable.");
      }

      try {
        routeBuilderService = createRouteBuilderService();
        totalFuelResult = routeBuilderService.routegenEstimateFuelForDistance(routeInputs, totalDistanceNm, 0, true);
      } catch (any totalFuelErr) {
        return assignRouteTimelineFuelUnavailable(out, "Route generator fuel estimate failed.");
      }

      if (!structKeyExists(totalFuelResult, "SUCCESS") OR totalFuelResult.SUCCESS NEQ true) {
        return assignRouteTimelineFuelUnavailable(out, (structKeyExists(totalFuelResult, "MESSAGE") ? safeString(totalFuelResult.MESSAGE) : "Route fuel estimate is unavailable."));
      }

      totalEstimate = (
        structKeyExists(totalFuelResult, "FUEL_ESTIMATE")
        AND isStruct(totalFuelResult.FUEL_ESTIMATE)
        ? totalFuelResult.FUEL_ESTIMATE
        : {}
      );
      totalFuelGallons = (structKeyExists(totalEstimate, "baseFuelGallons") ? safeNumber(totalEstimate.baseFuelGallons) : 0);
      fuelWithReserveGallons = (structKeyExists(totalEstimate, "requiredFuelGallons") ? safeNumber(totalEstimate.requiredFuelGallons) : 0);
      if (fuelWithReserveGallons LTE 0) {
        return assignRouteTimelineFuelUnavailable(out, "Fuel burn inputs are unavailable for fuel estimation.");
      }

      baseFuel = buildRouteTimelineLegFuelUnavailable("");
      baseFuel.totalFuelGallons = totalFuelGallons;
      baseFuel.totalFuelLabel = formatFuelGallonsLabel(totalFuelGallons);
      baseFuel.fuelWithReserveGallons = fuelWithReserveGallons;
      baseFuel.fuelWithReserveLabel = formatFuelGallonsLabel(fuelWithReserveGallons);

      for (i = 1; i LTE arrayLen(out.legs); i++) {
        legFuel = duplicate(baseFuel);
        legDistanceNm = (structKeyExists(out.legs[i], "distanceNm") ? safeNumber(out.legs[i].distanceNm) : 0);
        if (legDistanceNm LTE 0) {
          legFuel.unavailableReason = "Selected leg distance is unavailable.";
          out.legs[i].fuel = legFuel;
          continue;
        }

        try {
          legFuelResult = routeBuilderService.routegenEstimateFuelForDistance(routeInputs, legDistanceNm, 0, false);
        } catch (any legFuelErr) {
          legFuel.unavailableReason = "Route generator fuel estimate failed.";
          out.legs[i].fuel = legFuel;
          continue;
        }

        if (!structKeyExists(legFuelResult, "SUCCESS") OR legFuelResult.SUCCESS NEQ true) {
          legFuel.unavailableReason = (structKeyExists(legFuelResult, "MESSAGE") ? safeString(legFuelResult.MESSAGE) : "Selected leg fuel estimate is unavailable.");
          out.legs[i].fuel = legFuel;
          continue;
        }

        legEstimate = (
          structKeyExists(legFuelResult, "FUEL_ESTIMATE")
          AND isStruct(legFuelResult.FUEL_ESTIMATE)
          ? legFuelResult.FUEL_ESTIMATE
          : {}
        );
        legFuelNeededGallons = (structKeyExists(legEstimate, "requiredFuelGallons") ? safeNumber(legEstimate.requiredFuelGallons) : 0);
        if (legFuelNeededGallons LTE 0) {
          legFuel.unavailableReason = "Selected leg fuel estimate is unavailable.";
          out.legs[i].fuel = legFuel;
          continue;
        }

        legFuel.isAvailable = true;
        legFuel.unavailableReason = "";
        legFuel.legFuelNeededGallons = legFuelNeededGallons;
        legFuel.legFuelNeededLabel = formatFuelGallonsLabel(legFuelNeededGallons);
        out.legs[i].fuel = legFuel;
      }

      return out;
    </cfscript>
  </cffunction>

  <cffunction name="buildCurrentLegFuelSection" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfargument name="routeTimeline" type="struct" required="true">
    <cfargument name="currentLeg" type="struct" required="true">
    <cfscript>
      var out = {
        "isAvailable" = false,
        "unavailableReason" = "Fuel data is not available.",
        "authority" = "routeBuilder.routegenEstimateFuelForDistance",
        "totalFuelGallons" = 0,
        "totalFuelLabel" = "Not available",
        "fuelWithReserveGallons" = 0,
        "fuelWithReserveLabel" = "Not available",
        "legFuelNeededGallons" = 0,
        "legFuelNeededLabel" = "Not available",
        "fuelPricePerGallon" = 0,
        "fuelPriceLabel" = "Not provided",
        "fuelCost" = 0,
        "fuelCostLabel" = "Not available",
        "reservePercent" = 0,
        "reserveGallons" = 0,
        "reserveLabel" = "Not available"
      };
      var routeInputs = parseRouteInputsFromPlan(arguments.qPlan);
      var routeSummary = (
        structKeyExists(arguments.routeTimeline, "summary")
        AND isStruct(arguments.routeTimeline.summary)
        ? arguments.routeTimeline.summary
        : {}
      );
      var totalDistanceNm = (structKeyExists(routeSummary, "totalNm") ? safeNumber(routeSummary.totalNm) : 0);
      var legDistanceNm = (structKeyExists(arguments.currentLeg, "distanceNm") ? safeNumber(arguments.currentLeg.distanceNm) : 0);
      var routeBuilderService = "";
      var totalFuelResult = {};
      var legFuelResult = {};
      var totalEstimate = {};
      var legEstimate = {};
      var totalFuelGallons = 0;
      var fuelWithReserveGallons = 0;
      var legFuelNeededGallons = 0;
      var fuelPricePerGallon = 0;
      var fuelCost = 0;
      var reservePercent = 0;
      var reserveGallons = 0;

      if (!structCount(routeInputs)) {
        out.unavailableReason = "Route generator fuel inputs are unavailable.";
        return out;
      }
      if (totalDistanceNm LTE 0) {
        out.unavailableReason = "Route distance is unavailable.";
        return out;
      }
      if (legDistanceNm LTE 0) {
        out.unavailableReason = "Current leg distance is unavailable.";
        return out;
      }

      try {
        routeBuilderService = createRouteBuilderService();
        totalFuelResult = routeBuilderService.routegenEstimateFuelForDistance(routeInputs, totalDistanceNm, 0, true);
        legFuelResult = routeBuilderService.routegenEstimateFuelForDistance(routeInputs, legDistanceNm, 0, false);
      } catch (any fuelErr) {
        out.unavailableReason = "Route generator fuel estimate failed.";
        return out;
      }

      if (!structKeyExists(totalFuelResult, "SUCCESS") OR totalFuelResult.SUCCESS NEQ true) {
        out.unavailableReason = (structKeyExists(totalFuelResult, "MESSAGE") ? safeString(totalFuelResult.MESSAGE) : "Route fuel estimate is unavailable.");
        return out;
      }
      if (!structKeyExists(legFuelResult, "SUCCESS") OR legFuelResult.SUCCESS NEQ true) {
        out.unavailableReason = (structKeyExists(legFuelResult, "MESSAGE") ? safeString(legFuelResult.MESSAGE) : "Current leg fuel estimate is unavailable.");
        return out;
      }

      totalEstimate = (
        structKeyExists(totalFuelResult, "FUEL_ESTIMATE")
        AND isStruct(totalFuelResult.FUEL_ESTIMATE)
        ? totalFuelResult.FUEL_ESTIMATE
        : {}
      );
      legEstimate = (
        structKeyExists(legFuelResult, "FUEL_ESTIMATE")
        AND isStruct(legFuelResult.FUEL_ESTIMATE)
        ? legFuelResult.FUEL_ESTIMATE
        : {}
      );

      totalFuelGallons = (structKeyExists(totalEstimate, "baseFuelGallons") ? safeNumber(totalEstimate.baseFuelGallons) : 0);
      fuelWithReserveGallons = (structKeyExists(totalEstimate, "requiredFuelGallons") ? safeNumber(totalEstimate.requiredFuelGallons) : 0);
      legFuelNeededGallons = (structKeyExists(legEstimate, "requiredFuelGallons") ? safeNumber(legEstimate.requiredFuelGallons) : 0);
      fuelPricePerGallon = (structKeyExists(totalFuelResult, "FUEL_PRICE_PER_GALLON") ? safeNumber(totalFuelResult.FUEL_PRICE_PER_GALLON) : 0);
      fuelCost = (structKeyExists(totalEstimate, "totalFuelCost") ? safeNumber(totalEstimate.totalFuelCost) : 0);
      reservePercent = (structKeyExists(totalFuelResult, "RESERVE_PCT") ? safeNumber(totalFuelResult.RESERVE_PCT) : 0);
      reserveGallons = (structKeyExists(totalEstimate, "reserveGallons") ? safeNumber(totalEstimate.reserveGallons) : 0);

      if (fuelWithReserveGallons LTE 0 OR legFuelNeededGallons LTE 0) {
        out.unavailableReason = "Fuel burn inputs are unavailable for fuel estimation.";
        return out;
      }

      out.isAvailable = true;
      out.unavailableReason = "";
      out.totalFuelGallons = totalFuelGallons;
      out.totalFuelLabel = formatFuelGallonsLabel(totalFuelGallons);
      out.fuelWithReserveGallons = fuelWithReserveGallons;
      out.fuelWithReserveLabel = formatFuelGallonsLabel(fuelWithReserveGallons);
      out.legFuelNeededGallons = legFuelNeededGallons;
      out.legFuelNeededLabel = formatFuelGallonsLabel(legFuelNeededGallons);
      out.fuelPricePerGallon = fuelPricePerGallon;
      out.fuelPriceLabel = formatFuelPriceLabel(fuelPricePerGallon);
      out.fuelCost = fuelCost;
      out.fuelCostLabel = formatFuelCostLabel(fuelCost);
      out.reservePercent = reservePercent;
      out.reserveGallons = reserveGallons;
      out.reserveLabel = formatFuelReserveLabel(reservePercent, reserveGallons);

      return out;
    </cfscript>
  </cffunction>

  <cffunction name="buildCheckInSection" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfargument name="monitoring" type="struct" required="true">
    <cfargument name="tripState" type="string" required="true">
    <cfargument name="motionState" type="string" required="true">
    <cfscript>
      var isClosed = isDate(arguments.qPlan.closedAt[1]) OR compareNoCase(safeString(arguments.qPlan.status[1]), "CLOSED") EQ 0 OR compareNoCase(arguments.tripState, "closed") EQ 0;
      var isScheduled = compareNoCase(arguments.motionState, "scheduled") EQ 0;
      var isUnderway = compareNoCase(arguments.motionState, "underway") EQ 0;
      var isDelayedPause = compareNoCase(arguments.motionState, "paused_delayed") EQ 0;
      var closedReason = "Float plan is closed.";
      var delayedReason = "Please provide a new expected departure time before marking the trip delayed.";
      var changedPlanReason = "Please update and resend the plan if the route or schedule changed.";
      var assistanceReason = "Assistance monitoring is available after the cruise has started.";
      var secureReason = "Secure for the Night is available after the cruise has started.";
      var baseInputs = {
        "note" = { "required" = false },
        "checkinContext" = { "required" = false },
        "newExpectedDepartureTime" = { "required" = false }
      };
      var delayInputs = duplicate(baseInputs);
      delayInputs.newExpectedDepartureTime.required = true;
      delayInputs.newExpectedDepartureTime.validationError = "PRE_DEPARTURE_DELAY_REQUIRES_NEW_TIME";

      return {
        "context" = safeString(arguments.qPlan.checkin_context[1]),
        "lastStatus" = (structKeyExists(arguments.monitoring, "lastCheckinStatus") ? arguments.monitoring.lastCheckinStatus : ""),
        "allowedStatusOptions" = [
          { "status" = "On Track", "enabled" = !isClosed, "disabledReason" = (isClosed ? closedReason : ""), "startsTripPreDeparture" = true, "validationError" = "", "inputRequirements" = baseInputs, "confirmationRequired" = false, "confirmationMessage" = "" },
          { "status" = "Delayed", "enabled" = (!isClosed AND !isScheduled), "disabledReason" = (isClosed ? closedReason : (isScheduled ? delayedReason : "")), "startsTripPreDeparture" = false, "validationError" = "PRE_DEPARTURE_DELAY_REQUIRES_NEW_TIME", "inputRequirements" = delayInputs, "confirmationRequired" = false, "confirmationMessage" = "" },
          { "status" = "Changed Plan", "enabled" = (!isClosed AND !isScheduled), "disabledReason" = (isClosed ? closedReason : (isScheduled ? changedPlanReason : "")), "startsTripPreDeparture" = false, "validationError" = "PRE_DEPARTURE_PLAN_CHANGE_REQUIRES_UPDATE", "inputRequirements" = baseInputs, "confirmationRequired" = true, "confirmationMessage" = changedPlanReason },
          { "status" = "Assistance Needed", "enabled" = (!isClosed AND !isScheduled), "disabledReason" = (isClosed ? closedReason : (isScheduled ? assistanceReason : "")), "startsTripPreDeparture" = false, "validationError" = "PRE_DEPARTURE_ASSISTANCE_REQUIRES_START", "inputRequirements" = baseInputs, "confirmationRequired" = true, "confirmationMessage" = "Assistance Needed may notify approved monitoring contacts." },
          { "status" = "Secure for the Night", "enabled" = (!isClosed AND (isUnderway OR isDelayedPause)), "disabledReason" = (isClosed ? closedReason : ((isUnderway OR isDelayedPause) ? "" : secureReason)), "startsTripPreDeparture" = false, "validationError" = "PRE_DEPARTURE_SECURE_NOT_ALLOWED", "inputRequirements" = baseInputs, "confirmationRequired" = true, "confirmationMessage" = "Confirm the vessel is secure for the night." }
        ],
        "validationMessages" = {
          "PRE_DEPARTURE_DELAY_REQUIRES_NEW_TIME" = delayedReason,
          "PRE_DEPARTURE_PLAN_CHANGE_REQUIRES_UPDATE" = changedPlanReason,
          "PRE_DEPARTURE_SECURE_NOT_ALLOWED" = secureReason,
          "PRE_DEPARTURE_ASSISTANCE_REQUIRES_START" = assistanceReason
        }
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildPaceSection" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfargument name="projection" type="struct" required="true">
    <cfargument name="routeTimeline" type="struct" required="true">
    <cfscript>
      var routeInputs = parseRouteInputsFromPlan(arguments.qPlan);
      var paceMeta = {};
      var paceService = createActiveTripPaceService();
      var currentValue = "RELAXED";
      var actionDisabledReason = "";
      var isClosed = isDate(arguments.qPlan.closedAt[1]) OR compareNoCase(safeString(arguments.qPlan.status[1]), "CLOSED") EQ 0;

      if (structKeyExists(arguments.projection, "pace") AND isStruct(arguments.projection.pace)) {
        paceMeta = duplicate(arguments.projection.pace);
      } else {
        paceMeta = paceService.buildPaceMeta(routeInputs, safeNumber(arguments.qPlan.floatPlanId[1]));
      }
      currentValue = paceService.normalizePace(structKeyExists(paceMeta, "currentValue") ? paceMeta.currentValue : "RELAXED");

      if (safeNumber(arguments.qPlan.floatPlanId[1]) LTE 0) {
        actionDisabledReason = "An active float plan is required for pace controls.";
      } else if (safeNumber(arguments.qPlan.route_instance_id[1]) LTE 0) {
        actionDisabledReason = "A route-backed active float plan is required for pace controls.";
      } else if (isClosed) {
        actionDisabledReason = "Float plan is closed.";
      }

      return {
        "available" = true,
        "authority" = "route_instances.routegen_inputs_json.active_trip_pace",
        "currentValue" = currentValue,
        "currentLabel" = paceService.paceLabel(currentValue),
        "currentIndex" = paceService.paceIndex(currentValue),
        "plannedValue" = (structKeyExists(paceMeta, "plannedValue") ? safeString(paceMeta.plannedValue) : "RELAXED"),
        "plannedLabel" = paceService.paceLabel(structKeyExists(paceMeta, "plannedValue") ? paceMeta.plannedValue : "RELAXED"),
        "options" = paceService.paceOptions(),
        "effectiveSpeedKn" = (structKeyExists(paceMeta, "effectiveSpeedKn") ? safeNumber(paceMeta.effectiveSpeedKn) : 0),
        "weatherAdjustedSpeedKn" = firstNumber([
          (structKeyExists(paceMeta, "weatherAdjustedSpeedKn") ? paceMeta.weatherAdjustedSpeedKn : 0),
          (structKeyExists(arguments.routeTimeline, "effectiveSpeedKn") ? arguments.routeTimeline.effectiveSpeedKn : 0)
        ]),
        "effectiveSpeedLabel" = formatSpeedKnLabel(structKeyExists(paceMeta, "effectiveSpeedKn") ? paceMeta.effectiveSpeedKn : 0),
        "weatherAdjustedSpeedLabel" = formatSpeedKnLabel(firstNumber([
          (structKeyExists(paceMeta, "weatherAdjustedSpeedKn") ? paceMeta.weatherAdjustedSpeedKn : 0),
          (structKeyExists(arguments.routeTimeline, "effectiveSpeedKn") ? arguments.routeTimeline.effectiveSpeedKn : 0)
        ])),
        "weatherFactorPct" = (structKeyExists(paceMeta, "weatherFactorPct") ? safeNumber(paceMeta.weatherFactorPct) : 0),
        "weatherFactorLabel" = formatWeatherFactorLabel(structKeyExists(paceMeta, "weatherFactorPct") ? paceMeta.weatherFactorPct : 0),
        "speedSource" = (structKeyExists(paceMeta, "speedSource") ? safeString(paceMeta.speedSource) : ""),
        "updatedAtUtc" = (structKeyExists(paceMeta, "updatedAtUtc") ? safeString(paceMeta.updatedAtUtc) : ""),
        "isActiveTripOverride" = (structKeyExists(paceMeta, "isActiveTripOverride") AND paceMeta.isActiveTripOverride EQ true),
        "disabledReason" = actionDisabledReason
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildActionsSection" access="private" returntype="struct" output="false">
    <cfargument name="monitoring" type="struct" required="true">
    <cfargument name="currentLeg" type="struct" required="true">
    <cfargument name="routeTimeline" type="struct" required="true">
    <cfargument name="qPlan" type="query" required="true">
    <cfargument name="tripState" type="string" required="true">
    <cfargument name="motionState" type="string" required="true">
    <cfargument name="progressSummary" type="struct" required="true">
    <cfscript>
      var planStatus = uCase(safeString(arguments.qPlan.status[1]));
      var isClosed = isDate(arguments.qPlan.closedAt[1]) OR compareNoCase(planStatus, "CLOSED") EQ 0 OR compareNoCase(arguments.tripState, "closed") EQ 0;
      var isUnderway = compareNoCase(arguments.motionState, "underway") EQ 0;
      var hasCurrentLeg = structKeyExists(arguments.currentLeg, "order") AND safeNumber(arguments.currentLeg.order) GT 0;
      var completeLegReason = "";
      var startNextLegAvailability = buildStartNextLegAvailability(arguments.routeTimeline, arguments.progressSummary, isClosed);
      var routeLegsComplete = (
        structKeyExists(arguments.progressSummary, "totalRows")
        AND safeNumber(arguments.progressSummary.totalRows) GT 0
        AND structKeyExists(arguments.progressSummary, "completedRows")
        AND safeNumber(arguments.progressSummary.completedRows) EQ safeNumber(arguments.progressSummary.totalRows)
      );
      var closeFloatPlanEnabled = (!isClosed AND planStatus EQ "ACTIVE" AND routeLegsComplete);
      var closeFloatPlanReason = "";

      if (isClosed) {
        completeLegReason = "Float plan is closed.";
      } else if (!hasCurrentLeg) {
        completeLegReason = "Current leg is not available.";
      } else if (!isUnderway) {
        completeLegReason = "Complete Current Leg is available after the cruise is underway.";
      }
      if (isClosed) {
        closeFloatPlanReason = "Float plan is closed.";
      } else if (planStatus NEQ "ACTIVE") {
        closeFloatPlanReason = "Close Float Plan is available only for active float plans.";
      } else if (!routeLegsComplete) {
        closeFloatPlanReason = "Close Float Plan is available after all route legs are completed.";
      }

      return {
        "checkIn" = {
          "enabled" = !isClosed,
          "endpoint" = "/api/v1/floatplan.cfc?method=handle&action=checkin&returnFormat=json",
          "payload" = { "floatPlanId" = safeNumber(arguments.qPlan.floatPlanId[1]), "status" = "", "note" = "", "checkinContext" = "" },
          "reason" = (isClosed ? "Float plan is closed." : ""),
          "inputRequirements" = {
            "status" = { "required" = true },
            "note" = { "required" = false },
            "checkinContext" = { "required" = false }
          },
          "supportsLocation" = true,
          "locationCapture" = {
            "required" = false,
            "source" = "browser_geolocation"
          },
          "confirmationRequired" = false,
          "confirmationMessage" = ""
        },
        "timing" = buildTimingActionsSection(arguments.monitoring, arguments.qPlan, isClosed),
        "pace" = buildPaceActionsSection(arguments.qPlan, isClosed),
        "captainLog" = buildCaptainLogActionsSection(arguments.qPlan, arguments.currentLeg),
        "completeLeg" = {
          "enabled" = (!isClosed AND hasCurrentLeg AND isUnderway),
          "endpoint" = "/api/v1/floatplan.cfc?method=handle&action=completeleg&returnFormat=json",
          "payload" = { "floatPlanId" = safeNumber(arguments.qPlan.floatPlanId[1]), "expectedLegOrder" = (hasCurrentLeg ? safeNumber(arguments.currentLeg.order) : 0) },
          "reason" = completeLegReason,
          "inputRequirements" = {
            "expectedLegOrder" = { "required" = true }
          },
          "confirmationRequired" = true,
          "confirmationMessage" = "Confirm the current leg is complete."
        },
        "startNextLeg" = {
          "enabled" = startNextLegAvailability.enabled,
          "endpoint" = "/api/v1/floatplan.cfc?method=handle&action=startnextleg&returnFormat=json",
          "payload" = { "floatPlanId" = safeNumber(arguments.qPlan.floatPlanId[1]) },
          "reason" = startNextLegAvailability.reason,
          "inputRequirements" = {},
          "confirmationRequired" = false,
          "confirmationMessage" = ""
        },
        "closeFloatPlan" = {
          "enabled" = closeFloatPlanEnabled,
          "endpoint" = "/api/v1/floatplan.cfc?method=handle&action=checkin&returnFormat=json",
          "payload" = { "floatPlanId" = safeNumber(arguments.qPlan.floatPlanId[1]), "status" = "Arrived", "note" = "", "checkinContext" = "" },
          "reason" = closeFloatPlanReason,
          "inputRequirements" = {},
          "confirmationRequired" = true,
          "confirmationMessage" = "Confirm the float plan can be closed."
        }
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildStartNextLegAvailability" access="private" returntype="struct" output="false">
    <cfargument name="routeTimeline" type="struct" required="true">
    <cfargument name="progressSummary" type="struct" required="true">
    <cfargument name="isClosed" type="boolean" required="true">
    <cfscript>
      var availability = { "enabled" = false, "reason" = "" };
      var routeTimelineAvailable = structKeyExists(arguments.routeTimeline, "available") AND arguments.routeTimeline.available EQ true;
      var legs = [];
      var completedRows = (structKeyExists(arguments.progressSummary, "completedRows") ? safeNumber(arguments.progressSummary.completedRows) : 0);
      var activeLegOrder = (structKeyExists(arguments.progressSummary, "firstOpenStartedLegOrder") ? safeNumber(arguments.progressSummary.firstOpenStartedLegOrder) : 0);
      var hasPendingLeg = false;
      var i = 0;
      var leg = {};
      var statusVal = "";
      var isCompleted = false;

      if (arguments.isClosed) {
        availability.reason = "Float plan is closed.";
        return availability;
      }
      if (!routeTimelineAvailable) {
        availability.reason = "Canonical route timeline is unavailable.";
        return availability;
      }
      if (!structKeyExists(arguments.routeTimeline, "legs") OR !isArray(arguments.routeTimeline.legs) OR arrayLen(arguments.routeTimeline.legs) EQ 0) {
        availability.reason = "Route timeline legs are unavailable.";
        return availability;
      }
      if (activeLegOrder GT 0) {
        availability.reason = "A route leg is already underway.";
        return availability;
      }
      if (completedRows LTE 0) {
        availability.reason = "Start Next Leg is available after the current leg is completed.";
        return availability;
      }

      legs = arguments.routeTimeline.legs;
      for (i = 1; i LTE arrayLen(legs); i++) {
        if (!isStruct(legs[i])) {
          continue;
        }
        leg = legs[i];
        statusVal = (structKeyExists(leg, "status") ? uCase(safeString(leg.status)) : "");
        isCompleted = (
          (structKeyExists(leg, "isCompleted") AND leg.isCompleted EQ true)
          OR statusVal EQ "COMPLETED"
          OR (structKeyExists(leg, "completedAtUtc") AND len(safeString(leg.completedAtUtc)))
        );
        if (!isCompleted) {
          hasPendingLeg = true;
          break;
        }
      }

      if (!hasPendingLeg) {
        availability.reason = "No pending route leg is available to start.";
        return availability;
      }

      availability.enabled = true;
      return availability;
    </cfscript>
  </cffunction>

  <cffunction name="buildCaptainLogActionsSection" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfargument name="currentLeg" type="struct" required="true">
    <cfscript>
      var floatPlanId = safeNumber(arguments.qPlan.floatPlanId[1]);
      var routeInstanceId = safeNumber(arguments.qPlan.route_instance_id[1]);
      var routeLegOrder = (structKeyExists(arguments.currentLeg, "order") ? safeNumber(arguments.currentLeg.order) : 0);
      var enabled = floatPlanId GT 0;
      var disabledReason = (enabled ? "" : "An active float plan is required for captain notes.");

      return {
        "save" = {
          "enabled" = enabled,
          "label" = "Save Note",
          "endpoint" = "/api/v1/floatplan.cfc?method=handle&action=savecaptainlogentry&returnFormat=json",
          "method" = "POST",
          "payload" = {
            "floatPlanId" = floatPlanId,
            "routeInstanceId" = routeInstanceId,
            "routeLegOrder" = routeLegOrder,
            "noteBody" = "",
            "noteTag" = "",
            "postToFollowStream" = false
          },
          "reason" = disabledReason,
          "disabledReason" = disabledReason,
          "inputRequirements" = {
            "noteBody" = { "required" = true },
            "noteTag" = { "required" = false },
            "postToFollowStream" = { "required" = false }
          },
          "confirmationRequired" = false,
          "confirmationMessage" = ""
        }
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildTimingActionsSection" access="private" returntype="struct" output="false">
    <cfargument name="monitoring" type="struct" required="true">
    <cfargument name="qPlan" type="query" required="true">
    <cfargument name="isClosed" type="boolean" required="true">
    <cfscript>
      var floatPlanId = safeNumber(arguments.qPlan.floatPlanId[1]);
      var dailyStartLocalTime = safeString(arguments.qPlan.dailyStartLocalTime[1]);
      var hasFloatPlan = floatPlanId GT 0;
      var hasMonitoring = structKeyExists(arguments.monitoring, "available") AND arguments.monitoring.available EQ true;
      var disabledReason = "";
      var enabled = false;

      if (!hasFloatPlan) {
        disabledReason = "An active float plan is required for timing controls.";
      } else if (arguments.isClosed) {
        disabledReason = "Float plan is closed.";
      } else if (!hasMonitoring) {
        disabledReason = "Active monitoring is not available for this trip.";
      }
      enabled = hasFloatPlan AND !arguments.isClosed AND hasMonitoring;

      return {
        "addDelay" = {
          "enabled" = enabled,
          "label" = "Add Delay Time",
          "endpoint" = "/api/v1/floatplan.cfc?method=handle&action=adddelay&returnFormat=json",
          "method" = "POST",
          "payload" = { "floatPlanId" = floatPlanId, "minutes" = "" },
          "reason" = disabledReason,
          "disabledReason" = disabledReason,
          "inputRequirements" = {
            "minutes" = { "required" = true }
          },
          "confirmationRequired" = false,
          "confirmationMessage" = ""
        },
        "clearDelay" = {
          "enabled" = enabled,
          "label" = "Clear Delay",
          "endpoint" = "/api/v1/floatplan.cfc?method=handle&action=cleardelay&returnFormat=json",
          "method" = "POST",
          "payload" = { "floatPlanId" = floatPlanId },
          "reason" = disabledReason,
          "disabledReason" = disabledReason,
          "inputRequirements" = {},
          "confirmationRequired" = false,
          "confirmationMessage" = ""
        },
        "updateDailyStart" = {
          "enabled" = enabled,
          "label" = "Save Daily Start Time",
          "endpoint" = "/api/v1/floatplan.cfc?method=handle&action=updatedailystart&returnFormat=json",
          "method" = "POST",
          "payload" = { "floatPlanId" = floatPlanId, "dailyStartLocalTime" = dailyStartLocalTime },
          "reason" = disabledReason,
          "disabledReason" = disabledReason,
          "inputRequirements" = {
            "dailyStartLocalTime" = { "required" = true }
          },
          "confirmationRequired" = false,
          "confirmationMessage" = ""
        }
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildPaceActionsSection" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfargument name="isClosed" type="boolean" required="true">
    <cfscript>
      var floatPlanId = safeNumber(arguments.qPlan.floatPlanId[1]);
      var routeInstanceId = safeNumber(arguments.qPlan.route_instance_id[1]);
      var disabledReason = "";
      var enabled = false;

      if (floatPlanId LTE 0) {
        disabledReason = "An active float plan is required for pace controls.";
      } else if (routeInstanceId LTE 0) {
        disabledReason = "A route-backed active float plan is required for pace controls.";
      } else if (arguments.isClosed) {
        disabledReason = "Float plan is closed.";
      }
      enabled = floatPlanId GT 0 AND routeInstanceId GT 0 AND !arguments.isClosed;

      return {
        "updatePace" = {
          "enabled" = enabled,
          "label" = "Update Pace",
          "endpoint" = "/api/v1/floatplan.cfc?method=handle&action=updateactivepace&returnFormat=json",
          "method" = "POST",
          "payload" = { "floatPlanId" = floatPlanId, "pace" = "" },
          "allowedValues" = [ "RELAXED", "BALANCED", "AGGRESSIVE" ],
          "reason" = disabledReason,
          "disabledReason" = disabledReason,
          "inputRequirements" = {
            "pace" = { "required" = true }
          },
          "confirmationRequired" = false,
          "confirmationMessage" = ""
        }
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildWeatherSection" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfargument name="map" type="struct" required="true">
    <cfargument name="currentLeg" type="struct" required="true">
    <cfscript>
      var generatedAt = formatUtc(now());
      var currentLegOrder = (structKeyExists(arguments.currentLeg, "order") ? safeNumber(arguments.currentLeg.order) : 0);
      var routeLeg = findMapLegByOrder(arguments.map, currentLegOrder);
      var routeCode = safeString(arguments.qPlan.generated_route_code[1]);
      var startPoint = {};
      var endPoint = {};
      var warnings = [];
      var lookupAvailable = false;
      var applyAvailable = false;
      if (!len(routeCode)) {
        routeCode = safeString(arguments.qPlan.template_route_code[1]);
      }
      var out = {
        "available" = false,
        "authority" = "ActiveCruiseViewModelService.weather_lookup_contract",
        "source" = "voyage.getActiveCruiseWeatherCanonical",
        "generatedAtUtc" = generatedAt,
        "updatedAtUtc" = "",
        "routeInstanceId" = safeNumber(arguments.qPlan.route_instance_id[1]),
        "currentLegOrder" = currentLegOrder,
        "lookup" = {
          "available" = false,
          "endpoint" = "/api/v1/voyage.cfc?method=handle&action=getactivecruiseweather&returnFormat=json",
          "method" = "POST",
          "payload" = {
            "floatPlanId" = safeNumber(arguments.qPlan.floatPlanId[1]),
            "point" = ""
          },
          "allowedPoints" = [ "start", "end" ]
        },
        "apply" = {
          "available" = false,
          "method" = "POST",
          "routeCode" = routeCode,
          "endpoints" = {
            "editContext" = "/api/v1/routeBuilder.cfc?method=handle&action=routegen_geteditcontext&returnFormat=json",
            "generatedPreview" = "/api/v1/routeBuilder.cfc?method=handle&action=routegen_preview&returnFormat=json",
            "myRoutePreview" = "/api/v1/routeBuilder.cfc?method=handle&action=previewuserroute&returnFormat=json",
            "update" = "/api/v1/routeBuilder.cfc?method=handle&action=routegen_update&returnFormat=json"
          },
          "payload" = {
            "routeCode" = routeCode
          }
        },
        "points" = {
          "start" = buildWeatherLookupPoint("start", {}, "Current-leg start"),
          "end" = buildWeatherLookupPoint("end", {}, "Current-leg end")
        },
        "alerts" = [],
        "warnings" = [],
        "message" = "Select a current-leg point and check conditions."
      };

      if (currentLegOrder LTE 0) {
        arrayAppend(warnings, {
          "code" = "ACTIVE_CRUISE_WEATHER_CURRENT_LEG_MISSING",
          "message" = "Current leg order is unavailable, so weather lookup points cannot be selected.",
          "source" = "TripProgressProjectionService.currentLeg"
        });
        out.warnings = warnings;
        return out;
      }
      out.lookup.payload.routeLegOrder = currentLegOrder;

      if (!isStruct(routeLeg) OR !structCount(routeLeg)) {
        arrayAppend(warnings, {
          "code" = "ACTIVE_CRUISE_WEATHER_MAP_LEG_MISSING",
          "message" = "Current leg map geometry is unavailable for weather lookup.",
          "source" = "activeCruiseV2Model.map.legs"
        });
        out.warnings = warnings;
        return out;
      }

      startPoint = buildWeatherLookupPoint("start", (structKeyExists(routeLeg, "from") AND isStruct(routeLeg.from) ? routeLeg.from : {}), "Current-leg start");
      endPoint = buildWeatherLookupPoint("end", (structKeyExists(routeLeg, "to") AND isStruct(routeLeg.to) ? routeLeg.to : {}), "Current-leg end");
      out.points.start = startPoint;
      out.points.end = endPoint;
      lookupAvailable = (startPoint.available OR endPoint.available);
      out.lookup.available = lookupAvailable;
      if (!lookupAvailable) {
        arrayAppend(warnings, {
          "code" = "ACTIVE_CRUISE_WEATHER_LOOKUP_POINTS_UNAVAILABLE",
          "message" = "Current leg start and end coordinates are unavailable for weather lookup.",
          "source" = "activeCruiseV2Model.map.legs"
        });
      }
      applyAvailable = (lookupAvailable AND len(routeCode) GT 0);
      out.apply.available = applyAvailable;
      if (lookupAvailable AND !applyAvailable) {
        arrayAppend(warnings, {
          "code" = "ACTIVE_CRUISE_WEATHER_APPLY_ROUTE_CODE_MISSING",
          "message" = "Route code is unavailable, so weather factor cannot be applied to this route.",
          "source" = "activeCruiseV2Model.route.routeCode"
        });
      }
      out.warnings = warnings;
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="findMapLegByOrder" access="private" returntype="struct" output="false">
    <cfargument name="map" type="struct" required="true">
    <cfargument name="legOrder" type="numeric" required="true">
    <cfscript>
      var leg = {};
      if (arguments.legOrder LTE 0 OR !structKeyExists(arguments.map, "legs") OR !isArray(arguments.map.legs)) {
        return {};
      }
      for (leg in arguments.map.legs) {
        if (isStruct(leg) AND structKeyExists(leg, "order") AND safeNumber(leg.order) EQ arguments.legOrder) {
          return leg;
        }
      }
      return {};
    </cfscript>
  </cffunction>

  <cffunction name="buildWeatherLookupPoint" access="private" returntype="struct" output="false">
    <cfargument name="point" type="string" required="true">
    <cfargument name="routePoint" type="struct" required="true">
    <cfargument name="fallbackLabel" type="string" required="true">
    <cfscript>
      var label = (structKeyExists(arguments.routePoint, "name") ? safeString(arguments.routePoint.name) : arguments.fallbackLabel);
      var lat = (structKeyExists(arguments.routePoint, "lat") ? arguments.routePoint.lat : "");
      var lng = (structKeyExists(arguments.routePoint, "lng") ? arguments.routePoint.lng : (structKeyExists(arguments.routePoint, "lon") ? arguments.routePoint.lon : ""));
      var pointAvailable = (
        structKeyExists(arguments.routePoint, "available")
        AND arguments.routePoint.available EQ true
        AND isNumeric(lat)
        AND isNumeric(lng)
      );
      return {
        "available" = pointAvailable,
        "point" = arguments.point,
        "label" = safeString(label),
        "lat" = (isNumeric(lat) ? val(lat) : ""),
        "lng" = (isNumeric(lng) ? val(lng) : ""),
        "message" = (pointAvailable ? "Ready for weather lookup." : "Weather lookup coordinates are unavailable for this current-leg point.")
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildCurrentPositionFromCheckInHistory" access="private" returntype="struct" output="false">
    <cfargument name="checkInHistory" type="struct" required="true">
    <cfscript>
      var out = {
        "available" = false,
        "authority" = "floatplan_events",
        "message" = "No GPS-bearing Active Cruise check-in is available."
      };
      var i = 0;
      var item = {};

      if (
        !structKeyExists(arguments.checkInHistory, "items")
        OR !isArray(arguments.checkInHistory.items)
      ) {
        return out;
      }

      for (i = 1; i LTE arrayLen(arguments.checkInHistory.items); i++) {
        item = arguments.checkInHistory.items[i];
        if (
          isStruct(item)
          AND structKeyExists(item, "hasGps")
          AND item.hasGps EQ true
          AND structKeyExists(item, "latitude")
          AND structKeyExists(item, "longitude")
          AND isNumeric(item.latitude)
          AND isNumeric(item.longitude)
          AND abs(val(item.latitude)) LTE 90
          AND abs(val(item.longitude)) LTE 180
        ) {
          return {
            "available" = true,
            "authority" = "floatplan_events",
            "eventId" = (structKeyExists(item, "id") ? safeNumber(item.id) : 0),
            "sourceCode" = "ACTIVE_CRUISE_WEB",
            "sourceLabel" = (structKeyExists(item, "sourceLabel") ? safeString(item.sourceLabel) : "Active Cruise GPS"),
            "lat" = val(item.latitude),
            "lng" = val(item.longitude),
            "name" = "Latest reported position",
            "capturedAtUtc" = (structKeyExists(item, "capturedAtUtc") ? safeString(item.capturedAtUtc) : ""),
            "capturedAtLocalLabel" = (structKeyExists(item, "capturedAtLocalLabel") ? safeString(item.capturedAtLocalLabel) : ""),
            "occurredAtUtc" = (structKeyExists(item, "occurredAtUtc") ? safeString(item.occurredAtUtc) : ""),
            "occurredAtLocalLabel" = (structKeyExists(item, "occurredLocalLabel") ? safeString(item.occurredLocalLabel) : ""),
            "accuracyMeters" = (
              structKeyExists(item, "accuracyMeters")
              AND isNumeric(item.accuracyMeters)
              AND val(item.accuracyMeters) GTE 0
                ? val(item.accuracyMeters)
                : ""
            ),
            "message" = "Latest GPS position reported with an Active Cruise check-in."
          };
        }
      }

      return out;
    </cfscript>
  </cffunction>

  <cffunction name="buildMapSection" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfargument name="checkInHistory" type="struct" required="true">
    <cfscript>
      var routeInstanceId = safeNumber(arguments.qPlan.route_instance_id[1]);
      var ownerUserId = safeNumber(arguments.qPlan.userId[1]);
      var mapLegs = loadRouteMapLegs(routeInstanceId);
      var routeMapService = createRouteMapGeometryService();
      var routeMap = routeMapService.buildRouteMapData(routeInstanceId, ownerUserId, 0);
      var routeGeo = (
        structKeyExists(routeMap, "route_geo") AND isStruct(routeMap.route_geo)
          ? routeMap.route_geo
          : { "type" = "MultiLineString", "coordinates" = [] }
      );
      var routePins = (
        structKeyExists(routeMap, "pins") AND isArray(routeMap.pins)
          ? routeMap.pins
          : []
      );
      var sharedGeometryAvailable = (
        structKeyExists(routeGeo, "coordinates")
        AND isArray(routeGeo.coordinates)
        AND arrayLen(routeGeo.coordinates) GT 0
      );
      var bounds = buildMapBounds(mapLegs);
      var warnings = [];
      var currentPosition = buildCurrentPositionFromCheckInHistory(arguments.checkInHistory);

      if (arrayLen(mapLegs) EQ 0 AND !sharedGeometryAvailable) {
        arrayAppend(warnings, {
          "code" = "ACTIVE_CRUISE_MAP_LEGS_MISSING",
          "message" = "Route instance legs are not available for Active Cruise V2 map rendering.",
          "source" = "route_instance_legs"
        });
      } else if (!bounds.available AND !sharedGeometryAvailable) {
        arrayAppend(warnings, {
          "code" = "ACTIVE_CRUISE_MAP_GEOMETRY_MISSING",
          "message" = "Route instance legs exist, but usable leg coordinates are not available for map rendering.",
          "source" = "route_instance_legs"
        });
      }

      return {
        "available" = ((arrayLen(mapLegs) GT 0 AND bounds.available) OR sharedGeometryAvailable),
        "routeInstanceId" = routeInstanceId,
        "streamId" = safeNumber(arguments.qPlan.stream_id[1]),
        "authority" = "route_instance",
        "geometryAuthority" = "route_map_geometry_service",
        "overrideAuthority" = "route_leg_user_overrides",
        "fallbackGeometryAuthority" = "segment_geometries",
        "bounds" = bounds,
        "center" = buildMapCenter(bounds),
        "legs" = mapLegs,
        "routeGeo" = routeGeo,
        "pins" = routePins,
        "currentPosition" = currentPosition,
        "warnings" = warnings
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildFloatPlanInfoSection" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfscript>
      return {
        "vessel" = {
          "id" = safeNumber(arguments.qPlan.vesselId[1]),
          "name" = safeString(arguments.qPlan.vesselName[1]),
          "type" = safeString(arguments.qPlan.typeOfVessel[1]),
          "length" = safeNumber(arguments.qPlan.lengthOfVessel[1]),
          "hailingPort" = safeString(arguments.qPlan.hailingPort[1]),
          "registration" = safeString(arguments.qPlan.registration[1]),
          "yearBuilt" = safeString(arguments.qPlan.yearBuilt[1]),
          "make" = safeString(arguments.qPlan.make[1]),
          "model" = safeString(arguments.qPlan.model[1]),
          "draft" = safeString(arguments.qPlan.draft[1]),
          "hullMaterial" = safeString(arguments.qPlan.hullMaterial[1]),
          "hullColor" = safeString(arguments.qPlan.hullColor[1]),
          "prominentFeatures" = safeString(arguments.qPlan.prominentFeatures[1]),
          "callSignNumber" = safeString(arguments.qPlan.callSignNumber[1]),
          "mmsi" = safeString(arguments.qPlan.DSCMMSI[1]),
          "mobilePhone" = safeString(arguments.qPlan.vessel_mobile_phone[1]),
          "maxSpeedKn" = safeNumber(arguments.qPlan.max_speed[1]),
          "mostEfficientSpeedKn" = safeNumber(arguments.qPlan.most_efficient_speed[1]),
          "fuelCapacityGallons" = safeNumber(arguments.qPlan.fuel_capacity[1]),
          "primaryPropulsion" = safeString(arguments.qPlan.primaryPropulsion[1]),
          "primaryPropulsionType" = safeString(arguments.qPlan.primaryPropulsionType[1]),
          "primaryFuelCapacity" = safeString(arguments.qPlan.primaryFuelCapacity[1]),
          "navigation" = safeString(arguments.qPlan.navigation[1]),
          "visualDistressSignals" = safeString(arguments.qPlan.visualDistressSignals[1]),
          "audibleDistressSignals" = safeString(arguments.qPlan.audibleDistressSignals[1]),
          "aepirb" = safeString(arguments.qPlan.aepirb[1]),
          "anchor" = safeString(arguments.qPlan.anchor[1])
        },
        "operator" = {
          "id" = safeNumber(arguments.qPlan.operatorId[1]),
          "name" = safeString(arguments.qPlan.operator_name[1]),
          "address" = safeString(arguments.qPlan.operator_address[1]),
          "city" = safeString(arguments.qPlan.operator_city[1]),
          "state" = safeString(arguments.qPlan.operator_state[1]),
          "zip" = safeString(arguments.qPlan.operator_zip[1]),
          "homePhone" = safeString(arguments.qPlan.operator_home_phone[1]),
          "age" = safeNumber(arguments.qPlan.operator_age[1]),
          "gender" = safeString(arguments.qPlan.operator_gender[1]),
          "experienceWithVessel" = safeString(arguments.qPlan.operator_experience_with_vessel[1]),
          "experienceWithArea" = safeString(arguments.qPlan.operator_experience_with_area[1]),
          "vehicle" = safeString(arguments.qPlan.operator_vehicle[1]),
          "vehicleLicensePlate" = safeString(arguments.qPlan.operator_vehicle_license_plate[1]),
          "vehicleParkedAt" = safeString(arguments.qPlan.operator_vehicle_parked_at[1]),
          "notes" = safeString(arguments.qPlan.operator_notes[1])
        },
        "departure" = {
          "location" = safeString(arguments.qPlan.departing[1]),
          "lat" = safeNumber(arguments.qPlan.departureLat[1]),
          "lon" = safeNumber(arguments.qPlan.departureLon[1]),
          "scheduledUtc" = safeString(arguments.qPlan.departureTimeUtcRaw[1]),
          "scheduledLocalRaw" = safeString(arguments.qPlan.departureTimeLocalRaw[1]),
          "scheduledLocal" = safeString(arguments.qPlan.departureTimeLocalRaw[1]),
          "timezone" = resolveTimezone(arguments.qPlan)
        },
        "return" = {
          "location" = safeString(arguments.qPlan.returning[1]),
          "lat" = safeNumber(arguments.qPlan.returnLat[1]),
          "lon" = safeNumber(arguments.qPlan.returnLon[1]),
          "scheduledUtc" = safeString(arguments.qPlan.returnTimeUtcRaw[1]),
          "scheduledLocalRaw" = safeString(arguments.qPlan.returnTimeLocalRaw[1]),
          "scheduledLocal" = safeString(arguments.qPlan.returnTimeLocalRaw[1]),
          "timezone" = resolveTimezone(arguments.qPlan)
        },
        "rescueAuthority" = {
          "name" = safeString(arguments.qPlan.rescueAuthority[1]),
          "phone" = safeString(arguments.qPlan.rescueAuthorityPhone[1]),
          "centerId" = safeNumber(arguments.qPlan.rescueCenterId[1])
        },
        "supplies" = {
          "food" = safeString(arguments.qPlan.food[1]),
          "water" = safeString(arguments.qPlan.water[1]),
          "vesselFood" = safeString(arguments.qPlan.vessel_food[1]),
          "vesselWater" = safeString(arguments.qPlan.vessel_water[1]),
          "operatorHasPfd" = (safeNumber(arguments.qPlan.opHasPfd[1]) EQ 1)
        },
        "email" = safeString(arguments.qPlan.floatPlanEmail[1]),
        "download" = {
          "available" = false,
          "url" = "",
          "reason" = "No approved Active Cruise V2 print/download URL is exposed by the view model."
        },
        "notes" = safeString(arguments.qPlan.notes[1])
      };
    </cfscript>
  </cffunction>

  <cffunction name="loadContacts" access="private" returntype="struct" output="false">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      var qContacts = queryExecute("
        SELECT
          c.contactId,
          c.name,
          c.phone,
          c.email,
          'notification_contact' AS role,
          'notification_contact' AS category
        FROM floatplan_contacts fpc
        INNER JOIN contacts c
          ON c.contactId = fpc.contactId
        WHERE fpc.floatPlanId = :floatPlanId
        ORDER BY c.name ASC, c.contactId ASC
      ", {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      }, { datasource = variables.datasource });
      var qPassengers = queryExecute("
        SELECT
          p.passId,
          p.name,
          p.phone,
          p.age,
          p.gender,
          p.notes,
          p.pfd,
          p.plbuin,
          'passenger' AS role,
          'passenger' AS category
        FROM floatplan_passengers fpp
        INNER JOIN passengers p
          ON p.passId = fpp.passId
        WHERE fpp.floatPlanId = :floatPlanId
        ORDER BY p.name ASC, p.passId ASC
      ", {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      }, { datasource = variables.datasource });
      return {
        "available" = true,
        "authority" = "floatplan_contacts,floatplan_passengers",
        "roleAuthority" = "table_membership",
        "items" = queryRows(qContacts, [ "contactId", "name", "phone", "email", "role", "category" ]),
        "passengers" = queryRows(qPassengers, [ "passId", "name", "phone", "age", "gender", "notes", "pfd", "plbuin", "role", "category" ]),
        "count" = qContacts.recordCount,
        "passengerCount" = qPassengers.recordCount,
        "warnings" = []
      };
    </cfscript>
  </cffunction>

  <cffunction name="loadFloatPlanMonitorContact" access="private" returntype="struct" output="false">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      var qContact = queryExecute("
        SELECT
          c.contactId,
          c.name,
          c.phone,
          c.email
        FROM floatplan_contacts fpc
        INNER JOIN contacts c
          ON c.contactId = fpc.contactId
        WHERE fpc.floatPlanId = :floatPlanId
        ORDER BY fpc.recId ASC
        LIMIT 1
      ", {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      }, { datasource = variables.datasource });
      var contactName = "Shore contact not named";
      var contactPhone = "";
      var contactEmail = "";

      if (qContact.recordCount GT 0) {
        contactName = safeString(qContact.name[1]);
        if (!len(contactName)) {
          contactName = "Shore contact not named";
        }
        contactPhone = safeString(qContact.phone[1]);
        contactEmail = safeString(qContact.email[1]);
      }

      return {
        "available" = (qContact.recordCount GT 0),
        "authority" = "floatplan_contacts.recId",
        "contactId" = (qContact.recordCount GT 0 ? safeNumber(qContact.contactId[1]) : 0),
        "name" = contactName,
        "phoneHref" = buildContactPhoneHref(contactPhone, "tel"),
        "smsHref" = buildContactPhoneHref(contactPhone, "sms"),
        "emailHref" = buildContactEmailHref(contactEmail)
      };
    </cfscript>
  </cffunction>

  <cffunction name="loadCaptainLog" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      var qLog = queryExecute("
        SELECT id, route_leg_order, note_body, note_tag, posted_to_stream, voyage_post_id, created_utc
        FROM floatplan_captain_log_entries
        WHERE floatplan_id = :floatPlanId
          AND user_id = :userId
          AND deleted_utc IS NULL
        ORDER BY created_utc DESC, id DESC
        LIMIT 20
      ", {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      }, { datasource = variables.datasource });
      return {
        "available" = true,
        "storageAuthority" = "floatplan_captain_log_entries",
        "writeAvailable" = true,
        "writeReason" = "",
        "writeAction" = "actions.captainLog.save",
        "items" = queryRows(qLog, [ "id", "route_leg_order", "note_body", "note_tag", "posted_to_stream", "voyage_post_id", "created_utc" ]),
        "count" = qLog.recordCount
      };
    </cfscript>
  </cffunction>

  <cffunction name="loadCheckInHistory" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfargument name="qPlan" type="query" required="true">
    <cfscript>
      var qHistory = queryNew("");
      var items = [];
      var i = 0;
      var payload = {};
      var statusVal = "";
      var statusLabel = "";
      var noteBody = "";
      var occurredUtc = "";
      var occurredLocal = "";
      var timezone = resolveTimezone(arguments.qPlan);
      var location = {};
      var hasGps = false;
      var capturedAtUtc = "";
      var capturedAtLocal = "";

      qHistory = queryExecute("
        SELECT id, event_status, occurred_at_utc, source, payload_json
        FROM floatplan_events
        WHERE floatplan_id = :floatPlanId
          AND user_id = :userId
          AND event_type = 'CHECKIN_RECEIVED'
          AND source = 'active_cruise_checkin'
          AND voided_at_utc IS NULL
        ORDER BY occurred_at_utc DESC, id DESC
        LIMIT 20
      ", {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      }, { datasource = variables.datasource });

      for (i = 1; i LTE qHistory.recordCount; i++) {
        payload = parseJsonStruct(qHistory.payload_json[i]);
        statusVal = safeString(qHistory.event_status[i]);
        statusLabel = formatCheckInHistoryStatusLabel(statusVal, payload);
        noteBody = (structKeyExists(payload, "note_body") ? safeString(payload.note_body) : "");
        occurredUtc = formatUtc(qHistory.occurred_at_utc[i]);
        occurredLocal = formatLocalDisplay(qHistory.occurred_at_utc[i], timezone);
        location = (structKeyExists(payload, "location") AND isStruct(payload.location) ? payload.location : {});
        hasGps = (
          structKeyExists(location, "latitude")
          AND structKeyExists(location, "longitude")
          AND isNumeric(location.latitude)
          AND isNumeric(location.longitude)
          AND abs(val(location.latitude)) LTE 90
          AND abs(val(location.longitude)) LTE 180
        );
        capturedAtUtc = (
          hasGps
          AND structKeyExists(location, "capturedAtUtc")
            ? safeString(location.capturedAtUtc)
            : ""
        );
        capturedAtLocal = (
          hasGps AND len(capturedAtUtc)
            ? formatPublicFollowLocalLabel(capturedAtUtc, timezone)
            : ""
        );
        if (hasGps AND !len(capturedAtLocal)) {
          capturedAtLocal = occurredLocal;
        }

        arrayAppend(items, {
          "id" = safeNumber(qHistory.id[i]),
          "status" = statusVal,
          "statusLabel" = statusLabel,
          "title" = "Check-in: " & statusLabel,
          "note" = noteBody,
          "occurredAtUtc" = occurredUtc,
          "occurredLocalLabel" = occurredLocal,
          "checkinContext" = (structKeyExists(payload, "checkin_context") ? safeString(payload.checkin_context) : ""),
          "source" = safeString(qHistory.source[i]),
          "sourceLabel" = (hasGps ? "Active Cruise GPS" : "Active Cruise Web"),
          "hasGps" = hasGps,
          "latitude" = (hasGps ? val(location.latitude) : ""),
          "longitude" = (hasGps ? val(location.longitude) : ""),
          "accuracyMeters" = (
            hasGps
            AND structKeyExists(location, "accuracyMeters")
            AND isNumeric(location.accuracyMeters)
            AND val(location.accuracyMeters) GTE 0
              ? val(location.accuracyMeters)
              : ""
          ),
          "capturedAtUtc" = capturedAtUtc,
          "capturedAtLocalLabel" = capturedAtLocal,
          "storageAuthority" = "floatplan_events"
        });
      }

      return {
        "available" = true,
        "storageAuthority" = "floatplan_events",
        "items" = items,
        "count" = qHistory.recordCount
      };
    </cfscript>
  </cffunction>

  <cffunction name="loadPrivateTimeline" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfargument name="qPlan" type="query" required="true">
    <cfscript>
      var qTimeline = queryNew("");
      var items = [];
      var i = 0;
      var payload = {};
      var eventTypeVal = "";
      var sourceVal = "";
      var statusVal = "";
      var statusLabel = "";
      var noteBody = "";
      var titleVal = "";
      var detailVal = "";
      var legOrder = 0;
      var fromName = "";
      var toName = "";

      qTimeline = queryExecute("
        SELECT
          id,
          event_type,
          event_status,
          occurred_at_utc,
          DATE_FORMAT(occurred_at_utc, '%Y-%m-%d %H:%i:%s') AS occurred_at_utc_raw,
          source,
          payload_json
        FROM floatplan_events
        WHERE floatplan_id = :floatPlanId
          AND user_id = :userId
          AND voided_at_utc IS NULL
          AND (
            (event_type = 'CHECKIN_RECEIVED' AND source = 'active_cruise_checkin')
            OR (
              event_type IN ('ROUTE_LEG_COMPLETED', 'ROUTE_LEG_STARTED', 'FLOATPLAN_CLOSED')
              AND source = 'active_cruise_route_action'
            )
          )
        ORDER BY occurred_at_utc DESC, id DESC
        LIMIT 20
      ", {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      }, { datasource = variables.datasource });

      for (i = 1; i LTE qTimeline.recordCount; i++) {
        payload = parseJsonStruct(qTimeline.payload_json[i]);
        eventTypeVal = safeString(qTimeline.event_type[i]);
        sourceVal = safeString(qTimeline.source[i]);
        statusVal = safeString(qTimeline.event_status[i]);
        statusLabel = "";
        noteBody = "";
        titleVal = "";
        detailVal = "";
        legOrder = 0;
        fromName = "";
        toName = "";

        if (eventTypeVal EQ "CHECKIN_RECEIVED") {
          statusLabel = formatCheckInHistoryStatusLabel(statusVal, payload);
          noteBody = (structKeyExists(payload, "note_body") ? safeString(payload.note_body) : "");
          titleVal = "Check-in: " & statusLabel;
          detailVal = "Captain check-in recorded.";
        } else {
          titleVal = (structKeyExists(payload, "action_label") ? safeString(payload.action_label) : formatRouteActionTitle(eventTypeVal));
          legOrder = (structKeyExists(payload, "leg_order") ? safeNumber(payload.leg_order) : 0);
          fromName = (structKeyExists(payload, "from_name") ? safeString(payload.from_name) : "");
          toName = (structKeyExists(payload, "to_name") ? safeString(payload.to_name) : "");
          if (len(fromName) AND len(toName)) {
            detailVal = fromName & " to " & toName;
          } else if (legOrder GT 0) {
            detailVal = "Route leg " & legOrder;
          } else {
            detailVal = (structKeyExists(payload, "status_label") ? safeString(payload.status_label) : formatRouteActionTitle(eventTypeVal));
          }
        }

        arrayAppend(items, {
          "id" = safeNumber(qTimeline.id[i]),
          "eventType" = eventTypeVal,
          "source" = sourceVal,
          "title" = (len(titleVal) ? titleVal : "Operational event"),
          "detail" = detailVal,
          "note" = noteBody,
          "occurredAtUtc" = formatRawUtc(qTimeline.occurred_at_utc_raw[i]),
          "occurredLocalLabel" = formatUtcSqlStringAsLocalDisplay(qTimeline.occurred_at_utc_raw[i], resolveTimezone(arguments.qPlan)),
          "storageAuthority" = "floatplan_events"
        });
      }

      return {
        "available" = true,
        "storageAuthority" = "floatplan_events",
        "items" = items,
        "count" = qTimeline.recordCount
      };
    </cfscript>
  </cffunction>

  <cffunction name="formatRouteActionTitle" access="private" returntype="string" output="false">
    <cfargument name="eventType" type="string" required="true">
    <cfscript>
      switch (uCase(safeString(arguments.eventType))) {
        case "ROUTE_LEG_COMPLETED": return "Complete Current Leg / Arrived";
        case "ROUTE_LEG_STARTED": return "Start Next Leg";
        case "FLOATPLAN_CLOSED": return "Close Float Plan";
      }
      return "Route action";
    </cfscript>
  </cffunction>

  <cffunction name="formatCheckInHistoryStatusLabel" access="private" returntype="string" output="false">
    <cfargument name="status" type="string" required="true">
    <cfargument name="payload" type="struct" required="true">
    <cfscript>
      var statusVal = uCase(safeString(arguments.status));
      var payloadLabel = (structKeyExists(arguments.payload, "status_label") ? safeString(arguments.payload.status_label) : "");
      if (len(payloadLabel)) {
        return payloadLabel;
      }
      switch (statusVal) {
        case "ON_TRACK": return "On Track";
        case "DELAYED": return "Delayed";
        case "CHANGED_PLAN": return "Changed Plan";
        case "NEED_ATTENTION": return "Assistance Needed";
        case "ASSISTANCE_NEEDED": return "Assistance Needed";
        case "SECURE_FOR_NIGHT": return "Secure for the Night";
      }
      return (len(statusVal) ? replace(statusVal, "_", " ", "all") : "Check-in");
    </cfscript>
  </cffunction>

  <cffunction name="parseJsonStruct" access="private" returntype="struct" output="false">
    <cfargument name="value" type="any" required="false" default="">
    <cfscript>
      var raw = safeString(arguments.value);
      var parsed = {};
      if (!len(raw)) {
        return {};
      }
      try {
        parsed = deserializeJSON(raw);
        if (isStruct(parsed)) {
          return parsed;
        }
      } catch (any parseErr) {}
      return {};
    </cfscript>
  </cffunction>

  <cffunction name="parseRouteInputsFromPlan" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfscript>
      if (
        arguments.qPlan.recordCount LTE 0
        OR !listFindNoCase(arguments.qPlan.columnList, "routegen_inputs_json")
        OR isNull(arguments.qPlan.routegen_inputs_json[1])
      ) {
        return {};
      }
      return parseJsonStruct(arguments.qPlan.routegen_inputs_json[1]);
    </cfscript>
  </cffunction>

  <cffunction name="createActiveTripPaceService" access="private" returntype="any" output="false">
    <cfscript>
      try {
        return createObject("component", "fpw.api.v1.ActiveTripPaceService").init(variables.datasource);
      } catch (any pacePathErr) {
        return createObject("component", "api.v1.ActiveTripPaceService").init(variables.datasource);
      }
    </cfscript>
  </cffunction>

  <cffunction name="createRouteBuilderService" access="private" returntype="any" output="false">
    <cfscript>
      try {
        return createObject("component", "fpw.api.v1.routeBuilder");
      } catch (any routeBuilderPathErr) {
        return createObject("component", "api.v1.routeBuilder");
      }
    </cfscript>
  </cffunction>

  <cffunction name="formatSpeedKnLabel" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      if (!isNumeric(arguments.value) OR safeNumber(arguments.value) LTE 0) {
        return "--";
      }
      return numberFormat(safeNumber(arguments.value), "0.0") & " kn";
    </cfscript>
  </cffunction>

  <cffunction name="formatWeatherFactorLabel" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      if (!isNumeric(arguments.value)) {
        return "0%";
      }
      return numberFormat(safeNumber(arguments.value), "0") & "%";
    </cfscript>
  </cffunction>

  <cffunction name="formatFuelGallonsLabel" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      if (!isNumeric(arguments.value) OR safeNumber(arguments.value) LTE 0) {
        return "Not available";
      }
      return numberFormat(safeNumber(arguments.value), "0.0") & " gal";
    </cfscript>
  </cffunction>

  <cffunction name="formatFuelPriceLabel" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      if (!isNumeric(arguments.value) OR safeNumber(arguments.value) LTE 0) {
        return "Not provided";
      }
      return "$" & numberFormat(safeNumber(arguments.value), "0.00") & "/gal";
    </cfscript>
  </cffunction>

  <cffunction name="formatFuelCostLabel" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      if (!isNumeric(arguments.value) OR safeNumber(arguments.value) LTE 0) {
        return "Not available";
      }
      return "$" & numberFormat(safeNumber(arguments.value), "0.00");
    </cfscript>
  </cffunction>

  <cffunction name="formatFuelReserveLabel" access="private" returntype="string" output="false">
    <cfargument name="reservePercent" type="any" required="true">
    <cfargument name="reserveGallons" type="any" required="true">
    <cfscript>
      if (!isNumeric(arguments.reservePercent) OR safeNumber(arguments.reservePercent) LTE 0) {
        return formatFuelGallonsLabel(arguments.reserveGallons);
      }
      return numberFormat(safeNumber(arguments.reservePercent), "0") & "% / " & formatFuelGallonsLabel(arguments.reserveGallons);
    </cfscript>
  </cffunction>

  <cffunction name="summarizeRouteProgress" access="private" returntype="struct" output="false">
    <cfargument name="qProgress" type="query" required="true">
    <cfscript>
      var out = {
        "totalRows" = arguments.qProgress.recordCount,
        "startedRows" = 0,
        "startedStatusRows" = 0,
        "completedRows" = 0,
        "notStartedRows" = 0,
        "firstStartedLegOrder" = 0,
        "firstOpenStartedLegOrder" = 0
      };
      var i = 0;
      var statusVal = "";
      for (i = 1; i LTE arguments.qProgress.recordCount; i++) {
        statusVal = safeString(arguments.qProgress.status_value[i]);
        if (statusVal EQ "NOT_STARTED") {
          out.notStartedRows++;
        }
        if (statusVal EQ "STARTED" OR statusVal EQ "IN_PROGRESS") {
          out.startedStatusRows++;
        }
        if (isDate(arguments.qProgress.leg_started_at[i])) {
          out.startedRows++;
          if (out.firstStartedLegOrder LTE 0) {
            out.firstStartedLegOrder = safeNumber(arguments.qProgress.leg_order[i]);
          }
        }
        if (isDate(arguments.qProgress.completed_at[i]) OR statusVal EQ "COMPLETED") {
          out.completedRows++;
        } else if ((isDate(arguments.qProgress.leg_started_at[i]) OR statusVal EQ "STARTED" OR statusVal EQ "IN_PROGRESS") AND out.firstOpenStartedLegOrder LTE 0) {
          out.firstOpenStartedLegOrder = safeNumber(arguments.qProgress.leg_order[i]);
        }
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="hasExplicitStartProof" access="private" returntype="boolean" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfargument name="projection" type="struct" required="true">
    <cfargument name="progressSummary" type="struct" required="true">
    <cfscript>
      if (arguments.qPlan.recordCount AND !isNull(arguments.qPlan.route_started_at[1]) AND isDate(arguments.qPlan.route_started_at[1])) {
        return true;
      }
      if (structKeyExists(arguments.projection, "activitySegments") AND isArray(arguments.projection.activitySegments) AND arrayLen(arguments.projection.activitySegments) GT 0) {
        return true;
      }
      if (structKeyExists(arguments.progressSummary, "startedRows") AND safeNumber(arguments.progressSummary.startedRows) GT 0) {
        return true;
      }
      if (structKeyExists(arguments.progressSummary, "startedStatusRows") AND safeNumber(arguments.progressSummary.startedStatusRows) GT 0) {
        return true;
      }
      return false;
    </cfscript>
  </cffunction>

  <cffunction name="deriveMotionState" access="private" returntype="string" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfargument name="qMonitoring" type="query" required="true">
    <cfargument name="projection" type="struct" required="true">
    <cfargument name="routeTimeline" type="struct" required="true">
    <cfargument name="progressSummary" type="struct" required="true">
    <cfargument name="explicitStartProof" type="boolean" required="true">
    <cfscript>
      var planStatus = uCase(safeString(arguments.qPlan.status[1]));
      var monitorState = (arguments.qMonitoring.recordCount ? uCase(safeString(arguments.qMonitoring.monitor_state[1])) : "");
      var currentSegmentType = "";
      var routeTimelineAuthority = (structKeyExists(arguments.routeTimeline, "authority") ? safeString(arguments.routeTimeline.authority) : "");
      var routeTimelineAvailable = (structKeyExists(arguments.routeTimeline, "available") AND arguments.routeTimeline.available EQ true);
      var openStartedLegOrder = (structKeyExists(arguments.progressSummary, "firstOpenStartedLegOrder") ? safeNumber(arguments.progressSummary.firstOpenStartedLegOrder) : 0);
      var startedStatusRows = (structKeyExists(arguments.progressSummary, "startedStatusRows") ? safeNumber(arguments.progressSummary.startedStatusRows) : 0);
      var completedRows = (structKeyExists(arguments.progressSummary, "completedRows") ? safeNumber(arguments.progressSummary.completedRows) : 0);
      var notStartedRows = (structKeyExists(arguments.progressSummary, "notStartedRows") ? safeNumber(arguments.progressSummary.notStartedRows) : 0);
      var hasCurrentUnderwayProof = false;

      if (planStatus EQ "CLOSED" OR isDate(arguments.qPlan.closedAt[1]) OR monitorState EQ "CLOSED") {
        return "closed";
      }
      if (structKeyExists(arguments.progressSummary, "totalRows") AND safeNumber(arguments.progressSummary.totalRows) GT 0 AND safeNumber(arguments.progressSummary.completedRows) EQ safeNumber(arguments.progressSummary.totalRows)) {
        return "arrived";
      }
      if (arguments.qMonitoring.recordCount AND safeNumber(arguments.qMonitoring.secure_for_night[1]) EQ 1) {
        return "paused_overnight";
      }
      if (hasCanonicalActivitySegments(arguments.projection) AND structKeyExists(arguments.projection, "dailyWindow") AND isStruct(arguments.projection.dailyWindow) AND structKeyExists(arguments.projection.dailyWindow, "currentSegmentType")) {
        currentSegmentType = safeString(arguments.projection.dailyWindow.currentSegmentType);
      }
      if (currentSegmentType EQ "PAUSED_SECURE_FOR_NIGHT") {
        return "paused_overnight";
      }
      if (currentSegmentType EQ "PAUSED_DELAYED") {
        return "paused_delayed";
      }
      if (structKeyExists(arguments.projection, "currentLegProgress") AND isStruct(arguments.projection.currentLegProgress) AND structKeyExists(arguments.projection.currentLegProgress, "paused") AND arguments.projection.currentLegProgress.paused EQ true) {
        return "paused_overnight";
      }
      hasCurrentUnderwayProof = (currentSegmentType EQ "UNDERWAY" OR openStartedLegOrder GT 0 OR startedStatusRows GT 0);

      if (hasCurrentUnderwayProof) {
        return "underway";
      }
      if (arguments.explicitStartProof AND completedRows GT 0 AND notStartedRows GT 0) {
        return "awaiting_next_leg";
      }
      if (routeTimelineAvailable AND routeTimelineAuthority EQ "scheduled_projection") {
        return "scheduled";
      }
      if (routeTimelineAvailable AND !arguments.explicitStartProof) {
        return "scheduled";
      }
      return "unknown";
    </cfscript>
  </cffunction>

  <cffunction name="hasCanonicalActivitySegments" access="private" returntype="boolean" output="false">
    <cfargument name="projection" type="struct" required="true">
    <cfscript>
      return structKeyExists(arguments.projection, "activitySegments")
        AND isArray(arguments.projection.activitySegments)
        AND arrayLen(arguments.projection.activitySegments) GT 0;
    </cfscript>
  </cffunction>

  <cffunction name="deriveSafetyState" access="private" returntype="string" output="false">
    <cfargument name="qMonitoring" type="query" required="true">
    <cfscript>
      var monitorState = "";
      var lastStatus = "";
      if (arguments.qMonitoring.recordCount EQ 0) {
        return "normal";
      }
      monitorState = uCase(safeString(arguments.qMonitoring.monitor_state[1]));
      lastStatus = uCase(safeString(arguments.qMonitoring.last_checkin_status[1]));
      if (lastStatus EQ "NEED_ATTENTION" OR lastStatus EQ "ASSISTANCE_NEEDED") {
        return "assistance_needed";
      }
      if (listFindNoCase("ESCALATED,MISSED,LATE", monitorState)) {
        return lCase(monitorState);
      }
      return "normal";
    </cfscript>
  </cffunction>

  <cffunction name="deriveTripState" access="private" returntype="string" output="false">
    <cfargument name="motionState" type="string" required="true">
    <cfargument name="safetyState" type="string" required="true">
    <cfscript>
      if (listFindNoCase("assistance_needed,escalated,missed,late", arguments.safetyState)) {
        return arguments.safetyState;
      }
      if (listFindNoCase("scheduled,underway,awaiting_next_leg,paused_overnight,paused_delayed,arrived,closed", arguments.motionState)) {
        return arguments.motionState;
      }
      return "unknown_error";
    </cfscript>
  </cffunction>

  <cffunction name="buildHeroSection" access="private" returntype="struct" output="false">
    <cfargument name="model" type="struct" required="true">
    <cfscript>
      var statusLabel = stateLabel(arguments.model.tripState);
      var legText = "";
      if (structKeyExists(arguments.model.currentLeg, "fromName") AND len(arguments.model.currentLeg.fromName)) {
        legText = arguments.model.currentLeg.fromName & " to " & arguments.model.currentLeg.toName;
      }
      return {
        "status" = statusLabel,
        "tripState" = arguments.model.tripState,
        "motionState" = arguments.model.motionState,
        "safetyState" = arguments.model.safetyState,
        "title" = (structKeyExists(arguments.model.route, "routeName") ? arguments.model.route.routeName : ""),
        "currentLeg" = legText,
        "etaUtc" = (structKeyExists(arguments.model.currentLeg, "etaUtc") ? arguments.model.currentLeg.etaUtc : ""),
        "statusDetail" = stateDetail(arguments.model.tripState, arguments.model.motionState, arguments.model.safetyState),
        "authority" = arguments.model.displayAuthority.primary
      };
    </cfscript>
  </cffunction>

  <cffunction name="addProjectionWarnings" access="private" returntype="void" output="false">
    <cfargument name="model" type="struct" required="true">
    <cfargument name="projection" type="struct" required="true">
    <cfscript>
      var i = 0;
      var warningItem = {};
      if (!structKeyExists(arguments.projection, "success") OR arguments.projection.success NEQ true) {
        addWarning(arguments.model, "ACTIVE_CRUISE_PROJECTION_UNAVAILABLE", safeString(arguments.projection.message ?: "Canonical projection was unavailable."), "TripProgressProjectionService");
      }
      if (structKeyExists(arguments.projection, "authorityWarnings") AND isArray(arguments.projection.authorityWarnings)) {
        for (i = 1; i LTE arrayLen(arguments.projection.authorityWarnings); i++) {
          warningItem = arguments.projection.authorityWarnings[i];
          if (isStruct(warningItem)) {
            addWarning(
              arguments.model,
              (structKeyExists(warningItem, "code") ? warningItem.code : "PROJECTION_WARNING"),
              (structKeyExists(warningItem, "message") ? warningItem.message : ""),
              "TripProgressProjectionService"
            );
          }
        }
      }
    </cfscript>
  </cffunction>

  <cffunction name="addConsistencyWarnings" access="private" returntype="void" output="false">
    <cfargument name="model" type="struct" required="true">
    <cfargument name="qPlan" type="query" required="true">
    <cfargument name="projection" type="struct" required="true">
    <cfargument name="routeTimeline" type="struct" required="true">
    <cfargument name="progressSummary" type="struct" required="true">
    <cfargument name="explicitStartProof" type="boolean" required="true">
    <cfscript>
      var routeStatus = uCase(safeString(arguments.qPlan.route_status[1]));
      var routeTimelineAuthority = (structKeyExists(arguments.routeTimeline, "authority") ? safeString(arguments.routeTimeline.authority) : "");
      var scheduledDeparture = firstDate(arguments.qPlan.departureTimeUTC[1], "");

      if (arguments.explicitStartProof AND isDate(scheduledDeparture) AND dateCompare(scheduledDeparture, now(), "s") GT 0) {
        addWarning(arguments.model, "SCHEDULED_CLOCK_IGNORED_EXPLICIT_START", "Scheduled departure is still in the future, but explicit start proof exists. Display state must not remain scheduled.", "view_model");
      }
      if (arguments.explicitStartProof AND routeStatus EQ "PLANNED") {
        addWarning(arguments.model, "RAW_ROUTE_INSTANCE_STATUS_CONTRADICTS_CANONICAL_MOTION", "route_instances.status is PLANNED while canonical or route-leg start proof says the trip has started.", "route_instances.status");
      }
      if (arguments.explicitStartProof AND routeTimelineAuthority EQ "scheduled_projection") {
        addWarning(arguments.model, "SCHEDULED_TIMELINE_CONTRADICTS_START_PROOF", "Projection routeTimeline is scheduled while explicit start proof exists.", "TripProgressProjectionService.routeTimeline");
      }
      if (structKeyExists(arguments.progressSummary, "startedRows") AND safeNumber(arguments.progressSummary.startedRows) GT 0 AND safeNumber(arguments.progressSummary.startedStatusRows) EQ 0) {
        addWarning(arguments.model, "LEG_STARTED_STATUS_NOT_STARTED", "A route progress row has leg_started_at without a STARTED status.", "route_instance_leg_progress");
      }
    </cfscript>
  </cffunction>

  <cffunction name="finalizeAuthorityWarnings" access="private" returntype="void" output="false">
    <cfargument name="model" type="struct" required="true">
    <cfscript>
      arguments.model.displayAuthority.warnings = duplicate(arguments.model.warnings);
    </cfscript>
  </cffunction>

  <cffunction name="addWarning" access="private" returntype="void" output="false">
    <cfargument name="model" type="struct" required="true">
    <cfargument name="code" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfargument name="source" type="string" required="false" default="view_model">
    <cfscript>
      arrayAppend(arguments.model.warnings, {
        "code" = arguments.code,
        "message" = arguments.message,
        "source" = arguments.source
      });
    </cfscript>
  </cffunction>

  <cffunction name="findCurrentTimelineLeg" access="private" returntype="struct" output="false">
    <cfargument name="routeTimeline" type="struct" required="true">
    <cfscript>
      var i = 0;
      var currentOrder = (structKeyExists(arguments.routeTimeline, "currentLegOrder") ? safeNumber(arguments.routeTimeline.currentLegOrder) : 0);
      if (!structKeyExists(arguments.routeTimeline, "legs") OR !isArray(arguments.routeTimeline.legs)) {
        return {};
      }
      for (i = 1; i LTE arrayLen(arguments.routeTimeline.legs); i++) {
        if (structKeyExists(arguments.routeTimeline.legs[i], "isCurrent") AND arguments.routeTimeline.legs[i].isCurrent EQ true) {
          return arguments.routeTimeline.legs[i];
        }
        if (currentOrder GT 0 AND structKeyExists(arguments.routeTimeline.legs[i], "routeLegOrder") AND safeNumber(arguments.routeTimeline.legs[i].routeLegOrder) EQ currentOrder) {
          return arguments.routeTimeline.legs[i];
        }
      }
      return {};
    </cfscript>
  </cffunction>

  <cffunction name="queryRows" access="private" returntype="array" output="false">
    <cfargument name="q" type="query" required="true">
    <cfargument name="columns" type="array" required="true">
    <cfscript>
      var rows = [];
      var i = 0;
      var c = "";
      var row = {};
      for (i = 1; i LTE arguments.q.recordCount; i++) {
        row = {};
        for (c in arguments.columns) {
          row[c] = (listFindNoCase(arguments.q.columnList, c) ? arguments.q[c][i] : "");
        }
        arrayAppend(rows, row);
      }
      return rows;
    </cfscript>
  </cffunction>

  <cffunction name="buildCoordinatePoint" access="private" returntype="struct" output="false">
    <cfargument name="label" type="any" required="true">
    <cfargument name="latValue" type="any" required="true">
    <cfargument name="lonValue" type="any" required="true">
    <cfscript>
      var hasCoordinate = (!isNull(arguments.latValue) AND !isNull(arguments.lonValue) AND isNumeric(arguments.latValue) AND isNumeric(arguments.lonValue));
      return {
        "name" = safeString(arguments.label),
        "available" = hasCoordinate,
        "lat" = (hasCoordinate ? val(arguments.latValue) : ""),
        "lon" = (hasCoordinate ? val(arguments.lonValue) : ""),
        "lng" = (hasCoordinate ? val(arguments.lonValue) : "")
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildMapBounds" access="private" returntype="struct" output="false">
    <cfargument name="legs" type="array" required="true">
    <cfscript>
      var out = { "available" = false, "south" = "", "west" = "", "north" = "", "east" = "" };
      var leg = {};
      var pointKey = "";
      var point = {};
      var latVal = 0;
      var lonVal = 0;

      for (leg in arguments.legs) {
        for (pointKey in [ "from", "to" ]) {
          if (!isStruct(leg) OR !structKeyExists(leg, pointKey) OR !isStruct(leg[pointKey])) {
            continue;
          }
          point = leg[pointKey];
          if (!structKeyExists(point, "available") OR point.available NEQ true OR !structKeyExists(point, "lat") OR !structKeyExists(point, "lon") OR !isNumeric(point.lat) OR !isNumeric(point.lon)) {
            continue;
          }
          latVal = val(point.lat);
          lonVal = val(point.lon);
          if (!out.available) {
            out.available = true;
            out.south = latVal;
            out.north = latVal;
            out.west = lonVal;
            out.east = lonVal;
          } else {
            out.south = min(out.south, latVal);
            out.north = max(out.north, latVal);
            out.west = min(out.west, lonVal);
            out.east = max(out.east, lonVal);
          }
        }
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="buildMapCenter" access="private" returntype="struct" output="false">
    <cfargument name="bounds" type="struct" required="true">
    <cfscript>
      if (!structKeyExists(arguments.bounds, "available") OR arguments.bounds.available NEQ true) {
        return { "available" = false, "lat" = "", "lon" = "", "lng" = "" };
      }
      return {
        "available" = true,
        "lat" = (safeNumber(arguments.bounds.south) + safeNumber(arguments.bounds.north)) / 2,
        "lon" = (safeNumber(arguments.bounds.west) + safeNumber(arguments.bounds.east)) / 2,
        "lng" = (safeNumber(arguments.bounds.west) + safeNumber(arguments.bounds.east)) / 2
      };
    </cfscript>
  </cffunction>

  <cffunction name="stateLabel" access="private" returntype="string" output="false">
    <cfargument name="state" type="string" required="true">
    <cfscript>
      switch (arguments.state) {
        case "scheduled": return "Scheduled";
        case "underway": return "Underway";
        case "awaiting_next_leg": return "Awaiting Next Leg";
        case "paused_overnight": return "Secure for the Night";
        case "paused_delayed": return "Delayed";
        case "late": return "Late";
        case "missed": return "Missed";
        case "escalated": return "Escalated";
        case "assistance_needed": return "Assistance Needed";
        case "arrived": return "Arrived";
        case "closed": return "Closed";
      }
      return "Unknown";
    </cfscript>
  </cffunction>

  <cffunction name="stateDetail" access="private" returntype="string" output="false">
    <cfargument name="tripState" type="string" required="true">
    <cfargument name="motionState" type="string" required="true">
    <cfargument name="safetyState" type="string" required="true">
    <cfscript>
      if (arguments.safetyState EQ "assistance_needed") {
        return "Latest check-in reported Assistance Needed.";
      }
      if (listFindNoCase("late,missed,escalated", arguments.safetyState)) {
        return "Monitoring state requires attention.";
      }
      if (arguments.motionState EQ "underway") {
        return "Canonical activity or route leg start proof shows the trip is underway.";
      }
      if (arguments.motionState EQ "scheduled") {
        return "Scheduled departure is pending and no explicit start proof exists.";
      }
      if (arguments.motionState EQ "awaiting_next_leg") {
        return "Trip progress is paused until Start Next Leg is selected.";
      }
      if (arguments.motionState EQ "paused_overnight") {
        return "Trip progress is paused for secure overnight.";
      }
      if (arguments.motionState EQ "paused_delayed") {
        return "Trip progress is paused by the latest Delayed check-in. Monitoring remains active.";
      }
      return "Active Cruise state could not be fully resolved from canonical authorities.";
    </cfscript>
  </cffunction>

  <cffunction name="buildPublicFollowHealth" access="private" returntype="struct" output="false">
    <cfargument name="monitoring" type="struct" required="true">
    <cfscript>
      var stateVal = (structKeyExists(arguments.monitoring, "state") ? uCase(safeString(arguments.monitoring.state)) : "");
      var lastStatusVal = (structKeyExists(arguments.monitoring, "lastCheckinStatus") ? uCase(safeString(arguments.monitoring.lastCheckinStatus)) : "");
      var out = { "label" = "Monitoring unavailable", "variant" = "muted" };

      switch (stateVal) {
        case "LATE":
          out.label = "Late";
          out.variant = "warning";
          break;
        case "MISSED":
          out.label = "Missed Check-In";
          out.variant = "danger";
          break;
        case "ESCALATED":
          out.label = "Escalated";
          out.variant = "danger";
          break;
        case "ACTIVE":
          out.label = "All Good";
          out.variant = "good";
          break;
        default:
          if (len(stateVal)) {
            out.label = formatMonitorStatusLabel(stateVal, "All Good");
            out.variant = "muted";
          }
      }

      if (listFindNoCase("ESCALATED,MISSED,LATE", stateVal)) {
        return out;
      }

      switch (lastStatusVal) {
        case "DELAYED":
          out.label = "Delayed";
          out.variant = "warning";
          break;
        case "CHANGED_PLAN":
          out.label = "Changed Plan";
          out.variant = "warning";
          break;
        case "NEED_ATTENTION":
        case "ASSISTANCE_NEEDED":
          out.label = "Assistance Needed";
          out.variant = "danger";
          break;
        case "SECURE_FOR_NIGHT":
          out.label = "Secure for the Night";
          out.variant = "good";
          break;
      }

      return out;
    </cfscript>
  </cffunction>

  <cffunction name="publicFollowTripStateHelperText" access="private" returntype="string" output="false">
    <cfargument name="tripState" type="string" required="true">
    <cfargument name="motionState" type="string" required="true">
    <cfargument name="safetyState" type="string" required="true">
    <cfscript>
      switch (safeString(arguments.safetyState)) {
        case "assistance_needed":
        case "needs_attention":
          return "Latest check-in reported Assistance Needed.";
        case "escalated":
          return "Monitoring status requires attention.";
      }

      switch (safeString(arguments.tripState)) {
        case "paused_secure_for_night":
          return "The trip is secure for the night.";
        case "paused_delayed":
          return "The trip is delayed and monitoring remains active.";
        case "arrived":
          return "The route is marked arrived.";
        case "closed":
          return "The float plan is closed.";
        case "scheduled":
          return "The trip is scheduled and has not started yet.";
        case "underway":
          return "The trip is underway on the active route.";
        case "awaiting_next_leg":
          return "Trip progress is paused until the next route leg is started.";
      }

      switch (safeString(arguments.motionState)) {
        case "underway":
          return "The trip is underway on the active route.";
        case "awaiting_next_leg":
          return "Trip progress is paused until the next route leg is started.";
        case "scheduled":
          return "The trip is scheduled and has not started yet.";
      }

      return "Trip status is unavailable.";
    </cfscript>
  </cffunction>

  <cffunction name="countPublicFollowCompletedLegs" access="private" returntype="numeric" output="false">
    <cfargument name="routeTimeline" type="struct" required="true">
    <cfscript>
      var legs = (
        structKeyExists(arguments.routeTimeline, "legs")
        AND isArray(arguments.routeTimeline.legs)
        ? arguments.routeTimeline.legs
        : []
      );
      var i = 0;
      var completed = 0;
      var leg = {};

      for (i = 1; i LTE arrayLen(legs); i++) {
        leg = legs[i];
        if (
          isStruct(leg)
          AND (
            (structKeyExists(leg, "isCompleted") AND leg.isCompleted EQ true)
            OR (structKeyExists(leg, "state") AND safeString(leg.state) EQ "completed")
          )
        ) {
          completed += 1;
        }
      }

      return completed;
    </cfscript>
  </cffunction>

  <cffunction name="deriveLegStatusLabel" access="private" returntype="string" output="false">
    <cfargument name="timelineLeg" type="struct" required="true">
    <cfargument name="currentLeg" type="struct" required="true">
    <cfscript>
      var statusVal = "";
      if (structKeyExists(arguments.currentLeg, "status")) {
        statusVal = safeString(arguments.currentLeg.status);
      } else if (structKeyExists(arguments.timelineLeg, "status")) {
        statusVal = safeString(arguments.timelineLeg.status);
      }
      if (statusVal EQ "STARTED" OR statusVal EQ "IN_PROGRESS") {
        return "Underway";
      }
      if (statusVal EQ "COMPLETED") {
        return "Completed";
      }
      return "Scheduled";
    </cfscript>
  </cffunction>

  <cffunction name="firstDate" access="private" returntype="any" output="false">
    <cfargument name="primaryValue" type="any" required="true">
    <cfargument name="secondaryValue" type="any" required="true">
    <cfscript>
      if (isDate(arguments.primaryValue)) {
        return arguments.primaryValue;
      }
      if (isDate(arguments.secondaryValue)) {
        return arguments.secondaryValue;
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="formatUtc" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      if (!isDate(arguments.value)) {
        return "";
      }
      return dateTimeFormat(arguments.value, "yyyy-mm-dd'T'HH:nn:ss'Z'");
    </cfscript>
  </cffunction>

  <cffunction name="formatRawUtc" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      var rawUtc = normalizeUtcSqlString(arguments.value);
      if (!len(rawUtc)) {
        return "";
      }
      return replace(rawUtc, " ", "T", "one") & "Z";
    </cfscript>
  </cffunction>

  <cffunction name="formatLocal" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="true">
    <cfargument name="timezone" type="string" required="true">
    <cfscript>
      var tzId = len(safeString(arguments.timezone)) ? safeString(arguments.timezone) : "UTC";
      if (!isDate(arguments.value)) {
        return "";
      }
      try {
        return dateTimeFormat(arguments.value, "yyyy-mm-dd HH:nn:ss", tzId);
      } catch (any localFormatErr) {
        return dateTimeFormat(arguments.value, "yyyy-mm-dd HH:nn:ss");
      }
    </cfscript>
  </cffunction>

  <cffunction name="formatLocalDisplay" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="true">
    <cfargument name="timezone" type="string" required="true">
    <cfscript>
      var tzId = len(safeString(arguments.timezone)) ? safeString(arguments.timezone) : "UTC";
      if (!isDate(arguments.value)) {
        return "";
      }
      try {
        return dateTimeFormat(arguments.value, "mmm d, yyyy h:nn tt", tzId);
      } catch (any localDisplayErr) {
        return dateTimeFormat(arguments.value, "mmm d, yyyy h:nn tt");
      }
    </cfscript>
  </cffunction>

  <cffunction name="normalizeUtcSqlString" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      var raw = trim(safeString(arguments.value));
      if (!len(raw)) {
        return "";
      }
      raw = replace(raw, "T", " ", "one");
      raw = reReplace(raw, "Z$", "", "one");
      raw = reReplace(raw, "\.[0-9]+$", "", "one");
      if (reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}$", raw)) {
        raw &= ":00";
      }
      if (!reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$", raw)) {
        return "";
      }
      return left(raw, 19);
    </cfscript>
  </cffunction>

  <cffunction name="formatUtcSqlStringAsLocalDisplay" access="private" returntype="string" output="false">
    <cfargument name="utcSqlValue" type="string" required="true">
    <cfargument name="timezone" type="string" required="true">
    <cfscript>
      var rawUtc = normalizeUtcSqlString(arguments.utcSqlValue);
      var tzId = trim(safeString(arguments.timezone));
      var formatter = "";
      var displayFormatter = "";
      var localDateTime = "";
      var zoneId = "";
      var instant = "";
      var zonedDateTime = "";
      if (!len(rawUtc) OR !len(tzId)) {
        return "";
      }
      try {
        formatter = createObject("java", "java.time.format.DateTimeFormatter").ofPattern("yyyy-MM-dd HH:mm:ss");
        displayFormatter = createObject("java", "java.time.format.DateTimeFormatter").ofPattern("MMM d, yyyy h:mm a");
        localDateTime = createObject("java", "java.time.LocalDateTime").parse(rawUtc, formatter);
        instant = localDateTime.atOffset(createObject("java", "java.time.ZoneOffset").UTC).toInstant();
        zoneId = createObject("java", "java.time.ZoneId").of(tzId);
        zonedDateTime = createObject("java", "java.time.ZonedDateTime").ofInstant(instant, zoneId);
        return toString(displayFormatter.format(zonedDateTime));
      } catch (any utcLocalDisplayErr) {
        return "";
      }
    </cfscript>
  </cffunction>

  <cffunction name="formatPublicFollowLocalLabel" access="private" returntype="string" output="false">
    <cfargument name="utcValue" type="any" required="true">
    <cfargument name="timezone" type="string" required="true">
    <cfscript>
      var raw = safeString(arguments.utcValue);
      var rawUtc = "";
      var tzId = safeString(arguments.timezone);
      var tzLabel = "";
      var localLabel = "";

      if (!len(raw)) {
        return "";
      }

      rawUtc = normalizeUtcSqlString(raw);
      if (!len(rawUtc) OR !len(tzId)) {
        return "";
      }

      localLabel = formatUtcSqlStringAsLocalDisplay(rawUtc, tzId);
      if (!len(localLabel)) {
        return "";
      }

      tzLabel = publicFollowTimezoneLabel(tzId, rawUtc);
      return localLabel & (len(tzLabel) ? " " & tzLabel : "");
    </cfscript>
  </cffunction>

  <cffunction name="publicFollowTimezoneLabel" access="private" returntype="string" output="false">
    <cfargument name="timezone" type="string" required="true">
    <cfargument name="referenceValue" type="any" required="true">
    <cfscript>
      var tzId = safeString(arguments.timezone);
      if (!len(tzId)) {
        tzId = "UTC";
      }
      return tzId;
    </cfscript>
  </cffunction>

  <cffunction name="formatMinutesLabel" access="private" returntype="string" output="false">
    <cfargument name="minutes" type="numeric" required="true">
    <cfscript>
      var minuteValue = int(arguments.minutes);
      return minuteValue & " minute" & (minuteValue EQ 1 ? "" : "s");
    </cfscript>
  </cffunction>

  <cffunction name="normalizeLocalTimeValue" access="private" returntype="string" output="false">
    <cfargument name="rawValue" type="any" required="true">
    <cfargument name="defaultValue" type="string" required="false" default="">
    <cfscript>
      var normalized = safeString(arguments.rawValue);
      var parts = [];
      var hourValue = 0;
      var minuteValue = 0;
      var secondValue = 0;
      if (isDate(arguments.rawValue)) {
        return timeFormat(arguments.rawValue, "HH:nn:ss");
      }
      if (!len(normalized)) {
        return arguments.defaultValue;
      }
      normalized = listFirst(normalized, " ");
      if (!reFind("^[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?$", normalized)) {
        return arguments.defaultValue;
      }
      parts = listToArray(normalized, ":");
      hourValue = val(parts[1]);
      minuteValue = val(parts[2]);
      secondValue = (arrayLen(parts) GTE 3 ? val(parts[3]) : 0);
      if (hourValue LT 0 OR hourValue GT 23 OR minuteValue LT 0 OR minuteValue GT 59 OR secondValue LT 0 OR secondValue GT 59) {
        return arguments.defaultValue;
      }
      return numberFormat(hourValue, "00") & ":" & numberFormat(minuteValue, "00") & ":" & numberFormat(secondValue, "00");
    </cfscript>
  </cffunction>

  <cffunction name="formatLocalTimeLabel" access="private" returntype="string" output="false">
    <cfargument name="rawValue" type="any" required="true">
    <cfargument name="fallback" type="string" required="false" default="8:00 AM">
    <cfscript>
      var normalized = normalizeLocalTimeValue(arguments.rawValue, "");
      var parts = [];
      var displayDt = "";
      if (!len(normalized)) {
        return arguments.fallback;
      }
      parts = listToArray(normalized, ":");
      displayDt = createDateTime(2000, 1, 1, val(parts[1]), val(parts[2]), (arrayLen(parts) GTE 3 ? val(parts[3]) : 0));
      return timeFormat(displayDt, "h:nn tt");
    </cfscript>
  </cffunction>

  <cffunction name="resolveTimezone" access="private" returntype="string" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfscript>
      var tz = safeString(arguments.qPlan.departureTZ[1]);
      if (!len(tz)) {
        tz = safeString(arguments.qPlan.departTimezone[1]);
      }
      if (!len(tz)) {
        tz = safeString(arguments.qPlan.vessel_timezone[1]);
      }
      if (!len(tz)) {
        tz = "UTC";
      }
      return tz;
    </cfscript>
  </cffunction>

  <cffunction name="firstNonEmpty" access="private" returntype="string" output="false">
    <cfargument name="values" type="array" required="true">
    <cfscript>
      var value = "";
      for (value in arguments.values) {
        if (len(safeString(value))) {
          return safeString(value);
        }
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="firstNumber" access="private" returntype="numeric" output="false">
    <cfargument name="values" type="array" required="true">
    <cfscript>
      var value = 0;
      for (value in arguments.values) {
        if (safeNumber(value) GT 0) {
          return safeNumber(value);
        }
      }
      return 0;
    </cfscript>
  </cffunction>

  <cffunction name="formatMonitorStatusLabel" access="private" returntype="string" output="false">
    <cfargument name="rawStatus" type="string" required="true">
    <cfargument name="activeLabel" type="string" required="false" default="Active">
    <cfscript>
      var status = uCase(trim(arguments.rawStatus));
      if (!len(status)) {
        return "";
      }
      if (status EQ "ACTIVE") {
        return arguments.activeLabel;
      }
      if (listFindNoCase("OVERDUE,DUE_NOW,OVERDUE_1H,OVERDUE_2H,OVERDUE_3H,OVERDUE_4H,OVERDUE_12H,OVERDUE_24H", status)) {
        return "Overdue";
      }
      return startCaseWords(replace(status, "_", " ", "all"));
    </cfscript>
  </cffunction>

  <cffunction name="startCaseWords" access="private" returntype="string" output="false">
    <cfargument name="inputText" type="string" required="true">
    <cfscript>
      var normalized = lCase(trim(arguments.inputText));
      var parts = listToArray(normalized, " ");
      var outputParts = [];
      var i = 0;
      var part = "";

      for (i = 1; i LTE arrayLen(parts); i++) {
        part = trim(parts[i]);
        if (!len(part)) {
          continue;
        }
        arrayAppend(outputParts, uCase(left(part, 1)) & mid(part, 2, len(part)));
      }

      if (!arrayLen(outputParts)) {
        return "";
      }
      return arrayToList(outputParts, " ");
    </cfscript>
  </cffunction>

  <cffunction name="normalizeContactPhone" access="private" returntype="string" output="false">
    <cfargument name="rawPhone" type="any" required="false" default="">
    <cfscript>
      var raw = "";
      var digits = "";
      var hasPlus = false;

      if (!isNull(arguments.rawPhone)) {
        raw = trim(toString(arguments.rawPhone));
      }
      if (!len(raw)) {
        return "";
      }
      hasPlus = (left(raw, 1) EQ "+");
      digits = reReplace(raw, "[^0-9]", "", "all");
      if (!len(digits)) {
        return "";
      }
      return (hasPlus ? "+" : "") & digits;
    </cfscript>
  </cffunction>

  <cffunction name="buildContactPhoneHref" access="private" returntype="string" output="false">
    <cfargument name="rawPhone" type="any" required="false" default="">
    <cfargument name="scheme" type="string" required="false" default="tel">
    <cfscript>
      var normalizedPhone = normalizeContactPhone(arguments.rawPhone);
      if (!len(normalizedPhone)) {
        return "";
      }
      return lCase(trim(arguments.scheme)) & ":" & normalizedPhone;
    </cfscript>
  </cffunction>

  <cffunction name="buildContactEmailHref" access="private" returntype="string" output="false">
    <cfargument name="rawEmail" type="any" required="false" default="">
    <cfscript>
      var email = "";
      if (!isNull(arguments.rawEmail)) {
        email = trim(toString(arguments.rawEmail));
      }
      if (!len(email)) {
        return "";
      }
      return "mailto:" & email;
    </cfscript>
  </cffunction>

  <cffunction name="safeString" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      if (isNull(arguments.value)) {
        return "";
      }
      return trim(toString(arguments.value));
    </cfscript>
  </cffunction>

  <cffunction name="safeNumber" access="private" returntype="numeric" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      if (isNull(arguments.value) OR !isNumeric(arguments.value)) {
        return 0;
      }
      return val(arguments.value);
    </cfscript>
  </cffunction>

</cfcomponent>
