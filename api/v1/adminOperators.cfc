<cfcomponent output="false" hint="Admin operator management API.">

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
                        response = listOperators(body);
                        break;
                    case "get":
                        response = getOperator(body);
                        break;
                    case "save":
                        response = saveOperator(body);
                        break;
                    case "delete":
                        response = deleteOperator(body);
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
                            "Valid actions: list, get, save, delete, listUsers."
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

    <cffunction name="listOperators" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var pageLimit = toInt(readValue(arguments.body, "limit", readValue(url, "limit", 100)));
            var pageOffset = toInt(readValue(arguments.body, "offset", readValue(url, "offset", 0)));
            var userIdFilter = trim(toString(readValue(arguments.body, "userId", readValue(url, "userId", ""))));
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

            if (len(userIdFilter)) {
                arrayAppend(whereParts, "CAST(o.userId AS CHAR) = :userIdFilter");
                params.userIdFilter = { value = userIdFilter, cfsqltype = "cf_sql_varchar" };
            }

            if (len(emailFilter)) {
                arrayAppend(whereParts, "LOWER(COALESCE(u.email, '')) LIKE :emailLike");
                params.emailLike = { value = "%" & emailFilter & "%", cfsqltype = "cf_sql_varchar" };
            }

            if (len(searchFilter)) {
                arrayAppend(whereParts, "(
                    LOWER(COALESCE(o.name, '')) LIKE :searchLike
                    OR LOWER(COALESCE(o.homePhone, '')) LIKE :searchLike
                    OR LOWER(COALESCE(o.notes, '')) LIKE :searchLike
                    OR CAST(o.opId AS CHAR) LIKE :searchLike
                )");
                params.searchLike = { value = "%" & searchFilter & "%", cfsqltype = "cf_sql_varchar" };
            }

            sqlWhere = arrayToList(whereParts, " AND ");

            listSql = "
                SELECT
                    o.opId,
                    o.userId,
                    o.name,
                    o.homePhone,
                    o.notes,
                    u.email,
                    u.fName,
                    u.lName,
                    COALESCE(usageAgg.usage_count, 0) AS usage_count
                FROM operators o
                LEFT JOIN users u
                    ON CAST(u.userId AS CHAR) = CAST(o.userId AS CHAR)
                LEFT JOIN (
                    SELECT operatorId, userId, COUNT(*) AS usage_count
                    FROM floatplans
                    GROUP BY operatorId, userId
                ) usageAgg
                    ON usageAgg.operatorId = o.opId
                   AND CAST(usageAgg.userId AS CHAR) = CAST(o.userId AS CHAR)
                WHERE #sqlWhere#
                ORDER BY o.opId DESC
                LIMIT :pageLimit
                OFFSET :pageOffset";

            countSql = "
                SELECT COUNT(*) AS total_count
                FROM operators o
                LEFT JOIN users u
                    ON CAST(u.userId AS CHAR) = CAST(o.userId AS CHAR)
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
                arrayAppend(rows, normalizeOperatorRow(qRows, i));
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

    <cffunction name="getOperator" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var operatorId = toInt(readValue(arguments.body, "operatorId", readValue(arguments.body, "OPERATORID", readValue(url, "operatorId", 0))));
            var qRow = queryNew("");

            if (operatorId LTE 0) {
                return buildResponse(false, true, "Invalid operator", {}, "operatorId is required.");
            }

            qRow = loadOperatorQuery(operatorId);
            if (qRow.recordCount EQ 0) {
                return buildResponse(false, true, "Not found", {}, "Operator not found.");
            }

            return buildResponse(true, true, "OK", {
                "operator" = normalizeOperatorRow(qRow, 1)
            });
        </cfscript>
    </cffunction>

    <cffunction name="saveOperator" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var payload = {};
            var operatorId = 0;
            var userIdTxt = "";
            var operatorName = "";
            var phoneVal = "";
            var notesVal = "";
            var existing = queryNew("");
            var qSaved = queryNew("");
            var qInsertId = queryNew("");

            if (structKeyExists(arguments.body, "operator") AND isStruct(arguments.body.operator)) {
                payload = arguments.body.operator;
            } else if (structKeyExists(arguments.body, "OPERATOR") AND isStruct(arguments.body.OPERATOR)) {
                payload = arguments.body.OPERATOR;
            } else {
                payload = arguments.body;
            }

            operatorId = toInt(readValue(payload, "operatorId", readValue(payload, "OPERATORID", 0)));
            userIdTxt = trim(toString(readValue(payload, "userId", readValue(payload, "USERID", ""))));
            operatorName = trim(toString(readValue(payload, "name", readValue(payload, "OPERATORNAME", ""))));
            phoneVal = trim(toString(readValue(payload, "phone", readValue(payload, "PHONE", ""))));
            notesVal = trim(toString(readValue(payload, "notes", readValue(payload, "NOTES", ""))));

            if (!len(operatorName)) {
                return buildResponse(false, true, "Validation failed", {}, "Operator name is required.");
            }

            if (len(operatorName) GT 255) operatorName = left(operatorName, 255);
            if (len(phoneVal) GT 45) phoneVal = left(phoneVal, 45);
            if (len(notesVal) GT 500) notesVal = left(notesVal, 500);

            if (operatorId GT 0) {
                existing = queryExecute(
                    "SELECT opId, userId
                     FROM operators
                     WHERE opId = :operatorId
                     LIMIT 1",
                    {
                        operatorId = { value = operatorId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = getDatasource() }
                );
                if (existing.recordCount EQ 0) {
                    return buildResponse(false, true, "Not found", {}, "Operator not found.");
                }
                userIdTxt = trim(toString(existing.userId[1]));

                queryExecute(
                    "UPDATE operators
                     SET name = :name,
                         homePhone = :phone,
                         notes = :notes
                     WHERE opId = :operatorId
                       AND CAST(userId AS CHAR) = :userId",
                    {
                        name = { value = operatorName, cfsqltype = "cf_sql_varchar" },
                        phone = { value = phoneVal, cfsqltype = "cf_sql_varchar" },
                        notes = { value = notesVal, cfsqltype = "cf_sql_varchar" },
                        operatorId = { value = operatorId, cfsqltype = "cf_sql_integer" },
                        userId = { value = userIdTxt, cfsqltype = "cf_sql_varchar" }
                    },
                    { datasource = getDatasource() }
                );
            } else {
                if (!isNumeric(userIdTxt) OR val(userIdTxt) LTE 0) {
                    return buildResponse(false, true, "Validation failed", {}, "userId is required when creating an operator.");
                }

                queryExecute(
                    "INSERT INTO operators (userId, name, homePhone, notes)
                     VALUES (:userId, :name, :phone, :notes)",
                    {
                        userId = { value = userIdTxt, cfsqltype = "cf_sql_varchar" },
                        name = { value = operatorName, cfsqltype = "cf_sql_varchar" },
                        phone = { value = phoneVal, cfsqltype = "cf_sql_varchar" },
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
                    operatorId = toInt(qInsertId.new_id[1]);
                }
                if (operatorId LTE 0) {
                    return buildResponse(false, true, "Insert failed", {}, "Operator created but id could not be resolved.");
                }
            }

            qSaved = loadOperatorQuery(operatorId);
            return buildResponse(true, true, "Operator saved", {
                "operatorId" = operatorId,
                "operator" = (qSaved.recordCount GT 0 ? normalizeOperatorRow(qSaved, 1) : {})
            });
        </cfscript>
    </cffunction>

    <cffunction name="deleteOperator" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var operatorId = toInt(readValue(arguments.body, "operatorId", readValue(arguments.body, "OPERATORID", readValue(url, "operatorId", 0))));
            var result = {};

            if (operatorId LTE 0) {
                return buildResponse(false, true, "Invalid operator", {}, "operatorId is required.");
            }

            result = deleteOperatorById(operatorId);
            if (!result.success) {
                return buildResponse(false, true, "Delete failed", result, result.message);
            }

            return buildResponse(true, true, "Operator deleted", result);
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
                    COUNT(o.opId) AS operator_count
                FROM users u
                LEFT JOIN operators o
                    ON CAST(o.userId AS CHAR) = CAST(u.userId AS CHAR)
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
                ORDER BY operator_count DESC, u.userId DESC
                LIMIT :limitVal";
            params.limitVal = { value = limitVal, cfsqltype = "cf_sql_integer" };

            qUsers = queryExecute(sql, params, { datasource = getDatasource() });
            for (i = 1; i LTE qUsers.recordCount; i++) {
                arrayAppend(rows, {
                    "userId" = val(qUsers.userId[i]),
                    "email" = (isNull(qUsers.email[i]) ? "" : toString(qUsers.email[i])),
                    "firstName" = (isNull(qUsers.fName[i]) ? "" : toString(qUsers.fName[i])),
                    "lastName" = (isNull(qUsers.lName[i]) ? "" : toString(qUsers.lName[i])),
                    "operatorCount" = val(qUsers.operator_count[i])
                });
            }

            return buildResponse(true, true, "OK", {
                "users" = rows,
                "limit" = limitVal,
                "search" = searchFilter
            });
        </cfscript>
    </cffunction>

    <cffunction name="deleteOperatorById" access="private" returntype="struct" output="false">
        <cfargument name="operatorId" type="numeric" required="true">
        <cfscript>
            var qRow = queryNew("");
            var qUsage = queryNew("");
            var usageCount = 0;
            var operatorNameVal = "";
            var ownerUserId = "";
            var planLabels = [];
            var outcome = {
                "operatorId" = arguments.operatorId,
                "operatorName" = "",
                "success" = false,
                "errorCode" = "",
                "message" = "",
                "usageCount" = 0
            };

            if (arguments.operatorId LTE 0) {
                outcome.errorCode = "INVALID_ID";
                outcome.message = "operatorId is required.";
                return outcome;
            }

            qRow = queryExecute(
                "SELECT opId, userId, name
                 FROM operators
                 WHERE opId = :operatorId
                 LIMIT 1",
                {
                    operatorId = { value = arguments.operatorId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = getDatasource() }
            );

            if (qRow.recordCount EQ 0) {
                outcome.errorCode = "NOT_FOUND";
                outcome.message = "Operator not found.";
                return outcome;
            }

            ownerUserId = (isNull(qRow.userId[1]) ? "" : toString(qRow.userId[1]));
            operatorNameVal = (isNull(qRow.name[1]) ? "" : toString(qRow.name[1]));
            outcome.operatorName = operatorNameVal;

            qUsage = queryExecute(
                "SELECT floatPlanId, floatPlanName
                 FROM floatplans
                 WHERE operatorId = :operatorId
                   AND CAST(userId AS CHAR) = :ownerUserId
                 ORDER BY floatPlanId ASC",
                {
                    operatorId = { value = arguments.operatorId, cfsqltype = "cf_sql_integer" },
                    ownerUserId = { value = ownerUserId, cfsqltype = "cf_sql_varchar" }
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
                outcome.message = "This operator is used in " & usageCount & " float plan" & (usageCount EQ 1 ? "" : "s") & ": " & arrayToList(planLabels, ", ") & ". Edit the float plan to remove it before deleting.";
                return outcome;
            }

            queryExecute(
                "DELETE FROM operators
                 WHERE opId = :operatorId",
                {
                    operatorId = { value = arguments.operatorId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = getDatasource() }
            );

            outcome.success = true;
            outcome.message = "Operator deleted.";
            return outcome;
        </cfscript>
    </cffunction>

    <cffunction name="loadOperatorQuery" access="private" returntype="query" output="false">
        <cfargument name="operatorId" type="numeric" required="true">
        <cfscript>
            return queryExecute(
                "SELECT
                    o.opId,
                    o.userId,
                    o.name,
                    o.homePhone,
                    o.notes,
                    u.email,
                    u.fName,
                    u.lName,
                    COALESCE(usageAgg.usage_count, 0) AS usage_count
                 FROM operators o
                 LEFT JOIN users u
                    ON CAST(u.userId AS CHAR) = CAST(o.userId AS CHAR)
                 LEFT JOIN (
                    SELECT operatorId, userId, COUNT(*) AS usage_count
                    FROM floatplans
                    GROUP BY operatorId, userId
                 ) usageAgg
                    ON usageAgg.operatorId = o.opId
                   AND CAST(usageAgg.userId AS CHAR) = CAST(o.userId AS CHAR)
                 WHERE o.opId = :operatorId
                 LIMIT 1",
                {
                    operatorId = { value = arguments.operatorId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = getDatasource() }
            );
        </cfscript>
    </cffunction>

    <cffunction name="normalizeOperatorRow" access="private" returntype="struct" output="false">
        <cfargument name="q" type="query" required="true">
        <cfargument name="idx" type="numeric" required="true">
        <cfscript>
            return {
                "OPERATORID" = val(arguments.q.opId[arguments.idx]),
                "USERID" = (isNull(arguments.q.userId[arguments.idx]) ? "" : toString(arguments.q.userId[arguments.idx])),
                "OPERATORNAME" = (isNull(arguments.q.name[arguments.idx]) ? "" : toString(arguments.q.name[arguments.idx])),
                "PHONE" = (isNull(arguments.q.homePhone[arguments.idx]) ? "" : toString(arguments.q.homePhone[arguments.idx])),
                "NOTES" = (isNull(arguments.q.notes[arguments.idx]) ? "" : toString(arguments.q.notes[arguments.idx])),
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
