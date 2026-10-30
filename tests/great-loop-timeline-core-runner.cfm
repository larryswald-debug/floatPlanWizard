<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">
<cfset localHost = reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$", cgi.http_host) GT 0>
<cfset localServer = listFindNoCase("localhost,127.0.0.1,::1", cgi.server_name) GT 0>
<cfif NOT localHost OR NOT localServer OR val(cgi.server_port) NEQ 8500 OR url.confirm NEQ "RUN_GREAT_LOOP_TIMELINE_CORE_TESTS">
    <cfheader statuscode="404"><cfcontent type="application/json" reset="true">
    <cfoutput>#serializeJSON({SUCCESS=false,ERROR="LOCAL_TEST_CONFIRMATION_REQUIRED"})#</cfoutput><cfabort>
</cfif>
<cfscript>
result = {SUCCESS=false,checks=[]};
function check(required boolean passed, required string name) {
    arrayAppend(result.checks,{name=arguments.name,passed=arguments.passed});
    if (!arguments.passed) throw(type="GreatLoopTimelineCore.Assertion",message=arguments.name);
}
function near(required numeric actual, required numeric expected) { return abs(arguments.actual-arguments.expected) LT 0.011; }
function leg(required numeric id, required numeric distance, numeric locks=0, numeric minutes=0, numeric exposure=0) {
    return {id=arguments.id,route_leg_id=arguments.id,segment_id=arguments.id,order_index=arguments.id,
        start_name="Port " & arguments.id,end_name="Port " & (arguments.id+1),dist_nm=arguments.distance,
        lock_count=arguments.locks,lock_time_min_total=arguments.minutes,is_offshore=0,is_icw=1,exposure_level=arguments.exposure};
}
try {
    service = new fpw.api.v1.RouteTimelineService().init("fpw");
    inputs = {pace="AGGRESSIVE",cruising_speed=10,fuel_burn_gph=4,weather_factor_pct=0,reserve_pct=33,reserve_mode="thirds",underway_hours_per_day=6.5};
    legs = [leg(1,40,2,60),leg(2,45,1,30)];
    before = serializeJSON(legs);
    timeline = service.calculateCruiseTimeline(legs=legs,startDate="2026-10-29",inputs=inputs);
    check(timeline.success AND arrayLen(timeline.days) EQ 2,"Canonical daily grouping accepts public preview shape");
    check(near(timeline.route_summary.total_nm,85) AND near(timeline.route_summary.total_required_fuel,51),"Distance and required fuel match deterministic fixture");
    check(near(timeline.days[1].est_hours,6.5) AND near(timeline.days[2].est_hours,3.5),"Typical lock time participates in canonical hours and day splitting");
    check(near(timeline.days[1].segment_slices[1].segment_cruising_hours,4) AND near(timeline.days[1].segment_slices[1].segment_hours,5)
        AND near(timeline.days[1].segment_slices[2].segment_cruising_hours,4.5)
        AND near(timeline.days[2].segment_slices[1].segment_cruising_hours,4.5),"Additive cruising-hours projection captures existing pre-lock hours and survives day splitting");
    check(arrayLen(timeline.days[1].segment_slices) EQ 2 AND arrayLen(timeline.days[2].segment_slices) EQ 1,"Multiple legs share a day and long legs retain daily slices");
    check(timeline.days[1].lock_count EQ 3 AND timeline.days[2].lock_count EQ 0,"A split leg assigns locks exactly once");
    check(near(timeline.days[1].reserve_gallons,11) AND near(timeline.days[2].reserve_gallons,6),"Thirds reserve uses the existing shared fuel helper");
    check(timeline.days[1].risk_color EQ "GREEN" AND timeline.days[2].risk_color EQ "GREEN","Canonical daily status is retained");
    check(serializeJSON(legs) EQ before,"Calculation does not mutate public input legs");

    ownedQuery = queryNew("id,route_leg_id,segment_id,order_index,start_name,end_name,dist_nm,lock_count,lock_time_min_total,is_offshore,is_icw,exposure_level");
    for (row in legs) {
        queryAddRow(ownedQuery);
        for (key in row) querySetCell(ownedQuery,key,row[key]);
    }
    fromQuery = service.calculateCruiseTimeline(legs=ownedQuery,startDate="2026-10-29",inputs=inputs);
    check(serializeJSON(timeline) EQ serializeJSON(fromQuery),"Owned-query and public-array adapters produce identical full calculation payloads");

    overrideLeg = leg(1,20);
    overrideLeg.base_dist_nm = 100;
    overrideLeg.geometry_dist_nm = 75;
    overrideLeg.generated_dist_nm = 90;
    overridden = service.calculateCruiseTimeline(legs=[overrideLeg],startDate="2026-10-29",inputs=inputs);
    check(near(overridden.route_summary.total_nm,20) AND near(overridden.days[1].est_hours,2),"Effective dist_nm takes precedence over unrelated geometry/generated distance metadata");

    weatherInputs = duplicate(inputs);
    weatherInputs.weather_factor_pct = 20;
    weather = service.calculateCruiseTimeline(legs=[leg(1,20,1,60,2)],startDate="2026-10-29",inputs=weatherInputs);
    check(near(weather.timeline_meta.effective_weather_pct_max,20) AND near(weather.days[1].est_hours,3.5),"Exposure-adjusted weather and typical lock delay use the existing engine");
    check(near(weather.days[1].required_fuel_gallons,18) AND near(weather.days[1].reserve_gallons,6),"Weather-adjusted fuel and reserve remain canonical");

    reserveInputs = duplicate(inputs);
    reserveInputs.reserve_mode = "percentage";
    reserveInputs.reserve_pct = 20;
    percentage = service.calculateCruiseTimeline(legs=[leg(1,20)],startDate="2026-10-29",inputs=reserveInputs);
    check(near(percentage.days[1].required_fuel_gallons,9.6) AND near(percentage.days[1].reserve_gallons,1.6) AND percentage.days[1].risk_color EQ "YELLOW","Percentage reserve and warning status match the existing engine");
    reserveInputs.reserve_pct = 15;
    critical = service.calculateCruiseTimeline(legs=[leg(1,20)],startDate="2026-10-29",inputs=reserveInputs);
    check(critical.days[1].risk_color EQ "RED","Canonical critical reserve status retained");
    longInputs = duplicate(inputs);
    longInputs.underway_hours_per_day = 12;
    longDay = service.calculateCruiseTimeline(legs=[leg(1,100)],startDate="2026-10-29",inputs=longInputs);
    check(near(longDay.days[1].est_hours,10) AND longDay.days[1].risk_color EQ "YELLOW","Long-day status adjustment remains canonical");

    defaults = service.getPlanningDefaults();
    check(defaults.pace EQ "RELAXED" AND defaults.max_speed_kn EQ 20 AND defaults.underway_hours_per_day EQ 6.5 AND defaults.weather_factor_pct EQ 0 AND defaults.reserve_pct EQ 33 AND defaults.reserve_mode EQ "thirds" AND defaults.fuel_burn_gph EQ "","Public defaults come from existing generator normalizers");
    missingFuel = service.calculateCruiseTimeline(legs=[leg(1,20)],startDate="2026-10-29",inputs=defaults);
    check(!missingFuel.timeline_meta.fuel_resolved AND missingFuel.timeline_meta.fuel_source EQ "missing","Missing vessel fuel remains explicitly unresolved");
    check(near(missingFuel.timeline_meta.effective_speed_kn,5) AND near(missingFuel.days[1].est_hours,4),"Documented relaxed-pace default is reused by the shared calculation");

    yearEnd = service.calculateCruiseTimeline(legs=legs,startDate="2026-12-31",inputs=inputs);
    monthEnd = service.calculateCruiseTimeline(legs=legs,startDate="2026-10-31",inputs=inputs);
    check(yearEnd.days[2].date EQ "2027-01-01" AND monthEnd.days[2].date EQ "2026-11-01","Existing date-only grouping crosses month and year boundaries");
    invalidDate = service.calculateCruiseTimeline(legs=legs,startDate="2026-10-29T12:00",inputs=inputs);
    check(!invalidDate.success AND invalidDate.message EQ "Invalid startDate","Engine remains date-only; no invented hourly scheduling");
    empty = service.calculateCruiseTimeline(legs=[],startDate="2026-10-29",inputs=inputs);
    check(!empty.success AND empty.message EQ "Route has no segments","Empty public adapter fails explicitly");
    unauthorized = service.generateCruiseTimeline(userId=0,routeId=1,startDate="2026-10-29",previewLegs=legs,inputOverrides=inputs);
    check(!unauthorized.success AND unauthorized.message EQ "Unauthorized","Owned wrapper does not permit anonymous preview bypass");
    result.SUCCESS = true;
    result.totalChecks = arrayLen(result.checks);
    result.fixture = timeline;
} catch (any error) {
    result.message=error.message;
    result.detail=error.detail;
    result.type=error.type;
}
</cfscript>
<cfif NOT result.SUCCESS><cfheader statuscode="500"></cfif>
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfoutput>#serializeJSON(result)#</cfoutput>
