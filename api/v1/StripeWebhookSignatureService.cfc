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
      var nowSeconds = arguments.nowEpochSeconds GT 0 ? arguments.nowEpochSeconds : currentEpochSeconds();
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
      if (abs(nowSeconds - timestamp) GT arguments.toleranceSeconds) {
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
      var ts = arguments.timestamp GT 0 ? arguments.timestamp : currentEpochSeconds();
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
      var mac = createObject("java", "javax.crypto.Mac").getInstance("HmacSHA256");
      var keySpec = createObject("java", "javax.crypto.spec.SecretKeySpec")
        .init(charsetDecode(arguments.secret, "utf-8"), "HmacSHA256");
      var digest = "";
      mac.init(keySpec);
      digest = mac.doFinal(charsetDecode(arguments.message, "utf-8"));
      return lCase(binaryEncode(digest, "hex"));
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

  <cffunction name="currentEpochSeconds" access="private" returntype="numeric" output="false">
    <cfscript>
      return int(createObject("java", "java.lang.System").currentTimeMillis() / 1000);
    </cfscript>
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
