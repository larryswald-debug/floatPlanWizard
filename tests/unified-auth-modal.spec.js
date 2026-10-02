const { test, expect } = require("@playwright/test");

const guideUrl = "http://localhost:8500/fpw/great-loop/trip-planning/";

async function prepareModal(page) {
  await page.goto(guideUrl);
  await page.evaluate(() => {
    window.__authModalEvents = [];
    window.__authModalNavigations = [];
    window.__authModalDismissals = [];
    window.FPWAnalytics.track = (name, params) => window.__authModalEvents.push({ name, params });
    window.Api.dismissAuthIntent = (token) => {
      window.__authModalDismissals.push(token);
      return Promise.resolve({ SUCCESS: true });
    };
    window.AppAuth.navigateContinuation = (url) => window.__authModalNavigations.push(url);
    window.__openAuthForTest = () => window.FPWAuthModal.open({
      bootstrap: {
        SUCCESS: true,
        AUTH: false,
        INTENT_TOKEN: "a".repeat(64),
        DISCLOSURE: {
          REVISION: "test-revision",
          TEXT: "Continue to log in or create an account.",
          TERMS_URL: "/fpw/terms_of_service.cfm",
          PRIVACY_URL: "/fpw/privacy_policy.cfm"
        }
      },
      destinationKey: "planner",
      context: {},
      source: {
        source_page: "great_loop_trip_planning",
        section: "after_planning_guide",
        cta_type: "plan_trip",
        label: "Start Planning"
      },
      trigger: document.querySelector("#great-loop-trip-planning-cta a")
    });
  });
}

async function fillCredentials(page) {
  await page.locator("#fpwAuthEmail").fill("modal-test@example.com");
  await page.locator("#fpwAuthPassword").fill("ExamplePass123!");
}

test("native auth dialog restores focus and cancels its intent", async ({ page }) => {
  await prepareModal(page);
  await page.evaluate(() => window.__openAuthForTest());
  await expect(page.locator("#fpwAuthModal")).toBeVisible();
  await expect(page.locator("#fpwAuthEmail")).toBeFocused();
  await expect(page.locator("#fpwAuthModal")).toHaveAttribute("data-clarity-mask", "True");
  await page.keyboard.press("Shift+Tab");
  expect(await page.locator("#fpwAuthModal").evaluate(dialog => dialog.contains(document.activeElement))).toBe(true);
  await page.keyboard.press("Escape");
  await expect(page.locator("#fpwAuthModal")).not.toBeVisible();
  await expect(page.locator("#great-loop-trip-planning-cta a")).toBeFocused();
  const result = await page.evaluate(() => ({
    dismissals: window.__authModalDismissals,
    events: window.__authModalEvents
  }));
  expect(result.dismissals).toEqual(["a".repeat(64)]);
  expect(result.events.map((event) => event.name)).toEqual(["auth_modal_open", "auth_modal_cancelled"]);
});

test("double submits and late completion after close cannot navigate", async ({ page }) => {
  await prepareModal(page);
  await page.evaluate(() => {
    window.__authCalls = 0;
    window.AppAuth.continueAuthentication = () => {
      window.__authCalls++;
      return new Promise((resolve) => { window.__resolveAuth = resolve; });
    };
    window.__openAuthForTest();
  });
  await fillCredentials(page);
  await page.evaluate(() => {
    document.getElementById("fpwAuthForm").requestSubmit();
    document.getElementById("fpwAuthForm").requestSubmit();
  });
  expect(await page.evaluate(() => window.__authCalls)).toBe(1);
  await page.locator("[data-fpw-auth-close]").click();
  await page.evaluate(() => window.__resolveAuth({
    SUCCESS: true, AUTH: true, ACCOUNT_CREATED: true, REDIRECT_URL: "/fpw/app/dashboard.cfm"
  }));
  expect(await page.evaluate(() => window.__authModalNavigations)).toEqual([]);
  expect(await page.evaluate(() => window.__authModalEvents.map((event) => event.name)))
    .toEqual(["auth_modal_open", "auth_continue_submit", "auth_modal_cancelled"]);
});

