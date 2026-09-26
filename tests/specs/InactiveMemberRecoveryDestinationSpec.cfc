component extends="testbox.system.BaseSpec" output="false" {
  function run() {
    describe("Inactive member recovery action destinations",function() {
      beforeEach(function() {
        variables.fixture=new fpw.tests.support.RecoveryReadinessFixture();
        variables.destinations=new fpw.includes.InactiveMemberRecoveryDestinationService(datasource="fpw");
        variables.instanceIds=[];
        variables.loopIds=[];
        variables.contactIds=[];
      });
      afterEach(function() {
        for (var id in variables.contactIds) {
          queryExecute("DELETE FROM basic_review_send_receipts WHERE contact_id=:id",p(id),{datasource="fpw"});
          queryExecute("DELETE FROM contacts WHERE contactId=:id",p(id),{datasource="fpw"});
        }
        for (var id in variables.instanceIds) {
          queryExecute("DELETE FROM route_instance_leg_progress WHERE route_instance_id=:id",p(id),{datasource="fpw"});
          queryExecute("DELETE FROM route_instances WHERE id=:id",p(id),{datasource="fpw"});
        }
        for (var id in variables.loopIds) queryExecute("DELETE FROM loop_routes WHERE id=:id",p(id),{datasource="fpw"});
        variables.fixture.cleanup();
        expect(variables.fixture.counts().users).toBe(0);
        expect(variables.fixture.counts().events).toBe(0);
        expect(variables.fixture.counts().ledger).toBe(0);
      });

      it("sends A and B to the vessel and new planner actions",function() {
        var a=fixture.createMember("A");
        var b=fixture.createMember("B");
        expect(destinations.resolveStage(a.userId,"A")).toBe(path("vessel"));
        expect(destinations.resolveStage(b.userId,"B")).toBe(path("planner"));
      });

      it("uses an owned active saved route and verifies it again on click",function() {
        var member=fixture.createMember("C");
        expect(destinations.resolveStage(member.userId,"C")).toBe(path("route&routeId=" & member.routeId));
        var intent=destinations.resolveRequest(member.userId,{recoveryAction="route",routeId=member.routeId});
        expect(intent.action).toBe("route");
        expect(intent.routeId).toBe(member.routeId);
      });

      it("orders multiple saved routes by updated time and then ID",function() {
        var member=fixture.createMember("C");
        var second=route(member.userId,"2026-08-02 00:00:00");
        queryExecute("UPDATE user_routes SET updated_at='2026-08-03 00:00:00' WHERE id=:id",p(member.routeId),{datasource="fpw"});
        expect(destinations.resolveStage(member.userId,"C")).toBe(path("route&routeId=" & member.routeId));
        queryExecute("UPDATE user_routes SET updated_at='2026-08-03 00:00:00' WHERE id=:id",p(second),{datasource="fpw"});
        expect(destinations.resolveStage(member.userId,"C")).toBe(path("route&routeId=" & second));
      });

      it("falls back to routes for a missing, foreign, inactive, or deleted saved route",function() {
        var member=fixture.createMember("A");
        var other=fixture.createMember("C");
        expect(destinations.resolveStage(member.userId,"C")).toBe(path("routes"));
        for (var id in [2147483647,other.routeId]) {
          var intent=destinations.resolveRequest(member.userId,{recoveryAction="route",routeId=id});
          expect(intent.action).toBe("routes");
          expect(intent.routeId).toBe(0);
        }
        var own=route(member.userId);
        queryExecute("UPDATE user_routes SET is_active=0 WHERE id=:id",p(own),{datasource="fpw"});
        expect(destinations.resolveRequest(member.userId,{recoveryAction="route",routeId=own}).action).toBe("routes");
        expect(destinations.resolveStage(member.userId,"C")).toBe(path("routes"));
        queryExecute("DELETE FROM user_routes WHERE id=:id",p(own),{datasource="fpw"});
        expect(destinations.resolveRequest(member.userId,{recoveryAction="route",routeId=own}).action).toBe("routes");
      });

      it("continues an owned planned route instance when no saved route is available",function() {
        var member=fixture.createMember("A");
        var saved=instance(member.userId);
        expect(destinations.resolveStage(member.userId,"C")).toBe(path("route&routeInstanceId=" & saved.id));
        var intent=destinations.resolveRequest(member.userId,{recoveryAction="route",routeInstanceId=saved.id});
        expect(intent.action).toBe("route");
        expect(intent.routeInstanceId).toBe(saved.id);
        expect(intent.routeCode).toBe(saved.code);
        var ownRoute=route(member.userId);
        expect(destinations.resolveStage(member.userId,"C")).toBe(path("route&routeId=" & ownRoute));
      });

      it("rejects another member's or no-longer-planned route instance",function() {
        var member=fixture.createMember("A");
        var other=fixture.createMember("A");
        var saved=instance(other.userId);
        expect(destinations.resolveRequest(member.userId,{recoveryAction="route",routeInstanceId=saved.id}).action).toBe("routes");
        queryExecute("UPDATE route_instances SET user_id=:owner,status='ACTIVE',started_at=UTC_TIMESTAMP() WHERE id=:id",
          {owner={value=member.userId,cfsqltype="cf_sql_varchar"},id={value=saved.id,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
        expect(destinations.resolveRequest(member.userId,{recoveryAction="route",routeInstanceId=saved.id}).action).toBe("routes");
        expect(destinations.resolveStage(member.userId,"C")).toBe(path("routes"));
      });

      it("opens the unique owned Draft and rechecks ownership on click",function() {
        var member=fixture.createMember("D");
        expect(destinations.resolveStage(member.userId,"D")).toBe(path("draft&floatPlanId=" & member.planId));
        var intent=destinations.resolveRequest(member.userId,{recoveryAction="draft",floatPlanId=member.planId});
        expect(intent.action).toBe("draft");
        expect(intent.floatPlanId).toBe(member.planId);
        var other=fixture.createMember("A");
        expect(destinations.resolveRequest(other.userId,{recoveryAction="draft",floatPlanId=member.planId}).action).toBe("plans");
      });

      it("uses plans fallback for no Draft, missing IDs, and ambiguous multiple Drafts",function() {
        var member=fixture.createMember("A");
        expect(destinations.resolveStage(member.userId,"D")).toBe(path("plans"));
        expect(destinations.resolveRequest(member.userId,{recoveryAction="draft",floatPlanId=2147483647}).action).toBe("plans");
        fixture.advance(member.userId,"D");
        fixture.draft(member.userId);
        expect(destinations.resolveStage(member.userId,"D")).toBe(path("plans"));
      });

      it("falls back when an emailed Draft was activated, shared, or deleted",function() {
        var member=fixture.createMember("D");
        queryExecute("UPDATE floatplans SET status='ACTIVE',activatedAt=UTC_TIMESTAMP() WHERE floatPlanId=:id",p(member.planId),{datasource="fpw"});
        expect(destinations.resolveRequest(member.userId,{recoveryAction="draft",floatPlanId=member.planId}).action).toBe("plans");
        queryExecute("UPDATE floatplans SET status='DRAFT',activatedAt=NULL,initialSentAt=UTC_TIMESTAMP() WHERE floatPlanId=:id",p(member.planId),{datasource="fpw"});
        expect(destinations.resolveRequest(member.userId,{recoveryAction="draft",floatPlanId=member.planId}).action).toBe("plans");
        queryExecute("DELETE FROM floatplans WHERE floatPlanId=:id",p(member.planId),{datasource="fpw"});
        expect(destinations.resolveRequest(member.userId,{recoveryAction="draft",floatPlanId=member.planId}).action).toBe("plans");
      });

      it("does not reopen a shared Basic Draft when successful events exist without a status or timestamp change",function() {
        for (var name in ["basic_send_completed","premium_send_completed","recovery_share_succeeded"]) {
          var member=fixture.createMember("A");
          var id=fixture.basicDraft(member.userId);
          expect(destinations.resolveRequest(member.userId,{recoveryAction="draft",floatPlanId=id}).action).toBe("draft");
          fixture.event(member.userId,name,"float_plan",id,name EQ "premium_send_completed" ? "premium_save_send" : "basic_review_send","2026-09-01 00:00:00");
          var row=queryExecute("SELECT status,initialSentAt FROM floatplans WHERE floatPlanId=:id",p(id),{datasource="fpw"});
          expect(row.status[1]).toBe("DRAFT");
          expect(isNull(row.initialSentAt[1]) OR !len(toString(row.initialSentAt[1]))).toBeTrue();
          var intent=destinations.resolveRequest(member.userId,{recoveryAction="draft",floatPlanId=id});
          expect(intent.action).toBe("plans");
          expect(intent.floatPlanId).toBe(0);
          expect(destinations.resolveStage(member.userId,"D")).toBe(path("plans"));
        }
      });

      it("does not reopen a Draft with a successful Basic receipt even without a successful event",function() {
        var member=fixture.createMember("A");
        var id=fixture.basicDraft(member.userId);
        var inserted={};
        queryExecute("INSERT INTO contacts (name,phone,userId,email) VALUES ('Recovery receipt fixture','555-0100',:owner,'recovery-contact@example.test')",
          {owner={value=member.userId,cfsqltype="cf_sql_varchar"}},{datasource="fpw",result="inserted"});
        var contactId=val(inserted.generatedKey);
        arrayAppend(variables.contactIds,contactId);
        queryExecute("INSERT INTO basic_review_send_receipts
          (user_id,float_plan_id,contact_id,idempotency_key,status,recipient_email,created_at_utc,updated_at_utc,completed_at_utc)
          VALUES (:owner,:plan,:contact,:receiptKey,'SENT','recovery-contact@example.test',UTC_TIMESTAMP(),UTC_TIMESTAMP(),UTC_TIMESTAMP())",
          {owner={value=member.userId,cfsqltype="cf_sql_integer"},plan={value=id,cfsqltype="cf_sql_integer"},
           contact={value=contactId,cfsqltype="cf_sql_integer"},receiptKey={value=createUUID(),cfsqltype="cf_sql_varchar"}},
          {datasource="fpw"});
        var intent=destinations.resolveRequest(member.userId,{recoveryAction="draft",floatPlanId=id});
        expect(intent.action).toBe("plans");
        expect(intent.floatPlanId).toBe(0);
        expect(destinations.resolveStage(member.userId,"D")).toBe(path("plans"));
      });

      it("falls back when a Draft has current enabled monitoring",function() {
        var member=fixture.createMember("D");
        fixture.changeAfterEvaluation(member.userId,"active");
        var intent=destinations.resolveRequest(member.userId,{recoveryAction="draft",floatPlanId=member.planId});
        expect(intent.action).toBe("plans");
        expect(intent.floatPlanId).toBe(0);
        expect(destinations.resolveStage(member.userId,"D")).toBe(path("plans"));
      });

      it("falls back when a Draft's route has an unfinished started leg",function() {
        var member=fixture.createMember("D");
        var saved=instance(member.userId);
        queryExecute("UPDATE floatplans SET route_instance_id=:route WHERE floatPlanId=:plan",
          {route={value=saved.id,cfsqltype="cf_sql_integer"},plan={value=member.planId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
        queryExecute("INSERT INTO route_instance_leg_progress (user_id,route_instance_id,leg_order,status,leg_started_at)
          VALUES (:owner,:route,1,'STARTED',UTC_TIMESTAMP())",
          {owner={value=member.userId,cfsqltype="cf_sql_integer"},route={value=saved.id,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
        var intent=destinations.resolveRequest(member.userId,{recoveryAction="draft",floatPlanId=member.planId});
        expect(intent.action).toBe("plans");
        expect(intent.floatPlanId).toBe(0);
        expect(destinations.resolveStage(member.userId,"D")).toBe(path("plans"));
      });

      it("recognizes canonical Basic Drafts for the existing Basic editor",function() {
        var member=fixture.createMember("A");
        var id=fixture.basicDraft(member.userId);
        expect(destinations.resolveStage(member.userId,"D")).toBe(path("draft&floatPlanId=" & id));
        var intent=destinations.resolveRequest(member.userId,{recoveryAction="draft",floatPlanId=id});
        expect(intent.action).toBe("draft");
        expect(intent.basicDraft).toBeTrue();
        expect(intent.floatPlanId).toBe(id);
      });

      it("never lets request-supplied owner identity authorize a foreign object",function() {
        var member=fixture.createMember("A");
        var other=fixture.createMember("C");
        var intent=destinations.resolveRequest(member.userId,{recoveryAction="route",routeId=other.routeId,userId=other.userId});
        expect(intent.action).toBe("");
        expect(intent.routeId).toBe(0);
      });
    });
  }

  private string function path(required string action) { return "/app/dashboard.cfm?recoveryAction=" & arguments.action; }
  private struct function p(required numeric id) { return {id={value=arguments.id,cfsqltype="cf_sql_integer"}}; }
  private numeric function route(required numeric userId,string updatedAt="2026-08-01 00:00:00") {
    var inserted={};
    queryExecute("INSERT INTO user_routes (user_id,route_name,is_active,created_at,updated_at)
      VALUES (:owner,'Recovery destination fixture',1,UTC_TIMESTAMP(),:updated)",
      {owner={value=arguments.userId,cfsqltype="cf_sql_integer"},updated={value=arguments.updatedAt,cfsqltype="cf_sql_timestamp"}},
      {datasource="fpw",result="inserted"});
    return val(inserted.generatedKey);
  }
  private struct function instance(required numeric userId) {
    var code="REC_DEST_" & left(replace(createUUID(),"-","","all"),20);
    var inserted={};
    queryExecute("INSERT INTO loop_routes (code,name,short_code,description,is_active)
      VALUES (:code,'Recovery destination fixture',:code,'Disposable recovery destination test',1)",
      {code={value=code,cfsqltype="cf_sql_varchar"}},{datasource="fpw",result="inserted"});
    var loopId=val(inserted.generatedKey);
    arrayAppend(variables.loopIds,loopId);
    queryExecute("INSERT INTO route_instances (user_id,template_route_code,generated_route_id,generated_route_code,
      direction,trip_type,start_location,end_location,status)
      VALUES (:owner,:code,:routeId,:code,'CCW','POINT_TO_POINT','Fixture start','Fixture end','PLANNED')",
      {owner={value=arguments.userId,cfsqltype="cf_sql_varchar"},code={value=code,cfsqltype="cf_sql_varchar"},
       routeId={value=loopId,cfsqltype="cf_sql_integer"}},{datasource="fpw",result="inserted"});
    var id=val(inserted.generatedKey);
    arrayAppend(variables.instanceIds,id);
    return {id=id,code=code};
  }
}
