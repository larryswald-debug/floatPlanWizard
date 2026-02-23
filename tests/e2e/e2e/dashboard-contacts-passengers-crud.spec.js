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
  await expect(page.locator("#addContactBtn")).toBeVisible({ timeout: 30000 });
  await expect(page.locator("#addPassengerBtn")).toBeVisible({ timeout: 30000 });
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

test("Dashboard Contacts CRUD flow works end-to-end", async ({ page }) => {
  await loginToDashboard(page);
  await waitForPanelReady(page, "#contactsSummary");

  const suffix = uniqueSuffix();
  const contactName = `PW Contact ${suffix}`;
  const contactNameUpdated = `${contactName} Updated`;

  await page.click("#addContactBtn");
  const modal = page.locator("#contactModal");
  await expect(modal).toBeVisible({ timeout: 15000 });

  await modal.locator("#saveContactBtn").click();
  await expect(modal.locator("#contactNameError")).toContainText("Contact name is required.", { timeout: 10000 });
  await expect(modal.locator("#contactPhoneError")).toContainText("Phone is required.", { timeout: 10000 });
  await expect(modal.locator("#contactEmailError")).toContainText("Email is required.", { timeout: 10000 });

  await modal.locator("#contactName").fill(contactName);
  await modal.locator("#contactPhone").fill("123");
  await modal.locator("#contactEmail").fill("not-an-email");
  await modal.locator("#saveContactBtn").click();
  await expect(modal.locator("#contactPhoneError")).toContainText("valid US phone number", { timeout: 10000 });
  await expect(modal.locator("#contactEmailError")).toContainText("valid email address", { timeout: 10000 });

  await modal.locator("#contactPhone").fill("5555551212");
  await modal.locator("#contactEmail").fill(`pw-contact-${suffix}@example.com`);
  await modal.locator("#saveContactBtn").click();
  await expect(modal).toBeHidden({ timeout: 20000 });

  const contactRows = page.locator("#contactsList .list-item", { hasText: contactName });
  await expect(contactRows.first()).toBeVisible({ timeout: 20000 });
  await expect(page.locator("#contactsSummary")).toContainText(/total|No contacts yet/i);

  await contactRows.first().locator('button[data-action="edit"]').click();
  await expect(modal).toBeVisible({ timeout: 15000 });
  await expect(modal.locator("#contactName")).toHaveValue(contactName);
  await modal.locator("#contactName").fill(contactNameUpdated);
  await modal.locator("#contactPhone").fill("5555553333");
  await modal.locator("#saveContactBtn").click();
  await expect(modal).toBeHidden({ timeout: 20000 });

  const updatedRows = page.locator("#contactsList .list-item", { hasText: contactNameUpdated });
  await expect(updatedRows.first()).toBeVisible({ timeout: 20000 });

  await updatedRows.first().locator('button[data-action="delete"]').click();
  await confirmDelete(page);
  await expect(page.locator("#contactsList .list-item", { hasText: contactNameUpdated })).toHaveCount(0, { timeout: 20000 });
  await expect(page.locator("#contactsSummary")).toContainText(/total|No contacts yet/i);
});

test("Dashboard Passengers CRUD flow works end-to-end", async ({ page }) => {
  await loginToDashboard(page);
  await waitForPanelReady(page, "#passengersSummary");

  const suffix = uniqueSuffix();
  const passengerName = `PW Passenger ${suffix}`;
  const passengerNameUpdated = `${passengerName} Updated`;

  await page.click("#addPassengerBtn");
  const modal = page.locator("#passengerModal");
  await expect(modal).toBeVisible({ timeout: 15000 });

  await modal.locator("#savePassengerBtn").click();
  await expect(modal.locator("#passengerNameError")).toContainText("Name is required.", { timeout: 10000 });

  await modal.locator("#passengerName").fill(passengerName);
  await modal.locator("#passengerPhone").fill("123");
  await modal.locator("#passengerAge").fill("44");
  await modal.locator("#passengerGender").fill("Other");
  await modal.locator("#savePassengerBtn").click();
  await expect(modal.locator("#passengerPhoneError")).toContainText("valid US phone number", { timeout: 10000 });

  await modal.locator("#passengerPhone").fill("5555554242");
  await modal.locator("#passengerNotes").fill("Playwright passenger test");
  await modal.locator("#savePassengerBtn").click();
  await expect(modal).toBeHidden({ timeout: 20000 });

  const passengerRows = page.locator("#passengersList .list-item", { hasText: passengerName });
  await expect(passengerRows.first()).toBeVisible({ timeout: 20000 });
  await expect(page.locator("#passengersSummary")).toContainText(/total|No passengers yet/i);

  await passengerRows.first().locator('button[data-action="edit"]').click();
  await expect(modal).toBeVisible({ timeout: 15000 });
  await expect(modal.locator("#passengerName")).toHaveValue(passengerName);
  await modal.locator("#passengerName").fill(passengerNameUpdated);
  await modal.locator("#passengerGender").fill("Female");
  await modal.locator("#savePassengerBtn").click();
  await expect(modal).toBeHidden({ timeout: 20000 });

  const updatedRows = page.locator("#passengersList .list-item", { hasText: passengerNameUpdated });
  await expect(updatedRows.first()).toBeVisible({ timeout: 20000 });

  await updatedRows.first().locator('button[data-action="delete"]').click();
  await confirmDelete(page);
  await expect(page.locator("#passengersList .list-item", { hasText: passengerNameUpdated })).toHaveCount(0, { timeout: 20000 });
  await expect(page.locator("#passengersSummary")).toContainText(/total|No passengers yet/i);
});
