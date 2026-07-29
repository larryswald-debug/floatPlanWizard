const { test, expect } = require("@playwright/test");
const { loginApprovedUser, openRouteBuilder } = require("../support/fpwSession");
const { createRouteBuilderCleanup } = require("../support/routebuilderCleanup");

test.describe.configure({ timeout: 240000 });

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

const OVERRIDE_POINTS_A = [
  { lat: 41.8781, lon: -87.6298 },
  { lat: 41.9500, lon: -87.3200 },
  { lat: 42.0200, lon: -86.9800 }
];

const OVERRIDE_POINTS_B = [
  { lat: 41.8200, lon: -87.6000 },
  { lat: 41.9300, lon: -87.1400 },
  { lat: 42.1100, lon: -86.7600 }
];

async function waitForPreviewWhenReady(page) {
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

async function closeRouteBuilderModal(page) {
  const modal = page.locator("#routeBuilderModal");
  if (await modal.isVisible().catch(() => false)) {
    const closeBtn = page.locator("#routeGenCloseBtn, #routeGenCancelBtn").first();
    await expect(closeBtn).toBeVisible({ timeout: 15000 });
    await closeBtn.click({ timeout: 5000 });
  }
  await expect(modal).toBeHidden({ timeout: 30000 });
  await expect(page.locator(".modal-backdrop.show")).toHaveCount(0, { timeout: 30000 });
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

async function ensureRouteName(page, value) {
  const input = page.locator("#routeGenRouteName");
  await expect(input).toBeVisible({ timeout: 15000 });
  if (!String(await input.inputValue()).trim()) {
    await input.fill(value);
  }
}

async function prepareGreatLoopRoutePreview(page, routeName) {
  await openRouteBuilder(page);

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
      return {
        order: parseInt(row.getAttribute("data-leg-order") || "0", 10),
        routeLegId: parseInt(row.getAttribute("data-route-leg-id") || "0", 10),
        segmentId: parseInt(row.getAttribute("data-segment-id") || "0", 10),
        hasOverride: !!row.querySelector(".fpw-routegen__flag--override"),
        distText: nmText,
        name: nameEl ? String(nameEl.textContent || "").trim() : ""
      };
    });
  });
}

function summarizeLegs(legs) {
  return legs.map((leg) => ({
    order: leg.order,
    routeLegId: leg.routeLegId,
    segmentId: leg.segmentId,
    hasOverride: !!leg.hasOverride,
    name: leg.name
  }));
}

function summarizeMapPayload(payload) {
  return {
    routeLegId: parseInt(payload?.DATA?.route_leg_id || 0, 10) || 0,
    segmentId: parseInt(payload?.DATA?.segment_id || 0, 10) || 0,
    hasOverride: !!(payload?.DATA?.has_override),
    hasEffectiveOverride: !!(payload?.DATA?.has_effective_override || payload?.DATA?.has_override || payload?.DATA?.has_segment_override),
    hasSegmentOverride: !!(payload?.DATA?.has_segment_override),
    source: String(payload?.DATA?.source || payload?.DATA?.map_source || "")
  };
}

async function openLegMapForOrder(page, order) {
  await page.evaluate((legOrder) => {
    const btn = document.querySelector(`#routeGenLegList .fpw-routegen__leg[data-leg-order="${legOrder}"] [data-leg-action="open-map"]`);
    if (!btn) throw new Error("Open map button not found for leg order " + String(legOrder));
    btn.click();
  }, order);
  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 10000 });
}

async function closeLegMapOverlay(page) {
  const overlay = page.locator("#routeGenLegOverlay");
  if (await overlay.evaluate((el) => el.classList.contains("is-open")).catch(() => false)) {
    await page.click("#routeGenLegOverlayCloseBtn");
    await expect(overlay).not.toHaveClass(/is-open/, { timeout: 10000 });
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
  await waitForPreviewWhenReady(page);
  return payload;
}

async function generateRoute(page) {
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
  return { routeCode, generatePayload };
}

async function reopenExistingRouteFromDashboard(page, routeCode) {
  const routeCard = page.locator(`[data-route-code="${routeCode}"]`).first();
  await expect(routeCard).toBeVisible({ timeout: 30000 });
  const editBtn = routeCard.locator(".js-expedition-view-edit");
  await expect(editBtn).toBeVisible({ timeout: 30000 });

  const previewPromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_preview");
  }, { timeout: 30000 });

  await editBtn.click();
  await expect(page.locator("#routeBuilderModal")).toBeVisible({ timeout: 15000 });
  const previewResponse = await previewPromise;
  const previewPayload = await previewResponse.json();
  expect(!!(previewPayload && previewPayload.SUCCESS)).toBeTruthy();
  await waitForPreviewWhenReady(page);
  return previewPayload;
}

async function reloadDashboard(page) {
  await page.goto("/fpw/app/dashboard.cfm", { waitUntil: "domcontentloaded" });
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 30000 });
}

async function reverseExistingRoute(page) {
  const reversePreviewPromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=routegen_preview");
  }, { timeout: 30000 });

  const toggle = page.locator("#routeGenDirectionToggle");
  if (await toggle.count()) {
    await toggle.click();
  } else {
    const select = page.locator("#routeGenDirection");
    const currentValue = await select.inputValue();
    await select.selectOption(currentValue.toUpperCase() === "CW" ? "CCW" : "CW");
  }

  const reversePreviewResponse = await reversePreviewPromise;
  const reversePreviewPayload = await reversePreviewResponse.json();
  expect(!!(reversePreviewPayload && reversePreviewPayload.SUCCESS)).toBeTruthy();
  await waitForPreviewWhenReady(page);
  return reversePreviewPayload;
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

async function saveRoute(page) {
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
  const requestInfo = parseRequestBody(updateRequest);
  const updatePayload = await updateResponse.json();
  expect(!!(updatePayload && updatePayload.SUCCESS)).toBeTruthy();
  await waitForPreviewWhenReady(page);
  return {
    requestBody: requestInfo.parsed,
    requestRaw: requestInfo.raw,
    responsePayload: updatePayload
  };
}

async function createSavedRouteBaseline(page, routeName) {
  await page.addInitScript(() => {
    window.__FPW_ENABLE_TEST_HOOKS = true;
  });

  await loginApprovedUser(page);
  await prepareGreatLoopRoutePreview(page, routeName);
  await waitForRouteBuilderTestHook(page);

  const { routeCode } = await generateRoute(page);
  await reloadTimeline(page);

  const initialLegs = await snapshotPreviewLegs(page);
  expect(initialLegs.length).toBeGreaterThan(3);

  await closeRouteBuilderModal(page);
  await reloadDashboard(page);
  await reopenExistingRouteFromDashboard(page, routeCode);
  const reopenedOriginalLegs = await snapshotPreviewLegs(page);

  return {
    routeCode,
    originalLegs: reopenedOriginalLegs
  };
}

