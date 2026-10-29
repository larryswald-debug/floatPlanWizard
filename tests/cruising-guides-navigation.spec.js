const { test, expect } = require("@playwright/test");

const baseUrl = process.env.FPW_BASE_URL || "http://127.0.0.1:8500/fpw";
const basePath = new URL(baseUrl).pathname.replace(/\/$/, "");
const chesapeakePath = "/boating-guides/chesapeake-bay/";
const expectedTitle = "Chesapeake Bay Cruising Guide: Routes, Destinations, Travel Times & Float Plan Planning";
const tabTargets = ["#plan-a-cruise", "#destinations", "#itineraries", "#build-a-route", "#fuel"];

test("Cruising Guides index is server-rendered, canonical, and limited to two published guides", async ({ page }) => {
  const response = await page.goto(baseUrl + "/boating-guides/", { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);
  const html = await response.text();
  const cards = page.locator(".fpw-cruising-card-grid > article.fpw-cruising-card");
  await expect(cards).toHaveCount(2);
  await expect(page.locator("h1")).toHaveCount(1);
  await expect(page.locator("h1")).toHaveText("Cruising Guides");
  await expect(page.locator("link[rel=canonical]")).toHaveAttribute("href", "https://floatplanwizard.com/boating-guides/");
  await expect(page.locator('meta[name="robots"]')).toHaveAttribute("content", "index,follow");
  for (const [index, route] of [[0, chesapeakePath], [1, "/great-loop/trip-planning/"]]) {
    const card = cards.nth(index);
    expect(html).toContain('href="' + basePath + route + '"');
    const links = card.locator("a");
    expect(await links.count()).toBeGreaterThan(0);
    for (const link of await links.all()) await expect(link).toHaveAttribute("href", basePath + route);
    await expect(card.locator("img")).toBeVisible();
    expect(await card.locator("img").getAttribute("alt")).toBeTruthy();
    expect(await card.locator("img").evaluate(img => img.complete && img.naturalWidth > 0)).toBe(true);
  }
  const schemas = await page.locator('script[type="application/ld+json"]').allTextContents();
  const nodes = schemas.flatMap(text => {
    const data = JSON.parse(text);
    return data["@graph"] || [data];
  });
  expect(nodes.some(node => node["@type"] === "CollectionPage")).toBe(true);
  expect(nodes.some(node => node["@type"] === "BreadcrumbList")).toBe(true);
  expect(nodes.some(node => node["@type"] === "Article")).toBe(false);
});

test("Chesapeake hero keeps its original headline, SEO, and external-link behavior", async ({ page }) => {
  await page.goto(baseUrl + chesapeakePath, { waitUntil: "domcontentloaded" });
  await expect(page.locator("h1")).toHaveCount(1);
  await expect(page.locator("#fpw-chesapeake-title")).toHaveText(expectedTitle);
  await expect(page.locator(".fpw-chesapeake-hero .fpw-overdue-lede")).toHaveText(
    "Choose a manageable part of the Bay, research the actual harbor approaches, and turn a destination list into daily legs your boat and crew can handle. This guide connects those decisions to FPW's route builder, distance overrides, fuel estimates, timing and Float Plan workflow."
  );
  await expect(page.locator(".fpw-chesapeake-reviewed time")).toHaveAttribute("datetime", "2026-10-28");
  await expect(page.locator("link[rel=canonical]")).toHaveAttribute("href", "https://floatplanwizard.com" + chesapeakePath);
  const external = await page.locator("#main-content a[href]").evaluateAll(anchors =>
    anchors.filter(anchor => /^https?:$/.test(anchor.protocol) && anchor.origin !== location.origin)
      .map(anchor => ({ target: anchor.target, noopener: anchor.relList.contains("noopener") })));
  expect(external).toHaveLength(24);
  expect(external.every(link => link.target === "_blank" && link.noopener)).toBe(true);
  const article = await page.locator('script[type="application/ld+json"]').first().evaluate(node => {
    const json = JSON.parse(node.textContent);
    return json["@graph"].find(item => item["@type"] === "Article");
  });
  expect(article.headline).toBe(expectedTitle);
  expect(article.url).toBe("https://floatplanwizard.com" + chesapeakePath);
});

test("guide tabs remain real anchors and reach unobscured existing sections at every required width", async ({ page }) => {
  test.setTimeout(90_000);
  for (const width of [1920, 1440, 1280, 1100, 1024, 768, 430, 390]) {
    await page.setViewportSize({ width, height: 1000 });
    await page.goto(baseUrl + chesapeakePath, { waitUntil: "domcontentloaded" });
    const tabs = page.locator("#fpwChesapeakeSectionLinks a");
    expect(await tabs.evaluateAll(nodes => nodes.map(node => node.getAttribute("href")))).toEqual(tabTargets);
    await expect(page.locator(".fpw-overdue-toc")).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    for (const target of tabTargets) expect(await page.locator(target).count()).toBe(1);
    const fuel = tabs.filter({ hasText: "Fuel & Timing" });
    await fuel.scrollIntoViewIfNeeded();
    await fuel.click();
    await expect(page).toHaveURL(baseUrl + chesapeakePath + "#fuel");
    await expect.poll(async () => {
      const before = await page.evaluate(() => scrollY);
      await page.waitForTimeout(150);
      return page.locator("#fuel").evaluate((section, previousY) => {
        const header = document.querySelector("[data-fpw-nav]");
        const heading = section.querySelector("h2") || section;
        const box = heading.getBoundingClientRect();
        return Math.abs(scrollY - previousY) <= 1 &&
          box.top >= header.getBoundingClientRect().bottom - 2 && box.bottom <= innerHeight - 2;
      }, before);
    }, { timeout: 12000 }).toBe(true);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  }
});

test("approved Great Loop leg search anchor reaches its existing filter", async ({ page }) => {
  await page.goto(baseUrl + "/fpw_great_loop_clockwise/index.html#search", { waitUntil: "domcontentloaded" });
  const search = page.locator("#search");
  await expect(search).toHaveCount(1);
  await expect(search).toBeVisible();
  await expect.poll(() => search.evaluate(input => {
    const rect = input.getBoundingClientRect();
    return rect.top >= 0 && rect.bottom <= innerHeight;
  })).toBe(true);
});
