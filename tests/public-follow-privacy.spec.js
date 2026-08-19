const { test, expect } = require("@playwright/test");

const baseUrl = process.env.FPW_BASE_URL || "http://localhost:8500/fpw";
const fixturePath = "/tests/public-follow-privacy-browser-fixture.cfm";
const confirmation = "RUN_PUBLIC_FOLLOW_PRIVACY_BROWSER_FIXTURE";
let fixture = null;

function apiUrl(slug, token) {
  const params = new URLSearchParams({
    method: "handle",
    action: "getStreamBootstrap",
    slug,
    t: token,
    returnFormat: "json"
  });
  return `${baseUrl}/api/v1/voyage.cfc?${params.toString()}`;
}

function allKeys(value, keys = []) {
  if (Array.isArray(value)) {
    value.forEach((item) => allKeys(item, keys));
    return keys;
  }
  if (!value || typeof value !== "object") return keys;
  Object.keys(value).forEach((key) => {
    keys.push(key.toLowerCase());
    allKeys(value[key], keys);
  });
  return keys;
}

function expectNoInternalAccountKeys(payload) {
  const keys = allKeys(payload);
  expect(keys).not.toContain("owner_user_id");
  expect(keys).not.toContain("author_user_id");
  expect(keys).not.toContain("user_id");
  expect(keys).not.toContain("userid");
  expect(keys).not.toContain("member_id");
  expect(keys).not.toContain("account_id");
}

test.describe.serial("QA6-005 public Follow privacy runtime", () => {
  test.beforeAll(async ({ request }) => {
    const response = await request.get(
      `${baseUrl}${fixturePath}?action=setup&confirm=${confirmation}`
    );
    expect(response.status()).toBe(200);
    fixture = await response.json();
    expect(fixture.SUCCESS).toBe(true);
  });

  test.afterAll(async ({ request }) => {
    await request.get(
      `${baseUrl}${fixturePath}?action=cleanup&confirm=${confirmation}`
    );
  });

  test("new opaque identifiers preserve exact slug and token isolation", async ({ request }) => {
    expect(fixture.NEW_A.SLUG).toMatch(/^trip-[a-f0-9]{32}$/);
    expect(fixture.NEW_B.SLUG).toMatch(/^trip-[a-f0-9]{32}$/);
    expect(fixture.NEW_A.SLUG).not.toContain(String(fixture.NEW_A.OWNER_USER_ID_FOR_ASSERTION));
    expect(fixture.NEW_B.SLUG).not.toContain(String(fixture.NEW_B.OWNER_USER_ID_FOR_ASSERTION));

    const validResponse = await request.get(apiUrl(fixture.NEW_A.SLUG, fixture.NEW_A.TOKEN));
    const validPayload = await validResponse.json();
    expect(validResponse.status()).toBe(200);
    expect(validPayload.SUCCESS).toBe(true);
    expect((validPayload.stream || validPayload.STREAM).is_owner).toBe(false);
    expectNoInternalAccountKeys(validPayload);

    const wrongTokenPayload = await (
      await request.get(apiUrl(fixture.NEW_A.SLUG, "f".repeat(64)))
    ).json();
    expect(wrongTokenPayload.SUCCESS).toBe(false);
    expect(wrongTokenPayload.ERROR.CODE).toBe("INVALID_SHARE_TOKEN");

    const crossTripPayload = await (
      await request.get(apiUrl(fixture.NEW_B.SLUG, fixture.NEW_A.TOKEN))
    ).json();
    expect(crossTripPayload.SUCCESS).toBe(false);
    expect(crossTripPayload.ERROR.CODE).toBe("INVALID_SHARE_TOKEN");

    const tamperedSlugPayload = await (
      await request.get(apiUrl(`${fixture.NEW_A.SLUG}0`, fixture.NEW_A.TOKEN))
    ).json();
    expect(tamperedSlugPayload.SUCCESS).toBe(false);
    expect(tamperedSlugPayload.MESSAGE).toBe("Stream not found");
  });

  test("new Follow and Full Map pages render without internal account identifiers", async ({ page }) => {
    const consoleErrors = [];
    const localFailures = [];
    const publicPayloads = [];

    page.on("console", (message) => {
      if (message.type() === "error") consoleErrors.push(message.text());
    });
    page.on("requestfailed", (request) => {
      if (request.url().startsWith(baseUrl)) {
        localFailures.push(`${request.method()} ${request.url()}`);
      }
    });
    page.on("response", async (response) => {
      if (!response.url().includes("/api/v1/voyage.cfc")) return;
      const contentType = response.headers()["content-type"] || "";
      if (!contentType.includes("application/json")) return;
      try {
        publicPayloads.push(await response.json());
      } catch (_) {
        // A malformed response will be caught by the page failing to finish loading.
      }
    });

    const followResponse = await page.goto(`${baseUrl}${fixture.NEW_A.URL}`, {
      waitUntil: "domcontentloaded"
    });
    expect(followResponse.status()).toBe(200);
    await page.waitForFunction(() => !document.body.classList.contains("follow-loading"));
    await expect(page.locator('[data-fpw-field="page-title"]')).not.toHaveText("—");

    const followHtml = (await page.content()).toLowerCase();
    expect(followHtml).not.toContain("owner_user_id");
    expect(followHtml).not.toContain("author_user_id");
    expect(followHtml).not.toContain(`>${fixture.NEW_A.OWNER_USER_ID_FOR_ASSERTION}<`);

    const fullMapResponse = await page.goto(`${baseUrl}${fixture.NEW_A.FULL_MAP_URL}`, {
      waitUntil: "domcontentloaded"
    });
    expect(fullMapResponse.status()).toBe(200);
    await expect(page.locator("#followFullMapTitle")).not.toContainText("Loading");

    expect(publicPayloads.length).toBeGreaterThan(0);
    expect(publicPayloads.some((payload) => payload.stream || payload.STREAM)).toBe(true);
    expect(publicPayloads.some((payload) => Array.isArray(payload.posts || payload.POSTS))).toBe(true);
    publicPayloads.forEach(expectNoInternalAccountKeys);
    expect(localFailures).toEqual([]);
    expect(consoleErrors).toEqual([]);
  });

  test("an issued legacy slug still renders under the private DTO contract", async ({ page, request }) => {
    const legacyApiResponse = await request.get(
      apiUrl(fixture.LEGACY_A.SLUG, fixture.LEGACY_A.TOKEN)
    );
    const legacyPayload = await legacyApiResponse.json();
    expect(legacyApiResponse.status()).toBe(200);
    expect(legacyPayload.SUCCESS).toBe(true);
    expectNoInternalAccountKeys(legacyPayload);

    const response = await page.goto(`${baseUrl}${fixture.LEGACY_A.URL}`, {
      waitUntil: "domcontentloaded"
    });
    expect(response.status()).toBe(200);
    await page.waitForFunction(() => !document.body.classList.contains("follow-loading"));
    await expect(page.locator('[data-fpw-field="page-title"]')).not.toHaveText("—");
  });
});
