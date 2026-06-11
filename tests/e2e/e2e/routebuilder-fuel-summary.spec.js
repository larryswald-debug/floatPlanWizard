const { test, expect } = require("@playwright/test");
const {
  assertNoConsoleErrors,
  attachConsoleErrorCollector
} = require("../support/fpwAssertions");
const {
  cleanupTrackedData,
  createCleanupState,
  postJson,
  trackId,
  trackValue
} = require("../support/fpwCleanup");
const { loginApprovedUser, openRouteBuilder } = require("../support/fpwSession");

test.describe.configure({ mode: "serial", timeout: 240000 });

const TEMPLATE_CODE = "GL_REUSE_V2";
const OPTIONAL_STOP_CODES = ["GLD_KEYS_OUTSIDE", "GLD_CHAMPLAIN_STLAW"];
const VESSEL_NAME = "Big Blue";
const sharedState = createCleanupState();

function normalizeText(value) {
  return String(value || "").replace(/\s+/g, " ").trim();
}

function formatFixed(value, decimals) {
  return Number(value || 0).toLocaleString(undefined, {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals
  });
}

function formatCurrency(value) {
  return "$" + formatFixed(value, 2);
}

function parseCurrencyNumber(value) {
  return Number(String(value || "").replace(/[^0-9.]/g, ""));
}

function roundTo1(value) {
  return Math.round(Number(value || 0) * 10) / 10;
}

function roundTo2(value) {
  return Math.round(Number(value || 0) * 100) / 100;
}

function extractTimelineDisplayTotals(payload, options = {}) {
  const source = (payload && typeof payload === "object") ? payload : {};
  const routeSummary = (source.route_summary && typeof source.route_summary === "object")
    ? source.route_summary
    : ((source.ROUTE_SUMMARY && typeof source.ROUTE_SUMMARY === "object") ? source.ROUTE_SUMMARY : {});
  const days = Array.isArray(source.days) ? source.days : (Array.isArray(source.DAYS) ? source.DAYS : []);
  const idleBurnGph = Number(options.idleBurnGph || 0);
  const idleHoursTotal = Number(options.idleHoursTotal || 0);
  const reservePct = Number(options.reservePct || 0);
  const fuelPricePerGal = Number(options.fuelPricePerGal || 0);
  const cruiseHours = roundTo2(days.reduce((sum, day) => {
    return sum + Number(day.est_hours !== undefined ? day.est_hours : day.EST_HOURS || 0);
  }, 0));
  const cruiseReserveFuel = roundTo2(days.reduce((sum, day) => {
    return sum + Number(day.reserve_gallons !== undefined ? day.reserve_gallons : day.RESERVE_GALLONS || 0);
  }, 0));
  const cruiseRequiredFuelRaw = Number(
    routeSummary.total_required_fuel !== undefined
      ? routeSummary.total_required_fuel
      : routeSummary.TOTAL_REQUIRED_FUEL
  );
  const cruiseRequiredFuel = Number.isFinite(cruiseRequiredFuelRaw)
    ? roundTo2(cruiseRequiredFuelRaw)
    : roundTo2(days.reduce((sum, day) => {
      return sum + Number(day.required_fuel_gallons !== undefined ? day.required_fuel_gallons : day.REQUIRED_FUEL_GALLONS || 0);
    }, 0));
  const cruiseBaseFuel = roundTo2(Math.max(0, cruiseRequiredFuel - cruiseReserveFuel));
  const idleFuel = (idleBurnGph > 0 && idleHoursTotal > 0) ? roundTo1(idleBurnGph * idleHoursTotal) : 0;
  const idleReserveFuel = (idleFuel > 0 && reservePct > 0) ? roundTo2(idleFuel * (reservePct / 100)) : 0;
  const summaryTotalHours = roundTo2(cruiseHours + Math.max(0, idleHoursTotal));
  const summaryBaseFuel = roundTo2(cruiseBaseFuel + idleFuel);
  const summaryReserveFuel = roundTo2(cruiseReserveFuel + idleReserveFuel);
  const summaryRequiredFuel = roundTo2(summaryBaseFuel + summaryReserveFuel);
  const summaryFuelCost = (fuelPricePerGal > 0 ? roundTo2(summaryRequiredFuel * fuelPricePerGal) : 0);

  return {
    cruiseHours,
    cruiseRequiredFuel,
    summaryTotalHours,
    summaryBaseFuel,
    summaryReserveFuel,
    summaryRequiredFuel,
    summaryFuelCost
  };
}

