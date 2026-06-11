const { test, expect } = require("@playwright/test");

const ACTIVE_CRUISE_URL = "/fpw/app/active-cruise.cfm";
const ACTIVE_CRUISE_ROUTE = "**/fpw/app/active-cruise.cfm**";
const VOYAGE_ROUTE = "**/fpw/api/v1/voyage.cfc?**";
const ROUTE_BUILDER_ROUTE = "**/fpw/api/v1/routeBuilder.cfc?**";

async function openActiveCruiseV2(page) {
  await loginActiveCruiseUser(page);

  const counters = {
    documentLoads: 0,
    viewRefreshes: 0
  };

  await page.route(ACTIVE_CRUISE_ROUTE, async (route) => {
    if (route.request().resourceType() === "document") {
      counters.documentLoads += 1;
    } else {
      counters.viewRefreshes += 1;
    }
    await route.continue();
  });

  await page.goto(ACTIVE_CRUISE_URL, { waitUntil: "domcontentloaded" });
  await expect(page).toHaveTitle(/Active Cruise V2/);
  await expect(page.locator("#fpwV2WeatherLookup")).toBeVisible({ timeout: 30000 });
  return counters;
}

async function loginActiveCruiseUser(page) {
  const email = String(process.env.FPW_EMAIL || "").trim();
  const password = String(process.env.FPW_PASSWORD || "").trim();
  if (!email || !password) {
    throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
  }
  const response = await page.context().request.post("/fpw/api/v1/auth.cfc?method=handle&returnFormat=json", {
    data: {
      action: "login",
      email,
      password
    }
  });
  const payload = await response.json();
  expect(response.ok()).toBeTruthy();
  expect(payload.SUCCESS).toBe(true);
}

function parseJsonPost(request) {
  const raw = request.postData() || "{}";
  try {
    return JSON.parse(raw);
  } catch (error) {
    return {};
  }
}

function actionName(urlValue) {
  try {
    return String(new URL(urlValue).searchParams.get("action") || "").toLowerCase();
  } catch (error) {
    return "";
  }
}

function buildWeatherLookupPayload() {
  return {
    SUCCESS: true,
    DATA: {
      available: true,
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

function buildEditContextPayload(requestBody) {
  const routeCode = String(requestBody.route_code || requestBody.routeCode || "GEN_ROUTE_12");
  const isMyRoute = routeCode.toUpperCase().indexOf("MY_ROUTE") === 0;
  return {
    SUCCESS: true,
    DATA: {
      route: {
        ROUTE_NAME: isMyRoute ? "My Route" : "Generated Route"
      },
      inputs: {
        route_type: isMyRoute ? "my_route" : "generated",
        route_code: routeCode,
        route_id: Number(requestBody.route_id || requestBody.routeId || 912),
        route_name: isMyRoute ? "My Route" : "Generated Route",
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

test.describe("Active Cruise V2 weather apply", () => {
  test("uses the real V2 weather panel and refresh helper without document navigation", async ({ page }) => {
    const requests = {
      weather: [],
      editContext: [],
      preview: [],
      update: []
    };

    await page.route(VOYAGE_ROUTE, async (route) => {
      if (actionName(route.request().url()) !== "getactivecruiseweather") {
        await route.continue();
        return;
      }
      requests.weather.push(parseJsonPost(route.request()));
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify(buildWeatherLookupPayload())
      });
    });

    await page.route(ROUTE_BUILDER_ROUTE, async (route) => {
      const action = actionName(route.request().url());
      const body = parseJsonPost(route.request());
      if (action === "routegen_geteditcontext") {
        requests.editContext.push(body);
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify(buildEditContextPayload(body))
        });
        return;
      }
      if (action === "routegen_preview" || action === "previewuserroute") {
        requests.preview.push({ action, body });
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify(buildPreviewPayload())
        });
        return;
      }
      if (action === "routegen_update") {
        requests.update.push(body);
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify({ SUCCESS: true, DATA: { route_code: body.route_code || body.routeCode || "" } })
        });
        return;
      }
      await route.continue();
    });

    const counters = await openActiveCruiseV2(page);
    const initialDocumentLoads = counters.documentLoads;
    const initialUrl = page.url();

    const firstPoint = page.locator('input[name="fpwV2WeatherPoint"]').first();
    await expect(firstPoint).toBeVisible();
    await firstPoint.check();

    await page.getByRole("button", { name: "Check Conditions" }).click();
    await expect(page.locator('[data-weather-field="wind"]')).toHaveText("NE 20 mph");
    await expect(page.locator('[data-weather-field="gusts"]')).toHaveText("25");
    await expect(page.locator('[data-weather-field="waves"]')).toHaveText("3");
    await expect(page.locator('[data-weather-field="weatherFactor"]')).toHaveText("46%");
    await expect(page.locator("#fpwV2WeatherApplyBtn")).toBeEnabled();
    expect(requests.weather).toHaveLength(1);
    expect(requests.editContext).toHaveLength(1);
    expect(requests.preview).toHaveLength(1);

    requests.editContext.length = 0;
    requests.preview.length = 0;
    requests.update.length = 0;
    await page.locator("#fpwV2WeatherApplyBtn").click();

    await expect(page.locator("#fpwV2WeatherFeedback")).toContainText("Applied 46% weather factor to route.");
    await expect.poll(() => requests.update.length).toBe(1);
    expect(requests.update[0].weather_factor_pct).toBe(46);
    await expect.poll(() => counters.viewRefreshes).toBeGreaterThan(0);
    expect(counters.documentLoads).toBe(initialDocumentLoads);
    expect(page.url()).toBe(initialUrl);
  });
});
