component extends="testbox.system.BaseSpec" output="false" {

  function beforeEach() {
    variables.tempDir = "";
  }

  function afterEach() {
    if (structKeyExists(variables, "tempDir") AND directoryExists(variables.tempDir)) {
      directoryDelete(variables.tempDir, true);
    }
  }

  function run() {
    describe("Stripe JSON config service", function() {
      it("loads Stripe config values from a JSON file", function() {
        var configPath = writeConfig(validConfig());
        var service = new fpw.api.v1.StripeConfigService().init(configPath);
        var status = service.getConfigStatus();
        var settings = service.getApplicationSettings();

        expect(status.SUCCESS).toBeTrue(serializeJSON(status));
        expect(status.configSource).toBe("json");
        expect(status.hasSecretKey).toBeTrue(serializeJSON(status));
        expect(status.hasWebhookSecret).toBeTrue(serializeJSON(status));
        expect(service.getSecretKey()).toBe("sk_test_json_loader_secret");
        expect(service.getWebhookSecret()).toBe("whsec_json_loader_secret");
        expect(service.getPremiumMonthlyPriceId()).toBe("price_json_monthly");
        expect(service.getPremiumYearlyPriceId()).toBe("price_json_yearly");
        expect(service.getCheckoutSuccessUrl()).toBe("http://localhost:8500/fpw/app/account.cfm?stripe=success");
        expect(service.getCheckoutCancelUrl()).toBe("http://localhost:8500/fpw/app/account.cfm?stripe=cancel");
        expect(service.getBillingPortalReturnUrl()).toBe("http://localhost:8500/fpw/app/account.cfm");
        expect(service.getFpwEnv()).toBe("dev");
        expect(service.getMonitorToken()).toBe("monitor_json_token");
        expect(settings.FPW_STRIPE_CHECKOUT_SUCCESS_URL).toBe(service.getCheckoutSuccessUrl());
        expect(settings.FPW_STRIPE_BILLING_PORTAL_RETURN_URL).toBe(service.getBillingPortalReturnUrl());
      });

      it("fails safely when the JSON config file is missing", function() {
        var service = new fpw.api.v1.StripeConfigService().init(getTempDir() & "/missing-stripe-config.json");
        var status = service.getConfigStatus();

        expect(status.SUCCESS).toBeFalse(serializeJSON(status));
        expect(status.ERROR).toBe("STRIPE_CONFIG_FILE_MISSING");
        expect(service.getSecretKey()).toBe("");
      });

      it("fails safely when the JSON config file is invalid", function() {
        var configPath = getTempDir() & "/invalid-stripe-config.json";
        fileWrite(configPath, "{ invalid json", "utf-8");

        var service = new fpw.api.v1.StripeConfigService().init(configPath);
        var status = service.getConfigStatus();

        expect(status.SUCCESS).toBeFalse(serializeJSON(status));
        expect(status.ERROR).toBe("STRIPE_CONFIG_JSON_INVALID");
        expect(service.getWebhookSecret()).toBe("");
      });

      it("fails safely when a required key is missing", function() {
        var config = validConfig();
        structDelete(config, "FPW_STRIPE_WEBHOOK_SECRET", false);

        var service = new fpw.api.v1.StripeConfigService().init(writeConfig(config));
        var status = service.getConfigStatus();

        expect(status.SUCCESS).toBeFalse(serializeJSON(status));
        expect(status.ERROR).toBe("STRIPE_CONFIG_KEY_MISSING");
        expect(service.getWebhookSecret()).toBe("");
      });

      it("fails safely when a required key is blank", function() {
        var config = validConfig({ FPW_STRIPE_PRICE_PREMIUM_MONTHLY = " " });
        var service = new fpw.api.v1.StripeConfigService().init(writeConfig(config));
        var status = service.getConfigStatus();

        expect(status.SUCCESS).toBeFalse(serializeJSON(status));
        expect(status.ERROR).toBe("STRIPE_CONFIG_KEY_BLANK");
        expect(service.getPremiumMonthlyPriceId()).toBe("");
      });

      it("does not include secret values in safe config errors", function() {
        var hiddenSecret = "sk_test_json_secret_should_not_appear";
        var config = validConfig({
          FPW_STRIPE_SECRET_KEY = hiddenSecret,
          FPW_MONITOR_TOKEN = ""
        });
        var service = new fpw.api.v1.StripeConfigService().init(writeConfig(config));
        var statusJson = serializeJSON(service.getConfigStatus());

        expect(findNoCase(hiddenSecret, statusJson)).toBe(0);
        expect(findNoCase("whsec_json_loader_secret", statusJson)).toBe(0);
      });

      it("does not require application settings or environment injected state", function() {
        var service = new fpw.api.v1.StripeConfigService().init(writeConfig(validConfig()));
        var status = service.getConfigStatus();

        expect(status.SUCCESS).toBeTrue(serializeJSON(status));
        expect(service.getSecretKey()).toBe("sk_test_json_loader_secret");
      });
    });
  }

  private string function writeConfig(required struct config) {
    var configPath = getTempDir() & "/stripe-config.json";
    fileWrite(configPath, serializeJSON(arguments.config), "utf-8");
    return configPath;
  }

  private string function getTempDir() {
    if (!structKeyExists(variables, "tempDir") OR !len(trim(toString(variables.tempDir)))) {
      variables.tempDir = getTempDirectory() & "stripe-config-service-" & replace(createUUID(), "-", "", "all");
      directoryCreate(variables.tempDir);
    }
    return variables.tempDir;
  }

  private struct function validConfig(struct overrides = {}) {
    var config = {
      FPW_ENV = "dev",
      FPW_STRIPE_SECRET_KEY = "sk_test_json_loader_secret",
      FPW_STRIPE_WEBHOOK_SECRET = "whsec_json_loader_secret",
      FPW_STRIPE_PRICE_PREMIUM_MONTHLY = "price_json_monthly",
      FPW_STRIPE_PRICE_PREMIUM_YEARLY = "price_json_yearly",
      FPW_STRIPE_SUCCESS_URL = "http://localhost:8500/fpw/app/account.cfm?stripe=success",
      FPW_STRIPE_CANCEL_URL = "http://localhost:8500/fpw/app/account.cfm?stripe=cancel",
      FPW_STRIPE_PORTAL_RETURN_URL = "http://localhost:8500/fpw/app/account.cfm",
      FPW_MONITOR_TOKEN = "monitor_json_token"
    };
    var key = "";

    for (key in arguments.overrides) {
      config[key] = arguments.overrides[key];
    }
    return config;
  }

}
