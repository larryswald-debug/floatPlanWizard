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
            <cfset vesselLimit = 100>

            <cfif structKeyExists(arguments, "limit") AND isNumeric(arguments.limit)>
                <cfset vesselLimit = val(arguments.limit)>
            <cfelseif structKeyExists(url, "limit") AND isNumeric(url.limit)>
                <cfset vesselLimit = val(url.limit)>
            <cfelseif structKeyExists(body, "limit") AND isNumeric(body.limit)>
                <cfset vesselLimit = val(body.limit)>
            </cfif>

            <cfif vesselLimit LTE 0><cfset vesselLimit = 100></cfif>
            <cfif vesselLimit GT 250><cfset vesselLimit = 250></cfif>

            <!-- Load vessels for this user -->
            <cftry>
                <cfset vesselImageService = createObject("component", "fpw.api.v1.VesselImageService").init("fpw")>
                <cfcatch>
                    <cfset vesselImageService = createObject("component", "api.v1.VesselImageService").init("fpw")>
                </cfcatch>
            </cftry>
            <cfset vesselImageBasePath = reReplace(cgi.script_name, "/api/v1/.*$", "", "one")>

            <cfquery name="qVessels" datasource="fpw">
                SELECT v.vesselId, v.userId, v.vesselName, v.registration, v.typeOfVessel, v.make, v.model,
                       v.lengthOfVessel, v.max_speed, v.most_efficient_speed, v.gallons_per_hour, v.gph_at_max_speed,
                       v.fuel_capacity, v.isDefaultVessel, v.hullColor, v.hailingPort,
                       vi.local_image_path, vi.thumbnail_image_path, vi.original_filename, vi.mime_type
                FROM vessels v
                LEFT JOIN vessel_images vi
                  ON vi.vessel_id = v.vesselId
                WHERE v.userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
                ORDER BY v.vesselId DESC
                LIMIT #vesselLimit#
            </cfquery>

            <cfset vessels = []>

            <cfloop query="qVessels">
                <cfset vesselImage = vesselImageService.buildImageAsset(
                    isNull(qVessels.local_image_path) ? "" : qVessels.local_image_path,
                    isNull(qVessels.thumbnail_image_path) ? "" : qVessels.thumbnail_image_path,
                    isNull(qVessels.original_filename) ? "" : qVessels.original_filename,
                    isNull(qVessels.mime_type) ? "" : qVessels.mime_type,
                    vesselImageBasePath
                )>
                <cfset vesselStruct = {
                    VESSELID     = qVessels.vesselId,
                    USERID       = qVessels.userId,
                    VESSELNAME   = qVessels.vesselName,
                    REGISTRATION = qVessels.registration,
                    TYPE         = qVessels.typeOfVessel,
                    MAKE         = qVessels.make,
                    MODEL        = qVessels.model,
                    LENGTH       = qVessels.lengthOfVessel,
                    MAX_SPEED    = qVessels.max_speed,
                    MAX_SPEED_KN = qVessels.max_speed,
                    MOST_EFFICIENT_SPEED = qVessels.most_efficient_speed,
                    MOST_EFFICIENT_SPEED_KN = qVessels.most_efficient_speed,
                    GALLONS_PER_HOUR = qVessels.gallons_per_hour,
                    GPH_AT_MAX_SPEED = qVessels.gph_at_max_speed,
                    FUEL_CAPACITY = qVessels.fuel_capacity,
                    GPH_AT_MOST_EFFICIENT_SPEED = qVessels.gallons_per_hour,
                    ISDEFAULTVESSEL = qVessels.isDefaultVessel,
                    COLOR        = qVessels.hullColor,
                    HOMEPORT     = qVessels.hailingPort,
                    IMAGE        = vesselImage,
                    IMAGE_URL    = vesselImage.thumbnailUrl,
                    THUMBNAIL_URL = vesselImage.thumbnailUrl
                }>
                <cfset arrayAppend(vessels, vesselStruct)>
            </cfloop>

            <cfset response = {
                SUCCESS = true,
                AUTH    = true,
                COUNT   = arrayLen(vessels),
                VESSELS = vessels
            }>

            <cfoutput>#serializeJSON(response)#</cfoutput>

            <cfcatch type="any">
                <cfset errResponse = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "SERVER_ERROR",
                    MESSAGE = "Vessels API error.",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

</cfcomponent>




