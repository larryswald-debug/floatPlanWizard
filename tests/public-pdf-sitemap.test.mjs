import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));
const sitemap = readFileSync(path.join(repositoryRoot, "sitemap.xml"), "utf8");
const robots = readFileSync(path.join(repositoryRoot, "robots.txt"), "utf8");

const publicPdfs = [
  { path: "/downloads/floatplanwizard-solo-boating-safety-guide.pdf", lastmod: "2026-08-14" },
  { path: "/downloads/solo-boater-trip-planning-guide.pdf", lastmod: "2026-08-10" },
  { path: "/downloads/solo-boater-vessel-information-guide.pdf", lastmod: "2026-08-10" },
  { path: "/downloads/solo-boater-personal-safety-guide.pdf", lastmod: "2026-08-10" },
  { path: "/downloads/solo-boater-weather-guide.pdf", lastmod: "2026-08-10" },
  { path: "/downloads/solo-boater-communications-guide.pdf", lastmod: "2026-08-10" },
  { path: "/downloads/solo-boater-boat-readiness-guide.pdf", lastmod: "2026-08-10" },
  { path: "/downloads/solo-boater-precautions-guide.pdf", lastmod: "2026-08-10" },
  { path: "/downloads/uscg-float-plan.pdf", lastmod: "2026-07-21" },
  { path: "/assets/press/floatplanwizard-fact-sheet.pdf", lastmod: "2026-08-15" },
  { path: "/assets/press/floatplanwizard-launch-press-release.pdf", lastmod: "2026-08-15" }
];

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

test("every confirmed public PDF appears exactly once with its publication date", () => {
  for (const pdf of publicPdfs) {
    const url = `https://floatplanwizard.com${pdf.path}`;
    const escapedUrl = escapeRegExp(url);
    assert.equal((sitemap.match(new RegExp(escapedUrl, "g")) || []).length, 1, `${url} must appear exactly once`);
    assert.match(
      sitemap,
      new RegExp(`<url>\\s*<loc>${escapedUrl}<\\/loc>\\s*<lastmod>${pdf.lastmod}<\\/lastmod>\\s*<\\/url>`),
      `${url} must use the expected sitemap formatting and lastmod`
    );
  }

  const sitemapPdfUrls = [...sitemap.matchAll(/<loc>(https:\/\/floatplanwizard\.com\/[^<]+\.pdf)<\/loc>/g)].map((match) => match[1]);
  assert.deepEqual(sitemapPdfUrls, publicPdfs.map((pdf) => `https://floatplanwizard.com${pdf.path}`));
  assert.doesNotMatch(sitemap, /<(?:changefreq|priority)>/);
});

test("the sitemap PDF set matches the published files and excludes build or generated-user artifacts", () => {
  const downloadPdfs = readdirSync(path.join(repositoryRoot, "downloads"))
    .filter((filename) => filename.endsWith(".pdf"))
    .map((filename) => `/downloads/${filename}`)
    .sort();
  const expectedDownloads = publicPdfs.filter((pdf) => pdf.path.startsWith("/downloads/")).map((pdf) => pdf.path).sort();
  assert.deepEqual(downloadPdfs, expectedDownloads);

  for (const pdf of publicPdfs) {
    const file = readFileSync(path.join(repositoryRoot, pdf.path));
    assert.equal(file.subarray(0, 4).toString("ascii"), "%PDF", `${pdf.path} must be a PDF file`);
  }
  assert.doesNotMatch(sitemap, /\/(?:api|publishing|tmp|floatplans)\//i);
});

test("robots permits each sitemap PDF without opening the downloads directory", () => {
  assert.equal((robots.match(/^Disallow: \/downloads\/$/gm) || []).length, 1);
  assert.equal((robots.match(/^Allow: \/assets\/$/gm) || []).length, 1);
  assert.doesNotMatch(robots, /^Allow: \/downloads\/$/m);

  for (const pdf of publicPdfs.filter((entry) => entry.path.startsWith("/downloads/"))) {
    const exactRule = new RegExp(`^Allow: ${escapeRegExp(pdf.path)}$`, "gm");
    assert.equal((robots.match(exactRule) || []).length, 1, `${pdf.path} needs one exact robots allowance`);
  }
});
