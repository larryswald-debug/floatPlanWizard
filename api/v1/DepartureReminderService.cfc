component output="false" {

  variables.datasource = "fpw";
  variables.emailService = 0;
  variables.dueWindowMinutes = 30;
  variables.maxAttempts = 3;

  public any function init(
    string datasource="fpw",
    any emailService=""
  ) output=false {
    variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
    variables.emailService = isObject(arguments.emailService)
      ? arguments.emailService
      : createEmailService();
    return this;
  }

  public struct function processDueReminders(numeric limit=100) output=false {
    var batchLimit = min(500, max(1, fix(arguments.limit)));
    var qCandidates = loadDueCandidates(batchLimit);
    var result = {
      SUCCESS = true,
      examined = 0,
      claimed = 0,
      sent = 0,
      failed = 0,
      skipped = 0,
      float_plan_ids = []
    };
    var index = 0;
    var candidate = {};
    var validation = {};
    var claim = {};
    var emailResult = {};

    for (index = 1; index LTE qCandidates.recordCount; index++) {
      result.examined++;
      candidate = mapCandidate(qCandidates, index);
      validation = validateCandidateForReminder(
        candidate = candidate,
        reminderType = candidate.reminderType,
        currentUtc = candidate.currentUtc
      );
      if (!validation.ELIGIBLE) {
        result.skipped++;
        continue;
      }

      claim = claimOccurrence(candidate);
      if (!claim.SUCCESS OR !claim.CLAIMED) {
        result.skipped++;
        continue;
      }
      result.claimed++;

      emailResult = sendReminderEmail(claim.CANDIDATE);
      if (!structKeyExists(emailResult, "success") OR emailResult.success NEQ true) {
        result.failed++;
        markFailed(
          deliveryId = claim.DELIVERY_ID,
          errorSummary = structKeyExists(emailResult, "errorCode")
            ? toString(emailResult.errorCode)
            : "EMAIL_SEND_FAILED"
        );
        continue;
      }

      try {
        markSent(claim.DELIVERY_ID);
        result.sent++;
        arrayAppend(result.float_plan_ids, claim.CANDIDATE.floatPlanId);
      } catch (any markSentErr) {
        // Leave the delivery CLAIMED after SMTP acceptance. Reclaiming it could duplicate mail.
        result.failed++;
        writeLog(
          file = "fpw-departure-reminders",
          type = "error",
          text = "DEPARTURE_REMINDER_MARK_SENT_FAILED delivery_id=" & claim.DELIVERY_ID
        );
      }
    }

    result.SUCCESS = result.failed EQ 0;
    return result;
  }

  public array function determineDueReminderTypes(
    required date departureUtc,
    required date currentUtc
  ) output=false {
    var dueTypes = [];
    var preStart = dateAdd("h", -2, arguments.departureUtc);
    var preEnd = dateAdd("n", variables.dueWindowMinutes, preStart);
    var notStartedStart = dateAdd("n", 30, arguments.departureUtc);
    var notStartedEnd = dateAdd("n", variables.dueWindowMinutes, notStartedStart);

    if (
      dateCompare(arguments.currentUtc, preStart, "s") GTE 0
      AND dateCompare(arguments.currentUtc, preEnd, "s") LT 0
    ) {
      arrayAppend(dueTypes, "PRE_DEPARTURE");
    }
    if (
      dateCompare(arguments.currentUtc, notStartedStart, "s") GTE 0
      AND dateCompare(arguments.currentUtc, notStartedEnd, "s") LT 0
    ) {
      arrayAppend(dueTypes, "NOT_STARTED");
    }
    return dueTypes;
  }

  public struct function validateCandidateForReminder(
    required struct candidate,
    required string reminderType,
    required date currentUtc
  ) output=false {
    var reminderTypeValue = uCase(trim(arguments.reminderType));
    var timezoneValue = "";
    var dueTypes = [];

    if (!listFindNoCase("PRE_DEPARTURE,NOT_STARTED", reminderTypeValue)) {
      return ineligible("INVALID_REMINDER_TYPE");
    }
    if (!structKeyExists(arguments.candidate, "floatPlanId") OR val(arguments.candidate.floatPlanId) LTE 0) {
      return ineligible("INVALID_FLOAT_PLAN");
    }
    if (!structKeyExists(arguments.candidate, "userId") OR val(arguments.candidate.userId) LTE 0) {
      return ineligible("MISSING_OWNER");
    }
    if (!structKeyExists(arguments.candidate, "ownerEmail") OR !isValid("email", trim(toString(arguments.candidate.ownerEmail)))) {
      return ineligible("INVALID_OWNER_EMAIL");
    }
    if (!structKeyExists(arguments.candidate, "routeInstanceId") OR val(arguments.candidate.routeInstanceId) LTE 0) {
      return ineligible("MISSING_ROUTE_INSTANCE");
    }
    if (!structKeyExists(arguments.candidate, "departureTimeUtc") OR !isDate(arguments.candidate.departureTimeUtc)) {
      return ineligible("MISSING_SCHEDULED_UTC");
    }
    timezoneValue = normalizeDepartureTimezone(
      structKeyExists(arguments.candidate, "departureTimezone")
        ? toString(arguments.candidate.departureTimezone)
        : ""
    );
    if (!len(timezoneValue)) {
      return ineligible("INVALID_DEPARTURE_TIMEZONE");
    }
    if (
      !structKeyExists(arguments.candidate, "planStatus")
      OR uCase(trim(toString(arguments.candidate.planStatus))) NEQ "ACTIVE"
    ) {
      return ineligible("PLAN_NOT_ACTIVE");
    }
    if (hasDateValue(arguments.candidate, "closedAt")) {
      return ineligible("PLAN_CLOSED");
    }
    if (hasDateValue(arguments.candidate, "expiredAt")) {
      return ineligible("PLAN_EXPIRED");
    }
    if (hasDateValue(arguments.candidate, "startedAt")) {
      return ineligible("TRIP_ALREADY_STARTED");
    }
    if (
      structKeyExists(arguments.candidate, "routeProgressStarted")
      AND toBoolean(arguments.candidate.routeProgressStarted)
    ) {
      return ineligible("ROUTE_PROGRESS_ALREADY_STARTED");
    }
    if (
      hasDateValue(arguments.candidate, "completedAt")
      OR (
        structKeyExists(arguments.candidate, "routeStatus")
        AND uCase(trim(toString(arguments.candidate.routeStatus))) EQ "COMPLETED"
      )
    ) {
      return ineligible("ROUTE_COMPLETED");
    }

    dueTypes = determineDueReminderTypes(arguments.candidate.departureTimeUtc, arguments.currentUtc);
    if (!arrayFindNoCase(dueTypes, reminderTypeValue)) {
      return ineligible("OUTSIDE_DUE_WINDOW");
    }

    return {
      ELIGIBLE = true,
      REASON = "ELIGIBLE",
      REMINDER_TYPE = reminderTypeValue,
      DEPARTURE_TIMEZONE = timezoneValue
    };
  }

  public string function buildOccurrenceKey(
    required numeric floatPlanId,
    required string reminderType,
    required string scheduledDepartureUtcKey
  ) output=false {
    var identity = int(arguments.floatPlanId)
      & "|" & uCase(trim(arguments.reminderType))
      & "|" & trim(arguments.scheduledDepartureUtcKey);
    return lCase(hash(identity, "SHA-256"));
  }

  public struct function resolveClaimState(
    required boolean wasInserted,
    required string existingStatus,
    required numeric attemptCount
  ) output=false {
    var statusValue = uCase(trim(arguments.existingStatus));
    if (arguments.wasInserted) {
      return { CLAIMED = true, RETRY = false, REASON = "NEW_CLAIM" };
    }
    if (statusValue EQ "FAILED" AND int(arguments.attemptCount) LT variables.maxAttempts) {
      return { CLAIMED = true, RETRY = true, REASON = "FAILED_RETRY" };
    }
    if (statusValue EQ "SENT") {
      return { CLAIMED = false, RETRY = false, REASON = "ALREADY_SENT" };
    }
    if (statusValue EQ "CLAIMED") {
      return { CLAIMED = false, RETRY = false, REASON = "ALREADY_CLAIMED" };
    }
    return { CLAIMED = false, RETRY = false, REASON = "NOT_RETRIABLE" };
  }

  public string function normalizeDepartureTimezone(required string timezone) output=false {
    var timezoneValue = trim(arguments.timezone);
    switch (uCase(timezoneValue)) {
      case "US/EASTERN": return "America/New_York";
      case "US/CENTRAL": return "America/Chicago";
      case "US/MOUNTAIN": return "America/Denver";
      case "US/PACIFIC": return "America/Los_Angeles";
      case "US/ALASKA": return "America/Anchorage";
      case "US/HAWAII": return "Pacific/Honolulu";
      case "+00:00":
      case "UTC":
      case "ETC/UTC":
      case "GMT":
        return "UTC";
    }
    if (!len(timezoneValue)) {
      return "";
    }
    try {
      dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss", timezoneValue);
      return timezoneValue;
    } catch (any invalidTimezoneErr) {
      return "";
    }
  }

  public string function formatScheduledDeparture(
    required string scheduledDepartureUtcKey,
    required string timezone
  ) output=false {
    var timezoneValue = normalizeDepartureTimezone(arguments.timezone);
    var utcValue = "";
    if (!len(trim(arguments.scheduledDepartureUtcKey)) OR !len(timezoneValue)) {
      return "";
    }
    try {
      utcValue = parseDateTime(replace(trim(arguments.scheduledDepartureUtcKey), " ", "T", "one") & "Z");
      return dateTimeFormat(utcValue, "mmm d, yyyy h:nn tt", timezoneValue);
    } catch (any formatDepartureErr) {
      return "";
    }
  }

  private query function loadDueCandidates(required numeric batchLimit) output=false {
    var limitValue = min(500, max(1, fix(arguments.batchLimit)));
    return queryExecute(
      "SELECT
         fp.floatPlanId AS float_plan_id,
         CAST(TRIM(fp.userId) AS UNSIGNED) AS user_id,
         fp.floatPlanName AS float_plan_name,
         fp.`status` AS plan_status,
         fp.closedAt AS closed_at,
         fp.expiredAt AS expired_at,
         fp.route_instance_id,
         fp.departureTimeUTC AS departure_time_utc,
         DATE_FORMAT(fp.departureTimeUTC, '%Y-%m-%d %H:%i:%s') AS departure_time_utc_key,
         COALESCE(NULLIF(TRIM(fp.departureTZ), ''), NULLIF(TRIM(fp.departTimezone), '')) AS departure_timezone,
         u.email AS owner_email,
         ri.`status` AS route_status,
         ri.started_at,
         ri.completed_at,
         UTC_TIMESTAMP(6) AS current_utc,
         CASE
           WHEN UTC_TIMESTAMP(6) >= DATE_SUB(fp.departureTimeUTC, INTERVAL 2 HOUR)
            AND UTC_TIMESTAMP(6) < DATE_ADD(DATE_SUB(fp.departureTimeUTC, INTERVAL 2 HOUR), INTERVAL 30 MINUTE)
           THEN 'PRE_DEPARTURE'
           ELSE 'NOT_STARTED'
         END AS reminder_type
       FROM floatplans fp
       INNER JOIN route_instances ri
         ON ri.id = fp.route_instance_id
        AND TRIM(ri.user_id) = TRIM(fp.userId)
       INNER JOIN users u
         ON CAST(u.userId AS CHAR) = TRIM(fp.userId)
       WHERE UPPER(TRIM(COALESCE(fp.`status`, ''))) = 'ACTIVE'
         AND fp.departureTimeUTC IS NOT NULL
         AND COALESCE(NULLIF(TRIM(fp.departureTZ), ''), NULLIF(TRIM(fp.departTimezone), '')) IS NOT NULL
         AND fp.closedAt IS NULL
         AND fp.expiredAt IS NULL
         AND fp.route_instance_id IS NOT NULL
         AND fp.route_instance_id > 0
         AND ri.started_at IS NULL
         AND ri.completed_at IS NULL
         AND UPPER(TRIM(COALESCE(ri.`status`, ''))) <> 'COMPLETED'
         AND NOT EXISTS (
           SELECT 1
           FROM route_instance_leg_progress rilp
           WHERE rilp.route_instance_id = fp.route_instance_id
             AND TRIM(rilp.user_id) = TRIM(fp.userId)
             AND (
               rilp.leg_started_at IS NOT NULL
               OR rilp.completed_at IS NOT NULL
               OR UPPER(TRIM(COALESCE(rilp.status, ''))) IN ('STARTED','IN_PROGRESS','COMPLETED')
             )
         )
         AND (
           (
             UTC_TIMESTAMP(6) >= DATE_SUB(fp.departureTimeUTC, INTERVAL 2 HOUR)
             AND UTC_TIMESTAMP(6) < DATE_ADD(DATE_SUB(fp.departureTimeUTC, INTERVAL 2 HOUR), INTERVAL 30 MINUTE)
             AND NOT EXISTS (
               SELECT 1
               FROM departure_reminder_deliveries drd
               WHERE drd.float_plan_id = fp.floatPlanId
                 AND drd.reminder_type = 'PRE_DEPARTURE'
                 AND drd.scheduled_departure_at_utc = fp.departureTimeUTC
                 AND (
                   drd.status IN ('CLAIMED','SENT')
                   OR (drd.status = 'FAILED' AND drd.attempt_count >= 3)
                 )
             )
           )
           OR
           (
             UTC_TIMESTAMP(6) >= DATE_ADD(fp.departureTimeUTC, INTERVAL 30 MINUTE)
             AND UTC_TIMESTAMP(6) < DATE_ADD(fp.departureTimeUTC, INTERVAL 60 MINUTE)
             AND NOT EXISTS (
               SELECT 1
               FROM departure_reminder_deliveries drd
               WHERE drd.float_plan_id = fp.floatPlanId
                 AND drd.reminder_type = 'NOT_STARTED'
                 AND drd.scheduled_departure_at_utc = fp.departureTimeUTC
                 AND (
                   drd.status IN ('CLAIMED','SENT')
                   OR (drd.status = 'FAILED' AND drd.attempt_count >= 3)
                 )
             )
           )
         )
       ORDER BY departure_time_utc ASC, float_plan_id ASC
       LIMIT #limitValue#",
      {},
      { datasource = variables.datasource }
    );
  }

  private struct function mapCandidate(required query source, required numeric rowIndex) output=false {
    var row = arguments.rowIndex;
    return {
      floatPlanId = val(arguments.source.float_plan_id[row]),
      userId = val(arguments.source.user_id[row]),
      floatPlanName = isNull(arguments.source.float_plan_name[row]) ? "" : trim(toString(arguments.source.float_plan_name[row])),
      planStatus = isNull(arguments.source.plan_status[row]) ? "" : trim(toString(arguments.source.plan_status[row])),
      closedAt = isNull(arguments.source.closed_at[row]) ? "" : arguments.source.closed_at[row],
      expiredAt = isNull(arguments.source.expired_at[row]) ? "" : arguments.source.expired_at[row],
      routeInstanceId = val(arguments.source.route_instance_id[row]),
      departureTimeUtc = arguments.source.departure_time_utc[row],
      scheduledDepartureUtcKey = trim(toString(arguments.source.departure_time_utc_key[row])),
      departureTimezone = isNull(arguments.source.departure_timezone[row]) ? "" : trim(toString(arguments.source.departure_timezone[row])),
      ownerEmail = isNull(arguments.source.owner_email[row]) ? "" : lCase(trim(toString(arguments.source.owner_email[row]))),
      routeStatus = isNull(arguments.source.route_status[row]) ? "" : trim(toString(arguments.source.route_status[row])),
      startedAt = isNull(arguments.source.started_at[row]) ? "" : arguments.source.started_at[row],
      completedAt = isNull(arguments.source.completed_at[row]) ? "" : arguments.source.completed_at[row],
      routeProgressStarted = false,
      currentUtc = arguments.source.current_utc[row],
      reminderType = uCase(trim(toString(arguments.source.reminder_type[row])))
    };
  }

  private struct function claimOccurrence(required struct candidate) output=false {
    var qLocked = queryNew("");
    var qInsertCount = queryNew("");
    var qDelivery = queryNew("");
    var lockedCandidate = {};
    var validation = {};
    var occurrenceKey = "";
    var wasInserted = false;
    var claimDecision = {};

    transaction {
      qLocked = queryExecute(
        "SELECT
           fp.floatPlanId AS float_plan_id,
           CAST(TRIM(fp.userId) AS UNSIGNED) AS user_id,
           fp.floatPlanName AS float_plan_name,
           fp.`status` AS plan_status,
           fp.closedAt AS closed_at,
           fp.expiredAt AS expired_at,
           fp.route_instance_id,
           fp.departureTimeUTC AS departure_time_utc,
           DATE_FORMAT(fp.departureTimeUTC, '%Y-%m-%d %H:%i:%s') AS departure_time_utc_key,
           COALESCE(NULLIF(TRIM(fp.departureTZ), ''), NULLIF(TRIM(fp.departTimezone), '')) AS departure_timezone,
           u.email AS owner_email,
           ri.`status` AS route_status,
           ri.started_at,
           ri.completed_at,
           UTC_TIMESTAMP(6) AS current_utc,
           :reminderType AS reminder_type
         FROM floatplans fp
         INNER JOIN route_instances ri
           ON ri.id = fp.route_instance_id
          AND TRIM(ri.user_id) = TRIM(fp.userId)
         INNER JOIN users u
           ON CAST(u.userId AS CHAR) = TRIM(fp.userId)
         WHERE fp.floatPlanId = :floatPlanId
           AND fp.route_instance_id = :routeInstanceId
           AND DATE_FORMAT(fp.departureTimeUTC, '%Y-%m-%d %H:%i:%s') = :departureUtcKey
           AND UPPER(TRIM(COALESCE(fp.`status`, ''))) = 'ACTIVE'
           AND fp.closedAt IS NULL
           AND fp.expiredAt IS NULL
           AND ri.started_at IS NULL
           AND ri.completed_at IS NULL
           AND UPPER(TRIM(COALESCE(ri.`status`, ''))) <> 'COMPLETED'
           AND NOT EXISTS (
             SELECT 1
             FROM route_instance_leg_progress rilp
             WHERE rilp.route_instance_id = fp.route_instance_id
               AND TRIM(rilp.user_id) = TRIM(fp.userId)
               AND (
                 rilp.leg_started_at IS NOT NULL
                 OR rilp.completed_at IS NOT NULL
                 OR UPPER(TRIM(COALESCE(rilp.status, ''))) IN ('STARTED','IN_PROGRESS','COMPLETED')
               )
           )
         LIMIT 1
         FOR UPDATE",
        {
          reminderType = { value = arguments.candidate.reminderType, cfsqltype = "cf_sql_varchar" },
          floatPlanId = { value = arguments.candidate.floatPlanId, cfsqltype = "cf_sql_integer" },
          routeInstanceId = { value = arguments.candidate.routeInstanceId, cfsqltype = "cf_sql_integer" },
          departureUtcKey = { value = arguments.candidate.scheduledDepartureUtcKey, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );

      if (qLocked.recordCount NEQ 1) {
        return { SUCCESS = true, CLAIMED = false, REASON = "NO_LONGER_ELIGIBLE" };
      }

      lockedCandidate = mapCandidate(qLocked, 1);
      validation = validateCandidateForReminder(
        candidate = lockedCandidate,
        reminderType = lockedCandidate.reminderType,
        currentUtc = lockedCandidate.currentUtc
      );
      if (!validation.ELIGIBLE) {
        return { SUCCESS = true, CLAIMED = false, REASON = validation.REASON };
      }

      lockedCandidate.departureTimezone = validation.DEPARTURE_TIMEZONE;
      lockedCandidate.scheduledDepartureLabel = formatScheduledDeparture(
        lockedCandidate.scheduledDepartureUtcKey,
        lockedCandidate.departureTimezone
      );
      if (!len(lockedCandidate.scheduledDepartureLabel)) {
        return { SUCCESS = true, CLAIMED = false, REASON = "INVALID_DEPARTURE_DISPLAY" };
      }

      occurrenceKey = buildOccurrenceKey(
        lockedCandidate.floatPlanId,
        lockedCandidate.reminderType,
        lockedCandidate.scheduledDepartureUtcKey
      );

      queryExecute(
        "INSERT IGNORE INTO departure_reminder_deliveries (
           float_plan_id,
           reminder_type,
           scheduled_departure_at_utc,
           occurrence_key,
           status,
           claimed_at_utc,
           sent_at_utc,
           failed_at_utc,
           attempt_count,
           last_error_summary,
           created_at_utc,
           updated_at_utc
         ) VALUES (
           :floatPlanId,
           :reminderType,
           :scheduledDepartureUtc,
           :occurrenceKey,
           'CLAIMED',
           UTC_TIMESTAMP(6),
           NULL,
           NULL,
           1,
           NULL,
           UTC_TIMESTAMP(6),
           UTC_TIMESTAMP(6)
         )",
        {
          floatPlanId = { value = lockedCandidate.floatPlanId, cfsqltype = "cf_sql_integer" },
          reminderType = { value = lockedCandidate.reminderType, cfsqltype = "cf_sql_varchar" },
          scheduledDepartureUtc = { value = lockedCandidate.departureTimeUtc, cfsqltype = "cf_sql_timestamp" },
          occurrenceKey = { value = occurrenceKey, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
      qInsertCount = queryExecute(
        "SELECT ROW_COUNT() AS inserted_count",
        {},
        { datasource = variables.datasource }
      );
      wasInserted = qInsertCount.recordCount EQ 1 AND val(qInsertCount.inserted_count[1]) EQ 1;

      qDelivery = queryExecute(
        "SELECT id, status, attempt_count
         FROM departure_reminder_deliveries
         WHERE occurrence_key = :occurrenceKey
         LIMIT 1
         FOR UPDATE",
        { occurrenceKey = { value = occurrenceKey, cfsqltype = "cf_sql_varchar" } },
        { datasource = variables.datasource }
      );
      if (qDelivery.recordCount NEQ 1) {
        return { SUCCESS = false, CLAIMED = false, REASON = "CLAIM_NOT_FOUND" };
      }

      claimDecision = resolveClaimState(
        wasInserted,
        toString(qDelivery.status[1]),
        val(qDelivery.attempt_count[1])
      );
      if (claimDecision.RETRY) {
        queryExecute(
          "UPDATE departure_reminder_deliveries
           SET status = 'CLAIMED',
               claimed_at_utc = UTC_TIMESTAMP(6),
               sent_at_utc = NULL,
               failed_at_utc = NULL,
               attempt_count = attempt_count + 1,
               last_error_summary = NULL,
               updated_at_utc = UTC_TIMESTAMP(6)
           WHERE id = :deliveryId
             AND status = 'FAILED'
             AND attempt_count < :maxAttempts",
          {
            deliveryId = { value = qDelivery.id[1], cfsqltype = "cf_sql_bigint" },
            maxAttempts = { value = variables.maxAttempts, cfsqltype = "cf_sql_integer" }
          },
          { datasource = variables.datasource }
        );
      }
      if (!claimDecision.CLAIMED) {
        return { SUCCESS = true, CLAIMED = false, REASON = claimDecision.REASON };
      }

      return {
        SUCCESS = true,
        CLAIMED = true,
        DELIVERY_ID = val(qDelivery.id[1]),
        OCCURRENCE_KEY = occurrenceKey,
        CANDIDATE = lockedCandidate,
        RETRY = claimDecision.RETRY
      };
    }
  }

  private struct function sendReminderEmail(required struct candidate) output=false {
    return variables.emailService.sendDepartureReminderEmail(
      userId = arguments.candidate.userId,
      toEmail = arguments.candidate.ownerEmail,
      floatPlanId = arguments.candidate.floatPlanId,
      floatPlanName = arguments.candidate.floatPlanName,
      scheduledDepartureLabel = arguments.candidate.scheduledDepartureLabel,
      departureTimezone = arguments.candidate.departureTimezone,
      reminderType = arguments.candidate.reminderType
    );
  }

  private void function markSent(required numeric deliveryId) output=false {
    queryExecute(
      "UPDATE departure_reminder_deliveries
       SET status = 'SENT',
           sent_at_utc = UTC_TIMESTAMP(6),
           failed_at_utc = NULL,
           last_error_summary = NULL,
           updated_at_utc = UTC_TIMESTAMP(6)
       WHERE id = :deliveryId
         AND status = 'CLAIMED'",
      { deliveryId = { value = arguments.deliveryId, cfsqltype = "cf_sql_bigint" } },
      { datasource = variables.datasource }
    );
  }

  private void function markFailed(
    required numeric deliveryId,
    required string errorSummary
  ) output=false {
    var safeSummary = left(
      reReplace(trim(arguments.errorSummary), "[\r\n\t]+", " ", "all"),
      255
    );
    if (!len(safeSummary)) {
      safeSummary = "EMAIL_SEND_FAILED";
    }
    queryExecute(
      "UPDATE departure_reminder_deliveries
       SET status = 'FAILED',
           sent_at_utc = NULL,
           failed_at_utc = UTC_TIMESTAMP(6),
           last_error_summary = :errorSummary,
           updated_at_utc = UTC_TIMESTAMP(6)
       WHERE id = :deliveryId
         AND status = 'CLAIMED'",
      {
        deliveryId = { value = arguments.deliveryId, cfsqltype = "cf_sql_bigint" },
        errorSummary = { value = safeSummary, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
  }

  private struct function ineligible(required string reason) output=false {
    return { ELIGIBLE = false, REASON = arguments.reason };
  }

  private boolean function hasDateValue(required struct value, required string key) output=false {
    return structKeyExists(arguments.value, arguments.key)
      AND !isNull(arguments.value[arguments.key])
      AND isDate(arguments.value[arguments.key]);
  }

  private boolean function toBoolean(required any value) output=false {
    if (isBoolean(arguments.value)) {
      return arguments.value;
    }
    return listFindNoCase("1,true,yes,on", trim(toString(arguments.value))) GT 0;
  }

  private any function createEmailService() output=false {
    try {
      return createObject("component", "fpw.api.v1.email").init();
    } catch (any primaryPathErr) {
      return createObject("component", "api.v1.email").init();
    }
  }
}
