const { test, expect } = require("@playwright/test");
const fs = require("node:fs");
const { execFileSync } = require("node:child_process");
test.skip(process.env.FPW_AUTH_LIVE !== "1", "Explicit local database and MailHog authorization required.");
const base = "http://localhost:8500/fpw";
const fixturePath = base + "/tests/member-profile-name-browser-fixture.cfm?confirm=RUN_MEMBER_NAME_BROWSER";
const get = (o, k) => o && (o[k] ?? o[k.toUpperCase()] ?? o[k.toLowerCase()]);
let fixture;
const captures = [];
const stage = (name) => console.log("Member-name integration:", name);

async function command(request, action, slot) {
  const response = await request.post(fixturePath + "&action=" + action
    + (fixture ? "&runKey=" + get(fixture, "runKey") : "") + (slot ? "&slot=" + slot : ""),
    { headers: fixture ? { "X-FPW-Member-Name-Token": get(fixture, "token") } : {} });
  const payload = await response.json();
  expect(response.status(), JSON.stringify(payload)).toBe(200);
  expect(get(payload, "ok"), JSON.stringify(payload)).toBe(true);
  return payload;
}
async function api(page, family, action, data = {}, successful = true) {
  stage(family + "/" + action);
  const response = await page.request.post(base + "/api/v1/" + family + ".cfc?method=handle" + (["routeBuilder", "floatplan"].includes(family) ? "&action=" + action : ""), { data: { ...data, action } });
  const payload = await response.json();
  stage(family + "/" + action + " response " + response.status());
  if (successful) expect(payload.SUCCESS, family + "/" + action + ": " + JSON.stringify(payload)).toBe(true);
  return payload;
}
async function login(page, member) {
  stage("login screen");
  await page.goto(base + "/app/login.cfm", { waitUntil: "domcontentloaded" });
  await page.waitForFunction(() => window.Api && window.Api.login);
  const response = await page.evaluate(({ email, password }) => window.Api.login(email, password),
    { email: get(member, "email"), password: get(fixture, "password") });
  expect(response.SUCCESS).toBe(true);
  stage("dashboard");
  await page.goto(base + "/app/dashboard.cfm", { waitUntil: "domcontentloaded" });
  await page.waitForFunction(() => window.FPW && window.FPW.DashboardModules && window.Api);
  await expect(page.locator("#welcomeOnboardingExploreBtn")).toBeVisible();
  await page.locator("#welcomeOnboardingExploreBtn").click();
  await expect(page.locator("#welcomeOnboardingExploreBtn")).not.toBeVisible();
}
async function openWizard(page, id, step = 1) {
  stage("open wizard step " + step);
  await page.evaluate(({ id, step }) => window.FPW.DashboardModules.floatplans.openWizardForPlan(id, step), { id, step });
  await expect(page.locator("#floatPlanWizardModal")).toBeVisible();
  await expect(page.locator("#wizardApp input[name=NAME]")).toBeVisible();
}
async function checkProfile(request, slot, first, last) {
  const state = await command(request, "inspect");
  const id = get(get(fixture, "members")[slot.toUpperCase()] || get(fixture, "members")[slot], "userId");
  const profile = get(state, "profiles").find((p) => Number(get(p, "userId")) === Number(id));
  expect(String(get(profile, "fName") || "").trim()).toBe(first);
  expect(String(get(profile, "lName") || "").trim()).toBe(last);
  expect(get(profile, "mobilePhone")).toBe("(727) 555-0123");
}
async function messages(request, email) {
  const r = await request.get("http://localhost:8025/api/v2/search?kind=to&query=" + encodeURIComponent(email));
  return (await r.json()).items || [];
}
async function inspectPdf(request, url, info, name, expectedName, absentName) {
  const response = await request.get(url);
  expect(response.ok(), "PDF HTTP " + response.status()).toBe(true);
  expect(response.headers()["content-type"]).toContain("application/pdf");
  const output = info.outputPath(name + ".pdf");
  fs.writeFileSync(output, await response.body());
  const python = "/Users/lawrencewald/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3";
  const text = execFileSync(python, ["-c", "from pypdf import PdfReader; import sys; r=PdfReader(sys.argv[1]); print(' '.join(p.extract_text() or '' for p in r.pages)); print(' '.join(str(f.get('/V', '')) for f in (r.get_fields() or {}).values()))", output], { encoding: "utf8" });
  expect(text).toContain(expectedName);
  expect(text).not.toContain("Prepared by");
  expect(text).not.toContain(absentName);
  await info.attach(name + "-text", { body: text, contentType: "text/plain" });
}
test.afterAll(async ({ request }) => {
  if (!fixture) return;
  for (const member of Object.values(get(fixture, "members"))) {
    for (const mail of await messages(request, get(member, "email"))) {
      expect((mail.To || []).every((to) => (to.Mailbox + "@" + to.Domain) === get(member, "email"))).toBe(true);
      expect((await request.delete("http://localhost:8025/api/v1/messages/" + encodeURIComponent(mail.ID))).ok()).toBe(true);
    }
    expect((await messages(request, get(member, "email"))).length).toBe(0);
  }
  const cleanup = await command(request, "cleanup");
  expect(get(cleanup, "remainingUsers")).toBe(0);
  expect(get(cleanup, "remainingOwnedRecords")).toBe(0);
  expect(get(cleanup, "remainingPdfs")).toBe(0);
});

