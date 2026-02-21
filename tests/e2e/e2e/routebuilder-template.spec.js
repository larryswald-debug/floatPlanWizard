require("./test-hooks");

if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
  throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
}

const { test, expect } = require("@playwright/test");

test("Route Builder generates route from template and opens timeline editor", async ({ page }) => {
  await page.goto("/fpw/index.cfm", { waitUntil: "domcontentloaded" });

  await page.fill('input[name="email"], input[name="EMAIL"]', process.env.FPW_EMAIL || "");
  await page.fill('input[type="password"], input[name="password"], input[name="PASSWORD"]', process.env.FPW_PASSWORD || "");
  await page.click('button[type="submit"], input[type="submit"]');
  await page.waitForLoadState("networkidle");
  await expect(page).not.toHaveURL(/index\.cfm$/i);

  await page.goto("/fpw/app/dashboard.cfm", { waitUntil: "domcontentloaded" });
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 15000 });

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

  await page.click("#routeGenPreviewBtn");
  await page.waitForFunction(() => {
    const txt = document.getElementById("routeGenLegCount");
    if (!txt) return false;
    const n = parseInt((txt.textContent || "").replace(/[^0-9]/g, ""), 10);
    return Number.isFinite(n) && n > 0;
  }, { timeout: 30000 });
  await expect(page.locator("#routeGenLegList .fpw-routegen__leglocks").first()).toHaveText(/[0-9]+/, { timeout: 10000 });

  await page.click("#routeGenGenerateBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 30000 });
  await expect(page.locator("#dashboardAlert")).toContainText("Route generated successfully.", { timeout: 30000 });

  await page.click("#openRouteBuilderBtn");
  await expect(page.locator("#routeBuilderModal")).toBeVisible({ timeout: 15000 });
  await expect(page.locator("#routeGenRouteCode")).toContainText("Draft", { timeout: 10000 });
  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
});

test("Route Builder leg row opens lock panel, then map editor from button", async ({ page }) => {
  await page.goto("/fpw/index.cfm", { waitUntil: "domcontentloaded" });

  await page.fill('input[name="email"], input[name="EMAIL"]', process.env.FPW_EMAIL || "");
  await page.fill('input[type="password"], input[name="password"], input[name="PASSWORD"]', process.env.FPW_PASSWORD || "");
  await page.click('button[type="submit"], input[type="submit"]');
  await page.waitForLoadState("networkidle");
  await expect(page).not.toHaveURL(/index\.cfm$/i);

  await page.goto("/fpw/app/dashboard.cfm", { waitUntil: "domcontentloaded" });
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 15000 });

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

  await page.click("#routeGenPreviewBtn");
  await page.waitForFunction(() => {
    const rows = document.querySelectorAll("#routeGenLegList .fpw-routegen__leg");
    return rows.length > 0;
  }, { timeout: 30000 });

  await page.click("#routeGenLegList .fpw-routegen__leg");
  await expect(page.locator("#routeGenLegList .fpw-routegen__leglockpanel")).toBeVisible({ timeout: 10000 });
  await expect(page.locator("#routeGenLegList .fpw-routegen__leglockhead")).toContainText("Lock Navigation Details", { timeout: 10000 });
  await page.waitForFunction(() => {
    const panel = document.querySelector("#routeGenLegList .fpw-routegen__leglockpanel");
    if (!panel) return false;
    return !!panel.querySelector(".fpw-routegen__locksummary, .fpw-routegen__lockstate");
  }, { timeout: 15000 });
  await page.evaluate(() => {
    const btn = document.querySelector('#routeGenLegList .fpw-routegen__leg [data-leg-action="open-map"]');
    if (!btn) throw new Error("Open map button not found.");
    btn.click();
  });
  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 10000 });
  await expect(page.locator("#routeGenLegMap")).toBeVisible({ timeout: 10000 });
  await expect(page.locator("#routeGenLegMapTitle")).toContainText("->", { timeout: 10000 });
  await expect(page.locator("#routeGenLegMap .leaflet-tooltip").filter({ hasText: "Start" }).first()).toBeVisible({ timeout: 10000 });
  await expect(page.locator("#routeGenLegMap .leaflet-tooltip").filter({ hasText: "End" }).first()).toBeVisible({ timeout: 10000 });
  await expect(page.locator("#routeGenLegSaveBtn")).toBeEnabled();
  await page.click("#routeGenLegOverlayCloseBtn");
  await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 10000 });
  await page.evaluate(() => {
    const btn = document.querySelector('#routeGenLegList .fpw-routegen__leg [data-leg-action="open-map"]');
    if (!btn) throw new Error("Open map button not found for reopen check.");
    btn.click();
  });
  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 10000 });
  await expect(page.locator("#routeGenLegMap .leaflet-tooltip").filter({ hasText: "Start" }).first()).toBeVisible({ timeout: 10000 });
  await expect(page.locator("#routeGenLegMap .leaflet-tooltip").filter({ hasText: "End" }).first()).toBeVisible({ timeout: 10000 });
  await page.click("#routeGenLegOverlayCloseBtn");
  await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 10000 });

  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
});

