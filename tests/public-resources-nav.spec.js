const { test, expect } = require("@playwright/test");

const baseUrl = "http://localhost:8500/fpw";
const guideUrl = `${baseUrl}/shore-contact-overdue-boater.cfm`;

function collectPageErrors(page) {
  const errors = [];
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(`console: ${message.text()}`);
  });
  page.on("pageerror", (error) => errors.push(`pageerror: ${error.message}`));
  return errors;
}

test("public Resources navigation fits and behaves at every required width", async ({ page }) => {
  const pageErrors = collectPageErrors(page);
  const widths = [1440, 1280, 1100, 1024, 760, 390];

  for (const width of widths) {
    await page.setViewportSize({ width, height: 900 });
    const response = await page.goto(guideUrl, { waitUntil: "domcontentloaded" });
    expect(response && response.status()).toBe(200);

    expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBe(width);

    const primaryLabels = await page.locator(".fpw-primary-nav > .fpw-nav-link, .fpw-primary-nav > .fpw-dropdown")
      .evaluateAll((items) => items.map((item) => {
        if (item.classList.contains("fpw-dropdown--mega")) return "Great Loop";
        if (item.classList.contains("fpw-dropdown--tools")) return "Tools";
        if (item.classList.contains("fpw-dropdown--resources")) return "Resources";
        return item.textContent.trim().replace(/\s+/g, " ");
      }));
    expect(primaryLabels).toEqual([
      "How It Works",
      "Features",
      "Great Loop",
      "Tools",
      "Resources",
      "Pricing"
    ]);

    const resources = page.locator(".fpw-dropdown--resources");
    const resourcesToggle = resources.locator("[data-fpw-dropdown-toggle]");
    const mobileToggle = page.locator("[data-fpw-mobile-toggle]");

    if (width > 1050) {
      await expect(mobileToggle).toBeHidden();
      await expect(resourcesToggle).toBeVisible();
      await expect(page.getByRole("link", { name: "Start Free" })).toBeVisible();
      await expect(page.getByRole("link", { name: "Login" })).toBeVisible();
    } else {
      await expect(mobileToggle).toBeVisible();
      await mobileToggle.click();
      await expect(mobileToggle).toHaveAttribute("aria-expanded", "true");
      await expect(resourcesToggle).toBeVisible();
    }

    await resourcesToggle.click();
    await expect(resourcesToggle).toHaveAttribute("aria-expanded", "true");
    await expect(resources).toHaveClass(/is-open/);

    const resourceLabels = await resources.locator('[role="menuitem"]')
      .evaluateAll((items) => items.map((item) => item.innerText.trim().replace(/\s+/g, " ")));
    expect(resourceLabels).toEqual([
      "Shore Contact Guide What to do when a boater misses a check-in or expected return. →",
      "Why Use a Float Plan →",
      "How It Works →",
      "FAQ →"
    ]);

    if (width > 1050) {
      const panelBox = await resources.locator(".fpw-resources-menu").boundingBox();
      expect(panelBox.x).toBeGreaterThanOrEqual(0);
      expect(panelBox.x + panelBox.width).toBeLessThanOrEqual(width);
      await page.keyboard.press("Escape");
      await expect(resourcesToggle).toHaveAttribute("aria-expanded", "false");
    } else {
      await resourcesToggle.click();
      await expect(resourcesToggle).toHaveAttribute("aria-expanded", "false");
      await page.locator("[data-fpw-mobile-close]").click();
      await expect(mobileToggle).toHaveAttribute("aria-expanded", "false");
    }
  }

  expect(pageErrors).toEqual([]);
});

