const { test, expect } = require("@playwright/test");

test("FPW loads login page", async ({ page }) => {
  const res = await page.goto("/fpw/index.cfm", { waitUntil: "domcontentloaded" });
  expect(res.status()).toBeLessThan(400);

  // Stable, text-agnostic assertions
  await expect(page.locator("form")).toHaveCount(1);

  // Password field exists
  await expect(
    page.locator('input[type="password"], input[name*="pass" i], input[id*="pass" i]')
  ).toBeVisible();

  // Submit exists
  await expect(
    page.locator('button[type="submit"], input[type="submit"]')
  ).toBeVisible();
});
