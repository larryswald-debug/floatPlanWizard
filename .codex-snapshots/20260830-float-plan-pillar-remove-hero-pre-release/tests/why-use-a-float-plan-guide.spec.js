const { test, expect } = require("@playwright/test");

const baseUrl = "http://localhost:8500/fpw";
const rawGuideUrl = `${baseUrl}/why-use-a-float-plan.cfm`;
const cleanGuideUrl = `${baseUrl}/why-use-a-float-plan/`;
const canonical = "https://floatplanwizard.com/why-use-a-float-plan/";
const title = "Float Plan Guide: Why It Matters & What to Include | FPW";
const description = "Learn what a float plan is, why boaters should use one, what to include, who should hold it, when to update it, and what to do if a boater is overdue.";
const requiredSections = [
  "what-is-a-float-plan",
  "why-use-a-float-plan",
  "who-should-use-a-float-plan",
  "what-to-include",
  "who-should-hold-float-plan",
  "timing-and-overdue",
  "when-plans-change",
  "shore-contact-overdue",
  "short-day-trip",
  "paper-vs-digital",
  "common-float-plan-mistakes",
  "float-plan-vs-safety-tools",
  "day-trip-example",
  "float-plan-checklist",
  "float-plan-faq",
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

function parseCssColor(value) {
  const hex = value.match(/#([0-9a-f]{6})/i);
  if (hex) {
    return hex[1].match(/.{2}/g).map((channel) => parseInt(channel, 16));
  }
  const rgb = value.match(/rgba?\(\s*([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)/i);
  if (rgb) return rgb.slice(1, 4).map(Number);
  throw new Error(`Unsupported CSS color: ${value}`);
}

function relativeLuminance(rgb) {
  const linear = rgb.map((channel) => {
    const normalized = channel / 255;
    return normalized <= 0.04045
      ? normalized / 12.92
      : ((normalized + 0.055) / 1.055) ** 2.4;
  });
  return (0.2126 * linear[0]) + (0.7152 * linear[1]) + (0.0722 * linear[2]);
}

function contrastRatio(firstColor, secondColor) {
  const first = relativeLuminance(parseCssColor(firstColor));
  const second = relativeLuminance(parseCssColor(secondColor));
  return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05);
}

test("clean route serves complete server-rendered pillar metadata and schema", async ({ page, request }) => {
  const pageErrors = collectPageErrors(page);
  const response = await page.goto(cleanGuideUrl, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);
  await expect(page).toHaveTitle(title);
  await expect(page.locator('meta[name="description"]')).toHaveAttribute("content", description);
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute("href", canonical);
  await expect(page.locator('meta[property="og:url"]')).toHaveAttribute("content", canonical);
  await expect(page.locator("h1")).toHaveCount(1);
  await expect(page.getByRole("heading", {
    level: 1,
    name: "Float Plan Guide: What It Is, Why It Matters, and How to Use One"
  })).toBeVisible();
  await expect(page.getByRole("navigation", { name: "Breadcrumb" })).toBeVisible();
  await expect(page.getByRole("navigation", { name: "On this page" })).toBeVisible();
  const productCtas = page.locator("[data-fpw-float-guide-cta]");
  await expect(productCtas).toHaveCount(4);
  expect(await productCtas.evaluateAll((links) => links.map((link) => {
    const explicitLabel = link.querySelector("strong");
    return (explicitLabel || link).textContent.trim();
  }))).toEqual(Array(4).fill("Create Your Free FPW Account"));

  const schemaScripts = page.locator('script[type="application/ld+json"]');
  await expect(schemaScripts).toHaveCount(1);
  const graph = JSON.parse(await schemaScripts.textContent())["@graph"];
  expect(graph.map((entity) => entity["@type"])).toEqual([
    "Organization",
    "WebSite",
    "BreadcrumbList",
    "WebPage",
    "Article"
  ]);
  expect(graph.some((entity) => entity["@type"] === "FAQPage")).toBe(false);
  expect(graph.some((entity) => entity["@type"] === "HowTo")).toBe(false);

  const webPage = graph.find((entity) => entity["@type"] === "WebPage");
  const article = graph.find((entity) => entity["@type"] === "Article");
  expect(webPage["@id"]).toBe(canonical);
  expect(webPage.url).toBe(canonical);
  expect(article.url).toBe(canonical);
  expect(article.mainEntityOfPage).toEqual({ "@id": canonical });
  expect(article.headline).toBe("Float Plan Guide: What It Is, Why It Matters, and How to Use One");
  expect(article.dateModified).toBe("2026-08-30");
  expect(article.inLanguage).toBe("en-US");

  const serverResponse = await request.get(cleanGuideUrl, { maxRedirects: 0 });
  const serverHtml = await serverResponse.text();
  expect(serverResponse.status()).toBe(200);
  for (const sectionId of requiredSections) {
    expect(serverHtml, sectionId).toContain(`id="${sectionId}"`);
  }
  expect(serverHtml).toContain("FloatPlanWizard is a planning and communication tool.");
  expect(serverHtml).toContain("It does not guarantee continuous tracking, guarantee message delivery, verify that an emergency exists, automatically dispatch rescue");
  expect(pageErrors).toEqual([]);
});

test("raw and no-slash routes redirect once while preserving query strings", async ({ page, request }) => {
  const rawResponse = await request.get(`${rawGuideUrl}?utm_source=route_test`, { maxRedirects: 0 });
  expect(rawResponse.status()).toBe(301);
  expect(rawResponse.headers().location).toBe("/fpw/why-use-a-float-plan/?utm_source=route_test");

  const noSlashResponse = await request.get(`${baseUrl}/why-use-a-float-plan?utm_source=route_test`, { maxRedirects: 0 });
  expect(noSlashResponse.status()).toBe(301);
  expect(noSlashResponse.headers().location).toBe("/fpw/why-use-a-float-plan/?utm_source=route_test");

  const cleanResponse = await request.get(`${cleanGuideUrl}?utm_source=route_test`, { maxRedirects: 0 });
  expect(cleanResponse.status()).toBe(200);

  const navigation = await page.goto(`${rawGuideUrl}?utm_source=route_test`, { waitUntil: "domcontentloaded" });
  expect(navigation && navigation.status()).toBe(200);
  expect(page.url()).toBe(`${cleanGuideUrl}?utm_source=route_test`);
});

test("How It Works FAQ links to the pillar with visible styling and schema parity", async ({ page }) => {
  const response = await page.goto(`${baseUrl}/how-it-works/`, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);

  await page.getByRole("button", { name: "What is a float plan?" }).click();
  const guideLink = page.getByRole("link", { name: "complete Float Plan Guide" });
  await expect(guideLink).toBeVisible();
  await expect(guideLink).toHaveAttribute("href", "/fpw/why-use-a-float-plan/");
  expect(await guideLink.evaluate((link) => {
    const style = getComputedStyle(link);
    return {
      color: style.color,
      textDecorationLine: style.textDecorationLine,
      textUnderlineOffset: style.textUnderlineOffset
    };
  })).toEqual({
    color: "rgb(149, 248, 255)",
    textDecorationLine: "underline",
    textUnderlineOffset: "3px"
  });

  const schemaAnswers = await page.locator('script[type="application/ld+json"]').evaluateAll((scripts) => scripts.flatMap((script) => {
    const value = JSON.parse(script.textContent);
    const graph = Array.isArray(value["@graph"]) ? value["@graph"] : [value];
    const faqPage = graph.find((entry) => entry["@type"] === "FAQPage");
    return (faqPage?.mainEntity || []).map((question) => question.acceptedAnswer?.text || "");
  }));
  expect(schemaAnswers.some((answer) => answer.includes("Learn more in our complete Float Plan Guide."))).toBe(true);
});

test("TOC targets, seven visuals, and responsive layouts remain readable from 320 through 1440 CSS pixels", async ({ page }, testInfo) => {
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
    const response = await page.goto(cleanGuideUrl, { waitUntil: "domcontentloaded" });
    expect(response && response.status(), viewport.name).toBe(200);
    await expect(page.locator("header.fpw-site-header"), viewport.name).toBeVisible();
    await expect(page.locator("footer.fpw-site-footer"), viewport.name).toBeAttached();
    await expect(page.getByRole("navigation", { name: "Breadcrumb" }), viewport.name).toBeVisible();
    await expect(page.getByRole("navigation", { name: "On this page" }), viewport.name).toBeVisible();
    await expect(page.locator(".fpw-float-guide-figure"), viewport.name).toHaveCount(6);
    await expect(page.locator('.fpw-float-guide-sample-plan[aria-label="Example day-trip float plan"]'), viewport.name).toHaveCount(1);
    await expect(page.locator(".fpw-float-guide-figure figcaption"), viewport.name).toHaveCount(6);

    const tocLinks = page.locator(".fpw-float-guide-toc [data-fpw-float-guide-toc]");
    await expect(tocLinks, viewport.name).toHaveCount(requiredSections.length);
    expect(await tocLinks.evaluateAll((links) => links.map((link) => link.getAttribute("href"))), viewport.name).toEqual(
      requiredSections.map((sectionId) => `#${sectionId}`)
    );
    expect(await tocLinks.evaluateAll((links) => links.every((link) => Boolean(document.querySelector(link.getAttribute("href"))))), viewport.name).toBe(true);

    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), viewport.name).toBe(true);
    expect(await page.locator(".fpw-float-guide-page").evaluate((element) => element.scrollWidth <= element.clientWidth), viewport.name).toBe(true);
    expect(await page.locator(".fpw-float-guide-figure").evaluateAll((figures) => figures.every((figure) => figure.scrollWidth <= figure.clientWidth)), viewport.name).toBe(true);
    expect(await page.locator(".fpw-float-guide-table-wrap").evaluateAll((tables) => tables.every((table) => table.scrollWidth <= table.clientWidth)), viewport.name).toBe(true);

    const controls = await page.locator(".fpw-float-guide-button, .fpw-float-guide-print-button").evaluateAll((elements) => elements.map((element) => {
      const bounds = element.getBoundingClientRect();
      return { width: bounds.width, height: bounds.height };
    }));
    for (const [index, control] of controls.entries()) {
      expect(control.width, `${viewport.name} control ${index + 1} width`).toBeGreaterThanOrEqual(44);
      expect(control.height, `${viewport.name} control ${index + 1} height`).toBeGreaterThanOrEqual(44);
    }

    const heroImage = page.locator(".fpw-float-guide-hero__media img");
    await heroImage.scrollIntoViewIfNeeded();
    await expect(heroImage, viewport.name).toHaveJSProperty("complete", true);
    expect(await heroImage.evaluate((image) => image.naturalWidth), viewport.name).toBeGreaterThan(0);

    await page.screenshot({
      path: testInfo.outputPath(`why-use-a-float-plan-${viewport.name}-full.png`),
      fullPage: true
    });
  }
  expect(pageErrors).toEqual([]);
});

