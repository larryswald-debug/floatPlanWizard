<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">
<cfparam name="url.phase" default="current">
<cfscript>
host = lCase(trim(cgi.http_host));
if (url.confirm NEQ "RUN_TEMPLATE_PLANNING_TESTS" OR !listFindNoCase("localhost,127.0.0.1,::1",cgi.server_name) OR !reFind("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$",host) OR val(cgi.server_port) NEQ 8500) {
    cfheader(statuscode=404);
    cfcontent(type="application/json; charset=utf-8",reset=true);
    writeOutput(serializeJSON({SUCCESS=false,ERROR="LOCAL_TEST_CONFIRMATION_REQUIRED"}));
    abort;
}
result = {SUCCESS=false};
try {
    helper = createObject("component","testbox.system.BaseSpec");
    builder = createObject("component","fpw.api.v1.routeBuilder");
    helper.makePublic(builder,"routegenLoadMainLegs","loadMainLegsForTest");
    helper.makePublic(builder,"routegenGetLegLocks","getLegLocksForTest");
    model = createObject("component","fpw.api.v1.GreatLoopReferenceService").init("fpw").getModel();
    template = queryExecute("SELECT id FROM loop_routes WHERE short_code=:code AND is_active=1",
        {code={value=model.templateCode,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
    if (template.recordCount NEQ 1) throw(message="Active template is not unique");
    ccw = builder.loadMainLegsForTest(template.id[1],"CCW");
    cw = builder.loadMainLegsForTest(template.id[1],"CW");
    samples = [];
    sampledZero = false;
    for (i=1;i LTE arrayLen(ccw);i++) {
        if (i LTE 2 OR (!sampledZero AND ccw[i].LOCK_COUNT EQ 0)) {
            arrayAppend(samples,builder.getLegLocksForTest(userId=0,templateCode=model.templateCode,
                segmentId=ccw[i].SEGMENT_ID,legOrder=ccw[i].ORDER_INDEX));
            if (ccw[i].LOCK_COUNT EQ 0) sampledZero=true;
        }
    }
    result = {SUCCESS=true,templateCode=model.templateCode,templateId=template.id[1],ccw=ccw,cw=cw,lockSamples=samples};
    if (url.phase NEQ "baseline") {
        service = createObject("component","fpw.api.v1.RouteTemplatePlanningService").init("fpw");
        sharedCcw = service.loadMainLegs(template.id[1],"CCW");
        sharedCw = service.loadMainLegs(template.id[1],"CW");
        if (serializeJSON(ccw) NEQ serializeJSON(sharedCcw) OR serializeJSON(cw) NEQ serializeJSON(sharedCw)) throw(message="Generator and shared leg outputs differ");
        bad = service.loadLegLocks(model.templateCode,2147483647,1,false);
        if (!bad.SUCCESS OR bad.DATA.mapping_available OR bad.DATA.delay_estimates_available) throw(message="Missing mapping was not marked unavailable");
        wrong = service.loadLegLocks("MISSING_TEMPLATE",ccw[1].SEGMENT_ID,1,false);
        if (!wrong.SUCCESS OR wrong.DATA.mapping_available) throw(message="Strict template mapping borrowed another template");
        sharedLock = service.loadLegLocks(model.templateCode,ccw[1].SEGMENT_ID,1,false);
        if (!sharedLock.SUCCESS OR sharedLock.DATA.lock_count NEQ samples[1].DATA.lock_count) throw(message="Generator and shared lock counts differ");
        if (serializeJSON(sharedLock.DATA.locks) NEQ serializeJSON(samples[1].DATA.locks)) throw(message="Generator and shared lock rows differ");
        wrongOrder = service.loadLegLocks(model.templateCode,ccw[1].SEGMENT_ID,2,false);
        if (!wrongOrder.SUCCESS OR wrongOrder.DATA.mapping_available) throw(message="Strict mapping accepted another template leg order");
        legacyFallback = service.loadLegLocks("MISSING_TEMPLATE",ccw[1].SEGMENT_ID,1,true);
        if (!legacyFallback.SUCCESS OR !legacyFallback.DATA.mapping_available) throw(message="Generator legacy fallback changed");
        denied = builder.getLegLocksForTest(userId=0,routeCode="__template_planning_unowned__",templateCode=model.templateCode,
            segmentId=ccw[1].SEGMENT_ID,legOrder=1);
        if (denied.SUCCESS OR denied.MESSAGE NEQ "Route not found") throw(message="Member route ownership wrapper was bypassed");
        for (method in getMetadata(service).functions) {
            if (method.access EQ "remote") throw(message="Template planning methods must not be remote");
        }
        result.checks = ["generator/shared CCW parity","generator/shared CW parity","missing mapping unavailable","strict template mapping","generator/shared lock row parity","strict leg order","legacy generator fallback","member route ownership wrapper","no remote methods"];
    }
} catch (any e) {
    result = {SUCCESS=false,MESSAGE=e.message,DETAIL=e.detail};
    cfheader(statuscode=500);
}
cfcontent(type="application/json; charset=utf-8",reset=true);
writeOutput(serializeJSON(result));
</cfscript>
