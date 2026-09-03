<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="240">
<cfparam name="url.confirm" default="">
<cfset localOnly = listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host) GT 0 AND val(cgi.server_port) EQ 8500>
<cfif NOT localOnly OR url.confirm NEQ "RUN_COMPLETED_CONTACT_ACCESS_TESTS">
  <cfheader statuscode="404"><cfabort>
</cfif>
<cfquery name="qDatabase" datasource="fpw">SELECT DATABASE() AS db</cfquery>
<cfif qDatabase.db[1] NEQ "FPW"><cfheader statuscode="409"><cfabort></cfif>
<cftry>
  <cfset runner = new testbox.system.TestBox(bundles="fpw.tests.specs.CompletedContactAccessSpec")>
  <cfset results = runner.runRaw().getMemento()>
  <cfset ok = results.totalSpecs GT 0 AND results.totalFail EQ 0 AND results.totalError EQ 0>
  <cfheader statuscode="#ok ? 200 : 500#">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({SUCCESS=ok,results=results})#</cfoutput>
  <cfcatch type="any">
    <cfheader statuscode="500"><cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({SUCCESS=false,MESSAGE=cfcatch.message,DETAIL=cfcatch.detail})#</cfoutput>
  </cfcatch>
</cftry>
