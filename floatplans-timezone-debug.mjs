import fs from "node:fs/promises";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");

const REPO_ROOT = process.cwd();
const DEFAULT_BASE_URL = "http://localhost:8500";
const DEFAULT_PATH = "/fpw/app/dashboard.cfm";
const DEFAULT_LOGIN_PATH = "/fpw/index.cfm";
const DEFAULT_APP_READY_SELECTOR = "#floatPlansPanel";
const DEFAULT_OUTPUT_DIR = "floatplans-timezone-debug-output";
const DEFAULT_LOCALE = "en-US";
const DEFAULT_HOST_TIMEZONE = "America/New_York";
const DEFAULT_RUN_MONITOR_LIMIT = 100;
const DEFAULT_SCREENSHOT_MODE = "failures";
const DEFAULT_USE_CLOCK = true;
const DEFAULT_TEST_INSTANTS = [
  "2026-03-08T06:59:59Z",
  "2026-03-08T07:00:00Z",
  "2026-11-01T05:59:59Z",
  "2026-11-01T06:00:00Z",
  "2026-12-31T23:30:00Z",
  "2027-01-01T00:30:00Z"
];
const CRITICAL_TIMEZONES = [
  "America/New_York",
  "UTC",
  "America/Los_Angeles",
  "Pacific/Honolulu",
  "America/St_Johns",
  "Europe/London",
  "Europe/Berlin",
  "Asia/Kolkata",
  "Asia/Kathmandu",
  "Asia/Tokyo",
  "Australia/Eucla",
  "Australia/Sydney",
  "Pacific/Chatham",
  "Pacific/Auckland"
];
const DEFAULT_PROBES = [
  {
    name: "floatplans-panel",
    stage: "dashboard",
    selector: "#floatPlansPanel",
    extract: "text"
  },
  {
    name: "plan-row",
    stage: "dashboard",
    selector: "#floatPlansList [data-plan-id=\"{{floatPlanId}}\"]",
    extract: "text"
  },
  {
    name: "plan-meta",
    stage: "dashboard",
    selector: "#floatPlansList [data-plan-id=\"{{floatPlanId}}\"] small",
    extract: "text"
  },
  {
    name: "wizard-step-title",
    stage: "edit-step2",
    selector: "#floatPlanWizardModal h2.h5",
    extract: "text"
  }
];
const DEFAULT_TIME_FIELDS = [
  {
    name: "browser-fixed-now",
    source: "fact",
    key: "browserFixedNowLocal",
    assertionMode: "absolute",
    expectedStrategy: "formatInstant"
  },
  {
    name: "departure-input",
    stage: "edit-step2",
    selector: "#floatPlanWizardModal [name=\"DEPARTURE_TIME\"]",
    extract: "value",
    assertionMode: "floating"
  },
  {
    name: "departure-timezone",
    stage: "edit-step2",
    selector: "#departureTimezone",
    extract: "value",
    assertionMode: "floating"
  },
  {
    name: "return-input",
    stage: "edit-step2",
    selector: "#floatPlanWizardModal [name=\"RETURN_TIME\"]",
    extract: "value",
    assertionMode: "floating"
  },
  {
    name: "return-timezone",
    stage: "edit-step2",
    selector: "#returnTimezone",
    extract: "value",
    assertionMode: "floating"
  },
  {
    name: "plan-meta",
    stage: "dashboard",
    selector: "#floatPlansList [data-plan-id=\"{{floatPlanId}}\"] small",
    extract: "text",
    assertionMode: "floating"
  }
];
const ROUTE_TEMPLATE_CODES = ["GULF-CORE", "GULF-WEST", "GL_REUSE_V2"];

function envText(name, fallback) {
  const raw = process.env[name];
  return raw !== undefined && String(raw).trim().length ? String(raw).trim() : fallback;
}

function envBool(name, fallback = false) {
  const raw = process.env[name];
  if (raw === undefined) return fallback;
  const normalized = String(raw).trim().toLowerCase();
  if (!normalized) return fallback;
  return ["1", "true", "yes", "y", "on"].includes(normalized);
}

function parseJsonEnv(name, fallback) {
  const raw = process.env[name];
  if (raw === undefined || !String(raw).trim().length) {
    return fallback;
  }
  try {
    return JSON.parse(raw);
  } catch (error) {
    throw new Error(`Invalid JSON in ${name}: ${error.message}`);
  }
}

function sanitizeSegment(value) {
  return String(value || "item")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, "-")
    .replace(/^-+|-+$/g, "") || "item";
}

function normalizeWhitespace(value) {
  return String(value || "")
    .replace(/\s+/g, " ")
    .trim();
}

