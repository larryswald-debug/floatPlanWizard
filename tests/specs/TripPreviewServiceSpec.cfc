component extends="testbox.system.BaseSpec" output=false {
  variables.datasource="fpw";

  function run() {
    describe("Owner trip preview read-only contract",function() {
      it("provides an isolated normal scheduled Active renderer fixture without sending or starting",function() {
        transaction {
          try {
            var f=createFixture(false,true);
            var before=fixtureSnapshot(f);
            var active=new fpw.api.v1.ActiveCruiseViewModelService().init("fpw").getActiveCruiseViewModel(f.ownerId,f.floatPlanId);
            expect(active.success).toBeTrue(active.message);
            expect(active.tripState).toBe("scheduled");
            expect(active.actions.checkIn.enabled).toBeTrue();
            expect(active.actions.pace.updatePace.enabled).toBeTrue();
            expect(active.routeTimeline.authority).toBe("scheduled_projection");
            expect(preview().getContext(f.ownerId,f.floatPlanId).reasonCode).toBe("PREVIEW_REQUIRES_DRAFT");
            var stream=q("SELECT privacy_mode,allow_interactions,share_token FROM voyage_streams WHERE id=:s",{s=num(f.streamId)});
            expect(stream.privacy_mode[1]).toBe("invite");
            expect(val(stream.allow_interactions[1])).toBe(0);
            expect(stream.share_token[1]).toBe(f.followToken);
            expect(before.operational.floatplans_tosend.count).toBe(0);
            expect(before.operational.floatplan_alert_history.count).toBe(0);
            expect(before.operational.floatplan_events.count).toBe(0);
            expect(before.generatedFiles).toBeEmpty();
            expect(serializeJSON(fixtureSnapshot(f).operational)).toBe(serializeJSON(before.operational));
          } finally { transaction action="rollback"; }
        }
      });
      it("accepts a free member's clean route Draft with optional details absent",function() {
        withFixture(function(f) {
          var context=preview().getContext(f.ownerId,f.floatPlanId);
          expect(context.eligible).toBeTrue();
          expect(context.reasonCode).toBe("PREVIEW_READY");
          expect(context.routeInstanceId).toBe(f.routeInstanceId);
          expect(q("SELECT COUNT(*) n FROM member_entitlements WHERE user_id=:u",{u=num(f.ownerId)}).n[1]).toBe(0);
          expect(q("SELECT COUNT(*) n FROM premium_send_credits WHERE user_id=:u AND status='AVAILABLE'",{u=num(f.ownerId)}).n[1]).toBe(0);
        });
      });
      it("rejects noncanonical identifiers and another member without returning their route",function() {
        withFixture(function(f) {
          for(var id in ["0","-1","01","1.0","1e2","2147483648","1,2","abc"," 1","1 ","1"&chr(10),"1"&chr(9),"1"&chr(13),{},[]]) {
            expect(preview().getContext(f.ownerId,id).reasonCode).toBe("INVALID_FLOAT_PLAN_ID");
          }
          expect(preview().getContext(0,f.floatPlanId).reasonCode).toBe("AUTH_REQUIRED");
          var foreign=preview().getContext(f.otherId,f.floatPlanId);
          expect(foreign.eligible).toBeFalse();
          expect(foreign.reasonCode).toBe("PREVIEW_NOT_FOUND");
          expect(foreign.routeInstanceId).toBe(0);
          expect(preview().getContext(f.ownerId,2147483647).reasonCode).toBe("PREVIEW_NOT_FOUND");
        });
      });
      it("requires a Draft, an owned vessel, a saved owned route and ordered meaningful endpoints",function() {
        withFixture(function(f) {
          for(var state in ["ACTIVE","CLOSED","CANCELLED"]) {
            q("UPDATE floatplans SET status=:s WHERE floatPlanId=:p",{s=txt(state),p=num(f.floatPlanId)});
            expect(preview().getContext(f.ownerId,f.floatPlanId).reasonCode).toBe("PREVIEW_REQUIRES_DRAFT");
          }
          q("UPDATE floatplans SET status='DRAFT',vesselId=NULL WHERE floatPlanId=:p",{p=num(f.floatPlanId)});
          expect(preview().getContext(f.ownerId,f.floatPlanId).reasonCode).toBe("PREVIEW_VESSEL_REQUIRED");
          q("UPDATE floatplans SET vesselId=:v WHERE floatPlanId=:p",{v=num(f.vesselId),p=num(f.floatPlanId)});
          q("UPDATE route_instances SET user_id=:u WHERE id=:r",{u=txt(f.otherId),r=num(f.routeInstanceId)});
          expect(preview().getContext(f.ownerId,f.floatPlanId).reasonCode).toBe("PREVIEW_ROUTE_REQUIRED");
          q("UPDATE route_instances SET user_id=:u WHERE id=:r",{u=txt(f.ownerId),r=num(f.routeInstanceId)});
          q("UPDATE route_instance_legs SET start_name='Unknown Start' WHERE route_instance_id=:r AND leg_order=1",{r=num(f.routeInstanceId)});
          expect(preview().getContext(f.ownerId,f.floatPlanId).reasonCode).toBe("PREVIEW_ENDPOINTS_REQUIRED");
          q("DELETE FROM route_instance_leg_progress WHERE route_instance_id=:r",{r=num(f.routeInstanceId)});
          q("DELETE FROM route_instance_legs WHERE route_instance_id=:r",{r=num(f.routeInstanceId)});
          expect(preview().getContext(f.ownerId,f.floatPlanId).reasonCode).toBe("PREVIEW_LEGS_REQUIRED");
        });
      });
      it("rejects foreign optional resources without requiring absent selections",function() {
        withFixture(function(f) {
          q("UPDATE floatplans SET operatorId=:o WHERE floatPlanId=:p",{o=num(f.otherOperatorId),p=num(f.floatPlanId)});
          expect(preview().getContext(f.ownerId,f.floatPlanId).reasonCode).toBe("PREVIEW_RESOURCE_OWNERSHIP_INVALID");
          q("UPDATE floatplans SET operatorId=NULL WHERE floatPlanId=:p",{p=num(f.floatPlanId)});
          q("INSERT INTO floatplan_contacts(floatPlanId,contactId) VALUES(:p,:c)",{p=num(f.floatPlanId),c=num(f.otherContactId)});
          expect(preview().getContext(f.ownerId,f.floatPlanId).reasonCode).toBe("PREVIEW_RESOURCE_OWNERSHIP_INVALID");
          q("DELETE FROM floatplan_contacts WHERE floatPlanId=:p",{p=num(f.floatPlanId)});
          q("INSERT INTO floatplan_passengers(floatPlanId,passId,hasPdf) VALUES(:p,:s,0)",{p=num(f.floatPlanId),s=num(f.otherPassengerId)});
          expect(preview().getContext(f.ownerId,f.floatPlanId).reasonCode).toBe("PREVIEW_RESOURCE_OWNERSHIP_INVALID");
        });
      });
      it("rejects operational timestamps, delays and route progress",function() {
        withFixture(function(f) {
          for(var field in ["activatedAt","initialSentAt","checkedInAt","closedAt","overdueNotifiedAt","lastMonitoredAt","monitorLockUntil"]) {
            q("UPDATE floatplans SET "&field&"=UTC_TIMESTAMP() WHERE floatPlanId=:p",{p=num(f.floatPlanId)});
            expect(preview().getContext(f.ownerId,f.floatPlanId).reasonCode).toBe("PREVIEW_OPERATIONAL_HISTORY");
            q("UPDATE floatplans SET "&field&"=NULL WHERE floatPlanId=:p",{p=num(f.floatPlanId)});
          }
          q("UPDATE floatplans SET manual_delay_minutes_total=5 WHERE floatPlanId=:p",{p=num(f.floatPlanId)});
          expect(preview().getContext(f.ownerId,f.floatPlanId).reasonCode).toBe("PREVIEW_OPERATIONAL_HISTORY");
          q("UPDATE floatplans SET manual_delay_minutes_total=0 WHERE floatPlanId=:p",{p=num(f.floatPlanId)});
          q("UPDATE route_instance_leg_progress SET status='COMPLETED',completed_at=UTC_TIMESTAMP() WHERE route_instance_id=:r AND leg_order=1",{r=num(f.routeInstanceId)});
          expect(preview().getContext(f.ownerId,f.floatPlanId).reasonCode).toBe("PREVIEW_OPERATIONAL_HISTORY");
        });
      });
      it("rejects monitoring, event and prior-plan history",function() {
        withFixture(function(f) {
          q("INSERT INTO floatplan_monitoring(float_plan_id,user_id,is_monitoring_enabled) VALUES(:p,:u,0)",{p=num(f.floatPlanId),u=num(f.ownerId)});
          expect(preview().getContext(f.ownerId,f.floatPlanId).reasonCode).toBe("PREVIEW_OPERATIONAL_HISTORY");
          q("DELETE FROM floatplan_monitoring WHERE float_plan_id=:p",{p=num(f.floatPlanId)});
          q("INSERT INTO floatplan_events(floatplan_id,user_id,route_instance_id,event_type,occurred_at_utc,source) VALUES(:p,:u,:r,'CHECK_IN',UTC_TIMESTAMP(),'manual')",
            {p=num(f.floatPlanId),u=num(f.ownerId),r=num(f.routeInstanceId)});
          expect(preview().getContext(f.ownerId,f.floatPlanId).reasonCode).toBe("PREVIEW_OPERATIONAL_HISTORY");
          q("DELETE FROM floatplan_events WHERE floatplan_id=:p",{p=num(f.floatPlanId)});
          q("UPDATE floatplans SET route_instance_id=:r WHERE floatPlanId=:p",{r=num(f.routeInstanceId),p=num(f.dueFloatPlanId)});
          expect(preview().getContext(f.ownerId,f.floatPlanId).reasonCode).toBe("PREVIEW_OPERATIONAL_HISTORY");
        });
      });
      it("rejects saved stream, captain log, companion, alert and isolated monitor-event history",function() {
        withFixture(function(f) {
          var params={p=num(f.floatPlanId),u=num(f.ownerId),r=num(f.routeInstanceId),token=txt(f.fixture)};
          var entries=[
            {sql="INSERT INTO voyage_streams(floatplan_id,owner_user_id,slug,share_token) VALUES(:p,:u,:token,:token)",table="voyage_streams",column="floatplan_id"},
            {sql="INSERT INTO floatplan_captain_log_entries(floatplan_id,user_id,route_instance_id,note_body) VALUES(:p,:u,:r,'Previous captain note')",table="floatplan_captain_log_entries",column="floatplan_id"},
            {sql="INSERT INTO floatplan_companion_events(mobile_submission_id,floatplan_id,user_id,route_instance_id,event_type,canonical_status) VALUES(:token,:p,:u,:r,'CHECK_IN','Underway')",table="floatplan_companion_events",column="floatplan_id"},
            {sql="INSERT INTO floatplan_alert_history(floatPlanId,alertType,status) VALUES(:p,'OVERDUE','SENT')",table="floatplan_alert_history",column="floatPlanId"}
          ];
          for(var entry in entries) {
            expect(preview().getContext(f.ownerId,f.floatPlanId).eligible).toBeTrue();
            q(entry.sql,params);
            expect(preview().getContext(f.ownerId,f.floatPlanId).reasonCode).toBe("PREVIEW_OPERATIONAL_HISTORY");
            q("DELETE FROM "&entry.table&" WHERE "&entry.column&"=:p",params);
          }
          // Isolate event-history admission from the separately checked monitoring record.
          params.monitor=num(q("SELECT id FROM floatplan_monitoring WHERE float_plan_id=:p",{p=num(f.dueFloatPlanId)}).id[1]);
          q("INSERT INTO floatplan_monitor_events(monitoring_id,float_plan_id,user_id,event_type) VALUES(:monitor,:p,:u,'MONITORING_STARTED')",params);
          expect(preview().getContext(f.ownerId,f.floatPlanId).reasonCode).toBe("PREVIEW_OPERATIONAL_HISTORY");
          q("DELETE FROM floatplan_monitor_events WHERE float_plan_id=:p",params);
          expect(preview().getContext(f.ownerId,f.floatPlanId).eligible).toBeTrue();
          q("INSERT INTO premium_send_credits(user_id,source,status,consumed_float_plan_id,idempotency_key,granted_at_utc,consumed_at_utc,created_at_utc,updated_at_utc)
             VALUES(:u,'complimentary_signup','CONSUMED',:p,:token,UTC_TIMESTAMP(6),UTC_TIMESTAMP(6),UTC_TIMESTAMP(6),UTC_TIMESTAMP(6))",params);
          expect(preview().getContext(f.ownerId,f.floatPlanId).reasonCode).toBe("PREVIEW_OPERATIONAL_HISTORY");
          q("INSERT INTO premium_send_receipts(user_id,float_plan_id,credit_id,access_source,access_started_at_utc,access_expires_at_utc,recipient_count,original_response_json,committed_at_utc,created_at_utc)
             SELECT user_id,consumed_float_plan_id,id,'premium_send_credit',consumed_at_utc,DATE_ADD(consumed_at_utc,INTERVAL 21 DAY),1,'{""SUCCESS"":true}',consumed_at_utc,consumed_at_utc
             FROM premium_send_credits WHERE idempotency_key=:token",params);
          expect(preview().getContext(f.ownerId,f.floatPlanId).reasonCode).toBe("PREVIEW_OPERATIONAL_HISTORY");
        });
      });
      it("builds real planned Active and Follow models without mutating any fixture state",function() {
        withFixture(function(f) {
          var before=fixtureSnapshot(f);
          var active=new fpw.api.v1.ActiveCruiseViewModelService().init("fpw").getPreviewViewModel(f.ownerId,f.floatPlanId);
          expect(active.success).toBeTrue();
          expect(active.mode).toBe("preview");
          expect(active.floatPlan.id).toBe(f.floatPlanId);
          expect(active.routeTimeline.authority).toBe("planned_preview");
          expect(arrayLen(active.routeTimeline.legs)).toBe(2);
          expect(active.monitoring.isEnabled).toBeFalse();
          expect(active.floatPlan.scheduledDepartureAtUtc).toBe("");
          expect(active.currentLeg.etaUtc).toBe("");
          expect(active.routeTimeline.summary.finalArrivalUtc).toBe("");
          expect(active.pace.effectiveSpeedKn).toBe(0);
          for(var leg in active.routeTimeline.legs) {
            expect(leg.departureUtc).toBe("");
            expect(leg.arrivalUtc).toBe("");
            expect(leg.etaUtc).toBe("");
            expect(leg.estimatedDurationLabel).toBe("");
            expect(leg.remainingDurationLabel).toBe("");
          }
          expect(active.weather.lookup.available).toBeFalse();
          expect(active.weather.lookup.endpoint).toBe("");
          expect(active.weather.apply.available).toBeFalse();
          assertNoEnabledActions(active.actions);
          var follow=new fpw.api.v1.voyage().getOwnerPreviewViewModel(preview().getContext(f.ownerId,f.floatPlanId),active);
          expect(follow.SUCCESS).toBeTrue();
          expect(follow.view_mode).toBe("owner_preview");
          var text=lcase(serializeJSON(follow));
          for(var key in ['"share_token"','"access_token"','"slug"','"followers"','"owner_user_id"'])
            expect(find(key,text)).toBe(0);
          expect(serializeJSON(fixtureSnapshot(f))).toBe(serializeJSON(before));
          expect(q("SELECT status FROM floatplans WHERE floatPlanId=:p",{p=num(f.dueFloatPlanId)}).status[1]).toBe("ACTIVE");
        });
      });
      it("uses saved departure and speed for planned timing while keeping operational state off",function() {
        withFixture(function(f) {
          q("UPDATE floatplans SET departureTimeUTC='2026-10-07 12:00:00',operatorId=:o WHERE floatPlanId=:p",{o=num(f.ownerOperatorId),p=num(f.floatPlanId)});
          q("INSERT INTO floatplan_contacts(floatPlanId,contactId) VALUES(:p,:c)",{p=num(f.floatPlanId),c=num(f.ownerContactId)});
          q("UPDATE route_instances SET routegen_inputs_json=:j WHERE id=:r",{j=txt(serializeJSON({effective_speed_kn=10,pace="BALANCED"})),r=num(f.routeInstanceId)});
          var before=fixtureSnapshot(f);
          var model=new fpw.api.v1.ActiveCruiseViewModelService().init("fpw").getPreviewViewModel(f.ownerId,f.floatPlanId);
          expect(model.success).toBeTrue();
          expect(model.routeTimeline.authority).toBe("planned_preview");
          expect(find("2026-10-07",model.routeTimeline.legs[1].departureUtc)).toBeGT(0);
          expect(model.routeTimeline.legs[1].estimatedDurationSeconds).toBe(1800);
          expect(model.routeTimeline.legs[2].estimatedDurationSeconds).toBe(2520);
          expect(model.routeTimeline.legs[2].departureUtc).toBe(model.routeTimeline.legs[1].arrivalUtc);
          expect(model.routeTimeline.summary.finalArrivalUtc).toBe(model.routeTimeline.legs[2].arrivalUtc);
          expect(len(model.routeTimeline.summary.finalArrivalUtc)).toBeGT(0);
          expect(arrayLen(model.contacts.items)).toBe(1);
          expect(model.monitoring.isEnabled).toBeFalse();
          expect(model.map.currentPosition.available).toBeFalse();
          expect(model.route.streamId).toBe(0);
          assertNoEnabledActions(model.actions);
          expect(serializeJSON(fixtureSnapshot(f))).toBe(serializeJSON(before));
        });
      });
      it("exposes preview readiness on the canonical saved-route dashboard response",function() {
        withFixture(function(f) {
          var builder=new fpw.api.v1.routeBuilder();
          makePublic(builder,"listUserRoutes","previewRoutesForTest");
          var listed=builder.previewRoutesForTest(f.ownerId);
          expect(listed.SUCCESS).toBeTrue();
          expect(arrayLen(listed.ROUTES)).toBe(1);
          expect(listed.ROUTES[1].SHORT_CODE).toBe(f.routeCode);
          expect(listed.ROUTES[1].HAS_CURRENT_GROUP).toBeTrue();
          expect(listed.ROUTES[1].CURRENT_GROUP.FLOATPLAN_ID).toBe(f.floatPlanId);
          expect(listed.ROUTES[1].CURRENT_GROUP.PREVIEW_READY).toBeTrue();
        },false);
      });
      it("rejects missing foreign and Draft operational targets with exact gate envelopes",function() {
        withFixture(function(f) {
          var before=fixtureSnapshot(f);
          var gate=new fpw.api.v1.MemberAccessGateService().init("fpw");
          var cases=[
            {userId=f.ownerId,planId=f.floatPlanId,code="TRIP_ACCESS_RECORD_MISSING",message="Premium access for this float plan is unavailable."},
            {userId=f.ownerId,planId=2147483647,code="TRIP_ACCESS_RECORD_MISSING",message="This float plan access record is unavailable."},
            {userId=f.otherId,planId=f.floatPlanId,code="TRIP_ACCESS_BINDING_INVALID",message="This float plan access record is invalid."}
          ];
          for(var item in cases) {
            var result=gate.requireTripOperationalAccess(item.userId,item.planId);
            assertDenial(result,item.code,item.message);
            var updated=gate.requireTripOperationalAccessForUpdate(item.userId,item.planId);
            assertDenial(updated,"TRIP_ACCESS_RECORD_MISSING","Premium access for this float plan is unavailable.");
          }
          expect(gate.requireTripOperationalAccess(0,f.floatPlanId).response.errorCode).toBe("AUTH_REQUIRED");
          expect(gate.requireTripOperationalAccess(f.ownerId,0).response.errorCode).toBe("FLOAT_PLAN_REQUIRED");
          assertDenial(gate.requireTripOperationalAccessForUpdate(f.ownerId,0),"TRIP_ACCESS_RECORD_MISSING","Premium access for this float plan is unavailable.");
          expect(serializeJSON(fixtureSnapshot(f))).toBe(serializeJSON(before));
        });
      });
      it("preserves receipt-backed Draft and mismatched owner denials without expiration",function() {
        withFixture(function(f) {
          q("UPDATE floatplans SET status='DRAFT' WHERE floatPlanId=:p",{p=num(f.dueFloatPlanId)});
          expect(preview().getContext(f.ownerId,f.dueFloatPlanId).reasonCode).toBe("PREVIEW_OPERATIONAL_HISTORY");
          var before=fixtureSnapshot(f);
          var gate=new fpw.api.v1.MemberAccessGateService().init("fpw");
          assertDenial(gate.requireTripOperationalAccess(f.ownerId,f.dueFloatPlanId),"TRIP_NOT_ACTIVE","This float plan is not active.");
          assertDenial(gate.requireTripOperationalAccessForUpdate(f.ownerId,f.dueFloatPlanId),"TRIP_NOT_ACTIVE","This float plan is not active.");
          expect(serializeJSON(fixtureSnapshot(f))).toBe(serializeJSON(before));
          q("UPDATE floatplans SET userId=:u WHERE floatPlanId=:p",{u=txt(f.otherId),p=num(f.dueFloatPlanId)});
          before=fixtureSnapshot(f);
          assertDenial(gate.requireTripOperationalAccess(f.ownerId,f.dueFloatPlanId),"TRIP_ACCESS_BINDING_INVALID","This float plan access record is invalid.");
          assertDenial(gate.requireTripOperationalAccessForUpdate(f.ownerId,f.dueFloatPlanId),"TRIP_ACCESS_BINDING_INVALID","This float plan access record is invalid.");
          expect(serializeJSON(fixtureSnapshot(f))).toBe(serializeJSON(before));
        });
      });
      it("lets existing owned ACTIVE and terminal targets continue to their existing gate",function() {
        withFixture(function(f) {
          var gate=new fpw.api.v1.MemberAccessGateService().init("fpw");
          for(var state in ["ACTIVE","CLOSED","CANCELLED"]) {
            q("UPDATE floatplans SET status=:s WHERE floatPlanId=:p",{s=txt(state),p=num(f.floatPlanId)});
            expect(gate.preflightOperationalTarget(f.ownerId,f.floatPlanId).rejected).toBeFalse();
            expect(gate.preflightOperationalTarget(f.ownerId,f.floatPlanId,true).rejected).toBeFalse();
          }
          q("UPDATE floatplans SET status='EXPIRED',expiredAt=UTC_TIMESTAMP(6),end_reason='SINGLE_TRIP_LIMIT' WHERE floatPlanId=:p",{p=num(f.floatPlanId)});
          expect(gate.preflightOperationalTarget(f.ownerId,f.floatPlanId).rejected).toBeFalse();
          expect(gate.preflightOperationalTarget(f.ownerId,f.floatPlanId,true).rejected).toBeFalse();
        });
      });
      it("weather rejects a Draft before canonical normalization or external lookup",function() {
        withFixture(function(f) {
          var before=fixtureSnapshot(f);
          var voyage=new fpw.api.v1.voyage();
          makePublic(voyage,"getActiveCruiseWeatherCanonical","previewWeatherForTest");
          var result=voyage.previewWeatherForTest(f.ownerId,f.floatPlanId,"start");
          expect(result.SUCCESS).toBeFalse();
          expect(result.errorCode).toBe("TRIP_ACCESS_RECORD_MISSING");
          expect(serializeJSON(fixtureSnapshot(f))).toBe(serializeJSON(before));
        });
      });
      it("marks preview lifecycle hooks and analytics suppression without changing normal callbacks",function() {
        var base=getDirectoryFromPath(getCurrentTemplatePath()) & "../../";
        var app=fileRead(base & "Application.cfc");
        var ga=fileRead(base & "includes/analytics_ga4.cfm");
        var clarity=fileRead(base & "includes/analytics_clarity.cfm");
        expect(find('request.fpwTripPreview',app)).toBeGT(0);
        expect(find('name="onAbort"',app)).toBeGT(0);
        expect(find('getPageContext().getResponse()',app)).toBeGT(0);
        expect(find('window.FPWAnalytics.track = function() {};',ga)).toBeGT(0);
        expect(find('NOT fpwGaIsTripPreview AND NOT structKeyExists(request, "fpwPlausibleTagRendered")',ga)).toBeGT(0);
        expect(find('NOT fpwGaIsTripPreview AND fpwGaIsProductionHost',ga)).toBeGT(0);
        expect(find('request.fpwTripPreview',clarity)).toBeGT(0);
      });
    });
  }

  private void function withFixture(required any assertion,boolean withDueTrip=true) {
    transaction {
      try {
        var f=createFixture(arguments.withDueTrip);
        arguments.assertion(f);
      } finally { transaction action="rollback"; }
    }
  }
  private any function preview() { return new fpw.api.v1.TripPreviewService().init("fpw"); }
  private any function q(required string sql,struct params={}) {
    return queryExecute(arguments.sql,arguments.params,{datasource=variables.datasource});
  }
  private struct function num(required numeric value) {return {value=arguments.value,cfsqltype="cf_sql_integer"};}
  private struct function txt(required any value) {return {value=toString(arguments.value),cfsqltype="cf_sql_varchar"};}
  private void function assertDenial(required struct gate,required string code,required string message) {
    expect(arguments.gate.allowed).toBeFalse();
    expect(arguments.gate.response.SUCCESS).toBeFalse();
    expect(arguments.gate.response.success).toBeFalse();
    expect(arguments.gate.response.AUTH).toBeTrue();
    expect(arguments.gate.response.STATUS_CODE).toBe(403);
    expect(arguments.gate.response.errorCode).toBe(arguments.code);
    expect(arguments.gate.response.ERROR.CODE).toBe(arguments.code);
    expect(arguments.gate.response.MESSAGE).toBe(arguments.message);
    expect(arguments.gate.response.tripAccess.allowed).toBeFalse();
  }
  private void function assertNoEnabledActions(required struct actions) {
    for(var key in arguments.actions) if(isStruct(arguments.actions[key])) {
      var action=arguments.actions[key];
      if(structKeyExists(action,"enabled")) expect(action.enabled).toBeFalse();
      if(structKeyExists(action,"endpoint")) expect(action.endpoint).toBe("");
    }
  }

  // Shared only by the gated local runner; public is intentionally nonremote.
  public struct function createFixture(boolean withDueTrip=false,boolean activeScheduled=false) {
    if(arguments.withDueTrip AND arguments.activeScheduled)
      throw(type="FPW.PreviewFixture.Mode",message="Scheduled Active fixtures cannot include an unrelated due trip.");
    var token=lcase(replace(createUUID(),"-","","all"));
    var f={"fixture"=token,"marker"="codex-trip-preview-"&token,"ownerId"=0,"otherId"=0,
      "floatPlanId"=0,"routeInstanceId"=0,"dueFloatPlanId"=0,"routeCode"=""};
    for(var member in ["owner","other"]) {
      var email=f.marker&"-"&member&"@example.test";
      q("INSERT INTO users(fName,lName,email,password,passwordCreated,created,welcomeOnboardingSeenAt,gettingStartedHidden)
         VALUES('Preview',:name,:email,:password,UTC_TIMESTAMP(),UTC_TIMESTAMP(),UTC_TIMESTAMP(),1)",
        {name=txt(member),email=txt(email),password=txt(hash(token&member,"SHA-256"))});
      var id=val(q("SELECT userId FROM users WHERE email=:e",{e=txt(email)}).userId[1]);
      f[member&"Id"]=id; f[member&"Email"]=email;
      q("INSERT INTO operators(userId,name) VALUES(:u,'Preview Operator')",{u=txt(id)});
      f[member&"OperatorId"]=val(q("SELECT opId FROM operators WHERE userId=:u ORDER BY opId DESC LIMIT 1",{u=txt(id)}).opId[1]);
      q("INSERT INTO contacts(userId,name,phone,email) VALUES(:u,'Preview Contact','2025550100',:e)",{u=txt(id),e=txt(email)});
      f[member&"ContactId"]=val(q("SELECT contactId FROM contacts WHERE userId=:u ORDER BY contactId DESC LIMIT 1",{u=txt(id)}).contactId[1]);
      q("INSERT INTO passengers(userId,name,phone) VALUES(:u,'Preview Passenger','2025550101')",{u=txt(id)});
      f[member&"PassengerId"]=val(q("SELECT passId FROM passengers WHERE userId=:u ORDER BY passId DESC LIMIT 1",{u=txt(id)}).passId[1]);
    }
    q("INSERT INTO vessels(userId,vesselName,hailingPort,timezone) VALUES(:u,'Preview Vessel','Test Harbor','America/New_York')",{u=txt(f.ownerId)});
    f.vesselId=val(q("SELECT vesselID FROM vessels WHERE userId=:u ORDER BY vesselID DESC LIMIT 1",{u=txt(f.ownerId)}).vesselID[1]);
    for(var waypoint in [{name="Preview Harbor",lat="27.760000",lng="-82.640000"},{name="Preview Cove",lat="27.820000",lng="-82.680000"}])
      q("INSERT INTO waypoints(userId,name,latitude,longitude) VALUES(:u,:n,:lat,:lng)",{u=txt(f.ownerId),n=txt(waypoint.name),lat=txt(waypoint.lat),lng=txt(waypoint.lng)});
    f.routeCode="USER_ROUTE_"&f.ownerId&"_"&left(token,12);
    q("INSERT INTO loop_routes(code,name,short_code,description,is_active,total_nm,total_locks)
       VALUES(:c,'Preview Test Route',:c,:d,1,12,1)",{c=txt(f.routeCode),d=txt(f.marker)});
    f.generatedRouteId=val(q("SELECT id FROM loop_routes WHERE code=:c",{c=txt(f.routeCode)}).id[1]);
    var routeInputs=serializeJSON({startName="Preview Harbor",endName="Preview Cove",startLat=27.76,startLng=-82.64,endLat=27.82,endLng=-82.68});
    q("INSERT INTO route_instances(user_id,template_route_code,generated_route_id,generated_route_code,direction,trip_type,start_location,end_location,routegen_inputs_json,status)
       VALUES(:u,'GREAT_LOOP_CCW',:r,:c,'CCW','POINT_TO_POINT','Preview Harbor','Preview Cove',:inputs,'PLANNED')",
      {u=txt(f.ownerId),r=num(f.generatedRouteId),c=txt(f.routeCode),inputs=txt(routeInputs)});
    f.routeInstanceId=val(q("SELECT id FROM route_instances WHERE user_id=:u AND generated_route_code=:c",{u=txt(f.ownerId),c=txt(f.routeCode)}).id[1]);
    q("INSERT INTO route_instance_legs(route_instance_id,leg_order,start_name,end_name,start_lat,start_lng,end_lat,end_lng,base_dist_nm,lock_count)
       VALUES(:r,1,'Preview Harbor','Preview Lock',27.76,-82.64,27.79,-82.66,5,1),
             (:r,2,'Preview Lock','Preview Cove',27.79,-82.66,27.82,-82.68,7,0)",{r=num(f.routeInstanceId)});
    q("INSERT INTO route_instance_leg_progress(user_id,route_instance_id,leg_order,status) VALUES(:u,:r,1,'NOT_STARTED'),(:u,:r,2,'NOT_STARTED')",
      {u=num(f.ownerId),r=num(f.routeInstanceId)});
    q("INSERT INTO floatplans(userId,floatPlanName,vesselId,dateCreated,lastUpdate,status,lastUpdateStatus,route_instance_id,route_day_number,departing,returning)
       VALUES(:u,:n,:v,UTC_TIMESTAMP(),UTC_TIMESTAMP(),'DRAFT',UTC_TIMESTAMP(),:r,1,'Preview Harbor','Preview Cove')",
      {u=txt(f.ownerId),n=txt("Preview "&left(token,8)),v=num(f.vesselId),r=num(f.routeInstanceId)});
    f["floatPlanName"]="Preview "&left(token,8);
    f.floatPlanId=val(q("SELECT floatPlanId FROM floatplans WHERE userId=:u ORDER BY floatPlanId DESC LIMIT 1",{u=txt(f.ownerId)}).floatPlanId[1]);
    f["activeScheduled"]=arguments.activeScheduled;
    if(arguments.activeScheduled) {
      // Renderer regression only: create isolated state directly; never invoke signup, send, activation or mail.
      var activeInputs=deserializeJSON(routeInputs);
      activeInputs.effective_speed_kn=10;
      activeInputs.pace="BALANCED";
      q("UPDATE route_instances SET routegen_inputs_json=:inputs WHERE id=:r",
        {inputs=txt(serializeJSON(activeInputs)),r=num(f.routeInstanceId)});
      q("UPDATE floatplans SET status='ACTIVE',activatedAt=UTC_TIMESTAMP(),initialSentAt=UTC_TIMESTAMP(),
           operatorId=:o,departureTime=DATE_ADD(UTC_TIMESTAMP(),INTERVAL 36 HOUR),
           departureTimeUTC=DATE_ADD(UTC_TIMESTAMP(),INTERVAL 36 HOUR),departTimezone='UTC',departureTZ='UTC',
           returnTime=DATE_ADD(UTC_TIMESTAMP(),INTERVAL 3 DAY),returnTimeUTC=DATE_ADD(UTC_TIMESTAMP(),INTERVAL 3 DAY),
           returnTimezone='UTC',returnTZ='UTC',dailyStartLocalTime='08:00:00'
         WHERE floatPlanId=:p",{o=num(f.ownerOperatorId),p=num(f.floatPlanId)});
      q("INSERT INTO floatplan_contacts(floatPlanId,contactId) VALUES(:p,:c)",
        {p=num(f.floatPlanId),c=num(f.ownerContactId)});
      q("INSERT INTO premium_send_credits(user_id,source,status,consumed_float_plan_id,idempotency_key,granted_at_utc,consumed_at_utc,created_at_utc,updated_at_utc)
         VALUES(:u,'complimentary_signup','CONSUMED',:p,:key,UTC_TIMESTAMP(6),UTC_TIMESTAMP(6),UTC_TIMESTAMP(6),UTC_TIMESTAMP(6))",
        {u=num(f.ownerId),p=num(f.floatPlanId),key=txt(f.marker&"-active")});
      q("INSERT INTO premium_send_receipts(user_id,float_plan_id,credit_id,access_source,access_started_at_utc,access_expires_at_utc,recipient_count,original_response_json,committed_at_utc,created_at_utc)
         SELECT user_id,consumed_float_plan_id,id,'premium_send_credit',consumed_at_utc,DATE_ADD(consumed_at_utc,INTERVAL 21 DAY),1,'{""SUCCESS"":true}',consumed_at_utc,consumed_at_utc
         FROM premium_send_credits WHERE idempotency_key=:key",{key=txt(f.marker&"-active")});
      q("INSERT INTO floatplan_monitoring(float_plan_id,user_id,monitoring_mode,is_monitoring_enabled) VALUES(:p,:u,'active_route',0)",
        {p=num(f.floatPlanId),u=num(f.ownerId)});
      f["followSlug"]="trip-"&token;
      f["followToken"]=token&token;
      q("INSERT INTO voyage_streams(floatplan_id,owner_user_id,slug,share_token,privacy_mode,allow_interactions,created_utc,updated_utc)
         VALUES(:p,:u,:slug,:token,'invite',0,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
        {p=num(f.floatPlanId),u=num(f.ownerId),slug=txt(f.followSlug),token=txt(f.followToken)});
      f["streamId"]=val(q("SELECT id FROM voyage_streams WHERE owner_user_id=:u AND slug=:slug",
        {u=num(f.ownerId),slug=txt(f.followSlug)}).id[1]);
      f["followPath"]="/app/follow.cfm?slug="&urlEncodedFormat(f.followSlug)&"&t="&urlEncodedFormat(f.followToken);
    }
    if(arguments.withDueTrip) {
      q("INSERT INTO floatplans(userId,floatPlanName,vesselId,dateCreated,lastUpdate,status,lastUpdateStatus,activatedAt,initialSentAt)
         VALUES(:u,:n,:v,UTC_TIMESTAMP(),UTC_TIMESTAMP(),'ACTIVE',UTC_TIMESTAMP(),DATE_SUB(UTC_TIMESTAMP(),INTERVAL 22 DAY),DATE_SUB(UTC_TIMESTAMP(),INTERVAL 22 DAY))",
        {u=txt(f.ownerId),n=txt(f.marker&"-due"),v=num(f.vesselId)});
      f.dueFloatPlanId=val(q("SELECT floatPlanId FROM floatplans WHERE userId=:u ORDER BY floatPlanId DESC LIMIT 1",{u=txt(f.ownerId)}).floatPlanId[1]);
      q("INSERT INTO premium_send_credits(user_id,source,status,consumed_float_plan_id,idempotency_key,granted_at_utc,consumed_at_utc,created_at_utc,updated_at_utc)
         VALUES(:u,'complimentary_signup','CONSUMED',:p,:key,DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 23 DAY),DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 22 DAY),UTC_TIMESTAMP(6),UTC_TIMESTAMP(6))",
        {u=num(f.ownerId),p=num(f.dueFloatPlanId),key=txt(f.marker)});
      q("INSERT INTO premium_send_receipts(user_id,float_plan_id,credit_id,access_source,access_started_at_utc,access_expires_at_utc,recipient_count,original_response_json,committed_at_utc,created_at_utc)
         SELECT user_id,consumed_float_plan_id,id,'premium_send_credit',consumed_at_utc,DATE_ADD(consumed_at_utc,INTERVAL 21 DAY),1,'{""SUCCESS"":true}',consumed_at_utc,consumed_at_utc
         FROM premium_send_credits WHERE idempotency_key=:key",{key=txt(f.marker)});
      q("INSERT INTO floatplan_monitoring(float_plan_id,user_id,monitoring_mode,is_monitoring_enabled) VALUES(:p,:u,'active_route',0)",
        {p=num(f.dueFloatPlanId),u=num(f.ownerId)});
    }
    return f;
  }

  public struct function fixtureSnapshot(required struct fixture) {
    var f=arguments.fixture;
    var params={owner=num(f.ownerId),other=num(f.otherId),ownerText=txt(f.ownerId),otherText=txt(f.otherId),route=num(f.routeInstanceId),generated=num(f.generatedRouteId)};
    var ownedUsers=" IN (:owner,:other)";
    var plans=" IN (SELECT floatPlanId FROM floatplans WHERE userId IN (:ownerText,:otherText))";
    var streams=" IN (SELECT id FROM voyage_streams WHERE owner_user_id IN (:owner,:other))";
    var specs=[
      {table="users",where="userId"&ownedUsers},{table="vessels",where="userId IN (:ownerText,:otherText)"},
      {table="floatplans",where="userId IN (:ownerText,:otherText)"},{table="route_instances",where="user_id IN (:ownerText,:otherText)"},
      {table="route_instance_legs",where="route_instance_id=:route"},{table="route_instance_leg_progress",where="route_instance_id=:route"},
      {table="route_instance_geometry_snapshots",where="route_instance_id=:route"},
      {table="route_instance_sections",where="route_instance_id=:route"},{table="loop_routes",where="id=:generated"},
      {table="contacts",where="userId IN (:ownerText,:otherText)"},{table="operators",where="userId IN (:ownerText,:otherText)"},
      {table="passengers",where="userId IN (:ownerText,:otherText)"},{table="waypoints",where="userId IN (:ownerText,:otherText)"},
      {table="floatplan_contacts",where="floatPlanId"&plans},{table="floatplan_passengers",where="floatPlanId"&plans},
      {table="floatplan_waypoints",where="floatPlanId"&plans},{table="floatplan_operators",where="floatPlanId"&plans},
      {table="floatplan_vessels",where="floatPlanId"&plans},
      {table="premium_send_credits",where="user_id"&ownedUsers},{table="premium_send_receipts",where="user_id"&ownedUsers},
      {table="member_entitlements",where="user_id"&ownedUsers},
      {table="floatplan_monitoring",where="user_id"&ownedUsers},{table="floatplan_monitor_events",where="user_id"&ownedUsers},
      {table="floatplan_events",where="user_id"&ownedUsers},{table="floatplan_activity_segments",where="user_id"&ownedUsers},
      {table="floatplan_captain_log_entries",where="user_id"&ownedUsers},{table="floatplan_companion_events",where="user_id"&ownedUsers},
      {table="floatplan_alert_history",where="floatPlanId"&plans},{table="floatplans_tosend",where="floatPlanId"&plans},
      {table="voyage_streams",where="owner_user_id"&ownedUsers},{table="voyage_followers",where="stream_id"&streams},
      {table="voyage_posts",where="stream_id"&streams},
      {table="voyage_comments",where="post_id IN (SELECT id FROM voyage_posts WHERE stream_id"&streams&")"},
      {table="voyage_reactions",where="post_id IN (SELECT id FROM voyage_posts WHERE stream_id"&streams&")"},
      {table="product_events",where="user_id"&ownedUsers},{table="inactive_member_recovery_messages",where="user_id"&ownedUsers}
    ];
    var snapshot=structNew("ordered");
    snapshot["operational"]={};snapshot["attribution"]={};
    for(var item in specs) {
      var rows=q("SELECT * FROM "&item.table&" WHERE "&item.where&" ORDER BY 1",params);
      var bucket=listFindNoCase("users,product_events,inactive_member_recovery_messages",item.table) ? "attribution" : "operational";
      snapshot[bucket][item.table]={"count"=rows.recordCount,"digest"=hash(serializeJSON(rows),"SHA-256")};
    }
    snapshot["availableCredits"]=val(q("SELECT COUNT(*) n FROM premium_send_credits WHERE user_id=:owner AND status='AVAILABLE'",params).n[1]);
    snapshot["generatedFiles"]=[];
    var directory=getDirectoryFromPath(getCurrentTemplatePath())&"../../api/api_assets/floatPlans/user_float_plans";
    if(directoryExists(directory)) for(var file in directoryList(directory,false,"query")) {
      if(findNoCase(left(f.fixture,8),file.name))
        arrayAppend(snapshot.generatedFiles,{name=file.name,size=file.size});
    }
    return snapshot;
  }

  public void function cleanupFixture(required struct fixture) {
    var f=arguments.fixture;
    var params={owner=num(f.ownerId),other=num(f.otherId),ownerText=txt(f.ownerId),otherText=txt(f.otherId),route=num(f.routeInstanceId),generated=num(f.generatedRouteId)};
    var owners=" IN (:owner,:other)";
    var plans=" IN (SELECT floatPlanId FROM floatplans WHERE userId IN (:ownerText,:otherText))";
    var streams=" IN (SELECT id FROM voyage_streams WHERE owner_user_id IN (:owner,:other))";
    var existing=q("SELECT COUNT(*) n FROM users WHERE userId IN (:owner,:other) AND email LIKE :prefix",
      {owner=num(f.ownerId),other=num(f.otherId),prefix=txt(f.marker&"-%@example.test")});
    if(val(existing.n[1]) NEQ 2) throw(type="FPW.PreviewFixture.Scope",message="Fixture identity verification failed.");
    for(var table in ["voyage_reactions","voyage_comments"])
      q("DELETE FROM "&table&" WHERE post_id IN (SELECT id FROM voyage_posts WHERE stream_id"&streams&")",params);
    q("DELETE FROM voyage_posts WHERE stream_id"&streams,params);
    q("DELETE FROM voyage_followers WHERE stream_id"&streams,params);
    q("DELETE FROM voyage_streams WHERE owner_user_id"&owners,params);
    q("DELETE FROM floatplan_activity_segments WHERE user_id"&owners,params);
    for(var table in ["floatplan_captain_log_entries","floatplan_companion_events","floatplan_events","floatplan_monitor_events","floatplan_monitoring"])
      q("DELETE FROM "&table&" WHERE user_id"&owners,params);
    q("DELETE FROM premium_send_receipts WHERE user_id"&owners,params);
    q("DELETE FROM premium_send_credits WHERE user_id"&owners,params);
    for(var table in ["floatplan_contacts","floatplan_passengers","floatplan_waypoints","floatplan_operators","floatplan_vessels","floatplan_alert_history","floatplans_tosend"])
      q("DELETE FROM "&table&" WHERE floatPlanId"&plans,params);
    q("DELETE FROM floatplans WHERE userId IN (:ownerText,:otherText)",params);
    for(var table in ["route_instance_geometry_snapshots","route_instance_leg_progress","route_instance_legs","route_instance_sections"])
      q("DELETE FROM "&table&" WHERE route_instance_id=:route",params);
    q("DELETE FROM route_instances WHERE id=:route",params);
    q("DELETE FROM loop_routes WHERE id=:generated",params);
    q("DELETE FROM inactive_member_recovery_messages WHERE user_id"&owners,params);
    q("DELETE FROM product_events WHERE user_id"&owners,params);
    q("DELETE FROM member_entitlements WHERE user_id"&owners,params);
    for(var table in ["waypoints","passengers","operators","contacts","vessels"])
      q("DELETE FROM "&table&" WHERE userId IN (:ownerText,:otherText)",params);
    q("DELETE FROM users WHERE userId"&owners,params);
  }
}
