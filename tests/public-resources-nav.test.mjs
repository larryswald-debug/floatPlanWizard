import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));
const read = (relativePath) => readFileSync(path.join(repositoryRoot, relativePath), "utf8");

const topNav = read("includes/top_nav.cfm");
const topNavCss = read("assets/css/top-nav.css");
const footer = read("includes/footer.cfm");
const homepage = read("partials/fpw-conversion-landing.cfm");
const homepageCss = read("assets/css/fpw-conversion-landing.css");
const webConfig = read("web.config");

function count(source, pattern) {
  return [...source.matchAll(pattern)].length;
}

test("public Resources replaces Tools between Great Loop and Pricing without changing member Tools", () => {
  const greatLoopIndex = topNav.indexOf('fpw-dropdown--mega');
  const memberToolsIndex = topNav.indexOf('fpw-dropdown--tools');
  const resourcesIndex = topNav.indexOf('fpw-dropdown--resources');
  const pricingIndex = topNav.indexOf('<span>Pricing</span>');

  assert.ok(greatLoopIndex > -1);
  assert.ok(memberToolsIndex > greatLoopIndex);
  assert.ok(resourcesIndex > memberToolsIndex);
  assert.ok(pricingIndex > resourcesIndex);
  assert.match(
    topNav,
    /<cfif topNavIsLoggedIn>\s+<div class="fpw-dropdown fpw-dropdown--tools"[\s\S]*?<cfelse>\s+<div class="fpw-dropdown fpw-dropdown--resources"/
  );
  assert.equal(count(topNav, /fpw-dropdown--resources/g), 1);

  const memberToolsBlock = topNav.slice(memberToolsIndex, topNav.indexOf("<cfelse>", memberToolsIndex));
  assert.match(memberToolsBlock, /Float Plan Basics/);
  assert.match(memberToolsBlock, /#topNavBasePath#\/why-use-a-float-plan\.cfm/);
});

test("Resources uses the approved two-column taxonomy with one float-plan resource", () => {
  const resourcesBlock = topNav.slice(
    topNav.indexOf('<div class="fpw-dropdown fpw-dropdown--resources"'),
    topNav.indexOf('<span>Pricing</span>')
  );

  assert.ok(resourcesBlock.indexOf("Featured Guide") < resourcesBlock.indexOf("Planning Tools"));
  assert.ok(resourcesBlock.indexOf("Planning Tools") < resourcesBlock.indexOf("Boating Resources"));
  assert.match(resourcesBlock, /Shore Contact Guide/);
  assert.match(resourcesBlock, /What to do when a boater misses a check-in or expected return\./);
  assert.match(resourcesBlock, /Read the Guide/);
  assert.match(resourcesBlock, /Fuel Calculator/);
  assert.match(resourcesBlock, /Marine Weather/);
  assert.match(resourcesBlock, /Why Use a Float Plan/);
  assert.match(resourcesBlock, /href="#topNavHowHref#"/);
  assert.match(resourcesBlock, /#topNavBasePath#\/faq\//);
  assert.equal(count(resourcesBlock, /#topNavBasePath#\/why-use-a-float-plan\.cfm/g), 1);
  assert.doesNotMatch(resourcesBlock, /Float Plan Basics/);
  assert.doesNotMatch(resourcesBlock, /Delayed vs\.|Solo Boater|Captain and Shore Contact Checklist/);
});

test("Resources uses one route map and accessible item-level selected states", () => {
  assert.match(topNav, /topNavResourceRouteMap = \[/);
  assert.match(topNav, /"pattern" = "\/shore-contact-overdue-boater", "active" = "resources-shore-contact-guide"/);
  assert.match(topNav, /"pattern" = "\/why-use-a-float-plan", "active" = "resources-why-float-plan"/);
  assert.match(topNav, /"pattern" = "\/faq\/", "active" = "resources-faq"/);
  assert.match(topNav, /topNavResourcesActive = listFindNoCase\(/);
  assert.match(topNav, /topNavShoreContactGuideActive> is-active/);
  assert.match(topNav, /topNavWhyFloatPlanActive> is-active/);
  assert.match(topNav, /topNavFaqActive> is-active/);
  assert.match(topNav, /topNavFuelActive> is-active/);
  assert.match(topNav, /topNavWeatherActive> is-active/);
  assert.match(topNav, /aria-controls="fpwResourcesMenu"/);
  assert.match(topNav, /id="fpwResourcesMenu" role="menu"/);
  assert.equal(count(topNav, /id="fpwResourceFeaturedTitle"/g), 1);
  assert.equal(count(topNav, /id="fpwPlanningToolsTitle"/g), 1);
  assert.equal(count(topNav, /id="fpwBoatingResourcesTitle"/g), 1);
});

test("guide analytics remain one-event, non-sensitive, and navigation-independent", () => {
  assert.equal(count(topNav, /data-fpw-nav-track="public_nav_shore_contact_guide_click"/g), 1);
  for (const field of ["source_page", "nav_location", "menu_group", "label", "destination_key", "auth_state"]) {
    assert.equal(topNav.includes(`${field}:`), true, `Missing analytics field: ${field}`);
  }
  assert.match(topNav, /data-fpw-nav-track-location="public_header"/);
  assert.match(topNav, /data-fpw-nav-track-menu-group="resources"/);
  assert.match(topNav, /data-fpw-nav-track-auth-state="signed_out"/);
  assert.doesNotMatch(topNav, /public_nav_resources_open/);

  const trackingFunction = topNav.match(/function trackPublicNavClick\(link\) \{[\s\S]*?\n      \}/)?.[0] ?? "";
  assert.match(trackingFunction, /try \{/);
  assert.match(trackingFunction, /catch \(error\) \{\}/);
  assert.doesNotMatch(trackingFunction, /preventDefault/);
  assert.match(topNav, /data-fpw-nav-bound/);
});

test("shared CSS provides the spacious layout, public fit, focus states, and closed-drawer containment", () => {
  assert.match(topNavCss, /\.fpw-dropdown--resources > \.fpw-dropdown-menu \{[\s\S]*?width: min\(820px, calc\(100vw - 32px\)\);[\s\S]*?padding: 32px;/);
  assert.match(topNavCss, /\.fpw-resources-grid \{[\s\S]*?grid-template-columns: minmax\(0, 0\.44fr\) minmax\(0, 0\.56fr\);[\s\S]*?gap: 36px;/);
  assert.match(topNavCss, /\.fpw-resource-feature-link:focus-visible/);
  assert.match(topNavCss, /\.fpw-resource-link:focus-visible/);
  assert.match(topNavCss, /@media \(max-width: 1320px\) and \(min-width: 1051px\)/);
  assert.match(topNavCss, /\.fpw-site-header:not\(\.fpw-site-header--logged-in\) \.fpw-nav-link/);
  assert.match(topNavCss, /\.fpw-site-header:not\(\.fpw-site-header--logged-in\) \.fpw-nav-menu \{\s+transform: none;\s+transition: opacity 180ms ease, visibility 180ms ease;/);
  assert.match(topNavCss, /\.fpw-resources-grid \{\s+grid-template-columns: 1fr;/);
  assert.match(topNavCss, /\.fpw-dropdown--resources:not\(\.is-open\):focus-within > \.fpw-dropdown-menu \{\s+display: none;/);
  assert.match(topNav, /"\(max-width: 1023px\)" : "\(max-width: 1050px\)"/);
});

test("footer and homepage retain their single approved guide links", () => {
  assert.equal(count(footer, /shore-contact-overdue-boater\//g), 1);
  assert.match(
    footer,
    /<nav class="fpw-footer-col fpw-footer-plan"[\s\S]*?<a href="#footerBasePath#\/shore-contact-overdue-boater\/">Shore Contact Guide<\/a>/
  );
  assert.equal(count(homepage, /shore-contact-overdue-boater\//g), 1);
  assert.match(homepage, /fpw-audience-safety-note[\s\S]*?Read the Shore Contact Guide/);
  assert.match(homepageCss, /\.fpw-audience-safety-note__link/);
});

test("canonical clean guide routes remain contract-backed", () => {
  assert.match(webConfig, /\^shore-contact-overdue-boater\/\$/);
  assert.match(webConfig, /url="\/shore-contact-overdue-boater\.cfm"/);
  assert.match(webConfig, /\^why-use-a-float-plan\/\$/);
  assert.match(webConfig, /url="\/why-use-a-float-plan\.cfm"/);
});
