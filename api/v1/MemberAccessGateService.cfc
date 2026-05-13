<cfcomponent output="false">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfscript>
      variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
      variables.entitlementService = "";
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="getCurrentAccess" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      return getEntitlementService().getCurrentAccess(arguments.userId);
    </cfscript>
  </cffunction>

  <cffunction name="hasPremiumAccess" access="public" returntype="boolean" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      return getEntitlementService().hasPremiumAccess(arguments.userId);
    </cfscript>
  </cffunction>

  <cffunction name="getFeatureLimits" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      return getEntitlementService().getFeatureLimits(arguments.userId);
    </cfscript>
  </cffunction>

  <cffunction name="requireAuthenticated" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var access = getCurrentAccess(arguments.userId);
      if (!structKeyExists(access, "authenticated") OR !access.authenticated) {
        return denied(
          errorCode = "AUTH_REQUIRED",
          message = "Log in to continue.",
          auth = false,
          statusCode = 401,
          includeUpgradeOptions = false,
          access = access
        );
      }
      return allowed(access);
    </cfscript>
  </cffunction>

  <cffunction name="requirePremium" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="errorCode" type="string" required="false" default="PREMIUM_REQUIRED">
    <cfargument name="message" type="string" required="false" default="">
    <cfscript>
      var access = getCurrentAccess(arguments.userId);
      if (!structKeyExists(access, "authenticated") OR !access.authenticated) {
        return denied(
          errorCode = "AUTH_REQUIRED",
          message = "Log in to continue.",
          auth = false,
          statusCode = 401,
          includeUpgradeOptions = false,
          access = access
        );
      }
      if (structKeyExists(access, "hasPremium") AND access.hasPremium) {
        return allowed(access);
      }
      return denied(
        errorCode = arguments.errorCode,
        message = len(trim(arguments.message)) ? arguments.message : defaultPremiumMessage(),
        auth = true,
        statusCode = 403,
        includeUpgradeOptions = true,
        access = access
      );
    </cfscript>
  </cffunction>

  <cffunction name="validateWaypointLimit" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="waypointCount" type="numeric" required="true">
    <cfscript>
      var access = getCurrentAccess(arguments.userId);
      var maxWaypoints = 0;
      if (!structKeyExists(access, "authenticated") OR !access.authenticated) {
        return denied(
          errorCode = "AUTH_REQUIRED",
          message = "Log in to continue.",
          auth = false,
          statusCode = 401,
          includeUpgradeOptions = false,
          access = access
        );
      }
      if (structKeyExists(access, "hasPremium") AND access.hasPremium) {
        return allowed(access);
      }
      if (structKeyExists(access, "limits") AND structKeyExists(access.limits, "maxWaypoints") AND !isNull(access.limits.maxWaypoints)) {
        maxWaypoints = val(access.limits.maxWaypoints);
      }
      if (maxWaypoints GT 0 AND arguments.waypointCount GT maxWaypoints) {
        return denied(
          errorCode = "BASIC_WAYPOINT_LIMIT",
          message = "Basic members can include up to 2 saved waypoints on a float plan.",
          auth = true,
          statusCode = 403,
          includeUpgradeOptions = true,
          access = access
        );
      }
      return allowed(access);
    </cfscript>
  </cffunction>

  <cffunction name="validateTripDurationLimit" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="departureAt" required="false" default="">
    <cfargument name="returnAt" required="false" default="">
    <cfscript>
      var access = getCurrentAccess(arguments.userId);
      var maxTripDays = 0;
      var maxMinutes = 0;

      if (!structKeyExists(access, "authenticated") OR !access.authenticated) {
        return denied(
          errorCode = "AUTH_REQUIRED",
          message = "Log in to continue.",
          auth = false,
          statusCode = 401,
          includeUpgradeOptions = false,
          access = access
        );
      }
      if (structKeyExists(access, "hasPremium") AND access.hasPremium) {
        return allowed(access);
      }
      if (!isDate(arguments.departureAt) OR !isDate(arguments.returnAt)) {
        return allowed(access);
      }
      if (structKeyExists(access, "limits") AND structKeyExists(access.limits, "maxTripDays") AND !isNull(access.limits.maxTripDays)) {
        maxTripDays = val(access.limits.maxTripDays);
      }
      maxMinutes = maxTripDays * 24 * 60;
      if (maxMinutes GT 0 AND dateDiff("n", arguments.departureAt, arguments.returnAt) GT maxMinutes) {
        return denied(
          errorCode = "BASIC_TRIP_DAY_LIMIT",
          message = "Basic members can send float plans for trips up to 1 day.",
          auth = true,
          statusCode = 403,
          includeUpgradeOptions = true,
          access = access
        );
      }
      return allowed(access);
    </cfscript>
  </cffunction>

  <cffunction name="validateMonitoringMode" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="monitoringMode" type="string" required="true">
    <cfscript>
      var modeValue = lCase(trim(arguments.monitoringMode));
      if (modeValue EQ "basic") {
        return requireAuthenticated(arguments.userId);
      }
      return requirePremium(
        userId = arguments.userId,
        errorCode = "BASIC_ADVANCED_MONITORING_RESTRICTED",
        message = "Upgrade to Premium to use Active Cruise and advanced route monitoring."
      );
    </cfscript>
  </cffunction>

  <cffunction name="buildDeniedResponse" access="public" returntype="struct" output="false">
    <cfargument name="errorCode" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfargument name="auth" type="boolean" required="false" default="true">
    <cfargument name="statusCode" type="numeric" required="false" default="403">
    <cfargument name="includeUpgradeOptions" type="boolean" required="false" default="true">
    <cfscript>
      return buildResponse(
        errorCode = arguments.errorCode,
        message = arguments.message,
        auth = arguments.auth,
        statusCode = arguments.statusCode,
        includeUpgradeOptions = arguments.includeUpgradeOptions
      );
    </cfscript>
  </cffunction>

  <cffunction name="allowed" access="private" returntype="struct" output="false">
    <cfargument name="access" type="struct" required="true">
    <cfscript>
      return {
        "allowed" = true,
        "SUCCESS" = true,
        "success" = true,
        "access" = arguments.access
      };
    </cfscript>
  </cffunction>

  <cffunction name="denied" access="private" returntype="struct" output="false">
    <cfargument name="errorCode" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfargument name="auth" type="boolean" required="true">
    <cfargument name="statusCode" type="numeric" required="true">
    <cfargument name="includeUpgradeOptions" type="boolean" required="true">
    <cfargument name="access" type="struct" required="true">
    <cfscript>
      return {
        "allowed" = false,
        "SUCCESS" = false,
        "success" = false,
        "access" = arguments.access,
        "response" = buildResponse(
          errorCode = arguments.errorCode,
          message = arguments.message,
          auth = arguments.auth,
          statusCode = arguments.statusCode,
          includeUpgradeOptions = arguments.includeUpgradeOptions
        )
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildResponse" access="private" returntype="struct" output="false">
    <cfargument name="errorCode" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfargument name="auth" type="boolean" required="true">
    <cfargument name="statusCode" type="numeric" required="true">
    <cfargument name="includeUpgradeOptions" type="boolean" required="true">
    <cfscript>
      var response = {
        "SUCCESS" = false,
        "success" = false,
        "AUTH" = arguments.auth,
        "STATUS_CODE" = arguments.statusCode,
        "errorCode" = arguments.errorCode,
        "message" = arguments.message,
        "MESSAGE" = arguments.message,
        "ERROR" = {
          "CODE" = arguments.errorCode,
          "MESSAGE" = arguments.message
        }
      };
      if (arguments.includeUpgradeOptions) {
        response.upgradeOptions = {
          "monthly" = true,
          "threeDayPass" = true
        };
      }
      return response;
    </cfscript>
  </cffunction>

  <cffunction name="defaultPremiumMessage" access="private" returntype="string" output="false">
    <cfscript>
      return "Upgrade to Premium to save routes, plan multi-day trips, use Active Cruise, share a Follow Page, and unlock advanced monitoring.";
    </cfscript>
  </cffunction>

  <cffunction name="getEntitlementService" access="private" returntype="any" output="false">
    <cfscript>
      if (isObject(variables.entitlementService)) {
        return variables.entitlementService;
      }
      try {
        variables.entitlementService = createObject("component", "fpw.api.v1.MemberEntitlementService").init(variables.datasource);
      } catch (any primaryErr) {
        variables.entitlementService = createObject("component", "api.v1.MemberEntitlementService").init(variables.datasource);
      }
      return variables.entitlementService;
    </cfscript>
  </cffunction>

</cfcomponent>
