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

async function expectPublicNavWithinViewport(page) {
  const result = await page.evaluate(() => {
    const viewportWidth = document.documentElement.clientWidth;
    const selectors = [
      ".fpw-nav-inner",
      "[data-fpw-nav-menu]",
      ".fpw-primary-nav",
      ".fpw-nav-actions",
      ".fpw-dropdown--resources",
      ".fpw-resources-menu"
    ];
    const boxes = selectors.map((selector) => {
      const element = document.querySelector(selector);
      if (!element) return null;
      const box = element.getBoundingClientRect();
      return { selector, left: box.left, right: box.right };
    }).filter(Boolean);
    return { viewportWidth, boxes };
  });

  for (const box of result.boxes) {
    expect(box.left, `${box.selector} left edge`).toBeGreaterThanOrEqual(0);
    expect(box.right, `${box.selector} right edge`).toBeLessThanOrEqual(result.viewportWidth);
  }
}

test("public Resources navigation fits and behaves at every required width", async ({ page }) => {
  const pageErrors = collectPageErrors(page);
  const widths = [1440, 1280, 1100, 1024, 760, 390];

  for (const width of widths) {
    await page.setViewportSize({ width, height: 900 });
    const response = await page.goto(guideUrl, { waitUntil: "domcontentloaded" });
    expect(response && response.status()).toBe(200);
    if (width !== 1024) {
      expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBe(width);
    }

    const primaryLabels = await page.locator(".fpw-primary-nav > .fpw-nav-link, .fpw-primary-nav > .fpw-dropdown")
      .evaluateAll((items) => items.map((item) => {
        if (item.classList.contains("fpw-dropdown--mega")) return "Great Loop";
        if (item.classList.contains("fpw-dropdown--resources")) return "Resources";
        return item.textContent.trim().replace(/\s+/g, " ");
      }));
    expect(primaryLabels).toEqual([
      "How It Works",
      "Features",
      "Great Loop",
      "Resources",
      "Pricing"
    ]);
    await expect(page.locator(".fpw-primary-nav > .fpw-dropdown--tools")).toHaveCount(0);

    const resources = page.locator(".fpw-dropdown--resources");
    const resourcesToggle = resources.locator("[data-fpw-dropdown-toggle]");
    const mobileToggle = page.locator("[data-fpw-mobile-toggle]");

    if (width > 1050) {
      await expect(mobileToggle).toBeHidden();
      await expect(resourcesToggle).toBeVisible();
      await expect(page.locator(".fpw-nav-actions").getByRole("link", { name: "Start Free" })).toBeVisible();
      await expect(page.locator(".fpw-nav-actions").getByRole("link", { name: "Login" })).toBeVisible();
    } else {
      await expect(mobileToggle).toBeVisible();
      await mobileToggle.click();
      await expect(mobileToggle).toHaveAttribute("aria-expanded", "true");
      await expect(resourcesToggle).toBeVisible();
    }

    await resourcesToggle.click();
    await expect(resourcesToggle).toHaveAttribute("aria-expanded", "true");
    await expect(resources).toHaveClass(/is-open/);
    await expect(resources.getByText("Featured Guides", { exact: true })).toBeVisible();
    await expect(resources.getByText("Planning Tools", { exact: true })).toBeVisible();
    await expect(resources.getByText("Boating Resources", { exact: true })).toBeVisible();
    await expect(resources.locator(".fpw-resource-feature-card")).toHaveCount(2);
    await expect(resources.locator(".fpw-resource-feature-card").nth(0).getByRole("heading", { name: "Shore Contact Guide" })).toBeVisible();
    await expect(resources.locator(".fpw-resource-feature-card").nth(1).getByRole("heading", { name: "Solo Boating Safety Guide" })).toBeVisible();
    await expect(resources.getByText("Practical solo boating safety guidance from kayaks to cruisers, with preparation tips and checklists.", { exact: true })).toBeVisible();

    const resourceLabels = await resources.locator('[role="menuitem"]')
      .evaluateAll((items) => items.map((item) => item.innerText.trim().replace(/\s+/g, " ")));
    expect(resourceLabels).toEqual([
      "Read the Guide →",
      "Read the Guide →",
      "Fuel Calculator Estimate fuel usage, range, and costs. →",
      "Marine Weather Current conditions and extended forecasts. →",
      "Why Use a Float Plan →",
      "How It Works →",
      "FAQ →"
    ]);
    await expect(resources.getByText("Float Plan Basics", { exact: true })).toHaveCount(0);
    await expect(resources.locator('a[href="/fpw/why-use-a-float-plan.cfm"]')).toHaveCount(1);
    await expectPublicNavWithinViewport(page);

    if (width > 1050) {
      const panelBox = await resources.locator(".fpw-resources-menu").boundingBox();
      expect(panelBox.x).toBeGreaterThanOrEqual(0);
      expect(panelBox.x + panelBox.width).toBeLessThanOrEqual(width);
      expect(panelBox.width).toBeGreaterThanOrEqual(720);
      expect(panelBox.width).toBeLessThanOrEqual(860);
      const featureLayout = await resources.evaluate((resourceMenu) => {
        const menu = resourceMenu.querySelector(".fpw-resources-menu");
        const featurePanel = resourceMenu.querySelector(".fpw-resource-feature");
        const cards = [...resourceMenu.querySelectorAll(".fpw-resource-feature-card")];
        const summaries = [...resourceMenu.querySelectorAll(".fpw-resource-feature-summary")];
        const buttons = [...resourceMenu.querySelectorAll(".fpw-resource-feature-link")];
        const divider = resourceMenu.querySelector(".fpw-featured-guide__divider");
        const menuBox = menu.getBoundingClientRect();
        const panelStyle = getComputedStyle(featurePanel);
        const dividerStyle = getComputedStyle(divider);
        return {
          menuHasVerticalClipping: menu.scrollHeight > menu.clientHeight + 1,
          sharedPanelHasBorder: parseFloat(panelStyle.borderTopWidth) > 0,
          sharedPanelHasBackground: panelStyle.backgroundImage !== "none",
          dividerIsVisible: divider.getBoundingClientRect().height >= 1 && dividerStyle.backgroundColor !== "rgba(0, 0, 0, 0)",
          cardsInsideMenu: cards.every((card) => {
            const box = card.getBoundingClientRect();
            return box.top >= menuBox.top && box.bottom <= menuBox.bottom;
          }),
          summariesUseExplicitGrid: summaries.every((summary) => getComputedStyle(summary).display === "grid"),
          iconsBesideCopy: summaries.every((summary) => {
            const iconBox = summary.querySelector(".fpw-resource-feature-icon").getBoundingClientRect();
            const copyBox = summary.querySelector(".fpw-resource-feature-copy").getBoundingClientRect();
            return iconBox.right <= copyBox.left && Math.abs(iconBox.top - copyBox.top) <= 1;
          }),
          buttonWidths: buttons.map((button) => Math.round(button.getBoundingClientRect().width)),
          contentButtonGaps: buttons.map((button, index) => Math.round(button.getBoundingClientRect().top - summaries[index].getBoundingClientRect().bottom)),
          bottomPadding: Math.round(featurePanel.getBoundingClientRect().bottom - buttons[1].getBoundingClientRect().bottom)
        };
      });
      expect(featureLayout.menuHasVerticalClipping).toBe(false);
      expect(featureLayout.sharedPanelHasBorder).toBe(true);
      expect(featureLayout.sharedPanelHasBackground).toBe(true);
      expect(featureLayout.dividerIsVisible).toBe(true);
      expect(featureLayout.cardsInsideMenu).toBe(true);
      expect(featureLayout.summariesUseExplicitGrid).toBe(true);
      expect(featureLayout.iconsBesideCopy).toBe(true);
      expect(Math.abs(featureLayout.buttonWidths[0] - featureLayout.buttonWidths[1])).toBeLessThanOrEqual(1);
      expect(featureLayout.contentButtonGaps.every((gap) => gap >= 18 && gap <= 24)).toBe(true);
      expect(featureLayout.bottomPadding).toBeGreaterThanOrEqual(16);
      expect(featureLayout.bottomPadding).toBeLessThanOrEqual(20);
      await page.keyboard.press("Escape");
      await expect(resourcesToggle).toHaveAttribute("aria-expanded", "false");
    } else {
      const tapTargetWidths = await resources.locator('[role="menuitem"]')
        .evaluateAll((items) => items.map((item) => item.getBoundingClientRect().width));
      expect(tapTargetWidths.every((itemWidth) => itemWidth >= 250)).toBe(true);
      await resourcesToggle.click();
      await expect(resourcesToggle).toHaveAttribute("aria-expanded", "false");
      await expect(resources.locator(".fpw-resources-menu")).toBeHidden();
      await page.locator("[data-fpw-mobile-close]").click();
      await expect(mobileToggle).toHaveAttribute("aria-expanded", "false");
    }

    if (width !== 1024) {
      expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBe(width);
    }
  }

  expect(pageErrors).toEqual([]);
});

