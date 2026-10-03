component extends="testbox.system.BaseSpec" output=false {
 function run() {
  describe("Recovery Center settings, member controls and one-time reset",function() {
   beforeEach(function(){try{setup();}catch(any failed){cleanup();rethrow;}});
   afterEach(function(){cleanup();});
   it("validates independent integer timing values and rejects malformed hours",function(){
    var valid=variables.settings.validate({firstDelayHours=12,stageIntervalHours=36,attributionWindowHours=72});
    expect(valid.firstDelayHours).toBe(12);expect(valid.stageIntervalHours).toBe(36);expect(valid.attributionWindowHours).toBe(72);
    for(var value in ["",0,-1,721,1.5,"24 hours","1e2","24.0"]) {
     var candidate={firstDelayHours=value,stageIntervalHours=24,attributionWindowHours=24};
     expect(function(){variables.settings.validate(candidate);}).toThrow("FPW.Recovery.Settings");
    }
    expect(function(){variables.settings.validate({firstDelayHours=24,stageIntervalHours=24});}).toThrow();
   });
   it("has database-backed 24 hour defaults and no indefinitely cached configuration",function(){
    transaction {
     try {
      queryExecute("UPDATE inactive_member_recovery_settings SET first_delay_hours=24,stage_interval_hours=24,attribution_window_hours=24 WHERE id=1",{}, {datasource="fpw"});
      var current=variables.settings.getSettings();
      expect(current.firstDelayHours).toBe(24);expect(current.stageIntervalHours).toBe(24);expect(current.attributionWindowHours).toBe(24);
      queryExecute("UPDATE inactive_member_recovery_settings SET first_delay_hours=12 WHERE id=1",{}, {datasource="fpw"});
      expect(variables.settings.getSettings().firstDelayHours).toBe(12);
      expect(new fpw.includes.InactiveMemberRecoverySettingsService().getSettings().firstDelayHours).toBe(12);
     } finally {transaction action="rollback";}
    }
   });
   it("fails closed when the required settings singleton is unavailable",function(){
    transaction {
     try {queryExecute("DELETE FROM inactive_member_recovery_settings WHERE id=1",{}, {datasource="fpw"});
      expect(function(){variables.settings.getSettings();}).toThrow("FPW.Recovery.Settings");
     } finally {transaction action="rollback";}
    }
   });
   it("previews exact current and proposed eligibility without any writes",function(){
    var before=counts();
    var proposed={firstDelayHours=1,stageIntervalHours=12,attributionWindowHours=72};
    var impact=variables.admin.previewImpact(proposed);
    var found={};for(var row in impact.rows) if(row.userId EQ variables.memberId) found=row;
    expect(structIsEmpty(found)).toBeFalse();
    expect(found.destinationStage).toBe("A");expect(found.contactNumber).toBe(1);
    expect(found.priorDecision).toBe("DEFERRED_WAITING_FOR_INTERVAL");expect(found.nextDecision).toBe("ELIGIBLE");
    expect(impact.newlyImmediate GTE 1).toBeTrue();expect(impact.earlier GTE 1).toBeTrue();
    expect(dateDiff("h",parseDateTime(replace(replace(found.after,"T"," "),"Z","")),parseDateTime(replace(replace(found.before,"T"," "),"Z","")))).toBe(23);
    expect(serializeJSON(counts())).toBe(serializeJSON(before));
   });
   it("saves timing and old/new audit atomically without sending or resetting enrollment",function(){
    var original=variables.enrollment.getEnrollment(variables.memberId);
    var baseline=counts();
    transaction {
     try {
      var proposed={firstDelayHours=12,stageIntervalHours=36,attributionWindowHours=72};
      var impact=variables.admin.previewImpact(proposed);
      var saved=variables.admin.saveSettings({proposed=proposed,fingerprint=impact.fingerprint},variables.actorId);
      expect(saved.firstDelayHours).toBe(12);expect(saved.stageIntervalHours).toBe(36);expect(saved.attributionWindowHours).toBe(72);
      var audit=queryExecute("SELECT previous_values_json,new_values_json FROM fpw_admin_audit_log WHERE admin_user_id=:id AND action='recovery_settings_saved'",p(variables.actorId),{datasource="fpw"});
      expect(audit.recordCount).toBe(1);expect(deserializeJSON(audit.new_values_json[1]).stageIntervalHours).toBe(36);
      expect(counts().messages).toBe(baseline.messages);expect(counts().deliveries).toBe(baseline.deliveries);
      expect(variables.enrollment.getEnrollment(variables.memberId).EVENT_ID).toBe(original.EVENT_ID);
     } finally {transaction action="rollback";}
    }
   });
   it("rejects a stale settings confirmation without partial changes or audit",function(){
    var proposed={firstDelayHours=12,stageIntervalHours=36,attributionWindowHours=72};
    var before=variables.settings.getSettings();var baseline=counts();
    expect(function(){variables.admin.saveSettings({proposed=proposed,fingerprint="stale"},variables.actorId);}).toThrow();
    expect(serializeJSON(variables.settings.getSettings())).toBe(serializeJSON(before));
    expect(serializeJSON(counts())).toBe(serializeJSON(baseline));
   });
   it("rolls back a timing change if its required administrator audit fails",function(){
    var broken=prepareMock(new fpw.api.v1.AdminRecoveryCenterService());
    makePublic(broken,"saveSettings");makePublic(broken,"audit");
    broken.$("audit").$throws(type="tests.RequiredAuditFailure",message="CONTROLLED_AUDIT_FAILURE");
    var proposed={firstDelayHours=12,stageIntervalHours=36,attributionWindowHours=72};
    var impact=variables.admin.previewImpact(proposed);var before=variables.settings.getSettings();
    expect(function(){broken.saveSettings({proposed=proposed,fingerprint=impact.fingerprint},variables.actorId);}).toThrow("tests.RequiredAuditFailure");
    expect(serializeJSON(variables.settings.getSettings())).toBe(serializeJSON(before));
   });
   it("keeps pause and exclusion independent and preserves timing/contact history",function(){
    var original=variables.state.getState(variables.memberId);
    variables.admin.changeState(variables.memberId,"pause",variables.actorId);
    variables.admin.changeState(variables.memberId,"exclude",variables.actorId);
    variables.admin.changeState(variables.memberId,"resume",variables.actorId);
    var state=variables.state.getState(variables.memberId);expect(state.paused).toBeFalse();expect(state.excluded).toBeTrue();
    expect(state.recoveryStartUtc).toBe(original.recoveryStartUtc);expect(state.enrollmentEventId).toBe(original.enrollmentEventId);
    variables.admin.changeState(variables.memberId,"remove_exclusion",variables.actorId);
    state=variables.state.getState(variables.memberId);expect(state.excluded).toBeFalse();
    expect(new fpw.includes.InactiveMemberRecoveryLedgerService().getSequenceState(variables.memberId).NEXT_CONTACT_NUMBER).toBe(1);
    expect(queryExecute("SELECT COUNT(*) n FROM product_events WHERE user_id=:id AND event_source='recovery_admin'",p(variables.memberId),{datasource="fpw"}).n[1]).toBe(4);
    expect(queryExecute("SELECT COUNT(*) n FROM fpw_admin_audit_log WHERE admin_user_id=:id AND entity_type='user'",p(variables.actorId),{datasource="fpw"}).n[1]).toBe(4);
   });
   it("rolls back a member state change if its required audit fails",function(){
    var broken=prepareMock(new fpw.api.v1.AdminRecoveryCenterService());makePublic(broken,"changeState");makePublic(broken,"audit");
    broken.$("audit").$throws(type="tests.RequiredAuditFailure",message="CONTROLLED_AUDIT_FAILURE");
    expect(function(){broken.changeState(variables.memberId,"pause",variables.actorId);}).toThrow("tests.RequiredAuditFailure");
    expect(variables.state.getState(variables.memberId).paused).toBeFalse();
    expect(queryExecute("SELECT COUNT(*) n FROM inactive_member_recovery_member_state WHERE user_id=:id",p(variables.memberId),{datasource="fpw"}).n[1]).toBe(0);
   });
   it("reports corrupt enrollment as a held unknown state without a false contact or queue error",function(){
    queryExecute("UPDATE product_events SET metadata_json='{""unexpected"":true}' WHERE user_id=:id AND event_name='inactive_member_recovery_enrolled'",p(variables.memberId),{datasource="fpw"});
    makePublic(variables.admin,"memberRow");
    var row=variables.admin.memberRow(variables.memberId);
    expect(row.stateVerified).toBeFalse();expect(row.paused).toBe("Unknown");expect(row.excluded).toBe("Unknown");
    expect(row.decision).toBe("HELD");expect(row.sequenceComplete).toBeFalse();expect(row.contactNumber).toBe(0);
    makePublic(variables.admin,"listMembers");makePublic(variables.admin,"dashboard");
    expect(isArray(variables.admin.listMembers({status="paused"}).rows)).toBeTrue();
    expect(isStruct(variables.admin.dashboard().metrics)).toBeTrue();
   });
   it("rejects a state row bound to another member enrollment",function(){
    var other=createMember(true);
    var foreignEnrollment=variables.enrollment.getEnrollment(other);
    queryExecute("INSERT INTO inactive_member_recovery_member_state(user_id,recovery_enrollment_event_id,paused,excluded,updated_at_utc)
      VALUES(:id,:event,1,0,UTC_TIMESTAMP())",
      {id={value=variables.memberId,cfsqltype="cf_sql_integer"},event={value=foreignEnrollment.EVENT_ID,cfsqltype="cf_sql_bigint"}},{datasource="fpw"});
    expect(function(){variables.state.getState(variables.memberId);}).toThrow("FPW.Recovery.State");
   });
   it("resets the existing cohort to one shared T0 without altering enrollment evidence",function(){
    var cohort=variables.admin.resetCohort();var original=queryExecute("SELECT id,occurred_at_utc,created_at_utc,metadata_json FROM product_events WHERE event_name='inactive_member_recovery_enrolled' ORDER BY id",{}, {datasource="fpw"});
    var baseline=counts();
    transaction isolation="serializable" {
     try {
      var reset=variables.admin.resetStart({fingerprint=hash(serializeJSON(cohort),"SHA-256")},variables.actorId);
      expect(reset.resetCohortCount).toBe(arrayLen(cohort));expect(len(reset.resetAtUtc) GT 0).toBeTrue();
      var clocks=queryExecute("SELECT COUNT(DISTINCT recovery_start_at_utc) n,COUNT(*) total,MAX(MICROSECOND(recovery_start_at_utc)) fractions FROM inactive_member_recovery_member_state WHERE reset_operation_id=(SELECT reset_operation_id FROM inactive_member_recovery_settings WHERE id=1)",{}, {datasource="fpw"});
      expect(clocks.n[1]).toBe(1);expect(clocks.total[1]).toBe(arrayLen(cohort));expect(clocks.fractions[1]).toBe(0);
      expect(serializeJSON(queryExecute("SELECT id,occurred_at_utc,created_at_utc,metadata_json FROM product_events WHERE event_name='inactive_member_recovery_enrolled' ORDER BY id",{}, {datasource="fpw"}))).toBe(serializeJSON(original));
      var state=variables.state.getState(variables.memberId);expect(state.recoveryStartUtc).toBe(reset.resetAtUtc);
      var classifier=new fpw.includes.InactiveMemberRecoveryClassifierService();
      var before=new fpw.includes.InactiveMemberRecoveryCoverageService().getCoverageVerification(variables.memberId);
      expect(before.stage_history).toBeTrue();
      var now=queryExecute("SELECT DATE_FORMAT(UTC_TIMESTAMP(),'%Y-%m-%dT%H:%i:%sZ') t",{}, {datasource="fpw"}).t[1];
      var evaluation=classifier.evaluateMember(userId=variables.memberId,nowUtc=now,coverageVerification=before);
      expect(evaluation.CONTACT_NUMBER).toBe(1);expect(evaluation.CURRENT_STAGE).toBe("A");expect(evaluation.DECISION).toBe("DEFERRED");
      expect(counts().deliveries).toBe(baseline.deliveries);expect(counts().messages).toBe(baseline.messages);
      expect(function(){variables.admin.resetCohort();}).toThrow();
      // New signup is tested separately under its normal read_committed transaction.
      // CF rejects nesting that transaction inside this reset's serializable rollback wrapper.
     } finally {transaction action="rollback";}
    }
    expect(len(variables.settings.getSettings().resetAtUtc)).toBe(0);
   });
   it("uses a new signup's own enrollment after the one-time reset has completed",function(){
    transaction isolation="read_committed" {
     try {
      queryExecute("UPDATE inactive_member_recovery_settings SET reset_at_utc=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 HOUR),reset_operation_id=:operation WHERE id=1",
       {operation={value=createUUID(),cfsqltype="cf_sql_char"}},{datasource="fpw"});
      var later=createMember(true);
      var laterState=variables.state.getState(later);var laterEnrollment=variables.enrollment.getEnrollment(later);
      expect(laterState.recoveryStartUtc).toBe(laterEnrollment.ENROLLMENT_UTC);
      expect(laterState.recoveryStartUtc GT variables.settings.getSettings().resetAtUtc).toBeTrue();
      expect(queryExecute("SELECT COUNT(*) n FROM inactive_member_recovery_member_state WHERE user_id=:id",p(later),{datasource="fpw"}).n[1]).toBe(0);
     } finally {transaction action="rollback";}
    }
   });
   it("rejects reset when any delivery history or unresolved claim exists",function(){
    var enrollment=variables.enrollment.getEnrollment(variables.memberId);
    var claim=new fpw.includes.InactiveMemberRecoveryLedgerService().claimContact(variables.memberId,enrollment.EVENT_ID,1,"A");
    expect(claim.CLAIMED).toBeTrue();
    expect(function(){variables.admin.resetCohort();}).toThrow();
   });
   it("rejects stale cohort confirmation and rolls back reset if required audit fails",function(){
    var baseline=counts();var before=variables.settings.getSettings();
    expect(function(){variables.admin.resetStart({fingerprint="stale"},variables.actorId);}).toThrow();
    expect(serializeJSON(counts())).toBe(serializeJSON(baseline));
    var broken=prepareMock(new fpw.api.v1.AdminRecoveryCenterService());makePublic(broken,"resetStart");makePublic(broken,"audit");
    broken.$("audit").$throws(type="tests.RequiredAuditFailure",message="CONTROLLED_AUDIT_FAILURE");
    var cohort=variables.admin.resetCohort();
    expect(function(){broken.resetStart({fingerprint=hash(serializeJSON(cohort),"SHA-256")},variables.actorId);}).toThrow("tests.RequiredAuditFailure");
    expect(serializeJSON(counts())).toBe(serializeJSON(baseline));
    expect(serializeJSON(variables.settings.getSettings())).toBe(serializeJSON(before));
   });
  });
 }
 private void function setup(){
  variables.ids=[];variables.actorId=0;
  variables.settings=new fpw.includes.InactiveMemberRecoverySettingsService();
  variables.enrollment=new fpw.includes.InactiveMemberRecoveryEnrollmentService();
  variables.state=new fpw.includes.InactiveMemberRecoveryStateService();
  variables.actorId=createMember(false);variables.memberId=createMember(true);
  queryExecute("INSERT INTO member_entitlements(user_id,entitlement_type,source,status,starts_at_utc,expires_at_utc,created_utc,updated_utc)
    VALUES(:id,'admin','recovery_center_test','active',DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 DAY),DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 DAY),UTC_TIMESTAMP(),UTC_TIMESTAMP())",p(variables.actorId),{datasource="fpw"});
  expect(new fpw.api.v1.AdminAuthorizationService().authorizeCurrentSession({userId=variables.actorId}).authorized).toBeTrue();
  queryExecute("UPDATE product_events SET occurred_at_utc=DATE_SUB(occurred_at_utc,INTERVAL 2 HOUR),created_at_utc=DATE_SUB(created_at_utc,INTERVAL 2 HOUR) WHERE user_id=:id",p(variables.memberId),{datasource="fpw"});
  variables.admin=new fpw.api.v1.AdminRecoveryCenterService();
  for(var method in ["previewImpact","saveSettings","changeState","resetCohort","resetStart"]) makePublic(variables.admin,method);
 }
 private numeric function createMember(required boolean enroll){
  var inserted={};
  transaction {
   queryExecute("INSERT INTO users(fName,lName,email,password,passwordCreated,created) VALUES('Recovery','Settings',:email,:password,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
    {email={value="codex-recovery-settings-" & lCase(replace(createUUID(),"-","","all")) & "@example.test",cfsqltype="cf_sql_varchar"},
     password={value=hash(createUUID(),"SHA-256"),cfsqltype="cf_sql_varchar"}},{datasource="fpw",result="inserted"});
   var id=val(inserted.generatedKey);arrayAppend(variables.ids,id);
   new fpw.includes.InactiveMemberRecoveryCoverageService().recordSignupInCurrentTransaction(id,{signup_method="password",account_tier="basic"});
   if(arguments.enroll){
    var result=variables.enrollment.ensureEnrolled(id);
    if(!result.SUCCESS OR !len(result.ENROLLMENT_UTC)) throw(type="tests.Fixture",message="CANONICAL_ENROLLMENT_FAILED",detail=serializeJSON(result));
   }
  }
  return id;
 }
 private struct function counts(){
  var q=queryExecute("SELECT
   (SELECT COUNT(*) FROM inactive_member_recovery_deliveries) deliveries,
   (SELECT COUNT(*) FROM inactive_member_recovery_messages) messages,
   (SELECT COUNT(*) FROM inactive_member_recovery_evaluations) evaluations,
   (SELECT COUNT(*) FROM inactive_member_recovery_runs) runs,
   (SELECT COUNT(*) FROM inactive_member_recovery_member_state) states,
   (SELECT COUNT(*) FROM product_events) events,
   (SELECT COUNT(*) FROM fpw_admin_audit_log) audits",{}, {datasource="fpw"});
  return {deliveries=q.deliveries[1],messages=q.messages[1],evaluations=q.evaluations[1],runs=q.runs[1],states=q.states[1],events=q.events[1],audits=q.audits[1]};
 }
 private struct function p(required numeric id){return {id={value=arguments.id,cfsqltype="cf_sql_integer"}};}
 private void function cleanup(){
  if(!structKeyExists(variables,"ids")) return;
  for(var id in variables.ids){
   for(var statement in [
    "DELETE FROM inactive_member_recovery_messages WHERE user_id=:id",
    "DELETE FROM inactive_member_recovery_evaluations WHERE user_id=:id",
    "DELETE FROM inactive_member_recovery_deliveries WHERE user_id=:id",
    "DELETE FROM inactive_member_recovery_member_state WHERE user_id=:id",
    "DELETE FROM product_events WHERE user_id=:id",
    "DELETE FROM member_entitlements WHERE user_id=:id",
    "DELETE FROM fpw_admin_audit_log WHERE admin_user_id=:id",
    "DELETE FROM users WHERE userId=:id"]) queryExecute(statement,p(id),{datasource="fpw"});
  }
 }
}