test("existing dropdown exclusivity, outside click, Escape, and focus behavior remain intact", async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 900 });
  await page.goto(guideUrl, { waitUntil: "domcontentloaded" });

  const resourcesToggle = page.locator(".fpw-dropdown--resources [data-fpw-dropdown-toggle]");
  const toolsToggle = page.locator(".fpw-dropdown--tools [data-fpw-dropdown-toggle]");
  const greatLoopToggle = page.locator(".fpw-dropdown--mega [data-fpw-dropdown-toggle]");

  await resourcesToggle.click();
  await toolsToggle.click();
  await expect(resourcesToggle).toHaveAttribute("aria-expanded", "false");
  await expect(toolsToggle).toHaveAttribute("aria-expanded", "true");

  await page.locator("main").click({ position: { x: 5, y: 5 } });
  await expect(toolsToggle).toHaveAttribute("aria-expanded", "false");

  await greatLoopToggle.focus();
  await expect(greatLoopToggle).toBeFocused();
  await expect(greatLoopToggle).toHaveAttribute("aria-expanded", "true");
  await page.keyboard.press("Escape");
  await expect(greatLoopToggle).toHaveAttribute("aria-expanded", "false");
  await expect(greatLoopToggle).not.toBeFocused();
});

test("guide route activates Resources and emits one non-blocking click event", async ({ page }) => {
  await page.goto(guideUrl, { waitUntil: "domcontentloaded" });

  const resourcesToggle = page.locator(".fpw-dropdown--resources [data-fpw-dropdown-toggle]");
  const guideLink = page.locator(".fpw-resource-feature");
  await expect(resourcesToggle).toHaveClass(/is-active/);
  await expect(guideLink).toHaveClass(/is-active/);
  await expect(guideLink).toHaveAttribute("aria-current", "page");

  await page.evaluate(() => {
    window.__fpwPublicNavEvents = [];
    window.FPWAnalytics.track = (name, fields) => window.__fpwPublicNavEvents.push({ name, fields });
    window.__fpwStopGuideNavigation = (event) => {
      if (event.target.closest(".fpw-resource-feature")) event.preventDefault();
    };
    document.addEventListener("click", window.__fpwStopGuideNavigation, true);
  });
  await guideLink.click();

  expect(await page.evaluate(() => window.__fpwPublicNavEvents)).toEqual([{
    name: "public_nav_shore_contact_guide_click",
    fields: {
      source_page: "/fpw/shore-contact-overdue-boater.cfm",
      nav_location: "resources_dropdown",
      label: "Shore Contact Guide",
      destination_key: "shore_contact_overdue_boater",
      auth_state: "signed_out"
    }
  }]);

  await page.evaluate(() => {
    document.removeEventListener("click", window.__fpwStopGuideNavigation, true);
    window.FPWAnalytics.track = () => { throw new Error("intentional analytics failure"); };
  });
  await Promise.all([
    page.waitForURL(`${baseUrl}/shore-contact-overdue-boater/`),
    guideLink.click()
  ]);
  expect(page.url()).toBe(`${baseUrl}/shore-contact-overdue-boater/`);
});

test("footer, homepage context, and raw resource destinations remain live", async ({ page }) => {
  for (const path of ["/", "/shore-contact-overdue-boater.cfm", "/why-use-a-float-plan.cfm", "/faq/index.cfm"]) {
    const response = await page.goto(`${baseUrl}${path}`, { waitUntil: "domcontentloaded" });
    expect(response && response.status(), path).toBe(200);
  }

  await page.goto(`${baseUrl}/index.cfm`, { waitUntil: "domcontentloaded" });
  const contextualLink = page.getByRole("link", { name: "Read the Shore Contact Guide" });
  await expect(contextualLink).toHaveCount(1);
  await expect(contextualLink).toHaveAttribute("href", "/fpw/shore-contact-overdue-boater/");

  const footerLink = page.locator(".fpw-footer-plan-links").getByRole("link", { name: "Shore Contact Guide" });
  await expect(footerLink).toHaveCount(1);
  await expect(footerLink).toHaveAttribute("href", "/fpw/shore-contact-overdue-boater/");

  await page.setViewportSize({ width: 390, height: 844 });
  await page.reload({ waitUntil: "domcontentloaded" });
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBe(390);
  await expect(footerLink).toBeVisible();
});
