<cfcomponent output="false">

    <cffunction name="getNavAids" access="remote" returntype="void" output="true">
        <cfargument name="lat" type="any" required="false">
        <cfargument name="lng" type="any" required="false">
        <cfargument name="radiusNm" type="any" required="false">
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
            <cfset radiusNm = structKeyExists(arguments, "radiusNm") ? arguments.radiusNm : (structKeyExists(url, "radiusNm") ? url.radiusNm : (structKeyExists(body, "radiusNm") ? body.radiusNm : 10))>

            <cfif NOT isNumeric(lat) OR NOT isNumeric(lng) OR NOT isNumeric(radiusNm)>
                <cfset response = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "INVALID_INPUT",
                    MESSAGE = "Latitude, longitude, and radius must be numeric."
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfset lat = val(lat)>
            <cfset lng = val(lng)>
            <cfset radiusNm = val(radiusNm)>
            <cfif radiusNm LTE 0><cfset radiusNm = 5></cfif>

            <cfset offset = min(radiusNm / 60, 0.12)>

            <cfset pois = [
                {
                    id = "aton:stub-1",
                    source = "aton",
                    type = "aton",
                    name = "Lighted Buoy Alpha",
                    lat = lat + offset,
                    lng = lng + offset,
                    summary = "Green Fl (2) 6s",
                    details = {
                        aidType = "buoy",
                        characteristic = "Fl (2) 6s",
                        number = "G1",
                        structure = "Can"
                    }
                },
                {
                    id = "aton:stub-2",
                    source = "aton",
                    type = "aton",
                    name = "Beacon Bravo",
                    lat = lat - offset,
                    lng = lng + (offset / 2),
                    summary = "Red Q 4s",
                    details = {
                        aidType = "beacon",
                        characteristic = "Q 4s",
                        number = "R4",
                        structure = "Pile"
                    }
                },
                {
                    id = "aton:stub-3",
                    source = "aton",
                    type = "aton",
                    name = "Light Charlie",
                    lat = lat + (offset / 3),
                    lng = lng - offset,
                    summary = "White Oc 3s",
                    details = {
                        aidType = "light",
                        characteristic = "Oc 3s",
                        number = "W2",
                        structure = "Tower"
                    }
                }
            ]>

            <cfset response = {
                SUCCESS = true,
                AUTH    = true,
                POIS    = pois
            }>

            <cfoutput>#serializeJSON(response)#</cfoutput>

            <cfcatch type="any">
                <cfset errResponse = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "SERVER_ERROR",
                    MESSAGE = "Nav aids API error.",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

</cfcomponent>
