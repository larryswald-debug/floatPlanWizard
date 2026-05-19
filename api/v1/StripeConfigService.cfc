<cfcomponent output="false">

  <cfset variables.configPath = "">
  <cfset variables.requiredKeys = [
    "FPW_ENV",
    "FPW_STRIPE_SECRET_KEY",
    "FPW_STRIPE_WEBHOOK_SECRET",
    "FPW_STRIPE_PRICE_PREMIUM_MONTHLY",
    "FPW_STRIPE_PRICE_PREMIUM_YEARLY",
    "FPW_STRIPE_SUCCESS_URL",
    "FPW_STRIPE_CANCEL_URL",
    "FPW_STRIPE_PORTAL_RETURN_URL",
    "FPW_MONITOR_TOKEN"
  ]>

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="configPath" type="string" required="false" default="">
    <cfscript>
      if (len(trim(arguments.configPath))) {
        variables.configPath = trim(arguments.configPath);
      } else if (isDefined("application") AND structKeyExists(application, "stripeConfigPath") AND len(trim(toString(application.stripeConfigPath)))) {
        variables.configPath = trim(toString(application.stripeConfigPath));
      } else {
        variables.configPath = expandPath("/_fpw_private/stripe-config.json");
      }
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="getSecretKey" access="public" returntype="string" output="false">
    <cfscript>
      return getRequiredValue("FPW_STRIPE_SECRET_KEY");
    </cfscript>
  </cffunction>

  <cffunction name="getWebhookSecret" access="public" returntype="string" output="false">
    <cfscript>
      return getRequiredValue("FPW_STRIPE_WEBHOOK_SECRET");
    </cfscript>
  </cffunction>

  <cffunction name="getPremiumMonthlyPriceId" access="public" returntype="string" output="false">
    <cfscript>
      return getRequiredValue("FPW_STRIPE_PRICE_PREMIUM_MONTHLY");
    </cfscript>
  </cffunction>

  <cffunction name="getPremiumYearlyPriceId" access="public" returntype="string" output="false">
    <cfscript>
      return getRequiredValue("FPW_STRIPE_PRICE_PREMIUM_YEARLY");
    </cfscript>
  </cffunction>

  <cffunction name="getThreeDayPassPriceId" access="public" returntype="string" output="false">
    <cfscript>
      return getRequiredValue("FPW_STRIPE_PRICE_THREE_DAY_PASS");
    </cfscript>
  </cffunction>

  <cffunction name="getCheckoutSuccessUrl" access="public" returntype="string" output="false">
    <cfscript>
      return getRequiredValue("FPW_STRIPE_SUCCESS_URL");
    </cfscript>
  </cffunction>

  <cffunction name="getCheckoutCancelUrl" access="public" returntype="string" output="false">
    <cfscript>
      return getRequiredValue("FPW_STRIPE_CANCEL_URL");
    </cfscript>
  </cffunction>

  <cffunction name="getBillingPortalReturnUrl" access="public" returntype="string" output="false">
    <cfscript>
      return getRequiredValue("FPW_STRIPE_PORTAL_RETURN_URL");
    </cfscript>
  </cffunction>

  <cffunction name="getFpwEnv" access="public" returntype="string" output="false">
    <cfscript>
      return getRequiredValue("FPW_ENV");
    </cfscript>
  </cffunction>

  <cffunction name="getMonitorToken" access="public" returntype="string" output="false">
    <cfscript>
      return getRequiredValue("FPW_MONITOR_TOKEN");
    </cfscript>
  </cffunction>

  <cffunction name="getApplicationSettings" access="public" returntype="struct" output="false">
    <cfscript>
      return {
        "monitorToken" = getMonitorToken(),
        "env" = getFpwEnv(),
        "FPW_ENV" = getFpwEnv(),
        "FPW_MONITOR_TOKEN" = getMonitorToken(),
        "FPW_STRIPE_SECRET_KEY" = getSecretKey(),
        "FPW_STRIPE_WEBHOOK_SECRET" = getWebhookSecret(),
        "FPW_STRIPE_PRICE_PREMIUM_MONTHLY" = getPremiumMonthlyPriceId(),
        "FPW_STRIPE_PRICE_PREMIUM_YEARLY" = getPremiumYearlyPriceId(),
        "FPW_STRIPE_PRICE_THREE_DAY_PASS" = getThreeDayPassPriceId(),
        "FPW_STRIPE_SUCCESS_URL" = getCheckoutSuccessUrl(),
        "FPW_STRIPE_CANCEL_URL" = getCheckoutCancelUrl(),
        "FPW_STRIPE_PORTAL_RETURN_URL" = getBillingPortalReturnUrl(),
        "FPW_STRIPE_CHECKOUT_SUCCESS_URL" = getCheckoutSuccessUrl(),
        "FPW_STRIPE_CHECKOUT_CANCEL_URL" = getCheckoutCancelUrl(),
        "FPW_STRIPE_BILLING_PORTAL_RETURN_URL" = getBillingPortalReturnUrl()
      };
    </cfscript>
  </cffunction>

  <cffunction name="getConfigStatus" access="public" returntype="struct" output="false">
    <cfscript>
      var loadResult = loadConfig();
      var response = {
        "SUCCESS" = loadResult.SUCCESS,
        "success" = loadResult.SUCCESS,
        "hasSecretKey" = false,
        "hasWebhookSecret" = false,
        "hasPremiumMonthlyPriceId" = false,
        "hasPremiumYearlyPriceId" = false,
        "hasThreeDayPassPriceId" = false,
        "hasCheckoutSuccessUrl" = false,
        "hasCheckoutCancelUrl" = false,
        "hasBillingPortalReturnUrl" = false,
        "configSource" = "json"
      };

      if (!loadResult.SUCCESS) {
        response["ERROR"] = loadResult.ERROR;
        response["errorCode"] = loadResult.ERROR;
        response["MESSAGE"] = loadResult.MESSAGE;
        response["message"] = loadResult.MESSAGE;
        return response;
      }

      response["hasSecretKey"] = len(readValue(loadResult.config, "FPW_STRIPE_SECRET_KEY")) GT 0;
      response["hasWebhookSecret"] = len(readValue(loadResult.config, "FPW_STRIPE_WEBHOOK_SECRET")) GT 0;
      response["hasPremiumMonthlyPriceId"] = len(readValue(loadResult.config, "FPW_STRIPE_PRICE_PREMIUM_MONTHLY")) GT 0;
      response["hasPremiumYearlyPriceId"] = len(readValue(loadResult.config, "FPW_STRIPE_PRICE_PREMIUM_YEARLY")) GT 0;
      response["hasThreeDayPassPriceId"] = len(readValue(loadResult.config, "FPW_STRIPE_PRICE_THREE_DAY_PASS")) GT 0;
      response["hasCheckoutSuccessUrl"] = len(readValue(loadResult.config, "FPW_STRIPE_SUCCESS_URL")) GT 0;
      response["hasCheckoutCancelUrl"] = len(readValue(loadResult.config, "FPW_STRIPE_CANCEL_URL")) GT 0;
      response["hasBillingPortalReturnUrl"] = len(readValue(loadResult.config, "FPW_STRIPE_PORTAL_RETURN_URL")) GT 0;
      return response;
    </cfscript>
  </cffunction>

  <cffunction name="getRequiredValue" access="private" returntype="string" output="false">
    <cfargument name="name" type="string" required="true">
    <cfscript>
      var loadResult = loadConfig();
      if (!loadResult.SUCCESS) {
        return "";
      }
      return readValue(loadResult.config, arguments.name);
    </cfscript>
  </cffunction>

  <cffunction name="loadConfig" access="private" returntype="struct" output="false">
    <cfscript>
      var rawContent = "";
      var parsedConfig = {};
      var key = "";

      if (!fileExists(variables.configPath)) {
        return buildConfigError("STRIPE_CONFIG_FILE_MISSING", "Stripe JSON configuration is missing.");
      }

      try {
        rawContent = fileRead(variables.configPath, "utf-8");
      } catch (any readErr) {
        return buildConfigError("STRIPE_CONFIG_FILE_UNREADABLE", "Stripe JSON configuration could not be read.");
      }

      try {
        parsedConfig = deserializeJSON(rawContent, false);
      } catch (any parseErr) {
        return buildConfigError("STRIPE_CONFIG_JSON_INVALID", "Stripe JSON configuration is invalid.");
      }

      if (!isStruct(parsedConfig)) {
        return buildConfigError("STRIPE_CONFIG_JSON_INVALID", "Stripe JSON configuration is invalid.");
      }

      for (key in variables.requiredKeys) {
        if (!structKeyExists(parsedConfig, key)) {
          return buildConfigError("STRIPE_CONFIG_KEY_MISSING", "Stripe JSON configuration is incomplete.");
        }
        if (!len(readValue(parsedConfig, key))) {
          return buildConfigError("STRIPE_CONFIG_KEY_BLANK", "Stripe JSON configuration is incomplete.");
        }
      }

      return {
        "SUCCESS" = true,
        "success" = true,
        "config" = parsedConfig
      };
    </cfscript>
  </cffunction>

  <cffunction name="readValue" access="private" returntype="string" output="false">
    <cfargument name="source" type="struct" required="true">
    <cfargument name="name" type="string" required="true">
    <cfscript>
      if (structKeyExists(arguments.source, arguments.name) AND !isNull(arguments.source[arguments.name])) {
        return trim(toString(arguments.source[arguments.name]));
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="buildConfigError" access="private" returntype="struct" output="false">
    <cfargument name="errorCode" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfscript>
      return {
        "SUCCESS" = false,
        "success" = false,
        "ERROR" = arguments.errorCode,
        "errorCode" = arguments.errorCode,
        "MESSAGE" = arguments.message,
        "message" = arguments.message,
        "config" = {}
      };
    </cfscript>
  </cffunction>

</cfcomponent>
