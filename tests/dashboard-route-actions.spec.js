const { test, expect } = require("@playwright/test");
const fs = require("node:fs");

const dashboardSource = fs.readFileSync("assets/js/app/dashboard.js", "utf8");
const dashboardCss = fs.readFileSync("assets/css/dashboard-console.css", "utf8");
let bootstrapScript, bootstrapCss;
test.beforeAll(async ({ request }) => {
  const responses = await Promise.all([
    request.get("https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"),
    request.get("https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css")
  ]);
  for (const response of responses) expect(response.ok()).toBe(true);
  [bootstrapScript, bootstrapCss] = await Promise.all(responses.map(response => response.text()));
});

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

  await page.addStyleTag({ content: bootstrapCss + "\n" + dashboardCss });
  await page.addScriptTag({ content: bootstrapScript });
  await page.evaluate(({ initialRoutes, failArchive, activeTrip }) => {
    window.FPW_BASE = "/fpw";
    window.__routeActionsTest = {
      routes: initialRoutes,
      activeTrip: activeTrip || { SUCCESS: false },
      actions: [],
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
          window.__routeActionsTest.confirmations.push(String(message));
          return Promise.resolve(true);
        },
        showAlertModal(message) {
          window.__routeActionsTest.alerts.push(String(message));
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
      var state = window.__routeActionsTest;
      state.calls.push({
        url: requestUrl,
        method: options && options.method ? String(options.method).toUpperCase() : "GET",
        body: options && options.body ? String(options.body) : ""
      });
      var payload = { SUCCESS: true };

      if (requestUrl.indexOf("action=listUserRoutes") >= 0) {
        payload = state.listPayload || {
          SUCCESS: true,
          AUTH: true,
          ROUTES: state.routes,
          CURRENT_GROUP: { HAS_CURRENT_GROUP: false },
          ACTIVE_TRIP: state.activeTrip
        };
      } else if (requestUrl.indexOf("action=ownerEnsureStream") >= 0) {
        payload = { SUCCESS: true, DATA: { follow: { url: "/fpw/app/follow.cfm?fixture=route-actions" } } };
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
  }, { initialRoutes: routes, failArchive: options.failArchive, activeTrip: options.activeTrip });

  await page.addScriptTag({ content: dashboardSource });
  await page.evaluate(() => {
    document.dispatchEvent(new Event("DOMContentLoaded"));
    const record = (action, ...args) => window.__routeActionsTest.actions.push({ action, args });
    window.FPW.DashboardModules.routeBuilder = { openEditorForRoute: code => record("edit", code) };
    window.FPW.DashboardModules.floatplans = {
      openWizardForPlan: (id, step) => record("wizard", id, step),
      cancelFloatPlan: id => record("cancel", id)
    };
    window.open = (url, target, features) => {
      record("open", url, target, features);
      return { closed: false, close() {}, set location(value) { record("follow", value); } };
    };
  });
  await expect(page.locator(".fpw-routes-table-row")).toHaveCount(routes.length);
}

function groupedRoute(state, overrides = {}) {
  return routePayload({
    SHORT_CODE: "TEST_" + state,
    NAME: state + " route",
    HAS_CURRENT_GROUP: true,
    CURRENT_GROUP: { HAS_CURRENT_GROUP: true, FLOATPLAN_ID: 7001, FLOATPLAN_NAME: state + " float plan",
      CURRENT_STATE: state, STATUS: state === "ACTIVE" ? "SENT" : state, IS_DRAFT: state === "DRAFT", IS_ACTIVE: state === "ACTIVE", PREVIEW_READY: false },
    CAN_DELETE: state !== "ACTIVE", CAN_ARCHIVE: false,
    HAS_PREMIUM_SEND_HISTORY: false, HAS_ACTIVE_FLOAT_PLAN: state === "ACTIVE",
    ...overrides
  });
}
const activeTrip = { SUCCESS: true, FLOATPLAN_ID: 7001, ROUTE_CODE: "TEST_ACTIVE" };
const rowActions = page => page.locator(".fpw-routes-table-row .fpw-route-icon-action");

test("tooltips show and hide synchronously, portal outside clipping, and survive AJAX replacement", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await bootDashboard(page, [groupedRoute("ACTIVE")], { activeTrip });
  const button = rowActions(page).first();
  await button.scrollIntoViewIfNeeded();
  const immediate = await button.evaluate(button => {
    const tooltip = window.bootstrap.Tooltip.getInstance(button);
    const start = performance.now();
    const originalTimeout = window.setTimeout;
    let timers = 0;
    window.setTimeout = function (...args) { timers += 1; return originalTimeout.apply(window, args); };
    button.dispatchEvent(new MouseEvent("mouseenter", { bubbles: true, relatedTarget: document.body }));
    const tip = document.querySelector(".fpw-route-action-tooltip");
    const shown = !!tip && tip.classList.contains("show") && getComputedStyle(tip).opacity === "1";
    const info = { shown, delay: tooltip._config.delay, animation: tooltip._config.animation,
      text: tip?.textContent, parentIsBody: tip?.parentElement === document.body,
      transition: tip && getComputedStyle(tip).transitionDuration,
      transitionDelay: tip && getComputedStyle(tip).transitionDelay,
      animationName: tip && getComputedStyle(tip).animationName,
      elapsed: performance.now() - start };
    button.dispatchEvent(new MouseEvent("mouseleave", { bubbles: true, relatedTarget: document.body }));
    info.hiddenImmediately = !document.querySelector(".fpw-route-action-tooltip");
    window.setTimeout = originalTimeout;
    info.timers = timers;
    return info;
  });
  expect(immediate).toMatchObject({ shown: true, hiddenImmediately: true, delay: { show: 0, hide: 0 },
    animation: false, timers: 0, text: "View Active Cruise", parentIsBody: true, transition: "0s", transitionDelay: "0s", animationName: "none" });
  const keyboard = await button.evaluate(button => {
    button.focus();
    const shown = document.querySelector(".fpw-route-action-tooltip")?.textContent === "View Active Cruise";
    const outline = getComputedStyle(button).outlineStyle;
    button.blur();
    return { shown, hidden: !document.querySelector(".fpw-route-action-tooltip"), outline };
  });
  expect(keyboard).toEqual({ shown: true, hidden: true, outline: "solid" });
  await button.hover();
  await expect(page.locator(".fpw-route-action-tooltip")).toHaveAttribute("data-popper-placement", "top");
  const geometry = await page.locator(".fpw-route-action-tooltip").evaluate(tip => {
    const r = tip.getBoundingClientRect();
    return { left: r.left, right: r.right, top: r.top, bottom: r.bottom, width: innerWidth, height: innerHeight };
  });
  expect(geometry.left).toBeGreaterThanOrEqual(0);
  expect(geometry.right).toBeLessThanOrEqual(geometry.width);
  expect(geometry.top).toBeGreaterThanOrEqual(0);
  expect(geometry.bottom).toBeLessThanOrEqual(geometry.height);
  await page.evaluate(() => window.dispatchEvent(new PageTransitionEvent("pagehide", { persisted: true })));
  await expect(page.locator(".fpw-route-action-tooltip")).toHaveCount(0);
  await expect(button).not.toHaveAttribute("aria-describedby");
  await page.evaluate(() => window.dispatchEvent(new PageTransitionEvent("pageshow", { persisted: true })));
  await button.focus();
  await expect(page.locator(".fpw-route-action-tooltip")).toHaveText("View Active Cruise");
  await page.evaluate(() => {
    window.__oldRouteButton = document.querySelector(".fpw-route-icon-action");
    return window.FPW.DashboardModules.expeditionTimeline.load();
  });
  expect(await page.evaluate(() => window.bootstrap.Tooltip.getInstance(window.__oldRouteButton))).toBeNull();
  await expect(page.locator(".fpw-route-action-tooltip")).toHaveCount(0);
  await rowActions(page).first().focus();
  await expect(page.locator(".fpw-route-action-tooltip")).toHaveText("View Active Cruise");
  await page.evaluate(() => {
    document.activeElement.blur();
    window.__routeActionsTest.routes = [];
    return window.FPW.DashboardModules.expeditionTimeline.load();
  });
  await expect(page.locator(".fpw-route-action-tooltip")).toHaveCount(0);
});


