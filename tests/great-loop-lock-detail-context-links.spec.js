const { test, expect } = require("@playwright/test");

const baseUrl = "http://localhost:8500/fpw";
const detailCases = [
  { slug: "lock-and-dam-12", title: "Lock and Dam 12" },
  { slug: "e11-amsterdam", title: "E11 Amsterdam" }
];
const requiredWidths = [1440, 1024, 768, 390, 320];
const disposablePassword = "LockDetailCTA!2026";
const ctaCopy = {
  mainHeading: "Planning your Great Loop trip?",
  mainBody: "Use the free FPW Trip Planner to plot your route and stops, calculate mileage, travel time, fuel, reserve, and cost, and adjust speed and weather assumptions.",
  sidebarHeading: "Plan your Great Loop trip",
  sidebarBody: "Plot your route and stops, then calculate mileage, travel time, fuel, reserve, and cost with the free FPW Trip Planner.",
  button: "Plan My Trip Free",
  note: "Free account required to save your trip.",
  accessibleName: "Open the free FloatPlanWizard Trip Planner"
};

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
    ctaCopy.sidebarHeading,
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

test("both Trip Planner placements use exact copy, safe destinations, and no lock-context transfer", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 1100 });
  await page.goto(detailUrl("lock-and-dam-12"), { waitUntil: "domcontentloaded" });

  const mainCta = page.locator(".fpw-lock-detail-trip-cta");
  const sidebarCta = page.locator(".fpw-lock-plan-panel");
  const links = page.locator("[data-fpw-action-cta]");

  await expect(mainCta.getByRole("heading", { level: 3, name: ctaCopy.mainHeading })).toHaveCount(1);
  await expect(mainCta.locator(".fpw-lock-detail-trip-cta__content p")).toHaveText(ctaCopy.mainBody);
  await expect(sidebarCta.getByRole("heading", { level: 3, name: ctaCopy.sidebarHeading })).toHaveCount(1);
  await expect(sidebarCta.locator(".fpw-lock-plan-panel__body")).toHaveText(ctaCopy.sidebarBody);
  await expect(mainCta.locator(".fpw-lock-detail-trip-cta__note")).toHaveText(ctaCopy.note);
  await expect(sidebarCta.locator(".fpw-lock-plan-panel__note")).toHaveText(ctaCopy.note);
  await expect(links).toHaveCount(2);

  for (const section of ["lock_detail_main", "lock_detail_sidebar"]) {
    const link = page.locator(`[data-fpw-track-section="${section}"]`);
    await expect(link).toHaveAttribute("href", "/fpw/app/join.cfm");
    await expect(link).toHaveAttribute("aria-label", ctaCopy.accessibleName);
    await expect(link).toContainText(ctaCopy.button);
    await expect(link).toHaveAttribute("data-fpw-track", "great_loop_locks_plan_route_cta_click");
    await expect(link).toHaveAttribute("data-fpw-track-source-page", "great_loop_locks");
    await expect(link).toHaveAttribute("data-fpw-track-cta-type", "plan_route");
    await expect(link).toHaveAttribute("data-fpw-track-label", ctaCopy.button);
    await expect(link).toHaveAttribute("data-fpw-track-auth-state", "signed_out");
    await expect(link).toHaveAttribute("data-fpw-track-destination-key", "join");
  }

  expect(await page.evaluate(() => {
    const map = document.querySelector(".fpw-lock-location-map-card");
    const cta = document.querySelector(".fpw-lock-detail-trip-cta");
    const details = document.querySelector(".fpw-lock-detail-grid");
    return Boolean(
      map.compareDocumentPosition(cta) & Node.DOCUMENT_POSITION_FOLLOWING
      && cta.compareDocumentPosition(details) & Node.DOCUMENT_POSITION_FOLLOWING
    );
  })).toBe(true);

  const ctaText = `${await mainCta.innerText()} ${await sidebarCta.innerText()}`;
  expect(ctaText).not.toMatch(/Plan With FPW|Plan Your Route|automated weather routing|optimized weather routing|certified marine navigation|official charts|lock-status guarantees|emergency dispatch|rescue services|continuous vessel tracking/i);

  const contextTransfer = await links.evaluateAll((elements) => elements.map((link) => ({
    href: link.getAttribute("href"),
    dataAttributes: Object.fromEntries([...link.attributes]
      .filter((attribute) => attribute.name.startsWith("data-"))
      .map((attribute) => [attribute.name, attribute.value]))
  })));
  for (const contract of contextTransfer) {
    expect(contract.href).toBe("/fpw/app/join.cfm");
    expect(contract.href).not.toMatch(/[?#]/);
    expect(JSON.stringify(contract.dataAttributes)).not.toMatch(/lock-and-dam-12|Lock and Dam 12|42\.258|-90\.423|latitude|longitude|coordinates|map_state|slug/i);
  }
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

  await expect(page.locator(".fpw-lock-plan-panel").getByRole("link", { name: ctaCopy.accessibleName }))
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

test("signed-out Trip Planner CTA and next-lock navigation still work", async ({ page }) => {
  await page.goto(detailUrl("lock-and-dam-12"), { waitUntil: "domcontentloaded" });
  await Promise.all([
    page.waitForURL(`${baseUrl}/app/join.cfm`),
    page.locator(".fpw-lock-detail-trip-cta").getByRole("link", { name: ctaCopy.accessibleName }).click()
  ]);

  await page.goto(detailUrl("lock-and-dam-12"), { waitUntil: "domcontentloaded" });
  await Promise.all([
    page.waitForURL(/great-loop-lock\.cfm\?slug=lock(?:%2D|-)+and(?:%2D|-)+dam(?:%2D|-)+13/i),
    page.locator(".fpw-lock-nav-pager a").last().click()
  ]);
  await expect(page.locator("main h1")).toHaveText("Lock and Dam 13");
});

test("each placement emits one established event and preserves signed-out Join attribution", async ({ page }) => {
  await page.goto(detailUrl("lock-and-dam-12"), { waitUntil: "domcontentloaded" });
  await page.evaluate(() => {
    window.sessionStorage.removeItem("fpw_signup_attribution");
    window.__lockDetailCtaEvents = [];
    window.FPWAnalytics = {
      track(eventName, params) {
        window.__lockDetailCtaEvents.push({ eventName, params });
      }
    };
    document.addEventListener("click", (event) => {
      if (event.target.closest("[data-fpw-action-cta]")) event.preventDefault();
    }, true);
  });

  await page.locator('[data-fpw-track-section="lock_detail_main"]').click();
  await page.locator('[data-fpw-track-section="lock_detail_sidebar"]').click();

  expect(await page.evaluate(() => window.__lockDetailCtaEvents)).toEqual([
    {
      eventName: "great_loop_locks_plan_route_cta_click",
      params: {
        source_page: "great_loop_locks",
        section: "lock_detail_main",
        cta_type: "plan_route",
        label: ctaCopy.button,
        auth_state: "signed_out",
        destination_key: "join"
      }
    },
    {
      eventName: "great_loop_locks_plan_route_cta_click",
      params: {
        source_page: "great_loop_locks",
        section: "lock_detail_sidebar",
        cta_type: "plan_route",
        label: ctaCopy.button,
        auth_state: "signed_out",
        destination_key: "join"
      }
    }
  ]);
  expect(JSON.parse(await page.evaluate(() => sessionStorage.getItem("fpw_signup_attribution")))).toEqual({
    landing_key: "great_loop_locks",
    source_content_type: "seo_hub",
    cta_type: "plan_route"
  });
});

test("signed-in placements use the existing dashboard destination", async ({ page }) => {
  const email = `codex-great-loop-lock-cta-${Date.now()}-${Math.random().toString(16).slice(2)}@example.test`;
  const joinResponse = await page.goto(`${baseUrl}/app/join.cfm`, { waitUntil: "domcontentloaded" });
  expect(joinResponse && joinResponse.status()).toBe(200);
  await page.locator("#firstName").fill("Lock Detail");
  await page.locator("#lastName").fill("CTA Test");
  await page.locator("#email").fill(email);
  await page.locator("#password").fill(disposablePassword);
  await page.locator("#confirmPassword").fill(disposablePassword);
  await page.locator("#termsAccepted").check();
  await Promise.all([
    page.waitForURL(/\/fpw\/app\/dashboard\.cfm/),
    page.locator("#joinButton").click()
  ]);

  const response = await page.goto(detailUrl("lock-and-dam-12"), { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);
  for (const section of ["lock_detail_main", "lock_detail_sidebar"]) {
    const link = page.locator(`[data-fpw-track-section="${section}"]`);
    await expect(link).toHaveAttribute("href", "/fpw/app/dashboard.cfm");
    await expect(link).toHaveAttribute("data-fpw-track-auth-state", "signed_in");
    await expect(link).toHaveAttribute("data-fpw-track-destination-key", "dashboard");
  }
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

  const tripCta = page.locator(".fpw-lock-detail-trip-cta").getByRole("link", { name: ctaCopy.accessibleName });
  await tripCta.focus();
  await expect(tripCta).toBeFocused();
  expect(await tripCta.evaluate((link) => {
    const style = getComputedStyle(link);
    return {
      visibleOutline: style.outlineStyle !== "none" && parseFloat(style.outlineWidth) >= 2,
      focusTextColor: style.color
    };
  })).toEqual({ visibleOutline: true, focusTextColor: "rgb(1, 20, 28)" });
  await expect(page.locator("main h1")).toHaveCount(1);
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
      function luminance(rgb) {
        const channels = (rgb.match(/[\d.]+/g) || []).slice(0, 3).map((value) => {
          const channel = Number(value) / 255;
          return channel <= 0.03928 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
        });
        return (0.2126 * channels[0]) + (0.7152 * channels[1]) + (0.0722 * channels[2]);
      }
      function contrast(foreground, background) {
        const lighter = Math.max(luminance(foreground), luminance(background));
        const darker = Math.min(luminance(foreground), luminance(background));
        return (lighter + 0.05) / (darker + 0.05);
      }
      const card = document.querySelector(".fpw-lock-related-resources");
      const rows = [...document.querySelectorAll(".fpw-lock-related-resource")];
      const planning = document.querySelector(".fpw-lock-continue-planning");
      const pager = document.querySelector(".fpw-lock-nav-pager");
      const main = document.querySelector(".fpw-lock-library-page");
      const footer = document.querySelector(".fpw-site-footer");
      const mapCard = document.querySelector(".fpw-lock-location-map-card");
      const map = document.querySelector("#fpwLockDetailMap");
      const mainCta = document.querySelector(".fpw-lock-detail-trip-cta");
      const sidebarCta = document.querySelector(".fpw-lock-plan-panel");
      const rail = document.querySelector(".fpw-lock-detail-rail");
      const resourceCard = document.querySelector(".fpw-lock-related-resources");
      const mainButton = mainCta.querySelector("[data-fpw-action-cta]");
      const mainButtonLabel = mainButton.querySelector("span");
      const mainNote = mainCta.querySelector(".fpw-lock-detail-trip-cta__note");
      const cardBox = card.getBoundingClientRect();
      const planningBox = planning.getBoundingClientRect();
      const pagerBox = pager.getBoundingClientRect();
      const mapCardBox = mapCard.getBoundingClientRect();
      const mapBox = map.getBoundingClientRect();
      const mainCtaBox = mainCta.getBoundingClientRect();
      const railBox = rail.getBoundingClientRect();
      const resourceBox = resourceCard.getBoundingClientRect();
      const sidebarStyle = getComputedStyle(sidebarCta);
      const mainNoteStyle = getComputedStyle(mainNote);
      const mainBodyStyle = getComputedStyle(mainCta.querySelector(".fpw-lock-detail-trip-cta__content p"));
      const officialSourcePanel = [...rail.querySelectorAll(".fpw-lock-panel")]
        .find((panel) => panel.querySelector("h3")?.textContent.trim() === "Official Source");
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
        mainCtaVisible: getComputedStyle(mainCta).display !== "none" && mainCtaBox.height > 0,
        sidebarCtaVisible: sidebarStyle.display !== "none" && sidebarCta.getBoundingClientRect().height > 0,
        resourcesVisible: getComputedStyle(resourceCard).display !== "none" && resourceBox.height > 0,
        beforeArrivalVisible: getComputedStyle(rail.firstElementChild).display !== "none",
        officialSourceVisible: Boolean(officialSourcePanel) && getComputedStyle(officialSourcePanel).display !== "none",
        mainCtaFits: mainCta.scrollWidth <= mainCta.clientWidth + 1,
        mainCtaFollowsMap: mainCtaBox.top >= mapCardBox.bottom - 1 && mainCtaBox.top >= mapBox.bottom - 1,
        mainCtaStaysInColumn: mainCtaBox.left >= document.querySelector(".fpw-lock-detail-main").getBoundingClientRect().left - 1
          && mainCtaBox.right <= document.querySelector(".fpw-lock-detail-main").getBoundingClientRect().right + 1,
        mainButtonHeight: mainButton.getBoundingClientRect().height,
        mainButtonSingleLine: mainButtonLabel.scrollHeight <= mainButtonLabel.clientHeight + 1,
        mainNoteIsSecondary: parseFloat(mainNoteStyle.fontSize) < parseFloat(mainBodyStyle.fontSize),
        mainNoteContrast: contrast(mainNoteStyle.color, "rgb(3, 15, 28)"),
        mainBodyContrast: contrast(mainBodyStyle.color, "rgb(3, 15, 28)"),
        sidebarDoesNotOverlapResources: sidebarStyle.display === "none"
          || sidebarCta.getBoundingClientRect().bottom <= resourceBox.top + 1,
        railInSeparateColumn: railBox.left >= mainCtaBox.right - 1 || sidebarStyle.display === "none",
        mapCoordinates: {
          lat: document.querySelector("#fpwLockDetailMap").dataset.lat,
          lng: document.querySelector("#fpwLockDetailMap").dataset.lng
        }
      };
    });

    expect(result.mainOverflow).toBe(false);
    expect(result.documentOverflow).toBe(false);
    expect(result.footerOverflow).toBe(false);
    expect(result.cardOverflow).toBe(false);
    expect(result.arrowsVisible).toBe(true);
    expect(result.descriptionsWrapInsideRows).toBe(true);
    expect(result.planningFits).toBe(true);
    expect(result.pagerFollowsPlanning).toBe(true);
    expect(result.mainCtaVisible).toBe(true);
    expect(result.sidebarCtaVisible).toBe(width > 1180);
    expect(result.resourcesVisible).toBe(true);
    expect(result.beforeArrivalVisible).toBe(true);
    expect(result.officialSourceVisible).toBe(true);
    expect(result.mainCtaFits).toBe(true);
    expect(result.mainCtaFollowsMap).toBe(true);
    expect(result.mainCtaStaysInColumn).toBe(true);
    expect(result.mainButtonHeight).toBeGreaterThanOrEqual(44);
    expect(result.mainButtonSingleLine).toBe(true);
    expect(result.mainNoteIsSecondary).toBe(true);
    expect(result.mainNoteContrast).toBeGreaterThanOrEqual(4.5);
    expect(result.mainBodyContrast).toBeGreaterThanOrEqual(4.5);
    expect(result.sidebarDoesNotOverlapResources).toBe(true);
    expect(result.railInSeparateColumn).toBe(true);
    expect(result.mapCoordinates).toEqual({ lat: "42.258000", lng: "-90.423000" });
    expect(errors).toEqual([]);
    expect(consoleErrors).toEqual([]);
  });
}

