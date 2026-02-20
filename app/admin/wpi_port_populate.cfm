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

formDefaults = {
    "apply" = "0",
    "fuzzy" = "0",
    "noBackfill" = "0",
    "limit" = "0",
    "delayMs" = "120",
    "reportOutPath" = "/tmp/fpw-wpi-populate.json",
    "namesText" = ""
};

for (k in formDefaults) {
    if (!structKeyExists(form, k)) {
        form[k] = formDefaults[k];
    }
}

didRun = false;
runError = "";
runResult = {};
portMessage = "";
portMessageType = "";
portSearchRaw = "";
portPage = 1;
portPageSize = 50;
portTotalRows = 0;
portTotalPages = 1;
portOffset = 0;
portStartRow = 0;
portEndRow = 0;
portRows = queryNew("");

if (isAuthorized AND structKeyExists(form, "runPopulate")) {
    didRun = true;

    namesArray = [];
    namesSeen = {};
    rawNames = trim(toString(form.namesText));
    if (len(rawNames)) {
        rawParts = reSplit("[\r\n,]+", rawNames);
        for (i = 1; i LTE arrayLen(rawParts); i++) {
            nameVal = trim(toString(rawParts[i]));
            if (!len(nameVal)) {
                continue;
            }
            keyVal = lCase(nameVal);
            if (!structKeyExists(namesSeen, keyVal)) {
                namesSeen[keyVal] = true;
                arrayAppend(namesArray, nameVal);
            }
        }
    }

    options = {
        "apply" = boolLike(form.apply, false),
        "fuzzy" = boolLike(form.fuzzy, false),
        "noBackfill" = boolLike(form.noBackfill, false),
        "limit" = (isNumeric(form.limit) ? int(val(form.limit)) : 0),
        "delayMs" = (isNumeric(form.delayMs) ? int(val(form.delayMs)) : 120),
        "reportOutPath" = trim(toString(form.reportOutPath)),
        "names" = namesArray
    };

    if (options.limit LT 0) {
        options.limit = 0;
    }
    if (options.delayMs LT 0) {
        options.delayMs = 0;
    }

    try {
        svc = "";
        try {
            svc = createObject("component", "fpw.api.v1.WpiPortPopulateService").init();
        } catch (any ePath) {
            svc = createObject("component", "api.v1.WpiPortPopulateService").init();
        }
        runResult = svc.run(options);
    } catch (any eRun) {
        runError = eRun.message;
        runResult = {
            "SUCCESS" = false,
            "MESSAGE" = "Run failed",
            "ERROR" = {
                "MESSAGE" = eRun.message,
                "DETAIL" = eRun.detail
            }
        };
    }
}

