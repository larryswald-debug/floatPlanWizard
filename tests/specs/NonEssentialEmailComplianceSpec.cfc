component extends="testbox.system.BaseSpec" output="false" {

  variables.datasource = "fpw";
  variables.fixturePrefix = "codex-nonessential-email-";

  function beforeAll() {
    cleanupFixtures();
  }

  function afterAll() {
    cleanupFixtures();
  }

  function run() {
    describe("Non-essential email compliance contract", function() {

      beforeEach(function() {
        cleanupFixtures();
      });

      afterEach(function() {
        cleanupFixtures();
      });

      it("returns ELIGIBLE with an environment-aware signed unsubscribe URL", function() {
        var fixture = createUserFixture("eligible");
        var emailService = createObject("component", "fpw.api.v1.email").init();
        var result = emailService.checkNonEssentialEmailEligibility(
          email = fixture.email,
          userId = fixture.userId
        );

        expect(result.eligible).toBeTrue();
        expect(result.code).toBe("ELIGIBLE");
        expect(findNoCase("http://localhost:8500/fpw/unsubscribe.cfm?t=", result.unsubscribeUrl)).toBe(1);
        expect(findNoCase(fixture.email, result.unsubscribeUrl)).toBe(0);
        expect(structKeyExists(result, "email")).toBeFalse();
      });

      it("suppresses invalid recipients and existing non-essential opt-outs", function() {
        var fixture = createUserFixture("opted-out");
        var emailService = createObject("component", "fpw.api.v1.email").init();
        var optOutService = createObject("component", "fpw.api.v1.EmailOptOutService").init(
          datasource = variables.datasource,
          publicBaseUrl = "http://localhost:8500/fpw"
        );
        var recordResult = optOutService.recordOptOut(
          email = fixture.email,
          userId = fixture.userId,
          optOutType = "non_essential",
          source = "compliance_test"
        );
        var optedOutResult = emailService.checkNonEssentialEmailEligibility(
          email = fixture.email,
          userId = fixture.userId
        );
        var invalidResult = emailService.checkNonEssentialEmailEligibility(
          email = "not-an-email",
          userId = 0
        );

        expect(recordResult.SUCCESS).toBeTrue();
        expect(optedOutResult.eligible).toBeFalse();
        expect(optedOutResult.code).toBe("OPTED_OUT");
        expect(optedOutResult.unsubscribeUrl).toBe("");
        expect(invalidResult.eligible).toBeFalse();
        expect(invalidResult.code).toBe("INVALID_EMAIL");
        expect(invalidResult.unsubscribeUrl).toBe("");
      });

      it("fails closed with separate safe codes for preference and URL failures", function() {
        var emailService = createObject("component", "fpw.api.v1.email").init();
        var preferenceFailure = createObject("component", "fpw.api.v1.EmailOptOutService").init(
          datasource = "fpw_nonessential_preference_failure",
          publicBaseUrl = "http://localhost:8500/fpw"
        );
        var urlFailure = createObject("component", "fpw.api.v1.EmailOptOutService").init(
          datasource = variables.datasource,
          configPath = getTempDirectory() & "missing-nonessential-config-" & createUUID() & ".json",
          publicBaseUrl = "http://localhost:8500/fpw"
        );
        var preferenceResult = emailService.checkNonEssentialEmailEligibility(
          email = "recipient@example.test",
          optOutService = preferenceFailure
        );
        var urlResult = emailService.checkNonEssentialEmailEligibility(
          email = "recipient@example.test",
          optOutService = urlFailure
        );

        expect(preferenceResult.eligible).toBeFalse();
        expect(preferenceResult.code).toBe("PREFERENCE_LOOKUP_FAILED");
        expect(preferenceResult.unsubscribeUrl).toBe("");
        expect(urlResult.eligible).toBeFalse();
        expect(urlResult.code).toBe("UNSUBSCRIBE_URL_FAILED");
        expect(urlResult.unsubscribeUrl).toBe("");
      });

      it("validates and processes signed links while rejecting tampering", function() {
        var fixture = createUserFixture("signed-link");
        var optOutService = createObject("component", "fpw.api.v1.EmailOptOutService").init(
          datasource = variables.datasource,
          publicBaseUrl = "http://localhost:8500/fpw"
        );
        var urlValue = optOutService.buildOptOutUrl(
          email = fixture.email,
          userId = fixture.userId,
          optOutType = "non_essential"
        );
        var tokenValue = extractToken(urlValue);
        var tamperedToken = left(tokenValue, len(tokenValue) - 1)
          & (right(tokenValue, 1) == "a" ? "b" : "a");
        var validResult = optOutService.validateSignedOptOutToken(tokenValue);
        var tamperedResult = optOutService.processOptOutToken(tamperedToken);
        var processResult = optOutService.processOptOutToken(
          token = tokenValue,
          source = "compliance_test"
        );

        expect(validResult.SUCCESS).toBeTrue();
        expect(validResult.userId).toBe(fixture.userId);
        expect(validResult.optOutType).toBe("non_essential");
        expect(tamperedResult.SUCCESS).toBeFalse();
        expect(tamperedResult.errorCode).toBe("OPTOUT_TOKEN_INVALID");
        expect(processResult.SUCCESS).toBeTrue();
        expect(isOptedOut(fixture.email)).toBeTrue();
      });

      it("renders distinct signed unsubscribe and preference links in HTML and text", function() {
        var eligibility = {
          eligible = true,
          code = "ELIGIBLE",
          unsubscribeUrl = "http://localhost:8500/fpw/unsubscribe.cfm?t=payload."
            & repeatString("a", 64)
        };
        var emailService = prepareMock(createObject("component", "fpw.api.v1.email").init());
        var footer = {};
        emailService.$("getEmailConfig", testEmailConfig());
        emailService.$("getConfiguredBusinessMailingAddress", "TEST-ONLY BUSINESS MAILING ADDRESS");

        footer = emailService.buildNonEssentialEmailComplianceFooter(eligibility);

        expect(findNoCase(eligibility.unsubscribeUrl, footer.textBody)).toBeGT(0);
        expect(findNoCase(encodeForHtmlAttribute(eligibility.unsubscribeUrl), footer.htmlBody)).toBeGT(0);
        expect(findNoCase(
          encodeForHtmlAttribute("http://localhost:8500/fpw/app/account.cfm##email-preferences"),
          footer.htmlBody
        )).toBeGT(0);
        expect(findNoCase("TEST-ONLY BUSINESS MAILING ADDRESS", footer.htmlBody)).toBeGT(0);
        expect(findNoCase("TEST-ONLY BUSINESS MAILING ADDRESS", footer.textBody)).toBeGT(0);
        expect(findNoCase('href="http://localhost:8500/fpw/unsubscribe.cfm"', footer.htmlBody)).toBe(0);
        expect(eligibility.unsubscribeUrl).notToBe("http://localhost:8500/fpw/app/account.cfm##email-preferences");
      });

      it("refuses non-essential footer rendering without eligibility or address configuration", function() {
        var validEligibility = {
          eligible = true,
          code = "ELIGIBLE",
          unsubscribeUrl = "http://localhost:8500/fpw/unsubscribe.cfm?t=payload."
            & repeatString("a", 64)
        };
        var ineligible = duplicate(validEligibility);
        var emailService = prepareMock(createObject("component", "fpw.api.v1.email").init());
        var missingAddressService = prepareMock(createObject("component", "fpw.api.v1.email").init());
        var ineligibleType = "";
        var addressType = "";
        ineligible.eligible = false;
        ineligible.code = "OPTED_OUT";
        emailService.$("getEmailConfig", testEmailConfig());
        emailService.$("getConfiguredBusinessMailingAddress", "TEST-ONLY BUSINESS MAILING ADDRESS");
        missingAddressService.$("getEmailConfig", testEmailConfig());
        missingAddressService.$("getConfiguredBusinessMailingAddress", "");

        try {
          emailService.buildNonEssentialEmailComplianceFooter(ineligible);
        } catch (any err) {
          ineligibleType = err.type;
        }
        try {
          missingAddressService.buildNonEssentialEmailComplianceFooter(validEligibility);
        } catch (any err) {
          addressType = err.type;
        }

        expect(ineligibleType).toBe("email.NonEssentialRecipientIneligible");
        expect(addressType).toBe("email.BusinessMailingAddressRequired");
      });

      it("preserves the existing signed welcome service footer without reclassification", function() {
        var fixture = createUserFixture("welcome-output");
        var emailService = createObject("component", "fpw.api.v1.email").init();
        var message = {};
        makePublic(emailService, "buildWelcomeMemberEmail", "buildWelcomeMemberEmailForTest");

        message = emailService.buildWelcomeMemberEmailForTest(
          userId = fixture.userId,
          toEmail = fixture.email,
          firstName = "Compliance",
          dashboardUrl = "http://localhost:8500/fpw/app/dashboard.cfm"
        );

        expect(findNoCase("/unsubscribe.cfm?t=", message.textBody)).toBeGT(0);
        expect(findNoCase("You may opt out of non-essential emails here", message.textBody)).toBeGT(0);
        expect(findNoCase("You are receiving this email because", message.textBody)).toBe(0);
        expect(findNoCase("unsubscribe.cfm", message.htmlBody)).toBeGT(0);
      });

      it("preserves the operational builders and keeps diagnostics token-free", function() {
        var currentSource = readRepoFile("api/v1/email.cfc");
        var baseline = deserializeJSON(readRepoFile(
          "tests/fixtures/operational-email-function-sha256.json"
        ));
        var operationalFunctions = [
          "sendPasswordResetEmail",
          "sendDepartureReminderEmail",
          "sendSafeArrivalCaptainEmail",
          "sendSafeArrivalShoreContactEmail",
          "buildPasswordResetEmail",
          "buildDepartureReminderEmail",
          "buildSafeArrivalCaptainEmail",
          "buildSafeArrivalShoreContactEmail"
        ];
        var functionName = "";
        var functionSource = "";
        var helperSource = extractFunction(currentSource, "checkNonEssentialEmailEligibility");

        expect(structCount(baseline.functions)).toBe(arrayLen(operationalFunctions));
        expect(len(helperSource)).toBeGT(0);
        for (functionName in operationalFunctions) {
          functionSource = extractFunction(currentSource, functionName);
          expect(len(functionSource)).toBeGT(0);
          expect(lCase(hash(functionSource, "SHA-256", "UTF-8"))).toBe(
            baseline.functions[functionName]
          );
        }

        expect(findNoCase("cflog", helperSource)).toBe(0);
        expect(findNoCase("sendMultipartEmail", helperSource)).toBe(0);
        expect(findNoCase("sendInactive", currentSource)).toBe(0);
        expect(findNoCase("recovery email", helperSource)).toBe(0);
      });
    });
  }

  private struct function createUserFixture(required string suffix) {
    var token = lCase(replace(createUUID(), "-", "", "all"));
    var email = left(variables.fixturePrefix & suffix & "-" & token & "@example.test", 255);
    var insertResult = {};

    queryExecute(
      "INSERT INTO users (fName, lName, email, password, passwordCreated, created)
       VALUES ('Compliance', 'Fixture', :email, :passwordValue, UTC_TIMESTAMP(), UTC_TIMESTAMP())",
      {
        email = { value = email, cfsqltype = "cf_sql_varchar" },
        passwordValue = { value = hash(token, "SHA-256"), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource, result = "insertResult" }
    );

    return { userId = val(insertResult.generatedKey), email = email };
  }

  private boolean function isOptedOut(required string email) {
    var result = queryExecute(
      "SELECT COUNT(*) AS row_count
       FROM email_optout
       WHERE email = :email
         AND opt_out_type = 'non_essential'",
      { email = { value = lCase(trim(arguments.email)), cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );
    return val(result.row_count[1]) GT 0;
  }

  private string function extractToken(required string urlValue) {
    return urlDecode(listLast(arguments.urlValue, "="));
  }

  private struct function testEmailConfig() {
    return {
      fromDisplayName = "FloatPlanWizard",
      fromEmail = "info@floatplanwizard.com",
      fromValue = "FloatPlanWizard <info@floatplanwizard.com>",
      replyToEmail = "info@floatplanwizard.com",
      publicBaseUrl = "http://localhost:8500/fpw",
      dashboardUrl = "http://localhost:8500/fpw/app/dashboard.cfm",
      emailPreferencesUrl = "http://localhost:8500/fpw/app/account.cfm##email-preferences"
    };
  }

  private string function readRepoFile(required string relativePath) {
    var specDirectory = replace(getDirectoryFromPath(getCurrentTemplatePath()), "\\", "/", "all");
    var repoRoot = reReplace(specDirectory, "/tests/specs/?$", "/", "one");
    return fileRead(repoRoot & arguments.relativePath, "utf-8");
  }

  private string function extractFunction(required string source, required string functionName) {
    var pattern = '(?is)<cffunction\b[^>]*\bname="'
      & arguments.functionName
      & '"[^>]*>.*?</cffunction>';
    var normalizedSource = replace(arguments.source, chr(13) & chr(10), chr(10), "all");
    var match = reFind(pattern, normalizedSource, 1, true);
    if (!match.len[1]) {
      return "";
    }
    return mid(normalizedSource, match.pos[1], match.len[1]);
  }

  private void function cleanupFixtures() {
    var pattern = variables.fixturePrefix & "%";
    queryExecute(
      "DELETE FROM email_optout WHERE email LIKE :pattern",
      { pattern = { value = pattern, cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM users WHERE email LIKE :pattern",
      { pattern = { value = pattern, cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );
  }
}