test("skip link and anchored headings remain keyboard-visible below the sticky header", async ({ page }) => {
  for (const viewport of [{ width: 1440, height: 1000 }, { width: 320, height: 700 }]) {
    await page.setViewportSize(viewport);
    await page.goto(cleanGuideUrl, { waitUntil: "domcontentloaded" });
    await page.keyboard.press("Tab");
    const skipLink = page.getByRole("link", { name: "Skip to guide content" });
    await expect(skipLink).toBeFocused();
    await expect(skipLink).toBeInViewport();

    await page.locator('.fpw-float-guide-toc a[href="#timing-and-overdue"]').click();
    await page.waitForFunction(() => document.querySelector("#timing-and-overdue-title").getBoundingClientRect().top < 260);
    expect(await page.evaluate(() => {
      const heading = document.querySelector("#timing-and-overdue-title").getBoundingClientRect();
      const header = document.querySelector("header.fpw-site-header").getBoundingClientRect();
      return heading.top >= header.bottom;
    })).toBe(true);
  }
});

test("two-layer guide focus remains keyboard-visible across dark and light controls", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto(cleanGuideUrl, { waitUntil: "domcontentloaded" });
  await page.keyboard.press("Tab");

  const focusTokens = await page.evaluate(() => {
    const root = getComputedStyle(document.documentElement);
    return {
      focus: root.getPropertyValue("--fpw-float-guide-focus").trim(),
      contrast: root.getPropertyValue("--fpw-float-guide-focus-contrast").trim()
    };
  });
  expect(contrastRatio(focusTokens.focus, focusTokens.contrast)).toBeGreaterThanOrEqual(9);

  const representatives = [
    { name: "skip link", locator: page.getByRole("link", { name: "Skip to guide content" }) },
    { name: "hero CTA", locator: page.locator('.fpw-float-guide-hero [data-fpw-float-guide-cta]') },
    { name: "TOC link", locator: page.locator('.fpw-float-guide-toc a[href="#what-is-a-float-plan"]') },
    { name: "body link", locator: page.locator('[data-fpw-float-guide-related][data-placement="timing"]') },
    { name: "official source", locator: page.locator('#sources [data-fpw-float-guide-source]').first() },
    { name: "related card", locator: page.locator('.fpw-float-guide-related__grid [data-guide-key="shore_contact"]'), hover: true },
    { name: "final CTA", locator: page.locator('.fpw-float-guide-final-cta [data-fpw-float-guide-cta]') },
    { name: "print button", locator: page.locator('[data-fpw-float-guide-print]') },
    { name: "checklist checkbox", locator: page.locator('#float-plan-checklist input[type="checkbox"]').first() }
  ];

  for (const representative of representatives) {
    await representative.locator.scrollIntoViewIfNeeded();
    if (representative.hover) await representative.locator.hover();
    await page.keyboard.press("Tab");
    await representative.locator.focus();
    await expect(representative.locator, representative.name).toBeFocused();

    const treatment = await representative.locator.evaluate((element) => {
      const style = getComputedStyle(element);
      return {
        focusVisible: element.matches(":focus-visible"),
        outlineStyle: style.outlineStyle,
        outlineWidth: parseFloat(style.outlineWidth),
        outlineOffset: parseFloat(style.outlineOffset),
        outlineColor: style.outlineColor,
        boxShadow: style.boxShadow
      };
    });
    expect(treatment.focusVisible, representative.name).toBe(true);
    expect(treatment.outlineStyle, representative.name).toBe("solid");
    expect(treatment.outlineWidth, representative.name).toBeGreaterThanOrEqual(2);
    expect(treatment.outlineOffset, representative.name).toBeGreaterThanOrEqual(0);
    expect(parseCssColor(treatment.outlineColor), representative.name).toEqual(parseCssColor(focusTokens.focus));
    expect(parseCssColor(treatment.boxShadow), representative.name).toEqual(parseCssColor(focusTokens.contrast));
    const shadowLengths = treatment.boxShadow.match(/-?[\d.]+px/g) || [];
    expect(shadowLengths.length, representative.name).toBeGreaterThanOrEqual(4);
    const shadowSpread = parseFloat(shadowLengths[3]);
    expect(shadowSpread, representative.name).toBeGreaterThanOrEqual(2);
    expect(shadowSpread, representative.name).toBeGreaterThanOrEqual(treatment.outlineOffset);
  }
});

