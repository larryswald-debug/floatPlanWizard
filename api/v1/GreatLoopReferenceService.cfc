component output="false" hint="Read-only Great Loop reference built from the active public route template." {
    public any function init(string datasource="") {
        variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : application.dsn;
        return this;
    }

    private struct function getActiveTemplate() {
        // Same public-template eligibility as routeBuilder.routegenResolveTemplate,
        // restricted to the Great Loop family so a Gulf template cannot replace this page.
        var candidates = queryExecute("
            SELECT id, code, short_code, is_default
            FROM loop_routes lr
            WHERE is_active = 1
              AND short_code NOT LIKE :userPrefix
              AND UPPER(LEFT(code, 11)) = :family
              AND EXISTS (SELECT 1 FROM route_template_segments rts WHERE rts.route_id = lr.id)
            ORDER BY is_default DESC, name ASC, id ASC",
            {userPrefix={value="USER_ROUTE_%",cfsqltype="cf_sql_varchar"},
             family={value="GREAT_LOOP_",cfsqltype="cf_sql_varchar"}},
            {datasource=variables.datasource});
        return selectTemplate(candidates);
    }

    public struct function getModel() {
        var template = getActiveTemplate();
        // Endpoint precedence and stored CCW order match routeBuilder.routegenLoadMainLegs.
        var legs = queryExecute("
            SELECT rts.order_index AS leg_number,
                   COALESCE(NULLIF(TRIM(p1.name), ''), TRIM(sl.start_port_name), '') AS start_name,
                   COALESCE(NULLIF(TRIM(p2.name), ''), TRIM(sl.end_port_name), '') AS end_name,
                   COALESCE(sl.region, '') AS region,
                   COALESCE(sl.lock_count, 0) AS fallback_lock_count,
                   COALESCE(sl.is_offshore, 0) AS is_offshore,
                   COALESCE(sl.is_icw, 0) AS is_icw
            FROM route_template_segments rts
            JOIN segment_library sl ON sl.id = rts.segment_id
            LEFT JOIN ports p1 ON p1.id = sl.start_port_id
            LEFT JOIN ports p2 ON p2.id = sl.end_port_id
            WHERE rts.route_id = :rid
            ORDER BY rts.order_index, rts.id",
            {rid={value=template.id,cfsqltype="cf_sql_integer"}},
            {datasource=variables.datasource});
        var locks = queryExecute("
            SELECT rll.leg AS leg_number, rll.seq, rll.lock_code,
                   COALESCE(NULLIF(TRIM(cl.name), ''), '') AS lock_name,
                   CASE WHEN ldm.base_cycle_min IS NOT NULL AND ldm.typical_wait_min IS NOT NULL
                             AND ldm.base_cycle_min >= 0 AND ldm.typical_wait_min >= 0
                        THEN 1 ELSE 0 END AS has_estimate,
                   COALESCE(ldm.base_cycle_min, 0) + COALESCE(ldm.typical_wait_min, 0) AS time_min
            FROM route_leg_locks rll
            LEFT JOIN canonical_locks cl ON cl.lock_code = rll.lock_code
            LEFT JOIN lock_delay_model ldm ON ldm.lock_code = rll.lock_code
            WHERE rll.route_code COLLATE utf8mb4_unicode_ci = :routeCode
            ORDER BY rll.leg, rll.seq, rll.lock_code",
            {routeCode={value=template.short_code,cfsqltype="cf_sql_varchar"}},
            {datasource=variables.datasource});
        return buildModel(template, legs, locks);
    }

    // Public planning is read-only and always uses this server-selected template.
    // No caller-supplied member, route, template, geometry or distance is accepted.
    public struct function getTimeline(required string startDate, struct inputs={}) {
        var template = getActiveTemplate();
        var planning = planningService();
        var legs = planning.loadMainLegs(template.id, "CCW");
        var engine = timelineService();
        var timeline = engine.calculateCruiseTimeline(
            legs=legs,
            startDate=arguments.startDate,
            inputs=validatePlanningInputs(arguments.inputs),
            sourceMeta={route_type="public_template", distance_source="active_template"}
        );
        return {"success"=timeline.success, "timeline"=timeline, "legs"=legs,
                "defaults"=engine.getPlanningDefaults(), "template_code"=template.short_code};
    }

    public struct function getTimelineLockDetails(required numeric legOrder) {
        var template = getActiveTemplate();
        var planning = planningService();
        var legs = planning.loadMainLegs(template.id, "CCW");
        for (var leg in legs) {
            if (val(leg.ORDER_INDEX) EQ arguments.legOrder) {
                var result = planning.loadLegLocks(templateCode=template.short_code,
                    segmentId=leg.SEGMENT_ID, legOrder=leg.ORDER_INDEX, allowTemplateFallback=false);
                if (structKeyExists(result, "DATA")) {
                    result.DATA["start_name"] = leg.START_NAME;
                    result.DATA["end_name"] = leg.END_NAME;
                    result.DATA["expected_lock_count"] = leg.LOCK_COUNT;
                }
                return result;
            }
        }
        throw(type="GreatLoopReference.InvalidInput", message="Select a valid Great Loop leg.");
    }

    private struct function validatePlanningInputs(required struct inputs) {
        var numericFields = "cruising_speed,max_speed_kn,underway_hours_per_day,fuel_burn_gph,vessel_max_speed_kn,vessel_most_efficient_speed_kn,vessel_gph_at_most_efficient_speed,reserve_pct,weather_factor_pct";
        var clean = {};
        for (var key in arguments.inputs) {
            var value = arguments.inputs[key];
            if (!isSimpleValue(value)) throw(type="GreatLoopReference.InvalidInput", message="Invalid planning input.");
            value = trim(toString(value));
            if (listFindNoCase(numericFields, key)) {
                if (len(value) AND (!isNumeric(value) OR val(value) LT 0 OR val(value) GT 10000)) {
                    throw(type="GreatLoopReference.InvalidInput", message="Planning values must be nonnegative numbers.");
                }
                clean[lCase(key)] = value;
            } else if (compareNoCase(key,"pace") EQ 0 AND listFindNoCase("RELAXED,BALANCED,AGGRESSIVE",value)) {
                clean.pace = uCase(value);
            } else if (compareNoCase(key,"reserve_mode") EQ 0 AND listFindNoCase("thirds,percentage",value)) {
                clean.reserve_mode = lCase(value);
            } else {
                throw(type="GreatLoopReference.InvalidInput", message="Unsupported planning input.");
            }
        }
        return clean;
    }

    private any function planningService() {
        try { return createObject("component", "api.v1.RouteTemplatePlanningService").init(variables.datasource); }
        catch (any componentPathError) { return createObject("component", "fpw.api.v1.RouteTemplatePlanningService").init(variables.datasource); }
    }

    private any function timelineService() {
        try { return createObject("component", "api.v1.RouteTimelineService").init(variables.datasource); }
        catch (any componentPathError) { return createObject("component", "fpw.api.v1.RouteTimelineService").init(variables.datasource); }
    }

    private struct function selectTemplate(required query candidates) {
        var defaults = [];
        for (var candidate in arguments.candidates) {
            if (val(candidate.is_default) EQ 1) arrayAppend(defaults, candidate);
        }
        if (arrayLen(defaults) EQ 1) return defaults[1];
        if (!arrayLen(defaults) AND arguments.candidates.recordCount EQ 1) {
            return queryGetRow(arguments.candidates, 1);
        }
        // Never guess between ambiguous active templates or fall back to a stale list.
        throw(type="GreatLoopReference.TemplateUnavailable", message="No unique active Great Loop template.");
    }

    private struct function buildModel(required struct template, required query legs, required query locks) {
        var model = {templateCode=arguments.template.short_code, sections=[], totalLegs=0,
                     totalLocks=0, totalLockMinutes=0, hasEstimate=true, lockTimeLabel=""};
        var locksByLeg = {};
        var section = {};
        var leg = {};
        var lock = {};
        var sectionIndex = 0;
        var previousRegion = "";
        var usedLegs = {};
        for (var row in arguments.locks) {
            var key = toString(val(row.leg_number));
            if (!structKeyExists(locksByLeg, key)) locksByLeg[key] = [];
            lock = {name=len(trim(row.lock_name)) ? trim(row.lock_name) : "Lock name unavailable",
                    hasEstimate=val(row.has_estimate) EQ 1,
                    minutes=val(row.time_min)};
            lock.timeLabel = lock.hasEstimate ? formatDuration(lock.minutes) : "Unavailable";
            arrayAppend(locksByLeg[key], lock);
        }
        if (!arguments.legs.recordCount) {
            throw(type="GreatLoopReference.TemplateUnavailable", message="The active template has no legs.");
        }
        for (var row in arguments.legs) {
            var key = toString(val(row.leg_number));
            if (val(key) LT 1 OR structKeyExists(usedLegs, key)) {
                throw(type="GreatLoopReference.InvalidLegOrder", message="The template has invalid leg numbering.");
            }
            usedLegs[key] = true;
            var region = len(trim(row.region)) ? trim(row.region) : "Waterway";
            leg = {number=val(row.leg_number), title=trim(row.start_name) & " → " & trim(row.end_name),
                   locks=structKeyExists(locksByLeg,key) ? locksByLeg[key] : [],
                   lockCount=0, lockMinutes=0, hasEstimate=true,
                   isOffshore=val(row.is_offshore) EQ 1, isICW=val(row.is_icw) EQ 1};
            // Mapped locks take precedence over segment_library.lock_count, as in the planner.
            leg.lockCount = arrayLen(leg.locks) ? arrayLen(leg.locks) : max(0,val(row.fallback_lock_count));
            leg.hasEstimate = leg.lockCount EQ arrayLen(leg.locks);
            leg.searchText = region & " " & leg.title & " " & leg.number;
            for (lock in leg.locks) {
                leg.searchText &= " " & lock.name;
                if (lock.hasEstimate) leg.lockMinutes += lock.minutes;
                else leg.hasEstimate = false;
            }
            leg.searchText = lCase(leg.searchText);
            leg.lockTimeLabel = leg.hasEstimate ? formatDuration(leg.lockMinutes) : "Unavailable";
            if (!sectionIndex OR compare(region, previousRegion) NEQ 0) {
                section = {name=region, legs=[], hasLocks=false, isOffshore=false, isICW=false};
                arrayAppend(model.sections, section);
                sectionIndex++;
            }
            section = model.sections[sectionIndex];
            arrayAppend(section.legs, leg);
            section.hasLocks = section.hasLocks OR leg.lockCount GT 0;
            section.isOffshore = section.isOffshore OR leg.isOffshore;
            section.isICW = section.isICW OR leg.isICW;
            previousRegion = region;
            model.totalLegs++;
            model.totalLocks += leg.lockCount;
            if (leg.hasEstimate) model.totalLockMinutes += leg.lockMinutes;
            else model.hasEstimate = false;
        }
        model.lockTimeLabel = model.hasEstimate ? formatDuration(model.totalLockMinutes) : "Unavailable";
        return model;
    }

    private string function formatDuration(required numeric minutes) {
        var wholeMinutes = round(arguments.minutes);
        var hours = int(wholeMinutes / 60);
        var remainder = wholeMinutes MOD 60;
        if (!hours) return remainder & " min";
        return hours & " hr" & (remainder ? " " & remainder & " min" : "");
    }
}
