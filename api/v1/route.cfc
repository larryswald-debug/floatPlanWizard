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

        <!--- 2) Load sections ordered --->
        <cfset var qSections = queryExecute(
            "SELECT id, name, short_code, phase_num, order_index, is_active_default
             FROM loop_sections
             WHERE route_id = :rid
             ORDER BY order_index ASC",
            { rid = { value=routeId, cfsqltype="cf_sql_integer" } },
            { datasource = application.dsn }
        ) />

        <!--- 3) Load segments ordered (all) --->
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

        <!--- 4) Load user progress for these segments --->
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

        <!--- Build a quick lookup struct: segmentId -> progress --->
        <cfset var progressBySeg = {} />
        <cfset var i = 0 />
        <cfloop query="qProg">
            <cfset progressBySeg[ toString(qProg.segment_id) ] = {
                "STATUS"=qProg.status,
                "COMPLETED_AT"=(isNull(qProg.completed_at) ? "" : dateTimeFormat(qProg.completed_at, "yyyy-mm-dd HH:nn:ss"))
            } />
        </cfloop>

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
            <cfset sectionIndexById[ toString(qSections.id) ] = arrayLen(sections) />
        </cfloop>

        <!--- Attach segments to sections and compute totals --->
        <cfloop query="qSegments">
            <cfset var sid = toString(qSegments.section_id) />
            <cfif NOT structKeyExists(sectionIndexById, sid)>
                <!--- Should never happen, but guard anyway --->
                <cfcontinue />
            </cfif>

            <cfset var idx = sectionIndexById[sid] />
            <cfset var segIdStr = toString(qSegments.id) />
            <cfset var prog = (structKeyExists(progressBySeg, segIdStr) ? progressBySeg[segIdStr] : {"STATUS"="NOT_STARTED","COMPLETED_AT"=""}) />
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

            <!--- Totals --->
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

        <!--- Compute section PCT and filter empty sections --->
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

        <!--- Upsert progress row --->
        <cfset queryExecute(
            "INSERT INTO user_route_progress (user_id, segment_id, status, completed_at)
             VALUES (:uid, :sid, 'COMPLETED', NOW())
             ON DUPLICATE KEY UPDATE status='COMPLETED', completed_at=NOW()",
            {
                uid = { value=arguments.userId, cfsqltype="cf_sql_integer" },
                sid = { value=arguments.segmentId, cfsqltype="cf_sql_integer" }
            },
            { datasource = application.dsn }
        ) />

        <cfreturn {
            "SUCCESS"=true,
            "AUTH"=true,
            "MESSAGE"="Segment marked complete",
            "SEGMENT_ID"=arguments.segmentId
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

        <cfset queryExecute(
            "DELETE urp
             FROM user_route_progress urp
             JOIN loop_segments s ON s.id = urp.segment_id
             JOIN loop_sections sec ON sec.id = s.section_id
             WHERE urp.user_id = :uid
               AND sec.route_id = :rid",
            {
                uid = { value=arguments.userId, cfsqltype="cf_sql_integer" },
                rid = { value=qRoute.id[1], cfsqltype="cf_sql_integer" }
            },
            { datasource = application.dsn }
        ) />

        <cfreturn {"SUCCESS"=true,"AUTH"=true,"MESSAGE"="Progress reset"} />
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
