const { test, expect, request: playwrightRequest } = require("@playwright/test");
const crypto = require("crypto");
const BASE = "http://localhost:8500/fpw";
const FIXTURE = BASE + "/tests/auth-signup-integrity-fixture.cfm?confirm=RUN_AUTH_SIGNUP_FIXTURES";
const MAIL = "http://localhost:8025";
test.skip(process.env.FPW_AUTH_LIVE !== "1", "Explicit local database and MailHog authorization required.");
test.setTimeout(90000);
let runId, fixtureContext, setup;
async function fixture(action) {
  const response = await fixtureContext.post(FIXTURE, { data: { action, runId } });
  expect(response.ok(), await response.text()).toBe(true);
  return response.json();
}
async function bootstrap(context) {
  const response = await context.get(BASE + "/api/v1/auth.cfc?method=bootstrap&destinationKey=planner");
  expect(response.ok()).toBe(true);
  return response.json();
}
async function ownMail() {
  const response = await fixtureContext.get(MAIL + "/api/v2/search?kind=to&query=" + encodeURIComponent(setup.EMAIL));
  expect(response.ok()).toBe(true);
  const messages = (await response.json()).items || [];
  for (const message of messages) {
    expect(message.To).toHaveLength(1);
    expect((message.To[0].Mailbox + "@" + message.To[0].Domain).toLowerCase()).toBe(setup.EMAIL);
  }
  return messages;
}
async function continueRequest(context, boot, revision = boot.DISCLOSURE.REVISION, email = setup.EMAIL) {
  return context.post(BASE + "/api/v1/auth.cfc?method=handle", {
    headers: { "X-CSRF-Token": boot.CSRF_TOKEN },
    data: { action: "continue", email, password: "Disposable Concurrent Signup 42!", intentToken: boot.INTENT_TOKEN, disclosureRevision: revision }
  });
}
function inspect(state, creditModel, acceptanceMethod = "continue_disclosure") {
  expect(state.USER_COUNT).toBe(1);
  expect(state.SIGNUP_COUNT).toBe(1);
  expect(state.ENROLLMENT_COUNT).toBe(1);
  expect(state.CREDIT_COUNT).toBe(creditModel ? 1 : 0);
  expect(state.ENTITLEMENT_COUNT).toBe(0);
  expect(state.FORMAT).toBe("ADAPTIVE");
  expect(state.NAMES_EMPTY).toBe(true);
  const metadata = Object.fromEntries(Object.entries(state.METADATA).map(([key,value]) => [key.toLowerCase(),value]));
  expect(metadata.acceptance_method).toBe(acceptanceMethod);
  expect(metadata.complimentary_premium_send_credit).toBe(creditModel);
  for (const key of ["terms_revision","privacy_revision","disclosure_revision"]) expect(metadata[key]).toMatch(/^[a-f0-9]{64}$/);
  expect(state.COUNTERS.authenticate.INFLIGHT).toBe(0);
  expect(state.COUNTERS.create_account.INFLIGHT).toBe(0);
}
test.beforeEach(async () => {
  runId = crypto.randomUUID().replace(/-/g, "");
  fixtureContext = await playwrightRequest.newContext();
  const safety = await fixtureContext.get(BASE + "/tests/auth-mail-safety-probe.cfm?confirm=READ_AUTH_MAIL_SAFETY");
  expect((await safety.json()).SAFE_LOCAL_MAIL).toBe(true);
  setup = await fixture("setup");
  console.log("SIGNUP_FIXTURE", JSON.stringify({ runId, email: setup.EMAIL, creditModel: setup.CREDIT_MODEL, sessionType: setup.SESSION_TYPE }));
});
test.afterEach(async () => {
  if (setup) {
    const mail = await ownMail();
    for (const message of mail) expect((await fixtureContext.delete(MAIL + "/api/v1/messages/" + encodeURIComponent(message.ID))).ok()).toBe(true);
    expect(await ownMail()).toHaveLength(0);
    const cleanup = await fixture("cleanup");
    expect(cleanup.CLEANED).toBe(true);
    expect(cleanup.CREDIT_MODEL).toBe(setup.CREDIT_MODEL);
    console.log("SIGNUP_CLEANUP", JSON.stringify({ userIds: cleanup.USER_IDS, removedMailCount: mail.length, creditModel: cleanup.CREDIT_MODEL }));
  }
  await fixtureContext?.dispose();
});
test("stale consent and concurrent case-equivalent signup produce exactly one account and provision once", async () => {
  const first = await playwrightRequest.newContext();
  const second = await playwrightRequest.newContext();
  try {
    const one = await bootstrap(first), two = await bootstrap(second);
    const stale = await continueRequest(first, one, "0".repeat(64));
    expect((await stale.json()).ERROR).toBe("CONSENT_UPDATED");
    expect((await fixture("state")).USER_COUNT).toBe(0);
    expect(await ownMail()).toHaveLength(0);
    const requests = await Promise.all([
      continueRequest(first, one), continueRequest(second, two, two.DISCLOSURE.REVISION, setup.EMAIL.toUpperCase())
    ]);
    const results = await Promise.all(requests.map(response => response.json()));
    results.forEach(result => expect(result.SUCCESS, JSON.stringify(result)).toBe(true));
    results.forEach(result => expect(result.AUTH).toBe(true));
    expect(results.filter(result => result.ACCOUNT_CREATED)).toHaveLength(1);
    expect(new Set(results.map(result => result.USERID)).size).toBe(1);
    results.forEach(result => expect(result.REDIRECT_URL).toMatch(/^\/fpw\/app\/dashboard[.]cfm\?authIntent=[a-f0-9]{64}$/));
    inspect(await fixture("state"), setup.CREDIT_MODEL);
    await expect.poll(async () => (await ownMail()).length, { timeout: 45000, intervals: [500, 1000, 2000] }).toBe(1);
  } finally { await first.dispose();await second.dispose(); }
});
test("dedicated Join retains its planner intent across signup and lands on the full overview", async ({ page }) => {
  const context = page.context().request;
  const boot = await bootstrap(context);
  const password = "Disposable Dedicated Intent 42!";
  const response = await context.post(BASE + "/api/v1/join.cfc?method=handle", {
    headers: { "X-CSRF-Token": boot.CSRF_TOKEN },
    data: { email: setup.EMAIL, firstName: "", lastName: "", password, confirmPassword: password,
      termsAccepted: true, disclosureRevision: boot.DISCLOSURE.REVISION, intentToken: boot.INTENT_TOKEN }
  });
  const result = await response.json();
  expect(result.SUCCESS, JSON.stringify(result)).toBe(true);
  expect(result.AUTH).toBe(true);
  expect(new URL(result.REDIRECT_URL, BASE).searchParams.get("authIntent")).toBe(boot.INTENT_TOKEN);
  await page.goto(new URL(result.REDIRECT_URL, BASE).href);
  await expect(page.locator("body")).toHaveAttribute("data-auth-overview", "true");
  await expect(page.locator("#dashboardGettingStartedPanel")).toBeVisible();
  await expect(page.locator("#authContinuationPanel")).toBeVisible();
  await expect(page.locator("#authContinuationBtn")).toBeDisabled();
  await expect(page.locator("#routeBuilderModal")).toBeHidden();
  await expect(page.locator("#vesselModal")).toBeHidden();
  expect(await page.evaluate(() => AppAuth.readHandoff().destinationKey)).toBe("planner");
  inspect(await fixture("state"), setup.CREDIT_MODEL, "dedicated_checkbox");
  await expect.poll(async () => (await ownMail()).length, { timeout: 45000, intervals: [500, 1000, 2000] }).toBe(1);
});
test("alternate credit model keeps signup canonical without a trial or duplicate side effects", async () => {
  test.skip(process.env.FPW_AUTH_ALT_CREDIT !== "1", "Requires coordinated exclusive local credit-flag window.");
  const context = await playwrightRequest.newContext();
  try {
    const toggle = await fixture("toggle-credit");
    expect(toggle.ORIGINAL).toBe(setup.CREDIT_MODEL);
    expect(toggle.CURRENT).toBe(!setup.CREDIT_MODEL);
    const response = await continueRequest(context, await bootstrap(context));
    const result = await response.json();
    expect(result.SUCCESS, JSON.stringify(result)).toBe(true);
    expect(result.AUTH).toBe(true);
    expect(result.ACCOUNT_CREATED).toBe(true);
    inspect(await fixture("state"), !setup.CREDIT_MODEL);
    await expect.poll(async () => (await ownMail()).length, { timeout: 45000, intervals: [500, 1000, 2000] }).toBe(1);
  } finally {
    expect((await fixture("restore-credit")).RESTORED).toBe(setup.CREDIT_MODEL);
    await context.dispose();
  }
});
