component extends="testbox.system.BaseSpec" output=false {
 function run() {
  describe("Optional beta feedback reuses enrolled session identity",function() {
   beforeEach(function() {
    if(!structKeyExists(request,"betaProgramTestRun")) throw(type="BetaTest.Scope");
    variables.hadUser=structKeyExists(session,"user");variables.savedUser=variables.hadUser ? duplicate(session.user) : {};
    variables.service=new fpw.api.v1.BetaFeedbackService().init("fpw");
    variables.beta=new fpw.api.v1.BetaProgramService().init("fpw");
    variables.adminId=createMember();variables.memberId=createMember();variables.otherId=createMember();
    queryExecute("INSERT INTO member_entitlements(user_id,entitlement_type,source,status,starts_at_utc) VALUES(:id,'admin','beta_test','active',UTC_TIMESTAMP())",p(adminId),{datasource="fpw"});
    session.user={userId=memberId};
   });
   afterEach(function(){if(variables.hadUser) session.user=variables.savedUser;else structDelete(session,"user");});
   it("leaves anonymous and nonbeta contact submissions outside beta storage",function() {
    structDelete(session,"user");
    expect(service.recordForCurrentSession("Other","Anonymous message",createUUID()).stored).toBeFalse();
    session.user={userId=memberId};
    expect(service.recordForCurrentSession("Other","Nonbeta message",createUUID()).stored).toBeFalse();
    expect(countRows()).toBe(0);
   });
   it("does not store feedback for an invitation that has not been accepted",function() {
    beta.inviteMember(adminId,memberId,"existing_member");
    expect(service.recordForCurrentSession("Other","Invited message",createUUID()).stored).toBeFalse();
    expect(countRows()).toBe(0);
   });
   it("uses only server session identity and records category text UTC and NEW state",function() {
    enroll(memberId);form.userId=otherId;
    try {
     var saved=service.recordForCurrentSession("Bug Report","A disposable beta issue.",createUUID());
     expect(saved.stored).toBeTrue();expect(saved.duplicate).toBeFalse();
     var row=owned(saved.id);
     expect(val(row.user_id[1])).toBe(memberId);
     expect(row.category[1]).toBe("Bug Report");expect(row.description[1]).toBe("A disposable beta issue.");
     expect(row.status[1]).toBe("NEW");expect(isDate(row.submitted_at_utc[1])).toBeTrue();
     expect(countRows()).toBe(1);
    } finally {structDelete(form,"userId");}
   });
   it("deduplicates a repeated member submission without changing its original content",function() {
    enroll(memberId);var key=createUUID();
    var first=service.recordForCurrentSession("Other","First content",key);
    var replay=service.recordForCurrentSession("Bug Report","Changed retry content",lCase(key));
    expect(replay.id).toBe(first.id);expect(replay.duplicate).toBeTrue();
    expect(countRows()).toBe(1);expect(owned(first.id).description[1]).toBe("First content");
    expect(owned(first.id).category[1]).toBe("Other");
   });
   it("scopes submission identity to each enrolled member",function() {
    enroll(memberId);enroll(otherId);var key=createUUID();
    var first=service.recordForCurrentSession("Other","First member",key);
    session.user={userId=otherId};
    var second=service.recordForCurrentSession("Other","Second member",key);
    expect(second.id).notToBe(first.id);expect(countRows()).toBe(2);
   });
   it("accepts the previous form without a submission key",function() {
    enroll(memberId);expect(service.recordForCurrentSession("Trip Planning","Legacy form content").stored).toBeTrue();
    expect(countRows()).toBe(1);
   });
   it("ignores future submissions from withdrawn participants",function() {
    enroll(memberId);var first=service.recordForCurrentSession("Other","Before withdrawal",createUUID());
    beta.withdraw(memberId);
    expect(service.recordForCurrentSession("Other","After withdrawal",createUUID()).stored).toBeFalse();
    expect(countRows()).toBe(1);expect(owned(first.id).description[1]).toBe("Before withdrawal");
   });
   it("rejects unsupported categories",function() {
    enroll(memberId);
    expect(function(){service.recordForCurrentSession("Unapproved","Description",createUUID());}).toThrow("FPW.BetaFeedback.Validation");
   });
   it("rejects descriptions beyond the existing 5000 character limit",function() {
    enroll(memberId);
    expect(function(){service.recordForCurrentSession("Other",repeatString("x",5001),createUUID());}).toThrow("FPW.BetaFeedback.Validation");
   });
   it("rejects blank descriptions",function() {
    enroll(memberId);
    expect(function(){service.recordForCurrentSession("Other","  ",createUUID());}).toThrow("FPW.BetaFeedback.Validation");
   });
   it("rejects malformed provided submission keys",function() {
    enroll(memberId);
    expect(function(){service.recordForCurrentSession("Other","Description","spoofed-key");}).toThrow("FPW.BetaFeedback.Validation");
   });
   it("restricts reading and status changes to administrators and audits only status",function() {
    enroll(memberId);var saved=service.recordForCurrentSession("Other","Private issue text",createUUID());
    expect(function(){service.getFeedback(memberId);}).toThrow();
    expect(function(){service.updateStatus(memberId,saved.id,"RESOLVED");}).toThrow();
    service.updateStatus(adminId,saved.id,"REVIEWED");service.updateStatus(adminId,saved.id,"RESOLVED");
    expect(owned(saved.id).status[1]).toBe("RESOLVED");
    var audit=queryExecute("SELECT previous_values_json,new_values_json FROM fpw_admin_audit_log WHERE admin_user_id=:id AND action='beta_feedback_status'",p(adminId),{datasource="fpw"});
    expect(audit.recordCount).toBe(2);
    expect(find("Private issue text",serializeJSON(audit))).toBe(0);
    var visible=service.getFeedback(adminId);var found=false;
    for(var row in visible) if(val(row.id)==saved.id) found=true;
    expect(found).toBeTrue();
    service.updateStatus(adminId,saved.id,"RESOLVED");
    expect(queryExecute("SELECT COUNT(*) n FROM fpw_admin_audit_log WHERE admin_user_id=:id AND action='beta_feedback_status'",p(adminId),{datasource="fpw"}).n[1]).toBe(2);
   });
   it("rejects unsupported status without mutating the record",function() {
    enroll(memberId);var saved=service.recordForCurrentSession("Other","Issue",createUUID());
    expect(function(){service.updateStatus(adminId,saved.id,"DELETED");}).toThrow("FPW.BetaFeedback.Validation");
    expect(owned(saved.id).status[1]).toBe("NEW");
   });
   it("retains a stored issue independently of a subsequent transport failure",function() {
    enroll(memberId);
    var saved=service.recordForCurrentSession("Other","Stored before transport",createUUID());
    try {throw(type="BetaTest.SimulatedTransportFailure");}catch(BetaTest.SimulatedTransportFailure expected) {}
    expect(owned(saved.id).description[1]).toBe("Stored before transport");
   });
  });
 }
 private void function enroll(required numeric userId) {beta.inviteMember(adminId,arguments.userId,"existing_member");beta.accept(arguments.userId);}
 private struct function p(required numeric id) {return {id={value=arguments.id,cfsqltype="cf_sql_integer"}};}
 private query function owned(required numeric id) {return queryExecute("SELECT * FROM fpw_beta_feedback WHERE id=:id",p(arguments.id),{datasource="fpw"});}
 private numeric function countRows() {
  return val(queryExecute("SELECT COUNT(*) n FROM fpw_beta_feedback WHERE user_id IN (:ids)",
   {ids={value=memberId & "," & otherId,cfsqltype="cf_sql_integer",list=true}},{datasource="fpw"}).n[1]);
 }
 private numeric function createMember() {
  var result={};
  queryExecute("INSERT INTO users(fName,lName,email,password,passwordCreated,created) VALUES('Beta','Feedback Fixture',:email,:password,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
   {email={value="codex-beta-" & request.betaProgramTestRun & "-" & replace(createUUID(),"-","","all") & "@example.test",cfsqltype="cf_sql_varchar"},
    password={value=hash(createUUID(),"SHA-256"),cfsqltype="cf_sql_varchar"}},{datasource="fpw",result="result"});
  return val(result.generatedKey);
 }
}
