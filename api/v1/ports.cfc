<cfcomponent output="false" hint="Public Great Loop ports library JSON API.">

  <cffunction name="handle" access="remote" returntype="void" output="true">
    <cfargument name="action" type="string" required="false" default="">
    <cfargument name="id" type="string" required="false" default="">
    <cfargument name="slug" type="string" required="false" default="">
    <cfargument name="q" type="string" required="false" default="">
    <cfargument name="state" type="string" required="false" default="">
    <cfargument name="stateCode" type="string" required="false" default="">
    <cfargument name="country" type="string" required="false" default="">
    <cfargument name="loopSegment" type="string" required="false" default="">
    <cfargument name="waterway" type="string" required="false" default="">
    <cfargument name="tag" type="string" required="false" default="">
    <cfargument name="major" type="string" required="false" default="">
    <cfargument name="hiddenGem" type="string" required="false" default="">
    <cfargument name="qualityStatus" type="string" required="false" default="">
    <cfargument name="mapReady" type="string" required="false" default="">
    <cfsetting enablecfoutputonly="true" showdebugoutput="false">
    <cfcontent type="application/json; charset=utf-8">
    <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

    <cftry>
      <cfscript>
        var body = getBodyJson();
        var actionName = resolveAction(arguments.action, body);
        var filters = readFilters(body);
        var portsSvc = createPortsService();
        var response = {};
        var portId = 0;
        var portSlug = "";

        switch (actionName) {
          case "list":
            response = portsSvc.listPorts(filters);
            break;
          case "detail":
            portId = val(readRequestValue(body, [ "id", "ID" ], arguments.id));
            portSlug = readRequestValue(body, [ "slug", "SLUG" ], arguments.slug);
            if (portId GT 0) {
              response = portsSvc.getPortById(portId);
            } else if (len(portSlug)) {
              response = portsSvc.getPortBySlug(portSlug);
            } else {
              response = buildErrorResponse("VALIDATION", "Port id or slug is required.");
            }
            break;
          case "filters":
            response = portsSvc.getFilters();
            break;
          case "quality":
            response = portsSvc.getQualitySummary();
            break;
          default:
            response = buildErrorResponse("INVALID_ACTION", "Valid actions: list, detail, filters, quality.");
        }

        writeOutput(serializeJSON(response));
      </cfscript>

      <cfcatch type="any">
        <cfoutput>#serializeJSON(buildErrorResponse("SERVER_ERROR", "Ports API error."))#</cfoutput>
      </cfcatch>
    </cftry>

    <cfsetting enablecfoutputonly="false">
  </cffunction>

  <cffunction name="resolveAction" access="private" returntype="string" output="false">
    <cfargument name="actionArg" type="any" required="false" default="">
    <cfargument name="body" type="struct" required="true">
    <cfscript>
      var actionName = lCase(trim(toString(arguments.actionArg)));
      if (!len(actionName) AND structKeyExists(url, "action") AND !isNull(url.action)) {
        actionName = lCase(trim(toString(url.action)));
      }
      if (!len(actionName) AND structKeyExists(arguments.body, "action") AND !isNull(arguments.body.action)) {
        actionName = lCase(trim(toString(arguments.body.action)));
      }
      if (!len(actionName) AND structKeyExists(arguments.body, "ACTION") AND !isNull(arguments.body.ACTION)) {
        actionName = lCase(trim(toString(arguments.body.ACTION)));
      }
      return actionName;
    </cfscript>
  </cffunction>

  <cffunction name="readFilters" access="private" returntype="struct" output="false">
    <cfargument name="body" type="struct" required="true">
    <cfscript>
      var filters = {};
      filters.q = readRequestValue(arguments.body, [ "q", "Q" ]);
      filters.state = readRequestValue(arguments.body, [ "state", "STATE" ]);
      filters.stateCode = readRequestValue(arguments.body, [ "stateCode", "state_code", "STATECODE" ]);
      filters.country = readRequestValue(arguments.body, [ "country", "COUNTRY" ]);
      filters.loopSegment = readRequestValue(arguments.body, [ "loopSegment", "loop_segment", "LOOPSEGMENT" ]);
      filters.waterway = readRequestValue(arguments.body, [ "waterway", "WATERWAY" ]);
      filters.tag = readRequestValue(arguments.body, [ "tag", "TAG" ]);
      filters.major = readRequestValue(arguments.body, [ "major", "MAJOR" ]);
      filters.hiddenGem = readRequestValue(arguments.body, [ "hiddenGem", "hidden_gem", "HIDDENGEM" ]);
      filters.qualityStatus = readRequestValue(arguments.body, [ "qualityStatus", "quality_status", "QUALITYSTATUS" ]);
      filters.mapReady = readRequestValue(arguments.body, [ "mapReady", "map_ready", "MAPREADY" ]);
      return filters;
    </cfscript>
  </cffunction>

  <cffunction name="readRequestValue" access="private" returntype="string" output="false">
    <cfargument name="body" type="struct" required="true">
    <cfargument name="keys" type="array" required="true">
    <cfargument name="defaultValue" type="string" required="false" default="">
    <cfscript>
      var i = 0;
      var keyName = "";

      for (i = 1; i LTE arrayLen(arguments.keys); i++) {
        keyName = arguments.keys[i];
        if (structKeyExists(url, keyName) AND !isNull(url[keyName])) {
          return trim(toString(url[keyName]));
        }
      }

      for (i = 1; i LTE arrayLen(arguments.keys); i++) {
        keyName = arguments.keys[i];
        if (structKeyExists(arguments.body, keyName) AND !isNull(arguments.body[keyName])) {
          return trim(toString(arguments.body[keyName]));
        }
      }

      return trim(toString(arguments.defaultValue));
    </cfscript>
  </cffunction>

  <cffunction name="getBodyJson" access="private" returntype="struct" output="false">
    <cfscript>
      var httpData = getHttpRequestData();
      var rawBody = toString(httpData.content);
      var body = {};

      if (len(trim(rawBody))) {
        try {
          body = deserializeJSON(rawBody, false);
          if (!isStruct(body)) {
            body = {};
          }
        } catch (any parseError) {
          body = {};
        }
      }

      return body;
    </cfscript>
  </cffunction>

  <cffunction name="createPortsService" access="private" returntype="any" output="false">
    <cfscript>
      try {
        return createObject("component", "api.v1.PortsLibraryService").init();
      } catch (any svcPathError) {
        return createObject("component", "fpw.api.v1.PortsLibraryService").init();
      }
    </cfscript>
  </cffunction>

  <cffunction name="buildErrorResponse" access="private" returntype="struct" output="false">
    <cfargument name="errorCode" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfscript>
      var response = structNew("ordered");
      response["SUCCESS"] = false;
      response["AUTH"] = true;
      response["ERROR"] = arguments.errorCode;
      response["MESSAGE"] = arguments.message;
      return response;
    </cfscript>
  </cffunction>

</cfcomponent>
