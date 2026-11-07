component extends="testbox.system.BaseSpec" output=false {
 function run() {
  describe("Minimum beta activation uses accepted evidence",function(){
   beforeEach(function(){
    if(!structKeyExists(request,"betaProgramTestRun")) throw(type="BetaTest.Scope",message="Use the local beta-program runner.");
    variables.service=new fpw.api.v1.BetaReportService().init("fpw");
    variables.enrolled="2026-01-02 12:00:00.000000";
    variables.accepted="2026-01-03 12:00:00.000000";
    variables.cutoff="2026-01-04 12:00:00.000000";
   });
   it("counts current assets without requiring post-enrollment recreation",function(){
    var c=cohort();c[1].has_vessel=1;c[1].has_route=1;c[1].has_floatplan=1;
    var r=report(c);
    expect(r.summary.enrolled).toBe(1);expect(r.summary.vessels).toBe(1);expect(r.summary.routes).toBe(1);expect(r.summary.floatplans).toBe(1);
    expect(r.summary.acceptedShares).toBe(0);expect(r.summary.unknownMembers).toBe(1);
   });
   it("excludes invitations, withdrawn participants and future enrollment",function(){
    var c=cohort();c[1].status="INVITED";expect(report(c).summary.enrolled).toBe(0);
    c[1].status="WITHDRAWN";expect(report(c).summary.enrolled).toBe(0);
    c[1].status="ENROLLED";c[1].enrolled_utc=cutoff;expect(report(c).summary.enrolled).toBe(0);
   });
   it("returns zero with a disclosed empty denominator",function(){expect(report([]).summary.activationPercent).toBe(0);});
   it("counts a SENT Basic Review receipt without requiring ACTIVE plan status",function(){
    var r=report(cohort(),[basic()]);expect(r.summary.acceptedShares).toBe(1);expect(r.summary.activationPercent).toBe(100);
   });
   it("does not count PROCESSING or FAILED Basic receipts",function(){
    var b=basic();b.status="PROCESSING";var r=report(cohort(),[b]);expect(r.summary.acceptedShares).toBe(0);expect(r.members[1].unknown_evidence).toBeTrue();
    b.status="FAILED";expect(report(cohort(),[b]).summary.acceptedShares).toBe(0);
   });
   it("requires positive Premium recipient count",function(){
    var p=premium();expect(report(cohort(),[],[p]).summary.acceptedShares).toBe(1);
    p.recipient_count=0;expect(report(cohort(),[],[p]).summary.acceptedShares).toBe(0);
   });
   it("does not inflate members from duplicate receipts and completed events",function(){
    var b=basic();var e=event();var r=report(cohort(),[b,b],[premium()],[e,e]);
    expect(r.summary.acceptedShares).toBe(1);expect(r.summary.activationPercent).toBe(100);
   });
   it("rejects pre-enrollment and cutoff-time shares",function(){
    var b=basic();b.accepted_utc="2026-01-01 12:00:00.000000";expect(report(cohort(),[b]).summary.acceptedShares).toBe(0);
    b.accepted_utc=cutoff;expect(report(cohort(),[b]).summary.acceptedShares).toBe(0);
   });
   it("permits exact enrollment time and marks missing accepted time unknown",function(){
    var b=basic();b.accepted_utc=enrolled;expect(report(cohort(),[b]).summary.acceptedShares).toBe(1);
    b.accepted_utc="";var r=report(cohort(),[b]);expect(r.summary.acceptedShares).toBe(0);expect(r.members[1].unknown_evidence).toBeTrue();
   });
   it("rejects current foreign ownership but accepts retained deleted-plan evidence",function(){
    var b=basic();b.valid_owner=0;expect(report(cohort(),[b]).summary.acceptedShares).toBe(0);
    b.valid_owner=1;expect(report(cohort(),[b]).summary.acceptedShares).toBe(1);
   });
   it("requires valid completed-event source, type, key and clock",function(){
    var e=event();expect(report(cohort(),[],[],[e]).summary.acceptedShares).toBe(1);
    e.event_source="browser";expect(report(cohort(),[],[],[e]).summary.acceptedShares).toBe(0);
    e=event();e.entity_type="route_instance";expect(report(cohort(),[],[],[e]).summary.acceptedShares).toBe(0);
    e=event();e.idempotency_key="click";expect(report(cohort(),[],[],[e]).summary.acceptedShares).toBe(0);
    e=event();e.created_utc=enrolled;expect(report(cohort(),[],[],[e]).summary.acceptedShares).toBe(0);
   });
   it("never counts a generated link or click",function(){
    var e=event();e.event_name="follow_page_shared";expect(report(cohort(),[],[],[e]).summary.acceptedShares).toBe(0);
   });
   it("rejects invalid product metadata and event ownership",function(){
    var e=event();e.metadata_object=0;expect(report(cohort(),[],[],[e]).summary.acceptedShares).toBe(0);
    e=event();e.valid_owner=0;expect(report(cohort(),[],[],[e]).summary.acceptedShares).toBe(0);
   });
   it("requires a Basic Review receipt key and rejects retained receipt mismatch",function(){
    var e=event();e.event_source="basic_review_send";e.idempotency_key="basic_send_completed:basic_review_receipt:10";
    expect(report(cohort(),[],[],[e]).summary.acceptedShares).toBe(1);
    var b=basic();b.id="10";b.user_id="99";expect(report(cohort(),[b],[],[e]).summary.acceptedShares).toBe(0);
   });
   it("counts Premium completion only from its canonical source",function(){
    var e=event();e.event_name="premium_send_completed";e.event_source="premium_save_send";e.idempotency_key="premium_send_completed:float_plan:100";
    expect(report(cohort(),[],[],[e]).summary.acceptedShares).toBe(1);
    e.event_source="basic_save_send";expect(report(cohort(),[],[],[e]).summary.acceptedShares).toBe(0);
   });
   it("accepts one matching tracked start and succeeded terminal",function(){
    expect(report(cohort(),[],[],pair()).summary.acceptedShares).toBe(1);
   });
   it("rejects orphan or conflicting terminal evidence",function(){
    var events=pair();var r=report(cohort(),[],[],[events[2]]);expect(r.summary.acceptedShares).toBe(0);expect(r.members[1].unknown_evidence).toBeTrue();
    var failed=duplicate(events[2]);failed.id="3";failed.event_name="recovery_share_failed";failed.idempotency_key="recovery_share:" & failed.request_correlation_id & ":failed";
    arrayAppend(events,failed);expect(report(cohort(),[],[],events).summary.acceptedShares).toBe(0);
   });
   it("rejects mismatched source, plan, ordering or malformed tracked key",function(){
    var events=pair();events[2].event_source="premium_save_send";expect(report(cohort(),[],[],events).summary.acceptedShares).toBe(0);
    events=pair();events[2].entity_id="101";expect(report(cohort(),[],[],events).summary.acceptedShares).toBe(0);
    events=pair();events[2].id="1";expect(report(cohort(),[],[],events).summary.acceptedShares).toBe(0);
    events=pair();events[2].idempotency_key="other";expect(report(cohort(),[],[],events).summary.acceptedShares).toBe(0);
   });
   it("does not turn a tracked failed operation into activation",function(){
    var events=pair();events[2].event_name="recovery_share_failed";events[2].idempotency_key="recovery_share:" & events[2].request_correlation_id & ":failed";
    expect(report(cohort(),[],[],events).summary.acceptedShares).toBe(0);
   });
   it("separates members and ignores evidence for people outside the cohort",function(){
    var b=basic();b.user_id="99";expect(report(cohort(),[b]).summary.acceptedShares).toBe(0);
    var c=cohort();var second=duplicate(c[1]);second.user_id="43";arrayAppend(c,second);
    var r=report(c,[basic()]);expect(r.summary.enrolled).toBe(2);expect(r.summary.acceptedShares).toBe(1);expect(r.summary.activationPercent).toBe(50);
   });
   it("outputs only the intended ID and metric projections",function(){
    var c=cohort();c[1].email="private@example.test";var b=basic();b.recipient_email="shore@example.test";b.response_json="PRIVATE_PLAN";
    var out=serializeJSON(report(c,[b]));
    expect(findNoCase("private@example.test",out)).toBe(0);expect(findNoCase("shore@example.test",out)).toBe(0);expect(find("PRIVATE_PLAN",out)).toBe(0);
   });
   it("rejects an invalid cutoff instead of returning invented zero counts",function(){expect(function(){service.reconcile(cohort(),[],[],[],"");}).toThrow();});
   it("protects the live batch report with existing admin authorization",function(){
    var uid=member();expect(function(){service.getReport(uid);}).toThrow();
   });
   it("reconciles actual SQL receipt and tracked-event projections without mail",function(){
    var aid=member();var uid=member();var foreign=member();var inserted={};
    queryExecute("INSERT INTO member_entitlements(user_id,entitlement_type,source,status,starts_at_utc,expires_at_utc) VALUES(:id,'admin','beta_test','active',DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 DAY),DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 DAY))",p(aid),{datasource="fpw"});
    var participation=new fpw.api.v1.BetaProgramService().init("fpw");
    participation.inviteMember(aid,uid,"existing_member");participation.accept(uid);
    queryExecute("UPDATE fpw_beta_participation SET enrolled_at_utc=DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 1 MINUTE) WHERE user_id=:id",p(uid),{datasource="fpw"});
    queryExecute("INSERT INTO floatplans(userId,floatPlanName,status,dateCreated,lastUpdate) VALUES(:id,'Disposable Beta Report','DRAFT',UTC_TIMESTAMP(),UTC_TIMESTAMP())",p(uid),{datasource="fpw",result="inserted"});
    var planId=val(inserted.generatedKey);
    queryExecute("INSERT INTO basic_review_send_receipts(user_id,float_plan_id,contact_id,idempotency_key,status,recipient_email,created_at_utc,updated_at_utc,completed_at_utc) VALUES(:uid,:pid,1,:key,'SENT','private-shore@example.test',DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 1 SECOND),UTC_TIMESTAMP(6),DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 1 SECOND))",
     {uid={value=uid,cfsqltype="cf_sql_integer"},pid={value=planId,cfsqltype="cf_sql_integer"},key={value="beta-test:" & createUUID(),cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
    var r=service.getReport(aid);var own={};for(var row in r.members) if(row.user_id==uid) own=row;
    expect(own.has_floatplan).toBeTrue();expect(own.accepted_share).toBeTrue();expect(findNoCase("private-shore@example.test",serializeJSON(r))).toBe(0);
    queryExecute("UPDATE basic_review_send_receipts SET status='PROCESSING',completed_at_utc=NULL WHERE user_id=:id",p(uid),{datasource="fpw"});
    r=service.getReport(aid);for(var row in r.members) if(row.user_id==uid) own=row;
    expect(own.accepted_share).toBeFalse();expect(own.unknown_evidence).toBeTrue();
    var coverage=new fpw.includes.InactiveMemberRecoveryCoverageService().init("fpw");
    var token=coverage.beginShare(uid,planId,"basic_save_send");coverage.finishShare(uid,token,"succeeded");
    r=service.getReport(aid);for(var row in r.members) if(row.user_id==uid) own=row;
    expect(own.accepted_share).toBeTrue();
    queryExecute("UPDATE floatplans SET userId=:foreign WHERE floatPlanId=:pid",{foreign={value=foreign,cfsqltype="cf_sql_varchar"},pid={value=planId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    r=service.getReport(aid);for(var row in r.members) if(row.user_id==uid) own=row;
    expect(own.accepted_share).toBeFalse();
    // A referenced receipt outside the cohort must not be mistaken for deleted evidence.
    queryExecute("UPDATE floatplans SET userId=:uid WHERE floatPlanId=:pid",{uid={value=uid,cfsqltype="cf_sql_varchar"},pid={value=planId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    queryExecute("DELETE FROM product_events WHERE user_id=:id",p(uid),{datasource="fpw"});
    queryExecute("INSERT INTO floatplans(userId,floatPlanName,status) VALUES(:id,'Disposable foreign receipt','DRAFT')",p(foreign),{datasource="fpw",result="inserted"});
    var foreignPlan=val(inserted.generatedKey);
    queryExecute("INSERT INTO basic_review_send_receipts(user_id,float_plan_id,contact_id,idempotency_key,status,recipient_email,created_at_utc,updated_at_utc,completed_at_utc) VALUES(:uid,:pid,1,:key,'SENT','foreign-shore@example.test',UTC_TIMESTAMP(6),UTC_TIMESTAMP(6),UTC_TIMESTAMP(6))",
     {uid={value=foreign,cfsqltype="cf_sql_integer"},pid={value=foreignPlan,cfsqltype="cf_sql_integer"},key={value="beta-test:" & createUUID(),cfsqltype="cf_sql_varchar"}},{datasource="fpw",result="inserted"});
    new fpw.includes.ProductEventService().init("fpw").recordEvent(userId=uid,eventName="basic_send_completed",entityType="float_plan",entityId=planId,eventSource="basic_review_send",metadata={},idempotencyKey="basic_send_completed:basic_review_receipt:" & inserted.generatedKey);
    r=service.getReport(aid);for(var row in r.members) if(row.user_id==uid) own=row;
    expect(own.accepted_share).toBeFalse();
   });
   it("runs real batch SQL, includes only accepted members and has no dependence on Premium",function(){
    var aid=member();var uid=member();var invited=member();
    queryExecute("INSERT INTO member_entitlements(user_id,entitlement_type,source,status,starts_at_utc,expires_at_utc) VALUES(:id,'admin','beta_test','active',DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 DAY),DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 DAY))",p(aid),{datasource="fpw"});
    var participation=new fpw.api.v1.BetaProgramService().init("fpw");
    participation.inviteMember(aid,uid,"existing_member");participation.accept(uid);
    participation.inviteMember(aid,invited,"existing_member");
    queryExecute("UPDATE fpw_beta_participation SET enrolled_at_utc=DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 1 MINUTE) WHERE user_id=:id",p(uid),{datasource="fpw"});
    var r=service.getReport(aid);var found=false;var sawInvite=false;
    for(var row in r.members) {if(row.user_id==uid) found=true;if(row.user_id==invited) sawInvite=true;}
    expect(found).toBeTrue();expect(sawInvite).toBeFalse();expect(len(r.cutoffUtc)).toBe(26);
    participation.withdraw(uid);r=service.getReport(aid);found=false;for(var row in r.members) if(row.user_id==uid) found=true;
    expect(found).toBeFalse();
   });
  });
 }
 private array function cohort(){return [{user_id="42",status="ENROLLED",enrolled_utc=variables.enrolled,has_vessel=0,has_route=0,has_floatplan=0}];}
 private struct function basic(){return {id="10",user_id="42",float_plan_id="100",status="SENT",created_utc=variables.accepted,accepted_utc=variables.accepted,valid_owner=1};}
 private struct function premium(){var r=basic();r.recipient_count=1;return r;}
 private struct function event(){return {id="1",user_id="42",entity_id="100",entity_type="float_plan",event_name="basic_send_completed",event_source="basic_save_send",idempotency_key="basic_send_completed:float_plan:100",request_correlation_id="",occurred_utc=variables.accepted,created_utc=variables.accepted,metadata_valid=1,metadata_object=1,metadata_empty=1,valid_owner=1};}
 private array function pair(){
  var first=event();first.event_name="recovery_share_started";first.request_correlation_id="11111111-2222-3333-4444444444444444";first.idempotency_key="recovery_share:" & first.request_correlation_id & ":started";
  var second=duplicate(first);second.id="2";second.event_name="recovery_share_succeeded";second.idempotency_key="recovery_share:" & first.request_correlation_id & ":succeeded";
  return [first,second];
 }
 private struct function report(required array cohort,array basic=[],array premium=[],array events=[]){return service.reconcile(arguments.cohort,arguments.basic,arguments.premium,arguments.events,variables.cutoff);}
 private struct function p(required numeric id){return {id={value=arguments.id,cfsqltype="cf_sql_integer"}};}
 private numeric function member(){
  var result={};
  queryExecute("INSERT INTO users(fName,lName,email,password,passwordCreated,created) VALUES('Beta','Fixture',:email,:password,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
   {email={value="codex-beta-" & request.betaProgramTestRun & "-" & replace(createUUID(),"-","","all") & "@example.test",cfsqltype="cf_sql_varchar"},
    password={value=hash(createUUID(),"SHA-256"),cfsqltype="cf_sql_varchar"}},{datasource="fpw",result="result"});
  return val(result.generatedKey);
 }
}
