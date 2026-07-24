component extends="testbox.system.BaseSpec" output="false" {

  variables.datasource = "fpw";
  variables.fixtureEmailPrefix = "codex-premium-send-contract-";

  function beforeAll() {
    cleanupFixtures();
  }

  function afterAll() {
    cleanupFixtures();
  }

  function run() {
    describe("Premium Send Credit service and access contract", function() {

      beforeEach(function() {
        cleanupFixtures();
        variables.creditService = createObject(
          "component",
          "fpw.api.v1.PremiumSendCreditService"
        ).init(variables.datasource);
        variables.entitlementService = createObject(
          "component",
          "fpw.api.v1.MemberEntitlementService"
        ).init(variables.datasource);
        variables.gateService = createObject(
          "component",
          "fpw.api.v1.MemberAccessGateService"
        ).init(variables.datasource);
      });

      afterEach(function() {
        cleanupFixtures();
      });

      it("treats every approved credit source as capability-equivalent", function() {
        var sources = [
          "complimentary_signup",
          "stripe_one_trip",
          "promotion",
          "admin_grant"
        ];
        var sourceName = "";
        var fixture = {};
        var granted = {};
        var availableAccess = {};
        var selected = {};
        var consumed = {};
        var consumedAccess = {};
        var exactGate = {};
        var unrelatedGate = {};

        for (sourceName in sources) {
          fixture = createFixture(sourceName);
          granted = variables.creditService.grantCredit(
            userId = fixture.userId,
            source = sourceName,
            idempotencyKey = fixture.marker & ":grant"
          );

          expect(granted.SUCCESS).toBeTrue();
          expect(granted.source).toBe(sourceName);
          expect(granted.status).toBe("AVAILABLE");
          expect(granted.consumedFloatPlanId).toBe(0);

          availableAccess = variables.gateService.getCurrentAccess(fixture.userId);
          expect(availableAccess.hasPremium).toBeFalse();
          expect(availableAccess.hasGeneralPremium).toBeFalse();
          expect(availableAccess.canSendPremiumFloatPlan).toBeTrue();
          expect(availableAccess.premiumSendAccessSource).toBe("premium_send_credit");
          expect(availableAccess.canUseActiveCruise).toBeFalse();
          expect(availableAccess.canUseMonitoring).toBeFalse();
          expect(availableAccess.canUseTripPage).toBeFalse();
          expect(availableAccess.canUseFollowPage).toBeFalse();

          setPlanStatus(fixture.userId, fixture.planAId, "ACTIVE");
          selected = variables.creditService.lockNextAvailableCredit(fixture.userId);
          expect(selected.SUCCESS).toBeTrue();
          expect(selected.source).toBe(sourceName);

          consumed = variables.creditService.consumeLockedCredit(
            creditId = selected.creditId,
            userId = fixture.userId,
            floatPlanId = fixture.planAId
          );
          expect(consumed.SUCCESS).toBeTrue();
          expect(consumed.status).toBe("CONSUMED");
          expect(consumed.consumedFloatPlanId).toBe(fixture.planAId);

          consumedAccess = variables.gateService.getCurrentAccess(fixture.userId);
          expect(consumedAccess.hasPremium).toBeFalse();
          expect(consumedAccess.hasGeneralPremium).toBeFalse();
          expect(consumedAccess.premiumSendCreditCount).toBe(0);
          expect(consumedAccess.canSendPremiumFloatPlan).toBeFalse();
          expect(consumedAccess.canUseActiveCruise).toBeTrue();
          expect(consumedAccess.canUseMonitoring).toBeTrue();
          expect(consumedAccess.canUseTripPage).toBeTrue();
          expect(consumedAccess.canUseFollowPage).toBeTrue();
          expect(consumedAccess.activeTripOperationalFloatPlanId).toBe(fixture.planAId);
          expect(consumedAccess.activeTripOperationalAccessSource).toBe("premium_send_credit");

          exactGate = variables.gateService.requireTripOperationalAccess(
            fixture.userId,
            fixture.planAId
          );
          unrelatedGate = variables.gateService.requireTripOperationalAccess(
            fixture.userId,
            fixture.planBId
          );
          expect(exactGate.allowed).toBeTrue();
          expect(exactGate.access.tripOperationalAccessSource).toBe("premium_send_credit");
          expect(unrelatedGate.allowed).toBeFalse();
          expect(unrelatedGate.response.errorCode).toBe("TRIP_OPERATION_ACCESS_REQUIRED");
        }
      });

      it("keeps credit grants idempotent without reassigning the canonical row", function() {
        var owner = createFixture("idempotent-owner");
        var other = createFixture("idempotent-other");
        var idempotencyKey = owner.marker & ":idempotent";
        var firstGrant = variables.creditService.grantCredit(
          userId = owner.userId,
          source = "admin_grant",
          idempotencyKey = idempotencyKey
        );
        var replayGrant = variables.creditService.grantCredit(
          userId = owner.userId,
          source = "admin_grant",
          idempotencyKey = idempotencyKey
        );
        var ownerConflict = variables.creditService.grantCredit(
          userId = other.userId,
          source = "admin_grant",
          idempotencyKey = idempotencyKey
        );
        var sourceConflict = variables.creditService.grantCredit(
          userId = owner.userId,
          source = "promotion",
          idempotencyKey = idempotencyKey
        );
        var invalidSource = variables.creditService.grantCredit(
          userId = owner.userId,
          source = "delivery_only",
          idempotencyKey = owner.marker & ":invalid"
        );
        var qCanonical = queryExecute(
          "SELECT user_id, source, status, COUNT(*) OVER () AS matching_count
           FROM premium_send_credits
           WHERE idempotency_key = :idempotencyKey",
          {
            idempotencyKey = {
              value = idempotencyKey,
              cfsqltype = "cf_sql_varchar"
            }
          },
          { datasource = variables.datasource }
        );

        expect(firstGrant.SUCCESS).toBeTrue();
        expect(firstGrant.idempotentReplay).toBeFalse();
        expect(replayGrant.SUCCESS).toBeTrue();
        expect(replayGrant.idempotentReplay).toBeTrue();
        expect(replayGrant.creditId).toBe(firstGrant.creditId);
        expect(ownerConflict.SUCCESS).toBeFalse();
        expect(ownerConflict.ERROR).toBe("IDEMPOTENCY_CONFLICT");
        expect(sourceConflict.SUCCESS).toBeFalse();
        expect(sourceConflict.ERROR).toBe("IDEMPOTENCY_CONFLICT");
        expect(invalidSource.SUCCESS).toBeFalse();
        expect(invalidSource.ERROR).toBe("INVALID_CREDIT_SOURCE");
        expect(qCanonical.recordCount).toBe(1);
        expect(val(qCanonical.matching_count[1])).toBe(1);
        expect(val(qCanonical.user_id[1])).toBe(owner.userId);
        expect(qCanonical.source[1]).toBe("admin_grant");
        expect(qCanonical.status[1]).toBe("AVAILABLE");
      });

      it("keeps planning and Basic send available at every pre-consumption boundary", function() {
        var withCredit = createFixture("available-boundary");
        var withoutCredit = createFixture("no-authority");
        var granted = variables.creditService.grantCredit(
          userId = withCredit.userId,
          source = "complimentary_signup",
          idempotencyKey = withCredit.marker & ":available"
        );
        var creditAccess = variables.gateService.getCurrentAccess(withCredit.userId);
        var premiumSendGate = variables.gateService.requirePremiumSend(withCredit.userId);
        var generalPremiumGate = variables.gateService.requirePremium(withCredit.userId);
        var tripGate = variables.gateService.requireTripOperationalAccess(
          withCredit.userId,
          withCredit.planAId
        );
        var noCreditAccess = variables.gateService.getCurrentAccess(withoutCredit.userId);
        var deniedSend = variables.gateService.requirePremiumSend(withoutCredit.userId);
        var anonymousSend = variables.gateService.requirePremiumSend(0);

        expect(granted.SUCCESS).toBeTrue();
        expect(creditAccess.canUsePlanningTools).toBeTrue();
        expect(creditAccess.canSendBasicFloatPlan).toBeTrue();
        expect(creditAccess.canSendPremiumFloatPlan).toBeTrue();
        expect(creditAccess.hasPremium).toBeFalse();
        expect(creditAccess.hasGeneralPremium).toBeFalse();
        expect(premiumSendGate.allowed).toBeTrue();
        expect(generalPremiumGate.allowed).toBeFalse();
        expect(generalPremiumGate.response.STATUS_CODE).toBe(403);
        expect(tripGate.allowed).toBeFalse();

        expect(noCreditAccess.canUsePlanningTools).toBeTrue();
        expect(noCreditAccess.canSendBasicFloatPlan).toBeTrue();
        expect(noCreditAccess.canSendPremiumFloatPlan).toBeFalse();
        expect(noCreditAccess.canUseActiveCruise).toBeFalse();
        expect(noCreditAccess.canUseMonitoring).toBeFalse();
        expect(noCreditAccess.canUseTripPage).toBeFalse();
        expect(noCreditAccess.canUseFollowPage).toBeFalse();
        expect(deniedSend.allowed).toBeFalse();
        expect(deniedSend.response.STATUS_CODE).toBe(403);
        expect(deniedSend.response.errorCode).toBe("PREMIUM_SEND_ACCESS_REQUIRED");
        expect(deniedSend.response.upgradeOptions.oneTrip).toBeTrue();
        expect(deniedSend.response.upgradeOptions.monthly).toBeTrue();
        expect(deniedSend.response.upgradeOptions.annual).toBeTrue();

        expect(anonymousSend.allowed).toBeFalse();
        expect(anonymousSend.response.STATUS_CODE).toBe(401);
        expect(anonymousSend.response.errorCode).toBe("AUTH_REQUIRED");
        expect(structKeyExists(anonymousSend.response, "upgradeOptions")).toBeFalse();
      });

      it("rejects Draft and ownership-tampered consumption before binding exactly once", function() {
        var owner = createFixture("consume-owner");
        var other = createFixture("consume-other");
        var granted = variables.creditService.grantCredit(
          userId = owner.userId,
          source = "promotion",
          idempotencyKey = owner.marker & ":consume"
        );
        var draftAttempt = {};
        var tamperedAttempt = {};
        var selected = {};
        var consumed = {};
        var duplicateAttempt = {};
        var qState = queryNew("");
        var exactGate = {};
        var unrelatedGate = {};
        var crossUserGate = {};

        expect(granted.SUCCESS).toBeTrue();

        draftAttempt = variables.creditService.consumeLockedCredit(
          creditId = granted.creditId,
          userId = owner.userId,
          floatPlanId = owner.planAId
        );
        expect(draftAttempt.SUCCESS).toBeFalse();
        expect(draftAttempt.ERROR).toBe("INVALID_FLOAT_PLAN_FOR_CREDIT");

        setPlanStatus(other.userId, other.planAId, "ACTIVE");
        tamperedAttempt = variables.creditService.consumeLockedCredit(
          creditId = granted.creditId,
          userId = owner.userId,
          floatPlanId = other.planAId
        );
        expect(tamperedAttempt.SUCCESS).toBeFalse();
        expect(tamperedAttempt.ERROR).toBe("INVALID_FLOAT_PLAN_FOR_CREDIT");

        qState = loadCreditState(granted.creditId);
        expect(qState.status[1]).toBe("AVAILABLE");
        expect(val(qState.plan_is_null[1])).toBe(1);
        expect(val(qState.consumed_at_is_null[1])).toBe(1);

        setPlanStatus(owner.userId, owner.planAId, "ACTIVE");
        selected = variables.creditService.lockNextAvailableCredit(owner.userId);
        consumed = variables.creditService.consumeLockedCredit(
          creditId = selected.creditId,
          userId = owner.userId,
          floatPlanId = owner.planAId
        );
        expect(consumed.SUCCESS).toBeTrue();
        expect(consumed.status).toBe("CONSUMED");
        expect(consumed.consumedFloatPlanId).toBe(owner.planAId);

        duplicateAttempt = variables.creditService.consumeLockedCredit(
          creditId = selected.creditId,
          userId = owner.userId,
          floatPlanId = owner.planAId
        );
        expect(duplicateAttempt.SUCCESS).toBeFalse();
        expect(duplicateAttempt.ERROR).toBe("CREDIT_CONSUMPTION_CONFLICT");

        qState = loadCreditState(granted.creditId);
        expect(qState.status[1]).toBe("CONSUMED");
        expect(val(qState.consumed_float_plan_id[1])).toBe(owner.planAId);
        expect(val(qState.consumed_at_is_null[1])).toBe(0);

        exactGate = variables.gateService.requireTripOperationalAccess(
          owner.userId,
          owner.planAId
        );
        unrelatedGate = variables.gateService.requireTripOperationalAccess(
          owner.userId,
          owner.planBId
        );
        crossUserGate = variables.gateService.requireTripOperationalAccess(
          other.userId,
          owner.planAId
        );
        expect(exactGate.allowed).toBeTrue();
        expect(unrelatedGate.allowed).toBeFalse();
        expect(crossUserGate.allowed).toBeFalse();
      });

      it("records and reloads one completed-send receipt for the consumed binding", function() {
        var fixture = createFixture("receipt-replay");
        var granted = variables.creditService.grantCredit(
          userId = fixture.userId,
          source = "complimentary_signup",
          idempotencyKey = fixture.marker & ":receipt"
        );
        var consumed = {};
        var originalResponse = {
          SUCCESS = true,
          success = true,
          marker = fixture.marker,
          sentCount = 1
        };
        var receipt = {};
        var loaded = {};
        var locked = {};
        var qReceiptCount = queryNew("");

        setPlanStatus(fixture.userId, fixture.planAId, "ACTIVE");
        consumed = variables.creditService.consumeLockedCredit(
          creditId = granted.creditId,
          userId = fixture.userId,
          floatPlanId = fixture.planAId
        );
        expect(consumed.SUCCESS).toBeTrue();

        receipt = variables.creditService.recordCompletedReceipt(
          userId = fixture.userId,
          floatPlanId = fixture.planAId,
          creditId = granted.creditId,
          accessSource = "premium_send_credit",
          recipientCount = 1,
          response = originalResponse
        );
        loaded = variables.creditService.loadCompletedReceipt(
          fixture.userId,
          fixture.planAId
        );
        locked = variables.creditService.lockCompletedReceipt(
          fixture.userId,
          fixture.planAId
        );
        qReceiptCount = queryExecute(
          "SELECT COUNT(*) AS receipt_count
           FROM premium_send_receipts
           WHERE user_id = :userId
             AND float_plan_id = :floatPlanId",
          {
            userId = {
              value = fixture.userId,
              cfsqltype = "cf_sql_integer"
            },
            floatPlanId = {
              value = fixture.planAId,
              cfsqltype = "cf_sql_integer"
            }
          },
          { datasource = variables.datasource }
        );

        expect(receipt.SUCCESS).toBeTrue();
        expect(receipt.found).toBeTrue();
        expect(receipt.accessSource).toBe("premium_send_credit");
        expect(receipt.creditId).toBe(granted.creditId);
        expect(loaded.found).toBeTrue();
        expect(loaded.receiptId).toBe(receipt.receiptId);
        expect(loaded.originalResponse.marker).toBe(fixture.marker);
        expect(loaded.originalResponse.sentCount).toBe(1);
        expect(locked.found).toBeTrue();
        expect(locked.receiptId).toBe(receipt.receiptId);
        expect(val(qReceiptCount.receipt_count[1])).toBe(1);
      });

      it("rejects invalid receipt sources and bindings without creating history", function() {
        var fixture = createFixture("receipt-invalid");
        var granted = variables.creditService.grantCredit(
          userId = fixture.userId,
          source = "admin_grant",
          idempotencyKey = fixture.marker & ":receipt-invalid"
        );
        var consumed = {};
        var invalidSource = {};
        var missingCredit = {};
        var invalidRecipient = {};
        var wrongCredit = {};
        var noGeneralPremium = {};
        var qReceiptCount = queryNew("");
        var responsePayload = {
          SUCCESS = true,
          marker = fixture.marker
        };

        setPlanStatus(fixture.userId, fixture.planAId, "ACTIVE");
        consumed = variables.creditService.consumeLockedCredit(
          creditId = granted.creditId,
          userId = fixture.userId,
          floatPlanId = fixture.planAId
        );
        expect(consumed.SUCCESS).toBeTrue();

        invalidSource = variables.creditService.recordCompletedReceipt(
          userId = fixture.userId,
          floatPlanId = fixture.planAId,
          creditId = granted.creditId,
          accessSource = "delivery_only",
          recipientCount = 1,
          response = responsePayload
        );
        missingCredit = variables.creditService.recordCompletedReceipt(
          userId = fixture.userId,
          floatPlanId = fixture.planAId,
          creditId = 0,
          accessSource = "premium_send_credit",
          recipientCount = 1,
          response = responsePayload
        );
        invalidRecipient = variables.creditService.recordCompletedReceipt(
          userId = fixture.userId,
          floatPlanId = fixture.planAId,
          creditId = granted.creditId,
          accessSource = "premium_send_credit",
          recipientCount = 0,
          response = responsePayload
        );
        wrongCredit = variables.creditService.recordCompletedReceipt(
          userId = fixture.userId,
          floatPlanId = fixture.planAId,
          creditId = granted.creditId + 999999,
          accessSource = "premium_send_credit",
          recipientCount = 1,
          response = responsePayload
        );
        noGeneralPremium = variables.creditService.recordCompletedReceipt(
          userId = fixture.userId,
          floatPlanId = fixture.planAId,
          creditId = 0,
          accessSource = "general_premium",
          recipientCount = 1,
          response = responsePayload
        );
        qReceiptCount = queryExecute(
          "SELECT COUNT(*) AS receipt_count
           FROM premium_send_receipts
           WHERE user_id = :userId",
          {
            userId = {
              value = fixture.userId,
              cfsqltype = "cf_sql_integer"
            }
          },
          { datasource = variables.datasource }
        );

        expect(invalidSource.SUCCESS).toBeFalse();
        expect(invalidSource.ERROR).toBe("INVALID_SEND_ACCESS_SOURCE");
        expect(missingCredit.SUCCESS).toBeFalse();
        expect(missingCredit.ERROR).toBe("INVALID_SEND_CREDIT_BINDING");
        expect(invalidRecipient.SUCCESS).toBeFalse();
        expect(invalidRecipient.ERROR).toBe("INVALID_RECIPIENT_COUNT");
        expect(wrongCredit.SUCCESS).toBeFalse();
        expect(wrongCredit.ERROR).toBe("INVALID_SEND_CREDIT_BINDING");
        expect(noGeneralPremium.SUCCESS).toBeFalse();
        expect(noGeneralPremium.ERROR).toBe("GENERAL_PREMIUM_REQUIRED");
        expect(val(qReceiptCount.receipt_count[1])).toBe(0);
      });

      it("keeps an AVAILABLE credit untouched for a general Premium send receipt", function() {
        var fixture = createFixture("general-premium");
        var granted = variables.creditService.grantCredit(
          userId = fixture.userId,
          source = "admin_grant",
          idempotencyKey = fixture.marker & ":available-bypass"
        );
        var entitlement = variables.entitlementService.createAdminCompEntitlement(
          userId = fixture.userId,
          expiresAt = dateAdd("d", 1, now())
        );
        var access = {};
        var sendGate = {};
        var firstTripGate = {};
        var secondTripGate = {};
        var receipt = {};
        var qState = queryNew("");
        var qReceipt = queryNew("");

        expect(granted.SUCCESS).toBeTrue();
        expect(entitlement.SUCCESS).toBeTrue();
        setPlanStatus(fixture.userId, fixture.planAId, "ACTIVE");

        access = variables.gateService.getCurrentAccess(fixture.userId);
        sendGate = variables.gateService.requirePremiumSend(fixture.userId);
        firstTripGate = variables.gateService.requireTripOperationalAccess(
          fixture.userId,
          fixture.planAId
        );
        secondTripGate = variables.gateService.requireTripOperationalAccess(
          fixture.userId,
          fixture.planBId
        );

        expect(access.hasPremium).toBeTrue();
        expect(access.hasGeneralPremium).toBeTrue();
        expect(access.canSendPremiumFloatPlan).toBeTrue();
        expect(access.premiumSendAccessSource).toBe("general_premium");
        expect(access.premiumSendCreditCount).toBe(1);
        expect(sendGate.allowed).toBeTrue();
        expect(firstTripGate.allowed).toBeTrue();
        expect(firstTripGate.access.tripOperationalAccessSource).toBe("general_premium");
        expect(secondTripGate.allowed).toBeTrue();
        expect(secondTripGate.access.tripOperationalAccessSource).toBe("general_premium");

        receipt = variables.creditService.recordCompletedReceipt(
          userId = fixture.userId,
          floatPlanId = fixture.planAId,
          creditId = 0,
          accessSource = "general_premium",
          recipientCount = 2,
          response = {
            SUCCESS = true,
            marker = fixture.marker,
            sentCount = 2
          }
        );
        qState = loadCreditState(granted.creditId);
        qReceipt = queryExecute(
          "SELECT access_source, (credit_id IS NULL) AS credit_is_null
           FROM premium_send_receipts
           WHERE id = :receiptId",
          {
            receiptId = {
              value = receipt.receiptId,
              cfsqltype = "cf_sql_bigint"
            }
          },
          { datasource = variables.datasource }
        );

        expect(receipt.SUCCESS).toBeTrue();
        expect(receipt.accessSource).toBe("general_premium");
        expect(receipt.creditId).toBe(0);
        expect(qState.status[1]).toBe("AVAILABLE");
        expect(val(qState.plan_is_null[1])).toBe(1);
        expect(val(qState.consumed_at_is_null[1])).toBe(1);
        expect(variables.creditService.countAvailableCredits(fixture.userId)).toBe(1);
        expect(qReceipt.access_source[1]).toBe("general_premium");
        expect(val(qReceipt.credit_is_null[1])).toBe(1);
      });

      it("never restores a consumed credit when its plan is closed or cancelled", function() {
        var terminalStatuses = ["CLOSED", "CANCELLED"];
        var terminalStatus = "";
        var fixture = {};
        var granted = {};
        var consumed = {};
        var receipt = {};
        var qState = queryNew("");
        var qReceipt = queryNew("");

        for (terminalStatus in terminalStatuses) {
          fixture = createFixture("terminal-" & lCase(terminalStatus));
          granted = variables.creditService.grantCredit(
            userId = fixture.userId,
            source = "stripe_one_trip",
            idempotencyKey = fixture.marker & ":terminal"
          );
          setPlanStatus(fixture.userId, fixture.planAId, "ACTIVE");
          consumed = variables.creditService.consumeLockedCredit(
            creditId = granted.creditId,
            userId = fixture.userId,
            floatPlanId = fixture.planAId
          );
          expect(consumed.SUCCESS).toBeTrue();

          receipt = variables.creditService.recordCompletedReceipt(
            userId = fixture.userId,
            floatPlanId = fixture.planAId,
            creditId = granted.creditId,
            accessSource = "premium_send_credit",
            recipientCount = 1,
            response = {
              SUCCESS = true,
              marker = fixture.marker
            }
          );
          expect(receipt.SUCCESS).toBeTrue();

          setPlanStatus(fixture.userId, fixture.planAId, terminalStatus);
          qState = loadCreditState(granted.creditId);
          qReceipt = queryExecute(
            "SELECT COUNT(*) AS receipt_count
             FROM premium_send_receipts
             WHERE id = :receiptId
               AND float_plan_id = :floatPlanId",
            {
              receiptId = {
                value = receipt.receiptId,
                cfsqltype = "cf_sql_bigint"
              },
              floatPlanId = {
                value = fixture.planAId,
                cfsqltype = "cf_sql_integer"
              }
            },
            { datasource = variables.datasource }
          );

          expect(qState.status[1]).toBe("CONSUMED");
          expect(val(qState.consumed_float_plan_id[1])).toBe(fixture.planAId);
          expect(val(qState.consumed_at_is_null[1])).toBe(0);
          expect(variables.creditService.countAvailableCredits(fixture.userId)).toBe(0);
          expect(val(qReceipt.receipt_count[1])).toBe(1);
        }
      });

      it("keeps the cutover flag off by default and accepts an explicit true config value", function() {
        var token = lCase(replace(createUUID(), "-", "", "all"));
        var disabledPath = getTempDirectory() & "fpw-phase3-disabled-" & token & ".json";
        var enabledPath = getTempDirectory() & "fpw-phase3-enabled-" & token & ".json";
        var baseConfig = {
          "FPW_ENV" = "development",
          "FPW_STRIPE_SECRET_KEY" = "sk_test_phase3_fake",
          "FPW_STRIPE_WEBHOOK_SECRET" = "whsec_phase3_fake",
          "FPW_STRIPE_PRICE_PREMIUM_MONTHLY" = "price_monthly_phase3_fake",
          "FPW_STRIPE_PRICE_PREMIUM_YEARLY" = "price_yearly_phase3_fake",
          "FPW_STRIPE_PRICE_THREE_DAY_PASS" = "price_pass_phase3_fake",
          "FPW_STRIPE_SUCCESS_URL" = "https://fpw.test/app/account.cfm",
          "FPW_STRIPE_CANCEL_URL" = "https://fpw.test/app/account.cfm",
          "FPW_STRIPE_PORTAL_RETURN_URL" = "https://fpw.test/app/account.cfm",
          "FPW_MONITOR_TOKEN" = "phase3-fake-monitor-token"
        };
        var enabledConfig = duplicate(baseConfig);
        var disabledService = "";
        var enabledService = "";
        var disabledStatus = {};
        var enabledStatus = {};
        var enabledSettings = {};

        enabledConfig["FPW_PREMIUM_SEND_CREDIT_MODEL_ENABLED"] = "true";
        enabledConfig["FPW_STRIPE_PRICE_ONE_TRIP"] = "price_one_trip_phase3_fake";
        enabledConfig["FPW_STRIPE_ONE_TRIP_DISPLAY_AMOUNT"] = "$4.99";

        try {
          fileWrite(disabledPath, serializeJSON(baseConfig), "utf-8");
          fileWrite(enabledPath, serializeJSON(enabledConfig), "utf-8");

          disabledService = createObject(
            "component",
            "fpw.api.v1.StripeConfigService"
          ).init(disabledPath);
          enabledService = createObject(
            "component",
            "fpw.api.v1.StripeConfigService"
          ).init(enabledPath);

          disabledStatus = disabledService.getConfigStatus();
          enabledStatus = enabledService.getConfigStatus();
          enabledSettings = enabledService.getApplicationSettings();

          expect(disabledStatus.SUCCESS).toBeTrue();
          expect(disabledService.getPremiumSendCreditModelEnabled()).toBeFalse();
          expect(disabledStatus.premiumSendCreditModelEnabled).toBeFalse();
          expect(disabledStatus.oneTripCheckoutAvailable).toBeFalse();

          expect(enabledStatus.SUCCESS).toBeTrue();
          expect(enabledService.getPremiumSendCreditModelEnabled()).toBeTrue();
          expect(enabledStatus.premiumSendCreditModelEnabled).toBeTrue();
          expect(enabledStatus.oneTripCheckoutAvailable).toBeTrue();
          expect(enabledService.getOneTripDisplayAmount()).toBe("$4.99");
          expect(enabledSettings.FPW_PREMIUM_SEND_CREDIT_MODEL_ENABLED).toBeTrue();
        } finally {
          if (fileExists(disabledPath)) {
            fileDelete(disabledPath);
          }
          if (fileExists(enabledPath)) {
            fileDelete(enabledPath);
          }
        }
      });

      it("exposes only safe cutover and one-trip capability fields through member access", function() {
        var fixture = createFixture("phase3-access-contract");
        var keys = [
          "premiumSendCreditModelEnabled",
          "oneTripCheckoutAvailable",
          "oneTripDisplayAmount"
        ];
        var originals = {};
        var keyName = "";
        var disabledAccess = {};
        var enabledAccess = {};

        for (keyName in keys) {
          if (structKeyExists(application, keyName)) {
            originals[keyName] = application[keyName];
          }
        }

        try {
          for (keyName in keys) {
            structDelete(application, keyName, false);
          }

          disabledAccess = variables.entitlementService.getCurrentAccess(fixture.userId);
          expect(disabledAccess.premiumSendCreditModelEnabled).toBeFalse();
          expect(disabledAccess.oneTripCheckoutAvailable).toBeFalse();
          expect(disabledAccess.oneTripDisplayAmount).toBe("");

          application.premiumSendCreditModelEnabled = true;
          application.oneTripCheckoutAvailable = true;
          application.oneTripDisplayAmount = "$4.99";

          enabledAccess = variables.entitlementService.getCurrentAccess(fixture.userId);
          expect(enabledAccess.premiumSendCreditModelEnabled).toBeTrue();
          expect(enabledAccess.oneTripCheckoutAvailable).toBeTrue();
          expect(enabledAccess.oneTripDisplayAmount).toBe("$4.99");
          expect(structKeyExists(enabledAccess, "FPW_STRIPE_PRICE_ONE_TRIP")).toBeFalse();
          expect(structKeyExists(enabledAccess, "FPW_STRIPE_SECRET_KEY")).toBeFalse();
        } finally {
          for (keyName in keys) {
            if (structKeyExists(originals, keyName)) {
              application[keyName] = originals[keyName];
            } else {
              structDelete(application, keyName, false);
            }
          }
        }
      });

      it("keeps subscription checkout inactive until a subscription lifecycle event activates Premium", function() {
        var fixture = createFixture("subscription-activation");
        var stripeService = createObject(
          "component",
          "fpw.api.v1.StripeEntitlementService"
        ).init(variables.datasource);
        var stripeCustomerId = "cus_test_subscription_" & fixture.userId;
        var stripeSubscriptionId = "sub_test_subscription_" & fixture.userId;
        var stripeCheckoutSessionId = "cs_test_subscription_" & fixture.userId;
        var stripeConfigService = createObject(
          "component",
          "fpw.api.v1.StripeConfigService"
        ).init();
        var stripePriceId = stripeConfigService.getPremiumMonthlyPriceId();
        var annualStripePriceId = stripeConfigService.getPremiumYearlyPriceId();
        var checkoutResult = stripeService.processVerifiedEvent({
          id = "evt_test_checkout_" & fixture.userId,
          type = "checkout.session.completed",
          data = {
            object = {
              id = stripeCheckoutSessionId,
              mode = "subscription",
              client_reference_id = toString(fixture.userId),
              customer = stripeCustomerId,
              subscription = stripeSubscriptionId,
              payment_status = "paid",
              metadata = {
                fpwUserId = toString(fixture.userId)
              }
            }
          }
        });
        var pendingAccess = variables.entitlementService.getCurrentAccess(fixture.userId);
        var qPending = queryExecute(
          "SELECT
             status,
             stripe_subscription_status,
             stripe_price_id,
             (starts_at_utc = expires_at_utc) AS timestamps_match
           FROM member_entitlements
           WHERE user_id = :userId
             AND source = 'stripe_subscription'
             AND stripe_subscription_id = :stripeSubscriptionId
           LIMIT 1",
          {
            userId = {
              value = fixture.userId,
              cfsqltype = "cf_sql_integer"
            },
            stripeSubscriptionId = {
              value = stripeSubscriptionId,
              cfsqltype = "cf_sql_varchar"
            }
          },
          { datasource = variables.datasource }
        );

        expect(checkoutResult.SUCCESS).toBeTrue();
        expect(qPending.recordCount).toBe(1);
        expect(qPending.status[1]).toBe("inactive");
        expect(qPending.stripe_subscription_status[1]).toBe("");
        expect(qPending.stripe_price_id[1]).toBe("");
        expect(val(qPending.timestamps_match[1])).toBe(1);
        expect(pendingAccess.hasGeneralPremium).toBeFalse();

        var subscriptionResult = stripeService.processVerifiedEvent({
          id = "evt_test_subscription_" & fixture.userId,
          type = "customer.subscription.created",
          data = {
            object = {
              id = stripeSubscriptionId,
              customer = stripeCustomerId,
              status = "active",
              metadata = {
                fpwUserId = toString(fixture.userId)
              },
              items = {
                data = [
                  {
                    price = {
                      id = stripePriceId
                    }
                  }
                ]
              }
            }
          }
        });
        var activeAccess = variables.entitlementService.getCurrentAccess(fixture.userId);
        var qActive = queryExecute(
          "SELECT
             status,
             stripe_subscription_status,
             stripe_price_id,
             (expires_at_utc IS NULL) AS expiration_is_null
           FROM member_entitlements
           WHERE user_id = :userId
             AND source = 'stripe_subscription'
             AND stripe_subscription_id = :stripeSubscriptionId
           LIMIT 1",
          {
            userId = {
              value = fixture.userId,
              cfsqltype = "cf_sql_integer"
            },
            stripeSubscriptionId = {
              value = stripeSubscriptionId,
              cfsqltype = "cf_sql_varchar"
            }
          },
          { datasource = variables.datasource }
        );
        var qEvents = queryExecute(
          "SELECT processing_status, COUNT(*) AS event_count
           FROM stripe_webhook_events
           WHERE user_id = :userId
             AND stripe_event_id IN (:checkoutEventId, :subscriptionEventId)
           GROUP BY processing_status",
          {
            userId = {
              value = fixture.userId,
              cfsqltype = "cf_sql_integer"
            },
            checkoutEventId = {
              value = "evt_test_checkout_" & fixture.userId,
              cfsqltype = "cf_sql_varchar"
            },
            subscriptionEventId = {
              value = "evt_test_subscription_" & fixture.userId,
              cfsqltype = "cf_sql_varchar"
            }
          },
          { datasource = variables.datasource }
        );

        expect(subscriptionResult.SUCCESS).toBeTrue();
        expect(qActive.recordCount).toBe(1);
        expect(qActive.status[1]).toBe("active");
        expect(qActive.stripe_subscription_status[1]).toBe("active");
        expect(qActive.stripe_price_id[1]).toBe(stripePriceId);
        expect(val(qActive.expiration_is_null[1])).toBe(1);
        expect(activeAccess.hasPremium).toBeTrue();
        expect(activeAccess.hasGeneralPremium).toBeTrue();
        expect(activeAccess.premiumSource).toBe("stripe_subscription");
        expect(activeAccess.stripeSubscriptionInterval).toBe("monthly");
        expect(qEvents.recordCount).toBe(1);
        expect(qEvents.processing_status[1]).toBe("processed");
        expect(val(qEvents.event_count[1])).toBe(2);

        var annualSubscriptionResult = stripeService.processVerifiedEvent({
          id = "evt_test_subscription_annual_" & fixture.userId,
          type = "customer.subscription.updated",
          data = {
            object = {
              id = stripeSubscriptionId,
              customer = stripeCustomerId,
              status = "active",
              metadata = {
                fpwUserId = toString(fixture.userId)
              },
              items = {
                data = [
                  {
                    price = {
                      id = annualStripePriceId
                    }
                  }
                ]
              }
            }
          }
        });
        var annualAccess = variables.entitlementService.getCurrentAccess(fixture.userId);

        expect(annualSubscriptionResult.SUCCESS).toBeTrue();
        expect(annualAccess.stripeSubscriptionInterval).toBe("annual");
      });

      it("keeps the development Stripe listener aligned with every handled lifecycle event", function() {
        var listenerSource = fileRead(
          expandPath("/fpw/scripts/start-stripe-listener-dev.sh"),
          "utf-8"
        );
        var expectedEvents = [
          "checkout.session.completed",
          "checkout.session.async_payment_succeeded",
          "customer.subscription.created",
          "customer.subscription.updated",
          "customer.subscription.paused",
          "customer.subscription.resumed",
          "customer.subscription.deleted",
          "invoice.payment_succeeded",
          "invoice.payment_failed"
        ];
        var eventType = "";

        expect(find(
          "http://localhost:8500/fpw/api/v1/stripeWebhook.cfc?method=handle",
          listenerSource
        )).toBeGT(0);
        for (eventType in expectedEvents) {
          expect(find(eventType, listenerSource)).toBeGT(0);
        }
      });

      it("renders normalized Monthly and Annual membership types in the account summary", function() {
        var accountSource = fileRead(
          expandPath("/fpw/assets/js/app/account.js"),
          "utf-8"
        );

        expect(find("stripeSubscriptionInterval", accountSource)).toBeGT(0);
        expect(find("Monthly Member", accountSource)).toBeGT(0);
        expect(find("Monthly Premium membership is active through Stripe.", accountSource)).toBeGT(0);
        expect(find("Annual Member", accountSource)).toBeGT(0);
        expect(find("Annual Premium membership is active through Stripe.", accountSource)).toBeGT(0);
      });

      it("binds one-trip Checkout to the authenticated member Stripe Customer", function() {
        var captured = {};
        var fixture = createFixture("one-trip-stripe-customer");
        var fakeTransport = {};
        var fakeConfig = {
          secretKey = "sk_test_phase3_fake",
          oneTripPriceId = "price_one_trip_phase3_fake",
          checkoutSuccessUrl = "https://fpw.test/app/account.cfm?existing=1",
          checkoutCancelUrl = "https://fpw.test/app/account.cfm"
        };
        var checkoutService = "";
        var result = {};
        var replayResult = {};
        var payload = {};
        var qMapping = queryNew("");
        var returnNonce = repeatString("a", 64);

        captured.customerCreateCalls = 0;
        captured.customerUpdateCalls = 0;
        captured.checkoutCalls = 0;

        fakeTransport.createCustomer = function(
          required struct requestPayload,
          required string secretKey
        ) {
          captured.customerCreateCalls++;
          captured.customerCreatePayload = duplicate(arguments.requestPayload);
          captured.customerCreateSecretKey = arguments.secretKey;
          return {
            SUCCESS = true,
            body = {
              id = "cus_test_phase3_member_customer"
            }
          };
        };

        fakeTransport.updateCustomer = function(
          required struct requestPayload,
          required string secretKey
        ) {
          captured.customerUpdateCalls++;
          captured.customerUpdatePayload = duplicate(arguments.requestPayload);
          captured.customerUpdateSecretKey = arguments.secretKey;
          return {
            SUCCESS = true,
            body = {
              id = "cus_test_phase3_member_customer"
            }
          };
        };

        fakeTransport.createCheckoutSession = function(
          required struct requestPayload,
          required string secretKey
        ) {
          captured.checkoutCalls++;
          captured.payload = duplicate(arguments.requestPayload);
          captured.secretKey = arguments.secretKey;
          return {
            SUCCESS = true,
            body = {
              id = "cs_test_phase3_fake",
              url = "https://checkout.stripe.test/cs_test_phase3_fake"
            }
          };
        };

        checkoutService = createObject(
          "component",
          "fpw.api.v1.StripeCheckoutService"
        ).init(
          datasource = variables.datasource,
          configService = fakeConfig,
          stripeTransport = fakeTransport
        );
        result = checkoutService.createCheckoutSession(
          userId = fixture.userId,
          interval = "one_trip",
          floatPlanId = 9876,
          returnNonce = returnNonce
        );
        payload = captured.payload.formFields;

        expect(result.SUCCESS).toBeTrue();
        expect(result.stripeCheckoutSessionId).toBe("cs_test_phase3_fake");
        expect(captured.secretKey).toBe("sk_test_phase3_fake");
        expect(captured.customerCreateCalls).toBe(1);
        expect(captured.customerUpdateCalls).toBe(0);
        expect(captured.customerCreateSecretKey).toBe("sk_test_phase3_fake");
        expect(captured.customerCreatePayload.formFields.email).toBe(fixture.email);
        expect(captured.customerCreatePayload.formFields.name).toBe("Codex Premium Send Contract Test");
        expect(captured.customerCreatePayload.formFields["metadata[fpwUserId]"]).toBe(toString(fixture.userId));
        expect(captured.customerCreatePayload.formFields["metadata[source]"]).toBe("one_trip_checkout");
        expect(payload.mode).toBe("payment");
        expect(payload.customer).toBe("cus_test_phase3_member_customer");
        expect(payload["line_items[0][price]"]).toBe("price_one_trip_phase3_fake");
        expect(payload.client_reference_id).toBe(toString(fixture.userId));
        expect(payload["metadata[fpwUserId]"]).toBe(toString(fixture.userId));
        expect(payload["metadata[fpwProduct]"]).toBe("one_trip");
        expect(payload["metadata[fpwCreditSource]"]).toBe("stripe_one_trip");
        expect(payload["metadata[fpwFloatPlanId]"]).toBe("9876");
        expect(payload["payment_intent_data[metadata][fpwFloatPlanId]"]).toBe("9876");
        expect(payload.success_url).toBe(
          "https://fpw.test/app/account.cfm?existing=1&fpw_checkout=one_trip&stripe_checkout=success&fpw_return=" & returnNonce & "&floatPlanId=9876"
        );
        expect(payload.cancel_url).toBe(
          "https://fpw.test/app/account.cfm?fpw_checkout=one_trip&stripe_checkout=cancel&fpw_return=" & returnNonce & "&floatPlanId=9876"
        );
        expect(findNoCase("session_id", payload.success_url)).toBe(0);

        qMapping = queryExecute(
          "SELECT stripe_customer_id, email_snapshot, name_snapshot, source
           FROM user_stripe_customers
           WHERE user_id = :userId
           LIMIT 1",
          {
            userId = { value = fixture.userId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = variables.datasource }
        );
        expect(qMapping.recordCount).toBe(1);
        expect(qMapping.stripe_customer_id[1]).toBe("cus_test_phase3_member_customer");
        expect(qMapping.email_snapshot[1]).toBe(fixture.email);
        expect(qMapping.name_snapshot[1]).toBe("Codex Premium Send Contract Test");
        expect(qMapping.source[1]).toBe("one_trip_checkout");

        replayResult = checkoutService.createCheckoutSession(
          userId = fixture.userId,
          interval = "one_trip",
          floatPlanId = 9876,
          returnNonce = returnNonce
        );
        expect(replayResult.SUCCESS).toBeTrue();
        expect(captured.customerCreateCalls).toBe(1);
        expect(captured.customerUpdateCalls).toBe(1);
        expect(captured.checkoutCalls).toBe(2);
        expect(captured.customerUpdatePayload.url).toBe("https://api.stripe.com/v1/customers/cus_test_phase3_member_customer");
        expect(captured.customerUpdatePayload.formFields.email).toBe(fixture.email);
        expect(captured.payload.formFields.customer).toBe("cus_test_phase3_member_customer");
      });

      it("keeps failed Stripe Checkout diagnostics out of the public service response", function() {
        var fixture = createFixture("failed-stripe-checkout");
        var fakeTransport = {};
        var fakeConfig = {
          secretKey = "sk_test_phase3_fake",
          oneTripPriceId = "price_one_trip_phase3_fake",
          checkoutSuccessUrl = "https://fpw.test/app/account.cfm",
          checkoutCancelUrl = "https://fpw.test/app/account.cfm"
        };
        var checkoutService = "";
        var result = {};

        fakeTransport.createCustomer = function(
          required struct requestPayload,
          required string secretKey
        ) {
          return {
            SUCCESS = true,
            body = {
              id = "cus_test_phase3_failed_checkout"
            }
          };
        };

        fakeTransport.createCheckoutSession = function(
          required struct requestPayload,
          required string secretKey
        ) {
          return {
            SUCCESS = false,
            statusCode = 400,
            rawBody = serializeJSON({
              error = {
                type = "invalid_request_error",
                code = "resource_missing",
                param = "line_items[0][price]",
                message = "No such price: price_one_trip_phase3_fake"
              }
            })
          };
        };

        checkoutService = createObject(
          "component",
          "fpw.api.v1.StripeCheckoutService"
        ).init(
          datasource = variables.datasource,
          configService = fakeConfig,
          stripeTransport = fakeTransport
        );
        result = checkoutService.createCheckoutSession(
          userId = fixture.userId,
          interval = "one_trip",
          floatPlanId = 9876,
          returnNonce = repeatString("b", 64)
        );

        expect(result.SUCCESS).toBeFalse();
        expect(result.ERROR).toBe("STRIPE_CHECKOUT_FAILED");
        expect(structKeyExists(result, "stripeRawBody")).toBeFalse();
        expect(structKeyExists(result, "stripeDebugMessage")).toBeFalse();
        expect(structKeyExists(result, "debugMessage")).toBeFalse();
        expect(structKeyExists(result, "stripeRequest_line_items[0][price]")).toBeFalse();
        expect(structKeyExists(result, "stripeRequest_success_url")).toBeFalse();
        expect(structKeyExists(result, "stripeRequest_cancel_url")).toBeFalse();
      });

      it("creates operational Follow streams as token-required invite streams", function() {
        var voyageSource = fileRead(expandPath("/fpw/api/v1/voyage.cfc"), "utf-8");
        var floatplanSource = fileRead(expandPath("/fpw/api/v1/floatplan.cfc"), "utf-8");
        var ownerStart = findNoCase('<cffunction name="ownerEnsureStream"', voyageSource);
        var ownerEnd = findNoCase("</cffunction>", voyageSource, ownerStart);
        var helperStart = findNoCase('<cffunction name="ensureVoyageStreamForFloatPlan"', floatplanSource);
        var helperEnd = findNoCase("</cffunction>", floatplanSource, helperStart);
        var ownerSource = mid(voyageSource, ownerStart, ownerEnd - ownerStart);
        var helperSource = mid(floatplanSource, helperStart, helperEnd - helperStart);

        expect(ownerStart).toBeGT(0);
        expect(ownerEnd).toBeGT(ownerStart);
        expect(helperStart).toBeGT(0);
        expect(helperEnd).toBeGT(helperStart);
        expect(findNoCase("'invite'", ownerSource)).toBeGT(0);
        expect(findNoCase("'public'", ownerSource)).toBe(0);
        expect(findNoCase("'invite'", helperSource)).toBeGT(0);
        expect(findNoCase("'public'", helperSource)).toBe(0);
      });

      it("keeps one-trip return nonces and masked Stripe credentials inside the log-redaction contract", function() {
        var applicationSource = fileRead(expandPath("/fpw/Application.cfc"), "utf-8");
        var checkoutSource = fileRead(expandPath("/fpw/api/v1/StripeCheckoutService.cfc"), "utf-8");

        expect(findNoCase("follower_token,followertoken,fpw_return,password", applicationSource)).toBeGT(0);
        expect(findNoCase('urlDecode(decodedKey, "utf-8")', applicationSource)).toBeGT(0);
        expect(find("sk_live_[A-Za-z0-9_*.-]+", applicationSource)).toBeGT(0);
        expect(find("sk_test_[A-Za-z0-9_*.-]+", applicationSource)).toBeGT(0);
        expect(find("rk_live_[A-Za-z0-9_*.-]+", applicationSource)).toBeGT(0);
        expect(find("rk_test_[A-Za-z0-9_*.-]+", applicationSource)).toBeGT(0);
        expect(find("whsec_[A-Za-z0-9_*.-]+", applicationSource)).toBeGT(0);
        expect(find("sk_live_[A-Za-z0-9_*.-]+", checkoutSource)).toBeGT(0);
        expect(find("sk_test_[A-Za-z0-9_*.-]+", checkoutSource)).toBeGT(0);
        expect(find("rk_live_[A-Za-z0-9_*.-]+", checkoutSource)).toBeGT(0);
        expect(find("rk_test_[A-Za-z0-9_*.-]+", checkoutSource)).toBeGT(0);
        expect(find("whsec_[A-Za-z0-9_*.-]+", checkoutSource)).toBeGT(0);
      });

      it("recognizes the exact Phase 3 event dictionary and stores the signup credit flag as a boolean", function() {
        var capturedLogs = [];
        var eventService = createObject(
          "component",
          "fpw.includes.ProductEventService"
        ).init(
          variables.datasource,
          { logEntries = capturedLogs }
        );
        var definitions = [
          { name = "sign_up", entityType = "user", source = "member_signup" },
          { name = "complimentary_credit_granted", entityType = "user", source = "member_signup" },
          { name = "premium_send_attempted", entityType = "float_plan", source = "premium_save_send" },
          { name = "premium_send_completed", entityType = "float_plan", source = "premium_save_send" },
          { name = "premium_send_denied_no_access", entityType = "float_plan", source = "premium_save_send" },
          { name = "basic_send_completed", entityType = "float_plan", source = "basic_save_send" },
          { name = "buy_one_trip_clicked", entityType = "user", source = "billing_api" },
          { name = "one_trip_checkout_created", entityType = "user", source = "billing_api" },
          { name = "one_trip_credit_granted", entityType = "user", source = "stripe_webhook" },
          { name = "same_plan_retry_resolved", entityType = "float_plan", source = "premium_save_send" },
          { name = "monthly_selected", entityType = "user", source = "billing_api" },
          { name = "annual_selected", entityType = "user", source = "billing_api" }
        ];
        var definition = {};
        var validationResult = {};
        var unknownResult = {};
        var fixture = {};
        var idempotencyKey = "";
        var storedResult = {};
        var qStored = queryNew("");
        var storedMetadata = {};

        for (definition in definitions) {
          validationResult = eventService.recordEvent(
            userId = 0,
            eventName = definition.name,
            entityType = definition.entityType,
            entityId = 1,
            eventSource = definition.source
          );
          expect(validationResult.SUCCESS).toBeFalse();
          expect(validationResult.ERROR).toBe("INVALID_USER_ID");
        }

        unknownResult = eventService.recordEvent(
          userId = 0,
          eventName = "premium_send_credit_invented",
          entityType = "user",
          entityId = 1,
          eventSource = "member_signup"
        );
        expect(unknownResult.SUCCESS).toBeFalse();
        expect(unknownResult.ERROR).toBe("UNKNOWN_EVENT_NAME");

        fixture = createFixture("phase3-event-boolean");
        idempotencyKey = fixture.marker & ":signup-boolean";

        try {
          storedResult = eventService.recordEvent(
            userId = fixture.userId,
            eventName = "sign_up",
            entityType = "user",
            entityId = fixture.userId,
            eventSource = "member_signup",
            metadata = {
              signup_method = "password",
              account_tier = "basic",
              onboarding_model = "premium_send_credit",
              complimentary_premium_send_credit = "TRUE"
            },
            idempotencyKey = idempotencyKey
          );
          qStored = queryExecute(
            "SELECT metadata_json
             FROM product_events
             WHERE idempotency_key = :idempotencyKey
             LIMIT 1",
            {
              idempotencyKey = {
                value = idempotencyKey,
                cfsqltype = "cf_sql_varchar"
              }
            },
            { datasource = variables.datasource }
          );

          expect(storedResult.SUCCESS).toBeTrue();
          expect(qStored.recordCount).toBe(1);
          storedMetadata = deserializeJSON(toString(qStored.metadata_json[1]), false);
          expect(isBoolean(storedMetadata.complimentary_premium_send_credit)).toBeTrue();
          expect(serializeJSON(storedMetadata.complimentary_premium_send_credit)).toBe("true");
        } finally {
          queryExecute(
            "DELETE FROM product_events
             WHERE idempotency_key = :idempotencyKey",
            {
              idempotencyKey = {
                value = idempotencyKey,
                cfsqltype = "cf_sql_varchar"
              }
            },
            { datasource = variables.datasource }
          );
        }
      });

    });
  }

  private struct function createFixture(required string label) {
    var token = lCase(replace(createUUID(), "-", "", "all"));
    var marker = variables.fixtureEmailPrefix & token;
    var email = marker & "@example.test";
    var planPrefix = "Codex Premium Send Contract " & left(arguments.label, 48) & " " & token;
    var qUser = queryNew("");
    var fixture = {};

    queryExecute(
      "INSERT INTO users (
         fName,
         lName,
         email,
         password,
         passwordCreated,
         created
       ) VALUES (
         :firstName,
         :lastName,
         :email,
         :password,
         UTC_TIMESTAMP(),
         UTC_TIMESTAMP()
       )",
      {
        firstName = {
          value = "Codex Premium Send",
          cfsqltype = "cf_sql_varchar"
        },
        lastName = {
          value = "Contract Test",
          cfsqltype = "cf_sql_varchar"
        },
        email = {
          value = email,
          cfsqltype = "cf_sql_varchar"
        },
        password = {
          value = hash("not-a-login-" & token, "SHA-256"),
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );

    qUser = queryExecute(
      "SELECT userId
       FROM users
       WHERE email = :email
       LIMIT 1",
      {
        email = {
          value = email,
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );

    if (qUser.recordCount NEQ 1) {
      throw(
        type = "FPW.PremiumSendContractFixture",
        message = "Disposable Premium Send test user was not created."
      );
    }

    fixture = {
      marker = marker,
      email = email,
      userId = val(qUser.userId[1])
    };
    fixture.planAId = createFloatPlan(
      fixture.userId,
      planPrefix & " A"
    );
    fixture.planBId = createFloatPlan(
      fixture.userId,
      planPrefix & " B"
    );

    return fixture;
  }

  private numeric function createFloatPlan(
    required numeric userId,
    required string planName
  ) {
    var qPlan = queryNew("");

    queryExecute(
      "INSERT INTO floatplans (
         userId,
         floatPlanName,
         dateCreated,
         lastUpdate,
         status,
         lastUpdateStatus
       ) VALUES (
         :userId,
         :planName,
         UTC_TIMESTAMP(),
         UTC_TIMESTAMP(),
         'DRAFT',
         UTC_TIMESTAMP()
       )",
      {
        userId = {
          value = toString(val(arguments.userId)),
          cfsqltype = "cf_sql_varchar"
        },
        planName = {
          value = arguments.planName,
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );

    qPlan = queryExecute(
      "SELECT floatPlanId
       FROM floatplans
       WHERE userId = :userId
         AND floatPlanName = :planName
       ORDER BY floatPlanId DESC
       LIMIT 1",
      {
        userId = {
          value = toString(val(arguments.userId)),
          cfsqltype = "cf_sql_varchar"
        },
        planName = {
          value = arguments.planName,
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );

    if (qPlan.recordCount NEQ 1) {
      throw(
        type = "FPW.PremiumSendContractFixture",
        message = "Disposable Premium Send float plan was not created."
      );
    }
    return val(qPlan.floatPlanId[1]);
  }

  private void function setPlanStatus(
    required numeric userId,
    required numeric floatPlanId,
    required string status
  ) {
    queryExecute(
      "UPDATE floatplans
       SET status = :status,
           lastUpdate = UTC_TIMESTAMP(),
           lastUpdateStatus = UTC_TIMESTAMP()
       WHERE floatPlanId = :floatPlanId
         AND userId = :userId",
      {
        status = {
          value = uCase(trim(arguments.status)),
          cfsqltype = "cf_sql_varchar"
        },
        floatPlanId = {
          value = arguments.floatPlanId,
          cfsqltype = "cf_sql_integer"
        },
        userId = {
          value = toString(val(arguments.userId)),
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );
  }

  private query function loadCreditState(required numeric creditId) {
    return queryExecute(
      "SELECT
          id,
          user_id,
          source,
          status,
          consumed_float_plan_id,
          (consumed_float_plan_id IS NULL) AS plan_is_null,
          (consumed_at_utc IS NULL) AS consumed_at_is_null
       FROM premium_send_credits
       WHERE id = :creditId
       LIMIT 1",
      {
        creditId = {
          value = arguments.creditId,
          cfsqltype = "cf_sql_bigint"
        }
      },
      { datasource = variables.datasource }
    );
  }

  private void function cleanupFixtures() {
    var emailPattern = variables.fixtureEmailPrefix & "%";
    var params = {
      emailPattern = {
        value = emailPattern,
        cfsqltype = "cf_sql_varchar"
      }
    };

    queryExecute(
      "DELETE FROM premium_send_receipts
       WHERE user_id IN (
         SELECT userId
         FROM users
         WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM premium_send_credits
       WHERE user_id IN (
         SELECT userId
         FROM users
         WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM stripe_webhook_events
       WHERE user_id IN (
         SELECT userId
         FROM users
         WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM member_entitlements
       WHERE user_id IN (
         SELECT userId
         FROM users
         WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM user_stripe_customers
       WHERE user_id IN (
         SELECT userId
         FROM users
         WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM floatplans
       WHERE userId IN (
         SELECT CAST(userId AS CHAR)
         FROM users
         WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM users
       WHERE email LIKE :emailPattern",
      params,
      { datasource = variables.datasource }
    );
  }

}
