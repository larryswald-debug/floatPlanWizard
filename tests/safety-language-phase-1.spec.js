const { test, expect } = require("@playwright/test");

const baseUrl = "http://localhost:8500/fpw";

async function openFollowPresentation(page, viewport) {
  await page.setViewportSize(viewport);
  const response = await page.goto(`${baseUrl}/app/follow.cfm`, {
    waitUntil: "domcontentloaded"
  });
  expect(response && response.status()).toBe(200);
  await page.evaluate(() => {
    document.body.classList.remove("follow-loading");
  });
}

test("Follow presents source-aware safety copy on desktop", async ({ page }) => {
  await openFollowPresentation(page, { width: 1440, height: 900 });

  await expect(page.locator('[data-fpw-field="page-subtitle"]')).toContainText("planned route");
  await expect(page.locator('[data-fpw-field="map-panel-subtitle"]')).toContainText("estimated route progress");
  await expect(page.locator('[data-fpw-field="map-position-note"]')).toContainText("No position update has been reported yet");
  await expect(page.locator('[data-fpw-field="map-position-note"]')).toContainText("not continuous live vessel tracking");
  await expect(page.getByText("Reported Progress", { exact: true })).toBeVisible();
  await expect(page.getByText("Follow along in real time", { exact: false })).toHaveCount(0);
  await expect(page.getByText("Live now", { exact: false })).toHaveCount(0);
});

test("Follow safety note remains readable without horizontal overflow on mobile", async ({ page }) => {
  await openFollowPresentation(page, { width: 390, height: 844 });
  const safetyNote = page.locator('[data-fpw-field="map-position-note"]');

  await expect(safetyNote).toBeVisible();
  await expect(safetyNote).toContainText("route-progress marker");
  const box = await safetyNote.boundingBox();
  expect(box).not.toBeNull();
  expect(box.x).toBeGreaterThanOrEqual(0);
  expect(box.x + box.width).toBeLessThanOrEqual(390);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
});

test("homepage safety corrections render on desktop and mobile", async ({ page }) => {
  for (const viewport of [
    { width: 1440, height: 900 },
    { width: 390, height: 844 }
  ]) {
    await page.setViewportSize(viewport);
    const response = await page.goto(`${baseUrl}/index.cfm`, {
      waitUntil: "domcontentloaded"
    });
    expect(response && response.status()).toBe(200);
    await expect(page.getByRole("heading", {
      name: "A PDF is a start. FPW keeps trip information available."
    })).toBeVisible();
    await expect(page.getByText("Captains can report updates and check-ins during the trip", {
      exact: true
    })).toBeVisible();
    await expect(page.getByText("Active Cruise keeps timing and status current", {
      exact: true
    })).toHaveCount(0);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  }
});

test("Follow full-map clarification is visible on desktop and mobile", async ({ page }) => {
  for (const viewport of [
    { width: 1440, height: 900 },
    { width: 390, height: 844 }
  ]) {
    await page.setViewportSize(viewport);
    const response = await page.goto(`${baseUrl}/app/follow-full-map.cfm`, {
      waitUntil: "domcontentloaded"
    });
    expect(response && response.status()).toBe(200);
    await expect(page.locator("#followFullMapStatus")).toContainText("not continuous live vessel tracking");
    await expect(page.getByText("Opening the live route map", { exact: false })).toHaveCount(0);
  }
});
