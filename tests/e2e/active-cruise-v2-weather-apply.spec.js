const fs = require("fs");
const path = require("path");
const { test, expect } = require("@playwright/test");

const HARNESS_PATH = "/fpw/test-harness/active-cruise-v2-weather-apply.html";
const ACTIVE_CRUISE_V2_TEMPLATE = fs.readFileSync(
  path.join(__dirname, "../../app/active-cruise.cfm"),
  "utf8"
);
const ROUTE_WEATHER_ASSIST_SCRIPT = fs.readFileSync(
  path.join(__dirname, "../../assets/js/app/shared/route-weather-assist.js"),
  "utf8"
);
const ACTIVE_CRUISE_V2_WEATHER_SCRIPT = extractWeatherScript(ACTIVE_CRUISE_V2_TEMPLATE);

function extractWeatherScript(template) {
  const match = template.match(
    /\(function\(\) \{\s*const root = document\.getElementById\('fpwV2WeatherLookup'\);[\s\S]*?\n\}\)\(\);\s*\n\s*\(function\(\) \{\s*const form = document\.getElementById\('fpwV2CaptainQuickNoteForm'\);/
  );

  if (!match || !match[0]) {
    throw new Error("Unable to extract the Active Cruise V2 weather inline script.");
  }

  return match[0]
    .replace(/\s*\n\s*\(function\(\) \{\s*const form = document\.getElementById\('fpwV2CaptainQuickNoteForm'\);[\s\S]*$/, "")
    .trim();
}

function buildWeatherModel() {
  return {
    lookup: {
      available: true,
      endpoint: "/api/v1/voyage.cfc?method=handle&action=getactivecruiseweather&returnFormat=json",
      method: "POST",
      payload: {
        floatPlanId: 2468,
        point: ""
      },
      allowedPoints: ["start", "end"]
    },
    apply: {
      available: 38,
      method: "POST",
      routeCode: "GEN_ROUTE_12",
      endpoints: {
        editContext: "/api/v1/routeBuilder.cfc?method=handle&action=routegen_geteditcontext&returnFormat=json",
        generatedPreview: "/api/v1/routeBuilder.cfc?method=handle&action=routegen_preview&returnFormat=json",
        myRoutePreview: "/api/v1/routeBuilder.cfc?method=handle&action=previewuserroute&returnFormat=json",
        update: "/api/v1/routeBuilder.cfc?method=handle&action=routegen_update&returnFormat=json"
      },
      payload: {
        routeCode: "GEN_ROUTE_12"
      }
    },
    source: "voyage.getActiveCruiseWeatherCanonical"
  };
}

function buildWeatherLookupPayload() {
  return {
    SUCCESS: true,
    DATA: {
      available: 6,
      point: "start",
      point_label: "Chicago",
      weather: {
        FORECAST: [
          {
            windDirection: "NE",
            windSpeed: "20 mph",
            gustMph: 25
          }
        ],
        ALERTS: [
          {
            headline: "Small Craft Advisory",
            severity: "Severe"
          }
        ],
        MARINE: {
          wave_height_ft: 3
        },
        surface: {
          visibility_mi: 10
        }
      }
    }
  };
}

function buildEditContextPayload() {
  return {
    SUCCESS: true,
    DATA: {
      route: {
        ROUTE_NAME: "Generated Route 12"
      },
      inputs: {
        route_type: "generated",
        route_code: "GEN_ROUTE_12",
        route_id: 912,
        route_name: "Generated Route 12",
        weather_factor_pct: 0,
        reserve_pct: 33,
        speed_kn: 24,
        selected_vessel_id: 429,
        template_code: "GL_REUSE_V2"
      }
    }
  };
}

function buildPreviewPayload() {
  return {
    SUCCESS: true,
    DATA: {
      legs: [
        { is_offshore: 1 },
        { is_offshore: 0 }
      ]
    }
  };
}

function buildHarnessHtml(options = {}) {
  const refreshed = options.refreshed === true;
  const weatherJson = JSON.stringify(buildWeatherModel()).replace(/<\//g, "<\\/");
  const routeRemaining = refreshed ? "99.9 nm" : "123.4 nm";
  const routeProgress = refreshed ? "46%" : "0%";

  return [
    "<!doctype html>",
    '<html lang="en">',
    "<head>",
    '  <meta charset="utf-8">',
    "  <title>Active Cruise V2 Weather Apply Harness</title>",
    "  <style>[hidden]{display:none !important;}</style>",
    "</head>",
    "<body>",
    `  <script id="fpwActiveCruiseV2WeatherPayload" type="application/json">${weatherJson}</script>`,
    '  <section id="acV2WeatherPanel">',
    '    <div id="fpwV2WeatherLookup" data-fpw-base="/fpw">',
    '      <form id="fpwV2WeatherForm">',
    '        <label><input type="radio" name="fpwV2WeatherPoint" value="start" checked>Chicago</label>',
    '        <label><input type="radio" name="fpwV2WeatherPoint" value="end">Joliet</label>',
    '        <button type="submit">Check Conditions</button>',
    '        <span data-weather-chip="alerts">No alerts</span>',
    '        <span data-weather-chip="factor">0% factor</span>',
    "      </form>",
    "    </div>",
    '    <div id="fpwV2WeatherFeedback"></div>',
    '    <div data-weather-field="point">Not checked</div>',
    '    <div data-weather-field="summary">Not checked</div>',
    '    <div data-weather-field="temperature">Not checked</div>',
    '    <div id="fpwV2WeatherResult" class="is-empty">',
    '      <strong data-weather-field="wind">Not checked</strong>',
    '      <strong data-weather-field="gusts">Not checked</strong>',
    '      <strong data-weather-field="waves">Not checked</strong>',
    '      <strong data-weather-field="visibility">Not checked</strong>',
    '      <strong data-weather-field="weatherFactor">0%</strong>',
    '      <strong data-weather-field="alerts">Not checked</strong>',
    "    </div>",
    '    <p data-weather-field="weatherFactorNote">Check conditions to calculate a route weather factor.</p>',
    '    <button type="button" id="fpwV2WeatherApplyBtn" disabled aria-disabled="true">Apply Weather to Route</button>',
    "  </section>",
    '  <section id="acV2RouteProgressPanel">',
    `    <strong data-fpw-field="routeProgress.remainingNm">${routeRemaining}</strong>`,
    `    <span data-fpw-field="routeProgress.progressBar" style="width:${routeProgress};"></span>`,
    "  </section>",
    `  <script>${ROUTE_WEATHER_ASSIST_SCRIPT}</script>`,
    `  <script>${ACTIVE_CRUISE_V2_WEATHER_SCRIPT}</script>`,
    "</body>",
    "</html>"
  ].join("\n");
}

async function openHarness(page) {
  const requestOrder = [];
  const requests = {
    weather: [],
    editContext: [],
    generatedPreview: [],
    update: []
  };
  let documentLoads = 0;
  let viewRefreshes = 0;

  await page.route(`**${HARNESS_PATH}`, async (route) => {
    const isNavigationDocument = route.request().resourceType() === "document";
    if (isNavigationDocument) {
      documentLoads += 1;
    } else {
      viewRefreshes += 1;
    }
    await route.fulfill({
      status: 200,
      contentType: "text/html",
      body: buildHarnessHtml({ refreshed: !isNavigationDocument })
    });
  });

  await page.route("**/fpw/api/v1/voyage.cfc?method=handle&action=getactivecruiseweather&returnFormat=json", async (route) => {
    requests.weather.push(JSON.parse(route.request().postData() || "{}"));
    requestOrder.push("getactivecruiseweather");
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(buildWeatherLookupPayload())
    });
  });

  await page.route("**/fpw/api/v1/routeBuilder.cfc?method=handle&action=routegen_geteditcontext&returnFormat=json", async (route) => {
    requests.editContext.push(JSON.parse(route.request().postData() || "{}"));
    requestOrder.push("routegen_geteditcontext");
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(buildEditContextPayload())
    });
  });

  await page.route("**/fpw/api/v1/routeBuilder.cfc?method=handle&action=routegen_preview&returnFormat=json", async (route) => {
    requests.generatedPreview.push(JSON.parse(route.request().postData() || "{}"));
    requestOrder.push("routegen_preview");
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(buildPreviewPayload())
    });
  });

  await page.route("**/fpw/api/v1/routeBuilder.cfc?method=handle&action=routegen_update&returnFormat=json", async (route) => {
    requests.update.push(JSON.parse(route.request().postData() || "{}"));
    requestOrder.push("routegen_update");
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ SUCCESS: true, DATA: { route_code: "GEN_ROUTE_12" } })
    });
  });

  await page.goto(HARNESS_PATH, { waitUntil: "domcontentloaded" });

  return {
    requestOrder,
    requests,
    getDocumentLoads: () => documentLoads,
    getViewRefreshes: () => viewRefreshes
  };
}

