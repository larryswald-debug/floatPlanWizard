if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
  throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
}

const { test, expect } = require("@playwright/test");
const { loginApprovedUser, openRouteBuilder } = require("./support/fpwSession");

test.describe.configure({ timeout: 120000 });

test("Mobile dashboard opens and closes Route Builder modal", async ({ page }) => {
  await loginApprovedUser(page);
  await openRouteBuilder(page);

  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 30000 });
  await expect(page.locator(".modal-backdrop.show")).toHaveCount(0, { timeout: 30000 });
});

test("Mobile route builder preview supports setup-panel scroll and map overlay reopen", async ({ page }) => {
  await loginApprovedUser(page);
  await openRouteBuilder(page);

  const today = new Date().toISOString().slice(0, 10);
  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenTemplateSelect");
    return !!sel && !sel.disabled && sel.options.length > 1;
  }, { timeout: 25000 });
  await page.selectOption("#routeGenTemplateSelect", { index: 1 });
  await page.fill("#routeGenStartDate", today);

  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenStartLocation");
    return !!sel && sel.options.length > 1;
  }, { timeout: 25000 });
  await page.selectOption("#routeGenStartLocation", { index: 1 });

  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenEndLocation");
    return !!sel && sel.options.length > 1;
  }, { timeout: 25000 });
  await page.selectOption("#routeGenEndLocation", { index: 1 });

  await page.waitForFunction(() => document.querySelectorAll("#routeGenLegList .fpw-routegen__leg").length > 0, { timeout: 30000 });

  const scrollState = await page.evaluate(() => {
    const el = document.getElementById("routeGenSetupPanelBody");
    if (!el) return { exists: false, scrollTop: 0, scrollHeight: 0, clientHeight: 0, maxScroll: 0 };
    const before = el.scrollTop;
    const maxScroll = Math.max(0, el.scrollHeight - el.clientHeight);
    el.scrollTop = maxScroll;
    return {
      exists: true,
      before,
      scrollTop: el.scrollTop,
      scrollHeight: el.scrollHeight,
      clientHeight: el.clientHeight,
      maxScroll
    };
  });
  expect(scrollState.exists).toBeTruthy();
  expect(scrollState.clientHeight).toBeGreaterThan(0);
  expect(scrollState.scrollHeight).toBeGreaterThanOrEqual(scrollState.clientHeight);
  expect(scrollState.scrollTop).toBeGreaterThanOrEqual(0);
  if (scrollState.maxScroll > 0) {
    expect(scrollState.scrollTop).toBeGreaterThanOrEqual(scrollState.before);
  }

  const openMapBtn = page.locator('#routeGenLegList .fpw-routegen__leg [data-leg-action="open-map"]').first();
  await expect(openMapBtn).toBeVisible({ timeout: 30000 });
  await page.evaluate(() => {
    const btn = document.querySelector('#routeGenLegList .fpw-routegen__leg [data-leg-action="open-map"]');
    if (btn) btn.click();
  });
  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 15000 });
  await page.evaluate(() => {
    const closeBtn = document.getElementById("routeGenLegOverlayCloseBtn");
    if (closeBtn) closeBtn.click();
  });
  await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 15000 });

  await page.evaluate(() => {
    const btn = document.querySelector('#routeGenLegList .fpw-routegen__leg [data-leg-action="open-map"]');
    if (btn) btn.click();
  });
  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 15000 });
  await page.evaluate(() => {
    const closeBtn = document.getElementById("routeGenLegOverlayCloseBtn");
    if (closeBtn) closeBtn.click();
  });
  await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 15000 });

  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 30000 });
  await expect(page.locator(".modal-backdrop.show")).toHaveCount(0, { timeout: 30000 });
});