test("dropdown exclusivity, outside click, Escape, and keyboard focus remain intact", async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 900 });
  await page.goto(guideUrl, { waitUntil: "domcontentloaded" });

  const resourcesToggle = page.locator(".fpw-dropdown--resources [data-fpw-dropdown-toggle]");
  const greatLoopToggle = page.locator(".fpw-dropdown--mega [data-fpw-dropdown-toggle]");

  await resourcesToggle.click();
  await greatLoopToggle.click();
  await expect(resourcesToggle).toHaveAttribute("aria-expanded", "false");
  await expect(greatLoopToggle).toHaveAttribute("aria-expanded", "true");

  await page.locator("main").click({ position: { x: 5, y: 5 } });
  await expect(greatLoopToggle).toHaveAttribute("aria-expanded", "false");

  await resourcesToggle.click();
  await expect(resourcesToggle).toHaveAttribute("aria-expanded", "true");
  const featuredLinks = page.locator(".fpw-resource-feature-link");
  await expect(featuredLinks.first()).toBeVisible();
  await resourcesToggle.focus();
  await page.keyboard.press("Tab");
  await expect(featuredLinks.first()).toBeFocused();
  await page.keyboard.press("Tab");
  await expect(featuredLinks.nth(1)).toBeFocused();
  await page.keyboard.press("Escape");
  await expect(resourcesToggle).toHaveAttribute("aria-expanded", "false");
  await expect(featuredLinks.nth(1)).not.toBeFocused();
});

