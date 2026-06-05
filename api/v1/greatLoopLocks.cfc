<cfcomponent output="false" hint="Public Great Loop lock library JSON API.">

  <cffunction name="handle" access="remote" returntype="void" output="true">
    <cfargument name="action" type="string" required="false" default="">
    <cfargument name="q" type="string" required="false" default="">
    <cfargument name="state" type="string" required="false" default="">
    <cfargument name="waterway" type="string" required="false" default="">
    <cfargument name="lockSystem" type="string" required="false" default="">
    <cfargument name="hasVhf" type="string" required="false" default="">
    <cfargument name="hasPhone" type="string" required="false" default="">
    <cfargument name="hasNotes" type="string" required="false" default="">
    <cfsetting enablecfoutputonly="true" showdebugoutput="false">
    <cfcontent type="application/json; charset=utf-8">
    <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

    <cftry>
      <cfscript>
        var actionName = resolveAction(arguments.action);
        var filters = readFiltersFromUrl();
        var lockSvc = createLockService();
        var response = {};

        switch (actionName) {
          case "filteroptions":
            response = lockSvc.getFilterOptions(filters);
            break;
          case "locks":
            response = lockSvc.getLocksApiModel(filters, resolveFpwBasePath());
            break;
          default:
            response = buildErrorResponse("Unsupported Great Loop lock action.");
        }

        writeOutput(serializeJSON(response));
      </cfscript>

      <cfcatch type="any">
        <cfoutput>#serializeJSON(buildErrorResponse("Unable to update lock filters. Please try again."))#</cfoutput>
      </cfcatch>
    </cftry>

    <cfsetting enablecfoutputonly="false">
  </cffunction>

  <cffunction name="resolveAction" access="private" returntype="string" output="false">
    <cfargument name="actionArg" type="any" required="false" default="">
    <cfscript>
      var actionName = lCase(trim(toString(arguments.actionArg)));
      if (!len(actionName) AND structKeyExists(url, "action")) {
        actionName = lCase(trim(toString(url.action)));
      }
      return actionName;
    </cfscript>
  </cffunction>

  <cffunction name="readFiltersFromUrl" access="private" returntype="struct" output="false">
    <cfscript>
      return {
        "q" = readUrlValue("q"),
        "state" = readUrlValue("state"),
        "waterway" = readUrlValue("waterway"),
        "hasVhf" = readUrlValue("hasVhf"),
        "hasPhone" = readUrlValue("hasPhone"),
        "hasNotes" = readUrlValue("hasNotes"),
        "limit" = "300"
      };
    </cfscript>
  </cffunction>

  <cffunction name="readUrlValue" access="private" returntype="string" output="false">
    <cfargument name="keyName" type="string" required="true">
    <cfscript>
      if (structKeyExists(url, arguments.keyName) AND !isNull(url[arguments.keyName])) {
        return trim(toString(url[arguments.keyName]));
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="createLockService" access="private" returntype="any" output="false">
    <cfscript>
      try {
        return createObject("component", "api.v1.GreatLoopLocksService").init();
      } catch (any svcPathError) {
        return createObject("component", "fpw.api.v1.GreatLoopLocksService").init();
      }
    </cfscript>
  </cffunction>

  <cffunction name="resolveFpwBasePath" access="private" returntype="string" output="false">
    <cfscript>
      var basePath = "";

      if (structKeyExists(request, "fpwBase") AND !isNull(request.fpwBase)) {
        basePath = trim(toString(request.fpwBase));
      } else if (structKeyExists(cgi, "script_name")) {
        basePath = trim(toString(cgi.script_name));
      } else if (structKeyExists(cgi, "SCRIPT_NAME")) {
        basePath = trim(toString(cgi.SCRIPT_NAME));
      }

      basePath = reReplace(basePath, "[?##].*$", "");
      basePath = replace(basePath, "\", "/", "all");
      basePath = reReplaceNoCase(basePath, "/api/v1(/.*)?$", "");
      basePath = reReplace(basePath, "/$", "");

      if (basePath EQ "/") {
        basePath = "";
      }
      if (len(basePath) AND left(basePath, 1) NEQ "/") {
        basePath = "/" & basePath;
      }

      request.fpwBase = basePath;
      request.fpwApiBase = basePath & "/api/v1";
      return basePath;
    </cfscript>
  </cffunction>

  <cffunction name="buildErrorResponse" access="private" returntype="struct" output="false">
    <cfargument name="message" type="string" required="true">
    <cfscript>
      var response = structNew("ordered");
      response["success"] = false;
      response["message"] = arguments.message;
      return response;
    </cfscript>
  </cffunction>

</cfcomponent>
