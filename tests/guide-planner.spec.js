const { test, expect } = require("@playwright/test");
const path = require("node:path");
const root = path.resolve(__dirname, "..");
const inputs = {planning_speed_kn:20,underway_burn_us_gph:18,underway_hours_per_day:6,reserve_mode:"percentage",reserve_pct:20,idle_burn_us_gph:0,idle_hours_total:0,usable_fuel_us_gal:190,start_date:"2026-12-01",performance_confirmed:true};
function fixture(distances=[60,60]) {
  return {user_route_id:42,template_key:"fort-lauderdale-bimini",template_version:1,revision:1,route_name:"Guide fixture",planning_inputs:{...inputs},trip_notes:"Two local days and two uncommitted weather days.",legs:distances.map((distance,i)=>({user_route_leg_id:i+1,leg_key:"leg-"+i,start_name:i?"Bimini":"Port Everglades",end_name:i?"Port Everglades":"Bimini",distance_nm:distance,distance_missing:distance===null,distance_kind:distance===null?"missing":"illustrative_estimate",distance_method:distance===null?"":"Constructed test assumption only",geometry_kind:"schematic",content_fingerprint:"fingerprint-"+i,review_status:"unreviewed"}))};
}
async function setup(page,data=fixture()) {
  await page.setContent('<main id="fpwRouteGen"><input id="routeGenRouteName" value="Guide fixture"><section id="guideTripPanel"></section><button id="routeGenSaveBtn">Save planning draft</button><button id="routeGenGenerateBtn">Save trip</button></main>');
  await page.addScriptTag({path:path.join(root,"assets/js/app/shared/fuel-math.js")});
  await page.addScriptTag({path:path.join(root,"assets/js/app/dashboard/guide-planner.js")});
  await page.evaluate(data=>{
    window.__draft=data; window.__calls=[]; window.__failTripOnce=false;
    window.Api={getAuthCsrfToken:()=>Promise.resolve("fixture-csrf")};
    Object.defineProperty(window.crypto,"randomUUID",{configurable:true,value:()=>"6e4f4fe3-9b02-4fc3-9aa2-47a17c9ea3a1"});
    window.fetch=(url,options)=>{
      const action=new URL(url,"https://example.test").searchParams.get("action"), body=JSON.parse(options.body);
      window.__calls.push({action,body,csrf:options.headers["X-CSRF-Token"]});
      if(action==="guide_savetrip" && window.__failTripOnce){window.__failTripOnce=false; return Promise.reject(new Error("Lost response"));}
      if(action==="guide_savedraft"){
        window.__draft={...window.__draft,revision:window.__draft.revision+1,planning_inputs:body.planning_inputs,trip_notes:body.trip_notes,
          legs:window.__draft.legs.map(old=>{const row=body.legs.find(r=>r.user_route_leg_id===old.user_route_leg_id);return {...old,...row,distance_missing:row.distance_nm===null,review_status:row.review_action==="replace"?"member_replaced":row.review_action==="confirm"?"member_confirmed":"unreviewed"};})};
      }
      return Promise.resolve({ok:true,json:()=>Promise.resolve({SUCCESS:true,AUTH:true,DATA:window.__draft})});
    };
    window.FPW.GuidePlanner.mount(data,{});
  },data);
}
test("explicit worksheet arithmetic, reserve modes and missing values",async({page})=>{
  await setup(page);
  const result=await page.evaluate(({inputs})=>{
    const calc=legs=>window.FPW.GuidePlanner.calculate({planning_inputs:{...inputs},legs:legs.map(distance_nm=>({distance_nm,distance_method:"Test worksheet"}))});
    const full=calc([60,60]),partial=calc([60,null]);
    const thirds=window.FPW.GuidePlanner.calculate({planning_inputs:{...inputs,reserve_mode:"thirds",reserve_pct:33},legs:[{distance_nm:120,distance_method:"Test worksheet"}]});
    const noSpeed=window.FPW.GuidePlanner.calculate({planning_inputs:{...inputs,planning_speed_kn:null},legs:[{distance_nm:60,distance_method:"Test worksheet"}]});
    const noConfirm=window.FPW.GuidePlanner.calculate({planning_inputs:{...inputs,performance_confirmed:false},legs:[{distance_nm:60,distance_method:"Test worksheet"}]});
    return {full,partial,thirds,noSpeed,noConfirm,empty:window.FPW.GuidePlanner.parseNumber("")};
  },{inputs});
  expect(result.full).toMatchObject({complete:true,nm:120,hours:6,cruise:108,reserve:21.6,required:129.6});
  expect(result.full.margin).toBeCloseTo(60.4);
  expect(result.partial).toMatchObject({complete:false,nm:60,hours:3,cruise:54,margin:null,missing:1});
  expect(result.thirds.reserve).toBe(54);
  expect(result.noSpeed.hours).toBeNull();
  expect(result.noConfirm.complete).toBe(false);
  expect(result.empty).toBeNull();
});
test("draft save preserves missing mileage and notes",async({page})=>{
  await setup(page,fixture([60,null]));
  await expect(page.locator("[data-guide-totals]")).toContainText("Incomplete estimate");
  await expect(page.locator("#guide-mileage-2")).toHaveValue("");
  await expect(page.locator("#routeGenGenerateBtn")).toBeDisabled();
  await page.locator("[data-guide-notes]").fill("Wait two additional days; return source missing.");
  await page.evaluate(()=>window.FPW.GuidePlanner.saveDraft());
  const call=await page.evaluate(()=>window.__calls.find(c=>c.action==="guide_savedraft"));
  expect(call.body.legs[1].distance_nm).toBeNull();
  expect(call.body.trip_notes).toContain("return source missing");
  expect(call.csrf).toBe("fixture-csrf");
  await page.evaluate(()=>window.FPW.GuidePlanner.refresh());
  await expect(page.locator("#guide-mileage-2")).toHaveValue("");
  await expect(page.locator("[data-guide-totals]")).toContainText("Incomplete estimate");
});
test("replacement review uses original fingerprint and keeps estimate meaning",async({page})=>{
  await setup(page);
  await page.locator("#guide-mileage-1").fill("65");
  await page.locator("#guide-method-1").fill("Member reviewed intended route and allowance");
  await page.locator('[data-guide-review="1"]').click();
  const call=await page.evaluate(()=>window.__calls.find(c=>c.action==="guide_savedraft"));
  expect(call.body.legs[0]).toMatchObject({distance_nm:65,distance_kind:"member_entered",content_fingerprint:"fingerprint-0",review_action:"replace"});
  await expect(page.locator('[data-guide-leg="1"] [data-guide-review-state]')).toContainText("not independently verified");
  await page.locator("#guide-planning_speed_kn").fill("7");
  await expect(page.locator("[data-guide-performance-confirmed]")).not.toBeChecked();
  await expect(page.locator("#routeGenGenerateBtn")).toBeDisabled();
});
test("lost trip-save response retries the identical UUID and revision without another draft mutation",async({page})=>{
  await setup(page);
  await page.evaluate(()=>{window.__failTripOnce=true;return window.FPW.GuidePlanner.saveTrip();});
  await expect(page.locator("[data-guide-status]")).toContainText("Retry Save trip");
  await page.evaluate(()=>window.FPW.GuidePlanner.saveTrip());
  const calls=await page.evaluate(()=>window.__calls);
  expect(calls.filter(c=>c.action==="guide_savedraft")).toHaveLength(1);
  const saves=calls.filter(c=>c.action==="guide_savetrip");
  expect(saves).toHaveLength(2);
  expect(saves[0].body).toEqual(saves[1].body);
});
test("responsive panel keeps unknown distance blank at 390 pixels",async({page})=>{
  await page.setViewportSize({width:390,height:844});
  await setup(page,fixture([null,null]));
  await page.addStyleTag({path:path.join(root,"assets/css/guide-planner.css")});
  await expect(page.locator("[data-guide-mileage]").first()).toHaveValue("");
  await expect(page.locator("#guideTripPanel")).toContainText("Schematic connection; not a navigation track");
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth)).toBe(true);
});


