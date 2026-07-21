component extends="testbox.system.BaseSpec" output="false" {

  variables.datasource = "fpw";
  variables.fixtureEmailPrefix = "codex-premium-send-contract-";

  function run() {
    describe("Premium Send Credit service and access contract", function() {

      beforeAll(function() {
        cleanupFixtures();
      });

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

      afterAll(function() {
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
