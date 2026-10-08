<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
localRequest=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host) GT 0
  AND val(cgi.server_port) EQ 8500
  AND structKeyExists(application,"env") AND listFindNoCase("dev,development,local",application.env) GT 0;
if (!localRequest OR cgi.request_method NEQ "POST" OR (url.confirm ?: "") NEQ "RUN_EMAIL_AUTH_FIXTURES") {
  cfheader(statuscode=404); writeOutput(serializeJSON({SUCCESS=false})); abort;
}
databaseName=queryExecute("SELECT DATABASE() db",{},{datasource="fpw"}).db[1];
if (compareNoCase(databaseName,"FPW") NEQ 0) { cfheader(statuscode=409); abort; }
body=deserializeJSON(toString(getHttpRequestData().content),false);
runId=toString(body.runId ?: "");
if (!reFind("^[a-f0-9]{32}$",runId)) {cfheader(statuscode=400); abort;}
action=toString(body.action ?: "");
support=new fpw.tests.support.CompletedContactFixture();
lock name="fpw-email-auth-fixtures" type="exclusive" timeout=60 {
  if (!structKeyExists(application,"fpwEmailAuthFixtures")) application.fpwEmailAuthFixtures={};
  if (action EQ "setup") {
    if (structKeyExists(application.fpwEmailAuthFixtures,runId)) throw(message="FIXTURE_ALREADY_EXISTS");
    fixture={members={},clientIp=new fpw.api.v1.AuthRequestGuardService().getClientIp()};
    try {
      for (role in ["active","completed"]) {
        member=support.create();
        fixture.members[role]=member;
        // Current canonical password encoding; this suite does not test password migration.
        queryExecute("UPDATE users SET password=:password,welcomeOnboardingSeenAt=UTC_TIMESTAMP() WHERE userId=:id",
          {password=new fpw.api.v1.PasswordHashService().hashPassword(member.password),id=member.userId},{datasource="fpw"});
        // Completed state is fixture data for navigation authorization, not lifecycle proof.
        if (role EQ "completed") support.completeForContractTest(member);
      }
      application.fpwEmailAuthFixtures[runId]=fixture;
      writeOutput(serializeJSON({SUCCESS=true,MEMBERS=fixture.members}));
    } catch (any setupFailure) {
      for (role in fixture.members) support.cleanup(fixture.members[role]);
      rethrow;
    }
  } else if (action EQ "cleanup" AND structKeyExists(application.fpwEmailAuthFixtures,runId)) {
    fixture=application.fpwEmailAuthFixtures[runId];
    ids=[]; planIds=[]; routeIds=[]; loopIds=[];
    for (role in fixture.members) {
      member=fixture.members[role]; arrayAppend(ids,member.userId);
      arrayAppend(planIds,member.planId); arrayAppend(routeIds,member.routeId); arrayAppend(loopIds,member.loopRouteId);
      queryExecute("DELETE FROM product_events WHERE user_id=:id",{id=member.userId},{datasource="fpw"});
      for (group in ["authenticate","create_account","reset_request","reset_confirm","change_password"]) {
        for (bucket in new fpw.api.v1.AuthRateLimitService().init("fpw").buildBuckets(group,member.email,fixture.clientIp,false)) {
          queryExecute("DELETE FROM auth_rate_counters WHERE action_group=:actionGroup AND subject_scope=:scope AND subject_hash=UNHEX(:key)",
            {actionGroup=bucket.actionGroup,scope=bucket.scope,key=bucket.subjectHash},{datasource="fpw"});
        }
      }
      support.cleanup(member);
    }
    remaining=queryExecute("SELECT COUNT(*) n FROM users WHERE userId IN (:ids)",
      {ids={value=arrayToList(ids),cfsqltype="cf_sql_integer",list=true}},{datasource="fpw"}).n[1];
    remainingState=queryExecute("SELECT (SELECT COUNT(*) FROM floatplans WHERE floatPlanId IN (:plans)) plans,
      (SELECT COUNT(*) FROM route_instances WHERE id IN (:routes)) routes,
      (SELECT COUNT(*) FROM loop_routes WHERE id IN (:loops)) templates,
      (SELECT COUNT(*) FROM product_events WHERE user_id IN (:users)) events,
      (SELECT COUNT(*) FROM premium_send_receipts WHERE user_id IN (:users)) receipts,
      (SELECT COUNT(*) FROM member_entitlements WHERE user_id IN (:users)) entitlements",
      {plans={value=arrayToList(planIds),cfsqltype="cf_sql_integer",list=true},
       routes={value=arrayToList(routeIds),cfsqltype="cf_sql_integer",list=true},
       loops={value=arrayToList(loopIds),cfsqltype="cf_sql_integer",list=true},
       users={value=arrayToList(ids),cfsqltype="cf_sql_integer",list=true}},{datasource="fpw"});
    remainingRows={users=remaining}; clean=remaining EQ 0;
    for (column in listToArray(remainingState.columnList)) {
      remainingRows[lCase(column)]=val(remainingState[column][1]);
      if (remainingState[column][1] NEQ 0) clean=false;
    }
    structDelete(application.fpwEmailAuthFixtures,runId);
    writeOutput(serializeJSON({SUCCESS=clean,CLEANED=clean,REMAINING_USERS=remaining,REMAINING_ROWS=remainingRows}));
  } else {cfheader(statuscode=400);writeOutput(serializeJSON({SUCCESS=false,ERROR="INVALID_FIXTURE_ACTION"}));}
}
</cfscript>
