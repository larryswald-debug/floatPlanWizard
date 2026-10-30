const { test, expect } = require("@playwright/test");
const fs = require("node:fs");
const path = require("node:path");

const baseUrl = "http://localhost:8500/fpw";
const outputDir = path.resolve("output/playwright/great-loop-shared-timeline-2026-10-29");
const cleanupUrl = `${baseUrl}/tests/onboarding-runner.cfm?confirm=RUN_DISPOSABLE_WELCOME_ONBOARDING_TESTS&reporter=json`;
let needsCleanup = false;

test.describe.configure({ mode: "serial" });
test.setTimeout(180000);

function lowerKeys(value) {
  if (Array.isArray(value)) return value.map(lowerKeys);
  if (!value || typeof value !== "object") return value;
  return Object.fromEntries(Object.entries(value).map(([key, item]) => [key.toLowerCase(), lowerKeys(item)]));
}

function calculationPayload(value) {
  const normalized = lowerKeys(value);
  const meta = { ...normalized.timeline_meta };
  // Source labels differ deliberately; compare every calculation field without rounding.
  delete meta.distance_source;
  delete meta.route_type;
  return { days: normalized.days, route_summary: normalized.route_summary, timeline_meta: meta };
}

async function routeBuilder(page, action, payload) {
  return page.evaluate(async ({ url, payload }) => {
    const response = await fetch(url, {
      method: "POST", credentials: "same-origin",
      headers: { "Content-Type": "application/json; charset=utf-8" }, body: JSON.stringify(payload)
    });
    return { status: response.status, payload: await response.json() };
  }, { url: `${baseUrl}/api/v1/routeBuilder.cfc?method=handle&action=${action}&returnFormat=json`, payload });
}

async function createDisposableMember(page) {
  const nonce = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const email = `codex-welcome-onboarding-shared-timeline-${nonce}@example.test`;
  expect((await page.goto(`${baseUrl}/app/join.cfm`, { waitUntil: "domcontentloaded" })).status()).toBe(200);
  await page.locator("#firstName").fill("Timeline");
  await page.locator("#lastName").fill("Parity");
  await page.locator("#email").fill(email);
  await page.locator("#password").fill("TimelineParity!2026");
  await page.locator("#confirmPassword").fill("TimelineParity!2026");
  await page.locator("#termsAccepted").check();
  needsCleanup = true;
  await Promise.all([
    page.waitForURL(/\/fpw\/app\/dashboard\.cfm/, { waitUntil: "domcontentloaded", timeout: 15000 }),
    page.locator("#joinButton").click()
  ]);
  needsCleanup = true;
  if (await page.locator("#welcomeOnboardingModal").isVisible()) {
    await page.locator("#welcomeOnboardingCloseBtn").click();
  }
}

test.afterAll(async ({ request }) => {
  if (!needsCleanup) return;
  const response = await request.get(cleanupUrl);
  expect(response.status()).toBe(200);
  const cleanup = lowerKeys(await response.json());
  fs.mkdirSync(outputDir, { recursive: true });
  fs.writeFileSync(path.join(outputDir, "parity-cleanup.json"), JSON.stringify({
    success: cleanup.success, cleanup: cleanup.cleanup
  }, null, 2));
  expect(cleanup.success).toBe(true);
  expect(cleanup.cleanup.success).toBe(true);
});

