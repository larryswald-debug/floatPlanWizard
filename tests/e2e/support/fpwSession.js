const { expect } = require("@playwright/test");
const { submitLoginForm } = require("../e2e/test-hooks");

const APPROVED_USER = {
  email: String(process.env.FPW_EMAIL || "codex@email.com").trim(),
  password: String(process.env.FPW_PASSWORD || "password").trim()
};
const ROUTE_TEMPLATE_CODES = ["GULF-CORE", "GULF-WEST", "GL_REUSE_V2"];

async function loginApprovedUser(page) {
  await submitLoginForm(page, {
    email: APPROVED_USER.email,
    password: APPROVED_USER.password,
    loginUrl: "/fpw/index.cfm",
    waitUntil: "domcontentloaded"
  });
  await page.waitForFunction(() => {
    return /\/fpw\/app\/dashboard\.cfm/i.test(String(window.location.pathname || ""));
  }, { timeout: 30000 });
  await waitForDashboardReady(page);
}

async function waitForDashboardReady(page) {
  await expect(page.locator("#missionSummaryTitle")).toBeVisible({ timeout: 30000 });
  await expect(page.locator("#expeditionTimelinePanel")).toBeVisible({ timeout: 30000 });
  await expect(page.locator("#expeditionTimelineBody")).toBeVisible({ timeout: 30000 });
  await page.waitForFunction(() => {
    function isVisible(selector) {
      const node = document.querySelector(selector);
      return !!(node && node.getClientRects && node.getClientRects().length);
    }
    return isVisible("#expeditionRouteList") || isVisible("#expeditionRouteEmpty");
  }, { timeout: 30000 });
}

async function gotoDashboard(page) {
  await page.goto("/fpw/app/dashboard.cfm", { waitUntil: "domcontentloaded" });
  await waitForDashboardReady(page);
}

async function gotoPublicSignup(page) {
  await page.goto("/fpw/app/join.cfm", { waitUntil: "domcontentloaded" });
  await expect(page.locator("#joinForm")).toBeVisible({ timeout: 30000 });
}

async function waitForSummaryLoaded(page, selector) {
  await page.waitForFunction((summarySelector) => {
    const el = document.querySelector(summarySelector);
    if (!el) {
      return false;
    }
    const text = String(el.textContent || "").trim().toLowerCase();
    return !!text && !text.includes("loading");
  }, selector, { timeout: 30000 });
}

async function openRouteBuilder(page) {
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 30000 });
  await page.click("#openRouteBuilderBtn");
  const routeBuilderModal = page.locator("#routeBuilderModal");
  const openedByClick = await routeBuilderModal.waitFor({ state: "visible", timeout: 5000 })
    .then(() => true)
    .catch(() => false);
  if (!openedByClick) {
    await page.evaluate(() => {
      const openBtn = document.getElementById("openRouteBuilderBtn");
      if (openBtn) {
        openBtn.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, view: window }));
      }
      const modalEl = document.getElementById("routeBuilderModal");
      if (!modalEl || !window.bootstrap || !window.bootstrap.Modal) {
        return;
      }
      window.bootstrap.Modal.getOrCreateInstance(modalEl).show();
    });
  }
  await expect(routeBuilderModal).toBeVisible({ timeout: 30000 });
  await expect(page.locator("#fpwRouteGen")).toBeVisible({ timeout: 30000 });
}

function normalizeBuiltFloatPlanIds(payload) {
  let floatPlanIds = Array.isArray(payload?.FLOATPLAN_IDS)
    ? payload.FLOATPLAN_IDS.map((value) => Number(value || 0)).filter((value) => Number.isFinite(value) && value > 0)
    : [];

  if (!floatPlanIds.length && Array.isArray(payload?.FLOATPLANS)) {
    floatPlanIds = payload.FLOATPLANS
      .map((entry) => Number(entry?.FLOATPLAN_ID || entry?.FLOATPLANID || 0))
      .filter((value) => Number.isFinite(value) && value > 0);
  }

  return floatPlanIds;
}

async function requestBuildFloatPlans(page, routeCode, routeInstanceId) {
  const response = await page.context().request.post("/fpw/api/v1/routeBuilder.cfc?method=handle&action=buildFloatPlansFromRoute", {
    data: {
      routeCode,
      routeInstanceId,
      mode: "DAILY",
      rebuild: 0
    }
  });
  return response.json();
}

function buildRouteStartDate(daysFromNow) {
  const value = new Date();
  value.setDate(value.getDate() + daysFromNow);
  return value.toISOString().slice(0, 10);
}

async function requestRouteTemplateOptions(page, templateCode) {
  const response = await page.context().request.post("/fpw/api/v1/routeBuilder.cfc?method=handle&action=routegen_getoptions", {
    data: {
      template_code: templateCode,
      direction: "CCW"
    }
  });
  return response.json();
}

