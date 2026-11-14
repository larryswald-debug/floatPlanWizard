const { test, expect } = require("@playwright/test");
const BASE = "http://localhost:8500/fpw";
test.skip(process.env.FPW_GUIDE_LIVE !== "1", "Requires explicit local fixture authorization.");
test("saved guide preview adapters retain schematic metadata and explicit estimates in Follow and Captain views", async ({ page, context }, testInfo) => {
  test.setTimeout(90000);
  // The local runner is not an authentication shortcut. Reuse a normal login's
  // private browser state, or log in through the public auth API with test-only env.
  const authState = process.env.FPW_GUIDE_AUTH_STATE;
  if (authState) {
    const state = JSON.parse(require("node:fs").readFileSync(authState, "utf8"));
    await context.addCookies(state.cookies);
  }
  let bootstrap = await context.request.get(BASE + "/api/v1/auth.cfc?method=bootstrap&returnFormat=json").then(r=>r.json());
  if (!authState) {
    expect(process.env.FPW_GUIDE_TEST_EMAIL, "Set private auth state or disposable test credentials").toBeTruthy();
    expect(process.env.FPW_GUIDE_TEST_PASSWORD, "Set disposable test credentials").toBeTruthy();
    const login = await context.request.post(BASE + "/api/v1/auth.cfc?method=handle&returnFormat=json", {
      headers:{"Origin":"http://localhost:8500","X-CSRF-Token":bootstrap.CSRF_TOKEN},
      data:{action:"login",email:process.env.FPW_GUIDE_TEST_EMAIL,password:process.env.FPW_GUIDE_TEST_PASSWORD}
    }).then(r=>r.json());
    expect(login.SUCCESS).toBe(true);
    bootstrap = await context.request.get(BASE + "/api/v1/auth.cfc?method=bootstrap&returnFormat=json").then(r=>r.json());
  }
  const me = await context.request.get(BASE + "/api/v1/me.cfc?method=handle&returnFormat=json").then(r=>r.json());
  expect(me.USER, "A normal authenticated session is required").toBeTruthy();
  const setup = await context.request.post(BASE + "/tests/guide-trip-ui-fixture.cfm?confirm=LOCAL_GUIDE_UI_FIXTURE",{
    headers:{"Origin":"http://localhost:8500","X-CSRF-Token":bootstrap.CSRF_TOKEN}
  });
  expect(setup.ok()).toBe(true);
  const result = await setup.json();
  expect(result.SUCCESS).toBe(true);
  const f = result.FIXTURE || result.fixture;
  const plan = f.FLOATPLAN || f.floatplan;
  const data = plan.DATA || plan.data || plan;
  const ids = data.FLOATPLAN_IDS || data.floatplan_ids || data.FLOATPLANIDS || data.floatPlanIds;
  const id = data.FLOATPLANID || data.floatplan_id || data.floatPlanId || (ids && ids[0]);
  expect(id, JSON.stringify(plan)).toBeTruthy();
  await page.goto(BASE + "/app/follow.cfm?mode=preview&floatPlanId=" + id);
  await expect(page.locator("body")).not.toHaveClass(/follow-loading/, { timeout: 20000 });
  const preview = await page.locator("#followPageContext").textContent().then(JSON.parse);
  expect(preview.previewBootstrap.SUCCESS).toBe(true);
  expect(preview.previewBootstrap.map.routeGeo.guide_estimates).toBe(true);
  expect(preview.previewBootstrap.map.routeGeo.guide_geometry_sources).toEqual(["schematic", "schematic"]);
  expect(Number(preview.previewBootstrap.timeline.summary.fuel_est)).toBe(108);
  expect(Number(preview.previewBootstrap.timeline.summary.required_fuel_est)).toBeCloseTo(129.6);
  await expect(page.locator(".leaflet-control").filter({hasText:"Planning estimates. Dashed"})).toContainText("Planning estimates");
  const lineStyles = await page.evaluate(() => {
    const lines=[]; window.FPWFollowMap.initFollowMap("followMap").eachLayer(layer => { if (layer instanceof window.L.Polyline) lines.push(layer.options.dashArray); }); return lines;
  });
  expect(lineStyles).toEqual(["8 7", "8 7"]);
  await page.screenshot({path:testInfo.outputPath("follow-guide-preview.png"),fullPage:true});
  await expect(page.locator('[data-fpw-field="trip-summary-distance"]')).toHaveText("120.0 nm estimated");
  await expect(page.locator('[data-fpw-field="timeline-eff-speed"]')).toContainText("20.0 kn");
  await expect(page.locator('[data-fpw-field="timeline-fuel-reserve"]')).toContainText("129.6 US gal estimated requirement");
  await page.locator(".follow-timeline-leg").first().click();
  await expect(page.locator(".follow-timeline-legpanel").first()).toContainText("54.0 US gal");
  await page.goto(BASE + "/app/active-cruise.cfm?mode=preview&floatPlanId=" + id);
  await expect(page.locator("[data-guide-estimate-summary]")).toContainText("108.0 US gal");
  await expect(page.locator("[data-guide-estimate-summary]")).toContainText("129.6 US gal");
  await expect(page.locator("[data-guide-estimate-summary]")).toContainText("20.0 kn");
  await expect(page.locator(".leaflet-control").filter({hasText:"Planning estimates. Dashed"})).toContainText("Planning estimates");
  await expect(page.locator('[data-selected-leg-field="totalFuel"]')).toHaveText("108.0 US gal");
  await expect(page.locator('[data-selected-leg-field="fuelReserve"]')).toHaveText("129.6 US gal");
  await page.screenshot({path:testInfo.outputPath("captain-guide-preview.png"),fullPage:true});
  const fullMap = page.locator("#fpwActiveCruiseV2OpenFullMapBtn");
  await expect(fullMap).toBeEnabled();
  {
    await page.evaluate(() => { window.__fullMapStyles=[]; const original=window.L.geoJSON; window.L.geoJSON=function(data,opts){window.__fullMapStyles.push(opts.style);return original.apply(this,arguments);}; });
    await fullMap.click();
    await expect(page.locator("#fpwActiveCruiseV2FullMapModal")).toBeVisible();
    await expect.poll(async () => (await page.evaluate(()=>window.__fullMapStyles)).map(style=>style.dashArray)).toEqual(["8 7","8 7"]);
    await expect(page.locator(".follow-guide-map-legend")).toContainText("Planning estimates");
  }
});
