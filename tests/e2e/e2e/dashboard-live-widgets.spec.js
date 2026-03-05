require("./test-hooks");

if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
  throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
}

const { test, expect } = require("@playwright/test");

test.describe.configure({ timeout: 120000 });

function buildForecastRows() {
  const now = Date.now();
  const rows = [];
  for (let i = 0; i < 12; i += 1) {
    const start = new Date(now + i * 60 * 60 * 1000).toISOString();
    rows.push({
      name: i === 0 ? "Now" : `+${i}h`,
      startTime: start,
      temperature: 58 + i,
      windDirection: ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][i % 8],
      windSpeed: `${8 + i} mph`,
      gustMph: 14 + i,
      shortForecast: i % 3 === 0 ? "Rain showers likely" : "Partly cloudy",
      probabilityOfPrecipitation: { value: (i % 3 === 0 ? 60 : 20) }
    });
  }
  return rows;
}

function buildMarinePayload() {
  const now = Date.now();
  const series = [];
  for (let i = 0; i < 8; i += 1) {
    series.push({
      t: new Date(now + i * 3 * 60 * 60 * 1000).toISOString(),
      h: (1.1 + Math.sin(i / 2) * 0.9).toFixed(2)
    });
  }
  return {
    tide: {
      stationName: "Chicago Harbor",
      series
    }
  };
}

function successPayload(zip) {
  if (zip === "11111") {
    return {
      SUCCESS: true,
      MESSAGE: "No marine alerts",
      DATA: {
        SUMMARY: "Calm weather window.",
        META: { anchor: { lat: 41.88, lon: -87.63 } },
        ALERTS: [],
        FORECAST: buildForecastRows(),
        MARINE: null
      }
    };
  }

  return {
    SUCCESS: true,
    MESSAGE: "Fresh advisory winds with periods of rain.",
    DATA: {
      SUMMARY: "Fresh advisory winds with periods of rain.",
      META: { anchor: { lat: 41.88, lon: -87.63 } },
      ALERTS: [
        { severity: "Severe", headline: "Small Craft Advisory", instruction: "Use caution in open water." },
        { severity: "Moderate", headline: "Gale Watch", instruction: "Expect strong gusts overnight." },
        { severity: "Minor", headline: "Dense Fog Advisory", instruction: "Reduce speed in harbor channels." }
      ],
      FORECAST: buildForecastRows(),
      MARINE: buildMarinePayload()
    }
  };
}

async function loginToDashboard(page) {
  await page.goto("/fpw/index.cfm", { waitUntil: "domcontentloaded" });
  await page.fill('input[name="email"], input[name="EMAIL"]', process.env.FPW_EMAIL || "");
  await page.fill('input[type="password"], input[name="password"], input[name="PASSWORD"]', process.env.FPW_PASSWORD || "");
  await page.evaluate(() => {
    var form = document.getElementById("loginForm");
    if (!form) return;
    if (typeof form.requestSubmit === "function") {
      form.requestSubmit();
      return;
    }
    form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
  });
  await page.waitForLoadState("networkidle");
  await expect(page).not.toHaveURL(/index\.cfm$/i);
  await page.goto("/fpw/app/dashboard.cfm", { waitUntil: "domcontentloaded" });
  await page.evaluate(() => {
    const collapse = document.getElementById("alertsCollapse");
    const toggle = document.querySelector('[data-bs-target="#alertsCollapse"]');
    if (collapse && !collapse.classList.contains("show") && toggle) {
      toggle.click();
    }
  });
  await expect(page.locator("#alertsCollapse")).toHaveClass(/show/, { timeout: 10000 });
  await expect(page.locator("#weatherRefreshBtn")).toBeVisible({ timeout: 30000 });
}

test("Dashboard weather/tide/alerts widgets render success and error states", async ({ page }) => {
  await page.route("**/api/v1/weather.cfc?*", async (route) => {
    const reqUrl = new URL(route.request().url());
    const zip = (reqUrl.searchParams.get("zip") || "").trim();
    if (zip === "99999") {
      await route.fulfill({
        status: 500,
        contentType: "application/json",
        body: JSON.stringify({ SUCCESS: false, MESSAGE: "Injected weather failure" })
      });
      return;
    }
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(successPayload(zip))
    });
  });

  await loginToDashboard(page);

  await page.fill("#weatherZip", "60601");
  await page.click("#weatherRefreshBtn");

  await expect(page.locator("#weatherSummary")).toContainText("Fresh advisory winds", { timeout: 20000 });
  await expect(page.locator("#weatherAlertLabel")).toContainText("3 active", { timeout: 10000 });
  await expect(page.locator("#weatherAlertsList .fpw-wx__alertItem")).toHaveCount(2, { timeout: 10000 });
  await expect(page.locator("#weatherTimeline .fpw-wx__bar")).toHaveCount(12, { timeout: 15000 });
  await expect(page.locator("#tideGraph")).not.toHaveClass(/d-none/, { timeout: 10000 });
  await expect(page.locator("#tideGraphNowValue")).not.toHaveText("Now —", { timeout: 10000 });
  await expect(page.locator("#weatherError")).toHaveClass(/d-none/, { timeout: 10000 });

  await page.fill("#weatherZip", "11111");
  await page.click("#weatherRefreshBtn");
  await expect(page.locator("#weatherAlertsEmpty")).not.toHaveClass(/d-none/, { timeout: 10000 });
  await expect(page.locator("#weatherAlertsList .fpw-wx__alertItem")).toHaveCount(0, { timeout: 10000 });
  await expect(page.locator("#tideGraphEmpty")).not.toHaveClass(/d-none/, { timeout: 10000 });

  await page.fill("#weatherZip", "99999");
  await page.click("#weatherRefreshBtn");
  await expect(page.locator("#weatherError")).not.toHaveClass(/d-none/, { timeout: 10000 });
  await expect(page.locator("#weatherError")).toContainText("Request failed with status 500", { timeout: 10000 });
});
