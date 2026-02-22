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
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 15000 });
}

async function openRoutePreview(page) {
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

  const previewBtn = page.locator("#routeGenPreviewBtn");
  await expect(previewBtn).toBeVisible({ timeout: 30000 });
  await expect(previewBtn).toBeEnabled({ timeout: 60000 });
  await previewBtn.click({ timeout: 60000 });
  await page.waitForFunction(() => {
    return document.querySelectorAll("#routeGenLegList .fpw-routegen__leg").length > 0;
  }, { timeout: 30000 });
}

async function waitForTestHook(page) {
  await page.waitForFunction(() => {
    const hook = window.FPW
      && window.FPW.DashboardModules
      && window.FPW.DashboardModules.routeBuilder
      && window.FPW.DashboardModules.routeBuilder.test;
    return !!(hook && typeof hook.isReady === "function" && hook.isReady());
  }, { timeout: 10000 });
}

async function getCandidateLegs(page, limit) {
  return page.evaluate((maxCount) => {
    return Array.from(document.querySelectorAll("#routeGenLegList .fpw-routegen__leg"))
      .map((row) => {
        const order = parseInt(row.getAttribute("data-leg-order") || "0", 10);
        const segmentId = parseInt(row.getAttribute("data-segment-id") || "0", 10);
        const nameEl = row.querySelector(".fpw-routegen__legname");
        const name = nameEl ? String(nameEl.textContent || "").trim() : "";
        return { order, segmentId, name };
      })
      .filter((leg) => Number.isFinite(leg.order) && leg.order > 0 && Number.isFinite(leg.segmentId) && leg.segmentId > 0)
      .slice(0, maxCount);
  }, limit);
}

async function openMapForLeg(page, legOrder) {
  const btn = page.locator(`#routeGenLegList .fpw-routegen__leg[data-leg-order="${legOrder}"] [data-leg-action="open-map"]`);
  await expect(btn).toBeVisible({ timeout: 15000 });
  await page.evaluate((orderText) => {
    const target = document.querySelector(`#routeGenLegList .fpw-routegen__leg[data-leg-order="${orderText}"] [data-leg-action="open-map"]`);
    if (!target) {
      throw new Error("Open map button not found for leg.");
    }
    target.click();
  }, String(legOrder));
  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 10000 });
  await expect(page.locator("#routeGenLegMap")).toBeVisible({ timeout: 10000 });
  await expect(page.locator("#routeGenLegMapTitle")).toContainText("->", { timeout: 10000 });
  await expect(page.locator("#routeGenLegMap .leaflet-tooltip").filter({ hasText: "Start" }).first()).toBeVisible({ timeout: 15000 });
  await expect(page.locator("#routeGenLegMap .leaflet-tooltip").filter({ hasText: "End" }).first()).toBeVisible({ timeout: 15000 });
}

function geometryForIndex(index) {
  const baseLat = 41.7 + (index * 0.1);
  const baseLon = -87.7 + (index * 0.1);
  return [
    { lat: baseLat, lon: baseLon },
    { lat: baseLat + 0.22, lon: baseLon + 0.31 },
    { lat: baseLat + 0.41, lon: baseLon + 0.62 }
  ];
}

test("Route Builder map remains stable across open/reopen and deterministic save/clear on multiple legs", async ({ page }) => {
  await page.addInitScript(() => {
    window.__FPW_ENABLE_TEST_HOOKS = true;
  });

  await loginToDashboard(page);
  await openRoutePreview(page);
  await waitForTestHook(page);

  const candidates = await getCandidateLegs(page, 3);
  expect(candidates.length).toBeGreaterThan(0);

  for (let i = 0; i < candidates.length; i += 1) {
    const leg = candidates[i];
    await openMapForLeg(page, leg.order);

    const selectedSnapshot = await page.evaluate(() => {
      return window.FPW.DashboardModules.routeBuilder.test.snapshot();
    });
    expect(String(selectedSnapshot.selectedLegOrder)).toBe(String(leg.order));

    const setResult = await page.evaluate((points) => {
      return window.FPW.DashboardModules.routeBuilder.test.setDraftGeometry(points);
    }, geometryForIndex(i));
    expect(setResult).toBeTruthy();

    await page.click("#routeGenLegSaveBtn");
    await expect(page.locator("#routeGenLegMapStatus")).toContainText(/saved/i, { timeout: 20000 });

    const savedSnapshot = await page.evaluate(() => {
      return window.FPW.DashboardModules.routeBuilder.test.snapshot();
    });
    expect(String(savedSnapshot.source || "").toLowerCase()).not.toContain("default");

    await page.click("#routeGenLegClearBtn");
    await page.click("#routeGenLegSaveBtn");
    await expect(page.locator("#routeGenLegMapSource")).toContainText(/default/i, { timeout: 20000 });
    await expect(page.locator("#routeGenLegMapStatus")).toContainText(/reverted|default|no saved geometry/i, { timeout: 20000 });

    await page.click("#routeGenLegOverlayCloseBtn");
    await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 10000 });

    await openMapForLeg(page, leg.order);
    await page.click("#routeGenLegOverlayCloseBtn");
    await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 10000 });
  }

  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
});
