const { test, expect } = require("@playwright/test");
const { readFileSync } = require("node:fs");
const path = require("node:path");

const repositoryRoot = path.resolve(__dirname, "..");
const hubSource = readFileSync(path.join(repositoryRoot, "app/great-loop-locks.cfm"), "utf8");
const hubCss = readFileSync(path.join(repositoryRoot, "assets/css/great-loop-locks.css"), "utf8");
const sharedCtaSource = readFileSync(path.join(repositoryRoot, "partials/fpw-action-cta.cfm"), "utf8");
const sharedCtaCssPath = path.join(repositoryRoot, "assets/css/fpw-action-cta.css");
const sharedNavCssPath = path.join(repositoryRoot, "assets/css/top-nav.css");
const liveHubUrl = "http://localhost:8500/fpw/app/great-loop-locks.cfm";

const expected = {
  heading: "Plan your Great Loop trip for free",
  body: "Plot your route and stops, calculate mileage, travel time, fuel, reserve, and cost, and adjust speed and weather assumptions as you plan.",
  button: "Plan My Trip Free",
  note: "Free account required to save your trip.",
  ariaLabel: "Open the free FloatPlanWizard Trip Planner for this Great Loop trip"
};

const otherConsumers = [
  "boat-fuel-calculator/boat-fuel-calculator.cfm",
  "solo-boating-safety-guide.cfm",
  "common-boating-emergencies.cfm",
  "shore-contact-overdue-boater.cfm"
];

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function expectedRenderedMarkup(authState = "signed_out") {
  const signedIn = authState === "signed_in";
  return `
    <main class="fpw-lock-library-page">
      <div class="fpw-lock-cta">
        <section class="fpw-action-cta" id="great-loop-locks-plan-route-cta" aria-labelledby="great-loop-locks-plan-route-cta-title">
          <div class="fpw-action-cta__content">
            <h2 id="great-loop-locks-plan-route-cta-title">${expected.heading}</h2>
            <p>${expected.body}</p>
          </div>
          <div class="fpw-action-cta__action">
            <a class="fpw-cta fpw-cta-primary"
              href="/fpw/app/${signedIn ? "dashboard" : "join"}.cfm"
              aria-label="${expected.ariaLabel}"
              data-fpw-action-cta
              data-fpw-track="great_loop_locks_plan_route_cta_click"
              data-fpw-track-source-page="great_loop_locks"
              data-fpw-track-section="hub_summary"
              data-fpw-track-cta-type="plan_route"
              data-fpw-track-label="${expected.button}"
              data-fpw-track-auth-state="${authState}"
              data-fpw-track-destination-key="${signedIn ? "dashboard" : "join"}">
              <span>${expected.button}</span><span class="fpw-cta-arrow" aria-hidden="true">→</span>
            </a>
          </div>
        </section>
        <p class="fpw-lock-cta__supporting-note">${expected.note}</p>
      </div>
      <section id="fpwLockFinder"></section>
    </main>`;
}

async function mountCta(page, authState = "signed_out") {
  await page.route("http://fpw-cta.test/", async (route) => {
    await route.fulfill({ status: 200, contentType: "text/html", body: "<!doctype html><title>CTA test origin</title>" });
  });
  await page.goto("http://fpw-cta.test/");
  await page.unroute("http://fpw-cta.test/");
  await page.setContent(expectedRenderedMarkup(authState));
  await page.addStyleTag({ path: sharedNavCssPath });
  await page.addStyleTag({ path: sharedCtaCssPath });
  await page.addStyleTag({ content: hubCss });
}

test("hub source has the exact Trip Planner CTA and preserves its routing and tracking contract", () => {
  for (const value of Object.values(expected)) {
    expect(hubSource.match(new RegExp(escapeRegExp(value), "g")) || []).toHaveLength(1);
  }

  expect(hubSource).not.toContain('"headline" = "Planning your Great Loop route?"');
  expect(hubSource).not.toContain('"buttonLabel" = "Plan a Route"');
  expect(hubSource).toContain('"destinationUrl" = request.fpwBase & (fpwLocksCtaSignedIn ? "/app/dashboard.cfm" : "/app/join.cfm")');
  expect(hubSource).toContain('"ctaType" = "plan_route"');
  expect(hubSource).toContain('"sourcePage" = "great_loop_locks"');
  expect(hubSource).toContain('"section" = "hub_summary"');
  expect(hubSource).toContain('"authState" = fpwLocksCtaSignedIn ? "signed_in" : "signed_out"');
  expect(hubSource).toContain('"destinationKey" = fpwLocksCtaSignedIn ? "dashboard" : "join"');
  expect(hubSource).toContain('"analyticsEvent" = "great_loop_locks_plan_route_cta_click"');
  expect(hubSource).toContain('<cfif isLockHubRoute>\n    <div class="fpw-lock-cta">');
  expect(hubSource).toContain('<p class="fpw-lock-cta__supporting-note"><cfoutput>#encodeForHTML(fpwCtaConfig.secondaryText)#</cfoutput></p>');
});

test("shared CTA defaults and every other shared CTA consumer remain unchanged by the new copy", () => {
  expect(sharedCtaSource).toContain('fpwActionCtaUnavailableMessage = "Route planning is currently unavailable.";');
  expect(sharedCtaSource).toContain('fpwActionCtaHeadline = "Plan your route";');

  for (const value of Object.values(expected)) {
    expect(sharedCtaSource).not.toContain(value);
  }
  for (const relativePath of otherConsumers) {
    const source = readFileSync(path.join(repositoryRoot, relativePath), "utf8");
    for (const value of Object.values(expected)) {
      expect(source, relativePath).not.toContain(value);
    }
  }
});

