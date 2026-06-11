const fs = require("fs");
const path = require("path");
const { test, expect } = require("@playwright/test");

const PLAN_ID = 4321;
const ROUTE_INSTANCE_ID = 8765;
const HARNESS_PATH = "/fpw/test-harness/floatplan-step5-review.html";
const DASHBOARD_TEMPLATE = fs.readFileSync(
  path.join(__dirname, "../../app/dashboard.cfm"),
  "utf8"
);
const FLOATPLAN_WIZARD_MODAL = extractBetween(
  DASHBOARD_TEMPLATE,
  '<div class="modal fade" id="floatPlanWizardModal"',
  '<div class="modal fade" id="floatPlanCloneModal"'
).replace('aria-hidden="true"', 'aria-hidden="false"');

function extractBetween(html, startMarker, endMarker) {
  const startIndex = html.indexOf(startMarker);
  const endIndex = html.indexOf(endMarker);

  if (startIndex === -1) {
    throw new Error(`Unable to locate start marker: ${startMarker}`);
  }
  if (endIndex === -1 || endIndex <= startIndex) {
    throw new Error(`Unable to locate end marker after ${startMarker}`);
  }

  return html.slice(startIndex, endIndex).trim();
}

function buildHarnessHtml() {
  return [
    "<!DOCTYPE html>",
    "<html lang=\"en\">",
    "<head>",
    "  <meta charset=\"UTF-8\">",
    "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
    "  <title>Float Plan Step 5 Review Harness</title>",
    "  <link rel=\"stylesheet\" href=\"http://localhost:8500/fpw/assets/css/dashboard-console.css\">",
    "  <script>window.FPW_BASE = \"/fpw\";</script>",
    "  <script src=\"https://unpkg.com/vue@3/dist/vue.global.prod.js\"></script>",
    "  <script src=\"http://localhost:8500/fpw/assets/js/app/validate.js?v=20260227c\"></script>",
    "  <script src=\"http://localhost:8500/fpw/assets/js/app/floatplanWizard.js?v=20260327a\"></script>",
    "</head>",
    "<body class=\"dashboard-body\">",
    FLOATPLAN_WIZARD_MODAL,
    "</body>",
    "</html>"
  ].join("\n");
}

function buildWaypointOption(id, name) {
  return {
    WAYPOINTID: id,
    WAYPOINTNAME: name,
    LATITUDE: "",
    LONGITUDE: "",
    NOTES: "",
    IS_ROUTE_DEFAULT: true
  };
}

function buildWaypointSelection(id, sortOrder) {
  return {
    WAYPOINTID: id,
    SORT_ORDER: sortOrder,
    REASON_FOR_STOP: "",
    DEPART_MODE: "",
    ARRIVAL_TIME: "",
    DEPARTURE_TIME: ""
  };
}

