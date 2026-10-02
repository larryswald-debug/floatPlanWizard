const { test, expect } = require("@playwright/test");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

// Opt-in local integration only. Retains ONE fixture across reruns; root coordinates cleanup.
test.skip(process.env.FPW_AUTH_LIVE !== "1", "Requires explicit local database and MailHog authorization.");
test.use({ viewport: { width: 1440, height: 1100 } });
const BASE = "http://localhost:8500/fpw";
const MAIL = "http://localhost:8025";
const statePath = process.env.FPW_AUTH_STATE_FILE || path.resolve(__dirname, "../../../backups/unified-auth/dedicated-fixture.json");
const passwords = { initial: "CodexInitial!2026", changed: "CodexChanged!2026", reset: "CodexReset!2026", other: "CodexOtherBrowser!2026" };
function save(state) {
  fs.mkdirSync(path.dirname(statePath), { recursive: true });
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2) + "\n");
}
function matchesAction(response, file, action) {
  if (!response.url().includes("/api/v1/" + file + ".cfc") || response.request().method() !== "POST") return false;
  try { return response.request().postDataJSON().action === action; } catch (_) { return false; }
}
async function submitAction(page, file, action, button) {
  // Fetch the real server response before forwarding it unchanged, avoiding Chromium's
  // response-body eviction when the application immediately navigates after logout/signup.
  const pattern = "**/api/v1/" + file + ".cfc?*";
  let resolveResponse, rejectResponse;
  const response = new Promise((resolve, reject) => { resolveResponse = resolve; rejectResponse = reject; });
  const deadline = setTimeout(() => rejectResponse(new Error("No server response for " + file + ":" + action)), 30000);
  const handler = async route => {
    let payload;
    try { payload = route.request().postDataJSON(); } catch (_) {}
    if (route.request().method() !== "POST" || (action && (!payload || payload.action !== action))) {
      await route.continue();
      return;
    }
    try {
      const serverResponse = await route.fetch();
      const data = await serverResponse.json();
      await route.fulfill({ response: serverResponse });
      resolveResponse(data);
    } catch (error) { rejectResponse(error); await route.abort(); }
  };
  await page.route(pattern, handler);
  try { await button.click(); return await response; }
  finally { clearTimeout(deadline); await page.unroute(pattern, handler); }
}
async function login(page, email, password, url = BASE + "/app/login.cfm") {
  await page.goto(url);
  await page.locator("#email").fill(email);
  await page.locator("#password").fill(password);
  return submitAction(page, "auth", "login", page.locator("#loginButton"));
}
async function logout(page) {
  const result = await submitAction(page, "auth", "logout", page.locator(".fpw-logout-direct"));
  expect(result.SUCCESS).toBe(true);
  await expect(page).toHaveURL(BASE + "/index.cfm");
}
async function ownMail(request, email) {
  const result = await request.get(MAIL + "/api/v2/search?kind=to&query=" + encodeURIComponent(email));
  expect(result.ok()).toBe(true);
  const data = await result.json();
  const items = data.items || [];
  for (const item of items) {
    expect(item.To.length).toBe(1);
    expect((item.To[0].Mailbox + "@" + item.To[0].Domain).toLowerCase()).toBe(email);
  }
  return items;
}
function mailBodies(node) {
  if (!node || typeof node !== "object") return [];
  const encoding = node.Headers && node.Headers["Content-Transfer-Encoding"];
  const body = encoding && String(encoding).toLowerCase().includes("quoted-printable") ? decodeMail(node.Body || "") : String(node.Body || "").replace(/&amp;/g, "&");
  return (typeof node.Body === "string" ? [body] : []).concat(
    Object.values(node).flatMap(value => typeof value === "object" ? mailBodies(value) : [])
  );
}
function decodeMail(text) {
  return text.replace(/=\r?\n/g, "").replace(/=([0-9A-F]{2})/gi, (_, hex) => String.fromCharCode(parseInt(hex, 16)))
    .replace(/&amp;/g, "&");
}

