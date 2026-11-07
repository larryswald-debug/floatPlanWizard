component extends="testbox.system.BaseSpec" output=false {
 function run() {
  describe("Founding Beta participation remains independent of access",function() {
   beforeEach(function() {
    if (!structKeyExists(request,"betaProgramTestRun")) throw(type="BetaTest.Scope",message="Use the local beta-program runner.");
    variables.service=new fpw.api.v1.BetaProgramService().init("fpw");
    variables.adminId=createMember();variables.memberId=createMember();variables.otherId=createMember();
    grant(variables.adminId,"admin");
   });
   it("records an invitation without enrollment or Premium access",function() {
    service.inviteMember(adminId,memberId,"existing_member");
    var record=service.getParticipation(memberId);
    expect(record.recordCount).toBe(1);
    expect(record.status[1]).toBe("INVITED");
    expect(record.recruitment_source[1]).toBe("existing_member");
    expect(isDate(record.invited_at_utc[1])).toBeTrue();
    expect(toString(record.enrolled_at_utc[1])).toBe("");
    expect(accessCount(memberId)).toBe(0);
    expect(queryExecute("SELECT COUNT(*) n FROM fpw_admin_audit_log WHERE admin_user_id=:id",
      p(adminId),{datasource="fpw"}).n[1]).toBeGT(0);
   });
   it("rejects acceptance without an invitation",function() {
    expect(function(){service.accept(memberId);}).toThrow();
   });
   it("requires explicit acceptance and enrolls a member without Premium",function() {
    service.inviteMember(adminId,memberId,"mailing_list");
    service.accept(memberId);
    var record=service.getParticipation(memberId);
    expect(record.status[1]).toBe("ENROLLED");
    expect(isDate(record.enrolled_at_utc[1])).toBeTrue();
    expect(len(toString(record.acceptance_version[1]))).toBeGT(0);
    expect(accessCount(memberId)).toBe(0);
   });
   it("does not count an entitlement grant as beta enrollment",function() {
    grant(memberId,"premium");
    expect(accessCount(memberId)).toBe(1);
    expect(service.getParticipation(memberId).recordCount).toBe(0);
   });
   it("preserves invitation source and timestamp on duplicate requests",function() {
    service.inviteMember(adminId,memberId,"existing_member");
    var first=service.getParticipation(memberId);
    service.inviteMember(adminId,memberId,"other");
    var replay=service.getParticipation(memberId);
    expect(replay.recordCount).toBe(1);
    expect(replay.recruitment_source[1]).toBe(first.recruitment_source[1]);
    expect(serializeJSON(replay.invited_at_utc[1])).toBe(serializeJSON(first.invited_at_utc[1]));
   });
   it("preserves the first enrollment timestamp on repeated acceptance",function() {
    service.inviteMember(adminId,memberId,"existing_member");service.accept(memberId);
    var first=service.getParticipation(memberId);
    service.accept(memberId);
    var replay=service.getParticipation(memberId);
    expect(replay.recordCount).toBe(1);
    expect(serializeJSON(replay.enrolled_at_utc[1])).toBe(serializeJSON(first.enrolled_at_utc[1]));
    expect(replay.acceptance_version[1]).toBe(first.acceptance_version[1]);
    expect(accessCount(memberId)).toBe(0);
   });
   it("links only an entitlement owned by the invited member",function() {
    var owned=grant(memberId,"premium");
    service.inviteMember(adminId,memberId,"existing_member",owned);
    expect(val(service.getParticipation(memberId).entitlement_id[1])).toBe(owned);
    expect(accessCount(memberId)).toBe(1);
   });
   it("rejects another member's promotional entitlement",function() {
    var foreign=grant(otherId,"premium");
    expect(function(){service.inviteMember(adminId,memberId,"existing_member",foreign);}).toThrow();
   });
   it("rejects nonadministrator invitations and invalid recruitment sources",function() {
    expect(function(){service.inviteMember(otherId,memberId,"existing_member");}).toThrow();
    expect(function(){service.inviteMember(adminId,memberId,"unapproved_source");}).toThrow();
    expect(service.getParticipation(memberId).recordCount).toBe(0);
   });
   it("rejects withdrawal before acceptance",function() {
    service.inviteMember(adminId,memberId,"existing_member");
    expect(function(){service.withdraw(memberId);}).toThrow();
   });
   it("preserves enrollment history and terminal withdrawal",function() {
    service.inviteMember(adminId,memberId,"existing_member");
    service.accept(memberId);
    var enrolled=service.getParticipation(memberId);
    service.withdraw(memberId);
    var first=service.getParticipation(memberId);
    expect(first.status[1]).toBe("WITHDRAWN");
    expect(isDate(first.withdrawn_at_utc[1])).toBeTrue();
    expect(serializeJSON(first.enrolled_at_utc[1])).toBe(serializeJSON(enrolled.enrolled_at_utc[1]));
    service.withdraw(memberId);
    expect(serializeJSON(service.getParticipation(memberId).withdrawn_at_utc[1])).toBe(serializeJSON(first.withdrawn_at_utc[1]));
    expect(service.getParticipation(memberId).status[1]).toBe("WITHDRAWN");
    expect(accessCount(memberId)).toBe(0);
    expect(function(){service.accept(memberId);}).toThrow();
   });
   it("rejects re-inviting a withdrawn participant without silently reenrolling",function() {
    service.inviteMember(adminId,memberId,"existing_member");service.accept(memberId);service.withdraw(memberId);
    expect(function(){service.inviteMember(adminId,memberId,"other");}).toThrow();
   });
   it("withdrawal never revokes existing Premium access",function() {
    var entitlement=grant(memberId,"premium");
    service.inviteMember(adminId,memberId,"existing_member",entitlement);service.accept(memberId);service.withdraw(memberId);
    expect(accessCount(memberId)).toBe(1);
    expect(queryExecute("SELECT status FROM member_entitlements WHERE id=:id",p(entitlement),{datasource="fpw"}).status[1]).toBe("active");
   });
  });
 }
 private struct function p(required numeric id) {return {id={value=arguments.id,cfsqltype="cf_sql_integer"}};}
 private numeric function createMember() {
  var result={};
  queryExecute("INSERT INTO users(fName,lName,email,password,passwordCreated,created)
    VALUES('Beta','Fixture',:email,:password,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
    {email={value="codex-beta-" & request.betaProgramTestRun & "-" & replace(createUUID(),"-","","all") & "@example.test",cfsqltype="cf_sql_varchar"},
     password={value=hash(createUUID(),"SHA-256"),cfsqltype="cf_sql_varchar"}},{datasource="fpw",result="result"});
  return val(result.generatedKey);
 }
 private numeric function grant(required numeric userId,required string entitlementType) {
  var result={};
  var promo=0;
  if (arguments.entitlementType EQ "premium") {
   queryExecute("INSERT INTO fpw_promo_codes(code_hash,internal_name,promo_type,starts_at_utc) VALUES(:code,'Disposable Beta Fixture','admin_grant',UTC_TIMESTAMP())",
    {code={value=hash(createUUID(),"SHA-256"),cfsqltype="cf_sql_char"}},{datasource="fpw",result="result"});
   promo=val(result.generatedKey);
  }
  queryExecute("INSERT INTO member_entitlements(user_id,entitlement_type,source,status,starts_at_utc,expires_at_utc,promo_code_id)
    VALUES(:id,:kind,'beta_test','active',DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 DAY),DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 DAY),:promo)",
    {id={value=arguments.userId,cfsqltype="cf_sql_integer"},kind={value=arguments.entitlementType,cfsqltype="cf_sql_varchar"},promo={value=promo,cfsqltype="cf_sql_bigint",null=promo EQ 0}},
    {datasource="fpw",result="result"});
  return val(result.generatedKey);
 }
 private numeric function accessCount(required numeric userId) {
  return val(queryExecute("SELECT COUNT(*) n FROM member_entitlements WHERE user_id=:id AND entitlement_type='premium' AND status='active'",p(arguments.userId),{datasource="fpw"}).n[1]);
 }
}
