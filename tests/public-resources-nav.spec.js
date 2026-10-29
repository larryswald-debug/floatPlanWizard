const { test, expect } = require("@playwright/test");

const baseUrl = process.env.FPW_BASE_URL || "http://127.0.0.1:8500/fpw";
const basePath = new URL(baseUrl).pathname.replace(/\/$/, "");
const guideUrl = baseUrl + "/shore-contact-overdue-boater/";
const categories = ["plan", "explore", "learn", "tools", "help"];
const primaryLabels = ["Plan a Trip", "Explore", "Learn", "Tools", "Help"];
const toggleFor = (page, category) => page.locator(".fpw-dropdown--" + category + " > [data-fpw-dropdown-toggle]");
const panelFor = (page, category) => page.locator("#fpw" + category[0].toUpperCase() + category.slice(1) + "Menu");
const href = (route) => basePath + route;

test.beforeEach(async ({ page }) => {
  await page.route(/https:\/\/(?:[^/]+\.)?(?:plausible\.io|google-analytics\.com|googletagmanager\.com|clarity\.ms)\//, route =>
    route.fulfill({ status: 200, contentType: "application/javascript", body: "" }));
});

function collectPageErrors(page) {
  const errors = [];
  page.on("console", message => {
    if (message.type() === "error") errors.push("console: " + message.text());
  });
  page.on("pageerror", error => errors.push("pageerror: " + error.message));
  return errors;
}

async function openNavigation(page, width) {
  if (width <= 1040) {
    await page.locator("[data-fpw-mobile-toggle]").click();
    await expect(page.locator("[data-fpw-mobile-toggle]")).toHaveAttribute("aria-expanded", "true");
  }
}

async function expectContained(page, locator) {
  const box = await locator.boundingBox();
  expect(box).not.toBeNull();
  expect(box.x).toBeGreaterThanOrEqual(-1);
  expect(box.x + box.width).toBeLessThanOrEqual(page.viewportSize().width + 1);
}

async function expectHeaderFits(page) {
  const boxes = await page.locator(
    ".fpw-brand:visible, .fpw-primary-nav > .fpw-dropdown > button:visible, " +
    ".fpw-primary-nav > a:visible, .fpw-nav-actions > a:visible, .fpw-nav-actions > .fpw-dropdown > button:visible"
  ).evaluateAll(nodes => nodes.map(node => {
    const rect = node.getBoundingClientRect();
    return { label: node.textContent.trim(), x: rect.x, right: rect.right, top: rect.top, bottom: rect.bottom };
  }));
  const width = page.viewportSize().width;
  for (const box of boxes) {
    expect(box.x, box.label + " left edge").toBeGreaterThanOrEqual(-1);
    expect(box.right, box.label + " right edge").toBeLessThanOrEqual(width + 1);
  }
  for (let i = 0; i < boxes.length; i++) {
    for (let j = i + 1; j < boxes.length; j++) {
      const a = boxes[i], b = boxes[j];
      const intersects = Math.min(a.right, b.right) - Math.max(a.x, b.x) > 1 &&
        Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top) > 1;
      expect(intersects, a.label + " must not overlap " + b.label).toBe(false);
    }
  }
}

