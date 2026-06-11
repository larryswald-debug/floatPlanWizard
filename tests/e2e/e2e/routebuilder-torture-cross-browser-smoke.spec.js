const { test, expect } = require("@playwright/test");
const {
  closeRouteBuilder,
  deleteRouteCard,
  loginRouteBuilderUser,
  reloadDashboard,
  reopenExistingRouteFromDashboard,
  reverseRoute,
  saveRoute,
  snapshotPreviewLegs
} = require("../support/routebuilderHarness");
const {
  expectOverrideRouteLegIds,
  expectRouteLegSequenceEqual,
  overrideRouteLegIds
} = require("../support/routebuilderAssertions");
const { createRouteBuilderCleanup } = require("../support/routebuilderCleanup");
const {
  createExistingGeneratedRouteFixture
} = require("../support/routebuilderFactories");

test.describe("Route Builder torture cross-browser smoke", () => {
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

  test("critical reverse -> save -> reopen existing-route flow survives in the browser matrix", async ({ page }) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-browser-critical",
      overrideOrders: [1]
    });
    const expectedOverrideRouteLegIds = overrideRouteLegIds(await snapshotPreviewLegs(page));
    await reverseRoute(page);
    const reversedLegs = await snapshotPreviewLegs(page);
    await saveRoute(page);
    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const reopenedLegs = await snapshotPreviewLegs(page);

    expectRouteLegSequenceEqual(reopenedLegs, reversedLegs, `Cross-browser critical flow lost the reversed saved order for ${fixture.routeCode}.`);
    expectOverrideRouteLegIds(reopenedLegs, expectedOverrideRouteLegIds, `Cross-browser critical flow lost override truth for ${fixture.routeCode}.`);
  });

  test("critical create -> reopen -> delete lifecycle survives in the browser matrix", async ({ page }) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-browser-delete",
      overrideOrders: [1, 2]
    });
    const baselineLegs = await snapshotPreviewLegs(page);
    expect(baselineLegs.length).toBeGreaterThan(1);
    await closeRouteBuilder(page);
    await deleteRouteCard(page, fixture.routeCode);
    await expect(page.locator(`[data-route-code="${fixture.routeCode}"]`)).toHaveCount(0);
  });
});
