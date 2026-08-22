import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
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
const mediaContact = readText("assets/press/media-contact.txt");
const mediaReadme = readText("assets/press/README.txt");
const pressKitBuilder = readText("scripts/build-press-kit.py");
const mediaKitPath = path.join(repositoryRoot, "assets/press/floatplanwizard-media-kit.zip");
const releasePdf = readBytes("assets/press/floatplanwizard-launch-press-release.pdf");
const factSheetPdf = readBytes("assets/press/floatplanwizard-fact-sheet.pdf");

const headline = "Solo Boater Builds FloatPlanWizard to Make Float Plans Easier and More Accessible to Recreational Boaters";
const currentSocialImage = "floatplanwizard-social-preview-20260730.png";
const obsoleteSocialImage = "floatplanwizard-social-preview-20260602.png";
const obsoletePressClaims = [
  /1 Month of Premium Free/i,
  /1 month of Premium included/i,
  /one month of Premium/i,
  /No credit card required/i,
  /free month/i,
  /trial month/i,
  /Membership cost is intentionally kept low/i,
  /remove the cost barrier/i,
  /cost barrier/i,
  /marine weather access for members/i
];

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

test("press pages use the current founder, time-friction, credit, pricing, and public-resource story", () => {
  const combined = `${pressPage}\n${releasePage}`;
  assert.match(releasePage, new RegExp(headline));
  assert.match(combined, /longtime recreational and solo boater/i);
  assert.match(combined, /approximately 55 years on the water/i);
  assert.match(combined, /approximately 30 years of professional web-development experience/i);
  assert.match(releasePage, /reduce the time and repetitive effort involved in creating, sharing, and monitoring a/);
  assert.match(releasePage, /Membership is free, including full trip planning and Basic float-plan sending/);
  assert.match(releasePage, /one complimentary Premium Send Credit for one complete Premium trip/);
  assert.match(releasePage, /used on the first\s+successful Premium Save &amp; Send/);
  assert.match(releasePage, /individually for \$4\.99/);
  assert.match(releasePage, /Monthly Premium for \$9\.99\/month/);
  assert.match(releasePage, /Annual Premium for \$89\/year/);
  assert.match(releasePage, /up to 21 days/);
  assert.match(
    releasePage,
    /Premium trips add\s+<strong>Active Cruise tools, Premium trip monitoring, and a private Trip page that can be\s+shared with family and shore contacts so they can follow trip status and progress<\/strong>\. Route planning and\s+Basic float-plan sending remain free\./
  );
  assert.match(releasePage, /Larry Wald, Founder/);

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
  assert.doesNotMatch(pressPage, /Product screenshots/);
  assert.match(pressPage, /Current social-preview graphic/);
});

test("all production-facing CFML sources use the current claim-neutral social image", () => {
  const staleSearch = spawnSync(
    "rg",
    ["-l", obsoleteSocialImage, "--glob", "*.cfm", "--glob", "*.cfc", "--glob", "*.html", "."],
    { cwd: repositoryRoot, encoding: "utf8" }
  );
  assert.equal(staleSearch.status, 1, staleSearch.stdout || staleSearch.stderr);

  for (const source of [pressPage, releasePage, publicReleaseCopy]) {
    assert.match(source, new RegExp(currentSocialImage.replaceAll(".", "\\.")));
    assert.doesNotMatch(source, new RegExp(obsoleteSocialImage.replaceAll(".", "\\.")));
  }
});

test("release metadata preserves the original date and identifies the current update", () => {
  assert.match(releasePage, /releasePublishedDate = "2026-06-07"/);
  assert.match(releasePage, /releaseModifiedDate = "2026-08-20"/);
  assert.match(releasePage, /For Immediate Release - June 7, 2026 &bull; Updated August 20, 2026/);
  assert.match(releasePage, /article:published_time/);
  assert.match(releasePage, /article:modified_time/);
  assert.match(releasePage, /"NewsArticle"/);
  assert.match(releasePage, /releaseSchema\["headline"\] = releaseHeading/);
  assert.match(releasePage, /releaseSchema\["datePublished"\] = releasePublishedDate/);
  assert.match(releasePage, /releaseSchema\["dateModified"\] = releaseModifiedDate/);
  assert.match(releasePage, /<link rel="canonical" href="<cfoutput>#releaseCanonical#<\/cfoutput>">/);
});

