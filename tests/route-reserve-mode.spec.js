const { test, expect } = require("@playwright/test");
const fs = require("node:fs");

const baseUrl = "http://localhost:8500/fpw";
const legacyCalculatorUrls = [
  `${baseUrl}/app/fuel-calculator.cfm`,
  `${baseUrl}/assets/app/fuel-calculator.cfm`,
  `${baseUrl}/api/app/fuel-calculator.cfm`
];
const onboardingCleanupUrl = `${baseUrl}/tests/onboarding-runner.cfm`
  + "?confirm=RUN_DISPOSABLE_WELCOME_ONBOARDING_TESTS&reporter=json";
const disposablePassword = "ReserveMode!2026";
let needsOnboardingCleanup = false;

test.describe.configure({ mode: "serial" });

function collectPageErrors(page) {
  const errors = [];
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(`console: ${message.text()}`);
  });
  page.on("pageerror", (error) => errors.push(`pageerror: ${error.message}`));
  return errors;
}

async function openLegacyCalculator(page, url = legacyCalculatorUrls[0]) {
  const response = await page.goto(url, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);
  await expect(page.locator("#qaFuelCalcForm")).toBeVisible();
}

async function enterBaseFuelScenario(page, baseFuel) {
  await page.locator("#totalNm").fill(String(baseFuel));
  await page.locator("#pace").selectOption("BALANCED");
  await page.locator("#mostEfficientSpeedKn").fill("10");
  await page.locator("#fuelBurnEfficientGph").fill("10");
}

async function readResult(page) {
  return JSON.parse(await page.locator("#calcJsonOut").textContent());
}

function valueFrom(source, ...keys) {
  for (const key of keys) {
    if (source && source[key] !== undefined) return source[key];
  }
  return undefined;
}

async function createDisposableMember(page) {
  const nonce = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const email = `codex-welcome-onboarding-reserve-mode-${nonce}@example.test`;
  const response = await page.goto(`${baseUrl}/app/join.cfm`, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);
  await page.locator("#firstName").fill("Reserve");
  await page.locator("#lastName").fill("Mode");
  await page.locator("#email").fill(email);
  await page.locator("#password").fill(disposablePassword);
  await page.locator("#confirmPassword").fill(disposablePassword);
  await page.locator("#termsAccepted").check();
  await Promise.all([
    page.waitForURL(/\/fpw\/app\/dashboard\.cfm/),
    page.locator("#joinButton").click()
  ]);
  needsOnboardingCleanup = true;
  if (await page.locator("#welcomeOnboardingModal").isVisible()) {
    await page.locator("#welcomeOnboardingCloseBtn").click();
  }
  return email;
}

async function callRouteBuilder(page, action, body) {
  return page.evaluate(async ({ apiUrl, payload }) => {
    const response = await fetch(apiUrl, {
      method: "POST",
      credentials: "same-origin",
      headers: { "Content-Type": "application/json; charset=utf-8" },
      body: JSON.stringify(payload)
    });
    return {
      status: response.status,
      payload: await response.json()
    };
  }, {
    apiUrl: `${baseUrl}/api/v1/routeBuilder.cfc?method=handle&action=${encodeURIComponent(action)}&returnFormat=json`,
    payload: body
  });
}

test.afterAll(async ({ request }) => {
  if (!needsOnboardingCleanup) return;
  const response = await request.get(onboardingCleanupUrl);
  expect(response.status()).toBe(200);
  const payload = await response.json();
  expect(payload.SUCCESS).toBe(true);
  expect(payload.CLEANUP && payload.CLEANUP.SUCCESS).toBe(true);
});

