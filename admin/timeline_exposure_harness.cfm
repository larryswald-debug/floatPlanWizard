<cfsetting showdebugoutput="false">

<cfscript>
userStruct = (structKeyExists(session, "user") AND isStruct(session.user)) ? session.user : {};
isLoggedIn = structCount(userStruct) GT 0;
adminWhitelist = "admin@floatplanwizard.com,lswald@yahoo.com";

function boolLike(any value, boolean defaultValue=false) {
    var txt = lCase(trim(toString(arguments.value)));
    if (!len(txt)) return arguments.defaultValue;
    if (listFindNoCase("1,true,yes,y,on", txt)) return true;
    if (listFindNoCase("0,false,no,n,off", txt)) return false;
    if (isNumeric(txt)) return (val(txt) NEQ 0);
    return arguments.defaultValue;
}

function emailFromUser(required struct u) {
    if (structKeyExists(arguments.u, "email")) return lCase(trim(toString(arguments.u.email)));
    if (structKeyExists(arguments.u, "EMAIL")) return lCase(trim(toString(arguments.u.EMAIL)));
    return "";
}

function roleFromUser(required struct u) {
    if (structKeyExists(arguments.u, "role")) return lCase(trim(toString(arguments.u.role)));
    if (structKeyExists(arguments.u, "ROLE")) return lCase(trim(toString(arguments.u.ROLE)));
    return "";
}

function resolveUserId(required struct u) {
    var keys = ["userId", "USERID", "id", "ID", "user_id", "USER_ID"];
    var v = 0;
    for (var k in keys) {
        if (!structKeyExists(arguments.u, k)) continue;
        if (isNumeric(arguments.u[k])) {
            v = int(val(arguments.u[k]));
            if (v GT 0) return v;
        }
    }
    return 0;
}

function hasExposureLevelColumn() {
    var qCol = queryExecute(
        "SELECT COUNT(*) AS cnt
         FROM information_schema.columns
         WHERE table_schema = DATABASE()
           AND table_name = 'segment_library'
           AND column_name = 'exposure_level'",
        {},
        { datasource = application.dsn }
    );
    return (qCol.recordCount GT 0 AND val(qCol.cnt[1]) GT 0);
}

function getCookiePairs() {
    var pairs = [];
    var names = ["CFID", "CFTOKEN", "JSESSIONID"];
    for (var n in names) {
        if (!structKeyExists(cookie, n)) continue;
        arrayAppend(pairs, { "name"=n, "value"=toString(cookie[n]) });
    }
    return pairs;
}

function decodeHttpJson(required struct httpRes) {
    var raw = "";
    if (structKeyExists(arguments.httpRes, "fileContent")) raw = toString(arguments.httpRes.fileContent);
    if (!len(raw)) {
        return { "SUCCESS"=false, "MESSAGE"="Empty response", "RAW"=raw };
    }
    try {
        var parsed = deserializeJSON(raw, false, false, true);
        if (isStruct(parsed)) return parsed;
        return { "SUCCESS"=false, "MESSAGE"="Response JSON was not an object", "RAW"=raw };
    } catch (any e) {
        return { "SUCCESS"=false, "MESSAGE"="Response was not valid JSON", "ERROR"=e.message, "RAW"=raw };
    }
}

function callRouteBuilder(required string action, required struct payload) {
    var proto = (structKeyExists(cgi, "HTTPS") AND lCase(toString(cgi.HTTPS)) EQ "on") ? "https" : "http";
    var host = structKeyExists(cgi, "HTTP_HOST") ? toString(cgi.HTTP_HOST) : (toString(cgi.SERVER_NAME) & ":" & toString(cgi.SERVER_PORT));
    var fpwBase = "/fpw";
    var res = {};
    var cookiePairs = getCookiePairs();
    var targetUrl = proto & "://" & host & fpwBase & "/api/v1/routeBuilder.cfc?method=handle&action=" & urlEncodedFormat(arguments.action);

    cfhttp(method="POST", url=targetUrl, timeout="60", result="res") {
        cfhttpparam(type="header", name="Accept", value="application/json");
        cfhttpparam(type="header", name="Content-Type", value="application/json; charset=utf-8");
        cfhttpparam(type="body", value=serializeJSON(arguments.payload));
        for (var p in cookiePairs) {
            cfhttpparam(type="cookie", name=p.name, value=p.value);
        }
    }
    return decodeHttpJson(res);
}

