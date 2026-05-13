<cfcomponent output="false">

  <cffunction name="handle" access="remote" returntype="void" output="true">
    <cfsetting enablecfoutputonly="true" showdebugoutput="false">
    <cfcontent type="application/json; charset=utf-8">
    <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

    <cftry>
      <cfset var httpData = getHttpRequestData()>
      <cfset var rawBody = structKeyExists(httpData, "content") ? toString(httpData.content) : "">
      <cfset var headers = structKeyExists(httpData, "headers") AND isStruct(httpData.headers) ? httpData.headers : {}>
      <cfset var signatureHeader = readHeader(headers, "Stripe-Signature")>
      <cfset var webhookSecret = new fpw.api.v1.StripeConfigService().init().getWebhookSecret()>
      <cfset var verifyResult = new fpw.api.v1.StripeWebhookSignatureService().init().verify(rawBody, signatureHeader, webhookSecret)>
      <cfset var response = {}>
      <cfset var event = {}>

      <cfif NOT verifyResult.SUCCESS>
        <cfheader statuscode="400">
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
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfsetting enablecfoutputonly="false">
        <cfreturn>
      </cfif>

      <cfset response = new fpw.api.v1.StripeEntitlementService().init("fpw").processVerifiedEvent(event)>
      <cfif NOT response.SUCCESS>
        <cfheader statuscode="400">
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

</cfcomponent>
