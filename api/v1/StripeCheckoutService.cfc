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
    <cfscript>
      var userIdValue = int(val(arguments.userId));
      var intervalValue = lCase(trim(arguments.interval));
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
      if (!listFindNoCase("monthly,yearly", intervalValue)) {
        return errorResponse("INVALID_PRICE_SELECTOR", "Choose monthly or yearly Premium billing.");
      }
      secretKey = readConfigValue("secretKey", "getSecretKey");
      selectedPriceId = resolvePriceId(intervalValue);
      successUrl = readConfigValue("checkoutSuccessUrl", "getCheckoutSuccessUrl");
      cancelUrl = readConfigValue("checkoutCancelUrl", "getCheckoutCancelUrl");
      if (!len(secretKey) OR !len(selectedPriceId) OR !len(successUrl) OR !len(cancelUrl)) {
        return errorResponse("STRIPE_CONFIG_MISSING", "Stripe checkout configuration is incomplete.");
      }

      requestPayload = buildStripeRequestPayload(userIdValue, selectedPriceId, successUrl, cancelUrl);
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

  <cffunction name="loadStripeCustomerIdForUser" access="private" returntype="string" output="false">
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

  <cffunction name="resolvePriceId" access="private" returntype="string" output="false">
    <cfargument name="interval" type="string" required="true">
    <cfscript>
      switch (lCase(trim(arguments.interval))) {
        case "monthly":
          return readConfigValue("premiumMonthlyPriceId", "getPremiumMonthlyPriceId");
        case "yearly":
          return readConfigValue("premiumYearlyPriceId", "getPremiumYearlyPriceId");
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
      var rawBody = structKeyExists(arguments.stripeResult, "rawBody") ? trim(toString(arguments.stripeResult.rawBody)) : "";
      var stripeType = "";
      var stripeCode = "";
      var stripeParam = "";
      var stripeMessage = "";
      var fieldName = "";

      arrayAppend(debugParts, "operation=" & arguments.operation);
      arrayAppend(debugParts, "userId=" & int(val(arguments.userId)));
      arrayAppend(debugParts, "priceId=" & sanitizeStripeDebugText(arguments.priceId));
      if (structKeyExists(arguments.requestPayload, "url")) {
        arguments.response["stripeRequestUrl"] = sanitizeStripeDebugText(toString(arguments.requestPayload.url));
        arrayAppend(debugParts, "stripeRequestUrl=" & arguments.response["stripeRequestUrl"]);
      }
      if (structKeyExists(arguments.requestPayload, "formFields") AND isStruct(arguments.requestPayload.formFields)) {
        for (fieldName in arguments.requestPayload.formFields) {
          if (listFindNoCase("mode,line_items[0][price],success_url,cancel_url,client_reference_id,metadata[fpwUserId],metadata[fpwPromoType],metadata[fpwTrialDays],subscription_data[trial_period_days],subscription_data[trial_settings][end_behavior][missing_payment_method],payment_method_collection", fieldName)) {
            arguments.response["stripeRequest_" & fieldName] = sanitizeStripeDebugText(toString(arguments.requestPayload.formFields[fieldName]));
            arrayAppend(debugParts, fieldName & "=" & arguments.response["stripeRequest_" & fieldName]);
          }
        }
      }
      if (statusCode GT 0) {
        arguments.response["stripeStatusCode"] = statusCode;
        arrayAppend(debugParts, "status=" & statusCode);
      }

      if (structKeyExists(stripePayload, "error") AND isStruct(stripePayload.error)) {
        stripeError = stripePayload.error;
        stripeType = readString(stripeError, "type");
        stripeCode = readString(stripeError, "code");
        stripeParam = readString(stripeError, "param");
        stripeMessage = readString(stripeError, "message");

        if (len(stripeType)) {
          arguments.response["stripeErrorType"] = stripeType;
          arrayAppend(debugParts, "type=" & stripeType);
        }
        if (len(stripeCode)) {
          arguments.response["stripeErrorCode"] = stripeCode;
          arrayAppend(debugParts, "code=" & stripeCode);
        }
        if (len(stripeParam)) {
          arguments.response["stripeErrorParam"] = stripeParam;
          arrayAppend(debugParts, "param=" & stripeParam);
        }
        if (len(stripeMessage)) {
          arguments.response["stripeErrorMessage"] = sanitizeStripeDebugText(stripeMessage);
          arrayAppend(debugParts, "message=" & arguments.response["stripeErrorMessage"]);
        }
      }

      if (len(rawBody)) {
        arguments.response["stripeRawBody"] = left(sanitizeStripeDebugText(rawBody), 1500);
        arrayAppend(debugParts, "raw=" & arguments.response["stripeRawBody"]);
      }
      if (!arrayLen(debugParts)) {
        arrayAppend(debugParts, "Stripe request failed before a status or parseable error body was available.");
      }

      debugMessage = arrayToList(debugParts, "; ");
      arguments.response["debugMessage"] = debugMessage;
      arguments.response["stripeDebugMessage"] = debugMessage;
      writeStripeCheckoutDebugLog(arguments.operation, arguments.userId, arguments.priceId, debugMessage);
    </cfscript>
  </cffunction>

  <cffunction name="sanitizeStripeDebugText" access="private" returntype="string" output="false">
    <cfargument name="value" type="string" required="true">
    <cfscript>
      var textValue = replace(replace(trim(arguments.value), chr(13), " ", "all"), chr(10), " ", "all");
      textValue = reReplace(textValue, "sk_live_[A-Za-z0-9]+", "sk_live_[redacted]", "all");
      textValue = reReplace(textValue, "sk_test_[A-Za-z0-9]+", "sk_test_[redacted]", "all");
      textValue = reReplace(textValue, "whsec_[A-Za-z0-9]+", "whsec_[redacted]", "all");
      return left(textValue, 1000);
    </cfscript>
  </cffunction>

  <cffunction name="writeStripeCheckoutDebugLog" access="private" returntype="void" output="false">
    <cfargument name="operation" type="string" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="priceId" type="string" required="true">
    <cfargument name="debugMessage" type="string" required="true">
    <cfscript>
      var logDirectory = expandPath("/fpw/logs");
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