test("legacy calculator uses One-Third Rule while preserving 20 and 15 percent modes", async ({ page }) => {
  const pageErrors = collectPageErrors(page);
  await openLegacyCalculator(page);
  await enterBaseFuelScenario(page, 24);

  const reserveSelect = page.locator("#reservePct");
  await expect(page.locator('label[for="reservePct"]')).toHaveText("Reserve Method");
  await expect(reserveSelect.locator("option:checked")).toHaveText("One-Third Rule");
  await expect(reserveSelect.locator("option:checked")).toHaveAttribute("data-reserve-mode", "thirds");
  await expect(page.locator("#cardEstimatedFuel")).toHaveText("36.0 gal");
  await expect(page.locator("#cardEstimatedFuelSub")).toHaveText("Base 24.0 + One-Third Rule Reserve 12.0");
  await expect(page.locator("#calcBreakdownBody")).toContainText("One-Third Rule Reserve (gal)");

  let result = await readResult(page);
  expect(result.standalone_inputs.reservePct).toBe(33);
  expect(result.standalone_inputs.reserveMode).toBe("thirds");
  expect(result.derived.baseFuelGallons).toBe(24);
  expect(result.derived.reserveGallons).toBe(12);
  expect(result.derived.requiredFuelGallons).toBe(36);

  await reserveSelect.selectOption("20");
  result = await readResult(page);
  expect(result.standalone_inputs.reserveMode).toBe("percentage");
  expect(result.derived.reserveGallons).toBe(4.8);
  expect(result.derived.requiredFuelGallons).toBe(28.8);
  await expect(page.locator("#cardEstimatedFuelSub")).toHaveText("Base 24.0 + Reserve (20%) 4.8");

  await reserveSelect.selectOption("15");
  result = await readResult(page);
  expect(result.standalone_inputs.reserveMode).toBe("percentage");
  expect(result.derived.reserveGallons).toBe(3.6);
  expect(result.derived.requiredFuelGallons).toBe(27.6);
  await expect(page.locator("#cardEstimatedFuelSub")).toHaveText("Base 24.0 + Reserve (15%) 3.6");
  expect(pageErrors).toEqual([]);
});

test("tracked legacy calculator copies expose the same reserve selector contract", async ({ page }) => {
  await openLegacyCalculator(page);
  const renderedOptions = await page.locator("#reservePct option").evaluateAll((nodes) => nodes.map((node) => ({
    value: node.value,
    mode: node.getAttribute("data-reserve-mode"),
    text: node.textContent.trim()
  })));
  expect(renderedOptions).toEqual([
    { value: "33", mode: "thirds", text: "One-Third Rule" },
    { value: "20", mode: "percentage", text: "Standard Reserve - 20%" },
    { value: "15", mode: "percentage", text: "Minimum Reserve - 15%" }
  ]);

  for (const relativePath of [
    "app/fuel-calculator.cfm",
    "assets/app/fuel-calculator.cfm",
    "api/app/fuel-calculator.cfm"
  ]) {
    const source = fs.readFileSync(relativePath, "utf8");
    expect(source).toContain('<option value="33" data-reserve-mode="thirds" selected>One-Third Rule</option>');
    expect(source).toContain('<option value="20" data-reserve-mode="percentage">Standard Reserve - 20%</option>');
    expect(source).toContain('<option value="15" data-reserve-mode="percentage">Minimum Reserve - 15%</option>');
  }
});

