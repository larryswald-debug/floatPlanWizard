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
        return errorResponse("STRIPE_CHECKOUT_FAILED", "Stripe checkout session could not be created.");
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

  <cffunction name="executeLiveStripeCheckoutRequest" access="private" returntype="struct" output="false">
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
