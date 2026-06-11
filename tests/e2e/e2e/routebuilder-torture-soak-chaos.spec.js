const { test, expect } = require("@playwright/test");
const {
  closeRouteBuilder,
  loginRouteBuilderUser,
  reloadDashboard,
  reopenExistingRouteFromDashboard,
  reverseRoute,
  saveRoute,
  snapshotPreviewLegs
} = require("../support/routebuilderHarness");
const {
  describeLegRows,
  expectRouteLegSequenceEqual,
  overrideRouteLegIds,
  routeLegSequence
} = require("../support/routebuilderAssertions");
const { createRouteBuilderCleanup } = require("../support/routebuilderCleanup");
const {
  createExistingGeneratedRouteFixture
} = require("../support/routebuilderFactories");

test.describe("Route Builder torture soak and chaos", () => {
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

  test("repeated reverse/save cycles stay stable across periodic close/reopen boundaries", async ({ page }, testInfo) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-soak-cycles",
      overrideOrders: [1, 2, 6]
    });
    const cycleProof = [];
    let currentLegs = await snapshotPreviewLegs(page);

    for (let cycle = 1; cycle <= 6; cycle += 1) {
      await reverseRoute(page);
      const reversedLegs = await snapshotPreviewLegs(page);
      await saveRoute(page);
      const savedLegs = await snapshotPreviewLegs(page);
      expectRouteLegSequenceEqual(savedLegs, reversedLegs, `Cycle ${cycle} failed to preserve the immediate saved state for ${fixture.routeCode}.`);

      if (cycle % 2 === 0) {
        await closeRouteBuilder(page);
        await reloadDashboard(page);
        await reopenExistingRouteFromDashboard(page, fixture.routeCode);
        currentLegs = await snapshotPreviewLegs(page);
        expectRouteLegSequenceEqual(currentLegs, savedLegs, `Cycle ${cycle} lost saved state after close/reopen for ${fixture.routeCode}.`);
      } else {
        currentLegs = savedLegs;
      }

      cycleProof.push({
        cycle,
        sequence: routeLegSequence(currentLegs),
        overrideRouteLegIds: overrideRouteLegIds(currentLegs)
      });
    }

    await testInfo.attach("soak-cycle-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        cycleProof,
        finalState: describeLegRows(currentLegs)
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("repeated open/close/reopen actions do not accumulate ghost state before a final save", async ({ page }, testInfo) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-soak-open-close",
      overrideOrders: [1]
    });

    let baselineLegs = await snapshotPreviewLegs(page);
    for (let iteration = 1; iteration <= 5; iteration += 1) {
      await closeRouteBuilder(page);
      await reloadDashboard(page);
      await reopenExistingRouteFromDashboard(page, fixture.routeCode);
      const reopenedLegs = await snapshotPreviewLegs(page);
      expectRouteLegSequenceEqual(reopenedLegs, baselineLegs, `Open/close iteration ${iteration} accumulated ghost state for ${fixture.routeCode}.`);
      baselineLegs = reopenedLegs;
    }

    await reverseRoute(page);
    const reversedLegs = await snapshotPreviewLegs(page);
    await saveRoute(page);
    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const reopenedAfterSave = await snapshotPreviewLegs(page);
    expectRouteLegSequenceEqual(reopenedAfterSave, reversedLegs, `Final saved state drifted after repeated open/close cycles for ${fixture.routeCode}.`);

    await testInfo.attach("soak-open-close-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        baseline: describeLegRows(baselineLegs),
        reversed: describeLegRows(reversedLegs),
        reopenedAfterSave: describeLegRows(reopenedAfterSave)
      }, null, 2),
      contentType: "application/json"
    });
  });
});
