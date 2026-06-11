const { test, expect } = require("@playwright/test");
const {
  closeRouteBuilder,
  loginRouteBuilderUser,
  prepareGreatLoopPreview,
  reverseRoute,
  snapshotPreviewLegs
} = require("../support/routebuilderHarness");
const {
  describeLegRows,
  expectRouteLegSequenceEqual
} = require("../support/routebuilderAssertions");
const { createRouteBuilderCleanup } = require("../support/routebuilderCleanup");
const {
  createExistingGeneratedRouteFixture
} = require("../support/routebuilderFactories");
const { withFailedRouteBuilderAction } = require("../support/routebuilderChaos");

async function expectRouteBuilderErrorState(page, expectedMessage, expectedStatus) {
  await expect(page.locator("#routeGenError")).toBeVisible({ timeout: 30000 });
  await expect(page.locator("#routeGenError")).toHaveText(expectedMessage, { timeout: 30000 });
  await expect(page.locator("#routeGenStatus")).toHaveText(expectedStatus, { timeout: 30000 });
}

async function confirmDashboardDelete(page) {
  const confirmModal = page.locator("#confirmModal");
  await expect(confirmModal).toBeVisible({ timeout: 15000 });
  const namedBtn = confirmModal.getByRole("button", { name: /^confirm$/i });
  if (await namedBtn.isVisible().catch(() => false)) {
    await namedBtn.click();
  } else {
    await page.locator("#confirmModalOk").click();
  }
  await expect(confirmModal).toBeHidden({ timeout: 30000 });
}

