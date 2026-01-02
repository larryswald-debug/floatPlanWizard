<cfcomponent output="false">

    <cfset variables.CHECKIN_INTERVAL_MINUTES = 60>
    <cfset variables.ESCALATION_DELAY_MINUTES = 30>
    <cfset variables.MONITOR_TASK_KEY = "CHANGE_ME">

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfargument name="limit" type="any" required="false">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

        <cftry>

            <!-- Require authenticated session -->
            <cfif NOT structKeyExists(session, "user") OR NOT isStruct(session.user)>
                <cfset response = {
                    SUCCESS = false,
                    AUTH    = false,
                    ERROR   = "NOT_LOGGED_IN",
                    MESSAGE = "Not logged in."
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <!-- Resolve userId from session -->
            <cfset userId = 0>
            <cfif structKeyExists(session.user, "userId")>
                <cfset userId = session.user.userId>
            <cfelseif structKeyExists(session.user, "id")>
                <cfset userId = session.user.id>
            <cfelseif structKeyExists(session.user, "USERID")>
                <cfset userId = session.user.USERID>
            </cfif>

            <cfif NOT isNumeric(userId) OR userId LTE 0>
                <cfset response = {
                    SUCCESS = false,
                    AUTH    = false,
                    ERROR   = "INVALID_SESSION",
                    MESSAGE = "Session user is invalid."
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <!-- Optional JSON body -->
            <cfset httpData = getHttpRequestData()>
            <cfset rawBody  = toString(httpData.content)>
            <cfset body     = {}>

            <cfif len(trim(rawBody))>
                <cftry>
                    <cfset body = deserializeJSON(rawBody, false)>
                <cfcatch>
                    <cfset body = {}>
                </cfcatch>
                </cftry>
            </cfif>

            <!-- Optional limit parameter -->
            <cfset planLimit = 5>

            <cfif structKeyExists(arguments, "limit") AND isNumeric(arguments.limit)>
                <cfset planLimit = val(arguments.limit)>
            <cfelseif structKeyExists(url, "limit") AND isNumeric(url.limit)>
                <cfset planLimit = val(url.limit)>
            <cfelseif structKeyExists(body, "limit") AND isNumeric(body.limit)>
                <cfset planLimit = val(body.limit)>
            </cfif>

            <cfif planLimit LTE 0><cfset planLimit = 5></cfif>
            <cfif planLimit GT 20><cfset planLimit = 20></cfif>

            <!-- Load float plans for this user -->
            <cfquery name="qPlans" datasource="fpw">
                SELECT
                    fp.floatplanId,
                    fp.userId,
                    fp.floatPlanName,
                    fp.status,
                    fp.departureTime,
                    fp.returnTime,
                    fp.vesselId,
                    fp.dateCreated,
                    fp.lastUpdate,
                    v.vesselName,
                    (
                        SELECT COUNT(*)
                        FROM floatplan_waypoints fwp
                        WHERE fwp.floatplanId = fp.floatplanId
                    ) AS waypointCount
                FROM floatplans fp
                LEFT JOIN vessels v ON fp.vesselId = v.vesselId
                WHERE fp.userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                ORDER BY
                    COALESCE(fp.lastUpdate, fp.dateCreated) DESC,
                    fp.floatplanId DESC
                LIMIT #planLimit#
            </cfquery>

            <cfset plans = []>

            <cfloop query="qPlans">
                <cfset planStruct = {
                    FLOATPLANID    = qPlans.floatplanId,
                    USERID         = qPlans.userId,
                    PLANNAME       = qPlans.floatPlanName,
                    STATUS         = qPlans.status,
                    DEPARTDATETIME = qPlans.departureTime,
                    RETURNDATETIME = qPlans.returnTime,
                    VESSELID       = qPlans.vesselId,
                    VESSELNAME     = qPlans.vesselName,
                    CREATEDDATE    = qPlans.dateCreated,
                    UPDATEDDATE    = qPlans.lastUpdate,
                    WAYPOINTCOUNT  = qPlans.waypointCount
                }>
                <cfset arrayAppend(plans, planStruct)>
            </cfloop>

            <cfset response = {
                SUCCESS = true,
                AUTH    = true,
                COUNT   = arrayLen(plans),
                PLANS   = plans
            }>

            <cfoutput>#serializeJSON(response)#</cfoutput>

            <cfcatch type="any">
                <cfset errResponse = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "SERVER_ERROR",
                    MESSAGE = "Float plans API error.",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

    <cffunction name="runMonitorTick" access="remote" returntype="void" output="true">
        <cfargument name="taskKey" type="any" required="false">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

        <cftry>
            <cfset providedKey = "">
            <cfif structKeyExists(arguments, "taskKey")>
                <cfset providedKey = trim(arguments.taskKey)>
            <cfelseif structKeyExists(url, "taskKey")>
                <cfset providedKey = trim(url.taskKey)>
            </cfif>

            <cfif NOT len(providedKey) OR providedKey NEQ 'testkey123'>
                <cfset response = {
                    SUCCESS = false,
                    MESSAGE = "Invalid task key."
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfquery name="qUpdate" result="qUpdateResult" datasource="fpw">
                UPDATE floatplans
                SET status = 'OVERDUE'
                WHERE UPPER(TRIM(status)) = 'ACTIVE'
                  AND (
                        (returnTime IS NOT NULL AND returnTime < NOW())
                     OR (checkedInAt IS NOT NULL AND checkedInAt < DATE_SUB(NOW(), INTERVAL <cfqueryparam cfsqltype="cf_sql_integer" value="#variables.CHECKIN_INTERVAL_MINUTES#"> MINUTE))
                  )
            </cfquery>

            <cfset response = {
                SUCCESS = true,
                DATA = { overdueMarked = qUpdateResult.recordCount },
                MESSAGE = ""
            }>
            <cflog file="floatplan_monitor" text="Monitor tick completed. Overdue plans marked: #qUpdateResult.recordCount#">
            <!--- CF scheduled task example:
                  http://localhost:8500/fpw/api/v1/floatplans.cfc?method=runMonitorTick&taskKey=CHANGE_ME --->
            <cfoutput>#serializeJSON(response)#</cfoutput>

            <cfcatch type="any">
                <cfset errResponse = {
                    SUCCESS = false,
                    MESSAGE = "Monitor tick failed.",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>   

    <cffunction name="getMonitoredPlans" access="remote" returntype="void" output="true">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

        <cftry>

            <!-- Require authenticated session -->
            <cfif NOT structKeyExists(session, "user") OR NOT isStruct(session.user)>
                <cfset response = {
                    SUCCESS = false,
                    AUTH    = false,
                    ERROR   = "NOT_LOGGED_IN",
                    MESSAGE = "Not logged in."
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <!-- Resolve userId from session -->
            <cfset userId = 0>
            <cfif structKeyExists(session.user, "userId")>
                <cfset userId = session.user.userId>
            <cfelseif structKeyExists(session.user, "id")>
                <cfset userId = session.user.id>
            <cfelseif structKeyExists(session.user, "USERID")>
                <cfset userId = session.user.USERID>
            </cfif>

            <cfif NOT isNumeric(userId) OR userId LTE 0>
                <cfset response = {
                    SUCCESS = false,
                    AUTH    = false,
                    ERROR   = "INVALID_SESSION",
                    MESSAGE = "Session user is invalid."
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfquery name="qPlans" datasource="fpw">
                SELECT
                    fp.floatplanId,
                    fp.userId,
                    fp.floatPlanName,
                    fp.status,
                    fp.departureTime,
                    fp.returnTime,
                    fp.checkedInAt,
                    v.vesselName,
                    TIMESTAMPDIFF(MINUTE, fp.checkedInAt, NOW()) AS minutesSinceCheckIn,
                    CASE
                        WHEN fp.returnTime IS NULL THEN NULL
                        WHEN UPPER(TRIM(fp.status)) = 'OVERDUE' THEN GREATEST(TIMESTAMPDIFF(MINUTE, fp.returnTime, NOW()), 0)
                        ELSE 0
                    END AS minutesOverdue,
                    CASE
                        WHEN UPPER(TRIM(fp.status)) = 'OVERDUE'
                         AND fp.returnTime IS NOT NULL
                         AND NOW() > DATE_ADD(fp.returnTime, INTERVAL <cfqueryparam cfsqltype="cf_sql_integer" value="#variables.ESCALATION_DELAY_MINUTES#"> MINUTE)
                        THEN 1
                        ELSE 0
                    END AS isEscalated
                FROM floatplans fp
                LEFT JOIN vessels v ON fp.vesselId = v.vesselId
                WHERE fp.userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                  AND UPPER(TRIM(fp.status)) IN ('ACTIVE', 'OVERDUE')
                ORDER BY
                    CASE WHEN UPPER(TRIM(fp.status)) = 'OVERDUE' THEN 0 ELSE 1 END,
                    CASE WHEN fp.returnTime IS NULL THEN 1 ELSE 0 END,
                    fp.returnTime ASC
                LIMIT <cfqueryparam cfsqltype="cf_sql_integer" value="50">
            </cfquery>

            <cfset plans = []>
            <cfset counts = { active = 0, overdue = 0, escalated = 0 }>

            <cfloop query="qPlans">
                <cfset planStatus = trim(toString(qPlans.status))>
                <cfset statusUpper = ucase(planStatus)>
                <cfset displayName = trim(toString(qPlans.floatPlanName))>
                <cfif NOT len(displayName)>
                    <cfset displayName = "Float Plan ##" & qPlans.floatplanId>
                </cfif>

                <cfif statusUpper EQ "ACTIVE">
                    <cfset counts.active++>
                <cfelseif statusUpper EQ "OVERDUE">
                    <cfset counts.overdue++>
                </cfif>
                <cfif qPlans.isEscalated EQ 1>
                    <cfset counts.escalated++>
                </cfif>

                <cfset planStruct = {
                    floatPlanId = qPlans.floatplanId,
                    status = qPlans.status,
                    departureDateTime = qPlans.departureTime,
                    returnByDateTime = qPlans.returnTime,
                    lastCheckInDateTime = qPlans.checkedInAt,
                    isEscalated = (qPlans.isEscalated EQ 1),
                    minutesSinceCheckIn = qPlans.minutesSinceCheckIn,
                    minutesOverdue = qPlans.minutesOverdue,
                    displayName = displayName
                }>
                <cfset arrayAppend(plans, planStruct)>
            </cfloop>

            <cfset response = {
                SUCCESS = true,
                AUTH    = true,
                DATA    = {
                    counts = counts,
                    plans  = plans
                }
            }>

            <cfoutput>#serializeJSON(response)#</cfoutput>

            <cfcatch type="any">
                <cfset errResponse = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "SERVER_ERROR",
                    MESSAGE = "Monitored plans API error.",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

</cfcomponent>