async function createSavedRouteWithOverrides(page, routeName) {
  const setup = await createSavedRouteBaseline(page, routeName);
  const routeCode = setup.routeCode;
  const initialLegs = setup.originalLegs;

  const overrideCandidates = initialLegs.filter((leg) => leg.routeLegId > 0).slice(0, 2);
  expect(overrideCandidates).toHaveLength(2);

  await saveOverrideForLeg(page, overrideCandidates[0].order, OVERRIDE_POINTS_A);
  await saveOverrideForLeg(page, overrideCandidates[1].order, OVERRIDE_POINTS_B);

  const savedLiveLegs = await snapshotPreviewLegs(page);
  const savedLiveOverrideLegs = savedLiveLegs.filter((leg) => leg.hasOverride);
  expect(savedLiveOverrideLegs).toHaveLength(2);

  await closeRouteBuilderModal(page);
  await reloadDashboard(page);
  await reopenExistingRouteFromDashboard(page, routeCode);
  const reopenedOriginalLegs = await snapshotPreviewLegs(page);
  const reopenedOriginalOverrideLegs = reopenedOriginalLegs.filter((leg) => leg.hasOverride);
  expect(reopenedOriginalOverrideLegs).toHaveLength(2);

  return {
    routeCode,
    originalLegs: reopenedOriginalLegs,
    overrideLegs: reopenedOriginalOverrideLegs
  };
}

async function deleteRouteFromDashboard(page, routeCode) {
  const card = page.locator(`[data-route-code="${routeCode}"]`).first();
  await expect(card).toBeVisible({ timeout: 30000 });
  await card.locator(".js-expedition-delete").click();
  const confirmModal = page.locator("#confirmModal");
  await expect(confirmModal).toBeVisible({ timeout: 15000 });
  const confirmOkBtn = page.locator("#confirmModalOk");
  const confirmRoleBtn = confirmModal.getByRole("button", { name: /^confirm$/i });
  if (await confirmRoleBtn.isVisible().catch(() => false)) {
    await confirmRoleBtn.click();
  } else if (await confirmOkBtn.isVisible().catch(() => false)) {
    await confirmOkBtn.click();
  } else {
    page.once("dialog", (dialog) => dialog.accept().catch(() => {}));
  }
  await expect(confirmModal).toBeHidden({ timeout: 30000 });
  await expect(page.locator(`[data-route-code="${routeCode}"]`)).toHaveCount(0, { timeout: 30000 });
  return { SUCCESS: true, MESSAGE: "Route card removed from dashboard." };
}

test("Route Builder unsaved draft override survives reverse and becomes exact after generate and reopen", async ({ page }, testInfo) => {
  const proof = {
    routeCode: "",
    targetSegmentId: 0,
    initial: [],
    afterDraft: [],
    reversed: [],
    postGenerate: [],
    reopened: [],
    draftGeometry: null,
    postGenerateGeometry: null,
    reopenedGeometry: null
  };

  try {
    await page.addInitScript(() => {
      window.__FPW_ENABLE_TEST_HOOKS = true;
    });

    await loginApprovedUser(page);
    await prepareGreatLoopRoutePreview(page, "PW Draft Reverse " + Date.now());
    await waitForRouteBuilderTestHook(page);

    const initialLegs = await snapshotPreviewLegs(page);
    proof.initial = summarizeLegs(initialLegs);
    expect(initialLegs.length).toBeGreaterThan(3);

    const targetLeg = initialLegs.find((leg) => leg.segmentId > 0 && !leg.hasOverride) || initialLegs[0];
    expect(targetLeg, `Unable to resolve an unsaved draft target leg. Initial=${JSON.stringify(proof.initial)}`).toBeTruthy();
    proof.targetSegmentId = targetLeg.segmentId;

    await saveOverrideForLeg(page, targetLeg.order, OVERRIDE_POINTS_A);

    const afterDraftLegs = await snapshotPreviewLegs(page);
    proof.afterDraft = summarizeLegs(afterDraftLegs);
    const draftedLeg = afterDraftLegs.find((leg) => leg.segmentId === targetLeg.segmentId) || null;
    expect(draftedLeg && draftedLeg.hasOverride, `Saving an unsaved draft override did not show a badge for segment ${targetLeg.segmentId}. AfterDraft=${JSON.stringify(proof.afterDraft)}`).toBeTruthy();

    const draftGeometryPayload = await loadLegGeometryPayload(page, draftedLeg.order);
    proof.draftGeometry = summarizeMapPayload(draftGeometryPayload);
    expect(!!proof.draftGeometry.hasOverride, `Draft geometry should not claim an exact override before generate. DraftGeometry=${JSON.stringify(proof.draftGeometry)}`).toBeFalsy();
    expect(!!proof.draftGeometry.hasEffectiveOverride, `Draft geometry should report effective override truth before generate. DraftGeometry=${JSON.stringify(proof.draftGeometry)}`).toBeTruthy();
    expect(proof.draftGeometry.source, `Draft geometry should identify draft override source before generate. DraftGeometry=${JSON.stringify(proof.draftGeometry)}`).toBe("draft_override");
    await closeLegMapOverlay(page);

    const reversedPreviewPayload = await reverseExistingRoute(page);
    expect(!!reversedPreviewPayload?.SUCCESS).toBeTruthy();
    const reversedLegs = await snapshotPreviewLegs(page);
    proof.reversed = summarizeLegs(reversedLegs);
    expect(
      reversedLegs.map((leg) => leg.segmentId),
      `Reverse did not change visible order after unsaved draft override. Initial=${JSON.stringify(proof.initial)} Reversed=${JSON.stringify(proof.reversed)}`
    ).not.toEqual(initialLegs.map((leg) => leg.segmentId));

    const reversedDraftLeg = reversedLegs.find((leg) => leg.segmentId === targetLeg.segmentId) || null;
    expect(reversedDraftLeg && reversedDraftLeg.hasOverride, `Reversing an unsaved route dropped the draft override badge for segment ${targetLeg.segmentId}. Reversed=${JSON.stringify(proof.reversed)}`).toBeTruthy();

    const generateResult = await generateRoute(page);
    proof.routeCode = generateResult.routeCode;
    expect(proof.routeCode).not.toBe("");

    const postGenerateLegs = await snapshotPreviewLegs(page);
    proof.postGenerate = summarizeLegs(postGenerateLegs);
    const generatedLeg = postGenerateLegs.find((leg) => leg.segmentId === targetLeg.segmentId) || null;
    expect(generatedLeg && generatedLeg.hasOverride, `Generating the route dropped the override badge for segment ${targetLeg.segmentId}. PostGenerate=${JSON.stringify(proof.postGenerate)}`).toBeTruthy();

    const postGenerateGeometryPayload = await loadLegGeometryPayload(page, generatedLeg.order);
    proof.postGenerateGeometry = summarizeMapPayload(postGenerateGeometryPayload);
    expect(!!proof.postGenerateGeometry.hasOverride, `Generated route should persist an exact override for segment ${targetLeg.segmentId}. GeneratedGeometry=${JSON.stringify(proof.postGenerateGeometry)}`).toBeTruthy();
    expect(!!proof.postGenerateGeometry.hasEffectiveOverride, `Generated route should keep effective override truth for segment ${targetLeg.segmentId}. GeneratedGeometry=${JSON.stringify(proof.postGenerateGeometry)}`).toBeTruthy();
    expect(proof.postGenerateGeometry.source, `Generated route should promote the draft into a user override for segment ${targetLeg.segmentId}. GeneratedGeometry=${JSON.stringify(proof.postGenerateGeometry)}`).toBe("user_override");
    await closeLegMapOverlay(page);

    await closeRouteBuilderModal(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, proof.routeCode);

    const reopenedLegs = await snapshotPreviewLegs(page);
    proof.reopened = summarizeLegs(reopenedLegs);
    expect(
      reopenedLegs.map((leg) => leg.segmentId),
      `Reopened route did not preserve the generated reversed order for ${proof.routeCode}. PostGenerate=${JSON.stringify(proof.postGenerate)} Reopened=${JSON.stringify(proof.reopened)}`
    ).toEqual(postGenerateLegs.map((leg) => leg.segmentId));

    const reopenedLeg = reopenedLegs.find((leg) => leg.segmentId === targetLeg.segmentId) || null;
    expect(reopenedLeg && reopenedLeg.hasOverride, `Reopened route dropped the override badge for segment ${targetLeg.segmentId}. Reopened=${JSON.stringify(proof.reopened)}`).toBeTruthy();

    const reopenedGeometryPayload = await loadLegGeometryPayload(page, reopenedLeg.order);
    proof.reopenedGeometry = summarizeMapPayload(reopenedGeometryPayload);
    expect(!!proof.reopenedGeometry.hasOverride, `Reopened route should keep the exact override for segment ${targetLeg.segmentId}. ReopenedGeometry=${JSON.stringify(proof.reopenedGeometry)}`).toBeTruthy();
    expect(!!proof.reopenedGeometry.hasEffectiveOverride, `Reopened route should keep effective override truth for segment ${targetLeg.segmentId}. ReopenedGeometry=${JSON.stringify(proof.reopenedGeometry)}`).toBeTruthy();
    expect(proof.reopenedGeometry.source, `Reopened route should report user_override source for segment ${targetLeg.segmentId}. ReopenedGeometry=${JSON.stringify(proof.reopenedGeometry)}`).toBe("user_override");
    await closeLegMapOverlay(page);
  } finally {
    const proofJson = JSON.stringify(proof, null, 2);
    console.log("PW_UNSAVED_DRAFT_REVERSE_GENERATE_PROOF " + proofJson);
    await testInfo.attach("unsaved-draft-reverse-generate-proof.json", {
      body: proofJson,
      contentType: "application/json"
    });
  }
});

