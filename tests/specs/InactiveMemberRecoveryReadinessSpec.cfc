component extends="testbox.system.BaseSpec" output="false" {
  function run() {
    describe("Recovery coverage and retained share-attempt authority",function() {
      beforeEach(function(){variables.fixture=new fpw.tests.support.RecoveryReadinessFixture();variables.coverage=new fpw.includes.InactiveMemberRecoveryCoverageService();});
      afterEach(function(){fixture.cleanup();expect(fixture.counts().users).toBe(0);expect(fixture.counts().events).toBe(0);expect(fixture.counts().ledger).toBe(0);});
      it("binds canonical signup and versioned coverage in DB UTC without enrollment",function(){
        var before=fixture.dbUtc();var m=fixture.fresh();var after=fixture.dbUtc();
        expect(coverage.getCoverageVerification(m.userId).stage_history).toBeTrue();
        expect(coverage.getEnrollmentUtc(m.userId)).toBe("");
        var e=queryExecute("SELECT metadata_json,DATE_FORMAT(occurred_at_utc,'%Y-%m-%dT%H:%i:%sZ') AS at_utc FROM product_events WHERE user_id=:id AND event_name='recovery_coverage_started'",p(m.userId),{datasource="fpw"});
        expect(deserializeJSON(e.metadata_json[1]).contract_version).toBe("v1");
        expect(compare(e.at_utc[1],before) GTE 0 AND compare(e.at_utc[1],after) LTE 0).toBeTrue();
      });
      it("admits only the verified canonical Basic zero-vessel Draft into normal D timing",function(){
        var m=fixture.fresh();fixture.basicDraft(m.userId);
        var service=new fpw.includes.InactiveMemberRecoveryClassifierService();makePublic(service,"loadLiveEvidence");
        expect(service.loadLiveEvidence(m.userId).LIFECYCLE_CONFLICT).toBeFalse();
        var enrolled=new fpw.includes.InactiveMemberRecoveryEnrollmentService().ensureEnrolled(m.userId);
        expect(enrolled.CODE).toBe("ENROLLED");
        expect(service.evaluateMember(m.userId,fixture.plusSeconds(enrolled.ENROLLMENT_UTC,604799)).ELIGIBLE).toBeFalse();
        var due=service.evaluateMember(m.userId,fixture.plusSeconds(enrolled.ENROLLMENT_UTC,604800));
        expect(due.CURRENT_STAGE).toBe("D");expect(due.ELIGIBLE).toBeTrue();
      });
      for (var invalidMarker in ["missing_details","wrong_origin","reusable","visible","route_reference","route_day","operator_zero","missing_positive_vessel","foreign_positive_vessel"]) {
        var marker=invalidMarker;
        it(title="holds unexpected or mismatched Basic vessel reference: " & marker,data={marker=marker},body=function(data){
          var m=fixture.fresh();var id=fixture.basicDraft(m.userId);var sql="";
          switch(data.marker) {
            case "missing_details":sql="DELETE FROM floatplan_basic_details WHERE floatplan_id=:id";break;
            case "wrong_origin":sql="UPDATE floatplans SET route_origin='basic_manual' WHERE floatplanId=:id";break;
            case "reusable":sql="UPDATE floatplans SET is_reusable=1 WHERE floatplanId=:id";break;
            case "visible":sql="UPDATE floatplans SET is_visible_in_route_library=1 WHERE floatplanId=:id";break;
            case "route_reference":sql="UPDATE floatplans SET route_instance_id=0 WHERE floatplanId=:id";break;
            case "route_day":sql="UPDATE floatplans SET route_day_number=1 WHERE floatplanId=:id";break;
            case "operator_zero":sql="UPDATE floatplans SET operatorId=0 WHERE floatplanId=:id";break;
            case "missing_positive_vessel":sql="UPDATE floatplans SET vesselId=2147483647 WHERE floatplanId=:id";break;
            case "foreign_positive_vessel":
              var other=fixture.createMember("B");
              queryExecute("UPDATE floatplans SET vesselId=:vesselId WHERE floatplanId=:id",
                {id={value=id,cfsqltype="cf_sql_integer"},vesselId={value=other.vesselId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});break;
          }
          if (len(sql)) queryExecute(sql,p(id),{datasource="fpw"});
          var service=new fpw.includes.InactiveMemberRecoveryClassifierService();makePublic(service,"loadLiveEvidence");
          expect(service.loadLiveEvidence(m.userId).LIFECYCLE_CONFLICT).toBeTrue();
          expect(service.evaluateMember(m.userId,fixture.dbUtc()).DECISION_CODE).toBe("HOLD_CONTRADICTORY_EVIDENCE");
        });
      }
      it("database rejects missing canonical scope flags without changing the Draft",function(){
        var m=fixture.fresh();var id=fixture.basicDraft(m.userId);
        for (var field in ["route_origin","is_reusable","is_visible_in_route_library"]) {
          var column=field;
          expect(function(){queryExecute("UPDATE floatplans SET " & column & "=NULL WHERE floatplanId=:id",p(id),{datasource="fpw"});}).toThrow();
        }
        var service=new fpw.includes.InactiveMemberRecoveryClassifierService();makePublic(service,"loadLiveEvidence");
        expect(service.loadLiveEvidence(m.userId).LIFECYCLE_CONFLICT).toBeFalse();
      });
      it("does not borrow another plan's Basic-details row",function(){
        var m=fixture.fresh();var id=fixture.basicDraft(m.userId);var other=fixture.fresh();fixture.basicDraft(other.userId);
        queryExecute("DELETE FROM floatplan_basic_details WHERE floatplan_id=:id",p(id),{datasource="fpw"});
        expect(new fpw.includes.InactiveMemberRecoveryClassifierService().evaluateMember(m.userId,fixture.dbUtc()).DECISION_CODE).toBe("HOLD_CONTRADICTORY_EVIDENCE");
      });
      it("preserves normal owned positive vessel references without requiring Basic markers",function(){
        var m=fixture.createMember("B");var id=fixture.draft(m.userId);
        queryExecute("UPDATE floatplans SET vesselId=:vesselId WHERE floatplanId=:id",
          {id={value=id,cfsqltype="cf_sql_integer"},vesselId={value=m.vesselId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
        var service=new fpw.includes.InactiveMemberRecoveryClassifierService();makePublic(service,"loadLiveEvidence");
        expect(service.loadLiveEvidence(m.userId).LIFECYCLE_CONFLICT).toBeFalse();
      });
      for(var failureMode in ["before","after"]) {
        var mode=failureMode;
        it(title="rolls back user signup and both events on coverage failure " & mode,data={mode=mode},body=function(data){
          expect(function(){fixture.fresh(new fpw.tests.support.RecoveryCoverageEventFailure(mode=data.mode));}).toThrow();
          expect(fixture.counts().users).toBe(0);expect(fixture.counts().events).toBe(0);
        });
      }
      it("does not grant coverage to enrolled older accounts or re-attest existing history",function(){
        var m=fixture.createMember();var at=new fpw.includes.InactiveMemberRecoveryEnrollmentService().ensureEnrolled(m.userId).ENROLLMENT_UTC;
        expect(coverage.getCoverageVerification(m.userId).sharing_history).toBeFalse();
        expect(function(){coverage.recordSignupInCurrentTransaction(m.userId,{});}).toThrow();
        expect(new fpw.includes.InactiveMemberRecoveryClassifierService().evaluateMember(m.userId,fixture.plusSeconds(at,604800)).DECISION_CODE).toBe("HOLD_INCOMPLETE_COVERAGE");
      });
      for(var mutation in ["version","binding","owner","future","missing_signup"]) {
        var mode=mutation;
        it(title="holds corrupt coverage " & mode,data={mode=mode},body=function(data){
          var m=fixture.fresh();var sql="";
          switch(data.mode){
            case "version":sql="UPDATE product_events SET metadata_json=JSON_OBJECT('contract_version','v99') WHERE user_id=:id AND event_name='recovery_coverage_started'";break;
            case "binding":sql="UPDATE product_events SET request_correlation_id='bad' WHERE user_id=:id AND event_name='recovery_coverage_started'";break;
            case "owner":sql="UPDATE product_events SET entity_id=entity_id+1 WHERE user_id=:id AND event_name='recovery_coverage_started'";break;
            case "future":sql="UPDATE product_events SET occurred_at_utc=UTC_TIMESTAMP()+INTERVAL 1 DAY WHERE user_id=:id AND event_name='recovery_coverage_started'";break;
            case "missing_signup":sql="DELETE FROM product_events WHERE user_id=:id AND event_name='sign_up'";break;
          }
          queryExecute(sql,p(m.userId),{datasource="fpw"});expect(coverage.getCoverageVerification(m.userId).activity_coverage).toBeFalse();
        });
      }
      for(var shareSource in ["basic_save_send","basic_review_send","premium_save_send"]) {
        var source=shareSource;
        it(title="retains unresolved HOLD and successful suppression after deletion for " & source,data={source=source},body=function(data){
          var m=fixture.fresh();var id=fixture.draft(m.userId);
          var token=coverage.beginShare(m.userId,id,data.source);
          expect(coverage.getShareEvidence(m.userId).UNRESOLVED).toBeTrue();
          fixture.deletePlanningRows(m.userId);
          expect(new fpw.includes.InactiveMemberRecoveryClassifierService().evaluateMember(m.userId,fixture.dbUtc()).DECISION_CODE).toBe("HOLD_UNRESOLVED_SHARE_ATTEMPT");
          coverage.finishShare(m.userId,token,"succeeded");
          expect(coverage.getShareEvidence(m.userId).SUCCESSFUL).toBeTrue();
          expect(new fpw.includes.InactiveMemberRecoveryClassifierService().evaluateMember(m.userId,fixture.dbUtc()).DECISION_CODE).toBe("SUPPRESSED_ALREADY_SHARED");
          expect(function(){coverage.finishShare(m.userId,token,"failed");}).toThrow();
        });
      }
      it("definitive failure clears only its own unresolved state and permits recovery",function(){
        var m=fixture.fresh();var id=fixture.draft(m.userId);var t=coverage.beginShare(m.userId,id,"basic_save_send");
        coverage.finishShare(m.userId,t,"failed");
        expect(coverage.getShareEvidence(m.userId).FAILED_COUNT).toBe(1);expect(coverage.getShareEvidence(m.userId).SUCCESSFUL).toBeFalse();
        var at=new fpw.includes.InactiveMemberRecoveryEnrollmentService().ensureEnrolled(m.userId).ENROLLMENT_UTC;
        expect(new fpw.includes.InactiveMemberRecoveryClassifierService().evaluateMember(m.userId,fixture.plusSeconds(at,604800)).ELIGIBLE).toBeTrue();
        coverage.beginShare(m.userId,id,"premium_save_send");expect(coverage.getShareEvidence(m.userId).UNRESOLVED).toBeTrue();
      });
      it("rejects cross-member attempt ownership and source spoofing",function(){
        var a=fixture.fresh();var b=fixture.fresh();var id=fixture.draft(a.userId);
        expect(function(){coverage.beginShare(b.userId,id,"premium_save_send");}).toThrow();
        expect(function(){coverage.beginShare(a.userId,id,"scheduler");}).toThrow();
        var t=coverage.beginShare(a.userId,id,"premium_save_send");
        expect(function(){coverage.finishShare(b.userId,t,"succeeded");}).toThrow();
        expect(coverage.getShareEvidence(a.userId).UNRESOLVED).toBeTrue();
      });
      it("retains the attempt across a domain rollback and leaves failed outcome persistence unresolved",function(){
        var m=fixture.fresh();var id=fixture.draft(m.userId);var t=coverage.beginShare(m.userId,id,"premium_save_send");
        transaction { queryExecute("UPDATE floatplans SET status='ACTIVE' WHERE floatPlanId=:id",p(id),{datasource="fpw"});transaction action="rollback"; }
        expect(coverage.getShareEvidence(m.userId).UNRESOLVED).toBeTrue();
        var broken=new fpw.includes.InactiveMemberRecoveryCoverageService(eventService=new fpw.tests.support.RecoveryEnrollmentEventFailure(mode="after"));
        expect(function(){broken.finishShare(m.userId,t,"succeeded");}).toThrow();
        expect(coverage.getShareEvidence(m.userId).UNRESOLVED).toBeTrue();expect(coverage.getShareEvidence(m.userId).SUCCESSFUL).toBeFalse();
      });
      it("revalidates newly unresolved sharing before submission and rolls back the recovery claim",function(){
        var m=fixture.fresh();var id=fixture.draft(m.userId);var at=new fpw.includes.InactiveMemberRecoveryEnrollmentService().ensureEnrolled(m.userId).ENROLLMENT_UTC;
        fixture.setTestNow(fixture.plusSeconds(at,604800));
        var sender=fixture.dueSender(new fpw.tests.support.RecoveryCoverageRaceClassifier(m.userId,id));
        var r=sender.processBatch(batchSize=1,dryRun=false);
        expect(r.sent).toBe(0);expect(r.canceled).toBe(1);expect(r.reasons.HOLD_UNRESOLVED_SHARE_ATTEMPT).toBe(1);
        expect(fixture.counts().ledger).toBe(0);expect(fixture.attemptCount()).toBe(0);
      });
      it("holds mismatched terminal records and keeps attempt metadata PII-free",function(){
        var m=fixture.fresh();var id=fixture.draft(m.userId);var t=coverage.beginShare(m.userId,id,"basic_review_send");coverage.finishShare(m.userId,t,"failed");
        var rows=queryExecute("SELECT metadata_json FROM product_events WHERE user_id=:id AND event_name LIKE 'recovery_share_%'",p(m.userId),{datasource="fpw"});
        for(var row in rows) expect(toString(row.metadata_json)).toBe("{}");
        queryExecute("UPDATE product_events SET entity_id=entity_id+1 WHERE user_id=:id AND event_name='recovery_share_failed'",p(m.userId),{datasource="fpw"});
        expect(coverage.getShareEvidence(m.userId).INVALID).toBeTrue();
      });
    });
  }
  private struct function p(required numeric id){return {id={value=arguments.id,cfsqltype="cf_sql_integer"}};}
}
