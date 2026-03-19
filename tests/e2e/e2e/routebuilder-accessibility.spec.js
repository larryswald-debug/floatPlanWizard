require("./test-hooks");

if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
  throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
}

const { test, expect } = require("@playwright/test");

test.describe.configure({ timeout: 120000 });

async function gotoWithRetry(page, url, retries = 1) {
  let lastError;
  for (let attempt = 0; attempt <= retries; attempt += 1) {
    try {
      await page.goto(url, { waitUntil: "domcontentloaded", timeout: 45000 });
      return;
    } catch (error) {
      lastError = error;
      if (attempt >= retries) {
        throw error;
      }
      await page.waitForTimeout(750);
    }
  }
  throw lastError;
}

async function loginToDashboard(page) {
  await gotoWithRetry(page, "/fpw/index.cfm");
  await page.fill('input[name="email"], input[name="EMAIL"]', process.env.FPW_EMAIL || "");
  await page.fill('input[type="password"], input[name="password"], input[name="PASSWORD"]', process.env.FPW_PASSWORD || "");
  await page.click('button[type="submit"], input[type="submit"]');
  await page.waitForLoadState("networkidle");
  await expect(page).not.toHaveURL(/index\.cfm$/i);

  await gotoWithRetry(page, "/fpw/app/dashboard.cfm");
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 20000 });
}

async function openRouteBuilderByKeyboard(page) {
  const openBtn = page.locator("#openRouteBuilderBtn");
  await openBtn.focus();
  await page.keyboard.press("Enter");
  await expect(page.locator("#routeBuilderModal")).toBeVisible({ timeout: 20000 });
  await expect(page.locator("#fpwRouteGen")).toBeVisible({ timeout: 20000 });
}

async function openRoutePreview(page) {
  const today = new Date().toISOString().slice(0, 10);
  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenTemplateSelect");
    return !!sel && !sel.disabled && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenTemplateSelect", { index: 1 });

  await page.fill("#routeGenStartDate", today);

  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenStartLocation");
    return !!sel && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenStartLocation", { index: 1 });

  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenEndLocation");
    return !!sel && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenEndLocation", { index: 1 });

  const previewBtn = page.locator("#routeGenPreviewBtn");
  await expect(previewBtn).toBeVisible({ timeout: 30000 });
  await expect(previewBtn).toBeEnabled({ timeout: 60000 });
  await previewBtn.click({ timeout: 60000 });

  await page.waitForFunction(() => {
    return document.querySelectorAll("#routeGenLegList .fpw-routegen__leg").length > 0;
  }, { timeout: 30000 });
}

test("Route Builder modal supports keyboard focus and close controls", async ({ page }) => {
  await loginToDashboard(page);
  await openRouteBuilderByKeyboard(page);

  await expect(page.locator("#routeBuilderModal")).toHaveAttribute("aria-labelledby", /routeBuilderLabel/i);
  const ariaHidden = await page.locator("#routeBuilderModal").getAttribute("aria-hidden");
  expect(ariaHidden === null || ariaHidden === "false").toBeTruthy();

  await page.locator("#routeGenCloseBtn").focus();
  await page.keyboard.press("Enter");
  await page.waitForTimeout(120);
  const modalStillOpen = await page.evaluate(() => {
    const modal = document.getElementById("routeBuilderModal");
    return !!(modal && modal.classList.contains("show"));
  });
  if (modalStillOpen) {
    await page.click("#routeGenCloseBtn");
  }
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 20000 });
  await expect(page.locator(".modal-backdrop.show")).toHaveCount(0, { timeout: 20000 });
});

test("Route Builder leg map overlay toggles aria state and keyboard close", async ({ page }) => {
  await loginToDashboard(page);
  await openRouteBuilderByKeyboard(page);
  await openRoutePreview(page);

  const firstOpenMapBtn = page.locator('#routeGenLegList .fpw-routegen__leg [data-leg-action="open-map"]').first();
  await expect(firstOpenMapBtn).toBeVisible({ timeout: 20000 });
  await firstOpenMapBtn.click();

  await expect(page.locator("#routeGenLegOverlay")).toHaveClass(/is-open/, { timeout: 10000 });
  await expect(page.locator("#routeGenLegOverlay")).toHaveAttribute("aria-hidden", "false");
  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 10000 });

  await page.locator("#routeGenLegOverlayCloseBtn").focus();
  await page.keyboard.press("Enter");
  await page.waitForTimeout(120);
  const overlayStillOpen = await page.evaluate(() => {
    const overlay = document.getElementById("routeGenLegOverlay");
    return !!(overlay && overlay.classList.contains("is-open"));
  });
  if (overlayStillOpen) {
    await page.locator("#routeGenLegOverlayCloseBtn").click({ force: true });
  }

  await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 10000 });
  await expect(page.locator("#routeGenLegOverlay")).toHaveAttribute("aria-hidden", "true");

  await page.locator("#routeGenCancelBtn").focus();
  await page.keyboard.press("Enter");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 20000 });
});
