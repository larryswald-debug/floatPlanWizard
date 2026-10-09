component extends="testbox.system.BaseSpec" output="false" {
  variables.datasource="fpw";
  variables.fixtures=[];

  function run() {
    describe("Companion tracking Phase 1 server contract",function() {
      beforeEach(function() {
        variables.fixtures=[];
        variables.f=createFixture();
        variables.service=new fpw.api.v1.CompanionTrackingService().init(variables.datasource);
      });
      afterEach(function() { cleanupFixtures(); });

      it("rejects missing bearer over HTTP",function() {
        var r=httpCall("eligibility","GET",{},"");
        expect(r.status).toBe(401); expect(r.body.SUCCESS).toBeFalse();
      });
      it("does not authorize tracking through an authenticated web session",function() {
        var hadUser=structKeyExists(session,"user"); var savedUser=hadUser ? duplicate(session.user) : {};
        try {
          session.user={USERID=f.userId};
          var responseBody="";
          savecontent variable="responseBody" { new fpw.api.v1.companionTracking().handle(action="eligibility"); }
          var r=deserializeJSON(responseBody);
          expect(r.SUCCESS).toBeFalse(); expect(r.AUTH).toBeFalse(); expect(sessionCount(f)).toBe(0);
        } finally {
          if(hadUser) session.user=savedUser; else structDelete(session,"user");
          getPageContext().getResponse().setStatus(200);
        }
      });
      it("rejects malformed bearer over HTTP",function() {
        var r=httpCall("eligibility","GET",{},"Basic invalid");
        expect(r.status).toBe(401); expect(r.body.SUCCESS).toBeFalse();
      });
      it("rejects unknown bearer over HTTP",function() {
        var r=httpCall("eligibility","GET",{},"Bearer fpwc_unknown.invalid");
        expect(r.status).toBe(401); expect(r.body.SUCCESS).toBeFalse();
      });
      it("rejects expired bearer over HTTP",function() {
        q("UPDATE companion_devices SET expires_at_utc=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 SECOND) WHERE id=:id",{id=num(f.deviceId)});
        var r=httpCall("eligibility","GET",{},"Bearer "&f.token);
        expect(r.status).toBe(401); expect(r.body.SUCCESS).toBeFalse();
      });
      it("rejects revoked bearer over HTTP",function() {
        q("UPDATE companion_devices SET revoked_at_utc=UTC_TIMESTAMP() WHERE id=:id",{id=num(f.deviceId)});
        var r=httpCall("eligibility","GET",{},"Bearer "&f.token);
        expect(r.status).toBe(401); expect(r.body.SUCCESS).toBeFalse();
      });
      it("requires re-pair for old credentials without adding tracking scope",function() {
        q("UPDATE companion_devices SET scopes='companion:current,companion:checkin' WHERE id=:id",{id=num(f.deviceId)});
        var before=q("SELECT * FROM companion_devices WHERE id=:id",{id=num(f.deviceId)});
        var r=httpCall("eligibility","GET",{},"Bearer "&f.token);
        expect(r.status).toBe(403); expect(r.body.SUCCESS).toBeFalse();
        expect(findNoCase("repair",replace(serializeJSON(r.body),"-","","all")) GT 0 OR findNoCase("re_pair",serializeJSON(r.body)) GT 0).toBeTrue();
        expect(hash(serializeJSON(q("SELECT * FROM companion_devices WHERE id=:id",{id=num(f.deviceId)})))).toBe(hash(serializeJSON(before)));
      });
      it("new pairing grants all three companion scopes",function() {
        var authService=new fpw.api.v1.CompanionAuthService().init(variables.datasource);
        var code=authService.createPairingCode(f.userId);
        expect(code.SUCCESS).toBeTrue();
        var paired=authService.exchangePairingCode(code.PAIRING_CODE,{deviceUuid=uuid(),deviceName="Tracking Test",platform="ios",appVersion="phase1"});
        expect(paired.SUCCESS).toBeTrue();
        expect(listFindNoCase(paired.SCOPES,"companion:current")).toBeGT(0);
        expect(listFindNoCase(paired.SCOPES,"companion:checkin")).toBeGT(0);
        expect(listFindNoCase(paired.SCOPES,"companion:tracking")).toBeGT(0);
      });
      it("preserves old-token access to the existing current-trip endpoint",function() {
        q("UPDATE companion_devices SET scopes='companion:current,companion:checkin' WHERE id=:id",{id=num(f.deviceId)});
        planStatus("DRAFT"); var r=httpCall("current","GET",{},"Bearer "&f.token,"","companion.cfc");
        expect(r.status).toBe(200); expect(r.body.AUTH).toBeTrue(); expect(r.body.HAS_ACTIVE_PLAN).toBeFalse();
        expect(r.body.ERROR).toBe("NO_ACTIVE_PLAN");
      });
      it("preserves old-token authorization and validation in the existing check-in endpoint",function() {
        q("UPDATE companion_devices SET scopes='companion:current,companion:checkin' WHERE id=:id",{id=num(f.deviceId)});
        var before=snapshot(f); var r=httpCall("checkin","POST",{},"Bearer "&f.token,"","companion.cfc");
        expect(r.status).toBe(200); expect(r.body.AUTH).toBeTrue(); expect(r.body.SUCCESS).toBeFalse();
        expect(r.body.ERROR).toBe("MOBILE_SUBMISSION_ID_REQUIRED"); expect(snapshot(f)).toBe(before);
      });
      it("rejects scalar samples without discarding valid siblings",function() {
        var s=start(); var r=call("batch",batch(s,[23,"null",sample()])); expect(r.SUCCESS).toBeTrue();
        expect(arrayLen(r.acceptedSampleIds)).toBe(1); expect(arrayLen(r.rejectedSamples)).toBe(2); expect(sampleCount(s)).toBe(1);
      });
      it("read-only eligibility returns the current canonical trip and leaves device usage unchanged",function() {
        var before=snapshot(f,true);
        var r=httpCall("eligibility","GET",{},"Bearer "&f.token);
        expect(r.status).toBe(200); expect(r.body.SUCCESS).toBeTrue();
        expect(toString(r.body.floatPlanId)).toBe(toString(f.planId));
        expect(toString(r.body.routeInstanceId)).toBe(toString(f.routeId));
        expect(snapshot(f,true)).toBe(before);
        expect(sessionCount(f)).toBe(0);
      });
      it("rejects a member with no active trip",function() {
        planStatus("DRAFT"); expectDenied(call("eligibility"));
      });
      it("rejects a Draft trip without activating it",function() {
        planStatus("DRAFT"); var before=snapshot(f); expectDenied(call("start",startPayload())); expect(snapshot(f)).toBe(before);
      });
      it("rejects a closed trip",function() {
        planStatus("CLOSED"); expectDenied(call("eligibility"));
      });
      it("rejects a cancelled trip",function() {
        planStatus("CANCELLED"); expectDenied(call("eligibility"));
      });
      it("rejects expired operational access without expiring the Float Plan",function() {
        setAccessSeconds(-1); var before=snapshot(f);
        expectDenied(call("eligibility")); expect(snapshot(f)).toBe(before);
        expect(q("SELECT status FROM floatplans WHERE floatPlanId=:id",{id=num(f.planId)}).status[1]).toBe("ACTIVE");
      });
      it("rejects multiple active route-backed trips",function() {
        q("INSERT INTO floatplans(userId,floatPlanName,dateCreated,lastUpdate,status,route_instance_id) VALUES(:u,:n,UTC_TIMESTAMP(),UTC_TIMESTAMP(),'ACTIVE',:r)",
          {u=txt(f.userId),n=txt(f.marker&"-second"),r=num(f.routeId)});
        expectDenied(call("eligibility")); expect(sessionCount(f)).toBe(0);
      });
      it("does not accept foreign Float Plan or route IDs as authority",function() {
        var other=createFixture(); var p=startPayload(); p.floatPlanId=toString(other.planId); p.routeInstanceId=toString(other.routeId);
        expectDenied(call("start",p)); expect(sessionCount(f)).toBe(0);
      });
      it("rejects a route whose owner differs from the Float Plan owner",function() {
        var other=createFixture(); q("UPDATE route_instances SET user_id=:u WHERE id=:r",{u=txt(other.userId),r=num(f.routeId)});
        expectDenied(call("eligibility"));
      });
      it("starts one session and returns its persisted authorization deadline",function() {
        var s=start(); expect(s.sessionStatus).toBe("ACTIVE");
        var row=q("SELECT DATE_FORMAT(authorization_valid_until_utc,'%Y-%m-%dT%H:%i:%s.%fZ') deadline, TIMESTAMPDIFF(SECOND,started_at_utc,authorization_valid_until_utc) seconds FROM companion_tracking_sessions WHERE id=:id",{id=num(s.trackingSessionId)});
        expect(row.seconds[1]).toBeLTE(604800); expect(row.seconds[1]).toBeGTE(604790);
        expect(len(s.authorizationValidUntilUtc)).toBeGT(0); expect(sessionCount(f)).toBe(1);
      });
      it("retries the same client session without creating another row",function() {
        var p=startPayload(); var a=call("start",p); var b=call("start",p);
        expect(a.SUCCESS).toBeTrue(); expect(b.SUCCESS).toBeTrue();
        expect(b.trackingSessionId).toBe(a.trackingSessionId); expect(sessionCount(f)).toBe(1);
      });
      it("rejects reuse of a client session ID with changed consent context",function() {
        var p=startPayload(); expect(call("start",p).SUCCESS).toBeTrue(); p.consentVersion="changed-consent";
        expectDenied(call("start",p)); expect(sessionCount(f)).toBe(1);
      });
      it("rejects a second active session on the same device",function() {
        start(); expectDenied(call("start",startPayload())); expect(sessionCount(f)).toBe(1);
      });
      it("rejects a competing collecting device on the same trip",function() {
        start(); var device=createDevice(f.userId); expectDenied(service.handle("start",auth(device.token),startPayload()));
        expect(sessionCount(f)).toBe(1);
      });
      it("shortens the seven day deadline to token expiry",function() {
        q("UPDATE companion_devices SET expires_at_utc=DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 DAY) WHERE id=:id",{id=num(f.deviceId)});
        var s=start();
        expect(q("SELECT (s.authorization_valid_until_utc<=d.expires_at_utc) bounded FROM companion_tracking_sessions s JOIN companion_devices d ON d.id=s.companion_device_id WHERE s.id=:id",{id=num(s.trackingSessionId)}).bounded[1]).toBe(1);
      });
      it("shortens the deadline to known trip access expiry",function() {
        setAccessSeconds(3600); var s=start();
        expect(q("SELECT (s.authorization_valid_until_utc<=r.access_expires_at_utc) bounded FROM companion_tracking_sessions s JOIN premium_send_receipts r ON r.float_plan_id=s.floatplan_id WHERE s.id=:id",{id=num(s.trackingSessionId)}).bounded[1]).toBe(1);
      });
      it("shortens a general Premium trip deadline to its known entitlement expiry",function() {
        q("INSERT INTO member_entitlements(user_id,entitlement_type,source,status,starts_at_utc,expires_at_utc,admin_notes) VALUES(:u,'premium','admin_grant','active',DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 DAY),DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 HOUR),:m)",{u=num(f.userId),m=txt(f.marker&"-active")});
        var entitlement=val(q("SELECT id FROM member_entitlements WHERE user_id=:u AND status='active'",{u=num(f.userId)}).id[1]);
        q("UPDATE premium_send_receipts SET credit_id=NULL,access_source='general_premium',access_expires_at_utc=NULL,member_entitlement_id=:e WHERE float_plan_id=:p",{e=num(entitlement),p=num(f.planId)});
        var s=start();
        expect(q("SELECT (s.authorization_valid_until_utc<=e.expires_at_utc) bounded FROM companion_tracking_sessions s JOIN member_entitlements e ON e.id=:e WHERE s.id=:id",{e=num(entitlement),id=num(s.trackingSessionId)}).bounded[1]).toBe(1);
      });
      it("rejects invalid client session UUIDs before creating a session",function() {
        var p=startPayload(); p.clientSessionId="invalid"; expectDenied(call("start",p)); expect(sessionCount(f)).toBe(0);
      });
      it("serializes competing duplicate starts into a single session",function() {
        var p=startPayload(); var results=concurrent("start",p,auth(f.token));
        expect(results[1].SUCCESS).toBeTrue(); expect(results[2].SUCCESS).toBeTrue();
        expect(results[1].trackingSessionId).toBe(results[2].trackingSessionId); expect(sessionCount(f)).toBe(1);
      });
      it("stores one valid sample and acknowledges its UUID",function() {
        var s=start(); var point=sample(); var r=call("batch",batch(s,[point]));
        expect(r.SUCCESS).toBeTrue(); expect(arrayLen(r.acceptedSampleIds)).toBe(1);
        expect(r.acceptedSampleIds[1]).toBe(point.clientSampleId); expect(sampleCount(s)).toBe(1);
      });
      it("stores multiple valid samples including optional speed and course",function() {
        var s=start(); var point=sample(); point.speedKnots=6.2; point.courseDegrees=182;
        var r=call("batch",batch(s,[point,sample(),sample()]));
        expect(r.SUCCESS).toBeTrue(); expect(arrayLen(r.acceptedSampleIds)).toBe(3); expect(sampleCount(s)).toBe(3);
      });
      it("retries an entire batch as duplicates without duplicate rows",function() {
        var s=start(); var p=batch(s,[sample(),sample()]); expect(call("batch",p).SUCCESS).toBeTrue(); var r=call("batch",p);
        expect(arrayLen(r.acceptedSampleIds)).toBe(0); expect(arrayLen(r.duplicateSampleIds)).toBe(2); expect(sampleCount(s)).toBe(2);
      });
      it("keeps immutable original coordinates on sample UUID payload conflict",function() {
        var s=start(); var point=sample(); var p=batch(s,[point]); call("batch",p); p.samples[1].latitude=28;
        var r=call("batch",p); expect(arrayLen(r.rejectedSamples)).toBe(1);
        expect(findNoCase("SAMPLE_ID_CONFLICT",serializeJSON(r.rejectedSamples))).toBeGT(0);
        expect(q("SELECT latitude FROM companion_location_samples WHERE tracking_session_id=:id",{id=num(s.trackingSessionId)}).latitude[1]).toBe(27.9506);
      });
      it("normalizes numeric payloads before duplicate comparison",function() {
        var s=start(); var point=sample(); point.speedKnots=6; point.courseDegrees=180;
        var p=batch(s,[point]); call("batch",p);
        p.samples[1].latitude=27.9506000; p.samples[1].speedKnots=6.000;
        var r=call("batch",p); expect(arrayLen(r.duplicateSampleIds)).toBe(1); expect(sampleCount(s)).toBe(1);
      });
      it("rejects out-of-range latitude",function() { rejectPoint("latitude",90.01); });
      it("rejects out-of-range longitude",function() { rejectPoint("longitude",-180.01); });
      it("rejects zero accuracy",function() { rejectPoint("accuracyMeters",0); });
      it("rejects accuracy above 500 meters",function() { rejectPoint("accuracyMeters",500.01); });
      it("rejects speed above 200 knots",function() { rejectPoint("speedKnots",200.01); });
      it("rejects negative speed",function() { rejectPoint("speedKnots",-1); });
      it("rejects course at 360 degrees",function() { rejectPoint("courseDegrees",360); });
      it("rejects negative course",function() { rejectPoint("courseDegrees",-1); });
      it("rejects noncanonical sample UUID",function() { rejectPoint("clientSampleId","not-a-uuid"); });
      it("rejects numeric strings rather than coercing coordinates",function() { rejectPoint("latitude","27.9506"); });
      it("rejects boolean coordinates rather than coercing them",function() { rejectPoint("latitude",true); });
      it("rejects non-finite coordinate representations",function() { rejectPoint("latitude","Infinity"); });
      it("rejects captures more than two minutes into the future",function() { rejectPoint("capturedAtUtc",utc(180)); });
      it("rejects captures older than seven days",function() { rejectPoint("capturedAtUtc",utc(-604801)); });
      it("rejects non-UTC capture timestamps",function() { rejectPoint("capturedAtUtc","2026-10-08T12:00:00-04:00"); });
      it("rejects impossible calendar timestamps",function() { rejectPoint("capturedAtUtc","2026-02-30T12:00:00.000Z"); });
      it("rejects captures preceding the tracking session start",function() { rejectPoint("capturedAtUtc",utc(-60)); });
      it("accepts inclusive coordinate and accuracy boundaries",function() {
        var s=start(); var a=sample(); a.latitude=-90; a.longitude=-180; a.accuracyMeters=500; a.speedKnots=0; a.courseDegrees=0;
        var b=sample(); b.latitude=90; b.longitude=180; b.accuracyMeters=0.01; b.speedKnots=200; b.courseDegrees=359.99;
        var r=call("batch",batch(s,[a,b])); expect(arrayLen(r.acceptedSampleIds)).toBe(2);
      });
      it("rejects samples beyond the session authorization boundary",function() {
        var s=start(); q("UPDATE companion_tracking_sessions SET authorization_valid_until_utc=DATE_ADD(UTC_TIMESTAMP(3),INTERVAL 10 SECOND) WHERE id=:id",{id=num(s.trackingSessionId)});
        var point=sample(); point.capturedAtUtc=utc(30);
        var r=call("batch",batch(s,[point])); expect(arrayLen(r.rejectedSamples)).toBe(1); expect(sampleCount(s)).toBe(0);
      });
      it("accepts valid points and explicitly rejects invalid points in a partial batch",function() {
        var s=start(); var bad=sample(); bad.longitude=999;
        var r=call("batch",batch(s,[sample(),bad,sample()]));
        expect(r.SUCCESS).toBeTrue(); expect(arrayLen(r.acceptedSampleIds)).toBe(2); expect(arrayLen(r.rejectedSamples)).toBe(1);
        expect(structKeyExists(r.rejectedSamples[1],"index")).toBeTrue(); expect(structKeyExists(r.rejectedSamples[1],"clientSampleId")).toBeTrue();
        expect(sampleCount(s)).toBe(2);
      });
      it("rejects a null sample by index while accepting a valid sibling",function() {
        var s=start(); var points=deserializeJSON("[null]"); arrayAppend(points,sample());
        var r=httpCall("batch","POST",batch(s,points),"Bearer "&f.token);
        if(r.status NEQ 200) fail("Null sample partial batch failed: "&serializeJSON(r.body));
        expect(r.body.SUCCESS).toBeTrue();
        expect(arrayLen(r.body.acceptedSampleIds)).toBe(1); expect(arrayLen(r.body.rejectedSamples)).toBe(1);
        expect(r.body.rejectedSamples[1].index).toBe(0); expect(sampleCount(s)).toBe(1);
      });
      it("rejects overflow tracking IDs as permanent invalid input",function() {
        for(var id in ["9999999999999999999","9223372036854775808"]) {
          var r=call("status",{trackingSessionId=id}); expect(r.SUCCESS).toBeFalse(); expect(r.HTTP_STATUS).toBe(400);
        }
      });
      it("rejects a JSON null request body with permanent 400",function() {
        var r=httpCall("start","POST",{},"Bearer "&f.token,"null"); expect(r.status).toBe(400); expect(r.body.SUCCESS).toBeFalse(); expect(sessionCount(f)).toBe(0);
      });
      it("rejects more than 100 samples without storing any",function() {
        var s=start(); var points=[]; for(var i=1;i<=101;i++) arrayAppend(points,sample());
        expectDenied(call("batch",batch(s,points))); expect(sampleCount(s)).toBe(0);
      });
      it("accepts the maximum batch of 100 samples",function() {
        var s=start(); var points=[]; for(var i=1;i<=100;i++) arrayAppend(points,sample());
        var r=call("batch",batch(s,points)); expect(r.SUCCESS).toBeTrue(); expect(arrayLen(r.acceptedSampleIds)).toBe(100); expect(sampleCount(s)).toBe(100);
      });
      it("rejects a structurally invalid batch without acknowledgments",function() {
        var s=start(); expectDenied(call("batch",{trackingSessionId=s.trackingSessionId,batchId=uuid(),samples="invalid"})); expect(sampleCount(s)).toBe(0);
      });
      it("rejects an oversized HTTP request with 413",function() {
        var s=start(); var p=batch(s,[sample()]); p.padding=repeatString("x",65536);
        var r=httpCall("batch","POST",p,"Bearer "&f.token);
        expect(r.status).toBe(413); expect(r.body.SUCCESS).toBeFalse(); expect(sampleCount(s)).toBe(0);
      });
      it("rejects non-POST mutation requests over HTTP",function() {
        var r=httpCall("start","GET",{},"Bearer "&f.token); expect(r.status).toBe(405); expect(sessionCount(f)).toBe(0);
      });
      it("rejects foreign devices on every session action",function() {
        var s=start(); var d=createDevice(f.userId); var context=auth(d.token);
        for(var action in ["status","latest","stop","finish","batch"]) {
          var p={trackingSessionId=s.trackingSessionId,captureStoppedAtUtc=utc(0)};
          if(action EQ "batch") p=batch(s,[sample()]);
          expectDenied(service.handle(action,context,p));
        }
        expect(sampleCount(s)).toBe(0);
      });
      it("rejects foreign members on every session action",function() {
        var s=start(); var other=createFixture(); var context=auth(other.token);
        for(var action in ["status","latest","stop","finish","batch"]) {
          var p={trackingSessionId=s.trackingSessionId,captureStoppedAtUtc=utc(0)};
          if(action EQ "batch") p=batch(s,[sample()]);
          expectDenied(service.handle(action,context,p));
        }
      });
      it("serializes concurrent duplicate uploads into one immutable row",function() {
        var s=start(); var p=batch(s,[sample()]); var results=concurrent("batch",p,auth(f.token));
        expect(results[1].SUCCESS).toBeTrue(); expect(results[2].SUCCESS).toBeTrue();
        expect(arrayLen(results[1].acceptedSampleIds)+arrayLen(results[2].acceptedSampleIds)).toBe(1);
        expect(arrayLen(results[1].duplicateSampleIds)+arrayLen(results[2].duplicateSampleIds)).toBe(1); expect(sampleCount(s)).toBe(1);
      });
      it("rolls back an entire batch after a database failure and reports no acknowledgments",function() {
        var s=start(); var failing=new fpw.tests.support.CompanionTrackingFailingStorage().init(variables.datasource);
        var r=failing.handle("batch",auth(f.token),batch(s,[sample(),sample()]));
        expect(r.SUCCESS).toBeFalse(); expect(r.HTTP_STATUS).toBeGTE(500); expect(sampleCount(s)).toBe(0);
        expect(!structKeyExists(r,"acceptedSampleIds") OR arrayLen(r.acceptedSampleIds) EQ 0).toBeTrue();
        expect(!structKeyExists(r,"duplicateSampleIds") OR arrayLen(r.duplicateSampleIds) EQ 0).toBeTrue();
        var row=q("SELECT last_sample_captured_at_utc IS NULL no_sample,last_received_at_utc IS NULL no_receive FROM companion_tracking_sessions WHERE id=:id",{id=num(s.trackingSessionId)});
        expect(row.no_sample[1]).toBe(1); expect(row.no_receive[1]).toBe(1);
      });
      it("persists Stop cutoff and a drain boundary no longer than 24 hours",function() {
        var s=start(); var p={trackingSessionId=s.trackingSessionId,captureStoppedAtUtc=utc(0)};
        var r=call("stop",p); expect(r.SUCCESS).toBeTrue(); expect(r.sessionStatus).toBe("DRAINING");
        var row=q("SELECT TIMESTAMPDIFF(SECOND,capture_stopped_at_utc,drain_until_utc) seconds FROM companion_tracking_sessions WHERE id=:id",{id=num(s.trackingSessionId)});
        expect(row.seconds[1]).toBeLTE(86400);
      });
      it("retries Stop without extending its cutoff or drain deadline",function() {
        var s=start(); var p={trackingSessionId=s.trackingSessionId,captureStoppedAtUtc=utc(0)};
        expect(call("stop",p).SUCCESS).toBeTrue();
        var before=q("SELECT capture_stopped_at_utc,drain_until_utc FROM companion_tracking_sessions WHERE id=:id",{id=num(s.trackingSessionId)});
        expect(call("stop",p).SUCCESS).toBeTrue();
        expect(serializeJSON(q("SELECT capture_stopped_at_utc,drain_until_utc FROM companion_tracking_sessions WHERE id=:id",{id=num(s.trackingSessionId)}))).toBe(serializeJSON(before));
      });
      it("acknowledges an identical accepted future-clock retry after Stop without exposing it as latest",function() {
        var s=start(); var point=sample(); point.capturedAtUtc=utc(60); var p=batch(s,[point]);
        expect(arrayLen(call("batch",p).acceptedSampleIds)).toBe(1);
        expect(call("stop",{trackingSessionId=s.trackingSessionId,captureStoppedAtUtc=utc(0)}).SUCCESS).toBeTrue();
        var retry=call("batch",p); expect(retry.SUCCESS).toBeTrue(); expect(arrayLen(retry.duplicateSampleIds)).toBe(1); expect(sampleCount(s)).toBe(1);
        expect(call("latest",{trackingSessionId=s.trackingSessionId}).hasLocation).toBeFalse();
      });
      it("accepts valid pre-cutoff backlog while draining",function() {
        var s=start(); backdateStart(s); var point=sample(); point.capturedAtUtc=utc(-30);
        expect(call("stop",{trackingSessionId=s.trackingSessionId,captureStoppedAtUtc=utc(0)}).SUCCESS).toBeTrue();
        var r=call("batch",batch(s,[point])); expect(arrayLen(r.acceptedSampleIds)).toBe(1);
      });
      it("rejects post-cutoff captures while draining",function() {
        var s=start(); backdateStart(s); call("stop",{trackingSessionId=s.trackingSessionId,captureStoppedAtUtc=utc(-10)});
        var r=call("batch",batch(s,[sample()])); expect(arrayLen(r.rejectedSamples)).toBe(1); expect(sampleCount(s)).toBe(0);
      });
      it("rejects historical inserts after the 24 hour drain window",function() {
        var s=start(); backdateStart(s); call("stop",{trackingSessionId=s.trackingSessionId,captureStoppedAtUtc=utc(0)});
        q("UPDATE companion_tracking_sessions SET drain_until_utc=DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 1 SECOND) WHERE id=:id",{id=num(s.trackingSessionId)});
        var point=sample(); point.capturedAtUtc=utc(-30); expectDenied(call("batch",batch(s,[point]))); expect(sampleCount(s)).toBe(0);
      });
      it("rejects old backlog immediately after trip invalidation",function() {
        var s=start(); backdateStart(s); var point=sample(); point.capturedAtUtc=utc(-30); planStatus("CANCELLED");
        var before=snapshot(f); expectDenied(call("batch",batch(s,[point]))); expect(snapshot(f)).toBe(before); expect(sampleCount(s)).toBe(0);
      });
      it("rechecks revoked devices inside ingestion despite previously resolved auth",function() {
        var s=start(); var context=auth(f.token); q("UPDATE companion_devices SET revoked_at_utc=UTC_TIMESTAMP() WHERE id=:id",{id=num(f.deviceId)});
        expectDenied(service.handle("batch",context,batch(s,[sample()]))); expect(sampleCount(s)).toBe(0);
      });
      it("closes a drained session without deleting acknowledged history",function() {
        var s=start(); call("batch",batch(s,[sample()])); call("stop",{trackingSessionId=s.trackingSessionId,captureStoppedAtUtc=utc(0)});
        var r=call("finish",{trackingSessionId=s.trackingSessionId}); expect(r.SUCCESS).toBeTrue(); expect(r.sessionStatus).toBe("CLOSED"); expect(sampleCount(s)).toBe(1);
      });
      it("reports authoritative ACTIVE DRAINING and CLOSED states",function() {
        var s=start(); var p={trackingSessionId=s.trackingSessionId}; expect(call("status",p).sessionStatus).toBe("ACTIVE");
        call("stop",{trackingSessionId=s.trackingSessionId,captureStoppedAtUtc=utc(0)}); expect(call("status",p).sessionStatus).toBe("DRAINING");
        call("finish",p); var closed=call("status",p); expect(closed.sessionStatus).toBe("CLOSED"); expect(closed.eligible).toBeFalse();
      });
      it("accepts trackingSessionId on authenticated status and latest HTTP GET requests",function() {
        var s=start(); var p={trackingSessionId=s.trackingSessionId}; var authorization="Bearer "&f.token;
        var before=snapshot(f,true);
        var active=httpCall("status","GET",p,authorization);
        expect(active.status).toBe(200); expect(active.body.SUCCESS).toBeTrue(); expect(active.body.AUTH).toBeTrue();
        expect(active.body.trackingSessionId).toBe(s.trackingSessionId); expect(active.body.sessionStatus).toBe("ACTIVE");
        expect(active.body.eligible).toBeTrue();
        var latest=httpCall("latest","GET",p,authorization);
        expect(latest.status).toBe(200); expect(latest.body.SUCCESS).toBeTrue(); expect(latest.body.AUTH).toBeTrue();
        expect(latest.body.trackingSessionId).toBe(s.trackingSessionId); expect(latest.body.hasLocation).toBeFalse();
        expect(snapshot(f,true)).toBe(before);
        call("stop",{trackingSessionId=s.trackingSessionId,captureStoppedAtUtc=utc(0)});
        var draining=httpCall("status","GET",p,authorization);
        expect(draining.status).toBe(200); expect(draining.body.sessionStatus).toBe("DRAINING");
        expect(draining.body.eligible).toBeTrue();
        call("finish",p);
        var closed=httpCall("status","GET",p,authorization);
        expect(closed.status).toBe(200); expect(closed.body.sessionStatus).toBe("CLOSED"); expect(closed.body.eligible).toBeFalse();
      });
      it("returns an explicit no-location response before the first accepted point",function() {
        var s=start(); var r=call("latest",{trackingSessionId=s.trackingSessionId}); expect(r.SUCCESS).toBeTrue(); expect(r.hasLocation).toBeFalse();
      });
      it("chooses greatest capture time when older backlog arrives later",function() {
        var s=start(); backdateStart(s); var recent=sample(); recent.capturedAtUtc=utc(-10); var old=sample(); old.capturedAtUtc=utc(-40); old.latitude=28;
        call("batch",batch(s,[recent])); call("batch",batch(s,[old]));
        var r=call("latest",{trackingSessionId=s.trackingSessionId}); expect(r.SUCCESS).toBeTrue(); expect(r.hasLocation).toBeTrue();
        expect(r.location.clientSampleId).toBe(recent.clientSampleId); expect(r.location.latitude).toBe(recent.latitude);
      });
      it("keeps check-ins trip route monitoring receipts credits entitlements and recovery unchanged",function() {
        var before=snapshot(f); call("eligibility"); var s=start(); var p=batch(s,[sample(),sample()]);
        call("batch",p); call("batch",p); call("latest",{trackingSessionId=s.trackingSessionId}); call("status",{trackingSessionId=s.trackingSessionId});
        call("stop",{trackingSessionId=s.trackingSessionId,captureStoppedAtUtc=utc(0)}); call("finish",{trackingSessionId=s.trackingSessionId});
        expect(snapshot(f)).toBe(before); expect(sampleCount(s)).toBe(2);
      });
      it("cascades user deletion through tracking sessions and samples",function() {
        var s=start(); call("batch",batch(s,[sample()]));
        // Remove nontracking fixture children exactly as account deletion does, then prove the new FK cascade.
        cleanupOperationalChildren(f);
        q("DELETE FROM users WHERE userId=:u AND email=:e",{u=num(f.userId),e=txt(f.email)});
        expect(sessionCount(f)).toBe(0); expect(sampleCount(s)).toBe(0); f.userDeleted=true;
      });
      it("cascades device deletion through tracking sessions and samples",function() {
        var s=start(); call("batch",batch(s,[sample()])); q("DELETE FROM companion_devices WHERE id=:id",{id=num(f.deviceId)});
        expect(sessionCount(f)).toBe(0); expect(sampleCount(s)).toBe(0);
      });
      it("maintenance reconciles invalid trips without operational mutation",function() {
        var s=start(); planStatus("CANCELLED"); var before=snapshot(f); assertMaintenanceIsolated();
        var result=service.runMaintenance(100); expect(result.SUCCESS).toBeTrue();
        expect(q("SELECT status FROM companion_tracking_sessions WHERE id=:id",{id=num(s.trackingSessionId)}).status[1]).toBe("CLOSED");
        expect(snapshot(f)).toBe(before);
      });
      it("maintenance closes revoked-device sessions",function() {
        var s=start(); q("UPDATE companion_devices SET revoked_at_utc=UTC_TIMESTAMP() WHERE id=:id",{id=num(f.deviceId)}); assertMaintenanceIsolated();
        expect(service.runMaintenance(100).SUCCESS).toBeTrue();
        expect(q("SELECT status FROM companion_tracking_sessions WHERE id=:id",{id=num(s.trackingSessionId)}).status[1]).toBe("CLOSED");
      });
      it("maintenance closes abandoned authorization-expired sessions",function() {
        var s=start(); backdateStart(s);
        q("UPDATE companion_tracking_sessions SET authorization_valid_until_utc=DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 1 SECOND) WHERE id=:id",{id=num(s.trackingSessionId)}); assertMaintenanceIsolated();
        expect(service.runMaintenance(100).SUCCESS).toBeTrue();
        expect(q("SELECT status FROM companion_tracking_sessions WHERE id=:id",{id=num(s.trackingSessionId)}).status[1]).toBe("CLOSED");
      });
      it("maintenance closes expired DRAINING sessions",function() {
        var s=start(); backdateStart(s); call("stop",{trackingSessionId=s.trackingSessionId,captureStoppedAtUtc=utc(0)});
        q("UPDATE companion_tracking_sessions SET drain_until_utc=DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 1 SECOND) WHERE id=:id",{id=num(s.trackingSessionId)}); assertMaintenanceIsolated();
        expect(service.runMaintenance(100).SUCCESS).toBeTrue();
        expect(q("SELECT status FROM companion_tracking_sessions WHERE id=:id",{id=num(s.trackingSessionId)}).status[1]).toBe("CLOSED");
      });
      it("retains samples just inside 90 days and deletes samples just outside 90 days",function() {
        var s=start(); var points=[sample(),sample()]; call("batch",batch(s,points));
        q("UPDATE companion_location_samples SET captured_at_utc=DATE_ADD(DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 90 DAY),INTERVAL 30 SECOND) WHERE tracking_session_id=:id AND client_sample_id=:uuid",{id=num(s.trackingSessionId),uuid=txt(points[1].clientSampleId)});
        q("UPDATE companion_location_samples SET captured_at_utc=DATE_SUB(DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 90 DAY),INTERVAL 30 SECOND) WHERE tracking_session_id=:id AND client_sample_id=:uuid",{id=num(s.trackingSessionId),uuid=txt(points[2].clientSampleId)});
        assertMaintenanceIsolated(); expect(service.runMaintenance(100).SUCCESS).toBeTrue();
        var rows=q("SELECT client_sample_id FROM companion_location_samples WHERE tracking_session_id=:id",{id=num(s.trackingSessionId)});
        expect(rows.recordCount).toBe(1); expect(rows.client_sample_id[1]).toBe(points[1].clientSampleId);
      });
      it("bounds sample-retention deletion by the requested limit",function() {
        var s=start(); call("batch",batch(s,[sample(),sample(),sample()]));
        q("UPDATE companion_location_samples SET captured_at_utc=DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 91 DAY) WHERE tracking_session_id=:id",{id=num(s.trackingSessionId)});
        assertMaintenanceIsolated(); expect(service.runMaintenance(1).SUCCESS).toBeTrue(); expect(sampleCount(s)).toBe(2);
      });
      it("retains recently closed metadata and removes metadata closed more than 90 days ago",function() {
        var first=start(); call("stop",{trackingSessionId=first.trackingSessionId,captureStoppedAtUtc=utc(0)}); call("finish",{trackingSessionId=first.trackingSessionId});
        var second=start(); call("stop",{trackingSessionId=second.trackingSessionId,captureStoppedAtUtc=utc(0)}); call("finish",{trackingSessionId=second.trackingSessionId});
        q("UPDATE companion_tracking_sessions SET closed_at_utc=DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 91 DAY) WHERE id=:id",{id=num(first.trackingSessionId)});
        q("UPDATE companion_tracking_sessions SET closed_at_utc=DATE_ADD(DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 90 DAY),INTERVAL 30 SECOND) WHERE id=:id",{id=num(second.trackingSessionId)});
        assertMaintenanceIsolated(); expect(service.runMaintenance(100).SUCCESS).toBeTrue();
        var rows=q("SELECT id FROM companion_tracking_sessions WHERE user_id=:u",{u=num(f.userId)}); expect(rows.recordCount).toBe(1); expect(rows.id[1]).toBe(second.trackingSessionId);
      });
      it("bounds expired closed-session deletion by the requested limit",function() {
        for(var i=1;i<=3;i++) { var s=start(); call("stop",{trackingSessionId=s.trackingSessionId,captureStoppedAtUtc=utc(0)}); call("finish",{trackingSessionId=s.trackingSessionId}); }
        q("UPDATE companion_tracking_sessions SET closed_at_utc=DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 91 DAY) WHERE user_id=:u",{u=num(f.userId)});
        assertMaintenanceIsolated(); expect(service.runMaintenance(1).SUCCESS).toBeTrue(); expect(sessionCount(f)).toBe(2);
      });
    });
  }

  private any function q(required string sql,struct params={}) {
    return queryExecute(arguments.sql,arguments.params,{datasource=variables.datasource});
  }
  private struct function num(required any value) { return {value=val(arguments.value),cfsqltype="cf_sql_bigint"}; }
  private struct function txt(required any value) { return {value=toString(arguments.value),cfsqltype="cf_sql_varchar"}; }
  private string function uuid() { return lcase(createObject("java","java.util.UUID").randomUUID().toString()); }
  private string function utc(numeric offset=0) {
    return q("SELECT CONCAT(DATE_FORMAT(DATE_ADD(UTC_TIMESTAMP(3),INTERVAL :n SECOND),'%Y-%m-%dT%H:%i:%s.'),LEFT(DATE_FORMAT(DATE_ADD(UTC_TIMESTAMP(3),INTERVAL :n SECOND),'%f'),3),'Z') value",{n=num(arguments.offset)}).value[1];
  }
  private struct function auth(required string token) {
    return new fpw.api.v1.CompanionAuthService().init(variables.datasource).resolveBearerToken("Bearer "&arguments.token,"companion:tracking",false);
  }
  private struct function call(required string action,struct payload={}) { return variables.service.handle(arguments.action,auth(f.token),arguments.payload); }
  private void function expectDenied(required struct response) { expect(arguments.response.SUCCESS).toBeFalse(); }
  private struct function startPayload() { return {clientSessionId=uuid(),floatPlanId=toString(f.planId),routeInstanceId=toString(f.routeId),consentVersion="phase1-test-v1"}; }
  private struct function start() { var r=call("start",startPayload()); if(!r.SUCCESS) fail("Tracking start failed: "&serializeJSON(r)); return r; }
  private struct function sample() { return {clientSampleId=uuid(),latitude=27.9506,longitude=-82.4572,accuracyMeters=18,capturedAtUtc=utc(0)}; }
  private struct function batch(required struct session,required array samples) { return {trackingSessionId=toString(arguments.session.trackingSessionId),batchId=uuid(),samples=arguments.samples}; }
  private numeric function sessionCount(required struct fixture) { return val(q("SELECT COUNT(*) n FROM companion_tracking_sessions WHERE user_id=:u",{u=num(arguments.fixture.userId)}).n[1]); }
  private numeric function sampleCount(required struct session) { return val(q("SELECT COUNT(*) n FROM companion_location_samples WHERE tracking_session_id=:id",{id=num(arguments.session.trackingSessionId)}).n[1]); }
  private void function planStatus(required string status) { q("UPDATE floatplans SET status=:s WHERE floatPlanId=:id",{s=txt(arguments.status),id=num(f.planId)}); }
  private void function backdateStart(required struct session) { q("UPDATE companion_tracking_sessions SET started_at_utc=DATE_SUB(UTC_TIMESTAMP(3),INTERVAL 120 SECOND) WHERE id=:id",{id=num(arguments.session.trackingSessionId)}); }
  private void function setAccessSeconds(required numeric seconds) {
    q("UPDATE premium_send_credits c JOIN premium_send_receipts r ON r.credit_id=c.id SET c.consumed_at_utc=DATE_SUB(DATE_ADD(UTC_TIMESTAMP(6),INTERVAL :n SECOND),INTERVAL 21 DAY),r.access_started_at_utc=DATE_SUB(DATE_ADD(UTC_TIMESTAMP(6),INTERVAL :n SECOND),INTERVAL 21 DAY),r.access_expires_at_utc=DATE_ADD(UTC_TIMESTAMP(6),INTERVAL :n SECOND) WHERE r.float_plan_id=:p",{n=num(arguments.seconds),p=num(f.planId)});
  }
  private void function rejectPoint(required string key,required any value) {
    var s=start(); var point=sample(); point[arguments.key]=arguments.value; var r=call("batch",batch(s,[point]));
    expect(r.SUCCESS,serializeJSON(r)).toBeTrue(); expect(arrayLen(r.rejectedSamples)).toBe(1); expect(sampleCount(s)).toBe(0);
  }
  private struct function httpCall(required string action,required string method,struct payload={},string authorization="",string rawBody="",string resource="companionTracking.cfc") {
    var result={}; var address="http://127.0.0.1:8500/fpw/api/v1/"&arguments.resource&"?method=handle&returnFormat=json&action="&arguments.action;
    cfhttp(url=address,method=arguments.method,result="result",redirect=false,timeout=30) {
      if(len(arguments.authorization)) cfhttpparam(type="header",name="Authorization",value=arguments.authorization);
      if(arguments.method EQ "GET" AND structKeyExists(arguments.payload,"trackingSessionId"))
        cfhttpparam(type="url",name="trackingSessionId",value=toString(arguments.payload.trackingSessionId));
      if(arguments.method EQ "POST") {
        cfhttpparam(type="header",name="Content-Type",value="application/json");
        cfhttpparam(type="body",value=len(arguments.rawBody) ? arguments.rawBody : serializeJSON(arguments.payload));
      }
    }
    expect(isJSON(result.fileContent),left(toString(result.fileContent),500)).toBeTrue();
    return {status=val(result.statusCode),body=deserializeJSON(result.fileContent)};
  }
  private array function concurrent(required string action,required struct payload,required struct context) {
    var names=[]; var token=replace(uuid(),"-","","all");
    for(var i=1;i<=2;i++) {
      var name="tracking_"&token&"_"&i; arrayAppend(names,name);
      thread name=name action="run" trackingAction=arguments.action payload=duplicate(arguments.payload) context=duplicate(arguments.context) datasource=variables.datasource {
        thread.result=new fpw.api.v1.CompanionTrackingService().init(attributes.datasource).handle(attributes.trackingAction,attributes.context,attributes.payload);
      }
    }
    thread action="join" name=arrayToList(names) timeout=30000;
    for(var name in names) expect(structKeyExists(cfthread[name],"result"),serializeJSON(cfthread[name])).toBeTrue();
    return [cfthread[names[1]].result,cfthread[names[2]].result];
  }

  private struct function createFixture() {
    var token=replace(uuid(),"-","","all"); var item={marker="codex-tracking-"&token,userId=0,routeId=0,generatedId=0,planId=0,userDeleted=false};
    item.email=item.marker&"@example.test"; arrayAppend(variables.fixtures,item);
    q("INSERT INTO users(fName,lName,email,password,passwordCreated,created) VALUES('Tracking','Disposable',:e,:p,UTC_TIMESTAMP(),UTC_TIMESTAMP())",{e=txt(item.email),p=txt(hash(token,"SHA-256"))});
    item.userId=val(q("SELECT userId FROM users WHERE email=:e",{e=txt(item.email)}).userId[1]);
    var code="TRACK_"&left(token,24);
    q("INSERT INTO loop_routes(code,name,short_code,description) VALUES(:c,'Tracking fixture',:c,:m)",{c=txt(code),m=txt(item.marker)});
    item.generatedId=val(q("SELECT id FROM loop_routes WHERE code=:c",{c=txt(code)}).id[1]);
    q("INSERT INTO route_instances(user_id,template_route_code,generated_route_id,generated_route_code,start_location,end_location,status) VALUES(:u,'GREAT_LOOP_CCW',:g,:c,'Tracking Start','Tracking End','PLANNED')",{u=txt(item.userId),g=num(item.generatedId),c=txt(code)});
    item.routeId=val(q("SELECT id FROM route_instances WHERE user_id=:u AND generated_route_code=:c",{u=txt(item.userId),c=txt(code)}).id[1]);
    q("INSERT INTO floatplans(userId,floatPlanName,dateCreated,lastUpdate,status,lastUpdateStatus,activatedAt,initialSentAt,route_instance_id) VALUES(:u,:n,UTC_TIMESTAMP(),UTC_TIMESTAMP(),'ACTIVE',UTC_TIMESTAMP(),UTC_TIMESTAMP(),UTC_TIMESTAMP(),:r)",{u=txt(item.userId),n=txt(item.marker),r=num(item.routeId)});
    item.planId=val(q("SELECT floatPlanId FROM floatplans WHERE userId=:u AND floatPlanName=:n",{u=txt(item.userId),n=txt(item.marker)}).floatPlanId[1]);
    q("INSERT INTO premium_send_credits(user_id,source,status,consumed_float_plan_id,idempotency_key,granted_at_utc,consumed_at_utc,created_at_utc,updated_at_utc) VALUES(:u,'admin_grant','CONSUMED',:p,:k,UTC_TIMESTAMP(6),UTC_TIMESTAMP(6),UTC_TIMESTAMP(6),UTC_TIMESTAMP(6))",{u=num(item.userId),p=num(item.planId),k=txt(item.marker)});
    q("INSERT INTO premium_send_receipts(user_id,float_plan_id,credit_id,access_source,access_started_at_utc,access_expires_at_utc,recipient_count,original_response_json,committed_at_utc,created_at_utc) SELECT user_id,consumed_float_plan_id,id,'premium_send_credit',consumed_at_utc,DATE_ADD(consumed_at_utc,INTERVAL 21 DAY),1,'{}',consumed_at_utc,consumed_at_utc FROM premium_send_credits WHERE idempotency_key=:k",{k=txt(item.marker)});
    var device=createDevice(item.userId); item.deviceId=device.id; item.token=device.token;
    q("INSERT INTO floatplan_monitoring(float_plan_id,user_id,monitoring_mode,monitor_state,is_monitoring_enabled,expected_checkin_at,grace_expires_at,missed_at) VALUES(:p,:u,'active_route','MISSED',0,DATE_SUB(UTC_TIMESTAMP(),INTERVAL 2 HOUR),DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 HOUR),DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 HOUR))",{p=num(item.planId),u=num(item.userId)});
    q("INSERT INTO floatplan_companion_events(mobile_submission_id,user_id,floatplan_id,route_instance_id,event_type,canonical_status,process_status) VALUES(:k,:u,:p,:r,'CHECKIN','NEED_ATTENTION','PROCESSED')",{k=txt(item.marker),u=num(item.userId),p=num(item.planId),r=num(item.routeId)});
    q("INSERT INTO member_entitlements(user_id,entitlement_type,source,status,starts_at_utc,expires_at_utc,admin_notes) VALUES(:u,'premium','admin_grant','revoked',DATE_SUB(UTC_TIMESTAMP(),INTERVAL 2 DAY),DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 DAY),:m)",{u=num(item.userId),m=txt(item.marker)});
    q("INSERT INTO inactive_member_recovery_messages(user_id,message_kind,template_id,template_version,subject,recipient,text_body,html_body,status,prepared_at_utc) VALUES(:u,'PERSONAL',:m,'1','Tracking fixture',:e,'Fixture','Fixture','PREPARED',UTC_TIMESTAMP(6))",{u=num(item.userId),m=txt(item.marker),e=txt(item.email)});
    return item;
  }
  private struct function createDevice(required numeric userId) {
    var prefix="fpwc_"&left(replace(uuid(),"-","","all"),16); var token=prefix&"."&replace(uuid(),"-","","all");
    q("INSERT INTO companion_devices(user_id,device_uuid,device_name,platform,app_version,token_prefix,token_hash,scopes,expires_at_utc,created_utc,updated_utc) VALUES(:u,:uuid,'Tracking fixture','ios','phase1',:p,:hash,'companion:current,companion:checkin,companion:tracking',DATE_ADD(UTC_TIMESTAMP(),INTERVAL 90 DAY),UTC_TIMESTAMP(),UTC_TIMESTAMP())",{u=num(arguments.userId),uuid=txt(uuid()),p=txt(prefix),hash=txt(lcase(hash(token,"SHA-256")))});
    return {id=val(q("SELECT id FROM companion_devices WHERE token_prefix=:p",{p=txt(prefix)}).id[1]),token=token};
  }
  private string function snapshot(required struct fixture,boolean devices=false) {
    var item=arguments.fixture; var params={u=num(item.userId),ut=txt(item.userId),r=num(item.routeId)}; var data=structNew("ordered");
    var tables=[
      {name="users",where="userId=:u"},{name="floatplans",where="userId=:ut"},{name="route_instances",where="id=:r"},
      {name="route_instance_leg_progress",where="route_instance_id=:r"},{name="floatplan_monitoring",where="user_id=:u"},
      {name="floatplan_monitor_events",where="user_id=:u"},{name="floatplan_companion_events",where="user_id=:u"},
      {name="floatplan_events",where="user_id=:u"},{name="floatplan_activity_segments",where="user_id=:u"},
      {name="premium_send_receipts",where="user_id=:u"},{name="premium_send_credits",where="user_id=:u"},
      {name="member_entitlements",where="user_id=:u"},{name="inactive_member_recovery_messages",where="user_id=:u"},
      {name="product_events",where="user_id=:u"}];
    if(arguments.devices) arrayAppend(tables,{name="companion_devices",where="user_id=:u"});
    for(var table in tables) data[table.name]=hash(serializeJSON(q("SELECT * FROM "&table.name&" WHERE "&table.where&" ORDER BY 1",params)),"SHA-256");
    return serializeJSON(data);
  }
  private void function cleanupOperationalChildren(required struct fixture) {
    var params={u=num(arguments.fixture.userId)};
    for(var table in ["inactive_member_recovery_messages","product_events","floatplan_companion_events","floatplan_monitor_events","floatplan_monitoring","floatplan_events","floatplan_activity_segments","premium_send_receipts","premium_send_credits","member_entitlements","companion_pairing_codes"])
      q("DELETE FROM "&table&" WHERE user_id=:u",params);
  }
  private void function assertMaintenanceIsolated() {
    var ids=[]; for(var item in variables.fixtures) arrayAppend(ids,item.userId);
    var rows=q("SELECT COUNT(*) n FROM companion_tracking_sessions WHERE user_id NOT IN (:ids)",{ids={value=arrayToList(ids),list=true,cfsqltype="cf_sql_integer"}});
    if(val(rows.n[1]) GT 0) throw(type="FPW.TrackingFixture.MaintenanceIsolation",message="Maintenance tests refuse to touch tracking sessions outside this test's disposable fixtures.");
  }
  private void function cleanupFixtures() {
    for(var item in variables.fixtures) {
      if(item.userId LTE 0) continue;
      var identity=q("SELECT userId FROM users WHERE userId=:u AND email=:e",{u=num(item.userId),e=txt(item.email)});
      if(!identity.recordCount AND !item.userDeleted) throw(type="FPW.TrackingFixture.Scope",message="Disposable fixture identity check failed.");
      cleanupOperationalChildren(item);
      q("DELETE FROM companion_tracking_sessions WHERE user_id=:u",{u=num(item.userId)});
      q("DELETE FROM companion_devices WHERE user_id=:u",{u=num(item.userId)});
      q("DELETE FROM floatplans WHERE userId=:u",{u=txt(item.userId)});
      q("DELETE FROM route_instances WHERE id=:r",{r=num(item.routeId)});
      q("DELETE FROM loop_routes WHERE id=:id",{id=num(item.generatedId)});
      q("DELETE FROM users WHERE userId=:u AND email=:e",{u=num(item.userId),e=txt(item.email)});
    }
    variables.fixtures=[];
  }
}
