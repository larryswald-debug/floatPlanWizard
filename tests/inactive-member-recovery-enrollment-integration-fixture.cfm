<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
// Disposable local evidence only; no production setting or recovery transport is invoked.
localOnly=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host) GT 0 AND val(cgi.server_port) EQ 8500;
if (!localOnly OR (url.confirm ?: "") NEQ "RUN_RECOVERY_ENROLLMENT_INTEGRATION") {
  cfheader(statuscode=404);writeOutput(serializeJSON({ok=false,error="LOCAL_CONFIRMATION_REQUIRED"}));abort;
}
action=url.action ?: "";
try {
  if (action EQ "prepare") {
    runKey=lCase(replace(createUUID(),"-","","all"));
    fixture=new fpw.tests.support.RecoveryEnrollmentIntegrationFixture();
    password="Enrollment-" & runKey;
    try {members=fixture.prepare(password);}
    catch(any failedPreparation) {fixture.cleanup();rethrow;}
    lock name="fpw-recovery-enrollment-integration-fixtures" type="exclusive" timeout=10 {
      if (!structKeyExists(application,"recoveryEnrollmentIntegrationFixtures")) application.recoveryEnrollmentIntegrationFixtures={};
      application.recoveryEnrollmentIntegrationFixtures[runKey]={fixture=fixture,members=members,expiresAt=dateAdd("n",45,now()),
        signupEmail="codex-activity-enrollment-auto-" & runKey & "@example.test"};
    }
    reply={ok=true,runKey=runKey,password=password,members=members,signupEmail="codex-activity-enrollment-auto-" & runKey & "@example.test"};
  } else {
    runKey=url.runKey ?: "";
    if (!reFind("^[a-f0-9]{32}$",runKey) OR reFind("[^a-f0-9]",runKey)) throw(message="UNKNOWN_FIXTURE");
    lock name="fpw-recovery-enrollment-integration-fixtures" type="readonly" timeout=10 {
      if (!structKeyExists(application,"recoveryEnrollmentIntegrationFixtures") OR !structKeyExists(application.recoveryEnrollmentIntegrationFixtures,runKey)) throw(message="UNKNOWN_FIXTURE");
      run=application.recoveryEnrollmentIntegrationFixtures[runKey];
    }
    if (action NEQ "cleanup" AND dateCompare(now(),run.expiresAt) GT 0) throw(message="EXPIRED_FIXTURE");
    if (action EQ "inspect") {
      reply=run.fixture.inspect();reply.ok=true;
    } else if (action EQ "signupState") {
      row=queryExecute("SELECT userId FROM users WHERE email=:email",{email={value=run.signupEmail,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
      id=row.recordCount EQ 1 ? val(row.userId[1]) : 0;
      counts=queryExecute("SELECT COUNT(*) AS enrollments,MIN(DATE_FORMAT(occurred_at_utc,'%Y-%m-%dT%H:%i:%sZ')) AS atUtc FROM product_events WHERE user_id=:id AND event_name='inactive_member_recovery_enrolled'",{id={value=id,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
      ledger=queryExecute("SELECT COUNT(*) AS n FROM inactive_member_recovery_deliveries WHERE user_id=:id",{id={value=id,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
      reply={ok=true,users=row.recordCount,enrollments=val(counts.enrollments[1]),enrollmentUtc=toString(counts.atUtc[1]),ledger=val(ledger.n[1]),
        coverage=new fpw.includes.InactiveMemberRecoveryCoverageService().getCoverageVerification(id)};
    } else if (action EQ "concurrent") {
      run.fixture.awaitBoth();
      reply=new fpw.includes.InactiveMemberRecoveryEnrollmentService().ensureEnrolled(run.members.concurrent.userId);
    } else if (action EQ "optOutCandidate") {
      run.fixture.optOut(run.members.race.userId);reply={ok=true};
    } else if (listFind("corruptEnrollmentEvidence,diagnosticCounts",action)) {
      uid=structKeyExists(session,"user") ? val(session.user.userId ?: session.user.id ?: 0) : 0;
      if (uid NEQ run.members.admin.userId) throw(message="FIXTURE_ADMIN_REQUIRED");
      id=run.members.covered.userId;
      if (!arrayFind(run.fixture.getCandidateIds(100),id)) throw(message="FIXTURE_MEMBER_REQUIRED");
      if (action EQ "corruptEnrollmentEvidence") {
        if (run.fixture.enrollmentCount(id) NEQ 1) throw(message="FIXTURE_ENROLLMENT_REQUIRED");
        // Corrupt only this run-owned enrollment after the successful cohort checks; cleanup removes it.
        queryExecute("UPDATE product_events SET metadata_json=JSON_OBJECT('fixture_invalid',true)
          WHERE user_id=:id AND event_name='inactive_member_recovery_enrolled'
            AND idempotency_key=:eventKey",
          {id={value=id,cfsqltype="cf_sql_integer"},
           eventKey={value="inactive_member_recovery_enrolled:" & id,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
      }
      reply={ok=true,counts=run.fixture.counts()};
    } else if (action EQ "expireReview") {
      uid=structKeyExists(session,"user") ? val(session.user.userId ?: session.user.id ?: 0) : 0;
      if (uid NEQ run.members.admin.userId) throw(message="FIXTURE_ADMIN_REQUIRED");
      // Exact session snapshot expiry field is supplied by the admin service contract.
      if (!structKeyExists(session,"fpwRecoveryEnrollmentReview")) throw(message="REVIEW_REQUIRED");
      session.fpwRecoveryEnrollmentReview.expiresAt=dateAdd("n",-1,now());
      reply={ok=true};
    } else if (action EQ "cleanup") {
      signup=queryExecute("SELECT userId FROM users WHERE email=:email",{email={value=run.signupEmail,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
      if (signup.recordCount EQ 1) new fpw.tests.support.MemberActivityHarness().cleanup(val(signup.userId[1]));
      run.fixture.cleanup();
      reply={ok=true,remaining=run.fixture.counts()};
      lock name="fpw-recovery-enrollment-integration-fixtures" type="exclusive" timeout=10 {
        structDelete(application.recoveryEnrollmentIntegrationFixtures,runKey);
      }
    } else throw(message="INVALID_ACTION");
  }
  writeOutput(serializeJSON(reply));
} catch (any failure) {
  cfheader(statuscode=500);writeOutput(serializeJSON({ok=false,error=failure.message,detail=failure.detail}));
}
</cfscript>
