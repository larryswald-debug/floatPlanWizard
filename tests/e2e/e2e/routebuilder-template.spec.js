const { submitLoginForm } = require("./test-hooks");
const { createRouteBuilderCleanup } = require("../support/routebuilderCleanup");

if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
  throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
}

const { test, expect } = require("@playwright/test");

test.describe.configure({ timeout: 120000 });

/** @type {ReturnType<typeof createRouteBuilderCleanup> | null} */
let cleanup = null;

test.beforeEach(async ({ page }) => {
  cleanup = createRouteBuilderCleanup(page);
  await cleanup.resetRouteBuilderUserState({ logout: true });
});

test.afterEach(async () => {
  if (cleanup) {
    await cleanup.resetRouteBuilderUserState({ logout: true });
    cleanup = null;
  }
});

async function gotoWithRetry(page, url, retries = 1) {
  let lastError;
  for (let attempt = 0; attempt <= retries; attempt += 1) {
    try {
      await page.goto(url, { waitUntil: "domcontentloaded", timeout: 45000 });
      return;
    } catch (error) {
      lastError = error;
      if (attempt >= retries) {
        throw error;
      }
      await page.waitForTimeout(750);
    }
  }
  throw lastError;
}

async function closeRouteBuilderModal(page, timeoutMs) {
  const modal = page.locator("#routeBuilderModal");
  if (await modal.isVisible().catch(() => false)) {
    const closeBtn = page.locator("#routeGenCloseBtn, #routeGenCancelBtn").first();
    await expect(closeBtn).toBeVisible({ timeout: timeoutMs });
    await closeBtn.click({ timeout: Math.min(timeoutMs, 5000) });
  }

  await expect(modal).toBeHidden({ timeout: timeoutMs });
  await expect(page.locator(".modal-backdrop.show")).toHaveCount(0, { timeout: timeoutMs });
}

async function waitForPreviewWhenReady(page) {
  await page.waitForFunction(() => {
    return document.querySelectorAll("#routeGenLegList .fpw-routegen__leg").length > 0;
  }, { timeout: 30000 });
}

async function ensureRouteName(page, value) {
  const input = page.locator("#routeGenRouteName");
  await expect(input).toBeVisible({ timeout: 15000 });
  if (!String(await input.inputValue()).trim()) {
    await input.fill(value);
  }
}

async function loginToDashboard(page) {
  await submitLoginForm(page, { loginUrl: "/fpw/index.cfm", waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle");
  await expect(page).not.toHaveURL(/index\.cfm$/i);
  await gotoWithRetry(page, "/fpw/app/dashboard.cfm");
}

async function waitForRouteBuilderTestHook(page) {
  await page.waitForFunction(() => {
    const hook = window.FPW
      && window.FPW.DashboardModules
      && window.FPW.DashboardModules.routeBuilder
      && window.FPW.DashboardModules.routeBuilder.test;
    return !!(hook && typeof hook.isReady === "function" && hook.isReady());
  }, { timeout: 10000 });
}

async function selectTemplateByLabelContains(page, wantedText) {
  const matchedValue = await page.evaluate((needle) => {
    const sel = document.getElementById("routeGenTemplateSelect");
    const wanted = String(needle || "").trim().toLowerCase();
    if (!sel || !wanted) return "";
    const option = Array.from(sel.options || []).find((opt) => {
      const value = String(opt.value || "").trim();
      const label = String(opt.textContent || "").trim().toLowerCase();
      return value && label.indexOf(wanted) !== -1;
    });
    if (!option) return "";
    sel.value = option.value;
    sel.dispatchEvent(new Event("change", { bubbles: true }));
    return option.value;
  }, wantedText);
  expect(matchedValue).not.toBe("");
  return matchedValue;
}

async function selectFirstRealOption(page, selector) {
  const selectedValue = await page.locator(selector).evaluate((sel) => {
    const option = Array.from(sel.options || []).find((opt) => String(opt.value || "").trim());
    if (!option) return "";
    sel.value = option.value;
    sel.dispatchEvent(new Event("change", { bubbles: true }));
    return option.value;
  });
  expect(selectedValue).not.toBe("");
  return selectedValue;
}

async function prepareGreatLoopRoutePreview(page, routeName) {
  await page.click("#openRouteBuilderBtn");
  await expect(page.locator("#routeBuilderModal")).toBeVisible({ timeout: 15000 });
  await expect(page.locator("#fpwRouteGen")).toBeVisible({ timeout: 15000 });

  const today = new Date().toISOString().slice(0, 10);
  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenTemplateSelect");
    return !!sel && !sel.disabled && sel.options.length > 1;
  }, { timeout: 20000 });
  await selectTemplateByLabelContains(page, "great loop");
  await page.fill("#routeGenStartDate", today);

  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenStartLocation");
    return !!sel && sel.options.length > 1;
  }, { timeout: 20000 });
  await selectFirstRealOption(page, "#routeGenStartLocation");

  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenEndLocation");
    return !!sel && sel.options.length > 1;
  }, { timeout: 20000 });
  await selectFirstRealOption(page, "#routeGenEndLocation");

  await waitForPreviewWhenReady(page);
  await ensureRouteName(page, routeName);
}

