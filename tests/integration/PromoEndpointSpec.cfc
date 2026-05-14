component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.baseUrl = "http://localhost:8500/fpw";
    variables.promoService = new fpw.api.v1.PromoCodeService().init("fpw");
    variables.memberService = new fpw.api.v1.MemberEntitlementService().init("fpw");
    variables.createdUserIds = [];
    variables.createdPromoIds = [];
    variables.userSeed = 510000 + randRange(1000, 99999);
    ensurePromoTables();
  }

  function afterEach() {
    cleanupRows();
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

      it("recognizes stripe_free_months without granting Premium or creating Checkout", function() {
        var userId = createTestUser();
        var code = uniqueCode("free-api");
        insertPromoCode(
          code = code,
          promoType = "stripe_free_months",
          durationMonths = 2,
          stripePromotionCodeId = "promo_endpoint_hidden"
        );

        var res = postPromo(userId, "redeem", { code = code });
        var access = variables.memberService.getCurrentAccess(userId);

        expect(res.SUCCESS).toBeTrue(serializeJSON(res));
        expect(res.promoType).toBe("stripe_free_months");
        expect(res.nextAction).toBe("stripe_checkout_required");
        expect(res.noticeCode).toBe("CHECKOUT_WIRING_PENDING");
        expect(res.MESSAGE).toBe("Launch discount recognized. Checkout activation will be completed in the next billing step.");
        expect(access.hasPremium).toBeFalse(serializeJSON(access));
        expect(countPremiumEntitlements(userId)).toBe(0);
        expect(structKeyExists(res, "stripePromotionCodeId")).toBeFalse(serializeJSON(res));
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

    cfhttp(url = variables.baseUrl & "/api/v1/promo.cfc?method=handle&action=" & encodeForURL(arguments.actionName), method = "post", result = "httpResult", charset = "utf-8") {
      cfhttpparam(type = "header", name = "Content-Type", value = "application/json");
      if (arguments.userId GT 0) {
        cfhttpparam(type = "header", name = "X-FPW-Test-UserId", value = toString(arguments.userId));
      }
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
    string stripePromotionCodeId = ""
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
         NULL,
         UTC_TIMESTAMP(),
         UTC_TIMESTAMP()
       )",
      {
        codeHash = { value = variables.promoService.hashPromoCode(arguments.code), cfsqltype = "cf_sql_char" },
        promoType = { value = arguments.promoType, cfsqltype = "cf_sql_varchar" },
        durationMonths = { value = (isNumeric(arguments.durationMonths) ? val(arguments.durationMonths) : 0), cfsqltype = "cf_sql_integer", null = !isNumeric(arguments.durationMonths) },
        stripePromotionCodeId = { value = arguments.stripePromotionCodeId, cfsqltype = "cf_sql_varchar", null = !len(trim(arguments.stripePromotionCodeId)) }
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
