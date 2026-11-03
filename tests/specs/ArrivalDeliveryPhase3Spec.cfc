component extends="testbox.system.BaseSpec" output=false {
  variables.ds = "fpw";

  function beforeAll() {
    if (!structKeyExists(request,"arrivalPhase3TestAuthorized") || !request.arrivalPhase3TestAuthorized ||
        !listFindNoCase("local,dev,development",application.env ?: "") ||
        compareNoCase(sql("SELECT DATABASE() AS db").db[1],"FPW")!=0) {
      throw(type="ArrivalDeliveryTest.LocalGuard",message="Use the confirmed local Phase 3 runner.");
    }
  }

  private any function sql(required string statement,struct params={}) {
    return queryExecute(arguments.statement,arguments.params,{datasource=variables.ds});
  }

  private string function shift(required string utc,required numeric minutes) {
    return sql("SELECT DATE_FORMAT(DATE_ADD(CAST(:t AS DATETIME), INTERVAL :n MINUTE),
      '%Y-%m-%d %H:%i:%s') AS stamp",{t=utc,n=minutes}).stamp[1];
  }

  private any function worker(required struct f,required any capture) {
    return new fpw.api.v1.ArrivalOverdueDeliveryService().init(variables.ds,capture,f.secret);
  }

  private void function withSchedulerConfig(required any scenario) {
    var originalEnv=application.env;
    var hadPath=structKeyExists(application,"stripeConfigPath");
    var originalPath=application.stripeConfigPath ?: "";
    var folder=getTempDirectory() & "fpw-arrival-settings-" & createUUID() & "/";
    directoryCreate(folder);
    try {
      application.stripeConfigPath=folder & "stripe-config.json";
      // A valid-looking setting in the sibling file must never authorize this sender.
      fileWrite(application.stripeConfigPath,serializeJSON({
        FPW_ARRIVAL_EMAIL_ENABLED=true,FPW_ARRIVAL_RECIPIENT_KEY=hash(createUUID(),"SHA-256")
      }),"utf-8");
      arguments.scenario(folder & "scheduler-config.json");
    } finally {
      application.env=originalEnv;
      if (hadPath) application.stripeConfigPath=originalPath;
      else structDelete(application,"stripeConfigPath");
      directoryDelete(folder,true);
    }
  }

  private void function withPlan(required any test, boolean historical=false,boolean enableCapture=true) {
    // Isolated DB tests commit only synthetic plans so independent CF worker connections see the same records.
    // Each fixture starts with global dispatch OFF. Injected captures use a per-plan CAPTURE scope.
    var control=sql("SELECT mode FROM fpw_arrival_dispatch_control WHERE plan_id=0");
    if(control.recordCount!=1 || control.mode[1]!="OFF") throw(message="Global arrival dispatch must be OFF.");
    var builder=new fpw.tests.support.CompletedContactFixture();
    var f=builder.create();
    try {
      var rollout=sql("SELECT DATE_FORMAT(cutoff_utc,'%Y-%m-%d %H:%i:%s') AS cutoff,
        CONCAT(YEAR(cutoff_utc)+1,'-07-10 19:00:00') AS fixture_due FROM fpw_arrival_rollout WHERE id=1");
      f.due=historical ? shift(rollout.cutoff[1],-60) : rollout.fixture_due[1];
      f.secret=hash(createUUID() & createUUID(),"SHA-256");
      sql("UPDATE floatplans SET returnTimeUTC=:t,returnTime=:wall,returnTZ='America/New_York',returnTimezone='America/New_York'
        WHERE floatPlanId=:p AND userId=:owner",{p=f.planId,owner=f.userId,t=f.due,wall=shift(f.due,-240)});
      sql("UPDATE floatplan_monitoring SET next_monitor_eval_at=NULL WHERE float_plan_id=:p AND user_id=:owner",
        {p=f.planId,owner=f.userId});
      if(enableCapture){
        sql("INSERT INTO fpw_arrival_dispatch_control (plan_id,mode,activated_at_utc,generation,updated_at_utc)
          VALUES (:p,'CAPTURE',:activation,1,UTC_TIMESTAMP(6))",{p=f.planId,activation=shift(f.due,-120)});
      }
      f.observer=new fpw.api.v1.ArrivalOverdueService().init(variables.ds);
      f.observer.syncPlan(f.planId,"ROUTE_START",f.userId);
      arguments.test(f);
    } finally {
      var owned=sql("SELECT COUNT(*) AS n FROM floatplans fp JOIN users u ON u.userId=fp.userId WHERE fp.floatPlanId=:p
        AND u.userId=:u AND fp.floatPlanName=:marker AND u.email=:email AND u.email LIKE 'ccv-%@example.test'",
        {p=f.planId,u=f.userId,marker=f.marker,email=f.email});
      if(val(owned.n[1])!=1) throw(message="Refusing cleanup outside this synthetic fixture.");
      transaction {
        sql("DELETE FROM fpw_arrival_attempts WHERE delivery_id IN (SELECT d.id FROM fpw_arrival_deliveries d
          JOIN fpw_arrival_notices n ON n.id=d.notice_id WHERE n.plan_id=:p)",{p=f.planId});
        sql("DELETE FROM fpw_arrival_deliveries WHERE notice_id IN (SELECT id FROM fpw_arrival_notices WHERE plan_id=:p)",{p=f.planId});
        sql("DELETE FROM fpw_arrival_notices WHERE plan_id=:p",{p=f.planId});
        sql("UPDATE fpw_arrival_dispatch_control SET mode='OFF',generation=generation+1 WHERE plan_id=:p AND mode<>'OFF'",{p=f.planId});
        sql("DELETE FROM fpw_arrival_events WHERE plan_id=:p",{p=f.planId});
        sql("DELETE FROM fpw_arrival_revisions WHERE plan_id=:p",{p=f.planId});
        sql("DELETE FROM fpw_arrival_watches WHERE plan_id=:p",{p=f.planId});
        sql("DELETE FROM floatplan_basic_details WHERE floatplan_id=:p",{p=f.planId});
        builder.cleanup(f);
      }
    }
  }

  private void function addContact(required struct f,required string address) {
    // One transaction keeps the newly selected association bound to its actual insert ID.
    transaction {
      var inserted={};
      queryExecute("INSERT INTO contacts (userId,name,phone,email) VALUES (:u,'Synthetic shore contact','5550100',:e)",
        {u=f.userId,e=address},{datasource=variables.ds,result="local.inserted"});
      sql("INSERT INTO floatplan_contacts(floatPlanId,contactId) VALUES(:p,:c)",{p=f.planId,c=val(inserted.generatedKey)});
    }
  }

  private query function deliveries(required struct f) {
    return sql("SELECT d.id,d.state,d.recipient_key,d.attempt_count,d.reason,
      DATE_FORMAT(d.next_attempt_utc,'%Y-%m-%d %H:%i:%s') AS next_attempt,
      DATE_FORMAT(d.lease_until_utc,'%Y-%m-%d %H:%i:%s') AS lease_until
      FROM fpw_arrival_deliveries d JOIN fpw_arrival_notices n ON n.id=d.notice_id
      WHERE n.plan_id=:p ORDER BY d.id",{p=f.planId});
  }

  private query function notices(required struct f) {
    return sql("SELECT id,state,slot_no,recipient_count,invalid_count,reason,revision_id
      FROM fpw_arrival_notices WHERE plan_id=:p ORDER BY id",{p=f.planId});
  }

  private query function scopeFor(required numeric planId) {
    return sql("SELECT mode,generation,DATE_FORMAT(updated_at_utc,'%Y-%m-%d %H:%i:%s.%f') AS cutoff
      FROM fpw_arrival_dispatch_control WHERE plan_id=:p",{p=planId});
  }

  private numeric function attempts(required struct f) {
    return val(sql("SELECT COUNT(*) AS n FROM fpw_arrival_attempts a JOIN fpw_arrival_deliveries d ON d.id=a.delivery_id
      JOIN fpw_arrival_notices n ON n.id=d.notice_id WHERE n.plan_id=:p",{p=f.planId}).n[1]);
  }

  private void function revise(required struct f,required string newDue) {
    transaction {
      var wall=dateTimeFormat(parseDateTime(replace(newDue," ","T") & "Z"),"yyyy-mm-dd HH:nn:ss","America/New_York");
      sql("UPDATE floatplans SET returnTimeUTC=:t,returnTime=:wall WHERE floatPlanId=:p AND userId=:u",
        {p=f.planId,u=f.userId,t=newDue,wall=wall});
      f.observer.reviseDeadline(f.planId,f.userId,1,f.due,newDue);
    }
  }

  private any function changeCapture(required struct f,required any capture) {
    // A change is due at the time of the save, before the synthetic trip's future arrival.
    sql("INSERT INTO fpw_arrival_dispatch_control(plan_id,mode,activated_at_utc,updated_at_utc)
      VALUES (:p,'CAPTURE',UTC_TIMESTAMP(6)-INTERVAL 1 MINUTE,UTC_TIMESTAMP(6))",{p=f.planId});
    return worker(f,capture);
  }

  private struct function saveOverHttp(required struct payload) {
    var response={};
    cfhttp(url="http://localhost:8500/fpw/api/v1/floatplan.cfc?method=handle&action=save",method="POST",
        redirect=false,timeout=20,result="local.response") {
      cfhttpparam(type="cookie",name="CFID",value=session.cfid);
      cfhttpparam(type="cookie",name="CFTOKEN",value=session.cftoken);
      if (structKeyExists(cookie,"JSESSIONID")) cfhttpparam(type="cookie",name="JSESSIONID",value=cookie.JSESSIONID);
      cfhttpparam(type="header",name="Content-Type",value="application/json");
      cfhttpparam(type="body",value=serializeJSON(payload));
    }
    if (!isJSON(response.fileContent)) throw(message="The sandbox save endpoint did not return JSON: " & response.statusCode);
    return deserializeJSON(response.fileContent);
  }

  function run() {
    describe("Phase 3 initial arrival notices with isolated capture transports",function(){
      it("requires a private scheduler JSON boolean and a valid key at both production mail checks",function(){
        withSchedulerConfig(function(path){
          var key=hash(createUUID(),"SHA-256");
          var flags={enabled=false,FPW_ARRIVAL_EMAIL_ENABLED=true,FPW_ARRIVAL_RECIPIENT_KEY=key};
          var mail=new fpw.api.v1.ArrivalOverdueMailService().init(variables.ds);
          fileWrite(path,serializeJSON(flags),"utf-8");
          expect(mail.scheduledTransport()).toBe("MAILHOG");
          expect(mail.submit("",{}).reason).toBe("LIVE_TRANSPORT_DISABLED");
          expect(mail.submit("",{},true).reason).toBe("INVALID_RECIPIENT");
          application.env="production";
          expect(mail.scheduledTransport()).toBe("PRODUCTION");
          expect(mail.submit("",{},true).reason).toBe("LIVE_TRANSPORT_DISABLED");
          // Empty destination exercises the real submit guard and stops before SMTP.
          expect(mail.submit("",{}).reason).toBe("INVALID_RECIPIENT");
          fileDelete(path);
          expect(mail.scheduledTransport()).toBe("");
          expect(mail.submit("",{}).reason).toBe("LIVE_TRANSPORT_DISABLED");
          var invalidSettings=["{","[]","{}",'{"FPW_ARRIVAL_EMAIL_ENABLED":true}'];
          for (var flag in ['false','"true"','"yes"','1','null']) {
            arrayAppend(invalidSettings,'{"enabled":true,"FPW_ARRIVAL_EMAIL_ENABLED":' & flag & ',"FPW_ARRIVAL_RECIPIENT_KEY":"' & key & '"}');
          }
          for (var badKey in ['""','"short"','"' & repeatString(" ",32) & '"','[]','{}','123456789012345678901234567890123456','null']) {
            arrayAppend(invalidSettings,'{"FPW_ARRIVAL_EMAIL_ENABLED":true,"FPW_ARRIVAL_RECIPIENT_KEY":' & badKey & '}');
          }
          for (var content in invalidSettings) {
            fileWrite(path,content,"utf-8");
            expect(mail.scheduledTransport()).toBe("");
            expect(mail.submit("",{}).reason).toBe("LIVE_TRANSPORT_DISABLED");
            application.env="dev";
            expect(mail.submit("",{},true).reason).toBe("LIVE_TRANSPORT_DISABLED");
            application.env="production";
          }
        });
      });

      it("uses the exact site key for recipient identity and rechecks it before resolving a queued address",function(){
        withPlan(function(f){
          withSchedulerConfig(function(path){
            var flags={FPW_ARRIVAL_EMAIL_ENABLED=false,FPW_ARRIVAL_RECIPIENT_KEY=f.secret};
            fileWrite(path,serializeJSON(flags),"utf-8");
            var mail=new fpw.api.v1.ArrivalOverdueMailService().init(variables.ds);
            var selected=mail.selectedRecipients(f.planId).valid;
            expect(arrayLen(selected)).toBe(1);
            var expected=lCase(hmac("arrival:v1:" & int(f.planId) & ":" & lCase(trim(f.contactEmail)),f.secret,"HmacSHA256","utf-8"));
            expect(compare(selected[1].recipientKey,expected)==0).toBeTrue();
            flags.FPW_ARRIVAL_RECIPIENT_KEY=hash(createUUID(),"SHA-256");
            fileWrite(path,serializeJSON(flags),"utf-8");
            expect(mail.resolveRecipient(f.planId,expected)).toBe("");
          });
        });
      });

      it("queues one initial notice at equality with a later or null routine evaluation, then submits it once",function(){
        withPlan(function(f){
          var capture=new fpw.tests.support.ArrivalCaptureTransport();
          var sender=worker(f,capture);
          sender.evaluatePlan(f.planId,shift(f.due,-1));
          expect(notices(f).recordCount).toBe(0);
          sender.evaluatePlan(f.planId,f.due);
          var row=deliveries(f);
          expect(row.recordCount).toBe(1); expect(row.state[1]).toBe("PENDING");
          expect(arrayLen(capture.calls())).toBe(0);
          expect(attempts(f)).toBe(0);
          sender.dispatchPlan(f.planId,shift(f.due,1));
          sender.evaluatePlan(f.planId,shift(f.due,61));
          sender.dispatchPlan(f.planId,shift(f.due,61));
          var calls=capture.calls();
          expect(arrayLen(calls)).toBe(1); expect(calls[1].address).toBe(lCase(f.contactEmail));
          expect(calls[1].message.subject).toBe("FloatPlanWizard Alert: Expected Arrival Time Has Passed");
          expect(findNoCase(f.marker,calls[1].message.body)).toBeGT(0);
          expect(findNoCase(f.slug,calls[1].message.body)).toBe(0);
          expect(findNoCase(f.token,calls[1].message.body)).toBe(0);
          expect(reFindNoCase("America/New_York|Eastern|EDT",calls[1].message.body)).toBeGT(0);
          expect(reFindNoCase("3:00[ ]*PM|15:00",calls[1].message.body)).toBeGT(0);
          expect(notices(f).recordCount).toBe(1); expect(val(notices(f).slot_no[1])).toBe(0);
          expect(deliveries(f).state[1]).toBe("SUBMITTED"); expect(attempts(f)).toBe(1);
        });
      });

      it("normalizes and deduplicates all selected addresses and audits an invalid address separately",function(){
        withPlan(function(f){
          var capture=new fpw.tests.support.ArrivalCaptureTransport(); var sender=worker(f,capture);
          var second=f.marker & "-two@example.test";
          addContact(f,uCase(f.contactEmail)); addContact(f,second); addContact(f,"invalid-address");
          sender.evaluatePlan(f.planId,f.due); sender.evaluatePlan(f.planId,f.due);
          var rows=deliveries(f); expect(rows.recordCount).toBe(2); expect(notices(f).invalid_count[1]).toBe(1);
          expect(rows.recipient_key[1]).notToBe(rows.recipient_key[2]);
          expect(reFind("^[0-9a-f]{64}$",rows.recipient_key[1])).toBeGT(0);
          sender.dispatchPlan(f.planId,f.due);
          var addresses=[];
          for(var entry in capture.calls()) arrayAppend(addresses,entry.address);
          expect(arrayLen(addresses)).toBe(2);
          expect(arrayFindNoCase(addresses,f.contactEmail)).toBeGT(0);
          expect(arrayFindNoCase(addresses,second)).toBeGT(0);
          expect(arrayFindNoCase(addresses,f.email)).toBe(0);
          expect(attempts(f)).toBe(2);
        });
      });

      it("records an empty selection once and never falls back to the owner's address",function(){
        withPlan(function(f){
          sql("DELETE FROM floatplan_contacts WHERE floatPlanId=:p",{p=f.planId});
          var capture=new fpw.tests.support.ArrivalCaptureTransport(); var sender=worker(f,capture);
          sender.evaluatePlan(f.planId,f.due); sender.evaluatePlan(f.planId,f.due);
          sender.dispatchPlan(f.planId,f.due);
          expect(notices(f).recordCount).toBe(1);
          expect(notices(f).state[1]).toBe("NO_RECIPIENTS");
          expect(deliveries(f).recordCount).toBe(0); expect(arrayLen(capture.calls())).toBe(0);
        });
      });

      it("evaluates only explicitly scoped synthetic capture plans and excludes historical incidents",function(){
        var checkExcluded=function(f){
          var capture=new fpw.tests.support.ArrivalCaptureTransport(); var sender=worker(f,capture);
          sender.evaluatePlan(f.planId,f.due); sender.dispatchPlan(f.planId,f.due);
          expect(deliveries(f).recordCount).toBe(0); expect(arrayLen(capture.calls())).toBe(0);
        };
        withPlan(checkExcluded,false,false); withPlan(checkExcluded,true,true);
      });

      it("rechecks selected recipients immediately before submission and suppresses a changed address",function(){
        withPlan(function(f){
          var capture=new fpw.tests.support.ArrivalCaptureTransport(); var sender=worker(f,capture);
          sender.evaluatePlan(f.planId,f.due);
          var id=deliveries(f).id[1]; var claim=sender.claimDelivery(id,f.due);
          sql("UPDATE contacts SET email=:changed WHERE contactId=:id AND userId=:owner",
            {id=f.contactId,owner=f.userId,changed=f.marker & "-replacement@example.test"});
          sender.submitClaim(id,claim.token,f.due);
          expect(deliveries(f).state[1]).toBe("SUPPRESSED");
          expect(arrayLen(capture.calls())).toBe(0);
        });
      });

      it("retries definite transient failures after five, fifteen and thirty additional minutes and stops at attempt four",function(){
        withPlan(function(f){
          var capture=new fpw.tests.support.ArrivalCaptureTransport("FAILED_RETRYABLE"); var sender=worker(f,capture);
          sender.evaluatePlan(f.planId,f.due);
          var at=0; var count=0;
          for(var wait in [5,15,30]){
            sender.dispatchPlan(f.planId,shift(f.due,at)); count++;
            var row=deliveries(f);
            expect(row.state[1]).toBe("FAILED_RETRYABLE"); expect(val(row.attempt_count[1])).toBe(count);
            at+=wait; expect(row.next_attempt[1]).toBe(shift(f.due,at));
            sender.dispatchPlan(f.planId,shift(f.due,at-1)); expect(attempts(f)).toBe(count);
          }
          sender.dispatchPlan(f.planId,shift(f.due,at));
          sender.dispatchPlan(f.planId,shift(f.due,at+120));
          expect(deliveries(f).state[1]).toBe("FAILED_PERMANENT");
          expect(attempts(f)).toBe(4); expect(arrayLen(capture.calls())).toBe(4);
          expect(notices(f).recordCount).toBe(1);
        });
      });

      it("retries a failed recipient independently while preserving the other recipient's submitted outcome",function(){
        withPlan(function(f){
          var capture=new fpw.tests.support.ArrivalCaptureTransport(); var sender=worker(f,capture);
          var other=f.marker & "-second@example.test"; addContact(f,other);
          capture.setRecipientStatus(f.contactEmail,"FAILED_RETRYABLE");
          sender.evaluatePlan(f.planId,f.due); sender.dispatchPlan(f.planId,f.due);
          var states=deliveries(f); var codes=valueList(states.state);
          expect(listFind(codes,"SUBMITTED")).toBeGT(0); expect(listFind(codes,"FAILED_RETRYABLE")).toBeGT(0);
          capture.setRecipientStatus(f.contactEmail,"SUBMITTED");
          sender.dispatchPlan(f.planId,shift(f.due,5));
          var ownCalls=0;var otherCalls=0;
          for(var entry in capture.calls()){
            if(entry.address==f.contactEmail) ownCalls++;
            if(entry.address==other) otherCalls++;
          }
          expect(ownCalls).toBe(2);expect(otherCalls).toBe(1);expect(attempts(f)).toBe(3);
          for(var row in deliveries(f)) expect(row.state).toBe("SUBMITTED");
        });
      });

      it("excludes a deadline overdue at first delivery activation but permits a newly authorized future revision",function(){
        withPlan(function(f){
          sql("INSERT INTO fpw_arrival_dispatch_control(plan_id,mode,activated_at_utc,generation,updated_at_utc)
            VALUES(:p,'CAPTURE',:t,1,UTC_TIMESTAMP(6))",{p=f.planId,t=shift(f.due,60)});
          var capture=new fpw.tests.support.ArrivalCaptureTransport(); var sender=worker(f,capture);
          sender.evaluatePlan(f.planId,shift(f.due,61)); sender.dispatchPlan(f.planId,shift(f.due,61));
          expect(notices(f).recordCount).toBe(0);
          var next=shift(f.due,240); revise(f,next);
          sender.evaluatePlan(f.planId,next); sender.dispatchPlan(f.planId,next);
          expect(arrayLen(capture.calls())).toBe(1);expect(notices(f).recordCount).toBe(1);
        },false,false);
      });

      it("records permanent and ambiguous transport failures without blindly resubmitting them",function(){
        for(var status in ["FAILED_PERMANENT","THROW"]){
          var expected=status=="THROW" ? "UNKNOWN" : "FAILED_PERMANENT";
          withPlan(function(f){
            var capture=new fpw.tests.support.ArrivalCaptureTransport(status); var sender=worker(f,capture);
            sender.evaluatePlan(f.planId,f.due); sender.dispatchPlan(f.planId,f.due);
            sender.dispatchPlan(f.planId,shift(f.due,180));
            expect(deliveries(f).state[1]).toBe(expected);
            expect(attempts(f)).toBe(1); expect(arrayLen(capture.calls())).toBe(1);
          });
        }
      });

      it("suppresses an already claimed old revision and enrolls the authorized 7 PM replacement on time",function(){
        withPlan(function(f){
          var capture=new fpw.tests.support.ArrivalCaptureTransport(); var sender=worker(f,capture);
          sender.evaluatePlan(f.planId,f.due);
          var id=deliveries(f).id[1]; var claim=sender.claimDelivery(id,f.due);
          var revised=shift(f.due,240); revise(f,revised);
          sender.submitClaim(id,claim.token,shift(f.due,30));
          expect(deliveries(f).state[1]).toBe("SUPPRESSED"); expect(arrayLen(capture.calls())).toBe(0);
          sender.evaluatePlan(f.planId,shift(revised,-1)); expect(notices(f).recordCount).toBe(1);
          sender.evaluatePlan(f.planId,revised); sender.dispatchPlan(f.planId,revised);
          expect(notices(f).recordCount).toBe(2); expect(arrayLen(capture.calls())).toBe(1);
        });
      });

      it("rejects stale claims after final-leg arrival, closure, cancellation, expiry or admin stop",function(){
        for(var terminal in ["FINAL_ARRIVAL","CLOSED","CANCELLED","EXPIRED","ADMIN_STOP"]){
          withPlan(function(f){
            var capture=new fpw.tests.support.ArrivalCaptureTransport(); var sender=worker(f,capture);
            sender.evaluatePlan(f.planId,f.due);
            var id=deliveries(f).id[1]; var claim=sender.claimDelivery(id,f.due);
            if(terminal=="FINAL_ARRIVAL"){
              var action=new fpw.api.v1.RouteProgressService().init().markCompletionFromFloatPlanCheckin(
                userId=f.userId,floatPlanId=f.planId,completionMode="active_leg",expectedLegOrder=1,datasource=variables.ds);
              expect(action.COMPLETED).toBeTrue();
            } else if(terminal=="ADMIN_STOP"){
              new fpw.api.v1.monitor().init(variables.ds).closeMonitoringForFloatPlan(f.planId,"admin_dashboard");
            } else if(terminal=="EXPIRED"){
              sql("UPDATE floatplans SET status='EXPIRED',expiredAt=UTC_TIMESTAMP(),end_reason='SINGLE_TRIP_LIMIT'
                WHERE floatPlanId=:p AND userId=:u",{p=f.planId,u=f.userId});
            } else {
              // Set committed terminal truth without invoking safe-arrival email paths.
              sql("UPDATE floatplans SET status=:terminal,closedAt=UTC_TIMESTAMP()
                WHERE floatPlanId=:p AND userId=:u",{p=f.planId,u=f.userId,terminal=terminal});
            }
            sender.submitClaim(id,claim.token,shift(f.due,1));
            expect(deliveries(f).state[1]).toBe("SUPPRESSED"); expect(arrayLen(capture.calls())).toBe(0);
          });
        }
      });

      it("recovers abandoned pre-handoff claims but quarantines interrupted post-handoff attempts",function(){
        for (var afterHandoff in [false,true]){
          withPlan(function(f){
            var capture=new fpw.tests.support.ArrivalCaptureTransport(); var sender=worker(f,capture);
            sender.evaluatePlan(f.planId,f.due);
            var id=deliveries(f).id[1]; var claim=sender.claimDelivery(id,f.due);
            if(afterHandoff){
              // Persist the last durable state of a process that vanished after authorizing handoff.
              transaction {
                sql("INSERT INTO fpw_arrival_attempts(delivery_id,attempt_no,status,started_at_utc)
                  VALUES(:id,1,'SUBMITTING',:t)",{id=id,t=f.due});
                sql("UPDATE fpw_arrival_deliveries SET state='SUBMITTING',attempt_count=1 WHERE id=:id",{id=id});
              }
            }
            var restarted=worker(f,capture);
            restarted.dispatchPlan(f.planId,shift(f.due,5));
            sender.submitClaim(id,claim.token,shift(f.due,6));
            restarted.dispatchPlan(f.planId,shift(f.due,60));
            expect(deliveries(f).state[1]).toBe(afterHandoff?"UNKNOWN":"SUBMITTED");
            expect(attempts(f)).toBe(1);
            expect(arrayLen(capture.calls())).toBe(afterHandoff?0:1);
          });
        }
      });

      it("suppresses a queued old generation after a rollback switch and reenablement",function(){
        withPlan(function(f){
          var capture=new fpw.tests.support.ArrivalCaptureTransport(); var sender=worker(f,capture);
          sender.evaluatePlan(f.planId,f.due);
          sql("UPDATE fpw_arrival_dispatch_control SET mode='OFF',generation=generation+1 WHERE plan_id=:p",{p=f.planId});
          sender.dispatchPlan(f.planId,f.due); expect(arrayLen(capture.calls())).toBe(0);
          sql("UPDATE fpw_arrival_dispatch_control SET mode='CAPTURE',generation=generation+1 WHERE plan_id=:p",{p=f.planId});
          sender.dispatchPlan(f.planId,shift(f.due,1));
          expect(deliveries(f).state[1]).toBe("SUPPRESSED"); expect(arrayLen(capture.calls())).toBe(0);
        });
      });

      it("resolves the Basic one-time contact independently of linked contacts and omits private access tokens",function(){
        withPlan(function(f){
          var basicEmail=f.marker & "-basic@example.test";
          sql("UPDATE floatplans SET route_instance_id=NULL WHERE floatPlanId=:p",{p=f.planId});
          sql("UPDATE floatplan_monitoring SET monitoring_mode='basic' WHERE float_plan_id=:p",{p=f.planId});
          sql("INSERT INTO floatplan_basic_details(floatplan_id,vessel_name,operator_name,captain_name,captain_email,
            notification_contact_name,notification_contact_email,launch_location,destination_location,
            authority_name_snapshot,authority_phone_snapshot) VALUES(:p,'Fixture launch','Fixture','Fixture',:ownerEmail,
            'Selected snapshot',:address,'Harbor','Marina','Test','5550100')",{p=f.planId,ownerEmail=f.email,address=basicEmail});
          var capture=new fpw.tests.support.ArrivalCaptureTransport(); var sender=worker(f,capture);
          sender.evaluatePlan(f.planId,f.due); sender.dispatchPlan(f.planId,f.due);
          var addresses=[];
          for(var entry in capture.calls()){
            arrayAppend(addresses,entry.address);
            expect(findNoCase(f.token,entry.message.body)).toBe(0);
            expect(findNoCase(f.slug,entry.message.body)).toBe(0);
            expect(findNoCase("Fixture launch",entry.message.body)).toBeGT(0);
          }
          expect(arrayLen(addresses)).toBe(2);
          expect(arrayFindNoCase(addresses,basicEmail)).toBeGT(0);
          expect(arrayFindNoCase(addresses,f.contactEmail)).toBeGT(0);
        });
      });

      it("does not create an unseen initial notice for a deadline that passed while dispatch was disabled",function(){
        withPlan(function(f){
          // Use database time here: policy-generation switches are timestamped by the database trigger.
          var deadline=sql("SELECT DATE_FORMAT(UTC_TIMESTAMP(),'%Y-%m-%d %H:%i:%s') AS utc").utc[1];
          revise(f,deadline);
          sql("INSERT INTO fpw_arrival_dispatch_control (plan_id,mode,activated_at_utc,generation,updated_at_utc)
            VALUES (:p,'CAPTURE',:t,1,:t)",{p=f.planId,t=shift(deadline,-30)});
          sql("UPDATE fpw_arrival_dispatch_control SET mode='OFF',generation=generation+1 WHERE plan_id=:p",{p=f.planId});
          sql("UPDATE fpw_arrival_dispatch_control SET mode='CAPTURE',generation=generation+1 WHERE plan_id=:p",{p=f.planId});
          var capture=new fpw.tests.support.ArrivalCaptureTransport(); var sender=worker(f,capture);
          sender.evaluatePlan(f.planId,shift(deadline,5)); sender.dispatchPlan(f.planId,shift(deadline,5));
          expect(notices(f).recordCount).toBe(0);expect(capture.submittedCount()).toBe(0);
        },false,false);
      });

      it("selects independent armed arrival deadlines in scheduler order without starving the batch",function(){
        withPlan(function(unstarted){
          withPlan(function(trip){
            withPlan(function(resumed){
              var capture=new fpw.tests.support.ArrivalCaptureTransport();
              var sender=worker(trip,capture);
              makePublic(sender,"duePlans","initialCandidatesForTest");
              // Supersede an earlier plan's schedule while its route is still unstarted.
              sql("DELETE FROM route_instance_leg_progress WHERE route_instance_id=:r AND user_id=:u",
                {r=unstarted.routeId,u=unstarted.userId});
              sql("UPDATE route_instances SET started_at=NULL,status='PLANNED' WHERE id=:r",{r=unstarted.routeId});
              revise(unstarted,shift(trip.due,-30));
              var earlier=sql("SELECT state,next_due_utc IS NULL AS unarmed FROM fpw_arrival_revisions
                WHERE plan_id=:p AND revision_no=2",{p=unstarted.planId});
              expect(earlier.state[1]).toBe("PENDING");
              expect(val(earlier.unarmed[1])).toBe(1);
              transaction {
                try {
                  sql("UPDATE fpw_arrival_dispatch_control SET mode='ALLOWLIST',generation=generation+1 WHERE plan_id=0");
                  sql("UPDATE fpw_arrival_dispatch_control SET mode='ALLOWLIST',generation=generation+1 WHERE plan_id IN (:a,:b)",
                    {a=unstarted.planId,b=trip.planId});
                  sql("UPDATE floatplan_monitoring SET next_monitor_eval_at=:six,expected_checkin_at=:six WHERE float_plan_id=:p",
                    {six=shift(trip.due,180),p=trip.planId});
                  expect(sender.initialCandidatesForTest(1,shift(trip.due,-1)).recordCount).toBe(0);
                  var exact=sender.initialCandidatesForTest(1,trip.due);
                  expect(exact.recordCount).toBe(1);expect(val(exact.plan_id[1])).toBe(val(trip.planId));
                  sql("UPDATE floatplan_monitoring SET next_monitor_eval_at=NULL,expected_checkin_at=NULL WHERE float_plan_id=:p",
                    {p=trip.planId});
                  var noRoutine=sender.initialCandidatesForTest(1,trip.due);
                  expect(val(noRoutine.plan_id[1])).toBe(val(trip.planId));
                  // A durable slot-zero outcome, even NO_RECIPIENTS, retires this revision from initial selection.
                  sql("INSERT INTO fpw_arrival_notices(revision_id,slot_no,plan_id,state,created_at_utc)
                    SELECT id,0,plan_id,'NO_RECIPIENTS',UTC_TIMESTAMP(6) FROM fpw_arrival_revisions
                    WHERE plan_id=:p AND revision_no=1",{p=trip.planId});
                  expect(sender.initialCandidatesForTest(1,trip.due).recordCount).toBe(0);

                  // An allowed revision may become due before a newer allowlist generation. The database authors
                  // that new watermark, so wait on its UTC clock rather than assuming the host clock agrees.
                  sql("INSERT INTO fpw_arrival_dispatch_control(plan_id,mode,generation,activated_at_utc,updated_at_utc)
                    VALUES (:p,'ALLOWLIST',1,UTC_TIMESTAMP(6),UTC_TIMESTAMP(6))",{p=resumed.planId});
                  var near=sql("SELECT DATE_FORMAT(TIMESTAMPADD(SECOND,2,UTC_TIMESTAMP(6)),'%Y-%m-%d %H:%i:%s') AS t").t[1];
                  revise(resumed,near);
                  var initially=sender.initialCandidatesForTest(1,near);
                  expect(initially.recordCount).toBe(1);expect(val(initially.plan_id[1])).toBe(val(resumed.planId));
                  var stopAt=getTickCount()+4000;
                  while(!val(sql("SELECT UTC_TIMESTAMP(6)>:t AS passed",{t=near}).passed[1]) && getTickCount()<stopAt) sleep(25);
                  sql("UPDATE fpw_arrival_dispatch_control SET mode='OFF',generation=generation+1 WHERE plan_id=:p",{p=resumed.planId});
                  sql("UPDATE fpw_arrival_dispatch_control SET mode='ALLOWLIST',generation=generation+1 WHERE plan_id=:p",{p=resumed.planId});
                  var generation=sql("SELECT updated_at_utc>:t AS passed, activated_at_utc<:t AS admitted_originally
                    FROM fpw_arrival_dispatch_control WHERE plan_id=:p",{t=near,p=resumed.planId});
                  expect(val(generation.passed[1])).toBe(1);expect(val(generation.admitted_originally[1])).toBe(1);
                  expect(sender.initialCandidatesForTest(1,shift(near,1)).recordCount).toBe(0);
                } finally {transaction action="rollback";}
              }
              expect(capture.submittedCount()).toBe(0);
            },false,false);
          });
        });
      });

      it("filters CAPTURE and unapproved plans out of the real global dispatch selector",function(){
        withPlan(function(f){
          var capture=new fpw.tests.support.ArrivalCaptureTransport(); var sender=worker(f,capture);
          sender.evaluatePlan(f.planId,f.due);
          makePublic(sender,"dueDeliveries","dueForCaptureTest");
          expect(sender.dueForCaptureTest(500,f.due,f.planId).recordCount).toBe(1);
          var scopedId=deliveries(f).id[1];
          for(var row in sender.dueForCaptureTest(500,f.due,0)) expect(val(row.id)).notToBe(val(scopedId));
          // The isolated mysql contains only synthetic fixtures and the transport switch remains unset.
          // Roll back this SQL-only verification of the registered allowlist scheduler query.
          transaction {
            try{
              sql("UPDATE fpw_arrival_dispatch_control SET mode='ALLOWLIST',generation=generation+1 WHERE plan_id=0");
              var unseen=sender.dueForCaptureTest(500,f.due,0);
              expect(unseen.recordCount).toBe(0);
              sql("UPDATE fpw_arrival_dispatch_control SET mode='ALLOWLIST',generation=generation+1 WHERE plan_id=:p",{p=f.planId});
              var selected=sender.dueForCaptureTest(500,f.due,0);
              expect(selected.recordCount).toBe(1); expect(val(selected.id[1])).toBe(val(scopedId));
            }finally{ transaction action="rollback"; }
          }
          expect(arrayLen(capture.calls())).toBe(0);
        });
      });

      it("serializes live handoff against deadline revision, final arrival and closure across distinct CF workers",function(){
        for(var outcome in ["REVISE","FINAL_ARRIVAL","CLOSED"]){
          withPlan(function(f){
            var capture=new fpw.tests.support.ArrivalCaptureTransport(outcome=="FINAL_ARRIVAL"?"SUBMITTED":"FAILED_RETRYABLE");
            var sender=worker(f,capture);
            sender.evaluatePlan(f.planId,f.due);var id=deliveries(f).id[1];
            var sendName="arrivalSend" & replace(createUUID(),"-","","all");
            var changeName="arrivalChange" & replace(createUUID(),"-","","all");
            var launched=false;
            capture.holdSubmission();
            thread name=sendName action="run" sender=sender id=id at=f.due {
              thread.result=attributes.sender.dispatchOne(attributes.id,attributes.at);
            }
            try{
              expect(capture.awaitSubmission()).toBeTrue();
              var nextDue=shift(f.due,240);
              thread name=changeName action="run" actionType=outcome fixture=f revised=nextDue revisedLocal=shift(nextDue,-240) {
                var fix=attributes.fixture;
                if(attributes.actionType=="FINAL_ARRIVAL"){
                  var progress=new fpw.api.v1.RouteProgressService().init();
                  thread.result=progress.markCompletionFromFloatPlanCheckin(userId=fix.userId,floatPlanId=fix.planId,
                    datasource="fpw",completionMode="active_leg",expectedLegOrder=1);
                } else {
                  transaction {
                    if(attributes.actionType=="REVISE"){
                      queryExecute("UPDATE floatplans SET returnTimeUTC=:t,returnTime=:wall WHERE floatPlanId=:p AND userId=:u",
                        {p=fix.planId,u=fix.userId,t=attributes.revised,wall=attributes.revisedLocal},{datasource="fpw"});
                      thread.result=fix.observer.reviseDeadline(fix.planId,fix.userId,1,fix.due,attributes.revised);
                    }else{
                      queryExecute("UPDATE floatplans SET status='CLOSED',closedAt=UTC_TIMESTAMP() WHERE floatPlanId=:p AND userId=:u",
                        {p=fix.planId,u=fix.userId},{datasource="fpw"});
                      thread.result=fix.observer.syncPlan(fix.planId,"CLOSED",fix.userId);
                    }
                  }
                }
              }
              launched=true;
              var waiting=false;
              var until=getTickCount()+6000;
              while(!waiting && getTickCount()<until){
                var probe=sql("SELECT COUNT(*) AS n FROM performance_schema.metadata_locks
                  WHERE OBJECT_TYPE='USER LEVEL LOCK' AND LOCK_STATUS='PENDING'
                  AND OBJECT_NAME=CONCAT('fpw:arrival:',LEFT(SHA2(DATABASE(),256),24),':',:p)",{p=f.planId});
                waiting=val(probe.n[1])>0;
                if(!waiting) sleep(25);
              }
              expect(waiting).toBeTrue("Expected the lifecycle worker to wait on the actual plan handoff fence for " & outcome);
              expect(deliveries(f).state[1]).toBe("SUBMITTING");
            } finally {
              capture.releaseSubmission(); thread action="join" name=sendName timeout=20000;
              if(launched){thread action="join" name=changeName timeout=20000;}
            }
            expect(cfthread[sendName].status).toBe("COMPLETED","Handoff " & outcome & " " & (cfthread[sendName].error.message ?: ""));
            expect(cfthread[changeName].status).toBe("COMPLETED","Lifecycle " & outcome & " " & (cfthread[changeName].error.message ?: ""));
            expect(cfthread[changeName].result.success).toBeTrue();
            expect(capture.submittedCount()).toBe(1); expect(attempts(f)).toBe(1);
            expect(deliveries(f).state[1]).toBe(outcome=="FINAL_ARRIVAL"?"SUBMITTED":"SUPPRESSED");
            sender.dispatchPlan(f.planId,shift(f.due,90)); expect(capture.submittedCount()).toBe(1);
          });
        }
      });

      it("runs overlapping workers on one recipient using separate connections and a single handoff",function(){
        withPlan(function(f){
          var capture=new fpw.tests.support.ArrivalCaptureTransport();
          var first=worker(f,capture);var second=worker(f,capture);
          first.evaluatePlan(f.planId,f.due);
          var id=deliveries(f).id[1];
          var nameA="arrivalA" & replace(createUUID(),"-","","all");
          var nameB="arrivalB" & replace(createUUID(),"-","","all");
          var launchedB=false;
          capture.holdSubmission();
          thread name=nameA action="run" sender=first id=id at=f.due {
            thread.result=attributes.sender.dispatchOne(attributes.id,attributes.at);
          }
          try {
            expect(capture.awaitSubmission()).toBeTrue();
            // The lease expires while the first transport is blocked. Its live physical fence prevents unsafe recovery.
            thread name=nameB action="run" sender=second id=id at=shift(f.due,5) {
              thread.result=attributes.sender.dispatchOne(attributes.id,attributes.at);
            }
            launchedB=true;
            thread action="join" name=nameB timeout=5000;
            expect(cfthread[nameB].status).toBe("COMPLETED");
            expect(cfthread[nameB].result.state).toBe("BUSY");
          } finally {
            capture.releaseSubmission();
            thread action="join" name=nameA timeout=20000;
            if(launchedB){thread action="join" name=nameB timeout=10000;}
          }
          expect(cfthread[nameA].status).toBe("COMPLETED");
          expect(deliveries(f).state[1]).toBe("SUBMITTED");
          expect(attempts(f)).toBe(1); expect(capture.submittedCount()).toBe(1);
        });
      });

      it("keeps the registered scheduler evaluator's routine result and reports disabled initial delivery",function(){
        // This check is deliberately stronger than zero due rows: this isolated schema must have no routine rows.
        var existing=sql("SELECT COUNT(*) AS n FROM floatplan_monitoring");
        if(val(existing.n[1])!=0) throw(message="Refusing to run routine monitoring with real or fixture rows present.");
        expect(sql("SELECT mode FROM fpw_arrival_dispatch_control WHERE plan_id=0").mode[1]).toBe("OFF");
        var result=new fpw.api.v1.monitor().init(variables.ds).evaluateDueMonitoringRows(1);
        expect(result.SUCCESS).toBeTrue();
        expect(result.PROCESSED_COUNT).toBe(0);
        expect(arrayLen(result.FLOAT_PLAN_IDS)).toBe(0);
        expect(result.ARRIVAL_OBSERVATION.mode).toBe("OFF");
        expect(result.ARRIVAL_DELIVERY.enabled).toBeFalse();
        expect(result.ARRIVAL_DELIVERY.processed).toBe(0);
        expect(val(sql("SELECT COUNT(*) AS n FROM floatplan_alert_history").n[1])).toBe(0);
      });

      it("enrolls Basic and pre-departure route plans at activation and rolls enrollment back with activation",function(){
        withPlan(function(basic){
          withPlan(function(route){
            var sender=new fpw.api.v1.ArrivalOverdueDeliveryService().init(variables.ds);
            sql("UPDATE floatplans SET status='DRAFT' WHERE floatPlanId IN (:a,:b)",{a=basic.planId,b=route.planId});
            sql("UPDATE floatplans SET route_instance_id=NULL WHERE floatPlanId=:p",{p=basic.planId});
            sql("UPDATE route_instances SET started_at=NULL,status='PLANNED' WHERE id=:r",{r=route.routeId});
            sender.runCycle();
            expect(scopeFor(basic.planId).recordCount).toBe(0);
            expect(scopeFor(route.planId).recordCount).toBe(0);
            transaction {
              try {
                sql("UPDATE floatplans SET status='ACTIVE' WHERE floatPlanId=:p",{p=basic.planId});
                sender.allowlistActivatedPlan(basic.planId);
                expect(scopeFor(basic.planId).mode[1]).toBe("ALLOWLIST");
              } finally { transaction action="rollback"; }
            }
            expect(scopeFor(basic.planId).recordCount).toBe(0);
            for (var id in [basic.planId,route.planId]) {
              transaction {
                sql("UPDATE floatplans SET status='ACTIVE' WHERE floatPlanId=:p",{p=id});
                sender.allowlistActivatedPlan(id);
              }
              var first=scopeFor(id);
              expect(first.mode[1]).toBe("ALLOWLIST");
              expect(val(first.generation[1])).toBe(1);
              sender.allowlistActivatedPlan(id);
              expect(scopeFor(id).cutoff[1]).toBe(first.cutoff[1]);
            }
            expect(scopeFor(0).mode[1]).toBe("OFF");
          },false,false);
        },false,false);
      });

      it("backfills missing active scopes in bounded batches and preserves terminal, capture and opted-out plans",function(){
        withPlan(function(first){
          withPlan(function(second){
            withPlan(function(captured){
              var sender=new fpw.api.v1.ArrivalOverdueDeliveryService().init(variables.ds);
              sql("UPDATE floatplans SET status='CLOSED',closedAt=UTC_TIMESTAMP() WHERE floatPlanId=:p",{p=first.planId});
              sql("UPDATE floatplans SET status='EXPIRED',expiredAt=UTC_TIMESTAMP(),end_reason='SINGLE_TRIP_LIMIT'
                WHERE floatPlanId=:p",{p=second.planId});
              sender.runCycle(1);
              expect(scopeFor(first.planId).recordCount).toBe(0);
              expect(scopeFor(second.planId).recordCount).toBe(0);
              sql("UPDATE floatplans SET closedAt=NULL,expiredAt=NULL,end_reason=NULL,status='CANCELLED' WHERE floatPlanId IN (:a,:b)",
                {a=first.planId,b=second.planId});
              sender.runCycle(1);
              expect(scopeFor(first.planId).recordCount+scopeFor(second.planId).recordCount).toBe(0);
              sql("UPDATE floatplans SET status='ACTIVE' WHERE floatPlanId IN (:a,:b)",{a=first.planId,b=second.planId});
              sender.runCycle(1);
              expect(scopeFor(first.planId).mode[1]).toBe("ALLOWLIST");
              expect(scopeFor(second.planId).recordCount).toBe(0);
              sql("UPDATE fpw_arrival_dispatch_control SET mode='OFF',generation=generation+1 WHERE plan_id=:p",{p=first.planId});
              var off=scopeFor(first.planId);
              var capture=scopeFor(captured.planId);
              sender.runCycle(1);
              sender.allowlistActivatedPlan(first.planId);
              sender.allowlistActivatedPlan(captured.planId);
              expect(scopeFor(second.planId).mode[1]).toBe("ALLOWLIST");
              expect(scopeFor(first.planId).mode[1]).toBe("OFF");
              expect(scopeFor(first.planId).cutoff[1]).toBe(off.cutoff[1]);
              expect(scopeFor(captured.planId).mode[1]).toBe("CAPTURE");
              expect(scopeFor(captured.planId).cutoff[1]).toBe(capture.cutoff[1]);
            });
          },false,false);
        },false,false);
      });

      it("automatically scopes production trips in ALLOWLIST and LIVE while refusing a MailHog handoff",function(){
        withPlan(function(f){
          withSchedulerConfig(function(path){
            fileWrite(path,serializeJSON({FPW_ARRIVAL_EMAIL_ENABLED=true,FPW_ARRIVAL_RECIPIENT_KEY=f.secret}),"utf-8");
            application.env="production";
            var sender=new fpw.api.v1.ArrivalOverdueDeliveryService().init(variables.ds);
            var mail=new fpw.api.v1.ArrivalOverdueMailService().init(variables.ds);
            transaction {
              try {
                sql("UPDATE fpw_arrival_rollout SET mode='OBSERVE' WHERE id=1");
                sql("UPDATE fpw_arrival_dispatch_control SET mode='LIVE',generation=generation+1 WHERE plan_id=0");
                expect(sender.evaluatePlan(f.planId).state).toBe("DISPATCH_DISABLED");
                expect(sender.runCycle(5).enabled).toBeTrue();
                expect(scopeFor(f.planId).mode[1]).toBe("ALLOWLIST");
                expect(sender.evaluatePlan(f.planId).state).toBe("NOT_DUE");
                sql("UPDATE fpw_arrival_dispatch_control SET mode='ALLOWLIST',generation=generation+1 WHERE plan_id=0");
                expect(sender.evaluatePlan(f.planId).state).toBe("NOT_DUE");
                expect(mail.submit("",{},true).reason).toBe("LIVE_TRANSPORT_DISABLED");
              } finally { transaction action="rollback"; }
            }
          });
        },false,false);
      });

      it("keeps a previously authorized LIVE retry eligible without opening an unseen past deadline",function(){
        withPlan(function(queued){
          withPlan(function(unseen){
            withSchedulerConfig(function(path){
              fileWrite(path,serializeJSON({FPW_ARRIVAL_EMAIL_ENABLED=true,FPW_ARRIVAL_RECIPIENT_KEY=queued.secret}),"utf-8");
              application.env="production";
              var sender=new fpw.api.v1.ArrivalOverdueDeliveryService().init(variables.ds);
              var mail=new fpw.api.v1.ArrivalOverdueMailService().init(variables.ds);
              var holder={};
              makePublic(sender,"prepareHandoff","checkHandoff");
              makePublic(sender,"duePlans","initialCandidates");
              transaction {
                try {
                  sql("UPDATE fpw_arrival_rollout SET mode='OBSERVE' WHERE id=1");
                  sql("UPDATE fpw_arrival_dispatch_control SET mode='LIVE',generation=generation+1 WHERE plan_id=0");
                  var due=sql("SELECT DATE_FORMAT(UTC_TIMESTAMP()+INTERVAL 2 SECOND,'%Y-%m-%d %H:%i:%s') AS t").t[1];
                  revise(queued,due);
                  revise(unseen,due);
                  var until=getTickCount()+6000;
                  while (!val(sql("SELECT UTC_TIMESTAMP()>=:t AS due",{t=due}).due[1]) && getTickCount()<until) sleep(50);
                  // Seed the previous release's durable outbox state under blanket LIVE.
                  sql("INSERT INTO fpw_arrival_notices(revision_id,slot_no,plan_id,state,recipient_count,created_at_utc)
                    SELECT id,0,plan_id,'READY',1,UTC_TIMESTAMP(6) FROM fpw_arrival_revisions WHERE plan_id=:p AND revision_no=2",
                    {p=queued.planId});
                  var recipient=mail.selectedRecipients(queued.planId).valid[1];
                  sql("INSERT INTO fpw_arrival_deliveries(notice_id,recipient_key,state,attempt_count,generation,scope_generation,
                    next_attempt_utc,created_at_utc,updated_at_utc)
                    SELECT n.id,:k,'FAILED_RETRYABLE',1,g.generation,1,UTC_TIMESTAMP(6),UTC_TIMESTAMP(6),UTC_TIMESTAMP(6)
                    FROM fpw_arrival_notices n JOIN fpw_arrival_dispatch_control g ON g.plan_id=0 WHERE n.plan_id=:p",
                    {k=recipient.recipientKey,p=queued.planId});
                  sender.allowlistActivatedPlan(queued.planId);
                  sender.allowlistActivatedPlan(unseen.planId);
                  expect(sender.evaluatePlan(unseen.planId).state).toBe("HISTORICAL_CUTOFF");
                  expect(sender.initialCandidates(5,due).recordCount).toBe(0);
                  expect(notices(unseen).recordCount).toBe(0);
                  var id=deliveries(queued).id[1];
                  var claim=sender.claimDelivery(id);
                  expect(claim.state).toBe("CLAIMED");
                  var nowUtc=sql("SELECT DATE_FORMAT(UTC_TIMESTAMP(6),'%Y-%m-%d %H:%i:%s.%f') AS t").t[1];
                  var permit=sender.checkHandoff(id,claim.token,nowUtc,holder);
                  expect(permit.state).toBe("SUBMITTING");
                  expect(permit.attempt).toBe(2);
                } finally {
                  if (structKeyExists(holder,"gate")) new fpw.api.v1.ArrivalHandoffGate().release(holder.gate);
                  transaction action="rollback";
                }
              }
            });
          },false,false);
        },false,false);
      });

      it("sends a committed earlier arrival through the save endpoint only to the newly saved contact",function(){
        withPlan(function(f){
          withSchedulerConfig(function(path){
            fileWrite(path,serializeJSON({FPW_ARRIVAL_EMAIL_ENABLED=true,FPW_ARRIVAL_RECIPIENT_KEY=f.secret}),"utf-8");
            var hadUser=structKeyExists(session,"user");
            var originalUser=hadUser ? duplicate(session.user) : {};
            try {
              session.user={USERID=f.userId};
              var sender=new fpw.api.v1.ArrivalOverdueDeliveryService().init(variables.ds);
              sender.allowlistActivatedPlan(f.planId);
              sql("UPDATE fpw_arrival_rollout SET mode='OBSERVE' WHERE id=1");
              sql("UPDATE fpw_arrival_dispatch_control SET mode='ALLOWLIST',generation=generation+1 WHERE plan_id=0");
              var handler=new fpw.api.v1.floatplan();
              makePublic(handler,"loadFloatPlan","loadChangeTest");
              makePublic(handler,"saveFloatPlan","saveChangeTest");
              var model=handler.loadChangeTest(f.userId,f.planId);
              var revised=shift(f.due,-60);
              model.RETURN_TIME_UTC=revised;
              model.RETURN_TIME=shift(revised,-300);
              model.RETURN_TIMEZONE="America/Chicago";
              var payload={FLOATPLAN=model,CONTACTS=[{CONTACTID=f.contactId}]};
              expect(handler.saveChangeTest(f.userId,payload).SUCCESS).toBeTrue();
              expect(notices(f).recordCount).toBe(0);
              model.REVISE_ARRIVAL_DEADLINE=true;
              model.EXPECTED_ARRIVAL_REVISION=99;
              expect(handler.saveChangeTest(f.userId,payload).SUCCESS).toBeFalse();
              expect(notices(f).recordCount).toBe(0);
              model.EXPECTED_ARRIVAL_REVISION=1;
              var inserted={};
              queryExecute("INSERT INTO contacts(userId,name,phone,email) VALUES(:u,'Updated recipient','5550100',:e)",
                {u=f.userId,e=f.marker & "-updated@example.test"},{datasource=variables.ds,result="local.inserted"});
              payload.CONTACTS=[{CONTACTID=val(inserted.generatedKey)}];
              transaction {
                try {
                  expect(handler.saveChangeTest(f.userId,payload).SUCCESS).toBeTrue();
                  expect(notices(f).recordCount).toBe(1);
                } finally { transaction action="rollback"; }
              }
              expect(f.observer.getRevision(f.planId)).toBe(1);
              expect(notices(f).recordCount).toBe(0);
              expect(deliveries(f).recordCount).toBe(0);
              var saved=saveOverHttp(payload);
              expect(saved.SUCCESS).toBeTrue(saved.ERROR ?: saved.MESSAGE ?: "HTTP save failed");
              expect(val(saved.FLOATPLAN.ARRIVAL_REVISION)).toBe(2);
              expect(notices(f).slot_no[1]).toBe(1);
              expect(deliveries(f).state[1]).toBe("SUBMITTED");
              expect(attempts(f)).toBe(1);
              expect(saveOverHttp(payload).SUCCESS).toBeFalse();
              model.EXPECTED_ARRIVAL_REVISION=2;
              model.RETURN_TIMEZONE="America/New_York";
              model.RETURN_TIME=shift(revised,-240); // Same UTC instant displayed in another zone.
              expect(saveOverHttp(payload).SUCCESS).toBeTrue();
              expect(notices(f).recordCount).toBe(1);
              expect(sender.runCycle().deadlineChanges.submitted).toBe(0);
            } finally {
              if (hadUser) session.user=originalUser; else structDelete(session,"user");
              sql("UPDATE fpw_arrival_dispatch_control SET mode='OFF',generation=generation+1 WHERE plan_id=0 AND mode<>'OFF'");
              sql("UPDATE fpw_arrival_rollout SET mode='OFF' WHERE id=1");
            }
          });
        },false,false);
      });

      it("retries a later arrival change once per recipient and still issues the separate overdue notice",function(){
        withPlan(function(f){
          var capture=new fpw.tests.support.ArrivalCaptureTransport("FAILED_RETRYABLE");
          var sender=changeCapture(f,capture);
          var later=shift(f.due,180);
          revise(f,later);
          var update=sender.evaluatePlan(planId=f.planId,changedRevision=2);
          expect(update.created).toBeTrue();
          expect(sender.evaluatePlan(planId=f.planId,changedRevision=2).created).toBeFalse();
          expect(sender.dispatchDeadlineChanges(update.noticeId,10,f.due).retryable).toBe(1);
          expect(sender.dispatchDeadlineChanges(update.noticeId,10,shift(f.due,4)).processed).toBe(0);
          capture.setRecipientStatus(f.contactEmail,"SUBMITTED");
          expect(sender.dispatchDeadlineChanges(update.noticeId,10,shift(f.due,5)).submitted).toBe(1);
          expect(sender.dispatchDeadlineChanges(update.noticeId,10,shift(f.due,6)).processed).toBe(0);
          expect(sender.evaluatePlan(f.planId,shift(later,-1)).state).toBe("NOT_DUE");
          expect(sender.evaluatePlan(f.planId,later).created).toBeTrue();
          sender.dispatchPlan(f.planId,later);
          var calls=capture.calls();
          expect(calls[2].message.subject).toBe("FloatPlanWizard Update: Expected Arrival Time Changed");
          expect(find("New expected arrival: ",calls[2].message.body)).toBeGT(0);
          expect(find(later & " UTC",calls[2].message.body)).toBeGT(0);
          expect(calls[3].message.subject).toBe("FloatPlanWizard Alert: Expected Arrival Time Has Passed");
          expect(notices(f).recordCount).toBe(2);
        },false,false);
      });

      it("notifies distinct selected addresses about a pre-departure change and never substitutes the owner",function(){
        withPlan(function(f){
          var capture=new fpw.tests.support.ArrivalCaptureTransport();
          var sender=changeCapture(f,capture);
          sql("DELETE FROM route_instance_leg_progress WHERE route_instance_id=:r AND user_id=:u",{r=f.routeId,u=f.userId});
          sql("UPDATE route_instances SET started_at=NULL,status='PLANNED' WHERE id=:r",{r=f.routeId});
          sql("DELETE FROM floatplan_monitoring WHERE float_plan_id=:p",{p=f.planId});
          addContact(f,uCase(f.contactEmail));
          var other=f.marker & "-second@example.test";
          addContact(f,other);
          addContact(f,"invalid-address");
          var later=shift(f.due,120);
          revise(f,later);
          var update=sender.evaluatePlan(planId=f.planId,changedRevision=2);
          expect(update.recipientCount).toBe(2);
          expect(notices(f).invalid_count[1]).toBe(1);
          expect(sender.dispatchDeadlineChanges(update.noticeId).submitted).toBe(2);
          expect(sender.evaluatePlan(f.planId,later).created).toBeFalse();
          var received={};
          for (var call in capture.calls()) received[call.address]=true;
          expect(structKeyExists(received,f.contactEmail)).toBeTrue();
          expect(structKeyExists(received,other)).toBeTrue();
          expect(structKeyExists(received,f.email)).toBeFalse();
        },false,false);
      });

      it("records no recipients for an empty change and will not replay an edit made before dispatch was enabled",function(){
        withPlan(function(f){
          var capture=new fpw.tests.support.ArrivalCaptureTransport();
          var sender=worker(f,capture);
          revise(f,shift(f.due,30));
          expect(sender.evaluatePlan(planId=f.planId,changedRevision=2).state).toBe("DISPATCH_DISABLED");
          sql("INSERT INTO fpw_arrival_dispatch_control(plan_id,mode,activated_at_utc,updated_at_utc)
            VALUES(:p,'CAPTURE',UTC_TIMESTAMP(6),UTC_TIMESTAMP(6))",{p=f.planId});
          expect(sender.evaluatePlan(planId=f.planId,changedRevision=2).state).toBe("HISTORICAL_CUTOFF");
          expect(notices(f).recordCount).toBe(0);
          transaction {
            sql("DELETE FROM floatplan_contacts WHERE floatPlanId=:p",{p=f.planId});
            var newer=shift(f.due,45);
            sql("UPDATE floatplans SET returnTimeUTC=:t WHERE floatPlanId=:p",{t=newer,p=f.planId});
            f.observer.reviseDeadline(f.planId,f.userId,2,shift(f.due,30),newer);
            var empty=sender.evaluatePlan(planId=f.planId,changedRevision=3);
          }
          expect(empty.state).toBe("NO_RECIPIENTS");
          expect(sender.dispatchDeadlineChanges(empty.noticeId).processed).toBe(0);
          expect(capture.submittedCount()).toBe(0);
        },false,false);
      });

      it("does not hand off a queued update after contact removal, closure, or another authorized change",function(){
        for (var action in ["REMOVE","CLOSE","REVISE","FINAL_LEG","OFF"]) {
          withPlan(function(f){
            var capture=new fpw.tests.support.ArrivalCaptureTransport();
            var sender=changeCapture(f,capture);
            var newDue=shift(f.due,30);
            revise(f,newDue);
            sender.evaluatePlan(planId=f.planId,changedRevision=2);
            var id=deliveries(f).id[1];
            var claim=sender.claimDelivery(id,f.due);
            expect(claim.state).toBe("CLAIMED");
            if (action=="REMOVE") sql("DELETE FROM floatplan_contacts WHERE floatPlanId=:p",{p=f.planId});
            if (action=="CLOSE") sql("UPDATE floatplans SET status='CLOSED',closedAt=UTC_TIMESTAMP() WHERE floatPlanId=:p",{p=f.planId});
            if (action=="OFF") sql("UPDATE fpw_arrival_dispatch_control SET mode='OFF',generation=generation+1 WHERE plan_id=:p",{p=f.planId});
            if (action=="FINAL_LEG") new fpw.api.v1.RouteProgressService().init().markCompletionFromFloatPlanCheckin(
              userId=f.userId,floatPlanId=f.planId,completionMode="active_leg",expectedLegOrder=1,datasource=variables.ds);
            if (action=="REVISE") {
              var replacement=shift(newDue,30);
              transaction {
                sql("UPDATE floatplans SET returnTimeUTC=:t WHERE floatPlanId=:p",{t=replacement,p=f.planId});
                f.observer.reviseDeadline(f.planId,f.userId,2,newDue,replacement);
              }
            }
            sender.submitClaim(id,claim.token,f.due);
            expect(deliveries(f).state[1]).toBe("SUPPRESSED");
            expect(capture.submittedCount()).toBe(0);
          },false,false);
        }
      });

      it("reminds the owner once at the revised deadline even without a selected shore contact",function(){
        withPlan(function(f){
          var capture=new fpw.tests.support.ArrivalCaptureTransport();
          var sender=worker(f,capture);
          sender.allowlistActivatedPlan(f.planId);
          sql("DELETE FROM floatplan_contacts WHERE floatPlanId=:p",{p=f.planId});
          var later=shift(f.due,60);
          revise(f,later);
          expect(sender.dispatchCaptainReminder(f.planId,f.due).state).toBe("INELIGIBLE");
          expect(sender.dispatchCaptainReminder(f.planId,later).state).toBe("SUBMITTED");
          expect(sender.dispatchCaptainReminder(f.planId,shift(later,5)).state).toBe("INELIGIBLE");
          expect(capture.calls()[1].address).toBe(f.email);
          expect(capture.calls()[1].message.subject).toBe("FloatPlanWizard Reminder: Close Your Float Plan");
          expect(capture.submittedCount()).toBe(1);
        });
      });

      it("reminds the captain after the final leg only while the float plan is still open",function(){
        for (var closed in [true,false]) {
          withPlan(function(f){
            var capture=new fpw.tests.support.ArrivalCaptureTransport();
            var sender=worker(f,capture);
            sender.allowlistActivatedPlan(f.planId);
            var completed=new fpw.api.v1.RouteProgressService().init().markCompletionFromFloatPlanCheckin(
              userId=f.userId,floatPlanId=f.planId,completionMode="active_leg",expectedLegOrder=1,datasource=variables.ds);
            expect(completed.COMPLETED).toBeTrue();
            expect(sender.evaluatePlan(f.planId,f.due).state).toBe("FINAL_ARRIVAL");
            if (closed) {
              sql("UPDATE floatplans SET status='CLOSED',closedAt=UTC_TIMESTAMP() WHERE floatPlanId=:p",{p=f.planId});
              new fpw.api.v1.monitor().init(variables.ds).closeMonitoringForFloatPlan(f.planId,"final_arrival");
            }
            expect(sender.dispatchCaptainReminder(f.planId,f.due).state).toBe(closed ? "INELIGIBLE" : "SUBMITTED");
            expect(capture.submittedCount()).toBe(closed ? 0 : 1);
          });
        }
      });

      it("can remind an open Basic plan or an unstarted active route without arming a shore alert",function(){
        for (var kind in ["BASIC","UNSTARTED_ROUTE"]) {
          withPlan(function(f){
            var capture=new fpw.tests.support.ArrivalCaptureTransport();
            var sender=worker(f,capture);
            if (kind=="BASIC") {
              sql("UPDATE floatplans SET route_instance_id=NULL WHERE floatPlanId=:p",{p=f.planId});
              sql("UPDATE floatplan_monitoring SET monitoring_mode='basic' WHERE float_plan_id=:p",{p=f.planId});
            } else {
              sql("DELETE FROM floatplan_monitoring WHERE float_plan_id=:p",{p=f.planId});
              sql("DELETE FROM route_instance_leg_progress WHERE route_instance_id=:r",{r=f.routeId});
              sql("UPDATE route_instances SET started_at=NULL,status='PLANNED' WHERE id=:r",{r=f.routeId});
              sql("DELETE FROM fpw_arrival_events WHERE plan_id=:p",{p=f.planId});
              sql("DELETE FROM fpw_arrival_revisions WHERE plan_id=:p",{p=f.planId});
              sql("DELETE FROM fpw_arrival_watches WHERE plan_id=:p",{p=f.planId});
              expect(sender.evaluatePlan(f.planId,f.due).created).toBeFalse();
            }
            sender.allowlistActivatedPlan(f.planId);
            expect(sender.dispatchCaptainReminder(f.planId,f.due).state).toBe("SUBMITTED");
            expect(capture.calls()[1].address).toBe(f.email);
            expect(notices(f).recordCount).toBe(0);
          });
        }
      });

      it("sends distinct messages when the owner is also the selected shore contact",function(){
        withPlan(function(f){
          var capture=new fpw.tests.support.ArrivalCaptureTransport();
          var sender=worker(f,capture);
          sql("UPDATE contacts SET email=:e WHERE contactId=:c AND userId=:u",{c=f.contactId,e=f.email,u=f.userId});
          sender.allowlistActivatedPlan(f.planId);
          sender.evaluatePlan(f.planId,f.due);
          sender.dispatchPlan(f.planId,f.due);
          expect(sender.dispatchCaptainReminder(f.planId,f.due).state).toBe("SUBMITTED");
          var calls=capture.calls();
          expect(arrayLen(calls)).toBe(2);
          expect(calls[1].address).toBe(f.email);
          expect(calls[2].address).toBe(f.email);
          expect(calls[1].message.subject).toBe("FloatPlanWizard Alert: Expected Arrival Time Has Passed");
          expect(calls[2].message.subject).toBe("FloatPlanWizard Reminder: Close Your Float Plan");
        });
      });

      it("blocks a duplicate captain handoff and fences closure after the final leg",function(){
        withPlan(function(f){
          var capture=new fpw.tests.support.ArrivalCaptureTransport();
          var sender=worker(f,capture);
          sender.allowlistActivatedPlan(f.planId);
          var completed=new fpw.api.v1.RouteProgressService().init().markCompletionFromFloatPlanCheckin(
            userId=f.userId,floatPlanId=f.planId,completionMode="active_leg",expectedLegOrder=1,datasource=variables.ds);
          expect(completed.COMPLETED).toBeTrue();
          var sendName="captainSend" & replace(createUUID(),"-","","all");
          var closeName="captainClose" & replace(createUUID(),"-","","all");
          var closing=false;
          capture.holdSubmission();
          thread name=sendName action="run" sender=sender id=f.planId at=f.due {
            thread.result=attributes.sender.dispatchCaptainReminder(attributes.id,attributes.at);
          }
          try {
            expect(capture.awaitSubmission()).toBeTrue();
            expect(sender.dispatchCaptainReminder(f.planId,f.due).state).toBe("INELIGIBLE");
            thread name=closeName action="run" id=f.planId {
              transaction {
                queryExecute("UPDATE floatplans SET status='CLOSED',closedAt=UTC_TIMESTAMP() WHERE floatPlanId=:p",
                  {p=attributes.id},{datasource="fpw"});
                thread.result=new fpw.api.v1.monitor().init("fpw").closeMonitoringForFloatPlan(attributes.id,"final_arrival");
              }
            }
            closing=true;
            var until=getTickCount()+6000;
            var waiting=false;
            while (!waiting && getTickCount()<until) {
              waiting=val(sql("SELECT COUNT(*) AS n FROM performance_schema.metadata_locks WHERE OBJECT_TYPE='USER LEVEL LOCK'
                AND LOCK_STATUS='PENDING' AND OBJECT_NAME=CONCAT('fpw:arrival:',LEFT(SHA2(DATABASE(),256),24),':',:p)",{p=f.planId}).n[1])>0;
              if (!waiting) sleep(25);
            }
            expect(waiting).toBeTrue();
          } finally {
            capture.releaseSubmission();
            thread action="join" name=sendName timeout=20000;
            if (closing) {thread action="join" name=closeName timeout=20000;}
          }
          expect(cfthread[sendName].result.state).toBe("SUBMITTED");
          expect(cfthread[closeName].result.success).toBeTrue();
          expect(sender.dispatchCaptainReminder(f.planId,shift(f.due,5)).state).toBe("INELIGIBLE");
          expect(capture.submittedCount()).toBe(1);
        });
      });

      it("skips historical or already-overdue enrollment, stopped monitoring, and disabled plans",function(){
        for (var action in ["HISTORICAL","LATE_ENROLLMENT","STOP","OPT_OUT","EXPIRED","CANCELLED","DRIFT"]) {
          withPlan(function(f){
            var capture=new fpw.tests.support.ArrivalCaptureTransport();
            var sender=worker(f,capture);
            sender.allowlistActivatedPlan(f.planId);
            if (action=="LATE_ENROLLMENT")
              sql("UPDATE floatplan_alert_history SET createdAtUTC=:t WHERE floatPlanId=:p AND alertType='CAPTAIN_CLOSEOUT'",{p=f.planId,t=f.due});
            if (action=="STOP") new fpw.api.v1.monitor().init(variables.ds).closeMonitoringForFloatPlan(f.planId,"admin_dashboard");
            if (action=="OPT_OUT") sql("UPDATE fpw_arrival_dispatch_control SET mode='OFF',generation=generation+1 WHERE plan_id=:p",{p=f.planId});
            if (action=="EXPIRED") sql("UPDATE floatplans SET status='EXPIRED',expiredAt=UTC_TIMESTAMP(),end_reason='SINGLE_TRIP_LIMIT' WHERE floatPlanId=:p",{p=f.planId});
            if (action=="CANCELLED") sql("UPDATE floatplans SET status='CANCELLED' WHERE floatPlanId=:p",{p=f.planId});
            if (action=="DRIFT") sql("UPDATE floatplans SET returnTimeUTC=:t WHERE floatPlanId=:p",{p=f.planId,t=shift(f.due,-1)});
            expect(sender.dispatchCaptainReminder(f.planId,shift(f.due,1)).state).toBe("INELIGIBLE");
            expect(capture.submittedCount()).toBe(0);
          },action=="HISTORICAL");
        }
      });

      it("retries a definite captain transport failure after 5, 15 and 30 minutes and quarantines an ambiguous one",function(){
        withPlan(function(f){
          var capture=new fpw.tests.support.ArrivalCaptureTransport("FAILED_RETRYABLE");
          var sender=worker(f,capture);
          sender.allowlistActivatedPlan(f.planId);
          for (var minutes in [0,5,20,50]) {
            if (minutes>0) expect(sender.dispatchCaptainReminder(f.planId,shift(f.due,minutes-1)).state).toBe("INELIGIBLE");
            expect(sender.dispatchCaptainReminder(f.planId,shift(f.due,minutes)).state)
              .toBe(minutes==50 ? "FAILED_PERMANENT" : "FAILED_RETRYABLE");
          }
          expect(sender.dispatchCaptainReminder(f.planId,shift(f.due,90)).state).toBe("INELIGIBLE");
          expect(capture.submittedCount()).toBe(4);
        });
        withPlan(function(f){
          var capture=new fpw.tests.support.ArrivalCaptureTransport("THROW");
          var sender=worker(f,capture);
          sender.allowlistActivatedPlan(f.planId);
          expect(sender.dispatchCaptainReminder(f.planId,f.due).state).toBe("UNKNOWN");
          expect(sender.dispatchCaptainReminder(f.planId,shift(f.due,30)).state).toBe("INELIGIBLE");
          expect(capture.submittedCount()).toBe(1);
        });
      });

      it("the normal dev scheduler sends the captain and shore contact their own email on the same pass",function(){
        withPlan(function(approved){
          withPlan(function(excluded){
            withSchedulerConfig(function(path){
              var flags={FPW_ARRIVAL_EMAIL_ENABLED=true,FPW_ARRIVAL_RECIPIENT_KEY=approved.secret};
              fileWrite(path,serializeJSON(flags),"utf-8");
              var sender=new fpw.api.v1.ArrivalOverdueDeliveryService().init(variables.ds);
              var monitor=new fpw.api.v1.monitor().init(variables.ds);
              try {
                sql("INSERT INTO fpw_arrival_dispatch_control(plan_id,mode,updated_at_utc)
                    VALUES (:p,'OFF',UTC_TIMESTAMP(6))",{p=excluded.planId});
                expect(sender.runCycle().enabled).toBeFalse();
                expect(scopeFor(approved.planId).mode[1]).toBe("ALLOWLIST");
                sql("UPDATE fpw_arrival_dispatch_control SET mode='ALLOWLIST',generation=generation+1 WHERE plan_id=0");
                expect(sender.runCycle().enabled).toBeFalse(); // Observation is still OFF.
                sql("UPDATE fpw_arrival_rollout SET mode='OBSERVE' WHERE id=1");
                sql("UPDATE fpw_arrival_dispatch_control SET mode='LIVE',generation=generation+1 WHERE plan_id=0");
                expect(sender.runCycle().enabled).toBeFalse();
                expect(sender.evaluatePlan(approved.planId).state).toBe("DISPATCH_DISABLED");
                sql("UPDATE fpw_arrival_dispatch_control SET mode='ALLOWLIST',generation=generation+1 WHERE plan_id=0");
                expect(sender.runCycle().submitted).toBe(0); // Both deadlines are in the future.
                var due=sql("SELECT DATE_FORMAT(TIMESTAMPADD(SECOND,2,UTC_TIMESTAMP()),'%Y-%m-%d %H:%i:%s') AS t").t[1];
                revise(approved,due);
                revise(excluded,due);
                var until=getTickCount()+6000;
                while (!val(sql("SELECT UTC_TIMESTAMP()>=:t AS due",{t=due}).due[1]) && getTickCount()<until) sleep(50);
                var pass=monitor.evaluateDueMonitoringRows(10).ARRIVAL_DELIVERY;
                expect(pass.enabled).toBeTrue();
                expect(pass.created).toBe(1);
                expect(pass.submitted).toBe(1);
                expect(pass.captainReminders.submitted).toBe(1);
                expect(pass.captainReminders.errors).toBe(0);
                expect(pass.errors).toBe(0);
                expect(deliveries(approved).state[1]).toBe("SUBMITTED");
                expect(notices(excluded).recordCount).toBe(0);
                var nextPass=monitor.evaluateDueMonitoringRows(10).ARRIVAL_DELIVERY;
                expect(nextPass.submitted).toBe(0);
                expect(nextPass.captainReminders.submitted).toBe(0);
                expect(attempts(approved)).toBe(1);
              } finally {
                sql("UPDATE fpw_arrival_dispatch_control SET mode='OFF',generation=generation+1 WHERE plan_id=0 AND mode<>'OFF'");
                sql("UPDATE fpw_arrival_rollout SET mode='OFF' WHERE id=1");
              }
            });
          },false,false);
        },false,false);
      });
    });
  }
}