test("loading, errors, and access changes remove visible tooltips", async ({ page }) => {
  await bootDashboard(page, [groupedRoute("ACTIVE")], { activeTrip });
  for (const payload of [
    { SUCCESS: false, AUTH: false },
    { SUCCESS: false, MESSAGE: "Fixture route load failed." },
    { SUCCESS: false, ERROR: "BASIC_SAVED_ROUTE_RESTRICTED" }
  ]) {
    await rowActions(page).first().focus();
    await expect(page.locator(".fpw-route-action-tooltip")).toHaveText("View Active Cruise");
    const removedDuringLoad = await page.evaluate(payload => {
      window.__routeActionsTest.listPayload = payload;
      window.__routeLoad = window.FPW.DashboardModules.expeditionTimeline.load();
      return !document.querySelector(".fpw-route-action-tooltip");
    }, payload);
    expect(removedDuringLoad).toBe(true);
    await page.evaluate(() => window.__routeLoad);
    await expect(page.locator(".fpw-route-action-tooltip")).toHaveCount(0);
    await page.evaluate(() => {
      window.__routeActionsTest.listPayload = null;
      return window.FPW.DashboardModules.expeditionTimeline.load();
    });
    await expect(rowActions(page)).toHaveCount(4);
  }
});

for (const width of [1920, 1440, 1280, 1024, 768, 390]) {
  test("compact icons and state restrictions at " + width + "px", async ({ page }, testInfo) => {
    await page.setViewportSize({ width, height: 900 });
    const routes = [
      groupedRoute("ACTIVE"),
      groupedRoute("DRAFT"),
      groupedRoute("CLOSED", { CAN_DELETE: false, CAN_ARCHIVE: true }),
      routePayload({ SHORT_CODE: "TEST_SAVED", HAS_PREMIUM_SEND_HISTORY: false, CAN_DELETE: true, CAN_ARCHIVE: false }),
      routePayload({ SHORT_CODE: "TEST_BLOCKED", CAN_DELETE: false, CAN_ARCHIVE: false })
    ];
    await bootDashboard(page, routes, { activeTrip });
    const expected = [
      ["View Active Cruise", "View Follow Page", "Edit Route", "Cancel Float Plan"],
      ["Complete Float Plan", "Activate Route", "Edit Route", "Delete Route"],
      ["View and Send Float Plan", "Edit Float Plan", "Activate Route", "Edit Route", "Archive Route"],
      ["Activate Route", "Edit Route", "Delete Route"],
      ["Activate Route", "Edit Route"]
    ];
    const rows = page.locator(".fpw-routes-table-row");
    for (let i = 0; i < expected.length; i++) {
      const buttons = rows.nth(i).locator(".fpw-route-icon-action");
      expect(await buttons.evaluateAll(es => es.map(e => e.getAttribute("aria-label")))).toEqual(expected[i]);
      const boxes = await buttons.evaluateAll(es => es.map(e => {
        const r = e.getBoundingClientRect(), icon = getComputedStyle(e, "::before");
        return { x: r.x, y: r.y, width: r.width, height: r.height, iconWidth: icon.width, iconHeight: icon.height,
          mask: icon.maskImage, content: icon.content, text: e.textContent, type: e.type };
      }));
      for (let j = 0; j < boxes.length; j++) {
        expect(boxes[j]).toMatchObject({ width: 40, height: 40, iconWidth: "20px", iconHeight: "20px", content: '""', text: "", type: "button" });
        expect(boxes[j].mask).toContain("data:image/svg+xml");
        expect(boxes[j].y).toBe(boxes[0].y);
        if (j) expect(boxes[j].x - boxes[j - 1].x - 40).toBe(6);
      }
      expect((await rows.nth(i).boundingBox()).height).toBe(76);
    }
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    const tableLayout = await page.evaluate(() => {
      const table = document.querySelector(".fpw-routes-table");
      const pane = document.querySelector(".fpw-routes-table-pane");
      const header = document.querySelector(".fpw-routes-table-head");
      const rows = [...document.querySelectorAll(".fpw-routes-table-row")];
      return {
        paneOverflow: pane.scrollWidth > pane.clientWidth,
        tableOverflow: table.scrollWidth > table.clientWidth,
        aligned: rows.every(row => [...row.children].every((cell, i) =>
          Math.abs(cell.getBoundingClientRect().left - header.children[i].getBoundingClientRect().left) < 1)),
        actionsContained: rows.every(row => [...row.querySelectorAll(".fpw-route-icon-action")].every(button => {
          const b = button.getBoundingClientRect(), cell = row.querySelector(".fpw-route-cell--actions").getBoundingClientRect();
          return b.left >= cell.left && b.right <= cell.right;
        }))
      };
    });
    expect(tableLayout.tableOverflow).toBe(false);
    expect(tableLayout.aligned).toBe(true);
    expect(tableLayout.actionsContained).toBe(true);
    if (width >= 768) expect(tableLayout.paneOverflow).toBe(false);
    // The existing scrollable route table remains the mobile layout.
    const last = rows.first().getByRole("button", { name: "Cancel Float Plan", exact: true });
    await last.scrollIntoViewIfNeeded();
    const hit = await last.evaluate(e => { const r=e.getBoundingClientRect(); return document.elementFromPoint(r.x+r.width/2,r.y+r.height/2)===e; });
    expect(hit).toBe(true);
    await page.screenshot({ path: testInfo.outputPath("route-actions-" + width + ".png") });
  });
}

