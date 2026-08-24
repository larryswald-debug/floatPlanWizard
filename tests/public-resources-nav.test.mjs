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
const commonEmergencies = read("common-boating-emergencies.cfm");
const homepage = read("partials/fpw-conversion-landing.cfm");
const homepageCss = read("assets/css/fpw-conversion-landing.css");
const webConfig = read("web.config");
const topNavStylesheetHosts = [
  "about.cfm",
  "app/active-cruise.cfm",
  "app/great-loop-anchorage.cfm",
  "app/great-loop-anchorages.cfm",
  "app/great-loop-lock.cfm",
  "app/great-loop-locks.cfm",
  "app/great-loop-port.cfm",
  "app/great-loop-ports.cfm",
  "boat-fuel-calculator/boat-fuel-calculator.cfm",
  "faq/index.cfm",
  "great-loop-bridge.cfm",
  "great-loop/bridges.cfm",
  "how-it-works.cfm",
  "includes/header_styles.cfm",
  "index.cfm",
  "shore-contact-overdue-boater.cfm",
  "solo-boating-safety-guide.cfm",
  "why-use-a-float-plan.cfm"
].map(read).join("\n");

function count(source, pattern) {
  return [...source.matchAll(pattern)].length;
}

test("one shared Resources menu replaces top-level Tools for public and member navigation", () => {
  const greatLoopIndex = topNav.indexOf('fpw-dropdown--mega');
  const resourcesIndex = topNav.indexOf('fpw-dropdown--resources');
  const pricingIndex = topNav.indexOf('<span>Pricing</span>');

  assert.ok(greatLoopIndex > -1);
  assert.ok(resourcesIndex > greatLoopIndex);
  assert.ok(pricingIndex > resourcesIndex);
  assert.equal(count(topNav, /fpw-dropdown--resources/g), 1);
  assert.doesNotMatch(topNav, /fpw-dropdown--tools|fpwToolsMenu|<span class="fpw-nav-label-desktop">Tools<\/span>|<span class="fpw-nav-label-mobile">Trip Tools<\/span>/);
  assert.doesNotMatch(topNav, /<cfif topNavIsLoggedIn>\s+<div class="fpw-dropdown fpw-dropdown--resources"/);
});

test("the authenticated secondary navigation remains unchanged", () => {
  const subnavStart = topNav.indexOf('<nav class="fpw-app-subnav"');
  const subnav = topNav.slice(subnavStart, topNav.indexOf("</nav>", subnavStart));
  const labels = ["Dashboard", "Active Cruise", "Monitor", "Weather", "Fuel Calculator"];

  assert.ok(subnavStart > -1);
  let previousIndex = -1;
  for (const label of labels) {
    const labelIndex = subnav.indexOf(`>${label}</span>`);
    assert.ok(labelIndex > previousIndex, `${label} is missing or out of order`);
    previousIndex = labelIndex;
  }
});

