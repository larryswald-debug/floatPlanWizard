require("./test-hooks");

if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
  throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
}

const { test, expect } = require("@playwright/test");

test.describe.configure({ timeout: 180000 });

async function loginToDashboard(page) {
  await page.goto("/fpw/index.cfm", { waitUntil: "domcontentloaded" });
  await page.fill('input[name="email"], input[name="EMAIL"]', process.env.FPW_EMAIL || "");
  await page.fill('input[type="password"], input[name="password"], input[name="PASSWORD"]', process.env.FPW_PASSWORD || "");
  await page.click('button[type="submit"], input[type="submit"]');
  await page.waitForLoadState("networkidle");
  await expect(page).not.toHaveURL(/index\.cfm$/i);
  if (!/\/fpw\/app\/dashboard\.cfm/i.test(page.url())) {
    await page.goto("/fpw/app/dashboard.cfm", { waitUntil: "domcontentloaded" });
  }
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 15000 });
}

async function openRouteBuilderWithSelections(page) {
  await page.click("#openRouteBuilderBtn");
  const routeBuilderModal = page.locator("#routeBuilderModal");
  const openedByClick = await routeBuilderModal.waitFor({ state: "visible", timeout: 5000 })
    .then(() => true)
    .catch(() => false);
  if (!openedByClick) {
    await page.evaluate(() => {
      const openBtn = document.getElementById("openRouteBuilderBtn");
      if (openBtn) {
        openBtn.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, view: window }));
      }
      const modalEl = document.getElementById("routeBuilderModal");
      if (!modalEl || !window.bootstrap || !window.bootstrap.Modal) return;
      window.bootstrap.Modal.getOrCreateInstance(modalEl).show();
    });
  }
  await expect(routeBuilderModal).toBeVisible({ timeout: 15000 });
  await expect(page.locator("#fpwRouteGen")).toBeVisible({ timeout: 15000 });

  const today = new Date().toISOString().slice(0, 10);
  let templateReady = await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenTemplateSelect");
    return !!sel && !sel.disabled && sel.options.length > 1;
  }, { timeout: 20000 }).then(() => true).catch(() => false);
  if (!templateReady) {
    await page.click("#routeGenCancelBtn").catch(() => {});
    await expect(routeBuilderModal).toBeHidden({ timeout: 15000 });
    await page.click("#openRouteBuilderBtn");
    await expect(routeBuilderModal).toBeVisible({ timeout: 15000 });
    templateReady = await page.waitForFunction(() => {
      const sel = document.getElementById("routeGenTemplateSelect");
      return !!sel && !sel.disabled && sel.options.length > 1;
    }, { timeout: 30000 }).then(() => true).catch(() => false);
  }
  expect(templateReady).toBeTruthy();
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

async function runPreviewCycle(page) {
  const previewBtn = page.locator("#routeGenPreviewBtn");
  await expect(previewBtn).toBeVisible({ timeout: 30000 });
  await expect(previewBtn).toBeEnabled({ timeout: 60000 });
  const startedAt = Date.now();
  await page.evaluate(() => {
    const button = document.getElementById("routeGenPreviewBtn");
    if (!button) {
      throw new Error("Preview button not found.");
    }
    button.click();
  });
  await page.waitForFunction(() => {
    return document.querySelectorAll("#routeGenLegList .fpw-routegen__leg").length > 0;
  }, { timeout: 30000 });
  return Date.now() - startedAt;
}

async function findFirstSegmentLegOrder(page) {
  const legOrder = await page.evaluate(() => {
    const rows = Array.from(document.querySelectorAll("#routeGenLegList .fpw-routegen__leg"));
    const row = rows.find((entry) => {
      const segmentId = parseInt(entry.getAttribute("data-segment-id") || "0", 10);
      return Number.isFinite(segmentId) && segmentId > 0;
    });
    return row ? String(row.getAttribute("data-leg-order") || "") : "";
  });
  expect(legOrder).not.toEqual("");
  return legOrder;
}

async function openMapForLeg(page, legOrder) {
  await page.evaluate((orderText) => {
    const button = document.querySelector(`#routeGenLegList .fpw-routegen__leg[data-leg-order="${orderText}"] [data-leg-action="open-map"]`);
    if (!button) throw new Error("Open map button not found.");
    button.click();
  }, String(legOrder));
  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 10000 });
  await expect(page.locator("#routeGenLegMap")).toBeVisible({ timeout: 10000 });
}

