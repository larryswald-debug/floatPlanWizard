import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));
const read = (relativePath) => readFileSync(path.join(repositoryRoot, relativePath), "utf8");

function decodeHtml(value) {
  const named = {
    amp: "&",
    apos: "'",
    gt: ">",
    hellip: "…",
    ldquo: "“",
    lt: "<",
    mdash: "—",
    nbsp: " ",
    ndash: "–",
    quot: '"',
    rdquo: "”",
    rsquo: "’",
    rarr: "→"
  };

  return value
    .replace(/&([a-z]+);/gi, (match, name) => named[name.toLowerCase()] ?? match)
    .replace(/&#x([0-9a-f]+);/gi, (_, value) => String.fromCodePoint(Number.parseInt(value, 16)))
    .replace(/&#([0-9]+);/g, (_, value) => String.fromCodePoint(Number.parseInt(value, 10)));
}

function compactText(value) {
  return decodeHtml(value)
    .replace(/<!---[\s\S]*?--->/g, " ")
    .replace(/<script\b[\s\S]*?<\/script>/gi, " ")
    .replace(/<style\b[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function assertVisibleCopy(source, expected) {
  assert.equal(
    compactText(source).includes(compactText(expected)),
    true,
    `Missing required visible copy: ${expected}`
  );
}

function stripCfOutputTags(source) {
  return source.replace(/<\/?cfoutput>/gi, "");
}

function resolveCfmlString(source, value) {
  const expression = value.match(/^#(?:encodeForHtml(?:Attribute)?\()?([a-z][\w]*)\)?#$/i);
  if (!expression) return value;

  const constants = new Map(
    [...source.matchAll(/^\s*([a-z][\w]*)\s*=\s*"([^"]*)";\s*$/gim)]
      .map((match) => [match[1], match[2]])
  );
  return constants.get(expression[1]) ?? value;
}

function parseAttributes(tag) {
  const attributes = {};
  const pattern = /([:@a-z][:\w.-]*)\s*=\s*(["'])([\s\S]*?)\2/gi;
  for (const match of tag.matchAll(pattern)) {
    attributes[match[1].toLowerCase()] = decodeHtml(match[3]);
  }
  return attributes;
}

function tags(source, tagName) {
  const cleanSource = stripCfOutputTags(source);
  return [...cleanSource.matchAll(new RegExp(`<${tagName}\\b[^>]*>`, "gi"))].map((match) => match[0]);
}

function metaValues(source, key, name) {
  return tags(source, "meta")
    .map(parseAttributes)
    .filter((attributes) => attributes[key] === name)
    .map((attributes) => resolveCfmlString(source, attributes.content));
}

function assertUniqueMeta(source, key, name, expected) {
  const values = metaValues(source, key, name);
  assert.deepEqual(values, [expected], `${name} must be present exactly once with the required value`);
}

function anchorByText(source, text) {
  const anchors = stripCfOutputTags(source).match(/<a\b[^>]*>[\s\S]*?<\/a>/gi) || [];
  return anchors.find((anchor) => compactText(anchor).includes(text)) || "";
}

function jsonLdBlocks(source) {
  return [...source.matchAll(/<script\b[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi)]
    .map((match) => match[1].trim());
}

function assertRenderedAboutGraph(graphDocument) {
  assert.equal(graphDocument["@context"], "https://schema.org");
  assert.equal(Array.isArray(graphDocument["@graph"]), true);
  assert.equal(graphDocument["@graph"].length, 3);

  const entities = new Map(graphDocument["@graph"].map((entity) => [entity["@id"], entity]));
  const page = entities.get("https://floatplanwizard.com/about#webpage");
  const organization = entities.get("https://floatplanwizard.com/#organization");
  const founder = entities.get("https://floatplanwizard.com/about#larry-wald");

  assert.deepEqual(
    [...entities.keys()].sort(),
    [
      "https://floatplanwizard.com/#organization",
      "https://floatplanwizard.com/about#larry-wald",
      "https://floatplanwizard.com/about#webpage"
    ].sort()
  );
  assert.equal(page?.["@type"], "AboutPage");
  assert.equal(page?.url, "https://floatplanwizard.com/about");
  assert.equal(page?.name, "About FloatPlanWizard");
  assert.equal(page?.isPartOf?.["@id"], "https://floatplanwizard.com/#website");
  assert.equal(page?.about?.["@id"], "https://floatplanwizard.com/#organization");
  assert.equal(page?.mainEntity?.["@id"], "https://floatplanwizard.com/#organization");
  assert.equal(organization?.["@type"], "Organization");
  assert.equal(organization?.name, "FloatPlanWizard");
  assert.equal(organization?.founder?.["@id"], "https://floatplanwizard.com/about#larry-wald");
  assert.equal(founder?.["@type"], "Person");
  assert.equal(founder?.name, "Larry Wald");
  assert.equal(founder?.jobTitle, "Founder of FloatPlanWizard");
  assert.equal(founder?.worksFor?.["@id"], "https://floatplanwizard.com/#organization");
}

test("About page has the exact page and social metadata", () => {
  const about = read("about.cfm");
  const titles = [...about.matchAll(/<title\b[^>]*>([\s\S]*?)<\/title>/gi)]
    .map((match) => resolveCfmlString(about, compactText(match[1])));
  const canonicals = tags(about, "link")
    .map(parseAttributes)
    .filter((attributes) => attributes.rel === "canonical")
    .map((attributes) => attributes.href);

  assert.deepEqual(titles, ["About FloatPlanWizard | Built by a Solo Boater"]);
  assertUniqueMeta(
    about,
    "name",
    "description",
    "Learn why solo boater and retired web developer Larry Wald created FloatPlanWizard to make trip planning, float-plan sharing, monitoring, and family communication easier."
  );
  assert.deepEqual(canonicals, ["https://floatplanwizard.com/about"]);
  assertUniqueMeta(about, "name", "robots", "index,follow");
  assertUniqueMeta(about, "property", "og:type", "website");
  assertUniqueMeta(about, "property", "og:site_name", "FloatPlanWizard");
  assertUniqueMeta(about, "property", "og:title", "Why I Built FloatPlanWizard");
  assertUniqueMeta(
    about,
    "property",
    "og:description",
    "FloatPlanWizard began as a one-click way for a solo boater to send a saved float plan to his family."
  );
  assertUniqueMeta(about, "property", "og:url", "https://floatplanwizard.com/about");
  assertUniqueMeta(about, "name", "twitter:card", "summary_large_image");
  assertUniqueMeta(about, "name", "twitter:title", "Why I Built FloatPlanWizard");
  assertUniqueMeta(
    about,
    "name",
    "twitter:description",
    "The story of how a solo boater and retired web developer created FloatPlanWizard."
  );

  const ogImage = metaValues(about, "property", "og:image");
  const twitterImage = metaValues(about, "name", "twitter:image");
  assert.equal(ogImage.length, 1);
  assert.match(ogImage[0], /^https:\/\/floatplanwizard\.com\/assets\/images\/.+\.(?:jpg|jpeg|png|webp)$/i);
  assert.deepEqual(twitterImage, ogImage, "Open Graph and Twitter must use the same production image");
});

test("About page has one H1 and one exact AboutPage graph", () => {
  const about = read("about.cfm");
  const h1s = [...about.matchAll(/<h1\b[^>]*>([\s\S]*?)<\/h1>/gi)].map((match) => compactText(match[1]));
  const blocks = jsonLdBlocks(about);

  assert.deepEqual(h1s, ["Built by a Solo Boater Who Needed a Better Way"]);
  assert.equal(blocks.length, 1);

  if (!/<cf/i.test(blocks[0])) {
    assertRenderedAboutGraph(JSON.parse(blocks[0]));
    return;
  }

  // CFML serializes the graph at runtime; source-contract the exact entities and render path here.
  const normalized = about.replaceAll("##", "#");
  assert.match(about, /serializeJSON\(/);
  for (const type of ["AboutPage", "Organization", "Person"]) {
    assert.match(about, new RegExp(`["']${type}["']`));
  }
  for (const id of [
    "https://floatplanwizard.com/#organization",
    "https://floatplanwizard.com/#website",
    "https://floatplanwizard.com/about#webpage",
    "https://floatplanwizard.com/about#larry-wald"
  ]) {
    const [base, fragment] = id.split("#");
    assert.equal(
      normalized.includes(id) || (normalized.includes(base) && normalized.includes(`#${fragment}`)),
      true,
      `Missing schema ID contract: ${id}`
    );
  }
  for (const value of [
    "About FloatPlanWizard",
    "The story behind FloatPlanWizard and why it was created for solo boaters, recreational captains, and their families.",
    "Larry Wald",
    "Founder of FloatPlanWizard",
    "A recreational solo boater and retired professional web developer with more than 30 years of website-development experience."
  ]) {
    assert.equal(about.includes(value), true, `Missing schema value: ${value}`);
  }
  for (const property of ["isPartOf", "about", "mainEntity", "founder", "worksFor"]) {
    assert.match(about, new RegExp(`["']${property}["']`));
  }
});

test("About page contains every required story section and core copy", () => {
  const about = read("about.cfm");
  const requiredHeadings = [
    "Why I Built FloatPlanWizard",
    "The Original FloatPlanWizard",
    "Built From Real Experience",
    "More Than a Float Plan",
    "Especially Valuable for Solo Boaters",
    "Our Mission",
    "A Tool That Came From Real Boating",
    "Plan Ahead Before You Leave the Dock"
  ];
  const requiredCopy = [
    "THE STORY BEHIND FLOATPLANWIZARD",
    "FloatPlanWizard began as a simple way to send my family a saved float plan whenever I headed out alone. Today, it helps boaters plan trips, share their journey, and keep the people waiting at home informed.",
    "FloatPlanWizard began with a simple personal need.",
    "I go boating alone most of the time, and I wanted an easy, dependable way to let my family know where I planned to go, when I expected to return, and what information they would need if something did not go according to plan.",
    "I did not want to recreate the same float plan every time I used the boat. I wanted to save my information once, prepare the trip ahead of time, and send the plan when I was ready to leave.",
    "So I built it.",
    "Save the plan. Send it with one click. Let your family know.",
    "Save Your Plan",
    "Send Before Departure",
    "Keep Family Informed",
    "FloatPlanWizard brings together two major parts of my life: boating and professional web development.",
    "For more than 30 years, I worked directly on websites, applications, databases, integrations, and the everyday problems that come with building technology people actually depend on.",
    "Now that I am retired, I can build the boating website I always wanted to use—one based on practical boating needs instead of corporate deadlines, committees, or short-term trends.",
    "Plan Your Trip",
    "Send Your Float Plan",
    "Stay Connected",
    "Share the Journey",
    "Especially valuable for solo boaters. Useful for every captain.",
    "Safety Before Complexity",
    "Useful Tools Should Be Accessible",
    "The Captain Remains in Control",
    "Families Should Not Be Left Guessing",
    "Useful Technology Should Feel Simple",
    "FloatPlanWizard was not created from a theoretical business idea.",
    "Help boaters prepare for the trip, stay connected on the water, and give the people waiting at home greater peace of mind.",
    "Larry Wald",
    "Founder, FloatPlanWizard",
    "Solo Boater and Retired Professional Web Developer",
    "Your trip should not begin with your family wondering where you are going.",
    "Create Your Free Account",
    "See How It Works",
    "Start Planning Your Next Trip"
  ];

  for (const heading of requiredHeadings) assertVisibleCopy(about, heading);
  for (const copy of requiredCopy) assertVisibleCopy(about, copy);

  const visible = compactText(about);
  for (const prohibited of [
    /industry-leading/i,
    /automatic(?:ally)? GPS tracking/i,
    /continuous live (?:GPS |vessel )?tracking/i,
    /real[- ]time tracking/i,
    /guarantee(?:s|d)? (?:safety|rescue)/i,
    /Coast Guard service/i,
    /dispatch(?:es|ing)? (?:help|rescue|assistance)/i
  ]) {
    assert.doesNotMatch(visible, prohibited);
  }
});

test("homepage founder story and schema link to the full About story", () => {
  const founderSection = read("partials/fpw-conversion-landing.cfm");
  const home = read("index.cfm");
  const storyLink = anchorByText(founderSection, "Read the Story Behind FPW");

  for (const copy of [
    "THE STORY BEHIND FLOATPLANWIZARD",
    "Built by a Solo Boater, for Solo Boaters",
    "I cannot tell you how many times I had already left the dock and realized I had forgotten to send it. Instead of turning around, I could open the website, click a link, and have the saved plan sent for me.",
    "No rewriting the same trip details. No searching for information at the dock. Just a ready-to-send plan that gave my family greater peace of mind.",
    "— Larry W., Founder",
    "Solo boater and retired professional web developer with more than 55 years of boating experience.",
    "Create Your Float Plan"
  ]) {
    assertVisibleCopy(founderSection, copy);
  }
  assert.notEqual(storyLink, "");
  assert.equal(parseAttributes(storyLink).href.endsWith("/about"), true);
  assert.doesNotMatch(storyLink, /aria-disabled|role=["']link["']/i);

  const normalizedHome = home.replaceAll("##", "#");
  assert.equal(jsonLdBlocks(home).length, 1);
  assert.match(home, /["']ImageObject["']/);
  assert.equal(normalizedHome.includes("https://floatplanwizard.com/#organization"), true);
  assert.equal(normalizedHome.includes("https://floatplanwizard.com/#website"), true);
  assert.equal(normalizedHome.includes("https://floatplanwizard.com/about#larry-wald"), true);
  assert.equal(
    home.includes("A boating trip-planning, float-plan sharing, trip-following, check-in, and monitoring platform."),
    true
  );
});

test("shared footer exposes a crawlable About link and modern page variant", () => {
  const footer = read("includes/footer.cfm");
  const aboutLink = anchorByText(footer, "About FPW");

  assert.notEqual(aboutLink, "");
  assert.equal(parseAttributes(aboutLink).href.endsWith("/about"), true);
  assert.match(footer, /footerModernPagePaths\s*=\s*["'][^"']*\/about\.cfm/);
});

test("IIS rules normalize both alternate About URLs to one loop-safe clean route", () => {
  const config = read("web.config");
  const rules = config.match(/<rule\b[\s\S]*?<\/rule>/gi) || [];
  const aboutRules = rules.filter((rule) => /about/i.test(rule));
  const cfmRedirect = aboutRules.find((rule) => /\^about\\\.cfm\$/.test(rule)) || "";
  const slashRedirect = aboutRules.find((rule) => /\^about\/\$/.test(rule)) || "";
  const cleanRewrite = aboutRules.find((rule) => /\^about\$/.test(rule)) || "";

  assert.equal(aboutRules.length, 3);
  assert.match(cfmRedirect, /input="\{THE_REQUEST\}"[\s\S]*about\\\.cfm/);
  assert.match(cfmRedirect, /action type="Redirect"[\s\S]*url="\/about"[\s\S]*redirectType="Permanent"/);
  assert.match(slashRedirect, /action type="Redirect"[\s\S]*url="\/about"[\s\S]*redirectType="Permanent"/);
  assert.match(cleanRewrite, /action type="Rewrite"[\s\S]*url="\/about\.cfm"/);
  assert.doesNotMatch(config, /action type="Redirect"[\s\S]{0,160}url="\/about\/"/i);
});

test("sitemap lists only the canonical About URL and robots does not block it", () => {
  const sitemap = read("sitemap.xml");
  const robots = read("robots.txt");
  const locations = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map((match) => match[1].trim());
  const aboutLocations = locations.filter((location) => /floatplanwizard\.com\/about(?:\/|\.cfm)?$/.test(location));
  const disallowedPaths = [...robots.matchAll(/^Disallow:\s*(\S*)\s*$/gim)].map((match) => match[1]);

  assert.deepEqual(aboutLocations, ["https://floatplanwizard.com/about"]);
  assert.match(robots, /^Allow:\s*\/\s*$/m);
  assert.equal(disallowedPaths.some((rule) => rule && "/about".startsWith(rule)), false);
});
