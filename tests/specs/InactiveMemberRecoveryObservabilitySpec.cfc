component extends="testbox.system.BaseSpec" output=false {
  function run() {
    describe("Recovery Center observability, tracking and attribution",function() {
      beforeEach(function() {try {setup();} catch(any setupFailure) {cleanup();rethrow;}});
      afterEach(function() {cleanup();});
      it("persists a stable initial decision and terminal cancellation with independent contact and destination",function() {
        var run=variables.observer.beginRun("test",true,{revision=1,firstDelayHours=24,stageIntervalHours=24,attributionWindowHours=24});
        arrayAppend(variables.runIds,run);
        var id=variables.observer.recordEvaluation(run,variables.userId,{CURRENT_STAGE="B",CONTACT_NUMBER=2,CONTACT_TOTAL=3,
          ENROLLMENT_EVENT_ID=variables.enrollmentId,ELIGIBLE=true,DECISION="ELIGIBLE",DECISION_CODE="ELIGIBLE",
          POLICY_DECISION={ELIGIBLE_AT_UTC="2026-10-03T00:00:00Z"}});
        variables.observer.finalizeEvaluation(id,{category="held",code="PRE_SEND_CANCELED"});
        variables.observer.finishRun(run,{ok=true,scanned=1,eligible=1,held=1,canceled=1});
        var row=queryExecute("SELECT * FROM inactive_member_recovery_evaluations WHERE id=:id",params(id),{datasource="fpw"});
        expect(row.contact_number[1]).toBe(2);expect(row.destination_stage[1]).toBe("B");
        expect(row.initial_decision[1]).toBe("ELIGIBLE");expect(row.final_reason[1]).toBe("PRE_SEND_CANCELED");
        variables.observer.finalizeEvaluation(id,{category="sent",code="SHOULD_NOT_OVERWRITE"});
        row=queryExecute("SELECT final_reason FROM inactive_member_recovery_evaluations WHERE id=:id",params(id),{datasource="fpw"});
        expect(row.final_reason[1]).toBe("PRE_SEND_CANCELED");
      });
      it("reports missing evaluation telemetry as a completed run with explicit observation gaps",function() {
        var run=variables.observer.beginRun("test",true,{revision=1});
        arrayAppend(variables.runIds,run);
        variables.observer.finishRun(run,{ok=true,scanned=1,skipped=1,observation_gaps=1});
        var row=queryExecute("SELECT status,error_code,waiting_count FROM inactive_member_recovery_runs WHERE id=:id",params(run),{datasource="fpw"});
        expect(row.status[1]).toBe("COMPLETED_WITH_GAPS");expect(row.error_code[1]).toBe("OBSERVATION_GAPS");expect(row.waiting_count[1]).toBe(0);
      });
      it("prepares distinct purpose-bound opaque tokens and tracks repeated opens atomically",function() {
        var msg=accepted(1,"A");
        var openToken=listLast(msg.openUrl,"=");
        var clickToken=listLast(msg.clickUrl,"=");
        expect(reFind("^[a-f0-9]{64}[.][a-f0-9]{64}$",openToken)).toBe(1);
        expect(openToken EQ clickToken).toBeFalse();
        expect(variables.tracking.recordOpen(clickToken)).toBeFalse();
        expect(variables.tracking.recordOpen(openToken)).toBeTrue();
        expect(variables.tracking.recordOpen(openToken)).toBeTrue();
        var row=message(msg.messageId);expect(row.open_count[1]).toBe(2);expect(row.click_count[1]).toBe(0);
        var events=queryExecute("SELECT COUNT(*) n FROM product_events WHERE user_id=:id AND event_name='recovery_opened'",params(variables.userId),{datasource="fpw"});
        expect(events.n[1]).toBe(1);
      });
      it("rejects tampering, nonaccepted messages, and tracking beyond 90 days",function() {
        var msg=prepared(1,"A");var token=listLast(msg.openUrl,"=");
        expect(variables.tracking.recordOpen(token)).toBeFalse();
        variables.observer.finalizeMessage(msg.messageId,"SEND_ACCEPTED",utc(-91));
        expect(variables.tracking.recordOpen(token)).toBeFalse();
        expect(variables.tracking.recordOpen(left(token,128) & (right(token,1) EQ "a" ? "b" : "a"))).toBeFalse();
        expect(message(msg.messageId).open_count[1]).toBe(0);
      });
      it("does not record a signal that expires after verification but before its guarded update",function() {
        var msg=prepared(1,"A");variables.observer.finalizeMessage(msg.messageId,"SEND_ACCEPTED",utc(-91));
        makePublic(variables.tracking,"signal");
        var stale=message(msg.messageId);
        expect(variables.tracking.signal(stale,"open")).toBeFalse();
        expect(message(msg.messageId).open_count[1]).toBe(0);
        expect(queryExecute("SELECT COUNT(*) n FROM product_events WHERE user_id=:id AND event_name='recovery_opened'",params(variables.userId),{datasource="fpw"}).n[1]).toBe(0);
      });
      it("keeps late opens visible without extending frozen attribution",function() {
        var msg=prepared(1,"C");variables.observer.finalizeMessage(msg.messageId,"SEND_ACCEPTED",utc(-2));
        var deadline=message(msg.messageId).attribution_deadline_utc[1];
        expect(variables.tracking.recordOpen(listLast(msg.openUrl,"="))).toBeTrue();
        var row=message(msg.messageId);expect(row.late_open_count[1]).toBe(1);
        expect(row.attribution_deadline_utc[1]).toBe(deadline);
      });
      it("redacts bearer tokens and disables tracking/link requests in previews",function() {
        var msg=accepted(2,"B");
        var preview=variables.observer.safePreview(msg.messageId);
        expect(findNoCase("<img",preview.htmlBody)).toBe(0);
        expect(find(listLast(msg.openUrl,"="),preview.htmlBody)).toBe(0);
        expect(find(listLast(msg.clickUrl,"="),preview.textBody)).toBe(0);
        expect(find("unsubscribe-secret",preview.textBody)).toBe(0);
        expect(find(encodeForHtml("unsubscribe-secret"),preview.htmlBody)).toBe(0);
        expect(find(encodeForHtmlAttribute("unsubscribe-secret"),preview.htmlBody)).toBe(0);
        expect(message(msg.messageId).open_count[1]).toBe(0);
      });
      it("attributes durable activity to the latest accepted same-member automated contact",function() {
        var one=prepared(1,"A");variables.observer.finalizeMessage(one.messageId,"SEND_ACCEPTED",utcHours(-2));
        var two=prepared(2,"A");variables.observer.finalizeMessage(two.messageId,"SEND_ACCEPTED",utcHours(-1));
        var source=sourceEvent("vessel_updated","vessel","member_api",variables.userId);
        expect(variables.attribution.reconcileMember(variables.userId)).toBe(1);
        expect(message(one.messageId).engaged_at_utc[1] EQ "").toBeTrue();
        expect(isDate(message(two.messageId).engaged_at_utc[1])).toBeTrue();
        expect(message(two.messageId).engagement_source_event_id[1]).toBe(source);
        expect(variables.attribution.reconcileMember(variables.userId)).toBe(0);
      });
      it("counts a login as returned but not engaged without an observed open or click",function() {
        var msg=accepted(1,"D");sourceEvent("login","user","password_auth",variables.userId);
        expect(variables.attribution.reconcileMember(variables.userId)).toBe(1);
        var row=message(msg.messageId);
        expect(isDate(row.returned_at_utc[1])).toBeTrue();expect(row.engaged_at_utc[1] EQ "").toBeTrue();
        expect(row.open_count[1]).toBe(0);expect(row.click_count[1]).toBe(0);
      });
      it("records authenticated page returns without fabricating meaningful engagement",function() {
        var msg=accepted(1,"A");variables.attribution.observeRequest(variables.userId,true);
        var row=message(msg.messageId);expect(isDate(row.returned_at_utc[1])).toBeTrue();expect(row.engaged_at_utc[1] EQ "").toBeTrue();
        variables.attribution.observeRequest(variables.userId,true);
        var q=queryExecute("SELECT COUNT(*) n FROM product_events WHERE user_id=:id AND event_name='recovery_authenticated_return'",params(variables.userId),{datasource="fpw"});
        expect(q.n[1]).toBe(1);
      });
      it("excludes irrelevant source contracts and activity outside the frozen window",function() {
        var msg=prepared(1,"A");variables.observer.finalizeMessage(msg.messageId,"SEND_ACCEPTED",utc(-2));
        sourceEvent("vessel_updated","vessel","member_api",variables.userId);
        sourceEvent("login","user","password_auth",variables.userId);
        expect(variables.attribution.reconcileMember(variables.userId)).toBe(0);
        expect(message(msg.messageId).returned_at_utc[1] EQ "").toBeTrue();
        // The expired contact stays unchanged even though later source evidence remains visible.
        expect(message(msg.messageId).engaged_at_utc[1] EQ "").toBeTrue();
      });
      it("honors the exact frozen attribution deadline and source timestamps",function() {
        var msg=prepared(1,"C");variables.observer.finalizeMessage(msg.messageId,"SEND_ACCEPTED",utc(-1));
        var row=message(msg.messageId);
        var source=sourceEvent("user_route_updated","user_route","member_api",variables.userId);
        queryExecute("UPDATE product_events SET occurred_at_utc=(SELECT attribution_deadline_utc FROM inactive_member_recovery_messages WHERE id=:message) WHERE id=:id",
          {id={value=source,cfsqltype="cf_sql_bigint"},message={value=msg.messageId,cfsqltype="cf_sql_bigint"}},{datasource="fpw"});
        expect(variables.attribution.reconcileMember(variables.userId)).toBe(1);
        expect(message(msg.messageId).engaged_at_utc[1]).toBe(row.attribution_deadline_utc[1]);
      });
      it("never attributes another member's event to a message",function() {
        var msg=accepted(1,"A");var other=createUser();
        sourceEvent("vessel_updated","vessel","member_api",other);
        expect(variables.attribution.reconcileMember(other)).toBe(0);
        expect(message(msg.messageId).returned_at_utc[1] EQ "").toBeTrue();
      });
      it("keeps personal submissions separate, replay protected and outside automated attribution",function() {
        var automated=accepted(1,"A");
        var context={userId=variables.userId,messageKind="PERSONAL",administratorId=variables.userId,submissionIdentity=replace(createUUID(),"-","","all")};
        var personal=variables.observer.prepareMessage(context,{toEmail=variables.email,subject="Personal note",textBody="Plain note",htmlBody="<p>Plain note</p>"});
        variables.observer.finalizeMessage(personal.messageId,"SEND_ACCEPTED");
        expect(personal.openUrl).toBe("");expect(message(personal.messageId).contact_number[1] EQ "").toBeTrue();
        expect(function(){variables.observer.prepareMessage(context,{toEmail=variables.email,subject="Personal note",textBody="Plain note",htmlBody="<p>Plain note</p>"});}).toThrow();
        sourceEvent("vessel_created","vessel","member_api",variables.userId);
        variables.attribution.reconcileMember(variables.userId);
        expect(isDate(message(automated.messageId).engaged_at_utc[1])).toBeTrue();
        expect(message(personal.messageId).engaged_at_utc[1] EQ "").toBeTrue();
      });
      it("keeps terminal status immutable and uncertain sends ineligible for tracking",function() {
        var msg=prepared(1,"A");variables.observer.finalizeMessage(msg.messageId,"OUTCOME_UNKNOWN");
        variables.observer.finalizeMessage(msg.messageId,"SEND_ACCEPTED");
        expect(message(msg.messageId).status[1]).toBe("OUTCOME_UNKNOWN");
        expect(variables.tracking.recordOpen(listLast(msg.openUrl,"="))).toBeFalse();
      });
      it("validates clicks through existing authentication continuation and rejects purpose swapping",function() {
        var msg=accepted(1,"A");
        var redirect=variables.tracking.resolveClick(listLast(msg.clickUrl,"="),"/fpw");
        expect(find("/fpw/app/login.cfm?authIntent=",redirect)).toBe(1);
        expect(message(msg.messageId).click_count[1]).toBe(1);
        expect(variables.tracking.resolveClick(listLast(msg.openUrl,"="),"/fpw")).toBe("/fpw/index.cfm");
        expect(variables.tracking.resolveClick("bad-token","/fpw")).toBe("/fpw/index.cfm");
        expect(message(msg.messageId).click_count[1]).toBe(1);
        var intent=new fpw.includes.AuthContinuationService().getIntent(listLast(redirect,"="));
        expect(intent.destinationKey).toBe("vessel");expect(intent.userId).toBe(0);
      });
      it("rejects external stored destinations and resolves deleted draft selectors to plans",function() {
        var msg=accepted(1,"D");
        queryExecute("UPDATE inactive_member_recovery_messages SET destination_path='/app/dashboard.cfm?recoveryAction=draft&floatPlanId=2147483647' WHERE id=:id",params(msg.messageId),{datasource="fpw"});
        var redirect=variables.tracking.resolveClick(listLast(msg.clickUrl,"="),"/fpw");
        var intent=new fpw.includes.AuthContinuationService().getIntent(listLast(redirect,"="));
        expect(intent.destinationKey).toBe("plans");
        queryExecute("UPDATE inactive_member_recovery_messages SET destination_path='https://evil.example/' WHERE id=:id",params(msg.messageId),{datasource="fpw"});
        expect(variables.tracking.resolveClick(listLast(msg.clickUrl,"="),"/fpw")).toBe("/fpw/index.cfm");
      });
      it("increments concurrent open counters without creating repeat event rows",function() {
        var msg=accepted(1,"A");var names=[];
        for(var n in [1,2]) {
          var threadName="recoveryOpen" & replace(createUUID(),"-","","all");
          arrayAppend(names,threadName);
          thread name=threadName action="run" candidate=listLast(msg.openUrl,"=") {
            thread.ok=new fpw.includes.InactiveMemberRecoveryTrackingService().init("fpw").recordOpen(attributes.candidate);
          }
        }
        thread action="join" name=arrayToList(names) timeout=10000;
        for(var threadName in names) expect(cfthread[threadName].ok).toBeTrue();
        expect(message(msg.messageId).open_count[1]).toBe(2);
      });
      it("does not let authenticated wrong-member clicks bypass ownership",function() {
        var msg=accepted(1,"A");
        var old=structKeyExists(session,"user") ? duplicate(session.user) : {};
        try {
          session.user={userId=createUser()};
          expect(variables.tracking.resolveClick(listLast(msg.clickUrl,"="),"/fpw")).toBe("/fpw/index.cfm");
        } finally {
          if(structIsEmpty(old)) structDelete(session,"user");else session.user=old;
        }
      });
      it("rejects mismatched enrollment ownership for prepared automated messages",function() {
        var other=createUser();
        expect(function() {
          variables.observer.prepareMessage({userId=other,enrollmentEventId=variables.enrollmentId,contactNumber=1,destinationStage="A",settings={attributionWindowHours=24}},
            {subject="Test",toEmail="other@example.test",textBody="Test",htmlBody="<p>Test</p>"});
        }).toThrow();
      });
      it("ignores future events and invalid meaningful-activity contracts",function() {
        var msg=accepted(1,"A");
        sourceEvent("vessel_updated","float_plan","member_api",variables.userId);
        var future=sourceEvent("vessel_updated","vessel","member_api",variables.userId);
        queryExecute("UPDATE product_events SET occurred_at_utc=DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 HOUR) WHERE id=:id",params(future),{datasource="fpw"});
        expect(variables.attribution.reconcileMember(variables.userId)).toBe(0);
        expect(message(msg.messageId).engaged_at_utc[1] EQ "").toBeTrue();
      });
      it("reports contact destination and template groups with independent accepted-message denominators",function() {
        var one=accepted(1,"A");var two=accepted(2,"B");
        variables.tracking.recordOpen(listLast(one.openUrl,"="));
        variables.tracking.recordOpen(listLast(one.openUrl,"="));
        variables.tracking.resolveClick(listLast(two.clickUrl,"="),"/fpw");
        var admin=new fpw.api.v1.AdminRecoveryCenterService();makePublic(admin,"performance");
        var all=admin.performance({});
        expect(all.summary.accepted).toBe(2);expect(all.summary.opened).toBe(1);expect(all.summary.clicked).toBe(1);
        expect(all.summary.openSignals).toBe(2);expect(all.summary.clickSignals).toBe(1);
        var filtered=admin.performance({contactNumber=2,destinationStage="B",templateId="recovery.contact_2.destination_B.v1"});
        expect(arrayLen(filtered.rows)).toBe(1);expect(filtered.rows[1].contactNumber).toBe(2);
        expect(filtered.rows[1].destinationStage).toBe("B");expect(filtered.summary.accepted).toBe(1);
        expect(filtered.summary.opened).toBe(0);expect(filtered.summary.clicked).toBe(1);
        expect(admin.performance({contactNumber=2,destinationStage="A"}).summary.accepted).toBe(0);
      });
      it("separates selected-period signals from accepted cohorts and uses original attribution timestamps",function() {
        var msg=prepared(1,"C");variables.observer.finalizeMessage(msg.messageId,"SEND_ACCEPTED",utc(-8));
        var deadline=message(msg.messageId).attribution_deadline_utc[1];
        variables.tracking.recordOpen(listLast(msg.openUrl,"="));
        var source=sourceEvent("vessel_updated","vessel","member_api",variables.userId);
        queryExecute("UPDATE product_events SET occurred_at_utc=(SELECT DATE_ADD(accepted_at_utc,INTERVAL 1 HOUR) FROM inactive_member_recovery_messages WHERE id=:message) WHERE id=:id",
          {id={value=source,cfsqltype="cf_sql_bigint"},message={value=msg.messageId,cfsqltype="cf_sql_bigint"}},{datasource="fpw"});
        variables.attribution.reconcileMember(variables.userId);
        var admin=new fpw.api.v1.AdminRecoveryCenterService();makePublic(admin,"performance");
        var report=admin.performance({days=7});
        expect(report.summary.accepted).toBe(0);expect(report.periodActivity.opened).toBe(1);
        expect(report.periodActivity.engaged).toBe(0);expect(report.periodActivity.returned).toBe(0);
        var all=admin.performance({days=0});
        expect(all.summary.accepted).toBe(1);expect(all.summary.engaged).toBe(1);expect(all.summary.lateOpens).toBe(1);
        expect(message(msg.messageId).attribution_deadline_utc[1]).toBe(deadline);
      });
      it("shows accepted ledger contacts with missing telemetry honestly",function() {
        var admin=new fpw.api.v1.AdminRecoveryCenterService();makePublic(admin,"performance");
        var initial=admin.performance({}).summary.untrackedAcceptedLedgerContacts;
        var ledger=new fpw.includes.InactiveMemberRecoveryLedgerService();
        var claim=ledger.claimContact(variables.userId,variables.enrollmentId,1,"A");
        expect(claim.CLAIMED).toBeTrue();
        expect(ledger.markSent(variables.userId,variables.enrollmentId,1,claim.CLAIM_TOKEN).SUCCESS).toBeTrue();
        expect(admin.performance({}).summary.untrackedAcceptedLedgerContacts).toBe(initial+1);
        expect(admin.performance({}).summary.accepted).toBe(0);
      });
      it("keeps run counters consistent with persisted initial and terminal decisions",function() {
        var run=variables.observer.beginRun("test",true,{revision=1});arrayAppend(variables.runIds,run);
        var eligible=variables.observer.recordEvaluation(run,variables.userId,{CURRENT_STAGE="A",CONTACT_NUMBER=1,
          ELIGIBLE=true,DECISION="ELIGIBLE",DECISION_CODE="ELIGIBLE",ENROLLMENT_EVENT_ID=variables.enrollmentId});
        var waiting=variables.observer.recordEvaluation(run,variables.userId,{CURRENT_STAGE="A",CONTACT_NUMBER=1,
          ELIGIBLE=false,DECISION="DEFERRED",DECISION_CODE="DEFERRED_WAITING_FOR_INTERVAL",ENROLLMENT_EVENT_ID=variables.enrollmentId});
        variables.observer.finalizeEvaluation(eligible,{eligible=true,category="",code="ELIGIBLE"});
        variables.observer.finalizeEvaluation(waiting,{category="skipped",code="DEFERRED_WAITING_FOR_INTERVAL"});
        variables.observer.finishRun(run,{ok=true,scanned=2,eligible=1,skipped=2});
        var admin=new fpw.api.v1.AdminRecoveryCenterService();makePublic(admin,"runs");
        var report=admin.runs({runId=run});
        expect(report.run.evaluated).toBe(2);expect(report.run.eligible).toBe(1);expect(report.run.waiting).toBe(1);
        expect(report.run.status).toBe("COMPLETED");expect(arrayLen(report.evaluations)).toBe(2);
      });
      it("clears historical failure attention after acceptance and applies the latest frozen deadline",function() {
        var ledger=new fpw.includes.InactiveMemberRecoveryLedgerService();
        var admin=new fpw.api.v1.AdminRecoveryCenterService();makePublic(admin,"memberRow");
        var claim=ledger.claimContact(variables.userId,variables.enrollmentId,1,"A");expect(claim.CLAIMED).toBeTrue();
        var failed=prepared(1,"A");variables.observer.finalizeMessage(failed.messageId,"SEND_FAILED");
        expect(ledger.markFailed(variables.userId,variables.enrollmentId,1,claim.CLAIM_TOKEN,"TEST_FAILURE").SUCCESS).toBeTrue();
        expect(admin.memberRow(variables.userId).needsAttention).toBeTrue();
        var retry=ledger.retryFailedContact(variables.userId,variables.enrollmentId,1,"A");expect(retry.CLAIMED).toBeTrue();
        var sent=ledger.markSent(variables.userId,variables.enrollmentId,1,retry.CLAIM_TOKEN);expect(sent.SUCCESS).toBeTrue();
        var acceptedMessage=prepared(1,"A");variables.observer.finalizeMessage(acceptedMessage.messageId,"SEND_ACCEPTED",sent.SENT_AT_UTC);
        expect(admin.memberRow(variables.userId).needsAttention).toBeFalse();
        expect(message(failed.messageId).status[1]).toBe("SEND_FAILED");
        queryExecute("UPDATE inactive_member_recovery_messages SET accepted_at_utc=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 2 DAY),
          attribution_deadline_utc=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 DAY) WHERE id=:id",params(acceptedMessage.messageId),{datasource="fpw"});
        expect(admin.memberRow(variables.userId).needsAttention).toBeTrue();
        var source=sourceEvent("vessel_updated","vessel","member_api",variables.userId);
        queryExecute("UPDATE product_events SET occurred_at_utc=(SELECT DATE_ADD(accepted_at_utc,INTERVAL 1 HOUR) FROM inactive_member_recovery_messages WHERE id=:message) WHERE id=:id",
          {id={value=source,cfsqltype="cf_sql_bigint"},message={value=acceptedMessage.messageId,cfsqltype="cf_sql_bigint"}},{datasource="fpw"});
        expect(variables.attribution.reconcileMember(variables.userId)).toBe(1);
        expect(admin.memberRow(variables.userId).needsAttention).toBeFalse();
      });
      it("paginates the current member cohort without repeating the first page",function() {
        var admin=new fpw.api.v1.AdminRecoveryCenterService();makePublic(admin,"listMembers");
        var first=admin.listMembers({pageSize=1,page=1});var second=admin.listMembers({pageSize=1,page=2});
        expect(first.total GTE 3).toBeTrue();expect(arrayLen(first.rows)).toBe(1);expect(arrayLen(second.rows)).toBe(1);
        expect(first.rows[1].userId EQ second.rows[1].userId).toBeFalse();
      });
      it("reaches member histories beyond old limits and bounds run and audit pages",function() {
        var admin=new fpw.api.v1.AdminRecoveryCenterService();
        for(var method in ["memberDetail","runs","settingsView","reportPage"]) makePublic(admin,method);
        var run=variables.observer.beginRun("test",true,{revision=1});arrayAppend(variables.runIds,run);
        for(var n=1;n LTE 201;n++) {
          variables.observer.recordEvaluation(run,variables.userId,{CURRENT_STAGE="A",CONTACT_NUMBER=1,ELIGIBLE=false,DECISION="DEFERRED",DECISION_CODE="DEFERRED_WAITING_FOR_INTERVAL",ENROLLMENT_EVENT_ID=variables.enrollmentId});
          prepared(1,"A");
          if(n LTE 101) sourceEvent("recovery_pagination_fixture","user","recovery_test",variables.userId);
        }
        var seenMessages={};var seenEvaluations={};var seenHistory={};
        for(var page=1;page LTE 9;page++) {
          var data=admin.memberDetail(variables.userId,{pageSize=25,messagesPage=page,evaluationsPage=page,historyPage=page});
          expect(data.messagesPagination.total).toBe(201);expect(data.evaluationsPagination.total).toBe(201);
          expect(arrayLen(data.messages) LTE 25).toBeTrue();expect(arrayLen(data.evaluations) LTE 25).toBeTrue();
          for(var row in data.messages) {expect(structKeyExists(seenMessages,toString(row.messageId))).toBeFalse();seenMessages[toString(row.messageId)]=true;}
          for(var row in data.evaluations) {expect(structKeyExists(seenEvaluations,toString(row.evaluationId))).toBeFalse();seenEvaluations[toString(row.evaluationId)]=true;}
          // Product history has its own independent page count.
        }
        expect(structCount(seenMessages)).toBe(201);expect(structCount(seenEvaluations)).toBe(201);
        var historyTotal=data.historyPagination.total;expect(historyTotal GT 100).toBeTrue();
        for(var page=1;page LTE ceiling(historyTotal/25);page++) {
          var historyData=admin.memberDetail(variables.userId,{pageSize=25,historyPage=page});
          for(var row in historyData.history) {expect(structKeyExists(seenHistory,toString(row.eventId))).toBeFalse();seenHistory[toString(row.eventId)]=true;}
        }
        expect(structCount(seenHistory)).toBe(historyTotal);
        var finalRun=admin.runs({runId=run,evaluationsPage=3,pageSize=100});
        expect(finalRun.evaluationsPagination.total).toBe(201);expect(arrayLen(finalRun.evaluations)).toBe(1);
        expect(admin.memberDetail(variables.userId,{pageSize=999}).messagesPagination.pageSize).toBe(100);
        for(var invalid in ["0","-1","1.5","abc","1 OR 1=1"]) {
          expect(function(){admin.reportPage(201,{messagesPage=invalid},"messagesPage");}).toThrow();
        }
        var beforeAudit=admin.settingsView().auditPagination.total;
        try {
          for(var n=1;n LTE 31;n++) new fpw.api.v1.AdminAuditService().record(actorUserId=variables.userId,action="recovery_settings_saved",targetType="test_pagination",targetId=toString(variables.userId),success=true);
          var auditOne=admin.settingsView({auditPage=1,pageSize=25});var auditTwo=admin.settingsView({auditPage=2,pageSize=25});
          expect(auditOne.auditPagination.total).toBe(beforeAudit+31);
          expect(arrayLen(auditOne.audit)).toBe(25);expect(arrayLen(auditTwo.audit) GT 0).toBeTrue();
          expect(auditOne.audit[1].audit_id EQ auditTwo.audit[1].audit_id).toBeFalse();
        } finally {queryExecute("DELETE FROM fpw_admin_audit_log WHERE admin_user_id=:id",params(variables.userId),{datasource="fpw"});}
      });
      it("records current progress separately on each contact snapshot",function() {
        for(var contact in [1,2,3]) {
          var msg=accepted(contact,"C");var row=message(msg.messageId);
          expect(row.contact_number[1]).toBe(contact);expect(row.destination_stage[1]).toBe("C");
          expect(row.template_id[1]).toBe("recovery.contact_" & contact & ".destination_C.v1");
        }
      });
    });
  }
  private void function setup() {
    variables.ids=[];variables.runIds=[];variables.userId=createUser();variables.email="observability-" & variables.userId & "@example.test";
    variables.observer=new fpw.includes.InactiveMemberRecoveryObservabilityService().init("fpw");
    variables.tracking=new fpw.includes.InactiveMemberRecoveryTrackingService().init("fpw");
    variables.attribution=new fpw.includes.InactiveMemberRecoveryAttributionService().init("fpw");
    var e=new fpw.includes.ProductEventService().init("fpw").recordEvent(variables.userId,"inactive_member_recovery_enrolled","user",variables.userId,"recovery_enrollment",{},"inactive_member_recovery_enrolled:" & variables.userId);
    variables.enrollmentId=queryExecute("SELECT id FROM product_events WHERE idempotency_key=:key",
      {key={value="inactive_member_recovery_enrolled:" & variables.userId,cfsqltype="cf_sql_varchar"}},{datasource="fpw"}).id[1];
  }
  private numeric function createUser() {
    var inserted={};
    queryExecute("INSERT INTO users(fName,lName,email,password,passwordCreated,created) VALUES('Recovery','Observability',:email,:password,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
      {email={value="codex-recovery-observe-" & lCase(replace(createUUID(),"-","","all")) & "@example.test",cfsqltype="cf_sql_varchar"},
       password={value=hash(createUUID(),"SHA-256"),cfsqltype="cf_sql_varchar"}},{datasource="fpw",result="inserted"});
    arrayAppend(variables.ids,val(inserted.generatedKey));return val(inserted.generatedKey);
  }
  private struct function prepared(required numeric contact,required string stage) {
    var path="/app/dashboard.cfm?recoveryAction=" & (arguments.stage EQ "A" ? "vessel" : arguments.stage EQ "B" ? "planner" : arguments.stage EQ "C" ? "routes" : "plans");
    var url="http://localhost:8500/fpw" & path;
    return variables.observer.prepareMessage({userId=variables.userId,enrollmentEventId=variables.enrollmentId,contactNumber=arguments.contact,
      destinationStage=arguments.stage,destinationPath=path,settings={revision=1,attributionWindowHours=24}},
      {success=true,messageType="INACTIVE_MEMBER_RECOVERY",subject="Approved contact",toEmail=variables.email,ctaLabel="Continue",
        ctaUrl=url,textBody="Continue: " & url & chr(10) & "https://example.test/unsubscribe?t=unsubscribe-secret",
        htmlBody='<html><body><a href="' & encodeForHtmlAttribute(url) & '">Continue</a><a href="https://example.test/unsubscribe?t=unsubscribe-secret">Preferences</a><p>' & encodeForHtml("https://example.test/unsubscribe?t=unsubscribe-secret") & '</p></body></html>'});
  }
  private struct function accepted(required numeric contact,required string stage) {
    var msg=prepared(arguments.contact,arguments.stage);variables.observer.finalizeMessage(msg.messageId,"SEND_ACCEPTED",utcHours(-1));return msg;
  }
  private string function utc(numeric days=0) {
    return queryExecute("SELECT DATE_FORMAT(DATE_ADD(UTC_TIMESTAMP(),INTERVAL :days DAY),'%Y-%m-%dT%H:%i:%sZ') at_utc",
      {days={value=arguments.days,cfsqltype="cf_sql_integer"}},{datasource="fpw"}).at_utc[1];
  }
  private string function utcHours(required numeric hours) {
    return queryExecute("SELECT DATE_FORMAT(DATE_ADD(UTC_TIMESTAMP(),INTERVAL :hours HOUR),'%Y-%m-%dT%H:%i:%sZ') at_utc",
      {hours={value=arguments.hours,cfsqltype="cf_sql_integer"}},{datasource="fpw"}).at_utc[1];
  }
  private numeric function sourceEvent(required string name,required string type,required string source,required numeric userId) {
    var result={};
    var entityId=arguments.userId;
    // Meaningful activity fixtures use real owned canonical entities; only the explicit
    // invalid-source test intentionally supplies a mismatched event/entity contract.
    if(arguments.source EQ "member_api" AND arguments.type EQ "vessel") {
      queryExecute("INSERT INTO vessels(userId,vesselName,hailingPort,isDefaultVessel) VALUES(:id,'Recovery Fixture','Fixture Port',1)",
        params(arguments.userId),{datasource="fpw",result="result"});
      entityId=val(result.generatedKey);
    } else if(arguments.source EQ "member_api" AND arguments.type EQ "user_route") {
      queryExecute("INSERT INTO user_routes(user_id,route_name,is_active,created_at,updated_at) VALUES(:id,'Recovery Fixture Route',1,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
        params(arguments.userId),{datasource="fpw",result="result"});
      entityId=val(result.generatedKey);
    }
    queryExecute("INSERT INTO product_events(event_uuid,user_id,event_name,entity_type,entity_id,event_source,occurred_at_utc,metadata_json,created_at_utc,idempotency_key)
      VALUES(:uuid,:user,:name,:type,:entityId,:source,UTC_TIMESTAMP(),:metadata,UTC_TIMESTAMP(),:key)",
      {uuid={value=createUUID(),cfsqltype="cf_sql_char"},user={value=arguments.userId,cfsqltype="cf_sql_integer"},
       name={value=arguments.name,cfsqltype="cf_sql_varchar"},type={value=arguments.type,cfsqltype="cf_sql_varchar"},
       entityId={value=entityId,cfsqltype="cf_sql_bigint"},
       metadata={value=arguments.name EQ "vessel_created" ? '{"creation_source":"member"}' : '{}',cfsqltype="cf_sql_longvarchar"},
       source={value=arguments.source,cfsqltype="cf_sql_varchar"},key={value="obs_source:" & createUUID(),cfsqltype="cf_sql_varchar"}},
      {datasource="fpw",result="result"});
    return val(result.generatedKey);
  }
  private query function message(required numeric id) {return queryExecute("SELECT * FROM inactive_member_recovery_messages WHERE id=:id",params(arguments.id),{datasource="fpw"});}
  private struct function params(required numeric id) {return {id={value=arguments.id,cfsqltype="cf_sql_bigint"}};}
  private void function cleanup() {
    for(var id in variables.ids) {
      queryExecute("DELETE FROM inactive_member_recovery_messages WHERE user_id=:id",params(id),{datasource="fpw"});
      queryExecute("DELETE FROM inactive_member_recovery_evaluations WHERE user_id=:id",params(id),{datasource="fpw"});
      queryExecute("DELETE FROM inactive_member_recovery_deliveries WHERE user_id=:id",params(id),{datasource="fpw"});
      queryExecute("DELETE FROM product_events WHERE user_id=:id",params(id),{datasource="fpw"});
      queryExecute("DELETE FROM user_routes WHERE user_id=:id",params(id),{datasource="fpw"});
      queryExecute("DELETE FROM vessels WHERE userId=:id",params(id),{datasource="fpw"});
      queryExecute("DELETE FROM users WHERE userId=:id",params(id),{datasource="fpw"});
    }
    for(var id in variables.runIds) queryExecute("DELETE FROM inactive_member_recovery_runs WHERE id=:id",params(id),{datasource="fpw"});
  }
}
