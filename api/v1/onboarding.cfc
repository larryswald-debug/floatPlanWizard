<cfcomponent output="false">

  <cffunction name="handle" access="remote" returntype="void" output="true">
    <cfargument name="action" type="string" required="false" default="">
    <cfargument name="userId" type="string" required="false" default="">
    <cfargument name="memberId" type="string" required="false" default="">
    <cfargument name="accountId" type="string" required="false" default="">
    <cfsetting enablecfoutputonly="true" showdebugoutput="false">
    <cfcontent type="application/json; charset=utf-8">
    <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

    <cfscript>
      var response = structNew("ordered-casesensitive");
      var body = {};
      var actionName = "";
      var requestMethod = structKeyExists(cgi, "request_method") ? uCase(trim(toString(cgi.request_method))) : "GET";
      var sessionUserId = resolveSessionUserId();
      var onboardingService = {};
      var onboardingState = {};
      var acknowledgment = {};
      var visibilityPreference = {};

      try {
        body = readBodyJson();
        actionName = lCase(trim(arguments.action));
        if (!len(actionName) AND structKeyExists(url, "action")) {
          actionName = lCase(trim(toString(url.action)));
        }
        if (!len(actionName) AND structKeyExists(body, "action")) {
          actionName = lCase(trim(toString(body.action)));
        }
        if (!len(actionName) AND requestMethod EQ "GET") {
          actionName = "state";
        }

        if (sessionUserId LTE 0) {
          cfheader(statuscode = 401);
          writeJson(failure("AUTH_REQUIRED", "Log in to access onboarding."));
          return;
        }

        if (hasSuppliedAccountIdentifier(body)) {
          cfheader(statuscode = 400);
          writeJson(failure("ACCOUNT_IDENTIFIER_NOT_ALLOWED", "Onboarding requests use only the authenticated account."));
          return;
        }

        if (actionName EQ "state") {
          if (requestMethod NEQ "GET") {
            cfheader(statuscode = 405);
            writeJson(failure("METHOD_NOT_ALLOWED", "Use GET for onboarding state."));
            return;
          }
          onboardingService = getOnboardingService();
          onboardingState = onboardingService.getState(sessionUserId);
          response = successResponse(onboardingState);
          writeJson(response);
          return;
        }

        if (actionName EQ "acknowledge") {
          if (requestMethod NEQ "POST") {
            cfheader(statuscode = 405);
            writeJson(failure("METHOD_NOT_ALLOWED", "Use POST to acknowledge Welcome onboarding."));
            return;
          }
          onboardingService = getOnboardingService();
          acknowledgment = onboardingService.acknowledgeWelcome(sessionUserId);
          if (!structKeyExists(acknowledgment, "SUCCESS") OR !acknowledgment.SUCCESS) {
            cfheader(statuscode = 500);
            writeJson(
              failure(
                structKeyExists(acknowledgment, "ERROR") ? acknowledgment.ERROR : "ACKNOWLEDGMENT_FAILED",
                structKeyExists(acknowledgment, "MESSAGE") ? acknowledgment.MESSAGE : "The Welcome acknowledgment could not be saved."
              )
            );
            return;
          }
          onboardingState = onboardingService.getState(sessionUserId);
          response = successResponse(onboardingState);
          writeJson(response);
          return;
        }

        if (actionName EQ "set-getting-started-hidden") {
          if (requestMethod NEQ "POST") {
            cfheader(statuscode = 405);
            writeJson(failure("METHOD_NOT_ALLOWED", "Use POST to save the Getting Started preference."));
            return;
          }
          if (
            !structKeyExists(body, "hidden")
            OR isNull(body.hidden)
            OR !isStrictJsonBoolean(body.hidden)
          ) {
            cfheader(statuscode = 400);
            writeJson(failure("INVALID_HIDDEN_PREFERENCE", "The hidden preference must be a JSON boolean."));
            return;
          }
          onboardingService = getOnboardingService();
          visibilityPreference = onboardingService.setGettingStartedHidden(
            sessionUserId,
            body.hidden
          );
          if (
            !structKeyExists(visibilityPreference, "SUCCESS")
            OR !visibilityPreference.SUCCESS
          ) {
            cfheader(statuscode = 500);
            writeJson(
              failure(
                structKeyExists(visibilityPreference, "ERROR")
                  ? visibilityPreference.ERROR
                  : "PREFERENCE_SAVE_FAILED",
                structKeyExists(visibilityPreference, "MESSAGE")
                  ? visibilityPreference.MESSAGE
                  : "The Getting Started preference could not be saved."
              )
            );
            return;
          }
          onboardingState = onboardingService.getState(sessionUserId);
          response = successResponse(onboardingState);
          writeJson(response);
          return;
        }

        cfheader(statuscode = 400);
        writeJson(failure("INVALID_ACTION", "Onboarding action is not supported."));
      } catch (any requestError) {
        cfheader(statuscode = 500);
        writeJson(failure("SERVER_ERROR", "The onboarding request could not be completed."));
      }
    </cfscript>

    <cfsetting enablecfoutputonly="false">
  </cffunction>

  <cffunction name="readBodyJson" access="private" returntype="struct" output="false">
    <cfscript>
      var requestData = getHttpRequestData();
      var rawBody = structKeyExists(requestData, "content") ? trim(toString(requestData.content)) : "";
      var parsed = {};
      if (!len(rawBody)) {
        return {};
      }
      try {
        parsed = deserializeJSON(rawBody, false);
        return isStruct(parsed) ? parsed : {};
      } catch (any invalidJson) {
        return {};
      }
    </cfscript>
  </cffunction>

  <cffunction name="isStrictJsonBoolean" access="private" returntype="boolean" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      try {
        return compare(
          arguments.value.getClass().getName(),
          "java.lang.Boolean"
        ) EQ 0;
      } catch (any invalidBoolean) {
        return false;
      }
    </cfscript>
  </cffunction>

  <cffunction name="hasSuppliedAccountIdentifier" access="private" returntype="boolean" output="false">
    <cfargument name="body" type="struct" required="true">
    <cfscript>
      var forbiddenKeys = [ "userId", "memberId", "accountId" ];
      var keyName = "";
      for (keyName in forbiddenKeys) {
        if (
          structKeyExists(url, keyName)
          OR structKeyExists(form, keyName)
          OR structKeyExists(arguments.body, keyName)
        ) {
          return true;
        }
      }
      return false;
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

  <cffunction name="successResponse" access="private" returntype="struct" output="false">
    <cfargument name="onboardingState" type="struct" required="true">
    <cfscript>
      var result = structNew("ordered-casesensitive");
      result["SUCCESS"] = true;
      result["success"] = true;
      result["ONBOARDING"] = arguments.onboardingState;
      result["onboarding"] = arguments.onboardingState;
      return result;
    </cfscript>
  </cffunction>

  <cffunction name="failure" access="private" returntype="struct" output="false">
    <cfargument name="errorCode" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfscript>
      var result = structNew("ordered-casesensitive");
      result["SUCCESS"] = false;
      result["success"] = false;
      result["ERROR"] = arguments.errorCode;
      result["errorCode"] = arguments.errorCode;
      result["MESSAGE"] = arguments.message;
      result["message"] = arguments.message;
      return result;
    </cfscript>
  </cffunction>

  <cffunction name="writeJson" access="private" returntype="void" output="true">
    <cfargument name="payload" type="struct" required="true">
    <cfscript>
      writeOutput(serializeJSON(arguments.payload));
    </cfscript>
  </cffunction>

  <cffunction name="getOnboardingService" access="private" returntype="any" output="false">
    <cfscript>
      try {
        return createObject("component", "fpw.api.v1.OnboardingService").init("fpw");
      } catch (any primaryPathError) {
        return createObject("component", "api.v1.OnboardingService").init("fpw");
      }
    </cfscript>
  </cffunction>

</cfcomponent>
