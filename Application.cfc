<!--- /Application.cfc (TAGS ONLY) --->
<cfcomponent output="false" hint="FloatPlanWizard Application.cfc">

    <!--- ===== APP SETTINGS ===== --->
    <cfset this.name               = "FPW">
    <cfset this.applicationTimeout = createTimeSpan(7,0,0,0)>
    <cfset this.sessionManagement  = true>
    <cfset this.sessionTimeout     = createTimeSpan(0,4,0,0)>
    <cfset this.setClientCookies   = true>
    <cfset this.clientManagement   = false>
    <cfset this.sessionType        = "j2ee">

    <!--- Local TestBox library mapping for /fpw/tests runner --->
    <cfif NOT structKeyExists(this, "mappings") OR NOT isStruct(this.mappings)>
        <cfset this.mappings = {}>
    </cfif>
    <cfset this.mappings["/testbox"] = expandPath("/fpw/testbox")>

    <!--- ===== DATASOURCE (SET ONLY IF NOT ALREADY DEFINED) ===== --->
    <cfif NOT structKeyExists(this, "fpw") OR NOT len(trim(this.datasource))>
        <cfset this.DSN = "fpw">
    </cfif>

    <!--- ===== PER-APP DEFAULTS ===== --->
    <cffunction name="onApplicationStart" access="public" returntype="boolean" output="false">
        <!--- Monitor token used by /api/v1/monitor.cfc --->
        <cfset application.monitorToken = "abc123">

        <!--- Optional: environment flag --->
        <cfset application.env = "dev">
        <cfset application.DSN = "fpw">
        <!--- Set to false after startup/request tracing is no longer needed. --->
        <cfset application.debugRequestTrace = true>

        <!--- Optional: app-level settings struct --->
        <cfset application.settings = {
            "monitorToken" = application.monitorToken,
            "env" = application.env
        }>

        <cfreturn true>
    </cffunction>

    <cffunction name="onRequestStart" access="public" returntype="boolean" output="false">
        <!--- Allow a manual restart in dev --->
        <cfif structKeyExists(url, "appReload") AND url.appReload EQ 1>
            <cflock scope="application" type="exclusive" timeout="10">
                <cfset onApplicationStart()>
            </cflock>
        </cfif>

        <!--- Temporary, low-noise startup diagnostics for inbound FPW app/API traffic. --->
        <cfif structKeyExists(application, "debugRequestTrace")
            AND isBoolean(application.debugRequestTrace)
            AND application.debugRequestTrace>
            <cfset var traceScriptName = structKeyExists(cgi, "script_name") ? toString(cgi.script_name) : "">
            <cfset var tracePathInfo = structKeyExists(cgi, "path_info") ? toString(cgi.path_info) : "">
            <cfset var tracePath = lCase(len(trim(tracePathInfo)) ? tracePathInfo : traceScriptName)>
            <cfset var traceShouldLog = (find("/app/", tracePath) GT 0)
                OR (find("/api/", tracePath) GT 0)
                OR (right(tracePath, 10) EQ "/index.cfm")
                OR (tracePath EQ "/")>

            <cfif traceShouldLog>
                <cfset var traceQueryStringRaw = structKeyExists(cgi, "query_string") ? toString(cgi.query_string) : "">
                <cfset var traceQueryString = rereplace(traceQueryStringRaw, "(?i)(token|auth|password|passwd|sessionid)=([^&]*)", "\1=[redacted]", "all")>
                <cfset var traceMethod = structKeyExists(cgi, "request_method") ? toString(cgi.request_method) : "">
                <cfset var traceRemoteAddr = structKeyExists(cgi, "remote_addr") ? toString(cgi.remote_addr) : "">
                <cfset var traceUserAgent = structKeyExists(cgi, "http_user_agent") ? toString(cgi.http_user_agent) : "">
                <cfset var traceReferer = structKeyExists(cgi, "http_referer") ? toString(cgi.http_referer) : "">
                <cflog
                    file="fpw-request-trace"
                    type="information"
                    text="FPW_REQUEST_TRACE ts=#dateTimeFormat(now(), 'yyyy-mm-dd HH:nn:ss')# script=#traceScriptName# pathInfo=#tracePathInfo# query=#traceQueryString# method=#traceMethod# remote=#traceRemoteAddr# ua=#traceUserAgent# referer=#traceReferer#">
            </cfif>
        </cfif>

        <!--- Dev/test hook: allow explicit user-id override via request header for integration harnesses. --->
        <cfif structKeyExists( application, "env" ) AND lCase( toString( application.env ) ) EQ "dev">
            <cfset var reqData = getHttpRequestData()>
            <cfset var reqHeaders = ( structKeyExists( reqData, "headers" ) AND isStruct( reqData.headers ) ) ? reqData.headers : {} >
            <cfset var headerUserIdRaw = "" >
            <cfset var headerUserId = 0 >
            <cfif structKeyExists( reqHeaders, "X-FPW-Test-UserId" )>
                <cfset headerUserIdRaw = toString( reqHeaders[ "X-FPW-Test-UserId" ] )>
            <cfelseif structKeyExists( reqHeaders, "x-fpw-test-userid" )>
                <cfset headerUserIdRaw = toString( reqHeaders[ "x-fpw-test-userid" ] )>
            </cfif>
            <cfif isNumeric( headerUserIdRaw )>
                <cfset headerUserId = val( headerUserIdRaw )>
            </cfif>
            <cfif headerUserId GT 0>
                <cfif NOT structKeyExists( session, "user" ) OR NOT isStruct( session.user )>
                    <cfset session.user = {} >
                </cfif>
                <cfset session.user.userId = headerUserId>
                <cfset session.user.id = headerUserId>
                <cfset session.user.USERID = headerUserId>
            </cfif>
        </cfif>

        <cfreturn true>
    </cffunction>

    <cffunction name="onError" access="public" returntype="void" output="false">
        <cfargument name="exception" type="any" required="true">
        <cfargument name="eventName" type="string" required="true">

        <cfcontent type="text/plain; charset=utf-8">
        <cfoutput>
ERROR in #arguments.eventName#
#toString(arguments.exception.message)#
#toString(arguments.exception.detail)#
        </cfoutput>
    </cffunction>

</cfcomponent>
