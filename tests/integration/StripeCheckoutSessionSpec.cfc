component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.baseUrl = "http://localhost:8500/fpw";
    variables.accessService = new fpw.api.v1.MemberEntitlementService().init("fpw");
    variables.createdUserIds = [];
    variables.userSeed = 908000000 + randRange(1000, 99999);
  }

  function afterEach() {
    cleanupRows();
  }

  function run() {
    describe("Stripe Checkout session endpoint", function() {
      it("rejects unauthenticated requests", function() {
        var res = postBilling(0, { interval = "monthly" });

        expect(res.SUCCESS).toBeFalse(serializeJSON(res));
        expect(res.AUTH).toBeFalse(serializeJSON(res));
        expect(res.ERROR).toBe("AUTH_REQUIRED");
      });

      it("rejects GET requests before creating checkout sessions", function() {
        var res = getBilling();

        expect(res.SUCCESS).toBeFalse(serializeJSON(res));
        expect(res.ERROR).toBe("METHOD_NOT_ALLOWED");
      });

      it("rejects already-Premium users before Stripe checkout creation", function() {
        var billingUser = createDisposableBillingUser();
        var billingApi = {};
        var userId = billingUser.userId;
        var hadOriginalSessionUser = structKeyExists(session, "user");
        var originalSessionUser = (hadOriginalSessionUser && isStruct(session.user)) ? duplicate(session.user) : {};
        var res = {};
        variables.accessService.createSubscriptionEntitlement(userId, {
          stripeSubscriptionId = "sub_checkout_existing_" & userId,
          stripeCustomerId = "cus_checkout_existing_" & userId
        });

        try {
          session.user = {
            userId = userId,
            id = userId,
            USERID = userId
          };
          billingApi = new fpw.tests.support.FpwApiSupport().init(
            baseUrl = variables.baseUrl,
            authEmail = billingUser.email,
            authPassword = billingUser.password
          );
          res = billingApi.postJson("/api/v1/billing.cfc?method=handle&action=createcheckoutsession", {
            interval = "monthly"
          });
        } finally {
          if (hadOriginalSessionUser) {
            session.user = originalSessionUser;
          } else {
            structDelete(session, "user", false);
          }
        }

        expect(res.SUCCESS).toBeFalse(serializeJSON(res));
        expect(res.AUTH).toBeTrue(serializeJSON(res));
        expect(res.ERROR).toBe("ALREADY_PREMIUM");
        expect(countEntitlements(userId)).toBe(1);
      });

      it("returns safe failure when Stripe checkout config is missing", function() {
        var service = new fpw.api.v1.StripeCheckoutService().init(
          datasource = "fpw",
          configService = {},
          stripeTransport = buildFakeTransport()
        );
        var res = service.createCheckoutSession(nextTestUserId(), "monthly");

        expect(res.SUCCESS).toBeFalse(serializeJSON(res));
        expect(res.ERROR).toBe("STRIPE_CONFIG_MISSING");
      });

      it("rejects unknown price selectors before reading arbitrary browser price IDs", function() {
        var service = new fpw.api.v1.StripeCheckoutService().init(
          datasource = "fpw",
          configService = buildFakeConfig(),
          stripeTransport = buildFakeTransport()
        );
        var res = service.createCheckoutSession(nextTestUserId(), "price_unsafe_browser_value");

        expect(res.SUCCESS).toBeFalse(serializeJSON(res));
        expect(res.ERROR).toBe("INVALID_PRICE_SELECTOR");
      });

      it("maps monthly and yearly selectors to configured Stripe price IDs", function() {
        var monthlyTransport = buildFakeTransport();
        var yearlyTransport = buildFakeTransport();
        var monthlyService = new fpw.api.v1.StripeCheckoutService().init(
          datasource = "fpw",
          configService = buildFakeConfig(),
          stripeTransport = monthlyTransport
        );
        var yearlyService = new fpw.api.v1.StripeCheckoutService().init(
          datasource = "fpw",
          configService = buildFakeConfig(),
          stripeTransport = yearlyTransport
        );

        var monthlyRes = monthlyService.createCheckoutSession(nextTestUserId(), "monthly");
        var yearlyRes = yearlyService.createCheckoutSession(nextTestUserId(), "yearly");

        expect(monthlyRes.SUCCESS).toBeTrue(serializeJSON(monthlyRes));
        expect(yearlyRes.SUCCESS).toBeTrue(serializeJSON(yearlyRes));
        expect(monthlyTransport.requests[1].requestPayload.formFields["line_items[0][price]"]).toBe("price_premium_monthly_test");
        expect(yearlyTransport.requests[1].requestPayload.formFields["line_items[0][price]"]).toBe("price_premium_yearly_test");
      });

      it("sends exact FPW user mapping fields to Stripe Checkout", function() {
        var userId = nextTestUserId();
        var transport = buildFakeTransport();
        var service = new fpw.api.v1.StripeCheckoutService().init(
          datasource = "fpw",
          configService = buildFakeConfig(),
          stripeTransport = transport
        );
        var res = service.createCheckoutSession(userId, "monthly");
        var fields = transport.requests[1].requestPayload.formFields;

        expect(res.SUCCESS).toBeTrue(serializeJSON(res));
        expect(fields.mode).toBe("subscription");
        expect(fields["line_items[0][quantity]"]).toBe("1");
        expect(fields.success_url).toBe("https://example.invalid/checkout/success");
        expect(fields.cancel_url).toBe("https://example.invalid/checkout/cancel");
        expect(fields.client_reference_id).toBe(toString(userId));
        expect(fields["metadata[fpwUserId]"]).toBe(toString(userId));
        expect(fields["subscription_data[metadata][fpwUserId]"]).toBe(toString(userId));
      });

      it("creates cardless free-trial subscription Checkout with cancel-on-missing-payment-method", function() {
        var userId = nextTestUserId();
        var transport = buildFakeTransport({
          id = "cs_test_trial_checkout",
          url = "https://checkout.stripe.com/c/pay/cs_test_trial_checkout"
        });
        var service = new fpw.api.v1.StripeCheckoutService().init(
          datasource = "fpw",
          configService = buildFakeConfig(),
          stripeTransport = transport
        );
        var res = service.createFreeTrialCheckoutSession(userId, 60, { promoType = "stripe_free_months" });
        var fields = transport.requests[1].requestPayload.formFields;

        expect(res.SUCCESS).toBeTrue(serializeJSON(res));
        expect(res.trialDays).toBe(60);
        expect(res.CHECKOUT_URL).toBe("https://checkout.stripe.com/c/pay/cs_test_trial_checkout");
        expect(fields.mode).toBe("subscription");
        expect(fields["line_items[0][price]"]).toBe("price_premium_monthly_test");
        expect(fields["line_items[0][quantity]"]).toBe("1");
        expect(fields.payment_method_collection).toBe("if_required");
        expect(fields["subscription_data[trial_period_days]"]).toBe("60");
        expect(fields["subscription_data[trial_settings][end_behavior][missing_payment_method]"]).toBe("cancel");
        expect(fields.client_reference_id).toBe(toString(userId));
        expect(fields["metadata[fpwUserId]"]).toBe(toString(userId));
        expect(fields["metadata[fpwPromoType]"]).toBe("stripe_free_months");
        expect(fields["metadata[fpwTrialDays]"]).toBe("60");
        expect(fields["subscription_data[metadata][fpwUserId]"]).toBe(toString(userId));
        expect(fields["subscription_data[metadata][fpwPromoType]"]).toBe("stripe_free_months");
        expect(fields["subscription_data[metadata][fpwTrialDays]"]).toBe("60");
        expect(findNoCase("sk_test_checkout_secret", serializeJSON(res))).toBe(0);
      });

      it("retrieves safe Checkout session status fields for pending trial reuse", function() {
        var transport = buildFakeTransport({
          id = "cs_test_reuse",
          url = "https://checkout.stripe.com/c/pay/cs_test_reuse",
          status = "open",
          payment_status = "unpaid",
          client_secret = "should_not_return"
        });
        var service = new fpw.api.v1.StripeCheckoutService().init(
          datasource = "fpw",
          configService = buildFakeConfig(),
          stripeTransport = transport
        );
        var res = service.retrieveCheckoutSession("cs_test_reuse");

        expect(res.SUCCESS).toBeTrue(serializeJSON(res));
        expect(res.status).toBe("open");
        expect(res.checkoutUrl).toBe("https://checkout.stripe.com/c/pay/cs_test_reuse");
        expect(res.stripeCheckoutSessionId).toBe("cs_test_reuse");
        expect(findNoCase("should_not_return", serializeJSON(res))).toBe(0);
        expect(transport.retrieveRequests[1].checkoutSessionId).toBe("cs_test_reuse");
      });

      it("returns only safe checkout fields and no secret or full Stripe payload", function() {
        var transport = buildFakeTransport({
          id = "cs_test_safe",
          url = "https://checkout.stripe.com/c/pay/cs_test_safe",
          client_secret = "should_not_return",
          payment_method = "should_not_return",
          billing_address = { line1 = "should_not_return" },
          metadata = { fpwUserId = "123" }
        });
        var service = new fpw.api.v1.StripeCheckoutService().init(
          datasource = "fpw",
          configService = buildFakeConfig(),
          stripeTransport = transport
        );
        var res = service.createCheckoutSession(nextTestUserId(), "monthly");

        expect(res.SUCCESS).toBeTrue(serializeJSON(res));
        expect(res.CHECKOUT_URL).toBe("https://checkout.stripe.com/c/pay/cs_test_safe");
        expect(res.STRIPE_CHECKOUT_SESSION_ID).toBe("cs_test_safe");
        expect(structKeyExists(res, "client_secret")).toBeFalse(serializeJSON(res));
        expect(structKeyExists(res, "payment_method")).toBeFalse(serializeJSON(res));
        expect(structKeyExists(res, "billing_address")).toBeFalse(serializeJSON(res));
        expect(structKeyExists(res, "metadata")).toBeFalse(serializeJSON(res));
        expect(findNoCase("sk_test_checkout_secret", serializeJSON(res))).toBe(0);
      });

      it("does not create or activate Premium entitlement from checkout creation or success URL state", function() {
        var userId = nextTestUserId();
        var service = new fpw.api.v1.StripeCheckoutService().init(
          datasource = "fpw",
          configService = buildFakeConfig(),
          stripeTransport = buildFakeTransport()
        );
        var res = service.createCheckoutSession(userId, "monthly");
        var access = variables.accessService.getCurrentAccess(userId);

        expect(res.SUCCESS).toBeTrue(serializeJSON(res));
        expect(access.hasPremium).toBeFalse(serializeJSON(access));
        expect(countEntitlements(userId)).toBe(0);
      });
    });
  }

  private numeric function nextTestUserId() {
    variables.userSeed++;
    arrayAppend(variables.createdUserIds, variables.userSeed);
    return variables.userSeed;
  }

  private struct function createDisposableBillingUser() {
    var signupApi = new fpw.tests.support.FpwApiSupport().init(
      baseUrl = variables.baseUrl
    );
    var uniqueEmail = "fpw-billing-" & replace(createUUID(), "-", "", "all") & "@example.com";
    var payload = signupApi.postJson("/api/v1/join.cfc?method=handle", {
      firstName = "FPW",
      lastName = "Billing",
      email = uniqueEmail,
      password = "changeIt",
      confirmPassword = "changeIt",
      termsAccepted = true
    }, false);

    expect(payload.SUCCESS).toBeTrue(serializeJSON(payload));
    expect(val(payload.USERID ?: 0)).toBeGT(0, serializeJSON(payload));
    arrayAppend(variables.createdUserIds, val(payload.USERID));

    return {
      userId = val(payload.USERID),
      email = uniqueEmail,
      password = "changeIt"
    };
  }

  private struct function buildFakeConfig() {
    return {
      secretKey = "sk_test_checkout_secret",
      premiumMonthlyPriceId = "price_premium_monthly_test",
      premiumYearlyPriceId = "price_premium_yearly_test",
      checkoutSuccessUrl = "https://example.invalid/checkout/success",
      checkoutCancelUrl = "https://example.invalid/checkout/cancel"
    };
  }

  private struct function buildFakeTransport(struct responseBody = {}) {
    var transport = { requests = [], retrieveRequests = [] };
    if (structIsEmpty(arguments.responseBody)) {
      arguments.responseBody = {
        id = "cs_test_checkout",
        url = "https://checkout.stripe.com/c/pay/cs_test_checkout"
      };
    }
    transport.responseBody = duplicate(arguments.responseBody);
    transport.createCheckoutSession = function(required struct requestPayload, required string secretKey) {
      arrayAppend(transport.requests, {
        requestPayload = duplicate(arguments.requestPayload),
        secretKey = arguments.secretKey
      });
      return {
        SUCCESS = true,
        success = true,
        statusCode = 200,
        body = duplicate(transport.responseBody)
      };
    };
    transport.retrieveCheckoutSession = function(required string checkoutSessionId, required string secretKey) {
      arrayAppend(transport.retrieveRequests, {
        checkoutSessionId = arguments.checkoutSessionId,
        secretKey = arguments.secretKey
      });
      return {
        SUCCESS = true,
        success = true,
        statusCode = 200,
        body = duplicate(transport.responseBody)
      };
    };
    return transport;
  }

  private struct function postBilling(required numeric userId, required struct body) {
    var httpResult = {};
    var raw = "";

    cfhttp(url = variables.baseUrl & "/api/v1/billing.cfc?method=handle&action=createcheckoutsession", method = "post", result = "httpResult", charset = "utf-8") {
      cfhttpparam(type = "header", name = "Content-Type", value = "application/json");
      if (arguments.userId GT 0) {
        cfhttpparam(type = "header", name = "X-FPW-Test-UserId", value = toString(arguments.userId));
      }
      cfhttpparam(type = "body", value = serializeJSON(arguments.body));
    }

    raw = structKeyExists(httpResult, "fileContent") ? trim(httpResult.fileContent) : "";
    return len(raw) ? deserializeJSON(raw, false) : {};
  }

  private struct function getBilling() {
    var httpResult = {};
    var raw = "";

    cfhttp(url = variables.baseUrl & "/api/v1/billing.cfc?method=handle&action=createcheckoutsession", method = "get", result = "httpResult", charset = "utf-8");

    raw = structKeyExists(httpResult, "fileContent") ? trim(httpResult.fileContent) : "";
    return len(raw) ? deserializeJSON(raw, false) : {};
  }

  private numeric function countEntitlements(required numeric userId) {
    var qRows = queryExecute(
      "SELECT COUNT(*) AS rowCount
       FROM member_entitlements
       WHERE user_id = :userId",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    return val(qRows.rowCount[1]);
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
        "DELETE FROM users_address WHERE userId = :userId",
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
    variables.createdUserIds = [];
  }

}
