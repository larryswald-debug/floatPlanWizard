const { test, expect } = require("@playwright/test");

const origin = "http://localhost:8500/fpw/";
const expected = {
  headline: "Plan the trip. Share the plan. Stay connected.",
  body: "Use the free Trip Planner to plot your route and stops and calculate mileage, travel time, fuel, reserve, and cost using your speed and weather assumptions. When departure approaches, turn your saved trip into a float plan and share a private Trip Page with family and friends.",
  primary: "Plan Your Trip Free",
  primaryAccessibleName: "Open the free FloatPlanWizard Trip Planner",
  secondary: "See What Family Sees",
  benefits: [
    "No credit card required",
    "Mileage, time, fuel, and cost",
    "Float plan when you depart",
    "No account for followers"
  ],
  disclaimer: "FloatPlanWizard organizes and shares trip information. It is not a rescue or emergency-dispatch service."
};

async function mountHero(page) {
  await page.goto(`${origin}?hero-test=planning-first`, { waitUntil: "domcontentloaded" });
  await expect(page.locator(".fpw-hero")).toBeVisible();
}

test("rendered hero has exact copy, semantics, destinations, and ordered benefits", async ({ page }) => {
  await mountHero(page);
  const hero = page.locator(".fpw-hero");
  const primary = hero.getByRole("link", { name: expected.primaryAccessibleName });
  const secondary = hero.locator(".fpw-hero-actions").getByRole("link", { name: expected.secondary });

  await expect(hero.getByRole("heading", { level: 1, name: expected.headline })).toHaveCount(1);
  await expect(hero.locator(".fpw-hero-copy > p").first()).toHaveText(expected.body);
  await expect(primary).toContainText(expected.primary);
  await expect(primary).toHaveAttribute("href", "/fpw/app/join.cfm");
  await expect(primary).toHaveAttribute("data-fpw-track", "homepage_hero_primary_cta_click");
  await expect(primary).toHaveAttribute("data-fpw-track-label", expected.primary);
  await expect(primary).toHaveAttribute("data-fpw-track-section", "hero");
  await expect(secondary).toHaveAttribute("href", "#fpwProductPreview");
  await expect(secondary).toHaveAttribute("data-fpw-open-preview", "follow");
  await expect(secondary).toHaveAttribute("data-fpw-track", "homepage_hero_secondary_cta_click");
  await expect(secondary).toHaveAttribute("data-fpw-track-label", expected.secondary);
  await expect(hero.locator(".fpw-trust-item > span:last-child")).toHaveText(expected.benefits);
  await expect(hero.locator(".fpw-check-dot")).toHaveCount(4);
  await expect(hero.locator(".fpw-hero-disclaimer")).toHaveText(expected.disclaimer);
  await expect(page.locator("h1")).toHaveCount(1);
});

for (const authState of ["signed_out", "signed_in"]) {
  test(`primary CTA preserves its existing ${authState} destination and analytics`, async ({ page }) => {
    await mountHero(page);
    const primary = page.getByRole("link", { name: expected.primaryAccessibleName });
    await expect(primary).toHaveAttribute("href", "/fpw/app/join.cfm");

    await page.evaluate(() => {
      window.sessionStorage.removeItem("fpw_signup_attribution");
      window.__heroEvents = [];
      window.gtag = () => {};
      window.FPWAnalytics = {
        track(eventName, params) {
          window.__heroEvents.push({ eventName, params });
        }
      };
      document.addEventListener("click", (event) => {
        if (event.target.closest('[data-fpw-track="homepage_hero_primary_cta_click"]')) event.preventDefault();
      }, true);
    });
    await primary.click();

    expect(await page.evaluate(() => window.__heroEvents)).toEqual([{
      eventName: "homepage_hero_primary_cta_click",
      params: { label: expected.primary, plan: "", section: "hero" }
    }]);
    expect(await page.evaluate(() => sessionStorage.getItem("fpw_signup_attribution"))).toBeNull();
  });
}

