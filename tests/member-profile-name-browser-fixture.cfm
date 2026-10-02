<cfsetting enablecfoutputonly="true" showdebugoutput="false" requesttimeout="120">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
localOnly=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
  AND reFindNoCase("^(localhost|127\\.0\\.0\\.1|\\[::1\\])(:8500)?$",cgi.http_host) GT 0 AND val(cgi.server_port) EQ 8500;
if (!localOnly OR cgi.request_method NEQ "POST" OR (url.confirm ?: "") NEQ "RUN_MEMBER_NAME_BROWSER") {
  cfheader(statuscode=404);writeOutput(serializeJSON({ok=false,error="LOCAL_CONFIRMATION_REQUIRED"}));abort;
}
action=url.action ?: "";
function fixtureFiles(required string prefix,boolean remove=false) {
  var utils=new fpw.api.api_assets.floatPlanUtils();
  var directory=getDirectoryFromPath(utils.getPdfPath("probe.pdf"));
  var files=directoryExists(directory) ? directoryList(directory,false,"query",arguments.prefix & "*.pdf") : queryNew("");
  var count=files.recordCount;
  if (arguments.remove) for(var item in files) fileDelete(directory & item.name);
  return count;
}
try {
  if (action EQ "prepare") {
    runKey=lCase(replace(createUUID(),"-","","all"));token=runKey & lCase(replace(createUUID(),"-","","all"));
    password="MemberName-" & runKey & "!";
    members={};inserted={};
    transaction {
      for(slot in ["regular","basic"]) {
        email="codex-activity-member-name-" & runKey & "-" & slot & "@example.test";
        queryExecute("INSERT INTO users (fName,lName,email,password,mobilePhone,passwordCreated,created)
          VALUES (NULL,NULL,:email,:password,'(727) 555-0123',UTC_TIMESTAMP(),UTC_TIMESTAMP())",
          {email={value=email,cfsqltype="cf_sql_varchar"},password={value=new fpw.api.v1.PasswordHashService().hashPassword(password),cfsqltype="cf_sql_varchar"}},
          {datasource="fpw",result="inserted"});
        members[slot]={userId=val(inserted.generatedKey),email=email,planName="MemberNameTest-" & runKey & "-" & slot};
      }
      credit=new fpw.api.v1.PremiumSendCreditService().init("fpw").grantCredit(
        userId=members.regular.userId,source="complimentary_signup",idempotencyKey="member_name_fixture:" & runKey);
      if (!credit.SUCCESS) throw(message="FIXTURE_CREDIT_FAILED");
    }
    lock name="fpw-member-name-fixtures" type="exclusive" timeout=10 {
      if (!structKeyExists(application,"memberNameFixtures")) application.memberNameFixtures={};
      application.memberNameFixtures[runKey]={tokenHash=hash(token,"SHA-256"),members=members,created=now(),clientIp=new fpw.api.v1.AuthRequestGuardService().getClientIp()};
    }
    writeOutput(serializeJSON({ok=true,runKey=runKey,token=token,password=password,members=members}));abort;
  }
  runKey=url.runKey ?: "";provided=cgi.http_x_fpw_member_name_token ?: "";
  if (!reFind("^[a-f0-9]{32}$",runKey) OR !len(provided)
      OR !structKeyExists(application,"memberNameFixtures") OR !structKeyExists(application.memberNameFixtures,runKey)) {
    cfheader(statuscode=403);writeOutput(serializeJSON({ok=false,error="UNKNOWN_FIXTURE"}));abort;
  }
  fixture=application.memberNameFixtures[runKey];
  if (compare(hash(provided,"SHA-256"),fixture.tokenHash) OR dateDiff("n",fixture.created,now()) GT 120) {
    cfheader(statuscode=403);writeOutput(serializeJSON({ok=false,error="EXPIRED_OR_INVALID_TOKEN"}));abort;
  }
  ids=[fixture.members.regular.userId,fixture.members.basic.userId];
  params={ids={value=arrayToList(ids),cfsqltype="cf_sql_integer",list=true}};
  if (action EQ "clearName") {
    slot=url.slot ?: "";
    if (!listFind("regular,basic",slot)) throw(message="INVALID_MEMBER_SLOT");
    queryExecute("UPDATE users SET fName=NULL,lName=NULL WHERE userId=:id",
      {id={value=fixture.members[slot].userId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    writeOutput(serializeJSON({ok=true}));abort;
  } else if (action EQ "inspect") {
    profiles=[];
    for(row in queryExecute("SELECT userId,fName,lName,mobilePhone FROM users WHERE userId IN (:ids)",params,{datasource="fpw"})) arrayAppend(profiles,row);
    plans=[];
    for(row in queryExecute("SELECT f.floatPlanId,f.userId,f.floatPlanName,f.status,o.name AS operator_name,b.captain_name
       FROM floatplans f LEFT JOIN operators o ON o.opId=f.operatorId
       LEFT JOIN floatplan_basic_details b ON b.floatplan_id=f.floatPlanId WHERE f.userId IN (:ids)",params,{datasource="fpw"})) arrayAppend(plans,row);
    writeOutput(serializeJSON({ok=true,profiles=profiles,plans=plans,pdfCount=fixtureFiles("MemberNameTest-" & runKey & "-")}));abort;
  } else if (action EQ "cleanup") {
    removedPdfs=fixtureFiles("MemberNameTest-" & runKey & "-",true);
    for(slot in ["regular","basic"]) {
      uid=fixture.members[slot].userId;
      queryExecute("DELETE FROM inactive_member_recovery_deliveries WHERE user_id=:uid",{uid={value=uid,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
      new fpw.tests.support.MemberActivityHarness().cleanup(uid);
      for (bucket in new fpw.api.v1.AuthRateLimitService().init("fpw").buildBuckets("authenticate",fixture.members[slot].email,fixture.clientIp,false)) {
        queryExecute("DELETE FROM auth_rate_counters WHERE action_group=:actionGroup AND subject_scope=:scope AND subject_hash=UNHEX(:key)",
          {actionGroup={value=bucket.actionGroup,cfsqltype="cf_sql_varchar"},scope={value=bucket.scope,cfsqltype="cf_sql_varchar"},key={value=bucket.subjectHash,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
      }
    }
    remaining=val(queryExecute("SELECT COUNT(*) AS n FROM users WHERE userId IN (:ids)",params,{datasource="fpw"}).n[1]);
    lock name="fpw-member-name-fixtures" type="exclusive" timeout=10 {structDelete(application.memberNameFixtures,runKey);}
    remainingRecords=0;
    for (table in ["floatplans","vessels","contacts","operators","waypoints"]) remainingRecords += val(queryExecute("SELECT COUNT(*) AS n FROM " & table & " WHERE userId IN (:ids)",params,{datasource="fpw"}).n[1]);
    for (table in ["user_routes","route_instances","product_events","premium_send_receipts","premium_send_credits"]) remainingRecords += val(queryExecute("SELECT COUNT(*) AS n FROM " & table & " WHERE user_id IN (:ids)",params,{datasource="fpw"}).n[1]);
    remainingPdfs=fixtureFiles("MemberNameTest-" & runKey & "-");
    writeOutput(serializeJSON({ok=remaining EQ 0 AND remainingRecords EQ 0 AND remainingPdfs EQ 0,remainingUsers=remaining,remainingOwnedRecords=remainingRecords,remainingPdfs=remainingPdfs,removedPdfs=removedPdfs}));abort;
  }
  throw(message="INVALID_ACTION");
} catch(any failure) {
  cfheader(statuscode=500);writeOutput(serializeJSON({ok=false,message=failure.message,detail=failure.detail}));
}
</cfscript>
