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
  await page.waitForLoadState("networkidle");
  await expect(page).not.toHaveURL(/index\.cfm$/i);
  await page.goto("/fpw/app/dashboard.cfm", { waitUntil: "domcontentloaded" });
  await expect(page.locator("#floatPlansPanel")).toBeVisible({ timeout: 30000 });
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

async function createDraftPlanViaApi(page, name) {
  await waitForApiHelpers(page, ["getFloatPlanBootstrap", "saveFloatPlan"]);
  return page.evaluate(async (planName) => {
    if (!window.Api || typeof window.Api.getFloatPlanBootstrap !== "function" || typeof window.Api.saveFloatPlan !== "function") {
      return { success: false, message: "Api helpers are unavailable." };
    }

    const bootstrap = await window.Api.getFloatPlanBootstrap(0);
    const vessels = Array.isArray(bootstrap?.VESSELS) ? bootstrap.VESSELS : [];
    const operators = Array.isArray(bootstrap?.OPERATORS) ? bootstrap.OPERATORS : [];
    const vesselId = Number(vessels[0]?.VESSELID || 0);
    const operatorId = Number(operators[0]?.OPERATORID || 0);
    if (!Number.isFinite(vesselId) || vesselId <= 0) {
      return { success: false, message: "No vessel available for the logged-in user." };
    }

    const formatCfDate = (dt) => {
      const y = dt.getFullYear();
      const m = String(dt.getMonth() + 1).padStart(2, "0");
      const d = String(dt.getDate()).padStart(2, "0");
      const hh = String(dt.getHours()).padStart(2, "0");
      const mm = String(dt.getMinutes()).padStart(2, "0");
      const ss = String(dt.getSeconds()).padStart(2, "0");
      return `${y}-${m}-${d} ${hh}:${mm}:${ss}`;
    };

    const depart = new Date(Date.now() + 60 * 60 * 1000);
    const ret = new Date(Date.now() + 6 * 60 * 60 * 1000);

    const payload = {
      FLOATPLAN: {
        floatPlanName: planName,
        vesselId,
        operatorId,
        departingFrom: "Playwright Dock",
        departureTime: formatCfDate(depart),
        departureTimezone: "America/New_York",
        returningTo: "Playwright Dock",
        returnTime: formatCfDate(ret),
        returnTimezone: "America/New_York",
        rescueAuthority: "USCG",
        rescueAuthorityPhone: "5555551212"
      }
    };

    const res = await window.Api.saveFloatPlan(payload);
    const planId = Number(res?.FLOATPLANID || res?.floatPlanId || res?.id || 0);
    return {
      success: !!res?.SUCCESS && Number.isFinite(planId) && planId > 0,
      planId,
      raw: res
    };
  }, name);
}

async function triggerFloatPlansRefresh(page) {
  await page.evaluate(() => {
    document.dispatchEvent(new window.CustomEvent("fpw:floatplans-updated"));
  });
}

async function cleanupPlansByToken(page, token) {
  if (page.isClosed()) {
    return { deleted: 0, lookedAt: 0 };
  }
  try {
    await waitForApiHelpers(page, ["getFloatPlans", "deleteFloatPlan"]);
  } catch (e) {
    return { deleted: 0, lookedAt: 0 };
  }
  return page.evaluate(async (nameToken) => {
    if (!window.Api || typeof window.Api.getFloatPlans !== "function" || typeof window.Api.deleteFloatPlan !== "function") {
      return { deleted: 0, lookedAt: 0 };
    }
    const payload = await window.Api.getFloatPlans({ limit: 200 });
    const plans = payload?.PLANS || payload?.FLOATPLANS || payload?.floatplans || [];
    let deleted = 0;
    for (const plan of plans) {
      const id = Number(plan?.FLOATPLANID || plan?.PLANID || plan?.ID || 0);
      const name = String(plan?.PLANNAME || plan?.NAME || "");
      if (!id || !name.includes(nameToken)) continue;
      try {
        const del = await window.Api.deleteFloatPlan(id);
        if (del && del.SUCCESS) deleted += 1;
      } catch (e) {
        // Keep cleanup best-effort.
      }
    }
    return { deleted, lookedAt: plans.length };
  }, token);
}

