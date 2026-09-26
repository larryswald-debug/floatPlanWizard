component extends="testbox.system.BaseSpec" output="false" {
  function run() {
    describe("Explicit reviewed enrollment cohorts",function() {
      beforeEach(function() {
        variables.fixture=new fpw.tests.support.RecoveryEnrollmentIntegrationFixture();
        variables.audit=new fpw.tests.support.RecoveryEnrollmentAuditStub();
        variables.service=expose(new fpw.api.v1.AdminRecoveryEnrollmentService(auditService=audit));
      });
      afterEach(function() {
        expect(fixture.counts().ledger).toBe(0);expect(fixture.attemptCount()).toBe(0);
        fixture.cleanup();expect(fixture.counts().users).toBe(0);expect(fixture.counts().events).toBe(0);
      });
      it("retains only allowlisted enrollment failure categories and validated diagnostic references",function() {
        var references=[lCase(createUUID()),"12345678-1234-1234-1234-123456789abc"];
        for (var reason in ["ENROLLMENT_EVIDENCE_INVALID","ENROLLMENT_DATABASE_ERROR","ENROLLMENT_COMPONENT_ERROR",
          "ENROLLMENT_ASSESSMENT_ERROR","ENROLLMENT_WRITE_ERROR"]) {
          for (var reference in references) {
            var result=service.outcomeRow(47,{SUCCESS=false,CODE="ENROLLMENT_FAILED",REASON=reason,
              ERROR_REFERENCE=uCase(reference),MESSAGE="Private exception text",SQL="Private SQL"});
            expect(result.code).toBe("ENROLLMENT_FAILED");expect(result.reason).toBe(reason);
            expect(result.errorReference).toBe(reference);expect(result.enrollmentUtc).toBe("");
            expect(result.coverageVerified).toBeFalse();expect(structCount(result)).toBe(6);
          }
        }
      });
      it("filters malformed and untrusted failure diagnostics without exposing exception details",function() {
        for (var outcome in [
          {SUCCESS=false,CODE="ENROLLMENT_FAILED",REASON="PRIVATE_DATABASE_DETAIL",ERROR_REFERENCE="<script>alert(1)</script>"},
          {SUCCESS=false,CODE="ENROLLMENT_FAILED",REASON="PRIVATE_DATABASE_DETAIL",ERROR_REFERENCE=lCase(createUUID()) & chr(10)},
          {SUCCESS=false,CODE="ENROLLMENT_FAILED",REASON="PRIVATE_DATABASE_DETAIL",ERROR_REFERENCE="12345678-1234-1234-1234-123456789abc" & chr(10)},
          {SUCCESS=false,CODE="ENROLLMENT_FAILED",REASON={message="Private failure"},ERROR_REFERENCE=["private"]},
          {SUCCESS=false,CODE="ENROLLMENT_FAILED",REASON="ENROLLMENT_DATABASE_ERROR,PRIVATE_DETAIL",ERROR_REFERENCE=repeatString("a",37)},
          {SUCCESS=false,CODE="UNEXPECTED_FAILURE",REASON="ENROLLMENT_DATABASE_ERROR",ERROR_REFERENCE=lCase(createUUID())},
          {SUCCESS=[],CODE="ENROLLMENT_FAILED",REASON="ENROLLMENT_DATABASE_ERROR",ERROR_REFERENCE=lCase(createUUID())},
          {SUCCESS=false,CODE={value="ENROLLMENT_FAILED"},REASON="ENROLLMENT_DATABASE_ERROR",ERROR_REFERENCE=lCase(createUUID())},
          {CODE="ENROLLMENT_FAILED",MESSAGE="Private exception text"}
        ]) {
          var result=service.outcomeRow(47,outcome);
          expect(result.code).toBe("ENROLLMENT_FAILED");expect(result.reason).toBe("ENROLLMENT_FAILED");
          expect(result.errorReference).toBe("");expect(result.enrollmentUtc).toBe("");
          expect(structCount(result)).toBe(6);
        }
      });
      it("keeps successful outcomes unchanged and never carries a failure reference into them",function() {
        var result=service.outcomeRow(47,{SUCCESS=true,CODE="ENROLLED",ENROLLMENT_UTC="2026-09-25T12:00:00Z",
          ERROR_REFERENCE=lCase(createUUID())});
        expect(result.code).toBe("ENROLLED");expect(result.reason).toBe("");
        expect(result.enrollmentUtc).toBe("2026-09-25T12:00:00Z");expect(result.errorReference).toBe("");
        var skipped=service.outcomeRow(47,{SUCCESS=true,CODE="NOT_ELIGIBLE_FOR_ENROLLMENT",REASON="SUPPRESSED_OPTED_OUT",
          ERROR_REFERENCE=lCase(createUUID())});
        expect(skipped.code).toBe("NOT_ELIGIBLE_FOR_ENROLLMENT");expect(skipped.reason).toBe("SUPPRESSED_OPTED_OUT");
        expect(skipped.errorReference).toBe("");expect(skipped.enrollmentUtc).toBe("");
      });
      it("reports invalid enrollment evidence while independently retaining verified coverage and making no preview writes",function() {
        var member=fixture.fresh();
        expect(new fpw.includes.InactiveMemberRecoveryEnrollmentService().ensureEnrolled(member.userId).CODE).toBe("ENROLLED");
        queryExecute("UPDATE product_events SET metadata_json=JSON_OBJECT('fixture_invalid',true)
          WHERE user_id=:id AND event_name='inactive_member_recovery_enrolled'
            AND idempotency_key=:eventKey",
          {id={value=member.userId,cfsqltype="cf_sql_integer"},
           eventKey={value="inactive_member_recovery_enrolled:" & member.userId,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
        var before=fixture.counts().events;
        var result=service.buildPreview(toString(member.userId),member.userId);
        var failed=row(result,member.userId);
        expect(result.ok).toBeFalse();expect(result.scanned).toBe(1);expect(result.failures).toBe(1);
        expect(result.eligible).toBe(0);expect(result.reviewToken).toBe("");
        expect(failed.code).toBe("ENROLLMENT_FAILED");expect(failed.reason).toBe("ENROLLMENT_EVIDENCE_INVALID");
        expect(isValid("uuid",failed.errorReference)).toBeTrue();expect(failed.coverageVerified).toBeTrue();
        expect(failed.enrollmentUtc).toBe("");expect(fixture.counts().events).toBe(before);
        expect(arrayLen(audit.entries())).toBe(0);
      });
      it("previews a mixed explicit cohort without changing enrollment or granting coverage",function() {
        var members=fixture.prepare("Disposable-Cohort-Test!");
        var ids=[members.A.userId,members.B.userId,members.C.userId,members.D.userId,members.already.userId,
          members.shared.userId,members.opted.userId,members.invalid.userId,members.deleted.userId,members.admin.userId,
          members.covered.userId,members.corrupt.userId];
        var before=fixture.counts().events;
        var result=service.buildPreview(arrayToList(ids),members.admin.userId);
        expect(result.ok).toBeTrue();expect(result.scanned).toBe(12);expect(result.eligible).toBe(6);
        expect(result.already_enrolled).toBe(1);expect(result.skipped).toBe(5);expect(result.newly_enrolled).toBe(0);
        expect(fixture.counts().events).toBe(before);expect(arrayLen(audit.entries())).toBe(0);
        expect(row(result,members.covered.userId).coverageVerified).toBeTrue();
        expect(row(result,members.corrupt.userId).coverageVerified).toBeFalse();
      });
      it("rejects empty malformed duplicate and over-limit explicit selections",function() {
        var m=fixture.createMember();
        for (var input in ["","0","-1","01","1.5","1,,2","1,","2147483648","1;2","<script>","1,1"]) {
          var result=service.buildPreview(input,m.userId);
          expect(result.ok).toBeFalse();expect(result.reasons.INVALID_CANDIDATES).toBe(1);
        }
        var ids=[];for(var i=1;i LTE 101;i++) arrayAppend(ids,i);
        expect(service.buildPreview(arrayToList(ids),m.userId).ok).toBeFalse();
        expect(service.buildPreview(toString(m.userId) & chr(10) & "2147483647",m.userId).scanned).toBe(2);
        expect(fixture.enrollmentCount(m.userId)).toBe(0);
      });
      it("enrolls only reviewed members and keeps already-enrolled timestamps unchanged",function() {
        var a=fixture.createMember();var b=fixture.createMember();var c=fixture.createMember();
        var original=new fpw.includes.InactiveMemberRecoveryEnrollmentService().ensureEnrolled(b.userId).ENROLLMENT_UTC;
        var preview=service.buildPreview(arrayToList([a.userId,b.userId]),a.userId);
        var result=service.executeReviewed(snapshot(preview),a.userId);
        expect(result.newly_enrolled).toBe(1);expect(result.already_enrolled).toBe(1);expect(result.eligible).toBe(1);
        expect(fixture.enrollmentCount(a.userId)).toBe(1);expect(fixture.enrollmentCount(c.userId)).toBe(0);
        expect(new fpw.includes.InactiveMemberRecoveryEnrollmentService().getEnrollmentUtc(b.userId)).toBe(original);
        var retry=service.executeReviewed(snapshot(preview),a.userId);
        expect(retry.newly_enrolled).toBe(0);expect(retry.already_enrolled).toBe(2);
        expect(reFindNoCase('"email"\s*:', '{"email":"fixture"}')).toBeGT(0);
        for(var entry in audit.entries()) {
          expect(reFindNoCase('"(?:(?:e)?mail|name|recipient|token)"\s*:',serializeJSON(entry.newValues))).toBe(0);
        }
      });
      it("rechecks opt-outs and intervening enrollment immediately before committing each member",function() {
        var a=fixture.createMember();var b=fixture.createMember();
        var preview=service.buildPreview(arrayToList([a.userId,b.userId]),a.userId);
        fixture.optOut(a.userId);
        var original=new fpw.includes.InactiveMemberRecoveryEnrollmentService().ensureEnrolled(b.userId).ENROLLMENT_UTC;
        var result=service.executeReviewed(snapshot(preview),a.userId);
        expect(result.newly_enrolled).toBe(0);expect(result.already_enrolled).toBe(1);expect(result.skipped).toBe(1);
        expect(row(result,a.userId).reason).toBe("SUPPRESSED_OPTED_OUT");expect(fixture.enrollmentCount(a.userId)).toBe(0);
        expect(row(result,b.userId).enrollmentUtc).toBe(original);
      });
      it("keeps coverage independent and applies the unchanged exact 168-hour interval",function() {
        var old=fixture.createMember();var fresh=fixture.fresh();
        var preview=service.buildPreview(arrayToList([old.userId,fresh.userId]),old.userId);
        var result=service.executeReviewed(snapshot(preview),old.userId);
        expect(result.newly_enrolled).toBe(2);
        var classifier=new fpw.includes.InactiveMemberRecoveryClassifierService();
        var oldAt=row(result,old.userId).enrollmentUtc;var freshAt=row(result,fresh.userId).enrollmentUtc;
        expect(classifier.evaluateMember(old.userId,fixture.plusSeconds(oldAt,604800)).DECISION_CODE).toBe("HOLD_INCOMPLETE_COVERAGE");
        expect(classifier.evaluateMember(fresh.userId,fixture.plusSeconds(freshAt,604799)).ELIGIBLE).toBeFalse();
        expect(classifier.evaluateMember(fresh.userId,fixture.plusSeconds(freshAt,604800)).ELIGIBLE).toBeTrue();
        expect(new fpw.includes.InactiveMemberRecoveryCoverageService().getCoverageVerification(old.userId).stage_history).toBeFalse();
      });
      it("makes no enrollment writes when the required review audit fails",function() {
        var a=fixture.createMember();var preview=service.buildPreview(toString(a.userId),a.userId);
        var broken=expose(new fpw.api.v1.AdminRecoveryEnrollmentService(auditService=new fpw.tests.support.RecoveryEnrollmentAuditStub(failAt=1)));
        var result=broken.executeReviewed(snapshot(preview),a.userId);
        expect(result.ok).toBeFalse();expect(result.newly_enrolled).toBe(0);expect(result.failures).toBe(1);
        expect(row(result,a.userId).reason).toBe("AUDIT_UNAVAILABLE");expect(fixture.enrollmentCount(a.userId)).toBe(0);
      });
      it("reports committed results and stops later writes if result auditing fails",function() {
        var a=fixture.createMember();var b=fixture.createMember();
        var preview=service.buildPreview(arrayToList([a.userId,b.userId]),a.userId);
        var broken=expose(new fpw.api.v1.AdminRecoveryEnrollmentService(auditService=new fpw.tests.support.RecoveryEnrollmentAuditStub(failAt=2)));
        var result=broken.executeReviewed(snapshot(preview),a.userId);
        expect(result.ok).toBeFalse();expect(result.auditIncomplete).toBeTrue();expect(result.newly_enrolled).toBe(1);
        expect(fixture.enrollmentCount(a.userId)).toBe(1);expect(fixture.enrollmentCount(b.userId)).toBe(0);
        expect(row(result,b.userId).code).toBe("ENROLLMENT_NOT_ATTEMPTED");
      });
      it("reports a persistence failure without claiming enrollment or touching delivery state",function() {
        var a=fixture.createMember();var preview=service.buildPreview(toString(a.userId),a.userId);
        var broken=expose(new fpw.api.v1.AdminRecoveryEnrollmentService(auditService=audit,
          enrollmentService=new fpw.includes.InactiveMemberRecoveryEnrollmentService(eventService=new fpw.tests.support.RecoveryEnrollmentEventFailure("after"))));
        var result=broken.executeReviewed(snapshot(preview),a.userId);
        expect(result.ok).toBeFalse();expect(result.failures).toBe(1);expect(result.newly_enrolled).toBe(0);
        expect(fixture.enrollmentCount(a.userId)).toBe(0);
      });
    });
  }
  private any function expose(required any target) {makePublic(arguments.target,"buildPreview");makePublic(arguments.target,"executeReviewed");makePublic(arguments.target,"outcomeRow");return arguments.target;}
  private struct function snapshot(required struct report) {
    var selected=[];for(var row in arguments.report.rows) if(row.code EQ "ENROLLABLE") arrayAppend(selected,row.userId);
    return {requestedIds=arguments.report.requestedIds,eligibleIds=selected,rows=duplicate(arguments.report.rows)};
  }
  private struct function row(required struct report,required numeric userId) {
    for(var entry in arguments.report.rows) if(entry.userId EQ arguments.userId) return entry;
    throw(message="EXPECTED_MEMBER_ROW_MISSING");
  }
}
