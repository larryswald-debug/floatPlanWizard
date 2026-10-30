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
const stylesheetHosts = [
  "about.cfm", "app/active-cruise.cfm", "app/great-loop-anchorage.cfm",
  "app/great-loop-anchorages.cfm", "app/great-loop-lock.cfm", "app/great-loop-locks.cfm",
  "app/great-loop-port.cfm", "app/great-loop-ports.cfm",
  "boat-fuel-calculator/boat-fuel-calculator.cfm", "boat-loan-calculator/index.cfm",
  "boating-guides/index.cfm", "boating-guides/chesapeake-bay/index.cfm",
  "common-boating-emergencies.cfm", "faq/index.cfm", "great-loop-bridge.cfm",
  "great-loop/bridges.cfm", "great-loop/trip-planning/index.cfm", "how-it-works.cfm",
  "includes/header_styles.cfm", "index.cfm", "shore-contact-overdue-boater.cfm",
  "solo-boating-safety-guide.cfm", "why-use-a-float-plan.cfm"
];

function count(source, pattern) {
  return [...source.matchAll(pattern)].length;
}

test("one shared navigation contains the approved categories in order", () => {
  let previous = -1;
  for (const category of ["plan", "explore", "learn", "tools", "help"]) {
    const marker = "fpw-dropdown--" + category;
    const position = topNav.indexOf(marker);
    assert.ok(position > previous, category + " must follow its preceding category");
    assert.equal(count(topNav, new RegExp('class="fpw-dropdown ' + marker + '(?:[ "])', "g")), 1);
    previous = position;
  }
  assert.match(topNav, /id="fpwPrimaryNav"/);
  assert.match(topNav, /data-fpw-nav-menu/);
  assert.doesNotMatch(topNav, /fpwResourcesMenu|fpw-dropdown--resources/);
  assert.doesNotMatch(topNav, /class="[^"]*\bsearch-trigger\b/);
});

test("the authenticated subnav, account, privacy, and logout contracts remain intact", () => {
  const start = topNav.indexOf('<nav class="fpw-app-subnav"');
  const subnav = topNav.slice(start, topNav.indexOf("</nav>", start));
  assert.ok(start > -1);
  let previous = -1;
  for (const label of ["Dashboard", "Active Cruise", "Monitor", "Weather", "Fuel Calculator"]) {
    const index = subnav.indexOf(">" + label + "</span>");
    assert.ok(index > previous, label + " is missing or out of order");
    previous = index;
  }
  for (const attribute of ["data-fpw-member-identity", "data-fpw-member-email", 'data-clarity-mask="True"', "data-fpw-member-logout"]) {
    assert.ok(topNav.includes(attribute), attribute + " must remain");
  }
  assert.match(topNav, /href="#topNavBasePath#\/app\/account\.cfm"/);
  assert.match(topNav, /topNavIsLoggedIn/);
  assert.match(topNav, /fpw-context-help/);
  assert.match(topNav, /fpw-auth-modal\.cfm/);
});

test("approved menus retain real route, guide, and documentation destinations", () => {
  for (const route of [
    "/app/dashboard.cfm?recoveryAction=planner", "/app/dashboard.cfm?recoveryAction=routes",
    "/app/dashboard.cfm?recoveryAction=plans", "/app/active-cruise.cfm",
    "/boating-guides/", "/boating-guides/chesapeake-bay/", "/great-loop/trip-planning/",
    "/great-loop/ports/", "/great-loop/anchorages/", "/great-loop/bridges/", "/great-loop/locks/",
    "/fpw_great_loop_clockwise/", "/solo-boating-safety-guide/",
    "/shore-contact-overdue-boater/", "/common-boating-emergencies/", "/why-use-a-float-plan/",
    "/boat-fuel-calculator/", "/boat-loan-calculator/", "/app/weather.cfm",
    "/app/user-manual.cfm", "/faq/", "/app/contact.cfm?mode=support", "/app/contact.cfm?mode=feedback"
  ]) assert.ok(topNav.includes(route), "Missing approved destination: " + route);
  for (const fragment of ["vesselsPanel", "#follow", "#mileage-override",
    "#12-understand-the-cruise-timeline-time-and-fuel-estimates", "#fpwProductPreview"]) {
    assert.ok(topNav.includes(fragment), "Missing approved anchor: " + fragment);
  }
  for (const label of ["Float Plan Workspace", "How to Follow a Trip", "Great Loop Waterway Legs",
    "Route Timing Guide", "Mileage Override Guide", "Features",
    "Submit a Support Request", "Suggest a Feature"]) assert.ok(topNav.includes(label), label);
  assert.doesNotMatch(topNav, /href="#"/);
});

