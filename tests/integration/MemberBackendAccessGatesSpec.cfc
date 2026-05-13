component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.gate = new fpw.api.v1.MemberAccessGateService().init("fpw");
    variables.entitlements = new fpw.api.v1.MemberEntitlementService().init("fpw");
    variables.activeCruiseViewModel = new fpw.api.v1.ActiveCruiseViewModelService().init("fpw");
    variables.createdUserIds = [];
    variables.userSeed = 901000000 + randRange(1000, 99999);
    ensureMemberEntitlementsTable();
  }

  function afterEach() {
    cleanupEntitlements();
  }

  function run() {
    describe("Member backend access gates", function() {
      it("rejects Basic users from reusable saved route/library behavior", function() {
        var userId = nextTestUserId();
        var result = variables.gate.requirePremium(
          userId = userId,
          errorCode = "BASIC_SAVED_ROUTE_RESTRICTED",
          message = "Upgrade to Premium to save routes."
        );

        expect(result.allowed).toBeFalse(serializeJSON(result));
        expect(result.response.ERROR.CODE).toBe("BASIC_SAVED_ROUTE_RESTRICTED");
      });

      it("rejects Basic users over the waypoint and 1-day trip limits", function() {
        var userId = nextTestUserId();
        var waypointResult = variables.gate.validateWaypointLimit(userId, 4);
        var durationResult = variables.gate.validateTripDurationLimit(
          userId = userId,
          departureAt = utcNow(),
          returnAt = dateAdd("h", 25, utcNow())
        );

        expect(waypointResult.allowed).toBeFalse(serializeJSON(waypointResult));
        expect(waypointResult.response.ERROR.CODE).toBe("BASIC_WAYPOINT_LIMIT");
        expect(durationResult.allowed).toBeFalse(serializeJSON(durationResult));
        expect(durationResult.response.ERROR.CODE).toBe("BASIC_TRIP_DAY_LIMIT");
      });

      it("rejects Basic users from Active Cruise backend models and Follow Page authority", function() {
        var userId = nextTestUserId();
        var activeModel = variables.activeCruiseViewModel.getActiveCruiseViewModel(userId, 1);
        var followAuthority = variables.activeCruiseViewModel.getPublicFollowAuthority(userId, 1);

        expect(activeModel.success).toBeFalse(serializeJSON(activeModel));
        expect(activeModel.errorCode).toBe("BASIC_ACTIVE_CRUISE_RESTRICTED");
        expect(followAuthority.errorCode).toBe("BASIC_FOLLOW_RESTRICTED");
      });

      it("allows Basic monitoring but rejects active_route monitoring for Basic users", function() {
        var userId = nextTestUserId();
        var basicResult = variables.gate.validateMonitoringMode(userId, "basic");
        var activeRouteResult = variables.gate.validateMonitoringMode(userId, "active_route");

        expect(basicResult.allowed).toBeTrue(serializeJSON(basicResult));
        expect(activeRouteResult.allowed).toBeFalse(serializeJSON(activeRouteResult));
        expect(activeRouteResult.response.ERROR.CODE).toBe("BASIC_ADVANCED_MONITORING_RESTRICTED");
      });

      it("allows Premium stripe_subscription, three_day_pass, and admin_comp users through gated features", function() {
        var sources = [ "stripe_subscription", "three_day_pass", "admin_comp" ];
        var i = 0;

        for (i = 1; i <= arrayLen(sources); i++) {
          var userId = nextTestUserId();
          createEntitlementForSource(userId, sources[i]);

          expect(variables.gate.requirePremium(userId, "BASIC_SAVED_ROUTE_RESTRICTED", "Premium required.").allowed).toBeTrue(sources[i]);
          expect(variables.gate.validateWaypointLimit(userId, 20).allowed).toBeTrue(sources[i]);
          expect(variables.gate.validateTripDurationLimit(userId, utcNow(), dateAdd("d", 5, utcNow())).allowed).toBeTrue(sources[i]);
          expect(variables.gate.requirePremium(userId, "BASIC_ACTIVE_CRUISE_RESTRICTED", "Premium required.").allowed).toBeTrue(sources[i]);
          expect(variables.gate.requirePremium(userId, "BASIC_FOLLOW_RESTRICTED", "Premium required.").allowed).toBeTrue(sources[i]);
          expect(variables.gate.validateMonitoringMode(userId, "active_route").allowed).toBeTrue(sources[i]);
        }
      });

      it("does not allow expired, canceled, inactive, or past_due entitlements through Basic restrictions", function() {
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

          var result = variables.gate.requirePremium(
            userId = userId,
            errorCode = "BASIC_ACTIVE_CRUISE_RESTRICTED",
            message = "Premium required."
          );

          expect(result.allowed).toBeFalse(statuses[i] & ": " & serializeJSON(result));
          expect(result.response.ERROR.CODE).toBe("BASIC_ACTIVE_CRUISE_RESTRICTED");
        }
      });

      it("rejects anonymous route and float-plan creation gates as auth required", function() {
        var waypointResult = variables.gate.validateWaypointLimit(0, 1);
        var routeResult = variables.gate.requirePremium(
          userId = 0,
          errorCode = "BASIC_SAVED_ROUTE_RESTRICTED",
          message = "Premium required."
        );

        expect(waypointResult.allowed).toBeFalse(serializeJSON(waypointResult));
        expect(waypointResult.response.ERROR.CODE).toBe("AUTH_REQUIRED");
        expect(routeResult.allowed).toBeFalse(serializeJSON(routeResult));
        expect(routeResult.response.ERROR.CODE).toBe("AUTH_REQUIRED");
      });
    });
  }

  private numeric function nextTestUserId() {
    variables.userSeed++;
    arrayAppend(variables.createdUserIds, variables.userSeed);
    return variables.userSeed;
  }

  private void function createEntitlementForSource(required numeric userId, required string source) {
    if (arguments.source EQ "stripe_subscription") {
      variables.entitlements.createSubscriptionEntitlement(arguments.userId, {
        stripeSubscriptionId = "sub_backend_gate_" & arguments.userId,
        stripeCustomerId = "cus_backend_gate_" & arguments.userId
      });
    } else if (arguments.source EQ "three_day_pass") {
      variables.entitlements.createThreeDayPassEntitlement(arguments.userId);
    } else if (arguments.source EQ "admin_comp") {
      variables.entitlements.createAdminCompEntitlement(arguments.userId);
    }
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

  private date function utcNow() {
    return dateConvert("local2utc", now());
  }
}
