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
  expect(resultJson.reserveMode).toBe("percentage");
  expect(resultJson.standalone_inputs.reserveMode).toBe("percentage");
  expect(resultJson.standalone_inputs.reservePct).toBe(20);
  expect(resultJson.derived.reserveGallons).toBe(10);
  expect(resultJson.derived.requiredFuelGallons).toBe(60);
  expect(resultJson.derived.fuelAvailableAfterReserveGallons).toBe(80);
  expect(resultJson.derived.tripUsableCapacityGallons).toBe(80);
  expect(resultJson.derived.usableCapacityMeetsRequirement).toBe(true);
  expect(resultJson.derived.capacityShortfallGallons).toBe(0);
  expect(resultJson.derived.capacityMarginGallons).toBe(40);
  expect(resultJson.derived.estimatedEnduranceHours).toBe(8);
  expect(resultJson.derived.estimatedRangeNauticalMiles).toBe(160);
  expect(resultJson.cards.estimated_range_with_reserve_nm).toBe(160);
  expect(pageErrors).toEqual([]);
});

test("One-Third Rule uses dedicated departure, range, capacity, weather, idle, and JSON logic", async ({ page }) => {
  const pageErrors = collectPageErrors(page);
  await openCalculator(page);

  await fillEfficientScenario(page, {
    distance: "60",
    speed: "20",
    burn: "8",
    reserve: "33",
    capacity: "34"
  });

  const reserveSelect = page.locator("#reservePct");
  await expect(reserveSelect).toHaveValue("33");
  await expect(reserveSelect).toHaveAttribute("aria-describedby", "tip-reservePct");
  await expect(page.locator("#reservePct option:checked")).toHaveText("One-Third Rule");
  await expect(page.locator("#reservePct option:checked")).toHaveAttribute("data-reserve-mode", "thirds");
  await expect(page.locator("#tip-reservePct")).toHaveText(
    "A conservative fuel-management practice that plans departure fuel so expected trip consumption uses no more than two-thirds of usable fuel, leaving one-third in reserve."
  );
  await expect(page.locator("#cardEstimatedFuel")).toHaveText("36.0 gal");
  await expect(page.locator("#cardEstimatedFuelSub")).toHaveText("Base 24.0 + One-Third Rule Reserve 12.0");
  await expect(page.locator("#cardEstimatedRange")).toHaveText("56.7 NM");
  await expect(page.locator("#usableFuelCapacityStatus")).toHaveText(
    "Capacity shortfall: 2.0 gal. The 34.0 gal usable capacity is below the 36.0 gal departure requirement for these planning assumptions."
  );
  await expect(page.locator("#usableFuelCapacityStatus")).toHaveAttribute("data-capacity-state", "shortfall");

  let resultJson = JSON.parse(await page.locator("#calcJsonOut").textContent());
  expect(resultJson.reserveMode).toBe("thirds");
  expect(resultJson.standalone_inputs.reserveMode).toBe("thirds");
  expect(resultJson.standalone_inputs.reservePct).toBe(33);
  expect(resultJson.derived.baseFuelGallons).toBe(24);
  expect(resultJson.derived.reserveGallons).toBe(12);
  expect(resultJson.derived.requiredFuelGallons).toBe(36);
  expect(resultJson.derived.tripUsableCapacityGallons).toBeCloseTo(22.666666666666664, 10);
  expect(resultJson.derived.usableCapacityMeetsRequirement).toBe(false);
  expect(resultJson.derived.capacityShortfallGallons).toBe(2);
  expect(resultJson.derived.capacityMarginGallons).toBe(0);
  expect(Object.keys(resultJson.standalone_inputs)).toEqual(expect.arrayContaining([
    "distanceNm",
    "pace",
    "maxSpeedKn",
    "mostEfficientSpeedKn",
    "fuelBurnEfficientGph",
    "fuelBurnGph",
    "idleBurnGph",
    "idleHoursTotal",
    "weatherPct",
    "reservePct",
    "usableFuelCapacityGallons",
    "usableFuelCapacityStatus",
    "underwayHoursPerDay",
    "fuelPricePerGal"
  ]));
  expect(Object.keys(resultJson.derived)).toEqual(expect.arrayContaining([
    "paceLabel",
    "paceRatio",
    "effectiveSpeedKn",
    "weatherAdjustedSpeedKn",
    "paceAdjustedBurnGph",
    "weatherAdjustedBurnGph",
    "cruiseHours",
    "cruiseFuelGallons",
    "idleFuelGallons",
    "baseFuelGallons",
    "reserveGallons",
    "requiredFuelGallons",
    "totalFuelCost",
    "totalTravelHours",
    "estimatedDays",
    "fuelAvailableAfterReserveGallons",
    "estimatedEnduranceHours",
    "estimatedRangeNauticalMiles",
    "usesAnchoredBurn",
    "fuelMode",
    "canEstimateFuel",
    "canEstimateRange",
    "missingRequiredInputs"
  ]));

  await page.context().grantPermissions(["clipboard-read", "clipboard-write"], { origin: "http://localhost:8500" });
  await page.locator("#copyJsonBtn").click();
  const copiedJson = JSON.parse(await page.evaluate(() => navigator.clipboard.readText()));
  expect(copiedJson.reserveMode).toBe("thirds");
  expect(copiedJson.standalone_inputs.reservePct).toBe(33);
  expect(copiedJson.derived.capacityShortfallGallons).toBe(2);
  expect(copiedJson.cards.estimated_fuel_gallons).toBe(36);

  await page.locator("#usableFuelCapacityGallons").fill("36");
  await expect(page.locator("#cardEstimatedRange")).toHaveText("60.0 NM");
  await expect(page.locator("#usableFuelCapacityStatus")).toHaveText(
    "Capacity boundary: The 36.0 gal usable capacity exactly matches the 36.0 gal departure requirement for these planning assumptions."
  );
  await expect(page.locator("#usableFuelCapacityStatus")).toHaveAttribute("data-capacity-state", "boundary");
  resultJson = JSON.parse(await page.locator("#calcJsonOut").textContent());
  expect(resultJson.derived.tripUsableCapacityGallons).toBe(24);
  expect(resultJson.derived.estimatedRangeNauticalMiles).toBe(60);
  expect(resultJson.derived.usableCapacityMeetsRequirement).toBe(true);
  expect(resultJson.derived.capacityShortfallGallons).toBe(0);
  expect(resultJson.derived.capacityMarginGallons).toBe(0);
  await expect(page.locator("#calcBreakdownBody")).toContainText("One-Third Rule");
  await expect(page.locator("#calcBreakdownBody")).toContainText("One-Third Rule Reserve (gal)");
  await expect(page.locator("#calcBreakdownBody")).toContainText("Exactly matches departure requirement");

  await page.locator("#reservePct").selectOption("20");
  resultJson = JSON.parse(await page.locator("#calcJsonOut").textContent());
  expect(resultJson.reserveMode).toBe("percentage");
  expect(resultJson.standalone_inputs.reservePct).toBe(20);
  expect(resultJson.derived.baseFuelGallons).toBe(24);
  expect(resultJson.derived.reserveGallons).toBe(4.8);
  expect(resultJson.derived.requiredFuelGallons).toBe(28.8);
  expect(resultJson.derived.tripUsableCapacityGallons).toBeCloseTo(28.8, 10);
  expect(resultJson.derived.estimatedRangeNauticalMiles).toBeCloseTo(72, 10);

  await page.locator("#reservePct").selectOption("33");
  await page.locator("#usableFuelCapacityGallons").fill("100");
  await page.locator("#weatherPct").fill("10");
  await page.locator("#idleBurnGph").fill("2");
  await page.locator("#idleHoursTotal").fill("1.5");
  resultJson = JSON.parse(await page.locator("#calcJsonOut").textContent());
  expect(resultJson.derived.weatherAdjustedSpeedKn).toBe(18);
  expect(resultJson.derived.weatherAdjustedBurnGph).toBe(8.8);
  expect(resultJson.derived.cruiseHours).toBe(3.33);
  expect(resultJson.derived.cruiseFuelGallons).toBe(29.3);
  expect(resultJson.derived.idleFuelGallons).toBe(3);
  expect(resultJson.derived.baseFuelGallons).toBe(32.3);
  expect(resultJson.derived.reserveGallons).toBe(16.15);
  expect(resultJson.derived.requiredFuelGallons).toBe(48.45);
  expect(resultJson.derived.tripUsableCapacityGallons).toBeCloseTo(66.66666666666666, 10);
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
  await expect(page.locator("#cardEstimatedRange")).toHaveText("133 NM");
  await expect(page.locator("#cardEstimatedRangeSub")).toHaveText("Endurance with reserve: 6.7 h");
  const thirdsJson = JSON.parse(await page.locator("#calcJsonOut").textContent());
  expect(thirdsJson.reserveMode).toBe("thirds");
  expect(thirdsJson.derived.requiredFuelGallons).toBe(75);
  expect(thirdsJson.derived.tripUsableCapacityGallons).toBeCloseTo(66.66666666666666, 10);
  await page.locator("#reservePct").selectOption("15");
  await expect(page.locator("#cardEstimatedRange")).toHaveText("170 NM");
  await expect(page.locator("#cardEstimatedRangeSub")).toHaveText("Endurance with reserve: 8.5 h");
  const minimumReserveJson = JSON.parse(await page.locator("#calcJsonOut").textContent());
  expect(minimumReserveJson.reserveMode).toBe("percentage");
  expect(minimumReserveJson.standalone_inputs.reservePct).toBe(15);
  expect(minimumReserveJson.derived.baseFuelGallons).toBe(50);
  expect(minimumReserveJson.derived.reserveGallons).toBe(7.5);
  expect(minimumReserveJson.derived.requiredFuelGallons).toBe(57.5);
  expect(minimumReserveJson.derived.tripUsableCapacityGallons).toBe(85);

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
  await expect(page.locator("#usableFuelCapacityStatus")).toBeHidden();
  await expect(page.locator("#cardEstimatedRange")).toHaveText("Enter fuel capacity");
  await expect(page.locator("#reservePct")).toHaveValue("33");
  await expect(page.locator("#reservePct option:checked")).toHaveText("One-Third Rule");
  await expect(page.locator("#reservePct option:checked")).toHaveAttribute("data-reserve-mode", "thirds");
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
      "usableFuelCapacityHelp usableFuelCapacityError usableFuelCapacityStatus"
    );
    await expect(page.getByLabel("Reserve Method", { exact: true })).toBeVisible();
    await expect(page.locator("#reservePct")).toHaveAttribute("aria-describedby", "tip-reservePct");
    await expect(page.locator("#usableFuelCapacityStatus")).toBeVisible();
    await expect(page.locator("#cardEstimatedRange")).toHaveText("160 NM");
    await expect(page.locator("h1")).toHaveCount(1);
    await expect(page.locator("h1")).toHaveText("Boat Fuel Calculator");
    await expect(page.getByRole("heading", { level: 2, name: expectedSupportingHeading, exact: true })).toBeVisible();
    await expect(page.getByText(expectedIntro, { exact: true })).toBeVisible();
    await expect(page.getByText(expectedIntent, { exact: true })).toHaveCount(0);
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
      const capacityStatus = document.querySelector("#usableFuelCapacityStatus");
      const rangeCard = document.querySelector(".fpw-result-card--range");
      const breakdown = document.querySelector(".fpw-dev-output");
      const breakdownRows = [...document.querySelectorAll("#calcBreakdownBody tr")];
      const guide = document.querySelector(".fpw-fuel-guide");
      const fuelTable = document.querySelector(".fpw-fuel-data-table");
      const fuelTableRow = fuelTable.querySelector("tbody tr");
      const fuelTableHead = fuelTable.querySelector("thead");
      const responsiveGuideElements = [...document.querySelectorAll(
        ".fpw-formula-card code, .fpw-source-list a, .fpw-guide-card, .fpw-guide-faq summary"
      )];
      const columns = getComputedStyle(grid).gridTemplateColumns.split(" ").filter(Boolean).length;
      const elementsStayInsideViewport = [main, hero, heroContent, supportingHeading, input, capacityStatus, rangeCard, breakdown, guide, fuelTableRow].every((element) => {
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
        rangeCardHasOverflow: rangeCard.scrollWidth > rangeCard.clientWidth + 1,
        capacityStatusHasOverflow: capacityStatus.scrollWidth > capacityStatus.clientWidth + 1,
        breakdownHasOverflow: breakdown.scrollWidth > breakdown.clientWidth + 1,
        breakdownRowsHaveContent: breakdownRows.length > 0 && breakdownRows.every((row) => row.textContent.trim().length > 0),
        guideHasOverflow: guide.scrollWidth > guide.clientWidth + 1,
        responsiveGuideElementsFit: responsiveGuideElements.every((element) => {
          const rect = element.getBoundingClientRect();
          return rect.left >= -1 && rect.right <= window.innerWidth + 1;
        }),
        fuelTableRowDisplay: getComputedStyle(fuelTableRow).display,
        fuelTableHeadIsVisuallyHidden: fuelTableHead.getBoundingClientRect().width <= 1
      };
    });
    expect(layout.columns).toBe(viewport.columns);
    expect(layout.supportingHeadingFollowsH1).toBe(true);
    expect(layout.mainHasOverflow).toBe(false);
    expect(layout.heroHasOverflow).toBe(false);
    expect(layout.heroContentFits).toBe(true);
    expect(layout.elementsStayInsideViewport).toBe(true);
    expect(layout.rangeCardHasOverflow).toBe(false);
    expect(layout.capacityStatusHasOverflow).toBe(false);
    expect(layout.breakdownHasOverflow).toBe(false);
    expect(layout.breakdownRowsHaveContent).toBe(true);
    expect(layout.guideHasOverflow).toBe(false);
    expect(layout.responsiveGuideElementsFit).toBe(true);
    expect(layout.fuelTableRowDisplay).toBe(viewport.width <= 900 ? "grid" : "table-row");
    expect(layout.fuelTableHeadIsVisuallyHidden).toBe(viewport.width <= 900);
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
  await expect(page.getByRole("heading", { name: "Turn this fuel estimate into a complete trip plan" })).toHaveCount(1);
  await expect(page.locator("#boat-fuel-calculator-plan-route-cta")).toContainText(
    "Plan the route and stops, then recalculate mileage, travel time, fuel, reserve, and cost from the saved route. When departure approaches, turn the trip into a float plan. Free account required to save a trip."
  );
  const distanceHelper = page.locator("#trip-planner-distance-helper");
  await expect(distanceHelper).toHaveText("Need the route distance first? Plot your route in the free Trip Planner.");
  await expect(distanceHelper.getByRole("link", { name: "Plot your route in the free Trip Planner." })).toHaveAttribute("href", "../app/join.cfm");
  const pageSectionOrder = await page.locator("main > section, main > .fpw-fuel-guide").evaluateAll((elements) =>
    elements.map((element) => element.id || element.className)
  );
  expect(pageSectionOrder.indexOf("boat-fuel-calculator-plan-route-cta")).toBeLessThan(
    pageSectionOrder.indexOf("fpw-fuel-why")
  );
  expect(pageSectionOrder.indexOf("fpw-fuel-why")).toBeLessThan(
    pageSectionOrder.indexOf("fpw-fuel-guide")
  );
  const cta = page.locator("#boat-fuel-calculator-plan-route-cta [data-fpw-action-cta]");
  await expect(cta).toHaveCount(1);
  await expect(cta).toHaveText(/Plan This Trip Free/);
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
      label: "Plan This Trip Free",
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

