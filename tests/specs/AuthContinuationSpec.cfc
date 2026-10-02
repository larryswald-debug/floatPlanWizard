component extends="testbox.system.BaseSpec" output=false {
  function run() {
    describe("Authentication continuation without database writes",function() {
      beforeEach(function() {
        variables.savedSession={};
        for (var key in ["user","fpwAuthIntents","fpwAuthOverviewUserId","fpwAuthCreatedNotice"]) {
          if (structKeyExists(session,key)) variables.savedSession[key]=duplicate(session[key]);
          structDelete(session,key);
        }
        variables.hadBase=structKeyExists(request,"fpwBase");
        variables.savedBase=variables.hadBase ? request.fpwBase : "";
        request.fpwBase="/fpw";
        variables.service=new fpw.includes.AuthContinuationService();
      });
      afterEach(function() {
        for (var key in ["user","fpwAuthIntents","fpwAuthOverviewUserId","fpwAuthCreatedNotice"]) {
          structDelete(session,key);
          if (structKeyExists(variables.savedSession,key)) session[key]=variables.savedSession[key];
        }
        if (variables.hadBase) request.fpwBase=variables.savedBase;
        else structDelete(request,"fpwBase");
      });
      it("rejects unsupported targets, injected action parameters and noncanonical identifiers",function() {
        for (var destination in ["https://evil.example","//evil.example","Planner","delete","send"]) {
          expect(function() { variables.service.createIntent(destination); }).toThrow();
        }
        for (var context in [{returnUrl="https://evil.example"},{recoveryAction="plans"},{routeId=1}]) {
          expect(function() { variables.service.createIntent("planner",context); }).toThrow();
        }
        for (var id in ["01","0","2147483648","1,2"]) {
          expect(function() { variables.service.createIntent("route",{routeId=id}); }).toThrow();
        }
        expect(function() { variables.service.createIntent("account",{routeId=1}); }).toThrow();
      });
      it("keeps separate opaque per-tab goals and binds every pending goal after login",function() {
        var first=variables.service.createIntent("planner");
        var second=variables.service.createIntent("account");
        expect(first.token).notToBe(second.token);
        expect(reFind("^[a-f0-9]{64}$",first.token)).toBe(1);
        variables.service.bindMember(123);
        expect(variables.service.getIntent(first.token,123).destinationKey).toBe("planner");
        expect(variables.service.getIntent(second.token,123).destinationKey).toBe("account");
        expect(structIsEmpty(variables.service.getIntent(first.token,456))).toBeTrue();
        expect(structIsEmpty(variables.service.getIntent(first.token))).toBeTrue();
      });
      it("clears previous-member goals and notices on a member change",function() {
        var first=variables.service.createIntent("planner");
        variables.service.bindMember(123);
        variables.service.markAccountCreated(123,"fixture@example.invalid");
        variables.service.bindMember(456);
        expect(structIsEmpty(variables.service.getIntent(first.token,123))).toBeTrue();
        expect(variables.service.needsOverview(123)).toBeFalse();
        expect(variables.service.takeCreatedNotice(123)).toBe("");
      });
      it("expires goals and evicts oldest unused entries at the eight-entry bound",function() {
        var old=variables.service.createIntent("planner");
        session.fpwAuthIntents[old.token].createdAt=dateAdd("n",-1,now());
        for (var n=1;n LTE 8;n++) variables.service.createIntent("account");
        expect(structCount(session.fpwAuthIntents)).toBe(8);
        expect(structIsEmpty(variables.service.getIntent(old.token))).toBeTrue();
        var current=variables.service.createIntent("dashboard");
        session.fpwAuthIntents[current.token].expiresAt=dateAdd("s",-1,now());
        expect(structIsEmpty(variables.service.getIntent(current.token))).toBeTrue();
      });
      it("routes new accounts to overview without consuming their original goal",function() {
        var entry=variables.service.createIntent("account");
        variables.service.bindMember(123);
        variables.service.markAccountCreated(123,"fixture@example.invalid");
        var created=variables.service.resolve(entry.token,123,true);
        expect(created.redirectUrl).toBe("/fpw/app/dashboard.cfm?authIntent=" & entry.token);
        expect(variables.service.needsOverview(123)).toBeTrue();
        expect(variables.service.takeCreatedNotice(123)).toBe("fixture@example.invalid");
        expect(variables.service.takeCreatedNotice(123)).toBe("");
        expect(structIsEmpty(variables.service.getIntent(entry.token,123))).toBeFalse();
        variables.service.acknowledgeOverview(123);
        expect(variables.service.needsOverview(123)).toBeFalse();
        var reloaded=variables.service.resolve(entry.token,123);
        expect(reloaded.waitForContinue).toBeTrue();
        expect(reloaded.redirectUrl).toBe("/fpw/app/dashboard.cfm?authIntent=" & entry.token);
        expect(variables.service.allowContinuation(entry.token,456)).toBeFalse();
        expect(variables.service.allowContinuation(entry.token,123)).toBeTrue();
        expect(variables.service.resolve(entry.token,123).waitForContinue).toBeFalse();
        expect(variables.service.resolve(entry.token,123).redirectUrl).toBe("/fpw/app/account.cfm?authIntent=" & entry.token);
      });
      it("delegates planner actions and consumes only explicit acknowledgement",function() {
        var entry=variables.service.createIntent("planner",{},{
          source_page="great_loop_trip_planning",section="after_planning_guide",cta_type="plan_trip",
          email="private@example.invalid",returnUrl="https://evil.example"
        });
        var resolved=variables.service.resolve(entry.token,123);
        expect(resolved.recovery.action).toBe("planner");
        expect(structCount(resolved.source)).toBe(3);
        expect(variables.service.discard(entry.token,456)).toBeFalse();
        expect(variables.service.discard(entry.token,123)).toBeTrue();
        expect(variables.service.discard(entry.token,123)).toBeFalse();
      });
      it("ignores a valid-shaped token missing from this session",function() {
        expect(structIsEmpty(variables.service.getIntent(repeatString("a",64),123))).toBeTrue();
        expect(structIsEmpty(variables.service.resolve(repeatString("a",64),123))).toBeTrue();
      });
    });
  }
}
