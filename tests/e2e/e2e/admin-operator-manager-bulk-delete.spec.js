require("./test-hooks");

const { test, expect } = require("@playwright/test");

test.describe.configure({ timeout: 120000 });

const ADMIN_USER = {
  email: String(process.env.FPW_ADMIN_EMAIL || "").trim(),
  password: String(process.env.FPW_ADMIN_PASSWORD || "").trim()
};
const OWNER_USER_ID = "187";

if (!ADMIN_USER.email || !ADMIN_USER.password) {
  throw new Error("Missing FPW_ADMIN_EMAIL or FPW_ADMIN_PASSWORD env var");
}

function uniqueSuffix() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

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
  await page.evaluate(() => {
    var form = document.getElementById("loginForm");
    if (!form) return;
    if (typeof form.requestSubmit === "function") {
      form.requestSubmit();
      return;
    }
    form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
  });

  await page.waitForURL(/\/fpw\/app\/dashboard\.cfm/i, { timeout: 30000 });
}

async function createOperator(page, operatorName, phone, notes) {
  const response = await page.context().request.post("/fpw/api/v1/adminOperators.cfc?method=handle&action=save", {
    data: {
      operator: {
        userId: OWNER_USER_ID,
        name: operatorName,
        phone: phone,
        notes: notes
      }
    }
  });
  const payload = await response.json();
  expect(payload.SUCCESS).toBe(true);
  return Number(payload?.DATA?.operatorId || 0);
}

async function bulkDeleteOperatorsByApi(page, operatorIds) {
  if (!Array.isArray(operatorIds) || !operatorIds.length) {
    return null;
  }
  const response = await page.context().request.post("/fpw/api/v1/adminOperators.cfc?method=handle&action=bulkdelete", {
    data: { operatorIds: operatorIds }
  });
  return response.json();
}

async function acceptNextDialog(page, expectedMessage, trigger) {
  const dialogHandled = new Promise((resolve, reject) => {
    page.once("dialog", async (dialog) => {
      try {
        expect(dialog.message()).toBe(expectedMessage);
        await dialog.accept();
        resolve();
      } catch (error) {
        reject(error);
      }
    });
  });

  await trigger();
  await dialogHandled;
}

async function loadOperatorManager(page, searchTerm) {
  await page.goto("/fpw/admin/operator-manager.cfm", { waitUntil: "domcontentloaded" });
  await expect(page.locator("h1")).toContainText("Admin Operator Manager", { timeout: 30000 });
  await page.fill("#filterUserId", OWNER_USER_ID);
  await page.fill("#filterSearch", searchTerm);
  await page.selectOption("#filterLimit", "25");
  await page.locator('button[type="submit"]', { hasText: "Search" }).click();
}

test("Admin Operator Manager bulk deletes checked operators only", async ({ page }) => {
  const suffix = uniqueSuffix();
  const prefix = `PW_ADMIN_BULK_${suffix}`;
  const operatorNames = [
    `${prefix} Alpha`,
    `${prefix} Bravo`,
    `${prefix} Charlie`
  ];
  const createdOperatorIds = [];
  const survivorName = operatorNames[2];

  await loginAdminUser(page);

  try {
    createdOperatorIds.push(await createOperator(page, operatorNames[0], "5555551001", `${prefix} note 1`));
    createdOperatorIds.push(await createOperator(page, operatorNames[1], "5555551002", `${prefix} note 2`));
    createdOperatorIds.push(await createOperator(page, operatorNames[2], "5555551003", `${prefix} note 3`));

    await loadOperatorManager(page, prefix);

    const rowCheckboxes = page.locator("#operatorTableBody .operator-select");
    const bulkDeleteButton = page.locator("#bulkDeleteOperatorsBtn");
    const selectAllCheckbox = page.locator("#selectAllOperators");
    const survivorRow = page.locator("#operatorTableBody tr", { hasText: survivorName });

    await expect(rowCheckboxes).toHaveCount(3, { timeout: 30000 });
    await expect(bulkDeleteButton).toBeDisabled();

    await selectAllCheckbox.check();
    await expect(rowCheckboxes.nth(0)).toBeChecked();
    await expect(rowCheckboxes.nth(1)).toBeChecked();
    await expect(rowCheckboxes.nth(2)).toBeChecked();
    await expect(bulkDeleteButton).toHaveText("Delete Checked (3)");

    await survivorRow.locator(".operator-select").uncheck();
    await expect(bulkDeleteButton).toHaveText("Delete Checked (2)");
    await expect
      .poll(async () => selectAllCheckbox.evaluate((el) => !!el.indeterminate))
      .toBe(true);

    await acceptNextDialog(page, "Delete 2 checked operator(s)?", async () => {
      await bulkDeleteButton.click();
    });

    await expect(page.locator("#adminOperatorMessage")).toContainText("Deleted 2 checked operator(s).", { timeout: 30000 });
    await expect(page.locator("#operatorTableBody tr", { hasText: operatorNames[0] })).toHaveCount(0, { timeout: 30000 });
    await expect(page.locator("#operatorTableBody tr", { hasText: operatorNames[1] })).toHaveCount(0, { timeout: 30000 });
    await expect(survivorRow).toHaveCount(1, { timeout: 30000 });

    await survivorRow.locator(".operator-select").check();
    await expect(bulkDeleteButton).toHaveText("Delete Checked (1)");

    await acceptNextDialog(page, "Delete 1 checked operator(s)?", async () => {
      await bulkDeleteButton.click();
    });

    await expect(page.locator("#operatorTableBody")).toContainText("No operators found.", { timeout: 30000 });
  } finally {
    await bulkDeleteOperatorsByApi(page, createdOperatorIds);
  }
});


