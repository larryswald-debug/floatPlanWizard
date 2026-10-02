const { test, expect } = require("@playwright/test");

const baseUrl = "http://localhost:8500/fpw";
const intentToken = "c".repeat(64);

async function prepareCompletion(page) {
  await page.goto(baseUrl + "/great-loop/trip-planning/");
  await page.evaluate((token) => {
    window.__completionEvents = [];
    window.__ackCalls = 0;
    window.FPWAnalytics.track = (name, params) => window.__completionEvents.push({ name, params });
    document.body.setAttribute("data-auth-handoff", JSON.stringify({
      TOKEN: token, DESTINATIONKEY: "planner",
      SOURCE: { SOURCE_PAGE: "great_loop_trip_planning", SECTION: "daily_decisions", CTA_TYPE: "plan_trip" }
    }));
    window.history.replaceState({}, "", window.location.pathname + "?authIntent=" + token);
  }, intentToken);
}

test("continuation stays pending until the authenticated server acknowledges it", async ({ page }) => {
  await prepareCompletion(page);
  for (const response of [
    { SUCCESS: true, AUTH: false, ACKNOWLEDGED: true },
    { SUCCESS: false, AUTH: true, ACKNOWLEDGED: true },
    { SUCCESS: true, AUTH: true, ACKNOWLEDGED: false },
    {}
  ]) {
    const completed = await page.evaluate(async (result) => {
      window.Api.acknowledgeAuthIntent = () => {
        window.__ackCalls++;
        return Promise.resolve(result);
      };
      return window.AppAuth.completeContinuation();
    }, response);
    expect(completed).toBe(false);
    await expect(page.locator("body")).toHaveAttribute("data-auth-handoff", /planner/);
    expect(new URL(page.url()).searchParams.get("authIntent")).toBe(intentToken);
    expect(await page.evaluate(() => window.__completionEvents)).toEqual([]);
  }
});

test("confirmed continuation acknowledges once and handles CFML response casing", async ({ page }) => {
  await prepareCompletion(page);
  const result = await page.evaluate(async () => {
    window.Api.acknowledgeAuthIntent = () => {
      window.__ackCalls++;
      return Promise.resolve({ SUCCESS: true, AUTH: true, ACKNOWLEDGED: true });
    };
    return Promise.all([window.AppAuth.completeContinuation(), window.AppAuth.completeContinuation()]);
  });
  expect(result).toEqual([true, true]);
  expect(await page.evaluate(() => window.__ackCalls)).toBe(1);
  await expect(page.locator("body")).not.toHaveAttribute("data-auth-handoff");
  expect(new URL(page.url()).searchParams.has("authIntent")).toBe(false);
  expect(await page.evaluate(() => window.__completionEvents)).toEqual([{
    name: "auth_continuation_success",
    params: {
      source_page: "great_loop_trip_planning", section: "daily_decisions",
      cta_type: "plan_trip", destination_key: "planner"
    }
  }]);
});

