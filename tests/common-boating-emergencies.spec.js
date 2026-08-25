const { test, expect } = require("@playwright/test");

const baseUrl = "http://localhost:8500/fpw";
const rawGuideUrl = `${baseUrl}/common-boating-emergencies.cfm`;
const cleanGuideUrl = `${baseUrl}/common-boating-emergencies/`;
const socialJpeg = "https://floatplanwizard.com/assets/images/boating-guides/common-boating-emergencies/common-boating-emergencies-hero.jpg";
const engineFailureAlt = "Three life-jacketed boaters respond to an engine failure as one checks the engine compartment, one makes a radio call, and one lowers the anchor from the bow.";
const groundingAlt = "Two life-jacketed boaters assess a cabin cruiser grounded in shallow water as one checks depth beside the bow and the other remains at the helm.";
const personOverboardAlt = "Two life-jacketed boaters aboard a cabin cruiser respond to a person overboard as one throws a ring buoy with a retrieval line toward the life-jacketed person in the water.";
const fireAlt = "Thirty-five-foot cabin cruiser docked at a fuel station with smoke and flames coming from the rear engine compartment and spilled fuel burning on the water near the stern.";
const fireCaption = "Fire at a fuel dock can spread rapidly from the engine compartment to spilled fuel on the water. Stop fueling, alert everyone nearby, evacuate to a safe location and call emergency services—do not remain aboard to fight a spreading fuel fire.";
const stormAlt = "Cabin cruiser moving through a marked channel toward protected water between a red marker on the left and a green marker on the right, with a dark storm and heavy rain behind the boat.";
const stormCaption = "Storms can close in quickly. When one is heading your way, seek safe harbor while you still have time to reach it safely.";
const maydayAlt = "Two life-jacketed boaters at the helm in rough water while the operator sends a Mayday call on a fixed VHF radio with a prepared emergency card beside the controls.";
const overdueAlt = "Three-panel scene showing a boater at a marina, a shore contact reviewing the boat and route while on the phone, and a rescue coordinator viewing the same vessel and route information.";
const paceNote = "Illustrative sequence; equipment and safe actions depend on the vessel and emergency.";
const individualEmergencyCards = [
  {
    id: "emergency-card-pace",
    cardId: "first-60-seconds-pace",
    title: "First 60 seconds — P.A.C.E.",
    filename: "first-60-seconds-pace.pdf"
  },
  {
    id: "emergency-card-mayday",
    cardId: "mayday-vhf-channel-16-script",
    title: "Mayday voice script — VHF Channel 16",
    filename: "mayday-vhf-channel-16-script.pdf"
  },
  {
    id: "emergency-card-pan-pan",
    cardId: "pan-pan-vhf-channel-16-script",
    title: "PAN-PAN voice script — VHF Channel 16",
    filename: "pan-pan-vhf-channel-16-script.pdf"
  },
  {
    id: "emergency-card-boat-fields",
    cardId: "boat-specific-emergency-fields",
    title: "Boat-specific fields",
    filename: "boat-specific-emergency-fields.pdf"
  }
];
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

  for (const unrelatedRoute of ["how-it-works/", "solo-boating-safety-guide/", "shore-contact-overdue-boater/"]) {
    const unrelatedResponse = await request.get(`${baseUrl}/${unrelatedRoute}`, { maxRedirects: 0 });
    expect(unrelatedResponse.status(), unrelatedRoute).toBe(200);
  }
});

test("metadata and JSON-LD are exact and internally consistent", async ({ page }) => {
  await page.goto(rawGuideUrl, { waitUntil: "domcontentloaded" });
  await expect(page.locator('meta[name="description"]')).toHaveAttribute(
    "content",
    "Learn what to do if your boat loses power, takes on water, runs aground, catches fire, encounters severe weather, or has a person overboard."
  );
  await expect(page.locator('meta[name="robots"]')).toHaveAttribute("content", "index,follow,max-image-preview:large");
  await expect(page.locator('meta[property="og:url"]')).toHaveAttribute("content", "https://floatplanwizard.com/common-boating-emergencies/");
  await expect(page.locator('meta[property="og:image"]')).toHaveAttribute("content", socialJpeg);
  await expect(page.locator('meta[property="og:image:secure_url"]')).toHaveAttribute("content", socialJpeg);
  await expect(page.locator('meta[property="og:image:type"]')).toHaveAttribute("content", "image/jpeg");
  await expect(page.locator('meta[name="twitter:image"]')).toHaveAttribute("content", socialJpeg);

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
  expect(article.image).toEqual([socialJpeg]);
});