test("Route Builder reverse changes visible order on an existing saved route before save", async ({ page }, testInfo) => {
  const proof = {
    routeCode: "",
    originalOrder: [],
    reversedOrder: [],
    originalOverrideLegs: [],
    reversedOverrideLegs: []
  };

  try {
    const routeName = "PW Reverse Editor Truth " + Date.now();
    const setup = await createSavedRouteWithOverrides(page, routeName);
    proof.routeCode = setup.routeCode;
    proof.originalOrder = summarizeLegs(setup.originalLegs);
    proof.originalOverrideLegs = summarizeLegs(setup.overrideLegs);

    const originalSequence = setup.originalLegs.map((leg) => leg.segmentId);
    const reversePreviewPayload = await reverseExistingRoute(page);
    expect(!!(reversePreviewPayload && reversePreviewPayload.SUCCESS)).toBeTruthy();

    const reversedLegs = await snapshotPreviewLegs(page);
    proof.reversedOrder = summarizeLegs(reversedLegs);
    proof.reversedOverrideLegs = summarizeLegs(reversedLegs.filter((leg) => leg.hasOverride));

    const reversedSequence = reversedLegs.map((leg) => leg.segmentId);
    expect(reversedSequence, `Reverse did not change visible leg order. Original=${JSON.stringify(originalSequence)} Reversed=${JSON.stringify(reversedSequence)}`).not.toEqual(originalSequence);
    expect(reversedSequence[0], `Reverse did not move the last original leg to the first visible position. Original=${JSON.stringify(originalSequence)} Reversed=${JSON.stringify(reversedSequence)}`).toBe(originalSequence[originalSequence.length - 1]);
    expect(reversedSequence[reversedSequence.length - 1], `Reverse did not move the first original leg to the last visible position. Original=${JSON.stringify(originalSequence)} Reversed=${JSON.stringify(reversedSequence)}`).toBe(originalSequence[0]);
  } finally {
    const proofJson = JSON.stringify(proof, null, 2);
    console.log("PW_REVERSE_EDITOR_BASELINE_PROOF " + proofJson);
    await testInfo.attach("reverse-editor-baseline-proof.json", {
      body: proofJson,
      contentType: "application/json"
    });
  }
});

