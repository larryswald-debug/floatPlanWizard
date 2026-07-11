component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.baseUrl = "http://localhost:8500/fpw";
    variables.createdPromoIds = [];
    variables.hadSessionUser = false;
    variables.priorSessionUser = {};
  }

  function beforeEach() {
    variables.hadSessionUser = structKeyExists(session, "user") AND isStruct(session.user);
    variables.priorSessionUser = variables.hadSessionUser ? duplicate(session.user) : {};
    session.user = { userId = 1, id = 1, USERID = 1 };
    session.adminPromoCodesNonce = "endpoint-promo-" & createUUID();
    session.adminMemberEntitlementsNonce = "endpoint-entitlement-" & createUUID();
    session.fpwAdminCsrfToken = lCase(replace(createUUID(), "-", "", "all")) & lCase(replace(createUUID(), "-", "", "all"));
    variables.api = new fpw.tests.support.FpwApiSupport().init(baseUrl = variables.baseUrl);
  }

  function afterEach() {
    cleanupPromos();
    if (variables.hadSessionUser) session.user = variables.priorSessionUser;
    else structDelete(session, "user", false);
    structDelete(session, "adminPromoCodesNonce", false);
    structDelete(session, "adminMemberEntitlementsNonce", false);
    structDelete(session, "fpwAdminCsrfToken", false);
  }

  function afterAll() {
    cleanupPromos();
  }

  function run() {
    describe("Admin promo and entitlement endpoints", function() {
      it("rejects non-admin endpoint access", function() {
        setupAdmin();
        session.user = { userId = 187, email = "member@example.invalid" };
        var response = variables.api.postJson("/api/v1/adminPromoCodes.cfc?method=handle&action=list", { action = "list" });
        expect(response.SUCCESS).toBeFalse(serializeJSON(response));
        expect(response.AUTH).toBeTrue(serializeJSON(response));
        expect(response.ERROR.CODE).toBe("FORBIDDEN");
      });

      it("permits authenticated admins to list promo and entitlement data", function() {
        setupAdmin();
        var promos = variables.api.postJson("/api/v1/adminPromoCodes.cfc?method=handle&action=list", { action = "list", limit = 1, offset = 0 });
        var entitlements = variables.api.postJson("/api/v1/adminMemberEntitlements.cfc?method=handle&action=list", { action = "list", limit = 1, offset = 0 });
        expect(promos.SUCCESS).toBeTrue(serializeJSON(promos));
        expect(entitlements.SUCCESS).toBeTrue(serializeJSON(entitlements));
      });

      it("rejects writes without the matching CSRF nonce", function() {
        setupAdmin();
        var response = variables.api.postJson("/api/v1/adminPromoCodes.cfc?method=handle&action=save", promoPayload(uniqueCode("csrf")), true, false);
        expect(response.SUCCESS).toBeFalse(serializeJSON(response));
        expect(response.ERROR.CODE).toBe("CSRF_INVALID");
      });

      it("rejects token-based database backup GET and requires centralized CSRF", function() {
        setupAdmin();
        var legacyGet = variables.api.getJson("/api/v1/dbBackup.cfc?method=exportLiveDatabase&token=legacy-token");
        expect(legacyGet.SUCCESS).toBeFalse(serializeJSON(legacyGet));
        expect(legacyGet.STATUS_CODE).toInclude("405");
        expect(legacyGet.ERROR.CODE).toBe("METHOD_NOT_ALLOWED");

        var missingCsrf = variables.api.postJson(
          "/api/v1/dbBackup.cfc?method=exportLiveDatabase",
          {},
          true,
          false
        );
        expect(missingCsrf.SUCCESS).toBeFalse(serializeJSON(missingCsrf));
        expect(missingCsrf.STATUS_CODE).toInclude("403");
        expect(missingCsrf.ERROR.CODE).toBe("CSRF_INVALID");
      });

      it("creates, searches, updates, and audits a promo through the protected endpoint", function() {
        setupAdmin();
        var code = uniqueCode("endpoint");
        var payload = promoPayload(code);
        payload.nonce = session.adminPromoCodesNonce;
        var created = variables.api.postJson("/api/v1/adminPromoCodes.cfc?method=handle&action=save", payload);
        expect(created.SUCCESS).toBeTrue(serializeJSON(created));
        var promoId = val(created.DATA.promoCodeId);
        arrayAppend(variables.createdPromoIds, promoId);

        var listed = variables.api.postJson("/api/v1/adminPromoCodes.cfc?method=handle&action=list", { action = "list", search = lCase(code), limit = 10, offset = 0 });
        expect(listed.SUCCESS).toBeTrue(serializeJSON(listed));
        expect(listed.DATA.total).toBe(1);

        var changed = variables.api.postJson("/api/v1/adminPromoCodes.cfc?method=handle&action=state", {
          action = "state", nonce = session.adminPromoCodesNonce,
          promoCodeId = promoId, status = "disabled", reason = "Endpoint state test"
        });
        expect(changed.SUCCESS).toBeTrue(serializeJSON(changed));
        expect(changed.DATA.promo.status).toBe("disabled");

        var detail = variables.api.postJson("/api/v1/adminPromoCodes.cfc?method=handle&action=get", { action = "get", promoCodeId = promoId });
        expect(detail.SUCCESS).toBeTrue(serializeJSON(detail));
        expect(arrayLen(detail.DATA.audit)).toBeGTE(2);
      });
    });
  }

  private struct function promoPayload(required string code) {
    return {
      action = "save",
      code = arguments.code,
      internalName = "Endpoint admin test",
      publicDescription = "Disposable endpoint test",
      promoType = "admin_grant",
      status = "active",
      adminGrantKind = "fixed_duration",
      adminGrantDurationDays = 7,
      startsAtUtc = dateTimeFormat(dateAdd("h", -1, dateConvert("local2utc", now())), "yyyy-mm-dd HH:nn:ss"),
      expiresAtUtc = dateTimeFormat(dateAdd("d", 7, dateConvert("local2utc", now())), "yyyy-mm-dd HH:nn:ss"),
      maxRedemptions = 10,
      onePerUser = true,
      entitlementType = "premium",
      reason = "Endpoint automated test"
    };
  }

  private void function setupAdmin() {
    variables.hadSessionUser = structKeyExists(session, "user") AND isStruct(session.user);
    variables.priorSessionUser = variables.hadSessionUser ? duplicate(session.user) : {};
    session.user = { userId = 1, id = 1, USERID = 1 };
    session.adminPromoCodesNonce = "endpoint-promo-" & createUUID();
    session.adminMemberEntitlementsNonce = "endpoint-entitlement-" & createUUID();
    session.fpwAdminCsrfToken = lCase(replace(createUUID(), "-", "", "all")) & lCase(replace(createUUID(), "-", "", "all"));
    variables.api = new fpw.tests.support.FpwApiSupport().init(baseUrl = variables.baseUrl);
  }

  private string function uniqueCode(required string prefix) {
    return "ADMIN-ENDPOINT-" & uCase(arguments.prefix) & "-" & replace(createUUID(), "-", "", "all");
  }

  private void function cleanupPromos() {
    if (!arrayLen(variables.createdPromoIds)) return;
    queryExecute(
      "DELETE FROM fpw_admin_audit_log WHERE entity_type = 'promo_code' AND entity_id IN (:promoIds)",
      { promoIds = { value = arrayToList(variables.createdPromoIds), cfsqltype = "cf_sql_varchar", list = true } },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM fpw_promo_codes WHERE promo_code_id IN (:promoIds)",
      { promoIds = { value = arrayToList(variables.createdPromoIds), cfsqltype = "cf_sql_bigint", list = true } },
      { datasource = "fpw" }
    );
    variables.createdPromoIds = [];
  }
}






