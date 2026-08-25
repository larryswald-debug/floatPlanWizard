import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const testsDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(testsDir, "..");
const partial = fs.readFileSync(path.join(root, "partials/fpw-conversion-landing.cfm"), "utf8");
const homepage = fs.readFileSync(path.join(root, "index.cfm"), "utf8");
const css = fs.readFileSync(path.join(root, "assets/css/fpw-conversion-landing.css"), "utf8");
const landingJs = fs.readFileSync(path.join(root, "assets/js/fpw-conversion-landing.js"), "utf8");
const entitlement = fs.readFileSync(path.join(root, "api/v1/MemberEntitlementService.cfc"), "utf8");
const routeModal = fs.readFileSync(path.join(root, "includes/modals/route_generator_modal.cfm"), "utf8");
const routeBuilderJs = fs.readFileSync(path.join(root, "assets/js/app/dashboard/routebuilder.js"), "utf8");
const routeBuilderApi = fs.readFileSync(path.join(root, "api/v1/routeBuilder.cfc"), "utf8");
const dashboardJs = fs.readFileSync(path.join(root, "assets/js/app/dashboard.js"), "utf8");
const followPage = fs.readFileSync(path.join(root, "app/follow.cfm"), "utf8");
const voyageApi = fs.readFileSync(path.join(root, "api/v1/voyage.cfc"), "utf8");

const expected = {
  headline: "Plan the trip. Share the plan. Stay connected.",
  body: "Use the free Trip Planner to plot your route and stops and calculate mileage, travel time, fuel, reserve, and cost using your speed and weather assumptions. When departure approaches, turn your saved trip into a float plan and share a private Trip Page with family and friends.",
  primary: "Plan Your Trip Free",
  primaryAccessibleName: "Open the free FloatPlanWizard Trip Planner",
  secondary: "See What Family Sees",
  benefits: [
    "No credit card required",
    "Mileage, time, fuel, and cost",
    "Float plan when you depart",
    "No account for followers"
  ],
  disclaimer: "FloatPlanWizard organizes and shares trip information. It is not a rescue or emergency-dispatch service."
};

function heroBlock(source = partial) {
  const start = source.indexOf('<section class="fpw-hero"');
  const end = source.indexOf("</section>", start);
  assert.ok(start >= 0 && end > start, "homepage hero block is missing");
  return source.slice(start, end + "</section>".length);
}

test("homepage hero uses the exact approved planning-first copy", () => {
  const hero = heroBlock();

  assert.match(hero, new RegExp(`<h1 id="fpwHeroTitle">${expected.headline.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}</h1>`));
  assert.ok(hero.includes(`<p>${expected.body}</p>`));
  assert.equal((hero.match(/Plan Your Trip Free/g) || []).length, 2);
  assert.ok(hero.includes(`aria-label="${expected.primaryAccessibleName}"`));
  assert.ok(hero.includes(`data-fpw-track-label="${expected.primary}"`));
  assert.ok(hero.includes(`data-fpw-track="homepage_hero_primary_cta_click"`));
  assert.ok(hero.includes(`data-fpw-track-section="hero"`));
  assert.ok(hero.includes('href="<cfoutput>#landingBasePath#</cfoutput>/app/join.cfm"'));
  assert.match(hero, /<use href="#fpw-i-pencil"><\/use>/);
});

test("secondary CTA, benefits, and disclaimer retain their approved contracts", () => {
  const hero = heroBlock();
  const secondary = hero.match(/<a class="fpw-btn fpw-btn-secondary"[\s\S]*?<\/a>/)?.[0] || "";
  const trustStart = hero.indexOf('<div class="fpw-trust-row"');
  const trustEnd = hero.indexOf("</div>\n\n          <p class=\"fpw-hero-disclaimer\"", trustStart);
  const trust = hero.slice(trustStart, trustEnd);

  assert.ok(secondary.includes('href="#fpwProductPreview"'));
  assert.ok(secondary.includes('data-fpw-open-preview="follow"'));
  assert.ok(secondary.includes('data-fpw-track="homepage_hero_secondary_cta_click"'));
  assert.ok(secondary.includes(`data-fpw-track-label="${expected.secondary}"`));
  assert.ok(secondary.includes(`>${expected.secondary}</a>`));
  assert.match(secondary, /<use href="#fpw-i-play"><\/use>/);

  let previousIndex = -1;
  for (const benefit of expected.benefits) {
    const benefitIndex = trust.indexOf(`<span>${benefit}</span>`);
    assert.ok(benefitIndex > previousIndex, `${benefit} is missing or out of order`);
    previousIndex = benefitIndex;
  }
  assert.equal((trust.match(/class="fpw-check-dot"/g) || []).length, 4);
  assert.ok(hero.includes(`<p class="fpw-hero-disclaimer">${expected.disclaimer}</p>`));
});