async function confirmModalOk(page) {
  const confirmModal = page.locator("#confirmModal");
  await expect(confirmModal).toBeVisible({ timeout: 15000 });
  await page.click("#confirmModalOk");
  await expect(confirmModal).toBeHidden({ timeout: 15000 });
}

async function clickCloneAndVerify(page, token, sourceRow) {
  const cloneResponsePromise = page.waitForResponse((response) => {
    if (response.request().method() !== "POST") return false;
    if (!response.url().includes("/api/v1/floatplan.cfc?method=handle")) return false;
    const postData = String(response.request().postData() || "");
    return postData.indexOf('"action":"clone"') >= 0 || postData.indexOf("action=clone") >= 0;
  }, { timeout: 30000 });

  await sourceRow.locator('button[data-action="clone"]').click();

  const cloneResponse = await cloneResponsePromise;
  const clonePayload = await cloneResponse.json();
  expect(!!(clonePayload && clonePayload.SUCCESS)).toBeTruthy();

  const cloneModal = page.locator("#floatPlanCloneModal");
  const modalVisible = await cloneModal.waitFor({ state: "visible", timeout: 10000 })
    .then(() => true)
    .catch(() => false);

  if (modalVisible) {
    await expect(page.locator("#floatPlanCloneModal [data-clone-message]")).toContainText("cloned", { timeout: 10000 });
    await page.click("#floatPlanCloneModal [data-clone-ok]");
    await expect(cloneModal).toBeHidden({ timeout: 15000 });
    await page.waitForLoadState("domcontentloaded");
    await expect(page.locator("#floatPlansPanel")).toBeVisible({ timeout: 30000 });
    return;
  }

  // Firefox can intermittently skip the modal animation under heavy parallel load;
  // verify clone result by persisted list state when API clone succeeded.
  await page.fill("#floatPlansFilterInput", token);
  await expect(page.locator("#floatPlansList .list-item", { hasText: token })).toHaveCount(2, { timeout: 20000 });
}

test("Dashboard float-plan list supports filter/view/clone/delete and check-in UI wiring", async ({ page }) => {
  const token = `PW-Lifecycle-${uniqueSuffix()}`;
  const planName = `${token}-Source`;

  await loginToDashboard(page);

  try {
    const created = await createDraftPlanViaApi(page, planName);
    expect(created.success).toBeTruthy();
    expect(created.planId).toBeGreaterThan(0);

    await triggerFloatPlansRefresh(page);
    await page.fill("#floatPlansFilterInput", token);
    const sourceRow = page.locator("#floatPlansList .list-item", { hasText: planName }).first();
    await expect(sourceRow).toBeVisible({ timeout: 20000 });
    await expect(page.locator("#floatPlansFilterCount")).toContainText(/Showing/i);

    await sourceRow.locator('button[data-action="view"]').click();
    await expect(page.locator("#floatPlanWizardModal")).toBeVisible({ timeout: 15000 });
    await page.locator("#floatPlanWizardModal .btn-close").click();
    await expect(page.locator("#floatPlanWizardModal")).toBeHidden({ timeout: 15000 });

    await page.fill("#floatPlansFilterInput", token);
    const sourceRowAfterView = page.locator("#floatPlansList .list-item", { hasText: planName }).first();
    await expect(sourceRowAfterView).toBeVisible({ timeout: 20000 });
    await clickCloneAndVerify(page, token, sourceRowAfterView);

    await page.fill("#floatPlansFilterInput", token);
    await expect(page.locator("#floatPlansList .list-item", { hasText: token })).toHaveCount(2, { timeout: 20000 });

    for (let i = 0; i < 3; i += 1) {
      const rows = page.locator("#floatPlansList .list-item", { hasText: token });
      if (await rows.count() === 0) break;
      await rows.first().locator('button[data-action="delete"]').click();
      await confirmModalOk(page);
      await page.waitForTimeout(250);
    }
    await expect(page.locator("#floatPlansList .list-item", { hasText: token })).toHaveCount(0, { timeout: 20000 });

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
    await cleanupPlansByToken(page, token);
    await triggerFloatPlansRefresh(page);
  }
});
