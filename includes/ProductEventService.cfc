component output="false" {

  variables.datasource = "fpw";
  variables.eventDefinitions = {};
  variables.forcedFailureWarningLogged = false;
  variables.captureTestLogs = false;
  variables.testLogEntries = [];

  public any function init(string datasource="fpw", struct testOptions={}) output="false" {
    variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
    variables.eventDefinitions = buildEventDefinitions();
    variables.forcedFailureWarningLogged = false;
    variables.captureTestLogs = structKeyExists(arguments.testOptions, "logEntries")
      && isArray(arguments.testOptions.logEntries);
    variables.testLogEntries = variables.captureTestLogs
      ? arguments.testOptions.logEntries
      : [];
    return this;
  }

  public struct function validateForcedFailureConfiguration() output="false" {
    var config = resolveForcedFailureConfiguration();

    if (config.WARNING_REQUIRED && !variables.forcedFailureWarningLogged) {
      writeProductEventLog("warning", config.WARNING_MESSAGE);
      variables.forcedFailureWarningLogged = true;
    }

    return config;
  }

  public array function getCapturedTestLogs() output="false" {
    return variables.captureTestLogs ? duplicate(variables.testLogEntries) : [];
  }

  // Caller must hold the owned mutation lock and use the same datasource/transaction.
  // Unlike best-effort analytics, activity evidence is required for the save to commit.
  public void function recordRequiredMemberActivity(
    required numeric userId,
    required string eventName,
    required numeric entityId
  ) output="false" {
    var activityTypes = memberActivityTypes();
    var eventMetadata = {};
    var result = {};
    if (!structKeyExists(activityTypes, arguments.eventName)
      || compare(arguments.eventName, lCase(trim(arguments.eventName))) NEQ 0
      || arguments.userId LTE 0 || arguments.userId NEQ fix(arguments.userId)
      || arguments.entityId LTE 0 || arguments.entityId NEQ fix(arguments.entityId)) {
      throw(type="FPW.MemberActivity.Invalid", message="Saved activity could not be verified.");
    }
    if (listFind("vessel_created,shore_contact_created", arguments.eventName)) {
      eventMetadata = { creation_source = "member" };
    }
    try {
      result = recordEvent(
        userId = arguments.userId,
        eventName = arguments.eventName,
        entityType = activityTypes[arguments.eventName],
        entityId = arguments.entityId,
        eventSource = "member_api",
        metadata = eventMetadata,
        idempotencyKey = "member_activity:" & lCase(createUUID())
      );
      if (!structKeyExists(result, "SUCCESS") || !result.SUCCESS
        || !structKeyExists(result, "RECORDED") || !result.RECORDED) {
        throw(type="FPW.MemberActivity.Unconfirmed", message="Saved activity could not be verified.");
      }
    } catch (any err) {
      throw(type="FPW.MemberActivity.PersistenceFailed", message="Your change could not be saved. Please try again.");
    }
  }

  private struct function memberActivityTypes() output="false" {
    return {
      vessel_created = "vessel", vessel_updated = "vessel",
      shore_contact_created = "shore_contact", shore_contact_updated = "shore_contact",
      operator_created = "operator", operator_updated = "operator",
      passenger_created = "passenger", passenger_updated = "passenger",
      waypoint_created = "waypoint", waypoint_updated = "waypoint",
      user_route_created = "user_route", user_route_updated = "user_route",
      route_created = "route_instance", route_updated = "route_instance",
      route_segment_updated = "user_segment_override",
      float_plan_created = "float_plan", float_plan_updated = "float_plan"
    };
  }

  public struct function recordEvent(
    required numeric userId,
    required string eventName,
    required string entityType,
    required numeric entityId,
    required string eventSource,
    struct metadata={},
    string idempotencyKey="",
    string requestCorrelationId=""
  ) output="false" {
    var normalizedEventName = lCase(trim(arguments.eventName));
    var normalizedEntityType = lCase(trim(arguments.entityType));
    var normalizedEventSource = lCase(trim(arguments.eventSource));
    var normalizedRequestId = trim(arguments.requestCorrelationId);
    var validation = validateRecordRequest(
      userId = arguments.userId,
      eventName = normalizedEventName,
      entityType = normalizedEntityType,
      entityId = arguments.entityId,
      eventSource = normalizedEventSource,
      metadata = arguments.metadata,
      idempotencyKey = arguments.idempotencyKey,
      requestCorrelationId = normalizedRequestId
    );
    var eventUuid = "";
    var resolvedIdempotencyKey = "";
    var qStored = "";
    var forcedFailureConfig = {};

    if (!validation.SUCCESS) {
      logFailure(normalizedEventName, normalizedEventSource, validation.ERROR);
      return validation;
    }

    eventUuid = lCase(createUUID());
    resolvedIdempotencyKey = len(trim(arguments.idempotencyKey))
      ? trim(arguments.idempotencyKey)
      : normalizedEventName & ":generated:" & eventUuid;

    forcedFailureConfig = resolveForcedFailureConfiguration();
    if (forcedFailureConfig.ENABLED) {
      logForcedTestFailure(normalizedEventName, normalizedEventSource);
      throw(
        type = "FPW.ProductEvent.ForcedTestFailure",
        message = "Forced product-event failure for controlled staging validation."
      );
    }

    try {
      queryExecute(
        "INSERT INTO product_events (
           event_uuid,
           user_id,
           event_name,
           entity_type,
           entity_id,
           event_source,
           occurred_at_utc,
           request_correlation_id,
           metadata_json,
           created_at_utc,
           idempotency_key
         ) VALUES (
           :eventUuid,
           :userId,
           :eventName,
           :entityType,
           :entityId,
           :eventSource,
           UTC_TIMESTAMP(),
           :requestCorrelationId,
           :metadataJson,
           UTC_TIMESTAMP(),
           :idempotencyKey
         )
         ON DUPLICATE KEY UPDATE idempotency_key = VALUES(idempotency_key)",
        {
          eventUuid = { value = eventUuid, cfsqltype = "cf_sql_varchar" },
          userId = { value = fix(arguments.userId), cfsqltype = "cf_sql_integer" },
          eventName = { value = normalizedEventName, cfsqltype = "cf_sql_varchar" },
          entityType = { value = normalizedEntityType, cfsqltype = "cf_sql_varchar" },
          entityId = { value = fix(arguments.entityId), cfsqltype = "cf_sql_bigint" },
          eventSource = { value = normalizedEventSource, cfsqltype = "cf_sql_varchar" },
          requestCorrelationId = {
            value = normalizedRequestId,
            cfsqltype = "cf_sql_varchar",
            null = !len(normalizedRequestId)
          },
          metadataJson = {
            value = serializeJSON(validation.metadata),
            cfsqltype = "cf_sql_longvarchar"
          },
          idempotencyKey = { value = resolvedIdempotencyKey, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );

      qStored = queryExecute(
        "SELECT event_uuid
         FROM product_events
         WHERE idempotency_key = :idempotencyKey
         LIMIT 1",
        {
          idempotencyKey = { value = resolvedIdempotencyKey, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );

      if (qStored.recordCount NEQ 1) {
        logFailure(normalizedEventName, normalizedEventSource, "PRODUCT_EVENT_NOT_CONFIRMED");
        return failureResponse("PRODUCT_EVENT_NOT_CONFIRMED", "Product event persistence could not be confirmed.");
      }

      return {
        SUCCESS = true,
        RECORDED = compareNoCase(toString(qStored.event_uuid[1]), eventUuid) EQ 0,
        DUPLICATE = compareNoCase(toString(qStored.event_uuid[1]), eventUuid) NEQ 0
      };
    } catch (any err) {
      logFailure(normalizedEventName, normalizedEventSource, "PRODUCT_EVENT_PERSIST_FAILED");
      return failureResponse("PRODUCT_EVENT_PERSIST_FAILED", "Product event persistence failed.");
    }
  }

  public struct function getMemberEventHistory(
    required numeric userId,
    numeric maxRows=200
  ) output="false" {
    var safeLimit = min(max(fix(arguments.maxRows), 1), 500);
    var qHistory = "";
    var events = [];
    var rowIndex = 0;
    var metadataValue = {};

    if (arguments.userId LTE 0 OR arguments.userId NEQ fix(arguments.userId)) {
      return failureResponse("INVALID_USER_ID", "A positive integer user id is required.");
    }

    try {
      qHistory = queryExecute(
        "SELECT event_name, entity_type, event_source, occurred_at_utc, metadata_json
         FROM product_events
         WHERE user_id = :userId
         ORDER BY occurred_at_utc ASC, id ASC
         LIMIT :maxRows",
        {
          userId = { value = fix(arguments.userId), cfsqltype = "cf_sql_integer" },
          maxRows = { value = safeLimit, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );

      for (rowIndex = 1; rowIndex LTE qHistory.recordCount; rowIndex++) {
        metadataValue = deserializeMetadata(qHistory.metadata_json[rowIndex]);
        arrayAppend(events, {
          eventName = toString(qHistory.event_name[rowIndex]),
          entityType = toString(qHistory.entity_type[rowIndex]),
          eventSource = toString(qHistory.event_source[rowIndex]),
          occurredAtUtc = formatUtc(qHistory.occurred_at_utc[rowIndex]),
          metadata = metadataValue
        });
      }

      return {
        SUCCESS = true,
        EVENTS = events
      };
    } catch (any err) {
      logFailure("history", "service_read", "PRODUCT_EVENT_HISTORY_FAILED");
      return failureResponse("PRODUCT_EVENT_HISTORY_FAILED", "Product event history could not be loaded.");
    }
  }

  public struct function getAggregateCounts(
    required date startUtc,
    required date endUtc,
    string eventName=""
  ) output="false" {
    var normalizedEventName = lCase(trim(arguments.eventName));
    var sqlText = "SELECT event_name, DATE(occurred_at_utc) AS event_date, COUNT(*) AS event_count
                   FROM product_events
                   WHERE occurred_at_utc >= :startUtc
                     AND occurred_at_utc <= :endUtc";
    var params = {
      startUtc = { value = arguments.startUtc, cfsqltype = "cf_sql_timestamp" },
      endUtc = { value = arguments.endUtc, cfsqltype = "cf_sql_timestamp" }
    };
    var qCounts = "";
    var counts = [];
    var rowIndex = 0;

    if (dateCompare(arguments.startUtc, arguments.endUtc) GT 0) {
      return failureResponse("INVALID_DATE_RANGE", "The UTC start must not be after the UTC end.");
    }
    if (len(normalizedEventName) AND !structKeyExists(variables.eventDefinitions, normalizedEventName)) {
      return failureResponse("UNKNOWN_EVENT_NAME", "The product event name is not supported.");
    }

    if (len(normalizedEventName)) {
      sqlText &= " AND event_name = :eventName";
      params.eventName = { value = normalizedEventName, cfsqltype = "cf_sql_varchar" };
    }
    sqlText &= " GROUP BY event_name, DATE(occurred_at_utc)
                 ORDER BY event_date ASC, event_name ASC";

    try {
      qCounts = queryExecute(sqlText, params, { datasource = variables.datasource });
      for (rowIndex = 1; rowIndex LTE qCounts.recordCount; rowIndex++) {
        arrayAppend(counts, {
          eventName = toString(qCounts.event_name[rowIndex]),
          eventDate = dateFormat(qCounts.event_date[rowIndex], "yyyy-mm-dd"),
          eventCount = val(qCounts.event_count[rowIndex])
        });
      }
      return {
        SUCCESS = true,
        COUNTS = counts
      };
    } catch (any err) {
      logFailure(
        len(normalizedEventName) ? normalizedEventName : "aggregate",
        "service_read",
        "PRODUCT_EVENT_AGGREGATE_FAILED"
      );
      return failureResponse("PRODUCT_EVENT_AGGREGATE_FAILED", "Product event aggregates could not be loaded.");
    }
  }

  private struct function buildEventDefinitions() output="false" {
    var definitions = {};

    definitions["sign_up"] = {
      entityType = "user",
      eventSources = [ "member_signup" ],
      metadata = {
        signup_method = [ "password" ],
        account_tier = [ "basic" ],
        onboarding_model = [ "legacy_trial", "premium_send_credit" ],
        complimentary_premium_send_credit = [ "true", "false" ],
        landing_key = [ "boat_fuel_calculator", "great_loop_locks" ],
        source_content_type = [ "seo_tool", "seo_hub" ],
        cta_type = [ "plan_route" ]
      }
    };
    definitions["complimentary_credit_granted"] = {
      entityType = "user",
      eventSources = [ "member_signup" ],
      metadata = {
        credit_source = [ "complimentary_signup" ]
      }
    };
    definitions["premium_send_attempted"] = {
      entityType = "float_plan",
      eventSources = [ "premium_save_send" ],
      metadata = {}
    };
    definitions["premium_send_completed"] = {
      entityType = "float_plan",
      eventSources = [ "premium_save_send" ],
      metadata = {
        premium_authority = [ "general_premium", "complimentary_signup", "stripe_one_trip", "promotion", "admin_grant" ]
      }
    };
    definitions["premium_send_denied_no_access"] = {
      entityType = "float_plan",
      eventSources = [ "premium_save_send" ],
      metadata = {}
    };
    definitions["basic_send_completed"] = {
      entityType = "float_plan",
      eventSources = [ "basic_save_send", "basic_review_send" ],
      metadata = {}
    };
    definitions["buy_one_trip_clicked"] = {
      entityType = "user",
      eventSources = [ "billing_api" ],
      metadata = {}
    };
    definitions["one_trip_checkout_created"] = {
      entityType = "user",
      eventSources = [ "billing_api" ],
      metadata = {}
    };
    definitions["one_trip_credit_granted"] = {
      entityType = "user",
      eventSources = [ "stripe_webhook" ],
      metadata = {
        credit_source = [ "stripe_one_trip" ]
      }
    };
    definitions["same_plan_retry_resolved"] = {
      entityType = "float_plan",
      eventSources = [ "premium_save_send" ],
      metadata = {}
    };
    definitions["monthly_selected"] = {
      entityType = "user",
      eventSources = [ "billing_api" ],
      metadata = {}
    };
    definitions["annual_selected"] = {
      entityType = "user",
      eventSources = [ "billing_api" ],
      metadata = {}
    };
    definitions["login"] = {
      entityType = "user",
      eventSources = [ "password_auth" ],
      metadata = {
        auth_method = [ "password" ]
      }
    };
    definitions["vessel_created"] = {
      entityType = "vessel",
      eventSources = [ "member_api" ],
      metadata = {
        creation_source = [ "member" ],
        is_first = [ "true", "false" ]
      }
    };
    definitions["shore_contact_created"] = {
      entityType = "shore_contact",
      eventSources = [ "member_api" ],
      metadata = {
        creation_source = [ "member" ],
        is_first = [ "true", "false" ]
      }
    };

    var activityTypes = memberActivityTypes();
    for (var activityName in activityTypes) {
      if (!structKeyExists(definitions, activityName)) {
        definitions[activityName] = {
          entityType = activityTypes[activityName],
          eventSources = [ "member_api" ],
          metadata = {}
        };
      }
    }
    return definitions;
  }

  private struct function validateRecordRequest(
    required numeric userId,
    required string eventName,
    required string entityType,
    required numeric entityId,
    required string eventSource,
    required struct metadata,
    required string idempotencyKey,
    required string requestCorrelationId
  ) output="false" {
    var definition = {};
    var sanitizedMetadata = {};
    var metadataKey = "";
    var normalizedKey = "";
    var normalizedValue = "";
    var allowedValues = [];

    if (!structKeyExists(variables.eventDefinitions, arguments.eventName)) {
      return failureResponse("UNKNOWN_EVENT_NAME", "The product event name is not supported.");
    }
    if (arguments.userId LTE 0 OR arguments.userId NEQ fix(arguments.userId)) {
      return failureResponse("INVALID_USER_ID", "A positive integer user id is required.");
    }
    if (arguments.entityId LTE 0 OR arguments.entityId NEQ fix(arguments.entityId)) {
      return failureResponse("INVALID_ENTITY_ID", "A positive integer entity id is required.");
    }

    definition = variables.eventDefinitions[arguments.eventName];
    if (compareNoCase(arguments.entityType, definition.entityType) NEQ 0) {
      return failureResponse("INVALID_ENTITY_TYPE", "The entity type is not valid for this event.");
    }
    if (!arrayContainsNoCase(definition.eventSources, arguments.eventSource)) {
      return failureResponse("INVALID_EVENT_SOURCE", "The event source is not valid for this event.");
    }

    if (len(trim(arguments.idempotencyKey))) {
      if (len(trim(arguments.idempotencyKey)) GT 191 OR !reFind("^[A-Za-z0-9:_-]+$", trim(arguments.idempotencyKey))) {
        return failureResponse("INVALID_IDEMPOTENCY_KEY", "The internal idempotency key is invalid.");
      }
    }
    if (len(arguments.requestCorrelationId)) {
      if (len(arguments.requestCorrelationId) GT 64 OR !reFind("^[A-Za-z0-9-]+$", arguments.requestCorrelationId)) {
        return failureResponse("INVALID_REQUEST_CORRELATION_ID", "The request correlation id is invalid.");
      }
    }

    for (metadataKey in arguments.metadata) {
      normalizedKey = lCase(trim(toString(metadataKey)));
      if (!structKeyExists(definition.metadata, normalizedKey)) {
        return failureResponse("DISALLOWED_METADATA_KEY", "The metadata key is not allowed for this event.");
      }
      if (!isSimpleValue(arguments.metadata[metadataKey])) {
        return failureResponse("INVALID_METADATA_VALUE", "Metadata values must be simple allow-listed values.");
      }

      normalizedValue = lCase(trim(toString(arguments.metadata[metadataKey])));
      allowedValues = definition.metadata[normalizedKey];
      if (!arrayContainsNoCase(allowedValues, normalizedValue)) {
        return failureResponse("DISALLOWED_METADATA_VALUE", "The metadata value is not allowed for this event.");
      }

      if (listFindNoCase("is_first,complimentary_premium_send_credit", normalizedKey)) {
        sanitizedMetadata[normalizedKey] = normalizedValue EQ "true";
      } else {
        sanitizedMetadata[normalizedKey] = normalizedValue;
      }
    }

    if (len(serializeJSON(sanitizedMetadata)) GT 1000) {
      return failureResponse("METADATA_TOO_LARGE", "Product event metadata is too large.");
    }

    return {
      SUCCESS = true,
      metadata = sanitizedMetadata
    };
  }

  private boolean function arrayContainsNoCase(required array values, required string candidate) output="false" {
    var item = "";
    for (item in arguments.values) {
      if (compareNoCase(toString(item), arguments.candidate) EQ 0) {
        return true;
      }
    }
    return false;
  }

  private struct function deserializeMetadata(any rawValue="") output="false" {
    if (isNull(arguments.rawValue) OR !len(trim(toString(arguments.rawValue)))) {
      return {};
    }
    try {
      var parsed = deserializeJSON(toString(arguments.rawValue), false);
      return isStruct(parsed) ? parsed : {};
    } catch (any err) {
      return {};
    }
  }

  private string function formatUtc(required any value) output="false" {
    if (!isDate(arguments.value)) {
      return "";
    }
    return dateTimeFormat(arguments.value, "yyyy-mm-dd'T'HH:nn:ss") & "Z";
  }

  private struct function resolveForcedFailureConfiguration() output="false" {
    var environment = "";
    var settingValue = "";
    var requested = false;
    var allowedEnvironment = false;

    if (isDefined("application") && structKeyExists(application, "env")) {
      environment = lCase(trim(toString(application.env)));
    }
    if (
      isDefined("application")
      && structKeyExists(application, "settings")
      && isStruct(application.settings)
      && structKeyExists(application.settings, "FPW_PRODUCT_EVENTS_FORCE_FAILURE")
      && !isNull(application.settings.FPW_PRODUCT_EVENTS_FORCE_FAILURE)
    ) {
      settingValue = trim(toString(application.settings.FPW_PRODUCT_EVENTS_FORCE_FAILURE));
    }

    requested = compare(settingValue, "true") EQ 0;
    allowedEnvironment = listFind("dev,staging", environment) GT 0;

    return {
      REQUESTED = requested,
      ENABLED = requested && allowedEnvironment,
      WARNING_REQUIRED = requested && !allowedEnvironment,
      WARNING_MESSAGE = "ProductEventService FORCED_TEST_FAILURE_DISABLED | reason=environment_not_allowed"
    };
  }

  private void function logForcedTestFailure(
    required string eventName,
    required string eventSource
  ) output="false" {
    var safeEventName = left(reReplace(arguments.eventName, "[^A-Za-z0-9_-]", "", "all"), 64);
    var safeEventSource = left(reReplace(arguments.eventSource, "[^A-Za-z0-9_-]", "", "all"), 64);

    writeProductEventLog(
      "error",
      "ProductEventService FORCED_TEST_FAILURE"
        & " | event=" & safeEventName
        & " | source=" & safeEventSource
        & " | type=FPW.ProductEvent.ForcedTestFailure"
        & " | message=Forced product-event failure for controlled staging validation."
    );
  }

  private void function writeProductEventLog(
    required string logType,
    required string logText
  ) output="false" {
    writeLog(
      file = "fpw_product_events",
      type = arguments.logType,
      text = arguments.logText
    );

    if (variables.captureTestLogs) {
      try {
        arrayAppend(variables.testLogEntries, {
          file = "fpw_product_events",
          type = arguments.logType,
          text = arguments.logText
        });
      } catch (any testLogCaptureError) {
      }
    }
  }

  private void function logFailure(
    required string eventName,
    required string eventSource,
    required string errorCode
  ) output="false" {
    var safeEventName = left(reReplace(arguments.eventName, "[^A-Za-z0-9_-]", "", "all"), 64);
    var safeEventSource = left(reReplace(arguments.eventSource, "[^A-Za-z0-9_-]", "", "all"), 64);
    var safeErrorCode = left(reReplace(arguments.errorCode, "[^A-Za-z0-9_-]", "", "all"), 80);

    writeProductEventLog(
      "error",
      "ProductEventService RECORD_FAILED | event=" & safeEventName
        & " | source=" & safeEventSource
        & " | error=" & safeErrorCode
    );
  }

  private struct function failureResponse(
    required string errorCode,
    required string message
  ) output="false" {
    return {
      SUCCESS = false,
      RECORDED = false,
      DUPLICATE = false,
      ERROR = arguments.errorCode,
      MESSAGE = arguments.message
    };
  }

}
