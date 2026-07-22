<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">
<cfinclude template="../includes/fpw_base_path.cfm">

<cfscript>
actionType = "";
targetUserIdRaw = "";
targetUserId = 0;
forceConfirmRaw = "";
forceExpected = "";
hasInput = false;
hasValidUserId = false;
message = "";
messageType = "info";
deleteBlocked = false;
deleteBlockCode = "";
deleteProtection = {
    premiumHistoryCount = 0,
    activeCount = 0
};

summary = {
    totalCount = 0,
    deletableCount = 0,
    skippedCount = 0,
    premiumHistoryProtectedCount = 0,
    activeProtectedCount = 0
};
plans = queryNew("floatplanId,name,statusValue,premiumHistoryProtected");

if (structKeyExists(form, "actionType")) {
    actionType = lcase(trim(toString(form.actionType)));
}
if (structKeyExists(form, "targetUserId")) {
    targetUserIdRaw = trim(toString(form.targetUserId));
}
if (structKeyExists(form, "forceConfirm")) {
    forceConfirmRaw = trim(toString(form.forceConfirm));
}

function queryToStructArray(required query q) {
    var rows = [];
    var row = {};
    var col = "";
    var i = 0;

    if (!isQuery(arguments.q) OR arguments.q.recordCount EQ 0) {
        return rows;
    }

    for (i = 1; i LTE arguments.q.recordCount; i++) {
        row = {};
        for (col in listToArray(arguments.q.columnList)) {
            row[col] = arguments.q[col][i];
        }
        arrayAppend(rows, row);
    }
    return rows;
}

function loadFloatPlanDeleteProtection(
    required numeric userId,
    boolean includeAllStatuses=false,
    boolean lockRows=false
) {
    var result = {
        premiumHistoryCount = 0,
        activeCount = 0
    };
    var statusFilter = arguments.includeAllStatuses
        ? ""
        : " AND UPPER(TRIM(f.`status`)) IN ('DRAFT', 'CLOSED')";
    var params = {
        userId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" }
    };
    var qLocks = queryNew("");
    var qProtection = queryNew("");

    if (arguments.lockRows) {
        qLocks = queryExecute(
            "SELECT f.floatplanId
               FROM floatplans f
              WHERE f.userId = :userId" & statusFilter & "
              FOR UPDATE",
            params,
            { datasource = "fpw" }
        );
    }

    qProtection = queryExecute(
        "SELECT
            SUM(
                CASE
                    WHEN EXISTS (
                        SELECT 1
                          FROM premium_send_credits psc
                         WHERE psc.consumed_float_plan_id = f.floatplanId
                    )
                    OR EXISTS (
                        SELECT 1
                          FROM premium_send_receipts psr
                         WHERE psr.float_plan_id = f.floatplanId
                    )
                    THEN 1 ELSE 0
                END
            ) AS premiumHistoryCount,
            SUM(
                CASE
                    WHEN UPPER(TRIM(f.`status`)) = 'ACTIVE'
                    THEN 1 ELSE 0
                END
            ) AS activeCount
           FROM floatplans f
          WHERE f.userId = :userId" & statusFilter,
        params,
        { datasource = "fpw" }
    );

    if (qProtection.recordCount GT 0) {
        result.premiumHistoryCount = val(qProtection.premiumHistoryCount[1]);
        result.activeCount = val(qProtection.activeCount[1]);
    }
    return result;
}

hasInput = len(targetUserIdRaw) GT 0;
if (hasInput AND isNumeric(targetUserIdRaw) AND val(targetUserIdRaw) GT 0) {
    targetUserId = val(targetUserIdRaw);
    hasValidUserId = true;
} else if (hasInput) {
    message = "Enter a valid numeric user id.";
    messageType = "error";
}

