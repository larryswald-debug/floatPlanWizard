component extends="testbox.system.BaseSpec" output=false {
  variables.datasource = "fpw";

  function beforeAll() {
    if (!structKeyExists(request,"arrivalPhase2TestAuthorized") || !request.arrivalPhase2TestAuthorized
        || !listFindNoCase("dev,development,local",toString(application.env ?: ""))) {
      throw(type="ArrivalTest.LocalGuard",message="Use the confirmed local Phase 2 test runner.");
    }
    var identity = sql("SELECT DATABASE() AS db_name");
    if (compareNoCase(identity.db_name[1],"FPW") != 0) {
      throw(type="ArrivalTest.DatabaseGuard",message="Expected the guarded local FPW datasource.");
    }
  }

  private any function sql(required string statement, struct params={}) {
    return queryExecute(arguments.statement,arguments.params,{datasource=variables.datasource});
  }

  private numeric function insertRow(required string statement, struct params={}) {
    var saved = {};
    queryExecute(arguments.statement,arguments.params,{datasource=variables.datasource,result="local.saved"});
    return val(saved.generatedKey);
  }

  private any function service() {
    return new fpw.api.v1.ArrivalOverdueService().init(variables.datasource);
  }

  private string function minutesFrom(required string utc, required numeric minutes) {
    var clock = sql("SELECT DATE_FORMAT(DATE_ADD(CAST(:utc AS DATETIME),INTERVAL :n MINUTE),
      '%Y-%m-%d %H:%i:%s') AS stamp",{utc=arguments.utc,n=arguments.minutes});
    return clock.stamp[1];
  }

  // The outer transaction keeps synthetic plans and the OBSERVE setting invisible to scheduler connections.
  // Every scenario, including failed assertions, restores the prior database state by rolling back.
  private void function isolated(required any scenario) {
    transaction {
      try {
        var control = sql("SELECT id,DATE_FORMAT(cutoff_utc,'%Y-%m-%d %H:%i:%s') AS cutoff,
          CONCAT(YEAR(cutoff_utc)+1,'-07-10 19:00:00') AS summer_due
          FROM fpw_arrival_rollout WHERE id=1 FOR UPDATE");
        if (control.recordCount != 1 || !len(trim(toString(control.cutoff[1] ?: "")))) {
          throw(type="ArrivalTest.MigrationRequired",message="Expected the installed rollout row and its durable cutoff.");
        }
        sql("UPDATE fpw_arrival_rollout SET mode='OBSERVE' WHERE id=1");
        arguments.scenario({due=control.summer_due[1],cutoff=control.cutoff[1]});
      } finally {
        transaction action="rollback";
      }
    }
  }

  private struct function newPlan(required string due, boolean basic=false, boolean started=true) {
    var f = {route=0, basic=arguments.basic};
    var code = "ARR" & left(replace(createUUID(),"-","","all"),21);
    var email = lCase(code) & "@example.test";
    f.owner = insertRow("INSERT INTO users (fName,lName,email,password,passwordCreated,created)
      VALUES ('Arrival','Fixture',:e,:p,UTC_TIMESTAMP(),UTC_TIMESTAMP())",{e=email,p=hash(code,"SHA-256")});
    if (!arguments.basic) {
      var template = insertRow("INSERT INTO loop_routes(code,name,short_code,is_active) VALUES(:c,:c,:c,1)",{c=code});
      f.route = insertRow("INSERT INTO route_instances(user_id,template_route_code,generated_route_id,
        generated_route_code,direction,trip_type,start_location,end_location,status,started_at)
        VALUES(:owner,:c,:template,:c,'CCW','POINT_TO_POINT','Fixture A','Fixture C',:status,:started)",
        {owner=f.owner,c=code,template=template,status=arguments.started?"ACTIVE":"PLANNED",
         started={value=minutesFrom(arguments.due,-120),null=!arguments.started,cfsqltype="cf_sql_varchar"}});
      var sectionId=insertRow("INSERT INTO route_instance_sections(route_instance_id,section_order,name)
        VALUES(:r,1,'Fixture section')",{r=f.route});
      for (var leg=1;leg<=2;leg++) {
        insertRow("INSERT INTO route_instance_legs(route_instance_id,route_instance_section_id,leg_order,start_name,end_name)
          VALUES(:r,:s,:n,'Fixture start','Fixture stop')",{r=f.route,s=sectionId,n=leg});
      }
      if (arguments.started) {
        insertRow("INSERT INTO route_instance_leg_progress(user_id,route_instance_id,leg_order,status,leg_started_at)
          VALUES(:owner,:r,1,'STARTED',:utc)",{owner=f.owner,r=f.route,utc=minutesFrom(arguments.due,-120)});
      }
    }
    f.plan = insertRow("INSERT INTO floatplans(userId,floatPlanName,dateCreated,status,activatedAt,
      route_instance_id,departureTimeUTC,departureTime,departureTZ,returnTimeUTC,returnTime,returnTZ)
      VALUES(:owner,:c,UTC_TIMESTAMP(),'ACTIVE',UTC_TIMESTAMP(),:r,:depart,:localDepart,'America/New_York',
        :due,:localDue,'America/New_York')",
      {owner=f.owner,c=code,r={value=f.route,null=arguments.basic,cfsqltype="cf_sql_integer"},
       depart=minutesFrom(arguments.due,-120),localDepart=minutesFrom(arguments.due,-360),
       due=arguments.due,localDue=minutesFrom(arguments.due,-240)});
    if (arguments.basic) {
      insertRow("INSERT INTO floatplan_basic_details(floatplan_id,vessel_name,operator_name,captain_name,
        captain_email,notification_contact_name,notification_contact_email,launch_location,destination_location,
        authority_name_snapshot,authority_phone_snapshot) VALUES(:p,'Test','Test','Test',:e,
        'Test shore',:e,'A','B','Test','5550100')",{p=f.plan,e=email});
    }
    f.monitor = insertRow("INSERT INTO floatplan_monitoring(float_plan_id,user_id,monitoring_mode,
      monitor_state,is_monitoring_enabled,expected_checkin_at,grace_expires_at,next_monitor_eval_at)
      VALUES(:p,:owner,:mode,'ACTIVE',1,:routine,:grace,:routine)",
      {p=f.plan,owner=f.owner,mode=arguments.basic?"basic":"active_route",
       routine=minutesFrom(arguments.due,180),grace=minutesFrom(arguments.due,240)});
    for(var contact=1;contact<=2;contact++){
      var cid=insertRow("INSERT INTO contacts(name,phone,userId,email) VALUES('Fixture','5550100',:owner,:e)",
        {owner=f.owner,e=code & "-" & contact & "@example.test"});
      insertRow("INSERT INTO floatplan_contacts(floatPlanId,contactId) VALUES(:p,:c)",{p=f.plan,c=cid});
    }
    return f;
  }

  private query function revision(required struct f, numeric rev=1) {
    return sql("SELECT revision_no,state,historical_only,last_slot,suppression_reason,
      DATE_FORMAT(deadline_utc,'%Y-%m-%d %H:%i:%s') AS deadline_text,
      DATE_FORMAT(next_due_utc,'%Y-%m-%d %H:%i:%s') AS next_text
      FROM fpw_arrival_revisions WHERE plan_id=:p AND revision_no=:n",{p=f.plan,n=arguments.rev});
  }

  private void function enroll(required any svc,required struct f) {
    svc.syncPlan(f.plan, f.basic ? "BASIC_START" : "ROUTE_START", f.owner);
    expect(val(svc.getRevision(f.plan))).toBe(1);
  }

  private void function finishLeg(required struct f,required numeric leg,required string utc) {
    sql("INSERT INTO route_instance_leg_progress(user_id,route_instance_id,leg_order,status,completed_at)
      VALUES(:owner,:r,:n,'COMPLETED',:utc) ON DUPLICATE KEY UPDATE status='COMPLETED',completed_at=:utc",
      {owner=f.owner,r=f.route,n=arguments.leg,utc=arguments.utc});
  }

  private numeric function eventCount(required struct f) {
    return val(sql("SELECT COUNT(*) AS n FROM fpw_arrival_events WHERE plan_id=:p",{p=f.plan}).n[1]);
  }

  function run() {
    describe("Phase 2 independent arrival observations",function(){
      it("reaches 3 PM Eastern exactly with a 6 PM routine checkpoint and never creates mail history",function(){
        isolated(function(c){
          var f=newPlan(c.due); var svc=service(); enroll(svc,f);
          svc.evaluatePlan(f.plan,minutesFrom(c.due,-1));
          expect(revision(f).state[1]).toBe("PENDING");
          svc.evaluatePlan(f.plan,c.due);
          var row=revision(f);
          expect(row.state[1]).toBe("OVERDUE");
          expect(val(row.last_slot[1])).toBe(0);
          expect(row.next_text[1]).toBe(minutesFrom(c.due,60));
          expect(val(sql("SELECT COUNT(*) AS n FROM floatplan_alert_history WHERE floatPlanId=:p",{p=f.plan}).n[1])).toBe(0);
          var routine=sql("SELECT monitor_state, DATE_FORMAT(expected_checkin_at,'%Y-%m-%d %H:%i:%s') AS checkpoint
            FROM floatplan_monitoring WHERE id=:id",{id=f.monitor});
          expect(routine.monitor_state[1]).toBe("ACTIVE");
          expect(routine.checkpoint[1]).toBe(minutesFrom(c.due,180));
        });
      });

      it("selects due and missing plans independently of routine 6 PM and null checkpoints and skips terminal work",function(){
        isolated(function(c){
          var svc=service();
          makePublic(svc,"candidateGroups","candidatesForTest");
          var inGroup=function(group,planId){
            for(var candidate in group) if(val(candidate.plan_id)==planId) return true;
            return false;
          };
          var due=newPlan(c.due); var basic=newPlan(c.due,true); var missing=newPlan(c.due);
          sql("UPDATE floatplan_monitoring SET expected_checkin_at=NULL,next_monitor_eval_at=NULL WHERE id=:id",{id=basic.monitor});
          enroll(svc,due); enroll(svc,basic);
          // This reads the scheduler's actual bounded candidate queries. Never process shared development rows.
          var candidates=svc.candidatesForTest(500,c.due);
          expect(inGroup(candidates[1],due.plan)).toBeTrue();
          expect(inGroup(candidates[1],basic.plan)).toBeTrue();
          expect(inGroup(candidates[2],missing.plan)).toBeTrue();
          finishLeg(due,1,c.due); finishLeg(due,2,c.due);
          svc.syncPlan(due.plan,"FINAL_LEG_CHECK",due.owner);
          var replay=svc.candidatesForTest(500,c.due);
          for(var group in replay) expect(inGroup(group,due.plan)).toBeFalse();
        });
      });

      it("observes an active Basic plan even when routine monitoring has no next evaluation",function(){
        isolated(function(c){
          var f=newPlan(c.due,true); var svc=service();
          sql("UPDATE floatplan_monitoring SET expected_checkin_at=NULL,next_monitor_eval_at=NULL WHERE id=:id",{id=f.monitor});
          enroll(svc,f); svc.evaluatePlan(f.plan,c.due);
          expect(revision(f).state[1]).toBe("OVERDUE");
        });
      });

      it("does not advance the arrival deadline when a routine checkpoint comes first",function(){
        isolated(function(c){
          var f=newPlan(c.due); var svc=service(); var prior=minutesFrom(c.due,-60);
          sql("UPDATE floatplan_monitoring SET expected_checkin_at=:cp,next_monitor_eval_at=:cp WHERE id=:id",{cp=prior,id=f.monitor});
          enroll(svc,f); svc.evaluatePlan(f.plan,prior);
          expect(revision(f).state[1]).toBe("PENDING");
          svc.evaluatePlan(f.plan,c.due); expect(revision(f).state[1]).toBe("OVERDUE");
        });
      });

      it("requires route-start proof before enrolling an active route-backed plan",function(){
        isolated(function(c){
          var f=newPlan(c.due,false,false); var svc=service();
          svc.syncPlan(f.plan,"ROUTE_START",f.owner);
          expect(val(svc.getRevision(f.plan))).toBe(0);
          sql("UPDATE route_instances SET status='ACTIVE',started_at=:t WHERE id=:id",{t=minutesFrom(c.due,-60),id=f.route});
          enroll(svc,f); svc.evaluatePlan(f.plan,c.due);
          expect(revision(f).state[1]).toBe("OVERDUE");
        });
      });

      it("preserves the deadline across an ordinary check-in, overnight, daily-start and delay changes",function(){
        isolated(function(c){
          var f=newPlan(c.due); var svc=service(); enroll(svc,f); svc.evaluatePlan(f.plan,c.due);
          var routine=new fpw.api.v1.monitor().init(variables.datasource);
          expect(routine.recordMonitoringCheckin(f.plan,"ON_TRACK").SUCCESS).toBeTrue();
          expect(routine.recordMonitoringCheckin(f.plan,"SECURE_FOR_NIGHT",{baseAt=minutesFrom(c.due,30)}).SUCCESS).toBeTrue();
          var persisted=sql("SELECT last_checkin_status,secure_for_night FROM floatplan_monitoring WHERE id=:id",{id=f.monitor});
          expect(persisted.last_checkin_status[1]).toBe("SECURE_FOR_NIGHT");
          expect(val(persisted.secure_for_night[1])).toBe(1);
          sql("UPDATE floatplans SET manual_delay_minutes_total=90,dailyStartLocalTime='09:00:00' WHERE floatPlanId=:p",{p=f.plan});
          svc.evaluatePlan(f.plan,minutesFrom(c.due,60));
          var row=revision(f); expect(row.deadline_text[1]).toBe(c.due);
          expect(row.state[1]).toBe("OVERDUE"); expect(val(row.last_slot[1])).toBe(1);
        });
      });

      it("continues after intermediate leg completion and stops on final progress even with stale routine monitoring",function(){
        isolated(function(c){
          var f=newPlan(c.due); var svc=service(); enroll(svc,f); svc.evaluatePlan(f.plan,c.due);
          finishLeg(f,1,minutesFrom(c.due,30));
          sql("UPDATE floatplan_monitoring SET expected_checkin_at=NULL,next_monitor_eval_at=NULL WHERE id=:id",{id=f.monitor});
          svc.syncPlan(f.plan,"FINAL_LEG_CHECK",f.owner); svc.evaluatePlan(f.plan,minutesFrom(c.due,60));
          expect(revision(f).state[1]).toBe("OVERDUE");
          finishLeg(f,2,minutesFrom(c.due,75));
          // Simulate a lost post-completion refresh. Evaluation must read canonical leg progress.
          svc.evaluatePlan(f.plan,minutesFrom(c.due,120));
          expect(revision(f).state[1]).toBe("RESOLVED");
          expect(sql("SELECT status FROM floatplans WHERE floatPlanId=:p",{p=f.plan}).status[1]).toBe("ACTIVE");
        });
      });

      it("records only the current hourly slot when a restarted evaluator catches up",function(){
        isolated(function(c){
          var f=newPlan(c.due); var svc=service(); enroll(svc,f); svc.evaluatePlan(f.plan,c.due);
          var asOf=minutesFrom(c.due,186);
          service().evaluatePlan(f.plan,asOf);
          var count=eventCount(f); var row=revision(f);
          expect(val(row.last_slot[1])).toBe(3);
          expect(row.next_text[1]).toBe(minutesFrom(c.due,240));
          var skipped=sql("SELECT COALESCE(SUM(skipped_slots),0) AS n FROM fpw_arrival_events WHERE plan_id=:p",{p=f.plan});
          expect(val(skipped.n[1])).toBe(2);
          service().evaluatePlan(f.plan,asOf);
          expect(eventCount(f)).toBe(count);
        });
      });

      it("suppresses on cancellation, expiry and admin stop and resolves on formal closure",function(){
        isolated(function(c){
          var svc=service();
          for(var reason in ["CLOSED","CANCELLED","EXPIRED","ADMIN_STOP"]){
            var f=newPlan(c.due); enroll(svc,f); svc.evaluatePlan(f.plan,c.due);
            if(reason=="ADMIN_STOP"){
              var routine=new fpw.api.v1.monitor().init(variables.datasource);
              expect(routine.closeMonitoringForFloatPlan(f.plan,"admin_dashboard").SUCCESS).toBeTrue();
              expect(revision(f).state[1]).toBe("SUPPRESSED");
            }else if(reason=="EXPIRED"){
              sql("UPDATE floatplans SET status='EXPIRED',expiredAt=:t,end_reason='SINGLE_TRIP_LIMIT'
                WHERE floatPlanId=:p",{t=minutesFrom(c.due,15),p=f.plan});
            }else{
              sql("UPDATE floatplans SET status=:s,closedAt=:t WHERE floatPlanId=:p",
                {s=reason,t=minutesFrom(c.due,15),p=f.plan});
            }
            svc.syncPlan(f.plan,reason,f.owner); service().evaluatePlan(f.plan,minutesFrom(c.due,60));
            expect(revision(f).state[1]).toBe(reason=="CLOSED"?"RESOLVED":"SUPPRESSED");
            var watch=sql("SELECT terminal_reason FROM fpw_arrival_watches WHERE plan_id=:p",{p=f.plan});
            expect(watch.terminal_reason[1]).toBe(reason);
          }
        });
      });

      it("supersedes a 3 PM deadline revised to 7 PM and rejects a stale revision",function(){
        isolated(function(c){
          var f=newPlan(c.due); var svc=service(); enroll(svc,f); svc.evaluatePlan(f.plan,c.due);
          var revised=minutesFrom(c.due,240);
          sql("UPDATE floatplans SET returnTimeUTC=:t,returnTime=:localTime WHERE floatPlanId=:p",
            {p=f.plan,t=revised,localTime=minutesFrom(revised,-240)});
          svc.reviseDeadline(f.plan,f.owner,1,c.due,revised);
          expect(revision(f).state[1]).toBe("SUPERSEDED");
          expect(val(svc.getRevision(f.plan))).toBe(2);
          svc.evaluatePlan(f.plan,minutesFrom(revised,-1)); expect(revision(f,2).state[1]).toBe("PENDING");
          svc.evaluatePlan(f.plan,revised); expect(revision(f,2).state[1]).toBe("OVERDUE");
          // An intentional transactional exception can also roll back this test's outer fixture transaction.
          expect(function(){svc.reviseDeadline(f.plan,f.owner,1,c.due,revised);}).toThrow();
        });
      });

      it("blocks unexpected stored-deadline drift and rejects a revision by another owner",function(){
        isolated(function(c){
          var f=newPlan(c.due); var svc=service(); enroll(svc,f);
          var revised=minutesFrom(c.due,60);
          sql("UPDATE floatplans SET returnTimeUTC=:t WHERE floatPlanId=:p",{t=revised,p=f.plan});
          var other=newPlan(c.due,true);
          svc.evaluatePlan(f.plan,revised);
          expect(val(svc.getRevision(f.plan))).toBe(1);
          expect(revision(f).state[1]).toBe("BLOCKED");
          expect(function(){svc.reviseDeadline(f.plan,other.owner,1,c.due,revised);}).toThrow();
        });
      });

      it("keeps a pre-cutoff revision historical across replay and classifies its authorized replacement separately",function(){
        isolated(function(c){
          var oldDue=minutesFrom(c.cutoff,-30);
          var f=newPlan(oldDue); var svc=service(); enroll(svc,f);
          svc.evaluatePlan(f.plan,c.cutoff);
          expect(val(revision(f).historical_only[1])).toBe(1);
          service().evaluatePlan(f.plan,minutesFrom(c.cutoff,120));
          expect(val(revision(f).historical_only[1])).toBe(1);
          sql("UPDATE floatplans SET returnTimeUTC=:nowDue,returnTime=:localDue WHERE floatPlanId=:p",
            {p=f.plan,nowDue=c.due,localDue=minutesFrom(c.due,-240)});
          svc.reviseDeadline(f.plan,f.owner,1,oldDue,c.due);
          expect(revision(f).state[1]).toBe("SUPERSEDED");
          expect(val(revision(f).historical_only[1])).toBe(1);
          expect(val(revision(f,2).historical_only[1])).toBe(0);
        });
      });

      it("uses distinct UTC instants for the two 1:30 AM occurrences on the Eastern fall DST transition",function(){
        isolated(function(c){
          var nov=left(c.due,4) & "-11-01";
          var day=sql("SELECT DATE_FORMAT(DATE_ADD(CAST(:nov AS DATE),INTERVAL MOD(8-DAYOFWEEK(:nov),7) DAY),
            '%Y-%m-%d') AS fold_day",{nov=nov}).fold_day[1];
          var first=day & " 05:30:00"; var second=day & " 06:30:00"; var svc=service();
          var a=newPlan(first); var b=newPlan(second);
          for(var f in [a,b]){
            sql("UPDATE floatplans SET returnTime=:wall WHERE floatPlanId=:p",{wall=day & " 01:30:00",p=f.plan});
            enroll(svc,f); svc.evaluatePlan(f.plan,first);
          }
          expect(revision(a).state[1]).toBe("OVERDUE"); expect(revision(b).state[1]).toBe("PENDING");
          svc.evaluatePlan(b.plan,second); expect(revision(b).state[1]).toBe("OVERDUE");
        });
      });

      it("requires explicit intent, owner and current revision in the canonical active Premium wizard save",function(){
        isolated(function(c){
          var f=new fpw.tests.support.CompletedContactFixture().create();
          sql("UPDATE floatplans SET departureTimeUTC=:dep,departureTime=:localDep,
            returnTimeUTC=:due,returnTime=:localDue WHERE floatPlanId=:p",
            {dep=minutesFrom(c.due,-120),localDep=minutesFrom(c.due,-360),due=c.due,localDue=minutesFrom(c.due,-240),p=f.planId});
          var svc=service();
          svc.syncPlan(f.planId,"ROUTE_START",f.userId);
          var handler=createObject("component","fpw.api.v1.floatplan");
          makePublic(handler,"saveFloatPlan","saveForArrivalTest");
          makePublic(handler,"loadFloatPlan","loadForArrivalTest");
          var model=handler.loadForArrivalTest(f.userId,f.planId);
          var edited=minutesFrom(c.due,240);
          model.RETURN_TIME_UTC=edited;
          model.RETURN_TIME=minutesFrom(edited,-240);
          var payload={FLOATPLAN=model,CONTACTS=[{CONTACTID=f.contactId}]};
          // A normal full-form save may update unrelated fields. It cannot revise the arrival.
          handler.saveForArrivalTest(f.userId,payload);
          expect(handler.loadForArrivalTest(f.userId,f.planId).RETURN_TIME_UTC).toBe(c.due);
          expect(val(svc.getRevision(f.planId))).toBe(1);
          model.REVISE_ARRIVAL_DEADLINE=true;
          model.EXPECTED_ARRIVAL_REVISION=1;
          var other=newPlan(c.due,true);
          expect(handler.saveForArrivalTest(other.owner,payload).SUCCESS).toBeFalse();
          var clearPayload=duplicate(payload);
          clearPayload.FLOATPLAN.RETURN_TIME_UTC=""; clearPayload.FLOATPLAN.RETURN_TIME="";
          expect(handler.saveForArrivalTest(f.userId,clearPayload).SUCCESS).toBeFalse();
          expect(handler.loadForArrivalTest(f.userId,f.planId).RETURN_TIME_UTC).toBe(c.due);
          var saved=handler.saveForArrivalTest(f.userId,payload);
          expect(saved.SUCCESS).toBeTrue(toString(saved.ERROR ?: saved.MESSAGE ?: "Active save was rejected"));
          expect(val(saved.FLOATPLAN.ARRIVAL_REVISION)).toBe(2);
          var sameInstant=duplicate(saved.FLOATPLAN);
          sameInstant.REVISE_ARRIVAL_DEADLINE=true;
          sameInstant.EXPECTED_ARRIVAL_REVISION=2;
          sameInstant.RETURN_TIMEZONE="America/Chicago";
          sameInstant.RETURN_TIME=minutesFrom(edited,-300);
          var replay=handler.saveForArrivalTest(f.userId,{FLOATPLAN=sameInstant,CONTACTS=[{CONTACTID=f.contactId}]});
          expect(replay.SUCCESS).toBeTrue();
          expect(replay.FLOATPLAN.RETURN_TIMEZONE).toBe("America/New_York");
          expect(replay.FLOATPLAN.RETURN_TIME).toBe(minutesFrom(edited,-240));
          expect(val(replay.FLOATPLAN.ARRIVAL_REVISION)).toBe(2);
          model.RETURN_TIME_UTC=minutesFrom(edited,60);
          model.RETURN_TIME=minutesFrom(model.RETURN_TIME_UTC,-240);
          expect(handler.saveForArrivalTest(f.userId,payload).SUCCESS).toBeFalse();
          expect(handler.loadForArrivalTest(f.userId,f.planId).RETURN_TIME_UTC).toBe(edited);
          expect(val(svc.getRevision(f.planId))).toBe(2);
        });
      });

      it("resolves inside actual final-leg completion without closing the plan or invoking a mail path",function(){
        isolated(function(c){
          var f=new fpw.tests.support.CompletedContactFixture().create();
          sql("UPDATE floatplans SET returnTimeUTC=:due WHERE floatPlanId=:p",{due=c.due,p=f.planId});
          var svc=service(); svc.syncPlan(f.planId,"ROUTE_START",f.userId); svc.evaluatePlan(f.planId,c.due);
          var progress=new fpw.api.v1.RouteProgressService().init();
          var complete=progress.markCompletionFromFloatPlanCheckin(userId=f.userId,floatPlanId=f.planId,
            completionMode="active_leg",expectedLegOrder=1,datasource=variables.datasource);
          expect(complete.SUCCESS).toBeTrue();
          expect(complete.COMPLETED).toBeTrue();
          expect(revision({plan=f.planId}).state[1]).toBe("RESOLVED");
          expect(sql("SELECT status FROM floatplans WHERE floatPlanId=:p",{p=f.planId}).status[1]).toBe("ACTIVE");
          expect(val(sql("SELECT COUNT(*) AS n FROM floatplan_alert_history WHERE floatPlanId=:p",{p=f.planId}).n[1])).toBe(0);
        });
      });

      it("keeps evaluation disabled in OFF mode and resumes observations from durable state",function(){
        isolated(function(c){
          var f=newPlan(c.due); var svc=service(); enroll(svc,f);
          sql("UPDATE fpw_arrival_rollout SET mode='OFF' WHERE id=1");
          expect(svc.evaluatePlan(f.plan,c.due).state).toBe("DISABLED");
          expect(revision(f).state[1]).toBe("PENDING");
          sql("UPDATE fpw_arrival_rollout SET mode='OBSERVE' WHERE id=1");
          service().evaluatePlan(f.plan,c.due); expect(revision(f).state[1]).toBe("OVERDUE");
        });
      });
    });
  }
}
