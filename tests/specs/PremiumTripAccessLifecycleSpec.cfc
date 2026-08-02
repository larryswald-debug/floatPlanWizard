component extends="testbox.system.BaseSpec" output="false" {

  variables.datasource = "fpw";
  variables.fixtureEmailPrefix = "codex-premium-trip-lifecycle-";

  function beforeAll() {
    cleanupFixtures();
  }

  function afterAll() {
    cleanupFixtures();
  }

  function run() {
    describe("Premium single-trip 21-day lifecycle contract", function() {

      beforeEach(function() {
        cleanupFixtures();
        variables.creditService = createObject(
          "component",
          "fpw.api.v1.PremiumSendCreditService"
        ).init(variables.datasource);
        variables.tripAccessService = createObject(
          "component",
          "fpw.api.v1.PremiumTripAccessService"
        ).init(variables.datasource);
        variables.gateService = createObject(
          "component",
          "fpw.api.v1.MemberAccessGateService"
        ).init(variables.datasource);
      });

      afterEach(function() {
        cleanupFixtures();
      });

      it("requires the additive lifecycle schema, constraints, indexes, and reversible migration contract", function() {
        var qColumns = queryExecute(
          "SELECT COUNT(*) AS column_count
           FROM information_schema.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE()
             AND (
               (TABLE_NAME = 'premium_send_receipts' AND COLUMN_NAME IN (
                 'member_entitlement_id', 'membership_interval_snapshot',
                 'access_started_at_utc', 'access_expires_at_utc',
                 'access_ended_at_utc', 'access_end_reason'
               ))
               OR (TABLE_NAME = 'floatplans' AND COLUMN_NAME IN ('expiredAt', 'end_reason'))
             )",
          {},
          { datasource = variables.datasource }
        );
        var qConstraints = queryExecute(
          "SELECT COUNT(*) AS constraint_count
           FROM information_schema.TABLE_CONSTRAINTS
           WHERE CONSTRAINT_SCHEMA = DATABASE()
             AND CONSTRAINT_NAME IN (
               'fk_premium_send_receipts_entitlement_binding',
               'chk_premium_send_receipts_access_window',
               'chk_premium_send_receipts_membership_snapshot',
               'chk_premium_send_receipts_access_end',
               'chk_floatplans_expired_lifecycle'
             )",
          {},
          { datasource = variables.datasource }
        );
        var qIndexes = queryExecute(
          "SELECT COUNT(DISTINCT CONCAT(TABLE_NAME, ':', INDEX_NAME)) AS index_count
           FROM information_schema.STATISTICS
           WHERE TABLE_SCHEMA = DATABASE()
             AND INDEX_NAME IN (
               'uq_member_entitlements_receipt_binding',
               'ix_premium_send_receipts_due_access',
               'ix_premium_send_receipts_entitlement_binding'
             )",
          {},
          { datasource = variables.datasource }
        );
        var upSource = readRepoFile("database/migrations/20260801_001_single_trip_access_lifecycle.up.sql");
        var downSource = readRepoFile("database/migrations/20260801_001_single_trip_access_lifecycle.down.sql");
        var preflightSource = readRepoFile("database/migrations/20260801_001_single_trip_access_lifecycle.preflight.sql");
        var verifySource = readRepoFile("database/migrations/20260801_001_single_trip_access_lifecycle.verify.sql");

        expect(val(qColumns.column_count[1])).toBe(8);
        expect(val(qConstraints.constraint_count[1])).toBe(5);
        expect(val(qIndexes.index_count[1])).toBe(3);
        expect(findNoCase("DATE_ADD(@fpw_up_20260801_001_deployment_utc, INTERVAL 21 DAY)", upSource)).toBeGT(0);
        expect(findNoCase("DATE_ADD(c.consumed_at_utc, INTERVAL 21 DAY)", upSource)).toBeGT(0);
        expect(findNoCase("chk_floatplans_expired_lifecycle", upSource)).toBeGT(0);
        expect(findNoCase("UPPER(TRIM(fp.status)) = 'EXPIRED'", downSource)).toBeGT(0);
        expect(findNoCase("active_unclassified", preflightSource)).toBeGT(0);
        expect(findNoCase("access_expires_at_utc <> DATE_ADD(r.access_started_at_utc, INTERVAL 21 DAY)", verifySource)).toBeGT(0);
        expect(findNoCase("ENFORCED = ''YES''", verifySource)).toBeGT(0);
        expect(findNoCase("enforced_phase1_checks", verifySource)).toBeGT(0);
      });

      it("creates the same immutable 504-hour window for all four approved credit sources", function() {
        var sources = [
          "complimentary_signup",
          "stripe_one_trip",
          "promotion",
          "admin_grant"
        ];
        var sourceName = "";
        var lifecycle = {};
        var qWindow = queryNew("");
        var firstReplay = {};
        var secondReplay = {};
        var exactGate = {};
        var otherGate = {};

        for (sourceName in sources) {
          lifecycle = createCreditLifecycle(sourceName, sourceName);
          qWindow = loadWindow(lifecycle.fixture.planAId);
          firstReplay = variables.creditService.loadCompletedReceipt(
            lifecycle.fixture.userId,
            lifecycle.fixture.planAId
          );
          secondReplay = variables.creditService.loadCompletedReceipt(
            lifecycle.fixture.userId,
            lifecycle.fixture.planAId
          );
          exactGate = variables.gateService.requireTripOperationalAccess(
            lifecycle.fixture.userId,
            lifecycle.fixture.planAId
          );
          otherGate = variables.gateService.requireTripOperationalAccess(
            lifecycle.fixture.userId,
            lifecycle.fixture.planBId
          );

          expect(lifecycle.credit.source).toBe(sourceName);
          expect(lifecycle.receipt.accessSource).toBe("premium_send_credit");
          expect(val(qWindow.window_hours[1])).toBe(504);
          expect(val(qWindow.window_seconds[1])).toBe(1814400);
          expect(val(qWindow.start_matches_consumption[1])).toBe(1);
          expect(firstReplay.receiptId).toBe(secondReplay.receiptId);
          expect(toString(firstReplay.accessStartedAtUtc)).toBe(toString(secondReplay.accessStartedAtUtc));
          expect(toString(firstReplay.accessExpiresAtUtc)).toBe(toString(secondReplay.accessExpiresAtUtc));
          expect(exactGate.tripAccess.reasonCode).toBe("TRIP_ACCESS_ACTIVE");
          expect(exactGate.allowed).toBeTrue();
          expect(exactGate.tripAccess.accessSource).toBe("premium_send_credit");
          expect(otherGate.allowed).toBeFalse();
          expect(otherGate.response.errorCode).toBe("TRIP_ACCESS_RECORD_MISSING");
          expect(variables.creditService.countAvailableCredits(lifecycle.fixture.userId)).toBe(0);
        }
      });

      it("enforces the database UTC boundary immediately before and at expiry", function() {
        var lifecycle = createCreditLifecycle("boundary", "promotion");
        var futureAccess = {};
        var dueAccess = {};
        var qBoundary = queryNew("");

        setCreditWindowOffset(lifecycle.fixture.planAId, 60);
        futureAccess = variables.tripAccessService.getTripOperationalAccess(
          lifecycle.fixture.userId,
          lifecycle.fixture.planAId,
          false
        );
        qBoundary = loadWindow(lifecycle.fixture.planAId);
        expect(futureAccess.reasonCode).toBe("TRIP_ACCESS_ACTIVE");
        expect(futureAccess.allowed).toBeTrue();
        expect(val(qBoundary.window_hours[1])).toBe(504);
        expect(val(qBoundary.is_due[1])).toBe(0);

        setCreditWindowOffset(lifecycle.fixture.planAId, 0);
        qBoundary = loadWindow(lifecycle.fixture.planAId);
        dueAccess = variables.tripAccessService.getTripOperationalAccess(
          lifecycle.fixture.userId,
          lifecycle.fixture.planAId,
          false
        );
        expect(val(qBoundary.is_due[1])).toBe(1);
        expect(dueAccess.allowed).toBeFalse();
        expect(dueAccess.reasonCode).toBe("TRIP_ACCESS_EXPIRED");
        expect(dueAccess.isExpired).toBeTrue();
      });

      it("denies consumed credits and general memberships that have no exact plan receipt", function() {
        var creditFixture = createFixture("missing-credit-receipt");
        var membershipFixture = createFixture("missing-membership-receipt");
        var granted = variables.creditService.grantCredit(
          creditFixture.userId,
          "admin_grant",
          creditFixture.marker & ":grant"
        );
        var consumed = {};
        var entitlementId = 0;
        var creditAccess = {};
        var membershipAccess = {};

        activatePlan(creditFixture.userId, creditFixture.planAId);
        consumed = variables.creditService.consumeLockedCredit(
          granted.creditId,
          creditFixture.userId,
          creditFixture.planAId
        );
        entitlementId = createMembershipEntitlement(membershipFixture, "monthly");
        activatePlan(membershipFixture.userId, membershipFixture.planAId);
        creditAccess = variables.tripAccessService.getTripOperationalAccess(
          creditFixture.userId,
          creditFixture.planAId,
          false
        );
        membershipAccess = variables.tripAccessService.getTripOperationalAccess(
          membershipFixture.userId,
          membershipFixture.planAId,
          false
        );

        expect(consumed.SUCCESS).toBeTrue();
        expect(entitlementId).toBeGT(0);
        expect(creditAccess.allowed).toBeFalse();
        expect(creditAccess.reasonCode).toBe("TRIP_ACCESS_RECORD_MISSING");
        expect(membershipAccess.allowed).toBeFalse();
        expect(membershipAccess.reasonCode).toBe("TRIP_ACCESS_RECORD_MISSING");
      });

      it("binds Monthly and Annual receipts to their exact entitlement without a trip expiry", function() {
        var intervals = ["monthly", "annual"];
        var intervalName = "";
        var fixture = {};
        var entitlementId = 0;
        var receipt = {};
        var access = {};

        for (intervalName in intervals) {
          fixture = createFixture("membership-" & intervalName);
          entitlementId = createMembershipEntitlement(fixture, intervalName);
          activatePlan(fixture.userId, fixture.planAId);
          receipt = variables.creditService.recordCompletedReceipt(
            userId = fixture.userId,
            floatPlanId = fixture.planAId,
            creditId = 0,
            accessSource = "general_premium",
            recipientCount = 1,
            response = { SUCCESS = true, marker = fixture.marker }
          );
          access = variables.tripAccessService.getTripOperationalAccess(
            fixture.userId,
            fixture.planAId,
            false
          );

          expect(receipt.SUCCESS).toBeTrue();
          expect(receipt.memberEntitlementId).toBe(entitlementId);
          expect(receipt.membershipIntervalSnapshot).toBe(intervalName);
          expect(len(toString(receipt.accessExpiresAtUtc))).toBe(0);
          expect(access.allowed).toBeTrue();
          expect(access.accessSource).toBe("general_premium");
        }
      });

      it("keeps the original credit deadline during override and restores only its exact remaining authority", function() {
        var dueLifecycle = createCreditLifecycle("membership-override-due", "stripe_one_trip");
        var dueEntitlementId = createMembershipEntitlement(dueLifecycle.fixture, "monthly");
        var originalWindow = {};
        var overrideAccess = {};
        var storedDuringOverride = {};
        var expiredAfterMembership = {};
        var futureLifecycle = createCreditLifecycle("membership-override-future", "promotion");
        var futureEntitlementId = createMembershipEntitlement(futureLifecycle.fixture, "annual");
        var restoredAccess = {};
        var unrelatedGrant = {};

        setCreditWindowOffset(dueLifecycle.fixture.planAId, 0);
        originalWindow = loadWindow(dueLifecycle.fixture.planAId);
        overrideAccess = variables.tripAccessService.getTripOperationalAccess(
          dueLifecycle.fixture.userId,
          dueLifecycle.fixture.planAId,
          true
        );
        storedDuringOverride = loadWindow(dueLifecycle.fixture.planAId);
        expect(overrideAccess.allowed).toBeTrue();
        expect(overrideAccess.reasonCode).toBe("TRIP_ACCESS_MEMBERSHIP_OVERRIDE");
        expect(toString(storedDuringOverride.access_expires_at_utc[1])).toBe(toString(originalWindow.access_expires_at_utc[1]));
        expect(val(storedDuringOverride.end_is_null[1])).toBe(1);

        deactivateEntitlement(dueEntitlementId);
        expiredAfterMembership = variables.tripAccessService.getTripOperationalAccess(
          dueLifecycle.fixture.userId,
          dueLifecycle.fixture.planAId,
          false
        );
        expect(expiredAfterMembership.allowed).toBeFalse();
        expect(expiredAfterMembership.reasonCode).toBe("TRIP_ACCESS_EXPIRED");

        setCreditWindowOffset(futureLifecycle.fixture.planAId, 300);
        deactivateEntitlement(futureEntitlementId);
        unrelatedGrant = variables.creditService.grantCredit(
          futureLifecycle.fixture.userId,
          "admin_grant",
          futureLifecycle.fixture.marker & ":unrelated"
        );
        restoredAccess = variables.tripAccessService.getTripOperationalAccess(
          futureLifecycle.fixture.userId,
          futureLifecycle.fixture.planAId,
          false
        );
        expect(unrelatedGrant.status).toBe("AVAILABLE");
        expect(restoredAccess.allowed).toBeTrue();
        expect(restoredAccess.accessSource).toBe("premium_send_credit");
      });

      it("does not let an unrelated credit preserve a membership-origin trip after membership ends", function() {
        var fixture = createFixture("membership-ended");
        var entitlementId = createMembershipEntitlement(fixture, "monthly");
        var receipt = {};
        var availableCredit = {};
        var access = {};

        activatePlan(fixture.userId, fixture.planAId);
        receipt = variables.creditService.recordCompletedReceipt(
          fixture.userId,
          fixture.planAId,
          0,
          "general_premium",
          1,
          { SUCCESS = true, marker = fixture.marker }
        );
        availableCredit = variables.creditService.grantCredit(
          fixture.userId,
          "complimentary_signup",
          fixture.marker & ":available"
        );
        deactivateEntitlement(entitlementId);
        access = variables.tripAccessService.getTripOperationalAccess(
          fixture.userId,
          fixture.planAId,
          false
        );

        expect(receipt.SUCCESS).toBeTrue();
        expect(availableCredit.status).toBe("AVAILABLE");
        expect(access.allowed).toBeFalse();
        expect(access.reasonCode).toBe("MEMBERSHIP_REQUIRED");
      });

      it("expires without a monitoring row, remains idempotent, and does not consume or restore another credit", function() {
        var lifecycle = createCreditLifecycle("no-monitor", "admin_grant");
        var spareCredit = variables.creditService.grantCredit(
          lifecycle.fixture.userId,
          "promotion",
          lifecycle.fixture.marker & ":spare"
        );
        var first = {};
        var second = {};
        var qState = queryNew("");
        var monitoringNoop = createObject("component", "fpw.api.v1.monitor")
          .init(variables.datasource)
          .closeMonitoringForFloatPlan(lifecycle.fixture.planAId, "SINGLE_TRIP_LIMIT");
        var monitorStub = createObject(
          "component",
          "fpw.tests.support.PremiumTripAccessMonitoringStub"
        ).init(true);
        var lifecycleService = createObject(
          "component",
          "fpw.api.v1.PremiumTripAccessService"
        ).init(variables.datasource, monitorStub);

        setCreditWindowOffset(lifecycle.fixture.planAId, 0);
        first = lifecycleService.expireSingleTripAccess(
          lifecycle.fixture.planAId,
          "manual_test"
        );
        second = lifecycleService.expireSingleTripAccess(
          lifecycle.fixture.planAId,
          "manual_test"
        );
        qState = loadLifecycleState(lifecycle.fixture.planAId, spareCredit.creditId);

        expect(monitoringNoop.SUCCESS).toBeTrue();
        expect(monitoringNoop.CLOSED).toBeFalse();
        expect(first.reasonCode).toBe("TRIP_ACCESS_EXPIRED");
        expect(first.SUCCESS).toBeTrue();
        expect(first.transitioned).toBeTrue();
        expect(second.SUCCESS).toBeTrue();
        expect(second.transitioned).toBeFalse();
        expect(second.alreadyEnded).toBeTrue();
        expect(qState.plan_status[1]).toBe("EXPIRED");
        expect(qState.end_reason[1]).toBe("SINGLE_TRIP_LIMIT");
        expect(val(qState.expired_is_null[1])).toBe(0);
        expect(val(qState.closed_is_null[1])).toBe(1);
        expect(qState.spare_credit_status[1]).toBe("AVAILABLE");
      });

      it("serializes two concurrent expiration workers into one lifecycle transition", function() {
        var lifecycle = createCreditLifecycle("concurrent-workers", "promotion");
        var monitoringId = createMonitoringFixture(lifecycle.fixture, "ACTIVE", false);
        var threadToken = replace(createUUID(), "-", "", "all");
        var firstThreadName = "fpw_trip_expire_a_" & threadToken;
        var secondThreadName = "fpw_trip_expire_b_" & threadToken;
        var firstResult = {};
        var secondResult = {};
        var qState = queryNew("");
        var qMonitoring = queryNew("");
        var transitionCount = 0;
        var alreadyEndedCount = 0;

        setCreditWindowOffset(lifecycle.fixture.planAId, 0);

        thread
          name = firstThreadName
          action = "run"
          datasource = variables.datasource
          floatPlanId = lifecycle.fixture.planAId
        {
          var service = createObject(
            "component",
            "fpw.api.v1.PremiumTripAccessService"
          ).init(attributes.datasource);
          thread.result = service.expireSingleTripAccess(
            attributes.floatPlanId,
            "scheduled_worker"
          );
        }

        thread
          name = secondThreadName
          action = "run"
          datasource = variables.datasource
          floatPlanId = lifecycle.fixture.planAId
        {
          var service = createObject(
            "component",
            "fpw.api.v1.PremiumTripAccessService"
          ).init(attributes.datasource);
          thread.result = service.expireSingleTripAccess(
            attributes.floatPlanId,
            "scheduled_worker"
          );
        }

        thread action = "join" name = firstThreadName;
        thread action = "join" name = secondThreadName;

        firstResult = cfthread[firstThreadName].result;
        secondResult = cfthread[secondThreadName].result;
        transitionCount = (firstResult.transitioned ? 1 : 0) + (secondResult.transitioned ? 1 : 0);
        alreadyEndedCount = (firstResult.alreadyEnded ? 1 : 0) + (secondResult.alreadyEnded ? 1 : 0);
        qState = loadLifecycleState(lifecycle.fixture.planAId, 0);
        qMonitoring = loadMonitoringState(monitoringId);

        expect(firstResult.SUCCESS).toBeTrue();
        expect(secondResult.SUCCESS).toBeTrue();
        expect(transitionCount).toBe(1);
        expect(alreadyEndedCount).toBe(1);
        expect(qState.plan_status[1]).toBe("EXPIRED");
        expect(qState.end_reason[1]).toBe("SINGLE_TRIP_LIMIT");
        expect(val(qMonitoring.close_event_count[1])).toBe(1);
      });

      it("continues a scheduled batch after one row fails and reports sanitized counts", function() {
        var failingLifecycle = createCreditLifecycle("batch-failure", "admin_grant");
        var succeedingLifecycle = createCreditLifecycle("batch-success", "complimentary_signup");
        var monitorStub = createObject(
          "component",
          "fpw.tests.support.PremiumTripAccessMonitoringStub"
        ).init(true, failingLifecycle.fixture.planAId);
        var workerService = createObject(
          "component",
          "fpw.api.v1.PremiumTripAccessService"
        ).init(variables.datasource, monitorStub);
        var result = {};
        var failingState = queryNew("");
        var succeedingState = queryNew("");

        setCreditWindowOffset(failingLifecycle.fixture.planAId, -60);
        setCreditWindowOffset(succeedingLifecycle.fixture.planAId, -30);
        result = workerService.processDueExpirations(2);
        failingState = loadLifecycleState(failingLifecycle.fixture.planAId, 0);
        succeedingState = loadLifecycleState(succeedingLifecycle.fixture.planAId, 0);

        expect(result.SUCCESS).toBeFalse();
        expect(result.examined).toBe(2);
        expect(result.expired).toBe(1);
        expect(result.failed).toBe(1);
        expect(result.membership_overridden).toBe(0);
        expect(result.already_ended).toBe(0);
        expect(result.skipped).toBe(0);
        expect(failingState.plan_status[1]).toBe("ACTIVE");
        expect(val(failingState.receipt_end_is_null[1])).toBe(1);
        expect(succeedingState.plan_status[1]).toBe("EXPIRED");
        expect(val(succeedingState.receipt_end_is_null[1])).toBe(0);
      });

      it("closes LATE, MISSED, ESCALATED, and secure-for-night monitoring without erasing safety history", function() {
        var states = ["LATE", "MISSED", "ESCALATED", "ACTIVE"];
        var stateName = "";
        var lifecycle = {};
        var monitoringId = 0;
        var beforeState = queryNew("");
        var expiration = {};
        var replay = {};
        var afterState = queryNew("");

        for (stateName in states) {
          lifecycle = createCreditLifecycle("monitor-" & lCase(stateName), "admin_grant");
          monitoringId = createMonitoringFixture(
            lifecycle.fixture,
            stateName,
            stateName EQ "ACTIVE"
          );
          beforeState = loadMonitoringState(monitoringId);
          setCreditWindowOffset(lifecycle.fixture.planAId, 0);
          expiration = variables.tripAccessService.expireSingleTripAccess(
            lifecycle.fixture.planAId,
            "manual_test"
          );
          replay = variables.tripAccessService.expireSingleTripAccess(
            lifecycle.fixture.planAId,
            "manual_test"
          );
          afterState = loadMonitoringState(monitoringId);

          expect(expiration.reasonCode).toBe("TRIP_ACCESS_EXPIRED");
          expect(expiration.SUCCESS).toBeTrue();
          expect(expiration.transitioned).toBeTrue();
          expect(replay.SUCCESS).toBeTrue();
          expect(afterState.monitor_state[1]).toBe("CLOSED");
          expect(val(afterState.is_monitoring_enabled[1])).toBe(0);
          expect(val(afterState.secure_for_night[1])).toBe(0);
          expect(val(afterState.secure_until_is_null[1])).toBe(1);
          expect(toString(afterState.missed_at[1])).toBe(toString(beforeState.missed_at[1]));
          expect(toString(afterState.escalated_at[1])).toBe(toString(beforeState.escalated_at[1]));
          expect(val(afterState.resolved_is_null[1])).toBe(1);
          expect(val(afterState.assistance_event_count[1])).toBe(1);
          expect(val(afterState.close_event_count[1])).toBe(1);
          expect(findNoCase("SINGLE_TRIP_LIMIT", toString(afterState.close_meta[1]))).toBeGT(0);
        }
      });

      it("rolls back plan and receipt expiration when canonical monitoring close fails", function() {
        var lifecycle = createCreditLifecycle("rollback", "stripe_one_trip");
        var monitorStub = createObject(
          "component",
          "fpw.tests.support.PremiumTripAccessMonitoringStub"
        ).init(false);
        var service = createObject(
          "component",
          "fpw.api.v1.PremiumTripAccessService"
        ).init(variables.datasource, monitorStub);
        var result = {};
        var qState = queryNew("");
        var calls = [];

        setCreditWindowOffset(lifecycle.fixture.planAId, 0);
        result = service.expireSingleTripAccess(
          lifecycle.fixture.planAId,
          "manual_test"
        );
        qState = loadLifecycleState(lifecycle.fixture.planAId, 0);
        calls = monitorStub.getCalls();

        expect(result.SUCCESS).toBeFalse();
        expect(result.reasonCode).toBe("TRIP_EXPIRATION_FAILED");
        expect(arrayLen(calls)).toBe(1);
        expect(calls[1].floatPlanId).toBe(lifecycle.fixture.planAId);
        expect(calls[1].closeReason).toBe("SINGLE_TRIP_LIMIT");
        expect(qState.plan_status[1]).toBe("ACTIVE");
        expect(val(qState.expired_is_null[1])).toBe(1);
        expect(val(qState.receipt_end_is_null[1])).toBe(1);
      });

      it("returns stable expired reasons and keeps every required status consumer wired to exact access", function() {
        var lifecycle = createCreditLifecycle("consumer-reasons", "complimentary_signup");
        var expiration = {};
        var serviceAccess = {};
        var gateAccess = {};
        var activeCruiseSource = readRepoFile("api/v1/ActiveCruiseViewModelService.cfc");
        var companionSource = readRepoFile("api/v1/CompanionViewModelService.cfc");
        var monitoringConsoleSource = readRepoFile("api/v1/MonitoringConsoleViewModelService.cfc");
        var monitoringSource = readRepoFile("api/v1/monitor.cfc");
        var checkinSource = readRepoFile("api/v1/CompanionCheckinService.cfc");
        var routeSource = readRepoFile("api/v1/RouteProgressService.cfc");
        var paceSource = readRepoFile("api/v1/ActiveTripPaceService.cfc");
        var routeBuilderSource = readRepoFile("api/v1/routeBuilder.cfc");

        setCreditWindowOffset(lifecycle.fixture.planAId, 0);
        expiration = variables.tripAccessService.expireSingleTripAccess(
          lifecycle.fixture.planAId,
          "manual_test"
        );
        serviceAccess = variables.tripAccessService.getTripOperationalAccess(
          lifecycle.fixture.userId,
          lifecycle.fixture.planAId,
          false
        );
        gateAccess = variables.gateService.requireTripOperationalAccess(
          lifecycle.fixture.userId,
          lifecycle.fixture.planAId
        );

        expect(expiration.SUCCESS).toBeTrue();
        expect(serviceAccess.reasonCode).toBe("TRIP_ACCESS_EXPIRED");
        expect(gateAccess.allowed).toBeFalse();
        expect(gateAccess.response.errorCode).toBe("TRIP_ACCESS_EXPIRED");
        expect(findNoCase('tripState = "expired_access"', activeCruiseSource)).toBeGT(0);
        expect(findNoCase('result.ERROR NEQ "TRIP_ACCESS_EXPIRED"', companionSource)).toBeGT(0);
        expect(findNoCase('case "TRIP_ACCESS_EXPIRED"', monitoringConsoleSource)).toBeGT(0);
        expect(findNoCase("'CANCELED','EXPIRED'", monitoringSource)).toBeGT(0);
        expect(findNoCase("requireTripOperationalAccessForUpdate", checkinSource)).toBeGT(0);
        expect(findNoCase("requireTripOperationalAccessForUpdate", routeSource)).toBeGT(0);
        expect(findNoCase("requireTripOperationalAccess", paceSource)).toBeGT(0);
        expect(findNoCase("SELECT ri.id, ri.routegen_inputs_json", paceSource)).toBeGT(0);
        expect(findNoCase("FOR UPDATE", paceSource)).toBeGT(0);
        expect(findNoCase("requireTripOperationalAccessForUpdate", routeBuilderSource)).toBeGT(0);
        expect(findNoCase("var newKeyNames = structKeyArray(preservedInputs)", routeBuilderSource)).toBeGT(0);
        expect(findNoCase('"SELECT id" & (hasInputsJsonCol ? ", routegen_inputs_json" : "")', routeBuilderSource)).toBeGT(0);
        expect(findNoCase("SELECT ri.routegen_inputs_json", routeBuilderSource)).toBeGT(0);
      });

      it("keeps the Phase 1 UI minimal and the scheduled worker independently token-protected", function() {
        var dashboardSource = readRepoFile("assets/js/app/dashboard/floatplans.js");
        var activeCruisePage = readRepoFile("app/active-cruise.cfm");
        var floatplanSource = readRepoFile("api/v1/floatplan.cfc");
        var runnerSource = readRepoFile("app/scheduled/run-single-trip-expiration.cfm");
        var serviceSource = readRepoFile("api/v1/PremiumTripAccessService.cfc");
        var validRunnerResponse = {};
        var validRunnerPayload = {};
        var serializedRunnerPayload = "";

        expect(findNoCase('normalized === "EXPIRED"', dashboardSource)).toBeGT(0);
        expect(findNoCase("expired_access", activeCruisePage)).toBeGT(0);
        expect(findNoCase("ACCESS_EXPIRES_AT_UTC", floatplanSource)).toBeGT(0);
        expect(findNoCase("application.monitorToken", runnerSource)).toBeGT(0);
        expect(findNoCase("processDueExpirations", runnerSource)).toBeGT(0);
        expect(findNoCase("access_expires_at_utc <= UTC_TIMESTAMP(6)", serviceSource)).toBeGT(0);
        expect(findNoCase("route_instance_legs", serviceSource)).toBe(0);
        expect(findNoCase("premium_send_credits SET status = 'AVAILABLE'", serviceSource)).toBe(0);

        expect(structKeyExists(application, "monitorToken")).toBeTrue();
        expect(len(trim(toString(application.monitorToken)))).toBeGT(0);
        cfhttp(
          method = "GET",
          url = "http://localhost:8500/fpw/app/scheduled/run-single-trip-expiration.cfm",
          result = "validRunnerResponse",
          timeout = 20,
          throwOnError = false
        ) {
          cfhttpparam(type = "url", name = "token", value = application.monitorToken);
          cfhttpparam(type = "url", name = "limit", value = 1);
        }
        validRunnerPayload = deserializeJSON(toString(validRunnerResponse.fileContent));
        serializedRunnerPayload = serializeJSON(validRunnerPayload);
        expect(val(validRunnerResponse.statusCode)).toBe(200);
        expect(validRunnerPayload.SUCCESS).toBeTrue();
        expect(validRunnerPayload.examined).toBeGTE(0);
        expect(validRunnerPayload.expired).toBeGTE(0);
        expect(validRunnerPayload.failed).toBeGTE(0);
        expect(findNoCase("token", serializedRunnerPayload)).toBe(0);
        expect(findNoCase("@", serializedRunnerPayload)).toBe(0);
      });

    });
  }

  private struct function createCreditLifecycle(required string label, required string source) {
    var fixture = createFixture(arguments.label);
    var credit = {};
    var consumed = {};
    var receipt = {};

    activatePlan(fixture.userId, fixture.planAId);
    credit = variables.creditService.grantCredit(
      fixture.userId,
      arguments.source,
      fixture.marker & ":grant"
    );
    consumed = variables.creditService.consumeLockedCredit(
      credit.creditId,
      fixture.userId,
      fixture.planAId
    );
    receipt = variables.creditService.recordCompletedReceipt(
      userId = fixture.userId,
      floatPlanId = fixture.planAId,
      creditId = credit.creditId,
      accessSource = "premium_send_credit",
      recipientCount = 1,
      response = { SUCCESS = true, marker = fixture.marker }
    );
    if (!credit.SUCCESS OR !consumed.SUCCESS OR !receipt.SUCCESS) {
      throw(
        type = "FPW.PremiumTripLifecycleFixture",
        message = "Disposable credit lifecycle could not be created."
      );
    }
    return {
      fixture = fixture,
      credit = credit,
      consumed = consumed,
      receipt = receipt
    };
  }

  private struct function createFixture(required string label) {
    var token = lCase(reReplace(createUUID(), "[^A-Za-z0-9]", "", "all"));
    var marker = variables.fixtureEmailPrefix & token;
    var email = marker & "@example.test";
    var qUser = queryNew("");
    var fixture = {};

    queryExecute(
      "INSERT INTO users (fName, lName, email, password, passwordCreated, created)
       VALUES ('Codex', 'Trip Lifecycle', :email, :password, UTC_TIMESTAMP(), UTC_TIMESTAMP())",
      {
        email = { value = email, cfsqltype = "cf_sql_varchar" },
        password = { value = hash(marker, "SHA-256"), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    qUser = queryExecute(
      "SELECT userId FROM users WHERE email = :email LIMIT 1",
      { email = { value = email, cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );
    fixture = {
      marker = marker,
      email = email,
      userId = val(qUser.userId[1])
    };
    fixture.planAId = createPlan(fixture.userId, arguments.label & " A " & token);
    fixture.planBId = createPlan(fixture.userId, arguments.label & " B " & token);
    return fixture;
  }

  private numeric function createPlan(required numeric userId, required string planName) {
    var qPlan = queryNew("");
    queryExecute(
      "INSERT INTO floatplans (
         userId, floatPlanName, dateCreated, lastUpdate, status, lastUpdateStatus
       ) VALUES (
         :userId, :planName, UTC_TIMESTAMP(), UTC_TIMESTAMP(), 'DRAFT', UTC_TIMESTAMP()
       )",
      {
        userId = { value = toString(val(arguments.userId)), cfsqltype = "cf_sql_varchar" },
        planName = { value = arguments.planName, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    qPlan = queryExecute(
      "SELECT floatPlanId
       FROM floatplans
       WHERE userId = :userId AND floatPlanName = :planName
       ORDER BY floatPlanId DESC LIMIT 1",
      {
        userId = { value = toString(val(arguments.userId)), cfsqltype = "cf_sql_varchar" },
        planName = { value = arguments.planName, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    return val(qPlan.floatPlanId[1]);
  }

  private void function activatePlan(required numeric userId, required numeric floatPlanId) {
    queryExecute(
      "UPDATE floatplans
       SET status = 'ACTIVE', activatedAt = UTC_TIMESTAMP(), lastUpdateStatus = UTC_TIMESTAMP()
       WHERE floatPlanId = :floatPlanId AND userId = :userId",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        userId = { value = toString(val(arguments.userId)), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
  }

  private numeric function createMembershipEntitlement(required struct fixture, required string intervalName) {
    var configService = createObject("component", "fpw.api.v1.StripeConfigService").init();
    var intervalValue = lCase(trim(arguments.intervalName));
    var priceId = intervalValue EQ "annual"
      ? configService.getPremiumYearlyPriceId()
      : configService.getPremiumMonthlyPriceId();
    var subscriptionId = "sub_lifecycle_" & arguments.fixture.userId & "_" & intervalValue;
    var qEntitlement = queryNew("");

    if (!len(trim(priceId))) {
      throw(type = "FPW.PremiumTripLifecycleFixture", message = "Recurring Stripe price ids are not configured.");
    }
    queryExecute(
      "INSERT INTO member_entitlements (
         user_id, entitlement_type, source, status, starts_at_utc, expires_at_utc,
         stripe_subscription_id, stripe_price_id, stripe_subscription_status,
         admin_notes, created_utc, updated_utc
       ) VALUES (
         :userId, 'premium', 'stripe_subscription', 'active',
         DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 DAY), DATE_ADD(UTC_TIMESTAMP(), INTERVAL 30 DAY),
         :subscriptionId, :priceId, 'active', :marker, UTC_TIMESTAMP(), UTC_TIMESTAMP()
       )",
      {
        userId = { value = arguments.fixture.userId, cfsqltype = "cf_sql_integer" },
        subscriptionId = { value = subscriptionId, cfsqltype = "cf_sql_varchar" },
        priceId = { value = priceId, cfsqltype = "cf_sql_varchar" },
        marker = { value = arguments.fixture.marker, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    qEntitlement = queryExecute(
      "SELECT id FROM member_entitlements WHERE stripe_subscription_id = :subscriptionId LIMIT 1",
      { subscriptionId = { value = subscriptionId, cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );
    return val(qEntitlement.id[1]);
  }

  private void function deactivateEntitlement(required numeric entitlementId) {
    queryExecute(
      "UPDATE member_entitlements
       SET status = 'revoked', revoked_at_utc = UTC_TIMESTAMP(),
           expires_at_utc = UTC_TIMESTAMP(), updated_utc = UTC_TIMESTAMP()
       WHERE id = :entitlementId",
      { entitlementId = { value = arguments.entitlementId, cfsqltype = "cf_sql_bigint" } },
      { datasource = variables.datasource }
    );
  }

  private void function setCreditWindowOffset(required numeric floatPlanId, required numeric offsetSeconds) {
    queryExecute(
      "UPDATE premium_send_credits c
       INNER JOIN premium_send_receipts r
         ON r.credit_id = c.id
        AND r.float_plan_id = c.consumed_float_plan_id
       SET c.consumed_at_utc = DATE_SUB(DATE_ADD(UTC_TIMESTAMP(6), INTERVAL :offsetSeconds SECOND), INTERVAL 21 DAY),
           r.access_started_at_utc = DATE_SUB(DATE_ADD(UTC_TIMESTAMP(6), INTERVAL :offsetSeconds SECOND), INTERVAL 21 DAY),
           r.access_expires_at_utc = DATE_ADD(UTC_TIMESTAMP(6), INTERVAL :offsetSeconds SECOND),
           r.access_ended_at_utc = NULL,
           r.access_end_reason = NULL
       WHERE r.float_plan_id = :floatPlanId",
      {
        offsetSeconds = { value = fix(arguments.offsetSeconds), cfsqltype = "cf_sql_integer" },
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );
  }

  private query function loadWindow(required numeric floatPlanId) {
    return queryExecute(
      "SELECT r.access_started_at_utc, r.access_expires_at_utc,
              TIMESTAMPDIFF(HOUR, r.access_started_at_utc, r.access_expires_at_utc) AS window_hours,
              TIMESTAMPDIFF(SECOND, r.access_started_at_utc, r.access_expires_at_utc) AS window_seconds,
              (r.access_started_at_utc = c.consumed_at_utc) AS start_matches_consumption,
              (r.access_expires_at_utc <= UTC_TIMESTAMP(6)) AS is_due,
              (r.access_ended_at_utc IS NULL) AS end_is_null
       FROM premium_send_receipts r
       INNER JOIN premium_send_credits c ON c.id = r.credit_id
       WHERE r.float_plan_id = :floatPlanId LIMIT 1",
      { floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" } },
      { datasource = variables.datasource }
    );
  }

  private numeric function createMonitoringFixture(
    required struct fixture,
    required string monitorState,
    boolean secureForNight=false
  ) {
    var qMonitor = queryNew("");
    var stateValue = uCase(trim(arguments.monitorState));
    queryExecute(
      "INSERT INTO floatplan_monitoring (
         float_plan_id, user_id, monitoring_mode, monitor_state,
         is_monitoring_enabled, expected_checkin_at, grace_expires_at,
         missed_at, escalated_at, resolved_at, secure_for_night,
         secure_for_night_until, next_monitor_eval_at
       ) VALUES (
         :floatPlanId, :userId, 'basic', :monitorState, 1,
         DATE_SUB(UTC_TIMESTAMP(), INTERVAL 2 HOUR),
         DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 HOUR),
         :missedAt, :escalatedAt, NULL, :secureForNight,
         :secureUntil, DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 HOUR)
       )",
      {
        floatPlanId = { value = arguments.fixture.planAId, cfsqltype = "cf_sql_integer" },
        userId = { value = arguments.fixture.userId, cfsqltype = "cf_sql_integer" },
        monitorState = { value = stateValue, cfsqltype = "cf_sql_varchar" },
        missedAt = {
          value = now(),
          null = !listFindNoCase("MISSED,ESCALATED", stateValue),
          cfsqltype = "cf_sql_timestamp"
        },
        escalatedAt = {
          value = now(),
          null = stateValue NEQ "ESCALATED",
          cfsqltype = "cf_sql_timestamp"
        },
        secureForNight = { value = arguments.secureForNight ? 1 : 0, cfsqltype = "cf_sql_tinyint" },
        secureUntil = {
          value = dateAdd("h", 8, now()),
          null = !arguments.secureForNight,
          cfsqltype = "cf_sql_timestamp"
        }
      },
      { datasource = variables.datasource }
    );
    qMonitor = queryExecute(
      "SELECT id FROM floatplan_monitoring WHERE float_plan_id = :floatPlanId LIMIT 1",
      { floatPlanId = { value = arguments.fixture.planAId, cfsqltype = "cf_sql_integer" } },
      { datasource = variables.datasource }
    );
    queryExecute(
      "INSERT INTO floatplan_monitor_events (
         monitoring_id, float_plan_id, user_id, event_type,
         event_at, checkin_status, actor_type, meta_json
       ) VALUES (
         :monitoringId, :floatPlanId, :userId, 'CHECKIN_RECEIVED',
         UTC_TIMESTAMP(), 'NEED_ATTENTION', 'captain', :metaJson
       )",
      {
        monitoringId = { value = val(qMonitor.id[1]), cfsqltype = "cf_sql_bigint" },
        floatPlanId = { value = arguments.fixture.planAId, cfsqltype = "cf_sql_integer" },
        userId = { value = arguments.fixture.userId, cfsqltype = "cf_sql_integer" },
        metaJson = { value = serializeJSON({ fixture = arguments.fixture.marker }), cfsqltype = "cf_sql_longvarchar" }
      },
      { datasource = variables.datasource }
    );
    return val(qMonitor.id[1]);
  }

  private query function loadMonitoringState(required numeric monitoringId) {
    return queryExecute(
      "SELECT fm.monitor_state, fm.is_monitoring_enabled, fm.secure_for_night,
              (fm.secure_for_night_until IS NULL) AS secure_until_is_null,
              fm.missed_at, fm.escalated_at,
              (fm.resolved_at IS NULL) AS resolved_is_null,
              SUM(e.event_type = 'CHECKIN_RECEIVED' AND e.checkin_status = 'NEED_ATTENTION') AS assistance_event_count,
              SUM(e.event_type = 'MONITORING_CLOSED') AS close_event_count,
              MAX(CASE WHEN e.event_type = 'MONITORING_CLOSED' THEN e.meta_json ELSE NULL END) AS close_meta
       FROM floatplan_monitoring fm
       LEFT JOIN floatplan_monitor_events e ON e.monitoring_id = fm.id
       WHERE fm.id = :monitoringId
       GROUP BY fm.id",
      { monitoringId = { value = arguments.monitoringId, cfsqltype = "cf_sql_bigint" } },
      { datasource = variables.datasource }
    );
  }

  private query function loadLifecycleState(required numeric floatPlanId, numeric spareCreditId=0) {
    return queryExecute(
      "SELECT UPPER(TRIM(fp.status)) AS plan_status, fp.end_reason,
              (fp.expiredAt IS NULL) AS expired_is_null,
              (fp.closedAt IS NULL) AS closed_is_null,
              (r.access_ended_at_utc IS NULL) AS receipt_end_is_null,
              COALESCE(c.status, '') AS spare_credit_status
       FROM floatplans fp
       INNER JOIN premium_send_receipts r ON r.float_plan_id = fp.floatPlanId
       LEFT JOIN premium_send_credits c ON c.id = :spareCreditId
       WHERE fp.floatPlanId = :floatPlanId LIMIT 1",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        spareCreditId = { value = arguments.spareCreditId, cfsqltype = "cf_sql_bigint" }
      },
      { datasource = variables.datasource }
    );
  }

  private string function readRepoFile(required string relativePath) {
    return fileRead(expandPath("/fpw/" & arguments.relativePath), "utf-8");
  }

  private void function cleanupFixtures() {
    var params = {
      emailPattern = {
        value = variables.fixtureEmailPrefix & "%",
        cfsqltype = "cf_sql_varchar"
      }
    };
    queryExecute(
      "DELETE FROM floatplan_monitor_events
       WHERE user_id IN (SELECT userId FROM users WHERE email LIKE :emailPattern)",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM floatplan_monitoring
       WHERE user_id IN (SELECT userId FROM users WHERE email LIKE :emailPattern)",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM premium_send_receipts
       WHERE user_id IN (SELECT userId FROM users WHERE email LIKE :emailPattern)",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM premium_send_credits
       WHERE user_id IN (SELECT userId FROM users WHERE email LIKE :emailPattern)",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM member_entitlements
       WHERE user_id IN (SELECT userId FROM users WHERE email LIKE :emailPattern)",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM floatplans
       WHERE userId IN (SELECT CAST(userId AS CHAR) FROM users WHERE email LIKE :emailPattern)",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM users WHERE email LIKE :emailPattern",
      params,
      { datasource = variables.datasource }
    );
  }

}
