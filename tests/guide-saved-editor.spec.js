const { test, expect } = require("@playwright/test");
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname,"..");
let bootstrapCss;
test.beforeAll(async({request})=>{
  const response=await request.get("https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css");
  expect(response.ok()).toBe(true);bootstrapCss=await response.text();
});
function markup(){
  return fs.readFileSync(path.join(root,"includes/modals/route_generator_modal.cfm"),"utf8")
    .replace(/<!---[\s\S]*?--->/g,"").replace(/<cfprocessingdirective[^>]*>/g,"")
    .replace(/<link[^\n]+\n/g,"").replace(/<script>[\s\S]*?<\/script>/g,"");
}
async function boot(page){
  await page.setContent('<body class="dashboard-body"><div class="expedition-route-card" data-route-code="USER_ROUTE_10671_261107150708_9efb4"><button id="guideEditorOpener" class="js-expedition-view-edit">Edit Route</button></div><button id="unrelatedAction">Other action</button><div class="modal" id="routeBuilderModal"><div class="modal-dialog modal-dialog-scrollable routebuilder-modal-fullwidth"><div class="modal-content dashboard-card"><div class="modal-body card-body routebuilder-modal-body p-0">'+markup()+'</div></div></div></div></body>');
  await page.addStyleTag({content:bootstrapCss});
  for(const css of ["app.css","layout.css","top-nav.css","dashboard-console.css","cruise-timeline.css","guide-planner.css"]) await page.addStyleTag({path:path.join(root,"assets/css",css)});
  await page.evaluate(()=>{
    const legs=[{user_route_leg_id:101,order_index:1,leg_key:"outbound",start_name:"Port Everglades",end_name:"Bimini",start_waypoint_id:11,end_waypoint_id:12,distance_nm:60,distance_kind:"member_entered",distance_method:"Member reviewed route allowance",review_status:"member_confirmed",content_fingerprint:"a",geometry_kind:"schematic"},
      {user_route_leg_id:102,order_index:2,leg_key:"return",start_name:"Bimini",end_name:"Port Everglades",start_waypoint_id:12,end_waypoint_id:11,distance_nm:60,distance_kind:"member_entered",distance_method:"Member reviewed return allowance",review_status:"member_confirmed",content_fingerprint:"b",geometry_kind:"schematic"}];
    window.__editorCalls=[];
    window.__guideDraft={user_route_id:42,route_name:"Reopen guide fixture",template_key:"fort-lauderdale-bimini",template_version:1,revision:3,generated_revision:3,generated_route_instance_id:99,trip_notes:"Local days and weather notes retained.",planning_inputs:{planning_speed_kn:20,underway_burn_us_gph:18,underway_hours_per_day:6,performance_confirmed:true,start_date:"2026-12-01",reserve_mode:"percentage",reserve_pct:20,idle_burn_us_gph:0,idle_hours_total:0,usable_fuel_us_gal:190},legs};
    window.FPW={DashboardModules:{},DashboardUtils:{}};
    window.bootstrap={Modal:class{constructor(el){this.el=el;}show(){this.el.style.display="block";this.el.classList.add("show");this.el.dispatchEvent(new Event("shown.bs.modal"));}hide(){this.el.style.display="none";this.el.classList.remove("show");this.el.dispatchEvent(new Event("hidden.bs.modal"));}}};
    window.fetch=async(url,options)=>{
      const parsed=new URL(url,"https://example.test");const action=parsed.searchParams.get("action")||"me";window.__editorCalls.push(action);
      let data={SUCCESS:true,AUTH:true};
      if(action==="me") data.USER={USERID:123};
      else if(action==="routegen_geteditcontext") data.DATA={ROUTE:{ROUTE_ID:900,ROUTE_CODE:"USER_ROUTE_10671_261107150708_9efb4",ROUTE_NAME:"Reopen guide fixture"},TEMPLATE:{NAME:"Reopen guide fixture"},INPUTS:{ROUTE_TYPE:"my_route",ROUTE_ID:42},GUIDE_CONTEXT:window.__guideDraft};
      else if(action==="listUserRoutes") data.DATA={routes:[{route_id:42,route_name:"Reopen guide fixture",leg_count:2}]};
      else if(action==="listUserWaypoints") data.DATA={waypoints:[{waypoint_id:11,name:"Port Everglades",latitude:26,longitude:-80},{waypoint_id:12,name:"Bimini",latitude:25,longitude:-79}]};
      else if(action==="guide_getdraft") data.DATA=window.__guideDraft;
      else if(action==="getUserRoute") data.DATA={route:{route_id:42,route_name:"Reopen guide fixture",start_waypoint_id:11},legs:(window.__guideDraft ? window.__guideDraft.legs : legs).map(leg=>({...leg,route_id:42,route_leg_id:leg.user_route_leg_id,dist_nm:leg.distance_nm})),GUIDE_CONTEXT:window.__guideDraft};
      else data={SUCCESS:false,MESSAGE:"Unexpected generic action: "+action};
      return new Response(JSON.stringify(data),{status:200,headers:{"Content-Type":"application/json"}});
    };
  });
  for(const js of ["shared/fuel-math.js","shared/cruise-timeline-view.js","dashboard/guide-planner.js","dashboard/routebuilder.js"]) await page.addScriptTag({path:path.join(root,"assets/js/app",js)});
  await page.evaluate(()=>window.FPW.DashboardModules.routeBuilder.init());
  await page.locator("#guideEditorOpener").focus();
  return page.evaluate(()=>window.FPW.DashboardModules.routeBuilder.openEditorForRoute("USER_ROUTE_10671_261107150708_9efb4"));
}
for(const width of [390,768,1440]){
  test("saved guide editor restores owned My Route and keeps footer inside "+width+"px",async({page})=>{
    await page.setViewportSize({width,height:900});
    expect(await boot(page)).toBe(true);
    await expect(page.locator("#fpwRouteGen")).toHaveClass(/fpw-guide-mode/);
    await expect(page.locator("#routeGenRouteName")).toHaveValue("Reopen guide fixture");
    await expect(page.locator("#routeGenMyRouteSelect")).toHaveValue("42");
    await expect(page.locator("#routeGenMyRouteLegList .fpw-routegen__myrouteleg")).toHaveCount(2);
    await expect(page.locator("#guide-planning_speed_kn")).toHaveValue("20");
    await expect(page.locator("[data-guide-notes]")).toHaveValue("Local days and weather notes retained.");
    await expect(page.locator("#routeGenError")).toBeHidden();
    const calls=await page.evaluate(()=>window.__editorCalls);
    expect(calls).toContain("getUserRoute");
    expect(calls).not.toContain("routegen_getVessels");
    expect(calls).not.toContain("previewUserRoute");
    expect(calls).not.toContain("routegen_preview");
    const bounds=await page.locator(".rg-actions button").evaluateAll(buttons=>buttons.filter(b=>getComputedStyle(b).display!=="none").map(b=>({id:b.id,left:b.getBoundingClientRect().left,right:b.getBoundingClientRect().right,width:innerWidth})));
    for(const b of bounds){expect(b.left,b.id).toBeGreaterThanOrEqual(0);expect(b.right,b.id).toBeLessThanOrEqual(b.width);}
  });
}

