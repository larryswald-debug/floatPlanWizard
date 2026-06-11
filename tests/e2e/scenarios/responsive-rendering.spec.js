const { test, expect } = require("@playwright/test");
const {
  assertNoConsoleErrors,
  attachConsoleErrorCollector,
  expectBoxWithinViewport,
  expectHeadingVisible
} = require("../support/fpwAssertions");
const {
  cleanupCurrentRouteFloatPlanGroup,
  cleanupTrackedData,
  createCleanupState,
  trackId,
  trackValue
} = require("../support/fpwCleanup");
const {
  buildFloatPlansFromFirstRoute,
  currentGroupActionSelector,
  gotoDashboard,
  gotoPublicSignup,
  loginApprovedUser,
  openRouteBuilder
} = require("../support/fpwSession");

test.describe.configure({ mode: "serial" });

async function openFloatPlanWizard(page, state) {
  const buildPayload = await buildFloatPlansFromFirstRoute(page);
  const floatPlanId = Number(buildPayload.floatPlanIds[0] || 0);
  expect(floatPlanId).toBeGreaterThan(0);
  trackId(state, "floatPlanIds", floatPlanId);
  if (buildPayload.createdTemporaryRoute && buildPayload.routeCode) {
    trackValue(state, "routeCodes", buildPayload.routeCode);
  }

  await page.locator(currentGroupActionSelector(floatPlanId, "edit")).click();
  await expect(page.locator("#floatPlanWizardModal")).toBeVisible({ timeout: 30000 });
  await expect(page.locator("#floatplanWizardForm")).toBeVisible({ timeout: 30000 });
}

test("responsive login and member signup keep the approved forms within the viewport", async ({ page }, testInfo) => {
  await page.goto("/fpw/index.cfm", { waitUntil: "domcontentloaded" });
  await expect(page.locator("#loginForm")).toBeVisible({ timeout: 30000 });
  await expect(page.locator("#email")).toBeVisible();
  await expect(page.locator("#password")).toBeVisible();
  await expect(page.locator("#loginButton")).toBeVisible();

  await gotoPublicSignup(page);
  await expectHeadingVisible(page, "Member Sign Up");
  await expect(page.locator("#joinForm")).toBeVisible();
  await expect(page.locator("#firstName")).toBeVisible();
  await expect(page.locator("#lastName")).toBeVisible();
  await expect(page.locator("#email")).toBeVisible();
  await page.locator("#joinButton").scrollIntoViewIfNeeded();
  await expectBoxWithinViewport(page, "#joinButton");

  if (testInfo.project.name === "tablet-webkit-ipad-pro-11") {
    await page.setViewportSize({ width: 1194, height: 834 });
    await page.reload({ waitUntil: "domcontentloaded" });
    await page.locator("#joinButton").scrollIntoViewIfNeeded();
    await expect(page.locator("#joinButton")).toBeVisible();
    await expectBoxWithinViewport(page, "#joinButton");
  }
});

test("responsive dashboard, float-plan wizard, and route builder keep key controls reachable", async ({ page }, testInfo) => {
  const state = createCleanupState();
  await loginApprovedUser(page);
  await gotoDashboard(page);
  await cleanupCurrentRouteFloatPlanGroup(page);
  const consoleErrors = attachConsoleErrorCollector(page);

  try {
    await expect(page.locator("#missionSummaryPanel")).toBeVisible();
    await expect(page.locator("#expeditionTimelinePanel")).toBeVisible();
    await expect(page.locator("#expeditionRouteList")).toBeVisible();

    await openFloatPlanWizard(page, state);
    await expect(page.getByRole("heading", { name: "Step 1 – Basics", exact: false })).toBeVisible();
    await expect(page.locator('#floatPlanWizardModal input[name="NAME"]')).toBeVisible();
    await expect(page.locator('#floatPlanWizardModal select[name="VESSELID"]')).toBeVisible();
    await expect(page.locator('#floatPlanWizardModal select[name="OPERATORID"]')).toBeVisible();
    await page.locator("#floatPlanWizardModal .btn-close").click();
    await expect(page.locator("#floatPlanWizardModal")).toBeHidden({ timeout: 30000 });

    await openRouteBuilder(page);
    await expect(page.locator("#routeGenTemplateSelect")).toBeVisible();
    await expect(page.locator("#routeGenDirectionToggle")).toBeVisible();
    await expect(page.locator("#routeGenGenerateBtn")).toBeVisible();

    if (testInfo.project.name === "tablet-webkit-ipad-pro-11") {
      await page.setViewportSize({ width: 1194, height: 834 });
      await expect(page.locator("#routeGenTemplateSelect")).toBeVisible();
      await expect(page.locator("#routeGenGenerateBtn")).toBeVisible();
    }

    await assertNoConsoleErrors(consoleErrors);
  } finally {
    await cleanupTrackedData(page, state).catch(() => {});
  }
});
