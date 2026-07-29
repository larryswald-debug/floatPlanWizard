const { test, expect } = require("@playwright/test");
const {
  closeRouteBuilder,
  loginRouteBuilderUser,
  reloadDashboard,
  reopenExistingRouteFromDashboard,
  reverseRoute,
  saveRoute,
  snapshotCurrentControls,
  snapshotPreviewLegs,
  wait
} = require("../support/routebuilderHarness");
const {
  describeLegRows,
  expectRouteLegSequenceChanged,
  expectRouteLegSequenceEqual,
  routeLegSequence,
  stableLegSequence
} = require("../support/routebuilderAssertions");
const { createRouteBuilderCleanup } = require("../support/routebuilderCleanup");
const {
  createExistingGeneratedRouteFixture
} = require("../support/routebuilderFactories");
const {
  withDelayedPreviews,
  withDelayedSaves
} = require("../support/routebuilderChaos");

test.describe("Route Builder torture reverse/save race scenarios", () => {
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

  test("delayed save keeps reverse controls locked until the save lifecycle settles", async ({ page }, testInfo) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-race-delayed-save",
      overrideOrders: [1, 2]
    });

    await reverseRoute(page);
    const reversedLegs = await snapshotPreviewLegs(page);

    const delayed = await withDelayedSaves(page, [1200], async () => {
      const savePromise = saveRoute(page);
      await wait(150);
      const toggleStateDuringSave = await page.evaluate(() => {
        const toggle = document.querySelector("#routeGenDirectionToggle");
        return {
          disabled: !!(toggle && toggle.disabled),
          ariaDisabled: toggle ? String(toggle.getAttribute("aria-disabled") || "") : ""
        };
      });
      const controlsDuringSave = await snapshotCurrentControls(page);
      const saveResult = await savePromise;
      return {
        toggleStateDuringSave,
        controlsDuringSave,
        saveResult
      };
    });

    expect(delayed.hits.length).toBeGreaterThan(0);
    expect(delayed.result.toggleStateDuringSave.disabled || delayed.result.controlsDuringSave.saveDisabled).toBeTruthy();

    await reverseRoute(page);
    const secondReverseLegs = await snapshotPreviewLegs(page);
    expectRouteLegSequenceChanged(reversedLegs, secondReverseLegs, `Delayed save route ${fixture.routeCode} still showed a stale no-op reverse after save settled.`);

    await testInfo.attach("delayed-save-race-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        delayedHits: delayed.hits,
        reversed: describeLegRows(reversedLegs),
        secondReverse: describeLegRows(secondReverseLegs),
        controlsDuringSave: delayed.result.controlsDuringSave,
        toggleStateDuringSave: delayed.result.toggleStateDuringSave
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("rapid repeated reverse clicks collapse into one settled preview state instead of flip-flopping out of order", async ({ page }, testInfo) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-race-rapid-reverse",
      overrideOrders: [1]
    });
    const originalLegs = await snapshotPreviewLegs(page);
    const originalControls = await snapshotCurrentControls(page);
    const originalStableSequence = stableLegSequence(originalLegs);
    const reversedStableSequence = originalStableSequence.slice().reverse();

    const delayed = await withDelayedPreviews(page, [900], async () => {
      const clickOne = page.click("#routeGenDirectionToggle");
      await wait(30);
      const clickTwo = page.click("#routeGenDirectionToggle").catch((error) => error?.message || "click-blocked");
      await Promise.allSettled([clickOne, clickTwo]);
      await wait(950);
      return {};
    });

    try {
      await page.waitForFunction(({ expectedOriginal, expectedReversed }) => {
        const canonicalLegName = (name) => {
          let normalized = String(name || "").trim();
          let changed = true;
          while (normalized && changed) {
            changed = false;
            ["Override", "Offshore", "Optional"].forEach((suffix) => {
              if (normalized.endsWith(suffix)) {
                normalized = normalized.slice(0, -suffix.length).trim();
                changed = true;
              }
            });
          }
          return normalized;
        };
        const current = Array.from(document.querySelectorAll("#routeGenLegList .fpw-routegen__leg")).map((row) => {
          const title = row.querySelector(".fpw-routegen__legname");
          return `name:${canonicalLegName(String(title ? title.textContent || "" : "").trim())}`;
        });
        const currentJson = JSON.stringify(current);
        return currentJson === expectedOriginal || currentJson === expectedReversed;
      }, {
        expectedOriginal: JSON.stringify(originalStableSequence),
        expectedReversed: JSON.stringify(reversedStableSequence)
      }, { timeout: 10000 });
    } catch (error) {
      const failedSettleLegs = await snapshotPreviewLegs(page);
      const failedSettleControls = await snapshotCurrentControls(page);
      await testInfo.attach("rapid-reverse-settle-timeout-proof", {
        body: JSON.stringify({
          routeCode: fixture.routeCode,
          delayedHits: delayed.hits,
          originalDirection: originalControls.direction,
          originalStableSequence,
          reversedStableSequence,
          failedSettleDirection: failedSettleControls.direction,
          failedSettleStableSequence: stableLegSequence(failedSettleLegs),
          failedSettleLegs: describeLegRows(failedSettleLegs)
        }, null, 2),
        contentType: "application/json"
      });
      throw error;
    }

    const settledLegs = await snapshotPreviewLegs(page);
    const settledControls = await snapshotCurrentControls(page);
    expect(delayed.hits.length).toBeGreaterThan(0);
    const settledSequence = stableLegSequence(settledLegs);
    const matchesOriginal = JSON.stringify(settledSequence) === JSON.stringify(originalStableSequence);
    const matchesReversed = JSON.stringify(settledSequence) === JSON.stringify(reversedStableSequence);
    expect(matchesOriginal || matchesReversed, `Rapid reverse clicks on ${fixture.routeCode} never settled into either canonical direction.`).toBeTruthy();

    await testInfo.attach("rapid-reverse-race-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        delayedHits: delayed.hits,
        originalDirection: originalControls.direction,
        settledDirection: settledControls.direction,
        original: routeLegSequence(originalLegs),
        settled: routeLegSequence(settledLegs)
      }, null, 2),
      contentType: "application/json"
    });
  });

  test("reverse -> save -> immediate dashboard reopen keeps the final saved state authoritative", async ({ page }, testInfo) => {
    const fixture = await createExistingGeneratedRouteFixture(page, cleanup, {
      namePrefix: "rb-race-immediate-reopen",
      overrideOrders: [1, 2]
    });

    await reverseRoute(page);
    const reversedLegs = await snapshotPreviewLegs(page);
    const saveResult = await saveRoute(page);
    await closeRouteBuilder(page);
    await reloadDashboard(page);
    await reopenExistingRouteFromDashboard(page, fixture.routeCode);
    const reopenedLegs = await snapshotPreviewLegs(page);
    expectRouteLegSequenceEqual(reopenedLegs, reversedLegs, `Immediate reopen after save restored stale state for ${fixture.routeCode}.`);

    await testInfo.attach("immediate-reopen-race-proof", {
      body: JSON.stringify({
        routeCode: fixture.routeCode,
        saveRequest: saveResult.requestBody,
        reversed: describeLegRows(reversedLegs),
        reopened: describeLegRows(reopenedLegs)
      }, null, 2),
      contentType: "application/json"
    });
  });
});
