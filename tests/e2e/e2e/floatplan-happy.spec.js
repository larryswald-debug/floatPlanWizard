// /fpw/tests/e2e/floatplan-happy.spec.js
require("./test-hooks");

const { test, expect } = require("@playwright/test");
const {
  cleanupTrackedData,
  createCleanupState,
  trackId,
  trackValue
} = require("../support/fpwCleanup");
const {
  buildFloatPlansFromFirstRoute,
  loginApprovedUser
} = require("../support/fpwSession");

async function clickWizardNext(modal, page) {
  const nextButton = page.getByRole("button", { name: /^(Next|Review Float Plan)$/ }).last();
  await expect(nextButton).toBeVisible({ timeout: 30000 });
  await nextButton.click();
}

test("Route-derived Float Plan Wizard completes happy path", async ({ page }) => {
  const state = createCleanupState();
  const planName = `Playwright Route Plan ${Date.now()}`;

  await loginApprovedUser(page);

  try {
    const built = await buildFloatPlansFromFirstRoute(page);
    for (const floatPlanId of built.floatPlanIds) {
      trackId(state, "floatPlanIds", floatPlanId);
    }
    if (built.createdTemporaryRoute && built.routeCode) {
      trackValue(state, "routeCodes", built.routeCode);
    }
    expect(built.floatPlanIds.length).toBeGreaterThan(0);

    await page.locator(`#floatPlansList [data-action="edit"][data-plan-id="${built.floatPlanIds[0]}"]`).click();
  const modal = page.locator("#floatPlanWizardModal");
  await expect(modal).toBeVisible({ timeout: 20000 });

  // Step 1
  await modal.locator('[name="NAME"]').fill(planName);
  await page.waitForFunction(() => {
    const root = document.querySelector("#floatPlanWizardModal.show");
    if (!root) return false;
    const vessel = root.querySelector('[name="VESSELID"]');
    const operator = root.querySelector('[name="OPERATORID"]');
    return !!vessel && !!operator && vessel.options.length > 1 && operator.options.length > 1;
  }, { timeout: 30000 });
  await modal.locator('[name="VESSELID"]').selectOption({ index: 1 });
  await modal.locator('[name="OPERATORID"]').selectOption({ index: 1 });
  await clickWizardNext(modal, page);

  // Step 2
  await modal.locator('[name="DEPARTING_FROM"]').fill("Test Marina");
  await modal.locator('[name="DEPARTURE_TIME"]').fill("2027-01-01T08:00");
  await modal.locator('[name="DEPARTURE_TIMEZONE"]').selectOption({ index: 1 });
  await modal.locator('[name="RETURNING_TO"]').fill("Test Marina");
  await modal.locator('[name="RETURN_TIME"]').fill("2027-01-01T18:00");
  await modal.locator('[name="RETURN_TIMEZONE"]').selectOption({ index: 1 });
  await clickWizardNext(modal, page);

  // Step 3
  await modal.locator('input[type="email"]').fill(process.env.FPW_EMAIL || "");
  await page.waitForFunction(() => {
    const root = document.querySelector("#floatPlanWizardModal.show");
    if (!root) return false;
    const rescue = root.querySelector('[name="RESCUE_AUTHORITY_SELECTION"]');
    return !!rescue && rescue.options.length > 1;
  }, { timeout: 30000 });
  await modal.locator('[name="RESCUE_AUTHORITY_SELECTION"]').selectOption({ index: 1 });
  await clickWizardNext(modal, page);

  // Step 4
  await expect(modal.locator('input[placeholder="Search passengers..."]')).toBeVisible({ timeout: 30000 });
  await clickWizardNext(modal, page);

  // Step 5
  await clickWizardNext(modal, page);

  // Step 6 (review/save)
  await modal.locator('button:has-text("Save Float Plan")').first().click();
  await expect(modal.locator(".wizard-alert.alert-success")).toBeVisible({ timeout: 30000 });
    trackValue(state, "pdfPrefixes", planName.replace(/[^A-Za-z0-9_-]+/g, "_"));
  } finally {
    await cleanupTrackedData(page, state).catch(() => {});
  }
});
