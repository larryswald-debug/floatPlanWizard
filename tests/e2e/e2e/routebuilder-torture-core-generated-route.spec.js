const { test, expect } = require("@playwright/test");
const {
  closeRouteBuilder,
  loginRouteBuilderUser,
  loginRouteBuilderUserViaApi,
  logoutRouteBuilderUserViaApi,
  reloadDashboard,
  reopenExistingRouteFromDashboard,
  reverseRoute,
  saveRoute,
  snapshotPreviewLegs
} = require("../support/routebuilderHarness");
const {
  describeLegRows,
  expectOverrideOrdersEqual,
  expectOverrideRouteLegIds,
  expectRouteLegSequenceEqual,
  fetchLegOverrides,
  fetchTimelineSegments,
  overrideRouteLegIds,
  overrideSegmentIds,
  routeLegSequence
} = require("../support/routebuilderAssertions");
const { createRouteBuilderCleanup } = require("../support/routebuilderCleanup");
const {
  addOverridesByOrder,
  createGeneratedRouteFixture,
  createHeavilyEditedGeneratedRouteFixture
} = require("../support/routebuilderFactories");

test.describe("Route Builder torture generated/template route correctness", () => {
  let cleanup = null;

  test.beforeEach(async ({ page }) => {
    cleanup = createRouteBuilderCleanup(page);
    await loginRouteBuilderUser(page);
    await cleanup.resetRouteBuilderUserState();
  });

  test.afterEach(async () => {
    if (cleanup) {
      await cleanup.cleanupAll();
      await cleanup.resetRouteBuilderUserState();
      cleanup = null;
    }
  });

  test("generated template route preserves spread-out overrides through reverse -> save -> reopen", async ({ page }, testInfo) => {
    const fixture = await createGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-generated-spread",
      overrideOrders: [],
      closeAfterCreate: false
    });

    const baseLegs = await snapshotPreviewLegs(page);
    const middleOrder = Math.max(2, Math.floor(baseLegs.length / 2));
    const lastOrder = baseLegs.length;
    await addOverridesByOrder(page, fixture.routeCode, [1, middleOrder, lastOrder]);
    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const overriddenLegs = await snapshotPreviewLegs(page);
    const expectedOverrideRouteLegIds = overrideRouteLegIds(overriddenLegs);
    const expectedOverrideSegmentIds = overrideSegmentIds(overriddenLegs);
    expect(expectedOverrideRouteLegIds.length).toBe(3);

    await reverseRoute(page);
    const reversedLegs = await snapshotPreviewLegs(page);
    const saveResult = await saveRoute(page);
    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const reopenedLegs = await snapshotPreviewLegs(page);

    expectRouteLegSequenceEqual(reopenedLegs, reversedLegs, `Generated spread-override route ${fixture.routeCode} lost its reversed saved order.`);
    expectOverrideRouteLegIds(reopenedLegs, expectedOverrideRouteLegIds, `Generated spread-override route ${fixture.routeCode} lost canonical override ownership on reopen.`);

    const timeline = await fetchTimelineSegments(page, fixture.routeCode);
    expectRouteLegSequenceEqual(timeline.segments, reopenedLegs, `Timeline truth diverged for generated spread-override route ${fixture.routeCode}.`);
    expectOverrideOrdersEqual(timeline.segments, reopenedLegs, `Timeline override truth diverged for generated spread-override route ${fixture.routeCode}.`);
    const overrideRows = await fetchLegOverrides(page, fixture.routeCode);
    expect(overrideRows.overrides.map((row) => row.segmentId).sort((a, b) => a - b)).toEqual(expectedOverrideSegmentIds);

    await testInfo.attach("generated-spread-override-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        saveRequest: saveResult.requestBody,
        base: describeLegRows(baseLegs),
        overridden: describeLegRows(overriddenLegs),
        reversed: describeLegRows(reversedLegs),
        reopened: describeLegRows(reopenedLegs)
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("generated route with many prior edits survives repeated reverse/save cycles and logout/login reopen", async ({ page }, testInfo) => {
    test.setTimeout(120000);
    const fixture = await createHeavilyEditedGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-generated-heavy",
      overrideOrders: [1, 2, 8],
      cycles: 3,
      reloadAfterCycles: false
    });

    const expectedFinalLegs = fixture.currentLegs;
    const expectedOverrideRouteLegIds = overrideRouteLegIds(expectedFinalLegs);
    await closeRouteBuilder(page);
    await logoutRouteBuilderUserViaApi(page);
    await loginRouteBuilderUserViaApi(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const reopenedLegs = await snapshotPreviewLegs(page);

    expectRouteLegSequenceEqual(reopenedLegs, expectedFinalLegs, `Heavily edited generated route ${fixture.routeCode} lost its final saved order after logout/login.`);
    expectOverrideRouteLegIds(reopenedLegs, expectedOverrideRouteLegIds, `Heavily edited generated route ${fixture.routeCode} lost override truth after logout/login.`);

    await testInfo.attach("generated-heavy-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        cycles: fixture.cycleStates.map((cycle) => ({
          cycle: cycle.cycle,
          reversed: routeLegSequence(cycle.reversedLegs),
          saved: routeLegSequence(cycle.savedLegs)
        })),
        reopened: describeLegRows(reopenedLegs)
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("generated route preserves first/middle/last override truth after close -> reopen -> reverse -> save -> reopen", async ({ page }, testInfo) => {
    const fixture = await createGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-generated-boundary",
      closeAfterCreate: false
    });
    const initialLegs = await snapshotPreviewLegs(page);
    const boundaryOrders = [1, Math.floor(initialLegs.length / 2), initialLegs.length];
    await addOverridesByOrder(page, fixture.routeCode, boundaryOrders);
    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const overriddenLegs = await snapshotPreviewLegs(page);
    const expectedOverrideRouteLegIds = overrideRouteLegIds(overriddenLegs);
    const expectedOverrideSegmentIds = overrideSegmentIds(overriddenLegs);

    await reverseRoute(page);
    const reversedLegs = await snapshotPreviewLegs(page);
    await saveRoute(page);
    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const reopenedLegs = await snapshotPreviewLegs(page);

    expectRouteLegSequenceEqual(reopenedLegs, reversedLegs, `Generated boundary-override route ${fixture.routeCode} did not preserve reversed order across close/reopen/save.`);
    expectOverrideRouteLegIds(reopenedLegs, expectedOverrideRouteLegIds, `Generated boundary-override route ${fixture.routeCode} lost first/middle/last override truth.`);
    const overrideRows = await fetchLegOverrides(page, fixture.routeCode);
    expect(overrideRows.overrides.map((row) => row.segmentId).sort((a, b) => a - b)).toEqual(expectedOverrideSegmentIds);

    await testInfo.attach("generated-boundary-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        boundaryOrders,
        initial: describeLegRows(initialLegs),
        overridden: describeLegRows(overriddenLegs),
        reversed: describeLegRows(reversedLegs),
        reopened: describeLegRows(reopenedLegs)
      }, null, 2),
      contentType: "application/json"
    });
  });
});
