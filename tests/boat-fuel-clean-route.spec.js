const { test, expect } = require("@playwright/test");

const baseUrl = process.env.FPW_BASE_URL || "http://localhost:8500/fpw";
const cleanPath = "/boat-fuel-calculator/";
const nestedPath = "/boat-fuel-calculator/boat-fuel-calculator.cfm";
const expectedTitle = "Free Boat Fuel Calculator – Fuel Needed, Range & Trip Cost";
const expectedCanonical = "https://floatplanwizard.com/boat-fuel-calculator/";

test("clean URL serves the calculator without Tomcat directory output", async ({ request }) => {
  const response = await request.get(`${baseUrl}${cleanPath}`, { maxRedirects: 0 });
  const body = await response.text();

  expect(response.status()).toBe(200);
  expect(body).toContain(expectedTitle);
  expect(body).toContain("Boat Fuel Calculator");
  expect(body).not.toContain("Directory Listing For");
});

test("slash, query-string, and nested-route behavior match the production contract", async ({ page, request }) => {
  const noSlash = await request.get(`${baseUrl}/boat-fuel-calculator`, { maxRedirects: 0 });
  expect(noSlash.status()).toBe(301);
  expect(noSlash.headers().location).toBe("/fpw/boat-fuel-calculator/");

  const nested = await request.get(`${baseUrl}${nestedPath}`, { maxRedirects: 0 });
  expect(nested.status()).toBe(301);
  expect(nested.headers().location).toBe("/fpw/boat-fuel-calculator/");

  const queryResponse = await page.goto(`${baseUrl}${cleanPath}?utm_source=qa`, { waitUntil: "domcontentloaded" });
  expect(queryResponse && queryResponse.status()).toBe(200);
  expect(page.url()).toBe(`${baseUrl}${cleanPath}?utm_source=qa`);
  await expect(page).toHaveTitle(expectedTitle);
});

test("clean route preserves the calculator SEO and page contract", async ({ page }) => {
  const response = await page.goto(`${baseUrl}${cleanPath}`, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);

  await expect(page).toHaveTitle(expectedTitle);
  await expect(page.getByRole("heading", { name: "Boat Fuel Calculator", exact: true })).toBeVisible();
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute("href", expectedCanonical);
  await expect(page.locator('meta[name="description"]')).toHaveAttribute("content", /Free boat fuel calculator/);
  await expect(page.locator("#boat-fuel-calculator-plan-route-cta")).toBeVisible();

  const jsonLd = JSON.parse(await page.locator('script[type="application/ld+json"]').textContent());
  expect(Array.isArray(jsonLd["@graph"])).toBe(true);
  expect(jsonLd["@graph"].some((entity) => entity["@type"] === "WebPage" && entity.url === expectedCanonical)).toBe(true);
});

test("lock-detail contextual link opens the clean calculator route", async ({ page }) => {
  const response = await page.goto(`${baseUrl}/app/great-loop-lock.cfm?slug=lock-and-dam-12`, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);

  const calculatorLink = page.locator(".fpw-lock-continue-planning").getByRole("link", { name: "Boat Fuel Calculator" });
  await expect(calculatorLink).toHaveAttribute("href", "/fpw/boat-fuel-calculator/");
  await Promise.all([
    page.waitForURL(`${baseUrl}${cleanPath}`),
    calculatorLink.click()
  ]);
  await expect(page.getByRole("heading", { name: "Boat Fuel Calculator", exact: true })).toBeVisible();
  await expect(page.locator("body")).not.toContainText("Directory Listing For");
});

for (const width of [390, 760, 1440]) {
  test(`clean calculator route initializes at ${width}px`, async ({ page }) => {
    const pageErrors = [];
    const consoleErrors = [];
    const failedLocalResponses = [];

    page.on("pageerror", (error) => pageErrors.push(error.message));
    page.on("console", (message) => {
      if (message.type() === "error") consoleErrors.push(message.text());
    });
    page.on("response", (response) => {
      if (response.url().startsWith(baseUrl) && response.status() >= 400) {
        failedLocalResponses.push(`${response.status()} ${response.url()}`);
      }
    });

    await page.setViewportSize({ width, height: 1000 });
    const response = await page.goto(`${baseUrl}${cleanPath}`, { waitUntil: "domcontentloaded" });
    expect(response && response.status()).toBe(200);
    await expect(page.getByRole("heading", { name: "Boat Fuel Calculator", exact: true })).toBeVisible();
    await expect(page.locator("#qaFuelCalcForm")).toBeVisible();
    expect(await page.locator("body").textContent()).not.toContain("Directory Listing For");
    expect(pageErrors).toEqual([]);
    expect(consoleErrors).toEqual([]);
    expect(failedLocalResponses).toEqual([]);
  });
}

test("representative existing clean routes still resolve", async ({ request }) => {
  const routes = [
    { path: "/solo-boating-safety-guide/", marker: "Solo Boating Safety" },
    { path: "/shore-contact-overdue-boater/", marker: "What a Shore Contact Should Do" },
    { path: "/how-it-works/", marker: "How It Works" },
    { path: "/why-use-a-float-plan/", marker: "Why Use a Float Plan" },
    { path: "/great-loop/locks/", marker: "Great Loop Locks" }
  ];

  for (const route of routes) {
    const response = await request.get(`${baseUrl}${route.path}`, { maxRedirects: 0 });
    const body = await response.text();
    expect(response.status(), route.path).toBe(200);
    expect(body, route.path).toContain(route.marker);
    expect(body, route.path).not.toContain("Directory Listing For");
  }
});
