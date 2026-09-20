const { test, expect } = require("@playwright/test");
const { readFileSync } = require("node:fs");
const engine = require("../assets/js/boat-cost-engine.js");
const state = require("../assets/js/boat-cost-state.js");

const canonical = "https://floatplanwizard.com/boat-loan-calculator/";
const localOrigin = process.env.FPW_TEST_ORIGIN || "http://127.0.0.1:8500";
const plausibleScript = "https://plausible.io/js/pa-RzmzzpwAcdcGg_-4y94nc.js";
const snapshotPath = process.env.FPW_PLAUSIBLE_SCRIPT;

// Use the actual deployed analytics script, but fulfill every outgoing event
// locally. These tests never send test events to the production analytics site.
async function inspectNetwork(context, options = {}) {
  const observed = { requests: [], events: [], forbiddenTrackers: [], scriptLoads: 0 };
  await context.addInitScript(({ declined }) => {
    window.__plausible = true; // Plausible otherwise ignores automated browsers.
    if (declined) localStorage.setItem("plausible_ignore", "true");
  }, { declined: !!options.declined });
  await context.route("**/*", async route => {
    const request = route.request();
    const url = new URL(request.url());
    const headers = await request.allHeaders();
    const body = request.postData() || "";
    observed.requests.push({ url: request.url(), headers, body, type: request.resourceType() });
    if (url.origin === "https://plausible.io" && url.pathname === "/api/event") {
      observed.events.push(JSON.parse(body));
      await route.fulfill({ status: 202, contentType: "application/json", headers: { "access-control-allow-origin": "*" }, body: "{}" });
      return;
    }
    if (/google-analytics|googletagmanager|clarity\.ms|hotjar/i.test(url.hostname)) {
      observed.forbiddenTrackers.push(url.hostname);
      await route.abort();
      return;
    }
    if (request.url() === plausibleScript) {
      observed.scriptLoads++;
      if (snapshotPath) {
        await route.fulfill({ status: 200, contentType: "application/javascript", body: readFileSync(snapshotPath, "utf8") });
      } else {
        const response = await route.fetch();
        await route.fulfill({ response });
      }
      return;
    }
    if (url.origin === "https://floatplanwizard.com") {
      const pathname = url.pathname.startsWith("/fpw/") ? url.pathname : "/fpw" + url.pathname;
      const response = await route.fetch({ url: localOrigin + pathname + url.search });
      await route.fulfill({ response });
      return;
    }
    if (request.method() !== "GET") {
      observed.forbiddenTrackers.push("unexpected_external_post");
      await route.abort();
      return;
    }
    await route.continue();
  });
  return observed;
}

function assertPrivate(observed, secrets) {
  expect(observed.forbiddenTrackers).toEqual([]);
  const serialized = JSON.stringify(observed.requests);
  for (const secret of secrets) expect(serialized.includes(secret), "A request must not contain a financial value, scenario label or share payload").toBe(false);
  for (const event of observed.events) {
    expect(event.u).toBe(canonical);
    expect(event.r == null).toBe(true);
    expect(event.d).toBe("floatplanwizard.com");
    if (event.n !== "pageview" && event.n !== "engagement") {
      const sanitized = state.sanitizeEvent(event.n, event.p);
      expect(sanitized).not.toBeNull();
      expect(event.p).toEqual(sanitized.params);
    }
  }
}

