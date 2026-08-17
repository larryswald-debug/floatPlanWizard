const { test, expect } = require("@playwright/test");
const fs = require("node:fs");

const dashboardSource = fs.readFileSync("assets/js/app/dashboard.js", "utf8");

function routePayload(overrides = {}) {
  return {
    ID: 9001,
    NAME: "Archive Contract Route",
    SHORT_CODE: "USER_ROUTE_9001_ARCHIVE_TEST",
    DESCRIPTION: "Focused browser contract",
    ROUTE_INSTANCE_ID: 7001,
    TOTALS: {
      TOTAL_NM: 12.5,
      ESTIMATED_HOURS: 2.5,
      WAYPOINT_COUNT: 2,
      ESTIMATED_FUEL_GALLONS: 4.2
    },
    ROUTE_ENDPOINTS: {
      START_LABEL: "Test Start",
      END_LABEL: "Test End"
    },
    HAS_CURRENT_GROUP: false,
    CURRENT_GROUP: {},
    HAS_PREMIUM_SEND_HISTORY: true,
    HAS_ACTIVE_FLOAT_PLAN: false,
    CAN_DELETE: false,
    CAN_ARCHIVE: true,
    DELETE_BLOCK_CODE: "PREMIUM_SEND_HISTORY_DELETE_BLOCKED",
    DELETE_BLOCK_MESSAGE: "Archive this route to preserve its completed Premium Send history.",
    ...overrides
  };
}

async function bootDashboard(page, routes, options = {}) {
  await page.setContent(`
    <!doctype html>
    <html>
      <body class="dashboard-body" data-fpw-page="dashboard">
        <section id="expeditionTimelinePanel">
          <header><button id="openRouteBuilderBtn" type="button">Create Route</button></header>
          <div class="card-body">
            <div id="expeditionTimelineSummary"></div>
            <div id="expeditionTimelineLoading"></div>
            <div id="expeditionTimelineUnauthorized" class="d-none"></div>
            <div id="expeditionTimelineError" class="d-none">
              <span id="expeditionTimelineErrorText"></span>
              <button id="expeditionTimelineRetry" type="button">Retry</button>
            </div>
            <div id="expeditionTimelineBody" class="d-none">
              <div id="expeditionRouteList"></div>
              <div id="expeditionRouteEmpty" class="d-none">No routes</div>
              <div id="expeditionTimelineAccordion"></div>
            </div>
          </div>
        </section>
      </body>
    </html>
  `);

  await page.evaluate(({ initialRoutes, failArchive }) => {
    window.FPW_BASE = "/fpw";
    window.__routeArchiveTest = {
      routes: initialRoutes,
      calls: [],
      confirmations: [],
      alerts: [],
      failArchive: !!failArchive
    };
    window.FPW = {
      DashboardState: { isBasicMember: false },
      DashboardModules: {},
      DashboardUtils: {
        clearDashboardAlert() {},
        ensureAuthResponse() { return true; },
        ensureConfirmModal() {},
        ensureAlertModal() {},
        showConfirmModal(message) {
          window.__routeArchiveTest.confirmations.push(String(message));
          return Promise.resolve(true);
        },
        showAlertModal(message) {
          window.__routeArchiveTest.alerts.push(String(message));
        }
      }
    };
    window.Api = {
      getCurrentMemberAccess() {
        return Promise.resolve({
          SUCCESS: true,
          USER: { USERID: 9001, NAME: "Archive Test", EMAIL: "archive@example.test" },
          ACCESS: { hasPremium: true }
        });
      },
      getCurrentUser() {
        return this.getCurrentMemberAccess();
      },
      logout() {
        return Promise.resolve({ SUCCESS: true });
      }
    };
    window.fetch = function (url, options) {
      var requestUrl = String(url);
      var state = window.__routeArchiveTest;
      state.calls.push({
        url: requestUrl,
        method: options && options.method ? String(options.method).toUpperCase() : "GET",
        body: options && options.body ? String(options.body) : ""
      });
      var payload = { SUCCESS: true };

      if (requestUrl.indexOf("action=listUserRoutes") >= 0) {
        payload = {
          SUCCESS: true,
          AUTH: true,
          ROUTES: state.routes,
          CURRENT_GROUP: { HAS_CURRENT_GROUP: false },
          ACTIVE_TRIP: { SUCCESS: false }
        };
      } else if (requestUrl.indexOf("action=archiveRoute") >= 0) {
        if (state.failArchive) {
          payload = {
            SUCCESS: false,
            MESSAGE: "Route archive failed.",
            ERROR: { MESSAGE: "Archive remains unavailable for this route." }
          };
        } else {
          state.routes = [];
          payload = { SUCCESS: true, MESSAGE: "Route archived" };
        }
      } else if (requestUrl.indexOf("action=deleteRoute") >= 0) {
        state.routes = [];
        payload = { SUCCESS: true, MESSAGE: "Route deleted" };
      }

      return Promise.resolve(new Response(JSON.stringify(payload), {
        status: 200,
        headers: { "Content-Type": "application/json" }
      }));
    };
  }, { initialRoutes: routes, failArchive: options.failArchive });

  await page.addScriptTag({ content: dashboardSource });
  await page.evaluate(() => {
    document.dispatchEvent(new Event("DOMContentLoaded"));
  });
}

