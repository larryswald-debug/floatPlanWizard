<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="180">
<cfparam name="url.confirm" default="">

<cfset expectedConfirmation = "RUN_INACTIVE_MEMBER_RECOVERY_EMAIL_TEMPLATE_TESTS">
<cfset serverName = structKeyExists(cgi,"server_name") ? lCase(trim(toString(cgi.server_name))) : "">
<cfset httpHost = structKeyExists(cgi,"http_host") ? lCase(trim(toString(cgi.http_host))) : "">
<cfset serverPort = structKeyExists(cgi,"server_port") ? val(cgi.server_port) : 0>
<cfset isLocal = listFindNoCase("localhost,127.0.0.1,::1",serverName) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",httpHost) GT 0
  AND serverPort EQ 8500>

<cfif trim(toString(url.confirm)) NEQ expectedConfirmation OR NOT isLocal>
  <cfheader statuscode="404">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({SUCCESS=false,ERROR="LOCAL_TEST_CONFIRMATION_REQUIRED"})#</cfoutput>
  <cfabort>
</cfif>

<cftry>
  <cfset testbox = new testbox.system.TestBox(bundles="fpw.tests.specs.InactiveMemberRecoveryEmailTemplateSpec")>
  <cfset rawResults = testbox.runRaw()>
  <cfset results = rawResults.getMemento()>
  <cfset ok = val(results.totalSpecs) GT 0 AND val(results.totalFail) EQ 0 AND val(results.totalError) EQ 0>
  <cfheader statuscode="#ok ? 200 : 500#">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({SUCCESS=ok,RESULTS=results})#</cfoutput>
  <cfcatch type="any">
    <cfheader statuscode="500">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({SUCCESS=false,ERROR="RECOVERY_EMAIL_TEMPLATE_TEST_RUNNER_FAILED",TYPE=cfcatch.type,MESSAGE=cfcatch.message})#</cfoutput>
  </cfcatch>
</cftry>
