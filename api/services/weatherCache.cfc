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

            variables.defaultTtl = {
                "nwsForecast"=900,
                "nwsAlerts"=300,
                "marine"=900,
                "metar"=900
            };
            variables.maxEntries = {
                "nwsForecast"=500,
                "nwsAlerts"=500,
                "marine"=500,
                "metar"=500,
                "legacy"=500
            };
            return this;
        </cfscript>
    </cffunction>

    <!--- Legacy compatibility wrappers --->
    <cffunction name="getForecast" access="public" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfargument name="forecastHour" type="date" required="true">
        <cfscript>
            var hourBucket = floorToHour(arguments.forecastHour);
            var ttlSeconds = ttlSecondsForHour(hourBucket);
            return getNwsForecastCached(arguments.lat, arguments.lng, ttlSeconds, false);
        </cfscript>
    </cffunction>

    <cffunction name="getAlerts" access="public" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfscript>
            var hourBucket = floorToHour(now());
            var ttlSeconds = ttlSecondsForHour(hourBucket);
            return getNwsAlertsCached(arguments.lat, arguments.lng, ttlSeconds, false);
        </cfscript>
    </cffunction>

    <cffunction name="getMarine" access="public" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfargument name="forecastHour" type="date" required="true">
        <cfscript>
            var hourBucket = floorToHour(arguments.forecastHour);
            var ttlSeconds = ttlSecondsForHour(hourBucket);
            return getMarineCached(
                arguments.lat,
                arguments.lng,
                ttlSeconds,
                false,
                function(required numeric fLat, required numeric fLng) {
                    return fetchForecastPayload(arguments.fLat, arguments.fLng);
                }
            );
        </cfscript>
    </cffunction>

    <!--- METAR surface-observation cache block (default 15 minute TTL, rounded lat/lng key). --->
    <cffunction name="getMetar" access="public" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfscript>
            return getMetarCached(arguments.lat, arguments.lng, variables.defaultTtl.metar);
        </cfscript>
    </cffunction>

    <cffunction name="getMetarCached" access="public" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfargument name="ttlSeconds" type="numeric" required="false" default="900">
        <cfscript>
            var latVal = normalizeCoord(arguments.lat);
            var lngVal = normalizeCoord(arguments.lng);
            var ttl = normalizeTtl(arguments.ttlSeconds, variables.defaultTtl.metar);
            var cacheKey = buildMetarKey(latVal, lngVal);
            var cachedEnvelope = cacheGetEnvelope("metar", cacheKey);
            var priorEnvelope = cachePeekEnvelope("metar", cacheKey);
            var cached = {};
            var priorCacheVal = {};
            var fetched = {};
            var currentRec = {};
            var previousRec = {};
            var cachePayload = {};
            var out = {};
            var newEnvelope = {};

            if (isStruct(cachedEnvelope) AND structKeyExists(cachedEnvelope, "data") AND isStruct(cachedEnvelope.data)) {
                cached = cachedEnvelope.data;
            }
            if (isStruct(priorEnvelope) AND structKeyExists(priorEnvelope, "data") AND isStruct(priorEnvelope.data)) {
                priorCacheVal = priorEnvelope.data;
            }

            if (structCount(cached) GT 0) {
                out = composeMetarEnvelope(cached, true, cacheKey);
                return mergePayloadWithCacheMeta(out, cachedEnvelope, cacheKey, ttl, true, false);
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
                newEnvelope = buildEnvelope(
                    cacheKey,
                    "aviationweather.gov",
                    cachePayload,
                    ttl,
                    { "status"=(structKeyExists(fetched, "status") ? val(fetched.status) : 0) }
                );
                cacheSetEnvelope("metar", cacheKey, newEnvelope, cacheTypeLimit("metar"));
                out = composeMetarEnvelope(cachePayload, false, cacheKey);
                return mergePayloadWithCacheMeta(out, newEnvelope, cacheKey, ttl, false, false);
            }

            if (structCount(priorCacheVal) GT 0) {
                out = composeMetarEnvelope(priorCacheVal, true, cacheKey);
                if ((!structKeyExists(out, "success") OR !out.success) AND isStruct(fetched)) {
                    if (structKeyExists(fetched, "note")) out.note = toString(fetched.note);
                    if (structKeyExists(fetched, "status")) out.status = val(fetched.status);
                    if (structKeyExists(fetched, "url")) out.url = toString(fetched.url);
                }
                return mergePayloadWithCacheMeta(out, priorEnvelope, cacheKey, ttl, true, false);
            }

            out = composeMetarEnvelope(fetched, false, cacheKey);
            return mergePayloadWithCacheMeta(out, {}, cacheKey, ttl, false, false);
        </cfscript>
    </cffunction>

    <cffunction name="getNwsForecastCached" access="public" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfargument name="ttlSeconds" type="numeric" required="false" default="900">
        <cfargument name="bypassCache" type="boolean" required="false" default="false">
        <cfargument name="fetcher" type="any" required="false" default="">
        <cfscript>
            var norm = normalizeLatLng(arguments.lat, arguments.lng, 3);
            var ttl = normalizeTtl(arguments.ttlSeconds, variables.defaultTtl.nwsForecast);
            var cacheKey = buildKey("nws:forecast", norm.lat, norm.lng, 3);
            var cachedEnvelope = {};
            var payload = {};
            var envelope = {};
            var httpMeta = {};

            if (!arguments.bypassCache) {
                cachedEnvelope = cacheGetEnvelope("nwsForecast", cacheKey);
                if (isStruct(cachedEnvelope) AND structCount(cachedEnvelope) GT 0) {
                    payload = (structKeyExists(cachedEnvelope, "data") AND isStruct(cachedEnvelope.data) ? cachedEnvelope.data : {});
                    return mergePayloadWithCacheMeta(payload, cachedEnvelope, cacheKey, ttl, true, false);
                }
            }

            if (isCustomFunction(arguments.fetcher)) {
                payload = arguments.fetcher(norm.lat, norm.lng);
            } else {
                payload = fetchForecastPayload(norm.lat, norm.lng);
            }
            if (!isStruct(payload)) payload = {};

            httpMeta = deriveForecastHttpMeta(payload);
            envelope = buildEnvelope(cacheKey, "api.weather.gov", payload, ttl, httpMeta);
            cacheSetEnvelope("nwsForecast", cacheKey, envelope, cacheTypeLimit("nwsForecast"));
            return mergePayloadWithCacheMeta(payload, envelope, cacheKey, ttl, false, arguments.bypassCache);
        </cfscript>
    </cffunction>

    <cffunction name="getNwsAlertsCached" access="public" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfargument name="ttlSeconds" type="numeric" required="false" default="300">
        <cfargument name="bypassCache" type="boolean" required="false" default="false">
        <cfargument name="fetcher" type="any" required="false" default="">
        <cfscript>
            var norm = normalizeLatLng(arguments.lat, arguments.lng, 3);
            var ttl = normalizeTtl(arguments.ttlSeconds, variables.defaultTtl.nwsAlerts);
            var cacheKey = buildKey("nws:alerts", norm.lat, norm.lng, 3);
            var cachedEnvelope = {};
            var payload = {};
            var envelope = {};
            var httpMeta = {};

            if (!arguments.bypassCache) {
                cachedEnvelope = cacheGetEnvelope("nwsAlerts", cacheKey);
                if (isStruct(cachedEnvelope) AND structCount(cachedEnvelope) GT 0) {
                    payload = (structKeyExists(cachedEnvelope, "data") AND isStruct(cachedEnvelope.data) ? cachedEnvelope.data : {});
                    return mergePayloadWithCacheMeta(payload, cachedEnvelope, cacheKey, ttl, true, false);
                }
            }

            if (isCustomFunction(arguments.fetcher)) {
                payload = arguments.fetcher(norm.lat, norm.lng);
            } else {
                payload = fetchAlertsPayload(norm.lat, norm.lng);
            }
            if (!isStruct(payload)) payload = {};

            httpMeta = deriveAlertsHttpMeta(payload);
            envelope = buildEnvelope(cacheKey, "api.weather.gov", payload, ttl, httpMeta);
            cacheSetEnvelope("nwsAlerts", cacheKey, envelope, cacheTypeLimit("nwsAlerts"));
            return mergePayloadWithCacheMeta(payload, envelope, cacheKey, ttl, false, arguments.bypassCache);
        </cfscript>
    </cffunction>

    <cffunction name="getMarineCached" access="public" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfargument name="ttlSeconds" type="numeric" required="false" default="900">
        <cfargument name="bypassCache" type="boolean" required="false" default="false">
        <cfargument name="fetcher" type="any" required="false" default="">
        <cfscript>
            var norm = normalizeLatLng(arguments.lat, arguments.lng, 3);
            var ttl = normalizeTtl(arguments.ttlSeconds, variables.defaultTtl.marine);
            var cacheKey = buildKey("marine", norm.lat, norm.lng, 3);
            var cachedEnvelope = {};
            var payload = {};
            var envelope = {};
            var httpMeta = {};

            if (!arguments.bypassCache) {
                cachedEnvelope = cacheGetEnvelope("marine", cacheKey);
                if (isStruct(cachedEnvelope) AND structCount(cachedEnvelope) GT 0) {
                    payload = (structKeyExists(cachedEnvelope, "data") AND isStruct(cachedEnvelope.data) ? cachedEnvelope.data : {});
                    return mergePayloadWithCacheMeta(payload, cachedEnvelope, cacheKey, ttl, true, false);
                }
            }

            if (isCustomFunction(arguments.fetcher)) {
                payload = arguments.fetcher(norm.lat, norm.lng);
            } else {
                payload = {};
            }
            if (!isStruct(payload)) payload = {};

            if (structKeyExists(payload, "http_meta") AND isStruct(payload.http_meta)) {
                httpMeta = payload.http_meta;
            } else {
                httpMeta = { "status"=0 };
            }
            envelope = buildEnvelope(cacheKey, "marine", payload, ttl, httpMeta);
            cacheSetEnvelope("marine", cacheKey, envelope, cacheTypeLimit("marine"));
            return mergePayloadWithCacheMeta(payload, envelope, cacheKey, ttl, false, arguments.bypassCache);
        </cfscript>
    </cffunction>

    <!--- Legacy marine cache wrappers retained for backwards compatibility with existing keys. --->
    <cffunction name="getMarineCacheValue" access="public" returntype="any" output="false">
        <cfargument name="key" type="string" required="true">
        <cfargument name="ttlSeconds" type="numeric" required="true">
        <cfscript>
            var out = "";
            var item = {};
            var hasItem = false;
            var ttl = normalizeTtl(arguments.ttlSeconds, variables.defaultTtl.marine);
            lock name="fpw.weatherCache.marineLegacy" type="exclusive" timeout="5" {
                ensureMarineLegacyStore();
                if (structKeyExists(application.marineCache, arguments.key)) {
                    item = application.marineCache[arguments.key];
                    if (
                        isStruct(item)
                        AND structKeyExists(item, "ts")
                        AND dateDiff("s", item.ts, now()) LT ttl
                    ) {
                        hasItem = true;
                        out = (structKeyExists(item, "val") ? item.val : "");
                    } else {
                        structDelete(application.marineCache, arguments.key, false);
                    }
                }
            }
            if (hasItem) return out;
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="setMarineCacheValue" access="public" returntype="void" output="false">
        <cfargument name="key" type="string" required="true">
        <cfargument name="val" type="any" required="true">
        <cfscript>
            lock name="fpw.weatherCache.marineLegacy" type="exclusive" timeout="5" {
                ensureMarineLegacyStore();
                application.marineCache[arguments.key] = { "ts"=now(), "val"=cloneAny(arguments.val) };
                pruneMarineLegacyStore(500);
            }
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
                "grid_body"="",
                "http_meta"={ "status"=0 }
            };
            var pointsRes = {};
            var pointsObj = {};
            var forecastRes = {};
            var gridRes = {};

            out.points_url = "https://api.weather.gov/points/" & arguments.lat & "," & arguments.lng;
            pointsRes = fetchHttp(out.points_url, "application/geo+json");
            out.points_status = val(pointsRes.status);
            out.points_body = toString(pointsRes.body);
            out.http_meta.status = out.points_status;
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
            out.http_meta.status = out.forecast_status;
            if (len(trim(toString(forecastRes.etag)))) out.http_meta.etag = trim(toString(forecastRes.etag));
            if (len(trim(toString(forecastRes.last_modified)))) out.http_meta.last_modified = trim(toString(forecastRes.last_modified));
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
                "note"="",
                "http_meta"={ "status"=0 }
            };
            var res = {};
            out.url = "https://api.weather.gov/alerts/active?point=" & arguments.lat & "," & arguments.lng;
            res = fetchHttp(out.url, "application/geo+json");
            out.status = val(res.status);
            out.body = toString(res.body);
            out.http_meta.status = out.status;
            if (len(trim(toString(res.etag)))) out.http_meta.etag = trim(toString(res.etag));
            if (len(trim(toString(res.last_modified)))) out.http_meta.last_modified = trim(toString(res.last_modified));
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
            var out = { "status"=0, "body"="", "headers"={}, "etag"="", "last_modified"="" };
            var res = {};
            try {
                cfhttp(url=arguments.url, method="get", result="res", timeout=variables.httpTimeout, throwOnError="false") {
                    cfhttpparam(type="header", name="User-Agent", value=variables.userAgent);
                    cfhttpparam(type="header", name="Accept", value=arguments.accept);
                }
                out.status = parseHttpStatus(res);
                out.body = (structKeyExists(res, "fileContent") ? toString(res.fileContent) : "");
                if (structKeyExists(res, "responseHeader") AND isStruct(res.responseHeader)) {
                    out.headers = duplicate(res.responseHeader);
                    out.etag = extractHeaderValue(out.headers, "ETag");
                    out.last_modified = extractHeaderValue(out.headers, "Last-Modified");
                }
            } catch (any eHttp) {
                out.status = 0;
                out.body = "";
                out.headers = {};
                out.etag = "";
                out.last_modified = "";
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

    <cffunction name="extractHeaderValue" access="private" returntype="string" output="false">
        <cfargument name="headers" type="struct" required="true">
        <cfargument name="name" type="string" required="true">
        <cfscript>
            var key = "";
            var keys = structKeyArray(arguments.headers);
            var v = "";
            for (key in keys) {
                if (lcase(trim(key)) EQ lcase(trim(arguments.name))) {
                    v = arguments.headers[key];
                    if (isArray(v) AND arrayLen(v)) {
                        return trim(toString(v[1]));
                    }
                    return trim(toString(v));
                }
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="appCacheGet" access="private" returntype="any" output="false">
        <cfargument name="cacheKey" type="string" required="true">
        <cfargument name="ttlSeconds" type="numeric" required="true">
        <cfscript>
            var item = javacast("null", "");
            var ttl = normalizeTtl(arguments.ttlSeconds, 60);
            lock name="fpw.weatherCache.legacy" type="exclusive" timeout="5" {
                if (NOT structKeyExists(application, "weatherCache")) {
                    application.weatherCache = {};
                }
                if (structKeyExists(application.weatherCache, arguments.cacheKey)) {
                    item = application.weatherCache[arguments.cacheKey];
                    if (
                        isStruct(item)
                        AND structKeyExists(item, "ts")
                        AND structKeyExists(item, "val")
                        AND dateDiff("s", item.ts, now()) LTE ttl
                    ) {
                        item = cloneAny(item.val);
                    } else {
                        structDelete(application.weatherCache, arguments.cacheKey, false);
                        item = javacast("null", "");
                    }
                }
                pruneLegacyStore(variables.maxEntries.legacy);
            }
            return item;
        </cfscript>
    </cffunction>

    <cffunction name="appCachePeek" access="private" returntype="any" output="false">
        <cfargument name="cacheKey" type="string" required="true">
        <cfscript>
            var item = javacast("null", "");
            lock name="fpw.weatherCache.legacy" type="exclusive" timeout="5" {
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
                        item = cloneAny(item.val);
                    } else {
                        item = javacast("null", "");
                    }
                }
            }
            return item;
        </cfscript>
    </cffunction>

    <cffunction name="appCacheSet" access="private" returntype="void" output="false">
        <cfargument name="cacheKey" type="string" required="true">
        <cfargument name="cacheVal" type="struct" required="true">
        <cfscript>
            lock name="fpw.weatherCache.legacy" type="exclusive" timeout="5" {
                if (NOT structKeyExists(application, "weatherCache")) {
                    application.weatherCache = {};
                }
                application.weatherCache[arguments.cacheKey] = {
                    "ts"=now(),
                    "val"=cloneAny(arguments.cacheVal)
                };
                pruneLegacyStore(variables.maxEntries.legacy);
            }
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

    <cffunction name="normalizeLatLng" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfargument name="decimals" type="numeric" required="false" default="3">
        <cfscript>
            var d = int(val(arguments.decimals));
            if (d LT 0) d = 0;
            if (d GT 7) d = 7;
            return {
                "lat"=roundToDecimals(arguments.lat, d),
                "lng"=roundToDecimals(arguments.lng, d)
            };
        </cfscript>
    </cffunction>

    <cffunction name="roundToDecimals" access="private" returntype="numeric" output="false">
        <cfargument name="n" type="numeric" required="true">
        <cfargument name="decimals" type="numeric" required="true">
        <cfscript>
            var factor = 1;
            var i = 0;
            for (i = 1; i LTE int(val(arguments.decimals)); i = i + 1) {
                factor = factor * 10;
            }
            return round(val(arguments.n) * factor) / factor;
        </cfscript>
    </cffunction>

    <cffunction name="buildKey" access="private" returntype="string" output="false">
        <cfargument name="prefix" type="string" required="true">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfargument name="decimals" type="numeric" required="false" default="3">
        <cfscript>
            return trim(arguments.prefix)
                & ":lat="
                & coordForKey(arguments.lat, arguments.decimals)
                & ":lng="
                & coordForKey(arguments.lng, arguments.decimals);
        </cfscript>
    </cffunction>

    <cffunction name="coordForKey" access="private" returntype="string" output="false">
        <cfargument name="coord" type="numeric" required="true">
        <cfargument name="decimals" type="numeric" required="true">
        <cfscript>
            var d = int(val(arguments.decimals));
            var i = 0;
            var mask = "0";
            if (d LT 0) d = 0;
            if (d GT 7) d = 7;
            if (d GT 0) {
                mask = mask & ".";
                for (i = 1; i LTE d; i = i + 1) {
                    mask = mask & "0";
                }
            }
            return numberFormat(roundToDecimals(arguments.coord, d), mask);
        </cfscript>
    </cffunction>

    <cffunction name="normalizeTtl" access="private" returntype="numeric" output="false">
        <cfargument name="ttlSeconds" type="numeric" required="true">
        <cfargument name="defaultSeconds" type="numeric" required="true">
        <cfscript>
            var ttl = int(val(arguments.ttlSeconds));
            if (ttl LTE 0) ttl = int(val(arguments.defaultSeconds));
            if (ttl LTE 0) ttl = 60;
            if (ttl GT 86400) ttl = 86400;
            return ttl;
        </cfscript>
    </cffunction>

    <cffunction name="cacheTypeLimit" access="private" returntype="numeric" output="false">
        <cfargument name="cacheType" type="string" required="true">
        <cfscript>
            if (structKeyExists(variables.maxEntries, arguments.cacheType)) {
                return int(val(variables.maxEntries[arguments.cacheType]));
            }
            return 500;
        </cfscript>
    </cffunction>

    <cffunction name="lockNameForType" access="private" returntype="string" output="false">
        <cfargument name="cacheType" type="string" required="true">
        <cfscript>
            return "fpw.weatherCache.unified." & rereplace(arguments.cacheType, "[^A-Za-z0-9_]", "_", "all");
        </cfscript>
    </cffunction>

    <cffunction name="ensureUnifiedCacheStore" access="private" returntype="void" output="false">
        <cfargument name="cacheType" type="string" required="true">
        <cfscript>
            if (NOT structKeyExists(application, "weatherCacheUnified") OR NOT isStruct(application.weatherCacheUnified)) {
                application.weatherCacheUnified = {};
            }
            if (NOT structKeyExists(application.weatherCacheUnified, arguments.cacheType) OR NOT isStruct(application.weatherCacheUnified[arguments.cacheType])) {
                application.weatherCacheUnified[arguments.cacheType] = {};
            }
        </cfscript>
    </cffunction>

    <cffunction name="cacheGetEnvelope" access="private" returntype="struct" output="false">
        <cfargument name="cacheType" type="string" required="true">
        <cfargument name="cacheKey" type="string" required="true">
        <cfscript>
            var out = {};
            var item = {};
            var nowEpoch = toEpochSeconds(now());
            lock name=lockNameForType(arguments.cacheType) type="exclusive" timeout="5" {
                ensureUnifiedCacheStore(arguments.cacheType);
                if (structKeyExists(application.weatherCacheUnified[arguments.cacheType], arguments.cacheKey)) {
                    item = application.weatherCacheUnified[arguments.cacheType][arguments.cacheKey];
                    if (
                        isStruct(item)
                        AND structKeyExists(item, "expires_epoch")
                        AND val(item.expires_epoch) GTE nowEpoch
                    ) {
                        out = cloneAny(item);
                    } else {
                        structDelete(application.weatherCacheUnified[arguments.cacheType], arguments.cacheKey, false);
                    }
                }
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="cachePeekEnvelope" access="private" returntype="struct" output="false">
        <cfargument name="cacheType" type="string" required="true">
        <cfargument name="cacheKey" type="string" required="true">
        <cfscript>
            var out = {};
            lock name=lockNameForType(arguments.cacheType) type="exclusive" timeout="5" {
                ensureUnifiedCacheStore(arguments.cacheType);
                if (structKeyExists(application.weatherCacheUnified[arguments.cacheType], arguments.cacheKey)) {
                    out = cloneAny(application.weatherCacheUnified[arguments.cacheType][arguments.cacheKey]);
                }
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="cacheSetEnvelope" access="private" returntype="void" output="false">
        <cfargument name="cacheType" type="string" required="true">
        <cfargument name="cacheKey" type="string" required="true">
        <cfargument name="envelope" type="struct" required="true">
        <cfargument name="maxEntries" type="numeric" required="false" default="500">
        <cfscript>
            lock name=lockNameForType(arguments.cacheType) type="exclusive" timeout="5" {
                ensureUnifiedCacheStore(arguments.cacheType);
                application.weatherCacheUnified[arguments.cacheType][arguments.cacheKey] = cloneAny(arguments.envelope);
                cachePrune(arguments.cacheType, int(val(arguments.maxEntries)));
            }
        </cfscript>
    </cffunction>

    <cffunction name="cachePrune" access="private" returntype="void" output="false">
        <cfargument name="cacheType" type="string" required="true">
        <cfargument name="maxEntries" type="numeric" required="true">
        <cfscript>
            var nowEpoch = toEpochSeconds(now());
            var keys = [];
            var key = "";
            var oldestKey = "";
            var oldestEpoch = 9999999999;
            var epochCandidate = 0;
            var entry = {};

            if (!structKeyExists(application, "weatherCacheUnified")
                OR !isStruct(application.weatherCacheUnified)
                OR !structKeyExists(application.weatherCacheUnified, arguments.cacheType)
                OR !isStruct(application.weatherCacheUnified[arguments.cacheType])) {
                return;
            }

            keys = structKeyArray(application.weatherCacheUnified[arguments.cacheType]);
            for (key in keys) {
                entry = application.weatherCacheUnified[arguments.cacheType][key];
                if (!isStruct(entry)) {
                    structDelete(application.weatherCacheUnified[arguments.cacheType], key, false);
                    continue;
                }
                if (structKeyExists(entry, "expires_epoch") AND val(entry.expires_epoch) LT nowEpoch) {
                    structDelete(application.weatherCacheUnified[arguments.cacheType], key, false);
                }
            }

            keys = structKeyArray(application.weatherCacheUnified[arguments.cacheType]);
            while (arrayLen(keys) GT arguments.maxEntries) {
                oldestKey = "";
                oldestEpoch = 9999999999;
                for (key in keys) {
                    entry = application.weatherCacheUnified[arguments.cacheType][key];
                    epochCandidate = (
                        isStruct(entry) AND structKeyExists(entry, "expires_epoch")
                            ? val(entry.expires_epoch)
                            : (isStruct(entry) AND structKeyExists(entry, "cached_epoch") ? val(entry.cached_epoch) : nowEpoch)
                    );
                    if (epochCandidate LT oldestEpoch) {
                        oldestEpoch = epochCandidate;
                        oldestKey = key;
                    }
                }
                if (!len(oldestKey)) {
                    break;
                }
                structDelete(application.weatherCacheUnified[arguments.cacheType], oldestKey, false);
                keys = structKeyArray(application.weatherCacheUnified[arguments.cacheType]);
            }
        </cfscript>
    </cffunction>

    <cffunction name="buildEnvelope" access="private" returntype="struct" output="false">
        <cfargument name="cacheKey" type="string" required="true">
        <cfargument name="source" type="string" required="true">
        <cfargument name="data" type="any" required="true">
        <cfargument name="ttlSeconds" type="numeric" required="true">
        <cfargument name="httpMeta" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var cachedAt = now();
            var ttl = normalizeTtl(arguments.ttlSeconds, 60);
            var expiresAt = dateAdd("s", ttl, cachedAt);
            var out = {
                "cached_at_utc"=dateToUtcIso(cachedAt),
                "expires_at_utc"=dateToUtcIso(expiresAt),
                "cache_key"=arguments.cacheKey,
                "source"=arguments.source,
                "data"=(isStruct(arguments.data) ? cloneAny(arguments.data) : {}),
                "http_meta"=(isStruct(arguments.httpMeta) ? cloneAny(arguments.httpMeta) : {}),
                "cached_epoch"=toEpochSeconds(cachedAt),
                "expires_epoch"=toEpochSeconds(expiresAt),
                "ttl_seconds"=ttl
            };
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="deriveForecastHttpMeta" access="private" returntype="struct" output="false">
        <cfargument name="payload" type="struct" required="true">
        <cfscript>
            var out = {};
            if (structKeyExists(arguments.payload, "http_meta") AND isStruct(arguments.payload.http_meta)) {
                out = cloneAny(arguments.payload.http_meta);
            } else {
                out.status = (
                    structKeyExists(arguments.payload, "forecast_status")
                        ? val(arguments.payload.forecast_status)
                        : (structKeyExists(arguments.payload, "points_status") ? val(arguments.payload.points_status) : 0)
                );
            }
            if (!structKeyExists(out, "status")) out.status = 0;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="deriveAlertsHttpMeta" access="private" returntype="struct" output="false">
        <cfargument name="payload" type="struct" required="true">
        <cfscript>
            var out = {};
            if (structKeyExists(arguments.payload, "http_meta") AND isStruct(arguments.payload.http_meta)) {
                out = cloneAny(arguments.payload.http_meta);
            } else {
                out.status = (structKeyExists(arguments.payload, "status") ? val(arguments.payload.status) : 0);
            }
            if (!structKeyExists(out, "status")) out.status = 0;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="mergePayloadWithCacheMeta" access="private" returntype="struct" output="false">
        <cfargument name="payload" type="any" required="true">
        <cfargument name="envelope" type="struct" required="true">
        <cfargument name="cacheKey" type="string" required="true">
        <cfargument name="ttlSeconds" type="numeric" required="true">
        <cfargument name="hit" type="boolean" required="true">
        <cfargument name="bypass" type="boolean" required="false" default="false">
        <cfscript>
            var out = (isStruct(arguments.payload) ? cloneAny(arguments.payload) : {});
            var cachedAtUtc = (isStruct(arguments.envelope) AND structKeyExists(arguments.envelope, "cached_at_utc") ? toString(arguments.envelope.cached_at_utc) : "");
            var expiresAtUtc = (isStruct(arguments.envelope) AND structKeyExists(arguments.envelope, "expires_at_utc") ? toString(arguments.envelope.expires_at_utc) : "");
            out.cache_meta = {
                "hit"=arguments.hit,
                "cached_at_utc"=cachedAtUtc,
                "expires_at_utc"=expiresAtUtc,
                "key"=arguments.cacheKey,
                "ttl_seconds"=int(val(arguments.ttlSeconds))
            };
            if (arguments.bypass) {
                out.cache_meta.bypass = true;
            }
            out.cache_hit = arguments.hit;
            out.cache_key = arguments.cacheKey;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="dateToUtcIso" access="private" returntype="string" output="false">
        <cfargument name="dt" type="date" required="true">
        <cfscript>
            return dateTimeFormat(dateConvert("local2utc", arguments.dt), "yyyy-mm-dd'T'HH:nn:ss'Z'");
        </cfscript>
    </cffunction>

    <cffunction name="toEpochSeconds" access="private" returntype="numeric" output="false">
        <cfargument name="dt" type="date" required="true">
        <cfscript>
            return dateDiff("s", createDateTime(1970, 1, 1, 0, 0, 0), dateConvert("local2utc", arguments.dt));
        </cfscript>
    </cffunction>

    <cffunction name="cloneAny" access="private" returntype="any" output="false">
        <cfargument name="v" type="any" required="true">
        <cfscript>
            if (isStruct(arguments.v) OR isArray(arguments.v) OR isQuery(arguments.v)) {
                return duplicate(arguments.v);
            }
            return arguments.v;
        </cfscript>
    </cffunction>

    <cffunction name="ensureMarineLegacyStore" access="private" returntype="void" output="false">
        <cfscript>
            if (!structKeyExists(application, "marineCache") OR !isStruct(application.marineCache)) {
                application.marineCache = {};
            }
        </cfscript>
    </cffunction>

    <cffunction name="pruneMarineLegacyStore" access="private" returntype="void" output="false">
        <cfargument name="maxEntries" type="numeric" required="true">
        <cfscript>
            var keys = structKeyArray(application.marineCache);
            var oldestKey = "";
            var oldestTs = now();
            var k = "";
            var item = {};
            while (arrayLen(keys) GT arguments.maxEntries) {
                oldestKey = "";
                oldestTs = now();
                for (k in keys) {
                    item = application.marineCache[k];
                    if (!isStruct(item) OR !structKeyExists(item, "ts") OR !isDate(item.ts)) {
                        oldestKey = k;
                        break;
                    }
                    if (!len(oldestKey) OR dateCompare(item.ts, oldestTs) LT 0) {
                        oldestTs = item.ts;
                        oldestKey = k;
                    }
                }
                if (!len(oldestKey)) {
                    break;
                }
                structDelete(application.marineCache, oldestKey, false);
                keys = structKeyArray(application.marineCache);
            }
        </cfscript>
    </cffunction>

    <cffunction name="pruneLegacyStore" access="private" returntype="void" output="false">
        <cfargument name="maxEntries" type="numeric" required="true">
        <cfscript>
            var keys = structKeyArray(application.weatherCache);
            var oldestKey = "";
            var oldestTs = now();
            var k = "";
            var item = {};
            while (arrayLen(keys) GT arguments.maxEntries) {
                oldestKey = "";
                oldestTs = now();
                for (k in keys) {
                    item = application.weatherCache[k];
                    if (!isStruct(item) OR !structKeyExists(item, "ts") OR !isDate(item.ts)) {
                        oldestKey = k;
                        break;
                    }
                    if (!len(oldestKey) OR dateCompare(item.ts, oldestTs) LT 0) {
                        oldestTs = item.ts;
                        oldestKey = k;
                    }
                }
                if (!len(oldestKey)) {
                    break;
                }
                structDelete(application.weatherCache, oldestKey, false);
                keys = structKeyArray(application.weatherCache);
            }
        </cfscript>
    </cffunction>

</cfcomponent>
