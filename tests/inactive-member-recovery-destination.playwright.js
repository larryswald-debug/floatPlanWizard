// Run with MCP Playwright browser_run_code_unsafe. Uses isolated contexts and SQL-only local fixtures.
// No signup, recovery runner, delivery transport, Save, Send, or production configuration is invoked.
async (page) => {
  const origin = "http://localhost:8500";
  const root = origin + "/fpw";
  const endpoint = root + "/tests/inactive-member-recovery-destination-browser-fixture.cfm?confirm=RUN_RECOVERY_DESTINATION_BROWSER";
  const browser = page.context().browser();
  if (!browser) throw new Error("An isolated Playwright context is required");
  const prepared = await (await page.request.get(endpoint + "&action=prepare")).json();
  if (!prepared.OK) throw new Error("Destination fixture preparation failed: " + JSON.stringify(prepared));
  const members = prepared.MEMBERS;
  const results = [];
  let cleanup;
  const assert = (condition, message) => { if (!condition) throw new Error(message); };
  const dashboard = root + "/app/dashboard.cfm";

  async function scenario(name, member, query, verify, options = {}) {
    const context = await browser.newContext({viewport:{width:1440,height:1000}});
    const p = await context.newPage();
    const pageErrors = [];
    p.on("pageerror", error => pageErrors.push(error.message));
    try {
      const target = dashboard + (query ? "?" + query : "");
      const login = root + "/app/login.cfm" + (query ? "?" + query : "");
      await p.goto(options.directLogin ? login : (query ? target : login), {waitUntil:"domcontentloaded"});
      if (options.invalidReturn) {
        assert((await p.locator("#loginForm").getAttribute("data-recovery-return")) === "", "Unsafe return was accepted");
      } else if (query) {
        assert(p.url() === login, "Anonymous recovery request did not preserve the exact login destination: " + p.url());
        assert((await p.locator("#loginForm").getAttribute("data-recovery-return")) === "/fpw/app/dashboard.cfm?" + query,
          "Login form did not preserve canonical recovery intent");
      }
      await p.locator("#email").fill(member.EMAIL);
      await p.locator("#password").fill(prepared.PASSWORD);
      const destination = options.invalidReturn ? dashboard : target;
      await Promise.all([
        p.waitForURL(destination, {timeout:20000}),
        p.locator("#loginButton").click()
      ]);
      await p.waitForFunction(() => window.FPW && window.FPW.DashboardState && window.FPW.DashboardState.currentUser, null, {timeout:15000});
      const details = await verify(p, context);
      assert(!pageErrors.some(message => /SyntaxError|Invalid regular expression/.test(message)), "JavaScript syntax error: " + pageErrors.join("; "));
      results.push({name,passed:true,url:p.url(),details,pageErrors});
    } catch (error) {
      results.push({name,passed:false,error:error.message,url:p.url(),pageErrors,
        body:(await p.locator("body").innerText().catch(() => "")).slice(0,2200)});
    } finally {
      await context.close();
    }
  }
  async function intent(p) {
    return p.evaluate(() => JSON.parse(document.body.getAttribute("data-recovery-intent") || "{}"));
  }
  async function modal(p, selector) {
    await p.locator(selector + ".show").waitFor({state:"visible",timeout:15000});
  }
  async function fallback(p, expectedAction) {
    const resolved = await intent(p);
    assert((resolved.action || resolved.ACTION) === expectedAction, "Wrong fallback action");
    await p.locator("#dashboardAlert:not(.d-none)").waitFor({state:"visible",timeout:15000});
    const text = await p.locator("#dashboardAlert").innerText();
    assert(text.includes(expectedAction === "routes" ? "Choose a saved route" : "Choose a current float plan"), "Missing useful fallback guidance");
    assert(await p.locator("#routeBuilderModal.show, #floatPlanWizardModal.show, #basicFloatPlanModal.show").count() === 0, "Foreign or stale object modal opened");
    return {resolved,text};
  }
  try {
    await scenario("A vessel setup through actual login", members.A, "recoveryAction=vessel", async p => {
      await modal(p,"#vesselModal");
      assert(await p.locator("#vesselId").inputValue() === "0", "Vessel entry was not new setup");
      return {modal:"vesselModal"};
    });
    await scenario("B Trip Planner entry preserves existing readiness gate", members.B, "recoveryAction=planner", async p => {
      await p.waitForFunction(() => /Before creating a route, complete Getting Started/.test(document.querySelector("#dashboardAlert")?.textContent || ""), null, {timeout:15000});
      return {message:await p.locator("#dashboardAlert").innerText()};
    });
    await scenario("B Trip Planner opens when existing setup requirements are complete", members.BREADY, "recoveryAction=planner", async p => {
      await modal(p,"#routeBuilderModal");
      return {modal:"routeBuilderModal"};
    });
    for (const [name,member,hasLeg] of [["C saved route with zero legs",members.CZERO,false],["C saved route with one owned waypoint leg",members.CLEGS,true]]) {
      await scenario(name,member,"recoveryAction=route&routeId=" + member.ROUTEID,async p => {
        await modal(p,"#routeBuilderModal");
        await p.waitForFunction(id => document.querySelector("#routeGenMyRouteSelect")?.value === String(id),member.ROUTEID,{timeout:15000});
        if (hasLeg) await p.waitForFunction(() => /Recovery start/.test(document.querySelector("#routeGenMyRouteLegList")?.textContent || ""),null,{timeout:15000});
        return {selectedRoute:await p.locator("#routeGenMyRouteSelect").inputValue(),legs:await p.locator("#routeGenMyRouteLegList").innerText()};
      });
    }
    await scenario("D canonical Basic Draft",members.DBASIC,"recoveryAction=draft&floatPlanId=" + members.DBASIC.PLANID,async p => {
      await modal(p,"#basicFloatPlanModal");
      await p.waitForFunction(id => document.querySelector("#basicFloatPlanId")?.value === String(id),members.DBASIC.PLANID,{timeout:15000});
      await p.waitForFunction(() => document.querySelector("#basicPlanName")?.value === "Recovery Sender Draft",null,{timeout:15000});
      return {planId:await p.locator("#basicFloatPlanId").inputValue(),name:await p.locator("#basicPlanName").inputValue()};
    });
    await scenario("D ordinary Draft",members.DORDINARY,"recoveryAction=draft&floatPlanId=" + members.DORDINARY.PLANID,async p => {
      await modal(p,"#floatPlanWizardModal");
      await p.waitForFunction(() => Array.from(document.querySelectorAll("#floatPlanWizardModal input")).some(input => input.value === "Recovery Sender Draft"),null,{timeout:15000});
      return {modal:"floatPlanWizardModal",resolved:await intent(p)};
    });
    await scenario("Foreign route rechecked after login",members.A,"recoveryAction=route&routeId=" + members.CZERO.ROUTEID,p => fallback(p,"routes"));
    await scenario("Foreign Draft rechecked after login",members.A,"recoveryAction=draft&floatPlanId=" + members.DBASIC.PLANID,p => fallback(p,"plans"));
    await scenario("Deleted route falls back",members.STALE,"recoveryAction=route&routeId=" + members.STALE.ROUTEID,p => fallback(p,"routes"));
    await scenario("Deleted Draft falls back",members.STALE,"recoveryAction=draft&floatPlanId=" + members.STALE.PLANID,p => fallback(p,"plans"));
    await scenario("External return URL rejected",members.A,"recoveryAction=vessel&returnUrl=https%3A%2F%2Fevil.example",async p => {
      assert(p.url() === dashboard,"Unsafe input altered ordinary login destination");
      assert(Object.keys(await intent(p)).length === 0,"Unsafe recovery intent survived");
      return {destination:p.url()};
    },{directLogin:true,invalidReturn:true});
    await scenario("Ordinary login unchanged",members.A,"",async p => {
      assert(p.url() === dashboard,"Ordinary login destination changed");
      return {destination:p.url()};
    });
    await scenario("Expired session keeps recovery action after real unauthorized API response",members.CZERO,"recoveryAction=route&routeId=" + members.CZERO.ROUTEID,async (p,context) => {
      await modal(p,"#routeBuilderModal");
      const logout = await p.evaluate(() => window.Api.logout());
      assert(logout.SUCCESS === true,"Fixture logout failed");
      await Promise.all([
        p.waitForURL(root + "/app/login.cfm?recoveryAction=route&routeId=" + members.CZERO.ROUTEID,{timeout:15000}),
        p.evaluate(async () => {
          try { window.AppAuth.ensureAuthenticated(await window.Api.getCurrentUser()); }
          catch (error) { window.AppAuth.handleUnauthorizedError(error); }
        })
      ]);
      assert((await p.locator("#loginForm").getAttribute("data-recovery-return")) === "/fpw/app/dashboard.cfm?recoveryAction=route&routeId=" + members.CZERO.ROUTEID,"Stale-session continuation lost");
      return {login:p.url()};
    });
    const inspection = await (await page.request.get(endpoint + "&action=inspect&runKey=" + prepared.RUNKEY)).json();
    assert(inspection.OK && inspection.COUNTS.LEDGER === 0 && inspection.COUNTS.SUBMISSIONS === 0,"Unexpected recovery send or ledger mutation");
  } finally {
    cleanup = await (await page.request.get(endpoint + "&action=cleanup&runKey=" + prepared.RUNKEY)).json();
  }
  const clean = cleanup.OK && Object.values(cleanup.REMAINING).every(value => value === 0);
  return {ok:clean && results.every(result => result.passed),passed:results.filter(result => result.passed).length,
    failed:results.filter(result => !result.passed).length,results,cleanup,cleanupVerified:clean};
};
