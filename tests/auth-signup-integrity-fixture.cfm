<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
isLocal=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
  AND reFindNoCase("^(localhost|127[.]0[.]0[.]1|\[::1\])(:8500)?$",cgi.http_host) GT 0 AND val(cgi.server_port) EQ 8500;
if (!isLocal OR cgi.request_method NEQ "POST" OR (url.confirm ?: "") NEQ "RUN_AUTH_SIGNUP_FIXTURES") {
  cfheader(statuscode=404);writeOutput(serializeJSON({SUCCESS=false,ERROR="LOCAL_CONFIRMATION_REQUIRED"}));abort;
}
body=deserializeJSON(toString(getHttpRequestData().content),false);
runId=toString(body.runId ?: "");
action=toString(body.action ?: "");
if (!reFind("^[a-f0-9]{32}$",runId)) {cfheader(statuscode=400);writeOutput(serializeJSON({SUCCESS=false,ERROR="INVALID_RUN"}));abort;}
lock name="fpw-auth-signup-fixtures" type="exclusive" timeout=20 {
  if (!structKeyExists(application,"fpwAuthSignupFixtures")) application.fpwAuthSignupFixtures={};
  if (action EQ "setup") {
    if (structKeyExists(application.fpwAuthSignupFixtures,runId)) throw(message="FIXTURE_ALREADY_EXISTS");
    fixture={email="auth-signup-" & runId & "@test.invalid",clientIp=new fpw.api.v1.AuthRequestGuardService().getClientIp(),
      originalCreditModel=application.premiumSendCreditModelEnabled,toggled=false};
    application.fpwAuthSignupFixtures[runId]=fixture;
    writeOutput(serializeJSON({SUCCESS=true,EMAIL=fixture.email,CREDIT_MODEL=fixture.originalCreditModel,
      SESSION_TYPE=getApplicationMetadata().sessionType ?: "unreported",CLIENT_IP=fixture.clientIp}));
  } else {
    if (!structKeyExists(application.fpwAuthSignupFixtures,runId)) throw(message="FIXTURE_NOT_FOUND");
    fixture=application.fpwAuthSignupFixtures[runId];
    if (action EQ "toggle-credit") {
      if (fixture.toggled) throw(message="CREDIT_MODEL_ALREADY_TOGGLED");
      application.premiumSendCreditModelEnabled=NOT fixture.originalCreditModel;
      fixture.toggled=true;
      writeOutput(serializeJSON({SUCCESS=true,ORIGINAL=fixture.originalCreditModel,CURRENT=application.premiumSendCreditModelEnabled}));
    } else if (action EQ "restore-credit") {
      application.premiumSendCreditModelEnabled=fixture.originalCreditModel;
      fixture.toggled=false;
      writeOutput(serializeJSON({SUCCESS=true,RESTORED=application.premiumSendCreditModelEnabled}));
    } else if (action EQ "state") {
      row=queryExecute("SELECT userId,fName,lName,password FROM users WHERE email=:email",
        {email={value=fixture.email,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
      result={SUCCESS=true,USER_COUNT=row.recordCount,USERID=0,SIGNUP_COUNT=0,CREDIT_COUNT=0,ENROLLMENT_COUNT=0,ENTITLEMENT_COUNT=0,
        FORMAT="",NAMES_EMPTY=true,METADATA={},CREDIT_MODEL=application.premiumSendCreditModelEnabled,COUNTERS={}};
      if (row.recordCount EQ 1) {
        result.USERID=val(row.userId[1]);
        result.FORMAT=new fpw.api.v1.PasswordHashService().detectPasswordFormat(row.password[1]);
        result.NAMES_EMPTY=NOT len(trim(row.fName[1] ?: "")) AND NOT len(trim(row.lName[1] ?: ""));
        args={id={value=result.USERID,cfsqltype="cf_sql_integer"}};
        events=queryExecute("SELECT event_name,metadata_json FROM product_events WHERE user_id=:id",args,{datasource="fpw"});
        for (event in events) {
          if (event.event_name EQ "sign_up") { result.SIGNUP_COUNT++;result.METADATA=deserializeJSON(event.metadata_json); }
          if (event.event_name EQ "inactive_member_recovery_enrolled") result.ENROLLMENT_COUNT++;
        }
        credits=queryExecute("SELECT COUNT(*) AS n FROM premium_send_credits WHERE user_id=:id AND source='complimentary_signup'",args,{datasource="fpw"});
        result.CREDIT_COUNT=val(credits.n[1]);
        entitlements=queryExecute("SELECT COUNT(*) AS n FROM member_entitlements WHERE user_id=:id",args,{datasource="fpw"});
        result.ENTITLEMENT_COUNT=val(entitlements.n[1]);
      }
      for (group in ["authenticate","create_account"]) {
        pair=new fpw.api.v1.AuthRateLimitService().init("fpw").buildBuckets(group,fixture.email,fixture.clientIp);
        bucket=pair[arrayLen(pair)];
        counter=queryExecute("SELECT admitted_count,failure_count,inflight_count FROM auth_rate_counters
          WHERE action_group=:actionGroup AND subject_scope='ip_account' AND subject_hash=UNHEX(:key)",
          {actionGroup={value=group,cfsqltype="cf_sql_varchar"},key={value=bucket.subjectHash,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
        result.COUNTERS[group]={admitted=counter.recordCount ? counter.admitted_count[1] : 0,
          failures=counter.recordCount ? counter.failure_count[1] : 0,inflight=counter.recordCount ? counter.inflight_count[1] : 0};
      }
      writeOutput(serializeJSON(result));
    } else if (action EQ "cleanup") {
      if (fixture.toggled) application.premiumSendCreditModelEnabled=fixture.originalCreditModel;
      ids=[];
      transaction {
        member=queryExecute("SELECT userId FROM users WHERE email=:email FOR UPDATE",
          {email={value=fixture.email,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
        for (row in member) {
          arrayAppend(ids,val(row.userId));
          args={id={value=row.userId,cfsqltype="cf_sql_integer"}};
          for (table in ["inactive_member_recovery_deliveries","product_events","premium_send_credits","member_entitlements"])
            queryExecute("DELETE FROM " & table & " WHERE user_id=:id",args,{datasource="fpw"});
          queryExecute("DELETE FROM users_address WHERE userId=:id",args,{datasource="fpw"});
          queryExecute("DELETE FROM users WHERE userId=:id",args,{datasource="fpw"});
        }
        for (group in ["authenticate","create_account","reset_request","reset_confirm","change_password"]) {
          for (bucket in new fpw.api.v1.AuthRateLimitService().init("fpw").buildBuckets(group,fixture.email,fixture.clientIp,false)) {
            queryExecute("DELETE FROM auth_rate_counters WHERE action_group=:actionGroup AND subject_scope=:scope AND subject_hash=UNHEX(:key)",
              {actionGroup={value=bucket.actionGroup,cfsqltype="cf_sql_varchar"},scope={value=bucket.scope,cfsqltype="cf_sql_varchar"},
                key={value=bucket.subjectHash,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
          }
        }
      }
      structDelete(application.fpwAuthSignupFixtures,runId);
      writeOutput(serializeJSON({SUCCESS=true,CLEANED=true,USER_IDS=ids,CREDIT_MODEL=application.premiumSendCreditModelEnabled}));
    } else {cfheader(statuscode=400);writeOutput(serializeJSON({SUCCESS=false,ERROR="INVALID_ACTION"}));}
  }
}
</cfscript>