test("protected inactive routes archive while ordinary inactive routes retain delete", async ({ page }) => {
  const pageErrors = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));

  await bootDashboard(page, [routePayload()]);

  const detailPane = page.locator(".fpw-route-detail-pane");
  await expect(detailPane.getByRole("button", { name: "Archive" })).toBeVisible();
  await expect(detailPane.getByRole("button", { name: "Delete" })).toHaveCount(0);
  await detailPane.getByRole("button", { name: "Archive" }).click();
  await expect(page.locator("#expeditionRouteEmpty")).not.toHaveClass(/d-none/);

  let state = await page.evaluate(() => window.__routeArchiveTest);
  const archiveCall = state.calls.find((call) => call.url.includes("action=archiveRoute"));
  expect(archiveCall).toMatchObject({ method: "POST" });
  expect(JSON.parse(archiveCall.body)).toEqual({ routeCode: "USER_ROUTE_9001_ARCHIVE_TEST" });
  expect(state.confirmations).toContain(
    "Archive this route? It will be removed from your Routes list while its completed Premium Send history is retained."
  );

  await page.evaluate((ordinaryRoute) => {
    window.__routeArchiveTest.routes = [ordinaryRoute];
    return window.FPW.DashboardModules.expeditionTimeline.load();
  }, routePayload({
    NAME: "Ordinary Route",
    SHORT_CODE: "USER_ROUTE_9001_DELETE_TEST",
    HAS_PREMIUM_SEND_HISTORY: false,
    CAN_DELETE: true,
    CAN_ARCHIVE: false,
    DELETE_BLOCK_CODE: "",
    DELETE_BLOCK_MESSAGE: ""
  }));

  await expect(detailPane.getByRole("button", { name: "Delete" })).toBeVisible();
  await expect(detailPane.getByRole("button", { name: "Archive" })).toHaveCount(0);
  await detailPane.getByRole("button", { name: "Delete" }).click();
  await expect(page.locator("#expeditionRouteEmpty")).not.toHaveClass(/d-none/);

  state = await page.evaluate(() => window.__routeArchiveTest);
  expect(state.calls.some((call) => call.url.includes("action=deleteRoute"))).toBe(true);
  expect(state.confirmations).toContain(
    "Delete this route and any attached non-Premium float-plan data? This cannot be undone."
  );
  expect(state.alerts).toEqual([]);
  expect(pageErrors).toEqual([]);
});

test("archive failures preserve the rendered route workspace and use an alert", async ({ page }) => {
  const pageErrors = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));

  await bootDashboard(page, [routePayload()], { failArchive: true });

  const detailPane = page.locator(".fpw-route-detail-pane");
  await expect(detailPane.getByRole("button", { name: "Archive" })).toBeVisible();
  await detailPane.getByRole("button", { name: "Archive" }).click();

  await expect.poll(async () => page.evaluate(() => window.__routeArchiveTest.alerts.length)).toBe(1);
  await expect(detailPane).toBeVisible();
  await expect(page.locator("#expeditionTimelineBody")).not.toHaveClass(/d-none/);
  await expect(page.locator("#expeditionTimelineError")).toHaveClass(/d-none/);

  const state = await page.evaluate(() => window.__routeArchiveTest);
  expect(state.alerts).toEqual(["Archive remains unavailable for this route."]);
  expect(pageErrors).toEqual([]);
});
