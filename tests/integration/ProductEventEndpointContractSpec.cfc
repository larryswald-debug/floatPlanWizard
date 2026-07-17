component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    ensureProductEventsTable();
    variables.createdUserIds = [];
    variables.createdVesselIds = [];
    variables.createdContactIds = [];
    variables.createdEntitlementIds = [];
    variables.originalProductEventTestState = snapshotProductEventTestState();
    variables.configuredEnvironment = new fpw.api.v1.StripeConfigService().init().getFpwEnv();
    variables.configuredForceFailureSetting = new fpw.api.v1.StripeConfigService().init().getProductEventsForceFailure();
  }

  function beforeEach() {
    application.env = variables.configuredEnvironment;
    if (!structKeyExists(application, "settings") || !isStruct(application.settings)) {
      application.settings = {};
    }
    application.settings.FPW_PRODUCT_EVENTS_FORCE_FAILURE = "false";
  }

  function afterEach() {
    cleanupCreatedRows();
  }

  function afterAll() {
    restoreProductEventTestState(variables.originalProductEventTestState);
    if (!structKeyExists(application, "settings") || !isStruct(application.settings)) {
      application.settings = {};
    }
    application.settings.FPW_PRODUCT_EVENTS_FORCE_FAILURE = variables.configuredForceFailureSetting;
  }

  function run() {
    describe("Phase 1 authoritative product-event endpoints", function() {
      it("records sign_up once after persistence and not for validation or duplicate rejection", function() {
        var beforeInvalid = countAllEvents("sign_up");
        var invalidApi = new fpw.tests.support.FpwApiSupport().init(inheritCookie = false);
        var invalid = invalidApi.postJson("/api/v1/join.cfc?method=handle", {}, false);
        var signupState = createSignedUpMember();
        var duplicate = signupState.api.postJson(
          "/api/v1/join.cfc?method=handle",
          signupState.requestBody,
          false
        );

        expect(invalid.SUCCESS).toBeFalse(serializeJSON(invalid));
        expect(countAllEvents("sign_up")).toBe(beforeInvalid + 1);
        expect(countUserEvents(signupState.userId, "sign_up")).toBe(1);
        expect(duplicate.SUCCESS).toBeFalse(serializeJSON(duplicate));
        expect(duplicate.ERROR).toBe("EMAIL_EXISTS");
        expect(countUserEvents(signupState.userId, "sign_up")).toBe(1);
      });

      it("records only successful explicit password login", function() {
        var signupState = createSignedUpMember();
        var loginApi = new fpw.tests.support.FpwApiSupport().init(inheritCookie = false);
        var wrongPassword = loginApi.postJson("/api/v1/auth.cfc?method=handle", {
          action = "login",
          email = signupState.email,
          password = "WrongPass123!"
        }, false);
        var unknownBefore = countAllEvents("login");
        var unknownUser = loginApi.postJson("/api/v1/auth.cfc?method=handle", {
          action = "login",
          email = "missing-" & lCase(replace(createUUID(), "-", "", "all")) & "@example.test",
          password = signupState.password
        }, false);
        var login = loginApi.postJson("/api/v1/auth.cfc?method=handle", {
          action = "login",
          email = signupState.email,
          password = signupState.password
        }, false);
        var inheritedApi = new fpw.tests.support.FpwApiSupport().init();
        var beforeExistingSessionView = countAllEvents("login");
        var me = inheritedApi.getJson("/api/v1/me.cfc?method=handle");

        expect(wrongPassword.SUCCESS).toBeFalse(serializeJSON(wrongPassword));
        expect(unknownUser.SUCCESS).toBeFalse(serializeJSON(unknownUser));
        expect(login.SUCCESS).toBeTrue(serializeJSON(login));
        expect(countUserEvents(signupState.userId, "login")).toBe(1);
        expect(countAllEvents("login")).toBe(unknownBefore + 1);
        expect(me.SUCCESS).toBeTrue(serializeJSON(me));
        expect(countAllEvents("login")).toBe(beforeExistingSessionView);
      });

      it("records member vessel creation once and excludes validation, update, default, list, and delete", function() {
        grantPremium(currentSessionUserId());
        var memberApi = new fpw.tests.support.FpwApiSupport().init();
        var invalid = memberApi.saveVessel({ vesselId = 0 });
        var created = memberApi.saveVessel({
          vesselId = 0,
          vesselName = "Product Event Test Vessel",
          type = "Cruiser",
          length = 32,
          color = "White"
        });
        var vesselId = val(created.VESSELID ?: 0);
        arrayAppend(variables.createdVesselIds, vesselId);
        var updated = memberApi.saveVessel({
          vesselId = vesselId,
          vesselName = "Product Event Test Vessel Updated",
          type = "Cruiser",
          length = 32,
          color = "Blue",
          isDefaultVessel = true
        });
        var listed = memberApi.listVessels(10);
        var deleted = memberApi.deleteVessel(vesselId);

        expect(invalid.SUCCESS).toBeFalse(serializeJSON(invalid));
        expect(created.SUCCESS).toBeTrue(serializeJSON(created));
        expect(vesselId).toBeGT(0);
        expect(updated.SUCCESS).toBeTrue(serializeJSON(updated));
        expect(listed.SUCCESS).toBeTrue(serializeJSON(listed));
        expect(deleted.SUCCESS).toBeTrue(serializeJSON(deleted));
        expect(countEntityEvents("vessel_created", "vessel", vesselId)).toBe(1);
      });

      it("records member shore-contact creation once and excludes validation, update, list, and delete", function() {
        grantPremium(currentSessionUserId());
        var memberApi = new fpw.tests.support.FpwApiSupport().init();
        var invalid = memberApi.saveContact({ contactId = 0 });
        var created = memberApi.saveContact({
          contactId = 0,
          name = "Product Event Contact",
          phone = "5555551212",
          email = "product-event-contact@example.test"
        });
        var contactId = val(created.CONTACTID ?: 0);
        arrayAppend(variables.createdContactIds, contactId);
        var updated = memberApi.saveContact({
          contactId = contactId,
          name = "Product Event Contact Updated",
          phone = "5555553434",
          email = "product-event-contact-updated@example.test"
        });
        var listed = memberApi.listContacts(10);
        var deleted = memberApi.deleteContact(contactId);

        expect(invalid.SUCCESS).toBeFalse(serializeJSON(invalid));
        expect(created.SUCCESS).toBeTrue(serializeJSON(created));
        expect(contactId).toBeGT(0);
        expect(updated.SUCCESS).toBeTrue(serializeJSON(updated));
        expect(listed.SUCCESS).toBeTrue(serializeJSON(listed));
        expect(deleted.SUCCESS).toBeTrue(serializeJSON(deleted));
        expect(countEntityEvents("shore_contact_created", "shore_contact", contactId)).toBe(1);
      });

      it("keeps successful signup isolated from a forced product-event failure", function() {
        var api = new fpw.tests.support.FpwApiSupport().init(inheritCookie = false);
        var email = "fpw-product-events-forced-" & lCase(replace(createUUID(), "-", "", "all")) & "@example.test";
        var password = "ProductEvent123!";
        var signup = {};
        var userId = 0;
        var responseJson = "";

        enableForcedProductEventFailure();
        signup = api.postJson("/api/v1/join.cfc?method=handle", {
          firstName = "Product",
          lastName = "Event",
          email = email,
          password = password,
          confirmPassword = password,
          termsAccepted = true
        }, false);
        userId = val(signup.USERID ?: 0);
        responseJson = serializeJSON(signup);

        expect(signup.SUCCESS).toBeTrue(responseJson);
        expect(signup.AUTH).toBeTrue(responseJson);
        expect(userId).toBeGT(0, responseJson);
        arrayAppend(variables.createdUserIds, userId);
        expect(countUserRows(userId)).toBe(1);
        expect(countUserEvents(userId, "sign_up")).toBe(0);
        expect(findNoCase("FPW.ProductEvent.ForcedTestFailure", responseJson)).toBe(0);
        expect(findNoCase("forced product-event", responseJson)).toBe(0);
        expect(findNoCase("analytics", responseJson)).toBe(0);
      });

      it("keeps successful login isolated from a forced product-event failure", function() {
        var signupState = createSignedUpMember();
        var loginApi = new fpw.tests.support.FpwApiSupport().init(inheritCookie = false);
        var wrongPassword = {};
        var login = {};

        enableForcedProductEventFailure();
        wrongPassword = loginApi.postJson("/api/v1/auth.cfc?method=handle", {
          action = "login",
          email = signupState.email,
          password = "WrongPass123!"
        }, false);
        expect(wrongPassword.SUCCESS).toBeFalse(serializeJSON(wrongPassword));
        expect(countUserEvents(signupState.userId, "login")).toBe(0);

        login = loginApi.postJson("/api/v1/auth.cfc?method=handle", {
          action = "login",
          email = signupState.email,
          password = signupState.password
        }, false);
        expect(login.SUCCESS).toBeTrue(serializeJSON(login));
        expect(isStruct(login.USER)).toBeTrue(serializeJSON(login));
        expect(val(login.USER.userId ?: login.USER.USERID ?: 0)).toBe(signupState.userId);
        expect(countUserEvents(signupState.userId, "login")).toBe(0);
        expect(findNoCase("forced product-event", serializeJSON(login))).toBe(0);
      });

      it("keeps successful vessel creation isolated from a forced product-event failure", function() {
        var userId = currentSessionUserId();
        var memberApi = new fpw.tests.support.FpwApiSupport().init();
        var created = {};
        var vesselId = 0;

        grantPremium(userId);
        enableForcedProductEventFailure();
        created = memberApi.saveVessel({
          vesselId = 0,
          vesselName = "Forced Failure Test Vessel",
          type = "Cruiser",
          length = 32,
          color = "White"
        });
        vesselId = val(created.VESSELID ?: 0);
        arrayAppend(variables.createdVesselIds, vesselId);

        expect(created.SUCCESS).toBeTrue(serializeJSON(created));
        expect(vesselId).toBeGT(0, serializeJSON(created));
        expect(countVesselRows(vesselId)).toBe(1);
        expect(countEntityEvents("vessel_created", "vessel", vesselId)).toBe(0);
        expect(findNoCase("forced product-event", serializeJSON(created))).toBe(0);
      });

      it("keeps successful shore-contact creation isolated from a forced product-event failure", function() {
        var userId = currentSessionUserId();
        var memberApi = new fpw.tests.support.FpwApiSupport().init();
        var created = {};
        var contactId = 0;

        grantPremium(userId);
        enableForcedProductEventFailure();
        created = memberApi.saveContact({
          contactId = 0,
          name = "Forced Failure Contact",
          phone = "5555551212",
          email = "forced-failure-contact@example.test"
        });
        contactId = val(created.CONTACTID ?: 0);
        arrayAppend(variables.createdContactIds, contactId);

        expect(created.SUCCESS).toBeTrue(serializeJSON(created));
        expect(contactId).toBeGT(0, serializeJSON(created));
        expect(countContactRows(contactId)).toBe(1);
        expect(countEntityEvents("shore_contact_created", "shore_contact", contactId)).toBe(0);
        expect(findNoCase("forced product-event", serializeJSON(created))).toBe(0);
      });

      it("keeps instrumentation isolated and excludes administrative vessel creation", function() {
        var joinSource = fileRead(expandPath("/fpw/api/v1/join.cfc"), "utf-8");
        var authSource = fileRead(expandPath("/fpw/api/v1/auth.cfc"), "utf-8");
        var vesselSource = fileRead(expandPath("/fpw/api/v1/vessel.cfc"), "utf-8");
        var contactSource = fileRead(expandPath("/fpw/api/v1/contact.cfc"), "utf-8");
        var adminVesselSource = fileRead(expandPath("/fpw/api/v1/adminVessels.cfc"), "utf-8");

        expect(findNoCase('eventName = "sign_up"', joinSource)).toBeGT(0);
        expect(findNoCase('eventName = "sign_up"', joinSource)).toBeLT(findNoCase("sendWelcomeMemberEmail", joinSource));
        expect(findNoCase("PRODUCT_EVENT_CALL_FAILED", joinSource)).toBeGT(0);
        expect(findNoCase("PRODUCT_EVENT_CALL_FAILED", authSource)).toBeGT(0);
        expect(findNoCase("PRODUCT_EVENT_CALL_FAILED", vesselSource)).toBeGT(0);
        expect(findNoCase("PRODUCT_EVENT_CALL_FAILED", contactSource)).toBeGT(0);
        expect(findNoCase("ProductEventService", adminVesselSource)).toBe(0);
      });
    });
  }

  private struct function snapshotProductEventTestState() {
    return {
      envExists = structKeyExists(application, "env"),
      env = structKeyExists(application, "env") ? application.env : "",
      settingsExists = structKeyExists(application, "settings") && isStruct(application.settings),
      settings = structKeyExists(application, "settings") && isStruct(application.settings)
        ? duplicate(application.settings)
        : {}
    };
  }

  private void function restoreProductEventTestState(required struct originalState) {
    if (arguments.originalState.envExists) {
      application.env = arguments.originalState.env;
    } else {
      structDelete(application, "env", false);
    }

    if (arguments.originalState.settingsExists) {
      application.settings = arguments.originalState.settings;
    } else {
      structDelete(application, "settings", false);
    }
  }

  private void function enableForcedProductEventFailure() {
    application.env = "dev";
    if (!structKeyExists(application, "settings") || !isStruct(application.settings)) {
      application.settings = {};
    }
    application.settings.FPW_PRODUCT_EVENTS_FORCE_FAILURE = "true";
  }

  private numeric function countUserRows(required numeric userId) {
    var qCount = queryExecute(
      "SELECT COUNT(*) AS row_count FROM users WHERE userId = :userId",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    return val(qCount.row_count[1]);
  }

  private numeric function countVesselRows(required numeric vesselId) {
    var qCount = queryExecute(
      "SELECT COUNT(*) AS row_count FROM vessels WHERE vesselID = :vesselId",
      {
        vesselId = { value = arguments.vesselId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    return val(qCount.row_count[1]);
  }

  private numeric function countContactRows(required numeric contactId) {
    var qCount = queryExecute(
      "SELECT COUNT(*) AS row_count FROM contacts WHERE contactId = :contactId",
      {
        contactId = { value = arguments.contactId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    return val(qCount.row_count[1]);
  }

  private struct function createSignedUpMember() {
    var api = new fpw.tests.support.FpwApiSupport().init(inheritCookie = false);
    var email = "fpw-product-events-" & lCase(replace(createUUID(), "-", "", "all")) & "@example.test";
    var password = "ProductEvent123!";
    var requestBody = {
      firstName = "Product",
      lastName = "Event",
      email = email,
      password = password,
      confirmPassword = password,
      termsAccepted = true
    };
    var signup = api.postJson("/api/v1/join.cfc?method=handle", requestBody, false);
    var userId = val(signup.USERID ?: 0);

    expect(signup.SUCCESS).toBeTrue(serializeJSON(signup));
    expect(userId).toBeGT(0, serializeJSON(signup));
    arrayAppend(variables.createdUserIds, userId);

    return {
      api = api,
      email = email,
      password = password,
      requestBody = requestBody,
      userId = userId
    };
  }

  private numeric function grantPremium(required numeric userId) {
    var insertResult = {};
    queryExecute(
      "INSERT INTO member_entitlements (
         user_id, entitlement_type, source, status, starts_at_utc, created_utc, updated_utc
       ) VALUES (
         :userId, 'premium', 'admin_comp', 'active', UTC_TIMESTAMP(), UTC_TIMESTAMP(), UTC_TIMESTAMP()
       )",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      },
      {
        datasource = "fpw",
        result = "insertResult"
      }
    );
    var entitlementId = val(insertResult.generatedKey ?: 0);
    if (entitlementId GT 0) {
      arrayAppend(variables.createdEntitlementIds, entitlementId);
    }
    return entitlementId;
  }

  private numeric function currentSessionUserId() {
    if (structKeyExists(session, "user") AND isStruct(session.user)) {
      if (structKeyExists(session.user, "userId")) {
        return val(session.user.userId);
      }
      if (structKeyExists(session.user, "id")) {
        return val(session.user.id);
      }
      if (structKeyExists(session.user, "USERID")) {
        return val(session.user.USERID);
      }
    }
    return 0;
  }

  private numeric function countUserEvents(required numeric userId, required string eventName) {
    var qCount = queryExecute(
      "SELECT COUNT(*) AS row_count
       FROM product_events
       WHERE user_id = :userId
         AND event_name = :eventName",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        eventName = { value = arguments.eventName, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    return val(qCount.row_count[1]);
  }

  private numeric function countAllEvents(required string eventName) {
    var qCount = queryExecute(
      "SELECT COUNT(*) AS row_count FROM product_events WHERE event_name = :eventName",
      {
        eventName = { value = arguments.eventName, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    return val(qCount.row_count[1]);
  }

  private numeric function countEntityEvents(
    required string eventName,
    required string entityType,
    required numeric entityId
  ) {
    var qCount = queryExecute(
      "SELECT COUNT(*) AS row_count
       FROM product_events
       WHERE event_name = :eventName
         AND entity_type = :entityType
         AND entity_id = :entityId",
      {
        eventName = { value = arguments.eventName, cfsqltype = "cf_sql_varchar" },
        entityType = { value = arguments.entityType, cfsqltype = "cf_sql_varchar" },
        entityId = { value = arguments.entityId, cfsqltype = "cf_sql_bigint" }
      },
      { datasource = "fpw" }
    );
    return val(qCount.row_count[1]);
  }

  private void function cleanupCreatedRows() {
    var userId = 0;
    for (userId in variables.createdUserIds) {
      queryExecute("DELETE FROM product_events WHERE user_id = :userId", {
        userId = { value = userId, cfsqltype = "cf_sql_integer" }
      }, { datasource = "fpw" });
      queryExecute("DELETE FROM contacts WHERE userId = :userId", {
        userId = { value = userId, cfsqltype = "cf_sql_varchar" }
      }, { datasource = "fpw" });
      queryExecute("DELETE FROM vessels WHERE userId = :userId", {
        userId = { value = userId, cfsqltype = "cf_sql_varchar" }
      }, { datasource = "fpw" });
      queryExecute("DELETE FROM member_entitlements WHERE user_id = :userId", {
        userId = { value = userId, cfsqltype = "cf_sql_integer" }
      }, { datasource = "fpw" });
      queryExecute("DELETE FROM users_address WHERE userId = :userId", {
        userId = { value = userId, cfsqltype = "cf_sql_integer" }
      }, { datasource = "fpw" });
      queryExecute("DELETE FROM users WHERE userId = :userId", {
        userId = { value = userId, cfsqltype = "cf_sql_integer" }
      }, { datasource = "fpw" });
    }
    var vesselId = 0;
    for (vesselId in variables.createdVesselIds) {
      queryExecute(
        "DELETE FROM product_events WHERE entity_type = 'vessel' AND entity_id = :entityId",
        {
          entityId = { value = vesselId, cfsqltype = "cf_sql_bigint" }
        },
        { datasource = "fpw" }
      );
      queryExecute(
        "DELETE FROM vessels WHERE vesselID = :entityId",
        {
          entityId = { value = vesselId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
    }
    var contactId = 0;
    for (contactId in variables.createdContactIds) {
      queryExecute(
        "DELETE FROM product_events WHERE entity_type = 'shore_contact' AND entity_id = :entityId",
        {
          entityId = { value = contactId, cfsqltype = "cf_sql_bigint" }
        },
        { datasource = "fpw" }
      );
      queryExecute(
        "DELETE FROM contacts WHERE contactId = :entityId",
        {
          entityId = { value = contactId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
    }
    var entitlementId = 0;
    for (entitlementId in variables.createdEntitlementIds) {
      queryExecute(
        "DELETE FROM member_entitlements WHERE id = :entitlementId",
        {
          entitlementId = { value = entitlementId, cfsqltype = "cf_sql_bigint" }
        },
        { datasource = "fpw" }
      );
    }
    variables.createdUserIds = [];
    variables.createdVesselIds = [];
    variables.createdContactIds = [];
    variables.createdEntitlementIds = [];
  }

  private void function ensureProductEventsTable() {
    queryExecute(
      "CREATE TABLE IF NOT EXISTS product_events (
         id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
         event_uuid CHAR(36) NOT NULL,
         user_id INT NOT NULL,
         event_name VARCHAR(64) NOT NULL,
         entity_type VARCHAR(40) NOT NULL,
         entity_id BIGINT UNSIGNED NOT NULL,
         event_source VARCHAR(64) NOT NULL,
         occurred_at_utc DATETIME NOT NULL,
         request_correlation_id VARCHAR(64) NULL,
         metadata_json JSON NULL,
         created_at_utc DATETIME NOT NULL,
         idempotency_key VARCHAR(191) NOT NULL,
         PRIMARY KEY (id),
         UNIQUE KEY uq_product_events_event_uuid (event_uuid),
         UNIQUE KEY uq_product_events_idempotency (idempotency_key),
         KEY idx_product_events_user_time (user_id, occurred_at_utc, id),
         KEY idx_product_events_name_time (event_name, occurred_at_utc, id)
       ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
      {},
      { datasource = "fpw" }
    );
  }

}
