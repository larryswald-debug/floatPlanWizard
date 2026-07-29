const { test, expect } = require("@playwright/test");
const {
  closeRouteBuilder,
  gotoDashboard,
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
  expectOverrideRouteLegIds,
  expectRouteLegSequenceEqual,
  overrideRouteLegIds
} = require("../support/routebuilderAssertions");
const { createRouteBuilderCleanup } = require("../support/routebuilderCleanup");
const {
  createGeneratedRouteFixture,
  createExistingGeneratedRouteFixture
} = require("../support/routebuilderFactories");

test.describe("Route Builder torture session persistence", () => {
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

  test("saved reversed route survives browser refresh and reopen", async ({ page }, testInfo) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-session-refresh",
      overrideOrders: [1, 2]
    });

    await reverseRoute(page);
    const reversedLegs = await snapshotPreviewLegs(page);
    const expectedOverrideRouteLegIds = overrideRouteLegIds(reversedLegs);
    await saveRoute(page);
    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const reopenedLegs = await snapshotPreviewLegs(page);

    expectRouteLegSequenceEqual(reopenedLegs, reversedLegs, `Refresh + reopen lost the saved reversed state for ${fixture.routeCode}.`);
    expectOverrideRouteLegIds(reopenedLegs, expectedOverrideRouteLegIds, `Refresh + reopen lost override truth for ${fixture.routeCode}.`);

    await testInfo.attach("session-refresh-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        reversed: describeLegRows(reversedLegs),
        reopened: describeLegRows(reopenedLegs)
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("saved reversed route survives logout/login and reopen", async ({ page }, testInfo) => {
    test.setTimeout(120000);
    const fixture = await createGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-session-login",
      overrideOrders: [1],
      closeAfterCreate: false
    });

    await reverseRoute(page);
    const reversedLegs = await snapshotPreviewLegs(page);
    const expectedOverrideRouteLegIds = overrideRouteLegIds(reversedLegs);
    await saveRoute(page);
    await closeRouteBuilder(page);
    await logoutRouteBuilderUserViaApi(page);
    await loginRouteBuilderUserViaApi(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const reopenedLegs = await snapshotPreviewLegs(page);

    expectRouteLegSequenceEqual(reopenedLegs, reversedLegs, `Logout/login reopen lost saved state for ${fixture.routeCode}.`);
    expectOverrideRouteLegIds(reopenedLegs, expectedOverrideRouteLegIds, `Logout/login reopen lost override truth for ${fixture.routeCode}.`);

    await testInfo.attach("session-login-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        reversed: describeLegRows(reversedLegs),
        reopened: describeLegRows(reopenedLegs)
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("editing route B does not contaminate reopened saved state for route A", async ({ page }, testInfo) => {
    const routeAFixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-session-route-a",
      overrideOrders: [1]
    });
    const routeABaselineLegs = await snapshotPreviewLegs(page);
    const routeAExpectedOverrides = overrideRouteLegIds(routeABaselineLegs);
    await closeRouteBuilder(page);

    const routeBFixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-session-route-b",
      overrideOrders: [1, 2]
    });
    await reverseRoute(page);
    const routeBReversedLegs = await snapshotPreviewLegs(page);
    await saveRoute(page);
    await closeRouteBuilder(page);
    await reloadDashboard(page);

    await reopenExistingRouteFromDashboard(page, routeAFixture.routeCode);
    const routeAReopenedLegs = await snapshotPreviewLegs(page);
    expectRouteLegSequenceEqual(routeAReopenedLegs, routeABaselineLegs, `Editing route B contaminated reopened state for route A (${routeAFixture.routeCode}).`);
    expectOverrideRouteLegIds(routeAReopenedLegs, routeAExpectedOverrides, `Editing route B contaminated override truth for route A (${routeAFixture.routeCode}).`);

    await closeRouteBuilder(page);
    await reopenExistingRouteFromDashboard(page, routeBFixture.routeCode);
    const routeBReopenedLegs = await snapshotPreviewLegs(page);
    expectRouteLegSequenceEqual(routeBReopenedLegs, routeBReversedLegs, `Route B (${routeBFixture.routeCode}) lost its own saved state while reopening after route A.`);

    await testInfo.attach("route-a-route-b-proof", {
      body: JSON.stringify({
        routeA: {
          routeCode: routeAFixture.routeCode,
          baseline: describeLegRows(routeABaselineLegs),
          reopened: describeLegRows(routeAReopenedLegs)
        },
        routeB: {
          routeCode: routeBFixture.routeCode,
          reversed: describeLegRows(routeBReversedLegs),
          reopened: describeLegRows(routeBReopenedLegs)
        }
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("unsaved edits in one tab do not contaminate the same route in a second tab, and saved state becomes authoritative only after explicit reopen", async ({ page }, testInfo) => {
    test.setTimeout(120000);
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-session-multitab",
      overrideOrders: [1, 2]
    });
    const baselineLegs = await snapshotPreviewLegs(page);
    const baselineOverrides = overrideRouteLegIds(baselineLegs);
    const page2 = await page.context().newPage();

    try {
      await gotoDashboard(page2);
      await reopenExistingRouteFromDashboard(page2, fixture.routeCode);
      const tabTwoBaselineLegs = await snapshotPreviewLegs(page2);
      expectRouteLegSequenceEqual(tabTwoBaselineLegs, baselineLegs, `Second tab failed to open the same saved baseline for ${fixture.routeCode}.`);
      expectOverrideRouteLegIds(tabTwoBaselineLegs, baselineOverrides, `Second tab opened ${fixture.routeCode} with different override truth than the first tab baseline.`);

      await reverseRoute(page);
      const tabOneUnsavedReversedLegs = await snapshotPreviewLegs(page);
      const tabTwoWhileUnsavedLegs = await snapshotPreviewLegs(page2);
      expectRouteLegSequenceEqual(tabTwoWhileUnsavedLegs, baselineLegs, `Unsaved first-tab edits contaminated the already-open second tab for ${fixture.routeCode}.`);
      expectOverrideRouteLegIds(tabTwoWhileUnsavedLegs, baselineOverrides, `Unsaved first-tab edits contaminated second-tab override truth for ${fixture.routeCode}.`);

      await closeRouteBuilder(page2);
      await reloadDashboard(page2);
      await reopenExistingRouteFromDashboard(page2, fixture.routeCode);
      const tabTwoReopenedBeforeSaveLegs = await snapshotPreviewLegs(page2);
      expectRouteLegSequenceEqual(tabTwoReopenedBeforeSaveLegs, baselineLegs, `Unsaved first-tab edits contaminated second-tab reopen state for ${fixture.routeCode}.`);
      expectOverrideRouteLegIds(tabTwoReopenedBeforeSaveLegs, baselineOverrides, `Unsaved first-tab edits contaminated second-tab reopened override truth for ${fixture.routeCode}.`);

      await saveRoute(page);
      const tabOneSavedLegs = await snapshotPreviewLegs(page);
      const savedOverrides = overrideRouteLegIds(tabOneSavedLegs);

      await closeRouteBuilder(page2);
      await reloadDashboard(page2);
      await reopenExistingRouteFromDashboard(page2, fixture.routeCode);
      const tabTwoReopenedAfterSaveLegs = await snapshotPreviewLegs(page2);
      expectRouteLegSequenceEqual(tabTwoReopenedAfterSaveLegs, tabOneSavedLegs, `Saved first-tab state did not become authoritative after explicit second-tab reopen for ${fixture.routeCode}.`);
      expectOverrideRouteLegIds(tabTwoReopenedAfterSaveLegs, savedOverrides, `Saved first-tab override truth did not become authoritative after explicit second-tab reopen for ${fixture.routeCode}.`);

      await testInfo.attach("session-multitab-same-route-proof", {
        body: JSON.stringify({
          routeCode: fixture.routeCode,
          tabOne: {
            baseline: describeLegRows(baselineLegs),
            unsavedReversed: describeLegRows(tabOneUnsavedReversedLegs),
            saved: describeLegRows(tabOneSavedLegs)
          },
          tabTwo: {
            baseline: describeLegRows(tabTwoBaselineLegs),
            whileUnsavedInTabOne: describeLegRows(tabTwoWhileUnsavedLegs),
            reopenedBeforeSave: describeLegRows(tabTwoReopenedBeforeSaveLegs),
            reopenedAfterSave: describeLegRows(tabTwoReopenedAfterSaveLegs)
          }
        }, null, 2),
        contentType: "application/json"
      });
    } finally {
      await page2.close().catch(() => null);
    }
  });
});
