import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));
const readText = (relativePath) => readFileSync(path.join(repositoryRoot, relativePath), "utf8");
const readBytes = (relativePath) => readFileSync(path.join(repositoryRoot, relativePath));
const pressPage = readText("press.cfm");
const releasePage = readText("press/floatplanwizard-launches.cfm");
const publicReleaseCopy = readText("assets/images/press/press/floatplanwizard-launches.cfm");
const pressStyles = readText("assets/css/press.css");
const mediaKitPath = path.join(repositoryRoot, "assets/press/floatplanwizard-media-kit.zip");

const headline = "Solo Boater Builds FloatPlanWizard to Make Float Plans Easier and More Accessible to Recreational Boaters";
const obsoletePressClaims = [
  /1 Month of Premium Free/i,
  /one month of Premium/i,
  /free month/i,
  /trial month/i,
  /Membership cost is intentionally kept low/i,
  /marine weather access for members/i
];

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

test("press pages use the current founder, membership, and public-resource story", () => {
  const combined = `${pressPage}\n${releasePage}`;
  assert.match(releasePage, new RegExp(headline));
  assert.match(combined, /longtime recreational and solo boater/i);
  assert.match(combined, /approximately 55 years on the water/i);
  assert.match(combined, /approximately 30 years of professional web-development experience/i);
  assert.match(releasePage, /FloatPlanWizard membership is free/);
  assert.match(releasePage, /Basic Save\s*&amp;\s*Send without purchasing Premium/);
  assert.match(releasePage, /one complimentary Premium Send Credit for one complete Premium trip/);
  assert.match(releasePage, /individually for \$4\.99/);
  assert.match(releasePage, /Monthly or Annual Premium membership/);
  assert.match(releasePage, /up to 21 days/);

  for (const destination of [
    "/solo-boating-safety-guide/",
    "/shore-contact-overdue-boater/",
    "/boat-fuel-calculator/",
    "/great-loop/locks/"
  ]) {
    assert.match(combined, new RegExp(destination.replaceAll("/", "\\/")));
  }

  for (const obsoleteClaim of obsoletePressClaims) {
    assert.doesNotMatch(combined, obsoleteClaim);
  }
  assert.doesNotMatch(pressPage, /One-page fact sheet/);
  assert.match(pressPage, /Fact sheet PDF/);
});

test("release metadata preserves the original date and identifies the August update", () => {
  assert.match(releasePage, /releasePublishedDate = "2026-06-07"/);
  assert.match(releasePage, /releaseModifiedDate = "2026-08-15"/);
  assert.match(releasePage, /For Immediate Release - June 7, 2026 &bull; Updated August 15, 2026/);
  assert.match(releasePage, /article:published_time/);
  assert.match(releasePage, /article:modified_time/);
  assert.match(releasePage, /"NewsArticle"/);
  assert.match(releasePage, /releaseSchema\["headline"\] = releaseHeading/);
  assert.match(releasePage, /releaseSchema\["datePublished"\] = releasePublishedDate/);
  assert.match(releasePage, /releaseSchema\["dateModified"\] = releaseModifiedDate/);
  assert.match(releasePage, /<link rel="canonical" href="<cfoutput>#releaseCanonical#<\/cfoutput>">/);
});

test("the public release copy stays byte-identical to the production release source", () => {
  assert.equal(publicReleaseCopy, releasePage);
});

test("press pages use the updated stylesheet and long fact values wrap safely", () => {
  for (const source of [pressPage, releasePage, publicReleaseCopy]) {
    assert.match(source, /press\.css\?v=20260815-membership-update/);
  }
  assert.match(pressStyles, /\.fpw-press-fact span \{\s*overflow-wrap: anywhere;/);
});

test("release actions expose the real PDF and media-kit downloads", () => {
  for (const destination of [
    "/assets/press/floatplanwizard-launch-press-release.pdf",
    "/assets/press/floatplanwizard-media-kit.zip"
  ]) {
    assert.equal((releasePage.match(new RegExp(destination.replaceAll("/", "\\/"), "g")) || []).length, 2);
  }
  assert.doesNotMatch(releasePage, /Download PDF <small>Coming soon<\/small>/);
  assert.doesNotMatch(releasePage, /Download Media Kit <small>Coming soon<\/small>/);
});

test("press PDFs are valid files and the media kit packages their exact bytes", () => {
  for (const filename of ["floatplanwizard-launch-press-release.pdf", "floatplanwizard-fact-sheet.pdf"]) {
    const standalone = readBytes(`assets/press/${filename}`);
    assert.equal(standalone.subarray(0, 4).toString("ascii"), "%PDF");
    assert.ok(standalone.length > 10_000, `${filename} should contain the complete rendered press document`);
    const packaged = execFileSync("unzip", ["-p", mediaKitPath, filename], { maxBuffer: 3_000_000 });
    assert.equal(sha256(packaged), sha256(standalone), `${filename} in the media kit must match the public PDF`);
  }
});

test("the media kit contains the current full-page homepage image", () => {
  const homepage = execFileSync("unzip", ["-p", mediaKitPath, "fpw-homepage.png"], { maxBuffer: 15_000_000 });
  assert.equal(homepage.subarray(1, 4).toString("ascii"), "PNG");
  assert.equal(homepage.readUInt32BE(16), 2790);
  assert.equal(homepage.readUInt32BE(20), 11334);
});