function buildFutureTimestamp(daysFromNow, hour) {
  const value = new Date();
  value.setSeconds(0, 0);
  value.setDate(value.getDate() + daysFromNow);
  value.setHours(hour, 0, 0, 0);
  const yyyy = value.getFullYear();
  const mm = String(value.getMonth() + 1).padStart(2, "0");
  const dd = String(value.getDate()).padStart(2, "0");
  const hh = String(value.getHours()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd} ${hh}:00:00`;
}

function buildBootstrapData(routeWaypoints) {
  const waypointOptions = routeWaypoints.map((waypoint) => buildWaypointOption(waypoint.id, waypoint.name));
  const waypointSelections = routeWaypoints.map((waypoint, index) => buildWaypointSelection(waypoint.id, index + 1));
  const departureTime = buildFutureTimestamp(1, 12);
  const returnTime = buildFutureTimestamp(2, 12);

  return {
    SUCCESS: true,
    AUTH: true,
    FLOATPLAN: {
      FLOATPLANID: PLAN_ID,
      NAME: "Activated Route Draft",
      VESSELID: 55,
      OPERATORID: 66,
      OPERATOR_HAS_PFD: true,
      EMAIL: "captain@example.com",
      RESCUE_AUTHORITY: "__USER_TO_SET__",
      RESCUE_AUTHORITY_PHONE: "__USER_TO_SET__",
      RESCUE_CENTERID: -1,
      DEPARTING_FROM: "Home Port",
      DEPARTURE_TIME: departureTime,
      DEPARTURE_TIMEZONE: "UTC",
      RETURNING_TO: "Home Port",
      RETURN_TIME: returnTime,
      RETURN_TIMEZONE: "UTC",
      FOOD_DAYS_PER_PERSON: "2",
      WATER_DAYS_PER_PERSON: "2",
      NOTES: "",
      ROUTE_INSTANCE_ID: ROUTE_INSTANCE_ID,
      ROUTE_DAY_NUMBER: 1,
      STATUS: "Draft"
    },
    PLAN_PASSENGERS: [],
    PLAN_CONTACTS: [
      {
        CONTACTID: 1,
        SORT_ORDER: 1
      }
    ],
    PLAN_WAYPOINTS: [],
    VESSELS: [
      {
        VESSELID: 55,
        VESSELNAME: "Test Vessel"
      }
    ],
    OPERATORS: [
      {
        OPERATORID: 66,
        OPERATORNAME: "Captain Test"
      }
    ],
    PASSENGERS: [],
    CONTACTS: [
      {
        CONTACTID: 1,
        CONTACTNAME: "Shore Contact",
        EMAIL: "shore@example.com",
        PHONE: "555-0100"
      }
    ],
    WAYPOINTS: waypointOptions,
    RESCUE_CENTERS: [
      {
        recId: -1,
        rcName: "__USER_TO_SET__",
        rcPhone: "__USER_TO_SET__",
        rcDistrict: "",
        rcArea: "",
        rcLocation: ""
      }
    ],
    HOME_PORT: {
      ISHOMEPORT: 1,
      STATE: "FL"
    },
    ROUTE_DEFAULTS: {
      IS_FROM_ROUTE: true,
      ROUTE_INSTANCE_ID: ROUTE_INSTANCE_ID,
      ROUTE_DAY_NUMBER: 1,
      ROUTE_TYPE: "custom",
      ROUTE_CODE: "route-test",
      ROUTE_START_DATE: "2026-04-14",
      LEG_COUNT: routeWaypoints.length,
      OPERATOR_ID: 66,
      OPERATOR_SOURCE: "existing_plan",
      DATES_SOURCE: "route_start_date",
      DEPARTING_FROM_DEFAULT: "Home Port",
      RETURNING_TO_DEFAULT: "Home Port",
      DEPARTURE_TIME_DEFAULT: departureTime,
      RETURN_TIME_DEFAULT: returnTime,
      WAYPOINT_SOURCE: routeWaypoints.length ? "custom_route_ordered" : "none",
      WAYPOINT_OPTIONS: waypointOptions,
      WAYPOINT_SELECTIONS: waypointSelections
    }
  };
}

async function openWaypointReview(page, bootstrapData) {
  await page.route(`**${HARNESS_PATH}`, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "text/html",
      body: buildHarnessHtml()
    });
  });

  await page.goto(HARNESS_PATH, { waitUntil: "domcontentloaded" });
  await page.waitForFunction(() => !!(window.Vue && window.FloatPlanWizard));

  const opened = await page.evaluate((args) => {
    function clone(value) {
      return JSON.parse(JSON.stringify(value));
    }

    window.__fpwStep5Test = {
      saveCalls: [],
      sendCalls: []
    };

    window.Api = window.Api || {};
    window.Api.getFloatPlanBootstrap = function () {
      return Promise.resolve(clone(args.data));
    };
    window.Api.saveFloatPlan = function (payload) {
      const savedPayload = clone(payload);
      window.__fpwStep5Test.saveCalls.push(savedPayload);
      return Promise.resolve({
        SUCCESS: true,
        AUTH: true,
        FLOATPLAN: Object.assign({}, savedPayload.FLOATPLAN, {
          FLOATPLANID: args.planId,
          STATUS: "Draft"
        }),
        PLAN_PASSENGERS: clone(savedPayload.PASSENGERS || []),
        PLAN_CONTACTS: clone(savedPayload.CONTACTS || []),
        PLAN_WAYPOINTS: clone(savedPayload.WAYPOINTS || [])
      });
    };
    window.Api.sendFloatPlan = function (planId) {
      window.__fpwStep5Test.sendCalls.push(planId);
      return Promise.resolve({
        SUCCESS: true,
        AUTH: true,
        MESSAGE: "Float plan sent to selected contacts."
      });
    };
    window.Api.createFloatPlanPdf = function () {
      return Promise.resolve("step5-review-test.pdf");
    };

    window.__fpwStep5Test.wizard = window.FloatPlanWizard.init({
      mountEl: document.getElementById("wizardApp"),
      planId: args.planId,
      startStep: 5,
      contactStep: 4
    });
    return !!window.__fpwStep5Test.wizard;
  }, { data: bootstrapData, planId: PLAN_ID });

  expect(opened).toBe(true);

  const container = page.locator("#floatPlanWizardModal");
  await expect(container.getByRole("heading", { name: "Step 5 – Waypoints" })).toBeVisible();
  return container;
}

test("Step 5 is review-only and preserves route waypoint order", async ({ page }) => {
  const routeWaypoints = [
    { id: 101, name: "Harbor Entrance" },
    { id: 102, name: "Mid-Channel Turn" },
    { id: 103, name: "Anchorage" }
  ];
  const modal = await openWaypointReview(page, buildBootstrapData(routeWaypoints));

  await expect(modal.getByText("Available Waypoints")).toHaveCount(0);
  await expect(modal.getByLabel("Search waypoints")).toHaveCount(0);
  await expect(modal.locator(".fpw-manifest--waypoints .fpw-manifest__available")).toHaveCount(0);

  const waypointRows = modal.locator(".fpw-manifest--waypoints .fpw-manifest__selectedlist li");
  await expect(waypointRows).toHaveCount(3);
  await expect(waypointRows.nth(0)).toContainText(/1\s*Harbor Entrance/);
  await expect(waypointRows.nth(1)).toContainText(/2\s*Mid-Channel Turn/);
  await expect(waypointRows.nth(2)).toContainText(/3\s*Anchorage/);

  const widthCheck = await modal.locator(".fpw-manifest--waypoints").evaluate((manifest) => {
    const summary = manifest.querySelector(".fpw-manifest__summary");
    const manifestRect = manifest.getBoundingClientRect();
    const summaryRect = summary.getBoundingClientRect();

    return {
      manifestWidth: manifestRect.width,
      summaryWidth: summaryRect.width
    };
  });
  expect(widthCheck.summaryWidth / widthCheck.manifestWidth).toBeGreaterThan(0.95);

  await page.evaluate(() => {
    window.__fpwStep5Test.wizard.nextStep();
  });
  await expect(modal.getByRole("heading", { name: "Step 6 – Review" })).toBeVisible();

  await page.evaluate(() => {
    window.__fpwStep5Test.wizard.submitPlan();
  });
  await expect.poll(async () => {
    return page.evaluate(() => window.__fpwStep5Test.saveCalls.length);
  }).toBe(1);

  const firstSave = await page.evaluate(() => window.__fpwStep5Test.saveCalls[0]);
  expect(firstSave.WAYPOINTS).toEqual([
    buildWaypointSelection(101, 1),
    buildWaypointSelection(102, 2),
    buildWaypointSelection(103, 3)
  ]);

  await page.evaluate(() => {
    window.__fpwStep5Test.wizard.submitPlanAndSend();
  });
  await expect.poll(async () => {
    return page.evaluate(() => ({
      saveCalls: window.__fpwStep5Test.saveCalls.length,
      sendCalls: window.__fpwStep5Test.sendCalls.length
    }));
  }).toEqual({
    saveCalls: 2,
    sendCalls: 1
  });
});

test("Step 5 remains stable for a single route waypoint", async ({ page }) => {
  const modal = await openWaypointReview(
    page,
    buildBootstrapData([{ id: 201, name: "Channel Marker 7" }])
  );

  await expect(modal.getByText("Available Waypoints")).toHaveCount(0);
  await expect(modal.getByLabel("Search waypoints")).toHaveCount(0);

  const waypointRows = modal.locator(".fpw-manifest--waypoints .fpw-manifest__selectedlist li");
  await expect(waypointRows).toHaveCount(1);
  await expect(waypointRows.first()).toContainText(/1\s*Channel Marker 7/);
});

test("Step 5 remains stable for a route with zero waypoints", async ({ page }) => {
  const modal = await openWaypointReview(page, buildBootstrapData([]));

  await expect(modal.getByText("Available Waypoints")).toHaveCount(0);
  await expect(modal.getByLabel("Search waypoints")).toHaveCount(0);
  await expect(modal.getByText("In Route (0)")).toBeVisible();
  await expect(modal.getByText("No waypoints selected.")).toBeVisible();
});
