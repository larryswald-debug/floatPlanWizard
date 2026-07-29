<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">
<cfscript>
userStruct = (structKeyExists(session, "user") AND isStruct(session.user)) ? session.user : {};
isLoggedIn = structCount(userStruct) GT 0;
isAdmin = false;
adminWhitelist = "admin@floatplanwizard.com,lswald@yahoo.com";
roleValue = "";
emailValue = "";
appDsn = (structKeyExists(application, "dsn") AND len(trim(toString(application.dsn)))) ? trim(toString(application.dsn)) : "";
actionType = "";
targetMonitoringIdRaw = "";
targetMonitoringId = 0;
targetFloatPlanIdRaw = "";
targetFloatPlanId = 0;
runMonitorLimit = 100;
message = "";
messageType = "info";
qSummary = queryNew("");
qRows = queryNew("");
activeMonitoredCount = 0;
dueSoonCount = 0;
overdueCount = 0;
missedOrEscalatedCount = 0;

function boolLike(any value, boolean defaultValue=false) {
    var txt = lCase(trim(toString(arguments.value)));
    if (!len(txt)) return arguments.defaultValue;
    if (listFindNoCase("1,true,yes,y,on", txt)) return true;
    if (listFindNoCase("0,false,no,n,off", txt)) return false;
    if (isNumeric(txt)) return (val(txt) NEQ 0);
    return arguments.defaultValue;
}

function asInt(any value, numeric defaultValue=0) {
    return isNumeric(arguments.value) ? int(val(arguments.value)) : arguments.defaultValue;
}

function textValue(any value, string fallback="") {
    if (isNull(arguments.value)) return arguments.fallback;
    return trim(toString(arguments.value));
}

function formatAdminDateTime(any value) {
    if (isNull(arguments.value)) return "&mdash;";
    if (!isDate(arguments.value)) return "&mdash;";
    return encodeForHtml(dateTimeFormat(arguments.value, "mmm d, yyyy h:nn tt"));
}

function formatAdminText(any value, string fallback="&mdash;") {
    var txt = textValue(arguments.value);
    return len(txt) ? encodeForHtml(txt) : arguments.fallback;
}

function buildFollowUrl(any slugValue, any shareTokenValue) {
    var slugTxt = textValue(arguments.slugValue);
    var shareTokenTxt = textValue(arguments.shareTokenValue);
    var url = "";
    if (!len(slugTxt)) return "";
    url = request.fpwBase & "/app/follow.cfm?slug=" & urlEncodedFormat(slugTxt);
    if (len(shareTokenTxt)) {
        url &= "&t=" & urlEncodedFormat(shareTokenTxt);
    }
    return url;
}

function buildActiveCruiseUrl(any floatPlanIdValue) {
    var planId = asInt(arguments.floatPlanIdValue, 0);
    if (planId LTE 0) return "";
    return request.fpwBase & "/app/active-cruise.cfm?floatPlanId=" & planId;
}

function buildTripLabel(any floatPlanNameValue, any floatPlanIdValue) {
    var planName = textValue(arguments.floatPlanNameValue);
    var planId = asInt(arguments.floatPlanIdValue, 0);
    if (len(planName)) return encodeForHtml(planName);
    if (planId GT 0) return "Float Plan ##" & planId;
    return "&mdash;";
}

if (isLoggedIn) {
    if (structKeyExists(userStruct, "isAdmin") AND boolLike(userStruct.isAdmin, false)) {
        isAdmin = true;
    } else if (structKeyExists(userStruct, "ISADMIN") AND boolLike(userStruct.ISADMIN, false)) {
        isAdmin = true;
    } else if (structKeyExists(userStruct, "is_admin") AND boolLike(userStruct.is_admin, false)) {
        isAdmin = true;
    } else {
        if (structKeyExists(userStruct, "role")) {
            roleValue = lCase(trim(toString(userStruct.role)));
        } else if (structKeyExists(userStruct, "ROLE")) {
            roleValue = lCase(trim(toString(userStruct.ROLE)));
        }
        if (roleValue EQ "admin") {
            isAdmin = true;
        } else {
            if (structKeyExists(userStruct, "email")) {
                emailValue = lCase(trim(toString(userStruct.email)));
            } else if (structKeyExists(userStruct, "EMAIL")) {
                emailValue = lCase(trim(toString(userStruct.EMAIL)));
            }
            if (len(emailValue) AND listFindNoCase(adminWhitelist, emailValue)) {
                isAdmin = true;
            }
        }
    }
}

