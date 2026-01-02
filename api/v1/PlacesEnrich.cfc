<cfcomponent output="false">

    <cffunction name="enrichPlace" access="remote" returntype="void" output="true">
        <cfargument name="lat" type="any" required="false">
        <cfargument name="lng" type="any" required="false">
        <cfargument name="name" type="any" required="false">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

        <cftry>

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

            <cfset lat = structKeyExists(arguments, "lat") ? arguments.lat : (structKeyExists(url, "lat") ? url.lat : (structKeyExists(body, "lat") ? body.lat : ""))>
            <cfset lng = structKeyExists(arguments, "lng") ? arguments.lng : (structKeyExists(url, "lng") ? url.lng : (structKeyExists(body, "lng") ? body.lng : ""))>
            <cfset name = structKeyExists(arguments, "name") ? arguments.name : (structKeyExists(url, "name") ? url.name : (structKeyExists(body, "name") ? body.name : ""))>

            <cfif NOT isNumeric(lat) OR NOT isNumeric(lng)>
                <cfset response = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "INVALID_INPUT",
                    MESSAGE = "Latitude and longitude must be numeric."
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfset lat = val(lat)>
            <cfset lng = val(lng)>
            <cfset name = trim(toString(name))>

            <cfset response = {
                SUCCESS = false,
                AUTH    = true,
                ERROR   = "UNAVAILABLE",
                MESSAGE = "Places enrichment is unavailable."
            }>

            <cfoutput>#serializeJSON(response)#</cfoutput>

            <cfcatch type="any">
                <cfset errResponse = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "SERVER_ERROR",
                    MESSAGE = "Places enrichment error.",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

</cfcomponent>