test("Route Builder reopen -> reverse -> save -> reopen preserves reversed order and override truth", async ({ page }, testInfo) => {
  const proof = {
    routeCode: "",
    originalOrder: [],
    originalOverrideLegs: [],
    reversedEditorOrder: [],
    reversedEditorOverrideLegs: [],
    updateRequest: {},
    reopenedSavedOrder: [],
    reopenedBadgeLegs: [],
    mapOverrideTruth: [],
    mapNonOverrideTruth: null
  };

  try {
    const routeName = "PW Reverse Save Reopen Bug " + Date.now();
    const setup = await createSavedRouteWithOverrides(page, routeName);
    proof.routeCode = setup.routeCode;
    proof.originalOrder = summarizeLegs(setup.originalLegs);
    proof.originalOverrideLegs = summarizeLegs(setup.overrideLegs);

    const originalSequence = setup.originalLegs.map((leg) => leg.segmentId);
    const originalOverrideSegments = setup.overrideLegs.map((leg) => leg.segmentId).sort((a, b) => a - b);

    await reverseExistingRoute(page);
    const reversedLegs = await snapshotPreviewLegs(page);
    proof.reversedEditorOrder = summarizeLegs(reversedLegs);
    proof.reversedEditorOverrideLegs = summarizeLegs(reversedLegs.filter((leg) => leg.hasOverride));
    const reversedSequence = reversedLegs.map((leg) => leg.segmentId);

    expect(reversedSequence, `Reverse action failed before save. Original=${JSON.stringify(originalSequence)} Reversed=${JSON.stringify(reversedSequence)}`).not.toEqual(originalSequence);

    const saveResult = await saveRoute(page);
    proof.updateRequest = {
      route_code: String(saveResult.requestBody.route_code || ""),
      direction: String(saveResult.requestBody.direction || ""),
      start_segment_id: String(saveResult.requestBody.start_segment_id || ""),
      end_segment_id: String(saveResult.requestBody.end_segment_id || "")
    };

    await closeRouteBuilderModal(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, setup.routeCode);
    const reopenedLegs = await snapshotPreviewLegs(page);
    proof.reopenedSavedOrder = summarizeLegs(reopenedLegs);
    const reopenedBadgeLegs = reopenedLegs.filter((leg) => leg.hasOverride);
    proof.reopenedBadgeLegs = summarizeLegs(reopenedBadgeLegs);

    const reopenedSequence = reopenedLegs.map((leg) => leg.segmentId);
    const reopenedBadgeSegments = reopenedBadgeLegs.map((leg) => leg.segmentId).sort((a, b) => a - b);

    expect.soft(
      reopenedSequence,
      `Save failed to persist reversed order or reopen restored old order. Original=${JSON.stringify(originalSequence)} ReversedBeforeSave=${JSON.stringify(reversedSequence)} Reopened=${JSON.stringify(reopenedSequence)}`
    ).toEqual(reversedSequence);

    expect.soft(
      reopenedBadgeSegments,
      `Override badges on reopen do not match canonical override segments. Expected segments=${JSON.stringify(originalOverrideSegments)} Reopened badge segments=${JSON.stringify(reopenedBadgeSegments)}`
    ).toEqual(originalOverrideSegments);

    for (const segmentId of originalOverrideSegments) {
      const reopenedLeg = reopenedLegs.find((leg) => leg.segmentId === segmentId);
      expect(reopenedLeg, `Canonical overridden leg with segment ${segmentId} was not present after reopen. Reopened=${JSON.stringify(reopenedSequence)}`).toBeTruthy();

      const geometryPayload = await loadLegGeometryPayload(page, reopenedLeg.order);
      const geometrySummary = summarizeMapPayload(geometryPayload);
      proof.mapOverrideTruth.push({
        expectedSegmentId: segmentId,
        rowOrder: reopenedLeg.order,
        rowHasBadge: reopenedLeg.hasOverride,
        rowRouteLegId: reopenedLeg.routeLegId,
        geometry: geometrySummary
      });

      expect.soft(
        geometrySummary.hasOverride || geometrySummary.hasSegmentOverride,
        `Map truth for canonical overridden segment ${segmentId} did not return override data. Geometry=${JSON.stringify(geometrySummary)}`
      ).toBeTruthy();
      await closeLegMapOverlay(page);
    }

    const reopenedNonOverrideLeg = reopenedLegs.find((leg) => originalOverrideSegments.indexOf(leg.segmentId) === -1);
    expect(reopenedNonOverrideLeg, `Could not find a non-overridden reopened leg. Reopened=${JSON.stringify(reopenedSequence)}`).toBeTruthy();
    const reopenedNonOverridePayload = await loadLegGeometryPayload(page, reopenedNonOverrideLeg.order);
    proof.mapNonOverrideTruth = {
      rowOrder: reopenedNonOverrideLeg.order,
      rowSegmentId: reopenedNonOverrideLeg.segmentId,
      rowRouteLegId: reopenedNonOverrideLeg.routeLegId,
      rowHasBadge: reopenedNonOverrideLeg.hasOverride,
      geometry: summarizeMapPayload(reopenedNonOverridePayload)
    };
    expect.soft(
      proof.mapNonOverrideTruth.geometry.hasOverride,
      `Non-overridden leg unexpectedly resolved user override truth. Geometry=${JSON.stringify(proof.mapNonOverrideTruth.geometry)}`
    ).toBeFalsy();
    await closeLegMapOverlay(page);
  } finally {
    const proofJson = JSON.stringify(proof, null, 2);
    console.log("PW_REVERSE_SAVE_REOPEN_BUG_PROOF " + proofJson);
    await testInfo.attach("reverse-save-reopen-bug-proof.json", {
      body: proofJson,
      contentType: "application/json"
    });
  }
});