test("print mode preserves the article, visuals, checklist, sources, and review date while hiding site controls", async ({ page }, testInfo) => {
  await page.goto(cleanGuideUrl, { waitUntil: "domcontentloaded" });
  await page.emulateMedia({ media: "print" });

  await expect(page.getByRole("heading", {
    level: 1,
    name: "Float Plan Guide: What It Is, Why It Matters, and How to Use One"
  })).toBeVisible();
  await expect(page.locator("#float-plan-checklist")).toBeVisible();
  await expect(page.locator("#sources")).toBeVisible();
  await expect(page.getByText("Reviewed: August 30, 2026", { exact: true })).toBeVisible();
  for (const figure of await page.locator(".fpw-float-guide-figure").all()) {
    await expect(figure).toBeVisible();
  }
  await expect(page.locator(".fpw-float-guide-sample-plan")).toBeVisible();

  await expect(page.locator("header.fpw-site-header")).toBeHidden();
  await expect(page.locator("footer.fpw-site-footer")).toBeHidden();
  await expect(page.locator(".fpw-float-guide-breadcrumbs")).toBeHidden();
  await expect(page.locator(".fpw-float-guide-toc")).toBeHidden();
  await expect(page.locator(".fpw-float-guide-actions").first()).toBeHidden();
  await expect(page.locator(".fpw-float-guide-hero__media")).toBeHidden();
  await expect(page.locator(".fpw-float-guide-print-button")).toBeHidden();
  expect(await page.locator(".fpw-float-guide-hero").evaluate((element) => getComputedStyle(element).overflow)).toBe("visible");
  await expect(page.locator("[data-fpw-float-guide-cta]")).toHaveCount(4);
  for (const productCta of await page.locator("[data-fpw-float-guide-cta]").all()) {
    await expect(productCta).toBeHidden();
  }
  await expect(page.locator(".fpw-float-guide-final-cta")).toBeHidden();
  await expect(page.locator('.fpw-float-guide-related__grid > a:not([data-fpw-float-guide-cta])')).toHaveCount(5);
  for (const relatedGuide of await page.locator('.fpw-float-guide-related__grid > a:not([data-fpw-float-guide-cta])').all()) {
    await expect(relatedGuide).toBeVisible();
  }
  expect(await page.locator(".fpw-float-guide-related__grid").evaluate((element) => getComputedStyle(element).display)).toBe("block");
  expect(await page.locator(".fpw-float-guide-related__grid > a").evaluateAll((cards) => cards.every((card) => (
    getComputedStyle(card).breakInside.startsWith("avoid")
  )))).toBe(true);
  expect(await page.locator(".fpw-float-guide-content blockquote").evaluateAll((callouts) => callouts.every((callout) => (
    getComputedStyle(callout).breakInside.startsWith("avoid")
  )))).toBe(true);
  expect(await page.locator([
    ".fpw-float-guide-hero h1",
    ".fpw-float-guide-section-kicker",
    ".fpw-float-guide-content h2",
    ".fpw-float-guide-content h3",
    ".fpw-float-guide-heading-actions"
  ].join(", ")).evaluateAll((headings) => headings.every((heading) => (
    getComputedStyle(heading).breakAfter.startsWith("avoid")
  )))).toBe(true);
  expect(await page.locator("body").evaluate((element) => getComputedStyle(element).backgroundColor)).toBe("rgb(255, 255, 255)");

  await page.screenshot({
    path: testInfo.outputPath("why-use-a-float-plan-print-full.png"),
    fullPage: true
  });

  const pdf = await page.pdf({ format: "Letter", printBackground: true, preferCSSPageSize: true });
  expect(pdf.length).toBeGreaterThan(1000);
  expect(pdf.subarray(0, 4).toString("ascii")).toBe("%PDF");
  await testInfo.attach("why-use-a-float-plan-print.pdf", {
    body: pdf,
    contentType: "application/pdf"
  });
});

