<cfcomponent output="false">

  <cfscript>
    variables.datasource = "fpw";
    variables.emailService = 0;
    variables.completedTripService = 0;
    variables.maxAttempts = 3;
  </cfscript>

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfargument name="emailService" type="any" required="false" default="">
    <cfargument name="completedTripService" type="any" required="false" default="">
    <cfscript>
      variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
      variables.emailService = isObject(arguments.emailService)
        ? arguments.emailService
        : createEmailService();
      variables.completedTripService = isObject(arguments.completedTripService)
        ? arguments.completedTripService
        : createCompletedTripService();
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="processCompletedTrip" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      var result = {
        SUCCESS = true,
        ELIGIBLE = false,
        REASON = "",
        floatPlanId = val(arguments.floatPlanId),
        examined = 0,
        claimed = 0,
        sent = 0,
        captainSent = 0,
        shoreSent = 0,
        failed = 0,
        skipped = 0
      };
      var model = {};
      var eligibility = {};
      var recipients = {};
      var context = {};
      var recipient = {};
      var claim = {};
      var emailResult = {};
      var recipientIndex = 0;

      if (arguments.userId LTE 0 OR arguments.floatPlanId LTE 0) {
        result.SUCCESS = false;
        result.REASON = "INVALID_ARGUMENTS";
        return result;
      }

      try {
        model = variables.completedTripService.getCompletedTripViewModel(
          userId = arguments.userId,
          floatPlanId = arguments.floatPlanId
        );
        eligibility = validateCompletionModel(model);
        if (!eligibility.ELIGIBLE) {
          result.REASON = eligibility.REASON;
          result.skipped = 1;
          return result;
        }

        result.ELIGIBLE = true;
        result.REASON = "CANONICAL_COMPLETION_CONFIRMED";
        context = buildTripContext(model, arguments.floatPlanId);
        context.userId = arguments.userId;
        recipients = loadRecipients(
          userId = arguments.userId,
          floatPlanId = arguments.floatPlanId,
          routeInstanceId = context.routeInstanceId
        );
        context.captainName = recipients.captainName;
        context.followPath = context.routeInstanceId GT 0
          ? resolveSecureFollowPath(arguments.userId, arguments.floatPlanId)
          : "";

        result.examined = arrayLen(recipients.items);
        if (!recipients.captainAvailable) {
          result.failed++;
          result.REASON = "CANONICAL_CAPTAIN_EMAIL_UNAVAILABLE";
        }

        for (recipientIndex = 1; recipientIndex LTE arrayLen(recipients.items); recipientIndex++) {
          recipient = recipients.items[recipientIndex];
          claim = claimRecipient(
            userId = arguments.userId,
            floatPlanId = arguments.floatPlanId,
            recipient = recipient,
            completionUtc = context.completionUtc
          );
          if (!claim.SUCCESS OR !claim.CLAIMED) {
            result.skipped++;
            continue;
          }

          result.claimed++;
          emailResult = sendSafeArrivalEmail(claim.RECIPIENT, context);
          if (!structKeyExists(emailResult, "success") OR emailResult.success NEQ true) {
            result.failed++;
            markFailed(
              historyId = claim.HISTORY_ID,
              errorSummary = structKeyExists(emailResult, "errorCode")
                ? toString(emailResult.errorCode)
                : "EMAIL_SEND_FAILED"
            );
            continue;
          }

          try {
            markSent(claim.HISTORY_ID);
            result.sent++;
            if (claim.RECIPIENT.role EQ "CAPTAIN") {
              result.captainSent++;
            } else {
              result.shoreSent++;
            }
          } catch (any markSentErr) {
            // Mail was accepted. Leave the claim in place so a later run cannot duplicate it.
            result.failed++;
            writeLog(
              file = "fpw-safe-arrival",
              type = "error",
              text = "SAFE_ARRIVAL_MARK_SENT_FAILED floatPlanId=" & arguments.floatPlanId
                & " historyId=" & claim.HISTORY_ID
            );
          }
        }

        result.SUCCESS = result.failed EQ 0;
        return result;
      } catch (any processErr) {
        writeLog(
          file = "fpw-safe-arrival",
          type = "error",
          text = "SAFE_ARRIVAL_PROCESS_FAILED floatPlanId=" & arguments.floatPlanId
            & " type=" & cleanLogValue(structKeyExists(processErr, "type") ? processErr.type : "any")
            & " message=" & cleanLogValue(processErr.message)
        );
        result.SUCCESS = false;
        result.REASON = "SAFE_ARRIVAL_PROCESS_FAILED";
        result.failed++;
        return result;
      }
    </cfscript>
  </cffunction>

  <cffunction name="validateCompletionModel" access="public" returntype="struct" output="false">
    <cfargument name="model" type="struct" required="true">
    <cfscript>
      var routeAvailable = false;
      if (
        !structKeyExists(arguments.model, "SUCCESS")
        OR arguments.model.SUCCESS NEQ true
      ) {
        return ineligible(
          structKeyExists(arguments.model, "errorCode") AND len(trim(toString(arguments.model.errorCode)))
            ? trim(toString(arguments.model.errorCode))
            : "COMPLETED_TRIP_NOT_ELIGIBLE"
        );
      }
      if (
        !structKeyExists(arguments.model, "trip")
        OR !isStruct(arguments.model.trip)
        OR !structKeyExists(arguments.model.trip, "status")
        OR uCase(trim(toString(arguments.model.trip.status))) NEQ "COMPLETED"
      ) {
        return ineligible("FLOAT_PLAN_NOT_CLOSED");
      }
      if (
        !structKeyExists(arguments.model, "timing")
        OR !isStruct(arguments.model.timing)
        OR !structKeyExists(arguments.model.timing, "actualCompletion")
        OR !isStruct(arguments.model.timing.actualCompletion)
        OR !structKeyExists(arguments.model.timing.actualCompletion, "available")
        OR arguments.model.timing.actualCompletion.available NEQ true
        OR !structKeyExists(arguments.model.timing.actualCompletion, "utc")
        OR !len(trim(toString(arguments.model.timing.actualCompletion.utc)))
      ) {
        return ineligible("COMPLETION_TIME_UNAVAILABLE");
      }

      routeAvailable = (
        structKeyExists(arguments.model, "route")
        AND isStruct(arguments.model.route)
        AND structKeyExists(arguments.model.route, "available")
        AND arguments.model.route.available EQ true
      );
      if (
        routeAvailable
        AND (
          !structKeyExists(arguments.model.route, "status")
          OR uCase(trim(toString(arguments.model.route.status))) NEQ "COMPLETED"
        )
      ) {
        return ineligible("ROUTE_INSTANCE_NOT_COMPLETED");
      }

      return {
        ELIGIBLE = true,
        REASON = "CANONICAL_COMPLETION_CONFIRMED"
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildAlertType" access="public" returntype="string" output="false">
    <cfargument name="role" type="string" required="true">
    <cfargument name="recipientKey" type="string" required="true">
    <cfargument name="completionUtc" type="string" required="true">
    <cfscript>
      var roleValue = uCase(trim(arguments.role));
      var prefix = roleValue EQ "CAPTAIN" ? "SAFE_CAPTAIN_" : "SAFE_SHORE_";
      var identityHash = lCase(hash(
        roleValue & "|" & trim(arguments.recipientKey) & "|" & trim(arguments.completionUtc),
        "SHA-256"
      ));
      return prefix & left(identityHash, 32 - len(prefix));
    </cfscript>
  </cffunction>

  <cffunction name="resolveClaimState" access="public" returntype="struct" output="false">
    <cfargument name="wasInserted" type="boolean" required="true">
    <cfargument name="existingStatus" type="string" required="true">
    <cfargument name="attemptCount" type="numeric" required="true">
    <cfscript>
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
    </cfscript>
  </cffunction>

  <cffunction name="buildTripContext" access="private" returntype="struct" output="false">
    <cfargument name="model" type="struct" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      var basePath = "";
      var routeInstanceId = 0;
      var vesselName = "";

      if (structKeyExists(request, "fpwBase") AND !isNull(request.fpwBase)) {
        basePath = trim(toString(request.fpwBase));
      }
      if (
        structKeyExists(arguments.model, "route")
        AND isStruct(arguments.model.route)
        AND structKeyExists(arguments.model.route, "routeInstanceId")
      ) {
        routeInstanceId = val(arguments.model.route.routeInstanceId);
      }
      if (
        structKeyExists(arguments.model, "vessel")
        AND isStruct(arguments.model.vessel)
        AND structKeyExists(arguments.model.vessel, "available")
        AND arguments.model.vessel.available
        AND structKeyExists(arguments.model.vessel, "name")
      ) {
        vesselName = trim(toString(arguments.model.vessel.name));
      }

      return {
        floatPlanId = val(arguments.floatPlanId),
        routeInstanceId = routeInstanceId,
        tripName = structText(arguments.model.trip, "name", "Completed Float Plan"),
        vesselName = vesselName,
        departureLocation = structText(arguments.model.trip, "departureLocation"),
        destination = structText(arguments.model.trip, "destination"),
        completionUtc = structText(arguments.model.timing.actualCompletion, "utc"),
        completionLabel = structText(arguments.model.timing.actualCompletion, "localLabel", "Not available"),
        completionTimezone = structText(arguments.model.timing.actualCompletion, "timezone", "UTC"),
        completedTripPath = variables.completedTripService.buildCompletedTripUrl(
          arguments.floatPlanId,
          basePath
        ),
        followPath = "",
        captainName = ""
      };
    </cfscript>
  </cffunction>

  <cffunction name="loadRecipients" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfargument name="routeInstanceId" type="numeric" required="true">
    <cfscript>
      var bundle = {
        items = [],
        captainAvailable = false,
        captainName = "The boater"
      };
      var qOwner = queryNew("");
      var qContacts = queryNew("");
      var qBasicContact = queryNew("");
      var ownerEmail = "";
      var ownerName = "";
      var contactEmail = "";
      var contactIndex = 0;
      var seenEmails = {};

      qOwner = queryExecute(
        "SELECT
           u.userId,
           u.email,
           TRIM(CONCAT(COALESCE(u.fName, ''), ' ', COALESCE(u.lName, ''))) AS display_name
         FROM floatplans fp
         INNER JOIN users u
           ON u.userId = CAST(TRIM(fp.userId) AS UNSIGNED)
         WHERE fp.floatPlanId = :floatPlanId
           AND u.userId = :userId
         LIMIT 1",
        {
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );

      if (qOwner.recordCount EQ 1) {
        ownerEmail = lCase(trim(toString(qOwner.email[1])));
        ownerName = trim(toString(qOwner.display_name[1]));
        if (len(ownerName)) {
          bundle.captainName = ownerName;
        }
        if (isValid("email", ownerEmail)) {
          bundle.captainAvailable = true;
          seenEmails[ownerEmail] = true;
          arrayAppend(bundle.items, {
            role = "CAPTAIN",
            kind = "USER",
            referenceId = val(qOwner.userId[1]),
            secondaryId = 0,
            recipientKey = "USER:" & val(qOwner.userId[1]),
            name = ownerName,
            email = ownerEmail
          });
        }
      }

      if (arguments.routeInstanceId GT 0) {
        qContacts = queryExecute(
          "SELECT
             fpc.recId,
             c.contactId,
             c.name,
             c.email
           FROM floatplan_contacts fpc
           INNER JOIN contacts c
             ON c.contactId = fpc.contactId
           INNER JOIN floatplans fp
             ON fp.floatPlanId = fpc.floatPlanId
            AND fp.floatPlanId = :floatPlanId
            AND CAST(TRIM(fp.userId) AS UNSIGNED) = :userId
           WHERE fpc.floatPlanId = :floatPlanId
             AND CAST(TRIM(c.userId) AS UNSIGNED) = :userId
           ORDER BY fpc.recId ASC",
          {
            floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
            userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = variables.datasource }
        );

        for (contactIndex = 1; contactIndex LTE qContacts.recordCount; contactIndex++) {
          contactEmail = isNull(qContacts.email[contactIndex])
            ? ""
            : lCase(trim(toString(qContacts.email[contactIndex])));
          if (
            isValid("email", contactEmail)
            AND !structKeyExists(seenEmails, contactEmail)
          ) {
            seenEmails[contactEmail] = true;
            arrayAppend(bundle.items, {
              role = "SHORE",
              kind = "FLOATPLAN_CONTACT",
              referenceId = val(qContacts.recId[contactIndex]),
              secondaryId = val(qContacts.contactId[contactIndex]),
              recipientKey = "ASSOCIATION:" & val(qContacts.recId[contactIndex]),
              name = isNull(qContacts.name[contactIndex]) ? "" : trim(toString(qContacts.name[contactIndex])),
              email = contactEmail
            });
          }
        }
      } else {
        qBasicContact = queryExecute(
          "SELECT
             id,
             notification_contact_name,
             notification_contact_email
           FROM floatplan_basic_details
           WHERE floatplan_id = :floatPlanId
           LIMIT 1",
          {
            floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = variables.datasource }
        );

        if (qBasicContact.recordCount EQ 1) {
          contactEmail = lCase(trim(toString(qBasicContact.notification_contact_email[1])));
          if (
            isValid("email", contactEmail)
            AND !structKeyExists(seenEmails, contactEmail)
          ) {
            seenEmails[contactEmail] = true;
            arrayAppend(bundle.items, {
              role = "SHORE",
              kind = "BASIC_DETAILS",
              referenceId = val(qBasicContact.id[1]),
              secondaryId = 0,
              recipientKey = "BASIC_DETAILS:" & val(qBasicContact.id[1]),
              name = trim(toString(qBasicContact.notification_contact_name[1])),
              email = contactEmail
            });
          }
        }
      }

      return bundle;
    </cfscript>
  </cffunction>

  <cffunction name="claimRecipient" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfargument name="recipient" type="struct" required="true">
    <cfargument name="completionUtc" type="string" required="true">
    <cfscript>
      var qPlan = queryNew("");
      var qRecipient = queryNew("");
      var qInsertCount = queryNew("");
      var qHistory = queryNew("");
      var lockedRecipient = {};
      var completionKey = "";
      var alertType = "";
      var wasInserted = false;
      var decision = {};

      transaction {
        qPlan = queryExecute(
          "SELECT
             fp.floatPlanId,
             CAST(TRIM(fp.userId) AS UNSIGNED) AS user_id,
             fp.`status` AS plan_status,
             fp.closedAt AS closed_at,
             fp.route_instance_id,
             ri.`status` AS route_status,
             ri.completed_at AS route_completed_at,
             u.email AS owner_email,
             TRIM(CONCAT(COALESCE(u.fName, ''), ' ', COALESCE(u.lName, ''))) AS owner_name,
             DATE_FORMAT(
               CASE
                 WHEN fp.route_instance_id IS NOT NULL AND fp.route_instance_id > 0
                   THEN ri.completed_at
                 ELSE fp.closedAt
               END,
               '%Y-%m-%dT%H:%i:%sZ'
             ) AS completion_utc_key
           FROM floatplans fp
           INNER JOIN users u
             ON u.userId = CAST(TRIM(fp.userId) AS UNSIGNED)
           LEFT JOIN route_instances ri
             ON ri.id = fp.route_instance_id
            AND TRIM(CAST(ri.user_id AS CHAR)) = TRIM(CAST(fp.userId AS CHAR))
           WHERE fp.floatPlanId = :floatPlanId
             AND CAST(TRIM(fp.userId) AS UNSIGNED) = :userId
           LIMIT 1
           FOR UPDATE",
          {
            floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
            userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = variables.datasource }
        );

        if (
          qPlan.recordCount NEQ 1
          OR uCase(trim(toString(qPlan.plan_status[1]))) NEQ "CLOSED"
          OR isNull(qPlan.closed_at[1])
          OR !isDate(qPlan.closed_at[1])
        ) {
          return { SUCCESS = true, CLAIMED = false, REASON = "NO_LONGER_COMPLETED" };
        }
        if (
          !isNull(qPlan.route_instance_id[1])
          AND val(qPlan.route_instance_id[1]) GT 0
          AND (
            isNull(qPlan.route_completed_at[1])
            OR !isDate(qPlan.route_completed_at[1])
            OR uCase(trim(toString(qPlan.route_status[1]))) NEQ "COMPLETED"
          )
        ) {
          return { SUCCESS = true, CLAIMED = false, REASON = "ROUTE_NOT_COMPLETED" };
        }

        completionKey = isNull(qPlan.completion_utc_key[1])
          ? ""
          : trim(toString(qPlan.completion_utc_key[1]));
        if (!len(completionKey) OR compare(completionKey, trim(arguments.completionUtc)) NEQ 0) {
          return { SUCCESS = true, CLAIMED = false, REASON = "COMPLETION_EVENT_CHANGED" };
        }

        if (uCase(trim(arguments.recipient.kind)) EQ "USER") {
          if (
            val(arguments.recipient.referenceId) NEQ val(qPlan.user_id[1])
            OR !isValid("email", lCase(trim(toString(qPlan.owner_email[1]))))
          ) {
            return { SUCCESS = true, CLAIMED = false, REASON = "CAPTAIN_RECIPIENT_UNAVAILABLE" };
          }
          lockedRecipient = duplicate(arguments.recipient);
          lockedRecipient.name = isNull(qPlan.owner_name[1]) ? "" : trim(toString(qPlan.owner_name[1]));
          lockedRecipient.email = lCase(trim(toString(qPlan.owner_email[1])));
        } else if (uCase(trim(arguments.recipient.kind)) EQ "FLOATPLAN_CONTACT") {
          qRecipient = queryExecute(
            "SELECT
               fpc.recId,
               c.contactId,
               c.name,
               c.email
             FROM floatplan_contacts fpc
             INNER JOIN contacts c
               ON c.contactId = fpc.contactId
             WHERE fpc.recId = :associationId
               AND fpc.contactId = :contactId
               AND fpc.floatPlanId = :floatPlanId
               AND CAST(TRIM(c.userId) AS UNSIGNED) = :userId
             LIMIT 1",
            {
              associationId = { value = arguments.recipient.referenceId, cfsqltype = "cf_sql_integer" },
              contactId = { value = arguments.recipient.secondaryId, cfsqltype = "cf_sql_integer" },
              floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
              userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
            },
            { datasource = variables.datasource }
          );
          if (
            qRecipient.recordCount NEQ 1
            OR isNull(qRecipient.email[1])
            OR !isValid("email", lCase(trim(toString(qRecipient.email[1]))))
            OR compareNoCase(trim(toString(qRecipient.email[1])), trim(toString(qPlan.owner_email[1]))) EQ 0
          ) {
            return { SUCCESS = true, CLAIMED = false, REASON = "SHORE_RECIPIENT_UNAVAILABLE" };
          }
          lockedRecipient = duplicate(arguments.recipient);
          lockedRecipient.name = isNull(qRecipient.name[1]) ? "" : trim(toString(qRecipient.name[1]));
          lockedRecipient.email = lCase(trim(toString(qRecipient.email[1])));
        } else if (uCase(trim(arguments.recipient.kind)) EQ "BASIC_DETAILS") {
          qRecipient = queryExecute(
            "SELECT
               id,
               notification_contact_name,
               notification_contact_email
             FROM floatplan_basic_details
             WHERE id = :detailsId
               AND floatplan_id = :floatPlanId
             LIMIT 1",
            {
              detailsId = { value = arguments.recipient.referenceId, cfsqltype = "cf_sql_bigint" },
              floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
            },
            { datasource = variables.datasource }
          );
          if (
            qRecipient.recordCount NEQ 1
            OR !isValid("email", lCase(trim(toString(qRecipient.notification_contact_email[1]))))
            OR compareNoCase(
              trim(toString(qRecipient.notification_contact_email[1])),
              trim(toString(qPlan.owner_email[1]))
            ) EQ 0
          ) {
            return { SUCCESS = true, CLAIMED = false, REASON = "BASIC_SHORE_RECIPIENT_UNAVAILABLE" };
          }
          lockedRecipient = duplicate(arguments.recipient);
          lockedRecipient.name = trim(toString(qRecipient.notification_contact_name[1]));
          lockedRecipient.email = lCase(trim(toString(qRecipient.notification_contact_email[1])));
        } else {
          return { SUCCESS = true, CLAIMED = false, REASON = "UNKNOWN_RECIPIENT_KIND" };
        }

        alertType = buildAlertType(
          role = lockedRecipient.role,
          recipientKey = lockedRecipient.recipientKey,
          completionUtc = completionKey
        );

        queryExecute(
          "INSERT IGNORE INTO floatplan_alert_history (
             floatPlanId,
             alertType,
             status,
             createdAtUTC,
             sentAtUTC,
             lastAttemptAtUTC,
             attemptCount,
             lastError
           ) VALUES (
             :floatPlanId,
             :alertType,
             'CLAIMED',
             UTC_TIMESTAMP(),
             NULL,
             UTC_TIMESTAMP(),
             1,
             NULL
           )",
          {
            floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
            alertType = { value = alertType, cfsqltype = "cf_sql_varchar" }
          },
          { datasource = variables.datasource }
        );
        qInsertCount = queryExecute(
          "SELECT ROW_COUNT() AS inserted_count",
          {},
          { datasource = variables.datasource }
        );
        wasInserted = qInsertCount.recordCount EQ 1
          AND val(qInsertCount.inserted_count[1]) EQ 1;

        qHistory = queryExecute(
          "SELECT id, status, attemptCount
           FROM floatplan_alert_history
           WHERE floatPlanId = :floatPlanId
             AND alertType = :alertType
           LIMIT 1
           FOR UPDATE",
          {
            floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
            alertType = { value = alertType, cfsqltype = "cf_sql_varchar" }
          },
          { datasource = variables.datasource }
        );
        if (qHistory.recordCount NEQ 1) {
          return { SUCCESS = false, CLAIMED = false, REASON = "CLAIM_NOT_FOUND" };
        }

        decision = resolveClaimState(
          wasInserted = wasInserted,
          existingStatus = toString(qHistory.status[1]),
          attemptCount = val(qHistory.attemptCount[1])
        );
        if (decision.RETRY) {
          queryExecute(
            "UPDATE floatplan_alert_history
             SET status = 'CLAIMED',
                 sentAtUTC = NULL,
                 lastAttemptAtUTC = UTC_TIMESTAMP(),
                 attemptCount = attemptCount + 1,
                 lastError = NULL
             WHERE id = :historyId
               AND status = 'FAILED'
               AND attemptCount < :maxAttempts",
            {
              historyId = { value = qHistory.id[1], cfsqltype = "cf_sql_bigint" },
              maxAttempts = { value = variables.maxAttempts, cfsqltype = "cf_sql_integer" }
            },
            { datasource = variables.datasource }
          );
        }
        if (!decision.CLAIMED) {
          return { SUCCESS = true, CLAIMED = false, REASON = decision.REASON };
        }

        return {
          SUCCESS = true,
          CLAIMED = true,
          HISTORY_ID = val(qHistory.id[1]),
          ALERT_TYPE = alertType,
          RECIPIENT = lockedRecipient,
          RETRY = decision.RETRY
        };
      }
    </cfscript>
  </cffunction>

  <cffunction name="sendSafeArrivalEmail" access="private" returntype="struct" output="false">
    <cfargument name="recipient" type="struct" required="true">
    <cfargument name="context" type="struct" required="true">
    <cfscript>
      if (arguments.recipient.role EQ "CAPTAIN") {
        return variables.emailService.sendSafeArrivalCaptainEmail(
          userId = arguments.context.userId,
          toEmail = arguments.recipient.email,
          recipientName = arguments.recipient.name,
          floatPlanId = arguments.context.floatPlanId,
          tripName = arguments.context.tripName,
          vesselName = arguments.context.vesselName,
          departureLocation = arguments.context.departureLocation,
          destination = arguments.context.destination,
          completionLabel = arguments.context.completionLabel,
          completionTimezone = arguments.context.completionTimezone,
          completedTripPath = arguments.context.completedTripPath
        );
      }

      return variables.emailService.sendSafeArrivalShoreContactEmail(
        userId = arguments.context.userId,
        toEmail = arguments.recipient.email,
        recipientName = arguments.recipient.name,
        captainName = arguments.context.captainName,
        floatPlanId = arguments.context.floatPlanId,
        tripName = arguments.context.tripName,
        vesselName = arguments.context.vesselName,
        destination = arguments.context.destination,
        completionLabel = arguments.context.completionLabel,
        completionTimezone = arguments.context.completionTimezone,
        followPath = arguments.context.followPath
      );
    </cfscript>
  </cffunction>

  <!--- Owner id travels in the canonical completion context. --->

  <cffunction name="resolveSecureFollowPath" access="private" returntype="string" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      var qStream = queryExecute(
        "SELECT slug, share_token
         FROM voyage_streams
         WHERE floatplan_id = :floatPlanId
           AND owner_user_id = :userId
           AND LENGTH(TRIM(slug)) > 0
           AND LENGTH(TRIM(share_token)) > 0
         ORDER BY id DESC
         LIMIT 1",
        {
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      var basePath = "";
      if (qStream.recordCount NEQ 1) {
        return "";
      }
      if (structKeyExists(request, "fpwBase") AND !isNull(request.fpwBase)) {
        basePath = reReplace(trim(toString(request.fpwBase)), "/$", "");
      }
      return basePath
        & "/app/follow.cfm?slug=" & urlEncodedFormat(trim(toString(qStream.slug[1])))
        & "&t=" & urlEncodedFormat(trim(toString(qStream.share_token[1])));
    </cfscript>
  </cffunction>

  <cffunction name="markSent" access="private" returntype="void" output="false">
    <cfargument name="historyId" type="numeric" required="true">
    <cfscript>
      queryExecute(
        "UPDATE floatplan_alert_history
         SET status = 'SENT',
             sentAtUTC = UTC_TIMESTAMP(),
             lastAttemptAtUTC = UTC_TIMESTAMP(),
             lastError = NULL
         WHERE id = :historyId
           AND status = 'CLAIMED'",
        {
          historyId = { value = arguments.historyId, cfsqltype = "cf_sql_bigint" }
        },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="markFailed" access="private" returntype="void" output="false">
    <cfargument name="historyId" type="numeric" required="true">
    <cfargument name="errorSummary" type="string" required="true">
    <cfscript>
      var safeSummary = left(cleanLogValue(arguments.errorSummary), 1024);
      if (!len(safeSummary)) {
        safeSummary = "EMAIL_SEND_FAILED";
      }
      queryExecute(
        "UPDATE floatplan_alert_history
         SET status = 'FAILED',
             sentAtUTC = NULL,
             lastAttemptAtUTC = UTC_TIMESTAMP(),
             lastError = :lastError
         WHERE id = :historyId
           AND status = 'CLAIMED'",
        {
          historyId = { value = arguments.historyId, cfsqltype = "cf_sql_bigint" },
          lastError = { value = safeSummary, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="ineligible" access="private" returntype="struct" output="false">
    <cfargument name="reason" type="string" required="true">
    <cfscript>
      return {
        ELIGIBLE = false,
        REASON = arguments.reason
      };
    </cfscript>
  </cffunction>

  <cffunction name="structText" access="private" returntype="string" output="false">
    <cfargument name="source" type="struct" required="true">
    <cfargument name="key" type="string" required="true">
    <cfargument name="defaultValue" type="string" required="false" default="">
    <cfscript>
      if (
        structKeyExists(arguments.source, arguments.key)
        AND !isNull(arguments.source[arguments.key])
        AND isSimpleValue(arguments.source[arguments.key])
      ) {
        var value = trim(toString(arguments.source[arguments.key]));
        if (len(value)) {
          return value;
        }
      }
      return arguments.defaultValue;
    </cfscript>
  </cffunction>

  <cffunction name="cleanLogValue" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="false" default="">
    <cfreturn left(reReplace(trim(toString(arguments.value)), "[\r\n\t]+", " ", "all"), 500)>
  </cffunction>

  <cffunction name="createEmailService" access="private" returntype="any" output="false">
    <cfscript>
      try {
        return createObject("component", "fpw.api.v1.email").init();
      } catch (any primaryPathErr) {
        return createObject("component", "api.v1.email").init();
      }
    </cfscript>
  </cffunction>

  <cffunction name="createCompletedTripService" access="private" returntype="any" output="false">
    <cfscript>
      try {
        return createObject("component", "fpw.api.v1.CompletedTripViewModelService").init(variables.datasource);
      } catch (any primaryPathErr) {
        return createObject("component", "api.v1.CompletedTripViewModelService").init(variables.datasource);
      }
    </cfscript>
  </cffunction>

</cfcomponent>