test("served signed-out hub renders the exact accessible Trip Planner CTA", async ({ page }) => {
  const response = await page.goto(liveHubUrl, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);
  await expect(page.getByRole("heading", { level: 2, name: expected.heading })).toHaveCount(1);
  await expect(page.locator("#great-loop-locks-plan-route-cta .fpw-action-cta__content p")).toHaveText(expected.body);
  await expect(page.locator(".fpw-lock-cta__supporting-note")).toHaveText(expected.note);
  await expect(page.getByRole("link", { name: expected.ariaLabel })).toHaveAttribute("href", "/fpw/app/join.cfm");
  await expect(page.getByRole("link", { name: expected.ariaLabel })).toContainText(expected.button);
  await expect(page.locator("#great-loop-locks-plan-route-cta")).not.toContainText("Plan a Route");
});

test("rendered signed-out and signed-in CTA contracts use the correct destinations and accessible name", async ({ page }) => {
  await mountCta(page, "signed_out");
  const signedOut = page.getByRole("link", { name: expected.ariaLabel });
  await expect(signedOut).toHaveAttribute("href", "/fpw/app/join.cfm");
  await expect(signedOut).toHaveAttribute("data-fpw-track-auth-state", "signed_out");
  await expect(signedOut).toHaveAttribute("data-fpw-track-destination-key", "join");
  await expect(page.getByRole("heading", { level: 2, name: expected.heading })).toHaveCount(1);
  await expect(page.locator("#great-loop-locks-plan-route-cta")).not.toContainText("Plan a Route");

  await mountCta(page, "signed_in");
  const signedIn = page.getByRole("link", { name: expected.ariaLabel });
  await expect(signedIn).toHaveAttribute("href", "/fpw/app/dashboard.cfm");
  await expect(signedIn).toHaveAttribute("data-fpw-track-auth-state", "signed_in");
  await expect(signedIn).toHaveAttribute("data-fpw-track-destination-key", "dashboard");
});

test("analytics and signed-out signup attribution keep their established identifiers", async ({ page }) => {
  const response = await page.goto(liveHubUrl, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);
  await page.evaluate(() => {
    window.sessionStorage.removeItem("fpw_signup_attribution");
    window.__ctaEvents = [];
    window.FPWAnalytics = {
      track(eventName, params) {
        window.__ctaEvents.push({ eventName, params });
      }
    };
    document.addEventListener("click", (event) => event.preventDefault(), true);
  });

  await page.getByRole("link", { name: expected.ariaLabel }).click();

  expect(await page.evaluate(() => window.__ctaEvents)).toEqual([{
    eventName: "great_loop_locks_plan_route_cta_click",
    params: {
      source_page: "great_loop_locks",
      section: "hub_summary",
      cta_type: "plan_route",
      label: "Plan My Trip Free",
      auth_state: "signed_out",
      destination_key: "join"
    }
  }]);
  expect(JSON.parse(await page.evaluate(() => sessionStorage.getItem("fpw_signup_attribution")))).toEqual({
    landing_key: "great_loop_locks",
    source_content_type: "seo_hub",
    cta_type: "plan_route"
  });
});

for (const width of [320, 390, 768, 1024, 1440]) {
  test(`CTA remains balanced, readable, and usable at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    const response = await page.goto(liveHubUrl, { waitUntil: "domcontentloaded" });
    expect(response && response.status()).toBe(200);

    const link = page.getByRole("link", { name: expected.ariaLabel });
    await link.focus();
    await expect(link).toBeFocused();

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
      const wrapper = document.querySelector(".fpw-lock-cta");
      const card = document.querySelector(".fpw-action-cta");
      const linkElement = document.querySelector("[data-fpw-action-cta]");
      const label = linkElement.querySelector("span");
      const note = document.querySelector(".fpw-lock-cta__supporting-note");
      const finder = document.querySelector("#fpwLockFinder");
      const linkStyle = getComputedStyle(linkElement);
      const noteStyle = getComputedStyle(note);
      const bodyStyle = getComputedStyle(card.querySelector(".fpw-action-cta__content p"));
      const wrapperBox = wrapper.getBoundingClientRect();
      const cardBox = card.getBoundingClientRect();
      const noteBox = note.getBoundingClientRect();
      return {
        documentOverflow: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
        wrapperOverflow: wrapper.scrollWidth > wrapper.clientWidth + 1,
        cardOverflow: card.scrollWidth > card.clientWidth + 1,
        contained: cardBox.left >= wrapperBox.left - 1 && cardBox.right <= wrapperBox.right + 1 && noteBox.right <= wrapperBox.right + 1,
        buttonHeight: linkElement.getBoundingClientRect().height,
        labelIsSingleLine: label.scrollHeight <= label.clientHeight + 1,
        noteIsSecondary: parseFloat(noteStyle.fontSize) < parseFloat(bodyStyle.fontSize),
        noteContrast: contrast(noteStyle.color, "rgb(8, 32, 51)"),
        focusOutlineVisible: linkStyle.outlineStyle !== "none" && parseFloat(linkStyle.outlineWidth) >= 2,
        finderFollowsCta: finder.getBoundingClientRect().top >= noteBox.bottom
      };
    });

    expect(result).toEqual({
      documentOverflow: false,
      wrapperOverflow: false,
      cardOverflow: false,
      contained: true,
      buttonHeight: expect.any(Number),
      labelIsSingleLine: true,
      noteIsSecondary: true,
      noteContrast: expect.any(Number),
      focusOutlineVisible: true,
      finderFollowsCta: true
    });
    expect(result.buttonHeight).toBeGreaterThanOrEqual(44);
    expect(result.noteContrast).toBeGreaterThanOrEqual(4.5);
  });
}
