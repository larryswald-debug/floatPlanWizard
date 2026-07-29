require("./test-hooks");

const { test, expect } = require("@playwright/test");

test.describe.configure({ timeout: 120000 });

const ADMIN_USER = {
  email: String(process.env.FPW_ADMIN_EMAIL || "").trim(),
  password: String(process.env.FPW_ADMIN_PASSWORD || "").trim()
};

async function loginAdminUser(page) {
  await page.goto("/fpw/index.cfm", { waitUntil: "domcontentloaded" });
  const publicLoginToggle = page.locator("#publicLoginToggle");
  const loginStrip = page.locator("#login");

  if (await publicLoginToggle.isVisible().catch(() => false)) {
    const stripOpen = await loginStrip.evaluate((el) => el.classList.contains("is-open")).catch(() => false);
    if (!stripOpen) {
      await publicLoginToggle.click();
      await expect(loginStrip).toHaveClass(/is-open/, { timeout: 10000 });
    }
  }

  await page.fill('input[name="email"], input[name="EMAIL"]', ADMIN_USER.email);
  await page.fill('input[type="password"], input[name="password"], input[name="PASSWORD"]', ADMIN_USER.password);
  await page.locator("#loginForm").evaluate((form) => {
    if (typeof form.requestSubmit === "function") form.requestSubmit();
    else form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
  });
  await page.waitForURL(/\/fpw\/app\/dashboard\.cfm/i, { timeout: 30000 });
}

test("unauthenticated visitors are rejected by both admin pages", async ({ page }) => {
  await page.goto("/fpw/admin/promo-codes.cfm", { waitUntil: "domcontentloaded" });
  await expect(page.locator(".alert-danger")).toContainText("Admin login is required");
  await expect(page.locator("#newPromoBtn")).toHaveCount(0);

  await page.goto("/fpw/admin/member-entitlements.cfm", { waitUntil: "domcontentloaded" });
  await expect(page.locator(".alert-danger")).toContainText("Admin login is required");
  await expect(page.locator("#grantEntitlementBtn")).toHaveCount(0);
});

test("admin navigation and both management surfaces load live data", async ({ page }) => {
  test.skip(!ADMIN_USER.email || !ADMIN_USER.password, "FPW_ADMIN_EMAIL and FPW_ADMIN_PASSWORD are required for authenticated admin UI coverage");
  await loginAdminUser(page);

  await page.goto("/fpw/admin/promo-codes.cfm", { waitUntil: "domcontentloaded" });
  await expect(page.locator("h1")).toHaveText("Promo Codes");
  await expect(page.locator('a[href="/fpw/admin/member-entitlements.cfm"]')).toBeVisible();
  await expect(page.locator("#newPromoBtn")).toBeVisible();
  await expect(page.locator("#promoActionModal")).toHaveCount(1);
  await expect(page.locator("#promoActionForm")).toHaveCount(1);
  await expect(page.locator("#promoActionReason")).toHaveCount(1);
  await expect(page.locator("#promoActionConfirmation")).toHaveCount(1);
  await expect(page.locator("#promoSummary")).toContainText("promotion(s)", { timeout: 30000 });
  await expect(page.locator("#promoMessage.error")).toHaveCount(0);

  await page.fill("#promoSearch", "__no_matching_admin_promo__");
  await page.locator("#promoFilters").evaluate((form) => {
    form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
  });
  await expect(page.locator("#promoSummary")).toContainText("of 0 promotion(s)", { timeout: 30000 });

  await page.goto("/fpw/admin/member-entitlements.cfm", { waitUntil: "domcontentloaded" });
  await expect(page.locator("h1")).toHaveText("Member Entitlements");
  await expect(page.locator('a[href="/fpw/admin/promo-codes.cfm"]')).toBeVisible();
  await expect(page.locator("#grantEntitlementBtn")).toBeVisible();
  await expect(page.locator("#entitlementActionModal")).toHaveCount(1);
  await expect(page.locator("#entitlementActionForm")).toHaveCount(1);
  await expect(page.locator("#entitlementActionExpires")).toHaveCount(1);
  await expect(page.locator("#entitlementActionNotes")).toHaveCount(1);
  await expect(page.locator("#entitlementActionConfirmation")).toHaveCount(1);
  await expect(page.locator("#entitlementSummary")).toContainText("entitlement record(s)", { timeout: 30000 });
  await expect(page.locator("#entitlementMessage.error")).toHaveCount(0);

  await page.fill("#entitlementSearch", "__no_matching_admin_entitlement__");
  await page.locator("#entitlementFilters").evaluate((form) => {
    form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
  });
  await expect(page.locator("#entitlementSummary")).toContainText("of 0 entitlement(s)", { timeout: 30000 });
});


