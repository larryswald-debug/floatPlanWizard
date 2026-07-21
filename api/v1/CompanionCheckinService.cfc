<cfcomponent output="false">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfscript>
      variables.datasource = arguments.datasource;
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="submitCheckin" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="payload" type="struct" required="true">
    <cfargument name="requestContext" type="struct" required="false" default="#structNew()#">
    <cfscript>
      var validation = validatePayload(arguments.payload);
      var activePlan = {};
      var tripAccessGate = {};
      var existingEvent = {};
      var insertedEvent = {};
      var canonicalPayload = {};
      var canonicalResponse = {};
      var refreshedModel = {};

      if (arguments.userId LTE 0) {
        return errorResponse("INVALID_USER_ID", "A valid authenticated user is required.", false);
      }

      if (!validation.SUCCESS) {
        return validation;
      }

      activePlan = validateActivePlan(arguments.userId, validation.floatPlanId);
      if (!activePlan.SUCCESS) {
        return activePlan;
      }

      tripAccessGate = createApiComponent("MemberAccessGateService")
        .init(variables.datasource)
        .requireTripOperationalAccess(arguments.userId, validation.floatPlanId);
      if (!structKeyExists(tripAccessGate, "allowed") OR !tripAccessGate.allowed) {
        return tripAccessGate.response;
      }

      validation.routeInstanceId = readNumber(activePlan, "routeInstanceId");
      validation.legOrder = readNumber(activePlan, "legOrder");
      validation.companionDeviceId = readNumber(arguments.requestContext, "companionDeviceId");

      existingEvent = getCompanionEvent(arguments.userId, validation.mobileSubmissionId);
      if (readNumber(existingEvent, "id") GT 0) {
        return handleExistingEvent(arguments.userId, existingEvent);
      }

      insertedEvent = insertReceivedEvent(arguments.userId, validation);
      if (structKeyExists(insertedEvent, "DUPLICATE") AND insertedEvent.DUPLICATE) {
        existingEvent = getCompanionEvent(arguments.userId, validation.mobileSubmissionId);
        if (readNumber(existingEvent, "id") GT 0) {
          return handleExistingEvent(arguments.userId, existingEvent);
        }
        return errorResponse("DUPLICATE_RACE_UNRESOLVED", "A duplicate mobile submission could not be resolved.", true);
      }
      if (!insertedEvent.SUCCESS) {
        return insertedEvent;
      }

      canonicalPayload = {
        "floatPlanId" = validation.floatPlanId,
        "status" = validation.status,
        "note" = validation.note,
        "checkinContext" = validation.checkinContext
      };

      canonicalResponse = callCanonicalCheckin(arguments.userId, canonicalPayload, arguments.requestContext);
      if (isSuccessPayload(canonicalResponse)) {
        markEventProcessed(insertedEvent.id);
        refreshedModel = createApiComponent("CompanionViewModelService").init(variables.datasource)
          .getCurrentActiveCompanionModel(arguments.userId);
        return {
          "SUCCESS" = true,
          "success" = true,
          "AUTH" = true,
          "duplicate" = false,
          "eventId" = insertedEvent.id,
          "MESSAGE" = "Check-in recorded.",
          "companion" = refreshedModel
        };
      }

      markEventFailed(insertedEvent.id, canonicalErrorMessage(canonicalResponse));
      return {
        "SUCCESS" = false,
        "success" = false,
        "AUTH" = true,
        "duplicate" = false,
        "eventId" = insertedEvent.id,
        "ERROR" = firstNonEmpty([
          readString(canonicalResponse, "ERROR"),
          "CANONICAL_CHECKIN_FAILED"
        ]),
        "MESSAGE" = firstNonEmpty([
          readString(canonicalResponse, "MESSAGE"),
          "The canonical check-in endpoint rejected the submission."
        ]),
        "canonical" = canonicalResponse
      };
    </cfscript>
  </cffunction>

  <cffunction name="validatePayload" access="private" returntype="struct" output="false">
    <cfargument name="payload" type="struct" required="true">
    <cfscript>
      var mobileSubmissionId = readString(arguments.payload, "mobileSubmissionId");
      var floatPlanId = readNumber(arguments.payload, "floatPlanId");
      var rawStatus = readString(arguments.payload, "status");
      var status = normalizeStatus(rawStatus);
      var note = readString(arguments.payload, "note");
      var checkinContext = readString(arguments.payload, "checkinContext");
      var location = readStruct(arguments.payload, "location");
      var device = readStruct(arguments.payload, "device");
      var locationValidation = {};
      var offlineValidation = {};
      var deviceValidation = {};

      if (!len(mobileSubmissionId)) {
        return errorResponse("MOBILE_SUBMISSION_ID_REQUIRED", "mobileSubmissionId is required.", true);
      }
      if (len(mobileSubmissionId) GT 128) {
        return errorResponse("MOBILE_SUBMISSION_ID_TOO_LONG", "mobileSubmissionId must be 128 characters or fewer.", true);
      }
      if (floatPlanId LTE 0) {
        return errorResponse("FLOAT_PLAN_ID_REQUIRED", "floatPlanId is required.", true);
      }
      if (!len(status)) {
        if (compareNoCase(rawStatus, "Arrived") EQ 0) {
          return errorResponse("UNSUPPORTED_STATUS", "Arrived is not supported by the companion check-in endpoint.", true);
        }
        return errorResponse("INVALID_STATUS", "Unsupported check-in status.", true);
      }
      if (len(note) GT 500) {
        return errorResponse("NOTE_TOO_LONG", "Check-in note must be 500 characters or fewer.", true);
      }

      if (compareNoCase(status, "Secure for the Night") EQ 0 AND !len(checkinContext)) {
        checkinContext = "overnight";
      }
      if (len(checkinContext) AND compareNoCase(checkinContext, "overnight") NEQ 0) {
        return errorResponse("INVALID_CHECKIN_CONTEXT", "Unsupported check-in context.", true);
      }
      if (len(checkinContext) AND compareNoCase(status, "Secure for the Night") NEQ 0) {
        return errorResponse("INVALID_CHECKIN_CONTEXT", "The overnight context is only supported for Secure for the Night check-ins.", true);
      }

      locationValidation = validateLocation(location);
      if (!locationValidation.SUCCESS) {
        return locationValidation;
      }

      offlineValidation = parseOptionalUtcDate(readString(arguments.payload, "offlineCreatedAtUtc"), "INVALID_OFFLINE_CREATED_AT", "offlineCreatedAtUtc must be parseable.");
      if (!offlineValidation.SUCCESS) {
        return offlineValidation;
      }

      deviceValidation = validateDevice(device);
      if (!deviceValidation.SUCCESS) {
        return deviceValidation;
      }

      return {
        "SUCCESS" = true,
        "success" = true,
        "AUTH" = true,
        "mobileSubmissionId" = mobileSubmissionId,
        "floatPlanId" = floatPlanId,
        "status" = status,
        "note" = note,
        "checkinContext" = checkinContext,
        "latitude" = locationValidation.latitude,
        "longitude" = locationValidation.longitude,
        "gpsAccuracyMeters" = locationValidation.gpsAccuracyMeters,
        "gpsAltitudeMeters" = locationValidation.gpsAltitudeMeters,
        "speedKnots" = locationValidation.speedKnots,
        "headingDegrees" = locationValidation.headingDegrees,
        "locationCapturedAtUtc" = locationValidation.capturedAtUtc,
        "deviceUuid" = deviceValidation.deviceUuid,
        "devicePlatform" = deviceValidation.devicePlatform,
        "appVersion" = deviceValidation.appVersion,
        "offlineCreatedAtUtc" = offlineValidation.value,
        "routeInstanceId" = 0,
        "legOrder" = 0
      };
    </cfscript>
  </cffunction>

  <cffunction name="validateActivePlan" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      var floatPlanComponent = createApiComponent("floatplan");
      var companionService = createApiComponent("CompanionViewModelService").init(variables.datasource);
      var currentGroup = floatPlanComponent.resolveCurrentRouteFloatPlanGroup(arguments.userId);
      var companionModel = {};
      var activeFloatPlanId = readNumber(currentGroup, "FLOATPLANID");

      if (!isStruct(currentGroup) OR !readBoolean(currentGroup, "SUCCESS") OR !readBoolean(currentGroup, "IS_ACTIVE")) {
        return errorResponse(firstNonEmpty([
          readString(currentGroup, "ERROR"),
          "NO_ACTIVE_PLAN"
        ]), firstNonEmpty([
          readString(currentGroup, "MESSAGE"),
          "No active trip is available."
        ]), true);
      }

      if (activeFloatPlanId LTE 0 OR activeFloatPlanId NEQ arguments.floatPlanId) {
        return errorResponse("ACTIVE_PLAN_MISMATCH", "The requested float plan is not the authenticated user's active route-backed plan.", true);
      }

      if (readNumber(currentGroup, "ROUTE_INSTANCE_ID") LTE 0) {
        return errorResponse("ROUTE_REQUIRED", "The active float plan must be linked to a route.", true);
      }

      companionModel = companionService.getCurrentActiveCompanionModel(arguments.userId);
      if (!isSuccessPayload(companionModel)) {
        return errorResponse(firstNonEmpty([
          readString(companionModel, "ERROR"),
          "COMPANION_MODEL_UNAVAILABLE"
        ]), firstNonEmpty([
          readString(companionModel, "MESSAGE"),
          "The companion model could not be refreshed."
        ]), true);
      }

      return {
        "SUCCESS" = true,
        "success" = true,
        "AUTH" = true,
        "floatPlanId" = activeFloatPlanId,
        "routeInstanceId" = readNumber(currentGroup, "ROUTE_INSTANCE_ID"),
        "legOrder" = readNumber(readStruct(companionModel, "currentLeg"), "order")
      };
    </cfscript>
  </cffunction>

  <cffunction name="validateLocation" access="private" returntype="struct" output="false">
    <cfargument name="location" type="struct" required="true">
    <cfscript>
      var capturedAt = {};
      var result = {
        "SUCCESS" = true,
        "success" = true,
        "latitude" = "",
        "longitude" = "",
        "gpsAccuracyMeters" = "",
        "gpsAltitudeMeters" = "",
        "speedKnots" = "",
        "headingDegrees" = "",
        "capturedAtUtc" = ""
      };

      if (!structCount(arguments.location)) {
        return result;
      }

      if (!isNumericValue(arguments.location, "latitude") OR val(arguments.location.latitude) LT -90 OR val(arguments.location.latitude) GT 90) {
        return errorResponse("INVALID_LOCATION", "Latitude must be between -90 and 90.", true);
      }
      if (!isNumericValue(arguments.location, "longitude") OR val(arguments.location.longitude) LT -180 OR val(arguments.location.longitude) GT 180) {
        return errorResponse("INVALID_LOCATION", "Longitude must be between -180 and 180.", true);
      }

      result.latitude = val(arguments.location.latitude);
      result.longitude = val(arguments.location.longitude);

      if (structKeyExists(arguments.location, "accuracyMeters") AND len(trim(toString(arguments.location.accuracyMeters)))) {
        if (!isNumeric(arguments.location.accuracyMeters) OR val(arguments.location.accuracyMeters) LT 0) {
          return errorResponse("INVALID_LOCATION", "GPS accuracy must be numeric and non-negative.", true);
        }
        result.gpsAccuracyMeters = val(arguments.location.accuracyMeters);
      }
      if (structKeyExists(arguments.location, "altitudeMeters") AND len(trim(toString(arguments.location.altitudeMeters)))) {
        if (!isNumeric(arguments.location.altitudeMeters)) {
          return errorResponse("INVALID_LOCATION", "GPS altitude must be numeric.", true);
        }
        result.gpsAltitudeMeters = val(arguments.location.altitudeMeters);
      }
      if (structKeyExists(arguments.location, "speedKnots") AND len(trim(toString(arguments.location.speedKnots)))) {
        if (!isNumeric(arguments.location.speedKnots) OR val(arguments.location.speedKnots) LT 0) {
          return errorResponse("INVALID_LOCATION", "Speed must be numeric and non-negative.", true);
        }
        result.speedKnots = val(arguments.location.speedKnots);
      }
      if (structKeyExists(arguments.location, "headingDegrees") AND len(trim(toString(arguments.location.headingDegrees)))) {
        if (!isNumeric(arguments.location.headingDegrees) OR val(arguments.location.headingDegrees) LT 0 OR val(arguments.location.headingDegrees) GT 360) {
          return errorResponse("INVALID_LOCATION", "Heading must be between 0 and 360 degrees.", true);
        }
        result.headingDegrees = val(arguments.location.headingDegrees);
      }

      capturedAt = parseOptionalUtcDate(readString(arguments.location, "capturedAtUtc"), "INVALID_LOCATION", "Location capturedAtUtc must be parseable.");
      if (!capturedAt.SUCCESS) {
        return capturedAt;
      }
      result.capturedAtUtc = capturedAt.value;

      return result;
    </cfscript>
  </cffunction>

  <cffunction name="validateDevice" access="private" returntype="struct" output="false">
    <cfargument name="device" type="struct" required="true">
    <cfscript>
      var deviceUuid = readString(arguments.device, "deviceUuid");
      var platform = lCase(readString(arguments.device, "platform"));
      var appVersion = readString(arguments.device, "appVersion");

      if (len(deviceUuid) GT 128) {
        return errorResponse("INVALID_DEVICE", "deviceUuid must be 128 characters or fewer.", true);
      }
      if (len(platform) AND !listFindNoCase("ios,android", platform)) {
        return errorResponse("INVALID_DEVICE", "Device platform must be ios or android.", true);
      }
      if (len(appVersion) GT 40) {
        return errorResponse("INVALID_DEVICE", "appVersion must be 40 characters or fewer.", true);
      }

      return {
        "SUCCESS" = true,
        "success" = true,
        "deviceUuid" = deviceUuid,
        "devicePlatform" = platform,
        "appVersion" = appVersion
      };
    </cfscript>
  </cffunction>

  <cffunction name="insertReceivedEvent" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="eventData" type="struct" required="true">
    <cfscript>
      var inserted = {};
      try {
        queryExecute(
          "INSERT INTO floatplan_companion_events (
             mobile_submission_id,
             user_id,
             floatplan_id,
             route_instance_id,
             leg_order,
             event_type,
             canonical_status,
             note,
             checkin_context,
             latitude,
             longitude,
             gps_accuracy_meters,
             gps_altitude_meters,
             speed_knots,
             heading_degrees,
             location_captured_at_utc,
             companion_device_id,
             device_uuid,
             device_platform,
             app_version,
             offline_created_at_utc,
             received_at_utc,
             process_status,
             created_utc,
             updated_utc
           ) VALUES (
             :mobileSubmissionId,
             :userId,
             :floatPlanId,
             :routeInstanceId,
             :legOrder,
             'CHECKIN',
             :canonicalStatus,
             :note,
             :checkinContext,
             :latitude,
             :longitude,
             :gpsAccuracyMeters,
             :gpsAltitudeMeters,
             :speedKnots,
             :headingDegrees,
             :locationCapturedAtUtc,
             :companionDeviceId,
             :deviceUuid,
             :devicePlatform,
             :appVersion,
             :offlineCreatedAtUtc,
             UTC_TIMESTAMP(),
             'RECEIVED',
             UTC_TIMESTAMP(),
             UTC_TIMESTAMP()
           )",
          buildInsertParams(arguments.userId, arguments.eventData),
          { datasource = variables.datasource }
        );
      } catch (any insertError) {
        if (isDuplicateKeyError(insertError)) {
          return { "SUCCESS" = false, "success" = false, "AUTH" = true, "DUPLICATE" = true };
        }
        return errorResponse("COMPANION_EVENT_WRITE_FAILED", "The companion event could not be recorded.", true, insertError.message);
      }

      inserted = getCompanionEvent(arguments.userId, arguments.eventData.mobileSubmissionId);
      if (readNumber(inserted, "id") LTE 0) {
        return errorResponse("COMPANION_EVENT_NOT_FOUND", "The companion event was recorded but could not be reloaded.", true);
      }

      return {
        "SUCCESS" = true,
        "success" = true,
        "AUTH" = true,
        "id" = readNumber(inserted, "id")
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildInsertParams" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="eventData" type="struct" required="true">
    <cfscript>
      return {
        mobileSubmissionId = { value = arguments.eventData.mobileSubmissionId, cfsqltype = "cf_sql_varchar" },
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        floatPlanId = { value = arguments.eventData.floatPlanId, cfsqltype = "cf_sql_integer" },
        routeInstanceId = { value = arguments.eventData.routeInstanceId, cfsqltype = "cf_sql_integer", null = (arguments.eventData.routeInstanceId LTE 0) },
        legOrder = { value = arguments.eventData.legOrder, cfsqltype = "cf_sql_integer", null = (arguments.eventData.legOrder LTE 0) },
        canonicalStatus = { value = arguments.eventData.status, cfsqltype = "cf_sql_varchar" },
        note = { value = arguments.eventData.note, cfsqltype = "cf_sql_longvarchar", null = !len(arguments.eventData.note) },
        checkinContext = { value = arguments.eventData.checkinContext, cfsqltype = "cf_sql_varchar", null = !len(arguments.eventData.checkinContext) },
        latitude = { value = optionalNumber(arguments.eventData.latitude), cfsqltype = "cf_sql_double", null = !isNumeric(arguments.eventData.latitude) },
        longitude = { value = optionalNumber(arguments.eventData.longitude), cfsqltype = "cf_sql_double", null = !isNumeric(arguments.eventData.longitude) },
        gpsAccuracyMeters = { value = optionalNumber(arguments.eventData.gpsAccuracyMeters), cfsqltype = "cf_sql_double", null = !isNumeric(arguments.eventData.gpsAccuracyMeters) },
        gpsAltitudeMeters = { value = optionalNumber(arguments.eventData.gpsAltitudeMeters), cfsqltype = "cf_sql_double", null = !isNumeric(arguments.eventData.gpsAltitudeMeters) },
        speedKnots = { value = optionalNumber(arguments.eventData.speedKnots), cfsqltype = "cf_sql_double", null = !isNumeric(arguments.eventData.speedKnots) },
        headingDegrees = { value = optionalNumber(arguments.eventData.headingDegrees), cfsqltype = "cf_sql_double", null = !isNumeric(arguments.eventData.headingDegrees) },
        locationCapturedAtUtc = { value = arguments.eventData.locationCapturedAtUtc, cfsqltype = "cf_sql_timestamp", null = !isDate(arguments.eventData.locationCapturedAtUtc) },
        companionDeviceId = { value = readNumber(arguments.eventData, "companionDeviceId"), cfsqltype = "cf_sql_bigint", null = (readNumber(arguments.eventData, "companionDeviceId") LTE 0) },
        deviceUuid = { value = arguments.eventData.deviceUuid, cfsqltype = "cf_sql_varchar", null = !len(arguments.eventData.deviceUuid) },
        devicePlatform = { value = arguments.eventData.devicePlatform, cfsqltype = "cf_sql_varchar", null = !len(arguments.eventData.devicePlatform) },
        appVersion = { value = arguments.eventData.appVersion, cfsqltype = "cf_sql_varchar", null = !len(arguments.eventData.appVersion) },
        offlineCreatedAtUtc = { value = arguments.eventData.offlineCreatedAtUtc, cfsqltype = "cf_sql_timestamp", null = !isDate(arguments.eventData.offlineCreatedAtUtc) }
      };
    </cfscript>
  </cffunction>

  <cffunction name="getCompanionEvent" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="mobileSubmissionId" type="string" required="true">
    <cfscript>
      var qEvent = queryExecute(
        "SELECT id, mobile_submission_id, user_id, floatplan_id, process_status, process_error
         FROM floatplan_companion_events
         WHERE user_id = :userId
           AND mobile_submission_id = :mobileSubmissionId
         LIMIT 1",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
          mobileSubmissionId = { value = arguments.mobileSubmissionId, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );

      if (qEvent.recordCount EQ 0) {
        return {};
      }

      return {
        "id" = val(qEvent.id[1]),
        "mobileSubmissionId" = toString(qEvent.mobile_submission_id[1]),
        "userId" = val(qEvent.user_id[1]),
        "floatPlanId" = val(qEvent.floatplan_id[1]),
        "processStatus" = toString(qEvent.process_status[1]),
        "processError" = toString(qEvent.process_error[1])
      };
    </cfscript>
  </cffunction>

  <cffunction name="handleExistingEvent" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="eventRow" type="struct" required="true">
    <cfscript>
      var processStatus = readString(arguments.eventRow, "processStatus");
      var refreshedModel = {};

      if (compareNoCase(processStatus, "PROCESSED") EQ 0) {
        refreshedModel = createApiComponent("CompanionViewModelService").init(variables.datasource)
          .getCurrentActiveCompanionModel(arguments.userId);
        return {
          "SUCCESS" = true,
          "success" = true,
          "AUTH" = true,
          "duplicate" = true,
          "eventId" = readNumber(arguments.eventRow, "id"),
          "MESSAGE" = "Check-in already processed.",
          "companion" = refreshedModel
        };
      }

      if (compareNoCase(processStatus, "FAILED") EQ 0) {
        return errorResponse("DUPLICATE_FAILED", "This mobile submission previously failed and was not retried.", true, readString(arguments.eventRow, "processError"));
      }

      return errorResponse("DUPLICATE_PENDING", "This mobile submission has already been received.", true);
    </cfscript>
  </cffunction>

  <cffunction name="resolveCanonicalBaseUrl" access="private" returntype="string" output="false">
    <cfargument name="baseUrl" type="string" required="true">
    <cfscript>
      var normalizedBaseUrl = reReplace(trim(arguments.baseUrl), "/+$", "", "all");
      var proxyOrigins = [ "http://localhost:4200", "http://127.0.0.1:4200" ];
      var proxyOrigin = "";
      var suffix = "";

      for (proxyOrigin in proxyOrigins) {
        if (compareNoCase(left(normalizedBaseUrl, len(proxyOrigin)), proxyOrigin) EQ 0) {
          suffix = "";
          if (len(normalizedBaseUrl) GT len(proxyOrigin)) {
            suffix = right(normalizedBaseUrl, len(normalizedBaseUrl) - len(proxyOrigin));
          }
          if (!len(suffix) OR left(suffix, 1) EQ "/") {
            return "http://localhost:8500" & suffix;
          }
        }
      }

      return normalizedBaseUrl;
    </cfscript>
  </cffunction>

  <cffunction name="callCanonicalCheckin" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="payload" type="struct" required="true">
    <cfargument name="requestContext" type="struct" required="true">
    <cfscript>
      try {
        return createApiComponent("floatplan").submitCanonicalCompanionCheckin(arguments.userId, arguments.payload);
      } catch (any canonicalError) {
        return {
          "SUCCESS" = false,
          "success" = false,
          "AUTH" = true,
          "ERROR" = "CANONICAL_CHECKIN_EXCEPTION",
          "MESSAGE" = "Canonical check-in could not be completed."
        };
      }
    </cfscript>
  </cffunction>

  <cffunction name="parseCanonicalResponse" access="private" returntype="struct" output="false">
    <cfargument name="httpResult" type="struct" required="true">
    <cfscript>
      var fileContent = trim(toString(structKeyExists(arguments.httpResult, "fileContent") ? arguments.httpResult.fileContent : ""));
      var parsed = {};

      try {
        parsed = deserializeJSON(fileContent);
      } catch (any parseError) {
        return {
          "SUCCESS" = false,
          "success" = false,
          "AUTH" = true,
          "ERROR" = "CANONICAL_RESPONSE_PARSE_ERROR",
          "MESSAGE" = "Canonical check-in response could not be parsed.",
          "DETAIL" = left(fileContent, 500)
        };
      }

      if (!isStruct(parsed)) {
        return {
          "SUCCESS" = false,
          "success" = false,
          "AUTH" = true,
          "ERROR" = "CANONICAL_RESPONSE_INVALID",
          "MESSAGE" = "Canonical check-in response was not a JSON object."
        };
      }

      return parsed;
    </cfscript>
  </cffunction>

  <cffunction name="markEventProcessed" access="private" returntype="void" output="false">
    <cfargument name="eventId" type="numeric" required="true">
    <cfscript>
      queryExecute(
        "UPDATE floatplan_companion_events
         SET process_status = 'PROCESSED',
             processed_at_utc = UTC_TIMESTAMP(),
             process_error = NULL,
             updated_utc = UTC_TIMESTAMP()
         WHERE id = :eventId",
        {
          eventId = { value = arguments.eventId, cfsqltype = "cf_sql_bigint" }
        },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="markEventFailed" access="private" returntype="void" output="false">
    <cfargument name="eventId" type="numeric" required="true">
    <cfargument name="processError" type="string" required="true">
    <cfscript>
      queryExecute(
        "UPDATE floatplan_companion_events
         SET process_status = 'FAILED',
             processed_at_utc = UTC_TIMESTAMP(),
             process_error = :processError,
             updated_utc = UTC_TIMESTAMP()
         WHERE id = :eventId",
        {
          eventId = { value = arguments.eventId, cfsqltype = "cf_sql_bigint" },
          processError = { value = left(arguments.processError, 2000), cfsqltype = "cf_sql_longvarchar" }
        },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="normalizeStatus" access="private" returntype="string" output="false">
    <cfargument name="status" type="string" required="true">
    <cfscript>
      var allowed = [ "On Track", "Delayed", "Changed Plan", "Assistance Needed", "Secure for the Night" ];
      var i = 0;
      for (i = 1; i LTE arrayLen(allowed); i++) {
        if (compareNoCase(trim(arguments.status), allowed[i]) EQ 0) {
          return allowed[i];
        }
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="parseOptionalUtcDate" access="private" returntype="struct" output="false">
    <cfargument name="rawValue" type="string" required="true">
    <cfargument name="errorCode" type="string" required="true">
    <cfargument name="errorMessage" type="string" required="true">
    <cfscript>
      var raw = trim(arguments.rawValue);
      var normalized = "";

      if (!len(raw)) {
        return { "SUCCESS" = true, "success" = true, "value" = "" };
      }

      normalized = replace(raw, "T", " ", "one");
      normalized = reReplace(normalized, "Z$", "", "one");
      normalized = reReplace(normalized, "\.\d+", "", "one");
      normalized = reReplace(normalized, "([+-]\d{2}:\d{2})$", "", "one");

      if (!isDate(normalized)) {
        return errorResponse(arguments.errorCode, arguments.errorMessage, true);
      }

      return { "SUCCESS" = true, "success" = true, "value" = parseDateTime(normalized) };
    </cfscript>
  </cffunction>

  <cffunction name="canonicalErrorMessage" access="private" returntype="string" output="false">
    <cfargument name="canonicalResponse" type="struct" required="true">
    <cfscript>
      return left(serializeJSON(arguments.canonicalResponse), 2000);
    </cfscript>
  </cffunction>

    <cffunction name="isDuplicateKeyError" access="private" returntype="boolean" output="false">
      <cfargument name="error" type="any" required="true">
      <cfscript>
        var text = lCase(toString(
          (structKeyExists(arguments.error, "message") ? arguments.error.message : "")
          & " "
          & (structKeyExists(arguments.error, "detail") ? arguments.error.detail : "")
        ));
        return find("duplicate", text) GT 0 OR find("uq_companion_events_user_submission", text) GT 0;
      </cfscript>
    </cffunction>

  <cffunction name="errorResponse" access="private" returntype="struct" output="false">
    <cfargument name="errorCode" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfargument name="auth" type="boolean" required="false" default="true">
    <cfargument name="detail" type="string" required="false" default="">
    <cfscript>
      var response = {
        "SUCCESS" = false,
        "success" = false,
        "AUTH" = arguments.auth,
        "duplicate" = false,
        "eventId" = 0,
        "ERROR" = arguments.errorCode,
        "MESSAGE" = arguments.message
      };
      if (len(arguments.detail)) {
        response.DETAIL = arguments.detail;
      }
      return response;
    </cfscript>
  </cffunction>

  <cffunction name="createApiComponent" access="private" returntype="any" output="false">
    <cfargument name="componentName" type="string" required="true">
    <cfscript>
      try {
        return createObject("component", "fpw.api.v1." & arguments.componentName);
      } catch (any primaryError) {
        return createObject("component", "api.v1." & arguments.componentName);
      }
    </cfscript>
  </cffunction>

  <cffunction name="readStruct" access="private" returntype="struct" output="false">
    <cfargument name="source" type="any" required="true">
    <cfargument name="key" type="string" required="true">
    <cfscript>
      if (isStruct(arguments.source) AND structKeyExists(arguments.source, arguments.key) AND isStruct(arguments.source[arguments.key])) {
        return arguments.source[arguments.key];
      }
      return {};
    </cfscript>
  </cffunction>

  <cffunction name="readString" access="private" returntype="string" output="false">
    <cfargument name="source" type="any" required="true">
    <cfargument name="key" type="string" required="true">
    <cfargument name="fallback" type="string" required="false" default="">
    <cfscript>
      if (!isStruct(arguments.source) OR !structKeyExists(arguments.source, arguments.key) OR isNull(arguments.source[arguments.key])) {
        return arguments.fallback;
      }
      return trim(toString(arguments.source[arguments.key]));
    </cfscript>
  </cffunction>

  <cffunction name="readNumber" access="private" returntype="numeric" output="false">
    <cfargument name="source" type="any" required="true">
    <cfargument name="key" type="string" required="true">
    <cfargument name="fallback" type="numeric" required="false" default="0">
    <cfscript>
      if (!isStruct(arguments.source) OR !structKeyExists(arguments.source, arguments.key) OR isNull(arguments.source[arguments.key]) OR !isNumeric(arguments.source[arguments.key])) {
        return arguments.fallback;
      }
      return val(arguments.source[arguments.key]);
    </cfscript>
  </cffunction>

  <cffunction name="readBoolean" access="private" returntype="boolean" output="false">
    <cfargument name="source" type="any" required="true">
    <cfargument name="key" type="string" required="true">
    <cfargument name="fallback" type="boolean" required="false" default="false">
    <cfscript>
      if (!isStruct(arguments.source) OR !structKeyExists(arguments.source, arguments.key) OR isNull(arguments.source[arguments.key])) {
        return arguments.fallback;
      }
      if (isBoolean(arguments.source[arguments.key])) {
        return arguments.source[arguments.key];
      }
      if (isNumeric(arguments.source[arguments.key])) {
        return val(arguments.source[arguments.key]) NEQ 0;
      }
      return listFindNoCase("true,yes,y,on", trim(toString(arguments.source[arguments.key]))) GT 0;
    </cfscript>
  </cffunction>

  <cffunction name="firstNonEmpty" access="private" returntype="string" output="false">
    <cfargument name="values" type="array" required="true">
    <cfscript>
      var i = 0;
      var value = "";
      for (i = 1; i LTE arrayLen(arguments.values); i++) {
        value = trim(toString(arguments.values[i]));
        if (len(value)) {
          return value;
        }
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="isSuccessPayload" access="private" returntype="boolean" output="false">
    <cfargument name="payload" type="struct" required="true">
    <cfscript>
      if (structKeyExists(arguments.payload, "SUCCESS") AND arguments.payload.SUCCESS EQ true) {
        return true;
      }
      if (structKeyExists(arguments.payload, "success") AND arguments.payload.success EQ true) {
        return true;
      }
      return false;
    </cfscript>
  </cffunction>

  <cffunction name="isNumericValue" access="private" returntype="boolean" output="false">
    <cfargument name="source" type="struct" required="true">
    <cfargument name="key" type="string" required="true">
    <cfscript>
      return structKeyExists(arguments.source, arguments.key)
        AND len(trim(toString(arguments.source[arguments.key])))
        AND isNumeric(arguments.source[arguments.key]);
    </cfscript>
  </cffunction>

  <cffunction name="optionalNumber" access="private" returntype="numeric" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      return isNumeric(arguments.value) ? val(arguments.value) : 0;
    </cfscript>
  </cffunction>

</cfcomponent>
