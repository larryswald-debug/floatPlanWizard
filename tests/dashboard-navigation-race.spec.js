const { test, expect } = require("@playwright/test");

const baseUrl = "http://localhost:8500/fpw";
const dashboardUrl = `${baseUrl}/app/dashboard.cfm`;
const loginUrlPattern = /\/fpw\/index\.cfm(?:\?|$)/;
const currentMemberPattern = "**/api/v1/me.cfc?*";
const cleanupUrl = `${baseUrl}/tests/onboarding-runner.cfm`
  + "?confirm=RUN_DISPOSABLE_WELCOME_ONBOARDING_TESTS&reporter=json";
const disposablePassword = "DashboardRace!2026";

let memberStorageState;

test.describe.configure({ mode: "serial" });

function collectUnexpectedErrors(page) {
  const errors = [];
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(`console: ${message.text()}`);
  });
  page.on("pageerror", (error) => errors.push(`pageerror: ${error.message}`));
  return errors;
}

async function createMemberStorageState(browser) {
  const context = await browser.newContext();
  const page = await context.newPage();
  const email = `codex-welcome-onboarding-dashboard-race-${Date.now()}-${Math.random().toString(16).slice(2)}@example.test`;

  const response = await page.goto(`${baseUrl}/app/join.cfm`, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);
  await page.locator("#firstName").fill("Dashboard");
  await page.locator("#lastName").fill("Race Test");
  await page.locator("#email").fill(email);
  await page.locator("#password").fill(disposablePassword);
  await page.locator("#confirmPassword").fill(disposablePassword);
  await page.locator("#termsAccepted").check();
  await Promise.all([
    page.waitForURL(/\/fpw\/app\/dashboard\.cfm/),
    page.locator("#joinButton").click()
  ]);

  const state = await context.storageState();
  await context.close();
  return state;
}

async function openMemberPage(browser) {
  const context = await browser.newContext({ storageState: memberStorageState });
  const page = await context.newPage();
  return { context, page };
}

async function navigateWhileCurrentMemberIsPending(page, destination) {
  let requestStarted;
  const started = new Promise((resolve) => { requestStarted = resolve; });

  await page.route(currentMemberPattern, async (route) => {
    requestStarted();
    await new Promise((resolve) => setTimeout(resolve, 900));
    try {
      await route.continue();
    } catch (error) {
      // Navigation can dispose the pending request before it is continued.
    }
  });

  const dashboardResponse = await page.goto(dashboardUrl, { waitUntil: "domcontentloaded" });
  expect(dashboardResponse && dashboardResponse.status()).toBe(200);
  await started;

  const [navigationResponse] = await Promise.all([
    page.waitForNavigation({ waitUntil: "domcontentloaded" }),
    page.evaluate((url) => window.location.assign(url), destination)
  ]);
  expect(navigationResponse && navigationResponse.status()).toBe(200);
  await page.waitForTimeout(1100);
  expect(new URL(page.url()).pathname).toBe(new URL(destination).pathname);
  expect(page.url()).not.toMatch(loginUrlPattern);
  await page.unroute(currentMemberPattern);
}

async function openDashboardWithCurrentMemberResponse(browser, response) {
  const { context, page } = await openMemberPage(browser);
  await page.route(currentMemberPattern, (route) => route.fulfill({
    status: response.status,
    contentType: "application/json",
    body: JSON.stringify(response.body)
  }));
  await page.goto(dashboardUrl, { waitUntil: "domcontentloaded" });
  return { context, page };
}

test.beforeAll(async ({ browser }) => {
  memberStorageState = await createMemberStorageState(browser);
});

test.afterAll(async ({ request }) => {
  const response = await request.get(cleanupUrl);
  expect(response.status()).toBe(200);
  const payload = await response.json();
  expect(payload.SUCCESS).toBe(true);
  expect(payload.CLEANUP && payload.CLEANUP.SUCCESS).toBe(true);
});

test("five immediate Dashboard-to-Solo-Guide navigations are not hijacked", async ({ browser }) => {
  const { context, page } = await openMemberPage(browser);
  const errors = collectUnexpectedErrors(page);
  const soloGuideUrl = `${baseUrl}/solo-boating-safety-guide/`;

  for (let attempt = 1; attempt <= 5; attempt += 1) {
    await navigateWhileCurrentMemberIsPending(page, soloGuideUrl);
  }

  const sessionResponse = await page.goto(dashboardUrl, { waitUntil: "domcontentloaded" });
  expect(sessionResponse && sessionResponse.status()).toBe(200);
  await expect(page).toHaveURL(dashboardUrl);
  expect(errors).toEqual([]);
  await context.close();
});

test("representative Dashboard destinations survive a pending current-member request", async ({ browser }) => {
  const { context, page } = await openMemberPage(browser);
  const errors = collectUnexpectedErrors(page);
  const destinations = [
    `${baseUrl}/how-it-works/`,
    `${baseUrl}/app/pricing.cfm`,
    `${baseUrl}/solo-boating-safety-guide/`,
    `${baseUrl}/shore-contact-overdue-boater/`
  ];

  for (const destination of destinations) {
    await navigateWhileCurrentMemberIsPending(page, destination);
  }

  expect(errors).toEqual([]);
  await context.close();
});

test("abort and transient current-member failures do not redirect", async ({ browser }) => {
  {
    const { context, page } = await openMemberPage(browser);
    await page.route(currentMemberPattern, (route) => route.abort("aborted"));
    await page.goto(dashboardUrl, { waitUntil: "domcontentloaded" });
    await page.waitForTimeout(500);
    await expect(page).toHaveURL(dashboardUrl);
    await context.close();
  }

  {
    const { context, page } = await openDashboardWithCurrentMemberResponse(browser, {
      status: 503,
      body: { SUCCESS: false, AUTH: false, ERROR: "SERVER_ERROR", MESSAGE: "Temporary failure" }
    });
    await page.waitForTimeout(500);
    await expect(page).toHaveURL(dashboardUrl);
    await context.close();
  }
});

test("explicit current-member authentication failure redirects to login", async ({ browser }) => {
  const { context, page } = await openDashboardWithCurrentMemberResponse(browser, {
    status: 200,
    body: { SUCCESS: false, AUTH: false, ERROR: "AUTH_REQUIRED", MESSAGE: "Not logged in." }
  });
  await page.waitForURL(loginUrlPattern);
  expect(page.url()).toMatch(loginUrlPattern);
  await context.close();
});

test("logged-out Dashboard access remains server-protected", async ({ browser }) => {
  const context = await browser.newContext();
  const page = await context.newPage();
  const response = await page.goto(dashboardUrl, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);
  expect(page.url()).toMatch(/\/fpw\/index\.cfm\?notice=member-required$/);
  await context.close();
});
