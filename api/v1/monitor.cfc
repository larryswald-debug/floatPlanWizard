<!--- /fpw/api/v1/monitor.cfc (FULL DROP-IN) --->
<cfcomponent output="true">

    <cffunction name="runOverdueAlerts" access="remote" returntype="any" output="true">
        <cfargument name="token" type="string" required="false" default="">
        <cfargument name="send" type="numeric" required="false" default="0">

        <cfset var expected = "">
        <cfset var svc = "">
        <cfset var plans = []>
        <cfset var jobs  = []>
        <cfset var j     = {}>
        <cfset var allowedStatuses = "ACTIVE,DUE_NOW,OVERDUE_1H,OVERDUE_2H,OVERDUE_3H,OVERDUE_4H,OVERDUE_12H,OVERDUE_24H">

        <cftry>

            <cfif structKeyExists(application,"monitorToken")>
                <cfset expected = trim(toString(application.monitorToken))>
            </cfif>

            <cfif NOT len(expected) OR trim(arguments.token) NEQ expected>
                <cfoutput>UNAUTHORIZED</cfoutput>
                <cfreturn>
            </cfif>

            <cfset var qClock = queryExecute("
                SELECT
                  UTC_TIMESTAMP() AS utcNow,
                  NOW() AS mysqlNow,
                  @@global.time_zone AS globalTZ,
                  @@session.time_zone AS sessionTZ
            ", {}, { datasource="fpw" })>

            <cfoutput>
==============================
FPW OVERDUE ALERT RUN (UTC)
CF now(): #now()#
send: #arguments.send#
==============================<br><br>

DB UTC_TIMESTAMP(): #qClock.utcNow#<br>
DB NOW(): #qClock.mysqlNow#<br>
DB global time_zone: #qClock.globalTZ#<br>
DB session time_zone: #qClock.sessionTZ#<br><br>
            </cfoutput>

            <!-- Summary counts -->
            <cfset var qCounts = queryExecute("
                SELECT
                    SUM(UPPER(TRIM(status)) IN ('ACTIVE','DUE_NOW','OVERDUE_1H','OVERDUE_2H','OVERDUE_3H','OVERDUE_4H','OVERDUE_12H','OVERDUE_24H')) AS activeTotal,
                    SUM(
                        UPPER(TRIM(status)) IN ('ACTIVE','DUE_NOW','OVERDUE_1H','OVERDUE_2H','OVERDUE_3H','OVERDUE_4H','OVERDUE_12H','OVERDUE_24H')
                        AND returnTime IS NOT NULL
                        AND COALESCE(CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), 'UTC'), returnTime) <= UTC_TIMESTAMP()
                    ) AS activeOverdue,
                    SUM(
                        UPPER(TRIM(status)) IN ('ACTIVE','DUE_NOW','OVERDUE_1H','OVERDUE_2H','OVERDUE_3H','OVERDUE_4H','OVERDUE_12H','OVERDUE_24H')
                        AND returnTime IS NOT NULL
                        AND COALESCE(CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), 'UTC'), returnTime) > UTC_TIMESTAMP()
                    ) AS activeNotOverdue
                FROM floatplans
            ", {}, { datasource="fpw" })>

            <cfoutput>
ACTIVE total: #qCounts.activeTotal#<br>
ACTIVE overdue: #qCounts.activeOverdue#<br>
ACTIVE NOT overdue: #qCounts.activeNotOverdue#<br><br>
            </cfoutput>

            <!-- Show NOT overdue plans -->
            <cfset var qNot = queryExecute("
                SELECT
                    floatplanId,
                    returnTime,
                    returnTimezone,
                    COALESCE(CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), 'UTC'), returnTime) AS returnUtc,
                    TIMESTAMPDIFF(
                        SECOND,
                        UTC_TIMESTAMP(),
                        COALESCE(CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), 'UTC'), returnTime)
                    ) AS secondsUntilDue
                FROM floatplans
                WHERE UPPER(TRIM(status)) IN ('ACTIVE','DUE_NOW','OVERDUE_1H','OVERDUE_2H','OVERDUE_3H','OVERDUE_4H','OVERDUE_12H','OVERDUE_24H')
                  AND returnTime IS NOT NULL
                  AND COALESCE(CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), 'UTC'), returnTime) > UTC_TIMESTAMP()
                ORDER BY returnUtc ASC
                LIMIT 50
            ", {}, { datasource="fpw" })>

            <cfoutput>
<b>ACTIVE NOT overdue (future)</b><br>
Rows: #qNot.recordCount#<br>
            </cfoutput>

            <cfif qNot.recordCount GT 0>
                <cfoutput>
<table border="1" cellpadding="4" cellspacing="0">
<tr><th>floatplanId</th><th>returnTime</th><th>secondsUntilDue</th></tr>
                </cfoutput>
                <cfloop query="qNot">
                    <cfoutput>
<tr>
  <td>#qNot.floatplanId#</td>
  <td>#qNot.returnTime#</td>
  <td>#qNot.secondsUntilDue#</td>
</tr>
                    </cfoutput>
                </cfloop>
                <cfoutput></table><br><br></cfoutput>
            <cfelse>
                <cfoutput><i>None found.</i><br><br></cfoutput>
            </cfif>

            <!-- Overdue plans used for job building -->
            <cfset var qOver = queryExecute("
                SELECT
                    floatplanId,
                    returnTime,
                    returnTimezone,
                    COALESCE(CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), 'UTC'), returnTime) AS returnUtc,
                    TIMESTAMPDIFF(
                        SECOND,
                        COALESCE(CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), 'UTC'), returnTime),
                        UTC_TIMESTAMP()
                    ) AS overdueSeconds
                FROM floatplans
                WHERE UPPER(TRIM(status)) IN ('ACTIVE','DUE_NOW','OVERDUE_1H','OVERDUE_2H','OVERDUE_3H','OVERDUE_4H','OVERDUE_12H','OVERDUE_24H')
                  AND returnTime IS NOT NULL
                  AND COALESCE(CONVERT_TZ(returnTime, NULLIF(returnTimezone, ''), 'UTC'), returnTime) <= UTC_TIMESTAMP()
                ORDER BY overdueSeconds DESC
                LIMIT 200
            ", {}, { datasource="fpw" })>

            <cfoutput>
<b>ACTIVE overdue (will be monitored)</b><br>
Rows (showing up to 200): #qOver.recordCount#<br><br>
            </cfoutput>

            <!-- Build plans array -->
            <cfloop query="qOver">
                <cfset arrayAppend(plans,{
                    "FLOATPLANID" = int(val(qOver.floatplanId)),
                    "OVERDUE_SECONDS" = int(val(qOver.overdueSeconds))
                })>
            </cfloop>

            <cfset svc  = createObject("component","fpw.api.v1.OverdueAlertService").init()>
            <cfset jobs = svc.buildOverdueAlertJobs(plans)>

            <cfoutput>
Jobs built: #arrayLen(jobs)#<br><br>
            </cfoutput>

            <cfloop array="#jobs#" index="j">
                <cfoutput>
