require("./test-hooks");

if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
  throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
}

const { test, expect } = require("@playwright/test");

test.describe.configure({ timeout: 180000 });

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

async function loginToDashboard(page) {
  await gotoWithRetry(page, "/fpw/index.cfm");
  await page.fill('input[name="email"], input[name="EMAIL"]', process.env.FPW_EMAIL || "");
  await page.fill('input[type="password"], input[name="password"], input[name="PASSWORD"]', process.env.FPW_PASSWORD || "");
  await page.click('button[type="submit"], input[type="submit"]');
  await page.waitForLoadState("networkidle");
  await expect(page).not.toHaveURL(/index\.cfm$/i);
  await gotoWithRetry(page, "/fpw/app/dashboard.cfm");
  await expect(page.locator("#openRouteBuilderBtn")).toBeVisible({ timeout: 15000 });
}

async function openRoutePreview(page) {
  await page.click("#openRouteBuilderBtn");
  const routeBuilderModal = page.locator("#routeBuilderModal");
  const openedByClick = await routeBuilderModal.waitFor({ state: "visible", timeout: 5000 })
    .then(() => true)
    .catch(() => false);
  if (!openedByClick) {
    await page.evaluate(() => {
      const openBtn = document.getElementById("openRouteBuilderBtn");
      if (openBtn) {
        openBtn.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, view: window }));
      }
      const modalEl = document.getElementById("routeBuilderModal");
      if (!modalEl || !window.bootstrap || !window.bootstrap.Modal) return;
      window.bootstrap.Modal.getOrCreateInstance(modalEl).show();
    });
  }
  await expect(routeBuilderModal).toBeVisible({ timeout: 15000 });
  await expect(page.locator("#fpwRouteGen")).toBeVisible({ timeout: 15000 });

  const today = new Date().toISOString().slice(0, 10);
  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenTemplateSelect");
    return !!sel && !sel.disabled && sel.options.length > 1;
  }, { timeout: 20000 });
  const templateValue = await page.evaluate(() => {
    const sel = document.getElementById("routeGenTemplateSelect");
    if (!sel || sel.options.length <= 1) return "";
    const idx = Math.max(1, sel.options.length - 1);
    return sel.options[idx].value || "";
  });
  if (templateValue) {
    await page.selectOption("#routeGenTemplateSelect", templateValue);
  } else {
    await page.selectOption("#routeGenTemplateSelect", { index: 1 });
  }
  await page.fill("#routeGenStartDate", today);

  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenStartLocation");
    return !!sel && sel.options.length > 1;
  }, { timeout: 20000 });
  const startValue = await page.evaluate(() => {
    const sel = document.getElementById("routeGenStartLocation");
    if (!sel || sel.options.length <= 1) return "";
    const idx = Math.min(sel.options.length - 1, 2);
    return sel.options[idx].value || "";
  });
  if (startValue) {
    await page.selectOption("#routeGenStartLocation", startValue);
  } else {
    await page.selectOption("#routeGenStartLocation", { index: 1 });
  }

  await page.waitForFunction(() => {
    const sel = document.getElementById("routeGenEndLocation");
    return !!sel && sel.options.length > 1;
  }, { timeout: 20000 });
  const endValue = await page.evaluate((selectedStartValue) => {
    const sel = document.getElementById("routeGenEndLocation");
    if (!sel || sel.options.length <= 1) return "";
    let idx = Math.max(1, sel.options.length - 1);
    if (sel.options[idx].value === selectedStartValue && idx > 1) {
      idx -= 1;
    }
    return sel.options[idx].value || "";
  }, startValue);
  if (endValue) {
    await page.selectOption("#routeGenEndLocation", endValue);
  } else {
    await page.selectOption("#routeGenEndLocation", { index: 1 });
  }

  const previewBtn = page.locator("#routeGenPreviewBtn");
  await expect(previewBtn).toBeVisible({ timeout: 30000 });
  await expect(previewBtn).toBeEnabled({ timeout: 60000 });
  await page.evaluate(() => {
    const button = document.getElementById("routeGenPreviewBtn");
    if (!button) {
      throw new Error("Preview button not found.");
    }
    button.click();
  });
  await page.waitForFunction(() => {
    return document.querySelectorAll("#routeGenLegList .fpw-routegen__leg").length > 0;
  }, { timeout: 30000 });
}