function timestampStamp() {
  const now = new Date();
  const yyyy = String(now.getUTCFullYear());
  const mm = String(now.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(now.getUTCDate()).padStart(2, "0");
  const hh = String(now.getUTCHours()).padStart(2, "0");
  const mi = String(now.getUTCMinutes()).padStart(2, "0");
  const ss = String(now.getUTCSeconds()).padStart(2, "0");
  return `${yyyy}${mm}${dd}-${hh}${mi}${ss}Z`;
}

function buildUrl(baseUrl, relativePath) {
  return new URL(relativePath, baseUrl).toString();
}

function formatInstantForTimeZone(instant, timeZone, locale) {
  return new Intl.DateTimeFormat(locale, {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23"
  }).format(new Date(instant));
}

function isValidTimezoneId(timeZone) {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone }).format(new Date("2026-01-01T00:00:00Z"));
    return true;
  } catch (error) {
    return false;
  }
}

function orderedTimezones(hostTimezone, allTimezones) {
  const supported = typeof Intl.supportedValuesOf === "function"
    ? Intl.supportedValuesOf("timeZone")
    : [];
  if (!supported.length) {
    throw new Error("This Node runtime does not support Intl.supportedValuesOf('timeZone').");
  }

  const requested = allTimezones ? supported : CRITICAL_TIMEZONES.slice();
  const unique = [];
  const seen = new Set();
  for (const timeZone of [hostTimezone, ...requested]) {
    if (!isValidTimezoneId(timeZone)) {
      throw new Error(`Unsupported timezone id: ${timeZone}`);
    }
    if (!seen.has(timeZone)) {
      seen.add(timeZone);
      unique.push(timeZone);
    }
  }
  return unique;
}

function resolveSpec() {
  const baseUrl = envText("FLOATPLANS_BASE_URL", DEFAULT_BASE_URL);
  const pathName = envText("FLOATPLANS_PATH", DEFAULT_PATH);
  const appReadySelector = envText("APP_READY_SELECTOR", DEFAULT_APP_READY_SELECTOR);
  const locale = envText("LOCALE", DEFAULT_LOCALE);
  const hostTimezone = envText("HOST_TIMEZONE", DEFAULT_HOST_TIMEZONE);
  const outputDir = envText("OUTPUT_DIR", DEFAULT_OUTPUT_DIR);
  const screenshotMode = envText("SCREENSHOT_MODE", DEFAULT_SCREENSHOT_MODE);
  const allTimezones = envBool("ALL_TIMEZONES", false);
  const useClock = envBool("USE_CLOCK", DEFAULT_USE_CLOCK);
  const probes = parseJsonEnv("FLOATPLAN_PROBES", DEFAULT_PROBES);
  const timeFields = parseJsonEnv("TIME_FIELDS", DEFAULT_TIME_FIELDS);
  const testInstants = parseJsonEnv("TEST_INSTANTS", DEFAULT_TEST_INSTANTS);

  if (!Array.isArray(probes)) throw new Error("FLOATPLAN_PROBES must be a JSON array.");
  if (!Array.isArray(timeFields)) throw new Error("TIME_FIELDS must be a JSON array.");
  if (!Array.isArray(testInstants) || !testInstants.length) {
    throw new Error("TEST_INSTANTS must be a non-empty JSON array.");
  }

  for (const instant of testInstants) {
    const parsed = new Date(instant);
    if (Number.isNaN(parsed.getTime())) {
      throw new Error(`Invalid TEST_INSTANTS entry: ${instant}`);
    }
  }

  return {
    baseUrl,
    pathName,
    loginPath: DEFAULT_LOGIN_PATH,
    appReadySelector,
    locale,
    hostTimezone,
    outputDir,
    screenshotMode,
    allTimezones,
    useClock,
    probes,
    timeFields,
    testInstants,
    runMonitorLimit: DEFAULT_RUN_MONITOR_LIMIT,
    routeTemplateCodes: ROUTE_TEMPLATE_CODES.slice()
  };
}

async function mkdirp(dirPath) {
  await fs.mkdir(dirPath, { recursive: true });
}

async function writeJson(filePath, value) {
  await mkdirp(path.dirname(filePath));
  await fs.writeFile(filePath, JSON.stringify(value, null, 2));
}

async function writeText(filePath, value) {
  await mkdirp(path.dirname(filePath));
  await fs.writeFile(filePath, value);
}

async function postJson(request, url, payload) {
  const response = await request.post(url, { data: payload });
  const bodyText = await response.text();
  let json;
  try {
    json = bodyText ? JSON.parse(bodyText) : {};
  } catch (error) {
    throw new Error(`Non-JSON response from ${url}: ${bodyText.slice(0, 500)}`);
  }
  if (!response.ok() || json.SUCCESS === false) {
    throw new Error(`Request failed for ${url}: ${JSON.stringify(json)}`);
  }
  return json;
}

async function waitForOptionValue(page, selector, value) {
  await page.waitForFunction(([selectSelector, targetValue]) => {
    const select = document.querySelector(selectSelector);
    if (!select) return false;
    return Array.from(select.options).some((option) => option.value === targetValue);
  }, [selector, value], { timeout: 30000 });
}

