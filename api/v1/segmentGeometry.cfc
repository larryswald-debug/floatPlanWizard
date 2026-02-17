<cfcomponent output="false" hint="Canonical segment geometry API for loop_segments.">

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
                var segmentId = 0;

                if (!structCount(userStruct)) {
                    response = buildResponse(
                        false,
                        false,
                        "Unauthorized",
                        {},
                        "No logged-in user session.",
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
                        "Admin privileges required.",
                        "User is authenticated but not authorized for segment geometry tools."
                    );
                    writeOutput(serializeJSON(response));
                    return;
                }

                switch (actionName) {
                    case "listsegments":
                        response = listSegments();
                        break;

                    case "getactivegeometry":
                        segmentId = toInt(readValue(body, "segmentId", readValue(body, "segment_id", 0)));
                        response = getActiveGeometry(segmentId);
                        break;

                    case "savegeometry":
                        response = saveGeometry(body, userStruct);
                        break;

                    default:
                        response = buildResponse(
                            false,
                            true,
                            "Unknown action",
                            {},
                            "Unsupported action.",
                            "Valid actions: listSegments, getActiveGeometry, saveGeometry."
                        );
                }

                writeOutput(serializeJSON(response));
            </cfscript>

            <cfcatch type="any">
                <cfset var errAuth = structKeyExists(session, "user") AND isStruct(session.user)>
                <cfoutput>#serializeJSON(buildResponse(false, errAuth, "Application error", {}, cfcatch.message, cfcatch.detail))#</cfoutput>
            </cfcatch>
        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

    <cffunction name="listSegments" access="private" returntype="struct" output="false">
        <cfscript>
            var qSegments = queryExecute(
                "SELECT
                    s.id,
                    s.section_id,
                    s.order_index,
                    s.start_name,
                    s.end_name,
                    s.dist_nm,
                    s.dist_nm_calc,
                    s.active_geom_version,
                    sec.order_index AS section_order
                 FROM loop_segments s
                 LEFT JOIN loop_sections sec ON sec.id = s.section_id
                 ORDER BY COALESCE(sec.order_index, 2147483647) ASC,
                          COALESCE(s.order_index, 2147483647) ASC,
                          s.id ASC",
                {},
                { datasource = Application.dsn }
            );
            var rows = [];
            var i = 0;

            for (i = 1; i LTE qSegments.recordCount; i++) {
                arrayAppend(rows, {
                    "id" = val(qSegments.id[i]),
                    "section_id" = (isNull(qSegments.section_id[i]) ? javacast("null", "") : val(qSegments.section_id[i])),
                    "order_index" = (isNull(qSegments.order_index[i]) ? javacast("null", "") : val(qSegments.order_index[i])),
                    "start_name" = (isNull(qSegments.start_name[i]) ? "" : toString(qSegments.start_name[i])),
                    "end_name" = (isNull(qSegments.end_name[i]) ? "" : toString(qSegments.end_name[i])),
                    "dist_nm" = (isNull(qSegments.dist_nm[i]) ? javacast("null", "") : val(qSegments.dist_nm[i])),
                    "dist_nm_calc" = (isNull(qSegments.dist_nm_calc[i]) ? javacast("null", "") : val(qSegments.dist_nm_calc[i])),
                    "active_geom_version" = (isNull(qSegments.active_geom_version[i]) ? javacast("null", "") : val(qSegments.active_geom_version[i]))
                });
            }

            return buildResponse(true, true, "OK", { "segments" = rows });
        </cfscript>
    </cffunction>

    <cffunction name="getActiveGeometry" access="private" returntype="struct" output="false">
        <cfargument name="segmentId" type="numeric" required="true">
        <cfscript>
            if (arguments.segmentId LTE 0) {
                return buildResponse(false, true, "Invalid segment", {}, "segmentId is required.", "segmentId must be a positive integer.");
            }

            var qSegment = queryExecute(
                "SELECT id, active_geom_version
                 FROM loop_segments
                 WHERE id = :segmentId
                 LIMIT 1",
                {
                    segmentId = { value = arguments.segmentId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = Application.dsn }
            );
            var activeVersion = 0;
            var qGeom = queryNew("");
            var polylineRaw = "";
            var points = [];

            if (qSegment.recordCount EQ 0) {
                return buildResponse(false, true, "Segment not found", {}, "segmentId was not found.", "No loop_segments row exists for that id.");
            }

            activeVersion = (isNull(qSegment.active_geom_version[1]) ? 0 : val(qSegment.active_geom_version[1]));

            if (activeVersion GT 0) {
                qGeom = queryExecute(
                    "SELECT
                        segment_id,
                        version,
                        polyline_json,
                        dist_nm_calc,
                        point_count,
                        source,
                        created_at,
                        simplify_tolerance_m,
                        created_by
                     FROM segment_geometries
                     WHERE segment_id = :segmentId
                       AND version = :version
                     LIMIT 1",
                    {
                        segmentId = { value = arguments.segmentId, cfsqltype = "cf_sql_integer" },
                        version = { value = activeVersion, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = Application.dsn }
                );
            }

            if (activeVersion LTE 0 OR qGeom.recordCount EQ 0) {
                qGeom = queryExecute(
                    "SELECT
                        segment_id,
                        version,
                        polyline_json,
                        dist_nm_calc,
                        point_count,
                        source,
                        created_at,
                        simplify_tolerance_m,
                        created_by
                     FROM segment_geometries
                     WHERE segment_id = :segmentId
                     ORDER BY version DESC
                     LIMIT 1",
                    {
                        segmentId = { value = arguments.segmentId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = Application.dsn }
                );
            }

            if (qGeom.recordCount EQ 0) {
                return buildResponse(true, true, "OK", {
                    "exists" = false,
                    "segmentId" = arguments.segmentId
                });
            }

            polylineRaw = (isNull(qGeom.polyline_json[1]) ? "" : toString(qGeom.polyline_json[1]));
            if (len(trim(polylineRaw))) {
                try {
                    points = deserializeJSON(polylineRaw, false);
                    if (!isArray(points)) {
                        points = [];
                    }
                } catch (any ignored) {
                    points = [];
                }
            }

            return buildResponse(true, true, "OK", {
                "exists" = true,
                "segmentId" = val(qGeom.segment_id[1]),
                "version" = val(qGeom.version[1]),
                "polyline_json" = polylineRaw,
                "points" = points,
                "dist_nm_calc" = (isNull(qGeom.dist_nm_calc[1]) ? javacast("null", "") : val(qGeom.dist_nm_calc[1])),
                "point_count" = (isNull(qGeom.point_count[1]) ? 0 : val(qGeom.point_count[1])),
                "source" = (isNull(qGeom.source[1]) ? "" : toString(qGeom.source[1])),
                "created_at" = (isNull(qGeom.created_at[1]) ? "" : dateTimeFormat(qGeom.created_at[1], "yyyy-mm-dd HH:nn:ss")),
                "simplify_tolerance_m" = (isNull(qGeom.simplify_tolerance_m[1]) ? javacast("null", "") : val(qGeom.simplify_tolerance_m[1])),
                "created_by" = (isNull(qGeom.created_by[1]) ? javacast("null", "") : val(qGeom.created_by[1]))
            });
        </cfscript>
    </cffunction>

    <cffunction name="saveGeometry" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfargument name="userStruct" type="struct" required="true">
        <cfscript>
            var segmentId = toInt(readValue(arguments.body, "segmentId", readValue(arguments.body, "segment_id", 0)));
            var sourceRaw = trim(toString(readValue(arguments.body, "source", "manual_draw")));
            var simplifyRaw = readValue(arguments.body, "simplifyToleranceM", readValue(arguments.body, "simplify_tolerance_m", ""));
            var pointsRaw = readValue(arguments.body, "points", []);
            var normalized = {};
            var nm = 0;
            var distNmCalc = 0;
            var pointCount = 0;
            var nextVersion = 1;
            var simplifyVal = 0;
            var simplifyIsNull = true;
            var qSegment = queryNew("");
            var qVersion = queryNew("");
            var createdBy = resolveUserId(arguments.userStruct);
            var polylineJson = "";

            if (segmentId LTE 0) {
                return buildResponse(false, true, "Invalid segment", {}, "segmentId is required.", "segmentId must be a positive integer.");
            }

            if (!len(sourceRaw)) {
                sourceRaw = "manual_draw";
            }
            if (len(sourceRaw) GT 40) {
                sourceRaw = left(sourceRaw, 40);
            }

            if (!isSimpleValue(simplifyRaw) OR !len(trim(toString(simplifyRaw)))) {
                simplifyIsNull = true;
            } else {
                if (!isNumeric(simplifyRaw)) {
                    return buildResponse(false, true, "Validation failed", {}, "simplifyToleranceM must be numeric.", "Provide simplifyToleranceM as a numeric value in meters.");
                }
                simplifyVal = val(simplifyRaw);
                if (simplifyVal LT 0 OR simplifyVal GT 999999) {
                    return buildResponse(false, true, "Validation failed", {}, "simplifyToleranceM is out of range.", "simplifyToleranceM must be between 0 and 999999.");
                }
                simplifyIsNull = false;
            }

            normalized = normalizePoints(pointsRaw);
            if (!normalized.ok) {
                return buildResponse(false, true, "Validation failed", {}, normalized.message, normalized.detail);
            }

            if (arrayLen(normalized.points) LT 2) {
                return buildResponse(false, true, "Validation failed", {}, "At least two points are required.", "points must contain two or more valid lat/lon pairs.");
            }

            qSegment = queryExecute(
                "SELECT id
                 FROM loop_segments
                 WHERE id = :segmentId
                 LIMIT 1",
                {
                    segmentId = { value = segmentId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = Application.dsn }
            );

            if (qSegment.recordCount EQ 0) {
                return buildResponse(false, true, "Segment not found", {}, "segmentId was not found.", "No loop_segments row exists for that id.");
            }

            nm = calculatePolylineNm(normalized.points);
            distNmCalc = round(nm * 100) / 100;
            pointCount = arrayLen(normalized.points);
            polylineJson = serializeJSON(normalized.points);

            transaction {
                qVersion = queryExecute(
                    "SELECT COALESCE(MAX(version), 0) + 1 AS next_version
                     FROM segment_geometries
                     WHERE segment_id = :segmentId",
                    {
                        segmentId = { value = segmentId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = Application.dsn }
                );

                nextVersion = val(qVersion.next_version[1]);

                queryExecute(
                    "INSERT INTO segment_geometries
                        (segment_id, version, polyline_json, polyline_enc, dist_nm_calc, point_count, simplify_tolerance_m, source, created_by)
                     VALUES
                        (:segmentId, :version, :polylineJson, NULL, :distNmCalc, :pointCount, :simplifyToleranceM, :source, :createdBy)",
                    {
                        segmentId = { value = segmentId, cfsqltype = "cf_sql_integer" },
                        version = { value = nextVersion, cfsqltype = "cf_sql_integer" },
                        polylineJson = { value = polylineJson, cfsqltype = "cf_sql_longvarchar" },
                        distNmCalc = { value = distNmCalc, cfsqltype = "cf_sql_decimal", scale = 2 },
                        pointCount = { value = pointCount, cfsqltype = "cf_sql_integer" },
                        simplifyToleranceM = { value = simplifyVal, cfsqltype = "cf_sql_decimal", scale = 2, null = simplifyIsNull },
                        source = { value = sourceRaw, cfsqltype = "cf_sql_varchar" },
                        createdBy = { value = createdBy, cfsqltype = "cf_sql_integer", null = (createdBy LTE 0) }
                    },
                    { datasource = Application.dsn }
                );

                queryExecute(
                    "UPDATE loop_segments
                     SET
                        active_geom_version = :activeGeomVersion,
                        dist_nm_calc = :distNmCalc,
                        geom_updated_at = NOW(),
                        geom_source = :geomSource
                     WHERE id = :segmentId",
                    {
                        activeGeomVersion = { value = nextVersion, cfsqltype = "cf_sql_integer" },
                        distNmCalc = { value = distNmCalc, cfsqltype = "cf_sql_decimal", scale = 2 },
                        geomSource = { value = sourceRaw, cfsqltype = "cf_sql_varchar" },
                        segmentId = { value = segmentId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = Application.dsn }
                );
            }

            return buildResponse(true, true, "Geometry saved", {
                "segmentId" = segmentId,
                "version" = nextVersion,
                "dist_nm_calc" = distNmCalc,
                "point_count" = pointCount,
                "source" = sourceRaw
            });
        </cfscript>
    </cffunction>

    <cffunction name="buildResponse" access="private" returntype="struct" output="false">
        <cfargument name="success" type="boolean" required="true">
        <cfargument name="auth" type="boolean" required="true">
        <cfargument name="message" type="string" required="true">
        <cfargument name="data" type="any" required="false" default="">
        <cfargument name="errorMessage" type="string" required="false" default="">
        <cfargument name="errorDetail" type="string" required="false" default="">
        <cfscript>
            var out = {
                "SUCCESS" = arguments.success,
                "AUTH" = arguments.auth,
                "MESSAGE" = arguments.message
            };

            if (isStruct(arguments.data) AND structCount(arguments.data)) {
                out.DATA = arguments.data;
            } else if (arguments.success) {
                out.DATA = {};
            }

            if (!arguments.success AND len(trim(arguments.errorMessage))) {
                out.ERROR = {
                    "MESSAGE" = arguments.errorMessage,
                    "DETAIL" = arguments.errorDetail
                };
            }

            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getBodyJson" access="private" returntype="struct" output="false">
        <cfscript>
            var body = {};
            var httpData = getHttpRequestData();
            var rawBody = (structKeyExists(httpData, "content") ? toString(httpData.content) : "");

            if (len(trim(rawBody))) {
                try {
                    body = deserializeJSON(rawBody, false);
                    if (!isStruct(body)) {
                        body = {};
                    }
                } catch (any ignored) {
                    body = {};
                }
            }

            return body;
        </cfscript>
    </cffunction>

    <cffunction name="resolveAction" access="private" returntype="string" output="false">
        <cfargument name="argAction" type="string" required="false" default="">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var actionName = lCase(trim(arguments.argAction));

            if (!len(actionName) AND structKeyExists(url, "action")) {
                actionName = lCase(trim(toString(url.action)));
            }
            if (!len(actionName) AND structKeyExists(form, "action")) {
                actionName = lCase(trim(toString(form.action)));
            }
            if (!len(actionName) AND structKeyExists(arguments.body, "action")) {
                actionName = lCase(trim(toString(arguments.body.action)));
            }

            return actionName;
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
            if (!len(txt) OR !isNumeric(txt)) {
                return 0;
            }
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
            // TODO: Move this whitelist to application configuration.
            var adminWhitelist = "admin@floatplanwizard.com,lswald@yahoo.com";

            if (structKeyExists(arguments.userStruct, "isAdmin") AND toBoolean(arguments.userStruct.isAdmin, false)) {
                return true;
            }
            if (structKeyExists(arguments.userStruct, "ISADMIN") AND toBoolean(arguments.userStruct.ISADMIN, false)) {
                return true;
            }
            if (structKeyExists(arguments.userStruct, "is_admin") AND toBoolean(arguments.userStruct.is_admin, false)) {
                return true;
            }

            if (structKeyExists(arguments.userStruct, "role")) {
                roleValue = lCase(trim(toString(arguments.userStruct.role)));
            } else if (structKeyExists(arguments.userStruct, "ROLE")) {
                roleValue = lCase(trim(toString(arguments.userStruct.ROLE)));
            }

            if (roleValue EQ "admin") {
                return true;
            }

            if (structKeyExists(arguments.userStruct, "email")) {
                emailValue = lCase(trim(toString(arguments.userStruct.email)));
            } else if (structKeyExists(arguments.userStruct, "EMAIL")) {
                emailValue = lCase(trim(toString(arguments.userStruct.EMAIL)));
            }

            if (len(emailValue) AND listFindNoCase(adminWhitelist, emailValue)) {
                return true;
            }

            return false;
        </cfscript>
    </cffunction>

    <cffunction name="resolveUserId" access="private" returntype="numeric" output="false">
        <cfargument name="userStruct" type="struct" required="true">
        <cfscript>
            var userId = 0;

            if (structKeyExists(arguments.userStruct, "userId")) {
                userId = toInt(arguments.userStruct.userId);
            } else if (structKeyExists(arguments.userStruct, "id")) {
                userId = toInt(arguments.userStruct.id);
            } else if (structKeyExists(arguments.userStruct, "USERID")) {
                userId = toInt(arguments.userStruct.USERID);
            }

            return userId;
        </cfscript>
    </cffunction>

    <cffunction name="normalizePoints" access="private" returntype="struct" output="false">
        <cfargument name="pointsRaw" type="any" required="true">
        <cfscript>
            var out = { "ok" = false, "message" = "", "detail" = "", "points" = [] };
            var i = 0;
            var p = {};
            var latRaw = "";
            var lonRaw = "";
            var latVal = 0.0;
            var lonVal = 0.0;

            if (!isArray(arguments.pointsRaw)) {
                out.message = "points must be an array.";
                out.detail = "Provide points as [{lat, lon}, ...].";
                return out;
            }

            for (i = 1; i LTE arrayLen(arguments.pointsRaw); i++) {
                if (!isStruct(arguments.pointsRaw[i])) {
                    out.message = "Point ##" & i & " is invalid.";
                    out.detail = "Each point must be an object with lat/lon.";
                    return out;
                }

                p = arguments.pointsRaw[i];
                latRaw = "";
                lonRaw = "";

                if (structKeyExists(p, "lat")) {
                    latRaw = p.lat;
                } else if (structKeyExists(p, "latitude")) {
                    latRaw = p.latitude;
                }

                if (structKeyExists(p, "lon")) {
                    lonRaw = p.lon;
                } else if (structKeyExists(p, "lng")) {
                    lonRaw = p.lng;
                } else if (structKeyExists(p, "longitude")) {
                    lonRaw = p.longitude;
                }

                if (!len(trim(toString(latRaw))) OR !len(trim(toString(lonRaw)))) {
                    out.message = "Point ##" & i & " is missing coordinates.";
                    out.detail = "Each point must include lat and lon (or lng/longitude).";
                    return out;
                }

                if (!isNumeric(latRaw) OR !isNumeric(lonRaw)) {
                    out.message = "Point ##" & i & " has non-numeric coordinates.";
                    out.detail = "Latitude/longitude must be numeric values.";
                    return out;
                }

                latVal = val(latRaw);
                lonVal = val(lonRaw);

                if (latVal LT -90 OR latVal GT 90) {
                    out.message = "Point ##" & i & " latitude is out of range.";
                    out.detail = "Latitude must be between -90 and 90.";
                    return out;
                }

                if (lonVal LT -180 OR lonVal GT 180) {
                    out.message = "Point ##" & i & " longitude is out of range.";
                    out.detail = "Longitude must be between -180 and 180.";
                    return out;
                }

                arrayAppend(out.points, {
                    "lat" = latVal,
                    "lon" = lonVal
                });
            }

            out.ok = true;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="toRadians" access="private" returntype="numeric" output="false">
        <cfargument name="deg" type="numeric" required="true">
        <cfreturn arguments.deg * (pi() / 180)>
    </cffunction>

    <cffunction name="haversineMeters" access="private" returntype="numeric" output="false">
        <cfargument name="lat1" type="numeric" required="true">
        <cfargument name="lon1" type="numeric" required="true">
        <cfargument name="lat2" type="numeric" required="true">
        <cfargument name="lon2" type="numeric" required="true">
        <cfscript>
            var earthRadiusMeters = 6371008.8;
            var dLat = toRadians(arguments.lat2 - arguments.lat1);
            var dLon = toRadians(arguments.lon2 - arguments.lon1);
            var phi1 = toRadians(arguments.lat1);
            var phi2 = toRadians(arguments.lat2);
            var a = (sin(dLat / 2) ^ 2) + cos(phi1) * cos(phi2) * (sin(dLon / 2) ^ 2);
            if (a LT 0) a = 0;
            if (a GT 1) a = 1;
            var c = 2 * atn2Compat(sqr(a), sqr(1 - a));
            return earthRadiusMeters * c;
        </cfscript>
    </cffunction>

    <cffunction name="calculatePolylineNm" access="private" returntype="numeric" output="false">
        <cfargument name="points" type="array" required="true">
        <cfscript>
            var totalMeters = 0.0;
            var i = 0;
            if (arrayLen(arguments.points) LT 2) {
                return 0;
            }
            for (i = 2; i LTE arrayLen(arguments.points); i++) {
                totalMeters += haversineMeters(
                    arguments.points[i - 1].lat,
                    arguments.points[i - 1].lon,
                    arguments.points[i].lat,
                    arguments.points[i].lon
                );
            }
            return totalMeters / 1852;
        </cfscript>
    </cffunction>

    <cffunction name="atn2Compat" access="private" returntype="numeric" output="false">
        <cfargument name="y" type="numeric" required="true">
        <cfargument name="x" type="numeric" required="true">
        <cfscript>
            var piVal = pi();
            if (arguments.x GT 0) {
                return atn(arguments.y / arguments.x);
            }
            if (arguments.x LT 0 AND arguments.y GTE 0) {
                return atn(arguments.y / arguments.x) + piVal;
            }
            if (arguments.x LT 0 AND arguments.y LT 0) {
                return atn(arguments.y / arguments.x) - piVal;
            }
            if (arguments.x EQ 0 AND arguments.y GT 0) {
                return piVal / 2;
            }
            if (arguments.x EQ 0 AND arguments.y LT 0) {
                return -piVal / 2;
            }
            return 0;
        </cfscript>
    </cffunction>

</cfcomponent>
