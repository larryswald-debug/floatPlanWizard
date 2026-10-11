<cfsetting showdebugoutput="false" requesttimeout="30">
<cfcontent type="text/html; charset=utf-8">
<cfheader name="Cache-Control" value="no-store">
<cfheader name="Pragma" value="no-cache">
<cfheader name="X-Content-Type-Options" value="nosniff">
<cfheader name="X-Robots-Tag" value="noindex, nofollow">
<cfheader name="Referrer-Policy" value="no-referrer">
<cfheader name="Content-Security-Policy" value="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'">
<!--- Temporary diagnostic. Application.cfc performs the existing administrator entitlement check.
      This second guard fails closed if the central authorization context is absent.
      No bypass, user-selected SQL, operational service invocation, or persistent diagnostic logging. --->
<cfif NOT structKeyExists(request, "fpwAdminAuthorization")
    OR NOT isStruct(request.fpwAdminAuthorization)
    OR NOT structKeyExists(request.fpwAdminAuthorization, "authenticated")
    OR NOT request.fpwAdminAuthorization.authenticated
    OR NOT structKeyExists(request.fpwAdminAuthorization, "authorized")
    OR NOT request.fpwAdminAuthorization.authorized
    OR NOT structKeyExists(request.fpwAdminAuthorization, "userId")
    OR NOT isNumeric(request.fpwAdminAuthorization.userId)
    OR request.fpwAdminAuthorization.userId LTE 0>
    <cfheader statuscode="403">
    <cfoutput>Administrative access is required.</cfoutput>
    <cfabort>
</cfif>
<cfif NOT listFindNoCase("GET,HEAD", cgi.request_method)>
    <cfheader statuscode="405">
    <cfheader name="Allow" value="GET, HEAD">
    <cfoutput>Use GET for this read-only diagnostic.</cfoutput>
    <cfabort>
</cfif>
<cfif compareNoCase(cgi.request_method, "HEAD") EQ 0><cfabort></cfif>
<cfif NOT structKeyExists(application, "dsn") OR compareNoCase(toString(application.dsn), "fpw") NEQ 0>
    <cfheader statuscode="503">
    <cfoutput>The expected application datasource is unavailable.</cfoutput>
    <cfabort>
</cfif>
<cfscript>
function mtRead(required any operation) {
    try {
        return { "available" = true, "value" = arguments.operation() };
    } catch (any diagnosticUnavailable) {
        // Never expose or persist exception messages, details, paths, URLs or traces.
        return { "available" = false, "value" = "Unavailable: this read-only probe was not supported or failed." };
    }
}

function mtAdd(required array rows, required string label, required any operation) {
    arrayAppend(arguments.rows, { "label" = arguments.label, "result" = mtRead(arguments.operation) });
    return arguments.rows;
}

// Controlled equivalent of Monitor formatLocalLabel(), with an observable fallback flag.
function mtMonitor(required any value, string timezone="UTC") {
    var tz = len(trim(arguments.timezone)) ? trim(arguments.timezone) : "UTC";
    var result = { "requestedTimezone" = tz, "label" = "", "fallbackUsed" = false };
    if (!isDate(arguments.value)) return result;
    try {
        result.label = dateTimeFormat(arguments.value, "mmm d, yyyy h:nn tt", tz);
    } catch (any monitorFormattingUnavailable) {
        result.fallbackUsed = true;
        result.label = dateTimeFormat(arguments.value, "mmm d, yyyy h:nn tt");
    }
    return result;
}

// Controlled equivalent of Active Cruise's conversion for this fixed SQL probe only.
// It is not an invocation of either operational view-model service.
function mtExplicitUtc(required string rawUtc, required string timezone) {
    var tz = arguments.timezone EQ "US/Eastern" ? "America/New_York" : arguments.timezone;
    var instant = parseDateTime(replace(arguments.rawUtc, " ", "T", "one") & "Z");
    return dateTimeFormat(instant, "mmm d, yyyy h:nn tt", tz);
}

