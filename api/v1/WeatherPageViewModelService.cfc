component output="false" {

  public any function init() {
    return this;
  }

  public struct function normalize(required struct envelope) {
    var data = dataPayload(arguments.envelope);
    var meta = getStruct(data, ["META", "meta"]);
    var summary = getStruct(data, ["SUMMARY", "summary"]);
    var surface = getStruct(data, ["surface", "SURFACE"]);
    var marine = getStruct(data, ["MARINE", "marine"]);
    var forecast = getStruct(data, ["FORECAST", "forecast"]);
    var zone = getStruct(data, ["ZONE_FORECAST", "zoneForecast", "zone_forecast"]);
    var alertsRaw = pick(data, ["ALERTS", "alerts"], []);
    var model = emptyViewModel();
    var anchor = getStruct(meta, ["anchor", "ANCHOR"]);
    var cacheReport = getStruct(meta, ["cache_report", "CACHE_REPORT", "cacheReport"]);
    var rootMessage = stringValue(pick(arguments.envelope, ["MESSAGE", "message"], pick(data, ["MESSAGE", "message"], "")));

    model.ok = boolValue(pick(arguments.envelope, ["SUCCESS", "success", "ok"], pick(data, ["SUCCESS", "success", "ok"], false)));
    model.requestId = stringValue(pick(meta, ["request_id", "REQUEST_ID", "requestId"], ""));
    model.generatedAtUtc = stringValue(pick(meta, ["generated_at_utc", "GENERATED_AT_UTC", "generatedAtUtc"], ""));

    model.target.mode = stringValue(pick(meta, ["mode", "MODE", "request_mode", "REQUEST_MODE"], ""));
    model.target.displayName = stringValue(firstNonEmpty([
      pick(meta, ["resolved_location", "RESOLVED_LOCATION", "resolvedLocation"], ""),
      pick(anchor, ["label", "LABEL", "name", "NAME"], ""),
      pick(meta, ["zip", "ZIP"], "")
    ]));
    model.target.zip = stringValue(pick(meta, ["zip", "ZIP", "request_zip", "REQUEST_ZIP"], ""));
    model.target.lat = numericValue(pick(anchor, ["lat", "LAT", "latitude", "LATITUDE"], pick(meta, ["lat", "LAT", "latitude", "LATITUDE"], nullValue())));
    model.target.lon = numericValue(pick(anchor, ["lon", "LON", "lng", "LNG", "longitude", "LONGITUDE"], pick(meta, ["lon", "LON", "lng", "LNG", "longitude", "LONGITUDE"], nullValue())));
    model.target.timezone = stringValue(pick(meta, ["timezone", "TIMEZONE"], ""));
    model.target.anchorLabel = stringValue(pick(anchor, ["label", "LABEL", "name", "NAME"], ""));

    model.current.observedAtUtc = stringValue(pick(surface, ["observed_at_utc", "OBSERVED_AT_UTC", "observedAtUtc", "observed_at"], ""));
    model.current.stationId = stringValue(firstNonEmpty([
      pick(surface, ["station_id", "STATION_ID", "stationId", "station"], ""),
      pick(meta, ["metar_station", "METAR_STATION"], "")
    ]));
    model.current.condition = stringValue(firstNonEmpty([
      pick(summary, ["condition", "CONDITION", "shortForecast"], ""),
      pick(surface, ["condition", "CONDITION", "weather"], "")
    ]));
    model.current.tempF = numericValue(firstNonEmpty([
      pick(summary, ["temp_f", "TEMP_F", "tempF", "temperature"], ""),
      pick(surface, ["temperature_f", "TEMPERATURE_F", "temp_f", "tempF"], "")
    ]));
    model.current.feelsLikeF = numericValue(firstNonEmpty([
      pick(summary, ["feels_like_f", "FEELS_LIKE_F", "feelsLikeF"], ""),
      pick(surface, ["feels_like_f", "FEELS_LIKE_F", "feelsLikeF"], "")
    ]));
    model.current.windMph = numericValue(firstNonEmpty([
      pick(summary, ["wind_mph", "WIND_MPH", "windMph"], ""),
      pick(surface, ["wind_mph", "WIND_MPH", "windMph"], "")
    ]));
    model.current.windDirection = stringValue(firstNonEmpty([
      pick(summary, ["wind_direction", "WIND_DIRECTION", "windDirection"], ""),
      pick(surface, ["wind_direction", "WIND_DIRECTION", "windDirection"], "")
    ]));
    model.current.gustMph = numericValue(firstNonEmpty([
      pick(summary, ["gust_mph", "GUST_MPH", "gustMph"], ""),
      pick(surface, ["gust_mph", "GUST_MPH", "gustMph"], "")
    ]));
    model.current.pressureInHg = numericValue(pick(surface, ["pressure_inhg", "PRESSURE_INHG", "pressureInHg"], nullValue()));
    model.current.visibilityMi = numericValue(firstNonEmpty([
      pick(surface, ["visibility_mi", "VISIBILITY_MI", "visibilityMi"], ""),
      pick(marine, ["visibility_mi", "VISIBILITY_MI", "visibilityMi"], "")
    ]));
    model.current.humidityPct = numericValue(pick(surface, ["humidity_pct", "HUMIDITY_PCT", "humidityPct"], nullValue()));
    model.current.dewpointF = numericValue(pick(surface, ["dewpoint_f", "DEWPOINT_F", "dewpointF"], nullValue()));

    normalizeMarine(model, marine);
    model.forecast12h = normalizeForecastPeriods(forecast);
    model.alerts = normalizeAlerts(alertsRaw);
    model.zoneForecast = normalizeZoneForecast(zone);
    model.map.center.lat = pick(model.target, ["lat"], nullValue());
    model.map.center.lon = pick(model.target, ["lon"], nullValue());
    model.map.layers = normalizeMapLayers(pick(data, ["MAP_LAYERS", "mapLayers", "map_layers"], []));
    model.cache = normalizeCache(cacheReport, getStruct(data, ["CACHE", "cache"]));
    model.sources = normalizeSources(meta, surface, marine, zone);
    model.diagnostics.timingsMs = normalizeTimings(marine, zone);

    model.status.summaryReady = structCount(summary) GT 0 OR arrayLen(model.forecast12h) GT 0 OR len(model.current.condition) GT 0;
    model.status.marineReady = structKeyExists(marine, "wave_height_ft")
      OR structKeyExists(marine, "WAVE_HEIGHT_FT")
      OR structKeyExists(marine, "tide")
      OR structKeyExists(marine, "TIDE");
    model.status.zoneReady = boolValue(pick(model.zoneForecast, ["available"], false));
    model.status.degraded = !model.ok OR !model.status.summaryReady OR !model.status.marineReady;

    if (len(rootMessage) AND (!model.ok OR findNoCase("partial", rootMessage) OR findNoCase("unavailable", rootMessage) OR findNoCase("invalid", rootMessage))) {
      arrayAppend(model.status.messages, rootMessage);
      arrayAppend(model.diagnostics.warnings, rootMessage);
    }
    if (!model.status.marineReady) {
      arrayAppend(model.diagnostics.warnings, "Marine detail is missing or deferred.");
    }
    if (!model.status.zoneReady AND len(model.zoneForecast.reason)) {
      arrayAppend(model.diagnostics.warnings, model.zoneForecast.reason);
    }

    return model;
  }

  public struct function emptyViewModel() {
    return {
      "ok" = false,
      "requestId" = "",
      "generatedAtUtc" = "",
      "target" = {
        "mode" = "",
        "displayName" = "",
        "zip" = "",
        "lat" = nullValue(),
        "lon" = nullValue(),
        "timezone" = "",
        "anchorLabel" = ""
      },
      "status" = {
        "summaryReady" = false,
        "marineReady" = false,
        "zoneReady" = false,
        "degraded" = false,
        "messages" = []
      },
      "current" = {
        "observedAtUtc" = "",
        "stationId" = "",
        "condition" = "",
        "tempF" = nullValue(),
        "feelsLikeF" = nullValue(),
        "windMph" = nullValue(),
        "windDirection" = "",
        "gustMph" = nullValue(),
        "pressureInHg" = nullValue(),
        "visibilityMi" = nullValue(),
        "humidityPct" = nullValue(),
        "dewpointF" = nullValue()
      },
      "marine" = {
        "riskLevel" = "",
        "riskScore" = nullValue(),
        "recommendation" = "",
        "seasFt" = nullValue(),
        "wavePeriodSec" = nullValue(),
        "waveDirectionDeg" = nullValue(),
        "tideLevelFt" = nullValue(),
        "tideTrend" = "",
        "nextHigh" = nullValue(),
        "nextLow" = nullValue(),
        "tideStation" = "",
        "waterLevelStation" = ""
      },
      "forecast12h" = [],
      "alerts" = [],
      "zoneForecast" = {
        "available" = false,
        "reason" = "",
        "zoneId" = "",
        "zoneName" = "",
        "office" = "",
        "synopsis" = "",
        "periods" = [],
        "sourceUrl" = ""
      },
      "map" = {
        "center" = {
          "lat" = nullValue(),
          "lon" = nullValue()
        },
        "layers" = []
      },
      "cache" = {
        "forecast" = nullValue(),
        "alerts" = nullValue(),
        "surface" = nullValue(),
        "marine" = nullValue(),
        "tide" = nullValue(),
        "zoneForecast" = nullValue()
      },
      "sources" = [],
      "diagnostics" = {
        "timingsMs" = {},
        "warnings" = []
      }
    };
  }

  public array function getWeatherPageFieldInventory() {
    return [
      inventoryRow("header", "weatherResolvedLocation", "required", "META.resolved_location / META.anchor.label", "target.displayName", "empty label"),
      inventoryRow("header", "weatherZipDisplay", "optional", "META.zip", "target.zip", "hide zip label"),
      inventoryRow("header", "weatherAnchorMeta", "optional", "META.anchor.lat/lon", "target.lat / target.lon / target.anchorLabel", "hide anchor detail"),
      inventoryRow("current", "weatherConditionText", "required", "SUMMARY.condition / surface.condition", "current.condition", "empty condition"),
      inventoryRow("current", "weatherCurrentTemp", "optional", "SUMMARY.temp_f / surface.temperature_f", "current.tempF", "placeholder"),
      inventoryRow("current", "weatherCurrentWind", "optional", "SUMMARY.wind_mph / surface.wind_mph", "current.windMph", "placeholder"),
      inventoryRow("current", "weatherObservedAt", "optional", "surface.observed_at_utc", "current.observedAtUtc", "placeholder"),
      inventoryRow("marine-risk", "weatherRiskValue", "required", "client calculation / MARINE.risk_level", "marine.riskLevel", "Unknown"),
      inventoryRow("marine-risk", "weatherRiskSeas", "optional", "MARINE.wave_height_ft", "marine.seasFt", "placeholder"),
      inventoryRow("waves", "weatherWavePeriod", "optional", "MARINE.wave_period_sec", "marine.wavePeriodSec", "placeholder"),
      inventoryRow("tide", "weatherCurrentTide", "optional", "MARINE.tide.current.height_ft", "marine.tideLevelFt", "placeholder"),
      inventoryRow("tide", "weatherNextHighTideTime", "optional", "MARINE.tide.next_high", "marine.nextHigh", "placeholder"),
      inventoryRow("alerts", "weatherAlertStatus", "required", "ALERTS", "alerts[]", "none active"),
      inventoryRow("next-12-hours", "weatherHourlyRows", "required", "FORECAST.periods", "forecast12h[]", "empty state"),
      inventoryRow("zone-forecast", "weatherZoneForecastContent", "optional", "ZONE_FORECAST", "zoneForecast", "unavailable state"),
      inventoryRow("map", "weatherMapLayerList", "optional", "MAP_LAYERS", "map.layers[]", "no layers"),
      inventoryRow("diagnostics", "weatherSourceCacheStatus", "optional", "CACHE / META.cache_report", "cache", "unknown cache status"),
      inventoryRow("diagnostics", "weatherSourceCacheRows", "deprecated", "dashboard.js reference only", "diagnostics", "do not require")
    ];
  }

  public array function getRequiredFieldPaths() {
    return [
      "ok",
      "target.displayName",
      "status.summaryReady",
      "status.degraded",
      "current.condition",
      "marine.riskLevel",
      "forecast12h",
      "alerts",
      "zoneForecast.available",
      "map.center",
      "cache",
      "diagnostics.warnings"
    ];
  }

  private void function normalizeMarine(required struct model, required struct marine) {
    var tide = getStruct(arguments.marine, ["tide", "TIDE"]);
    var current = getStruct(tide, ["current", "CURRENT"]);
    var nextHigh = getStruct(tide, ["next_high", "NEXT_HIGH", "nextHigh"]);
    var nextLow = getStruct(tide, ["next_low", "NEXT_LOW", "nextLow"]);

    arguments.model.marine.riskLevel = stringValue(firstNonEmpty([
      pick(arguments.marine, ["risk_level", "RISK_LEVEL", "riskLevel"], ""),
      "Unknown"
    ]));
    arguments.model.marine.riskScore = numericValue(pick(arguments.marine, ["risk_score", "RISK_SCORE", "riskScore"], nullValue()));
    arguments.model.marine.recommendation = stringValue(pick(arguments.marine, ["recommendation", "RECOMMENDATION"], ""));
    arguments.model.marine.seasFt = numericValue(pick(arguments.marine, ["wave_height_ft", "WAVE_HEIGHT_FT", "seasFt"], nullValue()));
    arguments.model.marine.wavePeriodSec = numericValue(pick(arguments.marine, ["wave_period_sec", "WAVE_PERIOD_SEC", "wavePeriodSec"], nullValue()));
    arguments.model.marine.waveDirectionDeg = numericValue(pick(arguments.marine, ["wave_direction_deg", "WAVE_DIRECTION_DEG", "waveDirectionDeg"], nullValue()));
    arguments.model.marine.tideLevelFt = numericValue(pick(current, ["height_ft", "HEIGHT_FT", "heightFt"], nullValue()));
    arguments.model.marine.tideTrend = stringValue(pick(current, ["trend", "TREND"], ""));
    arguments.model.marine.nextHigh = normalizeTideEvent(nextHigh);
    arguments.model.marine.nextLow = normalizeTideEvent(nextLow);
    arguments.model.marine.tideStation = stringValue(pick(arguments.marine, ["tide_station", "TIDE_STATION", "tideStation"], ""));
    arguments.model.marine.waterLevelStation = stringValue(pick(arguments.marine, ["water_level_station", "WATER_LEVEL_STATION", "waterLevelStation"], ""));
  }

  private array function normalizeForecastPeriods(required struct forecast) {
    var periods = pick(arguments.forecast, ["periods", "PERIODS"], []);
    var out = [];
    var maxItems = 12;
    var i = 0;

    if (!isArray(periods)) {
      return out;
    }

    for (i = 1; i <= arrayLen(periods) AND i <= maxItems; i++) {
      var row = isStruct(periods[i]) ? periods[i] : {};
      var pop = getStruct(row, ["probabilityOfPrecipitation", "probability_of_precipitation", "POP"]);
      arrayAppend(out, {
        "label" = stringValue(pick(row, ["name", "NAME", "label"], "")),
        "startUtc" = stringValue(pick(row, ["startTime", "start_time", "startUtc"], "")),
        "tempF" = numericValue(pick(row, ["temperature", "temp_f", "tempF"], nullValue())),
        "windMph" = numericValue(pick(row, ["wind_mph", "windMph"], nullValue())),
        "windText" = stringValue(pick(row, ["windSpeed", "wind_speed", "windText"], "")),
        "windDirection" = stringValue(pick(row, ["windDirection", "wind_direction"], "")),
        "gustMph" = numericValue(pick(row, ["gust_mph", "gustMph"], nullValue())),
        "popPct" = numericValue(pick(pop, ["value", "VALUE"], pick(row, ["pop_pct", "popPct"], nullValue()))),
        "shortForecast" = stringValue(pick(row, ["shortForecast", "short_forecast"], "")),
        "marineRisk" = stringValue(pick(row, ["marineRisk", "marine_risk"], ""))
      });
    }

    return out;
  }

  private array function normalizeAlerts(required any alertsRaw) {
    var rows = [];
    var out = [];

    if (isArray(arguments.alertsRaw)) {
      rows = arguments.alertsRaw;
    } else if (isStruct(arguments.alertsRaw)) {
      rows = pick(arguments.alertsRaw, ["features", "FEATURES", "alerts", "ALERTS"], []);
      if (!isArray(rows) AND structCount(arguments.alertsRaw) GT 0) {
        rows = [arguments.alertsRaw];
      }
    }

    if (!isArray(rows)) {
      return out;
    }

    for (var item in rows) {
      var alert = isStruct(item) ? item : {};
      var props = getStruct(alert, ["properties", "PROPERTIES"]);
      if (structCount(props) EQ 0) {
        props = alert;
      }
      arrayAppend(out, {
        "id" = stringValue(pick(alert, ["id", "ID"], pick(props, ["id", "ID"], ""))),
        "event" = stringValue(pick(props, ["event", "EVENT"], "")),
        "headline" = stringValue(pick(props, ["headline", "HEADLINE"], "")),
        "severity" = stringValue(pick(props, ["severity", "SEVERITY"], "")),
        "urgency" = stringValue(pick(props, ["urgency", "URGENCY"], "")),
        "certainty" = stringValue(pick(props, ["certainty", "CERTAINTY"], "")),
        "effectiveUtc" = stringValue(pick(props, ["effective", "EFFECTIVE", "effectiveUtc"], "")),
        "expiresUtc" = stringValue(pick(props, ["expires", "EXPIRES", "expiresUtc"], "")),
        "area" = stringValue(pick(props, ["areaDesc", "area_desc", "area"], "")),
        "description" = stringValue(pick(props, ["description", "DESCRIPTION"], "")),
        "instruction" = stringValue(pick(props, ["instruction", "INSTRUCTION"], "")),
        "sourceUrl" = stringValue(pick(props, ["uri", "URI", "sourceUrl"], ""))
      });
    }

    return out;
  }

  private struct function normalizeZoneForecast(required struct zone) {
    var out = emptyViewModel().zoneForecast;
    out.available = boolValue(pick(arguments.zone, ["available", "AVAILABLE"], false));
    out.reason = stringValue(pick(arguments.zone, ["reason", "REASON"], ""));
    out.zoneId = stringValue(pick(arguments.zone, ["zone_id", "ZONE_ID", "zoneId"], ""));
    out.zoneName = stringValue(pick(arguments.zone, ["zone_name", "ZONE_NAME", "zoneName"], ""));
    out.office = stringValue(pick(arguments.zone, ["office", "OFFICE", "wfo", "WFO"], ""));
    out.synopsis = stringValue(pick(arguments.zone, ["synopsis", "SYNOPSIS"], ""));
    out.periods = normalizeZonePeriods(pick(arguments.zone, ["periods", "PERIODS"], []));
    out.sourceUrl = stringValue(pick(arguments.zone, ["source_url", "SOURCE_URL", "sourceUrl"], ""));
    return out;
  }

  private array function normalizeZonePeriods(required any periods) {
    var out = [];
    if (!isArray(arguments.periods)) {
      return out;
    }
    for (var period in arguments.periods) {
      var row = isStruct(period) ? period : {};
      arrayAppend(out, {
        "name" = stringValue(pick(row, ["name", "NAME"], "")),
        "forecast" = stringValue(pick(row, ["forecast", "FORECAST", "text", "TEXT"], ""))
      });
    }
    return out;
  }

  private array function normalizeMapLayers(required any layers) {
    var out = [];
    if (!isArray(arguments.layers)) {
      return out;
    }
    for (var layer in arguments.layers) {
      var row = isStruct(layer) ? layer : {};
      arrayAppend(out, {
        "key" = stringValue(pick(row, ["key", "KEY", "id", "ID"], "")),
        "label" = stringValue(pick(row, ["label", "LABEL", "name", "NAME"], "")),
        "available" = boolValue(pick(row, ["available", "AVAILABLE"], true))
      });
    }
    return out;
  }

  private struct function normalizeCache(required struct cacheReport, required struct cacheFallback) {
    var src = structCount(arguments.cacheReport) ? arguments.cacheReport : arguments.cacheFallback;
    var out = {
      "forecast" = cacheEntry(src, "forecast"),
      "alerts" = cacheEntry(src, "alerts"),
      "surface" = cacheEntry(src, "surface"),
      "marine" = cacheEntry(src, "marine"),
      "tide" = cacheEntry(src, "tide"),
      "zoneForecast" = nullValue()
    };
    if (structKeyExists(src, "zone_forecast") AND isStruct(src.zone_forecast) AND structCount(src.zone_forecast)) {
      out.zoneForecast = src.zone_forecast;
    } else if (structKeyExists(src, "zoneForecast") AND isStruct(src.zoneForecast) AND structCount(src.zoneForecast)) {
      out.zoneForecast = src.zoneForecast;
    }
    return out;
  }

  private array function normalizeSources(required struct meta, required struct surface, required struct marine, required struct zone) {
    var out = [];
    var provider = stringValue(pick(arguments.meta, ["provider", "PROVIDER"], "NOAA/NWS"));
    arrayAppend(out, {
      "key" = "weather",
      "provider" = provider,
      "stationId" = stringValue(pick(arguments.surface, ["station_id", "STATION_ID", "stationId"], "")),
      "updatedAtUtc" = stringValue(pick(arguments.meta, ["generated_at_utc", "GENERATED_AT_UTC", "generatedAtUtc"], "")),
      "url" = ""
    });
    if (len(stringValue(pick(arguments.zone, ["source_url", "SOURCE_URL", "sourceUrl"], "")))) {
      arrayAppend(out, {
        "key" = "zoneForecast",
        "provider" = "NWS CWF",
        "stationId" = stringValue(pick(arguments.zone, ["zone_id", "ZONE_ID", "zoneId"], "")),
        "updatedAtUtc" = "",
        "url" = stringValue(pick(arguments.zone, ["source_url", "SOURCE_URL", "sourceUrl"], ""))
      });
    }
    if (len(stringValue(pick(arguments.marine, ["tide_station", "TIDE_STATION", "tideStation"], "")))) {
      arrayAppend(out, {
        "key" = "tide",
        "provider" = "NOAA CO-OPS",
        "stationId" = stringValue(pick(arguments.marine, ["tide_station", "TIDE_STATION", "tideStation"], "")),
        "updatedAtUtc" = "",
        "url" = ""
      });
    }
    return out;
  }

  private struct function normalizeTimings(required struct marine, required struct zone) {
    var out = {};
    var marineMeta = getStruct(arguments.marine, ["META", "meta"]);
    var marineTiming = getStruct(marineMeta, ["TIMING", "timing"]);
    for (var key in marineTiming) {
      if (isNumeric(marineTiming[key])) {
        out[key] = val(marineTiming[key]);
      }
    }
    return out;
  }

  private struct function normalizeTideEvent(required struct row) {
    if (!structCount(arguments.row)) {
      return {
        "timeUtc" = "",
        "heightFt" = nullValue()
      };
    }
    return {
      "timeUtc" = stringValue(pick(arguments.row, ["time_utc", "TIME_UTC", "timeUtc", "time"], "")),
      "heightFt" = numericValue(pick(arguments.row, ["height_ft", "HEIGHT_FT", "heightFt", "height"], nullValue()))
    };
  }

  private struct function dataPayload(required struct envelope) {
    var data = pick(arguments.envelope, ["DATA", "data"], {});
    return isStruct(data) ? data : arguments.envelope;
  }

  private struct function getStruct(required struct source, required array keys) {
    var value = pick(arguments.source, arguments.keys, {});
    return isStruct(value) ? value : {};
  }

  private any function pick(required struct source, required array keys, any defaultValue="") {
    for (var key in arguments.keys) {
      if (structKeyExists(arguments.source, key)) {
        return arguments.source[key];
      }
    }
    return arguments.defaultValue;
  }

  private any function firstNonEmpty(required array values) {
    for (var value in arguments.values) {
      if (isStruct(value) OR isArray(value)) {
        if ((isStruct(value) AND structCount(value)) OR (isArray(value) AND arrayLen(value))) {
          return value;
        }
      } else if (!isNullValue(value) AND len(trim(toString(value)))) {
        return value;
      }
    }
    return "";
  }

  private any function cacheEntry(required struct source, required string key) {
    if (structKeyExists(arguments.source, arguments.key) AND isStruct(arguments.source[arguments.key]) AND structCount(arguments.source[arguments.key])) {
      return arguments.source[arguments.key];
    }
    return nullValue();
  }

  private struct function inventoryRow(required string section, required string element, required string status, required string currentSource, required string futureField, required string fallback) {
    return {
      "section" = arguments.section,
      "element" = arguments.element,
      "status" = arguments.status,
      "currentSource" = arguments.currentSource,
      "futureField" = arguments.futureField,
      "fallback" = arguments.fallback
    };
  }

  private boolean function boolValue(required any value) {
    if (isBoolean(arguments.value)) {
      return arguments.value;
    }
    var s = lCase(trim(toString(arguments.value)));
    return listFindNoCase("true,yes,1", s) GT 0;
  }

  private any function numericValue(required any value) {
    if (isNullValue(arguments.value) OR !isNumeric(arguments.value)) {
      return nullValue();
    }
    return val(arguments.value);
  }

  private string function stringValue(required any value) {
    if (isNullValue(arguments.value)) {
      return "";
    }
    return toString(arguments.value);
  }

  private boolean function isNullValue(any value) {
    return !structKeyExists(arguments, "value") OR isNull(arguments.value);
  }

  private any function nullValue() {
    return javaCast("null", "");
  }

}