test("dedicated auth live: optional signup, identity, password lifecycle and recovery continuation", async ({ page, request }, testInfo) => {
  test.setTimeout(180000);
  const previous = fs.existsSync(statePath) ? JSON.parse(fs.readFileSync(statePath, "utf8")) : null;
  const state = previous && !previous.cleaned ? previous : {
    email: "codex-auth-dedicated-" + crypto.randomUUID() + "@example.test",
    created: false, passwordStage: "initial", profileSaved: false, mailIds: [], steps: []
  };
  expect(state.email).toMatch(/^codex-auth-dedicated-[a-f0-9-]+@example\.test$/);
  save(state);
  console.log("DEDICATED_FIXTURE", JSON.stringify({ email: state.email, userId: state.userId || null, created: state.created }));
  const dialogs = [];
  page.on("dialog", async dialog => { dialogs.push(dialog.message()); await dialog.accept(); });
  const mark = label => { if (!state.steps.includes(label)) state.steps.push(label); save(state); console.log("DEDICATED_STEP", label); };
  try {
    const mailHealth = await request.get(MAIL + "/api/v2/search?kind=to&query=" + encodeURIComponent(state.email));
    expect(mailHealth.ok()).toBe(true);
    expect((await mailHealth.json()).items).toBeInstanceOf(Array);
    if (!state.created) {
      await page.goto(BASE + "/app/join.cfm");
      await expect(page.locator("#firstName")).not.toHaveAttribute("required");
      await expect(page.locator("#lastName")).not.toHaveAttribute("required");
      await page.locator("#email").fill(state.email);
      await page.locator("#password").fill(passwords.initial);
      await page.locator("#confirmPassword").fill(passwords.initial);
      await page.locator("#termsAccepted").check();
      const signup = await submitAction(page, "join", "", page.locator("#joinButton"));
      expect(signup.SUCCESS, JSON.stringify(signup)).toBe(true);
      expect(signup.AUTH).toBe(true);
      expect(Number(signup.USERID)).toBeGreaterThan(0);
      state.created = true;
      state.userId = Number(signup.USERID);
      save(state);
      await expect(page).toHaveURL(/\/app\/dashboard\.cfm(?:\?|$)/);
      await expect(page.locator("body")).toHaveAttribute("data-auth-overview", "true");
      await expect(page.locator("#dashboardGettingStartedPanel")).toBeVisible();
      await expect(page.locator(".modal.show")).toHaveCount(0);
      await expect(page.locator("[data-fpw-member-identity]")).toHaveText(state.email);
      mark("blank-name dedicated signup lands on Getting Started without a modal");
    } else {
      const signedIn = await login(page, state.email, passwords[state.passwordStage]);
      expect(signedIn.SUCCESS).toBe(true);
      expect(signedIn.AUTH).toBe(true);
      await expect(page).toHaveURL(/\/app\/dashboard\.cfm(?:\?|$)/);
    }

    await page.goto(BASE + "/app/account.cfm");
    await expect(page.locator("#emailDisplay")).toHaveText(state.email);
    if (!state.profileSaved) {
      await expect(page.locator("#fName")).toHaveValue("");
      await expect(page.locator("#lName")).toHaveValue("");
      await page.locator("#fName").fill("Alyx");
      await page.locator("#lName").fill("Proof");
      const profile = await submitAction(page, "profile", "update", page.locator("#saveProfileBtn"));
      expect(profile.SUCCESS, JSON.stringify(profile)).toBe(true);
      await expect(page.locator("[data-fpw-member-identity]")).toHaveText("Alyx Proof");
      state.profileSaved = true;
      mark("profile save updates nav identity immediately");
    }
    await page.reload();
    await expect(page.locator("[data-fpw-member-identity]")).toHaveText("Alyx Proof");
    await expect(page.locator("#emailDisplay")).toHaveText(state.email);
    if (state.passwordStage === "initial") {
      await page.locator("#currentPassword").fill(passwords.initial);
      await page.locator("#newPassword").fill(passwords.changed);
      await page.locator("#confirmPassword").fill(passwords.changed);
      const changed = await submitAction(page, "profile", "changePassword", page.locator("#changePwBtn"));
      expect(changed.SUCCESS, JSON.stringify(changed)).toBe(true);
      state.passwordStage = "changed";
      mark("account password change succeeds");
    }
    await logout(page);
    await page.goto(BASE + "/app/account.cfm");
    await expect(page).toHaveURL(BASE + "/index.cfm?notice=member-required");
    mark("logout removes protected access");
    const wrong = await login(page, state.email, "CodexWrong!2026");
    expect(wrong.SUCCESS).toBe(false);
    await expect(page.locator("#loginAlert")).toBeVisible();
    await expect(page).toHaveURL(/\/app\/login\.cfm/);
    const right = await login(page, state.email, passwords[state.passwordStage]);
    expect(right.SUCCESS, JSON.stringify(right)).toBe(true);
    expect(right.AUTH).toBe(true);
    await expect(page).toHaveURL(/\/app\/dashboard\.cfm(?:\?|$)/);
    mark("wrong password rejected and correct dedicated login succeeds");
    await logout(page);

    await page.goto(BASE + "/great-loop/trip-planning/");
    const intent = await page.evaluate(() => window.Api.authBootstrap({
      destinationKey: "planner", context: {},
      source: { source_page: "great_loop_trip_planning", section: "daily_decisions", cta_type: "plan_trip", label: "Start Planning" }
    }));
    expect(intent.SUCCESS).toBe(true);
    expect(intent.INTENT_TOKEN).toMatch(/^[a-f0-9]{64}$/);
    await page.goto(new URL(intent.LOGIN_URL, BASE).href);
    await expect(page.locator("#loginForm")).toHaveAttribute("data-auth-intent", intent.INTENT_TOKEN);
    await expect(page.locator('a[href*="/app/forgot-password.cfm"]')).toHaveAttribute("href", "/fpw/app/forgot-password.cfm?authIntent=" + intent.INTENT_TOKEN);
    await expect(page.locator('a[href*="/app/join.cfm"]').first()).toHaveAttribute("href", "/fpw/app/join.cfm?authIntent=" + intent.INTENT_TOKEN);
    await page.locator('a[href*="/app/forgot-password.cfm"]').click();
    const before = (await ownMail(request, state.email)).map(item => item.ID);
    await page.locator("#email").fill(state.email);
    const resetRequested = await submitAction(page, "password_reset", "request", page.locator("#sendBtn"));
    expect(resetRequested.SUCCESS, JSON.stringify(resetRequested)).toBe(true);
    await expect(page.locator("#fpAlert")).toHaveClass(/alert-success/);
    let captured = [];
    await expect.poll(async () => {
      captured = (await ownMail(request, state.email)).filter(item => !before.includes(item.ID));
      return captured.length;
    }, { timeout: 15000 }).toBe(1);
    const message = captured[0];
    if (!state.mailIds.includes(message.ID)) state.mailIds.push(message.ID);
    save(state);
    const full = await (await request.get(MAIL + "/api/v1/messages/" + encodeURIComponent(message.ID))).json();
    const bodies = mailBodies(full).join("\n");
    const resetMatch = bodies.match(/https?:\/\/localhost:8500\/fpw\/app\/reset-password\.cfm\?token=[A-Za-z0-9_-]+(?:&continuationToken=[a-f0-9]{64})?/i);
    expect(resetMatch, "Captured fixture email must contain a local reset link").not.toBeNull();
    const resetUrl = resetMatch[0];
    expect(new URL(resetUrl).searchParams.get("continuationToken")).toBe(intent.INTENT_TOKEN);
    await page.goto(resetUrl);
    await expect(page.locator("#resetBtn")).toBeEnabled();
    await page.locator("#newPassword").fill(passwords.reset);
    await page.locator("#confirmPassword").fill(passwords.reset);
    const reset = await submitAction(page, "password_reset", "confirm", page.locator("#resetBtn"));
    expect(reset.SUCCESS, JSON.stringify(reset)).toBe(true);
    state.passwordStage = "reset";
    mark("MailHog-only forgot/reset preserves the same-session planner intent");
    await expect(page).toHaveURL(BASE + "/app/login.cfm?authIntent=" + intent.INTENT_TOKEN);
    await expect(page.locator("#loginForm")).toHaveAttribute("data-auth-intent", intent.INTENT_TOKEN);
    const restored = await login(page, state.email, passwords.reset, page.url());
    expect(restored.SUCCESS, JSON.stringify(restored)).toBe(true);
    expect(restored.AUTH).toBe(true);
    expect(restored.REDIRECT_URL).toContain("authIntent=" + intent.INTENT_TOKEN);
    await expect(page).toHaveURL(/\/app\/dashboard\.cfm/);
    await expect(page.locator("#authContinuationPanel")).toBeVisible();
    await expect(page.locator(".modal.show")).toHaveCount(0);
    mark("reset login returns to the original planner goal with readiness preserved");

    const replayPage = await page.context().newPage();
    const replayValidation = replayPage.waitForResponse(r => matchesAction(r, "password_reset", "validate"));
    await replayPage.goto(resetUrl);
    const replay = await (await replayValidation).json();
    expect(replay.SUCCESS).toBe(false);
    expect(replay.ERROR).toBe("INVALID_OR_EXPIRED_LINK");
    await expect(replayPage.locator("#resetBtn")).toBeDisabled();
    const replayConfirm = await replayPage.evaluate(async ({ url }) => {
      const csrf = await window.Api.authBootstrap();
      const result = await fetch(window.FPW_API_BASE + "/password_reset.cfc?method=handle", {
        method: "POST", headers: { "Content-Type": "application/json", "X-CSRF-Token": csrf.CSRF_TOKEN },
        body: JSON.stringify({ action: "confirm", token: new URL(url).searchParams.get("token"), newPassword: "DoNotApply!2026" })
      });
      return result.json();
    }, { url: resetUrl });
    expect(replayConfirm.SUCCESS).toBe(false);
    expect(replayConfirm.ERROR).toBe("INVALID_OR_EXPIRED_LINK");
    await replayPage.close();
    mark("reset token replay rejected by both UI validation and confirm API");
    await logout(page);
    const finalLogin = await login(page, state.email, passwords.reset);
    expect(finalLogin.SUCCESS).toBe(true);
    expect(finalLogin.AUTH).toBe(true);
    await expect(page).toHaveURL(/\/app\/dashboard\.cfm/);
    mark("replay does not replace the reset password");
    state.complete = true;
    save(state);
  } finally {
    state.mailIds = [...new Set(state.mailIds.concat((await ownMail(request, state.email)).map(item => item.ID)))];
    save(state);
    const report = { email: state.email, userId: state.userId, complete: !!state.complete, steps: state.steps, mailIds: state.mailIds, dialogs };
    console.log("DEDICATED_RESULT", JSON.stringify(report));
    await testInfo.attach("dedicated-auth-fixture-report", { body: JSON.stringify(report, null, 2), contentType: "application/json" });
  }
});

