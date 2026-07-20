component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.datasource = "fpw";
    variables.stripeService = new fpw.api.v1.StripeEntitlementService().init(variables.datasource);
    variables.tripService = new fpw.api.v1.PremiumTripEntitlementService().init(variables.datasource);
    variables.createdUserIds = [];
    variables.createdEventIds = [];
    variables.schemaReady = premiumTripStripeSchemaExists();
  }

  function afterEach() {
    cleanupFixtures();
  }

  function afterAll() {
    cleanupFixtures();
  }

  function run() {
    describe("Premium Trip Stripe webhook processing", function() {
      it("grants only on paid success and deduplicates event and payment identities", function() {
        requireSchema();
        var paidUserId = createTestUser();
        var checkoutId = stripeId("cs_paid");
        var paymentIntentId = stripeId("pi_paid");
        var paidEvent = checkoutEvent(
          stripeId("evt_paid"),
          "checkout.session.completed",
          paidUserId,
          checkoutId,
          paymentIntentId,
          "paid"
        );
        var paid = processEvent(paidEvent);
        var eventReplay = processEvent(paidEvent);
        var logicalReplay = processEvent(checkoutEvent(
          stripeId("evt_paid_replay"),
          "checkout.session.completed",
          paidUserId,
          checkoutId,
          paymentIntentId,
          "paid"
        ));

        expect(paid.SUCCESS).toBeTrue(serializeJSON(paid));
        expect(eventReplay.SUCCESS).toBeTrue(serializeJSON(eventReplay));
        expect(eventReplay.duplicate).toBeTrue(serializeJSON(eventReplay));
        expect(logicalReplay.SUCCESS).toBeTrue(serializeJSON(logicalReplay));
        expect(countTripEntitlements(paidUserId)).toBe(1);
        expect(loadTripStatus(paidUserId)).toBe("AVAILABLE");

        var pendingUserId = createTestUser();
        var pendingCheckoutId = stripeId("cs_pending");
        var pendingPaymentIntentId = stripeId("pi_pending");
        var pending = processEvent(checkoutEvent(
          stripeId("evt_pending"),
          "checkout.session.completed",
          pendingUserId,
          pendingCheckoutId,
          pendingPaymentIntentId,
          "unpaid"
        ));
        expect(pending.SUCCESS).toBeTrue(serializeJSON(pending));
        expect(pending.ignored).toBeTrue(serializeJSON(pending));
        expect(countTripEntitlements(pendingUserId)).toBe(0);

        var delayedSuccess = processEvent(checkoutEvent(
          stripeId("evt_async_success"),
          "checkout.session.async_payment_succeeded",
          pendingUserId,
          pendingCheckoutId,
          pendingPaymentIntentId,
          "paid"
        ));
        expect(delayedSuccess.SUCCESS).toBeTrue(serializeJSON(delayedSuccess));
        expect(countTripEntitlements(pendingUserId)).toBe(1);

        var failedUserId = createTestUser();
        var delayedFailure = processEvent(checkoutEvent(
          stripeId("evt_async_failed"),
          "checkout.session.async_payment_failed",
          failedUserId,
          stripeId("cs_failed"),
          stripeId("pi_failed"),
          "unpaid"
        ));
        expect(delayedFailure.SUCCESS).toBeTrue(serializeJSON(delayedFailure));
        expect(delayedFailure.ignored).toBeTrue(serializeJSON(delayedFailure));
        expect(countTripEntitlements(failedUserId)).toBe(0);
      });

      it("retries failed and stale webhook claims but rejects an active concurrent claim", function() {
        requireSchema();
        var failedUserId = createTestUser();
        var failedEvent = checkoutEvent(
          stripeId("evt_retry_failed"),
          "checkout.session.completed",
          failedUserId,
          stripeId("cs_retry_failed"),
          stripeId("pi_retry_failed"),
          "paid"
        );
        seedWebhookLedger(failedEvent.id, failedEvent.type, "failed", -1);
        var failedRetry = processEvent(failedEvent);
        var failedRow = loadWebhookEvent(failedEvent.id);

        expect(failedRetry.SUCCESS).toBeTrue(serializeJSON(failedRetry));
        expect(failedRow.processing_status[1]).toBe("processed");
        expect(val(failedRow.attempt_count[1])).toBe(2);
        expect(countTripEntitlements(failedUserId)).toBe(1);

        var staleUserId = createTestUser();
        var staleEvent = checkoutEvent(
          stripeId("evt_retry_stale"),
          "checkout.session.completed",
          staleUserId,
          stripeId("cs_retry_stale"),
          stripeId("pi_retry_stale"),
          "paid"
        );
        seedWebhookLedger(staleEvent.id, staleEvent.type, "processing", -11);
        var staleRetry = processEvent(staleEvent);
        var staleRow = loadWebhookEvent(staleEvent.id);

        expect(staleRetry.SUCCESS).toBeTrue(serializeJSON(staleRetry));
        expect(staleRow.processing_status[1]).toBe("processed");
        expect(val(staleRow.attempt_count[1])).toBe(2);
        expect(countTripEntitlements(staleUserId)).toBe(1);

        var concurrentUserId = createTestUser();
        var concurrentEvent = checkoutEvent(
          stripeId("evt_concurrent"),
          "checkout.session.completed",
          concurrentUserId,
          stripeId("cs_concurrent"),
          stripeId("pi_concurrent"),
          "paid"
        );
        seedWebhookLedger(concurrentEvent.id, concurrentEvent.type, "processing", 0);
        var concurrent = processEvent(concurrentEvent);

        expect(concurrent.SUCCESS).toBeFalse(serializeJSON(concurrent));
        expect(concurrent.ERROR).toBe("STRIPE_EVENT_ALREADY_PROCESSING");
        expect(countTripEntitlements(concurrentUserId)).toBe(0);
      });

      it("revokes an unused trip after a full refund and leaves partial refunds unchanged", function() {
        requireSchema();
        var fullUserId = createTestUser();
        var fullPaymentIntentId = stripeId("pi_full_refund");
        processEvent(checkoutEvent(
          stripeId("evt_full_purchase"),
          "checkout.session.completed",
          fullUserId,
          stripeId("cs_full_refund"),
          fullPaymentIntentId,
          "paid"
        ));
        var fullRefund = processEvent(refundEvent(
          stripeId("evt_full_refund"),
          stripeId("ch_full_refund"),
          fullPaymentIntentId,
          true,
          2500,
          2500
        ));

        expect(fullRefund.SUCCESS).toBeTrue(serializeJSON(fullRefund));
        expect(loadTripStatus(fullUserId)).toBe("REVOKED");

        var partialUserId = createTestUser();
        var partialPaymentIntentId = stripeId("pi_partial_refund");
        processEvent(checkoutEvent(
          stripeId("evt_partial_purchase"),
          "checkout.session.completed",
          partialUserId,
          stripeId("cs_partial_refund"),
          partialPaymentIntentId,
          "paid"
        ));
        var partialRefund = processEvent(refundEvent(
          stripeId("evt_partial_refund"),
          stripeId("ch_partial_refund"),
          partialPaymentIntentId,
          false,
          2500,
          1000
        ));

        expect(partialRefund.SUCCESS).toBeTrue(serializeJSON(partialRefund));
        expect(partialRefund.ignored).toBeTrue(serializeJSON(partialRefund));
        expect(partialRefund.ERROR).toBe("STRIPE_PARTIAL_REFUND_REVIEW");
        expect(loadTripStatus(partialUserId)).toBe("AVAILABLE");
      });

      it("flags an ACTIVE refunded trip for review without revoking or consuming it", function() {
        requireSchema();
        var userId = createTestUser();
        var paymentIntentId = stripeId("pi_active_refund");
        processEvent(checkoutEvent(
          stripeId("evt_active_purchase"),
          "checkout.session.completed",
          userId,
          stripeId("cs_active_refund"),
          paymentIntentId,
          "paid"
        ));
        var routeId = createRoute(userId);
        var floatPlanId = createDraftFloatPlan(userId, routeId);
        var creation = variables.tripService.createCreationSession(userId);
        expect(creation.SUCCESS).toBeTrue(serializeJSON(creation));
        var routeClaim = variables.tripService.authorizeCreationAction(
          userId,
          creation.creationSessionToken,
          "routegen_generate"
        );
        expect(variables.tripService.attachPreparedRoute(userId, creation.creationSessionToken, routeId).SUCCESS).toBeTrue();
        expect(
          variables.tripService.finishCreationAction(
            userId,
            creation.creationSessionToken,
            routeClaim.creationActionClaimToken
          ).SUCCESS
        ).toBeTrue();
        var buildClaim = variables.tripService.authorizeCreationAction(
          userId,
          creation.creationSessionToken,
          "buildfloatplansfromroute",
          routeId
        );
        expect(variables.tripService.attachPreparedFloatPlan(userId, creation.creationSessionToken, floatPlanId, routeId).SUCCESS).toBeTrue();
        expect(
          variables.tripService.finishCreationAction(
            userId,
            creation.creationSessionToken,
            buildClaim.creationActionClaimToken
          ).SUCCESS
        ).toBeTrue();
        expect(variables.tripService.applyCreationSessionToPreparedTrip(userId, creation.creationSessionToken, floatPlanId).SUCCESS).toBeTrue();

        queryExecute(
          "UPDATE route_instances SET started_at=UTC_TIMESTAMP() WHERE id=:routeId",
          { routeId={value=routeId,cfsqltype="cf_sql_integer"} },
          { datasource=variables.datasource }
        );
        var activated = variables.tripService.activateTripEntitlement(userId, floatPlanId);
        expect(activated.SUCCESS).toBeTrue(serializeJSON(activated));
        expect(loadTripStatus(userId)).toBe("ACTIVE");

        var refundEventId = stripeId("evt_active_refund");
        var reversal = processEvent(refundEvent(
          refundEventId,
          stripeId("ch_active_refund"),
          paymentIntentId,
          true,
          2500,
          2500
        ));
        var webhook = loadWebhookEvent(refundEventId);

        expect(reversal.SUCCESS).toBeTrue(serializeJSON(reversal));
        expect(reversal.reviewRequired).toBeTrue(serializeJSON(reversal));
        expect(loadTripStatus(userId)).toBe("ACTIVE");
        expect(val(webhook.review_required[1])).toBe(1);
        expect(len(trim(toString(webhook.review_reason[1])))).toBeGT(0);
      });
    });
  }

  private struct function processEvent(required struct event) {
    if (arrayFind(variables.createdEventIds, arguments.event.id) EQ 0) {
      arrayAppend(variables.createdEventIds, arguments.event.id);
    }
    return variables.stripeService.processVerifiedEvent(arguments.event);
  }

  private struct function checkoutEvent(
    required string eventId,
    required string eventType,
    required numeric userId,
    required string checkoutId,
    required string paymentIntentId,
    required string paymentStatus
  ) {
    return {
      id=arguments.eventId,
      type=arguments.eventType,
      data={
        object={
          id=arguments.checkoutId,
          mode="payment",
          payment_status=arguments.paymentStatus,
          client_reference_id=toString(arguments.userId),
          payment_intent=arguments.paymentIntentId,
          metadata={
            fpwProduct="premium_trip",
            fpwEntitlementSource="premium_trip",
            fpwUserId=toString(arguments.userId)
          }
        }
      }
    };
  }

  private struct function refundEvent(
    required string eventId,
    required string chargeId,
    required string paymentIntentId,
    required boolean fullyRefunded,
    required numeric amount,
    required numeric amountRefunded
  ) {
    return {
      id=arguments.eventId,
      type="charge.refunded",
      data={
        object={
          id=arguments.chargeId,
          payment_intent=arguments.paymentIntentId,
          refunded=arguments.fullyRefunded,
          amount=arguments.amount,
          amount_refunded=arguments.amountRefunded
        }
      }
    };
  }

  private void function seedWebhookLedger(
    required string eventId,
    required string eventType,
    required string status,
    required numeric startedMinutesOffset
  ) {
    arrayAppend(variables.createdEventIds, arguments.eventId);
    queryExecute(
      "INSERT INTO stripe_webhook_events
       (stripe_event_id,event_type,processing_status,attempt_count,processing_started_at_utc,last_attempt_at_utc,created_at_utc,updated_at_utc)
       VALUES (:eventId,:eventType,:status,1,DATE_ADD(UTC_TIMESTAMP(),INTERVAL :offset MINUTE),UTC_TIMESTAMP(),UTC_TIMESTAMP(),UTC_TIMESTAMP())",
      {
        eventId={value=arguments.eventId,cfsqltype="cf_sql_varchar"},
        eventType={value=arguments.eventType,cfsqltype="cf_sql_varchar"},
        status={value=arguments.status,cfsqltype="cf_sql_varchar"},
        offset={value=int(arguments.startedMinutesOffset),cfsqltype="cf_sql_integer"}
      },
      { datasource=variables.datasource }
    );
  }

  private query function loadWebhookEvent(required string eventId) {
    return queryExecute(
      "SELECT * FROM stripe_webhook_events WHERE stripe_event_id=:eventId LIMIT 1",
      { eventId={value=arguments.eventId,cfsqltype="cf_sql_varchar"} },
      { datasource=variables.datasource }
    );
  }

  private numeric function createTestUser() {
    var result = {};
    queryExecute(
      "INSERT INTO users (email,password,passwordCreated,lastUpdate,created)
       VALUES (:email,:password,UTC_TIMESTAMP(),UTC_TIMESTAMP(),UTC_TIMESTAMP())",
      {
        email={value="premium-trip-stripe+" & replace(createUUID(), "-", "", "all") & "@example.invalid",cfsqltype="cf_sql_varchar"},
        password={value=hash(createUUID(), "SHA-256"),cfsqltype="cf_sql_varchar"}
      },
      { datasource=variables.datasource,result="result" }
    );
    var userId = val(result.generatedKey);
    arrayAppend(variables.createdUserIds, userId);
    return userId;
  }

  private numeric function createRoute(required numeric userId) {
    var result = {};
    queryExecute(
      "INSERT INTO route_instances
       (user_id,template_route_code,generated_route_id,generated_route_code,direction,trip_type,start_location,status)
       VALUES (:userId,'TEST',:generatedId,:generatedCode,'CCW','POINT_TO_POINT','Test Start','PLANNED')",
      {
        userId={value=toString(arguments.userId),cfsqltype="cf_sql_varchar"},
        generatedId={value=100000000 + randRange(1000,899999999),cfsqltype="cf_sql_integer"},
        generatedCode={value="PTRIP-" & replace(createUUID(), "-", "", "all"),cfsqltype="cf_sql_varchar"}
      },
      { datasource=variables.datasource,result="result" }
    );
    return val(result.generatedKey);
  }

  private numeric function createDraftFloatPlan(required numeric userId, required numeric routeId) {
    var result = {};
    queryExecute(
      "INSERT INTO floatplans
       (userId,floatPlanName,dateCreated,lastUpdate,status,route_instance_id,route_origin,is_reusable,is_visible_in_route_library)
       VALUES (:userId,:name,UTC_TIMESTAMP(),UTC_TIMESTAMP(),'DRAFT',:routeId,'premium_saved_route',1,1)",
      {
        userId={value=toString(arguments.userId),cfsqltype="cf_sql_varchar"},
        name={value="Premium Trip Stripe Spec " & createUUID(),cfsqltype="cf_sql_varchar"},
        routeId={value=arguments.routeId,cfsqltype="cf_sql_integer"}
      },
      { datasource=variables.datasource,result="result" }
    );
    return val(result.generatedKey);
  }

  private numeric function countTripEntitlements(required numeric userId) {
    var q = queryExecute(
      "SELECT COUNT(*) AS row_count FROM member_premium_trip_entitlements WHERE user_id=:userId",
      { userId={value=arguments.userId,cfsqltype="cf_sql_integer"} },
      { datasource=variables.datasource }
    );
    return val(q.row_count[1]);
  }

  private string function loadTripStatus(required numeric userId) {
    var q = queryExecute(
      "SELECT status FROM member_premium_trip_entitlements
       WHERE user_id=:userId ORDER BY premium_trip_entitlement_id LIMIT 1",
      { userId={value=arguments.userId,cfsqltype="cf_sql_integer"} },
      { datasource=variables.datasource }
    );
    return q.recordCount ? trim(toString(q.status[1])) : "";
  }

  private string function stripeId(required string prefix) {
    return arguments.prefix & "_" & lCase(replace(createUUID(), "-", "", "all"));
  }

  private boolean function premiumTripStripeSchemaExists() {
    var tableCheck = queryExecute(
      "SELECT COUNT(*) AS table_count
       FROM information_schema.tables
       WHERE table_schema=DATABASE()
       AND table_name IN (
         'member_premium_trip_entitlements',
         'premium_trip_creation_sessions',
         'premium_trip_entitlement_events'
       )",
      {},
      { datasource=variables.datasource }
    );
    var columnCheck = queryExecute(
      "SELECT COUNT(*) AS column_count
       FROM information_schema.columns
       WHERE table_schema=DATABASE()
       AND table_name='stripe_webhook_events'
       AND column_name IN (
         'attempt_count',
         'processing_started_at_utc',
         'last_attempt_at_utc',
         'review_required',
         'review_reason'
       )",
      {},
      { datasource=variables.datasource }
    );
    return val(tableCheck.table_count[1]) EQ 3 && val(columnCheck.column_count[1]) EQ 5;
  }

  private void function requireSchema() {
    if (!variables.schemaReady) {
      skip("Apply db/migrations/20260720_01_premium_trip_entitlements.sql before running this specification.");
    }
  }

  private void function cleanupFixtures() {
    for (var eventId in variables.createdEventIds) {
      queryExecute(
        "DELETE FROM stripe_webhook_events WHERE stripe_event_id=:eventId",
        { eventId={value=eventId,cfsqltype="cf_sql_varchar"} },
        { datasource=variables.datasource }
      );
    }
    if (arrayLen(variables.createdUserIds)) {
      var params={userIds={value=arrayToList(variables.createdUserIds),cfsqltype="cf_sql_integer",list=true}};
      transaction {
        if (variables.schemaReady) {
          queryExecute("DELETE FROM premium_trip_entitlement_events WHERE user_id IN (:userIds)",params,{datasource=variables.datasource});
          queryExecute("DELETE FROM premium_trip_creation_sessions WHERE user_id IN (:userIds)",params,{datasource=variables.datasource});
          queryExecute("DELETE FROM member_premium_trip_entitlements WHERE user_id IN (:userIds)",params,{datasource=variables.datasource});
        }
        queryExecute("DELETE FROM member_entitlements WHERE user_id IN (:userIds)",params,{datasource=variables.datasource});
        queryExecute("DELETE FROM floatplans WHERE userId IN (:userIds)",params,{datasource=variables.datasource});
        queryExecute("DELETE FROM route_instances WHERE user_id IN (:userIds)",params,{datasource=variables.datasource});
        queryExecute("DELETE FROM users WHERE userId IN (:userIds)",params,{datasource=variables.datasource});
      }
    }
    variables.createdEventIds = [];
    variables.createdUserIds = [];
  }
}
