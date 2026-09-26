component extends="fpw.tests.support.RecoveryReadinessFixture" output="false" {
  public struct function prepare(required string password) {
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
      m.race=createMember();
      m.concurrent=createMember();
      queryExecute("UPDATE users SET password=:password WHERE userId IN (:ids)",
        {password={value=hash(arguments.password,"SHA-256","UTF-8"),cfsqltype="cf_sql_varchar"},
         ids={value=arrayToList(getCandidateIds(100)),cfsqltype="cf_sql_integer",list=true}},{datasource="fpw"});
    }
    return m;
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
      queryExecute("DELETE FROM fpw_admin_audit_log WHERE admin_user_id IN (:ids)",
        {ids={value=arrayToList(getCandidateIds(100)),cfsqltype="cf_sql_integer",list=true}},{datasource="fpw"});
    }
    super.cleanup();
  }
  private struct function p(required numeric id) {return {id={value=arguments.id,cfsqltype="cf_sql_integer"}};}
}
