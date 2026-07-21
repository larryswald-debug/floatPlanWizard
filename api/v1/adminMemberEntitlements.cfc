<cfcomponent output="false" hint="Authenticated admin member-entitlement API.">

  <cffunction name="handle" access="remote" returntype="void" output="true">
    <cfargument name="action" type="string" required="false" default="">
    <cfargument name="nonce" type="string" required="false" default="">
    <cfsetting enablecfoutputonly="true" showdebugoutput="false">
    <cfcontent type="application/json; charset=utf-8">
    <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">
    <cftry>
      <cfscript>
        var body = getBodyJson();
        var actionName = lCase(trim(len(arguments.action) ? arguments.action : toString(readValue(body, "action", ""))));
        var userStruct = (structKeyExists(session, "user") AND isStruct(session.user)) ? session.user : {};
        var response = {};
        var service = "";
        var requestNonce = len(trim(arguments.nonce)) ? trim(arguments.nonce) : trim(toString(readValue(body, "nonce", "")));
        var writeActions = "grant,extend,revoke,notes";
        var admin = {};

        if (uCase(trim(cgi.request_method)) NEQ "POST") {
          cfheader(statuscode = 405); writeOutput(serializeJSON(apiFailure(false, "METHOD_NOT_ALLOWED", "Use POST for admin entitlement requests."))); return;
        }
        if (!structCount(userStruct)) {
          cfheader(statuscode = 401); writeOutput(serializeJSON(apiFailure(false, "AUTH_REQUIRED", "Authentication is required."))); return;
        }
        if (!structKeyExists(request, "fpwAdminAuthorization") OR request.fpwAdminAuthorization.authorized NEQ true) {
          cfheader(statuscode = 403); writeOutput(serializeJSON(apiFailure(true, "FORBIDDEN", "Admin privileges are required."))); return;
        }
        if (!listFindNoCase("list,members,detail,overlap,grant,extend,revoke,notes", actionName)) {
          cfheader(statuscode = 400); writeOutput(serializeJSON(apiFailure(true, "INVALID_ACTION", "Admin entitlement action is not supported."))); return;
        }
        if (listFindNoCase(writeActions, actionName) AND !isValidNonce(requestNonce)) {
          cfheader(statuscode = 403); writeOutput(serializeJSON(apiFailure(true, "CSRF_INVALID", "The admin session token is invalid or expired. Refresh the page and try again."))); return;
        }

        admin = adminIdentity(userStruct);
        service = new fpw.api.v1.AdminMemberEntitlementService().init("fpw");
        switch (actionName) {
          case "list": response = service.listEntitlements(body); break;
          case "members": response = service.searchMembers(toString(readValue(body, "search", "")), val(readValue(body, "limit", 25))); break;
          case "detail": response = service.getMemberDetail(val(readValue(body, "userId", 0))); break;
          case "overlap": response = service.previewOverlap(val(readValue(body, "userId", 0)), readValue(body, "startsAtUtc", ""), readValue(body, "expiresAtUtc", "")); break;
          case "grant": response = service.grantEntitlement(body, admin); break;
          case "extend": response = service.extendEntitlement(val(readValue(body, "entitlementId", 0)), readValue(body, "newExpiresAtUtc", ""), toString(readValue(body, "reason", "")), admin); break;
          case "revoke": response = service.revokeEntitlement(val(readValue(body, "entitlementId", 0)), toString(readValue(body, "reason", "")), toString(readValue(body, "confirmation", "")), admin); break;
          case "notes": response = service.updateNotes(val(readValue(body, "entitlementId", 0)), toString(readValue(body, "adminNotes", "")), toString(readValue(body, "reason", "")), admin); break;
        }
        if (!response.SUCCESS) cfheader(statuscode = listFindNoCase("MEMBER_NOT_FOUND,ENTITLEMENT_NOT_FOUND", response.ERROR.CODE) ? 404 : 422);
        writeOutput(serializeJSON(response));
      </cfscript>
      <cfcatch type="any">
        <cflog file="fpw-errors" type="error" text="ADMIN_ENTITLEMENT_API_ERROR action=#encodeForHtmlAttribute(arguments.action)# message=#left(toString(cfcatch.message),500)# detail=#left(toString(cfcatch.detail),1000)#">
        <cfheader statuscode="500">
        <cfoutput>#serializeJSON(apiFailure(true, "SERVER_ERROR", "The admin entitlement request could not be completed."))#</cfoutput>
      </cfcatch>
    </cftry>
    <cfsetting enablecfoutputonly="false">
  </cffunction>

  <!--- One-time ADMIN bootstrap handler removed after the approved assignment. --->

  <!--- Additive ADMIN authorization migration applied through the approved authenticated session. --->

  <cffunction name="getBodyJson" access="private" returntype="struct" output="false">
    <cfscript>var requestData = getHttpRequestData(); var rawBody = structKeyExists(requestData, "content") ? toString(requestData.content) : ""; if (!len(trim(rawBody))) return {}; try { var parsed = deserializeJSON(rawBody, false); return isStruct(parsed) ? parsed : {}; } catch (any ignored) { return {}; }</cfscript>
  </cffunction>

  <cffunction name="isValidNonce" access="private" returntype="boolean" output="false">
    <cfargument name="nonce" type="string" required="true"><cfscript>return structKeyExists(session, "adminMemberEntitlementsNonce") AND len(trim(arguments.nonce)) AND compare(trim(arguments.nonce), trim(toString(session.adminMemberEntitlementsNonce))) EQ 0;</cfscript>
  </cffunction>

  <cffunction name="adminIdentity" access="private" returntype="struct" output="false">
    <cfargument name="userStruct" type="struct" required="true"><cfscript>return { "userId" = val(readFirst(arguments.userStruct, [ "userId", "USERID", "id", "ID" ], 0)), "email" = trim(toString(readFirst(arguments.userStruct, [ "email", "EMAIL" ], ""))) };</cfscript>
  </cffunction>

  <!--- Authorization is enforced centrally by Application.cfc. --->

  <cffunction name="apiFailure" access="private" returntype="struct" output="false">
    <cfargument name="auth" type="boolean" required="true"><cfargument name="code" type="string" required="true"><cfargument name="message" type="string" required="true"><cfscript>return { "SUCCESS" = false, "AUTH" = arguments.auth, "MESSAGE" = arguments.message, "DATA" = {}, "ERROR" = { "CODE" = arguments.code, "MESSAGE" = arguments.message } };</cfscript>
  </cffunction>

  <cffunction name="readValue" access="private" returntype="any" output="false">
    <cfargument name="source" type="struct" required="true"><cfargument name="key" type="string" required="true"><cfargument name="defaultValue" required="true"><cfscript>return structKeyExists(arguments.source, arguments.key) ? arguments.source[arguments.key] : arguments.defaultValue;</cfscript>
  </cffunction>

  <cffunction name="readFirst" access="private" returntype="any" output="false">
    <cfargument name="source" type="struct" required="true"><cfargument name="keys" type="array" required="true"><cfargument name="defaultValue" required="true"><cfscript>var i = 0; for (i = 1; i LTE arrayLen(arguments.keys); i++) if (structKeyExists(arguments.source, arguments.keys[i])) return arguments.source[arguments.keys[i]]; return arguments.defaultValue;</cfscript>
  </cffunction>

  <cffunction name="truthy" access="private" returntype="boolean" output="false">
    <cfargument name="value" required="true"><cfscript>return listFindNoCase("1,true,yes,y,on", trim(toString(arguments.value))) GT 0;</cfscript>
  </cffunction>

</cfcomponent>



