if (hasValidUserId AND listFindNoCase("preview,delete,forcedelete", actionType)) {
    if (actionType EQ "delete") {
        deleteProtection = loadFloatPlanDeleteProtection(targetUserId, false, false);
        if (deleteProtection.premiumHistoryCount GT 0) {
            message = "PREMIUM_SEND_HISTORY_DELETE_BLOCKED: Retained Premium Send history prevents this cleanup.";
            messageType = "error";
        } else {
            deletableCountQ = queryExecute(
                "SELECT COUNT(*) AS deleteCount
                   FROM floatplans
                  WHERE userId = :userId
                    AND UPPER(TRIM(`status`)) IN ('DRAFT', 'CLOSED')",
                {
                    userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" }
                },
                { datasource = "fpw" }
            );
            deleteCount = (deletableCountQ.recordCount GT 0) ? val(deletableCountQ.deleteCount[1]) : 0;

            if (deleteCount GT 0) {
                deleteBlocked = false;
                transaction {
                    queryExecute(
                        "SELECT userId
                           FROM users
                          WHERE userId = :userId
                          LIMIT 1
                          FOR UPDATE",
                        {
                            userId = { value = targetUserId, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = "fpw" }
                    );
                    deleteProtection = loadFloatPlanDeleteProtection(targetUserId, false, true);
                    if (deleteProtection.premiumHistoryCount GT 0) {
                        deleteBlocked = true;
                        deleteBlockCode = "PREMIUM_SEND_HISTORY_DELETE_BLOCKED";
                    } else {
                        queryExecute(
                            "DELETE fp
                               FROM floatplan_passengers fp
                               INNER JOIN floatplans f ON f.floatplanId = fp.floatplanId
                              WHERE f.userId = :userId
                                AND UPPER(TRIM(f.`status`)) IN ('DRAFT', 'CLOSED')",
                            {
                                userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" }
                            },
                            { datasource = "fpw" }
                        );
                        queryExecute(
                            "DELETE fc
                               FROM floatplan_contacts fc
                               INNER JOIN floatplans f ON f.floatplanId = fc.floatplanId
                              WHERE f.userId = :userId
                                AND UPPER(TRIM(f.`status`)) IN ('DRAFT', 'CLOSED')",
                            {
                                userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" }
                            },
                            { datasource = "fpw" }
                        );
                        queryExecute(
                            "DELETE fw
                               FROM floatplan_waypoints fw
                               INNER JOIN floatplans f ON f.floatplanId = fw.floatplanId
                              WHERE f.userId = :userId
                                AND UPPER(TRIM(f.`status`)) IN ('DRAFT', 'CLOSED')",
                            {
                                userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" }
                            },
                            { datasource = "fpw" }
                        );
                        queryExecute(
                            "DELETE FROM floatplans
                              WHERE userId = :userId
                                AND UPPER(TRIM(`status`)) IN ('DRAFT', 'CLOSED')",
                            {
                                userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" }
                            },
                            { datasource = "fpw" }
                        );
                    }
                }
                if (deleteBlocked) {
                    message = deleteBlockCode & ": Retained Premium Send history prevents this cleanup.";
                    messageType = "error";
                } else {
                    message = "Deleted " & deleteCount & " float plan(s) for user " & targetUserId & ".";
                    messageType = "success";
                }
            } else {
                message = "No DRAFT/CLOSED float plans found for user " & targetUserId & ".";
                messageType = "info";
            }
        }
    } else if (actionType EQ "forcedelete") {
        forceExpected = "FORCE DELETE " & targetUserId;
        if (forceConfirmRaw NEQ forceExpected) {
            message = "Force delete blocked. Type exactly: " & forceExpected;
            messageType = "error";
        } else {
            deleteProtection = loadFloatPlanDeleteProtection(targetUserId, true, false);
            if (deleteProtection.premiumHistoryCount GT 0) {
                message = "PREMIUM_SEND_HISTORY_DELETE_BLOCKED: Retained Premium Send history prevents force cleanup.";
                messageType = "error";
            } else if (deleteProtection.activeCount GT 0) {
                message = "ACTIVE_FLOATPLAN_DELETE_BLOCKED: Close or cancel every Active float plan before force cleanup.";
                messageType = "error";
            } else {
            forceCountQ = queryExecute(
                "SELECT COUNT(*) AS totalCount
                   FROM floatplans
                  WHERE userId = :userId",
                {
                    userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" }
                },
                { datasource = "fpw" }
            );
            forceDeleteCount = (forceCountQ.recordCount GT 0) ? val(forceCountQ.totalCount[1]) : 0;

            statusBreakdownQ = queryExecute(
                "SELECT UPPER(TRIM(`status`)) AS statusValue, COUNT(*) AS planCount
                   FROM floatplans
                  WHERE userId = :userId
                  GROUP BY UPPER(TRIM(`status`))
                  ORDER BY statusValue",
                {
                    userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" }
                },
                { datasource = "fpw" }
            );
            snapshotFloatplansQ = queryExecute(
                "SELECT *
                   FROM floatplans
                  WHERE userId = :userId
                  ORDER BY floatplanId",
                {
                    userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" }
                },
                { datasource = "fpw" }
            );
            snapshotContactsQ = queryExecute(
                "SELECT fc.*
                   FROM floatplan_contacts fc
                   INNER JOIN floatplans f ON f.floatplanId = fc.floatplanId
                  WHERE f.userId = :userId
                  ORDER BY fc.floatplanId",
                {
                    userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" }
                },
                { datasource = "fpw" }
            );
            snapshotPassengersQ = queryExecute(
                "SELECT fp.*
                   FROM floatplan_passengers fp
                   INNER JOIN floatplans f ON f.floatplanId = fp.floatplanId
                  WHERE f.userId = :userId
                  ORDER BY fp.floatplanId",
                {
                    userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" }
                },
                { datasource = "fpw" }
            );
            snapshotWaypointsQ = queryExecute(
                "SELECT fw.*
                   FROM floatplan_waypoints fw
                   INNER JOIN floatplans f ON f.floatplanId = fw.floatplanId
                  WHERE f.userId = :userId
                  ORDER BY fw.floatplanId",
                {
                    userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" }
                },
                { datasource = "fpw" }
            );

            tmpDir = expandPath("../tmp/");
            if (!directoryExists(tmpDir)) {
                directoryCreate(tmpDir);
            }
            snapshotFile = "rollback_floatplans_user_" & targetUserId & "_" & dateTimeFormat(now(), "yyyymmdd_HHnnss") & ".json";
            snapshotPath = tmpDir & snapshotFile;
            snapshotData = {
                generatedAt = dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss"),
                targetUserId = targetUserId,
                totalPlans = forceDeleteCount,
                statusBreakdown = queryToStructArray(statusBreakdownQ),
                floatplans = queryToStructArray(snapshotFloatplansQ),
                floatplan_contacts = queryToStructArray(snapshotContactsQ),
                floatplan_passengers = queryToStructArray(snapshotPassengersQ),
                floatplan_waypoints = queryToStructArray(snapshotWaypointsQ)
            };
            fileWrite(snapshotPath, serializeJSON(snapshotData));

            if (forceDeleteCount GT 0) {
                deleteBlocked = false;
                transaction {
                    queryExecute(
                        "SELECT userId
                           FROM users
                          WHERE userId = :userId
                          LIMIT 1
                          FOR UPDATE",
                        {
                            userId = { value = targetUserId, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = "fpw" }
                    );
                    deleteProtection = loadFloatPlanDeleteProtection(targetUserId, true, true);
                    if (deleteProtection.premiumHistoryCount GT 0) {
                        deleteBlocked = true;
                        deleteBlockCode = "PREMIUM_SEND_HISTORY_DELETE_BLOCKED";
                    } else if (deleteProtection.activeCount GT 0) {
                        deleteBlocked = true;
                        deleteBlockCode = "ACTIVE_FLOATPLAN_DELETE_BLOCKED";
                    } else {
                        queryExecute(
                            "DELETE fp
                               FROM floatplan_passengers fp
                               INNER JOIN floatplans f ON f.floatplanId = fp.floatplanId
                              WHERE f.userId = :userId",
                            {
                                userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" }
                            },
                            { datasource = "fpw" }
                        );
                        queryExecute(
                            "DELETE fc
                               FROM floatplan_contacts fc
                               INNER JOIN floatplans f ON f.floatplanId = fc.floatplanId
                              WHERE f.userId = :userId",
                            {
                                userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" }
                            },
                            { datasource = "fpw" }
                        );
                        queryExecute(
                            "DELETE fw
                               FROM floatplan_waypoints fw
                               INNER JOIN floatplans f ON f.floatplanId = fw.floatplanId
                              WHERE f.userId = :userId",
                            {
                                userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" }
                            },
                            { datasource = "fpw" }
                        );
                        queryExecute(
                            "DELETE FROM floatplans
                              WHERE userId = :userId",
                            {
                                userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" }
                            },
                            { datasource = "fpw" }
                        );
                    }
                }
                if (deleteBlocked) {
                    message = deleteBlockCode & ": This force cleanup was blocked after the transactional recheck.";
                    messageType = "error";
                } else {
                    message = "Force deleted " & forceDeleteCount & " float plan(s) for user " & targetUserId & ". Snapshot: " & request.fpwBase & "/tmp/" & snapshotFile;
                    messageType = "success";
                }
            } else {
                message = "No float plans found for user " & targetUserId & ". Empty snapshot created: " & request.fpwBase & "/tmp/" & snapshotFile;
                messageType = "info";
            }
            }
        }
    }

    summaryQ = queryExecute(
        "SELECT
            COUNT(*) AS totalCount,
            SUM(CASE WHEN UPPER(TRIM(`status`)) IN ('DRAFT', 'CLOSED') THEN 1 ELSE 0 END) AS deletableCount,
            SUM(CASE WHEN UPPER(TRIM(`status`)) IN ('DRAFT', 'CLOSED') THEN 0 ELSE 1 END) AS skippedCount
           FROM floatplans
          WHERE userId = :userId",
        {
            userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" }
        },
        { datasource = "fpw" }
    );

    plans = queryExecute(
        "SELECT
            f.floatplanId,
            COALESCE(NULLIF(TRIM(f.floatPlanName), ''), '[unnamed]') AS name,
            UPPER(TRIM(f.`status`)) AS statusValue,
            CASE
                WHEN EXISTS (
                    SELECT 1
                      FROM premium_send_credits psc
                     WHERE psc.consumed_float_plan_id = f.floatplanId
                )
                OR EXISTS (
                    SELECT 1
                      FROM premium_send_receipts psr
                     WHERE psr.float_plan_id = f.floatplanId
                )
                THEN 1 ELSE 0
            END AS premiumHistoryProtected
           FROM floatplans f
          WHERE f.userId = :userId
          ORDER BY f.floatplanId DESC",
        {
            userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" }
        },
        { datasource = "fpw" }
    );

    deleteProtection = loadFloatPlanDeleteProtection(targetUserId, true, false);
    if (summaryQ.recordCount GT 0) {
        summary.totalCount = val(summaryQ.totalCount[1]);
        summary.deletableCount = val(summaryQ.deletableCount[1]);
        summary.skippedCount = val(summaryQ.skippedCount[1]);
        summary.premiumHistoryProtectedCount = deleteProtection.premiumHistoryCount;
        summary.activeProtectedCount = deleteProtection.activeCount;
    }
}
</cfscript>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Admin FloatPlan Cleanup</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 24px; background: #f7f7f7; color: #111; }
    .wrap { max-width: 980px; margin: 0 auto; background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 20px; }
    .admin-nav { display: flex; gap: 8px; margin-bottom: 14px; flex-wrap: wrap; }
    .admin-nav a { text-decoration: none; border: 1px solid #bbb; background: #f5f5f5; color: #222; padding: 6px 10px; border-radius: 4px; font-size: 14px; }
    .admin-nav a.active { background: #111; border-color: #111; color: #fff; }
    h1 { margin-top: 0; font-size: 24px; }
    .hint { color: #444; margin-bottom: 16px; }
    .row { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
    input[type="text"] { width: 220px; padding: 8px; border: 1px solid #bbb; border-radius: 4px; font-size: 14px; }
    button { padding: 8px 12px; border-radius: 4px; border: 1px solid #666; background: #efefef; cursor: pointer; }
    button.danger { border-color: #9f1d1d; background: #c82333; color: #fff; }
    .msg { margin-top: 12px; padding: 10px; border-radius: 4px; }
    .msg.info { background: #edf2ff; border: 1px solid #b6c6ff; }
    .msg.success { background: #e9f8ee; border: 1px solid #9dd9ad; }
    .msg.error { background: #ffecec; border: 1px solid #ffb4b4; }
    .stats { display: flex; gap: 12px; margin-top: 16px; flex-wrap: wrap; }
    .stat { background: #fafafa; border: 1px solid #ddd; border-radius: 6px; padding: 10px 12px; }
    table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 14px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background: #f0f0f0; }
  </style>
</head>
<body>
  <div class="wrap">
    <cfinclude template="includes/admin_reports_nav.cfm">
    <h1>Admin FloatPlan Cleanup</h1>
    <p class="hint">Dev-only utility for cleanup by user id.</p>
    <div class="msg info">
      <strong>Instructions</strong>
      <ol>
        <li>Enter a numeric user id and click <strong>Preview</strong>.</li>
        <li>Use <strong>Delete All Deletable Plans</strong> to remove only <strong>DRAFT/CLOSED</strong> (dashboard-equivalent behavior).</li>
        <li>Use <strong>Force Delete All Plans (All Statuses)</strong> to remove every plan status; you must type exact confirmation text first.</li>
        <li>Force delete always writes a rollback snapshot JSON file under <code><cfoutput>#request.fpwBase#</cfoutput>/tmp/</code> before deleting.</li>
      </ol>
    </div>

    <form method="post" action="<cfoutput>#request.fpwBase#</cfoutput>/admin/floatplan-cleanup.cfm">
      <div class="row">
        <label for="targetUserId"><strong>User ID</strong></label>
        <input id="targetUserId" name="targetUserId" type="text" value="<cfoutput>#encodeForHtmlAttribute(targetUserIdRaw)#</cfoutput>" placeholder="e.g. 187">
        <button type="submit" name="actionType" value="preview">Preview</button>
        <button type="submit" name="actionType" value="delete" class="danger" onclick="return confirm('Delete all DRAFT/CLOSED float plans for this user?');">Delete All Deletable Plans</button>
      </div>
      <div class="row" style="margin-top:10px;">
        <label for="forceConfirm"><strong>Force Confirm</strong></label>
        <input id="forceConfirm" name="forceConfirm" type="text" value="<cfoutput>#encodeForHtmlAttribute(forceConfirmRaw)#</cfoutput>" placeholder="FORCE DELETE 187" style="width: 320px;">
        <button type="submit" name="actionType" value="forcedelete" class="danger" onclick="return confirm('Force delete will remove ALL statuses for this user. Continue?');">Force Delete All Plans (All Statuses)</button>
      </div>
    </form>

    <cfif len(message)>
      <div class="msg <cfoutput>#messageType#</cfoutput>"><cfoutput>#encodeForHtml(message)#</cfoutput></div>
    </cfif>

    <cfif hasValidUserId AND listFindNoCase("preview,delete,forcedelete", actionType)>
      <div class="stats">
        <div class="stat"><strong>User:</strong> <cfoutput>#targetUserId#</cfoutput></div>
        <div class="stat"><strong>Total Plans:</strong> <cfoutput>#summary.totalCount#</cfoutput></div>
        <div class="stat"><strong>Deletable:</strong> <cfoutput>#summary.deletableCount#</cfoutput></div>
        <div class="stat"><strong>Skipped:</strong> <cfoutput>#summary.skippedCount#</cfoutput></div>
        <div class="stat"><strong>Premium History Protected:</strong> <cfoutput>#summary.premiumHistoryProtectedCount#</cfoutput></div>
        <div class="stat"><strong>Active Protected:</strong> <cfoutput>#summary.activeProtectedCount#</cfoutput></div>
      </div>

      <table>
        <thead>
          <tr>
            <th>FloatPlan ID</th>
            <th>Name</th>
            <th>Status</th>
            <th>Premium History</th>
            <th>Delete Eligible</th>
          </tr>
        </thead>
        <tbody>
          <cfif plans.recordCount EQ 0>
            <tr><td colspan="5">No float plans found for this user.</td></tr>
          <cfelse>
            <cfoutput query="plans">
              <tr>
                <td>#floatplanId#</td>
                <td>#encodeForHtml(name)#</td>
                <td>#encodeForHtml(statusValue)#</td>
                <td>#iif(val(premiumHistoryProtected) GT 0, de("PROTECTED"), de("NO"))#</td>
                <td>#iif(listFindNoCase("DRAFT,CLOSED", statusValue) AND val(premiumHistoryProtected) EQ 0, de("YES"), de("NO"))#</td>
              </tr>
            </cfoutput>
          </cfif>
        </tbody>
      </table>
    </cfif>
  </div>
</body>
</html>
