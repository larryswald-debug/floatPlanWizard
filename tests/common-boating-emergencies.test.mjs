import assert from "node:assert/strict";
import { existsSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));
const read = (relativePath) => readFileSync(path.join(repositoryRoot, relativePath), "utf8");
const page = read("common-boating-emergencies.cfm");
const stylesheet = read("assets/css/common-boating-emergencies.css");
const script = read("assets/js/common-boating-emergencies.js");
const webConfig = read("web.config");
const sitemap = read("sitemap.xml");

const canonical = "https://floatplanwizard.com/common-boating-emergencies/";
const heroUrl = "https://floatplanwizard.com/assets/images/boating-guides/common-boating-emergencies/common-boating-emergencies-hero.jpg";
const imageDirectory = "assets/images/boating-guides/common-boating-emergencies";
const engineFailureAlt = "Three life-jacketed boaters respond to an engine failure as one checks the engine compartment, one makes a radio call, and one lowers the anchor from the bow.";
const groundingAlt = "Two life-jacketed boaters assess a cabin cruiser grounded in shallow water as one checks depth beside the bow and the other remains at the helm.";
const personOverboardAlt = "Two life-jacketed boaters aboard a cabin cruiser respond to a person overboard as one throws a ring buoy with a retrieval line toward the life-jacketed person in the water.";
const fireAlt = "Thirty-five-foot cabin cruiser docked at a fuel station with smoke and flames coming from the rear engine compartment and spilled fuel burning on the water near the stern.";
const fireCaption = "Fire at a fuel dock can spread rapidly from the engine compartment to spilled fuel on the water. Stop fueling, alert everyone nearby, evacuate to a safe location and call emergency services&mdash;do not remain aboard to fight a spreading fuel fire.";
const stormAlt = "Cabin cruiser moving through a marked channel toward protected water between a red marker on the left and a green marker on the right, with a dark storm and heavy rain behind the boat.";
const stormCaption = "Storms can close in quickly. When one is heading your way, seek safe harbor while you still have time to reach it safely.";
const maydayAlt = "Two life-jacketed boaters at the helm in rough water while the operator sends a Mayday call on a fixed VHF radio with a prepared emergency card beside the controls.";
const overdueAlt = "Three-panel scene showing a boater at a marina, a shore contact reviewing the boat and route while on the phone, and a rescue coordinator viewing the same vessel and route information.";
const paceNote = "Illustrative sequence; equipment and safe actions depend on the vessel and emergency.";
const figureAssets = [
  ["common-boating-emergencies-hero", 1672, 941, "A boat operator checks the VHF radio while two passengers put on life jackets after the boat loses power.", "Calm, early action preserves options: protect people, establish position, control the boat, and call before the situation worsens."],
  ["boat-engine-failure-drift-anchor", 1672, 941, engineFailureAlt, "Assess depth, bottom, traffic, wind, current, and sea room before anchoring or troubleshooting."],
  ["boat-taking-on-water-checkpoints", 1536, 1024, "A cutaway view highlights several common places water can enter a recreational boat, including fittings, hoses, drains, and hull damage.", "Boat layouts differ. Check only accessible areas you understand, and never delay a distress call while water is rising."],
  ["boat-grounding-stop-assess", 1672, 941, groundingAlt, "Stop and assess before trying to power free; immediate throttle can worsen damage or clog cooling-water intakes."],
  ["person-overboard-controlled-recovery", 1672, 941, personOverboardAlt, "Maintain visual contact, deploy flotation and approach under control. Shift to neutral and shut the engine off before the person is alongside or recovery begins."],
  ["boat-engine-compartment-fire-response", 1672, 941, fireAlt, fireCaption],
  ["boating-storm-early-shelter-decision", 1672, 941, stormAlt, stormCaption],
  ["marine-vhf-mayday-prepared-card", 1448, 1086, maydayAlt, "Give position, danger, assistance needed, and people aboard. Keep the full Mayday script in HTML and on the printable card."],
  ["capsize-stay-with-boat-visibility", 1672, 941, "From the air, an overturned boat and grouped survivors are much more visible than one person alone in the water.", "Stay with the boat unless fire, fuel, surf, a dam, rocks, or another immediate hazard makes leaving safer."],
  ["boat-carbon-monoxide-danger-zones", 1536, 1024, "Recreational cabin cruiser highlighting carbon-monoxide danger zones at the stern, swim platform, canvas-enclosed cockpit and cabin, with external exhaust backdrafting forward.", "Conceptual hazard overlay&mdash;carbon monoxide is colorless and odorless. Exhaust can collect near the stern and be drawn into cockpits or cabins by wind, speed, trim, canvas and open compartments."],
  ["overdue-boater-response-information-chain", 1672, 941, overdueAlt, "Conceptual information chain&mdash;not a representation of continuous live vessel tracking."]
];
const requiredSections = [
  "first-60-seconds",
  "choose-emergency-call",
  "mayday-call-script",
  "boat-engine-failure",
  "boat-control-failure",
  "boat-taking-on-water",
  "boat-fire-fuel-leak",
  "boat-ran-aground",
  "boating-collision",
  "person-overboard",
  "boat-capsize",
  "boating-weather-visibility",
  "medical-emergency-on-boat",
  "boat-carbon-monoxide",
  "disabled-boat-immediate-hazard",
  "overdue-boat",
  "boating-emergency-communications",
  "passenger-safety-briefing",
  "boat-emergency-equipment",
  "boating-accident-reporting",
  "printable-boating-emergency-card",
  "boating-emergency-faq",
  "sources"
];

