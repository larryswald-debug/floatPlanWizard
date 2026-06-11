component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.baseUrl = "http://localhost:8500/fpw";
    variables.promoService = new fpw.api.v1.PromoCodeService().init("fpw");
    variables.memberService = new fpw.api.v1.MemberEntitlementService().init("fpw");
    variables.createdUserIds = [];
    variables.createdPromoIds = [];
    variables.userSeed = 510000 + randRange(1000, 99999);
    variables.hadOriginalApplicationEnv = structKeyExists(application, "env");
    variables.originalApplicationEnv = variables.hadOriginalApplicationEnv ? application.env : "";
    application.env = "dev";
    ensurePromoTables();
  }

  function afterEach() {
    structDelete(application, "testPromoCodeService", false);
    cleanupRows();
  }

  function afterAll() {
    if (variables.hadOriginalApplicationEnv) {
      application.env = variables.originalApplicationEnv;
    } else {
      structDelete(application, "env", false);
    }
  }

  function run() {
    describe("Promo endpoint", function() {
      it("rejects unauthenticated requests", function() {
        var res = postPromo(0, "redeem", { code = "ANYCODE" });

        expect(res.SUCCESS).toBeFalse(serializeJSON(res));
        expect(res.AUTH).toBeFalse(serializeJSON(res));
        expect(res.ERROR).toBe("AUTH_REQUIRED");
      });

      it("rejects non-POST redeem requests", function() {
        var res = getPromo("redeem");

        expect(res.SUCCESS).toBeFalse(serializeJSON(res));
        expect(res.ERROR).toBe("METHOD_NOT_ALLOWED");
      });

      it("rejects non-POST launch trial activation requests", function() {
        var res = getPromo("startlaunchtrial");

        expect(res.SUCCESS).toBeFalse(serializeJSON(res));
        expect(res.ERROR).toBe("METHOD_NOT_ALLOWED");
      });

      it("rejects blank and unknown codes with stable endpoint errors", function() {
        var userId = createTestUser();
        var blank = postPromo(userId, "redeem", { code = "   " });
        var unknown = postPromo(userId, "redeem", { code = "not-a-real-code" });

        expect(blank.SUCCESS).toBeFalse(serializeJSON(blank));
        expect(blank.ERROR).toBe("CODE_REQUIRED");
        expect(unknown.SUCCESS).toBeFalse(serializeJSON(unknown));
        expect(unknown.ERROR).toBe("CODE_NOT_FOUND");
      });

      it("redeems a valid Founder code and changes access to Premium without exposing internals", function() {
        var userId = createTestUser();
        var code = uniqueCode("founder-api");
        insertPromoCode(code = code, promoType = "founder_lifetime");

        var res = postPromo(userId, "redeem", { code = code });
        var access = variables.memberService.getCurrentAccess(userId);

        expect(res.SUCCESS).toBeTrue(serializeJSON(res));
        expect(res.AUTH).toBeTrue(serializeJSON(res));
        expect(res.promoType).toBe("founder_lifetime");
        expect(res.nextAction).toBe("founder_lifetime_redeemed");
        expect(res.MESSAGE).toBe("Founders Lifetime Premium has been added to your account.");
        expect(access.hasPremium).toBeTrue(serializeJSON(access));
        expect(access.premiumSource).toBe("founder_lifetime");
        expect(structKeyExists(res, "promoCodeId")).toBeFalse(serializeJSON(res));
        expect(structKeyExists(res, "codeHash")).toBeFalse(serializeJSON(res));
        expect(structKeyExists(res, "stripePromotionCodeId")).toBeFalse(serializeJSON(res));
        expect(structKeyExists(res, "entitlementId")).toBeFalse(serializeJSON(res));
      });

      it("starts stripe_free_months cardless trial Checkout without granting Premium", function() {
        var userId = createTestUser();
        var code = uniqueCode("free-api");
        var checkoutService = buildFakeTrialCheckoutService();
        application.testPromoCodeService = new fpw.api.v1.PromoCodeService().init(datasource = "fpw", checkoutService = checkoutService);
        var promoId = insertPromoCode(
          code = code,
          promoType = "stripe_free_months",
          durationMonths = 2,
          stripePromotionCodeId = "promo_endpoint_hidden"
        );

        var res = postPromo(userId, "redeem", { code = code });
        var access = variables.memberService.getCurrentAccess(userId);

        expect(res.SUCCESS).toBeTrue(serializeJSON(res));
        expect(res.promoType).toBe("stripe_free_months");
        expect(res.nextAction).toBe("stripe_trial_checkout");
        expect(res.MESSAGE).toBe("No-credit-card trial checkout is ready.");
        expect(res.checkoutUrl).toBe("https://checkout.stripe.com/c/pay/cs_test_endpoint_trial_" & userId & "_1");
        expect(res.stripeCheckoutSessionId).toBe("cs_test_endpoint_trial_" & userId & "_1");
        expect(res.trialDays).toBe(60);
        expect(checkoutService.requests[1].trialDays).toBe(60);
        expect(access.hasPremium).toBeFalse(serializeJSON(access));
        expect(countPremiumEntitlements(userId)).toBe(0);
        expect(countCheckoutCreatedRows(userId, promoId)).toBe(1);
        expect(structKeyExists(res, "stripePromotionCodeId")).toBeFalse(serializeJSON(res));
        expect(structKeyExists(res, "promoCodeId")).toBeFalse(serializeJSON(res));
        expect(structKeyExists(res, "codeHash")).toBeFalse(serializeJSON(res));
      });

      it("returns a safe unavailable error when no server-side launch promo is active", function() {
        var userId = createTestUser();
        application.testPromoCodeService = {
          startLaunchTrial = function(required numeric userId) {
            return {
              SUCCESS = false,
              success = false,
              eligible = false,
              ERROR = "LAUNCH_PROMO_NOT_AVAILABLE",
              errorCode = "LAUNCH_PROMO_NOT_AVAILABLE",
              displayMessage = "The launch trial is not available right now."
            };
          }
        };

        var res = postPromo(userId, "startlaunchtrial", {});

        expect(res.SUCCESS).toBeFalse(serializeJSON(res));
        expect(res.ERROR).toBe("LAUNCH_PROMO_NOT_AVAILABLE");
        expect(structKeyExists(res, "promoCodeId")).toBeFalse(serializeJSON(res));
        expect(structKeyExists(res, "codeHash")).toBeFalse(serializeJSON(res));
      });

      it("returns a safe ambiguous error when multiple launch_trial promos are active", function() {
        var userId = createTestUser();
        application.testPromoCodeService = {
          startLaunchTrial = function(required numeric userId) {
            return {
              SUCCESS = false,
              success = false,
              eligible = false,
              ERROR = "LAUNCH_PROMO_AMBIGUOUS",
              errorCode = "LAUNCH_PROMO_AMBIGUOUS",
              displayMessage = "Launch trial setup needs attention before the trial can start."
            };
          }
        };

        var res = postPromo(userId, "startlaunchtrial", {});

        expect(res.SUCCESS).toBeFalse(serializeJSON(res));
        expect(res.ERROR).toBe("LAUNCH_PROMO_AMBIGUOUS");
      });

      it("starts server-side launch trial subscription without accepting promo internals from the browser", function() {
        var userId = createTestUser();
        application.testPromoCodeService = {
          startLaunchTrial = function(required numeric userId) {
            return {
              SUCCESS = true,
              success = true,
              eligible = true,
              promoType = "stripe_free_months",
              nextAction = "stripe_trial_subscription",
              displayMessage = "Your Premium trial has started. Activation may take a moment.",
              STATUS = "trial_created",
              status = "trial_created",
              STRIPE_CUSTOMER_ID = "cus_endpoint_trial_" & arguments.userId,
              stripeCustomerId = "cus_endpoint_trial_" & arguments.userId,
              STRIPE_SUBSCRIPTION_ID = "sub_endpoint_trial_" & arguments.userId,
              stripeSubscriptionId = "sub_endpoint_trial_" & arguments.userId,
              TRIAL_DAYS = 30,
              trialDays = 30
            };
          }
        };

        var res = postPromo(userId, "startlaunchtrial", {});
        var access = variables.memberService.getCurrentAccess(userId);

        expect(res.SUCCESS).toBeTrue(serializeJSON(res));
        expect(res.promoType).toBe("stripe_free_months");
        expect(res.nextAction).toBe("stripe_trial_subscription");
        expect(res.status).toBe("trial_created");
        expect(res.checkoutRequired).toBeFalse(serializeJSON(res));
        expect(res.stripeCustomerId).toBe("cus_endpoint_trial_" & userId);
        expect(res.stripeSubscriptionId).toBe("sub_endpoint_trial_" & userId);
        expect(res.trialDays).toBe(30);
        expect(res.redirectUrl).toBe("/fpw/app/dashboard.cfm");
        expect(access.hasPremium).toBeFalse(serializeJSON(access));
        expect(countPremiumEntitlements(userId)).toBe(0);
        expect(structKeyExists(res, "promoCodeId")).toBeFalse(serializeJSON(res));
        expect(structKeyExists(res, "codeHash")).toBeFalse(serializeJSON(res));
        expect(structKeyExists(res, "stripePromotionCodeId")).toBeFalse(serializeJSON(res));
        expect(structKeyExists(res, "checkoutUrl")).toBeFalse(serializeJSON(res));
      });

      it("returns already-trialing launch trial state without a Checkout URL", function() {
        var userId = createTestUser();
        application.testPromoCodeService = {
          startLaunchTrial = function(required numeric userId) {
            return {
              SUCCESS = true,
              success = true,
              eligible = true,
              promoType = "stripe_free_months",
              nextAction = "stripe_trial_subscription",
              displayMessage = "Your Premium trial is already active.",
              STATUS = "already_trialing",
              status = "already_trialing",
              STRIPE_SUBSCRIPTION_ID = "sub_endpoint_trial_reused_" & arguments.userId,
              stripeSubscriptionId = "sub_endpoint_trial_reused_" & arguments.userId,
              TRIAL_DAYS = 30,
              trialDays = 30
            };
          }
        };

        var first = postPromo(userId, "startlaunchtrial", {});
        var second = postPromo(userId, "startlaunchtrial", {});

        expect(first.SUCCESS).toBeTrue(serializeJSON(first));
        expect(second.SUCCESS).toBeTrue(serializeJSON(second));
        expect(second.status).toBe("already_trialing");
        expect(second.stripeSubscriptionId).toBe(first.stripeSubscriptionId);
        expect(structKeyExists(second, "checkoutUrl")).toBeFalse(serializeJSON(second));
      });

      it("routes already-Premium launch trial activation locally without creating a trial", function() {
        var userId = createTestUser();
        variables.memberService.createAdminCompEntitlement(userId);

        var res = postPromo(userId, "startlaunchtrial", {});

        expect(res.SUCCESS).toBeTrue(serializeJSON(res));
        expect(res.nextAction).toBe("stripe_trial_subscription");
        expect(res.status).toBe("already_premium");
        expect(res.redirectUrl).toBe("/fpw/app/dashboard.cfm");
      });

      it("rejects launch trial activation after verified trial use", function() {
        var userId = createTestUser();
        application.testPromoCodeService = {
          startLaunchTrial = function(required numeric userId) {
            return {
              SUCCESS = false,
              success = false,
              eligible = false,
              ERROR = "PROMO_FREE_TRIAL_ALREADY_USED",
              errorCode = "PROMO_FREE_TRIAL_ALREADY_USED",
              displayMessage = "A free trial has already been used for this account."
            };
          }
        };

        var res = postPromo(userId, "startlaunchtrial", {});

        expect(res.SUCCESS).toBeFalse(serializeJSON(res));
        expect(res.ERROR).toBe("FREE_TRIAL_ALREADY_USED");
      });

      it("reuses an open pending trial Checkout for the same user", function() {
        var userId = createTestUser();
        var firstCode = uniqueCode("free-first-api");
        var secondCode = uniqueCode("free-second-api");
        var checkoutService = buildFakeTrialCheckoutService();
        application.testPromoCodeService = new fpw.api.v1.PromoCodeService().init(datasource = "fpw", checkoutService = checkoutService);
        insertPromoCode(code = firstCode, promoType = "stripe_free_months", durationMonths = 1);
        insertPromoCode(code = secondCode, promoType = "stripe_free_months", durationMonths = 2);

        var first = postPromo(userId, "redeem", { code = firstCode });
        var second = postPromo(userId, "redeem", { code = secondCode });

        expect(first.SUCCESS).toBeTrue(serializeJSON(first));
        expect(second.SUCCESS).toBeTrue(serializeJSON(second));
        expect(second.reusedCheckoutSession).toBeTrue(serializeJSON(second));
        expect(second.checkoutUrl).toBe(first.checkoutUrl);
        expect(second.stripeCheckoutSessionId).toBe(first.stripeCheckoutSessionId);
        expect(arrayLen(checkoutService.requests)).toBe(1);
      });

      it("rejects a second stripe_free_months trial after verified trial use", function() {
        var userId = createTestUser();
        var firstCode = uniqueCode("free-used-first-api");
        var secondCode = uniqueCode("free-used-second-api");
        var checkoutService = buildFakeTrialCheckoutService();
        application.testPromoCodeService = new fpw.api.v1.PromoCodeService().init(datasource = "fpw", checkoutService = checkoutService);
        insertPromoCode(code = firstCode, promoType = "stripe_free_months", durationMonths = 1);
        insertPromoCode(code = secondCode, promoType = "stripe_free_months", durationMonths = 2);

        var first = postPromo(userId, "redeem", { code = firstCode });
        markFreeTrialRedeemed(userId, first.stripeCheckoutSessionId);
        var second = postPromo(userId, "redeem", { code = secondCode });

        expect(first.SUCCESS).toBeTrue(serializeJSON(first));
        expect(second.SUCCESS).toBeFalse(serializeJSON(second));
        expect(second.ERROR).toBe("FREE_TRIAL_ALREADY_USED");
        expect(arrayLen(checkoutService.requests)).toBe(1);
      });
    });
  }

  private numeric function createTestUser() {
    variables.userSeed++;
    var userId = variables.userSeed;
    arrayAppend(variables.createdUserIds, userId);
    queryExecute(
      "INSERT INTO users (userId, fName, lName, email, password, passwordCreated, created)
       VALUES (:userId, 'Promo', 'Endpoint', :email, 'test', UTC_TIMESTAMP(), UTC_TIMESTAMP())",
      {
        userId = { value = userId, cfsqltype = "cf_sql_integer" },
        email = { value = "promo-endpoint-" & userId & "@example.invalid", cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    return userId;
  }

  private string function uniqueCode(required string prefix) {
    return "PROMO3-" & arguments.prefix & "-" & replace(createUUID(), "-", "", "all");
  }

  private struct function postPromo(required numeric userId, required string actionName, required struct body) {
    var httpResult = {};
    var raw = "";
    var promoApi = {};
    var hadSessionUser = false;
    var priorSessionUser = {};

    if (arguments.userId GT 0) {
      hadSessionUser = structKeyExists(session, "user");
      priorSessionUser = hadSessionUser ? duplicate(session.user) : {};
      try {
        session.user = {
          id = arguments.userId,
          userId = arguments.userId,
          USERID = arguments.userId,
          email = "promo-endpoint-" & arguments.userId & "@example.invalid",
          EMAIL = "promo-endpoint-" & arguments.userId & "@example.invalid",
          firstName = "Promo",
          FIRSTNAME = "Promo",
          lastName = "Endpoint",
          LASTNAME = "Endpoint",
          mobilePhone = "",
          MOBILEPHONE = ""
        };
        promoApi = new fpw.tests.support.FpwApiSupport().init(
          baseUrl = variables.baseUrl
        );
        return promoApi.postJson("/api/v1/promo.cfc?method=handle&action=" & encodeForURL(arguments.actionName), arguments.body);
      } finally {
        if (hadSessionUser) {
          session.user = priorSessionUser;
        } else {
          structDelete(session, "user", false);
        }
      }
    }

    cfhttp(url = variables.baseUrl & "/api/v1/promo.cfc?method=handle&action=" & encodeForURL(arguments.actionName), method = "post", result = "httpResult", charset = "utf-8") {
      cfhttpparam(type = "header", name = "Content-Type", value = "application/json");
      cfhttpparam(type = "body", value = serializeJSON(arguments.body));
    }

    raw = structKeyExists(httpResult, "fileContent") ? trim(httpResult.fileContent) : "";
    return len(raw) ? deserializeJSON(raw, false) : {};
  }

  private struct function getPromo(required string actionName) {
    var httpResult = {};
    var raw = "";

    cfhttp(url = variables.baseUrl & "/api/v1/promo.cfc?method=handle&action=" & encodeForURL(arguments.actionName), method = "get", result = "httpResult", charset = "utf-8");

    raw = structKeyExists(httpResult, "fileContent") ? trim(httpResult.fileContent) : "";
    return len(raw) ? deserializeJSON(raw, false) : {};
  }

  private numeric function insertPromoCode(
    required string code,
    required string promoType,
    any durationMonths = "",
    string stripePromotionCodeId = "",
    string entitlementSource = ""
  ) {
    var promoId = 0;
    var qNewId = queryNew("");

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
         'active',
         DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 DAY),
         DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 DAY),
         NULL,
         0,
         1,
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
        durationMonths = { value = (isNumeric(arguments.durationMonths) ? val(arguments.durationMonths) : 0), cfsqltype = "cf_sql_integer", null = !isNumeric(arguments.durationMonths) },
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
      var sessionId = "cs_test_endpoint_trial_" & arguments.userId & "_" & (arrayLen(service.requests) + 1);
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

  private void function markFreeTrialRedeemed(required numeric userId, required string checkoutSessionId) {
    queryExecute(
      "UPDATE fpw_promo_redemptions
       SET result = 'redeemed',
           stripe_customer_id = :customerId,
           stripe_subscription_id = :subscriptionId,
           redeemed_at_utc = UTC_TIMESTAMP(),
           updated_at_utc = UTC_TIMESTAMP()
       WHERE user_id = :userId
         AND stripe_checkout_session_id = :checkoutSessionId
         AND result = 'checkout_created'",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        checkoutSessionId = { value = arguments.checkoutSessionId, cfsqltype = "cf_sql_varchar" },
        customerId = { value = "cus_endpoint_trial_" & arguments.userId, cfsqltype = "cf_sql_varchar" },
        subscriptionId = { value = "sub_endpoint_trial_" & arguments.userId, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
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
    variables.createdUserIds = [];
    variables.createdPromoIds = [];
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
}
