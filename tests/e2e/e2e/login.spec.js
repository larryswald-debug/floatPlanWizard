const { loginAsTestUser, requireCredentials } = require("./test-hooks");
requireCredentials();

const { test, expect } = require("@playwright/test");

test("FPW login succeeds", async ({ page }) => {
  await loginAsTestUser(page);

  await page.waitForURL(/\/fpw\/app\/dashboard\.cfm/i, { timeout: 20000 });
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 20000 });
  await expect(page.locator("#loginForm")).toHaveCount(0);
});
