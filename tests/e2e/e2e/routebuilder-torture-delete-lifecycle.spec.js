const { test, expect } = require("@playwright/test");
const {
  closeRouteBuilder,
  deleteRouteCard,
  loginRouteBuilderUser,
  reloadDashboard,
  reopenExistingRouteFromDashboard,
  reverseRoute,
  saveRoute,
  snapshotPreviewLegs,
  callRouteBuilderAction
} = require("../support/routebuilderHarness");
const {
  describeLegRows,
  expectRouteLegSequenceEqual
} = require("../support/routebuilderAssertions");
const { createRouteBuilderCleanup } = require("../support/routebuilderCleanup");
const {
  createExistingGeneratedRouteFixture
} = require("../support/routebuilderFactories");

test.describe("Route Builder torture delete lifecycle", () => {
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

  test("create -> save -> reopen -> delete removes the route and prevents ghost reopen", async ({ page }, testInfo) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-delete-basic",
      overrideOrders: [1]
    });
    const baselineLegs = await snapshotPreviewLegs(page);
    await closeRouteBuilder(page);
    await deleteRouteCard(page, fixture.routeCode);

    const missingTimeline = await callRouteBuilderAction(page, "gettimeline", { routeCode: fixture.routeCode });
    expect(!!missingTimeline?.SUCCESS).toBeFalsy();
    expect(String(missingTimeline?.MESSAGE || "")).toMatch(/not found|route/i);

    await testInfo.attach("delete-basic-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        baseline: describeLegRows(baselineLegs),
        missingTimeline
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("reverse -> save -> reopen -> delete removes the saved reversed route cleanly", async ({ page }, testInfo) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-delete-reversed",
      overrideOrders: [1, 2]
    });
    await reverseRoute(page);
    const reversedLegs = await snapshotPreviewLegs(page);
    await saveRoute(page);
    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const reopenedLegs = await snapshotPreviewLegs(page);
    expectRouteLegSequenceEqual(reopenedLegs, reversedLegs, `Delete-lifecycle route ${fixture.routeCode} failed before delete because reopened saved order drifted.`);

    await closeRouteBuilder(page);
    await deleteRouteCard(page, fixture.routeCode);
    const missingTimeline = await callRouteBuilderAction(page, "gettimeline", { routeCode: fixture.routeCode });
    expect(!!missingTimeline?.SUCCESS).toBeFalsy();

    await testInfo.attach("delete-reversed-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        reversed: describeLegRows(reversedLegs),
        reopened: describeLegRows(reopenedLegs),
        missingTimeline
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("unsaved partial edit can still be discarded and the saved route can be deleted without ghost state", async ({ page }, testInfo) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-delete-unsaved",
      overrideOrders: [1]
    });
    const originalLegs = await snapshotPreviewLegs(page);
    await reverseRoute(page);
    const unsavedLegs = await snapshotPreviewLegs(page);
    await closeRouteBuilder(page);
    await deleteRouteCard(page, fixture.routeCode);

    const missingTimeline = await callRouteBuilderAction(page, "gettimeline", { routeCode: fixture.routeCode });
    expect(!!missingTimeline?.SUCCESS).toBeFalsy();

    await testInfo.attach("delete-unsaved-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        original: describeLegRows(originalLegs),
        unsaved: describeLegRows(unsavedLegs),
        missingTimeline
      }, null, 2),
      contentType: "application/json"
    });
  });
});
