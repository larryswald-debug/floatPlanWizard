const { test, expect } = require("@playwright/test");
const {
  assertNoConsoleErrors,
  attachConsoleErrorCollector
} = require("../support/fpwAssertions");
const {
  cleanupTrackedData,
  createCleanupState,
  trackId
} = require("../support/fpwCleanup");
const { buildTracePrefix } = require("../support/fpwNames");
const { loginApprovedUser, openRouteBuilder } = require("../support/fpwSession");

test.describe.configure({ mode: "serial" });

const sharedState = createCleanupState();
let sharedWaypoints = null;
const OVERRIDE_POINTS = [
  { lat: 27.950575, lon: -82.457178 },
  { lat: 27.824112, lon: -82.529441 },
  { lat: 27.771889, lon: -82.638611 }
];

function requestBodyMatches(postData, bodyPart) {
  const requestBody = String(postData || "");
  if (!bodyPart) {
    return true;
  }
  if (requestBody.includes(bodyPart)) {
    return true;
  }
  const pairMatch = /"([^"]+)":"([^"]+)"/.exec(bodyPart);
  if (pairMatch) {
    const key = pairMatch[1];
    const value = pairMatch[2];
    return requestBody.includes(`${key}=${value}`) || requestBody.includes(`${key}=${encodeURIComponent(value)}`);
  }
  const keyMatch = /"([^"]+)"/.exec(bodyPart);
  if (keyMatch) {
    const key = keyMatch[1];
    return requestBody.includes(`"${key}"`) || requestBody.includes(`${key}=`);
  }
  return false;
}

async function waitForApi(page, urlPart, bodyPart, trigger) {
  const responsePromise = page.waitForResponse((response) => {
    if (!response.url().includes(urlPart)) {
      return false;
    }
    if (response.request().method() !== "POST") {
      return false;
    }
    const postData = response.request().postData() || "";
    return requestBodyMatches(postData, bodyPart);
  }, { timeout: 30000 });
  await trigger();
  const response = await responsePromise;
  return response.json();
}

async function openModal(page, openSelector, modalSelector) {
  const modal = page.locator(modalSelector);
  await page.click(openSelector);
  const openedByClick = await modal.waitFor({ state: "visible", timeout: 5000 })
    .then(() => true)
    .catch(() => false);
  if (!openedByClick) {
    await page.evaluate(([buttonSelector, targetSelector]) => {
      const openBtn = document.querySelector(buttonSelector);
      if (openBtn) {
        openBtn.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, view: window }));
      }
      const modalEl = document.querySelector(targetSelector);
      if (!modalEl || !window.bootstrap || !window.bootstrap.Modal) {
        return;
      }
      window.bootstrap.Modal.getOrCreateInstance(modalEl).show();
    }, [openSelector, modalSelector]);
  }
  await expect(modal).toBeVisible({ timeout: 30000 });
}

async function createWaypoint(page, prefix, label, latitude, longitude) {
  const waypointName = `${prefix} ${label}`;
  const response = await waitForApi(page, "/fpw/api/v1/waypoint.cfc?method=handle", '"action":"save"', async () => {
    await openModal(page, "#addWaypointBtn", "#waypointModal");
    await page.fill("#waypointName", waypointName);
    await page.fill("#waypointLatitude", latitude);
    await page.fill("#waypointLongitude", longitude);
    await page.fill("#waypointNotes", `${label} custom route waypoint`);
    await page.click("#saveWaypointBtn");
  });
  const waypointId = Number(response.WAYPOINTID || 0);
  trackId(sharedState, "waypointIds", waypointId);
  return { waypointId, waypointName };
}

async function ensureWaypoints(page, prefix) {
  if (sharedWaypoints) {
    return sharedWaypoints;
  }
  sharedWaypoints = {
    start: await createWaypoint(page, prefix, "Start A", "27.950575", "-82.457178"),
    middle: await createWaypoint(page, prefix, "Middle B", "27.771889", "-82.638611"),
    extra: await createWaypoint(page, prefix, "Extra C", "27.715906", "-82.748894")
  };
  return sharedWaypoints;
}

async function selectOptionContainingText(page, selector, text) {
  await page.waitForFunction(([selectSelector, wanted]) => {
    const select = document.querySelector(selectSelector);
    if (!select) {
      return false;
    }
    return Array.from(select.options).some((option) => {
      return String(option.textContent || "").includes(wanted);
    });
  }, [selector, text], { timeout: 30000 });
  const options = await page.locator(`${selector} option`).evaluateAll((nodes) => {
    return nodes.map((node) => ({
      text: String(node.textContent || "").trim(),
      value: node.value
    }));
  });
  const match = options.find((option) => option.text.includes(text));
  await page.selectOption(selector, match.value);
}