function pickFirst(required struct source, required array keys, any defaultValue="") {
    for (var k in arguments.keys) {
        if (structKeyExists(arguments.source, k)) return arguments.source[k];
    }
    return arguments.defaultValue;
}

function sumTimelineHours(any daysRaw) {
    var total = 0;
    var days = isArray(arguments.daysRaw) ? arguments.daysRaw : [];
    for (var d in days) {
        if (!isStruct(d)) continue;
        total += val(pickFirst(d, ["est_hours", "EST_HOURS"], 0));
    }
    return round(total * 100) / 100;
}

function makeFlattenedRow(required string responseLabel, required string path, required string valueType, required string valueText) {
    return {
        "response" = arguments.responseLabel,
        "path" = arguments.path,
        "type" = arguments.valueType,
        "value" = arguments.valueText
    };
}

function flattenJsonRows(required any value, required string basePath, required string responseLabel) {
    var rows = [];
    var currentPath = len(trim(arguments.basePath)) ? arguments.basePath : "$";
    var valueRef = arguments.value;
    var keys = [];
    var childRows = [];
    var childPath = "";

    if (isNull(valueRef)) {
        arrayAppend(rows, makeFlattenedRow(arguments.responseLabel, currentPath, "null", "NULL"));
        return rows;
    }

    if (isStruct(valueRef)) {
        keys = structKeyArray(valueRef);
        if (!arrayLen(keys)) {
            arrayAppend(rows, makeFlattenedRow(arguments.responseLabel, currentPath, "struct", "(empty struct)"));
            return rows;
        }
        arraySort(keys, "textnocase");
        for (var k in keys) {
            childPath = currentPath & "." & k;
            if (!structKeyExists(valueRef, k) OR isNull(valueRef[k])) {
                arrayAppend(rows, makeFlattenedRow(arguments.responseLabel, childPath, "null", "NULL"));
                continue;
            }
            childRows = flattenJsonRows(valueRef[k], childPath, arguments.responseLabel);
            arrayAppend(rows, childRows, true);
        }
        return rows;
    }

    if (isArray(valueRef)) {
        if (!arrayLen(valueRef)) {
            arrayAppend(rows, makeFlattenedRow(arguments.responseLabel, currentPath, "array", "(empty array)"));
            return rows;
        }
        for (var i = 1; i <= arrayLen(valueRef); i++) {
            childPath = currentPath & "[" & i & "]";
            if (isNull(valueRef[i])) {
                arrayAppend(rows, makeFlattenedRow(arguments.responseLabel, childPath, "null", "NULL"));
                continue;
            }
            childRows = flattenJsonRows(valueRef[i], childPath, arguments.responseLabel);
            arrayAppend(rows, childRows, true);
        }
        return rows;
    }

    if (isNumeric(valueRef)) {
        arrayAppend(rows, makeFlattenedRow(arguments.responseLabel, currentPath, "numeric", toString(valueRef)));
        return rows;
    }

    if (isBoolean(valueRef) AND listFindNoCase("true,false", lCase(trim(toString(valueRef))))) {
        arrayAppend(rows, makeFlattenedRow(arguments.responseLabel, currentPath, "boolean", lCase(toString(valueRef))));
        return rows;
    }

    if (isDate(valueRef)) {
        arrayAppend(rows, makeFlattenedRow(arguments.responseLabel, currentPath, "datetime", dateTimeFormat(valueRef, "yyyy-mm-dd HH:nn:ss")));
        return rows;
    }

    if (isSimpleValue(valueRef)) {
        arrayAppend(rows, makeFlattenedRow(arguments.responseLabel, currentPath, "string", toString(valueRef)));
        return rows;
    }

    arrayAppend(rows, makeFlattenedRow(arguments.responseLabel, currentPath, "unknown", toString(valueRef)));
    return rows;
}