mtSections = [];
mtCfRows = [];
mtCfRows = mtAdd(mtCfRows, "ColdFusion version/build", function() { return toString(server.coldfusion.productVersion); });
mtCfRows = mtAdd(mtCfRows, "getTimeZone().timezone", function() { return toString(getTimeZone().timezone); });
mtCfRows = mtAdd(mtCfRows, "Current CF request clock and ISO offset", function() { return dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss Z"); });
mtCfZoneInfo = mtRead(function() { return getTimeZoneInfo(); });
if (mtCfZoneInfo.available) {
    for (mtKey in listToArray("utcTotalOffset,utcHourOffset,utcMinuteOffset,isDSTOn,timezone,name,shortName,DSTOffset")) {
        if (structKeyExists(mtCfZoneInfo.value, mtKey) AND isSimpleValue(mtCfZoneInfo.value[mtKey])) {
            arrayAppend(mtCfRows, { "label" = "getTimeZoneInfo()." & mtKey, "result" = { "available" = true, "value" = mtCfZoneInfo.value[mtKey] } });
        }
    }
} else {
    arrayAppend(mtCfRows, { "label" = "getTimeZoneInfo()", "result" = mtCfZoneInfo });
}
arrayAppend(mtSections, { "title" = "ColdFusion request", "rows" = mtCfRows });

mtJavaRows = [];
mtJavaRows = mtAdd(mtJavaRows, "Java version", function() { return createObject("java", "java.lang.System").getProperty("java.version", "Unavailable"); });
mtJavaRows = mtAdd(mtJavaRows, "Java user.timezone property", function() { return createObject("java", "java.lang.System").getProperty("user.timezone", "Unset"); });
// Public reflection avoids CF introspection of the JDK's non-public ZoneInfo implementation.
// No setAccessible, internal APIs, property enumeration, or configuration changes are used.
mtJvm = mtRead(function() {
    var tzClass = createObject("java", "java.lang.Class").forName("java.util.TimeZone");
    var zone = tzClass.getMethod("getDefault", javacast("null", "")).invoke(javacast("null", ""), javacast("null", ""));
    var instantMillis = createObject("java", "java.lang.System").currentTimeMillis();
    return {
        "timezoneId" = tzClass.getMethod("getID", javacast("null", "")).invoke(zone, javacast("null", "")),
        "currentUtcOffsetMilliseconds" = tzClass.getMethod("getOffset", [createObject("java", "java.lang.Long").TYPE]).invoke(zone, [javacast("long", instantMillis)]),
        "usesDaylightTimeRules" = tzClass.getMethod("useDaylightTime", javacast("null", "")).invoke(zone, javacast("null", "")),
        "observesDaylightTime" = tzClass.getMethod("observesDaylightTime", javacast("null", "")).invoke(zone, javacast("null", ""))
    };
});
arrayAppend(mtJavaRows, { "label" = "JVM default timezone and current offset", "result" = mtJvm });
arrayAppend(mtSections, { "title" = "Java / JVM", "rows" = mtJavaRows });

mtDbRows = [];
mtProbeRows = [];
mtFormatterRows = [];
try {
    // One SELECT: constant DATETIME and timezone measurements share the same JDBC connection.
    // Raw clock columns are text so JDBC cannot reinterpret their wall-clock values.
    mtQuery = queryExecute(
        "SELECT
            CAST('2026-10-10 18:00:00' AS DATETIME) AS probe_date,
            CAST(CAST('2026-10-10 18:00:00' AS DATETIME) AS CHAR) AS probe_raw,
            VERSION() AS database_version,
            @@global.time_zone AS global_timezone,
            @@session.time_zone AS session_timezone,
            @@system_time_zone AS system_timezone,
            CAST(NOW(3) AS CHAR) AS database_now_raw,
            CAST(UTC_TIMESTAMP(3) AS CHAR) AS utc_now_raw",
        {},
        { datasource = application.dsn, timeout = 10 }
    );
    for (mtColumn in listToArray("database_version,global_timezone,session_timezone,system_timezone,database_now_raw,utc_now_raw")) {
        arrayAppend(mtDbRows, { "label" = mtColumn, "result" = { "available" = true, "value" = toString(mtQuery[mtColumn][1]) } });
    }
    mtValue = mtQuery.probe_date[1];
    mtRaw = toString(mtQuery.probe_raw[1]);
    arrayAppend(mtProbeRows, { "label" = "Raw SQL string (interpret as UTC)", "result" = { "available" = true, "value" = mtRaw } });
    mtProbeRows = mtAdd(mtProbeRows, "CFML value formatted in the request timezone", function() { return dateTimeFormat(mtValue, "yyyy-mm-dd HH:nn:ss Z"); });
    mtProbeRows = mtAdd(mtProbeRows, "Underlying Java class", function() { return mtValue.getClass().getName(); });
    mtEpoch = mtRead(function() { return mtValue.getTime(); });
    arrayAppend(mtProbeRows, { "label" = "Interpreted epoch milliseconds", "result" = mtEpoch });
    arrayAppend(mtProbeRows, { "label" = "Expected epoch milliseconds", "result" = { "available" = true, "value" = "1791655200000" } });
    if (mtEpoch.available) {
        arrayAppend(mtProbeRows, { "label" = "Epoch matches expected", "result" = { "available" = true, "value" = mtEpoch.value EQ 1791655200000 } });
    }
    mtProbeRows = mtAdd(mtProbeRows, "Default CF formatting", function() { return dateTimeFormat(mtValue, "mmm d, yyyy h:nn tt"); });
    mtProbeRows = mtAdd(mtProbeRows, "Explicit UTC formatting", function() { return dateTimeFormat(mtValue, "yyyy-mm-dd HH:nn:ss Z", "UTC"); });
    mtProbeRows = mtAdd(mtProbeRows, "America/New_York formatting", function() { return dateTimeFormat(mtValue, "mmm d, yyyy h:nn tt", "America/New_York"); });
    mtProbeRows = mtAdd(mtProbeRows, "US/Eastern formatting", function() { return dateTimeFormat(mtValue, "mmm d, yyyy h:nn tt", "US/Eastern"); });
    arrayAppend(mtProbeRows, { "label" = "Expected Eastern result", "result" = { "available" = true, "value" = "October 10, 2026, 2:00 PM EDT (UTC-04:00)" } });

    mtFormatterRows = mtAdd(mtFormatterRows, "Direct database date object / Eastern", function() { return dateTimeFormat(mtValue, "mmm d, yyyy h:nn tt", "America/New_York"); });
    mtFormatterRows = mtAdd(mtFormatterRows, "Monitor equivalent / America/New_York", function() { return mtMonitor(mtValue, "America/New_York"); });
    mtFormatterRows = mtAdd(mtFormatterRows, "Monitor equivalent / US/Eastern", function() { return mtMonitor(mtValue, "US/Eastern"); });
    mtFormatterRows = mtAdd(mtFormatterRows, "Active Cruise explicit-UTC equivalent / Eastern", function() { return mtExplicitUtc(mtRaw, "America/New_York"); });
    mtFormatterRows = mtAdd(mtFormatterRows, "Active Cruise explicit-UTC equivalent / US/Eastern", function() { return mtExplicitUtc(mtRaw, "US/Eastern"); });
    mtInvalid = mtRead(function() { return mtMonitor(mtValue, "FPW/Invalid_Time_Zone"); });
    arrayAppend(mtFormatterRows, { "label" = "Monitor equivalent / deliberately invalid timezone", "result" = mtInvalid });
    if (mtInvalid.available) {
        mtFormatterRows = mtAdd(mtFormatterRows, "Invalid-zone fallback equals default CF label", function() {
            return mtInvalid.value.fallbackUsed AND mtInvalid.value.label EQ dateTimeFormat(mtValue, "mmm d, yyyy h:nn tt");
        });
    }
} catch (any constantProbeUnavailable) {
    arrayAppend(mtDbRows, { "label" = "Combined constant/timezone SELECT", "result" = { "available" = false, "value" = "Unavailable: the constant database probe failed. No exception details are exposed." } });
}

try {
    cfdbinfo(type="version", datasource=application.dsn, name="mtDriverInfo");
    for (mtColumn in listToArray("DATABASE_PRODUCTNAME,DATABASE_VERSION,DRIVER_NAME,DRIVER_VERSION,JDBC_MAJOR_VERSION,JDBC_MINOR_VERSION")) {
        if (listFindNoCase(mtDriverInfo.columnList, mtColumn) AND mtDriverInfo.recordCount GT 0) {
            arrayAppend(mtDbRows, { "label" = mtColumn, "result" = { "available" = true, "value" = toString(mtDriverInfo[mtColumn][1]) } });
        }
    }
} catch (any driverMetadataUnavailable) {
    arrayAppend(mtDbRows, { "label" = "JDBC driver metadata", "result" = { "available" = false, "value" = "Unavailable: safe driver metadata could not be read." } });
}
arrayAppend(mtDbRows, { "label" = "Effective JDBC timezone properties", "result" = { "available" = false, "value" = "Unavailable through the safe metadata API. Datasource settings and connection URLs were not inspected; no property defaults are assumed." } });
arrayAppend(mtSections, { "title" = "Database / JDBC", "rows" = mtDbRows });
arrayAppend(mtSections, { "title" = "Constant UTC timestamp probe", "rows" = mtProbeRows });
arrayAppend(mtSections, { "title" = "Isolated formatter comparison", "rows" = mtFormatterRows });
</cfscript>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Temporary Monitor timezone diagnostic</title>
<style>
body { font: 16px/1.5 system-ui, sans-serif; max-width: 1100px; margin: 2rem auto; padding: 0 1rem; color: #172033; }
h1 { font-size: 1.6rem; } h2 { font-size: 1.2rem; margin-top: 2rem; }
table { width: 100%; border-collapse: collapse; table-layout: fixed; }
th, td { border: 1px solid #ccd3dd; padding: .6rem; text-align: left; vertical-align: top; overflow-wrap: anywhere; }
th { width: 38%; background: #f1f4f8; } code { white-space: pre-wrap; }
.unavailable { color: #65521b; }
</style>
</head>
<body>
<h1>Temporary Monitor timezone diagnostic</h1>
<p>Administrator-only, read-only measurements from this ColdFusion request. Remove this page after the approved production investigation.</p>
<p>The SQL probe is an offset-free database value whose intended meaning is UTC. Its raw text and the epoch interpreted by JDBC are shown separately. Formatter comparisons use controlled equivalents; no operational Monitor or Active Cruise method is called.</p>
<p>Java offsets are milliseconds east of UTC. ColdFusion <code>utcTotalOffset</code> is seconds west of UTC. <code>isDSTOn</code> reports current DST; Java daylight-time flags describe the selected zone's rules.</p>
<cfoutput>
<cfloop array="#mtSections#" index="mtSection">
<section>
<h2>#encodeForHTML(mtSection.title)#</h2>
<table>
<tbody>
<cfloop array="#mtSection.rows#" index="mtRow">
<tr>
<th scope="row">#encodeForHTML(mtRow.label)#</th>
<td<cfif NOT mtRow.result.available> class="unavailable"</cfif>><code>#encodeForHTML(isSimpleValue(mtRow.result.value) ? toString(mtRow.result.value) : serializeJSON(mtRow.result.value))#</code></td>
</tr>
</cfloop>
</tbody>
</table>
</section>
</cfloop>
</cfoutput>
<p>Different server timezones alone do not establish a Monitor defect. Compare the epoch and formatter results before drawing a root-cause conclusion.</p>
</body>
</html>
