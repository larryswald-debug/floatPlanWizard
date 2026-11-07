<cfsetting showdebugoutput="false" enablecfoutputonly="true">
<cfcontent type="application/json" reset="true">
<cfscript>
if(!structKeyExists(application,"env") OR !listFindNoCase("dev,development,local",application.env)
 OR !listFindNoCase("localhost,127.0.0.1",cgi.server_name) OR val(cgi.server_port)!=8500
 OR !reFindNoCase("^(localhost|127[.]0[.]0[.]1):8500$",cgi.http_host)
 OR cgi.request_method!='POST' OR (url.confirm ?: '')!='LOCAL_BETA_UI_FIXTURE') {cfheader(statuscode=404);abort;}
mode=form.mode ?: '';
fixtureState={};remaining=0;
if(mode=='setup') {
 if(structKeyExists(session,'betaUiFixture')) throw(message="Clean existing fixture first.");
 fixture={};
 transaction {
  for(role in ['admin','member']) {
   result={};
   queryExecute("INSERT INTO users(fName,lName,email,password,passwordCreated,created) VALUES('Disposable','Beta UI',:email,:password,NOW(),NOW())",
    {email={value='codex-beta-ui-' & createUUID() & '@example.test',cfsqltype='cf_sql_varchar'},password={value=hash(createUUID(),'SHA-256'),cfsqltype='cf_sql_varchar'}},{datasource='fpw',result='result'});
   fixture[role]=val(result.generatedKey);
  }
  queryExecute("INSERT INTO member_entitlements(user_id,entitlement_type,source,status,starts_at_utc) VALUES(:id,'admin','beta_test','active',UTC_TIMESTAMP())",{id={value=fixture.admin,cfsqltype='cf_sql_integer'}},{datasource='fpw'});
 }
 session.betaUiFixture=fixture;
} else if(mode=='cleanup') {
 if(structKeyExists(session,'betaUiFixture')) {
  ids=session.betaUiFixture.admin & ',' & session.betaUiFixture.member;
  params={ids={value=ids,cfsqltype='cf_sql_integer',list=true}};
  feedbackExists=queryExecute("SELECT COUNT(*) n FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='fpw_beta_feedback'",{},{datasource='fpw'}).n[1];
  transaction {
   if(feedbackExists) queryExecute("DELETE FROM fpw_beta_feedback WHERE user_id IN (:ids)",params,{datasource='fpw'});
   queryExecute("DELETE FROM fpw_admin_audit_log WHERE admin_user_id IN (:ids)",params,{datasource='fpw'});
   queryExecute("DELETE FROM fpw_beta_participation WHERE user_id IN (:ids)",params,{datasource='fpw'});
   queryExecute("DELETE FROM member_entitlements WHERE user_id IN (:ids)",params,{datasource='fpw'});
   queryExecute("DELETE FROM users WHERE userId IN (:ids) AND email LIKE 'codex-beta-ui-%@example.test'",params,{datasource='fpw'});
  }
  remaining=val(queryExecute("SELECT COUNT(*) n FROM users WHERE userId IN (:ids)",params,{datasource='fpw'}).n[1]);
  structDelete(session,'betaUiFixture');structDelete(session,'user');
 }
} else if(mode=='state' AND structKeyExists(session,'betaUiFixture')) {
 params={id={value=session.betaUiFixture.member,cfsqltype='cf_sql_integer'}};
 participation=queryExecute("SELECT status,DATE_FORMAT(enrolled_at_utc,'%Y-%m-%d %H:%i:%s.%f') enrolled_utc FROM fpw_beta_participation WHERE user_id=:id",params,{datasource='fpw'});
 fixtureState={participationStatus=participation.recordCount ? participation.status[1] : 'NONE',enrolledUtc=participation.recordCount ? participation.enrolled_utc[1] : '',accessCount=val(queryExecute("SELECT COUNT(*) n FROM member_entitlements WHERE user_id=:id",params,{datasource='fpw'}).n[1])};
} else if(listFind('admin,member',mode) AND structKeyExists(session,'betaUiFixture')) {
 session.user={userId=session.betaUiFixture[mode],fName='Disposable',lName='Beta UI'};
} else {cfheader(statuscode=400);abort;}
writeOutput(serializeJSON({SUCCESS=true,state=fixtureState,remainingUsers=remaining,fixture=structKeyExists(session,'betaUiFixture') ? session.betaUiFixture : {}}));
</cfscript>
