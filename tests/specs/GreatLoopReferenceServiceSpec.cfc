component extends="testbox.system.BaseSpec" output="false" {
    function run() {
        describe("Active Great Loop reference and lock estimates", function() {
            beforeEach(function() {
                variables.service = new fpw.api.v1.GreatLoopReferenceService().init("fpw");
                makePublic(variables.service, "selectTemplate", "selectForTest");
                makePublic(variables.service, "buildModel", "buildForTest");
            });
            it("selects the unique default or sole candidate without pinning a version", function() {
                var q = queryNew("id,short_code,is_default", "integer,varchar,integer", [
                    [901,"GL_NEW",1],[902,"GL_OTHER",0]]);
                expect(variables.service.selectForTest(q).id).toBe(901);
                expect(variables.service.selectForTest(queryNew("id,short_code,is_default",
                    "integer,varchar,integer",[[903,"GL_NEXT",0]])).id).toBe(903);
            });
            it("rejects missing or ambiguous active templates", function() {
                expect(function(){ variables.service.selectForTest(queryNew("id,short_code,is_default")); }).toThrow();
                expect(function(){ variables.service.selectForTest(queryNew("id,short_code,is_default",
                    "integer,varchar,integer",[[1,"A",0],[2,"B",0]])); }).toThrow();
                expect(function(){ variables.service.selectForTest(queryNew("id,short_code,is_default",
                    "integer,varchar,integer",[[1,"A",1],[2,"B",1]])); }).toThrow();
            });
            it("uses named mappings before fallback counts and includes cycle plus wait estimates", function() {
                var model = build(legs([[1,"A","B","Waterway",9,0,0]]), locks([
                    [1,1,"First Lock",1,30],[1,2,"Second Lock",1,40]]));
                var leg = model.sections[1].legs[1];
                expect(leg.lockCount).toBe(2);
                expect(leg.lockTimeLabel).toBe("1 hr 10 min");
                expect(leg.locks[2].name).toBe("Second Lock");
                expect(leg.searchText).toInclude("first lock");
                expect(model.totalLocks).toBe(2);
                expect(model.totalLockMinutes).toBe(70);
            });
            it("does not present incomplete time models as zero or as a partial total", function() {
                var model = build(legs([[1,"A","B","Canal",2,0,0]]), locks([
                    [1,1,"Known",1,40],[1,2,"Missing estimate",0,0]]));
                expect(model.sections[1].legs[1].lockTimeLabel).toBe("Unavailable");
                expect(model.sections[1].legs[1].locks[2].timeLabel).toBe("Unavailable");
                expect(model.lockTimeLabel).toBe("Unavailable");
            });
            it("retains fallback lock counts without inventing names or times", function() {
                var model = build(legs([[1,"A","B","Canal",3,0,0]]), locks([]));
                var leg = model.sections[1].legs[1];
                expect(leg.lockCount).toBe(3);
                expect(arrayLen(leg.locks)).toBe(0);
                expect(leg.hasEstimate).toBeFalse();
                expect(leg.lockTimeLabel).toBe("Unavailable");
            });
            it("distinguishes zero-lock legs and missing names", function() {
                var zero = build(legs([[1,"A","B","Lake",0,0,0]]), locks([]));
                expect(zero.lockTimeLabel).toBe("0 min");
                expect(zero.sections[1].legs[1].hasEstimate).toBeTrue();
                var missing = build(legs([[1,"A","B","Canal",1,0,0]]), locks([[1,1,"",1,25]]));
                expect(missing.sections[1].legs[1].locks[1].name).toBe("Lock name unavailable");
                expect(missing.lockTimeLabel).toBe("25 min");
            });
            it("groups consecutive template regions without reordering legs", function() {
                var model = build(legs([[1,"A","B","River",0,0,0],[2,"B","C","Lake",0,1,0],
                                       [3,"C","D","River",0,0,1]]), locks([]));
                expect(arrayLen(model.sections)).toBe(3);
                expect(model.sections[3].legs[1].number).toBe(3);
                expect(model.sections[2].legs[1].isOffshore).toBeTrue();
                expect(model.sections[3].legs[1].isICW).toBeTrue();
            });
            it("rejects empty lists and ambiguous lock-to-leg numbering", function() {
                expect(function(){ build(legs([]),locks([])); }).toThrow();
                expect(function(){ build(legs([[1,"A","B","X",0,0,0],[1,"B","C","X",0,0,0]]),locks([])); }).toThrow();
            });
            it("matches every live template leg and planner lock aggregate without database writes", function() {
                var model = variables.service.getModel();
                var q = queryExecute("
                    SELECT rts.order_index,
                        COALESCE(NULLIF(TRIM(p1.name),''),TRIM(sl.start_port_name),'') AS start_name,
                        COALESCE(NULLIF(TRIM(p2.name),''),TRIM(sl.end_port_name),'') AS end_name,
                        COALESCE(rll.lock_count,sl.lock_count,0) AS lock_count,
                        COALESCE(rll.lock_minutes,0) AS lock_minutes
                    FROM loop_routes rt
                    JOIN route_template_segments rts ON rts.route_id=rt.id
                    JOIN segment_library sl ON sl.id=rts.segment_id
                    LEFT JOIN ports p1 ON p1.id=sl.start_port_id
                    LEFT JOIN ports p2 ON p2.id=sl.end_port_id
                    LEFT JOIN (
                        SELECT rll.route_code,rll.leg,COUNT(*) AS lock_count,
                          SUM(COALESCE(ldm.base_cycle_min,0)+COALESCE(ldm.typical_wait_min,0)) AS lock_minutes
                        FROM route_leg_locks rll
                        LEFT JOIN lock_delay_model ldm ON ldm.lock_code=rll.lock_code
                        GROUP BY rll.route_code,rll.leg
                    ) rll ON rll.route_code COLLATE utf8mb4_unicode_ci=rt.short_code AND rll.leg=rts.order_index
                    WHERE rt.short_code=:code AND rt.is_active=1
                    ORDER BY rts.order_index,rts.id",
                    {code={value=model.templateCode,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
                var index=0;
                expect(model.totalLegs).toBe(q.recordCount);
                for (var section in model.sections) {
                    for (var leg in section.legs) {
                        index++;
                        expect(leg.number).toBe(q.order_index[index]);
                        expect(leg.title).toBe(q.start_name[index] & " → " & q.end_name[index]);
                        expect(leg.lockCount).toBe(q.lock_count[index]);
                        if (leg.hasEstimate) expect(leg.lockMinutes).toBe(q.lock_minutes[index]);
                    }
                }
            });
        });
    }
    private query function legs(required array rows) {
        return queryNew("leg_number,start_name,end_name,region,fallback_lock_count,is_offshore,is_icw",
            "integer,varchar,varchar,varchar,integer,integer,integer",arguments.rows);
    }
    private query function locks(required array rows) {
        return queryNew("leg_number,seq,lock_name,has_estimate,time_min",
            "integer,integer,varchar,integer,integer",arguments.rows);
    }
    private struct function build(required query legRows,required query lockRows) {
        return variables.service.buildForTest({short_code="SYNTHETIC"},arguments.legRows,arguments.lockRows);
    }
}
