import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));
const readText = (relativePath) => readFileSync(path.join(repositoryRoot, relativePath), "utf8");
const guide = readText("solo-boating-safety-guide.cfm");
const stylesheet = readText("assets/css/solo-boating-safety-guide.css");
const analyticsScript = readText("assets/js/solo-boating-safety-guide.js");
const generator = readText("scripts/generate-solo-boater-pamphlets.py");
const robots = readText("robots.txt");
const sitemap = readText("sitemap.xml");
const webConfig = readText("web.config");

const pamphlets = [
  {
    filename: "solo-boater-trip-planning-guide.pdf",
    label: "Download the Trip Planning Reference PDF",
    event: "solo_boating_trip_planning_pdf_download",
    section: "trip_plan",
    key: "trip_planning",
    items: 12
  },
  {
    filename: "solo-boater-vessel-information-guide.pdf",
    label: "Download the Vessel Information Reference PDF",
    event: "solo_boating_vessel_information_pdf_download",
    section: "vessel_information",
    key: "vessel_information",
    items: 7
  },
  {
    filename: "solo-boater-personal-safety-guide.pdf",
    label: "Download the Personal Safety Reference PDF",
    event: "solo_boating_personal_safety_pdf_download",
    section: "personal_safety",
    key: "personal_safety",
    items: 10
  },
  {
    filename: "solo-boater-weather-guide.pdf",
    label: "Download the Weather Reference PDF",
    event: "solo_boating_weather_pdf_download",
    section: "weather",
    key: "weather",
    items: 14
  },
  {
    filename: "solo-boater-communications-guide.pdf",
    label: "Download the Communications Reference PDF",
    event: "solo_boating_communications_pdf_download",
    section: "communications",
    key: "communications",
    items: 12
  },
  {
    filename: "solo-boater-boat-readiness-guide.pdf",
    label: "Download the Boat Readiness Reference PDF",
    event: "solo_boating_boat_readiness_pdf_download",
    section: "boat_readiness",
    key: "boat_readiness",
    items: 19
  },
  {
    filename: "solo-boater-precautions-guide.pdf",
    label: "Download the Solo Precautions Reference PDF",
    event: "solo_boating_precautions_pdf_download",
    section: "solo_precautions",
    key: "solo_precautions",
    items: 10
  }
];

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

test("the seven checklist panels expose direct, free PDF downloads with topic-specific context", () => {
  assert.equal((guide.match(/class="fpw-solo-checklist-why"/g) || []).length, 7);
  assert.equal((guide.match(/data-fpw-solo-pdf-download/g) || []).length, 7);
  assert.equal((guide.match(/<span class="fpw-solo-pdf-badge" aria-hidden="true">PDF<\/span>/g) || []).length, 7);
  assert.match(guide, /assets\/js\/solo-boating-safety-guide\.js\?v=20260813-ebook-downloads/);

  for (const pamphlet of pamphlets) {
    const linkPattern = new RegExp(
      `<a class="fpw-solo-pdf-download" href="<cfoutput>#fpwSoloBasePath#<\\/cfoutput>\\/downloads\\/${escapeRegExp(pamphlet.filename)}" download type="application\\/pdf"[^>]*`
      + `data-fpw-track="${pamphlet.event}"[^>]*`
      + `data-fpw-track-source-page="solo_boating_safety_guide"[^>]*`
      + `data-fpw-track-section="${pamphlet.section}"[^>]*`
      + `data-fpw-track-document-key="${pamphlet.key}"[^>]*`
      + `data-fpw-track-label="${escapeRegExp(pamphlet.label)}"`
    );
    assert.match(guide, linkPattern, `Missing direct download contract for ${pamphlet.filename}`);
    assert.equal((guide.match(new RegExp(escapeRegExp(pamphlet.label), "g")) || []).length, 2);
  }

  assert.doesNotMatch(guide, /fpw-solo-pdf-download[^>]+(?:join\.cfm|login|checkout|stripe)/i);
});

test("every generated pamphlet is a substantive two-page PDF within a practical download size", () => {
  assert.equal(pamphlets.reduce((total, pamphlet) => total + pamphlet.items, 0), 84);
  for (const pamphlet of pamphlets) {
    const pdf = readFileSync(path.join(repositoryRoot, "downloads", pamphlet.filename));
    const source = pdf.toString("latin1");
    assert.equal(pdf.subarray(0, 4).toString("ascii"), "%PDF", `${pamphlet.filename} is not a PDF`);
    assert.equal((source.match(/\/Type \/Page\b/g) || []).length, 2, `${pamphlet.filename} must have two pages`);
    assert.ok(pdf.byteLength > 100_000, `${pamphlet.filename} is unexpectedly small`);
    assert.ok(pdf.byteLength < 5_000_000, `${pamphlet.filename} is unexpectedly large`);
  }
});

