const { test, expect } = require("@playwright/test");

const baseUrl = process.env.FPW_BASE_URL || "http://127.0.0.1:8500/fpw";
const basePath = new URL(baseUrl).pathname.replace(/\/$/, "");
const timingId = "12-understand-the-cruise-timeline-time-and-fuel-estimates";
const manualPath = "/app/user-manual.cfm";
const contextualIds = [
  "1-find-your-way-around-fpw",
  "23-view-the-completed-trip-record",
  "18-read-active-cruise",
  "19-check-in-and-understand-monitoring",
  "13-use-weather-in-planning-and-underway",
  "14-use-the-linked-fuel-and-range-calculator"
];

async function headingMetrics(page, id) {
  return page.locator('[id="' + id + '"]').evaluate(section => {
    const heading = section.matches("h1,h2,h3") ? section : section.querySelector("h1,h2,h3") || section;
    const rect = heading.getBoundingClientRect();
    const header = document.querySelector("[data-fpw-nav]");
    return {
      hash: location.hash,
      y: scrollY,
      hidden: section.hidden,
      displayed: !!heading.getClientRects().length,
      top: rect.top,
      bottom: rect.bottom,
      headerBottom: header ? header.getBoundingClientRect().bottom : 0,
      viewportHeight: innerHeight
    };
  });
}

async function expectSettledArrival(page, id) {
  await expect(page.locator('[id="' + id + '"]')).toBeVisible();
  await expect.poll(async () => {
    const before = await headingMetrics(page, id);
    await page.waitForTimeout(150);
    const after = await headingMetrics(page, id);
    return !after.hidden && after.displayed &&
      Math.abs(after.y - before.y) <= 1 && Math.abs(after.top - before.top) <= 1 &&
      after.top >= Math.max(0, after.headerBottom) - 2 &&
      after.bottom <= after.viewportHeight - 2;
  }, { timeout: 12_000, message: id + " must settle visibly below the sticky header" }).toBe(true);
  expect(new URL(page.url()).hash).toBe("#" + id);
  return headingMetrics(page, id);
}

async function coldArrival(page, route, id) {
  // Force a new document so this verifies initial-fragment arrival, not only hashchange.
  await page.goto("about:blank");
  const response = await page.goto(baseUrl + route + "#" + id, { waitUntil: "domcontentloaded" });
  expect(response && response.status(), route + "#" + id).toBe(200);
  return expectSettledArrival(page, id);
}

async function clickSharedAnchor(page, width, category, route) {
  if (width <= 1040) {
    const mobile = page.locator("[data-fpw-mobile-toggle]");
    await mobile.click();
    await expect(mobile).toHaveAttribute("aria-expanded", "true");
  }
  await page.locator("#fpw" + category + "Toggle").click();
  const link = page.locator("#fpw" + category + 'Menu a[href="' + basePath + route + '"]');
  await expect(link).toHaveCount(1);
  await link.click();
  if (width <= 1040) await expect(page.locator("[data-fpw-mobile-toggle]")).toHaveAttribute("aria-expanded", "false");
}

for (const width of [1440, 390]) {
  test("cold help and manual anchor arrivals settle below the header at " + width + "px", async ({ page }, testInfo) => {
    test.setTimeout(90_000);
    await page.setViewportSize({ width, height: 900 });
    const routes = [
      ["/help/", "follow"],
      [manualPath, timingId],
      ["/great-loop/trip-planning/", "mileage-override"],
      ...contextualIds.map(id => [manualPath, id])
    ];
    const landings = [];
    for (const [route, id] of routes) {
      landings.push({ route, id, width, metrics: await coldArrival(page, route, id) });
    }
    await testInfo.attach("anchor-landings-" + width, {
      body: JSON.stringify(landings, null, 2), contentType: "application/json"
    });
  });

  test("shared guide links reveal filtered targets with same and different hashes at " + width + "px", async ({ page }, testInfo) => {
    test.setTimeout(90_000);
    await page.setViewportSize({ width, height: 900 });
    const landings = [];
    for (const sameHash of [false, true]) {
      await coldArrival(page, "/help/", sameHash ? "follow" : "great-loop-planning");
      await page.locator("[data-help-search]").fill("billing");
      await expect(page.locator("#follow")).toBeHidden();
      const priorHash = new URL(page.url()).hash;
      await clickSharedAnchor(page, width, "Plan", "/help/#follow");
      await expect(page.locator("[data-help-search]")).toHaveValue("");
      await expect(page.locator("[data-help-section][hidden]")).toHaveCount(0);
      landings.push({ surface: "help", sameHash, priorHash, metrics: await expectSettledArrival(page, "follow") });

      await coldArrival(page, manualPath, sameHash ? timingId : contextualIds[0]);
      await page.locator("[data-manual-search]").fill("password");
      await expect(page.locator('[id="' + timingId + '"]')).toBeHidden();
      const priorManualHash = new URL(page.url()).hash;
      await clickSharedAnchor(page, width, "Tools", manualPath + "#" + timingId);
      await expect(page.locator("[data-manual-search]")).toHaveValue("");
      await expect(page.locator("[data-manual-chapter][hidden]")).toHaveCount(0);
      landings.push({ surface: "manual", sameHash, priorHash: priorManualHash, metrics: await expectSettledArrival(page, timingId) });
    }
    await testInfo.attach("filtered-anchor-landings-" + width, {
      body: JSON.stringify(landings, null, 2), contentType: "application/json"
    });
  });
}
