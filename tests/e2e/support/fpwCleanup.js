const fs = require("fs/promises");
const path = require("path");

const PDF_OUTPUT_DIR = "/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/floatPlans/user_float_plans";
const ACTIVE_FLOAT_PLAN_STATUSES = new Set([
  "ACTIVE",
  "DUE_NOW",
  "OVERDUE",
  "OVERDUE_1H",
  "OVERDUE_2H",
  "OVERDUE_3H",
  "OVERDUE_4H",
  "OVERDUE_12H",
  "OVERDUE_24H"
]);
const CURRENT_GROUP_FLOAT_PLAN_STATUSES = new Set([
  "DRAFT",
  ...ACTIVE_FLOAT_PLAN_STATUSES
]);
const TEST_FLOAT_PLAN_PREFIXES = ["PW_", "TB_", "codex_"];

function normalizeStatus(value) {
  return String(value || "").trim().toUpperCase();
}

function extractErrorCode(payload) {
  if (!payload || typeof payload !== "object") {
    return "";
  }
  if (payload.ERROR && typeof payload.ERROR === "object" && payload.ERROR.CODE) {
    return String(payload.ERROR.CODE || "").trim().toUpperCase();
  }
  if (payload.ERROR) {
    return String(payload.ERROR || "").trim().toUpperCase();
  }
  return "";
}

function extractRouteInstanceId(plan) {
  return Number(plan.ROUTE_INSTANCE_ID || plan.route_instance_id || 0);
}

function createCleanupState() {
  return {
    contactIds: [],
    floatPlanIds: [],
    operatorIds: [],
    passengerIds: [],
    pdfPrefixes: [],
    routeCodes: [],
    userRouteIds: [],
    vesselIds: [],
    waypointIds: []
  };
}

function trackId(state, key, value) {
  const numericValue = Number(value || 0);
  if (!numericValue || !state || !Array.isArray(state[key])) {
    return;
  }
  if (!state[key].includes(numericValue)) {
    state[key].push(numericValue);
  }
}

function trackValue(state, key, value) {
  const normalized = String(value || "").trim();
  if (!normalized || !state || !Array.isArray(state[key])) {
    return;
  }
  if (!state[key].includes(normalized)) {
    state[key].push(normalized);
  }
}

async function postJson(page, url, payload) {
  const response = await page.context().request.post(url, {
    data: payload || {}
  });
  const json = await response.json();
  if (!response.ok() || json.SUCCESS === false) {
    throw new Error(`Request failed for ${url}: ${JSON.stringify(json)}`);
  }
  return json;
}

async function postJsonAllowFailure(page, url, payload) {
  const response = await page.context().request.post(url, {
    data: payload || {}
  });
  const json = await response.json();
  return {
    ok: response.ok(),
    json
  };
}

async function getJson(page, url) {
  const response = await page.context().request.get(url);
  const json = await response.json();
  if (!response.ok() || json.SUCCESS === false) {
    throw new Error(`Request failed for ${url}: ${JSON.stringify(json)}`);
  }
  return json;
}