function resolveRouteInstanceId(required numeric routeId, required numeric userId) {
    var qInst = queryExecute(
        "SELECT id
         FROM route_instances
         WHERE generated_route_id = :routeId
           AND user_id = :uid
         ORDER BY id DESC
         LIMIT 1",
        {
            routeId = { value=arguments.routeId, cfsqltype="cf_sql_integer" },
            uid = { value=toString(arguments.userId), cfsqltype="cf_sql_varchar" }
        },
        { datasource = application.dsn }
    );
    if (qInst.recordCount EQ 0 OR isNull(qInst.id[1])) return 0;
    return val(qInst.id[1]);
}

function resolveFirstSegment(required numeric routeInstanceId) {
    var qSeg = queryExecute(
        "SELECT segment_id, leg_order, start_name, end_name
         FROM route_instance_legs
         WHERE route_instance_id = :routeInstanceId
           AND segment_id IS NOT NULL
         ORDER BY leg_order ASC, id ASC
         LIMIT 1",
        {
            routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" }
        },
        { datasource = application.dsn }
    );
    if (qSeg.recordCount EQ 0) return {};
    return {
        "segment_id"=(isNull(qSeg.segment_id[1]) ? 0 : val(qSeg.segment_id[1])),
        "leg_order"=(isNull(qSeg.leg_order[1]) ? 0 : val(qSeg.leg_order[1])),
        "start_name"=(isNull(qSeg.start_name[1]) ? "" : trim(toString(qSeg.start_name[1]))),
        "end_name"=(isNull(qSeg.end_name[1]) ? "" : trim(toString(qSeg.end_name[1])))
    };
}

function readExposure(required numeric segmentId) {
    var q = queryExecute(
        "SELECT exposure_level
         FROM segment_library
         WHERE id = :segmentId
         LIMIT 1",
        {
            segmentId = { value=arguments.segmentId, cfsqltype="cf_sql_integer" }
        },
        { datasource = application.dsn }
    );
    if (q.recordCount EQ 0) return { "found"=false, "isNull"=true, "value"=0 };
    if (isNull(q.exposure_level[1])) return { "found"=true, "isNull"=true, "value"=0 };
    return { "found"=true, "isNull"=false, "value"=int(val(q.exposure_level[1])) };
}

function writeExposure(required numeric segmentId, required any exposureValue) {
    var isNullVal = isNull(arguments.exposureValue);
    var levelVal = (isNullVal ? 0 : int(val(arguments.exposureValue)));
    if (!isNullVal) {
        if (levelVal LT 0) levelVal = 0;
        if (levelVal GT 3) levelVal = 3;
    }
    queryExecute(
        "UPDATE segment_library
         SET exposure_level = :exposureLevel
         WHERE id = :segmentId",
        {
            exposureLevel = (isNullVal
                ? { value=0, null=true, cfsqltype="cf_sql_tinyint" }
                : { value=levelVal, cfsqltype="cf_sql_tinyint" }),
            segmentId = { value=arguments.segmentId, cfsqltype="cf_sql_integer" }
        },
        { datasource = application.dsn }
    );
}

isAdmin = false;
if (isLoggedIn) {
    if (structKeyExists(userStruct, "isAdmin") AND boolLike(userStruct.isAdmin, false)) {
        isAdmin = true;
    } else if (structKeyExists(userStruct, "ISADMIN") AND boolLike(userStruct.ISADMIN, false)) {
        isAdmin = true;
    } else if (structKeyExists(userStruct, "is_admin") AND boolLike(userStruct.is_admin, false)) {
        isAdmin = true;
    } else if (roleFromUser(userStruct) EQ "admin") {
        isAdmin = true;
    } else if (len(emailFromUser(userStruct)) AND listFindNoCase(adminWhitelist, emailFromUser(userStruct))) {
        isAdmin = true;
    }
}

isAuthorized = isLoggedIn AND isAdmin;
request.fpwBase = "/fpw";
activeUserId = resolveUserId(userStruct);

defaults = {
    "routeId"="",
    "startDate"=dateFormat(now(), "yyyy-mm-dd"),
    "segmentId"="",
    "maxHoursPerDay"="6.5",
    "pace"="BALANCED",
    "cruisingSpeed"="20",
    "weatherPct"="30",
    "fuelBurnGph"="8",
    "reservePct"="20"
};
for (dk in defaults) {
    if (!structKeyExists(form, dk)) {
        form[dk] = defaults[dk];
    }
}

