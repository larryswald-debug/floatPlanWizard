<cfsetting showdebugoutput="false" requesttimeout="180">
<cfset request.guideTestConfirmation="RUN_DISPOSABLE_GUIDE_TESTS">
<cfinclude template="support/guide-test-guard.cfm">
<cfcontent type="application/json; charset=utf-8"><cfheader name="Cache-Control" value="no-store">
<cfscript>
try { result=new fpw.tests.specs.GuideTripIntegrationSpec().runContract(); fileWrite(expandPath("/fpw/.codex-snapshots/bahamas-guide-20261107/backend/integration-result.json"),serializeJSON(result),"utf-8"); writeOutput(serializeJSON(result)); }
catch(any e) { writeOutput(serializeJSON({SUCCESS=false,error={type=e.type,message=e.message,detail=e.detail,tagcontext=e.tagcontext}})); }
</cfscript>




