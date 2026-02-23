require("./test-hooks");

if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
  throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
}

const { test, expect } = require("@playwright/test");

test.describe.configure({ timeout: 120000 });

async function loginToDashboard(page) {
  await page.goto("/fpw/index.cfm", { waitUntil: "domcontentloaded" });
  await page.fill('input[name="email"], input[name="EMAIL"]', process.env.FPW_EMAIL || "");
  await page.fill('input[type="password"], input[name="password"], input[name="PASSWORD"]', process.env.FPW_PASSWORD || "");
  await page.click('button[type="submit"], input[type="submit"]');
  await page.waitForLoadState("networkidle");
  await expect(page).not.toHaveURL(/index\.cfm$/i);
  await page.goto("/fpw/app/dashboard.cfm", { waitUntil: "domcontentloaded" });
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 30000 });
}

async function openPreview(page) {
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

  await expect(page.locator("#routeGenPreviewBtn")).toBeEnabled({ timeout: 30000 });
  await page.click("#routeGenPreviewBtn");
  await page.waitForFunction(() => {
    return document.querySelectorAll("#routeGenLegList .fpw-routegen__leg").length > 0;
  }, { timeout: 30000 });
}

test("Route Builder lock panel handles retry and keeps map action available", async ({ page }) => {
  let injectedFailure = false;
  await page.route("**/api/v1/routeBuilder.cfc?*action=routegen_getleglocks*", async (route) => {
    if (!injectedFailure) {
      injectedFailure = true;
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          SUCCESS: false,
          AUTH: true,
          MESSAGE: "Injected lock-panel failure",
          ERROR: { MESSAGE: "Injected lock-panel failure" }
        })
      });
      return;
    }
    await route.continue();
  });

  await loginToDashboard(page);
  await openPreview(page);

  const firstLeg = page.locator("#routeGenLegList .fpw-routegen__leg").first();
  await expect(firstLeg).toBeVisible({ timeout: 15000 });

  await firstLeg.click();
  const lockPanel = page.locator("#routeGenLegList .fpw-routegen__leglockpanel").first();
  await expect(lockPanel).toBeVisible({ timeout: 10000 });
  await expect(lockPanel).toContainText("Injected lock-panel failure", { timeout: 10000 });
  await expect(lockPanel.locator('[data-leg-action="reload-locks"]')).toBeVisible({ timeout: 10000 });

  await page.evaluate(() => {
    const retryBtn = document.querySelector('#routeGenLegList .fpw-routegen__leglockpanel [data-leg-action="reload-locks"]');
    if (retryBtn) retryBtn.click();
  });
  await expect(lockPanel).not.toContainText("Injected lock-panel failure", { timeout: 15000 });
  await expect(lockPanel).toContainText(/Lock Navigation Details|No locks mapped|Locks/i, { timeout: 15000 });

  const openMapBtn = firstLeg.locator('[data-leg-action="open-map"]');
  await expect(openMapBtn).toBeVisible({ timeout: 10000 });
  await openMapBtn.click();

  await expect(page.locator("#routeGenLegMapPanel")).toHaveClass(/is-open/, { timeout: 10000 });
  await expect(page.locator("#routeGenLegMap")).toBeVisible({ timeout: 10000 });
  await expect(page.locator("#routeGenLegMapTitle")).toContainText("->", { timeout: 10000 });

  await page.click("#routeGenLegOverlayCloseBtn");
  await expect(page.locator("#routeGenLegOverlay")).not.toHaveClass(/is-open/, { timeout: 10000 });

  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
});

test("Route Builder keeps lock panel open when advanced settings change", async ({ page }) => {
  await loginToDashboard(page);
  await openPreview(page);

  const secondLeg = page.locator("#routeGenLegList .fpw-routegen__leg").nth(1);
  await expect(secondLeg).toBeVisible({ timeout: 15000 });
  await secondLeg.scrollIntoViewIfNeeded();
  await secondLeg.click();
  await page.evaluate(() => {
    const openPanel = document.querySelector("#routeGenLegList .fpw-routegen__leglockpanel.is-open");
    if (openPanel) return;
    const rows = document.querySelectorAll("#routeGenLegList .fpw-routegen__leg");
    if (rows.length > 1) {
      rows[1].dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, view: window }));
    }
  });

  const openPanelSelector = "#routeGenLegList .fpw-routegen__leglockpanel.is-open";
  const openPanel = page.locator(openPanelSelector);
  await expect(openPanel).toBeVisible({ timeout: 10000 });
  await expect(openPanel).toContainText(/Lock Navigation Details|No locks mapped|Locks/i, { timeout: 15000 });

  const openOrder = await openPanel.getAttribute("data-leg-order");
  await page.evaluate(() => {
    const advanced = document.getElementById("routeGenAdvanced");
    if (advanced) advanced.open = true;
  });

  await page.fill("#routeGenReservePct", "25");
  await page.dispatchEvent("#routeGenReservePct", "input");
  await page.dispatchEvent("#routeGenReservePct", "change");

  await expect.poll(async () => {
    const panel = await page.locator(openPanelSelector).first();
    if (!(await panel.count())) return "";
    return panel.getAttribute("data-leg-order");
  }, { timeout: 15000 }).toBe(openOrder);

  await page.evaluate(() => {
    const select = document.getElementById("routeGenComfortProfile");
    if (!select || !select.options || !select.options.length) return;
    let nextValue = "";
    for (let i = 0; i < select.options.length; i += 1) {
      const val = String(select.options[i].value || "");
      if (val && val !== select.value) {
        nextValue = val;
        break;
      }
    }
    if (!nextValue) return;
    select.value = nextValue;
    select.dispatchEvent(new Event("change", { bubbles: true }));
  });

  await expect.poll(async () => {
    const panel = await page.locator(openPanelSelector).first();
    if (!(await panel.count())) return "";
    return panel.getAttribute("data-leg-order");
  }, { timeout: 15000 }).toBe(openOrder);

  await expect(page.locator(openPanelSelector)).toBeVisible({ timeout: 10000 });
  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
});

