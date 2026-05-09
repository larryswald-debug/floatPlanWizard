<cfcomponent output="false">

    <cffunction name="init" access="public" returntype="any" output="false">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            variables.datasource = arguments.datasource;
            return this;
        </cfscript>
    </cffunction>

    <cffunction name="getProjectionForStream" access="public" returntype="struct" output="false">
        <cfargument name="streamId" type="numeric" required="true">
        <cfargument name="asOfUtc" type="any" required="false" default="">
        <cfargument name="options" type="any" required="false" default="">
        <cfscript>
            var out = baseProjection();
            var qStream = queryNew("");

            if (arguments.streamId LTE 0) {
                out.success = false;
                out.message = "streamId is required.";
                return out;
            }

            qStream = queryExecute("
                SELECT floatplan_id
                FROM voyage_streams
                WHERE id = :streamId
                LIMIT 1
            ", {
                streamId = { value = arguments.streamId, cfsqltype = "cf_sql_integer" }
            }, { datasource = variables.datasource });

            if (qStream.recordCount EQ 0) {
                out.success = false;
                out.message = "Voyage stream was not found.";
                return out;
            }

            return getProjection(safeNumber(qStream.floatplan_id[1]), arguments.asOfUtc, arguments.options);
        </cfscript>
    </cffunction>

    <cffunction name="getProjection" access="public" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="asOfUtc" type="any" required="false" default="">
        <cfargument name="options" type="any" required="false" default="">
        <cfscript>
            var out = baseProjection();
            var projectionOptions = normalizeProjectionOptions(arguments.options);
            var qPlan = queryNew("");
            var qCanonicalEvents = queryNew("");
            var qCanonicalSegments = queryNew("");
            var qMonitorEvents = queryNew("");
            var qProgress = queryNew("");
            var qLegs = queryNew("");
            var qRouteInstance = queryNew("");
            var asOfDt = normalizeAsOf(arguments.asOfUtc);
            var departureTz = "";
            var ownerUserId = 0;
            var routeInstanceId = 0;
            var canonicalSegments = [];
            var canonicalOpenSegments = [];
            var diagnosticSegments = [];
            var diagnosticOpenSegments = [];
            var segmentsForProjection = [];
            var currentLeg = {};
            var routeInputs = {};
            var paceMeta = {};
            var speedKn = 0;
            var progressSpeedKn = 0;
            var manualDelayMinutes = 0;
            var dayBounds = {};
            var todayProgress = {};
            var currentLegProgress = {};
            var etaProjection = {};
            var routeTimeline = {};
            var latestActivity = {};
            var canonicalEventsTableExists = tableExists("floatplan_events");
            var canonicalSegmentsTableExists = tableExists("floatplan_activity_segments");

            if (arguments.floatPlanId LTE 0) {
                out.success = false;
                out.message = "floatPlanId is required.";
                return out;
            }

            qPlan = loadPlan(arguments.floatPlanId);
            if (qPlan.recordCount EQ 0) {
                out.success = false;
                out.message = "Float plan was not found.";
                return out;
            }

            ownerUserId = safeNumber(qPlan.userId[1]);
            routeInstanceId = safeNumber(qPlan.route_instance_id[1]);
            departureTz = resolveDepartureTimezone(qPlan);

            out.success = true;
            out.generatedAtUtc = formatUtc(asOfDt);
            out.floatPlanId = safeNumber(qPlan.floatPlanId[1]);
            out.userId = ownerUserId;
            out.routeInstanceId = routeInstanceId;
            out.monitoringState = buildMonitoringState(qPlan);
            out.dailyWindow = {
                "timezone" = departureTz,
                "asOfUtc" = formatUtc(asOfDt),
                "source" = "projection"
            };

            latestActivity = buildLatestActivity(qPlan);
            out.latestActivity = latestActivity;

            if (canonicalEventsTableExists) {
                qCanonicalEvents = queryExecute("
                    SELECT id, event_type, event_status, occurred_at_utc, source, source_monitoring_id, source_post_id
                    FROM floatplan_events
                    WHERE floatplan_id = :floatPlanId
                      AND voided_at_utc IS NULL
                    ORDER BY occurred_at_utc ASC, id ASC
                ", {
                    floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
                }, { datasource = variables.datasource });
                out.eventLedger = {
                    "source" = "floatplan_events",
                    "count" = qCanonicalEvents.recordCount,
                    "futureSourceOfTruth" = true
                };
            } else {
                out.eventLedger = {
                    "source" = "floatplan_events",
                    "count" = 0,
                    "futureSourceOfTruth" = true,
                    "available" = false
                };
                addWarning(out, "CANONICAL_EVENT_TABLE_MISSING", "floatplan_events does not exist yet. Run the approved additive migration before enabling write paths.");
            }

            if (canonicalSegmentsTableExists) {
                qCanonicalSegments = queryExecute("
                    SELECT id, route_instance_id, route_leg_order, local_timezone, segment_type, started_at_utc, ended_at_utc,
                           expected_resume_at_utc, actual_resume_at_utc, source_start_event_id, source_end_event_id
                    FROM floatplan_activity_segments
                    WHERE floatplan_id = :floatPlanId
                    ORDER BY started_at_utc ASC, id ASC
                ", {
                    floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
                }, { datasource = variables.datasource });
                canonicalSegments = segmentRowsToArray(qCanonicalSegments, "canonical");
            } else {
                addWarning(out, "CANONICAL_ACTIVITY_SEGMENT_TABLE_MISSING", "floatplan_activity_segments does not exist yet. Run the approved additive migration before enabling write paths.");
            }

            canonicalOpenSegments = getOpenSegments(canonicalSegments);
            if (arrayLen(canonicalOpenSegments) GT 1) {
                addWarning(out, "MULTIPLE_OPEN_SEGMENTS", "Multiple open canonical activity segments were detected for this float plan.");
            }

            out.activitySegments = canonicalSegments;
            if (arrayLen(canonicalSegments) EQ 0) {
                addWarning(out, "NO_CANONICAL_ACTIVITY_SEGMENTS", "No canonical activity segments exist. Legacy-derived segments are diagnostic only and must not be treated as permanent truth.");
            }

            qMonitorEvents = loadMonitorEvents(arguments.floatPlanId);
            diagnosticSegments = deriveDiagnosticSegments(qMonitorEvents, qPlan, asOfDt, departureTz, routeInstanceId, ownerUserId);
            diagnosticOpenSegments = getOpenSegments(diagnosticSegments);
            if (arrayLen(diagnosticOpenSegments) GT 1) {
                addWarning(out, "MULTIPLE_OPEN_LEGACY_DIAGNOSTIC_SEGMENTS", "Multiple open legacy-derived diagnostic segments were detected.");
            }

            out.diagnostics = {
                "legacyInferredSegments" = diagnosticSegments,
                "legacyInferredSegmentsAreCanonical" = false,
                "legacySource" = "floatplan_monitor_events",
                "proofTarget" = {
                    "floatPlanId" = arguments.floatPlanId,
                    "streamId" = "",
                    "purpose" = "read-only comparison only"
                }
            };

            if (arguments.floatPlanId EQ 8073) {
                out.diagnostics.proofTarget.streamId = 957;
            }

            qProgress = loadLegProgress(routeInstanceId, ownerUserId);
            qLegs = loadRouteLegs(routeInstanceId);
            currentLeg = buildCurrentLeg(qProgress, qLegs, out);
            out.currentLeg = currentLeg;

            qRouteInstance = loadRouteInstance(routeInstanceId);
            routeInputs = parseRouteInputs(qRouteInstance);
            paceMeta = buildPaceMeta(routeInputs, arguments.floatPlanId);
            speedKn = resolveEffectiveSpeed(routeInputs, arguments.floatPlanId);
            progressSpeedKn = resolveProgressSpeed(routeInputs);
            manualDelayMinutes = max(0, safeNumber(qPlan.manual_delay_minutes_total[1]));
            out.pace = paceMeta;

            segmentsForProjection = (arrayLen(canonicalSegments) GT 0 ? canonicalSegments : diagnosticSegments);
            if (arrayLen(canonicalSegments) EQ 0 AND arrayLen(diagnosticSegments) GT 0) {
                addWarning(out, "USING_LEGACY_DIAGNOSTIC_SEGMENTS", "Projection metrics are using legacy-derived diagnostic segments because no canonical segment rows exist.");
            }

            dayBounds = getLocalDayBounds(asOfDt, departureTz);
            todayProgress = buildTodayProgress(segmentsForProjection, dayBounds, asOfDt, progressSpeedKn, out);
            currentLegProgress = buildCurrentLegProgress(currentLeg, segmentsForProjection, asOfDt, progressSpeedKn, out);
            etaProjection = buildEtaProjection(currentLeg, currentLegProgress, diagnosticOpenSegments, canonicalOpenSegments, asOfDt, speedKn, manualDelayMinutes);
            routeTimeline = buildRouteTimeline(qPlan, qLegs, qProgress, currentLeg, currentLegProgress, etaProjection, canonicalSegments, asOfDt, speedKn, out, projectionOptions, paceMeta);

            out.dailyWindow.localDate = dayBounds.localDate;
            out.dailyWindow.dayStartUtc = formatUtc(dayBounds.startUtc);
            out.dailyWindow.dayEndUtc = formatUtc(dayBounds.endUtc);
            out.dailyWindow.currentSegmentType = getCurrentSegmentType(segmentsForProjection, asOfDt);
            out.todayProgress = todayProgress;
            out.currentLegProgress = currentLegProgress;
            out.etaProjection = etaProjection;
            out.routeTimeline = routeTimeline;

            if (arguments.floatPlanId EQ 8073) {
                out.diagnostics.bugExplanation = buildBugExplanation8073(out, qPlan);
            }

            return out;
        </cfscript>
    </cffunction>

    <cffunction name="baseProjection" access="private" returntype="struct" output="false">
        <cfscript>
            return {
                "success" = false,
                "message" = "",
                "generatedAtUtc" = "",
                "floatPlanId" = 0,
                "userId" = 0,
                "routeInstanceId" = 0,
                "eventLedger" = {},
                "monitoringState" = {},
                "latestActivity" = {},
                "dailyWindow" = {},
                "activitySegments" = [],
                "currentLeg" = {},
                "pace" = {},
                "todayProgress" = {},
                "currentLegProgress" = {},
                "etaProjection" = {},
                "routeTimeline" = {},
                "diagnostics" = {},
                "authorityWarnings" = []
            };
        </cfscript>
    </cffunction>

    <cffunction name="normalizeProjectionOptions" access="private" returntype="struct" output="false">
        <cfargument name="options" type="any" required="false" default="">
        <cfscript>
            var out = {
                "includeOperationalLockTime" = false
            };

            if (isStruct(arguments.options) AND structKeyExists(arguments.options, "includeOperationalLockTime")) {
                out.includeOperationalLockTime = (listFindNoCase("true,1,yes,y", trim(toString(arguments.options.includeOperationalLockTime))) GT 0);
            }

            return out;
        </cfscript>
    </cffunction>

    <cffunction name="loadPlan" access="private" returntype="query" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            return queryExecute("
                SELECT fp.floatPlanId, fp.userId, fp.status, fp.route_instance_id, fp.departureTZ, fp.departTimezone,
                       fp.dailyStartLocalTime, fp.departureTime, fp.departureTimeUTC, fp.checkedInAt,
                       fp.checkin_context, fp.overnight_pause_minutes_total, fp.manual_delay_minutes_total,
                       fm.id AS monitoring_id, fm.monitor_state, fm.expected_checkin_at, fm.last_checkin_at,
                       fm.last_checkin_status, fm.secure_for_night, fm.secure_for_night_until
                FROM floatplans fp
                LEFT JOIN floatplan_monitoring fm
                  ON fm.float_plan_id = fp.floatPlanId
                WHERE fp.floatPlanId = :floatPlanId
                LIMIT 1
            ", {
                floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
            }, { datasource = variables.datasource });
        </cfscript>
    </cffunction>

    <cffunction name="loadMonitorEvents" access="private" returntype="query" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            return queryExecute("
                SELECT id, monitoring_id, event_type, event_at, checkin_status, actor_type, meta_json
                FROM floatplan_monitor_events
                WHERE float_plan_id = :floatPlanId
                ORDER BY event_at ASC, id ASC
            ", {
                floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
            }, { datasource = variables.datasource });
        </cfscript>
    </cffunction>

    <cffunction name="loadLegProgress" access="private" returntype="query" output="false">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfargument name="userId" type="numeric" required="true">
        <cfscript>
            if (arguments.routeInstanceId LTE 0 OR arguments.userId LTE 0) {
                return queryNew("");
            }
            return queryExecute("
                SELECT id, leg_order, UPPER(TRIM(status)) AS status_val, leg_started_at, completed_at, created_at, updated_at
                FROM route_instance_leg_progress
                WHERE route_instance_id = :routeInstanceId
                  AND user_id = :userId
                ORDER BY leg_order ASC, id ASC
            ", {
                routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" },
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
            }, { datasource = variables.datasource });
        </cfscript>
    </cffunction>

    <cffunction name="loadRouteLegs" access="private" returntype="query" output="false">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfscript>
            if (arguments.routeInstanceId LTE 0) {
                return queryNew("");
            }
            return queryExecute("
                SELECT
                    ril.id,
                    ril.leg_order,
                    ril.segment_id,
                    ril.source_loop_segment_id,
                    ril.start_name,
                    ril.end_name,
                    ril.base_dist_nm,
                    COALESCE(ril.lock_count, 0) AS lock_count,
                    ril.notes AS leg_notes,
                    ri.template_route_code,
                    lr.short_code AS lock_route_code,
                    lr.code AS template_route_full_code,
                    rts.order_index AS lock_leg_order
                FROM route_instance_legs ril
                INNER JOIN route_instances ri
                    ON ri.id = ril.route_instance_id
                LEFT JOIN route_template_segments rts
                    ON rts.segment_id = ril.segment_id
                LEFT JOIN loop_routes lr
                    ON lr.id = rts.route_id
                   AND (lr.short_code = ri.template_route_code OR lr.code = ri.template_route_code)
                WHERE ril.route_instance_id = :routeInstanceId
                ORDER BY ril.leg_order ASC, ril.id ASC
            ", {
                routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" }
            }, { datasource = variables.datasource });
        </cfscript>
    </cffunction>

    <cffunction name="loadRouteInstance" access="private" returntype="query" output="false">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfscript>
            if (arguments.routeInstanceId LTE 0) {
                return queryNew("");
            }
            return queryExecute("
                SELECT id, routegen_inputs_json
                FROM route_instances
                WHERE id = :routeInstanceId
                LIMIT 1
            ", {
                routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" }
            }, { datasource = variables.datasource });
        </cfscript>
    </cffunction>

    <cffunction name="buildMonitoringState" access="private" returntype="struct" output="false">
        <cfargument name="qPlan" type="query" required="true">
        <cfscript>
            var row = arguments.qPlan;
            return {
                "monitoringId" = safeNumber(row.monitoring_id[1]),
                "monitorState" = safeString(row.monitor_state[1]),
                "expectedCheckinAtUtc" = formatUtc(row.expected_checkin_at[1]),
                "lastCheckinAtUtc" = formatUtc(row.last_checkin_at[1]),
                "lastCheckinStatus" = safeString(row.last_checkin_status[1]),
                "secureForNight" = (safeNumber(row.secure_for_night[1]) EQ 1),
                "secureForNightUntilUtc" = formatUtc(row.secure_for_night_until[1])
            };
        </cfscript>
    </cffunction>

    <cffunction name="buildLatestActivity" access="private" returntype="struct" output="false">
        <cfargument name="qPlan" type="query" required="true">
        <cfscript>
            return {
                "occurredAtUtc" = formatUtc(arguments.qPlan.checkedInAt[1]),
                "status" = safeString(arguments.qPlan.last_checkin_status[1]),
                "context" = safeString(arguments.qPlan.checkin_context[1]),
                "authority" = "display_only",
                "note" = "floatplans.checkedInAt is overwritten by every check-in and is not a stable progress authority."
            };
        </cfscript>
    </cffunction>

    <cffunction name="deriveDiagnosticSegments" access="private" returntype="array" output="false">
        <cfargument name="qEvents" type="query" required="true">
        <cfargument name="qPlan" type="query" required="true">
        <cfargument name="asOfUtc" type="date" required="true">
        <cfargument name="timezone" type="string" required="true">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfargument name="userId" type="numeric" required="true">
        <cfscript>
            var segments = [];
            var secureUntilByAt = {};
            var i = 0;
            var eventType = "";
            var statusVal = "";
            var eventAt = "";
            var key = "";
            var meta = {};
            var currentIndex = 0;
            var expectedResume = "";

            for (i = 1; i LTE arguments.qEvents.recordCount; i++) {
                eventType = safeString(arguments.qEvents.event_type[i]);
                eventAt = arguments.qEvents.event_at[i];
                if (eventType EQ "SECURE_FOR_NIGHT_SET" AND isDate(eventAt)) {
                    meta = parseJsonStruct(arguments.qEvents.meta_json[i]);
                    if (structKeyExists(meta, "SECURE_FOR_NIGHT_UNTIL") AND isDate(meta.SECURE_FOR_NIGHT_UNTIL)) {
                        secureUntilByAt[formatUtc(eventAt)] = meta.SECURE_FOR_NIGHT_UNTIL;
                    }
                }
            }

            for (i = 1; i LTE arguments.qEvents.recordCount; i++) {
                eventType = safeString(arguments.qEvents.event_type[i]);
                statusVal = uCase(safeString(arguments.qEvents.checkin_status[i]));
                eventAt = arguments.qEvents.event_at[i];
                if (!isDate(eventAt)) {
                    continue;
                }

                if (eventType EQ "MONITORING_STARTED") {
                    if (currentIndex EQ 0) {
                        arrayAppend(segments, newSegment("UNDERWAY", eventAt, "", "", "", arguments.timezone, arguments.routeInstanceId, arguments.userId, "legacy_diagnostic", arguments.qEvents.id[i], 0));
                        currentIndex = arrayLen(segments);
                    }
                    continue;
                }

                if (eventType NEQ "CHECKIN_RECEIVED") {
                    continue;
                }

                if (statusVal EQ "SECURE_FOR_NIGHT") {
                    if (currentIndex GT 0 AND !isDate(segments[currentIndex].endedAtUtc)) {
                        segments[currentIndex].endedAtUtc = formatUtc(eventAt);
                        segments[currentIndex].sourceEndEventId = safeNumber(arguments.qEvents.id[i]);
                    }
                    key = formatUtc(eventAt);
                    expectedResume = (structKeyExists(secureUntilByAt, key) ? secureUntilByAt[key] : "");
                    arrayAppend(segments, newSegment("PAUSED_SECURE_FOR_NIGHT", eventAt, "", expectedResume, "", arguments.timezone, arguments.routeInstanceId, arguments.userId, "legacy_diagnostic", arguments.qEvents.id[i], 0));
                    currentIndex = arrayLen(segments);
                    continue;
                }

                if (statusVal EQ "DELAYED") {
                    if (currentIndex GT 0 AND segments[currentIndex].segmentType EQ "UNDERWAY" AND !isDate(segments[currentIndex].endedAtUtc)) {
                        segments[currentIndex].endedAtUtc = formatUtc(eventAt);
                        segments[currentIndex].sourceEndEventId = safeNumber(arguments.qEvents.id[i]);
                        arrayAppend(segments, newSegment("PAUSED_DELAYED", eventAt, "", "", "", arguments.timezone, arguments.routeInstanceId, arguments.userId, "legacy_diagnostic", arguments.qEvents.id[i], 0));
                        currentIndex = arrayLen(segments);
                    }
                    continue;
                }

                if (statusVal EQ "ON_TRACK") {
                    if (currentIndex GT 0 AND isResumeEligiblePauseSegment(segments[currentIndex].segmentType) AND !isDate(segments[currentIndex].endedAtUtc)) {
                        segments[currentIndex].endedAtUtc = formatUtc(eventAt);
                        segments[currentIndex].actualResumeAtUtc = formatUtc(eventAt);
                        segments[currentIndex].sourceEndEventId = safeNumber(arguments.qEvents.id[i]);
                        arrayAppend(segments, newSegment("UNDERWAY", eventAt, "", "", "", arguments.timezone, arguments.routeInstanceId, arguments.userId, "legacy_diagnostic", arguments.qEvents.id[i], 0));
                        currentIndex = arrayLen(segments);
                    } else if (currentIndex EQ 0) {
                        arrayAppend(segments, newSegment("UNDERWAY", eventAt, "", "", "", arguments.timezone, arguments.routeInstanceId, arguments.userId, "legacy_diagnostic", arguments.qEvents.id[i], 0));
                        currentIndex = arrayLen(segments);
                    }
                }
            }

            return segments;
        </cfscript>
    </cffunction>

    <cffunction name="segmentRowsToArray" access="private" returntype="array" output="false">
        <cfargument name="qSegments" type="query" required="true">
        <cfargument name="authority" type="string" required="true">
        <cfscript>
            var arr = [];
            var i = 0;
            for (i = 1; i LTE arguments.qSegments.recordCount; i++) {
                arrayAppend(arr, {
                    "id" = safeNumber(arguments.qSegments.id[i]),
                    "segmentType" = safeString(arguments.qSegments.segment_type[i]),
                    "startedAtUtc" = formatUtc(arguments.qSegments.started_at_utc[i]),
                    "endedAtUtc" = formatUtc(arguments.qSegments.ended_at_utc[i]),
                    "expectedResumeAtUtc" = formatUtc(arguments.qSegments.expected_resume_at_utc[i]),
                    "actualResumeAtUtc" = formatUtc(arguments.qSegments.actual_resume_at_utc[i]),
                    "routeInstanceId" = safeNumber(arguments.qSegments.route_instance_id[i]),
                    "routeLegOrder" = safeNumber(arguments.qSegments.route_leg_order[i]),
                    "localTimezone" = safeString(arguments.qSegments.local_timezone[i]),
                    "sourceStartEventId" = safeNumber(arguments.qSegments.source_start_event_id[i]),
                    "sourceEndEventId" = safeNumber(arguments.qSegments.source_end_event_id[i]),
                    "authority" = arguments.authority
                });
            }
            return arr;
        </cfscript>
    </cffunction>

    <cffunction name="newSegment" access="private" returntype="struct" output="false">
        <cfargument name="segmentType" type="string" required="true">
        <cfargument name="startedAtUtc" type="any" required="true">
        <cfargument name="endedAtUtc" type="any" required="false" default="">
        <cfargument name="expectedResumeAtUtc" type="any" required="false" default="">
        <cfargument name="actualResumeAtUtc" type="any" required="false" default="">
        <cfargument name="timezone" type="string" required="true">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="authority" type="string" required="true">
        <cfargument name="sourceStartEventId" type="numeric" required="false" default="0">
        <cfargument name="sourceEndEventId" type="numeric" required="false" default="0">
        <cfscript>
            return {
                "id" = 0,
                "segmentType" = arguments.segmentType,
                "startedAtUtc" = formatUtc(arguments.startedAtUtc),
                "endedAtUtc" = formatUtc(arguments.endedAtUtc),
                "expectedResumeAtUtc" = formatUtc(arguments.expectedResumeAtUtc),
                "actualResumeAtUtc" = formatUtc(arguments.actualResumeAtUtc),
                "routeInstanceId" = safeNumber(arguments.routeInstanceId),
                "routeLegOrder" = 0,
                "localTimezone" = arguments.timezone,
                "sourceStartEventId" = safeNumber(arguments.sourceStartEventId),
                "sourceEndEventId" = safeNumber(arguments.sourceEndEventId),
                "authority" = arguments.authority
            };
        </cfscript>
    </cffunction>

    <cffunction name="buildCurrentLeg" access="private" returntype="struct" output="false">
        <cfargument name="qProgress" type="query" required="true">
        <cfargument name="qLegs" type="query" required="true">
        <cfargument name="out" type="struct" required="true">
        <cfscript>
            var highestCompleted = 0;
            var activeOrder = 0;
            var i = 0;
            var row = {};
            var legDetails = {};
            var statusVal = "";
            var startedAt = "";
            var completedAt = "";

            for (i = 1; i LTE arguments.qProgress.recordCount; i++) {
                statusVal = safeString(arguments.qProgress.status_val[i]);
                if (statusVal EQ "COMPLETED" AND safeNumber(arguments.qProgress.leg_order[i]) GT highestCompleted) {
                    highestCompleted = safeNumber(arguments.qProgress.leg_order[i]);
                }
            }

            for (i = 1; i LTE arguments.qProgress.recordCount; i++) {
                statusVal = safeString(arguments.qProgress.status_val[i]);
                startedAt = arguments.qProgress.leg_started_at[i];
                completedAt = arguments.qProgress.completed_at[i];
                if (safeNumber(arguments.qProgress.leg_order[i]) GT highestCompleted AND !isDate(completedAt) AND (isDate(startedAt) OR listFindNoCase("STARTED,IN_PROGRESS", statusVal))) {
                    activeOrder = safeNumber(arguments.qProgress.leg_order[i]);
                    row = {
                        "status" = statusVal,
                        "startedAtUtc" = formatUtc(startedAt),
                        "completedAtUtc" = formatUtc(completedAt)
                    };
                    if (isDate(startedAt) AND statusVal EQ "NOT_STARTED") {
                        addWarning(arguments.out, "LEG_STARTED_STATUS_NOT_STARTED", "route_instance_leg_progress has leg_started_at while status is NOT_STARTED.");
                    }
                    break;
                }
            }

            if (activeOrder LTE 0) {
                activeOrder = highestCompleted + 1;
                row = { "status" = "NOT_STARTED", "startedAtUtc" = "", "completedAtUtc" = "" };
            }

            legDetails = findLegDetails(arguments.qLegs, activeOrder);
            return {
                "routeLegOrder" = activeOrder,
                "status" = row.status,
                "startedAtUtc" = row.startedAtUtc,
                "completedAtUtc" = row.completedAtUtc,
                "startName" = legDetails.startName,
                "endName" = legDetails.endName,
                "distanceNm" = legDetails.distanceNm,
                "authority" = "route_instance_leg_progress"
            };
        </cfscript>
    </cffunction>

    <cffunction name="buildTodayProgress" access="private" returntype="struct" output="false">
        <cfargument name="segments" type="array" required="true">
        <cfargument name="dayBounds" type="struct" required="true">
        <cfargument name="asOfUtc" type="date" required="true">
        <cfargument name="speedKn" type="numeric" required="true">
        <cfargument name="out" type="struct" required="true">
        <cfscript>
            var windowEnd = minDate(arguments.dayBounds.endUtc, arguments.asOfUtc);
            var seconds = sumUnderwayOverlapSeconds(arguments.segments, arguments.dayBounds.startUtc, windowEnd);
            var hours = seconds / 3600;
            var miles = 0;
            if (arguments.speedKn GT 0) {
                miles = hours * arguments.speedKn;
            } else {
                addWarning(arguments.out, "MISSING_EFFECTIVE_SPEED", "Today mileage could not be projected because an effective speed was not available.");
            }
            return {
                "authority" = (arrayLen(arguments.segments) ? arguments.segments[1].authority : "none"),
                "localDate" = arguments.dayBounds.localDate,
                "underwaySeconds" = seconds,
                "hoursToday" = roundTo1(hours),
                "milesTodayNm" = roundTo1(miles),
                "usesLatestCheckinAsAnchor" = false
            };
        </cfscript>
    </cffunction>

    <cffunction name="buildCurrentLegProgress" access="private" returntype="struct" output="false">
        <cfargument name="currentLeg" type="struct" required="true">
        <cfargument name="segments" type="array" required="true">
        <cfargument name="asOfUtc" type="date" required="true">
        <cfargument name="progressSpeedKn" type="numeric" required="true">
        <cfargument name="out" type="struct" required="true">
        <cfscript>
            var legStart = "";
            var seconds = 0;
            var hours = 0;
            var completedNm = 0;
            var remainingNm = 0;
            var pct = 0;
            var openSegments = getOpenSegments(arguments.segments);
            var openType = "";
            var isPaused = false;
            var expectedResumeAtUtc = "";
            var statusLabel = "Underway";
            var statusDetail = "Current leg progress uses route leg lifecycle and activity segments.";

            if (arrayLen(openSegments)) {
                openType = safeString(openSegments[arrayLen(openSegments)].segmentType);
                isPaused = (left(openType, 7) EQ "PAUSED_");
                expectedResumeAtUtc = openSegments[arrayLen(openSegments)].expectedResumeAtUtc;
                if (isPaused) {
                    statusLabel = "Paused";
                    statusDetail = "Current leg progress is paused until resume.";
                    if (openType EQ "PAUSED_DELAYED") {
                        statusLabel = "Delayed";
                        statusDetail = "Current leg progress is paused by the latest Delayed check-in.";
                    } else if (openType EQ "PAUSED_SECURE_FOR_NIGHT") {
                        statusLabel = "Secure for the Night";
                        statusDetail = "Current leg progress is paused for secure overnight.";
                    }
                }
            }

            if (!structKeyExists(arguments.currentLeg, "startedAtUtc") OR !isDate(arguments.currentLeg.startedAtUtc)) {
                addWarning(arguments.out, "CURRENT_LEG_START_MISSING", "Current leg progress cannot be projected without leg_started_at.");
                return {
                    "available" = false,
                    "authority" = "route_instance_leg_progress",
                    "completedNm" = 0,
                    "remainingNm" = safeNumber(arguments.currentLeg.distanceNm),
                    "percentComplete" = 0,
                    "underwaySeconds" = 0,
                    "paused" = isPaused,
                    "expectedResumeAtUtc" = expectedResumeAtUtc,
                    "speedKn" = arguments.progressSpeedKn,
                    "progressSpeedKn" = arguments.progressSpeedKn,
                    "completedNmAuthority" = "elapsed_underway_time_x_stable_progress_speed",
                    "statusLabel" = "Unavailable",
                    "statusDetail" = "Current leg progress cannot be projected without leg_started_at."
                };
            }
            legStart = parseIsoUtc(arguments.currentLeg.startedAtUtc);
            seconds = sumUnderwayOverlapSeconds(arguments.segments, legStart, arguments.asOfUtc);
            hours = seconds / 3600;
            if (arguments.progressSpeedKn GT 0) {
                completedNm = min(safeNumber(arguments.currentLeg.distanceNm), hours * arguments.progressSpeedKn);
            }
            remainingNm = max(0, safeNumber(arguments.currentLeg.distanceNm) - completedNm);
            if (safeNumber(arguments.currentLeg.distanceNm) GT 0) {
                pct = (completedNm / safeNumber(arguments.currentLeg.distanceNm)) * 100;
            }
            return {
                "available" = true,
                "authority" = "route_instance_leg_progress_plus_activity_segments",
                "underwaySeconds" = seconds,
                "hoursUnderwayOnLeg" = roundTo1(hours),
                "completedNm" = roundTo1(completedNm),
                "remainingNm" = roundTo1(remainingNm),
                "percentComplete" = roundTo1(pct),
                "paused" = isPaused,
                "expectedResumeAtUtc" = expectedResumeAtUtc,
                "speedKn" = arguments.progressSpeedKn,
                "progressSpeedKn" = arguments.progressSpeedKn,
                "completedNmAuthority" = "elapsed_underway_time_x_stable_progress_speed",
                "statusLabel" = statusLabel,
                "statusDetail" = statusDetail,
                "usesLatestCheckinAsAnchor" = false
            };
        </cfscript>
    </cffunction>

    <cffunction name="buildEtaProjection" access="private" returntype="struct" output="false">
        <cfargument name="currentLeg" type="struct" required="true">
        <cfargument name="currentLegProgress" type="struct" required="true">
        <cfargument name="diagnosticOpenSegments" type="array" required="true">
        <cfargument name="canonicalOpenSegments" type="array" required="true">
        <cfargument name="asOfUtc" type="date" required="true">
        <cfargument name="speedKn" type="numeric" required="true">
        <cfargument name="manualDelayMinutes" type="numeric" required="false" default="0">
        <cfscript>
            var openSegments = (arrayLen(arguments.canonicalOpenSegments) ? arguments.canonicalOpenSegments : arguments.diagnosticOpenSegments);
            var isPaused = false;
            var expectedResumeAtUtc = "";
            var remainingHours = 0;
            var etaDt = "";
            var openType = "";
            var manualDelayMinutesVal = max(0, safeNumber(arguments.manualDelayMinutes));
            var remainingDurationSeconds = 0;

            if (!structKeyExists(arguments.currentLegProgress, "available") OR !arguments.currentLegProgress.available OR arguments.speedKn LTE 0) {
                return {
                    "available" = false,
                    "authority" = "projection",
                    "reason" = "Missing current leg progress or effective speed.",
                    "etaUtc" = "",
                    "paused" = false,
                    "remainingDurationSeconds" = 0,
                    "remainingDurationLabel" = formatDurationSecondsLabel(0)
                };
            }

            if (arrayLen(openSegments)) {
                openType = safeString(openSegments[arrayLen(openSegments)].segmentType);
                isPaused = (left(openType, 7) EQ "PAUSED_");
                expectedResumeAtUtc = openSegments[arrayLen(openSegments)].expectedResumeAtUtc;
            }

            remainingHours = safeNumber(arguments.currentLegProgress.remainingNm) / arguments.speedKn;
            if (isPaused) {
                if (isDate(expectedResumeAtUtc)) {
                    etaDt = dateAdd("s", round(remainingHours * 3600), parseIsoUtc(expectedResumeAtUtc));
                }
            } else {
                etaDt = dateAdd("s", round(remainingHours * 3600), arguments.asOfUtc);
            }

            if (isDate(etaDt) AND manualDelayMinutesVal GT 0) {
                etaDt = dateAdd("n", manualDelayMinutesVal, etaDt);
            }
            if (isDate(etaDt)) {
                remainingDurationSeconds = max(0, dateDiff("s", arguments.asOfUtc, etaDt));
            }

            return {
                "available" = isDate(etaDt),
                "authority" = "current_leg_projection",
                "etaUtc" = formatUtc(etaDt),
                "paused" = isPaused,
                "expectedResumeAtUtc" = expectedResumeAtUtc,
                "remainingNm" = safeNumber(arguments.currentLegProgress.remainingNm),
                "speedKn" = arguments.speedKn,
                "etaSpeedKn" = arguments.speedKn,
                "etaSpeedAuthority" = "active_trip_pace_adjusted_projection_speed",
                "remainingDurationSeconds" = remainingDurationSeconds,
                "remainingDurationLabel" = formatDurationSecondsLabel(remainingDurationSeconds),
                "manualDelayMinutesTotal" = manualDelayMinutesVal,
                "usesLatestCheckinAsAnchor" = false
            };
        </cfscript>
    </cffunction>

    <cffunction name="buildRouteTimeline" access="private" returntype="struct" output="false">
        <cfargument name="qPlan" type="query" required="true">
        <cfargument name="qLegs" type="query" required="true">
        <cfargument name="qProgress" type="query" required="true">
        <cfargument name="currentLeg" type="struct" required="true">
        <cfargument name="currentLegProgress" type="struct" required="true">
        <cfargument name="etaProjection" type="struct" required="true">
        <cfargument name="canonicalSegments" type="array" required="true">
        <cfargument name="asOfUtc" type="date" required="true">
        <cfargument name="speedKn" type="numeric" required="true">
        <cfargument name="out" type="struct" required="true">
        <cfargument name="projectionOptions" type="struct" required="true">
        <cfargument name="paceMeta" type="struct" required="false" default="#{}#">
        <cfscript>
            var timeline = {};
            var i = 0;
            var totalNm = 0;
            var completedTotalNm = 0;
            var remainingTotalNm = 0;
            var percentTotal = 0;
            var distanceMissing = false;
            var currentLegOrder = 0;
            var priorArrivalDt = "";
            var finalArrivalUtc = "";
            var legOrder = 0;
            var distanceNm = 0;
            var progressRow = {};
            var statusVal = "";
            var startedAtUtc = "";
            var completedAtUtc = "";
            var isCompleted = false;
            var isCurrent = false;
            var isFuture = false;
            var state = "";
            var legCompletedNm = 0;
            var legRemainingNm = 0;
            var legPct = 0;
            var departureDt = "";
            var arrivalDt = "";
            var departureUtc = "";
            var arrivalUtc = "";
            var etaUtc = "";
            var departureSource = "";
            var arrivalSource = "";
            var legWarnings = [];
            var legLockModel = {};
            var lockTimeMinutes = 0;
            var legDurationSeconds = 0;
            var legEstimatedDurationSeconds = 0;
            var legRemainingDurationSeconds = 0;
            var durationAuthority = "";
            var manualDelayMinutes = max(0, safeNumber(arguments.qPlan.manual_delay_minutes_total[1]));
            var manualDelayAppliedToFuture = false;

            timeline = {
                "available" = false,
                "authority" = "canonical_projection",
                "generatedAtUtc" = formatUtc(arguments.asOfUtc),
                "routeInstanceId" = safeNumber(arguments.out.routeInstanceId),
                "currentLegOrder" = (structKeyExists(arguments.currentLeg, "routeLegOrder") ? safeNumber(arguments.currentLeg.routeLegOrder) : 0),
                "paused" = (structKeyExists(arguments.etaProjection, "paused") ? arguments.etaProjection.paused : false),
                "expectedResumeAtUtc" = (structKeyExists(arguments.etaProjection, "expectedResumeAtUtc") ? arguments.etaProjection.expectedResumeAtUtc : ""),
                "effectiveSpeedKn" = arguments.speedKn,
                "pace" = duplicate(arguments.paceMeta),
                "manualDelayMinutesTotal" = manualDelayMinutes,
                "usesLatestCheckinAsAnchor" = false,
                "summary" = {
                    "totalNm" = 0,
                    "completedNm" = 0,
                    "remainingNm" = 0,
                    "percentComplete" = 0,
                    "finalArrivalUtc" = ""
                },
                "legs" = [],
                "warnings" = []
            };
            currentLegOrder = timeline.currentLegOrder;

            if (
                (
                    !structKeyExists(arguments.out, "eventLedger")
                    OR !structKeyExists(arguments.out.eventLedger, "count")
                    OR safeNumber(arguments.out.eventLedger.count) LTE 0
                    OR arrayLen(arguments.canonicalSegments) EQ 0
                )
                AND canAttemptScheduledRouteTimeline(arguments.qPlan, arguments.qProgress, arguments.currentLeg, arguments.canonicalSegments, arguments.out)
            ) {
                return buildScheduledRouteTimelineProjection(arguments.qPlan, arguments.qLegs, arguments.qProgress, arguments.currentLeg, arguments.asOfUtc, arguments.speedKn, timeline, arguments.out, arguments.projectionOptions);
            }

            if (!structKeyExists(arguments.out, "eventLedger") OR !structKeyExists(arguments.out.eventLedger, "count") OR safeNumber(arguments.out.eventLedger.count) LTE 0) {
                timeline.reason = "Canonical event ledger rows are required for routeTimeline.";
                return timeline;
            }

            if (arrayLen(arguments.canonicalSegments) EQ 0) {
                timeline.reason = "Canonical activity segments are required for routeTimeline.";
                return timeline;
            }

            if (arguments.qLegs.recordCount EQ 0) {
                addRouteTimelineWarning(timeline, arguments.out, "ROUTE_TIMELINE_ROUTE_LEGS_MISSING", "Route timeline cannot be projected because route legs were not found.");
                timeline.reason = "Route legs were not found.";
                return timeline;
            }

            if (currentLegOrder LTE 0) {
                addRouteTimelineWarning(timeline, arguments.out, "ROUTE_TIMELINE_CURRENT_LEG_MISSING", "Route timeline cannot be projected because current leg authority is missing.");
                timeline.reason = "Current leg authority is missing.";
                return timeline;
            }

            if (arguments.speedKn LTE 0) {
                addRouteTimelineWarning(timeline, arguments.out, "ROUTE_TIMELINE_SPEED_MISSING", "Route timeline cannot be projected because effective speed is missing.");
                timeline.reason = "Effective speed is missing.";
                return timeline;
            }

            if (countActiveProgressRows(arguments.qProgress) GT 1) {
                addRouteTimelineWarning(timeline, arguments.out, "ROUTE_TIMELINE_MULTIPLE_ACTIVE_LEGS", "Route timeline cannot be projected because multiple active route legs were detected.");
                timeline.reason = "Multiple active route legs were detected.";
                return timeline;
            }

            for (i = 1; i LTE arguments.qLegs.recordCount; i++) {
                distanceNm = safeNumber(arguments.qLegs.base_dist_nm[i]);
                totalNm += distanceNm;
                if (distanceNm LTE 0) {
                    distanceMissing = true;
                }
            }

            if (distanceMissing OR totalNm LTE 0) {
                addRouteTimelineWarning(timeline, arguments.out, "ROUTE_TIMELINE_DISTANCE_MISSING", "Route timeline cannot be projected because one or more route leg distances are missing.");
                timeline.reason = "Route leg distance is missing.";
                return timeline;
            }

            for (i = 1; i LTE arguments.qLegs.recordCount; i++) {
                legOrder = safeNumber(arguments.qLegs.leg_order[i]);
                distanceNm = safeNumber(arguments.qLegs.base_dist_nm[i]);
                progressRow = findProgressForLeg(arguments.qProgress, legOrder);
                statusVal = safeString(progressRow.status);
                startedAtUtc = formatUtc(progressRow.legStartedAt);
                completedAtUtc = formatUtc(progressRow.completedAt);
                isCompleted = (statusVal EQ "COMPLETED" OR isDate(progressRow.completedAt) OR (currentLegOrder GT 0 AND legOrder LT currentLegOrder));
                isCurrent = (legOrder EQ currentLegOrder AND structKeyExists(arguments.currentLegProgress, "available") AND arguments.currentLegProgress.available);
                isFuture = (!isCompleted AND !isCurrent);
                state = (isCompleted ? "completed" : (isCurrent ? "current" : "future"));
                legCompletedNm = 0;
                legRemainingNm = distanceNm;
                legPct = 0;
                departureDt = "";
                arrivalDt = "";
                departureUtc = "";
                arrivalUtc = "";
                etaUtc = "";
                departureSource = "";
                arrivalSource = "";
                legWarnings = [];
                legLockModel = buildLegLockModel(
                    safeString(arguments.qLegs.lock_route_code[i]),
                    safeNumber(arguments.qLegs.lock_leg_order[i]),
                    safeNumber(arguments.qLegs.lock_count[i])
                );
                lockTimeMinutes = (arguments.projectionOptions.includeOperationalLockTime ? getOperationalLockTimeMinutes(legLockModel) : 0);
                legDurationSeconds = round((distanceNm / arguments.speedKn) * 3600) + round(lockTimeMinutes * 60);
                legEstimatedDurationSeconds = legDurationSeconds;
                legRemainingDurationSeconds = legDurationSeconds;
                durationAuthority = (lockTimeMinutes GT 0 ? "pace_weather_speed_plus_operational_lock_time" : "pace_weather_speed");

                if (isCompleted) {
                    legCompletedNm = distanceNm;
                    legRemainingNm = 0;
                    legPct = 100;
                    legRemainingDurationSeconds = 0;
                    durationAuthority = "projected_duration_completed_leg_actuals_preserved";
                    departureUtc = startedAtUtc;
                    arrivalUtc = completedAtUtc;
                    etaUtc = completedAtUtc;
                    departureSource = (len(departureUtc) ? "route_instance_leg_progress.leg_started_at" : "");
                    arrivalSource = (len(arrivalUtc) ? "route_instance_leg_progress.completed_at" : "route_order_before_current");
                    if (isDate(progressRow.completedAt)) {
                        priorArrivalDt = progressRow.completedAt;
                        finalArrivalUtc = completedAtUtc;
                    }
                } else if (isCurrent) {
                    legCompletedNm = safeNumber(arguments.currentLegProgress.completedNm);
                    legRemainingNm = safeNumber(arguments.currentLegProgress.remainingNm);
                    legPct = safeNumber(arguments.currentLegProgress.percentComplete);
                    departureUtc = arguments.currentLeg.startedAtUtc;
                    etaUtc = (structKeyExists(arguments.etaProjection, "etaUtc") ? arguments.etaProjection.etaUtc : "");
                    legRemainingDurationSeconds = (structKeyExists(arguments.etaProjection, "remainingDurationSeconds") ? safeNumber(arguments.etaProjection.remainingDurationSeconds) : round((legRemainingNm / arguments.speedKn) * 3600)) + round(lockTimeMinutes * 60);
                    durationAuthority = (lockTimeMinutes GT 0 ? "current_leg_eta_projection_plus_operational_lock_time" : "current_leg_eta_projection");
                    if (len(etaUtc) AND lockTimeMinutes GT 0) {
                        etaUtc = formatUtc(dateAdd("s", round(lockTimeMinutes * 60), parseIsoUtc(etaUtc)));
                    }
                    arrivalUtc = etaUtc;
                    departureSource = "route_instance_leg_progress.leg_started_at";
                    arrivalSource = (lockTimeMinutes GT 0 ? "etaProjection.etaUtc_plus_operational_lock_time" : "etaProjection.etaUtc");
                    if (len(etaUtc)) {
                        priorArrivalDt = parseIsoUtc(etaUtc);
                        finalArrivalUtc = etaUtc;
                    }
                    manualDelayAppliedToFuture = (manualDelayMinutes GT 0);
                    if (lockTimeMinutes GT 0) {
                        arrayAppend(legWarnings, {
                            "code" = "LOCK_TIME_NOT_POSITION_AWARE",
                            "message" = "Operational lock time is applied in full to the current leg ETA; remaining-lock position awareness is not included in this phase."
                        });
                    }
                    if (safeString(arguments.currentLeg.status) EQ "NOT_STARTED" AND len(safeString(arguments.currentLeg.startedAtUtc))) {
                        arrayAppend(legWarnings, {
                            "code" = "LEG_STARTED_STATUS_NOT_STARTED",
                            "message" = "route_instance_leg_progress has leg_started_at while status is NOT_STARTED."
                        });
                    }
                } else {
                    departureDt = (isDate(priorArrivalDt) ? priorArrivalDt : "");
                    if (isDate(departureDt)) {
                        if (manualDelayMinutes GT 0 AND !manualDelayAppliedToFuture) {
                            departureDt = dateAdd("n", manualDelayMinutes, departureDt);
                            manualDelayAppliedToFuture = true;
                        }
                        arrivalDt = dateAdd("s", legDurationSeconds, departureDt);
                        departureUtc = formatUtc(departureDt);
                        arrivalUtc = formatUtc(arrivalDt);
                        etaUtc = arrivalUtc;
                        priorArrivalDt = arrivalDt;
                        finalArrivalUtc = arrivalUtc;
                    }
                    departureSource = (len(departureUtc) ? "previous_leg_arrival_projection" : "");
                    arrivalSource = (len(arrivalUtc) ? (lockTimeMinutes GT 0 ? "projected_from_previous_leg_plus_operational_lock_time" : "projected_from_previous_leg") : "");
                }
                completedTotalNm += legCompletedNm;
                arrayAppend(timeline.legs, {
                    "routeLegOrder" = legOrder,
                    "fromName" = safeString(arguments.qLegs.start_name[i]),
                    "toName" = safeString(arguments.qLegs.end_name[i]),
                    "status" = statusVal,
                    "state" = state,
                    "isCurrent" = isCurrent,
                    "isCompleted" = isCompleted,
                    "isFuture" = isFuture,
                    "distanceNm" = roundTo1(distanceNm),
                    "effectiveSpeedKn" = arguments.speedKn,
                    "startedAtUtc" = startedAtUtc,
                    "completedAtUtc" = completedAtUtc,
                    "departureUtc" = departureUtc,
                    "arrivalUtc" = arrivalUtc,
                    "etaUtc" = etaUtc,
                    "completedNm" = roundTo1(legCompletedNm),
                    "remainingNm" = roundTo1(legRemainingNm),
                    "percentComplete" = roundTo1(legPct),
                    "estimatedDurationSeconds" = legEstimatedDurationSeconds,
                    "estimatedDurationLabel" = formatDurationSecondsLabel(legEstimatedDurationSeconds),
                    "remainingDurationSeconds" = legRemainingDurationSeconds,
                    "remainingDurationLabel" = formatDurationSecondsLabel(legRemainingDurationSeconds),
                    "durationAuthority" = durationAuthority,
                    "paused" = (isCurrent AND timeline.paused),
                    "expectedResumeAtUtc" = (isCurrent ? timeline.expectedResumeAtUtc : ""),
                    "departureSource" = departureSource,
                    "arrivalSource" = arrivalSource,
                    "authority" = "canonical_projection",
                    "usesLatestCheckinAsAnchor" = false,
                    "lockSummary" = legLockModel.lockSummary,
                    "locks" = legLockModel.locks,
                    "warnings" = legWarnings
                });
            }

            remainingTotalNm = max(0, totalNm - completedTotalNm);
            if (totalNm GT 0) {
                percentTotal = (completedTotalNm / totalNm) * 100;
            }

            timeline.available = true;
            timeline.summary = {
                "totalNm" = roundTo1(totalNm),
                "completedNm" = roundTo1(completedTotalNm),
                "remainingNm" = roundTo1(remainingTotalNm),
                "percentComplete" = roundTo1(percentTotal),
                "finalArrivalUtc" = finalArrivalUtc,
                "effectiveSpeedKn" = arguments.speedKn,
                "manualDelayMinutesTotal" = manualDelayMinutes
            };
            return timeline;
        </cfscript>
    </cffunction>

    <cffunction name="canAttemptScheduledRouteTimeline" access="private" returntype="boolean" output="false">
        <cfargument name="qPlan" type="query" required="true">
        <cfargument name="qProgress" type="query" required="true">
        <cfargument name="currentLeg" type="struct" required="true">
        <cfargument name="canonicalSegments" type="array" required="true">
        <cfargument name="out" type="struct" required="true">
        <cfscript>
            var planStatus = "";
            var currentStatus = "";

            if (
                hasAuthorityWarning(arguments.out, "CANONICAL_EVENT_TABLE_MISSING")
                OR hasAuthorityWarning(arguments.out, "CANONICAL_ACTIVITY_SEGMENT_TABLE_MISSING")
            ) {
                return false;
            }
            if (
                !structKeyExists(arguments.out, "eventLedger")
                OR !structKeyExists(arguments.out.eventLedger, "count")
                OR safeNumber(arguments.out.eventLedger.count) NEQ 0
                OR arrayLen(arguments.canonicalSegments) NEQ 0
            ) {
                return false;
            }
            if (arguments.qPlan.recordCount EQ 0) {
                return false;
            }

            planStatus = uCase(safeString(arguments.qPlan.status[1]));
            if (!listFindNoCase("ACTIVE,SCHEDULED,PLANNED", planStatus)) {
                return false;
            }
            if (!structKeyExists(arguments.currentLeg, "routeLegOrder") OR safeNumber(arguments.currentLeg.routeLegOrder) LTE 0) {
                return false;
            }
            currentStatus = uCase(safeString(arguments.currentLeg.status));
            if (len(currentStatus) AND !listFindNoCase("NOT_STARTED,SCHEDULED,PLANNED", currentStatus)) {
                return false;
            }
            if (
                (structKeyExists(arguments.currentLeg, "startedAtUtc") AND isDate(arguments.currentLeg.startedAtUtc))
                OR (structKeyExists(arguments.currentLeg, "completedAtUtc") AND isDate(arguments.currentLeg.completedAtUtc))
                OR hasStartedOrCompletedRouteProgress(arguments.qProgress)
            ) {
                return false;
            }

            return true;
        </cfscript>
    </cffunction>

    <cffunction name="buildScheduledRouteTimelineProjection" access="private" returntype="struct" output="false">
        <cfargument name="qPlan" type="query" required="true">
        <cfargument name="qLegs" type="query" required="true">
        <cfargument name="qProgress" type="query" required="true">
        <cfargument name="currentLeg" type="struct" required="true">
        <cfargument name="asOfUtc" type="date" required="true">
        <cfargument name="speedKn" type="numeric" required="true">
        <cfargument name="timeline" type="struct" required="true">
        <cfargument name="out" type="struct" required="true">
        <cfargument name="projectionOptions" type="struct" required="true">
        <cfscript>
            var scheduledTimeline = duplicate(arguments.timeline);
            var scheduledDepartureDt = getScheduledDepartureUtc(arguments.qPlan);
            var scheduledDepartureSource = getScheduledDepartureSource(arguments.qPlan);
            var currentLegOrder = (structKeyExists(arguments.currentLeg, "routeLegOrder") ? safeNumber(arguments.currentLeg.routeLegOrder) : 0);
            var i = 0;
            var legOrder = 0;
            var distanceNm = 0;
            var totalNm = 0;
            var distanceMissing = false;
            var priorArrivalDt = "";
            var departureDt = "";
            var arrivalDt = "";
            var departureUtc = "";
            var arrivalUtc = "";
            var departureSource = "";
            var progressRow = {};
            var statusVal = "";
            var isCurrent = false;
            var finalArrivalUtc = "";
            var legLockModel = {};
            var lockTimeMinutes = 0;
            var legDurationSeconds = 0;
            var durationAuthority = "";
            var manualDelayMinutes = max(0, safeNumber(arguments.qPlan.manual_delay_minutes_total[1]));

            scheduledTimeline.authority = "scheduled_projection";
            scheduledTimeline.available = false;
            scheduledTimeline.generatedAtUtc = formatUtc(arguments.asOfUtc);
            scheduledTimeline.currentLegOrder = currentLegOrder;
            scheduledTimeline.paused = false;
            scheduledTimeline.expectedResumeAtUtc = "";
            scheduledTimeline.effectiveSpeedKn = arguments.speedKn;
            scheduledTimeline.manualDelayMinutesTotal = manualDelayMinutes;
            scheduledTimeline.usesLatestCheckinAsAnchor = false;
            scheduledTimeline.summary = {
                "totalNm" = 0,
                "completedNm" = 0,
                "remainingNm" = 0,
                "percentComplete" = 0,
                "finalArrivalUtc" = ""
            };
            scheduledTimeline.legs = [];
            scheduledTimeline.warnings = [];

            if (arguments.qLegs.recordCount EQ 0) {
                addRouteTimelineWarning(scheduledTimeline, arguments.out, "ROUTE_TIMELINE_ROUTE_LEGS_MISSING", "Route timeline cannot be projected because route legs were not found.");
                scheduledTimeline.reason = "Route legs were not found.";
                return scheduledTimeline;
            }
            if (currentLegOrder LTE 0) {
                addRouteTimelineWarning(scheduledTimeline, arguments.out, "ROUTE_TIMELINE_CURRENT_LEG_MISSING", "Route timeline cannot be projected because current leg authority is missing.");
                scheduledTimeline.reason = "Current leg authority is missing.";
                return scheduledTimeline;
            }
            if (arguments.speedKn LTE 0) {
                addRouteTimelineWarning(scheduledTimeline, arguments.out, "ROUTE_TIMELINE_SPEED_MISSING", "Route timeline cannot be projected because effective speed is missing.");
                scheduledTimeline.reason = "Effective speed is missing.";
                return scheduledTimeline;
            }
            if (!isDate(scheduledDepartureDt)) {
                addRouteTimelineWarning(scheduledTimeline, arguments.out, "ROUTE_TIMELINE_SCHEDULE_MISSING", "Route timeline cannot be projected because scheduled departure data is missing.");
                scheduledTimeline.reason = "Scheduled departure data is missing.";
                return scheduledTimeline;
            }

            for (i = 1; i LTE arguments.qLegs.recordCount; i++) {
                distanceNm = safeNumber(arguments.qLegs.base_dist_nm[i]);
                totalNm += distanceNm;
                if (distanceNm LTE 0) {
                    distanceMissing = true;
                }
            }
            if (distanceMissing OR totalNm LTE 0) {
                addRouteTimelineWarning(scheduledTimeline, arguments.out, "ROUTE_TIMELINE_DISTANCE_MISSING", "Route timeline cannot be projected because one or more route leg distances are missing.");
                scheduledTimeline.reason = "Route leg distance is missing.";
                return scheduledTimeline;
            }

            priorArrivalDt = scheduledDepartureDt;
            if (manualDelayMinutes GT 0) {
                priorArrivalDt = dateAdd("n", manualDelayMinutes, priorArrivalDt);
            }
            for (i = 1; i LTE arguments.qLegs.recordCount; i++) {
                legOrder = safeNumber(arguments.qLegs.leg_order[i]);
                distanceNm = safeNumber(arguments.qLegs.base_dist_nm[i]);
                progressRow = findProgressForLeg(arguments.qProgress, legOrder);
                statusVal = safeString(progressRow.status);
                isCurrent = (legOrder EQ currentLegOrder);
                departureDt = priorArrivalDt;
                legLockModel = buildLegLockModel(
                    safeString(arguments.qLegs.lock_route_code[i]),
                    safeNumber(arguments.qLegs.lock_leg_order[i]),
                    safeNumber(arguments.qLegs.lock_count[i])
                );
                lockTimeMinutes = (arguments.projectionOptions.includeOperationalLockTime ? getOperationalLockTimeMinutes(legLockModel) : 0);
                legDurationSeconds = round((distanceNm / arguments.speedKn) * 3600) + round(lockTimeMinutes * 60);
                durationAuthority = (lockTimeMinutes GT 0 ? "scheduled_projection_plus_operational_lock_time" : "scheduled_projection");
                arrivalDt = dateAdd("s", legDurationSeconds, departureDt);
                departureUtc = formatUtc(departureDt);
                arrivalUtc = formatUtc(arrivalDt);
                departureSource = (i EQ 1 ? scheduledDepartureSource : "previous_leg_arrival_projection");
                priorArrivalDt = arrivalDt;
                finalArrivalUtc = arrivalUtc;

                arrayAppend(scheduledTimeline.legs, {
                    "routeLegOrder" = legOrder,
                    "fromName" = safeString(arguments.qLegs.start_name[i]),
                    "toName" = safeString(arguments.qLegs.end_name[i]),
                    "status" = (len(statusVal) ? statusVal : "NOT_STARTED"),
                    "state" = (isCurrent ? "current" : "future"),
                    "isCurrent" = isCurrent,
                    "isCompleted" = false,
                    "isFuture" = !isCurrent,
                    "distanceNm" = roundTo1(distanceNm),
                    "effectiveSpeedKn" = arguments.speedKn,
                    "startedAtUtc" = "",
                    "completedAtUtc" = "",
                    "departureUtc" = departureUtc,
                    "arrivalUtc" = arrivalUtc,
                    "etaUtc" = arrivalUtc,
                    "completedNm" = 0,
                    "remainingNm" = roundTo1(distanceNm),
                    "percentComplete" = 0,
                    "estimatedDurationSeconds" = legDurationSeconds,
                    "estimatedDurationLabel" = formatDurationSecondsLabel(legDurationSeconds),
                    "remainingDurationSeconds" = legDurationSeconds,
                    "remainingDurationLabel" = formatDurationSecondsLabel(legDurationSeconds),
                    "durationAuthority" = durationAuthority,
                    "paused" = false,
                    "expectedResumeAtUtc" = "",
                    "departureSource" = departureSource,
                    "arrivalSource" = (lockTimeMinutes GT 0 ? "scheduled_projection_plus_operational_lock_time" : "scheduled_projection"),
                    "authority" = "scheduled_projection",
                    "usesLatestCheckinAsAnchor" = false,
                    "lockSummary" = legLockModel.lockSummary,
                    "locks" = legLockModel.locks,
                    "warnings" = []
                });
            }

            scheduledTimeline.available = true;
            scheduledTimeline.summary = {
                "totalNm" = roundTo1(totalNm),
                "completedNm" = 0,
                "remainingNm" = roundTo1(totalNm),
                "percentComplete" = 0,
                "finalArrivalUtc" = finalArrivalUtc,
                "effectiveSpeedKn" = arguments.speedKn,
                "manualDelayMinutesTotal" = manualDelayMinutes
            };
            return scheduledTimeline;
        </cfscript>
    </cffunction>

    <cffunction name="buildBugExplanation8073" access="private" returntype="struct" output="false">
        <cfargument name="projection" type="struct" required="true">
        <cfargument name="qPlan" type="query" required="true">
        <cfscript>
            return {
                "summary" = "Legacy Follow calculations can explain the reset because latest check-in is later than the first post-secure resume.",
                "latestCheckinAtUtc" = formatUtc(arguments.qPlan.checkedInAt[1]),
                "firstPostSecureResumeAtUtc" = findFirstDiagnosticResume(arguments.projection.diagnostics.legacyInferredSegments),
                "latestCheckinIsDisplayOnly" = true,
                "canonicalTablesBackfilled" = false
            };
        </cfscript>
    </cffunction>

    <cffunction name="getLocalDayBounds" access="private" returntype="struct" output="false">
        <cfargument name="asOfUtc" type="date" required="true">
        <cfargument name="timezone" type="string" required="true">
        <cfscript>
            var qBounds = queryExecute("
                SELECT
                  DATE(CONVERT_TZ(:asOfUtc, 'UTC', :tz)) AS local_date,
                  CONVERT_TZ(DATE(CONVERT_TZ(:asOfUtc, 'UTC', :tz)), :tz, 'UTC') AS day_start_utc,
                  CONVERT_TZ(DATE_ADD(DATE(CONVERT_TZ(:asOfUtc, 'UTC', :tz)), INTERVAL 1 DAY), :tz, 'UTC') AS day_end_utc
            ", {
                asOfUtc = { value = arguments.asOfUtc, cfsqltype = "cf_sql_timestamp" },
                tz = { value = arguments.timezone, cfsqltype = "cf_sql_varchar" }
            }, { datasource = variables.datasource });

            if (qBounds.recordCount GT 0 AND isDate(qBounds.day_start_utc[1]) AND isDate(qBounds.day_end_utc[1])) {
                return {
                    "localDate" = dateFormat(qBounds.local_date[1], "yyyy-mm-dd"),
                    "startUtc" = qBounds.day_start_utc[1],
                    "endUtc" = qBounds.day_end_utc[1]
                };
            }

            return {
                "localDate" = dateFormat(arguments.asOfUtc, "yyyy-mm-dd"),
                "startUtc" = createDateTime(year(arguments.asOfUtc), month(arguments.asOfUtc), day(arguments.asOfUtc), 0, 0, 0),
                "endUtc" = dateAdd("d", 1, createDateTime(year(arguments.asOfUtc), month(arguments.asOfUtc), day(arguments.asOfUtc), 0, 0, 0))
            };
        </cfscript>
    </cffunction>

    <cffunction name="sumUnderwayOverlapSeconds" access="private" returntype="numeric" output="false">
        <cfargument name="segments" type="array" required="true">
        <cfargument name="windowStart" type="date" required="true">
        <cfargument name="windowEnd" type="date" required="true">
        <cfscript>
            var total = 0;
            var i = 0;
            var seg = {};
            var segStart = "";
            var segEnd = "";
            var overlapStart = "";
            var overlapEnd = "";
            for (i = 1; i LTE arrayLen(arguments.segments); i++) {
                seg = arguments.segments[i];
                if (!structKeyExists(seg, "segmentType") OR seg.segmentType NEQ "UNDERWAY") {
                    continue;
                }
                if (!structKeyExists(seg, "startedAtUtc") OR !isDate(seg.startedAtUtc)) {
                    continue;
                }
                segStart = parseIsoUtc(seg.startedAtUtc);
                segEnd = (structKeyExists(seg, "endedAtUtc") AND isDate(seg.endedAtUtc) ? parseIsoUtc(seg.endedAtUtc) : arguments.windowEnd);
                overlapStart = maxDate(segStart, arguments.windowStart);
                overlapEnd = minDate(segEnd, arguments.windowEnd);
                if (dateCompare(overlapEnd, overlapStart, "s") GT 0) {
                    total += dateDiff("s", overlapStart, overlapEnd);
                }
            }
            return total;
        </cfscript>
    </cffunction>

    <cffunction name="getOpenSegments" access="private" returntype="array" output="false">
        <cfargument name="segments" type="array" required="true">
        <cfscript>
            var arr = [];
            var i = 0;
            for (i = 1; i LTE arrayLen(arguments.segments); i++) {
                if (!structKeyExists(arguments.segments[i], "endedAtUtc") OR !isDate(arguments.segments[i].endedAtUtc)) {
                    arrayAppend(arr, arguments.segments[i]);
                }
            }
            return arr;
        </cfscript>
    </cffunction>

    <cffunction name="getCurrentSegmentType" access="private" returntype="string" output="false">
        <cfargument name="segments" type="array" required="true">
        <cfargument name="asOfUtc" type="date" required="true">
        <cfscript>
            var openSegments = getOpenSegments(arguments.segments);
            if (arrayLen(openSegments)) {
                return safeString(openSegments[arrayLen(openSegments)].segmentType);
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

    <cffunction name="findProgressForLeg" access="private" returntype="struct" output="false">
        <cfargument name="qProgress" type="query" required="true">
        <cfargument name="legOrder" type="numeric" required="true">
        <cfscript>
            var i = 0;
            for (i = 1; i LTE arguments.qProgress.recordCount; i++) {
                if (safeNumber(arguments.qProgress.leg_order[i]) EQ safeNumber(arguments.legOrder)) {
                    return {
                        "found" = true,
                        "status" = safeString(arguments.qProgress.status_val[i]),
                        "legStartedAt" = arguments.qProgress.leg_started_at[i],
                        "completedAt" = arguments.qProgress.completed_at[i]
                    };
                }
            }
            return {
                "found" = false,
                "status" = "NOT_STARTED",
                "legStartedAt" = "",
                "completedAt" = ""
            };
        </cfscript>
    </cffunction>

    <cffunction name="countActiveProgressRows" access="private" returntype="numeric" output="false">
        <cfargument name="qProgress" type="query" required="true">
        <cfscript>
            var i = 0;
            var count = 0;
            var statusVal = "";
            for (i = 1; i LTE arguments.qProgress.recordCount; i++) {
                statusVal = safeString(arguments.qProgress.status_val[i]);
                if (!isDate(arguments.qProgress.completed_at[i]) AND (isDate(arguments.qProgress.leg_started_at[i]) OR listFindNoCase("STARTED,IN_PROGRESS", statusVal))) {
                    count++;
                }
            }
            return count;
        </cfscript>
    </cffunction>

    <cffunction name="hasStartedOrCompletedRouteProgress" access="private" returntype="boolean" output="false">
        <cfargument name="qProgress" type="query" required="true">
        <cfscript>
            var i = 0;
            var statusVal = "";
            for (i = 1; i LTE arguments.qProgress.recordCount; i++) {
                statusVal = safeString(arguments.qProgress.status_val[i]);
                if (
                    isDate(arguments.qProgress.leg_started_at[i])
                    OR isDate(arguments.qProgress.completed_at[i])
                    OR (len(statusVal) AND !listFindNoCase("NOT_STARTED", statusVal))
                ) {
                    return true;
                }
            }
            return false;
        </cfscript>
    </cffunction>

    <cffunction name="getScheduledDepartureUtc" access="private" returntype="any" output="false">
        <cfargument name="qPlan" type="query" required="true">
        <cfscript>
            if (arguments.qPlan.recordCount EQ 0) {
                return "";
            }
            if (isDate(arguments.qPlan.departureTimeUTC[1])) {
                return arguments.qPlan.departureTimeUTC[1];
            }
            if (isDate(arguments.qPlan.departureTime[1])) {
                return arguments.qPlan.departureTime[1];
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="getScheduledDepartureSource" access="private" returntype="string" output="false">
        <cfargument name="qPlan" type="query" required="true">
        <cfscript>
            if (arguments.qPlan.recordCount EQ 0) {
                return "";
            }
            if (isDate(arguments.qPlan.departureTimeUTC[1])) {
                return "floatplans.departureTimeUTC";
            }
            if (isDate(arguments.qPlan.departureTime[1])) {
                return "floatplans.departureTime";
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="hasAuthorityWarning" access="private" returntype="boolean" output="false">
        <cfargument name="out" type="struct" required="true">
        <cfargument name="code" type="string" required="true">
        <cfscript>
            var i = 0;
            var warningCode = "";
            if (!structKeyExists(arguments.out, "authorityWarnings") OR !isArray(arguments.out.authorityWarnings)) {
                return false;
            }
            for (i = 1; i LTE arrayLen(arguments.out.authorityWarnings); i++) {
                if (!isStruct(arguments.out.authorityWarnings[i]) OR !structKeyExists(arguments.out.authorityWarnings[i], "code")) {
                    continue;
                }
                warningCode = safeString(arguments.out.authorityWarnings[i].code);
                if (compareNoCase(warningCode, arguments.code) EQ 0) {
                    return true;
                }
            }
            return false;
        </cfscript>
    </cffunction>

    <cffunction name="addRouteTimelineWarning" access="private" returntype="void" output="false">
        <cfargument name="timeline" type="struct" required="true">
        <cfargument name="out" type="struct" required="true">
        <cfargument name="code" type="string" required="true">
        <cfargument name="message" type="string" required="true">
        <cfscript>
            if (!structKeyExists(arguments.timeline, "warnings")) {
                arguments.timeline.warnings = [];
            }
            arrayAppend(arguments.timeline.warnings, {
                "code" = arguments.code,
                "message" = arguments.message
            });
            addWarning(arguments.out, arguments.code, arguments.message);
        </cfscript>
    </cffunction>

    <cffunction name="buildLegLockModel" access="private" returntype="struct" output="false">
        <cfargument name="lockRouteCode" type="string" required="true">
        <cfargument name="lockLegOrder" type="numeric" required="true">
        <cfargument name="storedLockCount" type="numeric" required="true">
        <cfscript>
            var out = buildEmptyLegLockModel(arguments.storedLockCount, "route_instance_legs.lock_count");
            var qLocks = queryNew("");
            var hasDelayModel = false;
            var i = 0;
            var lockRow = {};
            var totalBaseCycle = 0;
            var totalBestDelay = 0;
            var totalTypicalDelay = 0;
            var totalWorstDelay = 0;

            if (arguments.storedLockCount LTE 0) {
                out.lockSummary.source = "route_instance_legs.lock_count";
                return out;
            }
            if (!len(trim(arguments.lockRouteCode)) OR arguments.lockLegOrder LTE 0) {
                out.lockSummary.source = "route_instance_legs.lock_count";
                out.lockSummary.delayLabel = "Lock detail mapping unavailable";
                return out;
            }
            if (!tableExists("route_leg_locks") OR !tableExists("canonical_locks")) {
                out.lockSummary.source = "lock_tables_unavailable";
                out.lockSummary.delayLabel = "Lock detail tables unavailable";
                return out;
            }

            hasDelayModel = tableExists("lock_delay_model");
            qLocks = queryExecute(
                "SELECT
                    rll.seq,
                    rll.lock_code,
                    COALESCE(cl.name, rll.lock_code) AS lock_name,
                    COALESCE(cl.waterway, '') AS waterway,
                    COALESCE(cl.state, '') AS state_code,
                    COALESCE(cl.country, '') AS country_code,
                    cl.lat,
                    cl.lng,
                    COALESCE(cl.lock_type, '') AS lock_type,
                    cl.chamber_length_ft,
                    cl.chamber_width_ft,
                    COALESCE(cl.agency, '') AS agency,
                    COALESCE(cl.source, '') AS source_url,
                    COALESCE(cl.notes, '') AS lock_notes,"
                    & (hasDelayModel ? "
                    ldm.base_cycle_min,
                    ldm.best_wait_min,
                    ldm.typical_wait_min,
                    ldm.worst_wait_min,
                    COALESCE(ldm.notes, '') AS delay_notes" : "
                    NULL AS base_cycle_min,
                    NULL AS best_wait_min,
                    NULL AS typical_wait_min,
                    NULL AS worst_wait_min,
                    '' AS delay_notes")
                    & "
                 FROM route_leg_locks rll
                 LEFT JOIN canonical_locks cl
                    ON cl.lock_code = rll.lock_code"
                    & (hasDelayModel ? "
                 LEFT JOIN lock_delay_model ldm
                    ON ldm.lock_code = rll.lock_code" : "")
                    & "
                 WHERE rll.route_code COLLATE utf8mb4_unicode_ci = :routeCode
                   AND rll.leg = :legOrder
                 ORDER BY rll.seq ASC, rll.lock_code ASC",
                {
                    routeCode = { value = trim(arguments.lockRouteCode), cfsqltype = "cf_sql_varchar" },
                    legOrder = { value = arguments.lockLegOrder, cfsqltype = "cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );

            for (i = 1; i LTE qLocks.recordCount; i++) {
                lockRow = {
                    "sequence" = (isNull(qLocks.seq[i]) ? i : val(qLocks.seq[i])),
                    "lockCode" = safeString(qLocks.lock_code[i]),
                    "name" = safeString(qLocks.lock_name[i]),
                    "waterway" = safeString(qLocks.waterway[i]),
                    "state" = safeString(qLocks.state_code[i]),
                    "country" = safeString(qLocks.country_code[i]),
                    "lockType" = safeString(qLocks.lock_type[i]),
                    "chamberLengthFt" = (isNull(qLocks.chamber_length_ft[i]) ? 0 : val(qLocks.chamber_length_ft[i])),
                    "chamberWidthFt" = (isNull(qLocks.chamber_width_ft[i]) ? 0 : val(qLocks.chamber_width_ft[i])),
                    "latitude" = (isNull(qLocks.lat[i]) ? javacast("null", "") : val(qLocks.lat[i])),
                    "longitude" = (isNull(qLocks.lng[i]) ? javacast("null", "") : val(qLocks.lng[i])),
                    "agency" = safeString(qLocks.agency[i]),
                    "baseCycleMinutes" = (isNull(qLocks.base_cycle_min[i]) ? 0 : val(qLocks.base_cycle_min[i])),
                    "bestDelayMinutes" = (isNull(qLocks.best_wait_min[i]) ? 0 : val(qLocks.best_wait_min[i])),
                    "typicalDelayMinutes" = (isNull(qLocks.typical_wait_min[i]) ? 0 : val(qLocks.typical_wait_min[i])),
                    "worstDelayMinutes" = (isNull(qLocks.worst_wait_min[i]) ? 0 : val(qLocks.worst_wait_min[i])),
                    "delayNotes" = safeString(qLocks.delay_notes[i]),
                    "notes" = safeString(qLocks.lock_notes[i]),
                    "source" = safeString(qLocks.source_url[i])
                };
                arrayAppend(out.locks, lockRow);
                totalBaseCycle += val(lockRow.baseCycleMinutes);
                totalBestDelay += val(lockRow.bestDelayMinutes);
                totalTypicalDelay += val(lockRow.typicalDelayMinutes);
                totalWorstDelay += val(lockRow.worstDelayMinutes);
            }

            if (arrayLen(out.locks) GT 0) {
                out.lockSummary.hasLocks = true;
                out.lockSummary.lockCount = arrayLen(out.locks);
                out.lockSummary.baseCycleMinutes = totalBaseCycle;
                out.lockSummary.bestDelayMinutes = totalBestDelay;
                out.lockSummary.typicalDelayMinutes = totalTypicalDelay;
                out.lockSummary.worstDelayMinutes = totalWorstDelay;
                out.lockSummary.operationalLockTimeMinutes = totalBaseCycle + totalTypicalDelay;
                out.lockSummary.delayLabel = buildLockDelayLabel(totalBestDelay, totalTypicalDelay, totalWorstDelay);
                out.lockSummary.source = "route_leg_locks";
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="buildEmptyLegLockModel" access="private" returntype="struct" output="false">
        <cfargument name="storedLockCount" type="numeric" required="false" default="0">
        <cfargument name="source" type="string" required="false" default="route_leg_locks">
        <cfscript>
            var lockCount = max(0, val(arguments.storedLockCount));
            return {
                "lockSummary" = {
                    "hasLocks" = (lockCount GT 0),
                    "lockCount" = lockCount,
                    "baseCycleMinutes" = 0,
                    "bestDelayMinutes" = 0,
                    "typicalDelayMinutes" = 0,
                    "worstDelayMinutes" = 0,
                    "operationalLockTimeMinutes" = 0,
                    "delayLabel" = (lockCount GT 0 ? "Delay estimate unavailable" : "No locks mapped"),
                    "source" = arguments.source
                },
                "locks" = []
            };
        </cfscript>
    </cffunction>

    <cffunction name="buildLockDelayLabel" access="private" returntype="string" output="false">
        <cfargument name="bestDelayMinutes" type="numeric" required="true">
        <cfargument name="typicalDelayMinutes" type="numeric" required="true">
        <cfargument name="worstDelayMinutes" type="numeric" required="true">
        <cfscript>
            if (arguments.bestDelayMinutes LTE 0 AND arguments.typicalDelayMinutes LTE 0 AND arguments.worstDelayMinutes LTE 0) {
                return "Delay estimate unavailable";
            }
            return "Best " & numberFormat(arguments.bestDelayMinutes, "0") & " min / Typical " & numberFormat(arguments.typicalDelayMinutes, "0") & " min / Worst " & numberFormat(arguments.worstDelayMinutes, "0") & " min";
        </cfscript>
    </cffunction>

    <cffunction name="getOperationalLockTimeMinutes" access="private" returntype="numeric" output="false">
        <cfargument name="legLockModel" type="struct" required="true">
        <cfscript>
            if (
                !structKeyExists(arguments.legLockModel, "lockSummary")
                OR !isStruct(arguments.legLockModel.lockSummary)
                OR !structKeyExists(arguments.legLockModel.lockSummary, "operationalLockTimeMinutes")
            ) {
                return 0;
            }
            return max(0, safeNumber(arguments.legLockModel.lockSummary.operationalLockTimeMinutes));
        </cfscript>
    </cffunction>

    <cffunction name="findLegDetails" access="private" returntype="struct" output="false">
        <cfargument name="qLegs" type="query" required="true">
        <cfargument name="legOrder" type="numeric" required="true">
        <cfscript>
            var i = 0;
            for (i = 1; i LTE arguments.qLegs.recordCount; i++) {
                if (safeNumber(arguments.qLegs.leg_order[i]) EQ safeNumber(arguments.legOrder)) {
                    return {
                        "startName" = safeString(arguments.qLegs.start_name[i]),
                        "endName" = safeString(arguments.qLegs.end_name[i]),
                        "distanceNm" = safeNumber(arguments.qLegs.base_dist_nm[i])
                    };
                }
            }
            return { "startName" = "", "endName" = "", "distanceNm" = 0 };
        </cfscript>
    </cffunction>

    <cffunction name="parseRouteInputs" access="private" returntype="struct" output="false">
        <cfargument name="qRouteInstance" type="query" required="true">
        <cfscript>
            if (arguments.qRouteInstance.recordCount EQ 0 OR isNull(arguments.qRouteInstance.routegen_inputs_json[1])) {
                return {};
            }
            return parseJsonStruct(arguments.qRouteInstance.routegen_inputs_json[1]);
        </cfscript>
    </cffunction>

    <cffunction name="buildPaceMeta" access="private" returntype="struct" output="false">
        <cfargument name="inputs" type="struct" required="true">
        <cfargument name="floatPlanId" type="numeric" required="false" default="0">
        <cfscript>
            return createActiveTripPaceService().buildPaceMeta(arguments.inputs, arguments.floatPlanId);
        </cfscript>
    </cffunction>

    <cffunction name="resolveEffectiveSpeed" access="private" returntype="numeric" output="false">
        <cfargument name="inputs" type="struct" required="true">
        <cfargument name="floatPlanId" type="numeric" required="false" default="0">
        <cfscript>
            return createActiveTripPaceService().resolveEffectiveSpeedKn(arguments.inputs, arguments.floatPlanId);
        </cfscript>
    </cffunction>

    <cffunction name="resolveProgressSpeed" access="private" returntype="numeric" output="false">
        <cfargument name="inputs" type="struct" required="true">
        <cfscript>
            return createActiveTripPaceService().resolveEffectiveSpeedKn(arguments.inputs, 0);
        </cfscript>
    </cffunction>

    <cffunction name="createActiveTripPaceService" access="private" returntype="any" output="false">
        <cfscript>
            try {
                return createObject("component", "fpw.api.v1.ActiveTripPaceService").init(variables.datasource);
            } catch (any pacePathErr) {
                return createObject("component", "api.v1.ActiveTripPaceService").init(variables.datasource);
            }
        </cfscript>
    </cffunction>

    <cffunction name="tableExists" access="private" returntype="boolean" output="false">
        <cfargument name="tableName" type="string" required="true">
        <cfscript>
            var q = queryExecute("
                SELECT table_name
                FROM information_schema.tables
                WHERE table_schema = DATABASE()
                  AND table_name = :tableName
                LIMIT 1
            ", {
                tableName = { value = arguments.tableName, cfsqltype = "cf_sql_varchar" }
            }, { datasource = variables.datasource });
            return q.recordCount GT 0;
        </cfscript>
    </cffunction>

    <cffunction name="resolveDepartureTimezone" access="private" returntype="string" output="false">
        <cfargument name="qPlan" type="query" required="true">
        <cfscript>
            var tz = safeString(arguments.qPlan.departureTZ[1]);
            if (!len(tz)) {
                tz = safeString(arguments.qPlan.departTimezone[1]);
            }
            if (!len(tz) OR uCase(tz) EQ "UTC") {
                tz = "America/New_York";
            }
            return tz;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeAsOf" access="private" returntype="date" output="false">
        <cfargument name="asOfUtc" type="any" required="false" default="">
        <cfscript>
            if (isDate(arguments.asOfUtc)) {
                return arguments.asOfUtc;
            }
            return now();
        </cfscript>
    </cffunction>

    <cffunction name="parseJsonStruct" access="private" returntype="struct" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            var parsed = {};
            if (isNull(arguments.value) OR !len(trim(toString(arguments.value)))) {
                return {};
            }
            try {
                parsed = deserializeJSON(toString(arguments.value));
                if (isStruct(parsed)) {
                    return parsed;
                }
            } catch (any parseErr) {
                return {};
            }
            return {};
        </cfscript>
    </cffunction>

    <cffunction name="formatUtc" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            if (!isDate(arguments.value)) {
                return "";
            }
            return dateTimeFormat(arguments.value, "yyyy-mm-dd'T'HH:nn:ss'Z'");
        </cfscript>
    </cffunction>

    <cffunction name="parseIsoUtc" access="private" returntype="date" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            var s = trim(toString(arguments.value));
            if (isDate(arguments.value)) {
                return arguments.value;
            }
            s = replace(s, "T", " ", "one");
            s = replace(s, "Z", "", "one");
            if (isDate(s)) {
                return parseDateTime(s);
            }
            return now();
        </cfscript>
    </cffunction>

    <cffunction name="safeString" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            if (isNull(arguments.value)) {
                return "";
            }
            return trim(toString(arguments.value));
        </cfscript>
    </cffunction>

    <cffunction name="safeNumber" access="private" returntype="numeric" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            if (isNull(arguments.value) OR !isNumeric(arguments.value)) {
                return 0;
            }
            return val(arguments.value);
        </cfscript>
    </cffunction>

    <cffunction name="formatDurationSecondsLabel" access="private" returntype="string" output="false">
        <cfargument name="seconds" type="numeric" required="true">
        <cfscript>
            var totalMinutes = max(0, round(arguments.seconds / 60));
            var hours = int(totalMinutes / 60);
            var minutes = totalMinutes - (hours * 60);

            if (hours LTE 0) {
                return numberFormat(minutes, "0") & " min";
            }
            if (minutes LTE 0) {
                return numberFormat(hours, "0") & " hr";
            }
            return numberFormat(hours, "0") & " hr " & numberFormat(minutes, "0") & " min";
        </cfscript>
    </cffunction>

    <cffunction name="addWarning" access="private" returntype="void" output="false">
        <cfargument name="out" type="struct" required="true">
        <cfargument name="code" type="string" required="true">
        <cfargument name="message" type="string" required="true">
        <cfscript>
            arrayAppend(arguments.out.authorityWarnings, {
                "code" = arguments.code,
                "message" = arguments.message
            });
        </cfscript>
    </cffunction>

    <cffunction name="maxDate" access="private" returntype="date" output="false">
        <cfargument name="a" type="date" required="true">
        <cfargument name="b" type="date" required="true">
        <cfscript>
            return (dateCompare(arguments.a, arguments.b, "s") GTE 0 ? arguments.a : arguments.b);
        </cfscript>
    </cffunction>

    <cffunction name="minDate" access="private" returntype="date" output="false">
        <cfargument name="a" type="date" required="true">
        <cfargument name="b" type="date" required="true">
        <cfscript>
            return (dateCompare(arguments.a, arguments.b, "s") LTE 0 ? arguments.a : arguments.b);
        </cfscript>
    </cffunction>

    <cffunction name="roundTo1" access="private" returntype="numeric" output="false">
        <cfargument name="value" type="numeric" required="true">
        <cfscript>
            return round(arguments.value * 10) / 10;
        </cfscript>
    </cffunction>

    <cffunction name="findFirstDiagnosticResume" access="private" returntype="string" output="false">
        <cfargument name="segments" type="array" required="true">
        <cfscript>
            var i = 0;
            for (i = 1; i LTE arrayLen(arguments.segments); i++) {
                if (
                    arguments.segments[i].segmentType EQ "PAUSED_SECURE_FOR_NIGHT"
                    AND structKeyExists(arguments.segments[i], "actualResumeAtUtc")
                    AND len(arguments.segments[i].actualResumeAtUtc)
                ) {
                    return arguments.segments[i].actualResumeAtUtc;
                }
            }
            return "";
        </cfscript>
    </cffunction>

</cfcomponent>