test("Route Builder fresh saved route reproduces add override -> reverse -> save -> reopen truth", async ({ page }, testInfo) => {
  const proof = {
    routeCode: "",
    initialOrder: [],
    initialOverrideLegs: [],
    afterOverrideOrder: [],
    afterOverrideBadgeLegs: [],
    reverseOrder: [],
    reverseBadgeLegs: [],
    saveRequest: {},
    postSaveOrder: [],
    postSaveBadgeLegs: [],
    reopenedOrder: [],
    reopenedBadgeLegs: [],
    mapOverrideTruth: [],
    mapNonOverrideTruth: null
  };

  try {
    await page.addInitScript(() => {
      window.__FPW_ENABLE_TEST_HOOKS = true;
    });

    const setup = await createSavedRouteBaseline(page, "PW Existing Reverse Save Reopen " + Date.now());
    const routeCode = setup.routeCode;
    proof.routeCode = routeCode;
    await waitForRouteBuilderTestHook(page);

    const initialLegs = setup.originalLegs;
    proof.initialOrder = summarizeLegs(initialLegs);
    proof.initialOverrideLegs = summarizeLegs(initialLegs.filter((leg) => leg.hasOverride));
    expect(initialLegs.length).toBeGreaterThan(3);

    await saveOverrideForLeg(page, 1, OVERRIDE_POINTS_A);
    await saveOverrideForLeg(page, 2, OVERRIDE_POINTS_B);

    const afterOverrideLegs = await snapshotPreviewLegs(page);
    const afterOverrideBadges = afterOverrideLegs.filter((leg) => leg.hasOverride);
    proof.afterOverrideOrder = summarizeLegs(afterOverrideLegs);
    proof.afterOverrideBadgeLegs = summarizeLegs(afterOverrideBadges);

    const originalSequence = afterOverrideLegs.map((leg) => leg.segmentId);
    const originalOverrideSegments = afterOverrideBadges.map((leg) => leg.segmentId).sort((a, b) => a - b);

    const reversePayload = await reverseExistingRoute(page);
    const reversedLegs = await snapshotPreviewLegs(page);
    const reversedBadges = reversedLegs.filter((leg) => leg.hasOverride);
    proof.reverseOrder = summarizeLegs(reversedLegs);
    proof.reverseBadgeLegs = summarizeLegs(reversedBadges);

    const reversedSequence = reversedLegs.map((leg) => leg.segmentId);
    expect(
      reversedSequence,
      `Reverse action failed in editor for ${routeCode}. Original=${JSON.stringify(originalSequence)} Reversed=${JSON.stringify(reversedSequence)}`
    ).not.toEqual(originalSequence);

    const saveResult = await saveRoute(page);
    proof.saveRequest = {
      route_code: String(saveResult.requestBody.route_code || ""),
      direction: String(saveResult.requestBody.direction || ""),
      start_segment_id: String(saveResult.requestBody.start_segment_id || ""),
      end_segment_id: String(saveResult.requestBody.end_segment_id || "")
    };

    const postSaveLegs = await snapshotPreviewLegs(page);
    const postSaveBadges = postSaveLegs.filter((leg) => leg.hasOverride);
    proof.postSaveOrder = summarizeLegs(postSaveLegs);
    proof.postSaveBadgeLegs = summarizeLegs(postSaveBadges);

    await closeRouteBuilderModal(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, routeCode);

    const reopenedLegs = await snapshotPreviewLegs(page);
    const reopenedBadges = reopenedLegs.filter((leg) => leg.hasOverride);
    proof.reopenedOrder = summarizeLegs(reopenedLegs);
    proof.reopenedBadgeLegs = summarizeLegs(reopenedBadges);

    const reopenedSequence = reopenedLegs.map((leg) => leg.segmentId);
    const reopenedBadgeSegments = reopenedBadges.map((leg) => leg.segmentId).sort((a, b) => a - b);

    for (const segmentId of originalOverrideSegments) {
      const reopenedLeg = reopenedLegs.find((leg) => leg.segmentId === segmentId);
      if (!reopenedLeg) {
        proof.mapOverrideTruth.push({
          expectedSegmentId: segmentId,
          missingOnReopen: true
        });
        continue;
      }

      const geometryPayload = await loadLegGeometryPayload(page, reopenedLeg.order);
      proof.mapOverrideTruth.push({
        expectedSegmentId: segmentId,
        rowOrder: reopenedLeg.order,
        rowHasBadge: reopenedLeg.hasOverride,
        rowRouteLegId: reopenedLeg.routeLegId,
        geometry: summarizeMapPayload(geometryPayload)
      });
      await closeLegMapOverlay(page);
    }

    const reopenedNonOverrideLeg = reopenedLegs.find((leg) => originalOverrideSegments.indexOf(leg.segmentId) === -1);
    if (reopenedNonOverrideLeg) {
      const reopenedNonOverridePayload = await loadLegGeometryPayload(page, reopenedNonOverrideLeg.order);
      proof.mapNonOverrideTruth = {
        rowOrder: reopenedNonOverrideLeg.order,
        rowSegmentId: reopenedNonOverrideLeg.segmentId,
        rowRouteLegId: reopenedNonOverrideLeg.routeLegId,
        rowHasBadge: reopenedNonOverrideLeg.hasOverride,
        geometry: summarizeMapPayload(reopenedNonOverridePayload)
      };
      await closeLegMapOverlay(page);
    }

    const afterOverrideOrders = afterOverrideBadges.map((leg) => leg.order);
    expect(
      afterOverrideOrders.includes(1) && afterOverrideOrders.includes(2),
      `Adding overrides did not mark visible legs 1 and 2 on ${routeCode}. AfterOverride=${JSON.stringify(proof.afterOverrideBadgeLegs)}`
    ).toBeTruthy();

    expect(
      reopenedSequence,
      `Save failed to persist reversed order or reopen restored old order for ${routeCode}. ReversedBeforeSave=${JSON.stringify(reversedSequence)} Reopened=${JSON.stringify(reopenedSequence)}`
    ).toEqual(reversedSequence);

    expect(
      reopenedBadgeSegments,
      `Override badges disappeared or moved after reopen for ${routeCode}. Expected canonical segments=${JSON.stringify(originalOverrideSegments)} Reopened badge segments=${JSON.stringify(reopenedBadgeSegments)} Map truth=${JSON.stringify(proof.mapOverrideTruth)}`
    ).toEqual(originalOverrideSegments);

    for (const row of proof.mapOverrideTruth) {
      expect(
        !!(row.geometry && (row.geometry.hasOverride || row.geometry.hasSegmentOverride)),
        `Map truth disagrees for overridden segment ${row.expectedSegmentId} on ${routeCode}. Row=${JSON.stringify(row)}`
      ).toBeTruthy();
    }

    if (proof.mapNonOverrideTruth) {
      expect(
        !!proof.mapNonOverrideTruth.geometry.hasOverride,
        `Map truth falsely reported a user override for non-overridden leg on ${routeCode}. Truth=${JSON.stringify(proof.mapNonOverrideTruth)}`
      ).toBeFalsy();
    }
  } finally {
    const proofJson = JSON.stringify(proof, null, 2);
    console.log("PW_EXISTING_TEST_ROUTE_REVERSE_SAVE_REOPEN_PROOF " + proofJson);
    await testInfo.attach("existing-test-route-reverse-save-reopen-proof.json", {
      body: proofJson,
      contentType: "application/json"
    });
  }
});