function dashboardHarness(firstLanding) {
  const handoff = JSON.stringify({
    token: intentToken, destinationKey: "planner", waitForContinue: true,
    source: { source_page: "great_loop_trip_planning", section: "after_planning_guide", cta_type: "plan_trip", label: "Start Planning" }
  }).replace(/"/g, "&quot;");
  return `<!doctype html><html><head><title>Dashboard handoff harness</title></head>
  <body data-auth-overview="${firstLanding}" data-auth-wait-for-continue="true" data-auth-handoff="${handoff}" data-recovery-intent="{}">
    <section id="authContinuationPanel" hidden>
      <p id="authContinuationStatus"></p>
      <button id="authContinuationBtn" disabled>Continue</button>
      <button id="authContinuationDismissBtn">Dismiss</button>
    </section>
    <section id="dashboardGettingStartedPanel" hidden></section>
    <button id="openRouteBuilderBtn">Create Route</button>
    <script>
      window.FPW_BASE = "/fpw";
      window.__ready = false;
      window.__opens = 0;
      window.__claims = 0;
      window.__requires = 0;
      window.__hydrateOptions = [];
      window.FPWAnalytics = { track: function () {} };
      window.Api = {
        getCurrentMemberAccess: function () { return Promise.resolve({
          SUCCESS: true, AUTH: true, USER: {USERID: 9001}, ACCESS: {hasPremium: false},
          ONBOARDING: {checklist: {allComplete: false}, autoOpenWelcome: true}
        }); },
        continueAuthIntent: function () { window.__claims++; return Promise.resolve({SUCCESS:true,AUTH:true,ACKNOWLEDGED:true}); },
        acknowledgeAuthIntent: function () { return Promise.resolve({SUCCESS:true,AUTH:true,ACKNOWLEDGED:true}); },
        dismissAuthIntent: function () { return Promise.resolve({SUCCESS:true,AUTH:true,ACKNOWLEDGED:true}); }
      };
      window.FPW = {
        DashboardUtils: {},
        DashboardState: {},
        DashboardModules: {
          onboarding: {
            init: function () {},
            acknowledgeOverview: function () { return Promise.resolve(); },
            hydrate: function (data, options) {
              window.__hydrateOptions.push(options);
              document.dispatchEvent(new CustomEvent("fpw:onboarding:updated", {detail:data}));
            }
          }
        }
      };
      document.getElementById("openRouteBuilderBtn").addEventListener("click", function () { window.__opens++; });
      document.addEventListener("fpw:dashboard:user-ready", function () { window.__ready = true; });
    </script>
    <script src="/fpw/assets/js/app/auth.js?v=20261001-unified-auth"></script>
    <script>window.AppAuth.requireAuth = function () { window.__requires++; return Promise.resolve({status:"navigating"}); };</script>
    <script src="/fpw/assets/js/app/dashboard.js?v=20261001-unified-auth"></script>
  </body></html>`;
}

test("pending new-account goal survives reload and waits for a ready explicit Continue", async ({ page }) => {
  let loads = 0;
  await page.route("**/api/v1/**", (route) => route.fulfill({
    status: 200, contentType: "application/json",
    body: JSON.stringify({SUCCESS: true, AUTH: true, ROUTES: [], DATA: {counts: {active:0,overdue:0,escalated:0}}})
  }));
  await page.route("**/app/dashboard.cfm?authIntent=*", (route) => route.fulfill({
    status: 200, contentType: "text/html", body: dashboardHarness(loads++ === 0)
  }));
  await page.goto(baseUrl + "/app/dashboard.cfm?authIntent=" + intentToken);
  await page.waitForFunction(() => window.__ready === true);
  expect(await page.evaluate(() => window.__hydrateOptions[0].allowAutoOpen)).toBe(false);
  await expect(page.locator("#authContinuationBtn")).toBeDisabled();
  expect(await page.evaluate(() => window.__opens + window.__claims + window.__requires)).toBe(0);

  await page.reload();
  await page.waitForFunction(() => window.__ready === true);
  await expect(page.locator("body")).toHaveAttribute("data-auth-overview", "false");
  expect(await page.evaluate(() => window.__hydrateOptions[0].allowAutoOpen)).toBe(false);
  await page.evaluate(() => document.dispatchEvent(new CustomEvent("fpw:onboarding:updated", {
    detail: {checklist: {allComplete: true}}
  })));
  await expect(page.locator("#authContinuationBtn")).toBeEnabled();
  expect(await page.evaluate(() => window.__opens + window.__claims + window.__requires)).toBe(0);
  await page.locator("#authContinuationBtn").click();
  await expect.poll(() => page.evaluate(() => window.__requires)).toBe(1);
  expect(await page.evaluate(() => window.__claims)).toBe(1);
  expect(await page.evaluate(() => window.__opens)).toBe(0);
});
