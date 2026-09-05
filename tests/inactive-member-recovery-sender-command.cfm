<cfsetting enablecfoutputonly="true" showdebugoutput="false" requesttimeout="90">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
localOnly=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host) GT 0
  AND val(cgi.server_port) EQ 8500;
if (!localOnly OR !structKeyExists(url,"confirm") OR url.confirm NEQ "RUN_RECOVERY_SENDER_COMMAND") {
  cfheader(statuscode=404); writeOutput(serializeJSON({ok=false,error="LOCAL_CONFIRMATION_REQUIRED"})); abort;
}
action=structKeyExists(url,"action") ? toString(url.action) : "";
reply={ok=false,error="INVALID_ACTION"};
if (listFind("prepare,prepareRetry",action)) {
  fixture=new fpw.tests.support.RecoveryOrchestrationFixture();
  fixture.createMember("C");
  if (action EQ "prepareRetry") {
    fixture.configure(outcome="FAILED");
    fixture.service().processBatch(batchSize=1,dryRun=false);
  }
  fixture.configure(race="barrier");
  runKey=replace(createUUID(),"-","","all");
  lock name="fpw-recovery-sender-fixtures" type="exclusive" timeout=10 {
    if (!structKeyExists(application,"recoverySenderFixtures")) application.recoverySenderFixtures={};
    application.recoverySenderFixtures[runKey]=fixture;
  }
  reply={ok=true,runKey=runKey};
} else if (listFind("run,inspect,cleanup",action)) {
  runKey=structKeyExists(url,"runKey") ? toString(url.runKey) : "";
  if (!reFind("^[A-Fa-f0-9]{32}$",runKey) OR !structKeyExists(application,"recoverySenderFixtures")
    OR !structKeyExists(application.recoverySenderFixtures,runKey)) {
    reply={ok=false,error="UNKNOWN_FIXTURE"};
  } else {
    fixture=application.recoverySenderFixtures[runKey];
    if (action EQ "run") reply=fixture.service().processBatch(batchSize=1,dryRun=false);
    if (action EQ "inspect") {
      stageState=fixture.state(fixture.getCandidateIds(1)[1],"C");
      reply={ok=true,counts=fixture.counts(),state=stageState.STATUS,attemptCount=stageState.ATTEMPT_COUNT};
    }
    if (action EQ "cleanup") {
      fixture.cleanup();
      reply={ok=true,remaining=fixture.counts()};
      structDelete(application.recoverySenderFixtures,runKey);
    }
  }
} else if (action EQ "runnerChecks") {
  // Private, byte-preserving local fixture only. The production endpoint gets no test override.
  configPath=application.stripeConfigPath;
  original=fileReadBinary(configPath);
  backupPath=configPath & ".recovery-sender-" & replace(createUUID(),"-","","all") & ".bak";
  fileCopy(configPath,backupPath);
  token=replace(createUUID(),"-","","all") & replace(createUUID(),"-","","all");
  outcomes=[];
  try {
    config=deserializeJSON(charsetEncode(original,"utf-8"));
    config.FPW_INACTIVE_RECOVERY_RUNNER_TOKEN=token;
    config.FPW_INACTIVE_RECOVERY_LIVE_ENABLED=false;
    fileWrite(configPath,serializeJSON(config),"utf-8");
    for (test in [
      {name="missing",token="",query="",status=403},
      {name="wrong",token="wrong",query="",status=403},
      {name="authorized_dry_run",token=token,query="?batchSize=1",status=200},
      {name="too_large",token=token,query="?batchSize=101",status=400},
      {name="zero",token=token,query="?batchSize=0",status=400},
      {name="fractional",token=token,query="?batchSize=1.5",status=400},
      {name="invalid_dry_run",token=token,query="?dryRun=yes",status=400},
      {name="target_override",token=token,query="?userId=1",status=400},
      {name="stage_override",token=token,query="?stage=D",status=400},
      {name="recipient_override",token=token,query="?email=x@example.test",status=400},
      {name="force_override",token=token,query="?force=true",status=400},
      {name="live_disabled",token=token,query="?dryRun=false",status=403}
    ]) {
      cfhttp(url="http://localhost:8500/fpw/app/scheduled/run-inactive-member-recovery.cfm" & test.query,method="GET",result="httpResult",timeout=30) {
        if (len(test.token)) cfhttpparam(type="header",name="X-FPW-Recovery-Token",value=test.token);
      }
      body=deserializeJSON(httpResult.fileContent);
      safe= !reFindNoCase('"(user_?id|email|name|token|claim_token|recipient)"\s*:',serializeJSON(body));
      noCache=structKeyExists(httpResult.responseHeader,"Cache-Control") AND findNoCase("no-store",httpResult.responseHeader["Cache-Control"]) GT 0;
      arrayAppend(outcomes,{name=test.name,status=val(httpResult.statusCode),passed=val(httpResult.statusCode) EQ test.status AND safe AND noCache});
      if (test.name EQ "authorized_dry_run") {
        outcomes[arrayLen(outcomes)].passed=outcomes[arrayLen(outcomes)].passed AND body.ok AND body.mode EQ "dry_run" AND body.claimed EQ 0 AND body.sent EQ 0;
      }
    }
  } finally {
    fileWrite(configPath,original);
    restored=compare(hash(fileReadBinary(configPath),"SHA-256"),hash(fileReadBinary(backupPath),"SHA-256")) EQ 0;
    if (restored) fileDelete(backupPath);
  }
  reply={ok=true,checks=outcomes,privateConfigRestored=restored,privateBackupRemoved=!fileExists(backupPath)};
}
writeOutput(serializeJSON(reply));
</cfscript>