test("approved shared navigation fits all required desktop, tablet, and mobile widths", async ({ page }) => {
  test.setTimeout(90_000);
  const errors = collectPageErrors(page);
  for (const width of [1920, 1440, 1280, 1100, 1099, 1041, 1024, 768, 430, 390]) {
    await page.setViewportSize({ width, height: 1000 });
    const response = await page.goto(guideUrl, { waitUntil: "domcontentloaded" });
    expect(response && response.status()).toBe(200);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    const labels = await page.locator(".fpw-primary-nav > .fpw-dropdown > [data-fpw-dropdown-toggle]")
      .evaluateAll(nodes => nodes.map(node => node.textContent.trim().replace(/\s+/g, " ")));
    expect(labels).toEqual(primaryLabels);
    await expect(page.locator(".fpw-site-header .search-trigger, .fpw-site-header [data-fpw-search]")).toHaveCount(0);
    if (width > 1040) {
      await expect(page.locator("[data-fpw-mobile-toggle]")).toBeHidden();
      await expectHeaderFits(page);
    } else {
      await expect(page.locator("[data-fpw-mobile-toggle]")).toBeVisible();
    }
    await openNavigation(page, width);
    await expect(page.locator(".fpw-nav-actions > a").first()).toBeVisible();
    const actionOrder = await page.locator(".fpw-nav-actions > a:visible").evaluateAll(nodes =>
      nodes.map(node => node.textContent.replace(/→/g, "").trim().replace(/\s+/g, " ")));
    expect(actionOrder).toEqual(width <= 1040 ? ["Start Free", "Pricing", "Login"] : ["Pricing", "Start Free", "Login"]);
    for (const category of categories) {
      const toggle = toggleFor(page, category);
      await toggle.click();
      await expect(toggle).toHaveAttribute("aria-expanded", "true");
      const panel = panelFor(page, category);
      await expect(panel).toBeVisible();
      await expectContained(page, panel);
      expect(await page.locator(".fpw-primary-nav > .fpw-dropdown > button[aria-expanded=true]").count()).toBe(1);
      const badLinks = await panel.locator("a").evaluateAll(nodes =>
        nodes.filter(node => !node.getAttribute("href") || node.getAttribute("href") === "#").length);
      expect(badLinks).toBe(0);
      if (width <= 1040) {
        const undersized = await panel.locator("a").evaluateAll(nodes =>
          nodes.filter(node => node.getBoundingClientRect().height < 47).map(node => node.textContent.trim()));
        expect(undersized).toEqual([]);
      }
    }
    await toggleFor(page, "explore").click();
    const explore = panelFor(page, "explore");
    await expect(explore.locator('a[href="' + href("/boating-guides/chesapeake-bay/") + '"]')).toBeVisible();
    await expect(explore.locator('a[href="' + href("/great-loop/trip-planning/") + '"]')).toBeVisible();
    await expect(explore.locator('a[href="' + href("/boating-guides/") + '"]')).toContainText("All Cruising Guides");
    await expect(explore.locator('a[href="' + href("/fpw_great_loop_clockwise/index.html#search") + '"]')).toHaveCount(0);
    await page.keyboard.press("Escape");
    await expect(toggleFor(page, "explore")).toHaveAttribute("aria-expanded", "false");
    if (width <= 1040) {
      await expect(page.locator("[data-fpw-mobile-toggle]")).toHaveAttribute("aria-expanded", "false");
      await expect(page.locator("[data-fpw-mobile-toggle]")).toBeFocused();
    }
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  }
  expect(errors).toEqual([]);
});

test("menus are click-only, exclusive, dismissible, and keyboard accessible", async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 900 });
  await page.goto(guideUrl, { waitUntil: "domcontentloaded" });
  const explore = toggleFor(page, "explore");
  await explore.hover();
  await page.waitForTimeout(250);
  await expect(explore).toHaveAttribute("aria-expanded", "false");
  await explore.focus();
  await expect(explore).toHaveAttribute("aria-expanded", "false");
  await page.keyboard.press("Enter");
  await expect(explore).toHaveAttribute("aria-expanded", "true");
  await page.keyboard.press("Tab");
  await expect(panelFor(page, "explore").locator("a").first()).toBeFocused();
  await page.keyboard.press("Escape");
  await expect(explore).toBeFocused();
  await expect(explore).toHaveAttribute("aria-expanded", "false");
  await explore.click();
  await toggleFor(page, "tools").click();
  await expect(explore).toHaveAttribute("aria-expanded", "false");
  await expect(toggleFor(page, "tools")).toHaveAttribute("aria-expanded", "true");
  await toggleFor(page, "tools").click();
  await expect(toggleFor(page, "tools")).toHaveAttribute("aria-expanded", "false");
  await toggleFor(page, "help").click();
  await page.locator("main").click({ position: { x: 4, y: 450 } });
  await expect(toggleFor(page, "help")).toHaveAttribute("aria-expanded", "false");
  const help = toggleFor(page, "help");
  await help.focus();
  await page.keyboard.press("ArrowDown");
  const links = panelFor(page, "help").locator("a");
  await expect(links.first()).toBeFocused();
  await page.keyboard.press("End");
  await expect(links.last()).toBeFocused();
  await page.keyboard.press("Home");
  await expect(links.first()).toBeFocused();
  await page.keyboard.press("ArrowUp");
  await expect(links.last()).toBeFocused();
  await page.keyboard.press("Escape");
  await expect(help).toBeFocused();
});

