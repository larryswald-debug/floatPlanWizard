import assert from "node:assert/strict";
import { existsSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));
const read = (relativePath) => readFileSync(path.join(repositoryRoot, relativePath), "utf8");
const page = read("common-boating-emergencies.cfm");
const stylesheet = read("assets/css/common-boating-emergencies.css");
const script = read("assets/js/common-boating-emergencies.js");
const webConfig = read("web.config");
const sitemap = read("sitemap.xml");

const canonical = "https://floatplanwizard.com/common-boating-emergencies/";
const heroUrl = "https://floatplanwizard.com/assets/images/boating-guides/common-boating-emergencies/common-boating-emergencies-hero.webp";
const imageDirectory = "assets/images/boating-guides/common-boating-emergencies";
const figureAssets = [
  ["common-boating-emergencies-hero", 1672, 941, "A boat operator checks the VHF radio while two passengers put on life jackets after the boat loses power.", "Calm, early action preserves options: protect people, establish position, control the boat, and call before the situation worsens."],
  ["boating-emergency-pace-first-minute", 1536, 1024, "Four scenes show a crew putting on life jackets, assessing hazards, controlling the boat, and making an emergency call.", "P.A.C.E. is FloatPlanWizard&rsquo;s quick-recall framework: People, Assess, Control, Emergency call. Actions may happen at the same time."],
  ["boat-engine-failure-drift-anchor", 1536, 1024, "A disabled boat drifts toward a hazard while the crew checks position and prepares an anchor.", "Assess depth, bottom, traffic, wind, current, and sea room before anchoring or troubleshooting."],
  ["boat-taking-on-water-checkpoints", 1536, 1024, "A cutaway view highlights several common places water can enter a recreational boat, including fittings, hoses, drains, and hull damage.", "Boat layouts differ. Check only accessible areas you understand, and never delay a distress call while water is rising."],
  ["boat-grounding-stop-assess", 1536, 1024, "A grounded boat is assessed for damage while a contrasting scene shows sediment churned by immediately reversing.", "Stop and assess before trying to power free; immediate throttle can worsen damage or clog cooling-water intakes."],
  ["person-overboard-controlled-recovery", 1536, 1024, "A crew keeps pointing to a person overboard as the operator makes a slow return toward thrown flotation and a boarding ladder.", "Shout, throw, point, slow, approach under control, and place propulsion in neutral or stop the engine before recovery."],
  ["boat-engine-compartment-fire-response", 1536, 1024, "A crew keeps the engine hatch closed, moves upwind, and uses the boat&rsquo;s external fire-system access point.", "Do not open a suspected engine-compartment fire. Shut down sources and use the installed system or fire port as designed."],
  ["boating-storm-early-shelter-decision", 1672, 941, "A recreational boat turns toward safe harbor before a distant thunderstorm reaches the route.", "The safest storm tactic is often the early decision to seek shelter before wind, waves, lightning, and visibility close the route."],
  ["marine-vhf-mayday-prepared-card", 1448, 1086, "A boat operator uses the VHF while reading position and vessel details from a prepared emergency card.", "Give position, danger, assistance needed, and people aboard. Keep the full Mayday script in HTML and on the printable card."],
  ["capsize-stay-with-boat-visibility", 1672, 941, "From the air, an overturned boat and grouped survivors are much more visible than one person alone in the water.", "Stay with the boat unless fire, fuel, surf, a dam, rocks, or another immediate hazard makes leaving safer."],
  ["boat-carbon-monoxide-danger-zones", 1536, 1024, "Exhaust gathers near a boat&rsquo;s stern and can curl toward the swim platform and enclosed cockpit.", "Carbon monoxide has no color or odor. Keep people away from exhaust zones and stop machinery if exposure is suspected."],
  ["overdue-boater-response-information-chain", 1672, 941, "A boater, shore contact, and rescue coordinator share the same boat, route, passenger, and timing information.", "A complete, current float plan reduces guesswork when a boat is overdue."]
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

function countMatches(source, pattern) {
  return [...source.matchAll(pattern)].length;
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

test("page has the approved discovery metadata and one canonical H1", () => {
  assert.equal(countMatches(page, /<title>Common Boating Emergencies: What to Do \| FloatPlanWizard<\/title>/g), 1);
  assert.equal(
    countMatches(page, /<meta name="description" content="Learn what to do if your boat loses power, takes on water, runs aground, catches fire, encounters severe weather, or has a person overboard\.">/g),
    1
  );
  assert.equal(countMatches(page, new RegExp(`<link rel="canonical" href="${escapeRegExp(canonical)}">`, "g")), 1);
  assert.equal(countMatches(page, /<h1 id="fpw-emergency-title">When Something Goes Wrong on the Water<\/h1>/g), 1);
  assert.equal(countMatches(page, /<h1\b/g), 1);
  assert.match(page, /<meta name="robots" content="index,follow,max-image-preview:large">/);
  assert.match(page, /<meta property="og:type" content="article">/);
  assert.match(page, /<meta property="og:url" content="https:\/\/floatplanwizard\.com\/common-boating-emergencies\/">/);
  assert.match(page, /<meta property="og:title" content="When Something Goes Wrong on the Water">/);
  assert.match(page, new RegExp(`<meta property="og:image" content="${escapeRegExp(heroUrl)}">`));
  assert.match(page, new RegExp(`<meta name="twitter:image" content="${escapeRegExp(heroUrl)}">`));
  assert.match(page, /<meta property="og:image:type" content="image\/webp">/);
  assert.match(page, /<meta property="og:image:width" content="1672">/);
  assert.match(page, /<meta property="og:image:height" content="941">/);
});

test("schema graph is Article-based and does not claim FAQPage or HowTo eligibility", () => {
  for (const type of ["Organization", "BreadcrumbList", "WebPage", "Article"]) {
    assert.match(page, new RegExp(`structInsert\\([^\\n]+schemaTypeKey, "${type}"`));
  }
  for (const property of [
    "url",
    "headline",
    "description",
    "datePublished",
    "dateModified",
    "articleSection",
    "inLanguage",
    "author",
    "publisher",
    "mainEntityOfPage",
    "image"
  ]) {
    assert.equal(page.includes(`["${property}"]`), true, `Missing schema property ${property}`);
  }
  assert.match(page, /fpwEmergencyPublishedDate = "2026-08-23";/);
  assert.match(page, /fpwEmergencyModifiedDate = "2026-08-23";/);
  assert.match(page, /fpwEmergencySchemaArticle\["image"\] = \[ fpwEmergencySocialImage \];/);
  assert.match(page, new RegExp(`fpwEmergencySocialImage = "${escapeRegExp(heroUrl)}";`));
  assert.doesNotMatch(page, /schemaTypeKey, "(?:FAQPage|HowTo)"/);
  assert.equal(countMatches(page, /type="application\/ld\+json"/g), 1);
});

test("all required sections are present, linked, unique, and available in initial HTML", () => {
  const staticIds = [...page.matchAll(/\sid="([a-z][a-z0-9-]*)"/gi)].map((match) => match[1]);
  assert.equal(new Set(staticIds).size, staticIds.length, "Static IDs must be unique");

  const tocTargets = [...page.matchAll(/<li><a href="#([a-z0-9-]+)" data-fpw-guide-toc/g)].map((match) => match[1]);
  assert.deepEqual(tocTargets, requiredSections);
  for (const sectionId of requiredSections) {
    assert.equal(page.includes(`id="${sectionId}"`), true, `Missing section ${sectionId}`);
    assert.equal(page.includes(`href="#${sectionId}" data-fpw-guide-toc`), true, `Missing TOC link ${sectionId}`);
  }

  for (const labelTarget of [...page.matchAll(/aria-labelledby="([a-z0-9-]+)"/g)].map((match) => match[1])) {
    assert.equal(page.includes(`id="${labelTarget}"`), true, `Missing aria-labelledby target ${labelTarget}`);
  }
  assert.doesNotMatch(page, /FPW_EMERGENCY_GUIDE_CONTENT|document\.write|innerHTML\s*=/);
});

test("approved emergency, communication, preparation, and limitation language is retained", () => {
  for (const requiredCopy of [
    "P.A.C.E.",
    "Mayday: grave and imminent danger",
    "Pan-Pan: urgent but not yet grave and imminent",
    "What to do if the boat engine dies or you lose propulsion",
    "What to do if the boat is taking on water",
    "What to do if you see smoke, smell gasoline, discover a fuel leak, or have a fire",
    "What to do when someone falls overboard",
    "What to do if the boat capsizes or sinking makes abandonment necessary",
    "What to do for a serious illness or injury aboard",
    "What to do if carbon monoxide exposure is possible",
    "Give passengers this two-minute safety briefing before leaving",
    "Printable boating emergency card",
    "After everyone is safe: reporting, documentation, and recovery",
    "does not determine when rescue action is required",
    "verify an emergency",
    "dispatch assistance",
    "continuously track every trip",
    "This U.S.-focused educational guide provides general safety information"
  ]) {
    assert.equal(page.includes(requiredCopy), true, `Missing approved content: ${requiredCopy}`);
  }
  assert.doesNotMatch(page, /final accessible 4|reserved for Phase 2|implementation|content owner|Product wording on this page/i);
});

test("links and CTA destinations are limited to verified routes and official sources", () => {
  for (const destination of [
    "/app/join.cfm",
    "/app/dashboard.cfm",
    "/shore-contact-overdue-boater/",
    "/solo-boating-safety-guide/",
    "/boat-fuel-calculator/",
    "/app/pricing.cfm"
  ]) {
    assert.equal(page.includes(destination), true, `Missing internal destination ${destination}`);
  }
  for (const sourceHost of [
    "uscgboating.org",
    "navcen.uscg.gov",
    "weather.gov",
    "cdc.gov",
    "sarsat.noaa.gov",
    "ecfr.gov",
    "redcross.org",
    "epa.gov"
  ]) {
    assert.equal(page.includes(sourceHost), true, `Missing official source ${sourceHost}`);
  }

  const externalLinks = [...page.matchAll(/<a\b[^>]*href="https:\/\/[^>]+>/g)].map((match) => match[0]);
  assert.ok(externalLinks.length >= 14);
  for (const link of externalLinks) {
    assert.match(link, /target="_blank"/);
    assert.match(link, /rel="noopener noreferrer"/);
    assert.match(link, /data-fpw-guide-source/);
  }
  assert.equal(countMatches(page, /<cfinclude template="partials\/fpw-action-cta\.cfm">/g), 2);
  assert.equal(countMatches(page, /"analyticsEvent" = "guide_cta_select"/g), 2);
  assert.doesNotMatch(page, /fpw-action-cta\.js/);
});

test("phase-two figures use every approved source, alt, caption, size, and loading policy", () => {
  assert.doesNotMatch(page, /implementation-assets|fpw-common-boating-emergencies-hero-reference|fpw-person-overboard-reference/i);
  assert.equal(countMatches(page, /<figure class="fpw-emergency-figure/g), 12);
  assert.equal(countMatches(page, /<picture>/g), 12);
  assert.equal(countMatches(page, /<figcaption>/g), 12);

  for (const [stem, width, height, alt, caption] of figureAssets) {
    const imageMatch = page.match(new RegExp(`<img\\b[^\\n]*${escapeRegExp(stem)}\\.jpg[^\\n]*>`));
    assert.ok(imageMatch, `Missing fallback image tag for ${stem}`);
    const imageTag = imageMatch[0];
    assert.match(imageTag, new RegExp(`width="${width}"`));
    assert.match(imageTag, new RegExp(`height="${height}"`));
    assert.match(imageTag, new RegExp(`alt="${escapeRegExp(alt)}"`));
    assert.match(imageTag, /decoding="async"/);
    assert.match(page, new RegExp(`${escapeRegExp(stem)}-640w\\.webp 640w`));
    assert.match(page, new RegExp(`${escapeRegExp(stem)}-960w\\.webp 960w`));
    assert.match(page, new RegExp(`${escapeRegExp(stem)}\\.webp ${width}w`));
    assert.equal(page.includes(`<figcaption>${caption}</figcaption>`), true, `Missing caption for ${stem}`);

    for (const suffix of ["-640w.webp", "-960w.webp", ".webp", "-640w.jpg", "-960w.jpg", ".jpg"]) {
      const relativePath = path.join(imageDirectory, `${stem}${suffix}`);
      assert.equal(existsSync(path.join(repositoryRoot, relativePath)), true, `Missing derivative ${relativePath}`);
      assert.ok(statSync(path.join(repositoryRoot, relativePath)).size > 0, `Empty derivative ${relativePath}`);
    }

    if (stem === "common-boating-emergencies-hero") {
      assert.doesNotMatch(imageTag, /loading="lazy"/);
      assert.match(imageTag, /fetchpriority="high"/);
    } else {
      assert.match(imageTag, /loading="lazy"/);
      assert.doesNotMatch(imageTag, /fetchpriority=/);
    }
  }
});

test("both emergency-card PDFs are direct visible downloads with stable filenames", () => {
  const files = [
    "floatplanwizard-boating-emergency-card-4x6.pdf",
    "floatplanwizard-boating-emergency-card-letter.pdf"
  ];
  assert.equal(countMatches(page, /data-fpw-guide-card/g), 2);
  for (const fileName of files) {
    assert.match(page, new RegExp(`href="<cfoutput>#fpwEmergencyBasePath#<\\/cfoutput>\\/downloads\\/${escapeRegExp(fileName)}"`));
    assert.match(page, new RegExp(`download="${escapeRegExp(fileName)}"`));
    assert.match(page, new RegExp(`data-file-name="${escapeRegExp(fileName)}" data-placement="download_section"`));
    const pdfPath = path.join(repositoryRoot, "downloads", fileName);
    assert.equal(existsSync(pdfPath), true, `Missing PDF ${fileName}`);
    assert.equal(readFileSync(pdfPath).subarray(0, 5).toString("ascii"), "%PDF-");
  }
});

test("analytics use the required low-cardinality event and parameter contracts", () => {
  for (const eventName of [
    "guide_print_select",
    "guide_toc_select",
    "guide_card_download",
    "guide_cta_select",
    "guide_source_select"
  ]) {
    assert.match(script, new RegExp(`track\\("${eventName}"`));
  }
  for (const field of [
    "guide_id",
    "file_name",
    "placement",
    "section_id",
    "cta_name",
    "destination_path",
    "source_org",
    "destination_host"
  ]) {
    assert.equal(script.includes(`${field}:`), true, `Missing analytics field ${field}`);
  }
  assert.match(script, /window\.__fpwBoatingEmergencyGuideBound/);
  assert.equal(countMatches(script, /document\.addEventListener\("click"/g), 1);
  assert.equal(countMatches(script, /track\("guide_card_download"/g), 1);
  assert.match(script, /event\.target\.closest\("\[data-fpw-guide-card\]"\)/);
  assert.doesNotMatch(script, /preventDefault\(\)/);
  assert.doesNotMatch(script, /email|phone|latitude|longitude|vessel|user_id/i);
});

test("styles provide responsive, focus, reduced-motion, table, and print foundations", () => {
  assert.match(page, /common-boating-emergencies\.css\?v=20260822-phase2/);
  assert.match(page, /common-boating-emergencies\.js\?v=20260822-phase2/);
  assert.match(stylesheet, /body\.fpw-emergency-body/);
  assert.match(stylesheet, /\.fpw-emergency-content > section \{[\s\S]*?scroll-margin-top: 116px;/);
  assert.match(stylesheet, /\.fpw-emergency-table-region \{[\s\S]*?overflow-x: auto;/);
  assert.match(stylesheet, /\.fpw-emergency-table-region:focus-visible/);
  assert.match(stylesheet, /\.fpw-emergency-rail \{[\s\S]*?position: sticky;/);
  assert.match(stylesheet, /@media \(max-width: 1100px\)[\s\S]*?\.fpw-emergency-rail \{[\s\S]*?position: static;/);
  assert.match(stylesheet, /@media \(max-width: 800px\)/);
  assert.match(stylesheet, /@media \(max-width: 480px\)/);
  assert.match(stylesheet, /\.fpw-emergency-figure img \{[\s\S]*?width: 100%;[\s\S]*?height: auto;/);
  assert.match(stylesheet, /\.fpw-emergency-card-downloads \{[\s\S]*?grid-template-columns: repeat\(2/);
  assert.match(stylesheet, /@media \(max-width: 800px\)[\s\S]*?\.fpw-emergency-card-downloads \{[\s\S]*?grid-template-columns: 1fr;/);
  assert.match(stylesheet, /@media \(prefers-reduced-motion: reduce\)/);
  assert.match(stylesheet, /@media print/);
  assert.match(stylesheet, /body\.fpw-emergency-body > header,[\s\S]*?body\.fpw-emergency-body > footer/);
  assert.match(stylesheet, /@media print[\s\S]*?\.fpw-emergency-figure,[\s\S]*?\.fpw-emergency-card-downloads,[\s\S]*?display: none !important;/);
});

test("production clean route and sitemap expose the canonical page once", () => {
  assert.match(webConfig, /\^common-boating-emergencies\\\.cfm\$/);
  assert.match(webConfig, /\^common-boating-emergencies\$/);
  assert.match(webConfig, /\^common-boating-emergencies\/\$/);
  assert.match(webConfig, /url="\/common-boating-emergencies\.cfm"/);
  assert.equal(countMatches(sitemap, new RegExp(escapeRegExp(canonical), "g")), 1);
  assert.match(sitemap, /<loc>https:\/\/floatplanwizard\.com\/common-boating-emergencies\/<\/loc>\s*<lastmod>2026-08-22<\/lastmod>/);
});