function geometryForIndex(index) {
  const baseLat = 41.7 + (index * 0.07);
  const baseLon = -87.8 + (index * 0.05);
  return [
    { lat: baseLat, lon: baseLon },
    { lat: baseLat + 0.15, lon: baseLon + 0.25 },
    { lat: baseLat + 0.30, lon: baseLon + 0.45 }
  ];
}

function maxOf(values) {
  return values.reduce((maxVal, value) => (value > maxVal ? value : maxVal), 0);
}

function avgOf(values) {
  if (!values.length) return 0;
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function performanceBudgets(browserName) {
  if (browserName === "firefox") {
    return {
      previewMaxMs: 40000,
      previewAvgMs: 18000,
      mapCycleMaxMs: 15000,
      saveMaxMs: 25000,
      clearMaxMs: 25000
    };
  }
  if (browserName === "webkit") {
    return {
      previewMaxMs: 45000,
      previewAvgMs: 20000,
      mapCycleMaxMs: 18000,
      saveMaxMs: 28000,
      clearMaxMs: 28000
    };
  }
  return {
    previewMaxMs: 30000,
    previewAvgMs: 12000,
    mapCycleMaxMs: 12000,
    saveMaxMs: 20000,
    clearMaxMs: 20000
  };
}

test("Route Builder handles repeated preview/map/save cycles within performance budget", async ({ page, browserName }, testInfo) => {
  const budgets = performanceBudgets(browserName);

  await page.addInitScript(() => {
    window.__FPW_ENABLE_TEST_HOOKS = true;
  });

  await loginToDashboard(page);
  await openRouteBuilderWithSelections(page);

  const previewDurations = [];
  for (let i = 0; i < 4; i += 1) {
    previewDurations.push(await runPreviewCycle(page));
  }

  await waitForTestHook(page);
  const legOrder = await findFirstSegmentLegOrder(page);

  const mapCycleDurations = [];
  for (let i = 0; i < 6; i += 1) {
    const startedAt = Date.now();
    await openMapForLeg(page, legOrder);
    await page.click("#routeGenLegOverlayCloseBtn");
    await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 10000 });
    mapCycleDurations.push(Date.now() - startedAt);
  }

  await openMapForLeg(page, legOrder);
  const saveDurations = [];
  const clearDurations = [];
  for (let i = 0; i < 3; i += 1) {
    const setResult = await page.evaluate((points) => {
      return window.FPW.DashboardModules.routeBuilder.test.setDraftGeometry(points);
    }, geometryForIndex(i));
    expect(setResult).toBeTruthy();

    const saveStartedAt = Date.now();
    await page.click("#routeGenLegSaveBtn");
    await expect(page.locator("#routeGenLegMapStatus")).toContainText(/saved/i, { timeout: 20000 });
    saveDurations.push(Date.now() - saveStartedAt);

    const clearStartedAt = Date.now();
    await page.click("#routeGenLegClearBtn");
    await page.click("#routeGenLegSaveBtn");
    await expect(page.locator("#routeGenLegMapSource")).toContainText(/default/i, { timeout: 20000 });
    clearDurations.push(Date.now() - clearStartedAt);
  }

  const metrics = {
    preview_ms: previewDurations,
    preview_avg_ms: Math.round(avgOf(previewDurations)),
    preview_max_ms: maxOf(previewDurations),
    map_cycle_ms: mapCycleDurations,
    map_cycle_avg_ms: Math.round(avgOf(mapCycleDurations)),
    map_cycle_max_ms: maxOf(mapCycleDurations),
    save_ms: saveDurations,
    save_max_ms: maxOf(saveDurations),
    clear_ms: clearDurations,
    clear_max_ms: maxOf(clearDurations)
  };

  await testInfo.attach("routebuilder-performance-metrics.json", {
    body: JSON.stringify(metrics, null, 2),
    contentType: "application/json"
  });

  expect(metrics.preview_max_ms).toBeLessThan(budgets.previewMaxMs);
  expect(metrics.preview_avg_ms).toBeLessThan(budgets.previewAvgMs);
  expect(metrics.map_cycle_max_ms).toBeLessThan(budgets.mapCycleMaxMs);
  expect(metrics.save_max_ms).toBeLessThan(budgets.saveMaxMs);
  expect(metrics.clear_max_ms).toBeLessThan(budgets.clearMaxMs);

  await page.click("#routeGenLegOverlayCloseBtn");
  await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 10000 });
  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
});
