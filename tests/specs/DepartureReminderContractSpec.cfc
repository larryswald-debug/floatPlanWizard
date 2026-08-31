component extends="testbox.system.BaseSpec" output="false" {

  function run() {
    describe("Day 36 departure reminder contract", function() {

      beforeEach(function() {
        variables.mailStub = createObject(
          "component",
          "fpw.tests.support.DepartureReminderEmailStub"
        ).init();
        variables.service = createObject(
          "component",
          "fpw.api.v1.DepartureReminderService"
        ).init("fpw", variables.mailStub);
      });

      it("opens the pre-departure occurrence for a bounded window two hours before departure", function() {
        var departureUtc = createDateTime(2026, 9, 1, 16, 0, 0);
        var exactDue = variables.service.determineDueReminderTypes(
          departureUtc,
          dateAdd("h", -2, departureUtc)
        );
        var slightlyLate = variables.service.determineDueReminderTypes(
          departureUtc,
          dateAdd("n", -105, departureUtc)
        );
        var beforeWindow = variables.service.determineDueReminderTypes(
          departureUtc,
          dateAdd("s", -1, dateAdd("h", -2, departureUtc))
        );
        var afterWindow = variables.service.determineDueReminderTypes(
          departureUtc,
          dateAdd("n", -90, departureUtc)
        );

        expect(arrayFindNoCase(exactDue, "PRE_DEPARTURE")).toBeGT(0);
        expect(arrayFindNoCase(slightlyLate, "PRE_DEPARTURE")).toBeGT(0);
        expect(arrayFindNoCase(beforeWindow, "PRE_DEPARTURE")).toBe(0);
        expect(arrayFindNoCase(afterWindow, "PRE_DEPARTURE")).toBe(0);
      });

      it("opens the not-started occurrence from plus 30 through plus 60 minutes", function() {
        var departureUtc = createDateTime(2026, 9, 1, 16, 0, 0);
        var beforeDeparture = variables.service.determineDueReminderTypes(
          departureUtc,
          dateAdd("n", -1, departureUtc)
        );
        var beforeThreshold = variables.service.determineDueReminderTypes(
          departureUtc,
          dateAdd("s", -1, dateAdd("n", 30, departureUtc))
        );
        var atThreshold = variables.service.determineDueReminderTypes(
          departureUtc,
          dateAdd("n", 30, departureUtc)
        );
        var slightlyLate = variables.service.determineDueReminderTypes(
          departureUtc,
          dateAdd("n", 45, departureUtc)
        );

        expect(arrayFindNoCase(beforeDeparture, "NOT_STARTED")).toBe(0);
        expect(arrayFindNoCase(beforeThreshold, "NOT_STARTED")).toBe(0);
        expect(arrayFindNoCase(atThreshold, "NOT_STARTED")).toBeGT(0);
        expect(arrayFindNoCase(slightlyLate, "NOT_STARTED")).toBeGT(0);
      });

      it("accepts only a valid route-backed active owner trip", function() {
        var departureUtc = createDateTime(2026, 9, 1, 16, 0, 0);
        var candidate = baseCandidate(departureUtc);
        var result = variables.service.validateCandidateForReminder(
          candidate,
          "PRE_DEPARTURE",
          dateAdd("h", -2, departureUtc)
        );

        expect(result.ELIGIBLE).toBeTrue();
        expect(result.DEPARTURE_TIMEZONE).toBe("America/New_York");
      });

      it("rejects missing schedule, timezone, owner, email, and route linkage", function() {
        var departureUtc = createDateTime(2026, 9, 1, 16, 0, 0);
        var currentUtc = dateAdd("h", -2, departureUtc);
        var candidate = baseCandidate(departureUtc);

        structDelete(candidate, "departureTimeUtc");
        expect(validate(candidate, currentUtc).REASON).toBe("MISSING_SCHEDULED_UTC");

        candidate = baseCandidate(departureUtc);
        candidate.departureTimezone = "Not/A-Timezone";
        expect(validate(candidate, currentUtc).REASON).toBe("INVALID_DEPARTURE_TIMEZONE");

        candidate = baseCandidate(departureUtc);
        candidate.userId = 0;
        expect(validate(candidate, currentUtc).REASON).toBe("MISSING_OWNER");

        candidate = baseCandidate(departureUtc);
        candidate.ownerEmail = "not-an-email";
        expect(validate(candidate, currentUtc).REASON).toBe("INVALID_OWNER_EMAIL");

        candidate = baseCandidate(departureUtc);
        candidate.routeInstanceId = 0;
        expect(validate(candidate, currentUtc).REASON).toBe("MISSING_ROUTE_INSTANCE");
      });

      it("suppresses actual start, canonical progress, completion, and terminal plan states", function() {
        var departureUtc = createDateTime(2026, 9, 1, 16, 0, 0);
        var currentUtc = dateAdd("h", -2, departureUtc);
        var candidate = baseCandidate(departureUtc);
        var terminalStatus = "";

        candidate.startedAt = dateAdd("n", -1, currentUtc);
        expect(validate(candidate, currentUtc).REASON).toBe("TRIP_ALREADY_STARTED");

        candidate = baseCandidate(departureUtc);
        candidate.routeProgressStarted = true;
        expect(validate(candidate, currentUtc).REASON).toBe("ROUTE_PROGRESS_ALREADY_STARTED");

        candidate = baseCandidate(departureUtc);
        candidate.completedAt = currentUtc;
        expect(validate(candidate, currentUtc).REASON).toBe("ROUTE_COMPLETED");

        candidate = baseCandidate(departureUtc);
        candidate.routeStatus = "COMPLETED";
        expect(validate(candidate, currentUtc).REASON).toBe("ROUTE_COMPLETED");

        for (terminalStatus in ["DRAFT", "CLOSED", "CANCELLED", "CANCELED", "EXPIRED"]) {
          candidate = baseCandidate(departureUtc);
          candidate.planStatus = terminalStatus;
          expect(validate(candidate, currentUtc).ELIGIBLE).toBeFalse();
        }

        candidate = baseCandidate(departureUtc);
        candidate.closedAt = currentUtc;
        expect(validate(candidate, currentUtc).REASON).toBe("PLAN_CLOSED");

        candidate = baseCandidate(departureUtc);
        candidate.expiredAt = currentUtc;
        expect(validate(candidate, currentUtc).REASON).toBe("PLAN_EXPIRED");
      });

      it("suppresses not-started after an actual start occurring after the pre-reminder", function() {
        var departureUtc = createDateTime(2026, 9, 1, 16, 0, 0);
        var candidate = baseCandidate(departureUtc);
        var preResult = validate(candidate, dateAdd("h", -2, departureUtc), "PRE_DEPARTURE");

        candidate.startedAt = dateAdd("n", 5, departureUtc);
        expect(preResult.ELIGIBLE).toBeTrue();
        expect(validate(candidate, dateAdd("n", 30, departureUtc), "NOT_STARTED").REASON)
          .toBe("TRIP_ALREADY_STARTED");
      });

      it("gives a rescheduled departure a distinct occurrence identity", function() {
        var departureA = "2026-09-01 16:00:00";
        var departureB = "2026-09-01 18:30:00";
        var keyA = variables.service.buildOccurrenceKey(42, "PRE_DEPARTURE", departureA);
        var keyB = variables.service.buildOccurrenceKey(42, "PRE_DEPARTURE", departureB);
        var notStartedKey = variables.service.buildOccurrenceKey(42, "NOT_STARTED", departureA);

        expect(keyA).notToBe(keyB);
        expect(keyA).notToBe(notStartedKey);
        expect(len(keyA)).toBe(64);
      });

      it("permits one simulated concurrent claimant and blocks the second", function() {
        var workerA = variables.service.resolveClaimState(true, "CLAIMED", 1);
        var workerB = variables.service.resolveClaimState(false, "CLAIMED", 1);
        var sentReplay = variables.service.resolveClaimState(false, "SENT", 1);
        var retry = variables.service.resolveClaimState(false, "FAILED", 1);
        var exhausted = variables.service.resolveClaimState(false, "FAILED", 3);

        expect(workerA.CLAIMED).toBeTrue();
        expect(workerB.CLAIMED).toBeFalse();
        expect(sentReplay.CLAIMED).toBeFalse();
        expect(retry.CLAIMED).toBeTrue();
        expect(retry.RETRY).toBeTrue();
        expect(exhausted.CLAIMED).toBeFalse();
      });

      it("uses the injected owner-only mail service without reaching SMTP", function() {
        var candidate = baseCandidate(createDateTime(2026, 9, 1, 16, 0, 0));
        var calls = [];
        var emailResult = {};

        candidate.reminderType = "PRE_DEPARTURE";
        candidate.scheduledDepartureLabel = "Sep 1, 2026 12:00 PM";
        makePublic(variables.service, "sendReminderEmail", "sendReminderEmailForTest");
        emailResult = variables.service.sendReminderEmailForTest(candidate);
        calls = variables.mailStub.getCalls();

        expect(emailResult.success).toBeTrue();
        expect(arrayLen(calls)).toBe(1);
        expect(calls[1].toEmail).toBe(candidate.ownerEmail);
        expect(calls[1].floatPlanId).toBe(candidate.floatPlanId);
        expect(calls[1].reminderType).toBe("PRE_DEPARTURE");
      });

      it("builds both centralized multipart variants with one Active Cruise action", function() {
        var emailService = createObject("component", "fpw.api.v1.email").init();
        var pre = {};
        var notStarted = {};

        makePublic(emailService, "buildDepartureReminderEmail", "buildDepartureReminderEmailForTest");
        pre = emailService.buildDepartureReminderEmailForTest(
          42,
          "Harbor Run",
          "Sep 1, 2026 12:00 PM",
          "America/New_York",
          "PRE_DEPARTURE"
        );
        notStarted = emailService.buildDepartureReminderEmailForTest(
          42,
          "Harbor Run",
          "Sep 1, 2026 12:00 PM",
          "America/New_York",
          "NOT_STARTED"
        );

        expect(pre.subject).toBe("Your FloatPlanWizard trip is coming up");
        expect(notStarted.subject).toBe("Your scheduled trip has not started yet");
        expect(pre.ctaPath).toBe("/app/active-cruise.cfm?floatPlanId=42");
        expect(notStarted.ctaPath).toBe(pre.ctaPath);
        expect(countOccurrences(pre.htmlBody, ">Open Active Cruise</a>")).toBe(1);
        expect(countOccurrences(notStarted.htmlBody, ">Open Active Cruise</a>")).toBe(1);
        expect(findNoCase("America/New_York", pre.textBody)).toBeGT(0);
        expect(findNoCase("has not recorded an actual trip start", notStarted.textBody)).toBeGT(0);
        expect(findNoCase("emergency", pre.textBody)).toBe(0);
        expect(findNoCase("emergency", notStarted.textBody)).toBe(0);
      });

      it("enforces the database claim and preserves existing systems by source contract", function() {
        var serviceSource = readRepoFile("api/v1/DepartureReminderService.cfc");
        var migrationSource = readRepoFile("database/migrations/20260831_001_departure_reminder_deliveries.up.sql");
        var runnerSource = readRepoFile("app/scheduled/run-departure-reminders.cfm");
        var emailSource = readRepoFile("api/v1/email.cfc");

        expect(findNoCase("uq_departure_reminder_deliveries_occurrence", migrationSource)).toBeGT(0);
        expect(findNoCase("UNIQUE KEY", migrationSource)).toBeGT(0);
        expect(findNoCase("INSERT IGNORE INTO departure_reminder_deliveries", serviceSource)).toBeGT(0);
        expect(findNoCase("SELECT ROW_COUNT() AS inserted_count", serviceSource)).toBeGT(0);
        expect(findNoCase("FOR UPDATE", serviceSource)).toBeGT(0);
        expect(findNoCase("ri.started_at IS NULL", serviceSource)).toBeGT(0);
        expect(findNoCase("route_instance_leg_progress", serviceSource)).toBeGT(0);
        expect(findNoCase("fp.departureTimeUTC", serviceSource)).toBeGT(0);
        expect(findNoCase("getScheduledStartStateForFloatPlan", serviceSource)).toBe(0);
        expect(findNoCase("floatplancontacts", serviceSource)).toBe(0);
        expect(findNoCase("ProductEventService", serviceSource)).toBe(0);
        expect(findNoCase("application.monitorToken", runnerSource)).toBeGT(0);
        expect(findNoCase("sendMultipartEmail(", emailSource)).toBeGT(0);
        expect(findNoCase("sendDepartureReminderEmail", emailSource)).toBeGT(0);
      });
    });
  }

  private struct function baseCandidate(required date departureUtc) {
    return {
      floatPlanId = 42,
      userId = 7,
      floatPlanName = "Harbor Run",
      planStatus = "ACTIVE",
      closedAt = "",
      expiredAt = "",
      routeInstanceId = 99,
      departureTimeUtc = arguments.departureUtc,
      scheduledDepartureUtcKey = dateTimeFormat(arguments.departureUtc, "yyyy-mm-dd HH:nn:ss"),
      departureTimezone = "US/Eastern",
      ownerEmail = "captain@example.test",
      routeStatus = "PLANNED",
      startedAt = "",
      completedAt = "",
      routeProgressStarted = false,
      reminderType = "PRE_DEPARTURE"
    };
  }

  private struct function validate(
    required struct candidate,
    required date currentUtc,
    string reminderType="PRE_DEPARTURE"
  ) {
    return variables.service.validateCandidateForReminder(
      arguments.candidate,
      arguments.reminderType,
      arguments.currentUtc
    );
  }

  private numeric function countOccurrences(required string source, required string token) {
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
}
