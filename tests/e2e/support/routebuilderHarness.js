const { expect } = require("@playwright/test");
const { submitLoginForm } = require("../e2e/test-hooks");

const ROUTE_BUILDER_MODAL_SELECTOR = "#routeBuilderModal";
const ROUTE_BUILDER_BODY_SELECTOR = "#fpwRouteGen";
const GREAT_LOOP_LABEL = "great loop";

function readRouteBuilderCredentials() {
  const email = String(process.env.FPW_EMAIL || "").trim();
  const password = String(process.env.FPW_PASSWORD || "").trim();
  if (!email || !password) {
    throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
  }
  return { email, password };
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function parseRequestBody(request) {
  const raw = String(request.postData() || "");
  if (!raw) {
    return { raw, parsed: {} };
  }
  try {
    return { raw, parsed: JSON.parse(raw) };
  } catch (error) {
    const params = new URLSearchParams(raw);
    const parsed = {};
    for (const [key, value] of params.entries()) {
      parsed[key] = value;
    }
    return { raw, parsed };
  }
}

async function postJson(page, url, data) {
  const response = await page.context().request.post(url, { data });
  const status = response.status();
  const contentType = String(response.headers()["content-type"] || "").trim();
  const text = await response.text();
  if (!String(text || "").trim()) {
    const error = new Error(`Empty response from ${url} (status ${status}, content-type ${contentType || "unknown"}).`);
    error.responseStatus = status;
    error.responseContentType = contentType;
    error.responseBody = text;
    throw error;
  }
  try {
    return JSON.parse(text);
  } catch (parseError) {
    const preview = text.slice(0, 500);
    const error = new Error(`Non-JSON response from ${url} (status ${status}, content-type ${contentType || "unknown"}): ${preview}`);
    error.responseStatus = status;
    error.responseContentType = contentType;
    error.responseBody = text;
    error.parseError = parseError;
    throw error;
  }
}

async function getJson(page, url) {
  const response = await page.context().request.get(url);
  return response.json();
}

async function callRouteBuilderAction(page, action, body) {
  return postJson(page, `/fpw/api/v1/routeBuilder.cfc?method=handle&action=${encodeURIComponent(action)}`, body || {});
}

async function callWaypointAction(page, action, body) {
  return postJson(page, `/fpw/api/v1/waypoint.cfc?method=handle&action=${encodeURIComponent(action)}`, body || {});
}

async function waitForDashboardReady(page) {
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 30000 });
  await expect(page.locator("#expeditionTimelinePanel")).toBeVisible({ timeout: 30000 });
}

async function loginRouteBuilderUser(page, options) {
  const opts = options || {};
  const creds = readRouteBuilderCredentials();
  await submitLoginForm(page, {
    loginUrl: "/fpw/index.cfm",
    waitUntil: "domcontentloaded",
    email: opts.email || creds.email,
    password: opts.password || creds.password
  });
  const reachedDashboard = await page.waitForURL(/\/fpw\/app\/dashboard\.cfm/i, {
    timeout: 30000
  }).then(() => true).catch(() => false);
  if (!reachedDashboard) {
    await page.goto("/fpw/app/dashboard.cfm", { waitUntil: "domcontentloaded" });
  }
  await waitForDashboardReady(page);
}

async function loginRouteBuilderUserViaApi(page, options) {
  const opts = options || {};
  const creds = readRouteBuilderCredentials();
  const payload = await postJson(page, "/fpw/api/v1/auth.cfc?method=handle", {
    email: opts.email || creds.email,
    password: opts.password || creds.password
  });
  expect(!!(payload && payload.SUCCESS)).toBeTruthy();
  await gotoDashboard(page);
  return payload;
}

