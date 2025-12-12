<cfsetting enablecfoutputonly="true" showdebugoutput="false">
<cfcontent type="application/json; charset=utf-8">
<cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

<cftry>

    <!-- Check if user is logged in -->
    <cfif structKeyExists(session, "user") AND isStruct(session.user)>

        <cfset response = {
            SUCCESS = true,
            AUTH    = true,
            USER    = session.user
        }>

    <cfelse>

        <cfset response = {
            SUCCESS = false,
            AUTH    = false,
            MESSAGE = "Not logged in."
        }>

    </cfif>

    <cfoutput>#serializeJSON(response)#</cfoutput>

    <cfcatch type="any">
        <cfset errResponse = {
            SUCCESS = false,
            AUTH    = false,
            MESSAGE = "Server error fetching current user.",
            ERROR   = "SERVER_ERROR",
            DETAIL  = cfcatch.message
        }>
        <cfoutput>#serializeJSON(errResponse)#</cfoutput>
    </cfcatch>

</cftry>

<cfsetting enablecfoutputonly="false">
