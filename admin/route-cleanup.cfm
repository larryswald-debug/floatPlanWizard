<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">

<cfscript>
actionType = "";
targetUserIdRaw = "";
targetUserId = 0;
forceConfirmRaw = "";
forceExpected = "";
routePrefix = "";
hasInput = false;
hasValidUserId = false;
message = "";
messageType = "info";

summary = {
    totalRoutes = 0,
    totalInstances = 0,
    orphanInstances = 0
};
routes = queryNew("routeId,routeName,routeCode,sectionCount,segmentCount,totalNm,totalLocks,hasInstance");

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

if (structKeyExists(form, "actionType")) {
    actionType = lcase(trim(toString(form.actionType)));
}
if (structKeyExists(form, "targetUserId")) {
    targetUserIdRaw = trim(toString(form.targetUserId));
}
if (structKeyExists(form, "forceConfirm")) {
    forceConfirmRaw = trim(toString(form.forceConfirm));
}

hasInput = len(targetUserIdRaw) GT 0;
if (hasInput AND isNumeric(targetUserIdRaw) AND val(targetUserIdRaw) GT 0) {
    targetUserId = val(targetUserIdRaw);
    hasValidUserId = true;
    routePrefix = "USER_ROUTE_" & targetUserId & "_%";
} else if (hasInput) {
    message = "Enter a valid numeric user id.";
    messageType = "error";
}

