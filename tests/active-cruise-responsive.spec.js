const { test, expect } = require("@playwright/test");
const fs = require("node:fs");
const path = require("node:path");

const baseUrl = "http://localhost:8500/fpw";
const cleanupUrl = `${baseUrl}/tests/onboarding-runner.cfm`
  + "?confirm=RUN_DISPOSABLE_WELCOME_ONBOARDING_TESTS&reporter=json";
const password = "Qa5Mobile!2026";
const pdfDirectory = path.join(
  __dirname,
  "..",
  "api",
  "api_assets",
  "floatPlans",
  "user_float_plans"
);

let needsCleanup = false;
let pdfFilesBefore = new Set();
let sourceMyRouteId = 0;

test.describe.configure({ mode: "serial" });

function valueFrom(source, ...keys) {
  for (const key of keys) {
    if (source && source[key] !== undefined) return source[key];
  }
  return undefined;
}

function formatLocalDateTime(date) {
  const pad = (value) => String(value).padStart(2, "0");
  return [
    date.getFullYear(),
    "-",
    pad(date.getMonth() + 1),
    "-",
    pad(date.getDate()),
    "T",
    pad(date.getHours()),
    ":",
    pad(date.getMinutes())
  ].join("");
}

function formatIsoDate(date) {
  return formatLocalDateTime(date).slice(0, 10);
}

function collectRuntimeFailures(page) {
  const failures = [];
  page.on("console", (message) => {
    if (message.type() === "error") {
      failures.push(`console: ${message.text()}`);
    }
  });
  page.on("pageerror", (error) => failures.push(`pageerror: ${error.message}`));
  page.on("requestfailed", (request) => {
    const failure = request.failure();
    failures.push(`requestfailed: ${request.url()} (${failure ? failure.errorText : "unknown"})`);
  });
  page.on("response", (response) => {
    if (response.status() >= 500) {
      failures.push(`response ${response.status()}: ${response.url()}`);
    }
  });
  return failures;
}

