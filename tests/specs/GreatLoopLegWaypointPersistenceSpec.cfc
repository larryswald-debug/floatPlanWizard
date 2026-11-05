component extends="testbox.system.BaseSpec" output=false {
    function run() {
        describe("Great Loop leg stops use the existing owned waypoint writer",function() {
            beforeEach(function() {
                if (!structKeyExists(request,"legWaypointFixtureUserId")) throw(message="Disposable fixture is required.");
                variables.uid=request.legWaypointFixtureUserId;
                variables.service=new fpw.api.v1.GreatLoopReferenceService().init("fpw");
                var model=variables.service.getTimeline("2026-11-04");
                variables.sources=variables.service.getLegWaypointSources(model.template_code,model.legs[3].ORDER_INDEX,model.legs[3].SEGMENT_ID).endpoints;
                variables.adjacent=variables.service.getLegWaypointSources(model.template_code,model.legs[4].ORDER_INDEX,model.legs[4].SEGMENT_ID).endpoints;
                variables.controller=new fpw.tests.support.LegWaypointTestHarness().controller();
                clean();
            });
            afterEach(function(){clean();});
            it("adds the ordered pair and required activity atomically",function() {
                var saved=controller.saveForTest(uid,sources);
                expect(saved.ADDED_COUNT).toBe(2);expect(saved.EXISTING_COUNT).toBe(0);
                expect(saved.ENDPOINTS[1].NAME).toBe("Ottawa");expect(saved.ENDPOINTS[2].NAME).toBe("Peoria");
                expect(counts().points).toBe(2);expect(counts().events).toBe(2);
            });
            it("replays both existing endpoints without duplicate activity or writes",function() {
                var first=controller.saveForTest(uid,sources);var replay=controller.saveForTest(uid,sources);
                expect(replay.RESULT).toBe("already_exists");expect(replay.EXISTING_COUNT).toBe(2);
                expect(replay.ENDPOINTS[1].WAYPOINTID).toBe(first.ENDPOINTS[1].WAYPOINTID);
                expect(counts().points).toBe(2);expect(counts().events).toBe(2);
            });
            it("adds only the missing end when the start was saved through Ports",function() {
                single(sources[1]);var saved=controller.saveForTest(uid,sources);
                expect(saved.ADDED_COUNT).toBe(1);expect(saved.EXISTING_COUNT).toBe(1);
                expect(saved.ENDPOINTS[1].STATUS).toBe("already_exists");expect(saved.ENDPOINTS[2].STATUS).toBe("added");
                expect(counts().points).toBe(2);
            });
            it("adds only the missing start when the end was saved through Ports",function() {
                single(sources[2]);var saved=controller.saveForTest(uid,sources);
                expect(saved.ADDED_COUNT).toBe(1);expect(saved.ENDPOINTS[1].STATUS).toBe("added");
                expect(saved.ENDPOINTS[2].STATUS).toBe("already_exists");expect(counts().points).toBe(2);
            });
            it("shares the middle port between adjacent legs",function() {
                controller.saveForTest(uid,sources);var next=controller.saveForTest(uid,adjacent);
                expect(next.ADDED_COUNT).toBe(1);expect(next.EXISTING_COUNT).toBe(1);
                expect(counts().points).toBe(3);expect(counts().events).toBe(3);
            });
            it("rolls back the first waypoint and its activity when the second write fails",function() {
                var failing=new fpw.tests.support.LegWaypointTestHarness().controller(2);
                expect(function(){failing.saveForTest(uid,sources);}).toThrow();
                expect(counts().points).toBe(0);expect(counts().events).toBe(0);
                expect(controller.saveForTest(uid,sources).ADDED_COUNT).toBe(2);
            });
            it("rolls back before the first activity commit and remains retryable",function() {
                var failing=new fpw.tests.support.LegWaypointTestHarness().controller(1);
                expect(function(){failing.saveForTest(uid,sources);}).toThrow();
                expect(counts().points).toBe(0);expect(counts().events).toBe(0);
            });
            it("does not dedupe a same-named point at different coordinates",function() {
                var changed=duplicate(sources[1]);changed.waypoint.LATITUDE=toString(val(changed.waypoint.LATITUDE)+0.0001);
                single(changed);expect(controller.saveForTest(uid,sources).ADDED_COUNT).toBe(2);expect(counts().points).toBe(3);
            });
            it("retains existing generic waypoint create/update and activity behavior",function() {
                var first=controller.singleForTest(uid,0,"Manual stop","27.95","-82.46","Test only",{});
                controller.singleForTest(uid,first.WAYPOINTID,"Manual stop","27.95","-82.46","Test only",{});
                expect(counts().points).toBe(1);expect(counts().events).toBe(1);
                controller.singleForTest(uid,first.WAYPOINTID,"Changed stop","27.95","-82.46","Test only",{});
                expect(counts().events).toBe(2);
            });
            it("preserves Port, Anchorage, Bridge and Lock source saves and replay identities",function() {
                var resolver=new fpw.api.v1.LibraryWaypointService();
                for(var input in [
                    {library="port",portId=168},
                    {library="anchorage",slug="chesapeake-city-anchorage-basin-chesapeake-city-md"},
                    {library="bridge",slug="tom-adams-bridge-glb-0008"},
                    {library="lock",slug="olmsted-locks-and-dam"}
                ]) {
                    var source=resolver.resolve(input);
                    expect(source.eligible).toBeTrue();
                    var first=single(source);var replay=single(source);
                    expect(first.ALREADY_SAVED).toBeFalse();expect(replay.ALREADY_SAVED).toBeTrue();
                    expect(replay.WAYPOINTID).toBe(first.WAYPOINTID);
                    var saved=queryExecute("SELECT name,latitude,longitude,notes FROM waypoints WHERE wpId=:id AND userId=:uid",
                        {id={value=first.WAYPOINTID,cfsqltype="cf_sql_integer"},uid={value=uid,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
                    expect(saved.name[1]).toBe(source.waypoint.WAYPOINTNAME);
                    expect(saved.notes[1]).toBe(source.waypoint.NOTES);
                    expect(val(saved.latitude[1])).toBe(val(source.waypoint.LATITUDE));
                    expect(val(saved.longitude[1])).toBe(val(source.waypoint.LONGITUDE));
                }
                expect(counts().points).toBe(4);expect(counts().events).toBe(4);
            });
            it("refuses a nonexistent member and leaves the fixture collection unchanged",function() {
                expect(function(){controller.saveForTest(2147483647,sources);}).toThrow();
                expect(counts().points).toBe(0);expect(counts().events).toBe(0);
            });
        });
    }
    private any function single(required struct source) {
        var p=source.waypoint;return variables.controller.singleForTest(variables.uid,0,p.WAYPOINTNAME,p.LATITUDE,p.LONGITUDE,p.NOTES,source);
    }
    private struct function counts() {
        var p={uid={value=variables.uid,cfsqltype="cf_sql_integer"}};
        return {points=queryExecute("SELECT COUNT(*) AS n FROM waypoints WHERE userId=:uid",p,{datasource="fpw"}).n[1],
            events=queryExecute("SELECT COUNT(*) AS n FROM product_events WHERE user_id=:uid AND event_name IN ('waypoint_created','waypoint_updated')",p,{datasource="fpw"}).n[1]};
    }
    private void function clean() {
        if (!structKeyExists(variables,"uid")) return;
        var p={uid={value=variables.uid,cfsqltype="cf_sql_integer"}};
        if (queryExecute("SELECT userId FROM users WHERE userId=:uid AND email LIKE 'codex-activity-leg-stops-%@example.test' AND created>=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 2 HOUR)",p,{datasource="fpw"}).recordCount NEQ 1) throw(message="Refusing non-fixture cleanup.");
        transaction {
            queryExecute("DELETE FROM waypoints WHERE userId=:uid",p,{datasource="fpw"});
            queryExecute("DELETE FROM product_events WHERE user_id=:uid AND event_name IN ('waypoint_created','waypoint_updated')",p,{datasource="fpw"});
        }
    }
}
