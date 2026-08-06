import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));
const read = (relativePath) => readFileSync(path.join(repositoryRoot, relativePath), "utf8");
const page = read("shore-contact-overdue-boater.cfm");
const stylesheet = read("assets/css/shore-contact-overdue-guide.css");
const actionCtaPartial = read("partials/fpw-action-cta.cfm");
const actionCtaScript = read("assets/js/fpw-action-cta.js");
const topNavStylesheet = read("assets/css/top-nav.css");

function countMatches(source, pattern) {
  return [...source.matchAll(pattern)].length;
}

test("guide has one exact metadata set and the canonical public URL", () => {
  assert.equal(
    countMatches(page, /<title>What to Do When a Boater Is Overdue \| Shore Contact Guide<\/title>/g),
    1
  );
  assert.equal(
    countMatches(
      page,
      /<meta name="description" content="Learn what a shore contact should do when a boater misses a check-in or expected return, what information to gather, and when to contact authorities\.">/g
    ),
    1
  );
  assert.equal(
    countMatches(
      page,
      /<link rel="canonical" href="https:\/\/floatplanwizard\.com\/shore-contact-overdue-boater\/">/g
    ),
    1
  );
  assert.match(page, /<meta property="og:type" content="article">/);
  assert.match(page, /<meta name="twitter:card" content="summary_large_image">/);
  assert.match(page, /<meta name="robots" content="index,follow">/);
});

test("guide uses the existing schema graph pattern with Article and breadcrumbs", () => {
  for (const type of ["Organization", "BreadcrumbList", "WebPage", "Article"]) {
    assert.match(page, new RegExp(`structInsert\\([^\\n]+schemaTypeKey, "${type}"`));
  }
  for (const property of [
    "headline",
    "datePublished",
    "dateModified",
    "author",
    "publisher",
    "mainEntityOfPage",
    "breadcrumb"
  ]) {
    assert.equal(page.includes(`["${property}"]`), true, `Missing schema property ${property}`);
  }
  assert.match(page, /fpwOverduePublishedDate = "2026-08-06";/);
  assert.match(page, /serializeJSON\(fpwOverdueJsonLd\)/);
  assert.equal(countMatches(page, /type="application\/ld\+json"/g), 1);
});

test("guide contains the complete safety structure and careful response principles", () => {
  assert.equal(
    countMatches(
      page,
      /<h1 id="fpw-overdue-title">What a Shore Contact Should Do When a Boater Is Overdue<\/h1>/g
    ),
    1
  );

  for (const heading of [
    "Before the boat leaves",
    "When a check-in or return is missed",
    "Information to gather",
    "When to contact authorities",
    "What to do after reporting concern",
    "What FloatPlanWizard helps organize"
  ]) {
    assert.equal(page.includes(`>${heading}</h2>`), true, `Missing section heading: ${heading}`);
  }

  for (const requiredCopy of [
    "There is no universal grace period.",
    "report facts and clearly identify anything you do not know. Do not speculate.",
    "do not wait for the planned overdue time",
    "Treat it as a reported update, not as a live or guaranteed current position.",
    "Do not independently launch an unsafe search.",
    "FloatPlanWizard does not determine when rescue action is required, verify an emergency, contact authorities for you, or dispatch assistance.",
    "FPW does not continuously watch every trip, guarantee message delivery, confirm distress, provide professional monitoring, guarantee a vessel's current location, contact the Coast Guard automatically, or replace emergency authorities."
  ]) {
    assert.equal(page.includes(requiredCopy), true, `Missing safety copy: ${requiredCopy}`);
  }

  assert.equal(countMatches(page, /class="fpw-overdue-checklist"/g), 1);
  assert.equal(countMatches(page, /class="fpw-overdue-steps"/g), 1);
  assert.equal(countMatches(page, /class="fpw-overdue-emergency" role="note"/g), 1);
});

test("table of contents, heading IDs, and contextual links are internally consistent", () => {
  const staticIds = [...page.matchAll(/\bid="([a-z][a-z0-9-]*)"/gi)].map((match) => match[1]);
  assert.equal(new Set(staticIds).size, staticIds.length, "Static IDs must be unique");

  const tocTargets = [...page.matchAll(/<li><a href="#([a-z0-9-]+)">/g)].map((match) => match[1]);
  assert.deepEqual(tocTargets, [
    "before-the-boat-leaves",
    "when-a-check-in-is-missed",
    "information-to-gather",
    "when-to-contact-authorities",
    "after-reporting-concern",
    "what-fpw-organizes"
  ]);
  for (const target of tocTargets) {
    assert.equal(page.includes(`id="${target}"`), true, `Missing table-of-contents target: ${target}`);
  }

  for (const destination of [
    "/why-use-a-float-plan/",
    "/how-it-works/",
    "/faq/#safety",
    "/downloads/uscg-float-plan.pdf"
  ]) {
    assert.equal(page.includes(destination), true, `Missing contextual destination: ${destination}`);
  }
});

