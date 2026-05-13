<cfcomponent output="false">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfscript>
      variables.env = createObject("java", "java.lang.System");
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="getSecretKey" access="public" returntype="string" output="false">
    <cfscript>
      return getEnvValue("FPW_STRIPE_SECRET_KEY");
    </cfscript>
  </cffunction>

  <cffunction name="getWebhookSecret" access="public" returntype="string" output="false">
    <cfscript>
      return getEnvValue("FPW_STRIPE_WEBHOOK_SECRET");
    </cfscript>
  </cffunction>

  <cffunction name="getPremiumMonthlyPriceId" access="public" returntype="string" output="false">
    <cfscript>
      return getEnvValue("FPW_STRIPE_PRICE_PREMIUM_MONTHLY");
    </cfscript>
  </cffunction>

  <cffunction name="getPremiumYearlyPriceId" access="public" returntype="string" output="false">
    <cfscript>
      return getEnvValue("FPW_STRIPE_PRICE_PREMIUM_YEARLY");
    </cfscript>
  </cffunction>

  <cffunction name="getCheckoutSuccessUrl" access="public" returntype="string" output="false">
    <cfscript>
      return getEnvValue("FPW_STRIPE_CHECKOUT_SUCCESS_URL");
    </cfscript>
  </cffunction>

  <cffunction name="getCheckoutCancelUrl" access="public" returntype="string" output="false">
    <cfscript>
      return getEnvValue("FPW_STRIPE_CHECKOUT_CANCEL_URL");
    </cfscript>
  </cffunction>

  <cffunction name="getConfigStatus" access="public" returntype="struct" output="false">
    <cfscript>
      return {
        "SUCCESS" = true,
        "success" = true,
        "hasSecretKey" = len(getSecretKey()) GT 0,
        "hasWebhookSecret" = len(getWebhookSecret()) GT 0,
        "hasPremiumMonthlyPriceId" = len(getPremiumMonthlyPriceId()) GT 0,
        "hasPremiumYearlyPriceId" = len(getPremiumYearlyPriceId()) GT 0,
        "hasCheckoutSuccessUrl" = len(getCheckoutSuccessUrl()) GT 0,
        "hasCheckoutCancelUrl" = len(getCheckoutCancelUrl()) GT 0
      };
    </cfscript>
  </cffunction>

  <cffunction name="getEnvValue" access="private" returntype="string" output="false">
    <cfargument name="name" type="string" required="true">
    <cfscript>
      var value = variables.env.getenv(arguments.name);
      if (isNull(value)) {
        return "";
      }
      return trim(toString(value));
    </cfscript>
  </cffunction>

</cfcomponent>