test("hero avoids prohibited marketing claims and leaves later homepage sections untouched", () => {
  const hero = heroBlock();
  const nonHero = partial.replace(hero, "");

  assert.doesNotMatch(hero, /Route Generator|weather routing|weather optimization|automatic routing|side-by-side comparison|guarantee(?:d|s)? a safe return|continuous(?:ly)? track/i);
  assert.doesNotMatch(hero, /Plan your cruise\. Share the journey\. Return safely\.|Build your route, organize your vessel and crew/);
  assert.doesNotMatch(nonHero, /Plan the trip\. Share the plan\. Stay connected\.|Use the free Trip Planner to plot your route and stops/);
  assert.match(nonHero, /Everything you need from planning to safe return\./);
  assert.match(nonHero, /Built by a Solo Boater/);
  assert.match(nonHero, /See how the whole trip stays connected\./);
  assert.match(nonHero, /homepage_final_cta_click[\s\S]*?data-fpw-track-label="Plan Your Trip"/);
});

test("approved hero claims are supported by current implementation contracts", () => {
  assert.match(entitlement, /access\.canUsePlanningTools = true;/);
  assert.match(partial, /<h3>Free Membership<\/h3><div class="fpw-price">\$0<\/div><p>Full planning and Basic sending\.<\/p>/);
  assert.match(routeModal, /id="routeGenMyRouteStartWaypointSelect"/);
  assert.match(routeModal, /id="routeGenMyRouteEndWaypointSelect"/);
  assert.match(routeModal, /id="routeGenEstimatedFuel"/);
  assert.match(routeModal, /id="routeGenReservePct"/);
  assert.match(routeModal, /id="routeGenFuelPricePerGal"/);
  assert.match(routeModal, /id="routeGenWeatherFactorPct"/);
  assert.match(routeBuilderJs, /totalHours/);
  assert.match(routeBuilderJs, /fuelCostEstimate/);
  assert.match(routeBuilderJs, /routegen_generate/);
  assert.match(routeBuilderApi, /\["dist_nm", "DIST_NM", "distance_nm", "DISTANCE_NM"\]/);
  assert.match(routeBuilderApi, /INSERT INTO route_instances/);
  assert.match(routeBuilderApi, /'Draft'/);
  assert.match(dashboardJs, /buildFloatPlansFromRoute/);
  assert.match(followPage, /Family and Friends/);
  assert.match(voyageApi, /followPath = fpwBasePath & "\/app\/follow\.cfm\?slug="/);
  assert.match(voyageApi, /canReadStream\(streamRow, arguments\.shareToken, isOwner\)/);
});

test("existing CSS and analytics implementation retain the hero presentation and event contract", () => {
  assert.match(css, /\.fpw-hero\s*\{[\s\S]*?min-height:\s*360px;[\s\S]*?background:\s*#04152f;/);
  assert.match(css, /\.fpw-hero-copy h1\s*\{[\s\S]*?font-size:\s*clamp\(38px, 4\.1vw, 48px\);/);
  assert.match(css, /\.fpw-hero \.fpw-btn-primary\s*\{[\s\S]*?color:\s*#071529;/);
  assert.match(homepage, /fpw-conversion-landing\.css\?v=20260825-homepage-trip-planner-hero/);
  assert.match(css, /\.fpw-trust-row\s*\{[\s\S]*?grid-template-columns:\s*repeat\(4, minmax\(0, 1fr\)\);/);
  assert.match(css, /@media \(max-width:\s*720px\)[\s\S]*?\.fpw-hero-copy h1\s*\{[\s\S]*?font-size:\s*31px;/);
  assert.match(css, /@media \(max-width:\s*720px\)[\s\S]*?\.fpw-trust-row\s*\{[\s\S]*?grid-template-columns:\s*repeat\(2, minmax\(0, 1fr\)\);/);
  assert.match(landingJs, /trackEvent\(target\.getAttribute\('data-fpw-track'\),\s*\{[\s\S]*?label:\s*target\.getAttribute\('data-fpw-track-label'\)/);
  assert.equal((heroBlock().match(/data-fpw-track="homepage_hero_primary_cta_click"/g) || []).length, 1);
  assert.equal((heroBlock().match(/data-fpw-track="homepage_hero_secondary_cta_click"/g) || []).length, 1);
  assert.doesNotMatch(heroBlock(), /data-fpw-action-cta|fpw_signup_attribution|route_id|vessel_id|latitude|longitude/);
});
