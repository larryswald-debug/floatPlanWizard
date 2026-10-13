<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfheader name="Cache-Control" value="no-store">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfscript>
localRequest=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name)
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host)
  AND val(cgi.server_port) EQ 8500
  AND listFindNoCase("127.0.0.1,::1,0:0:0:0:0:0:0:1,172.19.0.1",cgi.remote_addr)
  AND structKeyExists(application,"env") AND listFindNoCase("dev,development,local",application.env);
if (!localRequest OR cgi.request_method NEQ "POST" OR (url.confirm ?: "") NEQ "RUN_COMPANION_PAIRING_FIXTURE") {
  cfheader(statuscode=404);writeOutput(serializeJSON({SUCCESS=false,ERROR="LOCAL_TEST_CONFIRMATION_REQUIRED"}));abort;
}
database=queryExecute("SELECT DATABASE() name",{},{datasource="fpw"});
if (database.recordCount NEQ 1 OR ucase(database.name[1]) NEQ "FPW") {
  cfheader(statuscode=409);writeOutput(serializeJSON({SUCCESS=false,ERROR="LOCAL_FPW_DATABASE_REQUIRED"}));abort;
}
function sql(required string statement,struct params={}) {
  return queryExecute(arguments.statement,arguments.params,{datasource="fpw"});
}
function num(required any value) { return {value=val(arguments.value),cfsqltype="cf_sql_bigint"}; }
function txt(required any value) { return {value=toString(arguments.value),cfsqltype="cf_sql_varchar"}; }
try {
  raw=toString(getHttpRequestData().content);
  if (!isJSON(raw)) throw(message="JSON_OBJECT_REQUIRED");
  body=deserializeJSON(raw);
  if (!isStruct(body)) throw(message="JSON_OBJECT_REQUIRED");
  action=toString(body.action ?: "");
  lock name="fpw-companion-pairing-browser-fixtures" type="exclusive" timeout=30 {
    if (!structKeyExists(application,"companionPairingBrowserFixtures")) application.companionPairingBrowserFixtures={};
    service=new fpw.api.v1.CompanionAuthService().init("fpw");
    if (action EQ "prepare") {
      runId=lcase(replace(createObject("java","java.util.UUID").randomUUID().toString(),"-","","all"));
      email="codex-pairing-browser-" & runId & "@example.test";
      fixture={email=email,userId=0,created=now()};
      transaction {
        sql("INSERT INTO users(fName,lName,email,password,passwordCreated,created) VALUES('Pairing','Disposable',:email,:password,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
          {email=txt(email),password=txt(new fpw.api.v1.PasswordHashService().hashPassword(runId & "!Disposable"))});
        fixture.userId=val(sql("SELECT userId FROM users WHERE email=:email",{email=txt(email)}).userId[1]);
        code=service.createPairingCode(fixture.userId);
        if (!code.SUCCESS) throw(message="PAIRING_CODE_CREATE_FAILED");
      }
      application.companionPairingBrowserFixtures[runId]=fixture;
      writeOutput(serializeJSON({SUCCESS=true,runId=runId,userId=fixture.userId,pairingCode=code.PAIRING_CODE}));
    } else {
      runId=toString(body.runId ?: "");
      if (!reFind("^[a-f0-9]{32}$",runId) OR !structKeyExists(application.companionPairingBrowserFixtures,runId)) throw(message="FIXTURE_NOT_FOUND");
      fixture=application.companionPairingBrowserFixtures[runId];
      params={u=num(fixture.userId),email=txt(fixture.email)};
      if (sql("SELECT userId FROM users WHERE userId=:u AND email=:email",params).recordCount NEQ 1) throw(message="FIXTURE_IDENTITY_MISMATCH");
      if (action NEQ "cleanup" AND dateDiff("n",fixture.created,now()) GT 120) throw(message="FIXTURE_EXPIRED");
      if (action EQ "cleanup") {
        transaction {
          sql("DELETE FROM companion_pairing_codes WHERE user_id=:u",params);
          sql("DELETE FROM companion_devices WHERE user_id=:u",params);
          sql("DELETE FROM users WHERE userId=:u AND email=:email",params);
        }
        remaining=sql("SELECT
          (SELECT COUNT(*) FROM users WHERE userId=:u) users,
          (SELECT COUNT(*) FROM companion_devices WHERE user_id=:u) devices,
          (SELECT COUNT(*) FROM companion_pairing_codes WHERE user_id=:u) codes",params);
        cleaned=val(remaining.users[1])+val(remaining.devices[1])+val(remaining.codes[1]) EQ 0;
        if (cleaned) structDelete(application.companionPairingBrowserFixtures,runId);
        writeOutput(serializeJSON({SUCCESS=cleaned,CLEANED=cleaned,remainingUsers=remaining.users[1],remainingDevices=remaining.devices[1],remainingCodes=remaining.codes[1]}));
      } else if (action EQ "state") {
        response=service.listDevices(fixture.userId);
        for (device in response.DEVICES) structDelete(device,"tokenPrefix");
        writeOutput(serializeJSON(response));
      } else if (action EQ "expire" OR action EQ "revoke") {
        devices=sql("SELECT id FROM companion_devices WHERE user_id=:u",params);
        if (devices.recordCount NEQ 1) throw(message="EXACTLY_ONE_PAIRED_DEVICE_REQUIRED");
        if (action EQ "revoke") response=service.revokeDevice(fixture.userId,val(devices.id[1]),"disposable pairing browser test");
        else {
          sql("UPDATE companion_devices SET expires_at_utc=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 SECOND) WHERE id=:id AND user_id=:u",
            {id=num(devices.id[1]),u=num(fixture.userId)});
          response={SUCCESS=true};
        }
        writeOutput(serializeJSON(response));
      } else throw(message="INVALID_ACTION");
    }
  }
} catch(any failure) {
  cfheader(statuscode=400);
  writeOutput(serializeJSON({SUCCESS=false,ERROR="PAIRING_FIXTURE_FAILURE",MESSAGE=failure.message}));
}
</cfscript>
