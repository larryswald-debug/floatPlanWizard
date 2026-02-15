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
                <cfset var startDate = pickArg(body, "startDate", "startDate", "") />
                <cfset var startLocation = pickArg(body, "startLocation", "startLocation", "") />
                <cfset var endLocation = pickArg(body, "endLocation", "endLocation", "") />
                <cfset var directionArg = pickArg(body, "direction", "direction", "CCW") />
                <cfset var tripType = pickArg(body, "tripType", "tripType", "POINT_TO_POINT") />
                <cfset var generated = generateRoute(userId, startDate, startLocation, endLocation, directionArg, tripType) />
                <cfoutput>#serializeJSON(generated)#</cfoutput>
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
                <cfset var templateRouteId = val(pickArg(body, "templateRouteId", "template_route_id", 0)) />
                <cfset var templateRouteCode = trim(pickArg(body, "templateRouteCode", "template_route_code", "")) />
                <cfset var templateDirection = trim(pickArg(body, "direction", "direction", "CCW")) />
                <cfset var templateMode = trim(pickArg(body, "mode", "mode", "FULL_TEMPLATE")) />
                <cfset var templateName = trim(pickArg(body, "routeName", "route_name", "")) />
                <cfset var templateSetActive = toBoolean(pickArg(body, "setActive", "set_active", true), true) />
                <cfset var generatedFromTemplate = generateRouteFromTemplate(
                    userId = userId,
                    templateRouteId = templateRouteId,
                    templateRouteCode = templateRouteCode,
                    direction = templateDirection,
                    mode = templateMode,
                    routeName = templateName,
                    setActive = templateSetActive
                ) />
                <cfoutput>#serializeJSON(generatedFromTemplate)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "listuserroutes">
                <cfset var listed = listUserRoutes(userId) />
                <cfoutput>#serializeJSON(listed)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "listcanonicallocations">
                <cfset var canonicalDirection = pickArg(body, "direction", "direction", "CCW") />
                <cfset var canonical = listCanonicalLocations(canonicalDirection) />
                <cfoutput>#serializeJSON(canonical)#</cfoutput>
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

            <cfelseif act EQ "updatesegment">
                <cfset var segIdLocal = val(arguments.segmentId) />
                <cfif segIdLocal LTE 0>
                    <cfset segIdLocal = val(pickArg(body, "segmentId", "segmentId", 0)) />
                </cfif>
                <cfset var rc = trim(arguments.routeCode) />
                <cfif NOT len(rc)>
                    <cfset rc = trim(pickArg(body, "routeCode", "routeCode", "")) />
                </cfif>
                <cfif segIdLocal LTE 0 OR NOT len(rc)>
                    <cfoutput>#serializeJSON({
                        "SUCCESS"=false,
                        "AUTH"=true,
                        "MESSAGE"="segmentId and routeCode required",
                        "ERROR"={"MESSAGE"="segmentId and routeCode are required"}
                    })#</cfoutput>
                    <cfreturn>
                </cfif>
                <cfset var upd = updateSegment(userId, rc, segIdLocal, body) />
                <cfoutput>#serializeJSON(upd)#</cfoutput>
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
            var out = { "SUCCESS"=true, "AUTH"=true, "MESSAGE"="OK", "WARNINGS"=[] };
            var milepointService = getMilepointService();
            var rmAutoFillCount = 0;
            var rmUnresolvedCount = 0;
            var tripTypeVal = normalizeTripType(arguments.tripType);
            var startDateVal = trim(arguments.startDate);
            var startLocRaw = trim(arguments.startLocation);
            var endLocRaw = trim(arguments.endLocation);
            if (!len(startDateVal) OR !len(startLocRaw)) {
                return {
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Missing required fields",
                    "ERROR"={"MESSAGE"="startDate and startLocation are required"}
                };
            }
            if (tripTypeVal NEQ "FULL_LOOP" AND !len(endLocRaw)) {
                return {
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Missing required fields",
                    "ERROR"={"MESSAGE"="endLocation is required for point-to-point routes"}
                };
            }
            if (tripTypeVal EQ "FULL_LOOP") {
                endLocRaw = startLocRaw;
            }

            var qTpl = queryExecute(
                "SELECT id, name, short_code, description
                 FROM loop_routes
                 WHERE short_code = 'GREAT_LOOP_CCW'
                 LIMIT 1",
                {},
                { datasource = application.dsn }
            );
            if (qTpl.recordCount EQ 0) {
                return {
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Template route not found",
                    "ERROR"={"MESSAGE"="GREAT_LOOP_CCW was not found in loop_routes"}
                };
            }

            var templateRouteId = qTpl.id[1];
            var directionVal = normalizeDirection(arguments.direction);
            var shortCode = allocateUserRouteCode(arguments.userId);
            if (!len(shortCode)) {
                return {
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Unable to allocate user route code",
                    "ERROR"={"MESSAGE"="Could not generate a unique USER_ROUTE code."}
                };
            }
            var routeName = "My Great Loop Route";
            var routeDesc = "Generated from GREAT_LOOP_CCW (" & directionVal & ") on " & dateFormat(now(), "yyyy-mm-dd") & " (" & startLocRaw & " to " & endLocRaw & ")";

            var qTplSections = queryExecute(
                "SELECT id, name, slug, short_code, phase_num, order_index, is_active_default
                 FROM loop_sections
                 WHERE route_id = :rid
                 ORDER BY order_index ASC",
                { rid = { value=templateRouteId, cfsqltype="cf_sql_integer" } },
                { datasource = application.dsn }
            );

            var qTplSegments = queryExecute(
                "SELECT s.id, s.section_id, s.order_index, s.start_name, s.end_name, s.dist_nm, s.lock_count, s.rm_start, s.rm_end, s.is_signature_event, s.is_milestone_end, s.notes,
                        sec.order_index AS section_order
                 FROM loop_segments s
                 INNER JOIN loop_sections sec ON sec.id = s.section_id
                 WHERE sec.route_id = :rid
                 ORDER BY sec.order_index ASC, s.order_index ASC",
                { rid = { value=templateRouteId, cfsqltype="cf_sql_integer" } },
                { datasource = application.dsn }
            );

            var segmentRows = [];
            var routeOrderCounter = 0;
            var segIdx = 0;
            if (directionVal EQ "CW") {
                for (segIdx = qTplSegments.recordCount; segIdx GTE 1; segIdx--) {
                    routeOrderCounter += 1;
                    arrayAppend(segmentRows, {
                        "TEMPLATE_SEGMENT_ID"=qTplSegments.id[segIdx],
                        "SECTION_ID"=qTplSegments.section_id[segIdx],
                        "ORDER_INDEX"=qTplSegments.order_index[segIdx],
                        "SECTION_ORDER"=qTplSegments.section_order[segIdx],
                        "START_NAME"=qTplSegments.end_name[segIdx],
                        "END_NAME"=qTplSegments.start_name[segIdx],
                        "DIST_NM"=qTplSegments.dist_nm[segIdx],
                        "LOCK_COUNT"=qTplSegments.lock_count[segIdx],
                        "RM_START"=qTplSegments.rm_end[segIdx],
                        "RM_END"=qTplSegments.rm_start[segIdx],
                        "IS_SIGNATURE_EVENT"=qTplSegments.is_signature_event[segIdx],
                        "IS_MILESTONE_END"=qTplSegments.is_milestone_end[segIdx],
                        "NOTES"=qTplSegments.notes[segIdx],
                        "ROUTE_ORDER"=routeOrderCounter
                    });
                }
            } else {
                for (segIdx = 1; segIdx LTE qTplSegments.recordCount; segIdx++) {
                    routeOrderCounter += 1;
                    arrayAppend(segmentRows, {
                        "TEMPLATE_SEGMENT_ID"=qTplSegments.id[segIdx],
                        "SECTION_ID"=qTplSegments.section_id[segIdx],
                        "ORDER_INDEX"=qTplSegments.order_index[segIdx],
                        "SECTION_ORDER"=qTplSegments.section_order[segIdx],
                        "START_NAME"=qTplSegments.start_name[segIdx],
                        "END_NAME"=qTplSegments.end_name[segIdx],
                        "DIST_NM"=qTplSegments.dist_nm[segIdx],
                        "LOCK_COUNT"=qTplSegments.lock_count[segIdx],
                        "RM_START"=qTplSegments.rm_start[segIdx],
                        "RM_END"=qTplSegments.rm_end[segIdx],
                        "IS_SIGNATURE_EVENT"=qTplSegments.is_signature_event[segIdx],
                        "IS_MILESTONE_END"=qTplSegments.is_milestone_end[segIdx],
                        "NOTES"=qTplSegments.notes[segIdx],
                        "ROUTE_ORDER"=routeOrderCounter
                    });
                }
            }

            if (arrayLen(segmentRows) LTE 0) {
                return {
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Template route has no segments",
                    "ERROR"={"MESSAGE"="GREAT_LOOP_CCW has no loop_segments to generate from."}
                };
            }

            var matchInfo = findFocusSegments(templateRouteId, startLocRaw, endLocRaw, directionVal);
            var trimStartOrder = 0;
            var trimEndOrder = 0;
            var endFallbackUsed = false;
            var wrapRangeUsed = false;
            var selectedSegmentRows = [];
            var selectedIdx = 0;
            var fullLoopPick = {};
            var pointToPointPick = {};
            if (!matchInfo.START_FOUND OR val(matchInfo.START_ORDER) LTE 0) {
                return {
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Start location not found in route template",
                    "ERROR"={"MESSAGE"="The selected start location could not be matched in GREAT_LOOP_CCW (" & directionVal & ")."}
                };
            }
            trimStartOrder = val(matchInfo.START_ORDER);

            if (tripTypeVal EQ "FULL_LOOP") {
                fullLoopPick = pickBestFullLoopSelection(segmentRows, startLocRaw, trimStartOrder);
                if (fullLoopPick.SUCCESS) {
                    selectedSegmentRows = fullLoopPick.ROWS;
                    trimStartOrder = fullLoopPick.START_ORDER;
                    trimEndOrder = fullLoopPick.END_ORDER;
                } else {
                    for (selectedIdx = trimStartOrder; selectedIdx LTE arrayLen(segmentRows); selectedIdx++) {
                        arrayAppend(selectedSegmentRows, segmentRows[selectedIdx]);
                    }
                    for (selectedIdx = 1; selectedIdx LT trimStartOrder; selectedIdx++) {
                        arrayAppend(selectedSegmentRows, segmentRows[selectedIdx]);
                    }
                    if (arrayLen(selectedSegmentRows) GT 0) {
                        trimEndOrder = selectedSegmentRows[arrayLen(selectedSegmentRows)].ROUTE_ORDER;
                    } else {
                        trimEndOrder = 0;
                    }
                }
            } else {
                pointToPointPick = pickBestPointToPointSelection(segmentRows, startLocRaw, endLocRaw, trimStartOrder);
                if (pointToPointPick.SUCCESS) {
                    selectedSegmentRows = pointToPointPick.ROWS;
                    trimStartOrder = pointToPointPick.START_ORDER;
                    trimEndOrder = pointToPointPick.END_ORDER;
                    wrapRangeUsed = pointToPointPick.WRAP_RANGE;
                } else {
                    if (!matchInfo.END_FOUND OR val(matchInfo.END_ORDER) LTE 0) {
                        trimEndOrder = segmentRows[arrayLen(segmentRows)].ROUTE_ORDER;
                        endFallbackUsed = true;
                    } else {
                        trimEndOrder = val(matchInfo.END_ORDER);
                    }

                    if (trimEndOrder GTE trimStartOrder) {
                        for (selectedIdx = trimStartOrder; selectedIdx LTE trimEndOrder; selectedIdx++) {
                            arrayAppend(selectedSegmentRows, segmentRows[selectedIdx]);
                        }
                    } else {
                        wrapRangeUsed = true;
                        for (selectedIdx = trimStartOrder; selectedIdx LTE arrayLen(segmentRows); selectedIdx++) {
                            arrayAppend(selectedSegmentRows, segmentRows[selectedIdx]);
                        }
                        for (selectedIdx = 1; selectedIdx LTE trimEndOrder; selectedIdx++) {
                            arrayAppend(selectedSegmentRows, segmentRows[selectedIdx]);
                        }
                    }
                }
            }

            if (arrayLen(selectedSegmentRows) EQ 0) {
                return {
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Unable to build route range from selected start/end",
                    "ERROR"={"MESSAGE"="Could not resolve a valid contiguous route range from your selected start and end locations."}
                };
            }
            var continuityIssue = findRouteContinuityIssue(selectedSegmentRows);
            if (continuityIssue.HAS_BREAK) {
                return {
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Template route continuity error",
                    "ERROR"={
                        "MESSAGE"="Template continuity break between '" & continuityIssue.PREV_END_RAW & "' and '" & continuityIssue.NEXT_START_RAW & "'.",
                        "DETAIL"="GREAT_LOOP_CCW has non-contiguous segment ordering at route order " & continuityIssue.NEXT_ROUTE_ORDER & ". Update template segment ordering/data."
                    }
                };
            }

            var newRouteId = 0;
            var templateSectionInfoById = {};
            var segmentMap = {};
            var routeInstanceId = 0;
            var selectedSegIdx = 0;
            var sectionInfoIdx = 0;
            for (sectionInfoIdx = 1; sectionInfoIdx LTE qTplSections.recordCount; sectionInfoIdx++) {
                var tplSectionIdInfo = toString(qTplSections.id[sectionInfoIdx]);
                var sectionNameInfo = trim(toString(qTplSections.name[sectionInfoIdx]));
                var sectionSlugInfo = trim(toString(qTplSections.slug[sectionInfoIdx]));
                if (!len(sectionSlugInfo)) {
                    sectionSlugInfo = lCase(reReplace(sectionNameInfo, "[^A-Za-z0-9]+", "-", "all"));
                    sectionSlugInfo = reReplace(sectionSlugInfo, "^-+|-+$", "", "all");
                }
                if (!len(sectionSlugInfo)) {
                    sectionSlugInfo = "section-" & sectionInfoIdx;
                }
                var sectionShortCodeInfo = trim(toString(qTplSections.short_code[sectionInfoIdx]));
                if (!len(sectionShortCodeInfo)) {
                    sectionShortCodeInfo = uCase(reReplace(sectionSlugInfo, "[^A-Za-z0-9]+", "_", "all"));
                }
                if (!len(sectionNameInfo)) {
                    sectionNameInfo = "Section " & sectionInfoIdx;
                }
                templateSectionInfoById[tplSectionIdInfo] = {
                    "NAME"=sectionNameInfo,
                    "SLUG"=sectionSlugInfo,
                    "SHORT_CODE"=sectionShortCodeInfo,
                    "PHASE_NUM"=(isNull(qTplSections.phase_num[sectionInfoIdx]) ? 1 : val(qTplSections.phase_num[sectionInfoIdx])),
                    "IS_ACTIVE_DEFAULT"=(qTplSections.is_active_default[sectionInfoIdx] EQ 1 ? 1 : 0)
                };
            }

            transaction {
                queryExecute(
                    "INSERT INTO loop_routes (name, code, short_code, description, is_default)
                     VALUES (:name, :code, :shortCode, :descr, 0)",
                    {
                        name = { value=routeName, cfsqltype="cf_sql_varchar" },
                        code = { value=shortCode, cfsqltype="cf_sql_varchar" },
                        shortCode = { value=shortCode, cfsqltype="cf_sql_varchar" },
                        descr = { value=routeDesc, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource = application.dsn, result = "routeIns" }
                );
                newRouteId = val(routeIns.generatedKey);

                var i = 0;
                var segRow = {};
                var localOrderIndex = 0;
                var currentRunOldSectionId = "";
                var currentRunSectionId = 0;
                var currentRunSegmentOrder = 0;
                var sectionRunCountByTemplate = {};
                var runNum = 0;
                var sectionInfo = {};
                var sectionNameVal = "";
                var sectionSlugVal = "";
                var sectionShortCodeVal = "";
                var sectionOrderIndex = 0;
                for (i = 1; i LTE arrayLen(selectedSegmentRows); i++) {
                    segRow = selectedSegmentRows[i];
                    var oldSecId = toString(segRow.SECTION_ID);
                    var distNmBind = toNullableNumber(segRow.DIST_NM, "numeric");
                    var lockCountBind = toNullableNumber(segRow.LOCK_COUNT, "integer");
                    var rmStartBind = toNullableNumber(segRow.RM_START, "numeric");
                    var rmEndBind = toNullableNumber(segRow.RM_END, "numeric");
                    var startNameVal = trim(toString(segRow.START_NAME));
                    var endNameVal = trim(toString(segRow.END_NAME));
                    if (!structKeyExists(templateSectionInfoById, oldSecId)) {
                        continue;
                    }

                    if (oldSecId NEQ currentRunOldSectionId) {
                        currentRunOldSectionId = oldSecId;
                        currentRunSegmentOrder = 0;
                        runNum = (structKeyExists(sectionRunCountByTemplate, oldSecId) ? sectionRunCountByTemplate[oldSecId] + 1 : 1);
                        sectionRunCountByTemplate[oldSecId] = runNum;
                        sectionInfo = templateSectionInfoById[oldSecId];
                        sectionOrderIndex = i;

                        sectionNameVal = sectionInfo.NAME;
                        if (runNum GT 1) {
                            sectionNameVal &= " (Leg " & runNum & ")";
                        }

                        sectionSlugVal = sectionInfo.SLUG;
                        if (runNum GT 1) {
                            sectionSlugVal &= "-leg-" & runNum;
                        }
                        if (len(sectionSlugVal) GT 160) {
                            sectionSlugVal = left(sectionSlugVal, 160);
                        }

                        sectionShortCodeVal = sectionInfo.SHORT_CODE;
                        if (runNum GT 1) {
                            sectionShortCodeVal &= "_" & runNum;
                        }
                        if (len(sectionShortCodeVal) GT 40) {
                            sectionShortCodeVal = left(sectionShortCodeVal, 40);
                        }
                        if (!len(sectionShortCodeVal)) {
                            sectionShortCodeVal = "SECTION_" & sectionOrderIndex;
                        }

                        queryExecute(
                            "INSERT INTO loop_sections (route_id, name, slug, short_code, phase_num, order_index, is_active_default)
                             VALUES (:rid, :name, :slug, :scode, :phaseNum, :orderIndex, :isActive)",
                            {
                                rid = { value=newRouteId, cfsqltype="cf_sql_integer" },
                                name = { value=sectionNameVal, cfsqltype="cf_sql_varchar", null = false },
                                slug = { value=sectionSlugVal, cfsqltype="cf_sql_varchar", null = false },
                                scode = { value=sectionShortCodeVal, cfsqltype="cf_sql_varchar", null = false },
                                phaseNum = { value=sectionInfo.PHASE_NUM, cfsqltype="cf_sql_integer", null = false },
                                orderIndex = { value=sectionOrderIndex, cfsqltype="cf_sql_integer" },
                                isActive = { value=(i EQ 1 ? 1 : 0), cfsqltype="cf_sql_integer" }
                            },
                            { datasource = application.dsn, result = "secIns" }
                        );
                        currentRunSectionId = val(secIns.generatedKey);
                    }

                    currentRunSegmentOrder += 1;
                    localOrderIndex = currentRunSegmentOrder;
                    if (!len(startNameVal)) {
                        startNameVal = "Unknown Start";
                    }
                    if (!len(endNameVal)) {
                        endNameVal = "Unknown End";
                    }
                    sectionInfo = templateSectionInfoById[oldSecId];
                    if (isObject(milepointService)) {
                        var rmResolved = milepointService.resolveSegmentRM(sectionInfo.NAME, startNameVal, endNameVal);
                        if ((rmStartBind.isNull OR isNullableZero(rmStartBind)) AND rmResolved.START_FOUND) {
                            rmStartBind = { "isNull"=false, "value"=rmResolved.RM_START };
                        }
                        if ((rmEndBind.isNull OR isNullableZero(rmEndBind)) AND rmResolved.END_FOUND) {
                            rmEndBind = { "isNull"=false, "value"=rmResolved.RM_END };
                        }
                        if (!len(rmResolved.WATERWAY_CODE)) {
                            if (isNullableZero(rmStartBind)) rmStartBind = { "isNull"=true, "value"=0 };
                            if (isNullableZero(rmEndBind)) rmEndBind = { "isNull"=true, "value"=0 };
                        }
                        if (rmResolved.AUTOFILLED) {
                            rmAutoFillCount += 1;
                        } else if (len(rmResolved.WATERWAY_CODE) AND (NOT rmResolved.START_FOUND OR NOT rmResolved.END_FOUND)) {
                            rmUnresolvedCount += 1;
                        }
                    }
                    queryExecute(
                        "INSERT INTO loop_segments
                            (section_id, order_index, start_name, end_name, dist_nm, lock_count, rm_start, rm_end, is_signature_event, is_milestone_end, notes)
                         VALUES
                            (:sectionId, :orderIndex, :startName, :endName, :distNm, :lockCount, :rmStart, :rmEnd, :isSignature, :isMilestone, :notes)",
                        {
                            sectionId = { value=currentRunSectionId, cfsqltype="cf_sql_integer" },
                            orderIndex = { value=localOrderIndex, cfsqltype="cf_sql_integer" },
                            startName = { value=startNameVal, cfsqltype="cf_sql_varchar", null = false },
                            endName = { value=endNameVal, cfsqltype="cf_sql_varchar", null = false },
                            distNm = { value=distNmBind.value, cfsqltype="cf_sql_decimal", null = distNmBind.isNull },
                            lockCount = { value=lockCountBind.value, cfsqltype="cf_sql_integer", null = lockCountBind.isNull },
                            rmStart = { value=rmStartBind.value, cfsqltype="cf_sql_decimal", null = rmStartBind.isNull },
                            rmEnd = { value=rmEndBind.value, cfsqltype="cf_sql_decimal", null = rmEndBind.isNull },
                            isSignature = { value=(segRow.IS_SIGNATURE_EVENT EQ 1 ? 1 : 0), cfsqltype="cf_sql_integer" },
                            isMilestone = { value=(segRow.IS_MILESTONE_END EQ 1 ? 1 : 0), cfsqltype="cf_sql_integer" },
                            notes = { value=segRow.NOTES, cfsqltype="cf_sql_varchar", null = isNull(segRow.NOTES) }
                        },
                        { datasource = application.dsn, result = "segIns" }
                    );
                    segmentMap[toString(segRow.TEMPLATE_SEGMENT_ID)] = val(segIns.generatedKey);
                }

                queryExecute(
                    "INSERT INTO user_route_progress (user_id, segment_id, status, completed_at)
                     SELECT :uid, s.id, 'NOT_STARTED', NULL
                     FROM loop_segments s
                     INNER JOIN loop_sections sec ON sec.id = s.section_id
                     WHERE sec.route_id = :rid",
                    {
                        uid = { value=arguments.userId, cfsqltype="cf_sql_integer" },
                        rid = { value=newRouteId, cfsqltype="cf_sql_integer" }
                    },
                    { datasource = application.dsn }
                );

                queryExecute(
                    "INSERT INTO route_instances
                        (user_id, template_route_code, generated_route_id, generated_route_code, direction, trip_type, start_location, end_location, status)
                     VALUES
                        (:userId, :templateCode, :generatedRouteId, :generatedRouteCode, :direction, :tripType, :startLocation, :endLocation, 'PLANNED')",
                    {
                        userId = { value=toString(arguments.userId), cfsqltype="cf_sql_varchar" },
                        templateCode = { value="GREAT_LOOP_CCW", cfsqltype="cf_sql_varchar" },
                        generatedRouteId = { value=newRouteId, cfsqltype="cf_sql_integer" },
                        generatedRouteCode = { value=shortCode, cfsqltype="cf_sql_varchar" },
                        direction = { value=directionVal, cfsqltype="cf_sql_varchar" },
                        tripType = { value=tripTypeVal, cfsqltype="cf_sql_varchar" },
                        startLocation = { value=startLocRaw, cfsqltype="cf_sql_varchar" },
                        endLocation = { value=endLocRaw, cfsqltype="cf_sql_varchar", null=NOT len(endLocRaw) }
                    },
                    { datasource = application.dsn, result = "routeInstIns" }
                );
                routeInstanceId = val(routeInstIns.generatedKey);
            }

            if (endFallbackUsed) {
                arrayAppend(out.WARNINGS, "Could not match planned end location exactly; generated from selected start to template end.");
            }
            if (wrapRangeUsed) {
                arrayAppend(out.WARNINGS, "Route range wrapped across the loop origin.");
            }
            out.TRIMMED_TO_SELECTION = true;
            out.WRAP_RANGE = wrapRangeUsed;
            out.TRIP_TYPE = tripTypeVal;

            var timeline = getTimeline(arguments.userId, shortCode);
            out.ROUTE_CODE = shortCode;
            out.ROUTE_ID = newRouteId;
            out.ROUTE_INSTANCE_ID = routeInstanceId;
            out.DIRECTION = directionVal;
            out.START_DATE = startDateVal;
            out.START_LOCATION = startLocRaw;
            out.END_LOCATION = endLocRaw;
            out.FOCUS = {
                "START_SEGMENT_ID"=(structKeyExists(segmentMap, toString(matchInfo.START_SEGMENT_ID)) ? segmentMap[toString(matchInfo.START_SEGMENT_ID)] : 0),
                "END_SEGMENT_ID"=(structKeyExists(segmentMap, toString(matchInfo.END_SEGMENT_ID)) ? segmentMap[toString(matchInfo.END_SEGMENT_ID)] : 0),
                "START_FOUND"=matchInfo.START_FOUND,
                "END_FOUND"=matchInfo.END_FOUND
            };
            session.expeditionRouteCode = shortCode;
            out.RM_AUTOFILL_COUNT = rmAutoFillCount;
            out.RM_UNRESOLVED_COUNT = rmUnresolvedCount;
            structAppend(out, timeline, true);
            return out;
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
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unable to generate route from template",
                "DATA"={}
            };
            var templateRouteIdVal = val(arguments.templateRouteId);
            var templateRouteCodeVal = trim(arguments.templateRouteCode);
            var directionVal = normalizeDirection(arguments.direction);
            var modeVal = uCase(trim(toString(arguments.mode)));
            var setActiveVal = toBoolean(arguments.setActive, true);
            var routeNameVal = trim(arguments.routeName);
            var qTemplate = queryNew("");
            var qTemplateSegments = queryNew("");
            var legs = [];
            var i = 0;
            var srcIdx = 0;
            var leg = {};
            var shortCode = "";
            var routeDesc = "";
            var newRouteId = 0;
            var newSectionId = 0;
            var routeInstanceId = 0;
            var startLocationVal = "";
            var endLocationVal = "";
            var templateCodeOut = "";
            var templateNameOut = "";
            var templateShortCodeOut = "";
            var distBind = {};
            var lockBind = {};
            var notesBind = {};

            if (templateRouteIdVal LTE 0 AND !len(templateRouteCodeVal)) {
                out.MESSAGE = "Missing required fields";
                out.ERROR = { "MESSAGE"="templateRouteId or templateRouteCode is required." };
                return out;
            }

            if (modeVal NEQ "FULL_TEMPLATE") {
                out.MESSAGE = "Unsupported mode";
                out.ERROR = { "MESSAGE"="Only FULL_TEMPLATE mode is supported in this phase." };
                return out;
            }

            if (templateRouteIdVal GT 0) {
                qTemplate = queryExecute(
                    "SELECT id, code, short_code, name, description
                     FROM loop_routes
                     WHERE id = :rid
                       AND is_active = 1
                       AND short_code NOT LIKE :userPrefix
                       AND code NOT LIKE :userPrefix
                     LIMIT 1",
                    {
                        rid = { value=templateRouteIdVal, cfsqltype="cf_sql_integer" },
                        userPrefix = { value="USER_ROUTE_%", cfsqltype="cf_sql_varchar" }
                    },
                    { datasource = application.dsn }
                );
            } else {
                qTemplate = queryExecute(
                    "SELECT id, code, short_code, name, description
                     FROM loop_routes
                     WHERE is_active = 1
                       AND short_code NOT LIKE :userPrefix
                       AND code NOT LIKE :userPrefix
                       AND (short_code = :rcode OR code = :rcode)
                     ORDER BY CASE WHEN short_code = :rcode THEN 0 ELSE 1 END, id ASC
                     LIMIT 1",
                    {
                        userPrefix = { value="USER_ROUTE_%", cfsqltype="cf_sql_varchar" },
                        rcode = { value=templateRouteCodeVal, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource = application.dsn }
                );
            }

            if (qTemplate.recordCount EQ 0) {
                out.MESSAGE = "Template route not found";
                out.ERROR = { "MESSAGE"="No active canonical template matched the provided templateRouteId/templateRouteCode." };
                return out;
            }

            templateRouteIdVal = val(qTemplate.id[1]);
            templateCodeOut = (isNull(qTemplate.code[1]) ? "" : trim(toString(qTemplate.code[1])));
            templateShortCodeOut = (isNull(qTemplate.short_code[1]) ? "" : trim(toString(qTemplate.short_code[1])));
            templateNameOut = (isNull(qTemplate.name[1]) ? "" : trim(toString(qTemplate.name[1])));

            qTemplateSegments = queryExecute(
                "SELECT
                    rts.order_index,
                    sl.id AS segment_id,
                    p1.id AS start_port_id,
                    COALESCE(NULLIF(TRIM(p1.name), ''), TRIM(sl.start_port_name), '') AS start_port,
                    p2.id AS end_port_id,
                    COALESCE(NULLIF(TRIM(p2.name), ''), TRIM(sl.end_port_name), '') AS end_port,
                    sl.dist_nm,
                    sl.lock_count,
                    sl.is_offshore,
                    sl.is_icw,
                    sl.notes
                 FROM route_template_segments rts
                 INNER JOIN segment_library sl ON sl.id = rts.segment_id
                 LEFT JOIN ports p1 ON p1.id = sl.start_port_id
                 LEFT JOIN ports p2 ON p2.id = sl.end_port_id
                 WHERE rts.route_id = :rid
                 ORDER BY rts.order_index ASC, rts.id ASC",
                {
                    rid = { value=templateRouteIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );

            if (qTemplateSegments.recordCount EQ 0) {
                out.MESSAGE = "Template route has no segments";
                out.ERROR = { "MESSAGE"="The selected template route has no route_template_segments. Use Custom Start / End mode or migrate this template to route_template_segments." };
                return out;
            }

            for (i = 1; i LTE qTemplateSegments.recordCount; i++) {
                srcIdx = (directionVal EQ "CW" ? (qTemplateSegments.recordCount - i + 1) : i);
                leg = {
                    "ORDER_INDEX"=i,
                    "SEGMENT_ID"=val(qTemplateSegments.segment_id[srcIdx]),
                    "START_PORT_ID"=(directionVal EQ "CW"
                        ? (isNull(qTemplateSegments.end_port_id[srcIdx]) ? 0 : val(qTemplateSegments.end_port_id[srcIdx]))
                        : (isNull(qTemplateSegments.start_port_id[srcIdx]) ? 0 : val(qTemplateSegments.start_port_id[srcIdx]))),
                    "START_PORT"=(directionVal EQ "CW"
                        ? (isNull(qTemplateSegments.end_port[srcIdx]) ? "" : trim(toString(qTemplateSegments.end_port[srcIdx])))
                        : (isNull(qTemplateSegments.start_port[srcIdx]) ? "" : trim(toString(qTemplateSegments.start_port[srcIdx])))),
                    "END_PORT_ID"=(directionVal EQ "CW"
                        ? (isNull(qTemplateSegments.start_port_id[srcIdx]) ? 0 : val(qTemplateSegments.start_port_id[srcIdx]))
                        : (isNull(qTemplateSegments.end_port_id[srcIdx]) ? 0 : val(qTemplateSegments.end_port_id[srcIdx]))),
                    "END_PORT"=(directionVal EQ "CW"
                        ? (isNull(qTemplateSegments.start_port[srcIdx]) ? "" : trim(toString(qTemplateSegments.start_port[srcIdx])))
                        : (isNull(qTemplateSegments.end_port[srcIdx]) ? "" : trim(toString(qTemplateSegments.end_port[srcIdx])))),
                    "DIST_NM"=(isNull(qTemplateSegments.dist_nm[srcIdx]) ? 0 : val(qTemplateSegments.dist_nm[srcIdx])),
                    "LOCK_COUNT"=(isNull(qTemplateSegments.lock_count[srcIdx]) ? 0 : val(qTemplateSegments.lock_count[srcIdx])),
                    "IS_OFFSHORE"=(qTemplateSegments.is_offshore[srcIdx] EQ 1 ? 1 : 0),
                    "IS_ICW"=(qTemplateSegments.is_icw[srcIdx] EQ 1 ? 1 : 0),
                    "NOTES"=(isNull(qTemplateSegments.notes[srcIdx]) ? "" : toString(qTemplateSegments.notes[srcIdx]))
                };
                if (!len(leg.START_PORT)) leg.START_PORT = "Unknown Start";
                if (!len(leg.END_PORT)) leg.END_PORT = "Unknown End";
                arrayAppend(legs, leg);
            }

            if (!len(routeNameVal)) {
                if (len(templateNameOut)) {
                    routeNameVal = templateNameOut & " Route";
                } else {
                    routeNameVal = "My Route";
                }
            }

            shortCode = allocateUserRouteCode(arguments.userId);
            if (!len(shortCode)) {
                out.MESSAGE = "Unable to allocate user route code";
                out.ERROR = { "MESSAGE"="Could not generate a unique USER_ROUTE code." };
                return out;
            }

            startLocationVal = legs[1].START_PORT;
            endLocationVal = legs[arrayLen(legs)].END_PORT;
            routeDesc = "Generated from template " & (len(templateShortCodeOut) ? templateShortCodeOut : templateCodeOut) & " (" & directionVal & ")";

            transaction {
                queryExecute(
                    "INSERT INTO loop_routes
                        (code, name, short_code, description, is_active, version, is_default)
                     VALUES
                        (:code, :name, :shortCode, :descr, 1, 1, 0)",
                    {
                        code = { value=shortCode, cfsqltype="cf_sql_varchar" },
                        name = { value=routeNameVal, cfsqltype="cf_sql_varchar" },
                        shortCode = { value=shortCode, cfsqltype="cf_sql_varchar" },
                        descr = { value=routeDesc, cfsqltype="cf_sql_varchar", null=NOT len(routeDesc) }
                    },
                    { datasource = application.dsn, result = "routeInsFromTpl" }
                );
                newRouteId = val(routeInsFromTpl.generatedKey);

                queryExecute(
                    "INSERT INTO loop_sections
                        (route_id, name, slug, short_code, phase_num, order_index, is_active_default)
                     VALUES
                        (:rid, :name, :slug, :shortCode, 1, 1, 1)",
                    {
                        rid = { value=newRouteId, cfsqltype="cf_sql_integer" },
                        name = { value="Route", cfsqltype="cf_sql_varchar" },
                        slug = { value="route", cfsqltype="cf_sql_varchar" },
                        shortCode = { value="ROUTE", cfsqltype="cf_sql_varchar" }
                    },
                    { datasource = application.dsn, result = "secInsFromTpl" }
                );
                newSectionId = val(secInsFromTpl.generatedKey);

                for (i = 1; i LTE arrayLen(legs); i++) {
                    distBind = toNullableNumber(legs[i].DIST_NM, "numeric");
                    lockBind = toNullableNumber(legs[i].LOCK_COUNT, "integer");
                    notesBind = toNullableString(legs[i].NOTES);
                    if (!notesBind.isNull AND len(notesBind.value) GT 255) {
                        notesBind.value = left(notesBind.value, 255);
                    }
                    queryExecute(
                        "INSERT INTO loop_segments
                            (section_id, order_index, start_name, end_name, dist_nm, lock_count, rm_start, rm_end, is_signature_event, is_milestone_end, notes)
                         VALUES
                            (:sectionId, :orderIndex, :startName, :endName, :distNm, :lockCount, NULL, NULL, 0, 0, :notes)",
                        {
                            sectionId = { value=newSectionId, cfsqltype="cf_sql_integer" },
                            orderIndex = { value=i, cfsqltype="cf_sql_integer" },
                            startName = { value=legs[i].START_PORT, cfsqltype="cf_sql_varchar" },
                            endName = { value=legs[i].END_PORT, cfsqltype="cf_sql_varchar" },
                            distNm = { value=distBind.value, cfsqltype="cf_sql_decimal", null=distBind.isNull },
                            lockCount = { value=lockBind.value, cfsqltype="cf_sql_integer", null=lockBind.isNull },
                            notes = { value=notesBind.value, cfsqltype="cf_sql_varchar", null=notesBind.isNull }
                        },
                        { datasource = application.dsn }
                    );
                }

                queryExecute(
                    "INSERT INTO user_route_progress (user_id, segment_id, status, completed_at)
                     SELECT :uid, s.id, 'NOT_STARTED', NULL
                     FROM loop_segments s
                     INNER JOIN loop_sections sec ON sec.id = s.section_id
                     WHERE sec.route_id = :rid",
                    {
                        uid = { value=arguments.userId, cfsqltype="cf_sql_integer" },
                        rid = { value=newRouteId, cfsqltype="cf_sql_integer" }
                    },
                    { datasource = application.dsn }
                );

                queryExecute(
                    "INSERT INTO route_instances
                        (user_id, template_route_code, generated_route_id, generated_route_code, direction, trip_type, start_location, end_location, status)
                     VALUES
                        (:userId, :templateCode, :generatedRouteId, :generatedRouteCode, :direction, 'FULL_LOOP', :startLocation, :endLocation, 'PLANNED')",
                    {
                        userId = { value=toString(arguments.userId), cfsqltype="cf_sql_varchar" },
                        templateCode = { value=(len(templateShortCodeOut) ? templateShortCodeOut : templateCodeOut), cfsqltype="cf_sql_varchar" },
                        generatedRouteId = { value=newRouteId, cfsqltype="cf_sql_integer" },
                        generatedRouteCode = { value=shortCode, cfsqltype="cf_sql_varchar" },
                        direction = { value=directionVal, cfsqltype="cf_sql_varchar" },
                        startLocation = { value=startLocationVal, cfsqltype="cf_sql_varchar" },
                        endLocation = { value=endLocationVal, cfsqltype="cf_sql_varchar", null=NOT len(endLocationVal) }
                    },
                    { datasource = application.dsn, result = "routeInstInsFromTpl" }
                );
                routeInstanceId = val(routeInstInsFromTpl.generatedKey);
            }

            if (setActiveVal) {
                session.expeditionRouteCode = shortCode;
            }

            out.SUCCESS = true;
            out.MESSAGE = "OK";
            out.DATA = {
                "ROUTE_CODE"=shortCode,
                "ROUTE_ID"=newRouteId,
                "ROUTE_INSTANCE_ID"=routeInstanceId,
                "TEMPLATE"={
                    "ID"=templateRouteIdVal,
                    "CODE"=(len(templateCodeOut) ? templateCodeOut : templateShortCodeOut),
                    "NAME"=templateNameOut
                },
                "DIRECTION"=directionVal,
                "MODE"=modeVal,
                "NEXT_ACTION_HINT"="getTimeline"
            };
            return out;
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
            var out = {
                "SUCCESS"=true,
                "AUTH"=true,
                "MESSAGE"="OK",
                "TEMPLATE_ROUTE_CODE"="GREAT_LOOP_CCW",
                "LOCATIONS"=[],
                "START_LOCATIONS"=[],
                "END_LOCATIONS"=[]
            };
            var qTpl = queryExecute(
                "SELECT id
                 FROM loop_routes
                 WHERE short_code = :code
                 LIMIT 1",
                { code = { value=out.TEMPLATE_ROUTE_CODE, cfsqltype="cf_sql_varchar" } },
                { datasource = application.dsn }
            );
            if (qTpl.recordCount EQ 0) {
                return {
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Template route not found",
                    "ERROR"={"MESSAGE"=out.TEMPLATE_ROUTE_CODE & " was not found in loop_routes"}
                };
            }

            var qNodes = queryExecute(
                "SELECT s.start_name, s.end_name
                 FROM loop_segments s
                 INNER JOIN loop_sections sec ON sec.id = s.section_id
                 WHERE sec.route_id = :rid
                 ORDER BY sec.order_index ASC, s.order_index ASC",
                { rid = { value=val(qTpl.id[1]), cfsqltype="cf_sql_integer" } },
                { datasource = application.dsn }
            );

            var seen = {};
            var seenStarts = {};
            var seenEnds = {};
            var directionVal = normalizeDirection(arguments.direction);
            var i = 0;
            var srcIdx = 0;
            var locationValue = "";
            var locationKey = "";
            var orientedStart = "";
            var orientedEnd = "";

            for (i = 1; i LTE qNodes.recordCount; i++) {
                srcIdx = (directionVal EQ "CW" ? (qNodes.recordCount - i + 1) : i);
                orientedStart = (directionVal EQ "CW" ? qNodes.end_name[srcIdx] : qNodes.start_name[srcIdx]);
                orientedEnd = (directionVal EQ "CW" ? qNodes.start_name[srcIdx] : qNodes.end_name[srcIdx]);

                locationValue = trim(toString(orientedStart));
                if (len(locationValue)) {
                    locationKey = normalizeText(locationValue);
                    if (!len(locationKey)) locationKey = lCase(locationValue);
                    if (!structKeyExists(seenStarts, locationKey)) {
                        seenStarts[locationKey] = true;
                        arrayAppend(out.START_LOCATIONS, locationValue);
                    }
                    if (!structKeyExists(seen, locationKey)) {
                        seen[locationKey] = true;
                        arrayAppend(out.LOCATIONS, locationValue);
                    }
                }

                locationValue = trim(toString(orientedEnd));
                if (len(locationValue)) {
                    locationKey = normalizeText(locationValue);
                    if (!len(locationKey)) locationKey = lCase(locationValue);
                    if (!structKeyExists(seenEnds, locationKey)) {
                        seenEnds[locationKey] = true;
                        arrayAppend(out.END_LOCATIONS, locationValue);
                    }
                    if (!structKeyExists(seen, locationKey)) {
                        seen[locationKey] = true;
                        arrayAppend(out.LOCATIONS, locationValue);
                    }
                }
            }
            out.DIRECTION = directionVal;
            return out;
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
            var out = { "SUCCESS"=false, "AUTH"=true, "MESSAGE"="Update failed" };
            var qOwner = queryExecute(
                "SELECT s.id, sec.name AS section_name, sec.short_code AS section_short_code
                 FROM loop_segments s
                 INNER JOIN loop_sections sec ON sec.id = s.section_id
                 INNER JOIN loop_routes r ON r.id = sec.route_id
                 WHERE s.id = :sid
                   AND r.short_code = :rcode
                 LIMIT 1",
                {
                    sid = { value=arguments.segmentId, cfsqltype="cf_sql_integer" },
                    rcode = { value=arguments.routeCode, cfsqltype="cf_sql_varchar" }
                },
                { datasource = application.dsn }
            );
            if (qOwner.recordCount EQ 0) {
                return {
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Segment not found for route",
                    "ERROR"={"MESSAGE"="Segment does not belong to routeCode"}
                };
            }

            var qCurrent = queryExecute(
                "SELECT start_name, end_name, dist_nm, lock_count, rm_start, rm_end, notes
                 FROM loop_segments
                 WHERE id = :sid
                 LIMIT 1",
                { sid = { value=arguments.segmentId, cfsqltype="cf_sql_integer" } },
                { datasource = application.dsn }
            );
            if (qCurrent.recordCount EQ 0) {
                return {
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Segment not found",
                    "ERROR"={"MESSAGE"="Unable to load current segment values."}
                };
            }

            var hasStartName = structKeyExists(arguments.body, "start_name");
            var hasEndName = structKeyExists(arguments.body, "end_name");
            var hasDistNm = structKeyExists(arguments.body, "dist_nm");
            var hasLockCount = structKeyExists(arguments.body, "lock_count");
            var hasRmStart = structKeyExists(arguments.body, "rm_start");
            var hasRmEnd = structKeyExists(arguments.body, "rm_end");
            var hasNotes = structKeyExists(arguments.body, "notes");

            var startNameRaw = hasStartName ? pickStruct(arguments.body, "start_name", "") : qCurrent.start_name[1];
            var endNameRaw = hasEndName ? pickStruct(arguments.body, "end_name", "") : qCurrent.end_name[1];
            var distNmRaw = hasDistNm ? pickStruct(arguments.body, "dist_nm", "") : qCurrent.dist_nm[1];
            var lockCountRaw = hasLockCount ? pickStruct(arguments.body, "lock_count", "") : qCurrent.lock_count[1];
            var rmStartRaw = hasRmStart ? pickStruct(arguments.body, "rm_start", "") : qCurrent.rm_start[1];
            var rmEndRaw = hasRmEnd ? pickStruct(arguments.body, "rm_end", "") : qCurrent.rm_end[1];
            var notesRaw = hasNotes ? pickStruct(arguments.body, "notes", "") : qCurrent.notes[1];

            var startNameVal = trim(toString(startNameRaw));
            var endNameVal = trim(toString(endNameRaw));
            if (!len(startNameVal)) startNameVal = "Unknown Start";
            if (!len(endNameVal)) endNameVal = "Unknown End";

            var startName = { "isNull"=false, "value"=startNameVal };
            var endName = { "isNull"=false, "value"=endNameVal };
            var distNm = toNullableNumber(distNmRaw, "numeric");
            var lockCount = toNullableNumber(lockCountRaw, "integer");
            var rmStart = toNullableNumber(rmStartRaw, "numeric");
            var rmEnd = toNullableNumber(rmEndRaw, "numeric");
            var notes = toNullableString(notesRaw);
            var rmAutofilledStart = false;
            var rmAutofilledEnd = false;

            if ((hasStartName OR hasEndName) AND isObject(getMilepointService())) {
                var milepointService = getMilepointService();
                var rmResolved = milepointService.resolveSegmentRM(
                    (isNull(qOwner.section_name[1]) ? "" : qOwner.section_name[1]),
                    startName.value,
                    endName.value
                );
                if (NOT hasRmStart AND rmResolved.START_FOUND) {
                    rmStart = { "isNull"=false, "value"=rmResolved.RM_START };
                    rmAutofilledStart = true;
                }
                if (NOT hasRmEnd AND rmResolved.END_FOUND) {
                    rmEnd = { "isNull"=false, "value"=rmResolved.RM_END };
                    rmAutofilledEnd = true;
                }
                if (NOT hasRmStart AND NOT rmResolved.START_FOUND AND isNullableZero(rmStart)) {
                    rmStart = { "isNull"=true, "value"=0 };
                }
                if (NOT hasRmEnd AND NOT rmResolved.END_FOUND AND isNullableZero(rmEnd)) {
                    rmEnd = { "isNull"=true, "value"=0 };
                }
            }

            queryExecute(
                "UPDATE loop_segments
                 SET start_name = :startName,
                     end_name = :endName,
                     dist_nm = :distNm,
                     lock_count = :lockCount,
                     rm_start = :rmStart,
                     rm_end = :rmEnd,
                     notes = :notes
                 WHERE id = :sid",
                {
                    startName = { value=startName.value, cfsqltype="cf_sql_varchar", null=startName.isNull },
                    endName = { value=endName.value, cfsqltype="cf_sql_varchar", null=endName.isNull },
                    distNm = { value=distNm.value, cfsqltype="cf_sql_decimal", null=distNm.isNull },
                    lockCount = { value=lockCount.value, cfsqltype="cf_sql_integer", null=lockCount.isNull },
                    rmStart = { value=rmStart.value, cfsqltype="cf_sql_decimal", null=rmStart.isNull },
                    rmEnd = { value=rmEnd.value, cfsqltype="cf_sql_decimal", null=rmEnd.isNull },
                    notes = { value=notes.value, cfsqltype="cf_sql_varchar", null=notes.isNull },
                    sid = { value=arguments.segmentId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            );

            var qSeg = queryExecute(
                "SELECT id, start_name, end_name, dist_nm, lock_count, rm_start, rm_end, notes
                 FROM loop_segments
                 WHERE id = :sid
                 LIMIT 1",
                { sid = { value=arguments.segmentId, cfsqltype="cf_sql_integer" } },
                { datasource = application.dsn }
            );

            if (qSeg.recordCount EQ 1) {
                out.SUCCESS = true;
                out.MESSAGE = "Segment updated";
                out.RM_AUTOFILLED_START = rmAutofilledStart;
                out.RM_AUTOFILLED_END = rmAutofilledEnd;
                out.SEGMENT = {
                    "ID"=qSeg.id[1],
                    "START_NAME"=(isNull(qSeg.start_name[1]) ? "" : qSeg.start_name[1]),
                    "END_NAME"=(isNull(qSeg.end_name[1]) ? "" : qSeg.end_name[1]),
                    "DIST_NM"=(isNull(qSeg.dist_nm[1]) ? "" : val(qSeg.dist_nm[1])),
                    "LOCK_COUNT"=(isNull(qSeg.lock_count[1]) ? "" : val(qSeg.lock_count[1])),
                    "RM_START"=(isNull(qSeg.rm_start[1]) ? "" : val(qSeg.rm_start[1])),
                    "RM_END"=(isNull(qSeg.rm_end[1]) ? "" : val(qSeg.rm_end[1])),
                    "NOTES"=(isNull(qSeg.notes[1]) ? "" : qSeg.notes[1])
                };
            }
            return out;
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

            qSegments = queryExecute(
                "SELECT sec.id AS section_id, sec.name AS section_name, sec.order_index AS section_order,
                        s.id AS segment_id, s.order_index AS segment_order, s.start_name, s.end_name, s.dist_nm, s.lock_count
                 FROM loop_sections sec
                 INNER JOIN loop_segments s ON s.section_id = sec.id
                 WHERE sec.route_id = :rid
                 ORDER BY sec.order_index ASC, s.order_index ASC",
                { rid = { value=generatedRouteId, cfsqltype="cf_sql_integer" } },
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
            transaction {
                queryExecute(
                    "DELETE FROM user_route_progress
                     WHERE segment_id IN (
                        SELECT s.id
                        FROM loop_segments s
                        INNER JOIN loop_sections sec ON sec.id = s.section_id
                        WHERE sec.route_id = :rid
                     )",
                    { rid = { value=routeId, cfsqltype="cf_sql_integer" } },
                    { datasource = application.dsn }
                );
                queryExecute(
                    "DELETE FROM loop_segments
                     WHERE section_id IN (
                        SELECT id FROM loop_sections WHERE route_id = :rid
                     )",
                    { rid = { value=routeId, cfsqltype="cf_sql_integer" } },
                    { datasource = application.dsn }
                );
                queryExecute(
                    "DELETE FROM loop_sections
                     WHERE route_id = :rid",
                    { rid = { value=routeId, cfsqltype="cf_sql_integer" } },
                    { datasource = application.dsn }
                );
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

        <cfset var qSections = queryExecute(
            "SELECT id, name, short_code, phase_num, order_index, is_active_default
             FROM loop_sections
             WHERE route_id = :rid
             ORDER BY order_index ASC",
            { rid = { value=routeId, cfsqltype="cf_sql_integer" } },
            { datasource = application.dsn }
        ) />

        <cfset var qSegments = queryExecute(
            "SELECT s.id, s.section_id, s.order_index, s.start_name, s.end_name, s.dist_nm, s.lock_count,
                    s.rm_start, s.rm_end, s.is_signature_event, s.is_milestone_end, s.notes,
                    sec.order_index AS section_order
             FROM loop_segments s
             INNER JOIN loop_sections sec ON sec.id = s.section_id
             WHERE sec.route_id = :rid
             ORDER BY sec.order_index ASC, s.order_index ASC",
            { rid = { value=routeId, cfsqltype="cf_sql_integer" } },
            { datasource = application.dsn }
        ) />

        <cfset var qProg = queryExecute(
            "SELECT segment_id, status, completed_at
             FROM user_route_progress
             WHERE user_id = :uid
               AND segment_id IN (
                 SELECT s.id
                 FROM loop_segments s
                 JOIN loop_sections sec ON sec.id = s.section_id
                 WHERE sec.route_id = :rid
               )",
            {
                uid = { value=arguments.userId, cfsqltype="cf_sql_integer" },
                rid = { value=routeId, cfsqltype="cf_sql_integer" }
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
                "SELECT s.id, s.start_name, s.end_name, sec.order_index AS section_order, s.order_index AS seg_order
                 FROM loop_segments s
                 INNER JOIN loop_sections sec ON sec.id = s.section_id
                 WHERE sec.route_id = :rid
                 ORDER BY sec.order_index ASC, s.order_index ASC",
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
            var q = queryExecute(
                "SELECT
                    rts.order_index AS template_order,
                    sl.id AS segment_id,
                    p1.id AS start_port_id,
                    COALESCE(NULLIF(TRIM(p1.name), ''), TRIM(sl.start_port_name), '') AS start_port,
                    p2.id AS end_port_id,
                    COALESCE(NULLIF(TRIM(p2.name), ''), TRIM(sl.end_port_name), '') AS end_port,
                    sl.dist_nm,
                    sl.lock_count,
                    sl.is_offshore,
                    sl.is_icw,
                    sl.notes
                 FROM route_template_segments rts
                 INNER JOIN segment_library sl ON sl.id = rts.segment_id
                 LEFT JOIN ports p1 ON p1.id = sl.start_port_id
                 LEFT JOIN ports p2 ON p2.id = sl.end_port_id
                 WHERE rts.route_id = :rid
                 ORDER BY rts.order_index ASC, rts.id ASC",
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
                    p2.id AS end_port_id,
                    COALESCE(NULLIF(TRIM(p2.name), ''), TRIM(sl.end_port_name), '') AS end_port,
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
                    "END_PORT_ID"=(isNull(qSeg.end_port_id[i]) ? 0 : val(qSeg.end_port_id[i])),
                    "END_NAME"=(isNull(qSeg.end_port[i]) ? "" : trim(toString(qSeg.end_port[i]))),
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
                        leg.START_NAME = leg.END_NAME;
                        leg.START_PORT_ID = leg.END_PORT_ID;
                        leg.END_NAME = swapStartName;
                        leg.END_PORT_ID = swapStartPort;
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
                "template"={
                    "id"=templateInfo.ID,
                    "code"=(len(templateInfo.SHORT_CODE) ? templateInfo.SHORT_CODE : templateInfo.CODE),
                    "name"=templateInfo.NAME,
                    "description"=templateInfo.DESCRIPTION,
                    "is_loop"=(templateIsLoop ? true : false)
                },
                "inputs"={
                    "template_code"=(len(templateInfo.SHORT_CODE) ? templateInfo.SHORT_CODE : templateInfo.CODE),
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

            var i = 0;
            for (i = 1; i LTE arrayLen(finalLegs); i++) {
                arrayAppend(out.DATA.legs, {
                    "order_index"=i,
                    "segment_id"=val(finalLegs[i].SEGMENT_ID),
                    "start_name"=toString(finalLegs[i].START_NAME),
                    "end_name"=toString(finalLegs[i].END_NAME),
                    "dist_nm"=roundTo2(val(finalLegs[i].DIST_NM)),
                    "lock_count"=val(finalLegs[i].LOCK_COUNT),
                    "is_offshore"=(finalLegs[i].IS_OFFSHORE ? true : false),
                    "is_icw"=(finalLegs[i].IS_ICW ? true : false),
                    "is_optional"=(finalLegs[i].IS_OPTIONAL ? true : false),
                    "detour_code"=toString(finalLegs[i].DETOUR_CODE),
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
            var preview = routegenBuildPreview(arguments.input);
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
            var qInstSql = "SELECT template_route_code, direction, trip_type, start_location, end_location, created_at";
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

            var startLabel = trim(toString(qInst.start_location[1]));
            var endLabel = trim(toString(qInst.end_location[1]));
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

            var preview = routegenBuildPreview(arguments.input);
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
            var newSectionId = 0;
            var routeInstanceId = 0;
            var i = 0;
            var leg = {};
            var distBind = {};
            var lockBind = {};
            var notesBind = {};
            var notesVal = "";

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

                queryExecute(
                    "INSERT INTO loop_sections
                        (route_id, name, slug, short_code, phase_num, order_index, is_active_default)
                     VALUES
                        (:rid, :name, :slug, :shortCode, 1, 1, 1)",
                    {
                        rid = { value=newRouteId, cfsqltype="cf_sql_integer" },
                        name = { value="Route", cfsqltype="cf_sql_varchar" },
                        slug = { value="route", cfsqltype="cf_sql_varchar" },
                        shortCode = { value="ROUTE", cfsqltype="cf_sql_varchar" }
                    },
                    { datasource = application.dsn, result = "routegenSecIns" }
                );
                newSectionId = val(routegenSecIns.generatedKey);

                for (i = 1; i LTE arrayLen(legs); i++) {
                    leg = legs[i];
                    distBind = toNullableNumber(leg.dist_nm, "numeric");
                    lockBind = toNullableNumber(leg.lock_count, "integer");
                    notesVal = trim(toString(structKeyExists(leg, "notes") ? leg.notes : ""));
                    if (toBoolean(leg.is_optional, false) AND len(trim(toString(leg.detour_code)))) {
                        if (len(notesVal)) notesVal &= " ";
                        notesVal &= "[Optional stop: " & trim(toString(leg.detour_code)) & "]";
                    }
                    notesBind = toNullableString(notesVal);
                    if (!notesBind.isNull AND len(notesBind.value) GT 255) {
                        notesBind.value = left(notesBind.value, 255);
                    }

                    queryExecute(
                        "INSERT INTO loop_segments
                            (section_id, order_index, start_name, end_name, dist_nm, lock_count, rm_start, rm_end, is_signature_event, is_milestone_end, notes)
                         VALUES
                            (:sectionId, :orderIndex, :startName, :endName, :distNm, :lockCount, NULL, NULL, 0, 0, :notes)",
                        {
                            sectionId = { value=newSectionId, cfsqltype="cf_sql_integer" },
                            orderIndex = { value=i, cfsqltype="cf_sql_integer" },
                            startName = { value=trim(toString(leg.start_name)), cfsqltype="cf_sql_varchar" },
                            endName = { value=trim(toString(leg.end_name)), cfsqltype="cf_sql_varchar" },
                            distNm = { value=distBind.value, cfsqltype="cf_sql_decimal", null=distBind.isNull },
                            lockCount = { value=lockBind.value, cfsqltype="cf_sql_integer", null=lockBind.isNull },
                            notes = { value=notesBind.value, cfsqltype="cf_sql_varchar", null=notesBind.isNull }
                        },
                        { datasource = application.dsn }
                    );
                }

                queryExecute(
                    "INSERT INTO user_route_progress (user_id, segment_id, status, completed_at)
                     SELECT :uid, s.id, 'NOT_STARTED', NULL
                     FROM loop_segments s
                     INNER JOIN loop_sections sec ON sec.id = s.section_id
                     WHERE sec.route_id = :rid",
                    {
                        uid = { value=arguments.userId, cfsqltype="cf_sql_integer" },
                        rid = { value=newRouteId, cfsqltype="cf_sql_integer" }
                    },
                    { datasource = application.dsn }
                );

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

            var preview = routegenBuildPreview(arguments.input);
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

            var newSectionId = 0;
            var routeInstanceId = 0;
            var qInst = queryNew("");
            var i = 0;
            var leg = {};
            var distBind = {};
            var lockBind = {};
            var notesBind = {};
            var notesVal = "";

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

                queryExecute(
                    "DELETE FROM loop_sections
                     WHERE route_id = :rid",
                    { rid = { value=routeId, cfsqltype="cf_sql_integer" } },
                    { datasource = application.dsn }
                );

                queryExecute(
                    "INSERT INTO loop_sections
                        (route_id, name, slug, short_code, phase_num, order_index, is_active_default)
                     VALUES
                        (:rid, :name, :slug, :shortCode, 1, 1, 1)",
                    {
                        rid = { value=routeId, cfsqltype="cf_sql_integer" },
                        name = { value="Route", cfsqltype="cf_sql_varchar" },
                        slug = { value="route", cfsqltype="cf_sql_varchar" },
                        shortCode = { value="ROUTE", cfsqltype="cf_sql_varchar" }
                    },
                    { datasource = application.dsn, result = "routegenUpdSecIns" }
                );
                newSectionId = val(routegenUpdSecIns.generatedKey);

                for (i = 1; i LTE arrayLen(legs); i++) {
                    leg = legs[i];
                    distBind = toNullableNumber(leg.dist_nm, "numeric");
                    lockBind = toNullableNumber(leg.lock_count, "integer");
                    notesVal = trim(toString(structKeyExists(leg, "notes") ? leg.notes : ""));
                    if (toBoolean(leg.is_optional, false) AND len(trim(toString(leg.detour_code)))) {
                        if (len(notesVal)) notesVal &= " ";
                        notesVal &= "[Optional stop: " & trim(toString(leg.detour_code)) & "]";
                    }
                    notesBind = toNullableString(notesVal);
                    if (!notesBind.isNull AND len(notesBind.value) GT 255) {
                        notesBind.value = left(notesBind.value, 255);
                    }

                    queryExecute(
                        "INSERT INTO loop_segments
                            (section_id, order_index, start_name, end_name, dist_nm, lock_count, rm_start, rm_end, is_signature_event, is_milestone_end, notes)
                         VALUES
                            (:sectionId, :orderIndex, :startName, :endName, :distNm, :lockCount, NULL, NULL, 0, 0, :notes)",
                        {
                            sectionId = { value=newSectionId, cfsqltype="cf_sql_integer" },
                            orderIndex = { value=i, cfsqltype="cf_sql_integer" },
                            startName = { value=trim(toString(leg.start_name)), cfsqltype="cf_sql_varchar" },
                            endName = { value=trim(toString(leg.end_name)), cfsqltype="cf_sql_varchar" },
                            distNm = { value=distBind.value, cfsqltype="cf_sql_decimal", null=distBind.isNull },
                            lockCount = { value=lockBind.value, cfsqltype="cf_sql_integer", null=lockBind.isNull },
                            notes = { value=notesBind.value, cfsqltype="cf_sql_varchar", null=notesBind.isNull }
                        },
                        { datasource = application.dsn }
                    );
                }

                queryExecute(
                    "INSERT INTO user_route_progress (user_id, segment_id, status, completed_at)
                     SELECT :uid, s.id, 'NOT_STARTED', NULL
                     FROM loop_segments s
                     INNER JOIN loop_sections sec ON sec.id = s.section_id
                     WHERE sec.route_id = :rid",
                    {
                        uid = { value=arguments.userId, cfsqltype="cf_sql_integer" },
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
