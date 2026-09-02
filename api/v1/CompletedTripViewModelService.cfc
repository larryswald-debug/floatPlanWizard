<cfcomponent output="false">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfscript>
      variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="getCompletedTripViewModel" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      var model = baseModel();
      var qPlan = queryNew("");
      var routeInstanceId = 0;
      var routeStatus = "";
      var routeCompletedAt = "";

      if (arguments.userId LTE 0 OR arguments.floatPlanId LTE 0) {
        return failure(model, "INVALID_ARGUMENTS", "A valid member and completed trip are required.", 400);
      }

      qPlan = loadCompletedPlan(arguments.userId, arguments.floatPlanId);
      if (qPlan.recordCount NEQ 1) {
        return failure(model, "COMPLETED_TRIP_NOT_FOUND", "Completed trip was not found.", 404);
      }

      routeInstanceId = numberValue(valueAt(qPlan, "route_instance_id"));
      routeStatus = uCase(textValue(valueAt(qPlan, "route_status")));
      routeCompletedAt = valueAt(qPlan, "route_completed_at");

      if (routeInstanceId GT 0 AND (routeStatus NEQ "COMPLETED" OR !isDate(routeCompletedAt))) {
        return failure(model, "ROUTE_INSTANCE_NOT_COMPLETED", "Completed trip was not found.", 404);
      }

      model.SUCCESS = true;
      model.found = true;
      model.statusCode = 200;
      model.message = "Completed trip loaded.";
      model.completedTripUrl = buildCompletedTripUrl(arguments.floatPlanId);
      model.trip = buildTripSection(qPlan);
      model.timing = buildTimingSection(qPlan);
      model.route = buildRouteSection(qPlan);
      model.vessel = buildVesselSection(qPlan);
      model.shoreContact = loadShoreContactSummary(arguments.floatPlanId);
      model.completion = buildCompletionSection(qPlan, model.route);
      model.monitoring = loadMonitoringSummary(arguments.userId, arguments.floatPlanId);
      model.follow = {
        "available" = false,
        "displayed" = false,
        "authority" = "not_found",
        "message" = "No completed-trip Follow final-state source was identified for this minimum view."
      };
      model.dataSources = {
        "trip" = "floatplans",
        "route" = "route_instances,route_instance_legs,route_instance_leg_progress",
        "routeGeometry" = "route_instance_geometry_snapshots",
        "vesselName" = "vessels.vesselName_current_mutable",
        "shoreContact" = "floatplan_contacts association only; live contact details suppressed",
        "monitoring" = "floatplan_monitoring"
      };

      if (model.vessel.available) {
        addWarning(
          model,
          "VESSEL_NAME_CURRENT_PROFILE_MUTABLE",
          "Vessel name is displayed from the current associated vessels row as an approved temporary compromise, not from a historical vessel snapshot.",
          "vessels.vesselName"
        );
      } else {
        addWarning(
          model,
          "VESSEL_SNAPSHOT_MISSING",
          "No historical vessel snapshot exists for this completed trip.",
          "floatplans.vesselId"
        );
      }

      if (model.shoreContact.associatedCount GT 0) {
        addWarning(
          model,
          "SHORE_CONTACT_DETAILS_SUPPRESSED",
          "Shore-contact details are not displayed because only live mutable contact rows are available.",
          "floatplan_contacts"
        );
      } else {
        addWarning(
          model,
          "SHORE_CONTACT_SNAPSHOT_MISSING",
          "No historical shore-contact snapshot exists for this completed trip.",
          "floatplan_contacts"
        );
      }

      return model;
    </cfscript>
  </cffunction>

  <cffunction name="buildCompletedTripUrl" access="public" returntype="string" output="false">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfargument name="basePath" type="string" required="false" default="">
    <cfscript>
      var base = trim(arguments.basePath);
      base = reReplace(base, "/$", "");
      if (base EQ "/") {
        base = "";
      }
      if (len(base) AND left(base, 1) NEQ "/") {
        base = "/" & base;
      }
      return base & "/app/completed-trip.cfm?id=" & val(arguments.floatPlanId);
    </cfscript>
  </cffunction>

  <cffunction name="loadCompletedPlan" access="private" returntype="query" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      return queryExecute(
        "SELECT
           fp.floatPlanId,
           fp.userId,
           fp.floatPlanName,
           fp.vesselId,
           fp.departing,
           fp.`returning`,
           fp.departureTime,
           fp.departureTimeUTC,
           fp.departureTZ,
           fp.departTimezone,
           fp.returnTime,
           fp.returnTimeUTC,
           fp.returnTZ,
           fp.returnTimezone,
           fp.activatedAt,
           fp.checkedInAt,
           fp.closedAt,
           fp.status,
           fp.route_instance_id,
           ri.status AS route_status,
           ri.started_at AS route_started_at,
           ri.completed_at AS route_completed_at,
           ri.trip_type,
           ri.start_location,
           ri.end_location,
           v.vesselName
         FROM floatplans fp
         LEFT JOIN route_instances ri
           ON ri.id = fp.route_instance_id
          AND TRIM(CAST(ri.user_id AS CHAR)) = TRIM(CAST(fp.userId AS CHAR))
         LEFT JOIN vessels v
           ON v.vesselID = fp.vesselId
          AND TRIM(CAST(v.userId AS CHAR)) = TRIM(CAST(fp.userId AS CHAR))
         WHERE fp.floatPlanId = :floatPlanId
           AND TRIM(CAST(fp.userId AS CHAR)) = :userIdText
           AND UPPER(TRIM(fp.status)) = 'CLOSED'
           AND fp.closedAt IS NOT NULL
         LIMIT 1",
        {
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
          userIdText = { value = toString(val(arguments.userId)), cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="buildTripSection" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfscript>
      var routeStart = textValue(valueAt(arguments.qPlan, "start_location"));
      var routeEnd = textValue(valueAt(arguments.qPlan, "end_location"));
      var departure = textValue(valueAt(arguments.qPlan, "departing"));
      var destination = textValue(valueAt(arguments.qPlan, "returning"));

      return {
        "id" = numberValue(valueAt(arguments.qPlan, "floatPlanId")),
        "name" = fallbackText(valueAt(arguments.qPlan, "floatPlanName"), "Completed Float Plan"),
        "status" = "Completed",
        "departureLocation" = fallbackText(departure, routeStart),
        "destination" = fallbackText(destination, routeEnd),
        "tripType" = formatTripType(valueAt(arguments.qPlan, "trip_type")),
        "displayId" = "FP-" & numberValue(valueAt(arguments.qPlan, "floatPlanId")),
        "idDisplayedProminently" = false
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildTimingSection" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfscript>
      var departureTz = resolveDepartureTimezone(arguments.qPlan);
      var returnTz = resolveReturnTimezone(arguments.qPlan);
      var completionTz = resolveCompletionTimezone(arguments.qPlan);
      var actualDeparture = firstDateValue(valueAt(arguments.qPlan, "route_started_at"), valueAt(arguments.qPlan, "activatedAt"));
      var actualCompletion = firstDateValue(valueAt(arguments.qPlan, "route_completed_at"), valueAt(arguments.qPlan, "closedAt"));

      return {
        "plannedDeparture" = buildTimePoint(
          valueAt(arguments.qPlan, "departureTimeUTC"),
          valueAt(arguments.qPlan, "departureTime"),
          departureTz,
          "floatplans.departureTimeUTC",
          "floatplans.departureTime"
        ),
        "actualDeparture" = buildTimePoint(
          actualDeparture,
          "",
          departureTz,
          (isDate(valueAt(arguments.qPlan, "route_started_at")) ? "route_instances.started_at" : "floatplans.activatedAt"),
          ""
        ),
        "plannedReturn" = buildTimePoint(
          valueAt(arguments.qPlan, "returnTimeUTC"),
          valueAt(arguments.qPlan, "returnTime"),
          returnTz,
          "floatplans.returnTimeUTC",
          "floatplans.returnTime"
        ),
        "actualCompletion" = buildTimePoint(
          actualCompletion,
          "",
          completionTz,
          (isDate(valueAt(arguments.qPlan, "route_completed_at")) ? "route_instances.completed_at" : "floatplans.closedAt"),
          ""
        ),
        "completionTimezone" = completionTz,
        "durationAvailable" = false,
        "durationLabel" = "Not calculated"
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildRouteSection" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfscript>
      var routeInstanceId = numberValue(valueAt(arguments.qPlan, "route_instance_id"));
      var route = {
        "available" = false,
        "routeInstanceId" = routeInstanceId,
        "status" = "",
        "start" = "",
        "destination" = "",
        "tripType" = "",
        "legCount" = 0,
        "waypointCount" = 0,
        "distanceNm" = "",
        "distanceLabel" = "Not available",
        "geometrySnapshot" = {
          "available" = false,
          "authority" = "route_instance_geometry_snapshots",
          "createdAtUtc" = "",
          "markerCount" = 0
        },
        "authority" = "route_instances"
      };
      var qLegs = queryNew("");
      var qSnapshot = queryNew("");
      var distance = 0;
      var i = 0;
      var parsedSnapshot = {};

      if (routeInstanceId LTE 0) {
        route.authority = "route-less floatplan";
        return route;
      }

      route.available = true;
      route.status = textValue(valueAt(arguments.qPlan, "route_status"));
      route.start = fallbackText(valueAt(arguments.qPlan, "start_location"), valueAt(arguments.qPlan, "departing"));
      route.destination = fallbackText(valueAt(arguments.qPlan, "end_location"), valueAt(arguments.qPlan, "returning"));
      route.tripType = formatTripType(valueAt(arguments.qPlan, "trip_type"));

      qLegs = queryExecute(
        "SELECT leg_order, start_name, end_name, base_dist_nm
         FROM route_instance_legs
         WHERE route_instance_id = :routeInstanceId
         ORDER BY leg_order ASC, id ASC",
        {
          routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );

      route.legCount = qLegs.recordCount;
      if (qLegs.recordCount GT 0) {
        if (!len(route.start)) {
          route.start = textValue(qLegs.start_name[1]);
        }
        if (!len(route.destination)) {
          route.destination = textValue(qLegs.end_name[qLegs.recordCount]);
        }
        for (i = 1; i LTE qLegs.recordCount; i++) {
          if (isNumeric(qLegs.base_dist_nm[i])) {
            distance += val(qLegs.base_dist_nm[i]);
          }
        }
        route.waypointCount = qLegs.recordCount + 1;
        route.distanceNm = distance;
        route.distanceLabel = numberFormat(distance, "0.0") & " NM";
      }

      qSnapshot = queryExecute(
        "SELECT snapshot_version, snapshot_json, created_at_utc
         FROM route_instance_geometry_snapshots
         WHERE route_instance_id = :routeInstanceId
         LIMIT 1",
        {
          routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );

      if (qSnapshot.recordCount EQ 1 AND val(qSnapshot.snapshot_version[1]) EQ 1 AND len(textValue(qSnapshot.snapshot_json[1]))) {
        route.geometrySnapshot.available = true;
        route.geometrySnapshot.createdAtUtc = formatUtc(qSnapshot.created_at_utc[1]);
        try {
          parsedSnapshot = deserializeJSON(textValue(qSnapshot.snapshot_json[1]), false);
          if (isStruct(parsedSnapshot) AND structKeyExists(parsedSnapshot, "markers") AND isArray(parsedSnapshot.markers)) {
            route.geometrySnapshot.markerCount = arrayLen(parsedSnapshot.markers);
            if (route.geometrySnapshot.markerCount GT route.waypointCount) {
              route.waypointCount = route.geometrySnapshot.markerCount;
            }
          }
        } catch (any snapshotParseErr) {
          route.geometrySnapshot.available = false;
        }
      }

      return route;
    </cfscript>
  </cffunction>

  <cffunction name="buildVesselSection" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfscript>
      var vesselName = textValue(valueAt(arguments.qPlan, "vesselName"));
      return {
        "available" = len(vesselName) GT 0,
        "name" = vesselName,
        "authority" = "vessels.vesselName_current_mutable",
        "isHistoricalSnapshot" = false,
        "snapshotAvailable" = false,
        "message" = "Temporary compromise: current associated vessel name only."
      };
    </cfscript>
  </cffunction>

  <cffunction name="loadShoreContactSummary" access="private" returntype="struct" output="false">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      var qContacts = queryExecute(
        "SELECT COUNT(*) AS contact_count
         FROM floatplan_contacts
         WHERE floatPlanId = :floatPlanId",
        {
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );

      return {
        "displayed" = false,
        "snapshotAvailable" = false,
        "associatedCount" = (qContacts.recordCount ? numberValue(qContacts.contact_count[1]) : 0),
        "authority" = "floatplan_contacts association only; live contacts suppressed",
        "message" = "Live shore-contact details are intentionally not shown as historical facts."
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildCompletionSection" access="private" returntype="struct" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfargument name="route" type="struct" required="true">
    <cfscript>
      var completionTz = resolveCompletionTimezone(arguments.qPlan);
      var completedAt = firstDateValue(valueAt(arguments.qPlan, "route_completed_at"), valueAt(arguments.qPlan, "closedAt"));

      return {
        "status" = "Completed",
        "completedAtUtc" = formatUtc(completedAt),
        "completedAtLocalLabel" = formatLocalDisplay(completedAt, completionTz),
        "timezone" = completionTz,
        "routeCompleted" = (structKeyExists(arguments.route, "available") AND arguments.route.available AND uCase(textValue(arguments.route.status)) EQ "COMPLETED"),
        "routeCompletedAtUtc" = formatUtc(valueAt(arguments.qPlan, "route_completed_at")),
        "floatPlanClosedAtUtc" = formatUtc(valueAt(arguments.qPlan, "closedAt")),
        "authority" = (isDate(valueAt(arguments.qPlan, "route_completed_at")) ? "route_instances.completed_at" : "floatplans.closedAt")
      };
    </cfscript>
  </cffunction>

  <cffunction name="loadMonitoringSummary" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      var qMonitoring = queryExecute(
        "SELECT monitor_state, is_monitoring_enabled, closed_at
         FROM floatplan_monitoring
         WHERE float_plan_id = :floatPlanId
           AND user_id = :userId
         ORDER BY id DESC
         LIMIT 1",
        {
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );

      if (qMonitoring.recordCount NEQ 1) {
        return {
          "available" = false,
          "closed" = false,
          "state" = "Not available",
          "closedAtUtc" = "",
          "authority" = "floatplan_monitoring"
        };
      }

      return {
        "available" = true,
        "closed" = (uCase(textValue(qMonitoring.monitor_state[1])) EQ "CLOSED" OR isDate(qMonitoring.closed_at[1])),
        "state" = textValue(qMonitoring.monitor_state[1]),
        "closedAtUtc" = formatUtc(qMonitoring.closed_at[1]),
        "authority" = "floatplan_monitoring"
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildTimePoint" access="private" returntype="struct" output="false">
    <cfargument name="utcValue" type="any" required="true">
    <cfargument name="localValue" type="any" required="false" default="">
    <cfargument name="timezone" type="string" required="true">
    <cfargument name="utcAuthority" type="string" required="true">
    <cfargument name="localAuthority" type="string" required="false" default="">
    <cfscript>
      var authoritativeValue = isDate(arguments.utcValue) ? arguments.utcValue : arguments.localValue;
      var authority = isDate(arguments.utcValue) ? arguments.utcAuthority : arguments.localAuthority;
      return {
        "available" = isDate(authoritativeValue),
        "utc" = formatUtc(arguments.utcValue),
        "localLabel" = formatLocalDisplay(authoritativeValue, arguments.timezone),
        "timezone" = normalizeTimezone(arguments.timezone),
        "authority" = authority
      };
    </cfscript>
  </cffunction>

  <cffunction name="baseModel" access="private" returntype="struct" output="false">
    <cfscript>
      return {
        "SUCCESS" = false,
        "AUTH" = true,
        "found" = false,
        "errorCode" = "",
        "message" = "",
        "statusCode" = 200,
        "warnings" = []
      };
    </cfscript>
  </cffunction>

  <cffunction name="failure" access="private" returntype="struct" output="false">
    <cfargument name="model" type="struct" required="true">
    <cfargument name="errorCode" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfargument name="statusCode" type="numeric" required="true">
    <cfscript>
      arguments.model.SUCCESS = false;
      arguments.model.found = false;
      arguments.model.errorCode = arguments.errorCode;
      arguments.model.message = arguments.message;
      arguments.model.statusCode = arguments.statusCode;
      return arguments.model;
    </cfscript>
  </cffunction>

  <cffunction name="addWarning" access="private" returntype="void" output="false">
    <cfargument name="model" type="struct" required="true">
    <cfargument name="code" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfargument name="source" type="string" required="true">
    <cfscript>
      arrayAppend(arguments.model.warnings, {
        "code" = arguments.code,
        "message" = arguments.message,
        "source" = arguments.source
      });
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

  <cffunction name="textValue" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="false" default="">
    <cfscript>
      if (isNull(arguments.value) OR !isSimpleValue(arguments.value)) {
        return "";
      }
      return trim(toString(arguments.value));
    </cfscript>
  </cffunction>

  <cffunction name="fallbackText" access="private" returntype="string" output="false">
    <cfargument name="primaryValue" type="any" required="false" default="">
    <cfargument name="fallbackValue" type="any" required="false" default="">
    <cfscript>
      var primaryText = textValue(arguments.primaryValue);
      if (len(primaryText)) {
        return primaryText;
      }
      return textValue(arguments.fallbackValue);
    </cfscript>
  </cffunction>

  <cffunction name="numberValue" access="private" returntype="numeric" output="false">
    <cfargument name="value" type="any" required="false" default="">
    <cfscript>
      if (!isNumeric(arguments.value)) {
        return 0;
      }
      return val(arguments.value);
    </cfscript>
  </cffunction>

  <cffunction name="firstDateValue" access="private" returntype="any" output="false">
    <cfargument name="primaryValue" type="any" required="true">
    <cfargument name="fallbackValue" type="any" required="true">
    <cfscript>
      if (isDate(arguments.primaryValue)) {
        return arguments.primaryValue;
      }
      if (isDate(arguments.fallbackValue)) {
        return arguments.fallbackValue;
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

  <cffunction name="formatLocalDisplay" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="true">
    <cfargument name="timezone" type="string" required="true">
    <cfscript>
      var tzId = normalizeTimezone(arguments.timezone);
      if (!isDate(arguments.value)) {
        return "Not available";
      }
      try {
        return dateTimeFormat(arguments.value, "mmm d, yyyy h:nn tt", tzId) & " " & tzId;
      } catch (any localDisplayErr) {
        return dateTimeFormat(arguments.value, "mmm d, yyyy h:nn tt") & " UTC";
      }
    </cfscript>
  </cffunction>

  <cffunction name="resolveDepartureTimezone" access="private" returntype="string" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfscript>
      return normalizeTimezone(fallbackText(valueAt(arguments.qPlan, "departureTZ"), valueAt(arguments.qPlan, "departTimezone")));
    </cfscript>
  </cffunction>

  <cffunction name="resolveReturnTimezone" access="private" returntype="string" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfscript>
      return normalizeTimezone(fallbackText(valueAt(arguments.qPlan, "returnTZ"), valueAt(arguments.qPlan, "returnTimezone")));
    </cfscript>
  </cffunction>

  <cffunction name="resolveCompletionTimezone" access="private" returntype="string" output="false">
    <cfargument name="qPlan" type="query" required="true">
    <cfscript>
      var returnTz = resolveReturnTimezone(arguments.qPlan);
      if (len(returnTz) AND returnTz NEQ "UTC") {
        return returnTz;
      }
      return resolveDepartureTimezone(arguments.qPlan);
    </cfscript>
  </cffunction>

  <cffunction name="normalizeTimezone" access="private" returntype="string" output="false">
    <cfargument name="timezone" type="string" required="false" default="">
    <cfscript>
      var tz = trim(arguments.timezone);
      switch (uCase(tz)) {
        case "US/EASTERN":
          return "America/New_York";
        case "US/CENTRAL":
          return "America/Chicago";
        case "US/MOUNTAIN":
          return "America/Denver";
        case "US/PACIFIC":
          return "America/Los_Angeles";
        case "US/ALASKA":
          return "America/Anchorage";
        case "US/HAWAII":
          return "Pacific/Honolulu";
        case "+00:00":
        case "UTC":
        case "ETC/UTC":
        case "GMT":
          return "UTC";
      }
      if (!len(tz)) {
        return "UTC";
      }
      try {
        dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss", tz);
        return tz;
      } catch (any invalidTimezoneErr) {
        return "UTC";
      }
    </cfscript>
  </cffunction>

  <cffunction name="formatTripType" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="false" default="">
    <cfscript>
      var raw = reReplace(lCase(replace(textValue(arguments.value), "_", " ", "all")), "\s+", " ", "all");
      var words = [];
      var formatted = [];
      var i = 0;
      var word = "";
      if (!len(raw)) {
        return "";
      }
      words = listToArray(raw, " ");
      for (i = 1; i LTE arrayLen(words); i++) {
        word = trim(words[i]);
        if (len(word)) {
          arrayAppend(formatted, uCase(left(word, 1)) & (len(word) GT 1 ? mid(word, 2, len(word) - 1) : ""));
        }
      }
      return arrayToList(formatted, " ");
    </cfscript>
  </cffunction>

</cfcomponent>
