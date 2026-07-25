<cfcomponent output="false">

  <cfset variables.datasource = "fpw">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfscript>
      variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="grantCredit" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="source" type="string" required="true">
    <cfargument name="idempotencyKey" type="string" required="true">
    <cfargument name="stripeCheckoutSessionId" type="string" required="false" default="">
    <cfargument name="stripePaymentIntentId" type="string" required="false" default="">
    <cfscript>
      var result = {};
      transaction {
        result = grantCreditInCurrentTransaction(
          userId = arguments.userId,
          source = arguments.source,
          idempotencyKey = arguments.idempotencyKey,
          stripeCheckoutSessionId = arguments.stripeCheckoutSessionId,
          stripePaymentIntentId = arguments.stripePaymentIntentId
        );
      }
      return result;
    </cfscript>
  </cffunction>

  <cffunction name="grantCreditInCurrentTransaction" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="source" type="string" required="true">
    <cfargument name="idempotencyKey" type="string" required="true">
    <cfargument name="stripeCheckoutSessionId" type="string" required="false" default="">
    <cfargument name="stripePaymentIntentId" type="string" required="false" default="">
    <cfscript>
      var cleanSource = lCase(trim(arguments.source));
      var cleanKey = trim(arguments.idempotencyKey);
      var cleanCheckoutId = trim(arguments.stripeCheckoutSessionId);
      var cleanPaymentIntentId = trim(arguments.stripePaymentIntentId);
      var grantIdentity = queryNew("");
      var granted = queryNew("");
      var wasCreated = false;

      if (arguments.userId LTE 0) {
        return failure("INVALID_USER_ID", "A valid member is required.");
      }
      if (!listFindNoCase("complimentary_signup,stripe_one_trip,promotion,admin_grant", cleanSource)) {
        return failure("INVALID_CREDIT_SOURCE", "The Premium Send Credit source is not supported.");
      }
      if (!len(cleanKey) OR len(cleanKey) GT 191) {
        return failure("INVALID_IDEMPOTENCY_KEY", "A valid Premium Send Credit idempotency key is required.");
      }

      // Inserts expose their generated id; duplicate unique keys reset LAST_INSERT_ID to zero without changing the canonical row.
      queryExecute(
        "INSERT INTO premium_send_credits (
           user_id,
           source,
           status,
           consumed_float_plan_id,
           idempotency_key,
           stripe_checkout_session_id,
           stripe_payment_intent_id,
           granted_at_utc,
           consumed_at_utc,
           created_at_utc,
           updated_at_utc
         ) VALUES (
           :userId,
           :source,
           'AVAILABLE',
           NULL,
           :idempotencyKey,
           :stripeCheckoutSessionId,
           :stripePaymentIntentId,
           UTC_TIMESTAMP(6),
           NULL,
           UTC_TIMESTAMP(6),
           UTC_TIMESTAMP(6)
         )
         ON DUPLICATE KEY UPDATE
           id = id + LAST_INSERT_ID(0)",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
          source = { value = cleanSource, cfsqltype = "cf_sql_varchar" },
          idempotencyKey = { value = cleanKey, cfsqltype = "cf_sql_varchar" },
          stripeCheckoutSessionId = nullableVarchar(cleanCheckoutId),
          stripePaymentIntentId = nullableVarchar(cleanPaymentIntentId)
        },
        { datasource = variables.datasource }
      );

      grantIdentity = queryExecute(
        "SELECT LAST_INSERT_ID() AS granted_id",
        {},
        { datasource = variables.datasource }
      );
      wasCreated = grantIdentity.recordCount GT 0 AND val(grantIdentity.granted_id[1]) GT 0;

      granted = queryExecute(
        "SELECT id, user_id, source, status, consumed_float_plan_id, granted_at_utc, consumed_at_utc
         FROM premium_send_credits
         WHERE idempotency_key = :idempotencyKey
         LIMIT 1
         FOR UPDATE",
        {
          idempotencyKey = { value = cleanKey, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );

      if (granted.recordCount EQ 0) {
        return failure("CREDIT_GRANT_FAILED", "The Premium Send Credit could not be created.");
      }
      if (val(granted.user_id[1]) NEQ val(arguments.userId) OR lCase(trim(granted.source[1])) NEQ cleanSource) {
        return failure("IDEMPOTENCY_CONFLICT", "The Premium Send Credit idempotency key is already assigned.");
      }
      return creditResponse(granted, !wasCreated);
    </cfscript>
  </cffunction>

  <cffunction name="countAvailableCredits" access="public" returntype="numeric" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var qCount = queryExecute(
        "SELECT COUNT(*) AS credit_count
         FROM premium_send_credits
         WHERE user_id = :userId
           AND status = 'AVAILABLE'",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      return qCount.recordCount ? val(qCount.credit_count[1]) : 0;
    </cfscript>
  </cffunction>

  <cffunction name="getCreditSourceSummary" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var result = structNew("ordered-casesensitive");
      var qSummary = queryNew("");
      var complimentaryGrantedCount = 0;
      var complimentaryAvailableCount = 0;
      var complimentaryConsumedCount = 0;
      var paidTripAvailableCount = 0;

      result["totalAvailableCount"] = 0;
      result["complimentaryGranted"] = false;
      result["complimentaryAvailable"] = false;
      result["complimentaryConsumed"] = false;
      result["paidTripAvailable"] = false;

      if (arguments.userId LTE 0) {
        return result;
      }

      qSummary = queryExecute(
        "SELECT
            SUM(CASE WHEN status = 'AVAILABLE' THEN 1 ELSE 0 END) AS total_available_count,
            SUM(CASE WHEN source = 'complimentary_signup' THEN 1 ELSE 0 END) AS complimentary_granted_count,
            SUM(CASE WHEN source = 'complimentary_signup' AND status = 'AVAILABLE' THEN 1 ELSE 0 END) AS complimentary_available_count,
            SUM(CASE WHEN source = 'complimentary_signup' AND status = 'CONSUMED' THEN 1 ELSE 0 END) AS complimentary_consumed_count,
            SUM(CASE WHEN source = 'stripe_one_trip' AND status = 'AVAILABLE' THEN 1 ELSE 0 END) AS paid_trip_available_count
         FROM premium_send_credits
         WHERE user_id = :userId",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );

      if (qSummary.recordCount GT 0) {
        result["totalAvailableCount"] = isNull(qSummary.total_available_count[1]) ? 0 : val(qSummary.total_available_count[1]);
        complimentaryGrantedCount = isNull(qSummary.complimentary_granted_count[1]) ? 0 : val(qSummary.complimentary_granted_count[1]);
        complimentaryAvailableCount = isNull(qSummary.complimentary_available_count[1]) ? 0 : val(qSummary.complimentary_available_count[1]);
        complimentaryConsumedCount = isNull(qSummary.complimentary_consumed_count[1]) ? 0 : val(qSummary.complimentary_consumed_count[1]);
        paidTripAvailableCount = isNull(qSummary.paid_trip_available_count[1]) ? 0 : val(qSummary.paid_trip_available_count[1]);
      }

      result["complimentaryGranted"] = complimentaryGrantedCount GT 0;
      result["complimentaryAvailable"] = complimentaryAvailableCount GT 0;
      result["complimentaryConsumed"] = complimentaryConsumedCount GT 0;
      result["paidTripAvailable"] = paidTripAvailableCount GT 0;
      return result;
    </cfscript>
  </cffunction>

  <cffunction name="lockNextAvailableCredit" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var qCredit = queryExecute(
        "SELECT id, user_id, source, status, consumed_float_plan_id, granted_at_utc, consumed_at_utc
         FROM premium_send_credits
         WHERE user_id = :userId
           AND status = 'AVAILABLE'
         ORDER BY granted_at_utc ASC, id ASC
         LIMIT 1
         FOR UPDATE",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );

      if (qCredit.recordCount EQ 0) {
        return failure("PREMIUM_SEND_CREDIT_REQUIRED", "No Premium Send Credit is available.");
      }
      return creditResponse(qCredit, false);
    </cfscript>
  </cffunction>

  <cffunction name="consumeLockedCredit" access="public" returntype="struct" output="false">
    <cfargument name="creditId" type="numeric" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      var qCredit = queryNew("");
      var qPlan = queryNew("");
      var creditUpdateResult = {};

      if (arguments.creditId LTE 0 OR arguments.userId LTE 0 OR arguments.floatPlanId LTE 0) {
        return failure("INVALID_CREDIT_CONSUMPTION", "A valid member, credit, and float plan are required.");
      }

      qPlan = queryExecute(
        "SELECT floatPlanId
         FROM floatplans
         WHERE floatPlanId = :floatPlanId
           AND userId = :userId
           AND UPPER(TRIM(`status`)) = 'ACTIVE'
         LIMIT 1
         FOR UPDATE",
        {
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
          userId = { value = toString(val(arguments.userId)), cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
      if (qPlan.recordCount EQ 0) {
        return failure("INVALID_FLOAT_PLAN_FOR_CREDIT", "The active float plan does not belong to this member.");
      }

      queryExecute(
        "UPDATE premium_send_credits
         SET status = 'CONSUMED',
             consumed_float_plan_id = :floatPlanId,
             consumed_at_utc = UTC_TIMESTAMP(6),
             updated_at_utc = UTC_TIMESTAMP(6)
         WHERE id = :creditId
           AND user_id = :userId
           AND status = 'AVAILABLE'
           AND consumed_float_plan_id IS NULL",
        {
          creditId = { value = arguments.creditId, cfsqltype = "cf_sql_bigint" },
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource, result = "local.creditUpdateResult" }
      );

      if (!structKeyExists(creditUpdateResult, "recordCount") OR val(creditUpdateResult.recordCount) NEQ 1) {
        return failure("CREDIT_CONSUMPTION_CONFLICT", "The Premium Send Credit could not be consumed.");
      }

      qCredit = queryExecute(
        "SELECT id, user_id, source, status, consumed_float_plan_id, granted_at_utc, consumed_at_utc
         FROM premium_send_credits
         WHERE id = :creditId
           AND user_id = :userId
         LIMIT 1",
        {
          creditId = { value = arguments.creditId, cfsqltype = "cf_sql_bigint" },
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );

      if (
        qCredit.recordCount EQ 0
        OR uCase(trim(qCredit.status[1])) NEQ "CONSUMED"
        OR val(qCredit.consumed_float_plan_id[1]) NEQ val(arguments.floatPlanId)
      ) {
        return failure("CREDIT_CONSUMPTION_CONFLICT", "The Premium Send Credit could not be consumed.");
      }
      return creditResponse(qCredit, false);
    </cfscript>
  </cffunction>

  <cffunction name="loadCompletedReceipt" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      var qReceipt = queryExecute(
        "SELECT id, user_id, float_plan_id, credit_id, access_source, recipient_count,
                original_response_json, committed_at_utc
         FROM premium_send_receipts
         WHERE user_id = :userId
           AND float_plan_id = :floatPlanId
         LIMIT 1",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      return receiptResponse(qReceipt);
    </cfscript>
  </cffunction>

  <cffunction name="lockCompletedReceipt" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      var qReceipt = queryExecute(
        "SELECT id, user_id, float_plan_id, credit_id, access_source, recipient_count,
                original_response_json, committed_at_utc
         FROM premium_send_receipts
         WHERE user_id = :userId
           AND float_plan_id = :floatPlanId
         LIMIT 1
         FOR UPDATE",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      return receiptResponse(qReceipt);
    </cfscript>
  </cffunction>

  <cffunction name="recordCompletedReceipt" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfargument name="creditId" type="numeric" required="false" default="0">
    <cfargument name="accessSource" type="string" required="true">
    <cfargument name="recipientCount" type="numeric" required="true">
    <cfargument name="response" type="struct" required="true">
    <cfscript>
      var cleanAccessSource = lCase(trim(arguments.accessSource));
      var qBinding = queryNew("");
      var qPlan = queryNew("");
      var entitlementAccess = {};

      if (!listFindNoCase("general_premium,premium_send_credit", cleanAccessSource)) {
        return failure("INVALID_SEND_ACCESS_SOURCE", "The Premium send access source is invalid.");
      }
      if (
        (cleanAccessSource EQ "general_premium" AND arguments.creditId GT 0)
        OR
        (cleanAccessSource EQ "premium_send_credit" AND arguments.creditId LTE 0)
      ) {
        return failure("INVALID_SEND_CREDIT_BINDING", "The Premium send receipt credit binding is invalid.");
      }
      if (arguments.recipientCount LTE 0) {
        return failure("INVALID_RECIPIENT_COUNT", "At least one recipient is required.");
      }

      qPlan = queryExecute(
        "SELECT floatPlanId
         FROM floatplans
         WHERE floatPlanId = :floatPlanId
           AND userId = :userIdText
           AND UPPER(TRIM(status)) = 'ACTIVE'
         LIMIT 1
         FOR UPDATE",
        {
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
          userIdText = { value = toString(val(arguments.userId)), cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
      if (qPlan.recordCount NEQ 1) {
        return failure("INVALID_SEND_PLAN_BINDING", "The Premium send receipt requires the member's ACTIVE float plan.");
      }

      if (cleanAccessSource EQ "premium_send_credit") {
        qBinding = queryExecute(
          "SELECT id
           FROM premium_send_credits
           WHERE id = :creditId
             AND user_id = :userId
             AND status = 'CONSUMED'
             AND consumed_float_plan_id = :floatPlanId
           LIMIT 1
           FOR UPDATE",
          {
            creditId = { value = arguments.creditId, cfsqltype = "cf_sql_bigint" },
            userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
            floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = variables.datasource }
        );
        if (qBinding.recordCount NEQ 1) {
          return failure("INVALID_SEND_CREDIT_BINDING", "The Premium send credit is not consumed by this member and float plan.");
        }
      } else {
        entitlementAccess = createEntitlementService().getCurrentAccess(arguments.userId);
        if (!structKeyExists(entitlementAccess, "hasPremium") OR !entitlementAccess.hasPremium) {
          return failure("GENERAL_PREMIUM_REQUIRED", "An active general Premium entitlement is required for this receipt.");
        }
      }

      queryExecute(
        "INSERT INTO premium_send_receipts (
           user_id,
           float_plan_id,
           credit_id,
           access_source,
           recipient_count,
           original_response_json,
           committed_at_utc,
           created_at_utc
         ) VALUES (
           :userId,
           :floatPlanId,
           :creditId,
           :accessSource,
           :recipientCount,
           :originalResponseJson,
           UTC_TIMESTAMP(6),
           UTC_TIMESTAMP(6)
         )",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
          creditId = nullableBigint(arguments.creditId),
          accessSource = { value = cleanAccessSource, cfsqltype = "cf_sql_varchar" },
          recipientCount = { value = arguments.recipientCount, cfsqltype = "cf_sql_integer" },
          originalResponseJson = { value = serializeJSON(arguments.response), cfsqltype = "cf_sql_longvarchar" }
        },
        { datasource = variables.datasource }
      );

      return loadCompletedReceipt(arguments.userId, arguments.floatPlanId);
    </cfscript>
  </cffunction>

  <cffunction name="hasExactTripOperationalAccess" access="public" returntype="boolean" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      var qAccess = queryExecute(
        "SELECT id
         FROM premium_send_credits
         WHERE user_id = :userId
           AND status = 'CONSUMED'
           AND consumed_float_plan_id = :floatPlanId
         LIMIT 1",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      return qAccess.recordCount GT 0;
    </cfscript>
  </cffunction>

  <cffunction name="getActiveTripOperationalSummary" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var qAccess = queryExecute(
        "SELECT
            c.id AS credit_id,
            c.source,
            c.consumed_float_plan_id
         FROM premium_send_credits c
         INNER JOIN floatplans fp
           ON fp.floatPlanId = c.consumed_float_plan_id
          AND fp.userId = :userIdText
         WHERE c.user_id = :userId
           AND c.status = 'CONSUMED'
           AND UPPER(TRIM(fp.status)) = 'ACTIVE'
         ORDER BY c.consumed_at_utc DESC, c.id DESC
         LIMIT 2",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
          userIdText = { value = toString(val(arguments.userId)), cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
      var result = {
        "hasActiveTripOperationalAccess" = false,
        "ambiguous" = qAccess.recordCount GT 1,
        "floatPlanId" = nullValue(),
        "creditId" = nullValue(),
        "creditSource" = ""
      };

      if (qAccess.recordCount EQ 1) {
        result.hasActiveTripOperationalAccess = true;
        result.floatPlanId = val(qAccess.consumed_float_plan_id[1]);
        result.creditId = val(qAccess.credit_id[1]);
        result.creditSource = lCase(trim(toString(qAccess.source[1])));
      }

      return result;
    </cfscript>
  </cffunction>

  <cffunction name="getTripOperationalAccess" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfscript>
      var entitlementAccess = createEntitlementService().getCurrentAccess(arguments.userId);
      var result = {
        "allowed" = false,
        "accessSource" = "none",
        "hasGeneralPremium" = false,
        "hasExactTripCredit" = false
      };

      if (structKeyExists(entitlementAccess, "hasPremium") AND entitlementAccess.hasPremium) {
        result.allowed = true;
        result.accessSource = "general_premium";
        result.hasGeneralPremium = true;
        return result;
      }

      result.hasExactTripCredit = hasExactTripOperationalAccess(arguments.userId, arguments.floatPlanId);
      if (result.hasExactTripCredit) {
        result.allowed = true;
        result.accessSource = "premium_send_credit";
      }
      return result;
    </cfscript>
  </cffunction>

  <cffunction name="receiptResponse" access="private" returntype="struct" output="false">
    <cfargument name="qReceipt" type="query" required="true">
    <cfscript>
      var response = {};
      if (arguments.qReceipt.recordCount EQ 0) {
        return {
          "SUCCESS" = true,
          "success" = true,
          "found" = false
        };
      }
      try {
        response = deserializeJSON(toString(arguments.qReceipt.original_response_json[1]));
      } catch (any invalidReceiptJson) {
        return failure("INVALID_SEND_RECEIPT", "The committed Premium send receipt is invalid.");
      }
      return {
        "SUCCESS" = true,
        "success" = true,
        "found" = true,
        "receiptId" = val(arguments.qReceipt.id[1]),
        "floatPlanId" = val(arguments.qReceipt.float_plan_id[1]),
        "creditId" = isNull(arguments.qReceipt.credit_id[1]) ? 0 : val(arguments.qReceipt.credit_id[1]),
        "accessSource" = trim(arguments.qReceipt.access_source[1]),
        "recipientCount" = val(arguments.qReceipt.recipient_count[1]),
        "committedAtUtc" = arguments.qReceipt.committed_at_utc[1],
        "originalResponse" = response
      };
    </cfscript>
  </cffunction>

  <cffunction name="creditResponse" access="private" returntype="struct" output="false">
    <cfargument name="qCredit" type="query" required="true">
    <cfargument name="idempotentReplay" type="boolean" required="true">
    <cfscript>
      return {
        "SUCCESS" = true,
        "success" = true,
        "creditId" = val(arguments.qCredit.id[1]),
        "userId" = val(arguments.qCredit.user_id[1]),
        "source" = lCase(trim(arguments.qCredit.source[1])),
        "status" = uCase(trim(arguments.qCredit.status[1])),
        "consumedFloatPlanId" = isNull(arguments.qCredit.consumed_float_plan_id[1]) ? 0 : val(arguments.qCredit.consumed_float_plan_id[1]),
        "grantedAtUtc" = arguments.qCredit.granted_at_utc[1],
        "consumedAtUtc" = isNull(arguments.qCredit.consumed_at_utc[1]) ? nullValue() : arguments.qCredit.consumed_at_utc[1],
        "idempotentReplay" = arguments.idempotentReplay
      };
    </cfscript>
  </cffunction>

  <cffunction name="failure" access="private" returntype="struct" output="false">
    <cfargument name="errorCode" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfscript>
      return {
        "SUCCESS" = false,
        "success" = false,
        "ERROR" = arguments.errorCode,
        "errorCode" = arguments.errorCode,
        "MESSAGE" = arguments.message,
        "message" = arguments.message
      };
    </cfscript>
  </cffunction>

  <cffunction name="nullableVarchar" access="private" returntype="struct" output="false">
    <cfargument name="value" type="string" required="true">
    <cfscript>
      if (len(trim(arguments.value))) {
        return { value = trim(arguments.value), cfsqltype = "cf_sql_varchar" };
      }
      return { value = javacast("null", ""), null = true, cfsqltype = "cf_sql_varchar" };
    </cfscript>
  </cffunction>

  <cffunction name="nullableBigint" access="private" returntype="struct" output="false">
    <cfargument name="value" type="numeric" required="true">
    <cfscript>
      if (arguments.value GT 0) {
        return { value = arguments.value, cfsqltype = "cf_sql_bigint" };
      }
      return { value = javacast("null", ""), null = true, cfsqltype = "cf_sql_bigint" };
    </cfscript>
  </cffunction>

  <cffunction name="nullValue" access="private" returntype="any" output="false">
    <cfscript>
      return javacast("null", "");
    </cfscript>
  </cffunction>

  <cffunction name="createEntitlementService" access="private" returntype="any" output="false">
    <cfscript>
      try {
        return createObject("component", "fpw.api.v1.MemberEntitlementService").init(variables.datasource);
      } catch (any e1) {
        return createObject("component", "api.v1.MemberEntitlementService").init(variables.datasource);
      }
    </cfscript>
  </cffunction>

</cfcomponent>
