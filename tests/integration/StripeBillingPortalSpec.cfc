component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.baseUrl = "http://localhost:8500/fpw";
    variables.createdUserIds = [];
    variables.userSeed = 909000000 + randRange(1000, 99999);
  }

  function afterEach() {
    cleanupRows();
  }

  function run() {
    describe("Stripe Billing Portal endpoint", function() {
      it("rejects unauthenticated requests", function() {
        var res = postPortal(0);

        expect(res.SUCCESS).toBeFalse(serializeJSON(res));
        expect(res.AUTH).toBeFalse(serializeJSON(res));
        expect(res.ERROR).toBe("AUTH_REQUIRED");
      });

      it("rejects GET requests before creating portal sessions", function() {
        var res = getPortal();

        expect(res.SUCCESS).toBeFalse(serializeJSON(res));
        expect(res.ERROR).toBe("METHOD_NOT_ALLOWED");
      });

      it("returns safe failure when Stripe billing portal config is missing", function() {
        var userId = nextTestUserId();
        createStripeCustomerMapping(userId, "cus_portal_missing_config_" & userId);
        var service = new fpw.api.v1.StripeCheckoutService().init(
          datasource = "fpw",
          configService = { secretKey = "" },
          stripeTransport = buildFakeTransport()
        );
        var res = service.createPortalSession(userId);

        expect(res.SUCCESS).toBeFalse(serializeJSON(res));
        expect(res.ERROR).toBe("STRIPE_CONFIG_MISSING");
      });

      it("returns NO_BILLING_CUSTOMER when the user has no Stripe customer mapping", function() {
        var res = postPortal(nextTestUserId());

        expect(res.SUCCESS).toBeFalse(serializeJSON(res));
        expect(res.AUTH).toBeTrue(serializeJSON(res));
        expect(res.ERROR).toBe("NO_BILLING_CUSTOMER");
      });

      it("creates portal sessions for mapped users through fake Stripe transport", function() {
        var userId = nextTestUserId();
        var transport = buildFakeTransport();
        var service = new fpw.api.v1.StripeCheckoutService().init(
          datasource = "fpw",
          configService = buildFakeConfig(),
          stripeTransport = transport
        );
        createStripeCustomerMapping(userId, "cus_portal_valid_" & userId);

        var res = service.createPortalSession(userId);

        expect(res.SUCCESS).toBeTrue(serializeJSON(res));
        expect(res.PORTAL_URL).toBe("https://billing.stripe.com/p/session/test_portal");
        expect(arrayLen(transport.portalRequests)).toBe(1);
      });

      it("sends only customer ID and return URL to Stripe Customer Portal", function() {
        var userId = nextTestUserId();
        var transport = buildFakeTransport();
        var service = new fpw.api.v1.StripeCheckoutService().init(
          datasource = "fpw",
          configService = buildFakeConfig(),
          stripeTransport = transport
        );
        createStripeCustomerMapping(userId, "cus_portal_fields_" & userId);

        var res = service.createPortalSession(userId);
        var fields = transport.portalRequests[1].requestPayload.formFields;

        expect(res.SUCCESS).toBeTrue(serializeJSON(res));
        expect(transport.portalRequests[1].requestPayload.url).toBe("https://api.stripe.com/v1/billing_portal/sessions");
        expect(fields.customer).toBe("cus_portal_fields_" & userId);
        expect(fields.return_url).toBe("https://example.invalid/account/billing");
        expect(structCount(fields)).toBe(2);
      });

      it("returns only safe portal fields and no secret or full Stripe payload", function() {
        var userId = nextTestUserId();
        var transport = buildFakeTransport({
          id = "bps_test_hidden",
          object = "billing_portal.session",
          url = "https://billing.stripe.com/p/session/safe",
          customer = "cus_should_not_return",
          client_secret = "should_not_return",
          payment_method = "should_not_return",
          billing_address = { line1 = "should_not_return" }
        });
        var service = new fpw.api.v1.StripeCheckoutService().init(
          datasource = "fpw",
          configService = buildFakeConfig(),
          stripeTransport = transport
        );
        createStripeCustomerMapping(userId, "cus_portal_safe_" & userId);

        var res = service.createPortalSession(userId);

        expect(res.SUCCESS).toBeTrue(serializeJSON(res));
        expect(res.PORTAL_URL).toBe("https://billing.stripe.com/p/session/safe");
        expect(structKeyExists(res, "customer")).toBeFalse(serializeJSON(res));
        expect(structKeyExists(res, "client_secret")).toBeFalse(serializeJSON(res));
        expect(structKeyExists(res, "payment_method")).toBeFalse(serializeJSON(res));
        expect(structKeyExists(res, "billing_address")).toBeFalse(serializeJSON(res));
        expect(findNoCase("sk_test_portal_secret", serializeJSON(res))).toBe(0);
      });

      it("does not alter member_entitlements when creating a portal session", function() {
        var userId = nextTestUserId();
        var service = new fpw.api.v1.StripeCheckoutService().init(
          datasource = "fpw",
          configService = buildFakeConfig(),
          stripeTransport = buildFakeTransport()
        );
        createStripeCustomerMapping(userId, "cus_portal_no_mutation_" & userId);

        var beforeRows = loadEntitlements(userId);
        var res = service.createPortalSession(userId);
        var afterRows = loadEntitlements(userId);

        expect(res.SUCCESS).toBeTrue(serializeJSON(res));
        expect(beforeRows.recordCount).toBe(1);
        expect(afterRows.recordCount).toBe(1);
        expect(afterRows.status[1]).toBe(beforeRows.status[1]);
        expect(afterRows.stripe_customer_id[1]).toBe(beforeRows.stripe_customer_id[1]);
      });
    });
  }

  private numeric function nextTestUserId() {
    variables.userSeed++;
    arrayAppend(variables.createdUserIds, variables.userSeed);
    return variables.userSeed;
  }

  private struct function buildFakeConfig() {
    return {
      secretKey = "sk_test_portal_secret",
      billingPortalReturnUrl = "https://example.invalid/account/billing"
    };
  }

  private struct function buildFakeTransport(struct portalResponseBody = {}) {
    var transport = { portalRequests = [] };
    if (structIsEmpty(arguments.portalResponseBody)) {
      arguments.portalResponseBody = {
        id = "bps_test_portal",
        url = "https://billing.stripe.com/p/session/test_portal"
      };
    }
    transport.portalResponseBody = duplicate(arguments.portalResponseBody);
    transport.createPortalSession = function(required struct requestPayload, required string secretKey) {
      arrayAppend(transport.portalRequests, {
        requestPayload = duplicate(arguments.requestPayload),
        secretKey = arguments.secretKey
      });
      return {
        SUCCESS = true,
        success = true,
        statusCode = 200,
        body = duplicate(transport.portalResponseBody)
      };
    };
    return transport;
  }

  private void function createStripeCustomerMapping(required numeric userId, required string stripeCustomerId) {
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
         stripe_subscription_status,
         created_utc,
         updated_utc
       ) VALUES (
         :userId,
         'premium',
         'stripe_subscription',
         'active',
         UTC_TIMESTAMP(),
         NULL,
         :stripeCustomerId,
         :stripeSubscriptionId,
         'active',
         UTC_TIMESTAMP(),
         UTC_TIMESTAMP()
       )",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        stripeCustomerId = { value = arguments.stripeCustomerId, cfsqltype = "cf_sql_varchar" },
        stripeSubscriptionId = { value = "sub_portal_" & arguments.userId, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
  }

  private struct function postPortal(required numeric userId) {
    var httpResult = {};
    var raw = "";

    cfhttp(url = variables.baseUrl & "/api/v1/billing.cfc?method=handle&action=createportal", method = "post", result = "httpResult", charset = "utf-8") {
      cfhttpparam(type = "header", name = "Content-Type", value = "application/json");
      if (arguments.userId GT 0) {
        cfhttpparam(type = "header", name = "X-FPW-Test-UserId", value = toString(arguments.userId));
      }
      cfhttpparam(type = "body", value = "{}");
    }

    raw = structKeyExists(httpResult, "fileContent") ? trim(httpResult.fileContent) : "";
    return len(raw) ? deserializeJSON(raw, false) : {};
  }

  private struct function getPortal() {
    var httpResult = {};
    var raw = "";

    cfhttp(url = variables.baseUrl & "/api/v1/billing.cfc?method=handle&action=createportal", method = "get", result = "httpResult", charset = "utf-8");

    raw = structKeyExists(httpResult, "fileContent") ? trim(httpResult.fileContent) : "";
    return len(raw) ? deserializeJSON(raw, false) : {};
  }

  private query function loadEntitlements(required numeric userId) {
    return queryExecute(
      "SELECT id, status, stripe_customer_id, stripe_subscription_status
       FROM member_entitlements
       WHERE user_id = :userId
       ORDER BY id ASC",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
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
    }
    variables.createdUserIds = [];
  }

}
