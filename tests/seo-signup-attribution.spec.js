const { test, expect } = require("@playwright/test");
const { readFileSync } = require("node:fs");
const path = require("node:path");

const repositoryRoot = path.resolve(__dirname, "..");
const storageKey = "fpw_signup_attribution";
const joinUrl = "http://localhost:8500/fpw/app/join.cfm";
const landingPages = [
  {
    name: "Fuel",
    url: "http://localhost:8500/fpw/boat-fuel-calculator/boat-fuel-calculator.cfm",
    selector: "#boat-fuel-calculator-plan-route-cta [data-fpw-action-cta]",
    attribution: {
      landing_key: "boat_fuel_calculator",
      source_content_type: "seo_tool",
      cta_type: "plan_route"
    }
  },
  {
    name: "Locks",
    url: "http://localhost:8500/fpw/app/great-loop-locks.cfm",
    selector: "#great-loop-locks-plan-route-cta [data-fpw-action-cta]",
    attribution: {
      landing_key: "great_loop_locks",
      source_content_type: "seo_hub",
      cta_type: "plan_route"
    }
  }
];

async function captureAnalytics(page) {
  await page.evaluate(() => {
    window.__seoSignupEvents = [];
    window.FPWAnalytics = window.FPWAnalytics || {};
    window.FPWAnalytics.track = (eventName, params) => {
      window.__seoSignupEvents.push({ eventName, params });
    };
  });
}

async function fillValidJoinForm(page) {
  await page.locator("#firstName").fill("Codex");
  await page.locator("#lastName").fill("Attribution");
  await page.locator("#email").fill("codex-attribution@example.com");
  await page.locator("#password").fill("AttributionPass123!");
  await page.locator("#confirmPassword").fill("AttributionPass123!");
  await page.locator("#termsAccepted").check();
}

async function stubSignup(page, responses) {
  const requests = [];
  let responseIndex = 0;

  await page.route("**/api/v1/join.cfc?method=handle", async (route) => {
    requests.push(route.request().postDataJSON());
    const response = responses[Math.min(responseIndex, responses.length - 1)];
    responseIndex += 1;
    await route.fulfill({
      status: response.status || 200,
      contentType: "application/json",
      body: JSON.stringify(response.body)
    });
  });

  return requests;
}

async function openJoin(page, storedValue) {
  if (storedValue !== undefined) {
    await page.addInitScript(({ key, value }) => {
      window.sessionStorage.setItem(key, JSON.stringify(value));
    }, { key: storageKey, value: storedValue });
  }
  const response = await page.goto(joinUrl, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);
  await captureAnalytics(page);
}

for (const landing of landingPages) {
  test(`${landing.name} signed-out CTA stores only its approved signup attribution`, async ({ page }) => {
    const response = await page.goto(landing.url, { waitUntil: "domcontentloaded" });
    expect(response && response.status()).toBe(200);
    await page.evaluate(() => {
      window.sessionStorage.removeItem("fpw_signup_attribution");
      document.addEventListener("click", (event) => {
        if (event.target.closest("[data-fpw-action-cta]")) event.preventDefault();
      }, true);
    });

    await page.locator(landing.selector).click();

    const stored = await page.evaluate((key) => window.sessionStorage.getItem(key), storageKey);
    expect(JSON.parse(stored)).toEqual(landing.attribution);
    expect(Object.keys(JSON.parse(stored)).sort()).toEqual([
      "cta_type",
      "landing_key",
      "source_content_type"
    ]);
  });
}

test("signed-in or unknown CTA values do not create signup attribution", async ({ page }) => {
  await page.goto(landingPages[0].url, { waitUntil: "domcontentloaded" });
  await page.evaluate(() => {
    document.addEventListener("click", (event) => {
      if (event.target.closest("[data-fpw-action-cta]")) event.preventDefault();
    }, true);
  });
  const cta = page.locator(landingPages[0].selector);

  await cta.evaluate((element) => {
    element.setAttribute("data-fpw-track-auth-state", "signed_in");
    element.setAttribute("data-fpw-track-destination-key", "dashboard");
  });
  await cta.click();
  await expect.poll(() => page.evaluate((key) => window.sessionStorage.getItem(key), storageKey)).toBeNull();

  await cta.evaluate((element) => {
    element.setAttribute("data-fpw-track-auth-state", "signed_out");
    element.setAttribute("data-fpw-track-destination-key", "join");
    element.setAttribute("data-fpw-track-source-page", "unknown_landing");
  });
  await cta.click();
  await expect.poll(() => page.evaluate((key) => window.sessionStorage.getItem(key), storageKey)).toBeNull();
});

