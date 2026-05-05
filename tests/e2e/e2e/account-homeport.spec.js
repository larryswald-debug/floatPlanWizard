require("./test-hooks");

if (!process.env.FPW_EMAIL || !process.env.FPW_PASSWORD) {
  throw new Error("Missing FPW_EMAIL / FPW_PASSWORD env vars");
}

const { test, expect } = require("@playwright/test");
const { loginApprovedUser } = require("../support/fpwSession");

test.describe.configure({ timeout: 120000 });

function uniqueSuffix() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

async function login(page) {
  await loginApprovedUser(page);
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

function jsonResponse(payload, status = 200) {
  return {
    status,
    contentType: "application/json",
    body: JSON.stringify(payload)
  };
}

function parsePostBody(request) {
  try {
    return JSON.parse(request.postData() || "{}");
  } catch (err) {
    return {};
  }
}

async function mockAccountProfile(page) {
  await page.route("**/api/v1/profile.cfc?*", async (route) => {
    await route.fulfill(jsonResponse({
      SUCCESS: true,
      AUTH: true,
      PROFILE: {
        userId: 10001,
        fName: "Companion",
        lName: "Tester",
        email: "companion-ui-test@example.com",
        mobilePhone: "5555550101",
        lastLogin: "2026-05-05T12:00:00Z",
        lastUpdate: "2026-05-05T12:05:00Z",
        homePort: {
          address: "1 Test Pier",
          city: "Test Harbor",
          state: "TS",
          zip: "02110",
          phone: "5555550101",
          lat: "42.3601",
          lng: "-71.0589"
        }
      }
    }));
  });
}

async function mockCompanionAuth(page, state) {
  await page.route("**/api/v1/companionAuth.cfc?*", async (route) => {
    const url = new URL(route.request().url());
    const action = String(url.searchParams.get("action") || "").toLowerCase();

    if (action === "listdevices") {
      await route.fulfill(jsonResponse({
        SUCCESS: true,
        AUTH: true,
        DEVICES: state.devices
      }));
      return;
    }

    if (action === "createpairingcode") {
      state.createCalls += 1;
      await route.fulfill(jsonResponse({
        SUCCESS: true,
        AUTH: true,
        PAIRING_CODE: "ABCD-2345",
        EXPIRES_AT_UTC: "2026-05-05T18:10:00Z",
        PAIRING_URI: "fpwcompanion://pair?code=ABCD-2345"
      }));
      return;
    }

    if (action === "revokedevice") {
      const body = parsePostBody(route.request());
      state.revokeCalls.push(body);
      state.devices = state.devices.map((device) => {
        if (Number(device.id) === Number(body.deviceId)) {
          return { ...device, revokedAtUtc: "2026-05-05T18:05:00Z" };
        }
        return device;
      });
      await route.fulfill(jsonResponse({
        SUCCESS: true,
        AUTH: true,
        DEVICE_ID: body.deviceId
      }));
      return;
    }

    await route.fulfill(jsonResponse({
      SUCCESS: false,
      AUTH: true,
      ERROR: "UNEXPECTED_TEST_ACTION",
      MESSAGE: `Unexpected companion auth action: ${action}`
    }, 400));
  });
}

test("Account Companion Devices shows empty state and manual pairing code with mocked API", async ({ page }) => {
  const state = {
    devices: [],
    createCalls: 0,
    revokeCalls: []
  };

  await mockAccountProfile(page);
  await mockCompanionAuth(page, state);

  await openAccount(page);

  await expect(page.locator("#companionDevicesCard")).toBeVisible();
  await expect(page.locator("#companionDevicesEmpty")).toBeVisible();
  await expect(page.locator("#companionPairBtn")).toBeVisible();

  await page.locator("#companionPairBtn").click();

  await expect(page.locator("#companionPairingPanel")).toBeVisible();
  await expect(page.locator("#companionPairingCode")).toHaveText("ABCD-2345");
  await expect(page.locator("#companionPairingExpires")).toContainText("Expires at");
  await expect(page.locator("#companionDevicesCard")).not.toContainText("fpwc_");
  expect(state.createCalls).toBe(1);
});

test("Account Companion Devices revokes an active mocked device and keeps it visible", async ({ page }) => {
  const state = {
    devices: [{
      id: 777,
      deviceName: "Companion Test Phone",
      platform: "ios",
      appVersion: "1.0.0",
      createdUtc: "2026-05-01T12:00:00Z",
      lastUsedAtUtc: "2026-05-02T12:00:00Z",
      expiresAtUtc: "2099-01-01T00:00:00Z",
      revokedAtUtc: ""
    }],
    createCalls: 0,
    revokeCalls: []
  };

  await mockAccountProfile(page);
  await mockCompanionAuth(page, state);

  page.on("dialog", async (dialog) => {
    expect(dialog.message()).toContain("Revoke this companion device?");
    await dialog.accept();
  });

  await openAccount(page);

  const row = page.locator(".companion-device-row").first();
  await expect(row).toContainText("Companion Test Phone");
  await expect(row).toContainText("Active");

  await page.locator('[data-companion-revoke-device="777"]').click();

  await expect(row).toContainText("Revoked");
  await expect(page.locator('[data-companion-revoke-device="777"]')).toHaveCount(0);
  expect(state.revokeCalls).toHaveLength(1);
  expect(Number(state.revokeCalls[0].deviceId)).toBe(777);
});

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
