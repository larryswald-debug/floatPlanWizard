component extends="testbox.system.BaseSpec" {

  function beforeAll() {
    variables.fixtureRoot = expandPath("/fpw/tests/fixtures/weather-rewrite-phase1");
    variables.testDsn = structKeyExists(application, "dsn") && len(application.dsn) ? application.dsn : "fpw";
    variables.createdUserIds = [];
    variables.nws = new fpw.api.v1.weather.WeatherNwsClient().init();
    variables.coops = new fpw.api.v1.weather.WeatherCoopsClient().init();
    variables.risk = createObject("component", "fpw.api.v1.weather.WeatherRiskService").init();
  }

  function afterAll() {
    cleanupWeatherTestUsers();
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

      it("resolves explicit valid coordinates before other target sources", function() {
        var resolver = new fpw.api.v1.WeatherTargetResolver().init("");
        var target = resolver.resolve(0, { "lat" = "27.9506", "lon" = "-82.4572", "zip" = "99999" });

        expect(target.available).toBeTrue();
        expect(target.sourceType).toBe("coordinates");
        expect(round(target.lat * 10000) / 10000).toBe(27.9506);
        expect(round(target.lon * 10000) / 10000).toBe(-82.4572);
      });

      it("returns degraded contract data for invalid coordinates without provider calls", function() {
        var service = new fpw.api.v1.WeatherPageService().init("");
        var model = service.getPageWeather(0, { "lat" = "abc", "lon" = "-82.7" });

        expect(model.ok).toBeFalse();
        expect(model.status.degraded).toBeTrue();
        expect(model.status.reason).toBe("INVALID_COORDINATES");
        expect(model.target.sourceType).toBe("fallback");
        expect(arrayLen(model.cache.entries)).toBe(0);
        expect(arrayToList(model.status.messages, " ")).toInclude("coordinates entered were not valid");
        expect(arrayLen(model.diagnostics.warnings)).toBeGT(0);
      });

      it("returns degraded contract data when no coordinates are available", function() {
        var service = new fpw.api.v1.WeatherPageService().init("");
        var model = service.getPageWeather(0, {});

        expect(model.ok).toBeFalse();
        expect(model.status.degraded).toBeTrue();
        expect(model.status.reason).toBe("NO_TARGET");
        expect(arrayToList(model.status.messages, " ")).toInclude("home-port location with coordinates");
        expect(model.cache.summary).toInclude("No provider requests");
        expect(arrayLen(model.cache.entries)).toBe(0);
      });

      it("returns clear missing-coordinate copy for a home port without lat/lng", function() {
        var userId = createWeatherTestUser();
        insertWeatherHomePort(userId, "Madeira Beach", "FL", "33708", "", "");

        var service = new fpw.api.v1.WeatherPageService().init(variables.testDsn);
        var model = service.getPageWeather(userId, {});

        expect(model.ok).toBeFalse();
        expect(model.status.reason).toBe("HOMEPORT_NO_COORDINATES");
        expect(model.target.reason).toBe("HOMEPORT_NO_COORDINATES");
        expect(arrayToList(model.status.messages, " ")).toInclude("Weather needs a saved home-port location with coordinates");
        expect(arrayLen(model.cache.entries)).toBe(0);
      });

      it("prefers stored member home-port coordinates over explicit ZIP-only fallback", function() {
        var userId = createWeatherTestUser();
        insertWeatherHomePort(userId, "Madeira Beach", "FL", "33708", "27.7856", "-82.7814");

        var resolver = new fpw.api.v1.WeatherTargetResolver().init(variables.testDsn);
        var target = resolver.resolve(userId, { "zip" = "99999" });

        expect(target.available).toBeTrue();
        expect(target.sourceType).toBe("homeport");
        expect(target.zip).toBe("33708");
        expect(round(target.lat * 10000) / 10000).toBe(27.7856);
        expect(round(target.lon * 10000) / 10000).toBe(-82.7814);
      });

      it("does not invent coordinates for ZIP-only requests without an approved resolver", function() {
        var service = new fpw.api.v1.WeatherPageService().init("");
        var model = service.getPageWeather(0, { "zip" = "33708" });

        expect(model.ok).toBeFalse();
        expect(model.status.reason).toBe("ZIP_COORDINATES_UNAVAILABLE");
        expect(model.target.sourceType).toBe("manual ZIP");
        expect(model.target.zip).toBe("33708");
        expect(arrayLen(model.cache.entries)).toBe(0);
        expect(arrayToList(model.status.messages, " ")).toInclude("ZIP-only weather lookup is not enabled yet");
      });

      it("returns degraded contract data when required NWS point metadata fails", function() {
        var service = new fpw.api.v1.WeatherPageService().init(
          "",
          new fpw.api.v1.weather.WeatherCache().init("fpwWeatherRewritePhase2PointFailure" & replace(createUUID(), "-", "", "all")),
          createObject("component", "fpw.tests.fixtures.weather_rewrite_phase2.FakeResolver").init(true),
          createObject("component", "fpw.tests.fixtures.weather_rewrite_phase2.FakeNwsClient").init(true),
          createObject("component", "fpw.tests.fixtures.weather_rewrite_phase2.FakeCoopsClient").init(false),
          variables.risk
        );
        var model = service.getPageWeather(1, {});

        expect(model.ok).toBeFalse();
        expect(model.status.degraded).toBeTrue();
        expect(arrayToList(model.diagnostics.warnings, " ")).toInclude("NWS point failure");
        expect(arrayLen(model.cache.entries)).toBeGT(0);
      });

      it("keeps useful NWS data when optional CO-OPS tide data fails", function() {
        var service = new fpw.api.v1.WeatherPageService().init(
          "",
          new fpw.api.v1.weather.WeatherCache().init("fpwWeatherRewritePhase2CoopsFailure" & replace(createUUID(), "-", "", "all")),
          createObject("component", "fpw.tests.fixtures.weather_rewrite_phase2.FakeResolver").init(true),
          createObject("component", "fpw.tests.fixtures.weather_rewrite_phase2.FakeNwsClient").init(false),
          createObject("component", "fpw.tests.fixtures.weather_rewrite_phase2.FakeCoopsClient").init(true),
          variables.risk
        );
        var model = service.getPageWeather(1, {});

        expect(model.ok).toBeTrue();
        expect(model.current.available).toBeTrue();
        expect(arrayLen(model.forecast12h)).toBeGT(0);
        expect(model.marine.available).toBeFalse();
        expect(arrayToList(model.marine.warnings, " ")).toInclude("Tide data is temporarily unavailable");
        expect(findNoCase("fake failure", arrayToList(model.marine.warnings, " "))).toBe(0);
        expect(arrayToList(model.status.messages, " ")).toInclude("optional marine or observation data");
      });

      it("keeps the response renderable when alerts are empty", function() {
        var service = new fpw.api.v1.WeatherPageService().init(
          "",
          new fpw.api.v1.weather.WeatherCache().init("fpwWeatherRewritePhase3NoAlerts" & replace(createUUID(), "-", "", "all")),
          createObject("component", "fpw.tests.fixtures.weather_rewrite_phase2.FakeResolver").init(true),
          createObject("component", "fpw.tests.fixtures.weather_rewrite_phase2.FakeNwsClient").init(false),
          createObject("component", "fpw.tests.fixtures.weather_rewrite_phase2.FakeCoopsClient").init(false),
          variables.risk
        );
        var model = service.getPageWeather(1, {});

        expect(model.ok).toBeTrue();
        expect(isArray(model.alerts)).toBeTrue();
        expect(arrayLen(model.alerts)).toBe(0);
        expect(model.status.ready).toBeTrue();
      });

      it("keeps the response renderable when forecast12h is empty", function() {
        var service = new fpw.api.v1.WeatherPageService().init(
          "",
          new fpw.api.v1.weather.WeatherCache().init("fpwWeatherRewritePhase3EmptyForecast" & replace(createUUID(), "-", "", "all")),
          createObject("component", "fpw.tests.fixtures.weather_rewrite_phase2.FakeResolver").init(true),
          createObject("component", "fpw.tests.fixtures.weather_rewrite_phase2.FakeNwsClient").init(false, true),
          createObject("component", "fpw.tests.fixtures.weather_rewrite_phase2.FakeCoopsClient").init(false),
          variables.risk
        );
        var model = service.getPageWeather(1, {});

        expect(model.ok).toBeTrue();
        expect(isArray(model.forecast12h)).toBeTrue();
        expect(arrayLen(model.forecast12h)).toBe(0);
        expect(model.current.available).toBeTrue();
      });

      it("returns the clean contract with cache metadata for a successful normalized response", function() {
        var service = new fpw.api.v1.WeatherPageService().init(
          "",
          new fpw.api.v1.weather.WeatherCache().init("fpwWeatherRewritePhase2Success" & replace(createUUID(), "-", "", "all")),
          createObject("component", "fpw.tests.fixtures.weather_rewrite_phase2.FakeResolver").init(true),
          createObject("component", "fpw.tests.fixtures.weather_rewrite_phase2.FakeNwsClient").init(false),
          createObject("component", "fpw.tests.fixtures.weather_rewrite_phase2.FakeCoopsClient").init(false),
          variables.risk
        );
        var model = service.getPageWeather(1, {});

        expect(model.ok).toBeTrue();
        expect(model).toHaveKey("requestId");
        expect(model).toHaveKey("generatedAtUtc");
        expect(model).toHaveKey("sources");
        expect(model.cache).toHaveKey("entries");
        expect(arrayLen(model.cache.entries)).toBeGT(0);
        expect(model.cache.entries[1]).toHaveKey("key");
        expect(model.cache.entries[1]).toHaveKey("status");
        expect(model.cache.entries[1]).toHaveKey("durationMs");
        expect(model).notToHaveKey("SUCCESS");
        expect(model).notToHaveKey("DATA");
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

  private numeric function createWeatherTestUser() {
    var email = "fpw-weather-phase2-" & lcase(replace(createUUID(), "-", "", "all")) & "@example.invalid";

    queryExecute(
      "INSERT INTO users (fName, lName, email, password, passwordCreated, created, lastUpdate)
       VALUES (:fName, :lName, :email, :password, :passwordCreated, :created, :lastUpdate)",
      {
        fName = { value = "Weather", cfsqltype = "cf_sql_varchar" },
        lName = { value = "Phase2", cfsqltype = "cf_sql_varchar" },
        email = { value = email, cfsqltype = "cf_sql_varchar" },
        password = { value = "test", cfsqltype = "cf_sql_varchar" },
        passwordCreated = { value = now(), cfsqltype = "cf_sql_timestamp" },
        created = { value = now(), cfsqltype = "cf_sql_timestamp" },
        lastUpdate = { value = now(), cfsqltype = "cf_sql_timestamp" }
      },
      { datasource = variables.testDsn }
    );

    var qUser = queryExecute(
      "SELECT userId FROM users WHERE email = :email LIMIT 1",
      { email = { value = email, cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.testDsn }
    );

    arrayAppend(variables.createdUserIds, val(qUser.userId[1]));
    return val(qUser.userId[1]);
  }

  private void function insertWeatherHomePort(required numeric userId, required string city, required string state, required string zip, required string lat, required string lng) {
    queryExecute(
      "INSERT INTO users_address (userId, address, city, state, zip, phone, lat, lng, isHomePort)
       VALUES (:userId, :address, :city, :state, :zip, :phone, :lat, :lng, 1)",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        address = { value = "Test Dock", cfsqltype = "cf_sql_varchar" },
        city = { value = arguments.city, cfsqltype = "cf_sql_varchar" },
        state = { value = arguments.state, cfsqltype = "cf_sql_varchar" },
        zip = { value = arguments.zip, cfsqltype = "cf_sql_varchar" },
        phone = { value = "", cfsqltype = "cf_sql_varchar", null = true },
        lat = { value = arguments.lat, cfsqltype = "cf_sql_varchar" },
        lng = { value = arguments.lng, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.testDsn }
    );
  }

  private void function cleanupWeatherTestUsers() {
    if (!structKeyExists(variables, "createdUserIds")) {
      return;
    }
    for (var userId in variables.createdUserIds) {
      queryExecute(
        "DELETE FROM users_address WHERE userId = :userId",
        { userId = { value = userId, cfsqltype = "cf_sql_integer" } },
        { datasource = variables.testDsn }
      );
      queryExecute(
        "DELETE FROM users WHERE userId = :userId",
        { userId = { value = userId, cfsqltype = "cf_sql_integer" } },
        { datasource = variables.testDsn }
      );
    }
  }
}

