<cfsetting showdebugoutput="false">
<cfcontent type="application/json; charset=utf-8">

<cfscript>
response = {
    success = false,
    checkedAt = dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss"),
    configFileExists = false,
    jsonIsValid = false,
    requiredKeysPresent = false,
    missingKeys = [],
    envValue = "",
    successUrlHostOk = false,
    cancelUrlHostOk = false,
    portalUrlHostOk = false,
    secretKeyShapeOk = false,
    webhookSecretShapeOk = false,
    monthlyPriceShapeOk = false,
    yearlyPriceShapeOk = false,
    error = ""
};

try {
    configPath = expandPath("/_fpw_private/stripe-config-prod.json");

    response.configFileExists = fileExists(configPath);

    if (!response.configFileExists) {
        response.error = "Config file not found at resolved app path.";
        writeOutput(serializeJSON(response));
        abort;
    }

    rawConfig = fileRead(configPath, "utf-8");

    response.jsonIsValid = isJSON(rawConfig);

    if (!response.jsonIsValid) {
        response.error = "Config file exists but is not valid JSON.";
        writeOutput(serializeJSON(response));
        abort;
    }

    config = deserializeJSON(rawConfig);

    requiredKeys = [
        "FPW_ENV",
        "FPW_STRIPE_SECRET_KEY",
        "FPW_STRIPE_WEBHOOK_SECRET",
        "FPW_STRIPE_PRICE_PREMIUM_MONTHLY",
        "FPW_STRIPE_PRICE_PREMIUM_YEARLY",
        "FPW_STRIPE_SUCCESS_URL",
        "FPW_STRIPE_CANCEL_URL",
        "FPW_STRIPE_PORTAL_RETURN_URL",
        "FPW_MONITOR_TOKEN"
    ];

    for (keyName in requiredKeys) {
        if (!structKeyExists(config, keyName) || !len(trim(config[keyName] & ""))) {
            arrayAppend(response.missingKeys, keyName);
        }
    }

    response.requiredKeysPresent = arrayLen(response.missingKeys) == 0;

    if (structKeyExists(config, "FPW_ENV")) {
        response.envValue = config.FPW_ENV;
    }

    if (structKeyExists(config, "FPW_STRIPE_SECRET_KEY")) {
        response.secretKeyShapeOk = left(config.FPW_STRIPE_SECRET_KEY, 8) == "sk_test_";
    }

    if (structKeyExists(config, "FPW_STRIPE_WEBHOOK_SECRET")) {
        response.webhookSecretShapeOk = left(config.FPW_STRIPE_WEBHOOK_SECRET, 6) == "whsec_";
    }

    if (structKeyExists(config, "FPW_STRIPE_PRICE_PREMIUM_MONTHLY")) {
        response.monthlyPriceShapeOk = left(config.FPW_STRIPE_PRICE_PREMIUM_MONTHLY, 6) == "price_";
    }

    if (structKeyExists(config, "FPW_STRIPE_PRICE_PREMIUM_YEARLY")) {
        response.yearlyPriceShapeOk = left(config.FPW_STRIPE_PRICE_PREMIUM_YEARLY, 6) == "price_";
    }

    if (structKeyExists(config, "FPW_STRIPE_SUCCESS_URL")) {
        response.successUrlHostOk = findNoCase("floatplanwizard.tmpsite.media3.us", config.FPW_STRIPE_SUCCESS_URL) > 0;
    }

    if (structKeyExists(config, "FPW_STRIPE_CANCEL_URL")) {
        response.cancelUrlHostOk = findNoCase("floatplanwizard.tmpsite.media3.us", config.FPW_STRIPE_CANCEL_URL) > 0;
    }

    if (structKeyExists(config, "FPW_STRIPE_PORTAL_RETURN_URL")) {
        response.portalUrlHostOk = findNoCase("floatplanwizard.tmpsite.media3.us", config.FPW_STRIPE_PORTAL_RETURN_URL) > 0;
    }

    response.success =
        response.configFileExists &&
        response.jsonIsValid &&
        response.requiredKeysPresent &&
        response.envValue == "prod" &&
        response.secretKeyShapeOk &&
        response.webhookSecretShapeOk &&
        response.monthlyPriceShapeOk &&
        response.yearlyPriceShapeOk &&
        response.successUrlHostOk &&
        response.cancelUrlHostOk &&
        response.portalUrlHostOk;

} catch (any e) {
    response.error = "Safe config proof failed.";
}

writeOutput(serializeJSON(response));
</cfscript>
