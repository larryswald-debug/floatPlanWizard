require("./test-hooks");

if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
  throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
}

const { test, expect } = require("@playwright/test");

test.describe.configure({ timeout: 120000 });

function uniqueSuffix() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

async function loginToDashboard(page) {
  await page.goto("/fpw/index.cfm", { waitUntil: "domcontentloaded" });
  await page.fill('input[name="email"], input[name="EMAIL"]', process.env.FPW_EMAIL || "");
  await page.fill('input[type="password"], input[name="password"], input[name="PASSWORD"]', process.env.FPW_PASSWORD || "");
  await page.click('button[type="submit"], input[type="submit"]');
  await page.waitForURL(/\/fpw\/app\/dashboard\.cfm/i, { timeout: 30000 });
  await expect(page.locator("#addVesselBtn")).toBeVisible({ timeout: 30000 });
  await expect(page.locator("#addOperatorBtn")).toBeVisible({ timeout: 30000 });
}

async function waitForPanelReady(page, summarySelector) {
  await page.waitForFunction((selector) => {
    const el = document.querySelector(selector);
    if (!el) return false;
    const text = String(el.textContent || "").trim().toLowerCase();
    return !!text && !text.includes("loading");
  }, summarySelector, { timeout: 30000 });
}

async function confirmDelete(page) {
  const confirmModal = page.locator("#confirmModal");
  await expect(confirmModal).toBeVisible({ timeout: 15000 });
  await page.locator("#confirmModalOk").click();
  await expect(confirmModal).toBeHidden({ timeout: 15000 });
}

test("Dashboard Vessels CRUD flow works end-to-end", async ({ page }) => {
  await loginToDashboard(page);
  await waitForPanelReady(page, "#vesselsSummary");

  const suffix = uniqueSuffix();
  const vesselName = `PW Vessel ${suffix}`;
  const vesselNameUpdated = `${vesselName} Updated`;

  await page.click("#addVesselBtn");
  const modal = page.locator("#vesselModal");
  await expect(modal).toBeVisible({ timeout: 15000 });

  await modal.locator("#saveVesselBtn").click();
  await expect(modal.locator("#vesselNameError")).toContainText("Vessel name is required.", { timeout: 10000 });
  await expect(modal.locator("#vesselTypeError")).toContainText("Vessel type is required.", { timeout: 10000 });
  await expect(modal.locator("#vesselLengthError")).toContainText("Vessel length is required.", { timeout: 10000 });
  await expect(modal.locator("#vesselColorError")).toContainText("Hull color is required.", { timeout: 10000 });

  await modal.locator("#vesselName").fill(vesselName);
  await modal.locator("#vesselRegistration").fill(`REG-${suffix}`);
  await modal.locator("#vesselType").fill("Trawler");
  await modal.locator("#vesselLength").fill("36");
  await modal.locator("#vesselMake").fill("FPW");
  await modal.locator("#vesselModel").fill("Playwright");
  await modal.locator("#vesselColor").fill("Blue");
  await modal.locator("#vesselHomePort").fill("Chicago");
  await modal.locator("#saveVesselBtn").click();
  await expect(modal).toBeHidden({ timeout: 20000 });

  const vesselRows = page.locator("#vesselsList .list-item", { hasText: vesselName });
  await expect(vesselRows.first()).toBeVisible({ timeout: 20000 });
  await expect(page.locator("#vesselsSummary")).toContainText(/total|No vessels yet/i);

  await vesselRows.first().locator('button[data-action="edit"]').click();
  await expect(modal).toBeVisible({ timeout: 15000 });
  await expect(modal.locator("#vesselName")).toHaveValue(vesselName);
  await modal.locator("#vesselName").fill(vesselNameUpdated);
  await modal.locator("#vesselColor").fill("Silver");
  await modal.locator("#saveVesselBtn").click();
  await expect(modal).toBeHidden({ timeout: 20000 });

  const updatedRows = page.locator("#vesselsList .list-item", { hasText: vesselNameUpdated });
  await expect(updatedRows.first()).toBeVisible({ timeout: 20000 });

  await updatedRows.first().locator('button[data-action="delete"]').click();
  await confirmDelete(page);
  await expect(page.locator("#vesselsList .list-item", { hasText: vesselNameUpdated })).toHaveCount(0, { timeout: 20000 });
  await expect(page.locator("#vesselsSummary")).toContainText(/total|No vessels yet/i);
});

test("Dashboard Operators CRUD flow works end-to-end", async ({ page }) => {
  await loginToDashboard(page);
  await waitForPanelReady(page, "#operatorsSummary");

  const suffix = uniqueSuffix();
  const operatorName = `PW Operator ${suffix}`;
  const operatorNameUpdated = `${operatorName} Updated`;

  await page.click("#addOperatorBtn");
  const modal = page.locator("#operatorModal");
  await expect(modal).toBeVisible({ timeout: 15000 });

  await modal.locator("#saveOperatorBtn").click();
  await expect(modal.locator("#operatorNameError")).toContainText("Name is required.", { timeout: 10000 });

  await modal.locator("#operatorName").fill(operatorName);
  await modal.locator("#operatorPhone").fill("123");
  await modal.locator("#operatorNotes").fill("Operator validation test");
  await modal.locator("#saveOperatorBtn").click();
  await expect(modal.locator("#operatorPhoneError")).toContainText("valid US phone number", { timeout: 10000 });

  await modal.locator("#operatorPhone").fill("5555551212");
  await modal.locator("#saveOperatorBtn").click();
  await expect(modal).toBeHidden({ timeout: 20000 });

  const operatorRows = page.locator("#operatorsList .list-item", { hasText: operatorName });
  await expect(operatorRows.first()).toBeVisible({ timeout: 20000 });
  await expect(page.locator("#operatorsSummary")).toContainText(/total|No operators yet/i);

  await operatorRows.first().locator('button[data-action="edit"]').click();
  await expect(modal).toBeVisible({ timeout: 15000 });
  await expect(modal.locator("#operatorName")).toHaveValue(operatorName);
  await modal.locator("#operatorName").fill(operatorNameUpdated);
  await modal.locator("#operatorPhone").fill("5555553333");
  await modal.locator("#saveOperatorBtn").click();
  await expect(modal).toBeHidden({ timeout: 20000 });

  const updatedRows = page.locator("#operatorsList .list-item", { hasText: operatorNameUpdated });
  await expect(updatedRows.first()).toBeVisible({ timeout: 20000 });

  await updatedRows.first().locator('button[data-action="delete"]').click();
  await confirmDelete(page);
  await expect(page.locator("#operatorsList .list-item", { hasText: operatorNameUpdated })).toHaveCount(0, { timeout: 20000 });
  await expect(page.locator("#operatorsSummary")).toContainText(/total|No operators yet/i);
});
