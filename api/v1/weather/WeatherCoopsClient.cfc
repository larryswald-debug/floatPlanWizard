component output="false" {

  public any function init(string userAgent = "FloatPlanWizard Weather Rewrite Phase 1 (https://floatplanwizard.com)") {
    variables.userAgent = arguments.userAgent;
    variables.dataUrl = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter";
    variables.mdapiUrl = "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi";
    return this;
  }

  public struct function getTideBundle(required numeric lat, required numeric lon, any cache = "", string timezone = "") {
    var out = {
      "available" = false,
      "seasFt" = javacast("null", ""),
      "waveHeightFt" = javacast("null", ""),
      "wavePeriodSec" = javacast("null", ""),
      "waveDirectionDeg" = javacast("null", ""),
      "tideLevelFt" = javacast("null", ""),
      "tideTrend" = "",
      "nextHigh" = javacast("null", ""),
      "nextLow" = javacast("null", ""),
      "tidePredictions" = [],
      "tideStation" = "",
      "waterLevelStation" = "",
      "warnings" = [],
      "sources" = [],
      "_cacheEntries" = []
    };

    var predictionStartDate = predictionBeginDate(arguments.timezone);
    var tideStation = nearestStation(arguments.lat, arguments.lon, "tidepredictions", arguments.cache);
    if (structKeyExists(tideStation, "cache")) {
      arrayAppend(out._cacheEntries, tideStation.cache);
    }
    if (!tideStation.available) {
      arrayAppend(out.warnings, tideStation.reason);
      return out;
    }

    out.tideStation = tideStation.name & " (" & tideStation.id & ")";
    arrayAppend(out.sources, { "provider" = "NOAA CO-OPS", "type" = "tide station", "id" = tideStation.id });

    var predictionFetch = cachedProviderFetch(arguments.cache, "coops:predictions:v2:" & tideStation.id & ":" & predictionStartDate, 900, 45, function() {
      return fetchPredictions(tideStation.id, predictionStartDate);
    });
    arrayAppend(out._cacheEntries, predictionFetch.cache);
    if (predictionFetch.value.ok) {
      var tide = normalizePredictions(predictionFetch.value.data);
      out.available = structKeyExists(tide, "available") && tide.available;
      out.nextHigh = hasNonNullKey(tide, "nextHigh") ? tide["nextHigh"] : javacast("null", "");
      out.nextLow = hasNonNullKey(tide, "nextLow") ? tide["nextLow"] : javacast("null", "");
      out.tideTrend = structKeyExists(tide, "tideTrend") ? tide.tideTrend : "";
      out.tidePredictions = structKeyExists(tide, "tidePredictions") && isArray(tide.tidePredictions) ? tide.tidePredictions : [];
      if (hasNonNullKey(tide, "tideLevelFt")) {
        out.tideLevelFt = tide["tideLevelFt"];
      }
    } else {
      arrayAppend(out.warnings, predictionFetch.value.error);
    }

    var waterStation = nearestStation(arguments.lat, arguments.lon, "waterlevels", arguments.cache);
    if (structKeyExists(waterStation, "cache")) {
      arrayAppend(out._cacheEntries, waterStation.cache);
    }
    if (waterStation.available) {
      out.waterLevelStation = waterStation.name & " (" & waterStation.id & ")";
      var waterFetch = cachedProviderFetch(arguments.cache, "coops:waterlevel:" & waterStation.id, 300, 45, function() {
        return fetchWaterLevel(waterStation.id);
      });
      arrayAppend(out._cacheEntries, waterFetch.cache);
      if (waterFetch.value.ok) {
        var level = normalizeWaterLevel(waterFetch.value.data);
        if (hasNonNullKey(level, "tideLevelFt")) {
          out.tideLevelFt = level["tideLevelFt"];
          out.available = true;
        }
      } else {
        arrayAppend(out.warnings, waterFetch.value.error);
      }
    }

    return out;
  }

  public struct function nearestStation(required numeric lat, required numeric lon, string stationType = "tidepredictions", any cache = "") {
    var out = { "available" = false, "id" = "", "name" = "", "lat" = javacast("null", ""), "lon" = javacast("null", ""), "distanceMiles" = javacast("null", ""), "reason" = "" };
    var listResult = {};
    var cacheKey = "coops:stations:" & arguments.stationType;
    var stationTypeValue = arguments.stationType;

    if (isObject(arguments.cache)) {
      listResult = cachedProviderFetch(arguments.cache, cacheKey, 86400, 45, function() {
        return fetchStations(stationTypeValue);
      });
      out.cache = listResult.cache;
    } else {
      listResult = { "value" = fetchStations(arguments.stationType) };
    }

    var stations = listResult.value.ok ? (listResult.value.data.stations ?: []) : [];
    if (!isArray(stations) || arrayLen(stations) EQ 0) {
      out.reason = len(listResult.value.error ?: "") ? listResult.value.error : "No CO-OPS stations returned for " & arguments.stationType & ".";
      return out;
    }

    var best = {};
    var bestDistance = 999999;
    for (var station in stations) {
      if (!isNumeric(station.lat ?: "") || !isNumeric(station.lng ?: "")) {
        continue;
      }
      var miles = haversineMiles(arguments.lat, arguments.lon, val(station.lat), val(station.lng));
      if (miles LT bestDistance) {
        bestDistance = miles;
        best = station;
      }
    }

    if (!structCount(best)) {
      out.reason = "No CO-OPS station had usable coordinates.";
      return out;
    }

    out.available = true;
    out.id = best.id ?: "";
    out.name = best.name ?: out.id;
    out.lat = val(best.lat);
    out.lon = val(best.lng);
    out.distanceMiles = round(bestDistance * 10) / 10;
    return out;
  }

  public struct function fetchStations(required string stationType) {
    return fetchJson(variables.mdapiUrl & "/stations.json?type=" & urlEncodedFormat(arguments.stationType), 3);
  }

  public struct function fetchPredictions(required string stationId, string beginDate = "") {
    var requestBeginDate = trim(arguments.beginDate);
    if (!reFind("^[0-9]{8}$", requestBeginDate)) {
      requestBeginDate = predictionBeginDate();
    }
    var url = variables.dataUrl
      & "?product=predictions&application=FPW&begin_date=" & requestBeginDate
      & "&range=72&datum=MLLW&station=" & urlEncodedFormat(arguments.stationId)
      & "&time_zone=gmt&units=english&interval=hilo&format=json";
    return fetchJson(url, 3);
  }

  public struct function fetchWaterLevel(required string stationId) {
    var url = variables.dataUrl
      & "?product=water_level&application=FPW&date=latest&datum=MLLW&station=" & urlEncodedFormat(arguments.stationId)
      & "&time_zone=gmt&units=english&format=json";
    return fetchJson(url, 2);
  }

  public struct function fetchJson(required string url, numeric timeoutSeconds = 4) {
    var result = { "ok" = false, "statusCode" = 0, "url" = arguments.url, "data" = {}, "error" = "" };
    try {
      cfhttp(method="GET", url=arguments.url, result="local.http", timeout=arguments.timeoutSeconds) {
        cfhttpparam(type="header", name="User-Agent", value=variables.userAgent);
        cfhttpparam(type="header", name="Accept", value="application/json");
      }
      result.statusCode = val(local.http.statusCode);
      if (result.statusCode GTE 200 && result.statusCode LT 300 && len(trim(local.http.fileContent))) {
        result.data = deserializeJSON(local.http.fileContent);
        result.ok = true;
      } else {
        result.error = "CO-OPS request failed with HTTP " & local.http.statusCode;
      }
    } catch (any err) {
      result.error = err.message;
    }
    return result;
  }

  private struct function cachedProviderFetch(required any cache, required string key, required numeric ttlSeconds, required numeric failureTtlSeconds, required any producer) {
    var started = getTickCount();
    if (!isObject(arguments.cache)) {
      return {
        "value" = arguments.producer(),
        "cache" = {
          "key" = arguments.key,
          "status" = "uncached",
          "ageSeconds" = javacast("null", ""),
          "createdAtUtc" = "",
          "expiresAtUtc" = "",
          "durationMs" = getTickCount() - started
        }
      };
    }

    var cached = arguments.cache.get(arguments.key);
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
      value = { "ok" = false, "statusCode" = 0, "url" = "", "data" = {}, "error" = err.message };
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

    var ttl = (structKeyExists(value, "ok") && value.ok) ? arguments.ttlSeconds : arguments.failureTtlSeconds;
    arguments.cache.put(arguments.key, value, ttl);
    return {
      "value" = value,
      "cache" = {
        "key" = arguments.key,
        "status" = cached.found ? "stale-refresh" : "miss",
        "ageSeconds" = 0,
        "createdAtUtc" = isoUtc(now()),
        "expiresAtUtc" = isoUtc(dateAdd("s", ttl, now())),
        "durationMs" = getTickCount() - started
      }
    };
  }

  public struct function normalizePredictions(struct payload = {}) {
    var predictions = arguments.payload.predictions ?: [];
    var out = { "available" = false, "nextHigh" = javacast("null", ""), "nextLow" = javacast("null", ""), "tideTrend" = "", "tideLevelFt" = javacast("null", ""), "tidePredictions" = [] };
    var nowUtcKey = dateTimeFormat(dateConvert("local2Utc", now()), "yyyy-mm-dd HH:nn");
    if (!isArray(predictions) || arrayLen(predictions) EQ 0) {
      return out;
    }
    for (var row in predictions) {
      var timeInfo = normalizeCoopsPredictionUtc(toString(row.t ?: ""));
      var item = {
        "timeUtc" = timeInfo.iso,
        "heightFt" = isNumeric(row.v ?: "") ? val(row.v) : javacast("null", ""),
        "type" = ucase(row.type ?: "")
      };
      if (len(item.timeUtc) && hasNonNullKey(item, "heightFt") && len(item.type)) {
        arrayAppend(out.tidePredictions, item);
      }
      if (timeInfo.valid && compare(timeInfo.sortKey, nowUtcKey) GTE 0) {
        if (item.type EQ "H" && !hasNonNullKey(out, "nextHigh")) {
          out.nextHigh = item;
        }
        if (item.type EQ "L" && !hasNonNullKey(out, "nextLow")) {
          out.nextLow = item;
        }
      }
    }
    out.available = arrayLen(out.tidePredictions) GT 0 || hasNonNullKey(out, "nextHigh") || hasNonNullKey(out, "nextLow");
    out.tideTrend = (hasNonNullKey(out, "nextHigh") && hasNonNullKey(out, "nextLow")) ? "Mixed" : "";
    return out;
  }

  private struct function normalizeCoopsPredictionUtc(required string value) {
    var raw = trim(arguments.value);
    var out = { "valid" = false, "sortKey" = "", "iso" = raw };

    if (!len(raw)) {
      return out;
    }

    raw = replace(raw, "T", " ", "one");
    raw = replace(raw, "Z", "", "one");
    if (reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}", raw) EQ 1) {
      out.valid = true;
      out.sortKey = left(raw, 16);
      out.iso = replace(out.sortKey, " ", "T", "one") & ":00Z";
    }
    return out;
  }

  public struct function normalizeWaterLevel(struct payload = {}) {
    var rows = arguments.payload.data ?: [];
    var out = { "tideLevelFt" = javacast("null", "") };
    if (isArray(rows) && arrayLen(rows) GT 0 && isNumeric(rows[1].v ?: "")) {
      out.tideLevelFt = val(rows[1].v);
    }
    return out;
  }

  private string function predictionBeginDate(string timezone = "") {
    var tz = trim(arguments.timezone);
    if (len(tz)) {
      try {
        return dateTimeFormat(now(), "yyyymmdd", tz);
      } catch (any tzErr) {
      }
    }
    return dateFormat(now(), "yyyymmdd");
  }

  private boolean function hasNonNullKey(required struct source, required string key) {
    return structKeyExists(arguments.source, arguments.key) && !isNull(arguments.source[arguments.key]);
  }

  private numeric function haversineMiles(required numeric lat1, required numeric lon1, required numeric lat2, required numeric lon2) {
    var radius = 3958.8;
    var dLat = radians(arguments.lat2 - arguments.lat1);
    var dLon = radians(arguments.lon2 - arguments.lon1);
    var a = sin(dLat / 2) * sin(dLat / 2) + cos(radians(arguments.lat1)) * cos(radians(arguments.lat2)) * sin(dLon / 2) * sin(dLon / 2);
    var c = 2 * atn2(sqr(a), sqr(1 - a));
    return radius * c;
  }

  private numeric function radians(required numeric deg) {
    return arguments.deg * pi() / 180;
  }

  private numeric function atn2(required numeric y, required numeric x) {
    if (arguments.x GT 0) {
      return atn(arguments.y / arguments.x);
    }
    if (arguments.x LT 0 && arguments.y GTE 0) {
      return atn(arguments.y / arguments.x) + pi();
    }
    if (arguments.x LT 0 && arguments.y LT 0) {
      return atn(arguments.y / arguments.x) - pi();
    }
    if (arguments.x EQ 0 && arguments.y GT 0) {
      return pi() / 2;
    }
    if (arguments.x EQ 0 && arguments.y LT 0) {
      return -pi() / 2;
    }
    return 0;
  }

  private string function isoUtc(required date value) {
    return dateTimeFormat(dateConvert("local2Utc", arguments.value), "yyyy-mm-dd'T'HH:nn:ss'Z'");
  }
}






