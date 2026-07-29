component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.service = new fpw.api.v1.WeatherPageViewModelService().init();
    variables.fixtureRoot = expandPath("/fpw/tests/fixtures/weather-page-view-model");
  }

  function run() {
    describe("WeatherPageViewModelService contract parity and Phase 2 opt-in endpoint shape", function() {

      it("returns the required top-level contract fields", function() {
        var model = variables.service.normalize(loadFixture("normal-summary-response.json"));
        var requiredPaths = variables.service.getRequiredFieldPaths();

        for (var path in requiredPaths) {
          expect(hasPath(model, path)).toBeTrue("Missing required path: " & path & " in " & serializeJSON(model));
        }
      });

      it("documents Weather page UI field inventory with status and source mapping", function() {
        var inventory = variables.service.getWeatherPageFieldInventory();
        expect(arrayLen(inventory)).toBeGTE(18);
        expect(findInventory(inventory, "weatherResolvedLocation").status).toBe("required");
        expect(findInventory(inventory, "weatherRiskValue").futureField).toBe("marine.riskLevel");
        expect(findInventory(inventory, "weatherSourceCacheRows").status).toBe("deprecated");
      });

      it("normalizes current conditions, target, map, alerts, forecast, and cache from a summary response", function() {
        var model = variables.service.normalize(loadFixture("normal-summary-response.json"));

        expect(model.ok).toBeTrue(serializeJSON(model));
        expect(model.requestId).toBe("fixture-summary");
        expect(model.target.displayName).toBe("Boston, MA");
        expect(model.target.zip).toBe("02110");
        expect(model.target.lat).toBe(42.3601);
        expect(model.current.stationId).toBe("KBOS");
        expect(model.current.condition).toBe("Partly Cloudy");
        expect(model.current.tempF).toBe(72);
        expect(model.current.windDirection).toBe("SW");
        expect(arrayLen(model.forecast12h)).toBe(2);
        expect(model.forecast12h[1].label).toBe("This Hour");
        expect(arrayLen(model.alerts)).toBe(1);
        expect(model.alerts[1].event).toBe("Small Craft Advisory");
        expect(model.map.layers[1].key).toBe("radar");
        expect(model.cache.forecast.status).toBe("fresh");
      });

      it("normalizes marine full hydration fields", function() {
        var model = variables.service.normalize(loadFixture("marine-full-response.json"));

        expect(model.ok).toBeTrue(serializeJSON(model));
        expect(model.status.marineReady).toBeTrue(serializeJSON(model.status));
        expect(model.marine.riskLevel).toBe("Moderate");
        expect(model.marine.riskScore).toBe(2);
        expect(model.marine.seasFt).toBe(3.2);
        expect(model.marine.wavePeriodSec).toBe(8);
        expect(model.marine.waveDirectionDeg).toBe(135);
        expect(model.marine.tideLevelFt).toBe(1.4);
        expect(model.marine.tideTrend).toBe("rising");
        expect(model.marine.nextHigh.timeUtc).toBe("2026-06-30T18:20:00Z");
        expect(model.marine.nextLow.heightFt).toBe(0.3);
        expect(model.marine.tideStation).toBe("Boston Harbor");
        expect(model.marine.waterLevelStation).toBe("8443970");
        expect(model.cache.marine.status).toBe("fresh");
        expect(model.cache.tide.status).toBe("fresh");
      });

      it("normalizes zone forecast hydration fields", function() {
        var model = variables.service.normalize(loadFixture("zone-full-response.json"));

        expect(model.ok).toBeTrue(serializeJSON(model));
        expect(model.status.zoneReady).toBeTrue(serializeJSON(model.status));
        expect(model.zoneForecast.available).toBeTrue(serializeJSON(model.zoneForecast));
        expect(model.zoneForecast.zoneId).toBe("ANZ230");
        expect(model.zoneForecast.office).toBe("BOX");
        expect(model.zoneForecast.synopsis).toInclude("High pressure");
        expect(arrayLen(model.zoneForecast.periods)).toBe(2);
        expect(model.zoneForecast.periods[1].name).toBe("Tonight");
        expect(model.zoneForecast.sourceUrl).toInclude("forecast.weather.gov");
        expect(model.cache.zoneForecast.status).toBe("fresh");
      });

      it("keeps missing marine summary responses safe and degraded without throwing", function() {
        var model = variables.service.normalize(loadFixture("summary-marine-missing-response.json"));

        expect(model.ok).toBeTrue(serializeJSON(model));
        expect(model.status.summaryReady).toBeTrue(serializeJSON(model.status));
        expect(model.status.marineReady).toBeFalse(serializeJSON(model.status));
        expect(model.status.degraded).toBeTrue(serializeJSON(model.status));
        expect(model.marine.riskLevel).toBe("Unknown");
        expect(arrayLen(model.diagnostics.warnings)).toBeGTE(1);
      });

      it("normalizes degraded no-marine and unavailable zone responses", function() {
        var model = variables.service.normalize(loadFixture("degraded-no-marine-response.json"));

        expect(model.ok).toBeTrue(serializeJSON(model));
        expect(model.status.degraded).toBeTrue(serializeJSON(model.status));
        expect(model.zoneForecast.available).toBeFalse(serializeJSON(model.zoneForecast));
        expect(model.zoneForecast.reason).toBe("No marine zone found for this point.");
        expect(model.cache.marine.status).toBe("unavailable");
        expect(arrayLen(model.diagnostics.warnings)).toBeGTE(2);
      });

      it("normalizes invalid coordinate envelopes without changing endpoint behavior", function() {
        var model = variables.service.normalize(loadFixture("invalid-coordinate-response.json"));

        expect(model.ok).toBeFalse(serializeJSON(model));
        expect(model.status.degraded).toBeTrue(serializeJSON(model.status));
        expect(model.status.messages[1]).toBe("Invalid latitude.");
        expect(model.target.displayName).toBe("");
        expect(arrayLen(model.forecast12h)).toBe(0);
      });

      it("keeps default weather endpoint validation responses in the legacy envelope without opt-in", function() {
        var raw = invokeWeatherHandle({ "action"="search", "lat"="91", "lon"="-71.0589" });
        var response = deserializeJSON(raw);

        expect(structKeyExists(response, "SUCCESS")).toBeTrue(raw);
        expect(response.SUCCESS).toBeFalse(raw);
        expect(response.MESSAGE).toBe("Latitude is invalid.");
        expect(structKeyExists(response, "DATA")).toBeTrue(raw);
        expect(structKeyExists(response, "ok")).toBeFalse(raw);
      });

      it("returns the Weather Page ViewModel envelope when viewModel=weatherPage is requested", function() {
        var raw = invokeWeatherHandle({ "action"="search", "lat"="91", "lon"="-71.0589", "viewModel"="weatherPage" });
        var response = deserializeJSON(raw);

        expect(structKeyExists(response, "ok")).toBeTrue(raw);
        expect(structKeyExists(response, "SUCCESS")).toBeFalse(raw);
        expect(response.ok).toBeFalse(raw);
        expect(response.status.degraded).toBeTrue(raw);
        expect(response.status.messages[1]).toBe("Latitude is invalid.");
        expect(structKeyExists(response, "current")).toBeTrue(raw);
        expect(structKeyExists(response, "marine")).toBeTrue(raw);
        expect(structKeyExists(response, "diagnostics")).toBeTrue(raw);
      });

    });
  }

  private string function invokeWeatherHandle(required struct params) {
    var raw = "";
    var hadSessionUser = structKeyExists(session, "user");
    var previousSessionUser = hadSessionUser ? duplicate(session.user) : {};

    session.user = { "id" = 1 };
    savecontent variable="raw" {
      new fpw.api.v1.weather().handle(argumentCollection=arguments.params);
    }
    if (hadSessionUser) {
      session.user = previousSessionUser;
    } else {
      structDelete(session, "user", false);
    }

    return trim(raw);
  }

  private struct function loadFixture(required string filename) {
    var path = variables.fixtureRoot & "/" & arguments.filename;
    expect(fileExists(path)).toBeTrue("Missing fixture: " & path);
    return deserializeJSON(fileRead(path));
  }

  private boolean function hasPath(required struct source, required string path) {
    var current = arguments.source;
    var parts = listToArray(arguments.path, ".");
    for (var part in parts) {
      if (!isStruct(current) OR !structKeyExists(current, part)) {
        return false;
      }
      current = current[part];
    }
    return true;
  }

  private struct function findInventory(required array inventory, required string element) {
    for (var row in arguments.inventory) {
      if (isStruct(row) AND structKeyExists(row, "element") AND row.element EQ arguments.element) {
        return row;
      }
    }
    return {};
  }

}











