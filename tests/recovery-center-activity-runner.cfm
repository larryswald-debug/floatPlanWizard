<cfsetting enablecfoutputonly="true" showdebugoutput="false" requesttimeout="180">
<cfparam name="url.confirm" default="">
<cfif url.confirm NEQ "RUN_RECOVERY_ACTIVITY_TESTS" OR val(cgi.server_port) NEQ 8500
 OR NOT listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name)
 OR NOT reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host)>
 <cfheader statuscode="404"><cfabort>
</cfif>
<cfscript>
uid=0;result={};cleanup={SUCCESS=false};
try {
 fixture=new fpw.tests.support.RecoveryReadinessFixture();
 member=fixture.fresh();uid=member.userId;
 params={uid={value=uid,cfsqltype="cf_sql_integer"}};
 queryExecute("UPDATE users SET email=:email WHERE userId=:uid",
  {uid=params.uid,email={value="codex-activity-core-" & left(lCase(replace(createUUID(),"-","","all")),12) & "@example.test",cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
 transaction {
  inserted={};
  queryExecute("INSERT INTO vessels(userId,vesselName,hailingPort,isDefaultVessel) VALUES(:uid,'Activity recovery fixture','Fixture Port',1)",params,{datasource="fpw",result="inserted"});
  events=new fpw.includes.ProductEventService();
  events.recordRequiredMemberActivity(uid,"vessel_created",val(inserted.generatedKey));
  for(index=1;index LTE 2;index++){
   queryExecute("INSERT INTO waypoints(userId,name,latitude,longitude) VALUES(:uid,:name,:latitude,:longitude)",
    {uid=params.uid,name={value="Activity waypoint " & index,cfsqltype="cf_sql_varchar"},
     latitude={value=index EQ 1 ? "38.95" : "39.00",cfsqltype="cf_sql_varchar"},
     longitude={value=index EQ 1 ? "-76.49" : "-76.45",cfsqltype="cf_sql_varchar"}},{datasource="fpw",result="inserted"});
   events.recordRequiredMemberActivity(uid,"waypoint_created",val(inserted.generatedKey));
  }
 }
 request.memberActivityFixtureUserId=uid;
 raw=new testbox.system.TestBox(bundles="fpw.tests.specs.MemberActivityEvidenceSpec").runRaw().getMemento();
 failures=[];
 for(bundle in raw.bundleStats) for(suite in bundle.suiteStats){
  for(spec in suite.specStats) if(spec.status NEQ "Passed") arrayAppend(failures,{name=spec.name,message=spec.failMessage});
  for(child in suite.suiteStats) for(spec in child.specStats) if(spec.status NEQ "Passed") arrayAppend(failures,{name=spec.name,message=spec.failMessage});
 }
 result={total=raw.totalSpecs,passed=raw.totalPass,failed=raw.totalFail,errors=raw.totalError,failures=failures};
} catch(any problem){result={error=problem.message,detail=problem.detail ?: ""};}
finally {
 if(uid GT 0) {
  try {cleanup=new fpw.tests.support.MemberActivityHarness().cleanup(uid);}
  catch(any cleanupError){cleanup={SUCCESS=false,message=cleanupError.message};}
 }
}
result.cleanup=cleanup;
</cfscript>
<cfheader statuscode="#structKeyExists(result,'total') AND result.failed EQ 0 AND result.errors EQ 0 AND cleanup.SUCCESS ? 200 : 500#">
<cfcontent type="application/json" reset="true"><cfoutput>#serializeJSON(result)#</cfoutput>