test("dedicated auth live: another-browser reset, session cookies and current-password checks", async ({ page, browser, request }, testInfo) => {
  test.setTimeout(120000);
  expect(fs.existsSync(statePath), "Resume the canonical dedicated fixture").toBe(true);
  const state = JSON.parse(fs.readFileSync(statePath, "utf8"));
  expect(state.created && Number(state.userId) > 0).toBe(true);
  const mark = label => { if (!state.steps.includes(label)) state.steps.push(label); save(state); console.log("DEDICATED_STEP", label); };
  const beforePassword = passwords[state.otherBrowserPriorPasswordStage || state.passwordStage];
  let otherContext;
  try {
    let intentToken = state.otherBrowserIntentToken || "";
    let resetUrl = state.otherBrowserResetUrl || "";
    if (!state.otherBrowserResetComplete) {
      await page.goto(BASE + "/great-loop/trip-planning/");
      const intent = await page.evaluate(() => window.Api.authBootstrap({ destinationKey: "planner" }));
      expect(intent.SUCCESS).toBe(true);
      intentToken = intent.INTENT_TOKEN;
      const before = (await ownMail(request, state.email)).map(item => item.ID);
      await page.goto(BASE + "/app/forgot-password.cfm?authIntent=" + intentToken);
      await page.locator("#email").fill(state.email);
      const requested = await submitAction(page, "password_reset", "request", page.locator("#sendBtn"));
      expect(requested.SUCCESS, JSON.stringify(requested)).toBe(true);
      let captured = [];
      await expect.poll(async () => {
        captured = (await ownMail(request, state.email)).filter(item => !before.includes(item.ID));
        return captured.length;
      }, { timeout: 15000 }).toBe(1);
      const full = await (await request.get(MAIL + "/api/v1/messages/" + encodeURIComponent(captured[0].ID))).json();
      state.mailIds.push(captured[0].ID); save(state);
      const resetMatch = mailBodies(full).join("\n").match(/https?:\/\/localhost:8500\/fpw\/app\/reset-password\.cfm\?token=[A-Za-z0-9_-]+(?:&continuationToken=[a-f0-9]{64})?/i);
      expect(resetMatch).not.toBeNull();
      resetUrl = resetMatch[0];
      expect(new URL(resetUrl).searchParams.get("continuationToken")).toBe(intentToken);
      state.otherBrowserIntentToken = intentToken;
      state.otherBrowserResetUrl = resetUrl;
      state.otherBrowserPriorPasswordStage = state.passwordStage;
      save(state);
    }
    otherContext = await browser.newContext({ viewport: { width: 1440, height: 1100 } });
    const other = await otherContext.newPage();
    if (!state.otherBrowserResetComplete) {
      const validation = other.waitForResponse(response => matchesAction(response, "password_reset", "validate"));
      await other.goto(resetUrl);
      expect((await (await validation).json()).SUCCESS).toBe(true);
      await expect(other.locator('a[href*="/app/login.cfm"]')).toHaveAttribute("href", "/fpw/app/login.cfm");
      await other.locator("#newPassword").fill(passwords.other);
      await other.locator("#confirmPassword").fill(passwords.other);
      const reset = await submitAction(other, "password_reset", "confirm", other.locator("#resetBtn"));
      expect(reset.SUCCESS, JSON.stringify(reset)).toBe(true);
      state.passwordStage = "other"; state.otherBrowserResetComplete = true; save(state);
      await expect(other).toHaveURL(/\/app\/login\.cfm/);
    } else {
      await other.goto(BASE + "/app/login.cfm?authIntent=" + intentToken);
    }
    await expect(other.locator("#loginForm")).toHaveAttribute("data-auth-intent", "");
    const sessionCookies = async () => (await otherContext.cookies()).filter(cookie => /^(JSESSIONID|CFID|CFTOKEN)$/i.test(cookie.name)).sort((a,b) => a.name.localeCompare(b.name));
    const beforeCookies = await sessionCookies();
    expect(beforeCookies.length).toBeGreaterThan(0);
    const signedIn = await login(other, state.email, passwords.other, other.url());
    expect(signedIn.SUCCESS, JSON.stringify(signedIn)).toBe(true);
    expect(signedIn.AUTH).toBe(true);
    expect(signedIn.REDIRECT_URL).not.toContain(intentToken);
    await expect(other).toHaveURL(/\/app\/dashboard\.cfm/);
    await expect(other.locator("#authContinuationPanel")).toBeHidden();
    await expect(other.locator("[data-fpw-member-identity]")).toHaveText("Alyx Proof");
    const afterCookies = await sessionCookies();
    expect(afterCookies.map(cookie => cookie.value).join("|")).not.toBe(beforeCookies.map(cookie => cookie.value).join("|"));
    for (const cookie of afterCookies) {
      expect(cookie.httpOnly).toBe(true);
      expect(cookie.sameSite).toBe("Lax");
      expect(cookie.secure).toBe(false);
    }
    state.cookieEvidence = { rotated: true, cookies: afterCookies.map(({ value, ...metadata }) => metadata) };
    mark("another-browser reset succeeds while the original session-bound planner intent is ignored");
    mark("actual local session cookies rotate at login and are HttpOnly, SameSite Lax, non-Secure on local HTTP");
    await logout(other);
    const oldPassword = await login(other, state.email, beforePassword);
    expect(oldPassword.SUCCESS).toBe(false);
    const newPassword = await login(other, state.email, passwords.other);
    expect(newPassword.SUCCESS).toBe(true);
    await expect(other).toHaveURL(/\/app\/dashboard\.cfm/);
    await other.goto(BASE + "/app/account.cfm");
    await other.locator("#currentPassword").fill("WrongCurrent!2026");
    await other.locator("#newPassword").fill(passwords.changed);
    await other.locator("#confirmPassword").fill(passwords.changed);
    const rejected = await submitAction(other, "profile", "changePassword", other.locator("#changePwBtn"));
    expect(rejected.SUCCESS).toBe(false);
    await other.locator("#currentPassword").fill(passwords.other);
    const changed = await submitAction(other, "profile", "changePassword", other.locator("#changePwBtn"));
    expect(changed.SUCCESS, JSON.stringify(changed)).toBe(true);
    state.passwordStage = "changed"; save(state);
    await logout(other);
    const final = await login(other, state.email, passwords.changed);
    expect(final.SUCCESS).toBe(true);
    await expect(other).toHaveURL(/\/app\/dashboard\.cfm/);
    mark("old reset password and wrong current password rejected; correct password change and subsequent login succeed");
    state.otherBrowserComplete = true; save(state);
  } finally {
    if (otherContext) await otherContext.close();
    state.mailIds = [...new Set(state.mailIds.concat((await ownMail(request, state.email)).map(item => item.ID)))];
    save(state);
    const report = { userId: state.userId, complete: !!state.otherBrowserComplete, steps: state.steps, cookieEvidence: state.cookieEvidence };
    console.log("DEDICATED_OTHER_BROWSER", JSON.stringify(report));
    await testInfo.attach("dedicated-other-browser-report", { body: JSON.stringify(report, null, 2), contentType: "application/json" });
  }
});
