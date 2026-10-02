<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">
<cfset serverName = structKeyExists(cgi,"server_name") ? lCase(trim(toString(cgi.server_name))) : "">
<cfset httpHost = structKeyExists(cgi,"http_host") ? lCase(trim(toString(cgi.http_host))) : "">
<cfset serverPort = structKeyExists(cgi,"server_port") ? val(cgi.server_port) : 0>
<cfset isLocal = listFindNoCase("localhost,127.0.0.1,::1",serverName) GT 0
  AND reFindNoCase("^(localhost|127\\.0\\.0\\.1|\\[::1\\])(:8500)?$",httpHost) GT 0 AND serverPort EQ 8500>
<cfif trim(toString(url.confirm)) NEQ "RUN_AUTH_SECURITY_SERVICE_TESTS" OR NOT isLocal>
  <cfheader statuscode="404"><cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({SUCCESS=false,ERROR="LOCAL_TEST_CONFIRMATION_REQUIRED"})#</cfoutput><cfabort>
</cfif>
<cftry>
  <!--- Compile the gated DB suite without executing its fixtures or tests. --->
  <cfset integrationMetadata = getComponentMetadata("fpw.tests.specs.AuthRateLimitIntegrationSpec")>
  <cfset passwordIntegrationMetadata = getComponentMetadata("fpw.tests.specs.AuthPasswordIntegrationSpec")>
  <cfloop list="auth,join,password_reset" index="authComponent">
    <cfset endpointMetadata = getComponentMetadata("fpw.api.v1." & authComponent)>
  </cfloop>
  <cfset testbox = new testbox.system.TestBox(bundles="fpw.tests.specs.AuthSecurityServiceSpec")>
  <cfset results = testbox.runRaw().getMemento()>
  <cfset ok = val(results.totalSpecs) GT 0 AND val(results.totalFail) EQ 0 AND val(results.totalError) EQ 0>
  <cfheader statuscode="#ok ? 200 : 500#"><cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({SUCCESS=ok,RESULTS=results})#</cfoutput>
  <cfcatch type="any">
    <cfheader statuscode="500"><cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({SUCCESS=false,ERROR="AUTH_SECURITY_TEST_RUNNER_FAILED",TYPE=cfcatch.type,MESSAGE=cfcatch.message,FILE=cfcatch.tagContext[1].template,LINE=cfcatch.tagContext[1].line})#</cfoutput>
  </cfcatch>
</cftry>
