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
