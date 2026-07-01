component extends="testbox.system.BaseSpec" {

  function beforeAll() {
    variables.fixtureRoot = expandPath("/fpw/tests/fixtures/weather-rewrite-phase1");
    variables.nws = new fpw.api.v1.weather.WeatherNwsClient().init();
    variables.coops = new fpw.api.v1.weather.WeatherCoopsClient().init();
    variables.risk = createObject("component", "fpw.api.v1.weather.WeatherRiskService").init();
  }

  function run() {
    describe("Weather rewrite Phase 1 clean contract", function() {

      it("creates the minimum Weather page contract shape without legacy envelopes", function() {
        var service = new fpw.api.v1.WeatherPageService().init("");
        var model = service.emptyContract();

        expect(model).toHaveKey("ok");
        expect(model).toHaveKey("target");
        expect(model).toHaveKey("current");
        expect(model).toHaveKey("marine");
        expect(model).toHaveKey("forecast12h");
        expect(model).toHaveKey("alerts");
        expect(model).toHaveKey("zoneForecast");
        expect(model).toHaveKey("cache");
        expect(model).toHaveKey("diagnostics");
        expect(model).notToHaveKey("SUCCESS");
        expect(model).notToHaveKey("DATA");
      });

      it("returns degraded contract data for invalid coordinates without provider calls", function() {
        var service = new fpw.api.v1.WeatherPageService().init("");
        var model = service.getPageWeather(0, { "lat" = "abc", "lon" = "-82.7" });

        expect(model.ok).toBeFalse();
        expect(model.status.degraded).toBeTrue();
        expect(model.target.sourceType).toBe("fallback");
        expect(arrayLen(model.diagnostics.warnings)).toBeGT(0);
      });

      it("normalizes NWS current observation fields", function() {
        var payload = readFixtureJson("nws-observation.json");
        var current = variables.nws.normalizeCurrentObservation(payload, "KPIE");

        expect(current.available).toBeTrue();
        expect(current.condition).toBe("Partly Cloudy");
        expect(current.tempF).toBe(86);
        expect(current.feelsLikeF).toBe(90);
        expect(current.windMph).toBe(11);
        expect(current.gustMph).toBe(20);
        expect(current.windDirectionLabel).toBe("E");
        expect(current.stationId).toBe("KPIE");
      });

      it("normalizes NWS hourly periods into the 12-hour page rows", function() {
        var payload = readFixtureJson("nws-hourly.json");
        var rows = variables.nws.normalizeForecast12h(payload, variables.risk);

        expect(arrayLen(rows)).toBe(2);
        expect(rows[1].condition).toBe("Scattered Showers");
        expect(rows[1].windMph).toBe(10);
        expect(rows[1].precipChancePct).toBe(60);
      });

      it("normalizes NWS alert features", function() {
        var payload = readFixtureJson("nws-alerts.json");
        var alerts = variables.nws.normalizeAlerts(payload);

        expect(arrayLen(alerts)).toBe(1);
        expect(alerts[1].event).toBe("Small Craft Advisory");
        expect(alerts[1].severity).toBe("Moderate");
      });

      it("normalizes CO-OPS tide predictions", function() {
        var payload = readFixtureJson("coops-predictions.json");
        var tide = variables.coops.normalizePredictions(payload);

        expect(tide.available).toBeTrue();
        expect(tide.nextHigh.type).toBe("H");
        expect(tide.nextLow.type).toBe("L");
      });

      it("scores marine risk deterministically", function() {
        var result = variables.risk.scoreConditions(
          { "windMph" = 18, "gustMph" = 25, "visibilityMi" = 10 },
          { "seasFt" = 3.5 },
          []
        );

        expect(result.riskLevel).toBe("Caution");
        expect(result.riskScore).toBeGT(0);
      });

      it("records typed cache miss and hit states", function() {
        var cache = new fpw.api.v1.weather.WeatherCache().init("fpwWeatherRewritePhase1SpecCache" & replace(createUUID(), "-", "", "all"));
        var calls = 0;

        var first = cache.remember("spec:key", 60, function() {
          calls++;
          return { "value" = "fresh" };
        });
        var second = cache.remember("spec:key", 60, function() {
          calls++;
          return { "value" = "stale" };
        });

        expect(first.cache.status).toBe("miss");
        expect(second.cache.status).toBe("hit");
        expect(calls).toBe(1);
        expect(second.value.value).toBe("fresh");
      });
    });
  }

  private struct function readFixtureJson(required string name) {
    return deserializeJSON(fileRead(variables.fixtureRoot & "/" & arguments.name));
  }
}