test("Resources uses the approved two-column taxonomy with a linked Boating Safety group", () => {
  const resourcesBlock = topNav.slice(
    topNav.indexOf('<div class="fpw-dropdown fpw-dropdown--resources"'),
    topNav.indexOf('<span>Pricing</span>')
  );

  assert.ok(resourcesBlock.indexOf("Boating Safety") < resourcesBlock.indexOf("Planning Tools"));
  assert.ok(resourcesBlock.indexOf("Planning Tools") < resourcesBlock.indexOf("Boating Resources"));
  assert.match(resourcesBlock, /<section class="fpw-resource-feature fpw-resource-featured" aria-labelledby="fpwResourceFeaturedTitle">/);
  assert.match(resourcesBlock, /class="fpw-resource-section-link<cfif topNavBoatingSafetyActive> is-active<\/cfif>"[\s\S]*?href="#topNavBasePath#\/solo-boating-safety-guide\/"[\s\S]*?>Boating Safety<\/a>/);
  assert.equal(count(resourcesBlock, /class="fpw-resource-feature-card fpw-featured-guide"/g), 2);
  assert.equal(count(resourcesBlock, /class="fpw-resource-feature-summary fpw-featured-guide__main"/g), 2);
  assert.equal(count(resourcesBlock, /class="fpw-featured-guide__icon"/g), 2);
  assert.equal(count(resourcesBlock, /class="fpw-resource-feature-copy fpw-featured-guide__content"/g), 2);
  assert.equal(count(resourcesBlock, /class="fpw-featured-guide__title"/g), 2);
  assert.equal(count(resourcesBlock, /class="fpw-featured-guide__description"/g), 2);
  assert.equal(count(resourcesBlock, /class="fpw-featured-guide__divider" aria-hidden="true"/g), 2);
  assert.ok(resourcesBlock.indexOf("Solo Boating Safety Guide") < resourcesBlock.indexOf("Common Boating Emergencies"));
  assert.ok(resourcesBlock.indexOf("Common Boating Emergencies") < resourcesBlock.indexOf("Shore Contact Guide"));
  assert.match(resourcesBlock, /Shore Contact Guide/);
  assert.match(resourcesBlock, /What to do when a boater misses a check-in or expected return\./);
  assert.match(resourcesBlock, /Practical solo boating safety guidance from kayaks to cruisers, with preparation tips and checklists\./);
  assert.match(resourcesBlock, /renderFpwNavIcon\("checklist", "fpw-resource-feature-icon"\)/);
  assert.match(resourcesBlock, /renderFpwNavIcon\("kayak", "fpw-resource-feature-icon"\)/);
  assert.match(resourcesBlock, /renderFpwNavIcon\("anchor", "fpw-tool-icon"\)#\s+<span>Common Boating Emergencies<\/span>/);
  assert.equal(count(resourcesBlock, /<span>Read the Guide<\/span>/g), 2);
  assert.match(resourcesBlock, /Fuel Calculator/);
  assert.match(resourcesBlock, /Marine Weather/);
  assert.match(resourcesBlock, /Solo Boating Safety Guide/);
  assert.equal(count(resourcesBlock, /#topNavBasePath#\/solo-boating-safety-guide\//g), 2);
  assert.equal(count(resourcesBlock, /#topNavBasePath#\/common-boating-emergencies\//g), 1);
  assert.match(resourcesBlock, /Why Use a Float Plan/);
  assert.match(resourcesBlock, /href="#topNavHowHref#"/);
  assert.match(resourcesBlock, /#topNavBasePath#\/faq\//);
  assert.equal(count(resourcesBlock, /#topNavBasePath#\/why-use-a-float-plan\.cfm/g), 1);
  assert.doesNotMatch(resourcesBlock, /Float Plan Basics/);
  assert.doesNotMatch(resourcesBlock, /Delayed vs\.|Captain and Shore Contact Checklist/);
});

test("Boating Resources retain the approved three-link icon-row treatment", () => {
  const boatingResourcesBlock = topNav.slice(
    topNav.indexOf('<h2 id="fpwBoatingResourcesTitle">Boating Resources</h2>'),
    topNav.indexOf('</div>\n                    </div>\n                  </div>', topNav.indexOf('<h2 id="fpwBoatingResourcesTitle">Boating Resources</h2>'))
  );

  assert.match(boatingResourcesBlock, /#renderFpwNavIcon\("checklist", "fpw-tool-icon"\)#\s+<span>Why Use a Float Plan<\/span>/);
  assert.doesNotMatch(boatingResourcesBlock, /Solo Boating Safety Guide/);
  assert.doesNotMatch(boatingResourcesBlock, /Common Boating Emergencies/);
  assert.match(boatingResourcesBlock, /#renderFpwNavIcon\("how", "fpw-tool-icon"\)#\s+<span>How It Works<\/span>/);
  assert.match(boatingResourcesBlock, /#renderFpwNavIcon\("help", "fpw-tool-icon"\)#\s+<span>FAQ<\/span>/);
  assert.match(topNav, /case "help":[\s\S]*?fpw-icon-help[\s\S]*?<circle cx="24" cy="24" r="18"><\/circle>/);
  assert.match(topNav, /case "kayak":[\s\S]*?fpw-icon-kayak[\s\S]*?<path d="M8 40h48/);
  assert.match(topNav, /aria-hidden="true" focusable="false">' & iconPaths/);
  assert.match(topNavCss, /\.fpw-resource-link \{[\s\S]*?grid-template-columns: auto minmax\(0, 1fr\) auto;[\s\S]*?gap: 13px;/);
});

test("Resources uses one route map and accessible item-level selected states", () => {
  assert.match(topNav, /topNavResourceRouteMap = \[/);
  assert.match(topNav, /"pattern" = "\/solo-boating-safety-guide", "active" = "resources-solo-boating-guide"/);
  assert.match(topNav, /"pattern" = "\/common-boating-emergencies", "active" = "resources-common-boating-emergencies"/);
  assert.match(topNav, /"pattern" = "\/shore-contact-overdue-boater", "active" = "resources-shore-contact-guide"/);
  assert.match(topNav, /"pattern" = "\/why-use-a-float-plan", "active" = "resources-why-float-plan"/);
  assert.match(topNav, /"pattern" = "\/faq\/", "active" = "resources-faq"/);
  assert.match(topNav, /topNavResourcesActive = listFindNoCase\(/);
  assert.match(topNav, /topNavSoloBoatingGuideActive> is-active/);
  assert.match(topNav, /topNavCommonBoatingEmergenciesActive> is-active/);
  assert.match(topNav, /topNavShoreContactGuideActive> is-active/);
  assert.match(topNav, /topNavBoatingSafetyActive = topNavSoloBoatingGuideActive OR topNavCommonBoatingEmergenciesActive OR topNavShoreContactGuideActive/);
  assert.match(commonEmergencies, /request\.fpwTopNavActive = "resources-common-boating-emergencies";/);
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
  assert.equal(count(topNav, /data-fpw-nav-track="public_nav_solo_boating_safety_guide_click"/g), 1);
  assert.equal(count(topNav, /data-fpw-nav-track="public_nav_common_boating_emergencies_click"/g), 1);
  assert.equal(count(topNav, /data-fpw-nav-track="public_nav_boating_safety_click"/g), 1);
  for (const field of ["source_page", "nav_location", "menu_group", "label", "destination_key", "auth_state"]) {
    assert.equal(topNav.includes(`${field}:`), true, `Missing analytics field: ${field}`);
  }
  assert.match(topNav, /data-fpw-nav-track-location="public_header"/);
  assert.match(topNav, /data-fpw-nav-track-menu-group="resources"/);
  assert.match(topNav, /data-fpw-nav-track-auth-state="signed_out"/);
  assert.match(topNav, /<cfif NOT topNavIsLoggedIn>\s+data-fpw-nav-track="public_nav_shore_contact_guide_click"/);
  assert.match(topNav, /<cfif NOT topNavIsLoggedIn>\s+data-fpw-nav-track="public_nav_solo_boating_safety_guide_click"/);
  assert.match(topNav, /<cfif NOT topNavIsLoggedIn>\s+data-fpw-nav-track="public_nav_common_boating_emergencies_click"/);
  assert.match(topNav, /<cfif NOT topNavIsLoggedIn>\s+data-fpw-nav-track="public_nav_boating_safety_click"/);
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
  assert.match(topNavCss, /\.fpw-resource-feature \{[\s\S]*?align-self: start;[\s\S]*?padding: 18px;[\s\S]*?border: 1px solid rgba\(68, 226, 235, 0\.3\);/);
  assert.match(topNavCss, /\.fpw-featured-guide__main \{[\s\S]*?grid-template-columns: 42px minmax\(0, 1fr\);[\s\S]*?align-items: start;/);
  assert.match(topNavCss, /\.fpw-featured-guide \{[\s\S]*?flex-direction: column;[\s\S]*?gap: 20px;/);
  assert.match(topNavCss, /\.fpw-featured-guide__divider \{[\s\S]*?height: 1px;[\s\S]*?margin: 24px 0;[\s\S]*?background: rgba\(169, 186, 203, 0\.18\);/);
  assert.match(topNavCss, /\.fpw-resource-feature-link:focus-visible/);
  assert.match(topNavCss, /\.fpw-resource-section-link:focus-visible/);
  assert.match(topNavCss, /:not\(\.fpw-resource-section-link\):focus-visible/);
  assert.match(topNavCss, /\.fpw-resource-link:focus-visible/);
  assert.match(topNavCss, /@media \(max-width: 1320px\) and \(min-width: 1051px\)/);
  assert.match(topNavCss, /\.fpw-site-header:not\(\.fpw-site-header--logged-in\) \.fpw-nav-link/);
  assert.match(topNavCss, /\.fpw-site-header:not\(\.fpw-site-header--logged-in\) \.fpw-nav-menu \{\s+transform: none;\s+transition: opacity 180ms ease, visibility 180ms ease;/);
  assert.match(topNavCss, /\.fpw-resources-grid \{\s+grid-template-columns: 1fr;/);
  assert.match(topNavCss, /\.fpw-dropdown--resources:not\(\.is-open\):focus-within > \.fpw-dropdown-menu \{\s+display: none;/);
  assert.match(topNav, /var mobileQuery = window\.matchMedia\("\(max-width: 1050px\)"\);/);
});

test("every active top-nav stylesheet host uses the Boating Safety cache version", () => {
  assert.equal(count(topNavStylesheetHosts, /top-nav\.css\?v=20260824-boating-safety-nav-v2/g), 18);
  assert.doesNotMatch(topNavStylesheetHosts, /top-nav\.css\?v=20260806-resources-mega-v3/);
});

test("footer groups the live Boating Safety destinations without changing the homepage link", () => {
  assert.equal(count(footer, /shore-contact-overdue-boater\//g), 1);
  assert.equal(count(footer, /solo-boating-safety-guide\//g), 2);
  assert.equal(count(footer, /common-boating-emergencies\//g), 1);
  assert.match(
    footer,
    /<nav class="fpw-footer-col fpw-footer-plan"[\s\S]*?<a href="#footerBasePath#\/solo-boating-safety-guide\/">Boating Safety<\/a>[\s\S]*?<a href="#footerBasePath#\/solo-boating-safety-guide\/">Solo Boating Safety Guide<\/a>[\s\S]*?<a href="#footerBasePath#\/common-boating-emergencies\/">Common Boating Emergencies<\/a>[\s\S]*?<a href="#footerBasePath#\/shore-contact-overdue-boater\/">Shore Contact \/ Overdue Boater Guide<\/a>/
  );
  assert.match(footer, /\.fpw-footer-plan-links \{[\s\S]*?grid-template-rows: repeat\(7, max-content\);/);
  assert.match(footer, /@media \(max-width: 768px\) \{[\s\S]*?\.fpw-footer-plan-links,[\s\S]*?\.fpw-footer-account-links/);
  assert.equal(count(homepage, /shore-contact-overdue-boater\//g), 1);
  assert.match(homepage, /fpw-audience-safety-note[\s\S]*?Read the Shore Contact Guide/);
  assert.match(homepageCss, /\.fpw-audience-safety-note__link/);
});

test("canonical clean guide routes remain contract-backed", () => {
  assert.match(webConfig, /\^shore-contact-overdue-boater\/\$/);
  assert.match(webConfig, /url="\/shore-contact-overdue-boater\.cfm"/);
  assert.match(webConfig, /\^common-boating-emergencies\/\$/);
  assert.match(webConfig, /url="\/common-boating-emergencies\.cfm"/);
  assert.match(webConfig, /\^why-use-a-float-plan\/\$/);
  assert.match(webConfig, /url="\/why-use-a-float-plan\.cfm"/);
});
