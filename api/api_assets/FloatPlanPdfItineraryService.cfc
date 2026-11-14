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

            model.guide_context = createObject("component", "fpw.api.v1.GuideTripService").init(variables.datasource).getSnapshotForInstance(routeInstanceId);
            model.guideSupplementHtml = structIsEmpty(model.guide_context) ? "" : buildGuideSupplementHtml(model.guide_context, model.planName);

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


    <cffunction name="buildGuideSupplementHtml" access="public" output="false" returntype="string">
        <cfargument name="context" type="struct" required="true">
        <cfargument name="planName" type="string" required="false" default="">
        <cfscript>
            var ctx = arguments.context;
            var legs = structKeyExists(ctx, "legs") AND isArray(ctx.legs) ? ctx.legs : [];
            var inputs = structKeyExists(ctx, "planning_inputs") AND isStruct(ctx.planning_inputs) ? ctx.planning_inputs : {};
            var html = '<html><head><meta charset="utf-8"><style>body{font-family:"DejaVu Sans",Arial,sans-serif;font-size:10pt;color:##172b3a;line-height:1.4}h1{font-size:18pt}h2{font-size:13pt;margin-top:18pt;page-break-after:avoid}table{border-collapse:collapse;width:100%;font-size:9pt}th,td{border:1px solid ##b7c5ce;padding:7pt;text-align:left;vertical-align:top}th{background:##eaf1f4}thead{display:table-header-group}tr{page-break-inside:avoid}.note{border-left:4px solid ##316b85;padding:8pt;background:##f2f6f8}.muted{color:##475966}p{margin:7pt 0;page-break-inside:avoid;orphans:2;widows:2}.guide-notes{page-break-inside:avoid}</style></head><body>';
            html &= '<h1>Guide trip planning estimates</h1><p>' & encodeForHTML(arguments.planName) & '</p>';
            html &= '<p class="note">Mileage, time and fuel are planning estimates. Member confirmation records review by the member; it is not independent route verification. Schematic map connections are not navigational tracks.</p>';
            html &= '<p>Source template: ' & encodeForHTML(getString(ctx, "template_key", "Guide itinerary")) & ' / version ' & encodeForHTML(getString(ctx, "template_version", "")) & '.</p>';
            html &= '<h2>Movement legs</h2><table><thead><tr><th>Leg</th><th>Estimated mileage</th><th>Source or calculation method</th><th>Member review / geometry</th></tr></thead><tbody>';
            for (var i = 1; i LTE arrayLen(legs); i++) {
                var leg = legs[i];
                var distanceText = "Missing - incomplete estimate";
                if (structKeyExists(leg, "distance_nm") AND !isNull(leg.distance_nm) AND isNumeric(leg.distance_nm) AND val(leg.distance_nm) GT 0)
                    distanceText = numberFormat(val(leg.distance_nm), "0.0") & (getString(leg, "distance_kind", "") EQ "member_entered" ? " nm - Member-entered estimate" : " nm (estimate)");
                var reviewText = "Not reviewed";
                var reviewStatus = getString(leg, "review_status", "");
                if (reviewStatus EQ "member_confirmed") reviewText = "Member confirmed";
                if (reviewStatus EQ "member_replaced") reviewText = "Member replaced and reviewed";
                if (len(getString(leg, "reviewed_at", ""))) reviewText &= " - " & getString(leg, "reviewed_at", "") & " UTC";
                var geometryText = getString(leg, "geometry_kind", "schematic") EQ "member_plotted" ? "Member-created plot" : "Schematic connection";
                var method = getString(leg, "distance_method", "");
                if (!len(trim(method))) method = "Not recorded - enter a source or method before Float Plan creation.";
                if (structKeyExists(leg, "source_ids") AND isArray(leg.source_ids) AND arrayLen(leg.source_ids))
                    method &= " Sources: " & arrayToList(leg.source_ids, ", ") & ".";
                html &= '<tr><td>' & i & '. ' & encodeForHTML(getString(leg, "start_name", "Start")) & ' to ' & encodeForHTML(getString(leg, "end_name", "End")) & '</td><td>' & encodeForHTML(distanceText) & '</td><td>' & encodeForHTML(method) & '</td><td>' & encodeForHTML(reviewText) & '<br>' & encodeForHTML(geometryText) & '</td></tr>';
            }
            html &= '</tbody></table><h2>Planning assumptions</h2>';
            html &= '<p>Speed: ' & encodeForHTML(getString(inputs, "planning_speed_kn", "missing")) & ' kn. Total vessel underway consumption: ' & encodeForHTML(getString(inputs, "underway_burn_us_gph", "missing")) & ' US gal/h.</p>';
            var reserveMode = getString(inputs, "reserve_mode", "missing");
            var reserveDescription = "Reserve method is missing.";
            if (reserveMode EQ "percentage")
                reserveDescription = "Percentage reserve: " & getString(inputs, "reserve_pct", "missing") & "% added to base consumption.";
            else if (reserveMode EQ "thirds")
                reserveDescription = "Thirds reserve: half of base consumption is added as reserve, making reserve one-third of the required departure quantity. The percentage input is not used.";
            html &= '<p>' & encodeForHTML(reserveDescription) & ' Reserve is included once in the estimated requirement. Time and fuel are estimates, not a crossing-safety decision.</p>';
            html &= '<p>Local and weather-wait days are notes, not scheduled movement legs. Review actual departure and return dates separately.</p>';
            if (len(getString(ctx, "trip_notes", "")))
                html &= '<p class="guide-notes"><strong>Trip notes:</strong> ' & replace(encodeForHTML(getString(ctx, "trip_notes", "")), chr(10), '<br>', 'all') & '</p>';
            var totals = structKeyExists(ctx, "totals") AND isStruct(ctx.totals) ? ctx.totals : {};
            var complete = structKeyExists(totals, "complete") AND isBoolean(totals.complete) AND totals.complete;
            html &= '<h2>' & (complete ? 'Estimated trip totals' : 'Known-leg subtotals - incomplete estimate') & '</h2>';
            html &= '<p>Distance: ' & (isNumeric(getString(totals, "known_distance_nm", "")) ? numberFormat(val(totals.known_distance_nm), "0.0") & ' nm' : 'missing') & '. ';
            var runMinutes = isNumeric(getString(totals, "known_run_hours", "")) ? round(val(totals.known_run_hours) * 60) : -1;
            html &= 'Movement time: ' & (runMinutes GTE 0 ? int(runMinutes / 60) & ' h ' & numberFormat(runMinutes MOD 60, "00") & ' min' : 'missing') & '. ';
            html &= 'Movement fuel: ' & (isNumeric(getString(totals, "known_cruise_fuel_us_gal", "")) ? numberFormat(val(totals.known_cruise_fuel_us_gal), "0.0") & ' US gal' : 'missing') & '.</p>';
            if (!complete) {
                html &= '<p class="note">Incomplete estimate: missing mileage, source/method or calculation inputs prevent a complete-trip requirement or fuel sufficiency result.</p>';
                if (structKeyExists(totals, "missing_inputs") AND isArray(totals.missing_inputs) AND arrayLen(totals.missing_inputs))
                    html &= '<p>Missing inputs: ' & encodeForHTML(arrayToList(totals.missing_inputs, ", ")) & '.</p>';
            } else {
                html &= '<p>Base fuel: ' & (isNumeric(getString(totals, "base_fuel_us_gal", "")) ? numberFormat(val(totals.base_fuel_us_gal), "0.0") : 'missing') & ' US gal. Reserve: ' & (isNumeric(getString(totals, "reserve_fuel_us_gal", "")) ? numberFormat(val(totals.reserve_fuel_us_gal), "0.0") : 'missing') & ' US gal. Estimated departure requirement: ' & (isNumeric(getString(totals, "required_fuel_us_gal", "")) ? numberFormat(val(totals.required_fuel_us_gal), "0.0") : 'missing') & ' US gal.</p>';
                if (isNumeric(getString(totals, "usable_above_requirement_us_gal", "")))
                    html &= '<p>Usable fuel above the estimated requirement: ' & numberFormat(val(totals.usable_above_requirement_us_gal), "0.0") & ' US gal. This is worksheet arithmetic, not a crossing-safety decision.</p>';
            }
            html &= '<p>Daily underway allowance: ' & encodeForHTML(getString(inputs, "underway_hours_per_day", "missing")) & ' hours. Idle/auxiliary consumption: ' & encodeForHTML(getString(inputs, "idle_burn_us_gph", "missing")) & ' US gal/h for ' & encodeForHTML(getString(inputs, "idle_hours_total", "missing")) & ' hours. Usable fuel aboard: ' & encodeForHTML(getString(inputs, "usable_fuel_us_gal", "missing")) & ' US gal.</p>';
            var sourceSnapshot = structKeyExists(ctx, "source_snapshot") AND isStruct(ctx.source_snapshot) ? ctx.source_snapshot : {};
            if (structKeyExists(sourceSnapshot, "verification") AND isStruct(sourceSnapshot.verification))
                html &= '<p class="muted">Source access/review date: ' & encodeForHTML(getString(sourceSnapshot.verification, "checked_at", "unspecified")) & '. Source retrieval does not verify navigation, services or availability.</p>';
            var guideUrl = getString(ctx, "canonical_url", getString(ctx, "canonical_guide_url", getString(sourceSnapshot, "canonical_url", "")));
            if (len(guideUrl) AND left(guideUrl, len("https://floatplanwizard.com/")) EQ "https://floatplanwizard.com/")
                html &= '<p class="muted">Public example and source register: ' & encodeForHTML(guideUrl) & '</p>';
            var citedIds = {};
            if (structKeyExists(sourceSnapshot, "stops") AND isArray(sourceSnapshot.stops)) {
                for (var stopSource in sourceSnapshot.stops) {
                    if (isStruct(stopSource) AND structKeyExists(stopSource, "source_ids") AND isArray(stopSource.source_ids))
                        for (var sourceId in stopSource.source_ids) citedIds[toString(sourceId)] = true;
                }
            }
            for (var sourceLeg in legs) {
                if (structKeyExists(sourceLeg, "source_ids") AND isArray(sourceLeg.source_ids))
                    for (var legSourceId in sourceLeg.source_ids) citedIds[toString(legSourceId)] = true;
            }
            if (structKeyExists(sourceSnapshot, "source_register_snapshot") AND isArray(sourceSnapshot.source_register_snapshot)) {
                html &= '<h2>Copied source records</h2><p>These records preserve the source information copied with this template version. Recheck current conditions and instructions before use.</p>';
                for (var sourceRecord in sourceSnapshot.source_register_snapshot) {
                    if (!isStruct(sourceRecord) OR !structKeyExists(citedIds, getString(sourceRecord, "id", ""))) continue;
                    html &= '<p><strong>' & encodeForHTML(getString(sourceRecord, "id", "") & ' - ' & getString(sourceRecord, "authority", "")) & '</strong><br>';
                    html &= encodeForHTML(getString(sourceRecord, "url", "")) & '<br>Accessed: ' & encodeForHTML(getString(sourceRecord, "accessed_at", "unspecified")) & '. Effective/revision date: ' & encodeForHTML(getString(sourceRecord, "effective_date", "unspecified")) & '.<br>';
                    html &= encodeForHTML(getString(sourceRecord, "claim", "")) & ' Source status: ' & encodeForHTML(getString(sourceRecord, "verification_status", "unspecified")) & '.</p>';
                }
            }
            html &= '</body></html>';
            return html;
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
