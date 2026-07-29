<!--- /fpw/api/v1/monitor.cfc (FULL DROP-IN) --->
<cfcomponent output="true">

    <cffunction name="runOverdueAlerts" access="remote" returntype="any" output="true">
        <cfargument name="token" type="string" required="false" default="">
        <cfargument name="send" type="numeric" required="false" default="0">

        <cfset var expected = "">

        <cftry>

            <cfif structKeyExists(application,"monitorToken")>
                <cfset expected = trim(toString(application.monitorToken))>
            </cfif>

            <cfif NOT len(expected) OR trim(arguments.token) NEQ expected>
                <cfoutput>UNAUTHORIZED</cfoutput>
                <cfreturn>
            </cfif>

            <cfoutput>FPW legacy overdue alert runner is retired. Use runMonitoringEvaluator for canonical monitoring transitions and alerts.</cfoutput>

            <cfcatch>
                <cflog file="fpw-monitor" type="error" text="runOverdueAlerts failed: #cfcatch.message# #cfcatch.detail#">
                <cfoutput>SERVER_ERROR</cfoutput>
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
                writeLog(file = "fpw-monitor", type = "error", text = "runMonitoringEvaluator failed: " & err.message & " " & err.detail);
                response = {
                    SUCCESS = false,
                    ERROR = "SERVER_ERROR",
                    MESSAGE = "Server error."
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
            var expectedCheckinOptions = {};
            var memberGateResult = {};
            var routeStartProof = {};
            var monitoringBaseAt = monitoringStartAt;

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

            memberGateResult = getMemberAccessGateService().validateMonitoringMode(
                context.user_id,
                modeVal,
                arguments.floatPlanId
            );
            if (!memberGateResult.allowed) {
                return memberGateResult.response;
            }

            expectedCheckinOptions = duplicate(arguments.options);
            if (modeVal EQ "active_route") {
                routeStartProof = getRouteStartProofForFloatPlan(arguments.floatPlanId);
                if (
                    !structKeyExists(routeStartProof, "SUCCESS")
                    OR routeStartProof.SUCCESS NEQ true
                    OR !structKeyExists(routeStartProof, "HAS_START_PROOF")
                    OR !routeStartProof.HAS_START_PROOF
                ) {
                    result.ERROR = "ROUTE_TRIP_NOT_STARTED";
                    result.MESSAGE = "Route-backed monitoring starts only after the trip is explicitly started.";
                    return result;
                }
                if (structKeyExists(arguments.options, "baseAt") AND isDate(arguments.options.baseAt)) {
                    monitoringBaseAt = arguments.options.baseAt;
                } else if (structKeyExists(routeStartProof, "START_PROOF_AT") AND isDate(routeStartProof.START_PROOF_AT)) {
                    monitoringBaseAt = routeStartProof.START_PROOF_AT;
                }
                expectedCheckinOptions.baseAt = monitoringBaseAt;
            }

            expectedCheckinAt = computeNextExpectedCheckin(context, "", expectedCheckinOptions);
            if (!isDate(expectedCheckinAt)) {
                result.ERROR = "EXPECTED_CHECKIN_UNAVAILABLE";
                result.MESSAGE = "Unable to compute the first expected monitoring checkpoint.";
                return result;
            }
            graceExpiresAt = computeGraceExpiresAt(expectedCheckinAt, variables.graceWindowMinutes);
            nextMonitorEvalAt = computeInitialNextMonitorEvalAt(context, expectedCheckinAt, monitoringBaseAt, expectedCheckinOptions);
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

    <cffunction name="startScheduledRouteMonitoringForFloatPlan" access="public" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = { SUCCESS = false };
            var context = {};
            var memberGateResult = {};

            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }

            context = loadScheduledRouteMonitoringContext(arguments.floatPlanId);
            if (!context.SUCCESS) {
                return context;
            }

            memberGateResult = getMemberAccessGateService().requirePremiumForTrip(
                userId = context.user_id,
                canonicalTripId = arguments.floatPlanId,
                errorCode = "BASIC_ADVANCED_MONITORING_RESTRICTED",
                message = "Premium access for this trip is required for scheduled route monitoring."
            );
            if (!memberGateResult.allowed) {
                return memberGateResult.response;
            }

            result.SUCCESS = true;
            result.SKIPPED = true;
            result.DEFERRED = true;
            result.REASON = "ROUTE_TRIP_NOT_STARTED_MONITORING_DEFERRED";
            result.FLOAT_PLAN_ID = arguments.floatPlanId;
            result.MONITORING_MODE = "active_route";
            result.MONITOR_STATE = "";
            result.SCHEDULED_MONITORING_STARTED = false;
            result.MESSAGE = "Route-backed monitoring starts only after the trip is explicitly started.";
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
            var rowBeforeTransition = {};
            var activeState = "";

            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }
            if (!len(statusVal)) {
                result.ERROR = "INVALID_CHECKIN_STATUS";
                result.MESSAGE = "Monitoring check-in status is invalid.";
                return result;
            }
            if (statusVal EQ "ARRIVED") {
                result.ERROR = "FINAL_CLOSE_REQUIRED";
                result.MESSAGE = "Arrival closes monitoring through the final float plan close path.";
                return result;
            }

            monitoringRow = getMonitoringRowByFloatPlanId(arguments.floatPlanId);
            if (!monitoringRow.SUCCESS) {
                return monitoringRow;
            }
            if (!booleanValue(monitoringRow.is_monitoring_enabled) OR monitoringRow.monitor_state EQ "CLOSED") {
                result.ERROR = "MONITORING_INACTIVE";
                result.MESSAGE = "Monitoring is not active for this float plan.";
                return result;
            }

            rowBeforeTransition = duplicate(monitoringRow);

            transaction {
                appendMonitorEvent(monitoringRow.id, monitoringRow.float_plan_id, monitoringRow.user_id, "CHECKIN_RECEIVED", {
                    actorType = "captain",
                    eventAt = nowTs,
                    checkinStatus = statusVal
                });

                if (listFindNoCase("MISSED,ESCALATED", monitoringRow.monitor_state)) {
                    transitionMonitorState(monitoringRow.id, monitoringRow.monitor_state, "RESOLVED", {
                        actorType = "captain",
                        eventAt = nowTs,
                        checkinStatus = statusVal
                    });
                    appendMonitorEvent(monitoringRow.id, monitoringRow.float_plan_id, monitoringRow.user_id, "RESOLVED", {
                        actorType = "captain",
                        eventAt = nowTs,
                        checkinStatus = statusVal
                    });
                }

                if (statusVal EQ "SECURE_FOR_NIGHT") {
                    secureUntil = computeSecureForNightUntil(rowBeforeTransition, arguments.options);
                    if (!isUtcSqlTimestamp(secureUntil)) {
                        throw(message = "Unable to compute the secure-for-night checkpoint.", detail = "Expected monitoring checkpoint calculation failed.");
                    }
                    graceExpiresAt = addMinutesToUtcSql(secureUntil, rowBeforeTransition.grace_window_minutes);
                    if (!isUtcSqlTimestamp(graceExpiresAt)) {
                        throw(message = "Unable to compute the secure-for-night grace window.", detail = "Monitoring grace checkpoint calculation failed.");
                    }
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
                            expectedCheckinAt = { value = secureUntil, cfsqltype = "cf_sql_varchar" },
                            graceExpiresAt = { value = graceExpiresAt, cfsqltype = "cf_sql_varchar" },
                            secureForNightUntil = { value = secureUntil, cfsqltype = "cf_sql_varchar" },
                            nextMonitorEvalAt = { value = secureUntil, cfsqltype = "cf_sql_varchar" },
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
                    nextExpectedCheckin = computeNextExpectedCheckin(rowBeforeTransition, statusVal, {
                        baseAt = nowTs,
                        considerPlannedReturn = true
                    });
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
            var monitorability = {};
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
            monitorability = getMonitoringRowMonitorability(monitoringRow);
            if (!monitorability.MONITORABLE) {
                result.SUCCESS = true;
                result.SKIPPED = true;
                result.REASON = monitorability.REASON;
                result.MONITOR_STATE = monitoringRow.monitor_state;
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
            result.MONITOR_STATE = monitoringRow.monitor_state;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="evaluateDueMonitoringRows" access="public" returntype="struct" output="false">
        <cfargument name="limit" type="numeric" required="false" default="100">
        <cfscript>
            var result = { SUCCESS = true, PROCESSED_COUNT = 0, FLOAT_PLAN_IDS = [] };
            var qDue = queryNew("");
            var rowIndex = 0;
            var evalResult = {};
            var limitVal = max(1, int(arguments.limit));

            qDue = queryExecute(
                "SELECT fm.id, fm.float_plan_id
                 FROM floatplan_monitoring fm
                 INNER JOIN floatplans fp
                   ON fp.floatPlanId = fm.float_plan_id
                 LEFT JOIN route_instances ri
                   ON ri.id = fp.route_instance_id
                 WHERE fm.is_monitoring_enabled = 1
                   AND UPPER(TRIM(fm.monitor_state)) <> 'CLOSED'
                   AND UPPER(TRIM(COALESCE(fp.`status`, ''))) NOT IN ('CLOSED','CANCELLED')
                   AND fm.next_monitor_eval_at IS NOT NULL
                   AND fm.next_monitor_eval_at <= UTC_TIMESTAMP()
                   AND (
                       fp.route_instance_id IS NULL
                       OR fp.route_instance_id <= 0
                       OR ri.started_at IS NOT NULL
                       OR EXISTS (
                           SELECT 1
                           FROM route_instance_leg_progress rilp
                           WHERE rilp.route_instance_id = fp.route_instance_id
                             AND rilp.user_id = fp.userId
                             AND (
                                 rilp.leg_started_at IS NOT NULL
                                 OR rilp.completed_at IS NOT NULL
                                 OR UPPER(TRIM(COALESCE(rilp.status, ''))) IN ('STARTED','IN_PROGRESS','COMPLETED')
                             )
                       )
                   )
                 ORDER BY fm.next_monitor_eval_at ASC, fm.id ASC
                 LIMIT #limitVal#",
                {},
                { datasource = variables.datasource }
            );

            for (rowIndex = 1; rowIndex LTE qDue.recordCount; rowIndex++) {
                evalResult = evaluateMonitoringCycle(qDue.float_plan_id[rowIndex]);
                if (structKeyExists(evalResult, "SUCCESS") AND evalResult.SUCCESS) {
                    result.PROCESSED_COUNT++;
                    arrayAppend(result.FLOAT_PLAN_IDS, val(qDue.float_plan_id[rowIndex]));
                }
            }

            return result;
        </cfscript>
    </cffunction>

    <cffunction name="closeMonitoringForFloatPlan" access="public" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="closeReason" type="string" required="false" default="">
        <cfscript>
            var result = { SUCCESS = false };
            var monitoringRow = {};
            var closeAt = getCurrentUtcTimestamp();
            var closeReasonVal = trim(arguments.closeReason);

            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }

            monitoringRow = getMonitoringRowByFloatPlanId(arguments.floatPlanId);
            if (!monitoringRow.SUCCESS) {
                result.SUCCESS = true;
                result.CLOSED = false;
                result.MESSAGE = "No monitoring row exists for this float plan.";
                return result;
            }

            if (monitoringRow.monitor_state EQ "CLOSED") {
                result.SUCCESS = true;
                result.CLOSED = true;
                result.MESSAGE = "Monitoring is already closed.";
                return result;
            }

            transaction {
                transitionMonitorState(monitoringRow.id, monitoringRow.monitor_state, "CLOSED", {
                    actorType = "system",
                    eventAt = closeAt,
                    close_reason = closeReasonVal
                });
                queryExecute(
                    "UPDATE floatplan_monitoring
                     SET is_monitoring_enabled = 0,
                         next_monitor_eval_at = NULL,
                         secure_for_night = 0,
                         secure_for_night_until = NULL,
                         closed_at = COALESCE(closed_at, :closedAt),
                         updated_at = UTC_TIMESTAMP()
                     WHERE id = :monitoringId",
                    {
                        closedAt = { value = closeAt, cfsqltype = "cf_sql_timestamp" },
                        monitoringId = { value = monitoringRow.id, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = variables.datasource }
                );
                appendMonitorEvent(monitoringRow.id, monitoringRow.float_plan_id, monitoringRow.user_id, "MONITORING_CLOSED", {
                    actorType = "system",
                    eventAt = closeAt,
                    close_reason = closeReasonVal,
                    fromState = monitoringRow.monitor_state,
                    toState = "CLOSED"
                });
            }

            result.SUCCESS = true;
            result.CLOSED = true;
            result.FLOAT_PLAN_ID = monitoringRow.float_plan_id;
            result.MONITOR_STATE = "CLOSED";
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="loadFloatPlanMonitoringContext" access="private" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = { SUCCESS = false };
            var qPlan = queryNew("");
            var activeRouteTimeZoneId = "";
            var returnTimeZoneId = "";

            qPlan = queryExecute(
                "SELECT
                    fp.floatplanId,
                    fp.userId,
                    fp.floatPlanName,
                    fp.departureTime,
                    fp.departureTimeUTC,
                    fp.returnTime,
                    fp.returnTimeUTC,
                    fp.returnTimezone,
                    fp.returnTZ,
                    fp.departTimezone,
                    fp.departureTZ,
                    fp.route_instance_id,
                    TIME_FORMAT(fp.dailyStartLocalTime, '%H:%i:%s') AS dailyStartLocalTime
                 FROM floatplans fp
                 WHERE fp.floatplanId = :floatPlanId
                 LIMIT 1",
                {
                    floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );

            if (qPlan.recordCount EQ 0) {
                result.ERROR = "FLOAT_PLAN_NOT_FOUND";
                result.MESSAGE = "Float plan could not be found.";
                return result;
            }

            activeRouteTimeZoneId = trim(toString(qPlan.departureTZ[1] ?: qPlan.departTimezone[1] ?: ""));
            returnTimeZoneId = isNull(qPlan.returnTZ[1]) ? "" : trim(toString(qPlan.returnTZ[1]));
            if (!len(returnTimeZoneId)) {
                returnTimeZoneId = isNull(qPlan.returnTimezone[1]) ? "" : trim(toString(qPlan.returnTimezone[1]));
            }

            result.SUCCESS = true;
            result.float_plan_id = val(qPlan.floatplanId[1]);
            result.user_id = val(qPlan.userId[1]);
            result.float_plan_name = isNull(qPlan.floatPlanName[1]) ? "" : trim(toString(qPlan.floatPlanName[1]));
            result.departure_time = isNull(qPlan.departureTimeUTC[1]) ? "" : qPlan.departureTimeUTC[1];
            result.return_time = isNull(qPlan.returnTimeUTC[1]) ? "" : qPlan.returnTimeUTC[1];
            result.return_timezone = returnTimeZoneId;
            result.departure_timezone = activeRouteTimeZoneId;
            result.route_instance_id = isNull(qPlan.route_instance_id[1]) ? 0 : val(qPlan.route_instance_id[1]);
            result.current_leg_number = 0;
            result.total_legs = 0;
            result.route_progress_status = "";
            result.daily_start_local_time = isNull(qPlan.dailyStartLocalTime[1]) ? "" : trim(toString(qPlan.dailyStartLocalTime[1]));
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="loadScheduledRouteMonitoringContext" access="private" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = { SUCCESS = false };
            var qPlan = queryNew("");

            qPlan = queryExecute(
                "SELECT
                    fp.floatplanId,
                    fp.userId,
                    fp.departureTimeUTC,
                    fp.route_instance_id,
                    ri.started_at AS route_started_at,
                    UPPER(TRIM(fp.`status`)) AS status_value,
                    (
                        SELECT COUNT(*)
                        FROM route_instance_legs ril
                        WHERE ril.route_instance_id = fp.route_instance_id
                    ) AS route_leg_count,
                    (
                        SELECT COUNT(*)
                        FROM route_instance_leg_progress rilp
                        WHERE rilp.route_instance_id = fp.route_instance_id
                          AND rilp.user_id = fp.userId
                          AND (
                              rilp.leg_started_at IS NOT NULL
                              OR rilp.completed_at IS NOT NULL
                              OR UPPER(TRIM(COALESCE(rilp.status, ''))) IN ('STARTED','IN_PROGRESS','COMPLETED')
                          )
                    ) AS started_progress_count
                 FROM floatplans fp
                 LEFT JOIN route_instances ri
                   ON ri.id = fp.route_instance_id
                 WHERE fp.floatplanId = :floatPlanId
                 LIMIT 1",
                {
                    floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );

            if (qPlan.recordCount EQ 0) {
                result.ERROR = "FLOAT_PLAN_NOT_FOUND";
                result.MESSAGE = "Float plan could not be found.";
                return result;
            }
            if (uCase(trim(toString(qPlan.status_value[1]))) NEQ "ACTIVE") {
                result.ERROR = "ACTIVE_ROUTE_FLOAT_PLAN_REQUIRED";
                result.MESSAGE = "Scheduled monitoring can only be initialized for active route-backed float plans.";
                return result;
            }
            if (isNull(qPlan.route_instance_id[1]) OR val(qPlan.route_instance_id[1]) LTE 0) {
                result.ERROR = "ROUTE_INSTANCE_REQUIRED";
                result.MESSAGE = "A route instance is required before scheduled monitoring can start.";
                return result;
            }
            if (val(qPlan.route_leg_count[1]) LTE 0) {
                result.ERROR = "ROUTE_LEGS_REQUIRED";
                result.MESSAGE = "Route legs are required before scheduled monitoring can start.";
                return result;
            }
            if (isNull(qPlan.departureTimeUTC[1]) OR !isDate(qPlan.departureTimeUTC[1])) {
                result.ERROR = "SCHEDULED_DEPARTURE_REQUIRED";
                result.MESSAGE = "A valid scheduled departure is required before scheduled monitoring can start.";
                return result;
            }

            result.SUCCESS = true;
            result.float_plan_id = val(qPlan.floatplanId[1]);
            result.user_id = val(qPlan.userId[1]);
            result.departure_time = qPlan.departureTimeUTC[1];
            result.route_instance_id = val(qPlan.route_instance_id[1]);
            result.route_started_at = isNull(qPlan.route_started_at[1]) ? "" : qPlan.route_started_at[1];
            result.route_leg_count = val(qPlan.route_leg_count[1]);
            result.started_progress_count = val(qPlan.started_progress_count[1]);
            result.has_start_proof = (isDate(result.route_started_at) OR result.started_progress_count GT 0);
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="getRouteStartProofForFloatPlan" access="private" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = { SUCCESS = false, IS_ROUTE_BACKED = false, HAS_START_PROOF = false, START_PROOF_AT = "" };
            var qProof = queryNew("");

            qProof = queryExecute(
                "SELECT
                    fp.floatplanId,
                    fp.userId,
                    fp.route_instance_id,
                    UPPER(TRIM(COALESCE(fp.`status`, ''))) AS plan_status,
                    ri.started_at AS route_started_at,
                    (
                        SELECT COUNT(*)
                        FROM route_instance_leg_progress rilp
                        WHERE rilp.route_instance_id = fp.route_instance_id
                          AND rilp.user_id = fp.userId
                          AND (
                              rilp.leg_started_at IS NOT NULL
                              OR rilp.completed_at IS NOT NULL
                              OR UPPER(TRIM(COALESCE(rilp.status, ''))) IN ('STARTED','IN_PROGRESS','COMPLETED')
                          )
                    ) AS started_progress_count,
                    (
                        SELECT MIN(COALESCE(rilp.leg_started_at, rilp.completed_at))
                        FROM route_instance_leg_progress rilp
                        WHERE rilp.route_instance_id = fp.route_instance_id
                          AND rilp.user_id = fp.userId
                          AND (
                              rilp.leg_started_at IS NOT NULL
                              OR rilp.completed_at IS NOT NULL
                              OR UPPER(TRIM(COALESCE(rilp.status, ''))) IN ('STARTED','IN_PROGRESS','COMPLETED')
                          )
                    ) AS first_progress_at
                 FROM floatplans fp
                 LEFT JOIN route_instances ri
                   ON ri.id = fp.route_instance_id
                 WHERE fp.floatplanId = :floatPlanId
                 LIMIT 1",
                {
                    floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );

            if (qProof.recordCount EQ 0) {
                result.ERROR = "FLOAT_PLAN_NOT_FOUND";
                result.MESSAGE = "Float plan could not be found.";
                return result;
            }

            result.SUCCESS = true;
            result.FLOAT_PLAN_ID = val(qProof.floatplanId[1]);
            result.USER_ID = val(qProof.userId[1]);
            result.ROUTE_INSTANCE_ID = isNull(qProof.route_instance_id[1]) ? 0 : val(qProof.route_instance_id[1]);
            result.PLAN_STATUS = isNull(qProof.plan_status[1]) ? "" : trim(toString(qProof.plan_status[1]));
            result.IS_ROUTE_BACKED = (result.ROUTE_INSTANCE_ID GT 0);
            result.ROUTE_STARTED_AT = isNull(qProof.route_started_at[1]) ? "" : qProof.route_started_at[1];
            result.STARTED_PROGRESS_COUNT = val(qProof.started_progress_count[1]);
            result.FIRST_PROGRESS_AT = isNull(qProof.first_progress_at[1]) ? "" : qProof.first_progress_at[1];
            result.HAS_START_PROOF = (
                isDate(result.ROUTE_STARTED_AT)
                OR result.STARTED_PROGRESS_COUNT GT 0
            );
            if (isDate(result.ROUTE_STARTED_AT)) {
                result.START_PROOF_AT = result.ROUTE_STARTED_AT;
            } else if (isDate(result.FIRST_PROGRESS_AT)) {
                result.START_PROOF_AT = result.FIRST_PROGRESS_AT;
            }
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="getMonitoringRowMonitorability" access="private" returntype="struct" output="false">
        <cfargument name="monitoringRow" type="struct" required="true">
        <cfscript>
            var result = { MONITORABLE = true, REASON = "" };
            var modeVal = normalizeMonitoringMode(structKeyExists(arguments.monitoringRow, "monitoring_mode") ? arguments.monitoringRow.monitoring_mode : "");
            var routeInstanceIdVal = structKeyExists(arguments.monitoringRow, "route_instance_id") ? val(arguments.monitoringRow.route_instance_id) : 0;
            var planStatusVal = structKeyExists(arguments.monitoringRow, "float_plan_status") ? uCase(trim(toString(arguments.monitoringRow.float_plan_status))) : "";
            var routeStartProof = {};

            if (!booleanValue(arguments.monitoringRow.is_monitoring_enabled) OR arguments.monitoringRow.monitor_state EQ "CLOSED") {
                result.MONITORABLE = false;
                result.REASON = "DISABLED_OR_CLOSED";
                return result;
            }
            if (listFindNoCase("CLOSED,CANCELLED", planStatusVal)) {
                result.MONITORABLE = false;
                result.REASON = "FLOAT_PLAN_CLOSED";
                return result;
            }
            if (modeVal EQ "active_route" OR routeInstanceIdVal GT 0) {
                routeStartProof = getRouteStartProofForFloatPlan(arguments.monitoringRow.float_plan_id);
                if (
                    !structKeyExists(routeStartProof, "SUCCESS")
                    OR routeStartProof.SUCCESS NEQ true
                    OR !structKeyExists(routeStartProof, "HAS_START_PROOF")
                    OR !routeStartProof.HAS_START_PROOF
                ) {
                    result.MONITORABLE = false;
                    result.REASON = "ROUTE_TRIP_NOT_STARTED";
                    result.ROUTE_START_PROOF = routeStartProof;
                    return result;
                }
                result.ROUTE_START_PROOF = routeStartProof;
            }
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="getMonitoringRowByFloatPlanId" access="private" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = { SUCCESS = false };
            var qRow = queryNew("");

            qRow = queryExecute(
                "SELECT
                    fm.id,
                    fm.float_plan_id,
                    fm.user_id,
                    fm.monitoring_mode,
                    fm.monitor_state,
                    fm.is_monitoring_enabled,
                    fm.expected_checkin_at,
                    fm.grace_expires_at,
                    fm.missed_at,
                    fm.escalated_at,
                    fm.resolved_at,
                    fm.closed_at,
                    fm.last_checkin_at,
                    fm.last_checkin_status,
                    fm.secure_for_night,
                    fm.secure_for_night_until,
                    fm.escalation_delay_minutes,
                    fm.grace_window_minutes,
                    fm.next_monitor_eval_at,
                    fm.last_monitor_eval_at,
                    fm.last_captain_alert_at,
                    fm.last_contact_alert_at,
                    fm.created_at,
                    fm.updated_at,
                    fp.route_instance_id,
                    UPPER(TRIM(COALESCE(fp.`status`, ''))) AS float_plan_status,
                    fp.returnTimeUTC AS return_time,
                    DATE_FORMAT(fp.departureTime, '%Y-%m-%d %H:%i:%s') AS departure_time_local_raw,
                    DATE_FORMAT(fp.departureTimeUTC, '%Y-%m-%d %H:%i:%s') AS departure_time_utc_raw,
                    CASE
                        WHEN fp.departureTime IS NOT NULL AND fp.departureTimeUTC IS NOT NULL
                        THEN TIMESTAMPDIFF(MINUTE, fp.departureTime, fp.departureTimeUTC)
                        ELSE NULL
                    END AS departure_utc_offset_minutes,
                    DATE_FORMAT(fp.returnTime, '%Y-%m-%d %H:%i:%s') AS return_time_local_raw,
                    DATE_FORMAT(fp.returnTimeUTC, '%Y-%m-%d %H:%i:%s') AS return_time_utc_raw,
                    CASE
                        WHEN fp.returnTime IS NOT NULL AND fp.returnTimeUTC IS NOT NULL
                        THEN TIMESTAMPDIFF(MINUTE, fp.returnTime, fp.returnTimeUTC)
                        ELSE NULL
                    END AS return_utc_offset_minutes,
                    TIME_FORMAT(fp.dailyStartLocalTime, '%H:%i:%s') AS daily_start_local_time,
                    CASE
                        WHEN fp.departureTZ IS NOT NULL AND LENGTH(TRIM(fp.departureTZ)) > 0 THEN TRIM(fp.departureTZ)
                        WHEN fp.departTimezone IS NOT NULL AND LENGTH(TRIM(fp.departTimezone)) > 0 THEN TRIM(fp.departTimezone)
                        ELSE ''
                    END AS departure_timezone
                 FROM floatplan_monitoring fm
                 LEFT JOIN floatplans fp ON fp.floatplanId = fm.float_plan_id
                 WHERE fm.float_plan_id = :floatPlanId
                 LIMIT 1",
                {
                    floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );

            if (qRow.recordCount EQ 0) {
                result.ERROR = "MONITORING_NOT_FOUND";
                result.MESSAGE = "Monitoring row could not be found.";
                return result;
            }

            result.SUCCESS = true;
            result.id = val(qRow.id[1]);
            result.float_plan_id = val(qRow.float_plan_id[1]);
            result.user_id = val(qRow.user_id[1]);
            result.monitoring_mode = trim(toString(qRow.monitoring_mode[1]));
            result.monitor_state = trim(toString(qRow.monitor_state[1]));
            result.is_monitoring_enabled = booleanValue(qRow.is_monitoring_enabled[1]);
            result.expected_checkin_at = isNull(qRow.expected_checkin_at[1]) ? "" : qRow.expected_checkin_at[1];
            result.grace_expires_at = isNull(qRow.grace_expires_at[1]) ? "" : qRow.grace_expires_at[1];
            result.missed_at = isNull(qRow.missed_at[1]) ? "" : qRow.missed_at[1];
            result.escalated_at = isNull(qRow.escalated_at[1]) ? "" : qRow.escalated_at[1];
            result.resolved_at = isNull(qRow.resolved_at[1]) ? "" : qRow.resolved_at[1];
            result.closed_at = isNull(qRow.closed_at[1]) ? "" : qRow.closed_at[1];
            result.last_checkin_at = isNull(qRow.last_checkin_at[1]) ? "" : qRow.last_checkin_at[1];
            result.last_checkin_status = isNull(qRow.last_checkin_status[1]) ? "" : trim(toString(qRow.last_checkin_status[1]));
            result.secure_for_night = booleanValue(qRow.secure_for_night[1]);
            result.secure_for_night_until = isNull(qRow.secure_for_night_until[1]) ? "" : qRow.secure_for_night_until[1];
            result.escalation_delay_minutes = val(qRow.escalation_delay_minutes[1]);
            result.grace_window_minutes = val(qRow.grace_window_minutes[1]);
            result.next_monitor_eval_at = isNull(qRow.next_monitor_eval_at[1]) ? "" : qRow.next_monitor_eval_at[1];
            result.last_monitor_eval_at = isNull(qRow.last_monitor_eval_at[1]) ? "" : qRow.last_monitor_eval_at[1];
            result.last_captain_alert_at = isNull(qRow.last_captain_alert_at[1]) ? "" : qRow.last_captain_alert_at[1];
            result.last_contact_alert_at = isNull(qRow.last_contact_alert_at[1]) ? "" : qRow.last_contact_alert_at[1];
            result.created_at = isNull(qRow.created_at[1]) ? "" : qRow.created_at[1];
            result.updated_at = isNull(qRow.updated_at[1]) ? "" : qRow.updated_at[1];
            result.route_instance_id = isNull(qRow.route_instance_id[1]) ? 0 : val(qRow.route_instance_id[1]);
            result.float_plan_status = isNull(qRow.float_plan_status[1]) ? "" : trim(toString(qRow.float_plan_status[1]));
            result.return_time = isNull(qRow.return_time[1]) ? "" : qRow.return_time[1];
            result.departure_time_local_raw = isNull(qRow.departure_time_local_raw[1]) ? "" : trim(toString(qRow.departure_time_local_raw[1]));
            result.departure_time_utc_raw = isNull(qRow.departure_time_utc_raw[1]) ? "" : trim(toString(qRow.departure_time_utc_raw[1]));
            result.departure_utc_offset_minutes = isNull(qRow.departure_utc_offset_minutes[1]) ? "" : trim(toString(qRow.departure_utc_offset_minutes[1]));
            result.return_time_local_raw = isNull(qRow.return_time_local_raw[1]) ? "" : trim(toString(qRow.return_time_local_raw[1]));
            result.return_time_utc_raw = isNull(qRow.return_time_utc_raw[1]) ? "" : trim(toString(qRow.return_time_utc_raw[1]));
            result.return_utc_offset_minutes = isNull(qRow.return_utc_offset_minutes[1]) ? "" : trim(toString(qRow.return_utc_offset_minutes[1]));
            result.daily_start_local_time = isNull(qRow.daily_start_local_time[1]) ? "" : trim(toString(qRow.daily_start_local_time[1]));
            result.departure_timezone = isNull(qRow.departure_timezone[1]) ? "" : trim(toString(qRow.departure_timezone[1]));
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
            var returnTime = structKeyExists(arguments.monitoringRow, "return_time") ? arguments.monitoringRow.return_time : "";
            var activeRouteTimeZoneId = getActiveRouteTimeZoneId(arguments.monitoringRow);
            var baseAt = structKeyExists(arguments.options, "baseAt") AND isDate(arguments.options.baseAt) ? arguments.options.baseAt : getCurrentUtcTimestamp();
            var referenceAt = baseAt;
            var expectedCheckinAt = "";

            if (statusVal EQ "SECURE_FOR_NIGHT") {
                return computeSecureForNightUntil(arguments.monitoringRow, arguments.options);
            }
            if (modeVal EQ "basic") {
                return isDate(returnTime) ? returnTime : "";
            }
            if (modeVal EQ "active_route" AND len(activeRouteTimeZoneId)) {
                if (structKeyExists(arguments.options, "forceNextMorning") AND arguments.options.forceNextMorning) {
                    expectedCheckinAt = computeActiveRouteCheckpoint(referenceAt, activeRouteTimeZoneId, true, arguments.monitoringRow);
                } else {
                    expectedCheckinAt = computeActiveRouteCheckpoint(referenceAt, activeRouteTimeZoneId, false, arguments.monitoringRow);
                }
                if (structKeyExists(arguments.options, "considerPlannedReturn") AND booleanValue(arguments.options.considerPlannedReturn)) {
                    return selectEarlierPlannedReturnCheckpoint(arguments.monitoringRow, referenceAt, expectedCheckinAt);
                }
                return expectedCheckinAt;
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="computeGraceExpiresAt" access="private" returntype="any" output="false">
        <cfargument name="expectedCheckinAt" required="true">
        <cfargument name="graceWindowMinutes" type="numeric" required="true">
        <cfscript>
            if (!isDate(arguments.expectedCheckinAt)) {
                return "";
            }
            return dateAdd("n", arguments.graceWindowMinutes, arguments.expectedCheckinAt);
        </cfscript>
    </cffunction>

    <cffunction name="computeSecureForNightUntil" access="private" returntype="any" output="false">
        <cfargument name="monitoringRow" type="struct" required="true">
        <cfargument name="options" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var activeRouteTimeZoneId = getActiveRouteTimeZoneId(arguments.monitoringRow);
            var referenceUtc = structKeyExists(arguments.options, "baseAt") ? normalizeUtcSqlTimestamp(arguments.options.baseAt) : "";
            var allowSameDayFuture = structKeyExists(arguments.options, "allowSameDayFuture") AND booleanValue(arguments.options.allowSameDayFuture);
            var localReference = "";
            var targetLocal = "";
            var localDayStartRule = resolveMonitoringRowLocalDayStartRule(arguments.monitoringRow);
            var todayTarget = "";
            var referenceOffset = {};
            var targetOffset = {};

            if (!len(activeRouteTimeZoneId)) {
                return "";
            }
            if (!len(referenceUtc)) {
                referenceUtc = getCurrentUtcSqlTimestamp();
            }
            if (!len(referenceUtc)) {
                return "";
            }

            referenceOffset = resolveScheduleOffsetMinutesForUtcReference(arguments.monitoringRow, referenceUtc);
            if (!referenceOffset.success) {
                return "";
            }

            localReference = shiftSqlTimestampByMinutes(referenceUtc, -referenceOffset.minutes);
            if (!isUtcSqlTimestamp(localReference)) {
                return "";
            }

            if (allowSameDayFuture) {
                todayTarget = buildLocalSqlDateTime(localReference, localDayStartRule);
                if (isUtcSqlTimestamp(todayTarget) AND compare(todayTarget, localReference) GT 0) {
                    targetLocal = todayTarget;
                }
            }

            if (!isUtcSqlTimestamp(targetLocal)) {
                targetLocal = buildLocalSqlDateTime(shiftSqlTimestampByDays(localReference, 1), localDayStartRule);
            }
            if (!isUtcSqlTimestamp(targetLocal)) {
                return "";
            }

            targetOffset = resolveScheduleOffsetMinutesForLocalTarget(arguments.monitoringRow, targetLocal);
            if (!targetOffset.success) {
                return "";
            }
            return shiftSqlTimestampByMinutes(targetLocal, targetOffset.minutes);
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
            var alertService = createObject("component", "fpw.api.v1.OverdueAlertService").init();
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
            try {
                alertService.sendMonitoringMissedOwnerEmail(
                    arguments.monitoringRow.float_plan_id,
                    arguments.monitoringRow.id,
                    arguments.nowTs
                );
            } catch (any ignoredAlertError) {}
        </cfscript>
    </cffunction>

    <cffunction name="markContactAlertEligible" access="private" returntype="void" output="false">
        <cfargument name="monitoringRow" type="struct" required="true">
        <cfargument name="nowTs" required="true">
        <cfscript>
            var alertService = createObject("component", "fpw.api.v1.OverdueAlertService").init();
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
            try {
                alertService.sendMonitoringEscalatedContactEmail(
                    arguments.monitoringRow.float_plan_id,
                    arguments.monitoringRow.id,
                    arguments.nowTs
                );
            } catch (any ignoredAlertError) {}
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

    <cffunction name="selectEarlierPlannedReturnCheckpoint" access="private" returntype="any" output="false">
        <cfargument name="monitoringRow" type="struct" required="true">
        <cfargument name="anchorUtc" required="true">
        <cfargument name="normalCheckpointUtc" required="true">
        <cfscript>
            var modeVal = normalizeMonitoringMode(structKeyExists(arguments.monitoringRow, "monitoring_mode") ? arguments.monitoringRow.monitoring_mode : "");
            var plannedReturnUtc = structKeyExists(arguments.monitoringRow, "return_time") ? arguments.monitoringRow.return_time : "";
            var monitorState = structKeyExists(arguments.monitoringRow, "monitor_state") ? uCase(trim(toString(arguments.monitoringRow.monitor_state))) : "";

            if (modeVal NEQ "active_route") {
                return arguments.normalCheckpointUtc;
            }
            if (structKeyExists(arguments.monitoringRow, "is_monitoring_enabled") AND !booleanValue(arguments.monitoringRow.is_monitoring_enabled)) {
                return arguments.normalCheckpointUtc;
            }
            if (monitorState EQ "CLOSED") {
                return arguments.normalCheckpointUtc;
            }
            if (structKeyExists(arguments.monitoringRow, "secure_for_night") AND booleanValue(arguments.monitoringRow.secure_for_night)) {
                return arguments.normalCheckpointUtc;
            }
            if (!isDate(plannedReturnUtc) OR !isDate(arguments.anchorUtc) OR !isDate(arguments.normalCheckpointUtc)) {
                return arguments.normalCheckpointUtc;
            }
            if (dateCompare(plannedReturnUtc, arguments.anchorUtc, "s") LTE 0) {
                return arguments.normalCheckpointUtc;
            }
            if (dateCompare(plannedReturnUtc, arguments.normalCheckpointUtc, "s") LT 0) {
                return plannedReturnUtc;
            }
            return arguments.normalCheckpointUtc;
        </cfscript>
    </cffunction>

    <cffunction name="refreshActiveRouteCheckpointFromLegStart" access="public" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="routeInstanceId" type="numeric" required="false" default="0">
        <cfargument name="legOrder" type="numeric" required="false" default="0">
        <cfscript>
            var result = { SUCCESS = false, UPDATED = false };
            var monitoringRow = {};
            var qLegStart = queryNew("");
            var expectedCheckinAt = "";
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
            if (!booleanValue(monitoringRow.is_monitoring_enabled) OR uCase(trim(toString(monitoringRow.monitor_state))) EQ "CLOSED") {
                result.SUCCESS = true;
                result.UPDATED = false;
                result.MESSAGE = "Monitoring is not active for this float plan.";
                return result;
            }
            if (normalizeMonitoringMode(monitoringRow.monitoring_mode) NEQ "active_route") {
                result.SUCCESS = true;
                result.UPDATED = false;
                result.MESSAGE = "Monitoring mode is not active_route.";
                return result;
            }

            qLegStart = queryExecute(
                "SELECT rilp.leg_order, rilp.leg_started_at
                 FROM route_instance_leg_progress rilp
                 INNER JOIN floatplans fp
                    ON fp.route_instance_id = rilp.route_instance_id
                   AND fp.userId = rilp.user_id
                 WHERE fp.floatplanId = :floatPlanId
                   AND fp.userId = :userId
                   AND rilp.leg_started_at IS NOT NULL
                   AND (:routeInstanceId <= 0 OR rilp.route_instance_id = :routeInstanceId)
                   AND (:legOrder <= 0 OR rilp.leg_order = :legOrder)
                 ORDER BY rilp.leg_order DESC, rilp.id DESC
                 LIMIT 1",
                {
                    floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = monitoringRow.user_id, cfsqltype = "cf_sql_integer" },
                    routeInstanceId = { value = val(arguments.routeInstanceId), cfsqltype = "cf_sql_integer" },
                    legOrder = { value = val(arguments.legOrder), cfsqltype = "cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );

            if (qLegStart.recordCount EQ 0 OR isNull(qLegStart.leg_started_at[1]) OR !isDate(qLegStart.leg_started_at[1])) {
                result.ERROR = "LEG_START_NOT_FOUND";
                result.MESSAGE = "No actual started leg timestamp was available for monitoring refresh.";
                return result;
            }

            expectedCheckinAt = computeNextExpectedCheckin(monitoringRow, "", {
                baseAt = qLegStart.leg_started_at[1],
                considerPlannedReturn = true
            });
            if (!isDate(expectedCheckinAt)) {
                result.ERROR = "EXPECTED_CHECKIN_UNAVAILABLE";
                result.MESSAGE = "Unable to compute the updated active-route checkpoint.";
                return result;
            }
            graceExpiresAt = computeGraceExpiresAt(expectedCheckinAt, monitoringRow.grace_window_minutes);

            queryExecute(
                "UPDATE floatplan_monitoring
                 SET expected_checkin_at = :expectedCheckinAt,
                     grace_expires_at = :graceExpiresAt,
                     secure_for_night = 0,
                     secure_for_night_until = NULL,
                     next_monitor_eval_at = :nextMonitorEvalAt
                 WHERE id = :monitoringId",
                {
                    expectedCheckinAt = { value = expectedCheckinAt, cfsqltype = "cf_sql_timestamp" },
                    graceExpiresAt = { value = graceExpiresAt, cfsqltype = "cf_sql_timestamp" },
                    nextMonitorEvalAt = { value = expectedCheckinAt, cfsqltype = "cf_sql_timestamp" },
                    monitoringId = { value = monitoringRow.id, cfsqltype = "cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );

            result.SUCCESS = true;
            result.UPDATED = true;
            result.FLOAT_PLAN_ID = monitoringRow.float_plan_id;
            result.MONITORING_ID = monitoringRow.id;
            result.LEG_ORDER = val(qLegStart.leg_order[1]);
            result.ANCHOR_LEG_STARTED_AT = qLegStart.leg_started_at[1];
            result.EXPECTED_CHECKIN_AT = expectedCheckinAt;
            result.GRACE_EXPIRES_AT = graceExpiresAt;
            result.NEXT_MONITOR_EVAL_AT = expectedCheckinAt;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="refreshActiveRouteCheckpointFromLegCompletion" access="public" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="routeInstanceId" type="numeric" required="false" default="0">
        <cfargument name="legOrder" type="numeric" required="false" default="0">
        <cfscript>
            var result = { SUCCESS = false, UPDATED = false };
            var monitoringRow = {};
            var qLegCompletion = queryNew("");
            var qPendingLegs = queryNew("");
            var completedAt = "";
            var monitorStateVal = "";

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
            if (!booleanValue(monitoringRow.is_monitoring_enabled) OR uCase(trim(toString(monitoringRow.monitor_state))) EQ "CLOSED") {
                result.SUCCESS = true;
                result.UPDATED = false;
                result.MESSAGE = "Monitoring is not active for this float plan.";
                return result;
            }
            if (normalizeMonitoringMode(monitoringRow.monitoring_mode) NEQ "active_route") {
                result.SUCCESS = true;
                result.UPDATED = false;
                result.MESSAGE = "Monitoring mode is not active_route.";
                return result;
            }

            qLegCompletion = queryExecute(
                "SELECT rilp.route_instance_id, rilp.leg_order, rilp.completed_at
                 FROM route_instance_leg_progress rilp
                 INNER JOIN floatplans fp
                    ON fp.route_instance_id = rilp.route_instance_id
                   AND fp.userId = rilp.user_id
                 WHERE fp.floatplanId = :floatPlanId
                   AND fp.userId = :userId
                   AND rilp.completed_at IS NOT NULL
                   AND (:routeInstanceId <= 0 OR rilp.route_instance_id = :routeInstanceId)
                   AND (:legOrder <= 0 OR rilp.leg_order = :legOrder)
                 ORDER BY rilp.leg_order DESC, rilp.id DESC
                 LIMIT 1",
                {
                    floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = monitoringRow.user_id, cfsqltype = "cf_sql_integer" },
                    routeInstanceId = { value = val(arguments.routeInstanceId), cfsqltype = "cf_sql_integer" },
                    legOrder = { value = val(arguments.legOrder), cfsqltype = "cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );

            if (qLegCompletion.recordCount EQ 0 OR isNull(qLegCompletion.completed_at[1]) OR !isDate(qLegCompletion.completed_at[1])) {
                result.ERROR = "LEG_COMPLETION_NOT_FOUND";
                result.MESSAGE = "No actual completed leg timestamp was available for monitoring refresh.";
                return result;
            }

            completedAt = qLegCompletion.completed_at[1];
            qPendingLegs = queryExecute(
                "SELECT COUNT(*) AS pending_count
                 FROM route_instance_legs ril
                 INNER JOIN floatplans fp
                    ON fp.route_instance_id = ril.route_instance_id
                 LEFT JOIN route_instance_leg_progress rilp
                    ON rilp.route_instance_id = ril.route_instance_id
                   AND rilp.user_id = fp.userId
                   AND rilp.leg_order = ril.leg_order
                 WHERE fp.floatplanId = :floatPlanId
                   AND fp.userId = :userId
                   AND ril.route_instance_id = :routeInstanceId
                   AND ril.leg_order > :legOrder
                   AND (rilp.status IS NULL OR UPPER(TRIM(rilp.status)) <> 'COMPLETED')",
                {
                    floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = monitoringRow.user_id, cfsqltype = "cf_sql_integer" },
                    routeInstanceId = { value = val(qLegCompletion.route_instance_id[1]), cfsqltype = "cf_sql_integer" },
                    legOrder = { value = val(qLegCompletion.leg_order[1]), cfsqltype = "cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );

            monitorStateVal = uCase(trim(toString(monitoringRow.monitor_state)));
            transaction {
                if (monitorStateVal NEQ "ACTIVE") {
                    transitionMonitorState(monitoringRow.id, monitorStateVal, "ACTIVE", {
                        actorType = "captain",
                        eventAt = completedAt,
                        checkinStatus = "",
                        completed_leg_order = val(qLegCompletion.leg_order[1])
                    });
                }

                queryExecute(
                    "UPDATE floatplan_monitoring
                     SET monitor_state = 'ACTIVE',
                         expected_checkin_at = NULL,
                         grace_expires_at = NULL,
                         secure_for_night = 0,
                         secure_for_night_until = NULL,
                         next_monitor_eval_at = NULL,
                         missed_at = NULL,
                         escalated_at = NULL,
                         last_captain_alert_at = NULL,
                         last_contact_alert_at = NULL,
                         last_monitor_eval_at = :lastMonitorEvalAt
                     WHERE id = :monitoringId",
                    {
                        lastMonitorEvalAt = { value = completedAt, cfsqltype = "cf_sql_timestamp" },
                        monitoringId = { value = monitoringRow.id, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = variables.datasource }
                );
            }

            result.SUCCESS = true;
            result.UPDATED = true;
            result.FLOAT_PLAN_ID = monitoringRow.float_plan_id;
            result.MONITORING_ID = monitoringRow.id;
            result.LEG_ORDER = val(qLegCompletion.leg_order[1]);
            result.ANCHOR_COMPLETED_AT = completedAt;
            result.AWAITING_NEXT_LEG = (qPendingLegs.recordCount EQ 1 AND val(qPendingLegs.pending_count[1]) GT 0);
            result.PENDING_LEG_COUNT = qPendingLegs.recordCount EQ 1 ? val(qPendingLegs.pending_count[1]) : 0;
            result.MONITOR_STATE = "ACTIVE";
            result.EXPECTED_CHECKIN_AT = "";
            result.GRACE_EXPIRES_AT = "";
            result.NEXT_MONITOR_EVAL_AT = "";
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="refreshSecureForNightCheckpoint" access="public" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="options" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var result = { SUCCESS = false, UPDATED = false };
            var monitoringRow = {};
            var nowTs = structKeyExists(arguments.options, "baseAt") AND isDate(arguments.options.baseAt) ? arguments.options.baseAt : getCurrentUtcTimestamp();
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
            if (!isUtcSqlTimestamp(secureUntil)) {
                result.ERROR = "EXPECTED_CHECKIN_UNAVAILABLE";
                result.MESSAGE = "Unable to compute the updated secure-for-night resume time.";
                return result;
            }
            graceExpiresAt = addMinutesToUtcSql(secureUntil, monitoringRow.grace_window_minutes);
            if (!isUtcSqlTimestamp(graceExpiresAt)) {
                result.ERROR = "GRACE_WINDOW_UNAVAILABLE";
                result.MESSAGE = "Unable to compute the updated secure-for-night grace window.";
                return result;
            }

            queryExecute(
                "UPDATE floatplan_monitoring
                 SET expected_checkin_at = :expectedCheckinAt,
                     grace_expires_at = :graceExpiresAt,
                     secure_for_night_until = :secureForNightUntil,
                     next_monitor_eval_at = :nextMonitorEvalAt
                 WHERE id = :monitoringId",
                {
                    expectedCheckinAt = { value = secureUntil, cfsqltype = "cf_sql_varchar" },
                    graceExpiresAt = { value = graceExpiresAt, cfsqltype = "cf_sql_varchar" },
                    secureForNightUntil = { value = secureUntil, cfsqltype = "cf_sql_varchar" },
                    nextMonitorEvalAt = { value = secureUntil, cfsqltype = "cf_sql_varchar" },
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
            var normalizedTz = normalizeMonitorTimeZoneId(arguments.timeZoneId);
            var localStamp = "";
            if (!isDate(arguments.utcDateTime) OR !len(normalizedTz)) {
                return "";
            }

            localStamp = formatUtcWallTimeForMonitorZone(arguments.utcDateTime, normalizedTz);
            if (!len(localStamp)) {
                return "";
            }

            return parseMonitorDateTime(localStamp);
        </cfscript>
    </cffunction>

    <cffunction name="convertLocalToUtc" access="private" returntype="any" output="false">
        <cfargument name="localDateTime" required="true">
        <cfargument name="timeZoneId" type="string" required="true">
        <cfscript>
            var normalizedTz = normalizeMonitorTimeZoneId(arguments.timeZoneId);
            var targetLocalStamp = normalizeMonitorTimestamp(arguments.localDateTime);
            var targetLocal = "";
            var matches = [];
            var matchKeys = {};
            var offsetMinutes = 0;
            var candidateUtc = "";
            var candidateKey = "";
            var candidateLocalStamp = "";

            if (!len(targetLocalStamp) OR !len(normalizedTz)) {
                return "";
            }

            targetLocal = parseMonitorDateTime(targetLocalStamp);
            if (!isDate(targetLocal)) {
                return "";
            }

            if (normalizedTz EQ "UTC") {
                return targetLocal;
            }

            for (offsetMinutes = -840; offsetMinutes <= 840; offsetMinutes += 15) {
                candidateUtc = dateAdd("n", -offsetMinutes, targetLocal);
                candidateKey = normalizeMonitorTimestamp(candidateUtc);
                candidateLocalStamp = formatUtcWallTimeForMonitorZone(candidateUtc, normalizedTz);
                if (len(candidateLocalStamp) AND candidateLocalStamp EQ targetLocalStamp AND !structKeyExists(matchKeys, candidateKey)) {
                    matchKeys[candidateKey] = true;
                    arrayAppend(matches, candidateUtc);
                }
            }

            if (arrayLen(matches) NEQ 1) {
                return "";
            }

            return matches[1];
        </cfscript>
    </cffunction>

    <cffunction name="resolveScheduleOffsetMinutesForUtcReference" access="private" returntype="struct" output="false">
        <cfargument name="monitoringRow" type="struct" required="true">
        <cfargument name="referenceUtcSql" type="string" required="true">
        <cfscript>
            var result = { success = false, minutes = 0, source = "" };
            var rawUtc = normalizeUtcSqlTimestamp(arguments.referenceUtcSql);
            var departureLocal = getMonitoringRowRawTimestamp(arguments.monitoringRow, "departure_time_local_raw");
            var returnLocal = getMonitoringRowRawTimestamp(arguments.monitoringRow, "return_time_local_raw");
            var departureOffset = getMonitoringRowOffsetMinutes(arguments.monitoringRow, "departure_utc_offset_minutes");
            var returnOffset = getMonitoringRowOffsetMinutes(arguments.monitoringRow, "return_utc_offset_minutes");
            var departureCandidateLocal = "";
            var returnCandidateLocal = "";
            var matchCount = 0;

            if (!len(rawUtc)) {
                return result;
            }
            if (departureOffset.success AND returnOffset.success AND departureOffset.minutes EQ returnOffset.minutes) {
                result.success = true;
                result.minutes = departureOffset.minutes;
                result.source = "shared_schedule_offset";
                return result;
            }

            if (departureOffset.success AND len(departureLocal)) {
                departureCandidateLocal = shiftSqlTimestampByMinutes(rawUtc, -departureOffset.minutes);
                if (isUtcSqlTimestamp(departureCandidateLocal) AND left(departureCandidateLocal, 10) EQ left(departureLocal, 10)) {
                    result.success = true;
                    result.minutes = departureOffset.minutes;
                    result.source = "departure_schedule_offset";
                    matchCount++;
                }
            }
            if (returnOffset.success AND len(returnLocal)) {
                returnCandidateLocal = shiftSqlTimestampByMinutes(rawUtc, -returnOffset.minutes);
                if (isUtcSqlTimestamp(returnCandidateLocal) AND left(returnCandidateLocal, 10) EQ left(returnLocal, 10)) {
                    result.success = true;
                    result.minutes = returnOffset.minutes;
                    result.source = "return_schedule_offset";
                    matchCount++;
                }
            }

            if (matchCount EQ 1) {
                return result;
            }
            return { success = false, minutes = 0, source = "" };
        </cfscript>
    </cffunction>

    <cffunction name="resolveScheduleOffsetMinutesForLocalTarget" access="private" returntype="struct" output="false">
        <cfargument name="monitoringRow" type="struct" required="true">
        <cfargument name="targetLocalSql" type="string" required="true">
        <cfscript>
            var result = { success = false, minutes = 0, source = "" };
            var targetLocal = normalizeUtcSqlTimestamp(arguments.targetLocalSql);
            var targetLocalDate = "";
            var departureLocal = getMonitoringRowRawTimestamp(arguments.monitoringRow, "departure_time_local_raw");
            var returnLocal = getMonitoringRowRawTimestamp(arguments.monitoringRow, "return_time_local_raw");
            var departureOffset = getMonitoringRowOffsetMinutes(arguments.monitoringRow, "departure_utc_offset_minutes");
            var returnOffset = getMonitoringRowOffsetMinutes(arguments.monitoringRow, "return_utc_offset_minutes");

            if (!len(targetLocal)) {
                return result;
            }
            targetLocalDate = left(targetLocal, 10);

            if (departureOffset.success AND len(departureLocal) AND left(departureLocal, 10) EQ targetLocalDate) {
                result.success = true;
                result.minutes = departureOffset.minutes;
                result.source = "departure_schedule_offset";
                return result;
            }
            if (returnOffset.success AND len(returnLocal) AND left(returnLocal, 10) EQ targetLocalDate) {
                result.success = true;
                result.minutes = returnOffset.minutes;
                result.source = "return_schedule_offset";
                return result;
            }
            if (departureOffset.success AND returnOffset.success AND departureOffset.minutes EQ returnOffset.minutes) {
                result.success = true;
                result.minutes = departureOffset.minutes;
                result.source = "shared_schedule_offset";
                return result;
            }
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="getMonitoringRowRawTimestamp" access="private" returntype="string" output="false">
        <cfargument name="monitoringRow" type="struct" required="true">
        <cfargument name="keyName" type="string" required="true">
        <cfscript>
            if (!structKeyExists(arguments.monitoringRow, arguments.keyName)) {
                return "";
            }
            return normalizeUtcSqlTimestamp(arguments.monitoringRow[arguments.keyName]);
        </cfscript>
    </cffunction>

    <cffunction name="getMonitoringRowOffsetMinutes" access="private" returntype="struct" output="false">
        <cfargument name="monitoringRow" type="struct" required="true">
        <cfargument name="keyName" type="string" required="true">
        <cfscript>
            var result = { success = false, minutes = 0 };
            var raw = "";
            if (!structKeyExists(arguments.monitoringRow, arguments.keyName)) {
                return result;
            }
            raw = trim(toString(arguments.monitoringRow[arguments.keyName]));
            if (!len(raw) OR !isNumeric(raw)) {
                return result;
            }
            result.success = true;
            result.minutes = int(val(raw));
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="buildLocalSqlDateTime" access="private" returntype="string" output="false">
        <cfargument name="localReferenceSql" type="string" required="true">
        <cfargument name="localDayStartRule" type="struct" required="true">
        <cfscript>
            var localReference = normalizeUtcSqlTimestamp(arguments.localReferenceSql);
            if (!len(localReference)) {
                return "";
            }
            return left(localReference, 10) & " "
                & twoDigitClockPart(arguments.localDayStartRule.local_day_start_hour) & ":"
                & twoDigitClockPart(arguments.localDayStartRule.local_day_start_minute) & ":"
                & twoDigitClockPart(arguments.localDayStartRule.local_day_start_second);
        </cfscript>
    </cffunction>

    <cffunction name="twoDigitClockPart" access="private" returntype="string" output="false">
        <cfargument name="value" type="numeric" required="true">
        <cfscript>
            return right("0" & int(val(arguments.value)), 2);
        </cfscript>
    </cffunction>

    <cffunction name="shiftSqlTimestampByDays" access="private" returntype="string" output="false">
        <cfargument name="sqlValue" required="true">
        <cfargument name="days" type="numeric" required="true">
        <cfscript>
            return shiftSqlTimestampByMinutes(arguments.sqlValue, int(val(arguments.days)) * 1440);
        </cfscript>
    </cffunction>

    <cffunction name="shiftSqlTimestampByMinutes" access="private" returntype="string" output="false">
        <cfargument name="sqlValue" required="true">
        <cfargument name="minutes" type="numeric" required="true">
        <cfscript>
            var raw = normalizeUtcSqlTimestamp(arguments.sqlValue);
            var minutesVal = int(val(arguments.minutes));
            var qShifted = queryNew("");
            if (!len(raw)) {
                return "";
            }
            qShifted = queryExecute(
                "SELECT DATE_FORMAT(DATE_ADD(CAST(:raw AS DATETIME), INTERVAL #minutesVal# MINUTE), '%Y-%m-%d %H:%i:%s') AS shifted_at",
                {
                    raw = { value = raw, cfsqltype = "cf_sql_varchar" }
                },
                { datasource = variables.datasource }
            );
            if (qShifted.recordCount EQ 0 OR isNull(qShifted.shifted_at[1])) {
                return "";
            }
            return trim(toString(qShifted.shifted_at[1]));
        </cfscript>
    </cffunction>

    <cffunction name="addMinutesToUtcSql" access="private" returntype="string" output="false">
        <cfargument name="utcSqlValue" required="true">
        <cfargument name="minutes" type="numeric" required="true">
        <cfscript>
            return shiftSqlTimestampByMinutes(arguments.utcSqlValue, arguments.minutes);
        </cfscript>
    </cffunction>

    <cffunction name="normalizeUtcSqlTimestamp" access="private" returntype="string" output="false">
        <cfargument name="value" required="true">
        <cfscript>
            var raw = trim(toString(arguments.value));
            if (!len(raw)) {
                return "";
            }
            raw = replace(raw, "T", " ", "one");
            raw = reReplace(raw, "Z$", "", "one");
            raw = reReplace(raw, "\.[0-9]+$", "", "one");
            raw = reReplace(raw, "([+-]\d{2}:?\d{2})$", "", "one");
            if (reFind("^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$", raw)) {
                raw &= ":00";
            }
            if (!reFind("^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$", raw)) {
                return "";
            }
            return left(raw, 19);
        </cfscript>
    </cffunction>

    <cffunction name="isUtcSqlTimestamp" access="private" returntype="boolean" output="false">
        <cfargument name="value" required="true">
        <cfscript>
            return len(normalizeUtcSqlTimestamp(arguments.value)) EQ 19;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeMonitorTimeZoneId" access="private" returntype="string" output="false">
        <cfargument name="timeZoneId" type="string" required="true">
        <cfscript>
            var tz = trim(arguments.timeZoneId);
            if (!len(tz)) {
                return "";
            }
            if (listFindNoCase("UTC,Etc/UTC,GMT,+00:00", tz)) {
                return "UTC";
            }
            if (compareNoCase(tz, "US/Eastern") EQ 0) {
                return "America/New_York";
            }
            if (compareNoCase(tz, "US/Central") EQ 0) {
                return "America/Chicago";
            }
            if (compareNoCase(tz, "US/Mountain") EQ 0) {
                return "America/Denver";
            }
            if (compareNoCase(tz, "US/Pacific") EQ 0) {
                return "America/Los_Angeles";
            }
            if (compareNoCase(tz, "US/Alaska") EQ 0) {
                return "America/Anchorage";
            }
            if (compareNoCase(tz, "US/Hawaii") EQ 0) {
                return "Pacific/Honolulu";
            }
            return tz;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeMonitorTimestamp" access="private" returntype="string" output="false">
        <cfargument name="value" required="true">
        <cfscript>
            var normalized = trim(toString(arguments.value));
            if (isDate(arguments.value)) {
                return dateFormat(arguments.value, "yyyy-mm-dd") & " " & timeFormat(arguments.value, "HH:mm:ss");
            }
            if (!len(normalized)) {
                return "";
            }
            normalized = replace(normalized, "T", " ", "all");
            normalized = reReplace(normalized, "Z$", "", "one");
            normalized = reReplace(normalized, "([+-]\d{2}:?\d{2})$", "", "one");
            normalized = reReplace(normalized, "\.\d+$", "", "one");
            if (reFind("^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$", normalized)) {
                normalized &= ":00";
            }
            if (!isDate(normalized)) {
                return "";
            }
            return dateFormat(parseDateTime(normalized), "yyyy-mm-dd") & " " & timeFormat(parseDateTime(normalized), "HH:mm:ss");
        </cfscript>
    </cffunction>

    <cffunction name="parseMonitorDateTime" access="private" returntype="any" output="false">
        <cfargument name="value" required="true">
        <cfscript>
            var normalized = normalizeMonitorTimestamp(arguments.value);
            if (!len(normalized)) {
                return "";
            }
            try {
                return parseDateTime(normalized);
            } catch (any parseError) {
                return "";
            }
        </cfscript>
    </cffunction>

    <cffunction name="formatUtcWallTimeForMonitorZone" access="private" returntype="string" output="false">
        <cfargument name="utcDateTime" required="true">
        <cfargument name="timeZoneId" type="string" required="true">
        <cfscript>
            var normalizedTz = normalizeMonitorTimeZoneId(arguments.timeZoneId);
            var utcWallTime = parseMonitorDateTime(arguments.utcDateTime);
            var formattingInstant = "";
            if (!isDate(utcWallTime) OR !len(normalizedTz)) {
                return "";
            }
            if (normalizedTz EQ "UTC") {
                return normalizeMonitorTimestamp(utcWallTime);
            }
            try {
                formattingInstant = dateConvert("utc2local", utcWallTime);
                return dateTimeFormat(formattingInstant, "yyyy-mm-dd HH:nn:ss", normalizedTz);
            } catch (any formatError) {
                return "";
            }
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

    <cffunction name="getMemberAccessGateService" access="private" returntype="any" output="false">
        <cfscript>
            try {
                return createObject("component", "fpw.api.v1.MemberAccessGateService").init(variables.datasource);
            } catch (any e1) {
                return createObject("component", "api.v1.MemberAccessGateService").init(variables.datasource);
            }
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

    <cffunction name="getCurrentUtcSqlTimestamp" access="private" returntype="string" output="false">
        <cfscript>
            var qNow = queryExecute(
                "SELECT DATE_FORMAT(UTC_TIMESTAMP(), '%Y-%m-%d %H:%i:%s') AS nowUtcRaw",
                {},
                { datasource = variables.datasource }
            );
            if (qNow.recordCount EQ 0 OR isNull(qNow.nowUtcRaw[1])) {
                return "";
            }
            return trim(toString(qNow.nowUtcRaw[1]));
        </cfscript>
    </cffunction>

</cfcomponent>
