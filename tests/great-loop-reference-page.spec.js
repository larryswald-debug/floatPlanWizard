const { test, expect } = require("@playwright/test");
const baseUrl = (process.env.FPW_BASE_URL || "http://127.0.0.1:8500/fpw").replace(/\/$/, "");
const basePath = new URL(baseUrl).pathname;
const route = "/fpw_great_loop_clockwise/index.html";
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
  test("Great Loop shared page, search arrival, and navigation at " + width + "px", async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    const response = await page.goto(baseUrl + route + "?referenceCheck=1#search");
    expect(response.status()).toBe(200);
    expect(new URL(page.url()).pathname).toBe(basePath + route);
    expect(new URL(page.url()).searchParams.get("referenceCheck")).toBe("1");
    expect(new URL(page.url()).hash).toBe("#search");
    await expect(page.locator("[data-fpw-nav]")).toHaveCount(1);
    await expect(page.locator(".fpw-site-footer")).toHaveCount(1);
    await expect(page.locator(".legCard")).toHaveCount(reference.totallegs);
    await expect(page.locator(".legTitle")).toHaveText(legs.map(leg => leg.title));
    await expect(page.locator(".fpw-loop-guide h1")).toContainText("COUNTERCLOCKWISE");
    await expect(page.locator(".meta")).toContainText("Counterclockwise");
    await expect(page.locator("#totalCount")).toHaveText(String(reference.totallegs));
    await expect(page.locator("#totalLocks")).toHaveText(String(reference.totallocks));
    await expect(page.locator("#totalLockTime")).toHaveText(reference.locktimelabel);
    await expect(page.locator(".section")).toHaveCount(reference.sections.length);
    const rendered = await page.locator(".legCard").evaluateAll(cards => cards.map(card => ({
      number: Number(card.dataset.leg),
      count: Number(card.dataset.lockCount),
      minutes: card.dataset.lockMinutes === "" ? null : Number(card.dataset.lockMinutes),
      names: [...card.querySelectorAll(".lockName")].map(n => n.textContent),
      times: [...card.querySelectorAll(".lockDuration")].map(n => n.textContent),
      label: card.querySelector(".lockTime").textContent
    })));
    expect(rendered).toEqual(legs.map(leg => ({
      number: leg.number, count: leg.lockcount, minutes: leg.hasestimate ? leg.lockminutes : null,
      names: leg.locks.map(lock => lock.name), times: leg.locks.map(lock => lock.timelabel),
      label: "Est. lock time: " + leg.locktimelabel
    })));
    await expect(page.locator("body")).not.toContainText("FPW‑friendly");
    await expect(page.locator("body")).not.toContainText("Drop‑in");
    await expect(page.locator("body")).not.toContainText("loop_segments");
    await expect.poll(() => page.evaluate(() => {
      const input = document.querySelector("#search").getBoundingClientRect();
      const header = document.querySelector("[data-fpw-nav]").getBoundingClientRect();
      return input.top >= header.bottom && input.bottom < innerHeight;
    })).toBe(true);
    await expect(page.locator(".fpw-brand").first()).toHaveAttribute("href", basePath + "/#top");
    await expect(page.locator(".fpw-site-footer a").filter({ hasText: /^Great Loop Ports$/ })).toHaveAttribute("href", basePath + "/great-loop/ports/");
    const namedLeg = legs.find(leg => leg.locks.length);
    const lockSearch = namedLeg.locks[0].name;
    await page.locator("#search").fill(lockSearch);
    await expect(page.locator(".legCard:visible")).toHaveCount(legs.filter(leg => leg.searchtext.includes(lockSearch.toLowerCase())).length);
    const lockCard = page.locator('.legCard[data-leg="' + namedLeg.number + '"]');
    await lockCard.locator("summary").focus();
    await page.keyboard.press("Enter");
    await expect(lockCard.locator(".lockName").first()).toBeVisible();
    expect(await lockCard.locator("summary").evaluate(el => el.getBoundingClientRect().height)).toBeGreaterThanOrEqual(44);
    await page.keyboard.press("Enter");
    await expect(lockCard.locator(".lockName").first()).not.toBeVisible();
    await page.locator("#search").fill("Tarpon");
    await expect(page.locator(".legCard:visible")).toHaveCount(2);
    await expect(page.locator("#visibleCount")).toHaveText("2");
    await page.locator("#search").fill("Clewiston");
    await expect(page.locator(".legCard:visible .legTitle")).toHaveText(["Marco Island → Clewiston", "Clewiston → Stuart"]);
    await page.locator("#clearSearch").click();
    await expect(page.locator("#visibleCount")).toHaveText(String(reference.totallegs));
    await page.locator("#expandAll").click();
    await expect(page.locator(".legCard:visible")).toHaveCount(reference.totallegs);
    await page.locator("#collapseAll").click();
    await expect(page.locator(".legCard:visible")).toHaveCount(0);
    await page.locator(".sectionHeader").first().focus();
    await page.keyboard.press("Enter");
    await expect(page.locator(".sectionHeader").first()).toHaveAttribute("aria-expanded", "true");
    await expect(page.locator(".sectionBody").first()).toBeVisible();
    await page.evaluate(() => scrollTo(0, 0));
    await expect.poll(() => page.evaluate(() => scrollY)).toBe(0);
    const geometry = await page.evaluate(() => {
      const brand = document.querySelector(".fpw-loop-guide .brand").getBoundingClientRect();
      const controls = document.querySelector(".fpw-loop-guide .controls").getBoundingClientRect();
      return {
        overflow: document.documentElement.scrollWidth > innerWidth,
        overlap: brand.left < controls.right && brand.right > controls.left && brand.top < controls.bottom && brand.bottom > controls.top
      };
    });
    expect(geometry).toEqual({ overflow: false, overlap: false });
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

test("reference runner is guarded and the server-rendered list works without JavaScript", async ({ browser, request }) => {
  const blocked = await request.get(baseUrl + "/tests/great-loop-reference-runner.cfm");
  expect(blocked.status()).toBe(404);
  const context = await browser.newContext({ javaScriptEnabled: false });
  const page = await context.newPage();
  const response = await page.goto(baseUrl + route);
  expect(response.status()).toBe(200);
  await expect(page.locator(".legCard:visible")).toHaveCount(reference.totallegs);
  await expect(page.locator("#totalLocks")).toHaveText(String(reference.totallocks));
  await page.locator(".lockDetails summary").first().click();
  await expect(page.locator(".lockName").first()).toBeVisible();
  await context.close();
});