function countMatches(source, pattern) {
  return [...source.matchAll(pattern)].length;
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function visibleText(source) {
  return source
    .replace(/<span class="fpw-emergency-new-window">[\s\S]*?<\/span>/g, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/&mdash;/g, "—")
    .replace(/&rsquo;/g, "’")
    .replace(/&hellip;/g, "…")
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .replace(/\s+([.,;:!?])/g, "$1")
    .trim();
}

test("page has the approved discovery metadata, JPEG social image, and one canonical H1", () => {
  assert.equal(countMatches(page, /<title>Common Boating Emergencies: What to Do \| FloatPlanWizard<\/title>/g), 1);
  assert.equal(
    countMatches(page, /<meta name="description" content="Learn what to do if your boat loses power, takes on water, runs aground, catches fire, encounters severe weather, or has a person overboard\.">/g),
    1
  );
  assert.equal(countMatches(page, new RegExp(`<link rel="canonical" href="${escapeRegExp(canonical)}">`, "g")), 1);
  assert.equal(countMatches(page, /<h1 id="fpw-emergency-title">When Something Goes Wrong on the Water<\/h1>/g), 1);
  assert.equal(countMatches(page, /<h1\b/g), 1);
  assert.match(page, /<meta name="robots" content="index,follow,max-image-preview:large">/);
  assert.match(page, /<meta property="og:type" content="article">/);
  assert.match(page, /<meta property="og:url" content="https:\/\/floatplanwizard\.com\/common-boating-emergencies\/">/);
  assert.match(page, /<meta property="og:title" content="When Something Goes Wrong on the Water">/);
  assert.match(page, new RegExp(`<meta property="og:image" content="${escapeRegExp(heroUrl)}">`));
  assert.match(page, new RegExp(`<meta name="twitter:image" content="${escapeRegExp(heroUrl)}">`));
  assert.match(page, /<meta property="og:image:type" content="image\/jpeg">/);
  assert.match(page, /<meta property="og:image:width" content="1672">/);
  assert.match(page, /<meta property="og:image:height" content="941">/);
});

test("schema graph is Article-based and does not claim FAQPage or HowTo eligibility", () => {
  for (const type of ["Organization", "BreadcrumbList", "WebPage", "Article"]) {
    assert.match(page, new RegExp(`structInsert\\([^\\n]+schemaTypeKey, "${type}"`));
  }
  for (const property of [
    "url",
    "headline",
    "description",
    "datePublished",
    "dateModified",
    "articleSection",
    "inLanguage",
    "author",
    "publisher",
    "mainEntityOfPage",
    "image"
  ]) {
    assert.equal(page.includes(`["${property}"]`), true, `Missing schema property ${property}`);
  }
  assert.match(page, /fpwEmergencyPublishedDate = "2026-08-23";/);
  assert.match(page, /fpwEmergencyModifiedDate = "2026-08-23";/);
  assert.match(page, /fpwEmergencySchemaArticle\["image"\] = \[ fpwEmergencySocialImage \];/);
  assert.match(page, new RegExp(`fpwEmergencySocialImage = "${escapeRegExp(heroUrl)}";`));
  assert.doesNotMatch(page, /schemaTypeKey, "(?:FAQPage|HowTo)"/);
  assert.equal(countMatches(page, /type="application\/ld\+json"/g), 1);
});

test("all required sections are present, linked, unique, and available in initial HTML", () => {
  const staticIds = [...page.matchAll(/\sid="([a-z][a-z0-9-]*)"/gi)].map((match) => match[1]);
  assert.equal(new Set(staticIds).size, staticIds.length, "Static IDs must be unique");

  const tocTargets = [...page.matchAll(/<li><a href="#([a-z0-9-]+)" data-fpw-guide-toc/g)].map((match) => match[1]);
  assert.deepEqual(tocTargets, requiredSections);
  for (const sectionId of requiredSections) {
    assert.equal(page.includes(`id="${sectionId}"`), true, `Missing section ${sectionId}`);
    assert.equal(page.includes(`href="#${sectionId}" data-fpw-guide-toc`), true, `Missing TOC link ${sectionId}`);
  }

  for (const labelTarget of [...page.matchAll(/aria-labelledby="([a-z0-9-]+)"/g)].map((match) => match[1])) {
    assert.equal(page.includes(`id="${labelTarget}"`), true, `Missing aria-labelledby target ${labelTarget}`);
  }
  assert.doesNotMatch(page, /FPW_EMERGENCY_GUIDE_CONTENT|document\.write|innerHTML\s*=/);
});

test("fuel-dock fire subsection preserves the exact approved copy, semantics, links, and placement", () => {
  const fireSectionStart = page.indexOf('<section id="boat-fire-fuel-leak"');
  const fireFigureEnd = page.indexOf("</figure>", fireSectionStart);
  const subsectionStart = page.indexOf('<section class="fpw-emergency-fuel-dock" id="fuel-dock-fires"', fireFigureEnd);
  const existingFireInstructionsStart = page.indexOf("<h3>If you smell gasoline or discover a fuel leak</h3>", subsectionStart);
  assert.ok(fireSectionStart >= 0);
  assert.ok(fireFigureEnd < subsectionStart, "Subsection must follow the fire figure and caption");
  assert.ok(subsectionStart < existingFireInstructionsStart, "Subsection must precede the existing fire instructions");

  const subsection = page.slice(subsectionStart, existingFireInstructionsStart);
  const subsectionText = visibleText(subsection);
  assert.equal(countMatches(page, /\sid="fuel-dock-fires"/g), 1);
  assert.equal(countMatches(subsection, /<h3\b/g), 1);
  assert.equal(countMatches(subsection, /<h4\b/g), 4);
  assert.match(subsection, /^<section class="fpw-emergency-fuel-dock" id="fuel-dock-fires" aria-labelledby="fuel-dock-fires-heading">/);
  assert.match(subsection, /<h3 id="fuel-dock-fires-heading">Fuel-Dock Fires and Burning Fuel on the Water<\/h3>/);
  assert.equal(countMatches(subsection, /<aside\b/g), 2);
  assert.equal(countMatches(subsection, /<aside class="fpw-emergency-fuel-dock-experience">/g), 1);
  assert.equal(countMatches(subsection, /<aside class="fpw-emergency-fuel-dock-reminder" role="note">/g), 1);
  assert.equal(countMatches(subsection, /<section class="fpw-emergency-fuel-dock-panel\b/g), 3);
  assert.equal(page.includes('href="#fuel-dock-fires" data-fpw-guide-toc'), false, "Third-level subsection must not be added to the top-level TOC");

  const approvedCopy = [
    "Fueling may feel routine, but a fuel dock combines gasoline, vapors, electrical equipment, boats and people in a confined area. Even a small spill can spread across the water and underneath nearby boats or docks.",
    "The water itself does not burn. A layer of fuel floating on the surface—and the vapor above it—can ignite and carry fire rapidly across the fueling area.",
    "When I was about 10 years old, I was aboard my father’s 14-foot runabout while we stopped for fuel. A larger boat was fueling beside us. Although nothing appeared to be leaking at that moment, some fuel was already floating on the water.",
    "A man aboard the other boat was smoking a cigar. He threw it into the water, apparently intending to put it out, and the fuel on the surface ignited almost instantly.",
    "Everything happened very fast. My mother panicked and jumped into the water. Someone grabbed me and ran with me as quickly as possible to get away from the fire. Thankfully, my mother was unharmed and the fire was extinguished, but the situation could easily have ended very differently.",
    "That experience stayed with me because every part of it was preventable. Smoking should never have been permitted near the fuel dock, spilled fuel should not have been present, and no passenger—especially a child—should have remained aboard during fueling.",
    "Put all passengers ashore before fueling begins.",
    "Secure the boat firmly to the dock.",
    "Shut down engines, generators and other potential ignition sources.",
    "Extinguish cigarettes, cigars and every open flame. If anyone begins smoking nearby, stop fueling immediately and alert the dock attendant.",
    "Close ports, hatches and doors to keep gasoline vapors out of enclosed spaces.",
    "Keep the fuel nozzle in contact with the fill opening and attend it continuously.",
    "Fill slowly and never top off the tank.",
    "Watch the fuel vent, deck and surrounding water for spills or a visible sheen.",
    "After fueling, open the compartments, ventilate the boat and operate the blower for at least four minutes before starting a gasoline engine. Check carefully for fuel odors. Reboard passengers only after the engine has been started safely. These precautions follow BoatUS Foundation fueling guidance.",
    "Stop the flow of fuel and notify the marina attendant immediately.",
    "Do not start the engine or operate electrical switches in the affected area.",
    "Keep people away from the spill and eliminate every possible ignition source.",
    "Allow marina personnel to deploy oil-absorbent pads or containment booms.",
    "Never use soap or detergent to make a sheen disappear. It spreads the contamination through the water and is illegal.",
    "Report a spill that creates a sheen to the U.S. Coast Guard National Response Center at 1-800-424-8802, along with any required state or local notification.",
    "BoatUS Foundation spill-response guidance",
    "Shout a warning and get everyone away from the fuel dock immediately.",
    "Call 911 from a safe location and clearly report that fuel is burning on the water.",
    "Activate the fuel-dock emergency shutoff only if it can be reached without approaching the flames or passing through smoke.",
    "Use the dock as the primary escape route when it remains safe. Do not automatically jump into the water—burning fuel can spread across the surface, and marina water may also present electrical hazards.",
    "Do not start or move a burning boat unless emergency personnel direct you to do so.",
    "Attempt to use a properly rated fire extinguisher only when the fire is still small, you know how to use it and you have a clear escape route behind you.",
    "Never throw water onto burning gasoline. Leave a spreading fuel or marina fire to trained responders.",
    "Boat and marina fires can spread quickly, so evacuation takes priority over saving the boat or fighting a growing fire. U.S. Fire Administration marina-fire guidance.",
    "Remember: A fuel sheen is not harmless, and a fuel dock is never an acceptable place to smoke. If you see either condition, stop fueling and notify the marina before an ignition turns a manageable spill into a life-threatening emergency."
  ];
  for (const copy of approvedCopy) {
    assert.equal(subsectionText.split(copy).length - 1, 1, `Approved copy must appear exactly once: ${copy}`);
  }

  const beforeStart = subsection.indexOf('fpw-emergency-fuel-dock-panel--before');
  const spillStart = subsection.indexOf('fpw-emergency-fuel-dock-panel--spill');
  const fireStart = subsection.indexOf('fpw-emergency-fuel-dock-panel--fire');
  const panelsEnd = subsection.indexOf("</div>", fireStart);
  const beforePanel = subsection.slice(beforeStart, spillStart);
  const spillPanel = subsection.slice(spillStart, fireStart);
  const firePanel = subsection.slice(fireStart, panelsEnd);
  assert.match(beforePanel, /<h4>Before fueling<\/h4>[\s\S]*?<ul>[\s\S]*?<\/ul>/);
  assert.equal(countMatches(beforePanel, /<li>/g), 8);
  assert.match(spillPanel, /<h4>If fuel spills but has not ignited<\/h4>[\s\S]*?<ol>[\s\S]*?<\/ol>/);
  assert.equal(countMatches(spillPanel, /<li>/g), 6);
  assert.match(firePanel, /<h4>If the fuel ignites<\/h4>[\s\S]*?<ul>[\s\S]*?<\/ul>/);
  assert.equal(countMatches(firePanel, /<li>/g), 7);
  assert.match(spillPanel, /<strong>1-800-424-8802<\/strong>/);

  const approvedLinks = [
    ["https://boatus.org/study-guide/trip-planning-preparation/boat-transportation-trailering/", "BoatUS Foundation fueling guidance", "boatus"],
    ["https://www.boatus.org/clean-boating/fueling/fuel-spill-response", "BoatUS Foundation spill-response guidance", "boatus"],
    ["https://www.usfa.fema.gov/prevention/vehicle-fires/boats-and-marinas/", "U.S. Fire Administration marina-fire guidance", "usfa"]
  ];
  const sourceLinks = [...subsection.matchAll(/<a\b[^>]*href="https:\/\/[^>]+>[\s\S]*?<\/a>/g)].map((match) => match[0]);
  assert.equal(sourceLinks.length, 3);
  for (const [href, label, organization] of approvedLinks) {
    const link = sourceLinks.find((candidate) => candidate.includes(`href="${href}"`));
    assert.ok(link, `Missing approved source ${href}`);
    assert.equal(visibleText(link), label);
    assert.match(link, /target="_blank" rel="noopener noreferrer" data-fpw-guide-source/);
    assert.equal(link.includes(`data-source-org="${organization}" data-section-id="fuel-dock-fires"`), true);
  }

  assert.match(stylesheet, /\.fpw-emergency-fuel-dock \{[\s\S]*?max-width: 76ch;[\s\S]*?scroll-margin-top: 116px;/);
  assert.match(stylesheet, /\.fpw-emergency-fuel-dock-panels \{[\s\S]*?grid-template-columns: 1fr;/);
  assert.match(stylesheet, /\.fpw-emergency-fuel-dock-panel--spill \{[\s\S]*?border-left-color:/);
  assert.match(stylesheet, /\.fpw-emergency-fuel-dock-panel--fire \{[\s\S]*?border-left-color:/);
  assert.match(stylesheet, /@media \(max-width: 480px\)[\s\S]*?\.fpw-emergency-fuel-dock-panel,[\s\S]*?\.fpw-emergency-fuel-dock-reminder \{[\s\S]*?padding: 17px;/);
  assert.match(stylesheet, /@media print[\s\S]*?\.fpw-emergency-fuel-dock-experience,[\s\S]*?\.fpw-emergency-fuel-dock-panel,[\s\S]*?\.fpw-emergency-fuel-dock-reminder \{[\s\S]*?background: #ffffff !important;/);
  assert.doesNotMatch(stylesheet, /\.fpw-emergency-fuel-dock[^}]*(?:^|[;\s])height\s*:/m);
});

test("approved emergency, communication, preparation, and limitation language is retained", () => {
  for (const requiredCopy of [
    "P.A.C.E.",
    "Mayday: grave and imminent danger",
    "Pan-Pan: urgent but not yet grave and imminent",
    "What to do if the boat engine dies or you lose propulsion",
    "What to do if the boat is taking on water",
    "What to do if you see smoke, smell gasoline, discover a fuel leak, or have a fire",
    "What to do when someone falls overboard",
    "What to do if the boat capsizes or sinking makes abandonment necessary",
    "What to do for a serious illness or injury aboard",
    "What to do if carbon monoxide exposure is possible",
    "Give passengers this two-minute safety briefing before leaving",
    "Printable boating emergency card",
    "After everyone is safe: reporting, documentation, and recovery",
    "does not determine when rescue action is required",
    "verify an emergency",
    "dispatch assistance",
    "continuously track every trip",
    "This U.S.-focused educational guide provides general safety information"
  ]) {
    assert.equal(page.includes(requiredCopy), true, `Missing approved content: ${requiredCopy}`);
  }
  assert.doesNotMatch(page, /final accessible 4|reserved for Phase 2|implementation|content owner|Product wording on this page/i);
});

test("links and CTA destinations are limited to verified routes and official sources", () => {
  for (const destination of [
    "/app/join.cfm",
    "/app/dashboard.cfm",
    "/shore-contact-overdue-boater/",
    "/solo-boating-safety-guide/",
    "/boat-fuel-calculator/",
    "/app/pricing.cfm"
  ]) {
    assert.equal(page.includes(destination), true, `Missing internal destination ${destination}`);
  }
  for (const sourceHost of [
    "uscgboating.org",
    "navcen.uscg.gov",
    "weather.gov",
    "cdc.gov",
    "sarsat.noaa.gov",
    "ecfr.gov",
    "redcross.org",
    "epa.gov"
  ]) {
    assert.equal(page.includes(sourceHost), true, `Missing official source ${sourceHost}`);
  }

  const externalLinks = [...page.matchAll(/<a\b[^>]*href="https:\/\/[^>]+>/g)].map((match) => match[0]);
  assert.ok(externalLinks.length >= 14);
  for (const link of externalLinks) {
    assert.match(link, /target="_blank"/);
    assert.match(link, /rel="noopener noreferrer"/);
    assert.match(link, /data-fpw-guide-source/);
  }
  assert.equal(countMatches(page, /<cfinclude template="partials\/fpw-action-cta\.cfm">/g), 2);
  assert.equal(countMatches(page, /"analyticsEvent" = "guide_cta_select"/g), 2);
  assert.doesNotMatch(page, /fpw-action-cta\.js/);
});

test("remaining page figures use every approved source, alt, caption, size, and loading policy", () => {
  assert.doesNotMatch(page, /implementation-assets|fpw-common-boating-emergencies-hero-reference|fpw-person-overboard-reference/i);
  assert.equal(countMatches(page, /<figure class="fpw-emergency-figure/g), 11);
  assert.equal(countMatches(page, /<picture>/g), 11);
  assert.equal(countMatches(page, /<figcaption>/g), 11);
  assert.equal(countMatches(page, new RegExp(`<p>${escapeRegExp(paceNote)}</p>`, "g")), 1);
  assert.doesNotMatch(page, /boating-emergency-pace-first-minute/);

  for (const [stem, width, height, alt, caption] of figureAssets) {
    const versionSuffix = ["person-overboard-controlled-recovery", "overdue-boater-response-information-chain"].includes(stem)
      ? "\\?v=20260823-owner-approved"
      : ["boat-engine-compartment-fire-response", "boating-storm-early-shelter-decision"].includes(stem)
        ? "\\?v=20260823-owner-approved-v2"
        : "";
    const imageMatch = page.match(new RegExp(`<img\\b[^\\n]*${escapeRegExp(stem)}\\.jpg[^\\n]*>`));
    assert.ok(imageMatch, `Missing fallback image tag for ${stem}`);
    const imageTag = imageMatch[0];
    assert.match(imageTag, new RegExp(`width="${width}"`));
    assert.match(imageTag, new RegExp(`height="${height}"`));
    assert.match(imageTag, new RegExp(`alt="${escapeRegExp(alt)}"`));
    assert.match(imageTag, /decoding="async"/);
    assert.match(page, new RegExp(`${escapeRegExp(stem)}-640w\\.webp${versionSuffix} 640w`));
    assert.match(page, new RegExp(`${escapeRegExp(stem)}-960w\\.webp${versionSuffix} 960w`));
    assert.match(page, new RegExp(`${escapeRegExp(stem)}\\.webp${versionSuffix} ${width}w`));
    assert.equal(page.includes(`<figcaption>${caption}</figcaption>`), true, `Missing caption for ${stem}`);

    for (const suffix of ["-640w.webp", "-960w.webp", ".webp", "-640w.jpg", "-960w.jpg", ".jpg"]) {
      const relativePath = path.join(imageDirectory, `${stem}${suffix}`);
      assert.equal(existsSync(path.join(repositoryRoot, relativePath)), true, `Missing derivative ${relativePath}`);
      assert.ok(statSync(path.join(repositoryRoot, relativePath)).size > 0, `Empty derivative ${relativePath}`);
    }

    if (stem === "common-boating-emergencies-hero") {
      assert.doesNotMatch(imageTag, /loading="lazy"/);
      assert.match(imageTag, /fetchpriority="high"/);
    } else {
      assert.match(imageTag, /loading="lazy"/);
      assert.doesNotMatch(imageTag, /fetchpriority=/);
    }
  }
  assert.equal(countMatches(page, new RegExp(`alt="${escapeRegExp(fireAlt)}"`, "g")), 1);
  assert.equal(countMatches(page, new RegExp(`<figcaption>${escapeRegExp(fireCaption)}</figcaption>`, "g")), 1);
  assert.equal(countMatches(page, /boat-engine-compartment-fire-response(?:-640w|-960w)?\.(?:jpg|webp)\?v=20260823-owner-approved-v2/g), 7);
  assert.equal(countMatches(page, new RegExp(`alt="${escapeRegExp(stormAlt)}"`, "g")), 1);
  assert.equal(countMatches(page, new RegExp(`<figcaption>${escapeRegExp(stormCaption)}</figcaption>`, "g")), 1);
  assert.doesNotMatch(page, /alt="Sport cruiser proceeding slowly through a marked no-wake channel toward a protected canal, with a red buoy to the left, a green buoy to the right, a shoal alongside the channel and an ominous storm behind the boat\."/);
  assert.equal(countMatches(page, /boating-storm-early-shelter-decision(?:-640w|-960w)?\.(?:jpg|webp)\?v=20260823-owner-approved-v2/g), 7);
  assert.equal(countMatches(page, new RegExp(`alt="${escapeRegExp(maydayAlt)}"`, "g")), 1);
  assert.doesNotMatch(page, /alt="A boat operator uses the VHF while reading position and vessel details from a prepared emergency card\."/);
  assert.equal(countMatches(page, new RegExp(`alt="${escapeRegExp(engineFailureAlt)}"`, "g")), 1);
  assert.doesNotMatch(page, /alt="A disabled boat drifts toward a hazard while the crew checks position and prepares an anchor\."/);
  assert.equal(countMatches(page, new RegExp(`alt="${escapeRegExp(groundingAlt)}"`, "g")), 1);
  assert.doesNotMatch(page, /alt="A grounded boat is assessed for damage while a contrasting scene shows sediment churned by immediately reversing\."/);
  assert.equal(countMatches(page, new RegExp(`alt="${escapeRegExp(personOverboardAlt)}"`, "g")), 1);
  assert.doesNotMatch(page, /alt="A crew keeps pointing to a person overboard as the operator makes a slow return toward thrown flotation and a boarding ladder\."/);
  assert.equal(countMatches(page, /person-overboard-controlled-recovery(?:-640w|-960w)?\.(?:jpg|webp)\?v=20260823-owner-approved/g), 7);
  assert.equal(countMatches(page, new RegExp(`alt="${escapeRegExp(overdueAlt)}"`, "g")), 1);
  assert.doesNotMatch(page, /alt="A boater, shore contact, and rescue coordinator share the same boat, route, passenger, and timing information\."/);
  assert.equal(countMatches(page, /overdue-boater-response-information-chain(?:-640w|-960w)?\.(?:jpg|webp)\?v=20260823-owner-approved/g), 7);
});

test("both emergency-card PDFs are direct visible downloads with stable filenames", () => {
  const files = [
    "floatplanwizard-boating-emergency-card-4x6.pdf",
    "floatplanwizard-boating-emergency-card-letter.pdf"
  ];
  assert.equal(countMatches(page, /data-fpw-guide-card/g), 2);
  for (const fileName of files) {
    assert.match(page, new RegExp(`href="<cfoutput>#fpwEmergencyBasePath#<\\/cfoutput>\\/downloads\\/${escapeRegExp(fileName)}"`));
    assert.match(page, new RegExp(`download="${escapeRegExp(fileName)}"`));
    assert.match(page, new RegExp(`data-file-name="${escapeRegExp(fileName)}" data-placement="download_section"`));
    const pdfPath = path.join(repositoryRoot, "downloads", fileName);
    assert.equal(existsSync(pdfPath), true, `Missing PDF ${fileName}`);
    assert.equal(readFileSync(pdfPath).subarray(0, 5).toString("ascii"), "%PDF-");
  }
});

test("analytics use the required low-cardinality event and parameter contracts", () => {
  for (const eventName of [
    "guide_print_select",
    "guide_toc_select",
    "guide_card_download",
    "guide_cta_select",
    "guide_source_select"
  ]) {
    assert.match(script, new RegExp(`track\\("${eventName}"`));
  }
  for (const field of [
    "guide_id",
    "file_name",
    "placement",
    "section_id",
    "cta_name",
    "destination_path",
    "source_org",
    "destination_host"
  ]) {
    assert.equal(script.includes(`${field}:`), true, `Missing analytics field ${field}`);
  }
  assert.match(script, /window\.__fpwBoatingEmergencyGuideBound/);
  assert.equal(countMatches(script, /document\.addEventListener\("click"/g), 1);
  assert.equal(countMatches(script, /track\("guide_card_download"/g), 1);
  assert.match(script, /event\.target\.closest\("\[data-fpw-guide-card\]"\)/);
  assert.doesNotMatch(script, /preventDefault\(\)/);
  assert.doesNotMatch(script, /email|phone|latitude|longitude|vessel|user_id/i);
});

test("styles provide responsive, focus, reduced-motion, table, and print foundations", () => {
  assert.match(page, /common-boating-emergencies\.css\?v=20260823-fuel-dock/);
  assert.match(page, /common-boating-emergencies\.js\?v=20260822-phase2/);
  assert.match(stylesheet, /body\.fpw-emergency-body/);
  assert.match(stylesheet, /\.fpw-emergency-content > section \{[\s\S]*?scroll-margin-top: 116px;/);
  assert.match(stylesheet, /\.fpw-emergency-table-region \{[\s\S]*?overflow-x: auto;/);
  assert.match(stylesheet, /\.fpw-emergency-table-region:focus-visible/);
  assert.match(stylesheet, /\.fpw-emergency-rail \{[\s\S]*?position: sticky;/);
  assert.match(stylesheet, /@media \(max-width: 1100px\)[\s\S]*?\.fpw-emergency-rail \{[\s\S]*?position: static;/);
  assert.match(stylesheet, /@media \(max-width: 800px\)/);
  assert.match(stylesheet, /@media \(max-width: 480px\)/);
  assert.match(stylesheet, /\.fpw-emergency-figure img \{[\s\S]*?width: 100%;[\s\S]*?height: auto;/);
  assert.match(stylesheet, /\.fpw-emergency-card-downloads \{[\s\S]*?grid-template-columns: repeat\(2/);
  assert.match(stylesheet, /@media \(max-width: 800px\)[\s\S]*?\.fpw-emergency-card-downloads \{[\s\S]*?grid-template-columns: 1fr;/);
  assert.match(stylesheet, /@media \(prefers-reduced-motion: reduce\)/);
  assert.match(stylesheet, /@media print/);
  assert.match(stylesheet, /body\.fpw-emergency-body > header,[\s\S]*?body\.fpw-emergency-body > footer/);
  assert.doesNotMatch(stylesheet, /@media print[\s\S]*?\.fpw-emergency-figure,\s*\.fpw-emergency-card-downloads/);
  assert.match(stylesheet, /@media print[\s\S]*?\.fpw-emergency-figure picture \{[\s\S]*?display: none !important;/);
  assert.match(stylesheet, /@media print[\s\S]*?\.fpw-emergency-figure figcaption \{[\s\S]*?background: #ffffff !important;[\s\S]*?font-size: 10pt;/);
});

test("production clean route and sitemap expose the canonical page once", () => {
  assert.match(webConfig, /\^common-boating-emergencies\\\.cfm\$/);
  assert.match(webConfig, /\^common-boating-emergencies\$/);
  assert.match(webConfig, /\^common-boating-emergencies\/\$/);
  assert.match(webConfig, /url="\/common-boating-emergencies\.cfm"/);
  assert.equal(countMatches(sitemap, new RegExp(escapeRegExp(canonical), "g")), 1);
  assert.match(sitemap, /<loc>https:\/\/floatplanwizard\.com\/common-boating-emergencies\/<\/loc>\s*<lastmod>2026-08-22<\/lastmod>/);
});