async function createMyRouteAndWaitForStableControls(page, routeName, options) {
  const opts = options || {};
  const expectLegControlsEnabled = !!opts.expectLegControlsEnabled;
  const payload = await waitForApi(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=createUserRoute", `"route_name":"${routeName}"`, async () => {
    await page.fill("#routeGenMyRouteName", routeName);
    await page.click("#routeGenMyRouteCreateBtn");
  });
  expect(payload.SUCCESS).toBe(true);
  const routeId = Number(payload.DATA.route_id || 0);
  await page.waitForResponse((response) => {
    if (!response.url().includes("/fpw/api/v1/routeBuilder.cfc?method=handle&action=getUserRoute")) {
      return false;
    }
    if (response.request().method() !== "POST") {
      return false;
    }
    return (response.request().postData() || "").includes(`"route_id":${routeId}`);
  }, { timeout: 30000 });
  await page.waitForFunction(([createdRouteId, legControlsEnabled]) => {
    const routeSelect = document.querySelector("#routeGenMyRouteSelect");
    const startSelect = document.querySelector("#routeGenMyRouteStartWaypointSelect");
    const startBtn = document.querySelector("#routeGenMyRouteSetStartBtn");
    const endSelect = document.querySelector("#routeGenMyRouteEndWaypointSelect");
    const addBtn = document.querySelector("#routeGenMyRouteAddWaypointLegBtn");
    return !!routeSelect
      && routeSelect.value === String(createdRouteId)
      && !!startSelect
      && !!startBtn
      && !!endSelect
      && !!addBtn
      && !startSelect.disabled
      && !startBtn.disabled
      && (legControlsEnabled ? !endSelect.disabled : endSelect.disabled)
      && (legControlsEnabled ? !addBtn.disabled : addBtn.disabled);
  }, [routeId, expectLegControlsEnabled], { timeout: 30000 });
  trackId(sharedState, "userRouteIds", routeId);
  return routeId;
}

async function loadMyRouteIntoPreview(page, routeId, routeName) {
  await page.selectOption("#routeGenMyRouteSelect", String(routeId));
  const payload = await waitForApi(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=previewUserRoute", `"route_id":${routeId}`, async () => {
    await page.click("#routeGenMyRouteLoadBtn");
  });
  expect(payload.SUCCESS).toBe(true);
  await expect(page.locator("#routeGenPreviewHeading")).toBeVisible({ timeout: 30000 });
  await expect(page.locator("#routeGenMyRouteLegList")).toBeVisible({ timeout: 30000 });
}

async function setStartWaypointAndWaitForLegControls(page, routeId, waypointName) {
  await selectOptionContainingText(page, "#routeGenMyRouteStartWaypointSelect", waypointName);
  const payload = await waitForApi(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=setUserRouteStartWaypoint", `"route_id":${routeId}`, async () => {
    await page.click("#routeGenMyRouteSetStartBtn");
  });
  expect(payload.SUCCESS).toBe(true);
  const startWaypointId = Number(payload?.DATA?.route?.start_waypoint_id || 0);
  await page.waitForResponse((response) => {
    if (!response.url().includes("/fpw/api/v1/routeBuilder.cfc?method=handle&action=getUserRoute")) {
      return false;
    }
    if (response.request().method() !== "POST") {
      return false;
    }
    return (response.request().postData() || "").includes(`"route_id":${routeId}`);
  }, { timeout: 30000 });
  await page.waitForFunction((activeRouteId) => {
    const routeSelect = document.querySelector("#routeGenMyRouteSelect");
    const endSelect = document.querySelector("#routeGenMyRouteEndWaypointSelect");
    const addBtn = document.querySelector("#routeGenMyRouteAddWaypointLegBtn");
    return !!routeSelect
      && routeSelect.value === String(activeRouteId)
      && !!endSelect
      && !!addBtn
      && !endSelect.disabled
      && !addBtn.disabled
      && endSelect.options.length > 1;
  }, routeId, { timeout: 30000 });
  await expect(page.locator("#routeGenMyRouteStartWaypointSelect")).toHaveValue(String(startWaypointId), { timeout: 30000 });
}

async function addWaypointLeg(page, routeId, waypointName) {
  await selectOptionContainingText(page, "#routeGenMyRouteEndWaypointSelect", waypointName);
  const payload = await waitForApi(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=addWaypointLegToUserRoute", `"route_id":${routeId}`, async () => {
    await page.click("#routeGenMyRouteAddWaypointLegBtn");
  });
  expect(payload.SUCCESS).toBe(true);
}

async function removeFirstLeg(page, routeId) {
  const payload = await waitForApi(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=removeLegFromUserRoute", `"route_id":${routeId}`, async () => {
    await page.locator('#routeGenMyRouteLegList [data-my-route-action="remove-leg"]').first().click();
  });
  expect(payload.SUCCESS).toBe(true);
}