function routeStartDate(daysFromNow) {
  const value = new Date();
  value.setDate(value.getDate() + daysFromNow);
  return value.toISOString().slice(0, 10);
}

function routeCodeFromPayload(payload) {
  const data = (payload && typeof payload === "object" && payload.DATA && typeof payload.DATA === "object")
    ? payload.DATA
    : {};
  return String(
    data.route_code !== undefined ? data.route_code :
      (data.ROUTE_CODE !== undefined ? data.ROUTE_CODE : (payload.ROUTE_CODE !== undefined ? payload.ROUTE_CODE : ""))
  ).trim();
}

async function selectOptionContainingText(page, selector, text) {
  await page.waitForFunction(([selectSelector, wanted]) => {
    const select = document.querySelector(selectSelector);
    if (!select) {
      return false;
    }
    return Array.from(select.options).some((option) => {
      return String(option.textContent || "").includes(wanted);
    });
  }, [selector, text], { timeout: 30000 });

  const options = await page.locator(`${selector} option`).evaluateAll((nodes) => {
    return nodes.map((node) => ({
      text: String(node.textContent || "").trim(),
      value: node.value
    }));
  });
  const match = options.find((option) => option.text.includes(text));
  expect(match, `Missing option containing "${text}" for ${selector}`).toBeTruthy();
  await page.selectOption(selector, match.value);
}

async function fillField(page, selector, value) {
  const locator = page.locator(selector);
  await expect(locator).toBeVisible({ timeout: 30000 });
  await locator.fill(String(value));
  await locator.dispatchEvent("input");
  await locator.dispatchEvent("change");
}

async function setDirection(page, direction) {
  const toggle = page.locator("#routeGenDirectionToggle");
  const directionInput = page.locator("#routeGenDirection");
  await page.waitForFunction(() => {
    const input = document.querySelector("#routeGenDirection");
    return !!(input && input.value);
  }, { timeout: 30000 });
  if ((await directionInput.inputValue()) === direction) {
    return;
  }
  await expect(toggle).toBeEnabled({ timeout: 30000 });
  const desiredChecked = direction === "CW";
  if ((await toggle.isChecked()) !== desiredChecked) {
    await toggle.click();
  }
  await expect(directionInput).toHaveValue(direction, { timeout: 30000 });
}

async function waitForPreviewReady(page) {
  await page.waitForFunction(() => {
    return document.querySelectorAll("#routeGenLegList .fpw-routegen__leg").length > 0;
  }, { timeout: 30000 });
}

async function waitForRouteBuilderOption(page, selector, wantedValue) {
  await page.waitForFunction(([selectSelector, value]) => {
    const select = document.querySelector(selectSelector);
    if (!select || select.disabled) {
      return false;
    }
    return Array.from(select.options).some((option) => String(option.value) === String(value));
  }, [selector, wantedValue], { timeout: 30000 });
}

async function waitForPreviewAndTimeline(page, trigger) {
  const previewResponsePromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_preview");
  }, { timeout: 30000 });
  const timelineResponsePromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=generateCruiseTimeline");
  }, { timeout: 30000 });

  await trigger();

  const previewResponse = await previewResponsePromise;
  const previewPayload = await previewResponse.json();
  expect(!!(previewPayload && previewPayload.SUCCESS)).toBeTruthy();

  const timelineResponse = await timelineResponsePromise;
  const timelinePayload = await timelineResponse.json();
  expect(!!(timelinePayload && (timelinePayload.success || timelinePayload.SUCCESS))).toBeTruthy();

  return { previewPayload, timelinePayload };
}

async function waitForGenerateAndTimeline(page, trigger) {
  const generateResponsePromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_generate");
  }, { timeout: 30000 });
  const timelineResponsePromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=generateCruiseTimeline");
  }, { timeout: 30000 });

  await trigger();

  const generateResponse = await generateResponsePromise;
  const generatePayload = await generateResponse.json();
  expect(!!(generatePayload && generatePayload.SUCCESS)).toBeTruthy();

  const timelineResponse = await timelineResponsePromise;
  const timelinePayload = await timelineResponse.json();
  expect(!!(timelinePayload && (timelinePayload.success || timelinePayload.SUCCESS))).toBeTruthy();

  return generatePayload;
}