test("guide, educational, FAQ, and tool routes activate Resources and the current child", async ({ page }) => {
  const cases = [
    { path: "/shore-contact-overdue-boater.cfm", child: 'a.fpw-resource-feature-link[href="/fpw/shore-contact-overdue-boater/"]' },
    { path: "/solo-boating-safety-guide.cfm", child: 'a.fpw-resource-feature-link[href="/fpw/solo-boating-safety-guide/"]' },
    { path: "/why-use-a-float-plan.cfm", child: 'a[href="/fpw/why-use-a-float-plan.cfm"]' },
    { path: "/faq/index.cfm", child: 'a[href="/fpw/faq/"]' },
    { path: "/boat-fuel-calculator/boat-fuel-calculator.cfm", child: 'a[href="/fpw/boat-fuel-calculator/boat-fuel-calculator.cfm"]' }
  ];

  for (const routeCase of cases) {
    const response = await page.goto(`${baseUrl}${routeCase.path}`, { waitUntil: "domcontentloaded" });
    expect(response && response.status(), routeCase.path).toBe(200);
    await expect(page.locator(".fpw-dropdown--resources [data-fpw-dropdown-toggle]")).toHaveClass(/is-active/);
    await expect(page.locator(`.fpw-dropdown--resources ${routeCase.child}`)).toHaveClass(/is-active/);
    await expect(page.locator(`.fpw-dropdown--resources ${routeCase.child}`)).toHaveAttribute("aria-current", "page");
  }
});

