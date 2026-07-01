component output="false" {

  public any function init(string dsn = "", any cache = "", any resolver = "", any nws = "", any coops = "", any risk = "") {
    variables.dsn = len(arguments.dsn) ? arguments.dsn : (structKeyExists(application, "dsn") ? application.dsn : "");
    variables.cache = isObject(arguments.cache) ? arguments.cache : createObject("component", "fpw.api.v1.weather.WeatherCache").init();
    variables.resolver = isObject(arguments.resolver) ? arguments.resolver : createObject("component", "fpw.api.v1.WeatherTargetResolver").init(variables.dsn);
    variables.nws = isObject(arguments.nws) ? arguments.nws : createObject("component", "fpw.api.v1.weather.WeatherNwsClient").init();
    variables.coops = isObject(arguments.coops) ? arguments.coops : createObject("component", "fpw.api.v1.weather.WeatherCoopsClient").init();
    variables.risk = isObject(arguments.risk) ? arguments.risk : createObject("component", "fpw.api.v1.weather.WeatherRiskService").init();
    return this;
  }

  public struct function getPageWeather(required numeric userId, struct request = {}) {
    var model = emptyContract();
    model.requestId = createUUID();
    model.generatedAtUtc = isoUtc(now());

    var started = getTickCount();
    var cacheEntries = [];
    var target = variables.resolver.resolve(arguments.userId, arguments.request);
    applyTarget(model, target);

    if (!target.available) {
      model.ok = false;
      model.status.ready = false;
      model.status.degraded = true;
      arrayAppend(model.status.messages, "Weather target could not be resolved.");
      arrayAppend(model.status.messages, target.warnings, true);
      arrayAppend(model.diagnostics.warnings, target.warnings, true);
      model.diagnostics.timingsMs.total = getTickCount() - started;
      model.cache.entries = cacheEntries;
      model.cache.summary = "No provider requests were made because no target was available.";
      return model;
    }

    var pointFetch = cachedFetch("nws:point:" & target.lat & "," & target.lon, 86400, function() {
      return variables.nws.getPoint(target.lat, target.lon);
    });
    arrayAppend(cacheEntries, pointFetch.cache);

    if (!pointFetch.value.ok) {
      model.ok = false;
      model.status.degraded = true;
      arrayAppend(model.status.messages, "NWS point metadata was unavailable.");
      arrayAppend(model.diagnostics.warnings, pointFetch.value.error);
      model.diagnostics.timingsMs.total = getTickCount() - started;
      model.cache.entries = cacheEntries;
      model.cache.summary = cacheSummary(cacheEntries);
      return model;
    }

    var point = variables.nws.normalizePoint(pointFetch.value.data);
    if (len(point.timezone)) {
      model.target.timezone = point.timezone;
    }
    if (!len(model.target.displayName) && len(point.displayName)) {
      model.target.displayName = point.displayName;
    }

    var hourlyFetch = {};
    if (len(point.forecastHourlyUrl)) {
      hourlyFetch = cachedFetch("nws:hourly:" & point.forecastHourlyUrl, 900, function() {
        return variables.nws.getHourlyForecast(point.forecastHourlyUrl);
      });
      arrayAppend(cacheEntries, hourlyFetch.cache);
      if (hourlyFetch.value.ok) {
        model.forecast12h = variables.nws.normalizeForecast12h(hourlyFetch.value.data, variables.risk);
      } else {
        arrayAppend(model.diagnostics.warnings, hourlyFetch.value.error);
      }
    }

    var stationId = "";
    if (len(point.observationStationsUrl)) {
      var stationsFetch = cachedFetch("nws:stations:" & point.observationStationsUrl, 21600, function() {
        return variables.nws.getObservationStations(point.observationStationsUrl);
      });
      arrayAppend(cacheEntries, stationsFetch.cache);
      if (stationsFetch.value.ok) {
        stationId = variables.nws.firstStationId(stationsFetch.value.data);
      } else {
        arrayAppend(model.diagnostics.warnings, stationsFetch.value.error);
      }
    }

    if (len(stationId)) {
      var obsFetch = cachedFetch("nws:observation:" & stationId, 300, function() {
        return variables.nws.getLatestObservation(stationId);
      });
      arrayAppend(cacheEntries, obsFetch.cache);
      if (obsFetch.value.ok) {
        model.current = variables.nws.normalizeCurrentObservation(obsFetch.value.data, stationId);
      } else {
        model.current.stationId = stationId;
        model.current.stationName = stationId;
        arrayAppend(model.diagnostics.warnings, obsFetch.value.error);
      }
    }

    var alertsFetch = cachedFetch("nws:alerts:" & target.lat & "," & target.lon, 180, function() {
      return variables.nws.getActiveAlerts(target.lat, target.lon);
    });
    arrayAppend(cacheEntries, alertsFetch.cache);
    if (alertsFetch.value.ok) {
      model.alerts = variables.nws.normalizeAlerts(alertsFetch.value.data);
    } else {
      arrayAppend(model.diagnostics.warnings, alertsFetch.value.error);
    }

    var marineStart = getTickCount();
    try {
      model.marine = variables.coops.getTideBundle(target.lat, target.lon, variables.cache);
      if (structKeyExists(model.marine, "_cacheEntries") && isArray(model.marine._cacheEntries)) {
        arrayAppend(cacheEntries, model.marine._cacheEntries, true);
        structDelete(model.marine, "_cacheEntries", false);
      }
    } catch (any marineErr) {
      model.marine.available = false;
      arrayAppend(model.marine.warnings, "CO-OPS tide data was unavailable.");
      arrayAppend(model.diagnostics.warnings, marineErr.message);
    }
    model.diagnostics.timingsMs.coopsMs = getTickCount() - marineStart;

    var zoneFetch = cachedFetch("nws:marine-zones:" & target.lat & "," & target.lon, 21600, function() {
      return variables.nws.getMarineZones(target.lat, target.lon);
    });
    arrayAppend(cacheEntries, zoneFetch.cache);
    var zoneMeta = {};
    if (zoneFetch.value.ok) {
      zoneMeta = variables.nws.normalizeMarineZone(zoneFetch.value.data);
      if (zoneMeta.available && len(zoneMeta.zoneId)) {
        var zoneForecastFetch = cachedFetch("nws:zone-forecast:" & zoneMeta.zoneId, 1800, function() {
          return variables.nws.getZoneForecast(zoneMeta.zoneId);
        });
        arrayAppend(cacheEntries, zoneForecastFetch.cache);
        if (zoneForecastFetch.value.ok) {
          model.zoneForecast = variables.nws.normalizeZoneForecast(zoneMeta, zoneForecastFetch.value.data);
        } else {
          model.zoneForecast = variables.nws.normalizeZoneForecast(zoneMeta, {});
          model.zoneForecast.reason = zoneForecastFetch.value.error;
          arrayAppend(model.diagnostics.warnings, zoneForecastFetch.value.error);
        }
      } else {
        model.zoneForecast = variables.nws.normalizeZoneForecast(zoneMeta, {});
      }
    } else {
      model.zoneForecast.reason = zoneFetch.value.error;
      arrayAppend(model.diagnostics.warnings, zoneFetch.value.error);
    }

    var risk = variables.risk.scoreConditions(model.current, model.marine, model.alerts);
    model.marine.riskLevel = risk.riskLevel;
    model.marine.riskScore = risk.riskScore;
    model.marine.recommendation = risk.recommendation;

    for (var i = 1; i <= arrayLen(model.forecast12h); i++) {
      model.forecast12h[i].riskLabel = variables.risk.riskForForecastPeriod(model.forecast12h[i], model.marine);
    }

    model.map.center.lat = target.lat;
    model.map.center.lon = target.lon;
    model.map.layers = [
      { "key" = "radar", "label" = "Radar", "provider" = "NOAA/NWS", "available" = true },
      { "key" = "alerts", "label" = "Active Alerts", "provider" = "NOAA/NWS", "available" = true },
      { "key" = "surface", "label" = "Surface Fronts", "provider" = "NOAA/NWS", "available" = true }
    ];

    model.sources = buildSources(point, stationId, model.marine, model.zoneForecast);
    model.status.ready = model.current.available || arrayLen(model.forecast12h) GT 0 || arrayLen(model.alerts) GT 0;
    model.status.degraded = !model.current.available || !model.marine.available || !model.zoneForecast.available;
    model.ok = model.status.ready;
    if (model.status.degraded) {
      arrayAppend(model.status.messages, "Some optional marine or observation data is unavailable.");
    }

    model.diagnostics.timingsMs.total = getTickCount() - started;
    model.cache.entries = cacheEntries;
    model.cache.summary = cacheSummary(cacheEntries);
    return model;
  }

  public struct function emptyContract() {
    return {
      "ok" = false,
      "requestId" = "",
      "generatedAtUtc" = "",
      "target" = {
        "sourceType" = "",
        "displayName" = "",
        "zip" = "",
        "lat" = javacast("null", ""),
        "lon" = javacast("null", ""),
        "timezone" = "",
        "warnings" = []
      },
      "status" = {
        "ready" = false,
        "degraded" = false,
        "messages" = []
      },
      "current" = {
        "available" = false,
        "condition" = "",
        "tempF" = javacast("null", ""),
        "feelsLikeF" = javacast("null", ""),
        "windMph" = javacast("null", ""),
        "gustMph" = javacast("null", ""),
        "windDirectionDeg" = javacast("null", ""),
        "windDirectionLabel" = "",
        "pressureInHg" = javacast("null", ""),
        "visibilityMi" = javacast("null", ""),
        "humidityPct" = javacast("null", ""),
        "dewpointF" = javacast("null", ""),
        "observedAtUtc" = "",
        "stationId" = "",
        "stationName" = ""
      },
      "marine" = {
        "available" = false,
        "riskLevel" = "Unknown",
        "riskScore" = javacast("null", ""),
        "recommendation" = "",
        "seasFt" = javacast("null", ""),
        "waveHeightFt" = javacast("null", ""),
        "wavePeriodSec" = javacast("null", ""),
        "waveDirectionDeg" = javacast("null", ""),
        "tideLevelFt" = javacast("null", ""),
        "tideTrend" = "",
        "nextHigh" = javacast("null", ""),
        "nextLow" = javacast("null", ""),
        "tideStation" = "",
        "waterLevelStation" = "",
        "warnings" = []
      },
      "forecast12h" = [],
      "alerts" = [],
      "zoneForecast" = {
        "available" = false,
        "zoneId" = "",
        "zoneName" = "",
        "office" = "",
        "synopsis" = "",
        "periods" = [],
        "sourceUrl" = "",
        "reason" = ""
      },
      "map" = {
        "center" = {
          "lat" = javacast("null", ""),
          "lon" = javacast("null", "")
        },
        "layers" = []
      },
      "cache" = {
        "entries" = [],
        "summary" = ""
      },
      "sources" = [],
      "diagnostics" = {
        "timingsMs" = {},
        "warnings" = []
      }
    };
  }

  private void function applyTarget(required struct model, required struct target) {
    arguments.model.target.sourceType = structKeyExists(arguments.target, "sourceType") ? arguments.target.sourceType : "";
    arguments.model.target.displayName = structKeyExists(arguments.target, "displayName") ? arguments.target.displayName : "";
    arguments.model.target.zip = structKeyExists(arguments.target, "zip") ? arguments.target.zip : "";
    arguments.model.target.lat = structKeyExists(arguments.target, "lat") ? arguments.target.lat : javacast("null", "");
    arguments.model.target.lon = structKeyExists(arguments.target, "lon") ? arguments.target.lon : javacast("null", "");
    arguments.model.target.timezone = structKeyExists(arguments.target, "timezone") ? arguments.target.timezone : "";
    arguments.model.target.warnings = structKeyExists(arguments.target, "warnings") ? duplicate(arguments.target.warnings) : [];
  }

  private struct function cachedFetch(required string key, required numeric ttlSeconds, required any producer) {
    var started = getTickCount();
    var cached = variables.cache.get(arguments.key);
    if (cached.hit) {
      return {
        "value" = cached.value,
        "cache" = {
          "key" = arguments.key,
          "status" = "hit",
          "ageSeconds" = cached.ageSeconds,
          "createdAtUtc" = cached.createdAtUtc,
          "expiresAtUtc" = cached.expiresAtUtc,
          "durationMs" = getTickCount() - started
        }
      };
    }

    var value = {};
    try {
      value = arguments.producer();
    } catch (any err) {
      value = {
        "ok" = false,
        "statusCode" = 0,
        "data" = {},
        "error" = err.message
      };
    }
    if (cached.found && structKeyExists(value, "ok") && !value.ok) {
      return {
        "value" = cached.value,
        "cache" = {
          "key" = arguments.key,
          "status" = "stale",
          "ageSeconds" = cached.ageSeconds,
          "createdAtUtc" = cached.createdAtUtc,
          "expiresAtUtc" = cached.expiresAtUtc,
          "durationMs" = getTickCount() - started
        }
      };
    }
    variables.cache.put(arguments.key, value, (structKeyExists(value, "ok") && value.ok) ? arguments.ttlSeconds : 45);
    return {
      "value" = value,
      "cache" = {
        "key" = arguments.key,
        "status" = cached.found ? "stale-refresh" : "miss",
        "ageSeconds" = 0,
        "createdAtUtc" = isoUtc(now()),
        "expiresAtUtc" = isoUtc(dateAdd("s", (structKeyExists(value, "ok") && value.ok) ? arguments.ttlSeconds : 45, now())),
        "durationMs" = getTickCount() - started
      }
    };
  }

  private array function buildSources(required struct point, required string stationId, required struct marine, required struct zoneForecast) {
    var sources = [
      { "provider" = "NOAA/NWS", "type" = "point metadata, forecast, alerts", "id" = point.office ?: "" }
    ];
    if (len(arguments.stationId)) {
      arrayAppend(sources, { "provider" = "NOAA/NWS", "type" = "current observation", "id" = arguments.stationId });
    }
    if (len(arguments.marine.tideStation ?: "")) {
      arrayAppend(sources, { "provider" = "NOAA CO-OPS", "type" = "tide predictions", "id" = arguments.marine.tideStation });
    }
    if (len(arguments.marine.waterLevelStation ?: "")) {
      arrayAppend(sources, { "provider" = "NOAA CO-OPS", "type" = "water level", "id" = arguments.marine.waterLevelStation });
    }
    if (len(arguments.zoneForecast.zoneId ?: "")) {
      arrayAppend(sources, { "provider" = "NOAA/NWS", "type" = "marine zone forecast", "id" = arguments.zoneForecast.zoneId });
    }
    return sources;
  }

  private string function cacheSummary(required array entries) {
    var hits = 0;
    var misses = 0;
    for (var entry in arguments.entries) {
      if ((entry.status ?: "") EQ "hit") {
        hits++;
      } else {
        misses++;
      }
    }
    return hits & " cache hit" & (hits EQ 1 ? "" : "s") & ", " & misses & " fresh request" & (misses EQ 1 ? "" : "s") & ".";
  }

  private void function appendArray(required array target, required array values) {
    for (var item in arguments.values) {
      arrayAppend(arguments.target, item);
    }
  }

  private string function isoUtc(required date value) {
    return dateTimeFormat(dateConvert("local2Utc", arguments.value), "yyyy-mm-dd'T'HH:nn:ss'Z'");
  }
}

