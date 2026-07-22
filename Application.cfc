<!--- /Application.cfc (PRODUCTION ONLY) --->
<cfcomponent output="false" hint="FloatPlanWizard production Application.cfc">

    <!--- ===== APP SETTINGS ===== --->
    <cfset this.name               = "FPW">
    <cfset this.applicationTimeout = createTimeSpan(7,0,0,0)>
    <cfset this.sessionManagement  = true>
    <cfset this.sessionTimeout     = createTimeSpan(0,4,0,0)>
    <cfset this.setClientCookies   = true>
    <cfset this.clientManagement   = false>
    <cfset this.sessionType        = "j2ee">
    <cfset this.sessionCookie = {
        httpOnly = true,
        sameSite = "Lax",
        secure = (structKeyExists(server, "coldfusion")
            AND structKeyExists(server.coldfusion, "productLevel")
            AND compareNoCase(toString(server.coldfusion.productLevel), "Developer") NEQ 0)
    }>
    <cfset this.datasource         = "fpw">
    <cfset this.DSN                = "fpw">

    <!--- Root-mounted production still needs the /fpw component mapping. --->
    <cfif NOT structKeyExists(this, "mappings") OR NOT isStruct(this.mappings)>
        <cfset this.mappings = {}>
    </cfif>
    <cfset variables.applicationRootPath = getDirectoryFromPath(getCurrentTemplatePath())>
    <cfset this.mappings["/fpw"] = variables.applicationRootPath>
    <cfset this.mappings["/_fpw_private"] = variables.applicationRootPath & "_fpw_private">
    <cfif directoryExists(variables.applicationRootPath & "testbox")>
        <cfset this.mappings["/testbox"] = variables.applicationRootPath & "testbox">
    </cfif>

    <cffunction name="onApplicationStart" access="public" returntype="boolean" output="false">
         <!---  swithc for prod environment
        <cfset var stripeConfigPath = expandPath("/_fpw_private/stripe-config.json")> --->
        <cfset var stripeConfigPath = expandPath("/_fpw_private/stripe-config.json")>
        <cfset var stripeConfigService = new fpw.api.v1.StripeConfigService().init(stripeConfigPath)>
        <cfset var stripeApplicationSettings = stripeConfigService.getApplicationSettings()>
        <cfset var productEventFailureConfig = {}>
        <cfset application.stripeConfigPath = stripeConfigPath>
        <cfset application.env = stripeConfigService.getFpwEnv()>
        <cfset application.DSN = "fpw">
        <cfset application.monitorToken = stripeConfigService.getMonitorToken()>
        <cfset application.debugRequestTrace = false>
        <cfset application.settings = stripeApplicationSettings>
        <cfset application.premiumSendCreditModelEnabled = stripeConfigService.getPremiumSendCreditModelEnabled()>
        <cfset application.oneTripDisplayAmount = stripeConfigService.getOneTripDisplayAmount()>
        <cfset application.oneTripCheckoutAvailable = application.premiumSendCreditModelEnabled AND len(stripeConfigService.getOneTripPriceId()) GT 0 AND len(application.oneTripDisplayAmount) GT 0>
        <cfset productEventFailureConfig = new fpw.includes.ProductEventService().init("fpw").validateForcedFailureConfiguration()>
        <cfset application.productEventsForceFailure = productEventFailureConfig.ENABLED>

        <cfreturn true>
    </cffunction>

    <cffunction name="onRequestStart" access="public" returntype="boolean" output="true">
        <cfset var scriptName = structKeyExists(cgi, "script_name") ? lCase(toString(cgi.script_name)) : "">
        <cfset var requestMethod = structKeyExists(cgi, "request_method") ? uCase(trim(toString(cgi.request_method))) : "GET">
        <cfset var componentMethod = structKeyExists(url, "method") ? lCase(trim(toString(url.method))) : "">
        <cfset var isAdminPage = findNoCase("/admin/", scriptName) GT 0>
        <cfset var isApplicationReload = structKeyExists(url, "appreload")>
        <cfset var isNamedAdminApi = reFindNoCase("/api/v1/admin[^/]*\.cfc$", scriptName) GT 0>
        <cfset var isSegmentGeometryApi = reFindNoCase("/api/v1/segmentgeometry\.cfc$", scriptName) GT 0>
        <cfset var isDatabaseBackup = reFindNoCase("/api/v1/dbbackup\.(cfc|cfm)$", scriptName) GT 0>
        <cfset var isStripeConfigProof = reFindNoCase("/api/v1/stripeconfigproof\.cfm$", scriptName) GT 0>
        <cfset var isWmsAdminStats = reFindNoCase("/api/v1/wmsproxy\.cfc$", scriptName) GT 0 AND componentMethod EQ "stats">
        <cfset var isAdminApi = isNamedAdminApi OR isSegmentGeometryApi OR isDatabaseBackup OR isStripeConfigProof OR isWmsAdminStats>
        <cfset var userStruct = (structKeyExists(session, "user") AND isStruct(session.user)) ? session.user : {}>
        <cfset var adminAuthService = "">
        <cfset var adminAuthorization = {}>
        <cfset var csrfCandidate = "">
        <cfset var isWmsReset = isWmsAdminStats AND structKeyExists(url, "reset") AND trim(toString(url.reset)) EQ "1">

        <cfif NOT structKeyExists(request, "fpwRequestId")>
            <cfset request.fpwRequestId = createUUID()>
        </cfif>

        <!--- Application reloads are state-changing admin operations and must never run through GET. --->
        <cfif isApplicationReload AND requestMethod NEQ "POST">
            <cfreturn stopAdminRequest(405, "METHOD_NOT_ALLOWED", "Application reload requires an authenticated administrative POST request.", false)>
        </cfif>

        <cfif isAdminPage OR isAdminApi OR isApplicationReload>
            <cfset adminAuthService = new fpw.api.v1.AdminAuthorizationService().init("fpw")>
            <cfset adminAuthorization = adminAuthService.authorizeCurrentSession(userStruct)>
            <cfif NOT adminAuthorization.authenticated>
                <cfreturn stopAdminRequest(401, "AUTH_REQUIRED", "Authentication is required.", isAdminApi)>
            </cfif>
            <cfif NOT adminAuthorization.authorized>
                <cfreturn stopAdminRequest(403, "FORBIDDEN", "Administrative access is required.", isAdminApi)>
            </cfif>

            <cfset request.fpwAdminAuthorization = adminAuthorization>
            <cfset request.fpwAdminCsrfToken = adminAuthService.getOrCreateCsrfToken()>
            <cfset request.fpwAdminRequest = {
                "scriptName" = scriptName,
                "requestMethod" = requestMethod,
                "componentMethod" = componentMethod,
                "isAdminPage" = isAdminPage,
                "isAdminApi" = isAdminApi,
                "isApplicationReload" = isApplicationReload
            }>

            <cfif isAdminPage>
                <cfif NOT listFindNoCase("GET,HEAD,POST", requestMethod)>
                    <cfreturn stopAdminRequest(405, "METHOD_NOT_ALLOWED", "The administrative page does not support this method.", false)>
                </cfif>
                <cfif requestMethod EQ "POST">
                    <cfset csrfCandidate = adminAuthService.resolveRequestCsrfToken()>
                    <cfif NOT adminAuthService.isValidCsrfToken(csrfCandidate)>
                        <cfreturn stopAdminRequest(403, "CSRF_INVALID", "The administrative request token is invalid or expired.", false)>
                    </cfif>
                </cfif>
            <cfelseif isStripeConfigProof>
                <cfif NOT listFindNoCase("GET,HEAD", requestMethod)>
                    <cfreturn stopAdminRequest(405, "METHOD_NOT_ALLOWED", "Use GET for this read-only administrative diagnostic.", true)>
                </cfif>
            <cfelseif isWmsAdminStats AND NOT isWmsReset AND listFindNoCase("GET,HEAD", requestMethod)>
                <!--- Authorized read-only WMS statistics request. --->
            <cfelse>
                <cfif requestMethod NEQ "POST">
                    <cfreturn stopAdminRequest(405, "METHOD_NOT_ALLOWED", "Use POST for administrative API requests.", true)>
                </cfif>
                <cfset csrfCandidate = adminAuthService.resolveRequestCsrfToken()>
                <cfif NOT adminAuthService.isValidCsrfToken(csrfCandidate)>
                    <cfreturn stopAdminRequest(403, "CSRF_INVALID", "The administrative request token is invalid or expired.", true)>
                </cfif>
            </cfif>

            <cfif isApplicationReload>
                <cflock scope="application" type="exclusive" timeout="10">
                    <cfset onApplicationStart()>
                </cflock>
                <cfset request.fpwApplicationReloaded = true>
            </cfif>
        </cfif>

        <cfreturn true>
    </cffunction>

    <cffunction name="onRequestEnd" access="public" returntype="void" output="false">
        <cfargument name="targetPage" type="string" required="true">
        <cfif structKeyExists(request, "fpwAdminRequest")
            AND isStruct(request.fpwAdminRequest)
            AND structKeyExists(request.fpwAdminRequest, "requestMethod")
            AND request.fpwAdminRequest.requestMethod EQ "POST">
            <cfset recordAdminRequestAudit(true, "admin_request_completed")>
        </cfif>
    </cffunction>

    <cffunction name="recordAdminRequestAudit" access="private" returntype="void" output="false">
        <cfargument name="success" type="boolean" required="true">
        <cfargument name="action" type="string" required="true">
        <cfset var auditService = "">
        <cfset var requestDetails = {}>
        <cftry>
            <cfif NOT structKeyExists(request, "fpwAdminAuthorization")
                OR NOT isStruct(request.fpwAdminAuthorization)
                OR NOT structKeyExists(request.fpwAdminAuthorization, "userId")
                OR val(request.fpwAdminAuthorization.userId) LTE 0
                OR NOT structKeyExists(request, "fpwAdminRequest")
                OR NOT isStruct(request.fpwAdminRequest)>
                <cfreturn>
            </cfif>
            <cfset requestDetails = {
                "requestMethod" = structKeyExists(request.fpwAdminRequest, "requestMethod") ? request.fpwAdminRequest.requestMethod : "",
                "componentMethod" = structKeyExists(request.fpwAdminRequest, "componentMethod") ? request.fpwAdminRequest.componentMethod : ""
            }>
            <cfset auditService = new fpw.api.v1.AdminAuditService().init("fpw")>
            <cfset auditService.record(
                actorUserId = val(request.fpwAdminAuthorization.userId),
                action = arguments.action,
                targetType = "admin_endpoint",
                targetId = structKeyExists(request.fpwAdminRequest, "scriptName") ? request.fpwAdminRequest.scriptName : "",
                success = arguments.success,
                requestId = structKeyExists(request, "fpwRequestId") ? toString(request.fpwRequestId) : "",
                newValues = requestDetails
            )>
            <cfcatch type="any">
                <cflog file="fpw-admin-audit" type="error" text="ADMIN_AUDIT_WRITE_FAILED requestId=#structKeyExists(request, 'fpwRequestId') ? toString(request.fpwRequestId) : ''# message=#toString(cfcatch.message)#">
            </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="stopAdminRequest" access="private" returntype="boolean" output="true">
        <cfargument name="statusCode" type="numeric" required="true">
        <cfargument name="code" type="string" required="true">
        <cfargument name="message" type="string" required="true">
        <cfargument name="asJson" type="boolean" required="true">
        <cfsetting showdebugoutput="false">
        <cfheader statuscode="#arguments.statusCode#">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">
        <cfif arguments.asJson>
            <cfcontent type="application/json; charset=utf-8" reset="true">
            <cfoutput>#serializeJSON({
                "SUCCESS" = false,
                "AUTH" = arguments.statusCode NEQ 401,
                "MESSAGE" = arguments.message,
                "DATA" = {},
                "ERROR" = {
                    "CODE" = arguments.code,
                    "MESSAGE" = arguments.message
                }
            })#</cfoutput>
        <cfelse>
            <cfcontent type="text/plain; charset=utf-8" reset="true">
            <cfoutput>#encodeForHTML(arguments.message)#</cfoutput>
        </cfif>
        <cfreturn false>
    </cffunction>

    <cffunction name="onError" access="public" returntype="void" output="true">
        <cfargument name="exception" type="any" required="true">
        <cfargument name="eventName" type="string" required="true">

        <cfset var rootLogDirectory = variables.applicationRootPath & "logs">
        <cfset var rootLogFile = rootLogDirectory & "/fpw-errors.log">
        <cfset var rootLogContext = buildErrorLogContext(arguments.exception, arguments.eventName)>
        <cfset var rootLogMessage = sanitizeLogText(arguments.exception.message)>
        <cfset var rootLogDetail = sanitizeLogText(arguments.exception.detail)>
        <cfset var rootLogLine = "FPW_ERROR ts=#dateTimeFormat(now(), 'yyyy-mm-dd HH:nn:ss')# #rootLogContext# message=#rootLogMessage# detail=#rootLogDetail#">

        <cfif structKeyExists(request, "fpwAdminRequest")
            AND isStruct(request.fpwAdminRequest)
            AND structKeyExists(request.fpwAdminRequest, "requestMethod")
            AND request.fpwAdminRequest.requestMethod EQ "POST">
            <cfset recordAdminRequestAudit(false, "admin_request_error")>
        </cfif>

        <cftry>
            <cfif NOT directoryExists(rootLogDirectory)>
                <cfdirectory action="create" directory="#rootLogDirectory#">
            </cfif>
            <cffile action="append" file="#rootLogFile#" output="#rootLogLine#" addnewline="true" charset="utf-8">
            <cfcatch type="any">
                <cflog
                    file="fpw-errors"
                    type="error"
                    text="FPW_ERROR_ROOT_LOG_WRITE_FAILED message=#toString(cfcatch.message)# detail=#toString(cfcatch.detail)# original=#rootLogLine#">
            </cfcatch>
        </cftry>

        <cflog
            file="fpw-errors"
            type="error"
            text="FPW_ERROR #rootLogContext# message=#rootLogMessage# detail=#rootLogDetail#">

        <cfheader statuscode="500">
        <cfcontent type="text/plain; charset=utf-8" reset="true">
        <cfoutput>An unexpected error occurred. Please try again later.</cfoutput>
    </cffunction>

    <cffunction name="buildErrorLogContext" access="private" returntype="string" output="false">
        <cfargument name="exception" type="any" required="true">
        <cfargument name="eventName" type="string" required="true">

        <cfset var logParts = arrayNew(1)>
        <cfset var requestId = "">
        <cfset var sessionUserId = "">

        <cfif structKeyExists(request, "fpwRequestId")>
            <cfset requestId = toString(request.fpwRequestId)>
        <cfelse>
            <cfset requestId = createUUID()>
            <cfset request.fpwRequestId = requestId>
        </cfif>

        <cfif structKeyExists(session, "user") AND isStruct(session.user) AND structKeyExists(session.user, "id")>
            <cfset sessionUserId = toString(session.user.id)>
        </cfif>

        <cfset arrayAppend(logParts, formatLogPair("requestId", requestId))>
        <cfset arrayAppend(logParts, formatLogPair("event", arguments.eventName))>
        <cfset arrayAppend(logParts, formatLogPair("method", readCgiValue("request_method")))>
        <cfset arrayAppend(logParts, formatLogPair("scriptName", readCgiValue("script_name")))>
        <cfset arrayAppend(logParts, formatLogPair("pathInfo", readCgiValue("path_info")))>
        <cfset arrayAppend(logParts, formatLogPair("queryString", redactUrlLogValue(readCgiValue("query_string"))))>
        <cfset arrayAppend(logParts, formatLogPair("referrer", redactUrlLogValue(readCgiValue("http_referer"))))>
        <cfset arrayAppend(logParts, formatLogPair("userAgent", readCgiValue("http_user_agent")))>
        <cfset arrayAppend(logParts, formatLogPair("remoteAddr", readCgiValue("remote_addr")))>
        <cfset arrayAppend(logParts, formatLogPair("sessionUserId", sessionUserId))>
        <cfset arrayAppend(logParts, formatLogPair("exceptionType", readExceptionValue(arguments.exception, "type")))>
        <cfset arrayAppend(logParts, formatLogPair("tagContext", getFirstErrorTagContext(arguments.exception)))>

        <cfreturn arrayToList(logParts, " ")>
    </cffunction>

    <cffunction name="readCgiValue" access="private" returntype="string" output="false">
        <cfargument name="key" type="string" required="true">

        <cfif structKeyExists(cgi, arguments.key)>
            <cfreturn toString(cgi[arguments.key])>
        </cfif>

        <cfreturn "">
    </cffunction>

    <cffunction name="readExceptionValue" access="private" returntype="string" output="false">
        <cfargument name="exception" type="any" required="true">
        <cfargument name="key" type="string" required="true">

        <cfif isStruct(arguments.exception) AND structKeyExists(arguments.exception, arguments.key)>
            <cfreturn toString(arguments.exception[arguments.key])>
        </cfif>

        <cfreturn "">
    </cffunction>

    <cffunction name="getFirstErrorTagContext" access="private" returntype="string" output="false">
        <cfargument name="exception" type="any" required="true">

        <cfset var frame = "">
        <cfset var template = "">
        <cfset var lineNumber = "">

        <cfif isStruct(arguments.exception)
            AND structKeyExists(arguments.exception, "tagContext")
            AND isArray(arguments.exception.tagContext)
            AND arrayLen(arguments.exception.tagContext)>
            <cfset frame = arguments.exception.tagContext[1]>
            <cfif isStruct(frame)>
                <cfif structKeyExists(frame, "template")>
                    <cfset template = toString(frame.template)>
                </cfif>
                <cfif structKeyExists(frame, "line")>
                    <cfset lineNumber = toString(frame.line)>
                </cfif>
            </cfif>
        </cfif>

        <cfif len(template) AND len(lineNumber)>
            <cfreturn template & ":" & lineNumber>
        </cfif>

        <cfreturn template>
    </cffunction>

    <cffunction name="formatLogPair" access="private" returntype="string" output="false">
        <cfargument name="key" type="string" required="true">
        <cfargument name="value" type="any" required="false" default="">

        <cfset var cleanValue = sanitizeLogText(arguments.value)>
        <cfset cleanValue = reReplace(cleanValue, "\s+", "_", "all")>

        <cfif NOT len(cleanValue)>
            <cfset cleanValue = "-">
        </cfif>

        <cfreturn arguments.key & "=" & cleanValue>
    </cffunction>

    <cffunction name="sanitizeLogText" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="false" default="">

        <cfset var cleanValue = toString(arguments.value)>
        <cfset cleanValue = reReplace(cleanValue, "[\r\n\t]+", " ", "all")>
        <cfset cleanValue = reReplaceNoCase(cleanValue, "Bearer\s+[A-Za-z0-9._~+/=-]+", "Bearer [redacted]", "all")>
        <cfset cleanValue = reReplace(cleanValue, "sk_live_[A-Za-z0-9_*.-]+", "sk_live_[redacted]", "all")>
        <cfset cleanValue = reReplace(cleanValue, "sk_test_[A-Za-z0-9_*.-]+", "sk_test_[redacted]", "all")>
        <cfset cleanValue = reReplace(cleanValue, "rk_live_[A-Za-z0-9_*.-]+", "rk_live_[redacted]", "all")>
        <cfset cleanValue = reReplace(cleanValue, "rk_test_[A-Za-z0-9_*.-]+", "rk_test_[redacted]", "all")>
        <cfset cleanValue = reReplace(cleanValue, "whsec_[A-Za-z0-9_*.-]+", "whsec_[redacted]", "all")>

        <cfreturn trim(cleanValue)>
    </cffunction>

    <cffunction name="redactUrlLogValue" access="private" returntype="string" output="false">
        <cfargument name="value" type="string" required="false" default="">

        <cfset var rawValue = sanitizeLogText(arguments.value)>
        <cfset var queryStart = find("?", rawValue)>

        <cfif queryStart GT 0>
            <cfreturn left(rawValue, queryStart) & redactQueryString(mid(rawValue, queryStart + 1, len(rawValue)))>
        </cfif>

        <cfreturn redactQueryString(rawValue)>
    </cffunction>

    <cffunction name="redactQueryString" access="private" returntype="string" output="false">
        <cfargument name="queryString" type="string" required="false" default="">

        <cfset var queryParts = listToArray(arguments.queryString, "&")>
        <cfset var redactedParts = arrayNew(1)>
        <cfset var part = "">
        <cfset var keyName = "">
        <cfset var equalsPosition = 0>

        <cfloop array="#queryParts#" index="part">
            <cfset equalsPosition = find("=", part)>
            <cfif equalsPosition GT 1>
                <cfset keyName = left(part, equalsPosition - 1)>
                <cfif isSensitiveLogKey(keyName)>
                    <cfset part = keyName & "=[redacted]">
                </cfif>
            </cfif>
            <cfset arrayAppend(redactedParts, part)>
        </cfloop>

        <cfreturn arrayToList(redactedParts, "&")>
    </cffunction>

    <cffunction name="isSensitiveLogKey" access="private" returntype="boolean" output="false">
        <cfargument name="key" type="string" required="true">

        <cfset var decodedKey = trim(arguments.key)>
        <cfset var normalizedKey = "">
        <cfset var sensitiveKeys = "authorization,bearer,token,t,access_token,share_token,sharetoken,follower_token,followertoken,fpw_return,password,passwordconfirm,secret,client_secret,resetid,code,pairingcode,pairing_code,apikey,api_key">

        <cftry>
            <cfset decodedKey = urlDecode(decodedKey, "utf-8")>
            <cfcatch type="any">
                <!--- Preserve the raw key when malformed encoding cannot be decoded. --->
            </cfcatch>
        </cftry>
        <cfset normalizedKey = lCase(reReplace(decodedKey, "[^A-Za-z0-9_]", "", "all"))>

        <cfreturn listFindNoCase(sensitiveKeys, normalizedKey) GT 0
            OR find("token", normalizedKey) GT 0
            OR find("password", normalizedKey) GT 0
            OR find("secret", normalizedKey) GT 0>
    </cffunction>

</cfcomponent>
