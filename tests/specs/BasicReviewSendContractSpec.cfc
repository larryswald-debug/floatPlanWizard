component extends="testbox.system.BaseSpec" output="false" {

  variables.datasource = "fpw";
  variables.fixtureEmailPrefix = "codex-basic-review-send-";
  variables.testPdfPath = "";

  function beforeAll() {
    variables.fixtureEmailPrefix &= lCase(replace(createUUID(), "-", "", "all")) & "-";
    cleanupFixtures();
    variables.testPdfPath = getTempDirectory() & variables.fixtureEmailPrefix & "test.pdf";
    fileWrite(variables.testPdfPath, "%PDF-1.4" & chr(10) & "%%EOF", "utf-8");
  }

  function afterAll() {
    cleanupFixtures();
    if (len(variables.testPdfPath) AND fileExists(variables.testPdfPath)) {
      fileDelete(variables.testPdfPath);
    }
  }

  function run() {
    describe("Basic Review Send service contract", function() {

      beforeEach(function() {
        cleanupFixtures();
      });

      afterEach(function() {
        cleanupFixtures();
      });

      it("auto-selects one canonical saved contact and requires a choice when several are saved", function() {
        var singleFixture = createFixture("single", [
          { name = "Single Contact", email = "single@example.test" }
        ]);
        var singleService = createService(true, true);
        var singleResult = singleService.getConfirmation(singleFixture.userId, singleFixture.floatPlanId);
        var multiFixture = createFixture("multi", [
          { name = "First Contact", email = "first@example.test" },
          { name = "Second Contact", email = "second@example.test" }
        ]);
        var multiService = createService(true, true);
        var multiResult = multiService.getConfirmation(multiFixture.userId, multiFixture.floatPlanId);

        expect(singleResult.SUCCESS).toBeTrue();
        expect(singleResult.CONTACT_COUNT).toBe(1);
        expect(singleResult.REQUIRES_SELECTION).toBeFalse();
        expect(singleResult.SELECTED_CONTACT_ID).toBe(singleFixture.contactIds[1]);
        expect(singleResult.CONTACTS[1].EMAIL).toBe("single@example.test");

        expect(multiResult.SUCCESS).toBeTrue();
        expect(multiResult.CONTACT_COUNT).toBe(2);
        expect(multiResult.REQUIRES_SELECTION).toBeTrue();
        expect(multiResult.SELECTED_CONTACT_ID).toBe(0);
      });

      it("rejects missing email, unselected contacts, and cross-member access before delivery", function() {
        var invalidFixture = createFixture("invalid-email", [
          { name = "Invalid Contact", email = "not-an-email" }
        ]);
        var targetFixture = createFixture("target", [
          { name = "Target Contact", email = "target@example.test" }
        ]);
        var otherFixture = createFixture("other", [
          { name = "Other Contact", email = "other@example.test" }
        ]);
        var emailStub = createObject("component", "fpw.tests.support.BasicReviewSendEmailStub").init(true);
        var pdfStub = createObject("component", "fpw.tests.support.BasicReviewSendPdfStub").init(variables.testPdfPath, true);
        var service = createObject("component", "fpw.api.v1.BasicReviewSendService").init(
          variables.datasource,
          emailStub,
          pdfStub
        );
        var invalidResult = service.getConfirmation(invalidFixture.userId, invalidFixture.floatPlanId);
        var unselectedResult = service.send(
          targetFixture.userId,
          targetFixture.floatPlanId,
          otherFixture.contactIds[1],
          "basic_review_unselected_1234567890"
        );
        var unauthorizedResult = service.send(
          otherFixture.userId,
          targetFixture.floatPlanId,
          targetFixture.contactIds[1],
          "basic_review_unauthorized_1234567890"
        );

        expect(invalidResult.SUCCESS).toBeFalse();
        expect(invalidResult.ERROR).toBe("CONTACT_EMAIL_REQUIRED");
        expect(unselectedResult.ERROR).toBe("CONTACT_NOT_SELECTED");
        expect(unauthorizedResult.ERROR).toBe("PLAN_NOT_FOUND");
        expect(arrayLen(emailStub.getCalls())).toBe(0);
        expect(loadShareEvents(invalidFixture.userId).recordCount).toBe(0);
        expect(loadShareEvents(targetFixture.userId).recordCount).toBe(0);
        expect(loadShareEvents(otherFixture.userId).recordCount).toBe(0);
      });

      it("delivers once per token, replays duplicates, and permits deliberate resends with a new token", function() {
        var fixture = createFixture("idempotency", [
          { name = "Delivery Contact", email = "delivery@example.test" }
        ]);
        var emailStub = createObject("component", "fpw.tests.support.BasicReviewSendEmailStub").init(true);
        var pdfStub = createObject("component", "fpw.tests.support.BasicReviewSendPdfStub").init(variables.testPdfPath, true);
        var service = createObject("component", "fpw.api.v1.BasicReviewSendService").init(
          variables.datasource,
          emailStub,
          pdfStub
        );
        var firstKey = "basic_review_first_12345678901234567890";
        var secondKey = "basic_review_second_12345678901234567890";
        var firstResult = service.send(fixture.userId, fixture.floatPlanId, fixture.contactIds[1], firstKey);
        var firstEventCount = loadShareEvents(fixture.userId).recordCount;
        var replayResult = service.send(fixture.userId, fixture.floatPlanId, fixture.contactIds[1], firstKey);
        var replayEventCount = loadShareEvents(fixture.userId).recordCount;
        var resendResult = service.send(fixture.userId, fixture.floatPlanId, fixture.contactIds[1], secondKey);
        var qReceipts = queryExecute(
          "SELECT status, COUNT(*) AS receipt_count
           FROM basic_review_send_receipts
           WHERE user_id = :userId
             AND float_plan_id = :floatPlanId
           GROUP BY status",
          {
            userId = { value = fixture.userId, cfsqltype = "cf_sql_integer" },
            floatPlanId = { value = fixture.floatPlanId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = variables.datasource }
        );
        var invariants = loadInvariants(fixture.userId, fixture.floatPlanId);
        var calls = emailStub.getCalls();

        expect(firstResult.SUCCESS).toBeTrue();
        expect(firstEventCount).toBe(1);
        expect(replayEventCount).toBe(1);
        expect(firstResult.SENT_COUNT).toBe(1);
        expect(firstResult.RECIPIENT.CONTACTID).toBe(fixture.contactIds[1]);
        expect(replayResult.SUCCESS).toBeTrue();
        expect(replayResult.IDEMPOTENT_REPLAY).toBeTrue();
        expect(resendResult.SUCCESS).toBeTrue();
        expect(arrayLen(calls)).toBe(2);
        expect(calls[1].pdfPath).toBe(variables.testPdfPath);
        expect(calls[2].pdfPath).toBe(variables.testPdfPath);
        expect(qReceipts.recordCount).toBe(1);
        expect(qReceipts.status[1]).toBe("SENT");
        expect(val(qReceipts.receipt_count[1])).toBe(2);
        expect(invariants.plan_status).toBe("DRAFT");
        expect(invariants.float_plan_count).toBe(1);
        expect(invariants.premium_credit_count).toBe(0);
        expect(invariants.premium_receipt_count).toBe(0);
        expect(invariants.monitoring_count).toBe(0);
        expect(invariants.voyage_stream_count).toBe(0);
        expect(loadShareEvents(fixture.userId).recordCount).toBe(2);
        expect(hasShared(fixture.userId)).toBeTrue();
      });

      it("records PDF failure without sending email or changing trip state", function() {
        var fixture = createFixture("pdf-failure", [
          { name = "PDF Contact", email = "pdf@example.test" }
        ]);
        var emailStub = createObject("component", "fpw.tests.support.BasicReviewSendEmailStub").init(true);
        var pdfStub = createObject("component", "fpw.tests.support.BasicReviewSendPdfStub").init(variables.testPdfPath, false);
        var service = createObject("component", "fpw.api.v1.BasicReviewSendService").init(
          variables.datasource,
          emailStub,
          pdfStub
        );
        var key = "basic_review_pdf_failure_123456789012345";
        var result = service.send(fixture.userId, fixture.floatPlanId, fixture.contactIds[1], key);
        var replay = service.send(fixture.userId, fixture.floatPlanId, fixture.contactIds[1], key);
        var qReceipt = queryExecute(
          "SELECT status, error_code
           FROM basic_review_send_receipts
           WHERE idempotency_key = :idempotencyKey
           LIMIT 1",
          {
            idempotencyKey = { value = key, cfsqltype = "cf_sql_varchar" }
          },
          { datasource = variables.datasource }
        );
        var invariants = loadInvariants(fixture.userId, fixture.floatPlanId);

        expect(result.SUCCESS).toBeFalse();
        expect(result.ERROR).toBe("PDF_FAILED");
        expect(replay.SUCCESS).toBeFalse();
        expect(replay.IDEMPOTENT_REPLAY).toBeTrue();
        expect(arrayLen(emailStub.getCalls())).toBe(0);
        expect(qReceipt.status[1]).toBe("FAILED");
        expect(qReceipt.error_code[1]).toBe("PDF_FAILED");
        expect(invariants.plan_status).toBe("DRAFT");
        expect(invariants.premium_credit_count).toBe(0);
        expect(invariants.monitoring_count).toBe(0);
        expect(invariants.voyage_stream_count).toBe(0);
        expect(loadShareEvents(fixture.userId).recordCount).toBe(0);
      });

      it("retains account-owned Basic share evidence after supported parent-route deletion cascades the receipt", function() {
        var fixture = createFixture("durable", [{ name="Private Shore Name", email="private-shore@example.test" }]);
        var other = createFixture("not-the-owner", []);
        var result = createService().send(fixture.userId, fixture.floatPlanId, fixture.contactIds[1],
          "basic_review_durable_123456789012345");
        var evidence = loadShareEvents(fixture.userId);
        var receipt = loadReceipt(result.RECEIPT_ID);
        expect(result.SUCCESS).toBeTrue();
        expect(receipt.status[1]).toBe("SENT");
        expect(isDate(receipt.completed_at_utc[1])).toBeTrue();
        expect(evidence.recordCount).toBe(1);
        expect(val(evidence.user_id[1])).toBe(fixture.userId);
        expect(val(evidence.entity_id[1])).toBe(fixture.floatPlanId);
        expect(evidence.event_name[1]).toBe("basic_send_completed");
        expect(evidence.entity_type[1]).toBe("float_plan");
        expect(evidence.event_source[1]).toBe("basic_review_send");
        expect(structIsEmpty(deserializeJSON(evidence.metadata_json[1]))).toBeTrue();
        expect(isNull(evidence.request_correlation_id[1]) OR !len(evidence.request_correlation_id[1])).toBeTrue();
        expect(findNoCase("private-shore", serializeJSON(evidence))).toBe(0);
        expect(findNoCase("Private Shore Name", serializeJSON(evidence))).toBe(0);
        expect(evidence.idempotency_key[1]).toBe("basic_send_completed:basic_review_receipt:" & result.RECEIPT_ID);

        var deleted = deleteParentRoute(fixture);
        expect(deleted.SUCCESS).toBeTrue();
        expect(countFixtureRecord("floatplans", "floatPlanId", fixture.floatPlanId)).toBe(0);
        expect(countFixtureRecord("route_instances", "id", fixture.routeInstanceId)).toBe(0);
        expect(countFixtureRecord("loop_routes", "id", fixture.routeId)).toBe(0);
        expect(loadReceipt(result.RECEIPT_ID).recordCount).toBe(0);
        expect(loadShareEvents(fixture.userId).recordCount).toBe(1);
        expect(hasShared(fixture.userId)).toBeTrue();
        expect(hasShared(other.userId)).toBeFalse();
      });

      it("leaves no successful-share event after a failed email submission", function() {
        var fixture = createFixture("email-failure", [{ name="Failed Contact", email="failed@example.test" }]);
        var emailStub = createObject("component", "fpw.tests.support.BasicReviewSendEmailStub").init(false);
        var service = createObject("component", "fpw.api.v1.BasicReviewSendService").init(variables.datasource,
          emailStub, createObject("component", "fpw.tests.support.BasicReviewSendPdfStub").init(variables.testPdfPath, true));
        var result = service.send(fixture.userId, fixture.floatPlanId, fixture.contactIds[1], "basic_review_email_failure_123456789");
        expect(result.SUCCESS).toBeFalse();
        expect(result.ERROR).toBe("TEST_EMAIL_FAILURE");
        var qFailure = queryExecute("SELECT status FROM basic_review_send_receipts WHERE user_id = :id",
          { id={ value=fixture.userId, cfsqltype="cf_sql_integer" } }, { datasource=variables.datasource });
        expect(qFailure.recordCount).toBe(1);
        expect(qFailure.status[1]).toBe("FAILED");
        expect(arrayLen(emailStub.getCalls())).toBe(1);
        expect(hasShared(fixture.userId)).toBeFalse();
        expect(loadShareEvents(fixture.userId).recordCount).toBe(0);
      });

      it("does not create sharing proof for a no-contact request or deletion without sending", function() {
        var fixture = createFixture("unsent", []);
        var result = createService().send(fixture.userId, fixture.floatPlanId, 0, "basic_review_zero_contact_1234567890");
        expect(result.SUCCESS).toBeFalse();
        expect(result.ERROR).toBe("NO_CONTACTS");
        expect(deleteParentRoute(fixture).SUCCESS).toBeTrue();
        expect(hasShared(fixture.userId)).toBeFalse();
        expect(loadShareEvents(fixture.userId).recordCount).toBe(0);
      });

      it("preserves route-backed eligibility and rejects route-less review sends", function() {
        var fixture = createFixture("route-less-negative", [{ name="Contact", email="route-less@example.test" }]);
        queryExecute("UPDATE floatplans SET route_instance_id = NULL WHERE floatPlanId = :id",
          { id={ value=fixture.floatPlanId, cfsqltype="cf_sql_integer" } }, { datasource=variables.datasource });
        var result = createService().send(fixture.userId, fixture.floatPlanId, fixture.contactIds[1], "basic_review_route_less_123456789012");
        expect(result.ERROR).toBe("ROUTE_PLAN_REQUIRED");
        expect(hasShared(fixture.userId)).toBeFalse();
      });

      it("fails closed on event persistence failure without repeating accepted email", function() {
        verifyEvidenceFailure("failure");
      });

      it("rolls back an inserted event with the uncompleted receipt after a finalization exception", function() {
        verifyEvidenceFailure("after_insert");
      });

      it("keeps existing Basic and Premium event contracts valid and rejects private metadata", function() {
        var fixture = createFixture("event-parity", []);
        var service = createObject("component", "fpw.includes.ProductEventService").init(variables.datasource);
        var premium = service.recordEvent(userId=fixture.userId, eventName="premium_send_completed",
          entityType="float_plan", entityId=fixture.floatPlanId, eventSource="premium_save_send",
          metadata={ premium_authority="general_premium" }, idempotencyKey=fixture.marker & ":premium");
        var premiumReplay = service.recordEvent(userId=fixture.userId, eventName="premium_send_completed",
          entityType="float_plan", entityId=fixture.floatPlanId, eventSource="premium_save_send",
          metadata={ premium_authority="general_premium" }, idempotencyKey=fixture.marker & ":premium");
        var basic = service.recordEvent(userId=fixture.userId, eventName="basic_send_completed",
          entityType="float_plan", entityId=fixture.floatPlanId, eventSource="basic_save_send",
          idempotencyKey=fixture.marker & ":basic");
        var rejected = service.recordEvent(userId=fixture.userId, eventName="basic_send_completed",
          entityType="float_plan", entityId=fixture.floatPlanId, eventSource="basic_review_send",
          metadata={ recipient_email="private@example.test" });
        expect(premium.SUCCESS).toBeTrue();
        expect(premiumReplay.SUCCESS).toBeTrue();
        expect(premiumReplay.DUPLICATE).toBeTrue();
        expect(basic.SUCCESS).toBeTrue();
        expect(rejected.ERROR).toBe("DISALLOWED_METADATA_KEY");
        expect(loadShareEvents(fixture.userId).recordCount).toBe(2);
        expect(hasShared(fixture.userId)).toBeTrue();
      });
    });
  }

  private any function createService(boolean emailSucceeds=true, boolean pdfSucceeds=true) {
    var emailStub = createObject("component", "fpw.tests.support.BasicReviewSendEmailStub").init(arguments.emailSucceeds);
    var pdfStub = createObject("component", "fpw.tests.support.BasicReviewSendPdfStub").init(variables.testPdfPath, arguments.pdfSucceeds);
    return createObject("component", "fpw.api.v1.BasicReviewSendService").init(
      variables.datasource,
      emailStub,
      pdfStub
    );
  }

  private struct function createFixture(required string suffix, required array contacts) {
    var marker = variables.fixtureEmailPrefix & arguments.suffix & "-" & lCase(reReplace(createUUID(), "[^A-Za-z0-9]", "", "all"));
    var userEmail = marker & "@example.test";
    var qUser = queryNew("");
    var qPlan = queryNew("");
    var fixture = {};
    var index = 0;
    var qContact = queryNew("");
    var routeCode = "";
    var qRoute = queryNew("");
    var qRouteInstance = queryNew("");

    queryExecute(
      "INSERT INTO users (fName, lName, email, password, passwordCreated, created)
       VALUES ('Codex', 'Basic Send', :email, :password, UTC_TIMESTAMP(), UTC_TIMESTAMP())",
      {
        email = { value = userEmail, cfsqltype = "cf_sql_varchar" },
        password = { value = hash(marker, "SHA-256"), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    qUser = queryExecute(
      "SELECT userId FROM users WHERE email = :email LIMIT 1",
      { email = { value = userEmail, cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );

    routeCode = "USER_ROUTE_" & val(qUser.userId[1]) & "_SHARE_" & left(hash(marker), 10);
    queryExecute(
      "INSERT INTO loop_routes (code, name, short_code, description, is_active)
       VALUES (:code, 'Basic Share Contract Route', :code, :marker, 1)",
      { code={ value=routeCode, cfsqltype="cf_sql_varchar" }, marker={ value=marker, cfsqltype="cf_sql_varchar" } },
      { datasource=variables.datasource }
    );
    qRoute = queryExecute("SELECT id FROM loop_routes WHERE short_code = :code",
      { code={ value=routeCode, cfsqltype="cf_sql_varchar" } }, { datasource=variables.datasource });
    queryExecute(
      "INSERT INTO route_instances (user_id, template_route_code, generated_route_id, generated_route_code,
         direction, trip_type, start_location, end_location, status)
       VALUES (:userId, :code, :routeId, :code, 'CCW', 'POINT_TO_POINT', 'Test Start', 'Test End', 'PLANNED')",
      { userId={ value=toString(val(qUser.userId[1])), cfsqltype="cf_sql_varchar" },
        code={ value=routeCode, cfsqltype="cf_sql_varchar" }, routeId={ value=qRoute.id[1], cfsqltype="cf_sql_integer" } },
      { datasource=variables.datasource }
    );
    qRouteInstance = queryExecute("SELECT id FROM route_instances WHERE generated_route_code = :code",
      { code={ value=routeCode, cfsqltype="cf_sql_varchar" } }, { datasource=variables.datasource });

    queryExecute(
      "INSERT INTO floatplans (
         userId, floatPlanName, dateCreated, lastUpdate, status, lastUpdateStatus,
         route_instance_id, route_origin, is_reusable, is_visible_in_route_library
       ) VALUES (
         :userId, :planName, UTC_TIMESTAMP(), UTC_TIMESTAMP(), 'DRAFT', UTC_TIMESTAMP(),
         :routeInstanceId, 'premium_saved_route', 1, 1
       )",
      {
        userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" },
        planName = { value = "Basic Review " & arguments.suffix, cfsqltype = "cf_sql_varchar" },
        routeInstanceId = { value = qRouteInstance.id[1], cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );
    qPlan = queryExecute(
      "SELECT floatPlanId FROM floatplans WHERE userId = :userId ORDER BY floatPlanId DESC LIMIT 1",
      { userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );

    fixture = {
      marker = marker,
      userId = val(qUser.userId[1]),
      floatPlanId = val(qPlan.floatPlanId[1]),
      routeId = val(qRoute.id[1]),
      routeCode = routeCode,
      routeInstanceId = val(qRouteInstance.id[1]),
      contactIds = []
    };
    for (index = 1; index LTE arrayLen(arguments.contacts); index++) {
      queryExecute(
        "INSERT INTO contacts (name, phone, userId, email)
         VALUES (:name, '', :userId, :email)",
        {
          name = { value = arguments.contacts[index].name, cfsqltype = "cf_sql_varchar" },
          userId = { value = toString(fixture.userId), cfsqltype = "cf_sql_varchar" },
          email = { value = arguments.contacts[index].email, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
      qContact = queryExecute(
        "SELECT contactId FROM contacts WHERE userId = :userId ORDER BY contactId DESC LIMIT 1",
        { userId = { value = toString(fixture.userId), cfsqltype = "cf_sql_varchar" } },
        { datasource = variables.datasource }
      );
      arrayAppend(fixture.contactIds, val(qContact.contactId[1]));
      queryExecute(
        "INSERT INTO floatplan_contacts (contactId, floatPlanId) VALUES (:contactId, :floatPlanId)",
        {
          contactId = { value = fixture.contactIds[index], cfsqltype = "cf_sql_integer" },
          floatPlanId = { value = fixture.floatPlanId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
    }
    return fixture;
  }

  private struct function loadInvariants(required numeric userId, required numeric floatPlanId) {
    var qState = queryExecute(
      "SELECT
         (SELECT UPPER(TRIM(status)) FROM floatplans WHERE floatPlanId = :floatPlanId AND userId = :userId) AS plan_status,
         (SELECT COUNT(*) FROM floatplans WHERE userId = :userId) AS float_plan_count,
         (SELECT COUNT(*) FROM premium_send_credits WHERE user_id = :userId) AS premium_credit_count,
         (SELECT COUNT(*) FROM premium_send_receipts WHERE user_id = :userId) AS premium_receipt_count,
         (SELECT COUNT(*) FROM floatplan_monitoring WHERE user_id = :userId OR float_plan_id = :floatPlanId) AS monitoring_count,
         (SELECT COUNT(*) FROM voyage_streams WHERE floatplan_id = :floatPlanId) AS voyage_stream_count",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );
    return {
      plan_status = qState.plan_status[1],
      float_plan_count = val(qState.float_plan_count[1]),
      premium_credit_count = val(qState.premium_credit_count[1]),
      premium_receipt_count = val(qState.premium_receipt_count[1]),
      monitoring_count = val(qState.monitoring_count[1]),
      voyage_stream_count = val(qState.voyage_stream_count[1])
    };
  }

  private void function cleanupFixtures() {
    var pattern = variables.fixtureEmailPrefix & "%";
    var params = { pattern = { value = pattern, cfsqltype = "cf_sql_varchar" } };
    queryExecute("DELETE FROM product_events WHERE user_id IN (SELECT userId FROM users WHERE email LIKE :pattern)",
      params, { datasource=variables.datasource });
    queryExecute(
      "DELETE FROM floatplan_contacts
       WHERE floatPlanId IN (
         SELECT floatPlanId FROM floatplans
         WHERE userId IN (SELECT CAST(userId AS CHAR) FROM users WHERE email LIKE :pattern)
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM floatplans
       WHERE userId IN (SELECT CAST(userId AS CHAR) FROM users WHERE email LIKE :pattern)",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM contacts
       WHERE userId IN (SELECT CAST(userId AS CHAR) FROM users WHERE email LIKE :pattern)",
      params,
      { datasource = variables.datasource }
    );
    queryExecute("DELETE FROM route_instances WHERE CAST(user_id AS UNSIGNED) IN (SELECT userId FROM users WHERE email LIKE :pattern)",
      params, { datasource=variables.datasource });
    queryExecute("DELETE FROM loop_routes WHERE description LIKE :pattern", params, { datasource=variables.datasource });
    queryExecute(
      "DELETE FROM users WHERE email LIKE :pattern",
      params,
      { datasource = variables.datasource }
    );
  }

  private query function loadShareEvents(required numeric userId) {
    return queryExecute("SELECT user_id, entity_id, entity_type, event_name, event_source, metadata_json,
      request_correlation_id, idempotency_key FROM product_events WHERE user_id = :id
      AND event_name IN ('basic_send_completed','premium_send_completed') ORDER BY id",
      { id={ value=arguments.userId, cfsqltype="cf_sql_integer" } }, { datasource=variables.datasource });
  }

  private boolean function hasShared(required numeric userId) {
    // Same EXISTS contract documented for future recovery; no join to deletable trips/receipts.
    var q = queryExecute("SELECT EXISTS (SELECT 1 FROM users u WHERE u.userId = :id AND EXISTS (
      SELECT 1 FROM product_events e WHERE e.user_id = u.userId AND e.entity_type = 'float_plan' AND (
        (e.event_name = 'basic_send_completed' AND e.event_source IN ('basic_save_send','basic_review_send'))
        OR (e.event_name = 'premium_send_completed' AND e.event_source = 'premium_save_send')
      ))) AS shared",
      { id={ value=arguments.userId, cfsqltype="cf_sql_integer" } }, { datasource=variables.datasource });
    return val(q.shared[1]) EQ 1;
  }

  private query function loadReceipt(required numeric receiptId) {
    return queryExecute("SELECT status, completed_at_utc FROM basic_review_send_receipts WHERE id = :id",
      { id={ value=arguments.receiptId, cfsqltype="cf_sql_bigint" } }, { datasource=variables.datasource });
  }

  private numeric function countFixtureRecord(required string tableName, required string idColumn, required numeric id) {
    if (!listFind("floatplans,route_instances,loop_routes", arguments.tableName)
        OR !listFind("floatPlanId,id", arguments.idColumn)) {
      throw(type="FPW.TestInvalidTable", message="Unsupported fixture table.");
    }
    var q = queryExecute("SELECT COUNT(*) AS n FROM " & arguments.tableName & " WHERE " & arguments.idColumn & " = :id",
      { id={ value=arguments.id, cfsqltype="cf_sql_integer" } }, { datasource=variables.datasource });
    return val(q.n[1]);
  }

  private struct function deleteParentRoute(required struct fixture) {
    var service = createObject("component", "fpw.api.v1.routeBuilder");
    makePublic(service, "deleteRoute", "deleteRouteForShareTest");
    return service.deleteRouteForShareTest(arguments.fixture.userId, arguments.fixture.routeCode);
  }

  private void function verifyEvidenceFailure(required string mode) {
    var fixture = createFixture("event-" & arguments.mode, [{ name="Event Contact", email="event@example.test" }]);
    var emailStub = createObject("component", "fpw.tests.support.BasicReviewSendEmailStub").init(true);
    var service = createObject("component", "fpw.api.v1.BasicReviewSendService").init(variables.datasource,
      emailStub, createObject("component", "fpw.tests.support.BasicReviewSendPdfStub").init(variables.testPdfPath, true),
      createObject("component", "fpw.tests.support.BasicReviewProductEventFailureStub").init(arguments.mode));
    var key = "basic_review_event_failure_" & arguments.mode;
    var result = service.send(fixture.userId, fixture.floatPlanId, fixture.contactIds[1], key);
    var replay = service.send(fixture.userId, fixture.floatPlanId, fixture.contactIds[1], key);
    var q = queryExecute("SELECT status, completed_at_utc FROM basic_review_send_receipts WHERE user_id = :id",
      { id={ value=fixture.userId, cfsqltype="cf_sql_integer" } }, { datasource=variables.datasource });
    expect(result.SUCCESS).toBeFalse();
    expect(result.ERROR).toBe("BASIC_REVIEW_CONFIRMATION_PENDING");
    expect(replay.ERROR).toBe("REQUEST_IN_PROGRESS");
    expect(arrayLen(emailStub.getCalls())).toBe(1);
    expect(q.status[1]).toBe("PROCESSING");
    expect(isNull(q.completed_at_utc[1]) OR !len(q.completed_at_utc[1])).toBeTrue();
    expect(loadShareEvents(fixture.userId).recordCount).toBe(0);
  }
}