test("sessionStorage failure does not block normal CTA navigation", async ({ page }) => {
  await page.addInitScript(() => {
    Storage.prototype.setItem = function () {
      throw new Error("storage unavailable");
    };
  });
  await page.goto(landingPages[0].url, { waitUntil: "domcontentloaded" });

  await page.locator(landingPages[0].selector).click();

  await expect(page).toHaveURL(joinUrl);
});

test("direct Join submits without attribution and emits unattributed signup events", async ({ page }) => {
  const requests = await stubSignup(page, [{
    body: { SUCCESS: true, AUTH: true, USERID: 1001, MESSAGE: "User created successfully." }
  }]);
  await openJoin(page);
  await fillValidJoinForm(page);

  await page.locator("#joinButton").click();
  await expect.poll(() => requests.length).toBe(1);
  await expect.poll(() => page.evaluate(() => window.__seoSignupEvents.length)).toBe(2);

  expect(requests[0]).not.toHaveProperty("landing_key");
  expect(requests[0]).not.toHaveProperty("source_content_type");
  expect(requests[0]).not.toHaveProperty("cta_type");
  expect(await page.evaluate(() => window.__seoSignupEvents)).toEqual([
    { eventName: "signup_start", params: { method: "email", source: "join_page" } },
    { eventName: "sign_up", params: { method: "email", source: "join_page" } }
  ]);
});

test("valid stored attribution reaches the API and both signup events, then clears", async ({ page }) => {
  const attribution = landingPages[1].attribution;
  const sequence = [];
  const requests = [];
  await page.exposeFunction("recordSeoSignupSequence", (entry) => sequence.push(entry));
  await page.route("**/api/v1/join.cfc?method=handle", async (route) => {
    sequence.push("api");
    requests.push(route.request().postDataJSON());
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ SUCCESS: true, AUTH: true, USERID: 1002, MESSAGE: "User created successfully." })
    });
  });
  await openJoin(page, attribution);
  await page.evaluate(() => {
    window.FPWAnalytics.track = (eventName, params) => {
      window.__seoSignupEvents.push({ eventName, params });
      window.recordSeoSignupSequence(eventName);
    };
  });
  await fillValidJoinForm(page);

  await page.locator("#joinButton").click();
  await expect.poll(() => requests.length).toBe(1);
  await expect.poll(() => page.evaluate(() => window.__seoSignupEvents.length)).toBe(2);

  expect(requests[0]).toMatchObject(attribution);
  expect(await page.evaluate(() => window.__seoSignupEvents)).toEqual([
    { eventName: "signup_start", params: { method: "email", source: "join_page", ...attribution } },
    { eventName: "sign_up", params: { method: "email", source: "join_page", ...attribution } }
  ]);
  expect(await page.evaluate((key) => window.sessionStorage.getItem(key), storageKey)).toBeNull();
  expect(sequence).toEqual(["signup_start", "api", "sign_up"]);
});

test("validation failure does not emit signup_start or call the API", async ({ page }) => {
  const requests = await stubSignup(page, [{ body: { SUCCESS: true, AUTH: true, USERID: 1003 } }]);
  await openJoin(page, landingPages[0].attribution);
  await page.locator("#firstName").fill("Codex");
  await page.locator("#lastName").fill("Attribution");
  await page.locator("#email").fill("codex-attribution@example.com");
  await page.locator("#password").fill("AttributionPass123!");
  await page.locator("#confirmPassword").fill("AttributionPass123!");

  await page.locator("#joinButton").click();

  expect(requests).toHaveLength(0);
  expect(await page.evaluate(() => window.__seoSignupEvents)).toEqual([]);
});

