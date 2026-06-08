<cfsetting showdebugoutput="false" requesttimeout="120">
<cfcontent type="application/json; charset=utf-8" reset="true">

<cfscript>
probeToken = "fpw-wms-probe-20260524";

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

surfaceFrontsUrl =
  "https://mapservices.weather.noaa.gov/vector/services/outlooks/natl_fcst_wx_chart/MapServer/WMSServer"
  & "?SERVICE=WMS"
  & "&REQUEST=GetMap"
  & "&LAYERS=34"
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

function dnsProbe(required string hostName) {
  var started = getTickCount();
  var out = {
    host = arguments.hostName,
    elapsedMs = 0,
    addresses = [],
    success = false,
    error = ""
  };

  try {
    var inet = createObject("java", "java.net.InetAddress");
    var addrs = inet.getAllByName(arguments.hostName);

    for (var i = 1; i <= arrayLen(addrs); i++) {
      arrayAppend(out.addresses, addrs[i].getHostAddress());
    }

    out.success = true;
  } catch (any e) {
    out.error = e.message;
  }

  out.elapsedMs = getTickCount() - started;
  return out;
}

function cfhttpProbe(
  required string label,
  required string testUrl,
  required boolean writeToFile,
  required string connectionHeader
) {
  var started = getTickCount();
  var tempDir = getTempDirectory();
  var tempName = "wms_probe_" & createUUID() & ".bin";
  var tempPath = tempDir & tempName;
  var httpRes = {};
  var out = {
    label = arguments.label,
    writeToFile = arguments.writeToFile,
    connectionHeader = arguments.connectionHeader,
    elapsedMs = 0,
    success = false,
    statusCode = "",
    mimeType = "",
    contentLength = 0,
    responseHeaders = {},
    error = ""
  };

  try {
    if (arguments.writeToFile) {
      cfhttp(
        url = arguments.testUrl,
        method = "get",
        timeout = "30",
        getAsBinary = "yes",
        path = tempDir,
        file = tempName,
        result = "httpRes"
      ) {
        cfhttpparam(type="header", name="User-Agent", value="FPW-WMSProbe/1.0");
        cfhttpparam(type="header", name="Accept", value="image/png,image/*,*/*");
        cfhttpparam(type="header", name="Accept-Language", value="en-US,en;q=0.9");
        if (len(arguments.connectionHeader)) {
          cfhttpparam(type="header", name="Connection", value=arguments.connectionHeader);
        }
      }

      if (fileExists(tempPath)) {
        out.contentLength = getFileInfo(tempPath).size;
        fileDelete(tempPath);
      }
    } else {
      cfhttp(
        url = arguments.testUrl,
        method = "get",
        timeout = "30",
        getAsBinary = "yes",
        result = "httpRes"
      ) {
        cfhttpparam(type="header", name="User-Agent", value="FPW-WMSProbe/1.0");
        cfhttpparam(type="header", name="Accept", value="image/png,image/*,*/*");
        cfhttpparam(type="header", name="Accept-Language", value="en-US,en;q=0.9");
        if (len(arguments.connectionHeader)) {
          cfhttpparam(type="header", name="Connection", value=arguments.connectionHeader);
        }
      }

      if (structKeyExists(httpRes, "fileContent")) {
        out.contentLength = len(toBase64(httpRes.fileContent));
      }
    }

    out.success = true;
    out.statusCode = httpRes.statusCode ?: "";
    out.mimeType = httpRes.mimeType ?: "";
    out.responseHeaders = httpRes.responseHeader ?: {};
  } catch (any e) {
    out.error = e.message & " " & e.detail;
    if (fileExists(tempPath)) {
      fileDelete(tempPath);
    }
  }

  out.elapsedMs = getTickCount() - started;
  return out;
}

report = {
  success = true,
  generatedAt = dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss"),
  serverName = cgi.server_name ?: "",
  dns = [
    dnsProbe("mapservices.weather.noaa.gov"),
    dnsProbe("nowcoast.noaa.gov")
  ],
  tests = [
    cfhttpProbe("radar-mapservices-file-connection-close", radarUrl, true, "close"),
    cfhttpProbe("radar-mapservices-memory-connection-close", radarUrl, false, "close"),
    cfhttpProbe("radar-mapservices-file-no-connection-header", radarUrl, true, ""),
    cfhttpProbe("surface-fronts-mapservices-file-connection-close", surfaceFrontsUrl, true, "close"),
    cfhttpProbe("nowcoast-satellite-file-connection-close", nowCoastUrl, true, "close")
  ]
};

writeOutput(serializeJSON(report));
</cfscript>