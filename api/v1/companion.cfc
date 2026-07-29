<cfcomponent output="false">

  <cffunction name="handle" access="remote" returntype="void" output="true">
    <cfargument name="action" type="any" required="false">
    <cfsetting enablecfoutputonly="true" showdebugoutput="false">
    <cfcontent type="application/json; charset=utf-8">
    <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

    <cftry>
      <cfset var authContext = { SUCCESS = false }>
      <cfset var body = readJsonBody()>
      <cfset var actionName = resolveActionName(arguments, body)>
      <cfset authContext = resolveCompanionAuthContext(actionName)>
      <cfset var userId = authContext.SUCCESS ? val(authContext.userId) : 0>
      <cfset var response = {}>

      <cfif NOT authContext.SUCCESS>
        <cfoutput>#serializeJSON(authContext)#</cfoutput>
        <cfsetting enablecfoutputonly="false">
        <cfreturn>
      </cfif>

      <cfswitch expression="#actionName#">
        <cfcase value="current,active,getcurrent,getactive" delimiters=",">
          <cfset response = createApiComponent("CompanionViewModelService").init("fpw")
            .getCurrentActiveCompanionModel(userId)>
          <cfset response.AUTH = true>
          <cfoutput>#serializeJSON(response)#</cfoutput>
        </cfcase>

        <cfcase value="checkin">
          <cfset response = createApiComponent("CompanionCheckinService").init("fpw")
            .submitCheckin(userId, body, buildRequestContext(authContext))>
          <cfoutput>#serializeJSON(response)#</cfoutput>
        </cfcase>

        <cfdefaultcase>
          <cfset response = {
            SUCCESS = false,
            success = false,
            AUTH = true,
            ERROR = "INVALID_ACTION",
            MESSAGE = "Unsupported companion action."
          }>
          <cfoutput>#serializeJSON(response)#</cfoutput>
        </cfdefaultcase>
      </cfswitch>

      <cfcatch type="any">
        <cfset response = {
          SUCCESS = false,
          success = false,
          AUTH = (isStruct(authContext) AND structKeyExists(authContext, "SUCCESS") AND authContext.SUCCESS),
          ERROR = "SERVER_ERROR",
          MESSAGE = "Companion API error.",
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

  <cffunction name="resolveCompanionAuthContext" access="private" returntype="struct" output="false">
    <cfargument name="actionName" type="string" required="true">
    <cfscript>
      var sessionUserId = resolveSessionUserId();
      var requiredScope = resolveRequiredCompanionScope(arguments.actionName);
      var authorizationHeader = "";
      var tokenResult = {};

      if (sessionUserId GT 0) {
        return {
          SUCCESS = true,
          success = true,
          AUTH = true,
          authMode = "session",
          userId = sessionUserId,
          USERID = sessionUserId,
          scopes = ""
        };
      }

      authorizationHeader = readAuthorizationHeader();

      if (!len(requiredScope)) {
        if (len(authorizationHeader)) {
          return authErrorResponse("COMPANION_SCOPE_DENIED", "Companion token is not allowed for this action.");
        }
        return notLoggedInResponse();
      }

      if (!len(authorizationHeader)) {
        return notLoggedInResponse();
      }

      tokenResult = createApiComponent("CompanionAuthService").init("fpw")
        .resolveBearerToken(authorizationHeader, requiredScope);

      if (!structKeyExists(tokenResult, "SUCCESS") OR tokenResult.SUCCESS NEQ true) {
        return tokenResult;
      }

      return {
        SUCCESS = true,
        success = true,
        AUTH = true,
        authMode = "companion_token",
        userId = val(tokenResult.userId),
        USERID = val(tokenResult.userId),
        companionDeviceId = val(tokenResult.companionDeviceId),
        DEVICE_ID = val(tokenResult.companionDeviceId),
        tokenIdentifier = structKeyExists(tokenResult, "tokenPrefix") ? toString(tokenResult.tokenPrefix) : "",
        tokenPrefix = structKeyExists(tokenResult, "tokenPrefix") ? toString(tokenResult.tokenPrefix) : "",
        deviceUuid = structKeyExists(tokenResult, "deviceUuid") ? toString(tokenResult.deviceUuid) : "",
        devicePlatform = structKeyExists(tokenResult, "devicePlatform") ? toString(tokenResult.devicePlatform) : "",
        appVersion = structKeyExists(tokenResult, "appVersion") ? toString(tokenResult.appVersion) : "",
        scopes = structKeyExists(tokenResult, "scopes") ? toString(tokenResult.scopes) : ""
      };
    </cfscript>
  </cffunction>

  <cffunction name="resolveRequiredCompanionScope" access="private" returntype="string" output="false">
    <cfargument name="actionName" type="string" required="true">
    <cfscript>
      switch (lCase(trim(arguments.actionName))) {
        case "current":
        case "active":
        case "getcurrent":
        case "getactive":
          return "companion:current";
        case "checkin":
          return "companion:checkin";
        default:
          return "";
      }
    </cfscript>
  </cffunction>

  <cffunction name="readAuthorizationHeader" access="private" returntype="string" output="false">
    <cfscript>
      var httpData = getHttpRequestData();
      var headers = structKeyExists(httpData, "headers") AND isStruct(httpData.headers) ? httpData.headers : {};
      return readHeader(headers, "Authorization");
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

  <cffunction name="authErrorResponse" access="private" returntype="struct" output="false">
    <cfargument name="errorCode" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfscript>
      return {
        SUCCESS = false,
        success = false,
        AUTH = false,
        ERROR = arguments.errorCode,
        MESSAGE = arguments.message
      };
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
      return "current";
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

  <cffunction name="buildRequestContext" access="private" returntype="struct" output="false">
    <cfargument name="authContext" type="struct" required="false" default="#structNew()#">
    <cfscript>
      var httpData = getHttpRequestData();
      var headers = structKeyExists(httpData, "headers") AND isStruct(httpData.headers) ? httpData.headers : {};
      return {
        "baseUrl" = buildAppBaseUrl(),
        "cookieHeader" = readHeader(headers, "Cookie"),
        "testUserIdHeader" = readHeader(headers, "X-FPW-Test-UserId"),
        "authMode" = structKeyExists(arguments.authContext, "authMode") ? toString(arguments.authContext.authMode) : "",
        "companionDeviceId" = structKeyExists(arguments.authContext, "companionDeviceId") ? val(arguments.authContext.companionDeviceId) : 0
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildAppBaseUrl" access="private" returntype="string" output="false">
    <cfscript>
      var scheme = (structKeyExists(cgi, "HTTPS") AND cgi.HTTPS EQ "on") ? "https" : "http";
      var host = structKeyExists(cgi, "HTTP_HOST") ? cgi.HTTP_HOST : "localhost:8500";
      var scriptName = structKeyExists(cgi, "SCRIPT_NAME") ? cgi.SCRIPT_NAME : "/fpw/api/v1/companion.cfc";
      var marker = findNoCase("/api/v1/companion.cfc", scriptName);
      var appPath = marker GT 1 ? left(scriptName, marker - 1) : "";
      return scheme & "://" & host & appPath;
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

</cfcomponent>
