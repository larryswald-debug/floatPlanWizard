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

  public struct function normalizeMarineZone(struct zonesPayload = {}) {
    return {
      "available" = false,
      "zoneId" = "",
      "zoneName" = "",
      "office" = "",
      "sourceUrl" = "",
      "reason" = "No fake marine zone."
    };
  }

  public struct function getZoneForecast(required string zoneId) {
    return { "ok" = false, "statusCode" = 404, "url" = "fake:nws:zone-forecast", "data" = {}, "error" = "No fake zone forecast." };
  }

  public struct function normalizeZoneForecast(struct zoneMeta = {}, struct forecastPayload = {}) {
    return {
      "available" = false,
      "zoneId" = zoneMeta.zoneId ?: "",
      "zoneName" = zoneMeta.zoneName ?: "",
      "office" = zoneMeta.office ?: "",
      "synopsis" = "",
      "periods" = [],
      "sourceUrl" = zoneMeta.sourceUrl ?: "",
      "reason" = zoneMeta.reason ?: "No fake marine zone."
    };
  }
}