test("preview, generate, update, and edit context preserve explicit reserve mode", async ({ page }) => {
  const pageErrors = collectPageErrors(page);
  await page.addInitScript(() => {
    window.__FPW_ENABLE_TEST_HOOKS = true;
  });
  const email = await createDisposableMember(page);
  const vesselResult = await page.evaluate(async () => window.Api.saveVessel({
    vessel: {
      VESSELID: 0,
      VESSELNAME: "Reserve Mode Test Vessel",
      REGISTRATION: "",
      TYPE: "Power",
      LENGTH: "24",
      MAX_SPEED: "10",
      MOST_EFFICIENT_SPEED: "10",
      GALLONS_PER_HOUR: "10",
      GPH_AT_MAX_SPEED: "10",
      FUEL_CAPACITY: "60",
      ISDEFAULTVESSEL: 1,
      MAKE: "Test",
      MODEL: "Reserve Mode",
      COLOR: "White",
      HOMEPORT: ""
    }
  }));
  expect(vesselResult && vesselResult.SUCCESS).toBe(true);

  await page.waitForFunction(() => (
    window.FPW
    && window.FPW.DashboardModules
    && window.FPW.DashboardModules.routeBuilder
    && window.FPW.DashboardModules.routeBuilder.test
    && typeof window.FPW.DashboardModules.routeBuilder.test.roundTripReserveDraft === "function"
  ));
  const draftContract = await page.evaluate(() => (
    window.FPW.DashboardModules.routeBuilder.test.roundTripReserveDraft(33, "percentage")
  ));
  expect(draftContract.saved.reserve_pct).toBe("33");
  expect(draftContract.saved.reserve_mode).toBe("percentage");
  expect(draftContract.restored).toEqual({ reserve_pct: "33", reserve_mode: "percentage" });
  const legacyDraftRestore = await page.evaluate(() => (
    window.FPW.DashboardModules.routeBuilder.test.applyReserveDraft({ reserve_pct: 33 })
  ));
  expect(legacyDraftRestore).toEqual({ reserve_pct: "33", reserve_mode: "thirds" });

  const optionsResponse = await callRouteBuilder(page, "routegen_getoptions", {});
  expect(optionsResponse.status).toBe(200);
  expect(optionsResponse.payload.SUCCESS).toBe(true);
  const optionsData = valueFrom(optionsResponse.payload, "DATA", "data");
  const template = valueFrom(optionsData, "template", "TEMPLATE");
  const startOptions = valueFrom(optionsData, "startOptions", "STARTOPTIONS");
  const endOptions = valueFrom(optionsData, "endOptions", "ENDOPTIONS");
  expect(Array.isArray(startOptions) && startOptions.length > 0).toBe(true);
  expect(Array.isArray(endOptions) && endOptions.length > 0).toBe(true);

  const endIndex = endOptions.length > 1 ? 1 : 0;
  const routeName = `codex-welcome-onboarding-reserve-mode-${Date.now()}`;
  const payload = {
    route_type: "generated",
    route_name: routeName,
    template_code: valueFrom(template, "code", "CODE"),
    direction: "CCW",
    start_segment_id: String(valueFrom(startOptions[0], "segment_id", "SEGMENT_ID")),
    end_segment_id: String(valueFrom(endOptions[endIndex], "segment_id", "SEGMENT_ID")),
    start_date: "2026-08-15",
    pace: "AGGRESSIVE",
    cruising_speed: "10",
    effective_cruising_speed: "10",
    underway_hours_per_day: "6.5",
    fuel_burn_gph: "10",
    fuel_burn_gph_input: "10",
    fuel_burn_basis: "MAX_SPEED",
    idle_burn_gph: "",
    idle_hours_total: "",
    weather_factor_pct: "0",
    reserve_pct: "33",
    reserve_mode: "percentage",
    fuel_price_per_gal: "",
    vessel_max_speed_kn: "10",
    vessel_most_efficient_speed_kn: "10",
    vessel_gph_at_most_efficient_speed: "10",
    optional_stop_flags: [],
    leg_override_drafts: {}
  };
  let routeCode = "";

  try {
    const previewResponse = await callRouteBuilder(page, "routegen_preview", payload);
    expect(previewResponse.status).toBe(200);
    expect(previewResponse.payload.SUCCESS).toBe(true);
    const previewData = valueFrom(previewResponse.payload, "DATA", "data");
    const previewInputs = valueFrom(previewData, "inputs", "INPUTS");
    const previewTotals = valueFrom(previewData, "totals", "TOTALS");
    expect(valueFrom(previewInputs, "reserve_pct", "RESERVE_PCT")).toBe(33);
    expect(valueFrom(previewInputs, "reserve_mode", "RESERVE_MODE")).toBe("percentage");
    expect(valueFrom(previewTotals, "reserve_mode", "RESERVE_MODE")).toBe("percentage");
    expect(valueFrom(previewTotals, "reserve_fuel_gallons", "RESERVE_FUEL_GALLONS")).toBeCloseTo(
      valueFrom(previewTotals, "base_fuel_gallons", "BASE_FUEL_GALLONS") * 0.33,
      2
    );

    const generateResponse = await callRouteBuilder(page, "routegen_generate", payload);
    expect(generateResponse.status).toBe(200);
    expect(generateResponse.payload.SUCCESS).toBe(true);
    const generateData = valueFrom(generateResponse.payload, "DATA", "data");
    routeCode = String(valueFrom(generateData, "route_code", "ROUTE_CODE") || "");
    expect(routeCode).not.toBe("");
    expect(valueFrom(valueFrom(generateData, "totals", "TOTALS"), "RESERVE_MODE", "reserve_mode")).toBe("percentage");

    let editResponse = await callRouteBuilder(page, "routegen_geteditcontext", { route_code: routeCode });
    expect(editResponse.payload.SUCCESS).toBe(true);
    let editData = valueFrom(editResponse.payload, "DATA", "data");
    let editInputs = valueFrom(editData, "inputs", "INPUTS");
    expect(valueFrom(editInputs, "reserve_pct", "RESERVE_PCT")).toBe(33);
    expect(valueFrom(editInputs, "reserve_mode", "RESERVE_MODE")).toBe("percentage");
    await page.evaluate((code) => {
      window.FPW.DashboardModules.routeBuilder.openEditorForRoute(code);
    }, routeCode);
    await expect(page.locator("#routeBuilderModal")).toBeVisible();
    await expect(page.locator("#routeGenReservePct option:checked")).toHaveText("Custom Reserve - 33%");
    await expect(page.locator("#routeGenReservePct option:checked")).toHaveAttribute("data-reserve-mode", "percentage");

    payload.route_code = routeCode;
    payload.reserve_mode = "thirds";
    const updateResponse = await callRouteBuilder(page, "routegen_update", payload);
    expect(updateResponse.status).toBe(200);
    expect(updateResponse.payload.SUCCESS).toBe(true);
    const updateData = valueFrom(updateResponse.payload, "DATA", "data");
    const updateTotals = valueFrom(updateData, "totals", "TOTALS");
    expect(valueFrom(updateTotals, "reserve_mode", "RESERVE_MODE")).toBe("thirds");
    expect(valueFrom(updateTotals, "reserve_fuel_gallons", "RESERVE_FUEL_GALLONS")).toBe(
      valueFrom(updateTotals, "base_fuel_gallons", "BASE_FUEL_GALLONS") * 0.5
    );

    editResponse = await callRouteBuilder(page, "routegen_geteditcontext", { route_code: routeCode });
    expect(editResponse.payload.SUCCESS).toBe(true);
    editData = valueFrom(editResponse.payload, "DATA", "data");
    editInputs = valueFrom(editData, "inputs", "INPUTS");
    expect(valueFrom(editInputs, "reserve_pct", "RESERVE_PCT")).toBe(33);
    expect(valueFrom(editInputs, "reserve_mode", "RESERVE_MODE")).toBe("thirds");

    await page.evaluate((code) => {
      window.FPW.DashboardModules.routeBuilder.openEditorForRoute(code);
    }, routeCode);
    await expect(page.locator("#routeBuilderModal")).toBeVisible();
    for (const width of [1440, 1024, 760, 390]) {
      await page.setViewportSize({ width, height: 900 });
      await page.evaluate(() => {
        document.querySelector("#routeGenAdvanced").open = true;
        window.bootstrap.Modal.getOrCreateInstance(document.querySelector("#routeBuilderModal")).show();
      });
      await expect(page.locator("#routeBuilderModal")).toBeVisible();
      const reserveSelect = page.locator("#routeGenReservePct");
      await expect(page.locator('label[for="routeGenReservePct"]')).toHaveText("Reserve Method");
      await expect(reserveSelect.locator("option:checked")).toHaveText("One-Third Rule");
      await expect(reserveSelect.locator("option:checked")).toHaveAttribute("data-reserve-mode", "thirds");
      await expect(page.locator('[aria-label="Step 13: Reserve Method"]')).toHaveAttribute("aria-describedby", "routeGenGuidance13");
      await expect(page.locator("#routeGenGuidance13")).toHaveText(
        "Select the One-Third Rule or a percentage-based fuel reserve."
      );
      await reserveSelect.click();
      await expect(reserveSelect).toBeFocused();
      const reserveGeometry = await reserveSelect.evaluate((element) => {
        const rect = element.getBoundingClientRect();
        return { left: rect.left, right: rect.right };
      });
      expect(reserveGeometry.left).toBeGreaterThanOrEqual(-1);
      expect(reserveGeometry.right).toBeLessThanOrEqual(width + 1);
    }
  } finally {
    if (routeCode) {
      const deleteResponse = await callRouteBuilder(page, "deleteroute", { routeCode });
      expect(deleteResponse.payload.SUCCESS).toBe(true);
    }
  }

  expect(email).toContain("codex-welcome-onboarding-reserve-mode-");
  expect(pageErrors).toEqual([]);
});

