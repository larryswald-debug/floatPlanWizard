const { test, expect } = require("@playwright/test");
const { assertNoConsoleErrors, attachConsoleErrorCollector } = require("../support/fpwAssertions");
const { loginApprovedUser } = require("../support/fpwSession");

test.describe.configure({ mode: "serial" });

test("login verifies the approved account can reach the dashboard", async ({ page }) => {
  await loginApprovedUser(page);
  const consoleErrors = attachConsoleErrorCollector(page);

  await expect(page.locator("#missionSummaryTitle")).toHaveText("Mission Summary");
  await expect(page.locator("#expeditionTimelineTitle")).toHaveText("Routes");
  await expect(page.locator("#expeditionRouteList")).toBeVisible();
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible();

  await assertNoConsoleErrors(consoleErrors);
});