test("Route Builder fresh saved route save without reverse preserves current order and badges", async ({ page }, testInfo) => {
  const proof = {
    routeCode: "",
    beforeSave: [],
    beforeSaveBadges: [],
    saveRequest: {},
    afterSave: [],
    afterSaveBadges: [],
    reopened: [],
    reopenedBadges: []
  };

  try {
    await page.addInitScript(() => {
      window.__FPW_ENABLE_TEST_HOOKS = true;
    });
    const setup = await createSavedRouteWithOverrides(page, "PW Existing Save Only " + Date.now());
    const routeCode = setup.routeCode;
    proof.routeCode = routeCode;

    const beforeSave = setup.originalLegs;
    proof.beforeSave = summarizeLegs(beforeSave);
    proof.beforeSaveBadges = summarizeLegs(beforeSave.filter((leg) => leg.hasOverride));

    const saveResult = await saveRoute(page);
    proof.saveRequest = {
      route_code: String(saveResult.requestBody.route_code || ""),
      direction: String(saveResult.requestBody.direction || ""),
      start_segment_id: String(saveResult.requestBody.start_segment_id || ""),
      end_segment_id: String(saveResult.requestBody.end_segment_id || "")
    };

    const afterSave = await snapshotPreviewLegs(page);
    proof.afterSave = summarizeLegs(afterSave);
    proof.afterSaveBadges = summarizeLegs(afterSave.filter((leg) => leg.hasOverride));

    await closeRouteBuilderModal(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, routeCode);

    const reopened = await snapshotPreviewLegs(page);
    proof.reopened = summarizeLegs(reopened);
    proof.reopenedBadges = summarizeLegs(reopened.filter((leg) => leg.hasOverride));

    expect(
      reopened.map((leg) => leg.segmentId),
      `Save without reverse changed order for ${routeCode}. Before=${JSON.stringify(proof.beforeSave)} Reopened=${JSON.stringify(proof.reopened)}`
    ).toEqual(beforeSave.map((leg) => leg.segmentId));

    expect(
      reopened.filter((leg) => leg.hasOverride).map((leg) => leg.segmentId).sort((a, b) => a - b),
      `Save without reverse lost or moved override badges for ${routeCode}. Before=${JSON.stringify(proof.beforeSaveBadges)} Reopened=${JSON.stringify(proof.reopenedBadges)}`
    ).toEqual(beforeSave.filter((leg) => leg.hasOverride).map((leg) => leg.segmentId).sort((a, b) => a - b));
  } finally {
    const proofJson = JSON.stringify(proof, null, 2);
    console.log("PW_EXISTING_ROUTE_SAVE_ONLY_PROOF " + proofJson);
    await testInfo.attach("existing-route-save-only-proof.json", {
      body: proofJson,
      contentType: "application/json"
    });
  }
});

test("Route Builder fresh saved route reverse without save reopens to prior saved state", async ({ page }, testInfo) => {
  const proof = {
    routeCode: "",
    original: [],
    originalBadges: [],
    reversed: [],
    reversedBadges: [],
    reopened: [],
    reopenedBadges: []
  };

  try {
    await page.addInitScript(() => {
      window.__FPW_ENABLE_TEST_HOOKS = true;
    });
    const setup = await createSavedRouteWithOverrides(page, "PW Existing Reverse No Save " + Date.now());
    const routeCode = setup.routeCode;
    proof.routeCode = routeCode;

    const original = setup.originalLegs;
    proof.original = summarizeLegs(original);
    proof.originalBadges = summarizeLegs(original.filter((leg) => leg.hasOverride));

    await reverseExistingRoute(page);
    const reversed = await snapshotPreviewLegs(page);
    proof.reversed = summarizeLegs(reversed);
    proof.reversedBadges = summarizeLegs(reversed.filter((leg) => leg.hasOverride));

    expect(
      reversed.map((leg) => leg.segmentId),
      `Reverse did not change visible order for ${routeCode}. Original=${JSON.stringify(proof.original)} Reversed=${JSON.stringify(proof.reversed)}`
    ).not.toEqual(original.map((leg) => leg.segmentId));

    await closeRouteBuilderModal(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, routeCode);

    const reopened = await snapshotPreviewLegs(page);
    proof.reopened = summarizeLegs(reopened);
    proof.reopenedBadges = summarizeLegs(reopened.filter((leg) => leg.hasOverride));

    expect(
      reopened.map((leg) => leg.segmentId),
      `Closing without save did not restore the prior saved order for ${routeCode}. Original=${JSON.stringify(proof.original)} Reopened=${JSON.stringify(proof.reopened)}`
    ).toEqual(original.map((leg) => leg.segmentId));

    expect(
      reopened.filter((leg) => leg.hasOverride).map((leg) => leg.segmentId).sort((a, b) => a - b),
      `Closing without save did not restore prior badge state for ${routeCode}. Original=${JSON.stringify(proof.originalBadges)} Reopened=${JSON.stringify(proof.reopenedBadges)}`
    ).toEqual(original.filter((leg) => leg.hasOverride).map((leg) => leg.segmentId).sort((a, b) => a - b));
  } finally {
    const proofJson = JSON.stringify(proof, null, 2);
    console.log("PW_EXISTING_ROUTE_REVERSE_NO_SAVE_PROOF " + proofJson);
    await testInfo.attach("existing-route-reverse-no-save-proof.json", {
      body: proofJson,
      contentType: "application/json"
    });
  }
});

test("Route Builder fresh saved route double reverse then save preserves round-trip state", async ({ page }, testInfo) => {
  const proof = {
    routeCode: "",
    original: [],
    firstReverse: [],
    secondReverse: [],
    saveRequest: {},
    reopened: [],
    originalBadges: [],
    reopenedBadges: []
  };

  try {
    await page.addInitScript(() => {
      window.__FPW_ENABLE_TEST_HOOKS = true;
    });
    const setup = await createSavedRouteWithOverrides(page, "PW Existing Double Reverse " + Date.now());
    const routeCode = setup.routeCode;
    proof.routeCode = routeCode;

    const original = setup.originalLegs;
    proof.original = summarizeLegs(original);
    proof.originalBadges = summarizeLegs(original.filter((leg) => leg.hasOverride));

    await reverseExistingRoute(page);
    const firstReverse = await snapshotPreviewLegs(page);
    proof.firstReverse = summarizeLegs(firstReverse);

    await reverseExistingRoute(page);
    const secondReverse = await snapshotPreviewLegs(page);
    proof.secondReverse = summarizeLegs(secondReverse);

    expect(
      secondReverse.map((leg) => leg.segmentId),
      `Double reverse did not return to original visible order for ${routeCode}. Original=${JSON.stringify(proof.original)} SecondReverse=${JSON.stringify(proof.secondReverse)}`
    ).toEqual(original.map((leg) => leg.segmentId));

    const saveResult = await saveRoute(page);
    proof.saveRequest = {
      route_code: String(saveResult.requestBody.route_code || ""),
      direction: String(saveResult.requestBody.direction || ""),
      start_segment_id: String(saveResult.requestBody.start_segment_id || ""),
      end_segment_id: String(saveResult.requestBody.end_segment_id || "")
    };

    await closeRouteBuilderModal(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, routeCode);

    const reopened = await snapshotPreviewLegs(page);
    proof.reopened = summarizeLegs(reopened);
    proof.reopenedBadges = summarizeLegs(reopened.filter((leg) => leg.hasOverride));

    expect(
      reopened.map((leg) => leg.segmentId),
      `Save after double reverse changed saved order for ${routeCode}. Original=${JSON.stringify(proof.original)} Reopened=${JSON.stringify(proof.reopened)}`
    ).toEqual(original.map((leg) => leg.segmentId));

    expect(
      reopened.filter((leg) => leg.hasOverride).map((leg) => leg.segmentId).sort((a, b) => a - b),
      `Save after double reverse changed badge ownership for ${routeCode}. Original=${JSON.stringify(proof.originalBadges)} Reopened=${JSON.stringify(proof.reopenedBadges)}`
    ).toEqual(original.filter((leg) => leg.hasOverride).map((leg) => leg.segmentId).sort((a, b) => a - b));
  } finally {
    const proofJson = JSON.stringify(proof, null, 2);
    console.log("PW_EXISTING_ROUTE_DOUBLE_REVERSE_SAVE_PROOF " + proofJson);
    await testInfo.attach("existing-route-double-reverse-save-proof.json", {
      body: proofJson,
      contentType: "application/json"
    });
  }
});

