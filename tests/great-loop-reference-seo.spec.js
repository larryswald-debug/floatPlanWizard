const { test, expect } = require("@playwright/test");
const baseUrl = (process.env.FPW_BASE_URL || "http://127.0.0.1:8500/fpw").replace(/\/$/, "");
const path = "/fpw_great_loop_clockwise/";
const canonical = "https://floatplanwizard.com" + path;

test("Great Loop SEO is server-rendered and matches the active template and timeline", async ({ browser }) => {
  const context = await browser.newContext({ javaScriptEnabled: false });
  try {
    const page = await context.newPage();
    const response = await page.goto(baseUrl + path);
    expect(response.status()).toBe(200);
    expect(response.headers()["x-robots-tag"] || "").not.toMatch(/noindex/i);
    await expect(page).toHaveTitle("Great Loop Waterway Legs & Lock Times | FloatPlanWizard");
    await expect(page.locator("h1")).toHaveCount(1);
    await expect(page.locator('meta[name="description"]')).toHaveCount(1);
    const description = await page.locator('meta[name="description"]').getAttribute("content");
    expect(description).toContain("lock names, lock counts, and estimated lock times");
    await expect(page.locator('meta[name="robots"]')).toHaveAttribute("content", "index,follow,max-image-preview:large");
    await expect(page.locator('link[rel="canonical"]')).toHaveCount(1);
    await expect(page.locator('link[rel="canonical"]')).toHaveAttribute("href", canonical);
    await expect(page.locator('meta[property="og:url"]')).toHaveAttribute("content", canonical);
    await expect(page.locator('meta[property="og:title"]')).toHaveAttribute("content", await page.title());
    await expect(page.locator('meta[property="og:description"]')).toHaveAttribute("content", description);
    await expect(page.locator('meta[name="twitter:card"]')).toHaveAttribute("content", "summary_large_image");
    await expect(page.locator('meta[name="twitter:title"]')).toHaveAttribute("content", await page.title());
    const image = await page.locator('meta[property="og:image"]').getAttribute("content");
    expect(image).toBe("https://floatplanwizard.com/assets/images/navigation/great-loop-trawler.png");
    const imageResponse = await page.request.get(baseUrl + new URL(image).pathname);
    expect(imageResponse.status()).toBe(200);
    expect(imageResponse.headers()["content-type"]).toContain("image/png");

    await expect(page.locator('script[type="application/ld+json"]')).toHaveCount(1);
    const json = JSON.parse(await page.locator('script[type="application/ld+json"]').textContent());
    expect(json["@context"]).toBe("https://schema.org");
    const nodes = json["@graph"];
    expect(nodes.map(n => n["@type"])).toEqual(["CollectionPage","ItemList","BreadcrumbList"]);
    const collection = nodes[0], list = nodes[1], breadcrumb = nodes[2];
    expect(collection.url).toBe(canonical);
    expect(collection.mainEntity["@id"]).toBe(list["@id"]);
    expect(collection.breadcrumb["@id"]).toBe(breadcrumb["@id"]);
    const modelResponse = await page.request.get(baseUrl + "/tests/great-loop-reference-runner.cfm?confirm=RUN_GREAT_LOOP_REFERENCE_TESTS&mode=model");
    expect(modelResponse.status()).toBe(200);
    const lowerKeys = value => Array.isArray(value) ? value.map(lowerKeys) : value && typeof value === "object"
      ? Object.fromEntries(Object.entries(value).map(([key, item]) => [key.toLowerCase(), lowerKeys(item)])) : value;
    const data = lowerKeys(await modelResponse.json());
    expect(data.success).toBe(true);
    const cards = data.model.sections.flatMap(section => section.legs).map(leg => ({
      name: leg.title, count: leg.lockcount, time: leg.locktimelabel
    }));
    expect(list.numberOfItems).toBe(cards.length);
    expect(list.itemListElement).toEqual(cards.map((card, i) => ({
      "@type": "ListItem", position: i + 1, name: card.name,
      description: card.count + (card.count === 1 ? " lock" : " locks") + "; estimated lock time: " + card.time + "."
    })));
    expect(breadcrumb.itemListElement.at(-1).item).toBe(canonical);
    expect(JSON.stringify(json)).not.toMatch(/localhost|127\.0\.0\.1|\/fpw_prod\//);
    await expect(page.locator(".legCard")).toHaveCount(0);
    const liveContext = await browser.newContext();
    try {
      const livePage = await liveContext.newPage();
      await livePage.goto(baseUrl + path);
      await expect(livePage.locator("#loopTimelineLegs .fpw-routegen__leg")).toHaveCount(cards.length);
      const liveNames = await livePage.locator("#loopTimelineLegs .fpw-routegen__legname").evaluateAll(nodes =>
        nodes.map(node => node.firstChild.textContent.replace(" -> ", " → ")));
      expect(liveNames).toEqual(cards.map(card => card.name));
    } finally { await liveContext.close(); }
    await expect(page.locator('#fpwExploreMenu a[href$="/fpw_great_loop_clockwise/"]')).toHaveCount(1);
  } finally { await context.close(); }
});

test("direct aliases redirect once to the clean URL and preserve query strings and fragments", async ({ page, request }) => {
  const direct = await request.get(baseUrl + path, { maxRedirects: 0 });
  expect(direct.status()).toBe(200);
  expect(direct.headers().location).toBeUndefined();
  for (const alias of ["/fpw_great_loop_clockwise/index.html", "/fpw_great_loop_clockwise/index.cfm", "/fpw_great_loop_clockwise"]) {
    const response = await request.get(baseUrl + alias + "?seoCheck=1", { maxRedirects: 0 });
    expect(response.status()).toBe(301);
    const location = new URL(response.headers().location, baseUrl);
    expect(location.pathname).toBe(new URL(baseUrl).pathname + path);
    expect(location.search).toBe("?seoCheck=1");
    const final = await request.get(location.href, { maxRedirects: 0 });
    expect(final.status()).toBe(200);
  }
  await page.goto(baseUrl + "/fpw_great_loop_clockwise/index.html?seoCheck=1#loopCruiseTimeline");
  await expect(page).toHaveURL(baseUrl + path + "?seoCheck=1#loopCruiseTimeline");
  await expect(page.locator("#loopCruiseTimeline")).toBeVisible();
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute("href", canonical);
  const css = await request.get(baseUrl + "/fpw_great_loop_clockwise/assets/css/fpw_great_loop.css", { maxRedirects: 0 });
  expect(css.status()).toBe(200);
});

test("robots and sitemap publish the approved canonical page exactly once", async ({ page, request }) => {
  const robots = await request.get(baseUrl + "/robots.txt");
  expect(robots.status()).toBe(200);
  expect(await robots.text()).toContain("Allow: /fpw_great_loop_clockwise/$");
  const sitemap = await request.get(baseUrl + "/sitemap.xml");
  expect(sitemap.status()).toBe(200);
  const parsed = await page.evaluate(xml => {
    const doc = new DOMParser().parseFromString(xml, "application/xml");
    return { errors: doc.querySelectorAll("parsererror").length, urls: [...doc.querySelectorAll("url > loc")].map(n => n.textContent) };
  }, await sitemap.text());
  expect(parsed.errors).toBe(0);
  expect(parsed.urls.filter(url => url === canonical)).toHaveLength(1);
  expect(parsed.urls.some(url => /\/fpw_great_loop_clockwise\/index\.(?:html|cfm)$/.test(url))).toBe(false);
});

test("desktop and mobile menu links open the clean URL directly", async ({ page }) => {
  for (const width of [1440,390]) {
    await page.setViewportSize({ width, height: 1000 });
    await page.goto(baseUrl + "/boating-guides/");
    if (width <= 1040) await page.locator("[data-fpw-mobile-toggle]").click();
    await page.locator("#fpwExploreToggle").click();
    const link = page.locator("#fpwExploreMenu a").filter({ hasText: "Great Loop Waterway Legs" });
    await expect(link).toHaveAttribute("href", new URL(baseUrl).pathname + path);
    const [response] = await Promise.all([
      page.waitForResponse(response => response.request().isNavigationRequest() && response.url() === baseUrl + path),
      link.click()
    ]);
    expect(response.status()).toBe(200);
    expect(response.request().redirectedFrom()).toBeNull();
    await expect(page).toHaveURL(baseUrl + path);
    const timelineRows = page.locator("#loopTimelineLegs .fpw-routegen__leg");
    await expect(timelineRows.first()).toBeVisible();
    await expect(page.locator("#totalCount")).toHaveText(String(await timelineRows.count()));
    await expect(page.locator(".sections, .legCard")).toHaveCount(0);
  }
});
