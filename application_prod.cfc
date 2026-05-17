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

    <cffunction name="getEnvValue" access="private" returntype="string" output="false">
        <cfargument name="name" type="string" required="true">
        <cfreturn "">
    </cffunction>

    <cffunction name="onApplicationStart" access="public" returntype="boolean" output="false">
        <cfset application.env = "prod">
        <cfset application.DSN = "fpw">
        <cfset application.monitorToken = "">
        <cftry>
            <cfset application.monitorToken = getEnvValue("FPW_MONITOR_TOKEN")>
            <cfcatch type="any">
                <cflog
                    file="fpw-errors"
                    type="error"
                    text="FPW_MONITOR_TOKEN_READ_FAILED message=#toString(cfcatch.message)# detail=#toString(cfcatch.detail)#">
            </cfcatch>
        </cftry>
        <cfset application.debugRequestTrace = false>
        <cfset application.settings = {
            "monitorToken" = application.monitorToken,
            "env" = application.env
        }>

        <cfreturn true>
    </cffunction>

    <cffunction name="onRequestStart" access="public" returntype="boolean" output="false">
        <cfreturn true>
    </cffunction>

    <cffunction name="onError" access="public" returntype="void" output="true">
        <cfargument name="exception" type="any" required="true">
        <cfargument name="eventName" type="string" required="true">

        <cfset var rootLogDirectory = variables.applicationRootPath & "logs">
        <cfset var rootLogFile = rootLogDirectory & "/fpw-errors.log">
        <cfset var rootLogMessage = replace(replace(toString(arguments.exception.message), chr(13), " ", "all"), chr(10), " ", "all")>
        <cfset var rootLogDetail = replace(replace(toString(arguments.exception.detail), chr(13), " ", "all"), chr(10), " ", "all")>
        <cfset var rootLogLine = "FPW_ERROR ts=#dateTimeFormat(now(), 'yyyy-mm-dd HH:nn:ss')# event=#arguments.eventName# message=#rootLogMessage# detail=#rootLogDetail#">

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
            text="FPW_ERROR event=#arguments.eventName# message=#toString(arguments.exception.message)# detail=#toString(arguments.exception.detail)#">

        <cfheader statuscode="500">
        <cfcontent type="text/plain; charset=utf-8" reset="true">
        <cfoutput>An unexpected error occurred. Please try again later.</cfoutput>
    </cffunction>

</cfcomponent>
