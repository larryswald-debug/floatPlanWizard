<cfsetting showdebugoutput="false" requesttimeout="90">
<cfcontent type="text/html; charset=utf-8">
<cfscript>
userStruct = (structKeyExists(session, "user") AND isStruct(session.user)) ? session.user : {};
isLoggedIn = structCount(userStruct) GT 0;
isAdmin = false;
adminWhitelist = "admin@floatplanwizard.com,lswald@yahoo.com";
roleValue = "";
emailValue = "";

function boolLike(any value, boolean defaultValue=false) {
    var txt = lCase(trim(toString(arguments.value)));
    if (!len(txt)) return arguments.defaultValue;
    if (listFindNoCase("1,true,yes,y,on", txt)) return true;
    if (listFindNoCase("0,false,no,n,off", txt)) return false;
    if (isNumeric(txt)) return (val(txt) NEQ 0);
    return arguments.defaultValue;
}

if (isLoggedIn) {
    if (structKeyExists(userStruct, "isAdmin") AND boolLike(userStruct.isAdmin, false)) {
        isAdmin = true;
    } else if (structKeyExists(userStruct, "ISADMIN") AND boolLike(userStruct.ISADMIN, false)) {
        isAdmin = true;
    } else if (structKeyExists(userStruct, "is_admin") AND boolLike(userStruct.is_admin, false)) {
        isAdmin = true;
    } else {
        if (structKeyExists(userStruct, "role")) {
            roleValue = lCase(trim(toString(userStruct.role)));
        } else if (structKeyExists(userStruct, "ROLE")) {
            roleValue = lCase(trim(toString(userStruct.ROLE)));
        }
        if (roleValue EQ "admin") {
            isAdmin = true;
        } else {
            if (structKeyExists(userStruct, "email")) {
                emailValue = lCase(trim(toString(userStruct.email)));
            } else if (structKeyExists(userStruct, "EMAIL")) {
                emailValue = lCase(trim(toString(userStruct.EMAIL)));
            }
            if (len(emailValue) AND listFindNoCase(adminWhitelist, emailValue)) {
                isAdmin = true;
            }
        }
    }
}

isAuthorized = isLoggedIn AND isAdmin;

function readUrlParam(required string key, string defaultValue="") {
    if (structKeyExists(url, arguments.key)) {
        return trim(toString(url[arguments.key]));
    }
    return arguments.defaultValue;
}

function isFiveDigitZip(required string value) {
    return reFind("^[0-9]{5}$", trim(arguments.value)) GT 0;
}

function isValidCoordinatePair(required string latRaw, required string lonRaw) {
    if (!isNumeric(arguments.latRaw) OR !isNumeric(arguments.lonRaw)) {
        return false;
    }
    var latValue = val(arguments.latRaw);
    var lonValue = val(arguments.lonRaw);
    if (latValue EQ 0 AND lonValue EQ 0) {
        return false;
    }
    return latValue GTE -90 AND latValue LTE 90 AND lonValue GTE -180 AND lonValue LTE 180;
}

function isoUtc(required date value) {
    return dateTimeFormat(dateConvert("local2Utc", arguments.value), "yyyy-mm-dd'T'HH:nn:ss'Z'");
}

function displayNumber(any value) {
    if (isNull(arguments.value)) {
        return "";
    }
    if (!isNumeric(arguments.value)) {
        return trim(toString(arguments.value));
    }
    return numberFormat(val(arguments.value), "0.000000");
}

function renderRawValue(any value, numeric depth=0) {
    if (isNull(arguments.value)) {
        return "<span class=""muted"">null</span>";
    }

    if (isSimpleValue(arguments.value)) {
        if (isBoolean(arguments.value)) {
            return arguments.value ? "true" : "false";
        }
        if (!len(trim(toString(arguments.value)))) {
            return "<span class=""muted"">(empty)</span>";
        }
        return encodeForHtml(toString(arguments.value));
    }

    if (isArray(arguments.value)) {
        var arrayHtml = "<table class=""raw-table raw-table-nested""><tbody>";
        if (arrayLen(arguments.value) EQ 0) {
            return "<span class=""muted"">[]</span>";
        }
        for (var arrayIndex = 1; arrayIndex <= arrayLen(arguments.value); arrayIndex++) {
            var arrayCell = "";
            if (isNull(arguments.value[arrayIndex])) {
                arrayCell = "<span class=""muted"">null</span>";
            } else {
                arrayCell = renderRawValue(arguments.value[arrayIndex], arguments.depth + 1);
            }
            arrayHtml &= "<tr><th>[" & arrayIndex & "]</th><td>" & arrayCell & "</td></tr>";
        }
        arrayHtml &= "</tbody></table>";
        return arrayHtml;
    }

    if (isStruct(arguments.value)) {
        var keys = structKeyArray(arguments.value);
        if (arrayLen(keys) EQ 0) {
            return "<span class=""muted"">{}</span>";
        }
        arraySort(keys, "textnocase");
        var structHtml = "<table class=""raw-table raw-table-nested""><tbody>";
        for (var keyName in keys) {
            var structCell = "";
            if (isNull(arguments.value[keyName])) {
                structCell = "<span class=""muted"">null</span>";
            } else {
                structCell = renderRawValue(arguments.value[keyName], arguments.depth + 1);
            }
            structHtml &= "<tr><th>" & encodeForHtml(keyName) & "</th><td>" & structCell & "</td></tr>";
        }
        structHtml &= "</tbody></table>";
        return structHtml;
    }

    return encodeForHtml(toString(arguments.value));
}