test("the deterministic generator derives all checklist wording from the public guide and validates the series", () => {
  assert.match(generator, /rl_config\.invariant = 1/);
  assert.match(generator, /GUIDE_SOURCE = REPOSITORY_ROOT \/ "solo-boating-safety-guide\.cfm"/);
  assert.match(generator, /EXPECTED_COUNTS = \{/);
  assert.match(generator, /if total_items != 84:/);
  assert.match(generator, /if not 2 <= page_count <= 5:/);
  assert.match(generator, /if missing_items:/);
  assert.match(generator, /if link_count < 3:/);
  assert.match(generator, /writer\.root_object\[NameObject\("\/Lang"\)\] = TextStringObject\("en-US"\)/);
});

test("download analytics are delegated, single-bound, failure-safe, and never block the link", () => {
  assert.match(analyticsScript, /window\.__fpwSoloPdfDownloadsBound/);
  assert.match(analyticsScript, /document\.addEventListener\("click"/);
  assert.match(analyticsScript, /\[data-fpw-solo-pdf-download\]\[data-fpw-track\], \[data-fpw-solo-ebook-download\]\[data-fpw-track\]/);
  for (const field of ["source_page", "section", "document_key", "label"]) {
    assert.match(analyticsScript, new RegExp(`${field}:`));
  }
  assert.match(analyticsScript, /try \{/);
  assert.match(analyticsScript, /catch \(error\)/);
  assert.doesNotMatch(analyticsScript, /preventDefault|setTimeout|sendBeacon|fetch\(/);
  assert.equal(new Set(pamphlets.map((pamphlet) => pamphlet.event)).size, pamphlets.length);
});

test("download presentation is scoped, keyboard-visible, mobile-safe, and omitted from HTML print", () => {
  assert.match(stylesheet, /\.fpw-solo-pdf-download \{[\s\S]*?max-width: 100%;/);
  assert.match(stylesheet, /\.fpw-solo-pdf-download \{[\s\S]*?min-height: 44px;/);
  assert.match(stylesheet, /\.fpw-solo-content a:focus-visible/);
  assert.match(stylesheet, /@media \(max-width: 420px\)[\s\S]*?\.fpw-solo-pdf-download \{[\s\S]*?width: 100%;/);
  assert.match(stylesheet, /@media print[\s\S]*?\.fpw-solo-pdf-download \{[\s\S]*?display: none !important;/);
});

test("only the seven public pamphlets are crawlable exceptions to the downloads block", () => {
  assert.equal((robots.match(/^Disallow: \/downloads\/$/gm) || []).length, 1);
  for (const pamphlet of pamphlets) {
    const exactAllow = new RegExp(`^Allow: \/downloads\/${escapeRegExp(pamphlet.filename)}$`, "gm");
    assert.equal((robots.match(exactAllow) || []).length, 1, `Missing exact robots allowance for ${pamphlet.filename}`);
    assert.equal(sitemap.includes(pamphlet.filename), false, `${pamphlet.filename} must not be added to the sitemap`);
  }
  assert.doesNotMatch(robots, /^Allow: \/downloads\/$/m);
});

test("IIS adds one exact canonical Link header only to the seven pamphlet responses", () => {
  const ruleMatch = webConfig.match(/<rule name="Set Solo Boater PDF canonical Link header">[\s\S]*?<\/rule>/);
  assert.ok(ruleMatch, "Missing Solo Boater PDF canonical outbound rule");
  const rule = ruleMatch[0];
  const urlPatternMatch = rule.match(/<add input="\{URL\}"\s+pattern="([^"]+)"/);
  assert.ok(urlPatternMatch, "Missing exact PDF URL condition");
  const urlPattern = new RegExp(urlPatternMatch[1]);

  for (const pamphlet of pamphlets) {
    assert.equal(urlPattern.test(`/downloads/${pamphlet.filename}`), true, `Header rule misses ${pamphlet.filename}`);
  }

  const allDownloadPdfs = readdirSync(path.join(repositoryRoot, "downloads")).filter((name) => name.endsWith(".pdf"));
  const pamphletNames = new Set(pamphlets.map((pamphlet) => pamphlet.filename));
  const unrelatedPdfs = allDownloadPdfs.filter((name) => !pamphletNames.has(name));
  assert.ok(unrelatedPdfs.length > 0, "Expected at least one unrelated PDF scope control");
  for (const filename of unrelatedPdfs) {
    assert.equal(urlPattern.test(`/downloads/${filename}`), false, `Header rule must not affect ${filename}`);
  }

  assert.match(rule, /<match serverVariable="RESPONSE_Link" pattern="\.\*" \/>/);
  assert.match(rule, /<add input="\{RESPONSE_STATUS\}" pattern="\^200\(\?:\\s\|\$\)" \/>/);
  assert.match(rule, /<add input="\{RESPONSE_CONTENT_TYPE\}" pattern="\^application\/pdf\(\?:\\s\*;\.\*\)\?\$" ignoreCase="true" \/>/);
  assert.match(rule, /value="&lt;https:\/\/floatplanwizard\.com\/solo-boating-safety-guide\/&gt;; rel=&quot;canonical&quot;"/);
  assert.equal((webConfig.match(/serverVariable="RESPONSE_Link"/g) || []).length, 1);
});
