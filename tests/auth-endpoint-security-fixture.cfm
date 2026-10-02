<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
isLocal=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host) GT 0 AND val(cgi.server_port) EQ 8500;
if (!isLocal OR cgi.request_method NEQ "POST" OR (url.confirm ?: "") NEQ "RUN_AUTH_ENDPOINT_FIXTURES") {
  cfheader(statuscode=404);writeOutput(serializeJSON({SUCCESS=false,ERROR="LOCAL_CONFIRMATION_REQUIRED"}));abort;
}
body=deserializeJSON(toString(getHttpRequestData().content),false);
runId=toString(body.runId ?: "");
action=toString(body.action ?: "");
if (!reFind("^[a-f0-9]{32}$",runId)) {cfheader(statuscode=400);writeOutput(serializeJSON({SUCCESS=false,ERROR="INVALID_RUN"}));abort;}
lock name="fpw-auth-endpoint-fixtures" type="exclusive" timeout=20 {
  if (!structKeyExists(application,"fpwAuthEndpointFixtures")) application.fpwAuthEndpointFixtures={};
  if (action EQ "setup") {
    if (structKeyExists(application.fpwAuthEndpointFixtures,runId)) throw(message="FIXTURE_ALREADY_EXISTS");
    fixture={users={},clientIp=new fpw.api.v1.AuthRequestGuardService().getClientIp()};
    passwords=new fpw.api.v1.PasswordHashService();
    for (role in ["sha","plain","change","throttle"]) {
      email="auth-http-" & runId & "-" & role & "@test.invalid";
      plain=role EQ "plain" ? "Short7!" : "Endpoint Fixture Password 42!";
      stored=role EQ "sha" ? hash(plain,"SHA-256","UTF-8") : (role EQ "plain" ? plain : passwords.hashPassword(plain));
      queryExecute("INSERT INTO users(email,password,passwordCreated,created) VALUES(:email,:password,'2000-01-01 00:00:00',UTC_TIMESTAMP())",
        {email={value=email,cfsqltype="cf_sql_varchar"},password={value=stored,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
      row=queryExecute("SELECT userId FROM users WHERE email=:email",{email={value=email,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
      fixture.users[role]={id=val(row.userId[1]),email=email,password=plain};
    }
    application.fpwAuthEndpointFixtures[runId]=fixture;
    writeOutput(serializeJSON({SUCCESS=true,USERS=fixture.users}));
  } else {
    if (!structKeyExists(application.fpwAuthEndpointFixtures,runId)) throw(message="FIXTURE_NOT_FOUND");
    fixture=application.fpwAuthEndpointFixtures[runId];
    if (action EQ "state") {
      rows={};
      actionGroup=toString(body.actionGroup ?: "authenticate");
      if (!listFind("authenticate,change_password",actionGroup)) throw(message="INVALID_COUNTER_GROUP");
      limiter=new fpw.api.v1.AuthRateLimitService().init("fpw");
      for (role in fixture.users) {
        member=fixture.users[role];
        row=queryExecute("SELECT password,DATE_FORMAT(passwordCreated,'%Y-%m-%d %H:%i:%s') AS password_created FROM users WHERE userId=:id AND email=:email",
          {id={value=member.id,cfsqltype="cf_sql_integer"},email={value=member.email,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
        pair=limiter.buildBuckets(actionGroup,member.email,fixture.clientIp)[3];
        counter=queryExecute("SELECT admitted_count,failure_count,inflight_count FROM auth_rate_counters
          WHERE action_group=:actionGroup AND subject_scope='ip_account' AND subject_hash=UNHEX(:key)",
          {actionGroup={value=actionGroup,cfsqltype="cf_sql_varchar"},key={value=pair.subjectHash,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
        rows[role]={exists=row.recordCount EQ 1,format=row.recordCount ? new fpw.api.v1.PasswordHashService().detectPasswordFormat(row.password[1]) : "",
          passwordCreated=row.recordCount ? row.password_created[1] : "",admitted=counter.recordCount ? counter.admitted_count[1] : 0,
          failures=counter.recordCount ? counter.failure_count[1] : 0,inflight=counter.recordCount ? counter.inflight_count[1] : 0};
      }
      writeOutput(serializeJSON({SUCCESS=true,USERS=rows,
        FORWARDED_IGNORED=compare(new fpw.api.v1.AuthRequestGuardService().getClientIp(),toString(cgi.remote_addr)) EQ 0,
        SESSION_TYPE=getApplicationMetadata().sessionType ?: "unreported"}));
    } else if (action EQ "cleanup") {
      for (role in fixture.users) {
        member=fixture.users[role];
        queryExecute("DELETE FROM product_events WHERE user_id=:id",{id={value=member.id,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
        queryExecute("DELETE FROM users WHERE userId=:id AND email=:email",
          {id={value=member.id,cfsqltype="cf_sql_integer"},email={value=member.email,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
        for (group in ["authenticate","create_account","reset_request","reset_confirm","change_password"]) {
          for (bucket in new fpw.api.v1.AuthRateLimitService().init("fpw").buildBuckets(group,member.email,fixture.clientIp,false)) {
            queryExecute("DELETE FROM auth_rate_counters WHERE action_group=:actionGroup AND subject_scope=:scope AND subject_hash=UNHEX(:key)",
              {actionGroup={value=bucket.actionGroup,cfsqltype="cf_sql_varchar"},scope={value=bucket.scope,cfsqltype="cf_sql_varchar"},
               key={value=bucket.subjectHash,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
          }
        }
      }
      structDelete(application.fpwAuthEndpointFixtures,runId);
      writeOutput(serializeJSON({SUCCESS=true,CLEANED=true}));
    } else {cfheader(statuscode=400);writeOutput(serializeJSON({SUCCESS=false,ERROR="INVALID_ACTION"}));}
  }
}
</cfscript>
