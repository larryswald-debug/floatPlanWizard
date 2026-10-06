<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
if (cgi.server_name NEQ "localhost" OR cgi.http_host NEQ "localhost:8500" OR val(cgi.server_port) NEQ 8500
  OR cgi.request_method NEQ "POST" OR (url.confirm ?: "") NEQ "RUN_OPTIONAL_EMAIL_BROWSER_TESTS") {
  cfheader(statuscode=404); writeOutput(serializeJSON({success=false})); abort;
}
body=deserializeJSON(toString(getHttpRequestData().content),false);
action=body.action ?: "";
if (!structKeyExists(application,"optionalEmailBrowserFixtures")) application.optionalEmailBrowserFixtures={};
try {
  if(action EQ "prepare") {
    runKey=lCase(replace(createUUID(),"-","","all"));
    token=runKey & lCase(replace(createUUID(),"-","","all"));
    fixture=new fpw.tests.support.RecoveryOrchestrationFixture();
    state={fixture=fixture,tokenHash=hash(token,"SHA-256"),created=now(),clientIp=new fpw.api.v1.AuthRequestGuardService().getClientIp()};
    application.optionalEmailBrowserFixtures[runKey]=state;
    state.member=fixture.createMember("A");
    password="Optional-" & lCase(replace(createUUID(),"-","","all")) & "!";
    queryExecute("UPDATE users SET password=:password,welcomeOnboardingSeenAt=UTC_TIMESTAMP() WHERE userId=:id",
      {password={value=new fpw.api.v1.PasswordHashService().hashPassword(password),cfsqltype="cf_sql_varchar"},
       id={value=state.member.userId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    fixture.setTiming(24,24);
    fixture.setNow("2026-10-20T00:00:00Z");
    emailService=new fpw.api.v1.email();
    eligibility=emailService.checkNonEssentialEmailEligibility(state.member.email,state.member.userId);
    if(!eligibility.eligible) throw(message="FIXTURE_NOT_ELIGIBLE");
    rendered=emailService.buildInactiveMemberRecoveryEmail(stage="A",eligibility=eligibility,firstName="Disposable");
    if(!rendered.success OR !find(eligibility.unsubscribeUrl,rendered.textBody)) throw(message="FIXTURE_RENDER_FAILED");
    writeOutput(serializeJSON({success=true,runKey=runKey,token=token,email=state.member.email,password=password,unsubscribeUrl=eligibility.unsubscribeUrl}));
    abort;
  }
  runKey=body.runKey ?: "";
  token=cgi.http_x_fpw_optional_test_token ?: "";
  if(!reFind("^[a-f0-9]{32}$",runKey) OR !structKeyExists(application.optionalEmailBrowserFixtures,runKey)) {
    cfheader(statuscode=403);writeOutput(serializeJSON({success=false,error="FIXTURE_REQUIRED"}));abort;
  }
  state=application.optionalEmailBrowserFixtures[runKey];
  if(compare(hash(token,"SHA-256"),state.tokenHash) OR dateDiff("n",state.created,now()) GT 120) {
    cfheader(statuscode=403);writeOutput(serializeJSON({success=false,error="FIXTURE_TOKEN_INVALID"}));abort;
  }
  params={id={value=state.member.userId,cfsqltype="cf_sql_integer"},
    email={value=state.member.email,cfsqltype="cf_sql_varchar"}};
  preferenceService=new fpw.api.v1.EmailOptOutService();
  if(action EQ "state") {
    rows=queryExecute("SELECT COUNT(*) n,MIN(source) source,MIN(created_at IS NOT NULL) has_created,MIN(updated_at IS NOT NULL) has_updated
      FROM email_optout WHERE email=:email AND opt_out_type='non_essential'",params,{datasource="fpw"});
    writeOutput(serializeJSON({success=true,rows=val(rows.n[1]),source=rows.n[1] ? rows.source[1] : "",
      hasCreated=rows.n[1] ? val(rows.has_created[1]) : 0,hasUpdated=rows.n[1] ? val(rows.has_updated[1]) : 0,
      preference=preferenceService.getMemberOptionalEmailPreference(state.member.userId),
      eligibility=new fpw.api.v1.email().checkNonEssentialEmailEligibility(state.member.email,state.member.userId).code,
      attempts=state.fixture.attemptCount()}));
  } else if(action EQ "recovery") {
    result=state.fixture.service().processBatch(1,false);
    writeOutput(serializeJSON({success=true,result=result,attempts=state.fixture.attemptCount()}));
  } else if(action EQ "cleanup") {
    state.fixture.cleanup();
    for(bucket in new fpw.api.v1.AuthRateLimitService().init("fpw").buildBuckets("authenticate",state.member.email,state.clientIp,false)) {
      // Only account-specific counters belong to this fixture; shared IP counters stay intact.
      if(bucket.scope NEQ "ip") queryExecute("DELETE FROM auth_rate_counters WHERE action_group=:groupName AND subject_scope=:scope AND subject_hash=UNHEX(:key)",
        {groupName={value=bucket.actionGroup,cfsqltype="cf_sql_varchar"},scope={value=bucket.scope,cfsqltype="cf_sql_varchar"},
         key={value=bucket.subjectHash,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
    }
    remaining=state.fixture.counts();
    optouts=val(queryExecute("SELECT COUNT(*) n FROM email_optout WHERE user_id=:id",params,{datasource="fpw"}).n[1]);
    structDelete(application.optionalEmailBrowserFixtures,runKey);
    writeOutput(serializeJSON({success=remaining.users EQ 0 AND remaining.events EQ 0 AND remaining.ledger EQ 0 AND optouts EQ 0,remaining=remaining,optouts=optouts}));
  } else {
    cfheader(statuscode=400);writeOutput(serializeJSON({success=false,error="UNKNOWN_ACTION"}));
  }
} catch(any failure) {
  if(action EQ "prepare" AND isDefined("fixture")) {
    fixture.cleanup();
    if(isDefined("runKey")) structDelete(application.optionalEmailBrowserFixtures,runKey);
  }
  cfheader(statuscode=500);writeOutput(serializeJSON({success=false,error=failure.type,message=failure.message}));
}
</cfscript>