test("Follow renders mode-aware reserve wording without responsive overflow", async ({ page }) => {
  const pageErrors = collectPageErrors(page);
  let reserveMode = "thirds";
  let reservePct = 33;
  let reserveEstimate = 12;

  await page.route("**/api/v1/voyage.cfc?**", async (route) => {
    const url = new URL(route.request().url());
    const action = String(url.searchParams.get("action") || "").toLowerCase();
    if (action === "listposts") {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ SUCCESS: true, posts: [] }) });
      return;
    }
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        SUCCESS: true,
        stream: { id: 99001, slug: "reserve-mode-test", title: "Reserve Mode Test", status: "PLANNED", is_owner: false },
        topCards: {},
        pinned: {},
        body: {},
        map: {},
        timeline: {
          summary: {
            total_nm: 24,
            total_hours: 2.4,
            effective_speed_kn: 10,
            fuel_est: 24,
            reserve_est: reserveEstimate,
            required_fuel_est: 24 + reserveEstimate,
            reserve_pct: reservePct,
            reserve_mode: reserveMode,
            completed_legs: 0
          },
          legs: []
        }
      })
    });
  });

  let response = await page.goto(`${baseUrl}/app/follow.cfm?slug=reserve-mode-test`, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);
  const fuelCard = page.locator('[data-fpw-field="timeline-fuel-reserve"]');
  await expect(fuelCard.locator(".kicker")).toHaveText("Fuel + One-Third Rule reserve");
  await expect(fuelCard.locator("strong")).toHaveText("24.0 + 12.0 gal");

  for (const width of [1440, 1024, 760, 390]) {
    await page.setViewportSize({ width, height: 900 });
    const geometry = await fuelCard.evaluate((element) => {
      const cardRect = element.getBoundingClientRect();
      const kickerRect = element.querySelector(".kicker").getBoundingClientRect();
      return {
        cardLeft: cardRect.left,
        cardRight: cardRect.right,
        kickerLeft: kickerRect.left,
        kickerRight: kickerRect.right,
        kickerHeight: kickerRect.height
      };
    });
    expect(geometry.cardLeft).toBeGreaterThanOrEqual(-1);
    expect(geometry.cardRight).toBeLessThanOrEqual(width + 1);
    expect(geometry.kickerLeft).toBeGreaterThanOrEqual(geometry.cardLeft - 1);
    expect(geometry.kickerRight).toBeLessThanOrEqual(geometry.cardRight + 1);
    expect(geometry.kickerHeight).toBeGreaterThan(0);
  }

  reserveMode = "percentage";
  reservePct = 20;
  reserveEstimate = 4.8;
  response = await page.reload({ waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);
  await expect(fuelCard.locator(".kicker")).toHaveText("Fuel + 20% reserve");
  await expect(fuelCard.locator("strong")).toHaveText("24.0 + 4.8 gal");

  reserveMode = undefined;
  reservePct = undefined;
  reserveEstimate = 12;
  response = await page.reload({ waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);
  await expect(fuelCard.locator(".kicker")).toHaveText("Fuel + One-Third Rule reserve");
  expect(pageErrors).toEqual([]);
});

for (const width of [1440, 1024, 760, 390]) {
  test(`Reserve Method remains readable and accessible at ${width}px`, async ({ page }) => {
    const pageErrors = collectPageErrors(page);
    await page.setViewportSize({ width, height: 900 });
    await openLegacyCalculator(page);
    await enterBaseFuelScenario(page, 24);

    const reserveSelect = page.locator("#reservePct");
    await expect(reserveSelect).toBeVisible();
    await expect(page.locator('label[for="reservePct"]')).toBeVisible();
    await reserveSelect.focus();
    await expect(reserveSelect).toBeFocused();
    await expect(page.locator("#cardEstimatedFuelSub")).toBeVisible();

    const geometry = await page.evaluate(() => ({
      reserveRight: document.querySelector("#reservePct").getBoundingClientRect().right,
      resultRight: document.querySelector("#cardEstimatedFuelSub").getBoundingClientRect().right
    }));
    expect(geometry.reserveRight).toBeLessThanOrEqual(width + 1);
    expect(geometry.resultRight).toBeLessThanOrEqual(width + 1);
    expect(pageErrors).toEqual([]);
  });
}
