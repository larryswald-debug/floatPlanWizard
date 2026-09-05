<cfsetting showdebugoutput="false" requesttimeout="120">
<cfscript>
// Local, authenticated disposable-fixture harness. No production/global failure switches.
localHost = listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name)
  AND reFindNoCase("^(localhost|127\\.0\\.0\\.1|\\[::1\\])(:8500)?$",cgi.http_host)
  AND val(cgi.server_port) EQ 8500;
if (!localHost OR cgi.request_method NEQ "POST" OR !structKeyExists(url,"confirm")
  OR url.confirm NEQ "RUN_MEMBER_ACTIVITY_EVIDENCE_TESTS"
  OR !structKeyExists(session,"user")) {
  cfheader(statuscode=404); abort;
}
uid = val(session.user.userId ?: session.user.id ?: 0);
fixture = queryExecute("SELECT userId FROM users WHERE userId=:uid
  AND email LIKE 'codex-activity-%@example.test'
  AND created >= DATE_SUB(NOW(), INTERVAL 4 HOUR)
  AND EXISTS (SELECT 1 FROM product_events e WHERE e.user_id=users.userId
    AND e.event_name='sign_up' AND e.event_source='member_signup')",
  {uid={value=uid,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
if (fixture.recordCount NEQ 1) {cfheader(statuscode=404); abort;}
family = url.family ?: "";
mode = url.mode ?: "";
if (!listFind("vessel,contact,operator,passenger,waypoint,routeBuilder,floatplan",family)
  OR !listFind("before,after,state,cleanup",mode)) {cfheader(statuscode=404); abort;}
cfcontent(type="application/json; charset=utf-8");
if (mode EQ "cleanup") {
  cleaned=createObject("component","fpw.tests.support.MemberActivityHarness").cleanup(uid);
  structDelete(session,"user");
  writeOutput(serializeJSON(cleaned)); abort;
}
if (mode EQ "state") {
  events=queryExecute("SELECT id,event_name,entity_type,entity_id,event_source,metadata_json,
    DATE_FORMAT(occurred_at_utc,'%Y-%m-%dT%H:%i:%sZ') AS utc
    FROM product_events WHERE user_id=:uid ORDER BY id",
    {uid={value=uid,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
  eventRows=[];
  for (row in events) arrayAppend(eventRows,row);
  ownedIds={};
  for (entity in [{key="vessel",table="vessels",id="vesselID"},{key="contact",table="contacts",id="contactId"},{key="operator",table="operators",id="opId"},{key="passenger",table="passengers",id="passId"},{key="waypoint",table="waypoints",id="wpId"}]) {
    ownedIds[entity.key]=[];
    ids=queryExecute("SELECT " & entity.id & " AS id FROM " & entity.table & " WHERE userId=:uid",
      {uid={value=uid,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    for (row in ids) arrayAppend(ownedIds[entity.key],val(row.id));
  }
  writeOutput(serializeJSON({SUCCESS=true,userId=uid,events=eventRows,owned_ids=ownedIds}));
  abort;
}
target=createObject("component","fpw.tests.support.MemberActivityHarness").controller(family,mode);
body=deserializeJSON(toString(getHttpRequestData().content));
if (family EQ "routeBuilder" OR family EQ "floatplan") target.handle(action=body.action ?: "");
else target.handle();
</cfscript>
