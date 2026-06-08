<cfsetting showdebugoutput="false" requesttimeout="120">
<cfcontent type="application/json; charset=utf-8" reset="true">

<cfscript>
probeToken = "fpw-wms-ip-probe-20260524";

if (!structKeyExists(url, "token") || url.token != probeToken) {
  writeOutput(serializeJSON({
    success = false,
    error = "UNAUTHORIZED"
  }));
  abort;
}

ips = [
  "137.75.95.170",
  "137.75.95.183",
  "137.75.95.186"
];

pathAndQuery =
  "/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer"
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

function cfhttpIpProbe(required string ipAddress) {
  var started = getTickCount();
  var httpRes = {};
  var testUrl = "https://" & arguments.ipAddress & pathAndQuery;

  var out = {
    ip = arguments.ipAddress,
    url = testUrl,
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
      url = testUrl,
      method = "get",
      timeout = "12",
      getAsBinary = "yes",
      result = "httpRes"
    ) {
      cfhttpparam(type="header", name="Host", value="mapservices.weather.noaa.gov");
      cfhttpparam(type="header", name="User-Agent", value="FPW-WMSIpProbe/1.0");
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

tests = [];

for (ip in ips) {
  arrayAppend(tests, cfhttpIpProbe(ip));
}

writeOutput(serializeJSON({
  success = true,
  generatedAt = dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss"),
  serverName = cgi.server_name ?: "",
  tests = tests
}));
</cfscript>