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
  await expect(page.locator("#fpwV2TimingPanel")).toBeVisible({ timeout: 30000 });
  await expect(page.locator("#fpwV2TimingPanel")).toHaveAttribute("data-ac-v2-timing-bound", "true");
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

test.describe("Active Cruise V2 delay controls", () => {
  test("validates add-delay minutes on the real timing panel before calling the backend", async ({ page }) => {
    const floatPlanPosts = [];

    await page.route(FLOATPLAN_ROUTE, async (route) => {
      if (route.request().method().toUpperCase() === "POST") {
        floatPlanPosts.push(parseJsonPost(route.request()));
      }
      await route.continue();
    });

    await openActiveCruiseV2(page);

    const addButton = page.locator('[data-ac-v2-timing-action="addDelay"]').first();
    await expect(addButton).toBeEnabled();

    await addButton.click();
    await expect(page.locator("#fpwV2TimingFeedback")).toHaveText("Delay minutes are required.");

    await page.locator("#fpwV2AddDelayMinutes").fill("0");
    await addButton.click();
    await expect(page.locator("#fpwV2TimingFeedback")).toHaveText("Delay minutes must be a positive whole number.");
    expect(floatPlanPosts).toHaveLength(0);
  });

  test("submits valid add-delay minutes through fetch and refreshes the timing panel without navigation", async ({ page }) => {
    const addDelayRequests = [];

    await page.route(FLOATPLAN_ROUTE, async (route) => {
      if (route.request().method().toUpperCase() !== "POST") {
        await route.continue();
        return;
      }
      const body = parseJsonPost(route.request());
      if (!Object.prototype.hasOwnProperty.call(body, "minutes")) {
        await route.continue();
        return;
      }
      addDelayRequests.push(body);
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          SUCCESS: true,
          MESSAGE: "Added 30 minutes of delay time. Total manual delay: 30 minutes.",
          MANUAL_DELAY_MINUTES_TOTAL: 30
        })
      });
    });

    const counters = await openActiveCruiseV2(page);
    const initialDocumentLoads = counters.documentLoads;
    const initialUrl = page.url();

    await page.evaluate(() => {
      document.getElementById("fpwV2TimingPanel")?.setAttribute("data-test-generation", "before");
    });

    await page.locator("#fpwV2AddDelayMinutes").fill("30");
    await page.locator('[data-ac-v2-timing-action="addDelay"]').first().click();

    await expect.poll(() => addDelayRequests.length).toBe(1);
    expect(addDelayRequests[0].minutes).toBe(30);
    expect(Number(addDelayRequests[0].floatPlanId || 0)).toBeGreaterThan(0);

    await expect.poll(() => counters.viewRefreshes).toBeGreaterThan(0);
    expect(counters.documentLoads).toBe(initialDocumentLoads);
    expect(page.url()).toBe(initialUrl);
    await expect.poll(async () => {
      return page.evaluate(() => document.getElementById("fpwV2TimingPanel")?.getAttribute("data-test-generation") || "");
    }).toBe("");
    await expect(page.locator("#fpwV2TimingPanel")).toHaveAttribute("data-ac-v2-timing-bound", "true");
    await expect(page.locator("#fpwV2TimingFeedback")).toContainText("Added 30 minutes of delay time.");
  });
});