async function logoutRouteBuilderUser(page) {
  const logoutBtn = page.locator("#logoutButton");
  if (!(await logoutBtn.count())) {
    await page.goto("/fpw/index.cfm", { waitUntil: "domcontentloaded" });
    return;
  }
  await Promise.allSettled([
    page.waitForURL(/\/fpw\/index\.cfm/i, { timeout: 30000 }),
    logoutBtn.click()
  ]);
  const loginEmail = page.locator('input[name="email"], input[name="EMAIL"]').first();
  const dashboardBtn = page.locator("#openRouteBuilderBtn");
  await Promise.race([
    loginEmail.waitFor({ state: "visible", timeout: 30000 }).catch(() => null),
    dashboardBtn.waitFor({ state: "hidden", timeout: 30000 }).catch(() => null)
  ]);
}

async function logoutRouteBuilderUserViaApi(page) {
  const payload = await postJson(page, "/fpw/api/v1/auth.cfc?method=handle", {
    action: "logout"
  });
  expect(!!(payload && payload.SUCCESS)).toBeTruthy();
  await page.goto("/fpw/index.cfm", { waitUntil: "domcontentloaded" });
  const loginEmail = page.locator('input[name="email"], input[name="EMAIL"]').first();
  await loginEmail.waitFor({ state: "visible", timeout: 30000 }).catch(() => null);
  return payload;
}

async function gotoDashboard(page) {
  await page.goto("/fpw/app/dashboard.cfm", { waitUntil: "domcontentloaded" });
  await waitForDashboardReady(page);
}

async function reloadDashboard(page) {
  await page.reload({ waitUntil: "domcontentloaded" });
  await waitForDashboardReady(page);
}

async function openRouteBuilder(page) {
  const openBtn = page.locator("#openRouteBuilderBtn");
  await expect(openBtn).toBeVisible({ timeout: 30000 });
  await openBtn.click();
  const modal = page.locator(ROUTE_BUILDER_MODAL_SELECTOR);
  const opened = await modal.waitFor({ state: "visible", timeout: 5000 })
    .then(() => true)
    .catch(() => false);
  if (!opened) {
    await page.evaluate(() => {
      const openButton = document.getElementById("openRouteBuilderBtn");
      if (openButton) {
        openButton.dispatchEvent(new MouseEvent("click", {
          bubbles: true,
          cancelable: true,
          view: window
        }));
      }
      const modalEl = document.getElementById("routeBuilderModal");
      if (modalEl && window.bootstrap && window.bootstrap.Modal) {
        window.bootstrap.Modal.getOrCreateInstance(modalEl).show();
      }
    });
  }
  await expect(modal).toBeVisible({ timeout: 30000 });
  await expect(page.locator(ROUTE_BUILDER_BODY_SELECTOR)).toBeVisible({ timeout: 30000 });
}

async function closeRouteBuilder(page) {
  const modal = page.locator(ROUTE_BUILDER_MODAL_SELECTOR);
  if (await modal.isVisible().catch(() => false)) {
    const closeBtn = page.locator("#routeGenCloseBtn, #routeGenCancelBtn").first();
    await expect(closeBtn).toBeVisible({ timeout: 15000 });
    await closeBtn.click({ timeout: 5000 });
  }
  await expect(modal).toBeHidden({ timeout: 30000 });
  await expect(page.locator(".modal-backdrop.show")).toHaveCount(0, { timeout: 30000 });
}

async function waitForRouteBuilderReady(page) {
  await expect(page.locator(ROUTE_BUILDER_MODAL_SELECTOR)).toBeVisible({ timeout: 30000 });
  await expect(page.locator(ROUTE_BUILDER_BODY_SELECTOR)).toBeVisible({ timeout: 30000 });
}

async function waitForPreviewReady(page) {
  await page.waitForFunction(() => {
    return document.querySelectorAll("#routeGenLegList .fpw-routegen__leg").length > 0;
  }, { timeout: 30000 });
}

