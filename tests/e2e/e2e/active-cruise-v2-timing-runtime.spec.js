require("./test-hooks");

const { test, expect } = require("@playwright/test");

const FIXTURE_PATH = "/fpw/tests/_tmp_active_cruise_v2_timing_fixture.cfm";

test.describe.configure({ timeout: 180000 });

function parseJsonText(text, label) {
  try {
    return JSON.parse(String(text || "").trim());
  } catch (error) {
    throw new Error(`Unable to parse ${label} JSON: ${String(text || "").slice(0, 500)}`);
  }
}

async function callFixture(page, action, payload = {}) {
  const response = await page.context().request.post(`${FIXTURE_PATH}?action=${encodeURIComponent(action)}`, {
    data: payload
  });
  const text = await response.text();
  const parsed = parseJsonText(text, `fixture ${action}`);
  if (!response.ok() || parsed.SUCCESS === false) {
    throw new Error(`Fixture ${action} failed: ${JSON.stringify(parsed)}`);
  }
  return parsed;
}

async function createFixtureInBrowserSession(page) {
  await page.goto(`${FIXTURE_PATH}?action=create`, { waitUntil: "domcontentloaded" });
  const payload = parseJsonText(await page.locator("body").innerText(), "fixture create");
  expect(payload.SUCCESS).toBe(true);
  expect(Number(payload.USERID || 0)).toBeGreaterThan(0);
  expect(Number(payload.FLOATPLAN_ID || 0)).toBeGreaterThan(0);
  return payload;
}

function timingPanel(page) {
  return page.locator("#fpwV2TimingPanel");
}

function timingValue(page, label) {
  return timingPanel(page).locator(".ac-monitor-tile")
    .filter({ hasText: label })
    .locator(".ac-monitor-value")
    .first();
}

function dailyStartValue(page) {
  return timingPanel(page).locator('[data-fpw-field="monitor.dailyStartLabel"]').first();
}

async function waitForTimingPage(page) {
  await expect(page).toHaveURL(/\/fpw\/app\/active-cruise\.cfm/i, { timeout: 30000 });
  await expect(timingPanel(page)).toBeVisible({ timeout: 30000 });
  await expect(page.getByRole("heading", { name: "Float Plan Monitor" })).toBeVisible();
}

async function submitTimingAction(page, actionName, trigger) {
  const responsePromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("/fpw/api/v1/floatplan.cfc")
      && response.url().includes(`action=${actionName}`);
  }, { timeout: 30000 });

  await trigger();
  const response = await responsePromise;
  expect(response.ok()).toBeTruthy();
  await page.waitForLoadState("domcontentloaded", { timeout: 30000 }).catch(() => {});
  await waitForTimingPage(page);
  return {
    status: response.status(),
    url: response.url()
  };
}

test("Active Cruise V2 timing controls update a disposable active trip", async ({ page }) => {
  let fixture = null;
  let cleanupResult = null;

  try {
    fixture = await createFixtureInBrowserSession(page);
    console.log(`AC_V2_TIMING_FIXTURE ${JSON.stringify({
      userId: fixture.USERID,
      floatPlanId: fixture.FLOATPLAN_ID,
      routeInstanceId: fixture.ROUTE_INSTANCE_ID,
      routeCode: fixture.ROUTE_CODE
    })}`);

    await page.goto("/fpw/app/active-cruise.cfm", { waitUntil: "domcontentloaded" });
    await waitForTimingPage(page);

    await expect(page.getByText("Next Expected Check-In", { exact: true })).toBeVisible();
    await expect(page.getByText("Current Delay", { exact: true })).toBeVisible();
    await expect(timingPanel(page).locator(".ac-delay-section .ac-section-label")).toHaveText("Add Delay Time");
    await expect(page.locator("#fpwV2AddDelayMinutes")).toBeVisible();
    await expect(page.locator('[data-ac-v2-timing-action="addDelay"]')).toBeVisible();
    await expect(page.locator('[data-ac-v2-timing-action="clearDelay"]')).toBeVisible();
    await expect(timingPanel(page).locator(".ac-daily-start-section .ac-section-label")).toHaveText("Daily Start Time");
    await expect(page.locator("#fpwV2DailyStartLocalTime")).toBeVisible();
    await expect(page.locator('[data-ac-v2-timing-action="updateDailyStart"]')).toBeVisible();
    await expect(timingValue(page, "Next Expected Check-In")).not.toHaveText("Not available");
    await expect(timingValue(page, "Current Delay")).toHaveText("0 minutes");

    const initialState = await callFixture(page, "state", { floatPlanId: fixture.FLOATPLAN_ID });
    expect(String(initialState.EXPECTED_CHECKIN_AT_UTC || "")).not.toBe("");
    expect(Number(initialState.MANUAL_DELAY_MINUTES_TOTAL || 0)).toBe(0);

    const addExchange = await submitTimingAction(page, "adddelay", async () => {
      await page.locator("#fpwV2AddDelayMinutes").fill("15");
      await page.locator('[data-ac-v2-timing-action="addDelay"]').click();
    });
    expect(addExchange.status).toBe(200);
    await expect(timingValue(page, "Current Delay")).toHaveText("15 minutes", { timeout: 30000 });
    const afterAddState = await callFixture(page, "state", { floatPlanId: fixture.FLOATPLAN_ID });
    expect(Number(afterAddState.MANUAL_DELAY_MINUTES_TOTAL || 0)).toBe(15);

    const clearExchange = await submitTimingAction(page, "cleardelay", async () => {
      await page.locator('[data-ac-v2-timing-action="clearDelay"]').click();
    });
    expect(clearExchange.status).toBe(200);
    await expect(timingValue(page, "Current Delay")).toHaveText("0 minutes", { timeout: 30000 });
    const afterClearState = await callFixture(page, "state", { floatPlanId: fixture.FLOATPLAN_ID });
    expect(Number(afterClearState.MANUAL_DELAY_MINUTES_TOTAL || 0)).toBe(0);

    const dailyExchange = await submitTimingAction(page, "updatedailystart", async () => {
      await page.locator("#fpwV2DailyStartLocalTime").fill("09:30");
      await page.locator('[data-ac-v2-timing-action="updateDailyStart"]').click();
    });
    expect(dailyExchange.status).toBe(200);
    await expect(dailyStartValue(page)).toHaveText("09:30 EDT", { timeout: 30000 });
    const afterDailyStartState = await callFixture(page, "state", { floatPlanId: fixture.FLOATPLAN_ID });
    expect(String(afterDailyStartState.DAILY_START_LOCAL_TIME || "")).toBe("09:30:00");
  } finally {
    if (fixture) {
      cleanupResult = await callFixture(page, "cleanup", fixture).catch((error) => ({
        SUCCESS: false,
        ERROR: error.message
      }));
      console.log(`AC_V2_TIMING_CLEANUP ${JSON.stringify(cleanupResult.VERIFY || cleanupResult)}`);
      expect(cleanupResult.SUCCESS).toBe(true);
      expect(Number(cleanupResult.VERIFY?.remainingRows || 0)).toBe(0);
    }
  }
});
