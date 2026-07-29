const {
  callRouteBuilderAction,
  callWaypointAction,
  gotoDashboard,
  loginRouteBuilderUser,
  logoutRouteBuilderUserViaApi
} = require("./routebuilderHarness");
const {
  cleanupCurrentRouteFloatPlanGroup,
  getJson
} = require("./fpwCleanup");

function createRouteBuilderCleanup(page) {
  const routeCodes = [];
  const myRouteIds = [];
  const waypointIds = [];

  function addUnique(target, value) {
    const normalized = String(value || "").trim();
    if (!normalized) return;
    if (!target.includes(normalized)) {
      target.push(normalized);
    }
  }

  async function ensureCleanupSession() {
    try {
      await gotoDashboard(page);
      return;
    } catch (error) {
      await loginRouteBuilderUser(page);
      await gotoDashboard(page);
    }
  }

  async function deleteRouteCode(routeCode) {
    if (!String(routeCode || "").trim()) return;
    const payload = await callRouteBuilderAction(page, "deleteroute", { routeCode });
    if (payload?.AUTH === false) {
      await ensureCleanupSession();
      await callRouteBuilderAction(page, "deleteroute", { routeCode });
    }
  }

  async function deleteMyRouteId(routeId) {
    const numericId = parseInt(routeId || 0, 10) || 0;
    if (numericId <= 0) return;
    const payload = await callRouteBuilderAction(page, "deleteUserRoute", { route_id: numericId });
    if (payload?.AUTH === false) {
      await ensureCleanupSession();
      await callRouteBuilderAction(page, "deleteUserRoute", { route_id: numericId });
    }
  }

  async function deleteWaypointId(waypointId) {
    const numericId = parseInt(waypointId || 0, 10) || 0;
    if (numericId <= 0) return;
    const payload = await callWaypointAction(page, "delete", { waypointId: numericId });
    if (payload?.AUTH === false) {
      await ensureCleanupSession();
      await callWaypointAction(page, "delete", { waypointId: numericId });
    }
  }

  async function listUserRouteCodes() {
    const payload = await getJson(page, "/fpw/api/v1/routeBuilder.cfc?method=handle&action=listUserRoutes");
    const routes = Array.isArray(payload?.ROUTES) ? payload.ROUTES : [];
    const routeCodes = [];
    for (const route of routes) {
      const routeCode = String(
        route?.SHORT_CODE
        || route?.short_code
        || route?.routeCode
        || route?.route_code
        || ""
      ).trim();
      if (routeCode && !routeCodes.includes(routeCode)) {
        routeCodes.push(routeCode);
      }
    }
    return routeCodes;
  }

  async function resetRouteBuilderUserState(options) {
    const opts = options || {};
    let remainingRouteCodes = [];
    await ensureCleanupSession();

    for (let attempt = 0; attempt < 5; attempt += 1) {
      await cleanupCurrentRouteFloatPlanGroup(page);
      remainingRouteCodes = await listUserRouteCodes();
      if (!remainingRouteCodes.length) {
        if (opts.logout === true) {
          await logoutRouteBuilderUserViaApi(page);
        }
        return;
      }
      for (const routeCode of remainingRouteCodes) {
        await deleteRouteCode(routeCode);
      }
      await page.waitForTimeout(250);
    }

    remainingRouteCodes = await listUserRouteCodes();
    if (remainingRouteCodes.length) {
      throw new Error(`Route Builder cleanup failed to reset user routes: ${JSON.stringify(remainingRouteCodes)}`);
    }

    if (opts.logout === true) {
      await logoutRouteBuilderUserViaApi(page);
    }
  }

  async function cleanupAll() {
    try {
      await ensureCleanupSession();
    } catch (error) {
      return;
    }

    while (routeCodes.length) {
      const routeCode = routeCodes.pop();
      try {
        await deleteRouteCode(routeCode);
      } catch (error) {
        const responseBody = typeof error?.responseBody === "string" ? error.responseBody : "";
        if (responseBody) {
          console.warn("Route cleanup failed for", routeCode, error?.message || error, responseBody);
        } else {
          console.warn("Route cleanup failed for", routeCode, error?.message || error);
        }
      }
    }

    while (myRouteIds.length) {
      const routeId = myRouteIds.pop();
      try {
        await deleteMyRouteId(routeId);
      } catch (error) {
        console.warn("My Route cleanup failed for", routeId, error?.message || error);
      }
    }

    while (waypointIds.length) {
      const waypointId = waypointIds.pop();
      try {
        await deleteWaypointId(waypointId);
      } catch (error) {
        console.warn("Waypoint cleanup failed for", waypointId, error?.message || error);
      }
    }
  }

  return {
    cleanupAll,
    deleteMyRouteId,
    deleteRouteCode,
    deleteWaypointId,
    resetRouteBuilderUserState,
    trackMyRouteId(routeId) {
      const numericId = parseInt(routeId || 0, 10) || 0;
      if (numericId > 0) addUnique(myRouteIds, String(numericId));
      return numericId;
    },
    trackRouteCode(routeCode) {
      const normalized = String(routeCode || "").trim();
      if (normalized) addUnique(routeCodes, normalized);
      return normalized;
    },
    trackWaypointId(waypointId) {
      const numericId = parseInt(waypointId || 0, 10) || 0;
      if (numericId > 0) addUnique(waypointIds, String(numericId));
      return numericId;
    }
  };
}

module.exports = {
  createRouteBuilderCleanup
};
