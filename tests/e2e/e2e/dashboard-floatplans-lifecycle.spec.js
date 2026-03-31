require("./test-hooks");

if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
  throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
}

const { test, expect } = require("@playwright/test");
const {
  buildFloatPlansFromFirstRoute,
  loginApprovedUser
} = require("../support/fpwSession");

test.describe.configure({ timeout: 120000 });

function uniqueSuffix() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

async function loginToDashboard(page) {
  await loginApprovedUser(page);
  await waitForApiHelpers(page, [
    "getFloatPlanBootstrap",
    "saveFloatPlan",
    "getFloatPlans",
    "deleteFloatPlan"
  ]);
}

async function waitForApiHelpers(page, methodNames) {
  const required = Array.isArray(methodNames) ? methodNames.slice() : [];
  if (!required.length) return;
  await page.waitForFunction((methods) => {
    if (!window.Api) return false;
    for (var i = 0; i < methods.length; i += 1) {
      if (typeof window.Api[methods[i]] !== "function") return false;
    }
    return true;
  }, required, { timeout: 30000 });
}

async function triggerFloatPlansRefresh(page) {
  await page.evaluate(() => {
    document.dispatchEvent(new window.CustomEvent("fpw:floatplans-updated"));
  });
}

async function cleanupPlansByIds(page, planIds) {
  if (page.isClosed()) {
    return { deleted: 0, lookedAt: 0 };
  }
  try {
    await waitForApiHelpers(page, ["deleteFloatPlan"]);
  } catch (e) {
    return { deleted: 0, lookedAt: 0 };
  }
  return page.evaluate(async (ids) => {
    if (!window.Api || typeof window.Api.deleteFloatPlan !== "function") {
      return { deleted: 0, lookedAt: 0 };
    }
    let deleted = 0;
    for (const value of ids || []) {
      const id = Number(value || 0);
      if (!id) continue;
      try {
        const del = await window.Api.deleteFloatPlan(id);
        if (del && del.SUCCESS) deleted += 1;
      } catch (e) {
        // Keep cleanup best-effort.
      }
    }
    return { deleted, lookedAt: Array.isArray(ids) ? ids.length : 0 };
  }, planIds);
}

async function cleanupRoutesByCodes(page, routeCodes) {
  if (page.isClosed()) {
    return { deleted: 0, lookedAt: 0 };
  }
  return page.evaluate(async (codes) => {
    let deleted = 0;
    if (!window.fetch) {
      return { deleted: 0, lookedAt: Array.isArray(codes) ? codes.length : 0 };
    }
    for (const codeValue of codes || []) {
      const routeCode = String(codeValue || "").trim();
      if (!routeCode) continue;
      try {
        const response = await window.fetch(`/fpw/api/v1/routeBuilder.cfc?method=handle&action=deleteRoute&routeCode=${encodeURIComponent(routeCode)}`, {
          credentials: "same-origin"
        });
        const payload = await response.json();
        if (response.ok && payload && payload.SUCCESS) deleted += 1;
      } catch (e) {
        // Keep cleanup best-effort.
      }
    }
    return { deleted, lookedAt: Array.isArray(codes) ? codes.length : 0 };
  }, routeCodes);
}

async function confirmModalOk(page) {
  const confirmModal = page.locator("#confirmModal");
  await expect(confirmModal).toBeVisible({ timeout: 15000 });
  await page.click("#confirmModalOk");
  await expect(confirmModal).toBeHidden({ timeout: 15000 });
}

test("Dashboard float-plan list supports view/delete and check-in UI wiring for route-derived plans", async ({ page }) => {
  let createdPlanIds = [];
  let createdRouteCodes = [];

  await loginToDashboard(page);

  try {
    const built = await buildFloatPlansFromFirstRoute(page);
    expect(!!(built.payload && built.payload.SUCCESS)).toBeTruthy();
    createdPlanIds = built.floatPlanIds.slice();
    if (built.createdTemporaryRoute && built.routeCode) {
      createdRouteCodes.push(built.routeCode);
    }
    expect(createdPlanIds.length).toBeGreaterThan(0);

    await triggerFloatPlansRefresh(page);
    const sourceRow = page.locator("#floatPlansList .list-item", {
      has: page.locator(`[data-action="view"][data-plan-id="${createdPlanIds[0]}"]`)
    }).first();
    await expect(sourceRow).toBeVisible({ timeout: 20000 });
    await expect(page.locator("#floatPlansFilterCount")).toContainText(/Showing/i);

    await sourceRow.locator('button[data-action="view"]').click();
    await expect(page.locator("#floatPlanWizardModal")).toBeVisible({ timeout: 15000 });
    await page.locator("#floatPlanWizardModal .btn-close").click();
    await expect(page.locator("#floatPlanWizardModal")).toBeHidden({ timeout: 15000 });

    await sourceRow.locator('button[data-action="delete"]').click();
    await confirmModalOk(page);
    await expect(page.locator(`#floatPlansList [data-action="view"][data-plan-id="${createdPlanIds[0]}"]`)).toHaveCount(0, { timeout: 20000 });
    createdPlanIds = createdPlanIds.filter((value) => value !== createdPlanIds[0]);

    // Check-in button path is status-gated; inject one synthetic row to validate click/confirm wiring.
    await page.evaluate(() => {
      window.__FPW_CHECKIN_CALLS = [];
      window.__FPW_ORIG_CHECKIN = window.Api.checkInFloatPlan;
      window.Api.checkInFloatPlan = function (floatPlanId) {
        window.__FPW_CHECKIN_CALLS.push(String(floatPlanId));
        return Promise.resolve({ SUCCESS: true, FLOATPLANID: floatPlanId });
      };
      const list = document.getElementById("floatPlansList");
      if (!list) return;
      const row = document.createElement("div");
      row.className = "list-item";
      row.setAttribute("data-test-checkin", "1");
      row.innerHTML = ''
        + '<div class="list-main"><div class="list-title">Synthetic Active Plan:</div><small>Status: Active</small></div>'
        + '<div class="list-actions"><button class="btn-success" type="button" data-action="checkin" data-plan-id="999001">Check-In</button></div>';
      list.prepend(row);
    });

    await page.click('#floatPlansList .list-item[data-test-checkin="1"] button[data-action="checkin"]');
    await confirmModalOk(page);
    await expect.poll(async () => {
      return page.evaluate(() => Array.isArray(window.__FPW_CHECKIN_CALLS) ? window.__FPW_CHECKIN_CALLS.length : 0);
    }, { timeout: 10000 }).toBe(1);
    await expect.poll(async () => {
      return page.evaluate(() => Array.isArray(window.__FPW_CHECKIN_CALLS) ? window.__FPW_CHECKIN_CALLS[0] : "");
    }, { timeout: 10000 }).toBe("999001");

    await page.evaluate(() => {
      if (window.__FPW_ORIG_CHECKIN) {
        window.Api.checkInFloatPlan = window.__FPW_ORIG_CHECKIN;
      }
      document.querySelectorAll('#floatPlansList .list-item[data-test-checkin="1"]').forEach((el) => el.remove());
    });
  } finally {
    await cleanupPlansByIds(page, createdPlanIds);
    await cleanupRoutesByCodes(page, createdRouteCodes);
    await triggerFloatPlansRefresh(page);
  }
});
