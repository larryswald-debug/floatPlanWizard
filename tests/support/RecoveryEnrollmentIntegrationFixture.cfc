component extends="fpw.tests.support.RecoveryReadinessFixture" output="false" {
  public struct function prepare(required string password,boolean recoveryCenter=false) {
    var m={};
    transaction {
      m.admin=createMember(); admin(m.admin.userId);
      m.member=createMember();
      for (var stage in ["A","B","C","D"]) m[stage]=createMember(stage);
      m.already=createMember();
      new fpw.includes.InactiveMemberRecoveryEnrollmentService().ensureEnrolled(m.already.userId);
      m.shared=createMember("D");share(m.shared.userId,"basic");
      m.opted=createMember();optOut(m.opted.userId);
      m.invalid=createMember();
      queryExecute("UPDATE users SET email='invalid' WHERE userId=:id",p(m.invalid.userId),{datasource="fpw"});
      m.deleted=createMember();
      queryExecute("DELETE FROM users WHERE userId=:id",p(m.deleted.userId),{datasource="fpw"});
      m.covered=fresh();
      m.corrupt=fresh();
      queryExecute("UPDATE product_events SET metadata_json=JSON_OBJECT('contract_version','v99') WHERE user_id=:id AND event_name='recovery_coverage_started'",p(m.corrupt.userId),{datasource="fpw"});
      if(arguments.recoveryCenter) {
        m.center=fresh();
        new fpw.includes.InactiveMemberRecoveryEnrollmentService().ensureEnrolled(m.center.userId);
      }
      m.race=createMember();
      m.concurrent=createMember();
      queryExecute("UPDATE users SET password=:password WHERE userId IN (:ids)",
        {password={value=hash(arguments.password,"SHA-256","UTF-8"),cfsqltype="cf_sql_varchar"},
         ids={value=arrayToList(getCandidateIds(100)),cfsqltype="cf_sql_integer",list=true}},{datasource="fpw"});
    }
    return m;
  }
  public numeric function seedPagination(required numeric userId,required numeric adminUserId) {
    if(!arrayFind(getCandidateIds(100),arguments.userId) OR !arrayFind(getCandidateIds(100),arguments.adminUserId)) throw(message="FIXTURE_MEMBER_REQUIRED");
    var enrollment=queryExecute("SELECT id FROM product_events WHERE user_id=:id AND event_name='inactive_member_recovery_enrolled'",p(arguments.userId),{datasource="fpw"});
    if(enrollment.recordCount NEQ 1) throw(message="FIXTURE_ENROLLMENT_REQUIRED");
    var observer=new fpw.includes.InactiveMemberRecoveryObservabilityService();
    var runId=observer.beginRun("pagination_fixture",true,{revision=1});
    for(var n=1;n LTE 26;n++) {
      observer.recordEvaluation(runId,arguments.userId,{CURRENT_STAGE="A",CONTACT_NUMBER=1,ELIGIBLE=false,DECISION="DEFERRED",DECISION_CODE="DEFERRED_WAITING_FOR_INTERVAL",ENROLLMENT_EVENT_ID=enrollment.id[1]});
      observer.prepareMessage({runId=runId,userId=arguments.userId,enrollmentEventId=enrollment.id[1],contactNumber=1,destinationStage="A",
        destinationPath="/app/dashboard.cfm?recoveryAction=vessel",settings={revision=1,attributionWindowHours=24}},
        {success=true,messageType="INACTIVE_MEMBER_RECOVERY",subject="Pagination fixture " & n,toEmail=variables.records[toString(arguments.userId)].email,
         ctaLabel="Continue",ctaUrl="http://localhost:8500/fpw/app/dashboard.cfm?recoveryAction=vessel",textBody="Pagination fixture",htmlBody="<p>Pagination fixture</p>"});
      new fpw.api.v1.AdminAuditService().record(actorUserId=arguments.adminUserId,action="recovery_settings_saved",targetType="pagination_fixture",targetId=toString(arguments.userId),success=true);
    }
    observer.finishRun(runId,{ok=true,scanned=26,eligible=0,skipped=26});
    return runId;
  }
  public void function optOut(required numeric userId) {
    if (!arrayFind(getCandidateIds(100),arguments.userId)) throw(message="FIXTURE_MEMBER_REQUIRED");
    new fpw.api.v1.EmailOptOutService().recordOptOut(variables.records[toString(arguments.userId)].email,arguments.userId,"non_essential","enrollment_integration_test");
  }
  public struct function inspect() {
    var result={counts=counts(),members={}};
    var enrollment=new fpw.includes.InactiveMemberRecoveryEnrollmentService();
    var coverage=new fpw.includes.InactiveMemberRecoveryCoverageService();
    for (var id in getCandidateIds(100)) {
      var at=enrollment.getEnrollmentUtc(id);
      var proof=coverage.getCoverageVerification(id);
      result.members[toString(id)]={enrollments=enrollmentCount(id),enrollmentUtc=at,coverage=proof,
        decision=new fpw.includes.InactiveMemberRecoveryClassifierService().evaluateMember(id,len(at) ? plusSeconds(at,604800) : dbUtc()).DECISION_CODE};
    }
    return result;
  }
  public void function cleanup() {
    if (arrayLen(getCandidateIds(100))) {
      var ownedParams={ids={value=arrayToList(getCandidateIds(100)),cfsqltype="cf_sql_integer",list=true}};
      var runs=queryExecute("SELECT DISTINCT run_id FROM inactive_member_recovery_evaluations WHERE user_id IN (:ids)",ownedParams,{datasource="fpw"});
      queryExecute("DELETE FROM inactive_member_recovery_messages WHERE user_id IN (:ids)",ownedParams,{datasource="fpw"});
      queryExecute("DELETE FROM inactive_member_recovery_evaluations WHERE user_id IN (:ids)",ownedParams,{datasource="fpw"});
      queryExecute("DELETE FROM inactive_member_recovery_member_state WHERE user_id IN (:ids)",ownedParams,{datasource="fpw"});
      for(var run in runs) queryExecute("DELETE FROM inactive_member_recovery_runs WHERE id=:run
        AND NOT EXISTS(SELECT 1 FROM inactive_member_recovery_evaluations WHERE run_id=:run)
        AND NOT EXISTS(SELECT 1 FROM inactive_member_recovery_messages WHERE run_id=:run)",
        {run={value=run.run_id,cfsqltype="cf_sql_bigint"}},{datasource="fpw"});
      queryExecute("DELETE FROM fpw_admin_audit_log WHERE admin_user_id IN (:ids)",
        {ids={value=arrayToList(getCandidateIds(100)),cfsqltype="cf_sql_integer",list=true}},{datasource="fpw"});
    }
    super.cleanup();
  }
  private struct function p(required numeric id) {return {id={value=arguments.id,cfsqltype="cf_sql_integer"}};}
}