test("shared Follow map separates schematic and member plots and clears guide labels for ordinary routes",async({page})=>{
  await page.setContent('<div id="followMap"></div>');
  await page.evaluate(()=>{
    window.__mapLines=[];
    window.L={
      map:()=>({setView(){return this;}}),
      tileLayer:()=>({addTo(){return this;}}),
      layerGroup:()=>({addTo(){return this;},clearLayers(){window.__mapLines=[];}}),
      polyline:(points,style)=>({addTo(){window.__mapLines.push({points,style:{...style},tooltip:""});return this;},bindTooltip(text){window.__mapLines[window.__mapLines.length-1].tooltip=text;return this;}}),
      control:()=>({addTo(){this.node=this.onAdd();this.node.dataset.guideMapLegend="true";document.body.appendChild(this.node);return this;},remove(){this.node.remove();}})
    };
  });
  await page.addScriptTag({path:path.join(root,"assets/js/app/follow/followMap.js")});
  await page.evaluate(()=>{
    window.FPWFollowMap.initFollowMap("followMap");
    window.FPWFollowMap.renderRoute({type:"MultiLineString",coordinates:[[[-80,26],[-79,25]],[[-79,25],[-80,26]]],guide_estimates:true,guide_geometry_sources:["schematic","member_plotted"]});
  });
  let lines=await page.evaluate(()=>window.__mapLines);
  expect(lines[0].style.dashArray).toBe("8 7");
  expect(lines[0].tooltip).toContain("not a navigational route");
  expect(lines[1].style.dashArray).toBeNull();
  expect(lines[1].tooltip).toContain("not independently verified");
  await expect(page.locator("[data-guide-map-legend]")).toContainText("Planning estimates");
  await page.evaluate(()=>window.FPWFollowMap.renderRoute({type:"MultiLineString",coordinates:[[[-80,26],[-79,25]],[[-79,25],[-80,26]]],guide_estimates:true,guide_geometry_sources:["schematic","schematic"]}));
  lines=await page.evaluate(()=>window.__mapLines);
  expect(lines[0].points).toEqual(lines[1].points); // opposite direction may otherwise fill every dash gap
  await page.evaluate(()=>window.FPWFollowMap.renderRoute({type:"LineString",coordinates:[[-80,26],[-79,25]]}));
  lines=await page.evaluate(()=>window.__mapLines);
  expect(lines).toHaveLength(1);
  expect(lines[0].style).not.toHaveProperty("dashArray");
  expect(lines[0].tooltip).toBe("");
  await expect(page.locator("[data-guide-map-legend]")).toHaveCount(0);
});

