const { test, expect } = require("@playwright/test");
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");

const BASE = "http://localhost:8500/fpw";
const OUTPUT = path.resolve(".codex-snapshots/bahamas-import-full-rollback-20261115/tests");
const PASSWORD = "RouteGeometryRegression!2026";
test.setTimeout(150000);

function lower(value) {
  if (Array.isArray(value)) return value.map(lower);
  if (!value || typeof value !== "object") return value;
  return Object.fromEntries(Object.entries(value).map(([key,item])=>[key.toLowerCase(),lower(item)]));
}
function success(body) {
  const result=lower(body);
  expect(result.success,JSON.stringify(result)).toBe(true);
  return result.data || result;
}
async function api(page, action, body={}) {
  const boot=lower(await (await page.request.get(BASE+"/api/v1/auth.cfc?method=bootstrap")).json());
  const response=await page.request.post(BASE+"/api/v1/routeBuilder.cfc?method=handle&action="+action,{
    data:body,headers:{"X-CSRF-Token":boot.csrf_token}
  });
  const result=await response.json();
  expect(response.status()).toBeLessThan(500);
  return lower(result);
}
async function dashboardApi(page,method,payload) {
  return lower(await page.evaluate(async({method,payload})=>window.Api[method](payload),{method,payload}));
}
async function closeWelcome(page) {
  const close=page.locator("#welcomeOnboardingCloseBtn");
  if(await close.isVisible()) await close.click();
}
async function openEditor(page,code) {
  await page.goto(BASE+"/app/dashboard.cfm",{waitUntil:"domcontentloaded"});
  await closeWelcome(page);
  await page.waitForFunction(()=>window.FPW?.DashboardModules?.routeBuilder?.openEditorForRoute);
  await page.evaluate(code=>window.FPW.DashboardModules.routeBuilder.openEditorForRoute(code),code);
  await expect(page.locator("#routeBuilderModal")).toBeVisible();
  const tourClose=page.getByRole("button",{name:"Close route generator tour",exact:true});
  if(await tourClose.isVisible()) await tourClose.click();
  await expect(page.locator('.fpw-routegen__leg[data-leg-order="1"] [data-leg-action="open-map"]').first()).toBeVisible();
}
async function saveGeometry(page) {
  const response=page.waitForResponse(r=>r.url().toLowerCase().includes("action=saveroutelegoverridegeometry"));
  await page.locator("#routeGenLegSaveBtn").click();
  const saved=success(await (await response).json());
  await expect(page.locator("#routeGenLegSaveBtn")).toBeEnabled();
  return saved;
}