test("print control selects checklist-only mode and clears it after printing", async ({ page }) => {
  await page.goto(cleanGuideUrl, { waitUntil: "domcontentloaded" });
  await page.evaluate(() => {
    window.__fpwFloatGuidePrintCalls = 0;
    window.print = () => { window.__fpwFloatGuidePrintCalls += 1; };
  });

  await page.locator("[data-fpw-float-guide-print]").click();
  expect(await page.evaluate(() => window.__fpwFloatGuidePrintCalls)).toBe(1);
  await expect(page.locator("body")).toHaveClass(/fpw-float-guide-checklist-print/);
  await page.evaluate(() => window.dispatchEvent(new Event("afterprint")));
  await expect(page.locator("body")).not.toHaveClass(/fpw-float-guide-checklist-print/);
});

test("TOC, source, related-guide, and CTA selections emit only the approved fields", async ({ page }) => {
  await page.goto(cleanGuideUrl, { waitUntil: "domcontentloaded" });
  await page.evaluate(() => {
    window.__fpwFloatGuideEvents = [];
    window.FPWAnalytics = {
      track: (name, fields) => window.__fpwFloatGuideEvents.push({ name, fields })
    };
    window.__fpwFloatGuidePreventNavigation = (event) => {
      if (event.target.closest("[data-fpw-float-guide-source], [data-fpw-float-guide-related], [data-fpw-float-guide-cta]")) {
        event.preventDefault();
      }
    };
    document.addEventListener("click", window.__fpwFloatGuidePreventNavigation, true);
  });

  await page.locator('.fpw-float-guide-toc a[href="#why-use-a-float-plan"]').click();
  await page.locator('#sources [data-fpw-float-guide-source][data-source-org="uscg"]').click();
  await page.locator('.fpw-float-guide-related__grid [data-guide-key="solo_safety"]').click();
  await page.locator('.fpw-float-guide-hero [data-fpw-float-guide-cta][data-cta-name="create_float_plan"]').click();

  expect(await page.evaluate(() => window.__fpwFloatGuideEvents)).toEqual([
    {
      name: "float_plan_guide_toc_select",
      fields: { section_id: "why-use-a-float-plan" }
    },
    {
      name: "float_plan_official_source_select",
      fields: {
        source_org: "uscg",
        section_id: "sources",
        destination_host: "uscgboating.org"
      }
    },
    {
      name: "float_plan_related_guide_select",
      fields: {
        guide_key: "solo_safety",
        placement: "related_guides",
        destination_path: "/fpw/solo-boating-safety-guide/"
      }
    },
    {
      name: "float_plan_guide_cta_select",
      fields: {
        cta_name: "create_float_plan",
        placement: "hero",
        auth_state: "signed_out",
        destination_path: "/fpw/app/join.cfm"
      }
    }
  ]);

  await page.evaluate(() => {
    document.removeEventListener("click", window.__fpwFloatGuidePreventNavigation, true);
    window.FPWAnalytics.track = () => { throw new Error("intentional analytics failure"); };
  });
  const cta = page.locator('.fpw-float-guide-hero [data-fpw-float-guide-cta][data-cta-name="create_float_plan"]');
  await Promise.all([
    page.waitForURL(`${baseUrl}/app/join.cfm`),
    cta.click()
  ]);
  expect(page.url()).toBe(`${baseUrl}/app/join.cfm`);
});