async function snapshotPreviewLegs(page) {
  return page.evaluate(() => {
    return Array.from(document.querySelectorAll("#routeGenLegList .fpw-routegen__leg")).map((row) => {
      const nmEl = row.querySelector(".fpw-routegen__legnm");
      const nameEl = row.querySelector(".fpw-routegen__legname");
      const nmText = nmEl ? String(nmEl.textContent || "").trim() : "";
      const parsedNm = parseFloat(nmText.replace(/[^0-9.]/g, ""));
      return {
        order: parseInt(row.getAttribute("data-leg-order") || "0", 10),
        routeLegId: parseInt(row.getAttribute("data-route-leg-id") || "0", 10),
        segmentId: parseInt(row.getAttribute("data-segment-id") || "0", 10),
        hasOverride: !!row.querySelector(".fpw-routegen__flag--override"),
        distNm: Number.isFinite(parsedNm) ? parsedNm : 0,
        distText: nmText,
        name: nameEl ? String(nameEl.textContent || "").trim() : ""
      };
    });
  });
}

async function openLegMapForOrder(page, order) {
  await page.evaluate((legOrder) => {
    const btn = document.querySelector(`#routeGenLegList .fpw-routegen__leg[data-leg-order="${legOrder}"] [data-leg-action="open-map"]`);
    if (!btn) throw new Error("Open map button not found for leg order " + String(legOrder));
    btn.click();
  }, order);
  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 10000 });
  await expect(page.locator("#routeGenLegMap")).toBeVisible({ timeout: 10000 });
}

async function closeLegMapOverlay(page) {
  if (await page.locator("#routeGenLegOverlay").evaluate((el) => el.classList.contains("is-open")).catch(() => false)) {
    await page.click("#routeGenLegOverlayCloseBtn");
    await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 10000 });
  }
}

async function saveOverrideForLeg(page, order, points) {
  await openLegMapForOrder(page, order);
  await waitForRouteBuilderTestHook(page);
  const setResult = await page.evaluate((geometryPoints) => {
    return window.FPW.DashboardModules.routeBuilder.test.setDraftGeometry(geometryPoints);
  }, points);
  expect(setResult).toBeTruthy();
  await page.click("#routeGenLegSaveBtn");
  await expect(page.locator("#routeGenLegMapStatus")).toContainText(/saved/i, { timeout: 20000 });
  await closeLegMapOverlay(page);
}

async function loadLegGeometryPayload(page, order) {
  const responsePromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_getleggeometry");
  }, { timeout: 30000 });
  await openLegMapForOrder(page, order);
  const response = await responsePromise;
  const payload = await response.json();
  expect(!!(payload && payload.SUCCESS)).toBeTruthy();
  return payload;
}

test("Route Builder generates route from template and opens timeline editor", async ({ page }) => {
  await loginToDashboard(page);
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

  await waitForPreviewWhenReady(page);
  await page.waitForFunction(() => {
    const txt = document.getElementById("routeGenLegCount");
    if (!txt) return false;
    const n = parseInt((txt.textContent || "").replace(/[^0-9]/g, ""), 10);
    return Number.isFinite(n) && n > 0;
  }, { timeout: 30000 });
  await expect(page.locator("#routeGenLegList .fpw-routegen__leglocks").first()).toHaveText(/[0-9]+/, { timeout: 10000 });
  await ensureRouteName(page, "PW Route Template " + Date.now());

  const generateResponsePromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_generate");
  }, { timeout: 30000 });
  await page.click("#routeGenGenerateBtn");
  const generateResponse = await generateResponsePromise;
  const generatePayload = await generateResponse.json();
  expect(!!(generatePayload && generatePayload.SUCCESS)).toBeTruthy();
  await page.waitForFunction(() => {
    const alertEl = document.getElementById("dashboardAlert");
    if (!alertEl) return false;
    const text = String(alertEl.textContent || "");
    return /route generated successfully/i.test(text);
  }, { timeout: 12000 });
  await closeRouteBuilderModal(page, 30000);

  await page.click("#openRouteBuilderBtn");
  await expect(page.locator("#routeBuilderModal")).toBeVisible({ timeout: 15000 });
  await expect(page.locator("#routeGenRouteCode")).toContainText("Draft", { timeout: 10000 });
  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
});