didRun = false;
runError = "";
result = {};
responseTableRows = [];
if (isAuthorized AND structKeyExists(form, "runHarness")) {
    didRun = true;
    try {
        if (!hasExposureLevelColumn()) {
            throw(message="Missing segment_library.exposure_level. Run migration first.");
        }
        if (activeUserId LTE 0) {
            throw(message="Could not resolve user id from session.");
        }

        routeIdVal = (isNumeric(form.routeId) ? int(val(form.routeId)) : 0);
        startDateVal = trim(toString(form.startDate));
        segmentIdVal = (isNumeric(form.segmentId) ? int(val(form.segmentId)) : 0);
        maxHoursVal = (isNumeric(form.maxHoursPerDay) ? val(form.maxHoursPerDay) : 6.5);
        paceVal = uCase(trim(toString(form.pace)));
        speedVal = (isNumeric(form.cruisingSpeed) ? val(form.cruisingSpeed) : 20);
        weatherPctVal = (isNumeric(form.weatherPct) ? val(form.weatherPct) : 30);
        fuelBurnVal = (isNumeric(form.fuelBurnGph) ? val(form.fuelBurnGph) : 8);
        reservePctVal = (isNumeric(form.reservePct) ? val(form.reservePct) : 20);

        if (routeIdVal LTE 0) throw(message="routeId must be a positive number.");
        if (!reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", startDateVal)) throw(message="startDate must be yyyy-mm-dd.");
        if (maxHoursVal LT 4) maxHoursVal = 4;
        if (maxHoursVal GT 12) maxHoursVal = 12;
        if (!listFindNoCase("RELAXED,BALANCED,AGGRESSIVE", paceVal)) paceVal = "BALANCED";

        routeInstanceId = resolveRouteInstanceId(routeIdVal, activeUserId);
        if (routeInstanceId LTE 0) {
            throw(message="No route_instances row found for this route and user.");
        }

        segInfo = {};
        if (segmentIdVal GT 0) {
            segInfo = { "segment_id"=segmentIdVal, "leg_order"=0, "start_name"="", "end_name"="" };
        } else {
            segInfo = resolveFirstSegment(routeInstanceId);
            segmentIdVal = (structKeyExists(segInfo, "segment_id") ? val(segInfo.segment_id) : 0);
        }
        if (segmentIdVal LTE 0) throw(message="Unable to resolve segment_id for this route instance.");

        original = readExposure(segmentIdVal);
        if (!original.found) throw(message="segment_library row not found for segment_id=" & segmentIdVal);

        payload = {
            "routeId"=routeIdVal,
            "startDate"=startDateVal,
            "maxHoursPerDay"=maxHoursVal,
            "inputOverrides"={
                "pace"=paceVal,
                "cruising_speed"=speedVal,
                "weather_factor_pct"=weatherPctVal,
                "fuel_burn_gph"=fuelBurnVal,
                "reserve_pct"=reservePctVal
            }
        };

        lowRes = {};
        highRes = {};
        lowHours = 0;
        highHours = 0;
        try {
            writeExposure(segmentIdVal, 0);
            lowRes = callRouteBuilder("generateCruiseTimeline", payload);
            if (!boolLike(pickFirst(lowRes, ["success", "SUCCESS"], false), false)) {
                throw(message="Timeline request failed for exposure 0", detail=serializeJSON(lowRes));
            }
            lowHours = sumTimelineHours(structKeyExists(lowRes, "days") ? lowRes.days : []);

            writeExposure(segmentIdVal, 3);
            highRes = callRouteBuilder("generateCruiseTimeline", payload);
            if (!boolLike(pickFirst(highRes, ["success", "SUCCESS"], false), false)) {
                throw(message="Timeline request failed for exposure 3", detail=serializeJSON(highRes));
            }
            highHours = sumTimelineHours(structKeyExists(highRes, "days") ? highRes.days : []);
        } finally {
            if (structKeyExists(original, "isNull") AND original.isNull) {
                writeExposure(segmentIdVal, javacast("null", ""));
            } else {
                writeExposure(segmentIdVal, original.value);
            }
        }

        highMeta = (structKeyExists(highRes, "timeline_meta") AND isStruct(highRes.timeline_meta)) ? highRes.timeline_meta : {};
        highSources = (structKeyExists(highMeta, "exposure_sources") AND isStruct(highMeta.exposure_sources)) ? highMeta.exposure_sources : {};

        result = {
            "route_id"=routeIdVal,
            "route_instance_id"=routeInstanceId,
            "segment_id"=segmentIdVal,
            "segment_context"=segInfo,
            "original_exposure_is_null"=(structKeyExists(original, "isNull") ? original.isNull : true),
            "original_exposure_value"=(structKeyExists(original, "value") ? original.value : 0),
            "hours_exposure_0"=lowHours,
            "hours_exposure_3"=highHours,
            "hours_delta"=round((highHours - lowHours) * 100) / 100,
            "pass_hours_increase"=(highHours GT lowHours),
            "timeline_meta_exposure_enabled"=boolLike(pickFirst(highMeta, ["exposure_enabled", "EXPOSURE_ENABLED"], false), false),
            "timeline_meta_exposure_max_level"=val(pickFirst(highMeta, ["exposure_max_level", "EXPOSURE_MAX_LEVEL"], 0)),
            "timeline_meta_effective_weather_pct_max"=val(pickFirst(highMeta, ["effective_weather_pct_max", "EFFECTIVE_WEATHER_PCT_MAX"], 0)),
            "timeline_meta_override_count"=val(pickFirst(highSources, ["override", "OVERRIDE"], 0)),
            "low_response"=lowRes,
            "high_response"=highRes
        };
    } catch (any eRun) {
        runError = eRun.message;
        if (len(trim(toString(eRun.detail)))) {
            runError &= " | " & toString(eRun.detail);
        }
    }
}

if (didRun AND !len(runError)) {
    arrayAppend(responseTableRows, flattenJsonRows(
        structKeyExists(result, "low_response") ? result.low_response : {},
        "$",
        "Low Exposure (0)"
    ), true);
    arrayAppend(responseTableRows, flattenJsonRows(
        structKeyExists(result, "high_response") ? result.high_response : {},
        "$",
        "High Exposure (3)"
    ), true);
}
</cfscript>

<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Timeline Exposure Harness</title>
    <cfinclude template="../includes/header_styles.cfm">
    <style>
        .teh-shell { max-width: 1100px; margin: 22px auto; padding: 0 12px 24px; }
        .teh-card { border: 1px solid #d9dde3; border-radius: 10px; background: #fff; padding: 16px; margin-bottom: 14px; }
        .teh-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px; }
        .teh-label { display: block; font-weight: 600; margin-bottom: 4px; }
        .teh-input { width: 100%; border: 1px solid #c8ced8; border-radius: 6px; padding: 8px 10px; font-size: 14px; }
        .teh-row { display: flex; align-items: center; gap: 8px; margin-top: 10px; flex-wrap: wrap; }
        .teh-kv { margin: 4px 0; font-size: 14px; }
        .teh-ok { color: #0f7b40; font-weight: 700; }
        .teh-bad { color: #9b1c1c; font-weight: 700; }
        .teh-table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 14px; }
        .teh-table th, .teh-table td { border: 1px solid #d9dde3; padding: 8px 10px; text-align: left; vertical-align: top; }
        .teh-table th { background: #f8fafc; color: #344054; font-weight: 700; }
        .teh-table .teh-label-col { width: 42%; font-weight: 600; color: #344054; }
        .teh-table .teh-pass { color: #0f7b40; font-weight: 700; }
        .teh-table .teh-fail { color: #9b1c1c; font-weight: 700; }
        .teh-table--json .teh-col-response { width: 170px; font-weight: 600; }
        .teh-table--json .teh-col-path { width: 300px; font-family: Menlo, Consolas, monospace; }
        .teh-table--json .teh-col-type { width: 110px; text-transform: uppercase; font-size: 12px; color: #475467; }
        .teh-table--json .teh-col-value { white-space: pre-wrap; word-break: break-word; font-family: Menlo, Consolas, monospace; }
        .teh-json-wrap { max-height: 620px; overflow: auto; border: 1px solid #d9dde3; border-radius: 6px; }
        .teh-pre { white-space: pre-wrap; word-break: break-word; border: 1px solid #d9dde3; background: #f8fafc; border-radius: 6px; padding: 10px; font-family: Menlo, Consolas, monospace; font-size: 12px; max-height: 420px; overflow: auto; }
        .teh-note { border: 1px solid #d9dde3; background: #f8fafc; color: #344054; border-radius: 8px; padding: 9px 10px; margin-top: 8px; font-size: 13px; }
        .teh-error { border-color: #f2c4c4; background: #fff4f4; color: #8a1f1f; }
        @media (max-width: 900px) { .teh-grid { grid-template-columns: 1fr; } }
    </style>
</head>
<body>
<div class="teh-shell">
    <div class="teh-card">
        <h2 style="margin:0 0 6px;">Cruise Timeline Exposure Harness</h2>
        <div class="teh-note">
            Sets one segment to exposure <code>0</code> and <code>3</code>, calls <code>generateCruiseTimeline</code> twice, compares total hours, then restores original exposure.
        </div>
        <cfif NOT isAuthorized>
            <div class="teh-note teh-error" style="margin-top:12px;">Admin access required.</div>
        <cfelse>
            <form method="post">
                <div class="teh-grid" style="margin-top:12px;">
                    <div>
                        <label class="teh-label" for="routeId">Route ID</label>
                        <input class="teh-input" id="routeId" name="routeId" value="<cfoutput>#encodeForHTML(form.routeId)#</cfoutput>" placeholder="e.g., 593">
                    </div>
                    <div>
                        <label class="teh-label" for="startDate">Start Date (yyyy-mm-dd)</label>
                        <input class="teh-input" id="startDate" name="startDate" value="<cfoutput>#encodeForHTML(form.startDate)#</cfoutput>">
                    </div>
                    <div>
                        <label class="teh-label" for="segmentId">Segment ID (optional)</label>
                        <input class="teh-input" id="segmentId" name="segmentId" value="<cfoutput>#encodeForHTML(form.segmentId)#</cfoutput>" placeholder="auto if blank">
                    </div>
                    <div>
                        <label class="teh-label" for="maxHoursPerDay">Max Hrs/Day</label>
                        <input class="teh-input" id="maxHoursPerDay" name="maxHoursPerDay" value="<cfoutput>#encodeForHTML(form.maxHoursPerDay)#</cfoutput>">
                    </div>
                    <div>
                        <label class="teh-label" for="pace">Pace</label>
                        <input class="teh-input" id="pace" name="pace" value="<cfoutput>#encodeForHTML(form.pace)#</cfoutput>">
                    </div>
                    <div>
                        <label class="teh-label" for="cruisingSpeed">Cruising Speed</label>
                        <input class="teh-input" id="cruisingSpeed" name="cruisingSpeed" value="<cfoutput>#encodeForHTML(form.cruisingSpeed)#</cfoutput>">
                    </div>
                    <div>
                        <label class="teh-label" for="weatherPct">Weather %</label>
                        <input class="teh-input" id="weatherPct" name="weatherPct" value="<cfoutput>#encodeForHTML(form.weatherPct)#</cfoutput>">
                    </div>
                    <div>
                        <label class="teh-label" for="fuelBurnGph">Fuel Burn GPH</label>
                        <input class="teh-input" id="fuelBurnGph" name="fuelBurnGph" value="<cfoutput>#encodeForHTML(form.fuelBurnGph)#</cfoutput>">
                    </div>
                    <div>
                        <label class="teh-label" for="reservePct">Reserve %</label>
                        <input class="teh-input" id="reservePct" name="reservePct" value="<cfoutput>#encodeForHTML(form.reservePct)#</cfoutput>">
                    </div>
                </div>
                <div class="teh-row">
                    <button type="submit" class="btn btn-primary" name="runHarness" value="1">Run Harness</button>
                </div>
            </form>
        </cfif>
    </div>

    <cfif didRun>
        <div class="teh-card">
            <h3 style="margin:0 0 8px;">Run Result</h3>
            <cfif len(runError)>
                <div class="teh-note teh-error"><cfoutput>#encodeForHTML(runError)#</cfoutput></div>
            <cfelse>
                <cfset passState = (structKeyExists(result, "pass_hours_increase") AND result.pass_hours_increase)>
                <table class="teh-table">
                    <thead>
                        <tr>
                            <th colspan="2">Summary</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td class="teh-label-col">Status</td>
                            <td>
                                <span class="<cfif passState>teh-pass<cfelse>teh-fail</cfif>">
                                    <cfoutput><cfif passState>PASS<cfelse>FAIL</cfif></cfoutput>
                                </span>
                            </td>
                        </tr>
                        <tr>
                            <td class="teh-label-col">Route ID</td>
                            <td><cfoutput>#encodeForHTML(toString(result.route_id))#</cfoutput></td>
                        </tr>
                        <tr>
                            <td class="teh-label-col">Route Instance ID</td>
                            <td><cfoutput>#encodeForHTML(toString(result.route_instance_id))#</cfoutput></td>
                        </tr>
                        <tr>
                            <td class="teh-label-col">Segment ID</td>
                            <td><cfoutput>#encodeForHTML(toString(result.segment_id))#</cfoutput></td>
                        </tr>
                        <tr>
                            <td class="teh-label-col">Original Exposure</td>
                            <td><cfoutput><cfif result.original_exposure_is_null>NULL<cfelse>#encodeForHTML(toString(result.original_exposure_value))#</cfif></cfoutput></td>
                        </tr>
                    </tbody>
                </table>
                <table class="teh-table">
                    <thead>
                        <tr>
                            <th>Metric</th>
                            <th>Exposure 0</th>
                            <th>Exposure 3</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td class="teh-label-col">Total Timeline Hours</td>
                            <td><cfoutput>#encodeForHTML(toString(result.hours_exposure_0))#</cfoutput></td>
                            <td><cfoutput>#encodeForHTML(toString(result.hours_exposure_3))#</cfoutput></td>
                        </tr>
                        <tr>
                            <td class="teh-label-col">Hours Delta (3 - 0)</td>
                            <td colspan="2"><cfoutput>#encodeForHTML(toString(result.hours_delta))#</cfoutput></td>
                        </tr>
                    </tbody>
                </table>
                <table class="teh-table">
                    <thead>
                        <tr>
                            <th colspan="2">Timeline Meta</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td class="teh-label-col">timeline_meta.exposure_enabled</td>
                            <td><cfoutput>#encodeForHTML(toString(result.timeline_meta_exposure_enabled))#</cfoutput></td>
                        </tr>
                        <tr>
                            <td class="teh-label-col">timeline_meta.exposure_max_level</td>
                            <td><cfoutput>#encodeForHTML(toString(result.timeline_meta_exposure_max_level))#</cfoutput></td>
                        </tr>
                        <tr>
                            <td class="teh-label-col">timeline_meta.effective_weather_pct_max</td>
                            <td><cfoutput>#encodeForHTML(toString(result.timeline_meta_effective_weather_pct_max))#</cfoutput></td>
                        </tr>
                        <tr>
                            <td class="teh-label-col">timeline_meta.exposure_sources.override</td>
                            <td><cfoutput>#encodeForHTML(toString(result.timeline_meta_override_count))#</cfoutput></td>
                        </tr>
                    </tbody>
                </table>
            </cfif>
        </div>

        <cfif !len(runError)>
            <div class="teh-card">
                <h3 style="margin:0 0 8px;">Complete API Responses</h3>
                <div class="teh-note">Decoded with <code>DeserializeJSON(JSONVar, false, false, true)</code>.</div>
                <div class="teh-note" style="margin-top:10px;">
                    <strong>Low Exposure Response (0)</strong>
                </div>
                <cfdump var="#result.low_response#" label="Low Exposure Response (0)" expand="false" top="6">
                <div class="teh-note" style="margin-top:10px;">
                    <strong>High Exposure Response (3)</strong>
                </div>
                <cfdump var="#result.high_response#" label="High Exposure Response (3)" expand="false" top="6">
            </div>
        </cfif>
    </cfif>
</div>
</body>
</html>
