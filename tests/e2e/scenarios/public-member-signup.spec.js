const { test, expect } = require("@playwright/test");
const { gotoPublicSignup } = require("../support/fpwSession");

test.describe.configure({ mode: "serial" });

test("public member signup renders the current page and required-field validation", async ({ page }) => {
  await gotoPublicSignup(page);

  await expect(page.getByRole("heading", { name: "Member Sign Up" })).toBeVisible();
  await expect(page.locator("#joinButton")).toHaveText("Create User");

  await page.click("#joinButton");
  await expect(page.locator("#joinAlert")).toContainText("First name, last name, and email are required.");
});

test("public member signup shows the current duplicate-email response without creating a new account", async ({ page }) => {
  await gotoPublicSignup(page);

  await page.fill("#firstName", "Existing");
  await page.fill("#lastName", "Member");
  await page.fill("#email", "lswald@yahoo.com");
  await page.fill("#address", "100 Existing Way");
  await page.fill("#city", "Tampa");
  await page.fill("#state", "FL");
  await page.fill("#zip", "33602");
  await page.fill("#phone", "5555551212");
  await page.click("#joinButton");

  await expect(page.locator("#joinAlert")).toContainText("That email is already registered.");
  await expect(page.locator("#joinButton")).toHaveText("Create User");
});
