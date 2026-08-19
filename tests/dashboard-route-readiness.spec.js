const { test, expect } = require("@playwright/test");

const baseUrl = "http://localhost:8500/fpw";
const cleanupUrl = `${baseUrl}/tests/onboarding-runner.cfm`
  + "?confirm=RUN_DISPOSABLE_WELCOME_ONBOARDING_TESTS&reporter=json";
const password = "RouteReady!2026";

test.describe.configure({ mode: "serial" });

function collectRuntimeFailures(page) {
  const failures = [];
  page.on("console", (message) => {
    if (message.type() === "error") failures.push(`console: ${message.text()}`);
  });
  page.on("pageerror", (error) => failures.push(`pageerror: ${error.message}`));
  page.on("requestfailed", (request) => {
    const failure = request.failure();
    failures.push(`requestfailed: ${request.url()} (${failure ? failure.errorText : "unknown"})`);
  });
  page.on("response", (response) => {
    if (response.status() >= 500) failures.push(`response ${response.status()}: ${response.url()}`);
  });
  return failures;
}

function disposableEmail(label) {
  const nonce = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  return `codex-welcome-onboarding-${label}-${nonce}@example.test`;
}

async function createDisposableMember(page, label) {
  const email = disposableEmail(label);
  const response = await page.goto(`${baseUrl}/app/join.cfm`, {
    waitUntil: "domcontentloaded"
  });

  expect(response && response.status()).toBe(200);
  await page.locator("#firstName").fill("Route");
  await page.locator("#lastName").fill("Readiness");
  await page.locator("#email").fill(email);
  await page.locator("#password").fill(password);
  await page.locator("#confirmPassword").fill(password);
  await page.locator("#termsAccepted").check();

  await Promise.all([
    page.waitForURL(/\/fpw\/app\/dashboard\.cfm/),
    page.locator("#joinButton").click()
  ]);

  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible();
  await expect(page.locator("#welcomeOnboardingModal")).toBeVisible();
  await page.locator("#welcomeOnboardingCloseBtn").click();
  await expect(page.locator("#welcomeOnboardingModal")).toBeHidden();

  return email;
}

function onboardingState(payload) {
  return payload && (payload.ONBOARDING || payload.onboarding);
}

function valueFrom(source, ...keys) {
  for (const key of keys) {
    if (source && source[key] !== undefined) return source[key];
  }
  return undefined;
}

