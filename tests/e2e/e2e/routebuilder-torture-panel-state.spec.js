const { test, expect } = require("@playwright/test");
const {
  closeLegMapOverlay,
  closeRouteBuilder,
  loginRouteBuilderUser,
  reloadTimeline,
  reverseRoute,
  saveRoute,
  snapshotPreviewLegs
} = require("../support/routebuilderHarness");
const {
  assertMapTruthForOrder,
  describeLegRows,
  expectOverrideOrdersEqual,
  expectRouteLegSequenceEqual,
  findLegByOrder,
  findLegByRouteLegId,
  overrideRouteLegIds
} = require("../support/routebuilderAssertions");
const { createRouteBuilderCleanup } = require("../support/routebuilderCleanup");
const {
  createExistingGeneratedRouteFixture
} = require("../support/routebuilderFactories");

test.describe("Route Builder torture panel and map state", () => {
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

  test("leg map follows the current leg at order 1 after reverse instead of retaining stale selected-leg state", async ({ page }, testInfo) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-panel-map-order",
      overrideOrders: [1]
    });

    const beforeReverseLegs = await snapshotPreviewLegs(page);
    const beforeOrderOne = findLegByOrder(beforeReverseLegs, 1);
    expect(beforeOrderOne).toBeTruthy();
    await assertMapTruthForOrder(page, 1, {
      routeLegId: beforeOrderOne.routeLegId,
      hasOverride: beforeOrderOne.hasOverride
    }, `Before reverse order 1 on ${fixture.routeCode}`);
    await closeLegMapOverlay(page);

    await reverseRoute(page);
    const afterReverseLegs = await snapshotPreviewLegs(page);
    const afterOrderOne = findLegByOrder(afterReverseLegs, 1);
    expect(afterOrderOne).toBeTruthy();
    expect(afterOrderOne.routeLegId).not.toBe(beforeOrderOne.routeLegId);
    await assertMapTruthForOrder(page, 1, {
      routeLegId: afterOrderOne.routeLegId,
      hasOverride: afterOrderOne.hasOverride
    }, `After reverse order 1 on ${fixture.routeCode}`);

    await testInfo.attach("panel-map-order-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        beforeReverse: describeLegRows(beforeReverseLegs),
        afterReverse: describeLegRows(afterReverseLegs)
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("timeline rebuild after reverse/save leaves the saved route order and override truth unchanged", async ({ page }, testInfo) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-panel-timeline",
      overrideOrders: [1, 2]
    });

    await reverseRoute(page);
    const reversedLegs = await snapshotPreviewLegs(page);
    await saveRoute(page);
    await page.evaluate(() => {
      const input = document.getElementById("routeGenTimelineMaxHours");
      if (!input) {
        throw new Error("routeGenTimelineMaxHours not found");
      }
      input.value = "12";
      input.dispatchEvent(new Event("input", { bubbles: true }));
      input.dispatchEvent(new Event("change", { bubbles: true }));
    });
    await reloadTimeline(page);
    const afterRebuildLegs = await snapshotPreviewLegs(page);
    expectRouteLegSequenceEqual(afterRebuildLegs, reversedLegs, `Timeline rebuild changed the saved route sequence for ${fixture.routeCode}.`);
    expectOverrideOrdersEqual(afterRebuildLegs, reversedLegs, `Timeline rebuild changed override positions for ${fixture.routeCode}.`);

    await closeRouteBuilder(page);
    await testInfo.attach("panel-timeline-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        reversed: describeLegRows(reversedLegs),
        afterRebuild: describeLegRows(afterRebuildLegs)
      }, null, 2),
      contentType: "application/json"
    });
  });
});
