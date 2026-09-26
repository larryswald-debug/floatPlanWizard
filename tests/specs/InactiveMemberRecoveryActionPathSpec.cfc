component extends="testbox.system.BaseSpec" output="false" {
  function run() {
    describe("Inactive-member recovery action paths", function() {
      beforeEach(function() {
        variables.paths = new fpw.includes.InactiveMemberRecoveryActionPathService();
      });

      it("builds each action without an object id at root and subfolder mounts", function() {
        for (var action in ["vessel", "planner", "routes", "plans"]) {
          expect(variables.paths.buildPath("", {recoveryAction=action})).toBe("/app/dashboard.cfm?recoveryAction=" & action);
          expect(variables.paths.buildPath("/fpw", {recoveryAction=action})).toBe("/fpw/app/dashboard.cfm?recoveryAction=" & action);
        }
      });
      it("builds each supported owned-object identifier", function() {
        expect(variables.paths.buildPath("/fpw", {recoveryAction="route", routeId="12"})).toBe("/fpw/app/dashboard.cfm?recoveryAction=route&routeId=12");
        expect(variables.paths.buildPath("/fpw", {recoveryAction="route", routeInstanceId=34})).toBe("/fpw/app/dashboard.cfm?recoveryAction=route&routeInstanceId=34");
        expect(variables.paths.buildPath("/fpw", {recoveryAction="draft", floatPlanId=56})).toBe("/fpw/app/dashboard.cfm?recoveryAction=draft&floatPlanId=56");
      });
      it("requires canonical action values", function() {
        for (var action in ["", "Vessel", "vessel ", "vessel,planner", "../vessel", "https://evil.example"]) {
          expect(variables.paths.buildPath("/fpw", {recoveryAction=action})).toBe("");
        }
        expect(variables.paths.buildPath("/fpw", {})).toBe("");
        expect(variables.paths.buildPath("/fpw", {recoveryAction=["vessel"]})).toBe("");
      });
      it("rejects unknown fields and return URLs", function() {
        for (var key in ["returnUrl", "returnTo", "redirect", "utm_source", "anything"]) {
          var values = {recoveryAction="vessel"};
          values[key] = "https://evil.example";
          expect(variables.paths.buildPath("/fpw", values)).toBe("");
        }
      });
      it("rejects IDs on actions without objects", function() {
        for (var action in ["vessel", "planner", "routes", "plans"]) {
          expect(variables.paths.buildPath("/fpw", {recoveryAction=action, routeId=1})).toBe("");
          expect(variables.paths.buildPath("/fpw", {recoveryAction=action, floatPlanId=1})).toBe("");
        }
      });
      it("requires exactly one appropriate object ID", function() {
        expect(variables.paths.buildPath("/fpw", {recoveryAction="route"})).toBe("");
        expect(variables.paths.buildPath("/fpw", {recoveryAction="route", routeId=1, routeInstanceId=2})).toBe("");
        expect(variables.paths.buildPath("/fpw", {recoveryAction="route", routeId=1, floatPlanId=2})).toBe("");
        expect(variables.paths.buildPath("/fpw", {recoveryAction="draft"})).toBe("");
        expect(variables.paths.buildPath("/fpw", {recoveryAction="draft", routeId=1})).toBe("");
        expect(variables.paths.buildPath("/fpw", {recoveryAction="draft", floatPlanId=1, routeInstanceId=2})).toBe("");
      });
      it("rejects noncanonical, duplicate, and out-of-range IDs", function() {
        for (var id in ["0", "-1", "01", "1.0", "1e2", "+1", " 1", "1 ", "1,2", "2147483648", "99999999999", "1" & chr(10), "1" & chr(13), "%31"]) {
          expect(variables.paths.buildPath("/fpw", {recoveryAction="route", routeId=id})).toBe("");
          expect(variables.paths.buildPath("/fpw", {recoveryAction="draft", floatPlanId=id})).toBe("");
        }
      });
      it("rejects complex ID values and accepts the maximum signed INT", function() {
        expect(variables.paths.buildPath("/fpw", {recoveryAction="route", routeId=[1]})).toBe("");
        expect(variables.paths.buildPath("/fpw", {recoveryAction="draft", floatPlanId={id=1}})).toBe("");
        expect(variables.paths.buildPath("/fpw", {recoveryAction="draft", floatPlanId="2147483647"})).toBe("/fpw/app/dashboard.cfm?recoveryAction=draft&floatPlanId=2147483647");
      });
      it("rejects unsafe or noncanonical base paths", function() {
        for (var base in ["https://evil.example", "//evil.example", "/", "/fpw/", "/fpw/..", "/fpw//x", "/fpw?x=1", "/fpw" & chr(10)]) {
          expect(variables.paths.buildPath(base, {recoveryAction="vessel"})).toBe("");
        }
        expect(variables.paths.buildPath("/apps/fpw-dev", {recoveryAction="vessel"})).toBe("/apps/fpw-dev/app/dashboard.cfm?recoveryAction=vessel");
      });
      it("validates canonical paths using the same builder contract", function() {
        for (var values in [
          {recoveryAction="vessel"}, {recoveryAction="planner"}, {recoveryAction="routes"}, {recoveryAction="plans"},
          {recoveryAction="route", routeId=12}, {recoveryAction="route", routeInstanceId=34},
          {recoveryAction="draft", floatPlanId=56}
        ]) {
          for (var base in ["", "/fpw"]) {
            var path = variables.paths.buildPath(base, values);
            expect(variables.paths.validatePath(path, base)).toBe(path);
          }
        }
      });
      it("rejects absolute, protocol-relative, foreign-page, traversal, and fragment paths", function() {
        for (var path in [
          "https://evil.example/app/dashboard.cfm?recoveryAction=vessel",
          "http://localhost:8500/fpw/app/dashboard.cfm?recoveryAction=vessel",
          "//evil.example/app/dashboard.cfm?recoveryAction=vessel",
          "/app/login.cfm?recoveryAction=vessel",
          "/app/../app/dashboard.cfm?recoveryAction=vessel",
          "/app/dashboard.cfm?recoveryAction=vessel##x",
          "/fpw/app/dashboard.cfm?recoveryAction=vessel"
        ]) expect(variables.paths.validatePath(path)).toBe("");
      });
      it("rejects duplicate, encoded, reordered, empty, or unsupported query parts", function() {
        for (var query in [
          "", "recoveryAction=vessel&", "recoveryAction=vessel&&", "recoveryAction=vessel&returnUrl=https://evil.example",
          "recoveryAction=vessel&recoveryAction=planner", "recoveryAction=route&routeId=1&routeId=1",
          "recoveryAction=draft&floatPlanId=1&floatplanid=1",
          "recoveryAction=route&routeId=1&routeInstanceId=2", "routeId=1&recoveryAction=route",
          "recoveryaction=vessel", "recoveryAction=%76essel", "recoveryAction=route&routeId=%31",
          "recoveryAction=route&routeId=1=2", "recoveryAction=route&routeId=01"
        ]) expect(variables.paths.validatePath("/app/dashboard.cfm?" & query)).toBe("");
      });
    });
  }
}
