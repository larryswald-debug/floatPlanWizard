<cfcomponent output="false">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfscript>
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="verify" access="public" returntype="struct" output="false">
    <cfargument name="rawBody" type="string" required="true">
    <cfargument name="signatureHeader" type="string" required="true">
    <cfargument name="endpointSecret" type="string" required="true">
    <cfargument name="toleranceSeconds" type="numeric" required="false" default="300">
    <cfargument name="nowEpochSeconds" type="numeric" required="false" default="0">
    <cfscript>
      var parsed = parseSignatureHeader(arguments.signatureHeader);
      var timestamp = 0;
      var timestampSkewSeconds = 0;
      var serverEpochNow = 0;
      var serverNowUtc = "";
      var serverNowLocal = "";
      var expected = "";
      var signedPayload = "";
      var i = 0;

      if (!len(trim(arguments.endpointSecret))) {
        return errorResponse("STRIPE_WEBHOOK_SECRET_MISSING", "Stripe webhook secret is not configured.");
      }
      if (!parsed.SUCCESS) {
        return parsed;
      }

      timestamp = val(parsed.timestamp);
      if (timestamp LTE 0) {
        return errorResponse("STRIPE_SIGNATURE_TIMESTAMP_INVALID", "Stripe signature timestamp is invalid.");
      }

      serverEpochNow = arguments.nowEpochSeconds GT 0 ? val(arguments.nowEpochSeconds) : currentStripeTimestampSeconds();
      timestampSkewSeconds = abs(serverEpochNow - timestamp);
      serverNowUtc = dateTimeFormat(dateConvert("local2utc", now()), "yyyy-mm-dd'T'HH:nn:ss");
      serverNowLocal = dateTimeFormat(now(), "yyyy-mm-dd'T'HH:nn:ss");
      if (timestampSkewSeconds GT arguments.toleranceSeconds) {
        writeTimestampToleranceDebugLog(
          stripeTimestamp = timestamp,
          serverEpochNow = serverEpochNow,
          deltaSeconds = timestampSkewSeconds,
          toleranceSeconds = arguments.toleranceSeconds,
          serverNowUtc = serverNowUtc,
          serverNowLocal = serverNowLocal,
          signatureHeaderPresent = len(trim(arguments.signatureHeader)) GT 0,
          rawBodyLength = len(arguments.rawBody)
        );
        return errorResponse("STRIPE_SIGNATURE_TIMESTAMP_OUTSIDE_TOLERANCE", "Stripe signature timestamp is outside tolerance.");
      }

      signedPayload = toString(timestamp) & "." & arguments.rawBody;
      expected = hmacSha256Hex(signedPayload, arguments.endpointSecret);

      for (i = 1; i LTE arrayLen(parsed.signatures); i++) {
        if (secureCompare(lCase(trim(parsed.signatures[i])), expected)) {
          return {
            "SUCCESS" = true,
            "success" = true,
            "verified" = true,
            "timestamp" = timestamp
          };
        }
      }

      return errorResponse("STRIPE_SIGNATURE_INVALID", "Stripe signature is invalid.");
    </cfscript>
  </cffunction>

  <cffunction name="createTestSignatureHeader" access="public" returntype="string" output="false">
    <cfargument name="rawBody" type="string" required="true">
    <cfargument name="endpointSecret" type="string" required="true">
    <cfargument name="timestamp" type="numeric" required="false" default="0">
    <cfscript>
      var ts = arguments.timestamp GT 0 ? arguments.timestamp : currentStripeTimestampSeconds();
      var signedPayload = toString(ts) & "." & arguments.rawBody;
      return "t=" & ts & ",v1=" & hmacSha256Hex(signedPayload, arguments.endpointSecret);
    </cfscript>
  </cffunction>

  <cffunction name="parseSignatureHeader" access="private" returntype="struct" output="false">
    <cfargument name="signatureHeader" type="string" required="true">
    <cfscript>
      var parts = listToArray(arguments.signatureHeader, ",");
      var part = "";
      var key = "";
      var value = "";
      var eqAt = 0;
      var i = 0;
      var out = {
        "SUCCESS" = true,
        "success" = true,
        "timestamp" = "",
        "signatures" = []
      };

      if (!len(trim(arguments.signatureHeader))) {
        return errorResponse("STRIPE_SIGNATURE_MISSING", "Stripe-Signature header is required.");
      }

      for (i = 1; i LTE arrayLen(parts); i++) {
        part = trim(parts[i]);
        eqAt = find("=", part);
        if (eqAt LTE 1) {
          continue;
        }
        key = left(part, eqAt - 1);
        value = mid(part, eqAt + 1, len(part) - eqAt);
        if (key EQ "t") {
          out.timestamp = value;
        } else if (key EQ "v1") {
          arrayAppend(out.signatures, value);
        }
      }

      if (!len(out.timestamp) OR !arrayLen(out.signatures)) {
        return errorResponse("STRIPE_SIGNATURE_MALFORMED", "Stripe-Signature header is malformed.");
      }

      return out;
    </cfscript>
  </cffunction>

  <cffunction name="hmacSha256Hex" access="private" returntype="string" output="false">
    <cfargument name="message" type="string" required="true">
    <cfargument name="secret" type="string" required="true">
    <cfscript>
      return lCase(hmac(arguments.message, arguments.secret, "HmacSHA256", "utf-8"));
    </cfscript>
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

  <cffunction name="currentStripeTimestampSeconds" access="private" returntype="numeric" output="false">
    <cfscript>
      var epochLocal = dateConvert("utc2local", createDateTime(1970, 1, 1, 0, 0, 0));
      return dateDiff("s", epochLocal, now());
    </cfscript>
  </cffunction>

  <cffunction name="writeTimestampToleranceDebugLog" access="private" returntype="void" output="false">
    <cfargument name="stripeTimestamp" type="numeric" required="true">
    <cfargument name="serverEpochNow" type="numeric" required="true">
    <cfargument name="deltaSeconds" type="numeric" required="true">
    <cfargument name="toleranceSeconds" type="numeric" required="true">
    <cfargument name="serverNowUtc" type="string" required="true">
    <cfargument name="serverNowLocal" type="string" required="true">
    <cfargument name="signatureHeaderPresent" type="boolean" required="true">
    <cfargument name="rawBodyLength" type="numeric" required="true">
    <cfscript>
      var componentDir = replace(getDirectoryFromPath(getCurrentTemplatePath()), "\", "/", "all");
      var logDirectory = reReplace(componentDir, "/api/v1/?$", "/logs", "one");
      var logFile = logDirectory & "/stripe-webhook-debug.log";
      var logLine = "STRIPE_WEBHOOK_DEBUG stage=signature-timestamp"
        & " stripeTimestamp=" & int(val(arguments.stripeTimestamp))
        & " serverEpochNow=" & int(val(arguments.serverEpochNow))
        & " deltaSeconds=" & int(val(arguments.deltaSeconds))
        & " toleranceSeconds=" & int(val(arguments.toleranceSeconds))
        & " serverNowUtc=" & replace(replace(arguments.serverNowUtc, chr(13), "", "all"), chr(10), "", "all")
        & " serverNowLocal=" & replace(replace(arguments.serverNowLocal, chr(13), "", "all"), chr(10), "", "all")
        & " signatureHeaderPresent=" & (arguments.signatureHeaderPresent ? "true" : "false")
        & " rawBodyLength=" & int(val(arguments.rawBodyLength));
    </cfscript>
    <cftry>
      <cfif NOT directoryExists(logDirectory)>
        <cfdirectory action="create" directory="#logDirectory#">
      </cfif>
      <cffile action="append" file="#logFile#" output="#logLine#" addnewline="true" charset="utf-8">
      <cfcatch type="any">
        <cflog file="fpw-errors" type="error" text="STRIPE_WEBHOOK_TIMESTAMP_DEBUG_LOG_FAILED message=#toString(cfcatch.message)# detail=#toString(cfcatch.detail)#">
      </cfcatch>
    </cftry>
  </cffunction>

  <cffunction name="errorResponse" access="private" returntype="struct" output="false">
    <cfargument name="errorCode" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfscript>
      return {
        "SUCCESS" = false,
        "success" = false,
        "verified" = false,
        "ERROR" = arguments.errorCode,
        "errorCode" = arguments.errorCode,
        "MESSAGE" = arguments.message,
        "message" = arguments.message
      };
    </cfscript>
  </cffunction>

</cfcomponent>
