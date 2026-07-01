component output="false" {

  public any function init(string userAgent = "FloatPlanWizard Weather Rewrite Phase 1 (https://floatplanwizard.com)") {
    variables.userAgent = arguments.userAgent;
    variables.baseUrl = "https://api.weather.gov";
    return this;
  }

  public struct function getPoint(required numeric lat, required numeric lon) {
    return fetchJson(variables.baseUrl & "/points/" & formatCoordinate(arguments.lat) & "," & formatCoordinate(arguments.lon), 4);
  }

  public struct function getHourlyForecast(required string url) {
    return fetchJson(arguments.url, 5);
  }

  public struct function getObservationStations(required string url) {
    return fetchJson(arguments.url, 4);
  }

  public struct function getLatestObservation(required string stationId) {
    return fetchJson(variables.baseUrl & "/stations/" & urlEncodedFormat(arguments.stationId) & "/observations/latest", 4);
  }

  public struct function getActiveAlerts(required numeric lat, required numeric lon) {
    return fetchJson(variables.baseUrl & "/alerts/active?point=" & formatCoordinate(arguments.lat) & "," & formatCoordinate(arguments.lon), 4);
  }

  public struct function getMarineZones(required numeric lat, required numeric lon) {
    return fetchJson(variables.baseUrl & "/zones?type=marine&point=" & formatCoordinate(arguments.lat) & "," & formatCoordinate(arguments.lon), 4);
  }

  public struct function getZoneForecast(required string zoneId) {
    return fetchJson(variables.baseUrl & "/zones/marine/" & urlEncodedFormat(arguments.zoneId) & "/forecast", 4);
  }

  public struct function fetchJson(required string url, numeric timeoutSeconds = 4) {
    var result = {
      "ok" = false,
      "statusCode" = 0,
      "url" = arguments.url,
      "data" = {},
      "error" = "",
      "fetchedAtUtc" = isoUtc(now())
    };

    try {
      cfhttp(method="GET", url=arguments.url, result="local.http", timeout=arguments.timeoutSeconds) {
        cfhttpparam(type="header", name="User-Agent", value=variables.userAgent);
        cfhttpparam(type="header", name="Accept", value="application/geo+json, application/json");
      }

      result.statusCode = val(local.http.statusCode);
      if (result.statusCode GTE 200 && result.statusCode LT 300 && len(trim(local.http.fileContent))) {
        result.data = deserializeJSON(local.http.fileContent);
        result.ok = true;
      } else {
        result.error = "NWS request failed with HTTP " & local.http.statusCode;
      }
    } catch (any err) {
      result.error = err.message;
    }

    return result;
  }

  public struct function normalizePoint(required struct pointPayload) {
    var props = arguments.pointPayload.properties ?: {};
    var rel = props.relativeLocation ?: {};
    var relProps = rel.properties ?: {};
    return {
      "timezone" = props.timeZone ?: "",
      "displayName" = trim((relProps.city ?: "") & (len(relProps.state ?: "") ? ", " & relProps.state : "")),
      "forecastHourlyUrl" = props.forecastHourly ?: "",
      "forecastUrl" = props.forecast ?: "",
      "observationStationsUrl" = props.observationStations ?: "",
      "forecastZoneUrl" = props.forecastZone ?: "",
      "gridId" = props.gridId ?: "",
      "gridX" = props.gridX ?: javacast("null", ""),
      "gridY" = props.gridY ?: javacast("null", ""),
      "office" = props.cwa ?: ""
    };
  }

  public struct function normalizeCurrentObservation(struct observationPayload = {}, string fallbackStationId = "") {
    var props = arguments.observationPayload.properties ?: {};
    var stationId = arguments.fallbackStationId;
    if (len(props.station ?: "")) {
      stationId = listLast(props.station, "/");
    }

    return {
      "available" = structCount(props) GT 0,
      "condition" = props.textDescription ?: "",
      "tempF" = cToF(props.temperature.value ?: javacast("null", "")),
      "feelsLikeF" = cToF(props.heatIndex.value ?: props.windChill.value ?: javacast("null", "")),
      "windMph" = kmhToMph(props.windSpeed.value ?: javacast("null", "")),
      "gustMph" = kmhToMph(props.windGust.value ?: javacast("null", "")),
      "windDirectionDeg" = numericOrNull(props.windDirection.value ?: javacast("null", "")),
      "windDirectionLabel" = degreesToCompass(props.windDirection.value ?: javacast("null", "")),
      "pressureInHg" = paToInHg(props.barometricPressure.value ?: javacast("null", "")),
      "visibilityMi" = metersToMiles(props.visibility.value ?: javacast("null", "")),
      "humidityPct" = numericOrNull(props.relativeHumidity.value ?: javacast("null", "")),
      "dewpointF" = cToF(props.dewpoint.value ?: javacast("null", "")),
      "observedAtUtc" = props.timestamp ?: "",
      "stationId" = stationId,
      "stationName" = stationId
    };
  }

  public array function normalizeForecast12h(struct forecastPayload = {}, any riskService = "") {
    var periods = forecastPayload.properties.periods ?: [];
    var rows = [];

    if (!isArray(periods)) {
      return rows;
    }

    var periodLimit = arrayLen(periods);
    if (periodLimit GT 12) {
      periodLimit = 12;
    }

    for (var i = 1; i <= periodLimit; i++) {
      var p = periods[i];
      var wind = parseFirstNumber(p.windSpeed ?: "");
      var row = {
        "timeLabel" = p.startTime ?: "",
        "condition" = p.shortForecast ?: "",
        "tempF" = isNumeric(p.temperature ?: "") ? val(p.temperature) : javacast("null", ""),
        "windMph" = wind,
        "gustMph" = javacast("null", ""),
        "windDirectionLabel" = p.windDirection ?: "",
        "precipChancePct" = numericOrNull(p.probabilityOfPrecipitation.value ?: javacast("null", "")),
        "seasFt" = javacast("null", ""),
        "riskLabel" = "Unknown"
      };
      if (isObject(arguments.riskService)) {
        row.riskLabel = arguments.riskService.riskForForecastPeriod(row);
      }
      arrayAppend(rows, row);
    }

    return rows;
  }

  public array function normalizeAlerts(struct alertsPayload = {}) {
    var features = arguments.alertsPayload.features ?: [];
    var alerts = [];

    if (!isArray(features)) {
      return alerts;
    }

    for (var feature in features) {
      var props = feature.properties ?: {};
      arrayAppend(alerts, {
        "event" = props.event ?: "",
        "headline" = props.headline ?: "",
        "severity" = props.severity ?: "",
        "effectiveUtc" = props.effective ?: "",
        "expiresUtc" = props.expires ?: "",
        "description" = left(props.description ?: "", 500),
        "instruction" = left(props.instruction ?: "", 500)
      });
    }

    return alerts;
  }

  public struct function normalizeMarineZone(struct zonesPayload = {}) {
    var features = arguments.zonesPayload.features ?: [];
    if (isArray(features) && arrayLen(features) GT 0) {
      var props = features[1].properties ?: {};
      return {
        "available" = true,
        "zoneId" = props.id ?: listLast(props["@id"] ?: "", "/"),
        "zoneName" = props.name ?: "",
        "office" = props.cwa ?: "",
        "sourceUrl" = props["@id"] ?: "",
        "reason" = ""
      };
    }

    return {
      "available" = false,
      "zoneId" = "",
      "zoneName" = "",
      "office" = "",
      "sourceUrl" = "",
      "reason" = "No NWS marine zone matched this point."
    };
  }

  public struct function normalizeZoneForecast(struct zoneMeta = {}, struct forecastPayload = {}) {
    var out = {
      "available" = false,
      "zoneId" = zoneMeta.zoneId ?: "",
      "zoneName" = zoneMeta.zoneName ?: "",
      "office" = zoneMeta.office ?: "",
      "synopsis" = "",
      "periods" = [],
      "sourceUrl" = zoneMeta.sourceUrl ?: "",
      "reason" = zoneMeta.reason ?: ""
    };

    var periods = arguments.forecastPayload.properties.periods ?: [];
    if (isArray(periods) && arrayLen(periods) GT 0) {
      out.available = true;
      out.reason = "";
      var zonePeriodLimit = arrayLen(periods);
      if (zonePeriodLimit GT 6) {
        zonePeriodLimit = 6;
      }

      for (var i = 1; i <= zonePeriodLimit; i++) {
        arrayAppend(out.periods, {
          "name" = periods[i].name ?: "",
          "forecast" = periods[i].detailedForecast ?: periods[i].shortForecast ?: ""
        });
      }
    }

    return out;
  }

  public string function firstStationId(struct stationsPayload = {}) {
    var features = arguments.stationsPayload.features ?: [];
    if (!isArray(features) || arrayLen(features) EQ 0) {
      return "";
    }
    return features[1].properties.stationIdentifier ?: listLast(features[1].id ?: "", "/");
  }

  public any function numericOrNull(any value) {
    if (isNull(arguments.value) || !isNumeric(arguments.value)) {
      return javacast("null", "");
    }
    return val(arguments.value);
  }

  private any function cToF(any value) {
    if (isNull(arguments.value) || !isNumeric(arguments.value)) {
      return javacast("null", "");
    }
    return round((val(arguments.value) * 9 / 5) + 32);
  }

  private any function kmhToMph(any value) {
    if (isNull(arguments.value) || !isNumeric(arguments.value)) {
      return javacast("null", "");
    }
    return round(val(arguments.value) * 0.621371);
  }

  private any function metersToMiles(any value) {
    if (isNull(arguments.value) || !isNumeric(arguments.value)) {
      return javacast("null", "");
    }
    return round((val(arguments.value) / 1609.344) * 10) / 10;
  }

  private any function paToInHg(any value) {
    if (isNull(arguments.value) || !isNumeric(arguments.value)) {
      return javacast("null", "");
    }
    return round((val(arguments.value) * 0.0002953) * 100) / 100;
  }

  private any function parseFirstNumber(required string text) {
    var match = reFind("[0-9]+", arguments.text, 1, true);
    if (match.len[1] LTE 0) {
      return javacast("null", "");
    }
    return val(mid(arguments.text, match.pos[1], match.len[1]));
  }

  private string function degreesToCompass(any degrees) {
    if (isNull(arguments.degrees) || !isNumeric(arguments.degrees)) {
      return "";
    }
    var dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
    var idx = int(((val(arguments.degrees) + 22.5) mod 360) / 45) + 1;
    return dirs[idx];
  }

  private string function isoUtc(required date value) {
    return dateTimeFormat(dateConvert("local2Utc", arguments.value), "yyyy-mm-dd'T'HH:nn:ss'Z'");
  }

  private string function formatCoordinate(required numeric value) {
    return reReplace(trim(numberFormat(arguments.value, "0.0000")), ",", "", "all");
  }
}


