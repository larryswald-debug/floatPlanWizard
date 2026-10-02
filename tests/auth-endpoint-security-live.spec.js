const { test, expect, request: playwrightRequest } = require("@playwright/test");
const crypto = require("crypto");
const BASE = "http://localhost:8500/fpw";
const FIXTURE = BASE + "/tests/auth-endpoint-security-fixture.cfm?confirm=RUN_AUTH_ENDPOINT_FIXTURES";
test.skip(process.env.FPW_AUTH_LIVE !== "1", "Explicit local database authorization required.");
test.describe.configure({ mode: "serial" });
let runId, users, fixtureContext;
async function fixture(action, extra = {}) {
  const response = await fixtureContext.post(FIXTURE, { data: { action, runId, ...extra } });
  expect(response.ok(), await response.text()).toBe(true);
  return response.json();
}
async function bootstrap(context) {
  const response = await context.get(BASE + "/api/v1/auth.cfc?method=bootstrap");
  expect(response.ok()).toBe(true);
  expect(response.headers()["cache-control"]).toContain("no-store");
  return response.json();
}
async function submit(context, data, extra = {}) {
  const boot = await bootstrap(context);
  return context.post(BASE + "/api/v1/auth.cfc?method=handle", {
    data, headers: { "X-CSRF-Token": boot.CSRF_TOKEN, ...extra }
  });
}
async function login(context, member, action = "login", password = member.PASSWORD) {
  return submit(context, { action, email: member.EMAIL, password });
}
async function state(actionGroup = "authenticate") { return (await fixture("state", { actionGroup })).USERS; }

test.beforeAll(async () => {
  runId = crypto.randomUUID().replace(/-/g, "");
  fixtureContext = await playwrightRequest.newContext();
  users = (await fixture("setup")).USERS;
  console.log("AUTH_ENDPOINT_FIXTURE_IDS", Object.values(users).map(user => user.ID).join(","));
});
test.afterAll(async () => {
  if (users) expect((await fixture("cleanup")).CLEANED).toBe(true);
  await fixtureContext?.dispose();
});

test("mutations reject missing/stale CSRF, wrong method and mismatched origin before admission", async ({ request }) => {
  const boot = await bootstrap(request);
  const data = { action: "login", email: users["sha"].EMAIL, password: users["sha"].PASSWORD };
  const noCsrf = await request.post(BASE + "/api/v1/auth.cfc?method=handle", { data });
  expect(noCsrf.status()).toBe(403);
  expect((await noCsrf.json()).ERROR).toBe("CSRF_INVALID");
  const method = await request.get(BASE + "/api/v1/auth.cfc?method=handle");
  expect(method.status()).toBe(405);
  const foreign = await request.post(BASE + "/api/v1/auth.cfc?method=handle", {
    data, headers: { "X-CSRF-Token": boot.CSRF_TOKEN, Origin: "https://attacker.example" }
  });
  expect(foreign.status()).toBe(403);
  for (const file of ["join", "password_reset"]) {
    const response = await request.post(BASE + "/api/v1/" + file + ".cfc?method=handle", { data: { action: "request", email: users["sha"].EMAIL } });
    expect(response.status()).toBe(403);
    expect((await response.json()).ERROR).toBe("CSRF_INVALID");
  }
  expect((await state())["sha"].ADMITTED).toBe(0);
});

test("SHA login upgrades atomically, preserves passwordCreated, rotates session and releases successful counters", async ({ request }) => {
  const boot = await bootstrap(request);
  const cookiesBefore = (await request.storageState()).cookies;
  const response = await request.post(BASE + "/api/v1/auth.cfc?method=handle", {
    data: { action: "login", email: users["sha"].EMAIL, password: users["sha"].PASSWORD },
    headers: { "X-CSRF-Token": boot.CSRF_TOKEN, "CF-Connecting-IP": "198.51.100.244", "X-Forwarded-For": "198.51.100.245" }
  });
  const result = await response.json();
  expect(result.SUCCESS, JSON.stringify(result)).toBe(true);
  expect(result.AUTH).toBe(true);
  expect(result.ACCOUNT_CREATED).toBe(false);
  const cookiesAfter = (await request.storageState()).cookies;
  const beforeSession = cookiesBefore.filter(c => /^(CFID|CFTOKEN|JSESSIONID)$/i.test(c.name));
  const afterSession = cookiesAfter.filter(c => /^(CFID|CFTOKEN|JSESSIONID)$/i.test(c.name));
  expect(beforeSession.length).toBeGreaterThan(0);
  expect(JSON.stringify(afterSession.map(c => [c.name, c.value]))).not.toBe(JSON.stringify(beforeSession.map(c => [c.name, c.value])));
  const row = (await state())["sha"];
  expect(row.FORMAT).toBe("ADAPTIVE");
  expect(row.PASSWORDCREATED).toBe("2000-01-01 00:00:00");
  expect(row.INFLIGHT).toBe(0);
  expect(row.FAILURES).toBe(0);
  const stale = await request.post(BASE + "/api/v1/auth.cfc?method=handle", {
    data: { action: "logout" }, headers: { "X-CSRF-Token": boot.CSRF_TOKEN }
  });
  expect(stale.status()).toBe(403);
  const forwarded = await fixtureContext.post(FIXTURE, {
    data: { action: "state", runId }, headers: { "CF-Connecting-IP": "198.51.100.244", "X-Forwarded-For": "198.51.100.245" }
  });
  expect((await forwarded.json()).FORWARDED_IGNORED).toBe(true);
});