test("menu controls have unique panel targets and accessible selected state", () => {
  for (const category of ["Plan", "Explore", "Learn", "Tools", "Help"]) {
    assert.equal(count(topNav, new RegExp('id="fpw' + category + 'Menu"', "g")), 1);
    assert.match(topNav, new RegExp('aria-controls="fpw' + category + 'Menu"'));
  }
  assert.match(topNav, /aria-current="page"/);
  assert.match(topNav, /aria-expanded="false"/);
  assert.match(topNav, /data-fpw-dropdown-toggle/);
  for (const marker of ["resources-solo-boating-guide", "resources-common-boating-emergencies",
    "resources-shore-contact-guide", "resources-boat-loan-calculator"]) assert.ok(topNav.includes(marker));
});

test("guide analytics remain one-event, non-sensitive, and navigation-independent", () => {
  for (const name of ["public_nav_shore_contact_guide_click", "public_nav_solo_boating_safety_guide_click",
    "public_nav_common_boating_emergencies_click", "public_nav_boating_safety_click"]) {
    assert.equal(count(topNav, new RegExp('data-fpw-nav-track="' + name + '"', "g")), 1);
  }
  for (const field of ["source_page", "nav_location", "menu_group", "label", "destination_key", "auth_state"]) {
    assert.ok(topNav.includes(field + ":"), "Missing analytics field: " + field);
  }
  assert.match(topNav, /data-fpw-nav-track-location="public_header"/);
  assert.match(topNav, /data-fpw-nav-track-menu-group="resources"/);
  assert.match(topNav, /data-fpw-nav-track-auth-state="signed_out"/);
  assert.doesNotMatch(topNav, /public_nav_resources_open/);
  const start = topNav.indexOf("function trackPublicNavClick(");
  const end = topNav.indexOf("\n      }", start);
  const tracking = topNav.slice(start, end);
  assert.ok(start > -1);
  assert.match(tracking, /try \{/);
  assert.match(tracking, /catch \(error\) \{\}/);
  assert.doesNotMatch(tracking, /preventDefault/);
  assert.match(topNav, /data-fpw-nav-bound/);
});

test("responsive styles preserve visible focus and explicit hidden-panel containment", () => {
  assert.match(topNavCss, /max-width:\s*1040px/);
  assert.match(topNav, /max-width:\s*1040px/);
  assert.match(topNavCss, /focus-visible/);
  assert.match(topNavCss, /prefers-reduced-motion/);
  assert.match(topNavCss, /position:\s*sticky/);
  // Hidden panels must stay hidden even while legacy selectors match focus.
  // Actual click-only behavior is exercised in the browser suite.
  assert.match(topNavCss, /\[hidden\]\s*\{\s*display:\s*none\s*!important;/);
});

test("all primary stylesheet hosts use the approved-navigation asset version", () => {
  for (const host of stylesheetHosts) {
    const content = read(host);
    assert.equal(count(content, /top-nav\.css\?v=20261028-approved-navigation/g), 1, host);
    assert.doesNotMatch(content, /top-nav\.css\?v=20261013-global-help/, host);
  }
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
