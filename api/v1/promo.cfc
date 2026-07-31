<cfcomponent output="false">

  <cffunction name="handle" access="remote" returntype="void" output="true">
    <cfargument name="action" type="string" required="false" default="">
    <cfsetting enablecfoutputonly="true" showdebugoutput="false">
    <cfcontent type="application/json; charset=utf-8">
    <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

    <cftry>
      <cfset var body = getBodyJson()>
      <cfset var act = lCase(trim(arguments.action))>
      <cfset var userId = 0>
      <cfset var code = "">
      <cfset var promoService = "">
      <cfset var access = {}>
      <cfset var existingPremiumStatus = "">
      <cfset var existingPremiumMessage = "">
      <cfset var serviceResult = {}>
      <cfset var response = {}>
      <cfset var premiumSendCreditModelEnabled = (
        structKeyExists(application, "premiumSendCreditModelEnabled")
        AND listFindNoCase("1,true,yes,on", lCase(trim(toString(application.premiumSendCreditModelEnabled)))) GT 0
      )>

      <cfif NOT len(act) AND structKeyExists(url, "action")>
        <cfset act = lCase(trim(toString(url.action)))>
      </cfif>
      <cfif NOT len(act) AND structKeyExists(body, "action")>
        <cfset act = lCase(trim(toString(body.action)))>
      </cfif>

      <cfif NOT listFindNoCase("validate,redeem,startlaunchtrial", act)>
        <cfset response = buildErrorResponse(false, resolveSessionUserId() GT 0, "INVALID_ACTION", "Promo action is not supported.")>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfreturn>
      </cfif>

      <cfif uCase(trim(cgi.request_method)) NEQ "POST">
        <cfheader statuscode="405">
        <cfset response = buildErrorResponse(false, resolveSessionUserId() GT 0, "METHOD_NOT_ALLOWED", "Use POST for promo code requests.")>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfreturn>
      </cfif>

      <cfset userId = resolveSessionUserId()>
      <cfif userId LTE 0>
        <cfset response = buildErrorResponse(false, false, "AUTH_REQUIRED", "Log in to redeem promo codes.")>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfreturn>
      </cfif>

      <cfif act EQ "startlaunchtrial" AND premiumSendCreditModelEnabled>
        <cfheader statuscode="410">
        <cfset response = buildErrorResponse(false, true, "LAUNCH_TRIAL_CUTOVER_ACTIVE", "The launch trial has ended. FPW membership is free, and new members receive a complimentary Premium trip.")>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfreturn>
      </cfif>

      <cfset promoService = createPromoCodeService()>

      <cfif act EQ "startlaunchtrial">
        <cfset access = new fpw.api.v1.MemberEntitlementService().init("fpw").getCurrentAccess(userId)>
        <cfif hasPremiumAccess(access)>
          <cfset existingPremiumStatus = resolveExistingPremiumStartTrialStatus(userId)>
          <cfset existingPremiumMessage = existingPremiumStatus EQ "already_trialing" ? "Your Premium trial is already active." : "Your account already has Premium access.">
          <cfset response = buildServiceResponse({
            "SUCCESS" = true,
            "success" = true,
            "eligible" = true,
            "promoType" = "stripe_free_months",
            "nextAction" = "stripe_trial_subscription",
            "STATUS" = existingPremiumStatus,
            "status" = existingPremiumStatus,
            "MESSAGE" = existingPremiumMessage,
            "message" = existingPremiumMessage
          }, act)>
          <cfoutput>#serializeJSON(response)#</cfoutput>
          <cfreturn>
        </cfif>
        <cfset serviceResult = promoService.startLaunchTrial(userId)>
      <cfelse>
        <cfset code = readPromoCode(body)>
        <cfset serviceResult = promoService.validateCode(userId, code)>
        <cfif premiumSendCreditModelEnabled
            AND structKeyExists(serviceResult, "promoType")
            AND lCase(trim(toString(serviceResult.promoType))) EQ "stripe_free_months">
          <cfheader statuscode="410">
          <cfset response = buildErrorResponse(false, true, "LAUNCH_TRIAL_CUTOVER_ACTIVE", "The launch trial has ended. FPW membership is free, and new members receive a complimentary Premium trip.")>
          <cfoutput>#serializeJSON(response)#</cfoutput>
          <cfreturn>
        </cfif>
        <cfif act EQ "redeem">
          <cfset serviceResult = promoService.redeemCode(userId, code)>
        </cfif>
      </cfif>

      <cfset response = buildServiceResponse(serviceResult, act)>
      <cfoutput>#serializeJSON(response)#</cfoutput>

      <cfcatch type="any">
        <cfset response = buildErrorResponse(false, resolveSessionUserId() GT 0, "SERVER_ERROR", "Promo code request could not be completed.")>
        <cfoutput>#serializeJSON(response)#</cfoutput>
      </cfcatch>
    </cftry>

    <cfsetting enablecfoutputonly="false">
  </cffunction>

  <cffunction name="getBodyJson" access="private" returntype="struct" output="false">
    <cfscript>
      var httpData = getHttpRequestData();
      var rawBody = structKeyExists(httpData, "content") ? toString(httpData.content) : "";
      var parsed = {};
      if (!len(trim(rawBody))) {
        return {};
      }
      try {
        parsed = deserializeJSON(rawBody, false);
        if (isStruct(parsed)) {
          return parsed;
        }
      } catch (any parseErr) {
        return {};
      }
      return {};
    </cfscript>
  </cffunction>

  <cffunction name="resolveSessionUserId" access="private" returntype="numeric" output="false">
    <cfscript>
      if (structKeyExists(session, "user") AND isStruct(session.user)) {
        if (structKeyExists(session.user, "userId") AND isNumeric(session.user.userId)) {
          return val(session.user.userId);
        }
        if (structKeyExists(session.user, "id") AND isNumeric(session.user.id)) {
          return val(session.user.id);
        }
        if (structKeyExists(session.user, "USERID") AND isNumeric(session.user.USERID)) {
          return val(session.user.USERID);
        }
      }
      return 0;
    </cfscript>
  </cffunction>

  <cffunction name="createPromoCodeService" access="private" returntype="any" output="false">
    <cfscript>
      if (
        structKeyExists(application, "env")
        AND lCase(toString(application.env)) EQ "dev"
        AND structKeyExists(application, "testPromoCodeService")
        AND (isObject(application.testPromoCodeService) OR isStruct(application.testPromoCodeService))
        AND isTestPromoServiceRequest()
      ) {
        return application.testPromoCodeService;
      }
      return new fpw.api.v1.PromoCodeService().init("fpw");
    </cfscript>
  </cffunction>

  <cffunction name="isTestPromoServiceRequest" access="private" returntype="boolean" output="false">
    <cfscript>
      var httpData = getHttpRequestData();
      var headers = structKeyExists(httpData, "headers") ? httpData.headers : {};
      var headerName = "";
      var headerValue = "";

      if (!isStruct(headers)) {
        return false;
      }

      for (headerName in headers) {
        if (compareNoCase(headerName, "X-FPW-Test-UserId") EQ 0) {
          headerValue = trim(toString(headers[headerName]));
          break;
        }
      }

      return len(headerValue) AND isNumeric(headerValue) AND val(headerValue) GT 0;
    </cfscript>
  </cffunction>

  <cffunction name="readPromoCode" access="private" returntype="string" output="false">
    <cfargument name="body" type="struct" required="true">
    <cfscript>
      if (structKeyExists(arguments.body, "code")) {
        return trim(toString(arguments.body.code));
      }
      if (structKeyExists(arguments.body, "promoCode")) {
        return trim(toString(arguments.body.promoCode));
      }
      if (structKeyExists(arguments.body, "PROMO_CODE")) {
        return trim(toString(arguments.body.PROMO_CODE));
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="hasPremiumAccess" access="private" returntype="boolean" output="false">
    <cfargument name="access" type="struct" required="true">
    <cfscript>
      var value = false;
      if (structKeyExists(arguments.access, "hasPremium")) {
        value = arguments.access.hasPremium;
      } else if (structKeyExists(arguments.access, "HASPREMIUM")) {
        value = arguments.access.HASPREMIUM;
      }
      if (value EQ true OR value EQ 1) {
        return true;
      }
      return listFindNoCase("true,1,yes", trim(toString(value))) GT 0;
    </cfscript>
  </cffunction>

  <cffunction name="resolveExistingPremiumStartTrialStatus" access="private" returntype="string" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var qStripe = queryExecute(
        "SELECT stripe_subscription_status
         FROM member_entitlements
         WHERE user_id = :userId
           AND entitlement_type = 'premium'
           AND source = 'stripe_subscription'
           AND status = 'active'
           AND starts_at_utc <= UTC_TIMESTAMP()
           AND (expires_at_utc IS NULL OR expires_at_utc >= UTC_TIMESTAMP())
         ORDER BY updated_utc DESC, id DESC
         LIMIT 1",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
      var stripeStatus = "";

      if (qStripe.recordCount AND !isNull(qStripe.stripe_subscription_status[1])) {
        stripeStatus = lCase(trim(toString(qStripe.stripe_subscription_status[1])));
      }

      if (stripeStatus EQ "trialing") {
        return "already_trialing";
      }

      return "already_premium";
    </cfscript>
  </cffunction>

  <cffunction name="buildServiceResponse" access="private" returntype="struct" output="false">
    <cfargument name="serviceResult" type="struct" required="true">
    <cfargument name="actionName" type="string" required="true">
    <cfscript>
      var success = structKeyExists(arguments.serviceResult, "SUCCESS") AND arguments.serviceResult.SUCCESS EQ true;
      var promoType = safePromoType(arguments.serviceResult);
      var nextAction = safeNextAction(arguments.serviceResult);
      var message = safeServiceMessage(arguments.serviceResult, arguments.actionName, promoType, nextAction, success);
      var errorCode = success ? "" : mapPromoError(readErrorCode(arguments.serviceResult));
      var response = structNew("ordered-casesensitive");

      response["SUCCESS"] = success;
      response["success"] = success;
      response["AUTH"] = true;
      response["auth"] = true;
      response["eligible"] = success AND structKeyExists(arguments.serviceResult, "eligible") ? arguments.serviceResult.eligible : false;
      response["promoType"] = promoType;
      response["nextAction"] = nextAction;
      response["MESSAGE"] = message;
      response["message"] = message;
      response["ERROR"] = errorCode;
      response["errorCode"] = errorCode;

      if (success AND nextAction EQ "stripe_checkout_required") {
        response["NOTICE_CODE"] = "CHECKOUT_WIRING_PENDING";
        response["noticeCode"] = "CHECKOUT_WIRING_PENDING";
      }
      if (success AND nextAction EQ "stripe_trial_checkout") {
        response["CHECKOUT_URL"] = readServiceString(arguments.serviceResult, "CHECKOUT_URL", "checkoutUrl");
        response["checkoutUrl"] = response["CHECKOUT_URL"];
        response["STRIPE_CHECKOUT_SESSION_ID"] = readServiceString(arguments.serviceResult, "STRIPE_CHECKOUT_SESSION_ID", "stripeCheckoutSessionId");
        response["stripeCheckoutSessionId"] = response["STRIPE_CHECKOUT_SESSION_ID"];
        response["TRIAL_DAYS"] = readServiceNumeric(arguments.serviceResult, "TRIAL_DAYS", "trialDays");
        response["trialDays"] = response["TRIAL_DAYS"];
        response["REUSED_CHECKOUT_SESSION"] = readServiceBoolean(arguments.serviceResult, "REUSED_CHECKOUT_SESSION", "reusedCheckoutSession");
        response["reusedCheckoutSession"] = response["REUSED_CHECKOUT_SESSION"];
      }
      if (success AND nextAction EQ "stripe_trial_subscription") {
        response["CHECKOUT_REQUIRED"] = false;
        response["checkoutRequired"] = false;
        response["STATUS"] = readServiceString(arguments.serviceResult, "STATUS", "status");
        response["status"] = response["STATUS"];
        response["STRIPE_CUSTOMER_ID"] = readServiceString(arguments.serviceResult, "STRIPE_CUSTOMER_ID", "stripeCustomerId");
        response["stripeCustomerId"] = response["STRIPE_CUSTOMER_ID"];
        response["STRIPE_SUBSCRIPTION_ID"] = readServiceString(arguments.serviceResult, "STRIPE_SUBSCRIPTION_ID", "stripeSubscriptionId");
        response["stripeSubscriptionId"] = response["STRIPE_SUBSCRIPTION_ID"];
        response["TRIAL_DAYS"] = readServiceNumeric(arguments.serviceResult, "TRIAL_DAYS", "trialDays");
        response["trialDays"] = response["TRIAL_DAYS"];
        response["REDIRECT_URL"] = resolveFpwBasePath() & "/app/dashboard.cfm";
        response["redirectUrl"] = response["REDIRECT_URL"];
      }

      return response;
    </cfscript>
  </cffunction>

  <cffunction name="safePromoType" access="private" returntype="string" output="false">
    <cfargument name="serviceResult" type="struct" required="true">
    <cfscript>
      var promoType = "";
      if (structKeyExists(arguments.serviceResult, "promoType")) {
        promoType = lCase(trim(toString(arguments.serviceResult.promoType)));
      }
      return listFindNoCase("founder_lifetime,stripe_free_months", promoType) ? promoType : "";
    </cfscript>
  </cffunction>

  <cffunction name="safeNextAction" access="private" returntype="string" output="false">
    <cfargument name="serviceResult" type="struct" required="true">
    <cfscript>
      var nextAction = "";
      if (structKeyExists(arguments.serviceResult, "nextAction")) {
        nextAction = lCase(trim(toString(arguments.serviceResult.nextAction)));
      }
      return listFindNoCase("redeem_founder_lifetime,founder_lifetime_redeemed,stripe_checkout_required,stripe_trial_checkout,stripe_trial_subscription", nextAction) ? nextAction : "";
    </cfscript>
  </cffunction>

  <cffunction name="safeServiceMessage" access="private" returntype="string" output="false">
    <cfargument name="serviceResult" type="struct" required="true">
    <cfargument name="actionName" type="string" required="true">
    <cfargument name="promoType" type="string" required="true">
    <cfargument name="nextAction" type="string" required="true">
    <cfargument name="success" type="boolean" required="true">
    <cfscript>
      var errorCode = mapPromoError(readErrorCode(arguments.serviceResult));

      if (arguments.success AND arguments.nextAction EQ "stripe_trial_checkout") {
        if (structKeyExists(arguments.serviceResult, "displayMessage") AND len(trim(toString(arguments.serviceResult.displayMessage)))) {
          return trim(toString(arguments.serviceResult.displayMessage));
        }
        return "No-credit-card trial checkout is ready.";
      }
      if (arguments.success AND arguments.nextAction EQ "stripe_trial_subscription") {
        if (structKeyExists(arguments.serviceResult, "displayMessage") AND len(trim(toString(arguments.serviceResult.displayMessage)))) {
          return trim(toString(arguments.serviceResult.displayMessage));
        }
        if (structKeyExists(arguments.serviceResult, "MESSAGE") AND len(trim(toString(arguments.serviceResult.MESSAGE)))) {
          return trim(toString(arguments.serviceResult.MESSAGE));
        }
        return "Your Premium trial has started. Activation may take a moment.";
      }
      if (arguments.success AND arguments.nextAction EQ "stripe_checkout_required") {
        return "Launch trial code recognized. Redeem to start cardless checkout.";
      }
      if (arguments.success AND arguments.nextAction EQ "founder_lifetime_redeemed") {
        return "Founders Lifetime Premium has been added to your account.";
      }
      if (arguments.success AND arguments.promoType EQ "founder_lifetime") {
        return arguments.actionName EQ "validate"
          ? "Founders Lifetime Premium code is eligible."
          : "Founders Lifetime Premium has been added to your account.";
      }
      if (arguments.success AND structKeyExists(arguments.serviceResult, "displayMessage")) {
        return trim(toString(arguments.serviceResult.displayMessage));
      }
      return messageForError(errorCode);
    </cfscript>
  </cffunction>

  <cffunction name="readErrorCode" access="private" returntype="string" output="false">
    <cfargument name="serviceResult" type="struct" required="true">
    <cfscript>
      if (structKeyExists(arguments.serviceResult, "ERROR")) {
        return trim(toString(arguments.serviceResult.ERROR));
      }
      if (structKeyExists(arguments.serviceResult, "errorCode")) {
        return trim(toString(arguments.serviceResult.errorCode));
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="mapPromoError" access="private" returntype="string" output="false">
    <cfargument name="serviceCode" type="string" required="true">
    <cfscript>
      switch (uCase(trim(arguments.serviceCode))) {
        case "PROMO_CODE_REQUIRED":
          return "CODE_REQUIRED";
        case "PROMO_CODE_NOT_FOUND":
          return "CODE_NOT_FOUND";
        case "PROMO_CODE_DISABLED":
          return "CODE_DISABLED";
        case "PROMO_NOT_STARTED":
          return "CODE_NOT_STARTED";
        case "PROMO_EXPIRED":
          return "CODE_EXPIRED";
        case "PROMO_ALREADY_REDEEMED":
          return "CODE_ALREADY_REDEEMED";
        case "PROMO_MAX_REDEMPTIONS_REACHED":
          return "CODE_MAX_REDEMPTIONS_REACHED";
        case "PROMO_FREE_TRIAL_ALREADY_USED":
          return "FREE_TRIAL_ALREADY_USED";
        case "PROMO_INVALID_TRIAL_DURATION":
          return "INVALID_TRIAL_DURATION";
        case "PROMO_UNSUPPORTED_TYPE":
          return "PROMO_TYPE_NOT_SUPPORTED";
        case "STRIPE_CONFIG_MISSING":
          return "STRIPE_CONFIG_MISSING";
        case "STRIPE_CHECKOUT_FAILED":
          return "STRIPE_CHECKOUT_FAILED";
        case "STRIPE_SUBSCRIPTION_FAILED":
          return "STRIPE_SUBSCRIPTION_FAILED";
        case "STRIPE_SUBSCRIPTION_LOOKUP_FAILED":
          return "STRIPE_SUBSCRIPTION_LOOKUP_FAILED";
        case "STRIPE_CUSTOMER_CREATE_FAILED":
          return "STRIPE_CUSTOMER_CREATE_FAILED";
        case "STRIPE_CUSTOMER_UPDATE_FAILED":
          return "STRIPE_CUSTOMER_UPDATE_FAILED";
        case "STRIPE_CUSTOMER_MAPPING_CONFLICT":
          return "STRIPE_CUSTOMER_MAPPING_CONFLICT";
        case "STRIPE_CHECKOUT_LOOKUP_FAILED":
          return "STRIPE_CHECKOUT_LOOKUP_FAILED";
        case "STRIPE_CHECKOUT_CONFIRMATION_PENDING":
          return "STRIPE_CHECKOUT_CONFIRMATION_PENDING";
        case "LAUNCH_PROMO_NOT_AVAILABLE":
          return "LAUNCH_PROMO_NOT_AVAILABLE";
        case "LAUNCH_PROMO_AMBIGUOUS":
          return "LAUNCH_PROMO_AMBIGUOUS";
        case "PROMO_REDEMPTION_FAILED":
          return "SERVER_ERROR";
        default:
          return len(trim(arguments.serviceCode)) ? uCase(trim(arguments.serviceCode)) : "SERVER_ERROR";
      }
    </cfscript>
  </cffunction>

  <cffunction name="messageForError" access="private" returntype="string" output="false">
    <cfargument name="errorCode" type="string" required="true">
    <cfscript>
      switch (uCase(trim(arguments.errorCode))) {
        case "CODE_REQUIRED":
          return "Enter a promo code.";
        case "CODE_NOT_FOUND":
          return "Promo code was not recognized.";
        case "CODE_DISABLED":
          return "Promo code is not active.";
        case "CODE_NOT_STARTED":
          return "Promo code is not active yet.";
        case "CODE_EXPIRED":
          return "Promo code has expired.";
        case "CODE_ALREADY_REDEEMED":
          return "Promo code has already been used for this account.";
        case "CODE_MAX_REDEMPTIONS_REACHED":
          return "Promo code has reached its redemption limit.";
        case "FREE_TRIAL_ALREADY_USED":
          return "A free trial has already been used for this account.";
        case "INVALID_TRIAL_DURATION":
          return "Free trial duration is not supported.";
        case "PROMO_TYPE_NOT_SUPPORTED":
          return "Promo code type is not supported.";
        case "STRIPE_CONFIG_MISSING":
          return "Trial checkout is not available right now.";
        case "STRIPE_CHECKOUT_FAILED":
          return "Trial checkout could not be started.";
        case "STRIPE_SUBSCRIPTION_FAILED":
          return "Trial subscription could not be started.";
        case "STRIPE_SUBSCRIPTION_LOOKUP_FAILED":
          return "Existing Stripe subscriptions could not be checked.";
        case "STRIPE_CUSTOMER_CREATE_FAILED":
        case "STRIPE_CUSTOMER_UPDATE_FAILED":
          return "Billing customer setup could not be completed.";
        case "STRIPE_CUSTOMER_MAPPING_CONFLICT":
          return "Billing customer setup needs account support.";
        case "STRIPE_CHECKOUT_LOOKUP_FAILED":
          return "Free-trial checkout could not be checked. Please try again shortly.";
        case "STRIPE_CHECKOUT_CONFIRMATION_PENDING":
          return "Free-trial checkout is being confirmed. Please refresh shortly.";
        case "LAUNCH_PROMO_NOT_AVAILABLE":
          return "The launch trial is not available right now.";
        case "LAUNCH_PROMO_AMBIGUOUS":
          return "Launch trial setup needs attention before checkout can start.";
        case "ALREADY_PREMIUM":
          return "Your account already has Premium access.";
        case "METHOD_NOT_ALLOWED":
          return "Use POST for promo code requests.";
        case "AUTH_REQUIRED":
          return "Log in to redeem promo codes.";
        default:
          return "Promo code request could not be completed.";
      }
    </cfscript>
  </cffunction>

  <cffunction name="readServiceString" access="private" returntype="string" output="false">
    <cfargument name="serviceResult" type="struct" required="true">
    <cfargument name="upperKey" type="string" required="true">
    <cfargument name="lowerKey" type="string" required="true">
    <cfscript>
      if (structKeyExists(arguments.serviceResult, arguments.upperKey) AND !isNull(arguments.serviceResult[arguments.upperKey])) {
        return trim(toString(arguments.serviceResult[arguments.upperKey]));
      }
      if (structKeyExists(arguments.serviceResult, arguments.lowerKey) AND !isNull(arguments.serviceResult[arguments.lowerKey])) {
        return trim(toString(arguments.serviceResult[arguments.lowerKey]));
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="readServiceNumeric" access="private" returntype="numeric" output="false">
    <cfargument name="serviceResult" type="struct" required="true">
    <cfargument name="upperKey" type="string" required="true">
    <cfargument name="lowerKey" type="string" required="true">
    <cfscript>
      if (structKeyExists(arguments.serviceResult, arguments.upperKey) AND isNumeric(arguments.serviceResult[arguments.upperKey])) {
        return val(arguments.serviceResult[arguments.upperKey]);
      }
      if (structKeyExists(arguments.serviceResult, arguments.lowerKey) AND isNumeric(arguments.serviceResult[arguments.lowerKey])) {
        return val(arguments.serviceResult[arguments.lowerKey]);
      }
      return 0;
    </cfscript>
  </cffunction>

  <cffunction name="readServiceBoolean" access="private" returntype="boolean" output="false">
    <cfargument name="serviceResult" type="struct" required="true">
    <cfargument name="upperKey" type="string" required="true">
    <cfargument name="lowerKey" type="string" required="true">
    <cfscript>
      if (structKeyExists(arguments.serviceResult, arguments.upperKey)) {
        return arguments.serviceResult[arguments.upperKey] EQ true;
      }
      if (structKeyExists(arguments.serviceResult, arguments.lowerKey)) {
        return arguments.serviceResult[arguments.lowerKey] EQ true;
      }
      return false;
    </cfscript>
  </cffunction>

  <cffunction name="resolveFpwBasePath" access="private" returntype="string" output="false">
    <cfscript>
      var basePath = "";
      if (structKeyExists(request, "fpwBase") AND !isNull(request.fpwBase)) {
        basePath = trim(toString(request.fpwBase));
      }
      if (!len(basePath)) {
        basePath = getDirectoryFromPath(cgi.script_name);
        basePath = reReplace(basePath, "/api/v1/?$", "", "one");
        basePath = reReplace(basePath, "/$", "", "one");
      }
      if (basePath EQ "/") {
        basePath = "";
      }
      request.fpwBase = basePath;
      return basePath;
    </cfscript>
  </cffunction>

  <cffunction name="buildErrorResponse" access="private" returntype="struct" output="false">
    <cfargument name="success" type="boolean" required="true">
    <cfargument name="auth" type="boolean" required="true">
    <cfargument name="errorCode" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfscript>
      var response = structNew("ordered-casesensitive");
      response["SUCCESS"] = arguments.success;
      response["success"] = arguments.success;
      response["AUTH"] = arguments.auth;
      response["auth"] = arguments.auth;
      response["eligible"] = false;
      response["promoType"] = "";
      response["nextAction"] = "";
      response["ERROR"] = arguments.errorCode;
      response["errorCode"] = arguments.errorCode;
      response["MESSAGE"] = arguments.message;
      response["message"] = arguments.message;
      return response;
    </cfscript>
  </cffunction>

</cfcomponent>