test("compact header retains all categories and actions without collisions", async ({ page }) => {
  for (const width of [1920, 1440, 1280, 1100]) {
    await page.setViewportSize({ width, height: 900 });
    await page.goto(guideUrl, { waitUntil: "domcontentloaded" });
    const expandedHeight = await page.locator("[data-fpw-nav]").evaluate(node => node.getBoundingClientRect().height);
    await page.evaluate(() => scrollTo(0, 600));
    await expect.poll(() => page.locator("[data-fpw-nav]").evaluate(node => node.getBoundingClientRect().height)).toBeLessThan(expandedHeight);
    for (const category of categories) await expect(toggleFor(page, category)).toBeVisible();
    await expect(page.locator(".fpw-nav-actions").getByRole("link", { name: "Start Free" })).toBeVisible();
    await expect(page.locator(".fpw-nav-actions").getByRole("link", { name: "Login" })).toBeVisible();
    await expectHeaderFits(page);
    await toggleFor(page, "explore").click();
    await expectContained(page, panelFor(page, "explore"));
    await page.keyboard.press("Escape");
  }
});

test("calculator remains reachable at desktop, mobile, and zoom-equivalent sizes", async ({ page }, testInfo) => {
  test.setTimeout(90_000);
  const errors = collectPageErrors(page);
  for (const route of ["/index.cfm", "/boat-loan-calculator/", "/shore-contact-overdue-boater/"]) {
    for (const size of [{ width: 1280, height: 720 }, { width: 1440, height: 900 }, { width: 390, height: 844 }, { width: 640, height: 360 }]) {
      await page.setViewportSize(size);
      await page.goto(baseUrl + route, { waitUntil: "domcontentloaded" });
      await openNavigation(page, size.width);
      await toggleFor(page, "tools").click();
      const tools = panelFor(page, "tools");
      const calculator = tools.locator('a[href="' + href("/boat-loan-calculator/") + '"]');
      await expect(calculator).toHaveCount(1);
      await expect(calculator).toContainText("Boat Loan & Ownership Calculator");
      await expect(calculator.locator("svg")).toHaveAttribute("aria-hidden", "true");
      await expect(calculator.locator("svg")).toHaveAttribute("focusable", "false");
      await calculator.focus();
      await expect(calculator).toBeFocused();
      await expect.poll(() => calculator.evaluate(node => {
        const box = node.getBoundingClientRect();
        return box.top >= 0 && box.bottom <= innerHeight + 1;
      })).toBe(true);
      const lastLink = tools.locator("a").last();
      await lastLink.focus();
      await expect.poll(() => lastLink.evaluate(node => {
        const box = node.getBoundingClientRect();
        return box.top >= 0 && box.bottom <= innerHeight + 1;
      })).toBe(true);
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
      if (route === "/boat-loan-calculator/") await page.screenshot({ path: testInfo.outputPath("tools-" + size.width + "x" + size.height + ".png") });
      await page.keyboard.press("Escape");
      await expect(toggleFor(page, "tools")).toHaveAttribute("aria-expanded", "false");
    }
  }
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.goto(baseUrl + "/index.cfm", { waitUntil: "domcontentloaded" });
  await toggleFor(page, "tools").click();
  await panelFor(page, "tools").locator('a[href="' + href("/boat-loan-calculator/") + '"]').click();
  await expect(page).toHaveURL(baseUrl + "/boat-loan-calculator/");
  await expect(page.locator("#boat-cost-title")).toHaveText("Boat Loan and Ownership Cost Calculator");
  await expect(page.locator("#bc-results")).toContainText("Your boating budget");
  expect(errors).toEqual([]);
});

test("guide and tool destinations select their correct new parent and child", async ({ page }) => {
  for (const [route, category, destination] of [
    ["/boat-loan-calculator/", "tools", "/boat-loan-calculator/"],
    ["/shore-contact-overdue-boater/", "learn", "/shore-contact-overdue-boater/"],
    ["/solo-boating-safety-guide/", "learn", "/solo-boating-safety-guide/"],
    ["/common-boating-emergencies/", "learn", "/common-boating-emergencies/"],
    ["/why-use-a-float-plan/", "learn", "/why-use-a-float-plan/"],
    ["/faq/", "help", "/faq/"],
    ["/boat-fuel-calculator/", "tools", "/boat-fuel-calculator/"],
    ["/boating-guides/chesapeake-bay/", "explore", "/boating-guides/chesapeake-bay/"],
    ["/boating-guides/", "explore", "/boating-guides/"]
  ]) {
    const response = await page.goto(baseUrl + route, { waitUntil: "domcontentloaded" });
    expect(response && response.status(), route).toBe(200);
    await expect(toggleFor(page, category)).toHaveClass(/is-active/);
    const child = panelFor(page, category).locator('a[href="' + href(destination) + '"][aria-current=page]');
    await expect(child).toHaveCount(1);
  }
});