JOB → plan=#j.FLOATPLANID# type=#j.ALERTTYPE# overdueSeconds=#j.OVERDUE_SECONDS#
                </cfoutput>

                <cfif listFindNoCase(allowedStatuses, toString(j.ALERTTYPE)) GT 0>
                    <cfset queryExecute("
                        UPDATE floatplans
                        SET
                            status = :statusValue,
                            lastUpdateStatus = UTC_TIMESTAMP(),
                            lastUpdate = NOW()
                        WHERE floatplanId = :floatPlanId
                    ", {
                        statusValue = { value = left(toString(j.ALERTTYPE), 50), cfsqltype = "cf_sql_varchar" },
                        floatPlanId = { value = int(val(j.FLOATPLANID)), cfsqltype = "cf_sql_integer" }
                    }, { datasource = "fpw" })>
                    <cfoutput> → STATUS UPDATED (#j.ALERTTYPE#)</cfoutput>
                <cfelse>
                    <cfoutput> → STATUS SKIPPED (ALERTTYPE NOT ALLOWED)</cfoutput>
                </cfif>

                <cfif arguments.send EQ 1>
                    <cftry>
                        <cfset svc.sendOverdueEmail(j)>
                        <cfset svc.markSent(j.FLOATPLANID, j.ALERTTYPE)>
                        <cfoutput> → EMAIL SENT + DB UPDATED</cfoutput>
                        <cfcatch>
                            <cfset svc.markFailed(j.FLOATPLANID, j.ALERTTYPE, cfcatch.message)>
                            <cfoutput> → FAILED: #htmlEditFormat(cfcatch.message)#</cfoutput>
                        </cfcatch>
                    </cftry>
                <cfelse>
                    <cfoutput> → DRY RUN</cfoutput>
                </cfif>

                <cfoutput><br></cfoutput>
            </cfloop>

            <cfcatch>
                <cfoutput>
<br><br>
==============================
MONITOR ERROR (CAUGHT)
==============================<br>
Message: #htmlEditFormat(cfcatch.message)#<br>
Detail: #htmlEditFormat(cfcatch.detail)#<br>
Type: #htmlEditFormat(cfcatch.type)#<br>
Template: #htmlEditFormat(cfcatch.template)#<br>
Line: #cfcatch.line#<br>
==============================<br>
                </cfoutput>
            </cfcatch>

        </cftry>

    </cffunction>

    <cffunction name="runMonitoringEvaluator" access="remote" returntype="void" output="true">
        <cfargument name="token" type="string" required="false" default="">
        <cfargument name="limit" type="numeric" required="false" default="100">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">
        <cfscript>
            var response = {};
            var expectedToken = "";
            var service = "";
            var runResult = {};

            try {
                if (structKeyExists(application, "monitorToken")) {
                    expectedToken = trim(toString(application.monitorToken));
                }

                if (!len(expectedToken) OR trim(arguments.token) NEQ expectedToken) {
                    response = {
                        SUCCESS = false,
                        ERROR = "UNAUTHORIZED",
                        MESSAGE = "Unauthorized."
                    };
                    writeOutput(serializeJSON(response));
                    return;
                }

                service = init();
                runResult = service.evaluateDueMonitoringRows(arguments.limit);
                response = {
                    SUCCESS = structKeyExists(runResult, "SUCCESS") ? runResult.SUCCESS : false,
                    PROCESSED_COUNT = structKeyExists(runResult, "PROCESSED_COUNT") ? runResult.PROCESSED_COUNT : 0,
                    FLOAT_PLAN_IDS = structKeyExists(runResult, "FLOAT_PLAN_IDS") ? runResult.FLOAT_PLAN_IDS : []
                };
                writeOutput(serializeJSON(response));
            } catch (any err) {
                response = {
                    SUCCESS = false,
                    ERROR = "SERVER_ERROR",
                    MESSAGE = err.message
                };
                writeOutput(serializeJSON(response));
            }
        </cfscript>
        <cfsetting enablecfoutputonly="false">
    </cffunction>

    <cffunction name="init" access="public" returntype="any" output="false">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var overnightTimingService = createObject("component", "fpw.api.v1.OvernightTimingService").init();
            variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
            variables.overnightTimingService = overnightTimingService;
            variables.localDayStartRule = overnightTimingService.getLocalDayStartRule();
            variables.activeRouteEveningHour = 18;
            variables.activeRouteEveningMinute = 0;
            variables.activeRouteEveningSecond = 0;
            variables.graceWindowMinutes = 60;
            variables.escalationDelayMinutes = 120;
            variables.allowedMonitoringModes = "basic,active_route";
            variables.allowedMonitorStates = "ACTIVE,LATE,MISSED,ESCALATED,RESOLVED,CLOSED";
            variables.allowedCheckinStatuses = "ON_TRACK,DELAYED,CHANGED_PLAN,NEED_ATTENTION,SECURE_FOR_NIGHT,ARRIVED";
            variables.allowedMonitorEvents = "MONITORING_STARTED,STATE_CHANGED,CHECKIN_RECEIVED,CHECKIN_LATE,CHECKIN_MISSED,CAPTAIN_ALERTED,CONTACT_ALERTED,SECURE_FOR_NIGHT_SET,SECURE_FOR_NIGHT_CLEARED,RESOLVED,MONITORING_CLOSED";
            return this;
        </cfscript>
    </cffunction>

    <cffunction name="startMonitoringForFloatPlan" access="public" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="monitoringMode" type="string" required="true">
        <cfargument name="options" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var result = { SUCCESS = false };
            var modeVal = normalizeMonitoringMode(arguments.monitoringMode);
            var context = {};
            var existing = {};
            var expectedCheckinAt = "";
            var graceExpiresAt = "";
            var nextMonitorEvalAt = "";
            var monitorId = 0;
            var monitoringStartAt = getCurrentUtcTimestamp();

            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }
            if (!len(modeVal)) {
                result.ERROR = "INVALID_MONITORING_MODE";
                result.MESSAGE = "Monitoring mode must be basic or active_route.";
                return result;
            }

            context = loadFloatPlanMonitoringContext(arguments.floatPlanId);
            if (!context.SUCCESS) {
                return context;
            }
            context.monitoring_mode = modeVal;

            expectedCheckinAt = computeNextExpectedCheckin(context, "", arguments.options);
            if (!isDate(expectedCheckinAt)) {
                result.ERROR = "EXPECTED_CHECKIN_UNAVAILABLE";
                result.MESSAGE = "Unable to compute the first expected monitoring checkpoint.";
                return result;
            }
            graceExpiresAt = computeGraceExpiresAt(expectedCheckinAt, variables.graceWindowMinutes);
            nextMonitorEvalAt = computeInitialNextMonitorEvalAt(context, expectedCheckinAt, monitoringStartAt, arguments.options);
            existing = getMonitoringRowByFloatPlanId(arguments.floatPlanId);

            transaction {
                if (existing.SUCCESS) {
                    queryExecute(
                        "UPDATE floatplan_monitoring
                         SET user_id = :userId,
                             monitoring_mode = :monitoringMode,
                             monitor_state = 'ACTIVE',
                             is_monitoring_enabled = 1,
                             expected_checkin_at = :expectedCheckinAt,
                             grace_expires_at = :graceExpiresAt,
                             missed_at = NULL,
                             escalated_at = NULL,
                             resolved_at = NULL,
                             closed_at = NULL,
                             last_checkin_at = NULL,
                             last_checkin_status = NULL,
                             secure_for_night = 0,
                             secure_for_night_until = NULL,
                             escalation_delay_minutes = :escalationDelayMinutes,
                             grace_window_minutes = :graceWindowMinutes,
                             next_monitor_eval_at = :nextMonitorEvalAt,
                             last_monitor_eval_at = NULL,
                             last_captain_alert_at = NULL,
                             last_contact_alert_at = NULL
                         WHERE id = :monitoringId",
                        {
                            userId = { value = context.user_id, cfsqltype = "cf_sql_integer" },
                            monitoringMode = { value = modeVal, cfsqltype = "cf_sql_varchar" },
                            expectedCheckinAt = { value = expectedCheckinAt, cfsqltype = "cf_sql_timestamp" },
                            graceExpiresAt = { value = graceExpiresAt, cfsqltype = "cf_sql_timestamp" },
                            escalationDelayMinutes = { value = variables.escalationDelayMinutes, cfsqltype = "cf_sql_integer" },
                            graceWindowMinutes = { value = variables.graceWindowMinutes, cfsqltype = "cf_sql_integer" },
                            nextMonitorEvalAt = { value = nextMonitorEvalAt, cfsqltype = "cf_sql_timestamp" },
                            monitoringId = { value = existing.id, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = variables.datasource }
                    );
                    monitorId = existing.id;
                } else {
                    queryExecute(
                        "INSERT INTO floatplan_monitoring (
                            float_plan_id,
                            user_id,
                            monitoring_mode,
                            monitor_state,
                            is_monitoring_enabled,
                            expected_checkin_at,
                            grace_expires_at,
                            missed_at,
                            escalated_at,
                            resolved_at,
                            closed_at,
                            last_checkin_at,
                            last_checkin_status,
                            secure_for_night,
                            secure_for_night_until,
                            escalation_delay_minutes,
                            grace_window_minutes,
                            next_monitor_eval_at,
                            last_monitor_eval_at,
                            last_captain_alert_at,
                            last_contact_alert_at,
                            created_at,
                            updated_at
                        ) VALUES (
                            :floatPlanId,
                            :userId,
                            :monitoringMode,
                            'ACTIVE',
                            1,
                            :expectedCheckinAt,
                            :graceExpiresAt,
                            NULL,
                            NULL,
                            NULL,
                            NULL,
                            NULL,
                            NULL,
                            0,
                            NULL,
                            :escalationDelayMinutes,
                            :graceWindowMinutes,
                            :nextMonitorEvalAt,
                            NULL,
                            NULL,
                            NULL,
                            UTC_TIMESTAMP(),
                            UTC_TIMESTAMP()
                        )",
                        {
                            floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                            userId = { value = context.user_id, cfsqltype = "cf_sql_integer" },
                            monitoringMode = { value = modeVal, cfsqltype = "cf_sql_varchar" },
                            expectedCheckinAt = { value = expectedCheckinAt, cfsqltype = "cf_sql_timestamp" },
                            graceExpiresAt = { value = graceExpiresAt, cfsqltype = "cf_sql_timestamp" },
                            escalationDelayMinutes = { value = variables.escalationDelayMinutes, cfsqltype = "cf_sql_integer" },
                            graceWindowMinutes = { value = variables.graceWindowMinutes, cfsqltype = "cf_sql_integer" },
                            nextMonitorEvalAt = { value = nextMonitorEvalAt, cfsqltype = "cf_sql_timestamp" }
                        },
                        { datasource = variables.datasource }
                    );
                    monitorId = val(queryExecute("SELECT LAST_INSERT_ID() AS newId", {}, { datasource = variables.datasource }).newId[1]);
                }

                appendMonitorEvent(monitorId, arguments.floatPlanId, context.user_id, "MONITORING_STARTED", {
                    actorType = "system",
                    eventAt = getCurrentUtcTimestamp(),
                    monitoring_mode = modeVal,
                    expected_checkin_at = expectedCheckinAt,
                    grace_expires_at = graceExpiresAt
                });
            }

            result.SUCCESS = true;
            result.MONITORING_ID = monitorId;
            result.FLOAT_PLAN_ID = arguments.floatPlanId;
            result.MONITORING_MODE = modeVal;
            result.MONITOR_STATE = "ACTIVE";
            result.EXPECTED_CHECKIN_AT = expectedCheckinAt;
            result.GRACE_EXPIRES_AT = graceExpiresAt;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="computeInitialNextMonitorEvalAt" access="private" returntype="any" output="false">
        <cfargument name="monitoringRow" type="struct" required="true">
        <cfargument name="expectedCheckinAt" required="true">
        <cfargument name="monitoringStartAt" required="true">
        <cfargument name="options" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var modeVal = normalizeMonitoringMode(structKeyExists(arguments.monitoringRow, "monitoring_mode") ? arguments.monitoringRow.monitoring_mode : "");
            var nextMonitorEvalAt = arguments.expectedCheckinAt;
            var adjustedOptions = {};

            if (!isDate(nextMonitorEvalAt)) {
                return "";
            }
            if (!isDate(arguments.monitoringStartAt)) {
                return nextMonitorEvalAt;
            }
            if (dateCompare(nextMonitorEvalAt, arguments.monitoringStartAt, "s") GT 0) {
                return nextMonitorEvalAt;
            }

            if (modeVal EQ "active_route") {
                adjustedOptions = duplicate(arguments.options);
                adjustedOptions.baseAt = arguments.monitoringStartAt;
                nextMonitorEvalAt = computeNextExpectedCheckin(arguments.monitoringRow, "", adjustedOptions);
                if (
                    isDate(nextMonitorEvalAt)
                    AND dateCompare(nextMonitorEvalAt, arguments.monitoringStartAt, "s") GT 0
                ) {
                    return nextMonitorEvalAt;
                }
            }

            return computeGraceExpiresAt(arguments.monitoringStartAt, variables.graceWindowMinutes);
        </cfscript>
    </cffunction>

    <cffunction name="recordMonitoringCheckin" access="public" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="checkinStatus" type="string" required="true">
        <cfargument name="options" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var result = { SUCCESS = false };
            var statusVal = normalizeCheckinStatus(arguments.checkinStatus);
            var monitoringRow = {};
            var nowTs = getCurrentUtcTimestamp();
            var nextExpectedCheckin = "";
            var graceExpiresAt = "";
            var secureUntil = "";
            var shouldClearSecure = false;
            var rowBeforeTransition = {};
            var activeState = "";

            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }
            if (!len(statusVal)) {
                result.ERROR = "INVALID_CHECKIN_STATUS";
                result.MESSAGE = "Check-in status is invalid.";
                return result;
            }

            if (structKeyExists(arguments.options, "nowTs") AND isDate(arguments.options.nowTs)) {
                nowTs = arguments.options.nowTs;
            }

            monitoringRow = getMonitoringRowByFloatPlanId(arguments.floatPlanId);
            if (!monitoringRow.SUCCESS) {
                return monitoringRow;
            }
            if (!booleanValue(monitoringRow.is_monitoring_enabled)) {
                result.ERROR = "MONITORING_DISABLED";
                result.MESSAGE = "Monitoring is not enabled for this float plan.";
                return result;
            }
            if (monitoringRow.monitor_state EQ "CLOSED") {
                result.ERROR = "MONITORING_CLOSED";
                result.MESSAGE = "Monitoring is already closed for this float plan.";
                return result;
            }
            if (statusVal EQ "ARRIVED") {
                result.ERROR = "FINAL_CLOSE_REQUIRED";
                result.MESSAGE = "ARRIVED is only handled through the explicit trip-close path in this phase.";
                return result;
            }

            shouldClearSecure = (
                monitoringRow.monitoring_mode EQ "active_route"
                AND booleanValue(monitoringRow.secure_for_night)
                AND statusVal NEQ "SECURE_FOR_NIGHT"
            );

            transaction {
                appendMonitorEvent(monitoringRow.id, monitoringRow.float_plan_id, monitoringRow.user_id, "CHECKIN_RECEIVED", {
                    actorType = "captain",
                    eventAt = nowTs,
                    checkinStatus = statusVal
                });

                if (shouldClearSecure) {
                    queryExecute(
                        "UPDATE floatplan_monitoring
                         SET secure_for_night = 0,
                             secure_for_night_until = NULL
                         WHERE id = :monitoringId",
                        {
                            monitoringId = { value = monitoringRow.id, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = variables.datasource }
                    );
                    appendMonitorEvent(monitoringRow.id, monitoringRow.float_plan_id, monitoringRow.user_id, "SECURE_FOR_NIGHT_CLEARED", {
                        actorType = "captain",
                        eventAt = nowTs
                    });
                    monitoringRow.secure_for_night = 0;
                    monitoringRow.secure_for_night_until = "";
                }

                if (listFindNoCase("MISSED,ESCALATED", monitoringRow.monitor_state)) {
                    transitionMonitorState(monitoringRow.id, monitoringRow.monitor_state, "RESOLVED", {
                        actorType = "captain",
                        eventAt = nowTs,
                        resolution_reason = "valid_checkin",
                        checkinStatus = statusVal
                    });
                    queryExecute(
                        "UPDATE floatplan_monitoring
                         SET resolved_at = :resolvedAt,
                             last_checkin_at = :lastCheckinAt,
                             last_checkin_status = :lastCheckinStatus,
                             last_monitor_eval_at = :lastMonitorEvalAt
                         WHERE id = :monitoringId",
                        {
                            resolvedAt = { value = nowTs, cfsqltype = "cf_sql_timestamp" },
                            lastCheckinAt = { value = nowTs, cfsqltype = "cf_sql_timestamp" },
                            lastCheckinStatus = { value = statusVal, cfsqltype = "cf_sql_varchar" },
                            lastMonitorEvalAt = { value = nowTs, cfsqltype = "cf_sql_timestamp" },
                            monitoringId = { value = monitoringRow.id, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = variables.datasource }
                    );
                    appendMonitorEvent(monitoringRow.id, monitoringRow.float_plan_id, monitoringRow.user_id, "RESOLVED", {
                        actorType = "captain",
                        eventAt = nowTs,
                        checkinStatus = statusVal
                    });
                    rowBeforeTransition = duplicate(monitoringRow);
                    rowBeforeTransition.monitor_state = "RESOLVED";
                } else {
                    rowBeforeTransition = duplicate(monitoringRow);
                    queryExecute(
                        "UPDATE floatplan_monitoring
                         SET last_checkin_at = :lastCheckinAt,
                             last_checkin_status = :lastCheckinStatus,
                             last_monitor_eval_at = :lastMonitorEvalAt
                         WHERE id = :monitoringId",
                        {
                            lastCheckinAt = { value = nowTs, cfsqltype = "cf_sql_timestamp" },
                            lastCheckinStatus = { value = statusVal, cfsqltype = "cf_sql_varchar" },
                            lastMonitorEvalAt = { value = nowTs, cfsqltype = "cf_sql_timestamp" },
                            monitoringId = { value = monitoringRow.id, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = variables.datasource }
                    );
                }

                if (monitoringRow.monitoring_mode EQ "active_route" AND statusVal EQ "SECURE_FOR_NIGHT") {
                    secureUntil = computeSecureForNightUntil(monitoringRow, { baseAt = nowTs });
                    if (!isDate(secureUntil)) {
                        throw(message = "Unable to compute secure-for-night checkpoint.", detail = "SECURE_FOR_NIGHT checkpoint calculation failed.");
                    }
                    nextExpectedCheckin = secureUntil;
                    graceExpiresAt = computeGraceExpiresAt(nextExpectedCheckin, monitoringRow.grace_window_minutes);

                    queryExecute(
                        "UPDATE floatplan_monitoring
                         SET monitor_state = 'ACTIVE',
                             expected_checkin_at = :expectedCheckinAt,
                             grace_expires_at = :graceExpiresAt,
                             secure_for_night = 1,
                             secure_for_night_until = :secureForNightUntil,
                             next_monitor_eval_at = :nextMonitorEvalAt,
                             last_checkin_at = :lastCheckinAt,
                             last_checkin_status = :lastCheckinStatus,
                             missed_at = NULL,
                             escalated_at = NULL,
                             last_captain_alert_at = NULL,
                             last_contact_alert_at = NULL,
                             last_monitor_eval_at = :lastMonitorEvalAt
                         WHERE id = :monitoringId",
                        {
                            expectedCheckinAt = { value = nextExpectedCheckin, cfsqltype = "cf_sql_timestamp" },
                            graceExpiresAt = { value = graceExpiresAt, cfsqltype = "cf_sql_timestamp" },
                            secureForNightUntil = { value = secureUntil, cfsqltype = "cf_sql_timestamp" },
                            nextMonitorEvalAt = { value = nextExpectedCheckin, cfsqltype = "cf_sql_timestamp" },
                            lastCheckinAt = { value = nowTs, cfsqltype = "cf_sql_timestamp" },
                            lastCheckinStatus = { value = statusVal, cfsqltype = "cf_sql_varchar" },
                            lastMonitorEvalAt = { value = nowTs, cfsqltype = "cf_sql_timestamp" },
                            monitoringId = { value = monitoringRow.id, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = variables.datasource }
                    );
                    appendMonitorEvent(monitoringRow.id, monitoringRow.float_plan_id, monitoringRow.user_id, "SECURE_FOR_NIGHT_SET", {
                        actorType = "captain",
                        eventAt = nowTs,
                        secure_for_night_until = secureUntil
                    });
                } else {
                    nextExpectedCheckin = computeNextExpectedCheckin(rowBeforeTransition, statusVal, { baseAt = nowTs });
                    if (!isDate(nextExpectedCheckin)) {
                        throw(message = "Unable to compute next expected monitoring checkpoint.", detail = "Expected monitoring checkpoint calculation failed.");
                    }
                    graceExpiresAt = computeGraceExpiresAt(nextExpectedCheckin, rowBeforeTransition.grace_window_minutes);

                    queryExecute(
                        "UPDATE floatplan_monitoring
                         SET monitor_state = 'ACTIVE',
                             expected_checkin_at = :expectedCheckinAt,
                             grace_expires_at = :graceExpiresAt,
                             secure_for_night = 0,
                             secure_for_night_until = NULL,
                             next_monitor_eval_at = :nextMonitorEvalAt,
                             last_checkin_at = :lastCheckinAt,
                             last_checkin_status = :lastCheckinStatus,
                             missed_at = NULL,
                             escalated_at = NULL,
                             last_captain_alert_at = NULL,
                             last_contact_alert_at = NULL,
                             last_monitor_eval_at = :lastMonitorEvalAt
                         WHERE id = :monitoringId",
                        {
                            expectedCheckinAt = { value = nextExpectedCheckin, cfsqltype = "cf_sql_timestamp" },
                            graceExpiresAt = { value = graceExpiresAt, cfsqltype = "cf_sql_timestamp" },
                            nextMonitorEvalAt = { value = nextExpectedCheckin, cfsqltype = "cf_sql_timestamp" },
                            lastCheckinAt = { value = nowTs, cfsqltype = "cf_sql_timestamp" },
                            lastCheckinStatus = { value = statusVal, cfsqltype = "cf_sql_varchar" },
                            lastMonitorEvalAt = { value = nowTs, cfsqltype = "cf_sql_timestamp" },
                            monitoringId = { value = monitoringRow.id, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = variables.datasource }
                    );
                }

                activeState = rowBeforeTransition.monitor_state;
                if (activeState NEQ "ACTIVE") {
                    transitionMonitorState(monitoringRow.id, activeState, "ACTIVE", {
                        actorType = "captain",
                        eventAt = nowTs,
                        checkinStatus = statusVal,
                        next_expected_checkin_at = nextExpectedCheckin
                    });
                }
            }

            result.SUCCESS = true;
            result.MONITORING_ID = monitoringRow.id;
            result.FLOAT_PLAN_ID = monitoringRow.float_plan_id;
            result.MONITOR_STATE = "ACTIVE";
            result.LAST_CHECKIN_STATUS = statusVal;
            result.EXPECTED_CHECKIN_AT = nextExpectedCheckin;
            result.GRACE_EXPIRES_AT = graceExpiresAt;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="evaluateMonitoringCycle" access="public" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = { SUCCESS = false };
            var monitoringRow = {};
            var nowTs = getCurrentUtcTimestamp();
            var escalationAt = "";

            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }

            monitoringRow = getMonitoringRowByFloatPlanId(arguments.floatPlanId);
            if (!monitoringRow.SUCCESS) {
                return monitoringRow;
            }
            if (!booleanValue(monitoringRow.is_monitoring_enabled) OR monitoringRow.monitor_state EQ "CLOSED") {
                result.SUCCESS = true;
                result.SKIPPED = true;
                result.REASON = "DISABLED_OR_CLOSED";
                return result;
            }

            transaction {
                if (isOvernightSuppressed(monitoringRow, nowTs)) {
                    queryExecute(
                        "UPDATE floatplan_monitoring
                         SET last_monitor_eval_at = :lastMonitorEvalAt,
                             next_monitor_eval_at = :nextMonitorEvalAt
                         WHERE id = :monitoringId",
                        {
                            lastMonitorEvalAt = { value = nowTs, cfsqltype = "cf_sql_timestamp" },
                            nextMonitorEvalAt = { value = monitoringRow.expected_checkin_at, cfsqltype = "cf_sql_timestamp" },
                            monitoringId = { value = monitoringRow.id, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = variables.datasource }
                    );
                    result.SUCCESS = true;
                    result.SKIPPED = true;
                    result.REASON = "OVERNIGHT_SUPPRESSED";
                    result.MONITOR_STATE = monitoringRow.monitor_state;
                    return result;
                }

                if (
                    monitoringRow.monitor_state EQ "MISSED"
                    AND isDate(monitoringRow.missed_at)
                    AND dateCompare(nowTs, dateAdd("n", monitoringRow.escalation_delay_minutes, monitoringRow.missed_at), "s") GT 0
                ) {
                    transitionMonitorState(monitoringRow.id, "MISSED", "ESCALATED", {
                        actorType = "system",
                        eventAt = nowTs,
                        evaluator_path = "missed_to_escalated"
                    });
                    queryExecute(
                        "UPDATE floatplan_monitoring
                         SET escalated_at = COALESCE(escalated_at, :escalatedAt),
                             last_monitor_eval_at = :lastMonitorEvalAt,
                             next_monitor_eval_at = NULL
                         WHERE id = :monitoringId",
                        {
                            escalatedAt = { value = nowTs, cfsqltype = "cf_sql_timestamp" },
                            lastMonitorEvalAt = { value = nowTs, cfsqltype = "cf_sql_timestamp" },
                            monitoringId = { value = monitoringRow.id, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = variables.datasource }
                    );
                    markContactAlertEligible(monitoringRow, nowTs);
                    result.SUCCESS = true;
                    result.MONITOR_STATE = "ESCALATED";
                    return result;
                }

                if (
                    isDate(monitoringRow.grace_expires_at)
                    AND dateCompare(nowTs, monitoringRow.grace_expires_at, "s") GT 0
                    AND listFindNoCase("ACTIVE,LATE", monitoringRow.monitor_state)
                ) {
                    transitionMonitorState(monitoringRow.id, monitoringRow.monitor_state, "MISSED", {
                        actorType = "system",
                        eventAt = nowTs,
                        evaluator_path = "late_to_missed"
                    });
                    queryExecute(
                        "UPDATE floatplan_monitoring
                         SET missed_at = COALESCE(missed_at, :missedAt),
                             last_monitor_eval_at = :lastMonitorEvalAt,
                             next_monitor_eval_at = :nextMonitorEvalAt
                         WHERE id = :monitoringId",
                        {
                            missedAt = { value = nowTs, cfsqltype = "cf_sql_timestamp" },
                            lastMonitorEvalAt = { value = nowTs, cfsqltype = "cf_sql_timestamp" },
                            nextMonitorEvalAt = { value = dateAdd("n", monitoringRow.escalation_delay_minutes, nowTs), cfsqltype = "cf_sql_timestamp" },
                            monitoringId = { value = monitoringRow.id, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = variables.datasource }
                    );
                    appendMonitorEvent(monitoringRow.id, monitoringRow.float_plan_id, monitoringRow.user_id, "CHECKIN_MISSED", {
                        actorType = "system",
                        eventAt = nowTs
                    });
                    markCaptainAlertEligible(monitoringRow, nowTs);
                    result.SUCCESS = true;
                    result.MONITOR_STATE = "MISSED";
                    return result;
                }

                if (
                    monitoringRow.monitor_state EQ "ACTIVE"
                    AND isDate(monitoringRow.expected_checkin_at)
                    AND isDate(monitoringRow.grace_expires_at)
                    AND dateCompare(nowTs, monitoringRow.expected_checkin_at, "s") GT 0
                    AND dateCompare(nowTs, monitoringRow.grace_expires_at, "s") LTE 0
                ) {
                    transitionMonitorState(monitoringRow.id, "ACTIVE", "LATE", {
                        actorType = "system",
                        eventAt = nowTs,
                        evaluator_path = "active_to_late"
                    });
                    queryExecute(
                        "UPDATE floatplan_monitoring
                         SET last_monitor_eval_at = :lastMonitorEvalAt,
                             next_monitor_eval_at = :nextMonitorEvalAt
                         WHERE id = :monitoringId",
                        {
                            lastMonitorEvalAt = { value = nowTs, cfsqltype = "cf_sql_timestamp" },
                            nextMonitorEvalAt = { value = monitoringRow.grace_expires_at, cfsqltype = "cf_sql_timestamp" },
                            monitoringId = { value = monitoringRow.id, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = variables.datasource }
                    );
                    appendMonitorEvent(monitoringRow.id, monitoringRow.float_plan_id, monitoringRow.user_id, "CHECKIN_LATE", {
                        actorType = "system",
                        eventAt = nowTs
                    });
                    result.SUCCESS = true;
                    result.MONITOR_STATE = "LATE";
                    return result;
                }

                queryExecute(
                    "UPDATE floatplan_monitoring
                     SET last_monitor_eval_at = :lastMonitorEvalAt
                     WHERE id = :monitoringId",
                    {
                        lastMonitorEvalAt = { value = nowTs, cfsqltype = "cf_sql_timestamp" },
                        monitoringId = { value = monitoringRow.id, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = variables.datasource }
                );
            }

            result.SUCCESS = true;
            result.SKIPPED = true;
            result.REASON = "NO_STATE_CHANGE";
            result.MONITOR_STATE = monitoringRow.monitor_state;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="evaluateDueMonitoringRows" access="public" returntype="struct" output="false">
        <cfargument name="limit" type="numeric" required="false" default="100">
        <cfscript>
            var result = {
                SUCCESS = true,
                PROCESSED_COUNT = 0,
                FLOAT_PLAN_IDS = [],
                RESULTS = []
            };
            var qDue = queryNew("");
            var rowResult = {};
            var maxRows = arguments.limit;
            var i = 0;

            if (maxRows LTE 0) {
                maxRows = 100;
            }

            qDue = queryExecute(
                "SELECT float_plan_id
                 FROM floatplan_monitoring
                 WHERE is_monitoring_enabled = 1
                   AND monitor_state <> 'CLOSED'
                   AND next_monitor_eval_at IS NOT NULL
                   AND next_monitor_eval_at <= UTC_TIMESTAMP()
                 ORDER BY next_monitor_eval_at ASC, id ASC
                 LIMIT #maxRows#",
                {},
                { datasource = variables.datasource }
            );

            for (i = 1; i LTE qDue.recordCount; i++) {
                rowResult = evaluateMonitoringCycle(val(qDue.float_plan_id[i]));
                arrayAppend(result.FLOAT_PLAN_IDS, val(qDue.float_plan_id[i]));
                arrayAppend(result.RESULTS, rowResult);
            }

            result.PROCESSED_COUNT = arrayLen(result.FLOAT_PLAN_IDS);
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="closeMonitoringForFloatPlan" access="public" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="reason" type="string" required="false" default="normal">
        <cfscript>
            var result = { SUCCESS = false };
            var monitoringRow = {};
            var nowTs = getCurrentUtcTimestamp();
            var actorType = "system";

            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }

            monitoringRow = getMonitoringRowByFloatPlanId(arguments.floatPlanId);
            if (!monitoringRow.SUCCESS) {
                return monitoringRow;
            }

            if (lCase(trim(arguments.reason)) EQ "final_arrival") {
                actorType = "captain";
            }

            transaction {
                if (monitoringRow.monitor_state NEQ "CLOSED") {
                    transitionMonitorState(monitoringRow.id, monitoringRow.monitor_state, "CLOSED", {
                        actorType = actorType,
                        eventAt = nowTs,
                        close_reason = trim(arguments.reason)
                    });
                }
                queryExecute(
                    "UPDATE floatplan_monitoring
                     SET monitor_state = 'CLOSED',
                         is_monitoring_enabled = 0,
                         closed_at = :closedAt,
                         next_monitor_eval_at = NULL,
                         secure_for_night = 0,
                         secure_for_night_until = NULL,
                         last_monitor_eval_at = :lastMonitorEvalAt
                     WHERE id = :monitoringId",
                    {
                        closedAt = { value = nowTs, cfsqltype = "cf_sql_timestamp" },
                        lastMonitorEvalAt = { value = nowTs, cfsqltype = "cf_sql_timestamp" },
                        monitoringId = { value = monitoringRow.id, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = variables.datasource }
                );
                appendMonitorEvent(monitoringRow.id, monitoringRow.float_plan_id, monitoringRow.user_id, "MONITORING_CLOSED", {
                    actorType = actorType,
                    eventAt = nowTs,
                    close_reason = trim(arguments.reason)
                });
            }

            result.SUCCESS = true;
            result.MONITORING_ID = monitoringRow.id;
            result.FLOAT_PLAN_ID = monitoringRow.float_plan_id;
            result.MONITOR_STATE = "CLOSED";
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="loadFloatPlanMonitoringContext" access="private" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = { SUCCESS = false };
            var qPlan = queryExecute(
                "SELECT
                    floatplanId,
                    userId,
                    route_instance_id,
                    departureTime,
                    departTimezone,
                    departureTZ,
                    returnTime,
                    returnTimezone,
                    returnTZ,
                    dailyStartLocalTime,
                    activatedAt,
                    UPPER(TRIM(`status`)) AS statusValue
                 FROM floatplans
                 WHERE floatplanId = :planId
                 LIMIT 1",
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );
            if (qPlan.recordCount EQ 0) {
                result.ERROR = "NOT_FOUND";
                result.MESSAGE = "Float plan not found.";
                return result;
            }

            result.SUCCESS = true;
            result.id = 0;
            result.float_plan_id = val(qPlan.floatplanId[1]);
            result.user_id = val(qPlan.userId[1]);
            result.monitoring_mode = "";
            result.monitor_state = "";
            result.is_monitoring_enabled = 0;
            result.expected_checkin_at = "";
            result.grace_expires_at = "";
            result.missed_at = "";
            result.escalated_at = "";
            result.resolved_at = "";
            result.closed_at = "";
            result.last_checkin_at = "";
            result.last_checkin_status = "";
            result.secure_for_night = 0;
            result.secure_for_night_until = "";
            result.escalation_delay_minutes = variables.escalationDelayMinutes;
            result.grace_window_minutes = variables.graceWindowMinutes;
            result.next_monitor_eval_at = "";
            result.last_monitor_eval_at = "";
            result.trip_start_at = (!isNull(qPlan.departureTime[1]) AND isDate(qPlan.departureTime[1])) ? qPlan.departureTime[1] : "";
            result.departure_time = result.trip_start_at;
            result.departure_timezone = (isNull(qPlan.departureTZ[1]) ? "" : trim(toString(qPlan.departureTZ[1])));
            if (!len(result.departure_timezone)) {
                result.departure_timezone = (isNull(qPlan.departTimezone[1]) ? "" : trim(toString(qPlan.departTimezone[1])));
            }
            result.return_time = (!isNull(qPlan.returnTime[1]) AND isDate(qPlan.returnTime[1])) ? qPlan.returnTime[1] : "";
            result.return_timezone = (isNull(qPlan.returnTZ[1]) ? "" : trim(toString(qPlan.returnTZ[1])));
            if (!len(result.return_timezone)) {
                result.return_timezone = (isNull(qPlan.returnTimezone[1]) ? "" : trim(toString(qPlan.returnTimezone[1])));
            }
            result.daily_start_local_time = (isNull(qPlan.dailyStartLocalTime[1]) ? "" : trim(toString(qPlan.dailyStartLocalTime[1])));
            result.route_instance_id = (isNull(qPlan.route_instance_id[1]) ? 0 : val(qPlan.route_instance_id[1]));
            result.plan_status = (isNull(qPlan.statusValue[1]) ? "" : trim(toString(qPlan.statusValue[1])));
            result.activated_at = (!isNull(qPlan.activatedAt[1]) AND isDate(qPlan.activatedAt[1])) ? qPlan.activatedAt[1] : "";
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="getMonitoringRowByFloatPlanId" access="private" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = { SUCCESS = false };
            var qRow = queryExecute(
                "SELECT
                    m.id,
                    m.float_plan_id,
                    m.user_id,
                    m.monitoring_mode,
                    m.monitor_state,
                    m.is_monitoring_enabled,
                    m.expected_checkin_at,
                    m.grace_expires_at,
                    m.missed_at,
                    m.escalated_at,
                    m.resolved_at,
                    m.closed_at,
                    m.last_checkin_at,
                    m.last_checkin_status,
                    m.secure_for_night,
                    m.secure_for_night_until,
                    m.escalation_delay_minutes,
                    m.grace_window_minutes,
                    m.next_monitor_eval_at,
                    m.last_monitor_eval_at,
                    m.last_captain_alert_at,
                    m.last_contact_alert_at,
                    fp.departureTime,
                    fp.departTimezone,
                    fp.departureTZ,
                    fp.returnTime,
                    fp.returnTimezone,
                    fp.returnTZ,
                    fp.dailyStartLocalTime,
                    fp.activatedAt
                 FROM floatplan_monitoring m
                 INNER JOIN floatplans fp
                    ON fp.floatplanId = m.float_plan_id
                 WHERE m.float_plan_id = :floatPlanId
                 LIMIT 1",
                {
                    floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );
            if (qRow.recordCount EQ 0) {
                result.ERROR = "MONITORING_NOT_FOUND";
                result.MESSAGE = "No monitoring row exists for this float plan.";
                return result;
            }

            result.SUCCESS = true;
            result.id = val(qRow.id[1]);
            result.float_plan_id = val(qRow.float_plan_id[1]);
            result.user_id = val(qRow.user_id[1]);
            result.monitoring_mode = trim(toString(qRow.monitoring_mode[1]));
            result.monitor_state = trim(toString(qRow.monitor_state[1]));
            result.is_monitoring_enabled = booleanValue(qRow.is_monitoring_enabled[1]);
            result.expected_checkin_at = (!isNull(qRow.expected_checkin_at[1]) AND isDate(qRow.expected_checkin_at[1])) ? qRow.expected_checkin_at[1] : "";
            result.grace_expires_at = (!isNull(qRow.grace_expires_at[1]) AND isDate(qRow.grace_expires_at[1])) ? qRow.grace_expires_at[1] : "";
            result.missed_at = (!isNull(qRow.missed_at[1]) AND isDate(qRow.missed_at[1])) ? qRow.missed_at[1] : "";
            result.escalated_at = (!isNull(qRow.escalated_at[1]) AND isDate(qRow.escalated_at[1])) ? qRow.escalated_at[1] : "";
            result.resolved_at = (!isNull(qRow.resolved_at[1]) AND isDate(qRow.resolved_at[1])) ? qRow.resolved_at[1] : "";
            result.closed_at = (!isNull(qRow.closed_at[1]) AND isDate(qRow.closed_at[1])) ? qRow.closed_at[1] : "";
            result.last_checkin_at = (!isNull(qRow.last_checkin_at[1]) AND isDate(qRow.last_checkin_at[1])) ? qRow.last_checkin_at[1] : "";
            result.last_checkin_status = (isNull(qRow.last_checkin_status[1]) ? "" : trim(toString(qRow.last_checkin_status[1])));
            result.secure_for_night = booleanValue(qRow.secure_for_night[1]);
            result.secure_for_night_until = (!isNull(qRow.secure_for_night_until[1]) AND isDate(qRow.secure_for_night_until[1])) ? qRow.secure_for_night_until[1] : "";
            result.escalation_delay_minutes = isNull(qRow.escalation_delay_minutes[1]) ? variables.escalationDelayMinutes : val(qRow.escalation_delay_minutes[1]);
            result.grace_window_minutes = isNull(qRow.grace_window_minutes[1]) ? variables.graceWindowMinutes : val(qRow.grace_window_minutes[1]);
            result.next_monitor_eval_at = (!isNull(qRow.next_monitor_eval_at[1]) AND isDate(qRow.next_monitor_eval_at[1])) ? qRow.next_monitor_eval_at[1] : "";
            result.last_monitor_eval_at = (!isNull(qRow.last_monitor_eval_at[1]) AND isDate(qRow.last_monitor_eval_at[1])) ? qRow.last_monitor_eval_at[1] : "";
            result.last_captain_alert_at = (!isNull(qRow.last_captain_alert_at[1]) AND isDate(qRow.last_captain_alert_at[1])) ? qRow.last_captain_alert_at[1] : "";
            result.last_contact_alert_at = (!isNull(qRow.last_contact_alert_at[1]) AND isDate(qRow.last_contact_alert_at[1])) ? qRow.last_contact_alert_at[1] : "";
            result.trip_start_at = (!isNull(qRow.departureTime[1]) AND isDate(qRow.departureTime[1])) ? qRow.departureTime[1] : "";
            result.departure_time = result.trip_start_at;
            result.departure_timezone = (isNull(qRow.departureTZ[1]) ? "" : trim(toString(qRow.departureTZ[1])));
            if (!len(result.departure_timezone)) {
                result.departure_timezone = (isNull(qRow.departTimezone[1]) ? "" : trim(toString(qRow.departTimezone[1])));
            }
            result.return_time = (!isNull(qRow.returnTime[1]) AND isDate(qRow.returnTime[1])) ? qRow.returnTime[1] : "";
            result.return_timezone = (isNull(qRow.returnTZ[1]) ? "" : trim(toString(qRow.returnTZ[1])));
            if (!len(result.return_timezone)) {
                result.return_timezone = (isNull(qRow.returnTimezone[1]) ? "" : trim(toString(qRow.returnTimezone[1])));
            }
            result.daily_start_local_time = (isNull(qRow.dailyStartLocalTime[1]) ? "" : trim(toString(qRow.dailyStartLocalTime[1])));
            result.activated_at = (!isNull(qRow.activatedAt[1]) AND isDate(qRow.activatedAt[1])) ? qRow.activatedAt[1] : "";
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="computeNextExpectedCheckin" access="private" returntype="any" output="false">
        <cfargument name="monitoringRow" type="struct" required="true">
        <cfargument name="checkinStatus" type="string" required="false" default="">
        <cfargument name="options" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var modeVal = normalizeMonitoringMode(structKeyExists(arguments.monitoringRow, "monitoring_mode") ? arguments.monitoringRow.monitoring_mode : "");
            var statusVal = normalizeCheckinStatus(arguments.checkinStatus);
            var baseAt = "";
            var timeZoneId = "";
            if (modeVal EQ "basic") {
                if (structKeyExists(arguments.monitoringRow, "return_time") AND isDate(arguments.monitoringRow.return_time)) {
                    return arguments.monitoringRow.return_time;
                }
                return "";
            }
            if (modeVal NEQ "active_route") {
                return "";
            }

            timeZoneId = getActiveRouteTimeZoneId(arguments.monitoringRow);
            if (!len(timeZoneId)) {
                return "";
            }

            if (structKeyExists(arguments.options, "baseAt") AND isDate(arguments.options.baseAt)) {
                baseAt = arguments.options.baseAt;
            } else if (len(statusVal) AND structKeyExists(arguments.monitoringRow, "last_checkin_at") AND isDate(arguments.monitoringRow.last_checkin_at)) {
                baseAt = arguments.monitoringRow.last_checkin_at;
            } else if (structKeyExists(arguments.monitoringRow, "trip_start_at") AND isDate(arguments.monitoringRow.trip_start_at)) {
                baseAt = arguments.monitoringRow.trip_start_at;
            }

            if (!isDate(baseAt)) {
                return "";
            }

            if (statusVal EQ "SECURE_FOR_NIGHT") {
                return computeSecureForNightUntil(arguments.monitoringRow, { baseAt = baseAt });
            }

            return computeActiveRouteCheckpoint(baseAt, timeZoneId, false, arguments.monitoringRow);
        </cfscript>
    </cffunction>

    <cffunction name="computeGraceExpiresAt" access="private" returntype="any" output="false">
        <cfargument name="expectedCheckinAt" required="true">
        <cfargument name="graceMinutes" type="numeric" required="true">
        <cfscript>
            if (!isDate(arguments.expectedCheckinAt)) {
                return "";
            }
            return dateAdd("n", arguments.graceMinutes, arguments.expectedCheckinAt);
        </cfscript>
    </cffunction>

    <cffunction name="computeSecureForNightUntil" access="private" returntype="any" output="false">
        <cfargument name="monitoringRow" type="struct" required="true">
        <cfargument name="options" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var timeZoneId = getActiveRouteTimeZoneId(arguments.monitoringRow);
            var baseAt = "";
            var localReference = "";
            var targetLocal = "";
            var localDayStartRule = resolveMonitoringRowLocalDayStartRule(arguments.monitoringRow);
            if (!len(timeZoneId)) {
                return "";
            }
            if (structKeyExists(arguments.options, "baseAt") AND isDate(arguments.options.baseAt)) {
                baseAt = arguments.options.baseAt;
            } else if (structKeyExists(arguments.monitoringRow, "last_checkin_at") AND isDate(arguments.monitoringRow.last_checkin_at)) {
                baseAt = arguments.monitoringRow.last_checkin_at;
            } else {
                baseAt = getCurrentUtcTimestamp();
            }
            localReference = convertUtcToLocal(baseAt, timeZoneId);
            if (!isDate(localReference)) {
                return "";
            }
            if (structKeyExists(arguments.options, "allowSameDayFuture") AND arguments.options.allowSameDayFuture EQ true) {
                targetLocal = buildLocalDateTime(
                    localReference,
                    localDayStartRule.local_day_start_hour,
                    localDayStartRule.local_day_start_minute,
                    localDayStartRule.local_day_start_second
                );
                if (!isDate(targetLocal) OR dateCompare(targetLocal, localReference, "s") LTE 0) {
                    targetLocal = buildLocalDateTime(
                        dateAdd("d", 1, localReference),
                        localDayStartRule.local_day_start_hour,
                        localDayStartRule.local_day_start_minute,
                        localDayStartRule.local_day_start_second
                    );
                }
            } else {
                targetLocal = buildLocalDateTime(
                    dateAdd("d", 1, localReference),
                    localDayStartRule.local_day_start_hour,
                    localDayStartRule.local_day_start_minute,
                    localDayStartRule.local_day_start_second
                );
            }
            return convertLocalToUtc(targetLocal, timeZoneId);
        </cfscript>
    </cffunction>

    <cffunction name="isOvernightSuppressed" access="private" returntype="boolean" output="false">
        <cfargument name="monitoringRow" type="struct" required="true">
        <cfargument name="nowTs" required="true">
        <cfscript>
            return (
                structKeyExists(arguments.monitoringRow, "monitoring_mode")
                AND arguments.monitoringRow.monitoring_mode EQ "active_route"
                AND booleanValue(structKeyExists(arguments.monitoringRow, "secure_for_night") ? arguments.monitoringRow.secure_for_night : 0)
                AND structKeyExists(arguments.monitoringRow, "secure_for_night_until")
                AND isDate(arguments.monitoringRow.secure_for_night_until)
                AND isDate(arguments.nowTs)
                AND dateCompare(arguments.nowTs, arguments.monitoringRow.secure_for_night_until, "s") LTE 0
            );
        </cfscript>
    </cffunction>

    <cffunction name="transitionMonitorState" access="private" returntype="struct" output="false">
        <cfargument name="monitoringId" type="numeric" required="true">
        <cfargument name="fromState" type="string" required="true">
        <cfargument name="toState" type="string" required="true">
        <cfargument name="meta" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var result = { SUCCESS = false };
            var eventAt = structKeyExists(arguments.meta, "eventAt") AND isDate(arguments.meta.eventAt) ? arguments.meta.eventAt : getCurrentUtcTimestamp();
            var qIdentity = queryExecute(
                "SELECT float_plan_id, user_id
                 FROM floatplan_monitoring
                 WHERE id = :monitoringId
                 LIMIT 1",
                {
                    monitoringId = { value = arguments.monitoringId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );
            var updateSql = "";
            if (qIdentity.recordCount EQ 0) {
                result.ERROR = "MONITORING_NOT_FOUND";
                result.MESSAGE = "No monitoring row exists for this id.";
                return result;
            }
            if (arguments.monitoringId LTE 0) {
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Monitoring id is required.";
                return result;
            }
            if (!listFindNoCase(variables.allowedMonitorStates, trim(arguments.toState))) {
                result.ERROR = "INVALID_MONITOR_STATE";
                result.MESSAGE = "Target monitor state is invalid.";
                return result;
            }

            updateSql = "UPDATE floatplan_monitoring SET monitor_state = :toState";
            if (trim(arguments.toState) EQ "MISSED") {
                updateSql &= ", missed_at = COALESCE(missed_at, :eventAt)";
            } else if (trim(arguments.toState) EQ "ESCALATED") {
                updateSql &= ", escalated_at = COALESCE(escalated_at, :eventAt)";
            } else if (trim(arguments.toState) EQ "RESOLVED") {
                updateSql &= ", resolved_at = :eventAt";
            } else if (trim(arguments.toState) EQ "CLOSED") {
                updateSql &= ", closed_at = COALESCE(closed_at, :eventAt)";
            }
            updateSql &= " WHERE id = :monitoringId";

            queryExecute(
                updateSql,
                {
                    toState = { value = trim(arguments.toState), cfsqltype = "cf_sql_varchar" },
                    eventAt = { value = eventAt, cfsqltype = "cf_sql_timestamp" },
                    monitoringId = { value = arguments.monitoringId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );

            appendMonitorEvent(arguments.monitoringId, val(qIdentity.float_plan_id[1]), val(qIdentity.user_id[1]), "STATE_CHANGED", {
                actorType = structKeyExists(arguments.meta, "actorType") ? arguments.meta.actorType : "system",
                eventAt = eventAt,
                fromState = trim(arguments.fromState),
                toState = trim(arguments.toState),
                checkinStatus = structKeyExists(arguments.meta, "checkinStatus") ? arguments.meta.checkinStatus : ""
            });

            result.SUCCESS = true;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="appendMonitorEvent" access="private" returntype="struct" output="false">
        <cfargument name="monitoringId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="eventType" type="string" required="true">
        <cfargument name="meta" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var result = { SUCCESS = false };
            var eventTypeVal = trim(arguments.eventType);
            var actorTypeVal = structKeyExists(arguments.meta, "actorType") ? trim(toString(arguments.meta.actorType)) : "system";
            var eventAtVal = structKeyExists(arguments.meta, "eventAt") AND isDate(arguments.meta.eventAt) ? arguments.meta.eventAt : getCurrentUtcTimestamp();
            var fromStateVal = structKeyExists(arguments.meta, "fromState") ? trim(toString(arguments.meta.fromState)) : "";
            var toStateVal = structKeyExists(arguments.meta, "toState") ? trim(toString(arguments.meta.toState)) : "";
            var checkinStatusVal = structKeyExists(arguments.meta, "checkinStatus") ? normalizeCheckinStatus(arguments.meta.checkinStatus) : "";
            var metaCopy = duplicate(arguments.meta);
            var metaJsonVal = "";

            if (!listFindNoCase(variables.allowedMonitorEvents, eventTypeVal)) {
                result.ERROR = "INVALID_EVENT_TYPE";
                result.MESSAGE = "Monitoring event type is invalid.";
                return result;
            }
            if (listFindNoCase("system,captain,admin", actorTypeVal) EQ 0) {
                actorTypeVal = "system";
            }

            structDelete(metaCopy, "actorType", false);
            structDelete(metaCopy, "eventAt", false);
            structDelete(metaCopy, "fromState", false);
            structDelete(metaCopy, "toState", false);
            structDelete(metaCopy, "checkinStatus", false);
            metaJsonVal = structIsEmpty(metaCopy) ? "" : serializeJSON(metaCopy);

            queryExecute(
                "INSERT INTO floatplan_monitor_events (
                    monitoring_id,
                    float_plan_id,
                    user_id,
                    event_type,
                    from_state,
                    to_state,
                    event_at,
                    checkin_status,
                    actor_type,
                    meta_json,
                    created_at
                ) VALUES (
                    :monitoringId,
                    :floatPlanId,
                    :userId,
                    :eventType,
                    :fromState,
                    :toState,
                    :eventAt,
                    :checkinStatus,
                    :actorType,
                    :metaJson,
                    UTC_TIMESTAMP()
                )",
                {
                    monitoringId = { value = arguments.monitoringId, cfsqltype = "cf_sql_integer" },
                    floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                    eventType = { value = eventTypeVal, cfsqltype = "cf_sql_varchar" },
                    fromState = { value = fromStateVal, cfsqltype = "cf_sql_varchar", null = NOT len(fromStateVal) },
                    toState = { value = toStateVal, cfsqltype = "cf_sql_varchar", null = NOT len(toStateVal) },
                    eventAt = { value = eventAtVal, cfsqltype = "cf_sql_timestamp" },
                    checkinStatus = { value = checkinStatusVal, cfsqltype = "cf_sql_varchar", null = NOT len(checkinStatusVal) },
                    actorType = { value = actorTypeVal, cfsqltype = "cf_sql_varchar" },
                    metaJson = { value = metaJsonVal, cfsqltype = "cf_sql_longvarchar", null = NOT len(metaJsonVal) }
                },
                { datasource = variables.datasource }
            );

            result.SUCCESS = true;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="resetMonitoringCycleFields" access="private" returntype="void" output="false">
        <cfargument name="monitoringRow" type="struct" required="true">
        <cfscript>
            queryExecute(
                "UPDATE floatplan_monitoring
                 SET missed_at = NULL,
                     escalated_at = NULL,
                     last_captain_alert_at = NULL,
                     last_contact_alert_at = NULL
                 WHERE id = :monitoringId",
                {
                    monitoringId = { value = arguments.monitoringRow.id, cfsqltype = "cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );
        </cfscript>
    </cffunction>

    <cffunction name="markCaptainAlertEligible" access="private" returntype="void" output="false">
        <cfargument name="monitoringRow" type="struct" required="true">
        <cfargument name="nowTs" required="true">
        <cfscript>
            queryExecute(
                "UPDATE floatplan_monitoring
                 SET last_captain_alert_at = :alertAt
                 WHERE id = :monitoringId",
                {
                    alertAt = { value = arguments.nowTs, cfsqltype = "cf_sql_timestamp" },
                    monitoringId = { value = arguments.monitoringRow.id, cfsqltype = "cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );
            appendMonitorEvent(arguments.monitoringRow.id, arguments.monitoringRow.float_plan_id, arguments.monitoringRow.user_id, "CAPTAIN_ALERTED", {
                actorType = "system",
                eventAt = arguments.nowTs
            });
        </cfscript>
    </cffunction>

    <cffunction name="markContactAlertEligible" access="private" returntype="void" output="false">
        <cfargument name="monitoringRow" type="struct" required="true">
        <cfargument name="nowTs" required="true">
        <cfscript>
            queryExecute(
                "UPDATE floatplan_monitoring
                 SET last_contact_alert_at = :alertAt
                 WHERE id = :monitoringId",
                {
                    alertAt = { value = arguments.nowTs, cfsqltype = "cf_sql_timestamp" },
                    monitoringId = { value = arguments.monitoringRow.id, cfsqltype = "cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );
            appendMonitorEvent(arguments.monitoringRow.id, arguments.monitoringRow.float_plan_id, arguments.monitoringRow.user_id, "CONTACT_ALERTED", {
                actorType = "system",
                eventAt = arguments.nowTs
            });
        </cfscript>
    </cffunction>

    <cffunction name="computeActiveRouteCheckpoint" access="private" returntype="any" output="false">
        <cfargument name="referenceUtc" required="true">
        <cfargument name="timeZoneId" type="string" required="true">
        <cfargument name="forceNextMorning" type="boolean" required="false" default="false">
        <cfargument name="monitoringRow" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var localReference = convertUtcToLocal(arguments.referenceUtc, arguments.timeZoneId);
            var targetLocal = "";
            var localDayStartRule = resolveMonitoringRowLocalDayStartRule(arguments.monitoringRow);
            if (!isDate(localReference) OR !len(trim(arguments.timeZoneId))) {
                return "";
            }
            if (arguments.forceNextMorning) {
                targetLocal = buildLocalDateTime(
                    dateAdd("d", 1, localReference),
                    localDayStartRule.local_day_start_hour,
                    localDayStartRule.local_day_start_minute,
                    localDayStartRule.local_day_start_second
                );
            } else if (isBeforeEveningCheckpoint(localReference)) {
                targetLocal = buildLocalDateTime(
                    localReference,
                    variables.activeRouteEveningHour,
                    variables.activeRouteEveningMinute,
                    variables.activeRouteEveningSecond
                );
            } else {
                targetLocal = buildLocalDateTime(
                    dateAdd("d", 1, localReference),
                    localDayStartRule.local_day_start_hour,
                    localDayStartRule.local_day_start_minute,
                    localDayStartRule.local_day_start_second
                );
            }
            return convertLocalToUtc(targetLocal, arguments.timeZoneId);
        </cfscript>
    </cffunction>

    <cffunction name="refreshSecureForNightCheckpoint" access="public" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = { SUCCESS = false, UPDATED = false };
            var monitoringRow = {};
            var nowTs = getCurrentUtcTimestamp();
            var secureUntil = "";
            var graceExpiresAt = "";

            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }

            monitoringRow = getMonitoringRowByFloatPlanId(arguments.floatPlanId);
            if (!monitoringRow.SUCCESS) {
                result.SUCCESS = true;
                result.UPDATED = false;
                result.MESSAGE = "No monitoring row exists for this float plan.";
                return result;
            }

            if (!booleanValue(structKeyExists(monitoringRow, "secure_for_night") ? monitoringRow.secure_for_night : 0)) {
                result.SUCCESS = true;
                result.UPDATED = false;
                result.MESSAGE = "Monitoring row is not currently secure for the night.";
                return result;
            }

            secureUntil = computeSecureForNightUntil(monitoringRow, {
                baseAt = nowTs,
                allowSameDayFuture = true
            });
            if (!isDate(secureUntil)) {
                result.ERROR = "EXPECTED_CHECKIN_UNAVAILABLE";
                result.MESSAGE = "Unable to compute the updated secure-for-night resume time.";
                return result;
            }
            graceExpiresAt = computeGraceExpiresAt(secureUntil, monitoringRow.grace_window_minutes);

            queryExecute(
                "UPDATE floatplan_monitoring
                 SET expected_checkin_at = :expectedCheckinAt,
                     grace_expires_at = :graceExpiresAt,
                     secure_for_night_until = :secureForNightUntil,
                     next_monitor_eval_at = :nextMonitorEvalAt
                 WHERE id = :monitoringId",
                {
                    expectedCheckinAt = { value = secureUntil, cfsqltype = "cf_sql_timestamp" },
                    graceExpiresAt = { value = graceExpiresAt, cfsqltype = "cf_sql_timestamp" },
                    secureForNightUntil = { value = secureUntil, cfsqltype = "cf_sql_timestamp" },
                    nextMonitorEvalAt = { value = secureUntil, cfsqltype = "cf_sql_timestamp" },
                    monitoringId = { value = monitoringRow.id, cfsqltype = "cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );

            result.SUCCESS = true;
            result.UPDATED = true;
            result.FLOAT_PLAN_ID = monitoringRow.float_plan_id;
            result.EXPECTED_CHECKIN_AT = secureUntil;
            result.SECURE_FOR_NIGHT_UNTIL = secureUntil;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="resolveMonitoringRowLocalDayStartRule" access="private" returntype="struct" output="false">
        <cfargument name="monitoringRow" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var dailyStartLocalTime = "";
            if (structKeyExists(arguments.monitoringRow, "daily_start_local_time")) {
                dailyStartLocalTime = trim(toString(arguments.monitoringRow.daily_start_local_time));
            }
            if (len(dailyStartLocalTime) AND structKeyExists(variables, "overnightTimingService")) {
                return variables.overnightTimingService.getLocalDayStartRule(dailyStartLocalTime);
            }
            return variables.localDayStartRule;
        </cfscript>
    </cffunction>

    <cffunction name="convertUtcToLocal" access="private" returntype="any" output="false">
        <cfargument name="utcDateTime" required="true">
        <cfargument name="timeZoneId" type="string" required="true">
        <cfscript>
            var qLocal = queryNew("");
            if (!isDate(arguments.utcDateTime) OR !len(trim(arguments.timeZoneId))) {
                return "";
            }
            qLocal = queryExecute(
                "SELECT CONVERT_TZ(:utcDateTime, 'UTC', :timeZoneId) AS localDateTime",
                {
                    utcDateTime = { value = arguments.utcDateTime, cfsqltype = "cf_sql_timestamp" },
                    timeZoneId = { value = trim(arguments.timeZoneId), cfsqltype = "cf_sql_varchar" }
                },
                { datasource = variables.datasource }
            );
            if (qLocal.recordCount EQ 0 OR isNull(qLocal.localDateTime[1])) {
                return "";
            }
            return qLocal.localDateTime[1];
        </cfscript>
    </cffunction>

    <cffunction name="convertLocalToUtc" access="private" returntype="any" output="false">
        <cfargument name="localDateTime" required="true">
        <cfargument name="timeZoneId" type="string" required="true">
        <cfscript>
            var qUtc = queryNew("");
            if (!isDate(arguments.localDateTime) OR !len(trim(arguments.timeZoneId))) {
                return "";
            }
            qUtc = queryExecute(
                "SELECT CONVERT_TZ(:localDateTime, :timeZoneId, 'UTC') AS utcDateTime",
                {
                    localDateTime = { value = arguments.localDateTime, cfsqltype = "cf_sql_timestamp" },
                    timeZoneId = { value = trim(arguments.timeZoneId), cfsqltype = "cf_sql_varchar" }
                },
                { datasource = variables.datasource }
            );
            if (qUtc.recordCount EQ 0 OR isNull(qUtc.utcDateTime[1])) {
                return "";
            }
            return qUtc.utcDateTime[1];
        </cfscript>
    </cffunction>

    <cffunction name="getActiveRouteTimeZoneId" access="private" returntype="string" output="false">
        <cfargument name="monitoringRow" type="struct" required="true">
        <cfscript>
            if (structKeyExists(arguments.monitoringRow, "departure_timezone") AND len(trim(toString(arguments.monitoringRow.departure_timezone)))) {
                return trim(toString(arguments.monitoringRow.departure_timezone));
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="normalizeMonitoringMode" access="private" returntype="string" output="false">
        <cfargument name="value" required="true">
        <cfscript>
            var normalized = lCase(trim(toString(arguments.value)));
            if (listFindNoCase(variables.allowedMonitoringModes, normalized)) {
                return normalized;
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="normalizeCheckinStatus" access="private" returntype="string" output="false">
        <cfargument name="value" required="true">
        <cfscript>
            var normalized = uCase(trim(toString(arguments.value)));
            if (listFindNoCase(variables.allowedCheckinStatuses, normalized)) {
                return normalized;
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="isBeforeEveningCheckpoint" access="private" returntype="boolean" output="false">
        <cfargument name="localReference" required="true">
        <cfscript>
            var eveningCheckpoint = "";
            if (!isDate(arguments.localReference)) {
                return false;
            }
            eveningCheckpoint = buildLocalDateTime(arguments.localReference, variables.activeRouteEveningHour, variables.activeRouteEveningMinute, variables.activeRouteEveningSecond);
            return dateCompare(arguments.localReference, eveningCheckpoint, "s") LT 0;
        </cfscript>
    </cffunction>

    <cffunction name="buildLocalDateTime" access="private" returntype="any" output="false">
        <cfargument name="baseDate" required="true">
        <cfargument name="hourVal" type="numeric" required="true">
        <cfargument name="minuteVal" type="numeric" required="true">
        <cfargument name="secondVal" type="numeric" required="true">
        <cfscript>
            if (!isDate(arguments.baseDate)) {
                return "";
            }
            return createDateTime(
                year(arguments.baseDate),
                month(arguments.baseDate),
                day(arguments.baseDate),
                arguments.hourVal,
                arguments.minuteVal,
                arguments.secondVal
            );
        </cfscript>
    </cffunction>

    <cffunction name="booleanValue" access="private" returntype="boolean" output="false">
        <cfargument name="value" required="true">
        <cfscript>
            var stringValue = "";
            if (isBoolean(arguments.value)) {
                return arguments.value;
            }
            if (isNumeric(arguments.value)) {
                return val(arguments.value) NEQ 0;
            }
            stringValue = lCase(trim(toString(arguments.value)));
            return listFindNoCase("true,1,yes,on", stringValue) GT 0;
        </cfscript>
    </cffunction>

    <cffunction name="getCurrentUtcTimestamp" access="private" returntype="any" output="false">
        <cfscript>
            var qNow = queryExecute(
                "SELECT UTC_TIMESTAMP() AS nowUtc",
                {},
                { datasource = variables.datasource }
            );
            if (qNow.recordCount EQ 0 OR isNull(qNow.nowUtc[1])) {
                return now();
            }
            return qNow.nowUtc[1];
        </cfscript>
    </cffunction>

</cfcomponent>
