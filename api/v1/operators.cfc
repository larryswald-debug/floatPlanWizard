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
            <cfset operatorLimit = 100>

            <cfif structKeyExists(arguments, "limit") AND isNumeric(arguments.limit)>
                <cfset operatorLimit = val(arguments.limit)>
            <cfelseif structKeyExists(url, "limit") AND isNumeric(url.limit)>
                <cfset operatorLimit = val(url.limit)>
            <cfelseif structKeyExists(body, "limit") AND isNumeric(body.limit)>
                <cfset operatorLimit = val(body.limit)>
            </cfif>

            <cfif operatorLimit LTE 0><cfset operatorLimit = 100></cfif>
            <cfif operatorLimit GT 250><cfset operatorLimit = 250></cfif>

            <!-- Load operators for this user -->
            <cfquery name="qOperators" datasource="fpw">
                SELECT opId, name, homePhone, notes
                FROM operators
                WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                ORDER BY name ASC
                LIMIT #operatorLimit#
            </cfquery>

            <cfset operators = []>

            <cfloop query="qOperators">
                <cfset operatorStruct = {
                    OPERATORID   = qOperators.opId,
                    OPERATORNAME = qOperators.name,
                    PHONE        = qOperators.homePhone,
                    NOTES        = qOperators.notes
                }>
                <cfset arrayAppend(operators, operatorStruct)>
            </cfloop>

            <cfset response = {
                SUCCESS = true,
                AUTH    = true,
                COUNT   = arrayLen(operators),
                OPERATORS = operators
            }>

            <cfoutput>#serializeJSON(response)#</cfoutput>

            <cfcatch type="any">
                <cfset errResponse = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "SERVER_ERROR",
                    MESSAGE = "Operators API error.",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

</cfcomponent>
