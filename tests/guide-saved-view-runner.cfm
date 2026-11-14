<cfsetting showdebugoutput="false" enablecfoutputonly="true">
<cfcontent type="application/json; charset=utf-8"><cfheader name="Cache-Control" value="no-store">
<cfscript>
request.guideTestConfirmation="RUN_LOCAL_GUIDE_SAVED_VIEW_TESTS";
include "support/guide-test-guard.cfm";
try { writeOutput(serializeJSON(new fpw.tests.support.GuideSavedViewContract().runChecks())); }
catch(any e) { writeOutput(serializeJSON({SUCCESS=false,error={type=e.type,message=e.message,detail=e.detail,context=e.tagContext}})); }
</cfscript>

