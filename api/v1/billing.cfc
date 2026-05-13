<cfcomponent output="false">

  <cffunction name="handle" access="remote" returntype="void" output="true">
    <cfargument name="action" type="string" required="false" default="">
    <cfargument name="interval" type="string" required="false" default="">
    <cfsetting enablecfoutputonly="true" showdebugoutput="false">
    <cfcontent type="application/json; charset=utf-8">
    <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

    <cftry>
      <cfset var response = {}>
      <cfset var body = getBodyJson()>
      <cfset var act = lCase(trim(arguments.action))>
      <cfset var userId = 0>
      <cfset var access = {}>
      <cfset var intervalValue = readRequestedInterval(body, arguments.interval)>

      <cfif NOT len(act) AND isStruct(body) AND structKeyExists(body, "action")>
        <cfset act = lCase(trim(toString(body.action)))>
      </cfif>

      <cfif act NEQ "createcheckoutsession">
        <cfset response = buildErrorResponse(false, false, "INVALID_ACTION", "Billing action is not supported.")>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfreturn>
      </cfif>

      <cfif uCase(trim(cgi.request_method)) NEQ "POST">
        <cfheader statuscode="405">
        <cfset response = buildErrorResponse(false, false, "METHOD_NOT_ALLOWED", "Use POST to create a checkout session.")>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfreturn>
      </cfif>

      <cfif NOT structKeyExists(session, "user") OR NOT isStruct(session.user)>
        <cfset response = buildErrorResponse(false, false, "AUTH_REQUIRED", "Log in to continue.")>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfreturn>
      </cfif>

      <cfset userId = resolveSessionUserId()>
      <cfif userId LTE 0>
        <cfset response = buildErrorResponse(false, false, "INVALID_SESSION", "Session user is invalid.")>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfreturn>
      </cfif>

      <cfset access = new fpw.api.v1.MemberEntitlementService().init("fpw").getCurrentAccess(userId)>
      <cfif structKeyExists(access, "hasPremium") AND access.hasPremium EQ true>
        <cfset response = buildErrorResponse(false, true, "ALREADY_PREMIUM", "Your account already has Premium access.")>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfreturn>
      </cfif>

      <cfset response = new fpw.api.v1.StripeCheckoutService().init("fpw").createCheckoutSession(userId, intervalValue)>
      <cfset response["AUTH"] = true>
      <cfset response["auth"] = true>
      <cfoutput>#serializeJSON(response)#</cfoutput>

      <cfcatch type="any">
        <cfset response = buildErrorResponse(false, false, "STRIPE_CHECKOUT_FAILED", "Stripe checkout session could not be created.")>
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

  <cffunction name="readRequestedInterval" access="private" returntype="string" output="false">
    <cfargument name="body" type="struct" required="true">
    <cfargument name="intervalArg" type="string" required="true">
    <cfscript>
      if (structKeyExists(arguments.body, "interval")) {
        return trim(toString(arguments.body.interval));
      }
      if (structKeyExists(arguments.body, "INTERVAL")) {
        return trim(toString(arguments.body.INTERVAL));
      }
      return trim(arguments.intervalArg);
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
      response["ERROR"] = arguments.errorCode;
      response["errorCode"] = arguments.errorCode;
      response["MESSAGE"] = arguments.message;
      response["message"] = arguments.message;
      return response;
    </cfscript>
  </cffunction>

</cfcomponent>