test("required safety alt text and captions are server-rendered and associated with their figures", async ({ page }) => {
  await page.goto(rawGuideUrl, { waitUntil: "domcontentloaded" });
  const requiredFigures = [
    {
      section: "#boat-engine-failure",
      alt: engineFailureAlt,
      caption: "Assess depth, bottom, traffic, wind, current, and sea room before anchoring or troubleshooting."
    },
    {
      section: "#boat-ran-aground",
      alt: groundingAlt,
      caption: "Stop and assess before trying to power free; immediate throttle can worsen damage or clog cooling-water intakes."
    },
    {
      section: "#boat-fire-fuel-leak",
      alt: fireAlt,
      caption: fireCaption
    },
    {
      section: "#person-overboard",
      alt: personOverboardAlt,
      caption: "Maintain visual contact, deploy flotation and approach under control. Shift to neutral and shut the engine off before the person is alongside or recovery begins."
    },
    {
      section: "#boating-weather-visibility",
      alt: stormAlt,
      caption: stormCaption
    },
    {
      section: "#mayday-call-script",
      alt: maydayAlt,
      caption: "Give position, danger, assistance needed, and people aboard. Keep the full Mayday script in HTML and on the printable card."
    },
    {
      section: "#boat-carbon-monoxide",
      alt: "Recreational cabin cruiser highlighting carbon-monoxide danger zones at the stern, swim platform, canvas-enclosed cockpit and cabin, with external exhaust backdrafting forward.",
      caption: "Conceptual hazard overlay—carbon monoxide is colorless and odorless. Exhaust can collect near the stern and be drawn into cockpits or cabins by wind, speed, trim, canvas and open compartments."
    },
    {
      section: "#overdue-boat",
      alt: overdueAlt,
      caption: "Conceptual information chain—not a representation of continuous live vessel tracking."
    }
  ];

  for (const required of requiredFigures) {
    const figure = page.locator(`${required.section} figure.fpw-emergency-figure`);
    await expect(figure).toHaveCount(1);
    await expect(figure.locator("img")).toHaveAttribute("alt", required.alt);
    await expect(figure.locator("figcaption")).toHaveText(required.caption);
  }
  const paceSection = page.locator("#first-60-seconds");
  await expect(paceSection.locator("figure, picture, img")).toHaveCount(0);
  await expect(paceSection.getByText(paceNote, { exact: true })).toHaveCount(1);
});

