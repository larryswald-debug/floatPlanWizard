<cfcomponent output="false">

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
                    fp.departTimezone,
                    fp.departureTZ,
                    DATE_ADD(
                        fp.returnTime,
                        INTERVAL (
                            COALESCE(fp.overnight_pause_minutes_total, 0)
                            + COALESCE(fp.manual_delay_minutes_total, 0)
                        ) MINUTE
                    ) AS returnTime,
                    fp.returnTimezone,
                    fp.returnTZ,
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
                    DEPARTURE_TIMEZONE = len(trim(toString(qPlans.departureTZ))) ? qPlans.departureTZ : qPlans.departTimezone,
                    RETURNDATETIME = qPlans.returnTime,
                    RETURN_TIMEZONE = len(trim(toString(qPlans.returnTZ))) ? qPlans.returnTZ : qPlans.returnTimezone,
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

            <cfset response = {
                SUCCESS = true,
                DATA = {
                    overdueMarked = 0,
                    retired = true
                },
                MESSAGE = "Legacy monitor tick retired. Use canonical row-based monitoring evaluator."
            }>
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
                    m.float_plan_id AS floatplanId,
                    fp.userId,
                    fp.floatPlanName,
                    UPPER(TRIM(m.monitor_state)) AS status,
                    fp.departureTime,
                    fp.returnTime,
                    m.last_checkin_at AS lastCheckInAt,
                    v.vesselName,
                    CASE
                        WHEN m.last_checkin_at IS NULL THEN NULL
                        ELSE TIMESTAMPDIFF(MINUTE, m.last_checkin_at, UTC_TIMESTAMP())
                    END AS minutesSinceCheckIn,
                    CASE
                        WHEN UPPER(TRIM(m.monitor_state)) IN ('LATE','MISSED','ESCALATED')
                         AND m.expected_checkin_at IS NOT NULL
                        THEN GREATEST(TIMESTAMPDIFF(MINUTE, m.expected_checkin_at, UTC_TIMESTAMP()), 0)
                        ELSE 0
                    END AS minutesOverdue,
                    CASE
                        WHEN UPPER(TRIM(m.monitor_state)) = 'ESCALATED' THEN 1
                        ELSE 0
                    END AS isEscalated
                FROM floatplan_monitoring m
                INNER JOIN (
                    SELECT MAX(id) AS id
                    FROM floatplan_monitoring
                    WHERE user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                      AND is_monitoring_enabled = 1
                      AND UPPER(TRIM(monitor_state)) <> 'CLOSED'
                    GROUP BY float_plan_id
                ) latest ON latest.id = m.id
                INNER JOIN floatplans fp
                    ON fp.floatPlanId = m.float_plan_id
                   AND fp.userId = <cfqueryparam cfsqltype="cf_sql_varchar" value="#toString(val(userId))#">
                LEFT JOIN vessels v ON fp.vesselId = v.vesselId
                ORDER BY
                    CASE
                        WHEN UPPER(TRIM(m.monitor_state)) = 'ESCALATED' THEN 0
                        WHEN UPPER(TRIM(m.monitor_state)) = 'MISSED' THEN 1
                        WHEN UPPER(TRIM(m.monitor_state)) = 'LATE' THEN 2
                        ELSE 3
                    END,
                    CASE WHEN m.expected_checkin_at IS NULL THEN 1 ELSE 0 END,
                    m.expected_checkin_at ASC,
                    m.id DESC
                LIMIT <cfqueryparam cfsqltype="cf_sql_integer" value="50">
            </cfquery>

            <cfset plans = []>
            <cfset counts = { active = 0, overdue = 0, escalated = 0 }>
            <cftry>
                <cfset monitoringAccessGateService = createObject("component", "fpw.api.v1.MemberAccessGateService").init("fpw")>
                <cfcatch type="any">
                    <cfset monitoringAccessGateService = createObject("component", "api.v1.MemberAccessGateService").init("fpw")>
                </cfcatch>
            </cftry>

            <cfloop query="qPlans">
                <cfset monitoringPlanGate = monitoringAccessGateService.requireTripOperationalAccess(
                    val(userId),
                    val(qPlans.floatplanId)
                )>
                <cfif NOT monitoringPlanGate.allowed>
                    <cfcontinue>
                </cfif>

                <cfset planStatus = trim(toString(qPlans.status))>
                <cfset statusUpper = ucase(planStatus)>
                <cfset displayName = trim(toString(qPlans.floatPlanName))>
                <cfif NOT len(displayName)>
                    <cfset displayName = "Float Plan ##" & qPlans.floatplanId>
                </cfif>

                <cfif statusUpper EQ "ACTIVE">
                    <cfset counts.active++>
                <cfelseif listFindNoCase("LATE,MISSED,ESCALATED", statusUpper) GT 0>
                    <cfset counts.overdue++>
                </cfif>
                <cfif statusUpper EQ "ESCALATED">
                    <cfset counts.escalated++>
                </cfif>

                <cfset planStruct = {
                    floatPlanId = qPlans.floatplanId,
                    status = qPlans.status,
                    departureDateTime = qPlans.departureTime,
                    returnByDateTime = qPlans.returnTime,
                    lastCheckInDateTime = qPlans.lastCheckInAt,
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

    <cffunction name="loadFloatPlanRow" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var row = {};
            var q = queryExecute("\n                SELECT floatplanId, userId, status, returnTime, returnTimezone,\n                    floatPlanName, departing, `returning`, departureTime, departTimezone,\n                    rescueAuthority, rescueAuthorityPhone\n                FROM floatplans\n                WHERE floatplanId = :planId AND userId = :userId\n                LIMIT 1\n            ", {
                planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
            }, { datasource = "fpw" });

            if (q.recordCount EQ 1) {
                row = {
                    FLOATPLANID = q.floatplanId[1],
                    USERID = q.userId[1],
                    STATUS = q.status[1],
                    RETURN_TIME = q.returnTime[1],
                    RETURN_TIMEZONE = q.returnTimezone[1],
                    NAME = q.floatPlanName[1],
                    DEPARTING_FROM = q.departing[1],
                    RETURNING_TO = q.returning[1],
                    DEPARTURE_TIME = q.departureTime[1],
                    DEPARTURE_TIMEZONE = q.departTimezone[1],
                    RESCUE_AUTHORITY = q.rescueAuthority[1],
                    RESCUE_AUTHORITY_PHONE = q.rescueAuthorityPhone[1]
                };
            }
            return row;
        </cfscript>
    </cffunction>



</cfcomponent>