test("the public release copy stays byte-identical to the authoritative production release source", () => {
  assert.equal(publicReleaseCopy, releasePage);
});

test("the synchronized release PDF builder contains the authoritative current claims", () => {
  assert.match(pressKitBuilder, /reduce the time and repetitive effort involved in creating, sharing, and/);
  assert.match(pressKitBuilder, /one complimentary Premium Send Credit for one complete Premium trip/);
  assert.match(pressKitBuilder, /first successful Premium Save &amp; Send/);
  assert.match(pressKitBuilder, /\$4\.99/);
  assert.match(pressKitBuilder, /\$9\.99\/month/);
  assert.match(pressKitBuilder, /\$89\/year/);
  assert.match(pressKitBuilder, /up to 21 days/i);
  assert.match(
    pressKitBuilder,
    /Premium trips add <b>Active Cruise tools, Premium trip monitoring, and a private Trip page that can be /
  );
  assert.match(
    pressKitBuilder,
    /shared with family and shore contacts so they can follow trip status and progress<\/b>\. Route planning /
  );
  assert.match(pressKitBuilder, /and Basic float-plan sending remain free\./);
  assert.match(pressKitBuilder, /Larry Wald, Founder/);
  for (const obsoleteClaim of obsoletePressClaims) {
    assert.doesNotMatch(pressKitBuilder, obsoleteClaim);
  }
});

test("the fact-sheet builder contains the current founder, pricing, and credit model", () => {
  assert.match(pressKitBuilder, /Larry Wald, Founder/);
  assert.match(pressKitBuilder, /approximately 55 years on the water/i);
  assert.match(pressKitBuilder, /approximately 30 years of professional web-development experience/i);
  assert.match(pressKitBuilder, /complimentary Premium Send Credit/i);
  assert.match(pressKitBuilder, /first successful Premium Save &amp; Send/i);
  assert.match(pressKitBuilder, /Single Premium trip: \$4\.99/i);
  assert.match(pressKitBuilder, /Monthly Premium: \$9\.99\/month/i);
  assert.match(pressKitBuilder, /Annual Premium: \$89\/year/i);
  assert.match(pressKitBuilder, /up to 21 days/i);
  assert.match(pressKitBuilder, /Basic float-plan sending/i);
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

test("the cleaned media kit contains only approved current assets", () => {
  const inventory = execFileSync("unzip", ["-Z1", mediaKitPath], { encoding: "utf8" })
    .trim()
    .split(/\r?\n/)
    .sort();
  assert.deepEqual(inventory, [
    "README.txt",
    "floatplanwizard-fact-sheet.pdf",
    "floatplanwizard-launch-press-release.pdf",
    "floatplanwizard-logo-color.png",
    currentSocialImage,
    "media-contact.txt"
  ].sort());

  for (const removed of [
    "floatplanwizard-logo-white.png",
    "fpw-homepage.png",
    "fpw-active-cruise.png",
    "fpw-shared-trip-page.png"
  ]) {
    assert.ok(!inventory.includes(removed), `${removed} must not be packaged`);
  }

  const packagedSocial = execFileSync("unzip", ["-p", mediaKitPath, currentSocialImage], { maxBuffer: 2_000_000 });
  assert.equal(sha256(packagedSocial), sha256(readBytes(`assets/images/social/${currentSocialImage}`)));
});

test("distributed press text contains no obsolete offer, localhost, staging, or placeholders", () => {
  const distributedText = [
    pressPage,
    releasePage,
    publicReleaseCopy,
    mediaContact,
    mediaReadme,
    pressKitBuilder
  ].join("\n");
  for (const obsoleteClaim of obsoletePressClaims) {
    assert.doesNotMatch(distributedText, obsoleteClaim);
  }
  assert.doesNotMatch(distributedText, /localhost|127\.0\.0\.1|staging(?:\.|-|\/)|\bTODO\b|\bTBD\b|lorem ipsum/i);
});
