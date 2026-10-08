component extends="testbox.system.BaseSpec" output="false" {
  function run() {
    describe("Canonical email public origin and rendering",function() {
      it("uses canonical HTTPS in production and unknown environments regardless of dev override",function() {
        for(var env in ["production","prod",""]) {
          var mail=prepareMock(new fpw.api.v1.email());
          mail.$("getPublicUrlSettings",{environment=env,developmentBaseUrl="http://localhost:9123/other"});
          mail.$("resolveFpwBasePath","");
          expect(mail.getPublicBaseUrl()).toBe("https://floatplanwizard.com");
        }
      });
      it("keeps development mount handling and permits an explicit loopback base",function() {
        var mail=prepareMock(new fpw.api.v1.email());
        mail.$("resolveFpwBasePath","/fpw");
        mail.$("getPublicUrlSettings",{environment="dev",developmentBaseUrl=""});
        expect(mail.getPublicBaseUrl()).toBe("http://localhost:8500/fpw");
        mail.$("getPublicUrlSettings",{environment="development",developmentBaseUrl="http://127.0.0.1:8500/local/"});
        expect(mail.getPublicBaseUrl()).toBe("http://127.0.0.1:8500/local");
        mail.$("resolveFpwBasePath","");
        mail.$("getPublicUrlSettings",{environment="local",developmentBaseUrl=""});
        expect(mail.getPublicBaseUrl()).toBe("http://localhost:8500");
      });
      it("rejects external and malformed development origin overrides",function() {
        for(var invalid in ["https://evil.example","http://localhost.evil.example","http://localhost:8500/fpw?next=bad","http://user@localhost:8500/fpw"]) {
          var mail=prepareMock(new fpw.api.v1.email());
          mail.$("getPublicUrlSettings",{environment="dev",developmentBaseUrl=invalid});
          expect(function(){mail.getPublicBaseUrl();}).toThrow("email.InvalidDevelopmentPublicBaseUrl");
        }
      });
      it("uses the shared resolver in the real password reset URL builder and preserves token encoding",function() {
        var reset=prepareMock(new fpw.api.v1.password_reset());
        makePublic(reset,"buildPasswordResetUrl","testResetUrl");
        var base=new fpw.api.v1.email().getPublicBaseUrl();
        expect(reset.testResetUrl("test-only+token/=")).toBe(base & "/app/reset-password.cfm?token=" & encodeForURL("test-only+token/="));
        var source=fileRead(expandPath("/fpw/api/v1/password_reset.cfc"),"utf-8");
        expect(source).toInclude("emailService.getPublicBaseUrl()");
        expect(source).notToInclude("cgi.http_host");
        expect(source).notToInclude("http_x_forwarded_proto");
      });
      it("renders twenty shared variants and both retained early-access implementations without SMTP",function() {
        for(var env in ["production","development"]) {
          var captured=new fpw.tests.support.EmailReliabilityCapture().capture(env,env EQ "production" ? "" : "/fpw");
          expect(arrayLen(captured.messages)).toBe(21);
          expect(arrayLen(captured.earlyAccessCopies)).toBe(2);
          for(var message in captured.messages) {
            expect(reFindNoCase("@floatplanwizard\.com>?$",message.from)).toBeGT(0);
            if(len(message.replyTo)) expect(reFindNoCase("@floatplanwizard\.com$",message.replyTo)).toBeGT(0);
            expect(len(message.subject)).toBeGT(0);
            expect(len(message.textBody)).toBeGT(0);
          }
          expect(captured.emailPreferencesUrl).toBe(captured.publicBaseUrl & "/app/account.cfm?section=email-preferences##email-preferences");
        }
      });
      it("rejects noncanonical absolute links and preserves valid raw query and fragment values",function() {
        var mail=prepareMock(new fpw.api.v1.email());
        mail.$("getPublicUrlSettings",{environment="production",developmentBaseUrl=""});
        mail.$("resolveFpwBasePath","");
        mail.$("sendMultipartEmail");
        makePublic(mail,"resolveAbsolutePublicUrl","testAbsolute");
        makePublic(mail,"normalizeDashboardUrl","testDashboard");
        var base="https://floatplanwizard.com";
        var raw=base & "/app/completed-trip.cfm?id=42&view=full##summary";
        expect(mail.testAbsolute(raw)).toBe(raw);
        expect(mail.testAbsolute("/app/completed-trip.cfm?id=42&view=full##summary")).toBe(raw);
        for(var bad in ["https://evil.example/app/completed-trip.cfm?id=42","http://localhost:8500/app/completed-trip.cfm?id=42","https://floatplanwizard.com.evil.example/app/completed-trip.cfm?id=42","https://floatplanwizard.com@evil.example/app/completed-trip.cfm?id=42","http://floatplanwizard.com/app/completed-trip.cfm?id=42"]) {
          expect(function(){mail.testAbsolute(bad);}).toThrow("email.InvalidPublicUrl");
          expect(mail.testDashboard(bad,base & "/app/dashboard.cfm")).toBe(base & "/app/dashboard.cfm");
          expect(mail.sendPasswordResetEmail(userId=1,toEmail="capture@example.test",resetUrl=bad).errorCode).toBe("INVALID_RESET_LINK");
        }
        expect(mail.$count("sendMultipartEmail")).toBe(0);
        mail.$("getPublicUrlSettings",{environment="dev",developmentBaseUrl="http://localhost:8500/fpw"});
        expect(function(){mail.testAbsolute("http://localhost:8500/fpwevil/app/completed-trip.cfm?id=42");}).toThrow("email.InvalidPublicUrl");
        expect(mail.testAbsolute("http://localhost:8500/fpw/app/completed-trip.cfm?id=42")).toBe("http://localhost:8500/fpw/app/completed-trip.cfm?id=42");
      });
      it("retains the approved sender and SMTP attributes at the shared transport boundary",function() {
        var source=fileRead(expandPath("/fpw/api/v1/email.cfc"),"utf-8");
        expect(source).toInclude("from = config.fromValue");
        expect(source).toInclude("mailAttrs.replyto = config.replyToEmail");
        expect(source).toInclude('type="text/plain"');
        expect(source).toInclude('type="text/html"');
        expect(source).notToInclude("http_x_forwarded_proto");
        expect(source).notToInclude("cgi.http_host");
      });
    });
  }
}
