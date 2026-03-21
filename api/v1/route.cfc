<!--- /fpw/api/v1/route.cfc --->
<cfcomponent output="false">

    <!--- FPW Route Engine API (v1)
          - getTimeline: returns sections + segments + user progress + rollups
          - completeSegment: temporary/manual completion for testing only
          - resetProgress: optional helper to clear progress for a user (admin/testing)
    --->

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfargument name="action" type="string" required="false" default="getTimeline">
        <cfargument name="routeCode" type="string" required="false" default="GREAT_LOOP_CCW">
        <cfargument name="segmentId" type="numeric" required="false" default="0">

        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

        <cftry>
            <!--- Auth: reuse FPW session user pattern --->
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

            <cfset var act = lCase(trim(arguments.action)) />

            <cfif act EQ "gettimeline">
                <cfset var payload = getTimeline(userId, arguments.routeCode) />
                <cfoutput>#serializeJSON(payload)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "completesegment">
                <cfif arguments.segmentId LTE 0>
                    <cfoutput>#serializeJSON({
                        "SUCCESS"=false,
                        "AUTH"=true,
                        "MESSAGE"="segmentId required",
                        "ERROR"={"MESSAGE"="segmentId must be > 0"}
                    })#</cfoutput>
                    <cfreturn>
                </cfif>

                <cfset var result = completeSegment(userId, arguments.segmentId) />
                <cfoutput>#serializeJSON(result)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "resetprogress">
                <!--- Optional testing helper --->
                <cfset var result2 = resetProgress(userId, arguments.routeCode) />
                <cfoutput>#serializeJSON(result2)#</cfoutput>
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


    <!--- =========================
          Timeline / Route loader
         ========================= --->
    <cffunction name="getTimeline" access="public" returntype="struct" output="false">
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

        <!--- 1) Load route --->
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

        <!--- 2) Prefer normalized route-instance timeline for this user/route --->
        <cfset var qInstance = queryExecute(
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
        ) />

        <cfset var usingNormalized = (qInstance.recordCount GT 0) />
        <cfset var routeInstanceId = (usingNormalized ? val(qInstance.id[1]) : 0) />
        <cfset var qSections = queryNew("") />
        <cfset var qSegments = queryNew("") />
        <cfset var qProg = queryNew("") />

        <cfif usingNormalized>
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
                    routeInstanceId = { value=routeInstanceId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            ) />

            <cfset qSegments = queryExecute(
                "SELECT
                    COALESCE(ril.source_loop_segment_id, ril.segment_id, ril.id) AS id,
                    COALESCE(ris.id, 1) AS section_id,
                    ril.leg_order AS order_index,
                    ril.start_name,
                    ril.end_name,
                    COALESCE(ril.base_dist_nm, 0) AS dist_nm,
                    COALESCE(ril.lock_count, 0) AS lock_count,
                    NULL AS rm_start,
                    NULL AS rm_end,
                    0 AS is_signature_event,
                    0 AS is_milestone_end,
                    COALESCE(ril.notes, '') AS notes,
                    ril.leg_order AS progress_key
                 FROM route_instance_legs ril
                 LEFT JOIN route_instance_sections ris ON ris.id = ril.route_instance_section_id
                 WHERE ril.route_instance_id = :routeInstanceId
                 ORDER BY COALESCE(ris.section_order, 1) ASC, ril.leg_order ASC, ril.id ASC",
                {
                    routeInstanceId = { value=routeInstanceId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            ) />

            <cfset qProg = queryExecute(
                "SELECT leg_order, status, completed_at
                 FROM route_instance_leg_progress
                 WHERE route_instance_id = :routeInstanceId
                   AND user_id = :uid
                 ORDER BY leg_order ASC",
                {
                    routeInstanceId = { value=routeInstanceId, cfsqltype="cf_sql_integer" },
                    uid = { value=arguments.userId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            ) />
        <cfelse>
            <!--- Fallback to template segments directly from segment_library --->
            <cfset qSections = queryExecute(
                "SELECT
                    1 AS id,
                    'Route' AS name,
                    '' AS short_code,
                    1 AS phase_num,
                    1 AS order_index,
                    1 AS is_active_default",
                {},
                { datasource = application.dsn }
            ) />

            <cfset qSegments = queryExecute(
                "SELECT
                    sl.id AS id,
                    1 AS section_id,
                    rts.order_index AS order_index,
                    COALESCE(NULLIF(TRIM(p1.name), ''), TRIM(sl.start_port_name), '') AS start_name,
                    COALESCE(NULLIF(TRIM(p2.name), ''), TRIM(sl.end_port_name), '') AS end_name,
                    COALESCE(sl.dist_nm, 0) AS dist_nm,
                    COALESCE(sl.lock_count, 0) AS lock_count,
                    NULL AS rm_start,
                    NULL AS rm_end,
                    0 AS is_signature_event,
                    0 AS is_milestone_end,
                    COALESCE(sl.notes, '') AS notes,
                    sl.id AS progress_key
                 FROM route_template_segments rts
                 INNER JOIN segment_library sl ON sl.id = rts.segment_id
                 LEFT JOIN ports p1 ON p1.id = sl.start_port_id
                 LEFT JOIN ports p2 ON p2.id = sl.end_port_id
                 WHERE rts.route_id = :rid
                 ORDER BY rts.order_index ASC, rts.id ASC",
                { rid = { value=routeId, cfsqltype="cf_sql_integer" } },
                { datasource = application.dsn }
            ) />

            <cfset qProg = queryExecute(
                "SELECT segment_id, status, completed_at
                 FROM user_route_progress
                 WHERE user_id = :uid
                   AND segment_id IN (
                       SELECT rts.segment_id
                       FROM route_template_segments rts
                       WHERE rts.route_id = :rid
                   )",
                {
                    uid = { value=arguments.userId, cfsqltype="cf_sql_integer" },
                    rid = { value=routeId, cfsqltype="cf_sql_integer" }
                },
                { datasource = application.dsn }
            ) />
        </cfif>

        <!--- Build progress lookup --->
        <cfset var progressByKey = {} />
        <cfset var i = 0 />
        <cfif usingNormalized>
            <cfloop query="qProg">
                <cfset progressByKey[toString(qProg.leg_order)] = {
                    "STATUS"=qProg.status,
                    "COMPLETED_AT"=(isNull(qProg.completed_at) ? "" : dateTimeFormat(qProg.completed_at, "yyyy-mm-dd HH:nn:ss"))
                } />
            </cfloop>
        <cfelse>
            <cfloop query="qProg">
                <cfset progressByKey[toString(qProg.segment_id)] = {
                    "STATUS"=qProg.status,
                    "COMPLETED_AT"=(isNull(qProg.completed_at) ? "" : dateTimeFormat(qProg.completed_at, "yyyy-mm-dd HH:nn:ss"))
                } />
            </cfloop>
        </cfif>

        <!--- Rollup totals --->
        <cfset var totalNm = 0.0 />
        <cfset var totalLocks = 0 />
        <cfset var completedNm = 0.0 />
        <cfset var completedLocks = 0 />

        <!--- Prepare section buckets --->
        <cfset var sections = [] />
        <cfset var sectionIndexById = {} />
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
        <cfif arrayLen(sections) EQ 0>
            <cfset arrayAppend(sections, {
                "ID"=1,
                "NAME"="Route",
                "SHORT_CODE"="",
                "PHASE_NUM"=1,
                "ORDER_INDEX"=1,
                "IS_ACTIVE_DEFAULT"=true,
                "TOTALS"={
                    "NM"=0.0,
                    "LOCKS"=0,
                    "COMPLETED_NM"=0.0,
                    "COMPLETED_LOCKS"=0,
                    "PCT_COMPLETE"=0
                },
                "SEGMENTS"=[]
            }) />
            <cfset sectionIndexById["1"] = 1 />
        </cfif>

        <!--- Attach segments to sections and compute totals --->
        <cfloop query="qSegments">
            <cfset var sid = toString(qSegments.section_id) />
            <cfif NOT structKeyExists(sectionIndexById, sid)>
                <cfset sid = "1" />
            </cfif>

            <cfset var idx = sectionIndexById[sid] />
            <cfset var progressKey = toString(qSegments.progress_key) />
            <cfset var prog = (structKeyExists(progressByKey, progressKey) ? progressByKey[progressKey] : {"STATUS"="NOT_STARTED","COMPLETED_AT"=""}) />
            <cfset var isCompleted = (uCase(prog.STATUS) EQ "COMPLETED") />

            <cfset var segObj = {
                "ID"=qSegments.id,
                "ORDER_INDEX"=qSegments.order_index,
                "START_NAME"=qSegments.start_name,
                "END_NAME"=qSegments.end_name,
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

        <cfset var s = 0 />
        <cfset var filteredSections = [] />
        <cfloop from="1" to="#arrayLen(sections)#" index="s">
            <cfif sections[s].TOTALS.NM GT 0>
                <cfset sections[s].TOTALS.PCT_COMPLETE = round((sections[s].TOTALS.COMPLETED_NM / sections[s].TOTALS.NM) * 100) />
            <cfelse>
                <cfset sections[s].TOTALS.PCT_COMPLETE = 0 />
            </cfif>
            <cfif arrayLen(sections[s].SEGMENTS) GT 0>
                <cfset arrayAppend(filteredSections, sections[s]) />
            </cfif>
        </cfloop>

        <cfif arrayLen(filteredSections) GT 0>
            <cfset var hasDefaultSection = false />
            <cfloop from="1" to="#arrayLen(filteredSections)#" index="s">
                <cfif filteredSections[s].IS_ACTIVE_DEFAULT>
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


    <!--- =========================
          TEMP: mark segment complete
         ========================= --->
    <cffunction name="completeSegment" access="remote" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="segmentId" type="numeric" required="true">

        <cfset var routeSegCompleteRes = {} />
        <cfset queryExecute(
            "UPDATE route_instance_leg_progress rilp
             INNER JOIN route_instance_legs ril
                ON ril.route_instance_id = rilp.route_instance_id
               AND ril.leg_order = rilp.leg_order
             INNER JOIN route_instances ri
                ON ri.id = ril.route_instance_id
             SET
                rilp.status = 'COMPLETED',
                rilp.completed_at = NOW()
             WHERE rilp.user_id = :uid
               AND ri.user_id = :uidText
               AND (
                    ril.segment_id = :sid
                    OR COALESCE(ril.source_loop_segment_id, ril.id) = :sid
               )",
            {
                uid = { value=arguments.userId, cfsqltype="cf_sql_integer" },
                uidText = { value=toString(arguments.userId), cfsqltype="cf_sql_varchar" },
                sid = { value=arguments.segmentId, cfsqltype="cf_sql_integer" }
            },
            { datasource = application.dsn, result = "routeSegCompleteRes" }
        ) />

        <cfset var rowsTouched = (structKeyExists(routeSegCompleteRes, "recordCount") ? val(routeSegCompleteRes.recordCount) : 0) />

        <cfreturn {
            "SUCCESS"=(rowsTouched GT 0),
            "AUTH"=true,
            "MESSAGE"=(rowsTouched GT 0 ? "Segment marked complete" : "No matching route leg progress row found for this segment."),
            "SEGMENT_ID"=arguments.segmentId,
            "UPDATED_ROWS"=rowsTouched
        } />
    </cffunction>


    <!--- Optional testing helper: clear this user's progress for this route --->
    <cffunction name="resetProgress" access="public" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeCode" type="string" required="true">

        <cfset var qRoute = queryExecute(
            "SELECT id FROM loop_routes WHERE short_code=:code LIMIT 1",
            { code = { value=arguments.routeCode, cfsqltype="cf_sql_varchar" } },
            { datasource = application.dsn }
        ) />

        <cfif qRoute.recordCount EQ 0>
            <cfreturn {"SUCCESS"=false,"AUTH"=true,"MESSAGE"="Route not found"} />
        </cfif>

        <cfset var routeResetRes = {} />
        <cfset queryExecute(
            "UPDATE route_instance_leg_progress rilp
             INNER JOIN route_instances ri ON ri.id = rilp.route_instance_id
             SET
                rilp.status = 'NOT_STARTED',
                rilp.completed_at = NULL
             WHERE rilp.user_id = :uid
               AND ri.user_id = :uidText
               AND ri.generated_route_id = :rid",
            {
                uid = { value=arguments.userId, cfsqltype="cf_sql_integer" },
                uidText = { value=toString(arguments.userId), cfsqltype="cf_sql_varchar" },
                rid = { value=qRoute.id[1], cfsqltype="cf_sql_integer" }
            },
            { datasource = application.dsn, result = "routeResetRes" }
        ) />

        <cfreturn {
            "SUCCESS"=true,
            "AUTH"=true,
            "MESSAGE"="Progress reset",
            "UPDATED_ROWS"=(structKeyExists(routeResetRes, "recordCount") ? val(routeResetRes.recordCount) : 0)
        } />
    </cffunction>


    <!--- =========================
          Helpers
         ========================= --->
    <cffunction name="resolveUserId" access="private" returntype="numeric" output="false">
        <cfargument name="userStruct" type="any" required="true">
        <cfset var uid = 0 />

        <cfif isStruct(arguments.userStruct)>
            <!--- Common FPW variants --->
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

    <cffunction name="roundTo2" access="private" returntype="numeric" output="false">
        <cfargument name="n" type="numeric" required="true">
        <cfreturn (round(arguments.n * 100) / 100) />
    </cffunction>

</cfcomponent>
