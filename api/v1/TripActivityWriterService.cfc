<cfcomponent output="false">

    <cffunction name="init" access="public" returntype="any" output="false">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            variables.datasource = arguments.datasource;
            return this;
        </cfscript>
    </cffunction>

    <cffunction name="recordActiveCruiseCheckin" access="public" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="status" type="string" required="true">
        <cfargument name="checkinContext" type="string" required="false" default="">
        <cfargument name="occurredAtUtc" type="any" required="true">
        <cfargument name="monitoringId" type="numeric" required="false" default="0">
        <cfargument name="sourcePostId" type="numeric" required="false" default="0">
        <cfargument name="payload" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var out = { SUCCESS = false, SKIPPED = false, EVENTS = [], SEGMENTS = [] };
            var statusVal = normalizeMonitoringStatus(arguments.status);
            var planCtx = {};
            var routeCtx = {};
            var payloadVal = duplicate(arguments.payload);
            var openSegments = [];
            var checkinEventId = 0;
            var stateEventId = 0;
            var cutoverEventId = 0;
            var expectedResumeAt = "";
            var shouldWriteRouteState = false;
            var currentSegmentType = "";
            var checkinIdempotencyKey = "";
            var idempotencyStatus = "";
            var qDuplicateCheckin = queryNew("");

            if (arguments.floatPlanId LTE 0 OR arguments.userId LTE 0) {
                out.ERROR = "INVALID_ID";
                out.MESSAGE = "floatPlanId and userId are required.";
                return out;
            }
            if (!isDate(arguments.occurredAtUtc)) {
                out.ERROR = "INVALID_OCCURRED_AT";
                out.MESSAGE = "A valid occurredAtUtc timestamp is required.";
                return out;
            }
            if (!listFindNoCase("ON_TRACK,DELAYED,CHANGED_PLAN,NEED_ATTENTION,SECURE_FOR_NIGHT", statusVal)) {
                out.ERROR = "INVALID_STATUS";
                out.MESSAGE = "Active Cruise check-in status is not supported for canonical activity write.";
                return out;
            }
            shouldWriteRouteState = (listFindNoCase("ON_TRACK,SECURE_FOR_NIGHT", statusVal) GT 0);

            planCtx = loadPlanContext(arguments.floatPlanId, arguments.userId);
            if (!planCtx.found) {
                out.ERROR = "PLAN_NOT_FOUND";
                out.MESSAGE = "Float plan was not found for canonical activity write.";
                return out;
            }
            routeCtx = resolveCurrentRouteLeg(planCtx.routeInstanceId, arguments.userId);
            expectedResumeAt = resolveExpectedResumeAt(payloadVal, planCtx);
            payloadVal.canonical_phase = "2B";
            payloadVal.canonical_write_scope = "active_cruise_checkin";
            payloadVal.monitoring_status = statusVal;
            payloadVal.checkin_context = arguments.checkinContext;
            idempotencyStatus = statusVal;
            if (arguments.sourcePostId GT 0) {
                idempotencyStatus &= ":" & arguments.sourcePostId;
            }
            checkinIdempotencyKey = buildIdempotencyKey("checkin", arguments.floatPlanId, idempotencyStatus, arguments.occurredAtUtc);
            qDuplicateCheckin = getEventByIdempotencyKey(checkinIdempotencyKey);
            if (qDuplicateCheckin.recordCount GT 0) {
                out.SUCCESS = true;
                out.SKIPPED = true;
                arrayAppend(out.EVENTS, "CHECKIN_RECEIVED");
                return out;
            }

            try {
                transaction {
                    openSegments = getOpenSegmentsForUpdate(arguments.floatPlanId);
                    if (arrayLen(openSegments) GT 1) {
                        throw(
                            message = "Multiple open canonical activity segments were detected.",
                            detail = "floatPlanId=" & arguments.floatPlanId
                        );
                    }
                    if (arrayLen(openSegments) EQ 1) {
                        currentSegmentType = openSegments[1].segmentType;
                    }

                    if (shouldWriteRouteState) {
                        cutoverEventId = ensureCanonicalTrackingStartedInternal(
                            planCtx,
                            routeCtx,
                            arguments.occurredAtUtc
                        );
                        if (cutoverEventId GT 0) {
                            arrayAppend(out.EVENTS, "CANONICAL_TRACKING_STARTED");
                        }
                    }

                    checkinEventId = insertEvent(
                        planCtx = planCtx,
                        routeCtx = routeCtx,
                        eventType = "CHECKIN_RECEIVED",
                        eventStatus = statusVal,
                        occurredAtUtc = arguments.occurredAtUtc,
                        source = "active_cruise_checkin",
                        actorUserId = arguments.userId,
                        sourceMonitoringId = arguments.monitoringId,
                        sourcePostId = arguments.sourcePostId,
                        idempotencyKey = checkinIdempotencyKey,
                        payload = payloadVal
                    );
                    arrayAppend(out.EVENTS, "CHECKIN_RECEIVED");

                    if (statusVal EQ "SECURE_FOR_NIGHT") {
                        stateEventId = insertEvent(
                            planCtx = planCtx,
                            routeCtx = routeCtx,
                            eventType = "SECURE_FOR_NIGHT",
                            eventStatus = "ACTIVE",
                            occurredAtUtc = arguments.occurredAtUtc,
                            source = "active_cruise_checkin",
                            actorUserId = arguments.userId,
                            sourceMonitoringId = arguments.monitoringId,
                            sourcePostId = arguments.sourcePostId,
                            idempotencyKey = buildIdempotencyKey("secure_for_night", arguments.floatPlanId, idempotencyStatus, arguments.occurredAtUtc),
                            payload = payloadVal
                        );
                        arrayAppend(out.EVENTS, "SECURE_FOR_NIGHT");
                        if (arrayLen(openSegments) EQ 0) {
                            openSegment(planCtx, routeCtx, "PAUSED_SECURE_FOR_NIGHT", arguments.occurredAtUtc, expectedResumeAt, "", stateEventId);
                            arrayAppend(out.SEGMENTS, "OPENED_PAUSED_SECURE_FOR_NIGHT");
                        } else if (currentSegmentType EQ "UNDERWAY") {
                            closeSegment(openSegments[1].id, arguments.occurredAtUtc, stateEventId);
                            openSegment(planCtx, routeCtx, "PAUSED_SECURE_FOR_NIGHT", arguments.occurredAtUtc, expectedResumeAt, "", stateEventId);
                            arrayAppend(out.SEGMENTS, "CLOSED_UNDERWAY");
                            arrayAppend(out.SEGMENTS, "OPENED_PAUSED_SECURE_FOR_NIGHT");
                        } else if (currentSegmentType EQ "PAUSED_DELAYED") {
                            closeSegment(openSegments[1].id, arguments.occurredAtUtc, stateEventId);
                            openSegment(planCtx, routeCtx, "PAUSED_SECURE_FOR_NIGHT", arguments.occurredAtUtc, expectedResumeAt, "", stateEventId);
                            arrayAppend(out.SEGMENTS, "CLOSED_PAUSED_DELAYED");
                            arrayAppend(out.SEGMENTS, "OPENED_PAUSED_SECURE_FOR_NIGHT");
                        }
                    } else if (statusVal EQ "DELAYED") {
                        if (currentSegmentType EQ "UNDERWAY") {
                            stateEventId = insertEvent(
                                planCtx = planCtx,
                                routeCtx = routeCtx,
                                eventType = "DELAYED_PAUSE",
                                eventStatus = "ACTIVE",
                                occurredAtUtc = arguments.occurredAtUtc,
                                source = "active_cruise_checkin",
                                actorUserId = arguments.userId,
                                sourceMonitoringId = arguments.monitoringId,
                                sourcePostId = arguments.sourcePostId,
                                idempotencyKey = buildIdempotencyKey("delayed_pause", arguments.floatPlanId, idempotencyStatus, arguments.occurredAtUtc),
                                payload = payloadVal
                            );
                            closeSegment(openSegments[1].id, arguments.occurredAtUtc, stateEventId);
                            openSegment(planCtx, routeCtx, "PAUSED_DELAYED", arguments.occurredAtUtc, expectedResumeAt, "", stateEventId);
                            arrayAppend(out.EVENTS, "DELAYED_PAUSE");
                            arrayAppend(out.SEGMENTS, "CLOSED_UNDERWAY");
                            arrayAppend(out.SEGMENTS, "OPENED_PAUSED_DELAYED");
                        }
                    } else if (statusVal EQ "ON_TRACK") {
                        if (arrayLen(openSegments) EQ 0) {
                            openSegment(planCtx, routeCtx, "UNDERWAY", arguments.occurredAtUtc, "", "", checkinEventId);
                            arrayAppend(out.SEGMENTS, "OPENED_UNDERWAY");
                        } else if (isResumeEligiblePauseSegment(currentSegmentType)) {
                            stateEventId = insertEvent(
                                planCtx = planCtx,
                                routeCtx = routeCtx,
                                eventType = "RESUMED_UNDERWAY",
                                eventStatus = "ACTIVE",
                                occurredAtUtc = arguments.occurredAtUtc,
                                source = "active_cruise_checkin",
                                actorUserId = arguments.userId,
                                sourceMonitoringId = arguments.monitoringId,
                                sourcePostId = arguments.sourcePostId,
                                idempotencyKey = buildIdempotencyKey("resumed_underway", arguments.floatPlanId, idempotencyStatus, arguments.occurredAtUtc),
                                payload = payloadVal
                            );
                            closeSegment(openSegments[1].id, arguments.occurredAtUtc, stateEventId);
                            openSegment(planCtx, routeCtx, "UNDERWAY", arguments.occurredAtUtc, "", arguments.occurredAtUtc, stateEventId);
                            arrayAppend(out.EVENTS, "RESUMED_UNDERWAY");
                            arrayAppend(out.SEGMENTS, "CLOSED_" & currentSegmentType);
                            arrayAppend(out.SEGMENTS, "OPENED_UNDERWAY");
                        }
                    }
                }
                out.SUCCESS = true;
            } catch (any writeErr) {
                out.SUCCESS = false;
                out.ERROR = "CANONICAL_ACTIVITY_WRITE_FAILED";
                out.MESSAGE = left(trim(toString(writeErr.message)), 500);
                out.DETAIL = left(trim(toString(writeErr.detail)), 500);
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="recordActiveCruiseRouteAction" access="public" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="eventType" type="string" required="true">
        <cfargument name="actionLabel" type="string" required="true">
        <cfargument name="statusLabel" type="string" required="false" default="">
        <cfargument name="occurredAtUtc" type="any" required="true">
        <cfargument name="routeInstanceId" type="numeric" required="false" default="0">
        <cfargument name="routeLegOrder" type="numeric" required="false" default="0">
        <cfargument name="endpointResult" type="struct" required="false" default="#structNew()#">
        <cfargument name="payload" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var out = { SUCCESS = false, EVENTS = [], EVENT_ID = 0 };
            var eventTypeVal = uCase(trim(arguments.eventType));
            var planCtx = {};
            var routeCtx = {
                routeInstanceId = val(arguments.routeInstanceId),
                routeLegOrder = val(arguments.routeLegOrder)
            };
            var legCtx = {};
            var payloadVal = duplicate(arguments.payload);
            var endpointResultVal = duplicate(arguments.endpointResult);
            var eventStatusVal = "";
            var eventId = 0;

            if (arguments.floatPlanId LTE 0 OR arguments.userId LTE 0) {
                out.ERROR = "INVALID_ID";
                out.MESSAGE = "floatPlanId and userId are required.";
                return out;
            }
            if (!isDate(arguments.occurredAtUtc)) {
                out.ERROR = "INVALID_OCCURRED_AT";
                out.MESSAGE = "A valid occurredAtUtc timestamp is required.";
                return out;
            }
            if (!listFindNoCase("ROUTE_LEG_COMPLETED,ROUTE_LEG_STARTED,FLOATPLAN_CLOSED", eventTypeVal)) {
                out.ERROR = "INVALID_EVENT_TYPE";
                out.MESSAGE = "Active Cruise route action event type is not supported.";
                return out;
            }

            planCtx = loadPlanContext(arguments.floatPlanId, arguments.userId);
            if (!planCtx.found) {
                out.ERROR = "PLAN_NOT_FOUND";
                out.MESSAGE = "Float plan was not found for route action write.";
                return out;
            }
            if (routeCtx.routeInstanceId LTE 0) {
                routeCtx.routeInstanceId = planCtx.routeInstanceId;
            }
            if (listFindNoCase("ROUTE_LEG_COMPLETED,ROUTE_LEG_STARTED", eventTypeVal) AND (routeCtx.routeInstanceId LTE 0 OR routeCtx.routeLegOrder LTE 0)) {
                out.ERROR = "INVALID_ROUTE_ACTION_CONTEXT";
                out.MESSAGE = "Route action event writes require explicit acted-on route instance and leg order.";
                return out;
            }

            legCtx = loadRouteLegContext(routeCtx.routeInstanceId, routeCtx.routeLegOrder);
            eventStatusVal = routeActionStatusForEvent(eventTypeVal);
            payloadVal.canonical_phase = "2B";
            payloadVal.canonical_write_scope = "active_cruise_route_action";
            payloadVal.floatplan_id = arguments.floatPlanId;
            payloadVal.route_instance_id = routeCtx.routeInstanceId;
            payloadVal.leg_order = routeCtx.routeLegOrder;
            payloadVal.from_name = legCtx.fromName;
            payloadVal.to_name = legCtx.toName;
            payloadVal.status_label = (len(trim(arguments.statusLabel)) ? trim(arguments.statusLabel) : eventStatusVal);
            payloadVal.action_label = trim(arguments.actionLabel);
            payloadVal.occurred_at_utc = formatUtc(arguments.occurredAtUtc);

            if (structKeyExists(endpointResultVal, "FLOATPLANID")) {
                payloadVal.endpoint_floatplan_id = val(endpointResultVal.FLOATPLANID);
            }
            if (structKeyExists(endpointResultVal, "ROUTE_INSTANCE_ID")) {
                payloadVal.endpoint_route_instance_id = val(endpointResultVal.ROUTE_INSTANCE_ID);
            }
            if (structKeyExists(endpointResultVal, "LEG_ORDER")) {
                payloadVal.endpoint_leg_order = val(endpointResultVal.LEG_ORDER);
            }
            if (structKeyExists(endpointResultVal, "SUCCESS")) {
                payloadVal.endpoint_success = booleanValue(endpointResultVal.SUCCESS);
            }
            if (structKeyExists(endpointResultVal, "COMPLETED")) {
                payloadVal.endpoint_completed = booleanValue(endpointResultVal.COMPLETED);
            }
            if (structKeyExists(endpointResultVal, "STARTED")) {
                payloadVal.endpoint_started = booleanValue(endpointResultVal.STARTED);
            }
            if (structKeyExists(endpointResultVal, "MATCHED")) {
                payloadVal.endpoint_matched = booleanValue(endpointResultVal.MATCHED);
            }
            if (structKeyExists(endpointResultVal, "ALREADY_COMPLETE")) {
                payloadVal.endpoint_already_complete = booleanValue(endpointResultVal.ALREADY_COMPLETE);
            }
            if (structKeyExists(endpointResultVal, "STATUS")) {
                payloadVal.endpoint_status = safeString(endpointResultVal.STATUS);
            }
            if (structKeyExists(endpointResultVal, "ERROR")) {
                payloadVal.endpoint_error = safeString(endpointResultVal.ERROR);
            }
            if (structKeyExists(endpointResultVal, "MESSAGE")) {
                payloadVal.endpoint_message = safeString(endpointResultVal.MESSAGE);
            }

            try {
                eventId = insertEvent(
                    planCtx = planCtx,
                    routeCtx = routeCtx,
                    eventType = eventTypeVal,
                    eventStatus = eventStatusVal,
                    occurredAtUtc = arguments.occurredAtUtc,
                    source = "active_cruise_route_action",
                    actorUserId = arguments.userId,
                    sourceMonitoringId = planCtx.monitoringId,
                    sourcePostId = 0,
                    idempotencyKey = buildIdempotencyKey("route_action", arguments.floatPlanId, eventTypeVal & ":" & routeCtx.routeLegOrder, arguments.occurredAtUtc),
                    payload = payloadVal
                );
                out.SUCCESS = true;
                out.EVENT_ID = eventId;
                arrayAppend(out.EVENTS, eventTypeVal);
            } catch (any writeErr) {
                out.SUCCESS = false;
                out.ERROR = "CANONICAL_ROUTE_ACTION_WRITE_FAILED";
                out.MESSAGE = left(trim(toString(writeErr.message)), 500);
                out.DETAIL = left(trim(toString(writeErr.detail)), 500);
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="ensureCanonicalTrackingStarted" access="public" returntype="numeric" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="occurredAtUtc" type="any" required="true">
        <cfscript>
            var planCtx = loadPlanContext(arguments.floatPlanId, arguments.userId);
            var routeCtx = {};
            if (!planCtx.found OR !isDate(arguments.occurredAtUtc)) {
                return 0;
            }
            routeCtx = resolveCurrentRouteLeg(planCtx.routeInstanceId, arguments.userId);
            return ensureCanonicalTrackingStartedInternal(planCtx, routeCtx, arguments.occurredAtUtc);
        </cfscript>
    </cffunction>

    <cffunction name="loadPlanContext" access="private" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="userId" type="numeric" required="true">
        <cfscript>
            var out = { found = false };
            var qPlan = queryExecute("
                SELECT fp.floatplanId,
                       fp.userId,
                       fp.route_instance_id,
                       fp.departureTZ,
                       fp.departTimezone,
                       m.id AS monitoring_id,
                       m.expected_checkin_at,
                       m.secure_for_night_until
                FROM floatplans fp
                LEFT JOIN floatplan_monitoring m
                  ON m.float_plan_id = fp.floatplanId
                 AND m.is_monitoring_enabled = 1
                 AND UPPER(TRIM(m.monitor_state)) <> 'CLOSED'
                WHERE fp.floatplanId = :planId
                  AND fp.userId = :userId
                ORDER BY m.id DESC
                LIMIT 1
            ", {
                planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
            }, { datasource = variables.datasource });

            if (qPlan.recordCount EQ 0) {
                return out;
            }
            out.found = true;
            out.floatPlanId = val(qPlan.floatplanId[1]);
            out.userId = val(qPlan.userId[1]);
            out.routeInstanceId = val(qPlan.route_instance_id[1]);
            out.localTimezone = resolveLocalTimezone(qPlan);
            out.monitoringId = val(qPlan.monitoring_id[1]);
            out.expectedCheckinAt = (!isNull(qPlan.expected_checkin_at[1]) AND isDate(qPlan.expected_checkin_at[1]) ? qPlan.expected_checkin_at[1] : "");
            out.secureForNightUntil = (!isNull(qPlan.secure_for_night_until[1]) AND isDate(qPlan.secure_for_night_until[1]) ? qPlan.secure_for_night_until[1] : "");
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="resolveCurrentRouteLeg" access="private" returntype="struct" output="false">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfargument name="userId" type="numeric" required="true">
        <cfscript>
            var out = { routeInstanceId = arguments.routeInstanceId, routeLegOrder = 0 };
            var qProgress = queryNew("");
            if (arguments.routeInstanceId LTE 0) {
                return out;
            }
            qProgress = queryExecute("
                SELECT leg_order
                FROM route_instance_leg_progress
                WHERE route_instance_id = :routeInstanceId
                  AND user_id = :userId
                ORDER BY
                  CASE
                    WHEN completed_at IS NULL AND leg_started_at IS NOT NULL THEN 0
                    WHEN UPPER(TRIM(status)) IN ('STARTED', 'IN_PROGRESS', 'ACTIVE') THEN 1
                    WHEN UPPER(TRIM(status)) = 'COMPLETED' THEN 3
                    ELSE 2
                  END,
                  leg_order DESC
                LIMIT 1
            ", {
                routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" },
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
            }, { datasource = variables.datasource });
            if (qProgress.recordCount GT 0) {
                out.routeLegOrder = val(qProgress.leg_order[1]);
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="loadRouteLegContext" access="private" returntype="struct" output="false">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfargument name="routeLegOrder" type="numeric" required="true">
        <cfscript>
            var out = { fromName = "", toName = "" };
            var qLeg = queryNew("");
            if (arguments.routeInstanceId LTE 0 OR arguments.routeLegOrder LTE 0) {
                return out;
            }
            qLeg = queryExecute("
                SELECT start_name, end_name
                FROM route_instance_legs
                WHERE route_instance_id = :routeInstanceId
                  AND leg_order = :legOrder
                LIMIT 1
            ", {
                routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" },
                legOrder = { value = arguments.routeLegOrder, cfsqltype = "cf_sql_integer" }
            }, { datasource = variables.datasource });
            if (qLeg.recordCount GT 0) {
                out.fromName = safeString(qLeg.start_name[1]);
                out.toName = safeString(qLeg.end_name[1]);
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="ensureCanonicalTrackingStartedInternal" access="private" returntype="numeric" output="false">
        <cfargument name="planCtx" type="struct" required="true">
        <cfargument name="routeCtx" type="struct" required="true">
        <cfargument name="occurredAtUtc" type="any" required="true">
        <cfscript>
            var qExisting = queryExecute("
                SELECT COUNT(*) AS event_count
                FROM floatplan_events
                WHERE floatplan_id = :floatPlanId
                  AND voided_at_utc IS NULL
            ", {
                floatPlanId = { value = arguments.planCtx.floatPlanId, cfsqltype = "cf_sql_integer" }
            }, { datasource = variables.datasource });
            if (qExisting.recordCount GT 0 AND val(qExisting.event_count[1]) GT 0) {
                return 0;
            }
            return insertEvent(
                planCtx = arguments.planCtx,
                routeCtx = arguments.routeCtx,
                eventType = "CANONICAL_TRACKING_STARTED",
                eventStatus = "ACTIVE",
                occurredAtUtc = arguments.occurredAtUtc,
                source = "canonical_cutover",
                actorUserId = arguments.planCtx.userId,
                sourceMonitoringId = arguments.planCtx.monitoringId,
                sourcePostId = 0,
                idempotencyKey = buildIdempotencyKey("canonical_start", arguments.planCtx.floatPlanId, "ACTIVE", arguments.occurredAtUtc),
                payload = {
                    "canonical_phase" = "2B",
                    "legacy_history_not_backfilled" = true,
                    "canonical_tracking_starts_at_current_action" = true
                }
            );
        </cfscript>
    </cffunction>

    <cffunction name="insertEvent" access="private" returntype="numeric" output="false">
        <cfargument name="planCtx" type="struct" required="true">
        <cfargument name="routeCtx" type="struct" required="true">
        <cfargument name="eventType" type="string" required="true">
        <cfargument name="eventStatus" type="string" required="false" default="">
        <cfargument name="occurredAtUtc" type="any" required="true">
        <cfargument name="source" type="string" required="true">
        <cfargument name="actorUserId" type="numeric" required="false" default="0">
        <cfargument name="sourceMonitoringId" type="numeric" required="false" default="0">
        <cfargument name="sourcePostId" type="numeric" required="false" default="0">
        <cfargument name="idempotencyKey" type="string" required="true">
        <cfargument name="payload" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var qExisting = getEventByIdempotencyKey(arguments.idempotencyKey);
            var qInserted = queryNew("");
            var payloadJson = serializeJSON(arguments.payload);
            if (qExisting.recordCount GT 0) {
                return val(qExisting.id[1]);
            }
            try {
                queryExecute("
                    INSERT INTO floatplan_events (
                        floatplan_id,
                        user_id,
                        route_instance_id,
                        route_leg_order,
                        event_type,
                        event_status,
                        occurred_at_utc,
                        source,
                        actor_user_id,
                        source_checkin_id,
                        source_monitoring_id,
                        source_post_id,
                        idempotency_key,
                        payload_json
                    ) VALUES (
                        :floatPlanId,
                        :userId,
                        :routeInstanceId,
                        :routeLegOrder,
                        :eventType,
                        :eventStatus,
                        :occurredAtUtc,
                        :source,
                        :actorUserId,
                        NULL,
                        :sourceMonitoringId,
                        :sourcePostId,
                        :idempotencyKey,
                        :payloadJson
                    )
                ", {
                    floatPlanId = { value = arguments.planCtx.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.planCtx.userId, cfsqltype = "cf_sql_integer" },
                    routeInstanceId = { value = arguments.routeCtx.routeInstanceId, cfsqltype = "cf_sql_integer", null = (arguments.routeCtx.routeInstanceId LTE 0) },
                    routeLegOrder = { value = arguments.routeCtx.routeLegOrder, cfsqltype = "cf_sql_integer", null = (arguments.routeCtx.routeLegOrder LTE 0) },
                    eventType = { value = arguments.eventType, cfsqltype = "cf_sql_varchar" },
                    eventStatus = { value = arguments.eventStatus, cfsqltype = "cf_sql_varchar", null = NOT len(arguments.eventStatus) },
                    occurredAtUtc = { value = arguments.occurredAtUtc, cfsqltype = "cf_sql_timestamp" },
                    source = { value = arguments.source, cfsqltype = "cf_sql_varchar" },
                    actorUserId = { value = arguments.actorUserId, cfsqltype = "cf_sql_integer", null = (arguments.actorUserId LTE 0) },
                    sourceMonitoringId = { value = arguments.sourceMonitoringId, cfsqltype = "cf_sql_bigint", null = (arguments.sourceMonitoringId LTE 0) },
                    sourcePostId = { value = arguments.sourcePostId, cfsqltype = "cf_sql_integer", null = (arguments.sourcePostId LTE 0) },
                    idempotencyKey = { value = arguments.idempotencyKey, cfsqltype = "cf_sql_varchar" },
                    payloadJson = { value = payloadJson, cfsqltype = "cf_sql_longvarchar", null = NOT len(payloadJson) }
                }, { datasource = variables.datasource });
            } catch (any eventInsertErr) {
                qExisting = getEventByIdempotencyKey(arguments.idempotencyKey);
                if (qExisting.recordCount GT 0) {
                    return val(qExisting.id[1]);
                }
                rethrow;
            }
            qInserted = getEventByIdempotencyKey(arguments.idempotencyKey);
            return (qInserted.recordCount GT 0 ? val(qInserted.id[1]) : 0);
        </cfscript>
    </cffunction>

    <cffunction name="getEventByIdempotencyKey" access="private" returntype="query" output="false">
        <cfargument name="idempotencyKey" type="string" required="true">
        <cfscript>
            return queryExecute("
                SELECT id
                FROM floatplan_events
                WHERE idempotency_key = :idempotencyKey
                LIMIT 1
            ", {
                idempotencyKey = { value = arguments.idempotencyKey, cfsqltype = "cf_sql_varchar" }
            }, { datasource = variables.datasource });
        </cfscript>
    </cffunction>

    <cffunction name="getOpenSegmentsForUpdate" access="private" returntype="array" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var segments = [];
            var i = 0;
            var qSegments = queryExecute("
                SELECT id, segment_type
                FROM floatplan_activity_segments
                WHERE floatplan_id = :floatPlanId
                  AND ended_at_utc IS NULL
                ORDER BY started_at_utc ASC, id ASC
                FOR UPDATE
            ", {
                floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
            }, { datasource = variables.datasource });
            for (i = 1; i <= qSegments.recordCount; i++) {
                arrayAppend(segments, {
                    "id" = val(qSegments.id[i]),
                    "segmentType" = uCase(trim(toString(qSegments.segment_type[i])))
                });
            }
            return segments;
        </cfscript>
    </cffunction>

    <cffunction name="openSegment" access="private" returntype="void" output="false">
        <cfargument name="planCtx" type="struct" required="true">
        <cfargument name="routeCtx" type="struct" required="true">
        <cfargument name="segmentType" type="string" required="true">
        <cfargument name="startedAtUtc" type="any" required="true">
        <cfargument name="expectedResumeAtUtc" type="any" required="false" default="">
        <cfargument name="actualResumeAtUtc" type="any" required="false" default="">
        <cfargument name="sourceStartEventId" type="numeric" required="false" default="0">
        <cfscript>
            queryExecute("
                INSERT INTO floatplan_activity_segments (
                    floatplan_id,
                    user_id,
                    route_instance_id,
                    route_leg_order,
                    local_timezone,
                    segment_type,
                    started_at_utc,
                    ended_at_utc,
                    expected_resume_at_utc,
                    actual_resume_at_utc,
                    source_start_event_id,
                    source_end_event_id
                ) VALUES (
                    :floatPlanId,
                    :userId,
                    :routeInstanceId,
                    :routeLegOrder,
                    :localTimezone,
                    :segmentType,
                    :startedAtUtc,
                    NULL,
                    :expectedResumeAtUtc,
                    :actualResumeAtUtc,
                    :sourceStartEventId,
                    NULL
                )
            ", {
                floatPlanId = { value = arguments.planCtx.floatPlanId, cfsqltype = "cf_sql_integer" },
                userId = { value = arguments.planCtx.userId, cfsqltype = "cf_sql_integer" },
                routeInstanceId = { value = arguments.routeCtx.routeInstanceId, cfsqltype = "cf_sql_integer", null = (arguments.routeCtx.routeInstanceId LTE 0) },
                routeLegOrder = { value = arguments.routeCtx.routeLegOrder, cfsqltype = "cf_sql_integer", null = (arguments.routeCtx.routeLegOrder LTE 0) },
                localTimezone = { value = arguments.planCtx.localTimezone, cfsqltype = "cf_sql_varchar" },
                segmentType = { value = arguments.segmentType, cfsqltype = "cf_sql_varchar" },
                startedAtUtc = { value = arguments.startedAtUtc, cfsqltype = "cf_sql_timestamp" },
                expectedResumeAtUtc = { value = arguments.expectedResumeAtUtc, cfsqltype = "cf_sql_timestamp", null = NOT isDate(arguments.expectedResumeAtUtc) },
                actualResumeAtUtc = { value = arguments.actualResumeAtUtc, cfsqltype = "cf_sql_timestamp", null = NOT isDate(arguments.actualResumeAtUtc) },
                sourceStartEventId = { value = arguments.sourceStartEventId, cfsqltype = "cf_sql_bigint", null = (arguments.sourceStartEventId LTE 0) }
            }, { datasource = variables.datasource });
        </cfscript>
    </cffunction>

    <cffunction name="closeSegment" access="private" returntype="void" output="false">
        <cfargument name="segmentId" type="numeric" required="true">
        <cfargument name="endedAtUtc" type="any" required="true">
        <cfargument name="sourceEndEventId" type="numeric" required="false" default="0">
        <cfscript>
            queryExecute("
                UPDATE floatplan_activity_segments
                SET ended_at_utc = :endedAtUtc,
                    source_end_event_id = :sourceEndEventId
                WHERE id = :segmentId
                  AND ended_at_utc IS NULL
            ", {
                endedAtUtc = { value = arguments.endedAtUtc, cfsqltype = "cf_sql_timestamp" },
                sourceEndEventId = { value = arguments.sourceEndEventId, cfsqltype = "cf_sql_bigint", null = (arguments.sourceEndEventId LTE 0) },
                segmentId = { value = arguments.segmentId, cfsqltype = "cf_sql_bigint" }
            }, { datasource = variables.datasource });
        </cfscript>
    </cffunction>

    <cffunction name="resolveExpectedResumeAt" access="private" returntype="any" output="false">
        <cfargument name="payload" type="struct" required="true">
        <cfargument name="planCtx" type="struct" required="true">
        <cfscript>
            if (structKeyExists(arguments.payload, "expected_resume_at_utc") AND isDate(arguments.payload.expected_resume_at_utc)) {
                return arguments.payload.expected_resume_at_utc;
            }
            if (isDate(arguments.planCtx.secureForNightUntil)) {
                return arguments.planCtx.secureForNightUntil;
            }
            if (isDate(arguments.planCtx.expectedCheckinAt)) {
                return arguments.planCtx.expectedCheckinAt;
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="isResumeEligiblePauseSegment" access="private" returntype="boolean" output="false">
        <cfargument name="segmentType" type="string" required="true">
        <cfscript>
            return listFindNoCase("PAUSED_SECURE_FOR_NIGHT,PAUSED_DELAYED", uCase(trim(arguments.segmentType))) GT 0;
        </cfscript>
    </cffunction>

    <cffunction name="resolveLocalTimezone" access="private" returntype="string" output="false">
        <cfargument name="qPlan" type="query" required="true">
        <cfscript>
            var tz = "";
            if (arguments.qPlan.recordCount GT 0) {
                tz = trim(toString(isNull(arguments.qPlan.departureTZ[1]) ? "" : arguments.qPlan.departureTZ[1]));
                if (!len(tz)) {
                    tz = trim(toString(isNull(arguments.qPlan.departTimezone[1]) ? "" : arguments.qPlan.departTimezone[1]));
                }
            }
            return (len(tz) ? tz : "UTC");
        </cfscript>
    </cffunction>

    <cffunction name="routeActionStatusForEvent" access="private" returntype="string" output="false">
        <cfargument name="eventType" type="string" required="true">
        <cfscript>
            switch (uCase(trim(arguments.eventType))) {
                case "ROUTE_LEG_COMPLETED": return "COMPLETED";
                case "ROUTE_LEG_STARTED": return "STARTED";
                case "FLOATPLAN_CLOSED": return "CLOSED";
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="normalizeMonitoringStatus" access="private" returntype="string" output="false">
        <cfargument name="rawStatus" type="string" required="true">
        <cfscript>
            var statusVal = uCase(trim(arguments.rawStatus));
            statusVal = replace(statusVal, " ", "_", "all");
            statusVal = replace(statusVal, "-", "_", "all");
            if (statusVal EQ "SECURE_FOR_THE_NIGHT") {
                return "SECURE_FOR_NIGHT";
            }
            return statusVal;
        </cfscript>
    </cffunction>

    <cffunction name="buildIdempotencyKey" access="private" returntype="string" output="false">
        <cfargument name="scope" type="string" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="status" type="string" required="true">
        <cfargument name="occurredAtUtc" type="any" required="true">
        <cfscript>
            return "fpw:" & arguments.scope & ":" & arguments.floatPlanId & ":" & normalizeMonitoringStatus(arguments.status) & ":" & formatUtc(arguments.occurredAtUtc);
        </cfscript>
    </cffunction>

    <cffunction name="safeString" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfscript>
            if (isNull(arguments.value)) {
                return "";
            }
            return trim(toString(arguments.value));
        </cfscript>
    </cffunction>

    <cffunction name="booleanValue" access="private" returntype="boolean" output="false">
        <cfargument name="value" required="true">
        <cfscript>
            var strVal = "";
            if (isBoolean(arguments.value)) {
                return arguments.value;
            }
            if (isNumeric(arguments.value)) {
                return val(arguments.value) NEQ 0;
            }
            strVal = lCase(trim(arguments.value & ""));
            return listFindNoCase("true,yes,on,1", strVal) GT 0;
        </cfscript>
    </cffunction>

    <cffunction name="formatUtc" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfscript>
            if (!isDate(arguments.value)) {
                return "";
            }
            return dateTimeFormat(arguments.value, "yyyy-mm-dd'T'HH:nn:ss'Z'");
        </cfscript>
    </cffunction>

</cfcomponent>
