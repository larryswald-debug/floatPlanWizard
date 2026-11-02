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

  private void function withPlan(required any test, boolean historical=false,boolean enableCapture=true) {
    // Isolated DB tests commit only synthetic plans so independent CF worker connections see the same records.
    // The global dispatch control stays OFF. The injected capture transport is scoped to this one plan.
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

  private numeric function attempts(required struct f) {
    return val(sql("SELECT COUNT(*) AS n FROM fpw_arrival_attempts a JOIN fpw_arrival_deliveries d ON d.id=a.delivery_id
      JOIN fpw_arrival_notices n ON n.id=d.notice_id WHERE n.plan_id=:p",{p=f.planId}).n[1]);
  }

  private void function revise(required struct f,required string newDue) {
    transaction {
      sql("UPDATE floatplans SET returnTimeUTC=:t,returnTime=:wall WHERE floatPlanId=:p AND userId=:u",
        {p=f.planId,u=f.userId,t=newDue,wall=shift(newDue,-240)});
      f.observer.reviseDeadline(f.planId,f.userId,1,f.due,newDue);
    }
  }

  function run() {
    describe("Phase 3 initial arrival notices with local capture only",function(){
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
              sql("UPDATE fpw_arrival_dispatch_control SET mode='ALLOWLIST',activated_at_utc=:t,
                generation=generation+1 WHERE plan_id=0",{t=shift(f.due,-60)});
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
    });
  }
}
