<cfcomponent output="false">
    <!--- Shared read-only template/lock loader. Member ownership stays in routeBuilder. No methods are remote. --->
    <cfset variables.datasource = "fpw">
    <cffunction name="init" access="public" returntype="any" output="false">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
            return this;
        </cfscript>
    </cffunction>

    <cffunction name="loadMainLegs" access="public" returntype="array" output="false">
        <cfargument name="templateRouteId" type="numeric" required="true">
        <cfargument name="direction" type="string" required="false" default="CCW">
        <cfscript>
            var q = queryNew("");
            var hasRouteLegLocks = routegenHasRouteLegLocksTable();
            var hasDelayModel = routegenHasLockDelayModelTable();
            var lockExpr = "COALESCE(sl.lock_count, 0)";
            var lockTimeExpr = "0";
            var lockJoinSql = "";
            var sqlMainLegs = "";

            if (hasRouteLegLocks) {
                lockExpr = "COALESCE(rll.lock_count, sl.lock_count, 0)";
                if (hasDelayModel) {
                    lockTimeExpr = "COALESCE(rll.lock_time_min_total, 0)";
                    lockJoinSql =
                        " LEFT JOIN (
                            SELECT
                                rll.route_code,
                                rll.leg,
                                COUNT(*) AS lock_count,
                                COALESCE(SUM(COALESCE(ldm.base_cycle_min, 0) + COALESCE(ldm.typical_wait_min, 0)), 0) AS lock_time_min_total
                            FROM route_leg_locks rll
                            LEFT JOIN lock_delay_model ldm ON ldm.lock_code = rll.lock_code
                            GROUP BY rll.route_code, rll.leg
                          ) rll
                            ON rll.route_code COLLATE utf8mb4_unicode_ci = rt.short_code
                           AND rll.leg = rts.order_index";
                } else {
                    lockJoinSql =
                        " LEFT JOIN (
                            SELECT route_code, leg, COUNT(*) AS lock_count
                            FROM route_leg_locks
                            GROUP BY route_code, leg
                          ) rll
                            ON rll.route_code COLLATE utf8mb4_unicode_ci = rt.short_code
                           AND rll.leg = rts.order_index";
                }
            }

            sqlMainLegs =
                "SELECT
                    rts.order_index AS template_order,
                    sl.id AS segment_id,
                    p1.id AS start_port_id,
                    COALESCE(NULLIF(TRIM(p1.name), ''), TRIM(sl.start_port_name), '') AS start_port,
                    p1.lat AS start_lat,
                    p1.lng AS start_lng,
                    p2.id AS end_port_id,
                    COALESCE(NULLIF(TRIM(p2.name), ''), TRIM(sl.end_port_name), '') AS end_port,
                    p2.lat AS end_lat,
                    p2.lng AS end_lng,
                    sl.dist_nm,
                    " & lockExpr & " AS lock_count,
                    " & lockTimeExpr & " AS lock_time_min_total,
                    sl.is_offshore,
                    sl.is_icw,
                    sl.notes
                 FROM route_template_segments rts
                 INNER JOIN loop_routes rt ON rt.id = rts.route_id
                 INNER JOIN segment_library sl ON sl.id = rts.segment_id
                 LEFT JOIN ports p1 ON p1.id = sl.start_port_id
                 LEFT JOIN ports p2 ON p2.id = sl.end_port_id"
                & lockJoinSql
                & "
                 WHERE rts.route_id = :rid
                 ORDER BY rts.order_index ASC, rts.id ASC";

            q = queryExecute(
                sqlMainLegs,
                {
                    rid = { value=arguments.templateRouteId, cfsqltype="cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );

            var directionVal = normalizeDirection(arguments.direction);
            var legs = [];
            var i = 0;
            var srcIdx = 0;
            var startName = "";
            var endName = "";
            var notesVal = "";

            for (i = 1; i LTE q.recordCount; i++) {
                srcIdx = (directionVal EQ "CW" ? (q.recordCount - i + 1) : i);
                startName = trim(toString(directionVal EQ "CW" ? q.end_port[srcIdx] : q.start_port[srcIdx]));
                endName = trim(toString(directionVal EQ "CW" ? q.start_port[srcIdx] : q.end_port[srcIdx]));
                if (!len(startName)) startName = "Unknown Start";
                if (!len(endName)) endName = "Unknown End";
                notesVal = (isNull(q.notes[srcIdx]) ? "" : trim(toString(q.notes[srcIdx])));

                arrayAppend(legs, {
                    "ORDER_INDEX"=arrayLen(legs) + 1,
                    "SEGMENT_ID"=val(q.segment_id[srcIdx]),
                    "START_PORT_ID"=(directionVal EQ "CW" ? (isNull(q.end_port_id[srcIdx]) ? 0 : val(q.end_port_id[srcIdx])) : (isNull(q.start_port_id[srcIdx]) ? 0 : val(q.start_port_id[srcIdx]))),
                    "END_PORT_ID"=(directionVal EQ "CW" ? (isNull(q.start_port_id[srcIdx]) ? 0 : val(q.start_port_id[srcIdx])) : (isNull(q.end_port_id[srcIdx]) ? 0 : val(q.end_port_id[srcIdx]))),
                    "START_NAME"=startName,
                    "END_NAME"=endName,
                    "START_LAT"=(directionVal EQ "CW" ? (isNull(q.end_lat[srcIdx]) ? "" : q.end_lat[srcIdx]) : (isNull(q.start_lat[srcIdx]) ? "" : q.start_lat[srcIdx])),
                    "START_LNG"=(directionVal EQ "CW" ? (isNull(q.end_lng[srcIdx]) ? "" : q.end_lng[srcIdx]) : (isNull(q.start_lng[srcIdx]) ? "" : q.start_lng[srcIdx])),
                    "END_LAT"=(directionVal EQ "CW" ? (isNull(q.start_lat[srcIdx]) ? "" : q.start_lat[srcIdx]) : (isNull(q.end_lat[srcIdx]) ? "" : q.end_lat[srcIdx])),
                    "END_LNG"=(directionVal EQ "CW" ? (isNull(q.start_lng[srcIdx]) ? "" : q.start_lng[srcIdx]) : (isNull(q.end_lng[srcIdx]) ? "" : q.end_lng[srcIdx])),
                    "DIST_NM"=(isNull(q.dist_nm[srcIdx]) ? 0 : val(q.dist_nm[srcIdx])),
                    "LOCK_COUNT"=(isNull(q.lock_count[srcIdx]) ? 0 : val(q.lock_count[srcIdx])),
                    "LOCK_TIME_MIN_TOTAL"=(isNull(q.lock_time_min_total[srcIdx]) ? 0 : val(q.lock_time_min_total[srcIdx])),
                    "IS_OFFSHORE"=(q.is_offshore[srcIdx] EQ 1),
                    "IS_ICW"=(q.is_icw[srcIdx] EQ 1),
                    "IS_OPTIONAL"=false,
                    "DETOUR_CODE"="",
                    "NOTES"=notesVal
                });
            }
            return legs;
        </cfscript>
    </cffunction>

    <cffunction name="loadLegLocks" access="public" returntype="struct" output="false">
        <cfargument name="templateCode" type="string" required="true">
        <cfargument name="segmentId" type="numeric" required="true">
        <cfargument name="legOrder" type="numeric" required="false" default="0">
        <cfargument name="allowTemplateFallback" type="boolean" required="false" default="true">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unable to load lock details",
                "DATA"={}
            };
            var routeCodeVal = "";
            var templateCodeVal = trim(arguments.templateCode);
            var routeInfo = {};
            var routeLegIdVal = 0;
            var segmentIdVal = val(arguments.segmentId);
            var legOrderVal = val(arguments.legOrder);
            var startNameVal = "";
            var endNameVal = "";
            var qMap = queryNew("");
            var qLocks = queryNew("");
            var qMapSql = "";
            var qMapParams = {};
            var qLocksSql = "";
            var mapShortCodeVal = "";
            var mapRouteCodeVal = "";
            var mapLegOrderVal = 0;
            var totalBaseCycleMin = 0;
            var totalBestWaitMin = 0;
            var totalTypicalWaitMin = 0;
            var totalWorstWaitMin = 0;
            var hasDelayModel = routegenHasLockDelayModelTable();
            var i = 0;
            var lockRow = {};
            var allCanonicalRecords = true;
            var allDelayEstimates = true;

            if (!routegenHasRouteLegLocksTable()) {
                out.MESSAGE = "Lock data unavailable";
                out.ERROR = { "MESSAGE"="route_leg_locks table is missing." };
                return out;
            }
            if (!routegenHasCanonicalLocksTable()) {
                out.MESSAGE = "Lock data unavailable";
                out.ERROR = { "MESSAGE"="canonical_locks table is missing." };
                return out;
            }


            if (segmentIdVal LTE 0) {
                out.MESSAGE = "Segment required";
                out.ERROR = { "MESSAGE"="segment_id is required to resolve lock details." };
                return out;
            }

            qMapSql =
                "SELECT
                    rt.short_code,
                    rt.code,
                    rts.order_index,
                    sl.lock_count AS fallback_lock_count
                 FROM route_template_segments rts
                 INNER JOIN loop_routes rt ON rt.id = rts.route_id
                 INNER JOIN segment_library sl ON sl.id = rts.segment_id
                 WHERE rts.segment_id = :segmentId";
            qMapParams = {
                segmentId = { value=segmentIdVal, cfsqltype="cf_sql_integer" }
            };
            // Public template consumers require this exact template/order; the generator retains its legacy fallback.
            if (!arguments.allowTemplateFallback AND !len(templateCodeVal)) {
                out.MESSAGE = "Template required";
                out.ERROR = { "MESSAGE"="templateCode is required for strict template lock mapping." };
                return out;
            }
            if (!arguments.allowTemplateFallback AND legOrderVal GT 0) {
                qMapSql &= " AND rts.order_index = :templateLegOrder";
                qMapParams.templateLegOrder = { value=legOrderVal, cfsqltype="cf_sql_integer" };
            }
            if (len(templateCodeVal)) {
                qMapSql &= "
                    AND (rt.short_code = :templateCode OR rt.code = :templateCode)";
                qMapParams.templateCode = { value=templateCodeVal, cfsqltype="cf_sql_varchar" };
                qMapSql &= "
                 ORDER BY
                    CASE
                        WHEN rt.short_code = :templateCode THEN 0
                        WHEN rt.code = :templateCode THEN 1
                        ELSE 2
                    END,
                    rts.order_index ASC,
                    rt.id ASC
                 LIMIT 1";
            } else {
                qMapSql &= "
                 ORDER BY rt.is_default DESC, rt.id ASC, rts.order_index ASC
                 LIMIT 1";
            }
            qMap = queryExecute(qMapSql, qMapParams, { datasource = variables.datasource });

            if (qMap.recordCount EQ 0 AND len(templateCodeVal) AND arguments.allowTemplateFallback) {
                qMap = queryExecute(
                    "SELECT
                        rt.short_code,
                        rt.code,
                        rts.order_index,
                        sl.lock_count AS fallback_lock_count
                     FROM route_template_segments rts
                     INNER JOIN loop_routes rt ON rt.id = rts.route_id
                     INNER JOIN segment_library sl ON sl.id = rts.segment_id
                     WHERE rts.segment_id = :segmentId
                     ORDER BY rt.is_default DESC, rt.id ASC, rts.order_index ASC
                     LIMIT 1",
                    {
                        segmentId = { value=segmentIdVal, cfsqltype="cf_sql_integer" }
                    },
                    { datasource = variables.datasource }
                );
            }

            if (qMap.recordCount EQ 0) {
                out.SUCCESS = true;
                out.MESSAGE = "No lock mapping for this leg";
                out.DATA = {
                    "route_code"=(structCount(routeInfo) ? routeInfo.ROUTE_CODE : routeCodeVal),
                    "template_code"=templateCodeVal,
                    "template_route_code"=templateCodeVal,
                    "route_leg_id"=routeLegIdVal,
                    "leg_order"=legOrderVal,
                    "segment_id"=segmentIdVal,
                    "start_name"=startNameVal,
                    "end_name"=endNameVal,
                    "lock_count"=0,
                    "mapping_available"=false,
                    "delay_estimates_available"=false,
                    "mapping_status"="unavailable",
                    "unavailable_reason"="No canonical lock mapping is available for this leg.",
                    "totals"={
                        "base_cycle_min"=0,
                        "best_wait_min"=0,
                        "typical_wait_min"=0,
                        "worst_wait_min"=0
                    },
                    "locks"=[]
                };
                return out;
            }

            mapShortCodeVal = (isNull(qMap.short_code[1]) ? "" : trim(toString(qMap.short_code[1])));
            mapRouteCodeVal = (isNull(qMap.code[1]) ? "" : trim(toString(qMap.code[1])));
            mapLegOrderVal = (isNull(qMap.order_index[1]) ? 0 : val(qMap.order_index[1]));

            qLocksSql =
                "SELECT
                    rll.seq,
                    rll.lock_code,
                    cl.lock_code AS canonical_lock_code,
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
                 LEFT JOIN canonical_locks cl ON cl.lock_code = rll.lock_code"
                    & (hasDelayModel ? "
                 LEFT JOIN lock_delay_model ldm ON ldm.lock_code = rll.lock_code" : "")
                    & "
                 WHERE rll.route_code COLLATE utf8mb4_unicode_ci = :routeShortCode
                   AND rll.leg = :templateLeg
                 ORDER BY rll.seq ASC, rll.lock_code ASC";
            qLocks = queryExecute(
                qLocksSql,
                {
                    routeShortCode = { value=mapShortCodeVal, cfsqltype="cf_sql_varchar" },
                    templateLeg = { value=mapLegOrderVal, cfsqltype="cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );

            out.SUCCESS = true;
            out.MESSAGE = "OK";
            out.DATA = {
                "route_code"=(structCount(routeInfo) ? routeInfo.ROUTE_CODE : routeCodeVal),
                "template_code"=mapShortCodeVal,
                "template_route_code"=mapRouteCodeVal,
                "template_leg_order"=mapLegOrderVal,
                "route_leg_id"=routeLegIdVal,
                "leg_order"=legOrderVal,
                "segment_id"=segmentIdVal,
                "start_name"=startNameVal,
                "end_name"=endNameVal,
                "lock_count"=0,
                "mapping_available"=false,
                "delay_estimates_available"=false,
                "mapping_status"="unavailable",
                "unavailable_reason"="",
                "totals"={
                    "base_cycle_min"=0,
                    "best_wait_min"=0,
                    "typical_wait_min"=0,
                    "worst_wait_min"=0
                },
                "locks"=[]
            };

            for (i = 1; i LTE qLocks.recordCount; i++) {
                lockRow = {
                    "seq"=(isNull(qLocks.seq[i]) ? i : val(qLocks.seq[i])),
                    "lock_code"=(isNull(qLocks.lock_code[i]) ? "" : trim(toString(qLocks.lock_code[i]))),
                    "name"=(isNull(qLocks.lock_name[i]) ? "" : trim(toString(qLocks.lock_name[i]))),
                    "waterway"=(isNull(qLocks.waterway[i]) ? "" : trim(toString(qLocks.waterway[i]))),
                    "state_code"=(isNull(qLocks.state_code[i]) ? "" : trim(toString(qLocks.state_code[i]))),
                    "country_code"=(isNull(qLocks.country_code[i]) ? "" : trim(toString(qLocks.country_code[i]))),
                    "lat"=(isNull(qLocks.lat[i]) ? javacast("null", "") : val(qLocks.lat[i])),
                    "lng"=(isNull(qLocks.lng[i]) ? javacast("null", "") : val(qLocks.lng[i])),
                    "lock_type"=(isNull(qLocks.lock_type[i]) ? "" : trim(toString(qLocks.lock_type[i]))),
                    "chamber_length_ft"=(isNull(qLocks.chamber_length_ft[i]) ? 0 : val(qLocks.chamber_length_ft[i])),
                    "chamber_width_ft"=(isNull(qLocks.chamber_width_ft[i]) ? 0 : val(qLocks.chamber_width_ft[i])),
                    "agency"=(isNull(qLocks.agency[i]) ? "" : trim(toString(qLocks.agency[i]))),
                    "source_url"=(isNull(qLocks.source_url[i]) ? "" : trim(toString(qLocks.source_url[i]))),
                    "lock_notes"=(isNull(qLocks.lock_notes[i]) ? "" : trim(toString(qLocks.lock_notes[i]))),
                    "base_cycle_min"=(isNull(qLocks.base_cycle_min[i]) ? 0 : val(qLocks.base_cycle_min[i])),
                    "best_wait_min"=(isNull(qLocks.best_wait_min[i]) ? 0 : val(qLocks.best_wait_min[i])),
                    "typical_wait_min"=(isNull(qLocks.typical_wait_min[i]) ? 0 : val(qLocks.typical_wait_min[i])),
                    "worst_wait_min"=(isNull(qLocks.worst_wait_min[i]) ? 0 : val(qLocks.worst_wait_min[i])),
                    "delay_notes"=(isNull(qLocks.delay_notes[i]) ? "" : trim(toString(qLocks.delay_notes[i]))),
                    "canonical_record_available"=!isNull(qLocks.canonical_lock_code[i]),
                    "delay_estimate_available"=(!isNull(qLocks.base_cycle_min[i]) AND !isNull(qLocks.best_wait_min[i]) AND !isNull(qLocks.typical_wait_min[i]) AND !isNull(qLocks.worst_wait_min[i]))
                };
                if (!lockRow.canonical_record_available) allCanonicalRecords = false;
                if (!lockRow.delay_estimate_available) allDelayEstimates = false;
                arrayAppend(out.DATA.locks, lockRow);
                totalBaseCycleMin += val(lockRow.base_cycle_min);
                totalBestWaitMin += val(lockRow.best_wait_min);
                totalTypicalWaitMin += val(lockRow.typical_wait_min);
                totalWorstWaitMin += val(lockRow.worst_wait_min);
            }

            out.DATA.lock_count = arrayLen(out.DATA.locks);
            out.DATA.totals = {
                "base_cycle_min"=totalBaseCycleMin,
                "best_wait_min"=totalBestWaitMin,
                "typical_wait_min"=totalTypicalWaitMin,
                "worst_wait_min"=totalWorstWaitMin
            };
            // An empty mapping is only a known zero-lock leg when the template also records zero locks.
            out.DATA.mapping_available = (out.DATA.lock_count GT 0
                ? allCanonicalRecords
                : (!isNull(qMap.fallback_lock_count[1]) AND val(qMap.fallback_lock_count[1]) EQ 0));
            out.DATA.delay_estimates_available = out.DATA.mapping_available
                AND (out.DATA.lock_count EQ 0 OR (hasDelayModel AND allDelayEstimates));
            out.DATA.mapping_status = (!out.DATA.mapping_available ? "unavailable" : (out.DATA.lock_count EQ 0 ? "no_locks" : "mapped"));
            out.DATA.unavailable_reason = (!out.DATA.mapping_available
                ? "Canonical lock mapping is unavailable for this leg."
                : (!out.DATA.delay_estimates_available ? "Lock delay estimates are unavailable or incomplete for this leg." : ""));
            if (!len(out.MESSAGE)) {
                out.MESSAGE = (out.DATA.lock_count GT 0 ? "OK" : "No locks mapped for this leg");
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenHasRouteLegLocksTable" access="private" returntype="boolean" output="false">
        <cfscript>
            var qTbl = queryNew("");
            if (structKeyExists(request, "routegenHasRouteLegLocksTable")) {
                return request.routegenHasRouteLegLocksTable;
            }
            qTbl = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE()
                   AND table_name = 'route_leg_locks'",
                {},
                { datasource = variables.datasource }
            );
            request.routegenHasRouteLegLocksTable = (qTbl.recordCount GT 0 AND val(qTbl.cnt[1]) GT 0);
            return request.routegenHasRouteLegLocksTable;
        </cfscript>
    </cffunction>

    <cffunction name="routegenHasCanonicalLocksTable" access="private" returntype="boolean" output="false">
        <cfscript>
            var qTbl = queryNew("");
            if (structKeyExists(request, "routegenHasCanonicalLocksTable")) {
                return request.routegenHasCanonicalLocksTable;
            }
            qTbl = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE()
                   AND table_name = 'canonical_locks'",
                {},
                { datasource = variables.datasource }
            );
            request.routegenHasCanonicalLocksTable = (qTbl.recordCount GT 0 AND val(qTbl.cnt[1]) GT 0);
            return request.routegenHasCanonicalLocksTable;
        </cfscript>
    </cffunction>

    <cffunction name="routegenHasLockDelayModelTable" access="private" returntype="boolean" output="false">
        <cfscript>
            var qTbl = queryNew("");
            if (structKeyExists(request, "routegenHasLockDelayModelTable")) {
                return request.routegenHasLockDelayModelTable;
            }
            qTbl = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE()
                   AND table_name = 'lock_delay_model'",
                {},
                { datasource = variables.datasource }
            );
            request.routegenHasLockDelayModelTable = (qTbl.recordCount GT 0 AND val(qTbl.cnt[1]) GT 0);
            return request.routegenHasLockDelayModelTable;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeDirection" access="private" returntype="string" output="false">
        <cfargument name="direction" type="any" required="false" default="CCW">
        <cfscript>
            var d = uCase(trim(toString(arguments.direction)));
            if (d EQ "CW") return "CW";
            return "CCW";
        </cfscript>
    </cffunction>
</cfcomponent>
