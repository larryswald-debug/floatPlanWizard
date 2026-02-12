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

            <cfelseif act EQ "listuserroutes">
                <cfset var listed = listUserRoutes(userId) />
                <cfoutput>#serializeJSON(listed)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "listcanonicallocations">
                <cfset var canonicalDirection = pickArg(body, "direction", "direction", "CCW") />
                <cfset var canonical = listCanonicalLocations(canonicalDirection) />
                <cfoutput>#serializeJSON(canonical)#</cfoutput>
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
            var shortCode = "USER_ROUTE_" & int(arguments.userId) & "_" & dateTimeFormat(now(), "yyyymmddHHnnss");
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

            if (arrayLen(selectedSegmentRows) EQ 0) {
                return {
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Unable to build route range from selected start/end",
                    "ERROR"={"MESSAGE"="Could not resolve a valid contiguous route range from your selected start and end locations."}
                };
            }

            var newRouteId = 0;
            var sectionMap = {};
            var templateSectionInfoById = {};
            var segmentMap = {};
            var sectionFirstRouteOrder = {};
            var selectedSegIdx = 0;
            var sectionIdForOrder = "";
            for (selectedSegIdx = 1; selectedSegIdx LTE arrayLen(selectedSegmentRows); selectedSegIdx++) {
                sectionIdForOrder = toString(selectedSegmentRows[selectedSegIdx].SECTION_ID);
                if (!structKeyExists(sectionFirstRouteOrder, sectionIdForOrder)) {
                    sectionFirstRouteOrder[sectionIdForOrder] = selectedSegIdx;
                }
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
                var copiedSectionOrder = 0;
                for (i = 1; i LTE qTplSections.recordCount; i++) {
                    var tplSectionId = toString(qTplSections.id[i]);
                    if (!structKeyExists(sectionFirstRouteOrder, tplSectionId)) {
                        continue;
                    }
                    copiedSectionOrder = sectionFirstRouteOrder[tplSectionId];
                    var sectionNameVal = trim(toString(qTplSections.name[i]));
                    var sectionSlugVal = trim(toString(qTplSections.slug[i]));
                    if (!len(sectionSlugVal)) {
                        sectionSlugVal = lCase(reReplace(sectionNameVal, "[^A-Za-z0-9]+", "-", "all"));
                        sectionSlugVal = reReplace(sectionSlugVal, "^-+|-+$", "", "all");
                    }
                    if (!len(sectionSlugVal)) {
                        sectionSlugVal = "section-" & i;
                    }
                    var sectionShortCodeVal = trim(toString(qTplSections.short_code[i]));
                    if (!len(sectionShortCodeVal)) {
                        sectionShortCodeVal = uCase(reReplace(sectionSlugVal, "[^A-Za-z0-9]+", "_", "all"));
                    }
                    queryExecute(
                        "INSERT INTO loop_sections (route_id, name, slug, short_code, phase_num, order_index, is_active_default)
                         VALUES (:rid, :name, :slug, :scode, :phaseNum, :orderIndex, :isActive)",
                        {
                            rid = { value=newRouteId, cfsqltype="cf_sql_integer" },
                            name = { value=sectionNameVal, cfsqltype="cf_sql_varchar", null = false },
                            slug = { value=sectionSlugVal, cfsqltype="cf_sql_varchar", null = false },
                            scode = { value=sectionShortCodeVal, cfsqltype="cf_sql_varchar", null = false },
                            phaseNum = { value=qTplSections.phase_num[i], cfsqltype="cf_sql_integer", null = isNull(qTplSections.phase_num[i]) },
                            orderIndex = { value=copiedSectionOrder, cfsqltype="cf_sql_integer" },
                            isActive = { value=(qTplSections.is_active_default[i] EQ 1 ? 1 : 0), cfsqltype="cf_sql_integer" }
                        },
                        { datasource = application.dsn, result = "secIns" }
                    );
                    sectionMap[tplSectionId] = val(secIns.generatedKey);
                    templateSectionInfoById[tplSectionId] = {
                        "NAME"=(isNull(qTplSections.name[i]) ? "" : qTplSections.name[i]),
                        "SHORT_CODE"=(isNull(qTplSections.short_code[i]) ? "" : qTplSections.short_code[i])
                    };
                }

                var segRow = {};
                var localOrderIndex = 0;
                for (i = 1; i LTE arrayLen(selectedSegmentRows); i++) {
                    segRow = selectedSegmentRows[i];
                    var oldSecId = toString(segRow.SECTION_ID);
                    var distNmBind = toNullableNumber(segRow.DIST_NM, "numeric");
                    var lockCountBind = toNullableNumber(segRow.LOCK_COUNT, "integer");
                    var rmStartBind = toNullableNumber(segRow.RM_START, "numeric");
                    var rmEndBind = toNullableNumber(segRow.RM_END, "numeric");
                    var startNameVal = trim(toString(segRow.START_NAME));
                    var endNameVal = trim(toString(segRow.END_NAME));
                    if (!structKeyExists(sectionMap, oldSecId)) {
                        continue;
                    }
                    localOrderIndex = i;
                    if (!len(startNameVal)) {
                        startNameVal = "Unknown Start";
                    }
                    if (!len(endNameVal)) {
                        endNameVal = "Unknown End";
                    }
                    var sectionInfo = (structKeyExists(templateSectionInfoById, oldSecId) ? templateSectionInfoById[oldSecId] : {"NAME"="", "SHORT_CODE"=""});
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
                            sectionId = { value=sectionMap[oldSecId], cfsqltype="cf_sql_integer" },
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
            "SELECT id, section_id, order_index, start_name, end_name, dist_nm, lock_count,
                    rm_start, rm_end, is_signature_event, is_milestone_end, notes
             FROM loop_segments
             WHERE section_id IN (
                SELECT id FROM loop_sections WHERE route_id = :rid
             )
             ORDER BY section_id ASC, order_index ASC",
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
