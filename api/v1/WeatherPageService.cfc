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
    var bypassCache = (
      structKeyExists(arguments.request, "bypassCache")
      && (
        (isBoolean(arguments.request.bypassCache) && arguments.request.bypassCache)
        || (isNumeric(arguments.request.bypassCache) && val(arguments.request.bypassCache) EQ 1)
        || compareNoCase(toString(arguments.request.bypassCache), "true") EQ 0
      )
    );
    var target = variables.resolver.resolve(arguments.userId, arguments.request);
    applyTarget(model, target);

    if (!target.available) {
      model.ok = false;
      model.status.ready = false;
      model.status.degraded = true;
      model.status.reason = target.reason ?: "NO_TARGET";
      arrayAppend(model.status.messages, targetStatusMessage(target));
      arrayAppend(model.diagnostics.warnings, target.warnings, true);
      model.diagnostics.timingsMs.total = getTickCount() - started;
      model.cache.entries = cacheEntries;
      model.cache.summary = "No provider requests were made because no target was available.";
      return model;
    }

    var pointFetch = cachedFetch("nws:point:" & target.lat & "," & target.lon, 86400, function() {
      return variables.nws.getPoint(target.lat, target.lon);
    }, bypassCache);
    arrayAppend(cacheEntries, pointFetch.cache);

    if (!pointFetch.value.ok) {
      model.ok = false;
      model.status.degraded = true;
      model.status.reason = "NWS_POINT_UNAVAILABLE";
      arrayAppend(model.status.messages, "Weather data is temporarily unavailable for this location.");
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

    var gustGrid = {};
    if (structKeyExists(point, "forecastGridDataUrl") && len(point.forecastGridDataUrl)) {
      var gridFetch = cachedFetch("nws:grid:" & point.forecastGridDataUrl, 900, function() {
        return variables.nws.getGridData(point.forecastGridDataUrl);
      }, bypassCache);
      arrayAppend(cacheEntries, gridFetch.cache);
      if (gridFetch.value.ok) {
        gustGrid = normalizeForecastGridGusts(gridFetch.value.data);
      } else {
        arrayAppend(model.diagnostics.warnings, gridFetch.value.error);
      }
    }

    var hourlyFetch = {};
    if (len(point.forecastHourlyUrl)) {
      hourlyFetch = cachedFetch("nws:hourly:" & point.forecastHourlyUrl, 900, function() {
        return variables.nws.getHourlyForecast(point.forecastHourlyUrl);
      }, bypassCache);
      arrayAppend(cacheEntries, hourlyFetch.cache);
      if (hourlyFetch.value.ok) {
        model.forecast12h = variables.nws.normalizeForecast12h(hourlyFetch.value.data, variables.risk);
        applyForecastGridGusts(model.forecast12h, gustGrid);
      } else {
        arrayAppend(model.diagnostics.warnings, hourlyFetch.value.error);
      }
    }

    var stationId = "";
    var stationIds = [];
    if (len(point.observationStationsUrl)) {
      var stationsFetch = cachedFetch("nws:stations:" & point.observationStationsUrl, 21600, function() {
        return variables.nws.getObservationStations(point.observationStationsUrl);
      }, bypassCache);
      arrayAppend(cacheEntries, stationsFetch.cache);
      if (stationsFetch.value.ok) {
        stationIds = variables.nws.stationIds(stationsFetch.value.data, 6);
      } else {
        arrayAppend(model.diagnostics.warnings, stationsFetch.value.error);
      }
    }

    var bestCurrent = {};
    var bestCurrentRank = -1;
    for (var candidateStationId in stationIds) {
      if (!len(candidateStationId)) {
        continue;
      }
      var obsFetch = cachedFetch("nws:observation:" & candidateStationId, 300, function() {
        return variables.nws.getLatestObservation(candidateStationId);
      }, bypassCache);
      arrayAppend(cacheEntries, obsFetch.cache);
      if (obsFetch.value.ok) {
        var candidateCurrent = variables.nws.normalizeCurrentObservation(obsFetch.value.data, candidateStationId);
        var candidateRank = currentObservationRank(candidateCurrent);
        if (candidateRank GT bestCurrentRank) {
          bestCurrent = candidateCurrent;
          bestCurrentRank = candidateRank;
          stationId = candidateStationId;
        }
        if (isCompleteCurrentObservation(candidateCurrent) AND currentObservationHasGust(candidateCurrent)) {
          break;
        }
      } else {
        arrayAppend(model.diagnostics.warnings, obsFetch.value.error);
      }
    }
    if (structCount(bestCurrent)) {
      model.current = bestCurrent;
    } else if (arrayLen(stationIds)) {
      stationId = stationIds[1];
      model.current.stationId = stationId;
      model.current.stationName = stationId;
    }
    applyForecastGustFallback(model);

    var alertsFetch = cachedFetch("nws:alerts:" & target.lat & "," & target.lon, 180, function() {
      return variables.nws.getActiveAlerts(target.lat, target.lon);
    }, bypassCache);
    arrayAppend(cacheEntries, alertsFetch.cache);
    if (alertsFetch.value.ok) {
      model.alerts = variables.nws.normalizeAlerts(alertsFetch.value.data);
    } else {
      arrayAppend(model.diagnostics.warnings, alertsFetch.value.error);
    }

    var marineStart = getTickCount();
    try {
      model.marine = variables.coops.getTideBundle(target.lat, target.lon, bypassCache ? "" : variables.cache);
      if (structKeyExists(model.marine, "_cacheEntries") && isArray(model.marine._cacheEntries)) {
        arrayAppend(cacheEntries, model.marine._cacheEntries, true);
        structDelete(model.marine, "_cacheEntries", false);
      }
    } catch (any marineErr) {
      model.marine.available = false;
      arrayAppend(model.marine.warnings, "Tide data is temporarily unavailable for this location.");
      arrayAppend(model.diagnostics.warnings, marineErr.message);
    }
    model.diagnostics.timingsMs.coopsMs = getTickCount() - marineStart;
    normalizeMarineWarnings(model);

    var zoneFetch = cachedFetch("nws:marine-zones:" & target.lat & "," & target.lon, 21600, function() {
      return variables.nws.getMarineZones(target.lat, target.lon);
    }, bypassCache);
    arrayAppend(cacheEntries, zoneFetch.cache);
    var zoneMeta = {};
    if (zoneFetch.value.ok) {
      zoneMeta = variables.nws.normalizeMarineZone(zoneFetch.value.data);
      if (!zoneMeta.available && len(point.office ?: "")) {
        var nearestZoneFetch = cachedFetch("nws:nearest-marine-zone:" & point.office & ":" & target.lat & "," & target.lon, 21600, function() {
          return variables.nws.getNearestMarineZone(target.lat, target.lon, point.office);
        }, bypassCache);
        arrayAppend(cacheEntries, nearestZoneFetch.cache);
        if (nearestZoneFetch.value.ok) {
          zoneMeta = variables.nws.normalizeMarineZone(nearestZoneFetch.value.data);
        } else {
          arrayAppend(model.diagnostics.warnings, nearestZoneFetch.value.error);
        }
      }

      if (zoneMeta.available && len(zoneMeta.zoneId) && len(point.office ?: "")) {
        var cwfFetch = cachedFetch("nws:cwf:" & point.office, 1800, function() {
          return variables.nws.getCwfProduct(point.office);
        }, bypassCache);
        arrayAppend(cacheEntries, cwfFetch.cache);
        if (cwfFetch.value.ok) {
          model.zoneForecast = variables.nws.normalizeCwfZoneForecast(zoneMeta, cwfFetch.value.data);
          applyMarineZoneConditions(model);
        } else {
          model.zoneForecast = variables.nws.normalizeCwfZoneForecast(zoneMeta, {});
          model.zoneForecast.reason = cwfFetch.value.error;
          arrayAppend(model.diagnostics.warnings, cwfFetch.value.error);
        }
      } else if (zoneMeta.available && len(zoneMeta.zoneId)) {
        model.zoneForecast = variables.nws.normalizeZoneForecast(zoneMeta, {});
        model.zoneForecast.reason = "No NWS office was available for Coastal Waters Forecast lookup.";
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
      model.status.reason = len(model.status.reason) ? model.status.reason : "PARTIAL_DATA";
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
        "source" = "",
        "sourceLabel" = "",
        "isApproximate" = false,
        "reason" = "",
        "warnings" = []
      },
      "status" = {
        "ready" = false,
        "degraded" = false,
        "reason" = "",
        "messages" = []
      },
      "current" = {
        "available" = false,
        "condition" = "",
        "tempF" = javacast("null", ""),
        "feelsLikeF" = javacast("null", ""),
        "windMph" = javacast("null", ""),
        "gustMph" = javacast("null", ""),
        "gustSource" = "",
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
      "waveDirectionLabel" = "",
      "tideLevelFt" = javacast("null", ""),
        "tideTrend" = "",
        "nextHigh" = javacast("null", ""),
        "nextLow" = javacast("null", ""),
        "tidePredictions" = [],
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
      "seasFt" = javacast("null", ""),
      "waveHeightFt" = javacast("null", ""),
      "wavePeriodSec" = javacast("null", ""),
      "waveDirectionLabel" = "",
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
    arguments.model.target.source = structKeyExists(arguments.target, "source") ? arguments.target.source : "";
    arguments.model.target.sourceLabel = structKeyExists(arguments.target, "sourceLabel") ? arguments.target.sourceLabel : "";
    arguments.model.target.isApproximate = structKeyExists(arguments.target, "isApproximate") ? arguments.target.isApproximate : false;
    arguments.model.target.reason = structKeyExists(arguments.target, "reason") ? arguments.target.reason : "";
    arguments.model.target.warnings = structKeyExists(arguments.target, "warnings") ? duplicate(arguments.target.warnings) : [];
  }

  private string function targetStatusMessage(required struct target) {
    var reason = arguments.target.reason ?: "";
    if (reason EQ "HOMEPORT_NO_COORDINATES" || reason EQ "HOMEPORT_INVALID_COORDINATES" || reason EQ "NO_HOMEPORT") {
      return "Weather needs a saved home-port location with coordinates.";
    }
    if (reason EQ "ZIP_COORDINATES_UNAVAILABLE") {
      return "ZIP-only weather lookup is not enabled yet. Save a home port with coordinates to view local marine weather.";
    }
    if (reason EQ "ZIP_NOT_FOUND") {
      return "No approved ZIP-area coordinate was found for this ZIP code.";
    }
    if (reason EQ "INVALID_COORDINATES") {
      return "The coordinates entered were not valid.";
    }
    if (reason EQ "INVALID_ZIP") {
      return "Enter a valid 5-digit ZIP code.";
    }
    return "Weather needs a saved home-port location with coordinates.";
  }

  private void function normalizeMarineWarnings(required struct model) {
    if (!structKeyExists(arguments.model, "marine")) {
      return;
    }
    if (!structKeyExists(arguments.model.marine, "warnings") || !isArray(arguments.model.marine.warnings)) {
      arguments.model.marine.warnings = [];
    }
    if (arrayLen(arguments.model.marine.warnings)) {
      arrayAppend(arguments.model.diagnostics.warnings, arguments.model.marine.warnings, true);
    }
    if (!arguments.model.marine.available) {
      arguments.model.marine.warnings = [ "Tide data is temporarily unavailable for this location." ];
    } else if (arrayLen(arguments.model.marine.warnings)) {
      arguments.model.marine.warnings = [ "Some optional tide or water-level details are temporarily unavailable." ];
    }
  }

  private void function applyMarineZoneConditions(required struct model) {
    if (!structKeyExists(arguments.model, "zoneForecast") || !structKeyExists(arguments.model, "marine")) {
      return;
    }

    if (hasNonNullKey(arguments.model.zoneForecast, "seasFt")) {
      arguments.model.marine.seasFt = arguments.model.zoneForecast["seasFt"];
    }
    if (hasNonNullKey(arguments.model.zoneForecast, "waveHeightFt")) {
      arguments.model.marine.waveHeightFt = arguments.model.zoneForecast["waveHeightFt"];
    }
    if (hasNonNullKey(arguments.model.zoneForecast, "wavePeriodSec")) {
      arguments.model.marine.wavePeriodSec = arguments.model.zoneForecast["wavePeriodSec"];
    }
    if (len(arguments.model.zoneForecast.waveDirectionLabel ?: "")) {
      arguments.model.marine.waveDirectionLabel = arguments.model.zoneForecast.waveDirectionLabel;
    }

    var forecastSeas = javacast("null", "");
    if (hasNonNullKey(arguments.model.marine, "seasFt")) {
      forecastSeas = arguments.model.marine["seasFt"];
    } else if (hasNonNullKey(arguments.model.marine, "waveHeightFt")) {
      forecastSeas = arguments.model.marine["waveHeightFt"];
    }

    if (isNull(forecastSeas) || !isArray(arguments.model.forecast12h)) {
      return;
    }

    for (var i = 1; i <= arrayLen(arguments.model.forecast12h); i++) {
      if (!hasNonNullKey(arguments.model.forecast12h[i], "seasFt")) {
        arguments.model.forecast12h[i].seasFt = forecastSeas;
      }
    }
  }

  private struct function normalizeForecastGridGusts(struct gridPayload = {}) {
    var out = { "values" = [], "unit" = "", "source" = "NWS_GRID" };
    var props = arguments.gridPayload.properties ?: {};
    var gust = props.windGust ?: {};

    if (structKeyExists(gust, "values") && isArray(gust.values)) {
      out.values = gust.values;
    }
    if (structKeyExists(gust, "uom") && len(trim(toString(gust.uom)))) {
      out.unit = trim(toString(gust.uom));
    } else if (structKeyExists(gust, "unitCode") && len(trim(toString(gust.unitCode)))) {
      out.unit = trim(toString(gust.unitCode));
    }
    return out;
  }

  private void function applyForecastGridGusts(required array forecastRows, required struct gustGrid) {
    if (!structKeyExists(arguments.gustGrid, "values") || !isArray(arguments.gustGrid.values) || arrayLen(arguments.gustGrid.values) EQ 0) {
      return;
    }

    var unitCode = structKeyExists(arguments.gustGrid, "unit") ? arguments.gustGrid.unit : "";
    for (var i = 1; i <= arrayLen(arguments.forecastRows); i++) {
      if (!isStruct(arguments.forecastRows[i])) {
        continue;
      }
      var row = arguments.forecastRows[i];
      if (forecastRowHasGust(row)) {
        arguments.forecastRows[i] = row;
        continue;
      }

      var startIso = row.startTime ?: row.timeLabel ?: "";
      var endIso = row.endTime ?: "";
      var gust = forecastGridGustForPeriod(startIso, endIso, arguments.gustGrid.values, unitCode);
      if (gust.hasValue) {
        row.gustMph = round(gust.gustMph * 10) / 10;
        row.gustSource = gust.source;
        arguments.forecastRows[i] = row;
      }
    }
  }

  private void function applyForecastGustFallback(required struct model) {
    if (!structKeyExists(arguments.model, "current") || !isStruct(arguments.model.current)) {
      return;
    }
    if (currentObservationHasGust(arguments.model.current)) {
      if (!len(arguments.model.current.gustSource ?: "")) {
        arguments.model.current.gustSource = "NWS_OBSERVATION";
      }
      return;
    }
    if (!structKeyExists(arguments.model.current, "available") || !arguments.model.current.available) {
      return;
    }
    if (!structKeyExists(arguments.model, "forecast12h") || !isArray(arguments.model.forecast12h) || arrayLen(arguments.model.forecast12h) EQ 0) {
      return;
    }

    var row = isStruct(arguments.model.forecast12h[1]) ? arguments.model.forecast12h[1] : {};
    if (!forecastRowHasGust(row)) {
      return;
    }

    arguments.model.current.gustMph = row.gustMph;
    arguments.model.current.gustSource = len(row.gustSource ?: "") ? row.gustSource : "NWS_GRID";
  }

  private boolean function forecastRowHasGust(required struct row) {
    return structKeyExists(arguments.row, "gustMph")
      && !isNull(arguments.row["gustMph"])
      && len(trim(toString(arguments.row["gustMph"])))
      && isNumeric(arguments.row["gustMph"]);
  }

  private struct function forecastGridGustForPeriod(required string periodStartIso, required string periodEndIso, required array values, string unitCode = "") {
    var out = { "hasValue" = false, "gustMph" = 0, "source" = "NWS_GRID" };
    var periodStart = parseNwsIsoDate(arguments.periodStartIso);
    var periodEnd = parseNwsIsoDate(arguments.periodEndIso);
    var maxMph = -1;

    if (!isDate(periodStart) || !isDate(periodEnd) || periodEnd LTE periodStart) {
      return out;
    }

    for (var valueRow in arguments.values) {
      if (!isStruct(valueRow) || !structKeyExists(valueRow, "validTime")) {
        continue;
      }
      if (!structKeyExists(valueRow, "value") || !isNumeric(valueRow.value)) {
        continue;
      }

      var span = parseNwsValidTimeSpan(valueRow.validTime);
      if (!span.success) {
        continue;
      }

      var overlap = getDateRangeOverlapMinutes(periodStart, periodEnd, span.startDate, span.endDate);
      if (overlap LTE 0) {
        continue;
      }

      var mph = convertNwsSpeedToMph(val(valueRow.value), arguments.unitCode);
      if (mph GT maxMph) {
        maxMph = mph;
      }
    }

    if (maxMph GTE 0) {
      out.hasValue = true;
      out.gustMph = maxMph;
    }
    return out;
  }

  private struct function parseNwsValidTimeSpan(required string validTime) {
    var out = { "success" = false, "startDate" = "", "endDate" = "" };
    var value = trim(arguments.validTime);
    if (!len(value)) {
      return out;
    }

    var slash = find("/", value);
    var startIso = slash GT 0 ? left(value, slash - 1) : value;
    var durationIso = slash GT 0 ? mid(value, slash + 1, len(value) - slash) : "PT1H";
    var startDate = parseNwsIsoDate(startIso);
    if (!isDate(startDate)) {
      return out;
    }

    var durationMin = parseIsoDurationMinutes(durationIso);
    if (durationMin LTE 0) {
      durationMin = 60;
    }

    out.success = true;
    out.startDate = startDate;
    out.endDate = dateAdd("n", durationMin, startDate);
    return out;
  }

  private any function parseNwsIsoDate(required string iso) {
    if (!len(trim(arguments.iso))) {
      return "";
    }
    try {
      return parseDateTime(arguments.iso);
    } catch (any err) {
      return "";
    }
  }

  private numeric function parseIsoDurationMinutes(required string durationIso) {
    var value = ucase(trim(arguments.durationIso));
    var total = 0;
    var match = reFind("([0-9]+)D", value, 1, true);
    if (arrayLen(match.len) GTE 2 && match.len[2] GT 0) {
      total += val(mid(value, match.pos[2], match.len[2])) * 1440;
    }
    match = reFind("([0-9]+)H", value, 1, true);
    if (arrayLen(match.len) GTE 2 && match.len[2] GT 0) {
      total += val(mid(value, match.pos[2], match.len[2])) * 60;
    }
    match = reFind("([0-9]+)M", value, 1, true);
    if (arrayLen(match.len) GTE 2 && match.len[2] GT 0) {
      total += val(mid(value, match.pos[2], match.len[2]));
    }
    return total;
  }

  private numeric function getDateRangeOverlapMinutes(required date aStart, required date aEnd, required date bStart, required date bEnd) {
    if (arguments.aEnd LTE arguments.aStart || arguments.bEnd LTE arguments.bStart) {
      return 0;
    }

    var startAt = arguments.aStart GTE arguments.bStart ? arguments.aStart : arguments.bStart;
    var endAt = arguments.aEnd LTE arguments.bEnd ? arguments.aEnd : arguments.bEnd;
    if (endAt LTE startAt) {
      return 0;
    }
    return dateDiff("n", startAt, endAt);
  }

  private numeric function convertNwsSpeedToMph(required numeric speedVal, string unitCode = "") {
    var speed = val(arguments.speedVal);
    var unit = lcase(trim(arguments.unitCode));
    if (!len(unit)) {
      return speed;
    }
    if (find("km_h", unit) || find("km/h", unit) || find("kmh", unit)) {
      return speed * 0.621371;
    }
    if (find("m_s", unit) || find("m/s", unit) || find("meter", unit)) {
      return speed * 2.236936;
    }
    if (find("kt", unit) || find("knot", unit) || find("nautical_mile_per_hour", unit)) {
      return speed * 1.150779;
    }
    return speed;
  }

  private boolean function hasNonNullKey(required struct source, required string key) {
    return structKeyExists(arguments.source, arguments.key) && !isNull(arguments.source[arguments.key]);
  }

  private struct function cachedFetch(required string key, required numeric ttlSeconds, required any producer, boolean bypassCache = false) {
    var started = getTickCount();
    var cached = {
      "hit" = false,
      "found" = false,
      "ageSeconds" = javacast("null", ""),
      "createdAtUtc" = "",
      "expiresAtUtc" = ""
    };
    if (!arguments.bypassCache) {
      cached = variables.cache.get(arguments.key);
    }
    if (!arguments.bypassCache && cached.hit) {
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
    if (!arguments.bypassCache && cached.found && structKeyExists(value, "ok") && !value.ok) {
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
    if (!arguments.bypassCache) {
      variables.cache.put(arguments.key, value, (structKeyExists(value, "ok") && value.ok) ? arguments.ttlSeconds : 45);
    }
    return {
      "value" = value,
      "cache" = {
        "key" = arguments.key,
        "status" = arguments.bypassCache ? "bypass" : (cached.found ? "stale-refresh" : "miss"),
        "ageSeconds" = 0,
        "createdAtUtc" = isoUtc(now()),
        "expiresAtUtc" = arguments.bypassCache ? "" : isoUtc(dateAdd("s", (structKeyExists(value, "ok") && value.ok) ? arguments.ttlSeconds : 45, now())),
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

  private numeric function currentObservationRank(required struct current) {
    return (currentObservationScore(arguments.current) * 2) + (currentObservationHasGust(arguments.current) ? 1 : 0);
  }

  private boolean function currentObservationHasGust(required struct current) {
    return structKeyExists(arguments.current, "gustMph")
      AND !isNull(arguments.current["gustMph"])
      AND len(trim(toString(arguments.current["gustMph"])))
      AND isNumeric(arguments.current["gustMph"]);
  }

  private numeric function currentObservationScore(required struct current) {
    var score = 0;
    if (len(arguments.current.condition ?: "")) {
      score++;
    }
    if (!isNull(arguments.current.tempF ?: javacast("null", ""))) {
      score++;
    }
    if (!isNull(arguments.current.windMph ?: javacast("null", ""))) {
      score++;
    }
    if (!isNull(arguments.current.pressureInHg ?: javacast("null", ""))) {
      score++;
    }
    if (!isNull(arguments.current.visibilityMi ?: javacast("null", ""))) {
      score++;
    }
    if (!isNull(arguments.current.humidityPct ?: javacast("null", ""))) {
      score++;
    }
    if (!isNull(arguments.current.dewpointF ?: javacast("null", ""))) {
      score++;
    }
    if (len(arguments.current.observedAtUtc ?: "")) {
      score++;
    }
    return score;
  }

  private boolean function isCompleteCurrentObservation(required struct current) {
    return currentObservationScore(arguments.current) GTE 8;
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










