const { test, expect } = require("@playwright/test");

const baseUrl = process.env.FPW_BASE_URL || "http://localhost:8500/fpw";
const representativePages = [
  ["Homepage", "/"],
  ["Solo Guide", "/solo-boating-safety-guide/"],
  ["Shore Contact", "/shore-contact-overdue-boater/"],
  ["Pricing", "/app/pricing.cfm"],
  ["Boat Fuel Calculator", "/boat-fuel-calculator/"],
  ["Great Loop", "/great-loop/locks/"]
];

function collectRuntimeFailures(page) {
  const failures = [];
  page.on("console", (message) => {
    if (message.type() === "error") failures.push(`console: ${message.text()}`);
  });
  page.on("pageerror", (error) => failures.push(`pageerror: ${error.message}`));
  page.on("requestfailed", (request) => {
    const failure = request.failure();
    const errorText = failure ? failure.errorText : "unknown";
    if (!/ERR_ABORTED|cancelled/i.test(errorText)) {
      failures.push(`requestfailed: ${request.url()} (${errorText})`);
    }
  });
  page.on("response", (response) => {
    if (response.status() >= 500) failures.push(`response ${response.status()}: ${response.url()}`);
  });
  return failures;
}

async function loadPage(page, path) {
  const response = await page.goto(`${baseUrl}${path}`, { waitUntil: "domcontentloaded" });
  expect(response && response.status(), path).toBe(200);
  await expect(page.locator(".fpw-site-footer")).toBeVisible();
}

async function footerMetrics(page) {
  return page.evaluate(() => {
    const footer = document.querySelector(".fpw-site-footer");
    const shell = document.querySelector(".fpw-footer-shell");
    const grid = document.querySelector(".fpw-footer-grid");
    const footerRect = footer.getBoundingClientRect();
    const shellRect = shell.getBoundingClientRect();
    const columns = Array.from(grid.children).map((element) => {
      const rect = element.getBoundingClientRect();
      return {
        left: rect.left,
        right: rect.right,
        top: rect.top,
        width: rect.width
      };
    });
    const focusables = Array.from(footer.querySelectorAll("a[href]"));

    return {
      viewportWidth: window.innerWidth,
      documentWidth: document.documentElement.scrollWidth,
      bodyWidth: document.body.scrollWidth,
      footerRect: { left: footerRect.left, right: footerRect.right, width: footerRect.width },
      shellRect: { left: shellRect.left, right: shellRect.right, width: shellRect.width },
      gridWidth: grid.clientWidth,
      gridScrollWidth: grid.scrollWidth,
      template: getComputedStyle(grid).gridTemplateColumns,
      distinctColumnLefts: new Set(columns.map((rect) => Math.round(rect.left))).size,
      distinctRows: new Set(columns.map((rect) => Math.round(rect.top))).size,
      columns,
      focusablesContained: focusables.every((element) => {
        const rect = element.getBoundingClientRect();
        return rect.left >= -1 && rect.right <= window.innerWidth + 1;
      })
    };
  });
}

async function expectFooterContained(page, expectedWidth) {
  const metrics = await footerMetrics(page);
  expect(metrics.viewportWidth).toBe(expectedWidth);
  expect(metrics.documentWidth).toBeLessThanOrEqual(expectedWidth + 1);
  expect(metrics.bodyWidth).toBeLessThanOrEqual(expectedWidth + 1);
  expect(metrics.gridScrollWidth).toBeLessThanOrEqual(metrics.gridWidth + 1);
  expect(metrics.focusablesContained).toBe(true);

  for (const column of metrics.columns) {
    expect(column.left).toBeGreaterThanOrEqual(metrics.shellRect.left - 1);
    expect(column.right).toBeLessThanOrEqual(metrics.shellRect.right + 1);
    expect(column.left).toBeGreaterThanOrEqual(metrics.footerRect.left - 1);
    expect(column.right).toBeLessThanOrEqual(metrics.footerRect.right + 1);
  }

  return metrics;
}

test("1024px shared-footer regression keeps every column inside the page", async ({ page }) => {
  const failures = collectRuntimeFailures(page);
  await page.setViewportSize({ width: 1024, height: 900 });
  await loadPage(page, "/solo-boating-safety-guide/");
  const metrics = await expectFooterContained(page, 1024);
  expect(metrics.distinctColumnLefts).toBe(2);
  expect(failures).toEqual([]);
});

test("intermediate widths use the contained two-column footer contract", async ({ page }) => {
  const failures = collectRuntimeFailures(page);
  for (const width of [861, 900, 950, 1024, 1050, 1100]) {
    await page.setViewportSize({ width, height: 900 });
    await loadPage(page, "/solo-boating-safety-guide/");
    const metrics = await expectFooterContained(page, width);
    expect(metrics.distinctColumnLefts, `${width}px`).toBe(2);
  }
  expect(failures).toEqual([]);
});

test("mobile footer remains one column with visible keyboard focus", async ({ page }) => {
  const failures = collectRuntimeFailures(page);
  await page.setViewportSize({ width: 390, height: 844 });
  await loadPage(page, "/solo-boating-safety-guide/");
  const metrics = await expectFooterContained(page, 390);
  expect(metrics.distinctColumnLefts).toBe(1);

  const firstLink = page.locator(".fpw-site-footer a[href]").first();
  await firstLink.focus();
  await expect(firstLink).toBeFocused();
  const focusState = await firstLink.evaluate((element) => {
    const style = getComputedStyle(element);
    const rect = element.getBoundingClientRect();
    return {
      visible: rect.width > 0 && rect.height > 0,
      contained: rect.left >= -1 && rect.right <= window.innerWidth + 1,
      hasFocusIndicator: style.outlineStyle !== "none" || style.boxShadow !== "none"
    };
  });
  expect(focusState).toEqual({ visible: true, contained: true, hasFocusIndicator: true });
  expect(failures).toEqual([]);
});

test("desktop footer preserves four columns", async ({ page }) => {
  const failures = collectRuntimeFailures(page);
  await page.setViewportSize({ width: 1440, height: 900 });
  await loadPage(page, "/solo-boating-safety-guide/");
  const metrics = await expectFooterContained(page, 1440);
  expect(metrics.distinctColumnLefts).toBe(4);
  expect(metrics.distinctRows).toBe(1);
  expect(failures).toEqual([]);
});

test("representative shared-footer pages remain contained across required widths", async ({ page }) => {
  const failures = collectRuntimeFailures(page);
  for (const [name, path] of representativePages) {
    for (const width of [390, 760, 1024, 1440]) {
      await page.setViewportSize({ width, height: width === 390 ? 844 : 900 });
      await loadPage(page, path);
      await expectFooterContained(page, width);
    }
    await expect(page.locator(".fpw-site-footer"), name).toBeVisible();
  }
  expect(failures).toEqual([]);
});
