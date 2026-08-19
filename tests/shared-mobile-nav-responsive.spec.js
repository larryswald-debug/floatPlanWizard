const { test, expect } = require("@playwright/test");

const baseUrl = "http://localhost:8500/fpw";
const cleanupUrl = `${baseUrl}/tests/onboarding-runner.cfm`
  + "?confirm=RUN_DISPOSABLE_WELCOME_ONBOARDING_TESTS&reporter=json";
const password = "QaSharedNav!2026";

let needsCleanup = false;

test.describe.configure({ mode: "serial" });

function collectRuntimeFailures(page) {
  const failures = [];
  page.on("console", (message) => {
    if (message.type() === "error") {
      failures.push(`console: ${message.text()}`);
    }
  });
  page.on("pageerror", (error) => failures.push(`pageerror: ${error.message}`));
  page.on("requestfailed", (request) => {
    const failure = request.failure();
    failures.push(`requestfailed: ${request.url()} (${failure ? failure.errorText : "unknown"})`);
  });
  page.on("response", (response) => {
    if (response.status() >= 500) {
      failures.push(`response ${response.status()}: ${response.url()}`);
    }
  });
  return failures;
}

async function dismissWelcomeIfVisible(page) {
  await page.waitForTimeout(500);
  const modal = page.locator("#welcomeOnboardingModal");
  if (await modal.isVisible()) {
    await page.locator("#welcomeOnboardingCloseBtn").click();
    await expect(modal).toBeHidden();
    await page.waitForTimeout(250);
  }
}

async function createDisposableMember(page) {
  const nonce = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const email = `codex-welcome-onboarding-shared-nav-${nonce}@example.test`;
  const response = await page.goto(`${baseUrl}/app/join.cfm`, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);
  await page.locator("#firstName").fill("QA Shared");
  await page.locator("#lastName").fill("Navigation");
  await page.locator("#email").fill(email);
  await page.locator("#password").fill(password);
  await page.locator("#confirmPassword").fill(password);
  await page.locator("#termsAccepted").check();
  await Promise.all([
    page.waitForURL(/\/fpw\/app\/dashboard\.cfm/),
    page.locator("#joinButton").click()
  ]);
  needsCleanup = true;
  await dismissWelcomeIfVisible(page);
}

async function documentMetrics(page) {
  return page.evaluate(() => {
    const header = document.querySelector("[data-fpw-nav]");
    const nav = document.querySelector("#fpwPrimaryNav");
    const rect = nav.getBoundingClientRect();
    const style = getComputedStyle(nav);
    return {
      viewport: window.innerWidth,
      documentWidth: document.documentElement.scrollWidth,
      bodyWidth: document.body.scrollWidth,
      menuOpen: header.classList.contains("is-menu-open"),
      nav: {
        left: rect.left,
        right: rect.right,
        width: rect.width,
        position: style.position,
        display: style.display,
        transform: style.transform,
        opacity: style.opacity,
        visibility: style.visibility,
        pointerEvents: style.pointerEvents
      }
    };
  });
}

async function expectDocumentContained(page) {
  const metrics = await documentMetrics(page);
  expect(metrics.documentWidth).toBeLessThanOrEqual(metrics.viewport + 1);
  return metrics;
}

async function expectClosedMenu(page) {
  const toggle = page.locator("[data-fpw-mobile-toggle]");
  const nav = page.locator("#fpwPrimaryNav");
  await expect(toggle).toHaveAttribute("aria-expanded", "false");
  await expect(toggle).toHaveAttribute("aria-label", "Open menu");
  await expect(nav).toHaveCSS("visibility", "hidden");
  await expect(nav).toHaveCSS("pointer-events", "none");
  await page.waitForTimeout(220);
  const metrics = await expectDocumentContained(page);
  expect(metrics.menuOpen).toBe(false);
  expect(metrics.nav.display).toBe("none");
  expect(metrics.nav.width).toBe(0);
  return metrics;
}

async function expectOpenMenu(page) {
  const toggle = page.locator("[data-fpw-mobile-toggle]");
  const nav = page.locator("#fpwPrimaryNav");
  await expect(toggle).toHaveAttribute("aria-expanded", "true");
  await expect(toggle).toHaveAttribute("aria-label", "Close menu");
  await expect(nav).toHaveCSS("visibility", "visible");
  await expect(nav).toHaveCSS("pointer-events", "auto");
  await expect(page.locator("[data-fpw-mobile-backdrop]")).toBeVisible();
  await page.waitForTimeout(220);
  const metrics = await expectDocumentContained(page);
  expect(metrics.menuOpen).toBe(true);
  expect(metrics.nav.display).toBe("flex");
  expect(metrics.nav.left).toBeGreaterThanOrEqual(-1);
  expect(metrics.nav.right).toBeLessThanOrEqual(metrics.viewport + 1);
  return metrics;
}