test.describe("boat calculator privacy", () => {

    test("shared import, financial edits, calculate/save/compare keep requests private", async ({ page, context }) => {
      const observed = await inspectNetwork(context);
      const errors = [];
      page.on("pageerror", error => errors.push(error.message));
      const source = engine.example("B");
      source.purchase.price.value = 432198.76;
      source.label = "Private original label ZXQ90210";
      const shared = state.share(source);
      expect(shared.ok).toBe(true);
      const encoded = new URL(shared.url).hash.slice(4);
      await page.goto(shared.url, { waitUntil: "load" });
      await expect(page.locator("#bc-purchase-price")).toHaveValue("432198.76");
      await expect.poll(() => observed.events.filter(event => event.n === "pageview").length).toBe(1);
      expect(new URL(page.url()).hash).toBe("");
      expect(new URL(page.url()).search).toBe("");
      expect(await page.evaluate(() => window.FPWBoatCostBootstrap.fragment)).toBe("");
      expect(await page.evaluate(() => localStorage.getItem("fpw.boatCost.v1"))).toBeNull();
      expect(observed.events.filter(event => event.n === "boat_cost_calculate")).toHaveLength(0);

      await page.locator("#bc-label").fill("Private edited label ZXQ76328");
      await page.locator("#bc-purchase-price").fill("321987.65");
      await page.waitForTimeout(500); // Explicitly exercise the 300 ms automatic recalculation.
      expect(observed.events.filter(event => event.n === "boat_cost_calculate")).toHaveLength(0);
      await page.getByRole("button", { name: "Calculate my boating budget", exact: true }).click();
      await expect.poll(() => observed.events.filter(event => event.n === "boat_cost_calculate").length).toBe(1);
      await page.getByRole("button", { name: "Save in this browser", exact: true }).click();
      await expect.poll(() => observed.events.filter(event => event.n === "boat_cost_save").length).toBe(1);
      // Exercise the copy control only after the privacy assertions above. The
      // release gate remains a page setting; this isolated test does not edit it.
      await page.evaluate(() => {
        document.getElementById("boat-cost-app").setAttribute("data-share-verified", "true");
        Object.defineProperty(navigator, "clipboard", { configurable: true, value: {
          writeText(value) { window.__privacyCopiedLink = value; return Promise.resolve(); }
        } });
      });
      await page.getByRole("button", { name: "Duplicate scenario", exact: true }).click();
      await page.getByRole("button", { name: "Compare scenarios", exact: true }).click();
      await expect.poll(() => observed.events.filter(event => event.n === "boat_cost_compare").length).toBe(1);
      await page.locator("#bc-purchase-down-input").fill("23456.78");
      await page.waitForTimeout(500);
      expect(observed.events.filter(event => event.n === "boat_cost_calculate")).toHaveLength(1);
      expect(observed.events.filter(event => event.n === "boat_cost_start")).toHaveLength(1);
      page.once("dialog", dialog => dialog.dismiss());
      await page.getByRole("button", { name: "Share active scenario", exact: true }).click();
      expect(observed.events.filter(event => event.n === "boat_cost_share")).toHaveLength(0);
      page.once("dialog", dialog => dialog.accept());
      await page.getByRole("button", { name: "Share active scenario", exact: true }).click();
      await expect.poll(() => observed.events.filter(event => event.n === "boat_cost_share").length).toBe(1);
      const copied = await page.evaluate(() => window.__privacyCopiedLink);
      expect(state.parse(new URL(copied).hash).ok).toBe(true);
      expect(observed.scriptLoads).toBe(1);
      assertPrivate(observed, ["432198.76", "321987.65", "23456.78", "Private original label ZXQ90210", "Private edited label ZXQ76328", encoded, new URL(copied).hash.slice(4)]);
      expect(errors).toEqual([]);
    });

    test("declined analytics permits calculation and does not load a tracker", async ({ page, context }) => {
      const observed = await inspectNetwork(context, { declined: true });
      await page.goto(canonical, { waitUntil: "load" });
      await page.locator('[data-boat-cost-example="B"]').click();
      await expect(page.locator("#bc-results")).toContainText("$1,418.64");
      await page.getByRole("button", { name: "Save in this browser", exact: true }).click();
      await expect.poll(() => page.evaluate(() => localStorage.getItem("fpw.boatCost.v1") !== null)).toBe(true);
      expect(observed.scriptLoads).toBe(0);
      expect(observed.events).toEqual([]);
      expect(observed.forbiddenTrackers).toEqual([]);
    });

    test("incoming query and referrer are stripped before analytics receives them", async ({ page, context }) => {
      const observed = await inspectNetwork(context);
      await page.goto(canonical + "?price=963852.74", { waitUntil: "load", referer: "https://example.test/previous?cash=741852.96" });
      await expect.poll(() => observed.events.filter(event => event.n === "pageview").length).toBe(1);
      expect(new URL(page.url()).search).toBe("");
      assertPrivate({ ...observed, requests: observed.requests.filter(request => new URL(request.url).hostname === "plausible.io") }, ["963852.74", "741852.96"]);
    });

    test("failed URL removal keeps analytics and sharing disabled", async ({ page, context }) => {
      const observed = await inspectNetwork(context);
      await context.addInitScript(() => {
        history.replaceState = function () { throw new Error("URL cleanup unavailable"); };
      });
      const shared = state.share(engine.example("B"));
      await page.goto(shared.url, { waitUntil: "load" });
      await expect(page.locator("#bc-results")).toContainText("$1,418.64");
      await expect(page.getByRole("button", { name: "Share active scenario", exact: true })).toBeDisabled();
      expect(await page.evaluate(() => window.FPWBoatCostBootstrap.clean)).toBe(false);
      expect(observed.events).toEqual([]);
      expect(observed.scriptLoads).toBe(0);
    });

    test("same-document share fragments are scrubbed without pageview or calculation events", async ({ page, context }) => {
      const observed = await inspectNetwork(context);
      await page.goto(canonical, { waitUntil: "load" });
      await expect.poll(() => observed.events.filter(event => event.n === "pageview").length).toBe(1);
      const source = engine.example("I");
      source.purchase.price.value = 278634.51;
      const shared = state.share(source);
      const hash = new URL(shared.url).hash;
      await page.evaluate(value => { location.hash = value; }, hash);
      await expect(page.locator("#bc-purchase-price")).toHaveValue("278634.51");
      await expect.poll(() => new URL(page.url()).hash).toBe("");
      expect(await page.evaluate(() => localStorage.getItem("fpw.boatCost.v1"))).toBeNull();
      expect(observed.events.filter(event => event.n === "pageview")).toHaveLength(1);
      expect(observed.events.filter(event => event.n === "boat_cost_calculate")).toHaveLength(0);
      assertPrivate(observed, ["278634.51", hash.slice(4)]);
    });

    test("later URL-cleanup failure disables the already-loaded event bridge", async ({ page, context }) => {
      const observed = await inspectNetwork(context);
      await page.goto(canonical, { waitUntil: "load" });
      await expect.poll(() => observed.events.filter(event => event.n === "pageview").length).toBe(1);
      const hash = new URL(state.share(engine.example("B")).url).hash;
      await page.evaluate(value => {
        history.replaceState = function () { throw new Error("Later URL cleanup unavailable"); };
        location.hash = value;
      }, hash);
      await expect.poll(() => page.evaluate(() => window.FPWBoatCostBootstrap.clean)).toBe(false);
      await expect(page.getByRole("button", { name: "Share active scenario", exact: true })).toBeDisabled();
      await page.evaluate(() => {
        window.FPWAnalytics.track("boat_cost_start", { direction: "price" });
        window.plausible("boat_cost_start", { props: { direction: "price", price: 986421.37 }, url: location.href });
      });
      await page.waitForTimeout(100);
      expect(observed.events.filter(event => event.n === "boat_cost_start")).toHaveLength(0);
      assertPrivate(observed, ["986421.37", hash.slice(4)]);
    });
});
