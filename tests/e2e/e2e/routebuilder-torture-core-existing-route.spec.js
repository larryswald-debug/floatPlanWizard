const { test, expect } = require("@playwright/test");
const {
  closeRouteBuilder,
  loginRouteBuilderUser,
  reloadDashboard,
  reopenExistingRouteFromDashboard,
  reverseRoute,
  saveRoute,
  snapshotCurrentControls,
  snapshotPreviewLegs
} = require("../support/routebuilderHarness");
const {
  assertMapTruthForOrder,
  describeLegRows,
  expectOverrideOrdersEqual,
  expectOverrideRouteLegIds,
  expectRouteLegSequenceChanged,
  expectRouteLegSequenceEqual,
  fetchLegOverrides,
  fetchTimelineSegments,
  findLegByOrder,
  overrideRouteLegIds,
  overrideSegmentIds,
  routeLegSequence
} = require("../support/routebuilderAssertions");
const { createRouteBuilderCleanup } = require("../support/routebuilderCleanup");
const {
  createExistingGeneratedRouteFixture,
  createGeneratedRouteFixture
} = require("../support/routebuilderFactories");

test.describe("Route Builder torture core existing-route correctness", () => {
  /** @type {ReturnType<typeof createRouteBuilderCleanup> | null} */
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

  test("existing saved route with zero overrides survives reverse -> save -> reopen without false override truth", async ({ page }, testInfo) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-core-zero",
      overrideOrders: []
    });
    const originalLegs = await snapshotPreviewLegs(page);
    expect(overrideRouteLegIds(originalLegs)).toEqual([]);

    await reverseRoute(page);
    const reversedLegs = await snapshotPreviewLegs(page);
    expectRouteLegSequenceChanged(originalLegs, reversedLegs, `Reverse did not change existing zero-override route ${fixture.routeCode}.`);

    const saveResult = await saveRoute(page);
    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const reopenedLegs = await snapshotPreviewLegs(page);

    expectRouteLegSequenceEqual(reopenedLegs, reversedLegs, `Reopened zero-override route ${fixture.routeCode} did not preserve the reversed saved order.`);
    expectOverrideRouteLegIds(reopenedLegs, [], `Zero-override route ${fixture.routeCode} showed false override badges after reopen.`);

    const timeline = await fetchTimelineSegments(page, fixture.routeCode);
    expectRouteLegSequenceEqual(timeline.segments, reopenedLegs, `Timeline truth diverged from reopened zero-override route ${fixture.routeCode}.`);
    const overrideRows = await fetchLegOverrides(page, fixture.routeCode);
    expect(overrideRows.overrides).toEqual([]);

    const firstLeg = findLegByOrder(reopenedLegs, 1);
    expect(firstLeg).not.toBeNull();
    await assertMapTruthForOrder(page, 1, {
      routeLegId: firstLeg.routeLegId,
      hasOverride: false
    }, `Zero-override reopen route ${fixture.routeCode} first leg`);

    await testInfo.attach("zero-override-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        saveRequest: saveResult.requestBody,
        original: describeLegRows(originalLegs),
        reversed: describeLegRows(reversedLegs),
        reopened: describeLegRows(reopenedLegs)
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("existing saved route with a single override preserves one canonical override through reverse -> save -> reopen", async ({ page }, testInfo) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-core-single",
      overrideOrders: [1]
    });
    const originalLegs = await snapshotPreviewLegs(page);
    const expectedOverrideRouteLegIds = overrideRouteLegIds(originalLegs);
    const expectedOverrideSegmentIds = overrideSegmentIds(originalLegs);
    expect(expectedOverrideRouteLegIds.length).toBe(1);

    await reverseRoute(page);
    const reversedLegs = await snapshotPreviewLegs(page);
    expectRouteLegSequenceChanged(originalLegs, reversedLegs, `Reverse did not change single-override route ${fixture.routeCode}.`);
    const saveResult = await saveRoute(page);

    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const reopenedLegs = await snapshotPreviewLegs(page);
    expectRouteLegSequenceEqual(reopenedLegs, reversedLegs, `Single-override route ${fixture.routeCode} lost the saved reversed order on reopen.`);
    expectOverrideRouteLegIds(reopenedLegs, expectedOverrideRouteLegIds, `Single-override route ${fixture.routeCode} lost canonical override ownership on reopen.`);

    const timeline = await fetchTimelineSegments(page, fixture.routeCode);
    expectRouteLegSequenceEqual(timeline.segments, reopenedLegs, `Timeline truth diverged from reopened single-override route ${fixture.routeCode}.`);
    expectOverrideOrdersEqual(timeline.segments, reopenedLegs, `Timeline override truth diverged for single-override route ${fixture.routeCode}.`);

    const overrideRows = await fetchLegOverrides(page, fixture.routeCode);
    expect(overrideRows.overrides.map((row) => row.segmentId).sort((a, b) => a - b)).toEqual(expectedOverrideSegmentIds);

    expect(reopenedLegs.filter((leg) => leg.hasOverride)).toHaveLength(1);
    const reopenedOverrideLeg = reopenedLegs.find((leg) => leg.hasOverride);
    const reopenedNonOverrideLeg = reopenedLegs.find((leg) => !leg.hasOverride);
    expect(reopenedOverrideLeg).toBeTruthy();
    expect(reopenedNonOverrideLeg).toBeTruthy();

    await assertMapTruthForOrder(page, reopenedOverrideLeg.order, {
      routeLegId: reopenedOverrideLeg.routeLegId,
      segmentId: expectedOverrideSegmentIds[0],
      hasOverride: true,
      source: "user_override"
    }, `Single-override route ${fixture.routeCode} overridden leg`);
    await assertMapTruthForOrder(page, reopenedNonOverrideLeg.order, {
      routeLegId: reopenedNonOverrideLeg.routeLegId,
      hasOverride: false
    }, `Single-override route ${fixture.routeCode} non-overridden leg`);

    await testInfo.attach("single-override-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        saveRequest: saveResult.requestBody,
        expectedOverrideRouteLegIds,
        original: describeLegRows(originalLegs),
        reversed: describeLegRows(reversedLegs),
        reopened: describeLegRows(reopenedLegs),
        overrideRows: overrideRows.overrides
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("existing saved route with adjacent overrides returns to its original canonical sequence after reverse twice then save", async ({ page }, testInfo) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-core-adjacent",
      overrideOrders: [1, 2]
    });
    const originalLegs = await snapshotPreviewLegs(page);
    const expectedOverrideRouteLegIds = overrideRouteLegIds(originalLegs);
    expect(expectedOverrideRouteLegIds.length).toBe(2);

    await reverseRoute(page);
    const firstReverseLegs = await snapshotPreviewLegs(page);
    expectRouteLegSequenceChanged(originalLegs, firstReverseLegs, `First reverse did not change adjacent-override route ${fixture.routeCode}.`);

    await reverseRoute(page);
    const secondReverseLegs = await snapshotPreviewLegs(page);
    expectRouteLegSequenceEqual(secondReverseLegs, originalLegs, `Double reverse did not restore the original sequence for ${fixture.routeCode}.`);

    const saveResult = await saveRoute(page);
    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const reopenedLegs = await snapshotPreviewLegs(page);
    expectRouteLegSequenceEqual(reopenedLegs, originalLegs, `Double-reversed saved route ${fixture.routeCode} did not reopen in its restored original order.`);
    expectOverrideRouteLegIds(reopenedLegs, expectedOverrideRouteLegIds, `Double-reversed saved route ${fixture.routeCode} lost adjacent override ownership.`);

    await testInfo.attach("double-reverse-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        saveRequest: saveResult.requestBody,
        original: describeLegRows(originalLegs),
        firstReverse: describeLegRows(firstReverseLegs),
        secondReverse: describeLegRows(secondReverseLegs),
        reopened: describeLegRows(reopenedLegs)
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("existing saved route reverse closed without save reopens to the original sequence", async ({ page }, testInfo) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-core-close-unsaved",
      overrideOrders: [1, 2]
    });
    const originalLegs = await snapshotPreviewLegs(page);

    await reverseRoute(page);
    const reversedUnsavedLegs = await snapshotPreviewLegs(page);
    expectRouteLegSequenceChanged(originalLegs, reversedUnsavedLegs, `Unsaved reverse did not change the in-editor order for ${fixture.routeCode}.`);

    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const reopenedLegs = await snapshotPreviewLegs(page);
    expectRouteLegSequenceEqual(reopenedLegs, originalLegs, `Unsaved reverse leaked into reopened state for ${fixture.routeCode}.`);

    await testInfo.attach("unsaved-close-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        original: describeLegRows(originalLegs),
        reversedUnsaved: describeLegRows(reversedUnsavedLegs),
        reopened: describeLegRows(reopenedLegs)
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("existing saved route no-change state stays idempotent when save is unavailable or after a round-trip restore", async ({ page }, testInfo) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-core-idempotent",
      overrideOrders: [1, 4]
    });
    const originalLegs = await snapshotPreviewLegs(page);
    const controlsBefore = await snapshotCurrentControls(page);

    let saveStrategy = "disabled";
    let saveRequest = null;

    if (!controlsBefore.saveDisabled) {
      saveStrategy = "direct-no-change-save";
      const saveResult = await saveRoute(page);
      saveRequest = saveResult.requestBody;
    } else {
      await reverseRoute(page);
      await reverseRoute(page);
      const roundTripLegs = await snapshotPreviewLegs(page);
      expectRouteLegSequenceEqual(roundTripLegs, originalLegs, `Reverse-twice round-trip did not restore the original state for ${fixture.routeCode}.`);
      const saveResult = await saveRoute(page);
      saveRequest = saveResult.requestBody;
      saveStrategy = "reverse-twice-then-save";
    }

    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const reopenedLegs = await snapshotPreviewLegs(page);
    expectRouteLegSequenceEqual(reopenedLegs, originalLegs, `Idempotent save path mutated reopened saved state for ${fixture.routeCode}.`);

    await testInfo.attach("idempotent-save-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        saveStrategy,
        controlsBefore,
        saveRequest,
        originalSequence: routeLegSequence(originalLegs),
        reopenedSequence: routeLegSequence(reopenedLegs)
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("existing route fixture can be created as a true saved route baseline", async ({ page }, testInfo) => {
    const fixture = await createGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-core-baseline",
      overrideOrders: [],
      closeAfterCreate: true
    });

    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const reopenedLegs = await snapshotPreviewLegs(page);
    expect(reopenedLegs.length).toBeGreaterThan(1);

    await testInfo.attach("baseline-existing-route-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        reopened: describeLegRows(reopenedLegs)
      }, null, 2),
      contentType: "application/json"
    });
  });
});
