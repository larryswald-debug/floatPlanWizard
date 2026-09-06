<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="60">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
localOnly=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host) GT 0 AND val(cgi.server_port) EQ 8500;
if (!localOnly OR cgi.request_method NEQ "POST" OR !structKeyExists(session,"user")
  OR !structKeyExists(url,"confirm") OR url.confirm NEQ "RUN_RECOVERY_ENROLLMENT_COMMAND") {
  cfheader(statuscode=404); writeOutput(serializeJSON({ok=false,error="LOCAL_AUTH_REQUIRED"})); abort;
}
uid=val(session.user.userId ?: session.user.id ?: 0);
owned=queryExecute("SELECT userId FROM users WHERE userId=:id AND email LIKE 'codex-activity-enrollment-%@example.test'
  AND created>=DATE_SUB(NOW(),INTERVAL 4 HOUR)
  AND EXISTS (SELECT 1 FROM product_events e WHERE e.user_id=users.userId AND e.event_name='sign_up' AND e.event_source='member_signup')",
  {id={value=uid,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
if (owned.recordCount NEQ 1) {cfheader(statuscode=404); writeOutput(serializeJSON({ok=false,error="FIXTURE_REQUIRED"})); abort;}
action=url.action ?: "";
if (action EQ "prepare") {
  token=replace(createUUID(),"-","","all") & replace(createUUID(),"-","","all");
  runKey=replace(createUUID(),"-","","all");
  lock name="fpw-enrollment-test-registry" type="exclusive" timeout=10 {
    if (!structKeyExists(application,"recoveryEnrollmentFixtures")) application.recoveryEnrollmentFixtures={};
    application.recoveryEnrollmentFixtures[runKey]={userId=uid,tokenHash=hash(token,"SHA-256"),created=now(),
      barrier=createObject("java","java.util.concurrent.CyclicBarrier").init(javaCast("int",2))};
  }
  writeOutput(serializeJSON({ok=true,runKey=runKey,token=token})); abort;
}
runKey=url.runKey ?: "";
provided=structKeyExists(cgi,"http_x_fpw_enrollment_test_token") ? toString(cgi.http_x_fpw_enrollment_test_token) : "";
if (!reFind("^[A-Fa-f0-9]{32}$",runKey) OR !structKeyExists(application,"recoveryEnrollmentFixtures")
  OR !structKeyExists(application.recoveryEnrollmentFixtures,runKey)) {
  cfheader(statuscode=403); writeOutput(serializeJSON({ok=false,error="UNAUTHORIZED"})); abort;
}
fixture=application.recoveryEnrollmentFixtures[runKey];
if (fixture.userId NEQ uid OR dateDiff("n",fixture.created,now()) GT 60
  OR !len(provided) OR compare(hash(provided,"SHA-256"),fixture.tokenHash) NEQ 0) {
  cfheader(statuscode=403); writeOutput(serializeJSON({ok=false,error="UNAUTHORIZED"})); abort;
}
enrollment=new fpw.includes.InactiveMemberRecoveryEnrollmentService();
if (action EQ "enrollConcurrent") {
  fixture.barrier.await(javaCast("long",15),createObject("java","java.util.concurrent.TimeUnit").SECONDS);
  writeOutput(serializeJSON(enrollment.ensureEnrolled(uid)));
} else if (action EQ "enroll") {
  writeOutput(serializeJSON(enrollment.ensureEnrolled(uid)));
} else if (action EQ "preview") {
  writeOutput(serializeJSON(enrollment.previewMembers([uid])));
} else if (action EQ "dryRun") {
  sender=new fpw.api.v1.InactiveMemberRecoveryService(
    candidateSource=new fpw.tests.support.RecoveryEnrollmentCandidateSource(uid));
  writeOutput(serializeJSON(sender.processBatch(batchSize=1,dryRun=true)));
} else if (action EQ "state") {
  rows=queryExecute("SELECT (SELECT COUNT(*) FROM product_events WHERE user_id=:id AND event_name='inactive_member_recovery_enrolled') AS enrollments,
    (SELECT COUNT(*) FROM inactive_member_recovery_deliveries WHERE user_id=:id) AS ledger",
    {id={value=uid,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
  clock=queryExecute("SELECT DATE_FORMAT(UTC_TIMESTAMP(),'%Y-%m-%dT%H:%i:%sZ') AS utc",{},{datasource="fpw"});
  evaluated=new fpw.includes.InactiveMemberRecoveryClassifierService().evaluateMember(uid,toString(clock.utc[1]));
  writeOutput(serializeJSON({ok=true,enrollments=val(rows.enrollments[1]),ledger=val(rows.ledger[1]),
    enrollment_utc=enrollment.getEnrollmentUtc(uid),decision=evaluated.DECISION_CODE,stage=evaluated.CURRENT_STAGE}));
} else if (action EQ "cleanup") {
  cleaned=new fpw.tests.support.MemberActivityHarness().cleanup(uid);
  structDelete(session,"user");
  lock name="fpw-enrollment-test-registry" type="exclusive" timeout=10 {
    structDelete(application.recoveryEnrollmentFixtures,runKey);
    if (structIsEmpty(application.recoveryEnrollmentFixtures)) structDelete(application,"recoveryEnrollmentFixtures");
  }
  writeOutput(serializeJSON({ok=cleaned.SUCCESS,remaining_users=cleaned.remaining_users}));
} else {
  cfheader(statuscode=400); writeOutput(serializeJSON({ok=false,error="INVALID_ACTION"}));
}
</cfscript>
