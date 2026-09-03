component extends="testbox.system.BaseSpec" output="false" {

  variables.datasource = "fpw";
  variables.fixturePrefix = "codex-safe-arrival-";

  function beforeAll() {
    cleanupFixtures();
  }

  function afterAll() {
    cleanupFixtures();
  }

  function run() {
    describe("Phase 8 safe-arrival notification service", function() {

      beforeEach(function() {
        cleanupFixtures();
        request.fpwBase = "/fpw";
        variables.mailStub = createObject(
          "component",
          "fpw.tests.support.SafeArrivalEmailStub"
        ).init();
        variables.completedTripService = createObject(
          "component",
          "fpw.api.v1.CompletedTripViewModelService"
        ).init(variables.datasource);
        variables.service = createObject(
          "component",
          "fpw.api.v1.SafeArrivalNotificationService"
        ).init(
          variables.datasource,
          variables.mailStub,
          variables.completedTripService
        );
      });

      afterEach(function() {
        cleanupFixtures();
      });

      it("sends one captain message and one message per associated route shore contact", function() {
        var fixture = createFixture(
          label = "normal",
          contactCount = 2,
          addUnrelatedContact = true,
          addStream = true
        );
        var model = variables.completedTripService.getCompletedTripViewModel(
          fixture.userId,
          fixture.floatPlanId
        );
        var result = variables.service.processCompletedTrip(
          fixture.userId,
          fixture.floatPlanId
        );
        var calls = variables.mailStub.getCalls();
        var qHistory = loadHistory(fixture.floatPlanId);
        var shoreCalls = callsForRole(calls, "SHORE");

        expect(model.SUCCESS).toBeTrue();
        expect(result.SUCCESS).toBeTrue();
        expect(result.ELIGIBLE).toBeTrue();
        expect(result.sent).toBe(3);
        expect(result.captainSent).toBe(1);
        expect(result.shoreSent).toBe(2);
        expect(arrayLen(calls)).toBe(3);
        expect(calls[1].role).toBe("CAPTAIN");
        expect(calls[1].toEmail).toBe(fixture.ownerEmail);
        expect(calls[1].completedTripPath).toBe(
          variables.completedTripService.buildCompletedTripUrl(fixture.floatPlanId, "/fpw")
        );
        expect(calls[1].completionLabel).toBe(model.timing.actualCompletion.localLabel);
        expect(calls[1].completionTimezone).toBe(model.timing.actualCompletion.timezone);
        expect(arrayLen(shoreCalls)).toBe(2);
        expect(findNoCase("/fpw/app/follow.cfm?slug=", shoreCalls[1].followPath)).toBeGT(0);
        expect(findNoCase("&t=", shoreCalls[1].followPath)).toBeGT(0);
        expect(findNoCase("completed-trip.cfm", shoreCalls[1].followPath)).toBe(0);
        expect(callHasEmail(calls, fixture.unrelatedEmail)).toBeFalse();
        expect(qHistory.recordCount).toBe(3);
        expect(historyStatusCount(qHistory, "SENT")).toBe(3);
      });

      it("does not duplicate a successful completion event on a second pass", function() {
        var fixture = createFixture(
          label = "idempotent",
          contactCount = 2,
          addStream = true
        );
        var first = variables.service.processCompletedTrip(fixture.userId, fixture.floatPlanId);
        var second = variables.service.processCompletedTrip(fixture.userId, fixture.floatPlanId);
        var qHistory = loadHistory(fixture.floatPlanId);

        expect(first.sent).toBe(3);
        expect(second.SUCCESS).toBeTrue();
        expect(second.sent).toBe(0);
        expect(second.skipped).toBe(3);
        expect(arrayLen(variables.mailStub.getCalls())).toBe(3);
        expect(qHistory.recordCount).toBe(3);
        expect(historyStatusCount(qHistory, "SENT")).toBe(3);
      });

      it("suppresses draft, scheduled, active, and overdue plans", function() {
        var statuses = ["DRAFT", "SCHEDULED", "ACTIVE", "OVERDUE"];
        var i = 0;
        var fixture = {};
        var result = {};

        for (i = 1; i LTE arrayLen(statuses); i++) {
          fixture = createFixture(
            label = "suppressed-" & lCase(statuses[i]),
            planStatus = statuses[i],
            routeStatus = "ACTIVE",
            closed = false,
            contactCount = 1
          );
          result = variables.service.processCompletedTrip(
            fixture.userId,
            fixture.floatPlanId
          );
          expect(result.ELIGIBLE).toBeFalse();
          expect(result.sent).toBe(0);
        }

        expect(arrayLen(variables.mailStub.getCalls())).toBe(0);
      });

      it("suppresses monitoring or plan closure without canonical route completion", function() {
        var fixture = createFixture(
          label = "route-incomplete",
          planStatus = "CLOSED",
          routeStatus = "ACTIVE",
          closed = true,
          contactCount = 1
        );
        var result = variables.service.processCompletedTrip(
          fixture.userId,
          fixture.floatPlanId
        );

        expect(result.ELIGIBLE).toBeFalse();
        expect(result.sent).toBe(0);
        expect(arrayLen(variables.mailStub.getCalls())).toBe(0);
        expect(loadHistory(fixture.floatPlanId).recordCount).toBe(0);
      });

      it("still confirms the captain when no shore contact is associated", function() {
        var fixture = createFixture(
          label = "captain-only",
          contactCount = 0,
          addStream = true
        );
        var result = variables.service.processCompletedTrip(
          fixture.userId,
          fixture.floatPlanId
        );
        var calls = variables.mailStub.getCalls();

        expect(result.SUCCESS).toBeTrue();
        expect(result.captainSent).toBe(1);
        expect(result.shoreSent).toBe(0);
        expect(arrayLen(calls)).toBe(1);
        expect(calls[1].role).toBe("CAPTAIN");
      });

      it("uses Basic trip contact details without inventing a Follow destination", function() {
        var fixture = createFixture(
          label = "basic",
          basic = true,
          contactCount = 1,
          addStream = false
        );
        var result = variables.service.processCompletedTrip(
          fixture.userId,
          fixture.floatPlanId
        );
        var calls = variables.mailStub.getCalls();
        var shoreCalls = callsForRole(calls, "SHORE");

        expect(result.SUCCESS).toBeTrue();
        expect(result.captainSent).toBe(1);
        expect(result.shoreSent).toBe(1);
        expect(arrayLen(shoreCalls)).toBe(1);
        expect(shoreCalls[1].followPath).toBe("");
        expect(findNoCase("completed-trip.cfm", shoreCalls[1].followPath)).toBe(0);
      });

      it("isolates mail failure from completion and retries only the failed delivery", function() {
        var fixture = createFixture(
          label = "retry",
          contactCount = 0
        );
        var first = {};
        var second = {};
        var third = {};
        var qPlan = queryNew("");
        var qHistory = queryNew("");

        variables.mailStub.setFailures(1);
        first = variables.service.processCompletedTrip(fixture.userId, fixture.floatPlanId);
        qPlan = queryExecute(
          "SELECT `status`, closedAt FROM floatplans WHERE floatPlanId = :floatPlanId",
          {
            floatPlanId = { value = fixture.floatPlanId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = variables.datasource }
        );
        qHistory = loadHistory(fixture.floatPlanId);

        expect(first.SUCCESS).toBeFalse();
        expect(first.failed).toBe(1);
        expect(uCase(trim(toString(qPlan.status[1])))).toBe("CLOSED");
        expect(isDate(qPlan.closedAt[1])).toBeTrue();
        expect(historyStatusCount(qHistory, "FAILED")).toBe(1);
        expect(val(qHistory.attemptCount[1])).toBe(1);

        variables.mailStub.setFailures(0);
        second = variables.service.processCompletedTrip(fixture.userId, fixture.floatPlanId);
        qHistory = loadHistory(fixture.floatPlanId);
        expect(second.SUCCESS).toBeTrue();
        expect(second.sent).toBe(1);
        expect(historyStatusCount(qHistory, "SENT")).toBe(1);
        expect(val(qHistory.attemptCount[1])).toBe(2);

        third = variables.service.processCompletedTrip(fixture.userId, fixture.floatPlanId);
        expect(third.sent).toBe(0);
        expect(arrayLen(variables.mailStub.getCalls())).toBe(2);
      });

      it("builds operational email variants with the approved shore-contact referral contract", function() {
        var emailService = createObject("component", "fpw.api.v1.email").init();
        var captain = {};
        var shore = {};
        var basicShore = {};
        var excludedShore = {};
        var referralPath = "/app/join.cfm?utm_source=shore_contact&utm_medium=email&utm_campaign=safe_arrival&utm_content=plan_own_trip";

        makePublic(emailService, "buildSafeArrivalCaptainEmail", "buildSafeArrivalCaptainEmailForTest");
        makePublic(emailService, "buildSafeArrivalShoreContactEmail", "buildSafeArrivalShoreContactEmailForTest");

        captain = emailService.buildSafeArrivalCaptainEmailForTest(
          "Casey Captain",
          42,
          "Harbor Return",
          "Waypoint",
          "Test Marina",
          "Test Anchorage",
          "Sep 1, 2026 4:15 PM America/New_York",
          "America/New_York",
          "/fpw/app/completed-trip.cfm?id=42"
        );
        shore = emailService.buildSafeArrivalShoreContactEmailForTest(
          recipientName = "Trusted Contact",
          captainName = "Casey Captain",
          floatPlanId = 42,
          tripName = "Harbor Return",
          vesselName = "Waypoint",
          destination = "Test Anchorage",
          completionLabel = "Sep 1, 2026 4:15 PM America/New_York",
          completionTimezone = "America/New_York",
          followPath = "/fpw/app/follow.cfm?slug=trip-safe&t=opaque-token",
          includeReferral = true
        );
        basicShore = emailService.buildSafeArrivalShoreContactEmailForTest(
          recipientName = "Trusted Contact",
          captainName = "Casey Captain",
          floatPlanId = 42,
          tripName = "Harbor Return",
          vesselName = "Waypoint",
          destination = "Test Anchorage",
          completionLabel = "Sep 1, 2026 4:15 PM America/New_York",
          completionTimezone = "America/New_York",
          followPath = "",
          includeReferral = true
        );
        excludedShore = emailService.buildSafeArrivalShoreContactEmailForTest(
          recipientName = "Trusted Contact",
          captainName = "Casey Captain",
          floatPlanId = 42,
          tripName = "Harbor Return",
          vesselName = "Waypoint",
          destination = "Test Anchorage",
          completionLabel = "Sep 1, 2026 4:15 PM America/New_York",
          completionTimezone = "America/New_York",
          followPath = "",
          includeReferral = false
        );

        expect(captain.subject).toBe("Your FloatPlanWizard trip is complete");
        expect(captain.ctaPath).toBe("/fpw/app/completed-trip.cfm?id=42");
        expect(findNoCase("/fpw/app/completed-trip.cfm?id=42", captain.ctaUrl)).toBeGT(0);
        expect(countOccurrences(captain.htmlBody, ">View Completed Trip</a>")).toBe(1);
        expect(findNoCase("completed safely", captain.textBody)).toBeGT(0);
        expect(shore.hasFollowLink).toBeTrue();
        expect(shore.hasReferral).toBeTrue();
        expect(findNoCase("/fpw/app/follow.cfm?", shore.followPath)).toBeGT(0);
        expect(findNoCase("completed-trip.cfm", shore.htmlBody)).toBe(0);
        expect(shore.referralPath).toBe(referralPath);
        expect(findNoCase("/app/join.cfm?", shore.referralUrl)).toBeGT(0);
        expect(findNoCase("utm_source=shore_contact", shore.referralUrl)).toBeGT(0);
        expect(findNoCase("utm_medium=email", shore.referralUrl)).toBeGT(0);
        expect(findNoCase("utm_campaign=safe_arrival", shore.referralUrl)).toBeGT(0);
        expect(findNoCase("utm_content=plan_own_trip", shore.referralUrl)).toBeGT(0);
        expect(findNoCase("Plan your own boating trip.", shore.htmlBody)).toBeGT(0);
        expect(findNoCase("Create a free FPW account to plan your route, stops, and trip estimates with the Trip Planner.", shore.htmlBody)).toBeGT(0);
        expect(countOccurrences(shore.htmlBody, ">Plan Your Own Trip</a>")).toBe(1);
        expect(findNoCase("Plan your own boating trip.", shore.textBody)).toBeGT(0);
        expect(findNoCase("Plan Your Own Trip:", shore.textBody)).toBeGT(0);
        expect(findNoCase(shore.referralUrl, shore.textBody)).toBeGT(0);
        expect(findNoCase("display:inline-block", mid(shore.htmlBody, findNoCase(">Plan Your Own Trip</a>", shore.htmlBody) - 250, 250))).toBe(0);
        expect(findNoCase("Trusted Contact", shore.referralUrl)).toBe(0);
        expect(findNoCase("Casey Captain", shore.referralUrl)).toBe(0);
        expect(findNoCase("Harbor Return", shore.referralUrl)).toBe(0);
        expect(findNoCase("Waypoint", shore.referralUrl)).toBe(0);
        expect(findNoCase("Test Anchorage", shore.referralUrl)).toBe(0);
        expect(findNoCase("42", shore.referralUrl)).toBe(0);
        expect(findNoCase("opaque-token", shore.referralUrl)).toBe(0);
        expect(basicShore.hasFollowLink).toBeFalse();
        expect(basicShore.hasReferral).toBeTrue();
        expect(findNoCase("View Final Trip Status", basicShore.htmlBody)).toBe(0);
        expect(findNoCase("Plan your own boating trip.", basicShore.htmlBody)).toBeGT(0);
        expect(excludedShore.hasReferral).toBeFalse();
        expect(findNoCase("Plan your own boating trip.", excludedShore.htmlBody & excludedShore.textBody)).toBe(0);
        expect(findNoCase("Plan your own boating trip.", captain.htmlBody & captain.textBody)).toBe(0);
        expect(findNoCase("utm_source=shore_contact", captain.htmlBody & captain.textBody)).toBe(0);
        expect(findNoCase("upgrade", captain.textBody & shore.textBody)).toBe(0);
        expect(findNoCase("pricing", captain.textBody & shore.textBody)).toBe(0);
      });

      it("honors non-essential opt-outs and omits the referral when preference lookup fails", function() {
        var emailService = createObject("component", "fpw.api.v1.email").init();
        var optOutService = createObject("component", "fpw.api.v1.EmailOptOutService").init(
          datasource = variables.datasource
        );
        var failingOptOutService = createObject("component", "fpw.api.v1.EmailOptOutService").init(
          datasource = "fpw_referral_lookup_failure"
        );
        var recipientEmail = variables.fixturePrefix & lCase(reReplace(createUUID(), "[^A-Za-z0-9]", "", "all")) & "@example.test";
        var recordResult = {};
        var includeBeforeOptOut = false;
        var includeAfterOptOut = true;
        var includeAfterFailure = true;
        var optedOutMessage = {};
        var lookupFailureMessage = {};
        var senderService = prepareMock(createObject("component", "fpw.api.v1.email").init());
        var sendResult = {};

        makePublic(emailService, "shouldIncludeSafeArrivalReferral", "shouldIncludeSafeArrivalReferralForTest");
        makePublic(emailService, "buildSafeArrivalShoreContactEmail", "buildSafeArrivalShoreContactEmailForTest");

        includeBeforeOptOut = emailService.shouldIncludeSafeArrivalReferralForTest(
          recipientEmail,
          optOutService
        );
        recordResult = optOutService.recordOptOut(
          email = recipientEmail,
          optOutType = "non_essential",
          source = "codex_safe_arrival_referral_test"
        );
        includeAfterOptOut = emailService.shouldIncludeSafeArrivalReferralForTest(
          recipientEmail,
          optOutService
        );
        includeAfterFailure = emailService.shouldIncludeSafeArrivalReferralForTest(
          recipientEmail,
          failingOptOutService
        );
        optedOutMessage = emailService.buildSafeArrivalShoreContactEmailForTest(
          recipientName = "Trusted Contact",
          captainName = "Casey Captain",
          floatPlanId = 42,
          tripName = "Harbor Return",
          vesselName = "Waypoint",
          destination = "Test Anchorage",
          completionLabel = "Sep 1, 2026 4:15 PM America/New_York",
          completionTimezone = "America/New_York",
          followPath = "",
          includeReferral = includeAfterOptOut
        );
        lookupFailureMessage = emailService.buildSafeArrivalShoreContactEmailForTest(
          recipientName = "Trusted Contact",
          captainName = "Casey Captain",
          floatPlanId = 42,
          tripName = "Harbor Return",
          vesselName = "Waypoint",
          destination = "Test Anchorage",
          completionLabel = "Sep 1, 2026 4:15 PM America/New_York",
          completionTimezone = "America/New_York",
          followPath = "",
          includeReferral = includeAfterFailure
        );
        senderService.$("shouldIncludeSafeArrivalReferral", false);
        senderService.$("sendMultipartEmail");
        sendResult = senderService.sendSafeArrivalShoreContactEmail(
          userId = 42,
          toEmail = recipientEmail,
          recipientName = "Trusted Contact",
          captainName = "Casey Captain",
          floatPlanId = 42,
          tripName = "Harbor Return",
          vesselName = "Waypoint",
          destination = "Test Anchorage",
          completionLabel = "Sep 1, 2026 4:15 PM America/New_York",
          completionTimezone = "America/New_York",
          followPath = ""
        );

        expect(includeBeforeOptOut).toBeTrue();
        expect(recordResult.SUCCESS).toBeTrue();
        expect(includeAfterOptOut).toBeFalse();
        expect(includeAfterFailure).toBeFalse();
        expect(sendResult.SUCCESS).toBeTrue();
        expect(findNoCase("completed safely", optedOutMessage.textBody)).toBeGT(0);
        expect(findNoCase("completed safely", lookupFailureMessage.textBody)).toBeGT(0);
        expect(findNoCase("Plan your own boating trip.", optedOutMessage.htmlBody & optedOutMessage.textBody)).toBe(0);
        expect(findNoCase("Plan your own boating trip.", lookupFailureMessage.htmlBody & lookupFailureMessage.textBody)).toBe(0);
      });

      it("uses stable recipient claims and both post-commit closure hooks by source contract", function() {
        var serviceSource = readRepoFile("api/v1/SafeArrivalNotificationService.cfc");
        var floatPlanSource = readRepoFile("api/v1/floatplan.cfc");
        var emailSource = readRepoFile("api/v1/email.cfc");
        var completedTripPageSource = readRepoFile("app/completed-trip.cfm");

        expect(findNoCase("CompletedTripViewModelService", serviceSource)).toBeGT(0);
        expect(findNoCase("buildCompletedTripUrl", serviceSource)).toBeGT(0);
        expect(findNoCase("INSERT IGNORE INTO floatplan_alert_history", serviceSource)).toBeGT(0);
        expect(findNoCase("FOR UPDATE", serviceSource)).toBeGT(0);
        expect(findNoCase("status = 'CLAIMED'", serviceSource)).toBeGT(0);
        expect(findNoCase("status = 'SENT'", serviceSource)).toBeGT(0);
        expect(findNoCase("status = 'FAILED'", serviceSource)).toBeGT(0);
        expect(countOccurrences(floatPlanSource, "requestSafeArrivalNotifications(")).toBe(2);
        expect(findNoCase('name="requestSafeArrivalNotifications"', floatPlanSource)).toBeGT(0);
        expect(findNoCase("SafeArrivalNotificationService", floatPlanSource)).toBeGT(0);
        expect(findNoCase("sendSafeArrivalCaptainEmail", emailSource)).toBeGT(0);
        expect(findNoCase("sendSafeArrivalShoreContactEmail", emailSource)).toBeGT(0);
        expect(findNoCase('cfinclude template="../includes/require_auth.cfm"', completedTripPageSource)).toBeGT(0);
      });

      it("keeps alert identities within the existing 32-character schema contract", function() {
        var captainKey = variables.service.buildAlertType(
          "CAPTAIN",
          "USER:100",
          "2026-09-01T20:15:00Z"
        );
        var shoreKey = variables.service.buildAlertType(
          "SHORE",
          "ASSOCIATION:900",
          "2026-09-01T20:15:00Z"
        );
        var replay = variables.service.resolveClaimState(false, "SENT", 1);
        var retry = variables.service.resolveClaimState(false, "FAILED", 1);
        var exhausted = variables.service.resolveClaimState(false, "FAILED", 3);

        expect(len(captainKey)).toBe(32);
        expect(len(shoreKey)).toBe(32);
        expect(captainKey).notToBe(shoreKey);
        expect(replay.CLAIMED).toBeFalse();
        expect(retry.CLAIMED).toBeTrue();
        expect(retry.RETRY).toBeTrue();
        expect(exhausted.CLAIMED).toBeFalse();
      });
    });
  }

  private struct function createFixture(
    required string label,
    string planStatus = "CLOSED",
    string routeStatus = "COMPLETED",
    boolean closed = true,
    numeric contactCount = 1,
    boolean addUnrelatedContact = false,
    boolean addStream = false,
    boolean basic = false
  ) {
    var token = lCase(reReplace(createUUID(), "[^A-Za-z0-9]", "", "all"));
    var marker = left(variables.fixturePrefix & token & "-" & arguments.label, 180);
    var ownerEmail = left(marker & "@example.test", 255);
    var vesselName = left(marker & "-vessel", 255);
    var planName = left(marker & "-trip", 255);
    var completedAt = dateAdd("n", -15, now());
    var startedAt = dateAdd("h", -3, completedAt);
    var qUser = queryNew("");
    var qVessel = queryNew("");
    var qLoopRoute = queryNew("");
    var qRoute = queryNew("");
    var qPlan = queryNew("");
    var qContact = queryNew("");
    var routeInstanceId = 0;
    var routeCode = left("SAFE_" & token, 40);
    var contactIndex = 0;
    var associatedEmails = [];
    var unrelatedEmail = "";
    var contactEmail = "";
    var contactName = "";
    var slug = "";
    var shareToken = "";

    queryExecute(
      "INSERT INTO users (fName, lName, email, password, passwordCreated, created)
       VALUES ('Casey', 'Captain', :email, :password, UTC_TIMESTAMP(), UTC_TIMESTAMP())",
      {
        email = { value = ownerEmail, cfsqltype = "cf_sql_varchar" },
        password = { value = hash(marker, "SHA-256"), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    qUser = queryExecute(
      "SELECT userId FROM users WHERE email = :email ORDER BY userId DESC LIMIT 1",
      { email = { value = ownerEmail, cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );

    queryExecute(
      "INSERT INTO vessels (userId, vesselName, hailingPort, isDefaultVessel, timezone)
       VALUES (:userId, :vesselName, 'Test Harbor', 1, 'America/Chicago')",
      {
        userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" },
        vesselName = { value = vesselName, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    qVessel = queryExecute(
      "SELECT vesselID FROM vessels WHERE userId = :userId AND vesselName = :vesselName ORDER BY vesselID DESC LIMIT 1",
      {
        userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" },
        vesselName = { value = vesselName, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );

    if (!arguments.basic) {
      queryExecute(
        "INSERT INTO loop_routes (
           code, name, short_code, description, is_active,
           version, is_default, total_nm, total_locks
         ) VALUES (
           :routeCode, :routeName, :routeCode, :description, 1,
           1, 0, 1.00, 0
         )",
        {
          routeCode = { value = routeCode, cfsqltype = "cf_sql_varchar" },
          routeName = { value = left(marker & "-route", 160), cfsqltype = "cf_sql_varchar" },
          description = { value = marker, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
      qLoopRoute = queryExecute(
        "SELECT id FROM loop_routes WHERE short_code = :routeCode LIMIT 1",
        {
          routeCode = { value = routeCode, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );

      queryExecute(
        "INSERT INTO route_instances (
           user_id, template_route_code, generated_route_id, generated_route_code,
           direction, trip_type, start_location, end_location, status,
           started_at, completed_at
         ) VALUES (
           :userId, :routeCode, :routeId, :routeCode,
           'CCW', 'POINT_TO_POINT', 'Test Marina', 'Test Anchorage', :routeStatus,
           :startedAt, :completedAt
         )",
        {
          userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" },
          routeCode = { value = routeCode, cfsqltype = "cf_sql_varchar" },
          routeId = { value = val(qLoopRoute.id[1]), cfsqltype = "cf_sql_integer" },
          routeStatus = { value = arguments.routeStatus, cfsqltype = "cf_sql_varchar" },
          startedAt = {
            value = startedAt,
            null = !arguments.closed,
            cfsqltype = "cf_sql_timestamp"
          },
          completedAt = {
            value = completedAt,
            null = (!arguments.closed OR uCase(arguments.routeStatus) NEQ "COMPLETED"),
            cfsqltype = "cf_sql_timestamp"
          }
        },
        { datasource = variables.datasource }
      );
      qRoute = queryExecute(
        "SELECT id FROM route_instances
         WHERE user_id = :userId AND generated_route_code = :routeCode
         ORDER BY id DESC LIMIT 1",
        {
          userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" },
          routeCode = { value = routeCode, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
      routeInstanceId = val(qRoute.id[1]);
    }

    queryExecute(
      "INSERT INTO floatplans (
         userId, floatPlanName, vesselId, dateCreated, lastUpdate,
         departing, `returning`, departureTimeUTC, departureTZ,
         returnTimeUTC, returnTZ, `status`, lastUpdateStatus,
         activatedAt, checkedInAt, closedAt, route_instance_id,
         route_origin, is_reusable, is_visible_in_route_library
       ) VALUES (
         :userId, :planName, :vesselId, UTC_TIMESTAMP(), UTC_TIMESTAMP(),
         'Test Marina', 'Test Anchorage', :departureTimeUTC, 'America/Chicago',
         :returnTimeUTC, 'America/Chicago', :planStatus, UTC_TIMESTAMP(),
         :activatedAt, :checkedInAt, :closedAt, :routeInstanceId,
         :routeOrigin, :isReusable, :isVisible
       )",
      {
        userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" },
        planName = { value = planName, cfsqltype = "cf_sql_varchar" },
        vesselId = { value = val(qVessel.vesselID[1]), cfsqltype = "cf_sql_integer" },
        departureTimeUTC = { value = dateAdd("h", -4, completedAt), cfsqltype = "cf_sql_timestamp" },
        returnTimeUTC = { value = completedAt, cfsqltype = "cf_sql_timestamp" },
        planStatus = { value = arguments.planStatus, cfsqltype = "cf_sql_varchar" },
        activatedAt = { value = startedAt, null = !arguments.closed, cfsqltype = "cf_sql_timestamp" },
        checkedInAt = { value = completedAt, null = !arguments.closed, cfsqltype = "cf_sql_timestamp" },
        closedAt = { value = completedAt, null = !arguments.closed, cfsqltype = "cf_sql_timestamp" },
        routeInstanceId = {
          value = routeInstanceId,
          null = arguments.basic,
          cfsqltype = "cf_sql_integer"
        },
        routeOrigin = {
          value = arguments.basic ? "basic_float_plan" : "premium_saved_route",
          cfsqltype = "cf_sql_varchar"
        },
        isReusable = { value = arguments.basic ? 0 : 1, cfsqltype = "cf_sql_tinyint" },
        isVisible = { value = arguments.basic ? 0 : 1, cfsqltype = "cf_sql_tinyint" }
      },
      { datasource = variables.datasource }
    );
    qPlan = queryExecute(
      "SELECT floatPlanId FROM floatplans
       WHERE userId = :userId AND floatPlanName = :planName
       ORDER BY floatPlanId DESC LIMIT 1",
      {
        userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" },
        planName = { value = planName, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );

    if (arguments.basic AND arguments.contactCount GT 0) {
      contactEmail = left(marker & "-basic-contact@example.test", 255);
      queryExecute(
        "INSERT INTO floatplan_basic_details (
           floatplan_id, vessel_name, operator_name, captain_name, captain_email,
           notification_contact_name, notification_contact_email,
           launch_location, destination_location,
           authority_name_snapshot, authority_phone_snapshot,
           created_at, updated_at
         ) VALUES (
           :floatPlanId, :vesselName, 'Casey Captain', 'Casey Captain', :captainEmail,
           'Basic Shore Contact', :contactEmail,
           'Test Marina', 'Test Anchorage',
           'Test Authority', '555-0199',
           UTC_TIMESTAMP(), UTC_TIMESTAMP()
         )",
        {
          floatPlanId = { value = val(qPlan.floatPlanId[1]), cfsqltype = "cf_sql_integer" },
          vesselName = { value = vesselName, cfsqltype = "cf_sql_varchar" },
          captainEmail = { value = ownerEmail, cfsqltype = "cf_sql_varchar" },
          contactEmail = { value = contactEmail, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
      arrayAppend(associatedEmails, contactEmail);
    } else if (!arguments.basic) {
      for (contactIndex = 1; contactIndex LTE int(arguments.contactCount); contactIndex++) {
        contactEmail = left(marker & "-contact-" & contactIndex & "@example.test", 255);
        contactName = left("Safe Arrival Contact " & contactIndex & " " & marker, 150);
        queryExecute(
          "INSERT INTO contacts (name, phone, userId, email)
           VALUES (:name, '555-0100', :userId, :email)",
          {
            name = { value = contactName, cfsqltype = "cf_sql_varchar" },
            userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" },
            email = { value = contactEmail, cfsqltype = "cf_sql_varchar" }
          },
          { datasource = variables.datasource }
        );
        qContact = queryExecute(
          "SELECT contactId FROM contacts
           WHERE userId = :userId AND email = :email
           ORDER BY contactId DESC LIMIT 1",
          {
            userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" },
            email = { value = contactEmail, cfsqltype = "cf_sql_varchar" }
          },
          { datasource = variables.datasource }
        );
        queryExecute(
          "INSERT INTO floatplan_contacts (contactId, floatPlanId)
           VALUES (:contactId, :floatPlanId)",
          {
            contactId = { value = val(qContact.contactId[1]), cfsqltype = "cf_sql_integer" },
            floatPlanId = { value = val(qPlan.floatPlanId[1]), cfsqltype = "cf_sql_integer" }
          },
          { datasource = variables.datasource }
        );
        arrayAppend(associatedEmails, contactEmail);
      }

      if (arguments.addUnrelatedContact) {
        unrelatedEmail = left(marker & "-unrelated@example.test", 255);
        queryExecute(
          "INSERT INTO contacts (name, phone, userId, email)
           VALUES ('Unrelated Contact', '555-0198', :userId, :email)",
          {
            userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" },
            email = { value = unrelatedEmail, cfsqltype = "cf_sql_varchar" }
          },
          { datasource = variables.datasource }
        );
      }
    }

    if (arguments.addStream AND !arguments.basic) {
      slug = left("safe-arrival-" & token, 120);
      shareToken = left(lCase(replace(createUUID(), "-", "", "all")) & lCase(replace(createUUID(), "-", "", "all")), 96);
      queryExecute(
        "INSERT INTO voyage_streams (
           floatplan_id, owner_user_id, slug, share_token, privacy_mode,
           allow_interactions, created_utc, updated_utc
         ) VALUES (
           :floatPlanId, :userId, :slug, :shareToken, 'invite',
           0, UTC_TIMESTAMP(), UTC_TIMESTAMP()
         )",
        {
          floatPlanId = { value = val(qPlan.floatPlanId[1]), cfsqltype = "cf_sql_integer" },
          userId = { value = val(qUser.userId[1]), cfsqltype = "cf_sql_integer" },
          slug = { value = slug, cfsqltype = "cf_sql_varchar" },
          shareToken = { value = shareToken, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
    }

    return {
      marker = marker,
      userId = val(qUser.userId[1]),
      ownerEmail = ownerEmail,
      vesselId = val(qVessel.vesselID[1]),
      vesselName = vesselName,
      routeInstanceId = routeInstanceId,
      floatPlanId = val(qPlan.floatPlanId[1]),
      planName = planName,
      associatedEmails = associatedEmails,
      unrelatedEmail = unrelatedEmail,
      slug = slug,
      shareToken = shareToken
    };
  }

  private query function loadHistory(required numeric floatPlanId) {
    return queryExecute(
      "SELECT id, alertType, status, attemptCount, sentAtUTC, lastAttemptAtUTC, lastError
       FROM floatplan_alert_history
       WHERE floatPlanId = :floatPlanId
         AND alertType LIKE 'SAFE_%'
       ORDER BY id",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );
  }

  private numeric function historyStatusCount(
    required query history,
    required string status
  ) {
    var count = 0;
    var i = 0;
    for (i = 1; i LTE arguments.history.recordCount; i++) {
      if (compareNoCase(trim(toString(arguments.history.status[i])), arguments.status) EQ 0) {
        count++;
      }
    }
    return count;
  }

  private array function callsForRole(
    required array calls,
    required string role
  ) {
    var matches = [];
    var i = 0;
    for (i = 1; i LTE arrayLen(arguments.calls); i++) {
      if (compareNoCase(arguments.calls[i].role, arguments.role) EQ 0) {
        arrayAppend(matches, arguments.calls[i]);
      }
    }
    return matches;
  }

  private boolean function callHasEmail(
    required array calls,
    required string email
  ) {
    var i = 0;
    if (!len(trim(arguments.email))) {
      return false;
    }
    for (i = 1; i LTE arrayLen(arguments.calls); i++) {
      if (
        structKeyExists(arguments.calls[i], "toEmail")
        AND compareNoCase(trim(arguments.calls[i].toEmail), trim(arguments.email)) EQ 0
      ) {
        return true;
      }
    }
    return false;
  }

  private numeric function countOccurrences(
    required string source,
    required string token
  ) {
    var count = 0;
    var offset = 1;
    var matchAt = 0;
    while (offset LTE len(arguments.source)) {
      matchAt = findNoCase(arguments.token, arguments.source, offset);
      if (matchAt LTE 0) {
        break;
      }
      count++;
      offset = matchAt + len(arguments.token);
    }
    return count;
  }

  private string function readRepoFile(required string relativePath) {
    return fileRead(expandPath("/fpw/" & arguments.relativePath), "utf-8");
  }

  private void function cleanupFixtures() {
    var params = {
      emailPrefix = { value = variables.fixturePrefix & "%", cfsqltype = "cf_sql_varchar" },
      planPrefix = { value = variables.fixturePrefix & "%", cfsqltype = "cf_sql_varchar" },
      routePrefix = { value = "SAFE_%", cfsqltype = "cf_sql_varchar" }
    };

    queryExecute(
      "DELETE FROM email_optout WHERE email LIKE :emailPrefix",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM floatplan_alert_history
       WHERE floatPlanId IN (
         SELECT floatPlanId FROM floatplans WHERE floatPlanName LIKE :planPrefix
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM voyage_streams
       WHERE floatplan_id IN (
         SELECT floatPlanId FROM floatplans WHERE floatPlanName LIKE :planPrefix
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM floatplan_contacts
       WHERE floatPlanId IN (
         SELECT floatPlanId FROM floatplans WHERE floatPlanName LIKE :planPrefix
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM floatplan_basic_details
       WHERE floatplan_id IN (
         SELECT floatPlanId FROM floatplans WHERE floatPlanName LIKE :planPrefix
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM floatplans WHERE floatPlanName LIKE :planPrefix",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM route_instances
       WHERE generated_route_code LIKE :routePrefix
         AND CAST(user_id AS UNSIGNED) IN (
           SELECT userId FROM users WHERE email LIKE :emailPrefix
         )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM loop_routes WHERE description LIKE :planPrefix",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM contacts
       WHERE CAST(userId AS UNSIGNED) IN (
         SELECT userId FROM users WHERE email LIKE :emailPrefix
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM vessels
       WHERE CAST(userId AS UNSIGNED) IN (
         SELECT userId FROM users WHERE email LIKE :emailPrefix
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM users WHERE email LIKE :emailPrefix",
      params,
      { datasource = variables.datasource }
    );
  }
}