async function waitForRouteBuilderTestHook(page) {
  await page.waitForFunction(() => {
    const hook = window.FPW
      && window.FPW.DashboardModules
      && window.FPW.DashboardModules.routeBuilder
      && window.FPW.DashboardModules.routeBuilder.test;
    return !!(hook && typeof hook.isReady === "function" && hook.isReady());
  }, { timeout: 15000 });
}

async function selectOptionContainingText(page, selector, text) {
  await page.waitForFunction(([selectSelector, wantedText]) => {
    const select = document.querySelector(selectSelector);
    if (!select) return false;
    return Array.from(select.options || []).some((option) => {
      const value = String(option.value || "").trim();
      const label = String(option.textContent || "").trim().toLowerCase();
      return value && label.includes(String(wantedText || "").trim().toLowerCase());
    });
  }, [selector, text], { timeout: 30000 });

  const value = await page.locator(selector).evaluate((select, wantedText) => {
    const target = Array.from(select.options || []).find((option) => {
      const value = String(option.value || "").trim();
      const label = String(option.textContent || "").trim().toLowerCase();
      return value && label.includes(String(wantedText || "").trim().toLowerCase());
    });
    if (!target) return "";
    select.value = target.value;
    select.dispatchEvent(new Event("change", { bubbles: true }));
    return target.value;
  }, text);
  expect(value).not.toBe("");
  return value;
}

async function selectFirstRealOption(page, selector) {
  await page.waitForFunction((selectSelector) => {
    const select = document.querySelector(selectSelector);
    return !!select && Array.from(select.options || []).some((option) => String(option.value || "").trim());
  }, selector, { timeout: 30000 });

  const value = await page.locator(selector).evaluate((select) => {
    const target = Array.from(select.options || []).find((option) => String(option.value || "").trim());
    if (!target) return "";
    select.value = target.value;
    select.dispatchEvent(new Event("change", { bubbles: true }));
    return target.value;
  });
  expect(value).not.toBe("");
  return value;
}

async function ensureRouteName(page, routeName) {
  const input = page.locator("#routeGenRouteName");
  await expect(input).toBeVisible({ timeout: 15000 });
  if (!String(await input.inputValue()).trim()) {
    await input.fill(routeName);
  }
}

async function setDirection(page, direction) {
  const normalized = String(direction || "").trim().toUpperCase() === "CW" ? "CW" : "CCW";
  const hiddenInput = page.locator("#routeGenDirection");
  const toggle = page.locator("#routeGenDirectionToggle");
  await expect(hiddenInput).toHaveValue(/CW|CCW/, { timeout: 15000 });
  if ((await hiddenInput.inputValue()).toUpperCase() === normalized) {
    return normalized;
  }
  if (await toggle.count()) {
    await toggle.click();
  } else {
    await hiddenInput.selectOption(normalized);
  }
  await expect(hiddenInput).toHaveValue(normalized, { timeout: 15000 });
  return normalized;
}

async function prepareGreatLoopPreview(page, options) {
  const opts = options || {};
  const routeName = String(opts.routeName || "").trim();
  const direction = String(opts.direction || "CCW").trim().toUpperCase();
  const today = opts.startDate || new Date().toISOString().slice(0, 10);

  await openRouteBuilder(page);
  await selectOptionContainingText(page, "#routeGenTemplateSelect", opts.templateLabel || GREAT_LOOP_LABEL);
  await setDirection(page, direction);
  await page.fill("#routeGenStartDate", today);
  await selectFirstRealOption(page, "#routeGenStartLocation");
  await selectFirstRealOption(page, "#routeGenEndLocation");
  await waitForPreviewReady(page);
  if (routeName) {
    await ensureRouteName(page, routeName);
  }
}

