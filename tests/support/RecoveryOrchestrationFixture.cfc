component output="false" {
  variables.ids=[];
  variables.records={};
  variables.submissions=[];
  variables.attempts=0;
  variables.clockValue="2026-09-08T00:00:00Z";
  variables.enrollment="2026-09-01T00:00:00Z";
  variables.outcome="SUBMITTED";
  variables.race="";
  variables.emailMode="";
  variables.ledgerMode="";
  variables.missingEnrollment=false;
  variables.prefix="codex-recovery-orch-" & lCase(replace(createUUID(),"-","","all"));
  variables.barrier=createObject("java","java.util.concurrent.CyclicBarrier").init(javaCast("int",2));
  // Shift the fixed scenario together as the calendar advances; ledger writes still use real DB UTC.
  variables.dayOffset=val(queryExecute("SELECT DATEDIFF(UTC_DATE(),'2026-09-05') AS days",{}, {datasource="fpw"}).days[1]);

  public any function service() {
    var email=new fpw.tests.support.RecoveryOrchestrationEmailStub(mode=variables.emailMode);
    var ledger=new fpw.tests.support.RecoveryOrchestrationLedgerStub(mode=variables.ledgerMode);
    var classifier=new fpw.tests.support.RecoveryOrchestrationRaceClassifier(fixture=this,action=variables.race);
    return new fpw.api.v1.InactiveMemberRecoveryService(
      datasource="fpw",liveEnabled=true,classifier=classifier,ledger=ledger,emailService=email,
      contextProvider=this,candidateSource=this,clock=this,transport=this
    );
  }
  public void function configure(string outcome="SUBMITTED",string race="",string emailMode="",string ledgerMode="",boolean missingEnrollment=false) {
    variables.outcome=arguments.outcome;
    variables.race=arguments.race;
    variables.emailMode=arguments.emailMode;
    variables.ledgerMode=arguments.ledgerMode;
    variables.missingEnrollment=arguments.missingEnrollment;
  }
  public array function getCandidateIds(required numeric limit) {
    var ids=[];
    for (var id in variables.ids) {
      if (arrayLen(ids) GTE arguments.limit) break;
      arrayAppend(ids,id);
    }
    return ids;
  }
  public string function getEnrollmentUtc(required numeric userId) {
    return !variables.missingEnrollment AND structKeyExists(variables.records,toString(arguments.userId)) ? shiftedUtc(variables.enrollment) : "";
  }
  public string function nowUtc() { return shiftedUtc(variables.clockValue); }
  private string function shiftedUtc(required string value) {
    var row=queryExecute("SELECT DATE_FORMAT(DATE_ADD(CAST(:at AS DATETIME),INTERVAL :days DAY),'%Y-%m-%dT%H:%i:%sZ') AS value",
      {at={value=replace(replace(arguments.value,"T"," "),"Z",""),cfsqltype="cf_sql_varchar"},
       days={value=variables.dayOffset,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    return toString(row.value[1]);
  }
  public void function setNow(required string value) { variables.clockValue=arguments.value; }
  public void function awaitBoth() {
    variables.barrier.await(javaCast("long",15),createObject("java","java.util.concurrent.TimeUnit").SECONDS);
  }
  public struct function submitInactiveMemberRecoveryEmail(required string toEmail,required struct message) {
    lock name=variables.prefix & "-transport" type="exclusive" timeout=10 {
      variables.attempts++;
      if (variables.outcome EQ "THROW") throw(type="tests.UnknownTransport",message="CONTROLLED_UNKNOWN_RESULT");
      if (variables.outcome EQ "SUBMITTED") arrayAppend(variables.submissions,duplicate(arguments.message));
      return {OUTCOME=variables.outcome,CODE=(variables.outcome EQ "FAILED" ? "CONTROLLED_TRANSPORT_FAILURE" : variables.outcome)};
    }
  }
  public numeric function submittedCount() { return arrayLen(variables.submissions); }
  public numeric function attemptCount() { return variables.attempts; }
  public array function messages() { return duplicate(variables.submissions); }
  public string function prefix() { return variables.prefix; }

  public struct function createMember(string stage="A",string entry="2026-09-01 00:00:00") {
    var email=variables.prefix & "-" & (arrayLen(variables.ids)+1) & "@example.test";
    var inserted={};
    queryExecute(
      "INSERT INTO users (fName,lName,email,password,passwordCreated,created)
       VALUES ('Recovery','Fixture',:email,:password,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
      {email={value=email,cfsqltype="cf_sql_varchar"},password={value=hash(createUUID(),"SHA-256"),cfsqltype="cf_sql_varchar"}},
      {datasource="fpw",result="inserted"}
    );
    var userId=val(inserted.generatedKey);
    arrayAppend(variables.ids,userId);
    variables.records[toString(userId)]={userId=userId,email=email,planId=0,routeId=0,vesselId=0};
    event(userId,"sign_up","user",userId,"member_signup","2026-08-01 00:00:00");
    if (arguments.stage NEQ "A") advance(userId,arguments.stage,arguments.entry);
    return duplicate(variables.records[toString(userId)]);
  }
  public void function advance(required numeric userId,required string stage,string at="2026-09-01 00:00:00") {
    var inserted={};
    var member=variables.records[toString(arguments.userId)];
    var params={userId={value=arguments.userId,cfsqltype="cf_sql_integer"}};
    if (arguments.stage EQ "B") {
      queryExecute("INSERT INTO vessels (userId,vesselName,hailingPort,isDefaultVessel) VALUES (:userId,'Fixture Vessel','Fixture Port',1)",params,{datasource="fpw",result="inserted"});
      member.vesselId=val(inserted.generatedKey);
      event(arguments.userId,"vessel_created","vessel",member.vesselId,"member_api",arguments.at);
    } else if (arguments.stage EQ "C") {
      queryExecute("INSERT INTO user_routes (user_id,route_name,is_active,created_at,updated_at) VALUES (:userId,'Fixture Route',1,UTC_TIMESTAMP(),UTC_TIMESTAMP())",params,{datasource="fpw",result="inserted"});
      member.routeId=val(inserted.generatedKey);
      event(arguments.userId,"user_route_created","user_route",member.routeId,"member_api",arguments.at);
    } else if (arguments.stage EQ "D") {
      queryExecute("INSERT INTO floatplans (userId,floatPlanName,dateCreated,lastUpdate,status,lastUpdateStatus,route_origin,is_reusable,is_visible_in_route_library) VALUES (:userId,'Recovery Sender Draft',UTC_TIMESTAMP(),UTC_TIMESTAMP(),'DRAFT',UTC_TIMESTAMP(),'basic_manual',1,1)",params,{datasource="fpw",result="inserted"});
      member.planId=val(inserted.generatedKey);
      event(arguments.userId,"float_plan_created","float_plan",member.planId,"member_api",arguments.at);
    }
  }
  public void function event(required numeric userId,required string name,required string entity,required numeric id,required string source,required string at) {
    queryExecute(
      "INSERT INTO product_events (event_uuid,user_id,event_name,entity_type,entity_id,event_source,occurred_at_utc,metadata_json,created_at_utc,idempotency_key)
       VALUES (:uuid,:userId,:name,:entity,:id,:source,CAST(:at AS DATETIME),'{}',UTC_TIMESTAMP(),:eventKey)",
      {
        uuid={value=createUUID(),cfsqltype="cf_sql_char"},userId={value=arguments.userId,cfsqltype="cf_sql_integer"},
        name={value=arguments.name,cfsqltype="cf_sql_varchar"},entity={value=arguments.entity,cfsqltype="cf_sql_varchar"},
        id={value=arguments.id,cfsqltype="cf_sql_bigint"},source={value=arguments.source,cfsqltype="cf_sql_varchar"},
        at={value=replace(replace(shiftedUtc(arguments.at),"T"," "),"Z",""),cfsqltype="cf_sql_varchar"},eventKey={value=variables.prefix & "-" & createUUID(),cfsqltype="cf_sql_varchar"}
      },{datasource="fpw"}
    );
  }
  public void function changeAfterEvaluation(required numeric userId,required string action) {
    var member=variables.records[toString(arguments.userId)];
    if (arguments.action EQ "advance") advance(arguments.userId,"D");
    if (arguments.action EQ "share") share(arguments.userId,"basic");
    if (arguments.action EQ "optout") {
      new fpw.api.v1.EmailOptOutService(datasource="fpw").recordOptOut(member.email,arguments.userId,"non_essential","sender_test");
    }
    if (arguments.action EQ "active") {
      queryExecute("INSERT INTO floatplan_monitoring (float_plan_id,user_id,monitoring_mode,monitor_state,is_monitoring_enabled) VALUES (:planId,:userId,'basic','ACTIVE',1)",
        {planId={value=member.planId,cfsqltype="cf_sql_bigint"},userId={value=arguments.userId,cfsqltype="cf_sql_bigint"}},{datasource="fpw"});
    }
    if (arguments.action EQ "barrier") awaitBoth();
  }
  public void function share(required numeric userId,required string origin) {
    var member=variables.records[toString(arguments.userId)];
    if (!member.planId) advance(arguments.userId,"D");
    event(arguments.userId,arguments.origin & "_send_completed","float_plan",member.planId,
      arguments.origin EQ "basic" ? "basic_review_send" : "premium_save_send","2026-09-01 00:00:00");
  }
  public void function deletePlanningRows(required numeric userId) {
    var params={id={value=arguments.userId,cfsqltype="cf_sql_integer"}};
    queryExecute("DELETE FROM floatplans WHERE userId=:id",params,{datasource="fpw"});
    queryExecute("DELETE FROM user_routes WHERE user_id=:id",params,{datasource="fpw"});
  }
  public struct function state(required numeric userId,required string stage) {
    return new fpw.includes.InactiveMemberRecoveryLedgerService().getStageState(arguments.userId,arguments.stage);
  }
  public struct function counts() {
    if (!arrayLen(variables.ids)) return {users=0,ledger=0,events=0,submitted=submittedCount(),attempted=attemptCount()};
    var q=queryExecute("SELECT (SELECT COUNT(*) FROM users WHERE userId IN (:ids)) AS users,(SELECT COUNT(*) FROM inactive_member_recovery_deliveries WHERE user_id IN (:ids)) AS ledger,(SELECT COUNT(*) FROM product_events WHERE user_id IN (:ids)) AS events",
      {ids={value=arrayToList(variables.ids),cfsqltype="cf_sql_integer",list=true}},{datasource="fpw"});
    return {users=val(q.users[1]),ledger=val(q.ledger[1]),events=val(q.events[1]),submitted=submittedCount(),attempted=attemptCount()};
  }
  public void function cleanup() {
    if (!arrayLen(variables.ids)) return;
    var params={ids={value=arrayToList(variables.ids),cfsqltype="cf_sql_integer",list=true}};
    for (var sql in [
      "DELETE FROM email_optout WHERE user_id IN (:ids)",
      "DELETE FROM inactive_member_recovery_deliveries WHERE user_id IN (:ids)",
      "DELETE FROM product_events WHERE user_id IN (:ids)",
      "DELETE FROM floatplan_monitoring WHERE user_id IN (:ids)",
      "DELETE FROM floatplans WHERE userId IN (:ids)",
      "DELETE FROM user_routes WHERE user_id IN (:ids)",
      "DELETE FROM vessels WHERE userId IN (:ids)",
      "DELETE FROM member_entitlements WHERE user_id IN (:ids)",
      "DELETE FROM users WHERE userId IN (:ids)"
    ]) queryExecute(sql,params,{datasource="fpw"});
  }
}