test("guide analytics retain their exact one-event contracts and never control navigation", async ({ page }) => {
  await page.goto(guideUrl, { waitUntil: "domcontentloaded" });
  await page.evaluate(() => {
    window.__fpwPublicNavEvents = [];
    window.FPWAnalytics.track = (name, fields) => window.__fpwPublicNavEvents.push({ name, fields });
    window.__fpwStopGuideNavigation = event => {
      if (event.target.closest("[data-fpw-nav-track]")) event.preventDefault();
    };
    document.addEventListener("click", window.__fpwStopGuideNavigation, true);
  });
  const cases = [
    ["public_nav_boating_safety_click", "Boating Safety", "solo_boating_safety_guide"],
    ["public_nav_solo_boating_safety_guide_click", "Solo Boating Safety Guide", "solo_boating_safety_guide"],
    ["public_nav_common_boating_emergencies_click", "Common Boating Emergencies", "common_boating_emergencies"],
    ["public_nav_shore_contact_guide_click", "Shore Contact Guide", "shore_contact_overdue_boater"]
  ];
  for (const [name] of cases) {
    const toggle = toggleFor(page, "learn");
    if (await toggle.getAttribute("aria-expanded") !== "true") await toggle.click();
    await page.locator('[data-fpw-nav-track="' + name + '"]').click();
  }
  expect(await page.evaluate(() => window.__fpwPublicNavEvents)).toEqual(cases.map(([name, label, destination_key]) => ({
    name, fields: {
      source_page: href("/shore-contact-overdue-boater/"), nav_location: "public_header",
      menu_group: "resources", label, destination_key, auth_state: "signed_out"
    }
  })));
  await page.evaluate(() => {
    document.removeEventListener("click", window.__fpwStopGuideNavigation, true);
    window.FPWAnalytics.track = () => { throw new Error("intentional analytics failure"); };
  });
  if (await toggleFor(page, "learn").getAttribute("aria-expanded") !== "true") await toggleFor(page, "learn").click();
  await Promise.all([
    page.waitForURL(baseUrl + "/solo-boating-safety-guide/"),
    page.locator('[data-fpw-nav-track="public_nav_solo_boating_safety_guide_click"]').click()
  ]);
});

test("footer links, corrected icons, and menu IDs remain valid", async ({ page }) => {
  await page.goto(baseUrl + "/index.cfm", { waitUntil: "domcontentloaded" });
  const footer = page.locator(".fpw-footer-plan-links");
  for (const [label, destination] of [
    ["Boating Safety", "/solo-boating-safety-guide/"], ["Solo Boating Safety Guide", "/solo-boating-safety-guide/"],
    ["Common Boating Emergencies", "/common-boating-emergencies/"],
    ["Shore Contact / Overdue Boater Guide", "/shore-contact-overdue-boater/"]
  ]) await expect(footer.getByRole("link", { name: label, exact: true })).toHaveAttribute("href", href(destination));
  await expect(page.getByRole("link", { name: "Read the Shore Contact Guide", exact: true })).toHaveAttribute("href", href("/shore-contact-overdue-boater/"));
  const active = panelFor(page, "plan").locator('a[href="' + href("/app/active-cruise.cfm") + '"] svg');
  const mileage = panelFor(page, "tools").locator('a[href="' + href("/great-loop/trip-planning/#mileage-override") + '"] svg');
  await expect(active).toHaveAttribute("data-fpw-approved-icon", /(?:icon-)?boat-vessel(?:\.svg)?$/);
  await expect(mileage).toHaveAttribute("data-fpw-approved-icon", /(?:icon-)?mileage-override(?:\.svg)?$/);
  const ids = await page.locator(".fpw-site-header [id]").evaluateAll(nodes => nodes.map(node => node.id));
  expect(new Set(ids).size).toBe(ids.length);
});
