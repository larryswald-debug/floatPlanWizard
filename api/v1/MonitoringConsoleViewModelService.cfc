<cfcomponent output="false">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfscript>
      variables.datasource = arguments.datasource;
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="getMonitoringConsoleViewModel" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="false" default="0">
    <cfscript>
      var dto = buildBaseDto();
      var nowUtc = getCurrentUtcTimestamp();
      var context = {};
      var qPlan = queryNew("");
      var qMonitoring = queryNew("");
      var latestGps = {};
      var gpsHistory = [];
      var routeMap = {};
      var timezone = "UTC";

      dto.generatedAtUtc = formatUtc(nowUtc);
      dto.generatedAtLocalLabel = formatLocalLabel(nowUtc, timezone);
      dto.technicalSnapshot.generatedAtUtc = dto.generatedAtUtc;

      if (arguments.userId LTE 0) {
        dto.success = false;
        setEmptyState(dto, "UNAUTHENTICATED");
        return dto;
      }

      try {
        context = resolveActiveMonitoringContext(arguments.userId, arguments.floatPlanId);
        if (!context.success) {
          dto.success = false;
          setEmptyState(dto, context.emptyStateCode);
          return dto;
        }

        qPlan = loadPlanContext(arguments.userId, context.floatPlanId);
        if (qPlan.recordCount EQ 0) {
          dto.success = false;
          setEmptyState(dto, "NO_ACTIVE_FLOAT_PLAN");
          return dto;
        }

        timezone = resolveTimezone(qPlan);
        dto.generatedAtLocalLabel = formatLocalLabel(nowUtc, timezone);

        routeMap = buildMapData(context.routeInstanceId, arguments.userId);
        dto.identity = buildIdentitySection(arguments.userId, qPlan, context, routeMap);
        dto.tripState = buildTripStateSection(qPlan, routeMap);

        qMonitoring = loadMonitoringRow(arguments.userId, context.floatPlanId);
        if (qMonitoring.recordCount EQ 0) {
          dto.success = false;
          dto.map = buildMapSection(routeMap, buildDefaultLastCheckinLocation());
          setEmptyState(dto, "MONITORING_ROW_MISSING");
          return dto;
        }

        dto.monitoring = buildMonitoringSection(qMonitoring, qPlan, timezone);
        dto.tripState.safetyState = dto.monitoring.state;
        dto.technicalSnapshot.monitoringRowId = dto.monitoring.monitoringRowId;
        dto.technicalSnapshot.monitoringState = dto.monitoring.state;
        dto.technicalSnapshot.monitoringMode = dto.monitoring.mode;
        dto.technicalSnapshot.expectedCheckinAtUtc = dto.monitoring.expectedCheckinAtUtc;
        dto.technicalSnapshot.nextMonitorEvalAtUtc = dto.monitoring.nextMonitorEvalAtUtc;

        if (dto.monitoring.state EQ "CLOSED" OR len(safeString(qPlan.closedAt[1]))) {
          dto.success = false;
          setEmptyState(dto, "COMPLETED_OR_CLOSED");
        }

        gpsHistory = loadGpsHistory(arguments.userId, context.floatPlanId, timezone, 20);
        latestGps = findLatestGpsHistoryLocation(gpsHistory);
        dto.lastCheckinLocation = buildLastCheckinLocation(latestGps, timezone, nowUtc);
        if (
          dto.lastCheckinLocation.hasLocation
          AND dto.lastCheckinLocation.sourceCode EQ "COMPANION_APP"
          AND val(dto.lastCheckinLocation.canonicalEventId) LTE 0
        ) {
          addWarning(
            dto,
            "CANONICAL_CORRELATION_UNAVAILABLE",
            "Canonical event correlation unavailable",
            "The latest check-in location is sourced from the companion GPS event. No deterministic canonical event link is exposed.",
            "info"
          );
        } else if (dto.success) {
          setEmptyState(dto, "NO_GPS_CHECKIN");
        }

        dto.map = buildMapSection(routeMap, dto.lastCheckinLocation);
        dto.auditTimeline = loadMonitoringAudit(arguments.userId, context.floatPlanId, timezone);
        dto.gpsHistory = gpsHistory;
        dto.technicalSnapshot = buildTechnicalSnapshot(dto, latestGps);
        dto.safetyCopy = buildSafetyCopy(dto.lastCheckinLocation);

        return dto;
      } catch (any modelError) {
        dto.success = false;
        setEmptyState(dto, "SERVICE_UNAVAILABLE");
        addWarning(
          dto,
          "MODEL_BUILD_FAILED",
          "Monitoring Console data unavailable",
          "The Monitoring Console view model could not be built. No private diagnostic details were exposed.",
          "warning"
        );
        return dto;
      }
    </cfscript>
  </cffunction>

  <cffunction name="scanForbiddenPrivateKeysForTests" access="public" returntype="array" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      var findings = [];
      scanForbiddenKeys(arguments.value, "", findings);
      return findings;
    </cfscript>
  </cffunction>

  <cffunction name="buildBaseDto" access="private" returntype="struct" output="false">
    <cfscript>
      return {
        "success" = true,
        "version" = 1,
        "source" = "MonitoringConsoleViewModelService.getMonitoringConsoleViewModel",
        "generatedAtUtc" = "",
        "generatedAtLocalLabel" = "",
        "identity" = buildDefaultIdentity(),
        "tripState" = buildDefaultTripState(),
        "monitoring" = buildDefaultMonitoring(),
        "lastCheckinLocation" = buildDefaultLastCheckinLocation(),
        "map" = buildDefaultMap(),
        "auditTimeline" = [],
        "gpsHistory" = [],
        "technicalSnapshot" = buildDefaultTechnicalSnapshot(),
        "safetyCopy" = buildSafetyCopy(buildDefaultLastCheckinLocation()),
        "emptyState" = buildEmptyState(""),
        "warnings" = []
      };
    </cfscript>
  </cffunction>

  <cffunction name="resolveActiveMonitoringContext" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="false" default="0">
    <cfscript>
      var out = {
        "success" = false,
        "emptyStateCode" = "NO_ACTIVE_FLOAT_PLAN",
        "floatPlanId" = 0,
        "routeInstanceId" = 0,
        "currentGroup" = {}
      };
      var floatPlanService = createApiComponent("floatplan");
      var currentGroup = floatPlanService.resolveCurrentRouteFloatPlanGroup(arguments.userId);

      if (!isStruct(currentGroup) OR !structKeyExists(currentGroup, "SUCCESS") OR !currentGroup.SUCCESS) {
        if (isStruct(currentGroup) AND structKeyExists(currentGroup, "ERROR") AND currentGroup.ERROR EQ "MULTIPLE_ACTIVE_GROUPS") {
          out.emptyStateCode = "MULTIPLE_ACTIVE_GROUPS";
        }
        return out;
      }

      if (structKeyExists(currentGroup, "ERROR") AND currentGroup.ERROR EQ "MULTIPLE_ACTIVE_GROUPS") {
        out.emptyStateCode = "MULTIPLE_ACTIVE_GROUPS";
        return out;
      }

      if (!structKeyExists(currentGroup, "IS_ACTIVE") OR currentGroup.IS_ACTIVE NEQ true) {
        out.emptyStateCode = "NO_ACTIVE_FLOAT_PLAN";
        return out;
      }

      out.floatPlanId = readStructNumber(currentGroup, "FLOATPLANID");
      out.routeInstanceId = readStructNumber(currentGroup, "ROUTE_INSTANCE_ID");
      if (arguments.floatPlanId GT 0 AND arguments.floatPlanId NEQ out.floatPlanId) {
        out.emptyStateCode = "NO_ACTIVE_FLOAT_PLAN";
        out.floatPlanId = 0;
        out.routeInstanceId = 0;
        return out;
      }
      if (out.routeInstanceId LTE 0) {
        out.emptyStateCode = "NO_ACTIVE_ROUTE";
        return out;
      }

      out.success = true;
      out.emptyStateCode = "";
      out.currentGroup = duplicate(currentGroup);
      return out;
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
          fp.departing,
          fp.`returning`,
          fp.departureTZ,
          fp.departTimezone,
          fp.returnTZ,
          fp.returnTimezone,
          fp.manual_delay_minutes_total,
          fp.closedAt,
          fp.route_instance_id,
          ri.status AS route_status,
          ri.generated_route_id AS route_id,
          ri.generated_route_code,
          ri.template_route_code,
          ri.start_location,
          ri.end_location,
          lr.name AS template_route_name,
          lr.short_code AS template_route_short_code,
          v.vesselName,
          v.timezone AS vessel_timezone,
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
        LEFT JOIN vessels v
          ON v.vesselID = fp.vesselId
        WHERE fp.floatPlanId = :floatPlanId
          AND fp.userId = :userId
        LIMIT 1
      ", {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      }, { datasource = variables.datasource });
    </cfscript>
  </cffunction>

  <cffunction name="loadMonitoringRow" access="private" returntype="query" output="false">
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
          last_monitor_eval_at
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

  <cffunction name="loadLatestCompanionGpsCheckin" access="private" returntype="query" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      return queryExecute("
        SELECT
          id,
          mobile_submission_id,
          canonical_status,
          checkin_context,
          latitude,
          longitude,
          gps_accuracy_meters,
          gps_altitude_meters,
          speed_knots,
          heading_degrees,
          location_captured_at_utc,
          device_platform,
          offline_created_at_utc,
          received_at_utc,
          process_status,
          created_utc
        FROM floatplan_companion_events
        WHERE user_id = :userId
          AND floatplan_id = :floatPlanId
          AND event_type = 'CHECKIN'
          AND latitude IS NOT NULL
          AND longitude IS NOT NULL
        ORDER BY COALESCE(received_at_utc, created_utc, location_captured_at_utc) DESC, id DESC
        LIMIT 1
      ", {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      }, { datasource = variables.datasource });
    </cfscript>
  </cffunction>

  <cffunction name="loadGpsHistory" access="private" returntype="array" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfargument name="timezone" type="string" required="true">
    <cfargument name="limit" type="numeric" required="false" default="20">
    <cfscript>
      var limitRows = min(max(val(arguments.limit), 1), 20);
      var canonicalScanLimit = limitRows * 2;
      var qHistory = queryExecute("
        SELECT
          id,
          mobile_submission_id,
          canonical_status,
          checkin_context,
          latitude,
          longitude,
          gps_accuracy_meters,
          gps_altitude_meters,
          speed_knots,
          heading_degrees,
          location_captured_at_utc,
          received_at_utc,
          process_status,
          created_utc
        FROM floatplan_companion_events
        WHERE user_id = :userId
          AND floatplan_id = :floatPlanId
          AND event_type = 'CHECKIN'
        ORDER BY COALESCE(received_at_utc, created_utc, location_captured_at_utc) DESC, id DESC
        LIMIT :limitRows
      ", {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        limitRows = { value = limitRows, cfsqltype = "cf_sql_integer" }
      }, { datasource = variables.datasource });
      var qCanonical = queryExecute("
        SELECT id, event_status, occurred_at_utc, payload_json
        FROM floatplan_events
        WHERE floatplan_id = :floatPlanId
          AND user_id = :userId
          AND event_type = 'CHECKIN_RECEIVED'
          AND source = 'active_cruise_checkin'
          AND voided_at_utc IS NULL
        ORDER BY occurred_at_utc DESC, id DESC
        LIMIT :limitRows
      ", {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        limitRows = { value = canonicalScanLimit, cfsqltype = "cf_sql_integer" }
      }, { datasource = variables.datasource });
      var items = [];
      var i = 0;
      var hasGps = false;
      var checkinAt = "";
      var statusCode = "";
      var payload = {};
      var location = {};
      var capturedAt = "";
      var receivedAt = "";

      for (i = 1; i LTE qHistory.recordCount; i++) {
        hasGps = isNumericValue(qHistory.latitude[i]) AND isNumericValue(qHistory.longitude[i]);
        checkinAt = firstDate(qHistory.received_at_utc[i], qHistory.created_utc[i], qHistory.location_captured_at_utc[i]);
        statusCode = normalizeStatusCode(qHistory.canonical_status[i]);
        arrayAppend(items, {
          "id" = "companion-" & safeString(qHistory.id[i]),
          "checkinAtUtc" = formatUtc(checkinAt),
          "checkinLocalLabel" = formatLocalLabel(checkinAt, arguments.timezone),
          "statusCode" = statusCode,
          "statusLabel" = labelizeStatus(statusCode),
          "sourceCode" = "COMPANION_APP",
          "sourceLabel" = (hasGps ? "Companion App GPS" : "Companion App"),
          "hasGps" = hasGps,
          "latitude" = (hasGps ? safeNumber(qHistory.latitude[i]) : nullValue()),
          "longitude" = (hasGps ? safeNumber(qHistory.longitude[i]) : nullValue()),
          "accuracyMeters" = (isNumericValue(qHistory.gps_accuracy_meters[i]) ? safeNumber(qHistory.gps_accuracy_meters[i]) : nullValue()),
          "accuracyLabel" = buildAccuracyLabel(qHistory.gps_accuracy_meters[i]),
          "altitudeMeters" = (isNumericValue(qHistory.gps_altitude_meters[i]) ? safeNumber(qHistory.gps_altitude_meters[i]) : nullValue()),
          "speedKnots" = (isNumericValue(qHistory.speed_knots[i]) ? safeNumber(qHistory.speed_knots[i]) : nullValue()),
          "headingDegrees" = (isNumericValue(qHistory.heading_degrees[i]) ? safeNumber(qHistory.heading_degrees[i]) : nullValue()),
          "capturedAtUtc" = formatUtc(qHistory.location_captured_at_utc[i]),
          "capturedAtLocalLabel" = formatLocalLabel(qHistory.location_captured_at_utc[i], arguments.timezone),
          "receivedAtUtc" = formatUtc(qHistory.received_at_utc[i]),
          "receivedAtLocalLabel" = formatLocalLabel(qHistory.received_at_utc[i], arguments.timezone),
          "companionEventId" = safeNumber(qHistory.id[i]),
          "canonicalEventId" = 0,
          "mobileSubmissionId" = safeString(qHistory.mobile_submission_id[i]),
          "processedStatus" = safeString(qHistory.process_status[i]),
          "gpsQualityLabel" = buildAccuracyQualityLabel(qHistory.gps_accuracy_meters[i]),
          "notePreview" = "",
          "rowTone" = buildRowTone(statusCode, hasGps)
        });
      }

      for (i = 1; i LTE qCanonical.recordCount; i++) {
        payload = parseJsonStruct(qCanonical.payload_json[i]);
        location = (structKeyExists(payload, "location") AND isStruct(payload.location) ? payload.location : {});
        hasGps = (
          structKeyExists(location, "latitude")
          AND structKeyExists(location, "longitude")
          AND isNumericValue(location.latitude)
          AND isNumericValue(location.longitude)
        );
        capturedAt = parseStoredUtcDate(structKeyExists(location, "capturedAtUtc") ? location.capturedAtUtc : "");
        receivedAt = qCanonical.occurred_at_utc[i];
        checkinAt = firstDate(receivedAt, capturedAt);
        statusCode = normalizeStatusCode(qCanonical.event_status[i]);
        arrayAppend(items, {
          "id" = "active-cruise-" & safeString(qCanonical.id[i]),
          "checkinAtUtc" = formatUtc(checkinAt),
          "checkinLocalLabel" = formatLocalLabel(checkinAt, arguments.timezone),
          "statusCode" = statusCode,
          "statusLabel" = labelizeStatus(statusCode),
          "sourceCode" = "ACTIVE_CRUISE_WEB",
          "sourceLabel" = (hasGps ? "Active Cruise GPS" : "Active Cruise Web"),
          "hasGps" = hasGps,
          "latitude" = (hasGps ? safeNumber(location.latitude) : nullValue()),
          "longitude" = (hasGps ? safeNumber(location.longitude) : nullValue()),
          "accuracyMeters" = (structKeyExists(location, "accuracyMeters") AND isNumericValue(location.accuracyMeters) ? safeNumber(location.accuracyMeters) : nullValue()),
          "accuracyLabel" = (structKeyExists(location, "accuracyMeters") ? buildAccuracyLabel(location.accuracyMeters) : ""),
          "altitudeMeters" = (structKeyExists(location, "altitudeMeters") AND isNumericValue(location.altitudeMeters) ? safeNumber(location.altitudeMeters) : nullValue()),
          "speedKnots" = (structKeyExists(location, "speedKnots") AND isNumericValue(location.speedKnots) ? safeNumber(location.speedKnots) : nullValue()),
          "headingDegrees" = (structKeyExists(location, "headingDegrees") AND isNumericValue(location.headingDegrees) ? safeNumber(location.headingDegrees) : nullValue()),
          "capturedAtUtc" = formatUtc(capturedAt),
          "capturedAtLocalLabel" = formatLocalLabel(capturedAt, arguments.timezone),
          "receivedAtUtc" = formatUtc(receivedAt),
          "receivedAtLocalLabel" = formatLocalLabel(receivedAt, arguments.timezone),
          "companionEventId" = 0,
          "canonicalEventId" = safeNumber(qCanonical.id[i]),
          "mobileSubmissionId" = "",
          "processedStatus" = "RECORDED",
          "gpsQualityLabel" = (structKeyExists(location, "accuracyMeters") ? buildAccuracyQualityLabel(location.accuracyMeters) : "Unknown"),
          "notePreview" = "",
          "rowTone" = buildRowTone(statusCode, hasGps)
        });
      }

      sortGpsHistoryItemsDesc(items);
      return limitArray(items, limitRows);
    </cfscript>
  </cffunction>

  <cffunction name="loadMonitoringAudit" access="private" returntype="array" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfargument name="timezone" type="string" required="true">
    <cfscript>
      var items = [];
      items = appendCompanionAuditItems(items, arguments.userId, arguments.floatPlanId, arguments.timezone);
      items = appendMonitorAuditItems(items, arguments.userId, arguments.floatPlanId, arguments.timezone);
      items = appendCanonicalAuditItems(items, arguments.userId, arguments.floatPlanId, arguments.timezone);
      sortAuditItemsDesc(items);
      return limitArray(items, 20);
    </cfscript>
  </cffunction>

  <cffunction name="findLatestGpsHistoryLocation" access="private" returntype="struct" output="false">
    <cfargument name="gpsHistory" type="array" required="true">
    <cfscript>
      var i = 0;
      for (i = 1; i LTE arrayLen(arguments.gpsHistory); i++) {
        if (
          isStruct(arguments.gpsHistory[i])
          AND structKeyExists(arguments.gpsHistory[i], "hasGps")
          AND arguments.gpsHistory[i].hasGps
        ) {
          return arguments.gpsHistory[i];
        }
      }
      return {};
    </cfscript>
  </cffunction>

  <cffunction name="appendCompanionAuditItems" access="private" returntype="array" output="false">
    <cfargument name="items" type="array" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfargument name="timezone" type="string" required="true">
    <cfscript>
      var qEvents = queryExecute("
        SELECT id, canonical_status, latitude, longitude, gps_accuracy_meters, location_captured_at_utc, received_at_utc, created_utc
        FROM floatplan_companion_events
        WHERE user_id = :userId
          AND floatplan_id = :floatPlanId
          AND event_type = 'CHECKIN'
        ORDER BY COALESCE(received_at_utc, created_utc, location_captured_at_utc) DESC, id DESC
        LIMIT 10
      ", {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      }, { datasource = variables.datasource });
      var i = 0;
      var occurredAt = "";
      var statusCode = "";
      var hasGps = false;

      for (i = 1; i LTE qEvents.recordCount; i++) {
        occurredAt = firstDate(qEvents.received_at_utc[i], qEvents.created_utc[i], qEvents.location_captured_at_utc[i]);
        statusCode = normalizeStatusCode(qEvents.canonical_status[i]);
        hasGps = isNumericValue(qEvents.latitude[i]) AND isNumericValue(qEvents.longitude[i]);
        arrayAppend(arguments.items, buildAuditItem(
          "companion-checkin-" & qEvents.id[i],
          occurredAt,
          arguments.timezone,
          "COMPANION_CHECKIN_RECEIVED",
          "Companion check-in received",
          labelizeStatus(statusCode) & " was submitted from the companion app.",
          "success",
          "floatplan_companion_events",
          safeNumber(qEvents.id[i]),
          0,
          0,
          false
        ));
        if (hasGps) {
          arrayAppend(arguments.items, buildAuditItem(
            "gps-captured-" & qEvents.id[i],
            occurredAt,
            arguments.timezone,
            "GPS_CAPTURED",
            "GPS captured with check-in",
            "GPS coordinates were stored with " & buildAccuracyLabel(qEvents.gps_accuracy_meters[i]) & " accuracy.",
            "info",
            "floatplan_companion_events",
            safeNumber(qEvents.id[i]),
            0,
            0,
            false
          ));
        }
      }
      return arguments.items;
    </cfscript>
  </cffunction>

  <cffunction name="appendMonitorAuditItems" access="private" returntype="array" output="false">
    <cfargument name="items" type="array" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfargument name="timezone" type="string" required="true">
    <cfscript>
      var qEvents = queryExecute("
        SELECT id, event_type, from_state, to_state, event_at, checkin_status, actor_type
        FROM floatplan_monitor_events
        WHERE user_id = :userId
          AND float_plan_id = :floatPlanId
        ORDER BY event_at DESC, id DESC
        LIMIT 20
      ", {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      }, { datasource = variables.datasource });
      var i = 0;
      var mapped = {};

      for (i = 1; i LTE qEvents.recordCount; i++) {
        mapped = mapMonitorAuditEvent(qEvents.event_type[i], qEvents.from_state[i], qEvents.to_state[i], qEvents.checkin_status[i]);
        if (!mapped.supported) {
          continue;
        }
        arrayAppend(arguments.items, buildAuditItem(
          "monitor-" & qEvents.id[i],
          qEvents.event_at[i],
          arguments.timezone,
          mapped.type,
          mapped.title,
          mapped.detail,
          mapped.tone,
          "floatplan_monitor_events",
          0,
          0,
          safeNumber(qEvents.id[i]),
          false
        ));
      }
      return arguments.items;
    </cfscript>
  </cffunction>

  <cffunction name="appendCanonicalAuditItems" access="private" returntype="array" output="false">
    <cfargument name="items" type="array" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfargument name="timezone" type="string" required="true">
    <cfscript>
      var qEvents = queryExecute("
        SELECT id, event_status, occurred_at_utc, source, payload_json
        FROM floatplan_events
        WHERE floatplan_id = :floatPlanId
          AND user_id = :userId
          AND event_type = 'CHECKIN_RECEIVED'
          AND source = 'active_cruise_checkin'
          AND voided_at_utc IS NULL
        ORDER BY occurred_at_utc DESC, id DESC
        LIMIT 10
      ", {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      }, { datasource = variables.datasource });
      var i = 0;
      var statusCode = "";
      var payload = {};
      var location = {};
      var hasGps = false;

      for (i = 1; i LTE qEvents.recordCount; i++) {
        statusCode = normalizeStatusCode(qEvents.event_status[i]);
        payload = parseJsonStruct(qEvents.payload_json[i]);
        location = (structKeyExists(payload, "location") AND isStruct(payload.location) ? payload.location : {});
        hasGps = (
          structKeyExists(location, "latitude")
          AND structKeyExists(location, "longitude")
          AND isNumericValue(location.latitude)
          AND isNumericValue(location.longitude)
        );
        arrayAppend(arguments.items, buildAuditItem(
          "canonical-" & qEvents.id[i],
          qEvents.occurred_at_utc[i],
          arguments.timezone,
          "CANONICAL_EVENT_CREATED",
          "Canonical float plan event created",
          "CHECKIN_RECEIVED / " & labelizeStatus(statusCode) & ".",
          "system",
          "floatplan_events",
          0,
          safeNumber(qEvents.id[i]),
          0,
          true
        ));
        if (hasGps) {
          arrayAppend(arguments.items, buildAuditItem(
            "active-cruise-gps-" & qEvents.id[i],
            firstDate(qEvents.occurred_at_utc[i], parseStoredUtcDate(structKeyExists(location, "capturedAtUtc") ? location.capturedAtUtc : "")),
            arguments.timezone,
            "GPS_CAPTURED",
            "GPS captured with check-in",
            "GPS coordinates were stored from Active Cruise" & (structKeyExists(location, "accuracyMeters") AND len(buildAccuracyLabel(location.accuracyMeters)) ? " with " & buildAccuracyLabel(location.accuracyMeters) & " accuracy." : "."),
            "info",
            "floatplan_events",
            0,
            safeNumber(qEvents.id[i]),
            0,
            false
          ));
        }
      }
      return arguments.items;
    </cfscript>
  </cffunction>

  <cffunction name="buildMapData" access="private" returntype="struct" output="false">
    <cfargument name="routeInstanceId" type="numeric" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var service = createRouteMapGeometryService();
      if (arguments.routeInstanceId LTE 0) {
        return {};
      }
      return service.buildRouteMapData(arguments.routeInstanceId, arguments.userId, 0);
    </cfscript>
  </cffunction>

  <cffunction name="buildIdentitySection" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="qPlan" type="query" required="true">
    <cfargument name="context" type="struct" required="true">
    <cfargument name="routeMap" type="struct" required="true">
    <cfscript>
      var fromName = readStructString(arguments.routeMap, "active_leg_start_name");
      var toName = readStructString(arguments.routeMap, "active_leg_end_name");
      var routeName = firstString(valueAt(arguments.qPlan, "template_route_name"), valueAt(arguments.qPlan, "generated_route_code"), valueAt(arguments.qPlan, "floatPlanName"));
      return {
        "userId" = arguments.userId,
        "floatPlanId" = safeNumber(valueAt(arguments.qPlan, "floatPlanId")),
        "routeId" = safeNumber(valueAt(arguments.qPlan, "route_id")),
        "routeInstanceId" = safeNumber(valueAt(arguments.qPlan, "route_instance_id")),
        "vesselName" = firstString(valueAt(arguments.qPlan, "vesselName"), "Vessel"),
        "routeName" = routeName,
        "departureName" = firstString(valueAt(arguments.qPlan, "departing"), valueAt(arguments.qPlan, "start_location")),
        "destinationName" = firstString(valueAt(arguments.qPlan, "returning"), valueAt(arguments.qPlan, "end_location")),
        "currentLegOrder" = readStructNumber(arguments.routeMap, "active_leg_order"),
        "totalLegs" = safeNumber(valueAt(arguments.qPlan, "total_legs")),
        "currentLegLabel" = (len(fromName) AND len(toName) ? fromName & " to " & toName : "")
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildTripStateSection" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfargument name="routeMap" type="struct" required="true">
    <cfscript>
      var floatPlanStatus = normalizeStatusCode(valueAt(arguments.qPlan, "status"));
      var routeStatus = normalizeStatusCode(valueAt(arguments.qPlan, "route_status"));
      var currentLegStatus = loadCurrentLegStatus(
        safeNumber(valueAt(arguments.qPlan, "route_instance_id")),
        safeNumber(valueAt(arguments.qPlan, "userId")),
        readStructNumber(arguments.routeMap, "active_leg_order")
      );
      var code = "UNDERWAY";

      if (len(valueAt(arguments.qPlan, "closedAt")) OR routeStatus EQ "COMPLETED" OR floatPlanStatus EQ "CLOSED") {
        code = "COMPLETED_OR_CLOSED";
      } else if (floatPlanStatus EQ "ACTIVE") {
        code = "UNDERWAY";
      } else {
        code = floatPlanStatus;
      }

      return {
        "code" = code,
        "label" = labelizeStatus(code),
        "helperText" = buildTripHelperText(code),
        "motionState" = lCase(code),
        "safetyState" = "",
        "floatPlanStatus" = floatPlanStatus,
        "routeInstanceStatus" = routeStatus,
        "currentLegStatus" = currentLegStatus
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildMonitoringSection" access="private" returntype="struct" output="false">
    <cfargument name="qMonitoring" type="query" required="true">
    <cfargument name="qPlan" type="query" required="true">
    <cfargument name="timezone" type="string" required="true">
    <cfscript>
      var row = arguments.qMonitoring;
      var stateCode = normalizeStatusCode(row.monitor_state[1]);
      var modeCode = normalizeStatusCode(row.monitoring_mode[1]);
      var manualDelay = safeNumber(valueAt(arguments.qPlan, "manual_delay_minutes_total"));
      var out = buildDefaultMonitoring();

      out.hasMonitoringRow = true;
      out.monitoringRowId = safeNumber(row.id[1]);
      out.state = stateCode;
      out.stateLabel = labelizeStatus(stateCode);
      out.mode = modeCode;
      out.modeLabel = labelizeStatus(modeCode);
      out.captainHealthLabel = buildCaptainHealthLabel(stateCode);
      out.captainHealthVariant = buildCaptainHealthVariant(stateCode);
      out.lastCheckinStatus = normalizeStatusCode(row.last_checkin_status[1]);
      out.lastCheckinStatusLabel = labelizeStatus(out.lastCheckinStatus);
      out.lastCheckinAtUtc = formatUtc(row.last_checkin_at[1]);
      out.lastCheckinLocalLabel = formatLocalLabel(row.last_checkin_at[1], arguments.timezone);
      out.expectedCheckinAtUtc = formatUtc(row.expected_checkin_at[1]);
      out.expectedCheckinLocalLabel = formatLocalLabel(row.expected_checkin_at[1], arguments.timezone);
      out.graceUntilUtc = formatUtc(row.grace_expires_at[1]);
      out.graceUntilLocalLabel = formatLocalLabel(row.grace_expires_at[1], arguments.timezone);
      out.missedAtUtc = formatUtc(row.missed_at[1]);
      out.missedAtLocalLabel = formatLocalLabel(row.missed_at[1], arguments.timezone);
      out.escalatedAtUtc = formatUtc(row.escalated_at[1]);
      out.escalatedAtLocalLabel = formatLocalLabel(row.escalated_at[1], arguments.timezone);
      out.nextMonitorEvalAtUtc = formatUtc(row.next_monitor_eval_at[1]);
      out.nextMonitorEvalLocalLabel = formatLocalLabel(row.next_monitor_eval_at[1], arguments.timezone);
      out.secureForNight = (safeNumber(row.secure_for_night[1]) EQ 1);
      out.secureUntilUtc = formatUtc(row.secure_for_night_until[1]);
      out.secureUntilLocalLabel = formatLocalLabel(row.secure_for_night_until[1], arguments.timezone);
      out.manualDelayMinutesTotal = manualDelay;
      out.manualDelayLabel = buildManualDelayLabel(manualDelay);
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="buildLastCheckinLocation" access="private" returntype="struct" output="false">
    <cfargument name="latestGps" type="struct" required="true">
    <cfargument name="timezone" type="string" required="true">
    <cfargument name="nowUtc" type="any" required="true">
    <cfscript>
      var out = buildDefaultLastCheckinLocation();
      var capturedAt = "";
      var receivedAt = "";
      var ageMinutes = 0;
      var statusCode = "";

      if (
        !isStruct(arguments.latestGps)
        OR !structKeyExists(arguments.latestGps, "hasGps")
        OR !arguments.latestGps.hasGps
      ) {
        return out;
      }

      capturedAt = parseStoredUtcDate(safeString(arguments.latestGps.capturedAtUtc));
      receivedAt = parseStoredUtcDate(safeString(arguments.latestGps.receivedAtUtc));
      statusCode = normalizeStatusCode(arguments.latestGps.statusCode);
      out.hasLocation = true;
      out.latitude = safeNumber(arguments.latestGps.latitude);
      out.longitude = safeNumber(arguments.latestGps.longitude);
      out.accuracyMeters = (structKeyExists(arguments.latestGps, "accuracyMeters") AND !isNull(arguments.latestGps.accuracyMeters) AND isNumericValue(arguments.latestGps.accuracyMeters) ? safeNumber(arguments.latestGps.accuracyMeters) : nullValue());
      out.accuracyLabel = buildAccuracyLabel(out.accuracyMeters);
      out.accuracyQualityLabel = buildAccuracyQualityLabel(out.accuracyMeters);
      out.altitudeMeters = (structKeyExists(arguments.latestGps, "altitudeMeters") AND !isNull(arguments.latestGps.altitudeMeters) AND isNumericValue(arguments.latestGps.altitudeMeters) ? safeNumber(arguments.latestGps.altitudeMeters) : nullValue());
      out.speedKnots = (structKeyExists(arguments.latestGps, "speedKnots") AND !isNull(arguments.latestGps.speedKnots) AND isNumericValue(arguments.latestGps.speedKnots) ? safeNumber(arguments.latestGps.speedKnots) : nullValue());
      out.headingDegrees = (structKeyExists(arguments.latestGps, "headingDegrees") AND !isNull(arguments.latestGps.headingDegrees) AND isNumericValue(arguments.latestGps.headingDegrees) ? safeNumber(arguments.latestGps.headingDegrees) : nullValue());
      out.capturedAtUtc = formatUtc(capturedAt);
      out.capturedAtLocalLabel = formatLocalLabel(capturedAt, arguments.timezone);
      out.receivedAtUtc = formatUtc(receivedAt);
      out.receivedAtLocalLabel = formatLocalLabel(receivedAt, arguments.timezone);
      out.sourceCode = safeString(arguments.latestGps.sourceCode);
      out.sourceLabel = safeString(arguments.latestGps.sourceLabel);
      out.statusCode = statusCode;
      out.statusLabel = labelizeStatus(statusCode);
      out.notePreview = safeString(arguments.latestGps.notePreview);
      out.companionEventId = safeNumber(arguments.latestGps.companionEventId);
      out.canonicalEventId = safeNumber(arguments.latestGps.canonicalEventId);
      if (isDate(capturedAt) AND isDate(arguments.nowUtc)) {
        ageMinutes = max(0, dateDiff("n", capturedAt, arguments.nowUtc));
        out.ageMinutes = ageMinutes;
        out.ageLabel = buildAgeLabel(ageMinutes);
        if (ageMinutes GT 360) {
          out.isStale = true;
          out.staleReason = "Last GPS check-in was captured more than 6 hours ago.";
        }
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="buildMapSection" access="private" returntype="struct" output="false">
    <cfargument name="routeMap" type="struct" required="true">
    <cfargument name="lastLocation" type="struct" required="true">
    <cfscript>
      var out = buildDefaultMap();
      var routeGeo = {};
      var pins = [];
      var fromName = readStructString(arguments.routeMap, "active_leg_start_name");
      var toName = readStructString(arguments.routeMap, "active_leg_end_name");

      if (structKeyExists(arguments.routeMap, "route_geo") AND isStruct(arguments.routeMap.route_geo)) {
        routeGeo = duplicate(arguments.routeMap.route_geo);
      }
      if (structKeyExists(arguments.routeMap, "pins") AND isArray(arguments.routeMap.pins)) {
        pins = duplicate(arguments.routeMap.pins);
      }

      out.routeGeo = (structCount(routeGeo) ? routeGeo : out.routeGeo);
      out.pins = pins;
      out.hasRouteGeometry = hasRouteGeometry(out.routeGeo);
      out.currentLeg = {
        "order" = readStructNumber(arguments.routeMap, "active_leg_order"),
        "fromName" = fromName,
        "toName" = toName,
        "label" = (len(fromName) AND len(toName) ? fromName & " to " & toName : "")
      };

      if (arguments.lastLocation.hasLocation) {
        out.lastCheckinMarker = {
          "latitude" = arguments.lastLocation.latitude,
          "longitude" = arguments.lastLocation.longitude,
          "label" = "Last Check-In Location",
          "statusLabel" = arguments.lastLocation.statusLabel,
          "capturedAtLocalLabel" = arguments.lastLocation.capturedAtLocalLabel,
          "sourceLabel" = arguments.lastLocation.sourceLabel
        };
        out.mapCenter = {
          "latitude" = arguments.lastLocation.latitude,
          "longitude" = arguments.lastLocation.longitude
        };
        if (!isNull(arguments.lastLocation.accuracyMeters) AND isNumericValue(arguments.lastLocation.accuracyMeters)) {
          out.accuracyCircle = {
            "latitude" = arguments.lastLocation.latitude,
            "longitude" = arguments.lastLocation.longitude,
            "radiusMeters" = arguments.lastLocation.accuracyMeters,
            "label" = arguments.lastLocation.accuracyLabel
          };
        }
      }

      if (!out.hasRouteGeometry AND !arguments.lastLocation.hasLocation) {
        out.noMapReason = "No route geometry or GPS check-in location is available.";
      } else if (!out.hasRouteGeometry) {
        out.noMapReason = "Route geometry is not available; showing the last check-in marker only.";
      } else if (!arguments.lastLocation.hasLocation) {
        out.noMapReason = "Route geometry is available; no GPS check-in marker is available yet.";
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="buildTechnicalSnapshot" access="private" returntype="struct" output="false">
    <cfargument name="dto" type="struct" required="true">
    <cfargument name="latestGps" type="struct" required="true">
    <cfscript>
      var out = duplicate(arguments.dto.technicalSnapshot);
      out.monitoringRowId = arguments.dto.monitoring.monitoringRowId;
      out.monitoringState = arguments.dto.monitoring.state;
      out.monitoringMode = arguments.dto.monitoring.mode;
      out.companionEventId = arguments.dto.lastCheckinLocation.companionEventId;
      out.canonicalEventId = arguments.dto.lastCheckinLocation.canonicalEventId;
      if (isStruct(arguments.latestGps) AND structKeyExists(arguments.latestGps, "hasGps") AND arguments.latestGps.hasGps) {
        out.mobileSubmissionId = (structKeyExists(arguments.latestGps, "mobileSubmissionId") ? safeString(arguments.latestGps.mobileSubmissionId) : "");
        out.processedStatus = (structKeyExists(arguments.latestGps, "processedStatus") ? safeString(arguments.latestGps.processedStatus) : "");
        out.locationCapturedAtUtc = arguments.dto.lastCheckinLocation.capturedAtUtc;
      }
      out.duplicateReplay = false;
      out.expectedCheckinAtUtc = arguments.dto.monitoring.expectedCheckinAtUtc;
      out.nextMonitorEvalAtUtc = arguments.dto.monitoring.nextMonitorEvalAtUtc;
      out.generatedAtUtc = arguments.dto.generatedAtUtc;
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="buildSafetyCopy" access="private" returntype="struct" output="false">
    <cfargument name="lastLocation" type="struct" required="true">
    <cfscript>
      return {
        "notLiveTrackingMessage" = "FPW shows the last check-in location shared by the captain.",
        "emergencyDisclaimer" = "This is not live vessel tracking and may not reflect the vessel's current position. In an emergency, use official emergency channels such as VHF Channel 16, DSC distress, 911, EPIRB/PLB, flares, or other accepted emergency methods.",
        "gpsStaleMessage" = (structKeyExists(arguments.lastLocation, "isStale") AND arguments.lastLocation.isStale ? "The latest GPS check-in may be stale. Use the captured time when interpreting the marker." : ""),
        "noGpsMessage" = "No GPS has been captured with a check-in for this monitored trip yet.",
        "poorAccuracyMessage" = (structKeyExists(arguments.lastLocation, "accuracyQualityLabel") AND arguments.lastLocation.accuracyQualityLabel EQ "Poor" ? "The latest GPS check-in reported poor accuracy. Treat the marker as approximate." : "")
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildAuditItem" access="private" returntype="struct" output="false">
    <cfargument name="id" type="string" required="true">
    <cfargument name="occurredAt" type="any" required="true">
    <cfargument name="timezone" type="string" required="true">
    <cfargument name="type" type="string" required="true">
    <cfargument name="title" type="string" required="true">
    <cfargument name="detail" type="string" required="true">
    <cfargument name="tone" type="string" required="true">
    <cfargument name="source" type="string" required="true">
    <cfargument name="relatedCompanionEventId" type="numeric" required="false" default="0">
    <cfargument name="relatedCanonicalEventId" type="numeric" required="false" default="0">
    <cfargument name="relatedMonitorEventId" type="numeric" required="false" default="0">
    <cfargument name="isTechnical" type="boolean" required="false" default="false">
    <cfscript>
      return {
        "id" = arguments.id,
        "occurredAtUtc" = formatUtc(arguments.occurredAt),
        "occurredAtLocalLabel" = formatLocalLabel(arguments.occurredAt, arguments.timezone),
        "type" = arguments.type,
        "title" = arguments.title,
        "detail" = arguments.detail,
        "tone" = arguments.tone,
        "source" = arguments.source,
        "relatedCompanionEventId" = arguments.relatedCompanionEventId,
        "relatedCanonicalEventId" = arguments.relatedCanonicalEventId,
        "relatedMonitorEventId" = arguments.relatedMonitorEventId,
        "isTechnical" = arguments.isTechnical,
        "safeForCaptainDisplay" = true
      };
    </cfscript>
  </cffunction>

  <cffunction name="mapMonitorAuditEvent" access="private" returntype="struct" output="false">
    <cfargument name="eventType" type="string" required="true">
    <cfargument name="fromState" type="string" required="false" default="">
    <cfargument name="toState" type="string" required="false" default="">
    <cfargument name="checkinStatus" type="string" required="false" default="">
    <cfscript>
      var eventTypeVal = normalizeStatusCode(arguments.eventType);
      var statusVal = normalizeStatusCode(arguments.checkinStatus);
      var toStateVal = normalizeStatusCode(arguments.toState);
      var out = {
        "supported" = true,
        "type" = "MONITORING_STATE_UPDATED",
        "title" = "Monitoring state updated",
        "detail" = "Monitoring state was updated.",
        "tone" = "info"
      };

      if (eventTypeVal EQ "SECURE_FOR_NIGHT_SET") {
        out.type = "SECURE_FOR_NIGHT_APPLIED";
        out.title = "Secure for night applied";
        out.detail = "The next expected check-in was updated for secure-for-night handling.";
        out.tone = "success";
      } else if (eventTypeVal EQ "CAPTAIN_ALERTED") {
        out.type = "OWNER_ALERT_SENT";
        out.title = "Owner alert sent";
        out.detail = "The owner alert path was invoked for the missed check-in state.";
        out.tone = "warning";
      } else if (eventTypeVal EQ "CONTACT_ALERTED") {
        out.type = "CONTACT_ALERT_SENT";
        out.title = "Contact alert sent";
        out.detail = "The contact alert path was invoked for the escalated monitoring state.";
        out.tone = "warning";
      } else if (eventTypeVal EQ "STATE_CHANGED" AND toStateVal EQ "ESCALATED") {
        out.type = "MONITORING_ESCALATED";
        out.title = "Monitoring escalated";
        out.detail = "Monitoring state changed to escalated.";
        out.tone = "danger";
      } else if (eventTypeVal EQ "CHECKIN_RECEIVED" AND statusVal EQ "DELAYED") {
        out.type = "DELAY_APPLIED";
        out.title = "Delay applied";
        out.detail = "A delayed check-in was processed.";
        out.tone = "warning";
      } else if (eventTypeVal EQ "CHECKIN_RECEIVED" AND statusVal EQ "CHANGED_PLAN") {
        out.type = "CHANGED_PLAN_RECEIVED";
        out.title = "Changed plan received";
        out.detail = "A changed-plan check-in was processed.";
        out.tone = "warning";
      } else if (eventTypeVal EQ "CHECKIN_RECEIVED") {
        out.title = "Monitoring check-in processed";
        out.detail = (len(statusVal) ? labelizeStatus(statusVal) & " check-in processed by monitoring." : "Captain check-in processed by monitoring.");
        out.tone = "success";
      } else if (eventTypeVal EQ "STATE_CHANGED") {
        out.detail = "Monitoring state changed from " & labelizeStatus(arguments.fromState) & " to " & labelizeStatus(arguments.toState) & ".";
      } else {
        out.supported = false;
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="setEmptyState" access="private" returntype="void" output="false">
    <cfargument name="dto" type="struct" required="true">
    <cfargument name="code" type="string" required="true">
    <cfscript>
      arguments.dto.emptyState = buildEmptyState(arguments.code);
    </cfscript>
  </cffunction>

  <cffunction name="buildEmptyState" access="private" returntype="struct" output="false">
    <cfargument name="code" type="string" required="true">
    <cfscript>
      var codeVal = normalizeStatusCode(arguments.code);
      var out = {
        "code" = codeVal,
        "title" = "",
        "message" = "",
        "actionLabel" = "",
        "actionHref" = "",
        "safeForDisplay" = true
      };

      switch (codeVal) {
        case "UNAUTHENTICATED":
          out.title = "Sign in required";
          out.message = "Sign in to view the Monitoring Console.";
          break;
        case "NO_ACTIVE_FLOAT_PLAN":
          out.title = "No active monitored trip";
          out.message = "There is no active route-backed float plan available for the Monitoring Console.";
          break;
        case "NO_ACTIVE_ROUTE":
          out.title = "No active route";
          out.message = "The active float plan is not linked to an active route.";
          break;
        case "MONITORING_ROW_MISSING":
          out.title = "Monitoring is not initialized";
          out.message = "This route-backed float plan does not have a monitoring row yet.";
          break;
        case "NO_GPS_CHECKIN":
          out.title = "No GPS check-in yet";
          out.message = "No GPS has been captured with a check-in for this monitored trip yet.";
          break;
        case "COMPLETED_OR_CLOSED":
          out.title = "Trip monitoring is closed";
          out.message = "This float plan or monitoring record is completed or closed.";
          break;
        case "MULTIPLE_ACTIVE_GROUPS":
          out.title = "Multiple active trips found";
          out.message = "Resolve the extra active route-backed float plan before using the Monitoring Console.";
          break;
        case "SERVICE_UNAVAILABLE":
          out.title = "Monitoring Console unavailable";
          out.message = "The Monitoring Console data could not be prepared safely.";
          break;
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="addWarning" access="private" returntype="void" output="false">
    <cfargument name="dto" type="struct" required="true">
    <cfargument name="code" type="string" required="true">
    <cfargument name="label" type="string" required="true">
    <cfargument name="detail" type="string" required="true">
    <cfargument name="severity" type="string" required="false" default="info">
    <cfscript>
      arrayAppend(arguments.dto.warnings, {
        "code" = normalizeStatusCode(arguments.code),
        "label" = arguments.label,
        "detail" = arguments.detail,
        "severity" = lCase(arguments.severity),
        "safeForDisplay" = true
      });
    </cfscript>
  </cffunction>

  <cffunction name="createApiComponent" access="private" returntype="any" output="false">
    <cfargument name="name" type="string" required="true">
    <cfscript>
      try {
        return createObject("component", "fpw.api.v1." & arguments.name);
      } catch (any primaryPathErr) {
        return createObject("component", "api.v1." & arguments.name);
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

  <cffunction name="loadCurrentLegStatus" access="private" returntype="string" output="false">
    <cfargument name="routeInstanceId" type="numeric" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="legOrder" type="numeric" required="true">
    <cfscript>
      var qStatus = queryNew("");
      if (arguments.routeInstanceId LTE 0 OR arguments.userId LTE 0 OR arguments.legOrder LTE 0) {
        return "";
      }
      qStatus = queryExecute("
        SELECT UPPER(TRIM(COALESCE(status, ''))) AS status_value
        FROM route_instance_leg_progress
        WHERE route_instance_id = :routeInstanceId
          AND user_id = :userId
          AND leg_order = :legOrder
        ORDER BY id DESC
        LIMIT 1
      ", {
        routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" },
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        legOrder = { value = arguments.legOrder, cfsqltype = "cf_sql_integer" }
      }, { datasource = variables.datasource });
      if (qStatus.recordCount EQ 0) {
        return "";
      }
      return safeString(qStatus.status_value[1]);
    </cfscript>
  </cffunction>

  <cffunction name="getCurrentUtcTimestamp" access="private" returntype="any" output="false">
    <cfscript>
      var qNow = queryExecute("SELECT UTC_TIMESTAMP() AS utc_now", {}, { datasource = variables.datasource });
      if (qNow.recordCount AND isDate(qNow.utc_now[1])) {
        return qNow.utc_now[1];
      }
      return now();
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

  <cffunction name="formatLocalLabel" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="true">
    <cfargument name="timezone" type="string" required="false" default="UTC">
    <cfscript>
      var tz = len(trim(arguments.timezone)) ? trim(arguments.timezone) : "UTC";
      if (!isDate(arguments.value)) {
        return "";
      }
      try {
        return dateTimeFormat(arguments.value, "mmm d, yyyy h:nn tt", tz);
      } catch (any localLabelErr) {
        return dateTimeFormat(arguments.value, "mmm d, yyyy h:nn tt");
      }
    </cfscript>
  </cffunction>

  <cffunction name="resolveTimezone" access="private" returntype="string" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfscript>
      return firstString(
        valueAt(arguments.qPlan, "departureTZ"),
        valueAt(arguments.qPlan, "departTimezone"),
        valueAt(arguments.qPlan, "returnTZ"),
        valueAt(arguments.qPlan, "returnTimezone"),
        valueAt(arguments.qPlan, "vessel_timezone"),
        "UTC"
      );
    </cfscript>
  </cffunction>

  <cffunction name="buildAccuracyLabel" access="private" returntype="string" output="false">
    <cfargument name="accuracyMeters" type="any" required="true">
    <cfscript>
      if (!isNumericValue(arguments.accuracyMeters)) {
        return "";
      }
      return "+/- " & numberFormat(val(arguments.accuracyMeters), "0") & " meters";
    </cfscript>
  </cffunction>

  <cffunction name="buildAccuracyQualityLabel" access="private" returntype="string" output="false">
    <cfargument name="accuracyMeters" type="any" required="true">
    <cfscript>
      if (!isNumericValue(arguments.accuracyMeters)) {
        return "Unknown";
      }
      if (val(arguments.accuracyMeters) LTE 25) {
        return "Good";
      }
      if (val(arguments.accuracyMeters) LTE 100) {
        return "Fair";
      }
      return "Poor";
    </cfscript>
  </cffunction>

  <cffunction name="buildAgeLabel" access="private" returntype="string" output="false">
    <cfargument name="ageMinutes" type="numeric" required="true">
    <cfscript>
      if (arguments.ageMinutes LT 60) {
        return numberFormat(arguments.ageMinutes, "0") & " minutes ago";
      }
      return numberFormat(arguments.ageMinutes / 60, "0.0") & " hours ago";
    </cfscript>
  </cffunction>

  <cffunction name="buildManualDelayLabel" access="private" returntype="string" output="false">
    <cfargument name="minutes" type="numeric" required="true">
    <cfscript>
      if (arguments.minutes EQ 0) {
        return "";
      }
      return numberFormat(arguments.minutes, "0") & " minutes";
    </cfscript>
  </cffunction>

  <cffunction name="buildCaptainHealthLabel" access="private" returntype="string" output="false">
    <cfargument name="state" type="string" required="true">
    <cfscript>
      switch (normalizeStatusCode(arguments.state)) {
        case "ACTIVE": return "All Good";
        case "LATE": return "Late";
        case "MISSED": return "Missed";
        case "ESCALATED": return "Escalated";
        case "CLOSED": return "Closed";
      }
      return labelizeStatus(arguments.state);
    </cfscript>
  </cffunction>

  <cffunction name="buildCaptainHealthVariant" access="private" returntype="string" output="false">
    <cfargument name="state" type="string" required="true">
    <cfscript>
      switch (normalizeStatusCode(arguments.state)) {
        case "ACTIVE": return "success";
        case "LATE": return "warning";
        case "MISSED": return "danger";
        case "ESCALATED": return "danger";
        case "CLOSED": return "muted";
      }
      return "info";
    </cfscript>
  </cffunction>

  <cffunction name="buildRowTone" access="private" returntype="string" output="false">
    <cfargument name="statusCode" type="string" required="true">
    <cfargument name="hasGps" type="boolean" required="true">
    <cfscript>
      if (!arguments.hasGps) {
        return "muted";
      }
      if (normalizeStatusCode(arguments.statusCode) EQ "NEED_ATTENTION") {
        return "warning";
      }
      return "neutral";
    </cfscript>
  </cffunction>

  <cffunction name="buildTripHelperText" access="private" returntype="string" output="false">
    <cfargument name="code" type="string" required="true">
    <cfscript>
      switch (normalizeStatusCode(arguments.code)) {
        case "UNDERWAY": return "The route-backed float plan is underway.";
        case "COMPLETED_OR_CLOSED": return "The route-backed float plan is completed or closed.";
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="labelizeStatus" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      var raw = trim(safeString(arguments.value));
      var parts = [];
      var labels = [];
      var i = 0;
      if (!len(raw)) {
        return "";
      }
      raw = replace(raw, "_", " ", "all");
      raw = lCase(raw);
      parts = listToArray(raw, " ");
      for (i = 1; i LTE arrayLen(parts); i++) {
        if (len(parts[i])) {
          arrayAppend(labels, uCase(left(parts[i], 1)) & mid(parts[i], 2, len(parts[i])));
        }
      }
      return arrayToList(labels, " ");
    </cfscript>
  </cffunction>

  <cffunction name="normalizeStatusCode" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      return uCase(reReplace(trim(safeString(arguments.value)), "[^A-Za-z0-9]+", "_", "all"));
    </cfscript>
  </cffunction>

  <cffunction name="firstString" access="private" returntype="string" output="false">
    <cfargument name="a" type="any" required="false" default="">
    <cfargument name="b" type="any" required="false" default="">
    <cfargument name="c" type="any" required="false" default="">
    <cfargument name="d" type="any" required="false" default="">
    <cfargument name="e" type="any" required="false" default="">
    <cfargument name="f" type="any" required="false" default="">
    <cfscript>
      var values = [arguments.a, arguments.b, arguments.c, arguments.d, arguments.e, arguments.f];
      var i = 0;
      var value = "";
      for (i = 1; i LTE arrayLen(values); i++) {
        value = safeString(values[i]);
        if (len(value)) {
          return value;
        }
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="firstDate" access="private" returntype="any" output="false">
    <cfargument name="a" type="any" required="false" default="">
    <cfargument name="b" type="any" required="false" default="">
    <cfargument name="c" type="any" required="false" default="">
    <cfscript>
      if (isDate(arguments.a)) {
        return arguments.a;
      }
      if (isDate(arguments.b)) {
        return arguments.b;
      }
      if (isDate(arguments.c)) {
        return arguments.c;
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="parseStoredUtcDate" access="private" returntype="any" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      var raw = safeString(arguments.value);
      var normalized = "";
      if (isDate(arguments.value)) {
        return arguments.value;
      }
      if (!len(raw)) {
        return "";
      }
      normalized = replace(raw, "T", " ", "one");
      normalized = reReplace(normalized, "Z$", "", "one");
      normalized = reReplace(normalized, "\.\d+", "", "one");
      normalized = reReplace(normalized, "([+-]\d{2}:\d{2})$", "", "one");
      if (!isDate(normalized)) {
        return "";
      }
      return parseDateTime(normalized);
    </cfscript>
  </cffunction>

  <cffunction name="parseJsonStruct" access="private" returntype="struct" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      var raw = safeString(arguments.value);
      var parsed = {};
      if (!len(raw)) {
        return {};
      }
      try {
        parsed = deserializeJSON(raw);
      } catch (any parseErr) {
        return {};
      }
      return isStruct(parsed) ? parsed : {};
    </cfscript>
  </cffunction>

  <cffunction name="valueAt" access="private" returntype="any" output="false">
    <cfargument name="q" type="query" required="true">
    <cfargument name="column" type="string" required="true">
    <cfargument name="row" type="numeric" required="false" default="1">
    <cfargument name="defaultValue" type="any" required="false" default="">
    <cfscript>
      if (
        arguments.q.recordCount GTE arguments.row
        AND listFindNoCase(arguments.q.columnList, arguments.column)
        AND !isNull(arguments.q[arguments.column][arguments.row])
      ) {
        return arguments.q[arguments.column][arguments.row];
      }
      return arguments.defaultValue;
    </cfscript>
  </cffunction>

  <cffunction name="readStructString" access="private" returntype="string" output="false">
    <cfargument name="source" type="struct" required="true">
    <cfargument name="key" type="string" required="true">
    <cfscript>
      if (structKeyExists(arguments.source, arguments.key) AND !isNull(arguments.source[arguments.key])) {
        return safeString(arguments.source[arguments.key]);
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="readStructNumber" access="private" returntype="numeric" output="false">
    <cfargument name="source" type="struct" required="true">
    <cfargument name="key" type="string" required="true">
    <cfscript>
      if (structKeyExists(arguments.source, arguments.key) AND isNumericValue(arguments.source[arguments.key])) {
        return val(arguments.source[arguments.key]);
      }
      return 0;
    </cfscript>
  </cffunction>

  <cffunction name="safeString" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      if (isNull(arguments.value)) {
        return "";
      }
      if (isSimpleValue(arguments.value)) {
        return trim(toString(arguments.value));
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="safeNumber" access="private" returntype="numeric" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      if (isNumericValue(arguments.value)) {
        return val(arguments.value);
      }
      return 0;
    </cfscript>
  </cffunction>

  <cffunction name="isNumericValue" access="private" returntype="boolean" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      return (!isNull(arguments.value) AND isSimpleValue(arguments.value) AND len(trim(toString(arguments.value))) AND isNumeric(arguments.value));
    </cfscript>
  </cffunction>

  <cffunction name="nullValue" access="private" returntype="any" output="false">
    <cfscript>
      return javacast("null", "");
    </cfscript>
  </cffunction>

  <cffunction name="hasRouteGeometry" access="private" returntype="boolean" output="false">
    <cfargument name="routeGeo" type="struct" required="true">
    <cfscript>
      return (
        structKeyExists(arguments.routeGeo, "coordinates")
        AND isArray(arguments.routeGeo.coordinates)
        AND arrayLen(arguments.routeGeo.coordinates) GT 0
      );
    </cfscript>
  </cffunction>

  <cffunction name="sortAuditItemsDesc" access="private" returntype="void" output="false">
    <cfargument name="items" type="array" required="true">
    <cfscript>
      var i = 0;
      var j = 0;
      var tmp = {};
      for (i = 1; i LTE arrayLen(arguments.items); i++) {
        for (j = i + 1; j LTE arrayLen(arguments.items); j++) {
          if (safeString(arguments.items[j].occurredAtUtc) GT safeString(arguments.items[i].occurredAtUtc)) {
            tmp = arguments.items[i];
            arguments.items[i] = arguments.items[j];
            arguments.items[j] = tmp;
          }
        }
      }
    </cfscript>
  </cffunction>

  <cffunction name="sortGpsHistoryItemsDesc" access="private" returntype="void" output="false">
    <cfargument name="items" type="array" required="true">
    <cfscript>
      var i = 0;
      var j = 0;
      var tmp = {};
      for (i = 1; i LTE arrayLen(arguments.items); i++) {
        for (j = i + 1; j LTE arrayLen(arguments.items); j++) {
          if (safeString(arguments.items[j].checkinAtUtc) GT safeString(arguments.items[i].checkinAtUtc)) {
            tmp = arguments.items[i];
            arguments.items[i] = arguments.items[j];
            arguments.items[j] = tmp;
          }
        }
      }
    </cfscript>
  </cffunction>

  <cffunction name="limitArray" access="private" returntype="array" output="false">
    <cfargument name="items" type="array" required="true">
    <cfargument name="limit" type="numeric" required="true">
    <cfscript>
      var out = [];
      var i = 0;
      for (i = 1; i LTE min(arrayLen(arguments.items), arguments.limit); i++) {
        arrayAppend(out, arguments.items[i]);
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="scanForbiddenKeys" access="private" returntype="void" output="false">
    <cfargument name="value" type="any" required="true">
    <cfargument name="path" type="string" required="true">
    <cfargument name="findings" type="array" required="true">
    <cfscript>
      var forbidden = [
        "contact", "contacts", "passenger", "passengers", "recipient", "recipients",
        "email", "phone", "token", "bearer", "authorization", "password", "secret",
        "requestpayload", "rawpayload", "payloadjson", "meta_json", "metajson",
        "sql", "stacktrace", "debugdump"
      ];
      var keys = [];
      var i = 0;
      var key = "";
      var normalizedKey = "";
      var childPath = "";

      if (isStruct(arguments.value)) {
        keys = structKeyArray(arguments.value);
        for (i = 1; i LTE arrayLen(keys); i++) {
          key = keys[i];
          normalizedKey = lCase(reReplace(key, "[^A-Za-z0-9_]+", "", "all"));
          childPath = len(arguments.path) ? arguments.path & "." & key : key;
          if (arrayFindNoCase(forbidden, normalizedKey)) {
            arrayAppend(arguments.findings, childPath);
          }
          if (!isNull(arguments.value[key])) {
            scanForbiddenKeys(arguments.value[key], childPath, arguments.findings);
          }
        }
      } else if (isArray(arguments.value)) {
        for (i = 1; i LTE arrayLen(arguments.value); i++) {
          if (!isNull(arguments.value[i])) {
            scanForbiddenKeys(arguments.value[i], arguments.path & "[" & i & "]", arguments.findings);
          }
        }
      }
    </cfscript>
  </cffunction>

  <cffunction name="buildDefaultIdentity" access="private" returntype="struct" output="false">
    <cfscript>
      return {
        "userId" = 0,
        "floatPlanId" = 0,
        "routeId" = 0,
        "routeInstanceId" = 0,
        "vesselName" = "",
        "routeName" = "",
        "departureName" = "",
        "destinationName" = "",
        "currentLegOrder" = 0,
        "totalLegs" = 0,
        "currentLegLabel" = ""
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildDefaultTripState" access="private" returntype="struct" output="false">
    <cfscript>
      return {
        "code" = "",
        "label" = "",
        "helperText" = "",
        "motionState" = "",
        "safetyState" = "",
        "floatPlanStatus" = "",
        "routeInstanceStatus" = "",
        "currentLegStatus" = ""
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildDefaultMonitoring" access="private" returntype="struct" output="false">
    <cfscript>
      return {
        "hasMonitoringRow" = false,
        "monitoringRowId" = 0,
        "state" = "",
        "stateLabel" = "",
        "mode" = "",
        "modeLabel" = "",
        "captainHealthLabel" = "",
        "captainHealthVariant" = "",
        "lastCheckinStatus" = "",
        "lastCheckinStatusLabel" = "",
        "lastCheckinAtUtc" = "",
        "lastCheckinLocalLabel" = "",
        "expectedCheckinAtUtc" = "",
        "expectedCheckinLocalLabel" = "",
        "graceUntilUtc" = "",
        "graceUntilLocalLabel" = "",
        "missedAtUtc" = "",
        "missedAtLocalLabel" = "",
        "escalatedAtUtc" = "",
        "escalatedAtLocalLabel" = "",
        "nextMonitorEvalAtUtc" = "",
        "nextMonitorEvalLocalLabel" = "",
        "secureForNight" = false,
        "secureUntilUtc" = "",
        "secureUntilLocalLabel" = "",
        "manualDelayMinutesTotal" = 0,
        "manualDelayLabel" = ""
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildDefaultLastCheckinLocation" access="private" returntype="struct" output="false">
    <cfscript>
      return {
        "hasLocation" = false,
        "latitude" = nullValue(),
        "longitude" = nullValue(),
        "accuracyMeters" = nullValue(),
        "accuracyLabel" = "",
        "accuracyQualityLabel" = "",
        "altitudeMeters" = nullValue(),
        "speedKnots" = nullValue(),
        "headingDegrees" = nullValue(),
        "capturedAtUtc" = "",
        "capturedAtLocalLabel" = "",
        "receivedAtUtc" = "",
        "receivedAtLocalLabel" = "",
        "sourceCode" = "",
        "sourceLabel" = "",
        "statusCode" = "",
        "statusLabel" = "",
        "notePreview" = "",
        "companionEventId" = 0,
        "canonicalEventId" = 0,
        "isStale" = false,
        "staleReason" = "",
        "ageMinutes" = nullValue(),
        "ageLabel" = ""
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildDefaultMap" access="private" returntype="struct" output="false">
    <cfscript>
      return {
        "hasRouteGeometry" = false,
        "routeGeo" = { "type" = "MultiLineString", "coordinates" = [] },
        "pins" = [],
        "currentLeg" = {},
        "lastCheckinMarker" = nullValue(),
        "accuracyCircle" = nullValue(),
        "mapCenter" = nullValue(),
        "bounds" = nullValue(),
        "noMapReason" = ""
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildDefaultTechnicalSnapshot" access="private" returntype="struct" output="false">
    <cfscript>
      return {
        "monitoringRowId" = 0,
        "monitoringState" = "",
        "monitoringMode" = "",
        "companionEventId" = 0,
        "canonicalEventId" = 0,
        "mobileSubmissionId" = "",
        "processedStatus" = "",
        "duplicateReplay" = false,
        "locationCapturedAtUtc" = "",
        "expectedCheckinAtUtc" = "",
        "nextMonitorEvalAtUtc" = "",
        "generatedAtUtc" = ""
      };
    </cfscript>
  </cffunction>

</cfcomponent>