test("Route Builder disposable route survives repeated reverse-save-reopen cycles", async ({ page }, testInfo) => {
  const proof = {
    routeCode: "",
    originalOverrideSegments: [],
    cycles: [],
    finalMapOverrideTruth: [],
    finalMapNonOverrideTruth: null
  };

  try {
    const routeName = "PW Reverse Stress Loop " + Date.now();
    const setup = await createSavedRouteWithOverrides(page, routeName);
    proof.routeCode = setup.routeCode;
    proof.originalOverrideSegments = setup.overrideLegs.map((leg) => leg.segmentId).sort((a, b) => a - b);

    let currentLegs = setup.originalLegs.slice();

    for (let cycle = 1; cycle <= 3; cycle += 1) {
      const cycleProof = {
        cycle,
        beforeReverse: summarizeLegs(currentLegs),
        reversed: [],
        saveRequest: {},
        reopened: [],
        reopenedBadges: []
      };

      await reverseExistingRoute(page);
      const reversed = await snapshotPreviewLegs(page);
      cycleProof.reversed = summarizeLegs(reversed);

      expect(
        reversed.map((leg) => leg.segmentId),
        `Reverse did not change visible order during stress cycle ${cycle}. Before=${JSON.stringify(cycleProof.beforeReverse)} Reversed=${JSON.stringify(cycleProof.reversed)}`
      ).not.toEqual(currentLegs.map((leg) => leg.segmentId));

      const saveResult = await saveRoute(page);
      cycleProof.saveRequest = {
        route_code: String(saveResult.requestBody.route_code || ""),
        direction: String(saveResult.requestBody.direction || ""),
        start_segment_id: String(saveResult.requestBody.start_segment_id || ""),
        end_segment_id: String(saveResult.requestBody.end_segment_id || "")
      };

      await closeRouteBuilderModal(page);
      await reloadDashboard(page);
      await reopenExistingRouteFromDashboard(page, setup.routeCode);

      const reopened = await snapshotPreviewLegs(page);
      const reopenedBadges = reopened.filter((leg) => leg.hasOverride);
      cycleProof.reopened = summarizeLegs(reopened);
      cycleProof.reopenedBadges = summarizeLegs(reopenedBadges);

      expect(
        reopened.map((leg) => leg.segmentId),
        `Reopen after stress cycle ${cycle} did not persist the reversed order. Reversed=${JSON.stringify(cycleProof.reversed)} Reopened=${JSON.stringify(cycleProof.reopened)}`
      ).toEqual(reversed.map((leg) => leg.segmentId));

      expect(
        reopenedBadges.map((leg) => leg.segmentId).sort((a, b) => a - b),
        `Reopen after stress cycle ${cycle} changed canonical override ownership. Expected=${JSON.stringify(proof.originalOverrideSegments)} Reopened=${JSON.stringify(cycleProof.reopenedBadges)}`
      ).toEqual(proof.originalOverrideSegments);

      currentLegs = reopened;
      proof.cycles.push(cycleProof);
    }

    for (const segmentId of proof.originalOverrideSegments) {
      const reopenedLeg = currentLegs.find((leg) => leg.segmentId === segmentId);
      expect(reopenedLeg, `Final stress cycle could not find canonical overridden segment ${segmentId}. Current=${JSON.stringify(summarizeLegs(currentLegs))}`).toBeTruthy();

      const geometryPayload = await loadLegGeometryPayload(page, reopenedLeg.order);
      proof.finalMapOverrideTruth.push({
        expectedSegmentId: segmentId,
        rowOrder: reopenedLeg.order,
        rowHasBadge: reopenedLeg.hasOverride,
        rowRouteLegId: reopenedLeg.routeLegId,
        geometry: summarizeMapPayload(geometryPayload)
      });
      await closeLegMapOverlay(page);
    }

    const nonOverrideLeg = currentLegs.find((leg) => proof.originalOverrideSegments.indexOf(leg.segmentId) === -1);
    if (nonOverrideLeg) {
      const geometryPayload = await loadLegGeometryPayload(page, nonOverrideLeg.order);
      proof.finalMapNonOverrideTruth = {
        rowOrder: nonOverrideLeg.order,
        rowSegmentId: nonOverrideLeg.segmentId,
        rowHasBadge: nonOverrideLeg.hasOverride,
        rowRouteLegId: nonOverrideLeg.routeLegId,
        geometry: summarizeMapPayload(geometryPayload)
      };
      await closeLegMapOverlay(page);
    }

    for (const row of proof.finalMapOverrideTruth) {
      expect(
        !!row.geometry.hasOverride,
        `Final stress cycle map truth lost user override for canonical segment ${row.expectedSegmentId}. Row=${JSON.stringify(row)}`
      ).toBeTruthy();
    }

    if (proof.finalMapNonOverrideTruth) {
      expect(
        !!proof.finalMapNonOverrideTruth.geometry.hasOverride,
        `Final stress cycle non-overridden leg incorrectly resolved user override truth. Truth=${JSON.stringify(proof.finalMapNonOverrideTruth)}`
      ).toBeFalsy();
    }
  } finally {
    const proofJson = JSON.stringify(proof, null, 2);
    console.log("PW_REVERSE_STRESS_LOOP_PROOF " + proofJson);
    await testInfo.attach("reverse-stress-loop-proof.json", {
      body: proofJson,
      contentType: "application/json"
    });
  }
});

