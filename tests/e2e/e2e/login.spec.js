if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
  throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
}


const { test, expect } = require("@playwright/test");

test("FPW login succeeds", async ({ page }) => {
  await page.goto("/fpw/index.cfm", { waitUntil: "domcontentloaded" });

  await page.fill('input[name="email"], input[name="EMAIL"]', process.env.FPW_EMAIL || "");
  await page.fill('input[type="password"], input[name="password"], input[name="PASSWORD"]', process.env.FPW_PASSWORD || "");

  await page.click('button[type="submit"], input[type="submit"]');

  await page.waitForURL(/\/fpw\/app\/dashboard\.cfm/i, { timeout: 20000 });
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 20000 });
  await expect(page.locator("#loginForm")).toHaveCount(0);
});
