<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="240">
<cfheader name="Cache-Control" value="no-store">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfscript>
localRequest=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name)
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host)
  AND val(cgi.server_port) EQ 8500
  AND listFindNoCase("127.0.0.1,::1,0:0:0:0:0:0:0:1,172.19.0.1",cgi.remote_addr)
  AND structKeyExists(application,"env") AND listFindNoCase("dev,development,local",application.env);
if (!localRequest OR cgi.request_method NEQ "GET" OR (url.confirm ?: "") NEQ "RUN_COMPANION_PAIRING_STATUS_TESTS") {
  cfheader(statuscode=404);writeOutput(serializeJSON({SUCCESS=false,ERROR="LOCAL_TEST_CONFIRMATION_REQUIRED"}));abort;
}
if (!directoryExists(expandPath("/testbox/system"))) {
  cfheader(statuscode=503);writeOutput(serializeJSON({SUCCESS=false,ERROR="TESTBOX_NOT_INSTALLED"}));abort;
}
database=queryExecute("SELECT DATABASE() name",{},{datasource="fpw"});
if (database.recordCount NEQ 1 OR ucase(database.name[1]) NEQ "FPW") {
  cfheader(statuscode=409);writeOutput(serializeJSON({SUCCESS=false,ERROR="LOCAL_FPW_DATABASE_REQUIRED"}));abort;
}
function fixtureCounts() {
  return queryExecute("SELECT
    (SELECT COUNT(*) FROM users WHERE email LIKE 'codex-pairing-status-%@example.test') users,
    (SELECT COUNT(*) FROM companion_devices d JOIN users u ON u.userId=d.user_id WHERE u.email LIKE 'codex-pairing-status-%@example.test') devices,
    (SELECT COUNT(*) FROM companion_pairing_codes c JOIN users u ON u.userId=c.user_id WHERE u.email LIKE 'codex-pairing-status-%@example.test') codes",{},{datasource="fpw"});
}
try {
  before=serializeJSON(fixtureCounts());
  raw=new testbox.system.TestBox(bundles="fpw.tests.specs.CompanionPairingStatusSpec").runRaw().getMemento();
  after=serializeJSON(fixtureCounts());
  results={totalSpecs=raw.totalSpecs,totalPass=raw.totalPass,totalFail=raw.totalFail,totalError=raw.totalError,specs=[]};
  for(bundle in raw.bundleStats) for(suite in bundle.suiteStats) for(spec in suite.specStats)
    arrayAppend(results.specs,{name=spec.name,status=spec.status,message=spec.failMessage,detail=spec.failDetail,
      origin=isArray(spec.failOrigin) AND arrayLen(spec.failOrigin) ? spec.failOrigin[1] : {}});
  writeOutput(serializeJSON({SUCCESS=raw.totalSpecs GT 0 AND raw.totalFail EQ 0 AND raw.totalError EQ 0 AND before EQ after,
    RESULTS=results,CLEANUP={SUCCESS=before EQ after}}));
} catch(any failure) {
  cfheader(statuscode=500);
  writeOutput(serializeJSON({SUCCESS=false,ERROR="PAIRING_STATUS_TEST_RUN_FAILED",MESSAGE=failure.message,DETAIL=failure.detail}));
}
</cfscript>
