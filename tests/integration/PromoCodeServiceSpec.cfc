component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.baseUrl = "http://localhost:8500/fpw";
    variables.promoService = new fpw.api.v1.PromoCodeService().init("fpw");
    variables.memberService = new fpw.api.v1.MemberEntitlementService().init("fpw");
    variables.stripeService = new fpw.api.v1.StripeEntitlementService().init("fpw");
    variables.createdUserIds = [];
    variables.createdPromoIds = [];
    variables.createdEventIds = [];
    variables.userSeed = 509000 + randRange(1000, 99999);
    ensureMemberEntitlementsTable();
    ensureStripeFoundationSchema();
    ensurePromoTables();
  }

  function afterEach() {
    cleanupRows();
  }

  function run() {
    describe("PromoCodeService", function() {
      it("rejects blank and unknown codes with distinct safe errors", function() {
        var userId = createTestUser();
        var blank = variables.promoService.validateCode(userId, "   ");
        var unknown = variables.promoService.validateCode(userId, "unknown-code");

        expect(blank.SUCCESS).toBeFalse(serializeJSON(blank));
        expect(blank.ERROR).toBe("PROMO_CODE_REQUIRED");
        expect(unknown.SUCCESS).toBeFalse(serializeJSON(unknown));
        expect(unknown.ERROR).toBe("PROMO_CODE_NOT_FOUND");
      });

      it("rejects disabled, future, expired, maxed, duplicate, and unsupported codes with distinct errors", function() {
        var userId = createTestUser();
        var disabledCode = uniqueCode("disabled");
        var futureCode = uniqueCode("future");
        var expiredCode = uniqueCode("expired");
        var maxedCode = uniqueCode("maxed");
        var duplicateCode = uniqueCode("duplicate");
        var unsupportedCode = uniqueCode("unsupported");

        insertPromoCode(code = disabledCode, promoType = "founder_lifetime", status = "disabled");
        insertPromoCode(code = futureCode, promoType = "founder_lifetime", startsAt = dateAdd("d", 1, utcNow()));
        insertPromoCode(code = expiredCode, promoType = "founder_lifetime", expiresAt = dateAdd("d", -1, utcNow()));
        insertPromoCode(code = maxedCode, promoType = "founder_lifetime", maxRedemptions = 1, redemptionsCount = 1);
        insertPromoCode(code = duplicateCode, promoType = "founder_lifetime");
        insertPromoCode(code = unsupportedCode, promoType = "other_promo");

        expect(variables.promoService.validateCode(userId, disabledCode).ERROR).toBe("PROMO_CODE_DISABLED");
        expect(variables.promoService.validateCode(userId, futureCode).ERROR).toBe("PROMO_NOT_STARTED");
        expect(variables.promoService.validateCode(userId, expiredCode).ERROR).toBe("PROMO_EXPIRED");
        expect(variables.promoService.validateCode(userId, maxedCode).ERROR).toBe("PROMO_MAX_REDEMPTIONS_REACHED");

        expect(variables.promoService.redeemCode(userId, duplicateCode).SUCCESS).toBeTrue();
        expect(variables.promoService.validateCode(userId, duplicateCode).ERROR).toBe("PROMO_ALREADY_REDEEMED");
        expect(variables.promoService.validateCode(userId, unsupportedCode).ERROR).toBe("PROMO_UNSUPPORTED_TYPE");
      });

      it("matches codes with trim and case-insensitive normalization", function() {
        var userId = createTestUser();
        var code = uniqueCode("mixed");
        var promoId = insertPromoCode(code = code, promoType = "founder_lifetime");
        var normalizedHash = variables.promoService.hashPromoCode("  " & lCase(code) & "  ");
        var result = variables.promoService.validateCode(userId, "  " & lCase(code) & "  ");

        expect(result.SUCCESS).toBeTrue(serializeJSON(result));
        expect(result.promoCodeId).toBe(promoId);
        expect(normalizedHash).toBe(variables.promoService.hashPromoCode(code));
      });

      it("lets a Basic user redeem a Founder lifetime code and receive non-expiring Premium", function() {
        var userId = createTestUser();
        var code = uniqueCode("founder-basic");
        insertPromoCode(code = code, promoType = "founder_lifetime", maxRedemptions = 1);

        var result = variables.promoService.redeemCode(userId, code);
        var row = loadFounderEntitlement(userId);
        var access = variables.memberService.getCurrentAccess(userId);
        var me = getMeAsUser(userId);

        expect(result.SUCCESS).toBeTrue(serializeJSON(result));
        expect(result.nextAction).toBe("founder_lifetime_redeemed");
        expect(row.recordCount).toBe(1);
        expect(row.entitlement_type[1]).toBe("premium");
        expect(row.source[1]).toBe("founder_lifetime");
        expect(row.status[1]).toBe("active");
        expect(isDbNull(row.expires_at_utc[1])).toBeTrue(serializeJSON(row));
        expect(access.hasPremium).toBeTrue(serializeJSON(access));
        expect(access.premiumSource).toBe("founder_lifetime");
        expect(arrayToList(access.premiumSources)).toInclude("founder_lifetime");
        expect(me.ACCESS.hasPremium).toBeTrue(serializeJSON(me));
        expect(me.ACCESS.premiumSource).toBe("founder_lifetime");
      });

      it("makes Founder lifetime outrank Stripe while preserving Stripe billing state", function() {
        var userId = createTestUser();
        var code = uniqueCode("founder-stripe");
        insertPromoCode(code = code, promoType = "founder_lifetime");
        variables.memberService.createSubscriptionEntitlement(userId, {
          stripeSubscriptionId = "sub_founder_priority_" & userId,
          stripeCustomerId = "cus_founder_priority_" & userId
        });

        var result = variables.promoService.redeemCode(userId, code);
        var access = variables.memberService.getCurrentAccess(userId);

        expect(result.SUCCESS).toBeTrue(serializeJSON(result));
        expect(access.hasPremium).toBeTrue(serializeJSON(access));
        expect(access.premiumSource).toBe("founder_lifetime");
        expect(arrayToList(access.premiumSources)).toBe("founder_lifetime,stripe_subscription");
        expect(access.hasStripeBilling).toBeTrue(serializeJSON(access));
        expect(countStripeEntitlements(userId)).toBe(1);
      });

      it("keeps Founder Premium after Stripe cancellation and deletion events", function() {
        var userId = createTestUser();
        var code = uniqueCode("founder-cancel");
        var subscriptionId = "sub_founder_cancel_" & userId;
        insertPromoCode(code = code, promoType = "founder_lifetime");
        variables.stripeService.processVerifiedEvent(subscriptionEvent(uniqueEventId("evt_founder_seed"), "customer.subscription.updated", userId, subscriptionId, "active"));
        variables.promoService.redeemCode(userId, code);

        variables.stripeService.processVerifiedEvent(subscriptionEvent(uniqueEventId("evt_founder_canceled"), "customer.subscription.updated", userId, subscriptionId, "canceled"));
        expect(variables.memberService.getCurrentAccess(userId).premiumSource).toBe("founder_lifetime");
        expect(variables.memberService.getCurrentAccess(userId).hasPremium).toBeTrue();

        variables.stripeService.processVerifiedEvent(subscriptionEvent(uniqueEventId("evt_founder_deleted"), "customer.subscription.deleted", userId, subscriptionId, "canceled"));
        expect(variables.memberService.getCurrentAccess(userId).premiumSource).toBe("founder_lifetime");
        expect(variables.memberService.getCurrentAccess(userId).hasPremium).toBeTrue();
      });

      it("rejects duplicate single-use Founder redemption for the same user", function() {
        var userId = createTestUser();
        var code = uniqueCode("single-use");
        insertPromoCode(code = code, promoType = "founder_lifetime", maxRedemptions = 1);

        var first = variables.promoService.redeemCode(userId, code);
        var second = variables.promoService.redeemCode(userId, code);

        expect(first.SUCCESS).toBeTrue(serializeJSON(first));
        expect(second.SUCCESS).toBeFalse(serializeJSON(second));
        expect(second.ERROR).toBe("PROMO_MAX_REDEMPTIONS_REACHED");
        expect(countRedeemedRows(userId, code)).toBe(1);
      });

      it("starts a cardless 60-day Stripe trial checkout without granting Premium", function() {
        var userId = createTestUser();
        var code = uniqueCode("free-months");
        var checkoutService = buildFakeTrialCheckoutService();
        var promoService = new fpw.api.v1.PromoCodeService().init(datasource = "fpw", checkoutService = checkoutService);
        var promoId = insertPromoCode(
          code = code,
          promoType = "stripe_free_months",
          durationMonths = 2,
          stripePromotionCodeId = "promo_test_reference"
        );
        var validation = variables.promoService.validateCode(userId, code);
        var redemption = promoService.redeemCode(userId, code);
        var access = variables.memberService.getCurrentAccess(userId);
        var row = loadPromoCode(promoId);

        expect(validation.SUCCESS).toBeTrue(serializeJSON(validation));
        expect(validation.nextAction).toBe("stripe_checkout_required");
        expect(validation.durationMonths).toBe(2);
        expect(validation.stripePromotionCodeId).toBe("promo_test_reference");
        expect(redemption.SUCCESS).toBeTrue(serializeJSON(redemption));
        expect(redemption.nextAction).toBe("stripe_trial_checkout");
        expect(redemption.checkoutRequired).toBeTrue(serializeJSON(redemption));
        expect(redemption.trialDays).toBe(60);
        expect(redemption.checkoutUrl).toBe("https://checkout.stripe.com/c/pay/cs_test_trial_" & userId & "_1");
        expect(checkoutService.requests[1].userId).toBe(userId);
        expect(checkoutService.requests[1].trialDays).toBe(60);
        expect(access.hasPremium).toBeFalse(serializeJSON(access));
        expect(countPremiumEntitlements(userId)).toBe(0);
        expect(countCheckoutCreatedRows(userId, promoId)).toBe(1);
        expect(loadTrialRedemption(userId, promoId).stripe_checkout_session_id[1]).toBe("cs_test_trial_" & userId & "_1");
        expect(row.stripe_promotion_code_id[1]).toBe("promo_test_reference");
        expect(row.redemptions_count[1]).toBe(0);
      });

      it("maps one-month free promo codes to a 30-day trial", function() {
        var userId = createTestUser();
        var code = uniqueCode("free-one-month");
        var checkoutService = buildFakeTrialCheckoutService();
        var promoService = new fpw.api.v1.PromoCodeService().init(datasource = "fpw", checkoutService = checkoutService);
        insertPromoCode(code = code, promoType = "stripe_free_months", durationMonths = 1);

        var redemption = promoService.redeemCode(userId, code);

        expect(redemption.SUCCESS).toBeTrue(serializeJSON(redemption));
        expect(redemption.nextAction).toBe("stripe_trial_checkout");
        expect(redemption.trialDays).toBe(30);
        expect(checkoutService.requests[1].trialDays).toBe(30);
      });

      it("reuses an open pending trial Checkout session for the same promo code", function() {
        var userId = createTestUser();
        var code = uniqueCode("free-reuse-same");
        var checkoutService = buildFakeTrialCheckoutService();
        var promoService = new fpw.api.v1.PromoCodeService().init(datasource = "fpw", checkoutService = checkoutService);
        var promoId = insertPromoCode(code = code, promoType = "stripe_free_months", durationMonths = 1);

        var first = promoService.redeemCode(userId, code);
        var second = promoService.redeemCode(userId, code);

        expect(first.SUCCESS).toBeTrue(serializeJSON(first));
        expect(second.SUCCESS).toBeTrue(serializeJSON(second));
        expect(second.reusedCheckoutSession).toBeTrue(serializeJSON(second));
        expect(second.checkoutUrl).toBe(first.checkoutUrl);
        expect(second.stripeCheckoutSessionId).toBe(first.stripeCheckoutSessionId);
        expect(arrayLen(checkoutService.requests)).toBe(1);
        expect(countCheckoutCreatedRows(userId, promoId)).toBe(1);
        expect(countPremiumEntitlements(userId)).toBe(0);
      });

      it("reuses an open pending trial Checkout session across different free-month codes", function() {
        var userId = createTestUser();
        var firstCode = uniqueCode("free-reuse-first");
        var secondCode = uniqueCode("free-reuse-second");
        var checkoutService = buildFakeTrialCheckoutService();
        var promoService = new fpw.api.v1.PromoCodeService().init(datasource = "fpw", checkoutService = checkoutService);
        insertPromoCode(code = firstCode, promoType = "stripe_free_months", durationMonths = 1);
        insertPromoCode(code = secondCode, promoType = "stripe_free_months", durationMonths = 2);

        var first = promoService.redeemCode(userId, firstCode);
        var second = promoService.redeemCode(userId, secondCode);

        expect(first.SUCCESS).toBeTrue(serializeJSON(first));
        expect(second.SUCCESS).toBeTrue(serializeJSON(second));
        expect(second.reusedCheckoutSession).toBeTrue(serializeJSON(second));
        expect(second.checkoutUrl).toBe(first.checkoutUrl);
        expect(second.trialDays).toBe(30);
        expect(arrayLen(checkoutService.requests)).toBe(1);
      });

      it("allows a new trial Checkout when the previous pending session expired before completion", function() {
        var userId = createTestUser();
        var code = uniqueCode("free-expired-retry");
        var checkoutService = buildFakeTrialCheckoutService();
        var promoService = new fpw.api.v1.PromoCodeService().init(datasource = "fpw", checkoutService = checkoutService);
        var promoId = insertPromoCode(code = code, promoType = "stripe_free_months", durationMonths = 1);

        var first = promoService.redeemCode(userId, code);
        checkoutService.sessionStatuses[first.stripeCheckoutSessionId] = "expired";
        var second = promoService.redeemCode(userId, code);

        expect(first.SUCCESS).toBeTrue(serializeJSON(first));
        expect(second.SUCCESS).toBeTrue(serializeJSON(second));
        expect(second.reusedCheckoutSession).toBeFalse(serializeJSON(second));
        expect(arrayLen(checkoutService.requests)).toBe(2);
        expect(countCheckoutCreatedRows(userId, promoId)).toBe(2);
        expect(loadPromoCode(promoId).redemptions_count[1]).toBe(0);
      });

      it("enforces one free trial per user after verified checkout completion", function() {
        var userId = createTestUser();
        var firstCode = uniqueCode("free-first");
        var secondCode = uniqueCode("free-second");
        var checkoutService = buildFakeTrialCheckoutService();
        var promoService = new fpw.api.v1.PromoCodeService().init(datasource = "fpw", checkoutService = checkoutService);
        insertPromoCode(code = firstCode, promoType = "stripe_free_months", durationMonths = 1);
        insertPromoCode(code = secondCode, promoType = "stripe_free_months", durationMonths = 2);

        var first = promoService.redeemCode(userId, firstCode);
        variables.stripeService.processVerifiedEvent(checkoutEvent(uniqueEventId("evt_trial_completed"), userId, first.stripeCheckoutSessionId, "sub_trial_completed_" & userId));
        var secondValidation = variables.promoService.validateCode(userId, secondCode);
        var second = promoService.redeemCode(userId, secondCode);

        expect(first.SUCCESS).toBeTrue(serializeJSON(first));
        expect(secondValidation.SUCCESS).toBeFalse(serializeJSON(secondValidation));
        expect(secondValidation.ERROR).toBe("PROMO_FREE_TRIAL_ALREADY_USED");
        expect(second.SUCCESS).toBeFalse(serializeJSON(second));
        expect(second.ERROR).toBe("PROMO_FREE_TRIAL_ALREADY_USED");
        expect(arrayLen(checkoutService.requests)).toBe(1);
      });

      it("rejects unsupported free trial durations before Stripe checkout", function() {
        var userId = createTestUser();
        var code = uniqueCode("free-invalid-duration");
        var checkoutService = buildFakeTrialCheckoutService();
        var promoService = new fpw.api.v1.PromoCodeService().init(datasource = "fpw", checkoutService = checkoutService);
        insertPromoCode(code = code, promoType = "stripe_free_months", durationMonths = 3);

        var validation = variables.promoService.validateCode(userId, code);
        var redemption = promoService.redeemCode(userId, code);

        expect(validation.SUCCESS).toBeFalse(serializeJSON(validation));
        expect(validation.ERROR).toBe("PROMO_INVALID_TRIAL_DURATION");
        expect(redemption.SUCCESS).toBeFalse(serializeJSON(redemption));
        expect(redemption.ERROR).toBe("PROMO_INVALID_TRIAL_DURATION");
        expect(arrayLen(checkoutService.requests)).toBe(0);
      });

      it("preserves existing Basic, Stripe, three_day_pass, admin_comp, and past_due access behavior", function() {
        var basicUserId = createTestUser();
        var stripeUserId = createTestUser();
        var passUserId = createTestUser();
        var adminUserId = createTestUser();
        var pastDueUserId = createTestUser();

        variables.memberService.createSubscriptionEntitlement(stripeUserId, { stripeSubscriptionId = "sub_regression_" & stripeUserId });
        variables.memberService.createThreeDayPassEntitlement(passUserId);
        variables.memberService.createAdminCompEntitlement(adminUserId);
        insertEntitlement(pastDueUserId, "stripe_subscription", "past_due");

        expect(variables.memberService.getCurrentAccess(basicUserId).hasPremium).toBeFalse();
        expect(variables.memberService.getCurrentAccess(stripeUserId).premiumSource).toBe("stripe_subscription");
        expect(variables.memberService.getCurrentAccess(passUserId).premiumSource).toBe("three_day_pass");
        expect(variables.memberService.getCurrentAccess(adminUserId).premiumSource).toBe("admin_comp");
        expect(variables.memberService.getCurrentAccess(pastDueUserId).hasPremium).toBeFalse();
      });
    });
  }

  private numeric function createTestUser() {
    variables.userSeed++;
    var userId = variables.userSeed;
    arrayAppend(variables.createdUserIds, userId);
    queryExecute(
      "INSERT INTO users (userId, fName, lName, email, password, passwordCreated, created)
       VALUES (:userId, 'Promo', 'Tester', :email, 'test', UTC_TIMESTAMP(), UTC_TIMESTAMP())",
      {
        userId = { value = userId, cfsqltype = "cf_sql_integer" },
        email = { value = "promo-test-" & userId & "@example.invalid", cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    return userId;
  }

  private string function uniqueCode(required string prefix) {
    return "PROMO2-" & arguments.prefix & "-" & replace(createUUID(), "-", "", "all");
  }

  private string function uniqueEventId(required string prefix) {
    var eventId = arguments.prefix & "_" & replace(createUUID(), "-", "", "all");
    arrayAppend(variables.createdEventIds, eventId);
    return eventId;
  }

  private numeric function insertPromoCode(
    required string code,
    required string promoType,
    string status = "active",
    any startsAt = "",
    any expiresAt = "",
    any maxRedemptions = "",
    numeric redemptionsCount = 0,
    numeric onePerUser = 1,
    any durationMonths = "",
    string stripePromotionCodeId = "",
    string entitlementSource = ""
  ) {
    var promoId = 0;
    var qNewId = queryNew("");
    var startsAtValue = isDate(arguments.startsAt) ? arguments.startsAt : dateAdd("d", -1, utcNow());
    var expiresAtValue = isDate(arguments.expiresAt) ? arguments.expiresAt : "";
    var maxRedemptionsValue = isNumeric(arguments.maxRedemptions) ? val(arguments.maxRedemptions) : 0;
    var durationMonthsValue = isNumeric(arguments.durationMonths) ? val(arguments.durationMonths) : 0;

    queryExecute(
      "INSERT INTO fpw_promo_codes (
         code_hash,
         promo_type,
         status,
         starts_at_utc,
         expires_at_utc,
         max_redemptions,
         redemptions_count,
         one_per_user,
         duration_months,
         stripe_promotion_code_id,
         entitlement_type,
         entitlement_source,
         created_at_utc,
         updated_at_utc
       ) VALUES (
         :codeHash,
         :promoType,
         :status,
         :startsAtUtc,
         :expiresAtUtc,
         :maxRedemptions,
         :redemptionsCount,
         :onePerUser,
         :durationMonths,
         :stripePromotionCodeId,
         'premium',
         :entitlementSource,
         UTC_TIMESTAMP(),
         UTC_TIMESTAMP()
       )",
      {
        codeHash = { value = variables.promoService.hashPromoCode(arguments.code), cfsqltype = "cf_sql_char" },
        promoType = { value = arguments.promoType, cfsqltype = "cf_sql_varchar" },
        status = { value = arguments.status, cfsqltype = "cf_sql_varchar" },
        startsAtUtc = { value = startsAtValue, cfsqltype = "cf_sql_timestamp" },
        expiresAtUtc = { value = expiresAtValue, cfsqltype = "cf_sql_timestamp", null = !isDate(expiresAtValue) },
        maxRedemptions = { value = maxRedemptionsValue, cfsqltype = "cf_sql_integer", null = !isNumeric(arguments.maxRedemptions) },
        redemptionsCount = { value = arguments.redemptionsCount, cfsqltype = "cf_sql_integer" },
        onePerUser = { value = arguments.onePerUser, cfsqltype = "cf_sql_tinyint" },
        durationMonths = { value = durationMonthsValue, cfsqltype = "cf_sql_integer", null = !isNumeric(arguments.durationMonths) },
        stripePromotionCodeId = { value = arguments.stripePromotionCodeId, cfsqltype = "cf_sql_varchar", null = !len(trim(arguments.stripePromotionCodeId)) },
        entitlementSource = { value = arguments.entitlementSource, cfsqltype = "cf_sql_varchar", null = !len(trim(arguments.entitlementSource)) }
      },
      { datasource = "fpw" }
    );

    qNewId = queryExecute("SELECT LAST_INSERT_ID() AS new_id", {}, { datasource = "fpw" });
    promoId = qNewId.recordCount ? val(qNewId.new_id[1]) : 0;
    arrayAppend(variables.createdPromoIds, promoId);
    return promoId;
  }

  private void function insertEntitlement(required numeric userId, required string source, string status = "active") {
    queryExecute(
      "INSERT INTO member_entitlements (
         user_id,
         entitlement_type,
         source,
         status,
         starts_at_utc,
         expires_at_utc,
         created_utc,
         updated_utc
       ) VALUES (
         :userId,
         'premium',
         :source,
         :status,
         DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 DAY),
         DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 DAY),
         UTC_TIMESTAMP(),
         UTC_TIMESTAMP()
       )",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        source = { value = arguments.source, cfsqltype = "cf_sql_varchar" },
        status = { value = arguments.status, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
  }

  private struct function subscriptionEvent(required string eventId, required string eventType, required numeric userId, required string subscriptionId, required string status) {
    return {
      id = arguments.eventId,
      type = arguments.eventType,
      data = {
        object = {
          id = arguments.subscriptionId,
          customer = "cus_" & arguments.userId,
          status = arguments.status,
          metadata = {
            fpwUserId = toString(arguments.userId)
          },
          items = {
            data = [
              {
                price = {
                  id = "price_premium_monthly"
                }
              }
            ]
          }
        }
      }
    };
  }

  private struct function checkoutEvent(required string eventId, required numeric userId, required string checkoutSessionId, required string subscriptionId) {
    return {
      id = arguments.eventId,
      type = "checkout.session.completed",
      data = {
        object = {
          id = arguments.checkoutSessionId,
          client_reference_id = toString(arguments.userId),
          customer = "cus_trial_" & arguments.userId,
          subscription = arguments.subscriptionId,
          metadata = {
            fpwUserId = toString(arguments.userId),
            fpwPromoType = "stripe_free_months"
          },
          items = {
            data = [
              {
                price = {
                  id = "price_premium_monthly"
                }
              }
            ]
          }
        }
      }
    };
  }

  private struct function getMeAsUser(required numeric userId) {
    var httpResult = {};
    var raw = "";
    cfhttp(url = variables.baseUrl & "/api/v1/me.cfc?method=handle", method = "get", result = "httpResult", charset = "utf-8") {
      cfhttpparam(type = "header", name = "X-FPW-Test-UserId", value = toString(arguments.userId));
    }
    raw = structKeyExists(httpResult, "fileContent") ? trim(httpResult.fileContent) : "";
    return len(raw) ? deserializeJSON(raw, false) : {};
  }

  private query function loadFounderEntitlement(required numeric userId) {
    return queryExecute(
      "SELECT id, entitlement_type, source, status, expires_at_utc
       FROM member_entitlements
       WHERE user_id = :userId
         AND source = 'founder_lifetime'
       ORDER BY id DESC",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private query function loadPromoCode(required numeric promoCodeId) {
    return queryExecute(
      "SELECT stripe_promotion_code_id,
              redemptions_count
       FROM fpw_promo_codes
       WHERE promo_code_id = :promoCodeId",
      {
        promoCodeId = { value = arguments.promoCodeId, cfsqltype = "cf_sql_bigint" }
      },
      { datasource = "fpw" }
    );
  }

  private query function loadTrialRedemption(required numeric userId, required numeric promoCodeId) {
    return queryExecute(
      "SELECT result,
              stripe_checkout_session_id
       FROM fpw_promo_redemptions
       WHERE user_id = :userId
         AND promo_code_id = :promoCodeId
         AND result = 'checkout_created'
       ORDER BY redemption_id DESC",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        promoCodeId = { value = arguments.promoCodeId, cfsqltype = "cf_sql_bigint" }
      },
      { datasource = "fpw" }
    );
  }

  private numeric function countPremiumEntitlements(required numeric userId) {
    var qCount = queryExecute(
      "SELECT COUNT(*) AS row_count
       FROM member_entitlements
       WHERE user_id = :userId
         AND entitlement_type = 'premium'",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    return qCount.recordCount ? val(qCount.row_count[1]) : 0;
  }

  private numeric function countStripeEntitlements(required numeric userId) {
    var qCount = queryExecute(
      "SELECT COUNT(*) AS row_count
       FROM member_entitlements
       WHERE user_id = :userId
         AND source = 'stripe_subscription'",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    return qCount.recordCount ? val(qCount.row_count[1]) : 0;
  }

  private numeric function countRedeemedRows(required numeric userId, required string code) {
    var qCount = queryExecute(
      "SELECT COUNT(*) AS row_count
       FROM fpw_promo_redemptions
       WHERE user_id = :userId
         AND attempt_code_hash = :codeHash
         AND result = 'redeemed'",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        codeHash = { value = variables.promoService.hashPromoCode(arguments.code), cfsqltype = "cf_sql_char" }
      },
      { datasource = "fpw" }
    );
    return qCount.recordCount ? val(qCount.row_count[1]) : 0;
  }

  private numeric function countCheckoutCreatedRows(required numeric userId, required numeric promoCodeId) {
    var qCount = queryExecute(
      "SELECT COUNT(*) AS row_count
       FROM fpw_promo_redemptions
       WHERE user_id = :userId
         AND promo_code_id = :promoCodeId
         AND result = 'checkout_created'",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        promoCodeId = { value = arguments.promoCodeId, cfsqltype = "cf_sql_bigint" }
      },
      { datasource = "fpw" }
    );
    return qCount.recordCount ? val(qCount.row_count[1]) : 0;
  }

  private struct function buildFakeTrialCheckoutService() {
    var service = { requests = [], sessionStatuses = {} };
    service.createFreeTrialCheckoutSession = function(required numeric userId, required numeric trialDays, struct promoMetadata = {}) {
      var sessionId = "cs_test_trial_" & arguments.userId & "_" & (arrayLen(service.requests) + 1);
      arrayAppend(service.requests, {
        userId = arguments.userId,
        trialDays = arguments.trialDays,
        promoMetadata = duplicate(arguments.promoMetadata)
      });
      service.sessionStatuses[sessionId] = "open";
      return {
        SUCCESS = true,
        success = true,
        CHECKOUT_URL = "https://checkout.stripe.com/c/pay/" & sessionId,
        checkoutUrl = "https://checkout.stripe.com/c/pay/" & sessionId,
        STRIPE_CHECKOUT_SESSION_ID = sessionId,
        stripeCheckoutSessionId = sessionId,
        TRIAL_DAYS = arguments.trialDays,
        trialDays = arguments.trialDays
      };
    };
    service.retrieveCheckoutSession = function(required string checkoutSessionId, string secretKey = "") {
      var sessionId = trim(arguments.checkoutSessionId);
      var statusValue = structKeyExists(service.sessionStatuses, sessionId) ? service.sessionStatuses[sessionId] : "open";
      if (statusValue EQ "not_found") {
        return {
          SUCCESS = false,
          success = false,
          body = {
            error = {
              code = "resource_missing"
            }
          }
        };
      }
      return {
        SUCCESS = true,
        success = true,
        STRIPE_CHECKOUT_SESSION_ID = sessionId,
        stripeCheckoutSessionId = sessionId,
        CHECKOUT_URL = "https://checkout.stripe.com/c/pay/" & sessionId,
        checkoutUrl = "https://checkout.stripe.com/c/pay/" & sessionId,
        STATUS = statusValue,
        status = statusValue,
        PAYMENT_STATUS = "unpaid",
        paymentStatus = "unpaid"
      };
    };
    return service;
  }

  private void function cleanupRows() {
    var i = 0;
    for (i = 1; i <= arrayLen(variables.createdUserIds); i++) {
      queryExecute(
        "DELETE FROM fpw_promo_redemptions WHERE user_id = :userId",
        {
          userId = { value = variables.createdUserIds[i], cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
      queryExecute(
        "DELETE FROM member_entitlements WHERE user_id = :userId",
        {
          userId = { value = variables.createdUserIds[i], cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
      queryExecute(
        "DELETE FROM users WHERE userId = :userId",
        {
          userId = { value = variables.createdUserIds[i], cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
    }
    for (i = 1; i <= arrayLen(variables.createdPromoIds); i++) {
      queryExecute(
        "DELETE FROM fpw_promo_redemptions WHERE promo_code_id = :promoCodeId",
        {
          promoCodeId = { value = variables.createdPromoIds[i], cfsqltype = "cf_sql_bigint" }
        },
        { datasource = "fpw" }
      );
      queryExecute(
        "DELETE FROM fpw_promo_codes WHERE promo_code_id = :promoCodeId",
        {
          promoCodeId = { value = variables.createdPromoIds[i], cfsqltype = "cf_sql_bigint" }
        },
        { datasource = "fpw" }
      );
    }
    for (i = 1; i <= arrayLen(variables.createdEventIds); i++) {
      queryExecute(
        "DELETE FROM stripe_webhook_events WHERE stripe_event_id = :eventId",
        {
          eventId = { value = variables.createdEventIds[i], cfsqltype = "cf_sql_varchar" }
        },
        { datasource = "fpw" }
      );
    }
    variables.createdUserIds = [];
    variables.createdPromoIds = [];
    variables.createdEventIds = [];
  }

  private void function ensureMemberEntitlementsTable() {
    queryExecute(
      "CREATE TABLE IF NOT EXISTS member_entitlements (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        user_id INT NOT NULL,
        entitlement_type VARCHAR(40) NOT NULL DEFAULT 'premium',
        source VARCHAR(40) NOT NULL,
        status VARCHAR(40) NOT NULL DEFAULT 'active',
        starts_at_utc DATETIME NOT NULL,
        expires_at_utc DATETIME NULL,
        stripe_customer_id VARCHAR(255) NULL,
        stripe_subscription_id VARCHAR(255) NULL,
        stripe_checkout_session_id VARCHAR(255) NULL,
        stripe_payment_intent_id VARCHAR(255) NULL,
        stripe_price_id VARCHAR(255) NULL,
        stripe_subscription_status VARCHAR(40) NULL,
        created_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY idx_member_entitlements_user_access (user_id, entitlement_type, status, starts_at_utc, expires_at_utc),
        KEY idx_member_entitlements_pass_expiry (source, status, expires_at_utc),
        KEY idx_member_entitlements_stripe_customer (stripe_customer_id),
        KEY idx_member_entitlements_stripe_subscription (stripe_subscription_id),
        KEY idx_member_entitlements_stripe_checkout (stripe_checkout_session_id),
        KEY idx_member_entitlements_stripe_payment (stripe_payment_intent_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
      {},
      { datasource = "fpw" }
    );
    ensureColumn("member_entitlements", "stripe_price_id", "ALTER TABLE member_entitlements ADD COLUMN stripe_price_id VARCHAR(255) NULL AFTER stripe_payment_intent_id");
    ensureColumn("member_entitlements", "stripe_subscription_status", "ALTER TABLE member_entitlements ADD COLUMN stripe_subscription_status VARCHAR(40) NULL AFTER stripe_price_id");
  }

  private void function ensureStripeFoundationSchema() {
    queryExecute(
      "CREATE TABLE IF NOT EXISTS stripe_webhook_events (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        stripe_event_id VARCHAR(255) NOT NULL,
        event_type VARCHAR(120) NOT NULL,
        processing_status VARCHAR(40) NOT NULL DEFAULT 'processing',
        user_id INT NULL,
        stripe_customer_id VARCHAR(255) NULL,
        stripe_subscription_id VARCHAR(255) NULL,
        stripe_checkout_session_id VARCHAR(255) NULL,
        stripe_invoice_id VARCHAR(255) NULL,
        stripe_payment_intent_id VARCHAR(255) NULL,
        stripe_price_id VARCHAR(255) NULL,
        processed_at_utc DATETIME NULL,
        error_message VARCHAR(500) NULL,
        created_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY uq_stripe_webhook_events_event_id (stripe_event_id),
        KEY idx_stripe_webhook_events_status_created (processing_status, created_at_utc),
        KEY idx_stripe_webhook_events_user_created (user_id, created_at_utc),
        KEY idx_stripe_webhook_events_subscription (stripe_subscription_id),
        KEY idx_stripe_webhook_events_customer (stripe_customer_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
      {},
      { datasource = "fpw" }
    );
  }

  private void function ensurePromoTables() {
    queryExecute(
      "CREATE TABLE IF NOT EXISTS fpw_promo_codes (
        promo_code_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        code_hash CHAR(64) NOT NULL,
        promo_type VARCHAR(40) NOT NULL,
        status VARCHAR(40) NOT NULL DEFAULT 'active',
        starts_at_utc DATETIME NOT NULL,
        expires_at_utc DATETIME NULL,
        max_redemptions INT UNSIGNED NULL,
        redemptions_count INT UNSIGNED NOT NULL DEFAULT 0,
        one_per_user TINYINT(1) NOT NULL DEFAULT 1,
        duration_months INT UNSIGNED NULL,
        stripe_promotion_code_id VARCHAR(255) NULL,
        entitlement_type VARCHAR(40) NOT NULL DEFAULT 'premium',
        entitlement_source VARCHAR(40) NULL,
        created_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (promo_code_id),
        UNIQUE KEY uq_fpw_promo_codes_code_hash (code_hash),
        KEY idx_fpw_promo_codes_status_window (status, starts_at_utc, expires_at_utc),
        KEY idx_fpw_promo_codes_type_status (promo_type, status),
        KEY idx_fpw_promo_codes_stripe_promotion (stripe_promotion_code_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
      {},
      { datasource = "fpw" }
    );

    queryExecute(
      "CREATE TABLE IF NOT EXISTS fpw_promo_redemptions (
        redemption_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        promo_code_id BIGINT UNSIGNED NULL,
        user_id INT NOT NULL,
        attempt_code_hash CHAR(64) NULL,
        result VARCHAR(40) NOT NULL,
        error_code VARCHAR(80) NULL,
        entitlement_id BIGINT UNSIGNED NULL,
        stripe_checkout_session_id VARCHAR(255) NULL,
        stripe_customer_id VARCHAR(255) NULL,
        stripe_subscription_id VARCHAR(255) NULL,
        attempted_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        redeemed_at_utc DATETIME NULL,
        created_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (redemption_id),
        KEY idx_fpw_promo_redemptions_promo_user_result (promo_code_id, user_id, result),
        KEY idx_fpw_promo_redemptions_user_result_created (user_id, result, created_at_utc),
        KEY idx_fpw_promo_redemptions_promo_result (promo_code_id, result),
        KEY idx_fpw_promo_redemptions_entitlement (entitlement_id),
        KEY idx_fpw_promo_redemptions_checkout (stripe_checkout_session_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
      {},
      { datasource = "fpw" }
    );
  }

  private void function ensureColumn(required string tableName, required string columnName, required string alterSql) {
    var qColumn = queryExecute(
      "SELECT COUNT(*) AS column_count
       FROM information_schema.columns
       WHERE table_schema = DATABASE()
         AND table_name = :tableName
         AND column_name = :columnName",
      {
        tableName = { value = arguments.tableName, cfsqltype = "cf_sql_varchar" },
        columnName = { value = arguments.columnName, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    if (qColumn.recordCount AND val(qColumn.column_count[1]) EQ 0) {
      queryExecute(arguments.alterSql, {}, { datasource = "fpw" });
    }
  }

  private date function utcNow() {
    return dateConvert("local2utc", now());
  }

  private boolean function isDbNull(required any value) {
    if (isNull(arguments.value)) {
      return true;
    }
    return !len(trim(toString(arguments.value)));
  }
}