test("Route Builder timeline fuel updates after advanced input changes", async ({ page }) => {
  await loginToDashboard(page);
  await openPreview(page);

  await expect(page.locator("#routeGenGenerateBtn")).toBeEnabled({ timeout: 30000 });
  await page.click("#routeGenGenerateBtn");
  await expect(page.locator("#dashboardAlert")).toContainText("Route generated successfully.", { timeout: 30000 });
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 30000 });

  const editBtn = page.locator(".expedition-route-card .js-expedition-view-edit").first();
  await expect(editBtn).toBeVisible({ timeout: 30000 });
  await editBtn.click();

  await expect(page.locator("#routeBuilderModal")).toBeVisible({ timeout: 15000 });
  await page.waitForFunction(() => {
    return document.querySelectorAll("#routeGenLegList .fpw-routegen__leg").length > 0;
  }, { timeout: 30000 });

  const firstLeg = page.locator("#routeGenLegList .fpw-routegen__leg").first();
  await firstLeg.click();
  const openPanel = page.locator("#routeGenLegList .fpw-routegen__leglockpanel.is-open").first();
  await expect(openPanel).toBeVisible({ timeout: 15000 });
  await expect(openPanel).toContainText("Cruise Timeline", { timeout: 15000 });

  const timelineFuelSelector = "#routeGenLegList .fpw-routegen__leglockpanel.is-open [data-testid='required-fuel']";
  await expect(page.locator(timelineFuelSelector).first()).toBeVisible({ timeout: 15000 });
  const beforeFuelText = await page.locator(timelineFuelSelector).first().innerText();

  await page.evaluate(() => {
    const advanced = document.getElementById("routeGenAdvanced");
    if (advanced) advanced.open = true;
  });

  const currentFuelInput = Number(await page.inputValue("#routeGenFuelBurnGph"));
  const nextFuelValue = currentFuelInput === 32 ? "28" : "32";
  const previewReqP = page.waitForRequest((req) => {
    return req.method() === "POST"
      && req.url().includes("action=routegen_preview");
  }, { timeout: 30000 });
  const timelineReqP = page.waitForRequest((req) => {
    return req.method() === "POST"
      && req.url().includes("action=generateCruiseTimeline");
  }, { timeout: 30000 });

  await page.fill("#routeGenFuelBurnGph", nextFuelValue);
  await page.dispatchEvent("#routeGenFuelBurnGph", "input");
  await page.dispatchEvent("#routeGenFuelBurnGph", "change");

  const previewReq = await previewReqP;
  const previewResponse = await previewReq.response();
  expect(previewResponse).toBeTruthy();
  const previewPayload = await previewResponse.json();
  expect(!!previewPayload.SUCCESS).toBeTruthy();

  const timelineReq = await timelineReqP;
  const timelineResponse = await timelineReq.response();
  expect(timelineResponse).toBeTruthy();
  const timelinePayload = await timelineResponse.json();
  expect(!!(timelinePayload.success || timelinePayload.SUCCESS)).toBeTruthy();

  await expect.poll(async () => {
    return (await page.locator(timelineFuelSelector).first().innerText()).trim();
  }, { timeout: 20000 }).not.toBe(beforeFuelText.trim());

  const afterFuelText = await page.locator(timelineFuelSelector).first().innerText();
  expect(afterFuelText).not.toEqual(beforeFuelText);

  await expect(openPanel).toContainText("Required:", { timeout: 10000 });
  await page.click("#routeGenCancelBtn");
  await expect(page.locator("#routeBuilderModal")).toBeHidden({ timeout: 15000 });
});
