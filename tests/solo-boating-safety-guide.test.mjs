import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));
const read = (relativePath) => readFileSync(path.join(repositoryRoot, relativePath), "utf8");
const page = read("solo-boating-safety-guide.cfm");
const stylesheet = read("assets/css/solo-boating-safety-guide.css");
const actionCtaPartial = read("partials/fpw-action-cta.cfm");
const actionCtaScript = read("assets/js/fpw-action-cta.js");
const topNav = read("includes/top_nav.cfm");
const webConfig = read("web.config");
const sitemap = read("sitemap.xml");

function countMatches(source, pattern) {
  return [...source.matchAll(pattern)].length;
}

test("guide has the approved metadata, H1, and canonical URL exactly once", () => {
  assert.equal(countMatches(page, /<title>Solo Boating Safety Guide \| Kayaks, Powerboats &amp; Cruisers<\/title>/g), 1);
  assert.equal(
    countMatches(page, /<meta name="description" content="Practical solo boating safety guidance for kayaks, powerboats, sailboats and cruisers, including float plans, communications, weather, self-rescue and a pre-departure checklist\.">/g),
    1
  );
  assert.equal(countMatches(page, /<link rel="canonical" href="https:\/\/floatplanwizard\.com\/solo-boating-safety-guide\/">/g), 1);
  assert.equal(countMatches(page, /<h1 id="fpw-solo-title">Solo Boating Safety: A Practical Guide from Kayaks to Cruisers<\/h1>/g), 1);
  assert.match(page, /<meta property="og:type" content="article">/);
  assert.match(page, /<meta name="robots" content="index,follow">/);
});

test("guide uses the established schema graph with consistent Article references", () => {
  for (const type of ["Organization", "BreadcrumbList", "WebPage", "Article"]) {
    assert.match(page, new RegExp(`structInsert\\([^\\n]+schemaTypeKey, "${type}"`));
  }
  for (const property of [
    "url",
    "headline",
    "description",
    "datePublished",
    "dateModified",
    "inLanguage",
    "author",
    "publisher",
    "mainEntityOfPage",
    "breadcrumb"
  ]) {
    assert.equal(page.includes(`["${property}"]`), true, `Missing schema property ${property}`);
  }
  assert.match(page, /fpwSoloPublishedDate = "2026-08-10T11:58:52-04:00";/);
  assert.match(page, /fpwSoloSchemaArticle\["url"\] = fpwSoloCanonicalUrl;/);
  assert.match(page, /fpwSoloSchemaArticle\["headline"\] = fpwSoloHeadline;/);
  assert.doesNotMatch(page, /fpwSoloSchemaArticle\["image"\]/);
  assert.equal(countMatches(page, /type="application\/ld\+json"/g), 1);
});

test("all approved substantive sections are present without numeric heading prefixes", () => {
  assert.doesNotMatch(page, /<h[23][^>]*>\d+\./);

  for (const requiredCopy of [
    "Leave a float plan every time you boat alone",
    "Choose the right shore contact",
    "Wear your life jacket",
    "Plan around the possibility of falling overboard",
    "Keep critical emergency equipment with you",
    "Prevent the boat from leaving without you",
    "marine VHF and Channel 16",
    "Configure DSC correctly",
    "Understand PLBs and EPIRBs",
    "Treat weather as a solo go/no-go decision",
    "Cold water changes the risk",
    "Manage fatigue before it becomes a safety problem",
    "Alcohol and solo boating do not mix well",
    "Check the boat or craft before departure",
    "Solo kayaking, canoeing, and paddlecraft",
    "Solo operation of small powerboats",
    "Solo sailing",
    "Solo cruising and larger recreational boats",
    "Make route changes part of the plan",
    "Do not depend on continuous tracking",
    "What FloatPlanWizard can help organize"
  ]) {
    assert.equal(page.includes(requiredCopy), true, `Missing approved content: ${requiredCopy}`);
  }

  for (const carefulLanguage of [
    "There is no universal numerical threshold",
    "not universal U.S. recreational law",
    "A projected route position is not the same as a confirmed current vessel position.",
    "FPW does not guarantee continuous tracking.",
    "FPW does not verify distress.",
    "FPW does not dispatch emergency assistance.",
    "Do not treat an estimated or last reported position as a guaranteed current location.",
    "An autopilot does not make solo sailing equivalent to having another person aboard."
  ]) {
    assert.equal(page.includes(carefulLanguage), true, `Missing safety distinction: ${carefulLanguage}`);
  }
});

test("the complete source checklist is semantic and available without JavaScript", () => {
  assert.equal(countMatches(page, /<input type="checkbox">/g), 84);
  assert.equal(countMatches(page, /<ul class="fpw-solo-checklist">/g), 7);
  assert.equal(countMatches(page, /<li><label><input type="checkbox"><span>/g), 84);
  for (const group of [
    "Trip plan",
    "Vessel or craft information",
    "Personal safety",
    "Weather and environment",
    "Communications",
    "Boat or craft readiness",
    "Solo-specific precautions"
  ]) {
    assert.match(page, new RegExp(`>${group}<\\/h3>`));
  }
  assert.match(page, /does not require an account, download, or JavaScript/);
  assert.doesNotMatch(page, /FPW_SOLO_GUIDE_CONTENT/);
});