test("icons call the original actions and preserve confirmation messages", async ({ page }) => {
  await bootDashboard(page, [groupedRoute("ACTIVE")], { activeTrip });
  const row = page.locator(".fpw-routes-table-row");
  await row.getByRole("button", { name: "View Active Cruise", exact: true }).click();
  await row.getByRole("button", { name: "View Follow Page", exact: true }).click();
  await row.getByRole("button", { name: "Edit Route", exact: true }).click();
  await row.getByRole("button", { name: "Cancel Float Plan", exact: true }).click();
  let state = await page.evaluate(() => window.__routeActionsTest);
  expect(state.actions).toContainEqual({ action: "open", args: ["/fpw/app/active-cruise.cfm?floatPlanId=7001", "_blank", "noopener"] });
  expect(state.actions).toContainEqual({ action: "follow", args: ["/fpw/app/follow.cfm?fixture=route-actions"] });
  expect(state.actions).toContainEqual({ action: "edit", args: ["TEST_ACTIVE"] });
  expect(state.actions).toContainEqual({ action: "cancel", args: [7001] });
  expect(state.confirmations).toContain("Cancel this active route/float-plan group? This ends the active trip without requiring all legs to be complete first.");
  for (const archive of [true, false]) {
    await page.evaluate(({ archive, route }) => {
      window.__routeActionsTest.routes = [route];
      window.__routeActionsTest.activeTrip = { SUCCESS: false };
      return window.FPW.DashboardModules.expeditionTimeline.load();
    }, { archive, route: routePayload({ CAN_ARCHIVE: archive, CAN_DELETE: !archive }) });
    await row.getByRole("button", { name: archive ? "Archive Route" : "Delete Route", exact: true }).click();
    await expect(page.locator(".fpw-routes-table-row")).toHaveCount(0);
  }
  state = await page.evaluate(() => window.__routeActionsTest);
  const archiveCall = state.calls.find(c => c.url.includes("action=archiveRoute"));
  expect(archiveCall.method).toBe("POST");
  expect(JSON.parse(archiveCall.body)).toEqual({ routeCode: "USER_ROUTE_9001_ARCHIVE_TEST" });
  expect(state.calls.some(c => c.url.includes("action=deleteRoute") && c.url.includes("routeCode=USER_ROUTE_9001_ARCHIVE_TEST"))).toBe(true);
  expect(state.confirmations).toContain("Archive this route? It will be removed from your Routes list while its completed Premium Send history is retained.");
  expect(state.confirmations).toContain("Delete this route and any attached non-Premium float-plan data? This cannot be undone.");
  expect(state.alerts).toEqual([]);
});
