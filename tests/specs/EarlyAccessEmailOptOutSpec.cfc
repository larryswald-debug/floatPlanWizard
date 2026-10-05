component extends="testbox.system.BaseSpec" output="false" {
  variables.fixturePrefix = "codex-earlyaccess-optout-";
  variables.handlers = ["index.cfm", "assets/admin/index.cfm"];

  function beforeAll() {
    cleanupFixtures();
  }

  function afterAll() {
    cleanupFixtures();
  }

  function run() {
    describe("Retained early-access optional email", function() {
      afterEach(function() {
        cleanupFixtures();
      });

      for (var handlerPath in variables.handlers) {
        defineHandlerSuite(handlerPath);
      }
    });
  }

  private void function defineHandlerSuite(required string handlerPath) {
    // Each closure captures one path; both templates contain an independent retained helper.
    var sourcePath = arguments.handlerPath;
    describe(sourcePath, function() {

          it("submits an eligible message with a valid signed link and suppresses a later opt-out", function() {
            var handler = loadHandler(sourcePath);
            var recipient = createRecipient();
            var service = createObject("component", "fpw.api.v1.email").init();
            var preferences = createObject("component", "fpw.api.v1.EmailOptOutService").init();
            var transport = createObject("component", "fpw.tests.support.EarlyAccessMailTransportStub");
            var first = handler.send(
              recipientEmail = "  " & uCase(recipient) & "  ",
              mailConfig = handler.config,
              emailService = service,
              mailTransport = transport
            );
            var messages = transport.getMessages();
            expect(first.sent).toBeTrue();
            expect(arrayLen(messages)).toBe(1);
            expect(messages[1].mailAttributes.to).toBe(recipient);
            expect(messages[1].mailAttributes.subject).toBe("Thanks for joining the FloatPlanWizard launch list");
            expect(find("email=", messages[1].body)).toBe(0);
            var links = reMatch("https?://[^\s]+/unsubscribe\.cfm\?t=[^\s]+", messages[1].body);
            expect(arrayLen(links)).toBe(1);
            var token = urlDecode(listLast(links[1], "="));
            var validated = preferences.validateSignedOptOutToken(token);
            expect(validated.success).toBeTrue();
            expect(validated.optOutType).toBe("non_essential");

            var optedOut = preferences.processOptOutToken(token, "early_access_test");
            expect(optedOut.success).toBeTrue();
            var second = handler.send(
              recipientEmail = recipient,
              mailConfig = handler.config,
              emailService = service,
              mailTransport = transport
            );
            expect(second.sent).toBeFalse();
            expect(second.code).toBe("OPTED_OUT");
            expect(arrayLen(transport.getMessages())).toBe(1);
            // No signup record was involved: this proves send-time suppression, not duplicate-signup skipping.
            var signups = queryExecute("SELECT COUNT(*) AS n FROM fpw_early_access WHERE email = :email",
              {email={value=recipient,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
            expect(val(signups.n[1])).toBe(0);
          });

          it("fails closed when canonical eligibility is unavailable or cannot issue a signed link", function() {
            var handler = loadHandler(sourcePath);
            var transport = createObject("component", "fpw.tests.support.EarlyAccessMailTransportStub");
            for (var reason in ["PREFERENCE_LOOKUP_FAILED", "UNSUBSCRIBE_URL_FAILED"]) {
              var service = prepareMock(createObject("component", "fpw.api.v1.email").init());
              service.$("checkNonEssentialEmailEligibility", {eligible=false,code=reason,unsubscribeUrl=""});
              var result = handler.send(createRecipient(), handler.config, service, transport);
              expect(result.sent).toBeFalse();
              expect(result.code).toBe(reason);
            }
            expect(arrayLen(transport.getMessages())).toBe(0);
          });

          it("fails closed if the eligibility dependency throws", function() {
            var handler = loadHandler(sourcePath);
            var service = prepareMock(createObject("component", "fpw.api.v1.email").init());
            var transport = createObject("component", "fpw.tests.support.EarlyAccessMailTransportStub");
            service.$("checkNonEssentialEmailEligibility").$throws(
              type="tests.EarlyAccessPreferenceFailure",message="CONTROLLED_PREFERENCE_FAILURE");
            var result = handler.send(createRecipient(), handler.config, service, transport);
            expect(result.sent).toBeFalse();
            expect(result.code).toBe("PREFERENCE_LOOKUP_FAILED");
            expect(arrayLen(transport.getMessages())).toBe(0);
          });

          it("rejects invalid addresses through the canonical service without transport", function() {
            var handler = loadHandler(sourcePath);
            var service = createObject("component", "fpw.api.v1.email").init();
            var transport = createObject("component", "fpw.tests.support.EarlyAccessMailTransportStub");
            var result = handler.send("not-an-email", handler.config, service, transport);
            expect(result.sent).toBeFalse();
            expect(result.code).toBe("INVALID_EMAIL");
            expect(arrayLen(transport.getMessages())).toBe(0);
          });
    });
  }

  private struct function loadHandler(required string handlerPath) {
    if (!arrayFind(variables.handlers, arguments.handlerPath)) {
      throw(type="tests.UnknownEarlyAccessHandler",message="Unknown retained handler.");
    }
    if (uCase(cgi.request_method) NEQ "GET") {
      throw(type="tests.EarlyAccessRunnerMethod",message="Helper integration requires GET.");
    }
    // A fresh component scope avoids duplicate template UDF declarations between tests.
    return createObject("component", "fpw.tests.support.EarlyAccessHandlerHarness").load(arguments.handlerPath);
  }

  private string function createRecipient() {
    return variables.fixturePrefix & lCase(replace(createUUID(), "-", "", "all")) & "@example.test";
  }

  private void function cleanupFixtures() {
    queryExecute("DELETE FROM email_optout WHERE email LIKE :pattern",
      {pattern={value=variables.fixturePrefix & "%",cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
  }
}
