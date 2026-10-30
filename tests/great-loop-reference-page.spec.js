const { test, expect } = require("@playwright/test");
const baseUrl = (process.env.FPW_BASE_URL || "http://127.0.0.1:8500/fpw").replace(/\/$/, "");
const basePath = new URL(baseUrl).pathname;
const route = "/fpw_great_loop_clockwise/";
let reference;
let legs;
function lowerKeys(value) {
  if (Array.isArray(value)) return value.map(lowerKeys);
  if (value && typeof value === "object") return Object.fromEntries(Object.entries(value).map(([k,v]) => [k.toLowerCase(),lowerKeys(v)]));
  return value;
}
test.beforeAll(async ({ request }) => {
  const response = await request.get(baseUrl + "/tests/great-loop-reference-runner.cfm?confirm=RUN_GREAT_LOOP_REFERENCE_TESTS&mode=model");
  expect(response.status()).toBe(200);
  const data = lowerKeys(await response.json());
  expect(data.success).toBe(true);
  reference = data.model;
  legs = reference.sections.flatMap(section => section.legs);
});
for (const width of [1440, 1100, 768, 390]) {
  test("Great Loop timeline page and navigation at " + width + "px", async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    const response = await page.goto(baseUrl + route + "?referenceCheck=1#loopCruiseTimeline");
    expect(response.status()).toBe(200);
    expect(new URL(page.url()).pathname).toBe(basePath + route);
    expect(new URL(page.url()).searchParams.get("referenceCheck")).toBe("1");
    expect(new URL(page.url()).hash).toBe("#loopCruiseTimeline");
    await expect(page.locator("[data-fpw-nav]")).toHaveCount(1);
    await expect(page.locator(".fpw-site-footer")).toHaveCount(1);
    await expect(page.locator(".sections, .legCard")).toHaveCount(0);
    await expect(page.locator("#search, #clearSearch, #expandAll, #collapseAll, #visibleCount")).toHaveCount(0);
    await expect(page.locator("#loopTimelineLegs .fpw-routegen__leg")).toHaveCount(reference.totallegs);
    const rendered = await page.locator("#loopTimelineLegs .fpw-routegen__leg").evaluateAll(rows => rows.map(row => ({
      number: Number(row.dataset.legOrder),
      title: row.querySelector(".fpw-routegen__legname").firstChild.textContent.replace(" -> ", " → "),
      count: Number(row.querySelector(".fpw-routegen__leglocks").textContent)
    })));
    expect(rendered).toEqual(legs.map(leg => ({number: leg.number, title: leg.title, count: leg.lockcount})));
    await expect(page.locator(".fpw-loop-guide h1")).toContainText("COUNTERCLOCKWISE");
    await expect(page.locator(".meta")).toContainText("Counterclockwise");
    await expect(page.locator("#totalCount")).toHaveText(String(reference.totallegs));
    await expect(page.locator("#totalLocks")).toHaveText(String(reference.totallocks));
    await expect(page.locator("#totalLockTime")).toHaveText(reference.locktimelabel);
    await expect(page.locator("body")).not.toContainText("FPW‑friendly");
    await expect(page.locator("body")).not.toContainText("Drop‑in");
    await expect(page.locator("body")).not.toContainText("loop_segments");
    await expect(page.locator(".fpw-brand").first()).toHaveAttribute("href", basePath + "/#top");
    await expect(page.locator(".fpw-site-footer a").filter({ hasText: /^Great Loop Ports$/ })).toHaveAttribute("href", basePath + "/great-loop/ports/");
    await page.evaluate(() => scrollTo(0, 0));
    await expect.poll(() => page.evaluate(() => scrollY)).toBe(0);
    expect(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth)).toBe(false);
    if (width <= 1040) await page.locator("[data-fpw-mobile-toggle]").click();
    await page.locator("#fpwExploreToggle").click();
    const selfLink = page.locator('#fpwExploreMenu a[aria-current="page"]');
    await expect(selfLink).toHaveText(/Great Loop Waterway Legs/);
    await expect(selfLink).toHaveAttribute("href", basePath + route);
    await expect(page.locator('#fpwExploreMenu a[href="' + basePath + route + '#search"]')).toHaveCount(0);
    if (width <= 1040) {
      await page.keyboard.press("Escape");
      await expect(page.locator("[data-fpw-mobile-toggle]")).toBeFocused();
      await page.locator("[data-fpw-mobile-toggle]").click();
    } else await page.keyboard.press("Escape");
    await page.locator(".fpw-login-link").click();
    await expect(page.locator("#fpwAuthModal")).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(page.locator("#fpwAuthModal")).not.toBeVisible();
  });
}

test("reference runner is guarded and JavaScript-disabled visitors see an accurate timeline notice", async ({ browser, request }) => {
  const blocked = await request.get(baseUrl + "/tests/great-loop-reference-runner.cfm");
  expect(blocked.status()).toBe(404);
  const context = await browser.newContext({ javaScriptEnabled: false });
  const page = await context.newPage();
  const response = await page.goto(baseUrl + route);
  expect(response.status()).toBe(200);
  await expect(page.locator(".sections, .legCard")).toHaveCount(0);
  await expect(page.locator("#loopCruiseTimeline noscript p")).toHaveText("Enable JavaScript to view the Great Loop legs, lock details, and interactive Cruise Timeline.");
  await expect(page.locator("#loopTimelineTable")).toBeHidden();
  await expect(page.locator("#totalLocks")).toHaveText(String(reference.totallocks));
  await expect(page.locator(".fpw-site-footer")).toHaveCount(1);
  await context.close();
});
