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

test("lock detail keeps the sidebar resources in order after the Trip Planner card", () => {
  const planIndex = page.indexOf("<h3>Plan your Great Loop trip</h3>");
  const resourcesIndex = page.indexOf("<h3 id=\"fpwLockRelatedResourcesTitle\">Related Safety Resources</h3>");
  const officialIndex = page.indexOf("<h3>Official Source</h3>");

  assert.ok(planIndex >= 0);
  assert.ok(resourcesIndex > planIndex);
  assert.ok(officialIndex > resourcesIndex);
  assert.equal(count(page, /id="fpwLockRelatedResourcesTitle"/g), 1);
  assert.match(page, /aria-labelledby="fpwLockRelatedResourcesTitle"/);
});

test("lock detail has exact main and sidebar Trip Planner copy in the approved positions", () => {
  const mapIndex = page.indexOf("class=\"fpw-lock-panel fpw-lock-location-map-card\"");
  const mainCtaIndex = page.indexOf("class=\"fpw-lock-panel fpw-lock-detail-trip-cta\"");
  const detailGridIndex = page.indexOf("class=\"fpw-lock-detail-grid\"");

  assert.ok(mapIndex >= 0);
  assert.ok(mainCtaIndex > mapIndex);
  assert.ok(detailGridIndex > mainCtaIndex);
  assert.match(page, /<h3 id="fpwLockDetailTripCtaTitle">Planning your Great Loop trip\?<\/h3>/);
  assert.match(page, /Use the free FPW Trip Planner to plot your route and stops, calculate mileage, travel time, fuel, reserve, and cost, and adjust speed and weather assumptions\./);
  assert.match(page, /<h3>Plan your Great Loop trip<\/h3>/);
  assert.match(page, /Plot your route and stops, then calculate mileage, travel time, fuel, reserve, and cost with the free FPW Trip Planner\./);
  assert.equal(count(page, />Plan My Trip Free<\/span>/g), 2);
  assert.equal(count(page, /Free account required to save your trip\./g), 2);
  assert.equal(count(page, /aria-label="Open the free FloatPlanWizard Trip Planner"/g), 2);
  assert.doesNotMatch(page, /<h3>Plan With FPW<\/h3>|>Plan Your Route<\/a>/);
});

test("both CTA placements preserve one event contract and transfer no lock context", () => {
  assert.equal(count(page, /data-fpw-action-cta/g), 2);
  assert.equal(count(page, /data-fpw-track="great_loop_locks_plan_route_cta_click"/g), 2);
  assert.equal(count(page, /data-fpw-track-source-page="great_loop_locks"/g), 2);
  assert.equal(count(page, /data-fpw-track-cta-type="plan_route"/g), 2);
  assert.equal(count(page, /data-fpw-track-section="lock_detail_main"/g), 1);
  assert.equal(count(page, /data-fpw-track-section="lock_detail_sidebar"/g), 1);
  assert.match(page, /fpwLockDetailCtaDestinationUrl = request\.fpwBase & \(fpwLockDetailCtaSignedIn \? "\/app\/dashboard\.cfm" : "\/app\/join\.cfm"\);/);
  assert.match(page, /fpwLockDetailCtaAuthState = fpwLockDetailCtaSignedIn \? "signed_in" : "signed_out";/);
  assert.match(page, /fpwLockDetailCtaDestinationKey = fpwLockDetailCtaSignedIn \? "dashboard" : "join";/);
  assert.match(page, /assets\/js\/fpw-action-cta\.js\?v=20260825-lock-detail-trip-planner/);

  for (const section of ["lock_detail_main", "lock_detail_sidebar"]) {
    const sectionIndex = page.indexOf(`data-fpw-track-section="${section}"`);
    const linkStart = page.lastIndexOf("<a", sectionIndex);
    const linkEnd = page.indexOf("</a>", sectionIndex);
    const linkMarkup = page.slice(linkStart, linkEnd);
    assert.doesNotMatch(linkMarkup, /slug|lockItem|latitude|longitude|coordinates|map_state|data-lat|data-lng/i);
  }
});

test("CTA claims remain within supported planner capabilities", () => {
  const ctaBlocks = page.slice(
    page.indexOf("class=\"fpw-lock-panel fpw-lock-detail-trip-cta\""),
    page.indexOf("class=\"fpw-lock-panel fpw-lock-related-resources\"")
  );
  assert.doesNotMatch(ctaBlocks, /automated|optimized weather routing|side-by-side|certified marine navigation|official charts|lock-status guarantee|emergency dispatch|rescue service|continuous vessel tracking/i);
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

test("contextual resource links remain ordinary untracked links", () => {
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
  assert.match(css, /\.fpw-lock-detail-trip-cta\s*\{[\s\S]*?display:\s*flex;[\s\S]*?justify-content:\s*space-between;/);
  assert.match(css, /\.fpw-lock-detail-trip-cta \.fpw-cta:hover,[\s\S]*?\.fpw-lock-plan-panel \.fpw-cta:focus-visible\s*\{[\s\S]*?color:\s*#01141c;/);
  assert.match(css, /\.fpw-lock-detail-trip-cta \.fpw-cta:focus-visible,[\s\S]*?outline:\s*3px solid #ffffff;/);
  assert.match(css, /@media \(max-width:\s*1180px\)[\s\S]*?\.fpw-lock-detail-rail \.fpw-lock-plan-panel\s*\{[\s\S]*?display:\s*none;/);
  assert.match(css, /@media \(max-width:\s*760px\)[\s\S]*?\.fpw-lock-detail-trip-cta\s*\{[\s\S]*?flex-direction:\s*column;/);
  assert.match(page, /great-loop-locks\.css\?v=20260825-lock-detail-trip-planner-cta/);
});
