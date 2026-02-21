require("./test-hooks");

if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
  throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
}

const { test, expect } = require("@playwright/test");

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

  await page.click("#routeGenPreviewBtn");
  await page.waitForFunction(() => {
    return document.querySelectorAll("#routeGenLegList .fpw-routegen__leg").length > 0;
  }, { timeout: 30000 });
}

async function openMapForFirstSegmentLeg(page) {
  const legOrder = await page.evaluate(() => {
    const rows = Array.from(document.querySelectorAll("#routeGenLegList .fpw-routegen__leg"));
    const hit = rows.find((row) => {
      const segId = parseInt(row.getAttribute("data-segment-id") || "0", 10);
      return Number.isFinite(segId) && segId > 0;
    });
    return hit ? String(hit.getAttribute("data-leg-order") || "") : "";
  });

  expect(legOrder).not.toEqual("");
  await page.click(`#routeGenLegList .fpw-routegen__leg[data-leg-order="${legOrder}"] [data-leg-action="open-map"]`);
  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 10000 });
  await expect(page.locator("#routeGenLegMap")).toBeVisible({ timeout: 10000 });
}

test("Route Builder supports direct draw/save/clear via map gesture", async ({ page, browserName }) => {
  test.skip(browserName !== "chromium", "Leaflet draw completion gesture is validated on Chromium.");

  await loginToDashboard(page);
  await openRoutePreview(page);
  await openMapForFirstSegmentLeg(page);

  await page.click("#routeGenLegClearBtn");
  await expect(page.locator("#routeGenLegMapStatus")).toContainText(/clear|default|removed|no saved geometry|pin removed/i, { timeout: 10000 });

  await expect(page.locator("#routeGenLegMapPanel .leaflet-draw-draw-polyline")).toBeVisible({ timeout: 10000 });
  await page.click("#routeGenLegMapPanel .leaflet-draw-draw-polyline");
  await expect(page.locator("#routeGenLegMapPanel .leaflet-draw-toolbar-button-enabled")).toBeVisible({ timeout: 10000 });

  const box = await page.locator("#routeGenLegMap").boundingBox();
  if (!box) {
    throw new Error("Map bounding box is unavailable.");
  }

  const p1 = { x: Math.round(box.width * 0.35), y: Math.round(box.height * 0.45) };
  const p2 = { x: Math.round(box.width * 0.55), y: Math.round(box.height * 0.40) };
  const p3 = { x: Math.round(box.width * 0.68), y: Math.round(box.height * 0.58) };

  const map = page.locator("#routeGenLegMap");
  await map.click({ position: p1 });
  await map.click({ position: p2 });
  await map.dblclick({ position: p3 });

  await expect(page.locator("#routeGenLegMapStatus")).toContainText(/Draft geometry updated/i, { timeout: 10000 });
  await expect.poll(async () => {
    const raw = await page.locator("#routeGenLegMapNm").textContent();
    const val = parseFloat(String(raw || "").replace(/[^0-9.]/g, ""));
    return Number.isFinite(val) ? val : 0;
  }, { timeout: 15000 }).toBeGreaterThan(0);

  await page.click("#routeGenLegSaveBtn");
  await expect(page.locator("#routeGenLegMapStatus")).toContainText(/saved/i, { timeout: 20000 });

  await page.click("#routeGenLegClearBtn");
  await page.click("#routeGenLegSaveBtn");
  await expect(page.locator("#routeGenLegMapSource")).toContainText(/default/i, { timeout: 20000 });

  await page.click("#routeGenLegOverlayCloseBtn");
  await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 10000 });
  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
});
