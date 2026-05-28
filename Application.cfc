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
        <cfset application.stripeConfigPath = stripeConfigPath>
        <cfset application.env = stripeConfigService.getFpwEnv()>
        <cfset application.DSN = "fpw">
        <cfset application.monitorToken = stripeConfigService.getMonitorToken()>
        <cfset application.debugRequestTrace = false>
        <cfset application.settings = stripeApplicationSettings>

        <cfreturn true>
    </cffunction>

    <cffunction name="onRequestStart" access="public" returntype="boolean" output="false">
        <cfif NOT structKeyExists(request, "fpwRequestId")>
            <cfset request.fpwRequestId = createUUID()>
        </cfif>
        <cfif structKeyExists(url, "appreload")>
            <cfset onApplicationStart()>
        </cfif>
        <cfreturn true>
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
        <cfset cleanValue = reReplace(cleanValue, "sk_live_[A-Za-z0-9_]+", "sk_live_[redacted]", "all")>
        <cfset cleanValue = reReplace(cleanValue, "sk_test_[A-Za-z0-9_]+", "sk_test_[redacted]", "all")>
        <cfset cleanValue = reReplace(cleanValue, "rk_live_[A-Za-z0-9_]+", "rk_live_[redacted]", "all")>
        <cfset cleanValue = reReplace(cleanValue, "rk_test_[A-Za-z0-9_]+", "rk_test_[redacted]", "all")>
        <cfset cleanValue = reReplace(cleanValue, "whsec_[A-Za-z0-9_]+", "whsec_[redacted]", "all")>

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

        <cfset var normalizedKey = lCase(reReplace(trim(arguments.key), "[^A-Za-z0-9_]", "", "all"))>
        <cfset var sensitiveKeys = "authorization,bearer,token,t,access_token,share_token,sharetoken,follower_token,followertoken,password,passwordconfirm,secret,client_secret,resetid,code,pairingcode,pairing_code,apikey,api_key">

        <cfreturn listFindNoCase(sensitiveKeys, normalizedKey) GT 0
            OR find("token", normalizedKey) GT 0
            OR find("password", normalizedKey) GT 0
            OR find("secret", normalizedKey) GT 0>
    </cffunction>

</cfcomponent>
