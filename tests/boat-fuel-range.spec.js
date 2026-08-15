const { test, expect } = require("@playwright/test");

const pageUrl = "http://localhost:8500/fpw/boat-fuel-calculator/boat-fuel-calculator.cfm";

function collectPageErrors(page) {
  const errors = [];
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(`console: ${message.text()}`);
  });
  page.on("pageerror", (error) => errors.push(`pageerror: ${error.message}`));
  return errors;
}

async function openCalculator(page) {
  const response = await page.goto(pageUrl, { waitUntil: "domcontentloaded" });
  expect(response && response.status()).toBe(200);
}

async function fillEfficientScenario(page, values = {}) {
  const scenario = {
    distance: "100",
    speed: "20",
    burn: "10",
    reserve: "20",
    fuelPrice: "4",
    capacity: "",
    ...values
  };

  await page.locator("#totalNm").fill(scenario.distance);
  await page.locator("#pace").selectOption("BALANCED");
  await page.locator("#mostEfficientSpeedKn").fill(scenario.speed);
  await page.locator("#fuelBurnEfficientGph").fill(scenario.burn);
  await page.locator("#reservePct").selectOption(scenario.reserve);
  await page.locator("#fuelPricePerGal").fill(scenario.fuelPrice);
  await page.locator("#usableFuelCapacityGallons").fill(scenario.capacity);
}

test("standard range calculation reuses adjusted speed, average GPH, and reserve without changing existing outputs", async ({ page }) => {
  const pageErrors = collectPageErrors(page);
  await openCalculator(page);
  await fillEfficientScenario(page, { capacity: "100" });

  await expect(page.locator("#cardTotalDistance")).toHaveText("100.0 NM");
  await expect(page.locator("#cardTotalHours")).toHaveText("5.0 h");
  await expect(page.locator("#cardEstimatedFuel")).toHaveText("60.0 gal");
  await expect(page.locator("#cardAdjustedSpeed")).toHaveText("20.00 kn");
  await expect(page.locator("#cardExpectedAvgGph")).toHaveText("10.00 GPH");
  await expect(page.locator("#cardFuelCost")).toHaveText("$240.00");
  await expect(page.locator("#cardEstimatedRange")).toHaveText("160 NM");
  await expect(page.locator("#cardEstimatedRange")).toHaveAttribute("aria-label", "160 nautical miles");
  await expect(page.locator("#cardEstimatedRangeSub")).toHaveText("Endurance with reserve: 8.0 h");

  const resultJson = JSON.parse(await page.locator("#calcJsonOut").textContent());
  expect(resultJson.derived.fuelAvailableAfterReserveGallons).toBe(80);
  expect(resultJson.derived.estimatedEnduranceHours).toBe(8);
  expect(resultJson.derived.estimatedRangeNauticalMiles).toBe(160);
  expect(resultJson.cards.estimated_range_with_reserve_nm).toBe(160);
  expect(pageErrors).toEqual([]);
});

