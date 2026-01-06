<cfcomponent output="false">

    <cfset variables.CHECKIN_INTERVAL_MINUTES = 60>
    <cfset variables.ESCALATION_DELAY_MINUTES = 30>
    <cfset variables.MONITOR_TASK_KEY = "CHANGE_ME">

    <cffunction name="resolvePlanStatus" access="private" returntype="string" output="false">
        <cfargument name="currentStatus" type="any" required="true">
        <cfargument name="returnTime" type="any" required="false">
        <cfargument name="returnTimezone" type="any" required="false">
        <cfargument name="checkedInAt" type="any" required="false">
        <cfargument name="closedAt" type="any" required="false">
        <cfargument name="activatedAt" type="any" required="false">
        <cfscript>
            var statusVal = "";
            if (!isNull(arguments.currentStatus)) {
                statusVal = toString(arguments.currentStatus);
            }
            var statusUpper = ucase(trim(statusVal));
            var hasCheckIn = isDate(arguments.checkedInAt) OR isDate(arguments.closedAt);
            if (hasCheckIn) {
                return "CLOSED";
            }
            if (statusUpper EQ "CLOSED") {
                return "CLOSED";
            }
            if (statusUpper NEQ "ACTIVE" AND statusUpper NEQ "OVERDUE" AND statusUpper NEQ "DRAFT") {
                return arguments.currentStatus;
            }

            var isActivated = isDate(arguments.activatedAt) OR statusUpper EQ "ACTIVE" OR statusUpper EQ "OVERDUE";
            if (NOT isActivated AND statusUpper EQ "DRAFT") {
                return "DRAFT";
            }

            var shouldBeOverdue = false;
            if (isDate(arguments.returnTime)) {
                var returnTimeInFuture = true;
                try {
                    var returnTz = "";
                    if (!isNull(arguments.returnTimezone)) {
                        returnTz = trim(toString(arguments.returnTimezone));
                    }
                    if (len(returnTz)) {
                        var zone = createObject("java", "java.time.ZoneId").of(returnTz);
                        var returnLocal = createObject("java", "java.time.LocalDateTime").of(
                            datePart("yyyy", arguments.returnTime),
                            datePart("m", arguments.returnTime),
                            datePart("d", arguments.returnTime),
                            datePart("h", arguments.returnTime),
                            datePart("n", arguments.returnTime),
                            datePart("s", arguments.returnTime)
                        );
                        var returnZoned = returnLocal.atZone(zone);
                        var nowZoned = createObject("java", "java.time.ZonedDateTime").now(zone);
                        returnTimeInFuture = returnZoned.isAfter(nowZoned);
                    } else {
                        returnTimeInFuture = (dateCompare(now(), arguments.returnTime) LT 0);
                    }
                } catch (any e) {
                    returnTimeInFuture = (dateCompare(now(), arguments.returnTime) LT 0);
                }
                shouldBeOverdue = NOT returnTimeInFuture;
            }

            return shouldBeOverdue ? "OVERDUE" : "ACTIVE";
        </cfscript>
    </cffunction>

    <cffunction name="getOverdueMinutes" access="private" returntype="numeric" output="false">
        <cfargument name="returnTime" type="any" required="false">
        <cfargument name="returnTimezone" type="any" required="false">
        <cfscript>
            if (!isDate(arguments.returnTime)) {
                return -1;
            }

            var minutesOverdue = 0;
            try {
                var returnTz = "";
                if (!isNull(arguments.returnTimezone)) {
                    returnTz = trim(toString(arguments.returnTimezone));
                }
                if (len(returnTz)) {
                    var zone = createObject("java", "java.time.ZoneId").of(returnTz);
                    var returnLocal = createObject("java", "java.time.LocalDateTime").of(
                        datePart("yyyy", arguments.returnTime),
                        datePart("m", arguments.returnTime),
                        datePart("d", arguments.returnTime),
                        datePart("h", arguments.returnTime),
                        datePart("n", arguments.returnTime),
                        datePart("s", arguments.returnTime)
                    );
                    var returnZoned = returnLocal.atZone(zone);
                    var nowZoned = createObject("java", "java.time.ZonedDateTime").now(zone);
                    minutesOverdue = createObject("java", "java.time.Duration").between(returnZoned, nowZoned).toMinutes();
                } else {
                    minutesOverdue = dateDiff("n", arguments.returnTime, now());
                }
            } catch (any e) {
                minutesOverdue = dateDiff("n", arguments.returnTime, now());
            }

            if (minutesOverdue LT 0) {
                return -1;
            }
            return minutesOverdue;
        </cfscript>
    </cffunction>

    <cffunction name="getEscalationLevel" access="private" returntype="string" output="false">
        <cfargument name="minutesOverdue" type="numeric" required="true">
        <cfscript>
            if (arguments.minutesOverdue LT 0) {
                return "";
            }
            if (arguments.minutesOverdue GTE 720) {
                return "final";
            }
            if (arguments.minutesOverdue GTE 180) {
                var hoursOverdue = int(arguments.minutesOverdue / 60);
                return "hourly-" & hoursOverdue;
            }
            if (arguments.minutesOverdue GTE 90) {
                return "overdue-90";
            }
            if (arguments.minutesOverdue GTE 30) {
                return "overdue-30";
            }
            return "due";
        </cfscript>
    </cffunction>

    <cffunction name="resolveNotificationsComponentPath" access="private" returntype="string" output="false">
        <cfscript>
            var webRoot = "";
            var templatePath = getCurrentTemplatePath();
            var relativePath = "";
            var firstSegment = "";
            var prefix = "";
            try {
                webRoot = expandPath("/");
            } catch (any e) {
                webRoot = "";
            }

            if (len(webRoot)) {
                relativePath = replaceNoCase(templatePath, webRoot, "", "one");
            } else {
                relativePath = templatePath;
            }

            relativePath = replace(relativePath, "\", "/", "all");
            if (left(relativePath, 1) EQ "/") {
                relativePath = right(relativePath, len(relativePath) - 1);
            }

            firstSegment = listFirst(relativePath, "/");
            if (len(firstSegment) AND firstSegment NEQ "api") {
                prefix = firstSegment;
            }

            return (len(prefix) ? prefix & "." : "") & "api.v1.notifications";
        </cfscript>
    </cffunction>

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
                    fp.returnTimezone,
                    fp.checkedInAt,
                    fp.closedAt,
                    fp.activatedAt,
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
            <cfset idsToOverdue = []>
            <cfset idsToActive = []>
            <cfset idsToClosed = []>

            <cfloop query="qPlans">
                <cfset statusVal = "">
                <cfif NOT isNull(qPlans.status)>
                    <cfset statusVal = toString(qPlans.status)>
                </cfif>
                <cfset statusUpper = ucase(trim(statusVal))>
                <cfset resolvedStatus = resolvePlanStatus(qPlans.status, qPlans.returnTime, qPlans.returnTimezone, qPlans.checkedInAt, qPlans.closedAt, qPlans.activatedAt)>
                <cfif listFindNoCase("ACTIVE,OVERDUE,DRAFT", statusUpper) GT 0>
                    <cfif resolvedStatus EQ "OVERDUE" AND statusUpper NEQ "OVERDUE">
                        <cfset arrayAppend(idsToOverdue, qPlans.floatplanId)>
                    <cfelseif resolvedStatus EQ "ACTIVE" AND statusUpper NEQ "ACTIVE">
                        <cfset arrayAppend(idsToActive, qPlans.floatplanId)>
                    <cfelseif resolvedStatus EQ "CLOSED">
                        <cfset arrayAppend(idsToClosed, qPlans.floatplanId)>
                    </cfif>
                </cfif>
                <cfset planStruct = {
                    FLOATPLANID    = qPlans.floatplanId,
                    USERID         = qPlans.userId,
                    PLANNAME       = qPlans.floatPlanName,
                    STATUS         = resolvedStatus,
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

            <cfif arrayLen(idsToOverdue)>
                <cfquery name="qStatusToOverdue" datasource="fpw">
                    UPDATE floatplans
                    SET status = 'OVERDUE'
                    WHERE floatplanId IN (
                        <cfqueryparam value="#arrayToList(idsToOverdue)#" cfsqltype="cf_sql_integer" list="true">
                    )
                </cfquery>
            </cfif>

            <cfif arrayLen(idsToActive)>
                <cfquery name="qStatusToActive" datasource="fpw">
                    UPDATE floatplans
                    SET status = 'ACTIVE'
                    WHERE floatplanId IN (
                        <cfqueryparam value="#arrayToList(idsToActive)#" cfsqltype="cf_sql_integer" list="true">
                    )
                </cfquery>
            </cfif>

            <cfif arrayLen(idsToClosed)>
                <cfquery name="qStatusToClosed" datasource="fpw">
                    UPDATE floatplans
                    SET status = 'CLOSED'
                    WHERE floatplanId IN (
                        <cfqueryparam value="#arrayToList(idsToClosed)#" cfsqltype="cf_sql_integer" list="true">
                    )
                </cfquery>
            </cfif>

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

            <cfquery name="qPlansToMonitor" datasource="fpw">
                SELECT
                    floatplanId,
                    status,
                    returnTime,
                    returnTimezone,
                    checkedInAt,
                    closedAt,
                    activatedAt
                FROM floatplans
                WHERE UPPER(TRIM(status)) IN ('ACTIVE', 'OVERDUE', 'DRAFT', 'CLOSED')
            </cfquery>

            <cfset idsToOverdue = []>
            <cfset idsToActive = []>
            <cfset idsToClosed = []>
            <cfset notificationsService = "">
            <cfset notificationsReady = false>
            <cfset local.overdueCandidates = 0>
            <cfset local.overdueNotified = 0>
            <cfset local.overdueMissingReturn = 0>

            <cftry>
                <cfset notificationsService = createObject("component", resolveNotificationsComponentPath()).init()>
                <cfset notificationsReady = true>
                <cfcatch>
                    <cfset notificationsReady = false>
                    <cflog file="application" text="FloatPlanWizard: Notifications service failed to load in runMonitorTick: #cfcatch.message#">
                </cfcatch>
            </cftry>

            <cfloop query="qPlansToMonitor">
                <cfset statusVal = "">
                <cfif NOT isNull(qPlansToMonitor.status)>
                    <cfset statusVal = toString(qPlansToMonitor.status)>
                </cfif>
                <cfset statusUpper = ucase(trim(statusVal))>
                <cfset resolvedStatus = resolvePlanStatus(
                    qPlansToMonitor.status,
                    qPlansToMonitor.returnTime,
                    qPlansToMonitor.returnTimezone,
                    qPlansToMonitor.checkedInAt,
                    qPlansToMonitor.closedAt,
                    qPlansToMonitor.activatedAt
                )>
                <cfif resolvedStatus EQ "OVERDUE">
                    <cfset local.overdueCandidates++>
                    <cfset minutesOverdue = getOverdueMinutes(qPlansToMonitor.returnTime, qPlansToMonitor.returnTimezone)>
                    <cfif minutesOverdue LT 0>
                        <cfset local.overdueMissingReturn++>
                    <cfelseif notificationsReady>
                        <cfset escalationLevel = getEscalationLevel(minutesOverdue)>
                        <cfif len(escalationLevel)>
                            <cftry>
                                <cfset notificationsService.sendOverdueEmail(qPlansToMonitor.floatplanId, escalationLevel)>
                                <cfset local.overdueNotified++>
                                <cfcatch>
                                    <cflog file="application" text="FloatPlanWizard: Overdue email error for plan #qPlansToMonitor.floatplanId#: #cfcatch.message#">
                                </cfcatch>
                            </cftry>
                        </cfif>
                    <cfelse>
                        <cflog file="application" text="FloatPlanWizard: Notifications disabled; overdue email skipped for plan #qPlansToMonitor.floatplanId#">
                    </cfif>
                </cfif>
                <cfif resolvedStatus EQ "OVERDUE" AND statusUpper NEQ "OVERDUE">
                    <cfset arrayAppend(idsToOverdue, qPlansToMonitor.floatplanId)>
                <cfelseif resolvedStatus EQ "ACTIVE" AND statusUpper NEQ "ACTIVE">
                    <cfset arrayAppend(idsToActive, qPlansToMonitor.floatplanId)>
                <cfelseif resolvedStatus EQ "CLOSED">
                    <cfset arrayAppend(idsToClosed, qPlansToMonitor.floatplanId)>
                </cfif>
            </cfloop>

            <cfif arrayLen(idsToOverdue)>
                <cfquery name="qStatusToOverdue" result="qOverdueResult" datasource="fpw">
                    UPDATE floatplans
                    SET status = 'OVERDUE'
                    WHERE floatplanId IN (
                        <cfqueryparam value="#arrayToList(idsToOverdue)#" cfsqltype="cf_sql_integer" list="true">
                    )
                </cfquery>
            <cfelse>
                <cfset qOverdueResult = { recordCount = 0 }>
            </cfif>

            <cfif arrayLen(idsToActive)>
                <cfquery name="qStatusToActive" result="qActiveResult" datasource="fpw">
                    UPDATE floatplans
                    SET status = 'ACTIVE'
                    WHERE floatplanId IN (
                        <cfqueryparam value="#arrayToList(idsToActive)#" cfsqltype="cf_sql_integer" list="true">
                    )
                </cfquery>
            <cfelse>
                <cfset qActiveResult = { recordCount = 0 }>
            </cfif>

            <cfif arrayLen(idsToClosed)>
                <cfquery name="qStatusToClosed" result="qClosedResult" datasource="fpw">
                    UPDATE floatplans
                    SET status = 'CLOSED'
                    WHERE floatplanId IN (
                        <cfqueryparam value="#arrayToList(idsToClosed)#" cfsqltype="cf_sql_integer" list="true">
                    )
                </cfquery>
            <cfelse>
                <cfset qClosedResult = { recordCount = 0 }>
            </cfif>

            <cfset response = {
                SUCCESS = true,
                DATA = {
                    overdueMarked = qOverdueResult.recordCount,
                    activeRestored = qActiveResult.recordCount,
                    closedMarked = qClosedResult.recordCount,
                    overdueCandidates = local.overdueCandidates,
                    overdueNotified = local.overdueNotified,
                    overdueMissingReturn = local.overdueMissingReturn,
                    notificationsReady = notificationsReady
                },
                MESSAGE = ""
            }>
            <cflog file="application" text="FloatPlanWizard: Monitor overdue summary candidates=#local.overdueCandidates# notified=#local.overdueNotified# missingReturn=#local.overdueMissingReturn# notificationsReady=#notificationsReady#">
            <cflog file="floatplan_monitor" text="Monitor tick completed. Overdue plans marked: #qOverdueResult.recordCount#, Active restored: #qActiveResult.recordCount#, Closed marked: #qClosedResult.recordCount#">
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
                    fp.returnTimezone,
                    fp.checkedInAt,
                    fp.closedAt,
                    fp.activatedAt,
                    v.vesselName,
                    TIMESTAMPDIFF(MINUTE, fp.checkedInAt, NOW()) AS minutesSinceCheckIn
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
            <cfset idsToOverdue = []>
            <cfset idsToActive = []>
            <cfset idsToClosed = []>

            <cfloop query="qPlans">
                <cfset planStatus = trim(toString(qPlans.status))>
                <cfset statusUpper = ucase(planStatus)>
                <cfset resolvedStatus = resolvePlanStatus(
                    qPlans.status,
                    qPlans.returnTime,
                    qPlans.returnTimezone,
                    qPlans.checkedInAt,
                    qPlans.closedAt,
                    qPlans.activatedAt
                )>
                <cfset displayName = trim(toString(qPlans.floatPlanName))>
                <cfif NOT len(displayName)>
                    <cfset displayName = "Float Plan ##" & qPlans.floatplanId>
                </cfif>

                <cfif resolvedStatus EQ "ACTIVE">
                    <cfset counts.active++>
                <cfelseif resolvedStatus EQ "OVERDUE">
                    <cfset counts.overdue++>
                </cfif>

                <cfif resolvedStatus EQ "OVERDUE">
                    <cfif isDate(qPlans.returnTime) AND dateCompare(now(), qPlans.returnTime) GT 0>
                        <cfset minutesOverdue = dateDiff("n", qPlans.returnTime, now())>
                        <cfif minutesOverdue LT 0><cfset minutesOverdue = 0></cfif>
                        <cfset isEscalated = dateCompare(now(), dateAdd("n", variables.ESCALATION_DELAY_MINUTES, qPlans.returnTime)) GT 0>
                    <cfelse>
                        <cfset minutesOverdue = 0>
                        <cfset isEscalated = false>
                    </cfif>
                <cfelse>
                    <cfset minutesOverdue = 0>
                    <cfset isEscalated = false>
                </cfif>

                <cfif isEscalated>
                    <cfset counts.escalated++>
                </cfif>

                <cfif resolvedStatus EQ "OVERDUE" AND statusUpper NEQ "OVERDUE">
                    <cfset arrayAppend(idsToOverdue, qPlans.floatplanId)>
                <cfelseif resolvedStatus EQ "ACTIVE" AND statusUpper NEQ "ACTIVE">
                    <cfset arrayAppend(idsToActive, qPlans.floatplanId)>
                <cfelseif resolvedStatus EQ "CLOSED">
                    <cfset arrayAppend(idsToClosed, qPlans.floatplanId)>
                </cfif>

                <cfif resolvedStatus EQ "ACTIVE" OR resolvedStatus EQ "OVERDUE">
                    <cfset planStruct = {
                        floatPlanId = qPlans.floatplanId,
                        status = resolvedStatus,
                        departureDateTime = qPlans.departureTime,
                        returnByDateTime = qPlans.returnTime,
                        lastCheckInDateTime = qPlans.checkedInAt,
                        isEscalated = isEscalated,
                        minutesSinceCheckIn = (isDate(qPlans.checkedInAt) ? qPlans.minutesSinceCheckIn : 0),
                        minutesOverdue = minutesOverdue,
                        displayName = displayName
                    }>
                    <cfset arrayAppend(plans, planStruct)>
                </cfif>
            </cfloop>

            <cfif arrayLen(idsToOverdue)>
                <cfquery name="qStatusToOverdue" datasource="fpw">
                    UPDATE floatplans
                    SET status = 'OVERDUE'
                    WHERE floatplanId IN (
                        <cfqueryparam value="#arrayToList(idsToOverdue)#" cfsqltype="cf_sql_integer" list="true">
                    )
                </cfquery>
            </cfif>

            <cfif arrayLen(idsToActive)>
                <cfquery name="qStatusToActive" datasource="fpw">
                    UPDATE floatplans
                    SET status = 'ACTIVE'
                    WHERE floatplanId IN (
                        <cfqueryparam value="#arrayToList(idsToActive)#" cfsqltype="cf_sql_integer" list="true">
                    )
                </cfquery>
            </cfif>

            <cfif arrayLen(idsToClosed)>
                <cfquery name="qStatusToClosed" datasource="fpw">
                    UPDATE floatplans
                    SET status = 'CLOSED'
                    WHERE floatplanId IN (
                        <cfqueryparam value="#arrayToList(idsToClosed)#" cfsqltype="cf_sql_integer" list="true">
                    )
                </cfquery>
            </cfif>

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
