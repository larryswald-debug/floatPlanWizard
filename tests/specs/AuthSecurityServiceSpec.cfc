component extends="testbox.system.BaseSpec" output=false {
  function run() {
    describe("Shared authentication security services (no database writes)", function() {
      beforeEach(function() {
        variables.passwords = new fpw.api.v1.PasswordHashService();
        variables.guard = new fpw.api.v1.AuthRequestGuardService();
        variables.rate = new fpw.api.v1.AuthRateLimitService().init("fpw");
      });
      it("writes salted PBKDF2 and verifies only the correct password", function() {
        var first = variables.passwords.hashPassword("Disposable Test Password 42!");
        var second = variables.passwords.hashPassword("Disposable Test Password 42!");
        expect(first).notToBe(second);
        expect(variables.passwords.detectPasswordFormat(first)).toBe("ADAPTIVE");
        expect(variables.passwords.verifyPassword("Disposable Test Password 42!", first)).toBeTrue();
        expect(variables.passwords.verifyPassword("incorrect password", first)).toBeFalse();
        expect(variables.passwords.verifyPassword(first, first)).toBeFalse();
        expect(variables.passwords.needsRehash(first)).toBeFalse();
        expect(len(first) <= 255).toBeTrue();
      });
      it("preserves legacy SHA and literal compatibility until successful upgrade", function() {
        var digest = hash("Legacy Fixture Password", "SHA-256", "UTF-8");
        expect(variables.passwords.verifyPassword("Legacy Fixture Password", digest)).toBeTrue();
        expect(variables.passwords.verifyPassword("Legacy Fixture Password", lCase(digest))).toBeTrue();
        expect(variables.passwords.verifyPassword("wrong", digest)).toBeFalse();
        expect(variables.passwords.verifyPassword(digest, digest)).toBeTrue();
        expect(variables.passwords.verifyPassword("Plain Fixture", "Plain Fixture")).toBeTrue();
        expect(variables.passwords.needsRehash(digest)).toBeTrue();
        expect(variables.passwords.needsRehash("Plain Fixture")).toBeTrue();
        expect(variables.passwords.verifyPassword("", "")).toBeFalse();
      });
      it("never accepts malformed reserved PBKDF strings as literal passwords", function() {
        for (var malformed in ["$pbkdf2", "$pbkdf2-sha256$broken", "$PBKDF2-sha256$broken",
          "$pbkdf2-sha256$i=999999999,l=256$YWJjZA==$YWJjZA==",
          "$pbkdf2-sha256$i=600000,l=256$YWJjZA==$YWJjZA=="]) {
          expect(variables.passwords.verifyPassword(malformed, malformed)).toBeFalse();
        }
      });
      it("preserves password bytes in hashing and verification", function() {
        var password = "  Case Sensitive Fixture  ";
        var stored = variables.passwords.hashPassword(password);
        expect(variables.passwords.verifyPassword(password, stored)).toBeTrue();
        expect(variables.passwords.verifyPassword(trim(password), stored)).toBeFalse();
        expect(variables.passwords.verifyPassword(lCase(password), stored)).toBeFalse();
      });
      it("requires POST and a session token but permits omitted origin headers", function() {
        var token = repeatString("a",64);
        expect(variables.guard.validateRequest(method="POST",expectedOrigin="http://localhost:8500",candidate=token,expected=token).ALLOWED).toBeTrue();
        expect(variables.guard.validateRequest(method="GET",expectedOrigin="http://localhost:8500",candidate=token,expected=token).STATUSCODE).toBe(405);
        expect(variables.guard.validateRequest(method="POST",expectedOrigin="http://localhost:8500",candidate="",expected=token).CODE).toBe("CSRF_INVALID");
        expect(variables.guard.validateRequest(method="POST",expectedOrigin="http://localhost:8500",candidate=repeatString("b",64),expected=token).ALLOWED).toBeFalse();
      });
      it("rejects supplied foreign, opaque, malformed, and conflicting origins", function() {
        var token = repeatString("a",64);
        for (var origin in ["null"," ","https://evil.example","http://localhost:8501","http://localhost:8500.evil.example",
          "http://user@localhost:8500","http://localhost:8500/path","http://localhost:8500" & chr(10)]) {
          expect(variables.guard.validateRequest(method="POST",expectedOrigin="http://localhost:8500",origin=origin,candidate=token,expected=token).ALLOWED).toBeFalse();
        }
        expect(variables.guard.validateRequest(method="POST",expectedOrigin="http://localhost:8500",origin="http://localhost:8500",
          referer="https://evil.example/page",candidate=token,expected=token).ALLOWED).toBeFalse();
        expect(variables.guard.validateRequest(method="POST",expectedOrigin="http://localhost:8500",origin="http://localhost:8500",
          referer="http://localhost:8500/fpw/app/login.cfm?x=1",candidate=token,expected=token).ALLOWED).toBeTrue();
        expect(variables.guard.normalizeOrigin("https://floatplanwizard.com:443")).toBe("https://floatplanwizard.com");
      });
      it("uses stable normalized hash keys without raw subjects in bucket output", function() {
        var first = variables.rate.buildBuckets("authenticate"," Example@Test.invalid ","192.0.2.1");
        var same = variables.rate.buildBuckets("authenticate","example@test.invalid","192.0.2.1");
        expect(serializeJSON(first)).toBe(serializeJSON(same));
        expect(arrayLen(first)).toBe(3);
        expect(findNoCase("example",serializeJSON(first))).toBe(0);
        expect(find("192.0.2.1",serializeJSON(first))).toBe(0);
        expect(first[1].scope).toBe("account");
        expect(first[2].scope).toBe("ip");
        expect(first[3].scope).toBe("ip_account");
        var other = variables.rate.buildBuckets("authenticate","example@test.invalid","192.0.2.2");
        expect(first[1].subjectHash).toBe(other[1].subjectHash);
        expect(first[2].subjectHash).notToBe(other[2].subjectHash);
        expect(first[3].subjectHash).notToBe(other[3].subjectHash);
      });
      it("keeps ambiguous concatenations of valid IP and account subjects distinct", function() {
        var first = variables.rate.buildBuckets("authenticate","23@test.invalid","2001:db8::1");
        var second = variables.rate.buildBuckets("authenticate","3@test.invalid","2001:db8::12");
        expect(first[3].subjectHash).notToBe(second[3].subjectHash);
      });
      it("shares action policies across callers and supports reset prelookup IP admission", function() {
        var ipOnly = variables.rate.buildBuckets("reset_confirm","","192.0.2.1");
        var accountOnly = variables.rate.buildBuckets("reset_confirm","example@test.invalid","192.0.2.1",false);
        expect(arrayLen(ipOnly)).toBe(1);
        expect(ipOnly[1].scope).toBe("ip");
        expect(arrayLen(accountOnly)).toBe(2);
        expect(accountOnly[1].scope).toBe("account");
        expect(accountOnly[2].scope).toBe("ip_account");
        var policy = variables.rate.getPolicies();
        expect(policy.authenticate.ip.volume).toBe(100);
        expect(policy.authenticate.ip_account.failures).toBe(10);
        expect(policy.authenticate.account.failures).toBe(20);
        expect(policy.create_account.ip.volume).toBe(5);
        expect(policy.reset_request.account.volume).toBe(3);
        expect(policy.change_password.ip.seconds).toBe(3600);
        expect(policy.change_password.ip_account.seconds).toBe(900);
        expect(policy.change_password.ip_account.failures).toBe(5);
      });
      it("rejects unsupported rate actions and invalid address material", function() {
        expect(function() { variables.rate.buildBuckets("unsupported","a@test.invalid","192.0.2.1"); }).toThrow();
        expect(function() { variables.rate.buildBuckets("authenticate","a@test.invalid",""); }).toThrow();
        expect(function() { variables.rate.buildBuckets("authenticate","a@test.invalid","1.2.3.4, 5.6.7.8"); }).toThrow();
        expect(function() { variables.rate.buildBuckets("reset_confirm","","192.0.2.1",false); }).toThrow();
      });
    });
  }
}