test("fuel-dock fire subsection is semantic, sequential, and keyboard accessible", async ({ page }) => {
  await page.goto(rawGuideUrl, { waitUntil: "domcontentloaded" });
  const subsection = page.locator("#fuel-dock-fires");
  await expect(subsection).toHaveCount(1);
  await expect(subsection.locator(":scope > h3")).toHaveText("Fuel-Dock Fires and Burning Fuel on the Water");
  expect(await subsection.getByRole("heading", { level: 4 }).allTextContents()).toEqual([
    "A lesson I never forgot",
    "Before fueling",
    "If fuel spills but has not ignited",
    "If the fuel ignites"
  ]);
  await expect(subsection.locator("aside.fpw-emergency-fuel-dock-experience")).toHaveCount(1);
  await expect(subsection.locator('aside.fpw-emergency-fuel-dock-reminder[role="note"]')).toHaveCount(1);
  await expect(subsection.locator(".fpw-emergency-fuel-dock-panel")).toHaveCount(3);
  await expect(subsection.locator(".fpw-emergency-fuel-dock-panel--before > ul > li")).toHaveCount(8);
  await expect(subsection.locator(".fpw-emergency-fuel-dock-panel--spill > ol > li")).toHaveCount(6);
  await expect(subsection.locator(".fpw-emergency-fuel-dock-panel--fire > ul > li")).toHaveCount(7);
  await expect(subsection.locator("strong", { hasText: "1-800-424-8802" })).toHaveText("1-800-424-8802");

  const approvedLinks = [
    ["BoatUS Foundation fueling guidance", "https://boatus.org/study-guide/trip-planning-preparation/boat-transportation-trailering/"],
    ["BoatUS Foundation spill-response guidance", "https://www.boatus.org/clean-boating/fueling/fuel-spill-response"],
    ["U.S. Fire Administration marina-fire guidance", "https://www.usfa.fema.gov/prevention/vehicle-fires/boats-and-marinas/"]
  ];
  const sourceLinks = subsection.locator("[data-fpw-guide-source]");
  await expect(sourceLinks).toHaveCount(approvedLinks.length);
  for (const [name, href] of approvedLinks) {
    const link = subsection.getByRole("link", { name: new RegExp(`^${name}`) });
    await expect(link).toHaveAttribute("href", href);
    await expect(link).toHaveAttribute("target", "_blank");
    await expect(link).toHaveAttribute("rel", "noopener noreferrer");
    expect(await link.evaluate((element) => getComputedStyle(element).textDecorationLine.includes("underline"))).toBe(true);
    await link.focus();
    await expect(link).toBeFocused();
  }
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
    await expect(page.locator("figure.fpw-emergency-figure"), viewport.name).toHaveCount(10);
    await expect(page.locator('figure.fpw-emergency-figure source[type="image/webp"]'), viewport.name).toHaveCount(0);
    await expect(page.locator(".fpw-emergency-hero-figure"), viewport.name).toHaveCount(0);
    await expect(page.getByText("Calm, early action preserves options: protect people, establish position, control the boat, and call before the situation worsens.", { exact: true }), viewport.name).toHaveCount(0);
    await expect(page.locator("#first-60-seconds figure, #first-60-seconds picture, #first-60-seconds img"), viewport.name).toHaveCount(0);
    await expect(page.locator("#first-60-seconds").getByText(paceNote, { exact: true }), viewport.name).toHaveCount(1);
    const quickCards = page.locator(".fpw-emergency-quick-card");
    const cardDownloads = page.locator(".cbe-card-download");
    await expect(quickCards, viewport.name).toHaveCount(individualEmergencyCards.length);
    await expect(cardDownloads, viewport.name).toHaveCount(individualEmergencyCards.length);
    expect(await quickCards.evaluateAll((cards) => cards.map((card) => card.id)), viewport.name).toEqual(
      individualEmergencyCards.map((card) => card.id)
    );
    for (const cardDetails of individualEmergencyCards) {
      const card = page.locator(`#${cardDetails.id}`);
      const download = card.locator(".cbe-card-download");
      await expect(card, viewport.name).toBeVisible();
      await expect(download, viewport.name).toBeVisible();
      await expect(download, viewport.name).toHaveAttribute("href", `${baseUrl}/downloads/${cardDetails.filename}`);
      await expect(download, viewport.name).toHaveAttribute("download", cardDetails.filename);
      await expect(download, viewport.name).toHaveAttribute("type", "application/pdf");
      await expect(download, viewport.name).toHaveAttribute("data-card-id", cardDetails.cardId);
      await expect(download, viewport.name).toHaveAttribute("data-file-name", cardDetails.filename);
      await expect(download, viewport.name).toHaveAttribute("aria-label", `Download ${cardDetails.title} PDF`);
      const geometry = await card.evaluate((element) => {
        const bounds = element.getBoundingClientRect();
        const linkBounds = element.querySelector(".cbe-card-download").getBoundingClientRect();
        return {
          cardClientWidth: element.clientWidth,
          cardScrollWidth: element.scrollWidth,
          linkWidth: linkBounds.width,
          linkHeight: linkBounds.height,
          linkTop: linkBounds.top,
          linkRight: linkBounds.right,
          cardTop: bounds.top,
          cardRight: bounds.right
        };
      });
      expect(geometry.cardScrollWidth, `${viewport.name} ${cardDetails.id} clipping`).toBeLessThanOrEqual(geometry.cardClientWidth);
      expect(geometry.linkWidth, `${viewport.name} ${cardDetails.id} control width`).toBeGreaterThanOrEqual(44);
      expect(geometry.linkHeight, `${viewport.name} ${cardDetails.id} control height`).toBeGreaterThanOrEqual(44);
      expect(geometry.linkTop, `${viewport.name} ${cardDetails.id} upper control`).toBeGreaterThanOrEqual(geometry.cardTop);
      expect(geometry.linkRight, `${viewport.name} ${cardDetails.id} right control`).toBeLessThanOrEqual(geometry.cardRight);
    }
    const cardColumns = await page.locator(".fpw-emergency-card").evaluate((element) => getComputedStyle(element).gridTemplateColumns.split(" ").length);
    expect(cardColumns, `${viewport.name} quick-card columns`).toBe(viewport.width > 800 ? 2 : 1);
    const panPanSpacing = await page.locator("#choose-emergency-call").evaluate((section) => {
      const script = section.querySelector(".fpw-emergency-script--pan-pan");
      const note = section.querySelector(".fpw-emergency-pan-pan-note");
      const nextHeading = note?.nextElementSibling;
      const scriptBounds = script?.getBoundingClientRect();
      const noteBounds = note?.getBoundingClientRect();
      const headingBounds = nextHeading?.getBoundingClientRect();
      return {
        scriptToNote: scriptBounds && noteBounds ? noteBounds.top - scriptBounds.bottom : 0,
        noteToHeading: noteBounds && headingBounds ? headingBounds.top - noteBounds.bottom : 0
      };
    });
    expect(panPanSpacing.scriptToNote, `${viewport.name} spacing below Pan-Pan example`).toBeGreaterThanOrEqual(24);
    expect(panPanSpacing.noteToHeading, `${viewport.name} spacing below Pan-Pan note`).toBeGreaterThanOrEqual(44);
    for (const image of await page.locator("figure.fpw-emergency-figure img").all()) {
      await image.scrollIntoViewIfNeeded();
      await expect(image, viewport.name).toHaveJSProperty("complete", true);
      expect(await image.evaluate((element) => element.naturalWidth), viewport.name).toBeGreaterThan(0);
      expect(await image.evaluate((element) => element.currentSrc), viewport.name).toMatch(/\.jpg(?:\?|$)/);
    }
    const fireImage = page.locator("#boat-fire-fuel-leak figure.fpw-emergency-figure img");
    await expect(fireImage, viewport.name).toHaveAttribute("alt", fireAlt);
    expect(await fireImage.evaluate((image) => image.currentSrc), viewport.name).toContain("boat-engine-compartment-fire-response");
    expect(await fireImage.evaluate((image) => image.currentSrc), viewport.name).toContain("v=20260823-owner-approved-v2");
    const stormImage = page.locator("#boating-weather-visibility figure.fpw-emergency-figure img");
    await expect(stormImage, viewport.name).toHaveAttribute("alt", stormAlt);
    expect(await stormImage.evaluate((image) => image.currentSrc), viewport.name).toContain("boating-storm-early-shelter-decision");
    expect(await stormImage.evaluate((image) => image.currentSrc), viewport.name).toContain("v=20260823-owner-approved-v2");
    const maydayImage = page.locator("#mayday-call-script figure.fpw-emergency-figure img");
    await expect(maydayImage, viewport.name).toHaveAttribute("alt", maydayAlt);
    expect(await maydayImage.evaluate((image) => image.currentSrc), viewport.name).toContain("marine-vhf-mayday-prepared-card");
    const engineFailureImage = page.locator("#boat-engine-failure figure.fpw-emergency-figure img");
    await expect(engineFailureImage, viewport.name).toHaveAttribute("alt", engineFailureAlt);
    expect(await engineFailureImage.evaluate((image) => image.currentSrc), viewport.name).toContain("boat-engine-failure-drift-anchor");
    const groundingImage = page.locator("#boat-ran-aground figure.fpw-emergency-figure img");
    await expect(groundingImage, viewport.name).toHaveAttribute("alt", groundingAlt);
    expect(await groundingImage.evaluate((image) => image.currentSrc), viewport.name).toContain("boat-grounding-stop-assess");
    const personOverboardImage = page.locator("#person-overboard figure.fpw-emergency-figure img");
    await expect(personOverboardImage, viewport.name).toHaveAttribute("alt", personOverboardAlt);
    expect(await personOverboardImage.evaluate((image) => image.currentSrc), viewport.name).toContain("person-overboard-controlled-recovery");
    expect(await personOverboardImage.evaluate((image) => image.currentSrc), viewport.name).toContain("v=20260823-owner-approved");
    const overdueImage = page.locator("#overdue-boat figure.fpw-emergency-figure img");
    await expect(overdueImage, viewport.name).toHaveAttribute("alt", overdueAlt);
    expect(await overdueImage.evaluate((image) => image.currentSrc), viewport.name).toContain("overdue-boater-response-information-chain");
    expect(await overdueImage.evaluate((image) => image.currentSrc), viewport.name).toContain("v=20260823-owner-approved");
    const fuelDockSubsection = page.locator("#fuel-dock-fires");
    await expect(fuelDockSubsection, viewport.name).toBeVisible();
    expect(await fuelDockSubsection.evaluate((element) => element.scrollWidth > element.clientWidth), viewport.name).toBe(false);
    const fuelDockPanels = await fuelDockSubsection.locator(".fpw-emergency-fuel-dock-panel").evaluateAll((elements) => elements.map((element) => {
      const bounds = element.getBoundingClientRect();
      return {
        top: bounds.top,
        bottom: bounds.bottom,
        left: bounds.left,
        right: bounds.right,
        clientWidth: element.clientWidth,
        scrollWidth: element.scrollWidth,
        clientHeight: element.clientHeight,
        scrollHeight: element.scrollHeight
      };
    }));
    expect(fuelDockPanels).toHaveLength(3);
    for (const [index, panel] of fuelDockPanels.entries()) {
      expect(panel.scrollWidth, `${viewport.name} panel ${index + 1} horizontal clipping`).toBeLessThanOrEqual(panel.clientWidth);
      expect(panel.scrollHeight, `${viewport.name} panel ${index + 1} vertical clipping`).toBeLessThanOrEqual(panel.clientHeight);
      if (index > 0) {
        expect(panel.top, `${viewport.name} panels must stay stacked`).toBeGreaterThanOrEqual(fuelDockPanels[index - 1].bottom);
        expect(Math.abs(panel.left - fuelDockPanels[index - 1].left), `${viewport.name} panel alignment`).toBeLessThan(1);
      }
    }
    expect(await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth), viewport.name).toBe(false);
    expect(await page.locator(".fpw-emergency-page").evaluate((element) => element.scrollWidth > element.clientWidth), viewport.name).toBe(false);

    if (viewport.width === 375) {
      for (const sectionId of [
        "person-overboard",
        "boat-taking-on-water",
        "boat-fire-fuel-leak",
        "boating-weather-visibility",
        "mayday-call-script",
        "boat-carbon-monoxide",
        "boat-ran-aground"
      ]) {
        const figure = page.locator(`#${sectionId} figure.fpw-emergency-figure`);
        await figure.scrollIntoViewIfNeeded();
        await expect(figure).toBeVisible();
        expect(await figure.locator("img").evaluate((image) => {
          const renderedRatio = image.getBoundingClientRect().width / image.getBoundingClientRect().height;
          const intrinsicRatio = image.naturalWidth / image.naturalHeight;
          return Math.abs(renderedRatio - intrinsicRatio);
        })).toBeLessThan(0.02);
        await figure.screenshot({
          path: testInfo.outputPath(`common-boating-emergencies-${sectionId}-375.png`)
        });
      }
      await fuelDockSubsection.screenshot({
        path: testInfo.outputPath("common-boating-emergencies-fuel-dock-fires-375.png")
      });
    }
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
  const fuelDockSubsection = page.locator("#fuel-dock-fires");
  await expect(fuelDockSubsection).toBeVisible();
  await expect(fuelDockSubsection.locator("aside.fpw-emergency-fuel-dock-experience")).toBeVisible();
  await expect(fuelDockSubsection.locator(".fpw-emergency-fuel-dock-panel")).toHaveCount(3);
  await expect(fuelDockSubsection.locator('aside.fpw-emergency-fuel-dock-reminder[role="note"]')).toBeVisible();
  await expect(fuelDockSubsection.locator("[data-fpw-guide-source]")).toHaveCount(3);
  await expect(page.locator("header.fpw-site-header")).toBeHidden();
  await expect(page.locator("footer.fpw-site-footer")).toBeHidden();
  await expect(page.locator(".fpw-emergency-toc")).toBeHidden();
  await expect(page.locator("[data-fpw-action-cta]").first()).toBeHidden();
  await expect(page.locator("[data-fpw-guide-print]").first()).toBeHidden();
  await expect(page.locator(".fpw-emergency-quick-card")).toHaveCount(individualEmergencyCards.length);
  await expect(page.locator("#emergency-card-pan-pan").getByText("PAN-PAN, PAN-PAN, PAN-PAN", { exact: true })).toBeVisible();
  await expect(page.locator(".cbe-card-download").first()).toBeHidden();
  await expect(page.locator(".fpw-emergency-card-downloads").first()).toBeHidden();
  expect(await page.locator(".fpw-emergency-hero").evaluate((element) => getComputedStyle(element).backgroundColor)).toBe("rgb(255, 255, 255)");
  expect(await page.locator(".fpw-emergency-evidence").evaluate((element) => getComputedStyle(element).backgroundColor)).toBe("rgb(255, 255, 255)");
  expect(await page.locator(".fpw-emergency-supplement").evaluate((element) => getComputedStyle(element).color)).toBe("rgb(0, 0, 0)");
  for (const element of await fuelDockSubsection.locator("aside, .fpw-emergency-fuel-dock-panel").all()) {
    expect(await element.evaluate((node) => getComputedStyle(node).backgroundColor)).toBe("rgb(255, 255, 255)");
    expect(await element.evaluate((node) => getComputedStyle(node).borderColor)).toBe("rgb(119, 119, 119)");
  }
  await expect(page.locator("#first-60-seconds").getByText(paceNote, { exact: true })).toBeVisible();
  for (const sectionId of ["mayday-call-script", "boat-fire-fuel-leak", "boat-ran-aground", "person-overboard", "boating-weather-visibility", "boat-carbon-monoxide", "overdue-boat"]) {
    await expect(page.locator(`#${sectionId} figcaption`), sectionId).toBeVisible();
  }
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

test("TOC, source, CTA, print, and card activations each emit exactly one required event", async ({ page }) => {
  await page.goto(rawGuideUrl, { waitUntil: "domcontentloaded" });
  await page.evaluate(() => {
    window.__fpwGuideEvents = [];
    window.__fpwPrintCalls = 0;
    window.FPWAnalytics = {
      track: (name, fields) => window.__fpwGuideEvents.push({ name, fields })
    };
    window.print = () => { window.__fpwPrintCalls += 1; };
    window.__fpwPreventGuideNavigation = (event) => {
      if (event.target.closest("[data-fpw-action-cta], [data-fpw-guide-source], [data-fpw-guide-card]")) event.preventDefault();
    };
    document.addEventListener("click", window.__fpwPreventGuideNavigation, true);
  });

  await page.locator('[data-fpw-guide-toc][data-section-id="first-60-seconds"]').click();
  await page.locator('[data-fpw-guide-source][data-section-id="mayday-call-script"]').first().click();
  await page.locator('[data-fpw-action-cta][data-fpw-track-section="after_pace"]').click();
  await page.locator('[data-fpw-guide-print][data-placement="hero"]').click();
  await page.locator('[data-fpw-guide-card][data-file-name="first-60-seconds-pace.pdf"]').click();

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
    },
    {
      name: "guide_card_download",
      fields: {
        guide_id: "boating_emergencies",
        card_id: "first-60-seconds-pace",
        file_name: "first-60-seconds-pace.pdf",
        placement: "quick_reference_card"
      }
    }
  ]);
  expect(await page.evaluate(() => window.__fpwPrintCalls)).toBe(1);
});

