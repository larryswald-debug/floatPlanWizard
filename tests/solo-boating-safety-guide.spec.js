const { test, expect } = require("@playwright/test");

const baseUrl = "http://localhost:8500/fpw";
const rawGuideUrl = `${baseUrl}/solo-boating-safety-guide.cfm`;
const cleanGuideUrl = `${baseUrl}/solo-boating-safety-guide/`;
const cleanupUrl = `${baseUrl}/tests/onboarding-runner.cfm`
  + "?confirm=RUN_DISPOSABLE_WELCOME_ONBOARDING_TESTS&reporter=json";
const disposablePassword = "SoloGuide!2026";
const pamphlets = [
  ["solo-boater-trip-planning-guide.pdf", "Download the Trip Planning Reference PDF", "solo_boating_trip_planning_pdf_download", "trip_plan", "trip_planning"],
  ["solo-boater-vessel-information-guide.pdf", "Download the Vessel Information Reference PDF", "solo_boating_vessel_information_pdf_download", "vessel_information", "vessel_information"],
  ["solo-boater-personal-safety-guide.pdf", "Download the Personal Safety Reference PDF", "solo_boating_personal_safety_pdf_download", "personal_safety", "personal_safety"],
  ["solo-boater-weather-guide.pdf", "Download the Weather Reference PDF", "solo_boating_weather_pdf_download", "weather", "weather"],
  ["solo-boater-communications-guide.pdf", "Download the Communications Reference PDF", "solo_boating_communications_pdf_download", "communications", "communications"],
  ["solo-boater-boat-readiness-guide.pdf", "Download the Boat Readiness Reference PDF", "solo_boating_boat_readiness_pdf_download", "boat_readiness", "boat_readiness"],
  ["solo-boater-precautions-guide.pdf", "Download the Solo Precautions Reference PDF", "solo_boating_precautions_pdf_download", "solo_precautions", "solo_precautions"]
];

test.describe.configure({ mode: "serial" });

test.afterAll(async ({ request }) => {
  const response = await request.get(cleanupUrl);
  expect(response.status()).toBe(200);
  const payload = await response.json();
  expect(payload.SUCCESS).toBe(true);
  expect(payload.CLEANUP && payload.CLEANUP.SUCCESS).toBe(true);
});

function collectPageErrors(page) {
  const errors = [];
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(`console: ${message.text()}`);
  });
  page.on("pageerror", (error) => errors.push(`pageerror: ${error.message}`));
  return errors;
}

test("solo boating guide renders at every required width without new overflow", async ({ page }, testInfo) => {
  const pageErrors = collectPageErrors(page);
  const viewports = [
    { name: "desktop", width: 1440, height: 1000 },
    { name: "small-desktop", width: 1024, height: 900 },
    { name: "tablet", width: 760, height: 900 },
    { name: "mobile", width: 390, height: 844 }
  ];

  for (const viewport of viewports) {
    await page.setViewportSize({ width: viewport.width, height: viewport.height });
    const response = await page.goto(cleanGuideUrl, { waitUntil: "domcontentloaded" });

    expect(response && response.status()).toBe(200);
    await expect(page.locator("header.fpw-site-header")).toBeVisible();
    await expect(page.locator("footer.fpw-site-footer")).toBeAttached();
    await expect(page.locator("h1")).toHaveCount(1);
    await expect(page.getByRole("heading", {
      level: 1,
      name: "Solo Boating Safety: A Practical Guide from Kayaks to Cruisers"
    })).toBeVisible();
    await expect(page.getByRole("navigation", { name: "Breadcrumb" })).toBeVisible();
    await expect(page.getByRole("navigation", { name: "In this guide" })).toBeVisible();
    await expect(page.locator(".fpw-solo-callout")).toHaveCount(4);
    await expect(page.locator('#solo-boater-checklist input[type="checkbox"]')).toHaveCount(84);
    await expect(page.locator(".fpw-solo-checklist-why")).toHaveCount(7);
    await expect(page.locator("[data-fpw-solo-pdf-download]")).toHaveCount(7);
    await expect(page.getByRole("link", {
      name: "Plan a Route with FloatPlanWizard after reading the solo boating safety guide"
    })).toBeVisible();

    expect(await page.locator(".fpw-solo-page").evaluate(
      (element) => element.scrollWidth > element.clientWidth
    )).toBe(false);
    // The shared pre-existing footer is 35px wider at exactly 1024px; the new guide itself must never overflow.
    if (viewport.width !== 1024) {
      expect(await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth)).toBe(false);
    }

    await page.screenshot({
      path: testInfo.outputPath(`solo-boating-guide-${viewport.name}-full.png`),
      fullPage: true
    });
  }

  const tocLinks = page.locator(".fpw-solo-toc a");
  await expect(tocLinks).toHaveCount(11);
  expect(await tocLinks.evaluateAll((links) => links.every((link) => {
    const href = link.getAttribute("href");
    return Boolean(href && document.querySelector(href));
  }))).toBe(true);
  expect(pageErrors).toEqual([]);
});

