const { test, expect } = require("@playwright/test");

const baseUrl = "http://localhost:8500/fpw";
const rawGuideUrl = `${baseUrl}/common-boating-emergencies.cfm`;
const cleanGuideUrl = `${baseUrl}/common-boating-emergencies/`;
const requiredSections = [
  "first-60-seconds",
  "choose-emergency-call",
  "mayday-call-script",
  "boat-engine-failure",
  "boat-control-failure",
  "boat-taking-on-water",
  "boat-fire-fuel-leak",
  "boat-ran-aground",
  "boating-collision",
  "person-overboard",
  "boat-capsize",
  "boating-weather-visibility",
  "medical-emergency-on-boat",
  "boat-carbon-monoxide",
  "disabled-boat-immediate-hazard",
  "overdue-boat",
  "boating-emergency-communications",
  "passenger-safety-briefing",
  "boat-emergency-equipment",
  "boating-accident-reporting",
  "printable-boating-emergency-card",
  "boating-emergency-faq",
  "sources"
];

function collectPageErrors(page) {
  const errors = [];
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(`console: ${message.text()}`);
  });
  page.on("pageerror", (error) => errors.push(`pageerror: ${error.message}`));
  return errors;
}

test("clean guide renders complete server-side HTML at the canonical destination", async ({ page }) => {
  const pageErrors = collectPageErrors(page);
  const response = await page.goto(cleanGuideUrl, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);
  await expect(page).toHaveTitle("Common Boating Emergencies: What to Do | FloatPlanWizard");
  await expect(page.locator("h1")).toHaveCount(1);
  await expect(page.getByRole("heading", { level: 1, name: "When Something Goes Wrong on the Water" })).toBeVisible();
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute("href", "https://floatplanwizard.com/common-boating-emergencies/");
  await expect(page.locator("[data-fpw-guide-toc]")).toHaveCount(requiredSections.length);
  for (const sectionId of requiredSections) {
    await expect(page.locator(`#${sectionId}`)).toHaveCount(1);
  }
  expect(await page.locator("[data-fpw-guide-toc]").evaluateAll((links) => links.map((link) => link.getAttribute("href")))).toEqual(
    requiredSections.map((sectionId) => `#${sectionId}`)
  );
  expect(pageErrors).toEqual([]);
});

test("raw and no-slash variants redirect once while preserving query strings", async ({ request }) => {
  const rawResponse = await request.get(`${rawGuideUrl}?utm_source=route_test`, { maxRedirects: 0 });
  expect(rawResponse.status()).toBe(301);
  expect(rawResponse.headers().location).toBe("/fpw/common-boating-emergencies/?utm_source=route_test");

  const noSlashResponse = await request.get(`${baseUrl}/common-boating-emergencies?utm_source=route_test`, { maxRedirects: 0 });
  expect(noSlashResponse.status()).toBe(301);
  expect(noSlashResponse.headers().location).toBe("/fpw/common-boating-emergencies/?utm_source=route_test");

  const cleanResponse = await request.get(`${cleanGuideUrl}?utm_source=route_test`, { maxRedirects: 0 });
  expect(cleanResponse.status()).toBe(200);
  expect(await cleanResponse.text()).toContain("When Something Goes Wrong on the Water");
});

test("metadata and JSON-LD are exact and internally consistent", async ({ page }) => {
  await page.goto(rawGuideUrl, { waitUntil: "domcontentloaded" });
  await expect(page.locator('meta[name="description"]')).toHaveAttribute(
    "content",
    "Learn what to do if your boat loses power, takes on water, runs aground, catches fire, encounters severe weather, or has a person overboard."
  );
  await expect(page.locator('meta[name="robots"]')).toHaveAttribute("content", "index,follow,max-image-preview:large");
  await expect(page.locator('meta[property="og:url"]')).toHaveAttribute("content", "https://floatplanwizard.com/common-boating-emergencies/");

  const schemaScripts = page.locator('script[type="application/ld+json"]');
  await expect(schemaScripts).toHaveCount(1);
  const graph = JSON.parse(await schemaScripts.textContent())["@graph"];
  expect(graph.map((entity) => entity["@type"])).toEqual(["Organization", "BreadcrumbList", "WebPage", "Article"]);
  expect(graph.some((entity) => entity["@type"] === "FAQPage" || entity["@type"] === "HowTo")).toBe(false);
  const article = graph.find((entity) => entity["@type"] === "Article");
  expect(article.url).toBe("https://floatplanwizard.com/common-boating-emergencies/");
  expect(article.headline).toBe("When Something Goes Wrong on the Water: A Practical Guide to Common Boating Emergencies");
  expect(article.datePublished).toBe("2026-08-23");
  expect(article.dateModified).toBe("2026-08-23");
  expect(article.inLanguage).toBe("en");
  expect(article).not.toHaveProperty("image");
});

test("the page has no document-level overflow from 320 through 1440 CSS pixels", async ({ page }, testInfo) => {
  const pageErrors = collectPageErrors(page);
  const viewports = [
    { name: "wide", width: 1440, height: 1000 },
    { name: "desktop", width: 1024, height: 900 },
    { name: "tablet", width: 768, height: 900 },
    { name: "mobile", width: 375, height: 812 },
    { name: "minimum", width: 320, height: 700 }
  ];

  for (const viewport of viewports) {
    await page.setViewportSize({ width: viewport.width, height: viewport.height });
    const response = await page.goto(rawGuideUrl, { waitUntil: "domcontentloaded" });
    expect(response && response.status(), viewport.name).toBe(200);
    await expect(page.locator("header.fpw-site-header"), viewport.name).toBeVisible();
    await expect(page.locator("footer.fpw-site-footer"), viewport.name).toBeAttached();
    await expect(page.getByRole("navigation", { name: "Breadcrumb" }), viewport.name).toBeVisible();
    await expect(page.getByRole("navigation", { name: "In this guide" }), viewport.name).toBeVisible();
    await expect(page.locator("[data-fpw-action-cta]"), viewport.name).toHaveCount(2);
    await expect(page.locator("[data-fpw-guide-print]"), viewport.name).toHaveCount(2);
    expect(await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth), viewport.name).toBe(false);
    expect(await page.locator(".fpw-emergency-page").evaluate((element) => element.scrollWidth > element.clientWidth), viewport.name).toBe(false);
    await page.screenshot({ path: testInfo.outputPath(`common-boating-emergencies-${viewport.name}.png`), fullPage: true });
  }
  expect(pageErrors).toEqual([]);
});

