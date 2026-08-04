const { test, expect } = require("@playwright/test");

const baseUrl = "http://localhost:8500/fpw";
const cleanupUrl = `${baseUrl}/tests/onboarding-runner.cfm`
  + "?confirm=RUN_DISPOSABLE_WELCOME_ONBOARDING_TESTS&reporter=json";
const password = "RouteReady!2026";

test.describe.configure({ mode: "serial" });

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

async function getOnboardingState(page) {
  const payload = await page.evaluate(() => window.Api.getDashboardOnboardingState());
  return onboardingState(payload);
}

async function saveCompleteRouteSetup(page, email) {
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
      await api.savePassenger({
        passenger: {
          PASSENGERID: 0,
          PASSENGERNAME: "Readiness Passenger",
          PHONE: "",
          AGE: "",
          GENDER: "",
          NOTES: ""
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
}

test.afterAll(async ({ request }) => {
  const response = await request.get(cleanupUrl);
  expect(response.status()).toBe(200);
  const payload = await response.json();
  expect(payload.SUCCESS).toBe(true);
  expect(payload.CLEANUP && payload.CLEANUP.SUCCESS).toBe(true);
});

test("blocks Create Route for a disposable member with incomplete setup", async ({ page }) => {
  await createDisposableMember(page, "incomplete");

  const initialState = await getOnboardingState(page);
  expect(initialState.checklist.allComplete).toBe(false);
  expect(initialState.checklist.firstIncompleteStep).toBe("vessel");

  const stateResponsePromise = page.waitForResponse((response) => (
    response.request().method() === "GET"
    && response.url().includes("/api/v1/onboarding.cfc")
    && response.url().includes("action=state")
  ));
  await page.locator("#openRouteBuilderBtn").click();
  const stateResponse = await stateResponsePromise;
  expect(stateResponse.status()).toBe(200);

  await expect(page.locator("#routeBuilderModal")).toBeHidden();
  await expect(page.locator("#dashboardAlert")).toContainText(
    "Before creating a route, complete Getting Started"
  );
});

test("opens Create Route for a disposable member with complete setup", async ({ page }) => {
  const email = await createDisposableMember(page, "complete");
  await saveCompleteRouteSetup(page, email);

  const completeState = await getOnboardingState(page);
  expect(completeState.checklist.allComplete).toBe(true);

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
  await expect(page.locator("#routeBuilderModal")).toBeVisible();
});
