require("./test-hooks");

if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
  throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
}

const { test, expect } = require("@playwright/test");
const {
  buildFloatPlansFromFirstRoute,
  createDedicatedRouteForFloatPlans,
  currentGroupActionSelector,
  currentGroupRowSelector,
  loginApprovedUser
} = require("../support/fpwSession");

test.describe.configure({ timeout: 120000 });

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

async function loginToDashboard(page) {
  await loginApprovedUser(page);
  await waitForApiHelpers(page, [
    "cancelFloatPlan",
    "checkInFloatPlan",
    "deleteFloatPlan",
    "getFloatPlanBootstrap",
    "saveFloatPlan"
  ]);
}

async function cleanupRouteByCode(page, routeCode) {
  if (!routeCode || page.isClosed()) {
    return;
  }
  await page.evaluate(async (code) => {
    try {
      await window.fetch(`/fpw/api/v1/routeBuilder.cfc?method=handle&action=deleteRoute&routeCode=${encodeURIComponent(code)}`, {
        credentials: "same-origin"
      });
    } catch (e) {
      // Best-effort cleanup only.
    }
  }, routeCode);
}

async function confirmModalOk(page) {
  const confirmModal = page.locator("#confirmModal");
  await expect(confirmModal).toBeVisible({ timeout: 15000 });
  await page.click("#confirmModalOk");
  await expect(confirmModal).toBeHidden({ timeout: 15000 });
}

async function refreshRoutesFromDashboard(page) {
  await page.evaluate(() => {
    document.dispatchEvent(new window.CustomEvent("fpw:floatplans-updated", {
      detail: {
        routeCode: "",
        routeInstanceId: 0,
        createdCount: 0
      }
    }));
  });
}

async function injectSyntheticActiveGroup(page, routeCode, planId) {
  await page.evaluate(({ routeCode: code, planId: syntheticPlanId }) => {
    const routeCard = document.querySelector(`.expedition-route-card[data-route-code="${code}"]`);
    if (!routeCard) {
      throw new Error(`Unable to find route card for ${code}`);
    }
    document.querySelectorAll(`.expedition-route-current-group[data-plan-id="${syntheticPlanId}"]`).forEach((node) => node.remove());
    const group = document.createElement("div");
    group.className = "expedition-route-current-group";
    group.setAttribute("data-plan-id", String(syntheticPlanId));
    group.setAttribute("data-current-state", "ACTIVE");
    group.innerHTML = ""
      + '<div class="expedition-route-current-group-main">'
      + '  <div>'
      + '    <div class="expedition-route-current-group-title">Synthetic Active Float Plan</div>'
      + '    <div class="expedition-route-current-group-meta">Synthetic action wiring check.</div>'
      + "  </div>"
      + '  <div class="expedition-route-actions expedition-route-actions--child">'
      + `    <button type="button" class="btn-success js-expedition-plan-checkin" data-action="checkin" data-plan-id="${syntheticPlanId}">Check-In</button>`
      + `    <button type="button" class="btn-secondary js-expedition-plan-cancel" data-action="cancel" data-plan-id="${syntheticPlanId}">Cancel</button>`
      + "  </div>"
      + "</div>";
    routeCard.appendChild(group);
    window.__FPW_CHECKIN_CALLS = Array.isArray(window.__FPW_CHECKIN_CALLS) ? window.__FPW_CHECKIN_CALLS : [];
    window.__FPW_CANCEL_CALLS = Array.isArray(window.__FPW_CANCEL_CALLS) ? window.__FPW_CANCEL_CALLS : [];
    if (!window.__FPW_ORIG_CHECKIN) {
      window.__FPW_ORIG_CHECKIN = window.Api.checkInFloatPlan;
    }
    if (!window.__FPW_ORIG_CANCEL) {
      window.__FPW_ORIG_CANCEL = window.Api.cancelFloatPlan;
    }
    window.Api.checkInFloatPlan = function (floatPlanId) {
      window.__FPW_CHECKIN_CALLS.push(String(floatPlanId));
      return Promise.resolve({ SUCCESS: true, FLOATPLANID: floatPlanId });
    };
    window.Api.cancelFloatPlan = function (floatPlanId) {
      window.__FPW_CANCEL_CALLS.push(String(floatPlanId));
      return Promise.resolve({ SUCCESS: true, FLOATPLANID: floatPlanId });
    };
  }, { routeCode, planId });
}