test.afterEach(async ({ page }) => {
  if (!needsCleanup) return;
  await page.goto(cleanupUrl, { waitUntil: "domcontentloaded" });
  needsCleanup = false;
});

test("shared mobile navigation remains contained, usable, and accessible", async ({ page }) => {
  const runtimeFailures = collectRuntimeFailures(page);
  await page.setViewportSize({ width: 390, height: 844 });
  await createDisposableMember(page);

  const representativePages = [
    ["Homepage", "/index.cfm"],
    ["Dashboard", "/app/dashboard.cfm"],
    ["Active Cruise", "/app/active-cruise.cfm"],
    ["Solo Guide", "/solo-boating-safety-guide/"],
    ["Pricing", "/app/pricing.cfm"]
  ];

  for (const [name, path] of representativePages) {
    const response = await page.goto(`${baseUrl}${path}`, { waitUntil: "domcontentloaded" });
    expect(response && response.status(), name).toBe(200);
    await dismissWelcomeIfVisible(page);
    await expect(page.locator("[data-fpw-nav]")).toHaveClass(/fpw-site-header--logged-in/);
    await expectClosedMenu(page);
  }

  await page.goto(`${baseUrl}/app/dashboard.cfm`, { waitUntil: "domcontentloaded" });
  await dismissWelcomeIfVisible(page);
  const toggle = page.locator("[data-fpw-mobile-toggle]");
  const closeButton = page.locator("[data-fpw-mobile-close]");
  const backdrop = page.locator("[data-fpw-mobile-backdrop]");

  await toggle.click();
  await expectOpenMenu(page);
  await closeButton.click();
  await expectClosedMenu(page);

  await toggle.focus();
  await page.keyboard.press("Enter");
  await expectOpenMenu(page);
  await page.keyboard.press("Escape");
  await expectClosedMenu(page);
  expect(await page.evaluate(() => document.activeElement && document.activeElement.closest("#fpwPrimaryNav") === null)).toBe(true);

  await toggle.click();
  await expectOpenMenu(page);
  await backdrop.click({ position: { x: 8, y: 200 } });
  await expectClosedMenu(page);

  await toggle.click();
  await expectOpenMenu(page);
  await closeButton.click();
  await expectClosedMenu(page);

  await toggle.click();
  await expectOpenMenu(page);
  await closeButton.click();
  await expectClosedMenu(page);
  await expect(backdrop).toHaveCount(1);

  await toggle.focus();
  await page.keyboard.press("Tab");
  expect(await page.evaluate(() => document.activeElement && document.activeElement.closest("#fpwPrimaryNav") === null)).toBe(true);

  for (const viewport of [
    { width: 360, height: 844 },
    { width: 390, height: 844 },
    { width: 760, height: 900 },
    { width: 1024, height: 900 }
  ]) {
    await page.setViewportSize(viewport);
    await expect(toggle).toBeVisible();
    await expectClosedMenu(page);
    await toggle.click();
    await expectOpenMenu(page);
    await closeButton.click();
    await expectClosedMenu(page);
  }

  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(`${baseUrl}/app/pricing.cfm`, { waitUntil: "domcontentloaded" });
  await page.locator("[data-fpw-mobile-toggle]").click();
  await expectOpenMenu(page);
  await Promise.all([
    page.waitForURL(/\/fpw\/app\/dashboard\.cfm/),
    page.locator("#fpwPrimaryNav a[href*='/app/dashboard.cfm']").first().click()
  ]);
  await expectClosedMenu(page);

  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto(`${baseUrl}/app/pricing.cfm`, { waitUntil: "domcontentloaded" });
  await expect(page.locator("[data-fpw-mobile-toggle]")).toBeHidden();
  await expect(page.locator("#fpwPrimaryNav")).toBeVisible();
  const desktopMetrics = await expectDocumentContained(page);
  expect(desktopMetrics.nav.position).not.toBe("fixed");
  expect(runtimeFailures).toEqual([]);
});
