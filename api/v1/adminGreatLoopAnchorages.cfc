<cfcomponent output="false" hint="Admin Great Loop anchorage management API.">

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfargument name="action" type="string" required="false" default="">
        <cfargument name="id" type="string" required="false" default="">
        <cfargument name="nonce" type="string" required="false" default="">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

        <cftry>
            <cfscript>
                var body = getBodyJson();
                var actionName = resolveAction(arguments.action, body);
                var userStruct = (structKeyExists(session, "user") AND isStruct(session.user)) ? session.user : {};
                var response = {};

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
                        response = listAnchorages(body);
                        break;
                    case "get":
                        response = getAnchorage(body);
                        break;
                    case "create":
                        response = createAnchorage(body);
                        break;
                    case "save":
                        response = saveAnchorage(body);
                        break;
                    case "delete":
                        response = deleteAnchorage(body);
                        break;
                    case "facets":
                        response = listFacets();
                        break;
                    default:
                        response = buildResponse(false, true, "Unknown action", {}, "Valid actions: list, get, create, save, delete, facets.");
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

    <cffunction name="listAnchorages" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var svc = createAnchorageService();
            var result = svc.searchAdminAnchorages(arguments.body, resolveFpwBasePath());
            if (!result.SUCCESS) {
                return buildResponse(false, true, "Unable to load anchorages", {}, structKeyExists(result, "MESSAGE") ? result.MESSAGE : "");
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

    <cffunction name="getAnchorage" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var anchorageId = trim(toString(readValue(arguments.body, "id", readValue(arguments.body, "ID", readValue(url, "id", "")))));
            var svc = createAnchorageService();
            var result = {};

            if (!len(anchorageId)) {
                return buildResponse(false, true, "Invalid anchorage", {}, "Anchorage id is required.");
            }

            result = svc.getAdminAnchorageById(anchorageId, resolveFpwBasePath());
            if (!result.SUCCESS) {
                return buildResponse(false, true, "Not found", {}, "Anchorage not found.");
            }

            return buildResponse(true, true, "OK", { "anchorage" = result.ANCHORAGE });
        </cfscript>
    </cffunction>

    <cffunction name="createAnchorage" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var nonce = trim(toString(readValue(arguments.body, "nonce", readValue(arguments.body, "NONCE", ""))));
            var anchoragePayload = extractAnchoragePayload(arguments.body);
            var svc = createAnchorageService();
            var result = {};

            if (!isValidNonce(nonce)) {
                return buildResponse(false, true, "Security check failed", {}, "The admin form expired. Reload the page and try again.");
            }

            result = svc.createAdminAnchorage(anchoragePayload, resolveFpwBasePath());
            if (!result.SUCCESS) {
                return buildResponse(false, true, "Validation failed", {
                    "errors" = structKeyExists(result, "ERRORS") ? result.ERRORS : []
                }, structKeyExists(result, "MESSAGE") ? result.MESSAGE : "Unable to create anchorage.");
            }

            return buildResponse(true, true, result.MESSAGE, { "anchorage" = result.ANCHORAGE });
        </cfscript>
    </cffunction>

    <cffunction name="saveAnchorage" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var nonce = trim(toString(readValue(arguments.body, "nonce", readValue(arguments.body, "NONCE", ""))));
            var anchoragePayload = extractAnchoragePayload(arguments.body);
            var svc = createAnchorageService();
            var result = {};

            if (!isValidNonce(nonce)) {
                return buildResponse(false, true, "Security check failed", {}, "The admin form expired. Reload the page and try again.");
            }

            result = svc.updateAdminAnchorage(anchoragePayload, resolveFpwBasePath());
            if (!result.SUCCESS) {
                return buildResponse(false, true, "Validation failed", {
                    "errors" = structKeyExists(result, "ERRORS") ? result.ERRORS : []
                }, structKeyExists(result, "MESSAGE") ? result.MESSAGE : "Unable to save anchorage.");
            }

            return buildResponse(true, true, result.MESSAGE, { "anchorage" = result.ANCHORAGE });
        </cfscript>
    </cffunction>

    <cffunction name="deleteAnchorage" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var nonce = trim(toString(readValue(arguments.body, "nonce", readValue(arguments.body, "NONCE", ""))));
            var anchorageId = trim(toString(readValue(arguments.body, "id", readValue(arguments.body, "ID", ""))));
            var confirmation = trim(toString(readValue(arguments.body, "confirmation", readValue(arguments.body, "CONFIRMATION", ""))));
            var svc = createAnchorageService();
            var result = {};

            if (!isValidNonce(nonce)) {
                return buildResponse(false, true, "Security check failed", {}, "The admin form expired. Reload the page and try again.");
            }
            if (!len(anchorageId)) {
                return buildResponse(false, true, "Invalid anchorage", {}, "Anchorage id is required.");
            }
            if (uCase(confirmation) NEQ uCase(anchorageId)) {
                return buildResponse(false, true, "Delete blocked", {}, "Type the exact anchorage id to confirm deletion.");
            }

            result = svc.deleteAdminAnchorage(anchorageId);
            if (!result.SUCCESS) {
                return buildResponse(false, true, "Delete failed", {}, structKeyExists(result, "MESSAGE") ? result.MESSAGE : "Unable to delete anchorage.");
            }

            return buildResponse(true, true, result.MESSAGE, {
                "anchorage" = result.ANCHORAGE,
                "anchorage_id" = result.ANCHORAGE_ID
            });
        </cfscript>
    </cffunction>

    <cffunction name="listFacets" access="private" returntype="struct" output="false">
        <cfscript>
            var svc = createAnchorageService();
            return buildResponse(true, true, "OK", svc.getAdminFacets());
        </cfscript>
    </cffunction>

    <cffunction name="extractAnchoragePayload" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            if (structKeyExists(arguments.body, "anchorage") AND isStruct(arguments.body.anchorage)) {
                return arguments.body.anchorage;
            }
            if (structKeyExists(arguments.body, "ANCHORAGE") AND isStruct(arguments.body.ANCHORAGE)) {
                return arguments.body.ANCHORAGE;
            }
            return arguments.body;
        </cfscript>
    </cffunction>

    <cffunction name="createAnchorageService" access="private" returntype="any" output="false">
        <cfscript>
            try {
                return createObject("component", "api.v1.GreatLoopAnchoragesService").init();
            } catch (any svcPathError) {
                return createObject("component", "fpw.api.v1.GreatLoopAnchoragesService").init();
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

            if (!structKeyExists(httpData, "content")) {
                return body;
            }

            raw = toString(httpData.content);
            if (!len(trim(raw))) {
                return body;
            }

            try {
                body = deserializeJSON(raw, false);
                if (!isStruct(body)) {
                    body = {};
                }
            } catch (any ignored) {
                body = {};
            }
            return body;
        </cfscript>
    </cffunction>

    <cffunction name="readValue" access="private" returntype="any" output="false">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfargument name="defaultValue" type="any" required="false" default="">
        <cfscript>
            if (structKeyExists(arguments.source, arguments.key)) {
                return arguments.source[arguments.key];
            }
            return arguments.defaultValue;
        </cfscript>
    </cffunction>

    <cffunction name="toBoolean" access="private" returntype="boolean" output="false">
        <cfargument name="value" type="any" required="true">
        <cfargument name="defaultValue" type="boolean" required="false" default="false">
        <cfscript>
            var txt = lCase(trim(toString(arguments.value)));
            if (!len(txt)) return arguments.defaultValue;
            if (listFindNoCase("1,true,yes,y,on", txt)) return true;
            if (listFindNoCase("0,false,no,n,off", txt)) return false;
            if (isNumeric(txt)) return (val(txt) NEQ 0);
            return arguments.defaultValue;
        </cfscript>
    </cffunction>

    <!--- Authorization is enforced centrally by Application.cfc. --->

    <cffunction name="isValidNonce" access="private" returntype="boolean" output="false">
        <cfargument name="nonce" type="string" required="true">
        <cfscript>
            return structKeyExists(session, "greatLoopAnchoragesAdminNonce")
                AND len(trim(arguments.nonce))
                AND trim(arguments.nonce) EQ session.greatLoopAnchoragesAdminNonce;
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

</cfcomponent>