test("individual card controls and stretched card surfaces download the correct PDFs", async ({ page }) => {
  await page.goto(rawGuideUrl, { waitUntil: "domcontentloaded" });

  for (const cardDetails of individualEmergencyCards) {
    const link = page.locator(`#${cardDetails.id} .cbe-card-download`);
    await link.focus();
    await expect(link).toBeFocused();
    const [download] = await Promise.all([
      page.waitForEvent("download"),
      page.keyboard.press("Enter")
    ]);
    expect(download.suggestedFilename()).toBe(cardDetails.filename);
  }

  const paceCard = page.locator("#emergency-card-pace");
  const paceBounds = await paceCard.boundingBox();
  expect(paceBounds).not.toBeNull();
  const bodyPoint = {
    x: paceBounds.x + paceBounds.width / 2,
    y: paceBounds.y + paceBounds.height - 18
  };
  expect(await page.evaluate(({ x, y }) => document.elementFromPoint(x, y)?.closest("a")?.getAttribute("download"), bodyPoint)).toBe("first-60-seconds-pace.pdf");
  const [cardSurfaceDownload] = await Promise.all([
    page.waitForEvent("download"),
    page.mouse.click(bodyPoint.x, bodyPoint.y)
  ]);
  expect(cardSurfaceDownload.suggestedFilename()).toBe("first-60-seconds-pace.pdf");
});

