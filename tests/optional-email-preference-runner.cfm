<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">
<cfif cgi.server_name NEQ "localhost" OR cgi.http_host NEQ "localhost:8500" OR val(cgi.server_port) NEQ 8500 OR url.confirm NEQ "RUN_OPTIONAL_EMAIL_PREFERENCE_TESTS">
  <cfheader statuscode="404"><cfabort>
</cfif>
<cftry>
  <cfset runner=new testbox.system.TestBox(bundles="fpw.tests.specs.OptionalEmailPreferenceSpec")>
  <cfset results=runner.runRaw().getMemento()>
  <cfset ok=results.totalSpecs GT 0 AND results.totalFail EQ 0 AND results.totalError EQ 0>
  <cfheader statuscode="#ok ? 200 : 500#">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({SUCCESS=ok,RESULTS=results})#</cfoutput>
  <cfcatch type="any">
    <cfheader statuscode="500"><cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({SUCCESS=false,ERROR=cfcatch.type,MESSAGE=cfcatch.message})#</cfoutput>
  </cfcatch>
</cftry>
