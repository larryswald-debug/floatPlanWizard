<cfcomponent displayname="FloatPlanPdfItineraryService" output="false" hint="Build the canonical route itinerary model used by float plan PDFs">
    <cffunction name="init" access="public" output="false" returntype="any">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            variables.datasource = arguments.datasource;
            return this;
        </cfscript>
    </cffunction>

    <cffunction name="getItinerary" access="public" output="false" returntype="struct">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var plan = loadPlan(arguments.floatPlanId);
            var routeInstanceId = getNumeric(plan, "route_instance_id", 0);
            var routeLegs = [];
            var projection = {};
            var routeTimeline = {};
            var projectionWarnings = [];
            var timezone = resolvePlanTimezone(plan);
            var model = {
                "isRouteBacked" = false,
                "floatPlanId" = arguments.floatPlanId,
                "routeInstanceId" = routeInstanceId,
                "planName" = getString(plan, "floatPlanName", ""),
                "timezone" = timezone,
                "legs" = [],
                "stops" = [],
                "officialLegs" = [],
                "continuationPages" = [],
                "warnings" = []
            };

            if (!structCount(plan) OR routeInstanceId LTE 0) {
                return model;
            }

            routeLegs = loadRouteLegs(routeInstanceId);
            if (!arrayLen(routeLegs)) {
                throw(
                    type = "FloatPlanPdfItinerary.RouteLegsMissing",
                    message = "The route-backed float plan has no canonical route legs.",
                    detail = "floatPlanId=#arguments.floatPlanId# routeInstanceId=#routeInstanceId#"
                );
            }

            try {
                projection = createProjectionService().getProjection(
                    arguments.floatPlanId,
                    "",
                    {
                        "includeOperationalLockTime" = false,
                        "allowDraftScheduledProjection" = true
                    }
                );
                if (
                    structKeyExists(projection, "routeInstanceId")
                    AND val(projection.routeInstanceId) GT 0
                    AND val(projection.routeInstanceId) NEQ routeInstanceId
                ) {
                    throw(
                        type = "FloatPlanPdfItinerary.RouteInstanceMismatch",
                        message = "The canonical projection route instance does not match the float plan.",
                        detail = "floatPlanId=#arguments.floatPlanId# planRouteInstanceId=#routeInstanceId# projectionRouteInstanceId=#val(projection.routeInstanceId)#"
                    );
                }
                if (
                    structKeyExists(projection, "dailyWindow")
                    AND isStruct(projection.dailyWindow)
                    AND len(getString(projection.dailyWindow, "timezone", ""))
                ) {
                    timezone = getString(projection.dailyWindow, "timezone", "");
                }
                if (structKeyExists(projection, "routeTimeline") AND isStruct(projection.routeTimeline)) {
                    routeTimeline = projection.routeTimeline;
                }
            } catch (any projectionErr) {
                if (
                    structKeyExists(projectionErr, "type")
                    AND compareNoCase(toString(projectionErr.type), "FloatPlanPdfItinerary.RouteInstanceMismatch") EQ 0
                ) {
                    rethrow;
                }
                arrayAppend(projectionWarnings, {
                    "code" = "ROUTE_TIMELINE_PROJECTION_ERROR",
                    "message" = projectionErr.message,
                    "routeLegOrder" = 0
                });
            }

            model = buildItineraryModel(
                routeLegs = routeLegs,
                routeTimeline = routeTimeline,
                timezone = timezone,
                floatPlanId = arguments.floatPlanId,
                routeInstanceId = routeInstanceId,
                planName = getString(plan, "floatPlanName", "")
            );

            for (var projectionWarningIndex = 1; projectionWarningIndex LTE arrayLen(projectionWarnings); projectionWarningIndex++) {
                arrayAppend(model.warnings, projectionWarnings[projectionWarningIndex]);
            }

            if (
                structKeyExists(projection, "success")
                AND !projection.success
                AND structKeyExists(projection, "message")
                AND len(trim(toString(projection.message)))
            ) {
                arrayAppend(model.warnings, {
                    "code" = "ROUTE_TIMELINE_UNAVAILABLE",
                    "message" = trim(toString(projection.message)),
                    "routeLegOrder" = 0
                });
            }

            return model;
        </cfscript>
    </cffunction>

    <cffunction name="buildItineraryModel" access="public" output="false" returntype="struct">
        <cfargument name="routeLegs" type="array" required="true">
        <cfargument name="routeTimeline" type="struct" required="false" default="#{}#">
        <cfargument name="timezone" type="string" required="true">
        <cfargument name="floatPlanId" type="numeric" required="false" default="0">
        <cfargument name="routeInstanceId" type="numeric" required="false" default="0">
        <cfargument name="planName" type="string" required="false" default="">
        <cfscript>
            var out = {
                "isRouteBacked" = (arrayLen(arguments.routeLegs) GT 0),
                "floatPlanId" = arguments.floatPlanId,
                "routeInstanceId" = arguments.routeInstanceId,
                "planName" = arguments.planName,
                "timezone" = trim(arguments.timezone),
                "legs" = [],
                "stops" = [],
                "officialLegs" = [],
                "continuationPages" = [],
                "warnings" = []
            };
            var projectedByOrder = {};
            var projectedLegs = [];
            var routeOrders = {};
            var i = 0;
            var routeLeg = {};
            var projectedLeg = {};
            var legOrder = 0;
            var origin = "";
            var destination = "";
            var previousDestination = "";
            var departureUtc = "";
            var arrivalUtc = "";
            var departureLocal = {};
            var arrivalLocal = {};
            var normalizedLeg = {};
            var stop = {};
            var continuationPage = [];
            var continuationIndex = 0;

            if (!arrayLen(arguments.routeLegs)) {
                return out;
            }
            if (!len(out.timezone)) {
                throw(
                    type = "FloatPlanPdfItinerary.TimezoneMissing",
                    message = "The canonical trip timezone is required for route itinerary formatting."
                );
            }

            if (
                structKeyExists(arguments.routeTimeline, "legs")
                AND isArray(arguments.routeTimeline.legs)
            ) {
                projectedLegs = arguments.routeTimeline.legs;
            }

            for (i = 1; i LTE arrayLen(projectedLegs); i++) {
                projectedLeg = projectedLegs[i];
                legOrder = getNumeric(projectedLeg, "routeLegOrder", 0);
                if (legOrder LTE 0) {
                    throw(
                        type = "FloatPlanPdfItinerary.InvalidProjectionSequence",
                        message = "A canonical projected route leg has no valid route leg order."
                    );
                }
                if (structKeyExists(projectedByOrder, toString(legOrder))) {
                    throw(
                        type = "FloatPlanPdfItinerary.DuplicateProjectionSequence",
                        message = "The canonical projection contains a duplicate route leg order.",
                        detail = "routeLegOrder=#legOrder#"
                    );
                }
                projectedByOrder[toString(legOrder)] = projectedLeg;
            }

            for (i = 1; i LTE arrayLen(arguments.routeLegs); i++) {
                routeLeg = arguments.routeLegs[i];
                legOrder = getNumeric(routeLeg, "routeLegOrder", getNumeric(routeLeg, "leg_order", 0));
                origin = trim(getString(routeLeg, "fromName", getString(routeLeg, "start_name", "")));
                destination = trim(getString(routeLeg, "toName", getString(routeLeg, "end_name", "")));

                if (legOrder NEQ i) {
                    throw(
                        type = "FloatPlanPdfItinerary.InvalidRouteSequence",
                        message = "Canonical route leg orders must be unique and contiguous beginning at 1.",
                        detail = "expectedLegOrder=#i# actualLegOrder=#legOrder#"
                    );
                }
                if (structKeyExists(routeOrders, toString(legOrder))) {
                    throw(
                        type = "FloatPlanPdfItinerary.DuplicateRouteSequence",
                        message = "The canonical route contains a duplicate route leg order.",
                        detail = "routeLegOrder=#legOrder#"
                    );
                }
                routeOrders[toString(legOrder)] = true;

                if (!len(origin) OR !len(destination)) {
                    throw(
                        type = "FloatPlanPdfItinerary.RouteLocationMissing",
                        message = "Every canonical route leg must have an origin and destination.",
                        detail = "routeLegOrder=#legOrder#"
                    );
                }
                if (
                    i GT 1
                    AND normalizeLocation(previousDestination) NEQ normalizeLocation(origin)
                ) {
                    throw(
                        type = "FloatPlanPdfItinerary.RouteContinuityFailure",
                        message = "Canonical route leg continuity failed.",
                        detail = "routeLegOrder=#legOrder# previousDestination=#previousDestination# origin=#origin#"
                    );
                }

                projectedLeg = (
                    structKeyExists(projectedByOrder, toString(legOrder))
                    ? projectedByOrder[toString(legOrder)]
                    : {}
                );
                departureUtc = getString(projectedLeg, "departureUtc", "");
                arrivalUtc = getString(projectedLeg, "arrivalUtc", "");
                departureLocal = formatUtcForTimezone(departureUtc, out.timezone);
                arrivalLocal = formatUtcForTimezone(arrivalUtc, out.timezone);

                if (!len(departureUtc)) {
                    arrayAppend(out.warnings, {
                        "code" = "ROUTE_LEG_DEPARTURE_TIME_MISSING",
                        "message" = "Canonical departure timing is unavailable; the PDF value will be blank.",
                        "routeLegOrder" = legOrder
                    });
                } else if (!departureLocal.valid) {
                    arrayAppend(out.warnings, {
                        "code" = "ROUTE_LEG_DEPARTURE_TIME_FORMAT_FAILED",
                        "message" = "Canonical departure timing could not be formatted; the PDF value will be blank.",
                        "routeLegOrder" = legOrder
                    });
                }
                if (!len(arrivalUtc)) {
                    arrayAppend(out.warnings, {
                        "code" = "ROUTE_LEG_ARRIVAL_TIME_MISSING",
                        "message" = "Canonical arrival timing is unavailable; the PDF value will be blank.",
                        "routeLegOrder" = legOrder
                    });
                } else if (!arrivalLocal.valid) {
                    arrayAppend(out.warnings, {
                        "code" = "ROUTE_LEG_ARRIVAL_TIME_FORMAT_FAILED",
                        "message" = "Canonical arrival timing could not be formatted; the PDF value will be blank.",
                        "routeLegOrder" = legOrder
                    });
                }

                normalizedLeg = {
                    "routeLegOrder" = legOrder,
                    "origin" = origin,
                    "destination" = destination,
                    "departureUtc" = departureUtc,
                    "arrivalUtc" = arrivalUtc,
                    "departureDate" = (departureLocal.valid ? departureLocal.date : ""),
                    "departureTime" = (departureLocal.valid ? departureLocal.time : ""),
                    "arrivalDate" = (arrivalLocal.valid ? arrivalLocal.date : ""),
                    "arrivalTime" = (arrivalLocal.valid ? arrivalLocal.time : "")
                };
                arrayAppend(out.legs, normalizedLeg);
                previousDestination = destination;
            }

            arrayAppend(out.stops, {
                "stopNumber" = 1,
                "location" = out.legs[1].origin,
                "arrivalDate" = "",
                "arrivalTime" = "",
                "departureDate" = out.legs[1].departureDate,
                "departureTime" = out.legs[1].departureTime
            });

            for (i = 1; i LTE arrayLen(out.legs); i++) {
                stop = {
                    "stopNumber" = i + 1,
                    "location" = out.legs[i].destination,
                    "arrivalDate" = out.legs[i].arrivalDate,
                    "arrivalTime" = out.legs[i].arrivalTime,
                    "departureDate" = "",
                    "departureTime" = ""
                };
                if (i LT arrayLen(out.legs)) {
                    stop.departureDate = out.legs[i + 1].departureDate;
                    stop.departureTime = out.legs[i + 1].departureTime;
                }
                arrayAppend(out.stops, stop);
            }

            for (i = 1; i LTE min(20, arrayLen(out.legs)); i++) {
                arrayAppend(out.officialLegs, out.legs[i]);
            }

            if (arrayLen(out.legs) GT 20) {
                continuationIndex = 21;
                while (continuationIndex LTE arrayLen(out.legs)) {
                    continuationPage = [];
                    for (
                        i = continuationIndex;
                        i LTE min(continuationIndex + 19, arrayLen(out.legs));
                        i++
                    ) {
                        arrayAppend(continuationPage, out.legs[i]);
                    }
                    arrayAppend(out.continuationPages, continuationPage);
                    continuationIndex += 20;
                }
            }

            return out;
        </cfscript>
    </cffunction>

    <cffunction name="loadPlan" access="private" output="false" returntype="struct">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var qPlan = queryExecute(
                "SELECT floatPlanId, route_instance_id, floatPlanName, departureTZ, departTimezone
                 FROM floatplans
                 WHERE floatPlanId = :floatPlanId
                 LIMIT 1",
                {
                    floatPlanId = {
                        value = arguments.floatPlanId,
                        cfsqltype = "cf_sql_integer"
                    }
                },
                { datasource = variables.datasource }
            );
            return queryRowToStruct(qPlan);
        </cfscript>
    </cffunction>

    <cffunction name="loadRouteLegs" access="private" output="false" returntype="array">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfscript>
            var qLegs = queryExecute(
                "SELECT id, leg_order, start_name, end_name
                 FROM route_instance_legs
                 WHERE route_instance_id = :routeInstanceId
                 ORDER BY leg_order ASC, id ASC",
                {
                    routeInstanceId = {
                        value = arguments.routeInstanceId,
                        cfsqltype = "cf_sql_integer"
                    }
                },
                { datasource = variables.datasource }
            );
            var legs = [];
            for (var i = 1; i LTE qLegs.recordCount; i++) {
                arrayAppend(legs, {
                    "routeLegOrder" = val(qLegs.leg_order[i]),
                    "fromName" = (isNull(qLegs.start_name[i]) ? "" : toString(qLegs.start_name[i])),
                    "toName" = (isNull(qLegs.end_name[i]) ? "" : toString(qLegs.end_name[i]))
                });
            }
            return legs;
        </cfscript>
    </cffunction>

    <cffunction name="createProjectionService" access="private" output="false" returntype="any">
        <cfscript>
            try {
                return createObject("component", "fpw.api.v1.TripProgressProjectionService").init(variables.datasource);
            } catch (any primaryPathErr) {
                return createObject("component", "api.v1.TripProgressProjectionService").init(variables.datasource);
            }
        </cfscript>
    </cffunction>

    <cffunction name="resolvePlanTimezone" access="private" output="false" returntype="string">
        <cfargument name="plan" type="struct" required="true">
        <cfscript>
            var timezone = getString(arguments.plan, "departureTZ", "");
            if (!len(timezone)) {
                timezone = getString(arguments.plan, "departTimezone", "");
            }
            if (!len(timezone) OR uCase(timezone) EQ "UTC") {
                timezone = "America/New_York";
            }
            return normalizePdfTimezone(timezone);
        </cfscript>
    </cffunction>

    <cffunction name="normalizePdfTimezone" access="private" output="false" returntype="string">
        <cfargument name="timezone" type="string" required="true">
        <cfscript>
            var timezoneId = trim(arguments.timezone);
            var timezoneKey = uCase(timezoneId);

            switch (timezoneKey) {
                case "US/EASTERN":
                    return "America/New_York";
                case "US/CENTRAL":
                    return "America/Chicago";
                case "US/MOUNTAIN":
                    return "America/Denver";
                case "US/PACIFIC":
                    return "America/Los_Angeles";
                case "US/ALASKA":
                    return "America/Anchorage";
                case "US/HAWAII":
                    return "Pacific/Honolulu";
                case "+00:00":
                case "UTC":
                case "ETC/UTC":
                case "GMT":
                    return "UTC";
            }

            if (!len(timezoneId)) {
                return "";
            }
            try {
                dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss", timezoneId);
                return timezoneId;
            } catch (any invalidTimezoneErr) {
                return "";
            }
        </cfscript>
    </cffunction>

    <cffunction name="formatUtcForTimezone" access="private" output="false" returntype="struct">
        <cfargument name="utcValue" type="any" required="true">
        <cfargument name="timezone" type="string" required="true">
        <cfscript>
            var out = { "valid" = false, "date" = "", "time" = "" };
            var rawUtc = normalizeUtcString(arguments.utcValue);
            var timezoneId = normalizePdfTimezone(arguments.timezone);
            var utcDateTime = "";

            if (!len(rawUtc) OR !len(timezoneId)) {
                return out;
            }

            try {
                utcDateTime = parseDateTime(replace(rawUtc, " ", "T", "one") & "Z");
                out.date = dateTimeFormat(utcDateTime, "mm/dd/yy", timezoneId);
                out.time = dateTimeFormat(utcDateTime, "HH:nn z", timezoneId);
                out.valid = true;
            } catch (any formatErr) {
                out.valid = false;
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeUtcString" access="private" output="false" returntype="string">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            var raw = "";
            if (isNull(arguments.value)) {
                return "";
            }
            raw = trim(toString(arguments.value));
            if (!len(raw)) {
                return "";
            }
            raw = replace(raw, "T", " ", "one");
            raw = reReplace(raw, "Z$", "", "one");
            raw = reReplace(raw, "\.[0-9]+$", "", "one");
            if (reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}$", raw)) {
                raw &= ":00";
            }
            if (!reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$", raw)) {
                return "";
            }
            return left(raw, 19);
        </cfscript>
    </cffunction>

    <cffunction name="normalizeLocation" access="private" output="false" returntype="string">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            return lcase(reReplace(trim(toString(arguments.value)), "\s+", " ", "all"));
        </cfscript>
    </cffunction>

    <cffunction name="queryRowToStruct" access="private" output="false" returntype="struct">
        <cfargument name="qry" type="query" required="true">
        <cfscript>
            var result = {};
            if (!arguments.qry.recordCount) {
                return result;
            }
            var columnNames = listToArray(arguments.qry.columnList);
            for (var columnIndex = 1; columnIndex LTE arrayLen(columnNames); columnIndex++) {
                var columnName = columnNames[columnIndex];
                result[columnName] = arguments.qry[columnName][1];
            }
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="getString" access="private" output="false" returntype="string">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfargument name="defaultValue" type="string" required="false" default="">
        <cfscript>
            if (
                structKeyExists(arguments.source, arguments.key)
                AND !isNull(arguments.source[arguments.key])
            ) {
                return toString(arguments.source[arguments.key]);
            }
            return arguments.defaultValue;
        </cfscript>
    </cffunction>

    <cffunction name="getNumeric" access="private" output="false" returntype="numeric">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfargument name="defaultValue" type="numeric" required="false" default="0">
        <cfscript>
            if (
                structKeyExists(arguments.source, arguments.key)
                AND !isNull(arguments.source[arguments.key])
                AND isNumeric(arguments.source[arguments.key])
            ) {
                return val(arguments.source[arguments.key]);
            }
            return arguments.defaultValue;
        </cfscript>
    </cffunction>
</cfcomponent>







