<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">
<cfset localHost=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name)
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host)
  AND val(cgi.server_port) EQ 8500>
<cfif NOT localHost OR url.confirm NEQ "RUN_INACTIVE_RECOVERY_LEDGER_TESTS">
  <cfheader statuscode="404"><cfabort>
</cfif>
<cftry>
  <cfset runner=createObject("component","testbox.system.TestBox").init(
    bundles="fpw.tests.specs.InactiveMemberRecoveryLedgerSpec")>
  <cfset results=runner.runRaw().getMemento()>
  <cfset ok=results.totalSpecs GT 0 AND results.totalFail EQ 0 AND results.totalError EQ 0>
  <cfheader statuscode="#ok ? 200 : 500#">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({SUCCESS=ok,RESULTS=results})#</cfoutput>
  <cfcatch type="any">
    <cfheader statuscode="500"><cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({SUCCESS=false,ERROR="TEST_RUNNER_EXCEPTION",TYPE=cfcatch.type,MESSAGE=cfcatch.message})#</cfoutput>
  </cfcatch>
</cftry>
