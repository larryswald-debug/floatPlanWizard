component output="false" hint="Read-only Great Loop reference built from the active public route template." {
    public any function init(string datasource="") {
        variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : application.dsn;
        return this;
    }

    public struct function getModel() {
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
        var template = selectTemplate(candidates);
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
