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

            <cfset apiKey = "">
            <cftry>
                <cfif structKeyExists(getFunctionList(), "getSystemEnvironment")>
                    <cfset env = getSystemEnvironment()>
                    <cfif structKeyExists(env, "GOOGLE_PLACES_API_KEY")>
                        <cfset apiKey = env["GOOGLE_PLACES_API_KEY"]>
                    <cfelseif structKeyExists(env, "GOOGLE_MAPS_API_KEY")>
                        <cfset apiKey = env["GOOGLE_MAPS_API_KEY"]>
                    </cfif>
                </cfif>
            <cfcatch>
                <cfset apiKey = "">
            </cfcatch>
            </cftry>

            <cfif NOT len(trim(apiKey))>
                <cfset response = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "MISSING_API_KEY",
                    MESSAGE = "Places enrichment is not configured."
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfset lat = val(lat)>
            <cfset lng = val(lng)>
            <cfset name = trim(toString(name))>

            <cfset findUrl = "https://maps.googleapis.com/maps/api/place/findplacefromtext/json">
            <cfset findQuery = "input=#urlEncodedFormat(name)#&inputtype=textquery&locationbias=circle:800@#lat#,#lng#&fields=place_id,name&key=#urlEncodedFormat(apiKey)#">

            <cfhttp url="#findUrl#?#findQuery#" method="get" result="findRes" timeout="20"></cfhttp>

            <cfset placeId = "">
            <cftry>
                <cfset findData = deserializeJSON(findRes.fileContent, false)>
            <cfcatch>
                <cfset findData = {}>
            </cfcatch>
            </cftry>

            <cfif structKeyExists(findData, "candidates") AND isArray(findData.candidates) AND arrayLen(findData.candidates)>
                <cfset placeId = findData.candidates[1].place_id>
            </cfif>

            <cfif NOT len(placeId)>
                <cfset response = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "NOT_FOUND",
                    MESSAGE = "No matching place found."
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfset detailsUrl = "https://maps.googleapis.com/maps/api/place/details/json">
            <cfset detailsQuery = "place_id=#urlEncodedFormat(placeId)#&fields=formatted_phone_number,website,opening_hours,rating,photos&key=#urlEncodedFormat(apiKey)#">

            <cfhttp url="#detailsUrl#?#detailsQuery#" method="get" result="detailsRes" timeout="20"></cfhttp>

            <cfset detailsData = {}>
            <cftry>
                <cfset detailsData = deserializeJSON(detailsRes.fileContent, false)>
            <cfcatch>
                <cfset detailsData = {}>
            </cfcatch>
            </cftry>

            <cfset details = { PHONE = "", WEBSITE = "", HOURS = "", RATING = "", PHOTO = "" }>
            <cfif structKeyExists(detailsData, "result") AND isStruct(detailsData.result)>
                <cfset result = detailsData.result>
                <cfif structKeyExists(result, "formatted_phone_number")>
                    <cfset details.PHONE = result.formatted_phone_number>
                </cfif>
                <cfif structKeyExists(result, "website")>
                    <cfset details.WEBSITE = result.website>
                </cfif>
                <cfif structKeyExists(result, "opening_hours") AND structKeyExists(result.opening_hours, "weekday_text")>
                    <cfset details.HOURS = arrayToList(result.opening_hours.weekday_text, "; ")>
                </cfif>
                <cfif structKeyExists(result, "rating")>
                    <cfset details.RATING = result.rating>
                </cfif>
                <cfif structKeyExists(result, "photos") AND isArray(result.photos) AND arrayLen(result.photos)>
                    <cfset photoRef = result.photos[1].photo_reference>
                    <cfset details.PHOTO = "https://maps.googleapis.com/maps/api/place/photo?maxwidth=160&photo_reference=#urlEncodedFormat(photoRef)#&key=#urlEncodedFormat(apiKey)#">
                </cfif>
            </cfif>

            <cfset response = {
                SUCCESS = true,
                AUTH    = true,
                DETAILS = details
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
