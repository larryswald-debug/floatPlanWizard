<cfcomponent output="false" hint="Admin vessel management API.">

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
                        response = listVessels(body);
                        break;
                    case "get":
                        response = getVessel(body);
                        break;
                    case "save":
                        response = saveVessel(body);
                        break;
                    case "delete":
                        response = deleteVessel(body);
                        break;
                    case "batchdelete":
                        response = batchDeleteVessels(body);
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

    <cffunction name="listVessels" access="private" returntype="struct" output="false">
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
                arrayAppend(whereParts, "CAST(v.userId AS CHAR) = :userIdFilter");
                params.userIdFilter = { value = userIdFilter, cfsqltype = "cf_sql_varchar" };
            }

            if (len(emailFilter)) {
                arrayAppend(whereParts, "LOWER(COALESCE(u.email, '')) LIKE :emailLike");
                params.emailLike = { value = "%" & emailFilter & "%", cfsqltype = "cf_sql_varchar" };
            }

            if (len(searchFilter)) {
                arrayAppend(whereParts, "(
                    LOWER(COALESCE(v.vesselName, '')) LIKE :searchLike
                    OR LOWER(COALESCE(v.registration, '')) LIKE :searchLike
                    OR LOWER(COALESCE(v.typeOfVessel, '')) LIKE :searchLike
                    OR LOWER(COALESCE(v.make, '')) LIKE :searchLike
                    OR LOWER(COALESCE(v.model, '')) LIKE :searchLike
                    OR LOWER(COALESCE(v.lengthOfVessel, '')) LIKE :searchLike
                    OR LOWER(COALESCE(v.hullColor, '')) LIKE :searchLike
                    OR LOWER(COALESCE(v.hailingPort, '')) LIKE :searchLike
                    OR CAST(v.vesselID AS CHAR) LIKE :searchLike
                )");
                params.searchLike = { value = "%" & searchFilter & "%", cfsqltype = "cf_sql_varchar" };
            }

            sqlWhere = arrayToList(whereParts, " AND ");

            listSql = "
                SELECT
                    v.vesselID,
                    v.userId,
                    v.vesselName,
                    v.registration,
                    v.typeOfVessel,
                    v.make,
                    v.model,
                    v.lengthOfVessel,
                    v.max_speed,
                    v.most_efficient_speed,
                    v.gallons_per_hour,
                    v.gph_at_max_speed,
                    v.fuel_capacity,
                    v.isDefaultVessel,
                    v.hullColor,
                    v.hailingPort,
                    u.email,
                    u.fName,
                    u.lName,
                    COALESCE(usageAgg.usage_count, 0) AS usage_count
                FROM vessels v
                LEFT JOIN users u
                    ON u.userId = v.userId
                LEFT JOIN (
                    SELECT vesselId, userId, COUNT(*) AS usage_count
                    FROM floatplans
                    GROUP BY vesselId, userId
                ) usageAgg
                    ON usageAgg.vesselId = v.vesselID
                   AND CAST(usageAgg.userId AS CHAR) = CAST(v.userId AS CHAR)
                WHERE #sqlWhere#
                ORDER BY v.vesselID DESC
                LIMIT :pageLimit
                OFFSET :pageOffset";

            countSql = "
                SELECT COUNT(*) AS total_count
                FROM vessels v
                LEFT JOIN users u
                    ON u.userId = v.userId
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
                arrayAppend(rows, normalizeVesselRow(qRows, i));
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

    <cffunction name="getVessel" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var vesselId = toInt(readValue(arguments.body, "vesselId", readValue(arguments.body, "VESSELID", readValue(url, "vesselId", 0))));
            var qRow = queryNew("");

            if (vesselId LTE 0) {
                return buildResponse(false, true, "Invalid vessel", {}, "vesselId is required.");
            }

            qRow = loadVesselQuery(vesselId);
            if (qRow.recordCount EQ 0) {
                return buildResponse(false, true, "Not found", {}, "Vessel not found.");
            }

            return buildResponse(true, true, "OK", {
                "vessel" = normalizeVesselRow(qRow, 1)
            });
        </cfscript>
    </cffunction>

    <cffunction name="saveVessel" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var payload = {};
            var vesselId = 0;
            var userIdTxt = "";
            var vesselName = "";
            var registration = "";
            var vesselType = "";
            var makeVal = "";
            var modelVal = "";
            var lengthVal = "";
            var maxSpeedRaw = "";
            var mostEfficientSpeedRaw = "";
            var gallonsPerHourRaw = "";
            var gphAtMaxSpeedRaw = "";
            var fuelCapacityRaw = "";
            var colorVal = "";
            var homePortVal = "";
            var isDefaultVessel = 1;
            var existing = queryNew("");
            var qSaved = queryNew("");
            var qInsertId = queryNew("");
            var hasMaxSpeed = false;
            var hasMostEfficientSpeed = false;
            var hasGallonsPerHour = false;
            var hasGphAtMaxSpeed = false;
            var hasFuelCapacity = false;

            if (structKeyExists(arguments.body, "vessel") AND isStruct(arguments.body.vessel)) {
                payload = arguments.body.vessel;
            } else if (structKeyExists(arguments.body, "VESSEL") AND isStruct(arguments.body.VESSEL)) {
                payload = arguments.body.VESSEL;
            } else {
                payload = arguments.body;
            }

            vesselId = toInt(readValue(payload, "vesselId", readValue(payload, "VESSELID", 0)));
            userIdTxt = trim(toString(readValue(payload, "userId", readValue(payload, "USERID", ""))));
            vesselName = trim(toString(readValue(payload, "vesselName", readValue(payload, "VESSELNAME", ""))));
            registration = trim(toString(readValue(payload, "registration", readValue(payload, "REGISTRATION", ""))));
            vesselType = trim(toString(readValue(payload, "typeOfVessel", readValue(payload, "TYPE", readValue(payload, "type", "")))));
            makeVal = trim(toString(readValue(payload, "make", readValue(payload, "MAKE", ""))));
            modelVal = trim(toString(readValue(payload, "model", readValue(payload, "MODEL", ""))));
            lengthVal = trim(toString(readValue(payload, "lengthOfVessel", readValue(payload, "LENGTH", readValue(payload, "length", "")))));
            maxSpeedRaw = trim(toString(readValue(payload, "max_speed", readValue(payload, "MAX_SPEED", readValue(payload, "maxSpeed", "")))));
            mostEfficientSpeedRaw = trim(toString(readValue(payload, "most_efficient_speed", readValue(payload, "MOST_EFFICIENT_SPEED", readValue(payload, "mostEfficientSpeed", "")))));
            gallonsPerHourRaw = trim(toString(readValue(payload, "gallons_per_hour", readValue(payload, "GALLONS_PER_HOUR", readValue(payload, "gallonsPerHour", "")))));
            gphAtMaxSpeedRaw = trim(toString(readValue(payload, "gph_at_max_speed", readValue(payload, "GPH_AT_MAX_SPEED", readValue(payload, "gphAtMaxSpeed", "")))));
            fuelCapacityRaw = trim(toString(readValue(payload, "fuel_capacity", readValue(payload, "FUEL_CAPACITY", readValue(payload, "fuelCapacity", "")))));
            colorVal = trim(toString(readValue(payload, "hullColor", readValue(payload, "COLOR", readValue(payload, "color", "")))));
            homePortVal = trim(toString(readValue(payload, "hailingPort", readValue(payload, "HOMEPORT", readValue(payload, "homePort", "")))));
            isDefaultVessel = toBoolean(readValue(payload, "isDefaultVessel", readValue(payload, "ISDEFAULTVESSEL", 1)), true) ? 1 : 0;

            hasMaxSpeed = len(maxSpeedRaw);
            hasMostEfficientSpeed = len(mostEfficientSpeedRaw);
            hasGallonsPerHour = len(gallonsPerHourRaw);
            hasGphAtMaxSpeed = len(gphAtMaxSpeedRaw);
            hasFuelCapacity = len(fuelCapacityRaw);

            if (!len(vesselName)) {
                return buildResponse(false, true, "Validation failed", {}, "Vessel name is required.");
            }
            if (!len(vesselType)) {
                return buildResponse(false, true, "Validation failed", {}, "Vessel type is required.");
            }
            if (!len(lengthVal)) {
                return buildResponse(false, true, "Validation failed", {}, "Length of vessel is required.");
            }
            if (!len(colorVal)) {
                return buildResponse(false, true, "Validation failed", {}, "Hull color is required.");
            }
            if (hasMaxSpeed AND !isNumeric(maxSpeedRaw)) {
                return buildResponse(false, true, "Validation failed", {}, "Max speed must be numeric.");
            }
            if (hasMostEfficientSpeed AND !isNumeric(mostEfficientSpeedRaw)) {
                return buildResponse(false, true, "Validation failed", {}, "Most efficient speed must be numeric.");
            }
            if (hasGallonsPerHour AND !isNumeric(gallonsPerHourRaw)) {
                return buildResponse(false, true, "Validation failed", {}, "Gallons per hour must be numeric.");
            }
            if (hasGphAtMaxSpeed AND !isNumeric(gphAtMaxSpeedRaw)) {
                return buildResponse(false, true, "Validation failed", {}, "GPH at max speed must be numeric.");
            }
            if (hasFuelCapacity AND !isNumeric(fuelCapacityRaw)) {
                return buildResponse(false, true, "Validation failed", {}, "Fuel capacity must be numeric.");
            }

            if (vesselId GT 0) {
                existing = queryExecute(
                    "SELECT vesselID, userId
                     FROM vessels
                     WHERE vesselID = :vesselId
                     LIMIT 1",
                    {
                        vesselId = { value = vesselId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = getDatasource() }
                );
                if (existing.recordCount EQ 0) {
                    return buildResponse(false, true, "Not found", {}, "Vessel not found.");
                }
                userIdTxt = trim(toString(existing.userId[1]));
            } else {
                if (!isNumeric(userIdTxt) OR val(userIdTxt) LTE 0) {
                    return buildResponse(false, true, "Validation failed", {}, "userId is required when creating a vessel.");
                }
            }

            if (isDefaultVessel EQ 1) {
                if (vesselId GT 0) {
                    queryExecute(
                        "UPDATE vessels
                         SET isDefaultVessel = :defaultZero
                         WHERE userId = :userId
                           AND vesselID <> :vesselId",
                        {
                            defaultZero = { value = 0, cfsqltype = "cf_sql_tinyint" },
                            userId = { value = userIdTxt, cfsqltype = "cf_sql_varchar" },
                            vesselId = { value = vesselId, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = getDatasource() }
                    );
                } else {
                    queryExecute(
                        "UPDATE vessels
                         SET isDefaultVessel = :defaultZero
                         WHERE userId = :userId",
                        {
                            defaultZero = { value = 0, cfsqltype = "cf_sql_tinyint" },
                            userId = { value = userIdTxt, cfsqltype = "cf_sql_varchar" }
                        },
                        { datasource = getDatasource() }
                    );
                }
            }

            if (vesselId GT 0) {
                queryExecute(
                    "UPDATE vessels
                     SET vesselName = :vesselName,
                         registration = :registration,
                         typeOfVessel = :typeOfVessel,
                         make = :makeVal,
                         model = :modelVal,
                         lengthOfVessel = :lengthVal,
                         max_speed = :maxSpeed,
                         most_efficient_speed = :mostEfficientSpeed,
                         gallons_per_hour = :gallonsPerHour,
                         gph_at_max_speed = :gphAtMaxSpeed,
                         fuel_capacity = :fuelCapacity,
                         isDefaultVessel = :isDefaultVessel,
                         hullColor = :hullColor,
                         hailingPort = :hailingPort
                     WHERE vesselID = :vesselId",
                    {
                        vesselName = { value = vesselName, cfsqltype = "cf_sql_varchar" },
                        registration = { value = registration, cfsqltype = "cf_sql_varchar" },
                        typeOfVessel = { value = vesselType, cfsqltype = "cf_sql_varchar" },
                        makeVal = { value = makeVal, cfsqltype = "cf_sql_varchar" },
                        modelVal = { value = modelVal, cfsqltype = "cf_sql_varchar" },
                        lengthVal = { value = lengthVal, cfsqltype = "cf_sql_varchar" },
                        maxSpeed = { value = (hasMaxSpeed ? val(maxSpeedRaw) : 0), cfsqltype = "cf_sql_decimal", null = (!hasMaxSpeed), scale = 2, maxlength = 6 },
                        mostEfficientSpeed = { value = (hasMostEfficientSpeed ? val(mostEfficientSpeedRaw) : 0), cfsqltype = "cf_sql_decimal", null = (!hasMostEfficientSpeed), scale = 2, maxlength = 6 },
                        gallonsPerHour = { value = (hasGallonsPerHour ? val(gallonsPerHourRaw) : 0), cfsqltype = "cf_sql_decimal", null = (!hasGallonsPerHour), scale = 2, maxlength = 8 },
                        gphAtMaxSpeed = { value = (hasGphAtMaxSpeed ? val(gphAtMaxSpeedRaw) : 0), cfsqltype = "cf_sql_decimal", null = (!hasGphAtMaxSpeed), scale = 2, maxlength = 8 },
                        fuelCapacity = { value = (hasFuelCapacity ? val(fuelCapacityRaw) : 0), cfsqltype = "cf_sql_decimal", null = (!hasFuelCapacity), scale = 2, maxlength = 10 },
                        isDefaultVessel = { value = isDefaultVessel, cfsqltype = "cf_sql_tinyint" },
                        hullColor = { value = colorVal, cfsqltype = "cf_sql_varchar" },
                        hailingPort = { value = homePortVal, cfsqltype = "cf_sql_varchar" },
                        vesselId = { value = vesselId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = getDatasource() }
                );
            } else {
                queryExecute(
                    "INSERT INTO vessels (
                        userId,
                        vesselName,
                        registration,
                        typeOfVessel,
                        make,
                        model,
                        lengthOfVessel,
                        max_speed,
                        most_efficient_speed,
                        gallons_per_hour,
                        gph_at_max_speed,
                        fuel_capacity,
                        isDefaultVessel,
                        hullColor,
                        hailingPort
                     ) VALUES (
                        :userId,
                        :vesselName,
                        :registration,
                        :typeOfVessel,
                        :makeVal,
                        :modelVal,
                        :lengthVal,
                        :maxSpeed,
                        :mostEfficientSpeed,
                        :gallonsPerHour,
                        :gphAtMaxSpeed,
                        :fuelCapacity,
                        :isDefaultVessel,
                        :hullColor,
                        :hailingPort
                     )",
                    {
                        userId = { value = userIdTxt, cfsqltype = "cf_sql_varchar" },
                        vesselName = { value = vesselName, cfsqltype = "cf_sql_varchar" },
                        registration = { value = registration, cfsqltype = "cf_sql_varchar" },
                        typeOfVessel = { value = vesselType, cfsqltype = "cf_sql_varchar" },
                        makeVal = { value = makeVal, cfsqltype = "cf_sql_varchar" },
                        modelVal = { value = modelVal, cfsqltype = "cf_sql_varchar" },
                        lengthVal = { value = lengthVal, cfsqltype = "cf_sql_varchar" },
                        maxSpeed = { value = (hasMaxSpeed ? val(maxSpeedRaw) : 0), cfsqltype = "cf_sql_decimal", null = (!hasMaxSpeed), scale = 2, maxlength = 6 },
                        mostEfficientSpeed = { value = (hasMostEfficientSpeed ? val(mostEfficientSpeedRaw) : 0), cfsqltype = "cf_sql_decimal", null = (!hasMostEfficientSpeed), scale = 2, maxlength = 6 },
                        gallonsPerHour = { value = (hasGallonsPerHour ? val(gallonsPerHourRaw) : 0), cfsqltype = "cf_sql_decimal", null = (!hasGallonsPerHour), scale = 2, maxlength = 8 },
                        gphAtMaxSpeed = { value = (hasGphAtMaxSpeed ? val(gphAtMaxSpeedRaw) : 0), cfsqltype = "cf_sql_decimal", null = (!hasGphAtMaxSpeed), scale = 2, maxlength = 8 },
                        fuelCapacity = { value = (hasFuelCapacity ? val(fuelCapacityRaw) : 0), cfsqltype = "cf_sql_decimal", null = (!hasFuelCapacity), scale = 2, maxlength = 10 },
                        isDefaultVessel = { value = isDefaultVessel, cfsqltype = "cf_sql_tinyint" },
                        hullColor = { value = colorVal, cfsqltype = "cf_sql_varchar" },
                        hailingPort = { value = homePortVal, cfsqltype = "cf_sql_varchar" }
                    },
                    { datasource = getDatasource() }
                );

                qInsertId = queryExecute(
                    "SELECT LAST_INSERT_ID() AS new_id",
                    {},
                    { datasource = getDatasource() }
                );
                if (qInsertId.recordCount GT 0 AND isNumeric(qInsertId.new_id[1])) {
                    vesselId = toInt(qInsertId.new_id[1]);
                }
                if (vesselId LTE 0) {
                    return buildResponse(false, true, "Insert failed", {}, "Vessel created but id could not be resolved.");
                }
            }

            qSaved = loadVesselQuery(vesselId);
            return buildResponse(true, true, "Vessel saved", {
                "vesselId" = vesselId,
                "vessel" = (qSaved.recordCount GT 0 ? normalizeVesselRow(qSaved, 1) : {})
            });
        </cfscript>
    </cffunction>

    <cffunction name="deleteVessel" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var vesselId = toInt(readValue(arguments.body, "vesselId", readValue(arguments.body, "VESSELID", readValue(url, "vesselId", 0))));
            var result = {};

            if (vesselId LTE 0) {
                return buildResponse(false, true, "Invalid vessel", {}, "vesselId is required.");
            }

            result = deleteVesselById(vesselId);
            if (!result.success) {
                return buildResponse(false, true, "Delete failed", result, result.message);
            }

            return buildResponse(true, true, "Vessel deleted", result);
        </cfscript>
    </cffunction>

    <cffunction name="batchDeleteVessels" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var rawIds = readValue(arguments.body, "vesselIds", readValue(arguments.body, "ids", []));
            var ids = normalizeIdArray(rawIds);
            var item = 0;
            var perItem = [];
            var one = {};
            var deletedCount = 0;
            var failedCount = 0;
            var blockedCount = 0;
            var overallOk = false;

            if (!arrayLen(ids)) {
                return buildResponse(false, true, "Validation failed", {}, "vesselIds must be a non-empty array.");
            }

            for (item in ids) {
                one = deleteVesselById(item);
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
            }, (overallOk ? "" : "One or more vessels could not be deleted."));
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
                    COUNT(v.vesselID) AS vessel_count
                FROM users u
                LEFT JOIN vessels v
                    ON v.userId = u.userId
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
                ORDER BY vessel_count DESC, u.userId DESC
                LIMIT :limitVal";
            params.limitVal = { value = limitVal, cfsqltype = "cf_sql_integer" };

            qUsers = queryExecute(sql, params, { datasource = getDatasource() });
            for (i = 1; i LTE qUsers.recordCount; i++) {
                arrayAppend(rows, {
                    "userId" = val(qUsers.userId[i]),
                    "email" = (isNull(qUsers.email[i]) ? "" : toString(qUsers.email[i])),
                    "firstName" = (isNull(qUsers.fName[i]) ? "" : toString(qUsers.fName[i])),
                    "lastName" = (isNull(qUsers.lName[i]) ? "" : toString(qUsers.lName[i])),
                    "vesselCount" = val(qUsers.vessel_count[i])
                });
            }

            return buildResponse(true, true, "OK", {
                "users" = rows,
                "limit" = limitVal,
                "search" = searchFilter
            });
        </cfscript>
    </cffunction>

    <cffunction name="deleteVesselById" access="private" returntype="struct" output="false">
        <cfargument name="vesselId" type="numeric" required="true">
        <cfscript>
            var qRow = queryNew("");
            var qUsage = queryNew("");
            var usageCount = 0;
            var vesselNameVal = "";
            var userIdTxt = "";
            var planLabels = [];
            var outcome = {
                "vesselId" = arguments.vesselId,
                "vesselName" = "",
                "success" = false,
                "errorCode" = "",
                "message" = "",
                "usageCount" = 0
            };

            if (arguments.vesselId LTE 0) {
                outcome.errorCode = "INVALID_ID";
                outcome.message = "vesselId is required.";
                return outcome;
            }

            qRow = queryExecute(
                "SELECT vesselID, userId, vesselName
                 FROM vessels
                 WHERE vesselID = :vesselId
                 LIMIT 1",
                {
                    vesselId = { value = arguments.vesselId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = getDatasource() }
            );

            if (qRow.recordCount EQ 0) {
                outcome.errorCode = "NOT_FOUND";
                outcome.message = "Vessel not found.";
                return outcome;
            }

            vesselNameVal = (isNull(qRow.vesselName[1]) ? "" : toString(qRow.vesselName[1]));
            userIdTxt = (isNull(qRow.userId[1]) ? "" : toString(qRow.userId[1]));
            outcome.vesselName = vesselNameVal;

            qUsage = queryExecute(
                "SELECT floatPlanId, floatPlanName
                 FROM floatplans
                 WHERE vesselId = :vesselId
                   AND userId = :userId
                 ORDER BY floatPlanId ASC",
                {
                    vesselId = { value = arguments.vesselId, cfsqltype = "cf_sql_integer" },
                    userId = { value = userIdTxt, cfsqltype = "cf_sql_varchar" }
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
                outcome.message = "This vessel is used in " & usageCount & " float plan(s): " & arrayToList(planLabels, ", ") & ". Edit the float plan to remove it before deleting.";
                return outcome;
            }

            queryExecute(
                "DELETE FROM vessels
                 WHERE vesselID = :vesselId
                   AND userId = :userId",
                {
                    vesselId = { value = arguments.vesselId, cfsqltype = "cf_sql_integer" },
                    userId = { value = userIdTxt, cfsqltype = "cf_sql_varchar" }
                },
                { datasource = getDatasource() }
            );
            getVesselImageService().deleteVesselImageFiles(arguments.vesselId, val(userIdTxt));

            outcome.success = true;
            outcome.message = "Vessel deleted.";
            return outcome;
        </cfscript>
    </cffunction>

    <cffunction name="loadVesselQuery" access="private" returntype="query" output="false">
        <cfargument name="vesselId" type="numeric" required="true">
        <cfscript>
            return queryExecute(
                "SELECT
                    v.vesselID,
                    v.userId,
                    v.vesselName,
                    v.registration,
                    v.typeOfVessel,
                    v.make,
                    v.model,
                    v.lengthOfVessel,
                    v.max_speed,
                    v.most_efficient_speed,
                    v.gallons_per_hour,
                    v.gph_at_max_speed,
                    v.fuel_capacity,
                    v.isDefaultVessel,
                    v.hullColor,
                    v.hailingPort,
                    u.email,
                    u.fName,
                    u.lName,
                    COALESCE(usageAgg.usage_count, 0) AS usage_count
                 FROM vessels v
                 LEFT JOIN users u
                    ON u.userId = v.userId
                 LEFT JOIN (
                    SELECT vesselId, userId, COUNT(*) AS usage_count
                    FROM floatplans
                    GROUP BY vesselId, userId
                 ) usageAgg
                    ON usageAgg.vesselId = v.vesselID
                   AND CAST(usageAgg.userId AS CHAR) = CAST(v.userId AS CHAR)
                 WHERE v.vesselID = :vesselId
                 LIMIT 1",
                {
                    vesselId = { value = arguments.vesselId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = getDatasource() }
            );
        </cfscript>
    </cffunction>

    <cffunction name="normalizeVesselRow" access="private" returntype="struct" output="false">
        <cfargument name="q" type="query" required="true">
        <cfargument name="idx" type="numeric" required="true">
        <cfscript>
            return {
                "VESSELID" = val(arguments.q.vesselID[arguments.idx]),
                "USERID" = (isNull(arguments.q.userId[arguments.idx]) ? "" : toString(arguments.q.userId[arguments.idx])),
                "VESSELNAME" = (isNull(arguments.q.vesselName[arguments.idx]) ? "" : toString(arguments.q.vesselName[arguments.idx])),
                "REGISTRATION" = (isNull(arguments.q.registration[arguments.idx]) ? "" : toString(arguments.q.registration[arguments.idx])),
                "TYPE" = (isNull(arguments.q.typeOfVessel[arguments.idx]) ? "" : toString(arguments.q.typeOfVessel[arguments.idx])),
                "MAKE" = (isNull(arguments.q.make[arguments.idx]) ? "" : toString(arguments.q.make[arguments.idx])),
                "MODEL" = (isNull(arguments.q.model[arguments.idx]) ? "" : toString(arguments.q.model[arguments.idx])),
                "LENGTH" = (isNull(arguments.q.lengthOfVessel[arguments.idx]) ? "" : toString(arguments.q.lengthOfVessel[arguments.idx])),
                "MAX_SPEED" = (isNull(arguments.q.max_speed[arguments.idx]) ? "" : toString(arguments.q.max_speed[arguments.idx])),
                "MOST_EFFICIENT_SPEED" = (isNull(arguments.q.most_efficient_speed[arguments.idx]) ? "" : toString(arguments.q.most_efficient_speed[arguments.idx])),
                "GALLONS_PER_HOUR" = (isNull(arguments.q.gallons_per_hour[arguments.idx]) ? "" : toString(arguments.q.gallons_per_hour[arguments.idx])),
                "GPH_AT_MAX_SPEED" = (isNull(arguments.q.gph_at_max_speed[arguments.idx]) ? "" : toString(arguments.q.gph_at_max_speed[arguments.idx])),
                "FUEL_CAPACITY" = (isNull(arguments.q.fuel_capacity[arguments.idx]) ? "" : toString(arguments.q.fuel_capacity[arguments.idx])),
                "ISDEFAULTVESSEL" = toBoolean((isNull(arguments.q.isDefaultVessel[arguments.idx]) ? "" : toString(arguments.q.isDefaultVessel[arguments.idx])), true),
                "COLOR" = (isNull(arguments.q.hullColor[arguments.idx]) ? "" : toString(arguments.q.hullColor[arguments.idx])),
                "HOMEPORT" = (isNull(arguments.q.hailingPort[arguments.idx]) ? "" : toString(arguments.q.hailingPort[arguments.idx])),
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

    <cffunction name="getVesselImageService" access="private" returntype="any" output="false">
        <cftry>
            <cfreturn createObject("component", "fpw.api.v1.VesselImageService").init(getDatasource())>
            <cfcatch>
                <cfreturn createObject("component", "api.v1.VesselImageService").init(getDatasource())>
            </cfcatch>
        </cftry>
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