test("Route Builder leg row opens lock panel, then map editor from button", async ({ page }) => {
  await loginToDashboard(page);
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

  await waitForPreviewWhenReady(page);
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
  const firstOpenMapBtn = page.locator('#routeGenLegList .fpw-routegen__leg [data-leg-action="open-map"]').first();
  await expect(firstOpenMapBtn).toBeVisible({ timeout: 15000 });
  await firstOpenMapBtn.click();
  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 10000 });
  await expect(page.locator("#routeGenLegMap")).toBeVisible({ timeout: 10000 });
  await expect(page.locator("#routeGenLegMapTitle")).toContainText("->", { timeout: 10000 });
  await expect(page.locator("#routeGenLegMap .leaflet-tooltip").filter({ hasText: "Start" }).first()).toBeVisible({ timeout: 10000 });
  await expect(page.locator("#routeGenLegMap .leaflet-tooltip").filter({ hasText: "End" }).first()).toBeVisible({ timeout: 10000 });
  await expect(page.locator("#routeGenLegSaveBtn")).toBeEnabled();
  await page.click("#routeGenLegOverlayCloseBtn");
  await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 10000 });
  const reopenOpenMapBtn = page.locator('#routeGenLegList .fpw-routegen__leg [data-leg-action="open-map"]').first();
  await expect(reopenOpenMapBtn).toBeVisible({ timeout: 15000 });
  await reopenOpenMapBtn.click();
  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 10000 });
  await expect(page.locator("#routeGenLegMap .leaflet-tooltip").filter({ hasText: "Start" }).first()).toBeVisible({ timeout: 10000 });
  await expect(page.locator("#routeGenLegMap .leaflet-tooltip").filter({ hasText: "End" }).first()).toBeVisible({ timeout: 10000 });
  await page.click("#routeGenLegOverlayCloseBtn");
  await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 10000 });
  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
  await page.click("#openRouteBuilderBtn");
  await expect(page.locator("#routeBuilderModal")).toBeVisible({ timeout: 15000 });
  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenTemplateSelect");
    return !!sel && !sel.disabled && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenTemplateSelect", { index: 1 });
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
  await waitForPreviewWhenReady(page);
  await page.waitForFunction(() => {
    return document.querySelectorAll("#routeGenLegList .fpw-routegen__leg").length > 0;
  }, { timeout: 30000 });
  const modalReopenOpenMapBtn = page.locator('#routeGenLegList .fpw-routegen__leg [data-leg-action="open-map"]').first();
  await expect(modalReopenOpenMapBtn).toBeVisible({ timeout: 30000 });
  await modalReopenOpenMapBtn.click();
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

  await loginToDashboard(page);
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

  await waitForPreviewWhenReady(page);
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
  await expect(page.locator("#routeGenLegMapStatus")).toContainText(/draft override cleared/i, { timeout: 20000 });

  await page.click("#routeGenLegOverlayCloseBtn");
  await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 10000 });
  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
});