test("content stays available with JavaScript disabled", async ({ browser }) => {
  const context = await browser.newContext({ javaScriptEnabled: false, viewport: { width: 375, height: 812 } });
  const page = await context.newPage();
  const response = await page.goto(rawGuideUrl, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);
  await expect(page.locator("h1")).toHaveCount(1);
  await expect(page.locator("[data-fpw-guide-toc]")).toHaveCount(requiredSections.length);
  await expect(page.locator("#printable-boating-emergency-card")).toBeVisible();
  await expect(page.locator("[data-fpw-guide-card]")).toHaveCount(6);
  await expect(page.locator(".fpw-emergency-quick-card")).toHaveCount(individualEmergencyCards.length);
  await expect(page.locator(".cbe-card-download")).toHaveCount(individualEmergencyCards.length);
  await expect(page.locator("#emergency-card-pan-pan").getByText("PAN-PAN, PAN-PAN, PAN-PAN", { exact: true })).toBeVisible();
  await expect(page.locator("#sources")).toBeVisible();
  const paceSection = page.locator("#first-60-seconds");
  await expect(paceSection.locator("figure, picture, img")).toHaveCount(0);
  await expect(paceSection.getByText(paceNote, { exact: true })).toBeVisible();
  const fuelDockSubsection = page.locator("#fuel-dock-fires");
  await expect(fuelDockSubsection).toBeVisible();
  await expect(fuelDockSubsection.getByRole("heading", { level: 3, name: "Fuel-Dock Fires and Burning Fuel on the Water" })).toBeVisible();
  await expect(fuelDockSubsection.locator(".fpw-emergency-fuel-dock-panel")).toHaveCount(3);
  await expect(fuelDockSubsection.locator("[data-fpw-guide-source]")).toHaveCount(3);
  const fireFigure = page.locator("#boat-fire-fuel-leak figure.fpw-emergency-figure");
  await expect(fireFigure).toHaveCount(1);
  await expect(fireFigure.locator("img")).toHaveAttribute("alt", fireAlt);
  await expect(fireFigure.locator("figcaption")).toHaveText(fireCaption);
  const stormFigure = page.locator("#boating-weather-visibility figure.fpw-emergency-figure");
  await expect(stormFigure).toHaveCount(1);
  await expect(stormFigure.locator("img")).toHaveAttribute("alt", stormAlt);
  await expect(stormFigure.locator("figcaption")).toHaveText(stormCaption);
  const maydayFigure = page.locator("#mayday-call-script figure.fpw-emergency-figure");
  await expect(maydayFigure).toHaveCount(1);
  await expect(maydayFigure.locator("img")).toHaveAttribute("alt", maydayAlt);
  await expect(maydayFigure.locator("figcaption")).toHaveText("Give position, danger, assistance needed, and people aboard. Keep the full Mayday script in HTML and on the printable card.");
  const engineFailureFigure = page.locator("#boat-engine-failure figure.fpw-emergency-figure");
  await expect(engineFailureFigure).toHaveCount(1);
  await expect(engineFailureFigure.locator("img")).toHaveAttribute("alt", engineFailureAlt);
  await expect(engineFailureFigure.locator("figcaption")).toHaveText("Assess depth, bottom, traffic, wind, current, and sea room before anchoring or troubleshooting.");
  const groundingFigure = page.locator("#boat-ran-aground figure.fpw-emergency-figure");
  await expect(groundingFigure).toHaveCount(1);
  await expect(groundingFigure.locator("img")).toHaveAttribute("alt", groundingAlt);
  await expect(groundingFigure.locator("figcaption")).toHaveText("Stop and assess before trying to power free; immediate throttle can worsen damage or clog cooling-water intakes.");
  const personOverboardFigure = page.locator("#person-overboard figure.fpw-emergency-figure");
  await expect(personOverboardFigure).toHaveCount(1);
  await expect(personOverboardFigure.locator("img")).toHaveAttribute("alt", personOverboardAlt);
  await expect(personOverboardFigure.locator("figcaption")).toHaveText("Maintain visual contact, deploy flotation and approach under control. Shift to neutral and shut the engine off before the person is alongside or recovery begins.");
  const overdueFigure = page.locator("#overdue-boat figure.fpw-emergency-figure");
  await expect(overdueFigure).toHaveCount(1);
  await expect(overdueFigure.locator("img")).toHaveAttribute("alt", overdueAlt);
  await expect(overdueFigure.locator("figcaption")).toHaveText("Conceptual information chain—not a representation of continuous live vessel tracking.");
  await context.close();
});

