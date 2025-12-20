// /fpw/tests/e2e/floatplan-happy.spec.js
require("./test-hooks");

const { test, expect } = require("@playwright/test");

test("Float Plan Wizard completes happy path", async ({ page }) => {
  // Login
  await page.goto("/fpw/index.cfm", { waitUntil: "domcontentloaded" });

  await page.fill('input[name="email"], input[name="EMAIL"]', process.env.FPW_EMAIL || "");
  await page.fill('input[type="password"], input[name="password"], input[name="PASSWORD"]', process.env.FPW_PASSWORD || "");

  await page.click('button[type="submit"], input[type="submit"]');
  await page.waitForLoadState("domcontentloaded");

  // Go to Float Plan Wizard
  await page.goto("/fpw/app/floatplan-wizard.cfm", { waitUntil: "domcontentloaded" });

  /* --------------------
     STEP 1
     -------------------- */
  await page.fill('[name="NAME"]', "Playwright Test Plan");
  await page.selectOption('[name="VESSELID"]', { index: 1 });
  await page.selectOption('[name="OPERATORID"]', { index: 1 });
  await page.click('button:has-text("Next")');

  /* --------------------
     STEP 2
     -------------------- */
  await page.fill('[name="DEPARTING_FROM"]', "Test Marina");
  await page.fill('[name="DEPARTURE_TIME"]', "2025-01-01T08:00");
  await page.selectOption('[name="DEPARTURE_TIMEZONE"]', { index: 1 });

  await page.fill('[name="RETURNING_TO"]', "Test Marina");
  await page.fill('[name="RETURN_TIME"]', "2025-01-01T18:00");
  await page.selectOption('[name="RETURN_TIMEZONE"]', { index: 1 });

  await page.click('button:has-text("Next")');

/* --------------------
   STEP 3 (critical)
   -------------------- */
await page.locator('input[name="email"]:visible, input[name="EMAIL"]:visible').fill(process.env.FPW_EMAIL);
await page.locator('input[type="password"]:visible, input[name="password"]:visible, input[name="PASSWORD"]:visible').fill(process.env.FPW_PASSWORD);


// Rescue Authority: select (preferred) or manual text
const rescueSelect = page.locator('[name="RESCUE_AUTHORITY_ID"]:visible');
if (await rescueSelect.count()) {
  await rescueSelect.selectOption({ index: 1 });
} else {
  await page.locator('[name="RESCUE_AUTHORITY"]:visible').fill("US Coast Guard");
}

// Debug: print visible inline errors (if any)
const visibleErrors = await page.locator(".invalid-feedback:visible").allTextContents();
if (visibleErrors.length) console.log("STEP 3 ERRORS:", visibleErrors);

// Click the visible Next
await page.locator('button:has-text("Next"):visible').click();

// Confirm Step 4 is reached
await expect(page.locator("text=Step 4")).toBeVisible({ timeout: 5000 });


  /* --------------------
     STEP 4 (pass-through)
     -------------------- */
  await page.click('button:has-text("Next")');

  /* --------------------
     STEP 5 (pass-through)
     -------------------- */
  await page.click('button:has-text("Next")');

  /* --------------------
     STEP 6 (pass-through)
     -------------------- */
  await page.click('button:has-text("Next")');

  /* --------------------
     STEP 7 (submit)
     -------------------- */
  await page.click('button:has-text("Submit")');

  // A) URL changes away from /fpw/index.cfm
await expect(page).not.toHaveURL(/\/fpw\/index\.cfm/i);

  // Assert success indicator (match any one of these)
  await expect(
    page.locator(".alert-success, text=Success, text=Float Plan Saved")
  ).toBeVisible({ timeout: 5000 });
});