test("Route Builder keeps override badges and edit truth through reverse and reopen", async ({ page }) => {
  await page.addInitScript(() => {
    window.__FPW_ENABLE_TEST_HOOKS = true;
  });

  function extractPreviewPayloadLegs(payload) {
    const data = payload && typeof payload === "object"
      ? (payload.DATA || payload.data || {})
      : {};
    const legs = Array.isArray(data.legs)
      ? data.legs
      : (Array.isArray(data.LEGS) ? data.LEGS : []);
    return legs.map((leg, index) => ({
      order: parseInt(leg.order_index ?? leg.ORDER_INDEX ?? (index + 1), 10) || 0,
      routeLegId: parseInt(leg.route_leg_id ?? leg.ROUTE_LEG_ID ?? 0, 10) || 0,
      segmentId: parseInt(leg.segment_id ?? leg.SEGMENT_ID ?? 0, 10) || 0,
      hasOverride: !!(leg.has_effective_override || leg.HAS_EFFECTIVE_OVERRIDE || leg.has_user_override || leg.HAS_USER_OVERRIDE),
      distText: String(leg.dist_nm ?? leg.DIST_NM ?? "")
    }));
  }

  function extractTimelinePayloadLegs(payload) {
    const sections = Array.isArray(payload && payload.SECTIONS) ? payload.SECTIONS : [];
    return sections.flatMap((section) => {
      const segs = Array.isArray(section && section.SEGMENTS) ? section.SEGMENTS : [];
      return segs.map((seg, index) => ({
        order: parseInt(seg.ORDER_INDEX ?? seg.order_index ?? (index + 1), 10) || 0,
        routeLegId: parseInt(seg.ID ?? seg.id ?? 0, 10) || 0,
        hasOverride: !!(seg.HAS_EFFECTIVE_OVERRIDE || seg.has_effective_override || seg.HAS_USER_OVERRIDE || seg.has_user_override),
        distText: String(seg.DIST_NM ?? seg.dist_nm ?? "")
      }));
    });
  }

  await loginToDashboard(page);
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 15000 });
  await prepareGreatLoopRoutePreview(page, "PW Override Reverse " + Date.now());
  await waitForRouteBuilderTestHook(page);

  const generateResponsePromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_generate");
  }, { timeout: 30000 });
  await page.click("#routeGenGenerateBtn");
  const generateResponse = await generateResponsePromise;
  const generatePayload = await generateResponse.json();
  expect(!!(generatePayload && generatePayload.SUCCESS)).toBeTruthy();
  const generateData = generatePayload.DATA || {};
  const routeCode = String(
    generateData.route_code !== undefined ? generateData.route_code :
      (generateData.ROUTE_CODE !== undefined ? generateData.ROUTE_CODE : (generatePayload.ROUTE_CODE || ""))
  ).trim();
  expect(routeCode).not.toBe("");
  await waitForPreviewWhenReady(page);

  const initialReloadResponsePromise = page.waitForResponse((response) => {
    return response.request().method() === "GET"
      && response.url().includes("action=getTimeline");
  }, { timeout: 30000 });
  await page.evaluate(() => {
    return window.FPW.DashboardModules.routeBuilder.reloadTimeline();
  });
  const initialReloadResponse = await initialReloadResponsePromise;
  const initialReloadPayload = await initialReloadResponse.json();
  expect(!!(initialReloadPayload && initialReloadPayload.SUCCESS)).toBeTruthy();
  await waitForPreviewWhenReady(page);

  const initialLegs = await snapshotPreviewLegs(page);
  expect(initialLegs.length).toBeGreaterThan(3);
  const overrideCandidates = initialLegs.filter((leg) => leg.routeLegId > 0).slice(0, 2);
  expect(overrideCandidates).toHaveLength(2);
  const overrideIds = overrideCandidates.map((leg) => leg.routeLegId).sort((a, b) => a - b);

  await saveOverrideForLeg(page, overrideCandidates[0].order, [
    { lat: 41.8781, lon: -87.6298 },
    { lat: 42.0200, lon: -87.3200 },
    { lat: 42.1800, lon: -86.9800 }
  ]);
  await saveOverrideForLeg(page, overrideCandidates[1].order, [
    { lat: 41.8000, lon: -87.6000 },
    { lat: 41.9500, lon: -87.1000 },
    { lat: 42.2200, lon: -86.7200 }
  ]);

  const savedLegs = await snapshotPreviewLegs(page);
  const savedBadges = savedLegs.filter((leg) => leg.hasOverride);
  expect(savedBadges).toHaveLength(2);
  expect(savedBadges.map((leg) => leg.routeLegId).sort((a, b) => a - b)).toEqual(overrideIds);

  const reversePreviewPromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_preview");
  }, { timeout: 30000 });
  await page.evaluate(() => {
    const toggle = document.getElementById("routeGenDirectionToggle");
    if (toggle) {
      toggle.checked = !toggle.checked;
      toggle.dispatchEvent(new Event("change", { bubbles: true }));
      return;
    }
    const select = document.getElementById("routeGenDirection");
    if (!select) throw new Error("Direction control not found.");
    select.value = String(select.value || "").toUpperCase() === "CW" ? "CCW" : "CW";
    select.dispatchEvent(new Event("change", { bubbles: true }));
  });
  const reversePreviewResponse = await reversePreviewPromise;
  const reversePreviewPayload = await reversePreviewResponse.json();
  expect(!!(reversePreviewPayload && reversePreviewPayload.SUCCESS)).toBeTruthy();
  const reversedPayloadLegs = extractPreviewPayloadLegs(reversePreviewPayload);
  const reversedPayloadBadges = reversedPayloadLegs.filter((leg) => leg.hasOverride);
  expect(reversedPayloadBadges).toHaveLength(2);
  expect(reversedPayloadBadges.map((leg) => leg.routeLegId).sort((a, b) => a - b)).toEqual(overrideIds);
  expect(reversedPayloadBadges.map((leg) => leg.order).sort((a, b) => a - b)).not.toEqual([1, 2]);

  await waitForPreviewWhenReady(page);
  const reversedLegs = await snapshotPreviewLegs(page);
  const reversedBadges = reversedLegs.filter((leg) => leg.hasOverride);
  expect(reversedBadges).toHaveLength(2);
  expect(reversedBadges.map((leg) => leg.routeLegId).sort((a, b) => a - b)).toEqual(overrideIds);
  expect(reversedBadges.map((leg) => leg.order).sort((a, b) => a - b)).toEqual(
    reversedPayloadBadges.map((leg) => leg.order).sort((a, b) => a - b)
  );

  const reversedOverrideLeg = reversedBadges[0];
  const reversedNonOverrideLeg = reversedLegs.find((leg) => {
    return leg.routeLegId > 0
      && !leg.hasOverride
      && overrideIds.indexOf(leg.routeLegId) === -1;
  });
  expect(reversedNonOverrideLeg).toBeTruthy();

  const reversedOverridePayload = await loadLegGeometryPayload(page, reversedOverrideLeg.order);
  expect(!!(reversedOverridePayload.DATA && reversedOverridePayload.DATA.has_override)).toBeTruthy();
  expect(parseInt(reversedOverridePayload.DATA.route_leg_id || 0, 10)).toBe(reversedOverrideLeg.routeLegId);
  await closeLegMapOverlay(page);

  const reversedNonOverridePayload = await loadLegGeometryPayload(page, reversedNonOverrideLeg.order);
  expect(!!(reversedNonOverridePayload.DATA && reversedNonOverridePayload.DATA.has_override)).toBeFalsy();
  expect(parseInt(reversedNonOverridePayload.DATA.route_leg_id || 0, 10)).toBe(reversedNonOverrideLeg.routeLegId);
  await closeLegMapOverlay(page);

  await closeRouteBuilderModal(page, 30000);
  const reopenPreviewPromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_preview");
  }, { timeout: 30000 });
  await page.evaluate((code) => {
    window.FPW.DashboardModules.routeBuilder.openEditorForRoute(code);
  }, routeCode);
  await expect(page.locator("#routeBuilderModal")).toBeVisible({ timeout: 15000 });
  const reopenPreviewResponse = await reopenPreviewPromise;
  const reopenPreviewPayload = await reopenPreviewResponse.json();
  expect(!!(reopenPreviewPayload && reopenPreviewPayload.SUCCESS)).toBeTruthy();
  const reopenedPreviewPayloadLegs = extractPreviewPayloadLegs(reopenPreviewPayload);
  const reopenedPreviewBadges = reopenedPreviewPayloadLegs.filter((leg) => leg.hasOverride);
  expect(reopenedPreviewBadges).toHaveLength(2);
  expect(reopenedPreviewBadges.map((leg) => leg.routeLegId).sort((a, b) => a - b)).toEqual(overrideIds);
  await waitForPreviewWhenReady(page);

  const reloadTimelineResponsePromise = page.waitForResponse((response) => {
    return response.request().method() === "GET"
      && response.url().includes("action=getTimeline");
  }, { timeout: 30000 });
  await page.evaluate(() => {
    return window.FPW.DashboardModules.routeBuilder.reloadTimeline();
  });
  const reloadTimelineResponse = await reloadTimelineResponsePromise;
  const reloadTimelinePayload = await reloadTimelineResponse.json();
  expect(!!(reloadTimelinePayload && reloadTimelinePayload.SUCCESS)).toBeTruthy();
  const reopenedTimelineLegs = extractTimelinePayloadLegs(reloadTimelinePayload);
  const reopenedTimelineBadges = reopenedTimelineLegs.filter((leg) => leg.hasOverride);
  expect(reopenedTimelineBadges).toHaveLength(2);
  expect(reopenedTimelineBadges.map((leg) => leg.routeLegId).sort((a, b) => a - b)).toEqual(overrideIds);
  await waitForPreviewWhenReady(page);

  const reopenedLegs = await snapshotPreviewLegs(page);
  const reopenedBadges = reopenedLegs.filter((leg) => leg.hasOverride);
  expect(reopenedBadges).toHaveLength(2);
  expect(reopenedBadges.map((leg) => leg.routeLegId).sort((a, b) => a - b)).toEqual(overrideIds);
  expect(reopenedBadges.map((leg) => leg.routeLegId).sort((a, b) => a - b)).toEqual(
    reopenedTimelineBadges.map((leg) => leg.routeLegId).sort((a, b) => a - b)
  );
  expect(reopenedBadges.map((leg) => leg.order).sort((a, b) => a - b)).toEqual(
    reopenedTimelineBadges.map((leg) => leg.order).sort((a, b) => a - b)
  );

  const reopenedNonOverrideLeg = reopenedLegs.find((leg) => {
    return leg.routeLegId > 0
      && !leg.hasOverride
      && overrideIds.indexOf(leg.routeLegId) === -1;
  });
  expect(reopenedNonOverrideLeg).toBeTruthy();

  const reopenedOverridePayload = await loadLegGeometryPayload(page, reopenedBadges[0].order);
  expect(!!(reopenedOverridePayload.DATA && reopenedOverridePayload.DATA.has_override)).toBeTruthy();
  expect(parseInt(reopenedOverridePayload.DATA.route_leg_id || 0, 10)).toBe(reopenedBadges[0].routeLegId);
  await closeLegMapOverlay(page);

  const reopenedNonOverridePayload = await loadLegGeometryPayload(page, reopenedNonOverrideLeg.order);
  expect(!!(reopenedNonOverridePayload.DATA && reopenedNonOverridePayload.DATA.has_override)).toBeFalsy();
  expect(parseInt(reopenedNonOverridePayload.DATA.route_leg_id || 0, 10)).toBe(reopenedNonOverrideLeg.routeLegId);
  await closeLegMapOverlay(page);

  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
});