test("table of contents, labels, callouts, and contextual links are accessible and consistent", () => {
  const tocStart = page.indexOf('<nav class="fpw-solo-toc"');
  const tocMarkup = page.slice(tocStart, page.indexOf("</nav>", tocStart));
  assert.match(tocMarkup, /<ul>[\s\S]*?<\/ul>/);
  assert.doesNotMatch(tocMarkup, /<ol>/);
  const staticIds = [...page.matchAll(/\bid="([a-z][a-z0-9-]*)"/gi)].map((match) => match[1]);
  assert.equal(new Set(staticIds).size, staticIds.length, "Static IDs must be unique");

  const tocTargets = [...page.matchAll(/<li><a href="#([a-z0-9-]+)">/g)].map((match) => match[1]);
  assert.deepEqual(tocTargets, [
    "why-solo-boating-is-different",
    "float-plans-and-shore-contacts",
    "staying-aboard-self-recovery",
    "communications-emergency-beacons",
    "weather-cold-water-fatigue",
    "boat-readiness",
    "paddlecraft",
    "powerboats",
    "sailboats-cruisers",
    "changing-plans-tracking",
    "solo-boater-checklist"
  ]);
  for (const target of tocTargets) {
    assert.equal(page.includes(`id="${target}"`), true, `Missing TOC target: ${target}`);
  }

  for (const labelTarget of [...page.matchAll(/aria-labelledby="([a-z0-9-]+)"/g)].map((match) => match[1])) {
    assert.equal(page.includes(`id="${labelTarget}"`), true, `Missing aria-labelledby target: ${labelTarget}`);
  }
  assert.equal(countMatches(page, /class="fpw-solo-callout/g), 4);

  for (const destination of [
    "/shore-contact-overdue-boater/",
    "/why-use-a-float-plan/",
    "/how-it-works/",
    "/app/weather.cfm",
    "/boat-fuel-calculator/"
  ]) {
    assert.equal(page.includes(destination), true, `Missing internal link: ${destination}`);
  }
  for (const sourceHost of ["uscgboating.org", "navcen.uscg.gov", "beaconregistration.noaa.gov", "weather.gov", "nps.gov", "cgaux.org", "sailing.org"]) {
    assert.equal(page.includes(sourceHost), true, `Missing official source: ${sourceHost}`);
  }

  const externalLinks = [...page.matchAll(/<a\b[^>]*href="https:\/\/[^>]+>/g)].map((match) => match[0]);
  assert.equal(externalLinks.length, 10);
  for (const link of externalLinks) {
    assert.match(link, /target="_blank"/);
    assert.match(link, /rel="noopener noreferrer"/);
  }
});

test("CTA preserves the reusable signed-in, signed-out, no-JavaScript, and analytics contract", () => {
  for (const value of [
    '"headline" = "Give someone ashore a clear plan"',
    '"supportingText" = "Organize your route, timing, vessel details and shore contact before you head out alone."',
    '"buttonLabel" = "Plan a Route"',
    '"analyticsEvent" = "solo_boating_safety_guide_plan_route_cta_click"',
    '"sourcePage" = "solo_boating_safety_guide"',
    '"section" = "before_checklist"',
    '"ctaType" = "plan_route"',
    '"destinationKey" = fpwSoloCtaSignedIn ? "dashboard" : "join"'
  ]) {
    assert.equal(page.includes(value), true, `Missing CTA contract: ${value}`);
  }
  assert.match(page, /fpwSoloCtaSignedIn \? fpwSoloBasePath & "\/app\/dashboard\.cfm" : fpwSoloBasePath & "\/app\/join\.cfm"/);
  assert.equal(countMatches(page, /<cfinclude template="partials\/fpw-action-cta\.cfm">/g), 1);
  assert.equal(actionCtaPartial.includes("data-fpw-action-cta"), true);
  assert.equal(actionCtaScript.includes("preventDefault"), false);
  for (const field of ["source_page", "section", "cta_type", "label", "auth_state", "destination_key"]) {
    assert.equal(actionCtaScript.includes(`${field}:`), true, `Missing analytics field: ${field}`);
  }
});

test("guide styling is scoped, responsive, printable, and has visible focus", () => {
  assert.match(stylesheet, /body\.fpw-solo-body/);
  assert.match(page, /solo-boating-safety-guide\.css\?v=20260810/);
  assert.match(stylesheet, /\.fpw-solo-checklist-grid/);
  assert.match(stylesheet, /\.fpw-solo-checklist input\[type="checkbox"\]:focus-visible/);
  assert.match(stylesheet, /@media \(max-width: 1024px\)/);
  assert.match(stylesheet, /@media \(max-width: 760px\)/);
  assert.match(stylesheet, /@media \(max-width: 420px\)/);
  assert.match(stylesheet, /@media print/);
  assert.match(stylesheet, /\.fpw-solo-toc \{[\s\S]*?position: sticky;[\s\S]*?overflow-y: auto;/);
  assert.match(stylesheet, /@media \(max-width: 1024px\)[\s\S]*?\.fpw-solo-toc \{[\s\S]*?position: static;[\s\S]*?max-height: none;/);
});

test("navigation, clean routes, and sitemap publish the canonical guide", () => {
  assert.match(topNav, /"pattern" = "\/solo-boating-safety-guide", "active" = "resources-solo-boating-guide"/);
  assert.equal(countMatches(topNav, /<span>Solo Boating Safety Guide<\/span>/g), 1);
  assert.match(topNav, /href="#topNavBasePath#\/solo-boating-safety-guide\/"/);

  assert.match(webConfig, /\^solo-boating-safety-guide\\\.cfm\$/);
  assert.match(webConfig, /\^solo-boating-safety-guide\$/);
  assert.match(webConfig, /\^solo-boating-safety-guide\/\$/);
  assert.match(webConfig, /url="\/solo-boating-safety-guide\.cfm"/);

  const canonical = "https://floatplanwizard.com/solo-boating-safety-guide/";
  assert.equal(countMatches(sitemap, new RegExp(canonical.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "g")), 1);
  assert.match(sitemap, /<loc>https:\/\/floatplanwizard\.com\/solo-boating-safety-guide\/<\/loc>\s*<lastmod>2026-08-10<\/lastmod>/);
});
