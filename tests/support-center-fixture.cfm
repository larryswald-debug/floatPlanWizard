<!--- Local-only disposable rate counters and fault probes for the shared support form. --->
<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="60">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
isLocal=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
  AND reFindNoCase("^(localhost|127[.]0[.]0[.]1|\[::1\])(:8500)?$",cgi.http_host) GT 0 AND val(cgi.server_port) EQ 8500;
if (!isLocal OR cgi.request_method NEQ "POST" OR (url.confirm ?: "") NEQ "RUN_SUPPORT_FIXTURES") {
  cfheader(statuscode=404);writeOutput(serializeJSON({SUCCESS=false,ERROR="LOCAL_CONFIRMATION_REQUIRED"}));abort;
}
body=deserializeJSON(toString(getHttpRequestData().content),false);
runId=toString(body.runId ?: "");
action=toString(body.action ?: "");
if (!reFind("^[a-f0-9]{32}$",runId)) {cfheader(statuscode=400);writeOutput(serializeJSON({SUCCESS=false,ERROR="INVALID_RUN"}));abort;}
rate=new fpw.api.v1.AuthRateLimitService().init("fpw");
ip=new fpw.api.v1.AuthRequestGuardService().getClientIp();
function bucketParams(bucket) {
  return {scope={value=bucket.scope,cfsqltype="cf_sql_varchar"},key={value=bucket.subjectHash,cfsqltype="cf_sql_varchar"}};
}
lock name="fpw-support-fixtures" type="exclusive" timeout=20 {
  if (!structKeyExists(application,"fpwSupportFixtures")) application.fpwSupportFixtures={};
  if (action EQ "setup") {
    if (!structIsEmpty(application.fpwSupportFixtures)) throw(message="SUPPORT_FIXTURE_ALREADY_ACTIVE");
    emails=[];buckets=[];
    for (i=0;i LTE 9;i++) {
      email="support-" & runId & "-" & i & "@test.invalid";
      if (i EQ 9) email=runId & repeatString("x",32) & "@" & repeatString("a",63) & "." & repeatString("b",63) & "." & repeatString("c",53) & ".invalid";
      arrayAppend(emails,email);
      for (bucket in rate.buildBuckets("support_submit",email,ip,i EQ 0)) {
        existing=queryExecute("SELECT COUNT(*) AS n FROM auth_rate_counters WHERE action_group='support_submit' AND subject_scope=:scope AND subject_hash=UNHEX(:key)",bucketParams(bucket),{datasource="fpw"});
        if (existing.n[1] NEQ 0) throw(message="EXISTING_SUPPORT_COUNTER_MUST_NOT_BE_OVERWRITTEN");
        arrayAppend(buckets,bucket);
      }
    }
    application.fpwSupportFixtures[runId]={emails=emails,buckets=buckets};
    writeOutput(serializeJSON({SUCCESS=true,EMAILS=emails}));
  } else {
    if (!structKeyExists(application.fpwSupportFixtures,runId)) throw(message="FIXTURE_NOT_FOUND");
    fixture=application.fpwSupportFixtures[runId];
    if (action EQ "cleanup") {
      for (bucket in fixture.buckets) queryExecute("DELETE FROM auth_rate_counters WHERE action_group='support_submit' AND subject_scope=:scope AND subject_hash=UNHEX(:key)",bucketParams(bucket),{datasource="fpw"});
      structDelete(application.fpwSupportFixtures,runId);
      writeOutput(serializeJSON({SUCCESS=true,CLEANED=true}));
    } else if (listFind("non_scalar,mail_failure,admission_failure",action)) {
      // Copy the current handler, altering only the injected fault and its test URL/package.
      probeName="GlobalHelpProbe" & action & runId;
      probePath=expandPath("./support/" & probeName & ".cfc");
      source=fileRead(expandPath("../api/v1/contactUs.cfc"),"utf-8");
      source=replace(source,'reReplaceNoCase(cgi.script_name, "/api/v1/contactUs[.]cfc$", "")','"/fpw"',"one");
      source=replace(source,'reReplace(getMetadata(this).name, "[.][^.]+$", "." & arguments.name)','"fpw.api.v1." & arguments.name',"one");
      if (action EQ "mail_failure") source=replace(source,'<cfmail','<cfmail server="127.0.0.1" port="1" timeout="2"',"one");
      if (action EQ "admission_failure") source=replace(source,'componentPath("AuthRateLimitService")).init("fpw")','componentPath("AuthRateLimitService")).init("fpw_support_nonexistent_test_datasource")',"one");
      for (field in body.fields) form[field]=body.fields[field];
      if (action EQ "non_scalar") form.subject={unexpected="structured value"};
      try {
        fileWrite(probePath,source,"utf-8");
        createObject("component","fpw.tests.support." & probeName).handle();
      } finally {if (fileExists(probePath)) fileDelete(probePath);}
    } else {cfheader(statuscode=400);writeOutput(serializeJSON({SUCCESS=false,ERROR="INVALID_ACTION"}));}
  }
}
</cfscript>
