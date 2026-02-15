// /fpw/tests/e2e/floatplan-happy.spec.js
require("./test-hooks");

const { test, expect } = require("@playwright/test");

test("Float Plan Wizard completes happy path", async ({ page }) => {
  await page.goto("/fpw/index.cfm", { waitUntil: "domcontentloaded" });

  await page.fill('input[name="email"], input[name="EMAIL"]', process.env.FPW_EMAIL || "");
  await page.fill('input[type="password"], input[name="password"], input[name="PASSWORD"]', process.env.FPW_PASSWORD || "");

  await page.click('button[type="submit"], input[type="submit"]');
  await page.waitForURL(/\/fpw\/app\/dashboard\.cfm/i, { timeout: 20000 });
  await expect(page.locator("#addFloatPlanBtn")).toBeVisible({ timeout: 20000 });

  await page.click("#addFloatPlanBtn");
  const modal = page.locator("#floatPlanWizardModal");
  await expect(modal).toBeVisible({ timeout: 20000 });

  // Step 1
  await modal.locator('[name="NAME"]').fill("Playwright Test Plan");
  await page.waitForFunction(() => {
    const root = document.querySelector("#floatPlanWizardModal.show");
    if (!root) return false;
    const vessel = root.querySelector('[name="VESSELID"]');
    const operator = root.querySelector('[name="OPERATORID"]');
    return !!vessel && !!operator && vessel.options.length > 1 && operator.options.length > 1;
  }, { timeout: 30000 });
  await modal.locator('[name="VESSELID"]').selectOption({ index: 1 });
  await modal.locator('[name="OPERATORID"]').selectOption({ index: 1 });
  await modal.locator(".wizard-nav .btn-primary").click();

  // Step 2
  await modal.locator('[name="DEPARTING_FROM"]').fill("Test Marina");
  await modal.locator('[name="DEPARTURE_TIME"]').fill("2027-01-01T08:00");
  await modal.locator('[name="DEPARTURE_TIMEZONE"]').selectOption({ index: 1 });
  await modal.locator('[name="RETURNING_TO"]').fill("Test Marina");
  await modal.locator('[name="RETURN_TIME"]').fill("2027-01-01T18:00");
  await modal.locator('[name="RETURN_TIMEZONE"]').selectOption({ index: 1 });
  await modal.locator(".wizard-nav .btn-primary").click();

  // Step 3
  await modal.locator('input[type="email"]').fill(process.env.FPW_EMAIL || "");
  await page.waitForFunction(() => {
    const root = document.querySelector("#floatPlanWizardModal.show");
    if (!root) return false;
    const rescue = root.querySelector('[name="RESCUE_AUTHORITY_SELECTION"]');
    return !!rescue && rescue.options.length > 1;
  }, { timeout: 30000 });
  await modal.locator('[name="RESCUE_AUTHORITY_SELECTION"]').selectOption({ index: 1 });
  await modal.locator(".wizard-nav .btn-primary").click();

  // Step 4 (requires at least one contact)
  await page.waitForFunction(() => {
    const root = document.querySelector("#floatPlanWizardModal.show");
    if (!root) return false;
    return root.querySelectorAll("section button.list-group-item").length > 0;
  }, { timeout: 30000 });
  await modal.locator("section button.list-group-item").first().click();
  await modal.locator("section .mt-4 button.list-group-item").first().click();
  await modal.locator(".wizard-nav .btn-primary").click();

  // Step 5
  await modal.locator(".wizard-nav .btn-primary").click();

  // Step 6 (review/save)
  await modal.locator('button:has-text("Save Float Plan")').first().click();
  await expect(modal.locator(".wizard-alert.alert-success")).toBeVisible({ timeout: 30000 });
});
