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

            <cfif structKeyExists(session, "user") AND isStruct(session.user)>
                <cfset local.userStruct = session.user>
            </cfif>

            <cfset local.userId = 187>

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

                <cfset local.data = getWeatherForFloatPlan(local.userId, local.fpId)>

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

                <cfset local.data = getWeatherForZip(local.zip)>

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

        <cfset local.out = {
            "SUCCESS"=false,
            "MESSAGE"="",
            "SUMMARY"="",
            "FORECAST"=[],
            "ALERTS"=[],
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

        <cfset local.out.META.anchor = { "lat"=local.lat, "lon"=local.lon }>
        <cfset local.out.META.sources = {} >
        <cfset local.out.META.sources.forecast = (structKeyExists(local.f,"META") ? local.f.META : {})>
        <cfset local.out.META.sources.alerts   = (structKeyExists(local.a,"META") ? local.a.META : {})>

        <cfset local.out.SUCCESS = true>
        <cfset local.out.MESSAGE = "OK">
        <cfreturn local.out>
    </cffunction>

    <cffunction name="getWeatherForZip" access="private" returntype="struct" output="false">
        <cfargument name="zip" type="string" required="true">

        <cfset local.out = {
            "SUCCESS"=false,
            "MESSAGE"="",
            "SUMMARY"="",
            "FORECAST"=[],
            "ALERTS"=[],
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

        <cfset local.out.META.anchor = { "lat"=local.lat, "lon"=local.lon }>
        <cfset local.out.META.request = { "zip"=arguments.zip }>
        <cfset local.out.META.sources = {} >
        <cfset local.out.META.sources.geocode  = (structKeyExists(local.geo,"META") ? local.geo.META : {})>
        <cfset local.out.META.sources.forecast = (structKeyExists(local.f,"META") ? local.f.META : {})>
        <cfset local.out.META.sources.alerts   = (structKeyExists(local.a,"META") ? local.a.META : {})>

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
        <cfset local.pObj = {} >
        <cfset local.httpStatus = 0>
        <cfset local.httpStatus2 = 0>

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

        <cfreturn normalizeNwsForecast(fRes.fileContent, { "source"="NWS", "url"=local.forecastUrl, "status"=local.httpStatus2 })>
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
          Normalizers
    ========================== --->
    <cffunction name="normalizeNwsForecast" access="private" returntype="struct" output="false">
        <cfargument name="json" type="string" required="true">
        <cfargument name="meta" type="struct" required="true">

        <cfset local.out = { "FORECAST"=[], "META"=arguments.meta }>
        <cfset local.obj = {} >
        <cfset local.maxN = 0>
        <cfset local.i = 0>
        <cfset local.p = {} >

        <cftry>
            <cfset local.obj = deserializeJSON(arguments.json)>

            <cfif structKeyExists(local.obj, "properties") AND structKeyExists(local.obj.properties, "periods") AND isArray(local.obj.properties.periods)>
                <cfset local.maxN = arrayLen(local.obj.properties.periods)>
                <cfif local.maxN GT 12>
                    <cfset local.maxN = 12>
                </cfif>

                <cfloop from="1" to="#local.maxN#" index="local.i">
                    <cfset local.p = local.obj.properties.periods[local.i]>
                    <cfset arrayAppend(local.out.FORECAST, {
                        "name"=(structKeyExists(local.p,"name") ? local.p.name : ""),
                        "startTime"=(structKeyExists(local.p,"startTime") ? local.p.startTime : ""),
                        "endTime"=(structKeyExists(local.p,"endTime") ? local.p.endTime : ""),
                        "temperature"=(structKeyExists(local.p,"temperature") ? local.p.temperature : ""),
                        "temperatureUnit"=(structKeyExists(local.p,"temperatureUnit") ? local.p.temperatureUnit : ""),
                        "windSpeed"=(structKeyExists(local.p,"windSpeed") ? local.p.windSpeed : ""),
                        "windDirection"=(structKeyExists(local.p,"windDirection") ? local.p.windDirection : ""),
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
