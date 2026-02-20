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
    "limit" = "0",
    "delayMs" = "200",
    "portId" = "",
    "reportOutPath" = "/tmp/fpw-port-state-backfill.json"
};
for (k in formDefaults) {
    if (!structKeyExists(form, k)) {
        form[k] = formDefaults[k];
    }
}

didRun = false;
runError = "";
runStdErr = "";
runRaw = "";
runResult = {};
hasParsedResult = false;

if (isAuthorized AND structKeyExists(form, "runBackfill")) {
    didRun = true;

    applyFlag = boolLike(form.apply, false);
    limitVal = (isNumeric(form.limit) ? int(val(form.limit)) : 0);
    delayVal = (isNumeric(form.delayMs) ? int(val(form.delayMs)) : 200);
    portIdVal = (isNumeric(form.portId) ? int(val(form.portId)) : 0);
    reportOut = trim(toString(form.reportOutPath));

    if (limitVal LT 0) limitVal = 0;
    if (delayVal LT 0) delayVal = 0;
    if (portIdVal LT 0) portIdVal = 0;

    options = {
        "apply" = applyFlag,
        "limit" = limitVal,
        "delayMs" = delayVal,
        "portId" = portIdVal,
        "reportOutPath" = reportOut
    };

    try {
        svc = "";
        try {
            svc = createObject("component", "fpw.api.v1.PortStateBackfillService").init();
        } catch (any ePath) {
            svc = createObject("component", "api.v1.PortStateBackfillService").init();
        }
        runResult = svc.run(options);
        hasParsedResult = true;
        runRaw = serializeJSON(runResult);

        if (structKeyExists(runResult, "SUCCESS") AND !runResult.SUCCESS) {
            runError = structKeyExists(runResult, "ERROR") ? toString(runResult.ERROR) : "Backfill reported failure.";
        }
    } catch (any eRun) {
        runError = eRun.message;
        if (len(eRun.detail)) {
            runStdErr = eRun.detail;
        }
    }
}
</cfscript>

