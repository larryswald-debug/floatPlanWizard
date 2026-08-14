const { test, expect } = require("@playwright/test");

const baseUrl = "http://localhost:8500/fpw";
const detailCases = [
  { slug: "lock-and-dam-12", title: "Lock and Dam 12" },
  { slug: "e11-amsterdam", title: "E11 Amsterdam" }
];
const requiredWidths = [1440, 1024, 760, 390];

function detailUrl(slug) {
  return `${baseUrl}/app/great-loop-lock.cfm?slug=${slug}`;
}

test("contextual resources render generically on multiple lock details", async ({ page }) => {
  for (const detail of detailCases) {
    const response = await page.goto(detailUrl(detail.slug), { waitUntil: "domcontentloaded" });
    expect(response.status()).toBe(200);
    await expect(page.locator("main h1")).toHaveText(detail.title);
    await expect(page.getByRole("heading", { name: "Related Safety Resources" })).toHaveCount(1);
    await expect(page.locator(".fpw-lock-related-resource")).toHaveCount(2);
    await expect(page.locator(".fpw-lock-continue-planning")).toHaveCount(1);
  }
});

test("rail placement, copy, destinations, and decorative icons match the contract", async ({ page }) => {
  await page.goto(detailUrl("lock-and-dam-12"), { waitUntil: "domcontentloaded" });

  const railHeadings = await page.locator(".fpw-lock-detail-rail h3").allTextContents();
  expect(railHeadings.map((value) => value.trim())).toEqual([
    "Before You Arrive",
    "Plan With FPW",
    "Related Safety Resources",
    "Official Source",
    "Navigation Safety Note"
  ]);

  const resources = page.locator(".fpw-lock-related-resources");
  const solo = resources.getByRole("link", { name: /Solo Boating Safety Guide/ });
  const shore = resources.getByRole("link", { name: /Shore Contact Guide/ });
  await expect(solo).toHaveAttribute("href", "/fpw/solo-boating-safety-guide/");
  await expect(shore).toHaveAttribute("href", "/fpw/shore-contact-overdue-boater/");
  await expect(solo).toContainText("Running the Loop solo? Review practical preparation, communications, self-recovery, and trip-planning guidance before departure.");
  await expect(shore).toContainText("Leaving a float plan with someone ashore? Make sure they know what to do if you miss a check-in or become overdue.");
  await expect(resources.locator("svg")).toHaveCount(2);
  await expect(resources.locator('svg[aria-hidden="true"][focusable="false"]')).toHaveCount(2);
  await expect(resources.locator("[data-fpw-track]")).toHaveCount(0);
});

test("Continue planning precedes the pager and preserves existing controls", async ({ page }) => {
  await page.goto(detailUrl("lock-and-dam-12"), { waitUntil: "domcontentloaded" });

  const planning = page.locator(".fpw-lock-continue-planning");
  await expect(planning).toContainText("Continue planning: Check Marine Weather, estimate your trip with the Boat Fuel Calculator, or review the Solo Boating Safety Guide.");
  await expect(planning.getByRole("link", { name: "Marine Weather" })).toHaveAttribute("href", "/fpw/app/weather.cfm");
  await expect(planning.getByRole("link", { name: "Boat Fuel Calculator" })).toHaveAttribute("href", "/fpw/boat-fuel-calculator/");
  await expect(planning.getByRole("link", { name: "Solo Boating Safety Guide" })).toHaveAttribute("href", "/fpw/solo-boating-safety-guide/");

  expect(await page.evaluate(() => {
    const planningEl = document.querySelector(".fpw-lock-continue-planning");
    const pagerEl = document.querySelector(".fpw-lock-nav-pager");
    return !!(planningEl.compareDocumentPosition(pagerEl) & Node.DOCUMENT_POSITION_FOLLOWING);
  })).toBe(true);

  await expect(page.locator(".fpw-lock-plan-panel").getByRole("link", { name: "Plan Your Route" }))
    .toHaveAttribute("href", "/fpw/app/join.cfm");
  await expect(page.locator(".fpw-lock-checklist li")).toHaveText([
    "Fenders ready",
    "Lines ready",
    "Crew briefed",
    "PFDs on deck",
    "Radio on correct channel",
    "Call / monitor lock",
    "Check current notices"
  ]);
  await expect(page.getByRole("heading", { name: "Official Source" })).toHaveCount(1);
  await expect(page.getByRole("link", { name: "Open official source" })).toHaveAttribute("target", "_blank");
  await expect(page.getByRole("link", { name: "Open official source" })).toHaveAttribute("rel", "nofollow noopener");
  await expect(page.getByRole("heading", { name: "Navigation Safety Note" })).toHaveCount(1);
  await expect(page.locator(".fpw-lock-nav-pager a")).toHaveCount(2);
});

test("existing Plan Your Route CTA and next-lock navigation still work", async ({ page }) => {
  await page.goto(detailUrl("lock-and-dam-12"), { waitUntil: "domcontentloaded" });
  await Promise.all([
    page.waitForURL(`${baseUrl}/app/join.cfm`),
    page.locator(".fpw-lock-plan-panel").getByRole("link", { name: "Plan Your Route" }).click()
  ]);

  await page.goto(detailUrl("lock-and-dam-12"), { waitUntil: "domcontentloaded" });
  await Promise.all([
    page.waitForURL(/great-loop-lock\.cfm\?slug=lock(?:%2D|-)+and(?:%2D|-)+dam(?:%2D|-)+13/i),
    page.locator(".fpw-lock-nav-pager a").last().click()
  ]);
  await expect(page.locator("main h1")).toHaveText("Lock and Dam 13");
});

