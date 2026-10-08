<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfif (url.confirm ?: "") NEQ "RUN_EMAIL_RELIABILITY_TESTS" OR NOT listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) OR val(cgi.server_port) NEQ 8500><cfheader statuscode="404"><cfabort></cfif>
<cftry>
 <cfset runner=new testbox.system.TestBox(bundles="fpw.tests.specs.EmailReliabilitySpec")>
 <cfset results=runner.runRaw().getMemento()>
 <cfset ok=results.totalSpecs GT 0 AND results.totalFail EQ 0 AND results.totalError EQ 0>
 <cfheader statuscode="#ok ? 200 : 500#"><cfcontent type="application/json; charset=utf-8" reset="true"><cfoutput>#serializeJSON({success=ok,results=results})#</cfoutput>
 <cfcatch type="any"><cfheader statuscode="500"><cfcontent type="application/json; charset=utf-8" reset="true"><cfoutput>#serializeJSON({success=false,message=cfcatch.message,detail=cfcatch.detail})#</cfoutput></cfcatch>
</cftry>