async function loadRouteCodeForRouteInstance(page, routeInstanceId) {
  const numericRouteInstanceId = Number(routeInstanceId || 0);
  if (!numericRouteInstanceId) {
    return "";
  }

  const payload = await getJson(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=listUserRoutes");
  const routes = Array.isArray(payload.ROUTES) ? payload.ROUTES : [];
  const match = routes.find((route) => {
    return Number(route.ROUTE_INSTANCE_ID || route.route_instance_id || route.routeInstanceId || 0) === numericRouteInstanceId;
  });

  return String(
    (match && (match.ROUTE_CODE || match.route_code || match.routeCode))
    || ""
  ).trim();
}

async function deleteRouteByCode(page, routeCode) {
  const normalizedRouteCode = String(routeCode || "").trim();
  if (!normalizedRouteCode) {
    return;
  }

  const deleteResponse = await postJsonAllowFailure(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=deleteRoute", {
    routeCode: normalizedRouteCode
  });
  const deletePayload = deleteResponse.json || {};
  const deleteErrorCode = extractErrorCode(deletePayload);
  const deleteMessage = String(deletePayload.MESSAGE || "").trim().toUpperCase();
  if (!deleteResponse.ok || deletePayload.SUCCESS === false) {
    if (
      deleteErrorCode === "ROUTE_NOT_FOUND"
      || deleteErrorCode === "NOT_FOUND"
      || deleteMessage === "ROUTE NOT FOUND"
      || deleteMessage === "ROUTE IS NOT AVAILABLE FOR THIS USER."
    ) {
      return;
    }
    throw new Error(`Unable to delete route ${normalizedRouteCode}: ${JSON.stringify(deletePayload)}`);
  }
}

async function closeFloatPlanForCleanup(page, floatPlanId) {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const closeResponse = await postJsonAllowFailure(page, "/fpw/api/v1/floatplan.cfc?method=handle", {
      action: "checkin",
      floatPlanId
    });
    const closePayload = closeResponse.json || {};
    if (closeResponse.ok && closePayload.SUCCESS !== false) {
      return closePayload;
    }
    if (String(closePayload.ERROR || "").trim().toUpperCase() !== "CLOSE_TRIP_BLOCKED") {
      throw new Error(`Unable to close float plan ${floatPlanId}: ${JSON.stringify(closePayload)}`);
    }

    await postJson(page, "/fpw/api/v1/floatplan.cfc?method=handle", {
      action: "completeleg",
      floatPlanId
    });

    const startNextResponse = await postJsonAllowFailure(page, "/fpw/api/v1/floatplan.cfc?method=handle", {
      action: "startnextleg",
      floatPlanId
    });
    const startNextPayload = startNextResponse.json || {};
    if (startNextResponse.ok && startNextPayload.SUCCESS !== false) {
      continue;
    }
    throw new Error(`Unable to advance float plan ${floatPlanId} to the next leg: ${JSON.stringify(startNextPayload)}`);
  }

  throw new Error(`Unable to close float plan ${floatPlanId}: exceeded lifecycle attempts.`);
}

async function loadFloatPlanBootstrap(page, floatPlanId) {
  const response = await postJsonAllowFailure(page, "/fpw/api/v1/floatplan.cfc?method=handle", {
    action: "bootstrap",
    floatPlanId
  });
  const payload = response.json || {};
  const errorCode = extractErrorCode(payload);
  if (!response.ok || payload.SUCCESS === false) {
    if (errorCode === "NOT_FOUND" || errorCode === "PLAN_NOT_FOUND") {
      return null;
    }
    throw new Error(`Unable to bootstrap float plan ${floatPlanId}: ${JSON.stringify(payload)}`);
  }
  return payload;
}

async function endActiveFloatPlanForCleanup(page, floatPlanId) {
  const bootstrap = await loadFloatPlanBootstrap(page, floatPlanId);
  if (!bootstrap) {
    return null;
  }

  const plan = bootstrap.FLOATPLAN || {};
  const status = normalizeStatus(plan.STATUS);
  const routeInstanceId = extractRouteInstanceId(plan);

  if (!ACTIVE_FLOAT_PLAN_STATUSES.has(status)) {
    return bootstrap;
  }

  if (routeInstanceId > 0) {
    const cancelResponse = await postJsonAllowFailure(page, "/fpw/api/v1/floatplan.cfc?method=handle", {
      action: "cancel",
      floatPlanId
    });
    const cancelPayload = cancelResponse.json || {};
    if (cancelResponse.ok && cancelPayload.SUCCESS !== false) {
      return cancelPayload;
    }
  } else {
    await closeFloatPlanForCleanup(page, floatPlanId);
  }

  return loadFloatPlanBootstrap(page, floatPlanId).catch(() => null);
}