async function waitForFirstNonZeroOption(page, selector) {
  await page.waitForFunction((selectSelector) => {
    const select = document.querySelector(selectSelector);
    if (!select) return false;
    return Array.from(select.options).some((option) => option.value && option.value !== "0");
  }, selector, { timeout: 30000 });
}

async function clickWizardNext(page) {
  const button = page.getByRole("button", { name: /^(Next|Review Float Plan)$/ }).last();
  await button.waitFor({ state: "visible", timeout: 30000 });
  await button.click();
}

async function closeWizard(page) {
  const closeButton = page.locator("#floatPlanWizardModal .btn-close");
  if (await closeButton.count()) {
    await closeButton.first().click();
    await page.locator("#floatPlanWizardModal").waitFor({ state: "hidden", timeout: 30000 });
  }
}

async function login(page, spec) {
  await page.goto(buildUrl(spec.baseUrl, spec.loginPath), { waitUntil: "domcontentloaded" });
  await page.locator("#publicLoginToggle").click();
  await page.locator("#email").fill("lswald@yahoo.com");
  await page.locator("#password").fill("rIhnyc-garhab-neqbu2");
  await Promise.all([
    page.waitForURL(/\/fpw\/app\/dashboard\.cfm/i, { timeout: 30000 }),
    page.locator("#loginButton").click()
  ]);
  await page.locator(spec.appReadySelector).waitFor({ state: "visible", timeout: 30000 });
}

async function ensureSupportVessel(request, spec, prefix, cleanup) {
  const payload = await postJson(request, buildUrl(spec.baseUrl, "/fpw/api/v1/vessel.cfc?method=handle"), {
    action: "save",
    vessel: {
      vesselName: `${prefix} TZ Vessel`,
      type: "Cruiser",
      length: "36",
      color: "White",
      registration: `TZ-${Date.now()}`,
      homePort: "Tarpon Springs",
      maxSpeed: "24",
      mostEfficientSpeed: "15",
      gallonsPerHour: "5",
      gphAtMaxSpeed: "9",
      fuelCapacity: "220",
      make: "Carver",
      model: "Voyager"
    }
  });
  const vesselId = Number(payload.VESSELID || 0);
  cleanup.vesselIds.push(vesselId);
  return { vesselId, vesselName: `${prefix} TZ Vessel` };
}

async function ensureSupportOperator(request, spec, prefix, cleanup) {
  const payload = await postJson(request, buildUrl(spec.baseUrl, "/fpw/api/v1/operator.cfc?method=handle"), {
    action: "save",
    operator: {
      name: `${prefix} TZ Operator`,
      phone: "5555556060",
      notes: "Timezone harness operator"
    }
  });
  const operatorId = Number(payload.OPERATORID || 0);
  cleanup.operatorIds.push(operatorId);
  return { operatorId, operatorName: `${prefix} TZ Operator` };
}

