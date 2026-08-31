import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));
const read = (relativePath) => readFileSync(path.join(repositoryRoot, relativePath), "utf8");
const page = read("why-use-a-float-plan.cfm");
const stylesheet = read("assets/css/float-plan-guide.css");
const guideScript = read("assets/js/float-plan-guide.js");
const topNav = read("includes/top_nav.cfm");
const webConfig = read("web.config");
const sitemap = read("sitemap.xml");

const canonical = "https://floatplanwizard.com/why-use-a-float-plan/";
const title = "Float Plan Guide: Why It Matters & What to Include | FPW";
const description = "Learn what a float plan is, why boaters should use one, what to include, who should hold it, when to update it, and what to do if a boater is overdue.";
const socialTitle = "The Complete Float Plan Guide for Recreational Boaters";
const socialDescription = "What a float plan is, what to include, who should hold it, how overdue timing works, and how to keep the plan useful when the trip changes.";
const tocTargets = [
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

function countMatches(source, pattern) {
  return [...source.matchAll(pattern)].length;
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

test("pillar publishes one exact metadata set and one canonical URL", () => {
  assert.equal(countMatches(page, /<title>Float Plan Guide: Why It Matters & What to Include \| FPW<\/title>/g), 1);
  assert.equal(countMatches(page, new RegExp(`<meta name="description" content="${escapeRegExp(description)}">`, "g")), 1);
  assert.equal(countMatches(page, new RegExp(`<link rel="canonical" href="${escapeRegExp(canonical)}">`, "g")), 1);
  assert.equal(countMatches(page, new RegExp(`<meta property="og:url" content="${escapeRegExp(canonical)}">`, "g")), 1);
  assert.equal(countMatches(page, new RegExp(`<meta property="og:title" content="${escapeRegExp(socialTitle)}">`, "g")), 1);
  assert.equal(countMatches(page, new RegExp(`<meta property="og:description" content="${escapeRegExp(socialDescription)}">`, "g")), 1);
  assert.equal(countMatches(page, new RegExp(`<meta name="twitter:title" content="${escapeRegExp(socialTitle)}">`, "g")), 1);
  assert.equal(countMatches(page, new RegExp(`<meta name="twitter:description" content="${escapeRegExp(socialDescription)}">`, "g")), 1);
  assert.equal(countMatches(page, /<meta name="robots" content="index,follow,max-image-preview:large">/g), 1);
  assert.equal(countMatches(page, /type="application\/ld\+json"/g), 1);

  assert.equal(page.includes(`fpwFloatPlanPageTitle = "${title}";`), true);
  assert.equal(page.includes(`fpwFloatPlanPageDescription = "${description}";`), true);
  assert.equal(page.includes(`fpwFloatPlanCanonicalUrl = "${canonical}";`), true);
});

test("schema graph uses the canonical for WebPage and Article and excludes FAQPage and HowTo", () => {
  for (const type of ["Organization", "WebSite", "BreadcrumbList", "WebPage", "Article"]) {
    assert.match(page, new RegExp(`schemaTypeKey, "${type}"`), `Missing schema type ${type}`);
  }

  assert.match(page, /structInsert\(fpwFloatPlanSchemaPage, schemaIdKey, fpwFloatPlanCanonicalUrl, true\)/);
  assert.match(page, /fpwFloatPlanSchemaPage\["url"\] = fpwFloatPlanCanonicalUrl;/);
  assert.match(page, /fpwFloatPlanSchemaArticle\["url"\] = fpwFloatPlanCanonicalUrl;/);
  assert.match(page, /fpwFloatPlanSchemaArticle\["mainEntityOfPage"\] = fpwFloatPlanSchemaRef\(fpwFloatPlanCanonicalUrl\);/);
  assert.match(page, /fpwFloatPlanSchemaArticle\["headline"\] = fpwFloatPlanHeadline;/);
  assert.match(page, /fpwFloatPlanSchemaArticle\["dateModified"\] = "2026-08-30";/);
  assert.match(page, /fpwFloatPlanSchemaArticle\["inLanguage"\] = "en-US";/);
  assert.doesNotMatch(page, /schemaTypeKey, "FAQPage"/);
  assert.doesNotMatch(page, /schemaTypeKey, "HowTo"/);

  assert.equal(countMatches(sitemap, new RegExp(escapeRegExp(canonical), "g")), 1);
  assert.match(sitemap, /<loc>https:\/\/floatplanwizard\.com\/why-use-a-float-plan\/<\/loc>\s*<lastmod>2026-08-30<\/lastmod>/);
});

test("one H1, ordered sections, and crawlable TOC share stable unique anchors", () => {
  assert.equal(countMatches(page, /<h1\b/g), 1);
  assert.equal(
    countMatches(page, /<h1 id="float-plan-guide-title">Float Plan Guide: What It Is, Why It Matters, and How to Use One<\/h1>/g),
    1
  );
  assert.equal(countMatches(page, /<main\b/g), 1);
  assert.match(page, /<main class="fpw-float-guide-page" id="main-content">/);
  assert.match(page, /<nav class="fpw-float-guide-breadcrumbs" aria-label="Breadcrumb">/);
  assert.match(page, /<a class="fpw-float-guide-skip-link" href="#main-content">Skip to guide content<\/a>/);

  const tocStart = page.indexOf('<nav class="fpw-float-guide-toc"');
  const tocEnd = page.indexOf("</nav>", tocStart);
  assert.notEqual(tocStart, -1);
  assert.notEqual(tocEnd, -1);
  const toc = page.slice(tocStart, tocEnd);
  assert.match(toc, /<ol>[\s\S]*<\/ol>/);
  const actualTargets = [...toc.matchAll(/<li><a href="#([a-z0-9-]+)" data-fpw-float-guide-toc data-section-id="\1">/g)]
    .map((match) => match[1]);
  assert.deepEqual(actualTargets, tocTargets);

  let previousIndex = -1;
  for (const target of tocTargets) {
    const index = page.indexOf(`<section id="${target}"`);
    assert.ok(index > previousIndex, `Missing or out-of-order section: ${target}`);
    previousIndex = index;
  }
  assert.ok(page.indexOf('<section id="related-guides"') > previousIndex);
  assert.ok(page.indexOf('<section id="create-your-float-plan"') > page.indexOf('<section id="related-guides"'));

  const ids = [...page.matchAll(/\sid="([A-Za-z][A-Za-z0-9_-]*)"/g)].map((match) => match[1]);
  assert.equal(new Set(ids).size, ids.length, "Static IDs must be unique");
  for (const labelledBy of [...page.matchAll(/aria-labelledby="([A-Za-z][A-Za-z0-9_-]*)"/g)].map((match) => match[1])) {
    assert.equal(ids.includes(labelledBy), true, `Missing aria-labelledby target: ${labelledBy}`);
  }
});

test("all seven instructional visuals remain semantic, captioned, and text-readable", () => {
  const teachingFigures = [...page.matchAll(/<figure class="fpw-float-guide-figure[^"]*"[\s\S]*?<\/figure>/g)].map((match) => match[0]);
  assert.equal(teachingFigures.length, 6);
  for (const figure of teachingFigures) {
    assert.match(figure, /aria-labelledby="[a-z0-9-]+"/);
    assert.match(figure, /<figcaption>[\s\S]+<\/figcaption>/);
  }

  for (const titleText of [
    "How a Float Plan Works",
    "How Much Detail Should a Float Plan Have?",
    "Anatomy of a Useful Float Plan",
    "Check-In vs Expected Return vs Overdue Threshold",
    "Paper vs. Digital Float Plan",
    "Safety Layers: What a Float Plan Does and Does Not Replace"
  ]) {
    assert.equal(page.includes(titleText), true, `Missing visual title: ${titleText}`);
  }

  const sampleStart = page.indexOf('<article class="fpw-float-guide-sample-plan"');
  const sampleEnd = page.indexOf("</article>", sampleStart);
  const samplePlan = page.slice(sampleStart, sampleEnd);
  assert.match(samplePlan, /aria-label="Example day-trip float plan"/);
  assert.equal(countMatches(samplePlan, /<section>/g), 7);

  assert.match(page, /<table class="fpw-float-guide-table fpw-float-guide-table--responsive">/);
  assert.match(page, /<th scope="col">/);
  assert.match(page, /<th scope="row" data-label=/);
  assert.equal(countMatches(page, /<input type="checkbox">/g), 29);
  assert.match(page, /fetchpriority="high"/);
  assert.match(page, /width="1916" height="821"/);
  assert.doesNotMatch(page, /loading="lazy"[^>]*float-plan-hero/);
});

test("safety limitations and careful timing distinctions stay explicit", () => {
  for (const requiredCopy of [
    "A float plan is not a tracking device",
    "A float plan is not emergency dispatch",
    "There is no universal “30-minute,” “one-hour,” or other grace period that is correct for every trip.",
    "Known immediate danger can require action before any planned threshold.",
    "A float plan is one safety layer.",
    "FloatPlanWizard is a planning and communication tool.",
    "It does not guarantee continuous tracking, guarantee message delivery, verify that an emergency exists, automatically dispatch rescue, or replace appropriate emergency communications.",
    "Links to official resources identify the source of guidance and do not imply official endorsement of FloatPlanWizard."
  ]) {
    assert.equal(page.includes(requiredCopy), true, `Missing safety limitation: ${requiredCopy}`);
  }

  assert.equal(page.includes("You do not file a recreational float plan with the U.S. Coast Guard."), true);
  assert.equal(page.includes("Avoid collecting sensitive information merely because a field exists."), true);
  assert.equal(page.includes("The best plan is not the longest plan."), true);
});

test("official and internal destinations are explicit and safely attributed", () => {
  const officialUrls = [
    "https://uscgboating.org/recreational-boaters/floating-plan.php",
    "https://floatplancentral.cgaux.org/",
    "https://floatplancentral.cgaux.org/download/USCGFloatPlan.pdf",
    "https://floatplancentral.cgaux.org/classroom/definition.htm",
    "https://floatplancentral.cgaux.org/classroom/how_it_works.htm",
    "https://floatplancentral.cgaux.org/FAQ.htm",
    "https://navcen.uscg.gov/radio-information-for-boaters",
    "https://www.sarsat.noaa.gov/register-your-beacon/"
  ];
  const sourcesStart = page.indexOf('<section id="sources"');
  const sourcesEnd = page.indexOf("</section>", sourcesStart);
  const sources = page.slice(sourcesStart, sourcesEnd);

  for (const url of officialUrls) {
    assert.equal(sources.includes(`href="${url}"`), true, `Missing official source: ${url}`);
  }
  const externalSourceAnchors = [...sources.matchAll(/<a\b[^>]*href="https:\/\/[^>]+>/g)].map((match) => match[0]);
  assert.equal(externalSourceAnchors.length, 8);
  for (const anchor of externalSourceAnchors) {
    assert.match(anchor, /target="_blank"/);
    assert.match(anchor, /rel="noopener noreferrer"/);
    assert.match(anchor, /data-fpw-float-guide-source/);
    assert.match(anchor, /data-source-org="[a-z_]+"/);
  }
  assert.equal(page.includes('fpwFloatPlanOfficialPdf = "https://floatplancentral.cgaux.org/download/USCGFloatPlan.pdf";'), true);

  for (const destination of [
    "/shore-contact-overdue-boater/",
    "/solo-boating-safety-guide/",
    "/common-boating-emergencies/",
    "/boat-fuel-calculator/",
    "/how-it-works/",
    "/app/dashboard.cfm",
    "/app/join.cfm"
  ]) {
    assert.equal(page.includes(destination), true, `Missing internal destination: ${destination}`);
  }
});

test("page CSS, print behavior, reduced motion, analytics, routes, and sitemap remain contract-backed", () => {
  assert.match(page, /assets\/css\/float-plan-guide\.css\?v=20260830-pillar-v1/);
  assert.match(page, /assets\/js\/float-plan-guide\.js\?v=20260830-pillar-v1/);
  assert.match(stylesheet, /body\.fpw-float-guide-body/);
  assert.match(stylesheet, /\.fpw-float-guide-body :where\(a, button, input\):focus-visible/);
  assert.match(stylesheet, /\.fpw-float-guide-toc \{[\s\S]*position: sticky;[\s\S]*overflow: auto;/);
  assert.match(stylesheet, /scroll-margin-top: 154px;/);
  for (const breakpoint of [1100, 860, 720, 390]) {
    assert.match(stylesheet, new RegExp(`@media \\(max-width: ${breakpoint}px\\)`));
  }
  assert.match(stylesheet, /@media \(prefers-reduced-motion: reduce\)/);
  assert.match(stylesheet, /@media print/);
  assert.match(stylesheet, /\.fpw-site-header,[\s\S]*\.fpw-site-footer,[\s\S]*footer \{[\s\S]*display: none !important;/);
  assert.match(stylesheet, /\.fpw-float-guide-sources a\[href\^="http"\]::after/);
  assert.match(stylesheet, /body\.fpw-float-guide-checklist-print #float-plan-checklist/);

  assert.deepEqual(
    [...guideScript.matchAll(/track\("([a-z0-9_]+)"/g)].map((match) => match[1]),
    [
      "float_plan_guide_toc_select",
      "float_plan_official_source_select",
      "float_plan_related_guide_select",
      "float_plan_guide_cta_select"
    ]
  );
  for (const field of ["section_id", "source_org", "destination_host", "guide_key", "placement", "destination_path", "cta_name", "auth_state"]) {
    assert.equal(guideScript.includes(`${field}:`), true, `Missing analytics field: ${field}`);
  }
  assert.doesNotMatch(guideScript, /\b(?:latitude|longitude|medical|vessel|passenger|email|phone)\b/i);
  assert.doesNotMatch(guideScript, /preventDefault/);
  assert.match(guideScript, /try \{[\s\S]*window\.FPWAnalytics\.track\(eventName, fields\);[\s\S]*catch \(error\)/);
  assert.match(guideScript, /window\.print\(\)/);
  assert.match(guideScript, /window\.addEventListener\("afterprint", clearChecklistPrintMode\)/);

  assert.match(topNav, /href="#topNavBasePath#\/why-use-a-float-plan\/"/);
  assert.match(topNav, /"pattern" = "\/why-use-a-float-plan", "active" = "resources-why-float-plan"/);
  assert.match(webConfig, /\^why-use-a-float-plan\\\.cfm\$/);
  assert.match(webConfig, /\^why-use-a-float-plan\$/);
  assert.match(webConfig, /\^why-use-a-float-plan\/\$/);
  assert.match(webConfig, /url="\/why-use-a-float-plan\.cfm"/);
});
