component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.baseUrl = "http://localhost:8500/fpw";
    variables.service = new fpw.api.v1.StripeEntitlementService().init("fpw");
    variables.accessService = new fpw.api.v1.MemberEntitlementService().init("fpw");
    variables.signatureService = new fpw.api.v1.StripeWebhookSignatureService().init();
    variables.createdUserIds = [];
    variables.createdEventIds = [];
    variables.userSeed = 907000000 + randRange(1000, 99999);
    ensureStripeFoundationSchema();
  }

  function afterEach() {
    cleanupRows();
  }

  function run() {
    describe("Stripe Premium foundation", function() {
      it("processes the first event and ignores a duplicate without double-applying entitlement", function() {
        var userId = createTestUser();
        var eventId = uniqueEventId("evt_duplicate_once");
        var subscriptionId = "sub_duplicate_once_" & userId;
        var event = subscriptionEvent(eventId, "customer.subscription.updated", userId, subscriptionId, "active");
        var first = variables.service.processVerifiedEvent(event);
        var duplicate = variables.service.processVerifiedEvent(event);

        expect(first.SUCCESS).toBeTrue(serializeJSON(first));
        expect(first.ignored).toBeFalse(serializeJSON(first));
        expect(duplicate.SUCCESS).toBeTrue(serializeJSON(duplicate));
        expect(duplicate.duplicate).toBeTrue(serializeJSON(duplicate));
        expect(countEntitlementsBySubscription(subscriptionId)).toBe(1);
        expect(countWebhookEvents(eventId)).toBe(1);
      });

      it("records checkout session mapping without granting Premium", function() {
        var userId = createTestUser();
        var subscriptionId = "sub_mapping_checkout_" & userId;
        var event = checkoutEvent(uniqueEventId("evt_checkout_mapping"), userId, "cs_mapping_" & userId, subscriptionId);
        var result = variables.service.processVerifiedEvent(event);
        var access = variables.accessService.getCurrentAccess(userId);
        var row = loadEntitlementBySubscription(subscriptionId);

        expect(result.SUCCESS).toBeTrue(serializeJSON(result));
        expect(access.hasPremium).toBeFalse(serializeJSON(access));
        expect(row.recordCount).toBe(1);
        expect(row.status[1]).toBe("inactive");
      });

      it("does not grant Premium when checkout user mapping is missing or invalid", function() {
        var subscriptionId = "sub_invalid_user_" & replace(createUUID(), "-", "", "all");
        var event = checkoutEvent(uniqueEventId("evt_checkout_invalid_user"), 999999999, "cs_invalid_user_" & replace(createUUID(), "-", "", "all"), subscriptionId);
        var result = variables.service.processVerifiedEvent(event);

        expect(result.SUCCESS).toBeTrue(serializeJSON(result));
        expect(result.ignored).toBeTrue(serializeJSON(result));
        expect(countEntitlementsBySubscription(subscriptionId)).toBe(0);
      });

      it("grants Premium for active and trialing subscriptions", function() {
        var activeUserId = createTestUser();
        var trialUserId = createTestUser();
        var activeResult = variables.service.processVerifiedEvent(subscriptionEvent(uniqueEventId("evt_active_sub"), "customer.subscription.updated", activeUserId, "sub_active_" & activeUserId, "active"));
        var trialResult = variables.service.processVerifiedEvent(subscriptionEvent(uniqueEventId("evt_trial_sub"), "customer.subscription.created", trialUserId, "sub_trial_" & trialUserId, "trialing"));

        expect(activeResult.SUCCESS).toBeTrue(serializeJSON(activeResult));
        expect(trialResult.SUCCESS).toBeTrue(serializeJSON(trialResult));
        expect(variables.accessService.getCurrentAccess(activeUserId).hasPremium).toBeTrue();
        expect(variables.accessService.getCurrentAccess(trialUserId).hasPremium).toBeTrue();
        expect(getMeAsUser(activeUserId).ACCESS.hasPremium).toBeTrue();
      });

      it("keeps past_due Premium active while recording stripe_subscription_status", function() {
        var userId = createTestUser();
        var subscriptionId = "sub_past_due_" & userId;
        var result = variables.service.processVerifiedEvent(subscriptionEvent(uniqueEventId("evt_past_due_sub"), "customer.subscription.updated", userId, subscriptionId, "past_due"));
        var row = loadEntitlementBySubscription(subscriptionId);

        expect(result.SUCCESS).toBeTrue(serializeJSON(result));
        expect(variables.accessService.getCurrentAccess(userId).hasPremium).toBeTrue();
        expect(row.status[1]).toBe("active");
        expect(row.stripe_subscription_status[1]).toBe("past_due");
      });

      it("keeps period-end canceled active subscriptions Premium until Stripe sends canceled or deleted status", function() {
        var userId = createTestUser();
        var subscriptionId = "sub_period_end_cancel_" & userId;
        var event = subscriptionEvent(uniqueEventId("evt_period_end_cancel"), "customer.subscription.updated", userId, subscriptionId, "active");
        event.data.object.cancel_at_period_end = true;
        event.data.object.cancel_at = 1781452571;

        var result = variables.service.processVerifiedEvent(event);
        var row = loadEntitlementBySubscription(subscriptionId);

        expect(result.SUCCESS).toBeTrue(serializeJSON(result));
        expect(variables.accessService.getCurrentAccess(userId).hasPremium).toBeTrue();
        expect(row.status[1]).toBe("active");
        expect(row.stripe_subscription_status[1]).toBe("active");
      });

      it("removes Premium for unpaid, canceled, and deleted subscriptions", function() {
        var statuses = [ "unpaid", "canceled" ];
        var i = 0;

        for (i = 1; i <= arrayLen(statuses); i++) {
          var userId = createTestUser();
          var subId = "sub_remove_" & statuses[i] & "_" & userId;
          variables.service.processVerifiedEvent(subscriptionEvent(uniqueEventId("evt_remove_seed_" & statuses[i]), "customer.subscription.updated", userId, subId, "active"));
          variables.service.processVerifiedEvent(subscriptionEvent(uniqueEventId("evt_remove_" & statuses[i]), "customer.subscription.updated", userId, subId, statuses[i]));

          expect(variables.accessService.getCurrentAccess(userId).hasPremium).toBeFalse(statuses[i]);
          expect(loadEntitlementBySubscription(subId).status[1]).toBe("canceled");
        }

        var deletedUserId = createTestUser();
        var deletedSubId = "sub_deleted_" & deletedUserId;
        variables.service.processVerifiedEvent(subscriptionEvent(uniqueEventId("evt_deleted_seed"), "customer.subscription.updated", deletedUserId, deletedSubId, "active"));
        variables.service.processVerifiedEvent(subscriptionEvent(uniqueEventId("evt_deleted"), "customer.subscription.deleted", deletedUserId, deletedSubId, "canceled"));

        expect(variables.accessService.getCurrentAccess(deletedUserId).hasPremium).toBeFalse();
        expect(loadEntitlementBySubscription(deletedSubId).status[1]).toBe("canceled");
      });

      it("does not grant Premium for incomplete, incomplete_expired, or paused subscriptions", function() {
        var statuses = [ "incomplete", "incomplete_expired", "paused" ];
        var i = 0;

        for (i = 1; i <= arrayLen(statuses); i++) {
          var userId = createTestUser();
          var subId = "sub_no_grant_" & replace(statuses[i], "_", "", "all") & "_" & userId;
          var result = variables.service.processVerifiedEvent(subscriptionEvent(uniqueEventId("evt_no_grant_" & i), "customer.subscription.updated", userId, subId, statuses[i]));

          expect(result.SUCCESS).toBeTrue(statuses[i] & ": " & serializeJSON(result));
          expect(variables.accessService.getCurrentAccess(userId).hasPremium).toBeFalse(statuses[i]);
          expect(loadEntitlementBySubscription(subId).status[1]).toBe("inactive");
        }
      });

      it("handles subscription paused and resumed lifecycle events through the subscription upsert path", function() {
        var userId = createTestUser();
        var subscriptionId = "sub_pause_resume_" & userId;
        var activeResult = variables.service.processVerifiedEvent(subscriptionEvent(uniqueEventId("evt_pause_seed"), "customer.subscription.created", userId, subscriptionId, "trialing"));
        var pausedResult = variables.service.processVerifiedEvent(subscriptionEvent(uniqueEventId("evt_subscription_paused"), "customer.subscription.paused", userId, subscriptionId, "paused"));
        var resumedResult = {};

        expect(activeResult.SUCCESS).toBeTrue(serializeJSON(activeResult));
        expect(pausedResult.SUCCESS).toBeTrue(serializeJSON(pausedResult));
        expect(loadEntitlementBySubscription(subscriptionId).status[1]).toBe("inactive");
        expect(variables.accessService.getCurrentAccess(userId).hasPremium).toBeFalse();
        resumedResult = variables.service.processVerifiedEvent(subscriptionEvent(uniqueEventId("evt_subscription_resumed"), "customer.subscription.resumed", userId, subscriptionId, "active"));
        expect(resumedResult.SUCCESS).toBeTrue(serializeJSON(resumedResult));
        expect(loadEntitlementBySubscription(subscriptionId).status[1]).toBe("active");
        expect(variables.accessService.getCurrentAccess(userId).hasPremium).toBeTrue();
      });

      it("updates only known mapped subscriptions for invoice payment events", function() {
        var userId = createTestUser();
        var subscriptionId = "sub_invoice_known_" & userId;
        variables.service.processVerifiedEvent(checkoutEvent(uniqueEventId("evt_invoice_checkout"), userId, "cs_invoice_" & userId, subscriptionId));

        var successResult = variables.service.processVerifiedEvent(invoiceEvent(uniqueEventId("evt_invoice_success"), "invoice.payment_succeeded", "in_success_" & userId, subscriptionId));
        var failedResult = variables.service.processVerifiedEvent(invoiceEvent(uniqueEventId("evt_invoice_failed"), "invoice.payment_failed", "in_failed_" & userId, subscriptionId));
        var unknownSubscriptionId = "sub_invoice_unknown_" & replace(createUUID(), "-", "", "all");
        var unknownResult = variables.service.processVerifiedEvent(invoiceEvent(uniqueEventId("evt_invoice_unknown"), "invoice.payment_succeeded", "in_unknown_" & userId, unknownSubscriptionId));
        var row = loadEntitlementBySubscription(subscriptionId);

        expect(successResult.SUCCESS).toBeTrue(serializeJSON(successResult));
        expect(failedResult.SUCCESS).toBeTrue(serializeJSON(failedResult));
        expect(unknownResult.ignored).toBeTrue(serializeJSON(unknownResult));
        expect(row.status[1]).toBe("active");
        expect(row.stripe_subscription_status[1]).toBe("past_due");
        expect(countEntitlementsBySubscription(unknownSubscriptionId)).toBe(0);
      });

      it("accepts webhook signatures when timestamp equals server epoch seconds", function() {
        var rawBody = serializeJSON({ id = "evt_sig_valid", type = "customer.subscription.updated" });
        var secret = "whsec_test_secret";
        var nowSeconds = 1779074701;
        var header = variables.signatureService.createTestSignatureHeader(rawBody, secret, nowSeconds);
        var valid = variables.signatureService.verify(rawBody, header, secret, 300, nowSeconds);

        expect(valid.SUCCESS).toBeTrue(serializeJSON(valid));
      });

      it("accepts webhook signatures at the 300 second tolerance boundary", function() {
        var rawBody = serializeJSON({ id = "evt_sig_tolerance_boundary", type = "customer.subscription.updated" });
        var secret = "whsec_test_secret";
        var nowSeconds = 1779074701;
        var boundarySeconds = nowSeconds - 300;
        var header = variables.signatureService.createTestSignatureHeader(rawBody, secret, boundarySeconds);
        var valid = variables.signatureService.verify(rawBody, header, secret, 300, nowSeconds);

        expect(valid.SUCCESS).toBeTrue(serializeJSON(valid));
      });

      it("rejects webhook signatures older than tolerance", function() {
        var rawBody = serializeJSON({ id = "evt_sig_old", type = "customer.subscription.updated" });
        var secret = "whsec_test_secret";
        var nowSeconds = 1779074701;
        var oldSeconds = nowSeconds - 301;
        var header = variables.signatureService.createTestSignatureHeader(rawBody, secret, oldSeconds);
        var result = variables.signatureService.verify(rawBody, header, secret, 300, nowSeconds);

        expect(result.SUCCESS).toBeFalse(serializeJSON(result));
        expect(result.ERROR).toBe("STRIPE_SIGNATURE_TIMESTAMP_OUTSIDE_TOLERANCE");
      });

      it("rejects webhook signatures in the future beyond tolerance", function() {
        var rawBody = serializeJSON({ id = "evt_sig_future", type = "customer.subscription.updated" });
        var secret = "whsec_test_secret";
        var nowSeconds = 1779074701;
        var futureSeconds = nowSeconds + 301;
        var header = variables.signatureService.createTestSignatureHeader(rawBody, secret, futureSeconds);
        var result = variables.signatureService.verify(rawBody, header, secret, 300, nowSeconds);

        expect(result.SUCCESS).toBeFalse(serializeJSON(result));
        expect(result.ERROR).toBe("STRIPE_SIGNATURE_TIMESTAMP_OUTSIDE_TOLERANCE");
      });

      it("rejects bad HMAC signatures", function() {
        var rawBody = serializeJSON({ id = "evt_sig_bad_hmac", type = "customer.subscription.updated" });
        var secret = "whsec_test_secret";
        var nowSeconds = currentStripeTimestampForTest();
        var header = variables.signatureService.createTestSignatureHeader(rawBody, secret, nowSeconds);
        var result = variables.signatureService.verify(rawBody & " ", header, secret, 300);

        expect(result.SUCCESS).toBeFalse(serializeJSON(result));
        expect(result.ERROR).toBe("STRIPE_SIGNATURE_INVALID");
      });

      it("rejects missing and malformed Stripe-Signature headers", function() {
        var rawBody = serializeJSON({ id = "evt_sig_missing", type = "customer.subscription.updated" });
        var secret = "whsec_test_secret";
        var missing = variables.signatureService.verify(rawBody, "", secret, 300);
        var malformed = variables.signatureService.verify(rawBody, "t=12345", secret, 300);

        expect(missing.SUCCESS).toBeFalse(serializeJSON(missing));
        expect(missing.ERROR).toBe("STRIPE_SIGNATURE_MISSING");
        expect(malformed.SUCCESS).toBeFalse(serializeJSON(malformed));
        expect(malformed.ERROR).toBe("STRIPE_SIGNATURE_MALFORMED");
      });

      it("does not grant Premium from checkout completion or browser success URL state alone", function() {
        var userId = createTestUser();
        var event = checkoutEvent(uniqueEventId("evt_success_url_no_grant"), userId, "cs_success_url_" & userId, "sub_success_url_" & userId);
        variables.service.processVerifiedEvent(event);

        expect(variables.accessService.getCurrentAccess(userId).hasPremium).toBeFalse();
      });
    });
  }

  private numeric function createTestUser() {
    variables.userSeed++;
    var userId = variables.userSeed;
    arrayAppend(variables.createdUserIds, userId);
    queryExecute(
      "INSERT INTO users (userId, fName, lName, email, password, passwordCreated, created)
       VALUES (:userId, 'Stripe', 'Tester', :email, 'test', UTC_TIMESTAMP(), UTC_TIMESTAMP())",
      {
        userId = { value = userId, cfsqltype = "cf_sql_integer" },
        email = { value = "stripe-test-" & userId & "@example.invalid", cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    return userId;
  }

  private string function uniqueEventId(required string prefix) {
    return arguments.prefix & "_" & replace(createUUID(), "-", "", "all");
  }

  private numeric function currentStripeTimestampForTest() {
    var epochLocal = dateConvert("utc2local", createDateTime(1970, 1, 1, 0, 0, 0));
    return dateDiff("s", epochLocal, now());
  }

  private struct function checkoutEvent(required string eventId, required numeric userId, required string checkoutSessionId, required string subscriptionId) {
    arrayAppend(variables.createdEventIds, arguments.eventId);
    return {
      id = arguments.eventId,
      type = "checkout.session.completed",
      data = {
        object = {
          id = arguments.checkoutSessionId,
          client_reference_id = toString(arguments.userId),
          customer = "cus_" & arguments.userId,
          subscription = arguments.subscriptionId,
          payment_intent = "pi_" & arguments.userId,
          metadata = {
            fpwUserId = toString(arguments.userId)
          },
          items = {
            data = [
              {
                price = {
                  id = "price_premium_monthly"
                }
              }
            ]
          }
        }
      }
    };
  }

  private struct function subscriptionEvent(required string eventId, required string eventType, required numeric userId, required string subscriptionId, required string status) {
    arrayAppend(variables.createdEventIds, arguments.eventId);
    return {
      id = arguments.eventId,
      type = arguments.eventType,
      data = {
        object = {
          id = arguments.subscriptionId,
          customer = "cus_" & arguments.userId,
          status = arguments.status,
          metadata = {
            fpwUserId = toString(arguments.userId)
          },
          items = {
            data = [
              {
                price = {
                  id = "price_premium_monthly"
                }
              }
            ]
          }
        }
      }
    };
  }

  private struct function invoiceEvent(required string eventId, required string eventType, required string invoiceId, required string subscriptionId) {
    arrayAppend(variables.createdEventIds, arguments.eventId);
    return {
      id = arguments.eventId,
      type = arguments.eventType,
      data = {
        object = {
          id = arguments.invoiceId,
          customer = "cus_invoice",
          subscription = arguments.subscriptionId,
          payment_intent = "pi_" & arguments.invoiceId,
          lines = {
            data = [
              {
                price = {
                  id = "price_premium_monthly"
                }
              }
            ]
          }
        }
      }
    };
  }

  private struct function getMeAsUser(required numeric userId) {
    var raw = "";
    var hadSessionUser = structKeyExists(session, "user");
    var priorSessionUser = hadSessionUser ? duplicate(session.user) : {};

    try {
      session.user = {
        id = arguments.userId,
        userId = arguments.userId,
        USERID = arguments.userId,
        email = "stripe-test-" & arguments.userId & "@example.invalid",
        EMAIL = "stripe-test-" & arguments.userId & "@example.invalid",
        firstName = "Stripe",
        FIRSTNAME = "Stripe",
        lastName = "Tester",
        LASTNAME = "Tester",
        mobilePhone = "",
        MOBILEPHONE = ""
      };
      savecontent variable="raw" {
        new fpw.api.v1.me().handle();
      }
      return deserializeJSON(trim(raw), false);
    } finally {
      if (hadSessionUser) {
        session.user = priorSessionUser;
      } else {
        structDelete(session, "user", false);
      }
    }
  }

  private query function loadEntitlementBySubscription(required string subscriptionId) {
    return queryExecute(
      "SELECT status, stripe_subscription_status, stripe_price_id
       FROM member_entitlements
       WHERE stripe_subscription_id = :subscriptionId
       ORDER BY id DESC",
      {
        subscriptionId = { value = arguments.subscriptionId, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
  }

  private numeric function countEntitlementsBySubscription(required string subscriptionId) {
    var qCount = queryExecute(
      "SELECT COUNT(*) AS row_count
       FROM member_entitlements
       WHERE stripe_subscription_id = :subscriptionId",
      {
        subscriptionId = { value = arguments.subscriptionId, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    return qCount.recordCount ? val(qCount.row_count[1]) : 0;
  }

  private numeric function countWebhookEvents(required string eventId) {
    var qCount = queryExecute(
      "SELECT COUNT(*) AS row_count
       FROM stripe_webhook_events
       WHERE stripe_event_id = :eventId",
      {
        eventId = { value = arguments.eventId, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    return qCount.recordCount ? val(qCount.row_count[1]) : 0;
  }

  private void function cleanupRows() {
    var i = 0;
    for (i = 1; i <= arrayLen(variables.createdUserIds); i++) {
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
    for (i = 1; i <= arrayLen(variables.createdEventIds); i++) {
      queryExecute(
        "DELETE FROM stripe_webhook_events WHERE stripe_event_id = :eventId",
        {
          eventId = { value = variables.createdEventIds[i], cfsqltype = "cf_sql_varchar" }
        },
        { datasource = "fpw" }
      );
    }
    variables.createdUserIds = [];
    variables.createdEventIds = [];
  }

  private void function ensureStripeFoundationSchema() {
    queryExecute(
      "CREATE TABLE IF NOT EXISTS stripe_webhook_events (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        stripe_event_id VARCHAR(255) NOT NULL,
        event_type VARCHAR(120) NOT NULL,
        processing_status VARCHAR(40) NOT NULL DEFAULT 'processing',
        user_id INT NULL,
        stripe_customer_id VARCHAR(255) NULL,
        stripe_subscription_id VARCHAR(255) NULL,
        stripe_checkout_session_id VARCHAR(255) NULL,
        stripe_invoice_id VARCHAR(255) NULL,
        stripe_payment_intent_id VARCHAR(255) NULL,
        stripe_price_id VARCHAR(255) NULL,
        processed_at_utc DATETIME NULL,
        error_message VARCHAR(500) NULL,
        created_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at_utc DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY uq_stripe_webhook_events_event_id (stripe_event_id),
        KEY idx_stripe_webhook_events_status_created (processing_status, created_at_utc),
        KEY idx_stripe_webhook_events_user_created (user_id, created_at_utc),
        KEY idx_stripe_webhook_events_subscription (stripe_subscription_id),
        KEY idx_stripe_webhook_events_customer (stripe_customer_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
      {},
      { datasource = "fpw" }
    );
    ensureColumn("member_entitlements", "stripe_price_id", "ALTER TABLE member_entitlements ADD COLUMN stripe_price_id VARCHAR(255) NULL AFTER stripe_payment_intent_id");
    ensureColumn("member_entitlements", "stripe_subscription_status", "ALTER TABLE member_entitlements ADD COLUMN stripe_subscription_status VARCHAR(40) NULL AFTER stripe_price_id");
  }

  private void function ensureColumn(required string tableName, required string columnName, required string alterSql) {
    var qColumn = queryExecute(
      "SELECT COUNT(*) AS column_count
       FROM information_schema.columns
       WHERE table_schema = DATABASE()
         AND table_name = :tableName
         AND column_name = :columnName",
      {
        tableName = { value = arguments.tableName, cfsqltype = "cf_sql_varchar" },
        columnName = { value = arguments.columnName, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    if (qColumn.recordCount AND val(qColumn.column_count[1]) EQ 0) {
      queryExecute(arguments.alterSql, {}, { datasource = "fpw" });
    }
  }
}
