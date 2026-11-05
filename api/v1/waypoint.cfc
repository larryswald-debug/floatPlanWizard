<cfcomponent output="false">

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfargument name="action" type="string" required="false" default="">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

        <cftry>

            <!-- Require authenticated session -->
            <cfif NOT structKeyExists(session, "user") OR NOT isStruct(session.user)>
                <cfset response = {
                    SUCCESS = false,
                    AUTH    = false,
                    ERROR   = "NOT_LOGGED_IN",
                    MESSAGE = "Not logged in."
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfreturn>
            </cfif>

            <!-- Resolve userId from session -->
            <cfset userId = 0>
            <cfif structKeyExists(session.user, "userId")>
                <cfset userId = session.user.userId>
            <cfelseif structKeyExists(session.user, "id")>
                <cfset userId = session.user.id>
            <cfelseif structKeyExists(session.user, "USERID")>
                <cfset userId = session.user.USERID>
            </cfif>

            <cfif NOT isNumeric(userId) OR userId LTE 0>
                <cfset response = {
                    SUCCESS = false,
                    AUTH    = false,
                    ERROR   = "INVALID_SESSION",
                    MESSAGE = "Session user is invalid."
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfreturn>
            </cfif>

            <!-- Optional JSON body -->
            <cfset httpData = getHttpRequestData()>
            <cfset rawBody  = toString(httpData.content)>
            <cfset body     = {}>

            <cfif len(trim(rawBody))>
                <cftry>
                    <cfset body = deserializeJSON(rawBody, false)>
                <cfcatch>
                    <cfset body = {}>
                </cfcatch>
                </cftry>
            </cfif>

            <cfset action = "">
            <cfif len(trim(arguments.action))>
                <cfset action = lcase(trim(arguments.action))>
            <cfelseif structKeyExists(url, "action")>
                <cfset action = lcase(trim(url.action))>
            <cfelseif structKeyExists(body, "action")>
                <cfset action = lcase(trim(body.action))>
            </cfif>

            <!--- Only the new two-stop action uses the existing session CSRF guard. --->
            <cfif action EQ "savelegstops">
                <cfif NOT isStruct(body)>
                    <cfheader statuscode="400">
                    <cfoutput>#serializeJSON({SUCCESS=false, AUTH=true, ERROR="VALIDATION", RESULT="error", MESSAGE="Select a Great Loop leg and try again."})#</cfoutput>
                    <cfreturn>
                </cfif>
                <cfset local.guard = new fpw.api.v1.AuthRequestGuardService()>
                <cfset local.mutation = local.guard.validateMutation(body)>
                <cfif NOT local.mutation.ALLOWED>
                    <cfheader statuscode="#local.mutation.STATUSCODE#">
                    <cfoutput>#serializeJSON({SUCCESS=false, AUTH=true, ERROR=local.mutation.CODE, RESULT="error", MESSAGE=local.mutation.MESSAGE})#</cfoutput>
                    <cfreturn>
                </cfif>
                <cfset local.valid = listFirst(cgi.content_type, ";") EQ "application/json">
                <cfloop collection="#body#" item="local.inputKey">
                    <cfif NOT listFindNoCase("action,templateCode,legOrder,segmentId,csrfToken",local.inputKey)><cfset local.valid=false></cfif>
                </cfloop>
                <cfloop list="templateCode,legOrder,segmentId" index="local.inputKey">
                    <cfif NOT structKeyExists(body,local.inputKey) OR NOT isSimpleValue(body[local.inputKey])><cfset local.valid=false></cfif>
                </cfloop>
                <cfif local.valid>
                    <cfset local.valid = reFind("^[1-9][0-9]{0,9}$",toString(body.legOrder)) GT 0
                        AND reFind("^[1-9][0-9]{0,9}$",toString(body.segmentId)) GT 0
                        AND val(body.legOrder) LTE 2147483647 AND val(body.segmentId) LTE 2147483647
                        AND len(trim(toString(body.templateCode))) GT 0 AND len(toString(body.templateCode)) LTE 100>
                </cfif>
                <cfif NOT local.valid>
                    <cfheader statuscode="400">
                    <cfoutput>#serializeJSON({SUCCESS=false, AUTH=true, ERROR="VALIDATION", RESULT="error", MESSAGE="Select a Great Loop leg and try again."})#</cfoutput>
                    <cfreturn>
                </cfif>
                <cftry>
                    <cfset local.sources = new fpw.api.v1.GreatLoopReferenceService().init("fpw").getLegWaypointSources(body.templateCode,body.legOrder,body.segmentId)>
                    <cfif NOT local.sources.eligible>
                        <cfoutput>#serializeJSON({SUCCESS=false, AUTH=true, ERROR="ENDPOINT_UNRESOLVED", RESULT="unresolved", MESSAGE=local.sources.message, ADDED_COUNT=0, EXISTING_COUNT=0})#</cfoutput>
                        <cfreturn>
                    </cfif>
                    <cfset local.result = saveResolvedLegWaypoints(userId, local.sources.endpoints)>
                    <cfset local.result.LEG_ID = val(body.segmentId)>
                    <cfoutput>#serializeJSON(local.result)#</cfoutput>
                    <cfcatch type="any">
                        <cflog file="fpw" type="error" text="FPW_ERROR Great Loop waypoint save: #cfcatch.type#">
                        <cfoutput>#serializeJSON({SUCCESS=false, AUTH=true, ERROR="SERVER_ERROR", RESULT="error", MESSAGE="The stops could not be saved. No new waypoints were added. Please try again.", ADDED_COUNT=0, EXISTING_COUNT=0})#</cfoutput>
                    </cfcatch>
                </cftry>
                <cfreturn>
            </cfif>

            <cfif action EQ "save">
                <cfset waypoint = {}>
                <cfset local.librarySave = structKeyExists(body, "library")>
                <cfset local.alreadySaved = false>
                <cfif local.librarySave>
                    <cfif cgi.request_method NEQ "POST" OR listFirst(cgi.content_type, ";") NEQ "application/json">
                        <cfoutput>#serializeJSON({SUCCESS=false, AUTH=true, ERROR="VALIDATION", MESSAGE="Use the library save button."})#</cfoutput>
                        <cfreturn>
                    </cfif>
                    <!--- Resolve the public source on the server. Ignore any client-supplied waypoint or owner. --->
                    <cfset local.source = new fpw.api.v1.LibraryWaypointService().resolve(body)>
                    <cfif NOT local.source.eligible>
                        <cfoutput>#serializeJSON({SUCCESS=false, AUTH=true, ERROR="INELIGIBLE", MESSAGE=local.source.message})#</cfoutput>
                        <cfreturn>
                    </cfif>
                    <cfset waypoint = local.source.waypoint>
                <cfelseif structKeyExists(body, "waypoint")>
                    <cfset waypoint = body.waypoint>
                <cfelseif structKeyExists(body, "WAYPOINT")>
                    <cfset waypoint = body.WAYPOINT>
                </cfif>

                <cfset waypointId = 0>
                <cfif structKeyExists(waypoint, "WAYPOINTID")>
                    <cfset waypointId = val(waypoint.WAYPOINTID)>
                <cfelseif structKeyExists(waypoint, "waypointId")>
                    <cfset waypointId = val(waypoint.waypointId)>
                </cfif>

                <cfset waypointName = structKeyExists(waypoint, "WAYPOINTNAME") ? trim(waypoint.WAYPOINTNAME) : (structKeyExists(waypoint, "name") ? trim(waypoint.name) : "")>
                <cfif NOT len(waypointName)>
                    <cfthrow message="Name is required.">
                </cfif>
                <cfif len(waypointName) GT 45>
                    <cfset response = {
                        SUCCESS = false,
                        AUTH    = true,
                        ERROR   = "VALIDATION",
                        MESSAGE = "Waypoint name must be 45 characters or fewer."
                    }>
                    <cfoutput>#serializeJSON(response)#</cfoutput>
                    <cfreturn>
                </cfif>

                <cfset latitude = structKeyExists(waypoint, "LATITUDE") ? trim(waypoint.LATITUDE) : (structKeyExists(waypoint, "latitude") ? trim(waypoint.latitude) : "")>
                <cfset longitude = structKeyExists(waypoint, "LONGITUDE") ? trim(waypoint.LONGITUDE) : (structKeyExists(waypoint, "longitude") ? trim(waypoint.longitude) : "")>
                <cfset notes = structKeyExists(waypoint, "NOTES") ? trim(waypoint.NOTES) : (structKeyExists(waypoint, "notes") ? trim(waypoint.notes) : "")>

                <cfset local.savedWaypoint = persistWaypoint(userId, waypointId, waypointName, latitude, longitude, notes,
                    local.librarySave ? local.source : {})>
                <cfset waypointId = local.savedWaypoint.WAYPOINTID>
                <cfset local.alreadySaved = local.savedWaypoint.ALREADY_SAVED>

                <cfset response = {
                    SUCCESS = true,
                    AUTH    = true,
                    WAYPOINTID = waypointId
                }>
                <cfif local.librarySave><cfset response.ALREADY_SAVED = local.alreadySaved></cfif>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfreturn>
            </cfif>

            <cfif action EQ "delete">
                <cfset waypointId = 0>
                <cfif structKeyExists(body, "waypointId")>
                    <cfset waypointId = val(body.waypointId)>
                <cfelseif structKeyExists(body, "WAYPOINTID")>
                    <cfset waypointId = val(body.WAYPOINTID)>
                <cfelseif structKeyExists(url, "waypointId")>
                    <cfset waypointId = val(url.waypointId)>
                </cfif>

                <cfif waypointId LTE 0>
                    <cfthrow message="Waypoint id is required.">
                </cfif>

                <cfquery name="qWaypointUsage" datasource="fpw">
                    SELECT fp.floatPlanName
                    FROM floatplan_waypoints fwp
                    INNER JOIN floatplans fp ON fp.floatplanId = fwp.floatplanId
                    WHERE fwp.waypointId = <cfqueryparam cfsqltype="cf_sql_integer" value="#waypointId#">
                      AND fp.userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                </cfquery>

                <cfif qWaypointUsage.recordCount GT 0>
                    <cfset planNames = []>
                    <cfloop query="qWaypointUsage">
                        <cfset arrayAppend(planNames, qWaypointUsage.floatPlanName)>
                    </cfloop>
                    <cfset planCount = arrayLen(planNames)>
                    <cfset planList = arrayToList(planNames, ", ")>
                    <cfset response = {
                        SUCCESS = false,
                        AUTH    = true,
                        ERROR   = "IN_USE",
                        MESSAGE = "This waypoint is used in " & planCount & " float plan" & (planCount EQ 1 ? "" : "s") & ": " & planList & ". Edit the float plan to remove it before deleting."
                    }>
                    <cfoutput>#serializeJSON(response)#</cfoutput>
                    <cfsetting enablecfoutputonly="false">
                    <cfabort>
                </cfif>

                <cfquery datasource="fpw">
                    DELETE FROM waypoints
                    WHERE wpId = <cfqueryparam cfsqltype="cf_sql_integer" value="#waypointId#">
                      AND userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                </cfquery>

                <cfset response = {
                    SUCCESS = true,
                    AUTH    = true
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfif action EQ "candelete">
                <cfset waypointId = 0>
                <cfif structKeyExists(body, "waypointId")>
                    <cfset waypointId = val(body.waypointId)>
                <cfelseif structKeyExists(body, "WAYPOINTID")>
                    <cfset waypointId = val(body.WAYPOINTID)>
                <cfelseif structKeyExists(url, "waypointId")>
                    <cfset waypointId = val(url.waypointId)>
                </cfif>

                <cfif waypointId LTE 0>
                    <cfthrow message="Waypoint id is required.">
                </cfif>

                <cfquery name="qWaypointUsage" datasource="fpw">
                    SELECT fp.floatPlanName
                    FROM floatplan_waypoints fwp
                    INNER JOIN floatplans fp ON fp.floatplanId = fwp.floatplanId
                    WHERE fwp.waypointId = <cfqueryparam cfsqltype="cf_sql_integer" value="#waypointId#">
                      AND fp.userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                </cfquery>

                <cfif qWaypointUsage.recordCount GT 0>
                    <cfset planNames = []>
                    <cfloop query="qWaypointUsage">
                        <cfset arrayAppend(planNames, qWaypointUsage.floatPlanName)>
                    </cfloop>
                    <cfset planCount = arrayLen(planNames)>
                    <cfset planList = arrayToList(planNames, ", ")>
                    <cfset response = {
                        SUCCESS = true,
                        AUTH    = true,
                        CANDELETE = false,
                        MESSAGE = "This waypoint is used in " & planCount & " float plan" & (planCount EQ 1 ? "" : "s") & ": " & planList & ". Edit the float plan to remove it before deleting."
                    }>
                <cfelse>
                    <cfset response = {
                        SUCCESS = true,
                        AUTH    = true,
                        CANDELETE = true
                    }>
                </cfif>

                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfset response = {
                SUCCESS = false,
                AUTH    = true,
                ERROR   = "INVALID_ACTION",
                MESSAGE = "Unknown action."
            }>
            <cfoutput>#serializeJSON(response)#</cfoutput>

            <cfcatch type="any">
                <cfif isDefined("action") AND isSimpleValue(action) AND action EQ "savelegstops">
                    <cflog file="fpw" type="error" text="FPW_ERROR Great Loop waypoint request: #cfcatch.type#">
                    <cfoutput>#serializeJSON({SUCCESS=false, AUTH=true, ERROR="SERVER_ERROR", RESULT="error", MESSAGE="The stops could not be saved. Please refresh and try again."})#</cfoutput>
                    <cfreturn>
                </cfif>
                <cfset errResponse = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "SERVER_ERROR",
                    MESSAGE = "Waypoint API error.",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
                <cfreturn>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

    <!--- Nonremote: both callers supply server-validated ownership and source information. --->
    <cffunction name="persistWaypoint" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="waypointId" type="numeric" required="true">
        <cfargument name="waypointName" type="string" required="true">
        <cfargument name="latitude" type="string" required="true">
        <cfargument name="longitude" type="string" required="true">
        <cfargument name="notes" type="string" required="true">
        <cfargument name="source" type="struct" required="false" default="#{}#">
        <cfset local.waypointId = arguments.waypointId>
        <cfset local.source = arguments.source>
        <cfset local.librarySave = NOT structIsEmpty(local.source)>
        <cfset local.alreadySaved = false>
                <cfset local.activityWasCreate = local.waypointId LTE 0>
                <cftransaction>
                    <cfquery name="local.activityOwner" datasource="fpw">
                        SELECT userId FROM users
                        WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                        FOR UPDATE
                    </cfquery>
                    <cfif local.activityOwner.recordCount NEQ 1>
                        <cfthrow type="FPW.MemberActivity.Ownership" message="The saved item is unavailable.">
                    </cfif>
                    <!--- Library replays are serialized by the member row lock already held above. --->
                    <cfif local.librarySave>
                        <cfquery name="local.savedSource" datasource="fpw">
                            SELECT wpId FROM waypoints
                            WHERE userId = <cfqueryparam cfsqltype="cf_sql_varchar" value="#userId#">
                            <cfif local.source.library EQ "port">
                                AND notes = <cfqueryparam cfsqltype="cf_sql_varchar" value="#notes#">
                                AND CAST(latitude AS DECIMAL(18,10)) = <cfqueryparam cfsqltype="cf_sql_decimal" scale="10" value="#latitude#">
                                AND CAST(longitude AS DECIMAL(18,10)) = <cfqueryparam cfsqltype="cf_sql_decimal" scale="10" value="#longitude#">
                            <cfelse>
                                AND LEFT(notes, <cfqueryparam cfsqltype="cf_sql_integer" value="#len(local.source.prefix)#">)
                                    = <cfqueryparam cfsqltype="cf_sql_varchar" value="#local.source.prefix#">
                            </cfif>
                            ORDER BY wpId LIMIT 1 FOR UPDATE
                        </cfquery>
                        <cfif local.savedSource.recordCount>
                            <cfset local.waypointId = local.savedSource.wpId[1]>
                            <cfset local.alreadySaved = true>
                        </cfif>
                    </cfif>
                    <cfif NOT local.alreadySaved>
                    <cfquery name="local.activityBefore" datasource="fpw">
                        SELECT JSON_ARRAY(name,latitude,longitude,notes) AS projection
                        FROM waypoints
                        WHERE wpId = <cfqueryparam cfsqltype="cf_sql_integer" value="#local.waypointId#">
                          AND userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                        FOR UPDATE
                    </cfquery>
                    <cfif NOT local.activityWasCreate AND local.activityBefore.recordCount NEQ 1>
                        <cfthrow type="FPW.MemberActivity.Ownership" message="The saved item is unavailable.">
                    </cfif>
                <cfif local.waypointId GT 0>
                    <cfquery datasource="fpw">
                        UPDATE waypoints
                        SET name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#waypointName#">,
                            latitude = <cfqueryparam cfsqltype="cf_sql_varchar" value="#latitude#">,
                            longitude = <cfqueryparam cfsqltype="cf_sql_varchar" value="#longitude#">,
                            notes = <cfqueryparam cfsqltype="cf_sql_varchar" value="#notes#">
                        WHERE wpId = <cfqueryparam cfsqltype="cf_sql_integer" value="#local.waypointId#">
                          AND userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                    </cfquery>
                <cfelse>
                    <cfset local.insertResult = {}>
                    <cfquery datasource="fpw" result="local.insertResult">
                        INSERT INTO waypoints (userId, name, latitude, longitude, notes)
                        VALUES (
                            <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#waypointName#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#latitude#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#longitude#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#notes#">
                        )
                    </cfquery>
                    <cfif structKeyExists(local.insertResult, "generatedKey")>
                        <cfset local.waypointId = local.insertResult.generatedKey>
                    </cfif>
                </cfif>
                    <cfquery name="local.activityAfter" datasource="fpw">
                        SELECT JSON_ARRAY(name,latitude,longitude,notes) AS projection
                        FROM waypoints
                        WHERE wpId = <cfqueryparam cfsqltype="cf_sql_integer" value="#local.waypointId#">
                          AND userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                        FOR UPDATE
                    </cfquery>
                    <cfif local.activityAfter.recordCount NEQ 1>
                        <cfthrow type="FPW.MemberActivity.Unconfirmed" message="Your change could not be saved.">
                    </cfif>
                    <cfif local.activityWasCreate OR compare(local.activityBefore.projection[1], local.activityAfter.projection[1]) NEQ 0>
                        <cfset getMemberActivityEventService("fpw").recordRequiredMemberActivity(
                            userId, local.activityWasCreate ? "waypoint_created" : "waypoint_updated", local.waypointId
                        )>
                    </cfif>
                    </cfif>
                </cftransaction>
        <cfreturn {WAYPOINTID=local.waypointId, ALREADY_SAVED=local.alreadySaved}>
    </cffunction>

    <cffunction name="saveResolvedLegWaypoints" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="endpoints" type="array" required="true">
        <cfset local.result={SUCCESS=true, AUTH=true, RESULT="added", MESSAGE="", ADDED_COUNT=0, EXISTING_COUNT=0, ENDPOINTS=[]}>
        <!--- The first member lock remains held until both writes and their activity commit. --->
        <cftransaction>
            <cfloop array="#arguments.endpoints#" index="local.endpoint">
                <cfset local.point=local.endpoint.waypoint>
                <cfset local.saved=persistWaypoint(arguments.userId,0,local.point.WAYPOINTNAME,
                    local.point.LATITUDE,local.point.LONGITUDE,local.point.NOTES,local.endpoint)>
                <cfset arrayAppend(local.result.ENDPOINTS,{NAME=local.endpoint.endpointName,
                    STATUS=local.saved.ALREADY_SAVED ? "already_exists" : "added", WAYPOINTID=local.saved.WAYPOINTID})>
                <cfif local.saved.ALREADY_SAVED><cfset local.result.EXISTING_COUNT++><cfelse><cfset local.result.ADDED_COUNT++></cfif>
            </cfloop>
        </cftransaction>
        <cfif local.result.ADDED_COUNT EQ 0>
            <cfset local.result.RESULT="already_exists">
            <cfset local.result.MESSAGE="Both locations are already in My Waypoints.">
        <cfelseif local.result.EXISTING_COUNT EQ 0>
            <cfset local.result.MESSAGE=local.result.ENDPOINTS[1].NAME & " and " & local.result.ENDPOINTS[2].NAME & " have been added to My Waypoints. You can now use them when building your route.">
        <cfelse>
            <cfset local.result.RESULT="mixed">
            <cfloop array="#local.result.ENDPOINTS#" index="local.endpoint">
                <cfset local.result.MESSAGE &= (len(local.result.MESSAGE) ? " " : "") & local.endpoint.NAME & (local.endpoint.STATUS EQ "added" ? " was added." : " was already in My Waypoints.")>
            </cfloop>
        </cfif>
        <cfreturn local.result>
    </cffunction>

    <cffunction name="getMemberActivityEventService" access="private" returntype="any" output="false">
        <cfargument name="datasource" type="string" required="true">
        <cfreturn createObject("component","fpw.includes.ProductEventService").init(arguments.datasource)>
    </cffunction>
</cfcomponent>
