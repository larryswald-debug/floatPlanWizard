require("./test-hooks");

if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
  throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
}

const { test, expect } = require("@playwright/test");

async function loginToDashboard(page) {
  await page.goto("/fpw/index.cfm", { waitUntil: "domcontentloaded" });
  await page.fill('input[name="email"], input[name="EMAIL"]', process.env.FPW_EMAIL || "");
  await page.fill('input[type="password"], input[name="password"], input[name="PASSWORD"]', process.env.FPW_PASSWORD || "");
  await page.click('button[type="submit"], input[type="submit"]');
  await page.waitForLoadState("networkidle");
  await expect(page).not.toHaveURL(/index\.cfm$/i);
}

test("WPI ports overlay supports search, clear, ajax save, and in-place restore", async ({ page }) => {
  await page.route("https://nominatim.openstreetmap.org/search*", async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify([
        {
          lat: "41.878113",
          lon: "-87.629799",
          display_name: "Chicago, Cook County, Illinois, United States",
          address: { state: "Illinois" }
        }
      ])
    });
  });

  await loginToDashboard(page);
  await page.goto("/fpw/admin/wpi_port_populate.cfm?portPageSize=25", { waitUntil: "domcontentloaded" });
  await expect(page.locator("#wpiPortsEditorCard .js-wpi-map-btn").first()).toBeVisible({ timeout: 20000 });

  const row = await page.evaluate(() => {
    const btn = document.querySelector("#wpiPortsEditorCard .js-wpi-map-btn");
    if (!btn) return null;
    const formId = btn.getAttribute("data-form-id");
    if (!formId) return null;
    const read = (name) => {
      const el = document.querySelector('input[form="' + formId + '"][name="' + name + '"]');
      return el ? String(el.value || "") : "";
    };
    return {
      formId,
      originalState: read("state"),
      originalLat: read("lat"),
      originalLng: read("lng")
    };
  });

  expect(row).toBeTruthy();
  const formId = row.formId;
  await page.click(`#wpiPortsEditorCard .js-wpi-map-btn[data-form-id="${formId}"]`);
  await expect(page.locator("#wpiPortMapOverlay")).toHaveClass(/is-open/, { timeout: 10000 });

  await page.fill("#wpiPortMapSearchName", "Chicago");
  await page.fill("#wpiPortMapSearchState", "IL");
  await page.click("#wpiPortMapSearchBtn");
  await expect(page.locator("#wpiPortMapStatus")).toContainText(/Search result applied/i, { timeout: 10000 });

  await expect(page.locator(`input[form="${formId}"][name="lat"]`)).toHaveValue("41.878113");
  await expect(page.locator(`input[form="${formId}"][name="lng"]`)).toHaveValue("-87.629799");
  await expect(page.locator(`input[form="${formId}"][name="state"]`)).toHaveValue("Illinois");

  await page.click("#wpiPortMapSearchClearBtn");
  await expect(page.locator("#wpiPortMapStatus")).toContainText(/Coordinates cleared/i, { timeout: 10000 });
  await expect(page.locator(`input[form="${formId}"][name="lat"]`)).toHaveValue("");
  await expect(page.locator(`input[form="${formId}"][name="lng"]`)).toHaveValue("");

  await page.click("#wpiPortMapSaveBtn");
  await expect(page.locator("#wpiPortMapStatus")).toContainText(/Overlay remains open/i, { timeout: 15000 });
  await expect(page.locator("#wpiPortMapOverlay")).toHaveClass(/is-open/, { timeout: 10000 });
  await page.click("#wpiPortMapCloseBtn");
  await expect(page.locator("#wpiPortMapOverlay")).not.toHaveClass(/is-open/, { timeout: 10000 });

  await page.fill(`input[form="${formId}"][name="state"]`, row.originalState || "");
  await page.fill(`input[form="${formId}"][name="lat"]`, row.originalLat || "");
  await page.fill(`input[form="${formId}"][name="lng"]`, row.originalLng || "");
  await page.click(`button[form="${formId}"][type="submit"]`);
  await expect(page.locator(`input[form="${formId}"][name="state"]`)).toHaveValue(row.originalState || "", { timeout: 15000 });
  await expect(page.locator(`input[form="${formId}"][name="lat"]`)).toHaveValue(row.originalLat || "", { timeout: 15000 });
  await expect(page.locator(`input[form="${formId}"][name="lng"]`)).toHaveValue(row.originalLng || "", { timeout: 15000 });
});