async function createDedicatedRouteForFloatPlans(page) {
  const attempts = [];

  for (const templateCode of ROUTE_TEMPLATE_CODES) {
    const optionsPayload = await requestRouteTemplateOptions(page, templateCode);
    const startOptions = Array.isArray(optionsPayload?.DATA?.startOptions) ? optionsPayload.DATA.startOptions : [];
    const endOptions = Array.isArray(optionsPayload?.DATA?.endOptions) ? optionsPayload.DATA.endOptions : [];
    const vessels = Array.isArray(optionsPayload?.DATA?.vessels) ? optionsPayload.DATA.vessels : [];

    if (!optionsPayload?.SUCCESS || !startOptions.length || !endOptions.length) {
      attempts.push({
        templateCode,
        success: false,
        message: optionsPayload?.MESSAGE || "",
        errorCode: optionsPayload?.ERROR?.CODE || ""
      });
      continue;
    }

    const selectedVesselId = Number(
      vessels[0]?.VESSELID
      || vessels[0]?.vesselID
      || vessels[0]?.vesselId
      || 0
    );
    const startOption = startOptions[0];
    const endOption = endOptions[endOptions.length - 1];
    const routeName = `PW Route ${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const generateResponse = await page.context().request.post("/fpw/api/v1/routeBuilder.cfc?method=handle&action=routegen_generate", {
      data: {
        template_code: templateCode,
        direction: optionsPayload?.DATA?.direction || "CCW",
        start_segment_id: String(startOption.segment_id || ""),
        end_segment_id: String(endOption.segment_id || ""),
        start_location_label: String(startOption.label || ""),
        end_location_label: String(endOption.label || ""),
        start_date: buildRouteStartDate(10),
        route_name: routeName,
        pace: "RELAXED",
        selected_vessel_id: selectedVesselId > 0 ? String(selectedVesselId) : ""
      }
    });
    const generatePayload = await generateResponse.json();
    const routeCode = String(generatePayload?.ROUTE_CODE || generatePayload?.DATA?.route_code || "").trim();
    const routeInstanceId = Number(generatePayload?.ROUTE_INSTANCE_ID || generatePayload?.DATA?.route_instance_id || 0);

    attempts.push({
      templateCode,
      success: !!generatePayload?.SUCCESS,
      routeCode,
      routeInstanceId,
      message: generatePayload?.MESSAGE || "",
      errorCode: generatePayload?.ERROR?.CODE || ""
    });

    if (generatePayload?.SUCCESS && routeCode && routeInstanceId > 0) {
      return {
        routeCode,
        routeInstanceId,
        createdTemporaryRoute: true
      };
    }
  }

  throw new Error(`Unable to create a dedicated route-backed float-plan source. Attempts: ${JSON.stringify(attempts)}`);
}

async function buildFloatPlansFromRoute(page, routeCode) {
  let resolvedRouteCode = String(routeCode || "").trim();
  let resolvedRouteInstanceId = 0;

  await waitForDashboardReady(page);
  if (!resolvedRouteCode) {
    const createdRoute = await createDedicatedRouteForFloatPlans(page);
    resolvedRouteCode = createdRoute.routeCode;
    resolvedRouteInstanceId = createdRoute.routeInstanceId;
  }

  if (!resolvedRouteInstanceId) {
    const routeCard = page.locator(`.expedition-route-card[data-route-code="${resolvedRouteCode}"]`).first();
    resolvedRouteInstanceId = Number((await routeCard.getAttribute("data-route-instance-id")) || 0);
  }

  const payload = await requestBuildFloatPlans(page, resolvedRouteCode, resolvedRouteInstanceId);
  const floatPlanIds = normalizeBuiltFloatPlanIds(payload);
  if (!payload || payload.SUCCESS !== true || !floatPlanIds.length) {
    throw new Error(`Route-driven float-plan creation failed for ${resolvedRouteCode}: ${JSON.stringify(payload)}`);
  }

  await page.evaluate((detail) => {
    document.dispatchEvent(new window.CustomEvent("fpw:floatplans-updated", { detail }));
  }, {
    routeCode: resolvedRouteCode,
    routeInstanceId: payload.ROUTE_INSTANCE_ID || resolvedRouteInstanceId || 0,
    createdCount: floatPlanIds.length
  });

  await expect(page.locator(currentGroupActionSelector(floatPlanIds[0], "edit"))).toBeVisible({ timeout: 30000 });

  return {
    routeCode: resolvedRouteCode,
    routeInstanceId: payload.ROUTE_INSTANCE_ID || resolvedRouteInstanceId || 0,
    payload,
    floatPlanIds,
    createdTemporaryRoute: !String(routeCode || "").trim()
  };
}

async function buildFloatPlansFromFirstRoute(page) {
  return buildFloatPlansFromRoute(page, "");
}

function currentGroupRowSelector(planId) {
  return `.expedition-route-current-group[data-plan-id="${planId}"]`;
}

function currentGroupActionSelector(planId, action) {
  return `${currentGroupRowSelector(planId)} [data-action="${action}"]`;
}

module.exports = {
  APPROVED_USER,
  createDedicatedRouteForFloatPlans,
  buildFloatPlansFromFirstRoute,
  buildFloatPlansFromRoute,
  currentGroupActionSelector,
  currentGroupRowSelector,
  gotoDashboard,
  gotoPublicSignup,
  loginApprovedUser,
  openRouteBuilder,
  waitForDashboardReady,
  waitForSummaryLoaded
};
