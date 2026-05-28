<!--- /fpw/api/v1/weather.cfc  (TAGS ONLY)
      NOAA/NWS forecast + alerts + nowCOAST map layers for a float plan anchor

      Auth:
        - Normal: requires logged-in session.user
        - Dev bypass (optional): token/asUserId only in explicit dev mode
          token must match configured application.monitorToken

      Requires:
        - application.dsn set in Application.cfc
        - floatplans has departureLat/departureLon OR returnLat/returnLon
--->

<cfcomponent output="false" hint="FPW Weather API (V1) - NOAA/NWS + nowCOAST">

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfargument name="action" type="any" required="false">
        <cfargument name="id" type="any" required="false">
        <cfargument name="floatPlanId" type="any" required="false">
        <cfargument name="zip" type="any" required="false">
        <cfargument name="lat" type="any" required="false">
        <cfargument name="latitude" type="any" required="false">
        <cfargument name="lon" type="any" required="false">
        <cfargument name="lng" type="any" required="false">
        <cfargument name="longitude" type="any" required="false">
        <cfargument name="marineMode" type="any" required="false">
        <cfargument name="marineOnly" type="any" required="false">
        <cfargument name="waveTestFt" type="any" required="false">
        <cfargument name="cache" type="any" required="false">
        <cfargument name="bypassCache" type="any" required="false">
        <cfargument name="nocache" type="any" required="false">
        <cfargument name="token" type="any" required="false">
        <cfargument name="asUserId" type="any" required="false">

        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">
        <cfheader name="Pragma" value="no-cache">

        <cfparam name="url.token" default="">
        <cfparam name="url.asUserId" default="">
        <cfparam name="url.zip" default="">

        <cftry>
            <cfset local.resp = { "SUCCESS"=false, "AUTH"=true, "MESSAGE"="", "DATA"={} }>
            <cfset local.userStruct = {} >
            <cfset local.userId = 0 >
            <cfset local.devBypassToken = structKeyExists(arguments, "token") ? trim(toString(arguments.token)) : trim(url.token)>
            <cfset local.devBypassUserId = structKeyExists(arguments, "asUserId") ? trim(toString(arguments.asUserId)) : trim(url.asUserId)>
            <cfset local.act = "get" >
            <cfset local.fpId = 0 >
            <cfset local.data = {} >
            <cfset local.zip = "">
            <cfset local.marineMode = "full">
            <cfset local.marineOnly = false>
            <cfset local.marineModeProvided = false>
            <cfset local.marineOnlyProvided = false>

            <cfif structKeyExists(session, "user") AND isStruct(session.user)>
                <cfset local.userStruct = session.user>
                <cfset local.userId = resolveUserId(local.userStruct)>
            </cfif>

            <!--- DEV BYPASS (optional) --->
            <cfif local.userId LTE 0>
                <cfif len(local.devBypassToken)
                    AND structKeyExists(application, "env")
                    AND lCase(toString(application.env)) EQ "dev"
                    AND structKeyExists(application, "monitorToken")
                    AND len(trim(toString(application.monitorToken)))
                    AND local.devBypassToken EQ trim(application.monitorToken)
                    AND isNumeric(local.devBypassUserId)
                    AND val(local.devBypassUserId) GT 0>
                    <cfset local.userId = int(val(local.devBypassUserId))>
                </cfif>
            </cfif>

            <cfif local.userId LTE 0>
                <cfset local.resp.SUCCESS = false>
                <cfset local.resp.AUTH = false>
                <cfset local.resp.MESSAGE = "Unauthorized">
                <cfoutput>#serializeJSON(local.resp)#</cfoutput>
                <cfreturn>
            </cfif>

            <cfif structKeyExists(arguments, "action") AND len(trim(arguments.action))>
                <cfset local.act = lcase(trim(arguments.action))>
            </cfif>
            <cfif structKeyExists(arguments, "marineMode") AND len(trim(arguments.marineMode))>
                <cfset local.marineMode = lcase(trim(arguments.marineMode))>
                <cfset local.marineModeProvided = true>
            <cfelseif isDefined("url.marineMode") AND len(trim(url.marineMode))>
                <cfset local.marineMode = lcase(trim(url.marineMode))>
                <cfset local.marineModeProvided = true>
            </cfif>
            <cfif local.marineMode NEQ "quick" AND local.marineMode NEQ "full">
                <cfset local.marineMode = "full">
            </cfif>
            <cfif structKeyExists(arguments, "marineOnly")>
                <cfset local.marineOnly = (isBoolean(arguments.marineOnly) ? arguments.marineOnly : (val(arguments.marineOnly) EQ 1))>
                <cfset local.marineOnlyProvided = true>
            <cfelseif isDefined("url.marineOnly")>
                <cfset local.marineOnly = (val(url.marineOnly) EQ 1)>
                <cfset local.marineOnlyProvided = true>
            </cfif>

            <cfif local.act EQ "get">

                <cfif NOT structKeyExists(application, "dsn") OR NOT len(trim(application.dsn))>
                    <cfset local.resp.SUCCESS = false>
                    <cfset local.resp.MESSAGE = "Application error: application.dsn is not set.">
                    <cfoutput>#serializeJSON(local.resp)#</cfoutput>
                    <cfreturn>
                </cfif>

                <cfif structKeyExists(arguments, "floatPlanId") AND len(trim(arguments.floatPlanId))>
                    <cfset local.fpId = int(val(arguments.floatPlanId))>
                <cfelseif structKeyExists(arguments, "id") AND len(trim(arguments.id))>
                    <cfset local.fpId = int(val(arguments.id))>
                </cfif>

                <cfif local.fpId LTE 0>
                    <cfset local.resp.SUCCESS = false>
                    <cfset local.resp.MESSAGE = "Missing floatPlanId">
                    <cfoutput>#serializeJSON(local.resp)#</cfoutput>
                    <cfreturn>
                </cfif>

                <cfset local.data = getWeatherForFloatPlan(local.userId, local.fpId, local.marineMode, local.marineOnly)>

                <cfset local.resp.SUCCESS = local.data.SUCCESS>
                <cfset local.resp.MESSAGE = local.data.MESSAGE>
                <cfset structDelete(local.data, "SUCCESS", false)>
                <cfset structDelete(local.data, "MESSAGE", false)>
                <cfset local.resp.DATA = local.data>

                <cfoutput>#serializeJSON(local.resp)#</cfoutput>
                <cfreturn>
            </cfif>

            <cfif local.act EQ "zip">

                <cfif structKeyExists(arguments, "zip") AND len(trim(arguments.zip))>
                    <cfset local.zip = trim(arguments.zip)>
                <cfelse>
                    <cfset local.zip = trim(url.zip)>
                </cfif>

                <cfset local.zip = rereplace(local.zip, "[^0-9]", "", "all")>

                <cfif NOT reFind("^[0-9]{5}$", local.zip)>
                    <cfset local.resp.SUCCESS = false>
                    <cfset local.resp.MESSAGE = "Invalid ZIP">
                    <cfset local.resp.ERROR = { "CODE"="INVALID_ZIP", "DETAIL"="ZIP must be 5 digits." }>
                    <cfoutput>#serializeJSON(local.resp)#</cfoutput>
                    <cfreturn>
                </cfif>

                <cfset request._wxRequestSummary = {
                    "zip"=local.zip,
                    "geocodeCache"="none",
                    "geocodeProvider"="none",
                    "ndbcBuoy"="none",
                    "ndbcStatus"="none",
                    "ndbcNegCache"="none",
                    "marineMode"=(local.marineModeProvided ? local.marineMode : "unknown"),
                    "marineOnly"=(local.marineOnlyProvided ? (local.marineOnly ? "1" : "0") : "unknown")
                }>

                <cfset local.data = getWeatherForZip(local.zip, local.marineMode, local.marineOnly)>

                <cfset local.resp.SUCCESS = local.data.SUCCESS>
                <cfset local.resp.MESSAGE = local.data.MESSAGE>
                <cfif structKeyExists(local.data, "ERROR")>
                    <cfset local.resp.ERROR = local.data.ERROR>
                </cfif>
                <cfset structDelete(local.data, "SUCCESS", false)>
                <cfset structDelete(local.data, "MESSAGE", false)>
                <cfset structDelete(local.data, "ERROR", false)>
                <cfset local.resp.DATA = local.data>

                <cfif structKeyExists(application, "settings")
                    AND isStruct(application.settings)
                    AND structKeyExists(application.settings, "wxRequestSummaryLogEnabled")
                    AND isBoolean(application.settings.wxRequestSummaryLogEnabled)
                    AND application.settings.wxRequestSummaryLogEnabled
                    AND structKeyExists(request, "_wxRequestSummary")
                    AND isStruct(request._wxRequestSummary)>
                    <cfset local.summary = request._wxRequestSummary>
                    <cflog
                        file="fpw_weather"
                        type="information"
                        text="weather_zip_summary zip=#(structKeyExists(local.summary,'zip') ? toString(local.summary.zip) : local.zip)# geocodeCache=#(structKeyExists(local.summary,'geocodeCache') ? toString(local.summary.geocodeCache) : 'none')# geocodeProvider=#(structKeyExists(local.summary,'geocodeProvider') ? toString(local.summary.geocodeProvider) : 'none')# ndbcBuoy=#(structKeyExists(local.summary,'ndbcBuoy') ? toString(local.summary.ndbcBuoy) : 'none')# ndbcStatus=#(structKeyExists(local.summary,'ndbcStatus') ? toString(local.summary.ndbcStatus) : 'none')# ndbcNegCache=#(structKeyExists(local.summary,'ndbcNegCache') ? toString(local.summary.ndbcNegCache) : 'none')# marineMode=#(structKeyExists(local.summary,'marineMode') ? toString(local.summary.marineMode) : 'unknown')# marineOnly=#(structKeyExists(local.summary,'marineOnly') ? toString(local.summary.marineOnly) : 'unknown')#">
                </cfif>

                <cfoutput>#serializeJSON(local.resp)#</cfoutput>
                <cfreturn>
            </cfif>

            <cfif local.act EQ "search">
                <cfset local.searchLatRaw = readRequestParamValue(arguments, ["lat", "latitude"])>
                <cfset local.searchLonRaw = readRequestParamValue(arguments, ["lon", "lng", "longitude"])>
                <cfset local.searchZipRaw = readRequestParamValue(arguments, ["zip"])>
                <cfset local.searchFloatPlanRaw = readRequestParamValue(arguments, ["floatPlanId", "id"])>
                <cfset local.searchHasLat = len(local.searchLatRaw)>
                <cfset local.searchHasLon = len(local.searchLonRaw)>
                <cfset local.searchRequestEcho = {
                    "marineMode"=local.marineMode,
                    "marineOnly"=(local.marineOnly ? 1 : 0)
                }>

                <cfif local.searchHasLat XOR local.searchHasLon>
                    <cfset local.resp.SUCCESS = false>
                    <cfset local.resp.MESSAGE = "Latitude and longitude must both be provided.">
                    <cfset local.resp.ERROR = {
                        "CODE"="PARTIAL_COORDINATES",
                        "DETAIL"="Provide both latitude and longitude."
                    }>
                    <cfoutput>#serializeJSON(local.resp)#</cfoutput>
                    <cfreturn>
                </cfif>

                <cfif local.searchHasLat AND local.searchHasLon>
                    <cfset local.latParsed = parseSearchCoordinate(local.searchLatRaw, -90, 90, "INVALID_LATITUDE", "Latitude")>
                    <cfif NOT local.latParsed.SUCCESS>
                        <cfset local.resp.SUCCESS = false>
                        <cfset local.resp.MESSAGE = local.latParsed.MESSAGE>
                        <cfset local.resp.ERROR = local.latParsed.ERROR>
                        <cfoutput>#serializeJSON(local.resp)#</cfoutput>
                        <cfreturn>
                    </cfif>

                    <cfset local.lonParsed = parseSearchCoordinate(local.searchLonRaw, -180, 180, "INVALID_LONGITUDE", "Longitude")>
                    <cfif NOT local.lonParsed.SUCCESS>
                        <cfset local.resp.SUCCESS = false>
                        <cfset local.resp.MESSAGE = local.lonParsed.MESSAGE>
                        <cfset local.resp.ERROR = local.lonParsed.ERROR>
                        <cfoutput>#serializeJSON(local.resp)#</cfoutput>
                        <cfreturn>
                    </cfif>

                    <cfset local.searchRequestEcho.lat = local.searchLatRaw>
                    <cfset local.searchRequestEcho.lon = local.searchLonRaw>
                    <cfset local.searchRequestEcho.latitude = local.latParsed.VALUE>
                    <cfset local.searchRequestEcho.longitude = local.lonParsed.VALUE>

                    <cfset local.data = getWeatherForCoordinates(local.latParsed.VALUE, local.lonParsed.VALUE, local.marineMode, local.marineOnly)>
                    <cfset local.data = appendSearchResolutionMeta(
                        local.data,
                        "coords",
                        local.latParsed.VALUE,
                        local.lonParsed.VALUE,
                        local.searchRequestEcho
                    )>

                    <cfset local.resp.SUCCESS = local.data.SUCCESS>
                    <cfset local.resp.MESSAGE = local.data.MESSAGE>
                    <cfif structKeyExists(local.data, "ERROR")>
                        <cfset local.resp.ERROR = local.data.ERROR>
                    </cfif>
                    <cfset structDelete(local.data, "SUCCESS", false)>
                    <cfset structDelete(local.data, "MESSAGE", false)>
                    <cfset structDelete(local.data, "ERROR", false)>
                    <cfset local.resp.DATA = local.data>
                    <cfoutput>#serializeJSON(local.resp)#</cfoutput>
                    <cfreturn>
                </cfif>

                <cfif len(local.searchZipRaw)>
                    <cfset local.zip = rereplace(local.searchZipRaw, "[^0-9]", "", "all")>
                    <cfif NOT reFind("^[0-9]{5}$", local.zip)>
                        <cfset local.resp.SUCCESS = false>
                        <cfset local.resp.MESSAGE = "Invalid ZIP">
                        <cfset local.resp.ERROR = { "CODE"="INVALID_ZIP", "DETAIL"="ZIP must be 5 digits." }>
                        <cfoutput>#serializeJSON(local.resp)#</cfoutput>
                        <cfreturn>
                    </cfif>

                    <cfset local.searchRequestEcho.zip = local.zip>
                    <cfset local.data = getWeatherForZip(local.zip, local.marineMode, local.marineOnly)>
                    <cfset local.searchResolvedLat = "">
                    <cfset local.searchResolvedLon = "">
                    <cfif structKeyExists(local.data, "META")
                        AND isStruct(local.data.META)
                        AND structKeyExists(local.data.META, "anchor")
                        AND isStruct(local.data.META.anchor)
                        AND structKeyExists(local.data.META.anchor, "lat")
                        AND structKeyExists(local.data.META.anchor, "lon")>
                        <cfset local.searchResolvedLat = val(local.data.META.anchor.lat)>
                        <cfset local.searchResolvedLon = val(local.data.META.anchor.lon)>
                    </cfif>
                    <cfset local.data = appendSearchResolutionMeta(
                        local.data,
                        "zip",
                        local.searchResolvedLat,
                        local.searchResolvedLon,
                        local.searchRequestEcho
                    )>

                    <cfset local.resp.SUCCESS = local.data.SUCCESS>
                    <cfset local.resp.MESSAGE = local.data.MESSAGE>
                    <cfif structKeyExists(local.data, "ERROR")>
                        <cfset local.resp.ERROR = local.data.ERROR>
                    </cfif>
                    <cfset structDelete(local.data, "SUCCESS", false)>
                    <cfset structDelete(local.data, "MESSAGE", false)>
                    <cfset structDelete(local.data, "ERROR", false)>
                    <cfset local.resp.DATA = local.data>
                    <cfoutput>#serializeJSON(local.resp)#</cfoutput>
                    <cfreturn>
                </cfif>

                <cfif len(local.searchFloatPlanRaw)>
                    <cfif NOT structKeyExists(application, "dsn") OR NOT len(trim(application.dsn))>
                        <cfset local.resp.SUCCESS = false>
                        <cfset local.resp.MESSAGE = "Application error: application.dsn is not set.">
                        <cfoutput>#serializeJSON(local.resp)#</cfoutput>
                        <cfreturn>
                    </cfif>

                    <cfset local.fpId = int(val(local.searchFloatPlanRaw))>
                    <cfif local.fpId LTE 0>
                        <cfset local.resp.SUCCESS = false>
                        <cfset local.resp.MESSAGE = "Missing floatPlanId">
                        <cfset local.resp.ERROR = {
                            "CODE"="MISSING_FLOATPLAN_ID",
                            "DETAIL"="floatPlanId or id must be a positive integer."
                        }>
                        <cfoutput>#serializeJSON(local.resp)#</cfoutput>
                        <cfreturn>
                    </cfif>

                    <cfset local.searchRequestEcho.floatPlanId = local.fpId>
                    <cfset local.data = getWeatherForFloatPlan(local.userId, local.fpId, local.marineMode, local.marineOnly)>
                    <cfset local.searchResolvedLat = "">
                    <cfset local.searchResolvedLon = "">
                    <cfif structKeyExists(local.data, "META")
                        AND isStruct(local.data.META)
                        AND structKeyExists(local.data.META, "anchor")
                        AND isStruct(local.data.META.anchor)
                        AND structKeyExists(local.data.META.anchor, "lat")
                        AND structKeyExists(local.data.META.anchor, "lon")>
                        <cfset local.searchResolvedLat = val(local.data.META.anchor.lat)>
                        <cfset local.searchResolvedLon = val(local.data.META.anchor.lon)>
                    </cfif>
                    <cfset local.data = appendSearchResolutionMeta(
                        local.data,
                        "floatplan",
                        local.searchResolvedLat,
                        local.searchResolvedLon,
                        local.searchRequestEcho
                    )>

                    <cfset local.resp.SUCCESS = local.data.SUCCESS>
                    <cfset local.resp.MESSAGE = local.data.MESSAGE>
                    <cfif structKeyExists(local.data, "ERROR")>
                        <cfset local.resp.ERROR = local.data.ERROR>
                    </cfif>
                    <cfset structDelete(local.data, "SUCCESS", false)>
                    <cfset structDelete(local.data, "MESSAGE", false)>
                    <cfset structDelete(local.data, "ERROR", false)>
                    <cfset local.resp.DATA = local.data>
                    <cfoutput>#serializeJSON(local.resp)#</cfoutput>
                    <cfreturn>
                </cfif>

                <cfset local.resp.SUCCESS = false>
                <cfset local.resp.MESSAGE = "Missing location input">
                <cfset local.resp.ERROR = {
                    "CODE"="MISSING_LOCATION_INPUT",
                    "DETAIL"="Provide lat/lon, zip, or floatPlanId."
                }>
                <cfoutput>#serializeJSON(local.resp)#</cfoutput>
                <cfreturn>
            </cfif>

            <cfset local.resp.SUCCESS = false>
            <cfset local.resp.MESSAGE = "Unknown action">
            <cfoutput>#serializeJSON(local.resp)#</cfoutput>

            <cfcatch>
                <cfset local.err = {
                    "SUCCESS"=false,
                    "AUTH"=true,
                    "MESSAGE"="Application error",
                    "ERROR"={ "MESSAGE"=cfcatch.message, "DETAIL"=cfcatch.detail }
                }>
                <cfoutput>#serializeJSON(local.err)#</cfoutput>
            </cfcatch>
        </cftry>
    </cffunction>

    <!--- =========================
          Main
    ========================== --->
    <cffunction name="getWeatherForFloatPlan" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="marineMode" type="string" required="false" default="full">
        <cfargument name="marineOnly" type="boolean" required="false" default="false">

        <cfset local.out = {
            "SUCCESS"=false,
            "MESSAGE"="",
            "SUMMARY"="",
            "FORECAST"=[],
            "ALERTS"=[],
            "MARINE"={},
            "surface"={
                "pressure_inhg"="",
                "visibility_mi"="",
                "station_id"="",
                "observation_time"="",
                "dewpoint_f"="",
                "humidity"=""
            },
            "MAP_LAYERS"=[],
            "META"={}
        }>

        <cfset local.anchor = resolveFloatPlanAnchor(arguments.userId, arguments.floatPlanId)>

        <cfif NOT local.anchor.SUCCESS>
            <cfset local.out.SUCCESS = false>
            <cfset local.out.MESSAGE = local.anchor.MESSAGE>
            <cfreturn local.out>
        </cfif>

        <cfset local.lat = local.anchor.LAT>
        <cfset local.lon = local.anchor.LON>

        <cfset local.out = assembleWeatherResponse(
            lat = local.lat,
            lon = local.lon,
            marineMode = arguments.marineMode,
            marineOnly = arguments.marineOnly
        )>
        <cfreturn local.out>
    </cffunction>

    <cffunction name="getWeatherForCoordinates" access="public" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lon" type="numeric" required="true">
        <cfargument name="marineMode" type="string" required="false" default="full">
        <cfargument name="marineOnly" type="boolean" required="false" default="false">

        <cfset local.out = assembleWeatherResponse(
            lat = arguments.lat,
            lon = arguments.lon,
            marineMode = arguments.marineMode,
            marineOnly = arguments.marineOnly
        )>
        <cfreturn local.out>
    </cffunction>

    <cffunction name="getFollowConditionsSummary" access="public" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lon" type="numeric" required="true">

        <cfset local.out = {
            "SUCCESS"=false,
            "MESSAGE"="Forecast unavailable",
            "SUMMARY"="",
            "FORECAST_SHORT"="",
            "WIND_SPEED"="",
            "WIND_DIRECTION"="",
            "META"={}
        }>
        <cfset local.pointsUrl = "https://api.weather.gov/points/" & arguments.lat & "," & arguments.lon>
        <cfset local.forecastUrl = "">
        <cfset local.ua = getNwsUserAgent()>
        <cfset local.pointsStatus = 0>
        <cfset local.forecastStatus = 0>
        <cfset local.pointsObj = {} >
        <cfset local.forecastObj = {} >
        <cfset local.period = {} >
        <cfset local.summaryForecast = [] >

        <cfhttp url="#local.pointsUrl#" method="get" result="pointsRes" timeout="15">
            <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
            <cfhttpparam type="header" name="Accept" value="application/geo+json">
        </cfhttp>

        <cfset local.pointsStatus = val(pointsRes.statusCode)>
        <cfset local.out.META = {
            "source"="NWS",
            "step"="points",
            "url"=local.pointsUrl,
            "status"=local.pointsStatus
        }>
        <cfif local.pointsStatus LT 200 OR local.pointsStatus GTE 300>
            <cfreturn local.out>
        </cfif>

        <cftry>
            <cfset local.pointsObj = deserializeJSON(pointsRes.fileContent)>
            <cfcatch>
                <cflog
                    file="fpw-weather"
                    type="error"
                    text="[FPW][WEATHER] getFollowConditionsSummary:points_deserialize :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
                <cfset local.out.MESSAGE = "Forecast unavailable">
                <cfreturn local.out>
            </cfcatch>
        </cftry>

        <cfif
            isStruct(local.pointsObj)
            AND structKeyExists(local.pointsObj, "properties")
            AND isStruct(local.pointsObj.properties)
            AND structKeyExists(local.pointsObj.properties, "forecast")
            AND len(trim(toString(local.pointsObj.properties.forecast)))>
            <cfset local.forecastUrl = trim(toString(local.pointsObj.properties.forecast))>
        <cfelseif
            isStruct(local.pointsObj)
            AND structKeyExists(local.pointsObj, "properties")
            AND isStruct(local.pointsObj.properties)
            AND structKeyExists(local.pointsObj.properties, "forecastHourly")
            AND len(trim(toString(local.pointsObj.properties.forecastHourly)))>
            <cfset local.forecastUrl = trim(toString(local.pointsObj.properties.forecastHourly))>
        </cfif>

        <cfif NOT len(local.forecastUrl)>
            <cfset local.out.MESSAGE = "Forecast unavailable">
            <cfreturn local.out>
        </cfif>

        <cfhttp url="#local.forecastUrl#" method="get" result="forecastRes" timeout="15">
            <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
            <cfhttpparam type="header" name="Accept" value="application/geo+json">
        </cfhttp>

        <cfset local.forecastStatus = val(forecastRes.statusCode)>
        <cfset local.out.META = {
            "source"="NWS",
            "step"="forecast",
            "url"=local.forecastUrl,
            "status"=local.forecastStatus,
            "points_url"=local.pointsUrl,
            "points_status"=local.pointsStatus
        }>
        <cfif local.forecastStatus LT 200 OR local.forecastStatus GTE 300>
            <cfreturn local.out>
        </cfif>

        <cftry>
            <cfset local.forecastObj = deserializeJSON(forecastRes.fileContent)>
            <cfcatch>
                <cflog
                    file="fpw-weather"
                    type="error"
                    text="[FPW][WEATHER] getFollowConditionsSummary:forecast_deserialize :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
                <cfset local.out.MESSAGE = "Forecast unavailable">
                <cfreturn local.out>
            </cfcatch>
        </cftry>

        <cfif
            isStruct(local.forecastObj)
            AND structKeyExists(local.forecastObj, "properties")
            AND isStruct(local.forecastObj.properties)
            AND structKeyExists(local.forecastObj.properties, "periods")
            AND isArray(local.forecastObj.properties.periods)
            AND arrayLen(local.forecastObj.properties.periods)
            AND isStruct(local.forecastObj.properties.periods[1])>
            <cfset local.period = local.forecastObj.properties.periods[1]>
            <cfset local.out.FORECAST_SHORT = trim(toString(structKeyExists(local.period, "shortForecast") ? local.period.shortForecast : ""))>
            <cfset local.out.WIND_SPEED = trim(toString(structKeyExists(local.period, "windSpeed") ? local.period.windSpeed : ""))>
            <cfset local.out.WIND_DIRECTION = trim(toString(structKeyExists(local.period, "windDirection") ? local.period.windDirection : ""))>
            <cfset arrayAppend(local.summaryForecast, {
                "shortForecast"=local.out.FORECAST_SHORT,
                "windSpeed"=local.out.WIND_SPEED,
                "windDirection"=local.out.WIND_DIRECTION
            })>
            <cfset local.out.SUMMARY = buildBoaterSummary(local.summaryForecast, [])>
        <cfelse>
            <cfset local.out.SUMMARY = "Forecast currently unavailable.">
        </cfif>

        <cfset local.out.SUCCESS = true>
        <cfset local.out.MESSAGE = "OK">
        <cfreturn local.out>
    </cffunction>

    <cffunction name="getWeatherForZip" access="private" returntype="struct" output="false">
        <cfargument name="zip" type="string" required="true">
        <cfargument name="marineMode" type="string" required="false" default="full">
        <cfargument name="marineOnly" type="boolean" required="false" default="false">

        <cfset local.out = {
            "SUCCESS"=false,
            "MESSAGE"="",
            "SUMMARY"="",
            "FORECAST"=[],
            "ALERTS"=[],
            "MARINE"={},
            "surface"={
                "pressure_inhg"="",
                "visibility_mi"="",
                "station_id"="",
                "observation_time"="",
                "dewpoint_f"="",
                "humidity"=""
            },
            "MAP_LAYERS"=[],
            "META"={}
        }>

        <cfset local.geo = geocodeZip(arguments.zip)>

        <cfif NOT local.geo.SUCCESS>
            <cfset local.out.SUCCESS = false>
            <cfset local.out.MESSAGE = local.geo.MESSAGE>
            <cfif structKeyExists(local.geo, "ERROR")>
                <cfset local.out.ERROR = local.geo.ERROR>
            </cfif>
            <cfreturn local.out>
        </cfif>

        <cfset local.lat = local.geo.LAT>
        <cfset local.lon = local.geo.LON>

        <cfset local.out = assembleWeatherResponse(
            lat = local.lat,
            lon = local.lon,
            marineMode = arguments.marineMode,
            marineOnly = arguments.marineOnly,
            marineZip = arguments.zip,
            requestZip = arguments.zip,
            includeGeocodeSource = true,
            geocodeSourceMeta = (structKeyExists(local.geo, "META") ? local.geo.META : {})
        )>
        <cfreturn local.out>
    </cffunction>

    <cffunction name="assembleWeatherResponse" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lon" type="numeric" required="true">
        <cfargument name="marineMode" type="string" required="true">
        <cfargument name="marineOnly" type="boolean" required="true">
        <cfargument name="marineZip" type="string" required="false" default="">
        <cfargument name="requestZip" type="string" required="false" default="">
        <cfargument name="includeGeocodeSource" type="boolean" required="false" default="false">
        <cfargument name="geocodeSourceMeta" type="struct" required="false" default="#{}#">
        <cfscript>
            var tWeatherTotalStart = getTickCount();
            var tSectionStart = 0;
            var tMarine = 0;
            var tForecast = 0;
            var tAlerts = 0;
            var tMetar = 0;
            var marineCacheFlag = "";
            var forecastCacheFlag = "";
            var alertsCacheFlag = "";
            var metarCacheFlag = "";
            var weatherTimingLine = "";
        </cfscript>

        <cfset local.out = {
            "SUCCESS"=false,
            "MESSAGE"="",
            "SUMMARY"="",
            "FORECAST"=[],
            "ALERTS"=[],
            "MARINE"={},
            "surface"={
                "pressure_inhg"="",
                "visibility_mi"="",
                "station_id"="",
                "observation_time"="",
                "dewpoint_f"="",
                "humidity"=""
            },
            "MAP_LAYERS"=[],
            "META"={}
        }>
        <cfset local.bypassCache = shouldBypassWeatherCache()>
        <cfset local.noCache = ((isDefined("url.nocache") AND len(url.nocache) AND val(url.nocache) EQ 1) OR local.bypassCache)>
        <cfset local.isQuickMarineMode = (lcase(trim(arguments.marineMode)) EQ "quick")>
        <cfset local.f = {} >
        <cfset local.a = {} >
        <cfset local.s = {} >
        <cfset local.waveTest = resolveWaveTestOverride()>
        <cfset request._fpwWeatherTimingMetarMs = 0>
        <cfset request._fpwWeatherTimingMetarCache = "">
        <cfset tSectionStart = getTickCount()>
        <cfset local.m = getMarineDataCached(arguments.lat, arguments.lon, local.noCache, arguments.marineMode, arguments.marineZip, { "bypassCache"=local.bypassCache, "ttlSeconds"=900 })>
        <cfset tMarine = getTickCount() - tSectionStart>
        <cfset marineCacheFlag = (
            isStruct(local.m)
            AND structKeyExists(local.m, "cache_meta")
            AND isStruct(local.m.cache_meta)
            ? (
                structKeyExists(local.m.cache_meta, "bypass") AND local.m.cache_meta.bypass
                ? "bypass"
                : (structKeyExists(local.m.cache_meta, "hit") AND local.m.cache_meta.hit ? "hit" : "miss")
            )
            : ""
        )>

        <cfif local.waveTest.enabled>
            <cfif NOT isStruct(local.m)>
                <cfset local.m = {} >
            </cfif>
            <cfset local.m.wave_height_ft = local.waveTest.value>
            <cfif NOT structKeyExists(local.m, "META") OR NOT isStruct(local.m.META)>
                <cfset local.m.META = {} >
            </cfif>
            <cfset local.m.META.waveTestOverride = { "enabled"=true, "value"=local.waveTest.value }>
        </cfif>

        <cfif NOT arguments.marineOnly>
            <cfset tSectionStart = getTickCount()>
            <cfset local.f = getNwsForecast(arguments.lat, arguments.lon, { "bypassCache"=local.bypassCache, "ttlSeconds"=900 })>
            <cfset tForecast = getTickCount() - tSectionStart>
            <cfset forecastCacheFlag = (
                isStruct(local.f)
                AND structKeyExists(local.f, "cache_meta")
                AND isStruct(local.f.cache_meta)
                ? (
                    structKeyExists(local.f.cache_meta, "bypass") AND local.f.cache_meta.bypass
                    ? "bypass"
                    : (structKeyExists(local.f.cache_meta, "hit") AND local.f.cache_meta.hit ? "hit" : "miss")
                )
                : ""
            )>
            <cfset tSectionStart = getTickCount()>
            <cfset local.a = getNwsAlerts(arguments.lat, arguments.lon, { "bypassCache"=local.bypassCache, "ttlSeconds"=300 })>
            <cfset tAlerts = getTickCount() - tSectionStart>
            <cfset alertsCacheFlag = (
                isStruct(local.a)
                AND structKeyExists(local.a, "cache_meta")
                AND isStruct(local.a.cache_meta)
                ? (
                    structKeyExists(local.a.cache_meta, "bypass") AND local.a.cache_meta.bypass
                    ? "bypass"
                    : (structKeyExists(local.a.cache_meta, "hit") AND local.a.cache_meta.hit ? "hit" : "miss")
                )
                : ""
            )>
            <cfset local.s = getSurfaceObservations(arguments.lat, arguments.lon)>
            <cfset tMetar = (structKeyExists(request, "_fpwWeatherTimingMetarMs") ? val(request._fpwWeatherTimingMetarMs) : 0)>
            <cfset metarCacheFlag = (structKeyExists(request, "_fpwWeatherTimingMetarCache") ? toString(request._fpwWeatherTimingMetarCache) : "")>
            <cfif structKeyExists(local.f, "FORECAST") AND isArray(local.f.FORECAST)>
                <cfset local.out.FORECAST = local.f.FORECAST>
            </cfif>
            <cfif structKeyExists(local.a, "ALERTS") AND isArray(local.a.ALERTS)>
                <cfset local.out.ALERTS = local.a.ALERTS>
            </cfif>
            <cfif isStruct(local.s)>
                <cfset local.out.surface = local.s>
            </cfif>
            <cfset local.out.MAP_LAYERS = getNowCoastBaseLayers()>
            <cfset local.out.SUMMARY = buildBoaterSummary(local.out.FORECAST, local.out.ALERTS)>
        </cfif>

        <cfif isStruct(local.m) AND structCount(local.m) GT 0>
            <cfset local.out.MARINE = local.m>
        </cfif>

        <cfif NOT local.isQuickMarineMode>
            <cfset local.out.ZONE_FORECAST = getMarineZoneForecastCached(arguments.lat, arguments.lon, local.noCache)>
        <cfelse>
            <cfset local.out.ZONE_FORECAST = {} >
        </cfif>

        <cfset local.out.META.anchor = { "lat"=arguments.lat, "lon"=arguments.lon }>
        <cfif len(arguments.requestZip)>
            <cfset local.out.META.request = { "zip"=arguments.requestZip }>
        </cfif>
        <cfif arguments.includeGeocodeSource AND isStruct(arguments.geocodeSourceMeta)>
            <cfif structKeyExists(arguments.geocodeSourceMeta, "resolved_city") AND len(trim(toString(arguments.geocodeSourceMeta.resolved_city)))>
                <cfset local.out.META.resolved_city = trim(toString(arguments.geocodeSourceMeta.resolved_city))>
            </cfif>
            <cfif structKeyExists(arguments.geocodeSourceMeta, "resolved_state") AND len(trim(toString(arguments.geocodeSourceMeta.resolved_state)))>
                <cfset local.out.META.resolved_state = trim(toString(arguments.geocodeSourceMeta.resolved_state))>
            </cfif>
            <cfif structKeyExists(arguments.geocodeSourceMeta, "resolved_place") AND len(trim(toString(arguments.geocodeSourceMeta.resolved_place)))>
                <cfset local.out.META.resolved_place = trim(toString(arguments.geocodeSourceMeta.resolved_place))>
            </cfif>
            <cfif structKeyExists(arguments.geocodeSourceMeta, "resolved_display") AND len(trim(toString(arguments.geocodeSourceMeta.resolved_display)))>
                <cfset local.out.META.resolved_display = trim(toString(arguments.geocodeSourceMeta.resolved_display))>
            </cfif>
            <cfif structKeyExists(arguments.geocodeSourceMeta, "resolved_zip") AND len(trim(toString(arguments.geocodeSourceMeta.resolved_zip)))>
                <cfset local.out.META.resolved_zip = trim(toString(arguments.geocodeSourceMeta.resolved_zip))>
            </cfif>
            <cfif structKeyExists(arguments.geocodeSourceMeta, "resolved_source") AND len(trim(toString(arguments.geocodeSourceMeta.resolved_source)))>
                <cfset local.out.META.resolved_source = trim(toString(arguments.geocodeSourceMeta.resolved_source))>
            </cfif>
        </cfif>
        <cfset local.out.META.sources = {} >
        <cfif arguments.includeGeocodeSource>
            <cfset local.out.META.sources.geocode = arguments.geocodeSourceMeta>
        </cfif>
        <cfset local.out.META.sources.forecast = (NOT arguments.marineOnly AND structKeyExists(local.f, "META") ? local.f.META : {})>
        <cfset local.out.META.sources.alerts   = (NOT arguments.marineOnly AND structKeyExists(local.a, "META") ? local.a.META : {})>
        <cfset local.out.META.sources.surface  = (NOT arguments.marineOnly AND isStruct(local.s) ? { "source"="METAR" } : {})>
        <cfset local.out.META.sources.marine   = (structKeyExists(local.m, "META") ? local.m.META : {})>
        <cfif local.waveTest.enabled>
            <cfif NOT isStruct(local.out.META.sources.marine)>
                <cfset local.out.META.sources.marine = {} >
            </cfif>
            <cfset local.out.META.sources.marine.waveTestOverride = local.waveTest.value>
        </cfif>
        <cfset local.out.META.cache = buildWeatherCacheReport(local.out, local.f, local.a, local.s, local.m, local.out.ZONE_FORECAST)>

        <cfset local.out.SUCCESS = true>
        <cfset local.out.MESSAGE = "OK">
        <cfscript>
            weatherTimingLine = "[FPW_WEATHER_TIMING] total=" & (getTickCount() - tWeatherTotalStart) & "ms"
                & " marine=" & tMarine & "ms"
                & " forecast=" & tForecast & "ms"
                & " alerts=" & tAlerts & "ms"
                & " metar=" & tMetar & "ms";
            if (len(marineCacheFlag)) weatherTimingLine &= " marineCache=" & marineCacheFlag;
            if (len(forecastCacheFlag)) weatherTimingLine &= " forecastCache=" & forecastCacheFlag;
            if (len(alertsCacheFlag)) weatherTimingLine &= " alertsCache=" & alertsCacheFlag;
            if (len(metarCacheFlag)) weatherTimingLine &= " metarCache=" & metarCacheFlag;
            writeLog(file="fpw-weather-timing", text=weatherTimingLine, type="information");
        </cfscript>
        <cfset structDelete(request, "_fpwWeatherTimingMetarMs", false)>
        <cfset structDelete(request, "_fpwWeatherTimingMetarCache", false)>
        <cfreturn local.out>
    </cffunction>

    <cffunction name="resolveWaveTestOverride" access="private" returntype="struct" output="false">
        <cfset local.out = { "enabled"=false, "value"=0 } >
        <cfset local.raw = "" >

        <cfif isDefined("url.waveTestFt")>
            <cfset local.raw = trim(toString(url.waveTestFt))>
        </cfif>

        <cfif len(local.raw) AND isNumeric(local.raw) AND val(local.raw) GTE 0>
            <cfset local.out.enabled = true>
            <cfset local.out.value = round(val(local.raw) * 10) / 10>
        </cfif>

        <cfreturn local.out>
    </cffunction>

    <cffunction name="readRequestParamValue" access="private" returntype="string" output="false">
        <cfargument name="argStruct" type="struct" required="true">
        <cfargument name="keys" type="array" required="true">

        <cfset local.out = "">
        <cfset local.k = "">

        <cfloop from="1" to="#arrayLen(arguments.keys)#" index="local.i">
            <cfset local.k = toString(arguments.keys[local.i])>
            <cfif structKeyExists(arguments.argStruct, local.k) AND len(trim(toString(arguments.argStruct[local.k])))>
                <cfset local.out = trim(toString(arguments.argStruct[local.k]))>
                <cfreturn local.out>
            </cfif>
            <cfif structKeyExists(url, local.k) AND len(trim(toString(url[local.k])))>
                <cfset local.out = trim(toString(url[local.k]))>
                <cfreturn local.out>
            </cfif>
        </cfloop>

        <cfreturn local.out>
    </cffunction>

    <cffunction name="parseSearchCoordinate" access="private" returntype="struct" output="false">
        <cfargument name="rawVal" type="any" required="true">
        <cfargument name="minVal" type="numeric" required="true">
        <cfargument name="maxVal" type="numeric" required="true">
        <cfargument name="errorCode" type="string" required="true">
        <cfargument name="fieldLabel" type="string" required="true">

        <cfset local.raw = trim(toString(arguments.rawVal))>
        <cfset local.value = 0>
        <cfset local.out = {
            "SUCCESS"=false,
            "MESSAGE"=arguments.fieldLabel & " is invalid.",
            "VALUE"=0,
            "ERROR"={
                "CODE"=arguments.errorCode,
                "DETAIL"=arguments.fieldLabel & " must be a number between " & arguments.minVal & " and " & arguments.maxVal & "."
            }
        }>

        <cfif NOT len(local.raw)>
            <cfset local.out.ERROR.DETAIL = arguments.fieldLabel & " is required.">
            <cfreturn local.out>
        </cfif>

        <cfif NOT isNumeric(local.raw)>
            <cfset local.out.ERROR.DETAIL = arguments.fieldLabel & " must be numeric.">
            <cfreturn local.out>
        </cfif>

        <cfset local.value = val(local.raw)>
        <cfif local.value LT arguments.minVal OR local.value GT arguments.maxVal>
            <cfset local.out.ERROR.DETAIL = arguments.fieldLabel & " must be between " & arguments.minVal & " and " & arguments.maxVal & ".">
            <cfreturn local.out>
        </cfif>

        <cfset local.out.SUCCESS = true>
        <cfset local.out.MESSAGE = "OK">
        <cfset local.out.VALUE = local.value>
        <cfset structDelete(local.out, "ERROR", false)>
        <cfreturn local.out>
    </cffunction>

    <cffunction name="appendSearchResolutionMeta" access="private" returntype="struct" output="false">
        <cfargument name="payload" type="struct" required="true">
        <cfargument name="locationType" type="string" required="true">
        <cfargument name="resolvedLat" type="any" required="false" default="">
        <cfargument name="resolvedLon" type="any" required="false" default="">
        <cfargument name="requestEcho" type="struct" required="false" default="#{}#">

        <cfset local.out = arguments.payload>
        <cfset local.rLat = 0>
        <cfset local.rLon = 0>
        <cfset local.reqKeys = []>

        <cfif NOT structKeyExists(local.out, "META") OR NOT isStruct(local.out.META)>
            <cfset local.out.META = {} >
        </cfif>

        <cfset local.out.META.resolved_location_type = trim(arguments.locationType)>
        <cfif isNumeric(arguments.resolvedLat)>
            <cfset local.rLat = round(val(arguments.resolvedLat) * 1000000) / 1000000>
            <cfset local.out.META.resolved_lat = local.rLat>
        </cfif>
        <cfif isNumeric(arguments.resolvedLon)>
            <cfset local.rLon = round(val(arguments.resolvedLon) * 1000000) / 1000000>
            <cfset local.out.META.resolved_lon = local.rLon>
        </cfif>

        <cfif isStruct(arguments.requestEcho) AND structCount(arguments.requestEcho) GT 0>
            <cfif NOT structKeyExists(local.out.META, "request") OR NOT isStruct(local.out.META.request)>
                <cfset local.out.META.request = {} >
            </cfif>
            <cfset local.reqKeys = structKeyArray(arguments.requestEcho)>
            <cfloop from="1" to="#arrayLen(local.reqKeys)#" index="local.i">
                <cfset local.reqKey = local.reqKeys[local.i]>
                <cfset local.out.META.request[local.reqKey] = arguments.requestEcho[local.reqKey]>
            </cfloop>
        </cfif>

        <cfreturn local.out>
    </cffunction>

    <!--- =========================
          Anchor lookup
    ========================== --->
    <cffunction name="resolveFloatPlanAnchor" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">

        <cfset local.r = { "SUCCESS"=false, "MESSAGE"="", "LAT"=0, "LON"=0 }>

        <cftry>
            <cfquery name="q" datasource="#application.dsn#">
                SELECT departureLat, departureLon, returnLat, returnLon
                FROM floatplans
                WHERE floatPlanId = <cfqueryparam value="#arguments.floatPlanId#" cfsqltype="cf_sql_integer">
                  AND userId      = <cfqueryparam value="#arguments.userId#"      cfsqltype="cf_sql_integer">
                LIMIT 1
            </cfquery>

            <cfif q.recordCount EQ 0>
                <cfset local.r.MESSAGE = "Float plan not found or not owned by user.">
                <cfreturn local.r>
            </cfif>

            <cfif len(q.departureLat) AND len(q.departureLon)>
                <cfset local.r.LAT = val(q.departureLat)>
                <cfset local.r.LON = val(q.departureLon)>
                <cfset local.r.SUCCESS = true>
                <cfset local.r.MESSAGE = "OK">
                <cfreturn local.r>
            </cfif>

            <cfif len(q.returnLat) AND len(q.returnLon)>
                <cfset local.r.LAT = val(q.returnLat)>
                <cfset local.r.LON = val(q.returnLon)>
                <cfset local.r.SUCCESS = true>
                <cfset local.r.MESSAGE = "OK">
                <cfreturn local.r>
            </cfif>

            <cfset local.r.MESSAGE = "No coordinates set on this plan (departureLat/departureLon or returnLat/returnLon).">
            <cfreturn local.r>

            <cfcatch>
                <cflog
                    file="fpw-weather"
                    type="error"
                    text="[FPW][WEATHER] resolveFloatPlanAnchor :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
                <cfif NOT structKeyExists(local.r, "META") OR NOT isStruct(local.r.META)>
                    <cfset local.r.META = {} >
                </cfif>
                <cfif NOT structKeyExists(local.r.META, "warnings") OR NOT isArray(local.r.META.warnings)>
                    <cfset local.r.META.warnings = []>
                </cfif>
                <cfset arrayAppend(local.r.META.warnings, {
                    "code"="WEATHER_EXCEPTION",
                    "where"="resolveFloatPlanAnchor",
                    "message"=cfcatch.message
                })>
                <cfset local.r.MESSAGE = "Anchor lookup failed: " & cfcatch.message>
                <cfreturn local.r>
            </cfcatch>
        </cftry>
    </cffunction>

    <!--- =========================
          ZIP Geocode
    ========================== --->
    <cffunction name="geocodeZip" access="private" returntype="struct" output="false">
        <cfargument name="zip" type="string" required="true">

        <cfset local.r = { "SUCCESS"=false, "MESSAGE"="", "LAT"=0, "LON"=0, "META"={} }>
        <cfset local.ua = getNwsUserAgent()>
        <cfset local.zip5 = rereplace(trim(arguments.zip), "[^0-9]", "", "all")>
        <cfif len(local.zip5) NEQ 5>
            <cfset local.zip5 = trim(arguments.zip)>
        </cfif>
        <cfset local.lockZip = (len(local.zip5) ? local.zip5 : "unknown")>
        <cfset local.cacheKey = "wx_geocode_zip:" & local.lockZip>
        <cfset local.lockName = "fpw.weather.geocode.zip." & local.lockZip>
        <cfset local.url = "https://geocoding.geo.census.gov/geocoder/locations/onelineaddress?address=" & urlEncodedFormat(local.zip5 & " USA") & "&benchmark=Public_AR_Current&format=json">
        <cfset local.httpStatus = 0>
        <cfset local.obj = {} >
        <cfset local.match = {} >
        <cfset local.zurl = "https://api.zippopotam.us/us/" & urlEncodedFormat(local.zip5)>
        <cfset local.zstatus = 0>
        <cfset local.zobj = {} >
        <cfset local.resolvedCity = "">
        <cfset local.resolvedState = "">
        <cfset local.resolvedPlace = "">
        <cfset local.resolvedDisplay = "">
        <cfset local.hasSummary = (structKeyExists(request, "_wxRequestSummary") AND isStruct(request._wxRequestSummary))>

        <cflock name="#local.lockName#" type="exclusive" timeout="20">
            <cfset local.cached = marineCacheGet(local.cacheKey, 3600)>
            <cfif isStruct(local.cached)
                AND structKeyExists(local.cached, "LAT")
                AND structKeyExists(local.cached, "LON")
                AND structKeyExists(local.cached, "SOURCE")
                AND structKeyExists(local.cached, "META_VERSION")
                AND val(local.cached.META_VERSION) GTE 2>
                <cfset local.r.LAT = val(local.cached.LAT)>
                <cfset local.r.LON = val(local.cached.LON)>
                <cfset local.r.SUCCESS = true>
                <cfset local.r.MESSAGE = "OK">
                <cfset local.r.META = {
                    "source"=toString(local.cached.SOURCE),
                    "url"=(structKeyExists(local.cached, "URL") ? toString(local.cached.URL) : ""),
                    "status"=(structKeyExists(local.cached, "STATUS") ? val(local.cached.STATUS) : 0),
                    "resolved_city"=(structKeyExists(local.cached, "RESOLVED_CITY") ? toString(local.cached.RESOLVED_CITY) : ""),
                    "resolved_state"=(structKeyExists(local.cached, "RESOLVED_STATE") ? toString(local.cached.RESOLVED_STATE) : ""),
                    "resolved_place"=(structKeyExists(local.cached, "RESOLVED_PLACE") ? toString(local.cached.RESOLVED_PLACE) : ""),
                    "resolved_display"=(structKeyExists(local.cached, "RESOLVED_DISPLAY") ? toString(local.cached.RESOLVED_DISPLAY) : ""),
                    "resolved_zip"=(structKeyExists(local.cached, "RESOLVED_ZIP") ? toString(local.cached.RESOLVED_ZIP) : local.zip5),
                    "resolved_source"=toString(local.cached.SOURCE)
                }>
                <cfif local.hasSummary>
                    <cfset request._wxRequestSummary.geocodeCache = "hit">
                    <cfset request._wxRequestSummary.geocodeProvider = toString(local.cached.SOURCE)>
                </cfif>
                <cfreturn local.r>
            </cfif>

            <cfhttp url="#local.url#" method="get" result="gRes" timeout="15">
                <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
                <cfhttpparam type="header" name="Accept" value="application/json">
            </cfhttp>

            <cfset local.httpStatus = val(gRes.statusCode)>
            <cfif local.httpStatus GTE 200 AND local.httpStatus LT 300>
                <cftry>
                    <cfset local.obj = deserializeJSON(gRes.fileContent)>
                    <cfif structKeyExists(local.obj, "result") AND structKeyExists(local.obj.result, "addressMatches") AND isArray(local.obj.result.addressMatches) AND arrayLen(local.obj.result.addressMatches) GT 0>
                        <cfset local.match = local.obj.result.addressMatches[1]>
                        <cfif structKeyExists(local.match, "coordinates") AND structKeyExists(local.match.coordinates, "x") AND structKeyExists(local.match.coordinates, "y")>
                            <cfset local.r.LON = val(local.match.coordinates.x)>
                            <cfset local.r.LAT = val(local.match.coordinates.y)>
                            <cfset local.resolvedCity = "">
                            <cfset local.resolvedState = "">
                            <cfset local.resolvedPlace = "">
                            <cfset local.resolvedDisplay = "">
                            <cfif structKeyExists(local.match, "addressComponents") AND isStruct(local.match.addressComponents)>
                                <cfset local.resolvedCity = (structKeyExists(local.match.addressComponents, "city") ? trim(toString(local.match.addressComponents.city)) : "")>
                                <cfset local.resolvedState = (structKeyExists(local.match.addressComponents, "state") ? trim(toString(local.match.addressComponents.state)) : "")>
                                <cfset local.resolvedPlace = local.resolvedCity>
                            </cfif>
                            <cfif len(local.resolvedPlace)>
                                <cfset local.resolvedDisplay = local.resolvedPlace & (len(local.resolvedState) ? ", " & local.resolvedState : "")>
                            <cfelseif structKeyExists(local.match, "matchedAddress")>
                                <cfset local.resolvedDisplay = trim(toString(local.match.matchedAddress))>
                            </cfif>
                            <cfset local.r.SUCCESS = true>
                            <cfset local.r.MESSAGE = "OK">
                            <cfset local.r.META = {
                                "source"="Census",
                                "url"=local.url,
                                "status"=local.httpStatus,
                                "resolved_city"=local.resolvedCity,
                                "resolved_state"=local.resolvedState,
                                "resolved_place"=local.resolvedPlace,
                                "resolved_display"=local.resolvedDisplay,
                                "resolved_zip"=local.zip5,
                                "resolved_source"="Census"
                            }>
                            <cfset marineCacheSet(local.cacheKey, {
                                "LAT"=local.r.LAT,
                                "LON"=local.r.LON,
                                "SOURCE"="Census",
                                "STATUS"=local.httpStatus,
                                "URL"=local.url,
                                "RESOLVED_CITY"=local.resolvedCity,
                                "RESOLVED_STATE"=local.resolvedState,
                                "RESOLVED_PLACE"=local.resolvedPlace,
                                "RESOLVED_DISPLAY"=local.resolvedDisplay,
                                "RESOLVED_ZIP"=local.zip5,
                                "META_VERSION"=2
                            })>
                            <cfif local.hasSummary>
                                <cfset request._wxRequestSummary.geocodeCache = "miss">
                                <cfset request._wxRequestSummary.geocodeProvider = "Census">
                            </cfif>
                            <cfreturn local.r>
                        </cfif>
                    </cfif>
                    <cfcatch>
                        <cflog
                            file="fpw-weather"
                            type="error"
                            text="[FPW][WEATHER] geocodeZip:census_deserialize :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
                        <cfif NOT structKeyExists(local.r, "META") OR NOT isStruct(local.r.META)>
                            <cfset local.r.META = {} >
                        </cfif>
                        <cfif NOT structKeyExists(local.r.META, "warnings") OR NOT isArray(local.r.META.warnings)>
                            <cfset local.r.META.warnings = []>
                        </cfif>
                        <cfset arrayAppend(local.r.META.warnings, {
                            "code"="WEATHER_EXCEPTION",
                            "where"="geocodeZip:census_deserialize",
                            "message"=cfcatch.message
                        })>
                    </cfcatch>
                </cftry>
            </cfif>

            <!--- Fallback: Zippopotam.us --->
            <cfhttp url="#local.zurl#" method="get" result="zRes" timeout="15">
                <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
                <cfhttpparam type="header" name="Accept" value="application/json">
            </cfhttp>

            <cfset local.zstatus = val(zRes.statusCode)>
            <cfif local.zstatus GTE 200 AND local.zstatus LT 300>
                <cftry>
                    <cfset local.zobj = deserializeJSON(zRes.fileContent)>
                    <cfif structKeyExists(local.zobj, "places") AND isArray(local.zobj.places) AND arrayLen(local.zobj.places) GT 0>
                        <cfset local.match = local.zobj.places[1]>
                        <cfif structKeyExists(local.match, "longitude") AND structKeyExists(local.match, "latitude")>
                            <cfset local.r.LON = val(local.match.longitude)>
                            <cfset local.r.LAT = val(local.match.latitude)>
                            <cfset local.resolvedPlace = (structKeyExists(local.match, "place name") ? trim(toString(local.match["place name"])) : "")>
                            <cfset local.resolvedCity = local.resolvedPlace>
                            <cfset local.resolvedState = (structKeyExists(local.match, "state abbreviation") ? trim(toString(local.match["state abbreviation"])) : "")>
                            <cfset local.resolvedDisplay = (len(local.resolvedPlace) ? local.resolvedPlace & (len(local.resolvedState) ? ", " & local.resolvedState : "") : "")>
                            <cfset local.r.SUCCESS = true>
                            <cfset local.r.MESSAGE = "OK">
                            <cfset local.r.META = {
                                "source"="Zippopotam",
                                "url"=local.zurl,
                                "status"=local.zstatus,
                                "resolved_city"=local.resolvedCity,
                                "resolved_state"=local.resolvedState,
                                "resolved_place"=local.resolvedPlace,
                                "resolved_display"=local.resolvedDisplay,
                                "resolved_zip"=local.zip5,
                                "resolved_source"="Zippopotam"
                            }>
                            <cfset marineCacheSet(local.cacheKey, {
                                "LAT"=local.r.LAT,
                                "LON"=local.r.LON,
                                "SOURCE"="Zippopotam",
                                "STATUS"=local.zstatus,
                                "URL"=local.zurl,
                                "RESOLVED_CITY"=local.resolvedCity,
                                "RESOLVED_STATE"=local.resolvedState,
                                "RESOLVED_PLACE"=local.resolvedPlace,
                                "RESOLVED_DISPLAY"=local.resolvedDisplay,
                                "RESOLVED_ZIP"=local.zip5,
                                "META_VERSION"=2
                            })>
                            <cfif local.hasSummary>
                                <cfset request._wxRequestSummary.geocodeCache = "miss">
                                <cfset request._wxRequestSummary.geocodeProvider = "Zippopotam">
                            </cfif>
                            <cfreturn local.r>
                        </cfif>
                    </cfif>
                    <cfcatch>
                        <cflog
                            file="fpw-weather"
                            type="error"
                            text="[FPW][WEATHER] geocodeZip:zippopotam_deserialize :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
                        <cfif NOT structKeyExists(local.r, "META") OR NOT isStruct(local.r.META)>
                            <cfset local.r.META = {} >
                        </cfif>
                        <cfif NOT structKeyExists(local.r.META, "warnings") OR NOT isArray(local.r.META.warnings)>
                            <cfset local.r.META.warnings = []>
                        </cfif>
                        <cfset arrayAppend(local.r.META.warnings, {
                            "code"="WEATHER_EXCEPTION",
                            "where"="geocodeZip:zippopotam_deserialize",
                            "message"=cfcatch.message
                        })>
                    </cfcatch>
                </cftry>
            </cfif>

            <cfset local.r.MESSAGE = "ZIP not found.">
            <cfset local.r.ERROR = { "SOURCE"="Census/Zippopotam", "DETAIL"="No matches returned.", "CENSUS_STATUS"=local.httpStatus, "ZIP_STATUS"=local.zstatus }>
            <cfset local.r.META = { "source"="Census/Zippopotam", "url"=local.url, "status"=local.httpStatus }>
            <cfif local.hasSummary>
                <cfset request._wxRequestSummary.geocodeCache = "miss">
                <cfset request._wxRequestSummary.geocodeProvider = "none">
            </cfif>
            <cfreturn local.r>
        </cflock>
    </cffunction>

    <!--- =========================
          NOAA / NWS calls
    ========================== --->
    <cffunction name="getNwsForecast" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lon" type="numeric" required="true">
        <cfargument name="opts" type="struct" required="false" default="#structNew()#">

        <cfset local.out = { "FORECAST"=[], "META"={} }>
        <cfset local.pointsUrl = "https://api.weather.gov/points/" & arguments.lat & "," & arguments.lon>
        <cfset local.fetch = {} >
        <cfset local.gustGrid = { "SUCCESS"=false, "VALUES"=[], "UNIT"="", "META"={} }>
        <cfset local.meta = {} >
        <cfset local.ttlSeconds = 900>
        <cfset local.bypassCache = shouldBypassWeatherCache()>

        <cfif isStruct(arguments.opts) AND structKeyExists(arguments.opts, "ttlSeconds") AND isNumeric(arguments.opts.ttlSeconds)>
            <cfset local.ttlSeconds = int(val(arguments.opts.ttlSeconds))>
        </cfif>
        <cfif isStruct(arguments.opts) AND structKeyExists(arguments.opts, "bypassCache")>
            <cfset local.bypassCache = (isBoolean(arguments.opts.bypassCache) ? arguments.opts.bypassCache : (val(arguments.opts.bypassCache) EQ 1))>
        </cfif>

        <cfset local.fetch = getWeatherCacheService().getNwsForecastCached(arguments.lat, arguments.lon, local.ttlSeconds, local.bypassCache)>

        <cfif isStruct(local.fetch) AND structKeyExists(local.fetch, "cache_meta") AND isStruct(local.fetch.cache_meta)>
            <cfset local.out.cache_meta = local.fetch.cache_meta>
        </cfif>

        <cfif NOT isStruct(local.fetch)>
            <cfset local.out.META = { "source"="NWS", "step"="points", "status"=0, "url"=local.pointsUrl }>
            <cfif structKeyExists(local.out, "cache_meta")>
                <cfset local.out.META.cache_meta = local.out.cache_meta>
            </cfif>
            <cfreturn local.out>
        </cfif>

        <cfif NOT structKeyExists(local.fetch, "success") OR NOT local.fetch.success>
            <cfif structKeyExists(local.fetch, "step") AND local.fetch.step EQ "forecast">
                <cfset local.out.META = {
                    "source"="NWS",
                    "step"="forecast",
                    "status"=(structKeyExists(local.fetch, "forecast_status") ? val(local.fetch.forecast_status) : 0),
                    "url"=(structKeyExists(local.fetch, "forecast_url") ? toString(local.fetch.forecast_url) : "")
                }>
            <cfelse>
                <cfset local.out.META = {
                    "source"="NWS",
                    "step"="points",
                    "status"=(structKeyExists(local.fetch, "points_status") ? val(local.fetch.points_status) : 0),
                    "url"=(structKeyExists(local.fetch, "points_url") ? toString(local.fetch.points_url) : local.pointsUrl)
                }>
                <cfif structKeyExists(local.fetch, "note") AND len(trim(toString(local.fetch.note)))>
                    <cfset local.out.META.note = trim(toString(local.fetch.note))>
                </cfif>
            </cfif>
            <cfif structKeyExists(local.out, "cache_meta")>
                <cfset local.out.META.cache_meta = local.out.cache_meta>
            </cfif>
            <cfreturn local.out>
        </cfif>

        <cfif structKeyExists(local.fetch, "grid_url") AND len(trim(toString(local.fetch.grid_url)))>
            <cfif structKeyExists(local.fetch, "grid_status") AND val(local.fetch.grid_status) GTE 200 AND val(local.fetch.grid_status) LT 300>
                <cfset local.gustGrid = normalizeNwsGustGrid(
                    structKeyExists(local.fetch, "grid_body") ? toString(local.fetch.grid_body) : "",
                    {
                        "source"="NWS",
                        "step"="forecastGridData",
                        "url"=trim(toString(local.fetch.grid_url)),
                        "status"=val(local.fetch.grid_status)
                    }
                )>
            <cfelse>
                <cfset local.gustGrid.META = {
                    "source"="NWS",
                    "step"="forecastGridData",
                    "url"=trim(toString(local.fetch.grid_url)),
                    "status"=(structKeyExists(local.fetch, "grid_status") ? val(local.fetch.grid_status) : 0),
                    "note"="Grid request failed"
                }>
            </cfif>
        </cfif>

        <cfset local.meta = {
            "source"="NWS",
            "url"=(structKeyExists(local.fetch, "forecast_url") ? toString(local.fetch.forecast_url) : ""),
            "status"=(structKeyExists(local.fetch, "forecast_status") ? val(local.fetch.forecast_status) : 0)
        }>
        <cfif isStruct(local.gustGrid) AND structKeyExists(local.gustGrid, "META")>
            <cfset local.meta.gust = local.gustGrid.META>
        </cfif>
        <cfif structKeyExists(local.out, "cache_meta")>
            <cfset local.meta.cache_meta = local.out.cache_meta>
        </cfif>

        <cfset local.out = normalizeNwsForecast(
            structKeyExists(local.fetch, "forecast_body") ? toString(local.fetch.forecast_body) : "",
            local.meta,
            local.gustGrid
        )>
        <cfif structKeyExists(local.fetch, "cache_meta") AND isStruct(local.fetch.cache_meta)>
            <cfset local.out.cache_meta = local.fetch.cache_meta>
            <cfif structKeyExists(local.out, "META") AND isStruct(local.out.META)>
                <cfset local.out.META.cache_meta = local.fetch.cache_meta>
            </cfif>
        </cfif>
        <cfreturn local.out>
    </cffunction>

    <cffunction name="getNwsAlerts" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lon" type="numeric" required="true">
        <cfargument name="opts" type="struct" required="false" default="#structNew()#">

        <cfset local.out = { "ALERTS"=[], "META"={} }>
        <cfset local.url = "https://api.weather.gov/alerts/active?point=" & arguments.lat & "," & arguments.lon>
        <cfset local.ttlSeconds = 300>
        <cfset local.bypassCache = shouldBypassWeatherCache()>
        <cfset local.fetch = {} >

        <cfif isStruct(arguments.opts) AND structKeyExists(arguments.opts, "ttlSeconds") AND isNumeric(arguments.opts.ttlSeconds)>
            <cfset local.ttlSeconds = int(val(arguments.opts.ttlSeconds))>
        </cfif>
        <cfif isStruct(arguments.opts) AND structKeyExists(arguments.opts, "bypassCache")>
            <cfset local.bypassCache = (isBoolean(arguments.opts.bypassCache) ? arguments.opts.bypassCache : (val(arguments.opts.bypassCache) EQ 1))>
        </cfif>

        <cfset local.fetch = getWeatherCacheService().getNwsAlertsCached(arguments.lat, arguments.lon, local.ttlSeconds, local.bypassCache)>
        <cfif isStruct(local.fetch) AND structKeyExists(local.fetch, "cache_meta") AND isStruct(local.fetch.cache_meta)>
            <cfset local.out.cache_meta = local.fetch.cache_meta>
        </cfif>

        <cfif NOT isStruct(local.fetch) OR NOT structKeyExists(local.fetch, "success") OR NOT local.fetch.success>
            <cfset local.out.META = {
                "source"="NWS",
                "status"=(isStruct(local.fetch) AND structKeyExists(local.fetch, "status") ? val(local.fetch.status) : 0),
                "url"=(isStruct(local.fetch) AND structKeyExists(local.fetch, "url") ? toString(local.fetch.url) : local.url)
            }>
            <cfif structKeyExists(local.out, "cache_meta")>
                <cfset local.out.META.cache_meta = local.out.cache_meta>
            </cfif>
            <cfreturn local.out>
        </cfif>

        <cfset local.out = normalizeNwsAlerts(
            (structKeyExists(local.fetch, "body") ? toString(local.fetch.body) : ""),
            {
                "source"="NWS",
                "url"=(structKeyExists(local.fetch, "url") ? toString(local.fetch.url) : local.url),
                "status"=(structKeyExists(local.fetch, "status") ? val(local.fetch.status) : 0)
            }
        )>
        <cfif structKeyExists(local.fetch, "cache_meta") AND isStruct(local.fetch.cache_meta)>
            <cfset local.out.cache_meta = local.fetch.cache_meta>
            <cfif structKeyExists(local.out, "META") AND isStruct(local.out.META)>
                <cfset local.out.META.cache_meta = local.fetch.cache_meta>
            </cfif>
        </cfif>
        <cfreturn local.out>
    </cffunction>

    <!--- METAR surface observations normalized for dashboard pressure/visibility cards. --->
    <cffunction name="getSurfaceObservations" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lon" type="numeric" required="true">
        <cfset local.out = {
            "pressure_inhg"="",
            "visibility_mi"="",
            "station_id"="",
            "observation_time"="",
                "dewpoint_f"="",
                "humidity"="",
            "pressure_rate_per_hr"=javacast("null", ""),
            "pressure_delta"=javacast("null", ""),
            "pressure_trend"=javacast("null", "")
        }>
        <cfset local.metar = {} >
        <cfset local.current = {} >
        <cfset local.previous = {} >
        <cfset local.currentPressure = "" >
        <cfset local.previousPressure = "" >
        <cfset local.currentObs = "" >
        <cfset local.previousObs = "" >
        <cfset local.deltaPressure = "" >
        <cfset local.hoursBetween = 0 >
        <cfset local.ratePerHour = "" >
        <cfset local.obsTimesDistinct = false >
        <cfset local.maxAbsRatePerHour = 0.30 >
        <cfset local.metarTimingStart = getTickCount()>
        <cfset local.metar = getWeatherCacheService().getMetar(arguments.lat, arguments.lon)>
        <cfset request._fpwWeatherTimingMetarMs = getTickCount() - local.metarTimingStart>
        <cfif isStruct(local.metar) AND structKeyExists(local.metar, "cache_meta") AND isStruct(local.metar.cache_meta)>
            <cfset request._fpwWeatherTimingMetarCache = (
                structKeyExists(local.metar.cache_meta, "bypass") AND local.metar.cache_meta.bypass
                ? "bypass"
                : (structKeyExists(local.metar.cache_meta, "hit") AND local.metar.cache_meta.hit ? "hit" : "miss")
            )>
            <cfset local.out.cache_meta = local.metar.cache_meta>
        </cfif>

        <cfif NOT isStruct(local.metar)>
            <cfreturn local.out>
        </cfif>

        <cfif structKeyExists(local.metar, "current") AND isStruct(local.metar.current)>
            <cfset local.current = local.metar.current>
        <cfelse>
            <cfset local.current = local.metar>
        </cfif>
        <cfif structKeyExists(local.metar, "previous") AND isStruct(local.metar.previous)>
            <cfset local.previous = local.metar.previous>
        </cfif>

        <cfif structKeyExists(local.current, "altim") AND len(trim(toString(local.current.altim)))>
            <cfset local.out.pressure_inhg = trim(toString(local.current.altim))>
        </cfif>
        <cfif structKeyExists(local.current, "visib") AND len(trim(toString(local.current.visib)))>
            <cfset local.out.visibility_mi = trim(toString(local.current.visib))>
        </cfif>
        <cfif structKeyExists(local.current, "station") AND len(trim(toString(local.current.station)))>
            <cfset local.out.station_id = trim(toString(local.current.station))>
        </cfif>
        <cfif structKeyExists(local.current, "observation_time") AND len(trim(toString(local.current.observation_time)))>
            <cfset local.out.observation_time = trim(toString(local.current.observation_time))>
        </cfif>
        <cfif structKeyExists(local.current, "dewpoint_f") AND len(trim(toString(local.current.dewpoint_f)))>
            <cfset local.out.dewpoint_f = trim(toString(local.current.dewpoint_f))>
        </cfif>
        <cfif structKeyExists(local.current, "humidity") AND len(trim(toString(local.current.humidity)))>
            <cfset local.out.humidity = trim(toString(local.current.humidity))>
        </cfif>

        <cfif structKeyExists(local.current, "altim") AND isNumeric(local.current.altim)>
            <cfset local.currentPressure = val(local.current.altim)>
        </cfif>
        <cfif structKeyExists(local.previous, "altim") AND isNumeric(local.previous.altim)>
            <cfset local.previousPressure = val(local.previous.altim)>
        </cfif>

        <cfif structKeyExists(local.current, "observation_time")>
            <cfset local.currentObs = parseSurfaceObservationTime(local.current.observation_time)>
        </cfif>
        <cfif structKeyExists(local.previous, "observation_time")>
            <cfset local.previousObs = parseSurfaceObservationTime(local.previous.observation_time)>
        </cfif>

        <cfif isDate(local.currentObs) AND isDate(local.previousObs) AND isNumeric(local.currentPressure) AND isNumeric(local.previousPressure)>
            <cfset local.obsTimesDistinct = (dateDiff("s", local.previousObs, local.currentObs) GT 0)>
            <cfset local.hoursBetween = dateDiff("s", local.previousObs, local.currentObs) / 3600>
            <cfif local.obsTimesDistinct AND local.hoursBetween GTE 0.25>
                <cfset local.deltaPressure = local.currentPressure - local.previousPressure>
                <cfset local.ratePerHour = local.deltaPressure / local.hoursBetween>
                <cfif abs(local.ratePerHour) LTE local.maxAbsRatePerHour>
                    <cfset local.out.pressure_delta = round(local.deltaPressure * 1000) / 1000>
                    <cfset local.out.pressure_rate_per_hr = round(local.ratePerHour * 1000) / 1000>
                    <cfif local.ratePerHour LTE -0.06>
                        <cfset local.out.pressure_trend = "rapid_fall">
                    <cfelseif local.ratePerHour LT -0.01>
                        <cfset local.out.pressure_trend = "falling">
                    <cfelseif abs(local.ratePerHour) LTE 0.01>
                        <cfset local.out.pressure_trend = "steady">
                    <cfelseif local.ratePerHour LT 0.06>
                        <cfset local.out.pressure_trend = "rising">
                    <cfelse>
                        <cfset local.out.pressure_trend = "rapid_rise">
                    </cfif>
                <cfelse>
                    <cfset local.out.pressure_rate_per_hr = javacast("null", "")>
                    <cfset local.out.pressure_delta = javacast("null", "")>
                    <cfset local.out.pressure_trend = javacast("null", "")>
                </cfif>
            </cfif>
        </cfif>

        <cfreturn local.out>
    </cffunction>

    <cffunction name="parseSurfaceObservationTime" access="private" returntype="any" output="false">
        <cfargument name="rawVal" type="any" required="true">
        <cfset local.epoch = createDateTime(1970, 1, 1, 0, 0, 0)>
        <cfset local.txt = trim(toString(arguments.rawVal))>
        <cfset local.numVal = 0>

        <cfif isDate(arguments.rawVal)>
            <cfreturn arguments.rawVal>
        </cfif>
        <cfif NOT len(local.txt)>
            <cfreturn "">
        </cfif>

        <cfif isNumeric(local.txt)>
            <cfset local.numVal = val(local.txt)>
            <cfif local.numVal GTE 1000000000000>
                <cfreturn dateAdd("s", int(local.numVal / 1000), local.epoch)>
            <cfelseif local.numVal GTE 1000000000>
                <cfreturn dateAdd("s", int(local.numVal), local.epoch)>
            </cfif>
        </cfif>

        <cftry>
            <cfreturn parseDateTime(local.txt)>
            <cfcatch>
                <cflog
                    file="fpw-weather"
                    type="error"
                    text="[FPW][WEATHER] parseSurfaceObservationTime :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
                <cfreturn "">
            </cfcatch>
        </cftry>
    </cffunction>

    <!--- =========================
          nowCOAST layers
    ========================== --->
    <cffunction name="getNowCoastBaseLayers" access="private" returntype="array" output="false">
        <cfset local.layers = []>

        <cfset arrayAppend(local.layers, {
            "key"="radar",
            "label"="Radar",
            "type"="wms",
            "baseUrl"="https://new.nowcoast.noaa.gov/arcgis/services/nowcoast/radar_meteo_imagery_nexrad_time/MapServer/WMSServer",
            "layers"="1",
            "format"="image/png",
            "transparent"=true,
            "attribution"="NOAA nowCOAST"
        })>

        <cfset arrayAppend(local.layers, {
            "key"="warnings",
            "label"="Marine Warnings",
            "type"="wms",
            "baseUrl"="https://new.nowcoast.noaa.gov/arcgis/services/nowcoast/wwa_meteo_warnpolygons_time/MapServer/WMSServer",
            "layers"="1",
            "format"="image/png",
            "transparent"=true,
            "attribution"="NOAA nowCOAST"
        })>

        <cfreturn local.layers>
    </cffunction>

    <!--- =========================
          Marine data (tides + waves)
    ========================== --->
    <cffunction name="getMarineDataCached" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lon" type="numeric" required="true">
        <cfargument name="noCache" type="boolean" required="false" default="false">
        <cfargument name="marineMode" type="string" required="false" default="full">
        <cfargument name="zipHint" type="string" required="false" default="">
        <cfargument name="opts" type="struct" required="false" default="#structNew()#">

        <cfset local.ttlSeconds = 900>
        <cfset local.bypassCache = shouldBypassWeatherCache()>
        <cfset local.cachedMarine = {} >

        <cfif isStruct(arguments.opts) AND structKeyExists(arguments.opts, "ttlSeconds") AND isNumeric(arguments.opts.ttlSeconds)>
            <cfset local.ttlSeconds = int(val(arguments.opts.ttlSeconds))>
        </cfif>
        <cfif isStruct(arguments.opts) AND structKeyExists(arguments.opts, "bypassCache")>
            <cfset local.bypassCache = (isBoolean(arguments.opts.bypassCache) ? arguments.opts.bypassCache : (val(arguments.opts.bypassCache) EQ 1))>
        </cfif>
        <cfif arguments.noCache>
            <cfset local.bypassCache = true>
        </cfif>

        <cfset request._fpwMarineCacheFetchOpts = {
            "noCache"=arguments.noCache,
            "marineMode"=arguments.marineMode,
            "zipHint"=arguments.zipHint
        }>
        <cfset local.marineCacheFetcher = function(required numeric cacheLat, required numeric cacheLon) {
            return getMarineData(
                arguments.cacheLat,
                arguments.cacheLon,
                request._fpwMarineCacheFetchOpts.noCache,
                request._fpwMarineCacheFetchOpts.marineMode,
                request._fpwMarineCacheFetchOpts.zipHint
            );
        }>
        <cfset local.cachedMarine = getWeatherCacheService().getMarineCached(
            arguments.lat,
            arguments.lon,
            local.ttlSeconds,
            local.bypassCache,
            local.marineCacheFetcher,
            arguments.marineMode
        )>
        <cfset structDelete(request, "_fpwMarineCacheFetchOpts", false)>

        <cfif isStruct(local.cachedMarine) AND structKeyExists(local.cachedMarine, "cache_meta") AND isStruct(local.cachedMarine.cache_meta)>
            <cfif NOT structKeyExists(local.cachedMarine, "META") OR NOT isStruct(local.cachedMarine.META)>
                <cfset local.cachedMarine.META = {} >
            </cfif>
            <cfset local.cachedMarine.META.cache_meta = local.cachedMarine.cache_meta>
        </cfif>

        <cfif isStruct(local.cachedMarine)>
            <cfreturn local.cachedMarine>
        </cfif>
        <cfreturn { "wave_height_ft"=0 }>
    </cffunction>

    <cffunction name="getMarineData" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lon" type="numeric" required="true">
        <cfargument name="noCache" type="boolean" required="false" default="false">
        <cfargument name="marineMode" type="string" required="false" default="full">
        <cfargument name="zipHint" type="string" required="false" default="">

        <cfset local.out = { "wave_height_ft" = 0 } >
        <cfset local.meta = {} >
        <cfset local.maxLocalStationNm = 120>
        <cfset local.hasLocalTide = false>
        <cfset local.tide = {} >
        <cfset local.wl = {} >
        <cfset local.fetchTrend = (lcase(arguments.marineMode) NEQ "quick")>
        <cfset local.maxCandidateCount = (local.fetchTrend ? 10 : 1)>

        <cfset local.tideStation = getNearestCoopsTideStation(arguments.lat, arguments.lon)>
        <cfif structKeyExists(local.tideStation, "SUCCESS") AND local.tideStation.SUCCESS>
            <cfset local.tideDistance = (structKeyExists(local.tideStation, "META") AND structKeyExists(local.tideStation.META, "distanceNm") ? val(local.tideStation.META.distanceNm) : 999999)>
            <cfif local.tideDistance LTE local.maxLocalStationNm>
                <cfset local.tide = getCoopsTideData(local.tideStation.STATION_ID, local.tideStation.NAME, arguments.noCache)>
                <cfif isStruct(local.tide) AND structKeyExists(local.tide, "tide")>
                    <cfset local.out.tide = local.tide.tide>
                    <cfset local.hasLocalTide = true>
                </cfif>
            <cfelse>
                <cfset local.meta.tideUnavailable = "No local tide station within " & local.maxLocalStationNm & " nm.">
            </cfif>
            <cfset local.meta.tideStation = (structKeyExists(local.tideStation,"META") ? local.tideStation.META : {})>
            <cfif isStruct(local.tide) AND structKeyExists(local.tide, "META") AND structKeyExists(local.tide.META, "tidePred")>
                <cfset local.meta.tidePred = local.tide.META.tidePred>
            </cfif>
        <cfelse>
            <cfset local.meta.tideUnavailable = "No tide station available for this location.">
        </cfif>

        <!--- Great Lakes and inland fallback: observed water level stations --->
        <cfif NOT local.hasLocalTide>
            <cfset local.waterLevelCandidates = []>
            <cfif len(trim(arguments.zipHint)) EQ 5>
                <cfset local.cachedZipStation = getCachedBestWaterLevelStationForZip(arguments.zipHint)>
                <cfif isStruct(local.cachedZipStation) AND structKeyExists(local.cachedZipStation, "STATION_ID") AND len(local.cachedZipStation.STATION_ID)>
                    <cfset arrayAppend(local.waterLevelCandidates, local.cachedZipStation)>
                </cfif>
            </cfif>

            <cfset local.fallbackCandidates = getNearestCoopsWaterLevelCandidates(arguments.lat, arguments.lon, local.maxLocalStationNm, local.maxCandidateCount)>
            <cfif isArray(local.fallbackCandidates) AND arrayLen(local.fallbackCandidates)>
                <cfloop from="1" to="#arrayLen(local.fallbackCandidates)#" index="local.fcIdx">
                    <cfset local.fc = local.fallbackCandidates[local.fcIdx]>
                    <cfset local.existsInList = false>
                    <cfloop from="1" to="#arrayLen(local.waterLevelCandidates)#" index="local.ci">
                        <cfif local.waterLevelCandidates[local.ci].STATION_ID EQ local.fc.STATION_ID>
                            <cfset local.existsInList = true>
                            <cfbreak>
                        </cfif>
                    </cfloop>
                    <cfif NOT local.existsInList>
                        <cfset arrayAppend(local.waterLevelCandidates, local.fc)>
                    </cfif>
                    <cfif arrayLen(local.waterLevelCandidates) GTE local.maxCandidateCount>
                        <cfbreak>
                    </cfif>
                </cfloop>
            </cfif>

            <cfif isArray(local.waterLevelCandidates) AND arrayLen(local.waterLevelCandidates)>
                <cfset local.meta.waterLevelAttempts = []>
                <cfset local.selectedWlMeta = {} >
                <cfloop from="1" to="#arrayLen(local.waterLevelCandidates)#" index="local.wci">
                    <cfset local.candidate = local.waterLevelCandidates[local.wci]>
                    <cfset local.wl = getCoopsWaterLevelData(local.candidate.STATION_ID, local.candidate.NAME, arguments.noCache, local.fetchTrend)>
                    <cfset local.tryMeta = {
                        "stationId"=local.candidate.STATION_ID,
                        "stationName"=local.candidate.NAME,
                        "distanceNm"=(structKeyExists(local.candidate, "META") AND structKeyExists(local.candidate.META, "distanceNm") ? local.candidate.META.distanceNm : 0)
                    }>
                    <cfif isStruct(local.wl) AND structKeyExists(local.wl, "META") AND structKeyExists(local.wl.META, "waterLevelObs")>
                        <cfset local.obsMeta = local.wl.META.waterLevelObs>
                        <cfif structKeyExists(local.obsMeta, "lastStatus")>
                            <cfset local.tryMeta.lastStatus = local.obsMeta.lastStatus>
                        </cfif>
                        <cfif structKeyExists(local.obsMeta, "lastProduct")>
                            <cfset local.tryMeta.lastProduct = local.obsMeta.lastProduct>
                        </cfif>
                        <cfif structKeyExists(local.obsMeta, "lastDatum")>
                            <cfset local.tryMeta.lastDatum = local.obsMeta.lastDatum>
                        </cfif>
                        <cfif structKeyExists(local.obsMeta, "lastError")>
                            <cfset local.tryMeta.lastError = local.obsMeta.lastError>
                        </cfif>
                    </cfif>
                    <cfset arrayAppend(local.meta.waterLevelAttempts, local.tryMeta)>

                    <cfif isStruct(local.wl) AND structKeyExists(local.wl, "waterLevel")>
                        <cfset local.out.waterLevel = local.wl.waterLevel>
                        <cfset local.selectedWlMeta = {
                            "source"="COOPS_MDAPI_WATER_LEVEL",
                            "stationId"=local.candidate.STATION_ID,
                            "stationName"=local.candidate.NAME,
                            "distanceNm"=(structKeyExists(local.candidate, "META") AND structKeyExists(local.candidate.META, "distanceNm") ? local.candidate.META.distanceNm : 0)
                        }>
                        <cfif isStruct(local.wl) AND structKeyExists(local.wl, "META") AND structKeyExists(local.wl.META, "waterLevelObs")>
                            <cfset local.meta.waterLevelObs = local.wl.META.waterLevelObs>
                        </cfif>
                        <cfbreak>
                    <cfelseif isStruct(local.wl) AND structKeyExists(local.wl, "waterLevelCurrent") AND NOT structKeyExists(local.out, "waterLevelCurrent")>
                        <cfset local.out.waterLevelCurrent = local.wl.waterLevelCurrent>
                        <cfif structCount(local.selectedWlMeta) EQ 0>
                            <cfset local.selectedWlMeta = {
                                "source"="COOPS_MDAPI_WATER_LEVEL",
                                "stationId"=local.candidate.STATION_ID,
                                "stationName"=local.candidate.NAME,
                                "distanceNm"=(structKeyExists(local.candidate, "META") AND structKeyExists(local.candidate.META, "distanceNm") ? local.candidate.META.distanceNm : 0)
                            }>
                        </cfif>
                        <cfif isStruct(local.wl) AND structKeyExists(local.wl, "META") AND structKeyExists(local.wl.META, "waterLevelObs")>
                            <cfset local.meta.waterLevelObs = local.wl.META.waterLevelObs>
                        </cfif>
                        <cfif NOT local.fetchTrend>
                            <cfbreak>
                        </cfif>
                    </cfif>
                </cfloop>

                <cfif structKeyExists(local.out, "waterLevel")>
                    <cfset local.meta.waterLevelStation = local.selectedWlMeta>
                    <cfif len(trim(arguments.zipHint)) EQ 5>
                        <cfset cacheBestWaterLevelStationForZip(arguments.zipHint, local.selectedWlMeta)>
                    </cfif>
                <cfelseif structKeyExists(local.out, "waterLevelCurrent")>
                    <cfif structCount(local.selectedWlMeta)>
                        <cfset local.meta.waterLevelStation = local.selectedWlMeta>
                        <cfif len(trim(arguments.zipHint)) EQ 5>
                            <cfset cacheBestWaterLevelStationForZip(arguments.zipHint, local.selectedWlMeta)>
                        </cfif>
                    </cfif>
                <cfelse>
                    <cfset local.meta.waterLevelUnavailable = "Water level data unavailable for nearby local stations.">
                    <cfif arrayLen(local.waterLevelCandidates)>
                        <cfset local.meta.waterLevelStation = {
                            "source"="COOPS_MDAPI_WATER_LEVEL",
                            "stationId"=local.waterLevelCandidates[1].STATION_ID,
                            "stationName"=local.waterLevelCandidates[1].NAME,
                            "distanceNm"=(structKeyExists(local.waterLevelCandidates[1], "META") AND structKeyExists(local.waterLevelCandidates[1].META, "distanceNm") ? local.waterLevelCandidates[1].META.distanceNm : 0)
                        }>
                    </cfif>
                </cfif>
            <cfelse>
                <cfset local.meta.waterLevelUnavailable = "No local water level station within " & local.maxLocalStationNm & " nm.">
            </cfif>
        </cfif>

        <cfset local.buoy = getNearestNdbcBuoy(arguments.lat, arguments.lon)>
        <cfif structKeyExists(local.buoy, "SUCCESS") AND local.buoy.SUCCESS>
            <cfset local.waves = getNdbcWaveData(local.buoy.BUOY_ID, local.buoy.NAME)>
            <cfif isStruct(local.waves) AND structCount(local.waves) GT 0>
                <cfset local.out.waves = local.waves>
                <cfset local.meta.waveBuoy = (structKeyExists(local.buoy,"META") ? local.buoy.META : {})>
            </cfif>
        </cfif>

        <cfif structKeyExists(local.out, "waves") AND isStruct(local.out.waves)>
            <cfset local.out.wave_height_ft = extractWaveHeightFt(local.out.waves)>
        <cfelse>
            <cfset local.out.wave_height_ft = extractWaveHeightFt(local.out)>
        </cfif>

        <cfif structCount(local.meta) GT 0>
            <cfset local.out.META = local.meta>
        </cfif>

        <cfreturn local.out>
    </cffunction>

    <cffunction name="extractWaveHeightFt" access="private" returntype="numeric" output="false">
        <cfargument name="marineData" type="struct" required="true">

        <cfset local.h = 0>

        <cfif structKeyExists(arguments.marineData, "significantWaveHeight")>
            <cfset local.h = val(arguments.marineData.significantWaveHeight)>
        <cfelseif structKeyExists(arguments.marineData, "waveHeight")>
            <cfset local.h = val(arguments.marineData.waveHeight)>
        <cfelseif structKeyExists(arguments.marineData, "combinedSeas")>
            <cfset local.h = val(arguments.marineData.combinedSeas)>
        <cfelseif structKeyExists(arguments.marineData, "height")>
            <cfset local.h = val(arguments.marineData.height)>
        <cfelseif structKeyExists(arguments.marineData, "WAVE_HEIGHT_FT")>
            <cfset local.h = val(arguments.marineData.WAVE_HEIGHT_FT)>
        </cfif>

        <cfif NOT isNumeric(local.h) OR local.h LT 0>
            <cfset local.h = 0>
        </cfif>

        <cfreturn round(local.h * 10) / 10>
    </cffunction>

    <cffunction name="getCachedBestWaterLevelStationForZip" access="private" returntype="struct" output="false">
        <cfargument name="zip" type="string" required="true">

        <cfset local.out = {} >
        <cfset local.key = "coops_water_level_best_zip:" & trim(arguments.zip)>
        <cfset local.cached = marineCacheGet(local.key, 86400)>
        <cfif isStruct(local.cached) AND structKeyExists(local.cached, "STATION_ID") AND len(local.cached.STATION_ID)>
            <cfset local.out = local.cached>
        </cfif>
        <cfreturn local.out>
    </cffunction>

    <cffunction name="cacheBestWaterLevelStationForZip" access="private" returntype="void" output="false">
        <cfargument name="zip" type="string" required="true">
        <cfargument name="stationMeta" type="struct" required="true">

        <cfset local.stationId = (structKeyExists(arguments.stationMeta, "stationId") ? trim(arguments.stationMeta.stationId) : "")>
        <cfif len(trim(arguments.zip)) NEQ 5 OR NOT len(local.stationId)>
            <cfreturn>
        </cfif>
        <cfset local.name = (structKeyExists(arguments.stationMeta, "stationName") ? arguments.stationMeta.stationName : "")>
        <cfset local.distanceNm = (structKeyExists(arguments.stationMeta, "distanceNm") ? val(arguments.stationMeta.distanceNm) : 0)>
        <cfset local.key = "coops_water_level_best_zip:" & trim(arguments.zip)>
        <cfset marineCacheSet(local.key, {
            "STATION_ID"=local.stationId,
            "NAME"=local.name,
            "META"={"source"="COOPS_MDAPI_WATER_LEVEL","distanceNm"=local.distanceNm}
        })>
    </cffunction>

    <cffunction name="getNearestCoopsWaterLevelStation" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lon" type="numeric" required="true">

        <cfset local.out = { "SUCCESS"=false, "STATION_ID"="", "NAME"="", "META"={} }>
        <cfset local.candidates = getNearestCoopsWaterLevelCandidates(arguments.lat, arguments.lon, 999999, 1)>
        <cfif NOT isArray(local.candidates) OR arrayLen(local.candidates) EQ 0>
            <cfreturn local.out>
        </cfif>
        <cfset local.c = local.candidates[1]>
        <cfset local.out.SUCCESS = true>
        <cfset local.out.STATION_ID = local.c.STATION_ID>
        <cfset local.out.NAME = local.c.NAME>
        <cfset local.out.META = (structKeyExists(local.c, "META") ? local.c.META : {})>
        <cfreturn local.out>
    </cffunction>

    <cffunction name="getNearestCoopsWaterLevelCandidates" access="private" returntype="array" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lon" type="numeric" required="true">
        <cfargument name="maxDistanceNm" type="numeric" required="false" default="120">
        <cfargument name="maxCount" type="numeric" required="false" default="10">

        <cfset local.out = []>
        <cfset local.list = getCoopsWaterLevelStations()>
        <cfset local.maxNm = val(arguments.maxDistanceNm)>
        <cfset local.limit = int(arguments.maxCount)>

        <cfif NOT isArray(local.list) OR arrayLen(local.list) EQ 0>
            <cfreturn local.out>
        </cfif>

        <cfloop from="1" to="#arrayLen(local.list)#" index="local.i">
            <cfset local.s = local.list[local.i]>
            <cfset local.sLat = val(structKeyExists(local.s,"lat") ? local.s.lat : (structKeyExists(local.s,"latitude") ? local.s.latitude : 0))>
            <cfset local.sLon = val(structKeyExists(local.s,"lng") ? local.s.lng : (structKeyExists(local.s,"lon") ? local.s.lon : (structKeyExists(local.s,"longitude") ? local.s.longitude : 0)))>
            <cfif local.sLat EQ 0 AND local.sLon EQ 0>
                <cfcontinue>
            </cfif>
            <cfset local.d = distanceNm(arguments.lat, arguments.lon, local.sLat, local.sLon)>
            <cfif local.maxNm LTE 0 OR local.d LTE local.maxNm>
                <cfset local.item = {
                    "STATION_ID"=(structKeyExists(local.s, "id") ? local.s.id : ""),
                    "NAME"=(structKeyExists(local.s, "name") ? local.s.name : ""),
                    "META"={"source"="COOPS_MDAPI_WATER_LEVEL","distanceNm"=local.d}
                }>
                <cfif len(local.item.STATION_ID)>
                    <cfset arrayAppend(local.out, local.item)>
                </cfif>
            </cfif>
        </cfloop>

        <cfif arrayLen(local.out) GT 1>
            <cfloop from="1" to="#arrayLen(local.out)-1#" index="local.a">
                <cfloop from="#local.a+1#" to="#arrayLen(local.out)#" index="local.b">
                    <cfif val(local.out[local.b].META.distanceNm) LT val(local.out[local.a].META.distanceNm)>
                        <cfset local.tmp = local.out[local.a]>
                        <cfset local.out[local.a] = local.out[local.b]>
                        <cfset local.out[local.b] = local.tmp>
                    </cfif>
                </cfloop>
            </cfloop>
        </cfif>

        <cfif local.limit GT 0>
            <cfloop condition="arrayLen(local.out) GT local.limit">
                <cfset arrayDeleteAt(local.out, arrayLen(local.out))>
            </cfloop>
        </cfif>

        <cfreturn local.out>
    </cffunction>

    <cffunction name="getCoopsWaterLevelStations" access="private" returntype="array" output="false">
        <cfset local.cacheKey = "coops_water_level_stations">
        <cfset local.cached = marineCacheGet(local.cacheKey, 43200)>
        <cfif isArray(local.cached)>
            <cfreturn local.cached>
        </cfif>

        <cfset local.ua = getNwsUserAgent()>
        <cfset local.list = []>
        <cfset local.urlList = [
            "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json?type=waterlevels&units=english",
            "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json?type=water_level&units=english"
        ]>

        <cfloop from="1" to="#arrayLen(local.urlList)#" index="local.u">
            <cfhttp url="#local.urlList[local.u]#" method="get" result="wlsRes" timeout="20">
                <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
                <cfhttpparam type="header" name="Accept" value="application/json">
            </cfhttp>

            <cfif val(wlsRes.statusCode) GTE 200 AND val(wlsRes.statusCode) LT 300>
                <cftry>
                    <cfset local.obj = deserializeJSON(wlsRes.fileContent)>
                    <cfif structKeyExists(local.obj, "stations") AND isArray(local.obj.stations)>
                        <cfset local.list = local.obj.stations>
                    <cfelseif structKeyExists(local.obj, "stationList") AND isArray(local.obj.stationList)>
                        <cfset local.list = local.obj.stationList>
                    </cfif>
                    <cfcatch>
                        <cflog
                            file="fpw-weather"
                            type="error"
                            text="[FPW][WEATHER] getCoopsWaterLevelStations:deserialize :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
                    </cfcatch>
                </cftry>
            </cfif>

            <cfif arrayLen(local.list)>
                <cfbreak>
            </cfif>
        </cfloop>

        <cfif arrayLen(local.list)>
            <cfset marineCacheSet(local.cacheKey, local.list)>
        </cfif>

        <cfreturn local.list>
    </cffunction>

    <cffunction name="getCoopsWaterLevelData" access="private" returntype="struct" output="false">
        <cfargument name="stationId" type="string" required="true">
        <cfargument name="stationName" type="string" required="false" default="">
        <cfargument name="noCache" type="boolean" required="false" default="false">
        <cfargument name="includeTrend" type="boolean" required="false" default="true">

        <cfset local.cacheKey = "coops_water_level_data:" & arguments.stationId & ":" & (arguments.includeTrend ? "trend" : "current")>
        <cfif NOT arguments.noCache>
            <cfset local.cached = marineCacheGet(local.cacheKey, (arguments.includeTrend ? 600 : 120))>
            <cfif isStruct(local.cached)>
                <cfreturn local.cached>
            </cfif>
        </cfif>

        <cfset local.out = {} >
        <cfset local.meta = { "obsUrls"=[], "obsStatus"=[], "lastProduct"="", "lastDatum"="", "lastStatus"=0, "lastError"="" } >
        <cfset local.ua = getNwsUserAgent()>
        <cfset local.series = []>
        <cfset local.datumCandidates = ["LWD","IGLD","STND"]>
        <cfset local.productCandidates = ["water_level","hourly_height"]>
        <cfset local.recentTimeout = (arguments.includeTrend ? 12 : 7)>
        <cfset local.latestTimeout = (arguments.includeTrend ? 10 : 5)>

        <cfif arguments.includeTrend>
            <cfloop from="1" to="#arrayLen(local.productCandidates)#" index="local.prodIdx">
                <cfset local.product = local.productCandidates[local.prodIdx]>
                <cfloop from="1" to="#arrayLen(local.datumCandidates)#" index="local.d">
                    <cfset local.url = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?product=" & urlEncodedFormat(local.product) & "&application=FPW&datum=" & urlEncodedFormat(local.datumCandidates[local.d]) & "&units=english&time_zone=gmt&format=json&date=recent&station=" & urlEncodedFormat(arguments.stationId)>
                    <cfset arrayAppend(local.meta.obsUrls, local.url)>

                    <cfhttp url="#local.url#" method="get" result="wlRes" timeout="#local.recentTimeout#">
                        <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
                        <cfhttpparam type="header" name="Accept" value="application/json">
                    </cfhttp>

                    <cfset local.httpStatus = val(wlRes.statusCode)>
                    <cfset arrayAppend(local.meta.obsStatus, local.httpStatus)>
                    <cfset local.meta.lastProduct = local.product>
                    <cfset local.meta.lastDatum = local.datumCandidates[local.d]>
                    <cfset local.meta.lastStatus = local.httpStatus>

                    <cfif local.httpStatus GTE 200 AND local.httpStatus LT 300>
                        <cftry>
                            <cfset local.obj = deserializeJSON(wlRes.fileContent)>
                            <cfset local.meta.lastError = "">
                            <cfif structKeyExists(local.obj, "error") AND isStruct(local.obj.error) AND structKeyExists(local.obj.error, "message")>
                                <cfset local.meta.lastError = local.obj.error.message>
                            <cfelseif structKeyExists(local.obj, "message") AND isSimpleValue(local.obj.message)>
                                <cfset local.meta.lastError = local.obj.message>
                            </cfif>
                            <cfset local.rows = []>
                            <cfif structKeyExists(local.obj, "data") AND isArray(local.obj.data)>
                                <cfset local.rows = local.obj.data>
                            <cfelseif structKeyExists(local.obj, "predictions") AND isArray(local.obj.predictions)>
                                <cfset local.rows = local.obj.predictions>
                            </cfif>
                            <cfif isArray(local.rows) AND arrayLen(local.rows)>
                                <cfset local.series = []>
                                <cfloop from="1" to="#arrayLen(local.rows)#" index="local.i">
                                    <cfset local.p = local.rows[local.i]>
                                    <cfif structKeyExists(local.p, "t") AND (structKeyExists(local.p, "v") OR structKeyExists(local.p, "pred"))>
                                        <cfset local.vRaw = trim(structKeyExists(local.p, "v") ? local.p.v : local.p.pred)>
                                        <cfif reFind("^-?[0-9]+(\.[0-9]+)?$", local.vRaw)>
                                            <cfset arrayAppend(local.series, { "t"=local.p.t, "h"=val(local.vRaw) })>
                                        </cfif>
                                    </cfif>
                                </cfloop>
                                <cfif arrayLen(local.series) GTE 2>
                                    <cfset local.series = downsampleMarineSeries(local.series, 120)>
                                    <cfset local.out.waterLevel = {
                                        "stationId"=arguments.stationId,
                                        "stationName"=arguments.stationName,
                                        "tz"="gmt",
                                        "units"="ft",
                                        "datum"=local.datumCandidates[local.d],
                                        "product"=local.product,
                                        "series"=local.series
                                    }>
                                    <cfbreak>
                                </cfif>
                            </cfif>
                            <cfcatch>
                                <cflog
                                    file="fpw-weather"
                                    type="error"
                                    text="[FPW][WEATHER] getCoopsWaterLevelData:predictions_deserialize :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
                                <cfif NOT structKeyExists(local.meta, "warnings") OR NOT isArray(local.meta.warnings)>
                                    <cfset local.meta.warnings = []>
                                </cfif>
                                <cfset arrayAppend(local.meta.warnings, {
                                    "code"="WEATHER_EXCEPTION",
                                    "where"="getCoopsWaterLevelData:predictions_deserialize",
                                    "message"=cfcatch.message
                                })>
                                <cfset local.meta.lastError = "JSON parse error">
                            </cfcatch>
                        </cftry>
                    </cfif>
                </cfloop>
                <cfif structKeyExists(local.out, "waterLevel")>
                    <cfbreak>
                </cfif>
            </cfloop>
        </cfif>

        <!--- Fallback: latest single reading for current level text --->
        <cfif NOT structKeyExists(local.out, "waterLevel")>
            <cfloop from="1" to="#arrayLen(local.datumCandidates)#" index="local.d2">
                <cfset local.latestUrl = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?product=water_level&application=FPW&datum=" & urlEncodedFormat(local.datumCandidates[local.d2]) & "&units=english&time_zone=gmt&format=json&date=latest&station=" & urlEncodedFormat(arguments.stationId)>
                <cfset arrayAppend(local.meta.obsUrls, local.latestUrl)>
                <cfhttp url="#local.latestUrl#" method="get" result="latestRes" timeout="#local.latestTimeout#">
                    <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
                    <cfhttpparam type="header" name="Accept" value="application/json">
                </cfhttp>
                <cfset local.latestStatus = val(latestRes.statusCode)>
                <cfset arrayAppend(local.meta.obsStatus, local.latestStatus)>
                <cfset local.meta.lastProduct = "water_level_latest">
                <cfset local.meta.lastDatum = local.datumCandidates[local.d2]>
                <cfset local.meta.lastStatus = local.latestStatus>
                <cfif local.latestStatus GTE 200 AND local.latestStatus LT 300>
                    <cftry>
                        <cfset local.latestObj = deserializeJSON(latestRes.fileContent)>
                        <cfset local.meta.lastError = "">
                        <cfif structKeyExists(local.latestObj, "error") AND isStruct(local.latestObj.error) AND structKeyExists(local.latestObj.error, "message")>
                            <cfset local.meta.lastError = local.latestObj.error.message>
                        </cfif>
                        <cfset local.latestRows = []>
                        <cfif structKeyExists(local.latestObj, "data") AND isArray(local.latestObj.data)>
                            <cfset local.latestRows = local.latestObj.data>
                        <cfelseif structKeyExists(local.latestObj, "predictions") AND isArray(local.latestObj.predictions)>
                            <cfset local.latestRows = local.latestObj.predictions>
                        </cfif>
                        <cfif isArray(local.latestRows) AND arrayLen(local.latestRows)>
                            <cfset local.latestP = local.latestRows[1]>
                            <cfif structKeyExists(local.latestP, "t") AND (structKeyExists(local.latestP, "v") OR structKeyExists(local.latestP, "pred"))>
                                <cfset local.latestRaw = trim(structKeyExists(local.latestP, "v") ? local.latestP.v : local.latestP.pred)>
                                <cfif reFind("^-?[0-9]+(\.[0-9]+)?$", local.latestRaw)>
                                    <cfset local.out.waterLevelCurrent = {
                                        "stationId"=arguments.stationId,
                                        "stationName"=arguments.stationName,
                                        "tz"="gmt",
                                        "units"="ft",
                                        "datum"=local.datumCandidates[local.d2],
                                        "t"=local.latestP.t,
                                        "h"=val(local.latestRaw)
                                    }>
                                    <cfbreak>
                                </cfif>
                            </cfif>
                        </cfif>
                        <cfcatch>
                            <cflog
                                file="fpw-weather"
                                type="error"
                                text="[FPW][WEATHER] getCoopsWaterLevelData:latest_deserialize :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
                            <cfif NOT structKeyExists(local.meta, "warnings") OR NOT isArray(local.meta.warnings)>
                                <cfset local.meta.warnings = []>
                            </cfif>
                            <cfset arrayAppend(local.meta.warnings, {
                                "code"="WEATHER_EXCEPTION",
                                "where"="getCoopsWaterLevelData:latest_deserialize",
                                "message"=cfcatch.message
                            })>
                            <cfset local.meta.lastError = "JSON parse error">
                        </cfcatch>
                    </cftry>
                </cfif>
            </cfloop>
        </cfif>

        <cfset local.out.META = { "waterLevelObs"=local.meta }>
        <cfif (structKeyExists(local.out, "waterLevel") OR structKeyExists(local.out, "waterLevelCurrent")) AND NOT arguments.noCache>
            <cfset marineCacheSet(local.cacheKey, local.out)>
        </cfif>

        <cfreturn local.out>
    </cffunction>

    <cffunction name="downsampleMarineSeries" access="private" returntype="array" output="false">
        <cfargument name="series" type="array" required="true">
        <cfargument name="maxPoints" type="numeric" required="false" default="120">

        <cfset local.n = arrayLen(arguments.series)>
        <cfset local.maxKeep = int(arguments.maxPoints)>
        <cfset local.out = []>
        <cfset local.keep = {} >

        <cfif local.n LTE 0>
            <cfreturn local.out>
        </cfif>
        <cfif local.maxKeep LTE 0 OR local.n LTE local.maxKeep>
            <cfreturn arguments.series>
        </cfif>

        <cfset local.minIdx = 1>
        <cfset local.maxIdx = 1>
        <cfset local.minH = val(arguments.series[1].h)>
        <cfset local.maxH = val(arguments.series[1].h)>
        <cfloop from="2" to="#local.n#" index="local.i">
            <cfset local.h = val(arguments.series[local.i].h)>
            <cfif local.h LT local.minH>
                <cfset local.minH = local.h>
                <cfset local.minIdx = local.i>
            </cfif>
            <cfif local.h GT local.maxH>
                <cfset local.maxH = local.h>
                <cfset local.maxIdx = local.i>
            </cfif>
        </cfloop>

        <cfset local.keep["1"] = true>
        <cfset local.keep["#local.n#"] = true>
        <cfset local.keep["#local.minIdx#"] = true>
        <cfset local.keep["#local.maxIdx#"] = true>

        <cfloop from="1" to="#local.maxKeep#" index="local.k">
            <cfset local.idx = int(round(1 + ((local.k - 1) * (local.n - 1)) / (local.maxKeep - 1)))>
            <cfif local.idx LT 1><cfset local.idx = 1></cfif>
            <cfif local.idx GT local.n><cfset local.idx = local.n></cfif>
            <cfset local.keep["#local.idx#"] = true>
        </cfloop>

        <cfloop from="1" to="#local.n#" index="local.i2">
            <cfif structKeyExists(local.keep, toString(local.i2))>
                <cfset arrayAppend(local.out, arguments.series[local.i2])>
            </cfif>
        </cfloop>

        <cfreturn local.out>
    </cffunction>

    <cffunction name="getNearestCoopsTideStation" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lon" type="numeric" required="true">

        <cfset local.out = { "SUCCESS"=false, "STATION_ID"="", "NAME"="", "META"={} }>
        <cfset local.list = getCoopsTideStations()>
        <cfset local.best = {} >
        <cfset local.bestD = 0>

        <cfif NOT isArray(local.list) OR arrayLen(local.list) EQ 0>
            <cfreturn local.out>
        </cfif>

        <cfloop from="1" to="#arrayLen(local.list)#" index="local.i">
            <cfset local.s = local.list[local.i]>
            <cfset local.sLat = val(structKeyExists(local.s,"lat") ? local.s.lat : (structKeyExists(local.s,"latitude") ? local.s.latitude : 0))>
            <cfset local.sLon = val(structKeyExists(local.s,"lng") ? local.s.lng : (structKeyExists(local.s,"lon") ? local.s.lon : (structKeyExists(local.s,"longitude") ? local.s.longitude : 0)))>
            <cfif local.sLat EQ 0 AND local.sLon EQ 0>
                <cfcontinue>
            </cfif>
            <cfset local.d = distanceNm(arguments.lat, arguments.lon, local.sLat, local.sLon)>
            <cfif NOT structKeyExists(local.best, "id") OR local.d LT local.bestD>
                <cfset local.best = local.s>
                <cfset local.bestD = local.d>
            </cfif>
        </cfloop>

        <cfif structKeyExists(local.best, "id")>
            <cfset local.out.SUCCESS = true>
            <cfset local.out.STATION_ID = local.best.id>
            <cfset local.out.NAME = (structKeyExists(local.best,"name") ? local.best.name : "")>
            <cfset local.out.META = { "source"="COOPS_MDAPI", "distanceNm"=local.bestD }>
        </cfif>

        <cfreturn local.out>
    </cffunction>

    <cffunction name="getCoopsTideStations" access="private" returntype="array" output="false">
        <cfset local.cacheKey = "coops_tide_stations">
        <cfset local.cached = marineCacheGet(local.cacheKey, 43200)>
        <cfif isArray(local.cached)>
            <cfreturn local.cached>
        </cfif>

        <cfset local.url = "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json?type=tidepredictions&units=english">
        <cfset local.ua = getNwsUserAgent()>
        <cfset local.httpStatus = 0>
        <cfset local.list = []>

        <cfhttp url="#local.url#" method="get" result="sRes" timeout="20">
            <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
            <cfhttpparam type="header" name="Accept" value="application/json">
        </cfhttp>

        <cfset local.httpStatus = val(sRes.statusCode)>
        <cfif local.httpStatus GTE 200 AND local.httpStatus LT 300>
            <cftry>
                <cfset local.obj = deserializeJSON(sRes.fileContent)>
                <cfif structKeyExists(local.obj, "stations") AND isArray(local.obj.stations)>
                    <cfset local.list = local.obj.stations>
                <cfelseif structKeyExists(local.obj, "stationList") AND isArray(local.obj.stationList)>
                    <cfset local.list = local.obj.stationList>
                </cfif>
                <cfcatch>
                    <cflog
                        file="fpw-weather"
                        type="error"
                        text="[FPW][WEATHER] getCoopsTideStations:deserialize :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
                </cfcatch>
            </cftry>
        </cfif>

        <cfif arrayLen(local.list)>
            <cfset marineCacheSet(local.cacheKey, local.list)>
        </cfif>

        <cfreturn local.list>
    </cffunction>

    <cffunction name="getCoopsTideData" access="private" returntype="struct" output="false">
        <cfargument name="stationId" type="string" required="true">
        <cfargument name="stationName" type="string" required="false" default="">
        <cfargument name="noCache" type="boolean" required="false" default="false">

        <cfset local.cacheKey = "coops_tide_data:" & arguments.stationId>
        <cfif NOT arguments.noCache>
            <cfset local.cached = marineCacheGet(local.cacheKey, 600)>
            <cfif isStruct(local.cached)>
                <cfset local.cached.cache_meta = marineCacheMeta(local.cacheKey, 600)>
                <cfif structKeyExists(local.cached, "tide") AND isStruct(local.cached.tide)>
                    <cfset local.cached.tide.cache_meta = local.cached.cache_meta>
                </cfif>
                <cfreturn local.cached>
            </cfif>
        </cfif>

        <cfset local.out = {} >
        <cfset local.meta = { "predUrls"=[], "predStatus"=[] } >
        <cfset local.ua = getNwsUserAgent()>
        <cfset local.beginUtc = dateConvert("local2utc", now())>
        <cfset local.beginDate = dateFormat(local.beginUtc, "yyyymmdd")>
        <cfset local.beginStamp = dateFormat(local.beginUtc, "yyyymmdd") & " " & timeFormat(local.beginUtc, "HH:mm")>
        <cfset local.endUtc = dateAdd("h", 24, local.beginUtc)>
        <cfset local.endStamp = dateFormat(local.endUtc, "yyyymmdd") & " " & timeFormat(local.endUtc, "HH:mm")>
        <cfset local.url = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?product=predictions&application=FPW&datum=MLLW&interval=h&units=english&time_zone=gmt&format=json&begin_date=" & urlEncodedFormat(local.beginDate) & "&range=24&station=" & urlEncodedFormat(arguments.stationId)>
        <cfset local.httpStatus = 0>

        <cfset local.series = []>
        <cfset local.predUrlList = [local.url,
            "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?product=predictions&application=FPW&datum=MLLW&interval=h&units=english&time_zone=gmt&format=json&begin_date=" & urlEncodedFormat(local.beginStamp) & "&end_date=" & urlEncodedFormat(local.endStamp) & "&station=" & urlEncodedFormat(arguments.stationId)
        ]>

        <cfloop from="1" to="#arrayLen(local.predUrlList)#" index="local.u">
            <cfset local.httpStatus = 0>
            <cfhttp url="#local.predUrlList[local.u]#" method="get" result="tRes" timeout="20">
                <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
                <cfhttpparam type="header" name="Accept" value="application/json">
            </cfhttp>

            <cfset local.httpStatus = val(tRes.statusCode)>
            <cfset arrayAppend(local.meta.predUrls, local.predUrlList[local.u])>
            <cfset arrayAppend(local.meta.predStatus, local.httpStatus)>
            <cfif local.httpStatus GTE 200 AND local.httpStatus LT 300>
                <cftry>
                    <cfset local.obj = deserializeJSON(tRes.fileContent)>
                    <cfif structKeyExists(local.obj, "predictions") AND isArray(local.obj.predictions)>
                        <cfset local.series = []>
                        <cfloop from="1" to="#arrayLen(local.obj.predictions)#" index="local.i">
                            <cfset local.p = local.obj.predictions[local.i]>
                            <cfset arrayAppend(local.series, { "t"=local.p.t, "h"=val(local.p.v) })>
                        </cfloop>
                        <cfif arrayLen(local.series)>
                            <cfset local.out.tide = {
                                "stationId"=arguments.stationId,
                                "stationName"=arguments.stationName,
                                "tz"="gmt",
                                "units"="ft",
                                "series"=local.series
                            }>
                            <cfbreak>
                        </cfif>
                    </cfif>
                    <cfcatch>
                        <cflog
                            file="fpw-weather"
                            type="error"
                            text="[FPW][WEATHER] getCoopsTideData:deserialize :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
                        <cfif NOT structKeyExists(local.meta, "warnings") OR NOT isArray(local.meta.warnings)>
                            <cfset local.meta.warnings = []>
                        </cfif>
                        <cfset arrayAppend(local.meta.warnings, {
                            "code"="WEATHER_EXCEPTION",
                            "where"="getCoopsTideData:deserialize",
                            "message"=cfcatch.message
                        })>
                    </cfcatch>
                </cftry>
            </cfif>
        </cfloop>

        <!--- Fetch HI/LO payload once and reuse for both fallback series + next high/low extraction. --->
        <cfset local.hiloPayload = fetchCoopsHiloPayload(arguments.stationId, local.beginUtc)>

        <cfif NOT structKeyExists(local.out, "tide") OR NOT arrayLen(local.out.tide.series)>
            <cfset local.hilo = getCoopsHiloSeries(arguments.stationId, local.beginUtc, local.endUtc, local.hiloPayload)>
            <!---
                Fallback to HI/LO points directly when hourly series is unavailable.
                This guarantees the tide graph can render instead of showing empty.
            --->
            <cfif arrayLen(local.hilo) GTE 2>
                <cfset local.out.tide = {
                    "stationId"=arguments.stationId,
                    "stationName"=arguments.stationName,
                    "tz"="gmt",
                    "units"="ft",
                    "series"=local.hilo
                }>
            </cfif>
        </cfif>

        <cfset local.hl = getCoopsNextHighLow(arguments.stationId, local.hiloPayload)>
        <cfif isStruct(local.hl) AND structCount(local.hl)>
            <cfif NOT structKeyExists(local.out, "tide")>
                <cfset local.out.tide = { "stationId"=arguments.stationId, "stationName"=arguments.stationName, "tz"="gmt", "units"="ft", "series"=[] }>
            </cfif>
            <cfif structKeyExists(local.hl, "nextHigh")>
                <cfset local.out.tide.nextHigh = local.hl.nextHigh>
            </cfif>
            <cfif structKeyExists(local.hl, "nextLow")>
                <cfset local.out.tide.nextLow = local.hl.nextLow>
            </cfif>
        </cfif>

        <cfset local.out.META = { "tidePred"=local.meta }>
        <cfif structKeyExists(local.out, "tide") AND NOT arguments.noCache>
            <cfset local.out.cache_meta = marineCacheFreshMeta(local.cacheKey, 600, false, false)>
            <cfset local.out.tide.cache_meta = local.out.cache_meta>
            <cfset marineCacheSet(local.cacheKey, local.out)>
        </cfif>

        <cfreturn local.out>
    </cffunction>

    <cffunction name="fetchCoopsHiloPayload" access="private" returntype="struct" output="false">
        <cfargument name="stationId" type="string" required="true">
        <cfargument name="beginUtc" type="date" required="true">
        <cfargument name="datum" type="string" required="false" default="MLLW">
        <cfargument name="units" type="string" required="false" default="english">
        <cfargument name="timeZone" type="string" required="false" default="gmt">
        <cfargument name="rangeHours" type="numeric" required="false" default="48">

        <cfset local.ua = getNwsUserAgent()>
        <cfset local.begin = dateFormat(arguments.beginUtc, "yyyymmdd")>
        <cfset local.rangeInt = int(arguments.rangeHours)>
        <cfif local.rangeInt LTE 0>
            <cfset local.rangeInt = 48>
        </cfif>
        <cfset local.cacheKey = "coops_hilo_payload:"
            & trim(arguments.stationId)
            & ":"
            & local.begin
            & ":"
            & lCase(trim(arguments.datum))
            & ":"
            & lCase(trim(arguments.units))
            & ":"
            & lCase(trim(arguments.timeZone))
            & ":"
            & local.rangeInt>

        <cfif NOT structKeyExists(request, "_fpwCoopsHiloPayloadCache") OR NOT isStruct(request._fpwCoopsHiloPayloadCache)>
            <cfset request._fpwCoopsHiloPayloadCache = {} >
        </cfif>
        <cfif structKeyExists(request._fpwCoopsHiloPayloadCache, local.cacheKey)
            AND isStruct(request._fpwCoopsHiloPayloadCache[local.cacheKey])>
            <cfreturn request._fpwCoopsHiloPayloadCache[local.cacheKey]>
        </cfif>

        <cfset local.url = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?product=predictions&application=FPW&datum="
            & urlEncodedFormat(arguments.datum)
            & "&interval=hilo&units="
            & urlEncodedFormat(arguments.units)
            & "&time_zone="
            & urlEncodedFormat(arguments.timeZone)
            & "&format=json&begin_date="
            & urlEncodedFormat(local.begin)
            & "&range="
            & local.rangeInt
            & "&station="
            & urlEncodedFormat(arguments.stationId)>
        <cfset local.payload = {
            "statusCode"=0,
            "fileContent"="",
            "url"=local.url
        }>

        <cfhttp url="#local.url#" method="get" result="hRes" timeout="20">
            <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
            <cfhttpparam type="header" name="Accept" value="application/json">
        </cfhttp>

        <cfif structKeyExists(hRes, "statusCode")>
            <cfset local.payload.statusCode = val(hRes.statusCode)>
        </cfif>
        <cfif structKeyExists(hRes, "fileContent")>
            <cfset local.payload.fileContent = hRes.fileContent>
        </cfif>

        <cfset request._fpwCoopsHiloPayloadCache[local.cacheKey] = local.payload>
        <cfreturn local.payload>
    </cffunction>

    <cffunction name="getCoopsNextHighLow" access="private" returntype="struct" output="false">
        <cfargument name="stationId" type="string" required="true">
        <cfargument name="hiloPayload" type="any" required="false" default="">

        <cfset local.out = {} >
        <cfset local.beginUtc = dateConvert("local2utc", now())>
        <cfset local.payload = {} >
        <cfif isStruct(arguments.hiloPayload) AND structKeyExists(arguments.hiloPayload, "fileContent")>
            <cfset local.payload = arguments.hiloPayload>
        <cfelse>
            <cfset local.payload = fetchCoopsHiloPayload(arguments.stationId, local.beginUtc)>
        </cfif>
        <cfset local.httpStatus = 0>
        <cfif structKeyExists(local.payload, "statusCode")>
            <cfset local.httpStatus = val(local.payload.statusCode)>
        </cfif>
        <cfif local.httpStatus GTE 200 AND local.httpStatus LT 300>
            <cftry>
                <cfset local.obj = deserializeJSON(structKeyExists(local.payload, "fileContent") ? local.payload.fileContent : "")>
                <cfif structKeyExists(local.obj, "predictions") AND isArray(local.obj.predictions)>
                    <cfset local.nowTs = now()>
                    <cfloop from="1" to="#arrayLen(local.obj.predictions)#" index="local.i">
                        <cfset local.p = local.obj.predictions[local.i]>
                        <cfset local.pt = "">
                        <cftry>
                            <cfset local.pt = parseDateTime(local.p.t)>
                            <cfcatch>
                                <cflog
                                    file="fpw-weather"
                                    type="error"
                                    text="[FPW][WEATHER] getCoopsNextHighLow:parseDateTime :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
                                <cfif NOT structKeyExists(local.out, "META") OR NOT isStruct(local.out.META)>
                                    <cfset local.out.META = {} >
                                </cfif>
                                <cfif NOT structKeyExists(local.out.META, "warnings") OR NOT isArray(local.out.META.warnings)>
                                    <cfset local.out.META.warnings = []>
                                </cfif>
                                <cfset arrayAppend(local.out.META.warnings, {
                                    "code"="WEATHER_EXCEPTION",
                                    "where"="getCoopsNextHighLow:parseDateTime",
                                    "message"=cfcatch.message
                                })>
                                <cfset local.pt = "">
                            </cfcatch>
                        </cftry>
                        <cfif isDate(local.pt) AND local.pt GT local.nowTs>
                            <cfif local.p.type EQ "H" AND NOT structKeyExists(local.out, "nextHigh")>
                                <cfset local.out.nextHigh = { "t"=local.p.t, "h"=val(local.p.v) }>
                            <cfelseif local.p.type EQ "L" AND NOT structKeyExists(local.out, "nextLow")>
                                <cfset local.out.nextLow = { "t"=local.p.t, "h"=val(local.p.v) }>
                            </cfif>
                        </cfif>
                    </cfloop>
                </cfif>
                <cfcatch>
                    <cflog
                        file="fpw-weather"
                        type="error"
                        text="[FPW][WEATHER] getCoopsNextHighLow:deserialize :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
                    <cfif NOT structKeyExists(local.out, "META") OR NOT isStruct(local.out.META)>
                        <cfset local.out.META = {} >
                    </cfif>
                    <cfif NOT structKeyExists(local.out.META, "warnings") OR NOT isArray(local.out.META.warnings)>
                        <cfset local.out.META.warnings = []>
                    </cfif>
                    <cfset arrayAppend(local.out.META.warnings, {
                        "code"="WEATHER_EXCEPTION",
                        "where"="getCoopsNextHighLow:deserialize",
                        "message"=cfcatch.message
                    })>
                </cfcatch>
            </cftry>
        </cfif>

        <cfreturn local.out>
    </cffunction>

    <cffunction name="getCoopsHiloSeries" access="private" returntype="array" output="false">
        <cfargument name="stationId" type="string" required="true">
        <cfargument name="beginUtc" type="date" required="true">
        <cfargument name="endUtc" type="date" required="true">
        <cfargument name="hiloPayload" type="any" required="false" default="">

        <cfset local.out = []>
        <cfset local.payload = {} >
        <cfset local.httpStatus = 0>
        <cfif isStruct(arguments.hiloPayload) AND structKeyExists(arguments.hiloPayload, "fileContent")>
            <cfset local.payload = arguments.hiloPayload>
        <cfelse>
            <cfset local.payload = fetchCoopsHiloPayload(arguments.stationId, arguments.beginUtc)>
        </cfif>
        <cfif structKeyExists(local.payload, "statusCode")>
            <cfset local.httpStatus = val(local.payload.statusCode)>
        </cfif>

        <cfif local.httpStatus GTE 200 AND local.httpStatus LT 300>
            <cftry>
                <cfset local.obj = deserializeJSON(structKeyExists(local.payload, "fileContent") ? local.payload.fileContent : "")>
                <cfif structKeyExists(local.obj, "predictions") AND isArray(local.obj.predictions)>
                    <cfloop from="1" to="#arrayLen(local.obj.predictions)#" index="local.i">
                        <cfset local.p = local.obj.predictions[local.i]>
                        <cfif structKeyExists(local.p, "t") AND structKeyExists(local.p, "v")>
                            <cfset arrayAppend(local.out, { "t"=local.p.t, "h"=val(local.p.v), "type"=(structKeyExists(local.p,"type") ? local.p.type : "") })>
                        </cfif>
                    </cfloop>
                </cfif>
                <cfcatch>
                    <cflog
                        file="fpw-weather"
                        type="error"
                        text="[FPW][WEATHER] getCoopsHiloSeries:deserialize :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
                </cfcatch>
            </cftry>
        </cfif>

        <cfreturn local.out>
    </cffunction>

    <cffunction name="synthesizeHourlySeries" access="private" returntype="array" output="false">
        <cfargument name="hiloSeries" type="array" required="true">
        <cfargument name="beginUtc" type="date" required="true">
        <cfargument name="endUtc" type="date" required="true">

        <cfset local.out = []>
        <cfset local.stepMin = 60>
        <cfset local.count = arrayLen(arguments.hiloSeries)>

        <cfloop from="1" to="#local.count - 1#" index="local.i">
            <cfset local.a = arguments.hiloSeries[local.i]>
            <cfset local.b = arguments.hiloSeries[local.i + 1]>
            <cfset local.ta = parseDateTime(local.a.t)>
            <cfset local.tb = parseDateTime(local.b.t)>
            <cfif NOT isDate(local.ta) OR NOT isDate(local.tb)>
                <cfcontinue>
            </cfif>
            <cfset local.duration = dateDiff("n", local.ta, local.tb)>
            <cfif local.duration LTE 0>
                <cfcontinue>
            </cfif>
            <cfset local.steps = int(local.duration / local.stepMin)>
            <cfloop from="0" to="#local.steps#" index="local.k">
                <cfset local.t = dateAdd("n", local.k * local.stepMin, local.ta)>
                <cfif local.t LT arguments.beginUtc OR local.t GT arguments.endUtc>
                    <cfcontinue>
                </cfif>
                <cfset local.frac = (local.k * local.stepMin) / local.duration>
                <cfset local.h = (val(local.a.h) + val(local.b.h)) / 2 + (val(local.a.h) - val(local.b.h)) / 2 * cos(pi() * local.frac)>
                <cfset arrayAppend(local.out, { "t"=dateFormat(local.t, "yyyy-mm-dd") & " " & timeFormat(local.t, "HH:mm"), "h"=local.h })>
            </cfloop>
        </cfloop>

        <cfreturn local.out>
    </cffunction>

    <cffunction name="getNearestNdbcBuoy" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lon" type="numeric" required="true">

        <cfset local.out = { "SUCCESS"=false, "BUOY_ID"="", "NAME"="", "META"={} }>
        <cfset local.list = getNdbcStations()>
        <cfset local.best = {} >
        <cfset local.bestD = 0>
        <cfset local.triedIds = {} >
        <cfset local.waveCheck = {} >

        <cfif NOT isArray(local.list) OR arrayLen(local.list) EQ 0>
            <cfreturn local.out>
        </cfif>

        <cfloop from="1" to="#arrayLen(local.list)#" index="local.attempt">
            <cfset local.best = {} >
            <cfset local.bestD = 0>

            <cfloop from="1" to="#arrayLen(local.list)#" index="local.i">
                <cfset local.s = local.list[local.i]>
                <cfset local.sId = (structKeyExists(local.s, "id") ? trim(toString(local.s.id)) : "")>
                <cfif NOT len(local.sId) OR structKeyExists(local.triedIds, local.sId)>
                    <cfcontinue>
                </cfif>

                <cfset local.sLat = val(local.s.lat)>
                <cfset local.sLon = val(local.s.lon)>
                <cfif local.sLat EQ 0 AND local.sLon EQ 0>
                    <cfset local.triedIds[ local.sId ] = true>
                    <cfcontinue>
                </cfif>

                <cfset local.d = distanceNm(arguments.lat, arguments.lon, local.sLat, local.sLon)>
                <cfif NOT structKeyExists(local.best, "id") OR local.d LT local.bestD>
                    <cfset local.best = local.s>
                    <cfset local.bestD = local.d>
                </cfif>
            </cfloop>

            <cfif NOT structKeyExists(local.best, "id")>
                <cfbreak>
            </cfif>

            <cfset local.waveCheck = getNdbcWaveData(local.best.id, (structKeyExists(local.best, "name") ? local.best.name : ""))>
            <cfif isStruct(local.waveCheck) AND structCount(local.waveCheck) GT 0>
                <cfset local.out.SUCCESS = true>
                <cfset local.out.BUOY_ID = local.best.id>
                <cfset local.out.NAME = (structKeyExists(local.best,"name") ? local.best.name : "")>
                <cfset local.out.META = { "source"="NDBC", "distanceNm"=local.bestD }>
                <cfbreak>
            </cfif>

            <cfset local.triedIds[ local.best.id ] = true>
        </cfloop>

        <cfreturn local.out>
    </cffunction>

    <cffunction name="getNdbcStations" access="private" returntype="array" output="false">
        <cfset local.cacheKey = "ndbc_stations">
        <cfset local.cached = marineCacheGet(local.cacheKey, 43200)>
        <cfif isArray(local.cached)>
            <cfreturn local.cached>
        </cfif>

        <cfset local.url = "https://www.ndbc.noaa.gov/activestations.xml">
        <cfset local.ua = getNwsUserAgent()>
        <cfset local.list = []>

        <cfhttp url="#local.url#" method="get" result="xRes" timeout="20">
            <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
            <cfhttpparam type="header" name="Accept" value="application/xml">
        </cfhttp>

        <cfif val(xRes.statusCode) GTE 200 AND val(xRes.statusCode) LT 300>
            <cftry>
                <cfset local.xml = xmlParse(xRes.fileContent)>
                <cfset local.nodes = xmlSearch(local.xml, "/stations/station[@met='y']")>
                <cfif isArray(local.nodes) AND arrayLen(local.nodes)>
                    <cfloop from="1" to="#arrayLen(local.nodes)#" index="local.i">
                        <cfset local.n = local.nodes[local.i]>
                        <cfif NOT structKeyExists(local.n, "xmlAttributes") OR NOT structKeyExists(local.n.xmlAttributes, "id")>
                            <cfcontinue>
                        </cfif>
                        <cfset arrayAppend(local.list, {
                            "id"=local.n.xmlAttributes.id,
                            "name"=(structKeyExists(local.n.xmlAttributes,"name") ? local.n.xmlAttributes.name : ""),
                            "lat"=(structKeyExists(local.n.xmlAttributes,"lat") ? local.n.xmlAttributes.lat : ""),
                            "lon"=(structKeyExists(local.n.xmlAttributes,"lon") ? local.n.xmlAttributes.lon : "")
                        })>
                    </cfloop>
                </cfif>
                <cfcatch>
                    <cflog
                        file="fpw-weather"
                        type="error"
                        text="[FPW][WEATHER] getNdbcStations:xmlparse :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
                </cfcatch>
            </cftry>
        </cfif>

        <cfif arrayLen(local.list)>
            <cfset marineCacheSet(local.cacheKey, local.list)>
        </cfif>

        <cfreturn local.list>
    </cffunction>

    <cffunction name="getNdbcWaveData" access="private" returntype="struct" output="false">
        <cfargument name="buoyId" type="string" required="true">
        <cfargument name="buoyName" type="string" required="false" default="">

        <cfset local.out = {} >
        <cfset local.normalizedBuoyId = ucase(rereplace(trim(arguments.buoyId), "\\s+", "", "all"))>
        <cfif NOT len(local.normalizedBuoyId)>
            <cfreturn local.out>
        </cfif>
        <cfset local.cacheKey = "ndbc_wave:" & local.normalizedBuoyId>
        <cfset local.negCacheKey = "ndbc_wave_404:" & local.normalizedBuoyId>
        <cfset local.lockName = "fpw.weather.ndbc.wave." & local.normalizedBuoyId>
        <cfset local.url = "https://www.ndbc.noaa.gov/data/realtime2/" & urlEncodedFormat(local.normalizedBuoyId) & ".txt">
        <cfset local.ua = getNwsUserAgent()>
        <cfset local.hasSummary = (structKeyExists(request, "_wxRequestSummary") AND isStruct(request._wxRequestSummary))>

        <cflock name="#local.lockName#" type="exclusive" timeout="20">
            <cfset local.negCached = marineCacheGet(local.negCacheKey, 900)>
            <cfif isStruct(local.negCached)>
                <cfif local.hasSummary>
                    <cfset request._wxRequestSummary.ndbcBuoy = local.normalizedBuoyId>
                    <cfset request._wxRequestSummary.ndbcStatus = "404">
                    <cfset request._wxRequestSummary.ndbcNegCache = "hit">
                </cfif>
                <cfreturn local.out>
            </cfif>

            <cfset local.cached = marineCacheGet(local.cacheKey, 600)>
            <cfif isStruct(local.cached)>
                <cfif local.hasSummary>
                    <cfset request._wxRequestSummary.ndbcBuoy = local.normalizedBuoyId>
                    <cfset request._wxRequestSummary.ndbcStatus = "200">
                    <cfset request._wxRequestSummary.ndbcNegCache = "miss">
                </cfif>
                <cfreturn local.cached>
            </cfif>

            <cfhttp url="#local.url#" method="get" result="bRes" timeout="20">
                <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
                <cfhttpparam type="header" name="Accept" value="text/plain">
            </cfhttp>

            <cfset local.httpStatus = val(bRes.statusCode)>
            <cfif local.httpStatus EQ 404>
                <cfset marineCacheSet(local.negCacheKey, { "STATUS"=404, "BUOY_ID"=local.normalizedBuoyId })>
                <cfif local.hasSummary>
                    <cfset request._wxRequestSummary.ndbcBuoy = local.normalizedBuoyId>
                    <cfset request._wxRequestSummary.ndbcStatus = "404">
                    <cfset request._wxRequestSummary.ndbcNegCache = "miss">
                </cfif>
                <cfreturn local.out>
            </cfif>

            <cfif local.httpStatus GTE 200 AND local.httpStatus LT 300>
                <cfset local.lines = listToArray(bRes.fileContent, chr(10))>
                <cfset local.header = "">
                <cfset local.dataLine = "">
                <cfloop from="1" to="#arrayLen(local.lines)#" index="local.i">
                    <cfset local.line = trim(local.lines[local.i])>
                    <cfif NOT len(local.line)><cfcontinue></cfif>
                    <cfif left(local.line,1) EQ chr(35)>
                        <cfif NOT len(local.header)>
                            <cfset local.header = mid(local.line, 2, len(local.line))>
                            <cfset local.header = rereplace(local.header, "\\s+", " ", "all")>
                        </cfif>
                        <cfcontinue>
                    </cfif>
                    <cfif NOT len(local.header)><cfcontinue></cfif>
                    <cfset local.dataLine = rereplace(local.line, "\\s+", " ", "all")>
                    <cfbreak>
                </cfloop>

                <cfif len(local.header) AND len(local.dataLine)>
                    <cfset local.cols = listToArray(local.header, " ")>
                    <cfset local.vals = listToArray(local.dataLine, " ")>
                    <cfset local.map = {} >
                    <cfloop from="1" to="#arrayLen(local.cols)#" index="local.i">
                        <cfif local.i LTE arrayLen(local.vals)>
                            <cfset local.map[ local.cols[local.i] ] = local.vals[local.i]>
                        </cfif>
                    </cfloop>

                    <cfset local.wvht = (structKeyExists(local.map,"WVHT") ? local.map.WVHT : "")>
                    <cfset local.dpd  = (structKeyExists(local.map,"DPD") ? local.map.DPD : (structKeyExists(local.map,"APD") ? local.map.APD : ""))>
                    <cfset local.mwd  = (structKeyExists(local.map,"MWD") ? local.map.MWD : "")>

                    <cfif local.wvht NEQ "" AND local.wvht NEQ "MM">
                        <cfset local.wvhtNum = val(local.wvht)>
                        <cfset local.out = {
                            "buoyId"=arguments.buoyId,
                            "buoyName"=arguments.buoyName,
                            "units"="ft",
                            "height"=(local.wvhtNum * 3.28084),
                            "period"=(local.dpd NEQ "" AND local.dpd NEQ "MM" ? val(local.dpd) : 0),
                            "directionDeg"=(local.mwd NEQ "" AND local.mwd NEQ "MM" ? val(local.mwd) : 0)
                        }>
                    </cfif>
                </cfif>
            </cfif>

            <cfif structCount(local.out) GT 0>
                <cfset marineCacheSet(local.cacheKey, local.out)>
            </cfif>

            <cfif local.hasSummary>
                <cfset request._wxRequestSummary.ndbcBuoy = local.normalizedBuoyId>
                <cfif local.httpStatus GTE 200 AND local.httpStatus LT 300>
                    <cfset request._wxRequestSummary.ndbcStatus = "200">
                <cfelseif local.httpStatus EQ 404>
                    <cfset request._wxRequestSummary.ndbcStatus = "404">
                <cfelse>
                    <cfset request._wxRequestSummary.ndbcStatus = "none">
                </cfif>
                <cfset request._wxRequestSummary.ndbcNegCache = "miss">
            </cfif>

            <cfreturn local.out>
        </cflock>
    </cffunction>

    <cffunction name="getMarineZoneForecastCached" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lon" type="numeric" required="true">
        <cfargument name="noCache" type="boolean" required="false" default="false">

        <cfset local.cacheKey = "marine_zone_forecast_anchor:" & numberFormat(arguments.lat, "0.000") & ":" & numberFormat(arguments.lon, "0.000")>
        <cfset local.cached = "">
        <cfset local.lookupResult = {}>
        <cfset local.parsedCacheKey = "">
        <cfset local.parsedCached = "">
        <cfset local.product = {}>
        <cfset local.parsed = {}>

        <cfif NOT arguments.noCache>
            <cfset local.cached = marineCacheGet(local.cacheKey, 900)>
            <cfif isStruct(local.cached) AND structKeyExists(local.cached, "available")>
                <cfset local.cached.cache_meta = marineCacheMeta(local.cacheKey, 900)>
                <cfreturn local.cached>
            </cfif>
        </cfif>

        <cfset local.lookupResult = resolveMarineZoneForPoint(arguments.lat, arguments.lon, arguments.noCache)>
        <cfif NOT structKeyExists(local.lookupResult, "found") OR NOT local.lookupResult.found>
            <cfset local.parsed = getMarineZoneUnavailable(
                (structKeyExists(local.lookupResult, "reason") AND len(local.lookupResult.reason) ? local.lookupResult.reason : "No coastal marine forecast zone found for this location"),
                arguments.lat,
                arguments.lon,
                "unavailable",
                "",
                ""
            )>
            <cfset local.parsed.cache_meta = marineCacheFreshMeta(local.cacheKey, 900, false, false)>
            <cfset marineCacheSet(local.cacheKey, local.parsed)>
            <cfreturn local.parsed>
        </cfif>

        <cfset local.parsedCacheKey = "marine_zone_forecast_cwf:" & ucase(local.lookupResult.office) & ":" & ucase(local.lookupResult.zone_id)>
        <cfif NOT arguments.noCache>
            <cfset local.parsedCached = marineCacheGet(local.parsedCacheKey, 900)>
            <cfif isStruct(local.parsedCached) AND structKeyExists(local.parsedCached, "available")>
                <cfset local.parsed = duplicate(local.parsedCached)>
                <cfset local.parsed.lookup = local.lookupResult.lookup>
                <cfset local.parsed.cache_meta = marineCacheMeta(local.parsedCacheKey, 900)>
                <cfset marineCacheSet(local.cacheKey, local.parsed)>
                <cfreturn local.parsed>
            </cfif>
        </cfif>

        <cfset local.product = getCwfProductCached(local.lookupResult.office, arguments.noCache)>
        <cfif NOT structKeyExists(local.product, "success") OR NOT local.product.success>
            <cfset local.parsed = getMarineZoneUnavailable(
                (structKeyExists(local.product, "reason") AND len(local.product.reason) ? local.product.reason : "NOAA Coastal Waters Forecast product is unavailable"),
                arguments.lat,
                arguments.lon,
                local.lookupResult.lookup.strategy,
                local.lookupResult.lookup.offset_distance_nm,
                local.lookupResult.lookup.offset_bearing
            )>
            <cfset local.parsed.zone_id = local.lookupResult.zone_id>
            <cfset local.parsed.zone_name = local.lookupResult.zone_name>
            <cfset local.parsed.office = local.lookupResult.office>
            <cfset local.parsed.cache_meta = marineCacheFreshMeta(local.cacheKey, 900, false, false)>
            <cfset marineCacheSet(local.cacheKey, local.parsed)>
            <cfreturn local.parsed>
        </cfif>

        <cfset local.parsed = parseCwfZoneForecast(
            local.product.text,
            local.lookupResult.zone_id,
            local.lookupResult.zone_name,
            local.lookupResult.office,
            local.product.source_url,
            local.lookupResult.zone_url,
            local.lookupResult.lookup
        )>

        <cfset local.parsed.cache_meta = marineCacheFreshMeta(local.parsedCacheKey, 900, false, false)>
        <cfset marineCacheSet(local.parsedCacheKey, local.parsed)>
        <cfset marineCacheSet(local.cacheKey, local.parsed)>
        <cfreturn local.parsed>
    </cffunction>

    <cffunction name="resolveMarineZoneForPoint" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lon" type="numeric" required="true">
        <cfargument name="noCache" type="boolean" required="false" default="false">

        <cfset local.cacheKey = "marine_zone_lookup:" & numberFormat(arguments.lat, "0.000") & ":" & numberFormat(arguments.lon, "0.000")>
        <cfset local.cached = "">
        <cfset local.result = {}>
        <cfset local.distances = [2,5,10,15,20]>
        <cfset local.bearings = [0,45,90,135,180,225,270,315]>
        <cfset local.distance = 0>
        <cfset local.bearing = 0>
        <cfset local.point = {}>
        <cfset local.lookupStartedAt = getTickCount()>
        <cfset local.lookupBudgetMs = 12000>
        <cfset local.zoneLookupTimeoutSeconds = 4>

        <cfif NOT arguments.noCache>
            <cfset local.cached = marineCacheGet(local.cacheKey, 21600)>
            <cfif isStruct(local.cached) AND structKeyExists(local.cached, "found")>
                <cfreturn local.cached>
            </cfif>
        </cfif>

        <cfset local.result = queryNoaaMarineZone(arguments.lat, arguments.lon, "direct", 0, "", local.zoneLookupTimeoutSeconds)>
        <cfif structKeyExists(local.result, "found") AND local.result.found>
            <cfset marineCacheSet(local.cacheKey, local.result)>
            <cfreturn local.result>
        </cfif>

        <cfloop array="#local.distances#" index="local.distance">
            <cfloop array="#local.bearings#" index="local.bearing">
                <cfif (getTickCount() - local.lookupStartedAt) GTE local.lookupBudgetMs>
                    <cfset local.result = { "found"=false, "reason"="NOAA coastal marine forecast zone lookup timed out", "lookup"={ "lat"=arguments.lat, "lon"=arguments.lon, "strategy"="timeout", "layer"="NOAA/NWS Reference Map Layer 5 Coastal Marine Zone Forecasts" } }>
                    <cfset marineCacheSet(local.cacheKey, local.result)>
                    <cfreturn local.result>
                </cfif>
                <cfset local.point = offsetCoordinateNm(arguments.lat, arguments.lon, local.distance, local.bearing)>
                <cfset local.result = queryNoaaMarineZone(local.point.lat, local.point.lon, "offset", local.distance, local.bearing, local.zoneLookupTimeoutSeconds)>
                <cfif structKeyExists(local.result, "found") AND local.result.found>
                    <cfset marineCacheSet(local.cacheKey, local.result)>
                    <cfreturn local.result>
                </cfif>
            </cfloop>
        </cfloop>

        <cfset local.result = { "found"=false, "reason"="No coastal marine forecast zone found for this location", "lookup"={ "lat"=arguments.lat, "lon"=arguments.lon, "strategy"="unavailable", "layer"="NOAA/NWS Reference Map Layer 5 Coastal Marine Zone Forecasts" } }>
        <cfset marineCacheSet(local.cacheKey, local.result)>
        <cfreturn local.result>
    </cffunction>

    <cffunction name="queryNoaaMarineZone" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lon" type="numeric" required="true">
        <cfargument name="strategy" type="string" required="true">
        <cfargument name="offsetDistanceNm" type="any" required="false" default="">
        <cfargument name="offsetBearing" type="any" required="false" default="">
        <cfargument name="httpTimeoutSeconds" type="numeric" required="false" default="5">

        <cfset local.out = { "found"=false, "reason"="No coastal marine forecast zone found for this location" }>
        <cfset local.ua = getNwsUserAgent()>
        <cfset local.endpoint = "https://mapservices.weather.noaa.gov/static/rest/services/nws_reference_maps/nws_reference_map/MapServer/5/query">
        <cfset local.geometry = arguments.lon & "," & arguments.lat>
        <cfset local.httpStatus = 0>
        <cfset local.timeoutSeconds = int(val(arguments.httpTimeoutSeconds))>
        <cfset local.obj = {}>
        <cfset local.feature = {}>
        <cfset local.attrs = {}>
        <cfset local.zoneId = "">
        <cfset local.office = "">
        <cfset local.zoneName = "">
        <cfset local.zoneUrl = "">
        <cfset local.sourceUrl = "">

        <cfif local.timeoutSeconds LT 1>
            <cfset local.timeoutSeconds = 1>
        </cfif>
        <cfif local.timeoutSeconds GT 15>
            <cfset local.timeoutSeconds = 15>
        </cfif>

        <cftry>
            <cfhttp url="#local.endpoint#" method="get" result="zoneRes" timeout="#local.timeoutSeconds#">
                <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
                <cfhttpparam type="header" name="Accept" value="application/json">
                <cfhttpparam type="url" name="f" value="json">
                <cfhttpparam type="url" name="geometry" value="#local.geometry#">
                <cfhttpparam type="url" name="geometryType" value="esriGeometryPoint">
                <cfhttpparam type="url" name="inSR" value="4326">
                <cfhttpparam type="url" name="spatialRel" value="esriSpatialRelIntersects">
                <cfhttpparam type="url" name="outFields" value="*">
                <cfhttpparam type="url" name="returnGeometry" value="false">
            </cfhttp>

            <cfset local.httpStatus = val(zoneRes.statusCode)>
            <cfif local.httpStatus GTE 200 AND local.httpStatus LT 300 AND len(trim(toString(zoneRes.fileContent)))>
                <cfset local.obj = deserializeJSON(zoneRes.fileContent)>
                <cfif structKeyExists(local.obj, "features") AND isArray(local.obj.features) AND arrayLen(local.obj.features) GT 0>
                    <cfset local.feature = local.obj.features[1]>
                    <cfif structKeyExists(local.feature, "attributes") AND isStruct(local.feature.attributes)>
                        <cfset local.attrs = local.feature.attributes>
                        <cfset local.zoneId = getStructValueAnyCase(local.attrs, "id")>
                        <cfset local.office = getStructValueAnyCase(local.attrs, "wfo")>
                        <cfset local.zoneName = getStructValueAnyCase(local.attrs, "name")>
                        <cfset local.zoneUrl = getStructValueAnyCase(local.attrs, "zoneurl")>
                        <cfset local.sourceUrl = getStructValueAnyCase(local.attrs, "url")>
                        <cfif len(local.zoneId) AND len(local.office)>
                            <cfset local.out = {
                                "found"=true,
                                "zone_id"=ucase(local.zoneId),
                                "zone_name"=local.zoneName,
                                "office"=ucase(local.office),
                                "zone_url"=local.zoneUrl,
                                "map_click_url"=local.sourceUrl,
                                "lookup"={
                                    "lat"=arguments.lat,
                                    "lon"=arguments.lon,
                                    "strategy"=arguments.strategy,
                                    "offset_distance_nm"=arguments.offsetDistanceNm,
                                    "offset_bearing"=arguments.offsetBearing,
                                    "layer"="NOAA/NWS Reference Map Layer 5 Coastal Marine Zone Forecasts"
                                }
                            }>
                        </cfif>
                    </cfif>
                </cfif>
            <cfelse>
                <cfset local.out.reason = "NOAA marine zone lookup returned HTTP " & local.httpStatus>
            </cfif>
            <cfcatch>
                <cfset local.out = { "found"=false, "reason"="NOAA marine zone lookup failed: " & cfcatch.message }>
                <cflog file="fpw-weather" type="error" text="[FPW][WEATHER] queryNoaaMarineZone :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
            </cfcatch>
        </cftry>

        <cfreturn local.out>
    </cffunction>

    <cffunction name="getCwfProductCached" access="private" returntype="struct" output="false">
        <cfargument name="office" type="string" required="true">
        <cfargument name="noCache" type="boolean" required="false" default="false">

        <cfset local.office = ucase(trim(arguments.office))>
        <cfset local.cacheKey = "marine_cwf_product:" & local.office>
        <cfset local.cached = "">
        <cfset local.out = { "success"=false, "reason"="NOAA Coastal Waters Forecast product is unavailable", "text"="", "source_url"="" }>
        <cfset local.ua = getNwsUserAgent()>
        <cfset local.httpStatus = 0>

        <cfif NOT len(local.office)>
            <cfreturn local.out>
        </cfif>

        <cfset local.out.source_url = "https://forecast.weather.gov/product.php?issuedby=" & local.office & "&product=CWF&site=NWS">

        <cfif NOT arguments.noCache>
            <cfset local.cached = marineCacheGet(local.cacheKey, 900)>
            <cfif isStruct(local.cached) AND structKeyExists(local.cached, "success")>
                <cfreturn local.cached>
            </cfif>
        </cfif>

        <cftry>
            <cfhttp url="#local.out.source_url#" method="get" result="cwfRes" timeout="15">
                <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
                <cfhttpparam type="header" name="Accept" value="text/plain,text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8">
            </cfhttp>
            <cfset local.httpStatus = val(cwfRes.statusCode)>
            <cfif local.httpStatus GTE 200 AND local.httpStatus LT 300 AND len(trim(toString(cwfRes.fileContent)))>
                <cfset local.out.success = true>
                <cfset local.out.reason = "">
                <cfset local.out.text = normalizeNoaaProductText(cwfRes.fileContent)>
            <cfelse>
                <cfset local.out.reason = "NOAA Coastal Waters Forecast product returned HTTP " & local.httpStatus>
            </cfif>
            <cfcatch>
                <cfset local.out.success = false>
                <cfset local.out.reason = "NOAA Coastal Waters Forecast fetch failed: " & cfcatch.message>
                <cflog file="fpw-weather" type="error" text="[FPW][WEATHER] getCwfProductCached :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
            </cfcatch>
        </cftry>

        <cfset marineCacheSet(local.cacheKey, local.out)>
        <cfreturn local.out>
    </cffunction>

    <cffunction name="parseCwfZoneForecast" access="private" returntype="struct" output="false">
        <cfargument name="productText" type="string" required="true">
        <cfargument name="zoneId" type="string" required="true">
        <cfargument name="zoneName" type="string" required="true">
        <cfargument name="office" type="string" required="true">
        <cfargument name="sourceUrl" type="string" required="true">
        <cfargument name="zoneUrl" type="string" required="false" default="">
        <cfargument name="lookup" type="struct" required="true">

        <cfset local.zoneId = ucase(trim(arguments.zoneId))>
        <cfset local.block = extractCwfZoneBlock(arguments.productText, local.zoneId)>
        <cfset local.periods = []>
        <cfset local.out = {}>
        <cfset local.issuedAt = extractCwfProductTimestamp(arguments.productText)>
        <cfset local.synopsis = extractCwfSynopsis(arguments.productText)>

        <cfif NOT len(local.block)>
            <cfset local.out = getMarineZoneUnavailable("NOAA CWF product did not contain zone " & local.zoneId, arguments.lookup.lat, arguments.lookup.lon, arguments.lookup.strategy, arguments.lookup.offset_distance_nm, arguments.lookup.offset_bearing)>
            <cfset local.out.zone_id = local.zoneId>
            <cfset local.out.zone_name = arguments.zoneName>
            <cfset local.out.office = arguments.office>
            <cfreturn local.out>
        </cfif>

        <cfset local.periods = extractCwfPeriods(local.block)>
        <cfif arrayLen(local.periods) EQ 0>
            <cfset local.out = getMarineZoneUnavailable("NOAA CWF product did not contain forecast periods for " & local.zoneId, arguments.lookup.lat, arguments.lookup.lon, arguments.lookup.strategy, arguments.lookup.offset_distance_nm, arguments.lookup.offset_bearing)>
            <cfset local.out.zone_id = local.zoneId>
            <cfset local.out.zone_name = arguments.zoneName>
            <cfset local.out.office = arguments.office>
            <cfreturn local.out>
        </cfif>

        <cfset local.out = {
            "available"=true,
            "zone_id"=local.zoneId,
            "zone_name"=arguments.zoneName,
            "office"=ucase(trim(arguments.office)),
            "source"="NOAA/NWS Coastal Waters Forecast",
            "source_url"=arguments.sourceUrl,
            "zone_url"=arguments.zoneUrl,
            "issued_at"=local.issuedAt,
            "updated_at"=local.issuedAt,
            "synopsis"=local.synopsis,
            "periods"=local.periods,
            "lookup"=arguments.lookup
        }>

        <cfreturn local.out>
    </cffunction>

    <cffunction name="getMarineZoneUnavailable" access="private" returntype="struct" output="false">
        <cfargument name="reason" type="string" required="true">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lon" type="numeric" required="true">
        <cfargument name="strategy" type="string" required="false" default="unavailable">
        <cfargument name="offsetDistanceNm" type="any" required="false" default="">
        <cfargument name="offsetBearing" type="any" required="false" default="">

        <cfset local.out = {
            "available"=false,
            "reason"=arguments.reason,
            "lookup"={
                "lat"=arguments.lat,
                "lon"=arguments.lon,
                "strategy"=arguments.strategy,
                "offset_distance_nm"=arguments.offsetDistanceNm,
                "offset_bearing"=arguments.offsetBearing,
                "layer"="NOAA/NWS Reference Map Layer 5 Coastal Marine Zone Forecasts"
            }
        }>
        <cfreturn local.out>
    </cffunction>

    <cffunction name="offsetCoordinateNm" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lon" type="numeric" required="true">
        <cfargument name="distanceNm" type="numeric" required="true">
        <cfargument name="bearingDeg" type="numeric" required="true">

        <cfset local.rad = pi() / 180>
        <cfset local.bearing = arguments.bearingDeg * local.rad>
        <cfset local.latRad = arguments.lat * local.rad>
        <cfset local.cosLat = cos(local.latRad)>
        <cfset local.latOffset = (arguments.distanceNm * cos(local.bearing)) / 60>
        <cfset local.lonOffset = 0>
        <cfif abs(local.cosLat) GT 0.0001>
            <cfset local.lonOffset = (arguments.distanceNm * sin(local.bearing)) / (60 * local.cosLat)>
        </cfif>
        <cfreturn { "lat"=(arguments.lat + local.latOffset), "lon"=(arguments.lon + local.lonOffset) }>
    </cffunction>

    <cffunction name="normalizeNoaaProductText" access="private" returntype="string" output="false">
        <cfargument name="rawText" type="string" required="true">

        <cfset local.text = toString(arguments.rawText)>
        <cfif reFindNoCase("<pre[^>]*>", local.text)>
            <cfset local.text = reReplaceNoCase(local.text, "^[\s\S]*?<pre[^>]*>", "", "one")>
            <cfset local.text = reReplaceNoCase(local.text, "</pre>[\s\S]*$", "", "one")>
        </cfif>
        <cfset local.text = reReplace(local.text, "<[^>]+>", "", "all")>
        <cfset local.text = replace(local.text, "&nbsp;", " ", "all")>
        <cfset local.text = replace(local.text, "&amp;", "&", "all")>
        <cfset local.text = replace(local.text, "&lt;", "<", "all")>
        <cfset local.text = replace(local.text, "&gt;", ">", "all")>
        <cfset local.text = replace(local.text, "&quot;", chr(34), "all")>
        <cfset local.text = replace(local.text, "&##39;", "'", "all")>
        <cfset local.text = replace(local.text, chr(13) & chr(10), chr(10), "all")>
        <cfset local.text = replace(local.text, chr(13), chr(10), "all")>
        <cfreturn trim(local.text)>
    </cffunction>

    <cffunction name="extractCwfZoneBlock" access="private" returntype="string" output="false">
        <cfargument name="productText" type="string" required="true">
        <cfargument name="zoneId" type="string" required="true">

        <cfset local.lines = listToArray(arguments.productText, chr(10))>
        <cfset local.i = 0>
        <cfset local.j = 0>
        <cfset local.blockLines = []>
        <cfset local.line = "">
        <cfset local.zoneId = ucase(trim(arguments.zoneId))>

        <cfloop from="1" to="#arrayLen(local.lines)#" index="local.i">
            <cfset local.line = trim(local.lines[local.i])>
            <cfif cwfHeaderContainsZone(local.line, local.zoneId)>
                <cfloop from="#local.i#" to="#arrayLen(local.lines)#" index="local.j">
                    <cfif local.j GT local.i AND trim(local.lines[local.j]) EQ "$$">
                        <cfbreak>
                    </cfif>
                    <cfset arrayAppend(local.blockLines, local.lines[local.j])>
                </cfloop>
                <cfreturn arrayToList(local.blockLines, chr(10))>
            </cfif>
        </cfloop>

        <cfreturn "">
    </cffunction>

    <cffunction name="extractCwfSynopsis" access="private" returntype="string" output="false">
        <cfargument name="productText" type="string" required="true">

        <cfset local.lines = listToArray(arguments.productText, chr(10))>
        <cfset local.out = []>
        <cfset local.collecting = false>
        <cfset local.i = 0>
        <cfset local.line = "">
        <cfset local.inlineText = "">

        <cfloop from="1" to="#arrayLen(local.lines)#" index="local.i">
            <cfset local.line = trim(local.lines[local.i])>
            <cfif NOT local.collecting AND reFindNoCase("^\.SYNOPSIS\.{3}", local.line)>
                <cfset local.inlineText = trim(reReplaceNoCase(local.line, "^\.SYNOPSIS\.{3}", "", "one"))>
                <cfif len(local.inlineText)>
                    <cfset arrayAppend(local.out, local.inlineText)>
                </cfif>
                <cfset local.collecting = true>
                <cfcontinue>
            </cfif>
            <cfif local.collecting>
                <cfif local.line EQ "$$" OR reFindNoCase("^\.[A-Z0-9 /-]+\.{3}", local.line) OR cwfLooksLikeZoneHeader(local.line)>
                    <cfbreak>
                </cfif>
                <cfif len(local.line)>
                    <cfset arrayAppend(local.out, local.line)>
                </cfif>
            </cfif>
        </cfloop>

        <cfreturn normalizeCwfSentence(arrayToList(local.out, " "))>
    </cffunction>

    <cffunction name="extractCwfProductTimestamp" access="private" returntype="string" output="false">
        <cfargument name="productText" type="string" required="true">

        <cfset local.lines = listToArray(arguments.productText, chr(10))>
        <cfset local.i = 0>
        <cfset local.line = "">

        <cfloop from="1" to="#arrayLen(local.lines)#" index="local.i">
            <cfset local.line = trim(local.lines[local.i])>
            <cfif reFindNoCase("^[0-9]{3,4} [AP]M [A-Z]{2,4} .*[0-9]{4}$", local.line)>
                <cfreturn local.line>
            </cfif>
        </cfloop>

        <cfreturn "">
    </cffunction>

    <cffunction name="extractCwfPeriods" access="private" returntype="array" output="false">
        <cfargument name="zoneBlock" type="string" required="true">

        <cfset local.lines = listToArray(arguments.zoneBlock, chr(10))>
        <cfset local.periods = []>
        <cfset local.currentName = "">
        <cfset local.currentLines = []>
        <cfset local.i = 0>
        <cfset local.line = "">
        <cfset local.inlineText = "">

        <cfloop from="1" to="#arrayLen(local.lines)#" index="local.i">
            <cfset local.line = trim(local.lines[local.i])>
            <cfif reFindNoCase("^\.[A-Z0-9 /-]+\.{3}", local.line)>
                <cfif len(local.currentName) AND arrayLen(local.currentLines)>
                    <cfset arrayAppend(local.periods, { "name"=formatCwfPeriodName(local.currentName), "forecast"=normalizeCwfSentence(arrayToList(local.currentLines, " ")) })>
                </cfif>
                <cfset local.currentName = trim(reReplaceNoCase(local.line, "^\.([A-Z0-9 /-]+)\.{3}[\s\S]*$", "\1", "one"))>
                <cfset local.inlineText = trim(reReplaceNoCase(local.line, "^\.[A-Z0-9 /-]+\.{3}", "", "one"))>
                <cfset local.currentLines = []>
                <cfif len(local.inlineText)>
                    <cfset arrayAppend(local.currentLines, local.inlineText)>
                </cfif>
                <cfcontinue>
            </cfif>
            <cfif len(local.currentName) AND local.line NEQ "$$" AND len(local.line)>
                <cfset arrayAppend(local.currentLines, local.line)>
            </cfif>
        </cfloop>

        <cfif len(local.currentName) AND arrayLen(local.currentLines)>
            <cfset arrayAppend(local.periods, { "name"=formatCwfPeriodName(local.currentName), "forecast"=normalizeCwfSentence(arrayToList(local.currentLines, " ")) })>
        </cfif>

        <cfreturn local.periods>
    </cffunction>

    <cffunction name="cwfHeaderContainsZone" access="private" returntype="boolean" output="false">
        <cfargument name="headerLine" type="string" required="true">
        <cfargument name="zoneId" type="string" required="true">

        <cfset local.zoneId = ucase(trim(arguments.zoneId))>
        <cfset local.prefix = left(local.zoneId, 3)>
        <cfset local.header = ucase(trim(arguments.headerLine))>
        <cfset local.tokens = listToArray(local.header, "-")>
        <cfset local.activePrefix = "">
        <cfset local.token = "">
        <cfset local.i = 0>

        <cfif NOT len(local.header) OR find(local.prefix, local.header) EQ 0>
            <cfreturn false>
        </cfif>

        <cfloop from="1" to="#arrayLen(local.tokens)#" index="local.i">
            <cfset local.token = reReplace(ucase(trim(local.tokens[local.i])), "[^A-Z0-9]", "", "all")>
            <cfif reFind("^[A-Z]{3}[0-9]{3}$", local.token)>
                <cfset local.activePrefix = left(local.token, 3)>
                <cfif local.token EQ local.zoneId>
                    <cfreturn true>
                </cfif>
            <cfelseif reFind("^[0-9]{3}$", local.token) AND len(local.activePrefix)>
                <cfif local.activePrefix & local.token EQ local.zoneId>
                    <cfreturn true>
                </cfif>
            </cfif>
        </cfloop>

        <cfreturn false>
    </cffunction>

    <cffunction name="cwfLooksLikeZoneHeader" access="private" returntype="boolean" output="false">
        <cfargument name="line" type="string" required="true">
        <cfset local.line = ucase(trim(arguments.line))>
        <cfreturn reFind("^[A-Z]{3}[0-9]{3}[-A-Z0-9]*-[0-9]{6}-?$", local.line) GT 0>
    </cffunction>

    <cffunction name="formatCwfPeriodName" access="private" returntype="string" output="false">
        <cfargument name="name" type="string" required="true">

        <cfset local.words = listToArray(lcase(trim(arguments.name)), " ")>
        <cfset local.i = 0>
        <cfset local.word = "">
        <cfset local.out = []>
        <cfloop from="1" to="#arrayLen(local.words)#" index="local.i">
            <cfset local.word = local.words[local.i]>
            <cfif len(local.word)>
                <cfset arrayAppend(local.out, ucase(left(local.word, 1)) & mid(local.word, 2, len(local.word) - 1))>
            </cfif>
        </cfloop>
        <cfreturn arrayToList(local.out, " ")>
    </cffunction>

    <cffunction name="normalizeCwfSentence" access="private" returntype="string" output="false">
        <cfargument name="text" type="string" required="true">
        <cfset local.text = trim(arguments.text)>
        <cfset local.text = reReplace(local.text, "[\t ]+", " ", "all")>
        <cfset local.text = reReplace(local.text, "[ ]*\n[ ]*", " ", "all")>
        <cfset local.text = reReplace(local.text, "\s{2,}", " ", "all")>
        <cfreturn trim(local.text)>
    </cffunction>

    <cffunction name="getStructValueAnyCase" access="private" returntype="string" output="false">
        <cfargument name="data" type="struct" required="true">
        <cfargument name="key" type="string" required="true">

        <cfset local.k = "">
        <cfif structKeyExists(arguments.data, arguments.key)>
            <cfreturn toString(arguments.data[arguments.key])>
        </cfif>
        <cfloop collection="#arguments.data#" item="k">
            <cfif compareNoCase(k, arguments.key) EQ 0>
                <cfreturn toString(arguments.data[k])>
            </cfif>
        </cfloop>
        <cfreturn "">
    </cffunction>

    <cffunction name="distanceNm" access="private" returntype="numeric" output="false">
        <cfargument name="lat1" type="numeric" required="true">
        <cfargument name="lon1" type="numeric" required="true">
        <cfargument name="lat2" type="numeric" required="true">
        <cfargument name="lon2" type="numeric" required="true">

        <cfset local.r = 3440.065> <!--- nautical miles --->
        <cfset local.lat1 = arguments.lat1 * (pi() / 180)>
        <cfset local.lat2 = arguments.lat2 * (pi() / 180)>
        <cfset local.dlat = (arguments.lat2-arguments.lat1) * (pi() / 180)>
        <cfset local.dlon = (arguments.lon2-arguments.lon1) * (pi() / 180)>

        <cfset local.a = sin(local.dlat/2)*sin(local.dlat/2) + cos(local.lat1)*cos(local.lat2)*sin(local.dlon/2)*sin(local.dlon/2)>
        <cfset local.a = min(1, max(0, local.a))>
        <cfif local.a EQ 1>
            <cfset local.c = pi()>
        <cfelse>
            <cfset local.c = 2 * atn( sqr(local.a) / sqr(1-local.a) )>
        </cfif>
        <cfreturn local.r * local.c>
    </cffunction>

    <cffunction name="marineCacheGet" access="private" returntype="any" output="false">
        <cfargument name="key" type="string" required="true">
        <cfargument name="ttlSeconds" type="numeric" required="true">
        <cfreturn getWeatherCacheService().getMarineCacheValue(arguments.key, arguments.ttlSeconds)>
    </cffunction>

    <cffunction name="marineCacheSet" access="private" returntype="void" output="false">
        <cfargument name="key" type="string" required="true">
        <cfargument name="val" type="any" required="true">
        <cfset getWeatherCacheService().setMarineCacheValue(arguments.key, arguments.val)>
    </cffunction>

    <cffunction name="marineCacheMeta" access="private" returntype="struct" output="false">
        <cfargument name="key" type="string" required="true">
        <cfargument name="ttlSeconds" type="numeric" required="true">
        <cfreturn getWeatherCacheService().getMarineCacheMeta(arguments.key, arguments.ttlSeconds)>
    </cffunction>

    <cffunction name="marineCacheFreshMeta" access="private" returntype="struct" output="false">
        <cfargument name="key" type="string" required="true">
        <cfargument name="ttlSeconds" type="numeric" required="true">
        <cfargument name="hit" type="boolean" required="false" default="false">
        <cfargument name="bypass" type="boolean" required="false" default="false">
        <cfreturn getWeatherCacheService().buildMarineCacheMeta(arguments.key, arguments.ttlSeconds, arguments.hit, arguments.bypass)>
    </cffunction>

    <cffunction name="normalizeWeatherProviderTime" access="private" returntype="struct" output="false">
        <cfargument name="rawVal" type="any" required="false" default="">
        <cfset local.out = { "utc"="", "display"="" }>
        <cfset local.txt = trim(toString(arguments.rawVal))>
        <cfset local.dt = "">

        <cfif NOT len(local.txt)>
            <cfreturn local.out>
        </cfif>
        <cfset local.out.display = local.txt>
        <cfset local.dt = parseSurfaceObservationTime(local.txt)>
        <cfif isDate(local.dt)>
            <cfset local.out.utc = dateTimeFormat(dateConvert("local2utc", local.dt), "yyyy-mm-dd'T'HH:nn:ss'Z'")>
            <cfset local.out.display = local.out.utc>
        </cfif>
        <cfreturn local.out>
    </cffunction>

    <cffunction name="weatherSecondsSince" access="private" returntype="any" output="false">
        <cfargument name="rawVal" type="any" required="false" default="">
        <cfset local.dt = parseSurfaceObservationTime(arguments.rawVal)>
        <cfif isDate(local.dt)>
            <cfreturn max(0, dateDiff("s", local.dt, now()))>
        </cfif>
        <cfreturn "">
    </cffunction>

    <cffunction name="weatherSecondsUntil" access="private" returntype="any" output="false">
        <cfargument name="rawVal" type="any" required="false" default="">
        <cfset local.dt = parseSurfaceObservationTime(arguments.rawVal)>
        <cfif isDate(local.dt)>
            <cfreturn max(0, dateDiff("s", now(), local.dt))>
        </cfif>
        <cfreturn "">
    </cffunction>

    <cffunction name="buildWeatherCacheStatus" access="private" returntype="struct" output="false">
        <cfargument name="label" type="string" required="true">
        <cfargument name="source" type="string" required="true">
        <cfargument name="cacheMeta" type="any" required="false" default="">
        <cfargument name="providerTime" type="any" required="false" default="">
        <cfargument name="dataAvailable" type="boolean" required="false" default="false">

        <cfset local.meta = (isStruct(arguments.cacheMeta) ? arguments.cacheMeta : {})>
        <cfset local.provider = normalizeWeatherProviderTime(arguments.providerTime)>
        <cfset local.status = "not_reported">
        <cfset local.cachedAt = "">
        <cfset local.expiresAt = "">
        <cfset local.ttl = "">
        <cfset local.hitValue = "">

        <cfif structKeyExists(local.meta, "status") AND len(trim(toString(local.meta.status)))>
            <cfset local.status = trim(toString(local.meta.status))>
        <cfelseif structKeyExists(local.meta, "bypass") AND local.meta.bypass>
            <cfset local.status = "bypass">
        <cfelseif structKeyExists(local.meta, "hit")>
            <cfset local.hitValue = local.meta.hit>
            <cfif isBoolean(local.hitValue) AND local.hitValue>
                <cfset local.status = "cache_hit">
            <cfelseif isBoolean(local.hitValue)>
                <cfset local.status = "fresh_fetch">
            </cfif>
        <cfelseif NOT arguments.dataAvailable>
            <cfset local.status = "unavailable">
        </cfif>

        <cfset local.cachedAt = (structKeyExists(local.meta, "cached_at_utc") ? trim(toString(local.meta.cached_at_utc)) : "")>
        <cfset local.expiresAt = (structKeyExists(local.meta, "expires_at_utc") ? trim(toString(local.meta.expires_at_utc)) : "")>
        <cfset local.ttl = (structKeyExists(local.meta, "ttl_seconds") ? val(local.meta.ttl_seconds) : "")>

        <cfreturn {
            "status"=local.status,
            "cached_at_utc"=local.cachedAt,
            "expires_at_utc"=local.expiresAt,
            "provider_time_utc"=local.provider.utc,
            "provider_time_display"=local.provider.display,
            "age_seconds"=(len(local.provider.utc) ? weatherSecondsSince(local.provider.utc) : ""),
            "expires_in_seconds"=(len(local.expiresAt) ? weatherSecondsUntil(local.expiresAt) : ""),
            "ttl_seconds"=local.ttl,
            "source"=arguments.source,
            "label"=arguments.label
        }>
    </cffunction>

    <cffunction name="getForecastProviderTime" access="private" returntype="string" output="false">
        <cfargument name="forecastRows" type="any" required="false" default="">
        <cfif isArray(arguments.forecastRows) AND arrayLen(arguments.forecastRows) GT 0 AND isStruct(arguments.forecastRows[1]) AND structKeyExists(arguments.forecastRows[1], "startTime")>
            <cfreturn trim(toString(arguments.forecastRows[1].startTime))>
        </cfif>
        <cfreturn "">
    </cffunction>

    <cffunction name="getMarineProviderTime" access="private" returntype="string" output="false">
        <cfargument name="marine" type="any" required="false" default="">
        <cfif isStruct(arguments.marine) AND structKeyExists(arguments.marine, "waterLevelCurrent") AND isStruct(arguments.marine.waterLevelCurrent) AND structKeyExists(arguments.marine.waterLevelCurrent, "t")>
            <cfreturn trim(toString(arguments.marine.waterLevelCurrent.t))>
        </cfif>
        <cfreturn "">
    </cffunction>

    <cffunction name="getTideProviderTime" access="private" returntype="string" output="false">
        <cfargument name="marine" type="any" required="false" default="">
        <cfreturn "">
    </cffunction>

    <cffunction name="buildWeatherCacheReport" access="private" returntype="struct" output="false">
        <cfargument name="outPayload" type="struct" required="true">
        <cfargument name="forecastPayload" type="any" required="false" default="">
        <cfargument name="alertsPayload" type="any" required="false" default="">
        <cfargument name="surfacePayload" type="any" required="false" default="">
        <cfargument name="marinePayload" type="any" required="false" default="">
        <cfargument name="zonePayload" type="any" required="false" default="">

        <cfset local.report = {}>
        <cfset local.forecastMeta = (isStruct(arguments.forecastPayload) AND structKeyExists(arguments.forecastPayload, "cache_meta") ? arguments.forecastPayload.cache_meta : {})>
        <cfset local.alertsMeta = (isStruct(arguments.alertsPayload) AND structKeyExists(arguments.alertsPayload, "cache_meta") ? arguments.alertsPayload.cache_meta : {})>
        <cfset local.surfaceMeta = (isStruct(arguments.surfacePayload) AND structKeyExists(arguments.surfacePayload, "cache_meta") ? arguments.surfacePayload.cache_meta : {})>
        <cfset local.marineMeta = (isStruct(arguments.marinePayload) AND structKeyExists(arguments.marinePayload, "cache_meta") ? arguments.marinePayload.cache_meta : {})>
        <cfset local.tideMeta = (isStruct(arguments.marinePayload) AND structKeyExists(arguments.marinePayload, "tide") AND isStruct(arguments.marinePayload.tide) AND structKeyExists(arguments.marinePayload.tide, "cache_meta") ? arguments.marinePayload.tide.cache_meta : {})>
        <cfset local.zoneMeta = (isStruct(arguments.zonePayload) AND structKeyExists(arguments.zonePayload, "cache_meta") ? arguments.zonePayload.cache_meta : {})>

        <cfset local.report.forecast = buildWeatherCacheStatus("Hourly forecast", "NOAA/NWS", local.forecastMeta, getForecastProviderTime(arguments.outPayload.FORECAST), (structKeyExists(arguments.outPayload, "FORECAST") AND isArray(arguments.outPayload.FORECAST) AND arrayLen(arguments.outPayload.FORECAST) GT 0))>
        <cfset local.report.alerts = buildWeatherCacheStatus("Weather alerts", "NOAA/NWS", local.alertsMeta, "", (isStruct(arguments.alertsPayload) AND structKeyExists(arguments.alertsPayload, "ALERTS")))>
        <cfset local.report.surface = buildWeatherCacheStatus("Surface observation", "METAR", local.surfaceMeta, (isStruct(arguments.surfacePayload) AND structKeyExists(arguments.surfacePayload, "observation_time") ? arguments.surfacePayload.observation_time : ""), isStruct(arguments.surfacePayload))>
        <cfset local.report.marine = buildWeatherCacheStatus("Marine conditions", "NOAA/NDBC/CO-OPS", local.marineMeta, getMarineProviderTime(arguments.marinePayload), isStruct(arguments.marinePayload))>
        <cfset local.report.tide = buildWeatherCacheStatus("Tide data", "NOAA CO-OPS", local.tideMeta, getTideProviderTime(arguments.marinePayload), (isStruct(arguments.marinePayload) AND structKeyExists(arguments.marinePayload, "tide")))>
        <cfset local.report.zone_forecast = buildWeatherCacheStatus("NOAA zone forecast", "NOAA CWF", local.zoneMeta, (isStruct(arguments.zonePayload) AND structKeyExists(arguments.zonePayload, "updated_at") ? arguments.zonePayload.updated_at : (isStruct(arguments.zonePayload) AND structKeyExists(arguments.zonePayload, "issued_at") ? arguments.zonePayload.issued_at : "")), isStruct(arguments.zonePayload))>
        <cfreturn local.report>
    </cffunction>

    <!--- =========================
          Normalizers
    ========================== --->
    <cffunction name="normalizeNwsForecast" access="private" returntype="struct" output="false">
        <cfargument name="json" type="string" required="true">
        <cfargument name="meta" type="struct" required="true">
        <cfargument name="gustGrid" type="any" required="false" default="">

        <cfset local.out = { "FORECAST"=[], "META"=arguments.meta }>
        <cfset local.obj = {} >
        <cfset local.maxN = 0>
        <cfset local.i = 0>
        <cfset local.p = {} >
        <cfset local.gustValues = []>
        <cfset local.gustUnit = "">
        <cfset local.gust = { "hasValue"=false, "gustMph"=0, "source"="ESTIMATED" }>

        <cfif isStruct(arguments.gustGrid)>
            <cfif structKeyExists(arguments.gustGrid, "VALUES") AND isArray(arguments.gustGrid.VALUES)>
                <cfset local.gustValues = arguments.gustGrid.VALUES>
            </cfif>
            <cfif structKeyExists(arguments.gustGrid, "UNIT")>
                <cfset local.gustUnit = arguments.gustGrid.UNIT>
            </cfif>
        </cfif>

        <cftry>
            <cfset local.obj = deserializeJSON(arguments.json)>

            <cfif structKeyExists(local.obj, "properties") AND structKeyExists(local.obj.properties, "periods") AND isArray(local.obj.properties.periods)>
                <cfset local.maxN = arrayLen(local.obj.properties.periods)>
                <cfif local.maxN GT 12>
                    <cfset local.maxN = 12>
                </cfif>

                <cfloop from="1" to="#local.maxN#" index="local.i">
                    <cfset local.p = local.obj.properties.periods[local.i]>
                    <cfset local.gust = getPeriodGustFromGrid(
                        (structKeyExists(local.p,"startTime") ? local.p.startTime : ""),
                        (structKeyExists(local.p,"endTime") ? local.p.endTime : ""),
                        local.gustValues,
                        local.gustUnit
                    )>
                    <cfset arrayAppend(local.out.FORECAST, {
                        "name"=(structKeyExists(local.p,"name") ? local.p.name : ""),
                        "startTime"=(structKeyExists(local.p,"startTime") ? local.p.startTime : ""),
                        "endTime"=(structKeyExists(local.p,"endTime") ? local.p.endTime : ""),
                        "temperature"=(structKeyExists(local.p,"temperature") ? local.p.temperature : ""),
                        "temperatureUnit"=(structKeyExists(local.p,"temperatureUnit") ? local.p.temperatureUnit : ""),
                        "windSpeed"=(structKeyExists(local.p,"windSpeed") ? local.p.windSpeed : ""),
                        "windDirection"=(structKeyExists(local.p,"windDirection") ? local.p.windDirection : ""),
                        "gustMph"=(local.gust.hasValue ? (round(local.gust.gustMph * 10) / 10) : ""),
                        "gustSource"=(local.gust.hasValue ? local.gust.source : "ESTIMATED"),
                        "shortForecast"=(structKeyExists(local.p,"shortForecast") ? local.p.shortForecast : ""),
                        "detailedForecast"=(structKeyExists(local.p,"detailedForecast") ? local.p.detailedForecast : "")
                    })>
                </cfloop>
            </cfif>

            <cfcatch>
                <cflog
                    file="fpw-weather"
                    type="error"
                    text="[FPW][WEATHER] normalizeNwsForecast:deserialize :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
                <cfif NOT structKeyExists(local.out, "META") OR NOT isStruct(local.out.META)>
                    <cfset local.out.META = {} >
                </cfif>
                <cfif NOT structKeyExists(local.out.META, "warnings") OR NOT isArray(local.out.META.warnings)>
                    <cfset local.out.META.warnings = []>
                </cfif>
                <cfset arrayAppend(local.out.META.warnings, {
                    "code"="WEATHER_EXCEPTION",
                    "where"="normalizeNwsForecast:deserialize",
                    "message"=cfcatch.message
                })>
            </cfcatch>
        </cftry>

        <cfreturn local.out>
    </cffunction>

    <cffunction name="normalizeNwsGustGrid" access="private" returntype="struct" output="false">
        <cfargument name="json" type="string" required="true">
        <cfargument name="meta" type="struct" required="true">

        <cfset local.out = { "SUCCESS"=false, "VALUES"=[], "UNIT"="", "META"=arguments.meta }>
        <cfset local.obj = {} >
        <cfset local.g = {} >

        <cftry>
            <cfset local.obj = deserializeJSON(arguments.json)>
            <cfif structKeyExists(local.obj, "properties") AND structKeyExists(local.obj.properties, "windGust") AND isStruct(local.obj.properties.windGust)>
                <cfset local.g = local.obj.properties.windGust>
                <cfif structKeyExists(local.g, "values") AND isArray(local.g.values)>
                    <cfset local.out.VALUES = local.g.values>
                    <cfset local.out.SUCCESS = true>
                </cfif>
                <cfif structKeyExists(local.g, "uom")>
                    <cfset local.out.UNIT = local.g.uom>
                <cfelseif structKeyExists(local.g, "unitCode")>
                    <cfset local.out.UNIT = local.g.unitCode>
                </cfif>
            </cfif>
            <cfcatch>
                <cflog
                    file="fpw-weather"
                    type="error"
                    text="[FPW][WEATHER] normalizeNwsGustGrid:deserialize :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
                <cfif NOT structKeyExists(local.out, "META") OR NOT isStruct(local.out.META)>
                    <cfset local.out.META = {} >
                </cfif>
                <cfif NOT structKeyExists(local.out.META, "warnings") OR NOT isArray(local.out.META.warnings)>
                    <cfset local.out.META.warnings = []>
                </cfif>
                <cfset arrayAppend(local.out.META.warnings, {
                    "code"="WEATHER_EXCEPTION",
                    "where"="normalizeNwsGustGrid:deserialize",
                    "message"=cfcatch.message
                })>
                <cfset local.out.SUCCESS = false>
                <cfset local.out.META.note = "Invalid gust grid JSON">
            </cfcatch>
        </cftry>

        <cfset local.out.META.count = arrayLen(local.out.VALUES)>
        <cfset local.out.META.unit = local.out.UNIT>
        <cfreturn local.out>
    </cffunction>

    <cffunction name="getPeriodGustFromGrid" access="private" returntype="struct" output="false">
        <cfargument name="periodStartIso" type="string" required="true">
        <cfargument name="periodEndIso" type="string" required="true">
        <cfargument name="values" type="array" required="true">
        <cfargument name="unitCode" type="string" required="false" default="">

        <cfset local.out = { "hasValue"=false, "gustMph"=0, "source"="NWS_GRID" }>
        <cfset local.periodStart = parseNwsIsoDate(arguments.periodStartIso)>
        <cfset local.periodEnd = parseNwsIsoDate(arguments.periodEndIso)>
        <cfset local.i = 0>
        <cfset local.v = {} >
        <cfset local.span = {} >
        <cfset local.overlap = 0>
        <cfset local.mph = 0>
        <cfset local.maxMph = -1>

        <cfif NOT isDate(local.periodStart) OR NOT isDate(local.periodEnd) OR local.periodEnd LTE local.periodStart>
            <cfreturn local.out>
        </cfif>

        <cfloop from="1" to="#arrayLen(arguments.values)#" index="local.i">
            <cfset local.v = arguments.values[local.i]>
            <cfif NOT isStruct(local.v) OR NOT structKeyExists(local.v, "validTime")>
                <cfcontinue>
            </cfif>
            <cfif NOT structKeyExists(local.v, "value") OR NOT isNumeric(local.v.value)>
                <cfcontinue>
            </cfif>

            <cfset local.span = parseNwsValidTimeSpan(local.v.validTime)>
            <cfif NOT local.span.SUCCESS>
                <cfcontinue>
            </cfif>

            <cfset local.overlap = getDateRangeOverlapMinutes(local.periodStart, local.periodEnd, local.span.startDate, local.span.endDate)>
            <cfif local.overlap LTE 0>
                <cfcontinue>
            </cfif>

            <cfset local.mph = convertNwsSpeedToMph(val(local.v.value), arguments.unitCode)>
            <cfif local.mph GT local.maxMph>
                <cfset local.maxMph = local.mph>
            </cfif>
        </cfloop>

        <cfif local.maxMph GTE 0>
            <cfset local.out.hasValue = true>
            <cfset local.out.gustMph = local.maxMph>
        </cfif>

        <cfreturn local.out>
    </cffunction>

    <cffunction name="parseNwsValidTimeSpan" access="private" returntype="struct" output="false">
        <cfargument name="validTime" type="string" required="true">

        <cfset local.out = { "SUCCESS"=false, "startDate"="", "endDate"="" }>
        <cfset local.s = trim(arguments.validTime)>
        <cfset local.slash = 0>
        <cfset local.startIso = "">
        <cfset local.durationIso = "">
        <cfset local.startDate = "">
        <cfset local.durationMin = 0>

        <cfif NOT len(local.s)>
            <cfreturn local.out>
        </cfif>

        <cfset local.slash = find("/", local.s)>
        <cfif local.slash GT 0>
            <cfset local.startIso = left(local.s, local.slash - 1)>
            <cfset local.durationIso = mid(local.s, local.slash + 1, len(local.s) - local.slash)>
        <cfelse>
            <cfset local.startIso = local.s>
            <cfset local.durationIso = "PT1H">
        </cfif>

        <cfset local.startDate = parseNwsIsoDate(local.startIso)>
        <cfif NOT isDate(local.startDate)>
            <cfreturn local.out>
        </cfif>

        <cfset local.durationMin = parseIsoDurationMinutes(local.durationIso)>
        <cfif local.durationMin LTE 0>
            <cfset local.durationMin = 60>
        </cfif>

        <cfset local.out.SUCCESS = true>
        <cfset local.out.startDate = local.startDate>
        <cfset local.out.endDate = dateAdd("n", local.durationMin, local.startDate)>
        <cfreturn local.out>
    </cffunction>

    <cffunction name="parseNwsIsoDate" access="private" returntype="any" output="false">
        <cfargument name="iso" type="string" required="true">

        <cfset local.d = "">
        <cfif NOT len(trim(arguments.iso))>
            <cfreturn "">
        </cfif>

        <cftry>
            <cfset local.d = parseDateTime(arguments.iso)>
            <cfcatch>
                <cflog
                    file="fpw-weather"
                    type="error"
                    text="[FPW][WEATHER] parseNwsIsoDate :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
                <cfset local.d = "">
            </cfcatch>
        </cftry>

        <cfreturn local.d>
    </cffunction>

    <cffunction name="parseIsoDurationMinutes" access="private" returntype="numeric" output="false">
        <cfargument name="durationIso" type="string" required="true">

        <cfset local.s = ucase(trim(arguments.durationIso))>
        <cfset local.total = 0>
        <cfset local.n = 0>

        <cfif reFind("([0-9]+)D", local.s)>
            <cfset local.n = val(reReplace(local.s, ".*?([0-9]+)D.*", "\1"))>
            <cfset local.total = local.total + (local.n * 1440)>
        </cfif>
        <cfif reFind("([0-9]+)H", local.s)>
            <cfset local.n = val(reReplace(local.s, ".*?([0-9]+)H.*", "\1"))>
            <cfset local.total = local.total + (local.n * 60)>
        </cfif>
        <cfif reFind("([0-9]+)M", local.s)>
            <cfset local.n = val(reReplace(local.s, ".*?([0-9]+)M.*", "\1"))>
            <cfset local.total = local.total + local.n>
        </cfif>

        <cfreturn local.total>
    </cffunction>

    <cffunction name="getDateRangeOverlapMinutes" access="private" returntype="numeric" output="false">
        <cfargument name="aStart" type="date" required="true">
        <cfargument name="aEnd" type="date" required="true">
        <cfargument name="bStart" type="date" required="true">
        <cfargument name="bEnd" type="date" required="true">

        <cfset local.start = "">
        <cfset local.end = "">
        <cfset local.diff = 0>

        <cfif arguments.aEnd LTE arguments.aStart OR arguments.bEnd LTE arguments.bStart>
            <cfreturn 0>
        </cfif>

        <cfset local.start = (arguments.aStart GTE arguments.bStart ? arguments.aStart : arguments.bStart)>
        <cfset local.end = (arguments.aEnd LTE arguments.bEnd ? arguments.aEnd : arguments.bEnd)>
        <cfif local.end LTE local.start>
            <cfreturn 0>
        </cfif>

        <cfset local.diff = dateDiff("n", local.start, local.end)>
        <cfreturn (local.diff GT 0 ? local.diff : 0)>
    </cffunction>

    <cffunction name="convertNwsSpeedToMph" access="private" returntype="numeric" output="false">
        <cfargument name="speedVal" type="numeric" required="true">
        <cfargument name="unitCode" type="string" required="false" default="">

        <cfset local.v = val(arguments.speedVal)>
        <cfset local.u = lcase(trim(arguments.unitCode))>

        <cfif NOT len(local.u)>
            <cfreturn local.v>
        </cfif>
        <cfif find("km_h", local.u) OR find("km/h", local.u) OR find("kmh", local.u)>
            <cfreturn local.v * 0.621371>
        </cfif>
        <cfif find("m_s", local.u) OR find("m/s", local.u) OR find("meter", local.u)>
            <cfreturn local.v * 2.236936>
        </cfif>
        <cfif find("kt", local.u) OR find("knot", local.u) OR find("nautical_mile_per_hour", local.u)>
            <cfreturn local.v * 1.150779>
        </cfif>
        <cfif find("mi_h", local.u) OR find("mph", local.u) OR find("mile_per_hour", local.u)>
            <cfreturn local.v>
        </cfif>

        <cfreturn local.v>
    </cffunction>

    <cffunction name="normalizeNwsAlerts" access="private" returntype="struct" output="false">
        <cfargument name="json" type="string" required="true">
        <cfargument name="meta" type="struct" required="true">

        <cfset local.out = { "ALERTS"=[], "META"=arguments.meta }>
        <cfset local.obj = {} >
        <cfset local.i = 0>
        <cfset local.f = {} >
        <cfset local.p = {} >

        <cftry>
            <cfset local.obj = deserializeJSON(arguments.json)>

            <cfif structKeyExists(local.obj,"features") AND isArray(local.obj.features)>
                <cfloop from="1" to="#arrayLen(local.obj.features)#" index="local.i">
                    <cfset local.f = local.obj.features[local.i]>
                    <cfif structKeyExists(local.f,"properties")>
                        <cfset local.p = local.f.properties>
                        <cfset local.alertSpecificUrl = "">
                        <cfif structKeyExists(local.p,"@id") AND reFindNoCase("^https?://", trim(toString(structFind(local.p,"@id"))))>
                            <cfset local.alertSpecificUrl = trim(toString(structFind(local.p,"@id")))>
                        <cfelseif structKeyExists(local.f,"id") AND reFindNoCase("^https?://", trim(toString(local.f.id)))>
                            <cfset local.alertSpecificUrl = trim(toString(local.f.id))>
                        </cfif>
                        <cfset local.alertWeb = local.alertSpecificUrl>
                        <cfif NOT len(local.alertWeb) AND structKeyExists(local.p,"web")>
                            <cfset local.alertWeb = local.p.web>
                        </cfif>
                        <cfset arrayAppend(local.out.ALERTS, {
                            "event"=(structKeyExists(local.p,"event") ? local.p.event : ""),
                            "headline"=(structKeyExists(local.p,"headline") ? local.p.headline : ""),
                            "severity"=(structKeyExists(local.p,"severity") ? local.p.severity : ""),
                            "urgency"=(structKeyExists(local.p,"urgency") ? local.p.urgency : ""),
                            "certainty"=(structKeyExists(local.p,"certainty") ? local.p.certainty : ""),
                            "effective"=(structKeyExists(local.p,"effective") ? local.p.effective : ""),
                            "ends"=(structKeyExists(local.p,"ends") ? local.p.ends : ""),
                            "instruction"=(structKeyExists(local.p,"instruction") ? local.p.instruction : ""),
                            "description"=(structKeyExists(local.p,"description") ? local.p.description : ""),
                            "id"=(structKeyExists(local.p,"id") ? local.p.id : (structKeyExists(local.f,"id") ? local.f.id : "")),
                            "web"=local.alertWeb,
                            "areaDesc"=(structKeyExists(local.p,"areaDesc") ? local.p.areaDesc : ""),
                            "sender"=(structKeyExists(local.p,"sender") ? local.p.sender : ""),
                            "senderName"=(structKeyExists(local.p,"senderName") ? local.p.senderName : ""),
                            "expires"=(structKeyExists(local.p,"expires") ? local.p.expires : ""),
                            "sent"=(structKeyExists(local.p,"sent") ? local.p.sent : ""),
                            "onset"=(structKeyExists(local.p,"onset") ? local.p.onset : "")
                        })>
                    </cfif>
                </cfloop>
            </cfif>

            <cfcatch>
                <cflog
                    file="fpw-weather"
                    type="error"
                    text="[FPW][WEATHER] normalizeNwsAlerts:deserialize :: #cgi.script_name# :: #cfcatch.message# :: #left(toString(cfcatch.detail), 400)#">
                <cfif NOT structKeyExists(local.out, "META") OR NOT isStruct(local.out.META)>
                    <cfset local.out.META = {} >
                </cfif>
                <cfif NOT structKeyExists(local.out.META, "warnings") OR NOT isArray(local.out.META.warnings)>
                    <cfset local.out.META.warnings = []>
                </cfif>
                <cfset arrayAppend(local.out.META.warnings, {
                    "code"="WEATHER_EXCEPTION",
                    "where"="normalizeNwsAlerts:deserialize",
                    "message"=cfcatch.message
                })>
            </cfcatch>
        </cftry>

        <cfreturn local.out>
    </cffunction>

    <!--- =========================
          Summary
    ========================== --->
    <cffunction name="buildBoaterSummary" access="private" returntype="string" output="false">
        <cfargument name="forecast" type="array" required="true">
        <cfargument name="alerts" type="array" required="true">

        <cfset local.s = "">
        <cfset local.alertCount = arrayLen(arguments.alerts)>
        <cfset local.p1 = {} >

        <cfif local.alertCount GT 0>
            <cfset local.s = "Active alerts: " & local.alertCount & ". ">
        </cfif>

        <cfif arrayLen(arguments.forecast) GT 0>
            <cfset local.p1 = arguments.forecast[1]>
            <cfif structKeyExists(local.p1, "shortForecast") AND len(local.p1.shortForecast)>
                <cfset local.s = local.s & local.p1.shortForecast>
            <cfelse>
                <cfset local.s = local.s & "Forecast available">
            </cfif>

            <cfif structKeyExists(local.p1, "windSpeed") AND len(local.p1.windSpeed)>
                <cfset local.s = local.s & " • Wind " & local.p1.windSpeed>
                <cfif structKeyExists(local.p1, "windDirection") AND len(local.p1.windDirection)>
                    <cfset local.s = local.s & " " & local.p1.windDirection>
                </cfif>
            </cfif>
        <cfelse>
            <cfset local.s = local.s & "Forecast currently unavailable.">
        </cfif>

        <cfreturn trim(local.s)>
    </cffunction>

    <!--- =========================
          Helpers
    ========================== --->
    <cffunction name="shouldBypassWeatherCache" access="private" returntype="boolean" output="false">
        <cfset local.bypass = false>
        <cfset local.rawCache = "">
        <cfset local.rawBypass = "">

        <cfif isDefined("url.cache")>
            <cfset local.rawCache = trim(toString(url.cache))>
            <cfif len(local.rawCache) AND local.rawCache EQ "0">
                <cfset local.bypass = true>
            </cfif>
        </cfif>

        <cfif isDefined("url.bypassCache")>
            <cfset local.rawBypass = trim(toString(url.bypassCache))>
            <cfif (isNumeric(local.rawBypass) AND val(local.rawBypass) EQ 1) OR compareNoCase(local.rawBypass, "true") EQ 0>
                <cfset local.bypass = true>
            </cfif>
        </cfif>

        <cfreturn local.bypass>
    </cffunction>

    <cffunction name="getWeatherCacheService" access="private" returntype="any" output="false">
        <cfif structKeyExists(request, "_fpwWeatherCacheService") AND isObject(request._fpwWeatherCacheService)>
            <cfreturn request._fpwWeatherCacheService>
        </cfif>

        <cfset local.userAgent = getNwsUserAgent()>

        <cftry>
            <cfset request._fpwWeatherCacheService = createObject("component", "fpw.api.services.weatherCache").init(
                userAgent = local.userAgent,
                httpTimeout = 15
            )>
            <cfcatch>
                <cfset request._fpwWeatherCacheService = createObject("component", "api.services.weatherCache").init(
                    userAgent = local.userAgent,
                    httpTimeout = 15
                )>
            </cfcatch>
        </cftry>

        <cfreturn request._fpwWeatherCacheService>
    </cffunction>

    <cffunction name="getNwsUserAgent" access="private" returntype="string" output="false">
        <cfreturn "FloatPlanWizard Weather (V1) (admin@floatplanwizard.com)">
    </cffunction>

    <cffunction name="resolveUserId" access="private" returntype="numeric" output="false">
        <cfargument name="userStruct" type="struct" required="true">

        <cfset local.uid = 0>

        <cfif structKeyExists(arguments.userStruct, "id")>
            <cfset local.uid = int(val(arguments.userStruct.id))>
        <cfelseif structKeyExists(arguments.userStruct, "USERID")>
            <cfset local.uid = int(val(arguments.userStruct.USERID))>
        <cfelseif structKeyExists(arguments.userStruct, "userId")>
            <cfset local.uid = int(val(arguments.userStruct.userId))>
        </cfif>

        <cfreturn local.uid>
    </cffunction>

</cfcomponent>
