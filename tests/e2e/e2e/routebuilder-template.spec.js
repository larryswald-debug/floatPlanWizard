const { submitLoginForm } = require("./test-hooks");

if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
  throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
}

const { test, expect } = require("@playwright/test");

test.describe.configure({ timeout: 120000 });

async function gotoWithRetry(page, url, retries = 1) {
  let lastError;
  for (let attempt = 0; attempt <= retries; attempt += 1) {
    try {
      await page.goto(url, { waitUntil: "domcontentloaded", timeout: 45000 });
      return;
    } catch (error) {
      lastError = error;
      if (attempt >= retries) {
        throw error;
      }
      await page.waitForTimeout(750);
    }
  }
  throw lastError;
}

async function waitForRouteBuilderModalToClose(page, timeoutMs) {
  const modal = page.locator("#routeBuilderModal");
  const closedByApp = await page.waitForFunction(() => {
    const el = document.getElementById("routeBuilderModal");
    if (!el) return true;
    if (!el.classList.contains("show")) return true;
    const style = window.getComputedStyle(el);
    return style.display === "none" || el.getAttribute("aria-hidden") === "true";
  }, { timeout: timeoutMs }).then(() => true).catch(() => false);

  if (!closedByApp) {
    const closeBtn = page.locator("#routeGenCloseBtn, #routeGenCancelBtn").first();
    if (await closeBtn.isVisible().catch(() => false)) {
      await closeBtn.click({ timeout: 1500 }).catch(() => {});
    }
  }

  await expect(modal).toBeHidden({ timeout: timeoutMs });
  await expect(page.locator(".modal-backdrop.show")).toHaveCount(0, { timeout: timeoutMs });
}

async function clickPreviewWhenReady(page) {
  const previewBtn = page.locator("#routeGenPreviewBtn");
  await expect(previewBtn).toBeVisible({ timeout: 30000 });
  await expect(previewBtn).toBeEnabled({ timeout: 60000 });
  await previewBtn.click({ timeout: 60000 });
}

async function loginToDashboard(page) {
  await submitLoginForm(page, { loginUrl: "/fpw/index.cfm", waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle");
  await expect(page).not.toHaveURL(/index\.cfm$/i);
  await gotoWithRetry(page, "/fpw/app/dashboard.cfm");
}

test("Route Builder generates route from template and opens timeline editor", async ({ page }) => {
  await loginToDashboard(page);
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 15000 });

  await page.click("#openRouteBuilderBtn");
  await expect(page.locator("#routeBuilderModal")).toBeVisible({ timeout: 15000 });
  await expect(page.locator("#fpwRouteGen")).toBeVisible({ timeout: 15000 });

  const today = new Date().toISOString().slice(0, 10);
  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenTemplateSelect");
    return !!sel && !sel.disabled && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenTemplateSelect", { index: 1 });

  await page.fill("#routeGenStartDate", today);

  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenStartLocation");
    return !!sel && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenStartLocation", { index: 1 });

  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenEndLocation");
    return !!sel && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenEndLocation", { index: 1 });

  await clickPreviewWhenReady(page);
  await page.waitForFunction(() => {
    const txt = document.getElementById("routeGenLegCount");
    if (!txt) return false;
    const n = parseInt((txt.textContent || "").replace(/[^0-9]/g, ""), 10);
    return Number.isFinite(n) && n > 0;
  }, { timeout: 30000 });
  await expect(page.locator("#routeGenLegList .fpw-routegen__leglocks").first()).toHaveText(/[0-9]+/, { timeout: 10000 });

  await page.click("#routeGenGenerateBtn");
  const generatedViaAlert = await page.waitForFunction(() => {
    const alertEl = document.getElementById("dashboardAlert");
    if (!alertEl) return false;
    const text = String(alertEl.textContent || "");
    return /route generated successfully/i.test(text);
  }, { timeout: 12000 }).then(() => true).catch(() => false);
  if (!generatedViaAlert) {
    await page.waitForFunction(() => {
      const modal = document.getElementById("routeBuilderModal");
      return !modal || !modal.classList.contains("show");
    }, { timeout: 30000 });
  }
  await waitForRouteBuilderModalToClose(page, 30000);

  await page.click("#openRouteBuilderBtn");
  await expect(page.locator("#routeBuilderModal")).toBeVisible({ timeout: 15000 });
  await expect(page.locator("#routeGenRouteCode")).toContainText("Draft", { timeout: 10000 });
  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
});