async function seedBigBlue(page) {
  const payload = await postJson(page, "/fpw/api/v1/vessel.cfc?method=handle", {
    action: "save",
    vessel: {
      VESSELNAME: VESSEL_NAME,
      TYPE: "Motor Yacht",
      LENGTH: "42",
      COLOR: "Blue",
      HOMEPORT: "Chicago",
      MAX_SPEED: "20",
      MOST_EFFICIENT_SPEED: "15",
      GALLONS_PER_HOUR: "2",
      GPH_AT_MAX_SPEED: "2",
      FUEL_CAPACITY: "1000",
      ISDEFAULTVESSEL: 0
    }
  });
  const vesselId = Number(payload.VESSELID || 0);
  expect(vesselId).toBeGreaterThan(0);
  trackId(sharedState, "vesselIds", vesselId);
  return vesselId;
}

async function configureGreatLoopPreview(page, vesselId, overrides = {}) {
  const idleBurnGph = overrides.idleBurnGph !== undefined ? overrides.idleBurnGph : "0.5";
  const idleHoursTotal = overrides.idleHoursTotal !== undefined ? overrides.idleHoursTotal : "29";
  const optionsPayload = await postJson(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=routegen_getoptions", {
    template_code: TEMPLATE_CODE,
    direction: "CCW"
  });
  const optionsData = optionsPayload.DATA || {};
  const startOptions = Array.isArray(optionsData.startOptions) ? optionsData.startOptions : [];
  const endOptions = Array.isArray(optionsData.endOptions) ? optionsData.endOptions : [];
  expect(startOptions.length).toBeGreaterThan(0);
  expect(endOptions.length).toBeGreaterThan(0);

  await openRouteBuilder(page);

  await page.waitForFunction(() => {
    const select = document.getElementById("routeGenTemplateSelect");
    return !!(select && !select.disabled && select.options.length > 1);
  }, { timeout: 30000 });
  await page.selectOption("#routeGenTemplateSelect", TEMPLATE_CODE);
  await fillField(page, "#routeGenStartDate", routeStartDate(10));
  await setDirection(page, "CCW");

  await selectOptionContainingText(page, "#routeGenStartLocation", startOptions[0].label);
  await selectOptionContainingText(page, "#routeGenEndLocation", endOptions[endOptions.length - 1].label);
  await selectOptionContainingText(page, "#routeGenStartLocation", "Chicago");
  await selectOptionContainingText(page, "#routeGenEndLocation", "Chicago");

  for (const stopCode of OPTIONAL_STOP_CODES) {
    const stopLocator = page.locator(`[data-stop-code="${stopCode}"]`);
    await expect(stopLocator).toBeVisible({ timeout: 30000 });
    const pressed = await stopLocator.getAttribute("aria-pressed");
    if (pressed === "true") {
      await stopLocator.click();
    }
    await expect(stopLocator).toHaveAttribute("aria-pressed", "false", { timeout: 30000 });
  }

  await waitForPreviewReady(page);
  await expect(page.locator("#routeGenTotalNm")).toContainText("4,231.2", { timeout: 30000 });

  await waitForRouteBuilderOption(page, "#routeGenVesselSelect", vesselId);
  await page.selectOption("#routeGenVesselSelect", String(vesselId));

  await fillField(page, "#routeGenMostEfficientSpeed", "15");
  await fillField(page, "#routeGenFuelBurnEfficientGph", "2");
  await fillField(page, "#routeGenCruisingSpeed", "20");
  await fillField(page, "#routeGenFuelBurnGph", "2");
  await fillField(page, "#routeGenIdleBurnGph", idleBurnGph);
  await fillField(page, "#routeGenIdleHoursTotal", idleHoursTotal);
  await fillField(page, "#routeGenWeatherFactorPct", "11");
  await page.selectOption("#routeGenReservePct", "20");
  await fillField(page, "#routeGenUnderwayHoursPerDay", "10");
  await fillField(page, "#routeGenFuelPricePerGal", "5.29");
}

