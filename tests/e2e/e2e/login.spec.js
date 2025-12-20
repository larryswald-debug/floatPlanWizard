if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
  throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
}


const { test, expect } = require("@playwright/test");

test("FPW login succeeds", async ({ page }) => {
  await page.goto("/fpw/index.cfm", { waitUntil: "domcontentloaded" });

  // Fill login fields (adjust names if yours differ)
  await page.fill('input[name="email"], input[name="EMAIL"]', process.env.FPW_EMAIL || "");
  await page.fill('input[type="password"], input[name="password"], input[name="PASSWORD"]', process.env.FPW_PASSWORD || "");

  // Submit
  await page.click('button[type="submit"], input[type="submit"]');

  // Wait for navigation OR a post-login indicator
  await page.waitForLoadState("networkidle");

  // Assert we are no longer on login page
  await expect(page).not.toHaveURL(/index\.cfm$/i);

  // Assert something dashboard-specific exists
  // Pick ONE that you know exists after login
  await expect(
    page.locator("#userHeader, .dashboard, text=Dashboard")
  ).toBeVisible({ timeout: 5000 });
});