test("guide close restores the original keyboard opener",async({page})=>{
  await boot(page);
  await page.locator("#routeGenCancelBtn").focus();
  await page.keyboard.press("Enter");
  await expect(page.locator("#routeBuilderModal")).toBeHidden();
  await expect(page.locator("#guideEditorOpener")).toBeFocused();
});
test("guide close finds the visible saved-card action after its opener was replaced",async({page})=>{
  await boot(page);
  await page.evaluate(()=>document.querySelector(".expedition-route-card").innerHTML='<button id="replacementGuideOpener" class="js-expedition-view-edit">Edit Route</button>');
  await page.locator("#routeGenCancelBtn").focus();
  await page.keyboard.press("Enter");
  await expect(page.locator("#replacementGuideOpener")).toBeFocused();
});
test("async guide hydration does not move keyboard focus",async({page})=>{
  await boot(page);
  await page.locator("#routeGenCancelBtn").click();
  await page.locator("#guideEditorOpener").focus();
  await page.evaluate(()=>{
    const original=window.fetch;
    window.fetch=async(url,options)=>{
      if(String(url).includes("action=routegen_geteditcontext")) await new Promise(resolve=>window.__releaseEdit=resolve);
      return original(url,options);
    };
    window.__pendingEdit=window.FPW.DashboardModules.routeBuilder.openEditorForRoute("USER_ROUTE_10671_261107150708_9efb4");
  });
  await expect.poll(()=>page.evaluate(()=>typeof window.__releaseEdit)).toBe("function");
  await page.locator("#routeGenRouteName").focus();
  await page.evaluate(async()=>{window.__releaseEdit();await window.__pendingEdit;});
  await expect(page.locator("#routeGenRouteName")).toBeFocused();
});
test("ordinary route modal close does not use the guide focus restoration",async({page})=>{
  await boot(page);
  await page.locator("#routeGenCancelBtn").click();
  await page.evaluate(()=>{window.__guideDraft=null;document.querySelector("#guideEditorOpener").focus();});
  await page.evaluate(()=>window.FPW.DashboardModules.routeBuilder.openEditorForRoute("USER_ROUTE_10671_261107150708_9efb4"));
  await expect(page.locator("#fpwRouteGen")).not.toHaveClass(/fpw-guide-mode/);
  await page.locator("#routeGenCancelBtn").click();
  await expect(page.locator("#guideEditorOpener")).not.toBeFocused();
});