async function requestRouteTemplateOptions(request, spec, templateCode) {
  return postJson(
    request,
    buildUrl(spec.baseUrl, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=routegen_getoptions"),
    {
      template_code: templateCode,
      direction: "CCW"
    }
  );
}

function buildRouteStartDate() {
  const value = new Date();
  value.setUTCDate(value.getUTCDate() + 10);
  return value.toISOString().slice(0, 10);
}

async function createDedicatedRouteForFloatPlans(request, spec, prefix) {
  const attempts = [];
  for (const templateCode of spec.routeTemplateCodes) {
    const optionsPayload = await requestRouteTemplateOptions(request, spec, templateCode);
    const startOptions = Array.isArray(optionsPayload?.DATA?.startOptions) ? optionsPayload.DATA.startOptions : [];
    const endOptions = Array.isArray(optionsPayload?.DATA?.endOptions) ? optionsPayload.DATA.endOptions : [];
    const vessels = Array.isArray(optionsPayload?.DATA?.vessels) ? optionsPayload.DATA.vessels : [];
    if (!optionsPayload?.SUCCESS || !startOptions.length || !endOptions.length) {
      attempts.push({ templateCode, success: false, message: optionsPayload?.MESSAGE || "" });
      continue;
    }
    const selectedVesselId = Number(
      vessels[0]?.VESSELID ||
      vessels[0]?.vesselID ||
      vessels[0]?.vesselId ||
      0
    );
    const startOption = startOptions[0];
    const endOption = endOptions[endOptions.length - 1];
    const routeName = `${prefix} TZ Route`;
    const generatePayload = await postJson(
      request,
      buildUrl(spec.baseUrl, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=routegen_generate"),
      {
        template_code: templateCode,
        direction: optionsPayload?.DATA?.direction || "CCW",
        start_segment_id: String(startOption.segment_id || ""),
        end_segment_id: String(endOption.segment_id || ""),
        start_location_label: String(startOption.label || ""),
        end_location_label: String(endOption.label || ""),
        start_date: buildRouteStartDate(),
        route_name: routeName,
        pace: "RELAXED",
        selected_vessel_id: selectedVesselId > 0 ? String(selectedVesselId) : ""
      }
    );
    const routeCode = String(generatePayload?.ROUTE_CODE || generatePayload?.DATA?.route_code || "").trim();
    const routeInstanceId = Number(generatePayload?.ROUTE_INSTANCE_ID || generatePayload?.DATA?.route_instance_id || 0);
    attempts.push({ templateCode, success: !!generatePayload?.SUCCESS, routeCode, routeInstanceId });
    if (generatePayload?.SUCCESS && routeCode && routeInstanceId > 0) {
      return { routeCode, routeInstanceId };
    }
  }
  throw new Error(`Unable to create route-backed float plans. Attempts: ${JSON.stringify(attempts)}`);
}

async function buildFloatPlansFromRoute(request, spec, routeCode, routeInstanceId) {
  const payload = await postJson(
    request,
    buildUrl(spec.baseUrl, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=buildFloatPlansFromRoute"),
    {
      routeCode,
      routeInstanceId,
      mode: "DAILY",
      rebuild: 0
    }
  );
  const floatPlanIds = Array.isArray(payload?.FLOATPLAN_IDS)
    ? payload.FLOATPLAN_IDS.map((value) => Number(value || 0)).filter((value) => Number.isFinite(value) && value > 0)
    : [];
  if (!payload?.SUCCESS || !floatPlanIds.length) {
    throw new Error(`Route-driven float-plan creation failed: ${JSON.stringify(payload)}`);
  }
  return {
    routeCode,
    routeInstanceId: Number(payload.ROUTE_INSTANCE_ID || routeInstanceId || 0),
    floatPlanIds
  };
}

async function createFixturePlan(page, spec, cleanup) {
  const prefix = `TZH_${Date.now()}`;
  const request = page.context().request;
  const supportVessel = await ensureSupportVessel(request, spec, prefix, cleanup);
  const supportOperator = await ensureSupportOperator(request, spec, prefix, cleanup);
  const route = await createDedicatedRouteForFloatPlans(request, spec, prefix);
  cleanup.routeCodes.push(route.routeCode);

  const built = await buildFloatPlansFromRoute(request, spec, route.routeCode, route.routeInstanceId);
  for (const planId of built.floatPlanIds) {
    cleanup.floatPlanIds.push(planId);
  }

  await page.goto(buildUrl(spec.baseUrl, spec.pathName), { waitUntil: "domcontentloaded" });
  await page.locator(spec.appReadySelector).waitFor({ state: "visible", timeout: 30000 });
  const routeDraftId = built.floatPlanIds[0];
  const editButton = page.locator(`#floatPlansList [data-action="edit"][data-plan-id="${routeDraftId}"]`);
  await editButton.waitFor({ state: "visible", timeout: 30000 });
  await editButton.click();
  await page.locator("#floatPlanWizardModal").waitFor({ state: "visible", timeout: 30000 });

  const planName = `${prefix} Float Plan`;
  const pdfPrefix = planName.replace(/[^A-Za-z0-9_-]+/g, "_");
  cleanup.pdfPrefixes.push(pdfPrefix);

  await page.locator('[name="NAME"]').fill(planName);
  await waitForOptionValue(page, '[name="VESSELID"]', String(supportVessel.vesselId));
  await waitForOptionValue(page, '[name="OPERATORID"]', String(supportOperator.operatorId));
  await page.locator('[name="VESSELID"]').selectOption(String(supportVessel.vesselId));
  await page.locator('[name="OPERATORID"]').selectOption(String(supportOperator.operatorId));
  await clickWizardNext(page);

  await page.locator("#departingFrom").fill("Timezone Dock");
  await page.locator("#returningTo").fill("Timezone Dock");
  await page.locator('[name="DEPARTURE_TIME"]').fill("2027-01-01T08:00");
  await page.locator('[name="RETURN_TIME"]').fill("2027-01-01T18:00");
  await waitForOptionValue(page, "#departureTimezone", "America/New_York");
  await waitForOptionValue(page, "#returnTimezone", "America/New_York");
  await page.locator("#departureTimezone").selectOption("America/New_York");
  await page.locator("#returnTimezone").selectOption("America/New_York");
  await clickWizardNext(page);

  await page.locator('#floatPlanWizardModal input[type="email"]').fill("timezone-harness@example.com");
  await waitForFirstNonZeroOption(page, 'select[name="RESCUE_AUTHORITY_SELECTION"]');
  const rescueValue = await page.locator('select[name="RESCUE_AUTHORITY_SELECTION"] option').evaluateAll((nodes) => {
    const match = nodes.find((node) => node.value && node.value !== "0");
    return match ? match.value : "";
  });
  if (!rescueValue) {
    throw new Error("No rescue authority option is available.");
  }
  await page.locator('select[name="RESCUE_AUTHORITY_SELECTION"]').selectOption(rescueValue);
  await clickWizardNext(page);

  await clickWizardNext(page);
  await clickWizardNext(page);

  const saveButton = page.getByRole("button", { name: "Save Float Plan", exact: true }).first();
  await saveButton.waitFor({ state: "visible", timeout: 30000 });
  await saveButton.click();
  await page.locator(".wizard-alert.alert-success").waitFor({ state: "visible", timeout: 30000 });
  await closeWizard(page);
  await page.locator("#floatPlansList").waitFor({ state: "visible", timeout: 30000 });
  await page.locator("#floatPlansList").waitFor({ state: "visible", timeout: 30000 });

  return {
    floatPlanId: routeDraftId,
    planName,
    routeCode: route.routeCode,
    routeInstanceId: route.routeInstanceId,
    fixtureTimes: {
      departure: "2027-01-01T08:00",
      return: "2027-01-01T18:00",
      timeZone: "America/New_York"
    }
  };
}

async function cleanupFixture(browser, spec, cleanup) {
  const context = await browser.newContext({ timezoneId: spec.hostTimezone, locale: spec.locale });
  const page = await context.newPage();
  try {
    await login(page, spec);
    const request = page.context().request;
    for (const floatPlanId of cleanup.floatPlanIds.slice().reverse()) {
      try {
        const bootstrap = await postJson(request, buildUrl(spec.baseUrl, "/fpw/api/v1/floatplan.cfc?method=handle"), {
          action: "bootstrap",
          floatPlanId
        });
        const plan = bootstrap.FLOATPLAN || {};
        const status = String(plan.STATUS || "").trim().toUpperCase();
        if (status === "ACTIVE") {
          await postJson(request, buildUrl(spec.baseUrl, "/fpw/api/v1/floatplan.cfc?method=handle"), {
            action: "checkin",
            floatPlanId
          });
        }
        await postJson(request, buildUrl(spec.baseUrl, "/fpw/api/v1/floatplan.cfc?method=handle"), {
          action: "delete",
          floatPlanId
        });
      } catch (error) {
        console.error(`Cleanup failed for float plan ${floatPlanId}: ${error.message}`);
      }
    }

    for (const routeCode of cleanup.routeCodes.slice().reverse()) {
      try {
        await postJson(request, buildUrl(spec.baseUrl, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=deleteRoute"), {
          routeCode
        });
      } catch (error) {
        console.error(`Cleanup failed for route ${routeCode}: ${error.message}`);
      }
    }

    for (const vesselId of cleanup.vesselIds.slice().reverse()) {
      try {
        await postJson(request, buildUrl(spec.baseUrl, "/fpw/api/v1/vessel.cfc?method=handle"), {
          action: "delete",
          vesselId
        });
      } catch (error) {
        console.error(`Cleanup failed for vessel ${vesselId}: ${error.message}`);
      }
    }

    for (const operatorId of cleanup.operatorIds.slice().reverse()) {
      try {
        await postJson(request, buildUrl(spec.baseUrl, "/fpw/api/v1/operator.cfc?method=handle"), {
          action: "delete",
          operatorId
        });
      } catch (error) {
        console.error(`Cleanup failed for operator ${operatorId}: ${error.message}`);
      }
    }
  } finally {
    await context.close();
  }
}

function interpolate(value, variables) {
  return String(value).replace(/\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/g, (_, key) => {
    return variables[key] === undefined || variables[key] === null ? "" : String(variables[key]);
  });
}

function attachCollectors(page, spec, fixture) {
  const consoleErrors = [];
  const pageErrors = [];
  const failedRequests = [];
  let latestFloatplansApi = null;

  page.on("console", (msg) => {
    if (msg.type() === "error") {
      const text = String(msg.text() || "").trim();
      if (!text.startsWith("Failed to load resource")) {
        consoleErrors.push(text);
      }
    }
  });

  page.on("pageerror", (error) => {
    pageErrors.push(String(error.message || error));
  });

  page.on("requestfailed", (request) => {
    failedRequests.push({
      url: request.url(),
      method: request.method(),
      resourceType: request.resourceType(),
      failureText: request.failure()?.errorText || "unknown"
    });
  });

  page.on("response", async (response) => {
    if (response.status() >= 400) {
      failedRequests.push({
        url: response.url(),
        method: response.request().method(),
        resourceType: response.request().resourceType(),
        status: response.status()
      });
    }
    if (response.url().includes("/fpw/api/v1/floatplans.cfc?method=handle")) {
      try {
        const payload = await response.json();
        const plans = Array.isArray(payload?.PLANS)
          ? payload.PLANS
          : Array.isArray(payload?.FLOATPLANS)
            ? payload.FLOATPLANS
            : Array.isArray(payload?.floatplans)
              ? payload.floatplans
              : [];
        const row = plans.find((entry) => Number(entry.FLOATPLANID || entry.PLANID || entry.ID || 0) === fixture.floatPlanId) || null;
        latestFloatplansApi = {
          success: payload?.SUCCESS === true,
          count: Number(payload?.COUNT || plans.length || 0),
          row
        };
      } catch (error) {
        latestFloatplansApi = {
          success: false,
          error: error.message
        };
      }
    }
  });

  return {
    consoleErrors,
    pageErrors,
    failedRequests,
    getLatestFloatplansApi() {
      return latestFloatplansApi;
    }
  };
}

async function installClock(page, instant) {
  await page.clock.install({ time: new Date(instant) });
}

async function setClock(page, instant) {
  await page.clock.setFixedTime(new Date(instant));
}

async function captureBrowserFacts(page, spec, timeZone, instant) {
  return page.evaluate(({ locale, timeZone, instant }) => {
    const resolved = Intl.DateTimeFormat().resolvedOptions();
    const now = new Date();
    const fixedFormatter = new Intl.DateTimeFormat(locale, {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hourCycle: "h23"
    });
    return {
      resolvedTimeZone: resolved.timeZone,
      resolvedLocale: resolved.locale,
      requestedTimeZone: timeZone,
      fixedNowIso: now.toISOString(),
      browserFixedNowLocal: fixedFormatter.format(now),
      timezoneOffsetMinutes: now.getTimezoneOffset(),
      instantEcho: instant
    };
  }, {
    locale: spec.locale,
    timeZone,
    instant
  });
}

async function ensureDashboard(page, spec, fixture) {
  await page.goto(buildUrl(spec.baseUrl, spec.pathName), { waitUntil: "domcontentloaded" });
  await page.locator(spec.appReadySelector).waitFor({ state: "visible", timeout: 30000 });
  await page.locator(`#floatPlansList [data-plan-id="${fixture.floatPlanId}"]`).waitFor({ state: "visible", timeout: 30000 });
}

async function ensureEditStep2(page, fixture) {
  const departureInput = page.locator("#floatPlanWizardModal [name=\"DEPARTURE_TIME\"]");
  if (await departureInput.count() && await departureInput.first().isVisible().catch(() => false)) {
    return;
  }
  await page.locator(`#floatPlansList [data-action="edit"][data-plan-id="${fixture.floatPlanId}"]`).click();
  await page.locator("#floatPlanWizardModal").waitFor({ state: "visible", timeout: 30000 });
  if (!await departureInput.first().isVisible().catch(() => false)) {
    await clickWizardNext(page);
    await departureInput.waitFor({ state: "visible", timeout: 30000 });
  }
}

async function resolveDomProbe(page, probe, variables) {
  const selector = interpolate(probe.selector, variables);
  const locator = page.locator(selector).first();
  await locator.waitFor({ state: "visible", timeout: 30000 });
  let raw = "";
  if (probe.extract === "value") {
    raw = await locator.inputValue();
  } else if (probe.extract === "html") {
    raw = await locator.innerHTML();
  } else {
    raw = await locator.textContent();
  }
  return {
    selector,
    raw: raw ?? "",
    normalized: normalizeWhitespace(raw ?? "")
  };
}

function expectedForField(field, instant, timeZone, spec) {
  if (field.expectedStrategy === "formatInstant") {
    return normalizeWhitespace(formatInstantForTimeZone(instant, timeZone, spec.locale));
  }
  return "";
}

function buildAssertion(field, actual, baselineValue, instant, timeZone, spec) {
  if (!field.assertionMode) {
    return null;
  }

  if (field.assertionMode === "floating") {
    const expected = baselineValue ?? "";
    const pass = actual.normalized === expected;
    return {
      field: field.name,
      mode: "floating",
      expected,
      actual: actual.normalized,
      pass,
      message: pass
        ? "matched baseline floating value"
        : `expected floating value "${expected}" but saw "${actual.normalized}"`
    };
  }

  if (field.assertionMode === "absolute") {
    const expected = expectedForField(field, instant, timeZone, spec);
    const pass = !expected.length || actual.normalized === expected;
    return {
      field: field.name,
      mode: "absolute",
      expected,
      actual: actual.normalized,
      pass,
      message: pass
        ? "matched timezone-adjusted absolute value"
        : `expected absolute value "${expected}" but saw "${actual.normalized}"`
    };
  }

  return {
    field: field.name,
    mode: field.assertionMode,
    expected: "",
    actual: actual.normalized,
    pass: true,
    message: "unsupported assertion mode skipped"
  };
}

async function captureFieldsForInstant(page, spec, fixture, browserFacts) {
  const variables = {
    floatPlanId: fixture.floatPlanId,
    planName: fixture.planName
  };
  const capture = {
    probes: {},
    timeFields: {}
  };

  for (const probe of spec.probes) {
    if (probe.stage === "edit-step2") {
      await ensureEditStep2(page, fixture);
    }
    capture.probes[probe.name] = await resolveDomProbe(page, probe, variables);
  }

  for (const field of spec.timeFields) {
    if (field.source === "fact") {
      const raw = browserFacts[field.key];
      capture.timeFields[field.name] = {
        raw,
        normalized: normalizeWhitespace(raw)
      };
      continue;
    }
    if (field.stage === "edit-step2") {
      await ensureEditStep2(page, fixture);
    }
    capture.timeFields[field.name] = await resolveDomProbe(page, field, variables);
  }

  return capture;
}

async function maybeScreenshot(page, spec, runDir, timeZone, instant, failingFields) {
  if (spec.screenshotMode !== "failures" || !failingFields.length) {
    return "";
  }
  const fileName = `${sanitizeSegment(timeZone)}__${sanitizeSegment(instant)}.png`;
  const target = path.join(runDir, "screenshots", fileName);
  await mkdirp(path.dirname(target));
  await page.screenshot({ path: target, fullPage: true });
  return target;
}

function summarizeFailures(zoneRuns) {
  const failures = [];
  for (const zoneRun of zoneRuns) {
    for (const instantRun of zoneRun.instants) {
      for (const assertion of instantRun.assertions) {
        if (!assertion.pass) {
          failures.push({
            timeZone: zoneRun.timeZone,
            instant: instantRun.instant,
            field: assertion.field,
            mode: assertion.mode,
            expected: assertion.expected,
            actual: assertion.actual,
            message: assertion.message
          });
        }
      }
      if (instantRun.consoleErrors.length || instantRun.pageErrors.length || instantRun.failedRequests.length) {
        failures.push({
          timeZone: zoneRun.timeZone,
          instant: instantRun.instant,
          field: "runtime-errors",
          mode: "runtime",
          expected: "",
          actual: "",
          message: [
            instantRun.consoleErrors.length ? `console=${instantRun.consoleErrors.length}` : "",
            instantRun.pageErrors.length ? `page=${instantRun.pageErrors.length}` : "",
            instantRun.failedRequests.length ? `failedRequests=${instantRun.failedRequests.length}` : ""
          ].filter(Boolean).join(" ")
        });
      }
    }
  }
  return failures;
}

function summarizeRootCauses(failures) {
  const messages = [];
  const floatingInputFailures = failures.filter((item) => item.mode === "floating" && /input|timezone|plan-meta/.test(item.field));
  const absoluteFactFailures = failures.filter((item) => item.mode === "absolute");
  const runtimeFailures = failures.filter((item) => item.mode === "runtime");

  if (floatingInputFailures.length) {
    messages.push("Floating wall-clock values changed across browser timezones, which suggests browser-local formatting or parsing is leaking into fields that should stay anchored to the saved local value or explicit plan timezone.");
  }
  if (absoluteFactFailures.length) {
    messages.push("The emulated browser timezone facts did not match the requested timezone for at least one fixed instant, which points to context timezone emulation or clock installation not being applied consistently for those runs.");
  }
  if (runtimeFailures.length) {
    messages.push("Some runs logged console/page/request failures while probing the dashboard, which can mask timezone assertions and usually indicates a page-load or API stability problem rather than a formatting bug alone.");
  }
  if (!messages.length) {
    messages.push("No assertion mismatches were found in the configured Floatplans fields. The harness mainly confirmed that floating wizard inputs and plan-list renderings stay stable across browser timezone emulation for this screen.");
  }
  return messages;
}

function buildSummaryMarkdown(summary) {
  const lines = [];
  lines.push("# Floatplans timezone debug summary");
  lines.push("");
  lines.push(`- Run mode: ${summary.mode}`);
  lines.push(`- Base URL: ${summary.baseUrl}`);
  lines.push(`- Path: ${summary.pathName}`);
  lines.push(`- App ready selector: ${summary.appReadySelector}`);
  lines.push(`- Host timezone baseline: ${summary.hostTimezone}`);
  lines.push(`- Locale: ${summary.locale}`);
  lines.push(`- Timezones tested: ${summary.timezonesTested}`);
  lines.push(`- Instants tested: ${summary.instantsTested}`);
  lines.push(`- Assertion failures: ${summary.failureCount}`);
  lines.push("");
  lines.push("## Probes");
  lines.push("");
  for (const probe of summary.probes) {
    lines.push(`- ${probe.name}: ${probe.stage || probe.source || "dashboard"} -> ${probe.selector || probe.key}`);
  }
  lines.push("");
  lines.push("## Root-cause patterns");
  lines.push("");
  for (const message of summary.rootCausePatterns) {
    lines.push(`- ${message}`);
  }
  lines.push("");
  lines.push("## Failures");
  lines.push("");
  if (!summary.failures.length) {
    lines.push("- None");
  } else {
    for (const failure of summary.failures) {
      lines.push(`- ${failure.timeZone} | ${failure.instant} | ${failure.field} | ${failure.message}`);
    }
  }
  lines.push("");
  return lines.join("\n");
}

async function runSweep(browser, spec, runDir, fixture, storageStatePath, mode, timezones) {
  const zoneRuns = [];
  const baselineByInstant = new Map();

  for (const timeZone of timezones) {
    console.log(`[timezone] ${timeZone}`);
    const context = await browser.newContext({
      locale: spec.locale,
      timezoneId: timeZone,
      storageState: storageStatePath,
      viewport: { width: 1440, height: 1100 }
    });
    const page = await context.newPage();
    const collectors = attachCollectors(page, spec, fixture);
    const zoneRun = {
      timeZone,
      instants: [],
      consoleErrors: collectors.consoleErrors,
      pageErrors: collectors.pageErrors,
      failedRequests: collectors.failedRequests
    };

    try {
      if (spec.useClock) {
        await installClock(page, spec.testInstants[0]);
      }
      await ensureDashboard(page, spec, fixture);

      for (const instant of spec.testInstants) {
        if (spec.useClock) {
          await setClock(page, instant);
        }

        const browserFacts = await captureBrowserFacts(page, spec, timeZone, instant);
        const captures = await captureFieldsForInstant(page, spec, fixture, browserFacts);
        const assertions = [];
        const baselineEntry = baselineByInstant.get(instant) || {};

        for (const field of spec.timeFields) {
          const actual = captures.timeFields[field.name];
          const baselineValue = baselineEntry[field.name];
          const assertion = buildAssertion(field, actual, baselineValue, instant, timeZone, spec);
          if (assertion) {
            assertions.push(assertion);
          }
        }

        if (timeZone === spec.hostTimezone) {
          const baselineValues = {};
          for (const field of spec.timeFields) {
            baselineValues[field.name] = captures.timeFields[field.name]?.normalized || "";
          }
          baselineByInstant.set(instant, baselineValues);
        }

        const failingFields = assertions.filter((item) => !item.pass);
        const screenshotPath = await maybeScreenshot(page, spec, runDir, timeZone, instant, failingFields);
        zoneRun.instants.push({
          instant,
          browserFacts,
          probes: captures.probes,
          timeFields: captures.timeFields,
          assertions,
          consoleErrors: collectors.consoleErrors.slice(),
          pageErrors: collectors.pageErrors.slice(),
          failedRequests: collectors.failedRequests.slice(),
          apiContext: collectors.getLatestFloatplansApi(),
          screenshotPath
        });
      }
    } catch (error) {
      zoneRun.zoneError = error.message;
      const screenshotPath = await maybeScreenshot(page, { ...spec, screenshotMode: "failures" }, runDir, timeZone, "zone-error", ["zone"]);
      zoneRun.zoneErrorScreenshot = screenshotPath;
    } finally {
      const zoneFile = path.join(runDir, "runs", `${sanitizeSegment(timeZone)}.json`);
      await writeJson(zoneFile, zoneRun);
      zoneRuns.push(zoneRun);
      await context.close();
    }
  }

  const failures = summarizeFailures(zoneRuns);
  const summary = {
    mode,
    baseUrl: spec.baseUrl,
    pathName: spec.pathName,
    appReadySelector: spec.appReadySelector,
    hostTimezone: spec.hostTimezone,
    locale: spec.locale,
    timezonesTested: zoneRuns.length,
    instantsTested: spec.testInstants.length,
    failureCount: failures.length,
    failures,
    probes: [...spec.probes, ...spec.timeFields],
    rootCausePatterns: summarizeRootCauses(failures),
    fixture,
    runDir
  };

  await writeJson(path.join(runDir, "summary.json"), summary);
  await writeText(path.join(runDir, "summary.md"), buildSummaryMarkdown(summary));
  return summary;
}

async function main() {
  const spec = resolveSpec();
  const mode = spec.allTimezones ? "all" : "critical";
  const runDir = path.resolve(REPO_ROOT, spec.outputDir, `${mode}-${timestampStamp()}`);
  await mkdirp(runDir);
  await writeJson(path.join(runDir, "resolved-spec.json"), spec);

  const timezones = orderedTimezones(spec.hostTimezone, spec.allTimezones);
  const browser = await chromium.launch({ headless: true });
  const cleanup = {
    floatPlanIds: [],
    routeCodes: [],
    vesselIds: [],
    operatorIds: [],
    pdfPrefixes: []
  };
  let storageStatePath = path.join(runDir, "auth-state.json");
  let fixture = null;

  try {
    const setupContext = await browser.newContext({
      locale: spec.locale,
      timezoneId: spec.hostTimezone,
      viewport: { width: 1440, height: 1100 }
    });
    const setupPage = await setupContext.newPage();
    await login(setupPage, spec);
    await setupContext.storageState({ path: storageStatePath });
    fixture = await createFixturePlan(setupPage, spec, cleanup);
    await setupContext.storageState({ path: storageStatePath });
    await writeJson(path.join(runDir, "fixture.json"), fixture);
    await setupContext.close();

    const summary = await runSweep(browser, spec, runDir, fixture, storageStatePath, mode, timezones);
    console.log(JSON.stringify({
      runDir,
      mode,
      timezonesTested: summary.timezonesTested,
      failureCount: summary.failureCount
    }, null, 2));
  } finally {
    if (fixture) {
      await cleanupFixture(browser, spec, cleanup);
    }
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error.stack || error.message || String(error));
  process.exitCode = 1;
});
