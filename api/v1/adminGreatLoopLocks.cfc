<cfcomponent output="false" hint="Admin Great Loop lock management API.">

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfargument name="action" type="string" required="false" default="">
        <cfargument name="id" type="string" required="false" default="">
        <cfargument name="nonce" type="string" required="false" default="">
        <cfargument name="imageFile" type="any" required="false" default="">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

        <cftry>
            <cfscript>
                var isMultipart = isMultipartRequest();
                var body = isMultipart ? {} : getBodyJson();
                var actionName = resolveAction(arguments.action, body);
                var userStruct = (structKeyExists(session, "user") AND isStruct(session.user)) ? session.user : {};
                var response = {};

                if (!structCount(userStruct)) {
                    response = buildResponse(false, false, "Unauthorized", {}, "Authentication is required.");
                    writeOutput(serializeJSON(response));
                    return;
                }

                if (!isAdminUser(userStruct)) {
                    response = buildResponse(false, true, "Forbidden", {}, "Admin privileges are required.");
                    writeOutput(serializeJSON(response));
                    return;
                }

                switch (actionName) {
                    case "list":
                        response = listLocks(body);
                        break;
                    case "get":
                        response = getLock(body);
                        break;
                    case "save":
                        response = saveLock(body);
                        break;
                    case "uploadimage":
                        response = uploadImage();
                        break;
                    case "deleteimage":
                        response = deleteImage(body);
                        break;
                    case "facets":
                        response = listFacets();
                        break;
                    default:
                        response = buildResponse(false, true, "Unknown action", {}, "Valid actions: list, get, save, uploadImage, deleteImage, facets.");
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

    <cffunction name="listLocks" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var svc = createLockService();
            var result = svc.searchAdminLocks(arguments.body, resolveFpwBasePath());
            if (!result.SUCCESS) {
                return buildResponse(false, true, "Unable to load locks", {}, structKeyExists(result, "MESSAGE") ? result.MESSAGE : "");
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

    <cffunction name="getLock" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var lockId = toInt(readValue(arguments.body, "id", readValue(arguments.body, "ID", readValue(url, "id", 0))));
            var svc = createLockService();
            var result = {};

            if (lockId LTE 0) {
                return buildResponse(false, true, "Invalid lock", {}, "Lock id is required.");
            }

            result = svc.getLockById(lockId, resolveFpwBasePath());
            if (!result.SUCCESS) {
                return buildResponse(false, true, "Not found", {}, "Lock not found.");
            }

            return buildResponse(true, true, "OK", { "lock" = result.LOCK });
        </cfscript>
    </cffunction>

    <cffunction name="saveLock" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var nonce = trim(toString(readValue(arguments.body, "nonce", readValue(arguments.body, "NONCE", ""))));
            var lockPayload = {};
            var svc = createLockService();
            var result = {};

            if (!isValidNonce(nonce)) {
                return buildResponse(false, true, "Security check failed", {}, "The admin form expired. Reload the page and try again.");
            }

            if (structKeyExists(arguments.body, "lock") AND isStruct(arguments.body.lock)) {
                lockPayload = arguments.body.lock;
            } else if (structKeyExists(arguments.body, "LOCK") AND isStruct(arguments.body.LOCK)) {
                lockPayload = arguments.body.LOCK;
            } else {
                lockPayload = arguments.body;
            }

            result = svc.updateLock(lockPayload, resolveFpwBasePath());
            if (!result.SUCCESS) {
                return buildResponse(false, true, "Validation failed", {
                    "errors" = structKeyExists(result, "ERRORS") ? result.ERRORS : []
                }, structKeyExists(result, "MESSAGE") ? result.MESSAGE : "Unable to save lock.");
            }

            return buildResponse(true, true, result.MESSAGE, {
                "lock" = result.LOCK,
                "warnings" = structKeyExists(result, "WARNINGS") ? result.WARNINGS : []
            });
        </cfscript>
    </cffunction>

    <cffunction name="uploadImage" access="private" returntype="struct" output="false">
        <cfscript>
            var nonce = structKeyExists(form, "nonce") ? trim(toString(form.nonce)) : "";
            var lockId = structKeyExists(form, "id") ? toInt(form.id) : 0;
            var maxUploadBytes = 8 * 1024 * 1024;
            var uploadPath = "";
            var originalName = "";
            var ext = "";
            var uploadSize = 0;
            var uploadTempDirectory = "";
            var svc = createLockService();
            var result = {};

            if (!isValidNonce(nonce)) {
                return buildResponse(false, true, "Security check failed", {}, "The admin form expired. Reload the page and try again.");
            }
            if (lockId LTE 0) {
                return buildResponse(false, true, "Invalid lock", {}, "Lock id is required.");
            }
        </cfscript>

        <cftry>
            <cfset uploadTempDirectory = getLockUploadTempDirectory()>
            <cffile action="upload" filefield="imageFile" destination="#uploadTempDirectory#" nameconflict="makeunique" result="uploadResult">
            <cfscript>
                uploadPath = uploadResult.serverDirectory & "/" & uploadResult.serverFile;
                originalName = structKeyExists(uploadResult, "clientFile") ? uploadResult.clientFile : uploadResult.serverFile;
                ext = lCase(trim(listLast(originalName, ".")));
                uploadSize = (structKeyExists(uploadResult, "fileSize") AND isNumeric(uploadResult.fileSize)) ? val(uploadResult.fileSize) : 0;

                if (!listFindNoCase("jpg,jpeg,png,webp", ext)) {
                    safeDelete(uploadPath);
                    return buildResponse(false, true, "Upload rejected", {}, "Use a JPG, PNG, or WEBP image.");
                }
                if (uploadSize GT maxUploadBytes) {
                    safeDelete(uploadPath);
                    return buildResponse(false, true, "Upload rejected", {}, "The image must be 8 MB or smaller.");
                }

                result = svc.saveUploadedLockImage(lockId, uploadPath, originalName, resolveFpwBasePath());
                safeDelete(uploadPath);

                if (!result.SUCCESS) {
                    return buildResponse(false, true, "Upload failed", {}, result.MESSAGE);
                }

                return buildResponse(true, true, result.MESSAGE, {
                    "lock" = result.LOCK,
                    "image" = result.IMAGE
                });
            </cfscript>
            <cfcatch type="any">
                <cfscript>
                    try {
                        var logDirectory = getDirectoryFromPath(getCurrentTemplatePath()) & "../../logs";
                        var logFile = logDirectory & "/fpw-lock-image-upload.log";
                        var logLine = "FPW_LOCK_IMAGE_UPLOAD_ERROR"
                            & " ts=" & dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss")
                            & " method=" & (structKeyExists(cgi, "REQUEST_METHOD") ? replace(toString(cgi.REQUEST_METHOD), chr(10), " ", "all") : "-")
                            & " scriptName=" & (structKeyExists(cgi, "SCRIPT_NAME") ? replace(toString(cgi.SCRIPT_NAME), chr(10), " ", "all") : "-")
                            & " queryString=" & (structKeyExists(cgi, "QUERY_STRING") ? replace(toString(cgi.QUERY_STRING), chr(10), " ", "all") : "-")
                            & " lockId=" & lockId
                            & " originalName=" & replace(replace(originalName, chr(13), " ", "all"), chr(10), " ", "all")
                            & " uploadPath=" & replace(replace(uploadPath, chr(13), " ", "all"), chr(10), " ", "all")
                            & " exceptionType=" & (structKeyExists(cfcatch, "type") ? replace(toString(cfcatch.type), chr(10), " ", "all") : "-")
                            & " message=" & replace(replace(cfcatch.message, chr(13), " ", "all"), chr(10), " ", "all")
                            & " detail=" & replace(replace(cfcatch.detail, chr(13), " ", "all"), chr(10), " ", "all");

                        if (!directoryExists(logDirectory)) {
                            directoryCreate(logDirectory);
                        }
                        fileAppend(logFile, logLine & chr(10), "utf-8");
                    } catch (any logError) {
                    }

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
            var lockId = toInt(readValue(arguments.body, "id", readValue(arguments.body, "ID", 0)));
            var svc = createLockService();
            var result = {};

            if (!isValidNonce(nonce)) {
                return buildResponse(false, true, "Security check failed", {}, "The admin form expired. Reload the page and try again.");
            }
            if (lockId LTE 0) {
                return buildResponse(false, true, "Invalid lock", {}, "Lock id is required.");
            }

            result = svc.deleteLockImage(lockId, resolveFpwBasePath());
            if (!result.SUCCESS) {
                return buildResponse(false, true, "Delete failed", {
                    "lock" = structKeyExists(result, "LOCK") ? result.LOCK : {},
                    "image" = structKeyExists(result, "IMAGE") ? result.IMAGE : {},
                    "deleted" = structKeyExists(result, "DELETED") ? result.DELETED : []
                }, structKeyExists(result, "MESSAGE") ? result.MESSAGE : "Unable to delete lock image.");
            }

            return buildResponse(true, true, result.MESSAGE, {
                "lock" = result.LOCK,
                "image" = result.IMAGE,
                "deleted" = result.DELETED
            });
        </cfscript>
    </cffunction>

    <cffunction name="listFacets" access="private" returntype="struct" output="false">
        <cfscript>
            var svc = createLockService();
            return buildResponse(true, true, "OK", svc.getAdminFacets());
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

    <cffunction name="toInt" access="private" returntype="numeric" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            var txt = trim(toString(arguments.value));
            if (!len(txt) OR !isNumeric(txt)) return 0;
            return int(val(txt));
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

    <cffunction name="isAdminUser" access="private" returntype="boolean" output="false">
        <cfargument name="userStruct" type="struct" required="true">
        <cfscript>
            var roleValue = "";
            var emailValue = "";
            var adminWhitelist = "admin@floatplanwizard.com,lswald@yahoo.com";

            if (structKeyExists(arguments.userStruct, "isAdmin") AND toBoolean(arguments.userStruct.isAdmin, false)) return true;
            if (structKeyExists(arguments.userStruct, "ISADMIN") AND toBoolean(arguments.userStruct.ISADMIN, false)) return true;
            if (structKeyExists(arguments.userStruct, "is_admin") AND toBoolean(arguments.userStruct.is_admin, false)) return true;

            if (structKeyExists(arguments.userStruct, "role")) {
                roleValue = lCase(trim(toString(arguments.userStruct.role)));
            } else if (structKeyExists(arguments.userStruct, "ROLE")) {
                roleValue = lCase(trim(toString(arguments.userStruct.ROLE)));
            }
            if (roleValue EQ "admin") return true;

            if (structKeyExists(arguments.userStruct, "email")) {
                emailValue = lCase(trim(toString(arguments.userStruct.email)));
            } else if (structKeyExists(arguments.userStruct, "EMAIL")) {
                emailValue = lCase(trim(toString(arguments.userStruct.EMAIL)));
            }
            if (len(emailValue) AND listFindNoCase(adminWhitelist, emailValue)) return true;

            return false;
        </cfscript>
    </cffunction>

    <cffunction name="isValidNonce" access="private" returntype="boolean" output="false">
        <cfargument name="nonce" type="string" required="true">
        <cfscript>
            return structKeyExists(session, "greatLoopLocksAdminNonce")
                AND len(trim(arguments.nonce))
                AND trim(arguments.nonce) EQ session.greatLoopLocksAdminNonce;
        </cfscript>
    </cffunction>

    <cffunction name="isMultipartRequest" access="private" returntype="boolean" output="false">
        <cfscript>
            var contentType = "";
            if (structKeyExists(cgi, "CONTENT_TYPE")) {
                contentType = toString(cgi.CONTENT_TYPE);
            } else if (structKeyExists(cgi, "content_type")) {
                contentType = toString(cgi.content_type);
            }
            return findNoCase("multipart/form-data", contentType) GT 0;
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

    <cffunction name="getLockUploadTempDirectory" access="private" returntype="string" output="false">
        <cfscript>
            var tempDirectory = getDirectoryFromPath(getCurrentTemplatePath()) & "../../logs/fpw-lock-upload-temp";
            if (!directoryExists(tempDirectory)) {
                directoryCreate(tempDirectory);
            }
            return tempDirectory;
        </cfscript>
    </cffunction>

    <cffunction name="safeDelete" access="private" returntype="void" output="false">
        <cfargument name="filePath" type="string" required="false" default="">
        <cfscript>
            try {
                if (len(trim(arguments.filePath)) AND fileExists(arguments.filePath)) {
                    fileDelete(arguments.filePath);
                }
            } catch (any ignored) {
            }
        </cfscript>
    </cffunction>

</cfcomponent>
