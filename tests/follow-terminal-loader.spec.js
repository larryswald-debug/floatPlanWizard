const { test, expect } = require("@playwright/test");

const baseUrl = process.env.FPW_BASE_URL || "http://localhost:8500/fpw";
const fixturePath = "/tests/follow-terminal-loader-browser-fixture.cfm";
const confirmation = "RUN_FOLLOW_TERMINAL_LOADER_BROWSER_FIXTURE";
let fixture = null;

function fixtureUrl(action) {
  return `${baseUrl}${fixturePath}?action=${encodeURIComponent(action)}&confirm=${confirmation}`;
}

function followUrl(slug, token) {
  const params = new URLSearchParams({ slug, t: token });
  return `${baseUrl}/app/follow.cfm?${params.toString()}`;
}

function collectRuntimeFailures(page) {
  const failures = [];
  page.on("console", (message) => {
    if (message.type() === "error") failures.push(`console: ${message.text()}`);
  });
  page.on("pageerror", (error) => failures.push(`pageerror: ${error.message}`));
  page.on("requestfailed", (request) => {
    if (request.url().startsWith(baseUrl)) {
      failures.push(`requestfailed: ${request.method()} ${request.url()}`);
    }
  });
  page.on("response", (response) => {
    if (response.url().startsWith(baseUrl) && response.status() >= 500) {
      failures.push(`http-${response.status()}: ${response.url()}`);
    }
  });
  return failures;
}

async function expectTerminalState(page, expectedMessage) {
  const terminal = page.locator("#followTerminalError");
  await expect(terminal).toBeVisible();
  await expect(page.locator("#followTerminalErrorHeading")).toHaveText("Trip Page Unavailable");
  await expect(page.locator("#followTerminalErrorMessage")).toContainText(expectedMessage);
  await expect(page.locator("#followLoader")).toBeHidden();
  await expect(page.locator("#followLoaderPercent")).toBeHidden();
  await expect(page.locator("#followLoaderBar")).toBeHidden();
  await expect(page.locator(".app")).toBeHidden();
  await expect(page.locator("#followTerminalErrorHeading")).toBeFocused();

  const state = await page.evaluate(() => ({
    followLoading: document.body.classList.contains("follow-loading"),
    loadError: document.body.classList.contains("follow-load-error"),
    loaderAriaHidden: document.getElementById("followLoader").getAttribute("aria-hidden"),
    terminalRole: document.getElementById("followTerminalError").getAttribute("role"),
    terminalFocused: document.activeElement === document.getElementById("followTerminalErrorHeading"),
    bodyBusy: document.body.getAttribute("aria-busy"),
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth
  }));
  expect(state.followLoading).toBe(false);
  expect(state.loadError).toBe(true);
  expect(state.loaderAriaHidden).toBe("true");
  expect(state.terminalRole).toBe("alert");
  expect(state.terminalFocused).toBe(true);
  expect(state.bodyBusy).toBeNull();
  expect(state.scrollWidth).toBeLessThanOrEqual(state.clientWidth);
}

test.describe.serial("QA6-002 Follow terminal loader", () => {
  test.beforeAll(async ({ request }) => {
    const response = await request.get(fixtureUrl("setup"));
    expect(response.status()).toBe(200);
    fixture = await response.json();
    expect(fixture.SUCCESS).toBe(true);
    expect(fixture.SNAPSHOT.FIXTURE_STREAM_COUNT).toBe(2);
  });

  test.afterAll(async ({ request }) => {
    const response = await request.get(fixtureUrl("cleanup"));
    expect(response.status()).toBe(200);
    const payload = await response.json();
    expect(payload.SUCCESS).toBe(true);
  });

  test("valid Follow completes normally", async ({ page }) => {
    const failures = collectRuntimeFailures(page);
    let bootstrapCount = 0;
    page.on("request", (request) => {
      if (request.url().includes("action=getStreamBootstrap")) bootstrapCount += 1;
    });

    const response = await page.goto(`${baseUrl}${fixture.ACTIVE.URL}`, { waitUntil: "domcontentloaded" });
    expect(response.status()).toBe(200);
    await page.waitForFunction(() => !document.body.classList.contains("follow-loading"));
    await expect(page.locator("#followLoader")).toBeHidden();
    await expect(page.locator("#followTerminalError")).toBeHidden();
    await expect(page.locator(".app")).toBeVisible();
    await expect(page.locator('[data-fpw-field="page-title"]')).not.toHaveText("—");
    await expect(page.locator("#followMap")).toHaveClass(/leaflet-container/);
    expect(await page.evaluate(() => document.body.classList.contains("follow-load-error"))).toBe(false);
    expect(bootstrapCount).toBe(1);
    expect(failures).toEqual([]);
  });

  test("invalid token reaches a stable mobile terminal state", async ({ page }) => {
    const failures = collectRuntimeFailures(page);
    let bootstrapCount = 0;
    page.on("request", (request) => {
      if (request.url().includes("action=getStreamBootstrap")) bootstrapCount += 1;
    });
    await page.setViewportSize({ width: 390, height: 844 });

    const response = await page.goto(
      followUrl(fixture.ACTIVE.SLUG, "f".repeat(64)),
      { waitUntil: "domcontentloaded" }
    );
    expect(response.status()).toBe(200);
    await expectTerminalState(page, "A valid share token is required for this stream.");
    await page.waitForTimeout(500);
    expect(bootstrapCount).toBe(1);
    expect(failures).toEqual([]);
  });

  test("unknown slug remains terminal across refresh and reopen", async ({ page }) => {
    const failures = collectRuntimeFailures(page);
    let bootstrapCount = 0;
    page.on("request", (request) => {
      if (request.url().includes("action=getStreamBootstrap")) bootstrapCount += 1;
    });
    const url = followUrl(`${fixture.ACTIVE.SLUG}-unknown`, fixture.ACTIVE.TOKEN);
    await page.setViewportSize({ width: 390, height: 844 });

    await page.goto(url, { waitUntil: "domcontentloaded" });
    await expectTerminalState(page, "No voyage stream matched the provided slug or stream id.");
    await page.reload({ waitUntil: "domcontentloaded" });
    await expectTerminalState(page, "No voyage stream matched the provided slug or stream id.");
    await page.goto("about:blank");
    await page.goto(url, { waitUntil: "domcontentloaded" });
    await expectTerminalState(page, "No voyage stream matched the provided slug or stream id.");
    expect(bootstrapCount).toBe(3);
    expect(failures).toEqual([]);
  });

  test("ended Follow access reaches terminal state without writes", async ({ page, request }) => {
    const failures = collectRuntimeFailures(page);
    let bootstrapCount = 0;
    page.on("request", (browserRequest) => {
      if (browserRequest.url().includes("action=getStreamBootstrap")) bootstrapCount += 1;
    });
    await page.setViewportSize({ width: 390, height: 844 });

    const beforeResponse = await request.get(fixtureUrl("snapshot"));
    const before = (await beforeResponse.json()).SNAPSHOT;
    const response = await page.goto(`${baseUrl}${fixture.ENDED.URL}`, { waitUntil: "domcontentloaded" });
    expect(response.status()).toBe(200);
    await expectTerminalState(page, "access");
    await page.waitForTimeout(500);
    const afterResponse = await request.get(fixtureUrl("snapshot"));
    const after = (await afterResponse.json()).SNAPSHOT;

    expect(after).toEqual(before);
    expect(bootstrapCount).toBe(1);
    expect(failures).toEqual([]);
  });
});