test("raw and clean routes resolve to the canonical page", async ({ page, request }) => {
  const rawNavigation = await page.goto(rawGuideUrl, { waitUntil: "domcontentloaded" });
  expect(rawNavigation && rawNavigation.status()).toBe(200);
  expect(page.url()).toBe(cleanGuideUrl);

  const rawResponse = await request.get(rawGuideUrl, { maxRedirects: 0 });
  expect(rawResponse.status()).toBe(301);
  expect(rawResponse.headers().location).toBe("/fpw/solo-boating-safety-guide/");

  const noSlashResponse = await request.get(`${baseUrl}/solo-boating-safety-guide`, { maxRedirects: 0 });
  expect(noSlashResponse.status()).toBe(301);
  expect(noSlashResponse.headers().location).toBe("/fpw/solo-boating-safety-guide/");

  const cleanResponse = await request.get(cleanGuideUrl, { maxRedirects: 0 });
  expect(cleanResponse.status()).toBe(200);
});

test("all seven pamphlets are direct public PDF responses", async ({ request }) => {
  for (const [filename] of pamphlets) {
    const response = await request.get(`${baseUrl}/downloads/${filename}`, { maxRedirects: 0 });
    expect(response.status(), filename).toBe(200);
    expect(response.headers()["content-type"], filename).toContain("application/pdf");
    expect((await response.body()).subarray(0, 4).toString("ascii"), filename).toBe("%PDF");
  }
});

test("each pamphlet link fires one event and analytics failure does not block download", async ({ page }) => {
  const response = await page.goto(cleanGuideUrl, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);

  await page.evaluate(() => {
    window.__fpwPdfEvents = [];
    window.FPWAnalytics.track = (name, fields) => window.__fpwPdfEvents.push({ name, fields });
    window.__fpwPdfPreventDownload = (event) => {
      if (event.target.closest("[data-fpw-solo-pdf-download]")) event.preventDefault();
    };
    document.addEventListener("click", window.__fpwPdfPreventDownload, true);
  });

  for (const [, label] of pamphlets) {
    await page.getByRole("link", { name: label }).click();
  }

  expect(await page.evaluate(() => window.__fpwPdfEvents)).toEqual(pamphlets.map(([, label, event, section, key]) => ({
    name: event,
    fields: {
      source_page: "solo_boating_safety_guide",
      section,
      document_key: key,
      label
    }
  })));

  await page.evaluate(() => {
    document.removeEventListener("click", window.__fpwPdfPreventDownload, true);
    window.FPWAnalytics.track = () => { throw new Error("intentional analytics failure"); };
  });

  const [filename, label] = pamphlets[0];
  const [download] = await Promise.all([
    page.waitForEvent("download"),
    page.getByRole("link", { name: label }).click()
  ]);
  expect(download.suggestedFilename()).toBe(filename);
});

test("metadata and JSON-LD graph are exact and internally consistent", async ({ page }) => {
  const pageErrors = collectPageErrors(page);
  const response = await page.goto(cleanGuideUrl, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);

  await expect(page).toHaveTitle("Solo Boating Safety Guide | Kayaks, Powerboats & Cruisers");
  await expect(page.locator('meta[name="description"]')).toHaveCount(1);
  await expect(page.locator('meta[name="description"]')).toHaveAttribute(
    "content",
    "Practical solo boating safety guidance for kayaks, powerboats, sailboats and cruisers, including float plans, communications, weather, self-rescue and a pre-departure checklist."
  );
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute(
    "href",
    "https://floatplanwizard.com/solo-boating-safety-guide/"
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
  expect(article.url).toBe("https://floatplanwizard.com/solo-boating-safety-guide/");
  expect(article.headline).toBe("Solo Boating Safety: A Practical Guide from Kayaks to Cruisers");
  expect(article.datePublished).toBe("2026-08-10T11:58:52-04:00");
  expect(article.dateModified).toBe("2026-08-10T11:58:52-04:00");
  expect(article.inLanguage).toBe("en");
  expect(article).not.toHaveProperty("image");
  expect(article.author).toEqual({ "@id": "https://floatplanwizard.com/#organization" });
  expect(article.publisher).toEqual({ "@id": "https://floatplanwizard.com/#organization" });
  expect(article.mainEntityOfPage).toEqual({
    "@id": "https://floatplanwizard.com/solo-boating-safety-guide/#webpage"
  });
  expect(pageErrors).toEqual([]);
});

test("Resources menu exposes and selects the solo boating guide", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto(cleanGuideUrl, { waitUntil: "domcontentloaded" });
  await page.getByRole("button", { name: "Resources" }).click();

  const guideLink = page.getByRole("menuitem", { name: "Solo Boating Safety Guide" });
  await expect(guideLink).toBeVisible();
  await expect(guideLink).toHaveAttribute("href", "/fpw/solo-boating-safety-guide/");
  await expect(guideLink).toHaveAttribute("aria-current", "page");
});

