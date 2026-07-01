component extends="testbox.system.BaseSpec" {

  function beforeAll() {
    variables.fixtureRoot = expandPath("/fpw/tests/fixtures/weather-rewrite-phase1");
    variables.testDsn = structKeyExists(application, "dsn") && len(application.dsn) ? application.dsn : "fpw";
    variables.createdUserIds = [];
    variables.nws = new fpw.api.v1.weather.WeatherNwsClient().init();
    variables.coops = new fpw.api.v1.weather.WeatherCoopsClient().init();
    variables.risk = createObject("component", "fpw.api.v1.weather.WeatherRiskService").init();
    variables.phase4ZipFixture = expandPath("/fpw/tests/fixtures/weather_rewrite_phase4/zcta-test-coordinates.csv");
    variables.zipService = new fpw.api.v1.weather.WeatherZipCoordinateService().init(variables.phase4ZipFixture);
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

      it("returns clear missing-coordinate copy for a home port without lat/lng or ZIP", function() {
        var userId = createWeatherTestUser();
        insertWeatherHomePort(userId, "Madeira Beach", "FL", "", "", "");

        var service = new fpw.api.v1.WeatherPageService().init(variables.testDsn);
        var model = service.getPageWeather(userId, {});

        expect(model.ok).toBeFalse();
        expect(model.status.reason).toBe("HOMEPORT_NO_COORDINATES");
        expect(model.target.reason).toBe("HOMEPORT_NO_COORDINATES");
        expect(arrayToList(model.status.messages, " ")).toInclude("Weather needs a saved home-port location with coordinates");
        expect(arrayLen(model.cache.entries)).toBe(0);
      });

      it("prefers explicit ZIP lookup over stored member home-port coordinates", function() {
        var userId = createWeatherTestUser();
        insertWeatherHomePort(userId, "Madeira Beach", "FL", "33708", "27.7856", "-82.7814");

        var resolver = new fpw.api.v1.WeatherTargetResolver().init(variables.testDsn, variables.zipService);
        var target = resolver.resolve(userId, { "zip" = "34652" });

        expect(target.available).toBeTrue();
        expect(target.sourceType).toBe("zip_zcta");
        expect(target.zip).toBe("34652");
        expect(round(target.lat * 1000000) / 1000000).toBe(28.240555);
        expect(round(target.lon * 1000000) / 1000000).toBe(-82.744353);
      });

      it("uses ZIP authority when saved home-port coordinates do not match the saved ZIP", function() {
        var userId = createWeatherTestUser();
        insertWeatherHomePort(userId, "New Port Richey", "FL", "34652", "41.505436", "-88.096043");

        var resolver = new fpw.api.v1.WeatherTargetResolver().init(variables.testDsn, variables.zipService);
        var target = resolver.resolve(userId, {});

        expect(target.available).toBeTrue();
        expect(target.sourceType).toBe("homeport_zip_zcta");
        expect(target.displayName).toBe("New Port Richey, FL");
        expect(target.zip).toBe("34652");
        expect(target.isApproximate).toBeTrue();
        expect(arrayToList(target.warnings, " ")).toInclude("Saved home-port coordinates did not match the ZIP area");
        expect(round(target.lat * 1000000) / 1000000).toBe(28.240555);
        expect(round(target.lon * 1000000) / 1000000).toBe(-82.744353);
      });

      it("resolves valid ZIP-only requests through approved approximate ZCTA coordinates", function() {
        var resolver = new fpw.api.v1.WeatherTargetResolver().init("", variables.zipService);
        var target = resolver.resolve(0, { "zip" = "34652" });

        expect(target.available).toBeTrue();
        expect(target.sourceType).toBe("zip_zcta");
        expect(target.displayName).toBe("ZIP area 34652");
        expect(target.zip).toBe("34652");
        expect(target.isApproximate).toBeTrue();
        expect(target.source).toBe("CENSUS_ZCTA_GAZETTEER");
        expect(arrayToList(target.warnings, " ")).toInclude("ZIP-area coordinates are approximate");
        expect(round(target.lat * 1000000) / 1000000).toBe(28.240555);
        expect(round(target.lon * 1000000) / 1000000).toBe(-82.744353);
      });

      it("allows provider calls only after a valid ZIP authority coordinate resolves", function() {
        var service = newPhase4WeatherService("fpwWeatherRewritePhase4ZipSuccess");
        var model = service.getPageWeather(0, { "zip" = "34652" });

        expect(model.ok).toBeTrue();
        expect(model.target.sourceType).toBe("zip_zcta");
        expect(model.target.displayName).toBe("ZIP area 34652");
        expect(model.target.isApproximate).toBeTrue();
        expect(arrayLen(model.forecast12h)).toBeGT(0);
        expect(arrayLen(model.cache.entries)).toBeGT(0);
      });

      it("returns degraded contract data for invalid ZIP format without provider calls", function() {
        var service = newPhase4WeatherService("fpwWeatherRewritePhase4InvalidZip");
        var model = service.getPageWeather(0, { "zip" = "12ab3" });

        expect(model.ok).toBeFalse();
        expect(model.status.reason).toBe("INVALID_ZIP");
        expect(model.target.sourceType).toBe("fallback");
        expect(arrayLen(model.cache.entries)).toBe(0);
        expect(arrayToList(model.status.messages, " ")).toInclude("valid 5-digit ZIP");
      });

      it("returns degraded contract data for unknown ZIP without provider calls", function() {
        var service = newPhase4WeatherService("fpwWeatherRewritePhase4UnknownZip");
        var model = service.getPageWeather(0, { "zip" = "99999" });

        expect(model.ok).toBeFalse();
        expect(model.status.reason).toBe("ZIP_NOT_FOUND");
        expect(model.target.sourceType).toBe("zip_zcta");
        expect(model.target.zip).toBe("99999");
        expect(arrayLen(model.cache.entries)).toBe(0);
        expect(arrayToList(model.status.messages, " ")).toInclude("No approved ZIP-area coordinate");
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
        expect(model.marine.seasFt).toBe(3);
        expect(model.marine.waveHeightFt).toBe(3);
        expect(model.marine.wavePeriodSec).toBe(4);
        expect(model.forecast12h[1].seasFt).toBe(3);
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

      it("extracts seas and wave period from NWS marine zone forecast text", function() {
        var zone = variables.nws.normalizeZoneForecast(
          {
            "available" = true,
            "zoneId" = "GMZ853",
            "zoneName" = "Coastal waters",
            "office" = "TBW",
            "sourceUrl" = "https://api.weather.gov/zones/marine/GMZ853"
          },
          {
            "properties" = {
              "periods" = [{
                "name" = "Tonight",
                "detailedForecast" = "East winds 5 to 10 knots. Seas 2 to 3 feet. Dominant period 4 seconds."
              }]
            }
          }
        );

        expect(zone.available).toBeTrue();
        expect(zone.seasFt).toBe(3);
        expect(zone.waveHeightFt).toBe(3);
        expect(zone.wavePeriodSec).toBe(4);
      });

      it("parses NOAA Coastal Waters Forecast text for the selected marine zone", function() {
        var zone = variables.nws.normalizeCwfZoneForecast(
          {
            "available" = true,
            "zoneId" = "GMZ850",
            "zoneName" = "Coastal waters from Tarpon Springs to Suwannee River FL out 20 NM",
            "office" = "TBW",
            "sourceUrl" = "https://api.weather.gov/zones/marine/GMZ850"
          },
          {
            "@id" = "https://api.weather.gov/products/fake-cwf",
            "productText" =
              "GMZ850-011330-" & chr(10)
              & "Coastal waters from Tarpon Springs to Suwannee River FL out 20 NM-" & chr(10)
              & "834 PM EDT Tue Jun 30 2026" & chr(10)
              & chr(10)
              & ".TONIGHT...East winds 5 to 10 knots. Seas 1 foot or less. Wave Detail: Northeast 1 foot at 2 seconds." & chr(10)
              & ".WEDNESDAY...Northeast winds 5 to 10 knots. Seas 1 foot or less." & chr(10)
              & "$$"
          }
        );

        expect(zone.available).toBeTrue(serializeJSON(zone));
        expect(zone.zoneId).toBe("GMZ850");
        expect(arrayLen(zone.periods)).toBe(2);
        expect(zone.periods[1].name).toBe("TONIGHT");
        expect(zone.seasFt).toBe(1);
        expect(zone.waveHeightFt).toBe(1);
        expect(zone.wavePeriodSec).toBe(2);
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

  private any function newPhase4WeatherService(required string cachePrefix) {
    return new fpw.api.v1.WeatherPageService().init(
      "",
      new fpw.api.v1.weather.WeatherCache().init(arguments.cachePrefix & replace(createUUID(), "-", "", "all")),
      new fpw.api.v1.WeatherTargetResolver().init("", variables.zipService),
      createObject("component", "fpw.tests.fixtures.weather_rewrite_phase2.FakeNwsClient").init(false),
      createObject("component", "fpw.tests.fixtures.weather_rewrite_phase2.FakeCoopsClient").init(false),
      variables.risk
    );
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
