<cfcomponent output="false">

  <cfset variables.datasource = "fpw">
  <cfset variables.pairingMinutes = 10>
  <cfset variables.tokenDays = 90>
  <cfset variables.inactivityDays = 30>
  <cfset variables.maxPairingAttempts = 5>
  <cfset variables.defaultScopes = "companion:current,companion:checkin">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfscript>
      variables.datasource = arguments.datasource;
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="createPairingCode" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var rawCode = "";
      var normalizedCode = "";
      var expiresAtUtc = dateAdd("n", variables.pairingMinutes, dateConvert("local2utc", now()));
      var codeHash = "";
      var qRow = {};

      if (arguments.userId LTE 0) {
        return errorResponse("NOT_LOGGED_IN", "Not logged in.", false);
      }

      rawCode = formatPairingCode(generateRandomString(8, "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"));
      normalizedCode = normalizePairingCode(rawCode);
      codeHash = hashSecret(normalizedCode);

      queryExecute(
        "INSERT INTO companion_pairing_codes (
           user_id,
           code_hash,
           code_hint,
           expires_at_utc,
           created_utc,
           updated_utc
         ) VALUES (
           :userId,
           :codeHash,
           :codeHint,
           :expiresAtUtc,
           UTC_TIMESTAMP(),
           UTC_TIMESTAMP()
         )",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
          codeHash = { value = codeHash, cfsqltype = "cf_sql_char" },
          codeHint = { value = right(normalizedCode, 4), cfsqltype = "cf_sql_varchar" },
          expiresAtUtc = { value = expiresAtUtc, cfsqltype = "cf_sql_timestamp" }
        },
        { datasource = variables.datasource }
      );

      qRow = queryExecute(
        "SELECT id, expires_at_utc
         FROM companion_pairing_codes
         WHERE code_hash = :codeHash
         LIMIT 1",
        {
          codeHash = { value = codeHash, cfsqltype = "cf_sql_char" }
        },
        { datasource = variables.datasource }
      );

      return {
        "SUCCESS" = true,
        "success" = true,
        "AUTH" = true,
        "PAIRING_CODE_ID" = qRow.recordCount ? val(qRow.id[1]) : 0,
        "pairingCodeId" = qRow.recordCount ? val(qRow.id[1]) : 0,
        "PAIRING_CODE" = rawCode,
        "pairingCode" = rawCode,
        "EXPIRES_AT_UTC" = qRow.recordCount ? formatUtcDate(qRow.expires_at_utc[1]) : formatUtcDate(expiresAtUtc),
        "expiresAtUtc" = qRow.recordCount ? formatUtcDate(qRow.expires_at_utc[1]) : formatUtcDate(expiresAtUtc),
        "PAIRING_URI" = "fpwcompanion://pair?code=" & urlEncodedFormat(rawCode),
        "pairingUri" = "fpwcompanion://pair?code=" & urlEncodedFormat(rawCode)
      };
    </cfscript>
  </cffunction>

  <cffunction name="exchangePairingCode" access="public" returntype="struct" output="false">
    <cfargument name="pairingCode" type="string" required="true">
    <cfargument name="device" type="struct" required="false">
    <cfscript>
      var normalizedCode = normalizePairingCode(arguments.pairingCode);
      var codeHash = "";
      var qCode = {};
      var devicePayload = (structKeyExists(arguments, "device") AND isStruct(arguments.device)) ? arguments.device : {};
      var deviceValidation = validateDevice(devicePayload);
      var tokenPrefix = "";
      var rawToken = "";
      var tokenHash = "";
      var expiresAtUtc = dateAdd("d", variables.tokenDays, dateConvert("local2utc", now()));
      var deviceId = 0;
      var qDevice = {};
      var qUsed = {};

      if (!len(normalizedCode)) {
        return errorResponse("PAIRING_CODE_REQUIRED", "pairingCode is required.", false);
      }

      if (!deviceValidation.SUCCESS) {
        return deviceValidation;
      }

      codeHash = hashSecret(normalizedCode);
      qCode = loadPairingCodeByHash(codeHash);

      if (qCode.recordCount EQ 0) {
        return errorResponse("PAIRING_CODE_INVALID", "Pairing code is invalid or expired.", false);
      }

      if (hasQueryValue(qCode.revoked_at_utc[1])) {
        return errorResponse("PAIRING_CODE_INVALID", "Pairing code is invalid or expired.", false);
      }

      if (hasQueryValue(qCode.used_at_utc[1]) OR (hasQueryValue(qCode.used_by_device_id[1]) AND val(qCode.used_by_device_id[1]) GT 0)) {
        return errorResponse("PAIRING_CODE_USED", "Pairing code has already been used.", false);
      }

      if (val(qCode.attempt_count[1]) GTE variables.maxPairingAttempts) {
        return errorResponse("PAIRING_ATTEMPTS_EXCEEDED", "Pairing code attempt limit was exceeded.", false);
      }

      if (val(qCode.is_expired[1]) EQ 1) {
        return errorResponse("PAIRING_CODE_EXPIRED", "Pairing code is invalid or expired.", false);
      }

      tokenPrefix = generateTokenPrefix();
      rawToken = tokenPrefix & "." & generateRandomString(48, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789");
      tokenHash = hashSecret(rawToken);

      queryExecute(
        "INSERT INTO companion_devices (
           user_id,
           device_uuid,
           device_name,
           platform,
           app_version,
           token_prefix,
           token_hash,
           scopes,
           expires_at_utc,
           created_utc,
           updated_utc
         ) VALUES (
           :userId,
           :deviceUuid,
           :deviceName,
           :platform,
           :appVersion,
           :tokenPrefix,
           :tokenHash,
           :scopes,
           :expiresAtUtc,
           UTC_TIMESTAMP(),
           UTC_TIMESTAMP()
         )",
        {
          userId = { value = val(qCode.user_id[1]), cfsqltype = "cf_sql_integer" },
          deviceUuid = { value = deviceValidation.deviceUuid, cfsqltype = "cf_sql_varchar", null = !len(deviceValidation.deviceUuid) },
          deviceName = { value = deviceValidation.deviceName, cfsqltype = "cf_sql_varchar", null = !len(deviceValidation.deviceName) },
          platform = { value = deviceValidation.platform, cfsqltype = "cf_sql_varchar", null = !len(deviceValidation.platform) },
          appVersion = { value = deviceValidation.appVersion, cfsqltype = "cf_sql_varchar", null = !len(deviceValidation.appVersion) },
          tokenPrefix = { value = tokenPrefix, cfsqltype = "cf_sql_varchar" },
          tokenHash = { value = tokenHash, cfsqltype = "cf_sql_char" },
          scopes = { value = variables.defaultScopes, cfsqltype = "cf_sql_varchar" },
          expiresAtUtc = { value = expiresAtUtc, cfsqltype = "cf_sql_timestamp" }
        },
        { datasource = variables.datasource }
      );

      qDevice = queryExecute(
        "SELECT *
         FROM companion_devices
         WHERE token_hash = :tokenHash
         LIMIT 1",
        {
          tokenHash = { value = tokenHash, cfsqltype = "cf_sql_char" }
        },
        { datasource = variables.datasource }
      );

      if (qDevice.recordCount EQ 0) {
        return errorResponse("DEVICE_CREATE_FAILED", "Unable to create companion device.", false);
      }

      deviceId = val(qDevice.id[1]);

      queryExecute(
        "UPDATE companion_pairing_codes
         SET used_at_utc = UTC_TIMESTAMP(),
             used_by_device_id = :deviceId,
             updated_utc = UTC_TIMESTAMP()
         WHERE id = :codeId
           AND used_at_utc IS NULL
           AND used_by_device_id IS NULL
           AND revoked_at_utc IS NULL
           AND expires_at_utc > UTC_TIMESTAMP()",
        {
          codeId = { value = val(qCode.id[1]), cfsqltype = "cf_sql_bigint" },
          deviceId = { value = deviceId, cfsqltype = "cf_sql_bigint" }
        },
        { datasource = variables.datasource }
      );

      qUsed = queryExecute(
        "SELECT used_by_device_id
         FROM companion_pairing_codes
         WHERE id = :codeId
         LIMIT 1",
        {
          codeId = { value = val(qCode.id[1]), cfsqltype = "cf_sql_bigint" }
        },
        { datasource = variables.datasource }
      );

      if (qUsed.recordCount EQ 0 OR !hasQueryValue(qUsed.used_by_device_id[1]) OR val(qUsed.used_by_device_id[1]) NEQ deviceId) {
        revokeDeviceById(deviceId, val(qCode.user_id[1]), "pairing code reuse guard");
        return errorResponse("PAIRING_CODE_USED", "Pairing code has already been used.", false);
      }

      return {
        "SUCCESS" = true,
        "success" = true,
        "AUTH" = true,
        "TOKEN" = rawToken,
        "token" = rawToken,
        "TOKEN_TYPE" = "Bearer",
        "tokenType" = "Bearer",
        "SCOPES" = variables.defaultScopes,
        "scopes" = variables.defaultScopes,
        "EXPIRES_AT_UTC" = formatUtcDate(qDevice.expires_at_utc[1]),
        "expiresAtUtc" = formatUtcDate(qDevice.expires_at_utc[1]),
        "DEVICE" = deviceRowToStruct(qDevice),
        "device" = deviceRowToStruct(qDevice)
      };
    </cfscript>
  </cffunction>

  <cffunction name="resolveBearerToken" access="public" returntype="struct" output="false">
    <cfargument name="authorizationHeader" type="string" required="true">
    <cfargument name="requiredScope" type="string" required="false" default="">
    <cfscript>
      var headerValue = trim(arguments.authorizationHeader);
      var rawToken = "";
      var tokenPrefix = "";
      var tokenHash = "";
      var qDevice = {};

      if (!len(headerValue)) {
        return errorResponse("TOKEN_MISSING", "Companion token is required.", false);
      }

      if (compareNoCase(left(headerValue, 7), "Bearer ") NEQ 0) {
        return errorResponse("TOKEN_INVALID", "Companion token is invalid.", false);
      }

      rawToken = trim(right(headerValue, len(headerValue) - 7));
      if (!len(rawToken) OR find(".", rawToken) LTE 1) {
        return errorResponse("TOKEN_INVALID", "Companion token is invalid.", false);
      }

      tokenPrefix = listFirst(rawToken, ".");
      tokenHash = hashSecret(rawToken);
      qDevice = loadDeviceByToken(tokenPrefix, tokenHash);

      if (qDevice.recordCount EQ 0) {
        return errorResponse("TOKEN_INVALID", "Companion token is invalid.", false);
      }

      if (hasQueryValue(qDevice.revoked_at_utc[1])) {
        return errorResponse("TOKEN_REVOKED", "Companion token has been revoked.", false);
      }

      if (val(qDevice.is_expired[1]) EQ 1 OR val(qDevice.is_inactive_expired[1]) EQ 1) {
        return errorResponse("TOKEN_EXPIRED", "Companion token has expired.", false);
      }

      if (len(arguments.requiredScope) AND listFindNoCase(toString(qDevice.scopes[1]), arguments.requiredScope) EQ 0) {
        return errorResponse("COMPANION_SCOPE_DENIED", "Companion token is not allowed for this action.", false);
      }

      markDeviceUsed(val(qDevice.id[1]));

      return {
        "SUCCESS" = true,
        "success" = true,
        "AUTH" = true,
        "authMode" = "token",
        "userId" = val(qDevice.user_id[1]),
        "USERID" = val(qDevice.user_id[1]),
        "companionDeviceId" = val(qDevice.id[1]),
        "DEVICE_ID" = val(qDevice.id[1]),
        "tokenPrefix" = toString(qDevice.token_prefix[1]),
        "deviceUuid" = hasQueryValue(qDevice.device_uuid[1]) ? toString(qDevice.device_uuid[1]) : "",
        "devicePlatform" = hasQueryValue(qDevice.platform[1]) ? toString(qDevice.platform[1]) : "",
        "appVersion" = hasQueryValue(qDevice.app_version[1]) ? toString(qDevice.app_version[1]) : "",
        "scopes" = toString(qDevice.scopes[1])
      };
    </cfscript>
  </cffunction>

  <cffunction name="listDevices" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var qDevices = {};
      var devices = [];
      var i = 0;

      if (arguments.userId LTE 0) {
        return errorResponse("NOT_LOGGED_IN", "Not logged in.", false);
      }

      qDevices = queryExecute(
        "SELECT *
         FROM companion_devices
         WHERE user_id = :userId
         ORDER BY created_utc DESC, id DESC",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );

      for (i = 1; i LTE qDevices.recordCount; i++) {
        arrayAppend(devices, deviceRowToStruct(qDevices, i));
      }

      return {
        "SUCCESS" = true,
        "success" = true,
        "AUTH" = true,
        "DEVICES" = devices,
        "devices" = devices
      };
    </cfscript>
  </cffunction>

  <cffunction name="revokeDevice" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="deviceId" type="numeric" required="true">
    <cfargument name="reason" type="string" required="false" default="web revoke">
    <cfscript>
      var qDevice = {};

      if (arguments.userId LTE 0) {
        return errorResponse("NOT_LOGGED_IN", "Not logged in.", false);
      }

      qDevice = queryExecute(
        "SELECT id
         FROM companion_devices
         WHERE id = :deviceId
           AND user_id = :userId
         LIMIT 1",
        {
          deviceId = { value = arguments.deviceId, cfsqltype = "cf_sql_bigint" },
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );

      if (qDevice.recordCount EQ 0) {
        return errorResponse("DEVICE_NOT_FOUND", "Companion device was not found.", true);
      }

      revokeDeviceById(arguments.deviceId, arguments.userId, arguments.reason);

      return {
        "SUCCESS" = true,
        "success" = true,
        "AUTH" = true,
        "DEVICE_ID" = arguments.deviceId,
        "deviceId" = arguments.deviceId
      };
    </cfscript>
  </cffunction>

  <cffunction name="revokeCurrent" access="public" returntype="struct" output="false">
    <cfargument name="authContext" type="struct" required="true">
    <cfargument name="reason" type="string" required="false" default="app logout">
    <cfscript>
      if (!isStruct(arguments.authContext) OR !structKeyExists(arguments.authContext, "companionDeviceId") OR val(arguments.authContext.companionDeviceId) LTE 0) {
        return errorResponse("TOKEN_INVALID", "Companion token is invalid.", false);
      }

      revokeDeviceById(val(arguments.authContext.companionDeviceId), val(arguments.authContext.userId), arguments.reason);

      return {
        "SUCCESS" = true,
        "success" = true,
        "AUTH" = true
      };
    </cfscript>
  </cffunction>

  <cffunction name="loadPairingCodeByHash" access="private" returntype="query" output="false">
    <cfargument name="codeHash" type="string" required="true">
    <cfscript>
      return queryExecute(
        "SELECT *,
                CASE WHEN expires_at_utc <= UTC_TIMESTAMP() THEN 1 ELSE 0 END AS is_expired
         FROM companion_pairing_codes
         WHERE code_hash = :codeHash
         LIMIT 1",
        {
          codeHash = { value = arguments.codeHash, cfsqltype = "cf_sql_char" }
        },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="loadDeviceByToken" access="private" returntype="query" output="false">
    <cfargument name="tokenPrefix" type="string" required="true">
    <cfargument name="tokenHash" type="string" required="true">
    <cfscript>
      return queryExecute(
        "SELECT *,
                CASE WHEN expires_at_utc <= UTC_TIMESTAMP() THEN 1 ELSE 0 END AS is_expired,
                CASE
                  WHEN last_used_at_utc IS NOT NULL
                   AND last_used_at_utc <= DATE_SUB(UTC_TIMESTAMP(), INTERVAL #variables.inactivityDays# DAY)
                    THEN 1
                  ELSE 0
                END AS is_inactive_expired
         FROM companion_devices
         WHERE token_prefix = :tokenPrefix
           AND token_hash = :tokenHash
         LIMIT 1",
        {
          tokenPrefix = { value = arguments.tokenPrefix, cfsqltype = "cf_sql_varchar" },
          tokenHash = { value = arguments.tokenHash, cfsqltype = "cf_sql_char" }
        },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="markDeviceUsed" access="private" returntype="void" output="false">
    <cfargument name="deviceId" type="numeric" required="true">
    <cfscript>
      queryExecute(
        "UPDATE companion_devices
         SET last_used_at_utc = UTC_TIMESTAMP(),
             updated_utc = UTC_TIMESTAMP()
         WHERE id = :deviceId",
        {
          deviceId = { value = arguments.deviceId, cfsqltype = "cf_sql_bigint" }
        },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="revokeDeviceById" access="private" returntype="void" output="false">
    <cfargument name="deviceId" type="numeric" required="true">
    <cfargument name="revokedByUserId" type="numeric" required="true">
    <cfargument name="reason" type="string" required="true">
    <cfscript>
      queryExecute(
        "UPDATE companion_devices
         SET revoked_at_utc = COALESCE(revoked_at_utc, UTC_TIMESTAMP()),
             revoked_by_user_id = :revokedByUserId,
             revoked_reason = :reason,
             updated_utc = UTC_TIMESTAMP()
         WHERE id = :deviceId",
        {
          deviceId = { value = arguments.deviceId, cfsqltype = "cf_sql_bigint" },
          revokedByUserId = { value = arguments.revokedByUserId, cfsqltype = "cf_sql_integer", null = arguments.revokedByUserId LTE 0 },
          reason = { value = left(arguments.reason, 255), cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="validateDevice" access="private" returntype="struct" output="false">
    <cfargument name="device" type="struct" required="true">
    <cfscript>
      var deviceUuid = firstNonEmpty([ readString(arguments.device, "deviceUuid"), readString(arguments.device, "device_uuid") ]);
      var deviceName = firstNonEmpty([ readString(arguments.device, "deviceName"), readString(arguments.device, "name") ]);
      var platform = firstNonEmpty([ readString(arguments.device, "platform"), readString(arguments.device, "devicePlatform") ]);
      var appVersion = firstNonEmpty([ readString(arguments.device, "appVersion"), readString(arguments.device, "app_version") ]);

      if (len(deviceUuid) GT 128) {
        return errorResponse("INVALID_DEVICE", "deviceUuid must be 128 characters or fewer.", false);
      }
      if (len(deviceName) GT 120) {
        return errorResponse("INVALID_DEVICE", "deviceName must be 120 characters or fewer.", false);
      }
      if (len(platform) GT 32) {
        return errorResponse("INVALID_DEVICE", "platform must be 32 characters or fewer.", false);
      }
      if (len(appVersion) GT 40) {
        return errorResponse("INVALID_DEVICE", "appVersion must be 40 characters or fewer.", false);
      }

      return {
        "SUCCESS" = true,
        "success" = true,
        "deviceUuid" = deviceUuid,
        "deviceName" = deviceName,
        "platform" = platform,
        "appVersion" = appVersion
      };
    </cfscript>
  </cffunction>

  <cffunction name="deviceRowToStruct" access="private" returntype="struct" output="false">
    <cfargument name="qDevice" type="query" required="true">
    <cfargument name="row" type="numeric" required="false" default="1">
    <cfscript>
      return {
        "id" = val(arguments.qDevice.id[arguments.row]),
        "userId" = val(arguments.qDevice.user_id[arguments.row]),
        "deviceUuid" = hasQueryValue(arguments.qDevice.device_uuid[arguments.row]) ? toString(arguments.qDevice.device_uuid[arguments.row]) : "",
        "deviceName" = hasQueryValue(arguments.qDevice.device_name[arguments.row]) ? toString(arguments.qDevice.device_name[arguments.row]) : "",
        "platform" = hasQueryValue(arguments.qDevice.platform[arguments.row]) ? toString(arguments.qDevice.platform[arguments.row]) : "",
        "appVersion" = hasQueryValue(arguments.qDevice.app_version[arguments.row]) ? toString(arguments.qDevice.app_version[arguments.row]) : "",
        "tokenPrefix" = toString(arguments.qDevice.token_prefix[arguments.row]),
        "scopes" = toString(arguments.qDevice.scopes[arguments.row]),
        "expiresAtUtc" = formatUtcDate(arguments.qDevice.expires_at_utc[arguments.row]),
        "lastUsedAtUtc" = hasQueryValue(arguments.qDevice.last_used_at_utc[arguments.row]) ? formatUtcDate(arguments.qDevice.last_used_at_utc[arguments.row]) : "",
        "revokedAtUtc" = hasQueryValue(arguments.qDevice.revoked_at_utc[arguments.row]) ? formatUtcDate(arguments.qDevice.revoked_at_utc[arguments.row]) : "",
        "createdUtc" = formatUtcDate(arguments.qDevice.created_utc[arguments.row]),
        "updatedUtc" = formatUtcDate(arguments.qDevice.updated_utc[arguments.row])
      };
    </cfscript>
  </cffunction>

  <cffunction name="generateTokenPrefix" access="private" returntype="string" output="false">
    <cfscript>
      return "fpwc_" & lCase(generateRandomString(12, "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"));
    </cfscript>
  </cffunction>

  <cffunction name="generateRandomString" access="private" returntype="string" output="false">
    <cfargument name="length" type="numeric" required="true">
    <cfargument name="alphabet" type="string" required="true">
    <cfscript>
      var output = "";
      var i = 0;
      var digest = "";
      var pair = "";
      var indexValue = 0;
      for (i = 1; i LTE arguments.length; i++) {
        if (len(digest) LT 2) {
          digest &= hash(createUUID() & now() & randRange(1, 999999999), "SHA-256");
        }
        pair = left(digest, 2);
        digest = mid(digest, 3, len(digest) - 2);
        indexValue = inputBaseN(pair, 16) MOD len(arguments.alphabet);
        output &= mid(arguments.alphabet, indexValue + 1, 1);
      }
      return output;
    </cfscript>
  </cffunction>

  <cffunction name="normalizePairingCode" access="private" returntype="string" output="false">
    <cfargument name="pairingCode" type="string" required="true">
    <cfscript>
      return reReplace(ucase(trim(arguments.pairingCode)), "[^A-Z0-9]", "", "all");
    </cfscript>
  </cffunction>

  <cffunction name="formatPairingCode" access="private" returntype="string" output="false">
    <cfargument name="pairingCode" type="string" required="true">
    <cfscript>
      var normalized = normalizePairingCode(arguments.pairingCode);
      if (len(normalized) LTE 4) {
        return normalized;
      }
      return left(normalized, 4) & "-" & right(normalized, len(normalized) - 4);
    </cfscript>
  </cffunction>

  <cffunction name="hashSecret" access="private" returntype="string" output="false">
    <cfargument name="secret" type="string" required="true">
    <cfscript>
      return uCase(hash(arguments.secret, "SHA-256", "UTF-8"));
    </cfscript>
  </cffunction>

  <cffunction name="formatUtcDate" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      if (!isDate(arguments.value)) {
        return "";
      }
      return dateTimeFormat(arguments.value, "yyyy-mm-dd'T'HH:nn:ss'Z'");
    </cfscript>
  </cffunction>

  <cffunction name="readString" access="private" returntype="string" output="false">
    <cfargument name="source" type="any" required="true">
    <cfargument name="key" type="string" required="true">
    <cfargument name="fallback" type="string" required="false" default="">
    <cfscript>
      if (!isStruct(arguments.source) OR !structKeyExists(arguments.source, arguments.key) OR isNull(arguments.source[arguments.key])) {
        return arguments.fallback;
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

  <cffunction name="hasQueryValue" access="private" returntype="boolean" output="false">
    <cfargument name="value" required="false">
    <cfscript>
      if (!structKeyExists(arguments, "value") OR isNull(arguments.value)) {
        return false;
      }
      return len(trim(toString(arguments.value))) GT 0;
    </cfscript>
  </cffunction>

  <cffunction name="errorResponse" access="private" returntype="struct" output="false">
    <cfargument name="errorCode" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfargument name="auth" type="boolean" required="false" default="false">
    <cfscript>
      return {
        "SUCCESS" = false,
        "success" = false,
        "AUTH" = arguments.auth,
        "ERROR" = arguments.errorCode,
        "MESSAGE" = arguments.message
      };
    </cfscript>
  </cffunction>

</cfcomponent>