test("Route Builder persists reversed existing route order and preserves override ownership on save", async ({ page }) => {
  await page.addInitScript(() => {
    window.__FPW_ENABLE_TEST_HOOKS = true;
  });

  function extractPreviewPayloadLegs(payload) {
    const data = payload && typeof payload === "object"
      ? (payload.DATA || payload.data || {})
      : {};
    const legs = Array.isArray(data.legs)
      ? data.legs
      : (Array.isArray(data.LEGS) ? data.LEGS : []);
    return legs.map((leg, index) => ({
      order: parseInt(leg.order_index ?? leg.ORDER_INDEX ?? (index + 1), 10) || 0,
      routeLegId: parseInt(leg.route_leg_id ?? leg.ROUTE_LEG_ID ?? 0, 10) || 0,
      segmentId: parseInt(leg.segment_id ?? leg.SEGMENT_ID ?? 0, 10) || 0,
      hasOverride: !!(leg.has_effective_override || leg.HAS_EFFECTIVE_OVERRIDE || leg.has_user_override || leg.HAS_USER_OVERRIDE),
      name: String(
        (leg.start_name ?? leg.START_NAME ?? "") + " -> " + (leg.end_name ?? leg.END_NAME ?? "")
      ).trim()
    }));
  }

  function extractTimelinePayloadLegs(payload) {
    const sections = Array.isArray(payload && payload.SECTIONS) ? payload.SECTIONS : [];
    return sections.flatMap((section) => {
      const segs = Array.isArray(section && section.SEGMENTS) ? section.SEGMENTS : [];
      return segs.map((seg, index) => ({
        order: parseInt(seg.ORDER_INDEX ?? seg.order_index ?? (index + 1), 10) || 0,
        routeLegId: parseInt(seg.ID ?? seg.id ?? 0, 10) || 0,
        segmentId: parseInt(seg.SEGMENT_ID ?? seg.segment_id ?? 0, 10) || 0,
        hasOverride: !!(seg.HAS_EFFECTIVE_OVERRIDE || seg.has_effective_override || seg.HAS_USER_OVERRIDE || seg.has_user_override),
        name: String((seg.START_NAME ?? "") + " -> " + (seg.END_NAME ?? "")).trim()
      }));
    });
  }

  function extractSequence(legs) {
    return legs.map((leg) => ({
      order: leg.order,
      routeLegId: leg.routeLegId,
      segmentId: leg.segmentId,
      hasOverride: !!leg.hasOverride,
      name: leg.name
    }));
  }

  function extractSegmentSequence(legs) {
    return legs.map((leg) => leg.segmentId);
  }

  function extractNameSequence(legs) {
    return legs.map((leg) => leg.name);
  }

  function extractRouteLegIdSequence(legs) {
    return legs.map((leg) => leg.routeLegId);
  }

  function extractOverrideRouteLegIds(legs) {
    return legs
      .filter((leg) => leg.hasOverride)
      .map((leg) => leg.routeLegId)
      .sort((a, b) => a - b);
  }

  function extractOverrideSegments(legs) {
    return legs
      .filter((leg) => leg.hasOverride)
      .map((leg) => leg.segmentId)
      .sort((a, b) => a - b);
  }

  const routeName = "PW Reverse Save Persist " + Date.now();

  await loginToDashboard(page);
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 15000 });
  await prepareGreatLoopRoutePreview(page, routeName);
  await waitForRouteBuilderTestHook(page);

  const generateResponsePromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_generate");
  }, { timeout: 30000 });
  await page.click("#routeGenGenerateBtn");
  const generateResponse = await generateResponsePromise;
  const generatePayload = await generateResponse.json();
  expect(!!(generatePayload && generatePayload.SUCCESS)).toBeTruthy();
  const generateData = generatePayload.DATA || {};
  const routeCode = String(
    generateData.route_code !== undefined ? generateData.route_code :
      (generateData.ROUTE_CODE !== undefined ? generateData.ROUTE_CODE : (generatePayload.ROUTE_CODE || ""))
  ).trim();
  expect(routeCode).not.toBe("");
  await waitForPreviewWhenReady(page);

  const initialTimelineResponsePromise = page.waitForResponse((response) => {
    return response.request().method() === "GET"
      && response.url().includes("action=getTimeline");
  }, { timeout: 30000 });
  await page.evaluate(() => {
    return window.FPW.DashboardModules.routeBuilder.reloadTimeline();
  });
  const initialTimelineResponse = await initialTimelineResponsePromise;
  const initialTimelinePayload = await initialTimelineResponse.json();
  expect(!!(initialTimelinePayload && initialTimelinePayload.SUCCESS)).toBeTruthy();
  await waitForPreviewWhenReady(page);

  const initialLegs = await snapshotPreviewLegs(page);
  expect(initialLegs.length).toBeGreaterThan(3);
  const initialOverrideLegs = initialLegs.filter((leg) => leg.routeLegId > 0).slice(0, 2);
  expect(initialOverrideLegs).toHaveLength(2);

  await saveOverrideForLeg(page, initialOverrideLegs[0].order, [
    { lat: 41.8781, lon: -87.6298 },
    { lat: 41.9500, lon: -87.3200 },
    { lat: 42.0200, lon: -86.9800 }
  ]);
  await saveOverrideForLeg(page, initialOverrideLegs[1].order, [
    { lat: 41.8200, lon: -87.6000 },
    { lat: 41.9300, lon: -87.1400 },
    { lat: 42.1100, lon: -86.7600 }
  ]);

  const liveSavedLegs = await snapshotPreviewLegs(page);
  expect(liveSavedLegs.filter((leg) => leg.hasOverride)).toHaveLength(2);

  await closeRouteBuilderModal(page, 30000);

  const originalReopenPreviewPromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_preview");
  }, { timeout: 30000 });
  await page.evaluate((code) => {
    window.FPW.DashboardModules.routeBuilder.openEditorForRoute(code);
  }, routeCode);
  await expect(page.locator("#routeBuilderModal")).toBeVisible({ timeout: 15000 });
  const originalReopenPreviewResponse = await originalReopenPreviewPromise;
  const originalReopenPreviewPayload = await originalReopenPreviewResponse.json();
  expect(!!(originalReopenPreviewPayload && originalReopenPreviewPayload.SUCCESS)).toBeTruthy();
  await waitForPreviewWhenReady(page);

  const originalExistingLegs = await snapshotPreviewLegs(page);
  const originalExistingSequence = extractSegmentSequence(originalExistingLegs);
  const originalOverrideSegments = extractOverrideSegments(originalExistingLegs);
  expect(originalOverrideSegments).toHaveLength(2);

  const originalTimelineResponsePromise = page.waitForResponse((response) => {
    return response.request().method() === "GET"
      && response.url().includes("action=getTimeline");
  }, { timeout: 30000 });
  await page.evaluate(() => {
    return window.FPW.DashboardModules.routeBuilder.reloadTimeline();
  });
  const originalTimelineResponse = await originalTimelineResponsePromise;
  const originalTimelinePayload = await originalTimelineResponse.json();
  expect(!!(originalTimelinePayload && originalTimelinePayload.SUCCESS)).toBeTruthy();
  const originalTimelineLegs = extractTimelinePayloadLegs(originalTimelinePayload);
  expect(extractRouteLegIdSequence(originalTimelineLegs)).toEqual(extractRouteLegIdSequence(originalExistingLegs));
  expect(extractOverrideRouteLegIds(originalTimelineLegs)).toEqual(extractOverrideRouteLegIds(originalExistingLegs));
  await waitForPreviewWhenReady(page);

  const reversePreviewPromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_preview");
  }, { timeout: 30000 });
  await page.evaluate(() => {
    const toggle = document.getElementById("routeGenDirectionToggle");
    if (toggle) {
      toggle.checked = !toggle.checked;
      toggle.dispatchEvent(new Event("change", { bubbles: true }));
      return;
    }
    const select = document.getElementById("routeGenDirection");
    if (!select) throw new Error("Direction control not found.");
    select.value = String(select.value || "").toUpperCase() === "CW" ? "CCW" : "CW";
    select.dispatchEvent(new Event("change", { bubbles: true }));
  });
  const reversePreviewResponse = await reversePreviewPromise;
  const reversePreviewPayload = await reversePreviewResponse.json();
  expect(!!(reversePreviewPayload && reversePreviewPayload.SUCCESS)).toBeTruthy();
  const reversedPreviewPayloadLegs = extractPreviewPayloadLegs(reversePreviewPayload);
  const reversedPreviewSequence = extractSegmentSequence(reversedPreviewPayloadLegs);
  expect(reversedPreviewSequence).not.toEqual(originalExistingSequence);
  expect(extractOverrideSegments(reversedPreviewPayloadLegs)).toEqual(originalOverrideSegments);

  await waitForPreviewWhenReady(page);
  const reversedPreviewLegs = await snapshotPreviewLegs(page);
  expect(extractSegmentSequence(reversedPreviewLegs)).toEqual(reversedPreviewSequence);
  expect(extractOverrideSegments(reversedPreviewLegs)).toEqual(originalOverrideSegments);

  const updateRequestPromise = page.waitForRequest((request) => {
    return request.method() === "POST"
      && request.url().includes("action=routegen_update");
  }, { timeout: 30000 });
  const updateResponsePromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_update");
  }, { timeout: 30000 });
  await page.click("#routeGenSaveBtn");
  const updateRequest = await updateRequestPromise;
  const updateResponse = await updateResponsePromise;
  const updatePayload = JSON.parse(updateRequest.postData() || "{}");
  const updateResponsePayload = await updateResponse.json();
  expect(!!(updateResponsePayload && updateResponsePayload.SUCCESS)).toBeTruthy();
  expect(String(updatePayload.route_code || "").trim()).toBe(routeCode);
  await waitForPreviewWhenReady(page);

  const postSaveTimelineResponsePromise = page.waitForResponse((response) => {
    return response.request().method() === "GET"
      && response.url().includes("action=getTimeline");
  }, { timeout: 30000 });
  await page.evaluate(() => {
    return window.FPW.DashboardModules.routeBuilder.reloadTimeline();
  });
  const postSaveTimelineResponse = await postSaveTimelineResponsePromise;
  const postSaveTimelinePayload = await postSaveTimelineResponse.json();
  expect(!!(postSaveTimelinePayload && postSaveTimelinePayload.SUCCESS)).toBeTruthy();
  const postSaveTimelineLegs = extractTimelinePayloadLegs(postSaveTimelinePayload);
  expect(extractNameSequence(postSaveTimelineLegs)).toEqual(extractNameSequence(reversedPreviewPayloadLegs));
  await waitForPreviewWhenReady(page);

  const postSaveLegs = await snapshotPreviewLegs(page);
  expect(extractRouteLegIdSequence(postSaveTimelineLegs)).toEqual(extractRouteLegIdSequence(postSaveLegs));
  expect(extractOverrideRouteLegIds(postSaveTimelineLegs)).toEqual(extractOverrideRouteLegIds(postSaveLegs));

  const postSaveOverrideLeg = postSaveTimelineLegs.find((leg) => {
    return leg.hasOverride;
  });
  const postSaveNonOverrideLeg = postSaveTimelineLegs.find((leg) => {
    return !leg.hasOverride;
  });
  expect(postSaveOverrideLeg).toBeTruthy();
  expect(postSaveNonOverrideLeg).toBeTruthy();

  const postSaveOverridePayload = await loadLegGeometryPayload(page, postSaveOverrideLeg.order);
  expect(!!(postSaveOverridePayload.DATA && postSaveOverridePayload.DATA.has_override)).toBeTruthy();
  expect(parseInt(postSaveOverridePayload.DATA.route_leg_id || 0, 10)).toBe(postSaveOverrideLeg.routeLegId);
  await closeLegMapOverlay(page);

  const postSaveNonOverridePayload = await loadLegGeometryPayload(page, postSaveNonOverrideLeg.order);
  expect(!!(postSaveNonOverridePayload.DATA && postSaveNonOverridePayload.DATA.has_override)).toBeFalsy();
  expect(parseInt(postSaveNonOverridePayload.DATA.route_leg_id || 0, 10)).toBe(postSaveNonOverrideLeg.routeLegId);
  await closeLegMapOverlay(page);

  await closeRouteBuilderModal(page, 30000);

  const reopenedPreviewPromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_preview");
  }, { timeout: 30000 });
  await page.evaluate((code) => {
    window.FPW.DashboardModules.routeBuilder.openEditorForRoute(code);
  }, routeCode);
  await expect(page.locator("#routeBuilderModal")).toBeVisible({ timeout: 15000 });
  const reopenedPreviewResponse = await reopenedPreviewPromise;
  const reopenedPreviewPayload = await reopenedPreviewResponse.json();
  expect(!!(reopenedPreviewPayload && reopenedPreviewPayload.SUCCESS)).toBeTruthy();
  const reopenedPreviewPayloadLegs = extractPreviewPayloadLegs(reopenedPreviewPayload);
  expect(extractSegmentSequence(reopenedPreviewPayloadLegs)).toEqual(reversedPreviewSequence);
  expect(extractOverrideSegments(reopenedPreviewPayloadLegs)).toEqual(originalOverrideSegments);
  await waitForPreviewWhenReady(page);

  const reopenedLegs = await snapshotPreviewLegs(page);
  expect(extractSegmentSequence(reopenedLegs)).toEqual(reversedPreviewSequence);
  expect(extractOverrideSegments(reopenedLegs)).toEqual(originalOverrideSegments);

  const reopenedTimelineResponsePromise = page.waitForResponse((response) => {
    return response.request().method() === "GET"
      && response.url().includes("action=getTimeline");
  }, { timeout: 30000 });
  await page.evaluate(() => {
    return window.FPW.DashboardModules.routeBuilder.reloadTimeline();
  });
  const reopenedTimelineResponse = await reopenedTimelineResponsePromise;
  const reopenedTimelinePayload = await reopenedTimelineResponse.json();
  expect(!!(reopenedTimelinePayload && reopenedTimelinePayload.SUCCESS)).toBeTruthy();
  const reopenedTimelineLegs = extractTimelinePayloadLegs(reopenedTimelinePayload);
  expect(extractRouteLegIdSequence(reopenedTimelineLegs)).toEqual(extractRouteLegIdSequence(reopenedLegs));
  expect(extractOverrideRouteLegIds(reopenedTimelineLegs)).toEqual(extractOverrideRouteLegIds(reopenedLegs));
  await waitForPreviewWhenReady(page);

  const reopenedOverrideLeg = reopenedLegs.find((leg) => {
    return leg.hasOverride && originalOverrideSegments.indexOf(leg.segmentId) !== -1;
  });
  const reopenedNonOverrideLeg = reopenedLegs.find((leg) => {
    return !leg.hasOverride && originalOverrideSegments.indexOf(leg.segmentId) === -1;
  });
  expect(reopenedOverrideLeg).toBeTruthy();
  expect(reopenedNonOverrideLeg).toBeTruthy();

  const reopenedOverridePayload = await loadLegGeometryPayload(page, reopenedOverrideLeg.order);
  expect(!!(reopenedOverridePayload.DATA && reopenedOverridePayload.DATA.has_override)).toBeTruthy();
  expect(parseInt(reopenedOverridePayload.DATA.route_leg_id || 0, 10)).toBe(reopenedOverrideLeg.routeLegId);
  await closeLegMapOverlay(page);

  const reopenedNonOverridePayload = await loadLegGeometryPayload(page, reopenedNonOverrideLeg.order);
  expect(!!(reopenedNonOverridePayload.DATA && reopenedNonOverridePayload.DATA.has_override)).toBeFalsy();
  expect(parseInt(reopenedNonOverridePayload.DATA.route_leg_id || 0, 10)).toBe(reopenedNonOverrideLeg.routeLegId);
  await closeLegMapOverlay(page);

  console.log("PW_REVERSE_SAVE_PROOF " + JSON.stringify({
    routeName,
    routeCode,
    originalExistingSequence: extractSequence(originalExistingLegs),
    reversedPreviewSequence: extractSequence(reversedPreviewLegs),
    updatePayload: {
      route_code: String(updatePayload.route_code || ""),
      direction: String(updatePayload.direction || ""),
      start_segment_id: String(updatePayload.start_segment_id || ""),
      end_segment_id: String(updatePayload.end_segment_id || "")
    },
    postSaveSequence: extractSequence(postSaveTimelineLegs),
    reopenedSequence: extractSequence(reopenedLegs),
    originalOverrideSegments,
    postSaveOverrideSegments: extractOverrideSegments(postSaveTimelineLegs),
    reopenedOverrideSegments: extractOverrideSegments(reopenedLegs)
  }));

  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
});

