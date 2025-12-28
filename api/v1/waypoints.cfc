<cfcomponent output="false">

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfargument name="limit" type="any" required="false">
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

            <!-- Optional limit parameter -->
            <cfset waypointLimit = 100>

            <cfif structKeyExists(arguments, "limit") AND isNumeric(arguments.limit)>
                <cfset waypointLimit = val(arguments.limit)>
            <cfelseif structKeyExists(url, "limit") AND isNumeric(url.limit)>
                <cfset waypointLimit = val(url.limit)>
            <cfelseif structKeyExists(body, "limit") AND isNumeric(body.limit)>
                <cfset waypointLimit = val(body.limit)>
            </cfif>

            <cfif waypointLimit LTE 0><cfset waypointLimit = 100></cfif>
            <cfif waypointLimit GT 250><cfset waypointLimit = 250></cfif>

            <!-- Load waypoints for this user -->
            <cfquery name="qWaypoints" datasource="fpw">
                SELECT wpId, name, latitude, longitude, notes
                FROM waypoints
                WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                ORDER BY name ASC
                LIMIT #waypointLimit#
            </cfquery>

            <cfset waypoints = []>

            <cfloop query="qWaypoints">
                <cfset waypointStruct = {
                    WAYPOINTID   = qWaypoints.wpId,
                    WAYPOINTNAME = qWaypoints.name,
                    LATITUDE     = qWaypoints.latitude,
                    LONGITUDE    = qWaypoints.longitude,
                    NOTES        = qWaypoints.notes
                }>
                <cfset arrayAppend(waypoints, waypointStruct)>
            </cfloop>

            <cfset response = {
                SUCCESS = true,
                AUTH    = true,
                COUNT   = arrayLen(waypoints),
                WAYPOINTS = waypoints
            }>

            <cfoutput>#serializeJSON(response)#</cfoutput>

            <cfcatch type="any">
                <cfset errResponse = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "SERVER_ERROR",
                    MESSAGE = "Waypoints API error.",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

</cfcomponent>
