<cfcomponent output="false">

  <cffunction name="handle" access="remote" returntype="void" output="true">
    <cfargument name="action" type="any" required="false">
    <cfsetting enablecfoutputonly="true" showdebugoutput="false">
    <cfcontent type="application/json; charset=utf-8">
    <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

    <cftry>
      <cfset var userId = resolveSessionUserId()>
      <cfset var body = readJsonBody()>
      <cfset var actionName = resolveActionName(arguments, body)>
      <cfset var response = {}>

      <cfif userId LTE 0>
        <cfset response = {
          SUCCESS = false,
          success = false,
          AUTH = false,
          ERROR = "NOT_LOGGED_IN",
          MESSAGE = "Not logged in."
        }>
        <cfoutput>#serializeJSON(response)#</cfoutput>
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
          AUTH = (resolveSessionUserId() GT 0),
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

</cfcomponent>