test("authoritative guide order, manufacturer examples, sources, and FAQ schema remain exact", async ({ page }) => {
  const pageErrors = collectPageErrors(page);
  await page.setViewportSize({ width: 1440, height: 1000 });
  await openCalculator(page);

  const expectedSectionHeadings = [
    "How Much Fuel Does a Boat Use Per Hour?",
    "Real Boat Fuel-Burn Examples",
    "GPH vs. MPG: What the Numbers Mean",
    "Why Boat Fuel Consumption Changes With Speed",
    "How to Find Your Boat's Actual GPH",
    "What Affects Boat Fuel Consumption?",
    "Finding Your Most Efficient Cruising Speed",
    "Boat Fuel Planning Example",
    "How Much Fuel Reserve Should You Carry?",
    "Boat Fuel Calculator FAQ",
    "Sources & Further Reading"
  ];
  const actualSectionHeadings = await page.locator(".fpw-fuel-guide > .fpw-guide-section > h2").allTextContents();
  expect(actualSectionHeadings.map((heading) => heading.trim())).toEqual(expectedSectionHeadings);

  const guideSemantics = await page.locator(".fpw-fuel-guide").evaluate((guide) => {
    const headings = [...guide.querySelectorAll("h2, h3")];
    const levels = headings.map((heading) => Number(heading.tagName.slice(1)));
    const sectionLabelsResolve = [...guide.querySelectorAll("section[aria-labelledby]")].every((section) => {
      const label = document.getElementById(section.getAttribute("aria-labelledby"));
      return label && section.contains(label);
    });
    const noSkippedHeadingLevels = levels.every((level, index) => index === 0 || level <= levels[index - 1] + 1);
    return {
      firstHeadingLevel: levels[0],
      noSkippedHeadingLevels,
      sectionLabelsResolve,
      columnScopes: [...guide.querySelectorAll(".fpw-fuel-data-table th")].map((cell) => cell.getAttribute("scope")),
      tableCaption: guide.querySelector(".fpw-fuel-data-table caption")?.textContent.trim()
    };
  });
  expect(guideSemantics.firstHeadingLevel).toBe(2);
  expect(guideSemantics.noSkippedHeadingLevels).toBe(true);
  expect(guideSemantics.sectionLabelsResolve).toBe(true);
  expect(guideSemantics.columnScopes).toEqual(["col", "col", "col", "col", "col", "col"]);
  expect(guideSemantics.tableCaption).toBe("Manufacturer boat fuel-burn test examples");

  const expectedExamples = [
    ["G3 Boats 15 DLX / Yamaha F40", "4,000 RPM", "18.4 MPH", "1.5 GPH", "12.27 MPG", "Yamaha test data"],
    ["Crestliner 1850 Fish Hawk / Mercury 150 Pro XS", "3,000 RPM", "21.3 MPH", "3.6 GPH", "6.0 MPG", "Mercury test data"],
    ["Sportsman Open 232 / Yamaha F300", "3,500 RPM", "27.2 MPH", "8.3 GPH", "3.28 MPG", "Yamaha test data"],
    ["Sea Hunt Gamefish 30 CB / Twin Yamaha F350", "3,500 RPM", "35.9 MPH", "17.2 GPH total", "2.09 MPG", "Yamaha test data"]
  ];
  const actualExamples = await page.locator(".fpw-fuel-data-table tbody tr").evaluateAll((rows) => rows.map((row) => {
    const cells = [...row.querySelectorAll("td")];
    return [
      cells[0].querySelector("strong").textContent.trim(),
      ...cells.slice(1, 5).map((cell) => cell.textContent.trim()),
      cells[5].querySelector("a").textContent.trim()
    ];
  }));
  expect(actualExamples).toEqual(expectedExamples);

  const expectedSourceHrefs = [
    "https://www.uscgboating.org/assets/1/AssetManager/Boaters-Guide-to-Federal-Requirements-for-Receational-Boats-20231108.pdf",
    "https://yamahaoutboards.com/owner-center/performance-bulletins",
    "https://yamahaoutboards.com/blog/boating/take-command-of-fuel-efficiency",
    "https://performancedata.mercurymarine.com/performance-test/141",
    "https://www.mercurymarine.com/us/en/lifestyle/dockline/how-to-find-the-ideal-cruising-speed-on-your-boat",
    "https://www.mercurymarine.com/us/en/lifestyle/dockline/improving-your-boats-fuel-efficiency",
    "https://www.mercurymarine.com/us/en/lifestyle/dockline/how-to-trim-your-outboard-for-optimal-performance"
  ];
  const sourceLinks = page.locator(".fpw-source-list a");
  await expect(sourceLinks).toHaveCount(expectedSourceHrefs.length);
  expect(await sourceLinks.evaluateAll((links) => links.map((link) => link.href))).toEqual(expectedSourceHrefs);
  for (const sourceLink of await sourceLinks.all()) {
    await expect(sourceLink).toHaveAttribute("target", "_blank");
    await expect(sourceLink).toHaveAttribute("rel", "noopener noreferrer");
  }

  await expect(page.getByText("12 + 12 = 24 gallons", { exact: true })).toBeVisible();
  await expect(page.getByText("24 × $4.50 = $108", { exact: true })).toBeVisible();
  await expect(page.getByText(/36 usable gallons at departure/)).toBeVisible();
  await expect(page.locator("body")).not.toContainText(/horsepower\s*[×x]\s*0\.10/i);

  const visibleFaq = await page.locator(".fpw-guide-faq details").evaluateAll((items) => items.map((item) => ({
    question: item.querySelector("summary").textContent.trim(),
    answer: item.querySelector("p").textContent.trim()
  })));
  expect(visibleFaq).toHaveLength(8);

  const schema = JSON.parse(await page.locator('script[type="application/ld+json"]').textContent());
  const faqSchema = schema["@graph"].find((entity) => entity["@type"] === "FAQPage");
  const schemaFaq = faqSchema.mainEntity.map((item) => ({
    question: item.name,
    answer: item.acceptedAnswer.text
  }));
  expect(schemaFaq).toEqual(visibleFaq);

  await page.setViewportSize({ width: 390, height: 844 });
  await page.reload({ waitUntil: "domcontentloaded" });
  const mobileFaqMetrics = await page.locator(".fpw-guide-faq summary").evaluateAll((summaries) => summaries.map((summary) => ({
    height: summary.getBoundingClientRect().height,
    left: summary.getBoundingClientRect().left,
    right: summary.getBoundingClientRect().right
  })));
  expect(mobileFaqMetrics.every((item) => item.height >= 44)).toBe(true);
  expect(mobileFaqMetrics.every((item) => item.left >= -1 && item.right <= 391)).toBe(true);

  expect(pageErrors).toEqual([]);
});
