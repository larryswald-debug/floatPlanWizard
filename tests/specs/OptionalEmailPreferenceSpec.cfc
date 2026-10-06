component extends="testbox.system.BaseSpec" output="false" {
  function run() {
    describe("Canonical member optional email preferences",function() {
      beforeEach(function() {
        variables.fixture=new fpw.tests.support.RecoveryOrchestrationFixture();
        variables.member=variables.fixture.createMember("A");
        variables.service=new fpw.api.v1.EmailOptOutService();
      });
      afterEach(function() { variables.fixture.cleanup(); });

      it("persists OFF idempotently and ON restores eligibility",function() {
        expect(variables.service.getMemberOptionalEmailPreference(variables.member.userId).optionalEmailsEnabled).toBeTrue();
        for(var i=1;i LTE 2;i++) {
          var saved=variables.service.setMemberOptionalEmailPreference(variables.member.userId,false,"127.0.0.1","optional-email-test");
          expect(saved.success).toBeTrue();
          expect(saved.optionalEmailsEnabled).toBeFalse();
        }
        var row=queryExecute("SELECT COUNT(*) n,MIN(source) source,MIN(created_at IS NOT NULL) has_created,MIN(updated_at IS NOT NULL) has_updated FROM email_optout WHERE user_id=:id",
          {id={value=variables.member.userId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
        expect(row.n[1]).toBe(1);
        expect(row.source[1]).toBe("account_preferences");
        expect(row.has_created[1]).toBe(1);
        expect(row.has_updated[1]).toBe(1);
        expect(new fpw.api.v1.email().checkNonEssentialEmailEligibility(variables.member.email,variables.member.userId).code).toBe("OPTED_OUT");
        expect(variables.service.setMemberOptionalEmailPreference(variables.member.userId,true).optionalEmailsEnabled).toBeTrue();
        expect(variables.service.setMemberOptionalEmailPreference(variables.member.userId,true).optionalEmailsEnabled).toBeTrue();
        expect(new fpw.api.v1.email().checkNonEssentialEmailEligibility(variables.member.email,variables.member.userId).code).toBe("ELIGIBLE");
      });

      it("reenables only the current address and nonessential type",function() {
        var other=variables.fixture.createMember("A");
        var previous="previous-" & variables.member.email;
        variables.service.recordOptOut(previous,variables.member.userId);
        variables.service.recordOptOut(other.email,other.userId);
        variables.service.setMemberOptionalEmailPreference(variables.member.userId,false);
        queryExecute("INSERT INTO email_optout (user_id,email,email_hash,opt_out_type,date_added) VALUES (:id,:email,:hash,'test_other_type',UTC_TIMESTAMP())",
          {id={value=variables.member.userId,cfsqltype="cf_sql_integer"},email={value=variables.member.email,cfsqltype="cf_sql_varchar"},
           hash={value=lCase(hash(variables.member.email,"SHA-256","UTF-8")),cfsqltype="cf_sql_char"}},{datasource="fpw"});
        variables.service.setMemberOptionalEmailPreference(variables.member.userId,true);
        expect(variables.service.isOptedOut(variables.member.email)).toBeFalse();
        expect(variables.service.isOptedOut(previous)).toBeTrue();
        expect(variables.service.isOptedOut(other.email)).toBeTrue();
        var otherType=queryExecute("SELECT COUNT(*) n FROM email_optout WHERE user_id=:id AND opt_out_type='test_other_type'",
          {id={value=variables.member.userId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
        expect(otherType.n[1]).toBe(1);
      });

      it("normalizes the current stored address and refuses absent members",function() {
        queryExecute("UPDATE users SET email=:email WHERE userId=:id",
          {id={value=variables.member.userId,cfsqltype="cf_sql_integer"},email={value=" " & uCase(variables.member.email) & " ",cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
        expect(variables.service.setMemberOptionalEmailPreference(variables.member.userId,false).success).toBeTrue();
        expect(variables.service.isOptedOut(variables.member.email)).toBeTrue();
        expect(variables.service.setMemberOptionalEmailPreference(variables.member.userId,true).success).toBeTrue();
        expect(variables.service.isOptedOut(variables.member.email)).toBeFalse();
        expect(variables.service.getMemberOptionalEmailPreference(-1).success).toBeFalse();
        expect(variables.service.setMemberOptionalEmailPreference(-1,true).success).toBeFalse();
      });

      it("rechecks personal recovery after review and allows it again only after ON",function() {
        var mail=prepareMock(new fpw.api.v1.email());
        mail.$("sendMultipartEmail");
        var admin=new fpw.api.v1.AdminRecoveryCenterService(emailService=mail);
        makePublic(admin,"personalPreparation","preparePersonalForTest");
        makePublic(admin,"personalSend","sendPersonalForTest");
        var review=admin.preparePersonalForTest(variables.member.userId,"Local personal follow-up","Hello");
        review.operationId=createUUID();
        try {
          variables.service.setMemberOptionalEmailPreference(variables.member.userId,false);
          expect(function(){admin.preparePersonalForTest(variables.member.userId,"Test","Body");}).toThrow();
          expect(function(){admin.sendPersonalForTest(review,variables.member.userId);}).toThrow();
          expect(mail.$count("sendMultipartEmail")).toBe(0);
          variables.service.setMemberOptionalEmailPreference(variables.member.userId,true);
          review=admin.preparePersonalForTest(variables.member.userId,"Local personal follow-up","Hello");
          review.operationId=createUUID();
          var sent=admin.sendPersonalForTest(review,variables.member.userId);
          expect(sent.status).toBe("SEND_ACCEPTED");
          expect(sent.observationGap).toBeFalse();
          expect(mail.$count("sendMultipartEmail")).toBe(1);
          expect(mail.$callLog().sendMultipartEmail[1].textBody).toInclude("/unsubscribe.cfm?t=");
          expect(queryExecute("SELECT COUNT(*) n FROM inactive_member_recovery_deliveries WHERE user_id=:id",
            {id={value=variables.member.userId,cfsqltype="cf_sql_integer"}},{datasource="fpw"}).n[1]).toBe(0);
        } finally {
          queryExecute("DELETE FROM fpw_admin_audit_log WHERE admin_user_id=:id",
            {id={value=variables.member.userId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
        }
      });

      it("suppresses recovery before transport and restores normal eligibility after ON",function() {
        variables.fixture.setTiming(24,24);
        variables.service.setMemberOptionalEmailPreference(variables.member.userId,false);
        var suppressed=variables.fixture.service().processBatch(1,false);
        expect(suppressed.reasons.SUPPRESSED_OPTED_OUT).toBe(1);
        expect(variables.fixture.attemptCount()).toBe(0);
        variables.service.setMemberOptionalEmailPreference(variables.member.userId,true);
        var enabled=variables.fixture.service().processBatch(1,false);
        expect(enabled.sent).toBe(1);
        expect(variables.fixture.attemptCount()).toBe(1);
      });
    });
  }
}
