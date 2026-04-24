const { test, expect } = require("@playwright/test");

function requireCredentials() {
  if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
    throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
  }
  return {
    email: process.env.FPW_EMAIL || "",
    password: process.env.FPW_PASSWORD || ""
  };
}

async function isLocatorVisible(locator) {
  return locator.first().isVisible().catch(() => false);
}

async function isAuthenticatedShellVisible(page) {
  const markers = [
    page.locator("#missionSummaryTitle"),
    page.locator("#openRouteBuilderBtn"),
    page.locator("#logoutButton"),
    page.locator('nav[aria-label="App Primary"]'),
    page.locator('button:has-text("Generate Route")')
  ];
  for (const marker of markers) {
    if (await isLocatorVisible(marker)) {
      return true;
    }
  }
  return false;
}

async function waitForLoginSurface(page) {
  await page.waitForFunction(() => {
    function isVisible(node) {
      return !!(node && node.getClientRects && node.getClientRects().length);
    }
    const emailInput = document.querySelector('input[name="email"], input[name="EMAIL"], #loginForm input[type="email"]');
    const publicToggle = document.querySelector("#publicLoginToggle, #fpwMobilePublicLoginLink");
    const authenticated = !!(
      document.getElementById("missionSummaryTitle")
      || document.getElementById("openRouteBuilderBtn")
      || document.getElementById("logoutButton")
      || document.querySelector('nav[aria-label="App Primary"]')
      || document.querySelector('button[id="openRouteBuilderBtn"]')
    );
    return authenticated || isVisible(emailInput) || isVisible(publicToggle);
  }, { timeout: 10000 }).catch(() => {});
}

async function exposeLoginForm(page, emailInput) {
  if (await isLocatorVisible(emailInput)) {
    return;
  }
  const toggleCandidates = [
    page.locator("#publicLoginToggle"),
    page.locator("#fpwMobilePublicLoginLink"),
    page.getByRole("link", { name: /^Log in$/i }),
    page.getByRole("button", { name: /^Log in$/i })
  ];
  for (const toggle of toggleCandidates) {
    if (!(await isLocatorVisible(toggle))) {
      continue;
    }
    await toggle.first().click();
    if (await isAuthenticatedShellVisible(page)) {
      return;
    }
    try {
      await expect(emailInput).toBeVisible({ timeout: 10000 });
      return;
    } catch (error) {
      if (await isAuthenticatedShellVisible(page)) {
        return;
      }
    }
  }
}

async function submitLoginForm(page, options) {
  const opts = options || {};
  const creds = requireCredentials();
  const email = typeof opts.email === "string" ? opts.email : creds.email;
  const password = typeof opts.password === "string" ? opts.password : creds.password;
  const loginUrl = typeof opts.loginUrl === "string" ? opts.loginUrl : "/fpw/index.cfm";
  const waitUntil = typeof opts.waitUntil === "string" ? opts.waitUntil : "domcontentloaded";

  await page.goto(loginUrl, { waitUntil: waitUntil });
  await waitForLoginSurface(page);

  const emailInput = page.locator('input[name="email"], input[name="EMAIL"], #loginForm input[type="email"]').first();
  const passwordInput = page.locator('input[type="password"], input[name="password"], input[name="PASSWORD"]').first();

  if (await isAuthenticatedShellVisible(page)) {
    return;
  }

  if (!(await isLocatorVisible(emailInput))) {
    await exposeLoginForm(page, emailInput);
  }

  if (await isAuthenticatedShellVisible(page)) {
    return;
  }

  await expect(emailInput).toBeVisible({ timeout: 10000 });
  await expect(passwordInput).toBeVisible({ timeout: 10000 });
  await emailInput.fill(email);
  await passwordInput.fill(password);
  await page.evaluate(() => {
    var form = document.getElementById("loginForm");
    if (!form) return;
    if (typeof form.requestSubmit === "function") {
      form.requestSubmit();
      return;
    }
    form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
  });
}

async function loginAsTestUser(page, options) {
  await submitLoginForm(page, options);
}

test.afterEach(async ({ page }, testInfo) => {
  if (testInfo.status !== testInfo.expectedStatus) {
    console.log(`❌ Test failed: ${testInfo.title}`);
    if (process.env.PW_DEBUG_PAUSE_ON_FAIL === "1") {
      await page.pause();
    }
  }
});

module.exports = {
  requireCredentials,
  submitLoginForm,
  loginAsTestUser
};
