import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const testsDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(testsDir, "..");
const page = fs.readFileSync(path.join(root, "app/great-loop-lock.cfm"), "utf8");
const css = fs.readFileSync(path.join(root, "assets/css/great-loop-locks.css"), "utf8");

function count(value, pattern) {
  return (value.match(pattern) || []).length;
}

test("lock detail inserts the safety card between Plan With FPW and Official Source", () => {
  const planIndex = page.indexOf("<h3>Plan With FPW</h3>");
  const resourcesIndex = page.indexOf("<h3 id=\"fpwLockRelatedResourcesTitle\">Related Safety Resources</h3>");
  const officialIndex = page.indexOf("<h3>Official Source</h3>");

  assert.ok(planIndex >= 0);
  assert.ok(resourcesIndex > planIndex);
  assert.ok(officialIndex > resourcesIndex);
  assert.equal(count(page, /id="fpwLockRelatedResourcesTitle"/g), 1);
  assert.match(page, /aria-labelledby="fpwLockRelatedResourcesTitle"/);
});

test("safety resources use the approved copy, canonical routes, and existing icons", () => {
  assert.match(page, /Solo Boating Safety Guide/);
  assert.match(page, /Running the Loop solo\? Review practical preparation, communications, self-recovery, and trip-planning guidance before departure\./);
  assert.match(page, /request\.fpwBase & '\/solo-boating-safety-guide\/'/);
  assert.match(page, /renderFpwNavIcon\("kayak", "fpw-lock-related-resource__icon-svg"\)/);

  assert.match(page, /Shore Contact Guide/);
  assert.match(page, /Leaving a float plan with someone ashore\? Make sure they know what to do if you miss a check-in or become overdue\./);
  assert.match(page, /request\.fpwBase & '\/shore-contact-overdue-boater\/'/);
  assert.match(page, /renderFpwNavIcon\("checklist", "fpw-lock-related-resource__icon-svg"\)/);
  assert.equal(count(page, /class="fpw-lock-related-resource"/g), 2);
});

test("Continue planning is immediately before the pager and uses confirmed destinations", () => {
  const continueIndex = page.indexOf("class=\"fpw-lock-continue-planning\"");
  const pagerIndex = page.indexOf("class=\"fpw-lock-panel fpw-lock-nav-pager\"");
  const pagerSectionIndex = page.lastIndexOf("<section", pagerIndex);

  assert.ok(continueIndex >= 0);
  assert.ok(pagerIndex > continueIndex);
  assert.match(page.slice(continueIndex, pagerSectionIndex), /<\/p>\s*$/);
  assert.match(page, /<strong>Continue planning:<\/strong>\s+Check <a href="[^"]+">Marine Weather<\/a>, estimate your trip with the <a href="[^"]+">Boat Fuel Calculator<\/a>, or review the <a href="[^"]+">Solo Boating Safety Guide<\/a>\./);
  assert.match(page, /request\.fpwBase & '\/app\/weather\.cfm'/);
  assert.match(page, /request\.fpwBase & '\/boat-fuel-calculator\/'/);
});

test("existing Plan Your Route CTA remains unchanged and contextual links are ordinary links", () => {
  assert.match(page, /class="fpw-lock-btn fpw-lock-btn--primary fpw-lock-btn--full" href="<cfoutput>#request\.fpwBase#<\/cfoutput>\/app\/join\.cfm">Plan Your Route<\/a>/);
  const resourcesBlock = page.slice(
    page.indexOf("class=\"fpw-lock-panel fpw-lock-related-resources\""),
    page.indexOf("<h3>Official Source</h3>")
  );
  const continueBlock = page.slice(
    page.indexOf("class=\"fpw-lock-continue-planning\""),
    page.indexOf("class=\"fpw-lock-panel fpw-lock-nav-pager\"")
  );
  assert.doesNotMatch(resourcesBlock + continueBlock, /data-fpw-track|onclick=|javascript:/i);
});

test("page-scoped CSS provides compact rows, visible focus, and wrapping", () => {
  assert.match(css, /\.fpw-lock-related-resource\s*\{[\s\S]*?display:\s*grid;[\s\S]*?grid-template-columns:\s*34px minmax\(0, 1fr\) auto;/);
  assert.match(css, /\.fpw-lock-related-resource__icon-svg\s*\{[\s\S]*?width:\s*34px;[\s\S]*?height:\s*34px;/);
  assert.match(css, /\.fpw-lock-related-resource:focus-visible\s*\{[\s\S]*?outline:\s*2px solid #67e8f9;/);
  assert.match(css, /\.fpw-lock-continue-planning\s*\{[\s\S]*?margin:\s*0;[\s\S]*?line-height:\s*1\.55;/);
  assert.match(css, /\.fpw-lock-continue-planning a:focus-visible\s*\{[\s\S]*?outline:\s*2px solid #67e8f9;/);
  assert.match(page, /great-loop-locks\.css\?v=20260814-detail-context-links-v3/);
});