test("guide stop mutation sends the existing CSRF token and retains guard message",async({page})=>{
  await boot(page);
  await page.evaluate(()=>{
    window.Api={getAuthCsrfToken:async()=>"fixture-guide-csrf"};
    const original=window.fetch;
    window.fetch=async(url,options)=>{
      if(String(url).includes("action=addWaypointLegToUserRoute")){
        window.__guideMutationHeaders=options.headers;
        return new Response(JSON.stringify({SUCCESS:false,AUTH:true,MESSAGE:"Guide edit could not be authorized. Refresh and try again."}),{status:403});
      }
      return original(url,options);
    };
  });
  await page.locator("#routeGenMyRouteEndWaypointSelect").selectOption("12");
  await page.locator("#routeGenMyRouteAddWaypointLegBtn").click();
  await expect(page.locator("#routeGenError")).toHaveText("Guide edit could not be authorized. Refresh and try again.");
  expect(await page.evaluate(()=>window.__guideMutationHeaders["X-CSRF-Token"])).toBe("fixture-guide-csrf");
});

test("keyboard focus exposes the complete guide notes control in a short reflow viewport",async({page})=>{
  await page.setViewportSize({width:720,height:500});
  await boot(page);
  await page.locator('[data-guide-review="102"]').focus();
  await page.keyboard.press("Tab");
  await expect(page.locator("#guide-trip-notes")).toBeFocused();
  await expect.poll(()=>page.locator("#guide-trip-notes").evaluate(e=>{
    const rect=e.getBoundingClientRect(),bounds=e.closest(".rg-body").getBoundingClientRect();
    return rect.top>=bounds.top && rect.bottom<=bounds.bottom;
  })).toBe(true);
});
test("Load saved route rereads the owned guide draft and reports success visibly",async({page})=>{
  await boot(page);
  await page.evaluate(()=>{window.Api={getAuthCsrfToken:async()=>"fixture-csrf"};});
  await page.locator("#guide-mileage-102").fill("65");
  await page.locator("#routeGenMyRouteLoadBtn").click();
  await expect(page.locator("#guide-mileage-102")).toHaveValue("60");
  await expect(page.locator("[data-guide-status]")).toHaveText("Saved planning draft reloaded.");
  await expect(page.locator("[data-guide-status]")).toBeVisible();
  expect(await page.evaluate(()=>window.__editorCalls.filter(action=>action==="getUserRoute"))).toHaveLength(2);
});
test("a failed saved guide reload keeps edits and displays the retry error",async({page})=>{
  await boot(page);
  await page.evaluate(()=>{
    window.Api={getAuthCsrfToken:async()=>"fixture-csrf"};
    const original=window.fetch;
    window.fetch=(url,options)=>String(url).includes("action=getUserRoute")
      ? Promise.resolve(new Response(JSON.stringify({SUCCESS:false,MESSAGE:"Draft unavailable; retry reload."}),{status:503}))
      : original(url,options);
  });
  await page.locator("#guide-mileage-102").fill("65");
  await page.locator("#routeGenMyRouteLoadBtn").click();
  await expect(page.locator("#guide-mileage-102")).toHaveValue("65");
  await expect(page.locator("[data-guide-status]")).toContainText("Draft unavailable; retry reload.");
  await expect(page.locator("[data-guide-status]")).toBeVisible();
  await expect(page.locator("#routeGenMyRouteLoadBtn")).toBeEnabled();
});
test("closing a reloaded planning draft restores its replaced dashboard opener",async({page})=>{
  await boot(page);
  await page.locator("#routeGenCancelBtn").click();
  await page.evaluate(()=>{
    const card=document.querySelector(".expedition-route-card");
    card.removeAttribute("data-route-code");card.setAttribute("data-planning-draft-id","42");
    card.innerHTML='<button data-open-planning-draft="42">Open planning draft</button>';
    card.querySelector("button").disabled=true; // Dashboard prevents duplicate opens before async hydration.
  });
  await page.evaluate(()=>window.FPW.DashboardModules.routeBuilder.openSavedRoute(42));
  await page.evaluate(()=>document.querySelector(".expedition-route-card").innerHTML='<button id="replacementDraftOpener" data-open-planning-draft="42">Open planning draft</button>');
  await page.locator("#routeGenCancelBtn").click();
  await expect(page.locator("#replacementDraftOpener")).toBeFocused();
});

for(const button of ["#routeGenMyRouteLoadBtn","#routeGenResetBtn","[data-guide-reload]"]){
  test(button+" reloads changed stop lists as well as guide mileage",async({page})=>{
    await boot(page);
    await page.evaluate(()=>{window.__guideDraft.legs=window.__guideDraft.legs.slice(0,1);});
    await page.locator(button).click();
    await expect(page.locator("[data-guide-leg]")).toHaveCount(1);
    await expect(page.locator("#routeGenMyRouteLegList [data-route-leg-id]")).toHaveCount(1);
    await expect(page.locator("[data-guide-status]")).toHaveText("Saved planning draft reloaded.");
  });
}
