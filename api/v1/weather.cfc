<!--- /fpw/api/v1/weather.cfc  (TAGS ONLY)
      NOAA/NWS forecast + alerts + nowCOAST map layers for a float plan anchor

      Auth:
        - Normal: requires logged-in session.user
        - Dev bypass (optional): ?token=abc123&asUserId=187
          token must match application.monitorToken

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
        <cfargument name="marineMode" type="any" required="false">
        <cfargument name="marineOnly" type="any" required="false">

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
            <cfset local.act = "get" >
            <cfset local.fpId = 0 >
            <cfset local.data = {} >
            <cfset local.zip = "">
            <cfset local.marineMode = "full">
            <cfset local.marineOnly = false>

            <cfif structKeyExists(session, "user") AND isStruct(session.user)>
                <cfset local.userStruct = session.user>
                <cfset local.userId = resolveUserId(local.userStruct)>
            </cfif>

            <!--- DEV BYPASS (optional) --->
            <cfif local.userId LTE 0>
                <cfif len(trim(url.token))
                    AND structKeyExists(application, "monitorToken")
                    AND trim(url.token) EQ trim(application.monitorToken)
                    AND isNumeric(url.asUserId)
                    AND val(url.asUserId) GT 0>
                    <cfset local.userId = int(val(url.asUserId))>
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
            <cfelseif isDefined("url.marineMode") AND len(trim(url.marineMode))>
                <cfset local.marineMode = lcase(trim(url.marineMode))>
            </cfif>
            <cfif local.marineMode NEQ "quick" AND local.marineMode NEQ "full">
                <cfset local.marineMode = "full">
            </cfif>
            <cfif structKeyExists(arguments, "marineOnly")>
                <cfset local.marineOnly = (isBoolean(arguments.marineOnly) ? arguments.marineOnly : (val(arguments.marineOnly) EQ 1))>
            <cfelseif isDefined("url.marineOnly")>
                <cfset local.marineOnly = (val(url.marineOnly) EQ 1)>
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

        <cfset local.noCache = (isDefined("url.nocache") AND len(url.nocache) AND val(url.nocache) EQ 1)>
        <cfset local.f = {} >
        <cfset local.a = {} >
        <cfset local.m = getMarineData(local.lat, local.lon, local.noCache, arguments.marineMode, "")>

        <cfif NOT arguments.marineOnly>
            <cfset local.f = getNwsForecast(local.lat, local.lon)>
            <cfset local.a = getNwsAlerts(local.lat, local.lon)>
            <cfif structKeyExists(local.f, "FORECAST") AND isArray(local.f.FORECAST)>
                <cfset local.out.FORECAST = local.f.FORECAST>
            </cfif>
            <cfif structKeyExists(local.a, "ALERTS") AND isArray(local.a.ALERTS)>
                <cfset local.out.ALERTS = local.a.ALERTS>
            </cfif>
            <cfset local.out.MAP_LAYERS = getNowCoastBaseLayers()>
            <cfset local.out.SUMMARY = buildBoaterSummary(local.out.FORECAST, local.out.ALERTS)>
        </cfif>

        <cfif isStruct(local.m) AND structCount(local.m) GT 0>
            <cfset local.out.MARINE = local.m>
        </cfif>

        <cfset local.out.META.anchor = { "lat"=local.lat, "lon"=local.lon }>
        <cfset local.out.META.sources = {} >
        <cfset local.out.META.sources.forecast = (NOT arguments.marineOnly AND structKeyExists(local.f,"META") ? local.f.META : {})>
        <cfset local.out.META.sources.alerts   = (NOT arguments.marineOnly AND structKeyExists(local.a,"META") ? local.a.META : {})>
        <cfset local.out.META.sources.marine   = (structKeyExists(local.m,"META") ? local.m.META : {})>

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

        <cfset local.noCache = (isDefined("url.nocache") AND len(url.nocache) AND val(url.nocache) EQ 1)>
        <cfset local.f = {} >
        <cfset local.a = {} >
        <cfset local.m = getMarineData(local.lat, local.lon, local.noCache, arguments.marineMode, arguments.zip)>

        <cfif NOT arguments.marineOnly>
            <cfset local.f = getNwsForecast(local.lat, local.lon)>
            <cfset local.a = getNwsAlerts(local.lat, local.lon)>
            <cfif structKeyExists(local.f, "FORECAST") AND isArray(local.f.FORECAST)>
                <cfset local.out.FORECAST = local.f.FORECAST>
            </cfif>
            <cfif structKeyExists(local.a, "ALERTS") AND isArray(local.a.ALERTS)>
                <cfset local.out.ALERTS = local.a.ALERTS>
            </cfif>
            <cfset local.out.MAP_LAYERS = getNowCoastBaseLayers()>
            <cfset local.out.SUMMARY = buildBoaterSummary(local.out.FORECAST, local.out.ALERTS)>
        </cfif>

        <cfif isStruct(local.m) AND structCount(local.m) GT 0>
            <cfset local.out.MARINE = local.m>
        </cfif>

        <cfset local.out.META.anchor = { "lat"=local.lat, "lon"=local.lon }>
        <cfset local.out.META.request = { "zip"=arguments.zip }>
        <cfset local.out.META.sources = {} >
        <cfset local.out.META.sources.geocode  = (structKeyExists(local.geo,"META") ? local.geo.META : {})>
        <cfset local.out.META.sources.forecast = (NOT arguments.marineOnly AND structKeyExists(local.f,"META") ? local.f.META : {})>
        <cfset local.out.META.sources.alerts   = (NOT arguments.marineOnly AND structKeyExists(local.a,"META") ? local.a.META : {})>
        <cfset local.out.META.sources.marine   = (structKeyExists(local.m,"META") ? local.m.META : {})>

        <cfset local.out.SUCCESS = true>
        <cfset local.out.MESSAGE = "OK">
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
        <cfset local.url = "https://geocoding.geo.census.gov/geocoder/locations/onelineaddress?address=" & urlEncodedFormat(arguments.zip & " USA") & "&benchmark=Public_AR_Current&format=json">
        <cfset local.httpStatus = 0>
        <cfset local.obj = {} >
        <cfset local.match = {} >
        <cfset local.zurl = "https://api.zippopotam.us/us/" & urlEncodedFormat(arguments.zip)>
        <cfset local.zstatus = 0>
        <cfset local.zobj = {} >

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
                        <cfset local.r.SUCCESS = true>
                        <cfset local.r.MESSAGE = "OK">
                        <cfset local.r.META = { "source"="Census", "url"=local.url, "status"=local.httpStatus }>
                        <cfreturn local.r>
                    </cfif>
                </cfif>
                <cfcatch>
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
                        <cfset local.r.SUCCESS = true>
                        <cfset local.r.MESSAGE = "OK">
                        <cfset local.r.META = { "source"="Zippopotam", "url"=local.zurl, "status"=local.zstatus }>
                        <cfreturn local.r>
                    </cfif>
                </cfif>
                <cfcatch>
                </cfcatch>
            </cftry>
        </cfif>

        <cfset local.r.MESSAGE = "ZIP not found.">
        <cfset local.r.ERROR = { "SOURCE"="Census/Zippopotam", "DETAIL"="No matches returned.", "CENSUS_STATUS"=local.httpStatus, "ZIP_STATUS"=local.zstatus }>
        <cfset local.r.META = { "source"="Census/Zippopotam", "url"=local.url, "status"=local.httpStatus }>
        <cfreturn local.r>
    </cffunction>

    <!--- =========================
          NOAA / NWS calls (no cache)
    ========================== --->
    <cffunction name="getNwsForecast" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lon" type="numeric" required="true">

        <cfset local.out = { "FORECAST"=[], "META"={} }>
        <cfset local.ua = getNwsUserAgent()>
        <cfset local.pointsUrl = "https://api.weather.gov/points/" & arguments.lat & "," & arguments.lon>
        <cfset local.forecastUrl = "">
        <cfset local.gridUrl = "">
        <cfset local.pObj = {} >
        <cfset local.httpStatus = 0>
        <cfset local.httpStatus2 = 0>
        <cfset local.httpStatus3 = 0>
        <cfset local.gustGrid = { "SUCCESS"=false, "VALUES"=[], "UNIT"="", "META"={} }>
        <cfset local.meta = {} >

        <cfhttp url="#local.pointsUrl#" method="get" result="pRes" timeout="15">
            <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
            <cfhttpparam type="header" name="Accept" value="application/geo+json">
        </cfhttp>

        <cfset local.httpStatus = val(pRes.statusCode)>
        <cfif local.httpStatus LT 200 OR local.httpStatus GTE 300>
            <cfset local.out.META = { "source"="NWS", "step"="points", "status"=local.httpStatus, "url"=local.pointsUrl }>
            <cfreturn local.out>
        </cfif>

        <cftry>
            <cfset local.pObj = deserializeJSON(pRes.fileContent)>
            <cfcatch>
                <cfset local.out.META = { "source"="NWS", "step"="points", "status"=local.httpStatus, "url"=local.pointsUrl, "note"="Invalid JSON" }>
                <cfreturn local.out>
            </cfcatch>
        </cftry>

        <cfif structKeyExists(local.pObj, "properties") AND structKeyExists(local.pObj.properties, "forecastHourly") AND len(local.pObj.properties.forecastHourly)>
            <cfset local.forecastUrl = local.pObj.properties.forecastHourly>
        <cfelseif structKeyExists(local.pObj, "properties") AND structKeyExists(local.pObj.properties, "forecast") AND len(local.pObj.properties.forecast)>
            <cfset local.forecastUrl = local.pObj.properties.forecast>
        </cfif>
        <cfif structKeyExists(local.pObj, "properties") AND structKeyExists(local.pObj.properties, "forecastGridData") AND len(local.pObj.properties.forecastGridData)>
            <cfset local.gridUrl = local.pObj.properties.forecastGridData>
        </cfif>

        <cfif NOT len(local.forecastUrl)>
            <cfset local.out.META = { "source"="NWS", "step"="points", "status"=local.httpStatus, "url"=local.pointsUrl, "note"="No forecast URL" }>
            <cfreturn local.out>
        </cfif>

        <cfhttp url="#local.forecastUrl#" method="get" result="fRes" timeout="15">
            <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
            <cfhttpparam type="header" name="Accept" value="application/geo+json">
        </cfhttp>

        <cfset local.httpStatus2 = val(fRes.statusCode)>
        <cfif local.httpStatus2 LT 200 OR local.httpStatus2 GTE 300>
            <cfset local.out.META = { "source"="NWS", "step"="forecast", "status"=local.httpStatus2, "url"=local.forecastUrl }>
            <cfreturn local.out>
        </cfif>

        <cfif len(local.gridUrl)>
            <cfhttp url="#local.gridUrl#" method="get" result="gRes" timeout="15">
                <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
                <cfhttpparam type="header" name="Accept" value="application/geo+json">
            </cfhttp>
            <cfset local.httpStatus3 = val(gRes.statusCode)>
            <cfif local.httpStatus3 GTE 200 AND local.httpStatus3 LT 300>
                <cfset local.gustGrid = normalizeNwsGustGrid(gRes.fileContent, { "source"="NWS", "step"="forecastGridData", "url"=local.gridUrl, "status"=local.httpStatus3 })>
            <cfelse>
                <cfset local.gustGrid.META = { "source"="NWS", "step"="forecastGridData", "url"=local.gridUrl, "status"=local.httpStatus3, "note"="Grid request failed" }>
            </cfif>
        </cfif>

        <cfset local.meta = { "source"="NWS", "url"=local.forecastUrl, "status"=local.httpStatus2 }>
        <cfif isStruct(local.gustGrid) AND structKeyExists(local.gustGrid, "META")>
            <cfset local.meta.gust = local.gustGrid.META>
        </cfif>

        <cfreturn normalizeNwsForecast(fRes.fileContent, local.meta, local.gustGrid)>
    </cffunction>

    <cffunction name="getNwsAlerts" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lon" type="numeric" required="true">

        <cfset local.out = { "ALERTS"=[], "META"={} }>
        <cfset local.ua = getNwsUserAgent()>
        <cfset local.url = "https://api.weather.gov/alerts/active?point=" & arguments.lat & "," & arguments.lon>
        <cfset local.httpStatus = 0>

        <cfhttp url="#local.url#" method="get" result="aRes" timeout="15">
            <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
            <cfhttpparam type="header" name="Accept" value="application/geo+json">
        </cfhttp>

        <cfset local.httpStatus = val(aRes.statusCode)>
        <cfif local.httpStatus LT 200 OR local.httpStatus GTE 300>
            <cfset local.out.META = { "source"="NWS", "status"=local.httpStatus, "url"=local.url }>
            <cfreturn local.out>
        </cfif>

        <cfreturn normalizeNwsAlerts(aRes.fileContent, { "source"="NWS", "url"=local.url, "status"=local.httpStatus })>
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
    <cffunction name="getMarineData" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lon" type="numeric" required="true">
        <cfargument name="noCache" type="boolean" required="false" default="false">
        <cfargument name="marineMode" type="string" required="false" default="full">
        <cfargument name="zipHint" type="string" required="false" default="">

        <cfset local.out = {} >
        <cfset local.meta = {} >
        <cfset local.maxLocalStationNm = 120>
        <cfset local.hasLocalTide = false>
        <cfset local.tide = {} >
        <cfset local.wl = {} >
        <cfset local.fetchTrend = (lcase(arguments.marineMode) NEQ "quick")>
        <cfset local.maxCandidateCount = (local.fetchTrend ? 10 : 4)>

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

        <cfif structCount(local.meta) GT 0>
            <cfset local.out.META = local.meta>
        </cfif>

        <cfreturn local.out>
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
                    </cfcatch>
                </cftry>
            </cfif>
        </cfloop>

        <cfif NOT structKeyExists(local.out, "tide") OR NOT arrayLen(local.out.tide.series)>
            <cfset local.hilo = getCoopsHiloSeries(arguments.stationId, local.beginUtc, local.endUtc)>
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

        <cfset local.hl = getCoopsNextHighLow(arguments.stationId)>
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
            <cfset marineCacheSet(local.cacheKey, local.out)>
        </cfif>

        <cfreturn local.out>
    </cffunction>

    <cffunction name="getCoopsNextHighLow" access="private" returntype="struct" output="false">
        <cfargument name="stationId" type="string" required="true">

        <cfset local.out = {} >
        <cfset local.ua = getNwsUserAgent()>
        <cfset local.begin = dateFormat(dateConvert("local2utc", now()), "yyyymmdd")>
        <cfset local.url = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?product=predictions&application=FPW&datum=MLLW&interval=hilo&units=english&time_zone=gmt&format=json&begin_date=" & urlEncodedFormat(local.begin) & "&range=48&station=" & urlEncodedFormat(arguments.stationId)>
        <cfset local.httpStatus = 0>

        <cfhttp url="#local.url#" method="get" result="hRes" timeout="20">
            <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
            <cfhttpparam type="header" name="Accept" value="application/json">
        </cfhttp>

        <cfset local.httpStatus = val(hRes.statusCode)>
        <cfif local.httpStatus GTE 200 AND local.httpStatus LT 300>
            <cftry>
                <cfset local.obj = deserializeJSON(hRes.fileContent)>
                <cfif structKeyExists(local.obj, "predictions") AND isArray(local.obj.predictions)>
                    <cfset local.nowTs = now()>
                    <cfloop from="1" to="#arrayLen(local.obj.predictions)#" index="local.i">
                        <cfset local.p = local.obj.predictions[local.i]>
                        <cfset local.pt = "">
                        <cftry>
                            <cfset local.pt = parseDateTime(local.p.t)>
                            <cfcatch>
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
                </cfcatch>
            </cftry>
        </cfif>

        <cfreturn local.out>
    </cffunction>

    <cffunction name="getCoopsHiloSeries" access="private" returntype="array" output="false">
        <cfargument name="stationId" type="string" required="true">
        <cfargument name="beginUtc" type="date" required="true">
        <cfargument name="endUtc" type="date" required="true">

        <cfset local.ua = getNwsUserAgent()>
        <cfset local.begin = dateFormat(arguments.beginUtc, "yyyymmdd")>
        <cfset local.url = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?product=predictions&application=FPW&datum=MLLW&interval=hilo&units=english&time_zone=gmt&format=json&begin_date=" & urlEncodedFormat(local.begin) & "&range=48&station=" & urlEncodedFormat(arguments.stationId)>
        <cfset local.out = []>

        <cfhttp url="#local.url#" method="get" result="hRes" timeout="20">
            <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
            <cfhttpparam type="header" name="Accept" value="application/json">
        </cfhttp>

        <cfif val(hRes.statusCode) GTE 200 AND val(hRes.statusCode) LT 300>
            <cftry>
                <cfset local.obj = deserializeJSON(hRes.fileContent)>
                <cfif structKeyExists(local.obj, "predictions") AND isArray(local.obj.predictions)>
                    <cfloop from="1" to="#arrayLen(local.obj.predictions)#" index="local.i">
                        <cfset local.p = local.obj.predictions[local.i]>
                        <cfif structKeyExists(local.p, "t") AND structKeyExists(local.p, "v")>
                            <cfset arrayAppend(local.out, { "t"=local.p.t, "h"=val(local.p.v), "type"=(structKeyExists(local.p,"type") ? local.p.type : "") })>
                        </cfif>
                    </cfloop>
                </cfif>
                <cfcatch>
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

        <cfif NOT isArray(local.list) OR arrayLen(local.list) EQ 0>
            <cfreturn local.out>
        </cfif>

        <cfloop from="1" to="#arrayLen(local.list)#" index="local.i">
            <cfset local.s = local.list[local.i]>
            <cfset local.sLat = val(local.s.lat)>
            <cfset local.sLon = val(local.s.lon)>
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
            <cfset local.out.BUOY_ID = local.best.id>
            <cfset local.out.NAME = (structKeyExists(local.best,"name") ? local.best.name : "")>
            <cfset local.out.META = { "source"="NDBC", "distanceNm"=local.bestD }>
        </cfif>

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
                <cfif structKeyExists(local.xml, "stations") AND structKeyExists(local.xml.stations, "station")>
                    <cfset local.nodes = local.xml.stations.station>
                    <cfif isArray(local.nodes)>
                        <cfloop from="1" to="#arrayLen(local.nodes)#" index="local.i">
                            <cfset local.n = local.nodes[local.i]>
                            <cfset arrayAppend(local.list, {
                                "id"=local.n.xmlAttributes.id,
                                "name"=(structKeyExists(local.n.xmlAttributes,"name") ? local.n.xmlAttributes.name : ""),
                                "lat"=local.n.xmlAttributes.lat,
                                "lon"=local.n.xmlAttributes.lon
                            })>
                        </cfloop>
                    <cfelse>
                        <cfset local.n = local.nodes>
                        <cfset arrayAppend(local.list, {
                            "id"=local.n.xmlAttributes.id,
                            "name"=(structKeyExists(local.n.xmlAttributes,"name") ? local.n.xmlAttributes.name : ""),
                            "lat"=local.n.xmlAttributes.lat,
                            "lon"=local.n.xmlAttributes.lon
                        })>
                    </cfif>
                </cfif>
                <cfcatch>
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

        <cfset local.cacheKey = "ndbc_wave:" & arguments.buoyId>
        <cfset local.cached = marineCacheGet(local.cacheKey, 600)>
        <cfif isStruct(local.cached)>
            <cfreturn local.cached>
        </cfif>

        <cfset local.url = "https://www.ndbc.noaa.gov/data/realtime2/" & urlEncodedFormat(arguments.buoyId) & ".txt">
        <cfset local.ua = getNwsUserAgent()>
        <cfset local.out = {} >

        <cfhttp url="#local.url#" method="get" result="bRes" timeout="20">
            <cfhttpparam type="header" name="User-Agent" value="#local.ua#">
            <cfhttpparam type="header" name="Accept" value="text/plain">
        </cfhttp>

        <cfif val(bRes.statusCode) GTE 200 AND val(bRes.statusCode) LT 300>
            <cfset local.lines = listToArray(bRes.fileContent, chr(10))>
            <cfset local.header = "">
            <cfset local.dataLine = "">
            <cfloop from="1" to="#arrayLen(local.lines)#" index="local.i">
                <cfset local.line = trim(local.lines[local.i])>
                <cfif NOT len(local.line)><cfcontinue></cfif>
                <cfif left(local.line,1) EQ "##">
                    <cfcontinue>
                </cfif>
                <cfif left(local.line,1) EQ "##">
                    <cfset local.header = rereplace(local.line, "^##+", "", "one")>
                    <cfset local.header = rereplace(local.header, "\\s+", " ", "all")>
                    <cfcontinue>
                </cfif>
                <cfset local.dataLine = rereplace(local.line, "\\s+", " ", "all")>
                <cfbreak>
            </cfloop>

            <cfif len(local.header) AND len(local.dataLine)>
                <cfset local.cols = listToArray(local.header, " ")>
                <cfset local.vals = listToArray(local.dataLine, " ")>
                <cfset local.map = {} >
                <cfloop from="1" to="#arrayLen(local.cols)#" index="local.i">
                    <cfset local.map[ local.cols[local.i] ] = local.vals[local.i]>
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

        <cfreturn local.out>
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

        <cfif NOT structKeyExists(application, "marineCache")>
            <cfset application.marineCache = {} >
        </cfif>

        <cfif structKeyExists(application.marineCache, arguments.key)>
            <cfset local.item = application.marineCache[arguments.key]>
            <cfif structKeyExists(local.item, "ts") AND dateDiff("s", local.item.ts, now()) LT arguments.ttlSeconds>
                <cfreturn (structKeyExists(local.item, "val") ? local.item.val : "")>
            </cfif>
        </cfif>

        <cfreturn "">
    </cffunction>

    <cffunction name="marineCacheSet" access="private" returntype="void" output="false">
        <cfargument name="key" type="string" required="true">
        <cfargument name="val" type="any" required="true">

        <cfif NOT structKeyExists(application, "marineCache")>
            <cfset application.marineCache = {} >
        </cfif>

        <cfset application.marineCache[arguments.key] = { "ts"=now(), "val"=arguments.val }>
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
                        <cfset arrayAppend(local.out.ALERTS, {
                            "event"=(structKeyExists(local.p,"event") ? local.p.event : ""),
                            "headline"=(structKeyExists(local.p,"headline") ? local.p.headline : ""),
                            "severity"=(structKeyExists(local.p,"severity") ? local.p.severity : ""),
                            "urgency"=(structKeyExists(local.p,"urgency") ? local.p.urgency : ""),
                            "certainty"=(structKeyExists(local.p,"certainty") ? local.p.certainty : ""),
                            "effective"=(structKeyExists(local.p,"effective") ? local.p.effective : ""),
                            "ends"=(structKeyExists(local.p,"ends") ? local.p.ends : ""),
                            "instruction"=(structKeyExists(local.p,"instruction") ? local.p.instruction : ""),
                            "description"=(structKeyExists(local.p,"description") ? local.p.description : "")
                        })>
                    </cfif>
                </cfloop>
            </cfif>

            <cfcatch>
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
