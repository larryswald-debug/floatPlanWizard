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
            <cfset contactLimit = 100>

            <cfif structKeyExists(arguments, "limit") AND isNumeric(arguments.limit)>
                <cfset contactLimit = val(arguments.limit)>
            <cfelseif structKeyExists(url, "limit") AND isNumeric(url.limit)>
                <cfset contactLimit = val(url.limit)>
            <cfelseif structKeyExists(body, "limit") AND isNumeric(body.limit)>
                <cfset contactLimit = val(body.limit)>
            </cfif>

            <cfif contactLimit LTE 0><cfset contactLimit = 100></cfif>
            <cfif contactLimit GT 250><cfset contactLimit = 250></cfif>

            <!-- Load contacts for this user -->
            <cfquery name="qContacts" datasource="fpw">
                SELECT contactId, name, phone, email
                FROM contacts
                WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                ORDER BY name ASC
                LIMIT #contactLimit#
            </cfquery>

            <cfset contacts = []>

            <cfloop query="qContacts">
                <cfset contactStruct = {
                    CONTACTID   = qContacts.contactId,
                    CONTACTNAME = qContacts.name,
                    PHONE       = qContacts.phone,
                    EMAIL       = qContacts.email
                }>
                <cfset arrayAppend(contacts, contactStruct)>
            </cfloop>

            <cfset response = {
                SUCCESS = true,
                AUTH    = true,
                COUNT   = arrayLen(contacts),
                CONTACTS = contacts
            }>

            <cfoutput>#serializeJSON(response)#</cfoutput>

            <cfcatch type="any">
                <cfset errResponse = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "SERVER_ERROR",
                    MESSAGE = "Contacts API error.",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

</cfcomponent>