if (hasValidUserId AND listFindNoCase("preview,delete,forcedelete", actionType)) {
    if (actionType EQ "delete" OR actionType EQ "forcedelete") {
        forceExpected = "FORCE DELETE ROUTES " & targetUserId;
        if (actionType EQ "forcedelete" AND forceConfirmRaw NEQ forceExpected) {
            message = "Force delete blocked. Type exactly: " & forceExpected;
            messageType = "error";
        } else {
            forceRoutesQ = queryExecute(
                "SELECT COUNT(*) AS routeCount
                   FROM loop_routes
                  WHERE short_code LIKE :prefix",
                {
                    prefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" }
                },
                { datasource = "fpw" }
            );
            forceInstancesQ = queryExecute(
                "SELECT COUNT(*) AS instanceCount
                   FROM route_instances
                  WHERE user_id = :userId
                    AND generated_route_code LIKE :prefix",
                {
                    userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" },
                    prefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" }
                },
                { datasource = "fpw" }
            );
            forceRouteCount = (forceRoutesQ.recordCount GT 0) ? val(forceRoutesQ.routeCount[1]) : 0;
            forceInstanceCount = (forceInstancesQ.recordCount GT 0) ? val(forceInstancesQ.instanceCount[1]) : 0;

            snapshotRoutesQ = queryExecute(
                "SELECT *
                   FROM loop_routes
                  WHERE short_code LIKE :prefix
                  ORDER BY id",
                {
                    prefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" }
                },
                { datasource = "fpw" }
            );
            snapshotSectionsQ = queryExecute(
                "SELECT sec.*
                   FROM loop_sections sec
                   INNER JOIN loop_routes r ON r.id = sec.route_id
                  WHERE r.short_code LIKE :prefix
                  ORDER BY sec.route_id, sec.order_index, sec.id",
                {
                    prefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" }
                },
                { datasource = "fpw" }
            );
            snapshotSegmentsQ = queryExecute(
                "SELECT s.*
                   FROM loop_segments s
                   INNER JOIN loop_sections sec ON sec.id = s.section_id
                   INNER JOIN loop_routes r ON r.id = sec.route_id
                  WHERE r.short_code LIKE :prefix
                  ORDER BY sec.route_id, sec.order_index, s.order_index, s.id",
                {
                    prefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" }
                },
                { datasource = "fpw" }
            );
            snapshotProgressQ = queryExecute(
                "SELECT urp.*
                   FROM user_route_progress urp
                   INNER JOIN loop_segments s ON s.id = urp.segment_id
                   INNER JOIN loop_sections sec ON sec.id = s.section_id
                   INNER JOIN loop_routes r ON r.id = sec.route_id
                  WHERE r.short_code LIKE :prefix
                  ORDER BY urp.user_id, urp.segment_id",
                {
                    prefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" }
                },
                { datasource = "fpw" }
            );
            snapshotInstancesQ = queryExecute(
                "SELECT *
                   FROM route_instances
                  WHERE user_id = :userId
                    AND generated_route_code LIKE :prefix
                  ORDER BY id",
                {
                    userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" },
                    prefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" }
                },
                { datasource = "fpw" }
            );
            snapshotFloatplansQ = queryExecute(
                "SELECT fp.floatplanId, fp.userId, fp.floatPlanName, fp.status, fp.route_instance_id, fp.route_day_number
                   FROM floatplans fp
                   INNER JOIN route_instances ri ON ri.id = fp.route_instance_id
                  WHERE ri.user_id = :userId
                    AND ri.generated_route_code LIKE :prefix
                  ORDER BY fp.floatplanId",
                {
                    userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" },
                    prefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" }
                },
                { datasource = "fpw" }
            );

            tmpDir = expandPath("../tmp/");
            if (!directoryExists(tmpDir)) {
                directoryCreate(tmpDir);
            }
            snapshotFile = "rollback_routes_user_" & targetUserId & "_" & dateTimeFormat(now(), "yyyymmdd_HHnnss") & ".json";
            snapshotPath = tmpDir & snapshotFile;
            snapshotData = {
                generatedAt = dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss"),
                targetUserId = targetUserId,
                routePrefix = routePrefix,
                totalRoutes = forceRouteCount,
                totalRouteInstances = forceInstanceCount,
                loop_routes = queryToStructArray(snapshotRoutesQ),
                loop_sections = queryToStructArray(snapshotSectionsQ),
                loop_segments = queryToStructArray(snapshotSegmentsQ),
                user_route_progress = queryToStructArray(snapshotProgressQ),
                route_instances = queryToStructArray(snapshotInstancesQ),
                linked_floatplans = queryToStructArray(snapshotFloatplansQ)
            };
            fileWrite(snapshotPath, serializeJSON(snapshotData));

            if (forceRouteCount GT 0 OR forceInstanceCount GT 0) {
                transaction {
                    queryExecute(
                        "UPDATE floatplans fp
                           INNER JOIN route_instances ri ON ri.id = fp.route_instance_id
                           SET fp.route_instance_id = NULL,
                               fp.route_day_number = NULL
                         WHERE ri.user_id = :userId
                           AND ri.generated_route_code LIKE :prefix",
                        {
                            userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" },
                            prefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" }
                        },
                        { datasource = "fpw" }
                    );
                    queryExecute(
                        "DELETE urp
                           FROM user_route_progress urp
                           INNER JOIN loop_segments s ON s.id = urp.segment_id
                           INNER JOIN loop_sections sec ON sec.id = s.section_id
                           INNER JOIN loop_routes r ON r.id = sec.route_id
                          WHERE r.short_code LIKE :prefix",
                        {
                            prefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" }
                        },
                        { datasource = "fpw" }
                    );
                    queryExecute(
                        "DELETE s
                           FROM loop_segments s
                           INNER JOIN loop_sections sec ON sec.id = s.section_id
                           INNER JOIN loop_routes r ON r.id = sec.route_id
                          WHERE r.short_code LIKE :prefix",
                        {
                            prefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" }
                        },
                        { datasource = "fpw" }
                    );
                    queryExecute(
                        "DELETE sec
                           FROM loop_sections sec
                           INNER JOIN loop_routes r ON r.id = sec.route_id
                          WHERE r.short_code LIKE :prefix",
                        {
                            prefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" }
                        },
                        { datasource = "fpw" }
                    );
                    queryExecute(
                        "DELETE FROM loop_routes
                          WHERE short_code LIKE :prefix",
                        {
                            prefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" }
                        },
                        { datasource = "fpw" }
                    );
                    queryExecute(
                        "DELETE FROM route_instances
                          WHERE user_id = :userId
                            AND generated_route_code LIKE :prefix",
                        {
                            userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" },
                            prefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" }
                        },
                        { datasource = "fpw" }
                    );
                }
                message = "Force deleted " & forceRouteCount & " route(s) and " & forceInstanceCount & " route instance(s) for user " & targetUserId & ". Snapshot: /fpw/tmp/" & snapshotFile;
                if (snapshotFloatplansQ.recordCount GT 0) {
                    message &= " Unlinked " & snapshotFloatplansQ.recordCount & " float plan(s) from deleted route instances.";
                }
                messageType = "success";
            } else {
                message = "No routes or route instances found for user " & targetUserId & ". Empty snapshot created: /fpw/tmp/" & snapshotFile;
                messageType = "info";
            }
        }
    }

    summaryQ = queryExecute(
        "SELECT
            (SELECT COUNT(*) FROM loop_routes WHERE short_code LIKE :prefix) AS totalRoutes,
            (SELECT COUNT(*) FROM route_instances WHERE user_id = :userId AND generated_route_code LIKE :prefix) AS totalInstances,
            (SELECT COUNT(*)
               FROM route_instances ri
              WHERE ri.user_id = :userId
                AND ri.generated_route_code LIKE :prefix
                AND NOT EXISTS (
                    SELECT 1 FROM loop_routes r WHERE r.short_code = ri.generated_route_code
                )) AS orphanInstances",
        {
            userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" },
            prefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = "fpw" }
    );

    routes = queryExecute(
        "SELECT
            r.id AS routeId,
            COALESCE(NULLIF(TRIM(r.name), ''), '[unnamed]') AS routeName,
            COALESCE(NULLIF(TRIM(r.short_code), ''), '') AS routeCode,
            COUNT(DISTINCT sec.id) AS sectionCount,
            COUNT(seg.id) AS segmentCount,
            COALESCE(SUM(seg.dist_nm), 0) AS totalNm,
            COALESCE(SUM(seg.lock_count), 0) AS totalLocks,
            MAX(CASE WHEN ri.id IS NULL THEN 0 ELSE 1 END) AS hasInstance
           FROM loop_routes r
           LEFT JOIN loop_sections sec ON sec.route_id = r.id
           LEFT JOIN loop_segments seg ON seg.section_id = sec.id
           LEFT JOIN route_instances ri ON ri.generated_route_code = r.short_code AND ri.user_id = :userId
          WHERE r.short_code LIKE :prefix
          GROUP BY r.id, r.name, r.short_code
          ORDER BY r.id DESC",
        {
            userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" },
            prefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = "fpw" }
    );

    if (summaryQ.recordCount GT 0) {
        summary.totalRoutes = val(summaryQ.totalRoutes[1]);
        summary.totalInstances = val(summaryQ.totalInstances[1]);
        summary.orphanInstances = val(summaryQ.orphanInstances[1]);
    }
}
</cfscript>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Admin Route Cleanup</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 24px; background: #f7f7f7; color: #111; }
    .wrap { max-width: 1100px; margin: 0 auto; background: #fff; border: 1px solid #ddd; border-radius: 8px; padding: 20px; }
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
    <nav class="admin-nav" aria-label="Admin Tools">
      <a href="/fpw/admin/floatplan-cleanup.cfm">FloatPlan Cleanup</a>
      <a href="/fpw/admin/route-cleanup.cfm" class="active">Route Cleanup</a>
      <a href="/fpw/admin/fuel-calculator.cfm">Fuel Calculator</a>
    </nav>
    <h1>Admin Route Cleanup</h1>
    <p class="hint">Dev-only utility for deleting user-generated routes by user id.</p>
    <div class="msg info">
      <strong>Instructions</strong>
      <ol>
        <li>Enter a numeric user id and click <strong>Preview</strong>.</li>
        <li><strong>Delete All Route Artifacts</strong> removes user routes, route instances, and unlinks related float plans.</li>
        <li><strong>Force Delete All Route Artifacts</strong> does the same delete flow, but requires explicit typed confirmation.</li>
        <li>Delete actions always write a rollback snapshot JSON file under <code>/fpw/tmp/</code> before deleting.</li>
      </ol>
    </div>

    <form method="post" action="/fpw/admin/route-cleanup.cfm">
      <div class="row">
        <label for="targetUserId"><strong>User ID</strong></label>
        <input id="targetUserId" name="targetUserId" type="text" value="<cfoutput>#encodeForHtmlAttribute(targetUserIdRaw)#</cfoutput>" placeholder="e.g. 187">
        <button type="submit" name="actionType" value="preview">Preview</button>
        <button type="submit" name="actionType" value="delete" class="danger" onclick="return confirm('Delete all route artifacts (routes, route instances, and links) for this user?');">Delete All Route Artifacts</button>
      </div>
      <div class="row" style="margin-top:10px;">
        <label for="forceConfirm"><strong>Force Confirm</strong></label>
        <input id="forceConfirm" name="forceConfirm" type="text" value="<cfoutput>#encodeForHtmlAttribute(forceConfirmRaw)#</cfoutput>" placeholder="FORCE DELETE ROUTES 187" style="width: 320px;">
        <button type="submit" name="actionType" value="forcedelete" class="danger" onclick="return confirm('Force delete will remove route artifacts and route instances for this user. Continue?');">Force Delete All Route Artifacts</button>
      </div>
    </form>

    <cfif len(message)>
      <div class="msg <cfoutput>#messageType#</cfoutput>"><cfoutput>#encodeForHtml(message)#</cfoutput></div>
    </cfif>

    <cfif hasValidUserId AND listFindNoCase("preview,delete,forcedelete", actionType)>
      <div class="stats">
        <div class="stat"><strong>User:</strong> <cfoutput>#targetUserId#</cfoutput></div>
        <div class="stat"><strong>User Routes:</strong> <cfoutput>#summary.totalRoutes#</cfoutput></div>
        <div class="stat"><strong>Route Instances:</strong> <cfoutput>#summary.totalInstances#</cfoutput></div>
        <div class="stat"><strong>Orphan Instances:</strong> <cfoutput>#summary.orphanInstances#</cfoutput></div>
      </div>

      <table>
        <thead>
          <tr>
            <th>Route ID</th>
            <th>Name</th>
            <th>Route Code</th>
            <th>Sections</th>
            <th>Segments</th>
            <th>Total NM</th>
            <th>Total Locks</th>
            <th>Linked Instance</th>
          </tr>
        </thead>
        <tbody>
          <cfif routes.recordCount EQ 0>
            <tr><td colspan="8">No USER_ROUTE rows found for this user.</td></tr>
          <cfelse>
            <cfoutput query="routes">
              <tr>
                <td>#routeId#</td>
                <td>#encodeForHtml(routeName)#</td>
                <td>#encodeForHtml(routeCode)#</td>
                <td>#sectionCount#</td>
                <td>#segmentCount#</td>
                <td>#numberFormat(totalNm, "999,999,990.0")#</td>
                <td>#totalLocks#</td>
                <td>#iif(hasInstance EQ 1, de("YES"), de("NO"))#</td>
              </tr>
            </cfoutput>
          </cfif>
        </tbody>
      </table>
    </cfif>
  </div>
</body>
</html>