test("Active Cruise V2 weather lookup computes and applies route weather factor", async ({ page }) => {
  const harness = await openHarness(page);

  await expect(page.locator("#fpwV2WeatherApplyBtn")).toBeDisabled();
  await page.getByRole("button", { name: "Check Conditions" }).click();

  await expect(page.locator('[data-weather-field="wind"]')).toHaveText("NE 20 mph");
  await expect(page.locator('[data-weather-field="gusts"]')).toHaveText("25");
  await expect(page.locator('[data-weather-field="waves"]')).toHaveText("3");
  await expect(page.locator('[data-weather-field="visibility"]')).toHaveText("10");
  await expect(page.locator('[data-weather-field="weatherFactor"]')).toHaveText("46%");
  await expect(page.locator('[data-weather-chip="factor"]')).toHaveText("46% factor");
  await expect(page.locator('[data-weather-field="weatherFactorNote"]')).toHaveText("Suggested 46% weather factor. Apply to update the route.");
  await expect(page.locator("#fpwV2WeatherApplyBtn")).toBeEnabled();

  expect(harness.requests.weather).toEqual([
    {
      floatPlanId: 2468,
      point: "start"
    }
  ]);
  expect(harness.requestOrder).toEqual([
    "getactivecruiseweather",
    "routegen_geteditcontext",
    "routegen_preview"
  ]);

  await page.getByRole("button", { name: "Apply Weather to Route" }).click();
  await expect.poll(() => harness.requests.update.length).toBe(1);

  expect(harness.requests.update[0]).toEqual({
    route_type: "generated",
    route_code: "GEN_ROUTE_12",
    route_id: 912,
    route_name: "Generated Route 12",
    weather_factor_pct: 46,
    reserve_pct: 33,
    speed_kn: 24,
    selected_vessel_id: 429,
    template_code: "GL_REUSE_V2"
  });
  expect(harness.requestOrder).toEqual([
    "getactivecruiseweather",
    "routegen_geteditcontext",
    "routegen_preview",
    "routegen_geteditcontext",
    "routegen_preview",
    "routegen_update"
  ]);
  await expect(page.locator('[data-weather-field="weatherFactorNote"]')).toHaveText("Applied 46% weather factor to route.");
  await expect(page.locator('[data-fpw-field="routeProgress.remainingNm"]')).toHaveText("99.9 nm");
  await expect.poll(() => harness.getViewRefreshes()).toBe(1);
  expect(harness.getDocumentLoads()).toBe(1);
});
