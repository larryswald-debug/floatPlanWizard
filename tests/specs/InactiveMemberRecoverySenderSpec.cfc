component extends="testbox.system.BaseSpec" output="false" {
  function run() {
    describe("Inactive member recovery sender orchestration",function() {
      beforeEach(function() { variables.fixture=new fpw.tests.support.RecoveryOrchestrationFixture(); });
      afterEach(function() { variables.fixture.cleanup(); });

      it("submits contact one for all four destinations with real policy, compliance, and ledger",function() {
        var members=[];
        for (var stage in ["A","B","C","D"]) arrayAppend(members,variables.fixture.createMember(stage));
        var before=variables.fixture.counts();
        var first=variables.fixture.service().processBatch(25,false);
        expect(first.scanned).toBe(4);
        expect(first.eligible).toBe(4);
        expect(first.claimed).toBe(4);
        expect(first.sent).toBe(4);
        expect(first.submitted).toBe(4);
        expect(first.failed).toBe(0);
        expect(variables.fixture.counts().events).toBe(before.events);
        var messages=variables.fixture.messages();
        var expected=["Add your boat to FloatPlanWizard","Ready to plan your first trip?","Pick up your trip planning","Your Float Plan is waiting"];
        var destinations=["vessel","planner","route&routeId=" & members[3].routeId,"draft&floatPlanId=" & members[4].planId];
        for (var i=1;i LTE 4;i++) {
          expect(messages[i].subject).toBe(expected[i]);
          expect(messages[i].ctaUrl).toBe("http://localhost:8500/fpw/app/dashboard.cfm?recoveryAction=" & destinations[i]);
          expect(messages[i].textBody).toInclude(messages[i].ctaUrl);
          expect(messages[i].htmlBody).toInclude(encodeForHtmlAttribute(messages[i].ctaUrl));
          expect(messages[i].textBody).toInclude("4347 Topsail Trail, New Port Richey, FL 34652");
          expect(messages[i].textBody).toInclude("/unsubscribe.cfm?t=");
          expect(messages[i].textBody).toInclude("/app/account.cfm##email-preferences");
          expect(variables.fixture.state(members[i].userId,1).STATUS).toBe("SENT");
        }
        var second=variables.fixture.service().processBatch(25,false);
        expect(second.sent).toBe(0);
        expect(variables.fixture.attemptCount()).toBe(4);
        expect(reFindNoCase('"(email|user_?id|token|name|stack|floatplanid)"\s*:',serializeJSON(first))).toBe(0);
      });

      it("dry-run with observation stub performs no claim, render, send, or product write",function() {
        variables.fixture.createMember("A");
        variables.fixture.configure(emailMode="RENDER_FAILURE");
        var before=variables.fixture.counts();
        var result=variables.fixture.service().processBatch(25,true);
        expect(result.eligible).toBe(1);
        expect(result.claimed).toBe(0);
        expect(result.sent).toBe(0);
        expect(variables.fixture.counts()).toBe(before);
      });

      it("uses the existing synchronous multipart boundary and treats transport exceptions as ambiguous",function() {
        var member=variables.fixture.createMember("A");
        variables.fixture.service().processBatch(25,false);
        var message=variables.fixture.messages()[1];
        var email=prepareMock(new fpw.api.v1.email());
        email.$("sendMultipartEmail");
        expect(email.submitInactiveMemberRecoveryEmail(member.email,message).OUTCOME).toBe("SUBMITTED");
        expect(email.$count("sendMultipartEmail")).toBe(1);
        var call=email.$callLog().sendMultipartEmail[1];
        expect(call.spoolEnable).toBeFalse();
        expect(call.rethrowOnFailure).toBeTrue();
        expect(call.htmlBody).toBe(message.htmlBody);
        expect(call.textBody).toBe(message.textBody);
        var throwing=prepareMock(new fpw.api.v1.email());
        throwing.$(method="sendMultipartEmail",throwException=true,throwType="tests.UnknownSMTP",throwMessage="CONTROLLED_UNKNOWN_RESULT");
        expect(throwing.submitInactiveMemberRecoveryEmail(member.email,message).OUTCOME).toBe("AMBIGUOUS");
        var invalid=prepareMock(new fpw.api.v1.email());
        invalid.$("sendMultipartEmail");
        expect(invalid.submitInactiveMemberRecoveryEmail("invalid",message).OUTCOME).toBe("FAILED");
        expect(invalid.$count("sendMultipartEmail")).toBe(0);
      });

      it("uses an explicitly configured 168-hour policy boundary",function() {
        variables.fixture.createMember("A");
        variables.fixture.setNow("2026-09-07T23:59:59Z");
        var before=variables.fixture.service().processBatch(25,false);
        expect(before.claimed).toBe(0);
        expect(before.eligible).toBe(0);
        expect(variables.fixture.counts().ledger).toBe(0);
        variables.fixture.setNow("2026-09-08T00:00:00Z");
        expect(variables.fixture.service().processBatch(25,false).sent).toBe(1);
      });

      it("recent qualifying saved activity resets the interval",function() {
        var member=variables.fixture.createMember("B");
        variables.fixture.event(member.userId,"vessel_updated","vessel",member.vesselId,"member_api","2026-09-02 00:00:00");
        expect(variables.fixture.service().processBatch(25,false).claimed).toBe(0);
        variables.fixture.setNow("2026-09-09T00:00:00Z");
        expect(variables.fixture.service().processBatch(25,false).sent).toBe(1);
      });

      it("rolls back a C claim if a Draft appears before revalidation",function() {
        var member=variables.fixture.createMember("C");
        variables.fixture.configure(race="advance");
        var result=variables.fixture.service().processBatch(25,false);
        expect(result.canceled).toBe(1);
        expect(result.sent).toBe(0);
        expect(variables.fixture.state(member.userId,1).HAS_ROW).toBeFalse();
        expect(variables.fixture.attemptCount()).toBe(0);
        var current=new fpw.includes.InactiveMemberRecoveryClassifierService().evaluateMember(member.userId,variables.fixture.nowUtc(),variables.fixture.getEnrollmentUtc(member.userId));
        expect(current.CURRENT_STAGE).toBe("D");
      });

      it("cancels after sharing, opt-out, or monitoring starts before send",function() {
        for (var action in ["share","optout","active"]) {
          var member=variables.fixture.createMember("D");
          variables.fixture.configure(race=action);
          var result=variables.fixture.service().processBatch(25,false);
          expect(result.sent).toBe(0);
          expect(result.canceled).toBeGTE(1);
          expect(variables.fixture.state(member.userId,1).HAS_ROW).toBeFalse();
          expect(variables.fixture.attemptCount()).toBe(0);
          variables.fixture.cleanup();
          variables.fixture=new fpw.tests.support.RecoveryOrchestrationFixture();
        }
      });

      it("durable Basic and Premium sharing suppress after saved planning rows are deleted",function() {
        for (var origin in ["basic","premium"]) {
          var member=variables.fixture.createMember("C");
          variables.fixture.share(member.userId,origin);
          variables.fixture.deletePlanningRows(member.userId);
          var result=variables.fixture.service().processBatch(25,false);
          expect(result.reasons.SUPPRESSED_ALREADY_SHARED).toBeGTE(1);
          expect(result.claimed).toBe(0);
          expect(variables.fixture.attemptCount()).toBe(0);
        }
      });

      it("compliance and render failures cancel without consuming an attempt",function() {
        var member=variables.fixture.createMember("A");
        for (var mode in ["OPTED_OUT","PREFERENCE_LOOKUP_FAILED","UNSUBSCRIBE_URL_FAILED","MISSING_ADDRESS","RENDER_FAILURE"]) {
          variables.fixture.configure(emailMode=mode);
          var result=variables.fixture.service().processBatch(25,false);
          expect(result.sent).toBe(0);
          expect(variables.fixture.state(member.userId,1).HAS_ROW).toBeFalse();
          expect(variables.fixture.attemptCount()).toBe(0);
        }
      });

      it("retries only definite failures up to the canonical three-attempt cap",function() {
        var member=variables.fixture.createMember("A");
        variables.fixture.configure(outcome="FAILED");
        for (var attempt=1;attempt LTE 3;attempt++) {
          var result=variables.fixture.service().processBatch(25,false);
          expect(result.failed).toBe(1);
          expect(variables.fixture.state(member.userId,1).STATUS).toBe("FAILED");
          expect(variables.fixture.state(member.userId,1).ATTEMPT_COUNT).toBe(attempt);
        }
        expect(variables.fixture.service().processBatch(25,false).claimed).toBe(0);
        expect(variables.fixture.attemptCount()).toBe(3);
      });

      it("a canceled retry restores the previous failure and its attempt count exactly",function() {
        var member=variables.fixture.createMember("A");
        variables.fixture.configure(outcome="FAILED");
        expect(variables.fixture.service().processBatch(25,false).failed).toBe(1);
        var before=variables.fixture.state(member.userId,1);
        variables.fixture.configure(emailMode="MISSING_ADDRESS");
        expect(variables.fixture.service().processBatch(25,false).sent).toBe(0);
        expect(variables.fixture.state(member.userId,1)).toBe(before);
        variables.fixture.configure();
        expect(variables.fixture.service().processBatch(25,false).sent).toBe(1);
        expect(variables.fixture.state(member.userId,1).ATTEMPT_COUNT).toBe(2);
      });

      it("ambiguous transport results and thrown transport errors never replay",function() {
        for (var mode in ["AMBIGUOUS","THROW"]) {
          var member=variables.fixture.createMember("A");
          variables.fixture.configure(outcome=mode);
          var result=variables.fixture.service().processBatch(25,false);
          expect(result.ambiguous).toBe(1);
          expect(variables.fixture.state(member.userId,1).STATUS).toBe("CLAIMED");
          expect(variables.fixture.service().processBatch(25,false).claimed).toBe(0);
          expect(variables.fixture.attemptCount()).toBe(1);
          variables.fixture.cleanup();
          variables.fixture=new fpw.tests.support.RecoveryOrchestrationFixture();
        }
      });

      it("uncertain SENT confirmation preserves a nonreplayable claim or committed SENT row",function() {
        for (var mode in ["CONFIRMATION_UNKNOWN","COMMITTED_CONFIRMATION_UNKNOWN"]) {
          var member=variables.fixture.createMember("A");
          variables.fixture.configure(ledgerMode=mode);
          var result=variables.fixture.service().processBatch(25,false);
          expect(result.submitted).toBe(1);
          expect(result.ambiguous).toBe(1);
          expect(variables.fixture.state(member.userId,1).STATUS).toBe(mode EQ "CONFIRMATION_UNKNOWN" ? "CLAIMED" : "SENT");
          expect(variables.fixture.service().processBatch(25,false).claimed).toBe(0);
          expect(variables.fixture.attemptCount()).toBe(1);
          variables.fixture.cleanup();
          variables.fixture=new fpw.tests.support.RecoveryOrchestrationFixture();
        }
      });

      it("allows only the matching claimant to revalidate and leaves ordinary classification unchanged",function() {
        var member=variables.fixture.createMember("A");
        var ledger=new fpw.includes.InactiveMemberRecoveryLedgerService();
        var claim=ledger.claimContact(member.userId,variables.fixture.enrollmentId(member.userId),1,"A");
        var classifier=new fpw.includes.InactiveMemberRecoveryClassifierService(settingsService=variables.fixture);
        var args={userId=member.userId,nowUtc=variables.fixture.nowUtc(),enrollmentUtc=variables.fixture.getEnrollmentUtc(member.userId),
          coverageVerification=variables.fixture.getCoverageVerification(member.userId)};
        expect(classifier.evaluateMember(argumentCollection=args).DECISION_CODE).toBe("SUPPRESSED_UNRESOLVED_CLAIM");
        args.ownedClaimToken=repeatString("f",64);
        expect(classifier.evaluateMember(argumentCollection=args).ELIGIBLE).toBeFalse();
        args.ownedClaimToken=claim.CLAIM_TOKEN;
        expect(classifier.evaluateMember(argumentCollection=args).ELIGIBLE).toBeTrue();
        expect(ledger.claimContact(member.userId,variables.fixture.enrollmentId(member.userId),2,"B").CLAIMED).toBeFalse();
        expect(classifier.evaluateMember(argumentCollection=args).ELIGIBLE).toBeTrue();
      });

      it("a successful lower-stage send does not suppress a later eligible higher stage",function() {
        var member=variables.fixture.createMember("A");
        expect(variables.fixture.service().processBatch(25,false).sent).toBe(1);
        variables.fixture.advance(member.userId,"B","2026-09-08 00:00:00");
        expect(variables.fixture.service().processBatch(25,false).claimed).toBe(0);
        variables.fixture.setNow("2026-09-20T00:00:00Z");
        expect(variables.fixture.service().processBatch(25,false).sent).toBe(1);
        expect(variables.fixture.state(member.userId,1).STATUS).toBe("SENT");
        expect(variables.fixture.state(member.userId,2).STATUS).toBe("SENT");
        expect(variables.fixture.messages()[2].contactNumber).toBe(2);
        expect(variables.fixture.messages()[2].destinationStage).toBe("B");
      });

      it("sends contacts two and three at unchanged destination A and permanently stops",function(){
        var member=variables.fixture.createMember("A");
        variables.fixture.setTiming(24,24);
        expect(variables.fixture.service().processBatch(25,false).sent).toBe(1);
        variables.fixture.setNow("2026-09-09T00:00:00Z");
        expect(variables.fixture.service().processBatch(25,false).sent).toBe(1);
        variables.fixture.setNow("2026-09-10T00:00:00Z");
        expect(variables.fixture.service().processBatch(25,false).sent).toBe(1);
        var messages=variables.fixture.messages();
        for(var contact=1;contact LTE 3;contact++){
          expect(messages[contact].contactNumber).toBe(contact);
          expect(messages[contact].destinationStage).toBe("A");
          expect(variables.fixture.state(member.userId,contact).STATUS).toBe("SENT");
        }
        expect(messages[1].subject EQ messages[2].subject).toBeFalse();
        expect(messages[2].subject EQ messages[3].subject).toBeFalse();
        variables.fixture.advance(member.userId,"B");
        variables.fixture.setNow("2026-10-20T00:00:00Z");
        var completed=variables.fixture.service().processBatch(25,false);
        expect(completed.sent).toBe(0);
        expect(completed.reasons.SUPPRESSED_RECOVERY_SEQUENCE_COMPLETE).toBe(1);
      });

      it("revalidates product progress and sharing after rendering immediately before submission",function(){
        for(var race in ["final_advance","final_share","final_optout","final_active"]){
          var member=variables.fixture.createMember(race EQ "final_advance" ? "C" : "D");
          variables.fixture.configure(race=race);
          var checked=variables.fixture.service().processBatch(25,false);
          expect(checked.canceled).toBe(1);
          expect(checked.sent).toBe(0);
          expect(variables.fixture.attemptCount()).toBe(0);
          expect(variables.fixture.state(member.userId,1).HAS_ROW).toBeFalse();
          variables.fixture.cleanup();
          variables.fixture=new fpw.tests.support.RecoveryOrchestrationFixture();
        }
      });

      it("sends the three distinct contacts to the same current owned route at C",function(){
        var member=variables.fixture.createMember("C");
        variables.fixture.setTiming(24,24);
        for(var contact=1;contact LTE 3;contact++){
          variables.fixture.setNow("2026-09-" & (7+contact) & "T00:00:00Z");
          expect(variables.fixture.service().processBatch(25,false).sent).toBe(1);
          var message=variables.fixture.messages()[contact];
          expect(message.contactNumber).toBe(contact);
          expect(message.destinationStage).toBe("C");
          expect(message.ctaUrl).toInclude("recoveryAction=route&routeId=" & member.routeId);
          expect(variables.fixture.state(member.userId,contact).DESTINATION_STAGE).toBe("C");
        }
      });

      it("a known failed contact two rerenders that same contact for newly verified B",function(){
        var member=variables.fixture.createMember("A");
        variables.fixture.setTiming(24,24);
        expect(variables.fixture.service().processBatch(25,false).sent).toBe(1);
        variables.fixture.setNow("2026-09-09T00:00:00Z");
        variables.fixture.configure(outcome="FAILED");
        expect(variables.fixture.service().processBatch(25,false).failed).toBe(1);
        expect(variables.fixture.state(member.userId,2).DESTINATION_STAGE).toBe("A");
        variables.fixture.advance(member.userId,"B","2026-09-09 00:00:00");
        variables.fixture.setNow("2026-09-10T00:00:00Z");
        variables.fixture.configure();
        expect(variables.fixture.service().processBatch(25,false).sent).toBe(1);
        var message=variables.fixture.messages()[2];
        expect(message.contactNumber).toBe(2);expect(message.destinationStage).toBe("B");
        expect(message.ctaUrl).toInclude("recoveryAction=planner");
        expect(variables.fixture.state(member.userId,2).ATTEMPT_COUNT).toBe(2);
        expect(variables.fixture.state(member.userId,3).HAS_ROW).toBeFalse();
      });

      it("concurrent sender workers submit only one new contact or definite retry",function(){
        for(var retry in [false,true]){
          var member=variables.fixture.createMember("C");
          if(retry){
            variables.fixture.configure(outcome="FAILED");
            expect(variables.fixture.service().processBatch(1,false).failed).toBe(1);
          }
          variables.fixture.configure(race="barrier");
          var names=[];
          for(var worker=1;worker LTE 2;worker++){
            var name="recoverySender" & replace(createUUID(),"-","","all");
            arrayAppend(names,name);
            thread name=name action="run" fixture=variables.fixture {
              thread.result=attributes.fixture.service().processBatch(1,false);
              thread.acceptedSubmissions=attributes.fixture.submittedCount();
            }
          }
          thread action="join" name=arrayToList(names) timeout=20000;
          var sent=0;var submitted=0;
          for(var name in names){
            expect(cfthread[name].status).toBe("COMPLETED");
            sent+=cfthread[name].result.sent;submitted+=cfthread[name].acceptedSubmissions;
          }
          expect(sent).toBe(1);expect(submitted).toBe(1);
          expect(variables.fixture.counts().ledger).toBe(1);
          expect(variables.fixture.state(member.userId,1).ATTEMPT_COUNT).toBe(retry ? 2 : 1);
          variables.fixture.cleanup();variables.fixture=new fpw.tests.support.RecoveryOrchestrationFixture();
        }
      });

      it("reports missing transport outcome and failed observation while holding the claim",function(){
        var member=variables.fixture.createMember("A");
        var observer=prepareMock(new fpw.tests.support.RecoveryCoreObservationStub(messageId=123));
        observer.$(method="finalizeMessage",throwException=true,throwType="tests.ObservationFailure",throwMessage="CONTROLLED_OBSERVATION_FAILURE");
        var transport=createStub().$("submitInactiveMemberRecoveryEmail",{CODE="CONTROLLED_MISSING_OUTCOME"});
        var sender=prepareMock(variables.fixture.service());
        sender.$property("observability","variables",observer);
        sender.$property("transport","variables",transport);
        var run=sender.processBatch(1,false);
        expect(run.ambiguous).toBe(1);expect(run.sent).toBe(0);
        expect(run.observation_gaps).toBe(1);
        expect(run.reasons.TRANSPORT_OUTCOME_UNKNOWN).toBe(1);
        expect(observer.$count("finalizeMessage")).toBe(1);
        expect(observer.$callLog().finalizeMessage[1][1]).toBe(123);
        expect(observer.$callLog().finalizeMessage[1][2]).toBe("OUTCOME_UNKNOWN");
        expect(variables.fixture.state(member.userId,1).STATUS).toBe("CLAIMED");
        expect(sender.processBatch(1,false).claimed).toBe(0);
        expect(transport.$count("submitInactiveMemberRecoveryEmail")).toBe(1);
      });

      it("reports an unavailable observer during dry run without claiming or sending",function(){
        var member=variables.fixture.createMember("A");
        var sender=prepareMock(variables.fixture.service());
        sender.$property("observability","variables","");
        var run=sender.processBatch(1,true);
        expect(run.eligible).toBe(1);expect(run.run_id).toBe(0);
        expect(run.observation_gaps).toBe(1);
        expect(run.claimed).toBe(0);expect(run.sent).toBe(0);
        expect(variables.fixture.state(member.userId,1).HAS_ROW).toBeFalse();
        expect(variables.fixture.attemptCount()).toBe(0);
      });

      it("holds absent enrollment, rejects unbounded batches, and defaults live sending off",function() {
        variables.fixture.createMember("A");
        variables.fixture.configure(missingEnrollment=true);
        expect(variables.fixture.service().processBatch(25,false).reasons.ENROLLMENT_EVIDENCE_REQUIRED).toBe(1);
        expect(variables.fixture.service().processBatch(101,false).ok).toBeFalse();
        expect(variables.fixture.service().processBatch(0,false).ok).toBeFalse();
        expect(variables.fixture.service().processBatch(1.5,false).ok).toBeFalse();
        expect(new fpw.api.v1.InactiveMemberRecoveryService().processBatch(25,false).error).toBe("LIVE_MODE_DISABLED");
        expect(variables.fixture.counts().ledger).toBe(0);
      });
    });
  }
}
