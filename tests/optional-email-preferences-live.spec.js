const { test, expect } = require("@playwright/test");
const base = "http://localhost:8500/fpw";
const fixtureUrl = base + "/tests/optional-email-preferences-browser-fixture.cfm?confirm=RUN_OPTIONAL_EMAIL_BROWSER_TESTS";
const value = (o, key) => o && (o[key] ?? o[key.toUpperCase()] ?? o[key.toLowerCase()]);
let fixture;

async function command(request, action) {
  const response = await request.post(fixtureUrl, {
    headers: fixture ? { "X-FPW-Optional-Test-Token": value(fixture, "token") } : {},
    data: { action, ...(fixture ? { runKey: value(fixture, "runKey") } : {}) }
  });
  const result = await response.json();
  expect(response.status(), JSON.stringify(result)).toBe(200);
  expect(value(result, "success"), JSON.stringify(result)).toBe(true);
  return result;
}
async function login(page) {
  await page.goto(base + "/app/login.cfm");
  await page.waitForFunction(() => window.Api && window.Api.login);
  const result = await page.evaluate(({ email, password }) => window.Api.login(email, password),
    { email: value(fixture, "email"), password: value(fixture, "password") });
  expect(result.SUCCESS).toBe(true);
  await page.goto(base + "/app/account.cfm#email-preferences");
  await expect(page.locator("#optionalEmailsEnabled")).toBeEnabled();
}
async function saveFromUi(page, enabled) {
  await page.locator("#optionalEmailsEnabled").selectOption(enabled ? "on" : "off");
  const pending = page.waitForResponse(r => r.url().includes("action=update-email-preferences") && r.request().method() === "POST");
  await page.locator("#saveEmailPreferencesBtn").click();
  const response = await pending;
  expect(response.status()).toBe(200);
  expect(response.request().headers()["x-csrf-token"]).toMatch(/^[a-f0-9]{64}$/);
  expect(response.request().postDataJSON()).toEqual({ optionalEmailsEnabled: enabled });
  await expect(page.locator("#emailPreferencesStatus")).toHaveText(enabled ? "Optional emails are turned on." : "Optional emails are turned off.");
}
test.describe.configure({ mode: "serial" });
test.beforeEach(async ({ request }) => { fixture = null; fixture = await command(request, "prepare"); });
test.afterEach(async ({ request }) => {
  if (fixture) {
    const cleaned = await command(request, "cleanup");
    expect(value(cleaned, "optouts")).toBe(0);
    for (const key of ["users", "events", "ledger"]) expect(value(value(cleaned, "remaining"), key)).toBe(0);
    fixture = null;
  }
});

test("signed logged-out unsubscribe rejects tampering and remains idempotent", async ({ browser, request }) => {
  expect(value(await command(request, "state"), "rows")).toBe(0);
  const context = await browser.newContext();
  const page = await context.newPage();
  try {
    const signed = new URL(value(fixture, "unsubscribeUrl"));
    expect(signed.origin).toBe("http://localhost:8500");
    const altered = new URL(signed);
    altered.searchParams.set("t", altered.searchParams.get("t") + "X");
    await page.goto(altered.toString());
    await expect(page.locator("h1")).toHaveText("We Could Not Process This Link");
    expect(value(await command(request, "state"), "rows")).toBe(0);
    const response = await page.goto(signed.toString());
    expect(response.status()).toBe(200);
    await expect(page.locator("h1")).toHaveText("Email Preference Updated");
    let state = await command(request, "state");
    expect(value(state, "rows")).toBe(1);
    expect(value(state, "source")).toBe("unsubscribe_page");
    expect(value(state, "hasCreated")).toBe(1);
    expect(value(state, "hasUpdated")).toBe(1);
    await page.reload();
    await expect(page.locator("h1")).toHaveText("Email Preference Updated");
    expect(value(await command(request, "state"), "rows")).toBe(1);
    await page.goto(altered.toString());
    await expect(page.locator("h1")).toHaveText("We Could Not Process This Link");
    expect(value(await command(request, "state"), "rows")).toBe(1);
  } finally { await context.close(); }
});

test("account OFF and ON persist with authenticated current-address ownership and CSRF", async ({ page, request, browser }) => {
  const endpoint = base + "/api/v1/profile.cfc?method=handle&action=update-email-preferences";
  const anonymous = await browser.newContext();
  try {
    const unauthorized = await anonymous.request.post(endpoint, { data: { optionalEmailsEnabled: false } });
    expect((await unauthorized.json()).AUTH).toBe(false);
    expect(value(await command(request, "state"), "rows")).toBe(0);
  } finally { await anonymous.close(); }
  await login(page);
  await expect(page.locator("#email-preferences")).toBeVisible();
  await expect(page.locator("#optionalEmailsEnabled")).toHaveValue("on");
  const csrf = await page.evaluate(async () => (await window.Api.authBootstrap()).CSRF_TOKEN);
  expect((await page.request.get(endpoint)).status()).toBe(405);
  expect((await page.request.post(endpoint, { data: { optionalEmailsEnabled: false } })).status()).toBe(403);
  expect((await page.request.post(endpoint, { headers: { "X-CSRF-Token": "0".repeat(64) }, data: { optionalEmailsEnabled: false } })).status()).toBe(403);
  expect((await page.request.post(endpoint, { headers: { "X-CSRF-Token": csrf, Origin: "https://unrelated.invalid" }, data: { optionalEmailsEnabled: false } })).status()).toBe(403);
  for (const data of [
    { optionalEmailsEnabled: false, email: "unrelated@example.test" },
    { optionalEmailsEnabled: false, userId: 1 },
    { optionalEmailsEnabled: "false" },
    { optionalEmailsEnabled: null },
    { optionalEmailsEnabled: {} }
  ]) {
    expect((await page.request.post(endpoint, { headers: { "X-CSRF-Token": csrf }, data })).status()).toBe(400);
  }
  expect(value(await command(request, "state"), "rows")).toBe(0);
  await saveFromUi(page, false);
  let state = await command(request, "state");
  expect(value(state, "rows")).toBe(1);
  expect(value(state, "source")).toBe("account_preferences");
  expect(value(state, "eligibility")).toBe("OPTED_OUT");
  await page.reload();
  await expect(page.locator("#optionalEmailsEnabled")).toBeEnabled();
  await expect(page.locator("#optionalEmailsEnabled")).toHaveValue("off");
  await saveFromUi(page, false);
  expect(value(await command(request, "state"), "rows")).toBe(1);
  await saveFromUi(page, true);
  state = await command(request, "state");
  expect(value(state, "rows")).toBe(0);
  expect(value(state, "eligibility")).toBe("ELIGIBLE");
  await page.reload();
  await expect(page.locator("#optionalEmailsEnabled")).toBeEnabled();
  await expect(page.locator("#optionalEmailsEnabled")).toHaveValue("on");
  await page.setViewportSize({ width: 390, height: 844 });
  await page.locator("#email-preferences").scrollIntoViewIfNeeded();
  await expect(page.locator("#saveEmailPreferencesBtn")).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
});

test("account OFF blocks recovery transport and ON restores the normally eligible send", async ({ page, request }) => {
  await login(page);
  await saveFromUi(page, false);
  let result = await command(request, "recovery");
  expect(value(value(result, "result"), "reasons").SUPPRESSED_OPTED_OUT).toBe(1);
  expect(value(result, "attempts")).toBe(0);
  await saveFromUi(page, true);
  result = await command(request, "recovery");
  expect(value(value(result, "result"), "submitted")).toBe(1);
  expect(value(result, "attempts")).toBe(1);
});
