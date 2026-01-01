<cfcomponent output="false">

    <cffunction name="tile" access="remote" returntype="void" output="true">
        <cfargument name="target" required="false">
        <cfargument name="request" required="false">
        <cfargument name="service" required="false">
        <cfargument name="version" required="false">
        <cfargument name="layers" required="false">
        <cfargument name="styles" required="false">
        <cfargument name="bbox" required="false">
        <cfargument name="crs" required="false">
        <cfargument name="srs" required="false">
        <cfargument name="width" required="false">
        <cfargument name="height" required="false">
        <cfargument name="format" required="false">
        <cfargument name="transparent" required="false">
        <cfargument name="time" required="false">
        <cfargument name="exceptions" required="false">
        <cfargument name="bgcolor" required="false">
        <cfargument name="format_options" required="false">
        <cfargument name="tiled" required="false">
        <cfargument name="tilematrix" required="false">
        <cfargument name="tilematrixset" required="false">
        <cfargument name="tilecol" required="false">
        <cfargument name="tilerow" required="false">
        <cfargument name="i" required="false">
        <cfargument name="j" required="false">
        <cfargument name="query_layers" required="false">
        <cfargument name="info_format" required="false">
        <cfargument name="feature_count" required="false">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">

        <cfset var targets = {
            "nowcoast-radar" = "https://nowcoast.noaa.gov/arcgis/services/nowcoast/radar_meteo_imagery_nexrad_time/MapServer/WmsServer",
            "noaa-charts" = "https://gis.charttools.noaa.gov/arcgis/rest/services/MCS/NOAAChartDisplay/MapServer/exts/MaritimeChartService/WMSServer",
            "nws-radar" = "https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer"
        }>
        <cfset var targetKey = structKeyExists(arguments, "target") ? trim(toString(arguments.target)) : (structKeyExists(url, "target") ? trim(toString(url.target)) : "")>
        <cfset var normalizedTarget = lcase(reReplace(targetKey, "[^a-z0-9]", "", "all"))>
        <cfif normalizedTarget EQ "nwsradar">
            <cfset targetKey = "nws-radar">
        <cfelseif normalizedTarget EQ "nowcoastradar">
            <cfset targetKey = "nowcoast-radar">
        <cfelseif normalizedTarget EQ "noaacharts">
            <cfset targetKey = "noaa-charts">
        <cfelse>
            <cfset targetKey = lcase(trim(targetKey))>
        </cfif>
        <cfset var upstreamBase = structKeyExists(targets, targetKey) ? targets[targetKey] : "">
        <cfset var method = lcase(cgi.request_method)>
        <cfset var requestType = structKeyExists(url, "REQUEST") ? trim(toString(url.REQUEST)) : (structKeyExists(url, "request") ? trim(toString(url.request)) : "")>
        <cfset var serviceType = structKeyExists(url, "SERVICE") ? trim(toString(url.SERVICE)) : (structKeyExists(url, "service") ? trim(toString(url.service)) : "")>
        <cfset var widthVal = structKeyExists(url, "WIDTH") ? trim(toString(url.WIDTH)) : (structKeyExists(url, "width") ? trim(toString(url.width)) : "")>
        <cfset var heightVal = structKeyExists(url, "HEIGHT") ? trim(toString(url.HEIGHT)) : (structKeyExists(url, "height") ? trim(toString(url.height)) : "")>

        <cfset var statusCode = 200>
        <cfset var statusText = "OK">
        <cfset var responseBody = {} >

        <cfif method neq "get">
            <cfset statusCode = 405>
            <cfset statusText = "Method Not Allowed">
            <cfset responseBody = { SUCCESS = false, ERROR = "METHOD_NOT_ALLOWED", MESSAGE = "Only GET is allowed." }>
            <cfheader statuscode="#statusCode#">
            <cfcontent type="application/json; charset=utf-8">
            <cfoutput>#serializeJSON(responseBody)#</cfoutput>
            <cfsetting enablecfoutputonly="false">
            <cfreturn>
        </cfif>

        <cfif NOT len(upstreamBase)>
            <cfset statusCode = 403>
            <cfset statusText = "Forbidden">
            <cfset responseBody = { SUCCESS = false, ERROR = "INVALID_TARGET", MESSAGE = "Target not allowed.", DETAIL = targetKey }>
            <cfheader statuscode="#statusCode#">
            <cfcontent type="application/json; charset=utf-8">
            <cfoutput>#serializeJSON(responseBody)#</cfoutput>
            <cfsetting enablecfoutputonly="false">
            <cfreturn>
        </cfif>

        <cfif (findNoCase("/arcgis/services/", upstreamBase) EQ 0)
            AND (findNoCase("/geoserver/wms", upstreamBase) EQ 0)
            AND (findNoCase("/geoserver/ows", upstreamBase) EQ 0)
            AND (findNoCase("/eventdriven/services/", upstreamBase) EQ 0)>
            <cfset statusCode = 403>
            <cfset statusText = "Forbidden">
            <cfset responseBody = { SUCCESS = false, ERROR = "INVALID_PATH", MESSAGE = "Target path not allowed." }>
            <cfheader statuscode="#statusCode#">
            <cfcontent type="application/json; charset=utf-8">
            <cfoutput>#serializeJSON(responseBody)#</cfoutput>
            <cfsetting enablecfoutputonly="false">
            <cfreturn>
        </cfif>

        <cfif NOT (
            right(upstreamBase, 10) EQ "/WmsServer"
            OR right(upstreamBase, 10) EQ "/WMSServer"
            OR right(upstreamBase, 14) EQ "/geoserver/wms"
            OR right(upstreamBase, 14) EQ "/geoserver/ows"
        )>
            <cfset statusCode = 403>
            <cfset statusText = "Forbidden">
            <cfset responseBody = { SUCCESS = false, ERROR = "INVALID_PATH", MESSAGE = "Target endpoint not allowed." }>
            <cfheader statuscode="#statusCode#">
            <cfcontent type="application/json; charset=utf-8">
            <cfoutput>#serializeJSON(responseBody)#</cfoutput>
            <cfsetting enablecfoutputonly="false">
            <cfreturn>
        </cfif>

        <cfif NOT len(requestType)>
            <cfset statusCode = 400>
            <cfset statusText = "Bad Request">
            <cfset responseBody = { SUCCESS = false, ERROR = "MISSING_REQUEST", MESSAGE = "REQUEST parameter is required." }>
            <cfheader statuscode="#statusCode#">
            <cfcontent type="application/json; charset=utf-8">
            <cfoutput>#serializeJSON(responseBody)#</cfoutput>
            <cfsetting enablecfoutputonly="false">
            <cfreturn>
        </cfif>

        <cfset requestType = ucase(requestType)>
        <cfif NOT listFindNoCase("GETMAP,GETCAPABILITIES", requestType)>
            <cfset statusCode = 400>
            <cfset statusText = "Bad Request">
            <cfset responseBody = { SUCCESS = false, ERROR = "INVALID_REQUEST", MESSAGE = "REQUEST must be GetMap or GetCapabilities." }>
            <cfheader statuscode="#statusCode#">
            <cfcontent type="application/json; charset=utf-8">
            <cfoutput>#serializeJSON(responseBody)#</cfoutput>
            <cfsetting enablecfoutputonly="false">
            <cfreturn>
        </cfif>

        <cfif len(serviceType) AND ucase(serviceType) NEQ "WMS">
            <cfset statusCode = 400>
            <cfset statusText = "Bad Request">
            <cfset responseBody = { SUCCESS = false, ERROR = "INVALID_SERVICE", MESSAGE = "SERVICE must be WMS." }>
            <cfheader statuscode="#statusCode#">
            <cfcontent type="application/json; charset=utf-8">
            <cfoutput>#serializeJSON(responseBody)#</cfoutput>
            <cfsetting enablecfoutputonly="false">
            <cfreturn>
        </cfif>

        <cfif len(widthVal)>
            <cfif NOT isNumeric(widthVal) OR val(widthVal) GT 2048>
                <cfset statusCode = 400>
                <cfset statusText = "Bad Request">
                <cfset responseBody = { SUCCESS = false, ERROR = "INVALID_WIDTH", MESSAGE = "WIDTH must be numeric and <= 2048." }>
                <cfheader statuscode="#statusCode#">
                <cfcontent type="application/json; charset=utf-8">
                <cfoutput>#serializeJSON(responseBody)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfreturn>
            </cfif>
        </cfif>

        <cfif len(heightVal)>
            <cfif NOT isNumeric(heightVal) OR val(heightVal) GT 2048>
                <cfset statusCode = 400>
                <cfset statusText = "Bad Request">
                <cfset responseBody = { SUCCESS = false, ERROR = "INVALID_HEIGHT", MESSAGE = "HEIGHT must be numeric and <= 2048." }>
                <cfheader statuscode="#statusCode#">
                <cfcontent type="application/json; charset=utf-8">
                <cfoutput>#serializeJSON(responseBody)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfreturn>
            </cfif>
        </cfif>

        <cfset var queryPairs = []>
        <cfset var keyList = structKeyList(url)>
        <cfset var wmsKeys = {
            "SERVICE" = true,
            "REQUEST" = true,
            "VERSION" = true,
            "LAYERS" = true,
            "STYLES" = true,
            "FORMAT" = true,
            "TRANSPARENT" = true,
            "CRS" = true,
            "SRS" = true,
            "BBOX" = true,
            "WIDTH" = true,
            "HEIGHT" = true,
            "TIME" = true
        }>
        <cfset var emitted = {} >
        <cfloop list="#keyList#" index="key">
            <cfset var lowerKey = lcase(key)>
            <cfif lowerKey EQ "method" OR lowerKey EQ "target">
                <cfcontinue>
            </cfif>
            <cfset var value = url[key]>
            <cfif NOT isSimpleValue(value)>
                <cfcontinue>
            </cfif>
            <cfset var upperKey = ucase(key)>
            <cfif NOT structKeyExists(wmsKeys, upperKey)>
                <cfcontinue>
            </cfif>
            <cfset var outputKey = upperKey>
            <cfif structKeyExists(emitted, outputKey)>
                <cfcontinue>
            </cfif>
            <cfset emitted[outputKey] = true>
            <cfset arrayAppend(queryPairs, urlEncodedFormat(outputKey) & "=" & urlEncodedFormat(toString(value)))>
        </cfloop>

        <cfif requestType EQ "GETMAP" AND targetKey EQ "nws-radar">
            <cfset var requestedLayers = structKeyExists(url, "LAYERS") ? trim(toString(url.LAYERS)) : (structKeyExists(url, "layers") ? trim(toString(url.layers)) : "")>
            <cfif requestedLayers NEQ "radar_base_reflectivity_time">
                <cfset statusCode = 400>
                <cfset statusText = "Bad Request">
                <cfset responseBody = { SUCCESS = false, ERROR = "INVALID_LAYERS", MESSAGE = "LAYERS must be radar_base_reflectivity_time." }>
                <cfheader statuscode="#statusCode#">
                <cfcontent type="application/json; charset=utf-8">
                <cfoutput>#serializeJSON(responseBody)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfreturn>
            </cfif>
        </cfif>

        <cfset var queryString = arrayToList(queryPairs, "&")>
        <cfset var upstreamUrl = upstreamBase & (len(queryString) ? "?" & queryString : "")>

        <cfset var tempDir = getTempDirectory()>
        <cfset var tempName = "wms_" & createUUID() & ".bin">
        <cfset var tempPath = tempDir & tempName>

        <cfhttp url="#upstreamUrl#" method="get" result="httpRes" timeout="20" getAsBinary="yes" path="#tempDir#" file="#tempName#">
            <cfhttpparam type="header" name="User-Agent" value="Mozilla/5.0 (Macintosh; Intel Mac OS X 13_6_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36">
            <cfhttpparam type="header" name="Accept" value="image/png,image/*,*/*">
            <cfhttpparam type="header" name="Accept-Language" value="en-US,en;q=0.9">
            <cfhttpparam type="header" name="Connection" value="keep-alive">
            <cfhttpparam type="header" name="Referer" value="https://nowcoast.noaa.gov/">
            <cfhttpparam type="header" name="Origin" value="https://nowcoast.noaa.gov">
        </cfhttp>

        <cfset statusCode = val(listFirst(httpRes.statusCode, " "))>
        <cfset statusText = trim(reReplace(httpRes.statusCode, "^[0-9]+\\s*", ""))>
        <cfif statusCode EQ 0>
            <cfset statusCode = 502>
            <cfset statusText = "Bad Gateway">
        </cfif>

        <cfif statusCode NEQ 200>
            <cflog file="application" type="error" text="WMS proxy error target=#targetKey# status=#statusCode# #statusText#">
            <cfif fileExists(tempPath)>
                <cffile action="delete" file="#tempPath#">
            </cfif>
            <cfset responseBody = {
                SUCCESS = false,
                ERROR = "UPSTREAM_ERROR",
                MESSAGE = "Upstream WMS error.",
                statusCode = statusCode,
                statusText = statusText,
                upstreamUrl = upstreamBase & "?REQUEST=" & requestType
            }>
            <cfheader statuscode="#statusCode#">
            <cfcontent type="application/json; charset=utf-8">
            <cfoutput>#serializeJSON(responseBody)#</cfoutput>
            <cfsetting enablecfoutputonly="false">
            <cfreturn>
        </cfif>

        <cfif requestType EQ "GETMAP">
            <cfheader name="Cache-Control" value="public, max-age=300">
        <cfelseif requestType EQ "GETCAPABILITIES">
            <cfheader name="Cache-Control" value="public, max-age=3600">
        </cfif>

        <cfset var contentType = "application/octet-stream">
        <cfif structKeyExists(httpRes, "mimeType") AND len(httpRes.mimeType)>
            <cfset contentType = httpRes.mimeType>
        <cfelseif structKeyExists(httpRes, "responseheader") AND structKeyExists(httpRes.responseheader, "Content-Type")>
            <cfset contentType = httpRes.responseheader["Content-Type"]>
        </cfif>

        <cfset var responseText = "">
        <cfif findNoCase("xml", contentType) GT 0 OR findNoCase("text", contentType) GT 0>
            <cftry>
                <cfset responseText = fileRead(tempPath)>
            <cfcatch>
                <cfset responseText = "">
            </cfcatch>
            </cftry>
        </cfif>
        <cfset var hasServiceException = (len(responseText) AND (findNoCase("ServiceExceptionReport", responseText) GT 0 OR findNoCase("ExceptionReport", responseText) GT 0))>
        <cfif hasServiceException>
            <cfset var exceptionText = "">
            <cftry>
                <cfset exceptionText = reReplace(responseText, ".*<ExceptionText>([^<]+)</ExceptionText>.*", "\\1", "all")>
            <cfcatch>
                <cfset exceptionText = "">
            </cfcatch>
            </cftry>
            <cflog file="application" type="error" text="WMS proxy ServiceExceptionReport target=#targetKey# body=#left(responseText, 1500)#">
            <cfset statusCode = 502>
            <cfif fileExists(tempPath)>
                <cffile action="delete" file="#tempPath#">
            </cfif>
            <cfset responseBody = {
                SUCCESS = false,
                ERROR = "UPSTREAM_EXCEPTION",
                MESSAGE = "Upstream WMS returned a ServiceExceptionReport.",
                DETAIL = exceptionText,
                statusCode = statusCode,
                upstreamUrl = upstreamBase & "?REQUEST=" & requestType
            }>
            <cfheader statuscode="#statusCode#">
            <cfcontent type="application/json; charset=utf-8">
            <cfoutput>#serializeJSON(responseBody)#</cfoutput>
            <cfsetting enablecfoutputonly="false">
            <cfreturn>
        </cfif>

        <cfcontent type="#contentType#" file="#tempPath#" deleteFile="true" reset="true">
        <cfsetting enablecfoutputonly="false">
    </cffunction>

</cfcomponent>
