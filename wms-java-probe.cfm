<cfsetting showdebugoutput="false" requesttimeout="120">
<cfcontent type="application/json; charset=utf-8" reset="true">

<cfscript>
probeToken = "fpw-wms-java-probe-20260524";

if (!structKeyExists(url, "token") || url.token != probeToken) {
  writeOutput(serializeJSON({
    success = false,
    error = "UNAUTHORIZED",
    message = "Missing or invalid token."
  }));
  abort;
}

radarUrl =
  "https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer"
  & "?SERVICE=WMS"
  & "&REQUEST=GetMap"
  & "&LAYERS=radar_base_reflectivity_time"
  & "&STYLES="
  & "&FORMAT=image/png"
  & "&TRANSPARENT=true"
  & "&VERSION=1.3.0"
  & "&WIDTH=256"
  & "&HEIGHT=256"
  & "&CRS=EPSG:3857"
  & "&BBOX=-8766409.899970295,2504688.542848655,-8453323.832114214,2817774.6107047372";

nowCoastUrl =
  "https://nowcoast.noaa.gov/geoserver/ows"
  & "?SERVICE=WMS"
  & "&REQUEST=GetMap"
  & "&LAYERS=satellite:goes_visible_imagery"
  & "&STYLES="
  & "&FORMAT=image/png"
  & "&TRANSPARENT=true"
  & "&VERSION=1.3.0"
  & "&WIDTH=256"
  & "&HEIGHT=256"
  & "&CRS=EPSG:3857"
  & "&BBOX=-8766409.899970295,2504688.542848655,-8453323.832114214,2817774.6107047372";

function javaHttpProbe(required string label, required string testUrl) {
  var started = getTickCount();
  var out = {
    label = arguments.label,
    elapsedMs = 0,
    success = false,
    statusCode = 0,
    contentType = "",
    contentLength = 0,
    firstReadMs = 0,
    connectTimeoutMs = 8000,
    readTimeoutMs = 8000,
    error = "",
    responseHeaders = {}
  };

  var conn = javacast("null", 0);
  var inputStream = javacast("null", 0);

  try {
    var urlObj = createObject("java", "java.net.URL").init(arguments.testUrl);
    conn = urlObj.openConnection();

    conn.setRequestMethod("GET");
    conn.setConnectTimeout(out.connectTimeoutMs);
    conn.setReadTimeout(out.readTimeoutMs);
    conn.setRequestProperty("User-Agent", "FPW-JavaProbe/1.0");
    conn.setRequestProperty("Accept", "image/png,image/*,*/*");
    conn.setRequestProperty("Accept-Language", "en-US,en;q=0.9");
    conn.setRequestProperty("Connection", "close");

    var beforeResponse = getTickCount();
    out.statusCode = conn.getResponseCode();
    out.contentType = conn.getContentType() ?: "";

    var headerFields = conn.getHeaderFields();
    var headerIterator = headerFields.keySet().iterator();

    while (headerIterator.hasNext()) {
      var headerName = headerIterator.next();
      var headerValue = headerFields.get(headerName);

      if (!isNull(headerName) && !isNull(headerValue)) {
        out.responseHeaders[toString(headerName)] = toString(headerValue);
      }
    }

    inputStream = conn.getInputStream();

    var buffer = repeatString(" ", 8192).getBytes();
    var firstReadStarted = getTickCount();
    var readCount = inputStream.read(buffer);
    out.firstReadMs = getTickCount() - firstReadStarted;

    while (readCount > 0) {
      out.contentLength += readCount;
      readCount = inputStream.read(buffer);
    }

    out.success = true;
  } catch (any e) {
    out.error = e.message & " " & e.detail;
  }

  try {
    if (!isNull(inputStream)) {
      inputStream.close();
    }
  } catch (any closeErr) {}

  try {
    if (!isNull(conn)) {
      conn.disconnect();
    }
  } catch (any disconnectErr) {}

  out.elapsedMs = getTickCount() - started;
  return out;
}

function cfhttpProbe(required string label, required string testUrl) {
  var started = getTickCount();
  var httpRes = {};
  var out = {
    label = arguments.label,
    elapsedMs = 0,
    success = false,
    statusCode = "",
    mimeType = "",
    contentLength = 0,
    error = "",
    responseHeaders = {}
  };

  try {
    cfhttp(
      url = arguments.testUrl,
      method = "get",
      timeout = "8",
      getAsBinary = "yes",
      result = "httpRes"
    ) {
      cfhttpparam(type="header", name="User-Agent", value="FPW-CFHTTPProbe/1.0");
      cfhttpparam(type="header", name="Accept", value="image/png,image/*,*/*");
      cfhttpparam(type="header", name="Accept-Language", value="en-US,en;q=0.9");
      cfhttpparam(type="header", name="Connection", value="close");
    }

    out.success = true;
    out.statusCode = httpRes.statusCode ?: "";
    out.mimeType = httpRes.mimeType ?: "";
    out.responseHeaders = httpRes.responseHeader ?: {};

    if (structKeyExists(httpRes, "fileContent")) {
      out.contentLength = len(toBase64(httpRes.fileContent));
    }
  } catch (any e) {
    out.error = e.message & " " & e.detail;
  }

  out.elapsedMs = getTickCount() - started;
  return out;
}

report = {
  success = true,
  generatedAt = dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss"),
  serverName = cgi.server_name ?: "",
  javaVersion = createObject("java", "java.lang.System").getProperty("java.version"),
  javaVendor = createObject("java", "java.lang.System").getProperty("java.vendor"),
  tests = [
    javaHttpProbe("java-httpurlconnection-radar-mapservices", radarUrl),
    cfhttpProbe("cfhttp-radar-mapservices", radarUrl),
    javaHttpProbe("java-httpurlconnection-nowcoast", nowCoastUrl),
    cfhttpProbe("cfhttp-nowcoast", nowCoastUrl)
  ]
};

writeOutput(serializeJSON(report));
</cfscript>