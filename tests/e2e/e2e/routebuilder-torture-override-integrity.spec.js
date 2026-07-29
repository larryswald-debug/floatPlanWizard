const { test, expect } = require("@playwright/test");
const {
  clearOverrideForLeg,
  closeLegMapOverlay,
  closeRouteBuilder,
  loginRouteBuilderUser,
  loadLegGeometryPayload,
  reloadDashboard,
  reopenExistingRouteFromDashboard,
  reverseRoute,
  saveRoute,
  snapshotPreviewLegs
} = require("../support/routebuilderHarness");
const {
  assertMapTruthForOrder,
  describeLegRows,
  expectOverrideOrdersEqual,
  expectOverrideRouteLegIds,
  expectRouteLegSequenceEqual,
  fetchLegOverrides,
  fetchTimelineSegments,
  findLegByOrder,
  overrideRouteLegIds,
  overrideSegmentIds
} = require("../support/routebuilderAssertions");
const { createRouteBuilderCleanup } = require("../support/routebuilderCleanup");
const {
  addOverridesByOrder,
  createExistingGeneratedRouteFixture
} = require("../support/routebuilderFactories");

test.describe("Route Builder torture override integrity", () => {
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

  test("adjacent overrides keep badge truth, map truth, and reopened truth aligned", async ({ page }, testInfo) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-override-adjacent",
      overrideOrders: [1, 2]
    });

    const originalLegs = await snapshotPreviewLegs(page);
    const expectedOverrideRouteLegIds = overrideRouteLegIds(originalLegs);
    const expectedOverrideSegmentIds = overrideSegmentIds(originalLegs);
    await reverseRoute(page);
    const reversedLegs = await snapshotPreviewLegs(page);
    await saveRoute(page);
    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const reopenedLegs = await snapshotPreviewLegs(page);

    expectRouteLegSequenceEqual(reopenedLegs, reversedLegs, `Adjacent-override route ${fixture.routeCode} lost reversed order.`);
    expectOverrideRouteLegIds(reopenedLegs, expectedOverrideRouteLegIds, `Adjacent-override route ${fixture.routeCode} lost badge truth.`);

    const timeline = await fetchTimelineSegments(page, fixture.routeCode);
    expectOverrideOrdersEqual(timeline.segments, reopenedLegs, `Adjacent-override route ${fixture.routeCode} lost reopened timeline override truth.`);
    const expectedExactOverrideOrders = timeline.segments
      .filter((seg) => !!seg.hasExactOverride)
      .map((seg) => parseInt(seg.order || 0, 10) || 0)
      .sort((a, b) => a - b);
    const timelineByOrder = new Map(timeline.segments.map((seg) => [seg.order, seg]));

    const reopenedOverrideLegs = reopenedLegs.filter((leg) => leg.hasOverride);
    expect(reopenedOverrideLegs).toHaveLength(expectedOverrideRouteLegIds.length);
    const actualOverrideSegmentIds = [];
    for (const leg of reopenedOverrideLegs) {
      const timelineLeg = timelineByOrder.get(leg.order) || null;
      expect(timelineLeg, `Missing reopened timeline leg ${leg.order} for ${fixture.routeCode}.`).toBeTruthy();
      const geometry = await assertMapTruthForOrder(page, leg.order, {
        routeLegId: timelineLeg ? timelineLeg.routeLegId : leg.routeLegId,
        hasOverride: !!(timelineLeg && timelineLeg.hasExactOverride),
        hasEffectiveOverride: true,
        source: timelineLeg ? timelineLeg.source : ""
      }, `Adjacent override route ${fixture.routeCode} leg ${leg.order}`);
      actualOverrideSegmentIds.push(parseInt(geometry?.DATA?.segment_id || 0, 10) || 0);
    }
    expect(actualOverrideSegmentIds.sort((a, b) => a - b)).toEqual(expectedOverrideSegmentIds);
    const overrideRows = await fetchLegOverrides(page, fixture.routeCode);
    expect(overrideRows.overrides.map((row) => row.legOrder).sort((a, b) => a - b)).toEqual(expectedExactOverrideOrders);

    await testInfo.attach("adjacent-override-integrity-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        original: describeLegRows(originalLegs),
        reversed: describeLegRows(reversedLegs),
        reopened: describeLegRows(reopenedLegs),
        overrideRows: overrideRows.overrides
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("spread-out overrides remain canonical through repeated reverse/save cycles", async ({ page }, testInfo) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-override-spread",
      overrideOrders: []
    });

    const originalLegs = await snapshotPreviewLegs(page);
    const spreadOrders = [1, Math.floor(originalLegs.length / 2), originalLegs.length];
    await addOverridesByOrder(page, fixture.routeCode, spreadOrders);
    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const overriddenLegs = await snapshotPreviewLegs(page);
    const expectedOverrideRouteLegIds = overrideRouteLegIds(overriddenLegs);

    await reverseRoute(page);
    await saveRoute(page);
    await reverseRoute(page);
    const secondReverseLegs = await snapshotPreviewLegs(page);
    await saveRoute(page);
    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const reopenedLegs = await snapshotPreviewLegs(page);

    expectRouteLegSequenceEqual(reopenedLegs, secondReverseLegs, `Spread-out override route ${fixture.routeCode} lost final saved order.`);
    expectOverrideRouteLegIds(reopenedLegs, expectedOverrideRouteLegIds, `Spread-out override route ${fixture.routeCode} lost canonical override route_leg_ids.`);
    const reopenedTimeline = await fetchTimelineSegments(page, fixture.routeCode);
    expectOverrideOrdersEqual(reopenedTimeline.segments, reopenedLegs, `Spread-out override route ${fixture.routeCode} lost reopened timeline override truth.`);
    const expectedExactOverrideOrders = reopenedTimeline.segments
      .filter((seg) => !!seg.hasExactOverride)
      .map((seg) => parseInt(seg.order || 0, 10) || 0)
      .sort((a, b) => a - b);
    const overrideRows = await fetchLegOverrides(page, fixture.routeCode);
    expect(overrideRows.overrides.map((row) => row.legOrder).sort((a, b) => a - b)).toEqual(expectedExactOverrideOrders);

    await testInfo.attach("spread-override-integrity-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        spreadOrders,
        original: describeLegRows(originalLegs),
        overridden: describeLegRows(overriddenLegs),
        finalSaved: describeLegRows(secondReverseLegs),
        reopened: describeLegRows(reopenedLegs)
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("zero-override route never shows false badge truth after reopen and single-override route never drops its badge truth", async ({ page }, testInfo) => {
    const zeroFixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-override-zero-check",
      overrideOrders: []
    });
    const zeroLegs = await snapshotPreviewLegs(page);
    const expectedZeroOverrideRouteLegIds = overrideRouteLegIds(zeroLegs);
    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, zeroFixture.routeCode);
    const zeroReopened = await snapshotPreviewLegs(page);
    expectOverrideRouteLegIds(zeroReopened, expectedZeroOverrideRouteLegIds, `Zero-override route ${zeroFixture.routeCode} changed its baseline effective badge truth after reopen.`);

    await closeRouteBuilder(page);

    const singleFixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-override-single-check",
      overrideOrders: [1]
    });
    const singleLegs = await snapshotPreviewLegs(page);
    const expectedSingleOverrideRouteLegIds = overrideRouteLegIds(singleLegs);
    expect(expectedSingleOverrideRouteLegIds.length).toBeGreaterThan(0);
    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, singleFixture.routeCode);
    const singleReopened = await snapshotPreviewLegs(page);
    expectOverrideRouteLegIds(singleReopened, expectedSingleOverrideRouteLegIds, `Single-override route ${singleFixture.routeCode} lost its only override badge on reopen.`);

    await testInfo.attach("zero-vs-single-override-proof", {
      body: JSON.stringify({
        zeroRouteCode: zeroFixture.routeCode,
        zeroReopened: describeLegRows(zeroReopened),
        singleRouteCode: singleFixture.routeCode,
        singleReopened: describeLegRows(singleReopened),
        expectedSingleOverrideRouteLegIds
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("override added through leg-map save can be cleared back to canonical default truth and stay cleared after reopen", async ({ page }, testInfo) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-override-clear-cycle",
      overrideOrders: []
    });

    const baselineLegs = await snapshotPreviewLegs(page);
    const baselineOverrideRouteLegIds = overrideRouteLegIds(baselineLegs);
    const targetLeg = baselineLegs.find((leg) => !leg.hasOverride) || findLegByOrder(baselineLegs, 1) || baselineLegs[0];
    expect(targetLeg, `Could not resolve target leg for override add/remove symmetry on ${fixture.routeCode}.`).toBeTruthy();
    const baselineGeometryPayload = await loadLegGeometryPayload(page, targetLeg.order);
    const baselineMapTruth = {
      routeLegId: parseInt(baselineGeometryPayload?.DATA?.route_leg_id || targetLeg.routeLegId || 0, 10) || 0,
      segmentId: parseInt(baselineGeometryPayload?.DATA?.segment_id || targetLeg.segmentId || 0, 10) || 0,
      hasOverride: !!baselineGeometryPayload?.DATA?.has_override,
      hasSegmentOverride: !!baselineGeometryPayload?.DATA?.has_segment_override,
      source: String(baselineGeometryPayload?.DATA?.source || "").trim() || "default"
    };
    await closeLegMapOverlay(page);

    await addOverridesByOrder(page, fixture.routeCode, [targetLeg.order]);
    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const afterAddLegs = await snapshotPreviewLegs(page);
    expectRouteLegSequenceEqual(afterAddLegs, baselineLegs, `Saving an override changed route order for ${fixture.routeCode}.`);
    const addedOverrideLeg = afterAddLegs.find((leg) => leg.order === targetLeg.order) || null;
    expect(addedOverrideLeg && addedOverrideLeg.hasOverride).toBeTruthy();
    await assertMapTruthForOrder(page, targetLeg.order, {
      routeLegId: addedOverrideLeg.routeLegId,
      hasOverride: true,
      source: "user_override"
    }, `Override add/remove route ${fixture.routeCode} added override leg`);
    await closeLegMapOverlay(page);
    const overrideRowsAfterAdd = await fetchLegOverrides(page, fixture.routeCode);
    expect(overrideRowsAfterAdd.overrides.map((row) => row.legOrder)).toEqual([targetLeg.order]);

    await clearOverrideForLeg(page, targetLeg.order);
    const afterClearLegs = await snapshotPreviewLegs(page);
    expectRouteLegSequenceEqual(afterClearLegs, baselineLegs, `Clearing an override changed route order for ${fixture.routeCode}.`);
    expectOverrideRouteLegIds(afterClearLegs, baselineOverrideRouteLegIds, `Cleared override route ${fixture.routeCode} did not return to its baseline effective badge truth before reopen.`);
    const clearedLeg = afterClearLegs.find((leg) => leg.order === targetLeg.order) || null;
    expect(clearedLeg).toBeTruthy();
    await assertMapTruthForOrder(page, targetLeg.order, {
      routeLegId: baselineMapTruth.routeLegId || clearedLeg.routeLegId,
      segmentId: baselineMapTruth.segmentId,
      hasOverride: baselineMapTruth.hasOverride,
      hasSegmentOverride: baselineMapTruth.hasSegmentOverride,
      source: baselineMapTruth.source
    }, `Override add/remove route ${fixture.routeCode} cleared override leg`);
    await closeLegMapOverlay(page);
    const timelineAfterClear = await fetchTimelineSegments(page, fixture.routeCode);
    expectOverrideOrdersEqual(timelineAfterClear.segments, baselineLegs, `Cleared override route ${fixture.routeCode} did not return to baseline timeline override truth before reopen.`);
    const overrideRowsAfterClear = await fetchLegOverrides(page, fixture.routeCode);
    expect(overrideRowsAfterClear.overrides).toEqual([]);

    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const reopenedLegs = await snapshotPreviewLegs(page);
    expectRouteLegSequenceEqual(reopenedLegs, baselineLegs, `Cleared override route ${fixture.routeCode} did not reopen with the canonical default order.`);
    expectOverrideRouteLegIds(reopenedLegs, baselineOverrideRouteLegIds, `Cleared override route ${fixture.routeCode} did not return to baseline effective badge truth after reopen.`);
    await assertMapTruthForOrder(page, targetLeg.order, baselineMapTruth, `Override add/remove route ${fixture.routeCode} reopened cleared leg`);
    await closeLegMapOverlay(page);
    const reopenedTimeline = await fetchTimelineSegments(page, fixture.routeCode);
    expectOverrideOrdersEqual(reopenedTimeline.segments, baselineLegs, `Cleared override route ${fixture.routeCode} did not return to baseline reopened timeline override truth.`);
    const reopenedOverrideRows = await fetchLegOverrides(page, fixture.routeCode);
    expect(reopenedOverrideRows.overrides).toEqual([]);

    await testInfo.attach("override-add-remove-symmetry-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        targetOrder: targetLeg.order,
        baselineMapTruth,
        baseline: describeLegRows(baselineLegs),
        afterAdd: describeLegRows(afterAddLegs),
        afterClear: describeLegRows(afterClearLegs),
        reopened: describeLegRows(reopenedLegs),
        overrideRowsAfterAdd: overrideRowsAfterAdd.overrides,
        overrideRowsAfterClear: overrideRowsAfterClear.overrides,
        reopenedOverrideRows: reopenedOverrideRows.overrides
      }, null, 2),
      contentType: "application/json"
    });
  });
});
