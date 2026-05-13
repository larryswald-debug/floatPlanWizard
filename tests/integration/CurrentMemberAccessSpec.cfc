component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.baseUrl = "http://localhost:8500/fpw";
    variables.service = new fpw.api.v1.MemberEntitlementService().init("fpw");
    variables.createdUserIds = [];
    variables.userSeed = 904000000 + randRange(1000, 99999);
    ensureMemberEntitlementsTable();
  }

  function afterEach() {
    cleanupEntitlements();
  }

  function run() {
    describe("Current member access endpoint", function() {
      it("returns Basic access and limits for an authenticated Basic user", function() {
        var userId = nextTestUserId();
        var res = getMeAsUser(userId);

        expect(res.SUCCESS).toBeTrue(serializeJSON(res));
        expect(res.success).toBeTrue(serializeJSON(res));
        expect(res.AUTH).toBeTrue(serializeJSON(res));
        expect(res.auth).toBeTrue(serializeJSON(res));
        expect(resolveUserId(res.USER)).toBe(userId);
        expect(resolveUserId(res.user)).toBe(userId);
        expectAccessAliases(res);
        expect(res.ACCESS.authenticated).toBeTrue(serializeJSON(res.ACCESS));
        expect(res.ACCESS.memberLevel).toBe("basic");
        expect(res.ACCESS.hasPremium).toBeFalse(serializeJSON(res.ACCESS));
        expect(res.ACCESS.premiumSource).toBe("none");
        expectNoPremiumEntitlementId(res);
        expectBasicLimits(res.ACCESS.limits);
      });

      it("returns Premium access for an active stripe_subscription entitlement", function() {
        var userId = nextTestUserId();
        variables.service.createSubscriptionEntitlement(userId, {
          stripeSubscriptionId = "sub_current_member_" & userId,
          stripeCustomerId = "cus_current_member_" & userId
        });

        var res = getMeAsUser(userId);

        expect(res.SUCCESS).toBeTrue(serializeJSON(res));
        expect(res.ACCESS.hasPremium).toBeTrue(serializeJSON(res.ACCESS));
        expect(res.ACCESS.memberLevel).toBe("premium");
        expect(res.ACCESS.premiumSource).toBe("stripe_subscription");
        expectNoPremiumEntitlementId(res);
        expectPremiumLimits(res.ACCESS.limits);
      });

      it("returns Premium access for an active three_day_pass entitlement", function() {
        var userId = nextTestUserId();
        variables.service.createThreeDayPassEntitlement(userId);

        var res = getMeAsUser(userId);

        expect(res.SUCCESS).toBeTrue(serializeJSON(res));
        expect(res.ACCESS.hasPremium).toBeTrue(serializeJSON(res.ACCESS));
        expect(res.ACCESS.memberLevel).toBe("premium");
        expect(res.ACCESS.premiumSource).toBe("three_day_pass");
        expectNoPremiumEntitlementId(res);
        expectPremiumLimits(res.ACCESS.limits);
      });

      it("returns Premium access for an active admin_comp entitlement", function() {
        var userId = nextTestUserId();
        variables.service.createAdminCompEntitlement(userId);

        var res = getMeAsUser(userId);

        expect(res.SUCCESS).toBeTrue(serializeJSON(res));
        expect(res.ACCESS.hasPremium).toBeTrue(serializeJSON(res.ACCESS));
        expect(res.ACCESS.memberLevel).toBe("premium");
        expect(res.ACCESS.premiumSource).toBe("admin_comp");
        expectNoPremiumEntitlementId(res);
        expectPremiumLimits(res.ACCESS.limits);
      });

      it("does not return Premium access for expired, canceled, inactive, or past_due entitlements", function() {
        var statuses = [ "expired", "canceled", "inactive", "past_due" ];
        var i = 0;

        for (i = 1; i <= arrayLen(statuses); i++) {
          var userId = nextTestUserId();
          insertEntitlement(
            userId = userId,
            source = "stripe_subscription",
            status = statuses[i],
            startsAt = dateAdd("d", -2, utcNow()),
            expiresAt = dateAdd("d", 2, utcNow())
          );

          var res = getMeAsUser(userId);

          expect(res.SUCCESS).toBeTrue(statuses[i] & ": " & serializeJSON(res));
          expect(res.ACCESS.hasPremium).toBeFalse(statuses[i] & ": " & serializeJSON(res.ACCESS));
          expect(res.ACCESS.memberLevel).toBe("basic");
          expect(res.ACCESS.premiumSource).toBe("none");
          expectNoPremiumEntitlementId(res);
          expectBasicLimits(res.ACCESS.limits);
        }
      });

      it("returns AUTH_REQUIRED for unauthenticated requests", function() {
        var res = getMeUnauthenticated();

        expect(res.SUCCESS).toBeFalse(serializeJSON(res));
        expect(res.success).toBeFalse(serializeJSON(res));
        expect(res.AUTH).toBeFalse(serializeJSON(res));
        expect(res.auth).toBeFalse(serializeJSON(res));
        expect(res.ERROR).toBe("AUTH_REQUIRED");
        expect(res.errorCode).toBe("AUTH_REQUIRED");
      });
    });
  }

  private numeric function nextTestUserId() {
    variables.userSeed++;
    arrayAppend(variables.createdUserIds, variables.userSeed);
    return variables.userSeed;
  }

  private struct function getMeAsUser(required numeric userId) {
    return requestMe(arguments.userId);
  }

  private struct function getMeUnauthenticated() {
    return requestMe(0);
  }

  private struct function requestMe(required numeric userId) {
    var httpResult = {};
    var raw = "";

    cfhttp(url = variables.baseUrl & "/api/v1/me.cfc?method=handle", method = "get", result = "httpResult", charset = "utf-8") {
      if (arguments.userId GT 0) {
        cfhttpparam(type = "header", name = "X-FPW-Test-UserId", value = toString(arguments.userId));
      }
    }

    raw = structKeyExists(httpResult, "fileContent") ? trim(httpResult.fileContent) : "";
    if (!len(raw)) {
      return {};
    }
    return deserializeJSON(raw, false);
  }

  private void function expectAccessAliases(required struct res) {
    expect(structKeyExists(arguments.res, "ACCESS")).toBeTrue(serializeJSON(arguments.res));
    expect(structKeyExists(arguments.res, "access")).toBeTrue(serializeJSON(arguments.res));
    expect(arguments.res.access.memberLevel).toBe(arguments.res.ACCESS.memberLevel);
    expect(arguments.res.access.hasPremium).toBe(arguments.res.ACCESS.hasPremium);
  }

  private numeric function resolveUserId(required struct user) {
    if (structKeyExists(arguments.user, "userId") AND isNumeric(arguments.user.userId)) {
      return val(arguments.user.userId);
    }
    if (structKeyExists(arguments.user, "USERID") AND isNumeric(arguments.user.USERID)) {
      return val(arguments.user.USERID);
    }
    if (structKeyExists(arguments.user, "id") AND isNumeric(arguments.user.id)) {
      return val(arguments.user.id);
    }
    if (structKeyExists(arguments.user, "ID") AND isNumeric(arguments.user.ID)) {
      return val(arguments.user.ID);
    }
    return 0;
  }

  private void function expectNoPremiumEntitlementId(required struct res) {
    expect(structKeyExists(arguments.res.ACCESS, "premiumEntitlementId")).toBeFalse(serializeJSON(arguments.res.ACCESS));
    expect(structKeyExists(arguments.res.access, "premiumEntitlementId")).toBeFalse(serializeJSON(arguments.res.access));
  }

  private void function cleanupEntitlements() {
    var i = 0;
    for (i = 1; i <= arrayLen(variables.createdUserIds); i++) {
      queryExecute(
        "DELETE FROM member_entitlements WHERE user_id = :userId",
        {
          userId = { value = variables.createdUserIds[i], cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
    }
    variables.createdUserIds = [];
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
  }

  private numeric function insertEntitlement(
    required numeric userId,
    required string source,
    string status = "active",
    string entitlementType = "premium",
    any startsAt = "",
    any expiresAt = ""
  ) {
    var startsAtValue = isDate(arguments.startsAt) ? arguments.startsAt : utcNow();
    var expiresAtValue = isDate(arguments.expiresAt) ? arguments.expiresAt : "";
    var qNewId = queryNew("");

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
         :entitlementType,
         :source,
         :status,
         :startsAtUtc,
         :expiresAtUtc,
         UTC_TIMESTAMP(),
         UTC_TIMESTAMP()
       )",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        entitlementType = { value = arguments.entitlementType, cfsqltype = "cf_sql_varchar" },
        source = { value = arguments.source, cfsqltype = "cf_sql_varchar" },
        status = { value = arguments.status, cfsqltype = "cf_sql_varchar" },
        startsAtUtc = { value = startsAtValue, cfsqltype = "cf_sql_timestamp" },
        expiresAtUtc = { value = expiresAtValue, cfsqltype = "cf_sql_timestamp", null = !isDate(expiresAtValue) }
      },
      { datasource = "fpw" }
    );

    qNewId = queryExecute(
      "SELECT LAST_INSERT_ID() AS new_id",
      {},
      { datasource = "fpw" }
    );

    return qNewId.recordCount ? val(qNewId.new_id[1]) : 0;
  }

  private void function expectBasicLimits(required struct limits) {
    expect(arguments.limits.maxWaypoints).toBe(2);
    expect(arguments.limits.maxTripDays).toBe(1);
    expect(arguments.limits.canSaveRoutes).toBeFalse(serializeJSON(arguments.limits));
    expect(arguments.limits.canUseRouteLibrary).toBeFalse(serializeJSON(arguments.limits));
    expect(arguments.limits.canUseActiveCruise).toBeFalse(serializeJSON(arguments.limits));
    expect(arguments.limits.canUseFollowPage).toBeFalse(serializeJSON(arguments.limits));
    expect(arguments.limits.monitoringLevel).toBe("basic");
    expect(arguments.limits.canUseAdvancedMonitoring).toBeFalse(serializeJSON(arguments.limits));
    expect(arguments.limits.canUseMultiDayTrips).toBeFalse(serializeJSON(arguments.limits));
  }

  private void function expectPremiumLimits(required struct limits) {
    expect(isNull(arguments.limits.maxWaypoints)).toBeTrue(serializeJSON(arguments.limits));
    expect(isNull(arguments.limits.maxTripDays)).toBeTrue(serializeJSON(arguments.limits));
    expect(arguments.limits.canSaveRoutes).toBeTrue(serializeJSON(arguments.limits));
    expect(arguments.limits.canUseRouteLibrary).toBeTrue(serializeJSON(arguments.limits));
    expect(arguments.limits.canUseActiveCruise).toBeTrue(serializeJSON(arguments.limits));
    expect(arguments.limits.canUseFollowPage).toBeTrue(serializeJSON(arguments.limits));
    expect(arguments.limits.monitoringLevel).toBe("advanced");
    expect(arguments.limits.canUseAdvancedMonitoring).toBeTrue(serializeJSON(arguments.limits));
    expect(arguments.limits.canUseMultiDayTrips).toBeTrue(serializeJSON(arguments.limits));
  }

  private date function utcNow() {
    return dateConvert("local2utc", now());
  }
}