test("every main-article local link resolves and official links retain safe external attributes", async ({ page, request }) => {
  await page.goto(cleanGuideUrl, { waitUntil: "domcontentloaded" });
  const localPaths = await page.locator("main a[href]").evaluateAll((links) => [...new Set(links.map((link) => {
    const url = new URL(link.href, window.location.href);
    if (url.origin !== window.location.origin || url.hash) return null;
    return `${url.pathname}${url.search}`;
  }).filter(Boolean))].sort());
  expect(localPaths).toEqual([
    "/fpw/app/join.cfm",
    "/fpw/boat-fuel-calculator/",
    "/fpw/common-boating-emergencies/",
    "/fpw/how-it-works/",
    "/fpw/shore-contact-overdue-boater/",
    "/fpw/solo-boating-safety-guide/"
  ]);
  for (const localPath of localPaths) {
    const response = await request.get(`http://localhost:8500${localPath}`, { maxRedirects: 0 });
    expect(response.status(), localPath).toBe(200);
  }

  const officialLinks = page.locator("[data-fpw-float-guide-source]");
  expect(await officialLinks.count()).toBeGreaterThanOrEqual(9);
  for (const link of await officialLinks.all()) {
    await expect(link).toHaveAttribute("href", /^https:\/\//);
    await expect(link).toHaveAttribute("target", "_blank");
    await expect(link).toHaveAttribute("rel", "noopener noreferrer");
    await expect(link).toHaveAttribute("data-source-org", /^[a-z_]+$/);
  }
});
