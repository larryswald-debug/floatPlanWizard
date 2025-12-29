<cfcomponent output="false">

    <cffunction name="handle" access="remote" returntype="void" output="true">
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
                <cfsetting enablecfoutputonly="false">
                <cfabort>
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
                <cfsetting enablecfoutputonly="false">
                <cfabort>
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
            <cfif structKeyExists(url, "action")>
                <cfset action = lcase(trim(url.action))>
            <cfelseif structKeyExists(body, "action")>
                <cfset action = lcase(trim(body.action))>
            </cfif>

            <cfif action EQ "save">
                <cfset waypoint = {}>
                <cfif structKeyExists(body, "waypoint")>
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

                <cfset latitude = structKeyExists(waypoint, "LATITUDE") ? trim(waypoint.LATITUDE) : (structKeyExists(waypoint, "latitude") ? trim(waypoint.latitude) : "")>
                <cfset longitude = structKeyExists(waypoint, "LONGITUDE") ? trim(waypoint.LONGITUDE) : (structKeyExists(waypoint, "longitude") ? trim(waypoint.longitude) : "")>
                <cfset notes = structKeyExists(waypoint, "NOTES") ? trim(waypoint.NOTES) : (structKeyExists(waypoint, "notes") ? trim(waypoint.notes) : "")>

                <cfif waypointId GT 0>
                    <cfquery datasource="fpw">
                        UPDATE waypoints
                        SET name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#waypointName#">,
                            latitude = <cfqueryparam cfsqltype="cf_sql_varchar" value="#latitude#">,
                            longitude = <cfqueryparam cfsqltype="cf_sql_varchar" value="#longitude#">,
                            notes = <cfqueryparam cfsqltype="cf_sql_varchar" value="#notes#">
                        WHERE wpId = <cfqueryparam cfsqltype="cf_sql_integer" value="#waypointId#">
                          AND userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                    </cfquery>
                <cfelse>
                    <cfset insertResult = {}>
                    <cfquery datasource="fpw" result="insertResult">
                        INSERT INTO waypoints (userId, name, latitude, longitude, notes)
                        VALUES (
                            <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#waypointName#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#latitude#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#longitude#">,
                            <cfqueryparam cfsqltype="cf_sql_varchar" value="#notes#">
                        )
                    </cfquery>
                    <cfif structKeyExists(insertResult, "generatedKey")>
                        <cfset waypointId = insertResult.generatedKey>
                    </cfif>
                </cfif>

                <cfset response = {
                    SUCCESS = true,
                    AUTH    = true,
                    WAYPOINTID = waypointId
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
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
                <cfset errResponse = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "SERVER_ERROR",
                    MESSAGE = "Waypoint API error.",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

</cfcomponent>
