<cfcomponent output="false">

  <cfset variables.datasource = "fpw">
  <cfset variables.configService = "">
  <cfset variables.stripeTransport = "">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfargument name="configService" type="any" required="false" default="">
    <cfargument name="stripeTransport" type="any" required="false" default="">
    <cfscript>
      variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
      variables.configService = (isObject(arguments.configService) OR isStruct(arguments.configService))
        ? arguments.configService
        : new fpw.api.v1.StripeConfigService().init();
      variables.stripeTransport = arguments.stripeTransport;
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="createCheckoutSession" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="interval" type="string" required="true">
    <cfargument name="floatPlanId" type="numeric" required="false" default="0">
    <cfargument name="returnNonce" type="string" required="false" default="">
    <cfscript>
      var userIdValue = int(val(arguments.userId));
      var intervalValue = lCase(trim(arguments.interval));
      var secretKey = "";
      var selectedPriceId = "";
      var successUrl = "";
      var cancelUrl = "";
      var qUser = queryNew("");
      var customerResult = {};
      var stripeCustomerId = "";
      var requestPayload = {};
      var stripeResult = {};
      var stripePayload = {};
      var checkoutUrl = "";
      var checkoutSessionId = "";
      var response = {};

      if (userIdValue LTE 0) {
        return errorResponse("INVALID_USER_ID", "Session user is invalid.");
      }
      if (!listFindNoCase("monthly,yearly,three_day_pass,one_trip", intervalValue)) {
        return errorResponse("INVALID_PRICE_SELECTOR", "Choose monthly, yearly, one-trip, or 3-Day Pass Premium billing.");
      }
      secretKey = readConfigValue("secretKey", "getSecretKey");
      selectedPriceId = resolvePriceId(intervalValue);
      successUrl = readConfigValue("checkoutSuccessUrl", "getCheckoutSuccessUrl");
      cancelUrl = readConfigValue("checkoutCancelUrl", "getCheckoutCancelUrl");
      if (!len(secretKey) OR !len(selectedPriceId) OR !len(successUrl) OR !len(cancelUrl)) {
        return errorResponse("STRIPE_CONFIG_MISSING", "Stripe checkout configuration is incomplete.");
      }

      if (intervalValue EQ "three_day_pass") {
        requestPayload = buildStripeThreeDayPassRequestPayload(userIdValue, selectedPriceId, successUrl, cancelUrl);
      } else if (intervalValue EQ "one_trip") {
        qUser = loadStripeUser(userIdValue);
        if (qUser.recordCount EQ 0) {
          return errorResponse("USER_NOT_FOUND", "Account could not be loaded for Checkout.");
        }
        customerResult = ensureStripeCustomerForUser(userIdValue, qUser, secretKey, "one_trip_checkout");
        if (!structKeyExists(customerResult, "SUCCESS") OR customerResult.SUCCESS NEQ true) {
          return customerResult;
        }
        stripeCustomerId = trim(toString(customerResult.stripeCustomerId));
        requestPayload = buildStripeOneTripRequestPayload(
          userIdValue,
          selectedPriceId,
          successUrl,
          cancelUrl,
          arguments.floatPlanId,
          arguments.returnNonce,
          stripeCustomerId
        );
      } else {
        requestPayload = buildStripeRequestPayload(userIdValue, selectedPriceId, successUrl, cancelUrl);
      }
      stripeResult = executeStripeCheckoutRequest(requestPayload, secretKey);
      if (!structKeyExists(stripeResult, "SUCCESS") OR stripeResult.SUCCESS NEQ true) {
        response = errorResponse("STRIPE_CHECKOUT_FAILED", "Stripe checkout session could not be created.");
        addStripeCheckoutDebug(response, stripeResult, requestPayload, "checkout_session", userIdValue, selectedPriceId);
        return response;
      }

      stripePayload = normalizeStripePayload(stripeResult);
      checkoutUrl = readString(stripePayload, "url");
      checkoutSessionId = readString(stripePayload, "id");

      if (!len(checkoutUrl) OR !len(checkoutSessionId)) {
        return errorResponse("STRIPE_CHECKOUT_FAILED", "Stripe checkout session response was incomplete.");
      }

      response = structNew("ordered-casesensitive");
      response["SUCCESS"] = true;
      response["success"] = true;
      response["MESSAGE"] = "Checkout session created.";
      response["message"] = "Checkout session created.";
      response["CHECKOUT_URL"] = checkoutUrl;
      response["checkoutUrl"] = checkoutUrl;
      response["STRIPE_CHECKOUT_SESSION_ID"] = checkoutSessionId;
      response["stripeCheckoutSessionId"] = checkoutSessionId;
      return response;
    </cfscript>
  </cffunction>

  <cffunction name="createPortalSession" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var userIdValue = int(val(arguments.userId));
      var stripeCustomerId = "";
      var secretKey = "";
      var returnUrl = "";
      var requestPayload = {};
      var stripeResult = {};
      var stripePayload = {};
      var portalUrl = "";
      var response = {};

      if (userIdValue LTE 0) {
        return errorResponse("INVALID_USER_ID", "Session user is invalid.");
      }

      stripeCustomerId = loadStripeCustomerIdForUser(userIdValue);
      if (!len(stripeCustomerId)) {
        return errorResponse("NO_BILLING_CUSTOMER", "No Stripe billing customer is available for this account.");
      }

      secretKey = readConfigValue("secretKey", "getSecretKey");
      returnUrl = readConfigValue("billingPortalReturnUrl", "getBillingPortalReturnUrl");
      if (!len(secretKey) OR !len(returnUrl)) {
        return errorResponse("STRIPE_CONFIG_MISSING", "Stripe billing portal configuration is incomplete.");
      }

      requestPayload = buildStripePortalRequestPayload(stripeCustomerId, returnUrl);
      stripeResult = executeStripePortalRequest(requestPayload, secretKey);
      if (!structKeyExists(stripeResult, "SUCCESS") OR stripeResult.SUCCESS NEQ true) {
        addStripePortalDebug(stripeResult, "billing_portal_session_create", userIdValue, stripeCustomerId, returnUrl);
        return errorResponse("STRIPE_PORTAL_FAILED", "Stripe billing portal session could not be created.");
      }

      stripePayload = normalizeStripePayload(stripeResult);
      portalUrl = readString(stripePayload, "url");
      if (!len(portalUrl)) {
        return errorResponse("STRIPE_PORTAL_FAILED", "Stripe billing portal session response was incomplete.");
      }

      response = structNew("ordered-casesensitive");
      response["SUCCESS"] = true;
      response["success"] = true;
      response["MESSAGE"] = "Billing portal session created.";
      response["message"] = "Billing portal session created.";
      response["PORTAL_URL"] = portalUrl;
      response["portalUrl"] = portalUrl;
      return response;
    </cfscript>
  </cffunction>

  <cffunction name="createFreeTrialCheckoutSession" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="trialDays" type="numeric" required="true">
    <cfargument name="promoMetadata" type="struct" required="false" default="#structNew()#">
    <cfscript>
      var userIdValue = int(val(arguments.userId));
      var trialDaysValue = int(val(arguments.trialDays));
      var secretKey = "";
      var selectedPriceId = "";
      var successUrl = "";
      var cancelUrl = "";
      var requestPayload = {};
      var stripeResult = {};
      var stripePayload = {};
      var checkoutUrl = "";
      var checkoutSessionId = "";
      var response = {};

      if (userIdValue LTE 0) {
        return errorResponse("INVALID_USER_ID", "Session user is invalid.");
      }
      if (!listFind("30,60", toString(trialDaysValue))) {
        return errorResponse("INVALID_TRIAL_DURATION", "Free trial duration is not supported.");
      }

      secretKey = readConfigValue("secretKey", "getSecretKey");
      selectedPriceId = readConfigValue("premiumMonthlyPriceId", "getPremiumMonthlyPriceId");
      successUrl = readConfigValue("checkoutSuccessUrl", "getCheckoutSuccessUrl");
      cancelUrl = readConfigValue("checkoutCancelUrl", "getCheckoutCancelUrl");
      if (!len(secretKey) OR !len(selectedPriceId) OR !len(successUrl) OR !len(cancelUrl)) {
        return errorResponse("STRIPE_CONFIG_MISSING", "Stripe checkout configuration is incomplete.");
      }

      requestPayload = buildStripeTrialRequestPayload(userIdValue, selectedPriceId, successUrl, cancelUrl, trialDaysValue, arguments.promoMetadata);
      stripeResult = executeStripeCheckoutRequest(requestPayload, secretKey);
      if (!structKeyExists(stripeResult, "SUCCESS") OR stripeResult.SUCCESS NEQ true) {
        response = errorResponse("STRIPE_CHECKOUT_FAILED", "Stripe checkout session could not be created.");
        addStripeCheckoutDebug(response, stripeResult, requestPayload, "free_trial_checkout_session", userIdValue, selectedPriceId);
        return response;
      }

      stripePayload = normalizeStripePayload(stripeResult);
      checkoutUrl = readString(stripePayload, "url");
      checkoutSessionId = readString(stripePayload, "id");

      if (!len(checkoutUrl) OR !len(checkoutSessionId)) {
        return errorResponse("STRIPE_CHECKOUT_FAILED", "Stripe checkout session response was incomplete.");
      }

      response = structNew("ordered-casesensitive");
      response["SUCCESS"] = true;
      response["success"] = true;
      response["MESSAGE"] = "Trial checkout session created.";
      response["message"] = "Trial checkout session created.";
      response["CHECKOUT_URL"] = checkoutUrl;
      response["checkoutUrl"] = checkoutUrl;
      response["STRIPE_CHECKOUT_SESSION_ID"] = checkoutSessionId;
      response["stripeCheckoutSessionId"] = checkoutSessionId;
      response["TRIAL_DAYS"] = trialDaysValue;
      response["trialDays"] = trialDaysValue;
      return response;
    </cfscript>
  </cffunction>

  <cffunction name="startCustomNoCardTrialSubscription" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="trialDays" type="numeric" required="true">
    <cfargument name="promoMetadata" type="struct" required="false" default="#structNew()#">
    <cfscript>
      var userIdValue = int(val(arguments.userId));
      var trialDaysValue = int(val(arguments.trialDays));
      var secretKey = "";
      var selectedPriceId = "";
      var qUser = queryNew("");
      var customerResult = {};
      var stripeCustomerId = "";
      var duplicateCheck = {};
      var requestPayload = {};
      var stripeResult = {};
      var stripePayload = {};
      var subscriptionId = "";
      var subscriptionStatus = "";
      var response = {};

      if (userIdValue LTE 0) {
        return errorResponse("INVALID_USER_ID", "Session user is invalid.");
      }
      if (!listFind("30,60", toString(trialDaysValue))) {
        return errorResponse("INVALID_TRIAL_DURATION", "Free trial duration is not supported.");
      }

      secretKey = readConfigValue("secretKey", "getSecretKey");
      selectedPriceId = readConfigValue("premiumMonthlyPriceId", "getPremiumMonthlyPriceId");
      if (!len(secretKey) OR !len(selectedPriceId)) {
        return errorResponse("STRIPE_CONFIG_MISSING", "Stripe subscription configuration is incomplete.");
      }

      qUser = loadStripeUser(userIdValue);
      if (qUser.recordCount EQ 0) {
        return errorResponse("USER_NOT_FOUND", "Account could not be loaded for trial activation.");
      }

      duplicateCheck = findLocalTrialOrPremiumBlock(userIdValue);
      if (structKeyExists(duplicateCheck, "blocked") AND duplicateCheck.blocked) {
        return duplicateCheck.response;
      }

      customerResult = ensureStripeCustomerForUser(userIdValue, qUser, secretKey);
      if (!structKeyExists(customerResult, "SUCCESS") OR customerResult.SUCCESS NEQ true) {
        return customerResult;
      }
      stripeCustomerId = trim(toString(customerResult.stripeCustomerId));

      duplicateCheck = findExistingTrialOrPremiumBlock(userIdValue, stripeCustomerId, selectedPriceId, secretKey);
      if (structKeyExists(duplicateCheck, "blocked") AND duplicateCheck.blocked) {
        return duplicateCheck.response;
      }

      requestPayload = buildStripeDirectTrialSubscriptionPayload(
        userIdValue,
        qUser,
        stripeCustomerId,
        selectedPriceId,
        trialDaysValue,
        arguments.promoMetadata
      );
      stripeResult = executeStripeSubscriptionCreateRequest(requestPayload, secretKey);
      if (!structKeyExists(stripeResult, "SUCCESS") OR stripeResult.SUCCESS NEQ true) {
        response = errorResponse("STRIPE_SUBSCRIPTION_FAILED", "Stripe trial subscription could not be created.");
        addStripeCheckoutDebug(response, stripeResult, requestPayload, "custom_no_card_trial_subscription", userIdValue, selectedPriceId);
        return response;
      }

      stripePayload = normalizeStripePayload(stripeResult);
      subscriptionId = readString(stripePayload, "id");
      subscriptionStatus = lCase(readString(stripePayload, "status"));
      if (!len(subscriptionId) OR left(subscriptionId, 4) NEQ "sub_") {
        return errorResponse("STRIPE_SUBSCRIPTION_FAILED", "Stripe subscription response was incomplete.");
      }

      response = structNew("ordered-casesensitive");
      response["SUCCESS"] = true;
      response["success"] = true;
      response["MESSAGE"] = "Your Premium trial has started. Activation may take a moment.";
      response["message"] = response["MESSAGE"];
      response["STATUS"] = "trial_created";
      response["status"] = "trial_created";
      response["NEXT_ACTION"] = "stripe_trial_subscription";
      response["nextAction"] = "stripe_trial_subscription";
      response["STRIPE_CUSTOMER_ID"] = stripeCustomerId;
      response["stripeCustomerId"] = stripeCustomerId;
      response["STRIPE_SUBSCRIPTION_ID"] = subscriptionId;
      response["stripeSubscriptionId"] = subscriptionId;
      response["STRIPE_SUBSCRIPTION_STATUS"] = subscriptionStatus;
      response["stripeSubscriptionStatus"] = subscriptionStatus;
      response["TRIAL_DAYS"] = trialDaysValue;
      response["trialDays"] = trialDaysValue;
      if (structKeyExists(stripePayload, "trial_end") AND isNumeric(stripePayload.trial_end)) {
        response["TRIAL_END_EPOCH"] = val(stripePayload.trial_end);
        response["trialEndEpoch"] = val(stripePayload.trial_end);
      }
      return response;
    </cfscript>
  </cffunction>

  <cffunction name="retrieveCheckoutSession" access="public" returntype="struct" output="false">
    <cfargument name="checkoutSessionId" type="string" required="true">
    <cfscript>
      var sessionId = trim(arguments.checkoutSessionId);
      var secretKey = "";
      var stripeResult = {};
      var stripePayload = {};
      var response = {};
      var checkoutUrl = "";
      var checkoutStatus = "";

      if (!len(sessionId) OR left(sessionId, 3) NEQ "cs_") {
        return errorResponse("INVALID_CHECKOUT_SESSION_ID", "Checkout session is invalid.");
      }

      secretKey = readConfigValue("secretKey", "getSecretKey");
      if (!len(secretKey)) {
        return errorResponse("STRIPE_CONFIG_MISSING", "Stripe checkout configuration is incomplete.");
      }

      stripeResult = executeStripeCheckoutSessionRetrieve(sessionId, secretKey);
      if (!structKeyExists(stripeResult, "SUCCESS") OR stripeResult.SUCCESS NEQ true) {
        stripePayload = normalizeStripePayload(stripeResult);
        if (structKeyExists(stripePayload, "error") AND isStruct(stripePayload.error) AND readString(stripePayload.error, "code") EQ "resource_missing") {
          return errorResponse("STRIPE_CHECKOUT_SESSION_NOT_FOUND", "Stripe checkout session was not found.");
        }
        return errorResponse("STRIPE_CHECKOUT_LOOKUP_FAILED", "Stripe checkout session could not be checked.");
      }

      stripePayload = normalizeStripePayload(stripeResult);
      checkoutUrl = readString(stripePayload, "url");
      checkoutStatus = lCase(readString(stripePayload, "status"));

      response = structNew("ordered-casesensitive");
      response["SUCCESS"] = true;
      response["success"] = true;
      response["MESSAGE"] = "Checkout session retrieved.";
      response["message"] = "Checkout session retrieved.";
      response["STRIPE_CHECKOUT_SESSION_ID"] = readString(stripePayload, "id");
      response["stripeCheckoutSessionId"] = response["STRIPE_CHECKOUT_SESSION_ID"];
      response["CHECKOUT_URL"] = checkoutUrl;
      response["checkoutUrl"] = checkoutUrl;
      response["STATUS"] = checkoutStatus;
      response["status"] = checkoutStatus;
      response["PAYMENT_STATUS"] = lCase(readString(stripePayload, "payment_status"));
      response["paymentStatus"] = response["PAYMENT_STATUS"];
      return response;
    </cfscript>
  </cffunction>

  <cffunction name="buildStripeRequestPayload" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="priceId" type="string" required="true">
    <cfargument name="successUrl" type="string" required="true">
    <cfargument name="cancelUrl" type="string" required="true">
    <cfscript>
      return {
        "url" = "https://api.stripe.com/v1/checkout/sessions",
        "formFields" = {
          "mode" = "subscription",
          "line_items[0][price]" = trim(arguments.priceId),
          "line_items[0][quantity]" = "1",
          "success_url" = trim(arguments.successUrl),
          "cancel_url" = trim(arguments.cancelUrl),
          "client_reference_id" = toString(int(val(arguments.userId))),
          "metadata[fpwUserId]" = toString(int(val(arguments.userId))),
          "subscription_data[metadata][fpwUserId]" = toString(int(val(arguments.userId)))
        }
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildStripeThreeDayPassRequestPayload" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="priceId" type="string" required="true">
    <cfargument name="successUrl" type="string" required="true">
    <cfargument name="cancelUrl" type="string" required="true">
    <cfscript>
      var userIdText = toString(int(val(arguments.userId)));
      return {
        "url" = "https://api.stripe.com/v1/checkout/sessions",
        "formFields" = {
          "mode" = "payment",
          "line_items[0][price]" = trim(arguments.priceId),
          "line_items[0][quantity]" = "1",
          "success_url" = trim(arguments.successUrl),
          "cancel_url" = trim(arguments.cancelUrl),
          "client_reference_id" = userIdText,
          "metadata[fpwUserId]" = userIdText,
          "metadata[fpwProduct]" = "three_day_pass",
          "metadata[fpwEntitlementSource]" = "three_day_pass",
          "payment_intent_data[metadata][fpwUserId]" = userIdText,
          "payment_intent_data[metadata][fpwProduct]" = "three_day_pass",
          "payment_intent_data[metadata][fpwEntitlementSource]" = "three_day_pass"
        }
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildStripeOneTripRequestPayload" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="priceId" type="string" required="true">
    <cfargument name="successUrl" type="string" required="true">
    <cfargument name="cancelUrl" type="string" required="true">
    <cfargument name="floatPlanId" type="numeric" required="false" default="0">
    <cfargument name="returnNonce" type="string" required="false" default="">
    <cfargument name="stripeCustomerId" type="string" required="true">
    <cfscript>
      var userIdText = toString(int(val(arguments.userId)));
      var floatPlanIdValue = int(val(arguments.floatPlanId));
      var returnNonceValue = lCase(trim(arguments.returnNonce));
      var successUrlValue = appendReturnQuery(trim(arguments.successUrl), "fpw_checkout=one_trip&stripe_checkout=success");
      var cancelUrlValue = appendReturnQuery(trim(arguments.cancelUrl), "fpw_checkout=one_trip&stripe_checkout=cancel");
      if (reFind("^[a-f0-9]{64}$", returnNonceValue)) {
        successUrlValue = appendReturnQuery(successUrlValue, "fpw_return=" & urlEncodedFormat(returnNonceValue));
        cancelUrlValue = appendReturnQuery(cancelUrlValue, "fpw_return=" & urlEncodedFormat(returnNonceValue));
      }
      var payload = {
        "url" = "https://api.stripe.com/v1/checkout/sessions",
        "formFields" = {
          "mode" = "payment",
          "customer" = trim(arguments.stripeCustomerId),
          "line_items[0][price]" = trim(arguments.priceId),
          "line_items[0][quantity]" = "1",
          "success_url" = successUrlValue,
          "cancel_url" = cancelUrlValue,
          "client_reference_id" = userIdText,
          "metadata[fpwUserId]" = userIdText,
          "metadata[fpwProduct]" = "one_trip",
          "metadata[fpwCreditSource]" = "stripe_one_trip",
          "payment_intent_data[metadata][fpwUserId]" = userIdText,
          "payment_intent_data[metadata][fpwProduct]" = "one_trip",
          "payment_intent_data[metadata][fpwCreditSource]" = "stripe_one_trip"
        }
      };

      if (floatPlanIdValue GT 0) {
        payload.formFields["metadata[fpwFloatPlanId]"] = toString(floatPlanIdValue);
        payload.formFields["payment_intent_data[metadata][fpwFloatPlanId]"] = toString(floatPlanIdValue);
        payload.formFields["success_url"] = appendReturnQuery(payload.formFields["success_url"], "floatPlanId=" & urlEncodedFormat(toString(floatPlanIdValue)));
        payload.formFields["cancel_url"] = appendReturnQuery(payload.formFields["cancel_url"], "floatPlanId=" & urlEncodedFormat(toString(floatPlanIdValue)));
      }

      return payload;
    </cfscript>
  </cffunction>

  <cffunction name="buildStripeTrialRequestPayload" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="priceId" type="string" required="true">
    <cfargument name="successUrl" type="string" required="true">
    <cfargument name="cancelUrl" type="string" required="true">
    <cfargument name="trialDays" type="numeric" required="true">
    <cfargument name="promoMetadata" type="struct" required="false" default="#structNew()#">
    <cfscript>
      var userIdText = toString(int(val(arguments.userId)));
      var trialDaysText = toString(int(val(arguments.trialDays)));
      var promoType = structKeyExists(arguments.promoMetadata, "promoType") ? lCase(trim(toString(arguments.promoMetadata.promoType))) : "stripe_free_months";
      var formFields = {
        "mode" = "subscription",
        "line_items[0][price]" = trim(arguments.priceId),
        "line_items[0][quantity]" = "1",
        "success_url" = trim(arguments.successUrl),
        "cancel_url" = trim(arguments.cancelUrl),
        "client_reference_id" = userIdText,
        "metadata[fpwUserId]" = userIdText,
        "metadata[fpwPromoType]" = promoType,
        "metadata[fpwTrialDays]" = trialDaysText,
        "subscription_data[metadata][fpwUserId]" = userIdText,
        "subscription_data[metadata][fpwPromoType]" = promoType,
        "subscription_data[metadata][fpwTrialDays]" = trialDaysText,
        "subscription_data[trial_period_days]" = trialDaysText,
        "subscription_data[trial_settings][end_behavior][missing_payment_method]" = "cancel",
        "payment_method_collection" = "if_required"
      };

      return {
        "url" = "https://api.stripe.com/v1/checkout/sessions",
        "formFields" = formFields
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildStripeDirectTrialSubscriptionPayload" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="qUser" type="query" required="true">
    <cfargument name="stripeCustomerId" type="string" required="true">
    <cfargument name="priceId" type="string" required="true">
    <cfargument name="trialDays" type="numeric" required="true">
    <cfargument name="promoMetadata" type="struct" required="false" default="#structNew()#">
    <cfscript>
      var userIdText = toString(int(val(arguments.userId)));
      var trialDaysText = toString(int(val(arguments.trialDays)));
      var emailValue = qUserEmail(arguments.qUser);
      var sourceValue = structKeyExists(arguments.promoMetadata, "source")
        ? trim(toString(arguments.promoMetadata.source))
        : "fpw_custom_no_card_trial";
      var offerValue = structKeyExists(arguments.promoMetadata, "offer")
        ? trim(toString(arguments.promoMetadata.offer))
        : "launch_trial";

      if (!len(sourceValue)) {
        sourceValue = "fpw_custom_no_card_trial";
      }
      if (!len(offerValue)) {
        offerValue = "launch_trial";
      }

      return {
        "url" = "https://api.stripe.com/v1/subscriptions",
        "formFields" = {
          "customer" = trim(arguments.stripeCustomerId),
          "items[0][price]" = trim(arguments.priceId),
          "trial_period_days" = trialDaysText,
          "trial_settings[end_behavior][missing_payment_method]" = "pause",
          "metadata[fpwUserId]" = userIdText,
          "metadata[fpwMemberId]" = userIdText,
          "metadata[fpwEmail]" = emailValue,
          "metadata[source]" = sourceValue,
          "metadata[offer]" = offerValue
        }
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildStripePortalRequestPayload" access="private" returntype="struct" output="false">
    <cfargument name="stripeCustomerId" type="string" required="true">
    <cfargument name="returnUrl" type="string" required="true">
    <cfscript>
      return {
        "url" = "https://api.stripe.com/v1/billing_portal/sessions",
        "formFields" = {
          "customer" = trim(arguments.stripeCustomerId),
          "return_url" = trim(arguments.returnUrl)
        }
      };
    </cfscript>
  </cffunction>

  <cffunction name="executeStripeCheckoutRequest" access="private" returntype="struct" output="false">
    <cfargument name="requestPayload" type="struct" required="true">
    <cfargument name="secretKey" type="string" required="true">
    <cfscript>
      if (isObject(variables.stripeTransport)) {
        return invoke(variables.stripeTransport, "createCheckoutSession", { requestPayload = arguments.requestPayload, secretKey = arguments.secretKey });
      }
      if (isStruct(variables.stripeTransport) AND structKeyExists(variables.stripeTransport, "createCheckoutSession")) {
        return variables.stripeTransport.createCheckoutSession(arguments.requestPayload, arguments.secretKey);
      }
      return executeLiveStripeCheckoutRequest(arguments.requestPayload, arguments.secretKey);
    </cfscript>
  </cffunction>

  <cffunction name="executeStripeCustomerCreateRequest" access="private" returntype="struct" output="false">
    <cfargument name="requestPayload" type="struct" required="true">
    <cfargument name="secretKey" type="string" required="true">
    <cfscript>
      if (isObject(variables.stripeTransport)) {
        return invoke(variables.stripeTransport, "createCustomer", { requestPayload = arguments.requestPayload, secretKey = arguments.secretKey });
      }
      if (isStruct(variables.stripeTransport) AND structKeyExists(variables.stripeTransport, "createCustomer")) {
        return variables.stripeTransport.createCustomer(arguments.requestPayload, arguments.secretKey);
      }
      return executeLiveStripeRequest(arguments.requestPayload, arguments.secretKey);
    </cfscript>
  </cffunction>

  <cffunction name="executeStripeCustomerUpdateRequest" access="private" returntype="struct" output="false">
    <cfargument name="requestPayload" type="struct" required="true">
    <cfargument name="secretKey" type="string" required="true">
    <cfscript>
      if (isObject(variables.stripeTransport)) {
        return invoke(variables.stripeTransport, "updateCustomer", { requestPayload = arguments.requestPayload, secretKey = arguments.secretKey });
      }
      if (isStruct(variables.stripeTransport) AND structKeyExists(variables.stripeTransport, "updateCustomer")) {
        return variables.stripeTransport.updateCustomer(arguments.requestPayload, arguments.secretKey);
      }
      return executeLiveStripeRequest(arguments.requestPayload, arguments.secretKey);
    </cfscript>
  </cffunction>

  <cffunction name="executeStripeSubscriptionCreateRequest" access="private" returntype="struct" output="false">
    <cfargument name="requestPayload" type="struct" required="true">
    <cfargument name="secretKey" type="string" required="true">
    <cfscript>
      if (isObject(variables.stripeTransport)) {
        return invoke(variables.stripeTransport, "createSubscription", { requestPayload = arguments.requestPayload, secretKey = arguments.secretKey });
      }
      if (isStruct(variables.stripeTransport) AND structKeyExists(variables.stripeTransport, "createSubscription")) {
        return variables.stripeTransport.createSubscription(arguments.requestPayload, arguments.secretKey);
      }
      return executeLiveStripeRequest(arguments.requestPayload, arguments.secretKey);
    </cfscript>
  </cffunction>

  <cffunction name="executeStripeSubscriptionListRequest" access="private" returntype="struct" output="false">
    <cfargument name="stripeCustomerId" type="string" required="true">
    <cfargument name="secretKey" type="string" required="true">
    <cfscript>
      var requestUrl = "https://api.stripe.com/v1/subscriptions?customer=" & encodeForURL(trim(arguments.stripeCustomerId)) & "&status=all&limit=100";
      if (isObject(variables.stripeTransport)) {
        return invoke(variables.stripeTransport, "listSubscriptions", { requestUrl = requestUrl, stripeCustomerId = trim(arguments.stripeCustomerId), secretKey = arguments.secretKey });
      }
      if (isStruct(variables.stripeTransport) AND structKeyExists(variables.stripeTransport, "listSubscriptions")) {
        return variables.stripeTransport.listSubscriptions(requestUrl, trim(arguments.stripeCustomerId), arguments.secretKey);
      }
      return executeLiveStripeGetRequest(requestUrl, arguments.secretKey);
    </cfscript>
  </cffunction>

  <cffunction name="executeStripePortalRequest" access="private" returntype="struct" output="false">
    <cfargument name="requestPayload" type="struct" required="true">
    <cfargument name="secretKey" type="string" required="true">
    <cfscript>
      if (isObject(variables.stripeTransport)) {
        return invoke(variables.stripeTransport, "createPortalSession", { requestPayload = arguments.requestPayload, secretKey = arguments.secretKey });
      }
      if (isStruct(variables.stripeTransport) AND structKeyExists(variables.stripeTransport, "createPortalSession")) {
        return variables.stripeTransport.createPortalSession(arguments.requestPayload, arguments.secretKey);
      }
      return executeLiveStripeRequest(arguments.requestPayload, arguments.secretKey);
    </cfscript>
  </cffunction>

  <cffunction name="executeStripeCheckoutSessionRetrieve" access="private" returntype="struct" output="false">
    <cfargument name="checkoutSessionId" type="string" required="true">
    <cfargument name="secretKey" type="string" required="true">
    <cfscript>
      if (isObject(variables.stripeTransport)) {
        return invoke(variables.stripeTransport, "retrieveCheckoutSession", { checkoutSessionId = arguments.checkoutSessionId, secretKey = arguments.secretKey });
      }
      if (isStruct(variables.stripeTransport) AND structKeyExists(variables.stripeTransport, "retrieveCheckoutSession")) {
        return variables.stripeTransport.retrieveCheckoutSession(arguments.checkoutSessionId, arguments.secretKey);
      }
      return executeLiveStripeGetRequest(
        "https://api.stripe.com/v1/checkout/sessions/" & encodeForURL(arguments.checkoutSessionId),
        arguments.secretKey
      );
    </cfscript>
  </cffunction>

  <cffunction name="executeLiveStripeCheckoutRequest" access="private" returntype="struct" output="false">
    <cfargument name="requestPayload" type="struct" required="true">
    <cfargument name="secretKey" type="string" required="true">
    <cfscript>
      return executeLiveStripeRequest(arguments.requestPayload, arguments.secretKey);
    </cfscript>
  </cffunction>

  <cffunction name="executeLiveStripeRequest" access="private" returntype="struct" output="false">
    <cfargument name="requestPayload" type="struct" required="true">
    <cfargument name="secretKey" type="string" required="true">
    <cfscript>
      var httpResult = {};
      var fieldName = "";
      var statusCode = 0;
      var rawBody = "";
    </cfscript>
    <cfhttp url="#arguments.requestPayload.url#" method="post" result="httpResult" charset="utf-8" timeout="20">
      <cfhttpparam type="header" name="Authorization" value="Bearer #arguments.secretKey#">
      <cfloop collection="#arguments.requestPayload.formFields#" item="fieldName">
        <cfhttpparam type="formfield" name="#fieldName#" value="#arguments.requestPayload.formFields[fieldName]#">
      </cfloop>
    </cfhttp>

    <cfscript>
      statusCode = structKeyExists(httpResult, "statusCode") ? val(listFirst(toString(httpResult.statusCode), " ")) : 0;
      rawBody = structKeyExists(httpResult, "fileContent") ? toString(httpResult.fileContent) : "";
      return {
        "SUCCESS" = (statusCode GTE 200 AND statusCode LTE 299),
        "success" = (statusCode GTE 200 AND statusCode LTE 299),
        "statusCode" = statusCode,
        "rawBody" = rawBody
      };
    </cfscript>
  </cffunction>

  <cffunction name="executeLiveStripeGetRequest" access="private" returntype="struct" output="false">
    <cfargument name="requestUrl" type="string" required="true">
    <cfargument name="secretKey" type="string" required="true">
    <cfscript>
      var httpResult = {};
      var statusCode = 0;
      var rawBody = "";
    </cfscript>
    <cfhttp url="#arguments.requestUrl#" method="get" result="httpResult" charset="utf-8" timeout="20">
      <cfhttpparam type="header" name="Authorization" value="Bearer #arguments.secretKey#">
    </cfhttp>

    <cfscript>
      statusCode = structKeyExists(httpResult, "statusCode") ? val(listFirst(toString(httpResult.statusCode), " ")) : 0;
      rawBody = structKeyExists(httpResult, "fileContent") ? toString(httpResult.fileContent) : "";
      return {
        "SUCCESS" = (statusCode GTE 200 AND statusCode LTE 299),
        "success" = (statusCode GTE 200 AND statusCode LTE 299),
        "statusCode" = statusCode,
        "rawBody" = rawBody
      };
    </cfscript>
  </cffunction>

  <cffunction name="loadStripeUser" access="private" returntype="query" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      return queryExecute(
        "SELECT userId, fName, lName, email
         FROM users
         WHERE userId = :userId
         LIMIT 1",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="ensureStripeCustomerForUser" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="qUser" type="query" required="true">
    <cfargument name="secretKey" type="string" required="true">
    <cfargument name="source" type="string" required="false" default="fpw_signup">
    <cfscript>
      var mappedCustomerId = loadMappedStripeCustomerIdForUser(arguments.userId);
      var fallbackCustomerId = "";
      var sourceValue = len(trim(arguments.source)) ? trim(arguments.source) : "fpw_signup";
      var migratedSourceValue = left(sourceValue & "_migrated", 80);
      var requestPayload = {};
      var stripeResult = {};
      var stripePayload = {};
      var stripeCustomerId = "";
      var response = {};

      if (len(mappedCustomerId)) {
        requestPayload = buildStripeCustomerRequestPayload(arguments.userId, arguments.qUser, "https://api.stripe.com/v1/customers/" & encodeForURL(mappedCustomerId), sourceValue);
        stripeResult = executeStripeCustomerUpdateRequest(requestPayload, arguments.secretKey);
        if (!structKeyExists(stripeResult, "SUCCESS") OR stripeResult.SUCCESS NEQ true) {
          response = errorResponse("STRIPE_CUSTOMER_UPDATE_FAILED", "Stripe customer could not be updated for this account.");
          addStripeCheckoutDebug(response, stripeResult, requestPayload, "customer_update", arguments.userId, "");
          return response;
        }
        storeUserStripeCustomerMapping(arguments.userId, mappedCustomerId, arguments.qUser, sourceValue);
        return stripeCustomerResponse(mappedCustomerId, false);
      }

      fallbackCustomerId = loadLegacyStripeCustomerIdForUser(arguments.userId);
      if (len(fallbackCustomerId)) {
        if (!storeUserStripeCustomerMapping(arguments.userId, fallbackCustomerId, arguments.qUser, migratedSourceValue)) {
          return errorResponse("STRIPE_CUSTOMER_MAPPING_CONFLICT", "Stripe customer is already linked to a different account.");
        }
        requestPayload = buildStripeCustomerRequestPayload(arguments.userId, arguments.qUser, "https://api.stripe.com/v1/customers/" & encodeForURL(fallbackCustomerId), migratedSourceValue);
        stripeResult = executeStripeCustomerUpdateRequest(requestPayload, arguments.secretKey);
        if (!structKeyExists(stripeResult, "SUCCESS") OR stripeResult.SUCCESS NEQ true) {
          response = errorResponse("STRIPE_CUSTOMER_UPDATE_FAILED", "Stripe customer could not be updated for this account.");
          addStripeCheckoutDebug(response, stripeResult, requestPayload, "customer_update", arguments.userId, "");
          return response;
        }
        return stripeCustomerResponse(fallbackCustomerId, false);
      }

      requestPayload = buildStripeCustomerRequestPayload(arguments.userId, arguments.qUser, "https://api.stripe.com/v1/customers", sourceValue);
      stripeResult = executeStripeCustomerCreateRequest(requestPayload, arguments.secretKey);
      if (!structKeyExists(stripeResult, "SUCCESS") OR stripeResult.SUCCESS NEQ true) {
        response = errorResponse("STRIPE_CUSTOMER_CREATE_FAILED", "Stripe customer could not be created for this account.");
        addStripeCheckoutDebug(response, stripeResult, requestPayload, "customer_create", arguments.userId, "");
        return response;
      }
      stripePayload = normalizeStripePayload(stripeResult);
      stripeCustomerId = readString(stripePayload, "id");
      if (!len(stripeCustomerId) OR left(stripeCustomerId, 4) NEQ "cus_") {
        return errorResponse("STRIPE_CUSTOMER_CREATE_FAILED", "Stripe customer response was incomplete.");
      }
      if (!storeUserStripeCustomerMapping(arguments.userId, stripeCustomerId, arguments.qUser, sourceValue)) {
        return errorResponse("STRIPE_CUSTOMER_MAPPING_CONFLICT", "Stripe customer is already linked to a different account.");
      }
      return stripeCustomerResponse(stripeCustomerId, true);
    </cfscript>
  </cffunction>

  <cffunction name="findExistingTrialOrPremiumBlock" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="stripeCustomerId" type="string" required="true">
    <cfargument name="priceId" type="string" required="true">
    <cfargument name="secretKey" type="string" required="true">
    <cfscript>
      var stripeResult = {};
      var stripePayload = {};
      var stripeBlock = {};
      var response = {};

      stripeResult = executeStripeSubscriptionListRequest(arguments.stripeCustomerId, arguments.secretKey);
      if (!structKeyExists(stripeResult, "SUCCESS") OR stripeResult.SUCCESS NEQ true) {
        response = errorResponse("STRIPE_SUBSCRIPTION_LOOKUP_FAILED", "Existing Stripe subscriptions could not be checked.");
        return { "blocked" = true, "response" = response };
      }
      stripePayload = normalizeStripePayload(stripeResult);
      stripeBlock = findStripeSubscriptionBlock(stripePayload, arguments.priceId);
      if (structKeyExists(stripeBlock, "blocked") AND stripeBlock.blocked) {
        return { "blocked" = true, "response" = stripeBlock.response };
      }
      return { "blocked" = false };
    </cfscript>
  </cffunction>

  <cffunction name="findLocalTrialOrPremiumBlock" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var localSubscription = findLocalStripeSubscriptionBlock(arguments.userId);
      if (structKeyExists(localSubscription, "blocked") AND localSubscription.blocked) {
        return localSubscription;
      }
      if (hasActiveLocalPremium(arguments.userId)) {
        return { "blocked" = true, "response" = trialBlockResponse(true, "already_premium", "Your account already has Premium access.", "") };
      }
      if (hasUsedLocalStripeFreeTrial(arguments.userId)) {
        return { "blocked" = true, "response" = trialBlockResponse(false, "not_eligible", "A free trial has already been used for this account.", "PROMO_FREE_TRIAL_ALREADY_USED") };
      }
      return { "blocked" = false };
    </cfscript>
  </cffunction>

  <cffunction name="buildStripeCustomerRequestPayload" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="qUser" type="query" required="true">
    <cfargument name="requestUrl" type="string" required="true">
    <cfargument name="source" type="string" required="true">
    <cfscript>
      var userIdText = toString(int(val(arguments.userId)));
      var userName = qUserName(arguments.qUser);
      var formFields = {
        "email" = qUserEmail(arguments.qUser),
        "metadata[fpwUserId]" = userIdText,
        "metadata[fpwMemberId]" = userIdText,
        "metadata[source]" = trim(arguments.source),
        "metadata[site]" = "floatplanwizard.com"
      };
      if (len(userName)) {
        formFields["name"] = userName;
      }
      return {
        "url" = trim(arguments.requestUrl),
        "formFields" = formFields
      };
    </cfscript>
  </cffunction>

  <cffunction name="stripeCustomerResponse" access="private" returntype="struct" output="false">
    <cfargument name="stripeCustomerId" type="string" required="true">
    <cfargument name="created" type="boolean" required="true">
    <cfscript>
      return {
        "SUCCESS" = true,
        "success" = true,
        "stripeCustomerId" = trim(arguments.stripeCustomerId),
        "STRIPE_CUSTOMER_ID" = trim(arguments.stripeCustomerId),
        "stripeCustomerCreated" = arguments.created,
        "STRIPE_CUSTOMER_CREATED" = arguments.created
      };
    </cfscript>
  </cffunction>

  <cffunction name="trialBlockResponse" access="private" returntype="struct" output="false">
    <cfargument name="success" type="boolean" required="true">
    <cfargument name="status" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfargument name="errorCode" type="string" required="false" default="">
    <cfargument name="stripeSubscriptionId" type="string" required="false" default="">
    <cfscript>
      var response = structNew("ordered-casesensitive");
      response["SUCCESS"] = arguments.success;
      response["success"] = arguments.success;
      response["STATUS"] = trim(arguments.status);
      response["status"] = trim(arguments.status);
      response["MESSAGE"] = trim(arguments.message);
      response["message"] = trim(arguments.message);
      response["NEXT_ACTION"] = "stripe_trial_subscription";
      response["nextAction"] = "stripe_trial_subscription";
      response["ERROR"] = trim(arguments.errorCode);
      response["errorCode"] = trim(arguments.errorCode);
      if (len(trim(arguments.stripeSubscriptionId))) {
        response["STRIPE_SUBSCRIPTION_ID"] = trim(arguments.stripeSubscriptionId);
        response["stripeSubscriptionId"] = trim(arguments.stripeSubscriptionId);
      }
      return response;
    </cfscript>
  </cffunction>

  <cffunction name="hasActiveLocalPremium" access="private" returntype="boolean" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var access = new fpw.api.v1.MemberEntitlementService().init(variables.datasource).getCurrentAccess(arguments.userId);
      if (structKeyExists(access, "hasPremium") AND (access.hasPremium EQ true OR access.hasPremium EQ 1)) {
        return true;
      }
      if (structKeyExists(access, "HASPREMIUM") AND (access.HASPREMIUM EQ true OR access.HASPREMIUM EQ 1)) {
        return true;
      }
      return false;
    </cfscript>
  </cffunction>

  <cffunction name="hasUsedLocalStripeFreeTrial" access="private" returntype="boolean" output="false">
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

  <cffunction name="findLocalStripeSubscriptionBlock" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var qSub = queryExecute(
        "SELECT stripe_subscription_id, stripe_subscription_status, status
         FROM member_entitlements
         WHERE user_id = :userId
           AND entitlement_type = 'premium'
           AND source = 'stripe_subscription'
           AND stripe_subscription_id IS NOT NULL
           AND stripe_subscription_id <> ''
           AND (
             status = 'active'
             OR stripe_subscription_status IN ('trialing', 'active', 'past_due', 'incomplete', 'paused')
           )
         ORDER BY updated_utc DESC, id DESC
         LIMIT 1",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      var statusValue = "";
      var subscriptionId = "";
      if (qSub.recordCount EQ 0) {
        return { "blocked" = false };
      }
      statusValue = lCase(trim(toString(qSub.stripe_subscription_status[1])));
      subscriptionId = trim(toString(qSub.stripe_subscription_id[1]));
      if (listFindNoCase("trialing", statusValue)) {
        return { "blocked" = true, "response" = trialBlockResponse(true, "already_trialing", "Your Premium trial is already active.", "", subscriptionId) };
      }
      if (listFindNoCase("active,past_due", statusValue) OR lCase(trim(toString(qSub.status[1]))) EQ "active") {
        return { "blocked" = true, "response" = trialBlockResponse(true, "already_premium", "Your account already has Premium access.", "", subscriptionId) };
      }
      return { "blocked" = true, "response" = trialBlockResponse(false, "not_eligible", "A free trial has already been used for this account.", "PROMO_FREE_TRIAL_ALREADY_USED", subscriptionId) };
    </cfscript>
  </cffunction>

  <cffunction name="findStripeSubscriptionBlock" access="private" returntype="struct" output="false">
    <cfargument name="stripePayload" type="struct" required="true">
    <cfargument name="priceId" type="string" required="true">
    <cfscript>
      var stripeData = [];
      var subscription = {};
      var statusValue = "";
      var subscriptionId = "";

      if (structKeyExists(arguments.stripePayload, "data") AND isArray(arguments.stripePayload.data)) {
        stripeData = arguments.stripePayload.data;
      }
      for (subscription in stripeData) {
        if (!isStruct(subscription) OR !subscriptionHasPrice(subscription, arguments.priceId)) {
          continue;
        }
        statusValue = lCase(readString(subscription, "status"));
        subscriptionId = readString(subscription, "id");
        if (statusValue EQ "trialing") {
          return { "blocked" = true, "response" = trialBlockResponse(true, "already_trialing", "Your Premium trial is already active.", "", subscriptionId) };
        }
        if (listFindNoCase("active,past_due", statusValue)) {
          return { "blocked" = true, "response" = trialBlockResponse(true, "already_premium", "Your account already has Premium access.", "", subscriptionId) };
        }
        if (listFindNoCase("incomplete,paused", statusValue)) {
          return { "blocked" = true, "response" = trialBlockResponse(false, "not_eligible", "A free trial has already been used for this account.", "PROMO_FREE_TRIAL_ALREADY_USED", subscriptionId) };
        }
      }
      return { "blocked" = false };
    </cfscript>
  </cffunction>

  <cffunction name="subscriptionHasPrice" access="private" returntype="boolean" output="false">
    <cfargument name="subscription" type="struct" required="true">
    <cfargument name="priceId" type="string" required="true">
    <cfscript>
      var itemData = [];
      var item = {};
      var price = {};
      if (
        structKeyExists(arguments.subscription, "items")
        AND isStruct(arguments.subscription.items)
        AND structKeyExists(arguments.subscription.items, "data")
        AND isArray(arguments.subscription.items.data)
      ) {
        itemData = arguments.subscription.items.data;
      }
      for (item in itemData) {
        if (isStruct(item) AND structKeyExists(item, "price") AND isStruct(item.price)) {
          price = item.price;
          if (compareNoCase(readString(price, "id"), trim(arguments.priceId)) EQ 0) {
            return true;
          }
        }
      }
      return false;
    </cfscript>
  </cffunction>

  <cffunction name="loadMappedStripeCustomerIdForUser" access="private" returntype="string" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var qCustomer = queryExecute(
        "SELECT stripe_customer_id
         FROM user_stripe_customers
         WHERE user_id = :userId
         LIMIT 1",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      return qCustomer.recordCount ? trim(toString(qCustomer.stripe_customer_id[1])) : "";
    </cfscript>
  </cffunction>

  <cffunction name="storeUserStripeCustomerMapping" access="private" returntype="boolean" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="stripeCustomerId" type="string" required="true">
    <cfargument name="qUser" type="query" required="true">
    <cfargument name="source" type="string" required="true">
    <cfscript>
      if (stripeCustomerMappedToDifferentUser(arguments.stripeCustomerId, arguments.userId)) {
        return false;
      }
      queryExecute(
        "INSERT INTO user_stripe_customers (
           user_id,
           stripe_customer_id,
           email_snapshot,
           name_snapshot,
           source,
           created_at_utc,
           updated_at_utc
         ) VALUES (
           :userId,
           :stripeCustomerId,
           :emailSnapshot,
           :nameSnapshot,
           :source,
           UTC_TIMESTAMP(),
           UTC_TIMESTAMP()
         )
         ON DUPLICATE KEY UPDATE
           stripe_customer_id = VALUES(stripe_customer_id),
           email_snapshot = VALUES(email_snapshot),
           name_snapshot = VALUES(name_snapshot),
           source = VALUES(source),
           updated_at_utc = UTC_TIMESTAMP()",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
          stripeCustomerId = { value = trim(arguments.stripeCustomerId), cfsqltype = "cf_sql_varchar" },
          emailSnapshot = { value = qUserEmail(arguments.qUser), cfsqltype = "cf_sql_varchar", null = !len(qUserEmail(arguments.qUser)) },
          nameSnapshot = { value = qUserName(arguments.qUser), cfsqltype = "cf_sql_varchar", null = !len(qUserName(arguments.qUser)) },
          source = { value = trim(arguments.source), cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
      return true;
    </cfscript>
  </cffunction>

  <cffunction name="stripeCustomerMappedToDifferentUser" access="private" returntype="boolean" output="false">
    <cfargument name="stripeCustomerId" type="string" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var qConflict = queryExecute(
        "SELECT user_id
         FROM user_stripe_customers
         WHERE stripe_customer_id = :stripeCustomerId
           AND user_id <> :userId
         LIMIT 1",
        {
          stripeCustomerId = { value = trim(arguments.stripeCustomerId), cfsqltype = "cf_sql_varchar" },
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      return qConflict.recordCount GT 0;
    </cfscript>
  </cffunction>

  <cffunction name="loadStripeCustomerIdForUser" access="private" returntype="string" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var mappedCustomerId = loadMappedStripeCustomerIdForUser(arguments.userId);
      if (len(mappedCustomerId)) {
        return mappedCustomerId;
      }
      return loadLegacyStripeCustomerIdForUser(arguments.userId);
    </cfscript>
  </cffunction>

  <cffunction name="loadLegacyStripeCustomerIdForUser" access="private" returntype="string" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var qCustomer = queryExecute(
        "SELECT stripe_customer_id
         FROM member_entitlements
         WHERE user_id = :userId
           AND entitlement_type = 'premium'
           AND source = 'stripe_subscription'
           AND stripe_customer_id IS NOT NULL
           AND stripe_customer_id <> ''
         ORDER BY
           CASE
             WHEN status = 'active'
              AND starts_at_utc <= UTC_TIMESTAMP()
              AND (expires_at_utc IS NULL OR expires_at_utc >= UTC_TIMESTAMP())
             THEN 0
             ELSE 1
           END ASC,
           updated_utc DESC,
           id DESC
         LIMIT 1",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      return qCustomer.recordCount ? trim(toString(qCustomer.stripe_customer_id[1])) : "";
    </cfscript>
  </cffunction>

  <cffunction name="qUserEmail" access="private" returntype="string" output="false">
    <cfargument name="qUser" type="query" required="true">
    <cfscript>
      if (arguments.qUser.recordCount EQ 0 OR isNull(arguments.qUser.email[1])) {
        return "";
      }
      return trim(toString(arguments.qUser.email[1]));
    </cfscript>
  </cffunction>

  <cffunction name="qUserName" access="private" returntype="string" output="false">
    <cfargument name="qUser" type="query" required="true">
    <cfscript>
      var firstName = "";
      var lastName = "";
      if (arguments.qUser.recordCount EQ 0) {
        return "";
      }
      if (!isNull(arguments.qUser.fName[1])) {
        firstName = trim(toString(arguments.qUser.fName[1]));
      }
      if (!isNull(arguments.qUser.lName[1])) {
        lastName = trim(toString(arguments.qUser.lName[1]));
      }
      return trim(firstName & " " & lastName);
    </cfscript>
  </cffunction>

  <cffunction name="normalizeStripePayload" access="private" returntype="struct" output="false">
    <cfargument name="stripeResult" type="struct" required="true">
    <cfscript>
      if (structKeyExists(arguments.stripeResult, "body") AND isStruct(arguments.stripeResult.body)) {
        return arguments.stripeResult.body;
      }
      if (structKeyExists(arguments.stripeResult, "payload") AND isStruct(arguments.stripeResult.payload)) {
        return arguments.stripeResult.payload;
      }
      if (structKeyExists(arguments.stripeResult, "rawBody") AND len(trim(toString(arguments.stripeResult.rawBody)))) {
        try {
          var parsed = deserializeJSON(toString(arguments.stripeResult.rawBody), false);
          if (isStruct(parsed)) {
            return parsed;
          }
        } catch (any parseErr) {
          return {};
        }
      }
      return {};
    </cfscript>
  </cffunction>

  <cffunction name="appendReturnQuery" access="private" returntype="string" output="false">
    <cfargument name="urlValue" type="string" required="true">
    <cfargument name="queryValue" type="string" required="true">
    <cfscript>
      var cleanUrl = trim(arguments.urlValue);
      var cleanQuery = trim(arguments.queryValue);
      if (!len(cleanQuery)) {
        return cleanUrl;
      }
      return cleanUrl & (find("?", cleanUrl) GT 0 ? "&" : "?") & cleanQuery;
    </cfscript>
  </cffunction>

  <cffunction name="resolvePriceId" access="private" returntype="string" output="false">
    <cfargument name="interval" type="string" required="true">
    <cfscript>
      switch (lCase(trim(arguments.interval))) {
        case "monthly":
          return readConfigValue("premiumMonthlyPriceId", "getPremiumMonthlyPriceId");
        case "yearly":
          return readConfigValue("premiumYearlyPriceId", "getPremiumYearlyPriceId");
        case "three_day_pass":
          return readConfigValue("threeDayPassPriceId", "getThreeDayPassPriceId");
        case "one_trip":
          return readConfigValue("oneTripPriceId", "getOneTripPriceId");
        default:
          return "";
      }
    </cfscript>
  </cffunction>

  <cffunction name="readConfigValue" access="private" returntype="string" output="false">
    <cfargument name="structKey" type="string" required="true">
    <cfargument name="getterName" type="string" required="true">
    <cfscript>
      if (isStruct(variables.configService) AND structKeyExists(variables.configService, arguments.structKey)) {
        return trim(toString(variables.configService[arguments.structKey]));
      }
      if (isObject(variables.configService)) {
        return trim(toString(invoke(variables.configService, arguments.getterName)));
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="readString" access="private" returntype="string" output="false">
    <cfargument name="source" type="struct" required="true">
    <cfargument name="key" type="string" required="true">
    <cfscript>
      if (structKeyExists(arguments.source, arguments.key) AND !isNull(arguments.source[arguments.key])) {
        return trim(toString(arguments.source[arguments.key]));
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="addStripeCheckoutDebug" access="private" returntype="void" output="false">
    <cfargument name="response" type="struct" required="true">
    <cfargument name="stripeResult" type="struct" required="true">
    <cfargument name="requestPayload" type="struct" required="true">
    <cfargument name="operation" type="string" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="priceId" type="string" required="true">
    <cfscript>
      var statusCode = structKeyExists(arguments.stripeResult, "statusCode") ? val(arguments.stripeResult.statusCode) : 0;
      var stripePayload = normalizeStripePayload(arguments.stripeResult);
      var stripeError = {};
      var debugParts = [];
      var debugMessage = "";
      var stripeType = "";
      var stripeCode = "";
      var stripeParam = "";
      var stripeMessage = "";
      var fieldName = "";

      arrayAppend(debugParts, "operation=" & sanitizeStripeDebugText(arguments.operation));
      arrayAppend(debugParts, "userId=" & int(val(arguments.userId)));
      if (len(trim(arguments.priceId))) {
        arrayAppend(debugParts, "priceIdSha256=" & lCase(hash(trim(arguments.priceId), "SHA-256")));
      }
      if (structKeyExists(arguments.requestPayload, "url")) {
        arrayAppend(debugParts, "stripeRequestUrl=" & sanitizeStripeDebugText(toString(arguments.requestPayload.url)));
      }
      if (structKeyExists(arguments.requestPayload, "formFields")
          AND isStruct(arguments.requestPayload.formFields)
          AND structKeyExists(arguments.requestPayload.formFields, "mode")) {
        arrayAppend(debugParts, "mode=" & sanitizeStripeDebugText(toString(arguments.requestPayload.formFields.mode)));
      }
      if (statusCode GT 0) {
        arrayAppend(debugParts, "status=" & statusCode);
      }

      if (structKeyExists(stripePayload, "error") AND isStruct(stripePayload.error)) {
        stripeError = stripePayload.error;
        stripeType = readString(stripeError, "type");
        stripeCode = readString(stripeError, "code");
        stripeParam = readString(stripeError, "param");
        stripeMessage = readString(stripeError, "message");

        if (len(stripeType)) {
          arrayAppend(debugParts, "type=" & sanitizeStripeDebugText(stripeType));
        }
        if (len(stripeCode)) {
          arrayAppend(debugParts, "code=" & sanitizeStripeDebugText(stripeCode));
        }
        if (len(stripeParam)) {
          arrayAppend(debugParts, "param=" & sanitizeStripeDebugText(stripeParam));
        }
        if (len(stripeMessage)) {
          arrayAppend(debugParts, "message=" & sanitizeStripeDebugText(stripeMessage));
        }
      }

      if (!arrayLen(debugParts)) {
        arrayAppend(debugParts, "Stripe request failed before a status or parseable error body was available.");
      }

      debugMessage = arrayToList(debugParts, "; ");
      writeStripeCheckoutDebugLog(arguments.operation, arguments.userId, arguments.priceId, debugMessage);
    </cfscript>
  </cffunction>

  <cffunction name="sanitizeStripeDebugText" access="private" returntype="string" output="false">
    <cfargument name="value" type="string" required="true">
    <cfscript>
      var textValue = replace(replace(trim(arguments.value), chr(13), " ", "all"), chr(10), " ", "all");
      textValue = reReplace(textValue, "sk_live_[A-Za-z0-9_*.-]+", "sk_live_[redacted]", "all");
      textValue = reReplace(textValue, "sk_test_[A-Za-z0-9_*.-]+", "sk_test_[redacted]", "all");
      textValue = reReplace(textValue, "rk_live_[A-Za-z0-9_*.-]+", "rk_live_[redacted]", "all");
      textValue = reReplace(textValue, "rk_test_[A-Za-z0-9_*.-]+", "rk_test_[redacted]", "all");
      textValue = reReplace(textValue, "whsec_[A-Za-z0-9_*.-]+", "whsec_[redacted]", "all");
      textValue = reReplace(textValue, "cus_[A-Za-z0-9_]+", "cus_[redacted]", "all");
      textValue = reReplace(textValue, "sub_[A-Za-z0-9_]+", "sub_[redacted]", "all");
      textValue = reReplace(textValue, "bps_[A-Za-z0-9_]+", "bps_[redacted]", "all");
      return left(textValue, 1000);
    </cfscript>
  </cffunction>

  <cffunction name="addStripePortalDebug" access="private" returntype="void" output="false">
    <cfargument name="stripeResult" type="struct" required="true">
    <cfargument name="operation" type="string" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="stripeCustomerId" type="string" required="true">
    <cfargument name="returnUrl" type="string" required="true">
    <cfscript>
      var statusCode = structKeyExists(arguments.stripeResult, "statusCode") ? val(arguments.stripeResult.statusCode) : 0;
      var stripePayload = normalizeStripePayload(arguments.stripeResult);
      var stripeError = {};
      var debugParts = [];
      var rawBody = structKeyExists(arguments.stripeResult, "rawBody") ? trim(toString(arguments.stripeResult.rawBody)) : "";
      var stripeType = "";
      var stripeCode = "";
      var stripeParam = "";
      var stripeMessage = "";
      var requestLogUrl = "";
      var rawBodyParseable = false;

      arrayAppend(debugParts, "operation=" & sanitizeStripeDebugText(arguments.operation));
      arrayAppend(debugParts, "userId=" & int(val(arguments.userId)));
      arrayAppend(debugParts, "hasStoredStripeCustomerId=" & (len(trim(arguments.stripeCustomerId)) GT 0 ? "true" : "false"));
      if (len(trim(arguments.stripeCustomerId))) {
        arrayAppend(debugParts, "stripeCustomerId=" & redactStripeCustomerId(arguments.stripeCustomerId));
      }
      arrayAppend(debugParts, "returnUrlHost=" & sanitizeStripeDebugText(extractUrlHost(arguments.returnUrl)));
      if (statusCode GT 0) {
        arrayAppend(debugParts, "status=" & statusCode);
      }

      if (structKeyExists(stripePayload, "error") AND isStruct(stripePayload.error)) {
        rawBodyParseable = true;
        stripeError = stripePayload.error;
        stripeType = readString(stripeError, "type");
        stripeCode = readString(stripeError, "code");
        stripeParam = readString(stripeError, "param");
        stripeMessage = readString(stripeError, "message");
        requestLogUrl = readString(stripeError, "request_log_url");

        if (len(stripeType)) {
          arrayAppend(debugParts, "type=" & sanitizeStripeDebugText(stripeType));
        }
        if (len(stripeCode)) {
          arrayAppend(debugParts, "code=" & sanitizeStripeDebugText(stripeCode));
        }
        if (len(stripeParam)) {
          arrayAppend(debugParts, "param=" & sanitizeStripeDebugText(stripeParam));
        }
        if (len(stripeMessage)) {
          arrayAppend(debugParts, "message=" & sanitizeStripeDebugText(stripeMessage));
        }
        if (len(requestLogUrl)) {
          arrayAppend(debugParts, "requestLogUrl=" & sanitizeStripeDebugText(requestLogUrl));
        }
      } else if (len(rawBody)) {
        arrayAppend(debugParts, "rawBodyParseable=false");
      } else {
        arrayAppend(debugParts, "rawBodyPresent=false");
      }

      if (rawBodyParseable) {
        arrayAppend(debugParts, "rawBodyParseable=true");
      }

      writeStripePortalDebugLog(arguments.operation, arguments.userId, arrayToList(debugParts, "; "));
    </cfscript>
  </cffunction>

  <cffunction name="redactStripeCustomerId" access="private" returntype="string" output="false">
    <cfargument name="stripeCustomerId" type="string" required="true">
    <cfscript>
      var value = trim(arguments.stripeCustomerId);
      if (!len(value)) {
        return "";
      }
      if (len(value) LTE 12) {
        return left(value, 4) & "...[redacted]";
      }
      return left(value, 8) & "..." & right(value, 4);
    </cfscript>
  </cffunction>

  <cffunction name="extractUrlHost" access="private" returntype="string" output="false">
    <cfargument name="url" type="string" required="true">
    <cfscript>
      var value = trim(arguments.url);
      var match = {};
      if (!len(value)) {
        return "";
      }
      match = reFindNoCase("^https?://([^/?##:]+)", value, 1, true);
      if (isStruct(match) AND arrayLen(match.pos) GTE 2 AND match.pos[2] GT 0) {
        return mid(value, match.pos[2], match.len[2]);
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="getAppLogDirectory" access="private" returntype="string" output="false">
    <cfscript>
      var componentDir = replace(getDirectoryFromPath(getCurrentTemplatePath()), "\", "/", "all");
      var appRoot = reReplace(componentDir, "/api/v1/?$", "/", "one");
      return appRoot & "logs";
    </cfscript>
  </cffunction>

  <cffunction name="writeStripePortalDebugLog" access="private" returntype="void" output="false">
    <cfargument name="operation" type="string" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="debugMessage" type="string" required="true">
    <cfscript>
      var logDirectory = getAppLogDirectory();
      var logFile = logDirectory & "/stripe-portal-debug.log";
      var logLine = "STRIPE_PORTAL_DEBUG ts=#dateTimeFormat(now(), 'yyyy-mm-dd HH:nn:ss')# operation=#sanitizeStripeDebugText(arguments.operation)# userId=#int(val(arguments.userId))# debug=#arguments.debugMessage#";
    </cfscript>
    <cftry>
      <cfif NOT directoryExists(logDirectory)>
        <cfdirectory action="create" directory="#logDirectory#">
      </cfif>
      <cffile action="append" file="#logFile#" output="#logLine#" addnewline="true" charset="utf-8">
      <cfcatch type="any">
        <cflog file="fpw-errors" type="error" text="STRIPE_PORTAL_DEBUG_LOG_FAILED message=#toString(cfcatch.message)# detail=#toString(cfcatch.detail)#">
      </cfcatch>
    </cftry>
  </cffunction>

  <cffunction name="writeStripeCheckoutDebugLog" access="private" returntype="void" output="false">
    <cfargument name="operation" type="string" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="priceId" type="string" required="true">
    <cfargument name="debugMessage" type="string" required="true">
    <cfscript>
      var logDirectory = getAppLogDirectory();
      var logFile = logDirectory & "/stripe-checkout-debug.log";
      var logLine = "STRIPE_CHECKOUT_DEBUG ts=#dateTimeFormat(now(), 'yyyy-mm-dd HH:nn:ss')# operation=#arguments.operation# userId=#int(val(arguments.userId))# priceId=#sanitizeStripeDebugText(arguments.priceId)# debug=#sanitizeStripeDebugText(arguments.debugMessage)#";
    </cfscript>
    <cftry>
      <cfif NOT directoryExists(logDirectory)>
        <cfdirectory action="create" directory="#logDirectory#">
      </cfif>
      <cffile action="append" file="#logFile#" output="#logLine#" addnewline="true" charset="utf-8">
      <cfcatch type="any">
        <cflog file="fpw-errors" type="error" text="STRIPE_CHECKOUT_DEBUG_LOG_FAILED message=#toString(cfcatch.message)# detail=#toString(cfcatch.detail)#">
      </cfcatch>
    </cftry>
  </cffunction>

  <cffunction name="errorResponse" access="private" returntype="struct" output="false">
    <cfargument name="errorCode" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfscript>
      var response = structNew("ordered-casesensitive");
      response["SUCCESS"] = false;
      response["success"] = false;
      response["ERROR"] = arguments.errorCode;
      response["errorCode"] = arguments.errorCode;
      response["MESSAGE"] = arguments.message;
      response["message"] = arguments.message;
      return response;
    </cfscript>
  </cffunction>

</cfcomponent>
