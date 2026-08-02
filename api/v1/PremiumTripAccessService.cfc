<cfcomponent output="false">

  <cfset variables.datasource = "fpw">
  <cfset variables.monitoringService = "">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfargument name="monitoringService" type="any" required="false" default="">
    <cfscript>
      variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
      variables.monitoringService = isObject(arguments.monitoringService) ? arguments.monitoringService : "";
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="getTripOperationalAccess" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfargument name="expireIfDue" type="boolean" required="false" default="true">
    <cfscript>
      var qPlan = queryNew("");
      var qReceipt = queryNew("");
      var qCredit = queryNew("");
      var accessSource = "none";
      var planStatus = "";
      var membershipOverrideActive = false;
      var recurringMembershipState = {};
      var expirationResult = {};
      var result = baseAccessResult();

      if (arguments.userId LTE 0 OR arguments.floatPlanId LTE 0) {
        return denyResult(result, "TRIP_ACCESS_RECORD_MISSING", "This float plan access record is unavailable.");
      }

      qPlan = queryExecute(
        "SELECT floatPlanId, userId, UPPER(TRIM(status)) AS status_value,
                expiredAt, end_reason
         FROM floatplans
         WHERE floatPlanId = :floatPlanId
         LIMIT 1",
        {
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      if (qPlan.recordCount NEQ 1) {
        return denyResult(result, "TRIP_ACCESS_RECORD_MISSING", "This float plan access record is unavailable.");
      }
      if (val(qPlan.userId[1]) NEQ val(arguments.userId)) {
        return denyResult(result, "TRIP_ACCESS_BINDING_INVALID", "This float plan access record is invalid.");
      }

      qReceipt = loadReceipt(arguments.userId, arguments.floatPlanId, false);
      if (qReceipt.recordCount NEQ 1) {
        return denyResult(result, "TRIP_ACCESS_RECORD_MISSING", "Premium access for this float plan is unavailable.");
      }
      result.accessStartedAtUtc = val(qReceipt.has_access_start[1]) EQ 1
        ? qReceipt.access_started_at_utc[1]
        : nullValue();
      result.accessExpiresAtUtc = val(qReceipt.has_access_expiry[1]) EQ 1
        ? qReceipt.access_expires_at_utc[1]
        : nullValue();
      accessSource = lCase(trim(toString(qReceipt.access_source[1])));
      result.accessSource = accessSource;
      planStatus = uCase(trim(toString(qPlan.status_value[1])));

      if (val(qReceipt.access_is_ended[1]) EQ 1) {
        if (
          planStatus EQ "EXPIRED"
          OR (
            val(qReceipt.has_access_end_reason[1]) EQ 1
            AND compareNoCase(trim(toString(qReceipt.access_end_reason[1])), "SINGLE_TRIP_LIMIT") EQ 0
          )
        ) {
          result.isExpired = true;
          return denyResult(result, "TRIP_ACCESS_EXPIRED", expiredMessage());
        }
        return denyResult(result, "TRIP_ACCESS_ENDED", "Premium operational access for this float plan has ended.");
      }

      if (planStatus EQ "EXPIRED") {
        result.isExpired = true;
        return denyResult(result, "TRIP_ACCESS_EXPIRED", expiredMessage());
      }
      if (listFindNoCase("CLOSED,CANCELLED,CANCELED", planStatus)) {
        return denyResult(result, "TRIP_ACCESS_ENDED", "Premium operational access for this float plan has ended.");
      }
      if (planStatus NEQ "ACTIVE") {
        return denyResult(result, "TRIP_NOT_ACTIVE", "This float plan is not active.");
      }

      if (accessSource EQ "premium_send_credit") {
        qCredit = queryExecute(
          "SELECT c.id
           FROM premium_send_credits c
           INNER JOIN premium_send_receipts r
             ON r.id = :receiptId
            AND r.credit_id = c.id
            AND r.user_id = c.user_id
            AND r.float_plan_id = c.consumed_float_plan_id
            AND r.access_started_at_utc >= c.consumed_at_utc
            AND r.access_expires_at_utc = DATE_ADD(r.access_started_at_utc, INTERVAL 21 DAY)
           WHERE c.id = :creditId
             AND c.user_id = :userId
             AND c.status = 'CONSUMED'
             AND c.consumed_float_plan_id = :floatPlanId
           LIMIT 1",
          {
            receiptId = { value = val(qReceipt.id[1]), cfsqltype = "cf_sql_bigint" },
            creditId = { value = val(qReceipt.has_credit_id[1]) EQ 1 ? val(qReceipt.credit_id[1]) : 0, cfsqltype = "cf_sql_bigint" },
            userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
            floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = variables.datasource }
        );
        if (
          qCredit.recordCount NEQ 1
          OR val(qReceipt.has_access_start[1]) NEQ 1
          OR val(qReceipt.has_access_expiry[1]) NEQ 1
        ) {
          return denyResult(result, "TRIP_ACCESS_BINDING_INVALID", "This float plan access record is invalid.");
        }

        recurringMembershipState = getCurrentRecurringMembershipState(arguments.userId);
        membershipOverrideActive = recurringMembershipState.active;
        result.membershipOverrideActive = membershipOverrideActive;
        if (membershipOverrideActive) {
          return allowResult(result, "TRIP_ACCESS_MEMBERSHIP_OVERRIDE", "An active Monthly or Annual membership currently authorizes this trip.");
        }

        if (isCreditAccessDue(val(qReceipt.id[1]))) {
          result.isExpired = true;
          if (!recurringMembershipState.evaluated) {
            return denyResult(result, "TRIP_ACCESS_BINDING_INVALID", "Premium trip access could not be verified. Please try again.");
          }
          if (arguments.expireIfDue) {
            expirationResult = expireSingleTripAccess(arguments.floatPlanId, "request_gate");
            if (structKeyExists(expirationResult, "reasonCode") AND expirationResult.reasonCode EQ "TRIP_ACCESS_MEMBERSHIP_OVERRIDE") {
              result.membershipOverrideActive = true;
              result.isExpired = false;
              return allowResult(result, "TRIP_ACCESS_MEMBERSHIP_OVERRIDE", "An active Monthly or Annual membership currently authorizes this trip.");
            }
          }
          return denyResult(result, "TRIP_ACCESS_EXPIRED", expiredMessage());
        }
        return allowResult(result, "TRIP_ACCESS_ACTIVE", "Premium operational access for this float plan is active.");
      }

      if (accessSource EQ "general_premium") {
        if (val(qReceipt.has_credit_id[1]) EQ 1 OR val(qReceipt.has_access_expiry[1]) EQ 1) {
          return denyResult(result, "TRIP_ACCESS_BINDING_INVALID", "This float plan access record is invalid.");
        }
        if (
          val(qReceipt.has_member_entitlement_id[1]) EQ 1
          AND !isReceiptEntitlementOwnedByUser(val(qReceipt.member_entitlement_id[1]), arguments.userId)
        ) {
          return denyResult(result, "TRIP_ACCESS_BINDING_INVALID", "This float plan access record is invalid.");
        }
        if (hasCurrentGeneralPremium(arguments.userId)) {
          return allowResult(result, "TRIP_ACCESS_ACTIVE", "Premium operational access for this float plan is active.");
        }
        return denyResult(result, "MEMBERSHIP_REQUIRED", "An active Premium membership is required to continue this trip.");
      }

      return denyResult(result, "TRIP_ACCESS_BINDING_INVALID", "This float plan access record is invalid.");
    </cfscript>
  </cffunction>

  <cffunction name="getTripOperationalAccessForUpdate" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      var qReceiptLock = loadReceipt(arguments.userId, arguments.floatPlanId, true);
      var qPlanLock = queryNew("");

      if (qReceiptLock.recordCount NEQ 1) {
        return denyResult(baseAccessResult(), "TRIP_ACCESS_RECORD_MISSING", "Premium access for this float plan is unavailable.");
      }
      qPlanLock = queryExecute(
        "SELECT floatPlanId
         FROM floatplans
         WHERE floatPlanId = :floatPlanId
           AND userId = :userIdText
         LIMIT 1
         FOR UPDATE",
        {
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
          userIdText = { value = toString(val(arguments.userId)), cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
      if (qPlanLock.recordCount NEQ 1) {
        return denyResult(baseAccessResult(), "TRIP_ACCESS_BINDING_INVALID", "This float plan access record is invalid.");
      }
      return getTripOperationalAccess(arguments.userId, arguments.floatPlanId, true);
    </cfscript>
  </cffunction>

  <cffunction name="expireSingleTripAccess" access="public" returntype="struct" output="false">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfargument name="triggerSource" type="string" required="false" default="scheduled_worker">
    <cfscript>
      var cleanTrigger = normalizeTrigger(arguments.triggerSource);
      var result = lifecycleResult("TRIP_ACCESS_RECORD_MISSING", false, false);
      var qReceipt = queryNew("");
      var qPlan = queryNew("");
      var qEndedAt = queryNew("");
      var planStatus = "";
      var receiptUpdateResult = {};
      var planUpdateResult = {};
      var monitorResult = {};
      var recurringMembershipState = {};

      if (arguments.floatPlanId LTE 0) {
        return result;
      }

      try {
        transaction {
          qReceipt = queryExecute(
            "SELECT id, user_id, float_plan_id, access_source, access_expires_at_utc,
                    access_ended_at_utc, access_end_reason,
                    CASE WHEN access_expires_at_utc IS NULL THEN 0 ELSE 1 END AS has_access_expiry,
                    CASE WHEN access_ended_at_utc IS NULL THEN 0 ELSE 1 END AS access_is_ended
             FROM premium_send_receipts
             WHERE float_plan_id = :floatPlanId
             LIMIT 1
             FOR UPDATE",
            {
              floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
            },
            { datasource = variables.datasource }
          );
          if (qReceipt.recordCount NEQ 1) {
            result = lifecycleResult("TRIP_ACCESS_RECORD_MISSING", false, false);
          } else {
            qPlan = queryExecute(
              "SELECT floatPlanId, userId, UPPER(TRIM(status)) AS status_value
               FROM floatplans
               WHERE floatPlanId = :floatPlanId
               LIMIT 1
               FOR UPDATE",
              {
                floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
              },
              { datasource = variables.datasource }
            );
            if (qPlan.recordCount NEQ 1 OR val(qPlan.userId[1]) NEQ val(qReceipt.user_id[1])) {
              result = lifecycleResult("TRIP_ACCESS_BINDING_INVALID", false, false);
            } else if (val(qReceipt.access_is_ended[1]) EQ 1) {
              planStatus = uCase(trim(toString(qPlan.status_value[1])));
              if (planStatus EQ "ACTIVE") {
                result = lifecycleResult("TRIP_ACCESS_BINDING_INVALID", false, false);
              } else {
                result = lifecycleResult("TRIP_ACCESS_ENDED", true, false);
                result.alreadyEnded = true;
              }
            } else if (lCase(trim(toString(qReceipt.access_source[1]))) NEQ "premium_send_credit") {
              result = lifecycleResult("TRIP_ACCESS_SKIPPED", true, false);
              result.skipped = true;
            } else if (val(qReceipt.has_access_expiry[1]) NEQ 1) {
              result = lifecycleResult("TRIP_ACCESS_BINDING_INVALID", false, false);
            } else if (!isCreditAccessDue(val(qReceipt.id[1]))) {
              result = lifecycleResult("TRIP_ACCESS_NOT_DUE", true, false);
              result.skipped = true;
            } else {
              recurringMembershipState = getCurrentRecurringMembershipState(val(qReceipt.user_id[1]));
              if (!recurringMembershipState.evaluated) {
                throw(type = "FPW.RecurringMembershipConfigurationUnavailable", message = "Recurring membership configuration is unavailable.");
              }
              if (recurringMembershipState.active) {
                result = lifecycleResult("TRIP_ACCESS_MEMBERSHIP_OVERRIDE", true, false);
                result.membershipOverrideActive = true;
              } else {
              planStatus = uCase(trim(toString(qPlan.status_value[1])));
              if (planStatus EQ "EXPIRED") {
                result = lifecycleResult("TRIP_ACCESS_BINDING_INVALID", false, false);
              } else if (planStatus NEQ "ACTIVE") {
                result = lifecycleResult("TRIP_NOT_ACTIVE", true, false);
                result.skipped = true;
              } else {
                queryExecute(
                  "SET @fpw_single_trip_expiration_utc = UTC_TIMESTAMP(6)",
                  {},
                  { datasource = variables.datasource }
                );
                queryExecute(
                  "UPDATE floatplans
                   SET status = 'EXPIRED',
                       expiredAt = @fpw_single_trip_expiration_utc,
                       end_reason = 'SINGLE_TRIP_LIMIT',
                       lastUpdateStatus = @fpw_single_trip_expiration_utc
                   WHERE floatPlanId = :floatPlanId
                     AND userId = :userIdText
                     AND UPPER(TRIM(status)) = 'ACTIVE'",
                  {
                    floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userIdText = { value = toString(val(qReceipt.user_id[1])), cfsqltype = "cf_sql_varchar" }
                  },
                  { datasource = variables.datasource, result = "local.planUpdateResult" }
                );
                if (!structKeyExists(planUpdateResult, "recordCount") OR val(planUpdateResult.recordCount) NEQ 1) {
                  throw(type = "FPW.SingleTripExpirationConflict", message = "Float plan expiration lost its lifecycle lock.");
                }
                queryExecute(
                  "UPDATE premium_send_receipts
                   SET access_ended_at_utc = @fpw_single_trip_expiration_utc,
                       access_end_reason = 'SINGLE_TRIP_LIMIT'
                   WHERE id = :receiptId
                     AND access_source = 'premium_send_credit'
                     AND access_ended_at_utc IS NULL",
                  {
                    receiptId = { value = val(qReceipt.id[1]), cfsqltype = "cf_sql_bigint" }
                  },
                  { datasource = variables.datasource, result = "local.receiptUpdateResult" }
                );
                if (!structKeyExists(receiptUpdateResult, "recordCount") OR val(receiptUpdateResult.recordCount) NEQ 1) {
                  throw(type = "FPW.SingleTripExpirationConflict", message = "Receipt expiration lost its lifecycle lock.");
                }

                monitorResult = getMonitoringService().closeMonitoringForFloatPlan(arguments.floatPlanId, "SINGLE_TRIP_LIMIT");
                if (!structKeyExists(monitorResult, "SUCCESS") OR monitorResult.SUCCESS NEQ true) {
                  throw(type = "FPW.SingleTripMonitoringCloseFailed", message = "Canonical monitoring close failed.");
                }

                qEndedAt = queryExecute(
                  "SELECT @fpw_single_trip_expiration_utc AS ended_at_utc",
                  {},
                  { datasource = variables.datasource }
                );
                result = lifecycleResult("TRIP_ACCESS_EXPIRED", true, true);
                result.accessEndedAtUtc = qEndedAt.recordCount ? qEndedAt.ended_at_utc[1] : nullValue();
                result.triggerSource = cleanTrigger;
              }
              }
            }
          }
        }
      } catch (any expirationErr) {
        writeLog(
          file = "fpw-single-trip-expiration",
          type = "error",
          text = "SINGLE_TRIP_EXPIRATION_FAILED code=TRIP_EXPIRATION_FAILED floatPlanId=" & val(arguments.floatPlanId) & " trigger=" & cleanTrigger
        );
        result = lifecycleResult("TRIP_EXPIRATION_FAILED", false, false);
      }
      return result;
    </cfscript>
  </cffunction>

  <cffunction name="endAccessForPlan" access="public" returntype="struct" output="false">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfargument name="endReason" type="string" required="true">
    <cfscript>
      var reason = uCase(trim(arguments.endReason));
      var qReceipt = queryNew("");
      var updateResult = {};
      var result = lifecycleResult("TRIP_ACCESS_RECORD_MISSING", true, false);

      if (arguments.floatPlanId LTE 0 OR !listFindNoCase("CLOSED,CANCELLED,CANCELED", reason)) {
        return lifecycleResult("TRIP_ACCESS_BINDING_INVALID", false, false);
      }
      qReceipt = queryExecute(
        "SELECT id, access_ended_at_utc,
                CASE WHEN access_ended_at_utc IS NULL THEN 0 ELSE 1 END AS access_is_ended
         FROM premium_send_receipts
         WHERE float_plan_id = :floatPlanId
         LIMIT 1
         FOR UPDATE",
        {
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      if (qReceipt.recordCount NEQ 1) {
        result.skipped = true;
        return result;
      }
      if (val(qReceipt.access_is_ended[1]) EQ 1) {
        result.reasonCode = "TRIP_ACCESS_ENDED";
        result.alreadyEnded = true;
        return result;
      }
      queryExecute(
        "UPDATE premium_send_receipts r
         INNER JOIN floatplans fp ON fp.floatPlanId = r.float_plan_id
         SET r.access_ended_at_utc = COALESCE(fp.closedAt, UTC_TIMESTAMP(6)),
             r.access_end_reason = :endReason
         WHERE r.id = :receiptId
           AND r.access_ended_at_utc IS NULL",
        {
          endReason = { value = reason, cfsqltype = "cf_sql_varchar" },
          receiptId = { value = val(qReceipt.id[1]), cfsqltype = "cf_sql_bigint" }
        },
        { datasource = variables.datasource, result = "local.updateResult" }
      );
      if (!structKeyExists(updateResult, "recordCount") OR val(updateResult.recordCount) NEQ 1) {
        return lifecycleResult("TRIP_EXPIRATION_FAILED", false, false);
      }
      result.reasonCode = "TRIP_ACCESS_ENDED";
      result.transitioned = true;
      return result;
    </cfscript>
  </cffunction>

  <cffunction name="processDueExpirations" access="public" returntype="struct" output="false">
    <cfargument name="limit" type="numeric" required="false" default="100">
    <cfscript>
      return processDueQuery(0, arguments.limit, "scheduled_worker");
    </cfscript>
  </cffunction>

  <cffunction name="processDueExpirationsForUser" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="limit" type="numeric" required="false" default="10">
    <cfargument name="triggerSource" type="string" required="false" default="request_gate">
    <cfscript>
      return processDueQuery(arguments.userId, arguments.limit, arguments.triggerSource);
    </cfscript>
  </cffunction>

  <cffunction name="getActiveTripOperationalSummary" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var qPlans = queryExecute(
        "SELECT r.float_plan_id
         FROM premium_send_receipts r
         INNER JOIN floatplans fp
           ON fp.floatPlanId = r.float_plan_id
          AND fp.userId = :userIdText
         WHERE r.user_id = :userId
           AND r.access_ended_at_utc IS NULL
           AND UPPER(TRIM(fp.status)) = 'ACTIVE'
         ORDER BY r.committed_at_utc DESC, r.id DESC
         LIMIT 3",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
          userIdText = { value = toString(val(arguments.userId)), cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
      var allowedPlans = [];
      var access = {};
      var i = 0;
      var result = {
        "hasActiveTripOperationalAccess" = false,
        "ambiguous" = false,
        "floatPlanId" = nullValue(),
        "creditId" = nullValue(),
        "creditSource" = "",
        "accessSource" = "none",
        "accessStartedAtUtc" = nullValue(),
        "accessExpiresAtUtc" = nullValue()
      };

      for (i = 1; i LTE qPlans.recordCount; i++) {
        access = getTripOperationalAccess(arguments.userId, val(qPlans.float_plan_id[i]), true);
        if (access.allowed) {
          arrayAppend(allowedPlans, duplicate(access));
          allowedPlans[arrayLen(allowedPlans)].floatPlanId = val(qPlans.float_plan_id[i]);
        }
      }
      result.ambiguous = arrayLen(allowedPlans) GT 1;
      if (arrayLen(allowedPlans) EQ 1) {
        result.hasActiveTripOperationalAccess = true;
        result.floatPlanId = allowedPlans[1].floatPlanId;
        result.accessSource = allowedPlans[1].accessSource;
        if (structKeyExists(allowedPlans[1], "accessStartedAtUtc")) {
          result.accessStartedAtUtc = allowedPlans[1].accessStartedAtUtc;
        }
        if (structKeyExists(allowedPlans[1], "accessExpiresAtUtc")) {
          result.accessExpiresAtUtc = allowedPlans[1].accessExpiresAtUtc;
        }
      }
      return result;
    </cfscript>
  </cffunction>

  <cffunction name="processDueQuery" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="limit" type="numeric" required="true">
    <cfargument name="triggerSource" type="string" required="true">
    <cfscript>
      var batchLimit = min(500, max(1, fix(arguments.limit)));
      var scanLimit = min(1000, batchLimit + 50);
      var userFilter = arguments.userId GT 0 ? " AND r.user_id = :userId" : "";
      var recurringPriceIds = getRecurringPriceIds();
      var params = {
        scanLimit = { value = scanLimit, cfsqltype = "cf_sql_integer" },
        recurringConfigOk = { value = recurringPriceIds.configured ? 1 : 0, cfsqltype = "cf_sql_integer" },
        monthlyPriceId = { value = recurringPriceIds.monthly, cfsqltype = "cf_sql_varchar" },
        annualPriceId = { value = recurringPriceIds.annual, cfsqltype = "cf_sql_varchar" }
      };
      var qDue = queryNew("");
      var item = {};
      var i = 0;
      var result = {
        "SUCCESS" = true,
        "success" = true,
        "examined" = 0,
        "expired" = 0,
        "membership_overridden" = 0,
        "already_ended" = 0,
        "skipped" = 0,
        "failed" = 0
      };

      if (arguments.userId GT 0) {
        params.userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" };
      }
      qDue = queryExecute(
        "SELECT r.float_plan_id
         FROM premium_send_receipts r
         LEFT JOIN premium_send_credits c
           ON c.id = r.credit_id
          AND c.user_id = r.user_id
          AND c.consumed_float_plan_id = r.float_plan_id
         LEFT JOIN floatplans fp
           ON fp.floatPlanId = r.float_plan_id
          AND TRIM(fp.userId) = CAST(r.user_id AS CHAR)
         WHERE r.access_source = 'premium_send_credit'
           AND r.access_expires_at_utc <= UTC_TIMESTAMP(6)
           AND r.access_ended_at_utc IS NULL" & userFilter & "
         ORDER BY CASE
           WHEN :recurringConfigOk = 1
            AND c.id IS NOT NULL
            AND c.status = 'CONSUMED'
            AND c.consumed_at_utc IS NOT NULL
            AND fp.floatPlanId IS NOT NULL
            AND UPPER(TRIM(fp.status)) = 'ACTIVE'
            AND NOT EXISTS (
              SELECT 1
              FROM member_entitlements me
              WHERE me.user_id = r.user_id
                AND me.entitlement_type = 'premium'
                AND me.source = 'stripe_subscription'
                AND me.status = 'active'
                AND me.starts_at_utc <= UTC_TIMESTAMP(6)
                AND (me.expires_at_utc IS NULL OR me.expires_at_utc >= UTC_TIMESTAMP(6))
                AND (
                  (:monthlyPriceId <> '' AND me.stripe_price_id = :monthlyPriceId)
                  OR (:annualPriceId <> '' AND me.stripe_price_id = :annualPriceId)
                )
            )
           THEN 0 ELSE 1
         END ASC,
         r.access_expires_at_utc ASC,
         r.id ASC
         LIMIT :scanLimit",
        params,
        { datasource = variables.datasource }
      );
      for (i = 1; i LTE qDue.recordCount; i++) {
        if (result.expired GTE batchLimit) {
          break;
        }
        result.examined++;
        item = expireSingleTripAccess(val(qDue.float_plan_id[i]), arguments.triggerSource);
        if (!structKeyExists(item, "success") OR !item.success) {
          result.failed++;
        } else if (structKeyExists(item, "transitioned") AND item.transitioned) {
          result.expired++;
        } else if (structKeyExists(item, "membershipOverrideActive") AND item.membershipOverrideActive) {
          result.membership_overridden++;
        } else if (structKeyExists(item, "alreadyEnded") AND item.alreadyEnded) {
          result.already_ended++;
        } else {
          result.skipped++;
        }
      }
      result.SUCCESS = result.failed EQ 0;
      result.success = result.SUCCESS;
      return result;
    </cfscript>
  </cffunction>

  <cffunction name="loadReceipt" access="private" returntype="query" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfargument name="forUpdate" type="boolean" required="true">
    <cfscript>
      return queryExecute(
        "SELECT id, user_id, float_plan_id, credit_id, member_entitlement_id,
                membership_interval_snapshot, access_source, access_started_at_utc,
                access_expires_at_utc, access_ended_at_utc, access_end_reason,
                CASE WHEN credit_id IS NULL THEN 0 ELSE 1 END AS has_credit_id,
                CASE WHEN member_entitlement_id IS NULL THEN 0 ELSE 1 END AS has_member_entitlement_id,
                CASE WHEN access_started_at_utc IS NULL THEN 0 ELSE 1 END AS has_access_start,
                CASE WHEN access_expires_at_utc IS NULL THEN 0 ELSE 1 END AS has_access_expiry,
                CASE WHEN access_ended_at_utc IS NULL THEN 0 ELSE 1 END AS access_is_ended,
                CASE WHEN access_end_reason IS NULL THEN 0 ELSE 1 END AS has_access_end_reason
         FROM premium_send_receipts
         WHERE user_id = :userId
           AND float_plan_id = :floatPlanId
         LIMIT 1" & (arguments.forUpdate ? " FOR UPDATE" : ""),
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="isCreditAccessDue" access="private" returntype="boolean" output="false">
    <cfargument name="receiptId" type="numeric" required="true">
    <cfscript>
      var qDue = queryExecute(
        "SELECT CASE WHEN access_expires_at_utc <= UTC_TIMESTAMP(6) THEN 1 ELSE 0 END AS is_due
         FROM premium_send_receipts
         WHERE id = :receiptId
           AND access_source = 'premium_send_credit'
           AND access_ended_at_utc IS NULL
         LIMIT 1",
        {
          receiptId = { value = arguments.receiptId, cfsqltype = "cf_sql_bigint" }
        },
        { datasource = variables.datasource }
      );
      return qDue.recordCount EQ 1 AND val(qDue.is_due[1]) EQ 1;
    </cfscript>
  </cffunction>

  <cffunction name="hasCurrentGeneralPremium" access="private" returntype="boolean" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var qAccess = queryExecute(
        "SELECT id
         FROM member_entitlements
         WHERE user_id = :userId
           AND entitlement_type = 'premium'
           AND status = 'active'
           AND starts_at_utc <= UTC_TIMESTAMP(6)
           AND (expires_at_utc IS NULL OR expires_at_utc >= UTC_TIMESTAMP(6))
         LIMIT 1",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      return qAccess.recordCount EQ 1;
    </cfscript>
  </cffunction>

  <cffunction name="isReceiptEntitlementOwnedByUser" access="private" returntype="boolean" output="false">
    <cfargument name="entitlementId" type="numeric" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var qBinding = queryExecute(
        "SELECT id
         FROM member_entitlements
         WHERE id = :entitlementId
           AND user_id = :userId
           AND entitlement_type = 'premium'
         LIMIT 1",
        {
          entitlementId = { value = arguments.entitlementId, cfsqltype = "cf_sql_bigint" },
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      return qBinding.recordCount EQ 1;
    </cfscript>
  </cffunction>

  <cffunction name="getCurrentRecurringMembershipState" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var priceIds = getRecurringPriceIds();
      var qAccess = queryNew("");
      var result = { evaluated = priceIds.configured, active = false };
      if (!result.evaluated) {
        return result;
      }
      qAccess = queryExecute(
        "SELECT id
         FROM member_entitlements
         WHERE user_id = :userId
           AND entitlement_type = 'premium'
           AND source = 'stripe_subscription'
           AND status = 'active'
           AND starts_at_utc <= UTC_TIMESTAMP(6)
           AND (expires_at_utc IS NULL OR expires_at_utc >= UTC_TIMESTAMP(6))
           AND (
             (:monthlyPriceId <> '' AND stripe_price_id = :monthlyPriceId)
             OR (:annualPriceId <> '' AND stripe_price_id = :annualPriceId)
           )
         LIMIT 1",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
          monthlyPriceId = { value = priceIds.monthly, cfsqltype = "cf_sql_varchar" },
          annualPriceId = { value = priceIds.annual, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
      result.active = qAccess.recordCount EQ 1;
      return result;
    </cfscript>
  </cffunction>

  <cffunction name="getRecurringPriceIds" access="private" returntype="struct" output="false">
    <cfscript>
      var result = { monthly = "", annual = "", configured = false };
      var configService = "";
      try {
        configService = createObject("component", "fpw.api.v1.StripeConfigService").init();
        result.monthly = trim(configService.getPremiumMonthlyPriceId());
        result.annual = trim(configService.getPremiumYearlyPriceId());
        result.configured = len(result.monthly) AND len(result.annual);
      } catch (any configErr) {
        result.monthly = "";
        result.annual = "";
        result.configured = false;
      }
      return result;
    </cfscript>
  </cffunction>

  <cffunction name="getMonitoringService" access="private" returntype="any" output="false">
    <cfscript>
      if (isObject(variables.monitoringService)) {
        return variables.monitoringService;
      }
      try {
        variables.monitoringService = createObject("component", "fpw.api.v1.monitor").init(variables.datasource);
      } catch (any primaryErr) {
        variables.monitoringService = createObject("component", "api.v1.monitor").init(variables.datasource);
      }
      return variables.monitoringService;
    </cfscript>
  </cffunction>

  <cffunction name="baseAccessResult" access="private" returntype="struct" output="false">
    <cfscript>
      return {
        "allowed" = false,
        "accessSource" = "none",
        "membershipOverrideActive" = false,
        "accessStartedAtUtc" = nullValue(),
        "accessExpiresAtUtc" = nullValue(),
        "isExpired" = false,
        "reasonCode" = "TRIP_ACCESS_RECORD_MISSING",
        "userMessage" = "Premium access for this float plan is unavailable."
      };
    </cfscript>
  </cffunction>

  <cffunction name="allowResult" access="private" returntype="struct" output="false">
    <cfargument name="result" type="struct" required="true">
    <cfargument name="reasonCode" type="string" required="true">
    <cfargument name="userMessage" type="string" required="true">
    <cfscript>
      arguments.result.allowed = true;
      arguments.result.reasonCode = arguments.reasonCode;
      arguments.result.userMessage = arguments.userMessage;
      return arguments.result;
    </cfscript>
  </cffunction>

  <cffunction name="denyResult" access="private" returntype="struct" output="false">
    <cfargument name="result" type="struct" required="true">
    <cfargument name="reasonCode" type="string" required="true">
    <cfargument name="userMessage" type="string" required="true">
    <cfscript>
      arguments.result.allowed = false;
      arguments.result.reasonCode = arguments.reasonCode;
      arguments.result.userMessage = arguments.userMessage;
      return arguments.result;
    </cfscript>
  </cffunction>

  <cffunction name="lifecycleResult" access="private" returntype="struct" output="false">
    <cfargument name="reasonCode" type="string" required="true">
    <cfargument name="success" type="boolean" required="true">
    <cfargument name="transitioned" type="boolean" required="true">
    <cfscript>
      return {
        "SUCCESS" = arguments.success,
        "success" = arguments.success,
        "reasonCode" = arguments.reasonCode,
        "transitioned" = arguments.transitioned,
        "membershipOverrideActive" = false,
        "alreadyEnded" = false,
        "skipped" = false
      };
    </cfscript>
  </cffunction>

  <cffunction name="normalizeTrigger" access="private" returntype="string" output="false">
    <cfargument name="triggerSource" type="string" required="true">
    <cfscript>
      var cleanTrigger = lCase(trim(arguments.triggerSource));
      return listFindNoCase("scheduled_worker,request_gate,migration_backfill,manual_test", cleanTrigger)
        ? cleanTrigger
        : "scheduled_worker";
    </cfscript>
  </cffunction>

  <cffunction name="expiredMessage" access="private" returntype="string" output="false">
    <cfscript>
      return "This Premium Trip has reached its 21-day access limit.";
    </cfscript>
  </cffunction>

  <cffunction name="queryValueOrNull" access="private" returntype="any" output="false">
    <cfargument name="q" type="query" required="true">
    <cfargument name="column" type="string" required="true">
    <cfargument name="row" type="numeric" required="true">
    <cfscript>
      if (
        arguments.q.recordCount GTE arguments.row
        AND listFindNoCase(arguments.q.columnList, arguments.column)
        AND !isNull(arguments.q[arguments.column][arguments.row])
      ) {
        return arguments.q[arguments.column][arguments.row];
      }
      return nullValue();
    </cfscript>
  </cffunction>

  <cffunction name="nullValue" access="private" returntype="any" output="false">
    <cfscript>
      return javacast("null", "");
    </cfscript>
  </cffunction>

</cfcomponent>