async function snapshotPreviewLegs(page) {
  return page.evaluate(() => {
    return Array.from(document.querySelectorAll("#routeGenLegList .fpw-routegen__leg")).map((row) => {
      const title = row.querySelector(".fpw-routegen__legname");
      const dist = row.querySelector(".fpw-routegen__legnm");
      return {
        order: parseInt(row.getAttribute("data-leg-order") || "0", 10) || 0,
        routeLegId: parseInt(row.getAttribute("data-route-leg-id") || "0", 10) || 0,
        segmentId: parseInt(row.getAttribute("data-segment-id") || "0", 10) || 0,
        hasOverride: !!row.querySelector(".fpw-routegen__flag--override"),
        name: String(title ? title.textContent || "" : "").trim(),
        distText: String(dist ? dist.textContent || "" : "").trim()
      };
    });
  });
}

async function snapshotCurrentControls(page) {
  return page.evaluate(() => {
    return {
      routeCode: String(document.querySelector("#routeGenRouteCode")?.textContent || "").trim(),
      direction: String(document.querySelector("#routeGenDirection")?.value || "").trim(),
      startSegmentId: String(document.querySelector("#routeGenStartLocation")?.value || "").trim(),
      endSegmentId: String(document.querySelector("#routeGenEndLocation")?.value || "").trim(),
      saveDisabled: !!document.querySelector("#routeGenSaveBtn")?.disabled,
      previewDisabled: !!document.querySelector("#routeGenPreviewBtn")?.disabled
    };
  });
}

async function generateRoute(page) {
  const responsePromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_generate");
  }, { timeout: 30000 });
  await page.click("#routeGenGenerateBtn");
  const response = await responsePromise;
  const payload = await response.json();
  expect(!!(payload && payload.SUCCESS)).toBeTruthy();
  await waitForPreviewReady(page);
  const routeCode = String(
    payload?.DATA?.route_code
    || payload?.DATA?.ROUTE_CODE
    || payload?.ROUTE_CODE
    || ""
  ).trim();
  expect(routeCode).not.toBe("");
  return { routeCode, payload };
}

async function saveRoute(page) {
  const requestPromise = page.waitForRequest((request) => {
    return request.method() === "POST"
      && request.url().includes("action=routegen_update");
  }, { timeout: 30000 });
  const responsePromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_update");
  }, { timeout: 30000 });
  await page.click("#routeGenSaveBtn");
  const request = await requestPromise;
  const response = await responsePromise;
  const requestInfo = parseRequestBody(request);
  const payload = await response.json();
  expect(!!(payload && payload.SUCCESS)).toBeTruthy();
  await page.waitForFunction(() => !document.querySelector("#routeGenSaveBtn")?.disabled, null, {
    timeout: 30000
  });
  await waitForPreviewReady(page);
  return {
    requestBody: requestInfo.parsed,
    requestRaw: requestInfo.raw,
    responsePayload: payload
  };
}

async function reverseRoute(page) {
  const responsePromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_preview");
  }, { timeout: 30000 });
  const toggle = page.locator("#routeGenDirectionToggle");
  if (await toggle.count()) {
    await toggle.click();
  } else {
    const select = page.locator("#routeGenDirection");
    const current = String(await select.inputValue()).toUpperCase();
    await select.selectOption(current === "CW" ? "CCW" : "CW");
  }
  const response = await responsePromise;
  const payload = await response.json();
  expect(!!(payload && payload.SUCCESS)).toBeTruthy();
  await page.waitForFunction(() => !document.querySelector("#routeGenSaveBtn")?.disabled, null, {
    timeout: 30000
  });
  await waitForPreviewReady(page);
  return payload;
}

async function reverseRouteTimes(page, count) {
  let payload = null;
  for (let i = 0; i < count; i += 1) {
    payload = await reverseRoute(page);
  }
  return payload;
}

async function reloadTimeline(page) {
  const responsePromise = page.waitForResponse((response) => {
    return response.request().method() === "GET"
      && response.url().includes("action=getTimeline");
  }, { timeout: 30000 });
  await page.evaluate(() => {
    return window.FPW.DashboardModules.routeBuilder.reloadTimeline();
  });
  const response = await responsePromise;
  const payload = await response.json();
  expect(!!(payload && payload.SUCCESS)).toBeTruthy();
  await waitForPreviewReady(page);
  return payload;
}

