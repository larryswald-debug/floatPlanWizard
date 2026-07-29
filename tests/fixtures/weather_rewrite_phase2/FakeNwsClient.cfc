component output="false" {

  public any function init(boolean failPoint = false, boolean emptyForecast = false) {
    variables.failPoint = arguments.failPoint;
    variables.emptyForecast = arguments.emptyForecast;
    return this;
  }

  public struct function getPoint(required numeric lat, required numeric lon) {
    if (variables.failPoint) {
      return { "ok" = false, "statusCode" = 503, "url" = "fake:nws:point", "data" = {}, "error" = "NWS point failure" };
    }
    return { "ok" = true, "statusCode" = 200, "url" = "fake:nws:point", "data" = {} };
  }

  public struct function normalizePoint(required struct pointPayload) {
    return {
      "timezone" = "America/New_York",
      "displayName" = "Madeira Beach, FL",
      "forecastHourlyUrl" = "fake:nws:hourly",
      "forecastUrl" = "fake:nws:forecast",
      "observationStationsUrl" = "fake:nws:stations",
      "forecastZoneUrl" = "fake:nws:zone",
      "gridId" = "TBW",
      "gridX" = 1,
      "gridY" = 1,
      "office" = "TBW"
    };
  }

  public struct function getHourlyForecast(required string url) {
    return { "ok" = true, "statusCode" = 200, "url" = arguments.url, "data" = {} };
  }

  public array function normalizeForecast12h(struct forecastPayload = {}, any riskService = "") {
    if (variables.emptyForecast) {
      return [];
    }
    return [{
      "timeLabel" = "2026-07-01T12:00:00-04:00",
      "condition" = "Partly Sunny",
      "tempF" = 86,
      "windMph" = 10,
      "gustMph" = 15,
      "windDirectionLabel" = "E",
      "precipChancePct" = 20,
      "seasFt" = javacast("null", ""),
      "riskLabel" = "Good"
    }];
  }

  public struct function getObservationStations(required string url) {
    return { "ok" = true, "statusCode" = 200, "url" = arguments.url, "data" = {} };
  }

  public string function firstStationId(struct stationsPayload = {}) {
    return "KPIE";
  }

  public struct function getLatestObservation(required string stationId) {
    return { "ok" = true, "statusCode" = 200, "url" = "fake:nws:observation", "data" = {} };
  }

  public struct function normalizeCurrentObservation(struct observationPayload = {}, string fallbackStationId = "") {
    return {
      "available" = true,
      "condition" = "Partly Cloudy",
      "tempF" = 86,
      "feelsLikeF" = 88,
      "windMph" = 10,
      "gustMph" = 15,
      "windDirectionDeg" = 90,
      "windDirectionLabel" = "E",
      "pressureInHg" = 30.01,
      "visibilityMi" = 10,
      "humidityPct" = 62,
      "dewpointF" = 70,
      "observedAtUtc" = "2026-07-01T16:00:00Z",
      "stationId" = len(arguments.fallbackStationId) ? arguments.fallbackStationId : "KPIE",
      "stationName" = len(arguments.fallbackStationId) ? arguments.fallbackStationId : "KPIE"
    };
  }

  public struct function getActiveAlerts(required numeric lat, required numeric lon) {
    return { "ok" = true, "statusCode" = 200, "url" = "fake:nws:alerts", "data" = {} };
  }

  public array function normalizeAlerts(struct alertsPayload = {}) {
    return [];
  }

  public struct function getMarineZones(required numeric lat, required numeric lon) {
    return { "ok" = true, "statusCode" = 200, "url" = "fake:nws:zones", "data" = {} };
  }

  public struct function getNearestMarineZone(required numeric lat, required numeric lon, string office = "") {
    return { "ok" = true, "statusCode" = 200, "url" = "fake:nws:nearest-zone", "data" = {} };
  }

  public struct function normalizeMarineZone(struct zonesPayload = {}) {
    return {
      "available" = true,
      "zoneId" = "GMZ853",
      "zoneName" = "Coastal waters from Englewood to Tarpon Springs FL out 20 NM",
      "office" = "TBW",
      "sourceUrl" = "fake:nws:zone/GMZ853",
      "reason" = ""
    };
  }

  public struct function getZoneForecast(required string zoneId) {
    return { "ok" = true, "statusCode" = 200, "url" = "fake:nws:zone-forecast", "data" = {} };
  }

  public struct function getCwfProduct(required string office) {
    return {
      "ok" = true,
      "statusCode" = 200,
      "url" = "fake:nws:cwf",
      "data" = {
        "@id" = "fake:nws:cwf/TBW",
        "productText" = "GMZ853-011330-" & chr(10)
          & "Coastal waters from Englewood to Tarpon Springs FL out 20 NM-" & chr(10)
          & chr(10)
          & ".TONIGHT...East winds 5 to 10 knots. Seas 2 to 3 feet. Wave Detail: East 3 feet at 4 seconds." & chr(10)
          & "$$"
      }
    };
  }

  public struct function normalizeZoneForecast(struct zoneMeta = {}, struct forecastPayload = {}) {
    return {
      "available" = true,
      "zoneId" = zoneMeta.zoneId ?: "",
      "zoneName" = zoneMeta.zoneName ?: "",
      "office" = zoneMeta.office ?: "",
      "synopsis" = "",
      "periods" = [{
        "name" = "Tonight",
        "forecast" = "East winds 5 to 10 knots. Seas 2 to 3 feet. Dominant period 4 seconds."
      }],
      "sourceUrl" = zoneMeta.sourceUrl ?: "",
      "seasFt" = 3,
      "waveHeightFt" = 3,
      "wavePeriodSec" = 4,
      "reason" = zoneMeta.reason ?: ""
    };
  }

  public struct function normalizeCwfZoneForecast(struct zoneMeta = {}, struct productPayload = {}) {
    return normalizeZoneForecast(arguments.zoneMeta, arguments.productPayload);
  }
}