test("failed request preserves attribution and retry does not duplicate signup_start", async ({ page }) => {
  const attribution = landingPages[0].attribution;
  const requests = await stubSignup(page, [
    { status: 400, body: { SUCCESS: false, MESSAGE: "Synthetic failure." } },
    { body: { SUCCESS: true, AUTH: true, USERID: 1004, MESSAGE: "User created successfully." } }
  ]);
  await openJoin(page, attribution);
  await fillValidJoinForm(page);

  await page.locator("#joinButton").click();
  await expect.poll(() => requests.length).toBe(1);
  await expect(page.locator("#joinButton")).toBeEnabled();
  expect(JSON.parse(await page.evaluate((key) => window.sessionStorage.getItem(key), storageKey))).toEqual(attribution);

  await page.locator("#joinButton").click();
  await expect.poll(() => requests.length).toBe(2);
  await expect.poll(() => page.evaluate(() => (
    window.__seoSignupEvents.filter((event) => event.eventName === "sign_up").length
  ))).toBe(1);

  const events = await page.evaluate(() => window.__seoSignupEvents);
  expect(events.filter((event) => event.eventName === "signup_start")).toHaveLength(1);
  expect(events.filter((event) => event.eventName === "sign_up")).toHaveLength(1);
  expect(await page.evaluate((key) => window.sessionStorage.getItem(key), storageKey)).toBeNull();
});

test("non-auth success does not emit sign_up or clear attribution", async ({ page }) => {
  const attribution = landingPages[0].attribution;
  const requests = await stubSignup(page, [{
    body: { SUCCESS: true, AUTH: false, MESSAGE: "User created successfully." }
  }]);
  await openJoin(page, attribution);
  await fillValidJoinForm(page);

  await page.locator("#joinButton").click();
  await expect.poll(() => requests.length).toBe(1);

  const events = await page.evaluate(() => window.__seoSignupEvents);
  expect(events.filter((event) => event.eventName === "signup_start")).toHaveLength(1);
  expect(events.filter((event) => event.eventName === "sign_up")).toHaveLength(0);
  expect(JSON.parse(await page.evaluate((key) => window.sessionStorage.getItem(key), storageKey))).toEqual(attribution);
});

test("invalid stored attribution is ignored by analytics and the API", async ({ page }) => {
  const requests = await stubSignup(page, [{
    body: { SUCCESS: true, AUTH: true, USERID: 1005, MESSAGE: "User created successfully." }
  }]);
  await openJoin(page, {
    landing_key: "boat_fuel_calculator",
    source_content_type: "seo_hub",
    cta_type: "plan_route"
  });
  await fillValidJoinForm(page);

  await page.locator("#joinButton").click();
  await expect.poll(() => requests.length).toBe(1);

  expect(requests[0]).not.toHaveProperty("landing_key");
  expect(requests[0]).not.toHaveProperty("source_content_type");
  expect(requests[0]).not.toHaveProperty("cta_type");
  for (const event of await page.evaluate(() => window.__seoSignupEvents)) {
    expect(event.params).not.toHaveProperty("landing_key");
    expect(event.params).not.toHaveProperty("source_content_type");
    expect(event.params).not.toHaveProperty("cta_type");
  }
});

test("server source accepts only the approved tuples on sign_up metadata", () => {
  const joinSource = readFileSync(path.join(repositoryRoot, "api/v1/join.cfc"), "utf8");
  const eventServiceSource = readFileSync(path.join(repositoryRoot, "includes/ProductEventService.cfc"), "utf8");

  expect(joinSource).toContain('(landingKey EQ "boat_fuel_calculator" AND sourceContentType EQ "seo_tool")');
  expect(joinSource).toContain('(landingKey EQ "great_loop_locks" AND sourceContentType EQ "seo_hub")');
  expect(joinSource).toContain('ctaType NEQ "plan_route"');
  expect(joinSource).toContain("metadata = signUpEventMetadata");
  expect(eventServiceSource).toContain('landing_key = [ "boat_fuel_calculator", "great_loop_locks" ]');
  expect(eventServiceSource).toContain('source_content_type = [ "seo_tool", "seo_hub" ]');
  expect(eventServiceSource).toContain('cta_type = [ "plan_route" ]');
});