test("short existing plaintext credential authenticates and migrates to PBKDF2", async ({ request }) => {
  expect(users["plain"].PASSWORD.length).toBeLessThan(8);
  const response = await login(request, users["plain"], "continue");
  expect((await response.json()).AUTH).toBe(true);
  const row = (await state())["plain"];
  expect(row.FORMAT).toBe("ADAPTIVE");
  expect(row.PASSWORDCREATED).toBe("2000-01-01 00:00:00");
  expect(row.INFLIGHT).toBe(0);
});

test("switching members discards the old bound destination and returns a fresh Dashboard intent", async ({ request }) => {
  expect((await (await login(request, users["sha"])).json()).AUTH).toBe(true);
  const intentResponse = await request.get(BASE + "/api/v1/auth.cfc?method=bootstrap&destinationKey=planner");
  const original = await intentResponse.json();
  expect(original.AUTH).toBe(true);
  const switched = await request.post(BASE + "/api/v1/auth.cfc?method=handle", {
    data: { action: "login", email: users["plain"].EMAIL, password: users["plain"].PASSWORD, intentToken: original.INTENT_TOKEN },
    headers: { "X-CSRF-Token": original.CSRF_TOKEN }
  });
  const result = await switched.json();
  expect(result.SUCCESS, JSON.stringify(result)).toBe(true);
  expect(result.AUTH).toBe(true);
  expect(result.USERID).toBe(users["plain"].ID);
  expect(result.INTENT_TOKEN).not.toBe(original.INTENT_TOKEN);
  expect(result.REDIRECT_URL).toContain("/app/dashboard.cfm?authIntent=");
  const expired = await request.get(BASE + "/api/v1/auth.cfc?method=bootstrap&intentToken=" + original.INTENT_TOKEN);
  expect(expired.status()).toBe(400);
  expect((await expired.json()).ERROR).toBe("INTENT_EXPIRED");
  const fresh = await request.get(BASE + "/api/v1/auth.cfc?method=bootstrap&intentToken=" + result.INTENT_TOKEN);
  expect((await fresh.json()).AUTH).toBe(true);
});
test("password changes enforce CSRF/current password and finalize counters at zero", async ({ request }) => {
  expect((await (await login(request, users["change"])).json()).AUTH).toBe(true);
  const boot = await bootstrap(request);
  const url = BASE + "/api/v1/profile.cfc?method=handle";
  const data = { action: "changepassword", currentPassword: users["change"].PASSWORD, newPassword: "Endpoint Replacement Password 77!" };
  expect((await request.post(url, { data })).status()).toBe(403);
  const wrong = await request.post(url, { data: { ...data, currentPassword: "incorrect" }, headers: { "X-CSRF-Token": boot.CSRF_TOKEN } });
  expect((await wrong.json()).ERROR).toBe("BAD_CURRENT_PASSWORD");
  const response = await request.post(url, { data, headers: { "X-CSRF-Token": boot.CSRF_TOKEN } });
  expect((await response.json()).SUCCESS).toBe(true);
  const row = (await state("change_password"))["change"];
  expect(row.ADMITTED).toBe(2);
  expect(row.INFLIGHT).toBe(0);
  expect(row.FAILURES).toBe(0);
  const unauthenticated = await playwrightRequest.newContext();
  try { expect((await (await login(unauthenticated, users["change"], "login", data.newPassword)).json()).AUTH).toBe(true); }
  finally { await unauthenticated.dispose(); }
});

test("login and unified Continue share failed-attempt budget and emit Retry-After", async ({ request }) => {
  for (let attempt = 0; attempt < 10; attempt++) {
    const response = await login(request, users["throttle"], attempt % 2 ? "continue" : "login", "wrong password");
    expect(response.status()).toBe(200);
    expect((await response.json()).ERROR).toBe("INVALID_LOGIN");
  }
  const blocked = await login(request, users["throttle"]);
  expect(blocked.status()).toBe(429);
  expect(Number(blocked.headers()["retry-after"])).toBeGreaterThan(0);
  expect((await blocked.json()).ERROR).toBe("AUTH_RATE_LIMITED");
  const row = (await state())["throttle"];
  expect(row.ADMITTED).toBe(10);
  expect(row.FAILURES).toBe(10);
  expect(row.INFLIGHT).toBe(0);
});