function haversineMiles(required numeric lat1, required numeric lon1, required numeric lat2, required numeric lon2) {
    var radiusMiles = 3958.8;
    var dLat = (arguments.lat2 - arguments.lat1) * pi() / 180;
    var dLon = (arguments.lon2 - arguments.lon1) * pi() / 180;
    var a = sin(dLat / 2) * sin(dLat / 2)
      + cos(arguments.lat1 * pi() / 180) * cos(arguments.lat2 * pi() / 180)
      * sin(dLon / 2) * sin(dLon / 2);
    var c = 2 * atn2(sqr(a), sqr(1 - a));
    return radiusMiles * c;
}

function atn2(required numeric y, required numeric x) {
    if (arguments.x GT 0) {
        return atn(arguments.y / arguments.x);
    }
    if (arguments.x LT 0 AND arguments.y GTE 0) {
        return atn(arguments.y / arguments.x) + pi();
    }
    if (arguments.x LT 0 AND arguments.y LT 0) {
        return atn(arguments.y / arguments.x) - pi();
    }
    if (arguments.x EQ 0 AND arguments.y GT 0) {
        return pi() / 2;
    }
    if (arguments.x EQ 0 AND arguments.y LT 0) {
        return -pi() / 2;
    }
    return 0;
}

function nearestCoopsStationFromPayload(struct payload={}, required numeric lat, required numeric lon) {
    var out = {
        "available" = false,
        "id" = "",
        "name" = "",
        "lat" = javacast("null", ""),
        "lon" = javacast("null", ""),
        "distanceMiles" = javacast("null", ""),
        "reason" = ""
    };
    var stations = arguments.payload.stations ?: [];
    if (!isArray(stations) OR arrayLen(stations) EQ 0) {
        out.reason = "No CO-OPS stations were returned.";
        return out;
    }

    var best = {};
    var bestDistance = 999999;
    for (var station in stations) {
        var stationLat = station.lat ?: "";
        var stationLon = station.lng ?: (station.lon ?: "");
        if (!isNumeric(stationLat) OR !isNumeric(stationLon)) {
            continue;
        }
        var distance = haversineMiles(arguments.lat, arguments.lon, val(stationLat), val(stationLon));
        if (distance LT bestDistance) {
            bestDistance = distance;
            best = station;
        }
    }

    if (!structCount(best)) {
        out.reason = "No returned CO-OPS station had usable coordinates.";
        return out;
    }

    out.available = true;
    out.id = best.id ?: "";
    out.name = best.name ?: out.id;
    out.lat = val(best.lat);
    out.lon = val(best.lng ?: best.lon);
    out.distanceMiles = round(bestDistance * 10) / 10;
    return out;
}

function requestResult(required string provider, required string endpoint, required string cacheKey, required numeric ttlSeconds, required boolean useCache, required any cache, required any producer, string note="") {
    var started = getTickCount();
    var cached = {
        "found" = false,
        "hit" = false,
        "ageSeconds" = javacast("null", ""),
        "createdAtUtc" = "",
        "expiresAtUtc" = ""
    };
    var cacheStatus = arguments.useCache ? "miss" : "uncached";
    var result = {};

    if (arguments.useCache) {
        cached = arguments.cache.get(arguments.cacheKey);
        if (cached.hit) {
            result = cached.value;
            cacheStatus = "hit";
            return {
                "provider" = arguments.provider,
                "endpoint" = arguments.endpoint,
                "cacheKey" = arguments.cacheKey,
                "cacheStatus" = cacheStatus,
                "ageSeconds" = cached.ageSeconds,
                "createdAtUtc" = cached.createdAtUtc,
                "expiresAtUtc" = cached.expiresAtUtc,
                "durationMs" = getTickCount() - started,
                "url" = result.url ?: "",
                "statusCode" = result.statusCode ?: "",
                "ok" = structKeyExists(result, "ok") AND result.ok,
                "error" = result.error ?: "",
                "note" = arguments.note,
                "result" = result
            };
        }
    }

    try {
        result = arguments.producer();
    } catch (any err) {
        result = {
            "ok" = false,
            "statusCode" = 0,
            "url" = "",
            "data" = {},
            "error" = err.message
        };
    }

    if (arguments.useCache AND cached.found AND structKeyExists(result, "ok") AND !result.ok) {
        result = cached.value;
        cacheStatus = "stale";
    } else if (arguments.useCache) {
        cacheStatus = cached.found ? "stale-refresh" : "miss";
        arguments.cache.put(arguments.cacheKey, result, (structKeyExists(result, "ok") AND result.ok) ? arguments.ttlSeconds : 45);
    }

    return {
        "provider" = arguments.provider,
        "endpoint" = arguments.endpoint,
        "cacheKey" = arguments.cacheKey,
        "cacheStatus" = cacheStatus,
        "ageSeconds" = (arguments.useCache AND cached.found) ? cached.ageSeconds : javacast("null", ""),
        "createdAtUtc" = (arguments.useCache AND cached.found) ? cached.createdAtUtc : "",
        "expiresAtUtc" = (arguments.useCache AND cached.found) ? cached.expiresAtUtc : "",
        "durationMs" = getTickCount() - started,
        "url" = result.url ?: "",
        "statusCode" = result.statusCode ?: "",
        "ok" = structKeyExists(result, "ok") AND result.ok,
        "error" = result.error ?: "",
        "note" = arguments.note,
        "result" = result
    };
}