async function createDisposableMember(page) {
  const nonce = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const email = `codex-welcome-onboarding-qa5-mobile-${nonce}@example.test`;
  const response = await page.goto(`${baseUrl}/app/join.cfm`, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);
  await page.locator("#firstName").fill("QA5");
  await page.locator("#lastName").fill("Mobile");
  await page.locator("#email").fill(email);
  await page.locator("#password").fill(password);
  await page.locator("#confirmPassword").fill(password);
  await page.locator("#termsAccepted").check();
  await Promise.all([
    page.waitForURL(/\/fpw\/app\/dashboard\.cfm/),
    page.locator("#joinButton").click()
  ]);
  needsCleanup = true;
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

async function createCompleteSetup(page, email) {
  const setupNames = {
    vessel: `QA5 Mobile Vessel ${Date.now()}`,
    contact: `QA5 Mobile Contact ${Date.now()}`,
    passenger: `QA5 Mobile Passenger ${Date.now()}`,
    operator: `QA5 Mobile Operator ${Date.now()}`,
    startWaypoint: `QA5 Mobile Start ${Date.now()}`,
    endWaypoint: `QA5 Mobile End ${Date.now()}`
  };
  const results = await page.evaluate(async ({ contactEmail, names }) => {
    const api = window.Api;
    return [
      await api.saveVessel({
        vessel: {
          VESSELID: 0,
          VESSELNAME: names.vessel,
          REGISTRATION: "",
          TYPE: "Power",
          LENGTH: "24",
          MAX_SPEED: "20",
          MOST_EFFICIENT_SPEED: "12",
          GALLONS_PER_HOUR: "4",
          GPH_AT_MAX_SPEED: "7",
          FUEL_CAPACITY: "60",
          ISDEFAULTVESSEL: 1,
          MAKE: "Test",
          MODEL: "QA5",
          COLOR: "White",
          HOMEPORT: ""
        }
      }),
      await api.saveContact({
        contact: {
          CONTACTID: 0,
          CONTACTNAME: names.contact,
          PHONE: "(727) 555-0155",
          EMAIL: contactEmail
        }
      }),
      await api.savePassenger({
        passenger: {
          PASSENGERID: 0,
          PASSENGERNAME: names.passenger,
          PHONE: "",
          AGE: "",
          GENDER: "",
          NOTES: ""
        }
      }),
      await api.saveOperator({
        operator: {
          OPERATORID: 0,
          OPERATORNAME: names.operator,
          PHONE: "",
          NOTES: ""
        }
      }),
      await api.saveWaypoint({
        waypoint: {
          WAYPOINTID: 0,
          WAYPOINTNAME: names.startWaypoint,
          LATITUDE: "27.9506",
          LONGITUDE: "-82.4572",
          NOTES: ""
        }
      }),
      await api.saveWaypoint({
        waypoint: {
          WAYPOINTID: 0,
          WAYPOINTNAME: names.endWaypoint,
          LATITUDE: "27.9770",
          LONGITUDE: "-82.8270",
          NOTES: ""
        }
      })
    ];
  }, { contactEmail: email, names: setupNames });

  for (const result of results) {
    expect(result && result.SUCCESS).toBe(true);
  }

  const ids = await page.evaluate(async (names) => {
    const [vessels, contacts, passengers, operators, waypoints] = await Promise.all([
      window.Api.getVessels({ limit: 100 }),
      window.Api.getContacts({ limit: 100 }),
      window.Api.getPassengers({ limit: 100 }),
      window.Api.getOperators({ limit: 100 }),
      window.Api.getWaypoints({ limit: 100 })
    ]);
    const list = (payload, keys) => {
      for (const key of keys) {
        if (payload && Array.isArray(payload[key])) return payload[key];
      }
      return [];
    };
    const find = (items, name, nameKeys, idKeys) => {
      const item = items.find((entry) => nameKeys.some((key) => String(entry[key] || "") === name));
      if (!item) return 0;
      for (const key of idKeys) {
        const id = parseInt(item[key], 10);
        if (id > 0) return id;
      }
      return 0;
    };
    return {
      vesselId: find(list(vessels, ["VESSELS", "vessels"]), names.vessel, ["VESSELNAME", "vesselName"], ["VESSELID", "vesselId"]),
      contactId: find(list(contacts, ["CONTACTS", "contacts"]), names.contact, ["CONTACTNAME", "contactName", "NAME"], ["CONTACTID", "contactId"]),
      passengerId: find(list(passengers, ["PASSENGERS", "passengers"]), names.passenger, ["PASSENGERNAME", "passengerName", "NAME"], ["PASSENGERID", "passengerId"]),
      operatorId: find(list(operators, ["OPERATORS", "operators"]), names.operator, ["OPERATORNAME", "operatorName", "NAME"], ["OPERATORID", "operatorId"]),
      startWaypointId: find(list(waypoints, ["WAYPOINTS", "waypoints"]), names.startWaypoint, ["WAYPOINTNAME", "waypointName", "NAME"], ["WAYPOINTID", "waypointId"]),
      endWaypointId: find(list(waypoints, ["WAYPOINTS", "waypoints"]), names.endWaypoint, ["WAYPOINTNAME", "waypointName", "NAME"], ["WAYPOINTID", "waypointId"])
    };
  }, setupNames);

  expect(ids.vesselId).toBeGreaterThan(0);
  expect(ids.contactId).toBeGreaterThan(0);
  expect(ids.passengerId).toBeGreaterThan(0);
  expect(ids.operatorId).toBeGreaterThan(0);
  expect(ids.startWaypointId).toBeGreaterThan(0);
  expect(ids.endWaypointId).toBeGreaterThan(0);
  return ids;
}

async function createGeneratedRoute(page, setup) {
  const tomorrow = new Date(Date.now() + (24 * 60 * 60 * 1000));
  const routeName = `codex-welcome-onboarding-qa5-mobile-${Date.now()}`;
  const createResponse = await callRouteBuilder(page, "createuserroute", {
    route_name: `${routeName}-source`
  });
  expect(createResponse.status).toBe(200);
  expect(createResponse.payload.SUCCESS).toBe(true);
  const createData = valueFrom(createResponse.payload, "DATA", "data") || {};
  sourceMyRouteId = parseInt(valueFrom(createData, "route_id", "ROUTE_ID"), 10);
  expect(sourceMyRouteId).toBeGreaterThan(0);

  const startResponse = await callRouteBuilder(page, "setuserroutestartwaypoint", {
    route_id: sourceMyRouteId,
    start_waypoint_id: setup.startWaypointId
  });
  expect(startResponse.status).toBe(200);
  expect(startResponse.payload.SUCCESS).toBe(true);
  const legResponse = await callRouteBuilder(page, "addwaypointlegtouserroute", {
    route_id: sourceMyRouteId,
    end_waypoint_id: setup.endWaypointId
  });
  expect(legResponse.status).toBe(200);
  expect(legResponse.payload.SUCCESS).toBe(true);

  const payload = {
    route_type: "my_route",
    route_id: sourceMyRouteId,
    route_name: routeName,
    direction: "CCW",
    start_date: formatIsoDate(tomorrow),
    pace: "AGGRESSIVE",
    cruising_speed: "12",
    effective_cruising_speed: "12",
    underway_hours_per_day: "6.5",
    fuel_burn_gph: "4",
    fuel_burn_gph_input: "4",
    fuel_burn_basis: "MAX_SPEED",
    idle_burn_gph: "",
    idle_hours_total: "",
    weather_factor_pct: "0",
    reserve_pct: "33",
    reserve_mode: "thirds",
    fuel_price_per_gal: "",
    vessel_max_speed_kn: "20",
    vessel_most_efficient_speed_kn: "12",
    vessel_gph_at_most_efficient_speed: "4",
    optional_stop_flags: [],
    leg_override_drafts: {}
  };

  const previewResponse = await callRouteBuilder(page, "previewuserroute", payload);
  expect(previewResponse.status).toBe(200);
  expect(previewResponse.payload.SUCCESS).toBe(true);
  const generateResponse = await callRouteBuilder(page, "routegen_generate", payload);
  expect(generateResponse.status).toBe(200);
  expect(generateResponse.payload.SUCCESS).toBe(true);
  const generateData = valueFrom(generateResponse.payload, "DATA", "data");
  const routeCode = String(valueFrom(generateData, "route_code", "ROUTE_CODE") || "");
  expect(routeCode).not.toBe("");
  return routeCode;
}

async function activateRouteDraft(page, routeCode) {
  const response = await callRouteBuilder(page, "buildfloatplansfromroute", {
    routeCode,
    mode: "SINGLE_MASTER",
    rebuild: 0
  });
  expect(response.status).toBe(200);
  expect(response.payload.SUCCESS).toBe(true);
  const ids = valueFrom(response.payload, "FLOATPLAN_IDS", "floatPlanIds") || [];
  const plans = valueFrom(response.payload, "FLOATPLANS", "floatPlans") || [];
  const planId = parseInt(
    ids[0]
      || valueFrom(plans[0] || {}, "FLOATPLAN_ID", "FLOATPLANID", "floatPlanId"),
    10
  );
  expect(planId).toBeGreaterThan(0);
  return planId;
}

async function completeAndSendPlan(page, planId, setup, email) {
  const departure = new Date(Date.now() + (36 * 60 * 60 * 1000));
  const returnAt = new Date(departure.getTime() + (30 * 24 * 60 * 60 * 1000));
  const result = await page.evaluate(async (fixture) => {
    const failure = (stage, error) => ({
      stage,
      error: error && typeof error === "object"
        ? JSON.parse(JSON.stringify(error))
        : String(error || "Unknown error")
    });
    let bootstrap = null;
    try {
      bootstrap = await window.Api.getFloatPlanBootstrap(fixture.planId);
    } catch (error) {
      return failure("bootstrap", error);
    }
    const plan = Object.assign({}, bootstrap.FLOATPLAN || bootstrap.floatPlan || {});
    plan.FLOATPLANID = fixture.planId;
    plan.VESSELID = fixture.setup.vesselId;
    plan.OPERATORID = fixture.setup.operatorId;
    plan.OPERATOR_HAS_PFD = true;
    plan.EMAIL = fixture.email;
    plan.RESCUE_CENTERID = -1;
    plan.RESCUE_AUTHORITY = "N/A - Call 911";
    plan.RESCUE_AUTHORITY_PHONE = "911";
    plan.DEPARTING_FROM = plan.DEPARTING_FROM || "QA5 Start";
    plan.RETURNING_TO = plan.RETURNING_TO || "QA5 Destination";
    plan.DEPARTURE_TIME = fixture.departure;
    plan.DEPARTURE_TIMEZONE = "US/Eastern";
    plan.DEPARTURE_TIME_UTC = fixture.departureUtc;
    plan.RETURN_TIME = fixture.returnAt;
    plan.RETURN_TIMEZONE = "US/Eastern";
    plan.RETURN_TIME_UTC = fixture.returnAtUtc;
    plan.DO_NOT_SEND = false;

    let waypoints = bootstrap.PLAN_WAYPOINTS || bootstrap.planWaypoints || [];
    if (!waypoints.length) {
      const defaults = bootstrap.ROUTE_DEFAULTS || bootstrap.routeDefaults || {};
      waypoints = defaults.WAYPOINT_SELECTIONS || defaults.waypointSelections || [];
    }
    let saved = null;
    let sent = null;
    try {
      saved = await window.Api.saveFloatPlan({
        FLOATPLAN: plan,
        PASSENGERS: [{ PASSENGERID: fixture.setup.passengerId, HAS_PFD: true, SORT_ORDER: 1 }],
        CONTACTS: [{ CONTACTID: fixture.setup.contactId, SORT_ORDER: 1 }],
        WAYPOINTS: waypoints
      });
    } catch (error) {
      return failure("save", error);
    }
    try {
      sent = await window.Api.sendFloatPlan(fixture.planId);
    } catch (error) {
      return failure("send", error);
    }
    return { saved, sent };
  }, {
    planId,
    setup,
    email,
    departure: formatLocalDateTime(departure),
    departureUtc: departure.toISOString(),
    returnAt: formatLocalDateTime(returnAt),
    returnAtUtc: returnAt.toISOString()
  });

  expect(result.stage, JSON.stringify(result.error || {})).toBeUndefined();
  expect(result.saved && result.saved.SUCCESS).toBe(true);
  expect(result.sent && result.sent.SUCCESS).toBe(true);
}

async function assertContained(locator, viewportWidth) {
  const box = await locator.boundingBox();
  expect(box).not.toBeNull();
  expect(box.x).toBeGreaterThanOrEqual(-1);
  expect(box.x + box.width).toBeLessThanOrEqual(viewportWidth + 1);
}

async function assertAllContained(locator, viewportWidth) {
  const boxes = await locator.evaluateAll((elements) => elements.map((element) => {
    const rect = element.getBoundingClientRect();
    return { left: rect.left, right: rect.right };
  }));
  expect(boxes.length).toBeGreaterThan(0);
  for (const box of boxes) {
    expect(box.left).toBeGreaterThanOrEqual(-1);
    expect(box.right).toBeLessThanOrEqual(viewportWidth + 1);
  }
}

test.beforeAll(() => {
  if (fs.existsSync(pdfDirectory)) {
    pdfFilesBefore = new Set(fs.readdirSync(pdfDirectory));
  }
});

test.afterEach(async ({ page }) => {
  if (sourceMyRouteId <= 0) return;
  const response = await callRouteBuilder(page, "deleteuserroute", {
    route_id: sourceMyRouteId
  });
  expect(response.status).toBe(200);
  expect(response.payload.SUCCESS).toBe(true);
  sourceMyRouteId = 0;
});

test.afterAll(async ({ request }) => {
  try {
    if (needsCleanup) {
      const response = await request.get(cleanupUrl);
      expect(response.status()).toBe(200);
      const payload = await response.json();
      expect(payload.SUCCESS).toBe(true);
      expect(payload.CLEANUP && payload.CLEANUP.SUCCESS).toBe(true);
    }
  } finally {
    if (fs.existsSync(pdfDirectory)) {
      for (const fileName of fs.readdirSync(pdfDirectory)) {
        if (!pdfFilesBefore.has(fileName) && /qa5[_-]mobile/i.test(fileName)) {
          fs.unlinkSync(path.join(pdfDirectory, fileName));
        }
      }
    }
  }
});

test("Active Cruise remains shrink-safe and usable across mobile and desktop widths", async ({ page }) => {
  const runtimeFailures = collectRuntimeFailures(page);
  const widthProof = [];
  const email = await createDisposableMember(page);
  const setup = await createCompleteSetup(page, email);
  const routeCode = await createGeneratedRoute(page, setup);
  const planId = await activateRouteDraft(page, routeCode);
  await completeAndSendPlan(page, planId, setup, email);

  await page.setViewportSize({ width: 390, height: 844 });
  const activeResponse = await page.goto(
    `${baseUrl}/app/active-cruise.cfm?floatPlanId=${planId}`,
    { waitUntil: "domcontentloaded" }
  );
  expect(activeResponse && activeResponse.status()).toBe(200);
  await expect(page.locator("main.main > .shell")).toBeVisible();
  await expect(page.locator("#fpwActiveCruiseV2Map")).toHaveAttribute("data-ac-v2-map-rendered", "true");

  for (const viewport of [
    { width: 390, height: 844 },
    { width: 360, height: 844 },
    { width: 760, height: 900 },
    { width: 1024, height: 900 },
    { width: 1440, height: 900 }
  ]) {
    await page.setViewportSize(viewport);
    await page.waitForTimeout(100);
    await assertContained(page.locator(".fpw-app-subnav"), viewport.width);
    await assertContained(page.locator(".fpw-app-subnav-inner"), viewport.width);
    await assertContained(page.locator("main.main > .shell"), viewport.width);
    await assertContained(page.locator(".hero"), viewport.width);
    await assertContained(page.locator(".top-actions"), viewport.width);
    await assertContained(page.locator(".active-cruise-map-canvas"), viewport.width);
    await assertContained(page.locator("#fpwActiveCruiseV2Map"), viewport.width);
    await assertContained(page.locator(".leg-grid"), viewport.width);
    await assertContained(page.locator(".route-plan-box"), viewport.width);
    await assertAllContained(page.locator(".route-plan-leg-side"), viewport.width);
    await assertContained(page.locator("#acCheckInPanel"), viewport.width);
    await assertContained(page.locator("#fpwV2TimingPanel"), viewport.width);

    const layout = await page.evaluate(() => ({
      documentWidth: document.documentElement.scrollWidth,
      viewportWidth: window.innerWidth,
      offenders: Array.from(document.querySelectorAll("body *"))
        .map((element) => {
          const rect = element.getBoundingClientRect();
          return {
            tag: element.tagName,
            id: element.id,
            className: typeof element.className === "string" ? element.className : "",
            left: Math.round(rect.left * 10) / 10,
            right: Math.round(rect.right * 10) / 10,
            width: Math.round(rect.width * 10) / 10
          };
        })
        .filter((entry) => entry.right > window.innerWidth + 1 || entry.left < -1)
        .slice(0, 20)
    }));
    widthProof.push({
      viewportWidth: layout.viewportWidth,
      documentWidth: layout.documentWidth
    });
    expect(layout.documentWidth, JSON.stringify(layout.offenders)).toBeLessThanOrEqual(viewport.width + 1);
  }

  console.log(`QA5_WIDTH_PROOF ${JSON.stringify(widthProof)}`);

  await page.setViewportSize({ width: 390, height: 844 });
  const subnavLinks = page.locator(".fpw-app-subnav .fpw-app-link");
  await expect(subnavLinks).toHaveCount(5);
  await expect(subnavLinks.nth(0)).toHaveAttribute("href", /\/app\/dashboard\.cfm$/);
  await expect(subnavLinks.nth(1)).toHaveAttribute("href", /\/app\/active-cruise\.cfm$/);
  await expect(subnavLinks.nth(4)).toHaveAttribute("href", /\/boat-fuel-calculator\/boat-fuel-calculator\.cfm$/);
  await subnavLinks.nth(4).focus();
  const focusedSubnavState = await page.evaluate(() => {
    const subnav = document.querySelector(".fpw-app-subnav-inner");
    const focused = document.activeElement;
    return {
      focusedLabel: focused ? focused.textContent.trim() : "",
      subnavScrollLeft: subnav ? subnav.scrollLeft : 0,
      documentScrollX: window.scrollX,
      documentWidth: document.documentElement.scrollWidth,
      tabIndex: focused ? focused.tabIndex : -1
    };
  });
  expect(focusedSubnavState.focusedLabel).toContain("Fuel Calculator");
  expect(focusedSubnavState.subnavScrollLeft).toBeGreaterThan(0);
  expect(focusedSubnavState.documentScrollX).toBe(0);
  expect(focusedSubnavState.documentWidth).toBeLessThanOrEqual(391);
  expect(focusedSubnavState.tabIndex).toBe(0);

  await expect(page.locator("#fpwActiveCruiseV2Map.leaflet-container")).toBeVisible();
  await expect(page.getByRole("button", { name: /On Track/i })).toBeVisible();
  await expect(page.locator(".ac-disabled-action-row", { hasText: "Start Next Leg" })).toBeVisible();
  await expect(page.locator("[data-ac-v2-timing-action='addDelay']")).toBeVisible();
  await expect(page.locator("[data-ac-v2-timing-action='clearDelay']")).toBeVisible();
  await expect(page.locator("[data-ac-v2-timing-action='updateDailyStart']")).toBeVisible();

  await page.setViewportSize({ width: 1440, height: 900 });
  const desktopColumns = await page.locator(".hero").evaluate((element) => (
    getComputedStyle(element).gridTemplateColumns.trim().split(/\s+/).length
  ));
  expect(desktopColumns).toBe(2);
  expect(runtimeFailures).toEqual([]);
});
