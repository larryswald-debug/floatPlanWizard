require("./test-hooks");

if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
  throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
}

const { test, expect } = require("@playwright/test");
const { loginApprovedUser } = require("../support/fpwSession");

test.describe.configure({ timeout: 120000 });

function uniqueSuffix() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

async function loginToDashboard(page) {
  await loginApprovedUser(page);
  await expect(page.locator("#addWaypointBtn")).toBeVisible({ timeout: 30000 });
}

async function waitForWaypointsPanelReady(page) {
  try {
    await page.waitForFunction(() => {
      const summaryEl = document.querySelector("#waypointsSummary");
      const messageEl = document.querySelector("#waypointsMessage");
      const listEl = document.querySelector("#waypointsList");
      const summaryText = summaryEl ? String(summaryEl.textContent || "").trim() : "";
      const messageText = messageEl ? String(messageEl.textContent || "").trim() : "";
      const listCount = listEl ? listEl.querySelectorAll(".list-item").length : 0;

      if (!summaryText || /loading/i.test(summaryText)) {
        return false;
      }

      if (/^\d+\s+total$/i.test(summaryText)) {
        return true;
      }

      if (/^(no waypoints yet|error|unavailable)$/i.test(summaryText)) {
        return true;
      }

      return listCount > 0 || (!!messageText && !/loading/i.test(messageText));
    }, { timeout: 30000 });
  } catch (error) {
    const panelState = await page.evaluate(() => {
      const summaryEl = document.querySelector("#waypointsSummary");
      const messageEl = document.querySelector("#waypointsMessage");
      const listEl = document.querySelector("#waypointsList");
      return {
        summaryText: summaryEl ? String(summaryEl.textContent || "").trim() : "",
        messageText: messageEl ? String(messageEl.textContent || "").trim() : "",
        listCount: listEl ? listEl.querySelectorAll(".list-item").length : 0
      };
    });
    throw new Error(
      "Timed out waiting for waypoint panel readiness: " +
      JSON.stringify(panelState) +
      ". Original error: " +
      ((error && error.message) ? error.message : String(error))
    );
  }
}

async function confirmDelete(page) {
  const confirmModal = page.locator("#confirmModal");
  await expect(confirmModal).toBeVisible({ timeout: 15000 });
  await page.locator("#confirmModalOk").click();
  await expect(confirmModal).toBeHidden({ timeout: 15000 });
}

async function waitForWaypointMapInit(page) {
  await page.waitForFunction(() => {
    const map = document.getElementById("waypointMap");
    return !!(map && map.classList.contains("leaflet-container"));
  }, { timeout: 30000 });
}

test("Dashboard Waypoints CRUD flow works end-to-end", async ({ page }) => {
  await loginToDashboard(page);
  await waitForWaypointsPanelReady(page);

  const suffix = uniqueSuffix();
  const waypointName = `PW Waypoint ${suffix}`;
  const waypointNameUpdated = `${waypointName} Updated`;

  await page.click("#addWaypointBtn");
  const modal = page.locator("#waypointModal");
  await expect(modal).toBeVisible({ timeout: 15000 });
  await waitForWaypointMapInit(page);
  await expect(modal.locator("#waypointMap")).toBeVisible();

  await modal.locator("#saveWaypointBtn").click();
  await expect(modal.locator("#waypointNameError")).toContainText("Name is required.", { timeout: 10000 });

  await modal.locator("#waypointName").fill(waypointName);
  await modal.locator("#waypointLatitude").fill("41.8781");
  await modal.locator("#waypointLongitude").fill("-87.6298");
  await modal.locator("#waypointNotes").fill("Playwright waypoint test");
  await modal.locator("#saveWaypointBtn").click();
  await expect(modal).toBeHidden({ timeout: 20000 });

  const waypointRows = page.locator("#waypointsList .list-item", { hasText: waypointName });
  await expect(waypointRows.first()).toBeVisible({ timeout: 20000 });
  await expect(page.locator("#waypointsSummary")).toContainText(/total|No waypoints yet/i);

  await waypointRows.first().locator('button[data-action="edit"]').click();
  await expect(modal).toBeVisible({ timeout: 15000 });
  await waitForWaypointMapInit(page);
  await expect(modal.locator("#waypointName")).toHaveValue(waypointName);
  await modal.locator("#waypointName").fill(waypointNameUpdated);
  await modal.locator("#waypointLatitude").fill("41.9800");
  await modal.locator("#waypointLongitude").fill("-87.7000");
  await modal.locator("#saveWaypointBtn").click();
  await expect(modal).toBeHidden({ timeout: 20000 });

  const updatedRows = page.locator("#waypointsList .list-item", { hasText: waypointNameUpdated });
  await expect(updatedRows.first()).toBeVisible({ timeout: 20000 });

  await updatedRows.first().locator('button[data-action="delete"]').click();
  await confirmDelete(page);
  await expect(page.locator("#waypointsList .list-item", { hasText: waypointNameUpdated })).toHaveCount(0, { timeout: 20000 });
  await expect(page.locator("#waypointsSummary")).toContainText(/total|No waypoints yet/i);
});

test("Dashboard Waypoint map click writes coordinates (chromium)", async ({ page, browserName }) => {
  test.skip(browserName !== "chromium", "Map click smoke is chromium-only.");

  await loginToDashboard(page);
  await waitForWaypointsPanelReady(page);

  const suffix = uniqueSuffix();
  const waypointName = `PW Waypoint Click ${suffix}`;

  await page.click("#addWaypointBtn");
  const modal = page.locator("#waypointModal");
  await expect(modal).toBeVisible({ timeout: 15000 });
  await waitForWaypointMapInit(page);

  const latInput = modal.locator("#waypointLatitude");
  const lngInput = modal.locator("#waypointLongitude");
  await expect(latInput).toHaveValue("");
  await expect(lngInput).toHaveValue("");

  await modal.locator("#waypointMap").click({ position: { x: 130, y: 140 } });
  await expect.poll(async () => (await latInput.inputValue()).trim().length > 0).toBe(true);
  await expect.poll(async () => (await lngInput.inputValue()).trim().length > 0).toBe(true);

  await modal.locator("#waypointName").fill(waypointName);
  await modal.locator("#waypointNotes").fill("Map click coordinate write test");
  await modal.locator("#saveWaypointBtn").click();
  await expect(modal).toBeHidden({ timeout: 20000 });

  const waypointRows = page.locator("#waypointsList .list-item", { hasText: waypointName });
  await expect(waypointRows.first()).toBeVisible({ timeout: 20000 });

  await waypointRows.first().locator('button[data-action="delete"]').click();
  await confirmDelete(page);
  await expect(page.locator("#waypointsList .list-item", { hasText: waypointName })).toHaveCount(0, { timeout: 20000 });
});
