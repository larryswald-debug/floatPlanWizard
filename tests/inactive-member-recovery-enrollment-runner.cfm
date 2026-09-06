<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="180">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
localOnly=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host) GT 0 AND val(cgi.server_port) EQ 8500;
if (!localOnly OR !structKeyExists(url,"confirm") OR url.confirm NEQ "RUN_RECOVERY_ENROLLMENT_TESTS") {
  cfheader(statuscode=404); writeOutput(serializeJSON({ok=false,error="LOCAL_CONFIRMATION_REQUIRED"})); abort;
}
try {
  testbox=new testbox.system.TestBox(bundles="fpw.tests.specs.InactiveMemberRecoveryEnrollmentSpec");
  results=testbox.runRaw().getMemento();
  ok=results.totalSpecs GT 0 AND results.totalFail EQ 0 AND results.totalError EQ 0;
  cfheader(statuscode=ok ? 200 : 500);
  writeOutput(serializeJSON({SUCCESS=ok,RESULTS=results}));
} catch (any runnerFailure) {
  cfheader(statuscode=500);
  writeOutput(serializeJSON({SUCCESS=false,ERROR="ENROLLMENT_TEST_RUNNER_FAILED",TYPE=runnerFailure.type,MESSAGE=runnerFailure.message}));
}
</cfscript>
