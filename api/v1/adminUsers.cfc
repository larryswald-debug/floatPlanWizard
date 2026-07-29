<cfcomponent output="false" hint="Admin user management API.">

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
                    response = buildResponse(false, false, "Unauthorized", {}, "Authentication is required.");
                    writeOutput(serializeJSON(response));
                    return;
                }

                if (!structKeyExists(request, "fpwAdminAuthorization") OR request.fpwAdminAuthorization.authorized NEQ true) {
                    response = buildResponse(false, true, "Forbidden", {}, "Admin privileges are required.");
                    writeOutput(serializeJSON(response));
                    return;
                }

                switch (actionName) {
                    case "list":
                        response = listUsers(body);
                        break;
                    case "get":
                        response = getUser(body);
                        break;
                    case "save":
                        response = saveUser(body);
                        break;
                    case "deletepreview":
                        response = previewDeleteUser(body);
                        break;
                    case "deleteexecute":
                        response = executeDeleteUser(body);
                        break;
                    default:
                        response = buildResponse(false, true, "Unknown action", {}, "Valid actions: list, get, save, deletePreview, deleteExecute.");
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

    <cffunction name="listUsers" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var pageLimit = toInt(readValue(arguments.body, "limit", readValue(url, "limit", 50)));
            var pageOffset = toInt(readValue(arguments.body, "offset", readValue(url, "offset", 0)));
            var searchFilter = lCase(trim(toString(readValue(arguments.body, "search", readValue(url, "search", "")))));
            var emailFilter = lCase(trim(toString(readValue(arguments.body, "email", readValue(url, "email", "")))));
            var phoneFilter = lCase(trim(toString(readValue(arguments.body, "phone", readValue(url, "phone", "")))));
            var userIdFilter = trim(toString(readValue(arguments.body, "userId", readValue(url, "userId", ""))));
            var whereParts = ["1=1"];
            var params = {};
            var sqlWhere = "";
            var listSql = "";
            var countSql = "";
            var qRows = queryNew("");
            var qCount = queryNew("");
            var rows = [];
            var i = 0;
            var totalCount = 0;

            if (pageLimit LTE 0) pageLimit = 50;
            if (pageLimit GT 500) pageLimit = 500;
            if (pageOffset LT 0) pageOffset = 0;
            if (pageOffset GT 500000) pageOffset = 500000;

            if (len(userIdFilter)) {
                arrayAppend(whereParts, "CAST(u.userId AS CHAR) = :userIdFilter");
                params.userIdFilter = { value = userIdFilter, cfsqltype = "cf_sql_varchar" };
            }

            if (len(emailFilter)) {
                arrayAppend(whereParts, "LOWER(COALESCE(u.email, '')) LIKE :emailLike");
                params.emailLike = { value = "%" & emailFilter & "%", cfsqltype = "cf_sql_varchar" };
            }

            if (len(phoneFilter)) {
                arrayAppend(whereParts, "(
                    LOWER(COALESCE(u.mobilePhone, '')) LIKE :phoneLike
                    OR LOWER(COALESCE(addr.address_phones, '')) LIKE :phoneLike
                )");
                params.phoneLike = { value = "%" & phoneFilter & "%", cfsqltype = "cf_sql_varchar" };
            }

            if (len(searchFilter)) {
                arrayAppend(whereParts, "(
                    LOWER(COALESCE(u.fName, '')) LIKE :searchLike
                    OR LOWER(COALESCE(u.lName, '')) LIKE :searchLike
                    OR LOWER(CONCAT(COALESCE(u.fName, ''), ' ', COALESCE(u.lName, ''))) LIKE :searchLike
                    OR LOWER(COALESCE(u.email, '')) LIKE :searchLike
                    OR LOWER(COALESCE(u.mobilePhone, '')) LIKE :searchLike
                    OR LOWER(COALESCE(addr.address_phones, '')) LIKE :searchLike
                    OR CAST(u.userId AS CHAR) LIKE :searchLike
                )");
                params.searchLike = { value = "%" & searchFilter & "%", cfsqltype = "cf_sql_varchar" };
            }

            sqlWhere = arrayToList(whereParts, " AND ");
            params.limitVal = { value = pageLimit, cfsqltype = "cf_sql_integer" };
            params.offsetVal = { value = pageOffset, cfsqltype = "cf_sql_integer" };

            listSql = "
                SELECT
                    u.userId,
                    u.fName,
                    u.lName,
                    u.email,
                    u.mobilePhone,
                    u.hostek_userId,
                    u.created,
                    u.lastLogin,
                    u.lastUpdate,
                    COALESCE(addr.address_phones, '') AS address_phones,
                    COALESCE(addr.address_count, 0) AS address_count
                FROM users u
                LEFT JOIN (
                    SELECT
                        userId,
                        GROUP_CONCAT(DISTINCT phone ORDER BY recId SEPARATOR ', ') AS address_phones,
                        COUNT(*) AS address_count
                    FROM users_address
                    GROUP BY userId
                ) addr ON addr.userId = u.userId
                WHERE #sqlWhere#
                ORDER BY u.userId DESC
                LIMIT :limitVal OFFSET :offsetVal";

            countSql = "
                SELECT COUNT(*) AS total_count
                FROM users u
                LEFT JOIN (
                    SELECT
                        userId,
                        GROUP_CONCAT(DISTINCT phone ORDER BY recId SEPARATOR ', ') AS address_phones
                    FROM users_address
                    GROUP BY userId
                ) addr ON addr.userId = u.userId
                WHERE #sqlWhere#";

            qRows = queryExecute(listSql, params, { datasource = getDatasource() });
            structDelete(params, "limitVal");
            structDelete(params, "offsetVal");
            qCount = queryExecute(countSql, params, { datasource = getDatasource() });
            totalCount = qCount.recordCount ? val(qCount.total_count[1]) : 0;

            for (i = 1; i LTE qRows.recordCount; i++) {
                arrayAppend(rows, normalizeUserListRow(qRows, i));
            }

            return buildResponse(true, true, "Users loaded.", {
                "items" = rows,
                "total" = totalCount,
                "limit" = pageLimit,
                "offset" = pageOffset
            });
        </cfscript>
    </cffunction>

    <cffunction name="getUser" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var userId = toInt(readValue(arguments.body, "userId", readValue(url, "userId", 0)));
            var qUser = queryNew("");
            var qAddresses = queryNew("");
            var out = {};
            var addresses = [];
            var i = 0;

            if (userId LTE 0) {
                return buildResponse(false, true, "Validation failed", {}, "A valid userId is required.");
            }

            qUser = queryExecute(
                "SELECT userId, fName, lName, email, passwordCreated, lastLogin, lastUpdate,
                        mobilePhone, photoFileId, requestReset, resetId, created, hostek_userId,
                        CASE WHEN password IS NULL OR password = '' THEN 0 ELSE 1 END AS has_password
                 FROM users
                 WHERE userId = :userId
                 LIMIT 1",
                { userId = { value = userId, cfsqltype = "cf_sql_integer" } },
                { datasource = getDatasource() }
            );

            if (qUser.recordCount EQ 0) {
                return buildResponse(false, true, "User not found", {}, "User was not found.");
            }

            qAddresses = queryExecute(
                "SELECT recId, userId, address, city, state, zip, phone, lat, lng, isHomePort
                 FROM users_address
                 WHERE userId = :userId
                 ORDER BY recId ASC",
                { userId = { value = userId, cfsqltype = "cf_sql_integer" } },
                { datasource = getDatasource() }
            );

            for (i = 1; i LTE qAddresses.recordCount; i++) {
                arrayAppend(addresses, normalizeAddressRow(qAddresses, i));
            }

            out = normalizeUserDetailRow(qUser, 1);
            out.addresses = addresses;

            return buildResponse(true, true, "User loaded.", { "user" = out });
        </cfscript>
    </cffunction>

    <cffunction name="saveUser" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var userId = toInt(readValue(arguments.body, "userId", 0));
            var firstName = left(trim(toString(readValue(arguments.body, "firstName", readValue(arguments.body, "fName", "")))), 45);
            var lastName = left(trim(toString(readValue(arguments.body, "lastName", readValue(arguments.body, "lName", "")))), 45);
            var emailValue = left(trim(toString(readValue(arguments.body, "email", ""))), 255);
            var mobilePhone = left(trim(toString(readValue(arguments.body, "mobilePhone", ""))), 50);
            var hostekUserId = left(trim(toString(readValue(arguments.body, "hostekUserId", readValue(arguments.body, "hostek_userId", "")))), 255);
            var addresses = readValue(arguments.body, "addresses", []);
            var qExisting = queryNew("");
            var qEmail = queryNew("");
            var i = 0;

            if (userId LTE 0) {
                return buildResponse(false, true, "Validation failed", {}, "A valid userId is required.");
            }
            if (!len(emailValue)) {
                return buildResponse(false, true, "Validation failed", {}, "Email is required.");
            }
            if (!find("@", emailValue)) {
                return buildResponse(false, true, "Validation failed", {}, "Email must include @.");
            }

            qExisting = queryExecute(
                "SELECT userId FROM users WHERE userId = :userId LIMIT 1",
                { userId = { value = userId, cfsqltype = "cf_sql_integer" } },
                { datasource = getDatasource() }
            );
            if (qExisting.recordCount EQ 0) {
                return buildResponse(false, true, "User not found", {}, "User was not found.");
            }

            qEmail = queryExecute(
                "SELECT userId
                 FROM users
                 WHERE LOWER(email) = LOWER(:email)
                   AND userId <> :userId
                 LIMIT 1",
                {
                    email = { value = emailValue, cfsqltype = "cf_sql_varchar" },
                    userId = { value = userId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = getDatasource() }
            );
            if (qEmail.recordCount GT 0) {
                return buildResponse(false, true, "Validation failed", {}, "Email is already used by another user.");
            }

            transaction {
                queryExecute(
                    "UPDATE users
                     SET fName = :firstName,
                         lName = :lastName,
                         email = :email,
                         mobilePhone = :mobilePhone,
                         hostek_userId = :hostekUserId,
                         lastUpdate = NOW()
                     WHERE userId = :userId",
                    {
                        firstName = { value = firstName, cfsqltype = "cf_sql_varchar" },
                        lastName = { value = lastName, cfsqltype = "cf_sql_varchar" },
                        email = { value = emailValue, cfsqltype = "cf_sql_varchar" },
                        mobilePhone = { value = mobilePhone, cfsqltype = "cf_sql_varchar" },
                        hostekUserId = { value = hostekUserId, cfsqltype = "cf_sql_varchar" },
                        userId = { value = userId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = getDatasource() }
                );

                if (isArray(addresses)) {
                    for (i = 1; i LTE arrayLen(addresses); i++) {
                        saveAddressRow(userId, addresses[i]);
                    }
                }
            }

            return buildResponse(true, true, "User saved.", { "userId" = userId });
        </cfscript>
    </cffunction>

    <cffunction name="previewDeleteUser" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var result = buildDeletePreview(arguments.body);
            if (!result.success) {
                return buildResponse(false, true, "Delete preview failed", {}, result.message);
            }
            return buildResponse(true, true, "Delete preview loaded.", result.data);
        </cfscript>
    </cffunction>

    <cffunction name="executeDeleteUser" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var confirmation = trim(toString(readValue(arguments.body, "confirmation", "")));
            var preview = {};
            var target = {};

            if (confirmation NEQ "I UNDERSTAND THIS DELETES ONE FPW USER") {
                return buildResponse(false, true, "Confirmation failed", {}, "Confirmation text does not match.");
            }

            preview = buildDeletePreview(arguments.body);
            if (!preview.success) {
                return buildResponse(false, true, "Delete failed", {}, preview.message);
            }

            target = preview.data.target;
            transaction {
                prepareDeleteTempTables(target.userId, target.email, target.hostekUserId);
                runDeleteStatements(target);
            }

            return buildResponse(true, true, "User deleted.", {
                "target" = target,
                "counts" = preview.data.counts,
                "totalRows" = preview.data.totalRows
            });
        </cfscript>
    </cffunction>

    <cffunction name="buildDeletePreview" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var userId = toInt(readValue(arguments.body, "userId", readValue(url, "userId", 0)));
            var emailValue = trim(toString(readValue(arguments.body, "email", readValue(url, "email", ""))));
            var qTarget = resolveDeleteTarget(userId, emailValue);
            var target = {};
            var counts = [];
            var totalRows = 0;
            var i = 0;

            if (qTarget.recordCount NEQ 1) {
                return { "success" = false, "message" = "Delete target must resolve to exactly one user." };
            }

            target = {
                "userId" = val(qTarget.userId[1]),
                "email" = safeQueryString(qTarget, "email", 1),
                "firstName" = safeQueryString(qTarget, "fName", 1),
                "lastName" = safeQueryString(qTarget, "lName", 1),
                "hostekUserId" = safeQueryString(qTarget, "hostek_userId", 1)
            };

            transaction {
                prepareDeleteTempTables(target.userId, target.email, target.hostekUserId);
                counts = loadDeleteCounts(target);
            }

            for (i = 1; i LTE arrayLen(counts); i++) {
                totalRows += val(counts[i].rowsBefore);
            }

            return {
                "success" = true,
                "message" = "",
                "data" = {
                    "target" = target,
                    "counts" = counts,
                    "totalRows" = totalRows,
                    "confirmationRequired" = "I UNDERSTAND THIS DELETES ONE FPW USER"
                }
            };
        </cfscript>
    </cffunction>

    <cffunction name="resolveDeleteTarget" access="private" returntype="query" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="email" type="string" required="true">
        <cfscript>
            var params = {};
            var whereParts = [];

            if (arguments.userId GT 0) {
                arrayAppend(whereParts, "userId = :userId");
                params.userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" };
            }
            if (len(trim(arguments.email))) {
                arrayAppend(whereParts, "LOWER(email) = LOWER(:email)");
                params.email = { value = trim(arguments.email), cfsqltype = "cf_sql_varchar" };
            }
            if (!arrayLen(whereParts)) {
                return queryNew("");
            }

            return queryExecute(
                "SELECT userId, fName, lName, email, hostek_userId
                 FROM users
                 WHERE " & arrayToList(whereParts, " OR ") & "
                 ORDER BY userId",
                params,
                { datasource = getDatasource() }
            );
        </cfscript>
    </cffunction>

    <cffunction name="prepareDeleteTempTables" access="private" returntype="void" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="email" type="string" required="true">
        <cfargument name="hostekUserId" type="string" required="false" default="">
        <cfscript>
            var params = {
                targetUserId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                targetEmailKey = { value = lCase(trim(arguments.email)), cfsqltype = "cf_sql_varchar" },
                targetHostekUserId = { value = trim(arguments.hostekUserId), cfsqltype = "cf_sql_varchar" }
            };

            execSql("DROP TEMPORARY TABLE IF EXISTS _fpw_delete_target_runtime");
            execSql("CREATE TEMPORARY TABLE _fpw_delete_target_runtime (user_id INT NOT NULL PRIMARY KEY, email_key VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL, hostek_user_id VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL) ENGINE=MEMORY");
            execSql("INSERT INTO _fpw_delete_target_runtime (user_id, email_key, hostek_user_id) VALUES (:targetUserId, :targetEmailKey, :targetHostekUserId)", params);

            execSql("DROP TEMPORARY TABLE IF EXISTS _fpw_delete_floatplans");
            execSql("CREATE TEMPORARY TABLE _fpw_delete_floatplans (floatplan_id INT NOT NULL PRIMARY KEY) ENGINE=MEMORY");
            execSql("INSERT IGNORE INTO _fpw_delete_floatplans (floatplan_id) SELECT floatPlanId FROM floatplans WHERE TRIM(CAST(userId AS CHAR)) = CAST(:targetUserId AS CHAR)", params);

            execSql("DROP TEMPORARY TABLE IF EXISTS _fpw_delete_user_routes");
            execSql("CREATE TEMPORARY TABLE _fpw_delete_user_routes (user_route_id INT NOT NULL PRIMARY KEY) ENGINE=MEMORY");
            execSql("INSERT IGNORE INTO _fpw_delete_user_routes (user_route_id) SELECT id FROM user_routes WHERE user_id = :targetUserId", params);

            execSql("DROP TEMPORARY TABLE IF EXISTS _fpw_delete_waypoints");
            execSql("CREATE TEMPORARY TABLE _fpw_delete_waypoints (waypoint_id INT NOT NULL PRIMARY KEY) ENGINE=MEMORY");
            execSql("INSERT IGNORE INTO _fpw_delete_waypoints (waypoint_id) SELECT wpId FROM waypoints WHERE TRIM(CAST(userId AS CHAR)) = CAST(:targetUserId AS CHAR)", params);

            execSql("DROP TEMPORARY TABLE IF EXISTS _fpw_delete_user_route_legs");
            execSql("CREATE TEMPORARY TABLE _fpw_delete_user_route_legs (user_route_leg_id INT NOT NULL PRIMARY KEY) ENGINE=MEMORY");
            execSql("INSERT IGNORE INTO _fpw_delete_user_route_legs (user_route_leg_id) SELECT id FROM user_route_legs WHERE user_route_id IN (SELECT user_route_id FROM _fpw_delete_user_routes)");
            execSql("INSERT IGNORE INTO _fpw_delete_user_route_legs (user_route_leg_id) SELECT id FROM user_route_legs WHERE start_waypoint_id IN (SELECT waypoint_id FROM _fpw_delete_waypoints)");
            execSql("INSERT IGNORE INTO _fpw_delete_user_route_legs (user_route_leg_id) SELECT id FROM user_route_legs WHERE end_waypoint_id IN (SELECT waypoint_id FROM _fpw_delete_waypoints)");

            execSql("DROP TEMPORARY TABLE IF EXISTS _fpw_delete_route_instances");
            execSql("CREATE TEMPORARY TABLE _fpw_delete_route_instances (route_instance_id INT NOT NULL PRIMARY KEY) ENGINE=MEMORY");
            execSql("INSERT IGNORE INTO _fpw_delete_route_instances (route_instance_id) SELECT id FROM route_instances WHERE TRIM(CAST(user_id AS CHAR)) = CAST(:targetUserId AS CHAR)", params);
            execSql("INSERT IGNORE INTO _fpw_delete_route_instances (route_instance_id) SELECT DISTINCT route_instance_id FROM floatplans WHERE route_instance_id IS NOT NULL AND route_instance_id > 0 AND floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)");
            execSql("INSERT IGNORE INTO _fpw_delete_route_instances (route_instance_id) SELECT DISTINCT id FROM route_instances WHERE generated_route_id IS NOT NULL AND generated_route_id IN (SELECT user_route_id FROM _fpw_delete_user_routes)");

            execSql("DROP TEMPORARY TABLE IF EXISTS _fpw_delete_route_instance_sections");
            execSql("CREATE TEMPORARY TABLE _fpw_delete_route_instance_sections (route_instance_section_id INT NOT NULL PRIMARY KEY) ENGINE=MEMORY");
            execSql("INSERT IGNORE INTO _fpw_delete_route_instance_sections (route_instance_section_id) SELECT id FROM route_instance_sections WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)");

            execSql("DROP TEMPORARY TABLE IF EXISTS _fpw_delete_companion_devices");
            execSql("CREATE TEMPORARY TABLE _fpw_delete_companion_devices (companion_device_id BIGINT NOT NULL PRIMARY KEY) ENGINE=MEMORY");
            execSql("INSERT IGNORE INTO _fpw_delete_companion_devices (companion_device_id) SELECT id FROM companion_devices WHERE user_id = :targetUserId", params);

            execSql("DROP TEMPORARY TABLE IF EXISTS _fpw_delete_voyage_streams");
            execSql("CREATE TEMPORARY TABLE _fpw_delete_voyage_streams (stream_id INT NOT NULL PRIMARY KEY) ENGINE=MEMORY");
            execSql("INSERT IGNORE INTO _fpw_delete_voyage_streams (stream_id) SELECT id FROM voyage_streams WHERE owner_user_id = :targetUserId OR floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans)", params);

            execSql("DROP TEMPORARY TABLE IF EXISTS _fpw_delete_voyage_followers");
            execSql("CREATE TEMPORARY TABLE _fpw_delete_voyage_followers (follower_id INT NOT NULL PRIMARY KEY) ENGINE=MEMORY");
            execSql("INSERT IGNORE INTO _fpw_delete_voyage_followers (follower_id) SELECT id FROM voyage_followers WHERE stream_id IN (SELECT stream_id FROM _fpw_delete_voyage_streams) OR LOWER(CONVERT(email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = :targetEmailKey", params);

            execSql("DROP TEMPORARY TABLE IF EXISTS _fpw_delete_voyage_posts");
            execSql("CREATE TEMPORARY TABLE _fpw_delete_voyage_posts (post_id INT NOT NULL PRIMARY KEY) ENGINE=MEMORY");
            execSql("INSERT IGNORE INTO _fpw_delete_voyage_posts (post_id) SELECT id FROM voyage_posts WHERE stream_id IN (SELECT stream_id FROM _fpw_delete_voyage_streams) OR author_user_id = :targetUserId OR follower_id IN (SELECT follower_id FROM _fpw_delete_voyage_followers)", params);

            execSql("DROP TEMPORARY TABLE IF EXISTS _fpw_delete_stripe_refs");
            execSql("CREATE TEMPORARY TABLE _fpw_delete_stripe_refs (stripe_customer_id VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL, stripe_subscription_id VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL, stripe_checkout_session_id VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL, stripe_payment_intent_id VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL, KEY idx_customer (stripe_customer_id), KEY idx_subscription (stripe_subscription_id), KEY idx_checkout_session (stripe_checkout_session_id), KEY idx_payment_intent (stripe_payment_intent_id)) ENGINE=MEMORY");
            execSql("INSERT INTO _fpw_delete_stripe_refs (stripe_customer_id, stripe_subscription_id, stripe_checkout_session_id, stripe_payment_intent_id) SELECT stripe_customer_id, stripe_subscription_id, stripe_checkout_session_id, stripe_payment_intent_id FROM member_entitlements WHERE user_id = :targetUserId", params);
            execSql("INSERT INTO _fpw_delete_stripe_refs (stripe_customer_id, stripe_subscription_id, stripe_checkout_session_id, stripe_payment_intent_id) SELECT stripe_customer_id, stripe_subscription_id, stripe_checkout_session_id, NULL FROM fpw_promo_redemptions WHERE user_id = :targetUserId", params);
        </cfscript>
    </cffunction>

    <cffunction name="loadDeleteCounts" access="private" returntype="array" output="false">
        <cfargument name="target" type="struct" required="true">
        <cfscript>
            var specs = getDeleteSpecs(arguments.target);
            var rows = [];
            var i = 0;
            var spec = {};
            var rowCount = 0;
            var q = queryNew("");

            for (i = 1; i LTE arrayLen(specs); i++) {
                spec = specs[i];
                if (!tableExists(spec.tableName)) {
                    continue;
                }
                try {
                    q = queryExecute(spec.countSql, {}, { datasource = getDatasource() });
                } catch (any countError) {
                    if (isMissingTableError(countError)) {
                        continue;
                    }
                    rethrow;
                }
                rowCount = q.recordCount ? val(q["row_count"][1]) : 0;
                if (rowCount GT 0) {
                    arrayAppend(rows, {
                        "tableName" = spec.tableName,
                        "rowsBefore" = rowCount
                    });
                }
            }
            return rows;
        </cfscript>
    </cffunction>

    <cffunction name="runDeleteStatements" access="private" returntype="void" output="false">
        <cfargument name="target" type="struct" required="true">
        <cfscript>
            var specs = getDeleteSpecs(arguments.target);
            var i = 0;
            var spec = {};

            for (i = 1; i LTE arrayLen(specs); i++) {
                spec = specs[i];
                if (!tableExists(spec.tableName)) {
                    continue;
                }
                if (len(trim(spec.deleteSql))) {
                    try {
                        execSql(spec.deleteSql);
                    } catch (any deleteError) {
                        if (!isMissingTableError(deleteError)) {
                            rethrow;
                        }
                    }
                }
            }
        </cfscript>
    </cffunction>

    <cffunction name="getDeleteSpecs" access="private" returntype="array" output="false">
        <cfargument name="target" type="struct" required="true">
        <cfscript>
            var specs = [];
            arrayAppend(specs, buildDeleteSpec("voyage_comments", "SELECT COUNT(*) AS row_count FROM voyage_comments WHERE post_id IN (SELECT post_id FROM _fpw_delete_voyage_posts) OR follower_id IN (SELECT follower_id FROM _fpw_delete_voyage_followers)", "DELETE FROM voyage_comments WHERE post_id IN (SELECT post_id FROM _fpw_delete_voyage_posts) OR follower_id IN (SELECT follower_id FROM _fpw_delete_voyage_followers)"));
            arrayAppend(specs, buildDeleteSpec("voyage_reactions", "SELECT COUNT(*) AS row_count FROM voyage_reactions WHERE post_id IN (SELECT post_id FROM _fpw_delete_voyage_posts) OR follower_id IN (SELECT follower_id FROM _fpw_delete_voyage_followers)", "DELETE FROM voyage_reactions WHERE post_id IN (SELECT post_id FROM _fpw_delete_voyage_posts) OR follower_id IN (SELECT follower_id FROM _fpw_delete_voyage_followers)"));
            arrayAppend(specs, buildDeleteSpec("voyage_posts", "SELECT COUNT(*) AS row_count FROM voyage_posts WHERE id IN (SELECT post_id FROM _fpw_delete_voyage_posts)", "DELETE FROM voyage_posts WHERE id IN (SELECT post_id FROM _fpw_delete_voyage_posts)"));
            arrayAppend(specs, buildDeleteSpec("voyage_followers", "SELECT COUNT(*) AS row_count FROM voyage_followers WHERE id IN (SELECT follower_id FROM _fpw_delete_voyage_followers)", "DELETE FROM voyage_followers WHERE id IN (SELECT follower_id FROM _fpw_delete_voyage_followers)"));
            arrayAppend(specs, buildDeleteSpec("voyage_streams", "SELECT COUNT(*) AS row_count FROM voyage_streams WHERE id IN (SELECT stream_id FROM _fpw_delete_voyage_streams)", "DELETE FROM voyage_streams WHERE id IN (SELECT stream_id FROM _fpw_delete_voyage_streams)"));
            arrayAppend(specs, buildDeleteSpec("backup_route_instance_legs_endpoint_norm_20260221_222027", "SELECT COUNT(*) AS row_count FROM backup_route_instance_legs_endpoint_norm_20260221_222027 WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)", "DELETE FROM backup_route_instance_legs_endpoint_norm_20260221_222027 WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)"));
            arrayAppend(specs, buildDeleteSpec("backup_route_instance_legs_endpoint_norm_20260221_233840", "SELECT COUNT(*) AS row_count FROM backup_route_instance_legs_endpoint_norm_20260221_233840 WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)", "DELETE FROM backup_route_instance_legs_endpoint_norm_20260221_233840 WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)"));
            arrayAppend(specs, buildDeleteSpec("backup_route_instance_legs_lockcount_20260221_093626", "SELECT COUNT(*) AS row_count FROM backup_route_instance_legs_lockcount_20260221_093626 WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)", "DELETE FROM backup_route_instance_legs_lockcount_20260221_093626 WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)"));
            arrayAppend(specs, buildDeleteSpec("backup_route_instance_legs_lockcount_glreusev2_20260221_103545", "SELECT COUNT(*) AS row_count FROM backup_route_instance_legs_lockcount_glreusev2_20260221_103545 WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)", "DELETE FROM backup_route_instance_legs_lockcount_glreusev2_20260221_103545 WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)"));
            return completeDeleteSpecs(specs, arguments.target);
        </cfscript>
    </cffunction>

    <cffunction name="completeDeleteSpecs" access="private" returntype="array" output="false">
        <cfargument name="specs" type="array" required="true">
        <cfargument name="target" type="struct" required="true">
        <cfscript>
            return appendRuntimeDeleteSpecs(arguments.specs, arguments.target);
        </cfscript>
    </cffunction>

    <cffunction name="appendRuntimeDeleteSpecs" access="private" returntype="array" output="false">
        <cfargument name="specs" type="array" required="true">
        <cfargument name="target" type="struct" required="true">
        <cfscript>
            var u = toString(toInt(readValue(arguments.target, "userId", 0)));
            var e = sqlStringLiteral(lCase(trim(toString(readValue(arguments.target, "email", "")))));
            var h = sqlStringLiteral(trim(toString(readValue(arguments.target, "hostekUserId", ""))));

            arrayAppend(arguments.specs, buildDeleteSpec("floatplan_activity_segments", "SELECT COUNT(*) AS row_count FROM floatplan_activity_segments WHERE user_id = " & u & " OR floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans) OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)", "DELETE FROM floatplan_activity_segments WHERE user_id = " & u & " OR floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans) OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)"));
            arrayAppend(arguments.specs, buildDeleteSpec("floatplan_alert_history", "SELECT COUNT(*) AS row_count FROM floatplan_alert_history WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)", "DELETE FROM floatplan_alert_history WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)"));
            arrayAppend(arguments.specs, buildDeleteSpec("floatplan_basic_details", "SELECT COUNT(*) AS row_count FROM floatplan_basic_details WHERE floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans)", "DELETE FROM floatplan_basic_details WHERE floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans)"));
            arrayAppend(arguments.specs, buildDeleteSpec("floatplan_captain_log_entries", "SELECT COUNT(*) AS row_count FROM floatplan_captain_log_entries WHERE user_id = " & u & " OR floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans) OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)", "DELETE FROM floatplan_captain_log_entries WHERE user_id = " & u & " OR floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans) OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)"));
            arrayAppend(arguments.specs, buildDeleteSpec("floatplan_companion_events", "SELECT COUNT(*) AS row_count FROM floatplan_companion_events WHERE user_id = " & u & " OR floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans) OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances) OR companion_device_id IN (SELECT companion_device_id FROM _fpw_delete_companion_devices)", "DELETE FROM floatplan_companion_events WHERE user_id = " & u & " OR floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans) OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances) OR companion_device_id IN (SELECT companion_device_id FROM _fpw_delete_companion_devices)"));
            arrayAppend(arguments.specs, buildDeleteSpec("floatplan_contacts", "SELECT COUNT(*) AS row_count FROM floatplan_contacts WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)", "DELETE FROM floatplan_contacts WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)"));
            arrayAppend(arguments.specs, buildDeleteSpec("floatplan_emailsent", "SELECT COUNT(*) AS row_count FROM floatplan_emailsent WHERE fpId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)", "DELETE FROM floatplan_emailsent WHERE fpId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)"));
            arrayAppend(arguments.specs, buildDeleteSpec("floatplan_events", "SELECT COUNT(*) AS row_count FROM floatplan_events WHERE user_id = " & u & " OR actor_user_id = " & u & " OR floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans) OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)", "DELETE FROM floatplan_events WHERE user_id = " & u & " OR actor_user_id = " & u & " OR floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans) OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)"));
            arrayAppend(arguments.specs, buildDeleteSpec("floatplan_history", "SELECT COUNT(*) AS row_count FROM floatplan_history WHERE TRIM(CAST(userId AS CHAR)) = CAST(" & u & " AS CHAR) OR floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)", "DELETE FROM floatplan_history WHERE TRIM(CAST(userId AS CHAR)) = CAST(" & u & " AS CHAR) OR floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)"));
            arrayAppend(arguments.specs, buildDeleteSpec("floatplan_monitor_events", "SELECT COUNT(*) AS row_count FROM floatplan_monitor_events WHERE user_id = " & u & " OR float_plan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans)", "DELETE FROM floatplan_monitor_events WHERE user_id = " & u & " OR float_plan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans)"));
            arrayAppend(arguments.specs, buildDeleteSpec("floatplan_monitoring", "SELECT COUNT(*) AS row_count FROM floatplan_monitoring WHERE user_id = " & u & " OR float_plan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans)", "DELETE FROM floatplan_monitoring WHERE user_id = " & u & " OR float_plan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans)"));
            arrayAppend(arguments.specs, buildDeleteSpec("floatplan_notification_log", "SELECT COUNT(*) AS row_count FROM floatplan_notification_log WHERE floatplanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)", "DELETE FROM floatplan_notification_log WHERE floatplanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)"));
            arrayAppend(arguments.specs, buildDeleteSpec("floatplan_notifications", "SELECT COUNT(*) AS row_count FROM floatplan_notifications WHERE floatplanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)", "DELETE FROM floatplan_notifications WHERE floatplanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)"));
            arrayAppend(arguments.specs, buildDeleteSpec("floatplan_operators", "SELECT COUNT(*) AS row_count FROM floatplan_operators WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)", "DELETE FROM floatplan_operators WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)"));
            arrayAppend(arguments.specs, buildDeleteSpec("floatplan_passengers", "SELECT COUNT(*) AS row_count FROM floatplan_passengers WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)", "DELETE FROM floatplan_passengers WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)"));
            arrayAppend(arguments.specs, buildDeleteSpec("floatplan_vessels", "SELECT COUNT(*) AS row_count FROM floatplan_vessels WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)", "DELETE FROM floatplan_vessels WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)"));
            arrayAppend(arguments.specs, buildDeleteSpec("floatplan_waypoints", "SELECT COUNT(*) AS row_count FROM floatplan_waypoints WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)", "DELETE FROM floatplan_waypoints WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)"));
            arrayAppend(arguments.specs, buildDeleteSpec("floatplans_sent", "SELECT COUNT(*) AS row_count FROM floatplans_sent WHERE fpId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)", "DELETE FROM floatplans_sent WHERE fpId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)"));
            arrayAppend(arguments.specs, buildDeleteSpec("floatplans_tosend", "SELECT COUNT(*) AS row_count FROM floatplans_tosend WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)", "DELETE FROM floatplans_tosend WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)"));
            arrayAppend(arguments.specs, buildDeleteSpec("fpw_email_log", "SELECT COUNT(*) AS row_count FROM fpw_email_log WHERE floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans)", "DELETE FROM fpw_email_log WHERE floatplan_id IN (SELECT floatplan_id FROM _fpw_delete_floatplans)"));
            arrayAppend(arguments.specs, buildDeleteSpec("fpw_notification_log", "SELECT COUNT(*) AS row_count FROM fpw_notification_log WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)", "DELETE FROM fpw_notification_log WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)"));
            arrayAppend(arguments.specs, buildDeleteSpec("route_instance_leg_progress", "SELECT COUNT(*) AS row_count FROM route_instance_leg_progress WHERE user_id = " & u & " OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)", "DELETE FROM route_instance_leg_progress WHERE user_id = " & u & " OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)"));
            arrayAppend(arguments.specs, buildDeleteSpec("route_instance_legs", "SELECT COUNT(*) AS row_count FROM route_instance_legs WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances) OR route_instance_section_id IN (SELECT route_instance_section_id FROM _fpw_delete_route_instance_sections)", "DELETE FROM route_instance_legs WHERE route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances) OR route_instance_section_id IN (SELECT route_instance_section_id FROM _fpw_delete_route_instance_sections)"));
            arrayAppend(arguments.specs, buildDeleteSpec("route_instance_sections", "SELECT COUNT(*) AS row_count FROM route_instance_sections WHERE id IN (SELECT route_instance_section_id FROM _fpw_delete_route_instance_sections) OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)", "DELETE FROM route_instance_sections WHERE id IN (SELECT route_instance_section_id FROM _fpw_delete_route_instance_sections) OR route_instance_id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)"));
            arrayAppend(arguments.specs, buildDeleteSpec("route_instances", "SELECT COUNT(*) AS row_count FROM route_instances WHERE id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)", "DELETE FROM route_instances WHERE id IN (SELECT route_instance_id FROM _fpw_delete_route_instances)"));
            arrayAppend(arguments.specs, buildDeleteSpec("route_leg_user_overrides", "SELECT COUNT(*) AS row_count FROM route_leg_user_overrides WHERE user_id = " & u & " OR route_id IN (SELECT user_route_id FROM _fpw_delete_user_routes)", "DELETE FROM route_leg_user_overrides WHERE user_id = " & u & " OR route_id IN (SELECT user_route_id FROM _fpw_delete_user_routes)"));
            arrayAppend(arguments.specs, buildDeleteSpec("user_route_legs", "SELECT COUNT(*) AS row_count FROM user_route_legs WHERE id IN (SELECT user_route_leg_id FROM _fpw_delete_user_route_legs)", "DELETE FROM user_route_legs WHERE id IN (SELECT user_route_leg_id FROM _fpw_delete_user_route_legs)"));
            arrayAppend(arguments.specs, buildDeleteSpec("user_route_progress", "SELECT COUNT(*) AS row_count FROM user_route_progress WHERE user_id = " & u, "DELETE FROM user_route_progress WHERE user_id = " & u));
            arrayAppend(arguments.specs, buildDeleteSpec("user_routes", "SELECT COUNT(*) AS row_count FROM user_routes WHERE id IN (SELECT user_route_id FROM _fpw_delete_user_routes)", "DELETE FROM user_routes WHERE id IN (SELECT user_route_id FROM _fpw_delete_user_routes)"));
            arrayAppend(arguments.specs, buildDeleteSpec("user_segment_overrides", "SELECT COUNT(*) AS row_count FROM user_segment_overrides WHERE user_id = " & u, "DELETE FROM user_segment_overrides WHERE user_id = " & u));
            arrayAppend(arguments.specs, buildDeleteSpec("floatplans", "SELECT COUNT(*) AS row_count FROM floatplans WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)", "DELETE FROM floatplans WHERE floatPlanId IN (SELECT floatplan_id FROM _fpw_delete_floatplans)"));
            arrayAppend(arguments.specs, buildDeleteSpec("companion_pairing_codes", "SELECT COUNT(*) AS row_count FROM companion_pairing_codes WHERE user_id = " & u & " OR used_by_device_id IN (SELECT companion_device_id FROM _fpw_delete_companion_devices)", "DELETE FROM companion_pairing_codes WHERE user_id = " & u & " OR used_by_device_id IN (SELECT companion_device_id FROM _fpw_delete_companion_devices)"));
            arrayAppend(arguments.specs, buildDeleteSpec("companion_devices", "SELECT COUNT(*) AS row_count FROM companion_devices WHERE user_id = " & u, "DELETE FROM companion_devices WHERE user_id = " & u));
            arrayAppend(arguments.specs, buildDeleteSpec("contacts", "SELECT COUNT(*) AS row_count FROM contacts WHERE TRIM(CAST(userId AS CHAR)) = CAST(" & u & " AS CHAR)", "DELETE FROM contacts WHERE TRIM(CAST(userId AS CHAR)) = CAST(" & u & " AS CHAR)"));
            arrayAppend(arguments.specs, buildDeleteSpec("operators", "SELECT COUNT(*) AS row_count FROM operators WHERE TRIM(CAST(userId AS CHAR)) = CAST(" & u & " AS CHAR)", "DELETE FROM operators WHERE TRIM(CAST(userId AS CHAR)) = CAST(" & u & " AS CHAR)"));
            arrayAppend(arguments.specs, buildDeleteSpec("passengers", "SELECT COUNT(*) AS row_count FROM passengers WHERE TRIM(CAST(userId AS CHAR)) = CAST(" & u & " AS CHAR)", "DELETE FROM passengers WHERE TRIM(CAST(userId AS CHAR)) = CAST(" & u & " AS CHAR)"));
            arrayAppend(arguments.specs, buildDeleteSpec("vessels", "SELECT COUNT(*) AS row_count FROM vessels WHERE TRIM(CAST(userId AS CHAR)) = CAST(" & u & " AS CHAR)", "DELETE FROM vessels WHERE TRIM(CAST(userId AS CHAR)) = CAST(" & u & " AS CHAR)"));
            arrayAppend(arguments.specs, buildDeleteSpec("waypoints", "SELECT COUNT(*) AS row_count FROM waypoints WHERE wpId IN (SELECT waypoint_id FROM _fpw_delete_waypoints)", "DELETE FROM waypoints WHERE wpId IN (SELECT waypoint_id FROM _fpw_delete_waypoints)"));
            arrayAppend(arguments.specs, buildDeleteSpec("stripe_webhook_events", "SELECT COUNT(DISTINCT swe.id) AS row_count FROM stripe_webhook_events swe LEFT JOIN _fpw_delete_stripe_refs sr ON ((sr.stripe_customer_id IS NOT NULL AND sr.stripe_customer_id <> '' AND swe.stripe_customer_id = sr.stripe_customer_id) OR (sr.stripe_subscription_id IS NOT NULL AND sr.stripe_subscription_id <> '' AND swe.stripe_subscription_id = sr.stripe_subscription_id) OR (sr.stripe_checkout_session_id IS NOT NULL AND sr.stripe_checkout_session_id <> '' AND swe.stripe_checkout_session_id = sr.stripe_checkout_session_id) OR (sr.stripe_payment_intent_id IS NOT NULL AND sr.stripe_payment_intent_id <> '' AND swe.stripe_payment_intent_id = sr.stripe_payment_intent_id)) WHERE swe.user_id = " & u & " OR sr.stripe_customer_id IS NOT NULL OR sr.stripe_subscription_id IS NOT NULL OR sr.stripe_checkout_session_id IS NOT NULL OR sr.stripe_payment_intent_id IS NOT NULL", "DELETE swe FROM stripe_webhook_events swe LEFT JOIN _fpw_delete_stripe_refs sr ON ((sr.stripe_customer_id IS NOT NULL AND sr.stripe_customer_id <> '' AND swe.stripe_customer_id = sr.stripe_customer_id) OR (sr.stripe_subscription_id IS NOT NULL AND sr.stripe_subscription_id <> '' AND swe.stripe_subscription_id = sr.stripe_subscription_id) OR (sr.stripe_checkout_session_id IS NOT NULL AND sr.stripe_checkout_session_id <> '' AND swe.stripe_checkout_session_id = sr.stripe_checkout_session_id) OR (sr.stripe_payment_intent_id IS NOT NULL AND sr.stripe_payment_intent_id <> '' AND swe.stripe_payment_intent_id = sr.stripe_payment_intent_id)) WHERE swe.user_id = " & u & " OR sr.stripe_customer_id IS NOT NULL OR sr.stripe_subscription_id IS NOT NULL OR sr.stripe_checkout_session_id IS NOT NULL OR sr.stripe_payment_intent_id IS NOT NULL"));
            arrayAppend(arguments.specs, buildDeleteSpec("fpw_promo_redemptions", "SELECT COUNT(*) AS row_count FROM fpw_promo_redemptions WHERE user_id = " & u, "DELETE FROM fpw_promo_redemptions WHERE user_id = " & u));
            arrayAppend(arguments.specs, buildDeleteSpec("member_entitlements", "SELECT COUNT(*) AS row_count FROM member_entitlements WHERE user_id = " & u, "DELETE FROM member_entitlements WHERE user_id = " & u));
            arrayAppend(arguments.specs, buildDeleteSpec("reset_tokens", "SELECT COUNT(*) AS row_count FROM reset_tokens WHERE LOWER(CONVERT(email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = " & e, "DELETE FROM reset_tokens WHERE LOWER(CONVERT(email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = " & e));
            arrayAppend(arguments.specs, buildDeleteSpec("email_optout", "SELECT COUNT(*) AS row_count FROM email_optout WHERE LOWER(CONVERT(email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = " & e, "DELETE FROM email_optout WHERE LOWER(CONVERT(email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = " & e));
            arrayAppend(arguments.specs, buildDeleteSpec("emails_sent", "SELECT COUNT(*) AS row_count FROM emails_sent WHERE LOWER(CONVERT(email_address USING utf8mb4)) COLLATE utf8mb4_unicode_ci = " & e, "DELETE FROM emails_sent WHERE LOWER(CONVERT(email_address USING utf8mb4)) COLLATE utf8mb4_unicode_ci = " & e));
            arrayAppend(arguments.specs, buildDeleteSpec("messages", "SELECT COUNT(*) AS row_count FROM messages WHERE LOWER(CONVERT(email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = " & e, "DELETE FROM messages WHERE LOWER(CONVERT(email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = " & e));
            arrayAppend(arguments.specs, buildDeleteSpec("fpw_early_access", "SELECT COUNT(*) AS row_count FROM fpw_early_access WHERE LOWER(CONVERT(email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = " & e, "DELETE FROM fpw_early_access WHERE LOWER(CONVERT(email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = " & e));
            arrayAppend(arguments.specs, buildDeleteSpec("users_address", "SELECT COUNT(*) AS row_count FROM users_address WHERE userId = " & u, "DELETE FROM users_address WHERE userId = " & u));
            arrayAppend(arguments.specs, buildDeleteSpec("users_hostek", "SELECT COUNT(*) AS row_count FROM users_hostek WHERE TRIM(CAST(new_userId AS CHAR)) = CAST(" & u & " AS CHAR) OR LOWER(CONVERT(hostek_email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = " & e & " OR (COALESCE(" & h & ", '') <> '' AND hostek_userId = " & h & ")", "DELETE FROM users_hostek WHERE TRIM(CAST(new_userId AS CHAR)) = CAST(" & u & " AS CHAR) OR LOWER(CONVERT(hostek_email USING utf8mb4)) COLLATE utf8mb4_unicode_ci = " & e & " OR (COALESCE(" & h & ", '') <> '' AND hostek_userId = " & h & ")"));
            arrayAppend(arguments.specs, buildDeleteSpec("users", "SELECT COUNT(*) AS row_count FROM users WHERE userId = " & u, "DELETE FROM users WHERE userId = " & u));
            return arguments.specs;
        </cfscript>
    </cffunction>

    <cffunction name="buildDeleteSpec" access="private" returntype="struct" output="false">
        <cfargument name="tableName" type="string" required="true">
        <cfargument name="countSql" type="string" required="true">
        <cfargument name="deleteSql" type="string" required="true">
        <cfscript>
            return {
                "tableName" = arguments.tableName,
                "countSql" = arguments.countSql,
                "deleteSql" = arguments.deleteSql
            };
        </cfscript>
    </cffunction>

    <cffunction name="saveAddressRow" access="private" returntype="void" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="addressData" type="any" required="true">
        <cfscript>
            var row = isStruct(arguments.addressData) ? arguments.addressData : {};
            var recId = toInt(readValue(row, "recId", 0));
            var addressVal = left(trim(toString(readValue(row, "address", ""))), 200);
            var cityVal = left(trim(toString(readValue(row, "city", ""))), 45);
            var stateVal = left(trim(toString(readValue(row, "state", ""))), 45);
            var zipVal = left(trim(toString(readValue(row, "zip", ""))), 45);
            var phoneVal = left(trim(toString(readValue(row, "phone", ""))), 45);
            var latVal = left(trim(toString(readValue(row, "lat", ""))), 45);
            var lngVal = left(trim(toString(readValue(row, "lng", ""))), 45);
            var isHomePortVal = toBoolean(readValue(row, "isHomePort", false), false) ? 1 : 0;
            var hasAnyValue = len(addressVal & cityVal & stateVal & zipVal & phoneVal & latVal & lngVal) GT 0 OR isHomePortVal EQ 1;
            var qExisting = queryNew("");

            if (recId GT 0) {
                qExisting = queryExecute(
                    "SELECT recId FROM users_address WHERE recId = :recId AND userId = :userId LIMIT 1",
                    {
                        recId = { value = recId, cfsqltype = "cf_sql_integer" },
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = getDatasource() }
                );
                if (qExisting.recordCount EQ 0) {
                    return;
                }
                queryExecute(
                    "UPDATE users_address
                     SET address = :addressVal,
                         city = :cityVal,
                         state = :stateVal,
                         zip = :zipVal,
                         phone = :phoneVal,
                         lat = :latVal,
                         lng = :lngVal,
                         isHomePort = :isHomePortVal
                     WHERE recId = :recId
                       AND userId = :userId",
                    addressParams(arguments.userId, recId, addressVal, cityVal, stateVal, zipVal, phoneVal, latVal, lngVal, isHomePortVal),
                    { datasource = getDatasource() }
                );
            } else if (hasAnyValue) {
                queryExecute(
                    "INSERT INTO users_address (userId, address, city, state, zip, phone, lat, lng, isHomePort)
                     VALUES (:userId, :addressVal, :cityVal, :stateVal, :zipVal, :phoneVal, :latVal, :lngVal, :isHomePortVal)",
                    addressParams(arguments.userId, 0, addressVal, cityVal, stateVal, zipVal, phoneVal, latVal, lngVal, isHomePortVal),
                    { datasource = getDatasource() }
                );
            }
        </cfscript>
    </cffunction>

    <cffunction name="addressParams" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="recId" type="numeric" required="true">
        <cfargument name="addressVal" type="string" required="true">
        <cfargument name="cityVal" type="string" required="true">
        <cfargument name="stateVal" type="string" required="true">
        <cfargument name="zipVal" type="string" required="true">
        <cfargument name="phoneVal" type="string" required="true">
        <cfargument name="latVal" type="string" required="true">
        <cfargument name="lngVal" type="string" required="true">
        <cfargument name="isHomePortVal" type="numeric" required="true">
        <cfscript>
            return {
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                recId = { value = arguments.recId, cfsqltype = "cf_sql_integer" },
                addressVal = { value = arguments.addressVal, cfsqltype = "cf_sql_varchar" },
                cityVal = { value = arguments.cityVal, cfsqltype = "cf_sql_varchar" },
                stateVal = { value = arguments.stateVal, cfsqltype = "cf_sql_varchar" },
                zipVal = { value = arguments.zipVal, cfsqltype = "cf_sql_varchar" },
                phoneVal = { value = arguments.phoneVal, cfsqltype = "cf_sql_varchar" },
                latVal = { value = arguments.latVal, cfsqltype = "cf_sql_varchar" },
                lngVal = { value = arguments.lngVal, cfsqltype = "cf_sql_varchar" },
                isHomePortVal = { value = arguments.isHomePortVal, cfsqltype = "cf_sql_tinyint" }
            };
        </cfscript>
    </cffunction>

    <cffunction name="normalizeUserListRow" access="private" returntype="struct" output="false">
        <cfargument name="q" type="query" required="true">
        <cfargument name="idx" type="numeric" required="true">
        <cfscript>
            return {
                "userId" = val(arguments.q.userId[arguments.idx]),
                "firstName" = safeQueryString(arguments.q, "fName", arguments.idx),
                "lastName" = safeQueryString(arguments.q, "lName", arguments.idx),
                "email" = safeQueryString(arguments.q, "email", arguments.idx),
                "mobilePhone" = safeQueryString(arguments.q, "mobilePhone", arguments.idx),
                "hostekUserId" = safeQueryString(arguments.q, "hostek_userId", arguments.idx),
                "created" = safeQueryString(arguments.q, "created", arguments.idx),
                "lastLogin" = safeQueryString(arguments.q, "lastLogin", arguments.idx),
                "lastUpdate" = safeQueryString(arguments.q, "lastUpdate", arguments.idx),
                "addressPhones" = safeQueryString(arguments.q, "address_phones", arguments.idx),
                "addressCount" = val(arguments.q.address_count[arguments.idx])
            };
        </cfscript>
    </cffunction>

    <cffunction name="normalizeUserDetailRow" access="private" returntype="struct" output="false">
        <cfargument name="q" type="query" required="true">
        <cfargument name="idx" type="numeric" required="true">
        <cfscript>
            return {
                "userId" = val(arguments.q.userId[arguments.idx]),
                "firstName" = safeQueryString(arguments.q, "fName", arguments.idx),
                "lastName" = safeQueryString(arguments.q, "lName", arguments.idx),
                "email" = safeQueryString(arguments.q, "email", arguments.idx),
                "mobilePhone" = safeQueryString(arguments.q, "mobilePhone", arguments.idx),
                "hostekUserId" = safeQueryString(arguments.q, "hostek_userId", arguments.idx),
                "created" = safeQueryString(arguments.q, "created", arguments.idx),
                "lastLogin" = safeQueryString(arguments.q, "lastLogin", arguments.idx),
                "lastUpdate" = safeQueryString(arguments.q, "lastUpdate", arguments.idx),
                "photoFileId" = safeQueryString(arguments.q, "photoFileId", arguments.idx),
                "requestReset" = safeQueryString(arguments.q, "requestReset", arguments.idx),
                "resetId" = safeQueryString(arguments.q, "resetId", arguments.idx),
                "passwordCreated" = safeQueryString(arguments.q, "passwordCreated", arguments.idx),
                "hasPassword" = val(arguments.q.has_password[arguments.idx])
            };
        </cfscript>
    </cffunction>

    <cffunction name="normalizeAddressRow" access="private" returntype="struct" output="false">
        <cfargument name="q" type="query" required="true">
        <cfargument name="idx" type="numeric" required="true">
        <cfscript>
            return {
                "recId" = val(arguments.q.recId[arguments.idx]),
                "userId" = val(arguments.q.userId[arguments.idx]),
                "address" = safeQueryString(arguments.q, "address", arguments.idx),
                "city" = safeQueryString(arguments.q, "city", arguments.idx),
                "state" = safeQueryString(arguments.q, "state", arguments.idx),
                "zip" = safeQueryString(arguments.q, "zip", arguments.idx),
                "phone" = safeQueryString(arguments.q, "phone", arguments.idx),
                "lat" = safeQueryString(arguments.q, "lat", arguments.idx),
                "lng" = safeQueryString(arguments.q, "lng", arguments.idx),
                "isHomePort" = val(arguments.q.isHomePort[arguments.idx])
            };
        </cfscript>
    </cffunction>

    <cffunction name="safeQueryString" access="private" returntype="string" output="false">
        <cfargument name="q" type="query" required="true">
        <cfargument name="columnName" type="string" required="true">
        <cfargument name="idx" type="numeric" required="true">
        <cfscript>
            if (!listFindNoCase(arguments.q.columnList, arguments.columnName)) {
                return "";
            }
            if (isNull(arguments.q[arguments.columnName][arguments.idx])) {
                return "";
            }
            return toString(arguments.q[arguments.columnName][arguments.idx]);
        </cfscript>
    </cffunction>

    <cffunction name="sqlStringLiteral" access="private" returntype="string" output="false">
        <cfargument name="value" type="string" required="true">
        <cfscript>
            return "'" & replace(arguments.value, "'", "''", "all") & "'";
        </cfscript>
    </cffunction>

    <cffunction name="execSql" access="private" returntype="void" output="false">
        <cfargument name="sqlText" type="string" required="true">
        <cfargument name="params" type="struct" required="false" default="#structNew()#">
        <cfscript>
            queryExecute(arguments.sqlText, arguments.params, { datasource = getDatasource() });
        </cfscript>
    </cffunction>

    <cffunction name="tableExists" access="private" returntype="boolean" output="false">
        <cfargument name="tableName" type="string" required="true">
        <cfscript>
            var q = queryExecute(
                "SELECT COUNT(*) AS table_count
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE()
                   AND table_name = :tableName",
                { tableName = { value = arguments.tableName, cfsqltype = "cf_sql_varchar" } },
                { datasource = getDatasource() }
            );
            return q.recordCount GT 0 AND val(q["table_count"][1]) GT 0;
        </cfscript>
    </cffunction>

    <cffunction name="isMissingTableError" access="private" returntype="boolean" output="false">
        <cfargument name="err" type="any" required="true">
        <cfscript>
            var messageText = "";
            if (isStruct(arguments.err)) {
                if (structKeyExists(arguments.err, "message")) {
                    messageText &= " " & toString(arguments.err.message);
                }
                if (structKeyExists(arguments.err, "detail")) {
                    messageText &= " " & toString(arguments.err.detail);
                }
                if (structKeyExists(arguments.err, "sqlstate")) {
                    messageText &= " " & toString(arguments.err.sqlstate);
                }
            } else {
                messageText = toString(arguments.err);
            }
            messageText = lCase(messageText);
            return find("doesn't exist", messageText)
                OR find("does not exist", messageText)
                OR find("unknown table", messageText)
                OR find("base table or view not found", messageText);
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

    <!--- Authorization is enforced centrally by Application.cfc. --->

    <cffunction name="getDatasource" access="private" returntype="string" output="false">
        <cfscript>
            if (structKeyExists(application, "dsn") AND len(trim(toString(application.dsn)))) {
                return toString(application.dsn);
            }
            if (structKeyExists(application, "DSN") AND len(trim(toString(application.DSN)))) {
                return toString(application.DSN);
            }
            return "fpw";
        </cfscript>
    </cffunction>

</cfcomponent>



