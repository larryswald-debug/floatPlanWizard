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

test("Resources is signed-out-only and ordered between Tools and Pricing", () => {
  const toolsIndex = topNav.indexOf('fpw-dropdown--tools');
  const resourcesIndex = topNav.indexOf('fpw-dropdown--resources');
  const pricingIndex = topNav.indexOf('<span>Pricing</span>');

  assert.ok(toolsIndex > -1);
  assert.ok(resourcesIndex > toolsIndex);
  assert.ok(pricingIndex > resourcesIndex);
  assert.match(
    topNav,
    /<cfif NOT topNavIsLoggedIn>\s+<div class="fpw-dropdown fpw-dropdown--resources"/
  );
  assert.equal(count(topNav, /fpw-dropdown--resources/g), 1);
});

test("Resources contains the featured guide first and only live supporting links", () => {
  const resourcesBlock = topNav.slice(
    topNav.indexOf('<div class="fpw-dropdown fpw-dropdown--resources"'),
    topNav.indexOf('<span>Pricing</span>')
  );

  assert.ok(resourcesBlock.indexOf("Shore Contact Guide") < resourcesBlock.indexOf("Why Use a Float Plan"));
  assert.ok(resourcesBlock.indexOf("Why Use a Float Plan") < resourcesBlock.indexOf("How It Works"));
  assert.ok(resourcesBlock.indexOf("How It Works") < resourcesBlock.indexOf("FAQ"));
  assert.match(resourcesBlock, /What to do when a boater misses a check-in or expected return\./);
  assert.match(resourcesBlock, /#topNavBasePath#\/shore-contact-overdue-boater\//);
  assert.match(resourcesBlock, /#topNavBasePath#\/why-use-a-float-plan\//);
  assert.match(resourcesBlock, /href="#topNavHowHref#"/);
  assert.match(resourcesBlock, /#topNavBasePath#\/faq\//);
  assert.doesNotMatch(resourcesBlock, /Delayed vs\.|Solo Boater|Captain and Shore Contact Checklist/);
});

test("Resources uses reusable route inference and accessible selected states", () => {
  assert.match(topNav, /structKeyExists\(cgi, "request_uri"\)/);
  assert.match(topNav, /findNoCase\("\/shore-contact-overdue-boater", topNavRequestPath\)/);
  assert.match(topNav, /findNoCase\("\/why-use-a-float-plan", topNavRequestPath\)/);
  assert.match(topNav, /findNoCase\("\/faq\/", topNavRequestPath\)/);
  assert.match(topNav, /listFindNoCase\("resources,resources-shore-contact-guide", topNavActive\)/);
  assert.match(topNav, /topNavShoreContactGuideActive> is-active/);
  assert.match(topNav, /topNavShoreContactGuideActive>aria-current="page"/);
  assert.match(topNav, /aria-controls="fpwResourcesMenu"/);
  assert.match(topNav, /id="fpwResourcesMenu" role="menu"/);
});

test("guide click analytics are one-event, non-sensitive, and navigation-independent", () => {
  assert.equal(count(topNav, /data-fpw-nav-track="public_nav_shore_contact_guide_click"/g), 1);
  for (const field of ["source_page", "nav_location", "label", "destination_key", "auth_state"]) {
    assert.equal(topNav.includes(`${field}:`), true, `Missing analytics field: ${field}`);
  }
  assert.match(topNav, /data-fpw-nav-track-location="resources_dropdown"/);
  assert.match(topNav, /data-fpw-nav-track-auth-state="signed_out"/);
  assert.doesNotMatch(topNav, /public_nav_resources_open/);

  const trackingFunction = topNav.match(/function trackPublicNavClick\(link\) \{[\s\S]*?\n      \}/)?.[0] ?? "";
  assert.match(trackingFunction, /try \{/);
  assert.match(trackingFunction, /catch \(error\) \{\}/);
  assert.doesNotMatch(trackingFunction, /preventDefault/);
  assert.match(topNav, /data-fpw-nav-bound/);
});

test("shared CSS styles the compact feature and removes closed-drawer overflow", () => {
  assert.match(topNavCss, /\.fpw-dropdown--resources > \.fpw-dropdown-menu/);
  assert.match(topNavCss, /\.fpw-resource-feature \{/);
  assert.match(topNavCss, /\.fpw-resource-link:focus-visible/);
  assert.match(topNavCss, /@media \(max-width: 1320px\) and \(min-width: 1051px\)/);
  assert.match(topNavCss, /\.fpw-site-header:not\(\.fpw-site-header--logged-in\) \.fpw-nav-link/);
  assert.doesNotMatch(topNavCss, /transform: translateX\(110%\)/);
  assert.match(topNavCss, /\.fpw-nav-menu \{[\s\S]*?transform: none;[\s\S]*?transition: opacity 180ms ease/);
  assert.match(topNav, /"\(max-width: 1023px\)" : "\(max-width: 1050px\)"/);
});

test("footer and homepage each add one restrained guide link", () => {
  assert.equal(count(footer, /shore-contact-overdue-boater\//g), 1);
  assert.match(
    footer,
    /<nav class="fpw-footer-col fpw-footer-plan"[\s\S]*?<a href="#footerBasePath#\/shore-contact-overdue-boater\/">Shore Contact Guide<\/a>/
  );
  assert.equal(count(homepage, /shore-contact-overdue-boater\//g), 1);
  assert.match(homepage, /fpw-audience-safety-note[\s\S]*?Read the Shore Contact Guide/);
  assert.match(homepageCss, /\.fpw-audience-safety-note__link/);
});

test("canonical clean routes remain contract-backed", () => {
  assert.match(webConfig, /\^shore-contact-overdue-boater\/\$/);
  assert.match(webConfig, /url="\/shore-contact-overdue-boater\.cfm"/);
  assert.match(webConfig, /\^why-use-a-float-plan\/\$/);
  assert.match(webConfig, /url="\/why-use-a-float-plan\.cfm"/);
});
