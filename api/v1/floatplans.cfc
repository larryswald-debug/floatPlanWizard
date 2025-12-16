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
            <cfset planLimit = 5>

            <cfif structKeyExists(arguments, "limit") AND isNumeric(arguments.limit)>
                <cfset planLimit = val(arguments.limit)>
            <cfelseif structKeyExists(url, "limit") AND isNumeric(url.limit)>
                <cfset planLimit = val(url.limit)>
            <cfelseif structKeyExists(body, "limit") AND isNumeric(body.limit)>
                <cfset planLimit = val(body.limit)>
            </cfif>

            <cfif planLimit LTE 0><cfset planLimit = 5></cfif>
            <cfif planLimit GT 20><cfset planLimit = 20></cfif>

            <!-- Load float plans for this user -->
            <cfquery name="qPlans" datasource="fpw">
                SELECT
                    fp.floatplanId,
                    fp.userId,
                    fp.floatPlanName,
                    fp.status,
                    fp.departureTime,
                    fp.returnTime,
                    fp.vesselId,
                    fp.dateCreated,
                    fp.lastUpdate,
                    v.vesselName,
                    (
                        SELECT COUNT(*)
                        FROM floatplan_waypoints fwp
                        WHERE fwp.floatplanId = fp.floatplanId
                    ) AS waypointCount
                FROM floatplans fp
                LEFT JOIN vessels v ON fp.vesselId = v.vesselId
                WHERE fp.userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                ORDER BY
                    COALESCE(fp.lastUpdate, fp.dateCreated) DESC,
                    fp.floatplanId DESC
                LIMIT #planLimit#
            </cfquery>

            <cfset plans = []>

            <cfloop query="qPlans">
                <cfset planStruct = {
                    FLOATPLANID    = qPlans.floatplanId,
                    USERID         = qPlans.userId,
                    PLANNAME       = qPlans.floatPlanName,
                    STATUS         = qPlans.status,
                    DEPARTDATETIME = qPlans.departureTime,
                    RETURNDATETIME = qPlans.returnTime,
                    VESSELID       = qPlans.vesselId,
                    VESSELNAME     = qPlans.vesselName,
                    CREATEDDATE    = qPlans.dateCreated,
                    UPDATEDDATE    = qPlans.lastUpdate,
                    WAYPOINTCOUNT  = qPlans.waypointCount
                }>
                <cfset arrayAppend(plans, planStruct)>
            </cfloop>

            <cfset response = {
                SUCCESS = true,
                AUTH    = true,
                COUNT   = arrayLen(plans),
                PLANS   = plans
            }>

            <cfoutput>#serializeJSON(response)#</cfoutput>

            <cfcatch type="any">
                <cfset errResponse = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "SERVER_ERROR",
                    MESSAGE = "Float plans API error.",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

</cfcomponent>
