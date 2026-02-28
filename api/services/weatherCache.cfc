<cfcomponent output="false" singleton="true" hint="Shared NOAA/NWS cache service for forecast, alerts, marine, and METAR payloads.">

    <cffunction name="init" access="public" returntype="any" output="false">
        <cfargument name="userAgent" type="string" required="false" default="">
        <cfargument name="httpTimeout" type="numeric" required="false" default="15">
        <cfscript>
            variables.userAgent = trim(toString(arguments.userAgent));
            if (!len(variables.userAgent)) {
                variables.userAgent = "FloatPlanWizard Weather (V1) (admin@floatplanwizard.com)";
            }
            variables.httpTimeout = val(arguments.httpTimeout);
            if (variables.httpTimeout LT 2) variables.httpTimeout = 2;
            if (variables.httpTimeout GT 30) variables.httpTimeout = 30;
            return this;
        </cfscript>
    </cffunction>

    <cffunction name="getForecast" access="public" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfargument name="forecastHour" type="date" required="true">
        <cfscript>
            var latVal = normalizeCoord(arguments.lat);
            var lngVal = normalizeCoord(arguments.lng);
            var hourBucket = floorToHour(arguments.forecastHour);
            var cacheKey = buildForecastKey(latVal, lngVal, hourBucket);
            var ttlSeconds = ttlSecondsForHour(hourBucket);
            var cached = appCacheGet(cacheKey, ttlSeconds);
            var out = {};
            if (!isNull(cached) AND isStruct(cached)) {
                out = duplicate(cached);
                out.cache_hit = true;
                out.cache_key = cacheKey;
                return out;
            }
            out = fetchForecastPayload(latVal, lngVal);
            out.cache_hit = false;
            out.cache_key = cacheKey;
            appCacheSet(cacheKey, out);
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getAlerts" access="public" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfscript>
            var latVal = normalizeCoord(arguments.lat);
            var lngVal = normalizeCoord(arguments.lng);
            var hourBucket = floorToHour(now());
            var cacheKey = buildAlertsKey(latVal, lngVal, hourBucket);
            var ttlSeconds = ttlSecondsForHour(hourBucket);
            var cached = appCacheGet(cacheKey, ttlSeconds);
            var out = {};
            if (!isNull(cached) AND isStruct(cached)) {
                out = duplicate(cached);
                out.cache_hit = true;
                out.cache_key = cacheKey;
                return out;
            }
            out = fetchAlertsPayload(latVal, lngVal);
            out.cache_hit = false;
            out.cache_key = cacheKey;
            appCacheSet(cacheKey, out);
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getMarine" access="public" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfargument name="forecastHour" type="date" required="true">
        <cfscript>
            var latVal = normalizeCoord(arguments.lat);
            var lngVal = normalizeCoord(arguments.lng);
            var hourBucket = floorToHour(arguments.forecastHour);
            var cacheKey = buildMarineKey(latVal, lngVal, hourBucket);
            var ttlSeconds = ttlSecondsForHour(hourBucket);
            var cached = appCacheGet(cacheKey, ttlSeconds);
            var out = {};
            if (!isNull(cached) AND isStruct(cached)) {
                out = duplicate(cached);
                out.cache_hit = true;
                out.cache_key = cacheKey;
                return out;
            }
            out = fetchForecastPayload(latVal, lngVal);
            out.cache_hit = false;
            out.cache_key = cacheKey;
            appCacheSet(cacheKey, out);
            return out;
        </cfscript>
    </cffunction>

    <!--- METAR surface-observation cache block (15 minute TTL, rounded lat/lng key). --->
    <cffunction name="getMetar" access="public" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfscript>
            var latVal = normalizeCoord(arguments.lat);
            var lngVal = normalizeCoord(arguments.lng);
            var cacheKey = buildMetarKey(latVal, lngVal);
            var ttlSeconds = 900;
            var cached = {};
            var priorCacheVal = {};
            var fetched = {};
            var currentRec = {};
            var previousRec = {};
            var cachePayload = {};
            var out = {};

            local.cachedRaw = appCacheGet(cacheKey, ttlSeconds);
            if (structKeyExists(local, "cachedRaw") AND isStruct(local.cachedRaw)) {
                cached = local.cachedRaw;
            }
            local.priorRaw = appCachePeek(cacheKey);
            if (structKeyExists(local, "priorRaw") AND isStruct(local.priorRaw)) {
                priorCacheVal = local.priorRaw;
            }

            if (structCount(cached) GT 0) {
                out = composeMetarEnvelope(cached, true, cacheKey);
                return out;
            }

            fetched = fetchMetarPayload(latVal, lngVal);
            if (isStruct(fetched) AND structKeyExists(fetched, "success") AND fetched.success) {
                currentRec = extractMetarRecord(fetched);
                previousRec = extractMetarRecord(priorCacheVal);

                if (
                    isStruct(previousRec)
                    AND isStruct(currentRec)
                    AND structKeyExists(previousRec, "observation_time")
                    AND structKeyExists(currentRec, "observation_time")
                    AND trim(toString(previousRec.observation_time)) EQ trim(toString(currentRec.observation_time))
                ) {
                    previousRec = {};
                }

                cachePayload = {
                    "success"=true,
                    "source"="METAR",
                    "current"=currentRec,
                    "previous"=previousRec
                };
                appCacheSet(cacheKey, cachePayload);
                out = composeMetarEnvelope(cachePayload, false, cacheKey);
                return out;
            }

            if (structCount(priorCacheVal) GT 0) {
                out = composeMetarEnvelope(priorCacheVal, true, cacheKey);
                if ((!structKeyExists(out, "success") OR !out.success) AND isStruct(fetched)) {
                    if (structKeyExists(fetched, "note")) out.note = toString(fetched.note);
                    if (structKeyExists(fetched, "status")) out.status = val(fetched.status);
                    if (structKeyExists(fetched, "url")) out.url = toString(fetched.url);
                }
                return out;
            }

            out = composeMetarEnvelope(fetched, false, cacheKey);
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="fetchForecastPayload" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfscript>
            var out = {
                "success"=false,
                "source"="NWS",
                "step"="points",
                "note"="",
                "points_url"="",
                "forecast_url"="",
                "grid_url"="",
                "points_status"=0,
                "forecast_status"=0,
                "grid_status"=0,
                "points_body"="",
                "forecast_body"="",
                "grid_body"=""
            };
            var pointsRes = {};
            var pointsObj = {};
            var forecastRes = {};
            var gridRes = {};

            out.points_url = "https://api.weather.gov/points/" & arguments.lat & "," & arguments.lng;
            pointsRes = fetchHttp(out.points_url, "application/geo+json");
            out.points_status = val(pointsRes.status);
            out.points_body = toString(pointsRes.body);
            if (out.points_status LT 200 OR out.points_status GTE 300) {
                return out;
            }

            try {
                pointsObj = deserializeJSON(out.points_body, false, false, true);
            } catch (any ePointsJson) {
                out.note = "Invalid JSON";
                return out;
            }

            if (
                isStruct(pointsObj)
                AND structKeyExists(pointsObj, "properties")
                AND isStruct(pointsObj.properties)
                AND structKeyExists(pointsObj.properties, "forecastHourly")
                AND len(trim(toString(pointsObj.properties.forecastHourly)))
            ) {
                out.forecast_url = trim(toString(pointsObj.properties.forecastHourly));
            } else if (
                isStruct(pointsObj)
                AND structKeyExists(pointsObj, "properties")
                AND isStruct(pointsObj.properties)
                AND structKeyExists(pointsObj.properties, "forecast")
                AND len(trim(toString(pointsObj.properties.forecast)))
            ) {
                out.forecast_url = trim(toString(pointsObj.properties.forecast));
            }

            if (
                isStruct(pointsObj)
                AND structKeyExists(pointsObj, "properties")
                AND isStruct(pointsObj.properties)
                AND structKeyExists(pointsObj.properties, "forecastGridData")
                AND len(trim(toString(pointsObj.properties.forecastGridData)))
            ) {
                out.grid_url = trim(toString(pointsObj.properties.forecastGridData));
            }

            if (!len(out.forecast_url)) {
                out.note = "No forecast URL";
                return out;
            }

            out.step = "forecast";
            forecastRes = fetchHttp(out.forecast_url, "application/geo+json");
            out.forecast_status = val(forecastRes.status);
            out.forecast_body = toString(forecastRes.body);
            if (out.forecast_status LT 200 OR out.forecast_status GTE 300) {
                return out;
            }

            if (len(out.grid_url)) {
                out.step = "forecastGridData";
                gridRes = fetchHttp(out.grid_url, "application/geo+json");
                out.grid_status = val(gridRes.status);
                out.grid_body = toString(gridRes.body);
                if (out.grid_status LT 200 OR out.grid_status GTE 300) {
                    out.note = "Grid request failed";
                }
            }

            out.step = "forecast";
            out.success = true;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="fetchAlertsPayload" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfscript>
            var out = {
                "success"=false,
                "source"="NWS",
                "url"="",
                "status"=0,
                "body"="",
                "note"=""
            };
            var res = {};
            out.url = "https://api.weather.gov/alerts/active?point=" & arguments.lat & "," & arguments.lng;
            res = fetchHttp(out.url, "application/geo+json");
            out.status = val(res.status);
            out.body = toString(res.body);
            if (out.status GTE 200 AND out.status LT 300) {
                out.success = true;
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="fetchMetarPayload" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfscript>
            var out = {
                "success"=false,
                "source"="METAR",
                "url"="",
                "status"=0,
                "body"="",
                "note"="",
                "station"="",
                "altim"="",
                "visib"="",
                "observation_time"=""
            };
            var res = {};
            var parsed = {};
            var minLat = arguments.lat - 0.35;
            var minLng = arguments.lng - 0.35;
            var maxLat = arguments.lat + 0.35;
            var maxLng = arguments.lng + 0.35;
            out.url = "https://aviationweather.gov/api/data/metar?bbox="
                & numberFormat(minLat, "0.0000")
                & ","
                & numberFormat(minLng, "0.0000")
                & ","
                & numberFormat(maxLat, "0.0000")
                & ","
                & numberFormat(maxLng, "0.0000")
                & "&zoom=8&density=1&format=json&hours=1";
            res = fetchHttp(out.url, "application/json");
            out.status = val(res.status);
            out.body = toString(res.body);
            if (out.status GTE 200 AND out.status LT 300) {
                parsed = parseMetarPayload(out.body);
                if (isStruct(parsed)) {
                    if (structKeyExists(parsed, "success")) out.success = parsed.success;
                    if (structKeyExists(parsed, "note")) out.note = toString(parsed.note);
                    if (structKeyExists(parsed, "station")) out.station = toString(parsed.station);
                    if (structKeyExists(parsed, "altim")) out.altim = toString(parsed.altim);
                    if (structKeyExists(parsed, "visib")) out.visib = toString(parsed.visib);
                    if (structKeyExists(parsed, "observation_time")) out.observation_time = toString(parsed.observation_time);
                }
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="parseMetarPayload" access="private" returntype="struct" output="false">
        <cfargument name="body" type="string" required="true">
        <cfscript>
            var out = {
                "success"=false,
                "note"="",
                "station"="",
                "altim"="",
                "visib"="",
                "observation_time"=""
            };
            var obj = javacast("null", "");
            var row = {};
            if (!len(trim(arguments.body))) {
                out.note = "Empty response";
                return out;
            }
            try {
                obj = deserializeJSON(arguments.body, false, false, true);
            } catch (any eJson) {
                out.note = "Invalid JSON";
                return out;
            }
            if (isArray(obj) AND arrayLen(obj) GT 0 AND isStruct(obj[1])) {
                row = obj[1];
            } else if (isStruct(obj) AND structKeyExists(obj, "data") AND isArray(obj.data) AND arrayLen(obj.data) GT 0 AND isStruct(obj.data[1])) {
                row = obj.data[1];
            } else {
                out.note = "No METAR rows";
                return out;
            }

            if (structKeyExists(row, "station") AND len(trim(toString(row.station)))) {
                out.station = trim(toString(row.station));
            } else if (structKeyExists(row, "station_id") AND len(trim(toString(row.station_id)))) {
                out.station = trim(toString(row.station_id));
            } else if (structKeyExists(row, "stationId") AND len(trim(toString(row.stationId)))) {
                out.station = trim(toString(row.stationId));
            } else if (structKeyExists(row, "icaoId") AND len(trim(toString(row.icaoId)))) {
                out.station = trim(toString(row.icaoId));
            }

            if (structKeyExists(row, "altim") AND len(trim(toString(row.altim)))) {
                out.altim = trim(toString(row.altim));
            } else if (structKeyExists(row, "altimeter") AND len(trim(toString(row.altimeter)))) {
                out.altim = trim(toString(row.altimeter));
            }
            if (len(out.altim) AND isNumeric(out.altim)) {
                var altimVal = val(out.altim);
                if (altimVal GT 200) {
                    altimVal = altimVal * 0.0295299830714;
                }
                out.altim = numberFormat(altimVal, "0.00");
            }

            if (structKeyExists(row, "visib") AND len(trim(toString(row.visib)))) {
                out.visib = trim(toString(row.visib));
            } else if (structKeyExists(row, "visibility") AND len(trim(toString(row.visibility)))) {
                out.visib = trim(toString(row.visibility));
            }

            if (structKeyExists(row, "observation_time") AND len(trim(toString(row.observation_time)))) {
                out.observation_time = trim(toString(row.observation_time));
            } else if (structKeyExists(row, "observationTime") AND len(trim(toString(row.observationTime)))) {
                out.observation_time = trim(toString(row.observationTime));
            } else if (structKeyExists(row, "reportTime") AND len(trim(toString(row.reportTime)))) {
                out.observation_time = trim(toString(row.reportTime));
            } else if (structKeyExists(row, "obsTime") AND len(trim(toString(row.obsTime)))) {
                out.observation_time = trim(toString(row.obsTime));
            }

            out.success = (len(out.station) OR len(out.altim) OR len(out.visib) OR len(out.observation_time));
            if (!out.success AND !len(out.note)) {
                out.note = "METAR fields unavailable";
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="extractMetarRecord" access="private" returntype="any" output="false">
        <cfargument name="src" type="any" required="true">
        <cfscript>
            var rec = {};
            var currentSrc = {};
            if (isNull(arguments.src) OR !isStruct(arguments.src)) {
                return {};
            }

            if (structKeyExists(arguments.src, "current") AND isStruct(arguments.src.current)) {
                currentSrc = arguments.src.current;
            } else {
                currentSrc = arguments.src;
            }

            if (structKeyExists(currentSrc, "station")) rec.station = trim(toString(currentSrc.station));
            if (structKeyExists(currentSrc, "altim")) rec.altim = trim(toString(currentSrc.altim));
            if (structKeyExists(currentSrc, "visib")) rec.visib = trim(toString(currentSrc.visib));
            if (structKeyExists(currentSrc, "observation_time")) rec.observation_time = trim(toString(currentSrc.observation_time));

            if (
                !structKeyExists(rec, "station")
                AND !structKeyExists(rec, "altim")
                AND !structKeyExists(rec, "visib")
                AND !structKeyExists(rec, "observation_time")
            ) {
                return {};
            }
            return rec;
        </cfscript>
    </cffunction>

    <cffunction name="composeMetarEnvelope" access="private" returntype="struct" output="false">
        <cfargument name="src" type="any" required="true">
        <cfargument name="cacheHit" type="boolean" required="true">
        <cfargument name="cacheKey" type="string" required="true">
        <cfscript>
            var out = {
                "success"=false,
                "source"="METAR",
                "url"="",
                "status"=0,
                "body"="",
                "note"="",
                "station"="",
                "altim"="",
                "visib"="",
                "observation_time"="",
                "current"={},
                "previous"={},
                "cache_hit"=arguments.cacheHit,
                "cache_key"=arguments.cacheKey
            };
            var currentRec = {};
            var previousRec = {};
            if (isStruct(arguments.src)) {
                if (structKeyExists(arguments.src, "source")) out.source = toString(arguments.src.source);
                if (structKeyExists(arguments.src, "url")) out.url = toString(arguments.src.url);
                if (structKeyExists(arguments.src, "status")) out.status = val(arguments.src.status);
                if (structKeyExists(arguments.src, "body")) out.body = toString(arguments.src.body);
                if (structKeyExists(arguments.src, "note")) out.note = toString(arguments.src.note);
                if (structKeyExists(arguments.src, "success")) out.success = (arguments.src.success ? true : false);

                currentRec = extractMetarRecord(arguments.src);
                if (isStruct(currentRec) AND structCount(currentRec) GT 0) {
                    out.current = currentRec;
                    if (structKeyExists(currentRec, "station")) out.station = currentRec.station;
                    if (structKeyExists(currentRec, "altim")) out.altim = currentRec.altim;
                    if (structKeyExists(currentRec, "visib")) out.visib = currentRec.visib;
                    if (structKeyExists(currentRec, "observation_time")) out.observation_time = currentRec.observation_time;
                    if (!out.success) out.success = true;
                }

                if (structKeyExists(arguments.src, "previous") AND isStruct(arguments.src.previous)) {
                    previousRec = extractMetarRecord(arguments.src.previous);
                    if (isStruct(previousRec) AND structCount(previousRec) GT 0) {
                        out.previous = previousRec;
                    }
                }
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="fetchHttp" access="private" returntype="struct" output="false">
        <cfargument name="url" type="string" required="true">
        <cfargument name="accept" type="string" required="false" default="application/json">
        <cfscript>
            var out = { "status"=0, "body"="" };
            var res = {};
            try {
                cfhttp(url=arguments.url, method="get", result="res", timeout=variables.httpTimeout, throwOnError="false") {
                    cfhttpparam(type="header", name="User-Agent", value=variables.userAgent);
                    cfhttpparam(type="header", name="Accept", value=arguments.accept);
                }
                out.status = parseHttpStatus(res);
                out.body = (structKeyExists(res, "fileContent") ? toString(res.fileContent) : "");
            } catch (any eHttp) {
                out.status = 0;
                out.body = "";
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="parseHttpStatus" access="private" returntype="numeric" output="false">
        <cfargument name="res" type="struct" required="true">
        <cfscript>
            var statusTxt = "";
            if (structKeyExists(arguments.res, "statusCode")) {
                statusTxt = trim(toString(arguments.res.statusCode));
                if (isNumeric(statusTxt)) return int(val(statusTxt));
                if (len(statusTxt) GTE 3 AND isNumeric(left(statusTxt, 3))) {
                    return int(val(left(statusTxt, 3)));
                }
            }
            return 0;
        </cfscript>
    </cffunction>

    <cffunction name="appCacheGet" access="private" returntype="any" output="false">
        <cfargument name="cacheKey" type="string" required="true">
        <cfargument name="ttlSeconds" type="numeric" required="true">
        <cfscript>
            var item = javacast("null", "");
            if (NOT structKeyExists(application, "weatherCache")) {
                application.weatherCache = {};
            }
            if (structKeyExists(application.weatherCache, arguments.cacheKey)) {
                item = application.weatherCache[arguments.cacheKey];
                if (
                    isStruct(item)
                    AND structKeyExists(item, "ts")
                    AND structKeyExists(item, "val")
                    AND dateDiff("s", item.ts, now()) LTE arguments.ttlSeconds
                ) {
                    return item.val;
                }
            }
            return javacast("null", "");
        </cfscript>
    </cffunction>

    <cffunction name="appCachePeek" access="private" returntype="any" output="false">
        <cfargument name="cacheKey" type="string" required="true">
        <cfscript>
            var item = javacast("null", "");
            if (NOT structKeyExists(application, "weatherCache")) {
                application.weatherCache = {};
            }
            if (structKeyExists(application.weatherCache, arguments.cacheKey)) {
                item = application.weatherCache[arguments.cacheKey];
                if (
                    isStruct(item)
                    AND structKeyExists(item, "val")
                    AND isStruct(item.val)
                ) {
                    return item.val;
                }
            }
            return javacast("null", "");
        </cfscript>
    </cffunction>

    <cffunction name="appCacheSet" access="private" returntype="void" output="false">
        <cfargument name="cacheKey" type="string" required="true">
        <cfargument name="cacheVal" type="struct" required="true">
        <cfscript>
            if (NOT structKeyExists(application, "weatherCache")) {
                application.weatherCache = {};
            }
            application.weatherCache[arguments.cacheKey] = {
                "ts"=now(),
                "val"=duplicate(arguments.cacheVal)
            };
        </cfscript>
    </cffunction>

    <cffunction name="buildForecastKey" access="private" returntype="string" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfargument name="hourBucket" type="date" required="true">
        <cfscript>
            return "nws:forecast:"
                & numberFormat(arguments.lat, "0.0000000")
                & ":"
                & numberFormat(arguments.lng, "0.0000000")
                & ":"
                & dateTimeFormat(arguments.hourBucket, "yyyy-mm-dd HH:00:00");
        </cfscript>
    </cffunction>

    <cffunction name="buildAlertsKey" access="private" returntype="string" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfargument name="hourBucket" type="date" required="true">
        <cfscript>
            return "nws:alerts:"
                & numberFormat(arguments.lat, "0.0000000")
                & ":"
                & numberFormat(arguments.lng, "0.0000000")
                & ":"
                & dateTimeFormat(arguments.hourBucket, "yyyy-mm-dd HH:00:00");
        </cfscript>
    </cffunction>

    <cffunction name="buildMarineKey" access="private" returntype="string" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfargument name="hourBucket" type="date" required="true">
        <cfscript>
            return "nws:marine:"
                & numberFormat(arguments.lat, "0.0000000")
                & ":"
                & numberFormat(arguments.lng, "0.0000000")
                & ":"
                & dateTimeFormat(arguments.hourBucket, "yyyy-mm-dd HH:00:00");
        </cfscript>
    </cffunction>

    <cffunction name="buildMetarKey" access="private" returntype="string" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfscript>
            return "metar:v2:"
                & numberFormat(arguments.lat, "0.0000000")
                & ":"
                & numberFormat(arguments.lng, "0.0000000");
        </cfscript>
    </cffunction>

    <cffunction name="ttlSecondsForHour" access="private" returntype="numeric" output="false">
        <cfargument name="hourBucket" type="date" required="true">
        <cfscript>
            var aheadHours = dateDiff("h", now(), arguments.hourBucket);
            if (aheadHours GTE 0 AND aheadHours LTE 24) return 3600;
            return 21600;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeCoord" access="private" returntype="numeric" output="false">
        <cfargument name="coord" type="numeric" required="true">
        <cfscript>
            return round(arguments.coord * 10000000) / 10000000;
        </cfscript>
    </cffunction>

    <cffunction name="floorToHour" access="private" returntype="date" output="false">
        <cfargument name="dt" type="date" required="true">
        <cfscript>
            return createDateTime(year(arguments.dt), month(arguments.dt), day(arguments.dt), hour(arguments.dt), 0, 0);
        </cfscript>
    </cffunction>

</cfcomponent>
