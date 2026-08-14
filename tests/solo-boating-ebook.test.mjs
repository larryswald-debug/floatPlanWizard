import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));
const readText = (relativePath) => readFileSync(path.join(repositoryRoot, relativePath), "utf8");
const guide = readText("solo-boating-safety-guide.cfm");
const stylesheet = readText("assets/css/solo-boating-safety-guide.css");
const analyticsScript = readText("assets/js/solo-boating-safety-guide.js");
const webConfig = readText("web.config");

const publications = [
  {
    filename: "floatplanwizard-solo-boating-safety-guide.pdf",
    type: "application/pdf",
    label: "Download the Complete Solo Boating Safety E-Book PDF",
    format: "pdf",
    magic: "%PDF"
  },
  {
    filename: "solo-boating-safety-a-practical-guide.epub",
    type: "application/epub+zip",
    label: "Download the Complete Solo Boating Safety E-Book EPUB",
    format: "epub",
    magic: "PK"
  }
];

test("the guide exposes one direct PDF and one direct EPUB complete-book download", () => {
  assert.equal((guide.match(/data-fpw-solo-ebook-download/g) || []).length, 2);
  assert.equal((guide.match(/data-fpw-solo-pdf-download/g) || []).length, 7, "the existing seven pamphlets remain present");
  assert.match(guide, /<h2 id="fpw-solo-ebook-title">Download the Complete Solo Boating Safety E-Book<\/h2>/);
  assert.match(guide, /Take the complete guide with you for offline reading\./);

  for (const publication of publications) {
    assert.match(guide, new RegExp(
      `href="<cfoutput>#fpwSoloBasePath#<\\/cfoutput>\\/downloads\\/${publication.filename.replaceAll(".", "\\.")}" download type="${publication.type.replace("+", "\\+")}"[^>]*`
      + `data-fpw-track="solo_boating_ebook_download"[^>]*`
      + `data-fpw-track-source-page="solo_boating_safety_guide"[^>]*`
      + `data-fpw-track-section="ebook_download"[^>]*`
      + `data-fpw-track-document-key="complete_solo_boating_safety_ebook"[^>]*`
      + `data-fpw-track-label="${publication.label}"[^>]*`
      + `data-fpw-track-format="${publication.format}"`
    ));
    const file = readFileSync(path.join(repositoryRoot, "downloads", publication.filename));
    assert.equal(file.subarray(0, publication.magic.length).toString("ascii"), publication.magic);
    assert.ok(file.byteLength > 100_000);
  }
});

test("complete-book analytics add the requested format without changing pamphlet fields", () => {
  assert.match(analyticsScript, /data-fpw-solo-ebook-download/);
  assert.match(analyticsScript, /var format = link\.getAttribute\("data-fpw-track-format"\)/);
  assert.match(analyticsScript, /fields\.format = format/);
  assert.doesNotMatch(analyticsScript, /preventDefault|setTimeout|sendBeacon|fetch\(/);
});

test("production IIS serves EPUB with the registered media type", () => {
  assert.match(webConfig, /<remove fileExtension="\.epub" \/>/);
  assert.match(webConfig, /<mimeMap fileExtension="\.epub" mimeType="application\/epub\+zip" \/>/);
});

test("complete-book CTA presentation is scoped, focus-visible, responsive, and omitted from print", () => {
  assert.match(stylesheet, /\.fpw-solo-ebook \{[\s\S]*?grid-template-columns: minmax\(0, 1fr\) auto;/);
  assert.match(stylesheet, /\.fpw-solo-ebook-download \{[\s\S]*?min-height: 46px;/);
  assert.match(stylesheet, /\.fpw-solo-ebook-download:focus-visible/);
  assert.match(stylesheet, /@media \(max-width: 420px\)[\s\S]*?\.fpw-solo-ebook-download \{[\s\S]*?width: 100%;/);
  assert.match(stylesheet, /@media print[\s\S]*?\.fpw-solo-ebook,[\s\S]*?display: none !important;/);
});
