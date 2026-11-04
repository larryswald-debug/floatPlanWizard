const { test, expect } = require("@playwright/test");

// Exercise the real local library templates without signing in or changing any records.
const base = "http://localhost:8500/fpw";
const canonicalOrigin = "https://floatplanwizard.com";
const loopGuide = "/great-loop/trip-planning/";
const chesapeakeGuide = "/boating-guides/chesapeake-bay/";
const cases = [
  {
    path: "/great-loop/ports/168-new-bern-nc/", title: "New Bern",
    guide: loopGuide + "#generate-route", panel: ".fpw-ports-add-waypoint-panel"
  },
  {
    path: "/great-loop/anchorages/chesapeake-city-anchorage-basin-chesapeake-city-md/",
    title: "Chesapeake City anchorage basin", guide: chesapeakeGuide + "#overnight-alternatives"
  },
  {
    path: "/great-loop/bridges/tom-adams-bridge-glb-0008/", title: "Tom Adams Bridge",
    guide: loopGuide + "#boat-limits"
  },
  {
    path: "/great-loop/locks/olmsted-locks-and-dam/", title: "Olmsted Locks and Dam",
    guide: loopGuide + "#lock-timing"
  }
];

test.use({ javaScriptEnabled: false, viewport: { width: 390, height: 844 } });

for (const record of cases) {
  test("guest can read and continue planning from " + record.title, async ({ page }) => {
    const response = await page.goto(base + record.path, { waitUntil: "domcontentloaded" });
    expect(response.status()).toBe(200);
    const main = page.getByRole("main");
    await expect(main.getByRole("heading", { level: 1 })).toHaveText(record.title);
    await expect(main.getByRole("navigation", { name: "Breadcrumb" })).toBeVisible();
    await expect(page.locator('link[rel="canonical"]')).toHaveAttribute("href", canonicalOrigin + record.path);

    const documents = await page.locator('script[type="application/ld+json"]').allTextContents();
    const nodes = documents.flatMap(text => JSON.parse(text)["@graph"] || []);
    expect(nodes.find(node => node["@type"] === "WebPage").url).toBe(canonicalOrigin + record.path);
    expect(nodes.some(node => node["@type"] === "BreadcrumbList")).toBe(true);

    const panel = main.locator(record.panel || "[data-library-waypoint]");
    await expect(panel.getByRole("link", { name: "Log in", exact: true })).toHaveAttribute("href", "/fpw/app/login.cfm");
    await expect(panel.getByRole("link", { name: "join FPW", exact: true })).toHaveAttribute("href", "/fpw/app/join.cfm");
    await expect(panel.getByRole("button", { name: "Add to My Waypoints" })).toHaveCount(0);

    const guide = main.locator('a[href="/fpw' + record.guide + '"]');
    await expect(guide).toBeVisible();
    await expect(guide).toHaveAccessibleName(/\S/);
    await guide.focus();
    await expect(guide).toBeFocused();
    // The family styles may lighten focused text to white. Reject dark UA link colors.
    const linkColor = await guide.evaluate(link => getComputedStyle(link).color);
    expect(linkColor).not.toMatch(/^rgb\(0, 0, (238|255)\)$/);
    expect(await guide.evaluate(link => getComputedStyle(link).outlineStyle)).not.toBe("none");
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    await guide.click();
    await expect(page.locator(record.guide.slice(record.guide.indexOf("#")))).toHaveCount(1);
  });
}

test("system-wide bridge keeps its regional warning alongside the waypoint action", async ({ page }) => {
  await page.goto(base + "/great-loop/bridges/trent-severn-minimum-fixed-bridge-clearance-glb-0006/", { waitUntil: "domcontentloaded" });
  const panel = page.locator("[data-library-waypoint]");
  await expect(panel).toContainText("multiple locations");
  await expect(panel.locator("[data-library-waypoint-save]")).toHaveCount(1);
  await expect(panel.getByRole("link", { name: "Log in" })).toBeVisible();
  await expect(panel.getByRole("button", { name: "Add to My Waypoints" })).toHaveCount(0);
  await expect(page.locator("main a").filter({ hasText: "parks.canada.ca bridge reference" })).toHaveAttribute("href", /^https:\/\/parks\.canada\.ca\//);
});

test("a bridge awaiting coordinate review offers the same waypoint action", async ({ page }) => {
  await page.goto(base + "/great-loop/bridges/emerald-isle-b-cameron-langston-bridge-glb-0064/", { waitUntil: "domcontentloaded" });
  const panel = page.locator("[data-library-waypoint]");
  await expect(panel.locator("[data-library-waypoint-save]")).toHaveText("Add to My Waypoints");
  await expect(panel.getByRole("link", { name: "Log in" })).toBeVisible();
  await expect(panel.getByRole("link", { name: "join FPW" })).toBeVisible();
});

test("anchorage names without the category word retain it and regional links stay local", async ({ page }) => {
  await page.goto(base + "/great-loop/anchorages/browning-cove-little-current-on/", { waitUntil: "domcontentloaded" });
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("Browning Cove Anchorage");
  await expect(page).toHaveTitle("Browning Cove Anchorage Guide | FloatPlanWizard");
  await expect(page.locator('main a[href="/fpw' + loopGuide + '#overnight-stops"]')).toHaveCount(1);
  await expect(page.locator('main a[href="/fpw' + chesapeakeGuide + '#overnight-alternatives"]')).toHaveCount(0);
});

test("a port without a source has no empty source link or source panel", async ({ page }) => {
  await page.goto(base + cases[0].path, { waitUntil: "domcontentloaded" });
  await expect(page.getByRole("heading", { name: "Reference Source" })).toHaveCount(0);
  await expect(page.locator('main a[href=""]')).toHaveCount(0);
});