async function findFirstSegmentId(page) {
  const segmentId = await page.evaluate(() => {
    const rows = Array.from(document.querySelectorAll("#routeGenLegList .fpw-routegen__leg"));
    const row = rows.find((entry) => {
      const segmentId = parseInt(entry.getAttribute("data-segment-id") || "0", 10);
      return Number.isFinite(segmentId) && segmentId > 0;
    });
    return row ? parseInt(row.getAttribute("data-segment-id") || "0", 10) : 0;
  });
  expect(segmentId).toBeGreaterThan(0);
  return segmentId;
}

async function routeBuilderAction(page, action, payload) {
  return page.evaluate(async (args) => {
    const url = `/fpw/api/v1/routeBuilder.cfc?method=handle&action=${encodeURIComponent(args.action)}`;
    const response = await fetch(url, {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        Accept: "application/json"
      },
      body: JSON.stringify(args.payload || {})
    });
    const raw = await response.text();
    try {
      return JSON.parse(raw);
    } catch (err) {
      return {
        SUCCESS: false,
        MESSAGE: "Non-JSON response",
        ERROR: { MESSAGE: String(err && err.message ? err.message : err) },
        RAW: raw
      };
    }
  }, { action, payload });
}

function numeric(value) {
  return parseFloat(String(value || "").replace(/[^0-9.]/g, "")) || 0;
}

test("Route Builder two sessions on same leg uses last-save-wins override", async ({ browser }) => {
  const contextA = await browser.newContext();
  const contextB = await browser.newContext();
  const pageA = await contextA.newPage();
  const pageB = await contextB.newPage();

  try {
    await pageA.addInitScript(() => {
      window.__FPW_ENABLE_TEST_HOOKS = true;
    });
    await pageB.addInitScript(() => {
      window.__FPW_ENABLE_TEST_HOOKS = true;
    });

    await loginToDashboard(pageA);
    await openRoutePreview(pageA);
    const segmentIdA = await findFirstSegmentId(pageA);

    await loginToDashboard(pageB);
    await openRoutePreview(pageB);
    const segmentIdB = await findFirstSegmentId(pageB);
    expect(segmentIdB).toBe(segmentIdA);

    const clearRes = await routeBuilderAction(pageA, "routegen_clearsegmentoverride", {
      segment_id: segmentIdA
    });
    expect(clearRes && clearRes.SUCCESS === true).toBeTruthy();

    const saveARes = await routeBuilderAction(pageA, "routegen_savesegmentoverride", {
      segment_id: segmentIdA,
      geometry: [
        { lat: 41.7300, lon: -87.6200 },
        { lat: 41.9800, lon: -87.2200 },
        { lat: 42.2500, lon: -86.7800 }
      ]
    });
    expect(saveARes && saveARes.SUCCESS === true).toBeTruthy();
    const nmA = numeric(saveARes && saveARes.DATA ? saveARes.DATA.computed_nm : 0);
    expect(nmA).toBeGreaterThan(0);

    const saveBRes = await routeBuilderAction(pageB, "routegen_savesegmentoverride", {
      segment_id: segmentIdB,
      geometry: [
        { lat: 41.7400, lon: -87.6100 },
        { lat: 41.7900, lon: -87.5000 },
        { lat: 41.8600, lon: -87.3300 }
      ]
    });
    expect(saveBRes && saveBRes.SUCCESS === true).toBeTruthy();
    const nmB = numeric(saveBRes && saveBRes.DATA ? saveBRes.DATA.computed_nm : 0);
    expect(nmB).toBeGreaterThan(0);
    expect(Math.abs(nmA - nmB)).toBeGreaterThan(0.05);

    const getAfterBRes = await routeBuilderAction(pageA, "routegen_getleggeometry", {
      segment_id: segmentIdA
    });
    expect(getAfterBRes && getAfterBRes.SUCCESS === true).toBeTruthy();
    expect(!!(getAfterBRes && getAfterBRes.DATA && getAfterBRes.DATA.has_segment_override)).toBeTruthy();
    expect(String((getAfterBRes && getAfterBRes.DATA && getAfterBRes.DATA.source) || "").toLowerCase()).toContain("user_segment");
    const nmAfter = numeric(getAfterBRes && getAfterBRes.DATA ? getAfterBRes.DATA.computed_nm : 0);
    expect(Math.abs(nmAfter - nmB)).toBeLessThan(0.05);

    const finalClearRes = await routeBuilderAction(pageA, "routegen_clearsegmentoverride", {
      segment_id: segmentIdA
    });
    expect(finalClearRes && finalClearRes.SUCCESS === true).toBeTruthy();
  } finally {
    await contextA.close();
    await contextB.close();
  }
});