test("PDF downloads stay public while guide publishing sources and review files are denied", async ({ request }) => {
  for (const filename of [
    "floatplanwizard-boating-emergency-card-4x6.pdf",
    "floatplanwizard-boating-emergency-card-letter.pdf",
    ...individualEmergencyCards.map((card) => card.filename)
  ]) {
    const response = await request.get(`${baseUrl}/downloads/${filename}`);
    expect(response.status()).toBe(200);
    expect(response.headers()["content-type"]).toBe("application/pdf");
  }

  for (const stem of [
    "boat-engine-compartment-fire-response",
    "boat-carbon-monoxide-danger-zones",
    "marine-vhf-mayday-prepared-card"
  ]) {
    for (const suffix of ["-640w.jpg", "-640w.webp", "-960w.jpg", "-960w.webp", ".jpg", ".webp"]) {
      const response = await request.get(`${baseUrl}/assets/images/boating-guides/common-boating-emergencies/${stem}${suffix}`);
      expect(response.status(), `${stem}${suffix}`).toBe(200);
      expect(response.headers()["content-type"], `${stem}${suffix}`).toMatch(/^image\/(jpeg|webp)$/);
    }
  }

  for (const path of [
    "publishing/common-boating-emergencies/assets/source/common-boating-emergencies-hero-master.png",
    "publishing/common-boating-emergencies/scripts/build_images.py",
    "publishing/common-boating-emergencies/review/common-boating-emergencies-owner-review.zip"
  ]) {
    const response = await request.get(`${baseUrl}/${path}`, { maxRedirects: 0 });
    expect(response.status()).toBe(403);
  }
});