targetMode = lCase(readUrlParam("targetMode", "zip"));
if (targetMode NEQ "zip" AND targetMode NEQ "coordinates") {
    targetMode = "zip";
}
zipInput = readUrlParam("zip", "");
latInput = readUrlParam("lat", "");
lonInput = readUrlParam("lon", "");
cacheMode = lCase(readUrlParam("cacheMode", "fresh"));
useCache = (cacheMode EQ "cache");
hasRun = structKeyExists(url, "run");

target = {
    "available" = false,
    "mode" = targetMode,
    "displayName" = "",
    "zip" = "",
    "lat" = javacast("null", ""),
    "lon" = javacast("null", ""),
    "source" = "",
    "sourceLabel" = "",
    "warnings" = []
};
errors = [];
requestRows = [];
requestGeneratedAtUtc = "";
pageWeatherPayload = {};
pageWeatherError = "";
pageWeatherDurationMs = 0;
pageWeatherQueryString = "";
pageWeatherEndpointUrl = "";
pageWeatherStatusCode = "";

if (isAuthorized AND hasRun) {
    if (targetMode EQ "zip") {
        if (!isFiveDigitZip(zipInput)) {
            arrayAppend(errors, "Enter a valid 5-digit ZIP code.");
        } else {
            zipService = createObject("component", "fpw.api.v1.weather.WeatherZipCoordinateService").init();
            zipLookup = zipService.lookup(zipInput);
            target.zip = zipLookup.zip;
            target.displayName = len(zipLookup.displayName) ? zipLookup.displayName : "ZIP area " & zipInput;
            target.source = zipLookup.source ?: "";
            target.sourceLabel = zipLookup.sourceLabel ?: "";
            target.warnings = duplicate(zipLookup.warnings);
            if (zipLookup.found) {
                target.available = true;
                target.lat = zipLookup.lat;
                target.lon = zipLookup.lon;
            } else {
                arrayAppend(errors, len(zipLookup.reason) ? zipLookup.reason : "ZIP was not found in the approved coordinate list.");
            }
        }
    } else {
        if (!isValidCoordinatePair(latInput, lonInput)) {
            arrayAppend(errors, "Enter a valid latitude and longitude.");
        } else {
            target.available = true;
            target.lat = val(latInput);
            target.lon = val(lonInput);
            target.displayName = displayNumber(target.lat) & ", " & displayNumber(target.lon);
            target.source = "manual_coordinates";
            target.sourceLabel = "Manual latitude/longitude";
        }
    }

    if (target.available) {
        requestGeneratedAtUtc = isoUtc(now());
        weatherCache = createObject("component", "fpw.api.v1.weather.WeatherCache").init();
        nws = createObject("component", "fpw.api.v1.weather.WeatherNwsClient").init();
        coops = createObject("component", "fpw.api.v1.weather.WeatherCoopsClient").init();

        pageWeatherStarted = getTickCount();
        try {
            if (targetMode EQ "zip") {
                pageWeatherQueryString = "method=handle&action=pageWeather&zip=" & urlEncodedFormat(target.zip) & (!useCache ? "&cache=0" : "");
            } else {
                pageWeatherQueryString = "method=handle&action=pageWeather&lat=" & urlEncodedFormat(target.lat) & "&lon=" & urlEncodedFormat(target.lon) & (!useCache ? "&cache=0" : "");
            }
            pageWeatherEndpointUrl = (cgi.https EQ "on" ? "https://" : "http://") & cgi.http_host & "/fpw/api/v1/weather.cfc?" & pageWeatherQueryString;
            pageWeatherCookieHeader = "";
            for (cookieName in cookie) {
                if (len(pageWeatherCookieHeader)) {
                    pageWeatherCookieHeader &= "; ";
                }
                pageWeatherCookieHeader &= cookieName & "=" & cookie[cookieName];
            }
            cfhttp(method="GET", url=pageWeatherEndpointUrl, result="pageWeatherHttp", timeout=60) {
                cfhttpparam(type="header", name="Accept", value="application/json");
                if (len(pageWeatherCookieHeader)) {
                    cfhttpparam(type="header", name="Cookie", value=pageWeatherCookieHeader);
                }
            }
            pageWeatherStatusCode = listFirst(pageWeatherHttp.statusCode, " ");
            if (val(pageWeatherStatusCode) GTE 200 AND val(pageWeatherStatusCode) LT 300 AND len(trim(toString(pageWeatherHttp.fileContent)))) {
                pageWeatherPayload = deserializeJSON(pageWeatherHttp.fileContent);
            } else {
                pageWeatherError = "Weather page endpoint returned HTTP " & pageWeatherHttp.statusCode;
                pageWeatherPayload = {
                    "ok" = false,
                    "error" = pageWeatherError,
                    "body" = left(toString(pageWeatherHttp.fileContent), 2000)
                };
            }
        } catch (any pageErr) {
            pageWeatherError = pageErr.message;
            pageWeatherPayload = {
                "ok" = false,
                "error" = pageErr.message,
                "detail" = pageErr.detail ?: ""
            };
        }
        pageWeatherDurationMs = getTickCount() - pageWeatherStarted;

        pointRequest = requestResult("NOAA/NWS", "Point metadata", "nws:point:" & target.lat & "," & target.lon, 86400, useCache, weatherCache, function() {
            return nws.getPoint(target.lat, target.lon);
        });
        arrayAppend(requestRows, pointRequest);

        point = {};
        pointProps = {};
        if (pointRequest.ok) {
            point = nws.normalizePoint(pointRequest.result.data);
            pointProps = pointRequest.result.data.properties ?: {};
        }

        if (structKeyExists(point, "forecastHourlyUrl") AND len(point.forecastHourlyUrl)) {
            arrayAppend(requestRows, requestResult("NOAA/NWS", "Hourly forecast", "nws:hourly:" & point.forecastHourlyUrl, 900, useCache, weatherCache, function() {
                return nws.getHourlyForecast(point.forecastHourlyUrl);
            }));
        }

        stationIds = [];
        if (structKeyExists(point, "observationStationsUrl") AND len(point.observationStationsUrl)) {
            stationsRequest = requestResult("NOAA/NWS", "Observation stations", "nws:stations:" & point.observationStationsUrl, 21600, useCache, weatherCache, function() {
                return nws.getObservationStations(point.observationStationsUrl);
            });
            arrayAppend(requestRows, stationsRequest);
            if (stationsRequest.ok) {
                stationIds = nws.stationIds(stationsRequest.result.data, 4);
            }
        }

        for (stationId in stationIds) {
            arrayAppend(requestRows, requestResult("NOAA/NWS", "Latest observation " & stationId, "nws:observation:" & stationId, 300, useCache, weatherCache, function() {
                return nws.getLatestObservation(stationId);
            }));
        }

        arrayAppend(requestRows, requestResult("NOAA/NWS", "Active alerts", "nws:alerts:" & target.lat & "," & target.lon, 180, useCache, weatherCache, function() {
            return nws.getActiveAlerts(target.lat, target.lon);
        }));

        marineZonesRequest = requestResult("NOAA/NWS", "Marine zones", "nws:marine-zones:" & target.lat & "," & target.lon, 21600, useCache, weatherCache, function() {
            return nws.getMarineZones(target.lat, target.lon);
        });
        arrayAppend(requestRows, marineZonesRequest);

        officeCode = point.office ?: (pointProps.cwa ?: "");
        marineFeatures = marineZonesRequest.ok ? (marineZonesRequest.result.data.features ?: []) : [];
        if ((!isArray(marineFeatures) OR arrayLen(marineFeatures) EQ 0) AND len(officeCode)) {
            arrayAppend(requestRows, requestResult("NOAA/NWS", "Nearest marine zone", "nws:nearest-marine-zone:" & officeCode & ":" & target.lat & "," & target.lon, 21600, useCache, weatherCache, function() {
                return nws.getNearestMarineZone(target.lat, target.lon, officeCode);
            }));
        }

        if (len(officeCode)) {
            arrayAppend(requestRows, requestResult("NOAA/NWS", "Coastal Waters Forecast product", "nws:cwf:" & officeCode, 1800, useCache, weatherCache, function() {
                return nws.getCwfProduct(officeCode);
            }));
        }

        tideStationRequest = requestResult("NOAA CO-OPS", "Tide prediction stations", "coops:stations:tidepredictions", 86400, useCache, weatherCache, function() {
            return coops.fetchStations("tidepredictions");
        });
        arrayAppend(requestRows, tideStationRequest);
        tideStation = tideStationRequest.ok ? nearestCoopsStationFromPayload(tideStationRequest.result.data, target.lat, target.lon) : { "available" = false, "reason" = tideStationRequest.error };
        if (tideStation.available AND len(tideStation.id)) {
            arrayAppend(requestRows, requestResult("NOAA CO-OPS", "Tide predictions " & tideStation.name & " (" & tideStation.id & ")", "coops:predictions:v2:" & tideStation.id & ":" & dateFormat(now(), "yyyymmdd"), 900, useCache, weatherCache, function() {
                return coops.fetchPredictions(tideStation.id);
            }, "Nearest station: " & tideStation.name & " (" & tideStation.id & "), " & tideStation.distanceMiles & " mi"));
        }

        waterStationRequest = requestResult("NOAA CO-OPS", "Water level stations", "coops:stations:waterlevels", 86400, useCache, weatherCache, function() {
            return coops.fetchStations("waterlevels");
        });
        arrayAppend(requestRows, waterStationRequest);
        waterStation = waterStationRequest.ok ? nearestCoopsStationFromPayload(waterStationRequest.result.data, target.lat, target.lon) : { "available" = false, "reason" = waterStationRequest.error };
        if (waterStation.available AND len(waterStation.id)) {
            arrayAppend(requestRows, requestResult("NOAA CO-OPS", "Latest water level " & waterStation.name & " (" & waterStation.id & ")", "coops:waterlevel:" & waterStation.id, 300, useCache, weatherCache, function() {
                return coops.fetchWaterLevel(waterStation.id);
            }, "Nearest station: " & waterStation.name & " (" & waterStation.id & "), " & waterStation.distanceMiles & " mi"));
        }
    }
}
</cfscript>
<cfinclude template="../includes/fpw_base_path.cfm">

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Raw NOAA Weather Admin</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 24px; background: #f7f7f7; color: #111; }
    .wrap { max-width: 1600px; margin: 0 auto; background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 20px; }
    h1 { margin-top: 0; font-size: 24px; }
    h2 { font-size: 19px; margin: 24px 0 10px; }
    h3 { font-size: 16px; margin: 0; }
    .hint { color: #444; margin-bottom: 16px; }
    .msg { margin-bottom: 12px; padding: 10px; border-radius: 4px; }
    .msg.info { background: #edf2ff; border: 1px solid #b6c6ff; color: #13255a; }
    .msg.error { background: #ffecec; border: 1px solid #ffb4b4; color: #7f1d1d; }
    .toolbar { display: grid; gap: 12px; grid-template-columns: 180px 180px 180px 180px 220px auto; align-items: end; margin-bottom: 14px; }
    .field { display: flex; flex-direction: column; gap: 6px; }
    .field label { font-size: 13px; font-weight: 700; color: #222; }
    .field input, .field select {
      border: 1px solid #bbb;
      border-radius: 4px;
      font-size: 14px;
      padding: 8px;
      background: #fff;
      color: #111;
    }
    button {
      padding: 9px 14px;
      border-radius: 4px;
      border: 1px solid #111;
      background: #111;
      color: #fff;
      cursor: pointer;
      font-size: 14px;
      font-weight: 700;
    }
    .summary-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 10px; margin: 16px 0; }
    .summary-card { border: 1px solid #ddd; border-radius: 6px; background: #fafafa; padding: 10px; }
    .summary-card .label { color: #555; font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.06em; }
    .summary-card .value { margin-top: 4px; font-size: 15px; font-weight: 700; word-break: break-word; }
    .warnings { margin: 10px 0; padding: 10px 12px; background: #fff7ed; border: 1px solid #fed7aa; border-radius: 6px; color: #7c2d12; }
    .admin-section {
      margin-top: 18px;
      border: 1px solid #ddd;
      border-radius: 8px;
      background: #fff;
      overflow: hidden;
    }
    .admin-section-summary {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 14px;
      padding: 12px;
      background: #f8fafc;
      border-bottom: 1px solid #ddd;
      cursor: pointer;
      list-style: none;
    }
    .admin-section-summary::-webkit-details-marker { display: none; }
    .admin-section-title { font-size: 19px; font-weight: 700; color: #111; }
    .admin-section-toggle {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      min-width: 76px;
      border: 1px solid #c8d0db;
      border-radius: 999px;
      background: #fff;
      color: #1f2937;
      padding: 4px 10px;
      font-size: 12px;
      font-weight: 700;
    }
    .admin-section-toggle::after { content: "Open"; }
    .admin-section[open] > .admin-section-summary .admin-section-toggle::after { content: "Close"; }
    .admin-section-body { padding: 12px; }
    .admin-section-body > .summary-grid { margin-top: 0; }
    .admin-section-body > .response-card:first-child { margin-top: 0; }
    .table-scroll { overflow-x: auto; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    th, td { border: 1px solid #ddd; padding: 7px; text-align: left; vertical-align: top; }
    th { background: #f0f0f0; }
    td.num { text-align: right; font-family: Consolas, Menlo, Monaco, monospace; white-space: nowrap; }
    td.url { max-width: 520px; word-break: break-all; }
    .badge { display: inline-block; border: 1px solid #c8d0db; border-radius: 999px; padding: 2px 8px; background: #f8fafc; font-size: 12px; font-weight: 700; }
    .badge.ok { background: #e9f8ee; border-color: #9dd9ad; color: #0e5522; }
    .badge.warn { background: #fff7ed; border-color: #fed7aa; color: #9a3412; }
    .badge.cache { background: #edf2ff; border-color: #b6c6ff; color: #13255a; }
    .response-card { margin-top: 16px; border: 1px solid #ddd; border-radius: 8px; background: #fff; overflow: hidden; }
    .response-card header { display: flex; justify-content: space-between; gap: 12px; align-items: flex-start; padding: 12px; background: #f8fafc; border-bottom: 1px solid #ddd; }
    .response-meta { color: #555; font-size: 12px; margin-top: 4px; word-break: break-all; }
    .response-body { padding: 12px; }
    .raw-table { width: 100%; border-collapse: collapse; }
    .raw-table th { width: 220px; color: #1f2937; background: #f8fafc; }
    .raw-table-nested { margin: 0; font-size: 12px; }
    .raw-table-nested th, .raw-table-nested td { border-color: #e5e7eb; }
    details { margin-top: 12px; }
    summary { cursor: pointer; font-weight: 700; }
    pre {
      margin-top: 10px;
      background: #111;
      color: #f4f4f4;
      padding: 12px;
      border-radius: 6px;
      overflow: auto;
      font-size: 12px;
      line-height: 1.45;
      max-height: 520px;
    }
    .muted { color: #777; font-style: italic; }
    @media (max-width: 1200px) {
      .toolbar, .summary-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    }
    @media (max-width: 768px) {
      body { margin: 12px; }
      .wrap { padding: 14px; }
      .toolbar, .summary-grid { grid-template-columns: 1fr; }
      .response-card header { display: block; }
      .admin-section-summary { align-items: flex-start; }
    }
  </style>
</head>
<body>
  <div class="wrap">
    <cfinclude template="includes/admin_reports_nav.cfm">

    <h1>Raw NOAA Weather Inspector</h1>
    <p class="hint">Admin-only utility for viewing raw NOAA/NWS and NOAA CO-OPS responses used by the FPW Weather page.</p>

    <cfif NOT isAuthorized>
      <div class="msg error">
        <strong>Unauthorized:</strong> Admin login is required.
      </div>
    <cfelse>
      <form method="get" action="<cfoutput>#encodeForHtmlAttribute(request.fpwBase)#</cfoutput>/admin/raw-weather.cfm">
        <input type="hidden" name="run" value="1">
        <div class="toolbar">
          <div class="field">
            <label for="targetMode">Target mode</label>
            <select id="targetMode" name="targetMode">
              <option value="zip"<cfif targetMode EQ "zip"> selected</cfif>>ZIP code</option>
              <option value="coordinates"<cfif targetMode EQ "coordinates"> selected</cfif>>Latitude / longitude</option>
            </select>
          </div>
          <div class="field">
            <label for="zip">ZIP code</label>
            <input id="zip" name="zip" type="text" inputmode="numeric" maxlength="5" value="<cfoutput>#encodeForHtmlAttribute(zipInput)#</cfoutput>" placeholder="34652">
          </div>
          <div class="field">
            <label for="lat">Latitude</label>
            <input id="lat" name="lat" type="text" value="<cfoutput>#encodeForHtmlAttribute(latInput)#</cfoutput>" placeholder="28.240555">
          </div>
          <div class="field">
            <label for="lon">Longitude</label>
            <input id="lon" name="lon" type="text" value="<cfoutput>#encodeForHtmlAttribute(lonInput)#</cfoutput>" placeholder="-82.744353">
          </div>
          <div class="field">
            <label for="cacheMode">Cache mode</label>
            <select id="cacheMode" name="cacheMode">
              <option value="fresh"<cfif NOT useCache> selected</cfif>>Fresh NOAA request</option>
              <option value="cache"<cfif useCache> selected</cfif>>Use FPW weather cache</option>
            </select>
          </div>
          <div class="field">
            <button type="submit">Run NOAA Inspection</button>
          </div>
        </div>
      </form>

      <cfif arrayLen(errors)>
        <div class="msg error">
          <strong>Unable to run request:</strong>
          <ul>
            <cfloop array="#errors#" index="errorMessage">
              <cfoutput><li>#encodeForHtml(errorMessage)#</li></cfoutput>
            </cfloop>
          </ul>
        </div>
      <cfelseif NOT hasRun>
        <div class="msg info">
          Enter a ZIP code or coordinates, then choose whether the inspector should bypass or use the FPW weather cache.
        </div>
      </cfif>

      <cfif hasRun AND target.available>
        <details class="admin-section">
          <summary class="admin-section-summary">
            <span class="admin-section-title">Target Summary</span>
            <span class="admin-section-toggle" aria-hidden="true"></span>
          </summary>
          <div class="admin-section-body">
            <div class="summary-grid">
              <div class="summary-card">
                <div class="label">Input mode</div>
                <div class="value"><cfoutput>#encodeForHtml(target.mode)#</cfoutput></div>
              </div>
              <div class="summary-card">
                <div class="label">Display name</div>
                <div class="value"><cfoutput>#encodeForHtml(target.displayName)#</cfoutput></div>
              </div>
              <div class="summary-card">
                <div class="label">Coordinates</div>
                <div class="value"><cfoutput>#encodeForHtml(displayNumber(target.lat))#, #encodeForHtml(displayNumber(target.lon))#</cfoutput></div>
              </div>
              <div class="summary-card">
                <div class="label">Cache mode</div>
                <div class="value"><cfoutput>#useCache ? "Use FPW weather cache" : "Fresh NOAA request"#</cfoutput></div>
              </div>
              <div class="summary-card">
                <div class="label">ZIP</div>
                <div class="value"><cfoutput>#len(target.zip) ? encodeForHtml(target.zip) : "&mdash;"#</cfoutput></div>
              </div>
              <div class="summary-card">
                <div class="label">ZIP source</div>
                <div class="value"><cfoutput>#len(target.sourceLabel) ? encodeForHtml(target.sourceLabel) : encodeForHtml(target.source)#</cfoutput></div>
              </div>
              <div class="summary-card">
                <div class="label">Generated</div>
                <div class="value"><cfoutput>#encodeForHtml(requestGeneratedAtUtc)#</cfoutput></div>
              </div>
              <div class="summary-card">
                <div class="label">Provider requests</div>
                <div class="value"><cfoutput>#arrayLen(requestRows)#</cfoutput></div>
              </div>
            </div>

            <cfif arrayLen(target.warnings)>
              <div class="warnings">
                <strong>Target warnings</strong>
                <ul>
                  <cfloop array="#target.warnings#" index="targetWarning">
                    <cfoutput><li>#encodeForHtml(targetWarning)#</li></cfoutput>
                  </cfloop>
                </ul>
              </div>
            </cfif>
          </div>
        </details>

        <details class="admin-section">
          <summary class="admin-section-summary">
            <span class="admin-section-title">Weather Page Payload</span>
            <span class="admin-section-toggle" aria-hidden="true"></span>
          </summary>
          <div class="admin-section-body">
            <article class="response-card">
              <header>
                <div>
                  <h3>Normalized ViewModel returned by the Weather page endpoint</h3>
                  <div class="response-meta">
                    <cfoutput>#encodeForHtml(pageWeatherEndpointUrl)#</cfoutput>
                  </div>
                </div>
                <div>
                  <span class="badge <cfif structKeyExists(pageWeatherPayload, "ok") AND pageWeatherPayload.ok>ok<cfelse>warn</cfif>"><cfoutput>#(structKeyExists(pageWeatherPayload, "ok") AND pageWeatherPayload.ok) ? "OK" : "Review"#</cfoutput></span>
                  <span class="badge cache"><cfoutput>#useCache ? "cache enabled" : "cache bypass"#</cfoutput></span>
                </div>
              </header>
              <div class="response-body">
                <div class="table-scroll">
                  <table>
                    <tbody>
                      <tr>
                        <th>Endpoint called</th>
                        <td><cfoutput>#encodeForHtml(pageWeatherEndpointUrl)#</cfoutput></td>
                      </tr>
                      <tr>
                        <th>HTTP status</th>
                        <td><cfoutput>#encodeForHtml(pageWeatherStatusCode)#</cfoutput></td>
                      </tr>
                      <tr>
                        <th>Request mode</th>
                        <td><cfoutput>#encodeForHtml(targetMode)#</cfoutput></td>
                      </tr>
                      <tr>
                        <th>Cache mode</th>
                        <td><cfoutput>#useCache ? "Use FPW weather cache" : "Fresh NOAA request / cache bypass"#</cfoutput></td>
                      </tr>
                      <tr>
                        <th>Duration</th>
                        <td><cfoutput>#encodeForHtml(pageWeatherDurationMs)# ms</cfoutput></td>
                      </tr>
                      <tr>
                        <th>Payload ok</th>
                        <td><cfoutput>#(structKeyExists(pageWeatherPayload, "ok") AND pageWeatherPayload.ok) ? "true" : "false"#</cfoutput></td>
                      </tr>
                      <tr>
                        <th>Cache summary</th>
                        <td><cfoutput>#structKeyExists(pageWeatherPayload, "cache") AND isStruct(pageWeatherPayload.cache) ? encodeForHtml(pageWeatherPayload.cache.summary ?: "") : ""#</cfoutput></td>
                      </tr>
                      <cfif len(pageWeatherError)>
                        <tr>
                          <th>Error</th>
                          <td><cfoutput>#encodeForHtml(pageWeatherError)#</cfoutput></td>
                        </tr>
                      </cfif>
                    </tbody>
                  </table>
                </div>
                <details open>
                  <summary>Normalized Weather page payload table</summary>
                  <div class="table-scroll">
                    <cfoutput>#renderRawValue(pageWeatherPayload)#</cfoutput>
                  </div>
                </details>
                <details>
                  <summary>Normalized Weather page payload JSON</summary>
                  <pre><cfoutput>#encodeForHtml(serializeJSON(pageWeatherPayload))#</cfoutput></pre>
                </details>
              </div>
            </article>
          </div>
        </details>

        <details class="admin-section">
          <summary class="admin-section-summary">
            <span class="admin-section-title">Request Summary</span>
            <span class="admin-section-toggle" aria-hidden="true"></span>
          </summary>
          <div class="admin-section-body">
            <div class="table-scroll">
              <table>
                <thead>
                  <tr>
                    <th>Provider</th>
                    <th>Endpoint</th>
                    <th>Status</th>
                    <th>Cache</th>
                    <th>Duration</th>
                    <th>URL</th>
                    <th>Error / note</th>
                  </tr>
                </thead>
                <tbody>
                  <cfloop array="#requestRows#" index="requestItem">
                    <tr>
                      <td><cfoutput>#encodeForHtml(requestItem.provider)#</cfoutput></td>
                      <td><cfoutput>#encodeForHtml(requestItem.endpoint)#</cfoutput></td>
                      <td>
                        <cfif requestItem.ok>
                          <span class="badge ok"><cfoutput>#encodeForHtml(requestItem.statusCode)# OK</cfoutput></span>
                        <cfelse>
                          <span class="badge warn"><cfoutput>#encodeForHtml(requestItem.statusCode)#</cfoutput></span>
                        </cfif>
                      </td>
                      <td><span class="badge cache"><cfoutput>#encodeForHtml(requestItem.cacheStatus)#</cfoutput></span></td>
                      <td class="num"><cfoutput>#encodeForHtml(requestItem.durationMs)# ms</cfoutput></td>
                      <td class="url"><cfoutput>#encodeForHtml(requestItem.url)#</cfoutput></td>
                      <td><cfoutput>#encodeForHtml(trim((requestItem.error ?: "") & (len(requestItem.note ?: "") ? " " & requestItem.note : "")))#</cfoutput></td>
                    </tr>
                  </cfloop>
                </tbody>
              </table>
            </div>
          </div>
        </details>

        <details class="admin-section">
          <summary class="admin-section-summary">
            <span class="admin-section-title">Raw Provider Payloads</span>
            <span class="admin-section-toggle" aria-hidden="true"></span>
          </summary>
          <div class="admin-section-body">
            <cfloop array="#requestRows#" index="requestItem">
              <article class="response-card">
                <header>
                  <div>
                    <h3><cfoutput>#encodeForHtml(requestItem.provider)# - #encodeForHtml(requestItem.endpoint)#</cfoutput></h3>
                    <div class="response-meta">
                      <cfoutput>#encodeForHtml(requestItem.url)#</cfoutput>
                    </div>
                  </div>
                  <div>
                    <span class="badge <cfif requestItem.ok>ok<cfelse>warn</cfif>"><cfoutput>#requestItem.ok ? "OK" : "Review"#</cfoutput></span>
                    <span class="badge cache"><cfoutput>#encodeForHtml(requestItem.cacheStatus)#</cfoutput></span>
                  </div>
                </header>
                <div class="response-body">
                  <div class="table-scroll">
                    <cfoutput>#renderRawValue(requestItem.result)#</cfoutput>
                  </div>
                  <details>
                    <summary>Raw provider payload JSON</summary>
                    <pre><cfoutput>#encodeForHtml(serializeJSON(requestItem.result.data ?: {}))#</cfoutput></pre>
                  </details>
                </div>
              </article>
            </cfloop>
          </div>
        </details>
      </cfif>
    </cfif>
  </div>
</body>
</html>

