component extends="testbox.system.BaseSpec" output="false" {

  function run() {
    describe("Reserve mode compatibility and fuel arithmetic", function() {

      beforeEach(function() {
        variables.routeBuilder = createObject("component", "fpw.api.v1.routeBuilder");
        makePublic(variables.routeBuilder, "calculateFuelEstimate", "calculateFuelEstimateForTest");
        makePublic(variables.routeBuilder, "routegenNormalizeReserveMode", "normalizeReserveModeForTest");
        makePublic(variables.routeBuilder, "routegenSerializeInputsForInstance", "serializeInputsForTest");
        makePublic(variables.routeBuilder, "routegenParseStoredInputs", "parseStoredInputsForTest");

        variables.timeline = createObject("component", "fpw.api.v1.RouteTimelineService").init("fpw");
        makePublic(variables.timeline, "calculateFuelEstimate", "calculateFuelEstimateForTest");
        makePublic(variables.timeline, "routegenNormalizeReserveMode", "normalizeReserveModeForTest");
        makePublic(variables.timeline, "routegenBuildCruiseTimelineDay", "buildTimelineDayForTest");
        makePublic(variables.timeline, "routegenFinalizeCruiseTimelineDay", "finalizeTimelineDayForTest");

        variables.activeCruise = createObject("component", "fpw.api.v1.ActiveCruiseViewModelService").init("fpw");
        makePublic(variables.activeCruise, "formatFuelReserveLabel", "formatFuelReserveLabelForTest");
        makePublic(variables.activeCruise, "enrichRouteTimelineFuel", "enrichRouteTimelineFuelForTest");

        variables.voyage = createObject("component", "fpw.api.v1.voyage");
        makePublic(variables.voyage, "normalizeFuelReserveMode", "normalizeFuelReserveModeForTest");
        makePublic(variables.voyage, "estimateFollowPlannedFuel", "estimateFollowPlannedFuelForTest");
      });

      it("normalizes explicit, legacy, and missing reserve mode inputs consistently", function() {
        expect(variables.routeBuilder.normalizeReserveModeForTest("thirds", 20)).toBe("thirds");
        expect(variables.routeBuilder.normalizeReserveModeForTest("percentage", 33)).toBe("percentage");
        expect(variables.routeBuilder.normalizeReserveModeForTest("", 33)).toBe("thirds");
        expect(variables.routeBuilder.normalizeReserveModeForTest("", 20)).toBe("percentage");
        expect(variables.routeBuilder.normalizeReserveModeForTest("", 15)).toBe("percentage");
        expect(variables.routeBuilder.normalizeReserveModeForTest("", "")).toBe("thirds");
        expect(variables.timeline.normalizeReserveModeForTest("", 33)).toBe("thirds");
        expect(variables.timeline.normalizeReserveModeForTest("", 20)).toBe("percentage");
        expect(variables.voyage.normalizeFuelReserveModeForTest("percentage", 33)).toBe("percentage");
        expect(variables.voyage.normalizeFuelReserveModeForTest("", 33)).toBe("thirds");
      });

      it("calculates One-Third Rule and ordinary percentage cases from a 24 gallon base", function() {
        var thirds = calculateRouteBuilderFuel(24, 33, "thirds");
        var legacyThirds = calculateRouteBuilderFuel(24, 33, "");
        var missingBoth = variables.routeBuilder.calculateFuelEstimateForTest({
          distanceNm = 24,
          maxSpeedKnots = 10,
          maxBurnGph = 10,
          pace = "AGGRESSIVE"
        });
        var twenty = calculateRouteBuilderFuel(24, 20, "percentage");
        var fifteen = calculateRouteBuilderFuel(24, 15, "percentage");
        var literalThirtyThree = calculateRouteBuilderFuel(24, 33, "percentage");

        expect(thirds.baseFuelGallons).toBe(24);
        expect(thirds.reserveGallons).toBe(12);
        expect(thirds.requiredFuelGallons).toBe(36);
        expect(thirds.reserveMode).toBe("thirds");
        expect(legacyThirds.reserveGallons).toBe(12);
        expect(legacyThirds.requiredFuelGallons).toBe(36);
        expect(legacyThirds.reserveMode).toBe("thirds");
        expect(missingBoth.reservePct).toBe(33);
        expect(missingBoth.reserveGallons).toBe(12);
        expect(missingBoth.requiredFuelGallons).toBe(36);
        expect(missingBoth.reserveMode).toBe("thirds");
        expect(twenty.reserveGallons).toBe(4.8);
        expect(twenty.requiredFuelGallons).toBe(28.8);
        expect(fifteen.reserveGallons).toBe(3.6);
        expect(fifteen.requiredFuelGallons).toBe(27.6);
        expect(literalThirtyThree.reserveGallons).toBe(7.92);
        expect(literalThirtyThree.requiredFuelGallons).toBe(31.92);
        expect(literalThirtyThree.reserveMode).toBe("percentage");
      });

      it("applies One-Third Rule to one-way and multi-leg bases without refueling", function() {
        var oneWay = calculateRouteBuilderFuel(10, 33, "thirds");
        var legBases = [ 6, 8, 6 ];
        var reserveTotal = 0;
        var requiredTotal = 0;
        var i = 0;
        var leg = {};

        expect(oneWay.reserveGallons).toBe(5);
        expect(oneWay.requiredFuelGallons).toBe(15);

        for (i = 1; i LTE arrayLen(legBases); i++) {
          leg = calculateRouteBuilderFuel(legBases[i], 33, "thirds");
          reserveTotal += leg.reserveGallons;
          requiredTotal += leg.requiredFuelGallons;
        }
        expect(reserveTotal).toBe(10);
        expect(requiredTotal).toBe(30);
      });

      it("returns additive reserve mode fields from the public route fuel estimate", function() {
        var thirdsResult = variables.routeBuilder.routegenEstimateFuelForDistance(
          routeInputs = baseRouteInputs(33, "thirds"),
          distanceNm = 24,
          idleFuelGallons = 0,
          includeIdleFuelFromInputs = false
        );
        var literalResult = variables.routeBuilder.routegenEstimateFuelForDistance(
          routeInputs = baseRouteInputs(33, "percentage"),
          distanceNm = 24,
          idleFuelGallons = 0,
          includeIdleFuelFromInputs = false
        );

        expect(thirdsResult.SUCCESS).toBeTrue();
        expect(thirdsResult.RESERVE_PCT).toBe(33);
        expect(thirdsResult.RESERVE_MODE).toBe("thirds");
        expect(thirdsResult.FUEL_ESTIMATE.reserveGallons).toBe(12);
        expect(thirdsResult.FUEL_ESTIMATE.requiredFuelGallons).toBe(36);
        expect(literalResult.SUCCESS).toBeTrue();
        expect(literalResult.RESERVE_MODE).toBe("percentage");
        expect(literalResult.FUEL_ESTIMATE.reserveGallons).toBe(7.92);
        expect(literalResult.FUEL_ESTIMATE.requiredFuelGallons).toBe(31.92);
      });

      it("uses Route Builder fuel for Follow totals while keeping aggregate idle out of legs", function() {
        var routeInputs = baseRouteInputs(33, "thirds");
        var result = {};
        routeInputs.idle_burn_gph = 1.5;
        routeInputs.idle_hours_total = 1;

        result = variables.voyage.estimateFollowPlannedFuelForTest(
          routeInputs = routeInputs,
          totalDistanceNm = 24,
          legDistancesNm = [ 8, 16 ]
        );

        expect(result.SUCCESS).toBeTrue();
        expect(result.TOTAL.cruiseFuelGallons).toBe(24);
        expect(result.TOTAL.idleFuelGallons).toBe(1.5);
        expect(result.TOTAL.baseFuelGallons).toBe(25.5);
        expect(result.TOTAL.reserveGallons).toBe(12.75);
        expect(result.TOTAL.requiredFuelGallons).toBe(38.25);
        expect(result.LEGS[1].cruise_fuel_gallons).toBe(8);
        expect(result.LEGS[2].cruise_fuel_gallons).toBe(16);
        expect(result.LEGS[1].fuel_burn_gph).toBe(10);
        expect(result.LEGS[2].fuel_burn_gph).toBe(10);
      });

      it("stores both reserve fields and keeps legacy stored JSON compatible", function() {
        var storedThirds = deserializeJSON(variables.routeBuilder.serializeInputsForTest({
          pace = "AGGRESSIVE",
          reserve_pct = 33
        }));
        var storedLiteral = deserializeJSON(variables.routeBuilder.serializeInputsForTest({
          pace = "AGGRESSIVE",
          reserve_pct = 33,
          reserve_mode = "percentage"
        }));
        var parsedCamel = variables.routeBuilder.parseStoredInputsForTest('{"reservePct":20,"reserveMode":"percentage"}');
        var parsedLegacy = variables.routeBuilder.parseStoredInputsForTest('{"reserve_pct":33}');

        expect(storedThirds.reserve_pct).toBe(33);
        expect(storedThirds.reserve_mode).toBe("thirds");
        expect(storedLiteral.reserve_pct).toBe(33);
        expect(storedLiteral.reserve_mode).toBe("percentage");
        expect(parsedCamel.reserve_pct).toBe(20);
        expect(parsedCamel.reserve_mode).toBe("percentage");
        expect(parsedLegacy.reserve_pct).toBe(33);
        expect(variables.routeBuilder.normalizeReserveModeForTest(
          structKeyExists(parsedLegacy, "reserve_mode") ? parsedLegacy.reserve_mode : "",
          parsedLegacy.reserve_pct
        )).toBe("thirds");
      });

      it("uses mode-aware timeline day arithmetic while retaining risk thresholds", function() {
        var thirdsDay = variables.timeline.buildTimelineDayForTest(now(), 1);
        var percentageDay = variables.timeline.buildTimelineDayForTest(now(), 1);
        var multiLegBases = [ 6, 8, 6 ];
        var aggregateReserve = 0;
        var aggregateRequired = 0;
        var aggregateDay = {};
        var i = 0;
        thirdsDay.total_dist_nm = 24;
        thirdsDay.est_hours = 2.4;
        percentageDay.total_dist_nm = 24;
        percentageDay.est_hours = 2.4;

        thirdsDay = finalizeTimelineDay(thirdsDay, 33, "thirds");
        percentageDay = finalizeTimelineDay(percentageDay, 15, "percentage");

        expect(thirdsDay.cruise_fuel_gallons).toBe(24);
        expect(thirdsDay.reserve_gallons).toBe(12);
        expect(thirdsDay.required_fuel_gallons).toBe(36);
        expect(thirdsDay.fuel_confidence_score).toBe(100);
        expect(thirdsDay.risk_color).toBe("GREEN");
        expect(percentageDay.reserve_gallons).toBe(3.6);
        expect(percentageDay.required_fuel_gallons).toBe(27.6);
        expect(percentageDay.fuel_confidence_score).toBe(35);
        expect(percentageDay.risk_color).toBe("RED");

        for (i = 1; i LTE arrayLen(multiLegBases); i++) {
          aggregateDay = variables.timeline.buildTimelineDayForTest(now(), i);
          aggregateDay.total_dist_nm = multiLegBases[i];
          aggregateDay.est_hours = multiLegBases[i] / 10;
          aggregateDay = finalizeTimelineDay(aggregateDay, 33, "thirds");
          aggregateReserve += aggregateDay.reserve_gallons;
          aggregateRequired += aggregateDay.required_fuel_gallons;
        }
        expect(aggregateReserve).toBe(10);
        expect(aggregateRequired).toBe(30);
      });

      it("corrects Active Cruise planned fuel and labels without introducing live remaining-fuel state", function() {
        var plan = queryNew("routegen_inputs_json", "varchar", [{
          routegen_inputs_json = serializeJSON(baseRouteInputs(33, "thirds"))
        }]);
        var enriched = variables.activeCruise.enrichRouteTimelineFuelForTest(
          qPlan = plan,
          routeTimeline = {
            summary = { totalNm = 24 },
            legs = [{ distanceNm = 10 }]
          }
        );

        expect(variables.activeCruise.formatFuelReserveLabelForTest("thirds", 33, 12)).toBe("One-Third Rule / 12.0 gal");
        expect(variables.activeCruise.formatFuelReserveLabelForTest("percentage", 20, 4.8)).toBe("20% / 4.8 gal");
        expect(enriched.legs[1].fuel.totalFuelGallons).toBe(24);
        expect(enriched.legs[1].fuel.reserveGallons).toBe(12);
        expect(enriched.legs[1].fuel.fuelWithReserveGallons).toBe(36);
        expect(enriched.legs[1].fuel.reserveMode).toBe("thirds");
        expect(enriched.legs[1].fuel.reserveLabel).toBe("One-Third Rule / 12.0 gal");
        expect(structKeyExists(enriched.legs[1].fuel, "remainingFuelGallons")).toBeFalse();
      });

      it("locks draft, API, edit-context, Follow, and legacy UI reserve-mode contracts", function() {
        var routeBuilderJs = readRepoFile("assets/js/app/dashboard/routebuilder.js");
        var routeBuilderCfml = readRepoFile("api/v1/routeBuilder.cfc");
        var timelineCfml = readRepoFile("api/v1/RouteTimelineService.cfc");
        var activeCfml = readRepoFile("api/v1/ActiveCruiseViewModelService.cfc");
        var voyageCfml = readRepoFile("api/v1/voyage.cfc");
        var followJs = readRepoFile("assets/js/app/follow/follow.js");
        var routeModal = readRepoFile("includes/modals/route_generator_modal.cfm");
        var legacyCalculator = readRepoFile("app/fuel-calculator.cfm");

        expect(findNoCase("reserve_mode: getSelectedReserveMode()", routeBuilderJs)).toBeGT(0);
        expect(findNoCase("applyReserveSelection(", routeBuilderJs)).toBeGT(0);
        expect(findNoCase('payload.reserve_mode = reserveModeVal', routeBuilderCfml)).toBeGT(0);
        expect(findNoCase('"reserve_mode"=editReserveModeVal', routeBuilderCfml)).toBeGT(0);
        expect(findNoCase('"reserve_mode"=totals.RESERVE_MODE', routeBuilderCfml)).toBeGT(0);
        expect(findNoCase('"reserve_mode" = [ "reserveMode", "RESERVE_MODE" ]', timelineCfml)).toBeGT(0);
        expect(findNoCase('return "One-Third Rule / "', activeCfml)).toBeGT(0);
        expect(findNoCase('reserveEst = roundTo2(fuelEst * 0.5)', voyageCfml)).toBeGT(0);
        expect(findNoCase('plannedFuel = estimateFollowPlannedFuel(', voyageCfml)).toBeGT(0);
        expect(findNoCase('includeIdleFuelFromInputs=true', voyageCfml)).toBeGT(0);
        expect(findNoCase('includeIdleFuelFromInputs=false', voyageCfml)).toBeGT(0);
        expect(findNoCase('legOut.cruise_fuel_gallons = plannedLegFuel.cruise_fuel_gallons', voyageCfml)).toBeGT(0);
        expect(findNoCase('"Fuel + One-Third Rule reserve"', followJs)).toBeGT(0);
        expect(findNoCase('safeNum(leg.cruise_fuel_gallons)', followJs)).toBeGT(0);
        expect(findNoCase('Cruise fuel est:', followJs)).toBeGT(0);
        expect(findNoCase('>Reserve Method<', routeModal)).toBeGT(0);
        expect(findNoCase('data-reserve-mode="thirds"', routeModal)).toBeGT(0);
        expect(findNoCase('>One-Third Rule<', legacyCalculator)).toBeGT(0);
        expect(findNoCase('Rule of Thirds - 33%', routeModal)).toBe(0);
        expect(findNoCase('Rule of Thirds - 33%', legacyCalculator)).toBe(0);
      });
    });
  }

  private struct function calculateRouteBuilderFuel(
    required numeric baseFuel,
    required numeric reservePct,
    required string reserveMode
  ) {
    return variables.routeBuilder.calculateFuelEstimateForTest({
      distanceNm = arguments.baseFuel,
      maxSpeedKnots = 10,
      maxBurnGph = 10,
      efficientSpeedKnots = 0,
      efficientBurnGph = 0,
      pace = "AGGRESSIVE",
      weatherPct = 0,
      idleFuelGallons = 0,
      reservePct = arguments.reservePct,
      reserveMode = arguments.reserveMode,
      fuelPricePerGallon = 0
    });
  }

  private struct function baseRouteInputs(required numeric reservePct, required string reserveMode) {
    return {
      pace = "AGGRESSIVE",
      cruising_speed = 10,
      fuel_burn_gph = 10,
      weather_factor_pct = 0,
      reserve_pct = arguments.reservePct,
      reserve_mode = arguments.reserveMode
    };
  }

  private struct function finalizeTimelineDay(
    required struct day,
    required numeric reservePct,
    required string reserveMode
  ) {
    return variables.timeline.finalizeTimelineDayForTest(
      day = arguments.day,
      maxSpeedVal = 10,
      maxBurnForEstimateVal = 10,
      fuelBurnGphVal = 10,
      mostEfficientSpeedVal = 0,
      mostEfficientBurnGphVal = 0,
      paceVal = "AGGRESSIVE",
      paceRatioVal = 1,
      weatherFactorPctVal = 0,
      reservePctVal = arguments.reservePct,
      reserveModeVal = arguments.reserveMode,
      allowAnchoredBurnVal = false
    );
  }

  private string function readRepoFile(required string relativePath) {
    return fileRead(expandPath("/fpw/" & arguments.relativePath), "utf-8");
  }
}