test("print mode keeps the complete article and hides site-only controls", async ({ page }) => {
  await page.goto(rawGuideUrl, { waitUntil: "domcontentloaded" });
  await page.emulateMedia({ media: "print" });
  await expect(page.getByRole("heading", { level: 1, name: "When Something Goes Wrong on the Water" })).toBeVisible();
  await expect(page.locator("#first-60-seconds")).toBeVisible();
  await expect(page.locator("#sources")).toBeVisible();
  await expect(page.locator("header.fpw-site-header")).toBeHidden();
  await expect(page.locator("footer.fpw-site-footer")).toBeHidden();
  await expect(page.locator(".fpw-emergency-toc")).toBeHidden();
  await expect(page.locator("[data-fpw-action-cta]").first()).toBeHidden();
  await expect(page.locator("[data-fpw-guide-print]").first()).toBeHidden();
  expect(await page.locator(".fpw-emergency-hero").evaluate((element) => getComputedStyle(element).backgroundColor)).toBe("rgb(255, 255, 255)");
  expect(await page.locator(".fpw-emergency-evidence").evaluate((element) => getComputedStyle(element).backgroundColor)).toBe("rgb(255, 255, 255)");
  expect(await page.locator(".fpw-emergency-supplement").evaluate((element) => getComputedStyle(element).color)).toBe("rgb(0, 0, 0)");
});

test("skip link and anchored headings remain visible above the fixed header", async ({ page }) => {
  for (const viewport of [{ width: 1440, height: 1000 }, { width: 320, height: 700 }]) {
    await page.setViewportSize(viewport);
    await page.goto(cleanGuideUrl, { waitUntil: "domcontentloaded" });
    await page.keyboard.press("Tab");
    const skipLink = page.getByRole("link", { name: "Skip to guide content" });
    await expect(skipLink).toBeFocused();
    await expect(skipLink).toBeInViewport();

    await page.locator('[data-fpw-guide-toc][data-section-id="boat-taking-on-water"]').click();
    await page.waitForFunction(() => document.querySelector("#boat-taking-on-water-title").getBoundingClientRect().top < 250);
    expect(await page.evaluate(() => {
      const heading = document.querySelector("#boat-taking-on-water-title").getBoundingClientRect();
      const header = document.querySelector("header.fpw-site-header").getBoundingClientRect();
      return heading.top >= header.bottom;
    })).toBe(true);
  }
});

test("TOC, source, CTA, and print activations each emit exactly one required event", async ({ page }) => {
  await page.goto(rawGuideUrl, { waitUntil: "domcontentloaded" });
  await page.evaluate(() => {
    window.__fpwGuideEvents = [];
    window.__fpwPrintCalls = 0;
    window.FPWAnalytics = {
      track: (name, fields) => window.__fpwGuideEvents.push({ name, fields })
    };
    window.print = () => { window.__fpwPrintCalls += 1; };
    window.__fpwPreventGuideNavigation = (event) => {
      if (event.target.closest("[data-fpw-action-cta], [data-fpw-guide-source]")) event.preventDefault();
    };
    document.addEventListener("click", window.__fpwPreventGuideNavigation, true);
  });

  await page.locator('[data-fpw-guide-toc][data-section-id="first-60-seconds"]').click();
  await page.locator('[data-fpw-guide-source][data-section-id="mayday-call-script"]').first().click();
  await page.locator('[data-fpw-action-cta][data-fpw-track-section="after_pace"]').click();
  await page.locator('[data-fpw-guide-print][data-placement="hero"]').click();

  expect(await page.evaluate(() => window.__fpwGuideEvents)).toEqual([
    {
      name: "guide_toc_select",
      fields: { guide_id: "boating_emergencies", section_id: "first-60-seconds" }
    },
    {
      name: "guide_source_select",
      fields: {
        guide_id: "boating_emergencies",
        source_org: "uscg",
        destination_host: "www.navcen.uscg.gov",
        section_id: "mayday-call-script"
      }
    },
    {
      name: "guide_cta_select",
      fields: {
        guide_id: "boating_emergencies",
        cta_name: "create_float_plan",
        placement: "after_pace",
        destination_path: "/fpw/app/join.cfm"
      }
    },
    {
      name: "guide_print_select",
      fields: { guide_id: "boating_emergencies", placement: "hero" }
    }
  ]);
  expect(await page.evaluate(() => window.__fpwPrintCalls)).toBe(1);
});

test("content stays available with JavaScript disabled", async ({ browser }) => {
  const context = await browser.newContext({ javaScriptEnabled: false, viewport: { width: 375, height: 812 } });
  const page = await context.newPage();
  const response = await page.goto(rawGuideUrl, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);
  await expect(page.locator("h1")).toHaveCount(1);
  await expect(page.locator("[data-fpw-guide-toc]")).toHaveCount(requiredSections.length);
  await expect(page.locator("#printable-boating-emergency-card")).toBeVisible();
  await expect(page.locator("#sources")).toBeVisible();
  await context.close();
});
