require("./test-hooks");

if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
  throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
}

const { test, expect } = require("@playwright/test");

test.describe.configure({ timeout: 120000 });

function uniqueSuffix() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

async function login(page) {
  await page.goto("/fpw/index.cfm", { waitUntil: "domcontentloaded" });
  await page.fill('input[name="email"], input[name="EMAIL"]', process.env.FPW_EMAIL || "");
  await page.fill('input[type="password"], input[name="password"], input[name="PASSWORD"]', process.env.FPW_PASSWORD || "");
  await page.click('button[type="submit"], input[type="submit"]');
  await page.waitForURL(/\/fpw\/app\/dashboard\.cfm/i, { timeout: 30000 });
}

async function openAccount(page) {
  await page.goto("/fpw/app/account.cfm", { waitUntil: "domcontentloaded" });
  await page.waitForLoadState("networkidle");
  await expect(page.locator("#homePortForm")).toBeVisible({ timeout: 30000 });
  await expect(page.locator("#saveHomePortBtn")).toBeVisible({ timeout: 30000 });
  await page.waitForFunction(() => {
    var emailEl = document.getElementById("emailDisplay");
    if (!emailEl) return false;
    var text = String(emailEl.textContent || "").trim().toLowerCase();
    return !!text && text !== "loading…" && text !== "loading...";
  }, { timeout: 30000 });
}

async function readHomePort(page) {
  return {
    address: await page.locator("#homeAddress").inputValue(),
    city: await page.locator("#homeCity").inputValue(),
    state: await page.locator("#homeState").inputValue(),
    zip: await page.locator("#homeZip").inputValue(),
    phone: await page.locator("#homePhone").inputValue(),
    lat: await page.locator("#homeLat").inputValue(),
    lng: await page.locator("#homeLng").inputValue()
  };
}

async function fillHomePort(page, values) {
  await page.locator("#homeAddress").fill(values.address);
  await page.locator("#homeCity").fill(values.city);
  await page.locator("#homeState").fill(values.state);
  await page.locator("#homeZip").fill(values.zip);
  await page.locator("#homePhone").fill(values.phone);
  await page.locator("#homeLat").fill(values.lat);
  await page.locator("#homeLng").fill(values.lng);
}

async function saveHomePortAndAcceptAlert(page, expectedMessageRegex) {
  const dialogPromise = page.waitForEvent("dialog", { timeout: 20000 });
  await page.locator("#saveHomePortBtn").click();
  const dialog = await dialogPromise;
  expect(dialog.message()).toMatch(expectedMessageRegex);
  await dialog.accept();
  await expect(page.locator("#saveHomePortBtn")).toHaveText("Save Home Port", { timeout: 10000 });
}

test("Account Home Port saves and persists after reload", async ({ page, browserName }) => {
  test.skip(browserName !== "chromium", "Home Port persistence writes shared account state.");

  await login(page);
  await openAccount(page);

  const initial = await readHomePort(page);
  const suffix = uniqueSuffix();
  const payload = {
    address: `PW Dock ${suffix}`,
    city: `TestCity${suffix.slice(-4)}`,
    state: "TS",
    zip: "02110",
    phone: "5555559090",
    lat: "42.3601",
    lng: "-71.0589"
  };

  await fillHomePort(page, payload);
  await saveHomePortAndAcceptAlert(page, /Home port saved/i);

  await expect(page.locator("#homeAddress")).toHaveValue(payload.address);
  await expect(page.locator("#homeCity")).toHaveValue(payload.city);
  await expect(page.locator("#homeState")).toHaveValue(payload.state);
  await expect(page.locator("#homeZip")).toHaveValue(payload.zip);
  await expect(page.locator("#homePhone")).toHaveValue(payload.phone);
  await expect(page.locator("#homeLat")).toHaveValue(payload.lat);
  await expect(page.locator("#homeLng")).toHaveValue(payload.lng);

  await page.reload({ waitUntil: "domcontentloaded" });
  await expect(page.locator("#homePortForm")).toBeVisible({ timeout: 30000 });
  await expect(page.locator("#homeAddress")).toHaveValue(payload.address, { timeout: 30000 });
  await expect(page.locator("#homeCity")).toHaveValue(payload.city);
  await expect(page.locator("#homeState")).toHaveValue(payload.state);
  await expect(page.locator("#homeZip")).toHaveValue(payload.zip);
  await expect(page.locator("#homePhone")).toHaveValue(payload.phone);
  await expect(page.locator("#homeLat")).toHaveValue(payload.lat);
  await expect(page.locator("#homeLng")).toHaveValue(payload.lng);

  const canRestore =
    (initial.address && initial.address.trim()) ||
    (initial.city && initial.city.trim()) ||
    (initial.state && initial.state.trim()) ||
    (initial.zip && initial.zip.trim());

  if (canRestore) {
    await fillHomePort(page, {
      address: initial.address || "",
      city: initial.city || "",
      state: initial.state || "",
      zip: initial.zip || "",
      phone: initial.phone || "",
      lat: initial.lat || "",
      lng: initial.lng || ""
    });
    await saveHomePortAndAcceptAlert(page, /Home port saved/i);
  }
});
