<cfcomponent output="false">

  <cfset variables.configPath = "">
  <cfset variables.datasource = "fpw">
  <cfset variables.publicBaseUrl = "https://www.floatplanwizard.com">
  <cfset variables.maxTokenAgeSeconds = 31536000>

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="configPath" type="string" required="false" default="">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfargument name="publicBaseUrl" type="string" required="false" default="https://www.floatplanwizard.com">
    <cfscript>
      if (len(trim(arguments.configPath))) {
        variables.configPath = trim(arguments.configPath);
      } else if (isDefined("application") AND structKeyExists(application, "stripeConfigPath") AND len(trim(toString(application.stripeConfigPath)))) {
        variables.configPath = trim(toString(application.stripeConfigPath));
      } else {
        variables.configPath = expandPath("/_fpw_private/stripe-config.json");
      }

      variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
      variables.publicBaseUrl = normalizeBaseUrl(arguments.publicBaseUrl);
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="buildOptOutUrl" access="public" returntype="string" output="false">
    <cfargument name="email" type="string" required="true">
    <cfargument name="userId" type="numeric" required="false" default="0">
    <cfargument name="optOutType" type="string" required="false" default="non_essential">
    <cfscript>
      return variables.publicBaseUrl & "/unsubscribe.cfm?t=" & encodeForURL(buildSignedOptOutToken(
        email = arguments.email,
        userId = arguments.userId,
        optOutType = arguments.optOutType
      ));
    </cfscript>
  </cffunction>

  <cffunction name="buildSignedOptOutToken" access="public" returntype="string" output="false">
    <cfargument name="email" type="string" required="true">
    <cfargument name="userId" type="numeric" required="false" default="0">
    <cfargument name="optOutType" type="string" required="false" default="non_essential">
    <cfscript>
      var normalizedEmail = normalizeEmail(arguments.email);
      var normalizedType = normalizeOptOutType(arguments.optOutType);
      var payload = {
        "v" = 1,
        "uid" = int(val(arguments.userId)),
        "eh" = hashEmail(normalizedEmail),
        "typ" = normalizedType,
        "iat" = currentEpochSeconds()
      };
      var payloadPart = "";
      var signature = "";

      if (!isValid("email", normalizedEmail)) {
        throw(type = "fpw.emailOptOut.InvalidEmail", message = "Email opt-out recipient is invalid.");
      }

      if (payload.uid LTE 0) {
        payload["em"] = normalizedEmail;
      }

      payloadPart = base64UrlEncode(serializeJSON(payload));
      signature = hmacSha256Hex(payloadPart, getOptOutSecret());
      return payloadPart & "." & signature;
    </cfscript>
  </cffunction>

  <cffunction name="validateSignedOptOutToken" access="public" returntype="struct" output="false">
    <cfargument name="token" type="string" required="true">
    <cfscript>
      var tokenParts = listToArray(trim(arguments.token), ".");
      var payloadPart = "";
      var signature = "";
      var expectedSignature = "";
      var payloadJson = "";
      var payload = {};
      var issuedAt = 0;
      var nowSeconds = currentEpochSeconds();
      var normalizedType = "";
      var emailHash = "";
      var email = "";
      var userId = 0;
      var userLookup = {};

      if (arrayLen(tokenParts) NEQ 2) {
        return safeResult(false, "OPTOUT_TOKEN_INVALID", "Opt-out token is invalid.");
      }

      payloadPart = tokenParts[1];
      signature = lCase(trim(tokenParts[2]));
      expectedSignature = hmacSha256Hex(payloadPart, getOptOutSecret());

      if (!secureCompare(signature, expectedSignature)) {
        return safeResult(false, "OPTOUT_TOKEN_INVALID", "Opt-out token is invalid.");
      }

      try {
        payloadJson = base64UrlDecode(payloadPart);
        payload = deserializeJSON(payloadJson, false);
      } catch (any parseErr) {
        return safeResult(false, "OPTOUT_TOKEN_INVALID", "Opt-out token is invalid.");
      }

      if (!isStruct(payload)) {
        return safeResult(false, "OPTOUT_TOKEN_INVALID", "Opt-out token is invalid.");
      }

      normalizedType = normalizeOptOutType(readPayloadValue(payload, "typ"));
      issuedAt = val(readPayloadValue(payload, "iat"));
      userId = int(val(readPayloadValue(payload, "uid")));
      emailHash = lCase(trim(readPayloadValue(payload, "eh")));

      if (issuedAt LTE 0 OR issuedAt GT (nowSeconds + 300) OR (nowSeconds - issuedAt) GT variables.maxTokenAgeSeconds) {
        return safeResult(false, "OPTOUT_TOKEN_EXPIRED", "Opt-out token is expired.");
      }

      if (!isValidHash(emailHash)) {
        return safeResult(false, "OPTOUT_TOKEN_INVALID", "Opt-out token is invalid.");
      }

      if (userId GT 0) {
        userLookup = findUserEmailById(userId);
        if (!userLookup.success OR hashEmail(userLookup.email) NEQ emailHash) {
          return safeResult(false, "OPTOUT_TOKEN_INVALID", "Opt-out token is invalid.");
        }
        email = userLookup.email;
      } else {
        email = normalizeEmail(readPayloadValue(payload, "em"));
        if (!isValid("email", email) OR hashEmail(email) NEQ emailHash) {
          return safeResult(false, "OPTOUT_TOKEN_INVALID", "Opt-out token is invalid.");
        }
      }

      return {
        "success" = true,
        "errorCode" = "",
        "message" = "Opt-out token is valid.",
        "email" = email,
        "emailHash" = emailHash,
        "userId" = userId,
        "optOutType" = normalizedType
      };
    </cfscript>
  </cffunction>

  <cffunction name="processOptOutToken" access="public" returntype="struct" output="false">
    <cfargument name="token" type="string" required="true">
    <cfargument name="source" type="string" required="false" default="unsubscribe_page">
    <cfargument name="ipAddress" type="string" required="false" default="">
    <cfargument name="userAgent" type="string" required="false" default="">
    <cfscript>
      var validation = validateSignedOptOutToken(arguments.token);
      if (!validation.success) {
        return safeResult(false, validation.errorCode, "Opt-out link could not be processed.");
      }

      return recordOptOut(
        email = validation.email,
        userId = validation.userId,
        optOutType = validation.optOutType,
        source = arguments.source,
        ipAddress = arguments.ipAddress,
        userAgent = arguments.userAgent
      );
    </cfscript>
  </cffunction>

  <cffunction name="recordOptOut" access="public" returntype="struct" output="false">
    <cfargument name="email" type="string" required="true">
    <cfargument name="userId" type="numeric" required="false" default="0">
    <cfargument name="optOutType" type="string" required="false" default="non_essential">
    <cfargument name="source" type="string" required="false" default="email_footer">
    <cfargument name="ipAddress" type="string" required="false" default="">
    <cfargument name="userAgent" type="string" required="false" default="">
    <cfscript>
      var normalizedEmail = normalizeEmail(arguments.email);
      var normalizedType = normalizeOptOutType(arguments.optOutType);
      var nowStamp = now();
      var params = {};

      if (!isValid("email", normalizedEmail)) {
        return safeResult(false, "OPTOUT_EMAIL_INVALID", "Opt-out email is invalid.");
      }

      params = {
        email = { value = normalizedEmail, cfsqltype = "cf_sql_varchar" },
        userId = { value = int(val(arguments.userId)), cfsqltype = "cf_sql_integer" },
        emailHash = { value = hashEmail(normalizedEmail), cfsqltype = "cf_sql_char" },
        optOutType = { value = normalizedType, cfsqltype = "cf_sql_varchar" },
        source = { value = left(cleanTextValue(arguments.source), 80), cfsqltype = "cf_sql_varchar" },
        ipHash = { value = hashOptionalValue(arguments.ipAddress), cfsqltype = "cf_sql_char", null = !len(hashOptionalValue(arguments.ipAddress)) },
        userAgentHash = { value = hashOptionalValue(arguments.userAgent), cfsqltype = "cf_sql_char", null = !len(hashOptionalValue(arguments.userAgent)) },
        nowStamp = { value = nowStamp, cfsqltype = "cf_sql_timestamp" }
      };

      queryExecute("
        INSERT INTO email_optout (
          user_id,
          email,
          email_hash,
          opt_out_type,
          source,
          ip_hash,
          user_agent_hash,
          date_added,
          created_at,
          updated_at,
          lastUpdate
        ) VALUES (
          :userId,
          :email,
          :emailHash,
          :optOutType,
          :source,
          :ipHash,
          :userAgentHash,
          :nowStamp,
          :nowStamp,
          :nowStamp,
          :nowStamp
        )
        ON DUPLICATE KEY UPDATE
          user_id = IF(VALUES(user_id) > 0, VALUES(user_id), user_id),
          email = VALUES(email),
          source = VALUES(source),
          ip_hash = VALUES(ip_hash),
          user_agent_hash = VALUES(user_agent_hash),
          updated_at = VALUES(updated_at),
          lastUpdate = VALUES(lastUpdate)
      ", params, { datasource = variables.datasource });

      return safeResult(true, "", "Non-essential email opt-out recorded.");
    </cfscript>
  </cffunction>

  <cffunction name="isOptedOut" access="public" returntype="boolean" output="false">
    <cfargument name="email" type="string" required="true">
    <cfargument name="optOutType" type="string" required="false" default="non_essential">
    <cfscript>
      var normalizedEmail = normalizeEmail(arguments.email);
      var normalizedType = normalizeOptOutType(arguments.optOutType);
      var result = "";

      if (!isValid("email", normalizedEmail)) {
        return false;
      }

      result = queryExecute("
        SELECT COUNT(*) AS row_count
        FROM email_optout
        WHERE email_hash = :emailHash
          AND opt_out_type = :optOutType
      ", {
        emailHash = { value = hashEmail(normalizedEmail), cfsqltype = "cf_sql_char" },
        optOutType = { value = normalizedType, cfsqltype = "cf_sql_varchar" }
      }, { datasource = variables.datasource });

      return result.row_count[1] GT 0;
    </cfscript>
  </cffunction>

  <cffunction name="getOptOutSecret" access="private" returntype="string" output="false">
    <cfscript>
      var configResult = loadPrivateConfig();
      var secretValue = "";

      if (!configResult.success) {
        throw(type = "fpw.emailOptOut.ConfigMissing", message = "Email opt-out configuration is missing.");
      }

      secretValue = readStructValue(configResult.config, "PW_EMAIL_OPTOUT_SECRET");
      if (!len(secretValue)) {
        throw(type = "fpw.emailOptOut.SecretMissing", message = "Email opt-out secret is missing.");
      }

      return secretValue;
    </cfscript>
  </cffunction>

  <cffunction name="loadPrivateConfig" access="private" returntype="struct" output="false">
    <cfscript>
      var rawContent = "";
      var parsedConfig = {};

      if (!fileExists(variables.configPath)) {
        return safeConfigResult(false, "OPTOUT_CONFIG_FILE_MISSING", {});
      }

      try {
        rawContent = fileRead(variables.configPath, "utf-8");
      } catch (any readErr) {
        return safeConfigResult(false, "OPTOUT_CONFIG_FILE_UNREADABLE", {});
      }

      try {
        parsedConfig = deserializeJSON(rawContent, false);
      } catch (any parseErr) {
        return safeConfigResult(false, "OPTOUT_CONFIG_JSON_INVALID", {});
      }

      if (!isStruct(parsedConfig)) {
        return safeConfigResult(false, "OPTOUT_CONFIG_JSON_INVALID", {});
      }

      return safeConfigResult(true, "", parsedConfig);
    </cfscript>
  </cffunction>

  <cffunction name="findUserEmailById" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var userResult = queryExecute("
        SELECT email
        FROM users
        WHERE userId = :userId
        LIMIT 1
      ", {
        userId = { value = int(val(arguments.userId)), cfsqltype = "cf_sql_integer" }
      }, { datasource = variables.datasource });

      if (userResult.recordCount NEQ 1) {
        return { success = false, email = "" };
      }

      return { success = true, email = normalizeEmail(userResult.email[1]) };
    </cfscript>
  </cffunction>

  <cffunction name="normalizeOptOutType" access="private" returntype="string" output="false">
    <cfargument name="optOutType" type="string" required="true">
    <cfscript>
      var normalizedType = lCase(trim(arguments.optOutType));
      if (normalizedType NEQ "non_essential") {
        throw(type = "fpw.emailOptOut.InvalidType", message = "Email opt-out type is invalid.");
      }
      return normalizedType;
    </cfscript>
  </cffunction>

  <cffunction name="normalizeEmail" access="private" returntype="string" output="false">
    <cfargument name="email" type="string" required="true">
    <cfreturn lCase(trim(arguments.email))>
  </cffunction>

  <cffunction name="hashEmail" access="private" returntype="string" output="false">
    <cfargument name="email" type="string" required="true">
    <cfreturn lCase(hash(normalizeEmail(arguments.email), "SHA-256", "UTF-8"))>
  </cffunction>

  <cffunction name="hashOptionalValue" access="private" returntype="string" output="false">
    <cfargument name="value" type="string" required="false" default="">
    <cfscript>
      var cleanValue = trim(arguments.value);
      if (!len(cleanValue)) {
        return "";
      }
      return lCase(hash(cleanValue, "SHA-256", "UTF-8"));
    </cfscript>
  </cffunction>

  <cffunction name="base64UrlEncode" access="private" returntype="string" output="false">
    <cfargument name="value" type="string" required="true">
    <cfscript>
      var encoder = createObject("java", "java.util.Base64").getUrlEncoder().withoutPadding();
      return encoder.encodeToString(charsetDecode(arguments.value, "utf-8"));
    </cfscript>
  </cffunction>

  <cffunction name="base64UrlDecode" access="private" returntype="string" output="false">
    <cfargument name="value" type="string" required="true">
    <cfscript>
      var decoder = createObject("java", "java.util.Base64").getUrlDecoder();
      var decodedBytes = decoder.decode(arguments.value);
      return createObject("java", "java.lang.String").init(decodedBytes, "UTF-8");
    </cfscript>
  </cffunction>

  <cffunction name="hmacSha256Hex" access="private" returntype="string" output="false">
    <cfargument name="message" type="string" required="true">
    <cfargument name="secret" type="string" required="true">
    <cfreturn lCase(hmac(arguments.message, arguments.secret, "HmacSHA256", "utf-8"))>
  </cffunction>

  <cffunction name="secureCompare" access="private" returntype="boolean" output="false">
    <cfargument name="leftValue" type="string" required="true">
    <cfargument name="rightValue" type="string" required="true">
    <cfscript>
      var i = 0;
      var diff = 0;
      if (len(arguments.leftValue) NEQ len(arguments.rightValue)) {
        return false;
      }
      for (i = 1; i LTE len(arguments.leftValue); i++) {
        diff = bitOr(diff, bitXor(asc(mid(arguments.leftValue, i, 1)), asc(mid(arguments.rightValue, i, 1))));
      }
      return diff EQ 0;
    </cfscript>
  </cffunction>

  <cffunction name="currentEpochSeconds" access="private" returntype="numeric" output="false">
    <cfscript>
      var epochLocal = dateConvert("utc2local", createDateTime(1970, 1, 1, 0, 0, 0));
      return dateDiff("s", epochLocal, now());
    </cfscript>
  </cffunction>

  <cffunction name="readPayloadValue" access="private" returntype="string" output="false">
    <cfargument name="payload" type="struct" required="true">
    <cfargument name="name" type="string" required="true">
    <cfreturn readStructValue(arguments.payload, arguments.name)>
  </cffunction>

  <cffunction name="readStructValue" access="private" returntype="string" output="false">
    <cfargument name="source" type="struct" required="true">
    <cfargument name="name" type="string" required="true">
    <cfscript>
      if (structKeyExists(arguments.source, arguments.name) AND !isNull(arguments.source[arguments.name])) {
        return trim(toString(arguments.source[arguments.name]));
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="isValidHash" access="private" returntype="boolean" output="false">
    <cfargument name="value" type="string" required="true">
    <cfreturn reFindNoCase("^[a-f0-9]{64}$", arguments.value) EQ 1>
  </cffunction>

  <cffunction name="normalizeBaseUrl" access="private" returntype="string" output="false">
    <cfargument name="baseUrl" type="string" required="true">
    <cfscript>
      var cleanUrl = trim(arguments.baseUrl);
      if (!len(cleanUrl)) {
        cleanUrl = "https://www.floatplanwizard.com";
      }
      return reReplace(cleanUrl, "/+$", "", "all");
    </cfscript>
  </cffunction>

  <cffunction name="cleanTextValue" access="private" returntype="string" output="false">
    <cfargument name="value" type="string" required="false" default="">
    <cfreturn reReplace(trim(arguments.value), "[\r\n\t]+", " ", "all")>
  </cffunction>

  <cffunction name="safeConfigResult" access="private" returntype="struct" output="false">
    <cfargument name="success" type="boolean" required="true">
    <cfargument name="errorCode" type="string" required="false" default="">
    <cfargument name="config" type="struct" required="false" default="#structNew()#">
    <cfreturn {
      "success" = arguments.success,
      "errorCode" = arguments.errorCode,
      "config" = arguments.config
    }>
  </cffunction>

  <cffunction name="safeResult" access="private" returntype="struct" output="false">
    <cfargument name="success" type="boolean" required="true">
    <cfargument name="errorCode" type="string" required="false" default="">
    <cfargument name="message" type="string" required="false" default="">
    <cfreturn {
      "success" = arguments.success,
      "errorCode" = arguments.errorCode,
      "message" = arguments.message
    }>
  </cffunction>

</cfcomponent>
