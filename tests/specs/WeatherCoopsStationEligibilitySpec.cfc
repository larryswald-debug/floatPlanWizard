component extends="testbox.system.BaseSpec" output="false" {

  function run() {
    describe("NOAA CO-OPS local-station eligibility", function() {

      beforeEach(function() {
        variables.cacheName = "fpwWeatherCoopsEligibilityTest_" & replace(createUUID(), "-", "", "all");
        variables.cache = createObject("component", "fpw.api.v1.weather.WeatherCache").init(variables.cacheName);
        variables.client = prepareMock(
          createObject("component", "fpw.api.v1.weather.WeatherCoopsClient").init("FPW weather eligibility test")
        );
      });

      afterEach(function() {
        structDelete(application, variables.cacheName);
      });

      it("accepts a nearby coastal tide station and reports both distance units", function() {
        variables.client.$("fetchStations", stationResponse([
          { id = "8726996", name = "Cross Bayou", lat = 27.9447, lng = -82.8325 }
        ]));

        var station = variables.client.nearestStation(28.245, -82.719, "tidepredictions");

        expect(station.available).toBeTrue();
        expect(station.id).toBe("8726996");
        expect(station.name).toBe("Cross Bayou");
        expect(station.distanceMiles).toBeLT(120 * 1.150779448);
        expect(station.distanceNauticalMiles).toBeLT(120);
        expect(station.reason).toBe("");
      });

      it("rejects a distant tide station without leaking station or tide data", function() {
        variables.client.$("fetchStations", stationResponse([
          { id = "TWC0389", name = "Puerto Penasco", lat = 31.305, lng = -113.54 }
        ]));

        var bundle = variables.client.getTideBundle(39.751526, -104.997673);

        expect(bundle.available).toBeFalse();
        expect(bundle.tideStation).toBe("");
        expect(bundle.waterLevelStation).toBe("");
        expect(arrayLen(bundle.tidePredictions)).toBe(0);
        expect(arrayLen(bundle.sources)).toBe(0);
        expect(isNull(bundle.tideLevelFt)).toBeTrue();
        expect(isNull(bundle.nextHigh)).toBeTrue();
        expect(isNull(bundle.nextLow)).toBeTrue();
        expect(arrayLen(bundle.warnings)).toBe(1);
        expect(bundle.warnings[1]).toInclude("within 120 nautical miles");
      });

      it("applies the same 120 nautical-mile rule to water-level stations", function() {
        variables.client.$("fetchStations", stationResponse([
          { id = "9410170", name = "San Diego", lat = 32.7142, lng = -117.1736 }
        ]));

        var station = variables.client.nearestStation(39.751526, -104.997673, "waterlevels");

        expect(station.available).toBeFalse();
        expect(station.id).toBe("");
        expect(station.name).toBe("");
        expect(isNull(station.lat)).toBeTrue();
        expect(isNull(station.lon)).toBeTrue();
        expect(isNull(station.distanceMiles)).toBeTrue();
        expect(isNull(station.distanceNauticalMiles)).toBeTrue();
        expect(station.reason).toInclude("waterlevels");
        expect(station.reason).toInclude("within 120 nautical miles");
      });

      it("reapplies eligibility when the station list comes from cache", function() {
        variables.client.$("fetchStations", stationResponse([
          { id = "TWC0389", name = "Puerto Penasco", lat = 31.305, lng = -113.54 }
        ]));

        var first = variables.client.nearestStation(39.751526, -104.997673, "tidepredictions", variables.cache);
        var second = variables.client.nearestStation(39.751526, -104.997673, "tidepredictions", variables.cache);

        expect(first.cache.status).toBe("miss");
        expect(second.cache.status).toBe("hit");
        expect(first.available).toBeFalse();
        expect(second.available).toBeFalse();
        expect(second.id).toBe("");
        expect(second.name).toBe("");
        expect(second.reason).toInclude("within 120 nautical miles");
      });
    });
  }

  private struct function stationResponse(required array stations) {
    return {
      ok = true,
      statusCode = 200,
      url = "test://coops/stations",
      data = { stations = arguments.stations },
      error = ""
    };
  }
}