test("decimal, missing, invalid, unavailable, reserve-boundary, and reset states remain deterministic", async ({ page }) => {
  const pageErrors = collectPageErrors(page);
  await openCalculator(page);

  await fillEfficientScenario(page);
  await expect(page.locator("#cardEstimatedRange")).toHaveText("Enter fuel capacity");
  await expect(page.locator("#usableFuelCapacityError")).toBeHidden();
  await expect(page.locator("#cardEstimatedFuel")).toHaveText("60.0 gal");

  await page.locator("#usableFuelCapacityGallons").fill("123.45");
  await page.locator("#mostEfficientSpeedKn").fill("17.5");
  await page.locator("#fuelBurnEfficientGph").fill("7.25");
  await page.locator("#reservePct").selectOption("15");
  await expect(page.locator("#cardEstimatedRange")).toHaveText("253 NM");
  await expect(page.locator("#cardEstimatedRangeSub")).toHaveText("Endurance with reserve: 14.5 h");
  const decimalJson = JSON.parse(await page.locator("#calcJsonOut").textContent());
  expect(decimalJson.derived.fuelAvailableAfterReserveGallons).toBeCloseTo(104.9325, 10);
  expect(decimalJson.derived.estimatedEnduranceHours).toBeCloseTo(14.47344827586207, 10);
  expect(decimalJson.derived.estimatedRangeNauticalMiles).toBeCloseTo(253.28534482758624, 10);

  await fillEfficientScenario(page, { capacity: "50", speed: "10", burn: "15", reserve: "20" });
  await expect(page.locator("#cardEstimatedRange")).toHaveText("26.7 NM");
  await expect(page.locator("#cardEstimatedRangeSub")).toHaveText("Endurance with reserve: 2.7 h");

  await fillEfficientScenario(page, { capacity: "100", reserve: "33" });
  await expect(page.locator("#cardEstimatedRange")).toHaveText("134 NM");
  await expect(page.locator("#cardEstimatedRangeSub")).toHaveText("Endurance with reserve: 6.7 h");
  await page.locator("#reservePct").selectOption("15");
  await expect(page.locator("#cardEstimatedRange")).toHaveText("170 NM");
  await expect(page.locator("#cardEstimatedRangeSub")).toHaveText("Endurance with reserve: 8.5 h");

  for (const invalidCapacity of ["0", "-5"]) {
    await page.locator("#usableFuelCapacityGallons").fill(invalidCapacity);
    await expect(page.locator("#usableFuelCapacityGallons")).toHaveAttribute("aria-invalid", "true");
    await expect(page.locator("#usableFuelCapacityError")).toBeVisible();
    await expect(page.locator("#cardEstimatedRange")).toHaveText("Range unavailable");
    await expect(page.locator("body")).not.toContainText(/NaN|Infinity/);
    await expect(page.locator("#cardEstimatedFuel")).not.toHaveText("-- gal");
  }

  await page.locator("#usableFuelCapacityGallons").fill("100");
  await page.locator("#fuelBurnEfficientGph").fill("0");
  await expect(page.locator("#cardEstimatedRange")).toHaveText("Range unavailable");
  await expect(page.locator("#cardEstimatedRangeSub")).toHaveText("Complete the speed and fuel-burn inputs");
  await expect(page.locator("body")).not.toContainText(/NaN|Infinity/);

  await page.locator("#fuelBurnEfficientGph").fill("10");
  await page.locator("#mostEfficientSpeedKn").fill("0");
  await expect(page.locator("#cardEstimatedRange")).toHaveText("Range unavailable");
  await expect(page.locator("#cardEstimatedRangeSub")).toHaveText("Complete the speed and fuel-burn inputs");
  await expect(page.locator("body")).not.toContainText(/NaN|Infinity/);

  await page.locator("#resetBtn").click();
  await expect(page.locator("#usableFuelCapacityGallons")).toHaveValue("");
  await expect(page.locator("#usableFuelCapacityGallons")).toHaveAttribute("aria-invalid", "false");
  await expect(page.locator("#usableFuelCapacityError")).toBeHidden();
  await expect(page.locator("#cardEstimatedRange")).toHaveText("Enter fuel capacity");
  await expect(page.locator("#reservePct")).toHaveValue("33");
  expect(pageErrors).toEqual([]);
});

