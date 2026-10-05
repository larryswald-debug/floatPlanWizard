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

        var manualUrl = "http://localhost:8500/fpw/app/user-manual.cfm";
        var manualCopy = "The FloatPlanWizard User Manual walks you through the app step by step, from adding your boat and planning a trip to creating a Float Plan, checking in while underway, and completing your trip.";
        expect(message.subject).toBe("Welcome to FloatPlanWizard.com");
        expect(findNoCase(manualCopy, message.htmlBody)).toBeGT(0);
        expect(findNoCase(manualCopy, message.textBody)).toBeGT(0);
        expect(findNoCase('href="' & encodeForHtmlAttribute(manualUrl) & '"', message.htmlBody)).toBeGT(0);
        expect(findNoCase(">Open the User Manual</a>", message.htmlBody)).toBeGT(0);
        expect(findNoCase("Open the User Manual" & chr(10) & manualUrl, message.textBody)).toBeGT(0);
        for (var body in [message.htmlBody, message.textBody]) {
          var dashboardPosition = findNoCase("Go to Your Dashboard", body);
          var manualPosition = findNoCase("New to FloatPlanWizard?", body);
          var feedbackPosition = findNoCase("During this launch/beta period", body);
          expect(dashboardPosition).toBeGT(0);
          expect(manualPosition).toBeGT(dashboardPosition);
          expect(feedbackPosition).toBeGT(manualPosition);
        }
        expect(findNoCase("/unsubscribe.cfm?t=", message.textBody)).toBeGT(0);
        expect(findNoCase("You may opt out of non-essential emails here", message.textBody)).toBeGT(0);
        expect(findNoCase("You are receiving this email because", message.textBody)).toBe(0);
        expect(findNoCase("unsubscribe.cfm", message.htmlBody)).toBeGT(0);
      });

      it("uses the configured public base for welcome manual links at root and subdirectory mounts", function() {
        for (var publicBase in ["https://welcome.example.test", "https://welcome.example.test/fpw/"]) {
          var config = testEmailConfig();
          var emailService = prepareMock(createObject("component", "fpw.api.v1.email").init());
          var expectedUrl = reReplace(publicBase, "/+$", "", "all") & "/app/user-manual.cfm";
          config.publicBaseUrl = publicBase;
          config.dashboardUrl = reReplace(publicBase, "/+$", "", "all") & "/app/dashboard.cfm";
          emailService.$("getEmailConfig", config);
          emailService.$("buildWelcomeMemberOptOutUrl", "https://welcome.example.test/unsubscribe.cfm?t=test-disabled");
          makePublic(emailService, "buildWelcomeMemberEmail", "buildWelcomeMemberEmailForTest");

          var message = emailService.buildWelcomeMemberEmailForTest(
            userId = 1, toEmail = "welcome@example.test", firstName = "Taylor"
          );

          expect(findNoCase('href="' & encodeForHtmlAttribute(expectedUrl) & '"', message.htmlBody)).toBeGT(0);
          expect(findNoCase("Open the User Manual" & chr(10) & expectedUrl, message.textBody)).toBeGT(0);
          expect(findNoCase("localhost", message.htmlBody)).toBe(0);
          expect(findNoCase("localhost", message.textBody)).toBe(0);
        }
      });

      it("preserves the reviewed captain completed-trip fallback link and escaped content", function() {
        var service = prepareMock(new fpw.api.v1.email());
        service.$("getEmailConfig", testEmailConfig());
        makePublic(service, "buildSafeArrivalCaptainEmail", "captainForTest");
        var message = service.captainForTest(
          recipientName = "<Captain>", floatPlanId = 42, tripName = "<Safe Trip>",
          vesselName = "Boat & Crew", departureLocation = "Port A", destination = "Port B",
          completionLabel = "October 5, 2026 12:00 PM", completionTimezone = "America/New_York",
          completedTripPath = "/fpw/app/completed-trip.cfm?id=42"
        );
        var escapedUrl = encodeForHtmlAttribute(message.ctaUrl);
        expect(message.subject).toBe("Your FloatPlanWizard trip is complete");
        expect(message.ctaUrl).toBe("http://localhost:8500/fpw/app/completed-trip.cfm?id=42");
        expect(arrayLen(reMatch(">View Completed Trip</a>", message.htmlBody))).toBe(1);
        var completedHref = 'href="' & escapedUrl & '"';
        expect((len(message.htmlBody) - len(replace(message.htmlBody,completedHref,"","all"))) / len(completedHref)).toBe(2);
        expect(message.htmlBody).toInclude("If the button doesn't work, copy and paste this link into your browser:");
        expect(message.htmlBody).toInclude(">" & encodeForHtml(message.ctaUrl) & "</a>");
        expect(message.htmlBody).toInclude(encodeForHtml("<Captain>"));
        expect(message.htmlBody).toInclude(encodeForHtml("<Safe Trip>"));
        expect(message.htmlBody).notToInclude("<Captain>");
        expect(message.textBody).toInclude("View Completed Trip:" & chr(10) & message.ctaUrl);
        expect(message.textBody).toInclude("completed safely and closed");
        expect(message.textBody).notToInclude("If the button doesn't work");
      });

      it("submits security and operational messages despite a real optional-email opt-out", function() {
        var fixture = createUserFixture("operational-opted-out");
        var preference = new fpw.api.v1.EmailOptOutService(datasource=variables.datasource);
        expect(preference.recordOptOut(fixture.email,fixture.userId,"non_essential","compliance_test").success).toBeTrue();
        var service = prepareMock(new fpw.api.v1.email());
        service.$("getEmailConfig", testEmailConfig());
        service.$("sendMultipartEmail");
        expect(service.checkNonEssentialEmailEligibility(fixture.email,fixture.userId).code).toBe("OPTED_OUT");
        var reset = service.sendPasswordResetEmail(
          userId=fixture.userId,toEmail=fixture.email,resetUrl="http://localhost:8500/fpw/app/reset-password.cfm?t=test-only"
        );
        var departure = service.sendDepartureReminderEmail(
          userId=fixture.userId,toEmail=fixture.email,floatPlanId=42,floatPlanName="Operational Trip",
          scheduledDepartureLabel="October 5, 2026 12:00 PM",departureTimezone="America/New_York",reminderType="PRE_DEPARTURE"
        );
        var captain = service.sendSafeArrivalCaptainEmail(
          userId=fixture.userId,toEmail=fixture.email,floatPlanId=42,tripName="Operational Trip",
          completionLabel="October 5, 2026 12:00 PM",completionTimezone="America/New_York",
          completedTripPath="/fpw/app/completed-trip.cfm?id=42"
        );
        var pdfPath = getTempDirectory() & "codex-optional-operational-" & createUUID() & ".pdf";
        var basic = {};
        try {
          fileWrite(pdfPath, "%PDF-1.4 TEST-ONLY FAKE TRANSPORT ATTACHMENT", "utf-8");
          basic = service.sendBasicReviewFloatPlanEmail(
            userId=fixture.userId,toEmail=fixture.email,contactName="Fixture Contact",
            floatPlanName="Operational Trip",captainName="Fixture Captain",senderName="Fixture Member",pdfPath=pdfPath
          );
          expect(reset.success).toBeTrue();
          expect(departure.success).toBeTrue();
          expect(captain.success).toBeTrue();
          expect(basic.success).toBeTrue();
          expect(service.$count("sendMultipartEmail")).toBe(4);
          var calls = service.$callLog().sendMultipartEmail;
          for (var call in calls) expect(call.toEmail).toBe(fixture.email);
          expect(calls[1].textBody).toInclude("reset");
          expect(calls[2].spoolEnable).toBeFalse();
          expect(calls[3].spoolEnable).toBeFalse();
          expect(calls[4].attachmentPath).toBe(pdfPath);
          expect(calls[4].textBody).toInclude("Basic Send");
          expect(preference.isOptedOut(fixture.email,"non_essential")).toBeTrue();
        } finally {
          if (fileExists(pdfPath)) fileDelete(pdfPath);
        }
      });

      it("keeps opted-out recipients in Basic, Premium, and safety recipient selection", function() {
        var owner = createUserFixture("recipient-owner");
        var contact = createUserFixture("recipient-contact");
        var preference = new fpw.api.v1.EmailOptOutService(datasource=variables.datasource);
        expect(preference.recordOptOut(owner.email,owner.userId,"non_essential","compliance_test").success).toBeTrue();
        expect(preference.recordOptOut(contact.email,contact.userId,"non_essential","compliance_test").success).toBeTrue();
        var inserted = {};
        var planId = 0;
        var contactId = 0;
        try {
          queryExecute("INSERT INTO floatplans(userId,floatPlanName,status,dateCreated,lastUpdate)
            VALUES(:owner,'Optional Preference Regression','DRAFT',UTC_TIMESTAMP(),UTC_TIMESTAMP())",
            {owner={value=owner.userId,cfsqltype="cf_sql_integer"}},
            {datasource=variables.datasource,result="inserted"});
          planId=val(inserted.generatedKey);
          queryExecute("INSERT INTO contacts(name,phone,userId,email) VALUES('Fixture Contact','5550100000',:owner,:email)",
            {owner={value=owner.userId,cfsqltype="cf_sql_integer"},email={value=contact.email,cfsqltype="cf_sql_varchar"}},
            {datasource=variables.datasource,result="inserted"});
          contactId=val(inserted.generatedKey);
          queryExecute("INSERT INTO floatplan_contacts(contactId,floatPlanId) VALUES(:contact,:plan)",
            {contact={value=contactId,cfsqltype="cf_sql_integer"},plan={value=planId,cfsqltype="cf_sql_integer"}},
            {datasource=variables.datasource});
          queryExecute("INSERT INTO floatplan_basic_details(floatplan_id,vessel_name,operator_name,captain_name,captain_email,
            notification_contact_name,notification_contact_email,launch_location,destination_location,
            authority_name_snapshot,authority_phone_snapshot)
            VALUES(:plan,'Fixture Boat','Fixture Operator','Fixture Captain',:ownerEmail,'Fixture Contact',:email,'Port A','Port B','Fixture Authority','5550100001')",
            {plan={value=planId,cfsqltype="cf_sql_integer"},ownerEmail={value=owner.email,cfsqltype="cf_sql_varchar"},
              email={value=contact.email,cfsqltype="cf_sql_varchar"}},{datasource=variables.datasource});
          var controller = new fpw.api.v1.floatplan();
          makePublic(controller,"loadBasicPlanContactEmails","basicRecipientsForTest");
          makePublic(controller,"loadPlanContactEmails","premiumRecipientsForTest");
          var basicRecipients=controller.basicRecipientsForTest(planId);
          var premiumRecipients=controller.premiumRecipientsForTest(owner.userId,planId);
          expect(arrayLen(basicRecipients)).toBe(1);
          expect(basicRecipients[1].EMAIL).toBe(contact.email);
          expect(arrayLen(premiumRecipients)).toBe(1);
          expect(premiumRecipients[1].EMAIL).toBe(contact.email);
          var safety = new fpw.api.v1.OverdueAlertService();
          makePublic(safety,"loadFloatPlanAlertContext","contextForTest");
          makePublic(safety,"getOwnerAlertEmails","ownersForTest");
          makePublic(safety,"getSelectedContactEmails","contactsForTest");
          var context=safety.contextForTest(planId);
          expect(safety.ownersForTest(context)).toBe([owner.email]);
          expect(safety.contactsForTest(context)).toBe([contact.email]);
          expect(preference.isOptedOut(owner.email,"non_essential")).toBeTrue();
          expect(preference.isOptedOut(contact.email,"non_essential")).toBeTrue();
        } finally {
          if (planId GT 0) {
            var planParams={id={value=planId,cfsqltype="cf_sql_integer"}};
            queryExecute("DELETE FROM floatplan_contacts WHERE floatPlanId=:id",planParams,{datasource=variables.datasource});
            queryExecute("DELETE FROM floatplan_basic_details WHERE floatplan_id=:id",planParams,{datasource=variables.datasource});
            queryExecute("DELETE FROM floatplans WHERE floatPlanId=:id",planParams,{datasource=variables.datasource});
          }
          if (contactId GT 0) queryExecute("DELETE FROM contacts WHERE contactId=:id",
            {id={value=contactId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
        }
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
