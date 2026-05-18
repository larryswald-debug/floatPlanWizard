<cfcomponent output="false">

  <cffunction name="handle" access="remote" returntype="void" output="true">
    <cfargument name="action" type="string" required="false" default="status">
    <cfsetting enablecfoutputonly="true" showdebugoutput="false">
    <cfcontent type="application/json; charset=utf-8">
    <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

    <cfset var response = {}>
    <cfset var act = lCase(trim(arguments.action))>

    <cftry>
      <cfif act NEQ "status">
        <cfheader statuscode="400">
        <cfset response = {
          SUCCESS = false,
          success = false,
          ERROR = "INVALID_ACTION",
          errorCode = "INVALID_ACTION",
          MESSAGE = "Stripe config action is not supported."
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfsetting enablecfoutputonly="false">
        <cfreturn>
      </cfif>

      <cfif NOT isLocalQaRequest()>
        <cfheader statuscode="403">
        <cfset response = {
          SUCCESS = false,
          success = false,
          ERROR = "LOCAL_QA_ONLY",
          errorCode = "LOCAL_QA_ONLY",
          MESSAGE = "Stripe config status is available only for local QA requests."
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
        <cfsetting enablecfoutputonly="false">
        <cfreturn>
      </cfif>

      <cfset response = new fpw.api.v1.StripeConfigService().init().getConfigStatus()>
      <cfset response["localQaOnly"] = true>
      <cfoutput>#serializeJSON(response)#</cfoutput>

      <cfcatch type="any">
        <cfheader statuscode="500">
        <cfset response = {
          SUCCESS = false,
          success = false,
          ERROR = "STRIPE_CONFIG_STATUS_FAILED",
          errorCode = "STRIPE_CONFIG_STATUS_FAILED",
          MESSAGE = "Stripe config status could not be checked."
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
      </cfcatch>
    </cftry>

    <cfsetting enablecfoutputonly="false">
  </cffunction>

  <cffunction name="isLocalQaRequest" access="private" returntype="boolean" output="false">
    <cfset var host = "">
    <cfset var serverName = "">
    <cfif structKeyExists(application, "env") AND lCase(toString(application.env)) EQ "dev">
      <cfreturn true>
    </cfif>
    <cfif structKeyExists(cgi, "http_host")>
      <cfset host = lCase(trim(toString(cgi.http_host)))>
    </cfif>
    <cfif structKeyExists(cgi, "server_name")>
      <cfset serverName = lCase(trim(toString(cgi.server_name)))>
    </cfif>
    <cfreturn find("localhost", host) GT 0
      OR left(host, 4) EQ "127."
      OR find("[::1]", host) GT 0
      OR serverName EQ "localhost"
      OR left(serverName, 4) EQ "127."
      OR serverName EQ "::1">
  </cffunction>

</cfcomponent>