function formatIsoDate(date) {
  const pad = (value) => String(value).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function formatLocalDateTime(date) {
  const pad = (value) => String(value).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
    + `T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

async function getOnboardingState(page) {
  const payload = await page.evaluate(() => window.Api.getDashboardOnboardingState());
  return onboardingState(payload);
}

async function saveDashboardItem(page, method, payload) {
  const result = await page.evaluate(async ({ apiMethod, apiPayload }) => {
    return window.Api[apiMethod](apiPayload);
  }, { apiMethod: method, apiPayload: payload });
  expect(result && result.SUCCESS).toBe(true);
}

async function expectRouteCreationBlocked(page, expectedText) {
  const stateResponsePromise = page.waitForResponse((response) => (
    response.request().method() === "GET"
    && response.url().includes("/api/v1/onboarding.cfc")
    && response.url().includes("action=state")
  ));
  await page.locator("#openRouteBuilderBtn").click();
  expect((await stateResponsePromise).status()).toBe(200);
  await expect(page.locator("#routeBuilderModal")).toBeHidden();
  await expect(page.locator("#dashboardAlert")).toContainText(expectedText);
  await expect(page.locator("#dashboardAlert")).not.toContainText("passenger");
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

async function saveRequiredRouteSetup(page, email) {
  const results = await page.evaluate(async ({ contactEmail }) => {
    const api = window.Api;
    return [
      await api.saveVessel({
        vessel: {
          VESSELID: 0,
          VESSELNAME: "Readiness Test Vessel",
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
          MODEL: "Canonical",
          COLOR: "White",
          HOMEPORT: ""
        }
      }),
      await api.saveContact({
        contact: {
          CONTACTID: 0,
          CONTACTNAME: "Readiness Shore Contact",
          PHONE: "(727) 555-0123",
          EMAIL: contactEmail
        }
      }),
      await api.saveOperator({
        operator: {
          OPERATORID: 0,
          OPERATORNAME: "Readiness Operator",
          PHONE: "",
          NOTES: ""
        }
      }),
      await api.saveWaypoint({
        waypoint: {
          WAYPOINTID: 0,
          WAYPOINTNAME: "Readiness Start",
          LATITUDE: "27.9506",
          LONGITUDE: "-82.4572",
          NOTES: ""
        }
      }),
      await api.saveWaypoint({
        waypoint: {
          WAYPOINTID: 0,
          WAYPOINTNAME: "Readiness Destination",
          LATITUDE: "27.9770",
          LONGITUDE: "-82.8270",
          NOTES: ""
        }
      })
    ];
  }, { contactEmail: email });

  for (const result of results) {
    expect(result && result.SUCCESS).toBe(true);
  }

  const setup = await page.evaluate(async () => {
    const firstId = (payload, listKeys, idKeys) => {
      let items = [];
      for (const key of listKeys) {
        if (payload && Array.isArray(payload[key])) {
          items = payload[key];
          break;
        }
      }
      const item = items[0] || {};
      for (const key of idKeys) {
        const id = parseInt(item[key], 10);
        if (id > 0) return id;
      }
      return 0;
    };
    const [vessels, contacts, operators, waypoints] = await Promise.all([
      window.Api.getVessels({ limit: 100 }),
      window.Api.getContacts({ limit: 100 }),
      window.Api.getOperators({ limit: 100 }),
      window.Api.getWaypoints({ limit: 100 })
    ]);
    const waypointItems = waypoints.WAYPOINTS || waypoints.waypoints || [];
    return {
      vesselId: firstId(vessels, ["VESSELS", "vessels"], ["VESSELID", "vesselId"]),
      contactId: firstId(contacts, ["CONTACTS", "contacts"], ["CONTACTID", "contactId"]),
      operatorId: firstId(operators, ["OPERATORS", "operators"], ["OPERATORID", "operatorId"]),
      startWaypointId: parseInt(valueFromRow(waypointItems[0], ["WAYPOINTID", "waypointId"]), 10),
      endWaypointId: parseInt(valueFromRow(waypointItems[1], ["WAYPOINTID", "waypointId"]), 10)
    };

    function valueFromRow(row, keys) {
      for (const key of keys) {
        if (row && row[key] !== undefined) return row[key];
      }
      return 0;
    }
  });
  expect(setup.vesselId).toBeGreaterThan(0);
  expect(setup.contactId).toBeGreaterThan(0);
  expect(setup.operatorId).toBeGreaterThan(0);
  expect(setup.startWaypointId).toBeGreaterThan(0);
  expect(setup.endWaypointId).toBeGreaterThan(0);
  return setup;
}

test.afterAll(async ({ request }) => {
  const response = await request.get(cleanupUrl);
  expect(response.status()).toBe(200);
  const payload = await response.json();
  expect(payload.SUCCESS).toBe(true);
  expect(payload.CLEANUP && payload.CLEANUP.SUCCESS).toBe(true);
});

test("blocks Create Route for a disposable member with incomplete setup", async ({ page }) => {
  const runtimeFailures = collectRuntimeFailures(page);
  const email = await createDisposableMember(page, "incomplete");

  const initialState = await getOnboardingState(page);
  expect(initialState.checklist.allComplete).toBe(false);
  expect(initialState.checklist.firstIncompleteStep).toBe("vessel");

  await expectRouteCreationBlocked(page, "a vessel");

  await saveDashboardItem(page, "saveVessel", {
    vessel: {
      VESSELID: 0,
      VESSELNAME: "Incomplete Readiness Vessel",
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
      MODEL: "Required Guard",
      COLOR: "White",
      HOMEPORT: ""
    }
  });
  await expectRouteCreationBlocked(page, "a shore contact with name, phone, and email");

  await saveDashboardItem(page, "saveContact", {
    contact: {
      CONTACTID: 0,
      CONTACTNAME: "Incomplete Readiness Contact",
      PHONE: "(727) 555-0124",
      EMAIL: email
    }
  });
  await expectRouteCreationBlocked(page, "an operator");

  await saveDashboardItem(page, "saveOperator", {
    operator: {
      OPERATORID: 0,
      OPERATORNAME: "Incomplete Readiness Operator",
      PHONE: "",
      NOTES: ""
    }
  });
  await expectRouteCreationBlocked(page, "2 more waypoints (0 of 2 saved)");

  await saveDashboardItem(page, "saveWaypoint", {
    waypoint: {
      WAYPOINTID: 0,
      WAYPOINTNAME: "Incomplete Readiness Start",
      LATITUDE: "27.9506",
      LONGITUDE: "-82.4572",
      NOTES: ""
    }
  });
  await expectRouteCreationBlocked(page, "1 more waypoint (1 of 2 saved)");

  const finalIncompleteState = await getOnboardingState(page);
  expect(finalIncompleteState.checklist.passengers).toBe(false);
  expect(finalIncompleteState.checklist.allComplete).toBe(false);
  expect(finalIncompleteState.checklist.firstIncompleteStep).toBe("waypoints");
  expect(runtimeFailures).toEqual([]);
});

test("opens Create Route with complete required setup and zero passengers", async ({ page }) => {
  const runtimeFailures = collectRuntimeFailures(page);
  const email = await createDisposableMember(page, "complete");
  const setup = await saveRequiredRouteSetup(page, email);

  const completeState = await getOnboardingState(page);
  expect(completeState.checklist.passengers).toBe(false);
  expect(completeState.checklist.allComplete).toBe(true);

  await page.setViewportSize({ width: 390, height: 844 });
  await page.evaluate((state) => window.FPW.DashboardModules.onboarding.hydrate({
    ONBOARDING: state
  }), completeState);
  await page.locator("#dashboardGettingStartedVisibilityToggle").check();
  await expect(page.locator("#dashboardGettingStartedPanel")).toBeVisible();
  await expect(page.locator('[data-onboarding-step="passengers"] .fpw-onboarding-step-label'))
    .toContainText("optional");
  await expect(page.locator('[data-onboarding-step="passengers"] [data-onboarding-step-status]'))
    .toHaveText("Optional");
  const viewportOverflow = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth
  }));
  expect(viewportOverflow.scrollWidth).toBeLessThanOrEqual(viewportOverflow.clientWidth);

  const stateResponsePromise = page.waitForResponse((response) => (
    response.request().method() === "GET"
    && response.url().includes("/api/v1/onboarding.cfc")
    && response.url().includes("action=state")
  ));
  await page.locator("#openRouteBuilderBtn").click();
  const stateResponse = await stateResponsePromise;
  expect(stateResponse.status()).toBe(200);

  const refreshedState = onboardingState(await stateResponse.json());
  expect(refreshedState.checklist.allComplete).toBe(true);
  expect(refreshedState.checklist.passengers).toBe(false);
  await expect(page.locator("#routeBuilderModal")).toBeVisible();

  const routeName = `codex-welcome-onboarding-zero-passenger-${Date.now()}`;
  await page.locator("#routeGenMyRouteName").fill(routeName);
  const createRouteResponsePromise = page.waitForResponse((response) => (
    response.request().method() === "POST"
    && response.url().includes("/api/v1/routeBuilder.cfc")
    && response.url().includes("action=createUserRoute")
  ));
  await page.locator("#routeGenMyRouteCreateBtn").click();
  const createRouteResponse = await createRouteResponsePromise;
  expect(createRouteResponse.status()).toBe(200);
  const createRoutePayload = await createRouteResponse.json();
  expect(createRoutePayload.SUCCESS).toBe(true);
  await expect(page.locator("#routeGenMyRouteSelect option:checked")).toContainText(routeName);

  const createRouteData = valueFrom(createRoutePayload, "DATA", "data") || {};
  const sourceRouteId = parseInt(valueFrom(createRouteData, "route_id", "ROUTE_ID"), 10);
  expect(sourceRouteId).toBeGreaterThan(0);

  const startResponse = await callRouteBuilder(page, "setuserroutestartwaypoint", {
    route_id: sourceRouteId,
    start_waypoint_id: setup.startWaypointId
  });
  expect(startResponse.status).toBe(200);
  expect(startResponse.payload.SUCCESS).toBe(true);
  const legResponse = await callRouteBuilder(page, "addwaypointlegtouserroute", {
    route_id: sourceRouteId,
    end_waypoint_id: setup.endWaypointId
  });
  expect(legResponse.status).toBe(200);
  expect(legResponse.payload.SUCCESS).toBe(true);

  const tomorrow = new Date(Date.now() + (24 * 60 * 60 * 1000));
  const generationInputs = {
    route_type: "my_route",
    route_id: sourceRouteId,
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
  const previewResponse = await callRouteBuilder(page, "previewuserroute", generationInputs);
  expect(previewResponse.status).toBe(200);
  expect(previewResponse.payload.SUCCESS).toBe(true);
  const generateResponse = await callRouteBuilder(page, "routegen_generate", generationInputs);
  expect(generateResponse.status).toBe(200);
  expect(generateResponse.payload.SUCCESS).toBe(true);
  const generateData = valueFrom(generateResponse.payload, "DATA", "data") || {};
  const routeCode = String(valueFrom(generateData, "route_code", "ROUTE_CODE") || "");
  expect(routeCode).not.toBe("");

  const passengersAfterRouteCreation = await page.evaluate(async () => {
    const payload = await window.Api.getPassengers({ limit: 100 });
    return payload.PASSENGERS || payload.passengers || [];
  });
  expect(passengersAfterRouteCreation).toHaveLength(0);

  await page.locator("#routeGenCancelBtn").click();
  await expect(page.locator("#routeBuilderModal")).toBeHidden();
  await page.reload({ waitUntil: "domcontentloaded" });

  const routeCard = page.locator(
    `#expeditionRouteList .expedition-route-card[role="button"][data-route-code="${routeCode}"]`
  );
  await expect(routeCard).toBeVisible();
  await routeCard.click();
  const activateRouteButton = page.getByRole("button", { name: "Activate Route" }).last();
  await expect(activateRouteButton).toBeVisible();
  await activateRouteButton.click();

  const wizard = page.locator("#floatPlanWizardModal");
  await expect(wizard).toBeVisible();
  await expect(wizard.getByRole("heading", { name: /Step 1/ })).toBeVisible();
  await wizard.locator('input[name="NAME"]').fill(routeName);
  await wizard.locator('select[name="VESSELID"]').selectOption(String(setup.vesselId));
  await wizard.locator('select[name="OPERATORID"]').selectOption(String(setup.operatorId));
  await wizard.getByRole("button", { name: /Next/ }).first().click();
  await expect(wizard.getByRole("heading", { name: /Step 2/ })).toBeVisible();
  const departureAt = new Date(tomorrow);
  departureAt.setHours(8, 0, 0, 0);
  const returnAt = new Date(departureAt.getTime() + (4 * 60 * 60 * 1000));
  await wizard.locator('input[name="DEPARTURE_TIME"]').fill(formatLocalDateTime(departureAt));
  await wizard.locator('select[name="DEPARTURE_TIMEZONE"]').selectOption("US/Eastern");
  await wizard.locator('input[name="RETURN_TIME"]').fill(formatLocalDateTime(returnAt));
  await wizard.locator('select[name="RETURN_TIMEZONE"]').selectOption("US/Eastern");
  await wizard.getByRole("button", { name: /Next/ }).first().click();
  await expect(wizard.getByRole("heading", { name: /Step 3/ })).toBeVisible();
  await wizard.locator('select[name="RESCUE_AUTHORITY_SELECTION"]').selectOption("-1");
  await wizard.getByRole("button", { name: /Next/ }).first().click();
  await expect(wizard.getByRole("heading", { name: /Step 4/ })).toBeVisible();
  await expect(wizard.locator("section:visible .list-group-item")).toHaveCount(0);
  await expect(wizard.getByText("No passengers selected.")).toBeVisible();
  await wizard.getByRole("tab", { name: "Contacts" }).click();
  await wizard.getByText("Readiness Shore Contact", { exact: true }).click();
  await wizard.getByRole("button", { name: /Next/ }).first().click();
  await expect(wizard.getByRole("heading", { name: /Step 5/ })).toBeVisible();
  await wizard.getByRole("button", { name: "Close" }).click();
  await expect(wizard).toBeHidden();

  const passengerSave = await page.evaluate(() => window.Api.savePassenger({
    passenger: {
      PASSENGERID: 0,
      PASSENGERNAME: "Readiness Optional Passenger",
      PHONE: "",
      AGE: "",
      GENDER: "",
      NOTES: ""
    }
  }));
  expect(passengerSave && passengerSave.SUCCESS).toBe(true);

  const stateWithPassenger = await getOnboardingState(page);
  expect(stateWithPassenger.checklist.passengers).toBe(true);
  expect(stateWithPassenger.checklist.allComplete).toBe(true);
  await page.evaluate((state) => window.FPW.DashboardModules.onboarding.hydrate({
    ONBOARDING: state
  }), stateWithPassenger);
  await expect(page.locator('[data-onboarding-step="passengers"] [data-onboarding-step-status]'))
    .toHaveText("Complete");

  await routeCard.click();
  const completeFloatPlanButton = page.getByRole("button", { name: "Complete Float Plan" }).last();
  await expect(completeFloatPlanButton).toBeVisible();
  await completeFloatPlanButton.click();
  await expect(wizard).toBeVisible();
  await expect(wizard.getByRole("heading", { name: /Step 1/ })).toBeVisible();
  await wizard.locator('input[name="NAME"]').fill(routeName);
  await wizard.locator('select[name="VESSELID"]').selectOption(String(setup.vesselId));
  await wizard.locator('select[name="OPERATORID"]').selectOption(String(setup.operatorId));
  await wizard.getByRole("button", { name: /Next/ }).first().click();
  await expect(wizard.getByRole("heading", { name: /Step 2/ })).toBeVisible();
  await wizard.locator('input[name="DEPARTURE_TIME"]').fill(formatLocalDateTime(departureAt));
  await wizard.locator('select[name="DEPARTURE_TIMEZONE"]').selectOption("US/Eastern");
  await wizard.locator('input[name="RETURN_TIME"]').fill(formatLocalDateTime(returnAt));
  await wizard.locator('select[name="RETURN_TIMEZONE"]').selectOption("US/Eastern");
  await wizard.getByRole("button", { name: /Next/ }).first().click();
  await expect(wizard.getByRole("heading", { name: /Step 3/ })).toBeVisible();
  await wizard.locator('select[name="RESCUE_AUTHORITY_SELECTION"]').selectOption("-1");
  await wizard.getByRole("button", { name: /Next/ }).first().click();
  await expect(wizard.getByRole("heading", { name: /Step 4/ })).toBeVisible();
  const passengerRow = wizard.locator(
    '[role="listbox"][aria-label="Available passengers"] [role="button"]'
  ).filter({ hasText: "Readiness Optional Passenger" });
  await expect(passengerRow).toBeVisible();
  await expect(passengerRow).toHaveAttribute("aria-pressed", "false");
  await passengerRow.click();
  await expect(passengerRow).toHaveAttribute("aria-pressed", "true");
  await wizard.getByRole("button", { name: "Close" }).click();
  await expect(wizard).toBeHidden();
  expect(runtimeFailures).toEqual([]);
});
