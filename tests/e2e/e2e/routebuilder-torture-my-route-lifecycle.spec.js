const { test, expect } = require("@playwright/test");
const {
  addMyRouteWaypointLeg,
  callRouteBuilderAction,
  closeRouteBuilder,
  createMyRouteViaUi,
  deleteSelectedMyRouteViaUi,
  loginRouteBuilderUser,
  loadMyRoutePreview,
  openRouteBuilder,
  reloadDashboard,
  reopenExistingRouteFromDashboard,
  setMyRouteStartWaypoint,
  snapshotPreviewLegs
} = require("../support/routebuilderHarness");
const {
  describeLegRows,
  expectRouteLegSequenceChanged,
  expectRouteLegSequenceEqual
} = require("../support/routebuilderAssertions");
const { createRouteBuilderCleanup } = require("../support/routebuilderCleanup");
const {
  createWaypointFixture,
  createMyRouteFixture,
  uniqueName
} = require("../support/routebuilderFactories");

async function selectMyRouteById(page, routeId) {
  await page.selectOption("#routeGenMyRouteSelect", String(routeId));
  await expect(page.locator("#routeGenMyRouteSelect")).toHaveValue(String(routeId), { timeout: 30000 });
}

async function snapshotMyRouteLegRows(page) {
  return page.evaluate(() => {
    return Array.from(document.querySelectorAll("#routeGenMyRouteLegList .fpw-routegen__myrouteleg")).map((row) => {
      const title = row.querySelector(".fpw-routegen__myroutelegname");
      const meta = row.querySelector(".fpw-routegen__myroutelegmeta");
      return {
        routeLegId: parseInt(row.getAttribute("data-route-leg-id") || "0", 10) || 0,
        order: parseInt(row.getAttribute("data-order") || "0", 10) || 0,
        name: String(title ? title.textContent || "" : "").trim(),
        meta: String(meta ? meta.textContent || "" : "").trim()
      };
    });
  });
}

function routeLegIdSequence(rows) {
  return Array.from(rows || [])
    .map((row) => parseInt(row?.routeLegId || 0, 10) || 0)
    .filter((value) => value > 0);
}

async function reorderMyRouteLegsViaApi(page, routeId, orderedRouteLegIds) {
  const payload = await callRouteBuilderAction(page, "reorderUserRouteLegs", {
    route_id: routeId,
    route_leg_ids: orderedRouteLegIds
  });
  expect(!!payload?.SUCCESS, `reorderUserRouteLegs failed for My Route ${routeId}: ${payload?.MESSAGE || "unknown error"}`).toBeTruthy();
  return payload;
}

async function waitForMyRouteLegRowOrder(page, expectedRouteLegIds) {
  await page.waitForFunction((expectedIds) => {
    const rows = Array.from(document.querySelectorAll("#routeGenMyRouteLegList .fpw-routegen__myrouteleg"));
    const actualIds = rows.map((row) => parseInt(row.getAttribute("data-route-leg-id") || "0", 10) || 0).filter((value) => value > 0);
    return actualIds.length === expectedIds.length && actualIds.every((value, index) => value === expectedIds[index]);
  }, expectedRouteLegIds, { timeout: 30000 });
}

async function removeLastMyRouteLegViaUi(page) {
  const rows = page.locator("#routeGenMyRouteLegList .fpw-routegen__myrouteleg");
  const rowCount = await rows.count();
  expect(rowCount).toBeGreaterThan(0);
  const lastRow = rows.nth(rowCount - 1);
  const responsePromise = page.waitForResponse((response) => {
    return response.request().method() === "POST"
      && response.url().includes("action=removeLegFromUserRoute");
  }, { timeout: 30000 });
  await lastRow.locator("[data-my-route-action=\"remove-leg\"]").click();
  const response = await responsePromise;
  const payload = await response.json();
  expect(!!(payload && payload.SUCCESS)).toBeTruthy();
  return payload;
}

