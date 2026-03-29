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
legOverrideTableExists = false;
userRouteTablesExist = false;
selectedGeneratedRouteIds = [];
selectedCustomRouteIds = [];

summary = {
    totalRoutes = 0,
    totalInstances = 0,
    orphanInstances = 0,
    totalOverrides = 0,
    totalCustomRoutes = 0,
    totalCustomLegs = 0,
    totalCustomOverrides = 0
};
routes = queryNew("routeId,routeName,routeCode,sectionCount,segmentCount,totalNm,totalLocks,hasInstance");
customRoutes = queryNew("routeId,routeName,isActive,legCount,overrideCount,updatedAt");

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

function parsePositiveIntegerList(any rawValue="") {
    var out = [];
    var seen = {};
    var parts = [];
    var item = "";
    var itemVal = 0;

    if (isArray(arguments.rawValue)) {
        parts = arguments.rawValue;
    } else if (len(trim(toString(arguments.rawValue)))) {
        parts = listToArray(toString(arguments.rawValue));
    }

    for (item in parts) {
        item = trim(toString(item));
        if (!len(item) OR !isNumeric(item)) {
            continue;
        }
        itemVal = val(item);
        if (itemVal LTE 0 OR structKeyExists(seen, toString(itemVal))) {
            continue;
        }
        seen[toString(itemVal)] = true;
        arrayAppend(out, itemVal);
    }
    return out;
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
if (structKeyExists(form, "selectedGeneratedRouteIds")) {
    selectedGeneratedRouteIds = parsePositiveIntegerList(form.selectedGeneratedRouteIds);
}
if (structKeyExists(form, "selectedCustomRouteIds")) {
    selectedCustomRouteIds = parsePositiveIntegerList(form.selectedCustomRouteIds);
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
    legOverrideTableQ = queryExecute(
        "SELECT COUNT(*) AS tableCount
           FROM information_schema.tables
          WHERE table_schema = DATABASE()
            AND table_name = 'route_leg_user_overrides'",
        {},
        { datasource = "fpw" }
    );
    legOverrideTableExists = (legOverrideTableQ.recordCount GT 0 AND val(legOverrideTableQ.tableCount[1]) GT 0);
    userRouteTablesQ = queryExecute(
        "SELECT COUNT(*) AS tableCount
           FROM information_schema.tables
          WHERE table_schema = DATABASE()
            AND table_name IN ('user_routes', 'user_route_legs')",
        {},
        { datasource = "fpw" }
    );
    userRouteTablesExist = (userRouteTablesQ.recordCount GT 0 AND val(userRouteTablesQ.tableCount[1]) GTE 2);

    if (actionType EQ "delete" OR actionType EQ "forcedelete") {
        forceExpected = "FORCE DELETE ROUTES " & targetUserId;
        if (actionType EQ "forcedelete" AND forceConfirmRaw NEQ forceExpected) {
            message = "Force delete blocked. Type exactly: " & forceExpected;
            messageType = "error";
        } else if (!arrayLen(selectedGeneratedRouteIds) AND !arrayLen(selectedCustomRouteIds)) {
            message = "Select at least one generated route or custom route to delete.";
            messageType = "error";
        } else {
            selectedRoutesQ = queryNew("");
            if (arrayLen(selectedGeneratedRouteIds)) {
                selectedRoutesQ = queryExecute(
                    "SELECT id, short_code
                       FROM loop_routes
                      WHERE short_code LIKE :prefix
                        AND id IN (:routeIds)",
                    {
                        routeIds = { value = arrayToList(selectedGeneratedRouteIds), cfsqltype = "cf_sql_integer", list = true },
                        prefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" }
                    },
                    { datasource = "fpw" }
                );
            }
            selectedGeneratedRouteIds = [];
            selectedGeneratedRouteCodes = [];
            for (i = 1; i LTE selectedRoutesQ.recordCount; i++) {
                arrayAppend(selectedGeneratedRouteIds, val(selectedRoutesQ.id[i]));
                arrayAppend(selectedGeneratedRouteCodes, toString(selectedRoutesQ.short_code[i]));
            }
            selectedCustomRoutesQ = queryNew("");
            if (userRouteTablesExist AND arrayLen(selectedCustomRouteIds)) {
                selectedCustomRoutesQ = queryExecute(
                    "SELECT id
                       FROM user_routes
                      WHERE user_id = :userId
                        AND id IN (:routeIds)",
                    {
                        userId = { value = targetUserId, cfsqltype = "cf_sql_integer" },
                        routeIds = { value = arrayToList(selectedCustomRouteIds), cfsqltype = "cf_sql_integer", list = true }
                    },
                    { datasource = "fpw" }
                );
                selectedCustomRouteIds = [];
                for (i = 1; i LTE selectedCustomRoutesQ.recordCount; i++) {
                    arrayAppend(selectedCustomRouteIds, val(selectedCustomRoutesQ.id[i]));
                }
            } else {
                selectedCustomRouteIds = [];
            }
            if (!arrayLen(selectedGeneratedRouteIds) AND !arrayLen(selectedCustomRouteIds)) {
                message = "No checked routes were found for this user.";
                messageType = "error";
            } else {
            forceLegOverrideCount = 0;
            forceCustomRouteCount = 0;
            forceCustomLegCount = 0;
            forceCustomOverrideCount = 0;
            snapshotRoutesQ = queryNew("");
            snapshotSectionsQ = queryNew("");
            snapshotSegmentsQ = queryNew("");
            snapshotProgressQ = queryNew("");
            snapshotInstancesQ = queryNew("");
            snapshotFloatplansQ = queryNew("");
            snapshotLegOverridesQ = queryNew("");
            snapshotCustomRoutesQ = queryNew("");
            snapshotCustomLegsQ = queryNew("");
            snapshotCustomOverridesQ = queryNew("");
            if (arrayLen(selectedGeneratedRouteIds)) {
                snapshotRoutesQ = queryExecute(
                    "SELECT *
                       FROM loop_routes
                      WHERE short_code LIKE :prefix
                        AND id IN (:routeIds)
                      ORDER BY id",
                    {
                        prefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" },
                        routeIds = { value = arrayToList(selectedGeneratedRouteIds), cfsqltype = "cf_sql_integer", list = true }
                    },
                    { datasource = "fpw" }
                );
                snapshotSectionsQ = queryExecute(
                    "SELECT sec.*
                       FROM loop_sections sec
                       INNER JOIN loop_routes r ON r.id = sec.route_id
                      WHERE r.id IN (:routeIds)
                      ORDER BY sec.route_id, sec.order_index, sec.id",
                    {
                        routeIds = { value = arrayToList(selectedGeneratedRouteIds), cfsqltype = "cf_sql_integer", list = true }
                    },
                    { datasource = "fpw" }
                );
                snapshotSegmentsQ = queryExecute(
                    "SELECT s.*
                       FROM loop_segments s
                       INNER JOIN loop_sections sec ON sec.id = s.section_id
                      WHERE sec.route_id IN (:routeIds)
                      ORDER BY sec.route_id, sec.order_index, s.order_index, s.id",
                    {
                        routeIds = { value = arrayToList(selectedGeneratedRouteIds), cfsqltype = "cf_sql_integer", list = true }
                    },
                    { datasource = "fpw" }
                );
                snapshotProgressQ = queryExecute(
                    "SELECT urp.*
                       FROM user_route_progress urp
                       INNER JOIN loop_segments s ON s.id = urp.segment_id
                       INNER JOIN loop_sections sec ON sec.id = s.section_id
                      WHERE sec.route_id IN (:routeIds)
                      ORDER BY urp.user_id, urp.segment_id",
                    {
                        routeIds = { value = arrayToList(selectedGeneratedRouteIds), cfsqltype = "cf_sql_integer", list = true }
                    },
                    { datasource = "fpw" }
                );
                snapshotInstancesQ = queryExecute(
                    "SELECT *
                       FROM route_instances
                      WHERE user_id = :userId
                        AND generated_route_code IN (:routeCodes)
                      ORDER BY id",
                    {
                        userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" },
                        routeCodes = { value = arrayToList(selectedGeneratedRouteCodes), cfsqltype = "cf_sql_varchar", list = true }
                    },
                    { datasource = "fpw" }
                );
                snapshotFloatplansQ = queryExecute(
                    "SELECT fp.floatplanId, fp.userId, fp.floatPlanName, fp.status, fp.route_instance_id, fp.route_day_number
                       FROM floatplans fp
                       INNER JOIN route_instances ri ON ri.id = fp.route_instance_id
                      WHERE ri.user_id = :userId
                        AND ri.generated_route_code IN (:routeCodes)
                      ORDER BY fp.floatplanId",
                    {
                        userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" },
                        routeCodes = { value = arrayToList(selectedGeneratedRouteCodes), cfsqltype = "cf_sql_varchar", list = true }
                    },
                    { datasource = "fpw" }
                );
                if (legOverrideTableExists) {
                    snapshotLegOverridesQ = queryExecute(
                        "SELECT *
                           FROM route_leg_user_overrides rluo
                          WHERE rluo.user_id = :userId
                            AND (
                                rluo.route_id IN (:routeIds)
                                OR rluo.segment_id IN (
                                    SELECT s.id
                                      FROM loop_segments s
                                      INNER JOIN loop_sections sec ON sec.id = s.section_id
                                     WHERE sec.route_id IN (:routeIds)
                                )
                            )
                          ORDER BY rluo.id",
                        {
                            userId = { value = targetUserId, cfsqltype = "cf_sql_integer" },
                            routeIds = { value = arrayToList(selectedGeneratedRouteIds), cfsqltype = "cf_sql_integer", list = true }
                        },
                        { datasource = "fpw" }
                    );
                }
            }
            if (userRouteTablesExist AND arrayLen(selectedCustomRouteIds)) {
                snapshotCustomRoutesQ = queryExecute(
                    "SELECT *
                       FROM user_routes
                      WHERE user_id = :userId
                        AND id IN (:routeIds)
                      ORDER BY id",
                    {
                        userId = { value = targetUserId, cfsqltype = "cf_sql_integer" },
                        routeIds = { value = arrayToList(selectedCustomRouteIds), cfsqltype = "cf_sql_integer", list = true }
                    },
                    { datasource = "fpw" }
                );
                snapshotCustomLegsQ = queryExecute(
                    "SELECT url.*
                       FROM user_route_legs url
                       INNER JOIN user_routes ur ON ur.id = url.user_route_id
                      WHERE ur.user_id = :userId
                        AND ur.id IN (:routeIds)
                      ORDER BY url.user_route_id, url.order_index, url.id",
                    {
                        userId = { value = targetUserId, cfsqltype = "cf_sql_integer" },
                        routeIds = { value = arrayToList(selectedCustomRouteIds), cfsqltype = "cf_sql_integer", list = true }
                    },
                    { datasource = "fpw" }
                );
                if (legOverrideTableExists) {
                    snapshotCustomOverridesQ = queryExecute(
                        "SELECT rluo.*
                           FROM route_leg_user_overrides rluo
                           INNER JOIN user_route_legs url
                                   ON url.id = rluo.route_leg_id
                                  AND url.user_route_id = rluo.route_id
                           INNER JOIN user_routes ur ON ur.id = url.user_route_id
                          WHERE rluo.user_id = :userId
                            AND ur.user_id = :userId
                            AND ur.id IN (:routeIds)
                          ORDER BY rluo.id",
                        {
                            userId = { value = targetUserId, cfsqltype = "cf_sql_integer" },
                            routeIds = { value = arrayToList(selectedCustomRouteIds), cfsqltype = "cf_sql_integer", list = true }
                        },
                        { datasource = "fpw" }
                    );
                }
            }
            forceRouteCount = snapshotRoutesQ.recordCount;
            forceInstanceCount = snapshotInstancesQ.recordCount;
            forceLegOverrideCount = snapshotLegOverridesQ.recordCount;
            forceCustomRouteCount = snapshotCustomRoutesQ.recordCount;
            forceCustomLegCount = snapshotCustomLegsQ.recordCount;
            forceCustomOverrideCount = snapshotCustomOverridesQ.recordCount;

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
                totalRouteLegOverrides = forceLegOverrideCount,
                totalCustomRoutes = forceCustomRouteCount,
                totalCustomRouteLegs = forceCustomLegCount,
                totalCustomRouteOverrides = forceCustomOverrideCount,
                loop_routes = queryToStructArray(snapshotRoutesQ),
                loop_sections = queryToStructArray(snapshotSectionsQ),
                loop_segments = queryToStructArray(snapshotSegmentsQ),
                user_route_progress = queryToStructArray(snapshotProgressQ),
                route_instances = queryToStructArray(snapshotInstancesQ),
                route_leg_user_overrides = queryToStructArray(snapshotLegOverridesQ),
                linked_floatplans = queryToStructArray(snapshotFloatplansQ),
                user_routes = queryToStructArray(snapshotCustomRoutesQ),
                user_route_legs = queryToStructArray(snapshotCustomLegsQ),
                user_route_overrides = queryToStructArray(snapshotCustomOverridesQ)
            };
            fileWrite(snapshotPath, serializeJSON(snapshotData));

            if (
                forceRouteCount GT 0
                OR forceInstanceCount GT 0
                OR forceLegOverrideCount GT 0
                OR forceCustomRouteCount GT 0
                OR forceCustomLegCount GT 0
                OR forceCustomOverrideCount GT 0
            ) {
                transaction {
                    if (arrayLen(selectedGeneratedRouteIds)) {
                        queryExecute(
                            "UPDATE floatplans fp
                               INNER JOIN route_instances ri ON ri.id = fp.route_instance_id
                               SET fp.route_instance_id = NULL,
                                   fp.route_day_number = NULL
                             WHERE ri.user_id = :userId
                               AND ri.generated_route_code IN (:routeCodes)",
                            {
                                userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" },
                                routeCodes = { value = arrayToList(selectedGeneratedRouteCodes), cfsqltype = "cf_sql_varchar", list = true }
                            },
                            { datasource = "fpw" }
                        );
                        if (legOverrideTableExists) {
                            queryExecute(
                                "DELETE rluo
                                   FROM route_leg_user_overrides rluo
                                  WHERE rluo.user_id = :userId
                                    AND (
                                        rluo.route_id IN (:routeIds)
                                        OR rluo.segment_id IN (
                                            SELECT s.id
                                              FROM loop_segments s
                                              INNER JOIN loop_sections sec ON sec.id = s.section_id
                                             WHERE sec.route_id IN (:routeIds)
                                        )
                                    )",
                                {
                                    userId = { value = targetUserId, cfsqltype = "cf_sql_integer" },
                                    routeIds = { value = arrayToList(selectedGeneratedRouteIds), cfsqltype = "cf_sql_integer", list = true }
                                },
                                { datasource = "fpw" }
                            );
                        }
                    }
                    if (legOverrideTableExists AND userRouteTablesExist AND arrayLen(selectedCustomRouteIds)) {
                        queryExecute(
                            "DELETE rluo
                               FROM route_leg_user_overrides rluo
                               INNER JOIN user_route_legs url
                                       ON url.id = rluo.route_leg_id
                                      AND url.user_route_id = rluo.route_id
                               INNER JOIN user_routes ur ON ur.id = url.user_route_id
                              WHERE rluo.user_id = :userId
                                AND ur.user_id = :userId
                                AND ur.id IN (:routeIds)",
                            {
                                userId = { value = targetUserId, cfsqltype = "cf_sql_integer" },
                                routeIds = { value = arrayToList(selectedCustomRouteIds), cfsqltype = "cf_sql_integer", list = true }
                            },
                            { datasource = "fpw" }
                        );
                    }
                    if (arrayLen(selectedGeneratedRouteIds)) {
                        queryExecute(
                            "DELETE urp
                               FROM user_route_progress urp
                               INNER JOIN loop_segments s ON s.id = urp.segment_id
                               INNER JOIN loop_sections sec ON sec.id = s.section_id
                              WHERE sec.route_id IN (:routeIds)",
                            {
                                routeIds = { value = arrayToList(selectedGeneratedRouteIds), cfsqltype = "cf_sql_integer", list = true }
                            },
                            { datasource = "fpw" }
                        );
                        queryExecute(
                            "DELETE s
                               FROM loop_segments s
                               INNER JOIN loop_sections sec ON sec.id = s.section_id
                              WHERE sec.route_id IN (:routeIds)",
                            {
                                routeIds = { value = arrayToList(selectedGeneratedRouteIds), cfsqltype = "cf_sql_integer", list = true }
                            },
                            { datasource = "fpw" }
                        );
                        queryExecute(
                            "DELETE FROM loop_sections
                              WHERE route_id IN (:routeIds)",
                            {
                                routeIds = { value = arrayToList(selectedGeneratedRouteIds), cfsqltype = "cf_sql_integer", list = true }
                            },
                            { datasource = "fpw" }
                        );
                        queryExecute(
                            "DELETE FROM loop_routes
                              WHERE id IN (:routeIds)",
                            {
                                routeIds = { value = arrayToList(selectedGeneratedRouteIds), cfsqltype = "cf_sql_integer", list = true }
                            },
                            { datasource = "fpw" }
                        );
                        queryExecute(
                            "DELETE FROM route_instances
                              WHERE user_id = :userId
                                AND generated_route_code IN (:routeCodes)",
                            {
                                userId = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" },
                                routeCodes = { value = arrayToList(selectedGeneratedRouteCodes), cfsqltype = "cf_sql_varchar", list = true }
                            },
                            { datasource = "fpw" }
                        );
                    }
                    if (userRouteTablesExist AND arrayLen(selectedCustomRouteIds)) {
                        queryExecute(
                            "DELETE url
                               FROM user_route_legs url
                               INNER JOIN user_routes ur ON ur.id = url.user_route_id
                              WHERE ur.user_id = :userId
                                AND ur.id IN (:routeIds)",
                            {
                                userId = { value = targetUserId, cfsqltype = "cf_sql_integer" },
                                routeIds = { value = arrayToList(selectedCustomRouteIds), cfsqltype = "cf_sql_integer", list = true }
                            },
                            { datasource = "fpw" }
                        );
                        queryExecute(
                            "DELETE FROM user_routes
                              WHERE user_id = :userId
                                AND id IN (:routeIds)",
                            {
                                userId = { value = targetUserId, cfsqltype = "cf_sql_integer" },
                                routeIds = { value = arrayToList(selectedCustomRouteIds), cfsqltype = "cf_sql_integer", list = true }
                            },
                            { datasource = "fpw" }
                        );
                    }
                }
                message = "Force deleted "
                    & forceRouteCount & " generated route(s), "
                    & forceInstanceCount & " route instance(s), "
                    & forceLegOverrideCount & " generated route override record(s), "
                    & forceCustomRouteCount & " custom route(s), "
                    & forceCustomLegCount & " custom route leg(s), and "
                    & forceCustomOverrideCount & " custom route override record(s) for user " & targetUserId
                    & ". Snapshot: /fpw/tmp/" & snapshotFile;
                if (!legOverrideTableExists) {
                    message &= " Override table not found; skipped override cleanup.";
                }
                if (!userRouteTablesExist) {
                    message &= " Custom route tables not found; skipped custom route cleanup.";
                }
                if (snapshotFloatplansQ.recordCount GT 0) {
                    message &= " Unlinked " & snapshotFloatplansQ.recordCount & " float plan(s) from deleted route instances.";
                }
                messageType = "success";
            } else {
                message = "No generated routes, route instances, generated overrides, custom routes, custom route legs, or custom route overrides found for user " & targetUserId & ". Empty snapshot created: /fpw/tmp/" & snapshotFile;
                messageType = "info";
            }
            }
        }
    }

    summarySql = "
        SELECT
            (SELECT COUNT(*) FROM loop_routes WHERE short_code LIKE :prefix) AS totalRoutes,
            (SELECT COUNT(*) FROM route_instances WHERE user_id = :userIdText AND generated_route_code LIKE :prefix) AS totalInstances,
            (SELECT COUNT(*)
               FROM route_instances ri
              WHERE ri.user_id = :userIdText
                AND ri.generated_route_code LIKE :prefix
                AND NOT EXISTS (
                    SELECT 1 FROM loop_routes r WHERE r.short_code = ri.generated_route_code
                )) AS orphanInstances,";
    if (legOverrideTableExists) {
        summarySql &= "
            (SELECT COUNT(*)
               FROM route_leg_user_overrides rluo
              WHERE rluo.user_id = :userIdInt
                AND (
                    rluo.route_id IN (
                        SELECT r.id
                          FROM loop_routes r
                         WHERE r.short_code LIKE :prefix
                    )
                    OR rluo.segment_id IN (
                        SELECT s.id
                          FROM loop_segments s
                          INNER JOIN loop_sections sec ON sec.id = s.section_id
                          INNER JOIN loop_routes r2 ON r2.id = sec.route_id
                         WHERE r2.short_code LIKE :prefix
                    )
                )) AS totalOverrides,";
    } else {
        summarySql &= " 0 AS totalOverrides,";
    }
    if (userRouteTablesExist) {
        summarySql &= "
            (SELECT COUNT(*) FROM user_routes WHERE user_id = :userIdInt) AS totalCustomRoutes,
            (SELECT COUNT(*)
               FROM user_route_legs url
               INNER JOIN user_routes ur ON ur.id = url.user_route_id
              WHERE ur.user_id = :userIdInt) AS totalCustomLegs,";
        if (legOverrideTableExists) {
            summarySql &= "
            (SELECT COUNT(*)
               FROM route_leg_user_overrides rluo
               INNER JOIN user_route_legs url
                       ON url.id = rluo.route_leg_id
                      AND url.user_route_id = rluo.route_id
               INNER JOIN user_routes ur ON ur.id = url.user_route_id
              WHERE rluo.user_id = :userIdInt
                AND ur.user_id = :userIdInt) AS totalCustomOverrides";
        } else {
            summarySql &= " 0 AS totalCustomOverrides";
        }
    } else {
        summarySql &= " 0 AS totalCustomRoutes, 0 AS totalCustomLegs, 0 AS totalCustomOverrides";
    }
    summaryParams = {
        userIdText = { value = toString(targetUserId), cfsqltype = "cf_sql_varchar" },
        prefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" }
    };
    if (legOverrideTableExists) {
        summaryParams.userIdInt = { value = targetUserId, cfsqltype = "cf_sql_integer" };
    }
    summaryQ = queryExecute(
        summarySql,
        summaryParams,
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
    if (userRouteTablesExist) {
        customRoutes = queryExecute(
            "SELECT
                ur.id AS routeId,
                COALESCE(NULLIF(TRIM(ur.route_name), ''), '[unnamed]') AS routeName,
                ur.is_active AS isActive,
                COUNT(DISTINCT url.id) AS legCount,
                " & (legOverrideTableExists
                    ? "COUNT(DISTINCT rluo.id)"
                    : "0") & " AS overrideCount,
                ur.updated_at AS updatedAt
               FROM user_routes ur
               LEFT JOIN user_route_legs url ON url.user_route_id = ur.id"
               & (legOverrideTableExists
                    ? "
               LEFT JOIN route_leg_user_overrides rluo
                      ON rluo.user_id = :userIdInt
                     AND rluo.route_id = ur.id
                     AND rluo.route_leg_id = url.id"
                    : "") &
              " WHERE ur.user_id = :userIdInt
              GROUP BY ur.id, ur.route_name, ur.is_active, ur.updated_at
              ORDER BY ur.updated_at DESC, ur.id DESC",
            {
                userIdInt = { value = targetUserId, cfsqltype = "cf_sql_integer" }
            },
            { datasource = "fpw" }
        );
    }

    if (summaryQ.recordCount GT 0) {
        summary.totalRoutes = val(summaryQ.totalRoutes[1]);
        summary.totalInstances = val(summaryQ.totalInstances[1]);
        summary.orphanInstances = val(summaryQ.orphanInstances[1]);
        summary.totalOverrides = val(summaryQ.totalOverrides[1]);
        summary.totalCustomRoutes = val(summaryQ.totalCustomRoutes[1]);
        summary.totalCustomLegs = val(summaryQ.totalCustomLegs[1]);
        summary.totalCustomOverrides = val(summaryQ.totalCustomOverrides[1]);
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
    h2 { margin: 20px 0 8px; font-size: 18px; }
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
      <a href="/fpw/admin/waypoint-manager.cfm">Waypoint Manager</a>
      <a href="/fpw/admin/passenger-manager.cfm">Passenger Manager</a>
      <a href="/fpw/admin/vessel-manager.cfm">Vessel Manager</a>
      <a href="/fpw/admin/operator-manager.cfm">Operator Manager</a>
    </nav>
    <h1>Admin Route Cleanup</h1>
    <p class="hint">Dev-only utility for deleting generated routes and custom My Routes by user id.</p>
    <div class="msg info">
      <strong>Instructions</strong>
      <ol>
        <li>Enter a numeric user id and click <strong>Preview</strong>.</li>
        <li>Check the generated routes and custom routes you want to remove.</li>
        <li><strong>Delete Selected Route Artifacts</strong> removes only the checked generated routes, custom routes, route instances, route-specific overrides, custom route legs, and unlinks related float plans.</li>
        <li><strong>Force Delete Selected Route Artifacts</strong> does the same delete flow, but requires explicit typed confirmation.</li>
        <li>Delete actions always write a rollback snapshot JSON file under <code>/fpw/tmp/</code> before deleting.</li>
      </ol>
    </div>

    <form method="post" action="/fpw/admin/route-cleanup.cfm">
      <div class="row">
        <label for="targetUserId"><strong>User ID</strong></label>
        <input id="targetUserId" name="targetUserId" type="text" value="<cfoutput>#encodeForHtmlAttribute(targetUserIdRaw)#</cfoutput>" placeholder="e.g. 187">
        <button type="submit" name="actionType" value="preview">Preview</button>
        <button type="submit" name="actionType" value="delete" class="danger" onclick="return confirm('Delete only the checked generated routes, custom routes, route instances, route overrides, custom route legs, and related links for this user?');">Delete Selected Route Artifacts</button>
      </div>
      <div class="row" style="margin-top:10px;">
        <label for="forceConfirm"><strong>Force Confirm</strong></label>
        <input id="forceConfirm" name="forceConfirm" type="text" value="<cfoutput>#encodeForHtmlAttribute(forceConfirmRaw)#</cfoutput>" placeholder="FORCE DELETE ROUTES 187" style="width: 320px;">
        <button type="submit" name="actionType" value="forcedelete" class="danger" onclick="return confirm('Force delete will remove only the checked generated routes, custom routes, route instances, route overrides, custom route legs, and related links for this user. Continue?');">Force Delete Selected Route Artifacts</button>
      </div>

    <cfif len(message)>
      <div class="msg <cfoutput>#messageType#</cfoutput>"><cfoutput>#encodeForHtml(message)#</cfoutput></div>
    </cfif>

    <cfif hasValidUserId AND listFindNoCase("preview,delete,forcedelete", actionType)>
      <div class="stats">
        <div class="stat"><strong>User:</strong> <cfoutput>#targetUserId#</cfoutput></div>
        <div class="stat"><strong>Generated Routes:</strong> <cfoutput>#summary.totalRoutes#</cfoutput></div>
        <div class="stat"><strong>Route Instances:</strong> <cfoutput>#summary.totalInstances#</cfoutput></div>
        <div class="stat"><strong>Orphan Instances:</strong> <cfoutput>#summary.orphanInstances#</cfoutput></div>
        <div class="stat"><strong>Generated Overrides:</strong> <cfoutput>#summary.totalOverrides#</cfoutput></div>
        <div class="stat"><strong>Custom Routes:</strong> <cfoutput>#summary.totalCustomRoutes#</cfoutput></div>
        <div class="stat"><strong>Custom Route Legs:</strong> <cfoutput>#summary.totalCustomLegs#</cfoutput></div>
        <div class="stat"><strong>Custom Route Overrides:</strong> <cfoutput>#summary.totalCustomOverrides#</cfoutput></div>
      </div>

      <h2>Generated Routes</h2>
      <table>
        <thead>
          <tr>
            <th><label><input id="selectAllGeneratedRoutes" type="checkbox"> All</label></th>
            <th>User ID</th>
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
            <tr><td colspan="10">No USER_ROUTE rows found for this user.</td></tr>
          <cfelse>
            <cfoutput query="routes">
              <tr>
                <td><input type="checkbox" class="route-select route-select--generated" name="selectedGeneratedRouteIds" value="#routeId#"<cfif arrayFind(selectedGeneratedRouteIds, routeId) GT 0> checked</cfif>></td>
                <td>#targetUserId#</td>
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

      <h2>Custom Routes</h2>
      <table>
        <thead>
          <tr>
            <th><label><input id="selectAllCustomRoutes" type="checkbox"> All</label></th>
            <th>User ID</th>
            <th>Route ID</th>
            <th>Name</th>
            <th>Active</th>
            <th>Legs</th>
            <th>Route Overrides</th>
            <th>Updated At</th>
          </tr>
        </thead>
        <tbody>
          <cfif customRoutes.recordCount EQ 0>
            <tr><td colspan="8">No custom routes found for this user.</td></tr>
          <cfelse>
            <cfoutput query="customRoutes">
              <tr>
                <td><input type="checkbox" class="route-select route-select--custom" name="selectedCustomRouteIds" value="#routeId#"<cfif arrayFind(selectedCustomRouteIds, routeId) GT 0> checked</cfif>></td>
                <td>#targetUserId#</td>
                <td>#routeId#</td>
                <td>#encodeForHtml(routeName)#</td>
                <td>#iif(isActive EQ 1, de("YES"), de("NO"))#</td>
                <td>#legCount#</td>
                <td>#overrideCount#</td>
                <td>#encodeForHtml(toString(updatedAt))#</td>
              </tr>
            </cfoutput>
          </cfif>
        </tbody>
      </table>
    </cfif>
    </form>
  </div>
  <script>
    (function () {
      function syncMaster(master, items) {
        if (!master) return;
        if (!items.length) {
          master.checked = false;
          master.indeterminate = false;
          return;
        }
        var checkedCount = items.filter(function (item) { return item.checked; }).length;
        master.checked = checkedCount === items.length;
        master.indeterminate = checkedCount > 0 && checkedCount < items.length;
      }

      function bindSelectAll(masterId, selector) {
        var master = document.getElementById(masterId);
        var items = Array.prototype.slice.call(document.querySelectorAll(selector));
        if (!master) return;
        syncMaster(master, items);
        master.addEventListener("change", function () {
          items.forEach(function (item) {
            item.checked = master.checked;
          });
          syncMaster(master, items);
        });
        items.forEach(function (item) {
          item.addEventListener("change", function () {
            syncMaster(master, items);
          });
        });
      }

      bindSelectAll("selectAllGeneratedRoutes", ".route-select--generated");
      bindSelectAll("selectAllCustomRoutes", ".route-select--custom");
    })();
  </script>
</body>
</html>