test("Route Builder saves and clears leg override via deterministic geometry hook", async ({ page }) => {
  await page.addInitScript(() => {
    window.__FPW_ENABLE_TEST_HOOKS = true;
  });

  await page.goto("/fpw/index.cfm", { waitUntil: "domcontentloaded" });

  await page.fill('input[name="email"], input[name="EMAIL"]', process.env.FPW_EMAIL || "");
  await page.fill('input[type="password"], input[name="password"], input[name="PASSWORD"]', process.env.FPW_PASSWORD || "");
  await page.click('button[type="submit"], input[type="submit"]');
  await page.waitForLoadState("networkidle");
  await expect(page).not.toHaveURL(/index\.cfm$/i);

  await page.goto("/fpw/app/dashboard.cfm", { waitUntil: "domcontentloaded" });
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 15000 });

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

  await page.click("#routeGenPreviewBtn");
  await page.waitForFunction(() => {
    return document.querySelectorAll("#routeGenLegList .fpw-routegen__leg").length > 0;
  }, { timeout: 30000 });

  const legOrder = await page.evaluate(() => {
    const rows = Array.from(document.querySelectorAll("#routeGenLegList .fpw-routegen__leg"));
    const candidate = rows.find((row) => {
      const segmentId = parseInt(row.getAttribute("data-segment-id") || "0", 10);
      return Number.isFinite(segmentId) && segmentId > 0;
    });
    return candidate ? candidate.getAttribute("data-leg-order") : "";
  });
  expect(legOrder).not.toEqual("");

  await page.evaluate((orderText) => {
    const btn = document.querySelector(`#routeGenLegList .fpw-routegen__leg[data-leg-order="${orderText}"] [data-leg-action="open-map"]`);
    if (!btn) throw new Error("Open map button not found for selected leg.");
    btn.click();
  }, legOrder);
  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 10000 });
  await expect(page.locator("#routeGenLegMap")).toBeVisible({ timeout: 10000 });

  await page.waitForFunction(() => {
    const hook = window.FPW
      && window.FPW.DashboardModules
      && window.FPW.DashboardModules.routeBuilder
      && window.FPW.DashboardModules.routeBuilder.test;
    return !!(hook && typeof hook.isReady === "function" && hook.isReady());
  }, { timeout: 10000 });

  const setResult = await page.evaluate(() => {
    return window.FPW.DashboardModules.routeBuilder.test.setDraftGeometry([
      { lat: 41.8781, lon: -87.6298 },
      { lat: 42.1000, lon: -87.3000 },
      { lat: 42.3500, lon: -86.9000 }
    ]);
  });
  expect(setResult).toBeTruthy();

  await page.click("#routeGenLegSaveBtn");
  await expect(page.locator("#routeGenLegMapStatus")).toContainText(/saved/i, { timeout: 20000 });

  const savedSnapshot = await page.evaluate(() => {
    return window.FPW.DashboardModules.routeBuilder.test.snapshot();
  });
  expect(savedSnapshot.source.toLowerCase()).not.toContain("default");

  await page.click("#routeGenLegClearBtn");
  await page.click("#routeGenLegSaveBtn");
  await expect(page.locator("#routeGenLegMapSource")).toContainText(/default/i, { timeout: 20000 });
  await expect(page.locator("#routeGenLegMapStatus")).toContainText(/reverted|default|no saved geometry/i, { timeout: 20000 });

  await page.click("#routeGenLegOverlayCloseBtn");
  await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 10000 });
  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
});
