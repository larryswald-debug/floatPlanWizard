<cfcomponent output="false" hint="Admin waypoint management API.">

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfargument name="action" type="string" required="false" default="">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

        <cftry>
            <cfscript>
                var body = getBodyJson();
                var actionName = resolveAction(arguments.action, body);
                var userStruct = (structKeyExists(session, "user") AND isStruct(session.user)) ? session.user : {};
                var response = {};

                if (!structCount(userStruct)) {
                    response = buildResponse(
                        false,
                        false,
                        "Unauthorized",
                        {},
                        "Authentication is required."
                    );
                    writeOutput(serializeJSON(response));
                    return;
                }

                if (!isAdminUser(userStruct)) {
                    response = buildResponse(
                        false,
                        true,
                        "Forbidden",
                        {},
                        "Admin privileges are required."
                    );
                    writeOutput(serializeJSON(response));
                    return;
                }

                switch (actionName) {
                    case "list":
                        response = listWaypoints(body);
                        break;
                    case "get":
                        response = getWaypoint(body);
                        break;
                    case "save":
                        response = saveWaypoint(body);
                        break;
                    case "delete":
                        response = deleteWaypoint(body);
                        break;
                    case "batchdelete":
                        response = batchDeleteWaypoints(body);
                        break;
                    case "listusers":
                        response = listUsers(body);
                        break;
                    default:
                        response = buildResponse(
                            false,
                            true,
                            "Unknown action",
                            {},
                            "Valid actions: list, get, save, delete, batchDelete, listUsers."
                        );
                }

                writeOutput(serializeJSON(response));
            </cfscript>

            <cfcatch type="any">
                <cfset var isAuth = structKeyExists(session, "user") AND isStruct(session.user)>
                <cfoutput>#serializeJSON(buildResponse(false, isAuth, "Application error", {}, cfcatch.message, cfcatch.detail))#</cfoutput>
            </cfcatch>
        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

    <cffunction name="listWaypoints" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var pageLimit = toInt(readValue(arguments.body, "limit", readValue(url, "limit", 100)));
            var pageOffset = toInt(readValue(arguments.body, "offset", readValue(url, "offset", 0)));
            var userIdFilter = toInt(readValue(arguments.body, "userId", readValue(url, "userId", 0)));
            var emailFilter = lCase(trim(toString(readValue(arguments.body, "email", readValue(url, "email", "")))));
            var searchFilter = lCase(trim(toString(readValue(arguments.body, "search", readValue(url, "search", "")))));
            var hasCoordsFilter = lCase(trim(toString(readValue(arguments.body, "hasCoords", readValue(url, "hasCoords", "all")))));
            var whereParts = ["1=1"];
            var params = {};
            var sqlWhere = "";
            var listSql = "";
            var countSql = "";
            var qRows = queryNew("");
            var qCount = queryNew("");
            var countParams = {};
            var rows = [];
            var i = 0;
            var totalCount = 0;

            if (pageLimit LTE 0) pageLimit = 100;
            if (pageLimit GT 500) pageLimit = 500;
            if (pageOffset LT 0) pageOffset = 0;
            if (pageOffset GT 500000) pageOffset = 500000;

            if (userIdFilter GT 0) {
                arrayAppend(whereParts, "w.userId = :userIdFilter");
                params.userIdFilter = { value = userIdFilter, cfsqltype = "cf_sql_integer" };
            }

            if (len(emailFilter)) {
                arrayAppend(whereParts, "LOWER(COALESCE(u.email, '')) LIKE :emailLike");
                params.emailLike = { value = "%" & emailFilter & "%", cfsqltype = "cf_sql_varchar" };
            }

            if (len(searchFilter)) {
                arrayAppend(whereParts, "(LOWER(COALESCE(w.name, '')) LIKE :searchLike OR LOWER(COALESCE(w.notes, '')) LIKE :searchLike)");
                params.searchLike = { value = "%" & searchFilter & "%", cfsqltype = "cf_sql_varchar" };
            }

            if (hasCoordsFilter EQ "yes" OR hasCoordsFilter EQ "1" OR hasCoordsFilter EQ "true") {
                arrayAppend(whereParts, "TRIM(COALESCE(w.latitude, '')) <> '' AND TRIM(COALESCE(w.longitude, '')) <> ''");
                hasCoordsFilter = "yes";
            } else if (hasCoordsFilter EQ "no" OR hasCoordsFilter EQ "0" OR hasCoordsFilter EQ "false") {
                arrayAppend(whereParts, "(TRIM(COALESCE(w.latitude, '')) = '' OR TRIM(COALESCE(w.longitude, '')) = '')");
                hasCoordsFilter = "no";
            } else {
                hasCoordsFilter = "all";
            }

            sqlWhere = arrayToList(whereParts, " AND ");

            listSql = "
                SELECT
                    w.wpId,
                    w.userId,
                    w.name,
                    w.latitude,
                    w.longitude,
                    w.notes,
                    u.email,
                    u.fName,
                    u.lName,
                    COALESCE(usageAgg.usage_count, 0) AS usage_count
                FROM waypoints w
                LEFT JOIN users u
                    ON u.userId = w.userId
                LEFT JOIN (
                    SELECT waypointId, COUNT(*) AS usage_count
                    FROM floatplan_waypoints
                    GROUP BY waypointId
                ) usageAgg
                    ON usageAgg.waypointId = w.wpId
                WHERE #sqlWhere#
                ORDER BY w.wpId DESC
                LIMIT :pageLimit
                OFFSET :pageOffset";

            countSql = "
                SELECT COUNT(*) AS total_count
                FROM waypoints w
                LEFT JOIN users u
                    ON u.userId = w.userId
                WHERE #sqlWhere#";

            params.pageLimit = { value = pageLimit, cfsqltype = "cf_sql_integer" };
            params.pageOffset = { value = pageOffset, cfsqltype = "cf_sql_integer" };

            qRows = queryExecute(listSql, params, { datasource = getDatasource() });
            countParams = duplicate(params);
            structDelete(countParams, "pageLimit", false);
            structDelete(countParams, "pageOffset", false);
            qCount = queryExecute(countSql, countParams, { datasource = getDatasource() });

            totalCount = (qCount.recordCount GT 0) ? val(qCount.total_count[1]) : 0;

            for (i = 1; i LTE qRows.recordCount; i++) {
                arrayAppend(rows, normalizeWaypointRow(qRows, i));
            }

            return buildResponse(true, true, "OK", {
                "items" = rows,
                "total" = totalCount,
                "limit" = pageLimit,
                "offset" = pageOffset,
                "filters" = {
                    "userId" = userIdFilter,
                    "email" = emailFilter,
                    "search" = searchFilter,
                    "hasCoords" = hasCoordsFilter
                }
            });
        </cfscript>
    </cffunction>

    <cffunction name="getWaypoint" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var waypointId = toInt(readValue(arguments.body, "waypointId", readValue(arguments.body, "WAYPOINTID", readValue(url, "waypointId", 0))));
            var qRow = queryNew("");

            if (waypointId LTE 0) {
                return buildResponse(false, true, "Invalid waypoint", {}, "waypointId is required.");
            }

            qRow = loadWaypointQuery(waypointId);
            if (qRow.recordCount EQ 0) {
                return buildResponse(false, true, "Not found", {}, "Waypoint not found.");
            }

            return buildResponse(true, true, "OK", {
                "waypoint" = normalizeWaypointRow(qRow, 1)
            });
        </cfscript>
    </cffunction>

    <cffunction name="saveWaypoint" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var payload = {};
            var waypointId = 0;
            var userId = 0;
            var waypointName = "";
            var notesVal = "";
            var latitudeRaw = "";
            var longitudeRaw = "";
            var latitudeVal = "";
            var longitudeVal = "";
            var existing = queryNew("");
            var qSaved = queryNew("");
            var latValid = {};
            var lngValid = {};
            var qInsertId = queryNew("");

            if (structKeyExists(arguments.body, "waypoint") AND isStruct(arguments.body.waypoint)) {
                payload = arguments.body.waypoint;
            } else if (structKeyExists(arguments.body, "WAYPOINT") AND isStruct(arguments.body.WAYPOINT)) {
                payload = arguments.body.WAYPOINT;
            } else {
                payload = arguments.body;
            }

            waypointId = toInt(readValue(payload, "waypointId", readValue(payload, "WAYPOINTID", 0)));
            userId = toInt(readValue(payload, "userId", readValue(payload, "USERID", 0)));
            waypointName = trim(toString(readValue(payload, "name", readValue(payload, "WAYPOINTNAME", ""))));
            notesVal = trim(toString(readValue(payload, "notes", readValue(payload, "NOTES", ""))));
            latitudeRaw = trim(toString(readValue(payload, "latitude", readValue(payload, "LATITUDE", ""))));
            longitudeRaw = trim(toString(readValue(payload, "longitude", readValue(payload, "LONGITUDE", ""))));

            if (!len(waypointName)) {
                return buildResponse(false, true, "Validation failed", {}, "Waypoint name is required.");
            }
            if (len(waypointName) GT 255) {
                waypointName = left(waypointName, 255);
            }

            latValid = normalizeCoord(latitudeRaw, "lat");
            if (!latValid.ok) {
                return buildResponse(false, true, "Validation failed", {}, latValid.message);
            }
            lngValid = normalizeCoord(longitudeRaw, "lng");
            if (!lngValid.ok) {
                return buildResponse(false, true, "Validation failed", {}, lngValid.message);
            }
            latitudeVal = latValid.value;
            longitudeVal = lngValid.value;

            if (waypointId GT 0) {
                existing = queryExecute(
                    "SELECT wpId, userId
                     FROM waypoints
                     WHERE wpId = :waypointId
                     LIMIT 1",
                    {
                        waypointId = { value = waypointId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = getDatasource() }
                );
                if (existing.recordCount EQ 0) {
                    return buildResponse(false, true, "Not found", {}, "Waypoint not found.");
                }
                if (userId LTE 0) {
                    userId = val(existing.userId[1]);
                }
            } else {
                if (userId LTE 0) {
                    return buildResponse(false, true, "Validation failed", {}, "userId is required when creating a waypoint.");
                }
            }

            if (userId LTE 0) {
                return buildResponse(false, true, "Validation failed", {}, "userId must be a positive integer.");
            }

            if (waypointId GT 0) {
                queryExecute(
                    "UPDATE waypoints
                     SET userId = :userId,
                         name = :name,
                         latitude = :latitude,
                         longitude = :longitude,
                         notes = :notes
                     WHERE wpId = :waypointId",
                    {
                        userId = { value = userId, cfsqltype = "cf_sql_integer" },
                        name = { value = waypointName, cfsqltype = "cf_sql_varchar" },
                        latitude = { value = latitudeVal, cfsqltype = "cf_sql_varchar" },
                        longitude = { value = longitudeVal, cfsqltype = "cf_sql_varchar" },
                        notes = { value = notesVal, cfsqltype = "cf_sql_varchar" },
                        waypointId = { value = waypointId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = getDatasource() }
                );
            } else {
                queryExecute(
                    "INSERT INTO waypoints (userId, name, latitude, longitude, notes)
                     VALUES (:userId, :name, :latitude, :longitude, :notes)",
                    {
                        userId = { value = userId, cfsqltype = "cf_sql_integer" },
                        name = { value = waypointName, cfsqltype = "cf_sql_varchar" },
                        latitude = { value = latitudeVal, cfsqltype = "cf_sql_varchar" },
                        longitude = { value = longitudeVal, cfsqltype = "cf_sql_varchar" },
                        notes = { value = notesVal, cfsqltype = "cf_sql_varchar" }
                    },
                    { datasource = getDatasource() }
                );

                qInsertId = queryExecute(
                    "SELECT LAST_INSERT_ID() AS new_id",
                    {},
                    { datasource = getDatasource() }
                );
                if (qInsertId.recordCount GT 0 AND isNumeric(qInsertId.new_id[1])) {
                    waypointId = toInt(qInsertId.new_id[1]);
                }
                if (waypointId LTE 0) {
                    return buildResponse(false, true, "Insert failed", {}, "Waypoint created but id could not be resolved.");
                }
            }

            qSaved = loadWaypointQuery(waypointId);
            return buildResponse(true, true, "Waypoint saved", {
                "waypointId" = waypointId,
                "waypoint" = (qSaved.recordCount GT 0 ? normalizeWaypointRow(qSaved, 1) : {})
            });
        </cfscript>
    </cffunction>

    <cffunction name="deleteWaypoint" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var waypointId = toInt(readValue(arguments.body, "waypointId", readValue(arguments.body, "WAYPOINTID", readValue(url, "waypointId", 0))));
            var unlinkFloatplans = toBoolean(readValue(arguments.body, "unlinkFloatplans", readValue(url, "unlinkFloatplans", false)), false);
            var result = {};

            if (waypointId LTE 0) {
                return buildResponse(false, true, "Invalid waypoint", {}, "waypointId is required.");
            }

            result = deleteWaypointById(waypointId, unlinkFloatplans);
            if (!result.success) {
                return buildResponse(false, true, "Delete failed", result, result.message);
            }

            return buildResponse(true, true, "Waypoint deleted", result);
        </cfscript>
    </cffunction>

    <cffunction name="batchDeleteWaypoints" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var rawIds = readValue(arguments.body, "waypointIds", readValue(arguments.body, "ids", []));
            var unlinkFloatplans = toBoolean(readValue(arguments.body, "unlinkFloatplans", false), false);
            var ids = normalizeIdArray(rawIds);
            var item = 0;
            var perItem = [];
            var one = {};
            var deletedCount = 0;
            var failedCount = 0;
            var blockedCount = 0;
            var unlinkedCount = 0;
            var overallOk = false;

            if (!arrayLen(ids)) {
                return buildResponse(false, true, "Validation failed", {}, "waypointIds must be a non-empty array.");
            }

            for (item in ids) {
                one = deleteWaypointById(item, unlinkFloatplans);
                if (one.success) {
                    deletedCount++;
                    unlinkedCount += one.unlinkedCount;
                } else {
                    failedCount++;
                    if (one.errorCode EQ "IN_USE") {
                        blockedCount++;
                    }
                }
                arrayAppend(perItem, one);
            }

            overallOk = (failedCount EQ 0);

            return buildResponse(overallOk, true, (overallOk ? "Batch delete complete." : "Batch delete completed with errors."), {
                "requestedCount" = arrayLen(ids),
                "deletedCount" = deletedCount,
                "failedCount" = failedCount,
                "blockedCount" = blockedCount,
                "unlinkedCount" = unlinkedCount,
                "results" = perItem
            }, (overallOk ? "" : "One or more waypoints could not be deleted."));
        </cfscript>
    </cffunction>

    <cffunction name="listUsers" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var searchFilter = lCase(trim(toString(readValue(arguments.body, "search", readValue(url, "search", "")))));
            var limitVal = toInt(readValue(arguments.body, "limit", readValue(url, "limit", 100)));
            var sql = "";
            var params = {};
            var qUsers = queryNew("");
            var rows = [];
            var i = 0;

            if (limitVal LTE 0) limitVal = 100;
            if (limitVal GT 300) limitVal = 300;

            sql = "
                SELECT
                    u.userId,
                    u.email,
                    u.fName,
                    u.lName,
                    COUNT(w.wpId) AS waypoint_count
                FROM users u
                LEFT JOIN waypoints w
                    ON w.userId = u.userId
                WHERE 1=1";

            if (len(searchFilter)) {
                sql &= "
                    AND (
                        LOWER(COALESCE(u.email, '')) LIKE :searchLike
                        OR LOWER(CONCAT(COALESCE(u.fName, ''), ' ', COALESCE(u.lName, ''))) LIKE :searchLike
                        OR CAST(u.userId AS CHAR) LIKE :searchLike
                    )";
                params.searchLike = { value = "%" & searchFilter & "%", cfsqltype = "cf_sql_varchar" };
            }

            sql &= "
                GROUP BY u.userId, u.email, u.fName, u.lName
                ORDER BY waypoint_count DESC, u.userId DESC
                LIMIT :limitVal";
            params.limitVal = { value = limitVal, cfsqltype = "cf_sql_integer" };

            qUsers = queryExecute(sql, params, { datasource = getDatasource() });
            for (i = 1; i LTE qUsers.recordCount; i++) {
                arrayAppend(rows, {
                    "userId" = val(qUsers.userId[i]),
                    "email" = (isNull(qUsers.email[i]) ? "" : toString(qUsers.email[i])),
                    "firstName" = (isNull(qUsers.fName[i]) ? "" : toString(qUsers.fName[i])),
                    "lastName" = (isNull(qUsers.lName[i]) ? "" : toString(qUsers.lName[i])),
                    "waypointCount" = val(qUsers.waypoint_count[i])
                });
            }

            return buildResponse(true, true, "OK", {
                "users" = rows,
                "limit" = limitVal,
                "search" = searchFilter
            });
        </cfscript>
    </cffunction>

    <cffunction name="deleteWaypointById" access="private" returntype="struct" output="false">
        <cfargument name="waypointId" type="numeric" required="true">
        <cfargument name="unlinkFloatplans" type="boolean" required="true">
        <cfscript>
            var qRow = queryNew("");
            var qUsage = queryNew("");
            var usageCount = 0;
            var unlinkedCount = 0;
            var outcome = {
                "waypointId" = arguments.waypointId,
                "success" = false,
                "errorCode" = "",
                "message" = "",
                "unlinkedCount" = 0
            };

            if (arguments.waypointId LTE 0) {
                outcome.errorCode = "INVALID_ID";
                outcome.message = "waypointId is required.";
                return outcome;
            }

            qRow = queryExecute(
                "SELECT wpId
                 FROM waypoints
                 WHERE wpId = :waypointId
                 LIMIT 1",
                {
                    waypointId = { value = arguments.waypointId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = getDatasource() }
            );

            if (qRow.recordCount EQ 0) {
                outcome.errorCode = "NOT_FOUND";
                outcome.message = "Waypoint not found.";
                return outcome;
            }

            qUsage = queryExecute(
                "SELECT COUNT(*) AS usage_count
                 FROM floatplan_waypoints
                 WHERE waypointId = :waypointId",
                {
                    waypointId = { value = arguments.waypointId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = getDatasource() }
            );

            usageCount = (qUsage.recordCount GT 0 ? val(qUsage.usage_count[1]) : 0);

            if (usageCount GT 0 AND !arguments.unlinkFloatplans) {
                outcome.errorCode = "IN_USE";
                outcome.message = "Waypoint is referenced by " & usageCount & " float plan waypoint row(s).";
                return outcome;
            }

            transaction {
                if (usageCount GT 0 AND arguments.unlinkFloatplans) {
                    queryExecute(
                        "DELETE FROM floatplan_waypoints
                         WHERE waypointId = :waypointId",
                        {
                            waypointId = { value = arguments.waypointId, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = getDatasource() }
                    );
                    unlinkedCount = usageCount;
                }

                queryExecute(
                    "DELETE FROM waypoints
                     WHERE wpId = :waypointId",
                    {
                        waypointId = { value = arguments.waypointId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = getDatasource() }
                );
            }

            outcome.success = true;
            outcome.message = "Waypoint deleted.";
            outcome.unlinkedCount = unlinkedCount;
            return outcome;
        </cfscript>
    </cffunction>

    <cffunction name="loadWaypointQuery" access="private" returntype="query" output="false">
        <cfargument name="waypointId" type="numeric" required="true">
        <cfscript>
            return queryExecute(
                "SELECT
                    w.wpId,
                    w.userId,
                    w.name,
                    w.latitude,
                    w.longitude,
                    w.notes,
                    u.email,
                    u.fName,
                    u.lName,
                    COALESCE(usageAgg.usage_count, 0) AS usage_count
                 FROM waypoints w
                 LEFT JOIN users u
                    ON u.userId = w.userId
                 LEFT JOIN (
                    SELECT waypointId, COUNT(*) AS usage_count
                    FROM floatplan_waypoints
                    GROUP BY waypointId
                 ) usageAgg
                    ON usageAgg.waypointId = w.wpId
                 WHERE w.wpId = :waypointId
                 LIMIT 1",
                {
                    waypointId = { value = arguments.waypointId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = getDatasource() }
            );
        </cfscript>
    </cffunction>

    <cffunction name="normalizeWaypointRow" access="private" returntype="struct" output="false">
        <cfargument name="q" type="query" required="true">
        <cfargument name="idx" type="numeric" required="true">
        <cfscript>
            return {
                "WAYPOINTID" = val(arguments.q.wpId[arguments.idx]),
                "USERID" = val(arguments.q.userId[arguments.idx]),
                "WAYPOINTNAME" = (isNull(arguments.q.name[arguments.idx]) ? "" : toString(arguments.q.name[arguments.idx])),
                "LATITUDE" = (isNull(arguments.q.latitude[arguments.idx]) ? "" : toString(arguments.q.latitude[arguments.idx])),
                "LONGITUDE" = (isNull(arguments.q.longitude[arguments.idx]) ? "" : toString(arguments.q.longitude[arguments.idx])),
                "NOTES" = (isNull(arguments.q.notes[arguments.idx]) ? "" : toString(arguments.q.notes[arguments.idx])),
                "USER_EMAIL" = (isNull(arguments.q.email[arguments.idx]) ? "" : toString(arguments.q.email[arguments.idx])),
                "USER_FIRSTNAME" = (isNull(arguments.q.fName[arguments.idx]) ? "" : toString(arguments.q.fName[arguments.idx])),
                "USER_LASTNAME" = (isNull(arguments.q.lName[arguments.idx]) ? "" : toString(arguments.q.lName[arguments.idx])),
                "USAGE_COUNT" = (isNull(arguments.q.usage_count[arguments.idx]) ? 0 : val(arguments.q.usage_count[arguments.idx]))
            };
        </cfscript>
    </cffunction>

    <cffunction name="normalizeCoord" access="private" returntype="struct" output="false">
        <cfargument name="rawValue" type="string" required="true">
        <cfargument name="coordType" type="string" required="true">
        <cfscript>
            var txt = trim(arguments.rawValue);
            var valNum = 0;
            var minVal = (arguments.coordType EQ "lat" ? -90 : -180);
            var maxVal = (arguments.coordType EQ "lat" ? 90 : 180);
            var out = { "ok" = true, "message" = "", "value" = "" };

            if (!len(txt)) {
                return out;
            }

            if (!isNumeric(txt)) {
                out.ok = false;
                out.message = (arguments.coordType EQ "lat" ? "Latitude must be numeric." : "Longitude must be numeric.");
                return out;
            }

            valNum = val(txt);
            if (valNum LT minVal OR valNum GT maxVal) {
                out.ok = false;
                out.message = (arguments.coordType EQ "lat" ? "Latitude must be between -90 and 90." : "Longitude must be between -180 and 180.");
                return out;
            }

            out.value = toString(round(valNum * 1000000) / 1000000);
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeIdArray" access="private" returntype="array" output="false">
        <cfargument name="rawValue" type="any" required="true">
        <cfscript>
            var ids = [];
            var seen = {};
            var one = 0;
            var i = 0;
            var parts = [];

            if (isArray(arguments.rawValue)) {
                for (i = 1; i LTE arrayLen(arguments.rawValue); i++) {
                    one = toInt(arguments.rawValue[i]);
                    if (one LTE 0) continue;
                    if (!structKeyExists(seen, toString(one))) {
                        seen[toString(one)] = true;
                        arrayAppend(ids, one);
                    }
                }
                return ids;
            }

            if (isSimpleValue(arguments.rawValue)) {
                parts = listToArray(toString(arguments.rawValue), ",");
                for (i = 1; i LTE arrayLen(parts); i++) {
                    one = toInt(parts[i]);
                    if (one LTE 0) continue;
                    if (!structKeyExists(seen, toString(one))) {
                        seen[toString(one)] = true;
                        arrayAppend(ids, one);
                    }
                }
            }

            return ids;
        </cfscript>
    </cffunction>

    <cffunction name="buildResponse" access="private" returntype="struct" output="false">
        <cfargument name="success" type="boolean" required="true">
        <cfargument name="auth" type="boolean" required="true">
        <cfargument name="message" type="string" required="true">
        <cfargument name="data" type="struct" required="false" default="#structNew()#">
        <cfargument name="errorMessage" type="string" required="false" default="">
        <cfargument name="errorDetail" type="string" required="false" default="">
        <cfscript>
            return {
                "SUCCESS" = arguments.success,
                "AUTH" = arguments.auth,
                "MESSAGE" = arguments.message,
                "DATA" = arguments.data,
                "ERROR" = {
                    "MESSAGE" = arguments.errorMessage,
                    "DETAIL" = arguments.errorDetail
                }
            };
        </cfscript>
    </cffunction>

    <cffunction name="resolveAction" access="private" returntype="string" output="false">
        <cfargument name="actionArg" type="string" required="true">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var actionName = lCase(trim(arguments.actionArg));
            if (!len(actionName) AND structKeyExists(url, "action")) {
                actionName = lCase(trim(toString(url.action)));
            }
            if (!len(actionName) AND structKeyExists(arguments.body, "action")) {
                actionName = lCase(trim(toString(arguments.body.action)));
            }
            return actionName;
        </cfscript>
    </cffunction>

    <cffunction name="getBodyJson" access="private" returntype="struct" output="false">
        <cfscript>
            var body = {};
            var raw = "";
            var httpData = getHttpRequestData();

            if (!structKeyExists(httpData, "content")) {
                return body;
            }

            raw = toString(httpData.content);
            if (!len(trim(raw))) {
                return body;
            }

            try {
                body = deserializeJSON(raw, false);
                if (!isStruct(body)) {
                    body = {};
                }
            } catch (any ignored) {
                body = {};
            }
            return body;
        </cfscript>
    </cffunction>

    <cffunction name="readValue" access="private" returntype="any" output="false">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfargument name="defaultValue" type="any" required="false" default="">
        <cfscript>
            if (structKeyExists(arguments.source, arguments.key)) {
                return arguments.source[arguments.key];
            }
            return arguments.defaultValue;
        </cfscript>
    </cffunction>

    <cffunction name="toInt" access="private" returntype="numeric" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            var txt = trim(toString(arguments.value));
            if (!len(txt) OR !isNumeric(txt)) return 0;
            return int(val(txt));
        </cfscript>
    </cffunction>

    <cffunction name="toBoolean" access="private" returntype="boolean" output="false">
        <cfargument name="value" type="any" required="true">
        <cfargument name="defaultValue" type="boolean" required="false" default="false">
        <cfscript>
            var txt = lCase(trim(toString(arguments.value)));
            if (!len(txt)) return arguments.defaultValue;
            if (listFindNoCase("1,true,yes,y,on", txt)) return true;
            if (listFindNoCase("0,false,no,n,off", txt)) return false;
            if (isNumeric(txt)) return (val(txt) NEQ 0);
            return arguments.defaultValue;
        </cfscript>
    </cffunction>

    <cffunction name="isAdminUser" access="private" returntype="boolean" output="false">
        <cfargument name="userStruct" type="struct" required="true">
        <cfscript>
            var roleValue = "";
            var emailValue = "";
            var adminWhitelist = "admin@floatplanwizard.com,lswald@yahoo.com";

            if (structKeyExists(arguments.userStruct, "isAdmin") AND toBoolean(arguments.userStruct.isAdmin, false)) return true;
            if (structKeyExists(arguments.userStruct, "ISADMIN") AND toBoolean(arguments.userStruct.ISADMIN, false)) return true;
            if (structKeyExists(arguments.userStruct, "is_admin") AND toBoolean(arguments.userStruct.is_admin, false)) return true;

            if (structKeyExists(arguments.userStruct, "role")) {
                roleValue = lCase(trim(toString(arguments.userStruct.role)));
            } else if (structKeyExists(arguments.userStruct, "ROLE")) {
                roleValue = lCase(trim(toString(arguments.userStruct.ROLE)));
            }
            if (roleValue EQ "admin") return true;

            if (structKeyExists(arguments.userStruct, "email")) {
                emailValue = lCase(trim(toString(arguments.userStruct.email)));
            } else if (structKeyExists(arguments.userStruct, "EMAIL")) {
                emailValue = lCase(trim(toString(arguments.userStruct.EMAIL)));
            }
            if (len(emailValue) AND listFindNoCase(adminWhitelist, emailValue)) return true;

            return false;
        </cfscript>
    </cffunction>

    <cffunction name="getDatasource" access="private" returntype="string" output="false">
        <cfscript>
            if (structKeyExists(application, "dsn") AND len(trim(toString(application.dsn)))) {
                return toString(application.dsn);
            }
            return "fpw";
        </cfscript>
    </cffunction>

</cfcomponent>