<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Port State Backfill</title>
    <cfinclude template="../../includes/header_styles.cfm">
    <style>
        .psb-shell {
            max-width: 1100px;
            margin: 22px auto;
            padding: 0 12px 24px;
        }
        .psb-card {
            border: 1px solid #d9dde3;
            border-radius: 10px;
            background: #fff;
            padding: 16px;
            margin-bottom: 14px;
        }
        .psb-grid {
            display: grid;
            grid-template-columns: repeat(2, minmax(0, 1fr));
            gap: 12px;
        }
        .psb-label {
            display: block;
            font-weight: 600;
            margin-bottom: 4px;
        }
        .psb-input {
            width: 100%;
            border: 1px solid #c8ced8;
            border-radius: 6px;
            padding: 8px 10px;
            font-size: 14px;
        }
        .psb-row {
            display: flex;
            align-items: center;
            gap: 8px;
            margin-top: 8px;
            flex-wrap: wrap;
        }
        .psb-stats {
            display: grid;
            grid-template-columns: repeat(4, minmax(0, 1fr));
            gap: 10px;
            margin-top: 10px;
        }
        .psb-stat {
            border: 1px solid #d9dde3;
            border-radius: 8px;
            background: #f8fafc;
            padding: 10px;
        }
        .psb-stat-label {
            font-size: 12px;
            color: #5f6672;
            margin-bottom: 3px;
            text-transform: uppercase;
            letter-spacing: .03em;
        }
        .psb-stat-value {
            font-size: 22px;
            font-weight: 700;
            line-height: 1.1;
        }
        .psb-badge {
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
        .psb-badge.apply {
            background: #eafdf2;
            border-color: #bde8cc;
            color: #1b5734;
        }
        .psb-notice {
            border-radius: 8px;
            padding: 9px 10px;
            margin: 10px 0 2px;
            font-size: 13px;
            border: 1px solid #d9dde3;
            background: #f8fafc;
            color: #344054;
        }
        .psb-notice.error {
            border-color: #f2c4c4;
            background: #fff4f4;
            color: #8a1f1f;
        }
        .psb-pre {
            white-space: pre-wrap;
            word-break: break-word;
            border: 1px solid #d9dde3;
            background: #f8fafc;
            border-radius: 6px;
            padding: 10px;
            font-family: Menlo, Consolas, monospace;
            font-size: 12px;
            max-height: 500px;
            overflow: auto;
        }
        .psb-table-wrap {
            overflow: auto;
            border: 1px solid #d9dde3;
            border-radius: 8px;
            margin-top: 8px;
        }
        .psb-table {
            width: 100%;
            border-collapse: collapse;
            font-size: 12px;
            background: #fff;
        }
        .psb-table th,
        .psb-table td {
            border-bottom: 1px solid #edf0f4;
            padding: 7px 8px;
            text-align: left;
            vertical-align: top;
            white-space: nowrap;
        }
        .psb-table th {
            background: #f8fafc;
            font-weight: 700;
        }
        .psb-empty {
            padding: 10px;
            font-size: 13px;
            color: #5f6672;
            border: 1px dashed #d0d5dd;
            border-radius: 8px;
            margin-top: 8px;
            background: #fafbfc;
        }
        @media (max-width: 900px) {
            .psb-grid,
            .psb-stats {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
<cfinclude template="../../includes/top_nav.cfm">

<div class="psb-shell">
    <div class="psb-card">
        <h3 style="margin-top:0;">Port State Backfill</h3>
        <p style="margin-bottom:0;">
            Runs <code>scripts/backfill-port-state-from-latlng.js</code> to fill missing <code>ports.state</code> from existing <code>lat/lng</code> using reverse geocoding.
        </p>
        <div class="psb-row">
            <a href="<cfoutput>#request.fpwBase#</cfoutput>/app/admin/wpi_port_populate.cfm">Open WPI Port Populate</a>
        </div>
    </div>

    <cfif NOT isAuthorized>
        <div class="psb-card" style="border-color:#e6b4b4;background:#fff6f6;">
            <strong>Unauthorized:</strong> Admin login is required.
        </div>
    <cfelse>
        <div class="psb-card">
            <form method="post">
                <div class="psb-grid">
                    <div>
                        <label class="psb-label" for="limit">Limit (0 = all)</label>
                        <input class="psb-input" type="number" min="0" step="1" id="limit" name="limit" value="<cfoutput>#encodeForHTMLAttribute(form.limit)#</cfoutput>">
                    </div>
                    <div>
                        <label class="psb-label" for="delayMs">Delay Between API Calls (ms)</label>
                        <input class="psb-input" type="number" min="0" step="1" id="delayMs" name="delayMs" value="<cfoutput>#encodeForHTMLAttribute(form.delayMs)#</cfoutput>">
                    </div>
                    <div>
                        <label class="psb-label" for="portId">Port ID (optional)</label>
                        <input class="psb-input" type="number" min="1" step="1" id="portId" name="portId" value="<cfoutput>#encodeForHTMLAttribute(form.portId)#</cfoutput>">
                    </div>
                    <div>
                        <label class="psb-label" for="reportOutPath">Report Output Path</label>
                        <input class="psb-input" type="text" id="reportOutPath" name="reportOutPath" value="<cfoutput>#encodeForHTMLAttribute(form.reportOutPath)#</cfoutput>">
                    </div>
                </div>
                <div class="psb-row">
                    <label><input type="checkbox" name="apply" value="1" <cfif boolLike(form.apply, false)>checked</cfif>> Apply DB updates</label>
                </div>
                <div class="psb-row">
                    <button class="btn btn-primary" type="submit" name="runBackfill" value="1">Run Backfill</button>
                </div>
            </form>
        </div>

        <cfif didRun>
            <div class="psb-card">
                <h4 style="margin-top:0;margin-bottom:6px;">Run Report</h4>

                <cfif len(runError)>
                    <div class="psb-notice error">
                        <strong>Error:</strong>
                        <cfoutput>#encodeForHTML(runError)#</cfoutput>
                    </div>
                </cfif>
                <cfif len(runStdErr) AND !len(runError)>
                    <div class="psb-notice error">
                        <strong>stderr:</strong>
                        <cfoutput>#encodeForHTML(runStdErr)#</cfoutput>
                    </div>
                </cfif>

                <cfif hasParsedResult>
                    <cfscript>
                        modeVal = lCase(structKeyExists(runResult, "mode") ? toString(runResult.mode) : "unknown");
                        badgeClass = (modeVal EQ "apply" ? "psb-badge apply" : "psb-badge");
                        totalCandidates = (structKeyExists(runResult, "total_candidates") ? val(runResult.total_candidates) : 0);
                        processedVal = (structKeyExists(runResult, "processed") ? val(runResult.processed) : 0);
                        readyVal = (structKeyExists(runResult, "matched_updates_ready") ? val(runResult.matched_updates_ready) : 0);
                        appliedVal = (structKeyExists(runResult, "applied_updates") ? val(runResult.applied_updates) : 0);
                        unresolvedVal = (structKeyExists(runResult, "unresolved_count") ? val(runResult.unresolved_count) : 0);
                        errorVal = (structKeyExists(runResult, "error_count") ? val(runResult.error_count) : 0);
                        insecureTlsVal = (structKeyExists(runResult, "used_insecure_tls_count") ? val(runResult.used_insecure_tls_count) : 0);
                        queriedAtVal = (structKeyExists(runResult, "queried_at_utc") ? toString(runResult.queried_at_utc) : "");
                        datasourceVal = (structKeyExists(runResult, "datasource") ? toString(runResult.datasource) : "");
                        reportPathVal = (structKeyExists(runResult, "report_written") ? toString(runResult.report_written) : "");
                        sampleUpdates = (structKeyExists(runResult, "sample_updates") AND isArray(runResult.sample_updates) ? runResult.sample_updates : []);
                        unresolvedRows = (structKeyExists(runResult, "unresolved") AND isArray(runResult.unresolved) ? runResult.unresolved : []);
                        errorRows = (structKeyExists(runResult, "errors") AND isArray(runResult.errors) ? runResult.errors : []);
                    </cfscript>

                    <p style="margin:0 0 10px 0;">
                        Mode:
                        <span class="<cfoutput>#badgeClass#</cfoutput>"><cfoutput>#encodeForHTML(modeVal)#</cfoutput></span>
                    </p>
                    <p style="margin-top:0;margin-bottom:10px;font-size:13px;">
                        <strong>Queried At (UTC):</strong> <cfoutput>#encodeForHTML(queriedAtVal)#</cfoutput>
                        &nbsp;|&nbsp;
                        <strong>Datasource:</strong> <cfoutput>#encodeForHTML(datasourceVal)#</cfoutput>
                        &nbsp;|&nbsp;
                        <strong>TLS Fallback Count:</strong> <cfoutput>#numberFormat(insecureTlsVal, "9,999,999")#</cfoutput>
                    </p>
                    <p style="margin-top:0;margin-bottom:10px;font-size:13px;">
                        <strong>Report File:</strong>
                        <cfoutput>#encodeForHTML(len(reportPathVal) ? reportPathVal : "(not written)")#</cfoutput>
                    </p>

                    <div class="psb-stats">
                        <div class="psb-stat">
                            <div class="psb-stat-label">Candidates</div>
                            <div class="psb-stat-value"><cfoutput>#numberFormat(totalCandidates, "9,999,999")#</cfoutput></div>
                        </div>
                        <div class="psb-stat">
                            <div class="psb-stat-label">Processed</div>
                            <div class="psb-stat-value"><cfoutput>#numberFormat(processedVal, "9,999,999")#</cfoutput></div>
                        </div>
                        <div class="psb-stat">
                            <div class="psb-stat-label">Matched</div>
                            <div class="psb-stat-value"><cfoutput>#numberFormat(readyVal, "9,999,999")#</cfoutput></div>
                        </div>
                        <div class="psb-stat">
                            <div class="psb-stat-label">Applied</div>
                            <div class="psb-stat-value"><cfoutput>#numberFormat(appliedVal, "9,999,999")#</cfoutput></div>
                        </div>
                    </div>

                    <div class="psb-row" style="margin-top:10px;">
                        <span><strong>Unresolved:</strong> <cfoutput>#numberFormat(unresolvedVal, "9,999,999")#</cfoutput></span>
                        <span><strong>Errors:</strong> <cfoutput>#numberFormat(errorVal, "9,999,999")#</cfoutput></span>
                    </div>

                    <h5 style="margin:14px 0 6px 0;">Sample Updates</h5>
                    <cfif arrayLen(sampleUpdates)>
                        <div class="psb-table-wrap">
                            <table class="psb-table">
                                <thead>
                                    <tr>
                                        <th>Port ID</th>
                                        <th>Port Name</th>
                                        <th>State</th>
                                        <th>Lat</th>
                                        <th>Lng</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <cfloop from="1" to="#arrayLen(sampleUpdates)#" index="i">
                                        <cfset row = sampleUpdates[i]>
                                        <tr>
                                            <td><cfoutput>#encodeForHTML(structKeyExists(row, "port_id") ? toString(row.port_id) : "")#</cfoutput></td>
                                            <td><cfoutput>#encodeForHTML(structKeyExists(row, "port_name") ? toString(row.port_name) : "")#</cfoutput></td>
                                            <td><cfoutput>#encodeForHTML(structKeyExists(row, "state") ? toString(row.state) : "")#</cfoutput></td>
                                            <td><cfoutput>#encodeForHTML(structKeyExists(row, "lat") ? toString(row.lat) : "")#</cfoutput></td>
                                            <td><cfoutput>#encodeForHTML(structKeyExists(row, "lng") ? toString(row.lng) : "")#</cfoutput></td>
                                        </tr>
                                    </cfloop>
                                </tbody>
                            </table>
                        </div>
                    <cfelse>
                        <div class="psb-empty">No matched updates to show.</div>
                    </cfif>

                    <h5 style="margin:14px 0 6px 0;">Unresolved</h5>
                    <cfif arrayLen(unresolvedRows)>
                        <div class="psb-table-wrap">
                            <table class="psb-table">
                                <thead>
                                    <tr>
                                        <th>Port ID</th>
                                        <th>Port Name</th>
                                        <th>Reason</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <cfloop from="1" to="#arrayLen(unresolvedRows)#" index="i">
                                        <cfset row = unresolvedRows[i]>
                                        <tr>
                                            <td><cfoutput>#encodeForHTML(structKeyExists(row, "port_id") ? toString(row.port_id) : "")#</cfoutput></td>
                                            <td><cfoutput>#encodeForHTML(structKeyExists(row, "port_name") ? toString(row.port_name) : "")#</cfoutput></td>
                                            <td><cfoutput>#encodeForHTML(structKeyExists(row, "reason") ? toString(row.reason) : "")#</cfoutput></td>
                                        </tr>
                                    </cfloop>
                                </tbody>
                            </table>
                        </div>
                    <cfelse>
                        <div class="psb-empty">No unresolved rows.</div>
                    </cfif>

                    <h5 style="margin:14px 0 6px 0;">Errors</h5>
                    <cfif arrayLen(errorRows)>
                        <div class="psb-table-wrap">
                            <table class="psb-table">
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
                        <div class="psb-empty">No errors reported.</div>
                    </cfif>
                </cfif>

                <details style="margin-top:14px;">
                    <summary style="cursor:pointer;font-weight:600;">Raw Output</summary>
                    <pre class="psb-pre" style="margin-top:8px;"><cfoutput>#encodeForHTML(len(runRaw) ? runRaw : "(no output)")#</cfoutput></pre>
                </details>
            </div>
        </cfif>
    </cfif>
</div>

<cfinclude template="../../includes/footer_scripts.cfm">
</body>
</html>
