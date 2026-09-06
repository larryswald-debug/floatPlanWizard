component extends="testbox.system.BaseSpec" output="false" {
  function run() {
    describe("Durable recovery enrollment and independent coverage",function() {
      beforeEach(function() {
        variables.fixture=new fpw.tests.support.RecoveryEnrollmentFixture();
        variables.enrollment=new fpw.includes.InactiveMemberRecoveryEnrollmentService();
      });
      afterEach(function() {
        var counts=variables.fixture.counts();
        expect(counts.ledger).toBe(0);
        expect(counts.attempted).toBe(0);
        variables.fixture.cleanup();
        expect(variables.fixture.counts().users).toBe(0);
        expect(variables.fixture.counts().events).toBe(0);
      });

      it("writes one account-owned PII-free DB UTC event and keeps its initial time",function() {
        var member=fixture.createMember();
        var before=fixture.dbUtc();
        expect(enrollment.getEnrollmentUtc(member.userId)).toBe("");
        var first=enrollment.ensureEnrolled(member.userId);
        var after=fixture.dbUtc();
        expect(first.CODE).toBe("ENROLLED");
        expect(compare(first.ENROLLMENT_UTC,before) GTE 0).toBeTrue();
        expect(compare(first.ENROLLMENT_UTC,after) LTE 0).toBeTrue();
        var row=fixture.enrollmentRow(member.userId);
        expect(row.recordCount).toBe(1);
        expect(val(row.entity_id[1])).toBe(member.userId);
        expect(toString(row.entity_type[1])).toBe("user");
        expect(toString(row.event_source[1])).toBe("recovery_enrollment");
        expect(toString(row.metadata_json[1])).toBe("{}");
        expect(toString(row.idempotency_key[1])).toBe("inactive_member_recovery_enrolled:" & member.userId);
        var again=enrollment.ensureEnrolled(member.userId);
        expect(again.CODE).toBe("ALREADY_ENROLLED");
        expect(again.ENROLLMENT_UTC).toBe(first.ENROLLMENT_UTC);
        expect(fixture.enrollmentCount(member.userId)).toBe(1);
      });

      it("enrollment alone holds even after 168 hours and explicit dates prove no coverage",function() {
        var member=fixture.createMember();
        var at=enrollment.ensureEnrolled(member.userId).ENROLLMENT_UTC;
        var classifier=new fpw.includes.InactiveMemberRecoveryClassifierService();
        var evaluated=classifier.evaluateMember(member.userId,fixture.plusSeconds(at,604800));
        expect(evaluated.DECISION_CODE).toBe("HOLD_INCOMPLETE_COVERAGE");
        expect(evaluated.EVIDENCE_SUMMARY.ENROLLMENT_SOURCE).toBe("product_events");
        expect(evaluated.EVIDENCE_SUMMARY.ENROLLMENT_UTC).toBe(at);
        expect(classifier.evaluateMember(member.userId,fixture.plusSeconds(at,604800),at).ELIGIBLE).toBeFalse();
        for (var key in ["stage_history","activity_coverage","sharing_history","recovery_history"]) {
          var partial=reviewed(); structDelete(partial,key);
          expect(classifier.evaluateMember(userId=member.userId,nowUtc=fixture.plusSeconds(at,604800),coverageVerification=partial).DECISION_CODE).toBe("HOLD_INCOMPLETE_COVERAGE");
          partial[key]="true";
          expect(classifier.evaluateMember(userId=member.userId,nowUtc=fixture.plusSeconds(at,604800),coverageVerification=partial).ELIGIBLE).toBeFalse();
        }
      });

      it("old synthetic account gets a fresh exact 168-hour grace with independently reviewed evidence",function() {
        var member=fixture.createMember();
        queryExecute("UPDATE users SET created='2020-01-01',lastLogin='2020-01-02' WHERE userId=:id",params(member.userId),{datasource="fpw"});
        var at=enrollment.ensureEnrolled(member.userId).ENROLLMENT_UTC;
        var classifier=new fpw.includes.InactiveMemberRecoveryClassifierService();
        var early=classifier.evaluateMember(userId=member.userId,nowUtc=fixture.plusSeconds(at,604799),coverageVerification=reviewed());
        expect(early.ELIGIBLE).toBeFalse();
        expect(early.POLICY_DECISION.seconds_until_eligible).toBe(1);
        expect(early.POLICY_DECISION.anchor_utc).toBe(at);
        var exact=classifier.evaluateMember(userId=member.userId,nowUtc=fixture.plusSeconds(at,604800),coverageVerification=reviewed());
        expect(exact.DECISION_CODE).toBe("ELIGIBLE");
      });

      it("later qualifying activity supersedes enrollment without resetting it",function() {
        var member=fixture.createMember("B");
        var at=enrollment.ensureEnrolled(member.userId).ENROLLMENT_UTC;
        fixture.event(member.userId,"vessel_updated","vessel",member.vesselId,"member_api","2026-09-01 00:00:00");
        var activityAt=fixture.plusSeconds(at,432000);
        fixture.setEvidenceClock(member.userId,"vessel_updated",activityAt);
        var classifier=new fpw.includes.InactiveMemberRecoveryClassifierService();
        var early=classifier.evaluateMember(userId=member.userId,nowUtc=fixture.plusSeconds(at,604800),coverageVerification=reviewed());
        expect(early.DECISION_CODE).toBe("SUPPRESSED_RECENT_ACTIVITY");
        expect(early.POLICY_DECISION.anchor_utc).toBe(activityAt);
        expect(early.POLICY_DECISION.eligible_at_utc).toBe(fixture.plusSeconds(activityAt,604800));
        expect(classifier.evaluateMember(userId=member.userId,nowUtc=fixture.plusSeconds(activityAt,604800),coverageVerification=reviewed()).ELIGIBLE).toBeTrue();
        expect(enrollment.ensureEnrolled(member.userId).ENROLLMENT_UTC).toBe(at);
      });

      it("later stage advancement retains enrollment and starts its own interval",function() {
        var member=fixture.createMember();
        var at=enrollment.ensureEnrolled(member.userId).ENROLLMENT_UTC;
        fixture.advance(member.userId,"C");
        var stageAt=fixture.plusSeconds(at,432000);
        fixture.setEvidenceClock(member.userId,"user_route_created",stageAt);
        var result=new fpw.includes.InactiveMemberRecoveryClassifierService().evaluateMember(
          userId=member.userId,nowUtc=fixture.plusSeconds(at,604800),coverageVerification=reviewed());
        expect(result.CURRENT_STAGE).toBe("C");
        expect(result.STAGE_ENTERED_UTC).toBe(stageAt);
        expect(result.POLICY_DECISION.eligible_at_utc).toBe(fixture.plusSeconds(stageAt,604800));
        expect(enrollment.getEnrollmentUtc(member.userId)).toBe(at);
      });

      it("enrolls a valid member with a missing stage clock but never clears that HOLD",function() {
        var member=fixture.createMember();
        queryExecute("DELETE FROM product_events WHERE user_id=:id AND event_name='sign_up'",
          params(member.userId),{datasource="fpw"});
        expect(enrollment.ensureEnrolled(member.userId).CODE).toBe("ENROLLED");
        var result=new fpw.includes.InactiveMemberRecoveryClassifierService().evaluateMember(member.userId,fixture.dbUtc());
        expect(result.DECISION_CODE).toBe("HOLD_INCOMPLETE_STAGE_CLOCK");
      });

      it("Basic and Premium durable sharing omit initial enrollment and survive source deletion",function() {
        for (var origin in ["basic","premium"]) {
          var member=fixture.createMember("D"); fixture.share(member.userId,origin);
          fixture.deletePlanningRows(member.userId);
          var result=enrollment.ensureEnrolled(member.userId);
          expect(result.CODE).toBe("NOT_ELIGIBLE_FOR_ENROLLMENT");
          expect(result.REASON).toBe("SUPPRESSED_ALREADY_SHARED");
          expect(fixture.enrollmentCount(member.userId)).toBe(0);
        }
      });

      it("sharing after enrollment retains its clock but permanently suppresses evaluation",function() {
        var member=fixture.createMember("D");
        var at=enrollment.ensureEnrolled(member.userId).ENROLLMENT_UTC;
        fixture.share(member.userId,"basic"); fixture.deletePlanningRows(member.userId);
        expect(enrollment.ensureEnrolled(member.userId).ENROLLMENT_UTC).toBe(at);
        expect(new fpw.includes.InactiveMemberRecoveryClassifierService().evaluateMember(member.userId,fixture.dbUtc()).DECISION_CODE).toBe("SUPPRESSED_ALREADY_SHARED");
      });

      it("product deletion and account deletion cannot reset or recreate enrollment",function() {
        var member=fixture.createMember("C");
        var at=enrollment.ensureEnrolled(member.userId).ENROLLMENT_UTC;
        fixture.deletePlanningRows(member.userId);
        expect(enrollment.getEnrollmentUtc(member.userId)).toBe(at);
        expect(new fpw.includes.InactiveMemberRecoveryClassifierService().evaluateMember(member.userId,fixture.dbUtc()).DECISION_CODE).toBe("HOLD_CONTRADICTORY_EVIDENCE");
        // Exact run-owned account only; retained orphan events cannot enroll a deleted account.
        queryExecute("DELETE FROM users WHERE userId=:id",params(member.userId),{datasource="fpw"});
        expect(enrollment.ensureEnrolled(member.userId).CODE).toBe("MEMBER_NOT_FOUND");
        expect(enrollment.getEnrollmentUtc(member.userId)).toBe("");
      });

      it("preview reports enrolled enrollable shared rejected and held cohorts without identities",function() {
        var already=fixture.createMember(); enrollment.ensureEnrolled(already.userId);
        var eligible=fixture.createMember();
        var shared=fixture.createMember("D"); fixture.share(shared.userId,"basic");
        var admin=fixture.createMember(); fixture.admin(admin.userId);
        var held=fixture.createMember("C"); fixture.deletePlanningRows(held.userId);
        var result=enrollment.previewMembers(fixture.getCandidateIds(100));
        expect(result.scanned).toBe(5);
        expect(result.already_enrolled).toBe(1); expect(result.enrollable).toBe(1);
        expect(result.shared).toBe(1); expect(result.not_eligible).toBe(1); expect(result.held).toBe(1);
        expect(reFindNoCase('"(email|name|user_?id|token|recipient)"\s*:',serializeJSON(result))).toBe(0);
        expect(fixture.enrollmentCount(eligible.userId)).toBe(0);
      });

      it("omits admin invalid duplicate opted-out and nonexistent accounts",function() {
        var admin=fixture.createMember(); fixture.admin(admin.userId);
        expect(enrollment.ensureEnrolled(admin.userId).REASON).toBe("SUPPRESSED_ADMIN");
        var invalid=fixture.createMember();
        queryExecute("UPDATE users SET email='invalid' WHERE userId=:id",params(invalid.userId),{datasource="fpw"});
        expect(enrollment.ensureEnrolled(invalid.userId).REASON).toBe("SUPPRESSED_INVALID_EMAIL");
        var opted=fixture.createMember();
        new fpw.api.v1.EmailOptOutService(datasource="fpw").recordOptOut(opted.email,opted.userId,"non_essential","enrollment_test");
        expect(enrollment.ensureEnrolled(opted.userId).REASON).toBe("SUPPRESSED_OPTED_OUT");
        var duplicate=fixture.createMember();
        queryExecute("UPDATE users SET email=:email WHERE userId=:id",
          {id={value=duplicate.userId,cfsqltype="cf_sql_integer"},email={value=admin.email,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
        expect(enrollment.ensureEnrolled(duplicate.userId).REASON).toBe("HOLD_DUPLICATE_EMAIL_IDENTITY");
        for (var id in [0,-1,1.5,2147483647]) expect(enrollment.ensureEnrolled(id).CODE).toBe("MEMBER_NOT_FOUND");
        for (var id in fixture.getCandidateIds(100)) expect(fixture.enrollmentCount(id)).toBe(0);
      });

      it("future activity and contradictory stage history do not enroll",function() {
        var member=fixture.createMember("B");
        fixture.setEvidenceClock(member.userId,"vessel_created",fixture.plusSeconds(fixture.dbUtc(),86400));
        expect(enrollment.ensureEnrolled(member.userId).REASON).toBe("HOLD_CONTRADICTORY_EVIDENCE");
        var prior=fixture.createMember("C"); fixture.deletePlanningRows(prior.userId);
        expect(enrollment.ensureEnrolled(prior.userId).REASON).toBe("HOLD_CONTRADICTORY_EVIDENCE");
      });

      it("event failure before or after insertion rolls back enrollment",function() {
        for (var mode in ["before","after"]) {
          var member=fixture.createMember();
          var service=new fpw.includes.InactiveMemberRecoveryEnrollmentService(
            eventService=new fpw.tests.support.RecoveryEnrollmentEventFailure(mode));
          expect(service.ensureEnrolled(member.userId).CODE).toBe("ENROLLMENT_FAILED");
          expect(fixture.enrollmentCount(member.userId)).toBe(0);
          expect(enrollment.ensureEnrolled(member.userId).CODE).toBe("ENROLLED");
        }
      });

      it("tampered source owner metadata key duplicate or future enrollment fails closed",function() {
        for (var mutation in ["source","owner","metadata","key","future","duplicate"]) {
          var member=fixture.createMember();
          expect(enrollment.ensureEnrolled(member.userId).CODE).toBe("ENROLLED");
          var updates={source="event_source='member_api'",owner="entity_id=entity_id+1",metadata="metadata_json='{""name"":""private""}'",
            key="idempotency_key=CONCAT(idempotency_key,':bad')",future="occurred_at_utc=UTC_TIMESTAMP()+INTERVAL 1 DAY"};
          if (mutation EQ "duplicate") {
            new fpw.includes.ProductEventService().recordEvent(member.userId,"inactive_member_recovery_enrolled","user",member.userId,"recovery_enrollment");
          } else {
            queryExecute("UPDATE product_events SET " & updates[mutation] & " WHERE user_id=:id AND event_name='inactive_member_recovery_enrolled'",params(member.userId),{datasource="fpw"});
          }
          expect(enrollment.ensureEnrolled(member.userId).CODE).toBe("ENROLLMENT_FAILED");
          expect(new fpw.includes.InactiveMemberRecoveryClassifierService().evaluateMember(member.userId,fixture.dbUtc()).DECISION_CODE).toBe("HOLD_ENROLLMENT_EVIDENCE_INVALID");
        }
      });

      it("preview and sender dry runs never enroll claim or send",function() {
        var enrolled=fixture.createMember();
        var absent=fixture.createMember();
        var at=enrollment.ensureEnrolled(enrolled.userId).ENROLLMENT_UTC;
        var preview=enrollment.previewMembers(fixture.getCandidateIds(100));
        expect(preview.already_enrolled).toBe(1); expect(preview.enrollable).toBe(1);
        expect(fixture.enrollmentCount(absent.userId)).toBe(0);
        fixture.setTestNow(fixture.plusSeconds(at,604800));
        var held=fixture.dryService().processBatch(batchSize=2,dryRun=true);
        expect(held.held).toBe(2); expect(held.eligible).toBe(0);
        expect(held.reasons.HOLD_INCOMPLETE_COVERAGE).toBe(1);
        expect(held.reasons.ENROLLMENT_EVIDENCE_REQUIRED).toBe(1);
        var reviewed=fixture.dryService(true).processBatch(batchSize=2,dryRun=true);
        expect(reviewed.eligible).toBe(1); expect(reviewed.claimed).toBe(0); expect(reviewed.sent).toBe(0);
        expect(fixture.enrollmentCount(absent.userId)).toBe(0);
        expect(fixture.dryService().processBatch(batchSize=2,dryRun=false).error).toBe("LIVE_MODE_DISABLED");
        expect(enrollment.previewMembers([enrolled.userId,enrolled.userId]).ok).toBeFalse();
        var tooMany=[]; for (var i=1;i LTE 101;i++) arrayAppend(tooMany,i);
        expect(enrollment.previewMembers(tooMany).ok).toBeFalse();
      });
    });
  }
  private struct function reviewed() {
    return {stage_history=true,activity_coverage=true,sharing_history=true,recovery_history=true};
  }
  private struct function params(required numeric id) { return {id={value=arguments.id,cfsqltype="cf_sql_integer"}}; }
}
