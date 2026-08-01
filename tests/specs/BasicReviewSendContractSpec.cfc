component extends="testbox.system.BaseSpec" output="false" {

  variables.datasource = "fpw";
  variables.fixtureEmailPrefix = "codex-basic-review-send-";
  variables.testPdfPath = "";

  function beforeAll() {
    cleanupFixtures();
    variables.testPdfPath = getTempDirectory() & "fpw-basic-review-send-test.pdf";
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
        var replayResult = service.send(fixture.userId, fixture.floatPlanId, fixture.contactIds[1], firstKey);
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
        routeInstanceId = { value = 900000 + val(qUser.userId[1]), cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );
    qPlan = queryExecute(
      "SELECT floatPlanId FROM floatplans WHERE userId = :userId ORDER BY floatPlanId DESC LIMIT 1",
      { userId = { value = toString(val(qUser.userId[1])), cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );

    fixture = {
      userId = val(qUser.userId[1]),
      floatPlanId = val(qPlan.floatPlanId[1]),
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
    queryExecute(
      "DELETE FROM users WHERE email LIKE :pattern",
      params,
      { datasource = variables.datasource }
    );
  }
}
