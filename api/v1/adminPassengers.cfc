<cfcomponent output="false" hint="Admin passenger management API.">

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
                        response = listPassengers(body);
                        break;
                    case "get":
                        response = getPassenger(body);
                        break;
                    case "save":
                        response = savePassenger(body);
                        break;
                    case "delete":
                        response = deletePassenger(body);
                        break;
                    case "batchdelete":
                        response = batchDeletePassengers(body);
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

    <cffunction name="listPassengers" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var pageLimit = toInt(readValue(arguments.body, "limit", readValue(url, "limit", 100)));
            var pageOffset = toInt(readValue(arguments.body, "offset", readValue(url, "offset", 0)));
            var userIdFilter = toInt(readValue(arguments.body, "userId", readValue(url, "userId", 0)));
            var emailFilter = lCase(trim(toString(readValue(arguments.body, "email", readValue(url, "email", "")))));
            var searchFilter = lCase(trim(toString(readValue(arguments.body, "search", readValue(url, "search", "")))));
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
                arrayAppend(whereParts, "p.userId = :userIdFilter");
                params.userIdFilter = { value = toString(userIdFilter), cfsqltype = "cf_sql_varchar" };
            }

            if (len(emailFilter)) {
                arrayAppend(whereParts, "LOWER(COALESCE(u.email, '')) LIKE :emailLike");
                params.emailLike = { value = "%" & emailFilter & "%", cfsqltype = "cf_sql_varchar" };
            }

            if (len(searchFilter)) {
                arrayAppend(whereParts, "(
                    LOWER(COALESCE(p.name, '')) LIKE :searchLike
                    OR LOWER(COALESCE(p.phone, '')) LIKE :searchLike
                    OR LOWER(COALESCE(p.age, '')) LIKE :searchLike
                    OR LOWER(COALESCE(p.gender, '')) LIKE :searchLike
                    OR LOWER(COALESCE(p.notes, '')) LIKE :searchLike
                    OR CAST(p.passId AS CHAR) LIKE :searchLike
                )");
                params.searchLike = { value = "%" & searchFilter & "%", cfsqltype = "cf_sql_varchar" };
            }

            sqlWhere = arrayToList(whereParts, " AND ");

            listSql = "
                SELECT
                    p.passId,
                    p.userId,
                    p.name,
                    p.phone,
                    p.age,
                    p.gender,
                    p.notes,
                    p.pfd,
                    u.email,
                    u.fName,
                    u.lName,
                    COALESCE(usageAgg.usage_count, 0) AS usage_count
                FROM passengers p
                LEFT JOIN users u
                    ON u.userId = p.userId
                LEFT JOIN (
                    SELECT passId, COUNT(*) AS usage_count
                    FROM floatplan_passengers
                    GROUP BY passId
                ) usageAgg
                    ON usageAgg.passId = p.passId
                WHERE #sqlWhere#
                ORDER BY p.passId DESC
                LIMIT :pageLimit
                OFFSET :pageOffset";

            countSql = "
                SELECT COUNT(*) AS total_count
                FROM passengers p
                LEFT JOIN users u
                    ON u.userId = p.userId
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
                arrayAppend(rows, normalizePassengerRow(qRows, i));
            }

            return buildResponse(true, true, "OK", {
                "items" = rows,
                "total" = totalCount,
                "limit" = pageLimit,
                "offset" = pageOffset,
                "filters" = {
                    "userId" = userIdFilter,
                    "email" = emailFilter,
                    "search" = searchFilter
                }
            });
        </cfscript>
    </cffunction>

    <cffunction name="getPassenger" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var passengerId = toInt(readValue(arguments.body, "passengerId", readValue(arguments.body, "PASSENGERID", readValue(url, "passengerId", 0))));
            var qRow = queryNew("");

            if (passengerId LTE 0) {
                return buildResponse(false, true, "Invalid passenger", {}, "passengerId is required.");
            }

            qRow = loadPassengerQuery(passengerId);
            if (qRow.recordCount EQ 0) {
                return buildResponse(false, true, "Not found", {}, "Passenger not found.");
            }

            return buildResponse(true, true, "OK", {
                "passenger" = normalizePassengerRow(qRow, 1)
            });
        </cfscript>
    </cffunction>

    <cffunction name="savePassenger" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var payload = {};
            var passengerId = 0;
            var userIdTxt = "";
            var passengerName = "";
            var phoneVal = "";
            var ageVal = "";
            var genderVal = "";
            var notesVal = "";
            var existing = queryNew("");
            var qSaved = queryNew("");
            var qInsertId = queryNew("");

            if (structKeyExists(arguments.body, "passenger") AND isStruct(arguments.body.passenger)) {
                payload = arguments.body.passenger;
            } else if (structKeyExists(arguments.body, "PASSENGER") AND isStruct(arguments.body.PASSENGER)) {
                payload = arguments.body.PASSENGER;
            } else {
                payload = arguments.body;
            }

            passengerId = toInt(readValue(payload, "passengerId", readValue(payload, "PASSENGERID", 0)));
            userIdTxt = trim(toString(readValue(payload, "userId", readValue(payload, "USERID", ""))));
            passengerName = trim(toString(readValue(payload, "name", readValue(payload, "PASSENGERNAME", ""))));
            phoneVal = trim(toString(readValue(payload, "phone", readValue(payload, "PHONE", ""))));
            ageVal = trim(toString(readValue(payload, "age", readValue(payload, "AGE", ""))));
            genderVal = trim(toString(readValue(payload, "gender", readValue(payload, "GENDER", ""))));
            notesVal = trim(toString(readValue(payload, "notes", readValue(payload, "NOTES", ""))));

            if (!len(passengerName)) {
                return buildResponse(false, true, "Validation failed", {}, "Passenger name is required.");
            }

            if (len(passengerName) GT 255) passengerName = left(passengerName, 255);
            if (len(phoneVal) GT 45) phoneVal = left(phoneVal, 45);
            if (len(ageVal) GT 45) ageVal = left(ageVal, 45);
            if (len(genderVal) GT 45) genderVal = left(genderVal, 45);
            if (len(notesVal) GT 500) notesVal = left(notesVal, 500);

            if (passengerId GT 0) {
                existing = queryExecute(
                    "SELECT passId, userId
                     FROM passengers
                     WHERE passId = :passengerId
                     LIMIT 1",
                    {
                        passengerId = { value = passengerId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = getDatasource() }
                );
                if (existing.recordCount EQ 0) {
                    return buildResponse(false, true, "Not found", {}, "Passenger not found.");
                }
                userIdTxt = trim(toString(existing.userId[1]));

                queryExecute(
                    "UPDATE passengers
                     SET name = :name,
                         phone = :phone,
                         age = :age,
                         gender = :gender,
                         notes = :notes
                     WHERE passId = :passengerId",
                    {
                        name = { value = passengerName, cfsqltype = "cf_sql_varchar" },
                        phone = { value = phoneVal, cfsqltype = "cf_sql_varchar" },
                        age = { value = ageVal, cfsqltype = "cf_sql_varchar" },
                        gender = { value = genderVal, cfsqltype = "cf_sql_varchar" },
                        notes = { value = notesVal, cfsqltype = "cf_sql_varchar" },
                        passengerId = { value = passengerId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = getDatasource() }
                );
            } else {
                if (!isNumeric(userIdTxt) OR val(userIdTxt) LTE 0) {
                    return buildResponse(false, true, "Validation failed", {}, "userId is required when creating a passenger.");
                }

                queryExecute(
                    "INSERT INTO passengers (userId, name, phone, age, gender, notes, pfd)
                     VALUES (:userId, :name, :phone, :age, :gender, :notes, :pfd)",
                    {
                        userId = { value = userIdTxt, cfsqltype = "cf_sql_varchar" },
                        name = { value = passengerName, cfsqltype = "cf_sql_varchar" },
                        phone = { value = phoneVal, cfsqltype = "cf_sql_varchar" },
                        age = { value = ageVal, cfsqltype = "cf_sql_varchar" },
                        gender = { value = genderVal, cfsqltype = "cf_sql_varchar" },
                        notes = { value = notesVal, cfsqltype = "cf_sql_varchar" },
                        pfd = { value = 1, cfsqltype = "cf_sql_bit" }
                    },
                    { datasource = getDatasource() }
                );

                qInsertId = queryExecute(
                    "SELECT LAST_INSERT_ID() AS new_id",
                    {},
                    { datasource = getDatasource() }
                );
                if (qInsertId.recordCount GT 0 AND isNumeric(qInsertId.new_id[1])) {
                    passengerId = toInt(qInsertId.new_id[1]);
                }
                if (passengerId LTE 0) {
                    return buildResponse(false, true, "Insert failed", {}, "Passenger created but id could not be resolved.");
                }
            }

            qSaved = loadPassengerQuery(passengerId);
            return buildResponse(true, true, "Passenger saved", {
                "passengerId" = passengerId,
                "passenger" = (qSaved.recordCount GT 0 ? normalizePassengerRow(qSaved, 1) : {})
            });
        </cfscript>
    </cffunction>

    <cffunction name="deletePassenger" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var passengerId = toInt(readValue(arguments.body, "passengerId", readValue(arguments.body, "PASSENGERID", readValue(url, "passengerId", 0))));
            var result = {};

            if (passengerId LTE 0) {
                return buildResponse(false, true, "Invalid passenger", {}, "passengerId is required.");
            }

            result = deletePassengerById(passengerId);
            if (!result.success) {
                return buildResponse(false, true, "Delete failed", result, result.message);
            }

            return buildResponse(true, true, "Passenger deleted", result);
        </cfscript>
    </cffunction>

    <cffunction name="batchDeletePassengers" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var rawIds = readValue(arguments.body, "passengerIds", readValue(arguments.body, "ids", []));
            var ids = normalizeIdArray(rawIds);
            var item = 0;
            var perItem = [];
            var one = {};
            var deletedCount = 0;
            var failedCount = 0;
            var blockedCount = 0;
            var overallOk = false;

            if (!arrayLen(ids)) {
                return buildResponse(false, true, "Validation failed", {}, "passengerIds must be a non-empty array.");
            }

            for (item in ids) {
                one = deletePassengerById(item);
                if (one.success) {
                    deletedCount++;
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
                "results" = perItem
            }, (overallOk ? "" : "One or more passengers could not be deleted."));
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
                    COUNT(p.passId) AS passenger_count
                FROM users u
                LEFT JOIN passengers p
                    ON p.userId = u.userId
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
                ORDER BY passenger_count DESC, u.userId DESC
                LIMIT :limitVal";
            params.limitVal = { value = limitVal, cfsqltype = "cf_sql_integer" };

            qUsers = queryExecute(sql, params, { datasource = getDatasource() });
            for (i = 1; i LTE qUsers.recordCount; i++) {
                arrayAppend(rows, {
                    "userId" = val(qUsers.userId[i]),
                    "email" = (isNull(qUsers.email[i]) ? "" : toString(qUsers.email[i])),
                    "firstName" = (isNull(qUsers.fName[i]) ? "" : toString(qUsers.fName[i])),
                    "lastName" = (isNull(qUsers.lName[i]) ? "" : toString(qUsers.lName[i])),
                    "passengerCount" = val(qUsers.passenger_count[i])
                });
            }

            return buildResponse(true, true, "OK", {
                "users" = rows,
                "limit" = limitVal,
                "search" = searchFilter
            });
        </cfscript>
    </cffunction>

    <cffunction name="deletePassengerById" access="private" returntype="struct" output="false">
        <cfargument name="passengerId" type="numeric" required="true">
        <cfscript>
            var qRow = queryNew("");
            var qUsage = queryNew("");
            var usageCount = 0;
            var passengerNameVal = "";
            var planLabels = [];
            var outcome = {
                "passengerId" = arguments.passengerId,
                "passengerName" = "",
                "success" = false,
                "errorCode" = "",
                "message" = "",
                "usageCount" = 0
            };

            if (arguments.passengerId LTE 0) {
                outcome.errorCode = "INVALID_ID";
                outcome.message = "passengerId is required.";
                return outcome;
            }

            qRow = queryExecute(
                "SELECT passId, name
                 FROM passengers
                 WHERE passId = :passengerId
                 LIMIT 1",
                {
                    passengerId = { value = arguments.passengerId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = getDatasource() }
            );

            if (qRow.recordCount EQ 0) {
                outcome.errorCode = "NOT_FOUND";
                outcome.message = "Passenger not found.";
                return outcome;
            }

            passengerNameVal = (isNull(qRow.name[1]) ? "" : toString(qRow.name[1]));
            outcome.passengerName = passengerNameVal;

            qUsage = queryExecute(
                "SELECT fpp.recId, fpp.floatPlanId, fp.floatPlanName
                 FROM floatplan_passengers fpp
                 LEFT JOIN floatplans fp
                    ON fp.floatPlanId = fpp.floatPlanId
                 WHERE fpp.passId = :passengerId
                 ORDER BY fpp.recId ASC",
                {
                    passengerId = { value = arguments.passengerId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = getDatasource() }
            );

            usageCount = qUsage.recordCount;
            outcome.usageCount = usageCount;

            if (usageCount GT 0) {
                for (var i = 1; i LTE qUsage.recordCount; i++) {
                    var planNameVal = (isNull(qUsage.floatPlanName[i]) ? "" : toString(qUsage.floatPlanName[i]));
                    var planIdVal = (isNull(qUsage.floatPlanId[i]) ? "" : toString(qUsage.floatPlanId[i]));
                    if (len(trim(planNameVal))) {
                        arrayAppend(planLabels, planNameVal);
                    } else {
                        arrayAppend(planLabels, "FloatPlan " & planIdVal);
                    }
                }
                outcome.errorCode = "IN_USE";
                outcome.message = "This passenger is used in " & usageCount & " float plan row(s): " & arrayToList(planLabels, ", ") & ". Delete is blocked until those links are removed.";
                return outcome;
            }

            queryExecute(
                "DELETE FROM passengers
                 WHERE passId = :passengerId",
                {
                    passengerId = { value = arguments.passengerId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = getDatasource() }
            );

            outcome.success = true;
            outcome.message = "Passenger deleted.";
            return outcome;
        </cfscript>
    </cffunction>

    <cffunction name="loadPassengerQuery" access="private" returntype="query" output="false">
        <cfargument name="passengerId" type="numeric" required="true">
        <cfscript>
            return queryExecute(
                "SELECT
                    p.passId,
                    p.userId,
                    p.name,
                    p.phone,
                    p.age,
                    p.gender,
                    p.notes,
                    p.pfd,
                    u.email,
                    u.fName,
                    u.lName,
                    COALESCE(usageAgg.usage_count, 0) AS usage_count
                 FROM passengers p
                 LEFT JOIN users u
                    ON u.userId = p.userId
                 LEFT JOIN (
                    SELECT passId, COUNT(*) AS usage_count
                    FROM floatplan_passengers
                    GROUP BY passId
                 ) usageAgg
                    ON usageAgg.passId = p.passId
                 WHERE p.passId = :passengerId
                 LIMIT 1",
                {
                    passengerId = { value = arguments.passengerId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = getDatasource() }
            );
        </cfscript>
    </cffunction>

    <cffunction name="normalizePassengerRow" access="private" returntype="struct" output="false">
        <cfargument name="q" type="query" required="true">
        <cfargument name="idx" type="numeric" required="true">
        <cfscript>
            return {
                "PASSENGERID" = val(arguments.q.passId[arguments.idx]),
                "USERID" = (isNull(arguments.q.userId[arguments.idx]) ? "" : toString(arguments.q.userId[arguments.idx])),
                "PASSENGERNAME" = (isNull(arguments.q.name[arguments.idx]) ? "" : toString(arguments.q.name[arguments.idx])),
                "PHONE" = (isNull(arguments.q.phone[arguments.idx]) ? "" : toString(arguments.q.phone[arguments.idx])),
                "AGE" = (isNull(arguments.q.age[arguments.idx]) ? "" : toString(arguments.q.age[arguments.idx])),
                "GENDER" = (isNull(arguments.q.gender[arguments.idx]) ? "" : toString(arguments.q.gender[arguments.idx])),
                "NOTES" = (isNull(arguments.q.notes[arguments.idx]) ? "" : toString(arguments.q.notes[arguments.idx])),
                "HAS_PFD" = toBoolean((isNull(arguments.q.pfd[arguments.idx]) ? "" : toString(arguments.q.pfd[arguments.idx])), false),
                "USER_EMAIL" = (isNull(arguments.q.email[arguments.idx]) ? "" : toString(arguments.q.email[arguments.idx])),
                "USER_FIRSTNAME" = (isNull(arguments.q.fName[arguments.idx]) ? "" : toString(arguments.q.fName[arguments.idx])),
                "USER_LASTNAME" = (isNull(arguments.q.lName[arguments.idx]) ? "" : toString(arguments.q.lName[arguments.idx])),
                "USAGE_COUNT" = (isNull(arguments.q.usage_count[arguments.idx]) ? 0 : val(arguments.q.usage_count[arguments.idx]))
            };
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