test("generic route tour waits for saved context and skips guide copies without marking it seen",async({page})=>{
  await page.setContent('<div id="routeBuilderModal" class="show"><main id="fpwRouteGen" data-route-context-loading="true"><input id="routeGenRouteName" value="Imported guide"></main></div>');
  await page.addScriptTag({path:path.join(root,"assets/js/app/dashboard/route-generator-tour.js")});
  await page.evaluate(()=>document.getElementById("routeBuilderModal").dispatchEvent(new CustomEvent("fpw:route-context-ready")));
  await expect(page.locator("[data-fpw-route-generator-tour-layer]")).toHaveCount(0);
  await page.evaluate(()=>{
    const root=document.getElementById("fpwRouteGen");root.dataset.routeContextLoading="false";root.classList.add("fpw-guide-mode");
    document.getElementById("routeBuilderModal").dispatchEvent(new CustomEvent("fpw:route-context-ready"));
  });
  await expect(page.locator("[data-fpw-route-generator-tour-layer]")).toHaveCount(0);
  await page.evaluate(()=>{
    document.getElementById("fpwRouteGen").classList.remove("fpw-guide-mode");
    document.getElementById("routeBuilderModal").dispatchEvent(new CustomEvent("fpw:route-context-ready"));
  });
  await expect(page.locator("[data-fpw-route-generator-tour-layer]")).toHaveCount(1);
  await expect(page.locator("[data-route-tour-title]")).toHaveText("Name your route");
});

test("lost planning-draft response retries the original UUID and revision",async({page})=>{
  await setup(page,fixture([60,null]));
  await page.evaluate(()=>{
    const original=window.fetch; let cached=null;window.__draftRetries=[];
    window.fetch=async(url,options)=>{
      if(!url.includes("action=guide_savedraft")) return original(url,options);
      window.__draftRetries.push(JSON.parse(options.body));
      if(cached) return cached;
      cached=await original(url,options);
      throw new Error("Lost draft response after commit");
    };
  });
  await page.locator("[data-guide-notes]").fill("Weather delay recorded once.");
  await page.evaluate(()=>window.FPW.GuidePlanner.saveDraft());
  await expect(page.locator("[data-guide-status]")).toContainText("Lost draft response");
  const saved=await page.evaluate(()=>window.FPW.GuidePlanner.saveDraft());
  const attempts=await page.evaluate(()=>window.__draftRetries);
  expect(attempts).toHaveLength(2);
  expect(attempts[0]).toEqual(attempts[1]);
  expect(attempts[0].draft_request_id).toMatch(/^[a-f0-9-]{36}$/);
  expect(attempts[0].revision).toBe(1);
  expect(saved.revision).toBe(2);
  await expect(page.locator("[data-guide-notes]")).toHaveValue("Weather delay recorded once.");
  await expect(page.locator("#guide-mileage-2")).toHaveValue("");
});

test("entering missing mileage clears the imported missing-input explanation and requires a method",async({page})=>{
  const data=fixture([null,60]); data.legs[0].distance_method="Supply reviewed route mileage; harbor movement is missing.";
  await setup(page,data);
  await page.locator("#guide-mileage-1").fill("60");
  await expect(page.locator("#guide-method-1")).toHaveValue("");
  await expect(page.locator("#routeGenGenerateBtn")).toBeDisabled();
  await page.locator('[data-guide-review="1"]').click();
  await expect(page.locator("[data-guide-status]")).toContainText("source or calculation");
  expect(await page.evaluate(()=>window.__calls)).toHaveLength(0);
});

