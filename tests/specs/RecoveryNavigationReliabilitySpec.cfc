component extends="testbox.system.BaseSpec" output=false {
  function run() {
    describe("Recovery navigation reliability without live email",function() {
      beforeEach(function() {
        variables.savedSession={};
        for(var key in ["user","fpwAuthIntents"])
          if(structKeyExists(session,key)) variables.savedSession[key]=duplicate(session[key]);
        structDelete(session,"user");structDelete(session,"fpwAuthIntents");
        variables.fixture=new fpw.tests.support.RecoveryOrchestrationFixture();
        variables.member=variables.fixture.createMember("A");
        variables.observer=new fpw.includes.InactiveMemberRecoveryObservabilityService().init("fpw");
        variables.tracking=new fpw.includes.InactiveMemberRecoveryTrackingService().init("fpw");
      });
      afterEach(function() {
        variables.fixture.cleanup();
        for(var key in ["user","fpwAuthIntents"]) {
          if(structKeyExists(variables.savedSession,key)) session[key]=variables.savedSession[key];
          else structDelete(session,key);
        }
      });

      it("records a normal accepted click and preserves authenticated and anonymous destinations",function() {
        var msg=prepared();
        variables.observer.finalizeMessage(msg.messageId,"SEND_ACCEPTED");
        expectDestination(msg,"vessel");
        expect(row(msg.messageId).click_count[1]).toBe(1);
        session.user={userId=variables.member.userId};
        expectDestination(msg,"vessel",variables.tracking,true);
        expect(row(msg.messageId).click_count[1]).toBe(2);
      });

      it("keeps navigation when the click counter or event writer throws",function() {
        var msg=prepared();
        variables.observer.finalizeMessage(msg.messageId,"SEND_ACCEPTED");
        var tracker=prepareMock(new fpw.includes.InactiveMemberRecoveryTrackingService().init("fpw"));
        tracker.$(method="signal",throwException=true,throwType="tests.TelemetryFailure",throwMessage="CONTROLLED_TELEMETRY_FAILURE");
        tracker.$("logClickTelemetryFailure");
        expectDestination(msg,"vessel",tracker);
        expect(tracker.$count("signal")).toBe(1);
        expect(tracker.$count("logClickTelemetryFailure")).toBe(1);
        expect(row(msg.messageId).click_count[1]).toBe(0);
      });

      it("keeps navigation when analytics declines a click",function() {
        var msg=prepared();
        variables.observer.finalizeMessage(msg.messageId,"SEND_ACCEPTED");
        var tracker=prepareMock(new fpw.includes.InactiveMemberRecoveryTrackingService().init("fpw"));
        tracker.$("signal",false);
        tracker.$("logClickTelemetryFailure");
        expectDestination(msg,"vessel",tracker);
        expect(tracker.$count("signal")).toBe(1);
        expect(tracker.$count("logClickTelemetryFailure")).toBe(1);
        expect(row(msg.messageId).click_count[1]).toBe(0);
      });

      it("keeps navigation when both telemetry and its redacted logger fail",function() {
        var msg=prepared();variables.observer.finalizeMessage(msg.messageId,"SEND_ACCEPTED");
        var tracker=prepareMock(new fpw.includes.InactiveMemberRecoveryTrackingService().init("fpw"));
        tracker.$(method="signal",throwException=true,throwType="tests.TelemetryFailure",throwMessage="CONTROLLED_TELEMETRY_FAILURE");
        tracker.$(method="logClickTelemetryFailure",throwException=true,throwType="tests.LogFailure",throwMessage="CONTROLLED_LOG_FAILURE");
        expectDestination(msg,"vessel",tracker);
        expect(tracker.$count("logClickTelemetryFailure")).toBe(1);
        expect(row(msg.messageId).click_count[1]).toBe(0);
      });

      it("allows prepared and uncertain signed navigation without claiming accepted analytics",function() {
        for(var status in ["PREPARED","OUTCOME_UNKNOWN"]) {
          var msg=prepared();
          if(status NEQ "PREPARED") variables.observer.finalizeMessage(msg.messageId,status);
          expectDestination(msg,"vessel");
          expect(variables.tracking.recordOpen(listLast(msg.openUrl,"="))).toBeFalse();
          var saved=row(msg.messageId);
          expect(saved.status[1]).toBe(status);
          expect(saved.click_count[1]).toBe(0);expect(saved.open_count[1]).toBe(0);
        }
      });

      it("rejects canceled and known failed messages",function() {
        for(var status in ["CANCELED","SEND_FAILED"]) {
          var msg=prepared();variables.observer.finalizeMessage(msg.messageId,status);
          expect(variables.tracking.resolveClick(listLast(msg.clickUrl,"="),"/fpw")).toBe("/fpw/index.cfm");
          expect(row(msg.messageId).click_count[1]).toBe(0);
        }
      });

      it("expires unconfirmed navigation from preparation time without granting a new lifetime",function() {
        for(var status in ["PREPARED","OUTCOME_UNKNOWN"]) {
          var msg=prepared();
          if(status NEQ "PREPARED") variables.observer.finalizeMessage(msg.messageId,status);
          queryExecute("UPDATE inactive_member_recovery_messages SET prepared_at_utc=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 91 DAY) WHERE id=:id",params(msg.messageId),{datasource="fpw"});
          expect(variables.tracking.resolveClick(listLast(msg.clickUrl,"="),"/fpw")).toBe("/fpw/index.cfm");
          expect(row(msg.messageId).click_count[1]).toBe(0);
        }
      });

      it("retains accepted expiry and rejects future timestamps",function() {
        var msg=prepared();variables.observer.finalizeMessage(msg.messageId,"SEND_ACCEPTED");
        queryExecute("UPDATE inactive_member_recovery_messages SET accepted_at_utc=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 91 DAY) WHERE id=:id",params(msg.messageId),{datasource="fpw"});
        expect(variables.tracking.resolveClick(listLast(msg.clickUrl,"="),"/fpw")).toBe("/fpw/index.cfm");
        queryExecute("UPDATE inactive_member_recovery_messages SET accepted_at_utc=DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 DAY) WHERE id=:id",params(msg.messageId),{datasource="fpw"});
        expect(variables.tracking.resolveClick(listLast(msg.clickUrl,"="),"/fpw")).toBe("/fpw/index.cfm");
        var pending=prepared();
        queryExecute("UPDATE inactive_member_recovery_messages SET prepared_at_utc=DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 DAY) WHERE id=:id",params(pending.messageId),{datasource="fpw"});
        expect(variables.tracking.resolveClick(listLast(pending.clickUrl,"="),"/fpw")).toBe("/fpw/index.cfm");
      });

      it("retains the normal accepted lifetime when preparation predates acceptance",function() {
        var msg=prepared();variables.observer.finalizeMessage(msg.messageId,"SEND_ACCEPTED");
        queryExecute("UPDATE inactive_member_recovery_messages SET prepared_at_utc=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 91 DAY) WHERE id=:id",params(msg.messageId),{datasource="fpw"});
        expectDestination(msg,"vessel");
      });

      it("rejects tampered tokens and wrong-purpose tokens for every navigable state",function() {
        for(var status in ["PREPARED","OUTCOME_UNKNOWN","SEND_ACCEPTED"]) {
          var msg=prepared();if(status NEQ "PREPARED") variables.observer.finalizeMessage(msg.messageId,status);
          var token=listLast(msg.clickUrl,"=");
          var changed=left(token,128) & (right(token,1) EQ "a" ? "b":"a");
          expect(variables.tracking.resolveClick(changed,"/fpw")).toBe("/fpw/index.cfm");
          expect(variables.tracking.resolveClick(listLast(msg.openUrl,"="),"/fpw")).toBe("/fpw/index.cfm");
          expect(variables.tracking.recordOpen(token)).toBeFalse();
          expect(row(msg.messageId).click_count[1]).toBe(0);
        }
      });

      it("rejects a different signed-in member in every navigable state",function() {
        var other=variables.fixture.createMember("A");
        session.user={userId=other.userId};
        for(var status in ["PREPARED","OUTCOME_UNKNOWN","SEND_ACCEPTED"]) {
          var msg=prepared();if(status NEQ "PREPARED") variables.observer.finalizeMessage(msg.messageId,status);
          expect(variables.tracking.resolveClick(listLast(msg.clickUrl,"="),"/fpw")).toBe("/fpw/index.cfm");
          expect(row(msg.messageId).click_count[1]).toBe(0);
        }
      });

      it("rejects unsupported and external stored destinations",function() {
        for(var destination in ["/app/dashboard.cfm?recoveryAction=unsupported","https://evil.example/",
          "/app/dashboard.cfm?recoveryAction=vessel&returnUrl=https://evil.example/"]) {
          var msg=prepared();
          queryExecute("UPDATE inactive_member_recovery_messages SET destination_path=:destination WHERE id=:id",
            {id={value=msg.messageId,cfsqltype="cf_sql_bigint"},destination={value=destination,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
          expect(variables.tracking.resolveClick(listLast(msg.clickUrl,"="),"/fpw")).toBe("/fpw/index.cfm");
        }
      });

      it("rechecks selected-object ownership instead of opening another member's route",function() {
        var other=variables.fixture.createMember("C");var msg=prepared();
        queryExecute("UPDATE inactive_member_recovery_messages SET destination_path=:destination WHERE id=:id",
          {id={value=msg.messageId,cfsqltype="cf_sql_bigint"},destination={value="/app/dashboard.cfm?recoveryAction=route&routeId=" & other.routeId,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
        expectDestination(msg,"routes");
      });

      it("uses exactly the final tracked CTA in visible HTML and plain-text fallback links",function() {
        for(var path in ["/app/dashboard.cfm?recoveryAction=vessel","/app/dashboard.cfm?recoveryAction=route&routeId=123",
          "/app/dashboard.cfm?recoveryAction=draft&floatPlanId=456"]) {
          var destination="https://www.floatplanwizard.com" & path;
          var decorated=variables.tracking.decorate({destinationUrl=destination,ctaUrl=destination,
            textBody="Continue: " & destination,
            htmlBody='<a href="' & encodeForHtmlAttribute(destination) & '">Continue</a><a href="' & encodeForHtmlAttribute(destination) & '">' & encodeForHtml(destination) & '</a>'},
            repeatString("a",64),repeatString("b",64));
          expect(decorated.message.ctaUrl).toBe(decorated.clickUrl);
          expect(decorated.message.destinationUrl).toBe(destination);
          expect(decorated.message.htmlBody).toInclude('<a href="' & encodeForHtmlAttribute(decorated.clickUrl) & '">' & encodeForHtml(decorated.clickUrl) & '</a>');
          expect(decorated.message.textBody).toInclude(decorated.clickUrl);
          expect(decorated.message.htmlBody).notToInclude(encodeForHtml(destination));
          expect(decorated.message.htmlBody).notToInclude(encodeForHtmlAttribute(destination));
        }
      });

      it("keeps a submitted email navigable after post-SMTP ledger confirmation failures",function() {
        for(var mode in ["CONFIRMATION_UNKNOWN","COMMITTED_CONFIRMATION_UNKNOWN"]) {
          variables.fixture.configure(ledgerMode=mode);
          var sender=prepareMock(variables.fixture.service());
          var observer=prepareMock(new fpw.includes.InactiveMemberRecoveryObservabilityService().init("fpw"));
          observer.$("beginRun",0);sender.$property("observability","variables",observer);
          var result=sender.processBatch(1,false);
          expect(result.reasons.SENT_CONFIRMATION_UNKNOWN).toBe(1);
          expect(variables.fixture.submittedCount()).toBe(1);
          var message=variables.fixture.messages()[1];
          var saved=messageForUser(variables.member.userId);
          expect(saved.status[1]).toBe("OUTCOME_UNKNOWN");
          expectDestination({clickUrl=message.ctaUrl},"vessel");
          expect(row(saved.id[1]).click_count[1]).toBe(0);
          variables.fixture.cleanup();variables.fixture=new fpw.tests.support.RecoveryOrchestrationFixture();
          variables.member=variables.fixture.createMember("A");
        }
      });

      it("keeps a submitted email navigable after observability finalization fails",function() {
        var sender=prepareMock(variables.fixture.service());
        var observer=prepareMock(new fpw.includes.InactiveMemberRecoveryObservabilityService().init("fpw"));
        observer.$("beginRun",0);
        observer.$(method="finalizeMessage",throwException=true,throwType="tests.TelemetryFailure",throwMessage="CONTROLLED_FINALIZATION_FAILURE");
        sender.$property("observability","variables",observer);
        var result=sender.processBatch(1,false);
        expect(result.sent).toBe(1);expect(result.observation_gaps).toBe(1);
        expect(variables.fixture.submittedCount()).toBe(1);
        var message=variables.fixture.messages()[1];
        var saved=messageForUser(variables.member.userId);
        expect(saved.status[1]).toBe("PREPARED");
        expectDestination({clickUrl=message.ctaUrl},"vessel");
        expect(row(saved.id[1]).click_count[1]).toBe(0);
      });
    });
  }

  private struct function prepared() {
    var path="/app/dashboard.cfm?recoveryAction=vessel";
    var destination="http://localhost:8500/fpw" & path;
    return variables.observer.prepareMessage({userId=variables.member.userId,enrollmentEventId=variables.fixture.enrollmentId(variables.member.userId),
      contactNumber=1,destinationStage="A",destinationPath=path,settings={revision=1,attributionWindowHours=24}},
      {success=true,messageType="INACTIVE_MEMBER_RECOVERY",subject="Disposable recovery test",toEmail=variables.member.email,
        ctaLabel="Continue",ctaUrl=destination,textBody=destination,
        htmlBody='<a href="' & encodeForHtmlAttribute(destination) & '">Continue</a><p>' & encodeForHtml(destination) & '</p>'});
  }
  private void function expectDestination(required struct message,required string action,any tracker="",boolean authenticated=false) {
    var activeTracker=isObject(arguments.tracker) ? arguments.tracker : variables.tracking;
    var redirect=activeTracker.resolveClick(listLast(arguments.message.clickUrl,"="),"/fpw");
    expect(find("/fpw/app/" & (arguments.authenticated ? "dashboard":"login") & ".cfm?authIntent=",redirect)).toBe(1);
    var userId=arguments.authenticated ? variables.member.userId : 0;
    var intent=new fpw.includes.AuthContinuationService().getIntent(listLast(redirect,"="),userId);
    expect(intent.destinationKey).toBe(arguments.action);
  }
  private struct function params(required numeric id) { return {id={value=arguments.id,cfsqltype="cf_sql_bigint"}}; }
  private query function row(required numeric id) {
    return queryExecute("SELECT id,status,click_count,open_count FROM inactive_member_recovery_messages WHERE id=:id",params(arguments.id),{datasource="fpw"});
  }
  private query function messageForUser(required numeric id) {
    return queryExecute("SELECT id,status FROM inactive_member_recovery_messages WHERE user_id=:id ORDER BY id DESC LIMIT 1",params(arguments.id),{datasource="fpw"});
  }
}