async function cleanupFloatPlan(page, floatPlanId) {
  const bootstrap = await loadFloatPlanBootstrap(page, floatPlanId);
  if (!bootstrap) {
    return;
  }
  const plan = bootstrap.FLOATPLAN || {};
  const status = normalizeStatus(plan.STATUS);
  const routeInstanceId = extractRouteInstanceId(plan);

  if (ACTIVE_FLOAT_PLAN_STATUSES.has(status)) {
    if (routeInstanceId > 0) {
      const cancelResponse = await postJsonAllowFailure(page, "/fpw/api/v1/floatplan.cfc?method=handle", {
        action: "cancel",
        floatPlanId
      });
      const cancelPayload = cancelResponse.json || {};
      if (!(cancelResponse.ok && cancelPayload.SUCCESS !== false)) {
        return;
      }
    } else {
      await closeFloatPlanForCleanup(page, floatPlanId);
    }
  }

  if (routeInstanceId > 0) {
    const routeCode = await loadRouteCodeForRouteInstance(page, routeInstanceId);
    if (routeCode) {
      await deleteRouteByCode(page, routeCode);
      return;
    }
  }

  const deleteResponse = await postJsonAllowFailure(page, "/fpw/api/v1/floatplan.cfc?method=handle", {
    action: "delete",
    floatPlanId
  });
  const deletePayload = deleteResponse.json || {};
  const deleteErrorCode = extractErrorCode(deletePayload);
  if (!deleteResponse.ok || deletePayload.SUCCESS === false) {
    if (
      deleteErrorCode === "NOT_FOUND"
      || deleteErrorCode === "PLAN_NOT_FOUND"
      || deleteErrorCode === "ROUTE_GROUP_DELETE_REQUIRED"
    ) {
      return;
    }
    throw new Error(`Unable to delete float plan ${floatPlanId}: ${JSON.stringify(deletePayload)}`);
  }
}

function isTestFloatPlanName(name) {
  const normalized = String(name || "").trim();
  if (!normalized) {
    return false;
  }
  return TEST_FLOAT_PLAN_PREFIXES.some((prefix) => normalized.startsWith(prefix));
}

async function cleanupBlockingActiveTestFloatPlans(page) {
  const payload = await getJson(page, "/fpw/api/v1/floatplans.cfc?method=handle&limit=20");
  const plans = Array.isArray(payload.PLANS) ? payload.PLANS : [];

  for (const plan of plans) {
    const floatPlanId = Number(plan.FLOATPLANID || 0);
    const status = String(plan.STATUS || "").trim().toUpperCase();
    const planName = String(plan.PLANNAME || "").trim();

    if (!floatPlanId || !CURRENT_GROUP_FLOAT_PLAN_STATUSES.has(status) || !isTestFloatPlanName(planName)) {
      continue;
    }

    await cleanupFloatPlan(page, floatPlanId);
  }
}

async function cleanupCurrentRouteFloatPlanGroup(page) {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const currentGroup = page.locator(".expedition-route-current-group").first();
    if (await currentGroup.count() === 0) {
      return;
    }

    const floatPlanId = Number(await currentGroup.getAttribute("data-plan-id") || 0);
    const routeCard = currentGroup.locator("xpath=ancestor::div[contains(@class,'expedition-route-card')]").first();
    const routeCode = String(await routeCard.getAttribute("data-route-code") || "").trim();
    const currentState = String(await currentGroup.getAttribute("data-current-state") || "").trim().toUpperCase();

    if (currentState === "ACTIVE" && floatPlanId > 0) {
      const cancelResponse = await postJsonAllowFailure(page, "/fpw/api/v1/floatplan.cfc?method=handle", {
        action: "cancel",
        floatPlanId
      });
      const cancelPayload = cancelResponse.json || {};
      const cancelErrorCode = extractErrorCode(cancelPayload);
      if (cancelResponse.ok && cancelPayload.SUCCESS !== false) {
        await page.waitForTimeout(250);
        continue;
      }
      if (cancelErrorCode !== "NO_ACTIVE_GROUP") {
        throw new Error(`Unable to cancel current route/float-plan group ${floatPlanId}: ${JSON.stringify(cancelPayload)}`);
      }
    }

    if (routeCode) {
      await deleteRouteByCode(page, routeCode);
      await page.waitForTimeout(250);
      continue;
    }

    break;
  }
}

