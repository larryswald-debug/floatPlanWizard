<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="240">
<cfparam name="url.confirm" default="">
<cfif url.confirm NEQ "RUN_INACTIVE_MEMBER_RECOVERY_SENDER_TESTS"
  OR NOT listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) OR val(cgi.server_port) NEQ 8500
  OR NOT reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host)>
  <cfheader statuscode="404">
  <cfcontent type="application/json" reset="true"><cfoutput>{"ok":false}</cfoutput><cfabort>
</cfif>
<cftry>
  <cfset box=new testbox.system.TestBox(bundles="fpw.tests.specs.InactiveMemberRecoverySenderSpec")>
  <cfset results=box.runRaw().getMemento()>
  <cfset passed=results.totalSpecs GT 0 AND results.totalFail EQ 0 AND results.totalError EQ 0>
  <cfheader statuscode="#passed ? 200 : 500#">
  <cfcontent type="application/json" reset="true">
  <cfoutput>#serializeJSON({SUCCESS=passed,RESULTS=results})#</cfoutput>
  <cfcatch type="any">
    <cfheader statuscode="500"><cfcontent type="application/json" reset="true">
    <cfoutput>#serializeJSON({SUCCESS=false,ERROR="SENDER_TEST_RUNNER_FAILED",TYPE=cfcatch.type,MESSAGE=cfcatch.message})#</cfoutput>
  </cfcatch>
</cftry>