async function openEditorForRouteDirect(page, routeCode) {
  const previewPromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_preview");
  }, { timeout: 30000 });
  await page.evaluate((code) => {
    window.FPW.DashboardModules.routeBuilder.openEditorForRoute(code);
  }, routeCode);
  await waitForRouteBuilderReady(page);
  const response = await previewPromise;
  const payload = await response.json();
  expect(!!(payload && payload.SUCCESS)).toBeTruthy();
  await waitForPreviewReady(page);
  return payload;
}

async function reopenExistingRouteFromDashboard(page, routeCode) {
  const card = page.locator(`[data-route-code="${routeCode}"]`).first();
  await expect(card).toBeVisible({ timeout: 30000 });
  const editBtn = card.locator(".js-expedition-view-edit");
  await expect(editBtn).toBeVisible({ timeout: 30000 });
  const editContextPromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_geteditcontext")
      && String(response.request().postData() || "").includes(String(routeCode || ""));
  }, { timeout: 30000 });
  const routegenPreviewPromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_preview");
  }, { timeout: 30000 }).catch(() => null);
  const myRoutePreviewPromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=previewUserRoute");
  }, { timeout: 30000 }).catch(() => null);
  await editBtn.click();
  await waitForRouteBuilderReady(page);
  const editContextResponse = await editContextPromise;
  const editContextPayload = await editContextResponse.json();
  expect(!!(editContextPayload && editContextPayload.SUCCESS)).toBeTruthy();
  const editContextData = editContextPayload.DATA || {};
  const editContextInputs = editContextData.inputs || editContextData;
  const routeType = String(
    editContextInputs.route_type !== undefined ? editContextInputs.route_type :
      (editContextInputs.ROUTE_TYPE !== undefined ? editContextInputs.ROUTE_TYPE : "")
  ).trim().toLowerCase();
  const response = (
    routeType === "my_route"
      || routeType === "my_routes"
      || routeType === "custom"
  )
    ? await myRoutePreviewPromise
    : await routegenPreviewPromise;
  expect(response, `Route ${routeCode} did not emit the expected preview response during reopen.`).toBeTruthy();
  const payload = await response.json();
  expect(!!(payload && payload.SUCCESS)).toBeTruthy();
  await waitForPreviewReady(page);
  return payload;
}

async function openLegMapForOrder(page, order) {
  await page.evaluate((legOrder) => {
    const button = document.querySelector(`#routeGenLegList .fpw-routegen__leg[data-leg-order="${legOrder}"] [data-leg-action="open-map"]`);
    if (!button) {
      throw new Error("Open map button not found for leg order " + String(legOrder));
    }
    button.click();
  }, order);
  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 10000 });
  await expect(page.locator("#routeGenLegMap")).toBeVisible({ timeout: 10000 });
}

async function closeLegMapOverlay(page) {
  const overlay = page.locator("#routeGenLegOverlay");
  if (await overlay.evaluate((el) => el.classList.contains("is-open")).catch(() => false)) {
    await page.click("#routeGenLegOverlayCloseBtn");
    await expect(overlay).not.toHaveClass(/is-open/, { timeout: 10000 });
  }
}

async function setDeterministicGeometry(page, points) {
  await waitForRouteBuilderTestHook(page);
  const result = await page.evaluate((geometryPoints) => {
    return window.FPW.DashboardModules.routeBuilder.test.setDraftGeometry(geometryPoints);
  }, points);
  expect(result).toBeTruthy();
}

async function saveOverrideForLeg(page, order, points) {
  await openLegMapForOrder(page, order);
  await setDeterministicGeometry(page, points);
  await page.click("#routeGenLegSaveBtn");
  await expect(page.locator("#routeGenLegMapStatus")).toContainText(/saved/i, { timeout: 20000 });
  await closeLegMapOverlay(page);
}