test("ordinary My Route geometry, vessel, save/reopen, fuel and timeline remain independent",async({page})=>{
  fs.mkdirSync(OUTPUT,{recursive:true});
  const member="codex-route-geometry-"+Date.now()+"-"+crypto.randomUUID().slice(0,8)+"@example.test";
  const evidence={member,stages:[],cleanup:[],pageErrors:[],consoleErrors:[],serverErrors:[]};
  const ids={route:0,code:"",waypoints:[],vessels:[],contacts:[],operators:[]};
  page.on("pageerror",error=>evidence.pageErrors.push(error.message));
  page.on("console",message=>{if(message.type()==="error")evidence.consoleErrors.push(message.text());});
  page.on("response",response=>{if(response.status()>=500)evidence.serverErrors.push(response.status()+" "+response.url());});
  await page.setViewportSize({width:1440,height:1000});
  try {
    await page.goto(BASE+"/app/join.cfm",{waitUntil:"domcontentloaded"});
    await page.locator("#firstName").fill("Geometry");
    await page.locator("#lastName").fill("Regression");
    await page.locator("#email").fill(member);
    await page.locator("#password").fill(PASSWORD);
    await page.locator("#confirmPassword").fill(PASSWORD);
    await page.locator("#termsAccepted").check();
    const joined=page.waitForResponse(r=>r.url().includes("/auth.cfc")&&r.request().method()==="POST");
    await page.locator("#joinButton").click();
    const joinResult=lower(await (await joined).json());
    evidence.join={success:joinResult.success,message:joinResult.message,error:joinResult.error};
    expect(joinResult.success,JSON.stringify(joinResult)).toBe(true);
    await page.waitForURL(/\/app\/dashboard\.cfm/,{timeout:20000});
    await closeWelcome(page);
    await page.waitForFunction(()=>window.Api?.saveVessel);
    evidence.stages.push("Fresh member joined through public UI");

    success(await dashboardApi(page,"saveVessel",{vessel:{
      VESSELID:0,VESSELNAME:"Geometry regression vessel",TYPE:"Power",LENGTH:"24",MAX_SPEED:"20",
      MOST_EFFICIENT_SPEED:"12",GALLONS_PER_HOUR:"4",GPH_AT_MAX_SPEED:"7",FUEL_CAPACITY:"60",
      ISDEFAULTVESSEL:1,MAKE:"Test",MODEL:"Canonical",COLOR:"White",HOMEPORT:"",REGISTRATION:""
    }}));
    const vessels=success(await dashboardApi(page,"getVessels",{limit:100})).vessels;
    ids.vessels=vessels.map(v=>v.vesselid);
    evidence.vesselBefore=vessels;
    for(const waypoint of [
      {WAYPOINTNAME:"Geometry start",LATITUDE:"27.9506",LONGITUDE:"-82.4572"},
      {WAYPOINTNAME:"Geometry destination",LATITUDE:"27.9770",LONGITUDE:"-82.8270"}
    ]) success(await dashboardApi(page,"saveWaypoint",{waypoint:{WAYPOINTID:0,NOTES:"",...waypoint}}));
    const waypoints=success(await dashboardApi(page,"getWaypoints",{limit:100})).waypoints;
    ids.waypoints=waypoints.map(w=>w.waypointid);
    const start=waypoints.find(w=>w.waypointname==="Geometry start").waypointid;
    const end=waypoints.find(w=>w.waypointname==="Geometry destination").waypointid;
    ids.route=success(await api(page,"createuserroute",{route_name:"Geometry regression route"})).route_id;
    success(await api(page,"setuserroutestartwaypoint",{route_id:ids.route,start_waypoint_id:start}));
    const added=success(await api(page,"addwaypointlegtouserroute",{route_id:ids.route,end_waypoint_id:end}));
    const leg=added.legs[0].route_leg_id;
    const initial=success(await api(page,"saveroutelegoverridegeometry",{
      route_id:ids.route,route_leg_id:leg,
      points:[{lat:27.9506,lon:-82.4572},{lat:27.88,lon:-82.65},{lat:27.977,lon:-82.827}]
    }));
    expect(initial.computed_nm).toBeGreaterThan(0);
    evidence.initialNm=initial.computed_nm;
    const unsupported=await api(page,"guide_import",{});
    expect(unsupported.success).toBe(false);
    expect(unsupported.message).toBe("Unknown action");
    const numericOnly=await api(page,"saveroutelegoverridegeometry",{
      route_id:ids.route,route_leg_id:leg,manual_distance_nm:999
    });
    expect(numericOnly.success).toBe(false);
    expect(numericOnly.error.message).toContain("points");
    expect(success(await api(page,"getroutelegoverridegeometry",{route_id:ids.route,route_leg_id:leg})).computed_nm).toBe(initial.computed_nm);
    evidence.stages.push("Ordinary waypoint/start/leg/geometry APIs; removed importer and numeric-only save rejected");

    const inputs={
      route_type:"my_route",route_id:ids.route,route_name:"Geometry regression route",
      start_date:"2026-12-01",pace:"RELAXED",underway_hours_per_day:6.5,reserve_mode:"percentage",
      reserve_pct:20,idle_burn_gph:0,idle_hours_total:0,weather_factor_pct:0,
      selected_vessel_id:ids.vessels[0],vessel_max_speed_kn:20,cruising_speed:20,
      vessel_most_efficient_speed_kn:12,vessel_gph_at_most_efficient_speed:4,
      fuel_burn_gph:7,fuel_burn_gph_input:"7",fuel_burn_basis:"MAX_SPEED"
    };
    const generated=success(await api(page,"routegen_generate",inputs));
    ids.code=generated.route_code;
    expect(ids.code).toBeTruthy();
    evidence.generated=generated;
    await openEditor(page,ids.code);
    await expect(page.locator("#routeGenFuelBurnEfficientGph")).toHaveValue("4");
    await expect(page.locator("#routeGenFuelBurnGph")).toHaveValue("7");
    await page.locator('.fpw-routegen__leg[data-leg-order="1"] [data-leg-action="open-map"]').first().click();
    await expect(page.locator("#routeGenLegMap")).toBeVisible();
    await expect(page.locator("#routeGenLegMapHint")).toContainText("Draw or edit polyline");
    await expect(page.locator("#routeGenLegManualDistance")).toHaveCount(0);
    await expect(page.getByRole("button",{name:"Use calculated",exact:true})).toHaveCount(0);
    await expect(page.locator("#routeGenLegMapNm")).toHaveText(initial.computed_nm.toFixed(2));

    const map=page.locator("#routeGenLegMap");
    await map.locator(".leaflet-draw-draw-polyline").click();
    const bounds=await map.boundingBox();
    evidence.mapBounds=bounds;
    await map.click({position:{x:bounds.width*0.25,y:bounds.height*0.4}});
    await map.click({position:{x:bounds.width*0.48,y:bounds.height*0.65}});
    await map.click({position:{x:bounds.width*0.74,y:bounds.height*0.35}});
    await map.locator(".leaflet-draw-actions a").filter({hasText:"Finish"}).click();
    await expect(page.locator("#routeGenLegMapStatus")).toContainText("Draft geometry updated");
    evidence.drawnDisplay=await page.locator("#routeGenLegMapNm").textContent();
    const drawn=await saveGeometry(page);
    expect(drawn.computed_nm).toBeGreaterThan(0);
    expect(drawn.computed_nm).not.toBe(initial.computed_nm);
    evidence.drawnNm=drawn.computed_nm;
    await map.locator(".leaflet-draw-edit-edit").click();
    const vertex=map.locator(".leaflet-editing-icon").first();
    const vertexBox=await vertex.boundingBox();
    await page.mouse.move(vertexBox.x+vertexBox.width/2,vertexBox.y+vertexBox.height/2);
    await page.mouse.down();
    await page.mouse.move(vertexBox.x+vertexBox.width/2+35,vertexBox.y+vertexBox.height/2+20,{steps:6});
    await page.mouse.up();
    await map.locator(".leaflet-draw-actions a").filter({hasText:/^Save$/}).click();
    const edited=await saveGeometry(page);
    expect(edited.computed_nm).toBeGreaterThan(0);
    expect(edited.computed_nm).not.toBe(drawn.computed_nm);
    evidence.editedNm=edited.computed_nm;
    await page.screenshot({path:path.join(OUTPUT,"normal-geometry-edited.png")});
    await page.locator("#routeGenLegOverlayCloseBtn").click();
    const saved=page.waitForResponse(r=>r.url().toLowerCase().includes("action=routegen_update"));
    await page.locator("#routeGenSaveBtn").click();
    success(await (await saved).json());
    evidence.stages.push("Actual UI drew and edited polyline; computed NM changed; Save Route succeeded");

    await openEditor(page,ids.code);
    await page.locator('.fpw-routegen__leg[data-leg-order="1"] [data-leg-action="open-map"]').first().click();
    await expect(page.locator("#routeGenLegMapNm")).toHaveText(edited.computed_nm.toFixed(2));
    const loaded=success(await api(page,"getroutelegoverridegeometry",{route_id:ids.route,route_leg_id:leg}));
    expect(loaded.points.length).toBeGreaterThanOrEqual(2);
    expect(loaded.points).toEqual(JSON.parse(edited.geometry_json));
    expect(loaded.computed_nm).toBe(edited.computed_nm);
    expect(loaded.manual_distance_nm).toBeUndefined();
    const context=success(await api(page,"routegen_geteditcontext",{route_code:ids.code}));
    expect(Number(context.inputs.reserve_pct)).toBe(20);
    expect(Number(context.inputs.vessel_gph_at_most_efficient_speed)).toBe(4);
    expect(Number(context.inputs.selected_vessel_id)).toBe(Number(ids.vessels[0]));
    const timeline=await api(page,"gettimeline",{routeCode:ids.code});
    success(timeline);
    evidence.timeline=timeline;
    expect(Number(timeline.totals.total_nm)).toBe(edited.computed_nm);
    expect(Number(timeline.totals.fuel_estimate_gallons)).toBeGreaterThan(0);
    const cruise=await api(page,"generatecruisetimeline",{
      routeId:generated.route_id,routeType:"generated",startDate:"2026-12-01",maxHoursPerDay:6.5
    });
    success(cruise);
    evidence.cruiseTimeline=cruise;
    expect(Number(cruise.route_summary.total_nm)).toBe(edited.computed_nm);
    expect(Number(cruise.route_summary.total_required_fuel)).toBe(Number(timeline.totals.fuel_estimate_gallons));
    const after=success(await dashboardApi(page,"getVessels",{limit:100})).vessels;
    expect(after).toEqual(evidence.vesselBefore);
    await page.goto(BASE+"/app/dashboard.cfm");
    await closeWelcome(page);
    await expect(page.getByText("Planning drafts",{exact:true})).toHaveCount(0);
    expect(evidence.pageErrors).toEqual([]);
    expect(evidence.consoleErrors).toEqual([]);
    expect(evidence.serverErrors).toEqual([]);
    evidence.stages.push("Reopened saved geometry; normal fuel/reserve and cruise timeline passed; vessel unchanged; no dashboard drafts");
  } finally {
    if(ids.code) evidence.cleanup.push({kind:"generated route",result:await api(page,"deleteroute",{routeCode:ids.code})});
    if(ids.route) evidence.cleanup.push({kind:"source route",result:await api(page,"deleteuserroute",{route_id:ids.route})});
    for(const [kind,method,list] of [
      ["waypoint","deleteWaypoint",ids.waypoints],["vessel","deleteVessel",ids.vessels],
      ["contact","deleteContact",ids.contacts],["operator","deleteOperator",ids.operators]
    ]) for(const id of list) evidence.cleanup.push({kind,id,result:await dashboardApi(page,method,id)});
    fs.writeFileSync(path.join(OUTPUT,"normal-route-regression-evidence.json"),JSON.stringify(evidence,null,2));
    for(const entry of evidence.cleanup) expect(entry.result.success,JSON.stringify(entry)).toBe(true);
  }
});