test("200 percent zoom equivalent remains usable without horizontal overflow", async ({ page }) => {
  await page.setViewportSize({ width: 720, height: 900 });
  await page.goto(detailUrl("lock-and-dam-12"), { waitUntil: "domcontentloaded" });
  await expect(page.locator(".fpw-lock-detail-trip-cta")).toBeVisible();
  await expect(page.locator(".fpw-lock-plan-panel")).toBeHidden();
  expect(await page.evaluate(() => ({
    overflow: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
    buttonOverflow: document.querySelector(".fpw-lock-detail-trip-cta [data-fpw-action-cta]").scrollWidth
      > document.querySelector(".fpw-lock-detail-trip-cta [data-fpw-action-cta]").clientWidth + 1
  }))).toEqual({ overflow: false, buttonOverflow: false });
});

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
  await expect(page.locator(".fpw-lock-detail-trip-cta")).toContainText(ctaCopy.mainBody);
  await expect(page.locator(".fpw-lock-detail-trip-cta").getByRole("link", { name: ctaCopy.accessibleName })).toHaveAttribute("href", "/fpw/app/join.cfm");
  await expect(page.locator(".fpw-lock-related-resource")).toHaveCount(2);
  await expect(page.locator(".fpw-lock-continue-planning a")).toHaveCount(3);
  await context.close();
});
