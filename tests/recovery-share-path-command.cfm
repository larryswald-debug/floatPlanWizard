<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="180">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
localOnly=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host) GT 0 AND val(cgi.server_port) EQ 8500;
if (!localOnly OR cgi.request_method NEQ "POST" OR !structKeyExists(session,"user") OR (url.confirm ?: "") NEQ "RUN_RECOVERY_SHARE_PATHS") {
  cfheader(statuscode=404);writeOutput(serializeJSON({ok=false,error="LOCAL_AUTH_REQUIRED"}));abort;
}
uid=val(session.user.userId ?: session.user.id ?: 0);
owned=queryExecute("SELECT userId FROM users WHERE userId=:id AND email LIKE 'codex-activity-readiness-share-%@example.test'
  AND created>=DATE_SUB(NOW(),INTERVAL 4 HOUR)",{id={value=uid,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
runKey=url.runKey ?: "";provided=cgi.http_x_fpw_readiness_test_token ?: "";
if (owned.recordCount NEQ 1 OR !reFind("^[A-Fa-f0-9]{32}$",runKey) OR !structKeyExists(application,"recoveryReadinessFixtures")
  OR !structKeyExists(application.recoveryReadinessFixtures,runKey)) {
  cfheader(statuscode=403);writeOutput(serializeJSON({ok=false,error="UNAUTHORIZED"}));abort;
}
fixture=application.recoveryReadinessFixtures[runKey];
if (fixture.userId NEQ uid OR dateDiff("n",fixture.created,now()) GT 60 OR !len(provided)
  OR compare(hash(provided,"SHA-256"),fixture.tokenHash)) {
  cfheader(statuscode=403);writeOutput(serializeJSON({ok=false,error="UNAUTHORIZED"}));abort;
}
try {
  if (new fpw.api.v1.InactiveMemberRecoveryService().getRunnerSettings().liveEnabled) throw(message="LIVE_FLAG_MUST_REMAIN_DISABLED");
  harness=new fpw.tests.support.RecoverySharePathHarness();action=url.action ?: "";
  if (action EQ "send") {
    // Actual CF Administrator SMTP host/port must be independently inspected before this fixture run.
    socket=createObject("java","java.net.Socket").init("host.docker.internal",javaCast("int",1025));
    try {socket.setSoTimeout(javaCast("int",3000));reader=createObject("java","java.io.BufferedReader").init(createObject("java","java.io.InputStreamReader").init(socket.getInputStream()));
      if (!findNoCase("MailHog",reader.readLine())) throw(message="LOCAL_MAILHOG_REQUIRED");
    } finally {socket.close();}
    names=queryExecute("SELECT floatPlanName FROM floatplans WHERE userId=:id",{id={value=uid,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    if (names.recordCount NEQ 1 OR !reFind("^SharePath-[A-Za-z0-9-]+$",names.floatPlanName[1])) throw(message="UNIQUE_FIXTURE_PLAN_NAME_REQUIRED");
    fixture.pdfPrefix=toString(names.floatPlanName[1]) & "_";
    try {result=harness.runShare(uid,url.source ?: "",url.mode ?: "");}
    finally {
      if (!structKeyExists(fixture,"pdfFiles")) fixture.pdfFiles=[];
      if (structKeyExists(request,"recoveryShareProbe")) for(path in request.recoveryShareProbe.files)arrayAppend(fixture.pdfFiles,path);
    }
  } else if (action EQ "state") result=harness.readState(uid);
  else if (action EQ "due") result=harness.dueState(uid);
  else if (action EQ "purge") result=harness.purgePlanningForRetentionTest(uid);
  else if (action EQ "cleanupFiles") {
    removed=0;
    if (structKeyExists(fixture,"pdfFiles")) {
      utils=new fpw.api.api_assets.floatPlanUtils();dir=getDirectoryFromPath(utils.getPdfPath("probe.pdf"));
      for(path in fixture.pdfFiles) {
        if (getDirectoryFromPath(path) NEQ dir OR left(getFileFromPath(path),len(fixture.pdfPrefix)) NEQ fixture.pdfPrefix) throw(message="PDF_OWNER_SCOPE_MISMATCH");
        if (fileExists(path)) {fileDelete(path);removed++;}
      }
      fixture.pdfFiles=[];
    }
    // Only this disposable account's delivery ledger; canonical account cleanup handles other dependents.
    queryExecute("DELETE FROM inactive_member_recovery_deliveries WHERE user_id=:id",{id={value=uid,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    result={ok=true,removedFiles=removed};
  } else throw(message="INVALID_ACTION");
  writeOutput(serializeJSON(result));
} catch(any err){cfheader(statuscode=500);writeOutput(serializeJSON({ok=false,type=err.type,message=err.message,detail=err.detail}));}
</cfscript>
