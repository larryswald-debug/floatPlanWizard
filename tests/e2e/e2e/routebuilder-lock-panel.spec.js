require("./test-hooks");

if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
  throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
}

const { test, expect } = require("@playwright/test");

test.describe.configure({ timeout: 120000 });

async function loginToDashboard(page) {
  await page.goto("/fpw/index.cfm", { waitUntil: "domcontentloaded" });
  await page.fill('input[name="email"], input[name="EMAIL"]', process.env.FPW_EMAIL || "");
  await page.fill('input[type="password"], input[name="password"], input[name="PASSWORD"]', process.env.FPW_PASSWORD || "");
  await page.click('button[type="submit"], input[type="submit"]');
  await page.waitForLoadState("networkidle");
  await expect(page).not.toHaveURL(/index\.cfm$/i);
  await page.goto("/fpw/app/dashboard.cfm", { waitUntil: "domcontentloaded" });
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 30000 });
}

async function openPreview(page) {
  await page.click("#openRouteBuilderBtn");
  await expect(page.locator("#routeBuilderModal")).toBeVisible({ timeout: 15000 });
  await expect(page.locator("#fpwRouteGen")).toBeVisible({ timeout: 15000 });

  const today = new Date().toISOString().slice(0, 10);
  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenTemplateSelect");
    return !!sel && !sel.disabled && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenTemplateSelect", { index: 1 });
  await page.fill("#routeGenStartDate", today);

  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenStartLocation");
    return !!sel && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenStartLocation", { index: 1 });

  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenEndLocation");
    return !!sel && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenEndLocation", { index: 1 });

  await expect(page.locator("#routeGenPreviewBtn")).toBeEnabled({ timeout: 30000 });
  await page.click("#routeGenPreviewBtn");
  await page.waitForFunction(() => {
    return document.querySelectorAll("#routeGenLegList .fpw-routegen__leg").length > 0;
  }, { timeout: 30000 });
}

test("Route Builder lock panel handles retry and keeps map action available", async ({ page }) => {
  let injectedFailure = false;
  await page.route("**/api/v1/routeBuilder.cfc?*action=routegen_getleglocks*", async (route) => {
    if (!injectedFailure) {
      injectedFailure = true;
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          SUCCESS: false,
          AUTH: true,
          MESSAGE: "Injected lock-panel failure",
          ERROR: { MESSAGE: "Injected lock-panel failure" }
        })
      });
      return;
    }
    await route.continue();
  });

  await loginToDashboard(page);
  await openPreview(page);

  const firstLeg = page.locator("#routeGenLegList .fpw-routegen__leg").first();
  await expect(firstLeg).toBeVisible({ timeout: 15000 });

  await firstLeg.click();
  const lockPanel = page.locator("#routeGenLegList .fpw-routegen__leglockpanel").first();
  await expect(lockPanel).toBeVisible({ timeout: 10000 });
  await expect(lockPanel).toContainText("Injected lock-panel failure", { timeout: 10000 });
  await expect(lockPanel.locator('[data-leg-action="reload-locks"]')).toBeVisible({ timeout: 10000 });

  await page.evaluate(() => {
    const retryBtn = document.querySelector('#routeGenLegList .fpw-routegen__leglockpanel [data-leg-action="reload-locks"]');
    if (retryBtn) retryBtn.click();
  });
  await expect(lockPanel).not.toContainText("Injected lock-panel failure", { timeout: 15000 });
  await expect(lockPanel).toContainText(/Lock Navigation Details|No locks mapped|Locks/i, { timeout: 15000 });

  const openMapBtn = firstLeg.locator('[data-leg-action="open-map"]');
  await expect(openMapBtn).toBeVisible({ timeout: 10000 });
  await openMapBtn.click();

  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 10000 });
  await expect(page.locator("#routeGenLegMap")).toBeVisible({ timeout: 10000 });
  await expect(page.locator("#routeGenLegMapTitle")).toContainText("->", { timeout: 10000 });

  await page.click("#routeGenLegOverlayCloseBtn");
  await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 10000 });

  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
});
