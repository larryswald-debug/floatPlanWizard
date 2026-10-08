component extends="testbox.system.BaseSpec" output="false" {

  variables.datasource = "fpw";
  variables.fixturePrefix = "codex-recovery-email-template-";
  variables.dashboardUrl = "http://localhost:8500/fpw/app/dashboard.cfm";

  function beforeAll() {
    cleanupFixtures();
  }

  function afterAll() {
    cleanupFixtures();
  }

  function run() {
    describe("Inactive-member recovery email templates", function() {
      afterEach(function() { cleanupFixtures(); });

      it("renders all twelve approved contact and destination combinations independently", function() {
        var context = createEligibleContext("contact-matrix");
        var cases = [
          {contact=1,stage="A",subject="Add your boat to FloatPlanWizard",body="Your FloatPlanWizard account is ready. Add your vessel details once and FPW can reuse them when you plan future trips and create Float Plans."},
          {contact=1,stage="B",subject="Ready to plan your first trip?",body="Your vessel is saved in FloatPlanWizard. When you're ready, use Trip Planner to map a route, add stops, and estimate your trip."},
          {contact=1,stage="C",subject="Pick up your trip planning",body="You've started saving trip-planning work in FloatPlanWizard. You can come back anytime to continue the route and turn it into a trip when you're ready."},
          {contact=1,stage="D",subject="Your Float Plan is waiting",body="You've started a Float Plan in FloatPlanWizard. Come back when you're ready to finish the details and share the trip with someone ashore."},
          {contact=2,stage="A",subject="Pick up your vessel setup",body="If adding your boat is still on your list, you can continue whenever you're ready. Save its details once so you can reuse them when planning trips and creating Float Plans."},
          {contact=2,stage="B",subject="Still planning your next trip?",body="Your vessel details are already saved. When you're ready to take the next step, Trip Planner can help you map a route, add stops, and estimate the trip."},
          {contact=2,stage="C",subject="Continue the route you started",body="Still working on your trip? Return to your saved planning work, review the route, and continue toward a Float Plan when you're ready."},
          {contact=2,stage="D",subject="Ready to finish your Float Plan?",body="If your Float Plan still needs a few details, you can pick it up whenever you're ready. Review the trip and share it with someone ashore when it's complete."},
          {contact=3,stage="A",subject="One last reminder to add your boat",body="One last automated reminder from FloatPlanWizard: add your boat whenever you're ready, and reuse its details for future trips and Float Plans."},
          {contact=3,stage="B",subject="One last reminder to plan your trip",body="One last automated reminder from FloatPlanWizard: your vessel details are saved, and Trip Planner is available whenever you're ready to map your next trip."},
          {contact=3,stage="C",subject="One last trip-planning reminder",body="One last automated reminder from FloatPlanWizard: return to your saved planning work whenever you're ready to continue your route."},
          {contact=3,stage="D",subject="One last Float Plan reminder",body="One last automated reminder from FloatPlanWizard: return to your Float Plan whenever you're ready to finish the details and share it with someone ashore."}
        ];
        for (var item in cases) {
          var message = context.service.buildInactiveMemberRecoveryEmail(stage=item.stage,contactNumber=item.contact,eligibility=context.eligibility);
          expect(message.success).toBeTrue();
          expect(message.subject).toBe(item.subject);
          expect(memberText(message)).toInclude(item.body);
          expect(message.contactNumber).toBe(item.contact);
          expect(message.destinationStage).toBe(item.stage);
          expect(message.templateId).toBe("recovery.contact_" & item.contact & ".destination_" & item.stage & ".v1");
          expect(message.templateVersion).toBe("v1");
          expect(message.destinationUrl).toBe(message.ctaUrl);
        }
      });

      it("rejects invalid contact numbers without renderable content", function() {
        var context = createEligibleContext("bad-contact");
        for (var contact in [0,4,-1,1.5]) {
          var message = context.service.buildInactiveMemberRecoveryEmail(stage="A",contactNumber=contact,eligibility=context.eligibility);
          expect(message.success).toBeFalse();
          expect(message.errorCode).toBe("INVALID_RECOVERY_CONTACT");
          expect(message.subject & message.htmlBody & message.textBody).toBe("");
        }
      });

      it("accepts only canonical recovery tracking endpoints and retains the destination", function() {
        var context = createEligibleContext("tracking");
        var token = repeatString("a",64) & "." & repeatString("b",64);
        var tracking = {clickUrl="http://localhost:8500/fpw/app/recovery-click.cfm?t=" & token,
          openUrl="http://localhost:8500/fpw/app/recovery-open.cfm?t=" & token};
        var message = context.service.buildInactiveMemberRecoveryEmail(stage="C",contactNumber=2,eligibility=context.eligibility,tracking=tracking);
        expect(message.success).toBeTrue();
        expect(message.ctaUrl).toBe(tracking.clickUrl);
        expect(message.destinationUrl).toBe(variables.dashboardUrl & "?recoveryAction=routes");
        expect(message.htmlBody).toInclude(encodeForHtmlAttribute(tracking.openUrl));
        expect(message.textBody).notToInclude(tracking.openUrl);
        for (var invalid in ["https://evil.example/app/recovery-click.cfm?t=" & token,
          "http://localhost:8500/fpw/app/recovery-open.cfm?t=" & token,
          tracking.clickUrl & "&next=https://evil.example"]) {
          expect(context.service.buildInactiveMemberRecoveryEmail(stage="A",eligibility=context.eligibility,tracking={clickUrl=invalid}).success).toBeFalse();
        }
      });

      it("escapes personal follow-up text and rejects header injection and failed compliance", function() {
        var context = createEligibleContext("personal");
        var body = "<script>alert(1)</script>" & chr(10) & "Your next step";
        var message = context.service.buildRecoveryPersonalEmail(eligibility=context.eligibility,subject="A personal follow-up",body=body);
        expect(message.success).toBeTrue(message.errorCode);
        expect(message.messageType).toBe("RECOVERY_PERSONAL");
        expect(message.htmlBody).notToInclude("<script>alert(1)</script>");
        expect(message.htmlBody).toInclude(encodeForHtml("<script>alert(1)</script>"));
        expect(message.textBody).toInclude(body);
        expect(message.textBody).toInclude(context.eligibility.unsubscribeUrl);
        expect(context.service.buildRecoveryPersonalEmail(eligibility=context.eligibility,subject="Hello" & chr(10) & "Bcc: bad@example.test",body="Text").success).toBeFalse();
        expect(context.service.buildRecoveryPersonalEmail(eligibility={},subject="Hello",body="Text").success).toBeFalse();
        expect(context.service.submitRecoveryPersonalEmail(toEmail=context.email,message={success=true,messageType="INACTIVE_MEMBER_RECOVERY"}).CODE).toBe("INVALID_PERSONAL_MESSAGE");
      });

      it("renders the exact Stage A vessel setup message", function() {
        var context = createEligibleContext("a");
        var message = context.service.buildInactiveMemberRecoveryEmail(
          stage="A", eligibility=context.eligibility
        );

        expect(message.success).toBeTrue();
        expect(message.subject).toBe("Add your boat to FloatPlanWizard");
        expect(memberText(message)).toInclude("Your FloatPlanWizard account is ready. Add your vessel details once and FPW can reuse them when you plan future trips and create Float Plans.");
        expect(message.ctaLabel).toBe("Continue Vessel Setup");
        expect(message.ctaUrl).toBe(variables.dashboardUrl & "?recoveryAction=vessel");
        expect(memberText(message)).notToInclude("haven't done anything");
        expect(memberText(message)).notToInclude("account is incomplete");
      });

      it("renders the exact Stage B Trip Planner message", function() {
        var context = createEligibleContext("b");
        var message = context.service.buildInactiveMemberRecoveryEmail(
          stage="B", eligibility=context.eligibility
        );

        expect(message.subject).toBe("Ready to plan your first trip?");
        expect(memberText(message)).toInclude("Your vessel is saved in FloatPlanWizard. When you're ready, use Trip Planner to map a route, add stops, and estimate your trip.");
        expect(message.ctaLabel).toBe("Start Planning a Trip");
        expect(message.ctaUrl).toBe(variables.dashboardUrl & "?recoveryAction=planner");
        expect(memberText(message)).notToInclude("route is saved");
      });

      it("renders the exact Stage C saved-planning message without completion claims", function() {
        var context = createEligibleContext("c");
        var message = context.service.buildInactiveMemberRecoveryEmail(
          stage="C", eligibility=context.eligibility
        );

        expect(message.subject).toBe("Pick up your trip planning");
        expect(memberText(message)).toInclude("You've started saving trip-planning work in FloatPlanWizard. You can come back anytime to continue the route and turn it into a trip when you're ready.");
        expect(message.ctaLabel).toBe("Continue Trip Planning");
        expect(message.ctaUrl).toBe(variables.dashboardUrl & "?recoveryAction=routes");
        expect(memberText(message)).notToInclude("route is finished");
        expect(memberText(message)).notToInclude("Float Plan is ready");
      });

      it("renders the exact Stage D Draft message with plans fallback", function() {
        var context = createEligibleContext("d-fallback");
        var message = context.service.buildInactiveMemberRecoveryEmail(
          stage="D", eligibility=context.eligibility
        );

        expect(message.subject).toBe("Your Float Plan is waiting");
        expect(memberText(message)).toInclude("You've started a Float Plan in FloatPlanWizard. Come back when you're ready to finish the details and share the trip with someone ashore.");
        expect(message.ctaLabel).toBe("Continue Your Float Plan");
        expect(message.ctaUrl).toBe(variables.dashboardUrl & "?recoveryAction=plans");
        expect(memberText(message)).notToInclude("ready to send");
        expect(memberText(message)).notToInclude("has been shared");
        expect(memberText(message)).notToInclude("Monitoring is active");
      });

      it("uses only an explicitly supplied same-origin verified Draft URL", function() {
        var context = createEligibleContext("d-verified");
        var draftUrl = "http://localhost:8500/fpw/app/dashboard.cfm?recoveryAction=draft&floatPlanId=123";
        var message = context.service.buildInactiveMemberRecoveryEmail(
          stage="D",
          eligibility=context.eligibility,
          verifiedDraftUrl=draftUrl
        );

        expect(message.success).toBeTrue();
        expect(message.ctaUrl).toBe(draftUrl);
        expect(message.textBody).toInclude(draftUrl);
        expect(message.htmlBody).toInclude(encodeForHtmlAttribute(draftUrl));
      });

      it("resolves canonical relative owned route and Draft destinations in both message bodies", function() {
        var context = createEligibleContext("relative-actions");
        var cases = [
          {stage="C",path="/app/dashboard.cfm?recoveryAction=route&routeId=321"},
          {stage="C",path="/app/dashboard.cfm?recoveryAction=route&routeInstanceId=654"},
          {stage="D",path="/app/dashboard.cfm?recoveryAction=draft&floatPlanId=123"}
        ];
        for (var item in cases) {
          var args = {stage=item.stage,eligibility=context.eligibility};
          args[item.stage EQ "C" ? "verifiedRouteUrl" : "verifiedDraftUrl"] = item.path;
          var message = context.service.buildInactiveMemberRecoveryEmail(argumentCollection=args);
          var expected = "http://localhost:8500/fpw" & item.path;
          expect(message.success).toBeTrue();
          expect(message.ctaUrl).toBe(expected);
          expect(message.textBody).toInclude(expected);
          expect(message.htmlBody).toInclude(encodeForHtmlAttribute(expected));
        }
      });

      it("rejects supplied action URLs that do not belong to the selected stage", function() {
        var context = createEligibleContext("wrong-action");
        var route = context.service.buildInactiveMemberRecoveryEmail(
          stage="C",eligibility=context.eligibility,
          verifiedRouteUrl="/app/dashboard.cfm?recoveryAction=draft&floatPlanId=123"
        );
        var draft = context.service.buildInactiveMemberRecoveryEmail(
          stage="D",eligibility=context.eligibility,
          verifiedDraftUrl="/app/dashboard.cfm?recoveryAction=route&routeId=123"
        );
        expect(route.success).toBeFalse();
        expect(route.subject & route.htmlBody & route.textBody & route.ctaUrl).toBe("");
        expect(draft.success).toBeFalse();
        expect(draft.subject & draft.htmlBody & draft.textBody & draft.ctaUrl).toBe("");
      });

      it("rejects an unknown stage and an invalid verified Draft URL without send-ready content", function() {
        var context = createEligibleContext("invalid-input");
        var invalidStage = context.service.buildInactiveMemberRecoveryEmail(
          stage="E", eligibility=context.eligibility
        );
        var invalidDraft = context.service.buildInactiveMemberRecoveryEmail(
          stage="D",
          eligibility=context.eligibility,
          verifiedDraftUrl="https://example.test/app/dashboard.cfm?recoveryAction=draft&floatPlanId=123"
        );

        expect(invalidStage.success).toBeFalse();
        expect(invalidStage.errorCode).toBe("INVALID_RECOVERY_STAGE");
        expect(invalidStage.subject & invalidStage.htmlBody & invalidStage.textBody).toBe("");
        expect(invalidDraft.success).toBeFalse();
        expect(invalidDraft.errorCode).toBe("INVALID_VERIFIED_DRAFT_URL");
        expect(invalidDraft.subject & invalidDraft.htmlBody & invalidDraft.textBody).toBe("");
      });

      it("fails closed when compliance input is missing, malformed, or ineligible", function() {
        var service = createObject("component", "fpw.api.v1.email").init();
        var malformed = service.buildInactiveMemberRecoveryEmail(stage="A",eligibility={});
        var ineligible = service.buildInactiveMemberRecoveryEmail(
          stage="A",
          eligibility={eligible=false,code="OPTED_OUT",unsubscribeUrl=""}
        );

        expect(malformed.success).toBeFalse();
        expect(malformed.errorCode).toBe("NON_ESSENTIAL_COMPLIANCE_REQUIRED");
        expect(malformed.htmlBody & malformed.textBody).toBe("");
        expect(ineligible.success).toBeFalse();
        expect(ineligible.errorCode).toBe("NON_ESSENTIAL_COMPLIANCE_REQUIRED");
        expect(ineligible.htmlBody & ineligible.textBody).toBe("");
      });

      it("rejects malformed Draft destinations as well as wrong origins and paths", function() {
        var context = createEligibleContext("draft-url-security");
        var draftPath = variables.dashboardUrl;
        var invalidUrls = [
          draftPath & "?recoveryAction=draft&floatPlanId=123&value=%ZZ",
          draftPath & "?recoveryAction=draft&floatPlanId=12 3",
          draftPath & "?recoveryAction=draft&floatPlanId=123&value=<invalid>",
          draftPath & "?recoveryAction=draft&floatPlanId=123" & chr(10) & "x",
          draftPath & "?recoveryAction=draft&floatPlanId=123##fragment",
          "https://example.test/fpw/app/dashboard.cfm?recoveryAction=draft&floatPlanId=123",
          "http://localhost:8501/fpw/app/dashboard.cfm?recoveryAction=draft&floatPlanId=123",
          "http://localhost:8500@evil.example/fpw/app/dashboard.cfm?recoveryAction=draft&floatPlanId=123",
          "http://localhost:8500/fpw/app/account.cfm",
          "http://localhost:8500/fpw/app/floatplan-wizard.cfm/../account.cfm",
          "//localhost:8500/fpw/app/dashboard.cfm?recoveryAction=draft&floatPlanId=123",
          "javascript:alert(1)",
          "/app/dashboard.cfm?recoveryAction=draft&floatPlanId=0",
          "/app/dashboard.cfm?recoveryAction=draft&floatPlanId=123&next=https://example.test",
          "/app/dashboard.cfm?recoveryAction=draft&floatPlanId=123&floatPlanId=456"
        ];
        for (var destination in invalidUrls) {
          var message = context.service.buildInactiveMemberRecoveryEmail(
            stage="D", eligibility=context.eligibility, verifiedDraftUrl=destination
          );
          expect(message.success).toBeFalse("Accepted invalid Draft URL: " & destination);
          expect(message.errorCode).toBe("INVALID_VERIFIED_DRAFT_URL");
          expect(message.subject & message.htmlBody & message.textBody & message.ctaUrl).toBe("");
        }
      });

      it("renders signed unsubscribe, distinct preferences, configured address, and one product CTA for all stages", function() {
        var stage = "";
        for (stage in ["A","B","C","D"]) {
          var context = createEligibleContext("compliance-" & lCase(stage));
          var message = context.service.buildInactiveMemberRecoveryEmail(
            stage=stage,eligibility=context.eligibility
          );

          expect(message.success).toBeTrue();
          expect(message.htmlBody).toInclude(encodeForHtmlAttribute(context.eligibility.unsubscribeUrl));
          expect(message.textBody).toInclude(context.eligibility.unsubscribeUrl);
          expect(message.htmlBody).toInclude(encodeForHtmlAttribute("http://localhost:8500/fpw/app/account.cfm?section=email-preferences##email-preferences"));
          expect(message.textBody).toInclude("/app/account.cfm?section=email-preferences##email-preferences");
          expect(message.htmlBody).toInclude("4347 Topsail Trail, New Port Richey, FL 34652");
          expect(message.textBody).toInclude("4347 Topsail Trail, New Port Richey, FL 34652");
          expect(message.htmlBody).toInclude("overflow-wrap:anywhere; word-break:break-word;");
          expect(context.eligibility.unsubscribeUrl).notToBe("http://localhost:8500/fpw/app/account.cfm?section=email-preferences##email-preferences");
          expect(countOccurrences(message.htmlBody,"display:inline-block; background-color:##0d6efd")).toBe(1);
          expect(countOccurrences(message.htmlBody,">" & message.ctaLabel & "</a>")).toBe(1);
          cleanupFixtures();
        }
      });

      it("escapes minimal personalization and keeps HTML/plain-text content aligned", function() {
        var context = createEligibleContext("personalization");
        var message = context.service.buildInactiveMemberRecoveryEmail(
          stage="B",
          eligibility=context.eligibility,
          firstName="Taylor <script>alert(1)</script>"
        );

        expect(message.htmlBody).notToInclude("<script>alert(1)</script>");
        expect(message.htmlBody).toInclude(encodeForHtml("Taylor <script>alert(1)</script>"));
        expect(message.textBody).toInclude("Hi Taylor <script>alert(1)</script>,");
        expect(message.htmlBody).toInclude(encodeForHtml(message.subject));
        expect(message.textBody).toInclude(message.ctaLabel & ":");
        expect(message.textBody).toInclude(message.ctaUrl);
      });

      it("keeps member-facing content free of pressure, sales language, and internal stage labels", function() {
        var stage = "";
        var prohibited = "upgrade|pricing|subscribe|premium|discount|last chance|urgent|overdue|referral rewards|stage [abcd]";
        expect(reFindNoCase("\b(" & prohibited & ")\b", "Stage A offers an urgent upgrade")).toBeGT(0);
        for (stage in ["A","B","C","D"]) {
          var context = createEligibleContext("guard-" & lCase(stage));
          var message = context.service.buildInactiveMemberRecoveryEmail(
            stage=stage,eligibility=context.eligibility
          );
          expect(reFindNoCase("\b(" & prohibited & ")\b",memberText(message))).toBe(0);
          cleanupFixtures();
        }
      });
    });
  }

  private struct function createEligibleContext(required string suffix) {
    var token = lCase(replace(createUUID(),"-","","all"));
    var email = left(variables.fixturePrefix & arguments.suffix & "-" & token & "@example.test",255);
    var inserted = {};
    var service = createObject("component", "fpw.api.v1.email").init();
    queryExecute(
      "INSERT INTO users (fName,lName,email,password,passwordCreated,created)
       VALUES ('Recovery','Template',:email,:password,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
      {
        email={value=email,cfsqltype="cf_sql_varchar"},
        password={value=hash(token,"SHA-256"),cfsqltype="cf_sql_varchar"}
      },
      {datasource=variables.datasource,result="inserted"}
    );
    var userId = val(inserted.generatedKey);
    var eligibility = service.checkNonEssentialEmailEligibility(email=email,userId=userId);
    expect(eligibility.eligible).toBeTrue();
    return {service=service,eligibility=eligibility,userId=userId,email=email};
  }

  private string function memberText(required struct message) {
    var marker = "You are receiving this email because";
    var markerPosition = findNoCase(marker,arguments.message.textBody);
    return markerPosition GT 0 ? left(arguments.message.textBody,markerPosition - 1) : arguments.message.textBody;
  }

  private numeric function countOccurrences(required string haystack, required string needle) {
    if (!len(arguments.needle)) return 0;
    return (len(arguments.haystack) - len(replace(arguments.haystack,arguments.needle,"","all"))) / len(arguments.needle);
  }

  private void function cleanupFixtures() {
    var pattern = variables.fixturePrefix & "%";
    queryExecute(
      "DELETE FROM email_optout WHERE email LIKE :pattern",
      {pattern={value=pattern,cfsqltype="cf_sql_varchar"}},
      {datasource=variables.datasource}
    );
    queryExecute(
      "DELETE FROM users WHERE email LIKE :pattern",
      {pattern={value=pattern,cfsqltype="cf_sql_varchar"}},
      {datasource=variables.datasource}
    );
  }
}
