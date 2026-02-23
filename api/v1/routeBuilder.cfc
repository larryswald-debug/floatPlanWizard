<cfcomponent output="false">

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfargument name="action" type="string" required="false" default="getTimeline">
        <cfargument name="routeCode" type="string" required="false" default="">
        <cfargument name="segmentId" type="numeric" required="false" default="0">
        <cfargument name="direction" type="string" required="false" default="">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

        <cftry>
            <cfset var userStruct = {} />
            <cfif structKeyExists(session, "user") AND isStruct(session.user)>
                <cfset userStruct = session.user />
            </cfif>
            <cfset var userId = resolveUserId(userStruct) />

            <cfif userId LTE 0>
                <cfoutput>#serializeJSON({
                    "SUCCESS"=false,
                    "AUTH"=false,
                    "MESSAGE"="Unauthorized",
                    "ERROR"={"MESSAGE"="No logged-in user session."}
                })#</cfoutput>
                <cfreturn>
            </cfif>

            <cfset var body = getBodyJson() />
            <cfset var act = lCase(trim(arguments.action)) />

            <cfif act EQ "generateroute">
                <cfoutput>#serializeJSON({
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Legacy action disabled",
                    "ERROR"={"MESSAGE"="Action 'generateRoute' is disabled. Use 'routegen_generate'."},
                    "REPLACEMENT_ACTION"="routegen_generate"
                })#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "listroutetemplates">
                <cfset var templates = listRouteTemplates() />
                <cfoutput>#serializeJSON(templates)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "getroutetemplatepreview">
                <cfset var previewRouteId = val(pickArg(body, "routeId", "routeId", 0)) />
                <cfset var previewRouteCode = trim(pickArg(body, "routeCode", "routeCode", "")) />
                <cfset var previewDirection = trim(pickArg(body, "direction", "direction", "CCW")) />
                <cfset var preview = getRouteTemplatePreview(previewRouteId, previewRouteCode, previewDirection) />
                <cfoutput>#serializeJSON(preview)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "getroutetemplatedetours">
                <cfset var detourRouteId = val(pickArg(body, "routeId", "routeId", 0)) />
                <cfset var detourRouteCode = trim(pickArg(body, "routeCode", "routeCode", "")) />
                <cfset var detours = getRouteTemplateDetours(detourRouteId, detourRouteCode) />
                <cfoutput>#serializeJSON(detours)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "generateroutefromtemplate">
                <cfoutput>#serializeJSON({
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Legacy action disabled",
                    "ERROR"={"MESSAGE"="Action 'generateRouteFromTemplate' is disabled. Use 'routegen_generate'."},
                    "REPLACEMENT_ACTION"="routegen_generate"
                })#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "listuserroutes">
                <cfset var listed = listUserRoutes(userId) />
                <cfoutput>#serializeJSON(listed)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "listcanonicallocations">
                <cfoutput>#serializeJSON({
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Legacy action disabled",
                    "ERROR"={"MESSAGE"="Action 'listCanonicalLocations' is disabled. Use 'routegen_getoptions'."},
                    "REPLACEMENT_ACTION"="routegen_getoptions"
                })#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "routegen_getoptions">
                <cfset var routegenTemplateCode = trim(pickArg(body, "template_code", "templateCode", "")) />
                <cfset var routegenDirection = trim(pickArg(body, "direction", "direction", "CCW")) />
                <cfset var routegenOptions = routegenGetOptions(
                    userId = userId,
                    templateCode = routegenTemplateCode,
                    direction = routegenDirection
                ) />
                <cfoutput>#serializeJSON(routegenOptions)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "routegen_preview">
                <cfset var routegenPreviewInput = routegenReadInput(body) />
                <cfset var routegenPreviewRes = routegenPreview(
                    userId = userId,
                    input = routegenPreviewInput
                ) />
                <cfoutput>#serializeJSON(routegenPreviewRes)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "routegen_geteditcontext">
                <cfset var routegenEditRouteCode = trim(pickArg(body, "route_code", "routeCode", "")) />
                <cfset var routegenEditContextRes = routegenGetEditContext(
                    userId = userId,
                    routeCode = routegenEditRouteCode
                ) />
                <cfoutput>#serializeJSON(routegenEditContextRes)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "routegen_generate">
                <cfset var routegenGenerateInput = routegenReadInput(body) />
                <cfset var routegenGenerateRes = routegenGenerate(
                    userId = userId,
                    input = routegenGenerateInput
                ) />
                <cfoutput>#serializeJSON(routegenGenerateRes)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "routegen_update">
                <cfset var routegenUpdateRouteCode = trim(pickArg(body, "route_code", "routeCode", "")) />
                <cfset var routegenUpdateInput = routegenReadInput(body) />
                <cfset var routegenUpdateRes = routegenUpdate(
                    userId = userId,
                    routeCode = routegenUpdateRouteCode,
                    input = routegenUpdateInput
                ) />
                <cfoutput>#serializeJSON(routegenUpdateRes)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "routegen_getleggeometry">
                <cfset var routegenLegGeometryRouteCode = trim(pickArg(body, "route_code", "routeCode", "")) />
                <cfset var routegenLegGeometryLegId = val(pickArg(body, "route_leg_id", "routeLegId", 0)) />
                <cfset var routegenLegGeometrySegmentId = val(pickArg(body, "segment_id", "segmentId", 0)) />
                <cfset var routegenLegGeometryOrder = val(pickArg(body, "leg_order", "legOrder", 0)) />
                <cfset var routegenLegGeometryRes = routegenGetLegGeometry(
                    userId = userId,
                    routeCode = routegenLegGeometryRouteCode,
                    routeLegId = routegenLegGeometryLegId,
                    segmentId = routegenLegGeometrySegmentId,
                    legOrder = routegenLegGeometryOrder
                ) />
                <cfoutput>#serializeJSON(routegenLegGeometryRes)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "routegen_getleglocks">
                <cfset var routegenLegLocksRouteCode = trim(pickArg(body, "route_code", "routeCode", "")) />
                <cfset var routegenLegLocksTemplateCode = trim(pickArg(body, "template_code", "templateCode", "")) />
                <cfset var routegenLegLocksLegId = val(pickArg(body, "route_leg_id", "routeLegId", 0)) />
                <cfset var routegenLegLocksSegmentId = val(pickArg(body, "segment_id", "segmentId", 0)) />
                <cfset var routegenLegLocksOrder = val(pickArg(body, "leg_order", "legOrder", 0)) />
                <cfset var routegenLegLocksRes = routegenGetLegLocks(
                    userId = userId,
                    routeCode = routegenLegLocksRouteCode,
                    templateCode = routegenLegLocksTemplateCode,
                    routeLegId = routegenLegLocksLegId,
                    segmentId = routegenLegLocksSegmentId,
                    legOrder = routegenLegLocksOrder
                ) />
                <cfoutput>#serializeJSON(routegenLegLocksRes)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "routegen_savelegoverride">
                <cfset var routegenSaveOverrideRouteCode = trim(pickArg(body, "route_code", "routeCode", "")) />
                <cfset var routegenSaveOverrideLegId = val(pickArg(body, "route_leg_id", "routeLegId", 0)) />
                <cfset var routegenSaveOverrideOrder = val(pickArg(body, "leg_order", "legOrder", 0)) />
                <cfset var routegenSaveOverrideSegmentId = val(pickArg(body, "segment_id", "segmentId", 0)) />
                <cfset var routegenSaveOverrideGeometry = pickArg(body, "geometry", "points", []) />
                <cfset var routegenSaveOverrideFields = pickArg(body, "override_fields", "overrideFields", {}) />
                <cfset var routegenSaveOverrideRes = routegenSaveLegOverride(
                    userId = userId,
                    routeCode = routegenSaveOverrideRouteCode,
                    routeLegId = routegenSaveOverrideLegId,
                    legOrder = routegenSaveOverrideOrder,
                    segmentId = routegenSaveOverrideSegmentId,
                    geometryRaw = routegenSaveOverrideGeometry,
                    overrideFieldsRaw = routegenSaveOverrideFields
                ) />
                <cfoutput>#serializeJSON(routegenSaveOverrideRes)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "routegen_clearlegoverride">
                <cfset var routegenClearOverrideRouteCode = trim(pickArg(body, "route_code", "routeCode", "")) />
                <cfset var routegenClearOverrideLegId = val(pickArg(body, "route_leg_id", "routeLegId", 0)) />
                <cfset var routegenClearOverrideRes = routegenClearLegOverride(
                    userId = userId,
                    routeCode = routegenClearOverrideRouteCode,
                    routeLegId = routegenClearOverrideLegId
                ) />
                <cfoutput>#serializeJSON(routegenClearOverrideRes)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "routegen_savesegmentoverride">
                <cfset var routegenSaveSegmentOverrideId = val(pickArg(body, "segment_id", "segmentId", 0)) />
                <cfset var routegenSaveSegmentOverrideGeometry = pickArg(body, "geometry", "points", []) />
                <cfset var routegenSaveSegmentOverrideFields = pickArg(body, "override_fields", "overrideFields", {}) />
                <cfset var routegenSaveSegmentOverrideRes = routegenSaveSegmentOverride(
                    userId = userId,
                    segmentId = routegenSaveSegmentOverrideId,
                    geometryRaw = routegenSaveSegmentOverrideGeometry,
                    overrideFieldsRaw = routegenSaveSegmentOverrideFields
                ) />
                <cfoutput>#serializeJSON(routegenSaveSegmentOverrideRes)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "routegen_clearsegmentoverride">
                <cfset var routegenClearSegmentOverrideId = val(pickArg(body, "segment_id", "segmentId", 0)) />
                <cfset var routegenClearSegmentOverrideRes = routegenClearSegmentOverride(
                    userId = userId,
                    segmentId = routegenClearSegmentOverrideId
                ) />
                <cfoutput>#serializeJSON(routegenClearSegmentOverrideRes)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "routegen_listlegoverrides">
                <cfset var routegenListOverrideRouteCode = trim(pickArg(body, "route_code", "routeCode", "")) />
                <cfset var routegenListOverrideRes = routegenListLegOverrides(
                    userId = userId,
                    routeCode = routegenListOverrideRouteCode
                ) />
                <cfoutput>#serializeJSON(routegenListOverrideRes)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "buildfloatplansfromroute">
                <cfset var buildRouteInstanceId = val(pickArg(body, "routeInstanceId", "route_instance_id", 0)) />
                <cfset var buildRouteCode = trim(pickArg(body, "routeCode", "route_code", "")) />
                <cfset var buildMode = trim(pickArg(body, "mode", "mode", "DAILY")) />
                <cfset var buildVesselId = val(pickArg(body, "vesselId", "vessel_id", 0)) />
                <cfset var buildRebuild = pickArg(body, "rebuild", "rebuild", false) />
                <cfset var built = buildFloatPlansFromRoute(
                    userId = userId,
                    routeInstanceId = buildRouteInstanceId,
                    routeCode = buildRouteCode,
                    mode = buildMode,
                    vesselId = buildVesselId,
                    rebuild = buildRebuild
                ) />
                <cfoutput>#serializeJSON(built)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "setactiveroute">
                <cfset var activeCode = trim(arguments.routeCode) />
                <cfif NOT len(activeCode)>
                    <cfset activeCode = trim(pickArg(body, "routeCode", "routeCode", "")) />
                </cfif>
                <cfif NOT len(activeCode)>
                    <cfoutput>#serializeJSON({
                        "SUCCESS"=false,
                        "AUTH"=true,
                        "MESSAGE"="routeCode required",
                        "ERROR"={"MESSAGE"="routeCode is required"}
                    })#</cfoutput>
                    <cfreturn>
                </cfif>
                <cfset var activeRes = setActiveRoute(userId, activeCode) />
                <cfoutput>#serializeJSON(activeRes)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "deleteroute">
                <cfset var deleteCode = trim(arguments.routeCode) />
                <cfif NOT len(deleteCode)>
                    <cfset deleteCode = trim(pickArg(body, "routeCode", "routeCode", "")) />
                </cfif>
                <cfif NOT len(deleteCode)>
                    <cfoutput>#serializeJSON({
                        "SUCCESS"=false,
                        "AUTH"=true,
                        "MESSAGE"="routeCode required",
                        "ERROR"={"MESSAGE"="routeCode is required"}
                    })#</cfoutput>
                    <cfreturn>
                </cfif>
                <cfset var deleteRes = deleteRoute(userId, deleteCode) />
                <cfoutput>#serializeJSON(deleteRes)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "gettimeline">
                <cfset var rcode = trim(arguments.routeCode) />
                <cfif NOT len(rcode)>
                    <cfset rcode = trim(pickArg(body, "routeCode", "routeCode", "")) />
                </cfif>
                <cfif NOT len(rcode)>
                    <cfoutput>#serializeJSON({
                        "SUCCESS"=false,
                        "AUTH"=true,
                        "MESSAGE"="routeCode required",
                        "ERROR"={"MESSAGE"="routeCode is required"}
                    })#</cfoutput>
                    <cfreturn>
                </cfif>
                <cfset var tl = getTimeline(userId, rcode) />
                <cfoutput>#serializeJSON(tl)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "generatecruisetimeline">
                <cfset var cruiseRouteId = val(pickArg(body, "routeId", "route_id", 0)) />
                <cfset var cruiseStartDate = trim(toString(pickArg(body, "startDate", "start_date", ""))) />
                <cfset var cruiseMaxHoursPerDay = val(pickArg(body, "maxHoursPerDay", "max_hours_per_day", 6.5)) />
                <cfset var cruiseTimeline = generateCruiseTimeline(
                    routeId = cruiseRouteId,
                    startDate = cruiseStartDate,
                    maxHoursPerDay = cruiseMaxHoursPerDay
                ) />
                <cfoutput>#serializeJSON(cruiseTimeline)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "updatesegment">
                <cfoutput>#serializeJSON({
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Legacy action disabled",
                    "ERROR"={"MESSAGE"="Action 'updateSegment' is disabled. Use routegen preview/update and leg overrides."}
                })#</cfoutput>
                <cfreturn>

            <cfelse>
                <cfoutput>#serializeJSON({
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Unknown action",
                    "ERROR"={"MESSAGE"="Unsupported action: " & arguments.action}
                })#</cfoutput>
                <cfreturn>
            </cfif>

            <cfcatch>
                <cfoutput>#serializeJSON({
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Application error",
                    "ERROR"={"MESSAGE"=cfcatch.message, "DETAIL"=cfcatch.detail}
                })#</cfoutput>
            </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="listRouteTemplates" access="private" returntype="struct" output="false">
        <cfscript>
            var out = {
                "SUCCESS"=true,
                "AUTH"=true,
                "MESSAGE"="OK",
                "DATA"={ "ROUTES"=[] }
            };
            var qTemplates = queryExecute(
                "SELECT id, code, name, description, short_code, version, is_default
                 FROM loop_routes
                 WHERE is_active = 1
                   AND short_code NOT LIKE :userPrefix
                   AND EXISTS (
                     SELECT 1
                     FROM route_template_segments rts
                     WHERE rts.route_id = loop_routes.id
                   )
                 ORDER BY is_default DESC, name ASC, id ASC",
                {
                    userPrefix = { value="USER_ROUTE_%", cfsqltype="cf_sql_varchar" }
                },
                { datasource = application.dsn }
            );
            var i = 0;
            for (i = 1; i LTE qTemplates.recordCount; i++) {
                arrayAppend(out.DATA.ROUTES, {
                    "ID"=val(qTemplates.id[i]),
                    "CODE"=(isNull(qTemplates.code[i]) ? "" : toString(qTemplates.code[i])),
                    "NAME"=(isNull(qTemplates.name[i]) ? "" : toString(qTemplates.name[i])),
                    "DESCRIPTION"=(isNull(qTemplates.description[i]) ? "" : toString(qTemplates.description[i])),
                    "SHORT_CODE"=(isNull(qTemplates.short_code[i]) ? "" : toString(qTemplates.short_code[i])),
                    "VERSION"=(isNull(qTemplates.version[i]) ? 0 : val(qTemplates.version[i])),
                    "IS_DEFAULT"=(qTemplates.is_default[i] EQ 1)
                });
            }
            return out;
        </cfscript>
    </cffunction>
    <cffunction name="generateRoute" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="startDate" type="string" required="true">
        <cfargument name="startLocation" type="string" required="true">
        <cfargument name="endLocation" type="string" required="true">
        <cfargument name="direction" type="string" required="false" default="CCW">
        <cfargument name="tripType" type="string" required="false" default="POINT_TO_POINT">
        <cfscript>
            return {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Legacy action disabled",
                "ERROR"={"MESSAGE"="Action 'generateRoute' is disabled. Use 'routegen_generate'."},
                "REPLACEMENT_ACTION"="routegen_generate"
            };
        </cfscript>
    </cffunction>
    <cffunction name="generateRouteFromTemplate" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="templateRouteId" type="numeric" required="false" default="0">
        <cfargument name="templateRouteCode" type="string" required="false" default="">
        <cfargument name="direction" type="string" required="false" default="CCW">
        <cfargument name="mode" type="string" required="false" default="FULL_TEMPLATE">
        <cfargument name="routeName" type="string" required="false" default="">
        <cfargument name="setActive" type="any" required="false" default="true">
        <cfscript>
            return {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Legacy action disabled",
                "ERROR"={"MESSAGE"="Action 'generateRouteFromTemplate' is disabled. Use 'routegen_generate'."},
                "REPLACEMENT_ACTION"="routegen_generate"
            };
        </cfscript>
    </cffunction>


    <cffunction name="getRouteTemplatePreview" access="private" returntype="struct" output="false">
        <cfargument name="routeId" type="numeric" required="false" default="0">
        <cfargument name="routeCode" type="string" required="false" default="">
        <cfargument name="direction" type="string" required="false" default="CCW">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Route template preview unavailable",
                "DATA"={ "ROUTE"={}, "SEGMENTS"=[] }
            };
            var routeIdVal = val(arguments.routeId);
            var routeCodeVal = trim(arguments.routeCode);
            var directionVal = normalizeDirection(arguments.direction);
            var qRoute = queryNew("");
            var qSegments = queryNew("");
            var i = 0;
            var srcIdx = 0;
            var segObj = {};

            if (routeIdVal LTE 0 AND !len(routeCodeVal)) {
                out.MESSAGE = "Missing required fields";
                out.ERROR = { "MESSAGE"="routeId or routeCode is required." };
                return out;
            }

            if (routeIdVal GT 0) {
                qRoute = queryExecute(
                    "SELECT id, code, name, description, short_code
                     FROM loop_routes
                     WHERE id = :rid
                       AND is_active = 1
                       AND short_code NOT LIKE :userPrefix
                     LIMIT 1",
                    {
                        rid = { value=routeIdVal, cfsqltype="cf_sql_integer" },
                        userPrefix = { value="USER_ROUTE_%", cfsqltype="cf_sql_varchar" }
                    },
                    { datasource = application.dsn }
                );
            } else {
                qRoute = queryExecute(
                    "SELECT id, code, name, description, short_code
                     FROM loop_routes
                     WHERE is_active = 1
                       AND short_code NOT LIKE :userPrefix
                       AND (short_code = :rcode OR code = :rcode)
                     ORDER BY CASE WHEN short_code = :rcode THEN 0 ELSE 1 END, id ASC
                     LIMIT 1",
                    {
                        userPrefix = { value="USER_ROUTE_%", cfsqltype="cf_sql_varchar" },
                        rcode = { value=routeCodeVal, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource = application.dsn }
                );
            }

            if (qRoute.recordCount EQ 0) {
                out.MESSAGE = "Route template not found";
                out.ERROR = { "MESSAGE"="No active canonical route template matched the provided routeId/routeCode." };
                return out;
            }

            routeIdVal = val(qRoute.id[1]);
            qSegments = queryExecute(
                "SELECT
                    rts.order_index,
                    sl.id AS segment_id,
                    p1.id AS start_port_id,
                    COALESCE(NULLIF(TRIM(p1.name), ''), TRIM(sl.start_port_name), '') AS start_port,
                    p2.id AS end_port_id,
                    COALESCE(NULLIF(TRIM(p2.name), ''), TRIM(sl.end_port_name), '') AS end_port,
                    sl.dist_nm,
                    sl.is_offshore,
                    sl.is_icw
                 FROM route_template_segments rts
                 INNER JOIN segment_library sl ON sl.id = rts.segment_id
                 LEFT JOIN ports p1 ON p1.id = sl.start_port_id
                 LEFT JOIN ports p2 ON p2.id = sl.end_port_id
                 WHERE rts.route_id = :rid
                 ORDER BY rts.order_index ASC, rts.id ASC",
                {
                    rid = { value=routeIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );

            out.DATA.ROUTE = {
                "ID"=routeIdVal,
                "CODE"=(isNull(qRoute.code[1]) ? "" : toString(qRoute.code[1])),
                "NAME"=(isNull(qRoute.name[1]) ? "" : toString(qRoute.name[1])),
                "DESCRIPTION"=(isNull(qRoute.description[1]) ? "" : toString(qRoute.description[1]))
            };

            for (i = 1; i LTE qSegments.recordCount; i++) {
                srcIdx = (directionVal EQ "CW" ? (qSegments.recordCount - i + 1) : i);
                segObj = {
                    "ORDER_INDEX"=i,
                    "SEGMENT_ID"=val(qSegments.segment_id[srcIdx]),
                    "START_PORT_ID"=(directionVal EQ "CW" ? (isNull(qSegments.end_port_id[srcIdx]) ? 0 : val(qSegments.end_port_id[srcIdx])) : (isNull(qSegments.start_port_id[srcIdx]) ? 0 : val(qSegments.start_port_id[srcIdx]))),
                    "START_PORT"=(directionVal EQ "CW" ? (isNull(qSegments.end_port[srcIdx]) ? "" : toString(qSegments.end_port[srcIdx])) : (isNull(qSegments.start_port[srcIdx]) ? "" : toString(qSegments.start_port[srcIdx]))),
                    "END_PORT_ID"=(directionVal EQ "CW" ? (isNull(qSegments.start_port_id[srcIdx]) ? 0 : val(qSegments.start_port_id[srcIdx])) : (isNull(qSegments.end_port_id[srcIdx]) ? 0 : val(qSegments.end_port_id[srcIdx]))),
                    "END_PORT"=(directionVal EQ "CW" ? (isNull(qSegments.start_port[srcIdx]) ? "" : toString(qSegments.start_port[srcIdx])) : (isNull(qSegments.end_port[srcIdx]) ? "" : toString(qSegments.end_port[srcIdx]))),
                    "DIST_NM"=(isNull(qSegments.dist_nm[srcIdx]) ? 0 : val(qSegments.dist_nm[srcIdx])),
                    "IS_OFFSHORE"=(qSegments.is_offshore[srcIdx] EQ 1),
                    "IS_ICW"=(qSegments.is_icw[srcIdx] EQ 1)
                };
                arrayAppend(out.DATA.SEGMENTS, segObj);
            }

            out.SUCCESS = true;
            out.MESSAGE = "OK";
            out.DATA.DIRECTION = directionVal;
            return out;
        </cfscript>
    </cffunction>
    <cffunction name="listCanonicalLocations" access="private" returntype="struct" output="false">
        <cfargument name="direction" type="string" required="false" default="CCW">
        <cfscript>
            return {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Legacy action disabled",
                "ERROR"={"MESSAGE"="Action 'listCanonicalLocations' is disabled. Use 'routegen_getoptions'."},
                "REPLACEMENT_ACTION"="routegen_getoptions"
            };
        </cfscript>
    </cffunction>


    <cffunction name="getRouteTemplateDetours" access="private" returntype="struct" output="false">
        <cfargument name="routeId" type="numeric" required="false" default="0">
        <cfargument name="routeCode" type="string" required="false" default="">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Route detours unavailable",
                "DATA"={ "DETOURS"=[], "DETOUR_SEGMENTS"={} }
            };
            var routeIdVal = val(arguments.routeId);
            var routeCodeVal = trim(arguments.routeCode);
            var qRoute = queryNew("");
            var qDetours = queryNew("");
            var qDetourSegments = queryNew("");
            var i = 0;
            var detourCode = "";

            if (routeIdVal LTE 0 AND !len(routeCodeVal)) {
                out.MESSAGE = "Missing required fields";
                out.ERROR = { "MESSAGE"="routeId or routeCode is required." };
                return out;
            }

            if (routeIdVal GT 0) {
                qRoute = queryExecute(
                    "SELECT id
                     FROM loop_routes
                     WHERE id = :rid
                       AND is_active = 1
                       AND short_code NOT LIKE :userPrefix
                     LIMIT 1",
                    {
                        rid = { value=routeIdVal, cfsqltype="cf_sql_integer" },
                        userPrefix = { value="USER_ROUTE_%", cfsqltype="cf_sql_varchar" }
                    },
                    { datasource = application.dsn }
                );
            } else {
                qRoute = queryExecute(
                    "SELECT id
                     FROM loop_routes
                     WHERE is_active = 1
                       AND short_code NOT LIKE :userPrefix
                       AND (short_code = :rcode OR code = :rcode)
                     ORDER BY CASE WHEN short_code = :rcode THEN 0 ELSE 1 END, id ASC
                     LIMIT 1",
                    {
                        userPrefix = { value="USER_ROUTE_%", cfsqltype="cf_sql_varchar" },
                        rcode = { value=routeCodeVal, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource = application.dsn }
                );
            }

            if (qRoute.recordCount EQ 0) {
                out.MESSAGE = "Route template not found";
                out.ERROR = { "MESSAGE"="No active canonical route template matched the provided routeId/routeCode." };
                return out;
            }
            routeIdVal = val(qRoute.id[1]);

            qDetours = queryExecute(
                "SELECT
                    d.id AS detour_id,
                    d.detour_code,
                    d.name,
                    d.description,
                    d.detour_type,
                    d.sort_order,
                    d.is_active
                 FROM route_template_detours d
                 WHERE d.route_id = :rid
                 ORDER BY d.sort_order ASC, d.id ASC",
                {
                    rid = { value=routeIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );

            for (i = 1; i LTE qDetours.recordCount; i++) {
                detourCode = (isNull(qDetours.detour_code[i]) ? "" : trim(toString(qDetours.detour_code[i])));
                arrayAppend(out.DATA.DETOURS, {
                    "DETOUR_ID"=val(qDetours.detour_id[i]),
                    "DETOUR_CODE"=detourCode,
                    "NAME"=(isNull(qDetours.name[i]) ? "" : toString(qDetours.name[i])),
                    "DESCRIPTION"=(isNull(qDetours.description[i]) ? "" : toString(qDetours.description[i])),
                    "DETOUR_TYPE"=(isNull(qDetours.detour_type[i]) ? "" : toString(qDetours.detour_type[i])),
                    "SORT_ORDER"=(isNull(qDetours.sort_order[i]) ? 0 : val(qDetours.sort_order[i])),
                    "IS_ACTIVE"=(qDetours.is_active[i] EQ 1)
                });
                if (len(detourCode) AND !structKeyExists(out.DATA.DETOUR_SEGMENTS, detourCode)) {
                    out.DATA.DETOUR_SEGMENTS[detourCode] = [];
                }
            }

            qDetourSegments = queryExecute(
                "SELECT
                    d.detour_code,
                    dts.order_index,
                    sl.id AS segment_id,
                    p1.id AS start_port_id,
                    COALESCE(NULLIF(TRIM(p1.name), ''), TRIM(sl.start_port_name), '') AS start_port,
                    p2.id AS end_port_id,
                    COALESCE(NULLIF(TRIM(p2.name), ''), TRIM(sl.end_port_name), '') AS end_port,
                    sl.dist_nm,
                    sl.is_offshore,
                    sl.is_icw
                 FROM route_template_detours d
                 INNER JOIN route_template_detour_segments dts ON dts.detour_id = d.id
                 INNER JOIN segment_library sl ON sl.id = dts.segment_id
                 LEFT JOIN ports p1 ON p1.id = sl.start_port_id
                 LEFT JOIN ports p2 ON p2.id = sl.end_port_id
                 WHERE d.route_id = :rid
                 ORDER BY d.sort_order ASC, d.id ASC, dts.order_index ASC, dts.id ASC",
                {
                    rid = { value=routeIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );

            for (i = 1; i LTE qDetourSegments.recordCount; i++) {
                detourCode = (isNull(qDetourSegments.detour_code[i]) ? "" : trim(toString(qDetourSegments.detour_code[i])));
                if (!len(detourCode)) {
                    continue;
                }
                if (!structKeyExists(out.DATA.DETOUR_SEGMENTS, detourCode)) {
                    out.DATA.DETOUR_SEGMENTS[detourCode] = [];
                }
                arrayAppend(out.DATA.DETOUR_SEGMENTS[detourCode], {
                    "ORDER_INDEX"=(isNull(qDetourSegments.order_index[i]) ? 0 : val(qDetourSegments.order_index[i])),
                    "SEGMENT_ID"=val(qDetourSegments.segment_id[i]),
                    "START_PORT_ID"=(isNull(qDetourSegments.start_port_id[i]) ? 0 : val(qDetourSegments.start_port_id[i])),
                    "START_PORT"=(isNull(qDetourSegments.start_port[i]) ? "" : toString(qDetourSegments.start_port[i])),
                    "END_PORT_ID"=(isNull(qDetourSegments.end_port_id[i]) ? 0 : val(qDetourSegments.end_port_id[i])),
                    "END_PORT"=(isNull(qDetourSegments.end_port[i]) ? "" : toString(qDetourSegments.end_port[i])),
                    "DIST_NM"=(isNull(qDetourSegments.dist_nm[i]) ? 0 : val(qDetourSegments.dist_nm[i])),
                    "IS_OFFSHORE"=(qDetourSegments.is_offshore[i] EQ 1),
                    "IS_ICW"=(qDetourSegments.is_icw[i] EQ 1)
                });
            }

            out.SUCCESS = true;
            out.MESSAGE = "OK";
            return out;
        </cfscript>
    </cffunction>
    <cffunction name="updateSegment" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeCode" type="string" required="true">
        <cfargument name="segmentId" type="numeric" required="true">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            return {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Legacy action disabled",
                "ERROR"={"MESSAGE"="Action 'updateSegment' is disabled. Use routegen preview/update and leg overrides."}
            };
        </cfscript>
    </cffunction>


    <cffunction name="listUserRoutes" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfscript>
            var out = { "SUCCESS"=true, "AUTH"=true, "MESSAGE"="OK", "ROUTES"=[], "ACTIVE_ROUTE_CODE"="" };
            var routePrefix = "USER_ROUTE_" & int(arguments.userId) & "_%";
            var qRoutes = queryExecute(
                "SELECT id, name, short_code, description
                 FROM loop_routes
                 WHERE short_code LIKE :prefix
                 ORDER BY id DESC",
                { prefix = { value=routePrefix, cfsqltype="cf_sql_varchar" } },
                { datasource = application.dsn }
            );
            var i = 0;
            var timeline = {};
            for (i = 1; i LTE qRoutes.recordCount; i++) {
                timeline = getTimeline(arguments.userId, qRoutes.short_code[i]);
                if (!structKeyExists(timeline, "SUCCESS") OR timeline.SUCCESS EQ false) {
                    continue;
                }
                arrayAppend(out.ROUTES, {
                    "ID"=qRoutes.id[i],
                    "NAME"=(isNull(qRoutes.name[i]) ? "" : qRoutes.name[i]),
                    "SHORT_CODE"=qRoutes.short_code[i],
                    "DESCRIPTION"=(isNull(qRoutes.description[i]) ? "" : qRoutes.description[i]),
                    "TOTALS"=timeline.TOTALS
                });
            }

            if (structKeyExists(session, "expeditionRouteCode")) {
                out.ACTIVE_ROUTE_CODE = toString(session.expeditionRouteCode);
            }
            var hasActive = false;
            for (i = 1; i LTE arrayLen(out.ROUTES); i++) {
                if (out.ROUTES[i].SHORT_CODE EQ out.ACTIVE_ROUTE_CODE) {
                    hasActive = true;
                    break;
                }
            }
            if (!hasActive) {
                out.ACTIVE_ROUTE_CODE = "";
            }
            if (!len(out.ACTIVE_ROUTE_CODE) AND arrayLen(out.ROUTES)) {
                out.ACTIVE_ROUTE_CODE = out.ROUTES[1].SHORT_CODE;
                session.expeditionRouteCode = out.ACTIVE_ROUTE_CODE;
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="buildFloatPlansFromRoute" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeInstanceId" type="numeric" required="false" default="0">
        <cfargument name="routeCode" type="string" required="false" default="">
        <cfargument name="mode" type="string" required="false" default="DAILY">
        <cfargument name="vesselId" type="numeric" required="false" default="0">
        <cfargument name="rebuild" type="any" required="false" default="false">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unable to build float plans from route.",
                "ROUTE_INSTANCE_ID"=0,
                "ROUTE_CODE"="",
                "MODE"="DAILY",
                "CREATED_COUNT"=0,
                "FLOATPLAN_IDS"=[],
                "FLOATPLANS"=[]
            };

            var routeCodeVal = trim(arguments.routeCode);
            var routeInstanceIdVal = val(arguments.routeInstanceId);
            var modeVal = normalizeBuildMode(arguments.mode);
            var rebuildVal = toBoolean(arguments.rebuild, false);
            var userIdText = toString(arguments.userId);
            var vesselIdVal = val(arguments.vesselId);
            var qRouteInstance = queryNew("");
            var qPreferredVessel = queryNew("");
            var generatedRouteId = 0;
            var qRoute = queryNew("");
            var qSegments = queryNew("");
            var existingCount = 0;
            var activeExistingCount = 0;
            var dayRows = [];
            var sectionOrder = [];
            var sectionMap = {};
            var sid = "";
            var secObj = {};
            var i = 0;
            var totalNm = 0.0;
            var totalLocks = 0;
            var dayNum = 0;
            var dayObj = {};
            var planName = "";
            var notesVal = "";
            var newPlanId = 0;

            if (routeInstanceIdVal LTE 0 AND !len(routeCodeVal)) {
                out.MESSAGE = "Missing required fields";
                out.ERROR = { "CODE"="MISSING_ROUTE_REFERENCE", "MESSAGE"="routeInstanceId or routeCode is required." };
                return out;
            }

            if (routeInstanceIdVal GT 0) {
                qRouteInstance = queryExecute(
                    "SELECT id, generated_route_id, generated_route_code
                     FROM route_instances
                     WHERE id = :rid
                       AND user_id = :uid
                     LIMIT 1",
                    {
                        rid = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" },
                        uid = { value=userIdText, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource = application.dsn }
                );
            } else {
                qRouteInstance = queryExecute(
                    "SELECT id, generated_route_id, generated_route_code
                     FROM route_instances
                     WHERE generated_route_code = :rcode
                       AND user_id = :uid
                     ORDER BY id DESC
                     LIMIT 1",
                    {
                        rcode = { value=routeCodeVal, cfsqltype="cf_sql_varchar" },
                        uid = { value=userIdText, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource = application.dsn }
                );
            }

            if (qRouteInstance.recordCount EQ 0) {
                out.MESSAGE = "Route instance not found";
                out.ERROR = { "CODE"="ROUTE_INSTANCE_NOT_FOUND", "MESSAGE"="No route instance found for the selected route." };
                return out;
            }

            routeInstanceIdVal = val(qRouteInstance.id[1]);
            generatedRouteId = val(qRouteInstance.generated_route_id[1]);
            if (!len(routeCodeVal)) {
                routeCodeVal = trim(toString(qRouteInstance.generated_route_code[1]));
            }

            out.ROUTE_INSTANCE_ID = routeInstanceIdVal;
            out.ROUTE_CODE = routeCodeVal;
            out.MODE = modeVal;

            if (generatedRouteId LTE 0) {
                out.MESSAGE = "Route instance is missing generated route linkage";
                out.ERROR = { "CODE"="MISSING_GENERATED_ROUTE", "MESSAGE"="Route instance does not have a generated route id." };
                return out;
            }

            if (vesselIdVal LTE 0) {
                qPreferredVessel = queryExecute(
                    "SELECT vesselID
                     FROM vessels
                     WHERE userId = :uid
                     ORDER BY vesselID ASC
                     LIMIT 1",
                    { uid = { value=userIdText, cfsqltype="cf_sql_varchar" } },
                    { datasource = application.dsn }
                );
                if (qPreferredVessel.recordCount EQ 0) {
                    out.MESSAGE = "No vessel available";
                    out.ERROR = { "CODE"="NO_VESSEL", "MESSAGE"="A vessel is required before building float plans." };
                    return out;
                }
                vesselIdVal = val(qPreferredVessel.vesselID[1]);
            }

            qRoute = queryExecute(
                "SELECT id, name, short_code
                 FROM loop_routes
                 WHERE id = :rid
                 LIMIT 1",
                { rid = { value=generatedRouteId, cfsqltype="cf_sql_integer" } },
                { datasource = application.dsn }
            );
            if (qRoute.recordCount EQ 0) {
                out.MESSAGE = "Generated route not found";
                out.ERROR = { "CODE"="GENERATED_ROUTE_NOT_FOUND", "MESSAGE"="The generated route for this instance no longer exists." };
                return out;
            }

            var fpLegJoinSql = "";
            var fpSegJoinSql = "";
            var fpUsoJoinSql = "";
            var fpLockJoinSql = "";
            var fpDistExpr = "ril.base_dist_nm";
            var fpLockExpr = "COALESCE(ril.lock_count, 0)";
            var fpSegmentSql = "";

            if (!routegenHasNormalizedLegRows(routeInstanceIdVal)) {
                out.MESSAGE = "Route instance has no normalized legs";
                out.ERROR = { "CODE"="EMPTY_ROUTE_INSTANCE", "MESSAGE"="No normalized route_instance_legs were found for this route instance." };
                return out;
            }

            if (routegenHasLegOverrideTable()) {
                fpLegJoinSql =
                    " LEFT JOIN route_leg_user_overrides rluo_leg
                        ON rluo_leg.user_id = :uidNum
                       AND rluo_leg.route_id = :routeId
                       AND (
                            (ril.source_loop_segment_id IS NOT NULL AND rluo_leg.route_leg_id = ril.source_loop_segment_id)
                            OR
                            (ril.source_loop_segment_id IS NULL AND rluo_leg.route_leg_order = ril.leg_order)
                       )";
                fpSegJoinSql =
                    " LEFT JOIN route_leg_user_overrides rluo_seg
                        ON rluo_seg.user_id = :uidNum
                       AND rluo_seg.route_id = 0
                       AND rluo_seg.segment_id = ril.segment_id";
                fpDistExpr = "COALESCE(rluo_leg.computed_nm, rluo_seg.computed_nm, ril.base_dist_nm)";
            }
            if (routegenHasUserSegmentOverrideTable()) {
                fpUsoJoinSql =
                    " LEFT JOIN user_segment_overrides uso
                        ON uso.user_id = :uidNum
                       AND uso.segment_id = ril.segment_id";
                if (routegenHasLegOverrideTable()) {
                    fpDistExpr = "COALESCE(rluo_leg.computed_nm, rluo_seg.computed_nm, uso.computed_nm, ril.base_dist_nm)";
                } else {
                    fpDistExpr = "COALESCE(uso.computed_nm, ril.base_dist_nm)";
                }
            }
            if (routegenHasRouteLegLocksTable()) {
                fpLockJoinSql =
                    " LEFT JOIN (
                        SELECT route_code, leg, COUNT(*) AS lock_count
                        FROM route_leg_locks
                        GROUP BY route_code, leg
                      ) rll
                        ON rll.route_code COLLATE utf8mb4_unicode_ci = ri.template_route_code
                       AND rll.leg = ril.leg_order";
                fpLockExpr = "COALESCE(rll.lock_count, ril.lock_count, 0)";
            }

            fpSegmentSql =
                "SELECT
                    COALESCE(ris.id, 0) AS section_id,
                    COALESCE(ris.name, 'Section') AS section_name,
                    COALESCE(ris.section_order, 1) AS section_order,
                    COALESCE(ril.source_loop_segment_id, ril.id) AS segment_id,
                    ril.leg_order AS segment_order,
                    ril.start_name,
                    ril.end_name,
                    " & fpDistExpr & " AS dist_nm,
                    " & fpLockExpr & " AS lock_count
                 FROM route_instance_legs ril
                 INNER JOIN route_instances ri ON ri.id = ril.route_instance_id
                 LEFT JOIN route_instance_sections ris ON ris.id = ril.route_instance_section_id"
                & fpLegJoinSql
                & fpSegJoinSql
                & fpUsoJoinSql
                & fpLockJoinSql
                & "
                 WHERE ril.route_instance_id = :routeInstanceId
                 ORDER BY COALESCE(ris.section_order, 1) ASC, ril.leg_order ASC, ril.id ASC";
            qSegments = queryExecute(
                fpSegmentSql,
                {
                    routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" },
                    routeId = { value=generatedRouteId, cfsqltype="cf_sql_integer" },
                    uidNum = { value=arguments.userId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );
            if (qSegments.recordCount EQ 0) {
                out.MESSAGE = "Generated route has no segments";
                out.ERROR = { "CODE"="EMPTY_ROUTE", "MESSAGE"="Cannot build float plans from an empty route." };
                return out;
            }

            for (i = 1; i LTE qSegments.recordCount; i++) {
                sid = toString(qSegments.section_id[i]);
                if (!structKeyExists(sectionMap, sid)) {
                    secObj = {
                        "SECTION_ID"=qSegments.section_id[i],
                        "SECTION_NAME"=(isNull(qSegments.section_name[i]) ? "Section" : qSegments.section_name[i]),
                        "SECTION_ORDER"=val(qSegments.section_order[i]),
                        "START_NAME"=(isNull(qSegments.start_name[i]) ? "" : trim(toString(qSegments.start_name[i]))),
                        "END_NAME"=(isNull(qSegments.end_name[i]) ? "" : trim(toString(qSegments.end_name[i]))),
                        "TOTAL_NM"=0.0,
                        "TOTAL_LOCKS"=0,
                        "SEGMENT_COUNT"=0
                    };
                    sectionMap[sid] = secObj;
                    arrayAppend(sectionOrder, sid);
                }
                if (len(trim(toString(qSegments.end_name[i])))) {
                    sectionMap[sid].END_NAME = trim(toString(qSegments.end_name[i]));
                }
                sectionMap[sid].TOTAL_NM = sectionMap[sid].TOTAL_NM + val(qSegments.dist_nm[i]);
                sectionMap[sid].TOTAL_LOCKS = sectionMap[sid].TOTAL_LOCKS + val(qSegments.lock_count[i]);
                sectionMap[sid].SEGMENT_COUNT = sectionMap[sid].SEGMENT_COUNT + 1;
                totalNm = totalNm + val(qSegments.dist_nm[i]);
                totalLocks = totalLocks + val(qSegments.lock_count[i]);
            }

            if (modeVal EQ "SINGLE_MASTER") {
                dayObj = {
                    "DAY_NUMBER"=1,
                    "LABEL"="Day 1 - Full Route",
                    "START_NAME"=(isNull(qSegments.start_name[1]) ? "" : trim(toString(qSegments.start_name[1]))),
                    "END_NAME"=(isNull(qSegments.end_name[qSegments.recordCount]) ? "" : trim(toString(qSegments.end_name[qSegments.recordCount]))),
                    "TOTAL_NM"=roundTo2(totalNm),
                    "TOTAL_LOCKS"=totalLocks,
                    "SEGMENT_COUNT"=qSegments.recordCount
                };
                if (!len(dayObj.START_NAME)) dayObj.START_NAME = "Unknown Start";
                if (!len(dayObj.END_NAME)) dayObj.END_NAME = "Unknown End";
                arrayAppend(dayRows, dayObj);
            } else {
                dayNum = 0;
                for (i = 1; i LTE arrayLen(sectionOrder); i++) {
                    secObj = sectionMap[sectionOrder[i]];
                    if (secObj.SEGMENT_COUNT LTE 0) continue;
                    dayNum += 1;
                    dayObj = {
                        "DAY_NUMBER"=dayNum,
                        "LABEL"=("Day " & dayNum & " - " & secObj.SECTION_NAME),
                        "START_NAME"=(len(secObj.START_NAME) ? secObj.START_NAME : "Unknown Start"),
                        "END_NAME"=(len(secObj.END_NAME) ? secObj.END_NAME : "Unknown End"),
                        "TOTAL_NM"=roundTo2(secObj.TOTAL_NM),
                        "TOTAL_LOCKS"=secObj.TOTAL_LOCKS,
                        "SEGMENT_COUNT"=secObj.SEGMENT_COUNT
                    };
                    arrayAppend(dayRows, dayObj);
                }
            }

            if (!arrayLen(dayRows)) {
                out.MESSAGE = "No route days to build";
                out.ERROR = { "CODE"="NO_DAYS", "MESSAGE"="Could not derive any float plan days from route segments." };
                return out;
            }

            var qExisting = queryExecute(
                "SELECT floatPlanId, status
                 FROM floatplans
                 WHERE userId = :uid
                   AND route_instance_id = :routeInstanceId
                 ORDER BY floatPlanId DESC",
                {
                    uid = { value=userIdText, cfsqltype="cf_sql_varchar" },
                    routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );
            existingCount = qExisting.recordCount;

            if (existingCount GT 0 AND NOT rebuildVal) {
                out.MESSAGE = "Float plans already exist for this route instance.";
                out.ERROR = {
                    "CODE"="FLOATPLANS_ALREADY_EXIST",
                    "MESSAGE"="Float plans already exist. Re-run with rebuild=true to replace draft/closed plans."
                };
                out.EXISTING_COUNT = existingCount;
                return out;
            }

            if (existingCount GT 0 AND rebuildVal) {
                activeExistingCount = 0;
                for (i = 1; i LTE qExisting.recordCount; i++) {
                    if (listFindNoCase("DRAFT,CLOSED,COMPLETED,CANCELLED,CANCELED", trim(toString(qExisting.status[i]))) EQ 0) {
                        activeExistingCount += 1;
                    }
                }
                if (activeExistingCount GT 0) {
                    out.MESSAGE = "Cannot rebuild while active route-linked float plans exist.";
                    out.ERROR = {
                        "CODE"="FLOATPLANS_REBUILD_BLOCKED",
                        "MESSAGE"="Only draft/closed/completed/cancelled route-linked float plans may be replaced."
                    };
                    out.ACTIVE_EXISTING_COUNT = activeExistingCount;
                    return out;
                }
            }

            transaction {
                if (existingCount GT 0 AND rebuildVal) {
                    queryExecute(
                        "DELETE FROM floatplans
                         WHERE userId = :uid
                           AND route_instance_id = :routeInstanceId",
                        {
                            uid = { value=userIdText, cfsqltype="cf_sql_varchar" },
                            routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" }
                        },
                        { datasource = application.dsn }
                    );
                }

                for (i = 1; i LTE arrayLen(dayRows); i++) {
                    dayObj = dayRows[i];
                    planName = trim(toString(qRoute.name[1])) & " - " & dayObj.LABEL;
                    notesVal = "Auto-generated from route " & routeCodeVal & " (" & modeVal & "). "
                        & dayObj.START_NAME & " to " & dayObj.END_NAME & ". "
                        & dayObj.TOTAL_NM & " NM, " & dayObj.TOTAL_LOCKS & " locks.";

                    queryExecute(
                        "INSERT INTO floatplans
                            (userId, floatPlanName, vesselId, departing, returning, notes, route_instance_id, route_day_number, status, dateCreated, lastUpdate)
                         VALUES
                            (:userId, :planName, :vesselId, :departing, :returning, :notes, :routeInstanceId, :routeDayNumber, 'Draft', NOW(), NOW())",
                        {
                            userId = { value=userIdText, cfsqltype="cf_sql_varchar" },
                            planName = { value=planName, cfsqltype="cf_sql_varchar" },
                            vesselId = { value=vesselIdVal, cfsqltype="cf_sql_integer", null=(vesselIdVal LTE 0) },
                            departing = { value=dayObj.START_NAME, cfsqltype="cf_sql_varchar", null=NOT len(dayObj.START_NAME) },
                            returning = { value=dayObj.END_NAME, cfsqltype="cf_sql_varchar", null=NOT len(dayObj.END_NAME) },
                            notes = { value=notesVal, cfsqltype="cf_sql_varchar", null=NOT len(notesVal) },
                            routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" },
                            routeDayNumber = { value=dayObj.DAY_NUMBER, cfsqltype="cf_sql_integer" }
                        },
                        { datasource = application.dsn, result = "fpInsert" }
                    );
                    newPlanId = val(fpInsert.generatedKey);
                    arrayAppend(out.FLOATPLAN_IDS, newPlanId);
                    arrayAppend(out.FLOATPLANS, {
                        "FLOATPLAN_ID"=newPlanId,
                        "ROUTE_DAY_NUMBER"=dayObj.DAY_NUMBER,
                        "LABEL"=dayObj.LABEL,
                        "START_NAME"=dayObj.START_NAME,
                        "END_NAME"=dayObj.END_NAME,
                        "TOTAL_NM"=dayObj.TOTAL_NM,
                        "TOTAL_LOCKS"=dayObj.TOTAL_LOCKS
                    });
                }
            }

            out.SUCCESS = true;
            out.CREATED_COUNT = arrayLen(out.FLOATPLAN_IDS);
            if (existingCount GT 0 AND rebuildVal) {
                out.MESSAGE = "Rebuilt " & out.CREATED_COUNT & " float plans from route.";
                out.REBUILT = true;
                out.REMOVED_EXISTING_COUNT = existingCount;
            } else {
                out.MESSAGE = "Built " & out.CREATED_COUNT & " float plans from route.";
                out.REBUILT = false;
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="setActiveRoute" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeCode" type="string" required="true">
        <cfscript>
            var code = trim(arguments.routeCode);
            if (!isUserOwnedRoute(arguments.userId, code)) {
                return {
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Route not found",
                    "ERROR"={"MESSAGE"="Route is not available for this user."}
                };
            }
            session.expeditionRouteCode = code;
            return { "SUCCESS"=true, "AUTH"=true, "MESSAGE"="OK", "ACTIVE_ROUTE_CODE"=code };
        </cfscript>
    </cffunction>

    <cffunction name="isUserOwnedRoute" access="private" returntype="boolean" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeCode" type="string" required="true">
        <cfscript>
            var prefix = "USER_ROUTE_" & int(arguments.userId) & "_%";
            var q = queryExecute(
                "SELECT id
                 FROM loop_routes
                 WHERE short_code = :code
                   AND short_code LIKE :prefix
                 LIMIT 1",
                {
                    code = { value=arguments.routeCode, cfsqltype="cf_sql_varchar" },
                    prefix = { value=prefix, cfsqltype="cf_sql_varchar" }
                },
                { datasource = application.dsn }
            );
            return q.recordCount GT 0;
        </cfscript>
    </cffunction>

	    <cffunction name="deleteRoute" access="private" returntype="struct" output="false">
	        <cfargument name="userId" type="numeric" required="true">
	        <cfargument name="routeCode" type="string" required="true">
	        <cfscript>
	            var code = trim(arguments.routeCode);
	            var userIdText = toString(arguments.userId);
	            var qRouteInstancesTbl = queryNew("");
	            var hasRouteInstancesTbl = false;
	            var qFloatplanRouteCols = queryNew("");
	            var hasFloatplanRouteCols = false;
	            if (!isUserOwnedRoute(arguments.userId, code)) {
	                return {
	                    "SUCCESS"=false,
	                    "AUTH"=true,
	                    "MESSAGE"="Route not found",
                    "ERROR"={"MESSAGE"="Route is not available for this user."}
                };
            }

            var qRoute = queryExecute(
                "SELECT id
                 FROM loop_routes
                 WHERE short_code = :code
                 LIMIT 1",
                { code = { value=code, cfsqltype="cf_sql_varchar" } },
                { datasource = application.dsn }
            );
            if (qRoute.recordCount EQ 0) {
                return {
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Route not found",
                    "ERROR"={"MESSAGE"="Route does not exist."}
                };
	            }

	            var routeId = val(qRoute.id[1]);
	            qRouteInstancesTbl = queryExecute(
	                "SELECT COUNT(*) AS cnt
	                 FROM information_schema.tables
	                 WHERE table_schema = DATABASE()
	                   AND table_name = 'route_instances'",
	                {},
	                { datasource = application.dsn }
	            );
	            hasRouteInstancesTbl = (qRouteInstancesTbl.recordCount GT 0 AND val(qRouteInstancesTbl.cnt[1]) GT 0);
	            if (hasRouteInstancesTbl) {
	                qFloatplanRouteCols = queryExecute(
	                    "SELECT COUNT(*) AS cnt
	                     FROM information_schema.columns
	                     WHERE table_schema = DATABASE()
	                       AND table_name = 'floatplans'
	                       AND column_name IN ('route_instance_id', 'route_day_number')",
	                    {},
	                    { datasource = application.dsn }
	                );
	                hasFloatplanRouteCols = (qFloatplanRouteCols.recordCount GT 0 AND val(qFloatplanRouteCols.cnt[1]) GTE 2);
	            }
	            transaction {
	                if (hasRouteInstancesTbl AND hasFloatplanRouteCols) {
	                    queryExecute(
	                        "UPDATE floatplans fp
	                           INNER JOIN route_instances ri ON ri.id = fp.route_instance_id
	                           SET fp.route_instance_id = NULL,
	                               fp.route_day_number = NULL
	                         WHERE ri.user_id = :uid
	                           AND (
	                               ri.generated_route_id = :rid
	                               OR ri.generated_route_code = :rcode
	                           )",
	                        {
	                            uid = { value=userIdText, cfsqltype="cf_sql_varchar" },
	                            rid = { value=routeId, cfsqltype="cf_sql_integer" },
	                            rcode = { value=code, cfsqltype="cf_sql_varchar" }
	                        },
	                        { datasource = application.dsn }
	                    );
	                }
	                if (routegenHasLegOverrideTable()) {
	                    queryExecute(
	                        "DELETE rluo
	                           FROM route_leg_user_overrides rluo
	                          WHERE rluo.user_id = :uid
	                            AND rluo.route_id = :rid",
	                        {
	                            uid = { value=arguments.userId, cfsqltype="cf_sql_integer" },
	                            rid = { value=routeId, cfsqltype="cf_sql_integer" }
	                        },
	                        { datasource = application.dsn }
	                    );
	                }
	                if (hasRouteInstancesTbl) {
                        if (routegenHasNormalizedTables()) {
                            queryExecute(
                                "DELETE rilp
                                 FROM route_instance_leg_progress rilp
                                 INNER JOIN route_instances ri ON ri.id = rilp.route_instance_id
                                 WHERE ri.user_id = :uid
                                   AND (
                                       ri.generated_route_id = :rid
                                       OR ri.generated_route_code = :rcode
                                   )",
                                {
                                    uid = { value=userIdText, cfsqltype="cf_sql_varchar" },
                                    rid = { value=routeId, cfsqltype="cf_sql_integer" },
                                    rcode = { value=code, cfsqltype="cf_sql_varchar" }
                                },
                                { datasource = application.dsn }
                            );
                            queryExecute(
                                "DELETE ril
                                 FROM route_instance_legs ril
                                 INNER JOIN route_instances ri ON ri.id = ril.route_instance_id
                                 WHERE ri.user_id = :uid
                                   AND (
                                       ri.generated_route_id = :rid
                                       OR ri.generated_route_code = :rcode
                                   )",
                                {
                                    uid = { value=userIdText, cfsqltype="cf_sql_varchar" },
                                    rid = { value=routeId, cfsqltype="cf_sql_integer" },
                                    rcode = { value=code, cfsqltype="cf_sql_varchar" }
                                },
                                { datasource = application.dsn }
                            );
                            queryExecute(
                                "DELETE ris
                                 FROM route_instance_sections ris
                                 INNER JOIN route_instances ri ON ri.id = ris.route_instance_id
                                 WHERE ri.user_id = :uid
                                   AND (
                                       ri.generated_route_id = :rid
                                       OR ri.generated_route_code = :rcode
                                   )",
                                {
                                    uid = { value=userIdText, cfsqltype="cf_sql_varchar" },
                                    rid = { value=routeId, cfsqltype="cf_sql_integer" },
                                    rcode = { value=code, cfsqltype="cf_sql_varchar" }
                                },
                                { datasource = application.dsn }
                            );
                        }
	                    queryExecute(
	                        "DELETE FROM route_instances
	                         WHERE user_id = :uid
	                           AND (
	                               generated_route_id = :rid
	                               OR generated_route_code = :rcode
	                           )",
	                        {
	                            uid = { value=userIdText, cfsqltype="cf_sql_varchar" },
	                            rid = { value=routeId, cfsqltype="cf_sql_integer" },
	                            rcode = { value=code, cfsqltype="cf_sql_varchar" }
	                        },
	                        { datasource = application.dsn }
	                    );
	                }
	                queryExecute(
	                    "DELETE FROM loop_routes
	                     WHERE id = :rid",
                    { rid = { value=routeId, cfsqltype="cf_sql_integer" } },
                    { datasource = application.dsn }
                );
            }

            if (structKeyExists(session, "expeditionRouteCode") AND toString(session.expeditionRouteCode) EQ code) {
                structDelete(session, "expeditionRouteCode");
            }
            return { "SUCCESS"=true, "AUTH"=true, "MESSAGE"="Route deleted", "ROUTE_CODE"=code };
        </cfscript>
    </cffunction>

    <cffunction name="getTimeline" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeCode" type="string" required="true">
        <cfset var resp = {
            "SUCCESS"=true,
            "AUTH"=true,
            "MESSAGE"="OK",
            "ROUTE"={},
            "TOTALS"={},
            "SECTIONS"=[]
        } />

        <cfset var qRoute = queryExecute(
            "SELECT id, name, short_code, description, is_default
             FROM loop_routes
             WHERE short_code = :code
             LIMIT 1",
            { code = { value=arguments.routeCode, cfsqltype="cf_sql_varchar" } },
            { datasource = application.dsn }
        ) />
        <cfif qRoute.recordCount EQ 0>
            <cfset resp.SUCCESS = false />
            <cfset resp.MESSAGE = "Route not found" />
            <cfset resp.ERROR = { "MESSAGE"="No loop_routes row for short_code=" & arguments.routeCode } />
            <cfreturn resp />
        </cfif>

        <cfset var routeId = qRoute.id[1] />
        <cfset resp.ROUTE = {
            "ID"=routeId,
            "NAME"=qRoute.name[1],
            "SHORT_CODE"=qRoute.short_code[1],
            "DESCRIPTION"=qRoute.description[1],
            "IS_DEFAULT"=(qRoute.is_default[1] EQ 1)
        } />

        <cfset var routeInstanceIdVal = routegenResolveLatestRouteInstanceId(arguments.userId, routeId) />
        <cfset var qSections = queryNew("") />
        <cfset var qSegments = queryNew("") />
        <cfset var qProg = queryNew("") />
        <cfset var qSegmentsSql = "" />
        <cfset var normalizedLegJoinSql = "" />
        <cfset var normalizedSegJoinSql = "" />
        <cfset var normalizedUsoJoinSql = "" />
        <cfset var normalizedLockJoinSql = "" />
        <cfset var normalizedDistExpr = "ril.base_dist_nm" />
        <cfset var normalizedLockExpr = "COALESCE(ril.lock_count, 0)" />
        <cfset var normalizedBinds = {} />

        <cfif NOT routegenHasNormalizedLegRows(routeInstanceIdVal)>
            <cfset resp.SUCCESS = false />
            <cfset resp.MESSAGE = "Route timeline unavailable" />
            <cfset resp.ERROR = { "MESSAGE"="Route instance has no normalized leg rows." } />
            <cfreturn resp />
        </cfif>

        <cfset qSections = queryExecute(
            "SELECT
                id,
                name,
                '' AS short_code,
                COALESCE(phase_num, 1) AS phase_num,
                section_order AS order_index,
                CASE WHEN section_order = 1 THEN 1 ELSE 0 END AS is_active_default
             FROM route_instance_sections
             WHERE route_instance_id = :routeInstanceId
             ORDER BY section_order ASC, id ASC",
            {
                routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" }
            },
            { datasource = application.dsn }
        ) />

        <cfset normalizedBinds = {
            routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" },
            routeId = { value=routeId, cfsqltype="cf_sql_integer" },
            uid = { value=arguments.userId, cfsqltype="cf_sql_integer" },
            uidNum = { value=arguments.userId, cfsqltype="cf_sql_integer" }
        } />

        <cfif routegenHasLegOverrideTable()>
            <cfset normalizedLegJoinSql =
                " LEFT JOIN route_leg_user_overrides rluo_leg
                    ON rluo_leg.user_id = :uidNum
                   AND rluo_leg.route_id = :routeId
                   AND (
                        (ril.source_loop_segment_id IS NOT NULL AND rluo_leg.route_leg_id = ril.source_loop_segment_id)
                        OR
                        (ril.source_loop_segment_id IS NULL AND rluo_leg.route_leg_order = ril.leg_order)
                   )" />
            <cfset normalizedSegJoinSql =
                " LEFT JOIN route_leg_user_overrides rluo_seg
                    ON rluo_seg.user_id = :uidNum
                   AND rluo_seg.route_id = 0
                   AND rluo_seg.segment_id = ril.segment_id" />
            <cfset normalizedDistExpr = "COALESCE(rluo_leg.computed_nm, rluo_seg.computed_nm, ril.base_dist_nm)" />
        </cfif>

        <cfif routegenHasUserSegmentOverrideTable()>
            <cfset normalizedUsoJoinSql =
                " LEFT JOIN user_segment_overrides uso
                    ON uso.user_id = :uidNum
                   AND uso.segment_id = ril.segment_id" />
            <cfif routegenHasLegOverrideTable()>
                <cfset normalizedDistExpr = "COALESCE(rluo_leg.computed_nm, rluo_seg.computed_nm, uso.computed_nm, ril.base_dist_nm)" />
            <cfelse>
                <cfset normalizedDistExpr = "COALESCE(uso.computed_nm, ril.base_dist_nm)" />
            </cfif>
        </cfif>

        <cfif routegenHasRouteLegLocksTable()>
            <cfset normalizedLockJoinSql =
                " LEFT JOIN (
                    SELECT route_code, leg, COUNT(*) AS lock_count
                    FROM route_leg_locks
                    GROUP BY route_code, leg
                  ) rll
                    ON rll.route_code COLLATE utf8mb4_unicode_ci = ri.template_route_code
                   AND rll.leg = ril.leg_order" />
            <cfset normalizedLockExpr = "COALESCE(rll.lock_count, ril.lock_count, 0)" />
        </cfif>

        <cfset qSegmentsSql =
            "SELECT
                COALESCE(ril.source_loop_segment_id, ril.id) AS id,
                COALESCE(ris.id, 0) AS section_id,
                ril.leg_order AS order_index,
                ril.start_name,
                ril.end_name,
                " & normalizedDistExpr & " AS dist_nm,
                " & normalizedLockExpr & " AS lock_count,
                NULL AS rm_start,
                NULL AS rm_end,
                0 AS is_signature_event,
                0 AS is_milestone_end,
                COALESCE(ril.notes, '') AS notes,
                COALESCE(ris.section_order, 1) AS section_order
             FROM route_instance_legs ril
             INNER JOIN route_instances ri ON ri.id = ril.route_instance_id
             LEFT JOIN route_instance_sections ris ON ris.id = ril.route_instance_section_id"
            & normalizedLegJoinSql
            & normalizedSegJoinSql
            & normalizedUsoJoinSql
            & normalizedLockJoinSql
            & "
             WHERE ril.route_instance_id = :routeInstanceId
             ORDER BY COALESCE(ris.section_order, 1) ASC, ril.leg_order ASC, ril.id ASC" />
        <cfset qSegments = queryExecute(
            qSegmentsSql,
            normalizedBinds,
            { datasource = application.dsn }
        ) />

        <cfset qProg = queryExecute(
            "SELECT
                COALESCE(ril.source_loop_segment_id, ril.id) AS segment_id,
                rilp.status,
                rilp.completed_at
             FROM route_instance_leg_progress rilp
             INNER JOIN route_instance_legs ril
                ON ril.route_instance_id = rilp.route_instance_id
               AND ril.leg_order = rilp.leg_order
             WHERE rilp.route_instance_id = :routeInstanceId
               AND rilp.user_id = :uid
             ORDER BY ril.leg_order ASC",
            {
                routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" },
                uid = { value=arguments.userId, cfsqltype="cf_sql_integer" }
            },
            { datasource = application.dsn }
        ) />

        <cfset var progressBySeg = {} />
        <cfloop query="qProg">
            <cfset progressBySeg[toString(qProg.segment_id)] = {
                "STATUS"=qProg.status,
                "COMPLETED_AT"=(isNull(qProg.completed_at) ? "" : dateTimeFormat(qProg.completed_at, "yyyy-mm-dd HH:nn:ss"))
            } />
        </cfloop>

        <cfset var sections = [] />
        <cfset var sectionIndexById = {} />
        <cfset var totalNm = 0.0 />
        <cfset var totalLocks = 0 />
        <cfset var completedNm = 0.0 />
        <cfset var completedLocks = 0 />

        <cfset var i = 0 />
        <cfloop query="qSections">
            <cfset var secObj = {
                "ID"=qSections.id,
                "NAME"=qSections.name,
                "SHORT_CODE"=qSections.short_code,
                "PHASE_NUM"=qSections.phase_num,
                "ORDER_INDEX"=qSections.order_index,
                "IS_ACTIVE_DEFAULT"=(qSections.is_active_default EQ 1),
                "TOTALS"={
                    "NM"=0.0,
                    "LOCKS"=0,
                    "COMPLETED_NM"=0.0,
                    "COMPLETED_LOCKS"=0,
                    "PCT_COMPLETE"=0
                },
                "SEGMENTS"=[]
            } />
            <cfset arrayAppend(sections, secObj) />
            <cfset sectionIndexById[toString(qSections.id)] = arrayLen(sections) />
        </cfloop>

        <cfloop query="qSegments">
            <cfset var sid = toString(qSegments.section_id) />
            <cfif NOT structKeyExists(sectionIndexById, sid)>
                <cfcontinue />
            </cfif>
            <cfset var idx = sectionIndexById[sid] />
            <cfset var segIdStr = toString(qSegments.id) />
            <cfset var prog = (structKeyExists(progressBySeg, segIdStr) ? progressBySeg[segIdStr] : {"STATUS"="NOT_STARTED","COMPLETED_AT"=""}) />
            <cfset var isCompleted = (uCase(prog.STATUS) EQ "COMPLETED") />

            <cfset var segObj = {
                "ID"=qSegments.id,
                "ORDER_INDEX"=qSegments.order_index,
                "START_NAME"=(isNull(qSegments.start_name) ? "" : qSegments.start_name),
                "END_NAME"=(isNull(qSegments.end_name) ? "" : qSegments.end_name),
                "DIST_NM"=val(qSegments.dist_nm),
                "LOCK_COUNT"=val(qSegments.lock_count),
                "RM_START"=(isNull(qSegments.rm_start) ? "" : val(qSegments.rm_start)),
                "RM_END"=(isNull(qSegments.rm_end) ? "" : val(qSegments.rm_end)),
                "IS_SIGNATURE_EVENT"=(qSegments.is_signature_event EQ 1),
                "IS_MILESTONE_END"=(qSegments.is_milestone_end EQ 1),
                "NOTES"=(isNull(qSegments.notes) ? "" : qSegments.notes),
                "PROGRESS"=prog
            } />
            <cfset arrayAppend(sections[idx].SEGMENTS, segObj) />

            <cfset totalNm = totalNm + val(qSegments.dist_nm) />
            <cfset totalLocks = totalLocks + val(qSegments.lock_count) />
            <cfset sections[idx].TOTALS.NM = sections[idx].TOTALS.NM + val(qSegments.dist_nm) />
            <cfset sections[idx].TOTALS.LOCKS = sections[idx].TOTALS.LOCKS + val(qSegments.lock_count) />

            <cfif isCompleted>
                <cfset completedNm = completedNm + val(qSegments.dist_nm) />
                <cfset completedLocks = completedLocks + val(qSegments.lock_count) />
                <cfset sections[idx].TOTALS.COMPLETED_NM = sections[idx].TOTALS.COMPLETED_NM + val(qSegments.dist_nm) />
                <cfset sections[idx].TOTALS.COMPLETED_LOCKS = sections[idx].TOTALS.COMPLETED_LOCKS + val(qSegments.lock_count) />
            </cfif>
        </cfloop>

        <cfset var filteredSections = [] />
        <cfloop from="1" to="#arrayLen(sections)#" index="i">
            <cfif sections[i].TOTALS.NM GT 0>
                <cfset sections[i].TOTALS.PCT_COMPLETE = round((sections[i].TOTALS.COMPLETED_NM / sections[i].TOTALS.NM) * 100) />
            <cfelse>
                <cfset sections[i].TOTALS.PCT_COMPLETE = 0 />
            </cfif>
            <cfif arrayLen(sections[i].SEGMENTS) GT 0>
                <cfset arrayAppend(filteredSections, sections[i]) />
            </cfif>
        </cfloop>

        <cfif arrayLen(filteredSections) GT 0>
            <cfset var hasDefaultSection = false />
            <cfloop from="1" to="#arrayLen(filteredSections)#" index="i">
                <cfif filteredSections[i].IS_ACTIVE_DEFAULT>
                    <cfset hasDefaultSection = true />
                    <cfbreak />
                </cfif>
            </cfloop>
            <cfif NOT hasDefaultSection>
                <cfset filteredSections[1].IS_ACTIVE_DEFAULT = true />
            </cfif>
        </cfif>

        <cfset resp.TOTALS = {
            "TOTAL_NM"=roundTo2(totalNm),
            "TOTAL_LOCKS"=totalLocks,
            "COMPLETED_NM"=roundTo2(completedNm),
            "COMPLETED_LOCKS"=completedLocks,
            "PCT_COMPLETE"=(totalNm GT 0 ? round((completedNm/totalNm)*100) : 0)
        } />
        <cfset resp.SECTIONS = filteredSections />
        <cfreturn resp />
    </cffunction>

    <cffunction name="generateCruiseTimeline" access="private" returntype="struct" output="false">
        <cfargument name="routeId" type="numeric" required="true">
        <cfargument name="startDate" type="string" required="true">
        <cfargument name="maxHoursPerDay" type="numeric" required="false" default="6.5">
        <cfscript>
            var out = {
                "success"=false,
                "route_summary"={
                    "total_days"=0,
                    "total_nm"=0,
                    "total_required_fuel"=0
                },
                "days"=[]
            };
            var userStruct = {};
            var userId = 0;
            var routeIdVal = val(arguments.routeId);
            var startDateVal = trim(toString(arguments.startDate));
            var maxHoursVal = val(arguments.maxHoursPerDay);
            var currentDate = now();
            var hasInputsJsonCol = false;
            var qInstSql = "";
            var qInst = queryNew("");
            var routeInstanceIdVal = 0;
            var storedInputs = {};
            var paceVal = "RELAXED";
            var paceDefaults = {};
            var paceRatioVal = 0;
            var maxSpeedVal = 0;
            var effectiveSpeedVal = 0;
            var fuelBurnGphVal = 0;
            var reservePctVal = 20;
            var normalizedLegJoinSql = "";
            var normalizedSegJoinSql = "";
            var normalizedUsoJoinSql = "";
            var normalizedLockJoinSql = "";
            var normalizedDistExpr = "ril.base_dist_nm";
            var normalizedLockExpr = "COALESCE(ril.lock_count, 0)";
            var qSegmentsSql = "";
            var qSegments = queryNew("");
            var i = 0;
            var segIdVal = 0;
            var segStartName = "";
            var segEndName = "";
            var segDistNm = 0;
            var segLockCount = 0;
            var segHours = 0;
            var legIndex = 1;
            var days = [];
            var totalCruiseNm = 0;
            var totalRequiredFuel = 0;
            var currentDay = {
                "date"="",
                "leg_index"=1,
                "start_name"="",
                "end_name"="",
                "total_dist_nm"=0,
                "est_hours"=0,
                "cruise_fuel_gallons"=0,
                "reserve_gallons"=0,
                "required_fuel_gallons"=0,
                "fuel_confidence_score"=0,
                "risk_color"="GREEN",
                "lock_count"=0,
                "segment_ids"=[]
            };
            var fuelEstimate = {};
            var requiredFuelGallonsVal = 0;
            var reserveGallonsVal = 0;
            var reserveRatio = 0;
            var fuelConfidenceScore = 100;

            if (structKeyExists(session, "user") AND isStruct(session.user)) {
                userStruct = session.user;
            }
            userId = resolveUserId(userStruct);
            if (userId LTE 0) {
                out.message = "Unauthorized";
                out.error = { "message"="No logged-in user session." };
                return out;
            }

            if (routeIdVal LTE 0) {
                out.message = "routeId required";
                out.error = { "message"="routeId must be a positive numeric value." };
                return out;
            }
            if (!len(startDateVal) OR !reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", startDateVal)) {
                out.message = "Invalid startDate";
                out.error = { "message"="startDate must be yyyy-mm-dd." };
                return out;
            }
            try {
                currentDate = parseDateTime(startDateVal);
            } catch (any eDate) {
                out.message = "Invalid startDate";
                out.error = { "message"="Unable to parse startDate." };
                return out;
            }
            if (maxHoursVal LTE 0) maxHoursVal = 6.5;
            if (maxHoursVal LT 4) maxHoursVal = 4;
            if (maxHoursVal GT 12) maxHoursVal = 12;
            maxHoursVal = roundTo2(maxHoursVal);

            hasInputsJsonCol = routegenHasInputsJsonColumn();
            qInstSql = "SELECT id, template_route_code";
            if (hasInputsJsonCol) {
                qInstSql &= ", routegen_inputs_json";
            }
            qInstSql &= "
                FROM route_instances
                WHERE generated_route_id = :routeId
                  AND user_id = :uid
                ORDER BY id DESC
                LIMIT 1";
            qInst = queryExecute(
                qInstSql,
                {
                    routeId = { value=routeIdVal, cfsqltype="cf_sql_integer" },
                    uid = { value=toString(userId), cfsqltype="cf_sql_varchar" }
                },
                { datasource = application.dsn }
            );
            if (qInst.recordCount EQ 0) {
                out.message = "Route not found";
                out.error = { "message"="Route not found or not owned by user." };
                return out;
            }

            routeInstanceIdVal = val(qInst.id[1]);
            if (!routegenHasNormalizedLegRows(routeInstanceIdVal)) {
                out.message = "Route timeline unavailable";
                out.error = { "message"="Route instance has no normalized leg rows." };
                return out;
            }

            if (hasInputsJsonCol AND !isNull(qInst.routegen_inputs_json[1])) {
                storedInputs = routegenParseStoredInputs(qInst.routegen_inputs_json[1]);
            }
            paceVal = routegenNormalizePace(structKeyExists(storedInputs, "pace") ? storedInputs.pace : "RELAXED");
            paceDefaults = routegenPaceDefaults(paceVal);
            paceRatioVal = val(paceDefaults.PACE_FACTOR);
            if (paceRatioVal LT 0.05) paceRatioVal = 0.05;
            if (paceRatioVal GT 1) paceRatioVal = 1;
            maxSpeedVal = routegenNormalizeCruisingSpeed(
                structKeyExists(storedInputs, "cruising_speed") ? storedInputs.cruising_speed : "",
                paceDefaults.MAX_SPEED_KN
            );
            effectiveSpeedVal = routegenComputeEffectiveCruisingSpeed(maxSpeedVal, paceVal);
            if (effectiveSpeedVal LTE 0) effectiveSpeedVal = 1;
            fuelBurnGphVal = routegenNormalizeFuelBurnGph(
                structKeyExists(storedInputs, "fuel_burn_gph") ? storedInputs.fuel_burn_gph : ""
            );
            reservePctVal = routegenNormalizeReservePct(
                structKeyExists(storedInputs, "reserve_pct") ? storedInputs.reserve_pct : "",
                20
            );

            if (routegenHasLegOverrideTable()) {
                normalizedLegJoinSql =
                    " LEFT JOIN route_leg_user_overrides rluo_leg
                        ON rluo_leg.user_id = :uidNum
                       AND rluo_leg.route_id = :routeId
                       AND (
                            (ril.source_loop_segment_id IS NOT NULL AND rluo_leg.route_leg_id = ril.source_loop_segment_id)
                            OR
                            (ril.source_loop_segment_id IS NULL AND rluo_leg.route_leg_order = ril.leg_order)
                       )";
                normalizedSegJoinSql =
                    " LEFT JOIN route_leg_user_overrides rluo_seg
                        ON rluo_seg.user_id = :uidNum
                       AND rluo_seg.route_id = 0
                       AND rluo_seg.segment_id = ril.segment_id";
                normalizedDistExpr = "COALESCE(rluo_leg.computed_nm, rluo_seg.computed_nm, ril.base_dist_nm)";
            }
            if (routegenHasUserSegmentOverrideTable()) {
                normalizedUsoJoinSql =
                    " LEFT JOIN user_segment_overrides uso
                        ON uso.user_id = :uidNum
                       AND uso.segment_id = ril.segment_id";
                if (routegenHasLegOverrideTable()) {
                    normalizedDistExpr = "COALESCE(rluo_leg.computed_nm, rluo_seg.computed_nm, uso.computed_nm, ril.base_dist_nm)";
                } else {
                    normalizedDistExpr = "COALESCE(uso.computed_nm, ril.base_dist_nm)";
                }
            }
            if (routegenHasRouteLegLocksTable()) {
                normalizedLockJoinSql =
                    " LEFT JOIN (
                        SELECT route_code, leg, COUNT(*) AS lock_count
                        FROM route_leg_locks
                        GROUP BY route_code, leg
                      ) rll
                        ON rll.route_code COLLATE utf8mb4_unicode_ci = ri.template_route_code
                       AND rll.leg = ril.leg_order";
                normalizedLockExpr = "COALESCE(rll.lock_count, ril.lock_count, 0)";
            }

            qSegmentsSql =
                "SELECT
                    COALESCE(ril.source_loop_segment_id, ril.id) AS id,
                    ril.start_name,
                    ril.end_name,
                    " & normalizedDistExpr & " AS dist_nm,
                    " & normalizedLockExpr & " AS lock_count
                 FROM route_instance_legs ril
                 INNER JOIN route_instances ri ON ri.id = ril.route_instance_id"
                & normalizedLegJoinSql
                & normalizedSegJoinSql
                & normalizedUsoJoinSql
                & normalizedLockJoinSql
                & "
                 WHERE ril.route_instance_id = :routeInstanceId
                 ORDER BY ril.leg_order ASC, ril.id ASC";
            qSegments = queryExecute(
                qSegmentsSql,
                {
                    routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" },
                    routeId = { value=routeIdVal, cfsqltype="cf_sql_integer" },
                    uidNum = { value=userId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );
            if (qSegments.recordCount EQ 0) {
                out.message = "Route has no segments";
                out.error = { "message"="No route segments are available for this route instance." };
                return out;
            }

            currentDay = {
                "date"=dateFormat(currentDate, "yyyy-mm-dd"),
                "leg_index"=legIndex,
                "start_name"="",
                "end_name"="",
                "total_dist_nm"=0,
                "est_hours"=0,
                "cruise_fuel_gallons"=0,
                "reserve_gallons"=0,
                "required_fuel_gallons"=0,
                "fuel_confidence_score"=0,
                "risk_color"="GREEN",
                "lock_count"=0,
                "segment_ids"=[]
            };

            for (i = 1; i LTE qSegments.recordCount; i++) {
                segIdVal = (isNull(qSegments.id[i]) ? 0 : val(qSegments.id[i]));
                segStartName = (isNull(qSegments.start_name[i]) ? "" : trim(toString(qSegments.start_name[i])));
                segEndName = (isNull(qSegments.end_name[i]) ? "" : trim(toString(qSegments.end_name[i])));
                segDistNm = (isNull(qSegments.dist_nm[i]) ? 0 : val(qSegments.dist_nm[i]));
                segLockCount = (isNull(qSegments.lock_count[i]) ? 0 : val(qSegments.lock_count[i]));

                if (segDistNm LT 0) segDistNm = 0;
                if (segLockCount LT 0) segLockCount = 0;
                segHours = (effectiveSpeedVal GT 0 ? (segDistNm / effectiveSpeedVal) : 0);
                if (segHours LT 0) segHours = 0;

                if ((currentDay.est_hours + segHours) GT maxHoursVal AND currentDay.total_dist_nm GT 0) {
                    fuelEstimate = calculateFuelEstimate({
                        "distanceNm"=currentDay.total_dist_nm,
                        "maxSpeedKnots"=maxSpeedVal,
                        "maxBurnGph"=fuelBurnGphVal,
                        "pace"=paceVal,
                        "paceRatio"=paceRatioVal,
                        "weatherPct"=0,
                        "idleFuelGallons"=0,
                        "reservePct"=reservePctVal
                    });
                    currentDay.cruise_fuel_gallons = roundTo2(val(fuelEstimate.cruiseFuelGallons));
                    currentDay.reserve_gallons = roundTo2(val(fuelEstimate.reserveGallons));
                    currentDay.required_fuel_gallons = roundTo2(val(fuelEstimate.requiredFuelGallons));
                    requiredFuelGallonsVal = val(currentDay.required_fuel_gallons);
                    reserveGallonsVal = val(currentDay.reserve_gallons);
                    reserveRatio = (requiredFuelGallonsVal GT 0 ? (reserveGallonsVal / requiredFuelGallonsVal) : 0);

                    fuelConfidenceScore = 100;
                    if (requiredFuelGallonsVal GT 0 AND reserveRatio LT 0.20) fuelConfidenceScore -= 25;
                    if (requiredFuelGallonsVal GT 0 AND reserveRatio LT 0.15) fuelConfidenceScore -= 40;
                    if (val(currentDay.est_hours) GT 8) fuelConfidenceScore -= 10;
                    if (fuelConfidenceScore LT 0) fuelConfidenceScore = 0;
                    if (fuelConfidenceScore GT 100) fuelConfidenceScore = 100;
                    currentDay.fuel_confidence_score = fuelConfidenceScore;
                    if (fuelConfidenceScore GTE 80) {
                        currentDay.risk_color = "GREEN";
                    } else if (fuelConfidenceScore GTE 60) {
                        currentDay.risk_color = "YELLOW";
                    } else {
                        currentDay.risk_color = "RED";
                    }

                    currentDay.total_dist_nm = roundTo2(currentDay.total_dist_nm);
                    currentDay.est_hours = roundTo2(currentDay.est_hours);

                    totalCruiseNm += val(currentDay.total_dist_nm);
                    totalRequiredFuel += requiredFuelGallonsVal;
                    arrayAppend(days, duplicate(currentDay));

                    currentDate = dateAdd("d", 1, currentDate);
                    legIndex += 1;
                    currentDay = {
                        "date"=dateFormat(currentDate, "yyyy-mm-dd"),
                        "leg_index"=legIndex,
                        "start_name"=segStartName,
                        "end_name"=segEndName,
                        "total_dist_nm"=segDistNm,
                        "est_hours"=segHours,
                        "cruise_fuel_gallons"=0,
                        "reserve_gallons"=0,
                        "required_fuel_gallons"=0,
                        "fuel_confidence_score"=0,
                        "risk_color"="GREEN",
                        "lock_count"=segLockCount,
                        "segment_ids"=[]
                    };
                    arrayAppend(currentDay.segment_ids, segIdVal);
                } else {
                    if (!len(currentDay.start_name)) currentDay.start_name = segStartName;
                    currentDay.total_dist_nm += segDistNm;
                    currentDay.est_hours += segHours;
                    currentDay.lock_count += segLockCount;
                    arrayAppend(currentDay.segment_ids, segIdVal);
                    currentDay.end_name = segEndName;
                }
            }

            if (currentDay.total_dist_nm GT 0 OR arrayLen(currentDay.segment_ids) GT 0) {
                fuelEstimate = calculateFuelEstimate({
                    "distanceNm"=currentDay.total_dist_nm,
                    "maxSpeedKnots"=maxSpeedVal,
                    "maxBurnGph"=fuelBurnGphVal,
                    "pace"=paceVal,
                    "paceRatio"=paceRatioVal,
                    "weatherPct"=0,
                    "idleFuelGallons"=0,
                    "reservePct"=reservePctVal
                });
                currentDay.cruise_fuel_gallons = roundTo2(val(fuelEstimate.cruiseFuelGallons));
                currentDay.reserve_gallons = roundTo2(val(fuelEstimate.reserveGallons));
                currentDay.required_fuel_gallons = roundTo2(val(fuelEstimate.requiredFuelGallons));
                requiredFuelGallonsVal = val(currentDay.required_fuel_gallons);
                reserveGallonsVal = val(currentDay.reserve_gallons);
                reserveRatio = (requiredFuelGallonsVal GT 0 ? (reserveGallonsVal / requiredFuelGallonsVal) : 0);

                fuelConfidenceScore = 100;
                if (requiredFuelGallonsVal GT 0 AND reserveRatio LT 0.20) fuelConfidenceScore -= 25;
                if (requiredFuelGallonsVal GT 0 AND reserveRatio LT 0.15) fuelConfidenceScore -= 40;
                if (val(currentDay.est_hours) GT 8) fuelConfidenceScore -= 10;
                if (fuelConfidenceScore LT 0) fuelConfidenceScore = 0;
                if (fuelConfidenceScore GT 100) fuelConfidenceScore = 100;
                currentDay.fuel_confidence_score = fuelConfidenceScore;
                if (fuelConfidenceScore GTE 80) {
                    currentDay.risk_color = "GREEN";
                } else if (fuelConfidenceScore GTE 60) {
                    currentDay.risk_color = "YELLOW";
                } else {
                    currentDay.risk_color = "RED";
                }

                currentDay.total_dist_nm = roundTo2(currentDay.total_dist_nm);
                currentDay.est_hours = roundTo2(currentDay.est_hours);

                totalCruiseNm += val(currentDay.total_dist_nm);
                totalRequiredFuel += requiredFuelGallonsVal;
                arrayAppend(days, duplicate(currentDay));
            }

            out.success = true;
            out.route_summary = {
                "total_days"=arrayLen(days),
                "total_nm"=roundTo2(totalCruiseNm),
                "total_required_fuel"=roundTo2(totalRequiredFuel)
            };
            out.days = days;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="findFocusSegments" access="private" returntype="struct" output="false">
        <cfargument name="templateRouteId" type="numeric" required="true">
        <cfargument name="startLocation" type="string" required="true">
        <cfargument name="endLocation" type="string" required="true">
        <cfargument name="direction" type="string" required="false" default="CCW">
        <cfscript>
            var out = {
                "START_SEGMENT_ID"=0,
                "END_SEGMENT_ID"=0,
                "START_ORDER"=0,
                "END_ORDER"=0,
                "START_FOUND"=false,
                "END_FOUND"=false
            };
            var sNorm = normalizeText(arguments.startLocation);
            var eNorm = normalizeText(arguments.endLocation);
            var directionVal = normalizeDirection(arguments.direction);
            if (!len(sNorm) OR !len(eNorm)) {
                return out;
            }

            var q = queryExecute(
                "SELECT
                    sl.id,
                    COALESCE(NULLIF(TRIM(p1.name), ''), TRIM(sl.start_port_name), '') AS start_name,
                    COALESCE(NULLIF(TRIM(p2.name), ''), TRIM(sl.end_port_name), '') AS end_name,
                    1 AS section_order,
                    rts.order_index AS seg_order
                 FROM route_template_segments rts
                 INNER JOIN segment_library sl ON sl.id = rts.segment_id
                 LEFT JOIN ports p1 ON p1.id = sl.start_port_id
                 LEFT JOIN ports p2 ON p2.id = sl.end_port_id
                 WHERE rts.route_id = :rid
                 ORDER BY rts.order_index ASC, rts.id ASC",
                { rid = { value=arguments.templateRouteId, cfsqltype="cf_sql_integer" } },
                { datasource = application.dsn }
            );

            var i = 0;
            var sScore = 0;
            var eScore = 0;
            var sBest = 0;
            var eBest = 0;
            var segStart = "";
            var segEnd = "";
            var routeOrder = 0;
            var candidateOrder = 0;
            var candidateSegId = 0;
            var candidateStartValid = false;
            var candidateEndValid = false;
            var srcIdx = 0;
            for (i = 1; i LTE q.recordCount; i++) {
                srcIdx = (directionVal EQ "CW" ? (q.recordCount - i + 1) : i);
                segStart = normalizeText(directionVal EQ "CW" ? q.end_name[srcIdx] : q.start_name[srcIdx]);
                segEnd = normalizeText(directionVal EQ "CW" ? q.start_name[srcIdx] : q.end_name[srcIdx]);
                routeOrder = i;

                sScore = 0;
                candidateStartValid = false;
                candidateSegId = 0;
                candidateOrder = 0;
                if (len(sNorm)) {
                    if (sNorm EQ segStart) {
                        sScore = 300;
                        candidateSegId = q.id[srcIdx];
                        candidateOrder = routeOrder;
                        candidateStartValid = true;
                    } else if (
                        len(segStart) AND (findNoCase(sNorm, segStart) GT 0 OR findNoCase(segStart, sNorm) GT 0)
                    ) {
                        sScore = 120;
                        candidateSegId = q.id[srcIdx];
                        candidateOrder = routeOrder;
                        candidateStartValid = true;
                    }
                }
                if (
                    candidateStartValid
                    AND
                    (
                        sScore GT sBest
                        OR
                        (sScore EQ sBest AND sBest GT 0 AND (out.START_ORDER EQ 0 OR candidateOrder LT out.START_ORDER))
                    )
                ) {
                    sBest = sScore;
                    out.START_SEGMENT_ID = candidateSegId;
                    out.START_ORDER = candidateOrder;
                    out.START_FOUND = true;
                }

                eScore = 0;
                candidateEndValid = false;
                candidateSegId = 0;
                candidateOrder = 0;
                if (len(eNorm)) {
                    if (eNorm EQ segEnd) {
                        eScore = 300;
                        candidateSegId = q.id[srcIdx];
                        candidateOrder = routeOrder;
                        candidateEndValid = true;
                    } else if (
                        len(segEnd) AND (findNoCase(eNorm, segEnd) GT 0 OR findNoCase(segEnd, eNorm) GT 0)
                    ) {
                        eScore = 120;
                        candidateSegId = q.id[srcIdx];
                        candidateOrder = routeOrder;
                        candidateEndValid = true;
                    }
                }
                if (
                    candidateEndValid
                    AND
                    (
                        eScore GT eBest
                        OR
                        (eScore EQ eBest AND eBest GT 0 AND (out.END_ORDER EQ 0 OR candidateOrder LT out.END_ORDER))
                    )
                ) {
                    eBest = eScore;
                    out.END_SEGMENT_ID = candidateSegId;
                    out.END_ORDER = candidateOrder;
                    out.END_FOUND = true;
                }
            }
            if (sBest LTE 0) out.START_FOUND = false;
            if (eBest LTE 0) out.END_FOUND = false;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="scoreNodeMatch" access="private" returntype="numeric" output="false">
        <cfargument name="needle" type="string" required="true">
        <cfargument name="nodeA" type="string" required="true">
        <cfargument name="nodeB" type="string" required="true">
        <cfscript>
            if (!len(arguments.needle)) return 0;
            if (arguments.needle EQ arguments.nodeA OR arguments.needle EQ arguments.nodeB) return 100;
            if (
                (len(arguments.nodeA) AND (findNoCase(arguments.needle, arguments.nodeA) GT 0 OR findNoCase(arguments.nodeA, arguments.needle) GT 0))
                OR
                (len(arguments.nodeB) AND (findNoCase(arguments.needle, arguments.nodeB) GT 0 OR findNoCase(arguments.nodeB, arguments.needle) GT 0))
            ) {
                return 80;
            }
            return 0;
        </cfscript>
    </cffunction>

    <cffunction name="findRouteContinuityIssue" access="private" returntype="struct" output="false">
        <cfargument name="segmentRows" type="array" required="true">
        <cfscript>
            var out = {
                "HAS_BREAK"=false,
                "NEXT_ROUTE_ORDER"=0,
                "PREV_END_RAW"="",
                "NEXT_START_RAW"=""
            };
            var i = 0;
            var prevEndRaw = "";
            var nextStartRaw = "";
            var prevEndNorm = "";
            var nextStartNorm = "";
            for (i = 2; i LTE arrayLen(arguments.segmentRows); i++) {
                prevEndRaw = trim(toString(arguments.segmentRows[i - 1].END_NAME));
                nextStartRaw = trim(toString(arguments.segmentRows[i].START_NAME));
                prevEndNorm = normalizeText(prevEndRaw);
                nextStartNorm = normalizeText(nextStartRaw);
                if (!len(prevEndNorm) OR !len(nextStartNorm)) {
                    out.HAS_BREAK = true;
                } else if (
                    areLocationNamesEquivalent(prevEndRaw, nextStartRaw)
                ) {
                    continue;
                } else {
                    out.HAS_BREAK = true;
                }
                if (out.HAS_BREAK) {
                    out.NEXT_ROUTE_ORDER = val(arguments.segmentRows[i].ROUTE_ORDER);
                    out.PREV_END_RAW = prevEndRaw;
                    out.NEXT_START_RAW = nextStartRaw;
                    return out;
                }
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="pickBestFullLoopSelection" access="private" returntype="struct" output="false">
        <cfargument name="segmentRows" type="array" required="true">
        <cfargument name="startLocation" type="string" required="true">
        <cfargument name="fallbackStartOrder" type="numeric" required="true">
        <cfscript>
            var out = { "SUCCESS"=false, "ROWS"=[], "START_ORDER"=val(arguments.fallbackStartOrder), "END_ORDER"=0 };
            var startNorm = normalizeText(arguments.startLocation);
            var n = arrayLen(arguments.segmentRows);
            var candidateStarts = [];
            var i = 0;
            var k = 0;
            var idx = 0;
            var seg = {};
            var rows = [];
            var valid = false;
            var returnsToStart = false;
            var prevSeg = {};
            var bestRows = [];
            var bestStart = 0;
            if (!len(startNorm) OR n LTE 0) return out;

            for (i = 1; i LTE n; i++) {
                if (areLocationNamesEquivalent(arguments.segmentRows[i].START_NAME, arguments.startLocation)) {
                    arrayAppend(candidateStarts, i);
                }
            }
            if (!arrayLen(candidateStarts)) return out;

            for (i = 1; i LTE arrayLen(candidateStarts); i++) {
                rows = [];
                valid = true;
                for (k = 0; k LT n; k++) {
                    idx = ((candidateStarts[i] - 1 + k) MOD n) + 1;
                    seg = arguments.segmentRows[idx];
                    if (k GT 0 AND areLocationNamesEquivalent(seg.START_NAME, arguments.startLocation)) {
                        break;
                    }
                    if (arrayLen(rows) GT 0) {
                        prevSeg = rows[arrayLen(rows)];
                        if (!areLocationNamesEquivalent(prevSeg.END_NAME, seg.START_NAME)) {
                            valid = false;
                            break;
                        }
                    }
                    arrayAppend(rows, seg);
                }
                if (!valid OR !arrayLen(rows)) {
                    continue;
                }
                returnsToStart = areLocationNamesEquivalent(rows[arrayLen(rows)].END_NAME, arguments.startLocation);
                if (!returnsToStart) {
                    continue;
                }
                if (arrayLen(rows) GT arrayLen(bestRows)) {
                    bestRows = rows;
                    bestStart = candidateStarts[i];
                }
            }

            if (arrayLen(bestRows)) {
                out.SUCCESS = true;
                out.ROWS = bestRows;
                out.START_ORDER = bestRows[1].ROUTE_ORDER;
                out.END_ORDER = bestRows[arrayLen(bestRows)].ROUTE_ORDER;
                return out;
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="pickBestPointToPointSelection" access="private" returntype="struct" output="false">
        <cfargument name="segmentRows" type="array" required="true">
        <cfargument name="startLocation" type="string" required="true">
        <cfargument name="endLocation" type="string" required="true">
        <cfargument name="fallbackStartOrder" type="numeric" required="true">
        <cfscript>
            var out = { "SUCCESS"=false, "ROWS"=[], "START_ORDER"=val(arguments.fallbackStartOrder), "END_ORDER"=0, "WRAP_RANGE"=false };
            var n = arrayLen(arguments.segmentRows);
            var startNorm = normalizeText(arguments.startLocation);
            var endNorm = normalizeText(arguments.endLocation);
            var candidateStarts = [];
            var i = 0;
            var k = 0;
            var idx = 0;
            var seg = {};
            var rows = [];
            var prevSeg = {};
            var valid = false;
            var reachedEnd = false;
            var bestRows = [];
            if (!len(startNorm) OR !len(endNorm) OR n LTE 0) return out;

            for (i = 1; i LTE n; i++) {
                if (areLocationNamesEquivalent(arguments.segmentRows[i].START_NAME, arguments.startLocation)) {
                    arrayAppend(candidateStarts, i);
                }
            }
            if (!arrayLen(candidateStarts)) return out;

            for (i = 1; i LTE arrayLen(candidateStarts); i++) {
                rows = [];
                valid = true;
                reachedEnd = false;
                for (k = 0; k LT n; k++) {
                    idx = ((candidateStarts[i] - 1 + k) MOD n) + 1;
                    seg = arguments.segmentRows[idx];
                    if (k GT 0 AND areLocationNamesEquivalent(seg.START_NAME, arguments.startLocation)) {
                        break;
                    }
                    if (arrayLen(rows) GT 0) {
                        prevSeg = rows[arrayLen(rows)];
                        if (!areLocationNamesEquivalent(prevSeg.END_NAME, seg.START_NAME)) {
                            valid = false;
                            break;
                        }
                    }
                    arrayAppend(rows, seg);
                    if (areLocationNamesEquivalent(seg.END_NAME, arguments.endLocation)) {
                        reachedEnd = true;
                        break;
                    }
                }
                if (!valid OR !reachedEnd OR !arrayLen(rows)) {
                    continue;
                }
                if (!arrayLen(bestRows) OR arrayLen(rows) LT arrayLen(bestRows)) {
                    bestRows = rows;
                }
            }

            if (arrayLen(bestRows)) {
                out.SUCCESS = true;
                out.ROWS = bestRows;
                out.START_ORDER = bestRows[1].ROUTE_ORDER;
                out.END_ORDER = bestRows[arrayLen(bestRows)].ROUTE_ORDER;
                if (out.END_ORDER LT out.START_ORDER) {
                    out.WRAP_RANGE = true;
                }
                return out;
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="areLocationNamesEquivalent" access="private" returntype="boolean" output="false">
        <cfargument name="a" type="any" required="true">
        <cfargument name="b" type="any" required="true">
        <cfscript>
            var an = normalizeText(arguments.a);
            var bn = normalizeText(arguments.b);
            if (!len(an) OR !len(bn)) return false;
            if (an EQ bn) return true;
            if (findNoCase(an, bn) GT 0 OR findNoCase(bn, an) GT 0) return true;
            return false;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeText" access="private" returntype="string" output="false">
        <cfargument name="s" type="any" required="true">
        <cfscript>
            var v = lCase(trim(toString(arguments.s)));
            if (!len(v)) return "";
            v = reReplace(v, "\bst[.]?\b", "saint", "all");
            v = reReplace(v, "\bmt[.]?\b", "mount", "all");
            v = reReplace(v, "[^a-z0-9]+", " ", "all");
            v = reReplace(v, "\s+", " ", "all");
            return trim(v);
        </cfscript>
    </cffunction>

    <cffunction name="routegenReadInput" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var input = {};
            input.template_code = trim(toString(pickArg(arguments.body, "template_code", "templateCode", "")));
            input.route_code = trim(toString(pickArg(arguments.body, "route_code", "routeCode", "")));
            input.direction = normalizeDirection(pickArg(arguments.body, "direction", "direction", "CCW"));
            input.start_segment_id = trim(toString(pickArg(arguments.body, "start_segment_id", "startSegmentId", "")));
            input.end_segment_id = trim(toString(pickArg(arguments.body, "end_segment_id", "endSegmentId", "")));
            input.start_location_label = trim(toString(pickArg(arguments.body, "start_location_label", "startLocationLabel", "")));
            input.end_location_label = trim(toString(pickArg(arguments.body, "end_location_label", "endLocationLabel", "")));
            input.start_date = trim(toString(pickArg(arguments.body, "start_date", "startDate", "")));
            input.pace = routegenNormalizePace(pickArg(arguments.body, "pace", "pace", "RELAXED"));
            input.cruising_speed = trim(toString(pickArg(arguments.body, "cruising_speed", "cruisingSpeed", "")));
            input.effective_cruising_speed = trim(toString(pickArg(arguments.body, "effective_cruising_speed", "effectiveCruisingSpeed", "")));
            input.underway_hours_per_day = trim(toString(pickArg(arguments.body, "underway_hours_per_day", "underwayHoursPerDay", "")));
            input.fuel_burn_gph = trim(toString(pickArg(arguments.body, "fuel_burn_gph", "fuelBurnGph", "")));
            input.fuel_burn_gph_input = trim(
                toString(pickArg(arguments.body, "fuel_burn_gph_input", "fuelBurnGphInput", input.fuel_burn_gph))
            );
            input.fuel_burn_basis = routegenNormalizeFuelBurnBasis(
                pickArg(arguments.body, "fuel_burn_basis", "fuelBurnBasis", "MAX_SPEED")
            );
            input.idle_burn_gph = trim(toString(pickArg(arguments.body, "idle_burn_gph", "idleBurnGph", "")));
            input.idle_hours_total = trim(toString(pickArg(arguments.body, "idle_hours_total", "idleHoursTotal", "")));
            input.weather_factor_pct = trim(toString(pickArg(arguments.body, "weather_factor_pct", "weatherFactorPct", pickArg(arguments.body, "weather_factor", "weatherFactor", ""))));
            input.reserve_pct = trim(toString(pickArg(arguments.body, "reserve_pct", "reservePct", "")));
            input.fuel_price_per_gal = trim(toString(pickArg(arguments.body, "fuel_price_per_gal", "fuelPricePerGal", "")));
            input.comfort_profile = trim(toString(pickArg(arguments.body, "comfort_profile", "comfortProfile", "PREFER_INSIDE")));
            input.overnight_bias = trim(toString(pickArg(arguments.body, "overnight_bias", "overnightBias", "MARINAS")));
            input.route_name = trim(toString(pickArg(arguments.body, "route_name", "routeName", "")));
            input.optional_stop_flags = routegenNormalizeStopFlags(
                pickArg(arguments.body, "optional_stop_flags", "optionalStopFlags", [])
            );
            return input;
        </cfscript>
    </cffunction>

    <cffunction name="routegenNormalizePace" access="private" returntype="string" output="false">
        <cfargument name="pace" type="any" required="false" default="RELAXED">
        <cfscript>
            var paceVal = uCase(trim(toString(arguments.pace)));
            if (paceVal EQ "BALANCED") return "BALANCED";
            if (paceVal EQ "AGGRESSIVE") return "AGGRESSIVE";
            return "RELAXED";
        </cfscript>
    </cffunction>

    <cffunction name="routegenPaceDefaults" access="private" returntype="struct" output="false">
        <cfargument name="pace" type="any" required="false" default="RELAXED">
        <cfscript>
            var paceVal = routegenNormalizePace(arguments.pace);
            if (paceVal EQ "BALANCED") {
                return { "MAX_SPEED_KN"=20.0, "PACE_FACTOR"=0.50 };
            }
            if (paceVal EQ "AGGRESSIVE") {
                return { "MAX_SPEED_KN"=20.0, "PACE_FACTOR"=1.00 };
            }
            return { "MAX_SPEED_KN"=20.0, "PACE_FACTOR"=0.25 };
        </cfscript>
    </cffunction>

    <cffunction name="routegenNormalizeCruisingSpeed" access="private" returntype="numeric" output="false">
        <cfargument name="speedKn" type="any" required="false" default="">
        <cfargument name="defaultSpeedKn" type="numeric" required="false" default="20">
        <cfscript>
            var speedVal = val(arguments.speedKn);
            var fallbackVal = val(arguments.defaultSpeedKn);
            if (fallbackVal LTE 0) fallbackVal = 20;
            if (speedVal LTE 0) speedVal = fallbackVal;
            if (speedVal LT 1) speedVal = 1;
            if (speedVal GT 60) speedVal = 60;
            return roundTo2(speedVal);
        </cfscript>
    </cffunction>

    <cffunction name="routegenComputeEffectiveCruisingSpeed" access="private" returntype="numeric" output="false">
        <cfargument name="maxSpeedKn" type="any" required="false" default="">
        <cfargument name="pace" type="any" required="false" default="RELAXED">
        <cfscript>
            var paceDefaults = routegenPaceDefaults(arguments.pace);
            var maxSpeedVal = routegenNormalizeCruisingSpeed(arguments.maxSpeedKn, paceDefaults.MAX_SPEED_KN);
            var factorVal = val(paceDefaults.PACE_FACTOR);
            var effectiveSpeed = 0;
            if (factorVal LTE 0) factorVal = 0.25;
            effectiveSpeed = maxSpeedVal * factorVal;
            if (effectiveSpeed LT 1) effectiveSpeed = 1;
            return roundTo2(effectiveSpeed);
        </cfscript>
    </cffunction>

    <cffunction name="routegenEstimateDaysBySpeed" access="private" returntype="numeric" output="false">
        <cfargument name="distanceNm" type="any" required="false" default="0">
        <cfargument name="effectiveCruisingSpeed" type="any" required="false" default="10">
        <cfargument name="underwayHoursPerDay" type="any" required="false" default="8">
        <cfscript>
            var distanceVal = val(arguments.distanceNm);
            var speedVal = routegenNormalizeCruisingSpeed(arguments.effectiveCruisingSpeed, 10);
            var underwayHoursVal = routegenNormalizeUnderwayHours(arguments.underwayHoursPerDay);
            var runHours = 0;
            if (distanceVal LTE 0) return 0;
            if (speedVal LTE 0) speedVal = 10;
            runHours = distanceVal / speedVal;
            if (runHours LTE 0) return 0;
            return ceiling(runHours / underwayHoursVal);
        </cfscript>
    </cffunction>

    <cffunction name="routegenNormalizeUnderwayHours" access="private" returntype="numeric" output="false">
        <cfargument name="hours" type="any" required="false" default="8">
        <cfscript>
            var v = val(arguments.hours);
            if (v LTE 0) v = 8;
            if (v LT 1) v = 1;
            if (v GT 24) v = 24;
            return v;
        </cfscript>
    </cffunction>

    <cffunction name="routegenNormalizeFuelBurnGph" access="private" returntype="numeric" output="false">
        <cfargument name="fuelBurnGph" type="any" required="false" default="">
        <cfscript>
            var valueVal = val(arguments.fuelBurnGph);
            if (valueVal LTE 0) return 0;
            if (valueVal GT 1000) valueVal = 1000;
            return roundTo2(valueVal);
        </cfscript>
    </cffunction>

    <cffunction name="routegenNormalizeFuelBurnBasis" access="private" returntype="string" output="false">
        <cfargument name="basis" type="any" required="false" default="MAX_SPEED">
        <cfscript>
            var basisVal = uCase(trim(toString(arguments.basis)));
            if (basisVal EQ "SELECTED_PACE") return "SELECTED_PACE";
            return "MAX_SPEED";
        </cfscript>
    </cffunction>

    <cffunction name="routegenNormalizeIdleHoursTotal" access="private" returntype="numeric" output="false">
        <cfargument name="idleHoursTotal" type="any" required="false" default="">
        <cfscript>
            var rawVal = trim(toString(arguments.idleHoursTotal));
            var hoursVal = 0;
            if (!len(rawVal)) return 0;
            hoursVal = val(rawVal);
            if (hoursVal LTE 0) return 0;
            if (hoursVal GT 10000) hoursVal = 10000;
            return roundTo2(hoursVal);
        </cfscript>
    </cffunction>

    <cffunction name="routegenNormalizeWeatherFactorPct" access="private" returntype="numeric" output="false">
        <cfargument name="weatherFactorPct" type="any" required="false" default="">
        <cfscript>
            var rawVal = trim(toString(arguments.weatherFactorPct));
            var pctVal = 0;
            if (!len(rawVal)) return 0;
            pctVal = val(rawVal);
            if (pctVal LT 0) pctVal = 0;
            if (pctVal GT 60) pctVal = 60;
            return roundTo2(pctVal);
        </cfscript>
    </cffunction>

    <cffunction name="routegenNormalizeReservePct" access="private" returntype="numeric" output="false">
        <cfargument name="reservePct" type="any" required="false" default="">
        <cfargument name="defaultPct" type="numeric" required="false" default="20">
        <cfscript>
            var rawVal = trim(toString(arguments.reservePct));
            var pctVal = 0;
            if (!len(rawVal)) {
                pctVal = val(arguments.defaultPct);
            } else {
                pctVal = val(rawVal);
            }
            if (pctVal LT 0) pctVal = 0;
            if (pctVal GT 100) pctVal = 100;
            return roundTo2(pctVal);
        </cfscript>
    </cffunction>

    <cffunction name="routegenNormalizeFuelPricePerGal" access="private" returntype="numeric" output="false">
        <cfargument name="fuelPricePerGal" type="any" required="false" default="">
        <cfscript>
            var rawVal = trim(toString(arguments.fuelPricePerGal));
            var priceVal = 0;
            if (!len(rawVal)) return 0;
            priceVal = val(rawVal);
            if (priceVal LTE 0) return 0;
            if (priceVal GT 1000) priceVal = 1000;
            return roundTo2(priceVal);
        </cfscript>
    </cffunction>

    <!--- Fuel model helpers (pure) --->
    <cffunction name="paceAdjustedBurnGph" access="private" returntype="numeric" output="false">
        <cfargument name="maxBurnGph" type="any" required="false" default="0">
        <cfargument name="paceRatio" type="any" required="false" default="1">
        <cfargument name="burnExponent" type="any" required="false" default="3.0">
        <cfscript>
            var maxBurnVal = routegenNormalizeFuelBurnGph(arguments.maxBurnGph);
            var ratioVal = val(arguments.paceRatio);
            var expVal = val(arguments.burnExponent);
            if (maxBurnVal LTE 0) return 0;
            if (expVal LT 1) expVal = 1;
            if (expVal GT 6) expVal = 6;
            if (ratioVal LTE 0) ratioVal = 1;
            if (ratioVal LT 0.05) ratioVal = 0.05;
            if (ratioVal GT 1) ratioVal = 1;
            return roundTo2(maxBurnVal * (ratioVal ^ expVal));
        </cfscript>
    </cffunction>

    <cffunction name="calculateFuelEstimate" access="private" returntype="struct" output="false">
        <cfargument name="args" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var out = {
                "paceRatio"=0,
                "effectiveSpeedKnots"=0,
                "paceAdjustedBurnGph"=0,
                "weatherAdjustedSpeedKnots"=0,
                "weatherAdjustedBurnGph"=0,
                "cruiseHours"=0,
                "cruiseFuelGallons"=0,
                "idleFuelGallons"=0,
                "baseFuelGallons"=0,
                "reserveGallons"=0,
                "requiredFuelGallons"=0,
                "totalFuelCost"=0
            };
            var src = (isStruct(arguments.args) ? arguments.args : {});
            var distanceVal = val(structKeyExists(src, "distanceNm") ? src.distanceNm : 0);
            var maxSpeedVal = val(structKeyExists(src, "maxSpeedKnots") ? src.maxSpeedKnots : 0);
            var maxBurnVal = routegenNormalizeFuelBurnGph(structKeyExists(src, "maxBurnGph") ? src.maxBurnGph : 0);
            var paceRatioVal = 0;
            var pacePctVal = val(structKeyExists(src, "pacePct") ? src.pacePct : 0);
            var paceEnumVal = routegenNormalizePace(structKeyExists(src, "pace") ? src.pace : "");
            var weatherPctVal = val(structKeyExists(src, "weatherPct") ? src.weatherPct : 0);
            var weatherAdj = 0;
            var reservePctVal = val(structKeyExists(src, "reservePct") ? src.reservePct : 0);
            var reserveGallonsVal = val(structKeyExists(src, "reserveGallons") ? src.reserveGallons : 0);
            var idleFuelGallonsVal = val(structKeyExists(src, "idleFuelGallons") ? src.idleFuelGallons : 0);
            var fuelPriceVal = val(structKeyExists(src, "fuelPricePerGallon") ? src.fuelPricePerGallon : 0);

            if (distanceVal LTE 0 OR maxSpeedVal LTE 0 OR maxBurnVal LTE 0) {
                return out;
            }

            // Pace enum is primary source (RELAXED/BALANCED/AGGRESSIVE => 25/50/100).
            if (paceEnumVal EQ "RELAXED") {
                paceRatioVal = 0.25;
            } else if (paceEnumVal EQ "BALANCED") {
                paceRatioVal = 0.50;
            } else if (paceEnumVal EQ "AGGRESSIVE") {
                paceRatioVal = 1.00;
            }

            // Fallback to pacePct or explicit paceRatio if enum was not provided.
            if (paceRatioVal LTE 0) {
                if (pacePctVal GT 1) {
                    paceRatioVal = pacePctVal / 100;
                } else if (pacePctVal GT 0) {
                    paceRatioVal = pacePctVal;
                } else if (structKeyExists(src, "paceRatio")) {
                    paceRatioVal = val(src.paceRatio);
                } else {
                    paceRatioVal = 1;
                }
            }

            if (paceRatioVal LT 0.05) paceRatioVal = 0.05;
            if (paceRatioVal GT 1) paceRatioVal = 1;
            if (weatherPctVal LT 0) weatherPctVal = 0;
            if (weatherPctVal GT 60) weatherPctVal = 60;
            if (idleFuelGallonsVal LT 0) idleFuelGallonsVal = 0;
            weatherAdj = weatherPctVal / 100;

            out.paceRatio = roundTo2(paceRatioVal);
            out.effectiveSpeedKnots = roundTo2(maxSpeedVal * paceRatioVal);
            out.paceAdjustedBurnGph = paceAdjustedBurnGph(maxBurnVal, paceRatioVal, 3.0);
            out.weatherAdjustedSpeedKnots = roundTo2(out.effectiveSpeedKnots * (1 - weatherAdj));
            if (out.weatherAdjustedSpeedKnots LT 0.5) out.weatherAdjustedSpeedKnots = 0.5;
            out.weatherAdjustedBurnGph = roundTo2(out.paceAdjustedBurnGph * (1 + weatherAdj));
            out.cruiseHours = roundTo2(distanceVal / out.weatherAdjustedSpeedKnots);
            out.cruiseFuelGallons = roundTo2(out.cruiseHours * out.weatherAdjustedBurnGph);
            out.idleFuelGallons = roundTo2(idleFuelGallonsVal);
            out.baseFuelGallons = roundTo2(out.cruiseFuelGallons + out.idleFuelGallons);

            if (reserveGallonsVal GT 0) {
                out.reserveGallons = roundTo2(reserveGallonsVal);
            } else {
                if (reservePctVal LTE 0) reservePctVal = 20;
                out.reserveGallons = roundTo2(out.baseFuelGallons * (reservePctVal / 100));
            }

            out.requiredFuelGallons = roundTo2(out.baseFuelGallons + out.reserveGallons);
            out.totalFuelCost = (fuelPriceVal GT 0 ? round((out.requiredFuelGallons * fuelPriceVal) * 100) / 100 : 0);
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="calculateFuelUsedGallons" access="private" returntype="numeric" output="false">
        <cfargument name="distanceNm" type="any" required="false" default="0">
        <cfargument name="cruiseSpeedKnots" type="any" required="false" default="0">
        <cfargument name="cruiseBurnGph" type="any" required="false" default="0">
        <cfscript>
            var distanceVal = val(arguments.distanceNm);
            var cruiseSpeedVal = val(arguments.cruiseSpeedKnots);
            var cruiseBurnVal = routegenNormalizeFuelBurnGph(arguments.cruiseBurnGph);
            var hoursVal = 0;
            var fuelUsedGallonsVal = 0;

            // Knots are nautical miles per hour (NM/h), so NM ÷ knots = hours.
            // Fuel burn is GPH at that cruise speed.
            if (distanceVal LTE 0) return 0;
            if (cruiseSpeedVal LTE 0 OR cruiseBurnVal LTE 0) return 0;

            hoursVal = distanceVal / cruiseSpeedVal;
            if (hoursVal LTE 0) return 0;

            fuelUsedGallonsVal = hoursVal * cruiseBurnVal;
            if (fuelUsedGallonsVal LT 0) return 0;

            // Return numeric rounded to 1 decimal for stable display and storage.
            return round(fuelUsedGallonsVal * 10) / 10;
        </cfscript>
    </cffunction>

    <cffunction name="calculateFuelUsedGallonsExampleAssertions" access="private" returntype="array" output="false">
        <cfscript>
            var out = [];
            var actualA = calculateFuelUsedGallons(500, 10, 8);
            var actualB = calculateFuelUsedGallons(120, 8, 4);
            var actualC = calculateFuelUsedGallons(120, 0, 4);

            // A) 500 NM @ 10 kn, 8 GPH => 50 hours, 400 gallons
            arrayAppend(out, { "CASE"="A", "EXPECTED"=400, "ACTUAL"=actualA, "PASS"=(actualA EQ 400) });
            // B) 120 NM @ 8 kn, 4 GPH => 15 hours, 60 gallons
            arrayAppend(out, { "CASE"="B", "EXPECTED"=60, "ACTUAL"=actualB, "PASS"=(actualB EQ 60) });
            // C) Invalid speed => 0 gallons
            arrayAppend(out, { "CASE"="C", "EXPECTED"=0, "ACTUAL"=actualC, "PASS"=(actualC EQ 0) });
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenNormalizeStopFlags" access="private" returntype="array" output="false">
        <cfargument name="rawValue" type="any" required="true">
        <cfscript>
            var out = [];
            var seen = {};
            var item = "";
            var key = "";
            var i = 0;

            if (isArray(arguments.rawValue)) {
                for (i = 1; i LTE arrayLen(arguments.rawValue); i++) {
                    item = trim(toString(arguments.rawValue[i]));
                    if (!len(item)) continue;
                    key = lCase(item);
                    if (structKeyExists(seen, key)) continue;
                    seen[key] = true;
                    arrayAppend(out, item);
                }
                return out;
            }

            if (isStruct(arguments.rawValue)) {
                for (item in arguments.rawValue) {
                    if (!toBoolean(arguments.rawValue[item], false)) continue;
                    key = lCase(trim(toString(item)));
                    if (!len(key) OR structKeyExists(seen, key)) continue;
                    seen[key] = true;
                    arrayAppend(out, trim(toString(item)));
                }
                return out;
            }

            item = trim(toString(arguments.rawValue));
            if (!len(item)) return out;

            if (find(",", item)) {
                var parts = listToArray(item, ",");
                for (i = 1; i LTE arrayLen(parts); i++) {
                    key = lCase(trim(toString(parts[i])));
                    if (!len(key) OR structKeyExists(seen, key)) continue;
                    seen[key] = true;
                    arrayAppend(out, trim(toString(parts[i])));
                }
                return out;
            }

            arrayAppend(out, item);
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenHasInputsJsonColumn" access="private" returntype="boolean" output="false">
        <cfscript>
            var qCol = queryNew("");
            var hasCol = false;

            qCol = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.columns
                 WHERE table_schema = DATABASE()
                   AND table_name = 'route_instances'
                   AND column_name = 'routegen_inputs_json'",
                {},
                { datasource = application.dsn }
            );
            hasCol = (qCol.recordCount GT 0 AND val(qCol.cnt[1]) GT 0);
            return hasCol;
        </cfscript>
    </cffunction>

    <cffunction name="routegenSerializeInputsForInstance" access="private" returntype="string" output="false">
        <cfargument name="inputData" type="any" required="false" default="">
        <cfscript>
            var payload = {};
            var fuelBurnVal = 0;
            var fuelBurnInputVal = 0;
            var fuelBurnBasisVal = "MAX_SPEED";
            var idleBurnVal = 0;
            var idleHoursVal = 0;
            var weatherPctVal = 0;
            var reservePctVal = 20;
            var fuelPriceVal = 0;
            if (!isStruct(arguments.inputData)) return "";
            payload = duplicate(arguments.inputData);
            payload.pace = routegenNormalizePace(structKeyExists(payload, "pace") ? payload.pace : "RELAXED");
            payload.underway_hours_per_day = routegenNormalizeUnderwayHours(
                structKeyExists(payload, "underway_hours_per_day") ? payload.underway_hours_per_day : 8
            );
            fuelBurnVal = routegenNormalizeFuelBurnGph(
                structKeyExists(payload, "fuel_burn_gph") ? payload.fuel_burn_gph : ""
            );
            fuelBurnInputVal = routegenNormalizeFuelBurnGph(
                structKeyExists(payload, "fuel_burn_gph_input")
                    ? payload.fuel_burn_gph_input
                    : (structKeyExists(payload, "fuel_burn_gph") ? payload.fuel_burn_gph : "")
            );
            fuelBurnBasisVal = routegenNormalizeFuelBurnBasis(
                structKeyExists(payload, "fuel_burn_basis") ? payload.fuel_burn_basis : "MAX_SPEED"
            );
            idleBurnVal = routegenNormalizeFuelBurnGph(
                structKeyExists(payload, "idle_burn_gph") ? payload.idle_burn_gph : ""
            );
            idleHoursVal = routegenNormalizeIdleHoursTotal(
                structKeyExists(payload, "idle_hours_total") ? payload.idle_hours_total : ""
            );
            weatherPctVal = routegenNormalizeWeatherFactorPct(
                structKeyExists(payload, "weather_factor_pct") ? payload.weather_factor_pct : ""
            );
            reservePctVal = routegenNormalizeReservePct(
                structKeyExists(payload, "reserve_pct") ? payload.reserve_pct : "",
                20
            );
            fuelPriceVal = routegenNormalizeFuelPricePerGal(
                structKeyExists(payload, "fuel_price_per_gal") ? payload.fuel_price_per_gal : ""
            );
            payload.fuel_burn_gph = (fuelBurnVal GT 0 ? fuelBurnVal : "");
            payload.fuel_burn_gph_input = (fuelBurnInputVal GT 0 ? fuelBurnInputVal : "");
            payload.fuel_burn_basis = fuelBurnBasisVal;
            payload.idle_burn_gph = (idleBurnVal GT 0 ? idleBurnVal : "");
            payload.idle_hours_total = (idleHoursVal GT 0 ? idleHoursVal : "");
            payload.weather_factor_pct = weatherPctVal;
            payload.reserve_pct = reservePctVal;
            payload.fuel_price_per_gal = (fuelPriceVal GT 0 ? fuelPriceVal : "");
            payload.optional_stop_flags = routegenNormalizeStopFlags(
                structKeyExists(payload, "optional_stop_flags") ? payload.optional_stop_flags : []
            );
            try {
                return serializeJSON(payload);
            } catch (any e) {
                return "";
            }
        </cfscript>
    </cffunction>

    <cffunction name="routegenParseStoredInputs" access="private" returntype="struct" output="false">
        <cfargument name="rawJson" type="any" required="false" default="">
        <cfscript>
            var parsed = {};
            var raw = trim(toString(arguments.rawJson));
            if (!len(raw)) return {};
            try {
                parsed = deserializeJSON(raw, false);
                if (isStruct(parsed)) {
                    return parsed;
                }
            } catch (any e) {
                return {};
            }
            return {};
        </cfscript>
    </cffunction>

    <cffunction name="routegenResolveTemplate" access="private" returntype="struct" output="false">
        <cfargument name="templateCode" type="string" required="false" default="">
        <cfscript>
            var codeVal = trim(arguments.templateCode);
            var qTemplate = queryNew("");
            var sql = "";
            var binds = {
                userPrefix = { value="USER_ROUTE_%", cfsqltype="cf_sql_varchar" }
            };

            sql = "SELECT id, code, short_code, name, description, is_default
                   FROM loop_routes
                   WHERE is_active = 1
                     AND short_code NOT LIKE :userPrefix
                     AND EXISTS (
                       SELECT 1
                       FROM route_template_segments rts
                       WHERE rts.route_id = loop_routes.id
                     )";

            if (len(codeVal)) {
                sql &= " AND (short_code = :code OR code = :code)
                         ORDER BY CASE WHEN short_code = :code THEN 0 ELSE 1 END, is_default DESC, name ASC, id ASC
                         LIMIT 1";
                binds.code = { value=codeVal, cfsqltype="cf_sql_varchar" };
            } else {
                sql &= " ORDER BY is_default DESC, name ASC, id ASC LIMIT 1";
            }

            qTemplate = queryExecute(sql, binds, { datasource = application.dsn });
            if (qTemplate.recordCount EQ 0) {
                return {};
            }

            return {
                "ID"=val(qTemplate.id[1]),
                "CODE"=(isNull(qTemplate.code[1]) ? "" : trim(toString(qTemplate.code[1]))),
                "SHORT_CODE"=(isNull(qTemplate.short_code[1]) ? "" : trim(toString(qTemplate.short_code[1]))),
                "NAME"=(isNull(qTemplate.name[1]) ? "" : trim(toString(qTemplate.name[1]))),
                "DESCRIPTION"=(isNull(qTemplate.description[1]) ? "" : trim(toString(qTemplate.description[1]))),
                "IS_DEFAULT"=(qTemplate.is_default[1] EQ 1)
            };
        </cfscript>
    </cffunction>

    <cffunction name="routegenLoadMainLegs" access="private" returntype="array" output="false">
        <cfargument name="templateRouteId" type="numeric" required="true">
        <cfargument name="direction" type="string" required="false" default="CCW">
        <cfscript>
            var q = queryNew("");
            var hasRouteLegLocks = routegenHasRouteLegLocksTable();
            var lockExpr = "COALESCE(sl.lock_count, 0)";
            var lockJoinSql = "";
            var sqlMainLegs = "";

            if (hasRouteLegLocks) {
                lockExpr = "COALESCE(rll.lock_count, sl.lock_count, 0)";
                lockJoinSql =
                    " LEFT JOIN (
                        SELECT route_code, leg, COUNT(*) AS lock_count
                        FROM route_leg_locks
                        GROUP BY route_code, leg
                      ) rll
                        ON rll.route_code COLLATE utf8mb4_unicode_ci = rt.short_code
                       AND rll.leg = rts.order_index";
            }

            sqlMainLegs =
                "SELECT
                    rts.order_index AS template_order,
                    sl.id AS segment_id,
                    p1.id AS start_port_id,
                    COALESCE(NULLIF(TRIM(p1.name), ''), TRIM(sl.start_port_name), '') AS start_port,
                    p1.lat AS start_lat,
                    p1.lng AS start_lng,
                    p2.id AS end_port_id,
                    COALESCE(NULLIF(TRIM(p2.name), ''), TRIM(sl.end_port_name), '') AS end_port,
                    p2.lat AS end_lat,
                    p2.lng AS end_lng,
                    sl.dist_nm,
                    " & lockExpr & " AS lock_count,
                    sl.is_offshore,
                    sl.is_icw,
                    sl.notes
                 FROM route_template_segments rts
                 INNER JOIN loop_routes rt ON rt.id = rts.route_id
                 INNER JOIN segment_library sl ON sl.id = rts.segment_id
                 LEFT JOIN ports p1 ON p1.id = sl.start_port_id
                 LEFT JOIN ports p2 ON p2.id = sl.end_port_id"
                & lockJoinSql
                & "
                 WHERE rts.route_id = :rid
                 ORDER BY rts.order_index ASC, rts.id ASC";

            q = queryExecute(
                sqlMainLegs,
                {
                    rid = { value=arguments.templateRouteId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );

            var directionVal = normalizeDirection(arguments.direction);
            var legs = [];
            var i = 0;
            var srcIdx = 0;
            var startName = "";
            var endName = "";
            var notesVal = "";

            for (i = 1; i LTE q.recordCount; i++) {
                srcIdx = (directionVal EQ "CW" ? (q.recordCount - i + 1) : i);
                startName = trim(toString(directionVal EQ "CW" ? q.end_port[srcIdx] : q.start_port[srcIdx]));
                endName = trim(toString(directionVal EQ "CW" ? q.start_port[srcIdx] : q.end_port[srcIdx]));
                if (!len(startName)) startName = "Unknown Start";
                if (!len(endName)) endName = "Unknown End";
                notesVal = (isNull(q.notes[srcIdx]) ? "" : trim(toString(q.notes[srcIdx])));

                arrayAppend(legs, {
                    "ORDER_INDEX"=arrayLen(legs) + 1,
                    "SEGMENT_ID"=val(q.segment_id[srcIdx]),
                    "START_PORT_ID"=(directionVal EQ "CW" ? (isNull(q.end_port_id[srcIdx]) ? 0 : val(q.end_port_id[srcIdx])) : (isNull(q.start_port_id[srcIdx]) ? 0 : val(q.start_port_id[srcIdx]))),
                    "END_PORT_ID"=(directionVal EQ "CW" ? (isNull(q.start_port_id[srcIdx]) ? 0 : val(q.start_port_id[srcIdx])) : (isNull(q.end_port_id[srcIdx]) ? 0 : val(q.end_port_id[srcIdx]))),
                    "START_NAME"=startName,
                    "END_NAME"=endName,
                    "START_LAT"=(directionVal EQ "CW" ? (isNull(q.end_lat[srcIdx]) ? "" : q.end_lat[srcIdx]) : (isNull(q.start_lat[srcIdx]) ? "" : q.start_lat[srcIdx])),
                    "START_LNG"=(directionVal EQ "CW" ? (isNull(q.end_lng[srcIdx]) ? "" : q.end_lng[srcIdx]) : (isNull(q.start_lng[srcIdx]) ? "" : q.start_lng[srcIdx])),
                    "END_LAT"=(directionVal EQ "CW" ? (isNull(q.start_lat[srcIdx]) ? "" : q.start_lat[srcIdx]) : (isNull(q.end_lat[srcIdx]) ? "" : q.end_lat[srcIdx])),
                    "END_LNG"=(directionVal EQ "CW" ? (isNull(q.start_lng[srcIdx]) ? "" : q.start_lng[srcIdx]) : (isNull(q.end_lng[srcIdx]) ? "" : q.end_lng[srcIdx])),
                    "DIST_NM"=(isNull(q.dist_nm[srcIdx]) ? 0 : val(q.dist_nm[srcIdx])),
                    "LOCK_COUNT"=(isNull(q.lock_count[srcIdx]) ? 0 : val(q.lock_count[srcIdx])),
                    "IS_OFFSHORE"=(q.is_offshore[srcIdx] EQ 1),
                    "IS_ICW"=(q.is_icw[srcIdx] EQ 1),
                    "IS_OPTIONAL"=false,
                    "DETOUR_CODE"="",
                    "NOTES"=notesVal
                });
            }
            return legs;
        </cfscript>
    </cffunction>

    <cffunction name="routegenLoadDetours" access="private" returntype="struct" output="false">
        <cfargument name="templateRouteId" type="numeric" required="true">
        <cfargument name="direction" type="string" required="false" default="CCW">
        <cfargument name="effectiveCruisingSpeed" type="numeric" required="false" default="10">
        <cfargument name="underwayHoursPerDay" type="numeric" required="false" default="8">
        <cfscript>
            var out = { "DETOURS"=[], "BY_CODE"={} };
            var qDetours = queryExecute(
                "SELECT
                    d.id AS detour_id,
                    d.detour_code,
                    d.name,
                    d.description,
                    d.sort_order
                 FROM route_template_detours d
                 WHERE d.route_id = :rid
                   AND d.is_active = 1
                 ORDER BY d.sort_order ASC, d.id ASC",
                {
                    rid = { value=arguments.templateRouteId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );
            if (qDetours.recordCount EQ 0) {
                return out;
            }

            var directionVal = normalizeDirection(arguments.direction);
            var detourOrder = [];
            var detourDefs = {};
            var i = 0;
            var code = "";
            for (i = 1; i LTE qDetours.recordCount; i++) {
                code = trim(toString(qDetours.detour_code[i]));
                if (!len(code)) continue;
                arrayAppend(detourOrder, code);
                detourDefs[code] = {
                    "CODE"=code,
                    "NAME"=(isNull(qDetours.name[i]) ? code : toString(qDetours.name[i])),
                    "DESCRIPTION"=(isNull(qDetours.description[i]) ? "" : toString(qDetours.description[i])),
                    "SEGMENTS"=[],
                    "DELTA_NM"=0.0,
                    "DELTA_DAYS"=0,
                    "OFFSHORE_LEG_DELTA"=0
                };
            }

            var qSeg = queryExecute(
                "SELECT
                    d.id AS detour_id,
                    d.detour_code,
                    dts.order_index,
                    sl.id AS segment_id,
                    p1.id AS start_port_id,
                    COALESCE(NULLIF(TRIM(p1.name), ''), TRIM(sl.start_port_name), '') AS start_port,
                    p1.lat AS start_lat,
                    p1.lng AS start_lng,
                    p2.id AS end_port_id,
                    COALESCE(NULLIF(TRIM(p2.name), ''), TRIM(sl.end_port_name), '') AS end_port,
                    p2.lat AS end_lat,
                    p2.lng AS end_lng,
                    sl.dist_nm,
                    sl.lock_count,
                    sl.is_offshore,
                    sl.is_icw,
                    sl.notes
                 FROM route_template_detours d
                 INNER JOIN route_template_detour_segments dts ON dts.detour_id = d.id
                 INNER JOIN segment_library sl ON sl.id = dts.segment_id
                 LEFT JOIN ports p1 ON p1.id = sl.start_port_id
                 LEFT JOIN ports p2 ON p2.id = sl.end_port_id
                 WHERE d.route_id = :rid
                   AND d.is_active = 1
                 ORDER BY d.sort_order ASC, d.id ASC, dts.order_index ASC, dts.id ASC",
                {
                    rid = { value=arguments.templateRouteId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );

            var rowsByCode = {};
            for (i = 1; i LTE qSeg.recordCount; i++) {
                code = trim(toString(qSeg.detour_code[i]));
                if (!len(code) OR !structKeyExists(detourDefs, code)) continue;
                if (!structKeyExists(rowsByCode, code)) rowsByCode[code] = [];
                arrayAppend(rowsByCode[code], {
                    "SEGMENT_ID"=val(qSeg.segment_id[i]),
                    "START_PORT_ID"=(isNull(qSeg.start_port_id[i]) ? 0 : val(qSeg.start_port_id[i])),
                    "START_NAME"=(isNull(qSeg.start_port[i]) ? "" : trim(toString(qSeg.start_port[i]))),
                    "START_LAT"=(isNull(qSeg.start_lat[i]) ? "" : qSeg.start_lat[i]),
                    "START_LNG"=(isNull(qSeg.start_lng[i]) ? "" : qSeg.start_lng[i]),
                    "END_PORT_ID"=(isNull(qSeg.end_port_id[i]) ? 0 : val(qSeg.end_port_id[i])),
                    "END_NAME"=(isNull(qSeg.end_port[i]) ? "" : trim(toString(qSeg.end_port[i]))),
                    "END_LAT"=(isNull(qSeg.end_lat[i]) ? "" : qSeg.end_lat[i]),
                    "END_LNG"=(isNull(qSeg.end_lng[i]) ? "" : qSeg.end_lng[i]),
                    "DIST_NM"=(isNull(qSeg.dist_nm[i]) ? 0 : val(qSeg.dist_nm[i])),
                    "LOCK_COUNT"=(isNull(qSeg.lock_count[i]) ? 0 : val(qSeg.lock_count[i])),
                    "IS_OFFSHORE"=(qSeg.is_offshore[i] EQ 1),
                    "IS_ICW"=(qSeg.is_icw[i] EQ 1),
                    "NOTES"=(isNull(qSeg.notes[i]) ? "" : trim(toString(qSeg.notes[i])))
                });
            }

            var rawRows = [];
            var srcIdx = 0;
            var j = 0;
            var leg = {};
            var effectiveSpeedVal = routegenNormalizeCruisingSpeed(arguments.effectiveCruisingSpeed, 10);
            var underwayHoursVal = routegenNormalizeUnderwayHours(arguments.underwayHoursPerDay);

            for (i = 1; i LTE arrayLen(detourOrder); i++) {
                code = detourOrder[i];
                rawRows = (structKeyExists(rowsByCode, code) ? rowsByCode[code] : []);
                if (!arrayLen(rawRows)) continue;
                for (j = 1; j LTE arrayLen(rawRows); j++) {
                    srcIdx = (directionVal EQ "CW" ? (arrayLen(rawRows) - j + 1) : j);
                    leg = duplicate(rawRows[srcIdx]);
                    if (directionVal EQ "CW") {
                        var swapStartName = leg.START_NAME;
                        var swapStartPort = leg.START_PORT_ID;
                        var swapStartLat = leg.START_LAT;
                        var swapStartLng = leg.START_LNG;
                        leg.START_NAME = leg.END_NAME;
                        leg.START_PORT_ID = leg.END_PORT_ID;
                        leg.START_LAT = leg.END_LAT;
                        leg.START_LNG = leg.END_LNG;
                        leg.END_NAME = swapStartName;
                        leg.END_PORT_ID = swapStartPort;
                        leg.END_LAT = swapStartLat;
                        leg.END_LNG = swapStartLng;
                    }
                    if (!len(leg.START_NAME)) leg.START_NAME = "Unknown Start";
                    if (!len(leg.END_NAME)) leg.END_NAME = "Unknown End";
                    leg.ORDER_INDEX = arrayLen(detourDefs[code].SEGMENTS) + 1;
                    leg.IS_OPTIONAL = true;
                    leg.DETOUR_CODE = code;
                    arrayAppend(detourDefs[code].SEGMENTS, leg);
                    detourDefs[code].DELTA_NM += val(leg.DIST_NM);
                    if (leg.IS_OFFSHORE) detourDefs[code].OFFSHORE_LEG_DELTA += 1;
                }
                detourDefs[code].DELTA_NM = roundTo2(detourDefs[code].DELTA_NM);
                detourDefs[code].DELTA_DAYS = routegenEstimateDaysBySpeed(
                    detourDefs[code].DELTA_NM,
                    effectiveSpeedVal,
                    underwayHoursVal
                );
                arrayAppend(out.DETOURS, detourDefs[code]);
                out.BY_CODE[code] = detourDefs[code];
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenFindLegIndexBySegment" access="private" returntype="numeric" output="false">
        <cfargument name="legs" type="array" required="true">
        <cfargument name="segmentId" type="any" required="true">
        <cfscript>
            var wanted = val(arguments.segmentId);
            var i = 0;
            if (wanted LTE 0) return 0;
            for (i = 1; i LTE arrayLen(arguments.legs); i++) {
                if (val(arguments.legs[i].SEGMENT_ID) EQ wanted) {
                    return i;
                }
            }
            return 0;
        </cfscript>
    </cffunction>

    <cffunction name="routegenFindLegIndexByName" access="private" returntype="numeric" output="false">
        <cfargument name="legs" type="array" required="true">
        <cfargument name="name" type="string" required="true">
        <cfargument name="useStart" type="boolean" required="false" default="true">
        <cfscript>
            var i = 0;
            if (!len(trim(arguments.name))) return 0;
            for (i = 1; i LTE arrayLen(arguments.legs); i++) {
                if (arguments.useStart) {
                    if (areLocationNamesEquivalent(arguments.legs[i].START_NAME, arguments.name)) return i;
                } else {
                    if (areLocationNamesEquivalent(arguments.legs[i].END_NAME, arguments.name)) return i;
                }
            }
            return 0;
        </cfscript>
    </cffunction>

    <cffunction name="routegenIsLoopTemplate" access="private" returntype="boolean" output="false">
        <cfargument name="legs" type="array" required="true">
        <cfscript>
            if (arrayLen(arguments.legs) LTE 0) return false;

            var firstLeg = arguments.legs[1];
            var lastLeg = arguments.legs[arrayLen(arguments.legs)];
            var firstStartName = trim(toString(firstLeg.START_NAME));
            var lastEndName = trim(toString(lastLeg.END_NAME));
            var firstStartPortId = val(firstLeg.START_PORT_ID);
            var lastEndPortId = val(lastLeg.END_PORT_ID);

            if (len(firstStartName) AND len(lastEndName) AND areLocationNamesEquivalent(firstStartName, lastEndName)) {
                return true;
            }
            if (firstStartPortId GT 0 AND lastEndPortId GT 0 AND firstStartPortId EQ lastEndPortId) {
                return true;
            }
            return false;
        </cfscript>
    </cffunction>

    <cffunction name="routegenBuildSelection" access="private" returntype="array" output="false">
        <cfargument name="legs" type="array" required="true">
        <cfargument name="startSegmentId" type="any" required="false" default="">
        <cfargument name="endSegmentId" type="any" required="false" default="">
        <cfargument name="startLabel" type="string" required="false" default="">
        <cfargument name="endLabel" type="string" required="false" default="">
        <cfargument name="allowWrap" type="boolean" required="false" default="true">
        <cfscript>
            var selected = [];
            var n = arrayLen(arguments.legs);
            if (n LTE 0) return selected;

            var startIdx = routegenFindLegIndexBySegment(arguments.legs, arguments.startSegmentId);
            var endIdx = routegenFindLegIndexBySegment(arguments.legs, arguments.endSegmentId);
            var i = 0;

            if (startIdx LTE 0) {
                startIdx = routegenFindLegIndexByName(arguments.legs, arguments.startLabel, true);
            }
            if (endIdx LTE 0) {
                endIdx = routegenFindLegIndexByName(arguments.legs, arguments.endLabel, false);
            }
            if (startIdx LTE 0) startIdx = 1;
            if (endIdx LTE 0) endIdx = n;

            if (startIdx EQ endIdx) {
                if (
                    arguments.allowWrap
                    AND n GT 1
                    AND len(trim(arguments.startLabel))
                    AND len(trim(arguments.endLabel))
                    AND areLocationNamesEquivalent(arguments.startLabel, arguments.endLabel)
                ) {
                    for (i = startIdx; i LTE n; i++) {
                        arrayAppend(selected, duplicate(arguments.legs[i]));
                    }
                    for (i = 1; i LT startIdx; i++) {
                        arrayAppend(selected, duplicate(arguments.legs[i]));
                    }
                } else {
                    arrayAppend(selected, duplicate(arguments.legs[startIdx]));
                }
            } else if (endIdx GTE startIdx) {
                for (i = startIdx; i LTE endIdx; i++) {
                    arrayAppend(selected, duplicate(arguments.legs[i]));
                }
            } else {
                if (!arguments.allowWrap) {
                    return [];
                }
                for (i = startIdx; i LTE n; i++) {
                    arrayAppend(selected, duplicate(arguments.legs[i]));
                }
                for (i = 1; i LTE endIdx; i++) {
                    arrayAppend(selected, duplicate(arguments.legs[i]));
                }
            }
            return routegenReindexLegs(selected);
        </cfscript>
    </cffunction>

    <cffunction name="routegenReindexLegs" access="private" returntype="array" output="false">
        <cfargument name="legs" type="array" required="true">
        <cfscript>
            var i = 0;
            for (i = 1; i LTE arrayLen(arguments.legs); i++) {
                arguments.legs[i].ORDER_INDEX = i;
            }
            return arguments.legs;
        </cfscript>
    </cffunction>

    <cffunction name="routegenAppendDetours" access="private" returntype="array" output="false">
        <cfargument name="baseLegs" type="array" required="true">
        <cfargument name="detourByCode" type="struct" required="true">
        <cfargument name="selectedCodes" type="array" required="true">
        <cfscript>
            var out = [];
            var i = 0;
            var j = 0;
            var code = "";
            var detour = {};
            var detourLegs = [];
            var anchor = "";
            var insertAt = 0;

            for (i = 1; i LTE arrayLen(arguments.baseLegs); i++) {
                arrayAppend(out, duplicate(arguments.baseLegs[i]));
            }

            for (i = 1; i LTE arrayLen(arguments.selectedCodes); i++) {
                code = trim(toString(arguments.selectedCodes[i]));
                if (!len(code) OR !structKeyExists(arguments.detourByCode, code)) continue;
                detour = arguments.detourByCode[code];
                detourLegs = (structKeyExists(detour, "SEGMENTS") AND isArray(detour.SEGMENTS) ? detour.SEGMENTS : []);
                if (!arrayLen(detourLegs)) continue;

                anchor = trim(toString(detourLegs[1].START_NAME));
                insertAt = 0;
                for (j = 1; j LTE arrayLen(out); j++) {
                    if (
                        areLocationNamesEquivalent(out[j].END_NAME, anchor)
                        OR areLocationNamesEquivalent(out[j].START_NAME, anchor)
                    ) {
                        insertAt = j;
                        break;
                    }
                }
                if (insertAt LTE 0) insertAt = arrayLen(out);

                for (j = 1; j LTE arrayLen(detourLegs); j++) {
                    arrayInsertAt(out, insertAt + j, duplicate(detourLegs[j]));
                }
            }

            return routegenReindexLegs(out);
        </cfscript>
    </cffunction>

    <cffunction name="routegenComputeTotals" access="private" returntype="struct" output="false">
        <cfargument name="legs" type="array" required="true">
        <cfargument name="cruisingSpeed" type="numeric" required="false" default="10">
        <cfargument name="underwayHoursPerDay" type="numeric" required="false" default="8">
        <cfargument name="fuelBurnGph" type="any" required="false" default="">
        <cfargument name="idleBurnGph" type="any" required="false" default="">
        <cfargument name="idleHoursTotal" type="any" required="false" default="">
        <cfargument name="reservePct" type="any" required="false" default="20">
        <cfargument name="fuelPricePerGal" type="any" required="false" default="">
        <cfargument name="maxSpeedKnots" type="any" required="false" default="">
        <cfargument name="pace" type="any" required="false" default="RELAXED">
        <cfargument name="weatherPct" type="any" required="false" default="">
        <cfscript>
            var totalNm = 0.0;
            var lockCount = 0;
            var offshoreCount = 0;
            var i = 0;
            var leg = {};
            var dist = 0.0;
            var paceVal = routegenNormalizePace(arguments.pace);
            var paceDefaults = routegenPaceDefaults(paceVal);
            var paceRatioVal = val(paceDefaults.PACE_FACTOR);
            var maxSpeedVal = routegenNormalizeCruisingSpeed(arguments.maxSpeedKnots, paceDefaults.MAX_SPEED_KN);
            var effectiveSpeedVal = 0.0;
            var weatherPctVal = routegenNormalizeWeatherFactorPct(arguments.weatherPct);
            var weatherAdj = weatherPctVal / 100;
            var cruisingSpeedVal = routegenNormalizeCruisingSpeed(arguments.cruisingSpeed, 10);
            var underwayHoursVal = routegenNormalizeUnderwayHours(arguments.underwayHoursPerDay);
            var totalRunHours = 0.0;
            var fuelBurnVal = routegenNormalizeFuelBurnGph(arguments.fuelBurnGph);
            var idleBurnVal = routegenNormalizeFuelBurnGph(arguments.idleBurnGph);
            var idleHoursVal = routegenNormalizeIdleHoursTotal(arguments.idleHoursTotal);
            var reservePctVal = routegenNormalizeReservePct(arguments.reservePct, 20);
            var fuelPriceVal = routegenNormalizeFuelPricePerGal(arguments.fuelPricePerGal);
            var totalHours = 0.0;
            var daysByTime = 0;
            var cruiseFuelGallonsVal = 0.0;
            var idleFuelGallonsVal = 0.0;
            var baseFuelGallonsVal = 0.0;
            var reserveFuelGallonsVal = 0.0;
            var requiredFuelGallonsVal = 0.0;
            var fuelCostEstimateVal = 0.0;
            var fuelEstimate = {};

            if (paceRatioVal LT 0.05) paceRatioVal = 0.05;
            if (paceRatioVal GT 1) paceRatioVal = 1;
            effectiveSpeedVal = roundTo2(maxSpeedVal * paceRatioVal);
            cruisingSpeedVal = roundTo2(effectiveSpeedVal * (1 - weatherAdj));
            if (cruisingSpeedVal LT 0.5) cruisingSpeedVal = 0.5;

            for (i = 1; i LTE arrayLen(arguments.legs); i++) {
                leg = arguments.legs[i];
                dist = val(leg.DIST_NM);
                if (dist LT 0) dist = 0;
                totalNm += dist;
                if (dist GT 0 AND cruisingSpeedVal GT 0) {
                    totalRunHours += (dist / cruisingSpeedVal);
                }
                lockCount += val(leg.LOCK_COUNT);
                if (leg.IS_OFFSHORE) offshoreCount += 1;
            }

            totalHours = totalRunHours + idleHoursVal;
            var estimatedDays = 0;
            if (totalHours GT 0) {
                daysByTime = ceiling(totalHours / underwayHoursVal);
                estimatedDays = daysByTime;
                if (estimatedDays LT 1) estimatedDays = 1;
            }

            idleFuelGallonsVal = (idleBurnVal GT 0 AND idleHoursVal GT 0 ? round((idleBurnVal * idleHoursVal) * 10) / 10 : 0);
            fuelEstimate = calculateFuelEstimate({
                "distanceNm"=totalNm,
                "maxSpeedKnots"=maxSpeedVal,
                "maxBurnGph"=fuelBurnVal,
                "pace"=paceVal,
                "weatherPct"=weatherPctVal,
                "idleFuelGallons"=idleFuelGallonsVal,
                "reservePct"=reservePctVal,
                "fuelPricePerGallon"=fuelPriceVal
            });

            cruiseFuelGallonsVal = roundTo2(val(fuelEstimate.cruiseFuelGallons));
            baseFuelGallonsVal = roundTo2(val(fuelEstimate.baseFuelGallons));
            reserveFuelGallonsVal = roundTo2(val(fuelEstimate.reserveGallons));
            requiredFuelGallonsVal = roundTo2(val(fuelEstimate.requiredFuelGallons));
            fuelCostEstimateVal = roundTo2(val(fuelEstimate.totalFuelCost));

            return {
                "TOTAL_NM"=roundTo2(totalNm),
                "ESTIMATED_DAYS"=estimatedDays,
                "LOCK_COUNT"=lockCount,
                "OFFSHORE_LEG_COUNT"=offshoreCount,
                "CRUISING_SPEED_USED"=cruisingSpeedVal,
                "UNDERWAY_HOURS_PER_DAY"=underwayHoursVal,
                "TOTAL_RUN_HOURS"=roundTo2(totalRunHours),
                "IDLE_HOURS_TOTAL"=roundTo2(idleHoursVal),
                "TOTAL_HOURS"=roundTo2(totalHours),
                "CRUISE_FUEL_GALLONS"=cruiseFuelGallonsVal,
                "IDLE_FUEL_GALLONS"=idleFuelGallonsVal,
                "BASE_FUEL_GALLONS"=baseFuelGallonsVal,
                "RESERVE_PCT"=reservePctVal,
                "RESERVE_FUEL_GALLONS"=reserveFuelGallonsVal,
                "REQUIRED_FUEL_GALLONS"=requiredFuelGallonsVal,
                "FUEL_PRICE_PER_GAL"=fuelPriceVal,
                "FUEL_COST_ESTIMATE"=fuelCostEstimateVal,
                "DAYS_BY_TIME"=daysByTime,
                "ESTIMATED_FUEL_GALLONS"=requiredFuelGallonsVal,
                "FUEL_ESTIMATE"=fuelEstimate
            };
        </cfscript>
    </cffunction>

    <cffunction name="routegenBuildPreview" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="false" default="0">
        <cfargument name="input" type="struct" required="true">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unable to build route preview",
                "DATA"={}
            };

            var templateInfo = routegenResolveTemplate(arguments.input.template_code);
            if (!structCount(templateInfo)) {
                out.MESSAGE = "Template route not found";
                out.ERROR = { "MESSAGE"="Select a valid template route." };
                return out;
            }

            var directionVal = normalizeDirection(arguments.input.direction);
            var paceVal = routegenNormalizePace(arguments.input.pace);
            var paceDefaults = routegenPaceDefaults(paceVal);
            var maxSpeedVal = routegenNormalizeCruisingSpeed(arguments.input.cruising_speed, paceDefaults.MAX_SPEED_KN);
            var baseCruiseSpeedVal = routegenComputeEffectiveCruisingSpeed(maxSpeedVal, paceVal);
            var underwayHoursVal = routegenNormalizeUnderwayHours(arguments.input.underway_hours_per_day);
            var fuelBurnGphVal = routegenNormalizeFuelBurnGph(arguments.input.fuel_burn_gph);
            var fuelBurnInputGphVal = routegenNormalizeFuelBurnGph(
                structKeyExists(arguments.input, "fuel_burn_gph_input") ? arguments.input.fuel_burn_gph_input : arguments.input.fuel_burn_gph
            );
            var fuelBurnBasisVal = routegenNormalizeFuelBurnBasis(
                structKeyExists(arguments.input, "fuel_burn_basis") ? arguments.input.fuel_burn_basis : "MAX_SPEED"
            );
            var idleBurnGphVal = routegenNormalizeFuelBurnGph(arguments.input.idle_burn_gph);
            var idleHoursTotalVal = routegenNormalizeIdleHoursTotal(arguments.input.idle_hours_total);
            var weatherFactorPctVal = routegenNormalizeWeatherFactorPct(arguments.input.weather_factor_pct);
            var weatherFactorVal = weatherFactorPctVal / 100;
            var reservePctVal = routegenNormalizeReservePct(arguments.input.reserve_pct, 20);
            var fuelPricePerGalVal = routegenNormalizeFuelPricePerGal(arguments.input.fuel_price_per_gal);
            var paceRatioVal = val(paceDefaults.PACE_FACTOR);
            var weatherAdjustedSpeedVal = roundTo2(baseCruiseSpeedVal * (1 - weatherFactorVal));
            var paceAdjustedBurnVal = paceAdjustedBurnGph(fuelBurnGphVal, paceRatioVal, 3.0);
            var weatherAdjustedBurnVal = roundTo2(paceAdjustedBurnVal * (1 + weatherFactorVal));
            var fuelEstimateOut = {};
            if (weatherAdjustedSpeedVal LT 0.5) weatherAdjustedSpeedVal = 0.5;

            var mainLegs = routegenLoadMainLegs(templateInfo.ID, directionVal);
            if (!arrayLen(mainLegs)) {
                out.MESSAGE = "Template has no segments";
                out.ERROR = { "MESSAGE"="Selected template has no route_template_segments." };
                return out;
            }
            var templateIsLoop = routegenIsLoopTemplate(mainLegs);

            var selectedLegs = routegenBuildSelection(
                legs = mainLegs,
                startSegmentId = arguments.input.start_segment_id,
                endSegmentId = arguments.input.end_segment_id,
                startLabel = arguments.input.start_location_label,
                endLabel = arguments.input.end_location_label,
                allowWrap = templateIsLoop
            );
            if (!arrayLen(selectedLegs)) {
                out.MESSAGE = "Invalid start/end selection";
                out.ERROR = { "MESSAGE"="End location must be after the selected start location for this template and direction." };
                return out;
            }

            var detourData = routegenLoadDetours(templateInfo.ID, directionVal, weatherAdjustedSpeedVal, underwayHoursVal);
            var selectedStopCodes = routegenNormalizeStopFlags(arguments.input.optional_stop_flags);
            var finalLegs = routegenAppendDetours(
                baseLegs = selectedLegs,
                detourByCode = detourData.BY_CODE,
                selectedCodes = selectedStopCodes
            );
            var routeInfo = {};
            var routeLegMap = {};
            var routeLegOverrideMap = {};
            var legRouteLegId = 0;
            var legOverrideKey = "";
            var legOverrideRow = {};

            if (arguments.userId GT 0 AND len(trim(toString(arguments.input.route_code)))) {
                routeInfo = routegenResolveUserRoute(arguments.userId, arguments.input.route_code);
            }
            if (structCount(routeInfo)) {
                routeLegMap = routegenLoadRouteLegMap(routeInfo.ROUTE_ID, arguments.userId);
                routeLegOverrideMap = routegenLoadLegOverridesByRoute(arguments.userId, routeInfo.ROUTE_ID);
            }

            var i = 0;
            for (i = 1; i LTE arrayLen(finalLegs); i++) {
                legRouteLegId = 0;
                if (structKeyExists(routeLegMap, toString(i))) {
                    legRouteLegId = val(routeLegMap[toString(i)].ROUTE_LEG_ID);
                }
                finalLegs[i].ROUTE_LEG_ID = legRouteLegId;
                finalLegs[i].ROUTE_ID = (structCount(routeInfo) ? routeInfo.ROUTE_ID : 0);
                finalLegs[i].DIST_NM_DEFAULT = roundTo2(val(finalLegs[i].DIST_NM));
                finalLegs[i].HAS_USER_OVERRIDE = false;
                finalLegs[i].OVERRIDE_FIELDS = {};
                if (legRouteLegId GT 0) {
                    legOverrideKey = toString(legRouteLegId);
                    if (structKeyExists(routeLegOverrideMap, legOverrideKey)) {
                        legOverrideRow = routeLegOverrideMap[legOverrideKey];
                        finalLegs[i].HAS_USER_OVERRIDE = true;
                        finalLegs[i].DIST_NM = roundTo2(val(legOverrideRow.COMPUTED_NM));
                        if (structKeyExists(legOverrideRow, "OVERRIDE_FIELDS") AND isStruct(legOverrideRow.OVERRIDE_FIELDS)) {
                            finalLegs[i].OVERRIDE_FIELDS = legOverrideRow.OVERRIDE_FIELDS;
                        }
                    }
                }
            }

            var totals = routegenComputeTotals(
                legs = finalLegs,
                cruisingSpeed = weatherAdjustedSpeedVal,
                underwayHoursPerDay = underwayHoursVal,
                fuelBurnGph = fuelBurnGphVal,
                idleBurnGph = idleBurnGphVal,
                idleHoursTotal = idleHoursTotalVal,
                reservePct = reservePctVal,
                fuelPricePerGal = fuelPricePerGalVal,
                maxSpeedKnots = maxSpeedVal,
                pace = paceVal,
                weatherPct = weatherFactorPctVal
            );
            fuelEstimateOut = (structKeyExists(totals, "FUEL_ESTIMATE") AND isStruct(totals.FUEL_ESTIMATE) ? totals.FUEL_ESTIMATE : {});

            out.SUCCESS = true;
            out.MESSAGE = "OK";
            out.DATA = {
                "route"={
                    "route_id"=(structCount(routeInfo) ? routeInfo.ROUTE_ID : 0),
                    "route_code"=(structCount(routeInfo) ? routeInfo.ROUTE_CODE : trim(toString(arguments.input.route_code)))
                },
                "template"={
                    "id"=templateInfo.ID,
                    "code"=(len(templateInfo.SHORT_CODE) ? templateInfo.SHORT_CODE : templateInfo.CODE),
                    "name"=templateInfo.NAME,
                    "description"=templateInfo.DESCRIPTION,
                    "is_loop"=(templateIsLoop ? true : false)
                },
                "inputs"={
                    "template_code"=(len(templateInfo.SHORT_CODE) ? templateInfo.SHORT_CODE : templateInfo.CODE),
                    "route_code"=trim(toString(arguments.input.route_code)),
                    "direction"=directionVal,
                    "start_segment_id"=arguments.input.start_segment_id,
                    "end_segment_id"=arguments.input.end_segment_id,
                    "start_date"=arguments.input.start_date,
                    "pace"=paceVal,
                    "cruising_speed"=maxSpeedVal,
                    "effective_cruising_speed"=(structKeyExists(fuelEstimateOut, "effectiveSpeedKnots") AND val(fuelEstimateOut.effectiveSpeedKnots) GT 0 ? fuelEstimateOut.effectiveSpeedKnots : baseCruiseSpeedVal),
                    "weather_adjusted_speed_kn"=totals.CRUISING_SPEED_USED,
                    "underway_hours_per_day"=underwayHoursVal,
                    "fuel_burn_gph"=(fuelBurnGphVal GT 0 ? fuelBurnGphVal : ""),
                    "fuel_burn_gph_input"=(fuelBurnInputGphVal GT 0 ? fuelBurnInputGphVal : ""),
                    "fuel_burn_basis"=fuelBurnBasisVal,
                    "weather_adjusted_fuel_burn_gph"=(structKeyExists(fuelEstimateOut, "weatherAdjustedBurnGph") AND val(fuelEstimateOut.weatherAdjustedBurnGph) GT 0 ? fuelEstimateOut.weatherAdjustedBurnGph : (weatherAdjustedBurnVal GT 0 ? weatherAdjustedBurnVal : "")),
                    "idle_burn_gph"=(idleBurnGphVal GT 0 ? idleBurnGphVal : ""),
                    "idle_hours_total"=(idleHoursTotalVal GT 0 ? idleHoursTotalVal : ""),
                    "weather_factor_pct"=weatherFactorPctVal,
                    "reserve_pct"=reservePctVal,
                    "fuel_price_per_gal"=(fuelPricePerGalVal GT 0 ? fuelPricePerGalVal : ""),
                    "comfort_profile"=arguments.input.comfort_profile,
                    "overnight_bias"=arguments.input.overnight_bias,
                    "optional_stop_flags"=selectedStopCodes
                },
                "totals"={
                    "total_nm"=totals.TOTAL_NM,
                    "estimated_days"=totals.ESTIMATED_DAYS,
                    "lock_count"=totals.LOCK_COUNT,
                    "offshore_leg_count"=totals.OFFSHORE_LEG_COUNT,
                    "max_speed_kn"=maxSpeedVal,
                    "effective_cruising_speed"=baseCruiseSpeedVal,
                    "weather_adjusted_speed_kn"=totals.CRUISING_SPEED_USED,
                    "underway_hours_per_day"=totals.UNDERWAY_HOURS_PER_DAY,
                    "run_hours"=totals.TOTAL_RUN_HOURS,
                    "idle_hours"=totals.IDLE_HOURS_TOTAL,
                    "total_hours"=totals.TOTAL_HOURS,
                    "days_by_time"=totals.DAYS_BY_TIME,
                    "cruise_fuel_gallons"=totals.CRUISE_FUEL_GALLONS,
                    "idle_fuel_gallons"=totals.IDLE_FUEL_GALLONS,
                    "base_fuel_gallons"=totals.BASE_FUEL_GALLONS,
                    "reserve_pct"=totals.RESERVE_PCT,
                    "reserve_fuel_gallons"=totals.RESERVE_FUEL_GALLONS,
                    "required_fuel_gallons"=totals.REQUIRED_FUEL_GALLONS,
                    "fuel_price_per_gal"=totals.FUEL_PRICE_PER_GAL,
                    "fuel_cost_estimate"=totals.FUEL_COST_ESTIMATE,
                    "total_run_hours"=totals.TOTAL_RUN_HOURS,
                    "estimated_fuel_gallons"=totals.ESTIMATED_FUEL_GALLONS
                },
                "fuelEstimate"={
                    "paceRatio"=(structKeyExists(fuelEstimateOut, "paceRatio") ? fuelEstimateOut.paceRatio : 0),
                    "effectiveSpeedKnots"=(structKeyExists(fuelEstimateOut, "effectiveSpeedKnots") ? fuelEstimateOut.effectiveSpeedKnots : 0),
                    "paceAdjustedBurnGph"=(structKeyExists(fuelEstimateOut, "paceAdjustedBurnGph") ? fuelEstimateOut.paceAdjustedBurnGph : 0),
                    "weatherAdjustedSpeedKnots"=(structKeyExists(fuelEstimateOut, "weatherAdjustedSpeedKnots") ? fuelEstimateOut.weatherAdjustedSpeedKnots : 0),
                    "weatherAdjustedBurnGph"=(structKeyExists(fuelEstimateOut, "weatherAdjustedBurnGph") ? fuelEstimateOut.weatherAdjustedBurnGph : 0),
                    "cruiseHours"=(structKeyExists(fuelEstimateOut, "cruiseHours") ? fuelEstimateOut.cruiseHours : 0),
                    "cruiseFuelGallons"=(structKeyExists(fuelEstimateOut, "cruiseFuelGallons") ? fuelEstimateOut.cruiseFuelGallons : 0),
                    "idleFuelGallons"=(structKeyExists(fuelEstimateOut, "idleFuelGallons") ? fuelEstimateOut.idleFuelGallons : 0),
                    "baseFuelGallons"=(structKeyExists(fuelEstimateOut, "baseFuelGallons") ? fuelEstimateOut.baseFuelGallons : 0),
                    "reserveGallons"=(structKeyExists(fuelEstimateOut, "reserveGallons") ? fuelEstimateOut.reserveGallons : 0),
                    "requiredFuelGallons"=(structKeyExists(fuelEstimateOut, "requiredFuelGallons") ? fuelEstimateOut.requiredFuelGallons : 0),
                    "totalFuelCost"=(structKeyExists(fuelEstimateOut, "totalFuelCost") ? fuelEstimateOut.totalFuelCost : 0)
                },
                "legs"=[],
                "optional_stops"=(structKeyExists(detourData, "DETOURS") ? detourData.DETOURS : [])
            };

            for (i = 1; i LTE arrayLen(finalLegs); i++) {
                arrayAppend(out.DATA.legs, {
                    "order_index"=i,
                    "route_id"=val(finalLegs[i].ROUTE_ID),
                    "route_leg_id"=val(finalLegs[i].ROUTE_LEG_ID),
                    "segment_id"=val(finalLegs[i].SEGMENT_ID),
                    "start_name"=toString(finalLegs[i].START_NAME),
                    "end_name"=toString(finalLegs[i].END_NAME),
                    "start_lat"=(structKeyExists(finalLegs[i], "START_LAT") ? finalLegs[i].START_LAT : ""),
                    "start_lng"=(structKeyExists(finalLegs[i], "START_LNG") ? finalLegs[i].START_LNG : ""),
                    "end_lat"=(structKeyExists(finalLegs[i], "END_LAT") ? finalLegs[i].END_LAT : ""),
                    "end_lng"=(structKeyExists(finalLegs[i], "END_LNG") ? finalLegs[i].END_LNG : ""),
                    "dist_nm"=roundTo2(val(finalLegs[i].DIST_NM)),
                    "dist_nm_default"=roundTo2(val(finalLegs[i].DIST_NM_DEFAULT)),
                    "lock_count"=val(finalLegs[i].LOCK_COUNT),
                    "is_offshore"=(finalLegs[i].IS_OFFSHORE ? true : false),
                    "is_icw"=(finalLegs[i].IS_ICW ? true : false),
                    "is_optional"=(finalLegs[i].IS_OPTIONAL ? true : false),
                    "has_user_override"=(finalLegs[i].HAS_USER_OVERRIDE ? true : false),
                    "detour_code"=toString(finalLegs[i].DETOUR_CODE),
                    "override_fields"=(isStruct(finalLegs[i].OVERRIDE_FIELDS) ? finalLegs[i].OVERRIDE_FIELDS : {}),
                    "flags"={
                        "offshore"=(finalLegs[i].IS_OFFSHORE ? true : false),
                        "optional"=(finalLegs[i].IS_OPTIONAL ? true : false)
                    }
                });
            }

            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenGetOptions" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="templateCode" type="string" required="false" default="">
        <cfargument name="direction" type="string" required="false" default="CCW">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unable to load route options",
                "DATA"={}
            };

            var templateInfo = routegenResolveTemplate(arguments.templateCode);
            if (!structCount(templateInfo)) {
                out.MESSAGE = "Template route not found";
                out.ERROR = { "MESSAGE"="No active template matched template_code." };
                return out;
            }

            var directionVal = normalizeDirection(arguments.direction);
            var mainLegs = routegenLoadMainLegs(templateInfo.ID, directionVal);
            if (!arrayLen(mainLegs)) {
                out.MESSAGE = "Template has no segments";
                out.ERROR = { "MESSAGE"="Selected template has no route_template_segments." };
                return out;
            }
            var templateIsLoop = routegenIsLoopTemplate(mainLegs);

            var defaultPace = routegenPaceDefaults("BALANCED");
            var defaultEffectiveSpeed = routegenComputeEffectiveCruisingSpeed(defaultPace.MAX_SPEED_KN, "BALANCED");
            var detourData = routegenLoadDetours(templateInfo.ID, directionVal, defaultEffectiveSpeed, 8);
            var startOptions = [];
            var endOptions = [];
            var i = 0;
            var startRow = {};
            var endRow = {};
            var stopRow = {};
            for (i = 1; i LTE arrayLen(mainLegs); i++) {
                startRow = {
                    "segment_id"=val(mainLegs[i].SEGMENT_ID),
                    "label"=toString(mainLegs[i].START_NAME),
                    "order_index"=i,
                    "hint"=("Leg " & i & " - " & mainLegs[i].START_NAME & " -> " & mainLegs[i].END_NAME)
                };
                arrayAppend(startOptions, startRow);

                endRow = {
                    "segment_id"=val(mainLegs[i].SEGMENT_ID),
                    "label"=toString(mainLegs[i].END_NAME),
                    "order_index"=i,
                    "hint"=("Leg " & i & " - " & mainLegs[i].START_NAME & " -> " & mainLegs[i].END_NAME)
                };
                arrayAppend(endOptions, endRow);
            }

            var optionalStops = [];
            if (structKeyExists(detourData, "DETOURS") AND isArray(detourData.DETOURS)) {
                for (i = 1; i LTE arrayLen(detourData.DETOURS); i++) {
                    stopRow = {
                        "code"=detourData.DETOURS[i].CODE,
                        "name"=detourData.DETOURS[i].NAME,
                        "description"=detourData.DETOURS[i].DESCRIPTION,
                        "delta_nm"=roundTo2(val(detourData.DETOURS[i].DELTA_NM)),
                        "delta_days"=val(detourData.DETOURS[i].DELTA_DAYS),
                        "offshore_leg_delta"=val(detourData.DETOURS[i].OFFSHORE_LEG_DELTA)
                    };
                    arrayAppend(optionalStops, stopRow);
                }
            }

            out.SUCCESS = true;
            out.MESSAGE = "OK";
            out.DATA = {
                "template"={
                    "id"=templateInfo.ID,
                    "code"=(len(templateInfo.SHORT_CODE) ? templateInfo.SHORT_CODE : templateInfo.CODE),
                    "name"=templateInfo.NAME,
                    "description"=templateInfo.DESCRIPTION,
                    "is_loop"=(templateIsLoop ? true : false)
                },
                "direction"=directionVal,
                "is_loop"=(templateIsLoop ? true : false),
                "startOptions"=startOptions,
                "endOptions"=endOptions,
                "optionalStops"=optionalStops,
                "defaults"={
                    "relaxed"=routegenPaceDefaults("RELAXED"),
                    "balanced"=routegenPaceDefaults("BALANCED"),
                    "aggressive"=routegenPaceDefaults("AGGRESSIVE")
                }
            };
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenPreview" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="input" type="struct" required="true">
        <cfscript>
            var preview = routegenBuildPreview(
                userId = arguments.userId,
                input = arguments.input
            );
            return preview;
        </cfscript>
    </cffunction>

    <cffunction name="routegenResolveUserRoute" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeCode" type="string" required="true">
        <cfscript>
            var routeCodeVal = trim(arguments.routeCode);
            if (!len(routeCodeVal)) return {};

            var userPrefix = "USER_ROUTE_" & int(arguments.userId) & "_%";
            var userIdText = toString(arguments.userId);
            var qRoute = queryExecute(
                "SELECT r.id, r.name, r.short_code
                 FROM loop_routes r
                 LEFT JOIN route_instances ri ON ri.generated_route_id = r.id
                 WHERE r.short_code = :rcode
                   AND (
                        r.short_code LIKE :prefix
                        OR (ri.generated_route_code = r.short_code AND ri.user_id = :uid)
                   )
                 ORDER BY ri.id DESC
                 LIMIT 1",
                {
                    rcode = { value=routeCodeVal, cfsqltype="cf_sql_varchar" },
                    prefix = { value=userPrefix, cfsqltype="cf_sql_varchar" },
                    uid = { value=userIdText, cfsqltype="cf_sql_varchar" }
                },
                { datasource = application.dsn }
            );
            if (qRoute.recordCount EQ 0) return {};

            return {
                "ROUTE_ID"=val(qRoute.id[1]),
                "ROUTE_NAME"=(isNull(qRoute.name[1]) ? "" : trim(toString(qRoute.name[1]))),
                "ROUTE_CODE"=(isNull(qRoute.short_code[1]) ? "" : trim(toString(qRoute.short_code[1])))
            };
        </cfscript>
    </cffunction>

    <cffunction name="routegenGetEditContext" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeCode" type="string" required="true">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unable to load route edit context",
                "DATA"={}
            };

            var routeInfo = routegenResolveUserRoute(arguments.userId, arguments.routeCode);
            if (!structCount(routeInfo)) {
                out.MESSAGE = "Route not found";
                out.ERROR = { "MESSAGE"="Route not found or not owned by user." };
                return out;
            }

            var hasInputsJsonCol = routegenHasInputsJsonColumn();
            var qInstSql = "SELECT id, template_route_code, direction, trip_type, start_location, end_location, created_at";
            if (hasInputsJsonCol) {
                qInstSql &= ", routegen_inputs_json";
            }
            qInstSql &= "
                 FROM route_instances
                 WHERE generated_route_id = :rid
                   AND user_id = :uid
                 ORDER BY id DESC
                 LIMIT 1";
            var qInst = queryExecute(
                qInstSql,
                {
                    rid = { value=routeInfo.ROUTE_ID, cfsqltype="cf_sql_integer" },
                    uid = { value=toString(arguments.userId), cfsqltype="cf_sql_varchar" }
                },
                { datasource = application.dsn }
            );
            if (qInst.recordCount EQ 0) {
                out.MESSAGE = "Route context unavailable";
                out.ERROR = { "MESSAGE"="No route instance metadata found for this route." };
                return out;
            }

            var templateCodeVal = trim(toString(qInst.template_route_code[1]));
            var templateInfo = routegenResolveTemplate(templateCodeVal);
            if (!structCount(templateInfo)) {
                templateInfo = routegenResolveTemplate("");
            }
            if (!structCount(templateInfo)) {
                out.MESSAGE = "Template route not found";
                out.ERROR = { "MESSAGE"="No active template matched this route instance." };
                return out;
            }

            var directionVal = normalizeDirection(qInst.direction[1]);
            var tripTypeVal = normalizeTripType(qInst.trip_type[1]);
            var mainLegs = routegenLoadMainLegs(templateInfo.ID, directionVal);
            if (!arrayLen(mainLegs)) {
                out.MESSAGE = "Template has no segments";
                out.ERROR = { "MESSAGE"="Selected template has no route_template_segments." };
                return out;
            }

            var startLabel = "";
            var endLabel = "";
            var qNormLegBounds = queryExecute(
                "SELECT leg_order, start_name, end_name
                 FROM route_instance_legs
                 WHERE route_instance_id = :routeInstanceId
                 ORDER BY leg_order ASC, id ASC",
                {
                    routeInstanceId = { value=val(qInst.id[1]), cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );

            if (qNormLegBounds.recordCount GT 0) {
                startLabel = trim(toString(qNormLegBounds.start_name[1]));
                endLabel = trim(toString(qNormLegBounds.end_name[qNormLegBounds.recordCount]));
            } else {
                startLabel = trim(toString(qInst.start_location[1]));
                endLabel = trim(toString(qInst.end_location[1]));
            }
            if (!len(startLabel)) startLabel = trim(toString(mainLegs[1].START_NAME));
            if (!len(endLabel)) {
                endLabel = (tripTypeVal EQ "FULL_LOOP" ? startLabel : trim(toString(mainLegs[arrayLen(mainLegs)].END_NAME)));
            }

            var startIdx = routegenFindLegIndexByName(mainLegs, startLabel, true);
            if (startIdx LTE 0) startIdx = 1;
            var endIdx = routegenFindLegIndexByName(mainLegs, endLabel, false);
            if (endIdx LTE 0) {
                endIdx = (tripTypeVal EQ "FULL_LOOP" ? startIdx : arrayLen(mainLegs));
            }

            var storedInputs = {};
            if (hasInputsJsonCol AND !isNull(qInst.routegen_inputs_json[1])) {
                storedInputs = routegenParseStoredInputs(qInst.routegen_inputs_json[1]);
            }
            var paceVal = routegenNormalizePace(
                structKeyExists(storedInputs, "pace") ? storedInputs.pace : "RELAXED"
            );
            var paceDefaults = routegenPaceDefaults(paceVal);
            var maxSpeedVal = routegenNormalizeCruisingSpeed(
                structKeyExists(storedInputs, "cruising_speed") ? storedInputs.cruising_speed : "",
                paceDefaults.MAX_SPEED_KN
            );
            var underwayHoursVal = routegenNormalizeUnderwayHours(
                structKeyExists(storedInputs, "underway_hours_per_day") ? storedInputs.underway_hours_per_day : 8
            );
            var effectiveSpeedVal = routegenComputeEffectiveCruisingSpeed(maxSpeedVal, paceVal);
            var fuelBurnGphVal = routegenNormalizeFuelBurnGph(
                structKeyExists(storedInputs, "fuel_burn_gph") ? storedInputs.fuel_burn_gph : ""
            );
            var fuelBurnInputGphVal = routegenNormalizeFuelBurnGph(
                structKeyExists(storedInputs, "fuel_burn_gph_input")
                    ? storedInputs.fuel_burn_gph_input
                    : (structKeyExists(storedInputs, "fuel_burn_gph") ? storedInputs.fuel_burn_gph : "")
            );
            var fuelBurnBasisVal = routegenNormalizeFuelBurnBasis(
                structKeyExists(storedInputs, "fuel_burn_basis") ? storedInputs.fuel_burn_basis : "MAX_SPEED"
            );
            var idleBurnGphVal = routegenNormalizeFuelBurnGph(
                structKeyExists(storedInputs, "idle_burn_gph") ? storedInputs.idle_burn_gph : ""
            );
            var idleHoursTotalVal = routegenNormalizeIdleHoursTotal(
                structKeyExists(storedInputs, "idle_hours_total") ? storedInputs.idle_hours_total : ""
            );
            var weatherFactorPctVal = routegenNormalizeWeatherFactorPct(
                structKeyExists(storedInputs, "weather_factor_pct") ? storedInputs.weather_factor_pct : ""
            );
            var reservePctVal = routegenNormalizeReservePct(
                structKeyExists(storedInputs, "reserve_pct") ? storedInputs.reserve_pct : "",
                20
            );
            var fuelPricePerGalVal = routegenNormalizeFuelPricePerGal(
                structKeyExists(storedInputs, "fuel_price_per_gal") ? storedInputs.fuel_price_per_gal : ""
            );
            var comfortProfileVal = uCase(
                trim(toString(structKeyExists(storedInputs, "comfort_profile") ? storedInputs.comfort_profile : "PREFER_INSIDE"))
            );
            if (!listFindNoCase("PREFER_INSIDE,BALANCED,OFFSHORE_OK", comfortProfileVal)) {
                comfortProfileVal = "PREFER_INSIDE";
            }
            var overnightBiasVal = uCase(
                trim(toString(structKeyExists(storedInputs, "overnight_bias") ? storedInputs.overnight_bias : "MARINAS"))
            );
            if (!listFindNoCase("MARINAS,ANCHORAGES,MIXED", overnightBiasVal)) {
                overnightBiasVal = "MARINAS";
            }
            var optionalStopFlags = routegenNormalizeStopFlags(
                structKeyExists(storedInputs, "optional_stop_flags") ? storedInputs.optional_stop_flags : []
            );
            var storedStartDate = trim(
                toString(structKeyExists(storedInputs, "start_date") ? storedInputs.start_date : "")
            );
            var startDateVal = "";
            if (len(storedStartDate) AND reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", storedStartDate)) {
                startDateVal = storedStartDate;
            }
            if (!len(startDateVal)) {
                startDateVal = dateFormat(now(), "yyyy-mm-dd");
                if (!isNull(qInst.created_at[1])) {
                    startDateVal = dateFormat(qInst.created_at[1], "yyyy-mm-dd");
                }
            }

            out.SUCCESS = true;
            out.MESSAGE = "OK";
            out.DATA = {
                "route"={
                    "route_id"=routeInfo.ROUTE_ID,
                    "route_code"=routeInfo.ROUTE_CODE,
                    "route_name"=routeInfo.ROUTE_NAME
                },
                "template"={
                    "id"=templateInfo.ID,
                    "code"=(len(templateInfo.SHORT_CODE) ? templateInfo.SHORT_CODE : templateInfo.CODE),
                    "name"=templateInfo.NAME,
                    "description"=templateInfo.DESCRIPTION
                },
                "inputs"={
                    "template_code"=(len(templateInfo.SHORT_CODE) ? templateInfo.SHORT_CODE : templateInfo.CODE),
                    "route_code"=routeInfo.ROUTE_CODE,
                    "direction"=directionVal,
                    "start_segment_id"=val(mainLegs[startIdx].SEGMENT_ID),
                    "end_segment_id"=val(mainLegs[endIdx].SEGMENT_ID),
                    "start_location_label"=startLabel,
                    "end_location_label"=endLabel,
                    "start_date"=startDateVal,
                    "pace"=paceVal,
                    "cruising_speed"=maxSpeedVal,
                    "effective_cruising_speed"=effectiveSpeedVal,
                    "underway_hours_per_day"=underwayHoursVal,
                    "fuel_burn_gph"=(fuelBurnGphVal GT 0 ? fuelBurnGphVal : ""),
                    "fuel_burn_gph_input"=(fuelBurnInputGphVal GT 0 ? fuelBurnInputGphVal : ""),
                    "fuel_burn_basis"=fuelBurnBasisVal,
                    "idle_burn_gph"=(idleBurnGphVal GT 0 ? idleBurnGphVal : ""),
                    "idle_hours_total"=(idleHoursTotalVal GT 0 ? idleHoursTotalVal : ""),
                    "weather_factor_pct"=weatherFactorPctVal,
                    "reserve_pct"=reservePctVal,
                    "fuel_price_per_gal"=(fuelPricePerGalVal GT 0 ? fuelPricePerGalVal : ""),
                    "comfort_profile"=comfortProfileVal,
                    "overnight_bias"=overnightBiasVal,
                    "optional_stop_flags"=optionalStopFlags
                }
            };
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenHasLegOverrideTable" access="private" returntype="boolean" output="false">
        <cfscript>
            var qTbl = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE()
                   AND table_name = 'route_leg_user_overrides'",
                {},
                { datasource = application.dsn }
            );
            return (qTbl.recordCount GT 0 AND val(qTbl.cnt[1]) GT 0);
        </cfscript>
    </cffunction>

    <cffunction name="routegenHasRouteLegLocksTable" access="private" returntype="boolean" output="false">
        <cfscript>
            var qTbl = queryNew("");
            if (structKeyExists(request, "routegenHasRouteLegLocksTable")) {
                return request.routegenHasRouteLegLocksTable;
            }
            qTbl = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE()
                   AND table_name = 'route_leg_locks'",
                {},
                { datasource = application.dsn }
            );
            request.routegenHasRouteLegLocksTable = (qTbl.recordCount GT 0 AND val(qTbl.cnt[1]) GT 0);
            return request.routegenHasRouteLegLocksTable;
        </cfscript>
    </cffunction>

    <cffunction name="routegenHasCanonicalLocksTable" access="private" returntype="boolean" output="false">
        <cfscript>
            var qTbl = queryNew("");
            if (structKeyExists(request, "routegenHasCanonicalLocksTable")) {
                return request.routegenHasCanonicalLocksTable;
            }
            qTbl = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE()
                   AND table_name = 'canonical_locks'",
                {},
                { datasource = application.dsn }
            );
            request.routegenHasCanonicalLocksTable = (qTbl.recordCount GT 0 AND val(qTbl.cnt[1]) GT 0);
            return request.routegenHasCanonicalLocksTable;
        </cfscript>
    </cffunction>

    <cffunction name="routegenHasLockDelayModelTable" access="private" returntype="boolean" output="false">
        <cfscript>
            var qTbl = queryNew("");
            if (structKeyExists(request, "routegenHasLockDelayModelTable")) {
                return request.routegenHasLockDelayModelTable;
            }
            qTbl = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE()
                   AND table_name = 'lock_delay_model'",
                {},
                { datasource = application.dsn }
            );
            request.routegenHasLockDelayModelTable = (qTbl.recordCount GT 0 AND val(qTbl.cnt[1]) GT 0);
            return request.routegenHasLockDelayModelTable;
        </cfscript>
    </cffunction>

    <cffunction name="routegenHasSegmentGeometryTable" access="private" returntype="boolean" output="false">
        <cfscript>
            var qTbl = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE()
                   AND table_name = 'segment_geometries'",
                {},
                { datasource = application.dsn }
            );
            return (qTbl.recordCount GT 0 AND val(qTbl.cnt[1]) GT 0);
        </cfscript>
    </cffunction>

    <cffunction name="routegenHasNormalizedTables" access="private" returntype="boolean" output="false">
        <cfscript>
            var qTbl = queryNew("");
            if (structKeyExists(request, "routegenHasNormalizedTables")) {
                return request.routegenHasNormalizedTables;
            }
            qTbl = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE()
                   AND table_name IN (
                       'route_instance_sections',
                       'route_instance_legs',
                       'route_instance_leg_progress'
                   )",
                {},
                { datasource = application.dsn }
            );
            request.routegenHasNormalizedTables = (qTbl.recordCount GT 0 AND val(qTbl.cnt[1]) GTE 3);
            return request.routegenHasNormalizedTables;
        </cfscript>
    </cffunction>

    <cffunction name="routegenHasUserSegmentOverrideTable" access="private" returntype="boolean" output="false">
        <cfscript>
            var qTbl = queryNew("");
            if (structKeyExists(request, "routegenHasUserSegmentOverrideTable")) {
                return request.routegenHasUserSegmentOverrideTable;
            }
            qTbl = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE()
                   AND table_name = 'user_segment_overrides'",
                {},
                { datasource = application.dsn }
            );
            request.routegenHasUserSegmentOverrideTable = (qTbl.recordCount GT 0 AND val(qTbl.cnt[1]) GT 0);
            return request.routegenHasUserSegmentOverrideTable;
        </cfscript>
    </cffunction>

    <cffunction name="routegenResolveLatestRouteInstanceId" access="private" returntype="numeric" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeId" type="numeric" required="true">
        <cfscript>
            var q = queryNew("");
            if (arguments.userId LTE 0 OR arguments.routeId LTE 0) return 0;
            q = queryExecute(
                "SELECT id
                 FROM route_instances
                 WHERE generated_route_id = :rid
                   AND user_id = :uid
                 ORDER BY id DESC
                 LIMIT 1",
                {
                    rid = { value=arguments.routeId, cfsqltype="cf_sql_integer" },
                    uid = { value=toString(arguments.userId), cfsqltype="cf_sql_varchar" }
                },
                { datasource = application.dsn }
            );
            if (q.recordCount EQ 0) return 0;
            return val(q.id[1]);
        </cfscript>
    </cffunction>

    <cffunction name="routegenHasNormalizedLegRows" access="private" returntype="boolean" output="false">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfscript>
            var q = queryNew("");
            if (!routegenHasNormalizedTables()) return false;
            if (arguments.routeInstanceId LTE 0) return false;
            q = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM route_instance_legs
                 WHERE route_instance_id = :routeInstanceId",
                {
                    routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );
            return (q.recordCount GT 0 AND val(q.cnt[1]) GT 0);
        </cfscript>
    </cffunction>

    <cffunction name="routegenSyncNormalizedRouteInstance" access="private" returntype="void" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeId" type="numeric" required="true">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfscript>
            var sqlInsertLegs = "";
            var directionVal = "CCW";
            var qInst = queryNew("");
            var lockJoinSql = "";
            var lockExpr = "COALESCE(sl.lock_count, 0)";

            if (!routegenHasNormalizedTables()) return;
            if (arguments.userId LTE 0 OR arguments.routeId LTE 0 OR arguments.routeInstanceId LTE 0) return;

            if (routegenHasRouteLegLocksTable()) {
                lockJoinSql =
                    " LEFT JOIN (
                        SELECT route_code, leg, COUNT(*) AS lock_count
                        FROM route_leg_locks
                        GROUP BY route_code, leg
                      ) rll
                        ON rll.route_code COLLATE utf8mb4_unicode_ci = rt.short_code
                       AND rll.leg = rts.order_index";
                lockExpr = "COALESCE(rll.lock_count, sl.lock_count, 0)";
            }

            qInst = queryExecute(
                "SELECT direction
                 FROM route_instances
                 WHERE id = :routeInstanceId
                 LIMIT 1",
                {
                    routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );
            if (qInst.recordCount GT 0 AND !isNull(qInst.direction[1])) {
                directionVal = normalizeDirection(qInst.direction[1]);
            }

            queryExecute(
                "DELETE FROM route_instance_leg_progress
                 WHERE route_instance_id = :routeInstanceId",
                {
                    routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );

            queryExecute(
                "DELETE FROM route_instance_legs
                 WHERE route_instance_id = :routeInstanceId",
                {
                    routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );

            queryExecute(
                "DELETE FROM route_instance_sections
                 WHERE route_instance_id = :routeInstanceId",
                {
                    routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );

            queryExecute(
                "INSERT INTO route_instance_sections
                    (route_instance_id, section_order, name, phase_num, source_section_id)
                 VALUES
                    (:routeInstanceId, 1, 'Route', 1, NULL)",
                {
                    routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );

            sqlInsertLegs =
                "INSERT INTO route_instance_legs
                    (route_instance_id, route_instance_section_id, leg_order, segment_id, source_loop_segment_id,
                     is_reversed, is_optional, detour_code, start_name, end_name,
                     start_lat, start_lng, end_lat, end_lng, base_dist_nm, lock_count, notes)
                 SELECT
                    :routeInstanceId,
                    ris.id AS route_instance_section_id,
                    ROW_NUMBER() OVER (
                        ORDER BY " & (directionVal EQ "CW" ? "rts.order_index DESC, rts.id DESC" : "rts.order_index ASC, rts.id ASC") & "
                    ) AS leg_order,
                    sl.id AS segment_id,
                    sl.id AS source_loop_segment_id,
                    " & (directionVal EQ "CW" ? "1" : "0") & " AS is_reversed,
                    COALESCE(rts.is_optional, 0) AS is_optional,
                    NULL,
                    " & (directionVal EQ "CW"
                        ? "COALESCE(NULLIF(TRIM(p2.name), ''), TRIM(sl.end_port_name), '')"
                        : "COALESCE(NULLIF(TRIM(p1.name), ''), TRIM(sl.start_port_name), '')") & " AS start_name,
                    " & (directionVal EQ "CW"
                        ? "COALESCE(NULLIF(TRIM(p1.name), ''), TRIM(sl.start_port_name), '')"
                        : "COALESCE(NULLIF(TRIM(p2.name), ''), TRIM(sl.end_port_name), '')") & " AS end_name,
                    " & (directionVal EQ "CW" ? "p2.lat" : "p1.lat") & " AS start_lat,
                    " & (directionVal EQ "CW" ? "p2.lng" : "p1.lng") & " AS start_lng,
                    " & (directionVal EQ "CW" ? "p1.lat" : "p2.lat") & " AS end_lat,
                    " & (directionVal EQ "CW" ? "p1.lng" : "p2.lng") & " AS end_lng,
                    sl.dist_nm AS base_dist_nm,
                    " & lockExpr & " AS lock_count,
                    sl.notes
                 FROM route_template_segments rts
                 INNER JOIN loop_routes rt ON rt.id = rts.route_id
                 INNER JOIN segment_library sl ON sl.id = rts.segment_id
                 LEFT JOIN ports p1 ON p1.id = sl.start_port_id
                 LEFT JOIN ports p2 ON p2.id = sl.end_port_id
                 " & lockJoinSql & "
                 INNER JOIN route_instance_sections ris
                    ON ris.route_instance_id = :routeInstanceId
                   AND ris.section_order = 1
                 WHERE rts.route_id = :routeId";
            queryExecute(
                sqlInsertLegs,
                {
                    routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" },
                    routeId = { value=arguments.routeId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );

            if (routegenHasLegOverrideTable()) {
                queryExecute(
                    "UPDATE route_instance_legs ril
                     INNER JOIN route_leg_user_overrides rluo
                        ON rluo.route_id = :routeId
                       AND rluo.route_leg_id = ril.source_loop_segment_id
                     SET ril.segment_id = rluo.segment_id
                     WHERE ril.route_instance_id = :routeInstanceId
                       AND (ril.segment_id IS NULL OR ril.segment_id = 0)
                       AND rluo.segment_id IS NOT NULL
                       AND rluo.segment_id > 0",
                    {
                        routeId = { value=arguments.routeId, cfsqltype="cf_sql_integer" },
                        routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" }
                    },
                    { datasource = application.dsn }
                );
            }

            queryExecute(
                "INSERT INTO route_instance_leg_progress
                    (user_id, route_instance_id, leg_order, status, completed_at)
                 SELECT
                    :userId,
                    :routeInstanceId,
                    ril.leg_order,
                    COALESCE(NULLIF(TRIM(up.status), ''), 'NOT_STARTED'),
                    up.completed_at
                 FROM route_instance_legs ril
                 LEFT JOIN user_route_progress up
                    ON up.user_id = :userId
                   AND up.segment_id = ril.segment_id
                 WHERE ril.route_instance_id = :routeInstanceId",
                {
                    userId = { value=arguments.userId, cfsqltype="cf_sql_integer" },
                    routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );
        </cfscript>
    </cffunction>

    <cffunction name="routegenLoadCanonicalSegmentMap" access="private" returntype="struct" output="false">
        <cfargument name="segmentIds" type="array" required="true">
        <cfscript>
            var out = {};
            var ids = [];
            var seen = {};
            var sid = 0;
            var i = 0;
            var sidKey = "";
            var q = queryNew("");
            var startNameVal = "";
            var endNameVal = "";
            var startLatVal = "";
            var startLngVal = "";
            var endLatVal = "";
            var endLngVal = "";

            for (i = 1; i LTE arrayLen(arguments.segmentIds); i++) {
                sid = val(arguments.segmentIds[i]);
                if (sid LTE 0) continue;
                sidKey = toString(sid);
                if (structKeyExists(seen, sidKey)) continue;
                seen[sidKey] = true;
                arrayAppend(ids, sid);
            }
            if (!arrayLen(ids)) return out;

            q = queryExecute(
                "SELECT
                    sl.id AS segment_id,
                    COALESCE(NULLIF(TRIM(p1.name), ''), TRIM(sl.start_port_name), '') AS start_name,
                    COALESCE(NULLIF(TRIM(p2.name), ''), TRIM(sl.end_port_name), '') AS end_name,
                    p1.lat AS start_lat,
                    p1.lng AS start_lng,
                    p2.lat AS end_lat,
                    p2.lng AS end_lng
                 FROM segment_library sl
                 LEFT JOIN ports p1 ON p1.id = sl.start_port_id
                 LEFT JOIN ports p2 ON p2.id = sl.end_port_id
                 WHERE sl.id IN (:segmentIds)",
                {
                    segmentIds = {
                        value = arrayToList(ids),
                        cfsqltype = "cf_sql_integer",
                        list = true
                    }
                },
                { datasource = application.dsn }
            );

            for (i = 1; i LTE q.recordCount; i++) {
                sid = val(q.segment_id[i]);
                if (sid LTE 0) continue;
                startNameVal = (isNull(q.start_name[i]) ? "" : trim(toString(q.start_name[i])));
                endNameVal = (isNull(q.end_name[i]) ? "" : trim(toString(q.end_name[i])));
                startLatVal = (isNull(q.start_lat[i]) ? "" : q.start_lat[i]);
                startLngVal = (isNull(q.start_lng[i]) ? "" : q.start_lng[i]);
                endLatVal = (isNull(q.end_lat[i]) ? "" : q.end_lat[i]);
                endLngVal = (isNull(q.end_lng[i]) ? "" : q.end_lng[i]);
                out[toString(sid)] = {
                    "SEGMENT_ID"=sid,
                    "START_NAME"=startNameVal,
                    "END_NAME"=endNameVal,
                    "START_LAT"=startLatVal,
                    "START_LNG"=startLngVal,
                    "END_LAT"=endLatVal,
                    "END_LNG"=endLngVal
                };
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenRebuildNormalizedInstanceLegs" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfargument name="legs" type="array" required="true">
        <cfscript>
            var out = { "SECTION_ID"=0, "LEG_ID_BY_ORDER"={} };
            var i = 0;
            var leg = {};
            var legOrderVal = 0;
            var segmentIdVal = 0;
            var segmentIds = [];
            var canonicalBySegment = {};
            var canonical = {};
            var segmentKey = "";
            var isOptionalVal = 0;
            var isReversedVal = 0;
            var detourCodeVal = "";
            var notesVal = "";
            var legStartNameVal = "";
            var legEndNameVal = "";
            var canonicalStartNameVal = "";
            var canonicalEndNameVal = "";
            var startLatRaw = "";
            var startLngRaw = "";
            var endLatRaw = "";
            var endLngRaw = "";
            var inputReverseFlag = false;
            var distBind = {};
            var lockBind = {};
            var startLatBind = {};
            var startLngBind = {};
            var endLatBind = {};
            var endLngBind = {};
            var notesBind = {};

            if (!routegenHasNormalizedTables()) return out;
            if (arguments.userId LTE 0 OR arguments.routeInstanceId LTE 0 OR !arrayLen(arguments.legs)) return out;
            for (i = 1; i LTE arrayLen(arguments.legs); i++) {
                leg = arguments.legs[i];
                segmentIdVal = val(structKeyExists(leg, "segment_id") ? leg.segment_id : (structKeyExists(leg, "SEGMENT_ID") ? leg.SEGMENT_ID : 0));
                if (segmentIdVal GT 0) {
                    arrayAppend(segmentIds, segmentIdVal);
                }
            }
            canonicalBySegment = routegenLoadCanonicalSegmentMap(segmentIds);

            queryExecute(
                "DELETE FROM route_instance_leg_progress
                 WHERE route_instance_id = :routeInstanceId",
                {
                    routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );
            queryExecute(
                "DELETE FROM route_instance_legs
                 WHERE route_instance_id = :routeInstanceId",
                {
                    routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );
            queryExecute(
                "DELETE FROM route_instance_sections
                 WHERE route_instance_id = :routeInstanceId",
                {
                    routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );

            queryExecute(
                "INSERT INTO route_instance_sections
                    (route_instance_id, section_order, name, phase_num, source_section_id)
                 VALUES
                    (:routeInstanceId, 1, 'Route', 1, NULL)",
                {
                    routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn, result = "routegenNormSecIns" }
            );
            out.SECTION_ID = val(routegenNormSecIns.generatedKey);

            for (i = 1; i LTE arrayLen(arguments.legs); i++) {
                leg = arguments.legs[i];
                legOrderVal = val(structKeyExists(leg, "order_index") ? leg.order_index : i);
                if (legOrderVal LTE 0) legOrderVal = i;
                segmentIdVal = val(structKeyExists(leg, "segment_id") ? leg.segment_id : (structKeyExists(leg, "SEGMENT_ID") ? leg.SEGMENT_ID : 0));
                isOptionalVal = (toBoolean(structKeyExists(leg, "is_optional") ? leg.is_optional : false, false) ? 1 : 0);
                inputReverseFlag = toBoolean(structKeyExists(leg, "is_reversed") ? leg.is_reversed : false, false);
                detourCodeVal = trim(toString(structKeyExists(leg, "detour_code") ? leg.detour_code : ""));
                notesVal = trim(toString(structKeyExists(leg, "notes") ? leg.notes : ""));
                legStartNameVal = trim(toString(structKeyExists(leg, "start_name") ? leg.start_name : ""));
                legEndNameVal = trim(toString(structKeyExists(leg, "end_name") ? leg.end_name : ""));
                startLatRaw = (structKeyExists(leg, "start_lat") ? leg.start_lat : "");
                startLngRaw = (structKeyExists(leg, "start_lng") ? leg.start_lng : "");
                endLatRaw = (structKeyExists(leg, "end_lat") ? leg.end_lat : "");
                endLngRaw = (structKeyExists(leg, "end_lng") ? leg.end_lng : "");
                isReversedVal = (inputReverseFlag ? 1 : 0);

                if (segmentIdVal GT 0) {
                    segmentKey = toString(segmentIdVal);
                    if (structKeyExists(canonicalBySegment, segmentKey)) {
                        canonical = canonicalBySegment[segmentKey];
                        canonicalStartNameVal = trim(toString(structKeyExists(canonical, "START_NAME") ? canonical.START_NAME : ""));
                        canonicalEndNameVal = trim(toString(structKeyExists(canonical, "END_NAME") ? canonical.END_NAME : ""));

                        if (
                            len(legStartNameVal) AND len(legEndNameVal)
                            AND len(canonicalStartNameVal) AND len(canonicalEndNameVal)
                        ) {
                            if (
                                areLocationNamesEquivalent(legStartNameVal, canonicalEndNameVal)
                                AND areLocationNamesEquivalent(legEndNameVal, canonicalStartNameVal)
                            ) {
                                isReversedVal = 1;
                            } else if (
                                areLocationNamesEquivalent(legStartNameVal, canonicalStartNameVal)
                                AND areLocationNamesEquivalent(legEndNameVal, canonicalEndNameVal)
                            ) {
                                isReversedVal = 0;
                            }
                        }

                        if (isReversedVal EQ 1) {
                            if (len(canonicalEndNameVal)) legStartNameVal = canonicalEndNameVal;
                            if (len(canonicalStartNameVal)) legEndNameVal = canonicalStartNameVal;
                            if (isNumeric(canonical.END_LAT)) startLatRaw = canonical.END_LAT;
                            if (isNumeric(canonical.END_LNG)) startLngRaw = canonical.END_LNG;
                            if (isNumeric(canonical.START_LAT)) endLatRaw = canonical.START_LAT;
                            if (isNumeric(canonical.START_LNG)) endLngRaw = canonical.START_LNG;
                        } else {
                            if (len(canonicalStartNameVal)) legStartNameVal = canonicalStartNameVal;
                            if (len(canonicalEndNameVal)) legEndNameVal = canonicalEndNameVal;
                            if (isNumeric(canonical.START_LAT)) startLatRaw = canonical.START_LAT;
                            if (isNumeric(canonical.START_LNG)) startLngRaw = canonical.START_LNG;
                            if (isNumeric(canonical.END_LAT)) endLatRaw = canonical.END_LAT;
                            if (isNumeric(canonical.END_LNG)) endLngRaw = canonical.END_LNG;
                        }
                    }
                }

                if (isOptionalVal EQ 1 AND len(detourCodeVal)) {
                    if (len(notesVal)) notesVal &= " ";
                    notesVal &= "[Optional stop: " & detourCodeVal & "]";
                }

                distBind = toNullableNumber((structKeyExists(leg, "dist_nm") ? leg.dist_nm : 0), "numeric");
                lockBind = toNullableNumber((structKeyExists(leg, "lock_count") ? leg.lock_count : 0), "integer");
                startLatBind = toNullableNumber(startLatRaw, "numeric");
                startLngBind = toNullableNumber(startLngRaw, "numeric");
                endLatBind = toNullableNumber(endLatRaw, "numeric");
                endLngBind = toNullableNumber(endLngRaw, "numeric");
                notesBind = toNullableString(notesVal);
                if (!notesBind.isNull AND len(notesBind.value) GT 255) {
                    notesBind.value = left(notesBind.value, 255);
                }

                queryExecute(
                    "INSERT INTO route_instance_legs
                        (route_instance_id, route_instance_section_id, leg_order, segment_id, source_loop_segment_id,
                         is_reversed, is_optional, detour_code, start_name, end_name,
                         start_lat, start_lng, end_lat, end_lng, base_dist_nm, lock_count, notes)
                     VALUES
                        (:routeInstanceId, :sectionId, :legOrder, :segmentId, NULL,
                         :isReversed, :isOptional, :detourCode, :startName, :endName,
                         :startLat, :startLng, :endLat, :endLng, :distNm, :lockCount, :notes)",
                    {
                        routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" },
                        sectionId = { value=out.SECTION_ID, cfsqltype="cf_sql_integer" },
                        legOrder = { value=legOrderVal, cfsqltype="cf_sql_integer" },
                        segmentId = { value=segmentIdVal, cfsqltype="cf_sql_integer", null=(segmentIdVal LTE 0) },
                        isReversed = { value=isReversedVal, cfsqltype="cf_sql_integer" },
                        isOptional = { value=isOptionalVal, cfsqltype="cf_sql_integer" },
                        detourCode = { value=detourCodeVal, cfsqltype="cf_sql_varchar", null=NOT len(detourCodeVal) },
                        startName = { value=legStartNameVal, cfsqltype="cf_sql_varchar", null=NOT len(legStartNameVal) },
                        endName = { value=legEndNameVal, cfsqltype="cf_sql_varchar", null=NOT len(legEndNameVal) },
                        startLat = { value=startLatBind.value, cfsqltype="cf_sql_decimal", null=startLatBind.isNull, scale=7 },
                        startLng = { value=startLngBind.value, cfsqltype="cf_sql_decimal", null=startLngBind.isNull, scale=7 },
                        endLat = { value=endLatBind.value, cfsqltype="cf_sql_decimal", null=endLatBind.isNull, scale=7 },
                        endLng = { value=endLngBind.value, cfsqltype="cf_sql_decimal", null=endLngBind.isNull, scale=7 },
                        distNm = { value=distBind.value, cfsqltype="cf_sql_decimal", null=distBind.isNull },
                        lockCount = { value=lockBind.value, cfsqltype="cf_sql_integer", null=lockBind.isNull },
                        notes = { value=notesBind.value, cfsqltype="cf_sql_varchar", null=notesBind.isNull }
                    },
                    { datasource = application.dsn, result = "routegenNormLegIns" }
                );
                out.LEG_ID_BY_ORDER[toString(legOrderVal)] = val(routegenNormLegIns.generatedKey);
            }

            queryExecute(
                "INSERT INTO route_instance_leg_progress
                    (user_id, route_instance_id, leg_order, status, completed_at)
                 SELECT
                    :userId,
                    :routeInstanceId,
                    ril.leg_order,
                    'NOT_STARTED',
                    NULL
                 FROM route_instance_legs ril
                 WHERE ril.route_instance_id = :routeInstanceId",
                {
                    userId = { value=arguments.userId, cfsqltype="cf_sql_integer" },
                    routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );

            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenParseJsonStruct" access="private" returntype="struct" output="false">
        <cfargument name="rawJson" type="any" required="false" default="">
        <cfscript>
            var raw = trim(toString(arguments.rawJson));
            var parsed = {};
            if (!len(raw)) return {};
            try {
                parsed = deserializeJSON(raw, false);
                if (isStruct(parsed)) return parsed;
            } catch (any ignored) {}
            return {};
        </cfscript>
    </cffunction>

    <cffunction name="routegenNormalizeOverridePoints" access="private" returntype="struct" output="false">
        <cfargument name="pointsRaw" type="any" required="true">
        <cfscript>
            var out = { "ok"=false, "message"="", "detail"="", "points"=[] };
            var i = 0;
            var p = {};
            var latRaw = "";
            var lonRaw = "";
            var latVal = 0.0;
            var lonVal = 0.0;

            if (!isArray(arguments.pointsRaw)) {
                out.message = "Geometry must be an array of points.";
                out.detail = "Use [{lat, lon}, ...].";
                return out;
            }

            for (i = 1; i LTE arrayLen(arguments.pointsRaw); i++) {
                if (!isStruct(arguments.pointsRaw[i])) {
                    out.message = "Point ##" & i & " is invalid.";
                    out.detail = "Each point must be an object.";
                    return out;
                }
                p = arguments.pointsRaw[i];
                latRaw = "";
                lonRaw = "";
                if (structKeyExists(p, "lat")) latRaw = p.lat;
                else if (structKeyExists(p, "latitude")) latRaw = p.latitude;
                if (structKeyExists(p, "lon")) lonRaw = p.lon;
                else if (structKeyExists(p, "lng")) lonRaw = p.lng;
                else if (structKeyExists(p, "longitude")) lonRaw = p.longitude;

                if (!len(trim(toString(latRaw))) OR !len(trim(toString(lonRaw)))) {
                    out.message = "Point ##" & i & " is missing lat/lon.";
                    out.detail = "Each point must include lat and lon (or lng).";
                    return out;
                }
                if (!isNumeric(latRaw) OR !isNumeric(lonRaw)) {
                    out.message = "Point ##" & i & " has invalid coordinates.";
                    out.detail = "Latitude/longitude must be numeric.";
                    return out;
                }

                latVal = val(latRaw);
                lonVal = val(lonRaw);
                if (latVal LT -90 OR latVal GT 90) {
                    out.message = "Point ##" & i & " latitude out of range.";
                    out.detail = "Latitude must be between -90 and 90.";
                    return out;
                }
                if (lonVal LT -180 OR lonVal GT 180) {
                    out.message = "Point ##" & i & " longitude out of range.";
                    out.detail = "Longitude must be between -180 and 180.";
                    return out;
                }
                arrayAppend(out.points, { "lat"=latVal, "lon"=lonVal });
            }
            out.ok = true;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenParsePointsJson" access="private" returntype="array" output="false">
        <cfargument name="rawJson" type="any" required="false" default="">
        <cfscript>
            var raw = trim(toString(arguments.rawJson));
            var parsed = [];
            var normalized = {};
            if (!len(raw)) return [];
            try {
                parsed = deserializeJSON(raw, false);
                if (!isArray(parsed)) return [];
            } catch (any ignored) {
                return [];
            }
            normalized = routegenNormalizeOverridePoints(parsed);
            if (!normalized.ok) return [];
            return normalized.points;
        </cfscript>
    </cffunction>

    <cffunction name="routegenLoadRouteLegMap" access="private" returntype="struct" output="false">
        <cfargument name="routeId" type="numeric" required="true">
        <cfargument name="userId" type="numeric" required="false" default="0">
        <cfscript>
            var out = {};
            var qRouteInst = queryNew("");
            var qLegs = queryNew("");
            var i = 0;
            var routeInstanceIdVal = 0;
            var legOrderVal = 0;
            if (arguments.routeId LTE 0) return out;
            if (!routegenHasNormalizedTables()) return out;

            if (arguments.userId GT 0) {
                routeInstanceIdVal = routegenResolveLatestRouteInstanceId(arguments.userId, arguments.routeId);
            }
            if (routeInstanceIdVal LTE 0) {
                qRouteInst = queryExecute(
                    "SELECT id
                     FROM route_instances
                     WHERE generated_route_id = :rid
                     ORDER BY id DESC
                     LIMIT 1",
                    {
                        rid = { value=arguments.routeId, cfsqltype="cf_sql_integer" }
                    },
                    { datasource = application.dsn }
                );
                if (qRouteInst.recordCount EQ 0) return out;
                routeInstanceIdVal = val(qRouteInst.id[1]);
            }

            qLegs = queryExecute(
                "SELECT
                    COALESCE(ril.source_loop_segment_id, ril.id) AS route_leg_id,
                    ril.leg_order,
                    ril.start_name,
                    ril.end_name,
                    ril.base_dist_nm
                 FROM route_instance_legs ril
                 WHERE ril.route_instance_id = :routeInstanceId
                 ORDER BY ril.leg_order ASC, ril.id ASC",
                {
                    routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );
            for (i = 1; i LTE qLegs.recordCount; i++) {
                legOrderVal = (isNull(qLegs.leg_order[i]) ? i : val(qLegs.leg_order[i]));
                if (legOrderVal LTE 0) legOrderVal = i;
                out[toString(legOrderVal)] = {
                    "ROUTE_LEG_ID"=val(qLegs.route_leg_id[i]),
                    "ROUTE_LEG_ORDER"=legOrderVal,
                    "DIST_NM"=(isNull(qLegs.base_dist_nm[i]) ? 0 : val(qLegs.base_dist_nm[i])),
                    "START_NAME"=(isNull(qLegs.start_name[i]) ? "" : trim(toString(qLegs.start_name[i]))),
                    "END_NAME"=(isNull(qLegs.end_name[i]) ? "" : trim(toString(qLegs.end_name[i])))
                };
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenResolveRouteLegOrder" access="private" returntype="numeric" output="false">
        <cfargument name="routeId" type="numeric" required="true">
        <cfargument name="routeLegId" type="numeric" required="true">
        <cfargument name="userId" type="numeric" required="false" default="0">
        <cfscript>
            var legMap = routegenLoadRouteLegMap(arguments.routeId, arguments.userId);
            var k = "";
            for (k in legMap) {
                if (val(legMap[k].ROUTE_LEG_ID) EQ val(arguments.routeLegId)) {
                    return val(k);
                }
            }
            return 0;
        </cfscript>
    </cffunction>

    <cffunction name="routegenReadRouteLeg" access="private" returntype="struct" output="false">
        <cfargument name="routeId" type="numeric" required="true">
        <cfargument name="routeLegId" type="numeric" required="true">
        <cfargument name="userId" type="numeric" required="false" default="0">
        <cfscript>
            var qLeg = queryNew("");
            var row = {};
            var startLat = "";
            var startLng = "";
            var endLat = "";
            var endLng = "";
            var sql = "";
            var binds = {};
            if (arguments.routeId LTE 0 OR arguments.routeLegId LTE 0) return {};
            if (!routegenHasNormalizedTables()) return {};

            sql = "SELECT
                    COALESCE(ril.source_loop_segment_id, ril.id) AS route_leg_id,
                    ril.leg_order AS order_index,
                    ril.start_name,
                    ril.end_name,
                    ril.base_dist_nm AS dist_nm,
                    ril.start_lat,
                    ril.start_lng,
                    ril.end_lat,
                    ril.end_lng
                 FROM route_instance_legs ril
                 INNER JOIN route_instances ri ON ri.id = ril.route_instance_id
                 WHERE ri.generated_route_id = :rid
                   AND (
                        COALESCE(ril.source_loop_segment_id, ril.id) = :legId
                        OR ril.id = :legIdExact
                   )";
            binds = {
                rid = { value=arguments.routeId, cfsqltype="cf_sql_integer" },
                legId = { value=arguments.routeLegId, cfsqltype="cf_sql_integer" },
                legIdExact = { value=arguments.routeLegId, cfsqltype="cf_sql_integer" }
            };
            if (arguments.userId GT 0) {
                sql &= " AND ri.user_id = :uid";
                binds.uid = { value=toString(arguments.userId), cfsqltype="cf_sql_varchar" };
            }
            sql &= " ORDER BY ri.id DESC, ril.leg_order ASC, ril.id ASC LIMIT 1";
            qLeg = queryExecute(sql, binds, { datasource = application.dsn });

            if (qLeg.recordCount EQ 0) return {};
            row = {
                "ROUTE_LEG_ID"=val(qLeg.route_leg_id[1]),
                "ORDER_INDEX"=(isNull(qLeg.order_index[1]) ? 0 : val(qLeg.order_index[1])),
                "START_NAME"=(isNull(qLeg.start_name[1]) ? "" : trim(toString(qLeg.start_name[1]))),
                "END_NAME"=(isNull(qLeg.end_name[1]) ? "" : trim(toString(qLeg.end_name[1]))),
                "DIST_NM"=(isNull(qLeg.dist_nm[1]) ? 0 : val(qLeg.dist_nm[1])),
                "START_POINT"={},
                "END_POINT"={}
            };
            startLat = (isNull(qLeg.start_lat[1]) ? "" : qLeg.start_lat[1]);
            startLng = (isNull(qLeg.start_lng[1]) ? "" : qLeg.start_lng[1]);
            if (isNumeric(startLat) AND isNumeric(startLng)) {
                row.START_POINT = {
                    "lat"=val(startLat),
                    "lon"=val(startLng)
                };
            }
            endLat = (isNull(qLeg.end_lat[1]) ? "" : qLeg.end_lat[1]);
            endLng = (isNull(qLeg.end_lng[1]) ? "" : qLeg.end_lng[1]);
            if (isNumeric(endLat) AND isNumeric(endLng)) {
                row.END_POINT = {
                    "lat"=val(endLat),
                    "lon"=val(endLng)
                };
            }
            return row;
        </cfscript>
    </cffunction>

    <cffunction name="routegenReadLegOverride" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeId" type="numeric" required="true">
        <cfargument name="routeLegId" type="numeric" required="true">
        <cfscript>
            var q = queryNew("");
            var row = {};
            if (!routegenHasLegOverrideTable()) return {};
            if (arguments.userId LTE 0 OR arguments.routeId LTE 0 OR arguments.routeLegId LTE 0) return {};
            q = queryExecute(
                "SELECT
                    route_leg_id,
                    route_leg_order,
                    segment_id,
                    computed_nm,
                    geometry_json,
                    override_fields_json
                 FROM route_leg_user_overrides
                 WHERE user_id = :uid
                   AND route_id = :rid
                   AND route_leg_id = :legId
                 LIMIT 1",
                {
                    uid = { value=arguments.userId, cfsqltype="cf_sql_integer" },
                    rid = { value=arguments.routeId, cfsqltype="cf_sql_integer" },
                    legId = { value=arguments.routeLegId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );
            if (q.recordCount EQ 0) return {};
            row = {
                "ROUTE_LEG_ID"=val(q.route_leg_id[1]),
                "ROUTE_LEG_ORDER"=(isNull(q.route_leg_order[1]) ? 0 : val(q.route_leg_order[1])),
                "SEGMENT_ID"=(isNull(q.segment_id[1]) ? 0 : val(q.segment_id[1])),
                "COMPUTED_NM"=(isNull(q.computed_nm[1]) ? 0 : val(q.computed_nm[1])),
                "POINTS"=routegenParsePointsJson(isNull(q.geometry_json[1]) ? "" : toString(q.geometry_json[1])),
                "OVERRIDE_FIELDS"=routegenParseJsonStruct(isNull(q.override_fields_json[1]) ? "" : q.override_fields_json[1])
            };
            return row;
        </cfscript>
    </cffunction>

    <cffunction name="routegenReadLatestOverrideBySegment" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="segmentId" type="numeric" required="true">
        <cfscript>
            var q = queryNew("");
            var row = {};
            if (!routegenHasLegOverrideTable()) return {};
            if (arguments.userId LTE 0 OR arguments.segmentId LTE 0) return {};
            q = queryExecute(
                "SELECT
                    route_id,
                    route_leg_id,
                    route_leg_order,
                    segment_id,
                    computed_nm,
                    geometry_json,
                    override_fields_json
                 FROM route_leg_user_overrides
                 WHERE user_id = :uid
                   AND segment_id = :segmentId
                 ORDER BY updated_at DESC, id DESC
                 LIMIT 1",
                {
                    uid = { value=arguments.userId, cfsqltype="cf_sql_integer" },
                    segmentId = { value=arguments.segmentId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );
            if (q.recordCount EQ 0) return {};
            row = {
                "ROUTE_ID"=(isNull(q.route_id[1]) ? 0 : val(q.route_id[1])),
                "ROUTE_LEG_ID"=val(q.route_leg_id[1]),
                "ROUTE_LEG_ORDER"=(isNull(q.route_leg_order[1]) ? 0 : val(q.route_leg_order[1])),
                "SEGMENT_ID"=(isNull(q.segment_id[1]) ? 0 : val(q.segment_id[1])),
                "COMPUTED_NM"=(isNull(q.computed_nm[1]) ? 0 : val(q.computed_nm[1])),
                "POINTS"=routegenParsePointsJson(isNull(q.geometry_json[1]) ? "" : toString(q.geometry_json[1])),
                "OVERRIDE_FIELDS"=routegenParseJsonStruct(isNull(q.override_fields_json[1]) ? "" : q.override_fields_json[1])
            };
            return row;
        </cfscript>
    </cffunction>

    <cffunction name="routegenLoadLegOverridesByRoute" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeId" type="numeric" required="true">
        <cfscript>
            var out = {};
            var q = queryNew("");
            var i = 0;
            if (!routegenHasLegOverrideTable()) return out;
            if (arguments.userId LTE 0 OR arguments.routeId LTE 0) return out;
            q = queryExecute(
                "SELECT
                    route_leg_id,
                    route_leg_order,
                    segment_id,
                    computed_nm,
                    geometry_json,
                    override_fields_json
                 FROM route_leg_user_overrides
                 WHERE user_id = :uid
                   AND route_id = :rid",
                {
                    uid = { value=arguments.userId, cfsqltype="cf_sql_integer" },
                    rid = { value=arguments.routeId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );
            for (i = 1; i LTE q.recordCount; i++) {
                out[toString(q.route_leg_id[i])] = {
                    "ROUTE_LEG_ID"=val(q.route_leg_id[i]),
                    "ROUTE_LEG_ORDER"=(isNull(q.route_leg_order[i]) ? 0 : val(q.route_leg_order[i])),
                    "SEGMENT_ID"=(isNull(q.segment_id[i]) ? 0 : val(q.segment_id[i])),
                    "COMPUTED_NM"=(isNull(q.computed_nm[i]) ? 0 : val(q.computed_nm[i])),
                    "POINTS"=routegenParsePointsJson(isNull(q.geometry_json[i]) ? "" : toString(q.geometry_json[i])),
                    "OVERRIDE_FIELDS"=routegenParseJsonStruct(isNull(q.override_fields_json[i]) ? "" : q.override_fields_json[i])
                };
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenLoadDefaultLegGeometry" access="private" returntype="struct" output="false">
        <cfargument name="segmentId" type="numeric" required="true">
        <cfscript>
            var out = {
                "HAS_GEOMETRY"=false,
                "POINTS"=[],
                "DIST_NM"=0,
                "START_NAME"="",
                "END_NAME"="",
                "START_POINT"={},
                "END_POINT"={}
            };
            var qGeom = queryNew("");
            var qSeg = queryNew("");
            var rawGeom = "";
            var startLat = "";
            var startLng = "";
            var endLat = "";
            var endLng = "";
            if (arguments.segmentId LTE 0) return out;

            if (routegenHasSegmentGeometryTable()) {
                qGeom = queryExecute(
                    "SELECT polyline_json, dist_nm_calc
                     FROM segment_geometries
                     WHERE segment_id = :segmentId
                     ORDER BY version DESC
                     LIMIT 1",
                    {
                        segmentId = { value=arguments.segmentId, cfsqltype="cf_sql_integer" }
                    },
                    { datasource = application.dsn }
                );
                if (qGeom.recordCount GT 0) {
                    rawGeom = (isNull(qGeom.polyline_json[1]) ? "" : toString(qGeom.polyline_json[1]));
                    out.POINTS = routegenParsePointsJson(rawGeom);
                    out.HAS_GEOMETRY = (arrayLen(out.POINTS) GTE 2);
                    if (!isNull(qGeom.dist_nm_calc[1])) {
                        out.DIST_NM = roundTo2(val(qGeom.dist_nm_calc[1]));
                    }
                }
            }

            qSeg = queryExecute(
                "SELECT
                    sl.dist_nm,
                    COALESCE(NULLIF(TRIM(p1.name), ''), TRIM(sl.start_port_name), '') AS start_name,
                    COALESCE(NULLIF(TRIM(p2.name), ''), TRIM(sl.end_port_name), '') AS end_name,
                    p1.lat AS start_lat,
                    p1.lng AS start_lng,
                    p2.lat AS end_lat,
                    p2.lng AS end_lng
                 FROM segment_library sl
                 LEFT JOIN ports p1 ON p1.id = sl.start_port_id
                 LEFT JOIN ports p2 ON p2.id = sl.end_port_id
                 WHERE sl.id = :segmentId
                 LIMIT 1",
                {
                    segmentId = { value=arguments.segmentId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );
            if (qSeg.recordCount GT 0) {
                if (out.DIST_NM LTE 0 AND !isNull(qSeg.dist_nm[1])) {
                    out.DIST_NM = roundTo2(val(qSeg.dist_nm[1]));
                }
                out.START_NAME = (isNull(qSeg.start_name[1]) ? "" : trim(toString(qSeg.start_name[1])));
                out.END_NAME = (isNull(qSeg.end_name[1]) ? "" : trim(toString(qSeg.end_name[1])));

                startLat = (isNull(qSeg.start_lat[1]) ? "" : qSeg.start_lat[1]);
                startLng = (isNull(qSeg.start_lng[1]) ? "" : qSeg.start_lng[1]);
                if (isNumeric(startLat) AND isNumeric(startLng)) {
                    out.START_POINT = {
                        "lat"=val(startLat),
                        "lon"=val(startLng)
                    };
                }

                endLat = (isNull(qSeg.end_lat[1]) ? "" : qSeg.end_lat[1]);
                endLng = (isNull(qSeg.end_lng[1]) ? "" : qSeg.end_lng[1]);
                if (isNumeric(endLat) AND isNumeric(endLng)) {
                    out.END_POINT = {
                        "lat"=val(endLat),
                        "lon"=val(endLng)
                    };
                }
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenResolvePortPointByName" access="private" returntype="struct" output="false">
        <cfargument name="portName" type="string" required="false" default="">
        <cfscript>
            var out = {};
            var nameVal = trim(arguments.portName);
            var q = queryNew("");
            if (!len(nameVal)) return out;
            q = queryExecute(
                "SELECT lat, lng
                 FROM ports
                 WHERE LOWER(TRIM(name)) = LOWER(TRIM(:name))
                   AND lat IS NOT NULL
                   AND lng IS NOT NULL
                 ORDER BY id ASC
                 LIMIT 1",
                {
                    name = { value=nameVal, cfsqltype="cf_sql_varchar" }
                },
                { datasource = application.dsn }
            );
            if (q.recordCount EQ 0) return out;
            if (!isNumeric(q.lat[1]) OR !isNumeric(q.lng[1])) return out;
            out = {
                "lat"=val(q.lat[1]),
                "lon"=val(q.lng[1])
            };
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenGetLegGeometry" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeCode" type="string" required="false" default="">
        <cfargument name="routeLegId" type="numeric" required="false" default="0">
        <cfargument name="segmentId" type="numeric" required="false" default="0">
        <cfargument name="legOrder" type="numeric" required="false" default="0">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unable to load leg geometry",
                "DATA"={}
            };
            var routeCodeVal = trim(arguments.routeCode);
            var routeInfo = {};
            var routeLegIdVal = val(arguments.routeLegId);
            var segmentIdVal = val(arguments.segmentId);
            var legOrderVal = val(arguments.legOrder);
            var routeLegMap = {};
            var legRow = {};
            var overrideRow = {};
            var segmentOverrideRow = {};
            var defaultGeom = {};
            var routeInstanceIdVal = 0;
            var useNormalizedRead = false;
            var qNormLeg = queryNew("");
            var normSql = "";
            var normParams = {};
            var normRouteLegId = 0;
            var normStartLat = "";
            var normStartLng = "";
            var normEndLat = "";
            var normEndLng = "";
            var fallbackPoint = {};
            var effectivePoints = [];
            var effectiveNm = 0;
            var defaultNm = 0;
            var hasExactOverride = false;
            var hasSegmentOverride = false;
            var sourceVal = "default";

            if (len(routeCodeVal)) {
                routeInfo = routegenResolveUserRoute(arguments.userId, routeCodeVal);
                if (!structCount(routeInfo)) {
                    out.MESSAGE = "Route not found";
                    out.ERROR = { "MESSAGE"="Route not found or not owned by user." };
                    return out;
                }

                routeInstanceIdVal = routegenResolveLatestRouteInstanceId(arguments.userId, routeInfo.ROUTE_ID);
                useNormalizedRead = routegenHasNormalizedLegRows(routeInstanceIdVal);
                if (!useNormalizedRead) {
                    out.MESSAGE = "Route geometry unavailable";
                    out.ERROR = { "MESSAGE"="Route instance has no normalized leg rows." };
                    return out;
                }

                if (useNormalizedRead) {
                    normSql = "SELECT
                            ril.id,
                            ril.leg_order,
                            ril.segment_id,
                            ril.source_loop_segment_id,
                            ril.start_name,
                            ril.end_name,
                            ril.base_dist_nm,
                            ril.start_lat,
                            ril.start_lng,
                            ril.end_lat,
                            ril.end_lng
                         FROM route_instance_legs ril
                         WHERE ril.route_instance_id = :routeInstanceId";
                    normParams = {
                        routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" }
                    };

                    if (legOrderVal GT 0) {
                        normSql &= " AND ril.leg_order = :legOrder";
                        normParams.legOrder = { value=legOrderVal, cfsqltype="cf_sql_integer" };
                    } else if (routeLegIdVal GT 0) {
                        normSql &= " AND (COALESCE(ril.source_loop_segment_id, ril.id) = :routeLegId OR ril.id = :routeLegIdExact)";
                        normParams.routeLegId = { value=routeLegIdVal, cfsqltype="cf_sql_integer" };
                        normParams.routeLegIdExact = { value=routeLegIdVal, cfsqltype="cf_sql_integer" };
                    } else if (segmentIdVal GT 0) {
                        normSql &= " AND ril.segment_id = :segmentId";
                        normParams.segmentId = { value=segmentIdVal, cfsqltype="cf_sql_integer" };
                    }

                    normSql &= " ORDER BY ril.leg_order ASC, ril.id ASC LIMIT 1";
                    qNormLeg = queryExecute(
                        normSql,
                        normParams,
                        { datasource = application.dsn }
                    );

                    if (qNormLeg.recordCount GT 0) {
                        normRouteLegId = (
                            isNull(qNormLeg.source_loop_segment_id[1]) OR val(qNormLeg.source_loop_segment_id[1]) LTE 0
                                ? val(qNormLeg.id[1])
                                : val(qNormLeg.source_loop_segment_id[1])
                        );
                        legRow = {
                            "ROUTE_LEG_ID"=normRouteLegId,
                            "ORDER_INDEX"=(isNull(qNormLeg.leg_order[1]) ? 0 : val(qNormLeg.leg_order[1])),
                            "START_NAME"=(isNull(qNormLeg.start_name[1]) ? "" : trim(toString(qNormLeg.start_name[1]))),
                            "END_NAME"=(isNull(qNormLeg.end_name[1]) ? "" : trim(toString(qNormLeg.end_name[1]))),
                            "DIST_NM"=(isNull(qNormLeg.base_dist_nm[1]) ? 0 : val(qNormLeg.base_dist_nm[1])),
                            "START_POINT"={},
                            "END_POINT"={}
                        };
                        routeLegIdVal = normRouteLegId;
                        legOrderVal = (legOrderVal GT 0 ? legOrderVal : val(legRow.ORDER_INDEX));
                        if (segmentIdVal LTE 0 AND !isNull(qNormLeg.segment_id[1])) {
                            segmentIdVal = val(qNormLeg.segment_id[1]);
                        }

                        normStartLat = (isNull(qNormLeg.start_lat[1]) ? "" : qNormLeg.start_lat[1]);
                        normStartLng = (isNull(qNormLeg.start_lng[1]) ? "" : qNormLeg.start_lng[1]);
                        if (isNumeric(normStartLat) AND isNumeric(normStartLng)) {
                            legRow.START_POINT = {
                                "lat"=val(normStartLat),
                                "lon"=val(normStartLng)
                            };
                        }

                        normEndLat = (isNull(qNormLeg.end_lat[1]) ? "" : qNormLeg.end_lat[1]);
                        normEndLng = (isNull(qNormLeg.end_lng[1]) ? "" : qNormLeg.end_lng[1]);
                        if (isNumeric(normEndLat) AND isNumeric(normEndLng)) {
                            legRow.END_POINT = {
                                "lat"=val(normEndLat),
                                "lon"=val(normEndLng)
                            };
                        }
                    }
                }

                if (!structCount(legRow)) {
                    out.MESSAGE = "Leg not found";
                    out.ERROR = { "MESSAGE"="Requested route leg was not found in this route instance." };
                    return out;
                }
                if (segmentIdVal LTE 0) {
                    segmentIdVal = 0;
                }

                if (routeLegIdVal GT 0) {
                    overrideRow = routegenReadLegOverride(arguments.userId, routeInfo.ROUTE_ID, routeLegIdVal);
                }
            }

            if (!structCount(overrideRow) AND segmentIdVal GT 0) {
                segmentOverrideRow = routegenReadLatestOverrideBySegment(arguments.userId, segmentIdVal);
            }

            defaultGeom = routegenLoadDefaultLegGeometry(segmentIdVal);
            defaultNm = roundTo2(val(defaultGeom.DIST_NM));
            if (structCount(legRow) AND defaultNm LTE 0) {
                defaultNm = roundTo2(val(legRow.DIST_NM));
            }

            if (structCount(overrideRow)) {
                effectivePoints = (structKeyExists(overrideRow, "POINTS") AND isArray(overrideRow.POINTS) ? overrideRow.POINTS : []);
                effectiveNm = roundTo2(val(overrideRow.COMPUTED_NM));
                hasExactOverride = true;
                sourceVal = "user_override";
            } else if (structCount(segmentOverrideRow)) {
                effectivePoints = (structKeyExists(segmentOverrideRow, "POINTS") AND isArray(segmentOverrideRow.POINTS) ? segmentOverrideRow.POINTS : []);
                effectiveNm = roundTo2(val(segmentOverrideRow.COMPUTED_NM));
                if (effectiveNm LTE 0 AND arrayLen(effectivePoints) GTE 2) {
                    effectiveNm = roundTo2(routegenCalculatePolylineNm(effectivePoints));
                }
                if (effectiveNm LTE 0) {
                    effectiveNm = defaultNm;
                }
                hasSegmentOverride = true;
                sourceVal = "user_segment";
            } else {
                effectivePoints = (structKeyExists(defaultGeom, "POINTS") AND isArray(defaultGeom.POINTS) ? defaultGeom.POINTS : []);
                effectiveNm = defaultNm;
                sourceVal = "default";
            }

            if (
                structCount(legRow)
                AND (!structKeyExists(legRow, "START_POINT") OR !isStruct(legRow.START_POINT) OR !structCount(legRow.START_POINT))
            ) {
                fallbackPoint = routegenResolvePortPointByName(
                    structKeyExists(legRow, "START_NAME") ? legRow.START_NAME : ""
                );
                if (structCount(fallbackPoint)) {
                    legRow.START_POINT = fallbackPoint;
                }
            }
            if (
                structCount(legRow)
                AND (!structKeyExists(legRow, "END_POINT") OR !isStruct(legRow.END_POINT) OR !structCount(legRow.END_POINT))
            ) {
                fallbackPoint = routegenResolvePortPointByName(
                    structKeyExists(legRow, "END_NAME") ? legRow.END_NAME : ""
                );
                if (structCount(fallbackPoint)) {
                    legRow.END_POINT = fallbackPoint;
                }
            }

            out.SUCCESS = true;
            out.MESSAGE = "OK";
            out.DATA = {
                "route_id"=(structCount(routeInfo) ? routeInfo.ROUTE_ID : 0),
                "route_code"=(structCount(routeInfo) ? routeInfo.ROUTE_CODE : ""),
                "route_leg_id"=routeLegIdVal,
                "leg_order"=legOrderVal,
                "segment_id"=segmentIdVal,
                "has_override"=hasExactOverride,
                "has_segment_override"=hasSegmentOverride,
                "source"=sourceVal,
                "computed_nm"=roundTo2(effectiveNm),
                "default_nm"=roundTo2(defaultNm),
                "leg_start_point"=(
                    structCount(legRow) AND structKeyExists(legRow, "START_POINT") AND isStruct(legRow.START_POINT)
                        ? legRow.START_POINT
                        : {}
                ),
                "leg_end_point"=(
                    structCount(legRow) AND structKeyExists(legRow, "END_POINT") AND isStruct(legRow.END_POINT)
                        ? legRow.END_POINT
                        : {}
                ),
                "default_start_name"=(structKeyExists(defaultGeom, "START_NAME") ? defaultGeom.START_NAME : ""),
                "default_end_name"=(structKeyExists(defaultGeom, "END_NAME") ? defaultGeom.END_NAME : ""),
                "default_start_point"=(
                    structKeyExists(defaultGeom, "START_POINT") AND isStruct(defaultGeom.START_POINT)
                        ? defaultGeom.START_POINT
                        : {}
                ),
                "default_end_point"=(
                    structKeyExists(defaultGeom, "END_POINT") AND isStruct(defaultGeom.END_POINT)
                        ? defaultGeom.END_POINT
                        : {}
                ),
                "points"=effectivePoints
            };
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenGetLegLocks" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeCode" type="string" required="false" default="">
        <cfargument name="templateCode" type="string" required="false" default="">
        <cfargument name="routeLegId" type="numeric" required="false" default="0">
        <cfargument name="segmentId" type="numeric" required="false" default="0">
        <cfargument name="legOrder" type="numeric" required="false" default="0">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unable to load lock details",
                "DATA"={}
            };
            var routeCodeVal = trim(arguments.routeCode);
            var templateCodeVal = trim(arguments.templateCode);
            var routeInfo = {};
            var routeInstanceIdVal = 0;
            var routeLegIdVal = val(arguments.routeLegId);
            var segmentIdVal = val(arguments.segmentId);
            var legOrderVal = val(arguments.legOrder);
            var startNameVal = "";
            var endNameVal = "";
            var qInst = queryNew("");
            var qLeg = queryNew("");
            var qMap = queryNew("");
            var qLocks = queryNew("");
            var qMapSql = "";
            var qMapParams = {};
            var qLocksSql = "";
            var mapShortCodeVal = "";
            var mapRouteCodeVal = "";
            var mapLegOrderVal = 0;
            var totalBaseCycleMin = 0;
            var totalBestWaitMin = 0;
            var totalTypicalWaitMin = 0;
            var totalWorstWaitMin = 0;
            var hasDelayModel = routegenHasLockDelayModelTable();
            var i = 0;
            var lockRow = {};
            var routeLegResolved = 0;

            if (!routegenHasRouteLegLocksTable()) {
                out.MESSAGE = "Lock data unavailable";
                out.ERROR = { "MESSAGE"="route_leg_locks table is missing." };
                return out;
            }
            if (!routegenHasCanonicalLocksTable()) {
                out.MESSAGE = "Lock data unavailable";
                out.ERROR = { "MESSAGE"="canonical_locks table is missing." };
                return out;
            }

            if (len(routeCodeVal)) {
                routeInfo = routegenResolveUserRoute(arguments.userId, routeCodeVal);
                if (!structCount(routeInfo)) {
                    out.MESSAGE = "Route not found";
                    out.ERROR = { "MESSAGE"="Route not found or not owned by user." };
                    return out;
                }

                routeInstanceIdVal = routegenResolveLatestRouteInstanceId(arguments.userId, routeInfo.ROUTE_ID);
                if (routeInstanceIdVal LTE 0) {
                    out.MESSAGE = "Route locks unavailable";
                    out.ERROR = { "MESSAGE"="Route instance could not be resolved." };
                    return out;
                }

                qInst = queryExecute(
                    "SELECT template_route_code
                     FROM route_instances
                     WHERE id = :routeInstanceId
                     LIMIT 1",
                    {
                        routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" }
                    },
                    { datasource = application.dsn }
                );
                if (!len(templateCodeVal) AND qInst.recordCount GT 0 AND !isNull(qInst.template_route_code[1])) {
                    templateCodeVal = trim(toString(qInst.template_route_code[1]));
                }

                var qLegSql =
                    "SELECT
                        ril.id,
                        ril.leg_order,
                        ril.segment_id,
                        ril.source_loop_segment_id,
                        ril.start_name,
                        ril.end_name
                     FROM route_instance_legs ril
                     WHERE ril.route_instance_id = :routeInstanceId";
                var qLegParams = {
                    routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" }
                };

                if (legOrderVal GT 0) {
                    qLegSql &= " AND ril.leg_order = :legOrder";
                    qLegParams.legOrder = { value=legOrderVal, cfsqltype="cf_sql_integer" };
                } else if (routeLegIdVal GT 0) {
                    qLegSql &= " AND (COALESCE(ril.source_loop_segment_id, ril.id) = :routeLegId OR ril.id = :routeLegIdExact)";
                    qLegParams.routeLegId = { value=routeLegIdVal, cfsqltype="cf_sql_integer" };
                    qLegParams.routeLegIdExact = { value=routeLegIdVal, cfsqltype="cf_sql_integer" };
                } else if (segmentIdVal GT 0) {
                    qLegSql &= " AND ril.segment_id = :segmentId";
                    qLegParams.segmentId = { value=segmentIdVal, cfsqltype="cf_sql_integer" };
                } else {
                    out.MESSAGE = "Leg required";
                    out.ERROR = { "MESSAGE"="Provide leg_order, route_leg_id, or segment_id." };
                    return out;
                }

                qLegSql &= " ORDER BY ril.leg_order ASC, ril.id ASC LIMIT 1";
                qLeg = queryExecute(qLegSql, qLegParams, { datasource = application.dsn });
                if (qLeg.recordCount EQ 0) {
                    out.MESSAGE = "Leg not found";
                    out.ERROR = { "MESSAGE"="Requested leg was not found in this route instance." };
                    return out;
                }

                routeLegResolved = (
                    isNull(qLeg.source_loop_segment_id[1]) OR val(qLeg.source_loop_segment_id[1]) LTE 0
                        ? val(qLeg.id[1])
                        : val(qLeg.source_loop_segment_id[1])
                );
                routeLegIdVal = routeLegResolved;
                if (legOrderVal LTE 0) {
                    legOrderVal = (isNull(qLeg.leg_order[1]) ? 0 : val(qLeg.leg_order[1]));
                }
                if (segmentIdVal LTE 0 AND !isNull(qLeg.segment_id[1])) {
                    segmentIdVal = val(qLeg.segment_id[1]);
                }
                startNameVal = (isNull(qLeg.start_name[1]) ? "" : trim(toString(qLeg.start_name[1])));
                endNameVal = (isNull(qLeg.end_name[1]) ? "" : trim(toString(qLeg.end_name[1])));
            }

            if (segmentIdVal LTE 0) {
                out.MESSAGE = "Segment required";
                out.ERROR = { "MESSAGE"="segment_id is required to resolve lock details." };
                return out;
            }

            qMapSql =
                "SELECT
                    rt.short_code,
                    rt.code,
                    rts.order_index
                 FROM route_template_segments rts
                 INNER JOIN loop_routes rt ON rt.id = rts.route_id
                 WHERE rts.segment_id = :segmentId";
            qMapParams = {
                segmentId = { value=segmentIdVal, cfsqltype="cf_sql_integer" }
            };
            if (len(templateCodeVal)) {
                qMapSql &= "
                    AND (rt.short_code = :templateCode OR rt.code = :templateCode)";
                qMapParams.templateCode = { value=templateCodeVal, cfsqltype="cf_sql_varchar" };
                qMapSql &= "
                 ORDER BY
                    CASE
                        WHEN rt.short_code = :templateCode THEN 0
                        WHEN rt.code = :templateCode THEN 1
                        ELSE 2
                    END,
                    rts.order_index ASC,
                    rt.id ASC
                 LIMIT 1";
            } else {
                qMapSql &= "
                 ORDER BY rt.is_default DESC, rt.id ASC, rts.order_index ASC
                 LIMIT 1";
            }
            qMap = queryExecute(qMapSql, qMapParams, { datasource = application.dsn });

            if (qMap.recordCount EQ 0 AND len(templateCodeVal)) {
                qMap = queryExecute(
                    "SELECT
                        rt.short_code,
                        rt.code,
                        rts.order_index
                     FROM route_template_segments rts
                     INNER JOIN loop_routes rt ON rt.id = rts.route_id
                     WHERE rts.segment_id = :segmentId
                     ORDER BY rt.is_default DESC, rt.id ASC, rts.order_index ASC
                     LIMIT 1",
                    {
                        segmentId = { value=segmentIdVal, cfsqltype="cf_sql_integer" }
                    },
                    { datasource = application.dsn }
                );
            }

            if (qMap.recordCount EQ 0) {
                out.SUCCESS = true;
                out.MESSAGE = "No lock mapping for this leg";
                out.DATA = {
                    "route_code"=(structCount(routeInfo) ? routeInfo.ROUTE_CODE : routeCodeVal),
                    "template_code"=templateCodeVal,
                    "template_route_code"=templateCodeVal,
                    "route_leg_id"=routeLegIdVal,
                    "leg_order"=legOrderVal,
                    "segment_id"=segmentIdVal,
                    "start_name"=startNameVal,
                    "end_name"=endNameVal,
                    "lock_count"=0,
                    "totals"={
                        "base_cycle_min"=0,
                        "best_wait_min"=0,
                        "typical_wait_min"=0,
                        "worst_wait_min"=0
                    },
                    "locks"=[]
                };
                return out;
            }

            mapShortCodeVal = (isNull(qMap.short_code[1]) ? "" : trim(toString(qMap.short_code[1])));
            mapRouteCodeVal = (isNull(qMap.code[1]) ? "" : trim(toString(qMap.code[1])));
            mapLegOrderVal = (isNull(qMap.order_index[1]) ? 0 : val(qMap.order_index[1]));

            qLocksSql =
                "SELECT
                    rll.seq,
                    rll.lock_code,
                    COALESCE(cl.name, rll.lock_code) AS lock_name,
                    COALESCE(cl.waterway, '') AS waterway,
                    COALESCE(cl.state, '') AS state_code,
                    COALESCE(cl.country, '') AS country_code,
                    cl.lat,
                    cl.lng,
                    COALESCE(cl.lock_type, '') AS lock_type,
                    cl.chamber_length_ft,
                    cl.chamber_width_ft,
                    COALESCE(cl.agency, '') AS agency,
                    COALESCE(cl.source, '') AS source_url,
                    COALESCE(cl.notes, '') AS lock_notes,"
                    & (hasDelayModel ? "
                    ldm.base_cycle_min,
                    ldm.best_wait_min,
                    ldm.typical_wait_min,
                    ldm.worst_wait_min,
                    COALESCE(ldm.notes, '') AS delay_notes" : "
                    NULL AS base_cycle_min,
                    NULL AS best_wait_min,
                    NULL AS typical_wait_min,
                    NULL AS worst_wait_min,
                    '' AS delay_notes")
                    & "
                 FROM route_leg_locks rll
                 LEFT JOIN canonical_locks cl ON cl.lock_code = rll.lock_code"
                    & (hasDelayModel ? "
                 LEFT JOIN lock_delay_model ldm ON ldm.lock_code = rll.lock_code" : "")
                    & "
                 WHERE rll.route_code COLLATE utf8mb4_unicode_ci = :routeShortCode
                   AND rll.leg = :templateLeg
                 ORDER BY rll.seq ASC, rll.lock_code ASC";
            qLocks = queryExecute(
                qLocksSql,
                {
                    routeShortCode = { value=mapShortCodeVal, cfsqltype="cf_sql_varchar" },
                    templateLeg = { value=mapLegOrderVal, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );

            out.SUCCESS = true;
            out.MESSAGE = "OK";
            out.DATA = {
                "route_code"=(structCount(routeInfo) ? routeInfo.ROUTE_CODE : routeCodeVal),
                "template_code"=mapShortCodeVal,
                "template_route_code"=mapRouteCodeVal,
                "template_leg_order"=mapLegOrderVal,
                "route_leg_id"=routeLegIdVal,
                "leg_order"=legOrderVal,
                "segment_id"=segmentIdVal,
                "start_name"=startNameVal,
                "end_name"=endNameVal,
                "lock_count"=0,
                "totals"={
                    "base_cycle_min"=0,
                    "best_wait_min"=0,
                    "typical_wait_min"=0,
                    "worst_wait_min"=0
                },
                "locks"=[]
            };

            for (i = 1; i LTE qLocks.recordCount; i++) {
                lockRow = {
                    "seq"=(isNull(qLocks.seq[i]) ? i : val(qLocks.seq[i])),
                    "lock_code"=(isNull(qLocks.lock_code[i]) ? "" : trim(toString(qLocks.lock_code[i]))),
                    "name"=(isNull(qLocks.lock_name[i]) ? "" : trim(toString(qLocks.lock_name[i]))),
                    "waterway"=(isNull(qLocks.waterway[i]) ? "" : trim(toString(qLocks.waterway[i]))),
                    "state_code"=(isNull(qLocks.state_code[i]) ? "" : trim(toString(qLocks.state_code[i]))),
                    "country_code"=(isNull(qLocks.country_code[i]) ? "" : trim(toString(qLocks.country_code[i]))),
                    "lat"=(isNull(qLocks.lat[i]) ? javacast("null", "") : val(qLocks.lat[i])),
                    "lng"=(isNull(qLocks.lng[i]) ? javacast("null", "") : val(qLocks.lng[i])),
                    "lock_type"=(isNull(qLocks.lock_type[i]) ? "" : trim(toString(qLocks.lock_type[i]))),
                    "chamber_length_ft"=(isNull(qLocks.chamber_length_ft[i]) ? 0 : val(qLocks.chamber_length_ft[i])),
                    "chamber_width_ft"=(isNull(qLocks.chamber_width_ft[i]) ? 0 : val(qLocks.chamber_width_ft[i])),
                    "agency"=(isNull(qLocks.agency[i]) ? "" : trim(toString(qLocks.agency[i]))),
                    "source_url"=(isNull(qLocks.source_url[i]) ? "" : trim(toString(qLocks.source_url[i]))),
                    "lock_notes"=(isNull(qLocks.lock_notes[i]) ? "" : trim(toString(qLocks.lock_notes[i]))),
                    "base_cycle_min"=(isNull(qLocks.base_cycle_min[i]) ? 0 : val(qLocks.base_cycle_min[i])),
                    "best_wait_min"=(isNull(qLocks.best_wait_min[i]) ? 0 : val(qLocks.best_wait_min[i])),
                    "typical_wait_min"=(isNull(qLocks.typical_wait_min[i]) ? 0 : val(qLocks.typical_wait_min[i])),
                    "worst_wait_min"=(isNull(qLocks.worst_wait_min[i]) ? 0 : val(qLocks.worst_wait_min[i])),
                    "delay_notes"=(isNull(qLocks.delay_notes[i]) ? "" : trim(toString(qLocks.delay_notes[i])))
                };
                arrayAppend(out.DATA.locks, lockRow);
                totalBaseCycleMin += val(lockRow.base_cycle_min);
                totalBestWaitMin += val(lockRow.best_wait_min);
                totalTypicalWaitMin += val(lockRow.typical_wait_min);
                totalWorstWaitMin += val(lockRow.worst_wait_min);
            }

            out.DATA.lock_count = arrayLen(out.DATA.locks);
            out.DATA.totals = {
                "base_cycle_min"=totalBaseCycleMin,
                "best_wait_min"=totalBestWaitMin,
                "typical_wait_min"=totalTypicalWaitMin,
                "worst_wait_min"=totalWorstWaitMin
            };
            if (!len(out.MESSAGE)) {
                out.MESSAGE = (out.DATA.lock_count GT 0 ? "OK" : "No locks mapped for this leg");
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenSaveLegOverride" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeCode" type="string" required="true">
        <cfargument name="routeLegId" type="numeric" required="true">
        <cfargument name="legOrder" type="numeric" required="false" default="0">
        <cfargument name="segmentId" type="numeric" required="false" default="0">
        <cfargument name="geometryRaw" type="any" required="true">
        <cfargument name="overrideFieldsRaw" type="any" required="false" default="">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unable to save leg override",
                "DATA"={}
            };
            var routeCodeVal = trim(arguments.routeCode);
            var routeInfo = {};
            var legRow = {};
            var normalized = {};
            var points = [];
            var nm = 0;
            var computedNm = 0;
            var geometryJson = "";
            var overrideFields = {};
            var overrideFieldsJson = "";
            var segmentIdVal = val(arguments.segmentId);
            var legOrderVal = val(arguments.legOrder);

            if (!len(routeCodeVal)) {
                out.MESSAGE = "Route code required";
                out.ERROR = { "MESSAGE"="route_code is required." };
                return out;
            }
            if (arguments.routeLegId LTE 0) {
                out.MESSAGE = "Route leg required";
                out.ERROR = { "MESSAGE"="route_leg_id is required." };
                return out;
            }
            if (!routegenHasLegOverrideTable()) {
                out.MESSAGE = "Override table missing";
                out.ERROR = { "MESSAGE"="Database migration for route_leg_user_overrides has not been applied." };
                return out;
            }

            routeInfo = routegenResolveUserRoute(arguments.userId, routeCodeVal);
            if (!structCount(routeInfo)) {
                out.MESSAGE = "Route not found";
                out.ERROR = { "MESSAGE"="Route not found or not owned by user." };
                return out;
            }
            legRow = routegenReadRouteLeg(routeInfo.ROUTE_ID, arguments.routeLegId, arguments.userId);
            if (!structCount(legRow)) {
                out.MESSAGE = "Leg not found";
                out.ERROR = { "MESSAGE"="Requested route leg was not found in this route." };
                return out;
            }

            if (legOrderVal LTE 0) {
                legOrderVal = routegenResolveRouteLegOrder(routeInfo.ROUTE_ID, arguments.routeLegId, arguments.userId);
            }
            if (legOrderVal LTE 0) {
                legOrderVal = val(legRow.ORDER_INDEX);
            }
            if (segmentIdVal LT 0) segmentIdVal = 0;

            normalized = routegenNormalizeOverridePoints(arguments.geometryRaw);
            if (!normalized.ok) {
                out.MESSAGE = "Validation failed";
                out.ERROR = { "MESSAGE"=normalized.message, "DETAIL"=normalized.detail };
                return out;
            }
            points = normalized.points;
            if (arrayLen(points) LT 2) {
                out.MESSAGE = "Validation failed";
                out.ERROR = { "MESSAGE"="At least two points are required." };
                return out;
            }

            nm = routegenCalculatePolylineNm(points);
            computedNm = roundTo2(nm);
            geometryJson = serializeJSON(points);

            if (isStruct(arguments.overrideFieldsRaw)) {
                overrideFields = duplicate(arguments.overrideFieldsRaw);
            }
            if (structCount(overrideFields)) {
                overrideFieldsJson = serializeJSON(overrideFields);
            }

            queryExecute(
                "INSERT INTO route_leg_user_overrides
                    (user_id, route_id, route_leg_id, route_leg_order, segment_id, geometry_json, computed_nm, override_fields_json)
                 VALUES
                    (:userId, :routeId, :routeLegId, :routeLegOrder, :segmentId, :geometryJson, :computedNm, :overrideFieldsJson)
                 ON DUPLICATE KEY UPDATE
                    route_id = VALUES(route_id),
                    route_leg_order = VALUES(route_leg_order),
                    segment_id = VALUES(segment_id),
                    geometry_json = VALUES(geometry_json),
                    computed_nm = VALUES(computed_nm),
                    override_fields_json = VALUES(override_fields_json),
                    updated_at = NOW()",
                {
                    userId = { value=arguments.userId, cfsqltype="cf_sql_integer" },
                    routeId = { value=routeInfo.ROUTE_ID, cfsqltype="cf_sql_integer" },
                    routeLegId = { value=arguments.routeLegId, cfsqltype="cf_sql_integer" },
                    routeLegOrder = { value=legOrderVal, cfsqltype="cf_sql_integer" },
                    segmentId = { value=segmentIdVal, cfsqltype="cf_sql_integer", null=(segmentIdVal LTE 0) },
                    geometryJson = { value=geometryJson, cfsqltype="cf_sql_longvarchar" },
                    computedNm = { value=computedNm, cfsqltype="cf_sql_decimal", scale=2 },
                    overrideFieldsJson = { value=overrideFieldsJson, cfsqltype="cf_sql_longvarchar", null=NOT len(overrideFieldsJson) }
                },
                { datasource = application.dsn }
            );

            out.SUCCESS = true;
            out.MESSAGE = "Leg override saved";
            out.DATA = {
                "route_id"=routeInfo.ROUTE_ID,
                "route_code"=routeInfo.ROUTE_CODE,
                "route_leg_id"=arguments.routeLegId,
                "leg_order"=legOrderVal,
                "segment_id"=segmentIdVal,
                "has_override"=true,
                "computed_nm"=computedNm,
                "default_nm"=roundTo2(val(legRow.DIST_NM))
            };
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenSaveSegmentOverride" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="segmentId" type="numeric" required="true">
        <cfargument name="geometryRaw" type="any" required="true">
        <cfargument name="overrideFieldsRaw" type="any" required="false" default="">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unable to save segment override",
                "DATA"={}
            };
            var segmentIdVal = abs(val(arguments.segmentId));
            var syntheticRouteLegId = 0;
            var normalized = {};
            var points = [];
            var geometryJson = "";
            var overrideFields = {};
            var overrideFieldsJson = "";
            var computedNm = 0;
            var defaultGeom = {};
            var defaultNm = 0;

            if (segmentIdVal LTE 0) {
                out.MESSAGE = "Segment required";
                out.ERROR = { "MESSAGE"="segment_id is required." };
                return out;
            }
            if (!routegenHasLegOverrideTable()) {
                out.MESSAGE = "Override table missing";
                out.ERROR = { "MESSAGE"="Database migration for route_leg_user_overrides has not been applied." };
                return out;
            }

            normalized = routegenNormalizeOverridePoints(arguments.geometryRaw);
            if (!normalized.ok) {
                out.MESSAGE = "Validation failed";
                out.ERROR = { "MESSAGE"=normalized.message, "DETAIL"=normalized.detail };
                return out;
            }
            points = normalized.points;
            if (arrayLen(points) LT 2) {
                out.MESSAGE = "Validation failed";
                out.ERROR = { "MESSAGE"="At least two points are required." };
                return out;
            }

            computedNm = roundTo2(routegenCalculatePolylineNm(points));
            geometryJson = serializeJSON(points);
            syntheticRouteLegId = 0 - segmentIdVal;

            if (isStruct(arguments.overrideFieldsRaw)) {
                overrideFields = duplicate(arguments.overrideFieldsRaw);
            }
            if (structCount(overrideFields)) {
                overrideFieldsJson = serializeJSON(overrideFields);
            }

            queryExecute(
                "INSERT INTO route_leg_user_overrides
                    (user_id, route_id, route_leg_id, route_leg_order, segment_id, geometry_json, computed_nm, override_fields_json)
                 VALUES
                    (:userId, 0, :routeLegId, 0, :segmentId, :geometryJson, :computedNm, :overrideFieldsJson)
                 ON DUPLICATE KEY UPDATE
                    route_id = 0,
                    route_leg_order = 0,
                    segment_id = VALUES(segment_id),
                    geometry_json = VALUES(geometry_json),
                    computed_nm = VALUES(computed_nm),
                    override_fields_json = VALUES(override_fields_json),
                    updated_at = NOW()",
                {
                    userId = { value=arguments.userId, cfsqltype="cf_sql_integer" },
                    routeLegId = { value=syntheticRouteLegId, cfsqltype="cf_sql_integer" },
                    segmentId = { value=segmentIdVal, cfsqltype="cf_sql_integer" },
                    geometryJson = { value=geometryJson, cfsqltype="cf_sql_longvarchar" },
                    computedNm = { value=computedNm, cfsqltype="cf_sql_decimal", scale=2 },
                    overrideFieldsJson = { value=overrideFieldsJson, cfsqltype="cf_sql_longvarchar", null=NOT len(overrideFieldsJson) }
                },
                { datasource = application.dsn }
            );

            defaultGeom = routegenLoadDefaultLegGeometry(segmentIdVal);
            defaultNm = roundTo2(val(defaultGeom.DIST_NM));

            out.SUCCESS = true;
            out.MESSAGE = "Segment override saved";
            out.DATA = {
                "route_id"=0,
                "route_code"="",
                "route_leg_id"=syntheticRouteLegId,
                "segment_id"=segmentIdVal,
                "has_override"=false,
                "has_segment_override"=true,
                "source"="user_segment",
                "computed_nm"=computedNm,
                "default_nm"=defaultNm
            };
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenClearSegmentOverride" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="segmentId" type="numeric" required="true">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unable to clear segment override",
                "DATA"={}
            };
            var segmentIdVal = abs(val(arguments.segmentId));
            var syntheticRouteLegId = 0;
            var defaultGeom = {};
            var defaultNm = 0;

            if (segmentIdVal LTE 0) {
                out.MESSAGE = "Segment required";
                out.ERROR = { "MESSAGE"="segment_id is required." };
                return out;
            }
            if (!routegenHasLegOverrideTable()) {
                out.MESSAGE = "Override table missing";
                out.ERROR = { "MESSAGE"="Database migration for route_leg_user_overrides has not been applied." };
                return out;
            }

            syntheticRouteLegId = 0 - segmentIdVal;
            queryExecute(
                "DELETE FROM route_leg_user_overrides
                 WHERE user_id = :uid
                   AND route_id = 0
                   AND route_leg_id = :legId
                   AND segment_id = :segmentId",
                {
                    uid = { value=arguments.userId, cfsqltype="cf_sql_integer" },
                    legId = { value=syntheticRouteLegId, cfsqltype="cf_sql_integer" },
                    segmentId = { value=segmentIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );

            defaultGeom = routegenLoadDefaultLegGeometry(segmentIdVal);
            defaultNm = roundTo2(val(defaultGeom.DIST_NM));

            out.SUCCESS = true;
            out.MESSAGE = "Segment override cleared";
            out.DATA = {
                "route_id"=0,
                "route_code"="",
                "route_leg_id"=syntheticRouteLegId,
                "segment_id"=segmentIdVal,
                "has_override"=false,
                "has_segment_override"=false,
                "source"="default",
                "computed_nm"=defaultNm,
                "default_nm"=defaultNm
            };
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenClearLegOverride" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeCode" type="string" required="true">
        <cfargument name="routeLegId" type="numeric" required="true">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unable to clear leg override",
                "DATA"={}
            };
            var routeCodeVal = trim(arguments.routeCode);
            var routeInfo = {};
            var legRow = {};
            var legOrderVal = 0;

            if (!len(routeCodeVal)) {
                out.MESSAGE = "Route code required";
                out.ERROR = { "MESSAGE"="route_code is required." };
                return out;
            }
            if (arguments.routeLegId LTE 0) {
                out.MESSAGE = "Route leg required";
                out.ERROR = { "MESSAGE"="route_leg_id is required." };
                return out;
            }
            routeInfo = routegenResolveUserRoute(arguments.userId, routeCodeVal);
            if (!structCount(routeInfo)) {
                out.MESSAGE = "Route not found";
                out.ERROR = { "MESSAGE"="Route not found or not owned by user." };
                return out;
            }
            legRow = routegenReadRouteLeg(routeInfo.ROUTE_ID, arguments.routeLegId, arguments.userId);
            if (!structCount(legRow)) {
                out.MESSAGE = "Leg not found";
                out.ERROR = { "MESSAGE"="Requested route leg was not found in this route." };
                return out;
            }

            if (routegenHasLegOverrideTable()) {
                queryExecute(
                    "DELETE FROM route_leg_user_overrides
                     WHERE user_id = :uid
                       AND route_id = :rid
                       AND route_leg_id = :legId",
                    {
                        uid = { value=arguments.userId, cfsqltype="cf_sql_integer" },
                        rid = { value=routeInfo.ROUTE_ID, cfsqltype="cf_sql_integer" },
                        legId = { value=arguments.routeLegId, cfsqltype="cf_sql_integer" }
                    },
                    { datasource = application.dsn }
                );
            }

            legOrderVal = routegenResolveRouteLegOrder(routeInfo.ROUTE_ID, arguments.routeLegId, arguments.userId);

            out.SUCCESS = true;
            out.MESSAGE = "Leg override cleared";
            out.DATA = {
                "route_id"=routeInfo.ROUTE_ID,
                "route_code"=routeInfo.ROUTE_CODE,
                "route_leg_id"=arguments.routeLegId,
                "leg_order"=legOrderVal,
                "has_override"=false,
                "default_nm"=roundTo2(val(legRow.DIST_NM)),
                "computed_nm"=roundTo2(val(legRow.DIST_NM))
            };
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenListLegOverrides" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeCode" type="string" required="true">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unable to load leg overrides",
                "DATA"={ "overrides"=[] }
            };
            var routeCodeVal = trim(arguments.routeCode);
            var routeInfo = {};
            var q = queryNew("");
            var i = 0;

            if (!len(routeCodeVal)) {
                out.MESSAGE = "Route code required";
                out.ERROR = { "MESSAGE"="route_code is required." };
                return out;
            }
            routeInfo = routegenResolveUserRoute(arguments.userId, routeCodeVal);
            if (!structCount(routeInfo)) {
                out.MESSAGE = "Route not found";
                out.ERROR = { "MESSAGE"="Route not found or not owned by user." };
                return out;
            }

            if (routegenHasLegOverrideTable()) {
                q = queryExecute(
                    "SELECT route_leg_id, route_leg_order, segment_id, computed_nm
                     FROM route_leg_user_overrides
                     WHERE user_id = :uid
                       AND route_id = :rid
                     ORDER BY route_leg_order ASC, route_leg_id ASC",
                    {
                        uid = { value=arguments.userId, cfsqltype="cf_sql_integer" },
                        rid = { value=routeInfo.ROUTE_ID, cfsqltype="cf_sql_integer" }
                    },
                    { datasource = application.dsn }
                );
                for (i = 1; i LTE q.recordCount; i++) {
                    arrayAppend(out.DATA.overrides, {
                        "route_leg_id"=val(q.route_leg_id[i]),
                        "leg_order"=(isNull(q.route_leg_order[i]) ? 0 : val(q.route_leg_order[i])),
                        "segment_id"=(isNull(q.segment_id[i]) ? 0 : val(q.segment_id[i])),
                        "computed_nm"=(isNull(q.computed_nm[i]) ? 0 : roundTo2(val(q.computed_nm[i])))
                    });
                }
            }

            out.SUCCESS = true;
            out.MESSAGE = "OK";
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenRemapLegOverrideIds" access="private" returntype="void" output="false">
        <cfargument name="routeId" type="numeric" required="true">
        <cfargument name="oldLegMapByOrder" type="struct" required="true">
        <cfargument name="newLegIdByOrder" type="struct" required="true">
        <cfargument name="legs" type="array" required="true">
        <cfscript>
            var orderKey = "";
            var orderNum = 0;
            var oldLegId = 0;
            var newLegId = 0;
            var segmentId = 0;
            if (!routegenHasLegOverrideTable()) return;
            if (arguments.routeId LTE 0) return;

            for (orderKey in arguments.newLegIdByOrder) {
                orderNum = val(orderKey);
                newLegId = val(arguments.newLegIdByOrder[orderKey]);
                if (orderNum LTE 0 OR newLegId LTE 0) continue;

                oldLegId = 0;
                if (
                    structKeyExists(arguments.oldLegMapByOrder, orderKey)
                    AND isStruct(arguments.oldLegMapByOrder[orderKey])
                    AND structKeyExists(arguments.oldLegMapByOrder[orderKey], "ROUTE_LEG_ID")
                ) {
                    oldLegId = val(arguments.oldLegMapByOrder[orderKey].ROUTE_LEG_ID);
                }

                segmentId = 0;
                if (
                    orderNum LTE arrayLen(arguments.legs)
                    AND isStruct(arguments.legs[orderNum])
                    AND structKeyExists(arguments.legs[orderNum], "segment_id")
                ) {
                    segmentId = val(arguments.legs[orderNum].segment_id);
                }

                if (oldLegId GT 0 AND oldLegId NEQ newLegId) {
                    queryExecute(
                        "UPDATE route_leg_user_overrides
                         SET route_leg_id = :newLegId,
                             route_leg_order = :legOrder,
                             segment_id = :segmentId,
                             updated_at = NOW()
                         WHERE route_id = :routeId
                           AND route_leg_id = :oldLegId",
                        {
                            newLegId = { value=newLegId, cfsqltype="cf_sql_integer" },
                            legOrder = { value=orderNum, cfsqltype="cf_sql_integer" },
                            segmentId = { value=segmentId, cfsqltype="cf_sql_integer", null=(segmentId LTE 0) },
                            routeId = { value=arguments.routeId, cfsqltype="cf_sql_integer" },
                            oldLegId = { value=oldLegId, cfsqltype="cf_sql_integer" }
                        },
                        { datasource = application.dsn }
                    );
                } else if (oldLegId EQ newLegId AND oldLegId GT 0) {
                    queryExecute(
                        "UPDATE route_leg_user_overrides
                         SET route_leg_order = :legOrder,
                             segment_id = :segmentId,
                             updated_at = NOW()
                         WHERE route_id = :routeId
                           AND route_leg_id = :legId",
                        {
                            legOrder = { value=orderNum, cfsqltype="cf_sql_integer" },
                            segmentId = { value=segmentId, cfsqltype="cf_sql_integer", null=(segmentId LTE 0) },
                            routeId = { value=arguments.routeId, cfsqltype="cf_sql_integer" },
                            legId = { value=oldLegId, cfsqltype="cf_sql_integer" }
                        },
                        { datasource = application.dsn }
                    );
                }
            }
        </cfscript>
    </cffunction>

    <cffunction name="routegenToRadians" access="private" returntype="numeric" output="false">
        <cfargument name="deg" type="numeric" required="true">
        <cfreturn arguments.deg * (pi() / 180)>
    </cffunction>

    <cffunction name="routegenAtn2Compat" access="private" returntype="numeric" output="false">
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

    <cffunction name="routegenHaversineMeters" access="private" returntype="numeric" output="false">
        <cfargument name="lat1" type="numeric" required="true">
        <cfargument name="lon1" type="numeric" required="true">
        <cfargument name="lat2" type="numeric" required="true">
        <cfargument name="lon2" type="numeric" required="true">
        <cfscript>
            var earthRadiusMeters = 6371008.8;
            var dLat = routegenToRadians(arguments.lat2 - arguments.lat1);
            var dLon = routegenToRadians(arguments.lon2 - arguments.lon1);
            var phi1 = routegenToRadians(arguments.lat1);
            var phi2 = routegenToRadians(arguments.lat2);
            var a = (sin(dLat / 2) ^ 2) + cos(phi1) * cos(phi2) * (sin(dLon / 2) ^ 2);
            if (a LT 0) a = 0;
            if (a GT 1) a = 1;
            var c = 2 * routegenAtn2Compat(sqr(a), sqr(1 - a));
            return earthRadiusMeters * c;
        </cfscript>
    </cffunction>

    <cffunction name="routegenCalculatePolylineNm" access="private" returntype="numeric" output="false">
        <cfargument name="points" type="array" required="true">
        <cfscript>
            var totalMeters = 0.0;
            var i = 0;
            if (arrayLen(arguments.points) LT 2) {
                return 0;
            }
            for (i = 2; i LTE arrayLen(arguments.points); i++) {
                totalMeters += routegenHaversineMeters(
                    arguments.points[i - 1].lat,
                    arguments.points[i - 1].lon,
                    arguments.points[i].lat,
                    arguments.points[i].lon
                );
            }
            return totalMeters / 1852;
        </cfscript>
    </cffunction>

    <cffunction name="allocateUserRouteCode" access="private" returntype="string" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="maxAttempts" type="numeric" required="false" default="100">
        <cfscript>
            var tryNum = 0;
            var stamp = "";
            var token = "";
            var candidate = "";
            var q = queryNew("");
            var maxTry = max(1, int(arguments.maxAttempts));
            for (tryNum = 1; tryNum LTE maxTry; tryNum++) {
                stamp = dateTimeFormat(now(), "yyyymmddHHnnss");
                token = lCase(left(replace(createUUID(), "-", "", "all"), 8));
                candidate = "USER_ROUTE_" & int(arguments.userId) & "_" & stamp & "_" & token;
                q = queryExecute(
                    "SELECT id
                     FROM loop_routes
                     WHERE short_code = :code
                     LIMIT 1",
                    {
                        code = { value=candidate, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource = application.dsn }
                );
                if (q.recordCount EQ 0) {
                    return candidate;
                }
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="routegenAllocateUserRouteCode" access="private" returntype="string" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfscript>
            return allocateUserRouteCode(arguments.userId);
        </cfscript>
    </cffunction>

    <cffunction name="routegenGenerate" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="input" type="struct" required="true">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unable to generate route",
                "DATA"={}
            };

            var preview = routegenBuildPreview(
                userId = arguments.userId,
                input = arguments.input
            );
            if (!preview.SUCCESS) {
                return preview;
            }

            var data = preview.DATA;
            var legs = (structKeyExists(data, "legs") AND isArray(data.legs) ? data.legs : []);
            if (!arrayLen(legs)) {
                out.MESSAGE = "Preview returned no legs";
                out.ERROR = { "MESSAGE"="No route legs available for generation." };
                return out;
            }
            if (!routegenHasNormalizedTables()) {
                out.MESSAGE = "Normalized route tables are unavailable";
                out.ERROR = { "MESSAGE"="route_instance_* tables are required for route generation." };
                return out;
            }

            var routeCode = routegenAllocateUserRouteCode(arguments.userId);
            if (!len(routeCode)) {
                out.MESSAGE = "Unable to allocate route code";
                out.ERROR = { "MESSAGE"="Could not allocate a unique USER_ROUTE code." };
                return out;
            }

            var templateCodeVal = trim(toString(data.template.code));
            var templateNameVal = trim(toString(data.template.name));
            var routeNameVal = trim(toString(arguments.input.route_name));
            if (!len(routeNameVal)) {
                routeNameVal = (len(templateNameVal) ? templateNameVal & " Route" : "My Route");
            }
            var directionVal = normalizeDirection(arguments.input.direction);
            var startLocationVal = trim(toString(legs[1].start_name));
            var endLocationVal = trim(toString(legs[arrayLen(legs)].end_name));
            var templateIsLoop = (
                structKeyExists(data, "template")
                AND isStruct(data.template)
                AND (
                    (structKeyExists(data.template, "is_loop") AND data.template.is_loop)
                    OR (structKeyExists(data.template, "IS_LOOP") AND data.template.IS_LOOP)
                )
            );
            var tripTypeVal = ((templateIsLoop AND arguments.input.start_segment_id EQ arguments.input.end_segment_id) ? "FULL_LOOP" : "POINT_TO_POINT");
            var routeDesc = "Generated from template " & templateCodeVal & " (" & directionVal & ") on " & dateFormat(now(), "yyyy-mm-dd");
            var instanceInputs = (structKeyExists(data, "inputs") AND isStruct(data.inputs) ? duplicate(data.inputs) : {});
            if (!len(trim(toString(structKeyExists(instanceInputs, "start_date") ? instanceInputs.start_date : "")))) {
                instanceInputs.start_date = trim(toString(arguments.input.start_date));
            }
            var instanceInputsJson = routegenSerializeInputsForInstance(instanceInputs);
            var hasInputsJsonCol = routegenHasInputsJsonColumn();
            var newRouteId = 0;
            var routeInstanceId = 0;
            var rebuildRes = {};

            transaction {
                queryExecute(
                    "INSERT INTO loop_routes
                        (code, name, short_code, description, is_active, version, is_default)
                     VALUES
                        (:code, :name, :shortCode, :descr, 1, 1, 0)",
                    {
                        code = { value=routeCode, cfsqltype="cf_sql_varchar" },
                        name = { value=routeNameVal, cfsqltype="cf_sql_varchar" },
                        shortCode = { value=routeCode, cfsqltype="cf_sql_varchar" },
                        descr = { value=routeDesc, cfsqltype="cf_sql_varchar", null=NOT len(routeDesc) }
                    },
                    { datasource = application.dsn, result = "routegenRouteIns" }
                );
                newRouteId = val(routegenRouteIns.generatedKey);

                if (hasInputsJsonCol) {
                    queryExecute(
                        "INSERT INTO route_instances
                            (user_id, template_route_code, generated_route_id, generated_route_code, direction, trip_type, start_location, end_location, routegen_inputs_json, status)
                         VALUES
                            (:userId, :templateCode, :generatedRouteId, :generatedRouteCode, :direction, :tripType, :startLocation, :endLocation, :routegenInputsJson, 'PLANNED')",
                        {
                            userId = { value=toString(arguments.userId), cfsqltype="cf_sql_varchar" },
                            templateCode = { value=templateCodeVal, cfsqltype="cf_sql_varchar" },
                            generatedRouteId = { value=newRouteId, cfsqltype="cf_sql_integer" },
                            generatedRouteCode = { value=routeCode, cfsqltype="cf_sql_varchar" },
                            direction = { value=directionVal, cfsqltype="cf_sql_varchar" },
                            tripType = { value=tripTypeVal, cfsqltype="cf_sql_varchar" },
                            startLocation = { value=startLocationVal, cfsqltype="cf_sql_varchar", null=NOT len(startLocationVal) },
                            endLocation = { value=endLocationVal, cfsqltype="cf_sql_varchar", null=NOT len(endLocationVal) },
                            routegenInputsJson = { value=instanceInputsJson, cfsqltype="cf_sql_longvarchar", null=NOT len(instanceInputsJson) }
                        },
                        { datasource = application.dsn, result = "routegenInstIns" }
                    );
                } else {
                    queryExecute(
                        "INSERT INTO route_instances
                            (user_id, template_route_code, generated_route_id, generated_route_code, direction, trip_type, start_location, end_location, status)
                         VALUES
                            (:userId, :templateCode, :generatedRouteId, :generatedRouteCode, :direction, :tripType, :startLocation, :endLocation, 'PLANNED')",
                        {
                            userId = { value=toString(arguments.userId), cfsqltype="cf_sql_varchar" },
                            templateCode = { value=templateCodeVal, cfsqltype="cf_sql_varchar" },
                            generatedRouteId = { value=newRouteId, cfsqltype="cf_sql_integer" },
                            generatedRouteCode = { value=routeCode, cfsqltype="cf_sql_varchar" },
                            direction = { value=directionVal, cfsqltype="cf_sql_varchar" },
                            tripType = { value=tripTypeVal, cfsqltype="cf_sql_varchar" },
                            startLocation = { value=startLocationVal, cfsqltype="cf_sql_varchar", null=NOT len(startLocationVal) },
                            endLocation = { value=endLocationVal, cfsqltype="cf_sql_varchar", null=NOT len(endLocationVal) }
                        },
                        { datasource = application.dsn, result = "routegenInstIns" }
                    );
                }
                routeInstanceId = val(routegenInstIns.generatedKey);
                rebuildRes = routegenRebuildNormalizedInstanceLegs(
                    userId = arguments.userId,
                    routeInstanceId = routeInstanceId,
                    legs = legs
                );
            }

            session.expeditionRouteCode = routeCode;

            out.SUCCESS = true;
            out.MESSAGE = "Route generated";
            out.DATA = {
                "route_id"=newRouteId,
                "route_code"=routeCode,
                "route_name"=routeNameVal,
                "route_instance_id"=routeInstanceId,
                "generated_leg_count"=arrayLen(legs),
                "totals"=data.totals,
                "template"=data.template
            };
            out.ROUTE_ID = newRouteId;
            out.ROUTE_CODE = routeCode;
            out.ROUTE_INSTANCE_ID = routeInstanceId;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="routegenUpdate" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeCode" type="string" required="true">
        <cfargument name="input" type="struct" required="true">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unable to update route",
                "DATA"={}
            };

            var routeInfo = routegenResolveUserRoute(arguments.userId, arguments.routeCode);
            if (!structCount(routeInfo)) {
                out.MESSAGE = "Route not found";
                out.ERROR = { "MESSAGE"="Route not found or not owned by user." };
                return out;
            }

            if (
                !len(trim(toString(arguments.input.template_code)))
                OR !len(trim(toString(arguments.input.start_segment_id)))
                OR !len(trim(toString(arguments.input.end_segment_id)))
                OR !len(trim(toString(arguments.input.start_date)))
            ) {
                out.MESSAGE = "Missing required fields";
                out.ERROR = { "MESSAGE"="template_code, start_segment_id, end_segment_id, and start_date are required." };
                return out;
            }

            if (!len(trim(toString(arguments.input.route_code)))) {
                arguments.input.route_code = trim(arguments.routeCode);
            }
            var preview = routegenBuildPreview(
                userId = arguments.userId,
                input = arguments.input
            );
            if (!preview.SUCCESS) {
                return preview;
            }

            var data = preview.DATA;
            var legs = (structKeyExists(data, "legs") AND isArray(data.legs) ? data.legs : []);
            if (!arrayLen(legs)) {
                out.MESSAGE = "Preview returned no legs";
                out.ERROR = { "MESSAGE"="No route legs available for update." };
                return out;
            }
            if (!routegenHasNormalizedTables()) {
                out.MESSAGE = "Normalized route tables are unavailable";
                out.ERROR = { "MESSAGE"="route_instance_* tables are required for route updates." };
                return out;
            }

            var routeId = val(routeInfo.ROUTE_ID);
            var routeCodeVal = trim(routeInfo.ROUTE_CODE);
            var templateCodeVal = trim(toString(data.template.code));
            var templateNameVal = trim(toString(data.template.name));
            var routeNameVal = trim(toString(arguments.input.route_name));
            if (!len(routeNameVal)) {
                routeNameVal = trim(routeInfo.ROUTE_NAME);
            }
            if (!len(routeNameVal)) {
                routeNameVal = (len(templateNameVal) ? templateNameVal & " Route" : "My Route");
            }

            var directionVal = normalizeDirection(arguments.input.direction);
            var startLocationVal = trim(toString(legs[1].start_name));
            var endLocationVal = trim(toString(legs[arrayLen(legs)].end_name));
            var templateIsLoop = (
                structKeyExists(data, "template")
                AND isStruct(data.template)
                AND (
                    (structKeyExists(data.template, "is_loop") AND data.template.is_loop)
                    OR (structKeyExists(data.template, "IS_LOOP") AND data.template.IS_LOOP)
                )
            );
            var tripTypeVal = ((templateIsLoop AND arguments.input.start_segment_id EQ arguments.input.end_segment_id) ? "FULL_LOOP" : "POINT_TO_POINT");
            var routeDesc = "Updated from template " & templateCodeVal & " (" & directionVal & ") on " & dateFormat(now(), "yyyy-mm-dd");
            var instanceInputs = (structKeyExists(data, "inputs") AND isStruct(data.inputs) ? duplicate(data.inputs) : {});
            if (!len(trim(toString(structKeyExists(instanceInputs, "start_date") ? instanceInputs.start_date : "")))) {
                instanceInputs.start_date = trim(toString(arguments.input.start_date));
            }
            var instanceInputsJson = routegenSerializeInputsForInstance(instanceInputs);
            var hasInputsJsonCol = routegenHasInputsJsonColumn();
            var totals = (structKeyExists(data, "totals") ? data.totals : {});
            var totalNmBind = toNullableNumber((structKeyExists(totals, "total_nm") ? totals.total_nm : ""), "numeric");
            var totalLocksBind = toNullableNumber((structKeyExists(totals, "lock_count") ? totals.lock_count : ""), "integer");
            var oldLegMapByOrder = routegenLoadRouteLegMap(routeId, arguments.userId);
            var newLegIdByOrder = {};

            var rebuildRes = {};
            var routeInstanceId = 0;
            var qInst = queryNew("");

            transaction {
                queryExecute(
                    "UPDATE loop_routes
                     SET name = :name,
                         description = :descr,
                         total_nm = :totalNm,
                         total_locks = :totalLocks,
                         updated_at = NOW()
                     WHERE id = :rid",
                    {
                        name = { value=routeNameVal, cfsqltype="cf_sql_varchar" },
                        descr = { value=routeDesc, cfsqltype="cf_sql_varchar", null=NOT len(routeDesc) },
                        totalNm = { value=totalNmBind.value, cfsqltype="cf_sql_decimal", null=totalNmBind.isNull },
                        totalLocks = { value=totalLocksBind.value, cfsqltype="cf_sql_integer", null=totalLocksBind.isNull },
                        rid = { value=routeId, cfsqltype="cf_sql_integer" }
                    },
                    { datasource = application.dsn }
                );

                qInst = queryExecute(
                    "SELECT id
                     FROM route_instances
                     WHERE generated_route_id = :rid
                       AND user_id = :uid
                     ORDER BY id DESC
                     LIMIT 1",
                    {
                        rid = { value=routeId, cfsqltype="cf_sql_integer" },
                        uid = { value=toString(arguments.userId), cfsqltype="cf_sql_varchar" }
                    },
                    { datasource = application.dsn }
                );

                if (qInst.recordCount GT 0) {
                    routeInstanceId = val(qInst.id[1]);
                    if (hasInputsJsonCol) {
                        queryExecute(
                            "UPDATE route_instances
                             SET template_route_code = :templateCode,
                                 generated_route_code = :generatedRouteCode,
                                 direction = :direction,
                                 trip_type = :tripType,
                                 start_location = :startLocation,
                                 end_location = :endLocation,
                                 routegen_inputs_json = :routegenInputsJson,
                                 status = 'PLANNED',
                                 updated_at = NOW()
                             WHERE id = :id",
                            {
                                templateCode = { value=templateCodeVal, cfsqltype="cf_sql_varchar" },
                                generatedRouteCode = { value=routeCodeVal, cfsqltype="cf_sql_varchar" },
                                direction = { value=directionVal, cfsqltype="cf_sql_varchar" },
                                tripType = { value=tripTypeVal, cfsqltype="cf_sql_varchar" },
                                startLocation = { value=startLocationVal, cfsqltype="cf_sql_varchar", null=NOT len(startLocationVal) },
                                endLocation = { value=endLocationVal, cfsqltype="cf_sql_varchar", null=NOT len(endLocationVal) },
                                routegenInputsJson = { value=instanceInputsJson, cfsqltype="cf_sql_longvarchar", null=NOT len(instanceInputsJson) },
                                id = { value=routeInstanceId, cfsqltype="cf_sql_integer" }
                            },
                            { datasource = application.dsn }
                        );
                    } else {
                        queryExecute(
                            "UPDATE route_instances
                             SET template_route_code = :templateCode,
                                 generated_route_code = :generatedRouteCode,
                                 direction = :direction,
                                 trip_type = :tripType,
                                 start_location = :startLocation,
                                 end_location = :endLocation,
                                 status = 'PLANNED',
                                 updated_at = NOW()
                             WHERE id = :id",
                            {
                                templateCode = { value=templateCodeVal, cfsqltype="cf_sql_varchar" },
                                generatedRouteCode = { value=routeCodeVal, cfsqltype="cf_sql_varchar" },
                                direction = { value=directionVal, cfsqltype="cf_sql_varchar" },
                                tripType = { value=tripTypeVal, cfsqltype="cf_sql_varchar" },
                                startLocation = { value=startLocationVal, cfsqltype="cf_sql_varchar", null=NOT len(startLocationVal) },
                                endLocation = { value=endLocationVal, cfsqltype="cf_sql_varchar", null=NOT len(endLocationVal) },
                                id = { value=routeInstanceId, cfsqltype="cf_sql_integer" }
                            },
                            { datasource = application.dsn }
                        );
                    }
                } else {
                    if (hasInputsJsonCol) {
                        queryExecute(
                            "INSERT INTO route_instances
                                (user_id, template_route_code, generated_route_id, generated_route_code, direction, trip_type, start_location, end_location, routegen_inputs_json, status)
                             VALUES
                                (:userId, :templateCode, :generatedRouteId, :generatedRouteCode, :direction, :tripType, :startLocation, :endLocation, :routegenInputsJson, 'PLANNED')",
                            {
                                userId = { value=toString(arguments.userId), cfsqltype="cf_sql_varchar" },
                                templateCode = { value=templateCodeVal, cfsqltype="cf_sql_varchar" },
                                generatedRouteId = { value=routeId, cfsqltype="cf_sql_integer" },
                                generatedRouteCode = { value=routeCodeVal, cfsqltype="cf_sql_varchar" },
                                direction = { value=directionVal, cfsqltype="cf_sql_varchar" },
                                tripType = { value=tripTypeVal, cfsqltype="cf_sql_varchar" },
                                startLocation = { value=startLocationVal, cfsqltype="cf_sql_varchar", null=NOT len(startLocationVal) },
                                endLocation = { value=endLocationVal, cfsqltype="cf_sql_varchar", null=NOT len(endLocationVal) },
                                routegenInputsJson = { value=instanceInputsJson, cfsqltype="cf_sql_longvarchar", null=NOT len(instanceInputsJson) }
                            },
                            { datasource = application.dsn, result = "routegenUpdInstIns" }
                        );
                    } else {
                        queryExecute(
                            "INSERT INTO route_instances
                                (user_id, template_route_code, generated_route_id, generated_route_code, direction, trip_type, start_location, end_location, status)
                             VALUES
                                (:userId, :templateCode, :generatedRouteId, :generatedRouteCode, :direction, :tripType, :startLocation, :endLocation, 'PLANNED')",
                            {
                                userId = { value=toString(arguments.userId), cfsqltype="cf_sql_varchar" },
                                templateCode = { value=templateCodeVal, cfsqltype="cf_sql_varchar" },
                                generatedRouteId = { value=routeId, cfsqltype="cf_sql_integer" },
                                generatedRouteCode = { value=routeCodeVal, cfsqltype="cf_sql_varchar" },
                                direction = { value=directionVal, cfsqltype="cf_sql_varchar" },
                                tripType = { value=tripTypeVal, cfsqltype="cf_sql_varchar" },
                                startLocation = { value=startLocationVal, cfsqltype="cf_sql_varchar", null=NOT len(startLocationVal) },
                                endLocation = { value=endLocationVal, cfsqltype="cf_sql_varchar", null=NOT len(endLocationVal) }
                            },
                            { datasource = application.dsn, result = "routegenUpdInstIns" }
                        );
                    }
                    routeInstanceId = val(routegenUpdInstIns.generatedKey);
                }
                rebuildRes = routegenRebuildNormalizedInstanceLegs(
                    userId = arguments.userId,
                    routeInstanceId = routeInstanceId,
                    legs = legs
                );
                newLegIdByOrder = (structKeyExists(rebuildRes, "LEG_ID_BY_ORDER") AND isStruct(rebuildRes.LEG_ID_BY_ORDER) ? rebuildRes.LEG_ID_BY_ORDER : {});
                routegenRemapLegOverrideIds(routeId, oldLegMapByOrder, newLegIdByOrder, legs);
            }

            session.expeditionRouteCode = routeCodeVal;

            out.SUCCESS = true;
            out.MESSAGE = "Route updated";
            out.DATA = {
                "route_id"=routeId,
                "route_code"=routeCodeVal,
                "route_name"=routeNameVal,
                "route_instance_id"=routeInstanceId,
                "generated_leg_count"=arrayLen(legs),
                "totals"=data.totals,
                "template"=data.template
            };
            out.ROUTE_ID = routeId;
            out.ROUTE_CODE = routeCodeVal;
            out.ROUTE_INSTANCE_ID = routeInstanceId;
            return out;
        </cfscript>
    </cffunction>


    <cffunction name="normalizeDirection" access="private" returntype="string" output="false">
        <cfargument name="direction" type="any" required="false" default="CCW">
        <cfscript>
            var d = uCase(trim(toString(arguments.direction)));
            if (d EQ "CW") return "CW";
            return "CCW";
        </cfscript>
    </cffunction>

    <cffunction name="normalizeTripType" access="private" returntype="string" output="false">
        <cfargument name="tripType" type="any" required="false" default="POINT_TO_POINT">
        <cfscript>
            var t = uCase(trim(toString(arguments.tripType)));
            if (t EQ "FULL_LOOP") return "FULL_LOOP";
            return "POINT_TO_POINT";
        </cfscript>
    </cffunction>

    <cffunction name="normalizeBuildMode" access="private" returntype="string" output="false">
        <cfargument name="mode" type="any" required="false" default="DAILY">
        <cfscript>
            var m = uCase(trim(toString(arguments.mode)));
            if (m EQ "SINGLE_MASTER") return "SINGLE_MASTER";
            return "DAILY";
        </cfscript>
    </cffunction>

    <cffunction name="toBoolean" access="private" returntype="boolean" output="false">
        <cfargument name="value" type="any" required="true">
        <cfargument name="fallback" type="boolean" required="false" default="false">
        <cfscript>
            var raw = trim(lCase(toString(arguments.value)));
            if (isBoolean(arguments.value)) return (arguments.value ? true : false);
            if (isNumeric(arguments.value)) return (val(arguments.value) NEQ 0);
            if (listFindNoCase("true,yes,y,on", raw)) return true;
            if (listFindNoCase("false,no,n,off", raw)) return false;
            if (raw EQ "1") return true;
            if (raw EQ "0") return false;
            return arguments.fallback;
        </cfscript>
    </cffunction>

    <cffunction name="getBodyJson" access="private" returntype="struct" output="false">
        <cfset var httpData = getHttpRequestData() />
        <cfset var rawBody = toString(httpData.content) />
        <cfset var body = {} />
        <cfif len(trim(rawBody))>
            <cftry>
                <cfset body = deserializeJSON(rawBody, false) />
                <cfcatch>
                    <cfset body = {} />
                </cfcatch>
            </cftry>
        </cfif>
        <cfreturn body />
    </cffunction>

    <cffunction name="pickArg" access="private" returntype="any" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfargument name="fieldA" type="string" required="true">
        <cfargument name="fieldB" type="string" required="true">
        <cfargument name="fallback" type="any" required="false" default="">
        <cfif structKeyExists(arguments.body, arguments.fieldA)>
            <cfreturn arguments.body[arguments.fieldA] />
        </cfif>
        <cfif structKeyExists(url, arguments.fieldA)>
            <cfreturn url[arguments.fieldA] />
        </cfif>
        <cfif structKeyExists(arguments.body, arguments.fieldB)>
            <cfreturn arguments.body[arguments.fieldB] />
        </cfif>
        <cfif structKeyExists(url, arguments.fieldB)>
            <cfreturn url[arguments.fieldB] />
        </cfif>
        <cfreturn arguments.fallback />
    </cffunction>

    <cffunction name="pickStruct" access="private" returntype="any" output="false">
        <cfargument name="s" type="struct" required="true">
        <cfargument name="k" type="string" required="true">
        <cfargument name="fallback" type="any" required="false" default="">
        <cfif structKeyExists(arguments.s, arguments.k)>
            <cfreturn arguments.s[arguments.k] />
        </cfif>
        <cfreturn arguments.fallback />
    </cffunction>

    <cffunction name="toNullableString" access="private" returntype="struct" output="false">
        <cfargument name="v" type="any" required="true">
        <cfset var s = trim(toString(arguments.v)) />
        <cfif len(s)>
            <cfreturn { "isNull"=false, "value"=s } />
        </cfif>
        <cfreturn { "isNull"=true, "value"="" } />
    </cffunction>

    <cffunction name="toNullableNumber" access="private" returntype="struct" output="false">
        <cfargument name="v" type="any" required="true">
        <cfargument name="kind" type="string" required="false" default="numeric">
        <cfset var s = trim(toString(arguments.v)) />
        <cfset var n = 0 />
        <cfif len(s) AND isNumeric(s)>
            <cfset n = val(s) />
            <cfif arguments.kind EQ "integer">
                <cfset n = int(n) />
            </cfif>
            <cfreturn { "isNull"=false, "value"=n } />
        </cfif>
        <cfreturn { "isNull"=true, "value"=0 } />
    </cffunction>

    <cffunction name="isNullableZero" access="private" returntype="boolean" output="false">
        <cfargument name="n" type="struct" required="true">
        <cfif NOT structKeyExists(arguments.n, "isNull") OR NOT structKeyExists(arguments.n, "value")>
            <cfreturn false />
        </cfif>
        <cfreturn (NOT arguments.n.isNull AND isNumeric(arguments.n.value) AND val(arguments.n.value) EQ 0) />
    </cffunction>

    <cffunction name="resolveUserId" access="private" returntype="numeric" output="false">
        <cfargument name="userStruct" type="any" required="true">
        <cfset var uid = 0 />
        <cfif isStruct(arguments.userStruct)>
            <cfif structKeyExists(arguments.userStruct, "userId")>
                <cfset uid = val(arguments.userStruct.userId) />
            <cfelseif structKeyExists(arguments.userStruct, "USERID")>
                <cfset uid = val(arguments.userStruct.USERID) />
            <cfelseif structKeyExists(arguments.userStruct, "id")>
                <cfset uid = val(arguments.userStruct.id) />
            <cfelseif structKeyExists(arguments.userStruct, "ID")>
                <cfset uid = val(arguments.userStruct.ID) />
            </cfif>
        </cfif>
        <cfreturn uid />
    </cffunction>

    <cffunction name="getMilepointService" access="private" returntype="any" output="false">
        <cfscript>
            var svc = "";
            try {
                svc = createObject("component", "fpw.api.v1.MilepointService");
            } catch (any e1) {
                try {
                    svc = createObject("component", "api.v1.MilepointService");
                } catch (any e2) {
                    svc = "";
                }
            }
            return svc;
        </cfscript>
    </cffunction>

    <cffunction name="roundTo2" access="private" returntype="numeric" output="false">
        <cfargument name="n" type="numeric" required="true">
        <cfreturn (round(arguments.n * 100) / 100) />
    </cffunction>

</cfcomponent>
