<cfcomponent output="false">

  <cfset variables.datasource = "fpw">
  <cfset variables.checkoutService = "">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfargument name="checkoutService" type="any" required="false" default="">
    <cfscript>
      variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
      variables.checkoutService = arguments.checkoutService;
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="normalizeCode" access="public" returntype="string" output="false">
    <cfargument name="code" type="any" required="true">
    <cfscript>
      return uCase(trim(toString(arguments.code)));
    </cfscript>
  </cffunction>

  <cffunction name="hashPromoCode" access="public" returntype="string" output="false">
    <cfargument name="code" type="any" required="true">
    <cfscript>
      var normalized = normalizeCode(arguments.code);
      if (!len(normalized)) {
        return "";
      }
      return uCase(hash(normalized, "SHA-256", "UTF-8"));
    </cfscript>
  </cffunction>

  <cffunction name="validateCode" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="code" type="any" required="true">
    <cfargument name="nowUtc" type="any" required="false" default="">
    <cfscript>
      var codeHash = hashPromoCode(arguments.code);
      var nowValue = resolveNowUtc(arguments.nowUtc);
      var qPromo = queryNew("");

      if (arguments.userId LTE 0) {
        return ineligibleResponse("INVALID_USER_ID", "A valid user is required.");
      }
      if (!len(codeHash)) {
        return ineligibleResponse("PROMO_CODE_REQUIRED", "Enter a promo code.");
      }

      qPromo = loadPromoByHash(codeHash, false);
      return evaluatePromo(arguments.userId, codeHash, qPromo, nowValue);
    </cfscript>
  </cffunction>

  <cffunction name="redeemCode" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="code" type="any" required="true">
    <cfargument name="nowUtc" type="any" required="false" default="">
    <cfscript>
      var codeHash = hashPromoCode(arguments.code);
      var nowValue = resolveNowUtc(arguments.nowUtc);
      var qPromo = queryNew("");
      var validation = {};
      var promoId = 0;
      var promoType = "";
      var response = {};
      var entitlementId = 0;
      var entitlementResult = {};
      var trialDays = 0;
      var checkoutResult = {};
      var checkoutErrorCode = "";
      var checkoutSessionId = "";
      var pendingCheckout = {};

      if (arguments.userId LTE 0) {
        return ineligibleResponse("INVALID_USER_ID", "A valid user is required.");
      }
      if (!len(codeHash)) {
        logRedemptionAttempt(0, arguments.userId, "", "rejected", "PROMO_CODE_REQUIRED", 0, nowValue);
        return ineligibleResponse("PROMO_CODE_REQUIRED", "Enter a promo code.");
      }

      try {
        transaction {
          qPromo = loadPromoByHash(codeHash, true);
          validation = evaluatePromo(arguments.userId, codeHash, qPromo, nowValue);

          if (!validation.success) {
            logRedemptionAttempt(
              structKeyExists(validation, "promoCodeId") ? val(validation.promoCodeId) : 0,
              arguments.userId,
              codeHash,
              "rejected",
              validation.ERROR,
              0,
              nowValue
            );
            response = validation;
          } else {
            promoId = val(validation.promoCodeId);
            promoType = lCase(trim(validation.promoType));

            if (promoType EQ "founder_lifetime") {
              entitlementId = findActiveFounderEntitlement(arguments.userId);
              if (entitlementId LTE 0) {
                entitlementResult = new fpw.api.v1.MemberEntitlementService().init(variables.datasource)
                  .createFounderLifetimeEntitlement(arguments.userId);
                if (!structKeyExists(entitlementResult, "SUCCESS") OR entitlementResult.SUCCESS NEQ true) {
                  throw(type = "PromoCodeService.FounderEntitlementFailed", message = "Founder entitlement could not be created.");
                }
                entitlementId = val(entitlementResult.entitlementId);
              }

              incrementRedemptionCount(promoId);
              logRedemptionAttempt(promoId, arguments.userId, codeHash, "redeemed", "", entitlementId, nowValue);
              response = eligibleResponse(qPromo, "founder_lifetime_redeemed", "Founders Lifetime Premium is active.");
              response.entitlementId = entitlementId;
              response.redeemed = true;
            } else if (promoType EQ "stripe_free_months") {
              trialDays = resolveTrialDays(validation.durationMonths);
              if (trialDays LTE 0) {
                logRedemptionAttempt(promoId, arguments.userId, codeHash, "rejected", "PROMO_INVALID_TRIAL_DURATION", 0, nowValue);
                response = ineligibleResponse("PROMO_INVALID_TRIAL_DURATION", "Free trial duration is not supported.", qPromo);
              } else {
                pendingCheckout = continuePendingFreeTrialCheckout(arguments.userId, nowValue);
                if (structKeyExists(pendingCheckout, "response") AND isStruct(pendingCheckout.response)) {
                  response = pendingCheckout.response;
                } else {
                checkoutResult = getCheckoutService().createFreeTrialCheckoutSession(
                  arguments.userId,
                  trialDays,
                  {
                    promoType = "stripe_free_months"
                  }
                );

                if (!structKeyExists(checkoutResult, "SUCCESS") OR checkoutResult.SUCCESS NEQ true) {
                  checkoutErrorCode = structKeyExists(checkoutResult, "ERROR") ? trim(toString(checkoutResult.ERROR)) : "STRIPE_CHECKOUT_FAILED";
                  logRedemptionAttempt(promoId, arguments.userId, codeHash, "rejected", checkoutErrorCode, 0, nowValue);
                  response = ineligibleResponse(checkoutErrorCode, structKeyExists(checkoutResult, "MESSAGE") ? trim(toString(checkoutResult.MESSAGE)) : "Stripe checkout session could not be created.", qPromo);
                } else {
                  checkoutSessionId = structKeyExists(checkoutResult, "stripeCheckoutSessionId") ? trim(toString(checkoutResult.stripeCheckoutSessionId)) : "";
                  if (!len(checkoutSessionId) AND structKeyExists(checkoutResult, "STRIPE_CHECKOUT_SESSION_ID")) {
                    checkoutSessionId = trim(toString(checkoutResult.STRIPE_CHECKOUT_SESSION_ID));
                  }

                  logRedemptionAttempt(promoId, arguments.userId, codeHash, "checkout_created", "", 0, nowValue, checkoutSessionId);
                  response = eligibleResponse(qPromo, "stripe_trial_checkout", "No-credit-card trial checkout is ready.");
                  response.redeemed = false;
                  response.checkoutRequired = true;
                  response.reusedCheckoutSession = false;
                  response.REUSED_CHECKOUT_SESSION = false;
                  response.trialDays = trialDays;
                  response.TRIAL_DAYS = trialDays;
                  response.checkoutUrl = structKeyExists(checkoutResult, "checkoutUrl") ? trim(toString(checkoutResult.checkoutUrl)) : "";
                  response.CHECKOUT_URL = structKeyExists(checkoutResult, "CHECKOUT_URL") ? trim(toString(checkoutResult.CHECKOUT_URL)) : response.checkoutUrl;
                  response.stripeCheckoutSessionId = checkoutSessionId;
                  response.STRIPE_CHECKOUT_SESSION_ID = checkoutSessionId;
                }
                }
              }
            } else {
              logRedemptionAttempt(promoId, arguments.userId, codeHash, "rejected", "PROMO_UNSUPPORTED_TYPE", 0, nowValue);
              response = ineligibleResponse("PROMO_UNSUPPORTED_TYPE", "Promo code type is not supported.");
            }
          }
        }
      } catch (any err) {
        response = ineligibleResponse("PROMO_REDEMPTION_FAILED", "Promo code redemption failed.");
      }

      return response;
    </cfscript>
  </cffunction>

  <cffunction name="loadPromoByHash" access="private" returntype="query" output="false">
    <cfargument name="codeHash" type="string" required="true">
    <cfargument name="forUpdate" type="boolean" required="false" default="false">
    <cfscript>
      return queryExecute(
        "SELECT
            promo_code_id,
            code_hash,
            promo_type,
            status,
            starts_at_utc,
            expires_at_utc,
            max_redemptions,
            redemptions_count,
            one_per_user,
            duration_months,
            stripe_promotion_code_id,
            entitlement_type,
            entitlement_source
         FROM fpw_promo_codes
         WHERE code_hash = :codeHash
         LIMIT 1" & (arguments.forUpdate ? " FOR UPDATE" : ""),
        {
          codeHash = { value = trim(arguments.codeHash), cfsqltype = "cf_sql_char" }
        },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="evaluatePromo" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="codeHash" type="string" required="true">
    <cfargument name="qPromo" type="query" required="true">
    <cfargument name="nowUtc" type="date" required="true">
    <cfscript>
      var statusValue = "";
      var promoType = "";
      var maxRedemptions = 0;
      var hasMaxRedemptions = false;
      var redemptionCount = 0;
      var onePerUser = true;

      if (arguments.qPromo.recordCount EQ 0) {
        return ineligibleResponse("PROMO_CODE_NOT_FOUND", "Promo code was not found.");
      }

      statusValue = lCase(trim(toString(arguments.qPromo.status[1])));
      promoType = lCase(trim(toString(arguments.qPromo.promo_type[1])));
      maxRedemptions = val(arguments.qPromo.max_redemptions[1]);
      hasMaxRedemptions = !isNull(arguments.qPromo.max_redemptions[1]) AND maxRedemptions GT 0;
      redemptionCount = val(arguments.qPromo.redemptions_count[1]);
      onePerUser = truthy(arguments.qPromo.one_per_user[1]);

      if (statusValue NEQ "active") {
        return ineligibleResponse("PROMO_CODE_DISABLED", "Promo code is not active.", arguments.qPromo);
      }
      if (isDate(arguments.qPromo.starts_at_utc[1]) AND dateCompare(arguments.qPromo.starts_at_utc[1], arguments.nowUtc) GT 0) {
        return ineligibleResponse("PROMO_NOT_STARTED", "Promo code is not active yet.", arguments.qPromo);
      }
      if (!isNull(arguments.qPromo.expires_at_utc[1]) AND isDate(arguments.qPromo.expires_at_utc[1]) AND dateCompare(arguments.qPromo.expires_at_utc[1], arguments.nowUtc) LT 0) {
        return ineligibleResponse("PROMO_EXPIRED", "Promo code has expired.", arguments.qPromo);
      }
      if (hasMaxRedemptions AND redemptionCount GTE maxRedemptions) {
        return ineligibleResponse("PROMO_MAX_REDEMPTIONS_REACHED", "Promo code has reached its redemption limit.", arguments.qPromo);
      }
      if (onePerUser AND hasUserRedeemedPromo(arguments.userId, val(arguments.qPromo.promo_code_id[1]))) {
        return ineligibleResponse("PROMO_ALREADY_REDEEMED", "Promo code has already been used for this account.", arguments.qPromo);
      }
      if (promoType EQ "stripe_free_months" AND resolveTrialDays(arguments.qPromo.duration_months[1]) LTE 0) {
        return ineligibleResponse("PROMO_INVALID_TRIAL_DURATION", "Free trial duration is not supported.", arguments.qPromo);
      }
      if (promoType EQ "stripe_free_months" AND hasUserUsedStripeFreeTrial(arguments.userId)) {
        return ineligibleResponse("PROMO_FREE_TRIAL_ALREADY_USED", "A free trial has already been used for this account.", arguments.qPromo);
      }
      if (!listFindNoCase("founder_lifetime,stripe_free_months", promoType)) {
        return ineligibleResponse("PROMO_UNSUPPORTED_TYPE", "Promo code type is not supported.", arguments.qPromo);
      }

      return eligibleResponse(
        arguments.qPromo,
        promoType EQ "founder_lifetime" ? "redeem_founder_lifetime" : "stripe_checkout_required",
        promoType EQ "founder_lifetime" ? "Founders Lifetime Premium is available." : "Promo code is available for Stripe checkout."
      );
    </cfscript>
  </cffunction>

  <cffunction name="eligibleResponse" access="private" returntype="struct" output="false">
    <cfargument name="qPromo" type="query" required="true">
    <cfargument name="nextAction" type="string" required="true">
    <cfargument name="displayMessage" type="string" required="true">
    <cfscript>
      var out = {
        "SUCCESS" = true,
        "success" = true,
        "eligible" = true,
        "promoCodeId" = val(arguments.qPromo.promo_code_id[1]),
        "promoType" = lCase(trim(toString(arguments.qPromo.promo_type[1]))),
        "nextAction" = arguments.nextAction,
        "displayMessage" = arguments.displayMessage,
        "durationMonths" = queryValueOrNull(arguments.qPromo, "duration_months", 1),
        "stripePromotionCodeId" = queryValueOrNull(arguments.qPromo, "stripe_promotion_code_id", 1),
        "entitlementType" = trim(toString(arguments.qPromo.entitlement_type[1])),
        "entitlementSource" = queryValueOrNull(arguments.qPromo, "entitlement_source", 1),
        "ERROR" = "",
        "errorCode" = ""
      };
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="ineligibleResponse" access="private" returntype="struct" output="false">
    <cfargument name="errorCode" type="string" required="true">
    <cfargument name="displayMessage" type="string" required="true">
    <cfargument name="qPromo" type="query" required="false" default="#queryNew('')#">
    <cfscript>
      var out = {
        "SUCCESS" = false,
        "success" = false,
        "eligible" = false,
        "promoType" = "",
        "nextAction" = "",
        "displayMessage" = arguments.displayMessage,
        "ERROR" = arguments.errorCode,
        "errorCode" = arguments.errorCode
      };
      if (arguments.qPromo.recordCount GT 0) {
        out.promoCodeId = val(arguments.qPromo.promo_code_id[1]);
        out.promoType = lCase(trim(toString(arguments.qPromo.promo_type[1])));
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="hasUserRedeemedPromo" access="private" returntype="boolean" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="promoCodeId" type="numeric" required="true">
    <cfscript>
      var qExisting = queryExecute(
        "SELECT COUNT(*) AS redemption_count
         FROM fpw_promo_redemptions
         WHERE user_id = :userId
           AND promo_code_id = :promoCodeId
           AND result = 'redeemed'",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
          promoCodeId = { value = arguments.promoCodeId, cfsqltype = "cf_sql_bigint" }
        },
        { datasource = variables.datasource }
      );
      return qExisting.recordCount GT 0 AND val(qExisting.redemption_count[1]) GT 0;
    </cfscript>
  </cffunction>

  <cffunction name="hasUserUsedStripeFreeTrial" access="private" returntype="boolean" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var qExisting = queryExecute(
        "SELECT COUNT(*) AS trial_count
         FROM fpw_promo_redemptions r
         INNER JOIN fpw_promo_codes p ON p.promo_code_id = r.promo_code_id
         WHERE r.user_id = :userId
           AND p.promo_type = 'stripe_free_months'
           AND r.result = 'redeemed'",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      return qExisting.recordCount GT 0 AND val(qExisting.trial_count[1]) GT 0;
    </cfscript>
  </cffunction>

  <cffunction name="continuePendingFreeTrialCheckout" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="nowUtc" type="date" required="true">
    <cfscript>
      var qPending = loadPendingFreeTrialCheckout(arguments.userId);
      var sessionId = "";
      var lookup = {};
      var statusValue = "";
      var checkoutUrl = "";
      var trialDays = 0;
      var response = {};

      if (qPending.recordCount EQ 0) {
        return { "found" = false, "canCreate" = true };
      }

      sessionId = trim(toString(qPending.stripe_checkout_session_id[1]));
      if (!len(sessionId)) {
        return { "found" = true, "canCreate" = true };
      }

      lookup = getCheckoutService().retrieveCheckoutSession(sessionId);
      if (!structKeyExists(lookup, "SUCCESS") OR lookup.SUCCESS NEQ true) {
        if (structKeyExists(lookup, "ERROR") AND lookup.ERROR EQ "STRIPE_CHECKOUT_SESSION_NOT_FOUND") {
          return { "found" = true, "canCreate" = true };
        }
        return {
          "found" = true,
          "canCreate" = false,
          "response" = ineligibleResponse("STRIPE_CHECKOUT_LOOKUP_FAILED", "Free-trial checkout could not be checked. Please try again shortly.", qPending)
        };
      }

      statusValue = structKeyExists(lookup, "status") ? lCase(trim(toString(lookup.status))) : "";
      if (!len(statusValue) AND structKeyExists(lookup, "STATUS")) {
        statusValue = lCase(trim(toString(lookup.STATUS)));
      }

      if (statusValue EQ "open") {
        checkoutUrl = structKeyExists(lookup, "checkoutUrl") ? trim(toString(lookup.checkoutUrl)) : "";
        if (!len(checkoutUrl) AND structKeyExists(lookup, "CHECKOUT_URL")) {
          checkoutUrl = trim(toString(lookup.CHECKOUT_URL));
        }
        trialDays = resolveTrialDays(qPending.duration_months[1]);
        response = eligibleResponse(qPending, "stripe_trial_checkout", "Continue your free-trial checkout. No credit card is required to start.");
        response.redeemed = false;
        response.checkoutRequired = true;
        response.reusedCheckoutSession = true;
        response.REUSED_CHECKOUT_SESSION = true;
        response.trialDays = trialDays;
        response.TRIAL_DAYS = trialDays;
        response.checkoutUrl = checkoutUrl;
        response.CHECKOUT_URL = checkoutUrl;
        response.stripeCheckoutSessionId = sessionId;
        response.STRIPE_CHECKOUT_SESSION_ID = sessionId;
        return {
          "found" = true,
          "canCreate" = false,
          "response" = response
        };
      }

      if (listFindNoCase("expired", statusValue)) {
        return { "found" = true, "canCreate" = true };
      }

      return {
        "found" = true,
        "canCreate" = false,
        "response" = ineligibleResponse("STRIPE_CHECKOUT_CONFIRMATION_PENDING", "Free-trial checkout is being confirmed. Please refresh shortly.", qPending)
      };
    </cfscript>
  </cffunction>

  <cffunction name="loadPendingFreeTrialCheckout" access="private" returntype="query" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      return queryExecute(
        "SELECT
            p.promo_code_id,
            p.code_hash,
            p.promo_type,
            p.status,
            p.starts_at_utc,
            p.expires_at_utc,
            p.max_redemptions,
            p.redemptions_count,
            p.one_per_user,
            p.duration_months,
            p.stripe_promotion_code_id,
            p.entitlement_type,
            p.entitlement_source,
            r.stripe_checkout_session_id
         FROM fpw_promo_redemptions r
         INNER JOIN fpw_promo_codes p ON p.promo_code_id = r.promo_code_id
         WHERE r.user_id = :userId
           AND p.promo_type = 'stripe_free_months'
           AND r.result = 'checkout_created'
           AND r.stripe_checkout_session_id IS NOT NULL
           AND r.stripe_checkout_session_id <> ''
         ORDER BY r.created_at_utc DESC, r.redemption_id DESC
         LIMIT 1",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="findActiveFounderEntitlement" access="private" returntype="numeric" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var qFounder = queryExecute(
        "SELECT id
         FROM member_entitlements
         WHERE user_id = :userId
           AND entitlement_type = 'premium'
           AND source = 'founder_lifetime'
           AND status = 'active'
           AND starts_at_utc <= UTC_TIMESTAMP()
           AND (expires_at_utc IS NULL OR expires_at_utc >= UTC_TIMESTAMP())
         ORDER BY id DESC
         LIMIT 1",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      return qFounder.recordCount ? val(qFounder.id[1]) : 0;
    </cfscript>
  </cffunction>

  <cffunction name="incrementRedemptionCount" access="private" returntype="void" output="false">
    <cfargument name="promoCodeId" type="numeric" required="true">
    <cfscript>
      queryExecute(
        "UPDATE fpw_promo_codes
         SET redemptions_count = redemptions_count + 1,
             updated_at_utc = UTC_TIMESTAMP()
         WHERE promo_code_id = :promoCodeId",
        {
          promoCodeId = { value = arguments.promoCodeId, cfsqltype = "cf_sql_bigint" }
        },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="resolveTrialDays" access="private" returntype="numeric" output="false">
    <cfargument name="durationMonths" type="any" required="true">
    <cfscript>
      var monthsValue = (!isNull(arguments.durationMonths) AND isNumeric(arguments.durationMonths)) ? int(val(arguments.durationMonths)) : 0;
      switch (monthsValue) {
        case 1:
          return 30;
        case 2:
          return 60;
        default:
          return 0;
      }
    </cfscript>
  </cffunction>

  <cffunction name="getCheckoutService" access="private" returntype="any" output="false">
    <cfscript>
      if (isObject(variables.checkoutService) OR isStruct(variables.checkoutService)) {
        return variables.checkoutService;
      }
      return new fpw.api.v1.StripeCheckoutService().init(variables.datasource);
    </cfscript>
  </cffunction>

  <cffunction name="logRedemptionAttempt" access="private" returntype="void" output="false">
    <cfargument name="promoCodeId" type="numeric" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="codeHash" type="string" required="true">
    <cfargument name="result" type="string" required="true">
    <cfargument name="errorCode" type="string" required="true">
    <cfargument name="entitlementId" type="numeric" required="true">
    <cfargument name="nowUtc" type="date" required="true">
    <cfargument name="stripeCheckoutSessionId" type="string" required="false" default="">
    <cfscript>
      queryExecute(
        "INSERT INTO fpw_promo_redemptions (
           promo_code_id,
           user_id,
           attempt_code_hash,
           result,
           error_code,
           entitlement_id,
           stripe_checkout_session_id,
           attempted_at_utc,
           redeemed_at_utc,
           created_at_utc,
           updated_at_utc
         ) VALUES (
           :promoCodeId,
           :userId,
           :codeHash,
           :result,
           :errorCode,
           :entitlementId,
           :stripeCheckoutSessionId,
           :attemptedAtUtc,
           :redeemedAtUtc,
           UTC_TIMESTAMP(),
           UTC_TIMESTAMP()
         )",
        {
          promoCodeId = { value = arguments.promoCodeId, cfsqltype = "cf_sql_bigint", null = arguments.promoCodeId LTE 0 },
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
          codeHash = { value = trim(arguments.codeHash), cfsqltype = "cf_sql_char", null = !len(trim(arguments.codeHash)) },
          result = { value = trim(arguments.result), cfsqltype = "cf_sql_varchar" },
          errorCode = { value = trim(arguments.errorCode), cfsqltype = "cf_sql_varchar", null = !len(trim(arguments.errorCode)) },
          entitlementId = { value = arguments.entitlementId, cfsqltype = "cf_sql_bigint", null = arguments.entitlementId LTE 0 },
          stripeCheckoutSessionId = { value = trim(arguments.stripeCheckoutSessionId), cfsqltype = "cf_sql_varchar", null = !len(trim(arguments.stripeCheckoutSessionId)) },
          attemptedAtUtc = { value = arguments.nowUtc, cfsqltype = "cf_sql_timestamp" },
          redeemedAtUtc = { value = arguments.nowUtc, cfsqltype = "cf_sql_timestamp", null = !listFindNoCase("redeemed", arguments.result) }
        },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="resolveNowUtc" access="private" returntype="date" output="false">
    <cfargument name="nowUtc" type="any" required="false" default="">
    <cfscript>
      if (isDate(arguments.nowUtc)) {
        return arguments.nowUtc;
      }
      return currentUtc();
    </cfscript>
  </cffunction>

  <cffunction name="currentUtc" access="private" returntype="date" output="false">
    <cfscript>
      return dateConvert("local2utc", now());
    </cfscript>
  </cffunction>

  <cffunction name="truthy" access="private" returntype="boolean" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      return listFindNoCase("1,true,yes,y,on", trim(toString(arguments.value))) GT 0;
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
      return javacast("null", "");
    </cfscript>
  </cffunction>

</cfcomponent>
