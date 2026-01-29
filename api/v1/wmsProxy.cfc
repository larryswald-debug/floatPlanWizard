component output=false {

  /* ============================================================================
     FPW WMS Proxy (Hardened)
     - Allow-listed upstream targets + endpoint/path safety checks
     - Sanitized WMS params allow-list
     - Drops TIME for nws-radar GetMap (server-select latest; avoids ServiceException)
     - Ehcache tile caching (GetMap 300s, GetCapabilities 3600s)
     - Negative caching for failures (15s) to avoid hammering upstream
     - Always returns valid PNG for GetMap failures (no broken tiles)
     - Diagnostic response header: X-FPW-WMSProxy
     - Tile health counters (app-scope, lock-protected)
     - stats() remote endpoint to view/reset counters (authenticated session required)
     ============================================================================ */

  /* -----------------------------
     Counter Helpers (Application scope)
     ----------------------------- */
  private void function initCountersIfNeeded() {
    lock scope="application" type="exclusive" timeout="5" {
      if (!structKeyExists(application, "fpwWmsCounters") || !isStruct(application.fpwWmsCounters)) {
        application.fpwWmsCounters = {
          startedAt = dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss"),
          totals = { requests=0, getmap=0, getcapabilities=0 },
          byTarget = {}
        };
      }
    }
  }

  private void function bumpCounter(required string targetKey, required string name, numeric delta=1) {
    initCountersIfNeeded();
    lock scope="application" type="exclusive" timeout="5" {
      if (!structKeyExists(application.fpwWmsCounters.byTarget, targetKey)) {
        application.fpwWmsCounters.byTarget[targetKey] = {
          requests=0,
          cache_hit=0,
          upstream_ok=0,
          fallback_upstream=0,
          fallback_exception=0,
          fallback_read=0,
          negative_cache_set=0
        };
      }
      if (!structKeyExists(application.fpwWmsCounters.byTarget[targetKey], name)) {
        application.fpwWmsCounters.byTarget[targetKey][name] = 0;
      }
      application.fpwWmsCounters.byTarget[targetKey][name] += delta;

    }
  }

  private void function bumpTotals(required string requestType) {
    initCountersIfNeeded();
    lock scope="application" type="exclusive" timeout="5" {
      application.fpwWmsCounters.totals.requests++;
      if (ucase(requestType) == "GETMAP") application.fpwWmsCounters.totals.getmap++;
      if (ucase(requestType) == "GETCAPABILITIES") application.fpwWmsCounters.totals.getcapabilities++;
    }
  }

  /* -----------------------------
     Common Helpers
     ----------------------------- */
  private void function setDiag(required string value) {
    // Visible in DevTools > Network > Headers
    try { cfheader(name="X-FPW-WMSProxy", value=value); } catch(any e) {}
  }

  private void function sendJson(required numeric code, required struct body) {
    cfheader(statuscode=code);
    cfcontent(type="application/json; charset=utf-8", reset=true);
    writeOutput( serializeJSON(body) );
    setting enablecfoutputonly=false;
  }

  private string function getUrlParam(string name) {
    if (structKeyExists(url, name)) return trim(toString(url[name]));
    var low = lcase(name);
    if (structKeyExists(url, low)) return trim(toString(url[low]));
    var up = ucase(name);
    if (structKeyExists(url, up)) return trim(toString(url[up]));
    return "";
  }

  private string function normalizeTarget(string rawTarget) {
    var t = lcase( rereplace(rawTarget, "[^a-z0-9]", "", "all") );
    if (t == "nwsradar") return "nws-radar";
    if (t == "nowcoastradar") return "nowcoast-radar";
    if (t == "noaacharts") return "noaa-charts";
    return lcase(trim(rawTarget));
  }

  private boolean function isAllowedPath(string upstreamBase) {
    // Require known path patterns
    if ( findNoCase("/arcgis/services/", upstreamBase) == 0
      && findNoCase("/arcgis/rest/services/", upstreamBase) == 0
      && findNoCase("/geoserver/wms", upstreamBase) == 0
      && findNoCase("/geoserver/ows", upstreamBase) == 0
      && findNoCase("/eventdriven/services/", upstreamBase) == 0
    ) return false;

    // Require known endings
    var tailOk =
      right(upstreamBase, 10) == "/WmsServer"
      || right(upstreamBase, 10) == "/WMSServer"
      || right(upstreamBase, 14) == "/geoserver/wms"
      || right(upstreamBase, 14) == "/geoserver/ows";

    return tailOk;
  }

  private string function buildCacheKey(required string targetKey, required string requestType, required string upstreamUrl) {
    return "fpw:wms:" & targetKey & ":" & lcase(requestType) & ":" & hash(upstreamUrl, "SHA-256");
  }

  private any function cacheFetch(required string cacheKey) {
    try { return cacheGet(cacheKey); } catch(any e) { return javacast("null", 0); }
  }

  private void function cacheStore(required string cacheKey, required any value, required numeric ttlSeconds) {
    // cachePut(id, value, lifespan, idleTime)
    var ts = createTimeSpan(0,0,0,ttlSeconds);
    try { cachePut(cacheKey, value, ts, ts); } catch(any e) {}
  }

  /* ============================================================================
     Remote: tile()
     ============================================================================ */
  remote void function tile(
    string target="",
    string request="",
    string service="",
    string version="",
    string layers="",
    string styles="",
    string bbox="",
    string crs="",
    string srs="",
    string width="",
    string height="",
    string format="",
    string transparent="",
    string time="",
    string exceptions="",
    string bgcolor="",
    string format_options="",
    string tiled="",
    string tilematrix="",
    string tilematrixset="",
    string tilecol="",
    string tilerow="",
    string i="",
    string j="",
    string query_layers="",
    string info_format="",
    string feature_count="",
    string debug=""
  ) output=true {

    // Silence CF output + debug noise
    setting enablecfoutputonly=true;
    setting showdebugoutput=false;

    // Compact, tile-safe 1×1 transparent PNG (valid PNG everywhere)
    var transparentPngBase64 =
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+X2ZcAAAAASUVORK5CYII=";

    var negativeCacheTtlSeconds = 15;

    // Upstream targets allow-list
    var targets = {
      "nowcoast-radar" = "https://nowcoast.noaa.gov/arcgis/services/nowcoast/radar_meteo_imagery_nexrad_time/MapServer/WmsServer",
      "noaa-charts"    = "https://gis.charttools.noaa.gov/arcgis/rest/services/MCS/NOAAChartDisplay/MapServer/exts/MaritimeChartService/WMSServer",
      "nws-radar"      = "https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer"
    };

    // Local helper: always return image/png for GetMap failures
    void function sendTransparentPng(string reason="fallback") {
      setDiag(reason);
      cfheader(statuscode=200);
      cfcontent(type="image/png", reset=true, variable=binaryDecode(transparentPngBase64, "base64"));
      setting enablecfoutputonly=false;
    }

    var debugMode = (trim(arguments.debug) == "1" || getUrlParam("debug") == "1");

    // Method restriction
    if (lcase(cgi.request_method) != "get") {
      sendJson(405, { success=false, error="METHOD_NOT_ALLOWED", message="Only GET is allowed." });
      return;
    }

    // Resolve target
    var rawTarget    = len(arguments.target) ? arguments.target : getUrlParam("target");
    var targetKey    = normalizeTarget(rawTarget);
    var upstreamBase = structKeyExists(targets, targetKey) ? targets[targetKey] : "";

    if (!len(upstreamBase)) {
      sendJson(403, { success=false, error="INVALID_TARGET", message="Target not allowed.", detail=targetKey });
      return;
    }
    if (!isAllowedPath(upstreamBase)) {
      sendJson(403, { success=false, error="INVALID_PATH", message="Target endpoint not allowed." });
      return;
    }

    // Resolve request type
    var requestType = ucase( len(arguments.request) ? arguments.request : getUrlParam("request") );
    if (!len(requestType)) {
      sendJson(400, { success=false, error="MISSING_REQUEST", message="REQUEST parameter is required." });
      return;
    }
    if (!listFindNoCase("GETMAP,GETCAPABILITIES,GETFEATUREINFO", requestType)) {
      sendJson(400, { success=false, error="INVALID_REQUEST", message="REQUEST must be GetMap, GetCapabilities, or GetFeatureInfo." });
      return;
    }

    // Totals + per-target request counters
    bumpTotals(requestType);
    bumpCounter(targetKey, "requests", 1);

    // Validate SERVICE if provided
    var serviceType = ucase( len(arguments.service) ? arguments.service : getUrlParam("service") );
    if (len(serviceType) && serviceType != "WMS") {
      sendJson(400, { success=false, error="INVALID_SERVICE", message="SERVICE must be WMS." });
      return;
    }

    // Basic size sanity
    var widthVal  = len(arguments.width)  ? arguments.width  : getUrlParam("width");
    var heightVal = len(arguments.height) ? arguments.height : getUrlParam("height");

    if (len(widthVal) && (!isNumeric(widthVal) || val(widthVal) > 2048)) {
      sendJson(400, { success=false, error="INVALID_WIDTH", message="WIDTH must be numeric and <= 2048." });
      return;
    }
    if (len(heightVal) && (!isNumeric(heightVal) || val(heightVal) > 2048)) {
      sendJson(400, { success=false, error="INVALID_HEIGHT", message="HEIGHT must be numeric and <= 2048." });
      return;
    }

    // Extra restriction: nws-radar must only request radar_base_reflectivity_time
    if (requestType == "GETMAP" && targetKey == "nws-radar") {
      var requestedLayers = len(arguments.layers) ? trim(arguments.layers) : getUrlParam("layers");
      if (requestedLayers != "radar_base_reflectivity_time") {
        sendJson(400, { success=false, error="INVALID_LAYERS", message="LAYERS must be radar_base_reflectivity_time." });
        return;
      }
    }

    // WMS param allow-list (sanitized forward)
    // NOTE: We intentionally DROP TIME for nws-radar GetMap (most robust; avoids ServiceException).
    var wmsKeys = {
      "SERVICE"=true,"REQUEST"=true,"VERSION"=true,"LAYERS"=true,"STYLES"=true,"FORMAT"=true,
      "TRANSPARENT"=true,"CRS"=true,"SRS"=true,"BBOX"=true,"WIDTH"=true,"HEIGHT"=true,"TIME"=true,
      "QUERY_LAYERS"=true,"INFO_FORMAT"=true,"FEATURE_COUNT"=true,"I"=true,"J"=true
    };

    var queryPairs = [];
    var emitted = {};

    for (var key in url) {
      var lowerKey = lcase(key);
      if (lowerKey == "method" || lowerKey == "target" || lowerKey == "debug") continue;

      var upperKey = ucase(key);
      if (!structKeyExists(wmsKeys, upperKey)) continue;

      if (requestType == "GETMAP" && targetKey == "nws-radar" && upperKey == "TIME") continue;

      if (structKeyExists(emitted, upperKey)) continue;
      emitted[upperKey] = true;

      var v = url[key];
      if (!isSimpleValue(v)) continue;

      arrayAppend(queryPairs, urlEncodedFormat(upperKey) & "=" & urlEncodedFormat(toString(v)));
    }

    // Default FORMAT for GetMap if missing
    if (requestType == "GETMAP" && !structKeyExists(emitted, "FORMAT")) {
      arrayAppend(queryPairs, "FORMAT=" & urlEncodedFormat("image/png"));
    }

    var queryString = arrayToList(queryPairs, "&");
    var upstreamUrl = upstreamBase & (len(queryString) ? "?" & queryString : "");

    // Ehcache caching TTLs
    var ttlSeconds = (requestType == "GETMAP" || requestType == "GETFEATUREINFO") ? 300 : 3600;
    var cacheKey   = buildCacheKey(targetKey, requestType, upstreamUrl);

    // Cache hit?
    var cached = cacheFetch(cacheKey);
    if (!isNull(cached) && isStruct(cached) && structKeyExists(cached, "b64") && structKeyExists(cached, "ct")) {
      bumpCounter(targetKey, "cache_hit", 1);
      setDiag("cache-hit");
      cfheader(name="Cache-Control", value="public, max-age=" & ttlSeconds);
      cfheader(statuscode=200);
      cfcontent(type=cached.ct, reset=true, variable=binaryDecode(cached.b64, "base64"));
      setting enablecfoutputonly=false;
      return;
    }

    // Fetch upstream (retry once)
    var tempDir  = getTempDirectory();
    var tempName = "wms_" & createUUID() & ".bin";
    var tempPath = tempDir & tempName;

    var httpRes = {};
    var statusCode = 0;
    var statusText = "";

    for (var attempt=1; attempt <= 2; attempt++) {
      if (fileExists(tempPath)) fileDelete(tempPath);

      try {
        cfhttp(
          url=upstreamUrl,
          method="get",
          timeout="20",
          getAsBinary="yes",
          path=tempDir,
          file=tempName,
          result="httpRes"
        ) {
          cfhttpparam(type="header", name="User-Agent", value="FPW-WMSProxy/1.0");
          cfhttpparam(type="header", name="Accept", value="image/png,image/*,*/*");
          cfhttpparam(type="header", name="Accept-Language", value="en-US,en;q=0.9");
          cfhttpparam(type="header", name="Connection", value="keep-alive");
        };
      } catch (any e) {
        httpRes = { statusCode="0", mimeType="", responseHeader={} };
      }

      statusCode = val(listFirst(httpRes.statusCode ?: "0", " "));
      statusText = trim(reReplace(httpRes.statusCode ?: "", "^[0-9]+\s*", ""));

      if (statusCode == 200) break;
    }

    if (statusCode == 0) {
      statusCode = 502;
      statusText = "Bad Gateway";
    }

    // Upstream non-200
    if (statusCode != 200) {
      writeLog(file="application", type="error",
        text="WMS proxy upstream error target=#targetKey# status=#statusCode# #statusText# url=#upstreamBase#?REQUEST=#requestType#");

      if (fileExists(tempPath)) fileDelete(tempPath);

      if (requestType == "GETMAP") {
        bumpCounter(targetKey, "fallback_upstream", 1);

        if (debugMode) {
          sendJson(200, {
            success=false,
            mode="debug",
            target=targetKey,
            request=requestType,
            upstreamUrl=upstreamUrl,
            upstreamStatus=statusCode,
            upstreamStatusText=statusText,
            action="returned-transparent-png"
          });
          return;
        }

        // Negative cache: short-lived transparent tile to avoid hammering upstream
        cacheStore(cacheKey, { ct="image/png", b64=transparentPngBase64 }, negativeCacheTtlSeconds);
        bumpCounter(targetKey, "negative_cache_set", 1);

        sendTransparentPng("fallback: upstream-status=" & statusCode);
        return;
      }

      sendJson(statusCode, {
        success=false,
        error="UPSTREAM_ERROR",
        message="Upstream WMS error.",
        statusCode=statusCode,
        statusText=statusText,
        upstreamUrl=upstreamBase & "?REQUEST=" & requestType
      });
      return;
    }

    // Determine content type
    var contentType = "application/octet-stream";
    if (structKeyExists(httpRes, "mimeType") && len(httpRes.mimeType)) {
      contentType = httpRes.mimeType;
    } else if (structKeyExists(httpRes, "responseHeader") && structKeyExists(httpRes.responseHeader, "Content-Type")) {
      contentType = httpRes.responseHeader["Content-Type"];
    }

    // Detect ServiceException (XML returned with 200)
    var responseText = "";
    var hasServiceException = false;

    if (findNoCase("xml", contentType) || findNoCase("text", contentType)) {
      try { responseText = fileRead(tempPath); } catch (any e) { responseText = ""; }
      hasServiceException = (
        len(responseText)
        && (findNoCase("ServiceExceptionReport", responseText) || findNoCase("ExceptionReport", responseText))
      );
    }

    if (hasServiceException) {
      writeLog(file="application", type="error",
        text="WMS proxy ServiceException target=#targetKey# url=#upstreamBase#?REQUEST=#requestType# body=#left(responseText,2000)#");

      if (fileExists(tempPath)) fileDelete(tempPath);

      if (requestType == "GETMAP") {
        bumpCounter(targetKey, "fallback_exception", 1);

        if (debugMode) {
          sendJson(200, {
            success=false,
            mode="debug",
            target=targetKey,
            request=requestType,
            upstreamUrl=upstreamUrl,
            upstreamStatus=200,
            contentType=contentType,
            exceptionSnippet=left(responseText, 2000),
            action="returned-transparent-png"
          });
          return;
        }

        // Negative cache: short-lived transparent tile
        cacheStore(cacheKey, { ct="image/png", b64=transparentPngBase64 }, negativeCacheTtlSeconds);
        bumpCounter(targetKey, "negative_cache_set", 1);

        sendTransparentPng("fallback: service-exception");
        return;
      }

      sendJson(502, {
        success=false,
        error="UPSTREAM_EXCEPTION",
        message="Upstream WMS returned a ServiceExceptionReport.",
        detail="See server log for exception body."
      });
      return;
    }

    // Read binary
    var bytes = "";
    try {
      bytes = fileReadBinary(tempPath);
    } catch (any e) {
      if (fileExists(tempPath)) fileDelete(tempPath);

      if (requestType == "GETMAP") {
        bumpCounter(targetKey, "fallback_read", 1);

        if (debugMode) {
          sendJson(200, {
            success=false,
            mode="debug",
            target=targetKey,
            request=requestType,
            upstreamUrl=upstreamUrl,
            upstreamStatus=200,
            contentType=contentType,
            action="read-error-returned-transparent-png"
          });
          return;
        }

        // Negative cache: short-lived transparent tile
        cacheStore(cacheKey, { ct="image/png", b64=transparentPngBase64 }, negativeCacheTtlSeconds);
        bumpCounter(targetKey, "negative_cache_set", 1);

        sendTransparentPng("fallback: read-error");
        return;
      }

      sendJson(502, { success=false, error="READ_ERROR", message="Failed to read upstream response." });
      return;
    }

    if (fileExists(tempPath)) fileDelete(tempPath);

    // Cache + return success
    cfheader(name="Cache-Control", value="public, max-age=" & ttlSeconds);
    cacheStore(cacheKey, { ct=contentType, b64=toBase64(bytes) }, ttlSeconds);

    bumpCounter(targetKey, "upstream_ok", 1);
    setDiag("upstream-ok");

    cfheader(statuscode=200);
    cfcontent(type=contentType, reset=true, variable=bytes);

    setting enablecfoutputonly=false;
    return;
  }

  /* ============================================================================
     Remote: stats()  (Tile health counters)
     Usage:
       /fpw/api/v1/wmsProxy.cfc?method=stats
       /fpw/api/v1/wmsProxy.cfc?method=stats&reset=1
     ============================================================================ */
  remote void function stats(string reset="") output=true {
    setting enablecfoutputonly=true;
    setting showdebugoutput=false;

    if (!structKeyExists(session, "user") || !isStruct(session.user)) {
      sendJson(401, { success=false, AUTH=false, error="UNAUTHORIZED", message="Login required." });
      return;
    }

    initCountersIfNeeded();

    var doReset = (trim(arguments.reset) == "1" || getUrlParam("reset") == "1");

    if (doReset) {
      lock scope="application" type="exclusive" timeout="5" {
        application.fpwWmsCounters = {
          startedAt = dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss"),
          totals = { requests=0, getmap=0, getcapabilities=0 },
          byTarget = {}
        };
      }
    }

    // Snapshot (avoid holding lock while serializing)
    var snap = {};
    lock scope="application" type="readonly" timeout="5" {
      snap = duplicate(application.fpwWmsCounters);
    }

    // Add some derived rollups
    var rollup = {
      startedAt = snap.startedAt,
      totals = snap.totals,
      byTarget = snap.byTarget,
      derived = { byTarget = {} }
    };

    for (var t in rollup.byTarget) {
      var r = rollup.byTarget[t];
      var failures = (r.fallback_upstream ?: 0) + (r.fallback_exception ?: 0) + (r.fallback_read ?: 0);
      var successes = (r.upstream_ok ?: 0) + (r.cache_hit ?: 0);
      var total = (r.requests ?: 0);
      rollup.derived.byTarget[t] = {
        successRate = (total > 0 ? (successes / total) : 0),
        failureRate = (total > 0 ? (failures / total) : 0),
        failures = failures,
        successes = successes
      };
    }

    sendJson(200, { success=true, counters=rollup });
  }

}