test("owned generator and public active-template timelines have exact calculation parity", async ({ page, request }) => {
  fs.mkdirSync(outputDir, { recursive: true });
  const pageErrors = [];
  page.on("pageerror", error => pageErrors.push(error.message));
  await page.setViewportSize({ width: 1440, height: 1000 });
  await createDisposableMember(page);

  const optionResponse = await routeBuilder(page, "routegen_getoptions", {});
  const options = lowerKeys(optionResponse.payload);
  expect(options.success, JSON.stringify(options)).toBe(true);
  const defaults = {
    pace: "AGGRESSIVE", cruising_speed: 10, fuel_burn_gph: 4,
    underway_hours_per_day: 6.5, weather_factor_pct: 0,
    reserve_pct: 33, reserve_mode: "thirds"
  };
  const generateInput = {
    ...defaults, route_type: "generated",
    route_name: `codex-welcome-onboarding-shared-timeline-${Date.now()}`,
    template_code: options.data.template.code, direction: "CCW",
    start_segment_id: String(options.data.startoptions[0].segment_id),
    end_segment_id: String(options.data.endoptions[1].segment_id),
    start_date: "2026-10-29", fuel_burn_gph_input: "4", fuel_burn_basis: "MAX_SPEED",
    optional_stop_flags: [], leg_override_drafts: {}
  };
  let routeCode = "";
  let screenshotRouteId = 0;
  const evidence = { comparisons: [], screenshots: [], noSharedTemplateWrites: true };
  try {
    const generated = lowerKeys((await routeBuilder(page, "routegen_generate", generateInput)).payload);
    expect(generated.success, JSON.stringify(generated)).toBe(true);
    routeCode = generated.data.route_code;
    const routeId = generated.data.route_id;
    expect(routeCode).toBeTruthy();
    expect(routeId).toBeGreaterThan(0);

    const editContext = lowerKeys((await routeBuilder(page, "routegen_geteditcontext", { route_code: routeCode })).payload);
    expect(editContext.success).toBe(true);
    // This disposable member deliberately has no vessel defaults to alter explicit fixture inputs.
    expect(Number(editContext.data.inputs.vessel_most_efficient_speed_kn || 0)).toBe(0);
    expect(Number(editContext.data.inputs.vessel_gph_at_most_efficient_speed || 0)).toBe(0);

    const scenarios = [
      { name: "thirds-base", inputs: defaults },
      { name: "percentage-weather-short-days", inputs: { ...defaults, reserve_pct: 20, reserve_mode: "percentage", weather_factor_pct: 20, underway_hours_per_day: 4 } },
      { name: "minimum-reserve-weather", inputs: { ...defaults, reserve_pct: 15, reserve_mode: "percentage", weather_factor_pct: 10 } },
      { name: "anchored-vessel-performance", inputs: { ...defaults, pace: "BALANCED", vessel_max_speed_kn: 10, vessel_most_efficient_speed_kn: 6, vessel_gph_at_most_efficient_speed: 2, weather_factor_pct: 15 } }
    ];
    for (const scenario of scenarios) {
      const publicResponse = await request.post(`${baseUrl}/fpw_great_loop_clockwise/timeline.cfm`, {
        data: { action: "timeline", startDate: "2026-10-29", inputs: scenario.inputs }
      });
      expect(publicResponse.status()).toBe(200);
      const publicResult = lowerKeys(await publicResponse.json());
      expect(publicResult.success).toBe(true);
      expect(publicResult.template_code).toBe(generateInput.template_code);
      expect(publicResult.legs.length).toBeGreaterThan(0);
      const generator = lowerKeys((await routeBuilder(page, "generateCruiseTimeline", {
        routeId, routeType: "generated", startDate: "2026-10-29",
        maxHoursPerDay: scenario.inputs.underway_hours_per_day,
        inputOverrides: scenario.inputs, previewLegs: publicResult.legs
      })).payload);
      expect(generator.success, JSON.stringify(generator)).toBe(true);
      expect(calculationPayload(generator)).toEqual(calculationPayload(publicResult.timeline));
      expect(generator.timeline_meta.distance_source).toBe("preview_legs");
      expect(publicResult.timeline.timeline_meta.distance_source).toBe("active_template");
      evidence.comparisons.push({ name: scenario.name, exactCalculationParity: true,
        legs: publicResult.legs.length, days: generator.days.length,
        summary: generator.route_summary, riskColors: [...new Set(generator.days.map(day => day.risk_color))] });
    }

    const coreResponse = await request.get(`${baseUrl}/tests/great-loop-timeline-core-runner.cfm?confirm=RUN_GREAT_LOOP_TIMELINE_CORE_TESTS`);
    expect(coreResponse.status()).toBe(200);
    const core = lowerKeys(await coreResponse.json());
    expect(core.success).toBe(true);
    const fixtureLegs = [40, 45].map((distance, index) => ({
      id: index + 1, route_leg_id: index + 1, segment_id: index + 1, order_index: index + 1,
      start_name: `Port ${index + 1}`, end_name: `Port ${index + 2}`,
      dist_nm: distance, base_dist_nm: 100, geometry_dist_nm: 75, generated_dist_nm: 90,
      lock_count: index === 0 ? 2 : 1, lock_time_min_total: index === 0 ? 60 : 30,
      is_offshore: 0, is_icw: 1, exposure_level: 0
    }));
    const fixtureResult = lowerKeys((await routeBuilder(page, "generateCruiseTimeline", {
      routeId, routeType: "generated", startDate: "2026-10-29", maxHoursPerDay: 6.5,
      inputOverrides: defaults, previewLegs: fixtureLegs
    })).payload);
    expect(fixtureResult.success).toBe(true);
    expect(calculationPayload(fixtureResult)).toEqual(calculationPayload(core.fixture));
    expect(fixtureResult.route_summary.total_nm).toBe(85);
    expect(fixtureResult.days[0].segment_slices.length).toBe(2);
    expect(fixtureResult.days[0].lock_count).toBe(3);
    expect(fixtureResult.days[1].lock_count).toBe(0);
    expect(fixtureResult.days[0].segment_slices[0].segment_cruising_hours).toBe(4);
    expect(fixtureResult.days[0].segment_slices[0].segment_hours).toBe(5);
    evidence.comparisons.push({ name: "effective-distance-override-and-multileg-day-split",
      exactCalculationParity: true, source: "guarded deterministic shared-core fixture vs authenticated generator API",
      effectiveDistances: [40, 45], unrelatedBaseDistanceEach: 100,
      summary: fixtureResult.route_summary, dayLockCounts: fixtureResult.days.map(day => day.lock_count) });

    // Template controls are intentionally server-hidden in the current generator. Use
    // its supported saved My Route path for the actual UI/renderer regression check.
    const screenshotRoute = lowerKeys((await routeBuilder(page, "createuserroute", {
      route_name: "codex-welcome-onboarding-shared-timeline-visual"
    })).payload);
    expect(screenshotRoute.success).toBe(true);
    screenshotRouteId = screenshotRoute.data.route_id;
    const waypoints = await page.evaluate(async () => {
      const results = [];
      for (const [name, latitude, longitude] of [["Timeline Start", "27.9506", "-82.4572"], ["Timeline End", "27.9770", "-82.8270"]]) {
        results.push(await window.Api.saveWaypoint({ waypoint: {
          WAYPOINTID: 0, WAYPOINTNAME: name, LATITUDE: latitude, LONGITUDE: longitude, NOTES: ""
        } }));
      }
      return { results, list: await window.Api.getWaypoints({ limit: 100 }) };
    });
    expect(waypoints.results.every(result => lowerKeys(result).success)).toBe(true);
    const waypointList = lowerKeys(waypoints.list).waypoints;
    const startId = Number(waypointList.find(item => item.waypointname === "Timeline Start").waypointid);
    const endId = Number(waypointList.find(item => item.waypointname === "Timeline End").waypointid);
    expect(lowerKeys((await routeBuilder(page, "setuserroutestartwaypoint", {
      route_id: screenshotRouteId, start_waypoint_id: startId
    })).payload).success).toBe(true);
    expect(lowerKeys((await routeBuilder(page, "addwaypointlegtouserroute", {
      route_id: screenshotRouteId, end_waypoint_id: endId
    })).payload).success).toBe(true);
    const vessel = await page.evaluate(async () => window.Api.saveVessel({ vessel: {
      VESSELID: 0, VESSELNAME: "Shared Timeline Visual Vessel", TYPE: "Power", LENGTH: "24",
      MAX_SPEED: "10", MOST_EFFICIENT_SPEED: "10", GALLONS_PER_HOUR: "4", GPH_AT_MAX_SPEED: "4",
      FUEL_CAPACITY: "60", ISDEFAULTVESSEL: 1, MAKE: "Test", MODEL: "Timeline",
      REGISTRATION: "", COLOR: "White", HOMEPORT: ""
    } }));
    expect(lowerKeys(vessel).success).toBe(true);
    await page.waitForFunction(() => window.FPW?.DashboardModules?.routeBuilder?.openSavedRoute);
    await page.evaluate(id => window.FPW.DashboardModules.routeBuilder.openSavedRoute(id), screenshotRouteId);
    await expect(page.locator("#routeBuilderModal")).toBeVisible();
    const closeTour = page.getByRole("button", { name: "Close route generator tour", exact: true });
    await expect(closeTour).toBeVisible();
    await closeTour.click();
    await expect(closeTour).toBeHidden();
    const firstLeg = page.locator('.fpw-routegen__leg[data-leg-order="1"]');
    await expect(firstLeg).toBeVisible({ timeout: 15000 });
    await firstLeg.click();
    await expect(page.locator(".fpw-routegen__leglockpanel")).toBeVisible();
    await expect(page.locator("#routeBuilderModal")).toContainText(/Cruise Timeline/i);
    for (const width of [1440, 390]) {
      await page.setViewportSize({ width, height: 1000 });
      await page.locator(".fpw-routegen__leglockpanel").scrollIntoViewIfNeeded();
      const panelGeometry = await page.locator(".fpw-routegen__leglockpanel").evaluate(element => {
        const nodes = [];
        for (let node = element; node && nodes.length < 8; node = node.parentElement) {
          const rect = node.getBoundingClientRect();
          const style = getComputedStyle(node);
          nodes.push({ tag: node.tagName, id: node.id, className: node.className,
            x: rect.x, y: rect.y, width: rect.width, height: rect.height,
            scrollLeft: node.scrollLeft, scrollTop: node.scrollTop,
            overflowX: style.overflowX, overflowY: style.overflowY });
        }
        return nodes;
      });
      if (!evidence.generatorGeometry) evidence.generatorGeometry = {};
      evidence.generatorGeometry[width] = panelGeometry;
      const screenshot = `generator-${width}.png`;
      await page.waitForTimeout(100);
      await page.screenshot({ path: path.join(outputDir, screenshot), fullPage: false });
      evidence.screenshots.push(screenshot);
      if (width === 390) {
        await expect(page.locator(".fpw-routegen__legtimeline .card").first()).toBeVisible({ timeout: 5000 });
        await page.locator(".fpw-routegen__legtimeline .card").first().scrollIntoViewIfNeeded({ timeout: 5000 });
        await page.waitForTimeout(100);
        await page.screenshot({ path: path.join(outputDir, "generator-390-days.png"), fullPage: false });
        evidence.screenshots.push("generator-390-days.png");
      }
    }
    expect(pageErrors).toEqual([]);
    evidence.pageErrors = pageErrors;
  } finally {
    if (routeCode) {
      const deleted = lowerKeys((await routeBuilder(page, "deleteroute", { routeCode })).payload);
      expect(deleted.success, JSON.stringify(deleted)).toBe(true);
      evidence.disposableRouteDeleted = true;
    }
    if (screenshotRouteId) {
      const deleted = lowerKeys((await routeBuilder(page, "deleteuserroute", { route_id: screenshotRouteId })).payload);
      expect(deleted.success, JSON.stringify(deleted)).toBe(true);
      evidence.disposableVisualRouteDeleted = true;
    }
    evidence.pageErrors = pageErrors;
    fs.writeFileSync(path.join(outputDir, "parity-evidence.json"), JSON.stringify(evidence, null, 2));
  }
});
