component extends="testbox.system.BaseSpec" output="false" {
  function run() {
    describe("Post-commit signup recovery enrollment",function() {
      beforeEach(function() {
        variables.join=prepareMock(new fpw.api.v1.join());
        makePublic(variables.join,"enrollNewMemberForRecovery");
        makePublic(variables.join,"writeRecoveryEnrollmentAudit");
        variables.join.$("writeRecoveryEnrollmentAudit");
      });

      it("passes only the server-created member id to the existing enrollment command",function() {
        var service=new fpw.tests.support.RecoverySignupEnrollmentStub();
        var result=join.enrollNewMemberForRecovery(123,service);
        expect(result.SUCCESS).toBeTrue();expect(result.CODE).toBe("ENROLLED");
        var calls=service.calls();
        expect(arrayLen(calls)).toBe(1);expect(structCount(calls[1])).toBe(1);
        expect(calls[1].userId).toBe(123);
        expect(join.$count("writeRecoveryEnrollmentAudit")).toBe(1);
      });

      it("preserves successful, repeated, and skipped enrollment outcomes",function() {
        for (var code in ["ENROLLED","ALREADY_ENROLLED","NOT_ELIGIBLE_FOR_ENROLLMENT","MEMBER_NOT_FOUND"]) {
          var service=new fpw.tests.support.RecoverySignupEnrollmentStub(result={SUCCESS=true,CODE=code});
          var result=join.enrollNewMemberForRecovery(123,service);
          expect(result.SUCCESS).toBeTrue();expect(result.CODE).toBe(code);
        }
      });

      it("contains service exceptions and exposes only a stable failure code",function() {
        var result=join.enrollNewMemberForRecovery(123,new fpw.tests.support.RecoverySignupEnrollmentStub(fail=true));
        expect(result.SUCCESS).toBeFalse();expect(result.CODE).toBe("ENROLLMENT_FAILED");
        expect(structCount(result)).toBe(2);
        expect(find("PRIVATE_RAW",serializeJSON(result))).toBe(0);
        expect(join.$count("writeRecoveryEnrollmentAudit")).toBe(1);
      });

      it("contains reported failure without propagating raw error fields",function() {
        var service=new fpw.tests.support.RecoverySignupEnrollmentStub(result={SUCCESS=false,CODE="ENROLLMENT_FAILED",DETAIL="PRIVATE_RAW_FAILURE@example.test"});
        var result=join.enrollNewMemberForRecovery(123,service);
        expect(result.SUCCESS).toBeFalse();expect(result.CODE).toBe("ENROLLMENT_FAILED");
        expect(structCount(result)).toBe(2);
      });

      it("treats malformed or unrecognized outcomes as safe enrollment failure",function() {
        for (var reply in ["invalid",{},[],{SUCCESS=true},{SUCCESS=true,CODE=[]},
          {SUCCESS=true,CODE="ENROLLED" & chr(10) & "forged"}, {SUCCESS="invalid",CODE="ENROLLED"},
          {SUCCESS=false,CODE="ENROLLED"},{SUCCESS=true,CODE="ENROLLMENT_FAILED"}]) {
          var service=new fpw.tests.support.RecoverySignupEnrollmentStub(result=reply);
          var result=join.enrollNewMemberForRecovery(123,service);
          expect(result.SUCCESS).toBeFalse();expect(result.CODE).toBe("ENROLLMENT_FAILED");
        }
      });

      it("appends recovery signup results to the same application log",function() {
        var logPath=expandPath("/fpw/logs/fpw_recovery_enrollment.log");
        var before=fileExists(logPath) ? fileRead(logPath,"utf-8") : "";
        var actual=prepareMock(new fpw.api.v1.join());
        makePublic(actual,"writeRecoveryEnrollmentAudit");
        actual.writeRecoveryEnrollmentAudit(0,"ENROLLMENT_FAILED");
        expect(fileExists(logPath)).toBeTrue();
        var after=fileRead(logPath,"utf-8");
        if (len(before)) expect(left(after,len(before))).toBe(before);
        var appended=mid(after,len(before)+1,len(after)-len(before));
        expect(find("join.cfc RECOVERY_ENROLLMENT | userId=0 | code=ENROLLMENT_FAILED",appended)).toBeGT(0);
        expect(reFind("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z",appended)).toBeGT(0);
      });

      it("contains logging failure after either success or service failure",function() {
        join.$(method="writeRecoveryEnrollmentAudit",throwException=true,throwType="tests.AuditFailed",throwMessage="CONTROLLED_AUDIT_FAILURE");
        var success=join.enrollNewMemberForRecovery(123,new fpw.tests.support.RecoverySignupEnrollmentStub());
        expect(success.CODE).toBe("ENROLLED");
        var failure=join.enrollNewMemberForRecovery(123,new fpw.tests.support.RecoverySignupEnrollmentStub(fail=true));
        expect(failure.CODE).toBe("ENROLLMENT_FAILED");
      });

      it("enrolls a committed canonical new account once without resetting its clock or sending",function() {
        var fixture=new fpw.tests.support.RecoveryReadinessFixture();
        try {
          var member=fixture.fresh();
          var coverage=new fpw.includes.InactiveMemberRecoveryCoverageService();
          var enrollment=new fpw.includes.InactiveMemberRecoveryEnrollmentService();
          expect(coverage.getEnrollmentUtc(member.userId)).toBe("");
          expect(coverage.getCoverageVerification(member.userId).stage_history).toBeTrue();
          expect(join.enrollNewMemberForRecovery(member.userId).CODE).toBe("ENROLLED");
          var at=enrollment.getEnrollmentUtc(member.userId);
          expect(len(at) GT 0).toBeTrue();
          expect(join.enrollNewMemberForRecovery(member.userId).CODE).toBe("ALREADY_ENROLLED");
          expect(enrollment.getEnrollmentUtc(member.userId)).toBe(at);
          expect(fixture.enrollmentCount(member.userId)).toBe(1);
          var current=new fpw.includes.InactiveMemberRecoveryClassifierService().evaluateMember(member.userId,fixture.dbUtc());
          expect(current.ELIGIBLE).toBeFalse();
          expect(current.DECISION_CODE).toBe("DEFERRED_WAITING_FOR_INTERVAL");
          expect(fixture.counts().ledger).toBe(0);expect(fixture.counts().attempted).toBe(0);
        } finally {
          fixture.cleanup();
          expect(fixture.counts().users).toBe(0);expect(fixture.counts().events).toBe(0);
        }
      });
    });
  }
}