test("Route Builder keeps manual weather factor payload while weather assist stays hidden", async ({ page }) => {
  let lastPreviewWeatherFactor = "";

  await page.route("**/api/v1/routeBuilder.cfc?*", async (route) => {
    const request = route.request();
    if (/action=routegen_preview/i.test(request.url()) && request.method() === "POST") {
      try {
        const raw = request.postData() || "{}";
        const parsed = JSON.parse(raw);
        lastPreviewWeatherFactor = String(
          parsed.weather_factor_pct !== undefined && parsed.weather_factor_pct !== null
            ? parsed.weather_factor_pct
            : ""
        ).trim();
      } catch (err) {
        lastPreviewWeatherFactor = "";
      }
    }
    await route.continue();
  });

  await loginToDashboard(page);
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 15000 });

  await page.evaluate(() => {
    var weatherZipInput = document.getElementById("weatherZip");
    if (!weatherZipInput) return;
    weatherZipInput.value = "33708";
    weatherZipInput.dispatchEvent(new Event("input", { bubbles: true }));
    weatherZipInput.dispatchEvent(new Event("change", { bubbles: true }));
  });

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

  await waitForPreviewWhenReady(page);
  await expect(page.locator("#routeGenWeatherAssist")).toBeHidden({ timeout: 10000 });
  await expect(page.locator("#routeGenWeatherFactorPct")).toBeVisible({ timeout: 10000 });

  const previewRefreshPromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_preview");
  }, { timeout: 30000 });
  await page.fill("#routeGenWeatherFactorPct", "13");
  await page.dispatchEvent("#routeGenWeatherFactorPct", "input");
  await page.dispatchEvent("#routeGenWeatherFactorPct", "change");
  await expect(page.locator("#routeGenWeatherFactorPct")).toHaveValue("13");

  await previewRefreshPromise;
  await waitForPreviewWhenReady(page);
  await page.waitForFunction(() => {
    const rows = document.querySelectorAll("#routeGenLegList .fpw-routegen__leg");
    return rows.length > 0;
  }, { timeout: 30000 });
  expect(lastPreviewWeatherFactor).toBe("13");

  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
});



