isAuthorized = isLoggedIn AND isAdmin;

if (structKeyExists(form, "actionType")) {
    actionType = lCase(trim(toString(form.actionType)));
}
if (structKeyExists(form, "targetMonitoringId")) {
    targetMonitoringIdRaw = trim(toString(form.targetMonitoringId));
}
if (structKeyExists(form, "targetFloatPlanId")) {
    targetFloatPlanIdRaw = trim(toString(form.targetFloatPlanId));
}
if (len(targetMonitoringIdRaw) AND isNumeric(targetMonitoringIdRaw) AND val(targetMonitoringIdRaw) GT 0) {
    targetMonitoringId = int(val(targetMonitoringIdRaw));
}
if (len(targetFloatPlanIdRaw) AND isNumeric(targetFloatPlanIdRaw) AND val(targetFloatPlanIdRaw) GT 0) {
    targetFloatPlanId = int(val(targetFloatPlanIdRaw));
}

if (isAuthorized AND len(appDsn)) {
    if (actionType EQ "runmonitor") {
        try {
            monitoringService = "";
            runResult = {};
            processedCount = 0;
            processedIdsText = "";
            try {
                monitoringService = createObject("component", "fpw.api.v1.monitor").init(appDsn);
            } catch (any ePath) {
                monitoringService = createObject("component", "api.v1.monitor").init(appDsn);
            }
            runResult = monitoringService.evaluateDueMonitoringRows(runMonitorLimit);
            if (
                structKeyExists(runResult, "SUCCESS")
                AND runResult.SUCCESS
            ) {
                processedCount = structKeyExists(runResult, "PROCESSED_COUNT") ? asInt(runResult.PROCESSED_COUNT, 0) : 0;
                if (
                    structKeyExists(runResult, "FLOAT_PLAN_IDS")
                    AND isArray(runResult.FLOAT_PLAN_IDS)
                    AND arrayLen(runResult.FLOAT_PLAN_IDS)
                ) {
                    processedIdsText = arrayToList(runResult.FLOAT_PLAN_IDS, ", ");
                }
                message = "Ran monitoring evaluator. Processed " & processedCount & " row(s).";
                if (len(processedIdsText)) {
                    message &= " Float plans: " & processedIdsText & ".";
                }
                messageType = "success";
            } else {
                message = "Monitoring evaluator run failed.";
                if (structKeyExists(runResult, "MESSAGE") AND len(trim(toString(runResult.MESSAGE)))) {
                    message &= " " & trim(toString(runResult.MESSAGE));
                } else if (structKeyExists(runResult, "ERROR") AND len(trim(toString(runResult.ERROR)))) {
                    message &= " " & trim(toString(runResult.ERROR));
                }
                messageType = "error";
            }
        } catch (any eRun) {
            message = eRun.message;
            if (len(trim(toString(eRun.detail)))) {
                message &= " " & trim(toString(eRun.detail));
            }
            messageType = "error";
        }
    } else if (actionType EQ "close") {
        if (targetFloatPlanId LTE 0) {
            message = "A valid float plan id is required.";
            messageType = "error";
        } else {
            qCloseTarget = queryExecute(
                "
                SELECT
                    m.id,
                    m.float_plan_id,
                    m.monitor_state,
                    m.is_monitoring_enabled,
                    fp.floatplanId AS joined_floatplan_id,
                    fp.floatPlanName
                FROM floatplan_monitoring m
                LEFT JOIN floatplans fp
                    ON fp.floatplanId = m.float_plan_id
                WHERE m.float_plan_id = :floatPlanId
                  AND m.is_monitoring_enabled = 1
                  AND UPPER(TRIM(COALESCE(m.monitor_state, ''))) <> 'CLOSED'
                LIMIT 1
                ",
                {
                    floatPlanId = { value = targetFloatPlanId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = appDsn }
            );

            if (!qCloseTarget.recordCount) {
                message = "No enabled non-closed monitoring row was found for that float plan.";
                messageType = "error";
            } else if (asInt(qCloseTarget.joined_floatplan_id[1], 0) LTE 0) {
                message = "Orphaned monitoring rows are view-only in this phase and cannot be closed from this page.";
                messageType = "error";
            } else {
                try {
                    monitoringService = "";
                    try {
                        monitoringService = createObject("component", "fpw.api.v1.monitor").init();
                    } catch (any ePath) {
                        monitoringService = createObject("component", "api.v1.monitor").init();
                    }
                    closeResult = monitoringService.closeMonitoringForFloatPlan(targetFloatPlanId, "admin_dashboard");
                    if (
                        structKeyExists(closeResult, "SUCCESS")
                        AND closeResult.SUCCESS
                    ) {
                        message = "Closed monitoring for float plan " & targetFloatPlanId & ".";
                        messageType = "success";
                    } else {
                        message = "Monitoring close failed.";
                        if (structKeyExists(closeResult, "MESSAGE") AND len(trim(toString(closeResult.MESSAGE)))) {
                            message &= " " & trim(toString(closeResult.MESSAGE));
                        } else if (structKeyExists(closeResult, "ERROR") AND len(trim(toString(closeResult.ERROR)))) {
                            message &= " " & trim(toString(closeResult.ERROR));
                        }
                        messageType = "error";
                    }
                } catch (any eClose) {
                    message = eClose.message;
                    if (len(trim(toString(eClose.detail)))) {
                        message &= " " & trim(toString(eClose.detail));
                    }
                    messageType = "error";
                }
            }
        }
    } else if (actionType EQ "deleteorphan") {
        if (targetMonitoringId LTE 0 OR targetFloatPlanId LTE 0) {
            message = "A valid monitoring id and float plan id are required.";
            messageType = "error";
        } else {
            qDeleteTarget = queryExecute(
                "
                SELECT
                    m.id,
                    m.float_plan_id,
                    fp.floatplanId AS joined_floatplan_id
                FROM floatplan_monitoring m
                LEFT JOIN floatplans fp
                    ON fp.floatplanId = m.float_plan_id
                WHERE m.id = :monitoringId
                  AND m.float_plan_id = :floatPlanId
                LIMIT 1
                ",
                {
                    monitoringId = { value = targetMonitoringId, cfsqltype = "cf_sql_integer" },
                    floatPlanId = { value = targetFloatPlanId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = appDsn }
            );

            if (!qDeleteTarget.recordCount) {
                message = "No monitoring row was found for that orphan delete request.";
                messageType = "error";
            } else if (asInt(qDeleteTarget.joined_floatplan_id[1], 0) GT 0) {
                message = "Only orphaned monitoring rows can be deleted from this page.";
                messageType = "error";
            } else {
                try {
                    transaction {
                        queryExecute(
                            "DELETE vc
                               FROM voyage_comments vc
                               INNER JOIN voyage_posts vp
                                   ON vp.id = vc.post_id
                               INNER JOIN voyage_streams vs
                                   ON vs.id = vp.stream_id
                              WHERE vs.floatplan_id = :floatPlanId",
                            {
                                floatPlanId = { value = targetFloatPlanId, cfsqltype = "cf_sql_integer" }
                            },
                            { datasource = appDsn }
                        );
                        queryExecute(
                            "DELETE vr
                               FROM voyage_reactions vr
                               INNER JOIN voyage_posts vp
                                   ON vp.id = vr.post_id
                               INNER JOIN voyage_streams vs
                                   ON vs.id = vp.stream_id
                              WHERE vs.floatplan_id = :floatPlanId",
                            {
                                floatPlanId = { value = targetFloatPlanId, cfsqltype = "cf_sql_integer" }
                            },
                            { datasource = appDsn }
                        );
                        queryExecute(
                            "DELETE vf
                               FROM voyage_followers vf
                               INNER JOIN voyage_streams vs
                                   ON vs.id = vf.stream_id
                              WHERE vs.floatplan_id = :floatPlanId",
                            {
                                floatPlanId = { value = targetFloatPlanId, cfsqltype = "cf_sql_integer" }
                            },
                            { datasource = appDsn }
                        );
                        queryExecute(
                            "DELETE vp
                               FROM voyage_posts vp
                               INNER JOIN voyage_streams vs
                                   ON vs.id = vp.stream_id
                              WHERE vs.floatplan_id = :floatPlanId",
                            {
                                floatPlanId = { value = targetFloatPlanId, cfsqltype = "cf_sql_integer" }
                            },
                            { datasource = appDsn }
                        );
                        queryExecute(
                            "DELETE FROM voyage_streams
                              WHERE floatplan_id = :floatPlanId",
                            {
                                floatPlanId = { value = targetFloatPlanId, cfsqltype = "cf_sql_integer" }
                            },
                            { datasource = appDsn }
                        );
                        queryExecute(
                            "DELETE FROM floatplan_monitor_events
                              WHERE monitoring_id = :monitoringId
                                AND float_plan_id = :floatPlanId",
                            {
                                monitoringId = { value = targetMonitoringId, cfsqltype = "cf_sql_integer" },
                                floatPlanId = { value = targetFloatPlanId, cfsqltype = "cf_sql_integer" }
                            },
                            { datasource = appDsn }
                        );
                        queryExecute(
                            "DELETE FROM floatplan_monitoring
                              WHERE id = :monitoringId
                                AND float_plan_id = :floatPlanId",
                            {
                                monitoringId = { value = targetMonitoringId, cfsqltype = "cf_sql_integer" },
                                floatPlanId = { value = targetFloatPlanId, cfsqltype = "cf_sql_integer" }
                            },
                            { datasource = appDsn }
                        );
                    }
                    message = "Deleted orphaned monitoring artifacts for float plan " & targetFloatPlanId & ".";
                    messageType = "success";
                } catch (any eDelete) {
                    message = eDelete.message;
                    if (len(trim(toString(eDelete.detail)))) {
                        message &= " " & trim(toString(eDelete.detail));
                    }
                    messageType = "error";
                }
            }
        }
    }

    qSummary = queryExecute(
        "
        SELECT
            COUNT(*) AS active_monitored,
            SUM(
                CASE
                    WHEN m.next_monitor_eval_at IS NOT NULL
                     AND m.next_monitor_eval_at > UTC_TIMESTAMP()
                     AND m.next_monitor_eval_at <= DATE_ADD(UTC_TIMESTAMP(), INTERVAL 30 MINUTE)
                     AND UPPER(TRIM(COALESCE(m.monitor_state, ''))) NOT IN ('LATE', 'MISSED', 'ESCALATED')
                    THEN 1 ELSE 0
                END
            ) AS due_soon_count,
            SUM(CASE WHEN UPPER(TRIM(COALESCE(m.monitor_state, ''))) = 'LATE' THEN 1 ELSE 0 END) AS overdue_count,
            SUM(CASE WHEN UPPER(TRIM(COALESCE(m.monitor_state, ''))) IN ('MISSED', 'ESCALATED') THEN 1 ELSE 0 END) AS missed_or_escalated_count
        FROM floatplan_monitoring m
        WHERE m.is_monitoring_enabled = 1
          AND UPPER(TRIM(COALESCE(m.monitor_state, ''))) <> 'CLOSED'
        ",
        {},
        { datasource = appDsn }
    );

    qRows = queryExecute(
        "
        SELECT
            m.id,
            m.float_plan_id,
            m.user_id,
            m.monitoring_mode,
            m.monitor_state,
            m.last_checkin_at,
            CONVERT_TZ(m.last_checkin_at, 'UTC', NULLIF(fp.departureTZ, '')) AS last_checkin_at_local,
            m.last_checkin_status,
            m.expected_checkin_at,
            CONVERT_TZ(m.expected_checkin_at, 'UTC', NULLIF(fp.departureTZ, '')) AS expected_checkin_at_local,
            m.grace_expires_at,
            CONVERT_TZ(m.grace_expires_at, 'UTC', NULLIF(fp.departureTZ, '')) AS grace_expires_at_local,
            m.next_monitor_eval_at,
            CONVERT_TZ(m.next_monitor_eval_at, 'UTC', NULLIF(fp.departureTZ, '')) AS next_monitor_eval_at_local,
            m.missed_at,
            m.escalated_at,
            m.secure_for_night,
            m.secure_for_night_until,
            CONVERT_TZ(m.secure_for_night_until, 'UTC', NULLIF(fp.departureTZ, '')) AS secure_for_night_until_local,
            fp.floatplanId AS joined_floatplan_id,
            fp.floatPlanName,
            fp.route_instance_id,
            fp.departureTime,
            fp.departureTZ,
            u.fName,
            u.lName,
            u.email,
            v.vesselName,
            vs.id AS stream_id,
            vs.slug,
            vs.share_token
        FROM floatplan_monitoring m
        LEFT JOIN floatplans fp
            ON fp.floatPlanId = m.float_plan_id
        LEFT JOIN users u
            ON u.userId = COALESCE(fp.userId, m.user_id)
        LEFT JOIN vessels v
            ON v.vesselID = fp.vesselId
        LEFT JOIN voyage_streams vs
            ON vs.floatplan_id = m.float_plan_id
        WHERE m.is_monitoring_enabled = 1
          AND UPPER(TRIM(COALESCE(m.monitor_state, ''))) <> 'CLOSED'
        ORDER BY
            CASE WHEN m.next_monitor_eval_at IS NULL THEN 1 ELSE 0 END,
            m.next_monitor_eval_at ASC,
            m.float_plan_id ASC
        ",
        {},
        { datasource = appDsn }
    );

    if (qSummary.recordCount) {
        activeMonitoredCount = asInt(qSummary.active_monitored[1], 0);
        dueSoonCount = asInt(qSummary.due_soon_count[1], 0);
        overdueCount = asInt(qSummary.overdue_count[1], 0);
        missedOrEscalatedCount = asInt(qSummary.missed_or_escalated_count[1], 0);
    }
}
</cfscript>
<cfinclude template="../includes/fpw_base_path.cfm">

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Admin Monitoring Dashboard</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 24px; background: #f7f7f7; color: #111; }
    .wrap { max-width: 1600px; margin: 0 auto; background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 20px; }
    .admin-nav { display: flex; gap: 8px; margin-bottom: 14px; flex-wrap: wrap; }
    .admin-nav a { text-decoration: none; border: 1px solid #bbb; background: #f5f5f5; color: #222; padding: 6px 10px; border-radius: 4px; font-size: 14px; }
    .admin-nav a.active { background: #111; border-color: #111; color: #fff; }
    h1 { margin: 0 0 8px; font-size: 24px; }
    .hint { color: #444; margin: 0 0 18px; }
    .msg { margin-bottom: 12px; padding: 10px; border-radius: 4px; }
    .msg.error { background: #ffecec; border: 1px solid #ffb4b4; color: #7f1d1d; }
    .msg.info { background: #edf2ff; border: 1px solid #b6c6ff; color: #13255a; }
    .msg.success { background: #e9f8ee; border: 1px solid #9dd9ad; color: #0e5522; }
    .page-actions { display: flex; gap: 10px; margin: 0 0 14px; flex-wrap: wrap; }
    .summary-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; margin-bottom: 18px; }
    .summary-card { border: 1px solid #ddd; border-radius: 8px; padding: 14px; background: #fafafa; }
    .summary-card .label { font-size: 12px; color: #666; text-transform: uppercase; letter-spacing: .08em; font-weight: 700; margin-bottom: 6px; }
    .summary-card .value { font-size: 32px; font-weight: 700; line-height: 1.1; }
    .summary-card .meta { margin-top: 8px; color: #555; font-size: 13px; }
    .table-responsive { overflow-x: auto; }
    table { width: 100%; border-collapse: collapse; font-size: 14px; }
    th, td { border: 1px solid #ddd; padding: 10px; text-align: left; vertical-align: top; }
    th { background: #f0f0f0; white-space: nowrap; }
    .mono { font-family: Consolas, Menlo, Monaco, monospace; white-space: nowrap; }
    .status-pill { display: inline-block; padding: 3px 8px; border-radius: 999px; font-size: 12px; font-weight: 700; letter-spacing: .04em; border: 1px solid #bbb; background: #f7f7f7; }
    .status-pill.active { background: #e9f8ee; border-color: #9dd9ad; color: #0e5522; }
    .status-pill.late { background: #fff4e5; border-color: #f0bf75; color: #7a4a00; }
    .status-pill.missed, .status-pill.escalated { background: #ffecec; border-color: #ffb4b4; color: #7f1d1d; }
    .timing-note { display: inline-block; margin-top: 6px; padding: 2px 7px; border-radius: 999px; font-size: 11px; font-weight: 700; background: #edf2ff; color: #13255a; border: 1px solid #b6c6ff; }
    .timing-note.warn { background: #fff4e5; color: #7a4a00; border-color: #f0bf75; }
    .link-list { display: flex; flex-direction: column; gap: 6px; }
    .link-list a { color: #0b57d0; text-decoration: none; }
    .link-list a:hover { text-decoration: underline; }
    .inline-form { margin: 0; }
    .btn-linkish { display: inline-block; border: 1px solid #bbb; background: #fff; color: #222; padding: 5px 8px; border-radius: 4px; font-size: 12px; cursor: pointer; }
    .btn-linkish:hover { background: #f5f5f5; }
    .btn-danger { border-color: #9f1d1d; background: #c82333; color: #fff; }
    .btn-danger:hover { background: #b31d2c; }
    .muted { color: #666; font-size: 12px; }
    .nowrap { white-space: nowrap; }
    .small { font-size: 12px; }
    @media (max-width: 1100px) {
      .summary-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    }
    @media (max-width: 700px) {
      body { margin: 12px; }
      .wrap { padding: 14px; }
      .summary-grid { grid-template-columns: repeat(1, minmax(0, 1fr)); }
    }
  </style>
</head>
<body>
  <div class="wrap">
    <cfinclude template="includes/admin_reports_nav.cfm">

    <h1>Admin Monitoring Dashboard</h1>
    <p class="hint">Canonical monitoring view for all enabled monitoring rows. Follow is the primary support drill-in. Active Cruise link is conditional and may reject non-owner access.</p>

    <cfif NOT isAuthorized>
      <div class="msg error"><strong>Unauthorized:</strong> Admin login is required.</div>
    <cfelseif NOT len(appDsn)>
      <div class="msg error"><strong>Application error:</strong> application.dsn is not set.</div>
    <cfelse>
      <cfif len(message)>
        <cfoutput><div class="msg #encodeForHtmlAttribute(messageType)#">#encodeForHtml(message)#</div></cfoutput>
      </cfif>
      <div class="page-actions">
        <form method="post" class="inline-form">
          <input type="hidden" name="actionType" value="runmonitor">
          <button type="submit" class="btn-linkish">Run Monitor Now</button>
        </form>
      </div>
      <div class="summary-grid">
        <div class="summary-card">
          <div class="label">Active Monitored Trips</div>
          <div class="value"><cfoutput>#activeMonitoredCount#</cfoutput></div>
          <div class="meta">Canonical enabled monitoring rows where state is not closed.</div>
        </div>
        <div class="summary-card">
          <div class="label">Due Soon</div>
          <div class="value"><cfoutput>#dueSoonCount#</cfoutput></div>
          <div class="meta">Display only: <span class="mono">next_monitor_eval_at</span> within 30 minutes, excluding canonical <span class="mono">LATE</span>, <span class="mono">MISSED</span>, and <span class="mono">ESCALATED</span>.</div>
        </div>
        <div class="summary-card">
          <div class="label">Overdue</div>
          <div class="value"><cfoutput>#overdueCount#</cfoutput></div>
          <div class="meta">Canonical only: <span class="mono">monitor_state = 'LATE'</span>.</div>
        </div>
        <div class="summary-card">
          <div class="label">Missed / Escalated</div>
          <div class="value"><cfoutput>#missedOrEscalatedCount#</cfoutput></div>
          <div class="meta">Canonical only: <span class="mono">MISSED</span> or <span class="mono">ESCALATED</span>.</div>
        </div>
      </div>

      <div class="msg info">Showing <cfoutput>#qRows.recordCount#</cfoutput> canonical monitoring row(s). Rows with missing float plan metadata are still included.</div>

      <div class="table-responsive">
        <table>
          <thead>
            <tr>
              <th>Float Plan</th>
              <th>Stream</th>
              <th>Trip</th>
              <th>User</th>
              <th>Vessel</th>
              <th>Status</th>
              <th>Last Check-In</th>
              <th>Next Expected</th>
              <th>Grace Expires</th>
              <th>Next Eval</th>
              <th>Links</th>
            </tr>
          </thead>
          <tbody>
            <cfif NOT qRows.recordCount>
              <tr>
                <td colspan="11">No enabled monitoring rows found.</td>
              </tr>
            <cfelse>
              <cfoutput query="qRows">
                <cfscript>
                  rowState = uCase(textValue(qRows.monitor_state));
                  rowPillClass = lCase(rowState);
                  hasJoinedFloatPlan = asInt(qRows.joined_floatplan_id, 0) GT 0;
                  isOrphanRow = !hasJoinedFloatPlan;
                  followUrl = buildFollowUrl(qRows.slug, qRows.share_token);
                  activeCruiseUrl = buildActiveCruiseUrl(qRows.float_plan_id);
                  userLabel = trim(textValue(qRows.fName) & " " & textValue(qRows.lName));
                  if (!len(userLabel)) userLabel = textValue(qRows.email);
                  isDueSoon = isDate(qRows.next_monitor_eval_at)
                    AND dateCompare(qRows.next_monitor_eval_at, now(), "s") GT 0
                    AND dateDiff("n", now(), qRows.next_monitor_eval_at) LTE 30
                    AND !listFindNoCase("LATE,MISSED,ESCALATED", rowState);
                  isEvalDueNow = isDate(qRows.next_monitor_eval_at)
                    AND dateCompare(qRows.next_monitor_eval_at, now(), "s") LTE 0
                    AND !listFindNoCase("LATE,MISSED,ESCALATED", rowState);
                </cfscript>
                <tr>
                  <td class="mono">#asInt(qRows.float_plan_id, 0)#</td>
                  <td class="mono"><cfif asInt(qRows.stream_id, 0) GT 0>#asInt(qRows.stream_id, 0)#<cfelse>&mdash;</cfif></td>
                  <td>
                    <div>#buildTripLabel(qRows.floatPlanName, qRows.float_plan_id)#</div>
                    <div class="muted">Mode: #formatAdminText(qRows.monitoring_mode)#</div>
                    <cfif asInt(qRows.route_instance_id, 0) GT 0>
                      <div class="muted">Route instance: #asInt(qRows.route_instance_id, 0)#</div>
                    </cfif>
                  </td>
                  <td>
                    <div>#formatAdminText(userLabel)#</div>
                    <div class="muted">#formatAdminText(qRows.email)#</div>
                    <div class="muted">User ID: #asInt(qRows.user_id, 0)#</div>
                  </td>
                  <td>
                    <div>#formatAdminText(qRows.vesselName)#</div>
                    <cfif asInt(qRows.secure_for_night, 0) EQ 1>
                      <div class="muted">Secure for night until #formatAdminDateTime(isDate(qRows.secure_for_night_until_local) ? qRows.secure_for_night_until_local : qRows.secure_for_night_until)#</div>
                    </cfif>
                  </td>
                  <td>
                    <span class="status-pill #rowPillClass#">#encodeForHtml(rowState)#</span>
                    <cfif isEvalDueNow>
                      <div class="timing-note warn">Eval due now</div>
                    <cfelseif isDueSoon>
                      <div class="timing-note">Due soon (30m)</div>
                    </cfif>
                  </td>
                  <td>
                    <div>#formatAdminDateTime(isDate(qRows.last_checkin_at_local) ? qRows.last_checkin_at_local : qRows.last_checkin_at)#</div>
                    <cfif len(textValue(qRows.last_checkin_status))>
                      <div class="muted">#formatAdminText(qRows.last_checkin_status)#</div>
                    </cfif>
                  </td>
                  <td>#formatAdminDateTime(isDate(qRows.expected_checkin_at_local) ? qRows.expected_checkin_at_local : qRows.expected_checkin_at)#</td>
                  <td>#formatAdminDateTime(isDate(qRows.grace_expires_at_local) ? qRows.grace_expires_at_local : qRows.grace_expires_at)#</td>
                  <td>#formatAdminDateTime(isDate(qRows.next_monitor_eval_at_local) ? qRows.next_monitor_eval_at_local : qRows.next_monitor_eval_at)#</td>
                  <td>
                    <div class="link-list">
                      <cfif len(followUrl)>
                        <a href="#encodeForHtmlAttribute(followUrl)#" target="_blank" rel="noopener">Follow</a>
                      <cfelse>
                        <span class="muted">Follow unavailable</span>
                      </cfif>
                      <cfif len(activeCruiseUrl)>
                        <a href="#encodeForHtmlAttribute(activeCruiseUrl)#" target="_blank" rel="noopener">Active Cruise</a>
                        <span class="muted">Conditional owner-bound link</span>
                      <cfelse>
                        <span class="muted">Active Cruise unavailable</span>
                      </cfif>
                      <cfif hasJoinedFloatPlan>
                        <form method="post" class="inline-form">
                          <input type="hidden" name="actionType" value="close">
                          <input type="hidden" name="targetFloatPlanId" value="#asInt(qRows.float_plan_id, 0)#">
                          <button type="submit" class="btn-linkish">Close Monitoring</button>
                        </form>
                      <cfelseif isOrphanRow>
                        <form method="post" class="inline-form">
                          <input type="hidden" name="actionType" value="deleteorphan">
                          <input type="hidden" name="targetMonitoringId" value="#asInt(qRows.id, 0)#">
                          <input type="hidden" name="targetFloatPlanId" value="#asInt(qRows.float_plan_id, 0)#">
                          <button type="submit" class="btn-linkish btn-danger">Delete Orphaned</button>
                        </form>
                        <span class="muted">Deletes orphaned monitoring + stream artifacts</span>
                      </cfif>
                    </div>
                  </td>
                </tr>
              </cfoutput>
            </cfif>
          </tbody>
        </table>
      </div>
    </cfif>
  </div>
</body>
</html>
