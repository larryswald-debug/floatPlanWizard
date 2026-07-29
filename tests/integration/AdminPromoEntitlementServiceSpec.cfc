component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.promoService = new fpw.api.v1.AdminPromoCodeService().init("fpw");
    variables.entitlementService = new fpw.api.v1.AdminMemberEntitlementService().init("fpw");
    variables.accessService = new fpw.api.v1.MemberEntitlementService().init("fpw");
    variables.admin = { userId = 187, email = "admin-test@example.invalid" };
    variables.createdUserIds = [];
    variables.createdPromoIds = [];
    variables.createdEntitlementIds = [];
    variables.userSeed = 880000000 + randRange(1000, 90000);
  }

  function afterEach() {
    cleanupRows();
  }

  function afterAll() {
    cleanupRows();
  }

  function run() {
    describe("Admin promo and entitlement services", function() {
      it("creates normalized promos, supports list search, and rejects duplicates and invalid dates", function() {
        var code = uniqueCode("create");
        var created = createInternalPromo(code, "trial", 14);
        var promoId = created.DATA.promoCodeId;
        arrayAppend(variables.createdPromoIds, promoId);

        expect(created.SUCCESS).toBeTrue(serializeJSON(created));
        expect(created.DATA.promo.code).toBe(uCase(code));
        expect(created.DATA.promo.runtimeSupport).toBe("admin_grant_only");

        var listed = variables.promoService.listPromos({ search = lCase(code), promoType = "admin_grant", limit = 10, offset = 0, sort = "code", direction = "asc" });
        expect(listed.SUCCESS).toBeTrue(serializeJSON(listed));
        expect(listed.DATA.total).toBe(1);
        expect(listed.DATA.items[1].promoCodeId).toBe(promoId);

        var duplicate = createInternalPromo(lCase(code), "trial", 14);
        expect(duplicate.SUCCESS).toBeFalse(serializeJSON(duplicate));
        expect(duplicate.ERROR.CODE).toBe("PROMO_CODE_DUPLICATE");

        var badDates = variables.promoService.savePromo(basePromoPayload(uniqueCode("dates"), "admin_grant").append({
          adminGrantKind = "trial",
          adminGrantDurationDays = 7,
          startsAtUtc = dateTimeFormat(dateAdd("d", 1, utcNow()), "yyyy-mm-dd HH:nn:ss"),
          expiresAtUtc = dateTimeFormat(utcNow(), "yyyy-mm-dd HH:nn:ss")
        }, true), variables.admin);
        expect(badDates.SUCCESS).toBeFalse(serializeJSON(badDates));
        expect(badDates.ERROR.CODE).toBe("PROMO_DATE_RANGE_INVALID");
      });

      it("grants promo-linked access, blocks overlap without confirmation, and protects redeemed code history", function() {
        var userId = createTestUser();
        var code = uniqueCode("grant");
        var promo = createInternalPromo(code, "fixed_duration", 30);
        var promoId = promo.DATA.promoCodeId;
        arrayAppend(variables.createdPromoIds, promoId);

        var firstGrant = variables.entitlementService.grantEntitlement({
          userId = userId,
          grantKind = "promo",
          promoCodeId = promoId,
          startsAtUtc = dateTimeFormat(dateAdd("h", -1, utcNow()), "yyyy-mm-dd HH:nn:ss"),
          reason = "First admin promo grant",
          adminNotes = "Test grant",
          confirmOverlap = false
        }, variables.admin);
        expect(firstGrant.SUCCESS).toBeTrue(serializeJSON(firstGrant));
        arrayAppend(variables.createdEntitlementIds, firstGrant.DATA.entitlementId);
        expect(firstGrant.DATA.effectiveAccess.hasPremium).toBeTrue(serializeJSON(firstGrant));
        expect(firstGrant.DATA.effectiveAccess.premiumSource).toBe("admin_comp");

        var overlap = variables.entitlementService.grantEntitlement({
          userId = userId,
          grantKind = "fixed_duration",
          durationDays = 7,
          startsAtUtc = dateTimeFormat(utcNow(), "yyyy-mm-dd HH:nn:ss"),
          reason = "Overlapping test grant",
          confirmOverlap = false
        }, variables.admin);
        expect(overlap.SUCCESS).toBeFalse(serializeJSON(overlap));
        expect(overlap.ERROR.CODE).toBe("OVERLAP_CONFIRMATION_REQUIRED");
        expect(arrayLen(overlap.DATA.overlaps)).toBeGT(0);

        var changedCode = basePromoPayload(uniqueCode("replacement"), "admin_grant");
        changedCode.promoCodeId = promoId;
        changedCode.internalName = "Changed redeemed promo";
        changedCode.adminGrantKind = "fixed_duration";
        changedCode.adminGrantDurationDays = 30;
        changedCode.reason = "Attempt to change redeemed code";
        var immutable = variables.promoService.savePromo(changedCode, variables.admin);
        expect(immutable.SUCCESS).toBeFalse(serializeJSON(immutable));
        expect(immutable.ERROR.CODE).toBe("PROMO_CODE_IMMUTABLE");

        var blockedDelete = variables.promoService.deleteUnusedPromo(promoId, "DELETE PROMO " & promoId, "Deletion safety test", variables.admin);
        expect(blockedDelete.SUCCESS).toBeFalse(serializeJSON(blockedDelete));
        expect(blockedDelete.ERROR.CODE).toBe("PROMO_DELETE_BLOCKED");
      });

      it("extends and revokes internal entitlements while recording audit history and updating canonical access", function() {
        var userId = createTestUser();
        var grant = variables.entitlementService.grantEntitlement({
          userId = userId,
          grantKind = "fixed_duration",
          durationDays = 10,
          startsAtUtc = dateTimeFormat(dateAdd("h", -1, utcNow()), "yyyy-mm-dd HH:nn:ss"),
          reason = "Fixed access test",
          confirmOverlap = false
        }, variables.admin);
        expect(grant.SUCCESS).toBeTrue(serializeJSON(grant));
        var entitlementId = grant.DATA.entitlementId;
        arrayAppend(variables.createdEntitlementIds, entitlementId);

        var extended = variables.entitlementService.extendEntitlement(entitlementId, dateTimeFormat(dateAdd("d", 20, utcNow()), "yyyy-mm-dd HH:nn:ss"), "Extension test", variables.admin);
        expect(extended.SUCCESS).toBeTrue(serializeJSON(extended));

        var revoked = variables.entitlementService.revokeEntitlement(entitlementId, "Revocation test", "REVOKE ENTITLEMENT " & entitlementId, variables.admin);
        expect(revoked.SUCCESS).toBeTrue(serializeJSON(revoked));
        expect(revoked.DATA.entitlement.status).toBe("revoked");
        expect(revoked.DATA.effectiveAccess.hasPremium).toBeFalse(serializeJSON(revoked.DATA.effectiveAccess));

        var detail = variables.entitlementService.getMemberDetail(userId);
        expect(detail.SUCCESS).toBeTrue(serializeJSON(detail));
        expect(arrayLen(detail.DATA.audit)).toBeGTE(4);
        expect(detail.DATA.entitlements[1].revocationReason).toBe("Revocation test");
      });

      it("allows notes but blocks date and revocation changes for Stripe-managed entitlements", function() {
        var userId = createTestUser();
        var entitlementId = insertStripeEntitlement(userId);
        arrayAppend(variables.createdEntitlementIds, entitlementId);

        var notes = variables.entitlementService.updateNotes(entitlementId, "Read-only Stripe row note", "Admin note test", variables.admin);
        expect(notes.SUCCESS).toBeTrue(serializeJSON(notes));
        expect(notes.DATA.entitlement.adminNotes).toBe("Read-only Stripe row note");

        var extended = variables.entitlementService.extendEntitlement(entitlementId, dateTimeFormat(dateAdd("d", 20, utcNow()), "yyyy-mm-dd HH:nn:ss"), "Should fail", variables.admin);
        expect(extended.SUCCESS).toBeFalse(serializeJSON(extended));
        expect(extended.ERROR.CODE).toBe("STRIPE_MANAGED_RESTRICTED");

        var revoked = variables.entitlementService.revokeEntitlement(entitlementId, "Should fail", "REVOKE ENTITLEMENT " & entitlementId, variables.admin);
        expect(revoked.SUCCESS).toBeFalse(serializeJSON(revoked));
        expect(revoked.ERROR.CODE).toBe("STRIPE_MANAGED_RESTRICTED");
      });

      it("paginates and sorts entitlement lists while using canonical effective-access precedence", function() {
        var userId = createTestUser();
        var adminGrant = variables.entitlementService.grantEntitlement({
          userId = userId, grantKind = "fixed_duration", durationDays = 5,
          startsAtUtc = dateTimeFormat(dateAdd("h", -1, utcNow()), "yyyy-mm-dd HH:nn:ss"),
          reason = "Admin overlap fixture", confirmOverlap = false
        }, variables.admin);
        expect(adminGrant.SUCCESS).toBeTrue(serializeJSON(adminGrant));
        arrayAppend(variables.createdEntitlementIds, adminGrant.DATA.entitlementId);
        var stripeId = insertStripeEntitlement(userId);
        arrayAppend(variables.createdEntitlementIds, stripeId);

        var listed = variables.entitlementService.listEntitlements({ search = toString(userId), lifecycle = "active", sort = "source", direction = "asc", limit = 1, offset = 0 });
        expect(listed.SUCCESS).toBeTrue(serializeJSON(listed));
        expect(listed.DATA.total).toBe(2);
        expect(arrayLen(listed.DATA.items)).toBe(1);
        expect(variables.accessService.getCurrentAccess(userId).premiumSource).toBe("stripe_subscription");
      });
    });
  }

  private struct function basePromoPayload(required string code, required string promoType) {
    return {
      code = arguments.code,
      internalName = "Admin test " & arguments.code,
      publicDescription = "Disposable admin test promotion",
      promoType = arguments.promoType,
      status = "active",
      startsAtUtc = dateTimeFormat(dateAdd("h", -1, utcNow()), "yyyy-mm-dd HH:nn:ss"),
      expiresAtUtc = dateTimeFormat(dateAdd("d", 30, utcNow()), "yyyy-mm-dd HH:nn:ss"),
      maxRedemptions = 10,
      onePerUser = true,
      entitlementType = "premium",
      reason = "Automated admin service test"
    };
  }

  private struct function createInternalPromo(required string code, required string grantKind, required numeric days) {
    var payload = basePromoPayload(arguments.code, "admin_grant");
    payload.adminGrantKind = arguments.grantKind;
    payload.adminGrantDurationDays = arguments.days;
    return variables.promoService.savePromo(payload, variables.admin);
  }

  private numeric function createTestUser() {
    variables.userSeed++;
    var userId = variables.userSeed;
    arrayAppend(variables.createdUserIds, userId);
    queryExecute(
      "INSERT INTO users (userId, fName, lName, email, password, passwordCreated, created)
       VALUES (:userId, 'Admin', 'EntitlementTest', :email, 'test', UTC_TIMESTAMP(), UTC_TIMESTAMP())",
      {
        userId = { value = userId, cfsqltype = "cf_sql_integer" },
        email = { value = "admin-entitlement-test-" & userId & "@example.invalid", cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    return userId;
  }

  private numeric function insertStripeEntitlement(required numeric userId) {
    queryExecute(
      "INSERT INTO member_entitlements
         (user_id, entitlement_type, source, status, starts_at_utc, expires_at_utc,
          stripe_customer_id, stripe_subscription_id, stripe_subscription_status,
          created_utc, updated_utc)
       VALUES (:userId, 'premium', 'stripe_subscription', 'active',
               DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 DAY), DATE_ADD(UTC_TIMESTAMP(), INTERVAL 10 DAY),
               :customerId, :subscriptionId, 'active', UTC_TIMESTAMP(), UTC_TIMESTAMP())",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        customerId = { value = "cus_admin_test_" & arguments.userId, cfsqltype = "cf_sql_varchar" },
        subscriptionId = { value = "sub_admin_test_" & arguments.userId & "_" & replace(createUUID(), "-", "", "all"), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    var qId = queryExecute("SELECT LAST_INSERT_ID() AS new_id", {}, { datasource = "fpw" });
    return val(qId.new_id[1]);
  }

  private string function uniqueCode(required string prefix) {
    return "ADMIN-" & uCase(arguments.prefix) & "-" & replace(createUUID(), "-", "", "all");
  }

  private date function utcNow() {
    return dateConvert("local2utc", now());
  }

  private void function cleanupRows() {
    var idList = arrayLen(variables.createdUserIds) ? arrayToList(variables.createdUserIds) : "0";
    var promoList = arrayLen(variables.createdPromoIds) ? arrayToList(variables.createdPromoIds) : "0";
    var params = {
      userIds = { value = idList, cfsqltype = "cf_sql_integer", list = true },
      userEntityIds = { value = idList, cfsqltype = "cf_sql_varchar", list = true },
      promoIds = { value = promoList, cfsqltype = "cf_sql_bigint", list = true }
    };
    queryExecute("DELETE FROM fpw_promo_redemptions WHERE user_id IN (:userIds) OR promo_code_id IN (:promoIds)", params, { datasource = "fpw" });
    queryExecute("DELETE FROM fpw_admin_audit_log WHERE admin_email = 'admin-test@example.invalid' OR (entity_type = 'member' AND entity_id IN (:userEntityIds))", params, { datasource = "fpw" });
    queryExecute("DELETE FROM member_entitlements WHERE user_id IN (:userIds)", params, { datasource = "fpw" });
    queryExecute("DELETE FROM fpw_promo_codes WHERE promo_code_id IN (:promoIds)", params, { datasource = "fpw" });
    queryExecute("DELETE FROM users WHERE userId IN (:userIds)", params, { datasource = "fpw" });
    variables.createdUserIds = [];
    variables.createdPromoIds = [];
    variables.createdEntitlementIds = [];
  }
}