test.describe("Route Builder torture failure paths", () => {
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

  test("routegen_preview failure during direction change surfaces the preview error state and leaves the loading placeholder in place", async ({ page }, testInfo) => {
    const injectedMessage = "Injected routegen_preview failure.";
    await prepareGreatLoopPreview(page, {
      routeName: "rb-fail-preview"
    });
    const baselineLegs = await snapshotPreviewLegs(page);
    expect(baselineLegs.length).toBeGreaterThan(1);

    const failure = await withFailedRouteBuilderAction(page, "routegen_preview", {
      SUCCESS: false,
      MESSAGE: injectedMessage
    }, async () => {
      const responsePromise = page.waitForResponse((response) => {
        return response.request().method() === "POST"
          && response.url().includes("action=routegen_preview");
      }, { timeout: 30000 });
      await page.click("#routeGenDirectionToggle");
      const response = await responsePromise;
      const payload = await response.json();
      expect(!!payload?.SUCCESS).toBeFalsy();
      await expectRouteBuilderErrorState(page, injectedMessage, "Preview failed.");
      await page.waitForFunction(() => !document.querySelector("#routeGenPreviewBtn")?.disabled, null, {
        timeout: 30000
      });
    });

    const afterFailureLegs = await snapshotPreviewLegs(page);
    expect(failure.hits).toHaveLength(1);
    expect(afterFailureLegs).toHaveLength(0);
    await expect(page.locator("#routeGenLegList")).toContainText("Switching direction...", { timeout: 30000 });

    await testInfo.attach("preview-failure-proof", {
      body: JSON.stringify({
        hits: failure.hits,
        error: injectedMessage,
        baseline: describeLegRows(baselineLegs),
        afterFailure: describeLegRows(afterFailureLegs),
        legListText: await page.locator("#routeGenLegList").textContent()
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("routegen_update failure surfaces the save error state without clearing the unsaved reversed preview", async ({ page }, testInfo) => {
    const injectedMessage = "Injected routegen_update failure.";
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-fail-save",
      overrideOrders: [1]
    });

    await reverseRoute(page);
    const reversedLegs = await snapshotPreviewLegs(page);

    const failure = await withFailedRouteBuilderAction(page, "routegen_update", {
      SUCCESS: false,
      MESSAGE: injectedMessage
    }, async () => {
      const responsePromise = page.waitForResponse((response) => {
        return response.request().method() === "POST"
          && response.url().includes("action=routegen_update");
      }, { timeout: 30000 });
      await page.click("#routeGenSaveBtn");
      const response = await responsePromise;
      const payload = await response.json();
      expect(!!payload?.SUCCESS).toBeFalsy();
      await expectRouteBuilderErrorState(page, injectedMessage, "Save failed.");
      await page.waitForFunction(() => !document.querySelector("#routeGenSaveBtn")?.disabled, null, {
        timeout: 30000
      });
    });

    const afterFailureLegs = await snapshotPreviewLegs(page);
    expect(failure.hits).toHaveLength(1);
    expectRouteLegSequenceEqual(
      afterFailureLegs,
      reversedLegs,
      `routegen_update failure cleared the unsaved reversed preview for ${fixture.routeCode}.`
    );

    await testInfo.attach("save-failure-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        hits: failure.hits,
        error: injectedMessage,
        reversed: describeLegRows(reversedLegs),
        afterFailure: describeLegRows(afterFailureLegs)
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("getTimeline failure surfaces the route-load error state without clearing the current preview", async ({ page }, testInfo) => {
    const injectedMessage = "Injected getTimeline failure.";
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-fail-timeline",
      overrideOrders: [1, 2]
    });
    const baselineLegs = await snapshotPreviewLegs(page);

    const failure = await withFailedRouteBuilderAction(page, "getTimeline", {
      SUCCESS: false,
      MESSAGE: injectedMessage
    }, async () => {
      const responsePromise = page.waitForResponse((response) => {
        return response.request().method() === "GET"
          && response.url().includes("action=getTimeline");
      }, { timeout: 30000 });
      await page.evaluate(() => window.FPW.DashboardModules.routeBuilder.reloadTimeline());
      const response = await responsePromise;
      const payload = await response.json();
      expect(!!payload?.SUCCESS).toBeFalsy();
      await expectRouteBuilderErrorState(page, injectedMessage, "Route load failed.");
    });

    const afterFailureLegs = await snapshotPreviewLegs(page);
    expect(failure.hits).toHaveLength(1);
    expectRouteLegSequenceEqual(
      afterFailureLegs,
      baselineLegs,
      `getTimeline failure cleared the current preview for ${fixture.routeCode}.`
    );

    await testInfo.attach("timeline-failure-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        hits: failure.hits,
        error: injectedMessage,
        baseline: describeLegRows(baselineLegs),
        afterFailure: describeLegRows(afterFailureLegs)
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("deleteRoute failure surfaces the dashboard error state and leaves the route card present", async ({ page }, testInfo) => {
    const injectedMessage = "Injected deleteRoute failure.";
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-fail-delete",
      overrideOrders: [1]
    });
    await closeRouteBuilder(page);

    const failure = await withFailedRouteBuilderAction(page, "deleteRoute", {
      SUCCESS: false,
      MESSAGE: injectedMessage
    }, async () => {
      const card = page.locator(`[data-route-code="${fixture.routeCode}"]`).first();
      await expect(card).toBeVisible({ timeout: 30000 });
      const responsePromise = page.waitForResponse((response) => {
        return response.request().method() === "GET"
          && response.url().includes("action=deleteRoute")
          && response.url().includes(encodeURIComponent(fixture.routeCode));
      }, { timeout: 30000 });
      await card.locator(".js-expedition-delete").click();
      await confirmDashboardDelete(page);
      const response = await responsePromise;
      const payload = await response.json();
      expect(!!payload?.SUCCESS).toBeFalsy();
      await expect(page.locator("#expeditionTimelineError")).toBeVisible({ timeout: 30000 });
      await expect(page.locator("#expeditionTimelineErrorText")).toHaveText(injectedMessage, { timeout: 30000 });
      await expect(page.locator("#expeditionTimelineBody")).toBeHidden({ timeout: 30000 });
    });

    expect(failure.hits).toHaveLength(1);
    await expect(page.locator(`[data-route-code="${fixture.routeCode}"]`)).toHaveCount(1, { timeout: 30000 });

    await testInfo.attach("delete-failure-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        hits: failure.hits,
        error: injectedMessage
      }, null, 2),
      contentType: "application/json"
    });
  });
});
