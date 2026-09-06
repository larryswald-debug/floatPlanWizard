<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="90">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
localOnly=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host) GT 0 AND val(cgi.server_port) EQ 8500;
if (!localOnly OR cgi.request_method NEQ "POST" OR !structKeyExists(session,"user")
  OR (url.confirm ?: "") NEQ "RUN_RECOVERY_READINESS_COMMAND") {
  cfheader(statuscode=404);writeOutput(serializeJSON({ok=false,error="LOCAL_AUTH_REQUIRED"}));abort;
}
uid=val(session.user.userId ?: session.user.id ?: 0);
owned=queryExecute("SELECT userId,email FROM users WHERE userId=:id AND email LIKE 'codex-activity-readiness-%@example.test'
  AND created>=DATE_SUB(NOW(),INTERVAL 4 HOUR)", {id={value=uid,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
coverage=new fpw.includes.InactiveMemberRecoveryCoverageService();
if (owned.recordCount NEQ 1 OR !coverage.getCoverageVerification(uid).stage_history) {
  cfheader(statuscode=404);writeOutput(serializeJSON({ok=false,error="CANONICAL_FIXTURE_REQUIRED"}));abort;
}
action=url.action ?: "";
if (action EQ "prepare") {
  token=replace(createUUID(),"-","","all") & replace(createUUID(),"-","","all");runKey=replace(createUUID(),"-","","all");
  lock name="fpw-readiness-test-registry" type="exclusive" timeout=10 {
    if (!structKeyExists(application,"recoveryReadinessFixtures")) application.recoveryReadinessFixtures={};
    application.recoveryReadinessFixtures[runKey]={userId=uid,tokenHash=hash(token,"SHA-256"),created=now()};
  }
  writeOutput(serializeJSON({ok=true,runKey=runKey,token=token}));abort;
}
runKey=url.runKey ?: "";provided=cgi.http_x_fpw_readiness_test_token ?: "";
if (!reFind("^[A-Fa-f0-9]{32}$",runKey) OR !structKeyExists(application,"recoveryReadinessFixtures")
  OR !structKeyExists(application.recoveryReadinessFixtures,runKey)) {
  cfheader(statuscode=403);writeOutput(serializeJSON({ok=false,error="UNAUTHORIZED"}));abort;
}
fixture=application.recoveryReadinessFixtures[runKey];
if (fixture.userId NEQ uid OR dateDiff("n",fixture.created,now()) GT 60 OR !len(provided)
  OR compare(hash(provided,"SHA-256"),fixture.tokenHash)) {
  cfheader(statuscode=403);writeOutput(serializeJSON({ok=false,error="UNAUTHORIZED"}));abort;
}
enrollment=new fpw.includes.InactiveMemberRecoveryEnrollmentService();
try {
  if (action EQ "enroll") {
    result=enrollment.ensureEnrolled(uid);
    if (result.SUCCESS AND len(result.ENROLLMENT_UTC)) fixture.anchor=result.ENROLLMENT_UTC;
    writeOutput(serializeJSON(result));
  } else if (action EQ "state") {
    clock=toString(queryExecute("SELECT DATE_FORMAT(UTC_TIMESTAMP(),'%Y-%m-%dT%H:%i:%sZ') AS utc",{},{datasource="fpw"}).utc[1]);
    evaluated=new fpw.includes.InactiveMemberRecoveryClassifierService().evaluateMember(uid,clock);
    rows=queryExecute("SELECT status,recovery_stage FROM inactive_member_recovery_deliveries WHERE user_id=:id",{id={value=uid,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    writeOutput(serializeJSON({ok=true,coverage=coverage.getCoverageVerification(uid),enrollment=enrollment.getEnrollmentUtc(uid),stage=evaluated.CURRENT_STAGE,
      decision=evaluated.DECISION_CODE,ledger_count=rows.recordCount,ledger_status=rows.recordCount ? rows.status[1] : ""}));
  } else if (listFind("earlyDry,dueDry,dueSend",action)) {
    if (!structKeyExists(fixture,"anchor")) throw(message="ENROLL_FIRST");
    seconds=action EQ "earlyDry" ? 604799 : 604800;
    at=createObject("java","java.time.Instant").parse(fixture.anchor).plusSeconds(javaCast("long",seconds)).toString();
    context=new fpw.tests.support.RecoveryReadinessE2EContext(uid,at);
    settings=new fpw.api.v1.InactiveMemberRecoveryService().getRunnerSettings();
    if (settings.liveEnabled) throw(message="PRODUCTION_LIVE_FLAG_MUST_REMAIN_DISABLED");
    if (action EQ "dueSend") {
      socket=createObject("java","java.net.Socket").init("host.docker.internal",javaCast("int",1025));
      try {
        socket.setSoTimeout(javaCast("int",3000));
        reader=createObject("java","java.io.BufferedReader").init(createObject("java","java.io.InputStreamReader").init(socket.getInputStream()));
        if (!findNoCase("MailHog",reader.readLine())) throw(message="LOCAL_MAILHOG_REQUIRED");
      } finally {socket.close();}
    }
    // Real classifier, real coverage, real ledger, real compliance/templates and multipart transport.
    // Only candidate selection and elapsed-time observation are controlled in this LOCAL fixture endpoint.
    sender=new fpw.api.v1.InactiveMemberRecoveryService(liveEnabled=action EQ "dueSend",candidateSource=context,clock=context);
    writeOutput(serializeJSON(sender.processBatch(batchSize=1,dryRun=action NEQ "dueSend")));
  } else if (action EQ "cleanup") {
    queryExecute("DELETE FROM inactive_member_recovery_deliveries WHERE user_id=:id",{id={value=uid,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    cleaned=new fpw.tests.support.MemberActivityHarness().cleanup(uid);structDelete(session,"user");
    lock name="fpw-readiness-test-registry" type="exclusive" timeout=10 {
      structDelete(application.recoveryReadinessFixtures,runKey);
      if (structIsEmpty(application.recoveryReadinessFixtures)) structDelete(application,"recoveryReadinessFixtures");
    }
    writeOutput(serializeJSON({ok=cleaned.SUCCESS,remaining_users=cleaned.remaining_users}));
  } else {cfheader(statuscode=400);writeOutput(serializeJSON({ok=false,error="INVALID_ACTION"}));}
} catch (any err) {cfheader(statuscode=500);writeOutput(serializeJSON({ok=false,type=err.type,message=err.message}));}
</cfscript>