test("editing imported mileage clears copied attribution, saves a method-missing draft and requires fresh review",async({page})=>{
  const data=fixture([50.3,50.3]);
  const ownerMethod="Example route distance — review for your trip. Owner-supplied planning estimate; method and date unspecified.";
  data.legs.forEach(leg=>{leg.distance_kind="source_reported_estimate";leg.distance_method=ownerMethod;leg.review_status="member_confirmed";});
  data.source_snapshot={legs:data.legs.map(leg=>({key:leg.leg_key,distance_nm:50.3,distance_method:ownerMethod}))};
  await setup(page,data);
  await page.locator("#guide-mileage-1").fill("55");
  await expect(page.locator("#guide-method-1")).toHaveValue("");
  await expect(page.locator('[data-guide-leg="1"] [data-guide-distance-kind]')).toHaveText("Member-entered estimate");
  await expect(page.locator('[data-guide-leg="1"] [data-guide-review-state]')).toHaveText("Changed — member review required");
  await expect(page.locator('[data-guide-leg="1"] [data-guide-method-required]')).toBeVisible();
  await expect(page.locator("#guide-mileage-2")).toHaveValue("50.3");
  await expect(page.locator("#guide-method-2")).toHaveValue(ownerMethod);
  await expect(page.locator("#routeGenGenerateBtn")).toBeDisabled();
  await page.locator('[data-guide-review="1"]').click();
  expect(await page.evaluate(()=>window.__calls.filter(c=>c.action==="guide_savedraft"))).toHaveLength(0);
  await page.evaluate(()=>window.FPW.GuidePlanner.saveDraft());
  const saved=await page.evaluate(()=>window.__calls.find(c=>c.action==="guide_savedraft"));
  expect(saved.body.legs[0]).toMatchObject({distance_nm:55,distance_kind:"member_entered",distance_method:"",review_action:""});
  await page.evaluate(()=>window.FPW.GuidePlanner.refresh());
  await expect(page.locator("#guide-method-1")).toHaveValue("");
  await expect(page.locator('[data-guide-leg="1"] [data-guide-distance-kind]')).toHaveText("Member-entered estimate");
  await expect(page.locator("[data-guide-totals]")).toContainText("1 leg(s) still need a mileage source or calculation method");
  await page.locator("#guide-method-1").fill("Member reviewed intended path and added an allowance.");
  await page.locator('[data-guide-review="1"]').click();
  await expect(page.locator('[data-guide-leg="1"] [data-guide-review-state]')).toContainText("not independently verified");
});
test("each numeric transition clears its active method while copied references hide",async({page})=>{
  const data=fixture([50.3,50.3]);
  data.legs[0].source_ids=["S1"];
  data.source_snapshot={sources:[{id:"S1",authority:"Test source",accessed_at:"2026-11-09"}],legs:[{key:"leg-0",distance_method:data.legs[0].distance_method}]};
  await setup(page,data);
  await page.locator("#guide-method-1").fill("My replacement calculation for the changed path.");
  await page.locator("#guide-mileage-1").fill("55");
  await expect(page.locator("#guide-method-1")).toHaveValue("");
  await page.locator("#guide-method-1").fill("New calculation for 55 nm.");
  await page.locator("#guide-mileage-1").fill("56");
  await expect(page.locator("#guide-method-1")).toHaveValue("");
  await page.locator("#guide-method-1").fill("New calculation for the final 56 nm.");
  await expect(page.locator("#guide-method-1")).toHaveValue("New calculation for the final 56 nm.");
  await expect(page.locator('[data-guide-leg="1"] [data-guide-source-references]')).toBeHidden();
  await expect(page.locator('[data-guide-leg="1"] [data-guide-distance-kind]')).toHaveText("Member-entered estimate");
});
test("pasting original imported method into an edited leg cannot carry it into another distance edit",async({page})=>{
  const data=fixture([55,50.3]);
  data.legs[0].distance_kind="member_entered";
  data.legs[0].distance_method="Prior member calculation";
  data.source_snapshot={legs:[{key:"leg-0",distance_method:"Original owner estimate"}]};
  await setup(page,data);
  await page.locator("#guide-method-1").fill("Original owner estimate");
  await page.locator("#guide-mileage-1").fill("56");
  await expect(page.locator("#guide-method-1")).toHaveValue("");
});
test("unavailable template disables another copy through draft reload and save",async({page})=>{
  await setup(page,{...fixture(),can_create_another_copy:false});
  await expect(page.locator("[data-guide-another]")).toBeDisabled();
  await expect(page.locator("#guideCopyAvailability")).toContainText("draft or retired");
  await page.locator("[data-guide-reload]").click();
  await expect(page.locator("[data-guide-status]")).toHaveText("Saved planning draft reloaded.");
  await expect(page.locator("[data-guide-another]")).toBeDisabled();
  await page.evaluate(()=>window.FPW.GuidePlanner.saveDraft());
  await expect(page.locator("[data-guide-another]")).toBeDisabled();
});