test("only confirmed auth emits success and telemetry contains no credentials", async ({ page }) => {
  await prepareModal(page);
  await page.evaluate(() => {
    window.AppAuth.continueAuthentication = () => Promise.resolve({
      SUCCESS: true, AUTH: false, ACCOUNT_CREATED: false, MESSAGE: "Unable to continue."
    });
    window.__openAuthForTest();
  });
  await fillCredentials(page);
  await page.locator("#fpwAuthContinue").click();
  await expect(page.locator("#fpwAuthAlert")).toBeVisible();
  expect(await page.evaluate(() => window.__authModalNavigations)).toEqual([]);
  await page.evaluate(() => {
    window.AppAuth.continueAuthentication = () => Promise.resolve({
      SUCCESS: true, AUTH: true, ACCOUNT_CREATED: true,
      REDIRECT_URL: "/fpw/app/dashboard.cfm?authIntent=" + "b".repeat(64)
    });
  });
  await page.locator("#fpwAuthContinue").click();
  await expect.poll(() => page.evaluate(() => window.__authModalNavigations.length)).toBe(1);
  const events = await page.evaluate(() => window.__authModalEvents);
  expect(events.map((event) => event.name)).toEqual([
    "auth_modal_open", "auth_continue_submit", "auth_failure",
    "auth_continue_submit", "auth_account_created"
  ]);
  const encoded = JSON.stringify(events);
  expect(encoded).not.toContain("modal-test@example.com");
  expect(encoded).not.toContain("ExamplePass123!");
  expect(encoded).not.toContain("sign_up");
  expect(events.every((event) => Object.keys(event.params).sort().join(",") === "cta_type,label,section,source_page")).toBe(true);
});

test("changed disclosure refreshes without resubmitting credentials", async ({ page }) => {
  await prepareModal(page);
  await page.evaluate(() => {
    window.__authCalls = 0;
    window.__submittedRevisions = [];
    window.Api.authBootstrap = () => Promise.resolve({
      SUCCESS: true, AUTH: false, INTENT_TOKEN: "a".repeat(64),
      DISCLOSURE: {
        REVISION: "updated-revision", TEXT: "Updated terms disclosure.",
        TERMS_URL: "/fpw/terms_of_service.cfm", PRIVACY_URL: "/fpw/privacy_policy.cfm"
      }
    });
    window.AppAuth.continueAuthentication = (payload) => {
      window.__authCalls++;
      window.__submittedRevisions.push(payload.disclosureRevision);
      if (window.__authCalls === 1) return Promise.reject({ ERROR: "CONSENT_UPDATED" });
      return Promise.resolve({ SUCCESS: true, AUTH: true, ACCOUNT_CREATED: false, REDIRECT_URL: "/fpw/app/account.cfm" });
    };
    window.__openAuthForTest();
  });
  await fillCredentials(page);
  await page.locator("#fpwAuthContinue").click();
  await expect(page.locator("#fpwAuthDisclosureText")).toHaveText("Updated terms disclosure.");
  expect(await page.evaluate(() => window.__authCalls)).toBe(1);
  await expect(page.locator("#fpwAuthEmail")).toHaveValue("modal-test@example.com");
  await expect(page.locator("#fpwAuthPassword")).toHaveValue("ExamplePass123!");
  await page.locator("#fpwAuthContinue").click();
  await expect.poll(() => page.evaluate(() => window.__authModalNavigations.length)).toBe(1);
  expect(await page.evaluate(() => window.__submittedRevisions)).toEqual(["test-revision", "updated-revision"]);
});

test("native dialog preserves page scroll and mobile cancellation restores a visible control", async ({ page }) => {
  await prepareModal(page);
  await page.evaluate(() => {
    document.documentElement.style.setProperty("overflow", "auto");
    window.scrollTo({ top: 500, behavior: "instant" });
    window.__openAuthForTest();
  });
  const before = await page.evaluate(() => window.scrollY);
  await page.mouse.move(10, 400);
  await page.mouse.wheel(0, 700);
  await page.waitForTimeout(250);
  expect(await page.evaluate(() => window.scrollY)).toBe(before);
  await page.keyboard.press("Escape");
  expect(await page.evaluate(() => window.scrollY)).toBe(before);
  expect(await page.evaluate(() => document.documentElement.style.overflow)).toBe("auto");
  await page.setViewportSize({ width: 390, height: 844 });
  const menu = page.locator("[data-fpw-mobile-toggle]");
  await menu.click();
  await page.locator('a[data-fpw-auth-intent="dashboard"][data-fpw-auth-source-page="top_nav"]').click();
  await expect(page.locator("#fpwAuthModal")).toBeVisible();
  await expect(menu).toHaveAttribute("aria-expanded", "false");
  await page.keyboard.press("Escape");
  await expect(menu).toBeFocused();
});