for (const width of [320, 390, 768, 1024, 1440]) {
  test(`hero remains readable and contained at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 1000 });
    await mountHero(page);
    const primary = page.getByRole("link", { name: expected.primaryAccessibleName });
    await primary.focus();
    await expect(primary).toBeFocused();

    const result = await page.evaluate(() => {
      function luminance(rgb) {
        const channels = (rgb.match(/[\d.]+/g) || []).slice(0, 3).map((value) => {
          const channel = Number(value) / 255;
          return channel <= 0.03928 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
        });
        return (0.2126 * channels[0]) + (0.7152 * channels[1]) + (0.0722 * channels[2]);
      }
      function contrast(foreground, background) {
        const lighter = Math.max(luminance(foreground), luminance(background));
        const darker = Math.min(luminance(foreground), luminance(background));
        return (lighter + 0.05) / (darker + 0.05);
      }
      const hero = document.querySelector(".fpw-hero");
      const copy = hero.querySelector(".fpw-hero-copy");
      const headline = hero.querySelector("h1");
      const paragraph = hero.querySelector(".fpw-hero-copy > p");
      const actions = hero.querySelector(".fpw-hero-actions");
      const primary = actions.querySelector(".fpw-btn-primary");
      const secondary = actions.querySelector(".fpw-btn-secondary");
      const primaryTextNode = [...primary.childNodes].find((node) => node.nodeType === Node.TEXT_NODE && node.textContent.trim());
      const textRange = document.createRange();
      textRange.selectNode(primaryTextNode);
      const trust = hero.querySelector(".fpw-trust-row");
      const benefits = [...trust.querySelectorAll(".fpw-trust-item")];
      const disclaimer = hero.querySelector(".fpw-hero-disclaimer");
      const primaryStyle = getComputedStyle(primary);
      const headlineStyle = getComputedStyle(headline);
      const paragraphStyle = getComputedStyle(paragraph);
      const disclaimerStyle = getComputedStyle(disclaimer);
      const actionBoxes = [primary, secondary].map((link) => link.getBoundingClientRect());
      return {
        documentOverflow: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
        heroOverflow: hero.scrollWidth > hero.clientWidth + 1,
        copyOverflow: copy.scrollWidth > copy.clientWidth + 1,
        actionsOverflow: actions.scrollWidth > actions.clientWidth + 1,
        benefitsOverflow: benefits.some((item) => item.scrollWidth > item.clientWidth + 1),
        primarySingleLine: textRange.getClientRects().length === 1,
        primaryHeight: primary.getBoundingClientRect().height,
        secondaryHeight: secondary.getBoundingClientRect().height,
        buttonsOverlap: !(actionBoxes[0].right <= actionBoxes[1].left || actionBoxes[1].right <= actionBoxes[0].left || actionBoxes[0].bottom <= actionBoxes[1].top || actionBoxes[1].bottom <= actionBoxes[0].top),
        headlineFontSize: parseFloat(headlineStyle.fontSize),
        paragraphWidth: paragraph.getBoundingClientRect().width,
        paragraphMaxWidth: parseFloat(paragraphStyle.maxWidth),
        benefitColumns: getComputedStyle(trust).gridTemplateColumns.split(" ").length,
        disclaimerVisible: disclaimer.getBoundingClientRect().height > 0 && disclaimerStyle.visibility !== "hidden",
        disclaimerContrast: contrast(disclaimerStyle.color, "rgb(4, 21, 47)"),
        focusVisible: primaryStyle.outlineStyle !== "none" && parseFloat(primaryStyle.outlineWidth) >= 1,
        primaryContrast: contrast(primaryStyle.color, "rgb(244, 169, 0)"),
        heroHeight: hero.getBoundingClientRect().height
      };
    });

    expect(result.documentOverflow).toBe(false);
    expect(result.heroOverflow).toBe(false);
    expect(result.copyOverflow).toBe(false);
    expect(result.actionsOverflow).toBe(false);
    expect(result.benefitsOverflow).toBe(false);
    expect(result.primarySingleLine).toBe(true);
    expect(result.primaryHeight).toBeGreaterThanOrEqual(44);
    expect(result.secondaryHeight).toBeGreaterThanOrEqual(44);
    expect(result.buttonsOverlap).toBe(false);
    expect(result.headlineFontSize).toBeGreaterThanOrEqual(31);
    expect(result.paragraphWidth).toBeLessThanOrEqual(result.paragraphMaxWidth + 1);
    expect(result.benefitColumns).toBe(width <= 720 ? 2 : 4);
    expect(result.disclaimerVisible).toBe(true);
    expect(result.disclaimerContrast).toBeGreaterThanOrEqual(4.5);
    expect(result.focusVisible).toBe(true);
    expect(result.primaryContrast).toBeGreaterThanOrEqual(4.5);
    expect(result.heroHeight).toBeLessThan(width <= 1050 ? 1000 : 600);
  });
}

test("200 percent desktop zoom equivalent reflows without clipping", async ({ page }) => {
  await page.setViewportSize({ width: 720, height: 900 });
  await mountHero(page);
  const result = await page.evaluate(() => ({
    overflow: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
    primaryVisible: document.querySelector(".fpw-hero .fpw-btn-primary").getBoundingClientRect().height >= 44,
    disclaimerVisible: document.querySelector(".fpw-hero-disclaimer").getBoundingClientRect().height > 0
  }));
  expect(result).toEqual({ overflow: false, primaryVisible: true, disclaimerVisible: true });
});
