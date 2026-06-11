const { expect } = require("@playwright/test");

function attachConsoleErrorCollector(page) {
  const errors = [];

  page.on("console", (msg) => {
    const text = msg.text();
    if (msg.type() === "error" && !String(text || "").startsWith("Failed to load resource")) {
      errors.push(`console:${text}`);
    }
  });

  page.on("pageerror", (error) => {
    errors.push(`pageerror:${error.message}`);
  });

  return errors;
}

async function assertNoConsoleErrors(errors) {
  expect(errors, `Unexpected console or page errors:\n${errors.join("\n")}`).toEqual([]);
}

async function expectHeadingVisible(page, name) {
  await expect(page.getByRole("heading", { name, exact: false })).toBeVisible();
}

async function expectPanelVisible(page, selector) {
  await expect(page.locator(selector)).toBeVisible();
}

async function expectBoxWithinViewport(page, selector) {
  const box = await page.locator(selector).boundingBox();
  expect(box, `Missing bounding box for ${selector}`).not.toBeNull();
  const viewport = page.viewportSize();
  expect(viewport, "Viewport size unavailable").not.toBeNull();
  expect(box.x).toBeGreaterThanOrEqual(0);
  expect(box.y).toBeGreaterThanOrEqual(0);
  expect(box.x + box.width).toBeLessThanOrEqual(viewport.width + 2);
  expect(box.y + box.height).toBeLessThanOrEqual(viewport.height + 2);
}

module.exports = {
  assertNoConsoleErrors,
  attachConsoleErrorCollector,
  expectBoxWithinViewport,
  expectHeadingVisible,
  expectPanelVisible
};
