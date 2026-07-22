<cfcomponent output="false" hint="Admin Great Loop ports management API.">

  <cffunction name="handle" access="remote" returntype="void" output="true">
    <cfargument name="action" type="string" required="false" default="">
    <cfargument name="id" type="string" required="false" default="">
    <cfargument name="portId" type="string" required="false" default="">
    <cfargument name="nonce" type="string" required="false" default="">
    <cfargument name="imageFile" type="any" required="false" default="">
    <cfsetting enablecfoutputonly="true" showdebugoutput="false">
    <cfcontent type="application/json; charset=utf-8">
    <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

    <cftry>
      <cfscript>
        var isMultipart = isMultipartRequest();
        var body = isMultipart ? {} : getBodyJson();
        var actionName = "";
        var userStruct = (structKeyExists(session, "user") AND isStruct(session.user)) ? session.user : {};
        var response = {};

        if (len(trim(toString(arguments.portId))) AND !structKeyExists(body, "portId") AND !structKeyExists(body, "id")) {
          body.portId = trim(toString(arguments.portId));
        }
        actionName = resolveAction(arguments.action, body);

        if (!structCount(userStruct)) {
          response = buildResponse(false, false, "Unauthorized", {}, "Authentication is required.");
          writeOutput(serializeJSON(response));
          return;
        }

        if (!structKeyExists(request, "fpwAdminAuthorization") OR request.fpwAdminAuthorization.authorized NEQ true) {
          response = buildResponse(false, true, "Forbidden", {}, "Admin privileges are required.");
          writeOutput(serializeJSON(response));
          return;
        }

        switch (actionName) {
          case "list":
            response = listPorts(body);
            break;
          case "get":
            response = getPort(body);
            break;
          case "save":
            response = savePort(body);
            break;
          case "uploadimage":
            response = uploadImage();
            break;
          case "deleteimage":
            response = deleteImage(body);
            break;
          case "delete":
            response = deletePort(body);
            break;
          case "facets":
            response = listFacets();
            break;
          default:
            response = buildResponse(false, true, "Unknown action", {}, "Valid actions: list, get, save, uploadImage, deleteImage, delete, facets.");
        }

        writeOutput(serializeJSON(response));
      </cfscript>

      <cfcatch type="any">
        <cfset var isAuth = structKeyExists(session, "user") AND isStruct(session.user)>
        <cfoutput>#serializeJSON(buildResponse(false, isAuth, "Application error", {}, cfcatch.message, cfcatch.detail))#</cfoutput>
      </cfcatch>
    </cftry>

    <cfsetting enablecfoutputonly="false">
  </cffunction>

  <cffunction name="listPorts" access="private" returntype="struct" output="false">
    <cfargument name="body" type="struct" required="true">
    <cfscript>
      var svc = createPortService();
      var result = svc.searchAdminPorts(arguments.body, resolveFpwBasePath());
      if (!result.SUCCESS) {
        return buildResponse(false, true, "Unable to load ports", {}, structKeyExists(result, "MESSAGE") ? result.MESSAGE : "");
      }
      return buildResponse(true, true, "OK", {
        "items" = result.ROWS,
        "total" = result.TOTAL,
        "limit" = result.LIMIT,
        "offset" = result.OFFSET,
        "filters" = result.FILTERS
      });
    </cfscript>
  </cffunction>

  <cffunction name="getPort" access="private" returntype="struct" output="false">
    <cfargument name="body" type="struct" required="true">
    <cfscript>
      var portId = toInt(readValue(arguments.body, "id", readValue(arguments.body, "ID", readValue(arguments.body, "portId", readValue(arguments.body, "PORTID", readValue(arguments, "portId", readValue(url, "id", readValue(url, "portId", 0))))))));
      var svc = createPortService();
      var result = {};

      if (portId LTE 0) {
        return buildResponse(false, true, "Invalid port", {}, "Port id is required.");
      }

      result = svc.getPortById(portId, resolveFpwBasePath());
      if (!result.SUCCESS) {
        return buildResponse(false, true, "Not found", {}, "Port not found.");
      }
      return buildResponse(true, true, "OK", { "port" = result.PORT });
    </cfscript>
  </cffunction>

  <cffunction name="savePort" access="private" returntype="struct" output="false">
    <cfargument name="body" type="struct" required="true">
    <cfscript>
      var nonce = trim(toString(readValue(arguments.body, "nonce", readValue(arguments.body, "NONCE", ""))));
      var portPayload = {};
      var svc = createPortService();
      var result = {};

      if (!isValidNonce(nonce)) {
        return buildResponse(false, true, "Security check failed", {}, "The admin form expired. Reload the page and try again.");
      }

      if (structKeyExists(arguments.body, "port") AND isStruct(arguments.body.port)) {
        portPayload = arguments.body.port;
      } else if (structKeyExists(arguments.body, "PORT") AND isStruct(arguments.body.PORT)) {
        portPayload = arguments.body.PORT;
      } else {
        portPayload = arguments.body;
      }

      result = svc.updatePort(portPayload, resolveFpwBasePath());
      if (!result.SUCCESS) {
        return buildResponse(false, true, "Validation failed", {
          "errors" = structKeyExists(result, "ERRORS") ? result.ERRORS : []
        }, structKeyExists(result, "MESSAGE") ? result.MESSAGE : "Unable to save port.");
      }

      return buildResponse(true, true, result.MESSAGE, { "port" = result.PORT });
    </cfscript>
  </cffunction>

  <cffunction name="uploadImage" access="private" returntype="struct" output="false">
    <cfscript>
      var nonce = structKeyExists(form, "nonce") ? trim(toString(form.nonce)) : "";
      var portId = structKeyExists(form, "id") ? toInt(form.id) : 0;
      var maxUploadBytes = 8 * 1024 * 1024;
      var uploadPath = "";
      var originalName = "";
      var ext = "";
      var uploadSize = 0;
      var uploadInfo = {};
      var svc = createPortService();
      var result = {};

      if (!isValidNonce(nonce)) {
        return buildResponse(false, true, "Security check failed", {}, "The admin form expired. Reload the page and try again.");
      }
      if (portId LTE 0) {
        return buildResponse(false, true, "Invalid port", {}, "Port id is required.");
      }
    </cfscript>

    <cftry>
      <cffile action="upload" filefield="imageFile" destination="#getTempDirectory()#" nameconflict="makeunique" result="uploadResult">
      <cfscript>
        uploadPath = replace(uploadResult.serverDirectory, "\", "/", "all") & "/" & uploadResult.serverFile;
        originalName = structKeyExists(uploadResult, "clientFile") ? uploadResult.clientFile : uploadResult.serverFile;
        ext = lCase(trim(listLast(originalName, ".")));
        uploadSize = (structKeyExists(uploadResult, "fileSize") AND isNumeric(uploadResult.fileSize)) ? val(uploadResult.fileSize) : 0;
        try {
          uploadInfo = getFileInfo(uploadPath);
          uploadSize = uploadSize GT 0 ? uploadSize : val(uploadInfo.size);
        } catch (any ignored) {
        }

        if (!listFindNoCase("jpg,jpeg,png,webp", ext)) {
          safeDelete(uploadPath);
          return buildResponse(false, true, "Upload rejected", {}, "Use a JPG, PNG, or WEBP image.");
        }
        if (uploadSize GT maxUploadBytes) {
          safeDelete(uploadPath);
          return buildResponse(false, true, "Upload rejected", {}, "The image must be 8 MB or smaller.");
        }

        result = svc.saveUploadedPortImage(portId, uploadPath, originalName, resolveFpwBasePath());
        safeDelete(uploadPath);

        if (!result.SUCCESS) {
          return buildResponse(false, true, "Upload failed", {}, result.MESSAGE);
        }
        return buildResponse(true, true, result.MESSAGE, {
          "port" = result.PORT,
          "image" = result.IMAGE
        });
      </cfscript>
      <cfcatch type="any">
        <cfscript>
          safeDelete(uploadPath);
          return buildResponse(false, true, "Upload failed", {}, "The image could not be uploaded.");
        </cfscript>
      </cfcatch>
    </cftry>
  </cffunction>

  <cffunction name="deleteImage" access="private" returntype="struct" output="false">
    <cfargument name="body" type="struct" required="true">
    <cfscript>
      var nonce = trim(toString(readValue(arguments.body, "nonce", readValue(arguments.body, "NONCE", ""))));
      var portId = toInt(readValue(arguments.body, "id", readValue(arguments.body, "ID", 0)));
      var svc = createPortService();
      var result = {};

      if (!isValidNonce(nonce)) {
        return buildResponse(false, true, "Security check failed", {}, "The admin form expired. Reload the page and try again.");
      }
      if (portId LTE 0) {
        return buildResponse(false, true, "Invalid port", {}, "Port id is required.");
      }

      result = svc.deletePortImage(portId, resolveFpwBasePath());
      if (!result.SUCCESS) {
        return buildResponse(false, true, "Delete failed", {
          "port" = structKeyExists(result, "PORT") ? result.PORT : {},
          "image" = structKeyExists(result, "IMAGE") ? result.IMAGE : {},
          "deleted" = structKeyExists(result, "DELETED") ? result.DELETED : []
        }, structKeyExists(result, "MESSAGE") ? result.MESSAGE : "Unable to delete port image.");
      }
      return buildResponse(true, true, result.MESSAGE, {
        "port" = result.PORT,
        "image" = result.IMAGE,
        "deleted" = result.DELETED
      });
    </cfscript>
  </cffunction>

  <cffunction name="deletePort" access="private" returntype="struct" output="false">
    <cfargument name="body" type="struct" required="true">
    <cfscript>
      var nonce = trim(toString(readValue(arguments.body, "nonce", readValue(arguments.body, "NONCE", ""))));
      var portId = toInt(readValue(arguments.body, "id", readValue(arguments.body, "ID", readValue(arguments.body, "portId", readValue(arguments.body, "PORTID", 0)))));
      var confirmation = trim(toString(readValue(arguments.body, "confirmation", readValue(arguments.body, "CONFIRMATION", ""))));
      var svc = createPortService();
      var result = {};

      if (!isValidNonce(nonce)) {
        return buildResponse(false, true, "Security check failed", {}, "The admin form expired. Reload the page and try again.");
      }
      if (portId LTE 0) {
        return buildResponse(false, true, "Invalid port", {}, "Port id is required.");
      }
      if (confirmation NEQ toString(portId)) {
        return buildResponse(false, true, "Delete blocked", {}, "Type the exact port id to confirm deletion.");
      }

      result = svc.deletePortById(portId, resolveFpwBasePath());
      if (!result.SUCCESS) {
        return buildResponse(false, true, "Delete failed", {
          "port" = structKeyExists(result, "PORT") ? result.PORT : {},
          "deletedFiles" = structKeyExists(result, "DELETED_FILES") ? result.DELETED_FILES : []
        }, structKeyExists(result, "MESSAGE") ? result.MESSAGE : "Unable to delete port.");
      }
      return buildResponse(true, true, result.MESSAGE, {
        "port" = result.PORT,
        "port_id" = result.PORT_ID,
        "deletedFiles" = result.DELETED_FILES
      });
    </cfscript>
  </cffunction>

  <cffunction name="listFacets" access="private" returntype="struct" output="false">
    <cfscript>
      var svc = createPortService();
      return buildResponse(true, true, "OK", svc.getAdminFacets());
    </cfscript>
  </cffunction>

  <cffunction name="createPortService" access="private" returntype="any" output="false">
    <cfscript>
      try {
        return createObject("component", "api.v1.GreatLoopPortsAdminService").init();
      } catch (any svcPathError) {
        return createObject("component", "fpw.api.v1.GreatLoopPortsAdminService").init();
      }
    </cfscript>
  </cffunction>

  <cffunction name="buildResponse" access="private" returntype="struct" output="false">
    <cfargument name="success" type="boolean" required="true">
    <cfargument name="auth" type="boolean" required="true">
    <cfargument name="message" type="string" required="true">
    <cfargument name="data" type="struct" required="false" default="#structNew()#">
    <cfargument name="errorMessage" type="string" required="false" default="">
    <cfargument name="errorDetail" type="string" required="false" default="">
    <cfscript>
      return {
        "SUCCESS" = arguments.success,
        "AUTH" = arguments.auth,
        "MESSAGE" = arguments.message,
        "DATA" = arguments.data,
        "ERROR" = {
          "MESSAGE" = arguments.errorMessage,
          "DETAIL" = arguments.errorDetail
        }
      };
    </cfscript>
  </cffunction>

  <cffunction name="resolveAction" access="private" returntype="string" output="false">
    <cfargument name="actionArg" type="string" required="true">
    <cfargument name="body" type="struct" required="true">
    <cfscript>
      var actionName = lCase(trim(arguments.actionArg));
      if (!len(actionName) AND structKeyExists(url, "action")) {
        actionName = lCase(trim(toString(url.action)));
      }
      if (!len(actionName) AND structKeyExists(arguments.body, "action")) {
        actionName = lCase(trim(toString(arguments.body.action)));
      }
      return actionName;
    </cfscript>
  </cffunction>

  <cffunction name="getBodyJson" access="private" returntype="struct" output="false">
    <cfscript>
      var body = {};
      var raw = "";
      var httpData = getHttpRequestData();
      if (!structKeyExists(httpData, "content")) return body;
      raw = toString(httpData.content);
      if (!len(trim(raw))) return body;
      try {
        body = deserializeJSON(raw, false);
        if (!isStruct(body)) body = {};
      } catch (any ignored) {
        body = {};
      }
      return body;
    </cfscript>
  </cffunction>

  <cffunction name="readValue" access="private" returntype="any" output="false">
    <cfargument name="source" type="struct" required="true">
    <cfargument name="key" type="string" required="true">
    <cfargument name="defaultValue" required="false" default="">
    <cfscript>
      if (structKeyExists(arguments.source, arguments.key)) {
        return arguments.source[arguments.key];
      }
      return arguments.defaultValue;
    </cfscript>
  </cffunction>

  <!--- Authorization is enforced centrally by Application.cfc. --->

  <cffunction name="isValidNonce" access="private" returntype="boolean" output="false">
    <cfargument name="nonce" type="string" required="true">
    <cfscript>
      return structKeyExists(session, "greatLoopPortsAdminNonce")
        AND len(trim(arguments.nonce))
        AND trim(arguments.nonce) EQ session.greatLoopPortsAdminNonce;
    </cfscript>
  </cffunction>

  <cffunction name="resolveFpwBasePath" access="private" returntype="string" output="false">
    <cfscript>
      var scriptName = "";
      var basePath = "";
      if (structKeyExists(request, "fpwBase")) return trim(toString(request.fpwBase));
      if (structKeyExists(cgi, "SCRIPT_NAME")) {
        scriptName = trim(toString(cgi.SCRIPT_NAME));
      } else if (structKeyExists(cgi, "script_name")) {
        scriptName = trim(toString(cgi.script_name));
      }
      basePath = reReplace(scriptName, "[?##].*$", "");
      basePath = replace(basePath, "\", "/", "all");
      basePath = reReplaceNoCase(basePath, "/api/v1(/.*)?$", "");
      basePath = reReplace(basePath, "/$", "");
      if (basePath EQ "/") basePath = "";
      return basePath;
    </cfscript>
  </cffunction>

  <cffunction name="isMultipartRequest" access="private" returntype="boolean" output="false">
    <cfscript>
      var contentType = "";
      if (structKeyExists(cgi, "CONTENT_TYPE")) contentType = lCase(toString(cgi.CONTENT_TYPE));
      if (!len(contentType) AND structKeyExists(cgi, "HTTP_CONTENT_TYPE")) contentType = lCase(toString(cgi.HTTP_CONTENT_TYPE));
      return findNoCase("multipart/form-data", contentType) GT 0;
    </cfscript>
  </cffunction>

  <cffunction name="safeDelete" access="private" returntype="void" output="false">
    <cfargument name="path" type="string" required="true">
    <cfscript>
      try {
        if (len(trim(arguments.path)) AND fileExists(arguments.path)) {
          fileDelete(arguments.path);
        }
      } catch (any ignored) {
      }
    </cfscript>
  </cffunction>

  <cffunction name="boolLike" access="private" returntype="boolean" output="false">
    <cfargument name="value" required="false" default="">
    <cfargument name="defaultValue" type="boolean" required="false" default="false">
    <cfscript>
      var txt = lCase(trim(toString(isNull(arguments.value) ? "" : arguments.value)));
      if (!len(txt)) return arguments.defaultValue;
      if (listFindNoCase("1,true,yes,y,on", txt)) return true;
      if (listFindNoCase("0,false,no,n,off", txt)) return false;
      if (isNumeric(txt)) return val(txt) NEQ 0;
      return arguments.defaultValue;
    </cfscript>
  </cffunction>

  <cffunction name="toInt" access="private" returntype="numeric" output="false">
    <cfargument name="value" required="false" default="0">
    <cfscript>
      if (!isNumeric(arguments.value)) return 0;
      return int(val(arguments.value));
    </cfscript>
  </cffunction>

</cfcomponent>









