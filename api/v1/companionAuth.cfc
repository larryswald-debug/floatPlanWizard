<cfcomponent output="false">

  <cffunction name="handle" access="remote" returntype="void" output="true">
    <cfargument name="action" type="any" required="false">
    <cfsetting enablecfoutputonly="true" showdebugoutput="false">
    <cfcontent type="application/json; charset=utf-8">
    <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

    <cftry>
      <cfset var body = readJsonBody()>
      <cfset var actionName = resolveActionName(arguments, body)>
      <cfset var service = createApiComponent("CompanionAuthService").init("fpw")>
      <cfset var response = {}>
      <cfset var userId = 0>
      <cfset var authContext = {}>

      <cfswitch expression="#actionName#">
        <cfcase value="createpairingcode,create-pairing-code" delimiters=",">
          <cfset response = requireRequestMethod("POST")>
          <cfset userId = resolveSessionUserId()>
          <cfif NOT response.SUCCESS>
            <!-- method response already resolved -->
          <cfelseif userId LTE 0>
            <cfset response = notLoggedInResponse()>
          <cfelse>
            <cfset response = service.createPairingCode(userId)>
          </cfif>
          <cfoutput>#serializeJSON(response)#</cfoutput>
        </cfcase>

        <cfcase value="exchangepairingcode,exchange-pairing-code" delimiters=",">
          <cfset response = requireRequestMethod("POST")>
          <cfif response.SUCCESS>
            <cfset response = service.exchangePairingCode(resolvePairingCode(body), resolveDevicePayload(body))>
          </cfif>
          <cfoutput>#serializeJSON(response)#</cfoutput>
        </cfcase>

        <cfcase value="listdevices,list-devices" delimiters=",">
          <cfset response = requireRequestMethod("GET")>
          <cfset userId = resolveSessionUserId()>
          <cfif NOT response.SUCCESS>
            <!-- method response already resolved -->
          <cfelseif userId LTE 0>
            <cfset response = notLoggedInResponse()>
          <cfelse>
            <cfset response = service.listDevices(userId)>
          </cfif>
          <cfoutput>#serializeJSON(response)#</cfoutput>
        </cfcase>

        <cfcase value="revokedevice,revoke-device" delimiters=",">
          <cfset response = requireRequestMethod("POST")>
          <cfset userId = resolveSessionUserId()>
          <cfif NOT response.SUCCESS>
            <!-- method response already resolved -->
          <cfelseif userId LTE 0>
            <cfset response = notLoggedInResponse()>
          <cfelse>
            <cfset response = service.revokeDevice(userId, resolveNumericValue(body, "deviceId"), resolveRevokeReason(body))>
          </cfif>
          <cfoutput>#serializeJSON(response)#</cfoutput>
        </cfcase>

        <cfcase value="revokecurrent,revoke-current,logout" delimiters=",">
          <cfset response = requireRequestMethod("POST")>
          <cfset authContext = response.SUCCESS ? service.resolveBearerToken(readAuthorizationHeader()) : response>
          <cfif response.SUCCESS AND structKeyExists(authContext, "SUCCESS") AND authContext.SUCCESS>
            <cfset response = service.revokeCurrent(authContext, resolveRevokeReason(body))>
          <cfelseif response.SUCCESS>
            <cfset response = authContext>
          </cfif>
          <cfoutput>#serializeJSON(response)#</cfoutput>
        </cfcase>

        <cfdefaultcase>
          <cfset response = {
            SUCCESS = false,
            success = false,
            AUTH = (resolveSessionUserId() GT 0),
            ERROR = "INVALID_ACTION",
            MESSAGE = "Unsupported companion auth action."
          }>
          <cfoutput>#serializeJSON(response)#</cfoutput>
        </cfdefaultcase>
      </cfswitch>

      <cfcatch type="any">
        <cfset response = {
          SUCCESS = false,
          success = false,
          AUTH = (resolveSessionUserId() GT 0),
          ERROR = "SERVER_ERROR",
          MESSAGE = "Companion auth API error.",
          DETAIL = cfcatch.message
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
      </cfcatch>
    </cftry>

    <cfsetting enablecfoutputonly="false">
  </cffunction>

  <cffunction name="resolveSessionUserId" access="private" returntype="numeric" output="false">
    <cfscript>
      if (structKeyExists(session, "user") AND isStruct(session.user)) {
        if (structKeyExists(session.user, "userId") AND isNumeric(session.user.userId)) {
          return val(session.user.userId);
        }
        if (structKeyExists(session.user, "id") AND isNumeric(session.user.id)) {
          return val(session.user.id);
        }
        if (structKeyExists(session.user, "USERID") AND isNumeric(session.user.USERID)) {
          return val(session.user.USERID);
        }
      }
      return 0;
    </cfscript>
  </cffunction>

  <cffunction name="readJsonBody" access="private" returntype="struct" output="false">
    <cfscript>
      var httpData = getHttpRequestData();
      var rawBody = (structKeyExists(httpData, "content") ? toString(httpData.content) : "");
      if (!len(trim(rawBody))) {
        return {};
      }
      try {
        return deserializeJSON(rawBody);
      } catch (any parseError) {
        return {};
      }
    </cfscript>
  </cffunction>

  <cffunction name="resolveActionName" access="private" returntype="string" output="false">
    <cfargument name="remoteArguments" type="struct" required="true">
    <cfargument name="body" type="struct" required="true">
    <cfscript>
      if (structKeyExists(arguments.remoteArguments, "action") AND len(trim(toString(arguments.remoteArguments.action)))) {
        return lCase(trim(toString(arguments.remoteArguments.action)));
      }
      if (structKeyExists(url, "action") AND len(trim(toString(url.action)))) {
        return lCase(trim(toString(url.action)));
      }
      if (structKeyExists(arguments.body, "action") AND len(trim(toString(arguments.body.action)))) {
        return lCase(trim(toString(arguments.body.action)));
      }
      return "listdevices";
    </cfscript>
  </cffunction>

  <cffunction name="resolvePairingCode" access="private" returntype="string" output="false">
    <cfargument name="body" type="struct" required="true">
    <cfscript>
      return firstNonEmpty([
        readString(arguments.body, "pairingCode"),
        readString(arguments.body, "PAIRING_CODE"),
        readString(arguments.body, "code")
      ]);
    </cfscript>
  </cffunction>

  <cffunction name="resolveDevicePayload" access="private" returntype="struct" output="false">
    <cfargument name="body" type="struct" required="true">
    <cfscript>
      if (structKeyExists(arguments.body, "device") AND isStruct(arguments.body.device)) {
        return arguments.body.device;
      }
      return {
        "deviceUuid" = readString(arguments.body, "deviceUuid"),
        "deviceName" = firstNonEmpty([ readString(arguments.body, "deviceName"), readString(arguments.body, "name") ]),
        "platform" = readString(arguments.body, "platform"),
        "appVersion" = readString(arguments.body, "appVersion")
      };
    </cfscript>
  </cffunction>

  <cffunction name="resolveNumericValue" access="private" returntype="numeric" output="false">
    <cfargument name="body" type="struct" required="true">
    <cfargument name="key" type="string" required="true">
    <cfscript>
      if (structKeyExists(arguments.body, arguments.key) AND isNumeric(arguments.body[arguments.key])) {
        return val(arguments.body[arguments.key]);
      }
      if (structKeyExists(url, arguments.key) AND isNumeric(url[arguments.key])) {
        return val(url[arguments.key]);
      }
      return 0;
    </cfscript>
  </cffunction>

  <cffunction name="resolveRevokeReason" access="private" returntype="string" output="false">
    <cfargument name="body" type="struct" required="true">
    <cfscript>
      return firstNonEmpty([
        readString(arguments.body, "reason"),
        readString(arguments.body, "revokeReason")
      ]);
    </cfscript>
  </cffunction>

  <cffunction name="readAuthorizationHeader" access="private" returntype="string" output="false">
    <cfscript>
      var httpData = getHttpRequestData();
      var headers = structKeyExists(httpData, "headers") AND isStruct(httpData.headers) ? httpData.headers : {};
      return readHeader(headers, "Authorization");
    </cfscript>
  </cffunction>

  <cffunction name="requireRequestMethod" access="private" returntype="struct" output="false">
    <cfargument name="expectedMethod" type="string" required="true">
    <cfscript>
      var actualMethod = structKeyExists(cgi, "REQUEST_METHOD") ? uCase(trim(toString(cgi.REQUEST_METHOD))) : "";
      var expected = uCase(trim(arguments.expectedMethod));
      if (actualMethod EQ expected) {
        return {
          SUCCESS = true,
          success = true,
          AUTH = (resolveSessionUserId() GT 0)
        };
      }
      return {
        SUCCESS = false,
        success = false,
        AUTH = (resolveSessionUserId() GT 0),
        ERROR = "METHOD_NOT_ALLOWED",
        MESSAGE = "Use " & expected & " for this companion auth action."
      };
    </cfscript>
  </cffunction>

  <cffunction name="readHeader" access="private" returntype="string" output="false">
    <cfargument name="headers" type="struct" required="true">
    <cfargument name="headerName" type="string" required="true">
    <cfscript>
      var key = "";
      for (key in arguments.headers) {
        if (compareNoCase(key, arguments.headerName) EQ 0) {
          return trim(toString(arguments.headers[key]));
        }
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="notLoggedInResponse" access="private" returntype="struct" output="false">
    <cfscript>
      return {
        SUCCESS = false,
        success = false,
        AUTH = false,
        ERROR = "NOT_LOGGED_IN",
        MESSAGE = "Not logged in."
      };
    </cfscript>
  </cffunction>

  <cffunction name="createApiComponent" access="private" returntype="any" output="false">
    <cfargument name="componentName" type="string" required="true">
    <cfscript>
      try {
        return createObject("component", "fpw.api.v1." & arguments.componentName);
      } catch (any primaryError) {
        return createObject("component", "api.v1." & arguments.componentName);
      }
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

</cfcomponent>