if (isAuthorized) {
    if (structKeyExists(form, "portQ")) {
        portSearchRaw = trim(toString(form.portQ));
    } else if (structKeyExists(url, "portQ")) {
        portSearchRaw = trim(toString(url.portQ));
    }

    if (structKeyExists(form, "portPage")) {
        portPage = (isNumeric(form.portPage) ? int(val(form.portPage)) : 1);
    } else if (structKeyExists(url, "portPage")) {
        portPage = (isNumeric(url.portPage) ? int(val(url.portPage)) : 1);
    }
    if (portPage LT 1) {
        portPage = 1;
    }

    if (structKeyExists(form, "portPageSize")) {
        portPageSize = (isNumeric(form.portPageSize) ? int(val(form.portPageSize)) : 50);
    } else if (structKeyExists(url, "portPageSize")) {
        portPageSize = (isNumeric(url.portPageSize) ? int(val(url.portPageSize)) : 50);
    }
    if (!listFind("25,50,100,200", toString(portPageSize))) {
        portPageSize = 50;
    }

    if (structKeyExists(form, "savePortRow")) {
        savePortId = (structKeyExists(form, "port_id") AND isNumeric(form.port_id) ? int(val(form.port_id)) : 0);
        saveName = trim(structKeyExists(form, "name") ? toString(form.name) : "");
        saveState = trim(structKeyExists(form, "state") ? toString(form.state) : "");
        saveRegion = trim(structKeyExists(form, "region") ? toString(form.region) : "");
        saveLatRaw = trim(structKeyExists(form, "lat") ? toString(form.lat) : "");
        saveLngRaw = trim(structKeyExists(form, "lng") ? toString(form.lng) : "");
        saveMajor = (boolLike(structKeyExists(form, "is_major_port") ? form.is_major_port : 0, false) ? 1 : 0);
        saveHidden = (boolLike(structKeyExists(form, "is_hidden_gem") ? form.is_hidden_gem : 0, false) ? 1 : 0);
        saveStateIsNull = !len(saveState);
        saveRegionIsNull = !len(saveRegion);
        saveLatIsNull = !len(saveLatRaw);
        saveLngIsNull = !len(saveLngRaw);
        saveLatVal = 0;
        saveLngVal = 0;

        if (savePortId LTE 0) {
            portMessageType = "error";
            portMessage = "Invalid port id.";
        } else if (!len(saveName)) {
            portMessageType = "error";
            portMessage = "Port name is required.";
        } else if (!saveLatIsNull AND !isNumeric(saveLatRaw)) {
            portMessageType = "error";
            portMessage = "Latitude must be numeric.";
        } else if (!saveLngIsNull AND !isNumeric(saveLngRaw)) {
            portMessageType = "error";
            portMessage = "Longitude must be numeric.";
        } else {
            if (!saveLatIsNull) {
                saveLatVal = val(saveLatRaw);
            }
            if (!saveLngIsNull) {
                saveLngVal = val(saveLngRaw);
            }

            if (!saveLatIsNull AND (saveLatVal LT -90 OR saveLatVal GT 90)) {
                portMessageType = "error";
                portMessage = "Latitude must be between -90 and 90.";
            } else if (!saveLngIsNull AND (saveLngVal LT -180 OR saveLngVal GT 180)) {
                portMessageType = "error";
                portMessage = "Longitude must be between -180 and 180.";
            } else {
                try {
                    queryExecute(
                        "
                        UPDATE ports
                        SET
                          name = :nameVal,
                          state = :stateVal,
                          lat = :latVal,
                          lng = :lngVal,
                          region = :regionVal,
                          is_major_port = :majorVal,
                          is_hidden_gem = :hiddenVal
                        WHERE id = :portId
                        ",
                        {
                            nameVal = { value = saveName, cfsqltype = "cf_sql_varchar" },
                            stateVal = { value = saveState, cfsqltype = "cf_sql_varchar", null = saveStateIsNull },
                            latVal = { value = saveLatVal, cfsqltype = "cf_sql_decimal", scale = 7, null = saveLatIsNull },
                            lngVal = { value = saveLngVal, cfsqltype = "cf_sql_decimal", scale = 7, null = saveLngIsNull },
                            regionVal = { value = saveRegion, cfsqltype = "cf_sql_varchar", null = saveRegionIsNull },
                            majorVal = { value = saveMajor, cfsqltype = "cf_sql_bit" },
                            hiddenVal = { value = saveHidden, cfsqltype = "cf_sql_bit" },
                            portId = { value = savePortId, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = application.dsn }
                    );
                    portMessageType = "success";
                    portMessage = "Port ##" & savePortId & " saved.";
                } catch (any saveErr) {
                    portMessageType = "error";
                    portMessage = "Save failed: " & saveErr.message;
                }
            }
        }
    }

    portWhereSql = " WHERE 1=1 ";
    portBinds = {};
    if (len(portSearchRaw)) {
        portWhereSql &= " AND (name LIKE :q OR state LIKE :q OR region LIKE :q OR CAST(id AS CHAR) LIKE :q) ";
        portBinds.q = { value = "%" & portSearchRaw & "%", cfsqltype = "cf_sql_varchar" };
    }

    qPortCount = queryExecute(
        "SELECT COUNT(*) AS total_rows FROM ports" & portWhereSql,
        portBinds,
        { datasource = application.dsn }
    );
    portTotalRows = (qPortCount.recordCount ? val(qPortCount.total_rows[1]) : 0);
    portTotalPages = (portTotalRows GT 0 ? ceiling(portTotalRows / portPageSize) : 1);
    if (portPage GT portTotalPages) {
        portPage = portTotalPages;
    }
    portOffset = (portPage - 1) * portPageSize;

    portRows = queryExecute(
        "
        SELECT id, name, state, lat, lng, region, is_major_port, is_hidden_gem
        FROM ports
        " & portWhereSql & "
        ORDER BY id ASC
        LIMIT " & portPageSize & " OFFSET " & portOffset,
        portBinds,
        { datasource = application.dsn }
    );

    if (portTotalRows GT 0) {
        portStartRow = portOffset + 1;
        portEndRow = min(portOffset + portRows.recordCount, portTotalRows);
    } else {
        portStartRow = 0;
        portEndRow = 0;
    }
}
</cfscript>

<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>WPI Port Coordinate Populate</title>
    <cfinclude template="../../includes/header_styles.cfm">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
    <style>
        .wpi-shell {
            max-width: 1100px;
            margin: 22px auto;
            padding: 0 12px 24px;
        }
        .wpi-card {
            border: 1px solid #d9dde3;
            border-radius: 10px;
            background: #fff;
            padding: 16px;
            margin-bottom: 14px;
        }
        .wpi-grid {
            display: grid;
            grid-template-columns: repeat(2, minmax(0, 1fr));
            gap: 12px;
        }
        .wpi-row {
            display: flex;
            align-items: center;
            gap: 8px;
            margin-top: 6px;
        }
        .wpi-label {
            display: block;
            font-weight: 600;
            margin-bottom: 4px;
        }
        .wpi-input, .wpi-textarea {
            width: 100%;
            border: 1px solid #c8ced8;
            border-radius: 6px;
            padding: 8px 10px;
            font-size: 14px;
        }
        .wpi-textarea {
            min-height: 130px;
            resize: vertical;
            font-family: Menlo, Consolas, monospace;
        }
        .wpi-pre {
            white-space: pre-wrap;
            word-break: break-word;
            border: 1px solid #d9dde3;
            background: #f8fafc;
            border-radius: 6px;
            padding: 10px;
            font-family: Menlo, Consolas, monospace;
            font-size: 12px;
            max-height: 480px;
            overflow: auto;
        }
        .wpi-stats {
            display: grid;
            grid-template-columns: repeat(4, minmax(0, 1fr));
            gap: 10px;
            margin-top: 10px;
        }
        .wpi-stat {
            border: 1px solid #d9dde3;
            border-radius: 8px;
            background: #f8fafc;
            padding: 10px;
        }
        .wpi-stat-label {
            font-size: 12px;
            color: #5f6672;
            margin-bottom: 3px;
            text-transform: uppercase;
            letter-spacing: .03em;
        }
        .wpi-stat-value {
            font-size: 22px;
            font-weight: 700;
            line-height: 1.1;
        }
        .wpi-badge {
            display: inline-block;
            border-radius: 999px;
            padding: 4px 10px;
            font-size: 12px;
            font-weight: 600;
            letter-spacing: .02em;
            background: #eef2ff;
            color: #25335f;
            border: 1px solid #cdd8ff;
            text-transform: uppercase;
        }
        .wpi-badge.apply {
            background: #eafdf2;
            border-color: #bde8cc;
            color: #1b5734;
        }
        .wpi-report-grid {
            display: grid;
            grid-template-columns: repeat(2, minmax(0, 1fr));
            gap: 12px;
            margin-top: 12px;
        }
        .wpi-subcard {
            border: 1px solid #d9dde3;
            border-radius: 8px;
            padding: 10px;
            background: #fff;
        }
        .wpi-subtitle {
            margin: 0 0 8px 0;
            font-size: 14px;
        }
        .wpi-kv {
            margin: 0;
            font-size: 13px;
            line-height: 1.55;
        }
        .wpi-kv strong {
            display: inline-block;
            min-width: 165px;
        }
        .wpi-table-wrap {
            overflow: auto;
            border: 1px solid #d9dde3;
            border-radius: 8px;
            margin-top: 8px;
        }
        .wpi-table {
            width: 100%;
            border-collapse: collapse;
            font-size: 12px;
            background: #fff;
        }
        .wpi-table th,
        .wpi-table td {
            border-bottom: 1px solid #edf0f4;
            padding: 7px 8px;
            text-align: left;
            vertical-align: top;
            white-space: nowrap;
        }
        .wpi-table th {
            background: #f8fafc;
            font-weight: 700;
        }
        .wpi-empty {
            padding: 10px;
            font-size: 13px;
            color: #5f6672;
            border: 1px dashed #d0d5dd;
            border-radius: 8px;
            margin-top: 8px;
            background: #fafbfc;
        }
        .wpi-notice {
            border-radius: 8px;
            padding: 9px 10px;
            margin: 10px 0 2px;
            font-size: 13px;
            border: 1px solid #d9dde3;
            background: #f8fafc;
            color: #344054;
        }
        .wpi-notice.success {
            border-color: #b7e4c7;
            background: #ecfdf3;
            color: #1f5131;
        }
        .wpi-notice.error {
            border-color: #f2c4c4;
            background: #fff4f4;
            color: #8a1f1f;
        }
        .wpi-editor-filter {
            display: grid;
            grid-template-columns: 2fr 1fr auto;
            gap: 10px;
            align-items: end;
            margin-top: 10px;
        }
        .wpi-port-input {
            width: 100%;
            min-width: 70px;
            border: 1px solid #c8ced8;
            border-radius: 5px;
            padding: 6px 7px;
            font-size: 12px;
            line-height: 1.2;
            background: #fff;
        }
        .wpi-port-input[readonly] {
            background: #f7f8fa;
        }
        .wpi-port-num {
            min-width: 95px;
        }
        .wpi-port-flag {
            text-align: center;
            width: 58px;
        }
        .wpi-port-actions {
            width: 148px;
            text-align: center;
        }
        .wpi-port-actionstack {
            display: inline-flex;
            gap: 6px;
            align-items: center;
            justify-content: center;
        }
        .wpi-port-actionstack .btn {
            min-width: 58px;
        }
        .wpi-map-overlay {
            position: fixed;
            inset: 0;
            z-index: 2100;
            background: rgba(3, 8, 15, 0.78);
            opacity: 0;
            visibility: hidden;
            pointer-events: none;
            transition: opacity 0.2s ease, visibility 0.2s ease;
        }
        .wpi-map-overlay.is-open {
            opacity: 1;
            visibility: visible;
            pointer-events: auto;
        }
        body.wpi-map-open {
            overflow: hidden;
        }
        .wpi-map-shell {
            position: absolute;
            inset: 16px;
            border: 1px solid #26487a;
            border-radius: 14px;
            background: #0f1a2d;
            display: flex;
            flex-direction: column;
            overflow: hidden;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.35);
        }
        .wpi-map-head {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            gap: 10px;
            padding: 12px 14px 10px;
            border-bottom: 1px solid rgba(126, 157, 203, 0.32);
            color: #ecf3ff;
        }
        .wpi-map-title {
            margin: 0;
            font-size: 15px;
            font-weight: 700;
        }
        .wpi-map-subtitle {
            font-size: 12px;
            margin-top: 2px;
            color: #c2d5f3;
        }
        .wpi-map-close {
            border: 1px solid rgba(145, 175, 218, 0.32);
            border-radius: 8px;
            color: #ecf3ff;
            background: rgba(255, 255, 255, 0.04);
            width: 32px;
            height: 32px;
            font-size: 20px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            line-height: 1;
        }
        .wpi-map-close:hover {
            background: rgba(255, 255, 255, 0.12);
        }
        .wpi-map-meta {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 8px;
            padding: 8px 14px;
            border-bottom: 1px solid rgba(126, 157, 203, 0.28);
            background: rgba(7, 15, 27, 0.45);
            color: #d9e8ff;
            font-size: 12px;
        }
        .wpi-map-search {
            display: grid;
            grid-template-columns: minmax(0, 2fr) minmax(0, 1fr) auto auto;
            gap: 8px;
            padding: 8px 14px;
            border-bottom: 1px solid rgba(126, 157, 203, 0.28);
            background: rgba(7, 15, 27, 0.38);
        }
        .wpi-map-search .form-control {
            min-width: 0;
        }
        .wpi-map-actions {
            display: flex;
            justify-content: flex-end;
            gap: 8px;
            padding: 8px 14px;
            border-bottom: 1px solid rgba(126, 157, 203, 0.28);
            background: rgba(7, 15, 27, 0.34);
        }
        .wpi-map-coords {
            font-family: Menlo, Consolas, monospace;
        }
        .wpi-map-canvas {
            flex: 1 1 auto;
            min-height: 340px;
        }
        .leaflet-control {
            border-radius: 8px !important;
        }
        .wpi-page {
            display: flex;
            gap: 8px;
            align-items: center;
            flex-wrap: wrap;
            margin-top: 10px;
            font-size: 13px;
        }
        .wpi-page a {
            text-decoration: none;
        }
        @media (max-width: 900px) {
            .wpi-grid {
                grid-template-columns: 1fr;
            }
            .wpi-stats,
            .wpi-report-grid {
                grid-template-columns: 1fr;
            }
            .wpi-editor-filter {
                grid-template-columns: 1fr;
            }
            .wpi-map-shell {
                inset: 8px;
            }
            .wpi-map-search {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
<cfinclude template="../../includes/top_nav.cfm">

<div class="wpi-shell">
    <div class="wpi-card">
        <h3 style="margin-top:0;">WPI Port Coordinate Populate</h3>
        <p style="margin-bottom:0;">
            Queries NGA WPI for missing <code>ports.lat/lng</code>. Default mode is dry-run. Use apply to write updates and backfill <code>loop_segments</code>.
        </p>
    </div>

    <cfif NOT isAuthorized>
        <div class="wpi-card" style="border-color:#e6b4b4;background:#fff6f6;">
            <strong>Unauthorized:</strong> Admin login is required.
        </div>
    <cfelse>
        <div class="wpi-card">
            <form method="post">
                <div class="wpi-grid">
                    <div>
                        <label class="wpi-label" for="limit">Limit (0 = all)</label>
                        <input class="wpi-input" type="number" min="0" step="1" id="limit" name="limit" value="<cfoutput>#encodeForHTMLAttribute(form.limit)#</cfoutput>">
                    </div>
                    <div>
                        <label class="wpi-label" for="delayMs">Delay Between API Calls (ms)</label>
                        <input class="wpi-input" type="number" min="0" step="1" id="delayMs" name="delayMs" value="<cfoutput>#encodeForHTMLAttribute(form.delayMs)#</cfoutput>">
                    </div>
                </div>

                <div style="margin-top:12px;">
                    <label class="wpi-label" for="reportOutPath">Report Output Path</label>
                    <input class="wpi-input" type="text" id="reportOutPath" name="reportOutPath" value="<cfoutput>#encodeForHTMLAttribute(form.reportOutPath)#</cfoutput>">
                </div>

                <div style="margin-top:12px;">
                    <label class="wpi-label" for="namesText">Optional Port Name Filter (one per line, or comma separated)</label>
                    <textarea class="wpi-textarea" id="namesText" name="namesText"><cfoutput>#encodeForHTML(form.namesText)#</cfoutput></textarea>
                </div>

                <div class="wpi-row">
                    <label><input type="checkbox" name="apply" value="1" <cfif boolLike(form.apply, false)>checked</cfif>> Apply DB updates</label>
                    <label><input type="checkbox" name="fuzzy" value="1" <cfif boolLike(form.fuzzy, false)>checked</cfif>> Enable fuzzy fallback matching</label>
                    <label><input type="checkbox" name="noBackfill" value="1" <cfif boolLike(form.noBackfill, false)>checked</cfif>> Skip loop_segments backfill</label>
                </div>

                <div style="margin-top:12px;">
                    <button class="btn btn-primary" type="submit" name="runPopulate" value="1">Run</button>
                </div>
            </form>
        </div>

        <cfif didRun>
            <div class="wpi-card">
                <cfscript>
                    modeVal = (structKeyExists(runResult, "mode") ? lCase(toString(runResult.mode)) : "");
                    badgeClass = (modeVal EQ "apply" ? "wpi-badge apply" : "wpi-badge");
                    scannedVal = (structKeyExists(runResult, "total_ports_scanned") ? val(runResult.total_ports_scanned) : 0);
                    matchedVal = (structKeyExists(runResult, "matched_updates_ready") ? val(runResult.matched_updates_ready) : 0);
                    appliedVal = (structKeyExists(runResult, "applied_port_updates") ? val(runResult.applied_port_updates) : 0);
                    unresolvedVal = (structKeyExists(runResult, "unresolved_count") ? val(runResult.unresolved_count) : 0);
                    errorVal = (structKeyExists(runResult, "error_count") ? val(runResult.error_count) : 0);
                    queriedAtVal = (structKeyExists(runResult, "queried_at_utc") ? toString(runResult.queried_at_utc) : "");
                    datasourceVal = (structKeyExists(runResult, "datasource") ? toString(runResult.datasource) : "");
                    reportPathVal = (structKeyExists(runResult, "report_written") ? toString(runResult.report_written) : "");
                    sampleUpdates = (structKeyExists(runResult, "sample_updates") AND isArray(runResult.sample_updates) ? runResult.sample_updates : []);
                    unresolvedRows = (structKeyExists(runResult, "unresolved") AND isArray(runResult.unresolved) ? runResult.unresolved : []);
                    errorRows = (structKeyExists(runResult, "errors") AND isArray(runResult.errors) ? runResult.errors : []);
                    backfillVal = (structKeyExists(runResult, "backfill") AND isStruct(runResult.backfill) ? runResult.backfill : {});
                    backfillBefore = (structKeyExists(backfillVal, "before") AND isStruct(backfillVal.before) ? backfillVal.before : {});
                    backfillAfter = (structKeyExists(backfillVal, "after") AND isStruct(backfillVal.after) ? backfillVal.after : {});
                </cfscript>

                <h4 style="margin-top:0;margin-bottom:6px;">Run Report</h4>
                <cfif len(runError)>
                    <p style="color:#9f1d1d;"><strong>Error:</strong> <cfoutput>#encodeForHTML(runError)#</cfoutput></p>
                </cfif>

                <p style="margin:0 0 10px 0;">
                    Mode:
                    <span class="<cfoutput>#badgeClass#</cfoutput>"><cfoutput>#encodeForHTML(len(modeVal) ? modeVal : "unknown")#</cfoutput></span>
                </p>

                <div class="wpi-stats">
                    <div class="wpi-stat">
                        <div class="wpi-stat-label">Ports Scanned</div>
                        <div class="wpi-stat-value"><cfoutput>#numberFormat(scannedVal, "9,999,999")#</cfoutput></div>
                    </div>
                    <div class="wpi-stat">
                        <div class="wpi-stat-label">Matched Updates</div>
                        <div class="wpi-stat-value"><cfoutput>#numberFormat(matchedVal, "9,999,999")#</cfoutput></div>
                    </div>
                    <div class="wpi-stat">
                        <div class="wpi-stat-label">Applied Updates</div>
                        <div class="wpi-stat-value"><cfoutput>#numberFormat(appliedVal, "9,999,999")#</cfoutput></div>
                    </div>
                    <div class="wpi-stat">
                        <div class="wpi-stat-label">Unresolved</div>
                        <div class="wpi-stat-value"><cfoutput>#numberFormat(unresolvedVal, "9,999,999")#</cfoutput></div>
                    </div>
                </div>

                <div class="wpi-report-grid">
                    <div class="wpi-subcard">
                        <h5 class="wpi-subtitle">Run Details</h5>
                        <p class="wpi-kv"><strong>Queried At (UTC):</strong> <cfoutput>#encodeForHTML(queriedAtVal)#</cfoutput></p>
                        <p class="wpi-kv"><strong>Datasource:</strong> <cfoutput>#encodeForHTML(datasourceVal)#</cfoutput></p>
                        <p class="wpi-kv"><strong>Error Count:</strong> <cfoutput>#numberFormat(errorVal, "9,999,999")#</cfoutput></p>
                        <p class="wpi-kv"><strong>Report File:</strong> <cfoutput>#encodeForHTML(len(reportPathVal) ? reportPathVal : "(not written)")#</cfoutput></p>
                    </div>

                    <div class="wpi-subcard">
                        <h5 class="wpi-subtitle">Backfill Delta</h5>
                        <p class="wpi-kv"><strong>Missing Start (Before):</strong> <cfoutput>#numberFormat((structKeyExists(backfillBefore, "missingStart") ? val(backfillBefore.missingStart) : 0), "9,999,999")#</cfoutput></p>
                        <p class="wpi-kv"><strong>Missing Start (After):</strong> <cfoutput>#numberFormat((structKeyExists(backfillAfter, "missingStart") ? val(backfillAfter.missingStart) : 0), "9,999,999")#</cfoutput></p>
                        <p class="wpi-kv"><strong>Missing End (Before):</strong> <cfoutput>#numberFormat((structKeyExists(backfillBefore, "missingEnd") ? val(backfillBefore.missingEnd) : 0), "9,999,999")#</cfoutput></p>
                        <p class="wpi-kv"><strong>Missing End (After):</strong> <cfoutput>#numberFormat((structKeyExists(backfillAfter, "missingEnd") ? val(backfillAfter.missingEnd) : 0), "9,999,999")#</cfoutput></p>
                        <p class="wpi-kv"><strong>Improved Any:</strong> <cfoutput>#numberFormat((structKeyExists(backfillVal, "improvedAny") ? val(backfillVal.improvedAny) : 0), "9,999,999")#</cfoutput></p>
                    </div>
                </div>

                <h5 style="margin:14px 0 6px 0;">Matched Updates (Sample)</h5>
                <cfif arrayLen(sampleUpdates)>
                    <div class="wpi-table-wrap">
                        <table class="wpi-table">
                            <thead>
                                <tr>
                                    <th>Port ID</th>
                                    <th>Port Name</th>
                                    <th>Matched Port Name</th>
                                    <th>Lat</th>
                                    <th>Lng</th>
                                    <th>Strategy</th>
                                </tr>
                            </thead>
                            <tbody>
                                <cfloop from="1" to="#arrayLen(sampleUpdates)#" index="i">
                                    <cfset row = sampleUpdates[i]>
                                    <tr>
                                        <td><cfoutput>#encodeForHTML(structKeyExists(row, "port_id") ? toString(row.port_id) : "")#</cfoutput></td>
                                        <td><cfoutput>#encodeForHTML(structKeyExists(row, "port_name") ? toString(row.port_name) : "")#</cfoutput></td>
                                        <td><cfoutput>#encodeForHTML(structKeyExists(row, "matched_port_name") ? toString(row.matched_port_name) : "")#</cfoutput></td>
                                        <td><cfoutput>#encodeForHTML(structKeyExists(row, "lat") ? toString(row.lat) : "")#</cfoutput></td>
                                        <td><cfoutput>#encodeForHTML(structKeyExists(row, "lng") ? toString(row.lng) : "")#</cfoutput></td>
                                        <td><cfoutput>#encodeForHTML(structKeyExists(row, "strategy") ? toString(row.strategy) : "")#</cfoutput></td>
                                    </tr>
                                </cfloop>
                            </tbody>
                        </table>
                    </div>
                <cfelse>
                    <div class="wpi-empty">No matched updates to show.</div>
                </cfif>

                <h5 style="margin:14px 0 6px 0;">Unresolved Ports</h5>
                <cfif arrayLen(unresolvedRows)>
                    <div class="wpi-table-wrap">
                        <table class="wpi-table">
                            <thead>
                                <tr>
                                    <th>Port ID</th>
                                    <th>Port Name</th>
                                    <th>Attempt Summary</th>
                                </tr>
                            </thead>
                            <tbody>
                                <cfloop from="1" to="#arrayLen(unresolvedRows)#" index="i">
                                    <cfset row = unresolvedRows[i]>
                                    <cfset attemptSummary = "">
                                    <cfif structKeyExists(row, "attempts") AND isArray(row.attempts)>
                                        <cfloop from="1" to="#arrayLen(row.attempts)#" index="j">
                                            <cfset attemptRow = row.attempts[j]>
                                            <cfset modeTxt = (structKeyExists(attemptRow, "mode") ? toString(attemptRow.mode) : "attempt")>
                                            <cfset countTxt = (structKeyExists(attemptRow, "count") ? toString(attemptRow.count) : "0")>
                                            <cfset attemptSummary = listAppend(attemptSummary, modeTxt & ":" & countTxt, " | ")>
                                        </cfloop>
                                    </cfif>
                                    <tr>
                                        <td><cfoutput>#encodeForHTML(structKeyExists(row, "port_id") ? toString(row.port_id) : "")#</cfoutput></td>
                                        <td><cfoutput>#encodeForHTML(structKeyExists(row, "port_name") ? toString(row.port_name) : "")#</cfoutput></td>
                                        <td><cfoutput>#encodeForHTML(len(attemptSummary) ? attemptSummary : "(no attempts logged)")#</cfoutput></td>
                                    </tr>
                                </cfloop>
                            </tbody>
                        </table>
                    </div>
                <cfelse>
                    <div class="wpi-empty">No unresolved ports.</div>
                </cfif>

                <h5 style="margin:14px 0 6px 0;">Errors</h5>
                <cfif arrayLen(errorRows)>
                    <div class="wpi-table-wrap">
                        <table class="wpi-table">
                            <thead>
                                <tr>
                                    <th>Port ID</th>
                                    <th>Port Name</th>
                                    <th>Error</th>
                                </tr>
                            </thead>
                            <tbody>
                                <cfloop from="1" to="#arrayLen(errorRows)#" index="i">
                                    <cfset row = errorRows[i]>
                                    <tr>
                                        <td><cfoutput>#encodeForHTML(structKeyExists(row, "port_id") ? toString(row.port_id) : "")#</cfoutput></td>
                                        <td><cfoutput>#encodeForHTML(structKeyExists(row, "port_name") ? toString(row.port_name) : "")#</cfoutput></td>
                                        <td><cfoutput>#encodeForHTML(structKeyExists(row, "error") ? toString(row.error) : "")#</cfoutput></td>
                                    </tr>
                                </cfloop>
                            </tbody>
                        </table>
                    </div>
                <cfelse>
                    <div class="wpi-empty">No errors reported.</div>
                </cfif>

                <details style="margin-top:14px;">
                    <summary style="cursor:pointer;font-weight:600;">Raw JSON</summary>
                    <pre class="wpi-pre" style="margin-top:8px;"><cfoutput>#encodeForHTML(serializeJSON(runResult))#</cfoutput></pre>
                </details>
            </div>
        </cfif>

        <div class="wpi-card" id="wpiPortsEditorCard">
            <cfscript>
                portQueryEncoded = urlEncodedFormat(portSearchRaw);
                prevPage = (portPage GT 1 ? portPage - 1 : 1);
                nextPage = (portPage LT portTotalPages ? portPage + 1 : portTotalPages);
                basePortsPath = request.fpwBase & "/app/admin/wpi_port_populate.cfm";
                prevHref = basePortsPath & "?portQ=" & portQueryEncoded & "&portPageSize=" & portPageSize & "&portPage=" & prevPage;
                nextHref = basePortsPath & "?portQ=" & portQueryEncoded & "&portPageSize=" & portPageSize & "&portPage=" & nextPage;
            </cfscript>

            <h4 style="margin-top:0;margin-bottom:4px;">Ports Table Editor</h4>
            <p style="margin:0;">Edit `ports` rows in place and save one row at a time.</p>

            <cfif len(portMessage)>
                <div class="wpi-notice <cfoutput>#encodeForHTML(portMessageType)#</cfoutput>">
                    <cfoutput>#encodeForHTML(portMessage)#</cfoutput>
                </div>
            </cfif>

            <form method="get" class="wpi-editor-filter">
                <div>
                    <label class="wpi-label" for="portQ">Search (name/state/region/id)</label>
                    <input id="portQ" name="portQ" type="text" class="wpi-input" value="<cfoutput>#encodeForHTMLAttribute(portSearchRaw)#</cfoutput>">
                </div>
                <div>
                    <label class="wpi-label" for="portPageSize">Rows Per Page</label>
                    <select id="portPageSize" name="portPageSize" class="wpi-input">
                        <option value="25" <cfif portPageSize EQ 25>selected</cfif>>25</option>
                        <option value="50" <cfif portPageSize EQ 50>selected</cfif>>50</option>
                        <option value="100" <cfif portPageSize EQ 100>selected</cfif>>100</option>
                        <option value="200" <cfif portPageSize EQ 200>selected</cfif>>200</option>
                    </select>
                </div>
                <div>
                    <button class="btn btn-primary" type="submit">Apply</button>
                </div>
            </form>

            <div class="wpi-page">
                <span>
                    <cfoutput>Showing #numberFormat(portStartRow, "9,999,999")# - #numberFormat(portEndRow, "9,999,999")# of #numberFormat(portTotalRows, "9,999,999")#</cfoutput>
                </span>
                <span>|</span>
                <span><cfoutput>Page #portPage# of #portTotalPages#</cfoutput></span>
                <cfif portPage GT 1>
                    <span>|</span>
                    <a href="<cfoutput>#encodeForHTMLAttribute(prevHref)#</cfoutput>">Previous</a>
                </cfif>
                <cfif portPage LT portTotalPages>
                    <span>|</span>
                    <a href="<cfoutput>#encodeForHTMLAttribute(nextHref)#</cfoutput>">Next</a>
                </cfif>
            </div>

            <cfif portRows.recordCount GT 0>
                <div class="wpi-table-wrap">
                    <table class="wpi-table">
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>Name</th>
                                <th>State</th>
                                <th>Lat</th>
                                <th>Lng</th>
                                <th>Region</th>
                                <th>Major</th>
                                <th>Hidden Gem</th>
                                <th>Action</th>
                            </tr>
                        </thead>
                        <tbody>
                            <cfloop query="portRows">
                                <cfset rowFormId = "portForm_" & portRows.id>
                                <tr>
                                    <td><cfoutput>#portRows.id#</cfoutput></td>
                                    <td>
                                        <input
                                            form="<cfoutput>#rowFormId#</cfoutput>"
                                            type="text"
                                            class="wpi-port-input"
                                            name="name"
                                            value="<cfoutput>#encodeForHTMLAttribute(isNull(portRows.name) ? "" : toString(portRows.name))#</cfoutput>"
                                            maxlength="160">
                                    </td>
                                    <td>
                                        <input
                                            form="<cfoutput>#rowFormId#</cfoutput>"
                                            type="text"
                                            class="wpi-port-input"
                                            name="state"
                                            value="<cfoutput>#encodeForHTMLAttribute(isNull(portRows.state) ? "" : toString(portRows.state))#</cfoutput>"
                                            maxlength="80">
                                    </td>
                                    <td>
                                        <input
                                            form="<cfoutput>#rowFormId#</cfoutput>"
                                            type="text"
                                            class="wpi-port-input wpi-port-num"
                                            name="lat"
                                            value="<cfoutput>#encodeForHTMLAttribute(isNull(portRows.lat) ? "" : toString(portRows.lat))#</cfoutput>"
                                            inputmode="decimal">
                                    </td>
                                    <td>
                                        <input
                                            form="<cfoutput>#rowFormId#</cfoutput>"
                                            type="text"
                                            class="wpi-port-input wpi-port-num"
                                            name="lng"
                                            value="<cfoutput>#encodeForHTMLAttribute(isNull(portRows.lng) ? "" : toString(portRows.lng))#</cfoutput>"
                                            inputmode="decimal">
                                    </td>
                                    <td>
                                        <input
                                            form="<cfoutput>#rowFormId#</cfoutput>"
                                            type="text"
                                            class="wpi-port-input"
                                            name="region"
                                            value="<cfoutput>#encodeForHTMLAttribute(isNull(portRows.region) ? "" : toString(portRows.region))#</cfoutput>"
                                            maxlength="80">
                                    </td>
                                    <td class="wpi-port-flag">
                                        <input
                                            form="<cfoutput>#rowFormId#</cfoutput>"
                                            type="checkbox"
                                            name="is_major_port"
                                            value="1"
                                            <cfif val(portRows.is_major_port) EQ 1>checked</cfif>>
                                    </td>
                                    <td class="wpi-port-flag">
                                        <input
                                            form="<cfoutput>#rowFormId#</cfoutput>"
                                            type="checkbox"
                                            name="is_hidden_gem"
                                            value="1"
                                            <cfif val(portRows.is_hidden_gem) EQ 1>checked</cfif>>
                                    </td>
                                    <td class="wpi-port-actions">
                                        <div class="wpi-port-actionstack">
                                            <button
                                                type="button"
                                                class="btn btn-sm btn-secondary js-wpi-map-btn"
                                                data-form-id="<cfoutput>#rowFormId#</cfoutput>">
                                                Map
                                            </button>
                                            <button
                                                form="<cfoutput>#rowFormId#</cfoutput>"
                                                type="submit"
                                                class="btn btn-sm btn-primary">
                                                Save
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            </cfloop>
                        </tbody>
                    </table>
                </div>

                <div style="display:none;">
                    <cfloop query="portRows">
                        <cfset rowFormId = "portForm_" & portRows.id>
                        <form id="<cfoutput>#rowFormId#</cfoutput>" method="post">
                            <input type="hidden" name="savePortRow" value="1">
                            <input type="hidden" name="port_id" value="<cfoutput>#portRows.id#</cfoutput>">
                            <input type="hidden" name="portQ" value="<cfoutput>#encodeForHTMLAttribute(portSearchRaw)#</cfoutput>">
                            <input type="hidden" name="portPage" value="<cfoutput>#portPage#</cfoutput>">
                            <input type="hidden" name="portPageSize" value="<cfoutput>#portPageSize#</cfoutput>">
                            <input type="hidden" name="is_major_port" value="0">
                            <input type="hidden" name="is_hidden_gem" value="0">
                        </form>
                    </cfloop>
                </div>
            <cfelse>
                <div class="wpi-empty">No ports found for the current filter.</div>
            </cfif>
        </div>
    </cfif>
</div>

<div id="wpiPortMapOverlay" class="wpi-map-overlay" aria-hidden="true">
    <div class="wpi-map-shell" role="dialog" aria-modal="true" aria-labelledby="wpiPortMapTitle">
        <div class="wpi-map-head">
            <div>
                <h5 id="wpiPortMapTitle" class="wpi-map-title">Set Port Coordinates</h5>
                <div id="wpiPortMapSubtitle" class="wpi-map-subtitle">Click the map to set latitude/longitude for this row.</div>
            </div>
            <button type="button" id="wpiPortMapCloseBtn" class="wpi-map-close" aria-label="Close map overlay">&times;</button>
        </div>
        <div class="wpi-map-meta">
            <span id="wpiPortMapStatus">Tip: click anywhere on the map to set coordinates, then save the row.</span>
            <span id="wpiPortMapCoords" class="wpi-map-coords">Lat: -- | Lng: --</span>
        </div>
        <div class="wpi-map-search">
            <input id="wpiPortMapSearchName" type="text" class="form-control form-control-sm" placeholder="Port name">
            <input id="wpiPortMapSearchState" type="text" class="form-control form-control-sm" placeholder="State (optional)" maxlength="80">
            <button type="button" id="wpiPortMapSearchBtn" class="btn btn-sm btn-secondary">Search</button>
            <button type="button" id="wpiPortMapSearchClearBtn" class="btn btn-sm btn-secondary">Clear</button>
        </div>
        <div class="wpi-map-actions">
            <button type="button" id="wpiPortMapSaveBtn" class="btn btn-sm btn-primary">Save</button>
        </div>
        <div id="wpiPortMapCanvas" class="wpi-map-canvas"></div>
    </div>
</div>

<cfinclude template="../../includes/footer_scripts.cfm">
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script>
(function (window, document) {
    "use strict";

    var overlayEl = document.getElementById("wpiPortMapOverlay");
    var mapEl = document.getElementById("wpiPortMapCanvas");
    var closeBtn = document.getElementById("wpiPortMapCloseBtn");
    var titleEl = document.getElementById("wpiPortMapTitle");
    var subtitleEl = document.getElementById("wpiPortMapSubtitle");
    var statusEl = document.getElementById("wpiPortMapStatus");
    var coordsEl = document.getElementById("wpiPortMapCoords");
    var searchNameEl = document.getElementById("wpiPortMapSearchName");
    var searchStateEl = document.getElementById("wpiPortMapSearchState");
    var searchBtn = document.getElementById("wpiPortMapSearchBtn");
    var searchClearBtn = document.getElementById("wpiPortMapSearchClearBtn");
    var mapSaveBtn = document.getElementById("wpiPortMapSaveBtn");

    var map = null;
    var marker = null;
    var activeContext = null;

    function parseCoord(value) {
        var num = parseFloat(String(value || "").trim());
        return Number.isFinite(num) ? num : NaN;
    }

    function formatCoord(value) {
        return Number.isFinite(value) ? value.toFixed(6) : "--";
    }

    function setStatus(text) {
        if (statusEl) {
            statusEl.textContent = text || "";
        }
    }

    function setCoordReadout(lat, lng) {
        if (coordsEl) {
            coordsEl.textContent = "Lat: " + formatCoord(lat) + " | Lng: " + formatCoord(lng);
        }
    }

    function clearMarker() {
        if (map && marker) {
            map.removeLayer(marker);
            marker = null;
        }
    }

    function placeMarker(lat, lng) {
        if (!map || !window.L) return;
        if (marker) {
            marker.setLatLng([lat, lng]);
        } else {
            marker = window.L.marker([lat, lng]).addTo(map);
        }
    }

    function applyCoordinates(lat, lng, statusText) {
        if (!activeContext || !activeContext.latInput || !activeContext.lngInput) return;
        activeContext.latInput.value = lat.toFixed(6);
        activeContext.lngInput.value = lng.toFixed(6);
        placeMarker(lat, lng);
        setCoordReadout(lat, lng);
        if (statusText) {
            setStatus(statusText);
        }
    }

    function setActiveContextByFormId(formId) {
        if (!formId) return false;
        var nameInput = document.querySelector('input[form="' + formId + '"][name="name"]');
        var stateInput = document.querySelector('input[form="' + formId + '"][name="state"]');
        var latInput = document.querySelector('input[form="' + formId + '"][name="lat"]');
        var lngInput = document.querySelector('input[form="' + formId + '"][name="lng"]');
        if (!latInput || !lngInput) return false;

        activeContext = {
            formId: formId,
            nameInput: nameInput,
            stateInput: stateInput,
            latInput: latInput,
            lngInput: lngInput
        };
        return true;
    }

    function normalizeStateLabel(value) {
        return String(value || "").trim();
    }

    function deriveStateFromDisplayName(result) {
        var displayName = String((result && result.display_name) || "").trim();
        if (!displayName) return "";

        var parts = displayName.split(",").map(function (part) {
            return String(part || "").trim();
        }).filter(function (part) {
            return part.length > 0;
        });
        if (parts.length < 2) return "";

        var last = String(parts[parts.length - 1] || "").toLowerCase();
        if (last === "united states" || last === "united states of america" || last === "usa" || last === "us") {
            return parts[parts.length - 2] || "";
        }
        return "";
    }

    function deriveStateFromSearchResult(result) {
        var address = (result && result.address) ? result.address : {};
        var state = normalizeStateLabel(address.state);
        if (!state) state = normalizeStateLabel(address.region);
        if (!state) state = normalizeStateLabel(address.state_district);
        if (!state) state = deriveStateFromDisplayName(result);
        return normalizeStateLabel(state);
    }

    function buildSearchQuery() {
        var name = String(searchNameEl ? searchNameEl.value : "").trim();
        var state = String(searchStateEl ? searchStateEl.value : "").trim();
        if (name && state) {
            return name + ", " + state;
        }
        return name || state;
    }

    function runSearch() {
        if (!activeContext) return;
        if (!ensureMap()) return;

        var query = buildSearchQuery();
        if (!query) {
            setStatus("Enter port name and/or state to search.");
            return;
        }

        setStatus('Searching for "' + query + '"...');
        var geocodeUrl = "https://nominatim.openstreetmap.org/search?format=jsonv2&addressdetails=1&limit=1&q=" + encodeURIComponent(query);
        fetch(geocodeUrl, {
            method: "GET",
            credentials: "omit",
            headers: {
                "Accept": "application/json"
            }
        })
            .then(function (response) {
                if (!response.ok) {
                    throw new Error("Lookup failed.");
                }
                return response.json();
            })
            .then(function (rows) {
                var first = (Array.isArray(rows) && rows.length) ? rows[0] : null;
                var lat = first ? parseFloat(first.lat) : NaN;
                var lng = first ? parseFloat(first.lon) : NaN;
                if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
                    setStatus("No results found. Try a more specific name or state.");
                    return;
                }

                lat = Math.round(lat * 1000000) / 1000000;
                lng = Math.round(lng * 1000000) / 1000000;
                applyCoordinates(lat, lng, "Search result applied. Click Save to persist.");
                var resolvedState = deriveStateFromSearchResult(first);
                if (!resolvedState && searchStateEl) {
                    resolvedState = normalizeStateLabel(searchStateEl.value);
                }
                if (resolvedState && activeContext && activeContext.stateInput) {
                    activeContext.stateInput.value = resolvedState;
                    if (searchStateEl) {
                        searchStateEl.value = resolvedState;
                    }
                }
                map.setView([lat, lng], 11);
            })
            .catch(function () {
                setStatus("Search failed. Try again.");
            });
    }

    function clearSearch() {
        if (!activeContext || !activeContext.latInput || !activeContext.lngInput) return;
        if (searchNameEl) {
            searchNameEl.value = "";
        }
        if (searchStateEl) {
            searchStateEl.value = "";
        }
        clearMarker();
        activeContext.latInput.value = "";
        activeContext.lngInput.value = "";
        setCoordReadout(NaN, NaN);
        setStatus("Pin removed. Coordinates cleared. Click Save to persist.");
    }

    function getFormAssociatedInput(formId, fieldName) {
        return document.querySelector('input[form="' + formId + '"][name="' + fieldName + '"]');
    }

    function getFormAssociatedCheckbox(formId, fieldName) {
        var el = document.querySelector('input[form="' + formId + '"][name="' + fieldName + '"]');
        return !!(el && el.checked);
    }

    function getHiddenFormValue(formEl, fieldName) {
        var el = formEl ? formEl.querySelector('input[name="' + fieldName + '"]') : null;
        return el ? String(el.value || "") : "";
    }

    function buildAjaxPayload(formEl) {
        var formId = formEl ? String(formEl.id || "") : "";
        var payload = new URLSearchParams();
        payload.set("savePortRow", "1");
        payload.set("port_id", getHiddenFormValue(formEl, "port_id"));
        payload.set("portQ", getHiddenFormValue(formEl, "portQ"));
        payload.set("portPage", getHiddenFormValue(formEl, "portPage"));
        payload.set("portPageSize", getHiddenFormValue(formEl, "portPageSize"));
        payload.set("name", (getFormAssociatedInput(formId, "name") || {}).value || "");
        payload.set("state", (getFormAssociatedInput(formId, "state") || {}).value || "");
        payload.set("lat", (getFormAssociatedInput(formId, "lat") || {}).value || "");
        payload.set("lng", (getFormAssociatedInput(formId, "lng") || {}).value || "");
        payload.set("region", (getFormAssociatedInput(formId, "region") || {}).value || "");
        payload.set("is_major_port", getFormAssociatedCheckbox(formId, "is_major_port") ? "1" : "0");
        payload.set("is_hidden_gem", getFormAssociatedCheckbox(formId, "is_hidden_gem") ? "1" : "0");
        return payload;
    }

    function showAjaxNotice(type, message) {
        var card = document.getElementById("wpiPortsEditorCard");
        if (!card) return;
        var existing = card.querySelector(".wpi-notice.js-ajax-notice");
        if (existing && existing.parentNode) {
            existing.parentNode.removeChild(existing);
        }

        var notice = document.createElement("div");
        notice.className = "wpi-notice js-ajax-notice " + (type === "error" ? "error" : "success");
        notice.textContent = message;

        var intro = card.querySelector("p");
        if (intro && intro.parentNode) {
            intro.parentNode.insertBefore(notice, intro.nextSibling);
        } else {
            card.insertBefore(notice, card.firstChild);
        }
    }

    function replacePortsEditorCard(htmlText) {
        var parser = new window.DOMParser();
        var doc = parser.parseFromString(htmlText, "text/html");
        var freshCard = doc.getElementById("wpiPortsEditorCard");
        var currentCard = document.getElementById("wpiPortsEditorCard");
        if (!freshCard || !currentCard) {
            throw new Error("Could not refresh port table.");
        }
        currentCard.replaceWith(freshCard);
    }

    function submitPortFormAjax(formEl, submitButton, options) {
        options = options || {};
        if (!formEl) {
            return Promise.reject(new Error("Save failed."));
        }
        if (formEl.dataset.ajaxSaving === "1") {
            return Promise.reject(new Error("Save already in progress."));
        }
        formEl.dataset.ajaxSaving = "1";

        var buttonText = "";
        if (submitButton) {
            buttonText = submitButton.textContent;
            submitButton.disabled = true;
            submitButton.textContent = "Saving...";
        }

        return fetch(window.location.pathname + window.location.search, {
            method: "POST",
            credentials: "same-origin",
            headers: {
                "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
                "X-Requested-With": "XMLHttpRequest"
            },
            body: buildAjaxPayload(formEl).toString()
        })
            .then(function (response) {
                if (!response.ok) {
                    throw new Error("Save failed (" + response.status + ").");
                }
                return response.text();
            })
            .then(function (htmlText) {
                replacePortsEditorCard(htmlText);
                return true;
            })
            .catch(function (err) {
                if (!options.suppressCardNotice) {
                    showAjaxNotice("error", (err && err.message) ? err.message : "Save failed.");
                }
                throw err;
            })
            .finally(function () {
                formEl.dataset.ajaxSaving = "0";
                if (submitButton) {
                    submitButton.disabled = false;
                    submitButton.textContent = buttonText || "Save";
                }
            });
    }

    function saveOverlayValues() {
        if (!activeContext || !activeContext.formId) {
            setStatus("Select a port row first.");
            return;
        }

        var formId = activeContext.formId;
        if (!setActiveContextByFormId(formId)) {
            setStatus("Unable to locate selected row.");
            return;
        }

        if (activeContext.stateInput && searchStateEl) {
            var currentState = normalizeStateLabel(activeContext.stateInput.value);
            var searchState = normalizeStateLabel(searchStateEl.value);
            if (!currentState && searchState) {
                activeContext.stateInput.value = searchState;
            }
        }

        var formEl = document.getElementById(formId);
        if (!formEl) {
            setStatus("Unable to locate row form.");
            return;
        }

        setStatus("Saving...");
        submitPortFormAjax(formEl, mapSaveBtn, { suppressCardNotice: false })
            .then(function () {
                if (!setActiveContextByFormId(formId)) {
                    setStatus("Saved. Row is no longer visible on this page.");
                    return;
                }

                var lat = parseCoord(activeContext.latInput.value);
                var lng = parseCoord(activeContext.lngInput.value);
                if (Number.isFinite(lat) && Number.isFinite(lng)) {
                    placeMarker(lat, lng);
                    setCoordReadout(lat, lng);
                } else {
                    clearMarker();
                    setCoordReadout(NaN, NaN);
                }
                setStatus("Saved. Overlay remains open for additional edits.");
            })
            .catch(function (err) {
                setStatus((err && err.message) ? ("Save failed. " + err.message) : "Save failed.");
            });
    }

    function ensureMap() {
        if (map) return true;
        if (!window.L || !mapEl) {
            setStatus("Map failed to load.");
            return false;
        }

        map = window.L.map(mapEl, {
            center: [39.5, -95.5],
            zoom: 4,
            zoomControl: true
        });

        window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
            attribution: "&copy; OpenStreetMap contributors",
            maxZoom: 19
        }).addTo(map);

        map.on("click", function (evt) {
            if (!activeContext || !activeContext.latInput || !activeContext.lngInput) return;
            var lat = Math.round(evt.latlng.lat * 1000000) / 1000000;
            var lng = Math.round(evt.latlng.lng * 1000000) / 1000000;
            applyCoordinates(lat, lng, "Coordinates set for this row. Click Save to persist.");
        });

        return true;
    }

    function closeOverlay() {
        if (!overlayEl) return;
        overlayEl.classList.remove("is-open");
        overlayEl.setAttribute("aria-hidden", "true");
        document.body.classList.remove("wpi-map-open");
        activeContext = null;
    }

    function openOverlayForButton(btn) {
        if (!btn || !overlayEl) return;
        var formId = btn.getAttribute("data-form-id");
        if (!formId) return;
        if (!setActiveContextByFormId(formId)) return;

        var portName = activeContext.nameInput ? String(activeContext.nameInput.value || "").trim() : "";
        var portState = activeContext.stateInput ? String(activeContext.stateInput.value || "").trim() : "";
        if (titleEl) {
            titleEl.textContent = portName ? "Set Port Coordinates - " + portName : "Set Port Coordinates";
        }
        if (subtitleEl) {
            subtitleEl.textContent = "Click the map to set latitude/longitude for this row.";
        }
        if (searchNameEl) {
            searchNameEl.value = portName;
        }
        if (searchStateEl) {
            searchStateEl.value = portState;
        }

        overlayEl.classList.add("is-open");
        overlayEl.setAttribute("aria-hidden", "false");
        document.body.classList.add("wpi-map-open");

        if (!ensureMap()) return;

        var lat = parseCoord(activeContext.latInput.value);
        var lng = parseCoord(activeContext.lngInput.value);
        window.setTimeout(function () {
            map.invalidateSize();
            if (Number.isFinite(lat) && Number.isFinite(lng)) {
                placeMarker(lat, lng);
                map.setView([lat, lng], 11);
                setCoordReadout(lat, lng);
                setStatus("Current coordinates loaded. Click map to adjust, then save the row.");
            } else {
                clearMarker();
                map.setView([39.5, -95.5], 4);
                setCoordReadout(NaN, NaN);
                setStatus("No coordinates are set yet. Click map to choose a point, then save the row.");
            }
        }, 30);
    }

    if (!overlayEl) return;

    document.addEventListener("click", function (evt) {
        var mapBtn = evt.target ? evt.target.closest(".js-wpi-map-btn") : null;
        if (mapBtn) {
            evt.preventDefault();
            openOverlayForButton(mapBtn);
        }
    });

    document.addEventListener("submit", function (evt) {
        var formEl = evt.target;
        if (!formEl || !formEl.id || formEl.id.indexOf("portForm_") !== 0) return;
        evt.preventDefault();
        var submitButton = evt.submitter || document.querySelector('button[type="submit"][form="' + formEl.id + '"]');
        submitPortFormAjax(formEl, submitButton).catch(function () {
            // Error is already surfaced via in-card notice.
        });
    });

    if (closeBtn) {
        closeBtn.addEventListener("click", closeOverlay);
    }
    if (searchBtn) {
        searchBtn.addEventListener("click", runSearch);
    }
    if (searchClearBtn) {
        searchClearBtn.addEventListener("click", clearSearch);
    }
    if (mapSaveBtn) {
        mapSaveBtn.addEventListener("click", saveOverlayValues);
    }
    [searchNameEl, searchStateEl].forEach(function (el) {
        if (!el) return;
        el.addEventListener("keydown", function (evt) {
            if (evt.key === "Enter") {
                evt.preventDefault();
                runSearch();
            }
        });
    });

    overlayEl.addEventListener("click", function (evt) {
        if (evt.target === overlayEl) {
            closeOverlay();
        }
    });

    document.addEventListener("keydown", function (evt) {
        if (evt.key === "Escape" && overlayEl.classList.contains("is-open")) {
            closeOverlay();
        }
    });
})(window, document);
</script>
</body>
</html>
