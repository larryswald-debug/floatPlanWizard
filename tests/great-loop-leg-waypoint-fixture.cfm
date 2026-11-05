<cfsetting showdebugoutput="false" requesttimeout="120">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
localOnly=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
 AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host) GT 0 AND val(cgi.server_port) EQ 8500;
if (!localOnly OR cgi.request_method NEQ "POST" OR (url.confirm ?: "") NEQ "RUN_GREAT_LOOP_LEG_WAYPOINT_TESTS") {
 cfheader(statuscode=404); writeOutput(serializeJSON({SUCCESS=false})); abort;
}
action=url.action ?: "";
try {
 if (action EQ "create") {
  run=lCase(replace(createUUID(),"-","","all")); token=run & lCase(replace(createUUID(),"-","","all"));
  password="LegStops-" & run & "!"; members={}; inserted={};
  transaction {
   for(slot in ["owner","other"]) {
    email="codex-activity-leg-stops-" & run & "-" & slot & "@example.test";
    queryExecute("INSERT INTO users(fName,lName,email,password,passwordCreated,created) VALUES('Leg','Stops',:email,:password,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
     {email={value=email,cfsqltype="cf_sql_varchar"},password={value=new fpw.api.v1.PasswordHashService().hashPassword(password),cfsqltype="cf_sql_varchar"}},{datasource="fpw",result="inserted"});
    members[slot]={userId=val(inserted.generatedKey),email=email};
   }
  }
  lock name="fpw-leg-waypoint-fixtures" type="exclusive" timeout=10 {
   if (!structKeyExists(application,"legWaypointFixtures")) application.legWaypointFixtures={};
   application.legWaypointFixtures[run]={tokenHash=hash(token,"SHA-256"),members=members,created=now(),clientIp=new fpw.api.v1.AuthRequestGuardService().getClientIp()};
  }
  writeOutput(serializeJSON({SUCCESS=true,run=run,token=token,password=password,members=members}));abort;
 }
 run=url.run ?: ""; provided=cgi.http_x_fpw_leg_test_token ?: "";
 if (!reFind("^[a-f0-9]{32}$",run) OR !len(provided) OR !structKeyExists(application,"legWaypointFixtures") OR !structKeyExists(application.legWaypointFixtures,run)) {cfheader(statuscode=403);abort;}
 fixture=application.legWaypointFixtures[run];
 if (compare(hash(provided,"SHA-256"),fixture.tokenHash) OR dateDiff("n",fixture.created,now()) GT 120) {cfheader(statuscode=403);abort;}
 ids=[fixture.members.owner.userId,fixture.members.other.userId];
 params={ids={value=arrayToList(ids),list=true,cfsqltype="cf_sql_integer"}};
 if (action EQ "reset") {
  transaction {
   queryExecute("DELETE FROM waypoints WHERE userId IN (:ids)",params,{datasource="fpw"});
   queryExecute("DELETE FROM product_events WHERE user_id IN (:ids) AND event_name IN ('waypoint_created','waypoint_updated')",params,{datasource="fpw"});
  }
  writeOutput(serializeJSON({SUCCESS=true}));abort;
 }
 if (action EQ "state") {
  points=[];for(row in queryExecute("SELECT wpId,userId,name,latitude,longitude,notes FROM waypoints WHERE userId IN (:ids) ORDER BY wpId",params,{datasource="fpw"})) arrayAppend(points,row);
  counts={}; for(table in ["user_routes","route_instances","route_instance_legs","floatplans"]) {
   // Hash complete rows to detect route edits without exposing member or trip data.
   key=table EQ "floatplans" ? "floatplanId" : "id";
   rows=queryExecute("SELECT * FROM " & table & " ORDER BY " & key,{}, {datasource="fpw"});
   rowKeys=[]; for (record in rows) arrayAppend(rowKeys,record[key]);
   counts[table]={count=rows.recordCount,keysHash=hash(serializeJSON(rowKeys),"SHA-256"),contentHash=hash(serializeJSON(rows),"SHA-256")};
  }
  events=queryExecute("SELECT COUNT(*) AS n FROM product_events WHERE user_id IN (:ids) AND event_name='waypoint_created'",params,{datasource="fpw"}).n[1];
  writeOutput(serializeJSON({SUCCESS=true,waypoints=points,routes=counts,waypointEvents=events}));abort;
 }
 if (action EQ "expire") {
  uid=structKeyExists(session,"user") ? (session.user.userId ?: session.user.id ?: 0) : 0;
  if (!arrayFind(ids,val(uid))) {cfheader(statuscode=403);abort;}
  structDelete(session,"user");writeOutput(serializeJSON({SUCCESS=true}));abort;
 }
 if (action EQ "failure") {
  uid=session.user.userId ?: session.user.id ?: 0;
  if (!arrayFind(ids,val(uid))) {cfheader(statuscode=403);abort;}
  target=new fpw.tests.support.LegWaypointTestHarness().controller((url.failAt ?: "2") EQ "1" ? 1 : 2);
  target.handle();abort;
 }
 if (action EQ "tests") {
  request.legWaypointFixtureUserId=fixture.members.owner.userId;
  runner=new testbox.system.TestBox(bundles="fpw.tests.specs.GreatLoopLegWaypointPersistenceSpec");
  results=runner.runRaw().getMemento();
  ok=results.totalSpecs GT 0 AND results.totalFail EQ 0 AND results.totalError EQ 0;
  cfheader(statuscode=ok ? 200 : 500);writeOutput(serializeJSON({SUCCESS=ok,results=results}));abort;
 }
 if (action EQ "cleanup") {
  for(slot in ["owner","other"]) {
   new fpw.tests.support.MemberActivityHarness().cleanup(fixture.members[slot].userId);
   for(bucket in new fpw.api.v1.AuthRateLimitService().init("fpw").buildBuckets("authenticate",fixture.members[slot].email,fixture.clientIp,false)) {
    if (bucket.scope EQ "ip") continue;
    queryExecute("DELETE FROM auth_rate_counters WHERE action_group=:actionGroup AND subject_scope=:scope AND subject_hash=UNHEX(:key)",
     {actionGroup={value=bucket.actionGroup,cfsqltype="cf_sql_varchar"},scope={value=bucket.scope,cfsqltype="cf_sql_varchar"},key={value=bucket.subjectHash,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
   }
  }
  lock name="fpw-leg-waypoint-fixtures" type="exclusive" timeout=10 {structDelete(application.legWaypointFixtures,run);}
  if (structKeyExists(session,"user") AND arrayFind(ids,val(session.user.userId ?: session.user.id ?: 0))) structDelete(session,"user");
  writeOutput(serializeJSON({SUCCESS=true,remainingUsers=val(queryExecute("SELECT COUNT(*) AS n FROM users WHERE userId IN (:ids)",params,{datasource="fpw"}).n[1])}));abort;
 }
 cfheader(statuscode=400);writeOutput(serializeJSON({SUCCESS=false,ERROR="UNKNOWN_ACTION"}));
} catch(any failure) {cfheader(statuscode=500);writeOutput(serializeJSON({SUCCESS=false,MESSAGE=failure.message,DETAIL=failure.detail}));}
</cfscript>