test("CTA uses the reusable interface, signed-in and signed-out destinations, and one safe event", () => {
  for (const value of [
    '"headline" = "Give your shore contact a clear plan"',
    '"buttonLabel" = "Plan a Trip"',
    '"analyticsEvent" = "shore_contact_overdue_guide_cta_click"',
    '"sourcePage" = "shore_contact_overdue_guide"',
    '"section" = "after_safety_guide"',
    '"ctaType" = "plan_trip"',
    '"destinationKey" = fpwOverdueCtaSignedIn ? "dashboard" : "join"'
  ]) {
    assert.equal(page.includes(value), true, `Missing CTA contract: ${value}`);
  }
  assert.match(page, /fpwOverdueCtaSignedIn \? fpwOverdueBasePath & "\/app\/dashboard\.cfm" : fpwOverdueBasePath & "\/app\/join\.cfm"/);
  assert.match(page, /<cfinclude template="partials\/fpw-action-cta\.cfm">/);
  assert.match(page, /assets\/js\/fpw-action-cta\.js/);
  assert.match(page, /includes\/analytics_ga4\.cfm/);

  for (const field of ["source_page", "section", "cta_type", "label", "auth_state", "destination_key"]) {
    assert.equal(actionCtaScript.includes(`${field}:`), true, `Missing analytics field: ${field}`);
  }
  assert.equal(actionCtaScript.includes("preventDefault"), false, "Tracking must not control navigation");
  assert.match(actionCtaScript, /try \{/);
  assert.match(actionCtaScript, /catch \(error\) \{\}/);
  assert.equal(actionCtaPartial.includes("data-fpw-action-cta"), true);
  assert.equal(page.includes("route_planning_started"), false);
  assert.equal(page.includes("float_plan_started"), false);
});

test("new page styling is scoped, responsive, and exposes visible focus", () => {
  assert.match(stylesheet, /body\.fpw-overdue-body/);
  assert.match(page, /shore-contact-overdue-guide\.css\?v=20260806-cta-color/);
  assert.match(stylesheet, /\.fpw-overdue-page a:focus-visible/);
  assert.match(stylesheet, /\.fpw-overdue-content a:not\(\.fpw-cta\)/);
  assert.match(stylesheet, /\.fpw-overdue-content a:not\(\.fpw-cta\):hover/);
  assert.doesNotMatch(stylesheet, /\.fpw-overdue-content a\s*\{/);

  const sharedPrimaryCtaBlock = topNavStylesheet.match(/\.fpw-cta-primary,[\s\S]*?\.fpw-site-header \.fpw-cta-primary \{([^}]*)\}/)?.[1] ?? "";
  assert.match(sharedPrimaryCtaBlock, /color: #01141c;/);
  assert.match(stylesheet, /@media \(max-width: 1024px\)/);
  assert.match(stylesheet, /@media \(max-width: 760px\)/);
  assert.match(stylesheet, /@media \(max-width: 480px\)/);
  assert.match(stylesheet, /\.fpw-overdue-checklist/);
  assert.match(stylesheet, /\.fpw-overdue-risk-grid/);
  assert.match(stylesheet, /\.fpw-overdue-toc \{[\s\S]*?top: 165px;[\s\S]*?max-height: calc\(100vh - 181px\);[\s\S]*?overflow-y: auto;/);
  assert.match(stylesheet, /@media \(max-width: 1024px\)[\s\S]*?\.fpw-overdue-toc \{[\s\S]*?position: static;[\s\S]*?max-height: none;[\s\S]*?overflow: visible;/);

  const emergencyBlock = stylesheet.match(/\.fpw-overdue-emergency \{([^}]*)\}/)?.[1] ?? "";
  assert.match(emergencyBlock, /border: 1px solid/);
  assert.doesNotMatch(emergencyBlock, /border-left:/);

  const principleBlock = stylesheet.match(/\.fpw-overdue-content \.fpw-overdue-principle \{([^}]*)\}/)?.[1] ?? "";
  assert.match(principleBlock, /margin-top: 22px;/);
  assert.doesNotMatch(principleBlock, /border-left:/);
});

test("clean route and sitemap publish the selected canonical URL exactly once", () => {
  const webConfig = read("web.config");
  const sitemap = read("sitemap.xml");
  const canonical = "https://floatplanwizard.com/shore-contact-overdue-boater/";

  assert.match(webConfig, /\^shore-contact-overdue-boater\\\.cfm\$/);
  assert.match(webConfig, /\^shore-contact-overdue-boater\$/);
  assert.match(webConfig, /\^shore-contact-overdue-boater\/\$/);
  assert.match(webConfig, /url="\/shore-contact-overdue-boater\.cfm"/);
  assert.equal(countMatches(sitemap, new RegExp(canonical.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "g")), 1);
  assert.match(sitemap, /<loc>https:\/\/floatplanwizard\.com\/shore-contact-overdue-boater\/<\/loc>\s*<lastmod>2026-08-06<\/lastmod>/);
});
