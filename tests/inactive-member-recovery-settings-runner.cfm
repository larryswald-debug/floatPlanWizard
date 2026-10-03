<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="180">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
localOnly=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
 AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host) GT 0 AND val(cgi.server_port) EQ 8500;
if(!localOnly OR (url.confirm ?: "") NEQ "RUN_RECOVERY_SETTINGS_TESTS") {
 cfheader(statuscode=404);writeOutput(serializeJSON({ok=false,error="LOCAL_CONFIRMATION_REQUIRED"}));abort;
}
try {
 db=queryExecute("SELECT DATABASE() name",{}, {datasource="fpw"});
 if(db.name[1] NEQ "fpw") throw(message="UNEXPECTED_DATABASE");
 results=new testbox.system.TestBox(bundles="fpw.tests.specs.InactiveMemberRecoverySettingsSpec").runRaw().getMemento();
 ok=results.totalSpecs GT 0 AND results.totalFail EQ 0 AND results.totalError EQ 0;
 failures=[];
 for(bundle in results.bundleStats) for(suite in bundle.suiteStats) for(spec in suite.specStats)
  if(spec.status NEQ "Passed") arrayAppend(failures,{name=spec.name,status=spec.status,message=spec.failMessage,detail=spec.failDetail});
 cfheader(statuscode=ok ? 200 : 500);writeOutput(serializeJSON({SUCCESS=ok,totalSpecs=results.totalSpecs,totalPass=results.totalPass,totalFail=results.totalFail,totalError=results.totalError,failures=failures}));
} catch(any failure) {
 cfheader(statuscode=500);writeOutput(serializeJSON({SUCCESS=false,ERROR="SETTINGS_TEST_RUNNER_FAILED",TYPE=failure.type,MESSAGE=failure.message,DETAIL=failure.detail}));
}
</cfscript>