async function saveAndClearMyRouteOverride(page) {
  await page.locator('#routeGenMyRouteLegList [data-my-route-action="edit-geometry"]').first().click();
  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 30000 });
  await page.waitForFunction(() => {
    return !!window.FPW?.DashboardModules?.routeBuilder?.test?.isReady?.();
  }, { timeout: 30000 });
  await page.waitForFunction(() => {
    const snapshot = window.FPW?.DashboardModules?.routeBuilder?.test?.snapshot?.();
    return !!snapshot && !String(snapshot.status || "").includes("Loading geometry");
  }, { timeout: 30000 });
  const geometryReady = await page.evaluate((points) => {
    return window.FPW.DashboardModules.routeBuilder.test.setDraftGeometry(points);
  }, OVERRIDE_POINTS);
  expect(geometryReady).toBe(true);
  await expect(page.locator("#routeGenLegMapStatus")).toContainText("Test geometry loaded.", { timeout: 30000 });

  const savePayload = await waitForApi(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=saveRouteLegOverrideGeometry", '"route_id"', async () => {
    await page.click("#routeGenLegSaveBtn");
  });
  expect(savePayload.SUCCESS).toBe(true);
  await expect(page.locator("#routeGenLegMapSource")).toContainText("user override", { timeout: 30000 });

  const clearPayload = await waitForApi(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=clearRouteLegOverrideGeometry", '"route_id"', async () => {
    await page.click("#routeGenLegRevertBtn");
  });
  expect(clearPayload.SUCCESS).toBe(true);
  await expect(page.locator("#routeGenLegMapSource")).toContainText("default", { timeout: 30000 });
  await page.click("#routeGenLegOverlayCloseBtn");
  await expect(page.locator("#routeGenLegMapPanel")).not.toHaveClass(/is-open/, { timeout: 30000 });
}

async function deleteSelectedMyRoute(page, routeId) {
  await page.selectOption("#routeGenMyRouteSelect", String(routeId));
  const payload = await waitForApi(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=deleteUserRoute", `"route_id":${routeId}`, async () => {
    await page.click("#routeGenMyRouteDeleteBtn");
  });
  expect(payload.SUCCESS).toBe(true);
}

test.afterAll(async ({ browser }) => {
  if (!sharedWaypoints) {
    return;
  }
  const page = await browser.newPage();
  await loginApprovedUser(page);
  await cleanupTrackedData(page, sharedState);
  await page.close();
});

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    window.__FPW_ENABLE_TEST_HOOKS = true;
  });
});

test("custom routes cover create, load, waypoint legs, out-and-back, remove, soft-delete/reactivate, and geometry override", async ({ page }, testInfo) => {
  const consoleErrors = attachConsoleErrorCollector(page);
  const prefix = buildTracePrefix(testInfo, "custom-routes-supported-flows", "my-route-lifecycle");
  await loginApprovedUser(page);
  const waypoints = await ensureWaypoints(page, prefix);

  await openRouteBuilder(page);

  const lifecycleRouteName = `${prefix} Lifecycle My Route`;
  const lifecycleRouteId = await createMyRouteAndWaitForStableControls(page, lifecycleRouteName);
  await setStartWaypointAndWaitForLegControls(page, lifecycleRouteId, waypoints.start.waypointName);
  await addWaypointLeg(page, lifecycleRouteId, waypoints.middle.waypointName);
  await addWaypointLeg(page, lifecycleRouteId, waypoints.extra.waypointName);
  await loadMyRouteIntoPreview(page, lifecycleRouteId, lifecycleRouteName);
  await expect(page.locator("#routeGenMyRouteLegList")).toContainText(waypoints.middle.waypointName);
  await expect(page.locator("#routeGenMyRouteLegList")).toContainText(waypoints.extra.waypointName);

  await removeFirstLeg(page, lifecycleRouteId);
  await expect(page.locator("#routeGenMyRouteLegList")).not.toContainText(`01  ${waypoints.start.waypointName} -> ${waypoints.middle.waypointName}`);

  await deleteSelectedMyRoute(page, lifecycleRouteId);

  const reactivatedRouteId = await createMyRouteAndWaitForStableControls(page, lifecycleRouteName, {
    expectLegControlsEnabled: true
  });
  await expect(reactivatedRouteId).toBeGreaterThan(0);

  const outAndBackRouteName = `${prefix} Out And Back My Route`;
  const outAndBackRouteId = await createMyRouteAndWaitForStableControls(page, outAndBackRouteName);
  await setStartWaypointAndWaitForLegControls(page, outAndBackRouteId, waypoints.start.waypointName);
  await addWaypointLeg(page, outAndBackRouteId, waypoints.middle.waypointName);
  await addWaypointLeg(page, outAndBackRouteId, waypoints.start.waypointName);
  await loadMyRouteIntoPreview(page, outAndBackRouteId, outAndBackRouteName);
  await expect(page.locator("#routeGenMyRouteLegList")).toContainText(`${waypoints.start.waypointName} -> ${waypoints.middle.waypointName}`);
  await expect(page.locator("#routeGenMyRouteLegList")).toContainText(`${waypoints.middle.waypointName} -> ${waypoints.start.waypointName}`);

  await saveAndClearMyRouteOverride(page);
  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 30000 });

  await assertNoConsoleErrors(consoleErrors);
});
