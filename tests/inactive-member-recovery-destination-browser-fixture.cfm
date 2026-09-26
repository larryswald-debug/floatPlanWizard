<cfsetting enablecfoutputonly="true" showdebugoutput="false" requesttimeout="120">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfheader name="Cache-Control" value="no-store">
<cfscript>
localOnly=listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",cgi.http_host) GT 0
  AND val(cgi.server_port) EQ 8500;
if (!localOnly OR !structKeyExists(url,"confirm") OR url.confirm NEQ "RUN_RECOVERY_DESTINATION_BROWSER") {
  cfheader(statuscode=404); writeOutput(serializeJSON({ok=false,error="LOCAL_CONFIRMATION_REQUIRED"})); abort;
}
for (inputKey in structKeyArray(url)) {
  if (!listFindNoCase("confirm,action,runKey",inputKey)) {
    cfheader(statuscode=400); writeOutput(serializeJSON({ok=false,error="UNKNOWN_FIELD"})); abort;
  }
}
action=structKeyExists(url,"action") ? toString(url.action) : "";
reply={ok=false,error="INVALID_ACTION"};
function fixtureCounts(required any fixture) {
  var ids=arguments.fixture.getCandidateIds(100);
  if (!arrayLen(ids)) return {};
  var q=queryExecute("SELECT
    (SELECT COUNT(*) FROM users WHERE userId IN (:ids)) AS users,
    (SELECT COUNT(*) FROM product_events WHERE user_id IN (:ids)) AS events,
    (SELECT COUNT(*) FROM inactive_member_recovery_deliveries WHERE user_id IN (:ids)) AS ledger,
    (SELECT COUNT(*) FROM floatplans WHERE userId IN (:ids)) AS plans,
    (SELECT COUNT(*) FROM user_routes WHERE user_id IN (:ids)) AS routes,
    (SELECT COUNT(*) FROM waypoints WHERE userId IN (:ids)) AS waypoints,
    (SELECT COUNT(*) FROM contacts WHERE userId IN (:ids)) AS contacts,
    (SELECT COUNT(*) FROM operators WHERE userId IN (:ids)) AS operators",
    {ids={value=arrayToList(ids),cfsqltype="cf_sql_integer",list=true}},{datasource="fpw"});
  return {users=val(q.users[1]),events=val(q.events[1]),ledger=val(q.ledger[1]),plans=val(q.plans[1]),
    routes=val(q.routes[1]),waypoints=val(q.waypoints[1]),contacts=val(q.contacts[1]),operators=val(q.operators[1]),submissions=arguments.fixture.submittedCount()};
}
function cleanupFixture(required any fixture) {
  var params={ids={value=arrayToList(arguments.fixture.getCandidateIds(100)),cfsqltype="cf_sql_integer",list=true}};
  if (!len(params.ids.value)) return;
  queryExecute("DELETE bd FROM floatplan_basic_details bd JOIN floatplans fp ON fp.floatplanId=bd.floatplan_id WHERE fp.userId IN (:ids)",params,{datasource="fpw"});
  queryExecute("DELETE l FROM user_route_legs l JOIN user_routes r ON r.id=l.user_route_id WHERE r.user_id IN (:ids)",params,{datasource="fpw"});
  queryExecute("DELETE FROM waypoints WHERE userId IN (:ids)",params,{datasource="fpw"});
  queryExecute("DELETE FROM contacts WHERE userId IN (:ids)",params,{datasource="fpw"});
  queryExecute("DELETE FROM operators WHERE userId IN (:ids)",params,{datasource="fpw"});
  arguments.fixture.cleanup();
}
try {
  if (action EQ "prepare") {
    fixture=new fpw.tests.support.RecoveryOrchestrationFixture();
    runKey=lCase(replace(createUUID(),"-","","all"));
    testPassword="Recovery-" & runKey;
    members={};
    try {
      transaction {
        members.a=fixture.createMember("A");
        members.b=fixture.createMember("B");
        members.bReady=fixture.createMember("B");
        members.cZero=fixture.createMember("C");
        members.cLegs=fixture.createMember("C");
        members.dBasic=fixture.createMember("D");
        members.dOrdinary=fixture.createMember("D");
        members.stale=fixture.createMember("C");
        fixture.advance(members.stale.userId,"D");
        // Capture the stale Draft ID, then remove only this run's planning rows.
        stalePlan=queryExecute("SELECT floatplanId FROM floatplans WHERE userId=:uid",
          {uid={value=members.stale.userId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
        members.stale.planId=val(stalePlan.floatplanId[1]);
        fixture.deletePlanningRows(members.stale.userId);
        ids=fixture.getCandidateIds(100);
        queryExecute("UPDATE users SET password=:password WHERE userId IN (:ids)",
          {password={value=hash(testPassword,"SHA-256","UTF-8"),cfsqltype="cf_sql_varchar"},
           ids={value=arrayToList(ids),cfsqltype="cf_sql_integer",list=true}},{datasource="fpw"});
        basicParams={id={value=members.dBasic.planId,cfsqltype="cf_sql_integer"}};
        queryExecute("UPDATE floatplans SET vesselId=0,operatorId=NULL,route_instance_id=NULL,route_day_number=NULL,
          route_origin='basic_float_plan',is_reusable=0,is_visible_in_route_library=0 WHERE floatplanId=:id",basicParams,{datasource="fpw"});
        queryExecute("INSERT INTO floatplan_basic_details (floatplan_id,vessel_name,operator_name,captain_name,captain_email,
          notification_contact_name,notification_contact_email,launch_location,destination_location,authority_name_snapshot,
          authority_phone_snapshot,created_at,updated_at) VALUES (:id,'Recovery browser vessel','Recovery browser operator',
          'Recovery browser captain','captain@example.test','Recovery browser contact','contact@example.test',
          'Recovery launch','Recovery destination','N/A - Not Applicable','',UTC_TIMESTAMP(),UTC_TIMESTAMP())",basicParams,{datasource="fpw"});
        readyParams={uid={value=toString(members.bReady.userId),cfsqltype="cf_sql_varchar"}};
        queryExecute("INSERT INTO contacts (userId,name,phone,email) VALUES (:uid,'Recovery contact','727-555-0123','recovery-contact@example.test')",readyParams,{datasource="fpw"});
        queryExecute("INSERT INTO operators (userId,name) VALUES (:uid,'Recovery operator')",readyParams,{datasource="fpw"});
        queryExecute("INSERT INTO waypoints (userId,name,latitude,longitude) VALUES (:uid,'Recovery ready start','28.10','-82.80'),(:uid,'Recovery ready end','28.11','-82.81')",readyParams,{datasource="fpw"});
        waypointIds=[];
        for (wp in [{name="Recovery start",lat="28.10",lon="-82.80"},{name="Recovery end",lat="28.11",lon="-82.81"}]) {
          inserted={};
          queryExecute("INSERT INTO waypoints (name,latitude,longitude,userId) VALUES (:name,:lat,:lon,:uid)",
            {name={value=wp.name,cfsqltype="cf_sql_varchar"},lat={value=wp.lat,cfsqltype="cf_sql_varchar"},
             lon={value=wp.lon,cfsqltype="cf_sql_varchar"},uid={value=toString(members.cLegs.userId),cfsqltype="cf_sql_varchar"}},
            {datasource="fpw",result="inserted"});
          arrayAppend(waypointIds,val(inserted.generatedKey));
        }
        queryExecute("INSERT INTO user_route_legs (user_route_id,order_index,start_waypoint_id,end_waypoint_id)
          VALUES (:routeId,1,:startId,:endId)",
          {routeId={value=members.cLegs.routeId,cfsqltype="cf_sql_integer"},startId={value=waypointIds[1],cfsqltype="cf_sql_integer"},
           endId={value=waypointIds[2],cfsqltype="cf_sql_integer"}},{datasource="fpw"});
      }
      lock name="fpw-recovery-destination-browser-fixtures" type="exclusive" timeout=10 {
        if (!structKeyExists(application,"recoveryDestinationBrowserFixtures")) application.recoveryDestinationBrowserFixtures={};
        application.recoveryDestinationBrowserFixtures[runKey]={fixture=fixture,expiresAt=dateAdd("n",30,now()),members=members};
      }
      reply={ok=true,runKey=runKey,password=testPassword,members=members,counts=fixtureCounts(fixture)};
    } catch (any preparationFailure) {
      cleanupFixture(fixture);
      rethrow;
    }
  } else if (listFind("inspect,cleanup",action)) {
    runKey=structKeyExists(url,"runKey") ? toString(url.runKey) : "";
    if (!reFind("^[a-f0-9]{32}$",runKey) OR reFind("[^a-f0-9]",runKey)) {
      reply={ok=false,error="UNKNOWN_FIXTURE"};
    } else {
      lock name="fpw-recovery-destination-browser-fixtures" type="exclusive" timeout=15 {
        if (!structKeyExists(application,"recoveryDestinationBrowserFixtures") OR !structKeyExists(application.recoveryDestinationBrowserFixtures,runKey)) {
          reply={ok=false,error="UNKNOWN_FIXTURE"};
        } else {
          run=application.recoveryDestinationBrowserFixtures[runKey];
          if (action EQ "cleanup") {
            cleanupFixture(run.fixture);
            reply={ok=true,remaining=fixtureCounts(run.fixture)};
            structDelete(application.recoveryDestinationBrowserFixtures,runKey);
          } else if (dateCompare(now(),run.expiresAt) GT 0) {
            reply={ok=false,error="EXPIRED_FIXTURE"};
          } else reply={ok=true,counts=fixtureCounts(run.fixture)};
        }
      }
    }
  }
} catch (any failure) {
  cfheader(statuscode=500);
  reply={ok=false,error="FIXTURE_FAILED",message=failure.message,detail=failure.detail};
}
writeOutput(serializeJSON(reply));
</cfscript>
