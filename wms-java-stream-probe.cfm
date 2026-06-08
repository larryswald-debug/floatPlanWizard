<cfsetting showdebugoutput="false" requesttimeout="60">
<cfcontent type="application/json; charset=utf-8" reset="true">

<cfscript>
probeToken = "fpw-wms-java-stream-probe-20260524";

if (!structKeyExists(url, "token") || url.token != probeToken) {
  writeOutput(serializeJSON({
    success = false,
    error = "UNAUTHORIZED"
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

function javaStreamProbe(required string label, required string testUrl) {
  var started = getTickCount();
  var out = {
    label = arguments.label,
    success = false,
    elapsedMs = 0,
    bytesRead = 0,
    firstByteMs = 0,
    error = ""
  };

  var inputStream = javacast("null", 0);

  try {
    var urlObj = createObject("java", "java.net.URL").init(arguments.testUrl);
    var firstByteStarted = getTickCount();

    inputStream = urlObj.openStream();

    var firstByte = inputStream.read();
    out.firstByteMs = getTickCount() - firstByteStarted;

    if (firstByte >= 0) {
      out.bytesRead = 1;
    }

    var buffer = repeatString(" ", 8192).getBytes();
    var readCount = inputStream.read(buffer);

    while (readCount > 0) {
      out.bytesRead += readCount;
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

  out.elapsedMs = getTickCount() - started;
  return out;
}

report = {
  success = true,
  generatedAt = dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss"),
  javaVersion = createObject("java", "java.lang.System").getProperty("java.version"),
  tests = [
    javaStreamProbe("java-openstream-radar-mapservices", radarUrl),
    javaStreamProbe("java-openstream-nowcoast", nowCoastUrl)
  ]
};

writeOutput(serializeJSON(report));
</cfscript>