test("Routes panel renders the current draft group and wires view, delete, check-in, and cancel actions", async ({ page }) => {
  let createdRouteCode = "";
  let secondaryRouteCode = "";
  let createdPlanId = 0;

  await loginToDashboard(page);

  try {
    const built = await buildFloatPlansFromFirstRoute(page);
    expect(!!(built.payload && built.payload.SUCCESS)).toBeTruthy();
    createdRouteCode = built.createdTemporaryRoute ? built.routeCode : "";
    createdPlanId = built.floatPlanIds[0] || 0;
    expect(createdPlanId).toBeGreaterThan(0);

    const draftGroupRow = page.locator(currentGroupRowSelector(createdPlanId));
    await expect(draftGroupRow).toBeVisible({ timeout: 20000 });
    await expect(draftGroupRow).toContainText(/Draft Float Plan/i);
    await expect(draftGroupRow.locator('[data-action="delete"]')).toHaveCount(0);

    await page.locator(currentGroupActionSelector(createdPlanId, "view")).click();
    await expect(page.locator("#floatPlanWizardModal")).toBeVisible({ timeout: 15000 });
    await page.locator("#floatPlanWizardModal .btn-close").click();
    await expect(page.locator("#floatPlanWizardModal")).toBeHidden({ timeout: 15000 });

    const secondaryRoute = await createDedicatedRouteForFloatPlans(page);
    secondaryRouteCode = secondaryRoute.routeCode;
    await refreshRoutesFromDashboard(page);
    const secondaryActivateButton = page.locator(`.expedition-route-card[data-route-code="${secondaryRouteCode}"] .js-expedition-build-floatplans`).first();
    await expect(secondaryActivateButton).toBeVisible({ timeout: 20000 });
    await secondaryActivateButton.click();
    await expect(page.locator("#alertModal")).toBeVisible({ timeout: 15000 });
    await expect(page.locator("#alertModalMessage")).toContainText("Another route already has the current route/float-plan group.");
    await page.locator("#alertModal .btn-close, #alertModal .btn-primary, #alertModal .btn-secondary").first().click().catch(() => {});
    await page.keyboard.press("Escape").catch(() => {});

    await injectSyntheticActiveGroup(page, built.routeCode, 999001);
    await page.locator(currentGroupActionSelector(999001, "checkin")).click();
    await confirmModalOk(page);
    await expect.poll(async () => page.evaluate(() => (window.__FPW_CHECKIN_CALLS || [])[0] || ""), { timeout: 10000 }).toBe("999001");

    await expect(page.locator(`.expedition-route-card[data-route-code="${built.routeCode}"]`)).toBeVisible({ timeout: 15000 });
    await injectSyntheticActiveGroup(page, built.routeCode, 999002);
    await page.locator(currentGroupActionSelector(999002, "cancel")).click();
    await confirmModalOk(page);
    await expect.poll(async () => page.evaluate(() => (window.__FPW_CANCEL_CALLS || [])[0] || ""), { timeout: 10000 }).toBe("999002");

    const routeDeleteButton = page.locator(`.expedition-route-card[data-route-code="${built.routeCode}"] .js-expedition-delete`).first();
    await routeDeleteButton.click();
    await confirmModalOk(page);
    await expect(page.locator(currentGroupRowSelector(createdPlanId))).toHaveCount(0, { timeout: 20000 });
    await expect(page.locator(`.expedition-route-card[data-route-code="${built.routeCode}"]`)).toHaveCount(0, { timeout: 20000 });
    createdRouteCode = "";
  } finally {
    if (!page.isClosed()) {
      await page.evaluate(() => {
        if (window.__FPW_ORIG_CHECKIN) {
          window.Api.checkInFloatPlan = window.__FPW_ORIG_CHECKIN;
        }
        if (window.__FPW_ORIG_CANCEL) {
          window.Api.cancelFloatPlan = window.__FPW_ORIG_CANCEL;
        }
        document.querySelectorAll('.expedition-route-current-group[data-plan-id="999001"], .expedition-route-current-group[data-plan-id="999002"]').forEach((node) => node.remove());
      }).catch(() => {});
    }
    await cleanupRouteByCode(page, secondaryRouteCode);
    await cleanupRouteByCode(page, createdRouteCode);
  }
});