test("metadata, structured data, accessible input, responsive layout, and reusable CTA remain intact", async ({ page }) => {
  const pageErrors = collectPageErrors(page);
  const expectedTitle = "Free Boat Fuel Calculator – Fuel Needed, Range & Trip Cost";
  const expectedDescription = "Free boat fuel calculator. Enter trip distance, cruising speed and fuel burn to estimate gallons needed, safe reserve, cruising range, travel time and trip cost.";
  const expectedSupportingHeading = "How much fuel will your boat need?";
  const expectedIntro = "Calculate the fuel required for your trip, safe reserve, cruising range, travel time and estimated cost using your boat's actual fuel burn.";
  const expectedIntent = "Use the boat fuel calculator to estimate how many gallons of fuel you'll need for a trip based on distance, cruising speed and your boat's gallons-per-hour fuel burn.";

  for (const viewport of [
    { width: 1440, height: 1000, columns: 7 },
    { width: 1024, height: 900, columns: 3 },
    { width: 760, height: 900, columns: 3 },
    { width: 390, height: 844, columns: 1 }
  ]) {
    await page.setViewportSize({ width: viewport.width, height: viewport.height });
    await openCalculator(page);
    await fillEfficientScenario(page, { capacity: "100" });

    await expect(page.getByLabel("Usable Fuel Capacity", { exact: true })).toBeVisible();
    await expect(page.locator("#usableFuelCapacityGallons")).toHaveAttribute("type", "number");
    await expect(page.locator("#usableFuelCapacityGallons")).toHaveAttribute("min", "0.01");
    await expect(page.locator("#usableFuelCapacityGallons")).toHaveAttribute("step", "0.01");
    await expect(page.locator("#usableFuelCapacityGallons")).toHaveAttribute(
      "aria-describedby",
      "usableFuelCapacityHelp usableFuelCapacityError"
    );
    await expect(page.locator("#cardEstimatedRange")).toHaveText("160 NM");
    await expect(page.locator("h1")).toHaveCount(1);
    await expect(page.locator("h1")).toHaveText("Boat Fuel Calculator");
    await expect(page.getByRole("heading", { level: 2, name: expectedSupportingHeading, exact: true })).toBeVisible();
    await expect(page.getByText(expectedIntro, { exact: true })).toBeVisible();
    await expect(page.getByText(expectedIntent, { exact: true })).toBeVisible();
    await expect(page.getByText("Free. No account required.", { exact: true })).toBeVisible();
    await expect(page.locator(".fpw-fuel-calculator-panel")).toBeVisible();

    const layout = await page.evaluate(() => {
      const main = document.querySelector(".fpw-fuel-page");
      const hero = document.querySelector(".fpw-compact-tool-hero");
      const heroContent = document.querySelector(".fpw-compact-tool-hero__content");
      const h1 = document.querySelector("h1");
      const supportingHeading = document.querySelector(".fpw-compact-tool-hero__supporting");
      const grid = document.querySelector(".fpw-results-grid");
      const input = document.querySelector("#usableFuelCapacityGallons");
      const rangeCard = document.querySelector(".fpw-result-card--range");
      const columns = getComputedStyle(grid).gridTemplateColumns.split(" ").filter(Boolean).length;
      const elementsStayInsideViewport = [main, hero, heroContent, supportingHeading, input, rangeCard].every((element) => {
        const rect = element.getBoundingClientRect();
        return rect.left >= -1 && rect.right <= window.innerWidth + 1;
      });
      return {
        columns,
        supportingHeadingFollowsH1: h1.nextElementSibling === supportingHeading,
        mainHasOverflow: main.scrollWidth > main.clientWidth + 1,
        heroHasOverflow: hero.scrollWidth > hero.clientWidth + 1,
        heroContentFits: heroContent.scrollHeight <= hero.clientHeight + 1,
        elementsStayInsideViewport,
        rangeCardHasOverflow: rangeCard.scrollWidth > rangeCard.clientWidth + 1
      };
    });
    expect(layout.columns).toBe(viewport.columns);
    expect(layout.supportingHeadingFollowsH1).toBe(true);
    expect(layout.mainHasOverflow).toBe(false);
    expect(layout.heroHasOverflow).toBe(false);
    expect(layout.heroContentFits).toBe(true);
    expect(layout.elementsStayInsideViewport).toBe(true);
    expect(layout.rangeCardHasOverflow).toBe(false);
  }

  await expect(page.locator("head title")).toHaveCount(1);
  await expect(page).toHaveTitle(expectedTitle);
  await expect(page.locator('meta[name="description"]')).toHaveCount(1);
  await expect(page.locator('meta[name="description"]')).toHaveAttribute("content", expectedDescription);
  await expect(page.locator('meta[property="og:title"]')).toHaveAttribute("content", expectedTitle);
  await expect(page.locator('meta[property="og:description"]')).toHaveAttribute("content", expectedDescription);
  await expect(page.locator('meta[name="twitter:title"]')).toHaveAttribute("content", expectedTitle);
  await expect(page.locator('meta[name="twitter:description"]')).toHaveAttribute("content", expectedDescription);
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute(
    "href",
    "https://floatplanwizard.com/boat-fuel-calculator/"
  );

  const schema = JSON.parse(await page.locator('script[type="application/ld+json"]').textContent());
  const webPage = schema["@graph"].find((entity) => entity["@type"] === "WebPage");
  expect(webPage.url).toBe("https://floatplanwizard.com/boat-fuel-calculator/");
  expect(webPage.name).toBe(expectedTitle);
  expect(webPage.description).toBe(expectedDescription);
  expect(schema["@graph"].some((entity) => entity.aggregateRating || entity.review || entity.offers)).toBe(false);

  await expect(page.locator("#boat-fuel-calculator-plan-route-cta")).toHaveCount(1);
  await expect(page.getByRole("heading", { name: "Turn your fuel estimate into a trip plan" })).toHaveCount(1);
  const cta = page.locator("#boat-fuel-calculator-plan-route-cta [data-fpw-action-cta]");
  await expect(cta).toHaveCount(1);
  await expect(cta).toHaveText(/Plan a Route/);
  await expect(cta).toHaveAttribute("data-fpw-track", "boat_fuel_calculator_plan_route_cta_click");
  await expect(cta).toHaveAttribute("data-fpw-track-source-page", "boat_fuel_calculator");
  await expect(cta).toHaveAttribute("data-fpw-track-section", "calculator_results");
  await expect(cta).toHaveAttribute("data-fpw-track-cta-type", "plan_route");
  await expect(cta).toHaveAttribute("href", "../app/join.cfm");

  await page.evaluate(() => {
    window.__fuelCtaTrackedEvents = [];
    window.FPWAnalytics = window.FPWAnalytics || {};
    window.FPWAnalytics.track = (eventName, params) => {
      window.__fuelCtaTrackedEvents.push({ eventName, params });
    };
    document.addEventListener("click", (event) => {
      if (event.target.closest("[data-fpw-action-cta]")) event.preventDefault();
    }, true);
  });
  await cta.click();
  const trackedClicks = await page.evaluate(() => window.__fuelCtaTrackedEvents);
  expect(trackedClicks).toEqual([{
    eventName: "boat_fuel_calculator_plan_route_cta_click",
    params: {
      source_page: "boat_fuel_calculator",
      section: "calculator_results",
      cta_type: "plan_route",
      label: "Plan a Route",
      auth_state: "signed_out",
      destination_key: "join"
    }
  }]);

  const duplicateIds = await page.evaluate(() => {
    const ids = [...document.querySelectorAll("[id]")].map((element) => element.id);
    return ids.filter((id, index) => ids.indexOf(id) !== index);
  });
  expect(duplicateIds).toEqual([]);
  expect(pageErrors).toEqual([]);
});
