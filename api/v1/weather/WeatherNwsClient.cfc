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

  public struct function getGridData(required string url) {
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

  public struct function getNearestMarineZone(required numeric lat, required numeric lon, string office = "") {
    var result = {
      "ok" = false,
      "statusCode" = 0,
      "url" = variables.baseUrl & "/zones?type=marine",
      "data" = {},
      "error" = "",
      "fetchedAtUtc" = isoUtc(now())
    };

    var catalog = fetchJson(result.url, 5);
    result.statusCode = catalog.statusCode;
    if (!catalog.ok) {
      result.error = catalog.error;
      return result;
    }

    var features = catalog.data.features ?: [];
    if (!isArray(features) || arrayLen(features) EQ 0) {
      result.error = "NWS marine zone catalog returned no zones.";
      return result;
    }

    var bestFeature = {};
    var bestDistance = 999999;
    var officeFilter = ucase(trim(arguments.office));

    for (var feature in features) {
      var props = feature.properties ?: {};
      if (len(officeFilter) && !cwaContains(props.cwa ?: [], officeFilter)) {
        continue;
      }

      var zoneUrl = props["@id"] ?: "";
      if (!len(zoneUrl) && len(props.id ?: "")) {
        zoneUrl = variables.baseUrl & "/zones/marine/" & urlEncodedFormat(props.id);
      }
      if (!len(zoneUrl)) {
        continue;
      }

      var detail = fetchJson(zoneUrl, 4);
      if (!detail.ok || !isStruct(detail.data) || !structKeyExists(detail.data, "geometry") || !isStruct(detail.data.geometry)) {
        continue;
      }

      var distance = nearestGeometryDistanceMiles(arguments.lat, arguments.lon, detail.data.geometry);
      if (!isNull(distance) && distance LT bestDistance) {
        bestDistance = distance;
        bestFeature = detail.data;
      }
    }

    if (!structCount(bestFeature)) {
      result.error = len(officeFilter)
        ? "No NWS marine zone geometry matched office " & officeFilter & "."
        : "No NWS marine zone geometry was available for nearest-zone matching.";
      return result;
    }

    bestFeature.properties.nearestDistanceMiles = round(bestDistance * 10) / 10;
    result.ok = true;
    result.data = {
      "type" = "FeatureCollection",
      "features" = [ bestFeature ]
    };
    return result;
  }

  public struct function getZoneForecast(required string zoneId) {
    return fetchJson(variables.baseUrl & "/zones/marine/" & urlEncodedFormat(arguments.zoneId) & "/forecast", 4);
  }

  public struct function getCwfProduct(required string office) {
    var officeCode = ucase(trim(arguments.office));
    var listUrl = variables.baseUrl & "/products/types/CWF/locations/" & urlEncodedFormat(officeCode);
    var listResult = fetchJson(listUrl, 5);
    if (!listResult.ok) {
      return listResult;
    }

    var graph = listResult.data["@graph"] ?: [];
    if (!isArray(graph) || arrayLen(graph) EQ 0) {
      listResult.ok = false;
      listResult.error = "NOAA Coastal Waters Forecast product list did not include a latest product for " & officeCode & ".";
      return listResult;
    }

    var productUrl = graph[1]["@id"] ?: graph[1].id ?: "";
    if (!len(productUrl)) {
      listResult.ok = false;
      listResult.error = "NOAA Coastal Waters Forecast product list did not include a product URL for " & officeCode & ".";
      return listResult;
    }

    return fetchJson(productUrl, 5);
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
      "forecastGridDataUrl" = props.forecastGridData ?: "",
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
      "gustSource" = isNull(props.windGust.value ?: javacast("null", "")) ? "" : "NWS_OBSERVATION",
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
        "gustSource" = "",
        "startTime" = p.startTime ?: "",
        "endTime" = p.endTime ?: "",
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
        "nearestDistanceMiles" = props.nearestDistanceMiles ?: javacast("null", ""),
        "reason" = ""
      };
    }

    return {
      "available" = false,
      "zoneId" = "",
      "zoneName" = "",
      "office" = "",
      "sourceUrl" = "",
      "nearestDistanceMiles" = javacast("null", ""),
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
      "seasFt" = javacast("null", ""),
      "waveHeightFt" = javacast("null", ""),
      "wavePeriodSec" = javacast("null", ""),
      "waveDirectionLabel" = "",
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

      var marineConditions = extractMarineConditionsFromZone(out);
      if (marineConditions.available) {
        out.seasFt = marineConditions.seasFt;
        out.waveHeightFt = marineConditions.waveHeightFt;
        if (structKeyExists(marineConditions, "wavePeriodSec") && !isNull(marineConditions["wavePeriodSec"])) {
          out.wavePeriodSec = marineConditions["wavePeriodSec"];
        }
        if (len(marineConditions.waveDirectionLabel ?: "")) {
          out.waveDirectionLabel = marineConditions.waveDirectionLabel;
        }
      }
    }

    return out;
  }

  public struct function normalizeCwfZoneForecast(struct zoneMeta = {}, struct productPayload = {}) {
    var out = {
      "available" = false,
      "zoneId" = zoneMeta.zoneId ?: "",
      "zoneName" = zoneMeta.zoneName ?: "",
      "office" = normalizeOffice(zoneMeta.office ?: ""),
      "synopsis" = "",
      "periods" = [],
      "sourceUrl" = arguments.productPayload["@id"] ?: arguments.productPayload.id ?: zoneMeta.sourceUrl ?: "",
      "seasFt" = javacast("null", ""),
      "waveHeightFt" = javacast("null", ""),
      "wavePeriodSec" = javacast("null", ""),
      "waveDirectionLabel" = "",
      "reason" = zoneMeta.reason ?: ""
    };

    var productText = arguments.productPayload.productText ?: "";
    if (!len(out.zoneId)) {
      out.reason = "No NWS marine zone id was available for Coastal Waters Forecast parsing.";
      return out;
    }
    if (!len(productText)) {
      out.reason = "NOAA Coastal Waters Forecast product response did not include product text.";
      return out;
    }

    var zoneBlock = extractCwfZoneBlock(productText, out.zoneId);
    if (!len(zoneBlock)) {
      out.reason = "NOAA Coastal Waters Forecast product did not contain zone " & out.zoneId & ".";
      return out;
    }

    out.periods = parseCwfPeriods(zoneBlock);
    if (arrayLen(out.periods) EQ 0) {
      out.reason = "NOAA Coastal Waters Forecast product did not contain forecast periods for " & out.zoneId & ".";
      return out;
    }

    out.available = true;
    out.reason = "";
    var marineConditions = extractMarineConditionsFromZone(out);
    if (marineConditions.available) {
      out.seasFt = marineConditions.seasFt;
      out.waveHeightFt = marineConditions.waveHeightFt;
      if (structKeyExists(marineConditions, "wavePeriodSec") && !isNull(marineConditions["wavePeriodSec"])) {
        out.wavePeriodSec = marineConditions["wavePeriodSec"];
      }
      if (len(marineConditions.waveDirectionLabel ?: "")) {
        out.waveDirectionLabel = marineConditions.waveDirectionLabel;
      }
    }

    return out;
  }

  public struct function extractMarineConditionsFromZone(struct zoneForecast = {}) {
    var out = {
      "available" = false,
      "seasFt" = javacast("null", ""),
      "waveHeightFt" = javacast("null", ""),
      "wavePeriodSec" = javacast("null", ""),
      "waveDirectionLabel" = "",
      "sourcePeriod" = ""
    };
    var periods = arguments.zoneForecast.periods ?: [];
    if (!isArray(periods)) {
      return out;
    }

    for (var period in periods) {
      var forecastText = trim((period.name ?: "") & " " & (period.forecast ?: ""));
      var wave = parseMarineFeet(forecastText);
      if (!isNull(wave)) {
        out.available = true;
        out.seasFt = wave;
        out.waveHeightFt = wave;
        out.sourcePeriod = period.name ?: "";
        var wavePeriod = parseWavePeriodSeconds(forecastText);
        if (!isNull(wavePeriod)) {
          out.wavePeriodSec = wavePeriod;
        }
        out.waveDirectionLabel = parseWaveDirectionLabel(forecastText);
        return out;
      }
    }

    return out;
  }

  public string function firstStationId(struct stationsPayload = {}) {
    var ids = stationIds(arguments.stationsPayload, 1);
    if (!arrayLen(ids)) {
      return "";
    }
    return ids[1];
  }

  public array function stationIds(struct stationsPayload = {}, numeric maxStations = 6) {
    var ids = [];
    var features = arguments.stationsPayload.features ?: [];
    if (!isArray(features) || arrayLen(features) EQ 0) {
      return ids;
    }

    for (var feature in features) {
      var stationId = feature.properties.stationIdentifier ?: listLast(feature.id ?: "", "/");
      if (len(stationId)) {
        arrayAppend(ids, stationId);
      }
      if (arrayLen(ids) GTE arguments.maxStations) {
        break;
      }
    }

    return ids;
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

  private any function parseMarineFeet(required string text) {
    var match = reFindNoCase("(seas|waves)[^0-9]*([0-9]+)([[:space:]]*(to|-)[[:space:]]*([0-9]+))?[[:space:]]*(foot|feet|ft)", arguments.text, 1, true);
    if (arrayLen(match.len) LT 3 || match.len[1] LTE 0 || match.len[3] LTE 0) {
      return javacast("null", "");
    }
    var firstValue = val(mid(arguments.text, match.pos[3], match.len[3]));
    var secondValue = javacast("null", "");
    if (arrayLen(match.len) GTE 6 && match.len[6] GT 0) {
      secondValue = val(mid(arguments.text, match.pos[6], match.len[6]));
    }
    if (!isNull(secondValue) && secondValue GT firstValue) {
      return secondValue;
    }
    return firstValue;
  }

  private any function parseWavePeriodSeconds(required string text) {
    var match = reFindNoCase("(period|dominant period)[^0-9]*([0-9]+)[[:space:]]*(seconds|second|sec)", arguments.text, 1, true);
    if (arrayLen(match.len) GTE 3 && match.len[1] GT 0 && match.len[3] GT 0) {
      return val(mid(arguments.text, match.pos[3], match.len[3]));
    }

    match = reFindNoCase("at[[:space:]]*([0-9]+)[[:space:]]*(seconds|second|sec)", arguments.text, 1, true);
    if (arrayLen(match.len) LT 2 || match.len[1] LTE 0 || match.len[2] LTE 0) {
      return javacast("null", "");
    }
    return val(mid(arguments.text, match.pos[2], match.len[2]));
  }

  private string function parseWaveDirectionLabel(required string text) {
    var match = reFindNoCase("Wave Detail:[[:space:]]*([A-Za-z]+)[[:space:]]+[0-9]+[[:space:]]*(foot|feet|ft)", arguments.text, 1, true);
    if (arrayLen(match.len) LT 2 || match.len[1] LTE 0 || match.len[2] LTE 0) {
      return "";
    }
    return normalizeWaveDirection(mid(arguments.text, match.pos[2], match.len[2]));
  }

  private string function normalizeWaveDirection(required string direction) {
    var value = lcase(trim(arguments.direction));
    var labels = {
      "north" = "N",
      "northeast" = "NE",
      "east" = "E",
      "southeast" = "SE",
      "south" = "S",
      "southwest" = "SW",
      "west" = "W",
      "northwest" = "NW"
    };
    return structKeyExists(labels, value) ? labels[value] : trim(arguments.direction);
  }

  private string function normalizeOffice(any value) {
    if (isArray(arguments.value) && arrayLen(arguments.value) GT 0) {
      return ucase(trim(arguments.value[1]));
    }
    return ucase(trim(toString(arguments.value)));
  }

  private boolean function cwaContains(any cwa, required string office) {
    var targetOffice = ucase(trim(arguments.office));
    if (!len(targetOffice)) {
      return true;
    }
    if (isArray(arguments.cwa)) {
      for (var item in arguments.cwa) {
        if (ucase(trim(toString(item))) EQ targetOffice) {
          return true;
        }
      }
      return false;
    }
    return ucase(trim(toString(arguments.cwa))) EQ targetOffice;
  }

  private any function nearestGeometryDistanceMiles(required numeric lat, required numeric lon, required struct geometry) {
    var coords = arguments.geometry.coordinates ?: [];
    var baseLat = arguments.lat;
    var baseLon = arguments.lon;
    var best = 999999;
    var found = false;

    function walkCoords(required any node) {
      if (!isArray(arguments.node)) {
        return;
      }
      if (arrayLen(arguments.node) GTE 2 && isNumeric(arguments.node[1]) && isNumeric(arguments.node[2])) {
        var distance = haversineMiles(baseLat, baseLon, val(arguments.node[2]), val(arguments.node[1]));
        if (distance LT best) {
          best = distance;
          found = true;
        }
        return;
      }
      for (var child in arguments.node) {
        walkCoords(child);
      }
    }

    walkCoords(coords);
    return found ? best : javacast("null", "");
  }

  private numeric function haversineMiles(required numeric lat1, required numeric lon1, required numeric lat2, required numeric lon2) {
    var radiusMiles = 3958.7613;
    var dLat = radians(arguments.lat2 - arguments.lat1);
    var dLon = radians(arguments.lon2 - arguments.lon1);
    var a = sin(dLat / 2) * sin(dLat / 2)
      + cos(radians(arguments.lat1)) * cos(radians(arguments.lat2))
      * sin(dLon / 2) * sin(dLon / 2);
    return radiusMiles * 2 * atn2(sqr(a), sqr(1 - a));
  }

  private numeric function radians(required numeric value) {
    return arguments.value * pi() / 180;
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

  private string function extractCwfZoneBlock(required string productText, required string zoneId) {
    var text = replace(arguments.productText, chr(13), "", "all");
    var marker = ucase(trim(arguments.zoneId)) & "-";
    var startPos = findNoCase(marker, text);
    if (startPos LTE 0) {
      return "";
    }
    var endPos = find(chr(10) & "$$", text, startPos);
    if (endPos LTE 0) {
      endPos = len(text) + 1;
    }
    return mid(text, startPos, endPos - startPos);
  }

  private array function parseCwfPeriods(required string zoneBlock) {
    var periods = [];
    var lines = listToArray(replace(arguments.zoneBlock, chr(13), "", "all"), chr(10), true);
    var current = {};

    for (var line in lines) {
      var cleanLine = trim(line);
      if (!len(cleanLine)) {
        continue;
      }

      var markerPos = find("...", cleanLine);
      if (left(cleanLine, 1) EQ "." && markerPos GT 2) {
        if (structCount(current)) {
          arrayAppend(periods, current);
        }
        current = {
          "name" = trim(mid(cleanLine, 2, markerPos - 2)),
          "forecast" = trim(mid(cleanLine, markerPos + 3, len(cleanLine)))
        };
      } else if (structCount(current)) {
        current.forecast = trim(current.forecast & " " & cleanLine);
      }
    }

    if (structCount(current)) {
      arrayAppend(periods, current);
    }

    if (arrayLen(periods) GT 6) {
      return arraySlice(periods, 1, 6);
    }
    return periods;
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




