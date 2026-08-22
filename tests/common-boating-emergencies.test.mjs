import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
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
  assert.match(page, /<meta property="og:image" content="https:\/\/floatplanwizard\.com\/assets\/images\/social\/floatplanwizard-social-preview-20260730\.png">/);
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
    "mainEntityOfPage"
  ]) {
    assert.equal(page.includes(`["${property}"]`), true, `Missing schema property ${property}`);
  }
  assert.match(page, /fpwEmergencyPublishedDate = "2026-08-23";/);
  assert.match(page, /fpwEmergencyModifiedDate = "2026-08-23";/);
  assert.doesNotMatch(page, /fpwEmergencySchemaArticle\["image"\]/);
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

test("phase-one asset policy omits unreviewed scenario art and a PDF download", () => {
  assert.doesNotMatch(page, /implementation-assets|fpw-common-boating-emergencies-hero-reference|fpw-person-overboard-reference/i);
  assert.doesNotMatch(page, /href="[^"]+\.pdf(?:[?#][^"]*)?"[^>]*data-fpw-guide-card/i);
  assert.doesNotMatch(page, /guide_card_download/);
  assert.match(page, /Print this guide and emergency-card copy/);
});

test("analytics use the required low-cardinality event and parameter contracts", () => {
  for (const eventName of [
    "guide_print_select",
    "guide_toc_select",
    "guide_cta_select",
    "guide_source_select"
  ]) {
    assert.match(script, new RegExp(`track\\("${eventName}"`));
  }
  for (const field of [
    "guide_id",
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
  assert.doesNotMatch(script, /email|phone|latitude|longitude|vessel|user_id/i);
});

test("styles provide responsive, focus, reduced-motion, table, and print foundations", () => {
  assert.match(page, /common-boating-emergencies\.css\?v=20260822-phase1/);
  assert.match(stylesheet, /body\.fpw-emergency-body/);
  assert.match(stylesheet, /\.fpw-emergency-content > section \{[\s\S]*?scroll-margin-top: 116px;/);
  assert.match(stylesheet, /\.fpw-emergency-table-region \{[\s\S]*?overflow-x: auto;/);
  assert.match(stylesheet, /\.fpw-emergency-table-region:focus-visible/);
  assert.match(stylesheet, /\.fpw-emergency-rail \{[\s\S]*?position: sticky;/);
  assert.match(stylesheet, /@media \(max-width: 1100px\)[\s\S]*?\.fpw-emergency-rail \{[\s\S]*?position: static;/);
  assert.match(stylesheet, /@media \(max-width: 800px\)/);
  assert.match(stylesheet, /@media \(max-width: 480px\)/);
  assert.match(stylesheet, /@media \(prefers-reduced-motion: reduce\)/);
  assert.match(stylesheet, /@media print/);
  assert.match(stylesheet, /body\.fpw-emergency-body > header,[\s\S]*?body\.fpw-emergency-body > footer/);
});

test("production clean route and sitemap expose the canonical page once", () => {
  assert.match(webConfig, /\^common-boating-emergencies\\\.cfm\$/);
  assert.match(webConfig, /\^common-boating-emergencies\$/);
  assert.match(webConfig, /\^common-boating-emergencies\/\$/);
  assert.match(webConfig, /url="\/common-boating-emergencies\.cfm"/);
  assert.equal(countMatches(sitemap, new RegExp(escapeRegExp(canonical), "g")), 1);
  assert.match(sitemap, /<loc>https:\/\/floatplanwizard\.com\/common-boating-emergencies\/<\/loc>\s*<lastmod>2026-08-22<\/lastmod>/);
});