test("Route Builder leg row opens lock panel, then map editor from button", async ({ page }) => {
  await loginToDashboard(page);
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 15000 });

  await page.click("#openRouteBuilderBtn");
  await expect(page.locator("#routeBuilderModal")).toBeVisible({ timeout: 15000 });
  await expect(page.locator("#fpwRouteGen")).toBeVisible({ timeout: 15000 });

  const today = new Date().toISOString().slice(0, 10);
  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenTemplateSelect");
    return !!sel && !sel.disabled && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenTemplateSelect", { index: 1 });

  await page.fill("#routeGenStartDate", today);

  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenStartLocation");
    return !!sel && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenStartLocation", { index: 1 });

  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenEndLocation");
    return !!sel && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenEndLocation", { index: 1 });

  await clickPreviewWhenReady(page);
  await page.waitForFunction(() => {
    const rows = document.querySelectorAll("#routeGenLegList .fpw-routegen__leg");
    return rows.length > 0;
  }, { timeout: 30000 });

  await page.click("#routeGenLegList .fpw-routegen__leg");
  await expect(page.locator("#routeGenLegList .fpw-routegen__leglockpanel")).toBeVisible({ timeout: 10000 });
  await expect(page.locator("#routeGenLegList .fpw-routegen__leglockhead")).toContainText("Lock Navigation Details", { timeout: 10000 });
  await page.waitForFunction(() => {
    const panel = document.querySelector("#routeGenLegList .fpw-routegen__leglockpanel");
    if (!panel) return false;
    return !!panel.querySelector(".fpw-routegen__locksummary, .fpw-routegen__lockstate");
  }, { timeout: 15000 });
  const firstOpenMapBtn = page.locator('#routeGenLegList .fpw-routegen__leg [data-leg-action="open-map"]').first();
  await expect(firstOpenMapBtn).toBeVisible({ timeout: 15000 });
  await firstOpenMapBtn.click();
  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 10000 });
  await expect(page.locator("#routeGenLegMap")).toBeVisible({ timeout: 10000 });
  await expect(page.locator("#routeGenLegMapTitle")).toContainText("->", { timeout: 10000 });
  await expect(page.locator("#routeGenLegMap .leaflet-tooltip").filter({ hasText: "Start" }).first()).toBeVisible({ timeout: 10000 });
  await expect(page.locator("#routeGenLegMap .leaflet-tooltip").filter({ hasText: "End" }).first()).toBeVisible({ timeout: 10000 });
  await expect(page.locator("#routeGenLegSaveBtn")).toBeEnabled();
  await page.click("#routeGenLegOverlayCloseBtn");
  await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 10000 });
  const reopenOpenMapBtn = page.locator('#routeGenLegList .fpw-routegen__leg [data-leg-action="open-map"]').first();
  await expect(reopenOpenMapBtn).toBeVisible({ timeout: 15000 });
  await reopenOpenMapBtn.click();
  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 10000 });
  await expect(page.locator("#routeGenLegMap .leaflet-tooltip").filter({ hasText: "Start" }).first()).toBeVisible({ timeout: 10000 });
  await expect(page.locator("#routeGenLegMap .leaflet-tooltip").filter({ hasText: "End" }).first()).toBeVisible({ timeout: 10000 });
  await page.click("#routeGenLegOverlayCloseBtn");
  await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 10000 });
  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
  await page.click("#openRouteBuilderBtn");
  await expect(page.locator("#routeBuilderModal")).toBeVisible({ timeout: 15000 });
  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenTemplateSelect");
    return !!sel && !sel.disabled && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenTemplateSelect", { index: 1 });
  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenStartLocation");
    return !!sel && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenStartLocation", { index: 1 });
  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenEndLocation");
    return !!sel && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenEndLocation", { index: 1 });
  await clickPreviewWhenReady(page);
  await page.waitForFunction(() => {
    return document.querySelectorAll("#routeGenLegList .fpw-routegen__leg").length > 0;
  }, { timeout: 30000 });
  const modalReopenOpenMapBtn = page.locator('#routeGenLegList .fpw-routegen__leg [data-leg-action="open-map"]').first();
  await expect(modalReopenOpenMapBtn).toBeVisible({ timeout: 30000 });
  await modalReopenOpenMapBtn.click();
  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 10000 });
  await expect(page.locator("#routeGenLegMap .leaflet-tooltip").filter({ hasText: "Start" }).first()).toBeVisible({ timeout: 10000 });
  await expect(page.locator("#routeGenLegMap .leaflet-tooltip").filter({ hasText: "End" }).first()).toBeVisible({ timeout: 10000 });
  await page.click("#routeGenLegOverlayCloseBtn");
  await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 10000 });

  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
});

