<cfcomponent output="false">

  <cffunction name="handle" access="remote" returntype="void" output="true">
    <cfargument name="action" type="string" required="false" default="">
    <cfargument name="interval" type="string" required="false" default="">
    <cfargument name="floatPlanId" type="numeric" required="false" default="0">
    <cfargument name="returnSurface" type="string" required="false" default="">
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
      <cfset var requestedFloatPlanId = readRequestedFloatPlanId(body, arguments.floatPlanId)>
      <cfset var requestedReturnNonce = readRequestedReturnNonce(body)>
      <cfset var requestedReturnSurface = readRequestedReturnSurface(body, arguments.returnSurface)>
      <cfset var qDraft = queryNew("")>
      <cfset var qOneTripCredit = queryNew("")>
      <cfset var oneTripReturnNonce = "">
      <cfset var oneTripReturnContext = {}>

      <cfif NOT len(act) AND isStruct(body) AND structKeyExists(body, "action")>
        <cfset act = lCase(trim(toString(body.action)))>
      </cfif>

      <cfif NOT listFindNoCase("createcheckoutsession,createportal,confirmonetripcheckout", act)>
        <cfset response = buildErrorResponse(false, false, "INVALID_ACTION", "Billing action is not supported.")>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfreturn>
      </cfif>

      <cfif uCase(trim(cgi.request_method)) NEQ "POST">
        <cfheader statuscode="405">
        <cfset response = buildErrorResponse(false, false, "METHOD_NOT_ALLOWED", "Use POST for billing requests.")>
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

      <cfif act EQ "createcheckoutsession">
        <cfif listFindNoCase("one_trip,monthly,yearly", intervalValue)>
          <cfset recordBillingProductEvent(
            userId = userId,
            eventName = intervalValue EQ "one_trip" ? "buy_one_trip_clicked" : (intervalValue EQ "monthly" ? "monthly_selected" : "annual_selected"),
            idempotencyKey = (intervalValue EQ "one_trip" ? "buy_one_trip_clicked" : (intervalValue EQ "monthly" ? "monthly_selected" : "annual_selected"))
              & ":request:" & (structKeyExists(request, "fpwRequestId") ? toString(request.fpwRequestId) : createUUID())
          )>
        </cfif>
        <cfset access = new fpw.api.v1.MemberEntitlementService().init("fpw").getCurrentAccess(userId)>
        <cfif structKeyExists(access, "hasPremium") AND access.hasPremium EQ true>
          <cfset response = buildErrorResponse(false, true, "ALREADY_PREMIUM", "Your account already has Premium access.")>
          <cfoutput>#serializeJSON(response)#</cfoutput>
          <cfreturn>
        </cfif>

        <cfif intervalValue EQ "one_trip"
            AND (
              NOT structKeyExists(application, "oneTripCheckoutAvailable")
              OR listFindNoCase("1,true,yes,on", lCase(trim(toString(application.oneTripCheckoutAvailable)))) EQ 0
            )>
          <cfset response = buildErrorResponse(false, true, "STRIPE_CONFIG_MISSING", "Buy One Trip checkout is not configured right now.")>
          <cfoutput>#serializeJSON(response)#</cfoutput>
          <cfreturn>
        </cfif>

        <cfif intervalValue EQ "one_trip">
          <cfif NOT len(requestedReturnSurface)>
            <cfset requestedReturnSurface = "standalone_wizard">
          <cfelseif NOT listFindNoCase("dashboard_modal,standalone_wizard", requestedReturnSurface)>
            <cfset response = buildErrorResponse(false, true, "INVALID_CHECKOUT_RETURN_SURFACE", "One-trip checkout return surface is invalid.")>
            <cfoutput>#serializeJSON(response)#</cfoutput>
            <cfreturn>
          </cfif>
        </cfif>

        <cfif intervalValue EQ "one_trip" AND requestedFloatPlanId GT 0>
          <cfset qDraft = queryExecute(
            "SELECT floatPlanId
             FROM floatplans
             WHERE floatPlanId = :floatPlanId
               AND userId = :userId
               AND UPPER(TRIM(status)) = 'DRAFT'
             LIMIT 1",
            {
              floatPlanId = { value = requestedFloatPlanId, cfsqltype = "cf_sql_integer" },
              userId = { value = toString(userId), cfsqltype = "cf_sql_varchar" }
            },
            { datasource = "fpw" }
          )>
          <cfif qDraft.recordCount NEQ 1>
            <cfset response = buildErrorResponse(false, true, "ONE_TRIP_DRAFT_REQUIRED", "Buy One Trip can return only to your saved Draft float plan.")>
            <cfoutput>#serializeJSON(response)#</cfoutput>
            <cfreturn>
          </cfif>
        </cfif>

        <cfif intervalValue EQ "one_trip">
          <cfset oneTripReturnNonce = lCase(hash(createUUID() & createUUID(), "SHA-256"))>
        </cfif>
        <cfset response = new fpw.api.v1.StripeCheckoutService().init("fpw").createCheckoutSession(
          userId = userId,
          interval = intervalValue,
          floatPlanId = requestedFloatPlanId,
          returnNonce = oneTripReturnNonce
        )>
        <cfif intervalValue EQ "one_trip"
            AND structKeyExists(response, "SUCCESS")
            AND response.SUCCESS EQ true
            AND structKeyExists(response, "stripeCheckoutSessionId")
            AND len(trim(toString(response.stripeCheckoutSessionId)))>
          <cfset rememberOneTripCheckoutReturn(
            returnNonce = oneTripReturnNonce,
            checkoutSessionId = trim(toString(response.stripeCheckoutSessionId)),
            userId = userId,
            floatPlanId = requestedFloatPlanId,
            returnSurface = requestedReturnSurface
          )>
          <cfset recordBillingProductEvent(
            userId = userId,
            eventName = "one_trip_checkout_created",
            idempotencyKey = "one_trip_checkout_created:checkout_sha256:" & lCase(hash(trim(toString(response.stripeCheckoutSessionId)), "SHA-256"))
          )>
          <cfset structDelete(response, "STRIPE_CHECKOUT_SESSION_ID", false)>
          <cfset structDelete(response, "stripeCheckoutSessionId", false)>
        </cfif>
      <cfelseif act EQ "confirmonetripcheckout">
        <cfif reFind("^[a-f0-9]{64}$", requestedReturnNonce) EQ 0>
          <cfset response = buildErrorResponse(false, true, "INVALID_CHECKOUT_CONFIRMATION", "One-trip checkout confirmation is invalid.")>
          <cfoutput>#serializeJSON(response)#</cfoutput>
          <cfreturn>
        </cfif>
        <cfset oneTripReturnContext = loadOneTripCheckoutReturn(requestedReturnNonce, userId)>
        <cfif NOT oneTripReturnContext.FOUND>
          <cfset response = buildErrorResponse(false, true, oneTripReturnContext.ERROR, oneTripReturnContext.MESSAGE)>
          <cfoutput>#serializeJSON(response)#</cfoutput>
          <cfreturn>
        </cfif>
        <cfset qOneTripCredit = queryExecute(
          "SELECT status
             FROM premium_send_credits
            WHERE user_id = :userId
              AND source = 'stripe_one_trip'
              AND stripe_checkout_session_id = :checkoutSessionId
            LIMIT 1",
          {
            userId = { value = userId, cfsqltype = "cf_sql_integer" },
            checkoutSessionId = { value = oneTripReturnContext.checkoutSessionId, cfsqltype = "cf_sql_varchar" }
          },
          { datasource = "fpw" }
        )>
        <cfset response = {
          "SUCCESS" = true,
          "success" = true,
          "RESOLVED" = qOneTripCredit.recordCount EQ 1,
          "resolved" = qOneTripCredit.recordCount EQ 1,
          "AVAILABLE" = qOneTripCredit.recordCount EQ 1 AND uCase(trim(toString(qOneTripCredit.status[1]))) EQ "AVAILABLE",
          "available" = qOneTripCredit.recordCount EQ 1 AND uCase(trim(toString(qOneTripCredit.status[1]))) EQ "AVAILABLE",
          "STATUS" = qOneTripCredit.recordCount EQ 1 ? uCase(trim(toString(qOneTripCredit.status[1]))) : "PENDING",
          "status" = qOneTripCredit.recordCount EQ 1 ? uCase(trim(toString(qOneTripCredit.status[1]))) : "PENDING",
          "FLOATPLANID" = oneTripReturnContext.floatPlanId,
          "floatPlanId" = oneTripReturnContext.floatPlanId,
          "RETURNSURFACE" = oneTripReturnContext.returnSurface,
          "returnSurface" = oneTripReturnContext.returnSurface,
          "MESSAGE" = qOneTripCredit.recordCount EQ 1 ? "Premium Send Credit confirmed." : "Premium Send Credit is still being confirmed.",
          "message" = qOneTripCredit.recordCount EQ 1 ? "Premium Send Credit confirmed." : "Premium Send Credit is still being confirmed."
        }>
      <cfelse>
        <cfset response = new fpw.api.v1.StripeCheckoutService().init("fpw").createPortalSession(userId)>
      </cfif>

      <cfset response["AUTH"] = true>
      <cfset response["auth"] = true>
      <cfoutput>#serializeJSON(response)#</cfoutput>

      <cfcatch type="any">
        <cfset response = buildErrorResponse(false, false, "STRIPE_BILLING_FAILED", "Stripe billing request could not be completed.")>
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

  <cffunction name="rememberOneTripCheckoutReturn" access="private" returntype="void" output="false">
    <cfargument name="returnNonce" type="string" required="true">
    <cfargument name="checkoutSessionId" type="string" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="floatPlanId" type="numeric" required="false" default="0">
    <cfargument name="returnSurface" type="string" required="false" default="standalone_wizard">
    <cflock scope="session" type="exclusive" timeout="5">
      <cfscript>
        var nonceKey = "";
        var entry = {};
        var nowUtc = dateConvert("local2utc", now());
        var normalizedReturnSurface = lCase(trim(arguments.returnSurface));
        if (!listFindNoCase("dashboard_modal,standalone_wizard", normalizedReturnSurface)) {
          normalizedReturnSurface = "standalone_wizard";
        }
        if (!structKeyExists(session, "fpwOneTripCheckoutReturns") OR !isStruct(session.fpwOneTripCheckoutReturns)) {
          session.fpwOneTripCheckoutReturns = {};
        }
        for (nonceKey in session.fpwOneTripCheckoutReturns) {
          entry = session.fpwOneTripCheckoutReturns[nonceKey];
          if (!isStruct(entry)
              OR !structKeyExists(entry, "expiresAtUtc")
              OR !isDate(entry.expiresAtUtc)
              OR dateCompare(nowUtc, entry.expiresAtUtc) GTE 0) {
            structDelete(session.fpwOneTripCheckoutReturns, nonceKey, false);
          }
        }
        session.fpwOneTripCheckoutReturns[lCase(trim(arguments.returnNonce))] = {
          checkoutSessionId = trim(arguments.checkoutSessionId),
          userId = int(val(arguments.userId)),
          floatPlanId = int(val(arguments.floatPlanId)),
          returnSurface = normalizedReturnSurface,
          expiresAtUtc = dateAdd("n", 60, nowUtc)
        };
      </cfscript>
    </cflock>
  </cffunction>

  <cffunction name="loadOneTripCheckoutReturn" access="private" returntype="struct" output="false">
    <cfargument name="returnNonce" type="string" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfset var result = {
      "FOUND" = false,
      "ERROR" = "CHECKOUT_CONFIRMATION_EXPIRED",
      "MESSAGE" = "This one-trip checkout confirmation has expired. Refresh your membership status."
    }>
    <cfset var nonceKey = lCase(trim(arguments.returnNonce))>
    <cfset var entry = {}>
    <cfset var nowUtc = dateConvert("local2utc", now())>
    <cflock scope="session" type="exclusive" timeout="5">
      <cfscript>
        if (structKeyExists(session, "fpwOneTripCheckoutReturns")
            AND isStruct(session.fpwOneTripCheckoutReturns)
            AND structKeyExists(session.fpwOneTripCheckoutReturns, nonceKey)
            AND isStruct(session.fpwOneTripCheckoutReturns[nonceKey])) {
          entry = session.fpwOneTripCheckoutReturns[nonceKey];
          if (!structKeyExists(entry, "expiresAtUtc")
              OR !isDate(entry.expiresAtUtc)
              OR dateCompare(nowUtc, entry.expiresAtUtc) GTE 0) {
            structDelete(session.fpwOneTripCheckoutReturns, nonceKey, false);
          } else if (!structKeyExists(entry, "userId") OR int(val(entry.userId)) NEQ int(val(arguments.userId))) {
            result.ERROR = "CHECKOUT_CONFIRMATION_OWNER_MISMATCH";
            result.MESSAGE = "This one-trip checkout confirmation does not belong to the authenticated member.";
          } else {
            result = duplicate(entry);
            if (!structKeyExists(result, "returnSurface")
                OR !listFindNoCase("dashboard_modal,standalone_wizard", lCase(trim(toString(result.returnSurface))))) {
              result.returnSurface = "standalone_wizard";
            } else {
              result.returnSurface = lCase(trim(toString(result.returnSurface)));
            }
            result.FOUND = true;
            result.ERROR = "";
            result.MESSAGE = "One-trip checkout return matched.";
          }
        }
      </cfscript>
    </cflock>
    <cfreturn result>
  </cffunction>

  <cffunction name="readRequestedReturnNonce" access="private" returntype="string" output="false">
    <cfargument name="body" type="struct" required="true">
    <cfscript>
      if (structKeyExists(arguments.body, "returnNonce") AND !isNull(arguments.body.returnNonce)) {
        return lCase(trim(toString(arguments.body.returnNonce)));
      }
      if (structKeyExists(arguments.body, "RETURNNONCE") AND !isNull(arguments.body.RETURNNONCE)) {
        return lCase(trim(toString(arguments.body.RETURNNONCE)));
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="readRequestedReturnSurface" access="private" returntype="string" output="false">
    <cfargument name="body" type="struct" required="true">
    <cfargument name="returnSurfaceArg" type="string" required="true">
    <cfscript>
      if (structKeyExists(arguments.body, "returnSurface") AND !isNull(arguments.body.returnSurface)) {
        return lCase(trim(toString(arguments.body.returnSurface)));
      }
      if (structKeyExists(arguments.body, "RETURNSURFACE") AND !isNull(arguments.body.RETURNSURFACE)) {
        return lCase(trim(toString(arguments.body.RETURNSURFACE)));
      }
      return lCase(trim(arguments.returnSurfaceArg));
    </cfscript>
  </cffunction>

  <cffunction name="readRequestedFloatPlanId" access="private" returntype="numeric" output="false">
    <cfargument name="body" type="struct" required="true">
    <cfargument name="floatPlanIdArg" type="numeric" required="true">
    <cfscript>
      if (structKeyExists(arguments.body, "floatPlanId") AND isNumeric(arguments.body.floatPlanId)) {
        return int(val(arguments.body.floatPlanId));
      }
      if (structKeyExists(arguments.body, "FLOATPLANID") AND isNumeric(arguments.body.FLOATPLANID)) {
        return int(val(arguments.body.FLOATPLANID));
      }
      return int(val(arguments.floatPlanIdArg));
    </cfscript>
  </cffunction>

  <cffunction name="recordBillingProductEvent" access="private" returntype="void" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="eventName" type="string" required="true">
    <cfargument name="idempotencyKey" type="string" required="true">
    <cfscript>
      try {
        createObject("component", "fpw.includes.ProductEventService").init("fpw").recordEvent(
          userId = arguments.userId,
          eventName = arguments.eventName,
          entityType = "user",
          entityId = arguments.userId,
          eventSource = "billing_api",
          metadata = {},
          idempotencyKey = arguments.idempotencyKey,
          requestCorrelationId = structKeyExists(request, "fpwRequestId") ? toString(request.fpwRequestId) : ""
        );
      } catch (any eventErr) {
        writeLog(file = "fpw_product_events", type = "error", text = "billing.cfc PRODUCT_EVENT_CALL_FAILED | event=" & arguments.eventName);
      }
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
