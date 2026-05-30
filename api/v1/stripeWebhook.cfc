<cfcomponent output="false">

  <cffunction name="handle" access="remote" returntype="void" output="true">
    <cfsetting enablecfoutputonly="true" showdebugoutput="false">
    <cfcontent type="application/json; charset=utf-8">
    <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

    <cfset var httpData = {}>
    <cfset var rawBody = "">
    <cfset var headers = {}>
    <cfset var signatureHeader = "">
    <cfset var webhookSecret = "">
    <cfset var verifyResult = {}>
    <cfset var response = {}>
    <cfset var event = {}>

    <cftry>
      <cfset httpData = getHttpRequestData()>
      <cfset rawBody = structKeyExists(httpData, "content") ? toString(httpData.content) : "">
      <cfset headers = structKeyExists(httpData, "headers") AND isStruct(httpData.headers) ? httpData.headers : {}>
      <cfset signatureHeader = readHeader(headers, "Stripe-Signature")>
      <cfset webhookSecret = new fpw.api.v1.StripeConfigService().init().getWebhookSecret()>
      <cfset verifyResult = new fpw.api.v1.StripeWebhookSignatureService().init().verify(rawBody, signatureHeader, webhookSecret)>

      <cfif NOT verifyResult.SUCCESS>
        <cfheader statuscode="400">
        <cfset writeStripeWebhookDebugLog("signature", 400, verifyResult, rawBody, signatureHeader, event)>
        <cfoutput>#serializeJSON(verifyResult)#</cfoutput>
        <cfsetting enablecfoutputonly="false">
        <cfreturn>
      </cfif>

      <cftry>
        <cfset event = deserializeJSON(rawBody, false)>
        <cfcatch type="any">
          <cfheader statuscode="400">
          <cfset response = {
            SUCCESS = false,
            success = false,
            ERROR = "STRIPE_WEBHOOK_JSON_INVALID",
            errorCode = "STRIPE_WEBHOOK_JSON_INVALID",
            MESSAGE = "Stripe webhook payload is not valid JSON."
          }>
          <cfset writeStripeWebhookDebugLog("json", 400, response, rawBody, signatureHeader, event, cfcatch.message, cfcatch.detail)>
          <cfoutput>#serializeJSON(response)#</cfoutput>
          <cfsetting enablecfoutputonly="false">
          <cfreturn>
        </cfcatch>
      </cftry>

      <cfif NOT isStruct(event) OR NOT structKeyExists(event, "id") OR NOT len(trim(toString(event.id)))>
        <cfheader statuscode="400">
        <cfset response = {
          SUCCESS = false,
          success = false,
          ERROR = "INVALID_STRIPE_EVENT_ID",
          errorCode = "INVALID_STRIPE_EVENT_ID",
          MESSAGE = "Stripe event id is required."
        }>
        <cfset writeStripeWebhookDebugLog("event_id", 400, response, rawBody, signatureHeader, event)>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfsetting enablecfoutputonly="false">
        <cfreturn>
      </cfif>

      <cfset response = new fpw.api.v1.StripeEntitlementService().init("fpw").processVerifiedEvent(event)>
      <cfif NOT response.SUCCESS>
        <cfheader statuscode="400">
        <cfset writeStripeWebhookDebugLog("entitlement", 400, response, rawBody, signatureHeader, event)>
      </cfif>
      <cfoutput>#serializeJSON(response)#</cfoutput>

      <cfcatch type="any">
        <cfheader statuscode="500">
        <cfset response = {
          SUCCESS = false,
          success = false,
          ERROR = "STRIPE_WEBHOOK_SERVER_ERROR",
          errorCode = "STRIPE_WEBHOOK_SERVER_ERROR",
          MESSAGE = "Stripe webhook processing failed."
        }>
        <cfset writeStripeWebhookDebugLog("server", 500, response, rawBody, signatureHeader, event, cfcatch.message, cfcatch.detail)>
        <cfoutput>#serializeJSON(response)#</cfoutput>
      </cfcatch>
    </cftry>

    <cfsetting enablecfoutputonly="false">
  </cffunction>

  <cffunction name="readHeader" access="private" returntype="string" output="false">
    <cfargument name="headers" type="struct" required="true">
    <cfargument name="headerName" type="string" required="true">
    <cfscript>
      var key = "";
      for (key in arguments.headers) {
        if (compareNoCase(key, arguments.headerName) EQ 0) {
          return trim(toString(arguments.headers[key]));
        }
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="writeStripeWebhookDebugLog" access="private" returntype="void" output="false">
    <cfargument name="stage" type="string" required="true">
    <cfargument name="statusCode" type="numeric" required="true">
    <cfargument name="response" type="struct" required="false" default="#structNew()#">
    <cfargument name="rawBody" type="string" required="false" default="">
    <cfargument name="signatureHeader" type="string" required="false" default="">
    <cfargument name="event" type="struct" required="false" default="#structNew()#">
    <cfargument name="exceptionMessage" type="string" required="false" default="">
    <cfargument name="exceptionDetail" type="string" required="false" default="">
    <cfscript>
      var componentDir = replace(getDirectoryFromPath(getCurrentTemplatePath()), "\", "/", "all");
      var logDirectory = reReplace(componentDir, "/api/v1/?$", "/logs", "one");
      var logFile = logDirectory & "/stripe-webhook-debug.log";
      var logParts = [];
      var logLine = "";
      var responseError = firstNonBlank([
        readStructString(arguments.response, "ERROR"),
        readStructString(arguments.response, "errorCode")
      ]);
      var responseMessage = firstNonBlank([
        readStructString(arguments.response, "MESSAGE"),
        readStructString(arguments.response, "message")
      ]);
      var eventId = readStructString(arguments.event, "id");
      var eventType = readStructString(arguments.event, "type");

      arrayAppend(logParts, "STRIPE_WEBHOOK_DEBUG");
      arrayAppend(logParts, "ts=#dateTimeFormat(now(), 'yyyy-mm-dd HH:nn:ss')#");
      arrayAppend(logParts, "stage=#sanitizeStripeWebhookDebugText(arguments.stage)#");
      arrayAppend(logParts, "status=#int(val(arguments.statusCode))#");
      arrayAppend(logParts, "signatureHeaderPresent=#len(trim(arguments.signatureHeader)) ? 'true' : 'false'#");
      arrayAppend(logParts, "rawBodyLength=#len(arguments.rawBody)#");
      if (len(eventId)) {
        arrayAppend(logParts, "eventId=#sanitizeStripeWebhookDebugText(eventId)#");
      }
      if (len(eventType)) {
        arrayAppend(logParts, "eventType=#sanitizeStripeWebhookDebugText(eventType)#");
      }
      if (len(responseError)) {
        arrayAppend(logParts, "error=#sanitizeStripeWebhookDebugText(responseError)#");
      }
      if (len(responseMessage)) {
        arrayAppend(logParts, "message=#sanitizeStripeWebhookDebugText(responseMessage)#");
      }
      if (len(arguments.exceptionMessage)) {
        arrayAppend(logParts, "exceptionMessage=#sanitizeStripeWebhookDebugText(arguments.exceptionMessage)#");
      }
      if (len(arguments.exceptionDetail)) {
        arrayAppend(logParts, "exceptionDetail=#sanitizeStripeWebhookDebugText(arguments.exceptionDetail)#");
      }
      logLine = arrayToList(logParts, " ");
    </cfscript>
    <cftry>
      <cfif NOT directoryExists(logDirectory)>
        <cfdirectory action="create" directory="#logDirectory#">
      </cfif>
      <cffile action="append" file="#logFile#" output="#logLine#" addnewline="true" charset="utf-8">
      <cfcatch type="any">
        <cflog file="fpw-errors" type="error" text="STRIPE_WEBHOOK_DEBUG_LOG_FAILED message=#toString(cfcatch.message)# detail=#toString(cfcatch.detail)#">
      </cfcatch>
    </cftry>
  </cffunction>

  <cffunction name="readStructString" access="private" returntype="string" output="false">
    <cfargument name="source" type="struct" required="true">
    <cfargument name="key" type="string" required="true">
    <cfscript>
      if (structKeyExists(arguments.source, arguments.key) AND !isNull(arguments.source[arguments.key])) {
        return trim(toString(arguments.source[arguments.key]));
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="firstNonBlank" access="private" returntype="string" output="false">
    <cfargument name="values" type="array" required="true">
    <cfscript>
      var i = 0;
      var value = "";
      for (i = 1; i LTE arrayLen(arguments.values); i++) {
        value = trim(toString(arguments.values[i]));
        if (len(value)) {
          return value;
        }
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="sanitizeStripeWebhookDebugText" access="private" returntype="string" output="false">
    <cfargument name="value" type="string" required="true">
    <cfscript>
      var textValue = replace(replace(trim(arguments.value), chr(13), " ", "all"), chr(10), " ", "all");
      textValue = reReplace(textValue, "sk_live_[A-Za-z0-9]+", "sk_live_[redacted]", "all");
      textValue = reReplace(textValue, "sk_test_[A-Za-z0-9]+", "sk_test_[redacted]", "all");
      textValue = reReplace(textValue, "whsec_[A-Za-z0-9]+", "whsec_[redacted]", "all");
      textValue = reReplace(textValue, "v1=[A-Fa-f0-9]+", "v1=[redacted]", "all");
      return left(textValue, 1000);
    </cfscript>
  </cffunction>

</cfcomponent>