test("live regular, standalone and Basic names preserve identity and delivery/PDF boundaries", async ({ browser, request }, info) => {
  test.setTimeout(180000);
  stage("prepare fixture");
  fixture = await command(request, "prepare");
  const members = get(fixture, "members");
  const regular = members.REGULAR || members.regular, basic = members.BASIC || members.basic;
  const context = await browser.newContext();
  const basicContext = await browser.newContext();
  context.setDefaultTimeout(15000);
  basicContext.setDefaultTimeout(15000);
  const page = await context.newPage(), basicPage = await basicContext.newPage();
  try {
    await login(page, regular);
    for (const invalidName of [{ fName: "", lName: " " }, { fName: "x".repeat(46), lName: "" }, { fName: "", lName: "x".repeat(46) }]) {
      const rejected = await page.evaluate((value) => window.Api.updateProfileName(value).catch((error) => error), invalidName);
      expect(rejected.ERROR).toBe("PROFILE_NAME_REQUIRED");
    }
    await checkProfile(request, "regular", "", "");
    const email = get(regular, "email"), name = get(regular, "planName");
    const vessel = get(await api(page, "vessel", "save", { vessel: { VESSELNAME: "Member name vessel", TYPE: "Power", LENGTH: "24", COLOR: "White", MAX_SPEED: "10", FUEL_CAPACITY: "80" } }), "VESSELID");
    const contact = get(await api(page, "contact", "save", { contact: { CONTACTNAME: "Local Test Contact", PHONE: "727-555-0123", EMAIL: email } }), "CONTACTID");
    const operator = get(await api(page, "operator", "save", { operator: { OPERATORNAME: "Distinct Operator Sentinel", PHONE: "727-555-0123" } }), "OPERATORID");
    const start = get(await api(page, "waypoint", "save", { waypoint: { WAYPOINTNAME: "Test Start", LATITUDE: "27.95", LONGITUDE: "-82.46" } }), "WAYPOINTID");
    const end = get(await api(page, "waypoint", "save", { waypoint: { WAYPOINTNAME: "Test End", LATITUDE: "27.96", LONGITUDE: "-82.45" } }), "WAYPOINTID");
    const route = get(get(await api(page, "routeBuilder", "createUserRoute", { route_name: name }), "DATA"), "route_id");
    await api(page, "routeBuilder", "setUserRouteStartWaypoint", { route_id: route, start_waypoint_id: start });
    const legs = get(get(await api(page, "routeBuilder", "addWaypointLegToUserRoute", { route_id: route, end_waypoint_id: end }), "DATA"), "legs");
    await api(page, "routeBuilder", "saveRouteLegOverrideGeometry", { route_id: route, route_leg_id: get(legs[0], "route_leg_id"), points: [{ lat: 27.95, lon: -82.46 }, { lat: 27.955, lon: -82.454 }, { lat: 27.96, lon: -82.45 }] });
    const departure = new Date(Date.now() + 36 * 3600000).toISOString().replace(/\.\d{3}Z$/, "Z");
    const returning = new Date(Date.now() + 40 * 3600000).toISOString().replace(/\.\d{3}Z$/, "Z");
    const generated = await api(page, "routeBuilder", "routegen_generate", { route_type: "my_route", route_id: route, route_name: name, selected_vessel_id: vessel, speed_kn: 10, cruising_speed: 10, underway_hours_per_day: 6.5, start_date: departure.slice(0, 10) });
    const id = get(await api(page, "routeBuilder", "buildFloatPlansFromRoute", { routeInstanceId: get(generated, "ROUTE_INSTANCE_ID"), vesselId: vessel }), "FLOATPLAN_IDS")[0];
    expect(Number(id)).toBeGreaterThan(0); // Route scaffolding is allowed before member-name capture.
    const bootstrap = await page.evaluate((id) => window.Api.getFloatPlanBootstrap(id), id);
    const payload = {
      FLOATPLAN: { ...bootstrap.FLOATPLAN, NAME: name, FLOATPLANID: id, VESSELID: vessel, OPERATORID: operator, OPERATOR_HAS_PFD: true,
        EMAIL: email, RESCUE_CENTERID: -1, RESCUE_AUTHORITY: "N/A - Call 911", RESCUE_AUTHORITY_PHONE: "911", DO_NOT_SEND: false,
        DEPARTURE_TIME: departure.slice(0, 19), DEPARTURE_TIMEZONE: "UTC", DEPARTURE_TIME_UTC: departure,
        RETURN_TIME: returning.slice(0, 19), RETURN_TIMEZONE: "UTC", RETURN_TIME_UTC: returning },
      CONTACTS: [{ CONTACTID: contact, SORT_ORDER: 1 }], PASSENGERS: [],
      WAYPOINTS: bootstrap.PLAN_WAYPOINTS?.length ? bootstrap.PLAN_WAYPOINTS : bootstrap.ROUTE_DEFAULTS?.WAYPOINT_SELECTIONS || []
    };
    expect((await api(page, "floatplan", "save", payload, false)).ERROR).toBe("PROFILE_NAME_REQUIRED");
    expect((await api(page, "floatplan", "send", { floatPlanId: id }, false)).ERROR).toBe("PROFILE_NAME_REQUIRED");
    expect((await messages(request, email)).length).toBe(0);
    await openWizard(page, id);
    await page.locator("#wizardApp select[name=OPERATORID]").selectOption(String(operator));
    await page.locator("#wizardMemberFirstName").fill("  SenderFirstOnly  ");
    await page.locator("#wizardApp").getByRole("button", { name: "Next", exact: true }).first().click();
    await expect(page.locator("#wizardApp")).toContainText("Step 2");
    await expect(page.locator("#wizardMemberFirstName")).toHaveCount(0);
    await checkProfile(request, "regular", "SenderFirstOnly", "");
    await api(page, "floatplan", "save", payload);
    await page.locator("#floatPlanWizardModal .btn-close").click();
    await expect(page.locator("#floatPlanWizardModal")).not.toBeVisible();
    await openWizard(page, id);
    await expect(page.locator("#wizardMemberFirstName")).toHaveCount(0);
    await expect(page.locator("#wizardApp")).toContainText("SenderFirstOnly");
    await page.locator("#floatPlanWizardModal .btn-close").click();
    await expect(page.locator("#floatPlanWizardModal")).not.toBeVisible();
    await command(request, "clearName", "regular");
    await openWizard(page, id, 6);
    await expect(page.locator("#wizardMemberFirstName")).toBeVisible();
    await page.locator("#floatPlanWizardModal .btn-close").click();
    await expect(page.locator("#floatPlanWizardModal")).not.toBeVisible();
    await page.goto(base + "/app/floatplan-wizard.cfm?id=" + id);
    await expect(page.locator("#wizardMemberLastName")).toBeVisible();
    await page.locator("#wizardMemberLastName").fill(" SenderLastOnly ");
    await page.locator("#wizardApp").getByRole("button", { name: "Next", exact: true }).first().click();
    await expect(page.locator("#wizardMemberLastName")).toHaveCount(0);
    await checkProfile(request, "regular", "", "SenderLastOnly");
    const confirmation = await api(page, "floatplan", "getbasicreviewconfirmation", { floatPlanId: id });
    expect(confirmation.SENDER_NAME).toBe("SenderLastOnly");
    const key = "member_name_" + get(fixture, "runKey");
    const basicReview = await api(page, "floatplan", "sendbasicreview", { floatPlanId: id, contactId: contact, idempotencyKey: key });
    expect(basicReview.SENT_COUNT).toBe(1);
    await command(request, "clearName", "regular");
    expect((await api(page, "floatplan", "sendbasicreview", { floatPlanId: id, contactId: contact, idempotencyKey: key })).IDEMPOTENT_REPLAY).toBe(true);
    expect((await api(page, "floatplan", "sendbasicreview", { floatPlanId: id, contactId: contact, idempotencyKey: key + "_new" }, false)).ERROR).toBe("PROFILE_NAME_REQUIRED");
    await page.evaluate(() => window.Api.updateProfileName({ fName: "PremiumSenderOnly", lName: "" }));
    await api(page, "floatplan", "send", { floatPlanId: id });
    await command(request, "clearName", "regular");
    expect((await api(page, "floatplan", "send", { floatPlanId: id })).IDEMPOTENT_REPLAY).toBe(true);
    await inspectPdf(page.request, base + "/api/v1/floatplan.cfc?method=handle&action=previewpdf&id=" + id, info,
      "regular-operator", "Distinct Operator Sentinel", "PremiumSenderOnly");

    await login(basicPage, basic);
    await basicPage.evaluate(() => window.FPW.DashboardModules.basicFloatPlan.open(0));
    await expect(basicPage.locator("#basicMemberFirstName")).toBeVisible();
    const fields = {
      basicPlanName: get(basic, "planName"), basicPlanVesselName: "Basic vessel", basicPlanOperatorName: "Basic Operator Sentinel",
      basicPlanCaptainName: "Basic Captain Sentinel", basicPlanEmail: get(basic, "email"), basicDepartingFrom: "Test Port",
      basicDestination: "Test Marina", basicDepartureTime: departure.slice(0, 16), basicReturnTime: returning.slice(0, 16),
      basicContactName: "Local Basic Contact", basicContactEmail: get(basic, "email")
    };
    for (const [field, value] of Object.entries(fields)) await basicPage.locator("#" + field).fill(value);
    await basicPage.locator("#basicAuthorityId").selectOption("-1");
    await basicPage.locator("#basicDepartureTimezone").selectOption("UTC");
    await basicPage.locator("#basicReturnTimezone").selectOption("UTC");
    await basicPage.locator("#basicFloatPlanSaveBtn").click();
    await expect(basicPage.locator("#basicMemberNameError")).toBeVisible();
    await basicPage.locator("#basicMemberLastName").fill(" BasicLastOnly ");
    await basicPage.locator("#basicFloatPlanSaveBtn").click();
    await expect(basicPage.locator("#basicFloatPlanMessage")).toHaveText("Basic float plan draft saved.");
    await checkProfile(request, "basic", "", "BasicLastOnly");
    const basicId = Number(await basicPage.locator("#basicFloatPlanId").inputValue());
    expect(basicId).toBeGreaterThan(0);
    await basicPage.locator("#basicFloatPlanModal .btn-close").click();
    await expect(basicPage.locator("#basicFloatPlanModal")).not.toBeVisible();
    await command(request, "clearName", "basic");
    expect((await api(basicPage, "floatplan", "sendbasic", { floatPlanId: basicId }, false)).ERROR).toBe("PROFILE_NAME_REQUIRED");
    // Exercise the retained Basic workspace entry without changing the application credit-model flag.
    await basicPage.evaluate(() => {
      const panel = document.createElement("section");
      panel.id = "memberNameTestBasicWorkspace";
      document.querySelector("main").appendChild(panel);
      window.FPW.DashboardModules.basicFloatPlan.renderPanel(panel);
    });
    await basicPage.locator('[data-basic-floatplan-send-draft][data-basic-floatplan-id="' + basicId + '"]').first().click();
    await expect(basicPage.locator("#basicMemberFirstName")).toBeVisible();
    await expect(basicPage.locator("#basicFloatPlanMessage")).toContainText("Enter your name");
    await basicPage.locator("#basicMemberFirstName").fill(" BasicFirstOnly ");
    await basicPage.locator("#basicFloatPlanSendBtn").click();
    await expect(basicPage.locator("#basicFloatPlanSentState")).toBeVisible();
    await checkProfile(request, "basic", "BasicFirstOnly", "");
    await inspectPdf(basicPage.request, base + "/api/v1/floatplan.cfc?method=handle&action=downloadbasicpdf&id=" + basicId, info,
      "basic-operator", "Basic Operator Sentinel", "BasicFirstOnly");
    const identityState = await command(request, "inspect");
    const basicIdentity = get(identityState, "plans").find((plan) => Number(get(plan, "floatPlanId")) === basicId);
    expect(get(basicIdentity, "captain_name")).toBe("Basic Captain Sentinel");

    for (const [member, count, senderNames] of [[regular, 2, ["SenderLastOnly", "PremiumSenderOnly"]], [basic, 1, ["BasicFirstOnly"]]]) {
      await expect.poll(async () => (await messages(request, get(member, "email"))).length, { timeout: 20000 }).toBe(count);
      const mail = await messages(request, get(member, "email"));
      const content = mail.map((m) => JSON.stringify(m)).join("\n");
      for (const sender of senderNames) expect(content).toContain(sender);
      captures.push({ recipient: get(member, "email"), count, senderNames });
    }
    await info.attach("delivery-evidence", { body: JSON.stringify(captures), contentType: "application/json" });
  } finally {
    await context.close().catch(() => {});
    await basicContext.close().catch(() => {});
  }
});
