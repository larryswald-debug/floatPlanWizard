<cfcomponent output="false">

    <cffunction name="getPlacesPOIs" access="remote" returntype="void" output="true">
        <cfargument name="lat" type="any" required="false">
        <cfargument name="lng" type="any" required="false">
        <cfargument name="radiusNm" type="any" required="false">
        <cfargument name="types" type="any" required="false">
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

            <cfset args = arguments>
            <cfscript>
                function resolveInput(key, fallback, args, urlScope, bodyScope) {
                    if (structKeyExists(args, key)) return args[key];
                    if (structKeyExists(urlScope, key)) return urlScope[key];
                    if (structKeyExists(bodyScope, key)) return bodyScope[key];
                    return fallback;
                }
                function distanceKm(lat1, lon1, lat2, lon2) {
                    var toRad = function (value) { return value * (pi() / 180); };
                    var lat1Rad = toRad(lat1);
                    var lat2Rad = toRad(lat2);
                    var lonDiff = toRad(lon2 - lon1);
                    var inner = sin(lat1Rad) * sin(lat2Rad) +
                        cos(lat1Rad) * cos(lat2Rad) * cos(lonDiff);
                    inner = min(1, max(-1, inner));
                    return 6371 * acos(inner);
                }
                function sortPoisByDistance(pois) {
                    var i = 1;
                    var j = 1;
                    var temp = {};
                    for (i = 1; i LTE arrayLen(pois) - 1; i = i + 1) {
                        for (j = i + 1; j LTE arrayLen(pois); j = j + 1) {
                            if (pois[i]._distance GT pois[j]._distance) {
                                temp = pois[i];
                                pois[i] = pois[j];
                                pois[j] = temp;
                            }
                        }
                    }
                    return pois;
                }
            </cfscript>

            <cfset lat = resolveInput("lat", "", args, url, body)>
            <cfset lng = resolveInput("lng", "", args, url, body)>
            <cfset radiusNm = resolveInput("radiusNm", 10, args, url, body)>
            <cfset rawTypes = resolveInput("types", "", args, url, body)>

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
            <cfif radiusNm GT 50><cfset radiusNm = 50></cfif>

            <cfset allowedTypes = "marina,fuel,ramp,dock">
            <cfset typesArray = []>

            <cfif isArray(rawTypes)>
                <cfset typesArray = rawTypes>
            <cfelseif isSimpleValue(rawTypes) AND len(trim(rawTypes))>
                <cfset typesArray = listToArray(rawTypes)>
            </cfif>

            <cfset filteredTypes = []>
            <cfloop array="#typesArray#" index="typeItem">
                <cfset cleaned = lcase(trim(typeItem))>
                <cfif len(cleaned) AND listFindNoCase(allowedTypes, cleaned)>
                    <cfset arrayAppend(filteredTypes, cleaned)>
                </cfif>
            </cfloop>

            <cfif arrayLen(filteredTypes) EQ 0>
                <cfset response = {
                    SUCCESS = true,
                    AUTH    = true,
                    POIS    = []
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfset latKey = round(lat * 100) / 100>
            <cfset lngKey = round(lng * 100) / 100>
            <cfset typeKey = arrayToList(filteredTypes, ",")>
            <cfset cacheKey = latKey & "|" & lngKey & "|" & radiusNm & "|" & typeKey>
            <cfset cachedPois = "">
            <cflock scope="application" type="exclusive" timeout="2">
                <cfif NOT structKeyExists(application, "marinePoiCache")>
                    <cfset application.marinePoiCache = {} />
                </cfif>
                <cfif structKeyExists(application.marinePoiCache, cacheKey)>
                    <cfset cachedEntry = application.marinePoiCache[cacheKey]>
                    <cfif structKeyExists(cachedEntry, "timestamp") AND dateDiff("n", cachedEntry.timestamp, now()) LT 30>
                        <cfset cachedPois = cachedEntry.data>
                    </cfif>
                </cfif>
            </cflock>

            <cfif isArray(cachedPois)>
                <cfset response = {
                    SUCCESS = true,
                    AUTH    = true,
                    POIS    = cachedPois
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfset throttleKey = "ip:" & (structKeyExists(cgi, "remote_addr") ? cgi.remote_addr : "unknown")>
            <cfif isNumeric(userId) AND userId GT 0>
                <cfset throttleKey = "user:" & userId>
            </cfif>
            <cfset allowRequest = true>
            <cflock scope="application" type="exclusive" timeout="2">
                <cfif NOT structKeyExists(application, "marinePoiThrottle")>
                    <cfset application.marinePoiThrottle = {}>
                </cfif>
                <cfif structKeyExists(application.marinePoiThrottle, throttleKey)>
                    <cfset throttle = application.marinePoiThrottle[throttleKey]>
                <cfelse>
                    <cfset throttle = { count = 0, start = now() }>
                </cfif>
                <cfset elapsed = dateDiff("s", throttle.start, now())>
                <cfif elapsed GT 300>
                    <cfset throttle.count = 0>
                    <cfset throttle.start = now()>
                </cfif>
                <cfset throttle.count = throttle.count + 1>
                <cfset application.marinePoiThrottle[throttleKey] = throttle>
                <cfif throttle.count GT 120>
                    <cfset allowRequest = false>
                </cfif>
            </cflock>

            <cfif NOT allowRequest>
                <cfset response = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "RATE_LIMITED",
                    MESSAGE = "Too many requests. Please wait a moment."
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfset radiusMeters = radiusNm * 1852>
            <cfset queryParts = []>

            <cfif listFindNoCase(typeKey, "marina")>
                <cfset arrayAppend(queryParts, 'node["leisure"="marina"](around:#radiusMeters#,#lat#,#lng#);')>
                <cfset arrayAppend(queryParts, 'way["leisure"="marina"](around:#radiusMeters#,#lat#,#lng#);')>
                <cfset arrayAppend(queryParts, 'node["seamark:harbour"](around:#radiusMeters#,#lat#,#lng#);')>
                <cfset arrayAppend(queryParts, 'way["seamark:harbour"](around:#radiusMeters#,#lat#,#lng#);')>
            </cfif>
            <cfif listFindNoCase(typeKey, "ramp")>
                <cfset arrayAppend(queryParts, 'node["leisure"="slipway"](around:#radiusMeters#,#lat#,#lng#);')>
                <cfset arrayAppend(queryParts, 'way["leisure"="slipway"](around:#radiusMeters#,#lat#,#lng#);')>
                <cfset arrayAppend(queryParts, 'node["amenity"="boat_ramp"](around:#radiusMeters#,#lat#,#lng#);')>
                <cfset arrayAppend(queryParts, 'way["amenity"="boat_ramp"](around:#radiusMeters#,#lat#,#lng#);')>
            </cfif>
            <cfif listFindNoCase(typeKey, "fuel")>
                <cfset arrayAppend(queryParts, 'node["amenity"="fuel"]["boat"="yes"](around:#radiusMeters#,#lat#,#lng#);')>
                <cfset arrayAppend(queryParts, 'way["amenity"="fuel"]["boat"="yes"](around:#radiusMeters#,#lat#,#lng#);')>
                <cfset arrayAppend(queryParts, 'node["amenity"="fuel"]["fuel:marine"="yes"](around:#radiusMeters#,#lat#,#lng#);')>
                <cfset arrayAppend(queryParts, 'way["amenity"="fuel"]["fuel:marine"="yes"](around:#radiusMeters#,#lat#,#lng#);')>
                <cfset arrayAppend(queryParts, 'node["seamark:fuel"](around:#radiusMeters#,#lat#,#lng#);')>
                <cfset arrayAppend(queryParts, 'way["seamark:fuel"](around:#radiusMeters#,#lat#,#lng#);')>
                <cfset arrayAppend(queryParts, 'node["boat:service"="fuel"](around:#radiusMeters#,#lat#,#lng#);')>
                <cfset arrayAppend(queryParts, 'way["boat:service"="fuel"](around:#radiusMeters#,#lat#,#lng#);')>
            </cfif>
            <cfif listFindNoCase(typeKey, "dock")>
                <cfset arrayAppend(queryParts, 'node["man_made"="pier"](around:#radiusMeters#,#lat#,#lng#);')>
                <cfset arrayAppend(queryParts, 'way["man_made"="pier"](around:#radiusMeters#,#lat#,#lng#);')>
                <cfset arrayAppend(queryParts, 'node["seamark:mooring"](around:#radiusMeters#,#lat#,#lng#);')>
                <cfset arrayAppend(queryParts, 'way["seamark:mooring"](around:#radiusMeters#,#lat#,#lng#);')>
            </cfif>

            <cfset overpassQuery = "[out:json][timeout:10];(" & arrayToList(queryParts, "") & ");out center 50;">

            <cfset overpassUrls = [
                "https://overpass-api.de/api/interpreter",
                "https://overpass.kumi.systems/api/interpreter"
            ]>
            <cfset httpRes = {} />
            <cfset overpassData = {} />
            <cfset overpassRemark = "">
            <cfloop array="#overpassUrls#" index="overpassUrl">
                <cfhttp url="#overpassUrl#" method="post" result="httpRes" timeout="25">
                    <cfhttpparam type="formField" name="data" value="#overpassQuery#">
                </cfhttp>
                <cfif structKeyExists(httpRes, "statusCode") AND left(httpRes.statusCode, 3) EQ "200">
                    <cftry>
                        <cfset overpassData = deserializeJSON(httpRes.fileContent, false)>
                    <cfcatch>
                        <cfset overpassData = {} />
                    </cfcatch>
                    </cftry>
                    <cfif structKeyExists(overpassData, "remark")>
                        <cfset overpassRemark = overpassData.remark>
                    </cfif>
                    <cfif NOT len(overpassRemark)>
                        <cfbreak>
                    </cfif>
                </cfif>
            </cfloop>

            <cfif NOT structKeyExists(httpRes, "statusCode") OR NOT left(httpRes.statusCode, 3) EQ "200">
                <cfset response = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "OVERPASS_ERROR",
                    MESSAGE = "Unable to load marine POIs.",
                    DETAIL  = structKeyExists(httpRes, "statusCode") ? httpRes.statusCode : "no status"
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfif len(overpassRemark)>
                <cfset response = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "OVERPASS_ERROR",
                    MESSAGE = "Unable to load marine POIs.",
                    DETAIL  = overpassRemark
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfset pois = []>
            <cfif structKeyExists(overpassData, "elements") AND isArray(overpassData.elements)>
                <cfloop array="#overpassData.elements#" index="element">
                    <cfset tags = structKeyExists(element, "tags") ? element.tags : {}>
                    <cfset poiType = "">
                    <cfif structKeyExists(tags, "leisure") AND tags.leisure EQ "marina">
                        <cfset poiType = "marina">
                    <cfelseif structKeyExists(tags, "seamark:harbour")>
                        <cfset poiType = "marina">
                    <cfelseif structKeyExists(tags, "leisure") AND tags.leisure EQ "slipway">
                        <cfset poiType = "ramp">
                    <cfelseif structKeyExists(tags, "amenity") AND tags.amenity EQ "boat_ramp">
                        <cfset poiType = "ramp">
                    <cfelseif structKeyExists(tags, "amenity") AND tags.amenity EQ "fuel" AND (
                        (structKeyExists(tags, "boat") AND tags.boat EQ "yes")
                        OR (structKeyExists(tags, "fuel:marine") AND tags["fuel:marine"] EQ "yes")
                        OR (structKeyExists(tags, "boat:service") AND tags["boat:service"] EQ "fuel")
                    )>
                        <cfset poiType = "fuel">
                    <cfelseif structKeyExists(tags, "fuel:marine") AND tags["fuel:marine"] EQ "yes">
                        <cfset poiType = "fuel">
                    <cfelseif structKeyExists(tags, "boat:service") AND tags["boat:service"] EQ "fuel">
                        <cfset poiType = "fuel">
                    <cfelseif structKeyExists(tags, "seamark:fuel")>
                        <cfset poiType = "fuel">
                    <cfelseif structKeyExists(tags, "man_made") AND tags["man_made"] EQ "pier">
                        <cfset poiType = "dock">
                    <cfelseif structKeyExists(tags, "seamark:mooring")>
                        <cfset poiType = "dock">
                    </cfif>

                    <cfif len(poiType) EQ 0>
                        <cfcontinue>
                    </cfif>

                    <cfset poiLat = "">
                    <cfset poiLng = "">
                    <cfif structKeyExists(element, "lat") AND structKeyExists(element, "lon")>
                        <cfset poiLat = element.lat>
                        <cfset poiLng = element.lon>
                    <cfelseif structKeyExists(element, "center")>
                        <cfset poiLat = element.center.lat>
                        <cfset poiLng = element.center.lon>
                    </cfif>

                    <cfif NOT isNumeric(poiLat) OR NOT isNumeric(poiLng)>
                        <cfcontinue>
                    </cfif>

                    <cfset poiName = "">
                    <cfif structKeyExists(tags, "name")>
                        <cfset poiName = tags.name>
                    <cfelseif structKeyExists(tags, "seamark:name")>
                        <cfset poiName = tags["seamark:name"]>
                    </cfif>

                    <cfset summary = "">
                    <cfif structKeyExists(tags, "seamark:information")>
                        <cfset summary = tags["seamark:information"]>
                    <cfelseif structKeyExists(tags, "description")>
                        <cfset summary = tags.description>
                    <cfelseif structKeyExists(tags, "note")>
                        <cfset summary = tags.note>
                    </cfif>

                    <cfset addressParts = []>
                    <cfif structKeyExists(tags, "addr:housenumber")>
                        <cfset arrayAppend(addressParts, tags["addr:housenumber"])>
                    </cfif>
                    <cfif structKeyExists(tags, "addr:street")>
                        <cfset arrayAppend(addressParts, tags["addr:street"])>
                    </cfif>
                    <cfif structKeyExists(tags, "addr:city")>
                        <cfset arrayAppend(addressParts, tags["addr:city"])>
                    </cfif>
                    <cfset address = arrayLen(addressParts) ? arrayToList(addressParts, " ") : "">

                    <cfset details = {
                        address  = address,
                        website  = structKeyExists(tags, "website") ? tags.website : "",
                        phone    = structKeyExists(tags, "phone") ? tags.phone : (structKeyExists(tags, "contact:phone") ? tags["contact:phone"] : ""),
                        vhf      = structKeyExists(tags, "vhf") ? tags.vhf : (structKeyExists(tags, "seamark:communication:vhf") ? tags["seamark:communication:vhf"] : ""),
                        operator = structKeyExists(tags, "operator") ? tags.operator : ""
                    }>

                    <cfset poiStruct = {
                        id      = "osm:" & element.type & "/" & element.id,
                        source  = "osm",
                        type    = poiType,
                        name    = poiName,
                        lat     = val(poiLat),
                        lng     = val(poiLng),
                        summary = summary,
                        details = details,
                        _distance = distanceKm(lat, lng, val(poiLat), val(poiLng))
                    }>

                    <cfset arrayAppend(pois, poiStruct)>
                </cfloop>
            </cfif>

            <cfif arrayLen(pois) GT 1>
                <cfset pois = sortPoisByDistance(pois)>
            </cfif>

            <cfset limitedPois = []>
            <cfset maxItems = arrayLen(pois) GT 25 ? 25 : arrayLen(pois)>
            <cfloop from="1" to="#maxItems#" index="idx">
                <cfset structDelete(pois[idx], "_distance")>
                <cfset arrayAppend(limitedPois, pois[idx])>
            </cfloop>

            <cfset response = {
                SUCCESS = true,
                AUTH    = true,
                POIS    = limitedPois
            }>

            <cflock scope="application" type="exclusive" timeout="2">
                <cfset application.marinePoiCache[cacheKey] = { timestamp = now(), data = limitedPois }>
            </cflock>

            <cfoutput>#serializeJSON(response)#</cfoutput>

            <cfcatch type="any">
                <cfset errResponse = {
                    SUCCESS = false,
                    AUTH    = true,
                    ERROR   = "SERVER_ERROR",
                    MESSAGE = "Marine POI API error.",
                    DETAIL  = cfcatch.message
                }>
                <cfoutput>#serializeJSON(errResponse)#</cfoutput>
            </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

</cfcomponent>
