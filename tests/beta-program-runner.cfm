<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
if (!structKeyExists(application,"env") || !listFindNoCase("dev,development,local",application.env)
 || !listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) || val(cgi.server_port)!=8500
 || !reFindNoCase("^(localhost|127[.]0[.]0[.]1|\\[::1\\])(:8500)?$",cgi.http_host)
 || cgi.request_method!="POST" || (url.confirm ?: "")!="RUN_LOCAL_BETA_PROGRAM_TESTS") {
 cfheader(statuscode=404);writeOutput('{"SUCCESS":false,"ERROR":"LOCAL_TEST_CONFIRMATION_REQUIRED"}');abort;
}
if (!directoryExists(expandPath("/testbox/system"))) {
 cfheader(statuscode=503);writeOutput('{"SUCCESS":false,"ERROR":"TESTBOX_NOT_INSTALLED"}');abort;
}
request.betaProgramTestRun=lCase(replace(createUUID(),"-","","all"));
try {
 databaseName=queryExecute("SELECT DATABASE() name",{}, {datasource="fpw"}).name[1];
 if (compare(databaseName,"FPW")!=0) throw(type="BetaTest.Scope",message="The local FPW database is required.");
 transaction {
  try {
   runner=new testbox.system.TestBox(bundles="fpw.tests.specs.BetaParticipationSpec,fpw.tests.specs.BetaReportSpec,fpw.tests.specs.BetaFeedbackSpec,fpw.tests.specs.BetaFailureSpec");
   results=runner.runRaw().getMemento();
  } finally {transaction action="rollback";}
 }
 remaining=queryExecute("SELECT COUNT(*) n FROM users WHERE email LIKE :marker",
  {marker={value="codex-beta-" & request.betaProgramTestRun & "-%@example.test",cfsqltype="cf_sql_varchar"}},{datasource="fpw"}).n[1];
 ok=results.totalSpecs GT 0 && results.totalFail EQ 0 && results.totalError EQ 0 && remaining EQ 0;
 cfheader(statuscode=ok ? 200 : 500);
 writeOutput(serializeJSON({SUCCESS=ok,fixtureUsersRemaining=remaining,results=results}));
} catch(any failure) {
 cfheader(statuscode=500);
 writeOutput(serializeJSON({SUCCESS=false,ERROR="BETA_TEST_RUNNER_EXCEPTION",TYPE=failure.type,MESSAGE=failure.message}));
} finally {structDelete(request,"betaProgramTestRun");}
</cfscript>