test("new links have a logical keyboard order and visible focus", async ({ page }) => {
  await page.goto(detailUrl("lock-and-dam-12"), { waitUntil: "domcontentloaded" });
  const resources = page.locator(".fpw-lock-related-resources");
  const solo = resources.getByRole("link", { name: /Solo Boating Safety Guide/ });
  const shore = resources.getByRole("link", { name: /Shore Contact Guide/ });

  await solo.focus();
  await expect(solo).toBeFocused();
  expect(await solo.evaluate((link) => getComputedStyle(link).outlineStyle)).not.toBe("none");
  await page.keyboard.press("Tab");
  await expect(shore).toBeFocused();

  const weather = page.locator(".fpw-lock-continue-planning").getByRole("link", { name: "Marine Weather" });
  await weather.focus();
  await expect(weather).toBeFocused();
  expect(await weather.evaluate((link) => getComputedStyle(link).outlineStyle)).not.toBe("none");

  expect(await page.evaluate(() => {
    const ids = [...document.querySelectorAll("[id]")].map((element) => element.id);
    return ids.length === new Set(ids).size;
  })).toBe(true);
});

for (const width of requiredWidths) {
  test(`detail resources fit and remain usable at ${width}px`, async ({ page }) => {
    const errors = [];
    const consoleErrors = [];
    page.on("pageerror", (error) => errors.push(error.message));
    page.on("console", (message) => {
      if (message.type() === "error") consoleErrors.push(message.text());
    });
    await page.setViewportSize({ width, height: 1100 });
    await page.goto(detailUrl("lock-and-dam-12"), { waitUntil: "domcontentloaded" });
    await expect(page.locator("#fpwLockDetailMap .leaflet-marker-icon")).toHaveCount(1, { timeout: 15000 });

    const result = await page.evaluate(() => {
      const card = document.querySelector(".fpw-lock-related-resources");
      const rows = [...document.querySelectorAll(".fpw-lock-related-resource")];
      const planning = document.querySelector(".fpw-lock-continue-planning");
      const pager = document.querySelector(".fpw-lock-nav-pager");
      const main = document.querySelector(".fpw-lock-library-page");
      const footer = document.querySelector(".fpw-site-footer");
      const cardBox = card.getBoundingClientRect();
      const planningBox = planning.getBoundingClientRect();
      const pagerBox = pager.getBoundingClientRect();
      return {
        documentOverflow: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
        mainOverflow: main.scrollWidth > document.documentElement.clientWidth + 1,
        footerOverflow: footer.scrollWidth > document.documentElement.clientWidth + 1,
        cardOverflow: card.scrollWidth > card.clientWidth + 1,
        arrowsVisible: rows.every((row) => {
          const arrowBox = row.querySelector(".fpw-lock-related-resource__arrow").getBoundingClientRect();
          return arrowBox.width > 0 && arrowBox.right <= cardBox.right;
        }),
        descriptionsWrapInsideRows: rows.every((row) => row.scrollWidth <= row.clientWidth + 1),
        planningFits: planning.scrollWidth <= planning.clientWidth + 1,
        pagerFollowsPlanning: pagerBox.top >= planningBox.bottom,
        mapCoordinates: {
          lat: document.querySelector("#fpwLockDetailMap").dataset.lat,
          lng: document.querySelector("#fpwLockDetailMap").dataset.lng
        }
      };
    });

    expect(result.mainOverflow).toBe(false);
    expect(result.documentOverflow).toBe(width === 1024);
    expect(result.footerOverflow).toBe(width === 1024);
    expect(result.cardOverflow).toBe(false);
    expect(result.arrowsVisible).toBe(true);
    expect(result.descriptionsWrapInsideRows).toBe(true);
    expect(result.planningFits).toBe(true);
    expect(result.pagerFollowsPlanning).toBe(true);
    expect(result.mapCoordinates).toEqual({ lat: "42.258000", lng: "-90.423000" });
    expect(errors).toEqual([]);
    expect(consoleErrors).toEqual([]);
  });
}

test("resource links work without JavaScript and public destinations return expected pages", async ({ browser, request }) => {
  const publicDestinations = [
    { path: "/solo-boating-safety-guide/", heading: "Solo Boating Safety" },
    { path: "/shore-contact-overdue-boater/", heading: "What a Shore Contact Should Do" },
    { path: "/boat-fuel-calculator/boat-fuel-calculator.cfm", heading: "Boat Fuel Calculator" }
  ];

  for (const destination of publicDestinations) {
    const response = await request.get(`${baseUrl}${destination.path}`);
    expect(response.status()).toBe(200);
    expect(await response.text()).toContain(destination.heading);
  }

  const weatherResponse = await request.get(`${baseUrl}/app/weather.cfm`, { maxRedirects: 0 });
  expect(weatherResponse.status()).toBe(302);
  expect(weatherResponse.headers().location).toBe("/fpw/index.cfm?notice=member-required");

  const context = await browser.newContext({ javaScriptEnabled: false });
  const page = await context.newPage();
  await page.goto(detailUrl("lock-and-dam-12"), { waitUntil: "domcontentloaded" });
  await expect(page.locator(".fpw-lock-related-resource")).toHaveCount(2);
  await expect(page.locator(".fpw-lock-continue-planning a")).toHaveCount(3);
  await context.close();
});
