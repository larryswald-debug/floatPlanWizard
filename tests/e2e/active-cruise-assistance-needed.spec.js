const { test, expect } = require("@playwright/test");

const ACTIVE_CRUISE_URL = "/fpw/app/active-cruise.cfm";
const ACTIVE_CRUISE_ROUTE = "**/fpw/app/active-cruise.cfm**";
const FLOATPLAN_ROUTE = "**/fpw/api/v1/floatplan.cfc?**";

async function openActiveCruiseV2(page) {
  await loginActiveCruiseUser(page);

  const counters = {
    documentLoads: 0,
    viewRefreshes: 0
  };

  await page.route(ACTIVE_CRUISE_ROUTE, async (route) => {
    if (route.request().resourceType() === "document") {
      counters.documentLoads += 1;
    } else {
      counters.viewRefreshes += 1;
    }
    await route.continue();
  });

  await page.goto(ACTIVE_CRUISE_URL, { waitUntil: "domcontentloaded" });
  await expect(page).toHaveTitle(/Active Cruise V2/);
  await expect(page.locator("#fpwV2ActionPanel")).toBeVisible({ timeout: 30000 });
  await expect(page.locator("#fpwV2ActionPanel")).toHaveAttribute("data-ac-v2-action-bound", "true");
  return counters;
}

async function loginActiveCruiseUser(page) {
  const email = String(process.env.FPW_EMAIL || "").trim();
  const password = String(process.env.FPW_PASSWORD || "").trim();
  if (!email || !password) {
    throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
  }
  const response = await page.context().request.post("/fpw/api/v1/auth.cfc?method=handle&returnFormat=json", {
    data: {
      action: "login",
      email,
      password
    }
  });
  const payload = await response.json();
  expect(response.ok()).toBeTruthy();
  expect(payload.SUCCESS).toBe(true);
}

function parseJsonPost(request) {
  const raw = request.postData() || "{}";
  try {
    return JSON.parse(raw);
  } catch (error) {
    return {};
  }
}

function installGpsMock(page) {
  return page.addInitScript(() => {
    Object.defineProperty(navigator, "geolocation", {
      configurable: true,
      value: {
        getCurrentPosition(success) {
          success({
            timestamp: Date.parse("2026-05-11T12:00:00Z"),
            coords: {
              latitude: 41.881832,
              longitude: -87.623177,
              accuracy: 12,
              altitude: null,
              speed: null,
              heading: null
            }
          });
        }
      }
    });
  });
}

test.describe("Active Cruise V2 action panel", () => {
  test("renders current V2 check-in controls without the legacy modal harness", async ({ page }) => {
    await openActiveCruiseV2(page);

    await expect(page.locator("#fpwCheckInModal")).toHaveCount(0);
    await expect(page.locator('script#fpw-active-cruise-hooks')).toHaveCount(0);
    await expect(page.locator('[data-ac-v2-action="checkin"]').filter({ hasText: "On Track" })).toBeVisible();
    await expect(page.locator('[data-ac-v2-action="checkin"]').filter({ hasText: "Delayed" })).toBeVisible();
    await expect(page.locator('[data-ac-v2-action="checkin"]').filter({ hasText: "Changed Plan" })).toBeVisible();
    await expect(page.locator('[data-ac-v2-action="checkin"]').filter({ hasText: "Secure Night" })).toBeVisible();
  });

  test("submits On Track through fetch, captures GPS, and refreshes the action panel without navigation", async ({ page }) => {
    const checkInRequests = [];

    await installGpsMock(page);
    await page.route(FLOATPLAN_ROUTE, async (route) => {
      if (route.request().method().toUpperCase() !== "POST") {
        await route.continue();
        return;
      }
      const url = new URL(route.request().url());
      if (String(url.searchParams.get("action") || "").toLowerCase() !== "checkin") {
        await route.continue();
        return;
      }
      checkInRequests.push(parseJsonPost(route.request()));
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          SUCCESS: true,
          MESSAGE: "Check-in recorded."
        })
      });
    });

    const counters = await openActiveCruiseV2(page);
    const initialDocumentLoads = counters.documentLoads;
    const initialUrl = page.url();

    await page.evaluate(() => {
      document.getElementById("fpwV2ActionPanel")?.setAttribute("data-test-generation", "before");
    });

    const onTrackButton = page.locator('[data-ac-v2-action="checkin"]').filter({ hasText: "On Track" }).first();
    await expect(onTrackButton).toBeEnabled();
    await onTrackButton.click();

    await expect.poll(() => checkInRequests.length).toBe(1);
    expect(checkInRequests[0].status).toBe("On Track");
    expect(Number(checkInRequests[0].floatPlanId || 0)).toBeGreaterThan(0);
    expect(checkInRequests[0].location).toMatchObject({
      source: "ACTIVE_CRUISE_WEB",
      latitude: 41.881832,
      longitude: -87.623177,
      accuracyMeters: 12
    });

    await expect.poll(() => counters.viewRefreshes).toBeGreaterThan(0);
    expect(counters.documentLoads).toBe(initialDocumentLoads);
    expect(page.url()).toBe(initialUrl);
    await expect.poll(async () => {
      return page.evaluate(() => document.getElementById("fpwV2ActionPanel")?.getAttribute("data-test-generation") || "");
    }).toBe("");
    await expect(page.locator("#fpwV2ActionPanel")).toHaveAttribute("data-ac-v2-action-bound", "true");
    await expect(page.locator("#fpwV2ActionFeedback")).toContainText("Check-in recorded.");
  });
});
