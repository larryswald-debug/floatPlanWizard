const { test, expect } = require("@playwright/test");

const baseUrl = "http://localhost:8500/fpw";
const guideUrl = `${baseUrl}/shore-contact-overdue-boater.cfm`;

function collectPageErrors(page) {
  const errors = [];
  page.on("console", (message) => {
    if (message.type() === "error") {
      errors.push(`console: ${message.text()}`);
    }
  });
  page.on("pageerror", (error) => {
    errors.push(`pageerror: ${error.message}`);
  });
  return errors;
}

test("shore contact overdue guide renders at all required widths", async ({ page }, testInfo) => {
  const pageErrors = collectPageErrors(page);
  const viewports = [
    { name: "desktop", width: 1440, height: 1000 },
    { name: "small-desktop", width: 1024, height: 900 },
    { name: "tablet", width: 760, height: 900 },
    { name: "mobile", width: 390, height: 844 }
  ];

  for (const viewport of viewports) {
    await page.setViewportSize({ width: viewport.width, height: viewport.height });
    const response = await page.goto(guideUrl, { waitUntil: "domcontentloaded" });

    expect(response && response.status()).toBe(200);
    await expect(page.locator("header.fpw-site-header")).toBeVisible();
    await expect(page.locator("footer.fpw-site-footer")).toBeAttached();
    await expect(page.locator("h1")).toHaveCount(1);
    await expect(page.getByRole("heading", {
      level: 1,
      name: "What a Shore Contact Should Do When a Boater Is Overdue"
    })).toBeVisible();
    await expect(page.getByRole("navigation", { name: "Breadcrumb" })).toBeVisible();
    await expect(page.getByRole("navigation", { name: "In this guide" })).toBeVisible();
    await expect(page.getByRole("note")).toBeVisible();
    await expect(page.getByRole("link", { name: "Plan a Trip with FloatPlanWizard after reading the shore contact overdue boater guide" })).toBeVisible();

    const newPageHasOverflow = await page.locator(".fpw-overdue-page").evaluate(
      (element) => element.scrollWidth > element.clientWidth
    );
    expect(newPageHasOverflow).toBe(false);

    expect(await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth)).toBe(false);

    await page.screenshot({
      path: testInfo.outputPath(`shore-contact-overdue-${viewport.name}-full.png`),
      fullPage: true
    });
  }

  const tocLinks = page.locator(".fpw-overdue-toc a");
  await expect(tocLinks).toHaveCount(6);
  expect(await tocLinks.evaluateAll((links) => links.every((link) => {
    const target = document.querySelector(link.getAttribute("href"));
    return Boolean(target);
  }))).toBe(true);
  expect(pageErrors).toEqual([]);
});

test("guide emits exact metadata and a consistent Article graph", async ({ page }) => {
  const pageErrors = collectPageErrors(page);
  const response = await page.goto(guideUrl, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);

  await expect(page).toHaveTitle("What to Do When a Boater Is Overdue | Shore Contact Guide");
  await expect(page.locator('meta[name="description"]')).toHaveCount(1);
  await expect(page.locator('meta[name="description"]')).toHaveAttribute(
    "content",
    "Learn what a shore contact should do when a boater misses a check-in or expected return, what information to gather, and when to contact authorities."
  );
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute(
    "href",
    "https://floatplanwizard.com/shore-contact-overdue-boater/"
  );

  const schemaScripts = page.locator('script[type="application/ld+json"]');
  await expect(schemaScripts).toHaveCount(1);
  const graph = JSON.parse(await schemaScripts.textContent())["@graph"];
  expect(graph.map((entity) => entity["@type"])).toEqual([
    "Organization",
    "BreadcrumbList",
    "WebPage",
    "Article"
  ]);
  expect(new Set(graph.map((entity) => entity["@id"])).size).toBe(4);

  const article = graph.find((entity) => entity["@type"] === "Article");
  expect(article.url).toBe("https://floatplanwizard.com/shore-contact-overdue-boater/");
  expect(article.headline).toBe("What a Shore Contact Should Do When a Boater Is Overdue");
  expect(article.datePublished).toBe("2026-08-06T11:29:36-04:00");
  expect(article.dateModified).toBe("2026-08-06T11:29:36-04:00");
  expect(article.inLanguage).toBe("en");
  expect(article).not.toHaveProperty("image");
  expect(article.author).toEqual({ "@id": "https://floatplanwizard.com/#organization" });
  expect(article.publisher).toEqual({ "@id": "https://floatplanwizard.com/#organization" });
  expect(article.mainEntityOfPage).toEqual({
    "@id": "https://floatplanwizard.com/shore-contact-overdue-boater/#webpage"
  });
  expect(pageErrors).toEqual([]);
});

test("signed-out CTA fires once and analytics failure does not block navigation", async ({ page }) => {
  const response = await page.goto(guideUrl, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);

  const cta = page.locator("[data-fpw-action-cta]");
  await expect(cta).toHaveCount(1);
  await expect(cta).toHaveAttribute("href", "/fpw/app/join.cfm");
  await expect(cta).toHaveAttribute("data-fpw-track", "shore_contact_overdue_guide_cta_click");
  await expect(cta).toHaveAttribute("data-fpw-track-auth-state", "signed_out");
  await expect(cta).toHaveAttribute("data-fpw-track-destination-key", "join");

  await page.evaluate(() => {
    window.__fpwGuideEvents = [];
    window.FPWAnalytics.track = (name, fields) => window.__fpwGuideEvents.push({ name, fields });
    window.__fpwGuidePreventNavigation = (event) => {
      if (event.target.closest("[data-fpw-action-cta]")) event.preventDefault();
    };
    document.addEventListener("click", window.__fpwGuidePreventNavigation, true);
  });
  await cta.click();

  const events = await page.evaluate(() => window.__fpwGuideEvents);
  expect(events).toEqual([{
    name: "shore_contact_overdue_guide_cta_click",
    fields: {
      source_page: "shore_contact_overdue_guide",
      section: "after_safety_guide",
      cta_type: "plan_trip",
      label: "Plan a Trip",
      auth_state: "signed_out",
      destination_key: "join"
    }
  }]);

  await page.evaluate(() => {
    document.removeEventListener("click", window.__fpwGuidePreventNavigation, true);
    window.FPWAnalytics.track = () => { throw new Error("intentional analytics failure"); };
  });
  await Promise.all([
    page.waitForURL(`${baseUrl}/app/join.cfm`),
    cta.click()
  ]);
  expect(page.url()).toBe(`${baseUrl}/app/join.cfm`);
});

test("CTA remains a normal signed-out link without JavaScript", async ({ browser }) => {
  const context = await browser.newContext({ javaScriptEnabled: false });
  const page = await context.newPage();
  const response = await page.goto(guideUrl, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);

  const cta = page.getByRole("link", {
    name: "Plan a Trip with FloatPlanWizard after reading the shore contact overdue boater guide"
  });
  await expect(cta).toHaveAttribute("href", "/fpw/app/join.cfm");
  await Promise.all([
    page.waitForURL(`${baseUrl}/app/join.cfm`),
    cta.click()
  ]);
  expect(page.url()).toBe(`${baseUrl}/app/join.cfm`);
  await context.close();
});
