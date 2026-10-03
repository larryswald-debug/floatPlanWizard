component extends="testbox.system.BaseSpec" output="false" {
  function run() {
    describe("Inactive member recovery contact ledger",function(){
      beforeEach(function(){ variables.fixture=new fpw.tests.support.RecoveryOrchestrationFixture(); variables.ledger=new fpw.includes.InactiveMemberRecoveryLedgerService(); });
      afterEach(function(){ variables.fixture.cleanup(); });
      it("exposes dedicated contact operations and rejects invalid identities",function(){
        expect(structKeyExists(variables.ledger,"claimContact")).toBeTrue();
        expect(structKeyExists(variables.ledger,"retryFailedContact")).toBeTrue();
        expect(structKeyExists(variables.ledger,"getSequenceState")).toBeTrue();
        expect(variables.ledger.claimContact(1,1,4,"A").CODE).toBe("INVALID_CONTACT_NUMBER");
        expect(variables.ledger.claimContact(1,1,1,"Z").CODE).toBe("INVALID_DESTINATION_STAGE");
        expect(variables.ledger.claimContact(2147483647,1,1,"A").CODE).toBe("MEMBER_NOT_FOUND");
      });
      it("has distinct enrollment contact and destination columns and durable uniqueness",function(){
        var columns=queryExecute("SELECT column_name FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name='inactive_member_recovery_deliveries'",{},{datasource="fpw"});
        expect(columns.recordCount).toBe(14);
        var uniqueIndex=queryExecute("SELECT GROUP_CONCAT(column_name ORDER BY seq_in_index) names FROM information_schema.statistics WHERE table_schema=DATABASE() AND table_name='inactive_member_recovery_deliveries' AND index_name='uq_recovery_enrollment_contact' AND non_unique=0",{},{datasource="fpw"});
        expect(uniqueIndex.names[1]).toBe("recovery_enrollment_event_id,contact_number");
        var fk=queryExecute("SELECT delete_rule FROM information_schema.referential_constraints WHERE constraint_schema=DATABASE() AND table_name='inactive_member_recovery_deliveries' AND constraint_name='fk_inactive_recovery_user'",{},{datasource="fpw"});
        expect(fk.delete_rule[1]).toBe("CASCADE");
        var checks=queryExecute("SELECT COUNT(*) total FROM information_schema.table_constraints WHERE constraint_schema=DATABASE() AND table_name='inactive_member_recovery_deliveries' AND constraint_type='CHECK'",{},{datasource="fpw"});
        expect(val(checks.total[1])).toBe(5);
      });
      it("keeps diagnostic reads free of claim secrets and requires the member's canonical enrollment",function(){
        var first=variables.fixture.createMember("A"); var second=variables.fixture.createMember("A");
        var enrollment=variables.fixture.enrollmentId(first.userId);
        var state=variables.ledger.getContactState(first.userId,enrollment,1);
        expect(state.CODE).toBe("NOT_CLAIMED");
        expect(structKeyExists(state,"CLAIM_TOKEN")).toBeFalse();
        expect(variables.ledger.getLastSuccessfulRecoveryUtc(first.userId).HAS_SENT).toBeFalse();
        expect(variables.ledger.claimContact(first.userId,variables.fixture.enrollmentId(second.userId),1,"A").CODE).toBe("ENROLLMENT_MISMATCH");
      });
      it("accepts all three contacts at destination A and cannot skip, duplicate, or restart",function(){
        var member=variables.fixture.createMember("A"); var enrollment=variables.fixture.enrollmentId(member.userId);
        expect(variables.ledger.claimContact(member.userId,enrollment,2,"A").CODE).toBe("CONTACT_SEQUENCE_CONFLICT");
        for(var contact=1;contact LTE 3;contact++){
          var claimed=variables.ledger.claimContact(member.userId,enrollment,contact,"A");
          expect(claimed.CLAIMED).toBeTrue();
          expect(variables.ledger.claimContact(member.userId,enrollment,contact,"A").CODE).toBe("ALREADY_CLAIMED");
          expect(variables.ledger.markSent(member.userId,enrollment,contact,repeatString("f",64)).CODE).toBe("CLAIM_MISMATCH");
          expect(variables.ledger.markSent(member.userId,enrollment,contact,claimed.CLAIM_TOKEN).CODE).toBe("SENT");
          expect(variables.ledger.getContactState(member.userId,enrollment,contact).DESTINATION_STAGE).toBe("A");
        }
        var sequence=variables.ledger.getSequenceState(member.userId);
        expect(sequence.COMPLETED).toBeTrue(); expect(sequence.NEXT_CONTACT_NUMBER).toBe(0);
        expect(variables.ledger.claimContact(member.userId,enrollment,1,"B").CODE).toBe("ALREADY_SENT");
        expect(variables.ledger.claimContact(member.userId,enrollment,4,"D").CODE).toBe("INVALID_CONTACT_NUMBER");
      });
      it("rejects a future accepted timestamp before reporting a completed sequence",function(){
        var member=variables.fixture.createMember("A"); var enrollment=variables.fixture.enrollmentId(member.userId);
        for(var contact=1;contact LTE 3;contact++){
          var claimed=variables.ledger.claimContact(member.userId,enrollment,contact,"A");
          expect(variables.ledger.markSent(member.userId,enrollment,contact,claimed.CLAIM_TOKEN).CODE).toBe("SENT");
        }
        queryExecute("UPDATE inactive_member_recovery_deliveries SET sent_at_utc=DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 1 DAY) WHERE user_id=:id AND contact_number=3",
          {id={value=member.userId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
        var sequence=variables.ledger.getSequenceState(member.userId);
        expect(sequence.SUCCESS).toBeFalse();expect(sequence.COMPLETED).toBeFalse();
        expect(sequence.CODE).toBe("CONTACT_HISTORY_CONFLICT");
        expect(new fpw.includes.InactiveMemberRecoveryClassifierService(settingsService=variables.fixture)
          .evaluateMember(member.userId,variables.fixture.nowUtc(),"","",false,variables.fixture.getCoverageVerification(member.userId)).DECISION_CODE).toBe("HOLD_CONTACT_HISTORY_CONFLICT");
      });

      it("serializes concurrent claims for the same enrollment and contact",function(){
        var member=variables.fixture.createMember("A"); var enrollment=variables.fixture.enrollmentId(member.userId);
        var names=[];
        for(var attempt=1;attempt LTE 2;attempt++){
          var name="recoveryContactClaim" & replace(createUUID(),"-","","all");
          arrayAppend(names,name);
          thread name=name action="run" uid=member.userId enrollment=enrollment {
            thread.result=new fpw.includes.InactiveMemberRecoveryLedgerService().claimContact(attributes.uid,attributes.enrollment,1,"A");
          }
        }
        thread action="join" name=arrayToList(names) timeout=10000;
        var winners=0;var duplicates=0;
        for(var name in names){
          expect(cfthread[name].status).toBe("COMPLETED");
          if(cfthread[name].result.CODE EQ "CLAIMED") winners++;
          if(cfthread[name].result.CODE EQ "ALREADY_CLAIMED") duplicates++;
        }
        expect(winners).toBe(1);expect(duplicates).toBe(1);
        expect(variables.fixture.counts().ledger).toBe(1);
      });

      it("retries a failed transport within its same contact with fresh destination and bounded attempts",function(){
        var member=variables.fixture.createMember("A"); var enrollment=variables.fixture.enrollmentId(member.userId);
        var claimed=variables.ledger.claimContact(member.userId,enrollment,1,"A");
        for(var attempt=1;attempt LTE 3;attempt++){
          expect(variables.ledger.markFailed(member.userId,enrollment,1,claimed.CLAIM_TOKEN,"CONTROLLED_FAILURE").CODE).toBe("FAILED");
          expect(variables.ledger.getSequenceState(member.userId).NEXT_CONTACT_NUMBER).toBe(1);
          expect(variables.ledger.claimContact(member.userId,enrollment,2,"B").CODE).toBe("CONTACT_SEQUENCE_CONFLICT");
          if(attempt LT 3) claimed=variables.ledger.retryFailedContact(member.userId,enrollment,1,"B");
        }
        expect(variables.ledger.retryFailedContact(member.userId,enrollment,1,"C").CODE).toBe("RETRY_EXHAUSTED");
        var terminal=variables.ledger.getContactState(member.userId,enrollment,1);
        expect(terminal.ATTEMPT_COUNT).toBe(3); expect(terminal.DESTINATION_STAGE).toBe("B");
      });
    });
  }
}
