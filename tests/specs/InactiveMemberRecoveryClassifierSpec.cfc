component extends="testbox.system.BaseSpec" output="false" {

  variables.datasource = "fpw";
  variables.fixturePrefix = "codex-recovery-classifier-";
  variables.nowUtc = "2026-09-08T00:00:00Z";
  variables.enrollmentUtc = "2026-09-01T00:00:00Z";

  function beforeAll() {
    cleanupFixtures();
  }

  function afterAll() {
    cleanupFixtures();
  }

  function run() {
    describe("Inactive member recovery classifier", function() {
      afterEach(function() { cleanupFixtures(); });

      it("returns MEMBER_NOT_FOUND without creating recovery state", function() {
        var service = classifier();
        var beforeRows = ledgerCount();
        var result = service.evaluateMember(2147483647, variables.nowUtc, variables.enrollmentUtc);
        expect(result.DECISION_CODE).toBe("MEMBER_NOT_FOUND");
        expect(result.ELIGIBLE).toBeFalse();
        expect(ledgerCount()).toBe(beforeRows);
      });

      it("classifies an account-only member as A at the exact 168-hour boundary", function() {
        var member = createMember("a-exact", "2026-08-01 00:00:00");
        var result = classifier().evaluateMember(member.userId, variables.nowUtc, variables.enrollmentUtc);
        expect(result.CLASSIFICATION).toBe("A");
        expect(result.STAGE_ENTERED_UTC).toBe("2026-08-01T00:00:00Z");
        expect(result.EVIDENCE_SUMMARY.LATEST_ACTIVITY.STATE).toBe("NO_QUALIFYING_ACTIVITY_EVIDENCE");
        expect(result.DECISION_CODE).toBe("ELIGIBLE");
        expect(result.ELIGIBLE).toBeTrue();
      });

      it("defers at 167 hours 59 minutes 59 seconds", function() {
        var member = createMember("a-before", "2026-08-01 00:00:00");
        var result = classifier().evaluateMember(
          member.userId,
          "2026-09-07T23:59:59Z",
          variables.enrollmentUtc
        );
        expect(result.CLASSIFICATION).toBe("A");
        expect(result.DECISION_CODE).toBe("DEFERRED_WAITING_FOR_INTERVAL");
        expect(result.POLICY_DECISION.seconds_until_eligible).toBe(1);
      });

      it("classifies an owned vessel with durable creation evidence as B", function() {
        var member = createMember("b", "2026-08-01 00:00:00");
        var vesselId = createVessel(member.userId);
        insertEvent(member.userId,"vessel_created","vessel",vesselId,"member_api","2026-09-01 00:00:00");
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,"2026-08-01T00:00:00Z");
        expect(result.CLASSIFICATION).toBe("B");
        expect(result.STAGE_ENTERED_UTC).toBe("2026-09-01T00:00:00Z");
        expect(result.DECISION_CODE).toBe("ELIGIBLE");
      });

      it("holds a vessel stage without a verified B clock", function() {
        var member = createMember("b-no-clock", "2026-08-01 00:00:00");
        createVessel(member.userId);
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,variables.enrollmentUtc);
        expect(result.CLASSIFICATION).toBe("B");
        expect(result.DECISION_CODE).toBe("HOLD_INCOMPLETE_STAGE_CLOCK");
      });

      it("classifies a saved named route with no legs as C", function() {
        var member = createMember("c-empty", "2026-07-01 00:00:00");
        var routeId = createNamedRoute(member.userId,false);
        insertEvent(member.userId,"user_route_created","user_route",routeId,"member_api","2026-08-01 00:00:00");
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,"2026-07-01T00:00:00Z");
        expect(result.CLASSIFICATION).toBe("C");
        expect(result.STAGE_ENTERED_UTC).toBe("2026-08-01T00:00:00Z");
        expect(result.DECISION_CODE).toBe("ELIGIBLE");
      });

      it("classifies a saved named route with persisted legs as C", function() {
        var member = createMember("c-legs", "2026-07-01 00:00:00");
        var routeId = createNamedRoute(member.userId,true);
        insertEvent(member.userId,"user_route_created","user_route",routeId,"member_api","2026-08-01 00:00:00");
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,"2026-07-01T00:00:00Z");
        expect(result.CLASSIFICATION).toBe("C");
        expect(result.DECISION_CODE).toBe("ELIGIBLE");
      });

      it("classifies an owned Draft as D and enforces highest-stage precedence", function() {
        var member = createMember("d", "2026-06-01 00:00:00");
        var vesselId = createVessel(member.userId);
        var routeId = createNamedRoute(member.userId,false);
        var planId = createDraft(member.userId,0,"premium_saved_route");
        insertEvent(member.userId,"vessel_created","vessel",vesselId,"member_api","2026-06-02 00:00:00");
        insertEvent(member.userId,"user_route_created","user_route",routeId,"member_api","2026-06-03 00:00:00");
        insertEvent(member.userId,"float_plan_created","float_plan",planId,"member_api","2026-08-01 00:00:00");
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,"2026-06-01T00:00:00Z");
        expect(result.CLASSIFICATION).toBe("D");
        expect(result.HIGHEST_VERIFIED_STAGE).toBe("D");
        expect(result.DECISION_CODE).toBe("ELIGIBLE");
      });

      it("classifies a persisted generated Draft as D", function() {
        var member = createMember("d-generated", "2026-06-01 00:00:00");
        var routeInstanceId = createRouteInstance(member.userId,"PLANNED");
        var planId = createDraft(member.userId,routeInstanceId,"great_loop_generated");
        insertEvent(member.userId,"route_created","route_instance",routeInstanceId,"member_api","2026-07-01 00:00:00");
        insertEvent(member.userId,"float_plan_created","float_plan",planId,"member_api","2026-08-01 00:00:00");
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,"2026-06-01T00:00:00Z");
        expect(result.CLASSIFICATION).toBe("D");
        expect(result.EVIDENCE_SUMMARY.LIVE.DRAFT_EXISTS).toBeTrue();
      });

      it("permanently suppresses durable Basic sharing evidence", function() {
        var member = createMember("shared-basic", "2026-06-01 00:00:00");
        insertEvent(member.userId,"basic_send_completed","float_plan",999999001,"basic_review_send","2026-08-01 00:00:00");
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,"");
        expect(result.CLASSIFICATION).toBe("SHARED");
        expect(result.DECISION_CODE).toBe("SUPPRESSED_ALREADY_SHARED");
      });

      it("permanently suppresses durable Premium sharing evidence", function() {
        var member = createMember("shared-premium", "2026-06-01 00:00:00");
        insertEvent(member.userId,"premium_send_completed","float_plan",999999002,"premium_save_send","2026-08-01 00:00:00");
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,"");
        expect(result.CLASSIFICATION).toBe("SHARED");
        expect(result.DECISION_CODE).toBe("SUPPRESSED_ALREADY_SHARED");
      });

      it("keeps positive sharing suppression independent of the timing clock", function() {
        var member = createMember("shared-bad-clock", "2026-06-01 00:00:00");
        insertEvent(member.userId,"premium_send_completed","float_plan",999999005,"premium_save_send","2026-08-01 00:00:00");
        var result = classifier().evaluateMember(member.userId,"not-a-clock","");
        expect(result.CLASSIFICATION).toBe("SHARED");
        expect(result.DECISION_CODE).toBe("SUPPRESSED_ALREADY_SHARED");
      });

      it("keeps Basic sharing suppression after its parent record is absent", function() {
        var member = createMember("shared-deleted", "2026-06-01 00:00:00");
        insertEvent(member.userId,"basic_send_completed","float_plan",999999003,"basic_save_send","2026-08-01 00:00:00");
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,variables.enrollmentUtc);
        expect(result.EVIDENCE_SUMMARY.SHARE.BASIC_EVENT).toBeTrue();
        expect(result.DECISION_CODE).toBe("SUPPRESSED_ALREADY_SHARED");
      });

      it("treats an owned initial-send timestamp as positive sharing evidence", function() {
        var member = createMember("shared-initial-send", "2026-06-01 00:00:00");
        var planId = createDraft(member.userId);
        queryExecute(
          "UPDATE floatplans SET initialSentAt=CAST('2026-08-01 00:00:00' AS DATETIME) WHERE floatPlanId=:planId",
          {planId={value=planId,cfsqltype="cf_sql_integer"}},
          {datasource=variables.datasource}
        );
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,"");
        expect(result.CLASSIFICATION).toBe("SHARED");
        expect(result.EVIDENCE_SUMMARY.SHARE.INITIAL_SEND).toBeTrue();
        expect(result.DECISION_CODE).toBe("SUPPRESSED_ALREADY_SHARED");
      });

      it("suppresses a real non-essential opt-out", function() {
        var member = createMember("opted-out", "2026-08-01 00:00:00");
        var preference = new fpw.api.v1.EmailOptOutService(datasource=variables.datasource);
        var saved = preference.recordOptOut(member.email,member.userId,"non_essential","classifier_test");
        expect(saved.success).toBeTrue();
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,variables.enrollmentUtc);
        expect(result.DECISION_CODE).toBe("SUPPRESSED_OPTED_OUT");
      });

      it("holds when preference lookup fails", function() {
        var member = createMember("preference-fail", "2026-08-01 00:00:00");
        var failing = new fpw.tests.support.RecoveryClassifierPreferenceFailureStub();
        var result = classifier(failing).evaluateMember(member.userId,variables.nowUtc,variables.enrollmentUtc);
        expect(result.DECISION_CODE).toBe("HOLD_PREFERENCE_LOOKUP_FAILED");
      });

      it("suppresses an authoritative active administrator entitlement", function() {
        var member = createMember("admin", "2026-08-01 00:00:00");
        createAdminEntitlement(member.userId);
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,variables.enrollmentUtc);
        expect(result.DECISION_CODE).toBe("SUPPRESSED_ADMIN");
        expect(result.EVIDENCE_SUMMARY.ADMIN_ENTITLEMENT_ACTIVE).toBeTrue();
      });

      it("suppresses an invalid current recipient", function() {
        var invalidAddress = variables.fixturePrefix & "invalid-" & lCase(replace(createUUID(), "-", "", "all"));
        var member = createMember("invalid", "2026-08-01 00:00:00", invalidAddress);
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,variables.enrollmentUtc);
        expect(result.DECISION_CODE).toBe("SUPPRESSED_INVALID_EMAIL");
      });

      it("holds duplicate normalized recipient identity", function() {
        var duplicate = variables.fixturePrefix & "duplicate@example.test";
        var first = createMember("duplicate-a", "2026-08-01 00:00:00", duplicate);
        createMember("duplicate-b", "2026-08-01 00:00:00", uCase(duplicate));
        var result = classifier().evaluateMember(first.userId,variables.nowUtc,variables.enrollmentUtc);
        expect(result.DECISION_CODE).toBe("HOLD_DUPLICATE_EMAIL_IDENTITY");
      });

      it("suppresses an active trip without treating it as a Draft", function() {
        var member = createMember("active-plan", "2026-06-01 00:00:00");
        var planId = createDraft(member.userId,0,"premium_saved_route","ACTIVE");
        insertEvent(member.userId,"float_plan_created","float_plan",planId,"member_api","2026-08-01 00:00:00");
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,variables.enrollmentUtc);
        expect(result.DECISION_CODE).toBe("SUPPRESSED_ACTIVE_TRIP");
      });

      it("suppresses current monitoring", function() {
        var member = createMember("monitoring", "2026-06-01 00:00:00");
        var planId = createDraft(member.userId);
        insertEvent(member.userId,"float_plan_created","float_plan",planId,"member_api","2026-08-01 00:00:00");
        createMonitoring(member.userId,planId);
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,variables.enrollmentUtc);
        expect(result.DECISION_CODE).toBe("SUPPRESSED_ACTIVE_TRIP");
        expect(result.EVIDENCE_SUMMARY.LIVE.ACTIVE_MONITORING_EXISTS).toBeTrue();
      });

      it("suppresses a stage already sent and reads the ledger without exposing a claim token", function() {
        var member = createMember("ledger-sent", "2026-08-01 00:00:00");
        insertLedger(member.userId,"A","SENT","2026-09-01 00:00:00");
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,variables.enrollmentUtc);
        expect(result.DECISION_CODE).toBe("SUPPRESSED_STAGE_ALREADY_SENT");
        expect(result.LEDGER_STATE.STATUS).toBe("SENT");
        expect(structKeyExists(result.LEDGER_STATE,"CLAIM_TOKEN")).toBeFalse();
      });

      it("suppresses an unresolved claim and holds a definite failure for explicit retry", function() {
        var claimedMember = createMember("ledger-claimed", "2026-08-01 00:00:00");
        insertLedger(claimedMember.userId,"A","CLAIMED","2026-09-01 00:00:00");
        var claimed = classifier().evaluateMember(claimedMember.userId,variables.nowUtc,variables.enrollmentUtc);
        expect(claimed.DECISION_CODE).toBe("SUPPRESSED_UNRESOLVED_CLAIM");

        cleanupFixtures();
        var failedMember = createMember("ledger-failed", "2026-08-01 00:00:00");
        insertLedger(failedMember.userId,"A","FAILED","2026-09-01 00:00:00");
        var failed = classifier().evaluateMember(failedMember.userId,variables.nowUtc,variables.enrollmentUtc);
        expect(failed.DECISION_CODE).toBe("HOLD_RETRY_DECISION_REQUIRED");
      });

      it("delays for recent qualifying activity through the real policy", function() {
        var member = createMember("recent", "2026-06-01 00:00:00");
        var vesselId = createVessel(member.userId);
        insertEvent(member.userId,"vessel_created","vessel",vesselId,"member_api","2026-07-01 00:00:00");
        insertEvent(member.userId,"vessel_updated","vessel",vesselId,"member_api","2026-09-07 00:00:00");
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,"2026-06-01T00:00:00Z");
        expect(result.DECISION_CODE).toBe("SUPPRESSED_RECENT_ACTIVITY");
        expect(result.POLICY_DECISION.reason).toBe("WAITING_FOR_INTERVAL");
      });

      it("delays cross-stage recovery spacing through the real policy", function() {
        var member = createMember("spacing", "2026-06-01 00:00:00");
        var vesselId = createVessel(member.userId);
        insertEvent(member.userId,"vessel_created","vessel",vesselId,"member_api","2026-07-01 00:00:00");
        insertLedger(member.userId,"A","SENT","2026-09-07 00:00:00");
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,"2026-06-01T00:00:00Z");
        expect(result.DECISION_CODE).toBe("SUPPRESSED_CROSS_STAGE_SPACING");
        expect(result.LATEST_RECOVERY_SENT_UTC).toBe("2026-09-07T00:00:00Z");
      });

      it("allows a later higher stage after a fresh interval", function() {
        var member = createMember("later-stage", "2026-06-01 00:00:00");
        var vesselId = createVessel(member.userId);
        insertEvent(member.userId,"vessel_created","vessel",vesselId,"member_api","2026-09-01 00:00:00");
        insertLedger(member.userId,"A","SENT","2026-08-01 00:00:00");
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,"2026-06-01T00:00:00Z");
        expect(result.CLASSIFICATION).toBe("B");
        expect(result.DECISION_CODE).toBe("ELIGIBLE");
      });

      it("requires explicit enrollment and never invents it from deployment time", function() {
        var member = createMember("no-enrollment", "2026-08-01 00:00:00");
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,"");
        expect(result.DECISION_CODE).toBe("ENROLLMENT_EVIDENCE_REQUIRED");
        expect(result.POLICY_DECISION).toBeEmpty();
      });

      it("holds historical regression instead of downgrading after deletion", function() {
        var member = createMember("history-regression", "2026-06-01 00:00:00");
        insertEvent(member.userId,"float_plan_created","float_plan",999999004,"member_api","2026-07-01 00:00:00");
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,variables.enrollmentUtc);
        expect(result.CLASSIFICATION).toBe("A");
        expect(result.HIGHEST_VERIFIED_STAGE).toBe("D");
        expect(result.DECISION_CODE).toBe("HOLD_CONTRADICTORY_EVIDENCE");
      });

      it("holds future activity and inconsistent Draft lifecycle evidence", function() {
        var member = createMember("future", "2026-06-01 00:00:00");
        var vesselId = createVessel(member.userId);
        insertEvent(member.userId,"vessel_created","vessel",vesselId,"member_api","2026-07-01 00:00:00");
        insertEvent(member.userId,"vessel_updated","vessel",vesselId,"member_api","2026-10-01 00:00:00");
        var future = classifier().evaluateMember(member.userId,variables.nowUtc,variables.enrollmentUtc);
        expect(future.DECISION_CODE).toBe("HOLD_CONTRADICTORY_EVIDENCE");

        cleanupFixtures();
        var draftMember = createMember("bad-draft", "2026-06-01 00:00:00");
        var routeInstanceId = createRouteInstance(draftMember.userId,"COMPLETED");
        var planId = createDraft(draftMember.userId,routeInstanceId,"great_loop_generated");
        insertEvent(draftMember.userId,"float_plan_created","float_plan",planId,"member_api","2026-07-01 00:00:00");
        var contradictory = classifier().evaluateMember(draftMember.userId,variables.nowUtc,variables.enrollmentUtc);
        expect(contradictory.DECISION_CODE).toBe("HOLD_CONTRADICTORY_EVIDENCE");
      });

      it("holds cross-member event ownership and returns only safe evidence metadata", function() {
        var owner = createMember("owner", "2026-06-01 00:00:00");
        var other = createMember("other", "2026-06-01 00:00:00");
        var vesselId = createVessel(other.userId);
        insertEvent(owner.userId,"vessel_created","vessel",vesselId,"member_api","2026-07-01 00:00:00");
        var result = classifier().evaluateMember(owner.userId,variables.nowUtc,variables.enrollmentUtc);
        var serialized = serializeJSON(result);
        expect(result.DECISION_CODE).toBe("HOLD_CONTRADICTORY_EVIDENCE");
        expect(findNoCase(owner.email,serialized)).toBe(0);
        expect(findNoCase("CLAIM_TOKEN",serialized)).toBe(0);
        expect(findNoCase("ROUTE_NAME",serialized)).toBe(0);
        expect(findNoCase("VESSEL_NAME",serialized)).toBe(0);
      });

      it("holds cross-member update activity instead of using its timestamp", function() {
        var member = createMember("activity-owner", "2026-06-01 00:00:00");
        var other = createMember("activity-other", "2026-06-01 00:00:00");
        var vesselId = createVessel(other.userId);
        insertEvent(member.userId,"vessel_updated","vessel",vesselId,"member_api","2026-09-07 00:00:00");
        var result = classifier().evaluateMember(member.userId,variables.nowUtc,variables.enrollmentUtc);
        expect(result.DECISION_CODE).toBe("HOLD_CONTRADICTORY_EVIDENCE");
      });

      it("does not write events or ledger rows while evaluating", function() {
        var member = createMember("read-only", "2026-08-01 00:00:00");
        var beforeEvents = eventCount(member.userId);
        var beforeLedger = ledgerCount(member.userId);
        classifier().evaluateMember(member.userId,variables.nowUtc,variables.enrollmentUtc);
        classifier().evaluateMember(member.userId,variables.nowUtc,variables.enrollmentUtc);
        expect(eventCount(member.userId)).toBe(beforeEvents);
        expect(ledgerCount(member.userId)).toBe(beforeLedger);
      });
    });
  }

  private any function classifier(any optOutService="") {
    return isObject(arguments.optOutService)
      ? new fpw.includes.InactiveMemberRecoveryClassifierService(
          datasource=variables.datasource,
          optOutService=arguments.optOutService
        )
      : new fpw.includes.InactiveMemberRecoveryClassifierService(datasource=variables.datasource);
  }

  private struct function createMember(required string suffix, string signupAt="", string emailOverride="") {
    var marker = variables.fixturePrefix & arguments.suffix & "-" & lCase(replace(createUUID(),"-","","all"));
    var email = len(arguments.emailOverride) ? arguments.emailOverride : marker & "@example.test";
    var createdAt = len(arguments.signupAt) ? arguments.signupAt : "2026-08-01 00:00:00";
    var insertResult = {};
    queryExecute(
      "INSERT INTO users (fName,lName,email,password,passwordCreated,created)
       VALUES ('Classifier','Fixture',:email,:password,CAST(:createdAt AS DATETIME),CAST(:createdAt AS DATETIME))",
      {
        email={value=email,cfsqltype="cf_sql_varchar"},
        password={value=hash(marker,"SHA-256"),cfsqltype="cf_sql_varchar"},
        createdAt={value=createdAt,cfsqltype="cf_sql_varchar"}
      },
      {datasource=variables.datasource,result="insertResult"}
    );
    var userId = val(insertResult.generatedKey);
    if (len(arguments.signupAt)) {
      insertEvent(userId,"sign_up","user",userId,"member_signup",arguments.signupAt);
    }
    return {userId=userId,email=email,marker=marker};
  }

  private numeric function createVessel(required numeric userId) {
    var insertResult = {};
    queryExecute(
      "INSERT INTO vessels (userId,vesselName,hailingPort,isDefaultVessel)
       VALUES (CAST(:userId AS CHAR),'Classifier Vessel','Test Port',1)",
      {userId={value=arguments.userId,cfsqltype="cf_sql_integer"}},
      {datasource=variables.datasource,result="insertResult"}
    );
    return val(insertResult.generatedKey);
  }

  private numeric function createNamedRoute(required numeric userId, boolean withLeg=false) {
    var insertResult = {};
    queryExecute(
      "INSERT INTO user_routes (user_id,route_name,is_active,created_at,updated_at)
       VALUES (:userId,:name,1,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
      {
        userId={value=arguments.userId,cfsqltype="cf_sql_integer"},
        name={value=variables.fixturePrefix & createUUID(),cfsqltype="cf_sql_varchar"}
      },
      {datasource=variables.datasource,result="insertResult"}
    );
    var routeId = val(insertResult.generatedKey);
    if (arguments.withLeg) {
      queryExecute(
        "INSERT INTO user_route_legs (user_route_id,order_index,created_at,updated_at)
         VALUES (:routeId,1,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
        {routeId={value=routeId,cfsqltype="cf_sql_integer"}},
        {datasource=variables.datasource}
      );
    }
    return routeId;
  }

  private numeric function createRouteInstance(required numeric userId, string status="PLANNED") {
    var code = "CLASSIFIER_" & arguments.userId & "_" & left(replace(createUUID(),"-","","all"),16);
    var loopResult = {};
    var instanceResult = {};
    queryExecute(
      "INSERT INTO loop_routes (code,name,short_code,description,is_active)
       VALUES (:code,'Classifier Route',:code,:description,1)",
      {
        code={value=code,cfsqltype="cf_sql_varchar"},
        description={value=variables.fixturePrefix,cfsqltype="cf_sql_varchar"}
      },
      {datasource=variables.datasource,result="loopResult"}
    );
    queryExecute(
      "INSERT INTO route_instances (user_id,template_route_code,generated_route_id,generated_route_code,
        direction,trip_type,start_location,end_location,status,started_at,completed_at)
       VALUES (CAST(:userId AS CHAR),:code,:routeId,:code,'CCW','POINT_TO_POINT','Test Start','Test End',:status,
         CASE WHEN :status='ACTIVE' THEN UTC_TIMESTAMP() ELSE NULL END,
         CASE WHEN :status='COMPLETED' THEN UTC_TIMESTAMP() ELSE NULL END)",
      {
        userId={value=arguments.userId,cfsqltype="cf_sql_integer"},
        code={value=code,cfsqltype="cf_sql_varchar"},
        routeId={value=val(loopResult.generatedKey),cfsqltype="cf_sql_integer"},
        status={value=uCase(arguments.status),cfsqltype="cf_sql_varchar"}
      },
      {datasource=variables.datasource,result="instanceResult"}
    );
    return val(instanceResult.generatedKey);
  }

  private numeric function createDraft(
    required numeric userId,
    numeric routeInstanceId=0,
    string routeOrigin="basic_manual",
    string status="DRAFT"
  ) {
    var insertResult = {};
    queryExecute(
      "INSERT INTO floatplans (userId,floatPlanName,dateCreated,lastUpdate,status,lastUpdateStatus,
        route_instance_id,route_origin,is_reusable,is_visible_in_route_library,activatedAt)
       VALUES (CAST(:userId AS CHAR),'Classifier Draft',UTC_TIMESTAMP(),UTC_TIMESTAMP(),:status,UTC_TIMESTAMP(),
        :routeId,:origin,1,1,CASE WHEN :status='ACTIVE' THEN UTC_TIMESTAMP() ELSE NULL END)",
      {
        userId={value=arguments.userId,cfsqltype="cf_sql_integer"},
        status={value=uCase(arguments.status),cfsqltype="cf_sql_varchar"},
        routeId={value=arguments.routeInstanceId,cfsqltype="cf_sql_integer",null=(arguments.routeInstanceId LTE 0)},
        origin={value=arguments.routeOrigin,cfsqltype="cf_sql_varchar"}
      },
      {datasource=variables.datasource,result="insertResult"}
    );
    return val(insertResult.generatedKey);
  }

  private void function createMonitoring(required numeric userId, required numeric planId) {
    queryExecute(
      "INSERT INTO floatplan_monitoring (float_plan_id,user_id,monitoring_mode,monitor_state,is_monitoring_enabled)
       VALUES (:planId,:userId,'basic','ACTIVE',1)",
      {
        planId={value=arguments.planId,cfsqltype="cf_sql_bigint"},
        userId={value=arguments.userId,cfsqltype="cf_sql_bigint"}
      },
      {datasource=variables.datasource}
    );
  }

  private void function createAdminEntitlement(required numeric userId) {
    queryExecute(
      "INSERT INTO member_entitlements (user_id,entitlement_type,source,status,starts_at_utc,expires_at_utc,created_utc,updated_utc)
       VALUES (:userId,'admin','classifier_test','active',UTC_TIMESTAMP()-INTERVAL 1 DAY,UTC_TIMESTAMP()+INTERVAL 1 DAY,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
      {userId={value=arguments.userId,cfsqltype="cf_sql_integer"}},
      {datasource=variables.datasource}
    );
  }

  private void function insertEvent(
    required numeric userId,
    required string eventName,
    required string entityType,
    required numeric entityId,
    required string eventSource,
    required string occurredAt
  ) {
    var key = variables.fixturePrefix & lCase(replace(createUUID(),"-","","all"));
    queryExecute(
      "INSERT INTO product_events (event_uuid,user_id,event_name,entity_type,entity_id,event_source,
        occurred_at_utc,metadata_json,created_at_utc,idempotency_key)
       VALUES (:uuid,:userId,:eventName,:entityType,:entityId,:eventSource,CAST(:occurredAt AS DATETIME),'{}',UTC_TIMESTAMP(),:eventKey)",
      {
        uuid={value=createUUID(),cfsqltype="cf_sql_char"},
        userId={value=arguments.userId,cfsqltype="cf_sql_integer"},
        eventName={value=arguments.eventName,cfsqltype="cf_sql_varchar"},
        entityType={value=arguments.entityType,cfsqltype="cf_sql_varchar"},
        entityId={value=arguments.entityId,cfsqltype="cf_sql_bigint"},
        eventSource={value=arguments.eventSource,cfsqltype="cf_sql_varchar"},
        occurredAt={value=arguments.occurredAt,cfsqltype="cf_sql_varchar"},
        eventKey={value=key,cfsqltype="cf_sql_varchar"}
      },
      {datasource=variables.datasource}
    );
  }

  private void function insertLedger(
    required numeric userId,
    required string stage,
    required string status,
    required string atUtc
  ) {
    var normalizedStatus = uCase(arguments.status);
    queryExecute(
      "INSERT INTO inactive_member_recovery_deliveries (
        user_id,recovery_stage,status,claim_token,claimed_at_utc,sent_at_utc,failed_at_utc,
        attempt_count,last_error_summary,created_at_utc,updated_at_utc)
       VALUES (:userId,:stage,:status,:token,CAST(:atUtc AS DATETIME),:sentAt,:failedAt,
        1,:errorCode,CAST(:atUtc AS DATETIME),CAST(:atUtc AS DATETIME))",
      {
        userId={value=arguments.userId,cfsqltype="cf_sql_integer"},
        stage={value=uCase(arguments.stage),cfsqltype="cf_sql_char"},
        status={value=normalizedStatus,cfsqltype="cf_sql_varchar"},
        token={value=repeatString("a",64),cfsqltype="cf_sql_char"},
        atUtc={value=arguments.atUtc,cfsqltype="cf_sql_varchar"},
        sentAt={value=arguments.atUtc,cfsqltype="cf_sql_timestamp",null=(normalizedStatus NEQ "SENT")},
        failedAt={value=arguments.atUtc,cfsqltype="cf_sql_timestamp",null=(normalizedStatus NEQ "FAILED")},
        errorCode={value="CONTROLLED_FAILURE",cfsqltype="cf_sql_varchar",null=(normalizedStatus NEQ "FAILED")}
      },
      {datasource=variables.datasource}
    );
  }

  private numeric function eventCount(required numeric userId) {
    var q=queryExecute("SELECT COUNT(*) AS total FROM product_events WHERE user_id=:userId",
      {userId={value=arguments.userId,cfsqltype="cf_sql_integer"}}, {datasource=variables.datasource});
    return val(q.total[1]);
  }

  private numeric function ledgerCount(numeric userId=0) {
    var sql="SELECT COUNT(*) AS total FROM inactive_member_recovery_deliveries";
    var params={};
    if (arguments.userId GT 0) {
      sql &= " WHERE user_id=:userId";
      params.userId={value=arguments.userId,cfsqltype="cf_sql_integer"};
    }
    var q=queryExecute(sql,params,{datasource=variables.datasource});
    return val(q.total[1]);
  }

  private void function cleanupFixtures() {
    var users=queryExecute(
      "SELECT u.userId FROM users u WHERE LOWER(u.email) LIKE :pattern
        OR (u.email='not-an-email' AND EXISTS (
          SELECT 1 FROM product_events e
          WHERE e.user_id=u.userId AND e.idempotency_key LIKE :pattern
        ))",
      {pattern={value=lCase(variables.fixturePrefix) & "%",cfsqltype="cf_sql_varchar"}},
      {datasource=variables.datasource}
    );
    if (!users.recordCount) {
      queryExecute("DELETE FROM loop_routes WHERE description=:marker",
        {marker={value=variables.fixturePrefix,cfsqltype="cf_sql_varchar"}}, {datasource=variables.datasource});
      return;
    }
    var ids=valueList(users.userId);
    var params={ids={value=ids,cfsqltype="cf_sql_integer",list=true}};
    queryExecute("DELETE FROM email_optout WHERE user_id IN (:ids)",params,{datasource=variables.datasource});
    queryExecute("DELETE FROM inactive_member_recovery_deliveries WHERE user_id IN (:ids)",params,{datasource=variables.datasource});
    queryExecute("DELETE FROM product_events WHERE user_id IN (:ids)",params,{datasource=variables.datasource});
    queryExecute("DELETE FROM floatplan_monitoring WHERE user_id IN (:ids)",params,{datasource=variables.datasource});
    queryExecute("DELETE FROM basic_review_send_receipts WHERE user_id IN (:ids)",params,{datasource=variables.datasource});
    queryExecute("DELETE FROM premium_send_receipts WHERE user_id IN (:ids)",params,{datasource=variables.datasource});
    queryExecute("DELETE FROM floatplan_contacts WHERE floatPlanId IN (SELECT floatPlanId FROM floatplans WHERE userId IN (:ids))",params,{datasource=variables.datasource});
    queryExecute("DELETE FROM route_instance_leg_progress WHERE user_id IN (:ids)",params,{datasource=variables.datasource});
    queryExecute("DELETE FROM floatplans WHERE userId IN (:ids)",params,{datasource=variables.datasource});
    queryExecute("DELETE l FROM user_route_legs l JOIN user_routes r ON r.id=l.user_route_id WHERE r.user_id IN (:ids)",params,{datasource=variables.datasource});
    queryExecute("DELETE FROM user_routes WHERE user_id IN (:ids)",params,{datasource=variables.datasource});
    queryExecute("DELETE FROM route_instances WHERE user_id IN (:ids)",params,{datasource=variables.datasource});
    queryExecute("DELETE FROM loop_routes WHERE description=:marker",
      {marker={value=variables.fixturePrefix,cfsqltype="cf_sql_varchar"}}, {datasource=variables.datasource});
    queryExecute("DELETE FROM vessels WHERE userId IN (:ids)",params,{datasource=variables.datasource});
    queryExecute("DELETE FROM member_entitlements WHERE user_id IN (:ids)",params,{datasource=variables.datasource});
    queryExecute("DELETE FROM users WHERE userId IN (:ids)",params,{datasource=variables.datasource});
  }
}