test("Route Builder fresh saved route repeated reverse-save in edit mode preserves each saved state", async ({ page }, testInfo) => {
  const proof = {
    routeCode: "",
    baseline: [],
    baselineBadges: [],
    cycleOne: {
      reversed: [],
      postSave: [],
      saveRequest: {}
    },
    cycleTwo: {
      reversed: [],
      postSave: [],
      saveRequest: {}
    },
    reopened: [],
    reopenedBadges: []
  };

  try {
    await page.addInitScript(() => {
      window.__FPW_ENABLE_TEST_HOOKS = true;
    });
    const setup = await createSavedRouteWithOverrides(page, "PW Existing Repeat Reverse Save " + Date.now());
    const routeCode = setup.routeCode;
    proof.routeCode = routeCode;

    const baseline = setup.originalLegs;
    proof.baseline = summarizeLegs(baseline);
    proof.baselineBadges = summarizeLegs(baseline.filter((leg) => leg.hasOverride));
    const baselineBadgeSegments = baseline.filter((leg) => leg.hasOverride).map((leg) => leg.segmentId).sort((a, b) => a - b);

    await reverseExistingRoute(page);
    const cycleOneReversed = await snapshotPreviewLegs(page);
    proof.cycleOne.reversed = summarizeLegs(cycleOneReversed);
    expect(
      cycleOneReversed.map((leg) => leg.segmentId),
      `First in-editor reverse did not change order for ${routeCode}. Baseline=${JSON.stringify(proof.baseline)} Reversed=${JSON.stringify(proof.cycleOne.reversed)}`
    ).not.toEqual(baseline.map((leg) => leg.segmentId));

    const cycleOneSave = await saveRoute(page);
    proof.cycleOne.saveRequest = {
      route_code: String(cycleOneSave.requestBody.route_code || ""),
      direction: String(cycleOneSave.requestBody.direction || ""),
      start_segment_id: String(cycleOneSave.requestBody.start_segment_id || ""),
      end_segment_id: String(cycleOneSave.requestBody.end_segment_id || "")
    };
    const cycleOnePostSave = await snapshotPreviewLegs(page);
    proof.cycleOne.postSave = summarizeLegs(cycleOnePostSave);
    expect(
      cycleOnePostSave.map((leg) => leg.segmentId),
      `First in-editor save changed the just-reversed visible order for ${routeCode}. Reversed=${JSON.stringify(proof.cycleOne.reversed)} PostSave=${JSON.stringify(proof.cycleOne.postSave)}`
    ).toEqual(cycleOneReversed.map((leg) => leg.segmentId));

    await reverseExistingRoute(page);
    const cycleTwoReversed = await snapshotPreviewLegs(page);
    proof.cycleTwo.reversed = summarizeLegs(cycleTwoReversed);
    expect(
      cycleTwoReversed.map((leg) => leg.segmentId),
      `Second in-editor reverse did not change order for ${routeCode}. PreviousSaved=${JSON.stringify(proof.cycleOne.postSave)} Reversed=${JSON.stringify(proof.cycleTwo.reversed)}`
    ).not.toEqual(cycleOnePostSave.map((leg) => leg.segmentId));

    const cycleTwoSave = await saveRoute(page);
    proof.cycleTwo.saveRequest = {
      route_code: String(cycleTwoSave.requestBody.route_code || ""),
      direction: String(cycleTwoSave.requestBody.direction || ""),
      start_segment_id: String(cycleTwoSave.requestBody.start_segment_id || ""),
      end_segment_id: String(cycleTwoSave.requestBody.end_segment_id || "")
    };
    const cycleTwoPostSave = await snapshotPreviewLegs(page);
    proof.cycleTwo.postSave = summarizeLegs(cycleTwoPostSave);
    expect(
      cycleTwoPostSave.map((leg) => leg.segmentId),
      `Second in-editor save changed the just-reversed visible order for ${routeCode}. Reversed=${JSON.stringify(proof.cycleTwo.reversed)} PostSave=${JSON.stringify(proof.cycleTwo.postSave)}`
    ).toEqual(cycleTwoReversed.map((leg) => leg.segmentId));

    await closeRouteBuilderModal(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, routeCode);

    const reopened = await snapshotPreviewLegs(page);
    const reopenedBadges = reopened.filter((leg) => leg.hasOverride);
    proof.reopened = summarizeLegs(reopened);
    proof.reopenedBadges = summarizeLegs(reopenedBadges);

    expect(
      reopened.map((leg) => leg.segmentId),
      `Reopen after repeated in-editor reverse/save cycles restored the wrong state for ${routeCode}. Expected=${JSON.stringify(proof.cycleTwo.postSave)} Reopened=${JSON.stringify(proof.reopened)}`
    ).toEqual(cycleTwoPostSave.map((leg) => leg.segmentId));

    expect(
      reopenedBadges.map((leg) => leg.segmentId).sort((a, b) => a - b),
      `Reopen after repeated in-editor reverse/save cycles changed badge ownership for ${routeCode}. Expected=${JSON.stringify(baselineBadgeSegments)} Reopened=${JSON.stringify(proof.reopenedBadges)}`
    ).toEqual(baselineBadgeSegments);
  } finally {
    const proofJson = JSON.stringify(proof, null, 2);
    console.log("PW_EXISTING_ROUTE_REPEAT_REVERSE_SAVE_PROOF " + proofJson);
    await testInfo.attach("existing-route-repeat-reverse-save-proof.json", {
      body: proofJson,
      contentType: "application/json"
    });
  }
});

test("Route Builder disposable reversed route can be deleted after save", async ({ page }, testInfo) => {
  const proof = {
    routeCode: "",
    original: [],
    reversed: [],
    saveRequest: {},
    deleteResult: null
  };

  try {
    const routeName = "PW Reverse Delete " + Date.now();
    const setup = await createSavedRouteWithOverrides(page, routeName);
    proof.routeCode = setup.routeCode;
    proof.original = summarizeLegs(setup.originalLegs);

    await reverseExistingRoute(page);
    const reversed = await snapshotPreviewLegs(page);
    proof.reversed = summarizeLegs(reversed);

    const saveResult = await saveRoute(page);
    proof.saveRequest = {
      route_code: String(saveResult.requestBody.route_code || ""),
      direction: String(saveResult.requestBody.direction || ""),
      start_segment_id: String(saveResult.requestBody.start_segment_id || ""),
      end_segment_id: String(saveResult.requestBody.end_segment_id || "")
    };

    await closeRouteBuilderModal(page);
    await reloadDashboard(page);
    const deletePayload = await deleteRouteFromDashboard(page, setup.routeCode);
    proof.deleteResult = {
      success: !!deletePayload.SUCCESS,
      message: String(deletePayload.MESSAGE || "")
    };
  } finally {
    const proofJson = JSON.stringify(proof, null, 2);
    console.log("PW_DISPOSABLE_ROUTE_DELETE_PROOF " + proofJson);
    await testInfo.attach("disposable-route-delete-proof.json", {
      body: proofJson,
      contentType: "application/json"
    });
  }
});