async function clearOverrideForLeg(page, order) {
  await openLegMapForOrder(page, order);
  await page.click("#routeGenLegClearBtn");
  await page.click("#routeGenLegSaveBtn");
  await expect(page.locator("#routeGenLegMapSource")).toContainText(/default/i, { timeout: 20000 });
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

async function deleteRouteCard(page, routeCode) {
  const card = page.locator(`[data-route-code="${routeCode}"]`).first();
  await expect(card).toBeVisible({ timeout: 30000 });
  await card.locator(".js-expedition-delete").click();
  const confirmModal = page.locator("#confirmModal");
  await expect(confirmModal).toBeVisible({ timeout: 15000 });
  const okBtn = page.locator("#confirmModalOk");
  const namedBtn = confirmModal.getByRole("button", { name: /^confirm$/i });
  if (await namedBtn.isVisible().catch(() => false)) {
    await namedBtn.click();
  } else {
    await okBtn.click();
  }
  await expect(confirmModal).toBeHidden({ timeout: 30000 });
  await expect(page.locator(`[data-route-code="${routeCode}"]`)).toHaveCount(0, { timeout: 30000 });
  return { SUCCESS: true, MESSAGE: "Route card removed from dashboard." };
}

async function createMyRouteViaUi(page, routeName) {
  const responsePromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=createUserRoute");
  }, { timeout: 30000 });
  await page.fill("#routeGenMyRouteName", routeName);
  await page.click("#routeGenMyRouteCreateBtn");
  const response = await responsePromise;
  const payload = await response.json();
  expect(!!(payload && payload.SUCCESS)).toBeTruthy();
  const routeId = Number(payload?.DATA?.route_id || payload?.DATA?.ROUTE_ID || 0);
  expect(routeId).toBeGreaterThan(0);
  await expect(page.locator("#routeGenMyRouteSelect")).toHaveValue(String(routeId), { timeout: 30000 });
  await page.waitForFunction((expectedRouteId) => {
    const routeSelect = document.querySelector("#routeGenMyRouteSelect");
    const startSelect = document.querySelector("#routeGenMyRouteStartWaypointSelect");
    const setStartBtn = document.querySelector("#routeGenMyRouteSetStartBtn");
    const addLegBtn = document.querySelector("#routeGenMyRouteAddWaypointLegBtn");
    if (!routeSelect || !startSelect || !setStartBtn || !addLegBtn) return false;
    if (String(routeSelect.value || "").trim() !== String(expectedRouteId)) return false;
    return !startSelect.disabled && !setStartBtn.disabled;
  }, routeId, { timeout: 30000 });
  return { routeId, payload };
}

async function setMyRouteStartWaypoint(page, routeId, waypointLabel) {
  await page.waitForFunction((expectedRouteId) => {
    const routeSelect = document.querySelector("#routeGenMyRouteSelect");
    const startSelect = document.querySelector("#routeGenMyRouteStartWaypointSelect");
    const setStartBtn = document.querySelector("#routeGenMyRouteSetStartBtn");
    if (!routeSelect || !startSelect || !setStartBtn) return false;
    if (String(routeSelect.value || "").trim() !== String(expectedRouteId)) return false;
    return !startSelect.disabled && !setStartBtn.disabled;
  }, routeId, { timeout: 30000 });
  const selectedWaypointId = await selectOptionContainingText(page, "#routeGenMyRouteStartWaypointSelect", waypointLabel);
  await expect(page.locator("#routeGenMyRouteStartWaypointSelect")).toHaveValue(String(selectedWaypointId), { timeout: 30000 });
  const responsePromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=setUserRouteStartWaypoint");
  }, { timeout: 30000 });
  await page.click("#routeGenMyRouteSetStartBtn");
  const response = await responsePromise;
  const payload = await response.json();
  expect(!!(payload && payload.SUCCESS)).toBeTruthy();
  await page.waitForFunction(([expectedRouteId, expectedStartWaypointId]) => {
    const routeSelect = document.querySelector("#routeGenMyRouteSelect");
    const startSelect = document.querySelector("#routeGenMyRouteStartWaypointSelect");
    const setStartBtn = document.querySelector("#routeGenMyRouteSetStartBtn");
    if (!routeSelect || !startSelect || !setStartBtn) return false;
    if (String(routeSelect.value || "").trim() !== String(expectedRouteId)) return false;
    if (String(startSelect.value || "").trim() !== String(expectedStartWaypointId)) return false;
    return !startSelect.disabled && !setStartBtn.disabled;
  }, [routeId, selectedWaypointId], { timeout: 30000 });
  return payload;
}