async function generateRoute(page) {
  await fillField(page, "#routeGenRouteName", "Fuel Summary Regression " + Date.now());
  const generatePayload = await waitForGenerateAndTimeline(page, async () => {
    await expect(page.locator("#routeGenGenerateBtn")).toBeEnabled({ timeout: 30000 });
    await page.click("#routeGenGenerateBtn");
  });
  const routeCode = routeCodeFromPayload(generatePayload);
  expect(routeCode).not.toBe("");
  trackValue(sharedState, "routeCodes", routeCode);
  return routeCode;
}

async function setPaceAndWait(page, paceIndex) {
  return waitForPreviewAndTimeline(page, async () => {
    await page.evaluate((nextValue) => {
      const input = document.getElementById("routeGenPace");
      if (!input) {
        throw new Error("Missing routeGenPace input.");
      }
      input.value = String(nextValue);
      input.dispatchEvent(new Event("input", { bubbles: true }));
      input.dispatchEvent(new Event("change", { bubbles: true }));
    }, String(paceIndex));
  });
}

async function expectSummaryState(page, expected, pacePayload) {
  const timelinePayload = pacePayload.timelinePayload;
  const timelineTotals = extractTimelineDisplayTotals(timelinePayload, {
    idleBurnGph: expected.idleBurnGph || 0,
    idleHoursTotal: expected.idleHoursTotal || 0,
    reservePct: expected.reservePct || 20,
    fuelPricePerGal: expected.fuelPricePerGal || 5.29
  });
  const cruiseOnlyTotals = extractTimelineDisplayTotals(timelinePayload, {
    idleBurnGph: 0,
    idleHoursTotal: 0,
    reservePct: expected.reservePct || 20,
    fuelPricePerGal: expected.fuelPricePerGal || 5.29
  });

  await expect.poll(async () => normalizeText(await page.locator("#routeGenAdjustedSpeed").innerText()), {
    timeout: 30000
  }).toContain(expected.adjustedSpeed);

  await expect.poll(async () => normalizeText(await page.locator("#routeGenEstimatedDays").innerText()), {
    timeout: 30000
  }).toBe(`${formatFixed(timelineTotals.summaryTotalHours, 1)} h`);

  await expect.poll(async () => normalizeText(await page.locator("#routeGenEstimatedFuel").innerText()), {
    timeout: 30000
  }).toContain(formatFixed(timelineTotals.summaryRequiredFuel, 1));

  await expect.poll(async () => normalizeText(await page.locator("#routeGenTimelineRouteTotal").innerText()), {
    timeout: 30000
  }).toContain(`${formatFixed(timelineTotals.summaryTotalHours, 1)} h`);

  await expect.poll(async () => normalizeText(await page.locator("#routeGenTimelineRouteTotal").innerText()), {
    timeout: 30000
  }).toContain(`${formatFixed(timelineTotals.summaryRequiredFuel, 1)} gal`);

  await expect.poll(async () => {
    return parseCurrencyNumber(await page.locator("#routeGenFuelCost").innerText());
  }, {
    timeout: 30000
  }).toBeGreaterThan(0);
  const displayedFuelCost = parseCurrencyNumber(await page.locator("#routeGenFuelCost").innerText());
  if (Number(expected.idleHoursTotal || 0) > 0) {
    expect(displayedFuelCost).toBeGreaterThan(cruiseOnlyTotals.summaryFuelCost);
  } else {
    expect(Math.abs(displayedFuelCost - cruiseOnlyTotals.summaryFuelCost)).toBeLessThan(0.31);
  }

  if (expected.fuelSubTextExact) {
    await expect.poll(async () => normalizeText(await page.locator("#routeGenEstimatedFuelSub").innerText()), {
      timeout: 30000
    }).toBe(expected.fuelSubTextExact);
  }

  if (expected.idleHoursSubText) {
    await expect.poll(async () => normalizeText(await page.locator("#routeGenEstimatedDaysSub").innerText()), {
      timeout: 30000
    }).toBe(expected.idleHoursSubText);
  }

  if (expected.zeroIdleDaysSubText) {
    await expect.poll(async () => normalizeText(await page.locator("#routeGenEstimatedDaysSub").innerText()), {
      timeout: 30000
    }).toBe(expected.zeroIdleDaysSubText);
  }

  const calcLocator = page.locator("#routeGenLegHeaderCalc");
  await expect.poll(async () => {
    return normalizeText(await calcLocator.getAttribute("title"));
  }, { timeout: 30000 }).toContain(`Fuel total ${expected.estimatedFuel} gal from Cruise Timeline`);

  await expect(calcLocator).toContainText(`Fuel total ${expected.estimatedFuel} gal from Cruise Timeline`, { timeout: 30000 });

  const calcTitle = normalizeText(await calcLocator.getAttribute("title"));
  expected.titleContains.forEach((fragment) => {
    expect(calcTitle).toContain(fragment);
  });

  if (expected.hasRateEstimate) {
    expect(calcTitle).toContain("rate estimate:");
  } else {
    expect(calcTitle).not.toContain("rate estimate:");
  }
}

