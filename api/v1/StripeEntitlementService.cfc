<cfcomponent output="false">

  <cfset variables.datasource = "fpw">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfscript>
      variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="processVerifiedEvent" access="public" returntype="struct" output="false">
    <cfargument name="event" type="struct" required="true">
    <cfscript>
      var eventId = readString(arguments.event, "id");
      var eventType = readString(arguments.event, "type");
      var eventObject = getEventObject(arguments.event);
      var refs = extractReferences(eventType, eventObject);
      var registration = {};
      var result = {};

      if (!len(eventId)) {
        return errorResponse("INVALID_STRIPE_EVENT_ID", "Stripe event id is required.");
      }
      if (!len(eventType)) {
        return errorResponse("INVALID_STRIPE_EVENT_TYPE", "Stripe event type is required.");
      }

      registration = registerEvent(eventId, eventType, refs);
      if (!registration.SUCCESS) {
        return registration;
      }
      if (structKeyExists(registration, "duplicate") AND registration.duplicate) {
        return registration;
      }

      try {
        result = dispatchEvent(eventType, eventObject);
        updateEventResult(
          stripeEventId = eventId,
          processingStatus = result.SUCCESS ? (structKeyExists(result, "ignored") AND result.ignored ? "ignored" : "processed") : "failed",
          errorMessage = result.SUCCESS ? "" : readString(result, "MESSAGE"),
          userId = structKeyExists(result, "userId") ? val(result.userId) : 0,
          refs = mergeReferenceStructs(refs, result)
        );
        result.stripeEventId = eventId;
        result.eventType = eventType;
        return result;
      } catch (any err) {
        updateEventResult(
          stripeEventId = eventId,
          processingStatus = "failed",
          errorMessage = err.message,
          userId = 0,
          refs = refs
        );
        return errorResponse("STRIPE_EVENT_PROCESSING_FAILED", "Stripe event processing failed.");
      }
    </cfscript>
  </cffunction>

  <cffunction name="dispatchEvent" access="private" returntype="struct" output="false">
    <cfargument name="eventType" type="string" required="true">
    <cfargument name="eventObject" type="struct" required="true">
    <cfscript>
      switch (arguments.eventType) {
        case "checkout.session.completed":
          return processCheckoutSessionCompleted(arguments.eventObject);
        case "customer.subscription.created":
        case "customer.subscription.updated":
        case "customer.subscription.paused":
        case "customer.subscription.resumed":
          return processSubscriptionUpsert(arguments.eventObject, arguments.eventType);
        case "customer.subscription.deleted":
          return processSubscriptionDeleted(arguments.eventObject);
        case "invoice.payment_succeeded":
          return processInvoicePaymentSucceeded(arguments.eventObject);
        case "invoice.payment_failed":
          return processInvoicePaymentFailed(arguments.eventObject);
        default:
          return ignoredResponse("STRIPE_EVENT_IGNORED", "Stripe event type is not handled in this phase.");
      }
    </cfscript>
  </cffunction>

  <cffunction name="processCheckoutSessionCompleted" access="private" returntype="struct" output="false">
    <cfargument name="sessionObject" type="struct" required="true">
    <cfscript>
      var userId = resolveUserIdFromCheckoutSession(arguments.sessionObject);
      var identifiers = extractReferences("checkout.session.completed", arguments.sessionObject);
      var passResult = {};
      if (userId LTE 0) {
        return ignoredResponse("STRIPE_USER_MAPPING_NOT_FOUND", "Checkout session did not map to one valid FPW user.", identifiers);
      }

      if (isThreeDayPassCheckout(arguments.sessionObject, identifiers)) {
        if (lCase(readString(arguments.sessionObject, "payment_status")) NEQ "paid") {
          return ignoredResponse("STRIPE_THREE_DAY_PASS_PAYMENT_PENDING", "3-Day Pass checkout has not been paid yet.", identifiers, userId);
        }
        passResult = new fpw.api.v1.MemberEntitlementService().init(variables.datasource)
          .createThreeDayPassEntitlement(userId);
        if (!structKeyExists(passResult, "SUCCESS") OR passResult.SUCCESS NEQ true) {
          return errorResponse("THREE_DAY_PASS_ENTITLEMENT_FAILED", "3-Day Pass entitlement could not be activated.");
        }
        return successResponse("3-Day Pass entitlement activated.", userId, identifiers);
      }

      upsertStripeEntitlement(
        userId = userId,
        entitlementStatus = "inactive",
        subscriptionStatus = "",
        identifiers = identifiers,
        preserveActive = true
      );
      markPromoCheckoutCompleted(userId, identifiers);

      return successResponse("Checkout session mapping recorded without granting Premium.", userId, identifiers);
    </cfscript>
  </cffunction>

  <cffunction name="isThreeDayPassCheckout" access="private" returntype="boolean" output="false">
    <cfargument name="sessionObject" type="struct" required="true">
    <cfargument name="identifiers" type="struct" required="true">
    <cfscript>
      var configuredPriceId = new fpw.api.v1.StripeConfigService().init().getThreeDayPassPriceId();
      var sessionPriceId = readString(arguments.identifiers, "stripePriceId");
      var modeValue = lCase(readString(arguments.sessionObject, "mode"));
      var productValue = lCase(readMetadataString(arguments.sessionObject, "fpwProduct"));
      var sourceValue = lCase(readMetadataString(arguments.sessionObject, "fpwEntitlementSource"));
      if (len(readString(arguments.identifiers, "stripeSubscriptionId"))) {
        return false;
      }
      if (len(modeValue) AND modeValue NEQ "payment") {
        return false;
      }
      if (productValue EQ "three_day_pass" OR sourceValue EQ "three_day_pass") {
        return true;
      }
      return len(configuredPriceId) AND len(sessionPriceId) AND compareNoCase(configuredPriceId, sessionPriceId) EQ 0;
    </cfscript>
  </cffunction>

  <cffunction name="processSubscriptionUpsert" access="private" returntype="struct" output="false">
    <cfargument name="subscriptionObject" type="struct" required="true">
    <cfargument name="eventType" type="string" required="true">
    <cfscript>
      var subscriptionStatus = lCase(readString(arguments.subscriptionObject, "status"));
      var userId = resolveUserIdFromSubscription(arguments.subscriptionObject);
      var entitlementStatus = mapSubscriptionStatusToEntitlementStatus(subscriptionStatus);
      var identifiers = extractReferences(arguments.eventType, arguments.subscriptionObject);

      if (arguments.eventType EQ "customer.subscription.paused") {
        subscriptionStatus = "paused";
        entitlementStatus = mapSubscriptionStatusToEntitlementStatus(subscriptionStatus);
      } else if (arguments.eventType EQ "customer.subscription.resumed" AND !len(subscriptionStatus)) {
        subscriptionStatus = "active";
        entitlementStatus = mapSubscriptionStatusToEntitlementStatus(subscriptionStatus);
      }

      if (userId LTE 0) {
        return ignoredResponse("STRIPE_USER_MAPPING_NOT_FOUND", "Subscription event did not map to one valid FPW user.", identifiers);
      }
      if (!len(entitlementStatus)) {
        return ignoredResponse("STRIPE_SUBSCRIPTION_STATUS_IGNORED", "Subscription status is not handled in this phase.", identifiers, userId);
      }

      upsertStripeEntitlement(
        userId = userId,
        entitlementStatus = entitlementStatus,
        subscriptionStatus = subscriptionStatus,
        identifiers = identifiers,
        preserveActive = false
      );

      return successResponse("Subscription entitlement updated.", userId, identifiers);
    </cfscript>
  </cffunction>

  <cffunction name="processSubscriptionDeleted" access="private" returntype="struct" output="false">
    <cfargument name="subscriptionObject" type="struct" required="true">
    <cfscript>
      var userId = resolveUserIdFromSubscription(arguments.subscriptionObject);
      var identifiers = extractReferences("customer.subscription.deleted", arguments.subscriptionObject);
      if (userId LTE 0) {
        return ignoredResponse("STRIPE_USER_MAPPING_NOT_FOUND", "Deleted subscription did not map to one valid FPW user.", identifiers);
      }

      upsertStripeEntitlement(
        userId = userId,
        entitlementStatus = "canceled",
        subscriptionStatus = "canceled",
        identifiers = identifiers,
        preserveActive = false
      );

      return successResponse("Subscription entitlement canceled.", userId, identifiers);
    </cfscript>
  </cffunction>

  <cffunction name="processInvoicePaymentSucceeded" access="private" returntype="struct" output="false">
    <cfargument name="invoiceObject" type="struct" required="true">
    <cfscript>
      var identifiers = extractReferences("invoice.payment_succeeded", arguments.invoiceObject);
      var userId = resolveUserIdFromSubscriptionId(identifiers.stripeSubscriptionId);
      if (userId LTE 0) {
        return ignoredResponse("STRIPE_USER_MAPPING_NOT_FOUND", "Invoice payment succeeded without an existing FPW subscription mapping.", identifiers);
      }

      upsertStripeEntitlement(
        userId = userId,
        entitlementStatus = "active",
        subscriptionStatus = "active",
        identifiers = identifiers,
        preserveActive = false
      );

      return successResponse("Invoice payment success recorded.", userId, identifiers);
    </cfscript>
  </cffunction>

  <cffunction name="processInvoicePaymentFailed" access="private" returntype="struct" output="false">
    <cfargument name="invoiceObject" type="struct" required="true">
    <cfscript>
      var identifiers = extractReferences("invoice.payment_failed", arguments.invoiceObject);
      var userId = resolveUserIdFromSubscriptionId(identifiers.stripeSubscriptionId);
      if (userId LTE 0) {
        return ignoredResponse("STRIPE_USER_MAPPING_NOT_FOUND", "Invoice payment failed without an existing FPW subscription mapping.", identifiers);
      }

      upsertStripeEntitlement(
        userId = userId,
        entitlementStatus = "active",
        subscriptionStatus = "past_due",
        identifiers = identifiers,
        preserveActive = false
      );

      return successResponse("Invoice payment failure recorded as past_due.", userId, identifiers);
    </cfscript>
  </cffunction>

  <cffunction name="upsertStripeEntitlement" access="private" returntype="void" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="entitlementStatus" type="string" required="true">
    <cfargument name="subscriptionStatus" type="string" required="false" default="">
    <cfargument name="identifiers" type="struct" required="true">
    <cfargument name="preserveActive" type="boolean" required="false" default="false">
    <cfscript>
      var qExisting = findExistingEntitlement(arguments.identifiers, arguments.userId);
      var rowId = qExisting.recordCount ? val(qExisting.id[1]) : 0;
      var effectiveStatus = arguments.entitlementStatus;
      var effectiveSubscriptionStatus = arguments.subscriptionStatus;
      var expiresSql = (effectiveStatus EQ "active") ? "NULL" : "UTC_TIMESTAMP()";

      if (arguments.preserveActive AND qExisting.recordCount AND trim(qExisting.status[1]) EQ "active") {
        effectiveStatus = "active";
        effectiveSubscriptionStatus = len(trim(arguments.subscriptionStatus)) ? arguments.subscriptionStatus : trim(toString(qExisting.stripe_subscription_status[1]));
        expiresSql = "NULL";
      }

      if (rowId GT 0) {
        queryExecute(
          "UPDATE member_entitlements
           SET user_id = :userId,
               entitlement_type = 'premium',
               source = 'stripe_subscription',
               status = :status,
               starts_at_utc = IF(starts_at_utc IS NULL, UTC_TIMESTAMP(), starts_at_utc),
               expires_at_utc = " & expiresSql & ",
               stripe_customer_id = COALESCE(:stripeCustomerId, stripe_customer_id),
               stripe_subscription_id = COALESCE(:stripeSubscriptionId, stripe_subscription_id),
               stripe_checkout_session_id = COALESCE(:stripeCheckoutSessionId, stripe_checkout_session_id),
               stripe_payment_intent_id = COALESCE(:stripePaymentIntentId, stripe_payment_intent_id),
               stripe_price_id = COALESCE(:stripePriceId, stripe_price_id),
               stripe_subscription_status = :subscriptionStatus,
               updated_utc = UTC_TIMESTAMP()
           WHERE id = :id",
          buildEntitlementParams(arguments.userId, effectiveStatus, effectiveSubscriptionStatus, arguments.identifiers, rowId),
          { datasource = variables.datasource }
        );
      } else {
        queryExecute(
          "INSERT INTO member_entitlements (
             user_id,
             entitlement_type,
             source,
             status,
             starts_at_utc,
             expires_at_utc,
             stripe_customer_id,
             stripe_subscription_id,
             stripe_checkout_session_id,
             stripe_payment_intent_id,
             stripe_price_id,
             stripe_subscription_status,
             created_utc,
             updated_utc
           ) VALUES (
             :userId,
             'premium',
             'stripe_subscription',
             :status,
             UTC_TIMESTAMP(),
             " & expiresSql & ",
             :stripeCustomerId,
             :stripeSubscriptionId,
             :stripeCheckoutSessionId,
             :stripePaymentIntentId,
             :stripePriceId,
             :subscriptionStatus,
             UTC_TIMESTAMP(),
             UTC_TIMESTAMP()
           )",
          buildEntitlementParams(arguments.userId, effectiveStatus, effectiveSubscriptionStatus, arguments.identifiers, 0),
          { datasource = variables.datasource }
        );
      }
    </cfscript>
  </cffunction>

  <cffunction name="findExistingEntitlement" access="private" returntype="query" output="false">
    <cfargument name="identifiers" type="struct" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var subscriptionId = readString(arguments.identifiers, "stripeSubscriptionId");
      var checkoutId = readString(arguments.identifiers, "stripeCheckoutSessionId");
      if (len(subscriptionId)) {
        return queryExecute(
          "SELECT id, status, stripe_subscription_status
           FROM member_entitlements
           WHERE source = 'stripe_subscription'
             AND stripe_subscription_id = :subscriptionId
           ORDER BY id DESC
           LIMIT 1",
          {
            subscriptionId = { value = subscriptionId, cfsqltype = "cf_sql_varchar" }
          },
          { datasource = variables.datasource }
        );
      }
      if (len(checkoutId)) {
        return queryExecute(
          "SELECT id, status, stripe_subscription_status
           FROM member_entitlements
           WHERE source = 'stripe_subscription'
             AND user_id = :userId
             AND stripe_checkout_session_id = :checkoutId
           ORDER BY id DESC
           LIMIT 1",
          {
            userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
            checkoutId = { value = checkoutId, cfsqltype = "cf_sql_varchar" }
          },
          { datasource = variables.datasource }
        );
      }
      return queryNew("id,status,stripe_subscription_status");
    </cfscript>
  </cffunction>

  <cffunction name="markPromoCheckoutCompleted" access="private" returntype="void" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="identifiers" type="struct" required="true">
    <cfscript>
      var checkoutId = readString(arguments.identifiers, "stripeCheckoutSessionId");
      var qPending = queryNew("");
      var redemptionId = 0;
      var promoCodeId = 0;

      if (!len(checkoutId)) {
        return;
      }

      qPending = queryExecute(
        "SELECT redemption_id, promo_code_id
         FROM fpw_promo_redemptions
         WHERE user_id = :userId
           AND stripe_checkout_session_id = :checkoutId
           AND result = 'checkout_created'
         ORDER BY redemption_id DESC
         LIMIT 1",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
          checkoutId = { value = checkoutId, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
      if (qPending.recordCount EQ 0) {
        return;
      }

      redemptionId = val(qPending.redemption_id[1]);
      promoCodeId = val(qPending.promo_code_id[1]);

      queryExecute(
        "UPDATE fpw_promo_redemptions
         SET result = 'redeemed',
             stripe_customer_id = COALESCE(:stripeCustomerId, stripe_customer_id),
             stripe_subscription_id = COALESCE(:stripeSubscriptionId, stripe_subscription_id),
             redeemed_at_utc = UTC_TIMESTAMP(),
             updated_at_utc = UTC_TIMESTAMP()
         WHERE redemption_id = :redemptionId
           AND result = 'checkout_created'",
        {
          redemptionId = { value = redemptionId, cfsqltype = "cf_sql_bigint" },
          stripeCustomerId = { value = readString(arguments.identifiers, "stripeCustomerId"), cfsqltype = "cf_sql_varchar", null = !len(readString(arguments.identifiers, "stripeCustomerId")) },
          stripeSubscriptionId = { value = readString(arguments.identifiers, "stripeSubscriptionId"), cfsqltype = "cf_sql_varchar", null = !len(readString(arguments.identifiers, "stripeSubscriptionId")) }
        },
        { datasource = variables.datasource }
      );

      if (promoCodeId GT 0) {
        queryExecute(
          "UPDATE fpw_promo_codes
           SET redemptions_count = redemptions_count + 1,
               updated_at_utc = UTC_TIMESTAMP()
           WHERE promo_code_id = :promoCodeId",
          {
            promoCodeId = { value = promoCodeId, cfsqltype = "cf_sql_bigint" }
          },
          { datasource = variables.datasource }
        );
      }
    </cfscript>
  </cffunction>

  <cffunction name="registerEvent" access="private" returntype="struct" output="false">
    <cfargument name="stripeEventId" type="string" required="true">
    <cfargument name="eventType" type="string" required="true">
    <cfargument name="refs" type="struct" required="true">
    <cfscript>
      var qExisting = loadWebhookEvent(arguments.stripeEventId);
      if (qExisting.recordCount GT 0) {
        return {
          "SUCCESS" = true,
          "success" = true,
          "duplicate" = true,
          "processed" = false,
          "stripeEventId" = arguments.stripeEventId,
          "eventType" = arguments.eventType,
          "processingStatus" = qExisting.processing_status[1],
          "MESSAGE" = "Stripe event was already recorded."
        };
      }

      queryExecute(
        "INSERT INTO stripe_webhook_events (
           stripe_event_id,
           event_type,
           processing_status,
           stripe_customer_id,
           stripe_subscription_id,
           stripe_checkout_session_id,
           stripe_invoice_id,
           stripe_payment_intent_id,
           stripe_price_id,
           created_at_utc,
           updated_at_utc
         ) VALUES (
           :stripeEventId,
           :eventType,
           'processing',
           :stripeCustomerId,
           :stripeSubscriptionId,
           :stripeCheckoutSessionId,
           :stripeInvoiceId,
           :stripePaymentIntentId,
           :stripePriceId,
           UTC_TIMESTAMP(),
           UTC_TIMESTAMP()
         )",
        buildEventParams(arguments.stripeEventId, arguments.eventType, 0, arguments.refs, "", ""),
        { datasource = variables.datasource }
      );

      return {
        "SUCCESS" = true,
        "success" = true,
        "duplicate" = false,
        "processed" = true
      };
    </cfscript>
  </cffunction>

  <cffunction name="updateEventResult" access="private" returntype="void" output="false">
    <cfargument name="stripeEventId" type="string" required="true">
    <cfargument name="processingStatus" type="string" required="true">
    <cfargument name="errorMessage" type="string" required="false" default="">
    <cfargument name="userId" type="numeric" required="false" default="0">
    <cfargument name="refs" type="struct" required="true">
    <cfscript>
      queryExecute(
        "UPDATE stripe_webhook_events
         SET processing_status = :processingStatus,
             user_id = :userId,
             stripe_customer_id = COALESCE(:stripeCustomerId, stripe_customer_id),
             stripe_subscription_id = COALESCE(:stripeSubscriptionId, stripe_subscription_id),
             stripe_checkout_session_id = COALESCE(:stripeCheckoutSessionId, stripe_checkout_session_id),
             stripe_invoice_id = COALESCE(:stripeInvoiceId, stripe_invoice_id),
             stripe_payment_intent_id = COALESCE(:stripePaymentIntentId, stripe_payment_intent_id),
             stripe_price_id = COALESCE(:stripePriceId, stripe_price_id),
             processed_at_utc = UTC_TIMESTAMP(),
             error_message = :errorMessage,
             updated_at_utc = UTC_TIMESTAMP()
         WHERE stripe_event_id = :stripeEventId",
        buildEventParams(arguments.stripeEventId, "", arguments.userId, arguments.refs, arguments.processingStatus, left(arguments.errorMessage, 500)),
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="loadWebhookEvent" access="private" returntype="query" output="false">
    <cfargument name="stripeEventId" type="string" required="true">
    <cfscript>
      return queryExecute(
        "SELECT id, processing_status
         FROM stripe_webhook_events
         WHERE stripe_event_id = :stripeEventId
         LIMIT 1",
        {
          stripeEventId = { value = arguments.stripeEventId, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="resolveUserIdFromCheckoutSession" access="private" returntype="numeric" output="false">
    <cfargument name="sessionObject" type="struct" required="true">
    <cfscript>
      return validateUserId(firstNonEmpty([
        readString(arguments.sessionObject, "client_reference_id"),
        readString(arguments.sessionObject, "clientReferenceId"),
        readMetadataString(arguments.sessionObject, "fpwUserId"),
        readMetadataString(arguments.sessionObject, "userId"),
        readMetadataString(arguments.sessionObject, "user_id"),
        readMetadataString(arguments.sessionObject, "USERID")
      ]));
    </cfscript>
  </cffunction>

  <cffunction name="resolveUserIdFromSubscription" access="private" returntype="numeric" output="false">
    <cfargument name="subscriptionObject" type="struct" required="true">
    <cfscript>
      var metadataUserId = validateUserId(firstNonEmpty([
        readMetadataString(arguments.subscriptionObject, "fpwUserId"),
        readMetadataString(arguments.subscriptionObject, "userId"),
        readMetadataString(arguments.subscriptionObject, "user_id"),
        readMetadataString(arguments.subscriptionObject, "USERID")
      ]));
      if (metadataUserId GT 0) {
        return metadataUserId;
      }
      return resolveUserIdFromSubscriptionId(readString(arguments.subscriptionObject, "id"));
    </cfscript>
  </cffunction>

  <cffunction name="resolveUserIdFromSubscriptionId" access="private" returntype="numeric" output="false">
    <cfargument name="subscriptionId" type="string" required="true">
    <cfscript>
      var qUser = queryNew("");
      if (!len(trim(arguments.subscriptionId))) {
        return 0;
      }
      qUser = queryExecute(
        "SELECT me.user_id
         FROM member_entitlements me
         INNER JOIN users u ON u.userId = me.user_id
         WHERE me.source = 'stripe_subscription'
           AND me.stripe_subscription_id = :subscriptionId
         ORDER BY me.id DESC
         LIMIT 1",
        {
          subscriptionId = { value = trim(arguments.subscriptionId), cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
      return qUser.recordCount ? val(qUser.user_id[1]) : 0;
    </cfscript>
  </cffunction>

  <cffunction name="validateUserId" access="private" returntype="numeric" output="false">
    <cfargument name="userIdValue" type="any" required="true">
    <cfscript>
      var userId = isNumeric(arguments.userIdValue) ? val(arguments.userIdValue) : 0;
      var qUser = queryNew("");
      if (userId LTE 0) {
        return 0;
      }
      qUser = queryExecute(
        "SELECT userId
         FROM users
         WHERE userId = :userId
         LIMIT 1",
        {
          userId = { value = userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      return qUser.recordCount ? val(qUser.userId[1]) : 0;
    </cfscript>
  </cffunction>

  <cffunction name="mapSubscriptionStatusToEntitlementStatus" access="private" returntype="string" output="false">
    <cfargument name="subscriptionStatus" type="string" required="true">
    <cfscript>
      switch (lCase(trim(arguments.subscriptionStatus))) {
        case "active":
        case "trialing":
        case "past_due":
          return "active";
        case "unpaid":
        case "canceled":
          return "canceled";
        case "incomplete":
        case "incomplete_expired":
        case "paused":
          return "inactive";
        default:
          return "";
      }
    </cfscript>
  </cffunction>

  <cffunction name="extractReferences" access="private" returntype="struct" output="false">
    <cfargument name="eventType" type="string" required="true">
    <cfargument name="objectData" type="struct" required="true">
    <cfscript>
      var out = {
        "stripeCustomerId" = firstNonEmpty([ readString(arguments.objectData, "customer"), readString(arguments.objectData, "customer_id") ]),
        "stripeSubscriptionId" = "",
        "stripeCheckoutSessionId" = "",
        "stripeInvoiceId" = "",
        "stripePaymentIntentId" = firstNonEmpty([ readString(arguments.objectData, "payment_intent"), readString(arguments.objectData, "paymentIntent") ]),
        "stripePriceId" = extractPriceId(arguments.objectData)
      };

      if (arguments.eventType EQ "checkout.session.completed") {
        out.stripeCheckoutSessionId = readString(arguments.objectData, "id");
        out.stripeSubscriptionId = readString(arguments.objectData, "subscription");
      } else if (left(arguments.eventType, 21) EQ "customer.subscription") {
        out.stripeSubscriptionId = readString(arguments.objectData, "id");
      } else if (left(arguments.eventType, 8) EQ "invoice.") {
        out.stripeInvoiceId = readString(arguments.objectData, "id");
        out.stripeSubscriptionId = firstNonEmpty([
          readString(arguments.objectData, "subscription"),
          readNestedString(arguments.objectData, [ "parent", "subscription_details", "subscription" ])
        ]);
      }

      return out;
    </cfscript>
  </cffunction>

  <cffunction name="extractPriceId" access="private" returntype="string" output="false">
    <cfargument name="objectData" type="struct" required="true">
    <cfscript>
      var items = {};
      var lines = {};
      var data = [];
      var firstItem = {};
      var price = {};

      if (len(readString(arguments.objectData, "stripe_price_id"))) {
        return readString(arguments.objectData, "stripe_price_id");
      }
      if (len(readString(arguments.objectData, "price_id"))) {
        return readString(arguments.objectData, "price_id");
      }
      if (len(readNestedString(arguments.objectData, [ "plan", "id" ]))) {
        return readNestedString(arguments.objectData, [ "plan", "id" ]);
      }

      if (structKeyExists(arguments.objectData, "items") AND isStruct(arguments.objectData.items)) {
        items = arguments.objectData.items;
        if (structKeyExists(items, "data") AND isArray(items.data) AND arrayLen(items.data) GT 0 AND isStruct(items.data[1])) {
          firstItem = items.data[1];
          if (structKeyExists(firstItem, "price") AND isStruct(firstItem.price)) {
            price = firstItem.price;
            return readString(price, "id");
          }
        }
      }

      if (structKeyExists(arguments.objectData, "lines") AND isStruct(arguments.objectData.lines)) {
        lines = arguments.objectData.lines;
        if (structKeyExists(lines, "data") AND isArray(lines.data) AND arrayLen(lines.data) GT 0 AND isStruct(lines.data[1])) {
          firstItem = lines.data[1];
          if (structKeyExists(firstItem, "price") AND isStruct(firstItem.price)) {
            price = firstItem.price;
            return readString(price, "id");
          }
        }
      }

      return "";
    </cfscript>
  </cffunction>

  <cffunction name="getEventObject" access="private" returntype="struct" output="false">
    <cfargument name="event" type="struct" required="true">
    <cfscript>
      if (
        structKeyExists(arguments.event, "data")
        AND isStruct(arguments.event.data)
        AND structKeyExists(arguments.event.data, "object")
        AND isStruct(arguments.event.data.object)
      ) {
        return arguments.event.data.object;
      }
      return {};
    </cfscript>
  </cffunction>

  <cffunction name="buildEntitlementParams" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="status" type="string" required="true">
    <cfargument name="subscriptionStatus" type="string" required="false" default="">
    <cfargument name="identifiers" type="struct" required="true">
    <cfargument name="id" type="numeric" required="false" default="0">
    <cfscript>
      return {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        status = { value = arguments.status, cfsqltype = "cf_sql_varchar" },
        subscriptionStatus = { value = trim(arguments.subscriptionStatus), cfsqltype = "cf_sql_varchar", null = !len(trim(arguments.subscriptionStatus)) },
        stripeCustomerId = { value = readString(arguments.identifiers, "stripeCustomerId"), cfsqltype = "cf_sql_varchar", null = !len(readString(arguments.identifiers, "stripeCustomerId")) },
        stripeSubscriptionId = { value = readString(arguments.identifiers, "stripeSubscriptionId"), cfsqltype = "cf_sql_varchar", null = !len(readString(arguments.identifiers, "stripeSubscriptionId")) },
        stripeCheckoutSessionId = { value = readString(arguments.identifiers, "stripeCheckoutSessionId"), cfsqltype = "cf_sql_varchar", null = !len(readString(arguments.identifiers, "stripeCheckoutSessionId")) },
        stripePaymentIntentId = { value = readString(arguments.identifiers, "stripePaymentIntentId"), cfsqltype = "cf_sql_varchar", null = !len(readString(arguments.identifiers, "stripePaymentIntentId")) },
        stripePriceId = { value = readString(arguments.identifiers, "stripePriceId"), cfsqltype = "cf_sql_varchar", null = !len(readString(arguments.identifiers, "stripePriceId")) },
        id = { value = arguments.id, cfsqltype = "cf_sql_bigint" }
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildEventParams" access="private" returntype="struct" output="false">
    <cfargument name="stripeEventId" type="string" required="true">
    <cfargument name="eventType" type="string" required="true">
    <cfargument name="userId" type="numeric" required="false" default="0">
    <cfargument name="refs" type="struct" required="true">
    <cfargument name="processingStatus" type="string" required="false" default="">
    <cfargument name="errorMessage" type="string" required="false" default="">
    <cfscript>
      return {
        stripeEventId = { value = arguments.stripeEventId, cfsqltype = "cf_sql_varchar" },
        eventType = { value = arguments.eventType, cfsqltype = "cf_sql_varchar" },
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer", null = arguments.userId LTE 0 },
        processingStatus = { value = arguments.processingStatus, cfsqltype = "cf_sql_varchar", null = !len(arguments.processingStatus) },
        errorMessage = { value = arguments.errorMessage, cfsqltype = "cf_sql_varchar", null = !len(arguments.errorMessage) },
        stripeCustomerId = { value = readString(arguments.refs, "stripeCustomerId"), cfsqltype = "cf_sql_varchar", null = !len(readString(arguments.refs, "stripeCustomerId")) },
        stripeSubscriptionId = { value = readString(arguments.refs, "stripeSubscriptionId"), cfsqltype = "cf_sql_varchar", null = !len(readString(arguments.refs, "stripeSubscriptionId")) },
        stripeCheckoutSessionId = { value = readString(arguments.refs, "stripeCheckoutSessionId"), cfsqltype = "cf_sql_varchar", null = !len(readString(arguments.refs, "stripeCheckoutSessionId")) },
        stripeInvoiceId = { value = readString(arguments.refs, "stripeInvoiceId"), cfsqltype = "cf_sql_varchar", null = !len(readString(arguments.refs, "stripeInvoiceId")) },
        stripePaymentIntentId = { value = readString(arguments.refs, "stripePaymentIntentId"), cfsqltype = "cf_sql_varchar", null = !len(readString(arguments.refs, "stripePaymentIntentId")) },
        stripePriceId = { value = readString(arguments.refs, "stripePriceId"), cfsqltype = "cf_sql_varchar", null = !len(readString(arguments.refs, "stripePriceId")) }
      };
    </cfscript>
  </cffunction>

  <cffunction name="mergeReferenceStructs" access="private" returntype="struct" output="false">
    <cfargument name="leftRefs" type="struct" required="true">
    <cfargument name="rightRefs" type="struct" required="true">
    <cfscript>
      var out = duplicate(arguments.leftRefs);
      var key = "";
      for (key in [ "stripeCustomerId", "stripeSubscriptionId", "stripeCheckoutSessionId", "stripeInvoiceId", "stripePaymentIntentId", "stripePriceId" ]) {
        if (structKeyExists(arguments.rightRefs, key) AND len(trim(toString(arguments.rightRefs[key])))) {
          out[key] = trim(toString(arguments.rightRefs[key]));
        }
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="readMetadataString" access="private" returntype="string" output="false">
    <cfargument name="source" type="struct" required="true">
    <cfargument name="key" type="string" required="true">
    <cfscript>
      if (structKeyExists(arguments.source, "metadata") AND isStruct(arguments.source.metadata)) {
        return readString(arguments.source.metadata, arguments.key);
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="readNestedString" access="private" returntype="string" output="false">
    <cfargument name="source" type="struct" required="true">
    <cfargument name="path" type="array" required="true">
    <cfscript>
      var current = arguments.source;
      var i = 0;
      for (i = 1; i LTE arrayLen(arguments.path); i++) {
        if (!isStruct(current) OR !structKeyExists(current, arguments.path[i])) {
          return "";
        }
        current = current[arguments.path[i]];
      }
      if (isNull(current)) {
        return "";
      }
      return trim(toString(current));
    </cfscript>
  </cffunction>

  <cffunction name="readString" access="private" returntype="string" output="false">
    <cfargument name="source" type="any" required="true">
    <cfargument name="key" type="string" required="true">
    <cfscript>
      if (!isStruct(arguments.source) OR !structKeyExists(arguments.source, arguments.key) OR isNull(arguments.source[arguments.key])) {
        return "";
      }
      return trim(toString(arguments.source[arguments.key]));
    </cfscript>
  </cffunction>

  <cffunction name="firstNonEmpty" access="private" returntype="string" output="false">
    <cfargument name="values" type="array" required="true">
    <cfscript>
      var i = 0;
      var value = "";
      for (i = 1; i LTE arrayLen(arguments.values); i++) {
        value = trim(toString(arguments.values[i]));
        if (len(value)) {
          return value;
        }
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="successResponse" access="private" returntype="struct" output="false">
    <cfargument name="message" type="string" required="true">
    <cfargument name="userId" type="numeric" required="false" default="0">
    <cfargument name="refs" type="struct" required="false" default="#structNew()#">
    <cfscript>
      var out = duplicate(arguments.refs);
      out.SUCCESS = true;
      out.success = true;
      out.processed = true;
      out.ignored = false;
      out.userId = arguments.userId;
      out.MESSAGE = arguments.message;
      out.message = arguments.message;
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="ignoredResponse" access="private" returntype="struct" output="false">
    <cfargument name="errorCode" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfargument name="refs" type="struct" required="false" default="#structNew()#">
    <cfargument name="userId" type="numeric" required="false" default="0">
    <cfscript>
      var out = duplicate(arguments.refs);
      out.SUCCESS = true;
      out.success = true;
      out.processed = true;
      out.ignored = true;
      out.userId = arguments.userId;
      out.ERROR = arguments.errorCode;
      out.errorCode = arguments.errorCode;
      out.MESSAGE = arguments.message;
      out.message = arguments.message;
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="errorResponse" access="private" returntype="struct" output="false">
    <cfargument name="errorCode" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfscript>
      return {
        "SUCCESS" = false,
        "success" = false,
        "processed" = false,
        "ERROR" = arguments.errorCode,
        "errorCode" = arguments.errorCode,
        "MESSAGE" = arguments.message,
        "message" = arguments.message
      };
    </cfscript>
  </cffunction>

</cfcomponent>