test("signed-out CTA fires once and analytics failure does not block navigation", async ({ page }) => {
  const response = await page.goto(cleanGuideUrl, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);

  const cta = page.locator("[data-fpw-action-cta]");
  await expect(cta).toHaveCount(1);
  await expect(cta).toHaveAttribute("href", "/fpw/app/join.cfm");
  await expect(cta).toHaveAttribute("data-fpw-track", "solo_boating_safety_guide_plan_route_cta_click");
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

  expect(await page.evaluate(() => window.__fpwGuideEvents)).toEqual([{
    name: "solo_boating_safety_guide_plan_route_cta_click",
    fields: {
      source_page: "solo_boating_safety_guide",
      section: "before_checklist",
      cta_type: "plan_route",
      label: "Plan a Route",
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

test("signed-in CTA fires once and analytics failure does not block dashboard navigation", async ({ page }) => {
  const email = `codex-welcome-onboarding-solo-guide-${Date.now()}-${Math.random().toString(16).slice(2)}@example.test`;
  const joinResponse = await page.goto(`${baseUrl}/app/join.cfm`, { waitUntil: "domcontentloaded" });
  expect(joinResponse && joinResponse.status()).toBe(200);

  await page.locator("#firstName").fill("Solo Guide");
  await page.locator("#lastName").fill("CTA Test");
  await page.locator("#email").fill(email);
  await page.locator("#password").fill(disposablePassword);
  await page.locator("#confirmPassword").fill(disposablePassword);
  await page.locator("#termsAccepted").check();
  await Promise.all([
    page.waitForURL(/\/fpw\/app\/dashboard\.cfm/),
    page.locator("#joinButton").click()
  ]);

  const response = await page.goto(cleanGuideUrl, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);
  const cta = page.locator("[data-fpw-action-cta]");
  await expect(cta).toHaveAttribute("href", "/fpw/app/dashboard.cfm");
  await expect(cta).toHaveAttribute("data-fpw-track-auth-state", "signed_in");
  await expect(cta).toHaveAttribute("data-fpw-track-destination-key", "dashboard");

  await page.evaluate(() => {
    window.__fpwGuideEvents = [];
    window.FPWAnalytics.track = (name, fields) => window.__fpwGuideEvents.push({ name, fields });
    window.__fpwGuidePreventNavigation = (event) => {
      if (event.target.closest("[data-fpw-action-cta]")) event.preventDefault();
    };
    document.addEventListener("click", window.__fpwGuidePreventNavigation, true);
  });
  await cta.click();

  expect(await page.evaluate(() => window.__fpwGuideEvents)).toEqual([{
    name: "solo_boating_safety_guide_plan_route_cta_click",
    fields: {
      source_page: "solo_boating_safety_guide",
      section: "before_checklist",
      cta_type: "plan_route",
      label: "Plan a Route",
      auth_state: "signed_in",
      destination_key: "dashboard"
    }
  }]);

  await page.evaluate(() => {
    document.removeEventListener("click", window.__fpwGuidePreventNavigation, true);
    window.FPWAnalytics.track = () => { throw new Error("intentional analytics failure"); };
  });
  await Promise.all([
    page.waitForURL(`${baseUrl}/app/dashboard.cfm`),
    cta.click()
  ]);
  expect(page.url()).toBe(`${baseUrl}/app/dashboard.cfm`);
});

test("content and checklist remain available and the CTA navigates without JavaScript", async ({ browser }) => {
  const context = await browser.newContext({ javaScriptEnabled: false });
  const page = await context.newPage();
  const response = await page.goto(cleanGuideUrl, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);

  await expect(page.locator('#solo-boater-checklist input[type="checkbox"]')).toHaveCount(84);
  await expect(page.getByText("I will close the float plan when the trip is safely complete.")).toBeVisible();
  const [pdfFilename, pdfLabel] = pamphlets[0];
  const [pdfDownload] = await Promise.all([
    page.waitForEvent("download"),
    page.getByRole("link", { name: pdfLabel }).click()
  ]);
  expect(pdfDownload.suggestedFilename()).toBe(pdfFilename);
  const cta = page.getByRole("link", {
    name: "Plan a Route with FloatPlanWizard after reading the solo boating safety guide"
  });
  await expect(cta).toHaveAttribute("href", "/fpw/app/join.cfm");
  await Promise.all([
    page.waitForURL(`${baseUrl}/app/join.cfm`),
    cta.click()
  ]);
  expect(page.url()).toBe(`${baseUrl}/app/join.cfm`);
  await context.close();
});