test.afterAll(async ({ browser }) => {
  const hasTrackedState = Object.values(sharedState).some((value) => Array.isArray(value) && value.length);
  if (!hasTrackedState) {
    return;
  }
  const page = await browser.newPage();
  await loginApprovedUser(page);
  await cleanupTrackedData(page, sharedState);
  await page.close();
});

test("Route Builder keeps Cruise Timeline fuel totals authoritative across pace modes", async ({ page }) => {
  const consoleErrors = attachConsoleErrorCollector(page);

  await loginApprovedUser(page);
  const vesselId = await seedBigBlue(page);

  await configureGreatLoopPreview(page, vesselId);
  await generateRoute(page);

  let pacePayload = await setPaceAndWait(page, 0);
  await expectSummaryState(page, {
    adjustedSpeed: "4.67",
    estimatedFuel: "889.8",
    idleBurnGph: "0.5",
    idleHoursTotal: "29",
    idleHoursSubText: "Cruise 943.8h + Idle 29.0h = 972.8h",
    fuelSubTextExact: "Base 758.9 + Reserve (20%) 148.3",
    hasRateEstimate: true,
    titleContains: [
      "AdjSpeed 4.67 kn",
      "effective weather 6.60%",
      "943.80 h",
      "Fuel total 889.8 gal from Cruise Timeline",
      "[src route inputs]"
    ]
  }, pacePayload);

  pacePayload = await setPaceAndWait(page, 1);
  await expectSummaryState(page, {
    adjustedSpeed: "14.01",
    estimatedFuel: "844.3",
    idleBurnGph: "0.5",
    idleHoursTotal: "29",
    idleHoursSubText: "Cruise 339.8h + Idle 29.0h = 368.8h",
    hasRateEstimate: false,
    titleContains: [
      "AdjSpeed 14.01 kn",
      "effective weather 6.60%",
      "339.80 h",
      "Fuel total 844.3 gal from Cruise Timeline",
      "[src route inputs]"
    ]
  }, pacePayload);

  pacePayload = await setPaceAndWait(page, 2);
  await expectSummaryState(page, {
    adjustedSpeed: "18.68",
    estimatedFuel: "633.2",
    idleBurnGph: "0.5",
    idleHoursTotal: "29",
    idleHoursSubText: "Cruise 264.3h + Idle 29.0h = 293.3h",
    hasRateEstimate: true,
    titleContains: [
      "AdjSpeed 18.68 kn",
      "effective weather 6.60%",
      "264.30 h",
      "Fuel total 633.2 gal from Cruise Timeline",
      "[src route inputs]"
    ]
  }, pacePayload);

  await assertNoConsoleErrors(consoleErrors);
});

test("Route Builder leaves Cruise Timeline summary unchanged when idle inputs are zero", async ({ page }) => {
  const consoleErrors = attachConsoleErrorCollector(page);

  await loginApprovedUser(page);
  const vesselId = await seedBigBlue(page);

  await configureGreatLoopPreview(page, vesselId, {
    idleBurnGph: "0",
    idleHoursTotal: "0"
  });
  await generateRoute(page);

  const pacePayload = await setPaceAndWait(page, 2);
  await expectSummaryState(page, {
    adjustedSpeed: "18.68",
    estimatedFuel: "633.2",
    idleBurnGph: "0",
    idleHoursTotal: "0",
    zeroIdleDaysSubText: "ceil(264.30/10.0) from Cruise Timeline",
    fuelSubTextExact: "Base 527.2 + Reserve (20%) 106.0",
    hasRateEstimate: true,
    titleContains: [
      "AdjSpeed 18.68 kn",
      "effective weather 6.60%",
      "264.30 h",
      "Fuel total 633.2 gal from Cruise Timeline",
      "[src route inputs]"
    ]
  }, pacePayload);

  await assertNoConsoleErrors(consoleErrors);
});