test("Route Builder saves and clears leg override via deterministic geometry hook", async ({ page }) => {
  await page.addInitScript(() => {
    window.__FPW_ENABLE_TEST_HOOKS = true;
  });

  await loginToDashboard(page);
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 15000 });

  await page.click("#openRouteBuilderBtn");
  await expect(page.locator("#routeBuilderModal")).toBeVisible({ timeout: 15000 });
  await expect(page.locator("#fpwRouteGen")).toBeVisible({ timeout: 15000 });

  const today = new Date().toISOString().slice(0, 10);
  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenTemplateSelect");
    return !!sel && !sel.disabled && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenTemplateSelect", { index: 1 });

  await page.fill("#routeGenStartDate", today);

  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenStartLocation");
    return !!sel && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenStartLocation", { index: 1 });

  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenEndLocation");
    return !!sel && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenEndLocation", { index: 1 });

  await clickPreviewWhenReady(page);
  await page.waitForFunction(() => {
    return document.querySelectorAll("#routeGenLegList .fpw-routegen__leg").length > 0;
  }, { timeout: 30000 });

  const legOrder = await page.evaluate(() => {
    const rows = Array.from(document.querySelectorAll("#routeGenLegList .fpw-routegen__leg"));
    const candidate = rows.find((row) => {
      const segmentId = parseInt(row.getAttribute("data-segment-id") || "0", 10);
      return Number.isFinite(segmentId) && segmentId > 0;
    });
    return candidate ? candidate.getAttribute("data-leg-order") : "";
  });
  expect(legOrder).not.toEqual("");

  await page.evaluate((orderText) => {
    const btn = document.querySelector(`#routeGenLegList .fpw-routegen__leg[data-leg-order="${orderText}"] [data-leg-action="open-map"]`);
    if (!btn) throw new Error("Open map button not found for selected leg.");
    btn.click();
  }, legOrder);
  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 10000 });
  await expect(page.locator("#routeGenLegMap")).toBeVisible({ timeout: 10000 });

  await page.waitForFunction(() => {
    const hook = window.FPW
      && window.FPW.DashboardModules
      && window.FPW.DashboardModules.routeBuilder
      && window.FPW.DashboardModules.routeBuilder.test;
    return !!(hook && typeof hook.isReady === "function" && hook.isReady());
  }, { timeout: 10000 });

  const setResult = await page.evaluate(() => {
    return window.FPW.DashboardModules.routeBuilder.test.setDraftGeometry([
      { lat: 41.8781, lon: -87.6298 },
      { lat: 42.1000, lon: -87.3000 },
      { lat: 42.3500, lon: -86.9000 }
    ]);
  });
  expect(setResult).toBeTruthy();

  await page.click("#routeGenLegSaveBtn");
  await expect(page.locator("#routeGenLegMapStatus")).toContainText(/saved/i, { timeout: 20000 });

  const savedSnapshot = await page.evaluate(() => {
    return window.FPW.DashboardModules.routeBuilder.test.snapshot();
  });
  expect(savedSnapshot.source.toLowerCase()).not.toContain("default");

  await page.click("#routeGenLegClearBtn");
  await page.click("#routeGenLegSaveBtn");
  await expect(page.locator("#routeGenLegMapSource")).toContainText(/default/i, { timeout: 20000 });
  await expect(page.locator("#routeGenLegMapStatus")).toContainText(/reverted|default|no saved geometry/i, { timeout: 20000 });

  await page.click("#routeGenLegOverlayCloseBtn");
  await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 10000 });
  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
});