test("guide analytics emit once with safe fields and never control navigation", async ({ page }) => {
  await page.goto(guideUrl, { waitUntil: "domcontentloaded" });

  const resourcesToggle = page.locator(".fpw-dropdown--resources [data-fpw-dropdown-toggle]");
  await resourcesToggle.click();
  const shoreGuideLink = page.locator('a.fpw-resource-feature-link[href="/fpw/shore-contact-overdue-boater/"]');
  const soloGuideLink = page.locator('a.fpw-resource-feature-link[href="/fpw/solo-boating-safety-guide/"]');
  await page.evaluate(() => {
    window.__fpwPublicNavEvents = [];
    window.FPWAnalytics.track = (name, fields) => window.__fpwPublicNavEvents.push({ name, fields });
    window.__fpwStopGuideNavigation = (event) => {
      if (event.target.closest(".fpw-resource-feature-link")) event.preventDefault();
    };
    document.addEventListener("click", window.__fpwStopGuideNavigation, true);
  });
  await shoreGuideLink.click();
  await soloGuideLink.click();

  expect(await page.evaluate(() => window.__fpwPublicNavEvents)).toEqual([
    {
      name: "public_nav_shore_contact_guide_click",
      fields: {
        source_page: "/fpw/shore-contact-overdue-boater/",
        nav_location: "public_header",
        menu_group: "resources",
        label: "Shore Contact Guide",
        destination_key: "shore_contact_overdue_boater",
        auth_state: "signed_out"
      }
    },
    {
      name: "public_nav_solo_boating_safety_guide_click",
      fields: {
        source_page: "/fpw/shore-contact-overdue-boater/",
        nav_location: "public_header",
        menu_group: "resources",
        label: "Solo Boating Safety Guide",
        destination_key: "solo_boating_safety_guide",
        auth_state: "signed_out"
      }
    }
  ]);

  await page.evaluate(() => {
    document.removeEventListener("click", window.__fpwStopGuideNavigation, true);
    window.FPWAnalytics.track = () => { throw new Error("intentional analytics failure"); };
  });
  await Promise.all([
    page.waitForURL(`${baseUrl}/solo-boating-safety-guide/`),
    soloGuideLink.click()
  ]);
  expect(page.url()).toBe(`${baseUrl}/solo-boating-safety-guide/`);
});

test("destinations and approved footer and homepage guide links remain intact", async ({ page }) => {
  for (const path of ["/", "/shore-contact-overdue-boater.cfm", "/solo-boating-safety-guide.cfm", "/why-use-a-float-plan.cfm", "/faq/index.cfm", "/boat-fuel-calculator/boat-fuel-calculator.cfm"]) {
    const response = await page.goto(`${baseUrl}${path}`, { waitUntil: "domcontentloaded" });
    expect(response && response.status(), path).toBe(200);
  }

  await page.goto(`${baseUrl}/index.cfm`, { waitUntil: "domcontentloaded" });
  const resources = page.locator(".fpw-dropdown--resources");
  await expect(resources.locator('a[href="/fpw/app/weather.cfm"]')).toHaveCount(1);
  await expect(resources.locator('a[href="/fpw/boat-fuel-calculator/boat-fuel-calculator.cfm"]')).toHaveCount(1);
  await expect(resources.locator('a[href="/fpw/why-use-a-float-plan.cfm"]')).toHaveCount(1);
  await expect(resources.locator('a.fpw-resource-feature-link[href="/fpw/shore-contact-overdue-boater/"]')).toHaveCount(1);
  await expect(resources.locator('a.fpw-resource-feature-link[href="/fpw/solo-boating-safety-guide/"]')).toHaveCount(1);

  const contextualLink = page.getByRole("link", { name: "Read the Shore Contact Guide" });
  await expect(contextualLink).toHaveCount(1);
  await expect(contextualLink).toHaveAttribute("href", "/fpw/shore-contact-overdue-boater/");

  const footerLink = page.locator(".fpw-footer-plan-links").getByRole("link", { name: "Shore Contact Guide" });
  await expect(footerLink).toHaveCount(1);
  await expect(footerLink).toHaveAttribute("href", "/fpw/shore-contact-overdue-boater/");

  const menuIds = await page.locator("#fpwResourcesMenu [id]").evaluateAll((items) => items.map((item) => item.id));
  expect(new Set(menuIds).size).toBe(menuIds.length);
});