async function addMyRouteWaypointLeg(page, routeId, waypointLabel) {
  await selectOptionContainingText(page, "#routeGenMyRouteEndWaypointSelect", waypointLabel);
  const responsePromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=addWaypointLegToUserRoute");
  }, { timeout: 30000 });
  await page.click("#routeGenMyRouteAddWaypointLegBtn");
  const response = await responsePromise;
  const payload = await response.json();
  expect(!!(payload && payload.SUCCESS)).toBeTruthy();
  await expect(page.locator("#routeGenMyRouteSelect")).toHaveValue(String(routeId), { timeout: 30000 });
  return payload;
}

async function loadMyRoutePreview(page, routeId) {
  await expect(page.locator("#routeGenMyRouteSelect")).toHaveValue(String(routeId), { timeout: 30000 });
  const responsePromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=previewUserRoute");
  }, { timeout: 30000 });
  await page.click("#routeGenMyRouteLoadBtn");
  const response = await responsePromise;
  const payload = await response.json();
  expect(!!(payload && payload.SUCCESS)).toBeTruthy();
  await waitForPreviewReady(page);
  return payload;
}

async function deleteSelectedMyRouteViaUi(page, routeId) {
  await expect(page.locator("#routeGenMyRouteSelect")).toHaveValue(String(routeId), { timeout: 30000 });
  const responsePromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=deleteUserRoute");
  }, { timeout: 30000 });
  await page.click("#routeGenMyRouteDeleteBtn");
  const response = await responsePromise;
  const payload = await response.json();
  expect(!!(payload && payload.SUCCESS)).toBeTruthy();
  return payload;
}

module.exports = {
  ROUTE_BUILDER_MODAL_SELECTOR,
  callRouteBuilderAction,
  callWaypointAction,
  closeLegMapOverlay,
  closeRouteBuilder,
  createMyRouteViaUi,
  deleteRouteCard,
  deleteSelectedMyRouteViaUi,
  ensureRouteName,
  generateRoute,
  getJson,
  gotoDashboard,
  loadLegGeometryPayload,
  loadMyRoutePreview,
  loginRouteBuilderUser,
  loginRouteBuilderUserViaApi,
  logoutRouteBuilderUser,
  logoutRouteBuilderUserViaApi,
  openEditorForRouteDirect,
  openLegMapForOrder,
  openRouteBuilder,
  parseRequestBody,
  postJson,
  prepareGreatLoopPreview,
  reloadDashboard,
  reloadTimeline,
  reopenExistingRouteFromDashboard,
  reverseRoute,
  reverseRouteTimes,
  saveOverrideForLeg,
  saveRoute,
  selectFirstRealOption,
  selectOptionContainingText,
  setDeterministicGeometry,
  setDirection,
  setMyRouteStartWaypoint,
  snapshotCurrentControls,
  snapshotPreviewLegs,
  wait,
  waitForDashboardReady,
  waitForPreviewReady,
  waitForRouteBuilderReady,
  waitForRouteBuilderTestHook,
  clearOverrideForLeg,
  addMyRouteWaypointLeg
};
