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

async function submitLoginForm(page, options) {
  const opts = options || {};
  const creds = requireCredentials();
  const email = typeof opts.email === "string" ? opts.email : creds.email;
  const password = typeof opts.password === "string" ? opts.password : creds.password;
  const loginUrl = typeof opts.loginUrl === "string" ? opts.loginUrl : "/fpw/index.cfm";
  const waitUntil = typeof opts.waitUntil === "string" ? opts.waitUntil : "domcontentloaded";

  await page.goto(loginUrl, { waitUntil: waitUntil });
  const publicLoginToggle = page.locator("#publicLoginToggle");
  const loginStrip = page.locator("#login");
  if (await publicLoginToggle.isVisible().catch(() => false)) {
    const stripOpen = await loginStrip.evaluate((el) => el.classList.contains("is-open")).catch(() => false);
    if (!stripOpen) {
      await publicLoginToggle.click();
      await expect(loginStrip).toHaveClass(/is-open/, { timeout: 10000 });
    }
  }
  await page.fill('input[name="email"], input[name="EMAIL"]', email);
  await page.fill('input[type="password"], input[name="password"], input[name="PASSWORD"]', password);
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