test.describe("Route Builder torture My Route lifecycle", () => {
  let cleanup = null;

  test.beforeEach(async ({ page }) => {
    cleanup = createRouteBuilderCleanup(page);
    await loginRouteBuilderUser(page);
  });

  test.afterEach(async () => {
    if (cleanup) {
      await cleanup.cleanupAll();
      cleanup = null;
    }
  });

  test("My Route create -> load preview -> close -> reopen keeps the route definition intact", async ({ page }, testInfo) => {
    const fixture = await createMyRouteFixture(page, cleanup, {
      routeName: uniqueName("rb-myroute-preview")
    });
    expect(fixture.previewLegs.length).toBeGreaterThan(1);
    const initialPreview = fixture.previewLegs;

    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await openRouteBuilder(page);
    await page.selectOption("#routeGenMyRouteSelect", String(fixture.routeId));
    await loadMyRoutePreview(page, fixture.routeId);
    const reopenedPreview = await snapshotPreviewLegs(page);
    expectRouteLegSequenceEqual(reopenedPreview, initialPreview, `My Route ${fixture.routeId} did not reload with the same preview after close/reopen.`);

    await testInfo.attach("my-route-preview-proof", {
      body: JSON.stringify({
        originalRouteName: fixture.routeName,
        originalPreview: describeLegRows(initialPreview),
        reopenedPreview: describeLegRows(reopenedPreview)
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("My Route can generate an expedition route that reopens correctly and both route types can then be deleted", async ({ page }, testInfo) => {
    const fixture = await createMyRouteFixture(page, cleanup, {
      routeName: uniqueName("rb-myroute-expedition"),
      generateExpedition: true
    });
    expect(fixture.generatedRoute).toBeTruthy();

    const generatedLegs = await snapshotPreviewLegs(page);
    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.generatedRoute.routeCode);
    const reopenedGeneratedLegs = await snapshotPreviewLegs(page);
    expectRouteLegSequenceEqual(reopenedGeneratedLegs, generatedLegs, `Generated expedition from My Route ${fixture.generatedRoute.routeCode} did not reopen correctly.`);

    await deleteSelectedMyRouteViaUi(page, fixture.routeId);
    cleanup.deleteMyRouteId(fixture.routeId).catch(() => null);
    await closeRouteBuilder(page);

    await testInfo.attach("my-route-expedition-proof", {
      body: JSON.stringify({
        myRouteId: fixture.routeId,
        myRouteName: fixture.routeName,
        generatedRouteCode: fixture.generatedRoute.routeCode,
        generatedPreview: describeLegRows(generatedLegs),
        reopenedGenerated: describeLegRows(reopenedGeneratedLegs)
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("My Route start waypoint can be changed before leg build and the mutated start survives close -> reopen", async ({ page }, testInfo) => {
    const routeName = uniqueName("rb-myroute-start-mutation");
    const startWaypointA = await createWaypointFixture(page, cleanup, {
      namePrefix: `${routeName}-start-a`,
      latitude: "41.8100",
      longitude: "-87.7100"
    });
    const startWaypointB = await createWaypointFixture(page, cleanup, {
      namePrefix: `${routeName}-start-b`,
      latitude: "41.9100",
      longitude: "-87.8100"
    });
    const endWaypoint = await createWaypointFixture(page, cleanup, {
      namePrefix: `${routeName}-end`,
      latitude: "42.0100",
      longitude: "-87.9100"
    });

    await openRouteBuilder(page);
    const createResult = await createMyRouteViaUi(page, routeName);
    const routeId = cleanup.trackMyRouteId(createResult.routeId);

    await setMyRouteStartWaypoint(page, routeId, startWaypointA.waypointName);
    await setMyRouteStartWaypoint(page, routeId, startWaypointB.waypointName);
    await expect(page.locator("#routeGenMyRouteStartWaypointSelect")).toHaveValue(String(startWaypointB.waypointId), { timeout: 30000 });
    await expect(page.locator("#routeGenMyRouteStartMeta")).toContainText(startWaypointB.waypointName, { timeout: 30000 });

    await addMyRouteWaypointLeg(page, routeId, endWaypoint.waypointName);
    const mutatedLegRows = await snapshotMyRouteLegRows(page);
    expect(mutatedLegRows).toHaveLength(1);
    expect(mutatedLegRows[0].name).toContain(startWaypointB.waypointName);
    expect(mutatedLegRows[0].name).toContain(endWaypoint.waypointName);

    await loadMyRoutePreview(page, routeId);
    const mutatedPreview = await snapshotPreviewLegs(page);
    expect(mutatedPreview).toHaveLength(1);
    expect(mutatedPreview[0].name).toContain(startWaypointB.waypointName);
    expect(mutatedPreview[0].name).toContain(endWaypoint.waypointName);

    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await openRouteBuilder(page);
    await selectMyRouteById(page, routeId);
    await expect(page.locator("#routeGenMyRouteStartWaypointSelect")).toHaveValue(String(startWaypointB.waypointId), { timeout: 30000 });
    await expect(page.locator("#routeGenMyRouteStartMeta")).toContainText(startWaypointB.waypointName, { timeout: 30000 });
    await loadMyRoutePreview(page, routeId);
    const reopenedPreview = await snapshotPreviewLegs(page);
    expectRouteLegSequenceEqual(reopenedPreview, mutatedPreview, `My Route ${routeId} lost the mutated start-waypoint route after close/reopen.`);

    await testInfo.attach("my-route-start-mutation-proof", {
      body: JSON.stringify({
        routeId,
        routeName,
        startWaypointA,
        startWaypointB,
        endWaypoint,
        mutatedLegRows,
        mutatedPreview: describeLegRows(mutatedPreview),
        reopenedPreview: describeLegRows(reopenedPreview)
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("My Route post-create add/remove leg edits persist and removing the new tail leg restores the original route", async ({ page }, testInfo) => {
    const extraWaypoint = await createWaypointFixture(page, cleanup, {
      namePrefix: "rb-myroute-leg-mutations-extra",
      latitude: "42.1100",
      longitude: "-88.0100"
    });
    const fixture = await createMyRouteFixture(page, cleanup, {
      routeName: uniqueName("rb-myroute-leg-mutations"),
      waypointCount: 3
    });
    const initialPreview = fixture.previewLegs;
    expect(initialPreview.length).toBeGreaterThan(1);
    const initialLegRows = await snapshotMyRouteLegRows(page);
    expect(initialLegRows).toHaveLength(initialPreview.length);

    await addMyRouteWaypointLeg(page, fixture.routeId, extraWaypoint.waypointName);
    const afterAddLegRows = await snapshotMyRouteLegRows(page);
    expect(afterAddLegRows).toHaveLength(initialLegRows.length + 1);
    expect(afterAddLegRows[afterAddLegRows.length - 1].name).toContain(extraWaypoint.waypointName);
    await loadMyRoutePreview(page, fixture.routeId);
    const afterAddPreview = await snapshotPreviewLegs(page);
    expect(afterAddPreview).toHaveLength(initialPreview.length + 1);
    expectRouteLegSequenceChanged(initialPreview, afterAddPreview, `Adding a post-create waypoint leg did not change My Route ${fixture.routeId}.`);

    await removeLastMyRouteLegViaUi(page);
    const afterRemoveLegRows = await snapshotMyRouteLegRows(page);
    expect(afterRemoveLegRows).toHaveLength(initialLegRows.length);
    await loadMyRoutePreview(page, fixture.routeId);
    const afterRemovePreview = await snapshotPreviewLegs(page);
    expectRouteLegSequenceEqual(afterRemovePreview, initialPreview, `Removing the new tail leg did not restore the original route for My Route ${fixture.routeId}.`);

    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await openRouteBuilder(page);
    await selectMyRouteById(page, fixture.routeId);
    await loadMyRoutePreview(page, fixture.routeId);
    const reopenedPreview = await snapshotPreviewLegs(page);
    expectRouteLegSequenceEqual(reopenedPreview, afterRemovePreview, `My Route ${fixture.routeId} lost its post-create leg edit state after close/reopen.`);

    await testInfo.attach("my-route-leg-mutations-proof", {
      body: JSON.stringify({
        routeId: fixture.routeId,
        routeName: fixture.routeName,
        extraWaypoint,
        initialLegRows,
        afterAddLegRows,
        afterRemoveLegRows,
        initialPreview: describeLegRows(initialPreview),
        afterAddPreview: describeLegRows(afterAddPreview),
        afterRemovePreview: describeLegRows(afterRemovePreview),
        reopenedPreview: describeLegRows(reopenedPreview)
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("My Route leg reorder persists through load preview -> close -> reopen", async ({ page }, testInfo) => {
    const fixture = await createMyRouteFixture(page, cleanup, {
      routeName: uniqueName("rb-myroute-reorder"),
      waypointCount: 4
    });
    const initialPreview = fixture.previewLegs;
    expect(initialPreview.length).toBeGreaterThan(2);
    const initialLegRows = await snapshotMyRouteLegRows(page);
    expect(initialLegRows).toHaveLength(initialPreview.length);

    const desiredRouteLegIds = routeLegIdSequence(initialLegRows).slice().reverse();
    expect(desiredRouteLegIds).toHaveLength(initialLegRows.length);
    expect(desiredRouteLegIds).not.toEqual(routeLegIdSequence(initialLegRows));

    const reorderPayload = await reorderMyRouteLegsViaApi(page, fixture.routeId, desiredRouteLegIds);
    const reorderedPayloadLegIds = Array.isArray(reorderPayload?.DATA?.legs)
      ? reorderPayload.DATA.legs.map((leg) => parseInt(leg.route_leg_id || leg.ROUTE_LEG_ID || 0, 10) || 0).filter((value) => value > 0)
      : [];
    expect(reorderedPayloadLegIds).toEqual(desiredRouteLegIds);

    await loadMyRoutePreview(page, fixture.routeId);
    const reorderedPreview = await snapshotPreviewLegs(page);
    expectRouteLegSequenceChanged(initialPreview, reorderedPreview, `Reordering My Route ${fixture.routeId} did not change the loaded preview.`);
    expect(routeLegIdSequence(reorderedPreview)).toEqual(desiredRouteLegIds);

    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await openRouteBuilder(page);
    await selectMyRouteById(page, fixture.routeId);
    await waitForMyRouteLegRowOrder(page, desiredRouteLegIds);
    const reopenedLegRows = await snapshotMyRouteLegRows(page);
    expect(routeLegIdSequence(reopenedLegRows)).toEqual(desiredRouteLegIds);
    await loadMyRoutePreview(page, fixture.routeId);
    const reopenedPreview = await snapshotPreviewLegs(page);
    expectRouteLegSequenceEqual(reopenedPreview, reorderedPreview, `My Route ${fixture.routeId} lost its reordered leg sequence after close/reopen.`);
    expect(routeLegIdSequence(reopenedPreview)).toEqual(desiredRouteLegIds);

    await testInfo.attach("my-route-reorder-proof", {
      body: JSON.stringify({
        routeId: fixture.routeId,
        routeName: fixture.routeName,
        initialLegRows,
        desiredRouteLegIds,
        reorderedPayloadLegIds,
        initialPreview: describeLegRows(initialPreview),
        reorderedPreview: describeLegRows(reorderedPreview),
        reopenedLegRows,
        reopenedPreview: describeLegRows(reopenedPreview)
      }, null, 2),
      contentType: "application/json"
    });
  });
});