test("Route Builder weather suggestion assist applies manually and preview keeps manual weather factor payload", async ({ page }) => {
  const weatherZipPayload = {
    SUCCESS: true,
    DATA: {
      FORECAST: [
        { windSpeed: "18 to 26 mph", gustMph: 31 }
      ],
      ALERTS: [
        { severity: "Moderate" },
        { severity: "Severe" }
      ],
      MARINE: {
        wave_height_ft: 3.6
      },
      surface: {
        visibility_mi: "10+",
        pressure_inhg: "30.22",
        pressure_trend: null
      }
    }
  };
  let lastPreviewWeatherFactor = "";
  let weatherZipRequestCount = 0;

  await page.route("**/api/v1/weather.cfc?*", async (route) => {
    const url = route.request().url();
    if (/action=zip/i.test(url)) {
      weatherZipRequestCount += 1;
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify(weatherZipPayload)
      });
      return;
    }
    await route.continue();
  });

  await page.route("**/api/v1/routeBuilder.cfc?*", async (route) => {
    const request = route.request();
    if (/action=routegen_preview/i.test(request.url()) && request.method() === "POST") {
      try {
        const raw = request.postData() || "{}";
        const parsed = JSON.parse(raw);
        lastPreviewWeatherFactor = String(
          parsed.weather_factor_pct !== undefined && parsed.weather_factor_pct !== null
            ? parsed.weather_factor_pct
            : ""
        ).trim();
      } catch (err) {
        lastPreviewWeatherFactor = "";
      }
    }
    await route.continue();
  });

  await loginToDashboard(page);
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 15000 });

  await page.evaluate(() => {
    var weatherZipInput = document.getElementById("weatherZip");
    if (!weatherZipInput) return;
    weatherZipInput.value = "33708";
    weatherZipInput.dispatchEvent(new Event("input", { bubbles: true }));
    weatherZipInput.dispatchEvent(new Event("change", { bubbles: true }));
  });

  await page.click("#openRouteBuilderBtn");
  await expect(page.locator("#routeBuilderModal")).toBeVisible({ timeout: 15000 });
  await expect(page.locator("#fpwRouteGen")).toBeVisible({ timeout: 15000 });

  const today = new Date().toISOString().slice(0, 10);
  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenTemplateSelect");
    return !!sel && !sel.disabled && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenTemplateSelect", { index: 1 });
  await page.fill("#routeGenStartDate", today);

  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenStartLocation");
    return !!sel && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenStartLocation", { index: 1 });

  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenEndLocation");
    return !!sel && sel.options.length > 1;
  }, { timeout: 20000 });
  await page.selectOption("#routeGenEndLocation", { index: 1 });

  await expect(page.locator("#routeGenWeatherSuggestRefreshBtn")).toBeVisible({ timeout: 10000 });
  await page.click("#routeGenWeatherSuggestRefreshBtn");
  await expect(page.locator("#routeGenWeatherSuggestValue")).toHaveText(/^\d+%$/, { timeout: 15000 });
  await expect(page.locator("#routeGenWeatherSuggestApplyBtn")).toBeEnabled({ timeout: 10000 });
  await expect(page.locator("#routeGenWeatherSuggestFactors")).toContainText("Pressure 30.22 inHg", { timeout: 10000 });
  await expect(page.locator("#routeGenWeatherSuggestFactors")).not.toContainText(/null/i, { timeout: 10000 });

  const suggestedPct = await page.evaluate(() => {
    var text = String((document.getElementById("routeGenWeatherSuggestValue") || {}).textContent || "");
    var n = parseInt(text.replace(/[^0-9]/g, ""), 10);
    return Number.isFinite(n) ? n : -1;
  });
  expect(suggestedPct).toBeGreaterThanOrEqual(0);
  expect(suggestedPct).toBeLessThanOrEqual(60);

  await page.click("#routeGenWeatherSuggestApplyBtn");
  await expect(page.locator("#routeGenWeatherFactorPct")).toHaveValue(/^\d+$/, { timeout: 10000 });
  const appliedPct = await page.evaluate(() => {
    var input = document.getElementById("routeGenWeatherFactorPct");
    var txt = input ? String(input.value || "") : "";
    var n = parseInt(txt.replace(/[^0-9]/g, ""), 10);
    return Number.isFinite(n) ? n : -1;
  });
  const suggestedPctAfterApply = await page.evaluate(() => {
    var text = String((document.getElementById("routeGenWeatherSuggestValue") || {}).textContent || "");
    var n = parseInt(text.replace(/[^0-9]/g, ""), 10);
    return Number.isFinite(n) ? n : -1;
  });
  expect(appliedPct).toBeGreaterThanOrEqual(0);
  expect(appliedPct).toBeLessThanOrEqual(60);
  expect(appliedPct).toBe(suggestedPctAfterApply);

  await page.fill("#routeGenWeatherFactorPct", "13");
  await page.dispatchEvent("#routeGenWeatherFactorPct", "input");
  await page.dispatchEvent("#routeGenWeatherFactorPct", "change");
  await expect(page.locator("#routeGenWeatherFactorPct")).toHaveValue("13");

  await clickPreviewWhenReady(page);
  await page.waitForFunction(() => {
    const rows = document.querySelectorAll("#routeGenLegList .fpw-routegen__leg");
    return rows.length > 0;
  }, { timeout: 30000 });
  expect(lastPreviewWeatherFactor).toBe("13");
  expect(weatherZipRequestCount).toBeGreaterThan(0);

  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
});
