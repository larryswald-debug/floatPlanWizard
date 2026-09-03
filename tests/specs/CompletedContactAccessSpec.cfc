component extends="testbox.system.BaseSpec" output="false" {
  function run() {
    describe("Token-authorized completed-contact capability", function() {
      beforeEach(function() {
        variables.fixtures = [];
        variables.support = new fpw.tests.support.CompletedContactFixture();
        variables.voyage = new fpw.api.v1.voyage();
        makePublic(variables.voyage, "getStreamBootstrap", "bootstrapForTest");
        makePublic(variables.voyage, "readStream", "readStreamForTest");
        makePublic(variables.voyage, "canReadStream", "canReadForTest");
        makePublic(variables.voyage, "getCompletedContactBootstrap", "completedForTest");
        makePublic(variables.voyage, "listPosts", "postsForTest");
        makePublic(variables.voyage, "ownerCreatePost", "postForTest");
        makePublic(variables.voyage, "followerIdentify", "identifyForTest");
        makePublic(variables.voyage, "prepareFollowFloatPlanPdfDownload", "pdfForTest");
      });
      afterEach(function() {
        for (var f in variables.fixtures) variables.support.cleanup(f);
      });

      it("returns only the six approved fields for a membership-origin completed trip", function() {
        var f = fixture();
        var before = variables.support.snapshot(f);
        var result = bootstrap(f);
        expect(result.SUCCESS).toBeTrue();
        expect(result.view_mode).toBe("completed_read_only");
        expect(listSort(structKeyList(result), "textnocase")).toBe("completed_trip,SUCCESS,view_mode");
        expect(listSort(structKeyList(result.completed_trip), "textnocase")).toBe(
          "completed_at_local,completed_at_utc,completion_timezone,destination,trip_name,vessel_name");
        expect(result.completed_trip.trip_name).toBe(f.marker);
        expect(result.completed_trip.vessel_name).toBe("Contact Test Vessel");
        expect(result.completed_trip.destination).toBe("Test Anchorage");
        expect(result.completed_trip.completion_timezone).toBe("America/New_York");
        expect(variables.support.snapshot(f)).toBe(before);
        expect(new fpw.api.v1.PremiumTripAccessService().init("fpw").getTripOperationalAccess(f.userId,f.planId,false).allowed).toBeFalse();
      });

      it("accepts a completed complimentary-credit trip without restoring its access", function() {
        var f = fixture("premium_send_credit");
        expect(bootstrap(f).SUCCESS).toBeTrue();
        expect(new fpw.api.v1.PremiumTripAccessService().init("fpw").getTripOperationalAccess(f.userId,f.planId,false).reasonCode).toBe("TRIP_ACCESS_ENDED");
      });

      it("keeps a completed link usable after the original membership naturally expires", function() {
        var f = variables.support.create("general_premium", dateAdd("s", 3, now()));
        arrayAppend(variables.fixtures, f);
        variables.support.completeForContractTest(f);
        sleep(3500);
        expect(new fpw.api.v1.MemberEntitlementService().init("fpw").getCurrentAccess(f.userId).hasPremium).toBeFalse();
        expect(bootstrap(f).SUCCESS).toBeTrue();
      });

      it("rejects explicit revocation of the originating entitlement", function() {
        var f = fixture();
        var result = new fpw.api.v1.AdminMemberEntitlementService().init("fpw").revokeEntitlement(
          f.entitlementId, "Disposable completed contact regression", "REVOKE ENTITLEMENT " & f.entitlementId,
          { userId=f.userId, email=f.email });
        expect(result.SUCCESS).toBeTrue();
        expect(bootstrap(f).SUCCESS).toBeFalse();
      });

      it("requires the explicit share token even for an owner or a public stream", function() {
        var f = fixture();
        expect(variables.voyage.bootstrapForTest(f.slug,"",f.streamId,f.userId).SUCCESS).toBeFalse();
        sql("UPDATE voyage_streams SET privacy_mode='public' WHERE id=:id", { id=f.streamId });
        expect(variables.voyage.bootstrapForTest(f.slug,"",f.streamId,0).SUCCESS).toBeFalse();
        expect(variables.voyage.bootstrapForTest(f.slug,repeatString("f",64),f.streamId,0).SUCCESS).toBeFalse();
        expect(bootstrap(f).SUCCESS).toBeTrue();
      });

      it("rejects tampered, wrong-trip and mixed slug/stream identifiers", function() {
        var a = fixture();
        var b = fixture();
        expect(variables.voyage.bootstrapForTest(a.slug,repeatString("f",64),0,0).SUCCESS).toBeFalse();
        expect(variables.voyage.bootstrapForTest(b.slug,a.token,0,0).SUCCESS).toBeFalse();
        expect(variables.voyage.bootstrapForTest(a.slug,b.token,b.streamId,0).SUCCESS).toBeFalse();
        expect(variables.voyage.bootstrapForTest(a.slug,a.token,b.streamId,0).SUCCESS).toBeFalse();
      });

      it("rejects raw malformed identifiers and conflicting aliases that coercion could conceal", function() {
        var f = fixture();
        for (var raw in ["garbage", "-1", "1.5", f.streamId & "junk"]) {
          expect(variables.voyage.bootstrapForTest(f.slug,f.token,f.streamId,0,{body={stream_id=raw}}).SUCCESS).toBeFalse();
        }
        expect(variables.voyage.bootstrapForTest(f.slug,f.token,f.streamId,0,{body={route_slug="other-trip"}}).SUCCESS).toBeFalse();
        expect(variables.voyage.bootstrapForTest(f.slug,f.token,f.streamId,0,{body={token="other-token"}}).SUCCESS).toBeFalse();
      });

      it("rejects removed or rotated tokens and deleted streams", function() {
        var f = fixture();
        sql("UPDATE voyage_streams SET share_token=:token WHERE id=:id", { token=hash(createUUID(),"SHA-256"),id=f.streamId });
        expect(bootstrap(f).SUCCESS).toBeFalse();
        sql("DELETE FROM voyage_streams WHERE id=:id", {id=f.streamId});
        expect(bootstrap(f).SUCCESS).toBeFalse();
      });

      it("does not treat cancellation, administrative closure or other ended states as completion", function() {
        var f = fixture();
        for (var status in ["CANCELLED","CANCELED","ABANDONED","FAILED","DRAFT"]) {
          sql("UPDATE floatplans SET status=:status WHERE floatPlanId=:id", {status=status,id=f.planId});
          expect(bootstrap(f).SUCCESS).toBeFalse();
        }
        sql("UPDATE floatplans SET status='ADMIN_CLOSED' WHERE floatPlanId=:id", {id=f.planId});
        expect(bootstrap(f).SUCCESS).toBeFalse();
      });

      it("rejects expired plans and receipts ended for a non-completion reason", function() {
        var f = fixture("premium_send_credit");
        sql("UPDATE premium_send_receipts SET access_end_reason='SINGLE_TRIP_LIMIT' WHERE float_plan_id=:id", {id=f.planId});
        expect(bootstrap(f).SUCCESS).toBeFalse();
        sql("UPDATE floatplans SET status='EXPIRED',expiredAt=UTC_TIMESTAMP(),end_reason='SINGLE_TRIP_LIMIT' WHERE floatPlanId=:id", {id=f.planId});
        expect(bootstrap(f).SUCCESS).toBeFalse();
      });

      it("rejects incomplete routes and missing canonical completion timestamps", function() {
        var f = fixture();
        sql("UPDATE route_instances SET status='ACTIVE' WHERE id=:id", {id=f.routeId});
        expect(bootstrap(f).SUCCESS).toBeFalse();
        sql("UPDATE route_instances SET status='COMPLETED',completed_at=NULL WHERE id=:id", {id=f.routeId});
        expect(bootstrap(f).SUCCESS).toBeFalse();
        sql("UPDATE route_instances SET completed_at=UTC_TIMESTAMP() WHERE id=:id", {id=f.routeId});
        sql("UPDATE floatplans SET closedAt=NULL WHERE floatPlanId=:id", {id=f.planId});
        expect(bootstrap(f).SUCCESS).toBeFalse();
      });

      it("rejects missing receipts and inconsistent route ownership", function() {
        var f = fixture();
        var other = fixture();
        sql("UPDATE route_instances SET user_id=:owner WHERE id=:id", {owner=other.userId,id=f.routeId});
        expect(bootstrap(f).SUCCESS).toBeFalse();
        sql("UPDATE route_instances SET user_id=:owner WHERE id=:id", {owner=f.userId,id=f.routeId});
        sql("DELETE FROM premium_send_receipts WHERE float_plan_id=:id", {id=f.planId});
        expect(bootstrap(f).SUCCESS).toBeFalse();
      });

      it("never exposes another owner's vessel and uses canonical route completion time", function() {
        var f = fixture();
        var other = fixture();
        sql("UPDATE floatplans SET vesselId=:vessel,closedAt='2026-09-03 16:05:00' WHERE floatPlanId=:id", {vessel=other.vesselId,id=f.planId});
        sql("UPDATE route_instances SET completed_at='2026-09-03 16:00:00' WHERE id=:id", {id=f.routeId});
        var trip = bootstrap(f).completed_trip;
        expect(trip.vessel_name).toBe("");
        expect(trip.completed_at_utc).toBe("2026-09-03T16:00:00Z");
        expect(trip.completed_at_local).toBe("Sep 3, 2026 12:00 PM");
      });

      it("does not provide this capability to an active trip", function() {
        var f = variables.support.create();
        arrayAppend(variables.fixtures, f);
        var row = variables.voyage.readStreamForTest(f.slug,0);
        expect(structCount(variables.voyage.completedForTest(row,f.slug,f.token,f.streamId))).toBe(0);
        expect(new fpw.api.v1.PremiumTripAccessService().init("fpw").getTripOperationalAccess(f.userId,f.planId,false).allowed).toBeTrue();
      });

      it("preserves active invite, public and owner token behavior", function() {
        var f = variables.support.create();
        arrayAppend(variables.fixtures, f);
        var row = variables.voyage.readStreamForTest(f.slug,0);
        expect(variables.voyage.canReadForTest(row,f.token,false).allowed).toBeTrue();
        expect(variables.voyage.canReadForTest(row,"invalid",false).allowed).toBeFalse();
        expect(variables.voyage.canReadForTest(row,"",false).allowed).toBeFalse();
        expect(variables.voyage.canReadForTest(row,"",true).allowed).toBeTrue();
        row.privacy_mode="public";
        expect(variables.voyage.canReadForTest(row,"",false).allowed).toBeTrue();
      });

      it("keeps posts, follower registration, owner writes and PDF behind operational gates", function() {
        var f = fixture();
        var before = variables.support.snapshot(f);
        expect(variables.voyage.postsForTest(f.streamId,0,20,f.token,"",0).SUCCESS).toBeFalse();
        expect(variables.voyage.identifyForTest(f.streamId,f.token,"Contact",f.contactEmail,"").SUCCESS).toBeFalse();
        expect(variables.voyage.postForTest(f.streamId,"must not write","",f.userId).SUCCESS).toBeFalse();
        expect(variables.voyage.pdfForTest(f.slug,f.token,f.streamId,0).SUCCESS).toBeFalse();
        expect(variables.support.snapshot(f)).toBe(before);
      });

      it("keeps the arrival email URL contract and captain authentication unchanged", function() {
        var f = fixture();
        var mail = new fpw.tests.support.SafeArrivalEmailStub().init();
        var service = new fpw.api.v1.SafeArrivalNotificationService().init("fpw",mail,
          new fpw.api.v1.CompletedTripViewModelService().init("fpw"));
        request.fpwBase = "/fpw";
        expect(service.processCompletedTrip(f.userId,f.planId).SUCCESS).toBeTrue();
        var shore = {};
        for (var message in mail.getCalls()) if (message.role EQ "SHORE") shore=message;
        expect(findNoCase("/app/follow.cfm?slug=",shore.followPath)).toBeGT(0);
        expect(findNoCase(urlEncodedFormat(f.token),shore.followPath)).toBeGT(0);
        expect(bootstrap(f).SUCCESS).toBeTrue();
        expect(findNoCase('require_auth.cfm',fileRead(expandPath('/fpw/app/completed-trip.cfm')))).toBeGT(0);
      });
    });
  }
  private struct function fixture(string source="general_premium") {
    var f=variables.support.create(arguments.source);
    arrayAppend(variables.fixtures,f);
    variables.support.completeForContractTest(f);
    return f;
  }
  private struct function bootstrap(required struct f) {
    return variables.voyage.bootstrapForTest(f.slug,f.token,0,0);
  }
  private any function sql(required string statement, struct params={}) {
    return queryExecute(arguments.statement,arguments.params,{datasource="fpw"});
  }
}