async function cleanupTrackedData(page, state) {
  const floatPlanIds = state.floatPlanIds.slice().reverse();
  for (const floatPlanId of floatPlanIds) {
    await endActiveFloatPlanForCleanup(page, floatPlanId);
  }

  const routeCodes = state.routeCodes.slice().reverse();
  for (const routeCode of routeCodes) {
    const deleteResponse = await postJsonAllowFailure(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=deleteRoute", {
      routeCode
    });
    const deletePayload = deleteResponse.json || {};
    const deleteErrorCode = extractErrorCode(deletePayload);
    if (!deleteResponse.ok || deletePayload.SUCCESS === false) {
      if (
        deleteErrorCode === "ROUTE_NOT_FOUND"
        || deleteErrorCode === "NOT_FOUND"
      ) {
        continue;
      }
      throw new Error(`Unable to delete route ${routeCode}: ${JSON.stringify(deletePayload)}`);
    }
  }

  for (const floatPlanId of floatPlanIds) {
    await cleanupFloatPlan(page, floatPlanId);
  }

  const userRouteIds = state.userRouteIds.slice().reverse();
  for (const routeId of userRouteIds) {
    await postJson(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=deleteUserRoute", {
      route_id: routeId
    });
  }

  const vesselIds = state.vesselIds.slice().reverse();
  for (const vesselId of vesselIds) {
    await postJson(page, "/fpw/api/v1/vessel.cfc?method=handle", {
      action: "delete",
      vesselId
    });
  }

  const operatorIds = state.operatorIds.slice().reverse();
  for (const operatorId of operatorIds) {
    await postJson(page, "/fpw/api/v1/operator.cfc?method=handle", {
      action: "delete",
      operatorId
    });
  }

  const contactIds = state.contactIds.slice().reverse();
  for (const contactId of contactIds) {
    await postJson(page, "/fpw/api/v1/contact.cfc?method=handle", {
      action: "delete",
      contactId
    });
  }

  const passengerIds = state.passengerIds.slice().reverse();
  for (const passengerId of passengerIds) {
    await postJson(page, "/fpw/api/v1/passenger.cfc?method=handle", {
      action: "delete",
      passengerId
    });
  }

  const waypointIds = state.waypointIds.slice().reverse();
  for (const waypointId of waypointIds) {
    await postJson(page, "/fpw/api/v1/waypoint.cfc?method=handle", {
      action: "delete",
      waypointId
    });
  }

  const pdfPrefixes = state.pdfPrefixes.slice();
  for (const prefix of pdfPrefixes) {
    await deletePdfFilesByPrefix(prefix);
  }
}

async function deletePdfFilesByPrefix(prefix) {
  const entries = await fs.readdir(PDF_OUTPUT_DIR, { withFileTypes: true });
  const matching = entries.filter((entry) => entry.isFile() && entry.name.startsWith(prefix));
  for (const entry of matching) {
    await fs.unlink(path.join(PDF_OUTPUT_DIR, entry.name));
  }
}

module.exports = {
  cleanupBlockingActiveTestFloatPlans,
  cleanupCurrentRouteFloatPlanGroup,
  closeFloatPlanForCleanup,
  cleanupTrackedData,
  createCleanupState,
  deletePdfFilesByPrefix,
  getJson,
  PDF_OUTPUT_DIR,
  postJson,
  postJsonAllowFailure,
  trackId,
  trackValue
};
