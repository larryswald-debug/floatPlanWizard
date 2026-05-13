component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.service = new fpw.api.v1.MemberEntitlementService().init("fpw");
    variables.createdUserIds = [];
    variables.userSeed = 900000000 + randRange(1000, 99999);
    ensureMemberEntitlementsTable();
  }

  function afterEach() {
    cleanupEntitlements();
  }

  function run() {
    describe("MemberEntitlementService", function() {
      it("returns Basic access and limits for a user with no entitlement", function() {
        var userId = nextTestUserId();
        var access = variables.service.getCurrentAccess(userId);

        expect(access.authenticated).toBeTrue(serializeJSON(access));
        expect(access.userId).toBe(userId);
        expect(access.memberLevel).toBe("basic");
        expect(access.hasPremium).toBeFalse(serializeJSON(access));
        expect(access.premiumSource).toBe("none");
        expect(access.premiumEntitlementId).toBe(0);
        expectBasicLimits(access.limits);
      });

      it("returns Premium access and limits for an active three_day_pass entitlement", function() {
        var userId = nextTestUserId();
        var created = variables.service.createThreeDayPassEntitlement(userId);
        var access = variables.service.getCurrentAccess(userId);

        expect(created.SUCCESS).toBeTrue(serializeJSON(created));
        expect(access.hasPremium).toBeTrue(serializeJSON(access));
        expect(access.memberLevel).toBe("premium");
        expect(access.premiumSource).toBe("three_day_pass");
        expectPremiumLimits(access.limits);
      });

      it("returns Basic access for an expired active three_day_pass entitlement", function() {
        var userId = nextTestUserId();
        insertEntitlement(
          userId = userId,
          source = "three_day_pass",
          status = "active",
          startsAt = dateAdd("d", -5, utcNow()),
          expiresAt = dateAdd("d", -2, utcNow())
        );

        var access = variables.service.getCurrentAccess(userId);

        expect(access.hasPremium).toBeFalse(serializeJSON(access));
        expect(access.premiumSource).toBe("none");
        expectBasicLimits(access.limits);
      });

      it("returns Premium access and limits for an active admin_comp entitlement", function() {
        var userId = nextTestUserId();
        var created = variables.service.createAdminCompEntitlement(userId);
        var access = variables.service.getCurrentAccess(userId);

        expect(created.SUCCESS).toBeTrue(serializeJSON(created));
        expect(access.hasPremium).toBeTrue(serializeJSON(access));
        expect(access.premiumSource).toBe("admin_comp");
        expectPremiumLimits(access.limits);
      });

      it("returns Premium access and limits for an active stripe_subscription entitlement", function() {
        var userId = nextTestUserId();
        var created = variables.service.createSubscriptionEntitlement(userId, {
          stripeSubscriptionId = "sub_test_" & userId,
          stripeCustomerId = "cus_test_" & userId
        });
        var access = variables.service.getCurrentAccess(userId);

        expect(created.SUCCESS).toBeTrue(serializeJSON(created));
        expect(access.hasPremium).toBeTrue(serializeJSON(access));
        expect(access.premiumSource).toBe("stripe_subscription");
        expectPremiumLimits(access.limits);
      });

      it("reports overlapping Premium sources by paid-source priority", function() {
        var allUserId = nextTestUserId();
        var passAdminUserId = nextTestUserId();
        var adminOnlyUserId = nextTestUserId();

        variables.service.createAdminCompEntitlement(allUserId);
        variables.service.createThreeDayPassEntitlement(allUserId);
        variables.service.createSubscriptionEntitlement(allUserId, { stripeSubscriptionId = "sub_priority_all" });

        variables.service.createAdminCompEntitlement(passAdminUserId);
        variables.service.createThreeDayPassEntitlement(passAdminUserId);

        variables.service.createAdminCompEntitlement(adminOnlyUserId);

        expect(variables.service.getCurrentAccess(allUserId).premiumSource).toBe("stripe_subscription");
        expect(variables.service.getCurrentAccess(passAdminUserId).premiumSource).toBe("three_day_pass");
        expect(variables.service.getCurrentAccess(adminOnlyUserId).premiumSource).toBe("admin_comp");
      });

      it("chooses open-ended, latest-expiring, then newest same-source entitlement rows", function() {
        var openEndedUserId = nextTestUserId();
        var latestExpiryUserId = nextTestUserId();
        var newestTieUserId = nextTestUserId();
        var tieExpiry = dateAdd("d", 8, utcNow());
        var olderTieId = 0;
        var newerTieId = 0;

        insertEntitlement(
          userId = openEndedUserId,
          source = "admin_comp",
          status = "active",
          startsAt = dateAdd("d", -1, utcNow()),
          expiresAt = dateAdd("d", 10, utcNow())
        );
        var openEndedId = insertEntitlement(
          userId = openEndedUserId,
          source = "admin_comp",
          status = "active",
          startsAt = dateAdd("d", -1, utcNow())
        );

        insertEntitlement(
          userId = latestExpiryUserId,
          source = "admin_comp",
          status = "active",
          startsAt = dateAdd("d", -1, utcNow()),
          expiresAt = dateAdd("d", 2, utcNow())
        );
        var latestExpiryId = insertEntitlement(
          userId = latestExpiryUserId,
          source = "admin_comp",
          status = "active",
          startsAt = dateAdd("d", -1, utcNow()),
          expiresAt = dateAdd("d", 7, utcNow())
        );

        olderTieId = insertEntitlement(
          userId = newestTieUserId,
          source = "admin_comp",
          status = "active",
          startsAt = dateAdd("d", -1, utcNow()),
          expiresAt = tieExpiry
        );
        newerTieId = insertEntitlement(
          userId = newestTieUserId,
          source = "admin_comp",
          status = "active",
          startsAt = dateAdd("d", -1, utcNow()),
          expiresAt = tieExpiry
        );

        expect(variables.service.getCurrentAccess(openEndedUserId).premiumEntitlementId).toBe(openEndedId);
        expect(variables.service.getCurrentAccess(latestExpiryUserId).premiumEntitlementId).toBe(latestExpiryId);
        expect(newerTieId).toBeGT(olderTieId);
        expect(variables.service.getCurrentAccess(newestTieUserId).premiumEntitlementId).toBe(newerTieId);
      });

      it("expires only elapsed active three_day_pass rows", function() {
        var elapsedPassUserId = nextTestUserId();
        var currentPassUserId = nextTestUserId();
        var stripeUserId = nextTestUserId();
        var adminUserId = nextTestUserId();
        var inactiveElapsedPassUserId = nextTestUserId();
        var elapsedPassId = 0;
        var currentPassId = 0;
        var stripeId = 0;
        var adminId = 0;
        var inactiveElapsedPassId = 0;
        var result = {};

        elapsedPassId = insertEntitlement(
          userId = elapsedPassUserId,
          source = "three_day_pass",
          status = "active",
          startsAt = dateAdd("d", -5, utcNow()),
          expiresAt = dateAdd("d", -1, utcNow())
        );
        currentPassId = insertEntitlement(
          userId = currentPassUserId,
          source = "three_day_pass",
          status = "active",
          startsAt = dateAdd("h", -1, utcNow()),
          expiresAt = dateAdd("h", 1, utcNow())
        );
        stripeId = insertEntitlement(
          userId = stripeUserId,
          source = "stripe_subscription",
          status = "active",
          startsAt = dateAdd("d", -5, utcNow()),
          expiresAt = dateAdd("d", -1, utcNow())
        );
        adminId = insertEntitlement(
          userId = adminUserId,
          source = "admin_comp",
          status = "active",
          startsAt = dateAdd("d", -5, utcNow()),
          expiresAt = dateAdd("d", -1, utcNow())
        );
        inactiveElapsedPassId = insertEntitlement(
          userId = inactiveElapsedPassUserId,
          source = "three_day_pass",
          status = "inactive",
          startsAt = dateAdd("d", -5, utcNow()),
          expiresAt = dateAdd("d", -1, utcNow())
        );

        result = variables.service.expireElapsedPasses();

        expect(result.SUCCESS).toBeTrue(serializeJSON(result));
        expect(loadEntitlementStatus(elapsedPassId)).toBe("expired");
        expect(loadEntitlementStatus(currentPassId)).toBe("active");
        expect(loadEntitlementStatus(stripeId)).toBe("active");
        expect(loadEntitlementStatus(adminId)).toBe("active");
        expect(loadEntitlementStatus(inactiveElapsedPassId)).toBe("inactive");
      });

      it("does not grant Premium for expired, canceled, inactive, or past_due entitlements", function() {
        var statuses = [ "expired", "canceled", "inactive", "past_due" ];
        var i = 0;

        for (i = 1; i <= arrayLen(statuses); i++) {
          var userId = nextTestUserId();
          insertEntitlement(
            userId = userId,
            source = "stripe_subscription",
            status = statuses[i],
            startsAt = dateAdd("d", -1, utcNow())
          );

          var access = variables.service.getCurrentAccess(userId);
          expect(access.hasPremium).toBeFalse(statuses[i] & ": " & serializeJSON(access));
          expectBasicLimits(access.limits);
        }
      });

      it("does not grant Premium before starts_at_utc is reached", function() {
        var userId = nextTestUserId();
        insertEntitlement(
          userId = userId,
          source = "three_day_pass",
          status = "active",
          startsAt = dateAdd("d", 1, utcNow()),
          expiresAt = dateAdd("d", 4, utcNow())
        );

        var access = variables.service.getCurrentAccess(userId);

        expect(access.hasPremium).toBeFalse(serializeJSON(access));
        expect(access.premiumSource).toBe("none");
        expectBasicLimits(access.limits);
      });
    });
  }

  private numeric function nextTestUserId() {
    variables.userSeed++;
    arrayAppend(variables.createdUserIds, variables.userSeed);
    return variables.userSeed;
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

  private string function loadEntitlementStatus(required numeric entitlementId) {
    var qStatus = queryExecute(
      "SELECT status FROM member_entitlements WHERE id = :id LIMIT 1",
      {
        id = { value = arguments.entitlementId, cfsqltype = "cf_sql_bigint" }
      },
      { datasource = "fpw" }
    );

    return qStatus.recordCount ? trim(toString(qStatus.status[1])) : "";
  }

  private void function expectBasicLimits(required struct limits) {
    expect(arguments.limits.maxWaypoints).toBe(3);
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
