<cfcomponent output="false">

    <cfset variables.datasource = "fpw" />

    <cffunction name="init" access="public" returntype="any" output="false">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
            return this;
        </cfscript>
    </cffunction>

<cffunction name="routegenHasUserRouteTables" access="private" returntype="boolean" output="false">
        <cfscript>
            var qTbl = queryNew("");
            if (structKeyExists(request, "routegenHasUserRouteTables")) {
                return request.routegenHasUserRouteTables;
            }
            qTbl = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE()
                   AND table_name IN ('user_routes', 'user_route_legs')",
                {},
                { datasource = variables.datasource }
            );
            request.routegenHasUserRouteTables = (qTbl.recordCount GT 0 AND val(qTbl.cnt[1]) GTE 2);
            return request.routegenHasUserRouteTables;
        </cfscript>
    </cffunction>

<cffunction name="routegenHasUserRouteWaypointColumns" access="private" returntype="boolean" output="false">
        <cfscript>
            var qCol = queryNew("");
            if (structKeyExists(request, "routegenHasUserRouteWaypointColumns")) {
                return request.routegenHasUserRouteWaypointColumns;
            }
            qCol = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.columns
                 WHERE table_schema = DATABASE()
                   AND (
                     (table_name = 'user_routes' AND column_name = 'start_waypoint_id')
                     OR (table_name = 'user_route_legs' AND column_name IN ('start_waypoint_id', 'end_waypoint_id'))
                   )",
                {},
                { datasource = variables.datasource }
            );
            request.routegenHasUserRouteWaypointColumns = (qCol.recordCount GT 0 AND val(qCol.cnt[1]) GTE 3);
            return request.routegenHasUserRouteWaypointColumns;
        </cfscript>
    </cffunction>

<cffunction name="routegenComputeLegDefaultDistanceNm" access="private" returntype="numeric" output="false">
        <cfargument name="segmentDistNm" type="any" required="false" default="0">
        <cfargument name="startLat" type="any" required="false" default="">
        <cfargument name="startLng" type="any" required="false" default="">
        <cfargument name="endLat" type="any" required="false" default="">
        <cfargument name="endLng" type="any" required="false" default="">
        <cfscript>
            var distVal = roundTo2(val(arguments.segmentDistNm));
            if (distVal GT 0) return distVal;
            if (
                isNumeric(arguments.startLat)
                AND isNumeric(arguments.startLng)
                AND isNumeric(arguments.endLat)
                AND isNumeric(arguments.endLng)
            ) {
                distVal = roundTo2(routegenHaversineMeters(
                    val(arguments.startLat),
                    val(arguments.startLng),
                    val(arguments.endLat),
                    val(arguments.endLng)
                ) / 1852);
                if (distVal GT 0) return distVal;
            }
            return 0;
        </cfscript>
    </cffunction>

<cffunction name="resolveMyRouteById" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeId" type="numeric" required="true">
        <cfscript>
            var q = queryNew("");
            var hasWaypointCols = false;
            var selectCols = "";
            if (!routegenHasUserRouteTables()) return {};
            if (arguments.userId LTE 0 OR arguments.routeId LTE 0) return {};
            hasWaypointCols = routegenHasUserRouteWaypointColumns();
            selectCols = "id, route_name, is_active";
            if (hasWaypointCols) {
                selectCols &= ", start_waypoint_id";
            }
            q = queryExecute(
                "SELECT " & selectCols & "
                 FROM user_routes
                 WHERE id = :routeId
                   AND user_id = :uid
                 LIMIT 1",
                {
                    routeId = { value=arguments.routeId, cfsqltype="cf_sql_integer" },
                    uid = { value=arguments.userId, cfsqltype="cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );
            if (q.recordCount EQ 0) return {};
            return {
                "ROUTE_ID"=val(q.id[1]),
                "ROUTE_NAME"=(isNull(q.route_name[1]) ? "" : trim(toString(q.route_name[1]))),
                "IS_ACTIVE"=(isNull(q.is_active[1]) ? 0 : val(q.is_active[1])),
                "START_WAYPOINT_ID"=(
                    hasWaypointCols AND !isNull(q.start_waypoint_id[1])
                        ? val(q.start_waypoint_id[1])
                        : 0
                )
            };
        </cfscript>
    </cffunction>

<cffunction name="routegenResolvePositiveNumberByKeys" access="private" returntype="struct" output="false">
        <cfargument name="routeInputs" type="any" required="true">
        <cfargument name="keys" type="array" required="true">
        <cfscript>
            var out = {
                "value"=0,
                "key"="",
                "found"=false
            };
            var i = 0;
            var key = "";
            var rawValue = "";
            var numericVal = 0;
            var textValue = "";
            if (!isStruct(arguments.routeInputs)) return out;
            for (i = 1; i LTE arrayLen(arguments.keys); i++) {
                key = toString(arguments.keys[i]);
                if (!len(key) OR !structKeyExists(arguments.routeInputs, key)) {
                    continue;
                }
                rawValue = arguments.routeInputs[key];
                numericVal = 0;
                if (isSimpleValue(rawValue)) {
                    textValue = trim(toString(rawValue));
                    if (len(textValue) AND isNumeric(textValue)) {
                        numericVal = val(textValue);
                    }
                } else if (isNumeric(rawValue)) {
                    numericVal = val(rawValue);
                }
                if (numericVal GT 0) {
                    out.value = roundTo2(numericVal);
                    out.key = key;
                    out.found = true;
                    return out;
                }
            }
            return out;
        </cfscript>
    </cffunction>

<cffunction name="routegenResolveMostEfficientSpeedKn" access="private" returntype="numeric" output="false">
        <cfargument name="routeInputs" type="struct" required="true">
        <cfscript>
            var meta = routegenResolvePositiveNumberByKeys(
                arguments.routeInputs,
                [
                    "vessel_most_efficient_speed_kn",
                    "vesselMostEfficientSpeedKn",
                    "most_efficient_speed_kn",
                    "mostEfficientSpeedKn",
                    "MOST_EFFICIENT_SPEED_KN",
                    "MOST_EFFICIENT_SPEED"
                ]
            );
            return (meta.found ? meta.value : 0);
        </cfscript>
    </cffunction>

<cffunction name="routegenResolveMostEfficientBurnGph" access="private" returntype="numeric" output="false">
        <cfargument name="routeInputs" type="struct" required="true">
        <cfscript>
            var meta = routegenResolvePositiveNumberByKeys(
                arguments.routeInputs,
                [
                    "vessel_gph_at_most_efficient_speed",
                    "vesselGphAtMostEfficientSpeed",
                    "gph_at_most_efficient_speed",
                    "gphAtMostEfficientSpeed",
                    "GPH_AT_MOST_EFFICIENT_SPEED",
                    "GALLONS_PER_HOUR"
                ]
            );
            return (meta.found ? meta.value : 0);
        </cfscript>
    </cffunction>

<cffunction name="routegenResolveEffectiveSpeedMeta" access="private" returntype="struct" output="false">
        <cfargument name="routeInputs" type="struct" required="true">
        <cfscript>
            var out = {
                "speed_kn"=0,
                "speed_source"="default",
                "speed_key"=""
            };
            var userMeta = routegenResolvePositiveNumberByKeys(
                arguments.routeInputs,
                [
                    "speed_kn",
                    "speedKn",
                    "cruising_speed",
                    "cruisingSpeed",
                    "max_speed_kn",
                    "maxSpeedKn",
                    "CRUISING_SPEED",
                    "MAX_SPEED_KN"
                ]
            );
            var vesselMostEffSpeedVal = routegenResolveMostEfficientSpeedKn(arguments.routeInputs);
            var vesselMaxMeta = routegenResolvePositiveNumberByKeys(
                arguments.routeInputs,
                [
                    "vessel_max_speed_kn",
                    "vesselMaxSpeedKn",
                    "vessel_max_speed",
                    "vesselMaxSpeed",
                    "VESSEL_MAX_SPEED_KN",
                    "MAX_SPEED"
                ]
            );

            if (userMeta.found) {
                out.speed_kn = userMeta.value;
                out.speed_source = "route_inputs";
                out.speed_key = userMeta.key;
                return out;
            }
            if (vesselMostEffSpeedVal GT 0) {
                out.speed_kn = vesselMostEffSpeedVal;
                out.speed_source = "vessel_most_efficient";
                out.speed_key = "vessel_most_efficient_speed_kn";
                return out;
            }
            if (vesselMaxMeta.found) {
                out.speed_kn = vesselMaxMeta.value;
                out.speed_source = "vessel_max";
                out.speed_key = vesselMaxMeta.key;
                return out;
            }
            return out;
        </cfscript>
    </cffunction>

<cffunction name="routegenResolveFuelBurnGph" access="private" returntype="struct" output="false">
        <cfargument name="routeInputs" type="struct" required="true">
        <cfscript>
            var out = {
                "fuel_burn_gph"=0,
                "fuel_source"="missing",
                "fuel_key"=""
            };
            var primaryMeta = routegenResolvePositiveNumberByKeys(arguments.routeInputs, [ "fuel_burn_gph" ]);
            var aliasMeta = routegenResolvePositiveNumberByKeys(
                arguments.routeInputs,
                [ "fuelBurnGph", "fuel_burn_gph_input", "fuelBurnGphInput", "max_burn_gph", "maxBurnGph", "burn_gph", "burnGph", "FUEL_BURN_GPH" ]
            );
            var vesselBurnVal = routegenResolveMostEfficientBurnGph(arguments.routeInputs);

            if (primaryMeta.found) {
                out.fuel_burn_gph = primaryMeta.value;
                out.fuel_source = "route_inputs";
                out.fuel_key = primaryMeta.key;
                return out;
            }
            if (aliasMeta.found) {
                out.fuel_burn_gph = aliasMeta.value;
                out.fuel_source = "route_inputs_alias";
                out.fuel_key = aliasMeta.key;
                return out;
            }
            if (vesselBurnVal GT 0) {
                out.fuel_burn_gph = vesselBurnVal;
                out.fuel_source = "vessel_most_efficient";
                out.fuel_key = "vessel_gph_at_most_efficient_speed";
                return out;
            }
            return out;
        </cfscript>
    </cffunction>

<cffunction name="routegenResolvePerformanceModel" access="private" returntype="struct" output="false">
        <cfargument name="routeInputs" type="struct" required="true">
        <cfargument name="pace" type="any" required="false" default="RELAXED">
        <cfscript>
            var out = {
                "max_speed_kn"=0,
                "effective_speed_kn"=0,
                "speed_source"="default",
                "most_efficient_speed_kn"=0,
                "most_efficient_burn_gph"=0,
                "fuel_burn_gph"=0,
                "fuel_source"="missing",
                "fuel_key"="",
                "pace_ratio"=0,
                "burn_model"="legacy",
                "max_burn_for_estimate"=0
            };
            var paceVal = routegenNormalizePace(arguments.pace);
            var paceDefaults = routegenPaceDefaults(paceVal);
            var paceFactor = val(paceDefaults.PACE_FACTOR);
            var speedMeta = routegenResolveEffectiveSpeedMeta(arguments.routeInputs);
            var fuelMeta = routegenResolveFuelBurnGph(arguments.routeInputs);
            var mostEffSpeedVal = routegenResolveMostEfficientSpeedKn(arguments.routeInputs);
            var mostEffBurnVal = routegenResolveMostEfficientBurnGph(arguments.routeInputs);
            var resolvedMaxSpeedVal = 0;
            var resolvedEffectiveSpeedVal = 0;
            var effectiveRatioToMostEff = 0;
            var effectiveBurnAtSpeed = 0;
            var derivedMaxBurnVal = 0;
            var usingUserFuel = false;

            if (paceFactor LT 0.05) paceFactor = 0.05;
            if (paceFactor GT 1) paceFactor = 1;

            if (val(speedMeta.speed_kn) GT 0) {
                resolvedMaxSpeedVal = routegenNormalizeCruisingSpeed(speedMeta.speed_kn, paceDefaults.MAX_SPEED_KN);
                out.speed_source = trim(toString(speedMeta.speed_source));
            } else {
                resolvedMaxSpeedVal = routegenNormalizeCruisingSpeed("", paceDefaults.MAX_SPEED_KN);
                out.speed_source = "default";
            }
            resolvedEffectiveSpeedVal = routegenComputeEffectiveCruisingSpeed(
                resolvedMaxSpeedVal,
                paceVal,
                mostEffSpeedVal
            );
            out.max_speed_kn = resolvedMaxSpeedVal;
            out.effective_speed_kn = resolvedEffectiveSpeedVal;
            out.most_efficient_speed_kn = roundTo2(mostEffSpeedVal);
            out.most_efficient_burn_gph = roundTo2(mostEffBurnVal);
            out.fuel_burn_gph = routegenNormalizeFuelBurnGph(fuelMeta.fuel_burn_gph);
            out.fuel_source = trim(toString(fuelMeta.fuel_source));
            out.fuel_key = trim(toString(fuelMeta.fuel_key));

            usingUserFuel = (out.fuel_source EQ "route_inputs" OR out.fuel_source EQ "route_inputs_alias");

            if (paceVal EQ "BALANCED") {
                if (resolvedMaxSpeedVal GT 0 AND resolvedEffectiveSpeedVal GT 0) {
                    out.pace_ratio = roundTo2(resolvedEffectiveSpeedVal / resolvedMaxSpeedVal);
                }
                if (resolvedEffectiveSpeedVal GT 0 AND mostEffSpeedVal GT 0) {
                    out.speed_source = "vessel_most_efficient";
                }
                if (!usingUserFuel) {
                    out.fuel_burn_gph = (mostEffBurnVal GT 0 ? roundTo2(mostEffBurnVal) : 0);
                    out.fuel_source = (mostEffBurnVal GT 0 ? "vessel_most_efficient" : "missing");
                    out.fuel_key = "vessel_gph_at_most_efficient_speed";
                    out.burn_model = "most_efficient";
                }
                out.max_burn_for_estimate = out.fuel_burn_gph;
                if (out.max_burn_for_estimate LT 0) out.max_burn_for_estimate = 0;
                return out;
            }

            out.max_burn_for_estimate = out.fuel_burn_gph;

            if (!usingUserFuel AND resolvedEffectiveSpeedVal GT 0 AND mostEffSpeedVal GT 0 AND mostEffBurnVal GT 0) {
                effectiveRatioToMostEff = (resolvedEffectiveSpeedVal / mostEffSpeedVal);
                out.pace_ratio = roundTo2(effectiveRatioToMostEff);
                effectiveBurnAtSpeed = paceAdjustedBurnGph(mostEffBurnVal, effectiveRatioToMostEff, 3.0);
                if (paceFactor GT 0 AND effectiveBurnAtSpeed GT 0) {
                    derivedMaxBurnVal = roundTo2(effectiveBurnAtSpeed / (paceFactor ^ 3));
                    if (derivedMaxBurnVal GT 0) {
                        out.max_burn_for_estimate = derivedMaxBurnVal;
                        out.burn_model = "pace_adjusted";
                    }
                }
            }

            if (out.max_burn_for_estimate LT 0) out.max_burn_for_estimate = 0;
            return out;
        </cfscript>
    </cffunction>

<cffunction name="resolveTimelineFuelBurnFromInputs" access="private" returntype="struct" output="false">
        <cfargument name="routeInputs" type="struct" required="true">
        <cfscript>
            return routegenResolveFuelBurnGph(arguments.routeInputs);
        </cfscript>
    </cffunction>

<cffunction name="routegenNormalizeTimelineInputOverrides" access="private" returntype="struct" output="false">
        <cfargument name="inputOverrides" type="any" required="false" default="#structNew()#">
        <cfscript>
            var src = (isStruct(arguments.inputOverrides) ? arguments.inputOverrides : {});
            var out = {};
            var paceIndexVal = 0;
            var hasFuelOverride = false;
            var fuelRaw = "";

            if (structKeyExists(src, "pace")) {
                out.pace = routegenNormalizePace(src.pace);
            } else if (structKeyExists(src, "pace_index")) {
                paceIndexVal = val(src.pace_index);
                out.pace = (paceIndexVal GTE 2 ? "AGGRESSIVE" : (paceIndexVal EQ 1 ? "BALANCED" : "RELAXED"));
            } else if (structKeyExists(src, "paceIndex")) {
                paceIndexVal = val(src.paceIndex);
                out.pace = (paceIndexVal GTE 2 ? "AGGRESSIVE" : (paceIndexVal EQ 1 ? "BALANCED" : "RELAXED"));
            }

            if (structKeyExists(src, "cruising_speed")) {
                out.cruising_speed = routegenNormalizeCruisingSpeed(src.cruising_speed, 20);
            } else if (structKeyExists(src, "cruisingSpeed")) {
                out.cruising_speed = routegenNormalizeCruisingSpeed(src.cruisingSpeed, 20);
            } else if (structKeyExists(src, "max_speed_kn")) {
                out.cruising_speed = routegenNormalizeCruisingSpeed(src.max_speed_kn, 20);
            } else if (structKeyExists(src, "maxSpeedKn")) {
                out.cruising_speed = routegenNormalizeCruisingSpeed(src.maxSpeedKn, 20);
            }

            if (structKeyExists(src, "underway_hours_per_day")) {
                out.underway_hours_per_day = routegenNormalizeUnderwayHours(src.underway_hours_per_day);
            } else if (structKeyExists(src, "underwayHoursPerDay")) {
                out.underway_hours_per_day = routegenNormalizeUnderwayHours(src.underwayHoursPerDay);
            }

            if (structKeyExists(src, "fuel_burn_gph")) {
                fuelRaw = src.fuel_burn_gph;
                hasFuelOverride = true;
            } else if (structKeyExists(src, "fuelBurnGph")) {
                fuelRaw = src.fuelBurnGph;
                hasFuelOverride = true;
            } else if (structKeyExists(src, "max_burn_gph")) {
                fuelRaw = src.max_burn_gph;
                hasFuelOverride = true;
            } else if (structKeyExists(src, "maxBurnGph")) {
                fuelRaw = src.maxBurnGph;
                hasFuelOverride = true;
            } else if (structKeyExists(src, "burn_gph")) {
                fuelRaw = src.burn_gph;
                hasFuelOverride = true;
            } else if (structKeyExists(src, "burnGph")) {
                fuelRaw = src.burnGph;
                hasFuelOverride = true;
            }
            if (hasFuelOverride) {
                out.fuel_burn_gph = routegenNormalizeFuelBurnGph(fuelRaw);
            }

            if (structKeyExists(src, "vessel_max_speed_kn")) {
                out.vessel_max_speed_kn = roundTo2(val(src.vessel_max_speed_kn));
            } else if (structKeyExists(src, "vesselMaxSpeedKn")) {
                out.vessel_max_speed_kn = roundTo2(val(src.vesselMaxSpeedKn));
            }
            if (structKeyExists(out, "vessel_max_speed_kn") AND val(out.vessel_max_speed_kn) LT 1) {
                structDelete(out, "vessel_max_speed_kn");
            }
            if (structKeyExists(out, "vessel_max_speed_kn") AND val(out.vessel_max_speed_kn) GT 60) {
                out.vessel_max_speed_kn = 60;
            }

            if (structKeyExists(src, "vessel_most_efficient_speed_kn")) {
                out.vessel_most_efficient_speed_kn = roundTo2(val(src.vessel_most_efficient_speed_kn));
            } else if (structKeyExists(src, "vesselMostEfficientSpeedKn")) {
                out.vessel_most_efficient_speed_kn = roundTo2(val(src.vesselMostEfficientSpeedKn));
            }
            if (structKeyExists(out, "vessel_most_efficient_speed_kn") AND val(out.vessel_most_efficient_speed_kn) LT 1) {
                structDelete(out, "vessel_most_efficient_speed_kn");
            }
            if (structKeyExists(out, "vessel_most_efficient_speed_kn") AND val(out.vessel_most_efficient_speed_kn) GT 60) {
                out.vessel_most_efficient_speed_kn = 60;
            }

            if (structKeyExists(src, "vessel_gph_at_most_efficient_speed")) {
                out.vessel_gph_at_most_efficient_speed = routegenNormalizeFuelBurnGph(src.vessel_gph_at_most_efficient_speed);
            } else if (structKeyExists(src, "vesselGphAtMostEfficientSpeed")) {
                out.vessel_gph_at_most_efficient_speed = routegenNormalizeFuelBurnGph(src.vesselGphAtMostEfficientSpeed);
            }
            if (structKeyExists(out, "vessel_gph_at_most_efficient_speed") AND val(out.vessel_gph_at_most_efficient_speed) LTE 0) {
                structDelete(out, "vessel_gph_at_most_efficient_speed");
            }

            if (structKeyExists(src, "reserve_pct")) {
                out.reserve_pct = routegenNormalizeReservePct(src.reserve_pct, 33);
            } else if (structKeyExists(src, "reservePct")) {
                out.reserve_pct = routegenNormalizeReservePct(src.reservePct, 33);
            }

            if (structKeyExists(src, "weather_factor_pct")) {
                out.weather_factor_pct = routegenNormalizeWeatherFactorPct(src.weather_factor_pct);
            } else if (structKeyExists(src, "weatherFactorPct")) {
                out.weather_factor_pct = routegenNormalizeWeatherFactorPct(src.weatherFactorPct);
            } else if (structKeyExists(src, "weather_factor")) {
                out.weather_factor_pct = routegenNormalizeWeatherFactorPct(src.weather_factor);
            } else if (structKeyExists(src, "weatherFactor")) {
                out.weather_factor_pct = routegenNormalizeWeatherFactorPct(src.weatherFactor);
            }

            return out;
        </cfscript>
    </cffunction>

<cffunction name="routegenBuildTimelineInputs" access="private" returntype="struct" output="false">
        <cfargument name="storedInputs" type="any" required="false" default="#structNew()#">
        <cfargument name="inputOverrides" type="any" required="false" default="#structNew()#">
        <cfscript>
            var merged = (isStruct(arguments.storedInputs) ? duplicate(arguments.storedInputs) : {});
            var overrides = routegenNormalizeTimelineInputOverrides(arguments.inputOverrides);
            for (var key in overrides) {
                merged[key] = overrides[key];
            }
            return merged;
        </cfscript>
    </cffunction>

<cffunction name="routegenTimelinePickLegValue" access="private" returntype="any" output="false">
        <cfargument name="row" type="any" required="true">
        <cfargument name="keys" type="array" required="true">
        <cfargument name="fallback" type="any" required="false" default="">
        <cfscript>
            if (!isStruct(arguments.row)) return arguments.fallback;
            for (var key in arguments.keys) {
                if (structKeyExists(arguments.row, key)) {
                    return arguments.row[key];
                }
            }
            return arguments.fallback;
        </cfscript>
    </cffunction>

<cffunction name="routegenNormalizeTimelinePreviewLegs" access="private" returntype="array" output="false">
        <cfargument name="previewLegsRaw" type="any" required="false" default="#[]#">
        <cfscript>
            var src = (isArray(arguments.previewLegsRaw) ? arguments.previewLegsRaw : []);
            var byOrder = {};
            var orderKeys = [];
            var out = [];
            var i = 0;
            var row = {};
            var orderRaw = "";
            var orderVal = 0;
            var routeLegIdRaw = "";
            var routeLegIdVal = 0;
            var segmentIdRaw = "";
            var segmentIdVal = 0;
            var idRaw = "";
            var idVal = 0;
            var distRaw = "";
            var distVal = 0;
            var lockRaw = "";
            var lockVal = 0;
            var lockTimeMinRaw = "";
            var lockTimeMinVal = 0;
            var isOffshoreRaw = "";
            var isOffshoreVal = 0;
            var isIcwRaw = "";
            var isIcwVal = 0;
            var exposureOverrideRaw = "";
            var exposureOverrideVal = "";
            var startNameVal = "";
            var endNameVal = "";
            var orderKey = "";

            for (i = 1; i LTE arrayLen(src); i++) {
                row = src[i];
                if (!isStruct(row)) continue;

                orderRaw = routegenTimelinePickLegValue(
                    row,
                    ["order_index", "ORDER_INDEX", "order", "ORDER", "leg_order", "LEG_ORDER"],
                    ""
                );
                if (!isNumeric(orderRaw)) continue;
                orderVal = int(val(orderRaw));
                if (orderVal LTE 0) continue;
                orderKey = toString(orderVal);
                if (structKeyExists(byOrder, orderKey)) continue;

                routeLegIdRaw = routegenTimelinePickLegValue(row, ["route_leg_id", "ROUTE_LEG_ID"], "");
                routeLegIdVal = (isNumeric(routeLegIdRaw) ? int(val(routeLegIdRaw)) : 0);
                segmentIdRaw = routegenTimelinePickLegValue(row, ["segment_id", "SEGMENT_ID"], "");
                segmentIdVal = (isNumeric(segmentIdRaw) ? int(val(segmentIdRaw)) : 0);
                idRaw = routegenTimelinePickLegValue(row, ["id", "ID"], "");
                idVal = (isNumeric(idRaw) ? int(val(idRaw)) : 0);
                if (routeLegIdVal LTE 0 AND segmentIdVal LTE 0 AND idVal LTE 0) continue;

                distRaw = routegenTimelinePickLegValue(row, ["dist_nm", "DIST_NM", "distance_nm", "DISTANCE_NM"], "");
                if (!isNumeric(distRaw)) continue;
                distVal = val(distRaw);
                if (distVal LT 0) distVal = 0;

                lockRaw = routegenTimelinePickLegValue(row, ["lock_count", "LOCK_COUNT", "locks", "LOCKS"], "");
                lockVal = (isNumeric(lockRaw) ? int(val(lockRaw)) : 0);
                if (lockVal LT 0) lockVal = 0;
                lockTimeMinRaw = routegenTimelinePickLegValue(row, ["lock_time_min_total", "LOCK_TIME_MIN_TOTAL"], "");
                lockTimeMinVal = (isNumeric(lockTimeMinRaw) ? val(lockTimeMinRaw) : 0);
                if (lockTimeMinVal LT 0) lockTimeMinVal = 0;
                isOffshoreRaw = routegenTimelinePickLegValue(row, ["is_offshore", "IS_OFFSHORE", "offshore", "OFFSHORE"], "");
                isOffshoreVal = (isNumeric(isOffshoreRaw) AND val(isOffshoreRaw) GT 0 ? 1 : 0);
                isIcwRaw = routegenTimelinePickLegValue(row, ["is_icw", "IS_ICW", "icw", "ICW"], "");
                isIcwVal = (isNumeric(isIcwRaw) AND val(isIcwRaw) GT 0 ? 1 : 0);
                exposureOverrideRaw = routegenTimelinePickLegValue(row, ["exposure_level", "EXPOSURE_LEVEL"], "");
                exposureOverrideVal = "";
                if (isNumeric(exposureOverrideRaw)) {
                    exposureOverrideVal = int(val(exposureOverrideRaw));
                    if (exposureOverrideVal LT 0 OR exposureOverrideVal GT 3) {
                        exposureOverrideVal = "";
                    }
                }

                startNameVal = trim(toString(routegenTimelinePickLegValue(row, ["start_name", "START_NAME"], "")));
                endNameVal = trim(toString(routegenTimelinePickLegValue(row, ["end_name", "END_NAME"], "")));

                byOrder[orderKey] = {
                    "order_index"=orderVal,
                    "id"=(routeLegIdVal GT 0 ? routeLegIdVal : (segmentIdVal GT 0 ? segmentIdVal : idVal)),
                    "route_leg_id"=routeLegIdVal,
                    "segment_id"=segmentIdVal,
                    "start_name"=startNameVal,
                    "end_name"=endNameVal,
                    "dist_nm"=roundTo2(distVal),
                    "lock_count"=lockVal,
                    "lock_time_min_total"=roundTo2(lockTimeMinVal),
                    "is_offshore"=isOffshoreVal,
                    "is_icw"=isIcwVal,
                    "exposure_level"=exposureOverrideVal
                };
                arrayAppend(orderKeys, orderVal);
            }

            if (arrayLen(orderKeys) GT 1) {
                arraySort(orderKeys, "numeric", "asc");
            }
            for (i = 1; i LTE arrayLen(orderKeys); i++) {
                orderKey = toString(orderKeys[i]);
                if (structKeyExists(byOrder, orderKey)) {
                    arrayAppend(out, byOrder[orderKey]);
                }
            }
            return out;
        </cfscript>
    </cffunction>

<cffunction name="routegenBuildCruiseTimelineDay" access="private" returntype="struct" output="false">
        <cfargument name="dateValue" type="any" required="true">
        <cfargument name="legIndex" type="numeric" required="true">
        <cfscript>
            return {
                "date"=dateFormat(arguments.dateValue, "yyyy-mm-dd"),
                "leg_index"=int(val(arguments.legIndex)),
                "start_name"="",
                "end_name"="",
                "total_dist_nm"=0,
                "est_hours"=0,
                "cruise_fuel_gallons"=0,
                "reserve_gallons"=0,
                "required_fuel_gallons"=0,
                "fuel_confidence_score"=0,
                "risk_color"="GREEN",
                "lock_count"=0,
                "segment_ids"=[],
                "segment_slices"=[],
                "exposure_max_level"=0,
                "effective_weather_pct_max"=0,
                "exposure_override_count"=0,
                "offshore_segment_count"=0
            };
        </cfscript>
    </cffunction>

<cffunction name="routegenTimelineDayHasContent" access="private" returntype="boolean" output="false">
        <cfargument name="day" type="any" required="true">
        <cfscript>
            var src = (isStruct(arguments.day) ? arguments.day : {});
            return (
                val(structKeyExists(src, "total_dist_nm") ? src.total_dist_nm : 0) GT 0
                OR val(structKeyExists(src, "est_hours") ? src.est_hours : 0) GT 0
                OR val(structKeyExists(src, "lock_count") ? src.lock_count : 0) GT 0
                OR (structKeyExists(src, "segment_ids") AND isArray(src.segment_ids) AND arrayLen(src.segment_ids) GT 0)
                OR (structKeyExists(src, "segment_slices") AND isArray(src.segment_slices) AND arrayLen(src.segment_slices) GT 0)
            );
        </cfscript>
    </cffunction>

<cffunction name="routegenFinalizeCruiseTimelineDay" access="private" returntype="struct" output="false">
        <cfargument name="day" type="any" required="true">
        <cfargument name="maxSpeedVal" type="numeric" required="true">
        <cfargument name="maxBurnForEstimateVal" type="numeric" required="true">
        <cfargument name="fuelBurnGphVal" type="numeric" required="true">
        <cfargument name="mostEfficientSpeedVal" type="numeric" required="false" default="0">
        <cfargument name="mostEfficientBurnGphVal" type="numeric" required="false" default="0">
        <cfargument name="paceVal" type="string" required="true">
        <cfargument name="paceRatioVal" type="numeric" required="true">
        <cfargument name="weatherFactorPctVal" type="numeric" required="true">
        <cfargument name="reservePctVal" type="numeric" required="true">
        <cfargument name="allowAnchoredBurnVal" type="any" required="false" default="false">
        <cfscript>
            var outDay = (isStruct(arguments.day) ? duplicate(arguments.day) : {});
            var fuelEstimate = {};
            var requiredFuelGallonsVal = 0;
            var reserveGallonsVal = 0;
            var reserveRatio = 0;
            var reserveMarginPct = 0;
            var fuelConfidenceScore = 100;
            var i = 0;
            var slice = {};

            if (!routegenTimelineDayHasContent(outDay)) {
                return outDay;
            }

            fuelEstimate = calculateFuelEstimate({
                "distanceNm"=val(structKeyExists(outDay, "total_dist_nm") ? outDay.total_dist_nm : 0),
                "maxSpeedKnots"=arguments.maxSpeedVal,
                "maxBurnGph"=(arguments.maxBurnForEstimateVal GT 0 ? arguments.maxBurnForEstimateVal : arguments.fuelBurnGphVal),
                "efficientSpeedKnots"=arguments.mostEfficientSpeedVal,
                "efficientBurnGph"=arguments.mostEfficientBurnGphVal,
                "pace"=arguments.paceVal,
                "paceRatio"=arguments.paceRatioVal,
                "weatherPct"=arguments.weatherFactorPctVal,
                "idleFuelGallons"=0,
                "reservePct"=arguments.reservePctVal,
                "allowAnchoredBurn"=arguments.allowAnchoredBurnVal
            });
            outDay.cruise_fuel_gallons = roundTo2(val(fuelEstimate.cruiseFuelGallons));
            outDay.reserve_gallons = roundTo2(val(fuelEstimate.reserveGallons));
            outDay.required_fuel_gallons = roundTo2(val(fuelEstimate.requiredFuelGallons));
            requiredFuelGallonsVal = val(outDay.required_fuel_gallons);
            reserveGallonsVal = val(outDay.reserve_gallons);
            reserveRatio = (requiredFuelGallonsVal GT 0 ? (reserveGallonsVal / requiredFuelGallonsVal) : 0);
            reserveMarginPct = (
                val(fuelEstimate.baseFuelGallons) GT 0
                    ? ((reserveGallonsVal / val(fuelEstimate.baseFuelGallons)) * 100)
                    : val(arguments.reservePctVal)
            );

            fuelConfidenceScore = 100;
            if (requiredFuelGallonsVal GT 0 AND reserveRatio LT 0.20) fuelConfidenceScore -= 25;
            if (requiredFuelGallonsVal GT 0 AND reserveRatio LT 0.15) fuelConfidenceScore -= 40;
            if (val(structKeyExists(outDay, "est_hours") ? outDay.est_hours : 0) GT 8) fuelConfidenceScore -= 10;
            if (fuelConfidenceScore LT 0) fuelConfidenceScore = 0;
            if (fuelConfidenceScore GT 100) fuelConfidenceScore = 100;
            outDay.fuel_confidence_score = fuelConfidenceScore;
            if (reserveMarginPct GTE 33) {
                outDay.risk_color = "GREEN";
            } else if (reserveMarginPct GTE 20) {
                outDay.risk_color = "YELLOW";
            } else {
                outDay.risk_color = "RED";
            }
            if (val(structKeyExists(outDay, "est_hours") ? outDay.est_hours : 0) GT 8) {
                if (outDay.risk_color EQ "GREEN") {
                    outDay.risk_color = "YELLOW";
                } else if (outDay.risk_color EQ "YELLOW") {
                    outDay.risk_color = "RED";
                }
            }

            outDay.total_dist_nm = roundTo2(val(structKeyExists(outDay, "total_dist_nm") ? outDay.total_dist_nm : 0));
            outDay.est_hours = roundTo2(val(structKeyExists(outDay, "est_hours") ? outDay.est_hours : 0));
            outDay.effective_weather_pct_max = roundTo2(val(structKeyExists(outDay, "effective_weather_pct_max") ? outDay.effective_weather_pct_max : 0));
            outDay.lock_count = int(val(structKeyExists(outDay, "lock_count") ? outDay.lock_count : 0));

            if (structKeyExists(outDay, "segment_slices") AND isArray(outDay.segment_slices)) {
                for (i = 1; i LTE arrayLen(outDay.segment_slices); i++) {
                    if (!isStruct(outDay.segment_slices[i])) continue;
                    slice = duplicate(outDay.segment_slices[i]);
                    slice.slice_dist_nm = roundTo2(val(structKeyExists(slice, "slice_dist_nm") ? slice.slice_dist_nm : 0));
                    slice.slice_hours = roundTo2(val(structKeyExists(slice, "slice_hours") ? slice.slice_hours : 0));
                    slice.segment_dist_nm = roundTo2(val(structKeyExists(slice, "segment_dist_nm") ? slice.segment_dist_nm : 0));
                    slice.segment_hours = roundTo2(val(structKeyExists(slice, "segment_hours") ? slice.segment_hours : 0));
                    slice.lock_count = int(val(structKeyExists(slice, "lock_count") ? slice.lock_count : 0));
                    slice.order_index = int(val(structKeyExists(slice, "order_index") ? slice.order_index : 0));
                    slice.route_leg_id = int(val(structKeyExists(slice, "route_leg_id") ? slice.route_leg_id : 0));
                    slice.segment_id = int(val(structKeyExists(slice, "segment_id") ? slice.segment_id : 0));
                    slice.source_id = int(val(structKeyExists(slice, "source_id") ? slice.source_id : 0));
                    slice.is_split = !!(structKeyExists(slice, "is_split") AND slice.is_split);
                    outDay.segment_slices[i] = slice;
                }
            }

            return outDay;
        </cfscript>
    </cffunction>

<cffunction name="generateCruiseTimeline" access="public" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeId" type="numeric" required="true">
        <cfargument name="startDate" type="string" required="true">
        <cfargument name="maxHoursPerDay" type="numeric" required="false" default="6.5">
        <cfargument name="routeType" type="string" required="false" default="generated">
        <cfargument name="inputOverrides" type="struct" required="false" default="#structNew()#">
        <cfargument name="previewLegs" type="any" required="false" default="#[]#">
        <cfscript>
            var out = {
                "success"=false,
                "route_summary"={
                    "total_days"=0,
                    "total_nm"=0,
                    "total_required_fuel"=0
                },
                "timeline_meta"={
                    "fuel_burn_gph"=0,
                    "fuel_source"="missing",
                    "fuel_key"="",
                    "fuel_resolved"=false,
                    "distance_source"="route_instance_legs",
                    "preview_legs_ignored"=false,
                    "hours_source"="weather_adjusted_speed",
                    "exposure_enabled"=true,
                    "exposure_max_level"=0,
                    "exposure_sources"={
                        "override"=0,
                        "auto_offshore"=0,
                        "auto_inshore"=0
                    },
                    "exposure_coefficient_max"=0,
                    "effective_weather_pct_max"=0
                },
                "days"=[]
            };
            var userIdVal = val(arguments.userId);
            var routeIdVal = val(arguments.routeId);
            var startDateVal = trim(toString(arguments.startDate));
            var routeTypeVal = lCase(trim(toString(arguments.routeType)));
            var isMyRouteType = false;
            var maxHoursVal = val(arguments.maxHoursPerDay);
            var currentDate = now();
            var hasInputsJsonCol = false;
            var qInstSql = "";
            var qInst = queryNew("");
            var routeInstanceIdVal = 0;
            var myRouteRow = {};
            var storedInputs = {};
            var effectiveInputs = {};
            var paceVal = "RELAXED";
            var paceDefaults = {};
            var paceRatioVal = 0;
            var maxSpeedVal = 0;
            var effectiveSpeedVal = 0;
            var fuelMeta = {
                "fuel_burn_gph"=0,
                "fuel_source"="missing",
                "fuel_key"="",
                "fuel_resolved"=false
            };
            var fuelBurnGphVal = 0;
            var maxBurnForEstimateVal = 0;
            var weatherFactorPctVal = 0;
            var reservePctVal = 33;
            var timelineFuelEstimateMeta = {};
            var performanceMeta = {};
            var allowAnchoredBurnVal = false;
            var normalizedLegJoinSql = "";
            var normalizedSegJoinSql = "";
            var normalizedUsoJoinSql = "";
            var normalizedLockJoinSql = "";
            var normalizedDistExpr = "ril.base_dist_nm";
            var normalizedLockExpr = "COALESCE(ril.lock_count, 0)";
            var normalizedLockTimeExpr = "0";
            var hasLockDelayModel = routegenHasLockDelayModelTable();
            var hasExposureLevelCol = false;
            var normalizedExposureExpr = "NULL";
            var hasWaypointCols = false;
            var myRouteWaypointJoinSql = "";
            var myRouteStartNameExpr = "COALESCE(NULLIF(TRIM(p1.name), ''), TRIM(sl.start_port_name), '')";
            var myRouteEndNameExpr = "COALESCE(NULLIF(TRIM(p2.name), ''), TRIM(sl.end_port_name), '')";
            var myRouteStartLatExpr = "p1.lat";
            var myRouteStartLngExpr = "p1.lng";
            var myRouteEndLatExpr = "p2.lat";
            var myRouteEndLngExpr = "p2.lng";
            var qSegmentsSql = "";
            var qSegments = queryNew("");
            var previewLegsProvided = (isArray(arguments.previewLegs) AND arrayLen(arguments.previewLegs) GT 0);
            var normalizedPreviewLegs = [];
            var usePreviewLegs = false;
            var previewLegsIgnored = false;
            var previewLeg = {};
            var segSource = "route_instance_legs";
            var i = 0;
            var segIdVal = 0;
            var segRouteLegIdVal = 0;
            var segSegmentIdVal = 0;
            var segOrderIndexVal = 0;
            var segStartName = "";
            var segEndName = "";
            var segDistNm = 0;
            var segLockCount = 0;
            var segLockTimeMin = 0.0;
            var segIsOffshoreVal = 0;
            var segExposureOverrideVal = "";
            var segBaseDistNm = 0;
            var segStartLatRaw = "";
            var segStartLngRaw = "";
            var segEndLatRaw = "";
            var segEndLngRaw = "";
            var computedMyRouteDefaultNm = 0;
            var exposureInfo = {};
            var exposureSourceVal = "";
            var exposureCoeffVal = 1;
            var effectiveWeatherPctSegVal = 0;
            var weatherAdjustedSpeedThisSegVal = 0;
            var segHours = 0;
            var exposureSourceCounts = {
                "override"=0,
                "auto_offshore"=0,
                "auto_inshore"=0
            };
            var exposureMaxLevelVal = 0;
            var exposureCoeffMaxVal = 0;
            var effectiveWeatherPctMaxVal = 0;
            var legIndex = 1;
            var days = [];
            var totalCruiseNm = 0;
            var totalRequiredFuel = 0;
            var currentDay = {};
            var finalizedDay = {};
            var remainingSegHours = 0;
            var remainingSegDistNm = 0;
            var remainingDayCapacity = 0;
            var sliceHoursVal = 0;
            var sliceDistNm = 0;
            var sliceLockCount = 0;
            var segmentLockAssigned = false;
            var sliceMeta = {};
            var sliceEpsilon = 0.0001;
            var timelineMathService = createTripTimelineMathService();
            var windowAllocation = {};
            if (userIdVal LTE 0) {
                out.message = "Unauthorized";
                out.error = { "message"="No logged-in user session." };
                return out;
            }

            if (routeIdVal LTE 0) {
                out.message = "routeId required";
                out.error = { "message"="routeId must be a positive numeric value." };
                return out;
            }
            if (!len(routeTypeVal)) {
                routeTypeVal = "generated";
            }
            isMyRouteType = (routeTypeVal EQ "my_route" OR routeTypeVal EQ "my_routes" OR routeTypeVal EQ "custom");
            if (!len(startDateVal) OR !reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", startDateVal)) {
                out.message = "Invalid startDate";
                out.error = { "message"="startDate must be yyyy-mm-dd." };
                return out;
            }
            try {
                currentDate = parseDateTime(startDateVal);
            } catch (any eDate) {
                out.message = "Invalid startDate";
                out.error = { "message"="Unable to parse startDate." };
                return out;
            }
            hasInputsJsonCol = routegenHasInputsJsonColumn();
            if (isMyRouteType) {
                if (!routegenHasUserRouteTables()) {
                    out.message = "Route timeline unavailable";
                    out.error = { "message"="user_routes and user_route_legs migrations are not applied." };
                    return out;
                }
                myRouteRow = resolveMyRouteById(userIdVal, routeIdVal);
                if (!structCount(myRouteRow) OR val(myRouteRow.IS_ACTIVE) NEQ 1) {
                    out.message = "Route not found";
                    out.error = { "message"="My Route not found or not owned by user." };
                    return out;
                }
                segSource = "user_route_legs";
            } else {
                qInstSql = "SELECT id, template_route_code";
                if (hasInputsJsonCol) {
                    qInstSql &= ", routegen_inputs_json";
                }
                qInstSql &= "
                    FROM route_instances
                    WHERE generated_route_id = :routeId
                      AND user_id = :uid
                    ORDER BY id DESC
                    LIMIT 1";
                qInst = queryExecute(
                    qInstSql,
                    {
                        routeId = { value=routeIdVal, cfsqltype="cf_sql_integer" },
                        uid = { value=toString(userIdVal), cfsqltype="cf_sql_varchar" }
                    },
                    { datasource = variables.datasource }
                );
                if (qInst.recordCount EQ 0) {
                    out.message = "Route not found";
                    out.error = { "message"="Route not found or not owned by user." };
                    return out;
                }
                routeInstanceIdVal = val(qInst.id[1]);
            }

            normalizedPreviewLegs = routegenNormalizeTimelinePreviewLegs(arguments.previewLegs);
            usePreviewLegs = (arrayLen(normalizedPreviewLegs) GT 0);
            previewLegsIgnored = (previewLegsProvided AND !usePreviewLegs);
            if (usePreviewLegs) {
                segSource = "preview_legs";
            }
            if (!usePreviewLegs AND !isMyRouteType AND !routegenHasNormalizedLegRows(routeInstanceIdVal)) {
                out.message = "Route timeline unavailable";
                out.error = { "message"="Route instance has no normalized leg rows." };
                return out;
            }
            hasExposureLevelCol = routegenHasSegmentExposureLevelColumn();
            normalizedExposureExpr = (hasExposureLevelCol ? "sl.exposure_level" : "NULL");

            if (!isMyRouteType AND hasInputsJsonCol AND !isNull(qInst.routegen_inputs_json[1])) {
                storedInputs = routegenParseStoredInputs(qInst.routegen_inputs_json[1]);
            }
            effectiveInputs = routegenBuildTimelineInputs(storedInputs, arguments.inputOverrides);
            if (structKeyExists(effectiveInputs, "underway_hours_per_day")) {
                maxHoursVal = routegenNormalizeUnderwayHours(effectiveInputs.underway_hours_per_day);
            } else {
                maxHoursVal = routegenNormalizeUnderwayHours(arguments.maxHoursPerDay);
            }
            performanceMeta = routegenResolvePerformanceModel(
                effectiveInputs,
                (structKeyExists(effectiveInputs, "pace") ? effectiveInputs.pace : "RELAXED")
            );
            allowAnchoredBurnVal = routegenCanUseAnchoredBurn(performanceMeta);
            fuelMeta = resolveTimelineFuelBurnFromInputs(effectiveInputs);
            fuelBurnGphVal = routegenNormalizeFuelBurnGph(performanceMeta.fuel_burn_gph);
            maxBurnForEstimateVal = routegenNormalizeFuelBurnGph(performanceMeta.max_burn_for_estimate);
            out.timeline_meta = {
                "fuel_burn_gph"=roundTo2(fuelBurnGphVal),
                "weather_adjusted_fuel_burn_gph"=0,
                "fuel_source"=trim(toString(performanceMeta.fuel_source)),
                "fuel_key"=trim(toString(performanceMeta.fuel_key)),
                "fuel_resolved"=(fuelBurnGphVal GT 0),
                "route_type"=(isMyRouteType ? "my_route" : "generated"),
                "distance_source"=segSource,
                "preview_legs_ignored"=previewLegsIgnored,
                "hours_source"="weather_adjusted_speed",
                "effective_speed_kn"=roundTo2(performanceMeta.effective_speed_kn),
                "speed_source"=trim(toString(performanceMeta.speed_source)),
                "most_efficient_speed_kn"=roundTo2(performanceMeta.most_efficient_speed_kn),
                "most_efficient_burn_gph"=roundTo2(performanceMeta.most_efficient_burn_gph),
                "pace_ratio"=roundTo2(performanceMeta.pace_ratio),
                "burn_model"=trim(toString(performanceMeta.burn_model)),
                "exposure_enabled"=true,
                "exposure_max_level"=0,
                "exposure_sources"={
                    "override"=0,
                    "auto_offshore"=0,
                    "auto_inshore"=0
                },
                "exposure_coefficient_max"=0,
                "effective_weather_pct_max"=0
            };
            paceVal = routegenNormalizePace(structKeyExists(effectiveInputs, "pace") ? effectiveInputs.pace : "RELAXED");
            paceDefaults = routegenPaceDefaults(paceVal);
            paceRatioVal = val(performanceMeta.pace_ratio);
            if (paceRatioVal LTE 0) {
                paceRatioVal = val(paceDefaults.PACE_FACTOR);
            }
            if (paceVal NEQ "BALANCED") {
                if (paceRatioVal LT 0.05) paceRatioVal = 0.05;
                if (paceRatioVal GT 1) paceRatioVal = 1;
            }
            maxSpeedVal = routegenNormalizeCruisingSpeed(performanceMeta.max_speed_kn, paceDefaults.MAX_SPEED_KN);
            effectiveSpeedVal = routegenComputeEffectiveCruisingSpeed(
                maxSpeedVal,
                paceVal,
                performanceMeta.most_efficient_speed_kn
            );
            if (effectiveSpeedVal LTE 0) effectiveSpeedVal = 1;
            weatherFactorPctVal = routegenNormalizeWeatherFactorPct(
                structKeyExists(effectiveInputs, "weather_factor_pct")
                    ? effectiveInputs.weather_factor_pct
                    : (structKeyExists(effectiveInputs, "weather_factor") ? effectiveInputs.weather_factor : "")
            );
            reservePctVal = routegenNormalizeReservePct(
                structKeyExists(effectiveInputs, "reserve_pct") ? effectiveInputs.reserve_pct : "",
                33
            );
            timelineFuelEstimateMeta = calculateFuelEstimate({
                "distanceNm"=1,
                "maxSpeedKnots"=maxSpeedVal,
                "maxBurnGph"=(maxBurnForEstimateVal GT 0 ? maxBurnForEstimateVal : fuelBurnGphVal),
                "efficientSpeedKnots"=performanceMeta.most_efficient_speed_kn,
                "efficientBurnGph"=performanceMeta.most_efficient_burn_gph,
                "pace"=paceVal,
                "paceRatio"=paceRatioVal,
                "weatherPct"=weatherFactorPctVal,
                "idleFuelGallons"=0,
                "reservePct"=reservePctVal,
                "allowAnchoredBurn"=allowAnchoredBurnVal
            });
            out.timeline_meta.weather_adjusted_fuel_burn_gph = roundTo2(
                structKeyExists(timelineFuelEstimateMeta, "weatherAdjustedBurnGph")
                    ? timelineFuelEstimateMeta.weatherAdjustedBurnGph
                    : 0
            );

            if (usePreviewLegs) {
                qSegments = queryNew("id,route_leg_id,order_index,start_name,end_name,dist_nm,lock_count,lock_time_min_total,is_offshore,is_icw,exposure_level,segment_id,segment_dist_nm,start_lat,start_lng,end_lat,end_lng");
                for (i = 1; i LTE arrayLen(normalizedPreviewLegs); i++) {
                    previewLeg = normalizedPreviewLegs[i];
                    queryAddRow(qSegments, 1);
                    querySetCell(qSegments, "id", val(previewLeg.id));
                    querySetCell(qSegments, "route_leg_id", val(previewLeg.route_leg_id));
                    querySetCell(qSegments, "order_index", val(previewLeg.order_index));
                    querySetCell(qSegments, "start_name", trim(toString(previewLeg.start_name)));
                    querySetCell(qSegments, "end_name", trim(toString(previewLeg.end_name)));
                    querySetCell(qSegments, "dist_nm", val(previewLeg.dist_nm));
                    querySetCell(qSegments, "lock_count", val(previewLeg.lock_count));
                    querySetCell(qSegments, "lock_time_min_total", val(previewLeg.lock_time_min_total));
                    querySetCell(qSegments, "is_offshore", val(previewLeg.is_offshore));
                    querySetCell(qSegments, "is_icw", val(previewLeg.is_icw));
                    querySetCell(
                        qSegments,
                        "exposure_level",
                        (isNumeric(previewLeg.exposure_level) ? int(val(previewLeg.exposure_level)) : "")
                    );
                    querySetCell(qSegments, "segment_id", val(previewLeg.segment_id));
                    querySetCell(qSegments, "segment_dist_nm", val(previewLeg.dist_nm));
                    querySetCell(qSegments, "start_lat", "");
                    querySetCell(qSegments, "start_lng", "");
                    querySetCell(qSegments, "end_lat", "");
                    querySetCell(qSegments, "end_lng", "");
                }
            } else if (isMyRouteType) {
                normalizedLegJoinSql = "";
                normalizedDistExpr = "COALESCE(sl.dist_nm, 0)";
                hasWaypointCols = routegenHasUserRouteWaypointColumns();
                myRouteWaypointJoinSql = "";
                myRouteStartNameExpr = "COALESCE(NULLIF(TRIM(p1.name), ''), TRIM(sl.start_port_name), '')";
                myRouteEndNameExpr = "COALESCE(NULLIF(TRIM(p2.name), ''), TRIM(sl.end_port_name), '')";
                myRouteStartLatExpr = "p1.lat";
                myRouteStartLngExpr = "p1.lng";
                myRouteEndLatExpr = "p2.lat";
                myRouteEndLngExpr = "p2.lng";
                if (hasWaypointCols) {
                    myRouteWaypointJoinSql =
                        " LEFT JOIN waypoints wps ON wps.wpId = url.start_waypoint_id AND wps.userId = ur.user_id
                          LEFT JOIN waypoints wpe ON wpe.wpId = url.end_waypoint_id AND wpe.userId = ur.user_id";
                    myRouteStartNameExpr = "COALESCE(NULLIF(TRIM(wps.name), ''), " & myRouteStartNameExpr & ")";
                    myRouteEndNameExpr = "COALESCE(NULLIF(TRIM(wpe.name), ''), " & myRouteEndNameExpr & ")";
                    myRouteStartLatExpr = "COALESCE(wps.latitude, " & myRouteStartLatExpr & ")";
                    myRouteStartLngExpr = "COALESCE(wps.longitude, " & myRouteStartLngExpr & ")";
                    myRouteEndLatExpr = "COALESCE(wpe.latitude, " & myRouteEndLatExpr & ")";
                    myRouteEndLngExpr = "COALESCE(wpe.longitude, " & myRouteEndLngExpr & ")";
                }
                if (routegenHasLegOverrideTable()) {
                    normalizedLegJoinSql =
                        " LEFT JOIN route_leg_user_overrides rluo_leg
                            ON rluo_leg.user_id = :uidNum
                           AND rluo_leg.route_id = :routeId
                           AND rluo_leg.route_leg_id = url.id";
                    normalizedDistExpr = "COALESCE(rluo_leg.computed_nm, sl.dist_nm, 0)";
                }

                qSegmentsSql =
                    "SELECT
                        url.id AS id,
                        url.id AS route_leg_id,
                        url.order_index AS order_index,
                        " & myRouteStartNameExpr & " AS start_name,
                        " & myRouteEndNameExpr & " AS end_name,
                        " & normalizedDistExpr & " AS dist_nm,
                        COALESCE(sl.dist_nm, 0) AS segment_dist_nm,
                        COALESCE(sl.lock_count, 0) AS lock_count,
                        COALESCE(sl.is_offshore, 0) AS is_offshore,
                        COALESCE(sl.is_icw, 0) AS is_icw,
                        " & normalizedExposureExpr & " AS exposure_level,
                        " & myRouteStartLatExpr & " AS start_lat,
                        " & myRouteStartLngExpr & " AS start_lng,
                        " & myRouteEndLatExpr & " AS end_lat,
                        " & myRouteEndLngExpr & " AS end_lng,
                        url.segment_id
                     FROM user_route_legs url
                     INNER JOIN user_routes ur ON ur.id = url.user_route_id
                     LEFT JOIN segment_library sl ON sl.id = url.segment_id
                     LEFT JOIN ports p1 ON p1.id = sl.start_port_id
                     LEFT JOIN ports p2 ON p2.id = sl.end_port_id"
                    & myRouteWaypointJoinSql
                    & normalizedLegJoinSql
                    & "
                     WHERE ur.id = :routeId
                       AND ur.user_id = :uidNum
                       AND ur.is_active = 1
                     ORDER BY url.order_index ASC, url.id ASC";
                qSegments = queryExecute(
                    qSegmentsSql,
                    {
                        routeId = { value=routeIdVal, cfsqltype="cf_sql_integer" },
                    uidNum = { value=userIdVal, cfsqltype="cf_sql_integer" }
                    },
                    { datasource = variables.datasource }
                );
            } else {
                if (routegenHasLegOverrideTable()) {
                    normalizedLegJoinSql =
                        " LEFT JOIN route_leg_user_overrides rluo_leg
                            ON rluo_leg.user_id = :uidNum
                           AND rluo_leg.route_id = :routeId
                           AND (
                                (ril.source_loop_segment_id IS NOT NULL AND rluo_leg.route_leg_id = ril.source_loop_segment_id)
                                OR
                                (ril.source_loop_segment_id IS NULL AND rluo_leg.route_leg_order = ril.leg_order)
                           )";
                    normalizedSegJoinSql =
                        " LEFT JOIN route_leg_user_overrides rluo_seg
                            ON rluo_seg.user_id = :uidNum
                           AND rluo_seg.route_id = 0
                           AND rluo_seg.segment_id = ril.segment_id";
                    normalizedDistExpr = "COALESCE(rluo_leg.computed_nm, rluo_seg.computed_nm, ril.base_dist_nm)";
                }
                if (routegenHasUserSegmentOverrideTable()) {
                    normalizedUsoJoinSql =
                        " LEFT JOIN user_segment_overrides uso
                            ON uso.user_id = :uidNum
                           AND uso.segment_id = ril.segment_id";
                    if (routegenHasLegOverrideTable()) {
                        normalizedDistExpr = "COALESCE(rluo_leg.computed_nm, uso.computed_nm, rluo_seg.computed_nm, ril.base_dist_nm)";
                    } else {
                        normalizedDistExpr = "COALESCE(uso.computed_nm, ril.base_dist_nm)";
                    }
                }
                if (routegenHasRouteLegLocksTable()) {
                    if (hasLockDelayModel) {
                        normalizedLockTimeExpr = "COALESCE(rll.lock_time_min_total, 0)";
                        normalizedLockJoinSql =
                            " LEFT JOIN (
                                SELECT
                                    rll.route_code,
                                    rll.leg,
                                    COUNT(*) AS lock_count,
                                    COALESCE(SUM(COALESCE(ldm.base_cycle_min, 0) + COALESCE(ldm.typical_wait_min, 0)), 0) AS lock_time_min_total
                                FROM route_leg_locks rll
                                LEFT JOIN lock_delay_model ldm ON ldm.lock_code = rll.lock_code
                                GROUP BY rll.route_code, rll.leg
                              ) rll
                                ON rll.route_code COLLATE utf8mb4_unicode_ci = ri.template_route_code
                               AND rll.leg = ril.leg_order";
                    } else {
                        normalizedLockJoinSql =
                            " LEFT JOIN (
                                SELECT route_code, leg, COUNT(*) AS lock_count
                                FROM route_leg_locks
                                GROUP BY route_code, leg
                              ) rll
                                ON rll.route_code COLLATE utf8mb4_unicode_ci = ri.template_route_code
                               AND rll.leg = ril.leg_order";
                    }
                    normalizedLockExpr = "COALESCE(rll.lock_count, ril.lock_count, 0)";
                }

                qSegmentsSql =
                    "SELECT
                        COALESCE(ril.source_loop_segment_id, ril.id) AS id,
                        COALESCE(ril.source_loop_segment_id, ril.id) AS route_leg_id,
                        ril.leg_order AS order_index,
                        ril.start_name,
                        ril.end_name,
                        " & normalizedDistExpr & " AS dist_nm,
                        " & normalizedLockExpr & " AS lock_count,
                        " & normalizedLockTimeExpr & " AS lock_time_min_total,
                        COALESCE(sl.is_offshore, 0) AS is_offshore,
                        COALESCE(sl.is_icw, 0) AS is_icw,
                        " & normalizedExposureExpr & " AS exposure_level,
                        ril.segment_id
                     FROM route_instance_legs ril
                     INNER JOIN route_instances ri ON ri.id = ril.route_instance_id
                     LEFT JOIN segment_library sl ON sl.id = ril.segment_id"
                    & normalizedLegJoinSql
                    & normalizedSegJoinSql
                    & normalizedUsoJoinSql
                    & normalizedLockJoinSql
                    & "
                     WHERE ril.route_instance_id = :routeInstanceId
                     ORDER BY ril.leg_order ASC, ril.id ASC";
                qSegments = queryExecute(
                    qSegmentsSql,
                    {
                        routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" },
                        routeId = { value=routeIdVal, cfsqltype="cf_sql_integer" },
                    uidNum = { value=userIdVal, cfsqltype="cf_sql_integer" }
                    },
                    { datasource = variables.datasource }
                );
            }
            if (qSegments.recordCount EQ 0) {
                out.message = "Route has no segments";
                out.error = { "message"="No route segments are available for this route." };
                return out;
            }

            currentDay = routegenBuildCruiseTimelineDay(currentDate, legIndex);

            for (i = 1; i LTE qSegments.recordCount; i++) {
                segIdVal = (isNull(qSegments.id[i]) ? 0 : val(qSegments.id[i]));
                segRouteLegIdVal = (
                    structKeyExists(qSegments, "route_leg_id") AND !isNull(qSegments.route_leg_id[i])
                        ? val(qSegments.route_leg_id[i])
                        : segIdVal
                );
                segSegmentIdVal = (
                    structKeyExists(qSegments, "segment_id") AND !isNull(qSegments.segment_id[i])
                        ? val(qSegments.segment_id[i])
                        : 0
                );
                segOrderIndexVal = (
                    structKeyExists(qSegments, "order_index") AND !isNull(qSegments.order_index[i])
                        ? int(val(qSegments.order_index[i]))
                        : i
                );
                segStartName = (isNull(qSegments.start_name[i]) ? "" : trim(toString(qSegments.start_name[i])));
                segEndName = (isNull(qSegments.end_name[i]) ? "" : trim(toString(qSegments.end_name[i])));
                segDistNm = (isNull(qSegments.dist_nm[i]) ? 0 : val(qSegments.dist_nm[i]));
                segLockCount = (isNull(qSegments.lock_count[i]) ? 0 : val(qSegments.lock_count[i]));
                segLockTimeMin = (
                    structKeyExists(qSegments, "lock_time_min_total") AND !isNull(qSegments.lock_time_min_total[i])
                        ? val(qSegments.lock_time_min_total[i])
                        : 0
                );
                if (isMyRouteType) {
                    segBaseDistNm = (
                        structKeyExists(qSegments, "segment_dist_nm") AND !isNull(qSegments.segment_dist_nm[i])
                            ? val(qSegments.segment_dist_nm[i])
                            : 0
                    );
                    segStartLatRaw = (
                        structKeyExists(qSegments, "start_lat") AND !isNull(qSegments.start_lat[i])
                            ? qSegments.start_lat[i]
                            : ""
                    );
                    segStartLngRaw = (
                        structKeyExists(qSegments, "start_lng") AND !isNull(qSegments.start_lng[i])
                            ? qSegments.start_lng[i]
                            : ""
                    );
                    segEndLatRaw = (
                        structKeyExists(qSegments, "end_lat") AND !isNull(qSegments.end_lat[i])
                            ? qSegments.end_lat[i]
                            : ""
                    );
                    segEndLngRaw = (
                        structKeyExists(qSegments, "end_lng") AND !isNull(qSegments.end_lng[i])
                            ? qSegments.end_lng[i]
                            : ""
                    );
                    if (segDistNm LTE 0) {
                        computedMyRouteDefaultNm = routegenComputeLegDefaultDistanceNm(
                            segmentDistNm = segBaseDistNm,
                            startLat = segStartLatRaw,
                            startLng = segStartLngRaw,
                            endLat = segEndLatRaw,
                            endLng = segEndLngRaw
                        );
                        if (computedMyRouteDefaultNm GT 0) {
                            segDistNm = computedMyRouteDefaultNm;
                        }
                    }
                }
                segIsOffshoreVal = (
                    structKeyExists(qSegments, "is_offshore") AND !isNull(qSegments.is_offshore[i]) AND val(qSegments.is_offshore[i]) GT 0
                        ? 1
                        : 0
                );
                segExposureOverrideVal = (
                    structKeyExists(qSegments, "exposure_level") AND !isNull(qSegments.exposure_level[i])
                        ? qSegments.exposure_level[i]
                        : ""
                );

                if (segDistNm LT 0) segDistNm = 0;
                if (segLockCount LT 0) segLockCount = 0;
                if (segLockTimeMin LT 0) segLockTimeMin = 0;
                exposureInfo = routegenResolveExposureLevel(segIsOffshoreVal, segExposureOverrideVal);
                exposureSourceVal = trim(toString(structKeyExists(exposureInfo, "source") ? exposureInfo.source : "auto_inshore"));
                exposureCoeffVal = routegenExposureCoefficient(
                    structKeyExists(exposureInfo, "level_used") ? val(exposureInfo.level_used) : 0
                );
                effectiveWeatherPctSegVal = routegenComputeEffectiveWeatherPct(
                    weatherFactorPctVal,
                    structKeyExists(exposureInfo, "level_used") ? val(exposureInfo.level_used) : 0
                );
                weatherAdjustedSpeedThisSegVal = routegenComputeWeatherAdjustedSpeedKn(effectiveSpeedVal, effectiveWeatherPctSegVal);
                segHours = timelineMathService.calculateDurationSeconds(
                    distanceNm = segDistNm,
                    speedKn = weatherAdjustedSpeedThisSegVal,
                    lockMinutes = segLockTimeMin
                ) / 3600;
                if (segHours LT 0) segHours = 0;

                if (structKeyExists(exposureInfo, "level_used") AND val(exposureInfo.level_used) GT exposureMaxLevelVal) {
                    exposureMaxLevelVal = val(exposureInfo.level_used);
                }
                if (exposureCoeffVal GT exposureCoeffMaxVal) {
                    exposureCoeffMaxVal = exposureCoeffVal;
                }
                if (effectiveWeatherPctSegVal GT effectiveWeatherPctMaxVal) {
                    effectiveWeatherPctMaxVal = effectiveWeatherPctSegVal;
                }
                if (!structKeyExists(exposureSourceCounts, exposureSourceVal)) {
                    exposureSourceCounts[exposureSourceVal] = 0;
                }
                exposureSourceCounts[exposureSourceVal] = val(exposureSourceCounts[exposureSourceVal]) + 1;

                if (segHours LTE sliceEpsilon) {
                    if (!len(currentDay.start_name)) currentDay.start_name = segStartName;
                    currentDay.end_name = segEndName;
                    currentDay.lock_count += segLockCount;
                    if (structKeyExists(exposureInfo, "level_used") AND val(exposureInfo.level_used) GT val(currentDay.exposure_max_level)) {
                        currentDay.exposure_max_level = val(exposureInfo.level_used);
                    }
                    if (effectiveWeatherPctSegVal GT val(currentDay.effective_weather_pct_max)) {
                        currentDay.effective_weather_pct_max = effectiveWeatherPctSegVal;
                    }
                    if (exposureSourceVal EQ "override") {
                        currentDay.exposure_override_count += 1;
                    }
                    if (segIsOffshoreVal EQ 1) {
                        currentDay.offshore_segment_count += 1;
                    }
                    arrayAppend(currentDay.segment_ids, segIdVal);
                    arrayAppend(currentDay.segment_slices, {
                        "source_id"=segIdVal,
                        "route_leg_id"=segRouteLegIdVal,
                        "segment_id"=segSegmentIdVal,
                        "order_index"=segOrderIndexVal,
                        "start_name"=segStartName,
                        "end_name"=segEndName,
                        "slice_dist_nm"=0,
                        "slice_hours"=0,
                        "segment_dist_nm"=segDistNm,
                        "segment_hours"=segHours,
                        "lock_count"=segLockCount,
                        "is_split"=false
                    });
                    continue;
                }

                remainingSegHours = segHours;
                remainingSegDistNm = segDistNm;
                segmentLockAssigned = false;

                while (remainingSegHours GT sliceEpsilon) {
                    if ((maxHoursVal - val(currentDay.est_hours)) LTE sliceEpsilon AND routegenTimelineDayHasContent(currentDay)) {
                        finalizedDay = routegenFinalizeCruiseTimelineDay(
                            day = currentDay,
                            maxSpeedVal = maxSpeedVal,
                            maxBurnForEstimateVal = maxBurnForEstimateVal,
                            fuelBurnGphVal = fuelBurnGphVal,
                            mostEfficientSpeedVal = performanceMeta.most_efficient_speed_kn,
                            mostEfficientBurnGphVal = performanceMeta.most_efficient_burn_gph,
                            paceVal = paceVal,
                            paceRatioVal = paceRatioVal,
                            weatherFactorPctVal = weatherFactorPctVal,
                            reservePctVal = reservePctVal,
                            allowAnchoredBurnVal = allowAnchoredBurnVal
                        );
                        totalCruiseNm += val(finalizedDay.total_dist_nm);
                        totalRequiredFuel += val(finalizedDay.required_fuel_gallons);
                        arrayAppend(days, finalizedDay);

                        currentDate = timelineMathService.advanceLocalDate(currentDate);
                        legIndex += 1;
                        currentDay = routegenBuildCruiseTimelineDay(currentDate, legIndex);
                    }

                    windowAllocation = timelineMathService.getWindowAllocation(
                        remainingSeconds = remainingSegHours * 3600,
                        usedSeconds = val(currentDay.est_hours) * 3600,
                        maximumSeconds = maxHoursVal * 3600
                    );
                    remainingDayCapacity = windowAllocation.availableSeconds / 3600;
                    sliceHoursVal = windowAllocation.sliceSeconds / 3600;
                    if (sliceHoursVal LT sliceEpsilon) {
                        sliceHoursVal = remainingSegHours;
                    }

                    if ((remainingSegHours - sliceHoursVal) LTE sliceEpsilon) {
                        sliceDistNm = remainingSegDistNm;
                    } else {
                        sliceDistNm = (sliceHoursVal * weatherAdjustedSpeedThisSegVal);
                        if (sliceDistNm GT remainingSegDistNm) {
                            sliceDistNm = remainingSegDistNm;
                        }
                    }
                    if (sliceDistNm LT 0) {
                        sliceDistNm = 0;
                    }

                    if (!len(currentDay.start_name)) currentDay.start_name = segStartName;
                    currentDay.end_name = segEndName;
                    currentDay.total_dist_nm += sliceDistNm;
                    currentDay.est_hours += sliceHoursVal;
                    sliceLockCount = (segmentLockAssigned ? 0 : segLockCount);
                    segmentLockAssigned = true;
                    currentDay.lock_count += sliceLockCount;

                    if (structKeyExists(exposureInfo, "level_used") AND val(exposureInfo.level_used) GT val(currentDay.exposure_max_level)) {
                        currentDay.exposure_max_level = val(exposureInfo.level_used);
                    }
                    if (effectiveWeatherPctSegVal GT val(currentDay.effective_weather_pct_max)) {
                        currentDay.effective_weather_pct_max = effectiveWeatherPctSegVal;
                    }
                    if (exposureSourceVal EQ "override") {
                        currentDay.exposure_override_count += 1;
                    }
                    if (segIsOffshoreVal EQ 1) {
                        currentDay.offshore_segment_count += 1;
                    }

                    arrayAppend(currentDay.segment_ids, segIdVal);
                    sliceMeta = {
                        "source_id"=segIdVal,
                        "route_leg_id"=segRouteLegIdVal,
                        "segment_id"=segSegmentIdVal,
                        "order_index"=segOrderIndexVal,
                        "start_name"=segStartName,
                        "end_name"=segEndName,
                        "slice_dist_nm"=sliceDistNm,
                        "slice_hours"=sliceHoursVal,
                        "segment_dist_nm"=segDistNm,
                        "segment_hours"=segHours,
                        "lock_count"=sliceLockCount,
                        "is_split"=((segHours - sliceHoursVal) GT sliceEpsilon OR (segDistNm - sliceDistNm) GT sliceEpsilon)
                    };
                    arrayAppend(currentDay.segment_slices, sliceMeta);

                    remainingSegHours -= sliceHoursVal;
                    remainingSegDistNm -= sliceDistNm;
                    if (remainingSegHours LT sliceEpsilon) {
                        remainingSegHours = 0;
                    }
                    if (remainingSegDistNm LT sliceEpsilon) {
                        remainingSegDistNm = 0;
                    }
                }
            }

            if (routegenTimelineDayHasContent(currentDay)) {
                finalizedDay = routegenFinalizeCruiseTimelineDay(
                    day = currentDay,
                    maxSpeedVal = maxSpeedVal,
                    maxBurnForEstimateVal = maxBurnForEstimateVal,
                    fuelBurnGphVal = fuelBurnGphVal,
                    mostEfficientSpeedVal = performanceMeta.most_efficient_speed_kn,
                    mostEfficientBurnGphVal = performanceMeta.most_efficient_burn_gph,
                    paceVal = paceVal,
                    paceRatioVal = paceRatioVal,
                    weatherFactorPctVal = weatherFactorPctVal,
                    reservePctVal = reservePctVal,
                    allowAnchoredBurnVal = allowAnchoredBurnVal
                );
                totalCruiseNm += val(finalizedDay.total_dist_nm);
                totalRequiredFuel += val(finalizedDay.required_fuel_gallons);
                arrayAppend(days, finalizedDay);
            }

            out.timeline_meta.exposure_enabled = true;
            out.timeline_meta.exposure_max_level = exposureMaxLevelVal;
            out.timeline_meta.exposure_sources = exposureSourceCounts;
            out.timeline_meta.exposure_coefficient_max = roundTo2(exposureCoeffMaxVal);
            out.timeline_meta.effective_weather_pct_max = roundTo2(effectiveWeatherPctMaxVal);

            out.success = true;
            out.route_summary = {
                "total_days"=arrayLen(days),
                "total_nm"=roundTo2(totalCruiseNm),
                "total_required_fuel"=roundTo2(totalRequiredFuel)
            };
            out.days = days;
            return out;
        </cfscript>
    </cffunction>

<cffunction name="routegenNormalizePace" access="private" returntype="string" output="false">
        <cfargument name="pace" type="any" required="false" default="RELAXED">
        <cfscript>
            var paceVal = uCase(trim(toString(arguments.pace)));
            if (paceVal EQ "BALANCED") return "BALANCED";
            if (paceVal EQ "AGGRESSIVE") return "AGGRESSIVE";
            return "RELAXED";
        </cfscript>
    </cffunction>

<cffunction name="routegenPaceDefaults" access="private" returntype="struct" output="false">
        <cfargument name="pace" type="any" required="false" default="RELAXED">
        <cfscript>
            var paceVal = routegenNormalizePace(arguments.pace);
            if (paceVal EQ "BALANCED") {
                return { "MAX_SPEED_KN"=20.0, "PACE_FACTOR"=0.50 };
            }
            if (paceVal EQ "AGGRESSIVE") {
                return { "MAX_SPEED_KN"=20.0, "PACE_FACTOR"=1.00 };
            }
            return { "MAX_SPEED_KN"=20.0, "PACE_FACTOR"=0.25 };
        </cfscript>
    </cffunction>

<cffunction name="routegenNormalizeCruisingSpeed" access="private" returntype="numeric" output="false">
        <cfargument name="speedKn" type="any" required="false" default="">
        <cfargument name="defaultSpeedKn" type="numeric" required="false" default="20">
        <cfscript>
            var speedVal = val(arguments.speedKn);
            var fallbackVal = val(arguments.defaultSpeedKn);
            if (fallbackVal LTE 0) fallbackVal = 20;
            if (speedVal LTE 0) speedVal = fallbackVal;
            if (speedVal LT 1) speedVal = 1;
            if (speedVal GT 60) speedVal = 60;
            return roundTo2(speedVal);
        </cfscript>
    </cffunction>

<cffunction name="routegenComputeEffectiveCruisingSpeed" access="private" returntype="numeric" output="false">
        <cfargument name="maxSpeedKn" type="any" required="false" default="">
        <cfargument name="pace" type="any" required="false" default="RELAXED">
        <cfargument name="mostEfficientSpeedKn" type="any" required="false">
        <cfscript>
            var paceVal = routegenNormalizePace(arguments.pace);
            var paceDefaults = routegenPaceDefaults(arguments.pace);
            var maxSpeedVal = routegenNormalizeCruisingSpeed(arguments.maxSpeedKn, paceDefaults.MAX_SPEED_KN);
            var factorVal = val(paceDefaults.PACE_FACTOR);
            var effectiveSpeed = 0;
            var mostEffVal = 0;
            if (paceVal EQ "BALANCED" AND structKeyExists(arguments, "mostEfficientSpeedKn")) {
                mostEffVal = val(arguments.mostEfficientSpeedKn);
                if (mostEffVal GT 60) mostEffVal = 60;
                if (mostEffVal GTE 1) {
                    return roundTo2(mostEffVal);
                }
            }
            if (factorVal LTE 0) factorVal = 0.25;
            effectiveSpeed = maxSpeedVal * factorVal;
            if (effectiveSpeed LT 1) effectiveSpeed = 1;
            return roundTo2(effectiveSpeed);
        </cfscript>
    </cffunction>

<cffunction name="routegenResolveExposureLevel" access="private" returntype="struct" output="false">
        <cfargument name="isOffshoreVal" type="any" required="true">
        <cfargument name="exposureOverrideVal" type="any" required="true">
        <cfscript>
            var overrideVal = arguments.exposureOverrideVal;
            var levelVal = 0;
            var sourceVal = "auto_inshore";
            if (isNumeric(overrideVal)) {
                levelVal = int(val(overrideVal));
                if (levelVal GTE 0 AND levelVal LTE 3) {
                    return {
                        "level_used"=levelVal,
                        "source"="override"
                    };
                }
            }
            if (isNumeric(arguments.isOffshoreVal) AND val(arguments.isOffshoreVal) EQ 1) {
                levelVal = 3;
                sourceVal = "auto_offshore";
            } else {
                levelVal = 0;
                sourceVal = "auto_inshore";
            }
            return {
                "level_used"=levelVal,
                "source"=sourceVal
            };
        </cfscript>
    </cffunction>

<cffunction name="routegenExposureCoefficient" access="private" returntype="numeric" output="false">
        <cfargument name="level" type="numeric" required="true">
        <cfscript>
            var levelVal = int(val(arguments.level));
            if (levelVal EQ 0) return 0.60;
            if (levelVal EQ 1) return 0.85;
            if (levelVal EQ 2) return 1.00;
            if (levelVal EQ 3) return 1.25;
            return 1.00;
        </cfscript>
    </cffunction>

<cffunction name="routegenComputeEffectiveWeatherPct" access="private" returntype="numeric" output="false">
        <cfargument name="weatherPct" type="numeric" required="true">
        <cfargument name="exposureLevel" type="numeric" required="true">
        <cfscript>
            var weatherVal = val(arguments.weatherPct);
            var coeff = routegenExposureCoefficient(arguments.exposureLevel);
            var effectiveVal = 0;
            if (weatherVal LT 0) weatherVal = 0;
            effectiveVal = weatherVal * coeff;
            if (effectiveVal LT 0) effectiveVal = 0;
            if (effectiveVal GT 70) effectiveVal = 70;
            return roundTo2(effectiveVal);
        </cfscript>
    </cffunction>

<cffunction name="routegenComputeWeatherAdjustedSpeedKn" access="private" returntype="numeric" output="false">
        <cfargument name="effectiveSpeedKn" type="numeric" required="true">
        <cfargument name="weatherPct" type="numeric" required="true">
        <cfscript>
            var effectiveVal = val(arguments.effectiveSpeedKn);
            var weatherPctVal = val(arguments.weatherPct);
            var adjustedVal = 0;
            if (weatherPctVal LT 0) weatherPctVal = 0;
            if (weatherPctVal GT 70) weatherPctVal = 70;
            adjustedVal = roundTo2(effectiveVal * (1 - (weatherPctVal / 100)));
            if (adjustedVal LT 0.5) adjustedVal = 0.5;
            return adjustedVal;
        </cfscript>
    </cffunction>

<cffunction name="routegenNormalizeUnderwayHours" access="private" returntype="numeric" output="false">
        <cfargument name="hours" type="any" required="false" default="6.5">
        <cfscript>
            return createTripTimelineMathService().normalizeUnderwayHours(arguments.hours);
        </cfscript>
    </cffunction>

<cffunction name="routegenNormalizeFuelBurnGph" access="private" returntype="numeric" output="false">
        <cfargument name="fuelBurnGph" type="any" required="false" default="">
        <cfscript>
            var valueVal = val(arguments.fuelBurnGph);
            if (valueVal LTE 0) return 0;
            if (valueVal GT 1000) valueVal = 1000;
            return roundTo2(valueVal);
        </cfscript>
    </cffunction>

<cffunction name="routegenNormalizeWeatherFactorPct" access="private" returntype="numeric" output="false">
        <cfargument name="weatherFactorPct" type="any" required="false" default="">
        <cfscript>
            var rawVal = trim(toString(arguments.weatherFactorPct));
            var pctVal = 0;
            if (!len(rawVal)) return 0;
            pctVal = val(rawVal);
            if (pctVal LT 0) pctVal = 0;
            if (pctVal GT 60) pctVal = 60;
            return roundTo2(pctVal);
        </cfscript>
    </cffunction>

<cffunction name="routegenNormalizeReservePct" access="private" returntype="numeric" output="false">
        <cfargument name="reservePct" type="any" required="false" default="">
        <cfargument name="defaultPct" type="numeric" required="false" default="33">
        <cfscript>
            var rawVal = trim(toString(arguments.reservePct));
            var pctVal = 0;
            if (!len(rawVal)) {
                pctVal = val(arguments.defaultPct);
            } else {
                pctVal = val(rawVal);
            }
            if (pctVal LT 0) pctVal = 0;
            if (pctVal GT 100) pctVal = 100;
            return roundTo2(pctVal);
        </cfscript>
    </cffunction>

<cffunction name="paceAdjustedBurnGph" access="private" returntype="numeric" output="false">
        <cfargument name="maxBurnGph" type="any" required="false" default="0">
        <cfargument name="paceRatio" type="any" required="false" default="1">
        <cfargument name="burnExponent" type="any" required="false" default="3.0">
        <cfscript>
            var maxBurnVal = routegenNormalizeFuelBurnGph(arguments.maxBurnGph);
            var ratioVal = val(arguments.paceRatio);
            var expVal = val(arguments.burnExponent);
            if (maxBurnVal LTE 0) return 0;
            if (expVal LT 1) expVal = 1;
            if (expVal GT 6) expVal = 6;
            if (ratioVal LTE 0) ratioVal = 1;
            if (ratioVal LT 0.05) ratioVal = 0.05;
            if (ratioVal GT 1) ratioVal = 1;
            return roundTo2(maxBurnVal * (ratioVal ^ expVal));
        </cfscript>
    </cffunction>

<cffunction name="routegenAnchoredBurnInputsValid" access="private" returntype="boolean" output="false">
        <cfargument name="maxSpeedKn" type="any" required="false" default="0">
        <cfargument name="maxBurnGph" type="any" required="false" default="0">
        <cfargument name="efficientSpeedKn" type="any" required="false" default="0">
        <cfargument name="efficientBurnGph" type="any" required="false" default="0">
        <cfscript>
            var lowSpeedAnchorKn = 3.5;
            var maxSpeedVal = val(arguments.maxSpeedKn);
            var maxBurnVal = routegenNormalizeFuelBurnGph(arguments.maxBurnGph);
            var efficientSpeedVal = val(arguments.efficientSpeedKn);
            var efficientBurnVal = routegenNormalizeFuelBurnGph(arguments.efficientBurnGph);
            if (maxSpeedVal LTE 0) return false;
            if (maxBurnVal LTE 0) return false;
            if (efficientSpeedVal LTE lowSpeedAnchorKn) return false;
            if (efficientBurnVal LTE 0) return false;
            if (maxSpeedVal LT efficientSpeedVal) return false;
            return true;
        </cfscript>
    </cffunction>

<cffunction name="routegenAnchoredBurnGph" access="private" returntype="numeric" output="false">
        <cfargument name="effectiveSpeedKn" type="any" required="false" default="0">
        <cfargument name="maxSpeedKn" type="any" required="false" default="0">
        <cfargument name="maxBurnGph" type="any" required="false" default="0">
        <cfargument name="efficientSpeedKn" type="any" required="false" default="0">
        <cfargument name="efficientBurnGph" type="any" required="false" default="0">
        <cfscript>
            var lowSpeedAnchorKn = 3.5;
            var speedVal = val(arguments.effectiveSpeedKn);
            var maxSpeedVal = val(arguments.maxSpeedKn);
            var maxBurnVal = routegenNormalizeFuelBurnGph(arguments.maxBurnGph);
            var efficientSpeedVal = val(arguments.efficientSpeedKn);
            var efficientBurnVal = routegenNormalizeFuelBurnGph(arguments.efficientBurnGph);
            var lowBurnVal = efficientBurnVal * 0.25;
            var factorVal = 0;

            if (
                !routegenAnchoredBurnInputsValid(
                    maxSpeedVal,
                    maxBurnVal,
                    efficientSpeedVal,
                    efficientBurnVal
                )
            ) {
                return 0;
            }

            if (speedVal LTE lowSpeedAnchorKn) {
                return roundTo2(lowBurnVal);
            }
            if (speedVal LT efficientSpeedVal) {
                factorVal = (speedVal - lowSpeedAnchorKn) / (efficientSpeedVal - lowSpeedAnchorKn);
                return roundTo2(lowBurnVal + ((efficientBurnVal - lowBurnVal) * factorVal));
            }
            if (speedVal LTE efficientSpeedVal) {
                return roundTo2(efficientBurnVal);
            }
            if (speedVal LT maxSpeedVal) {
                factorVal = (speedVal - efficientSpeedVal) / (maxSpeedVal - efficientSpeedVal);
                return roundTo2(efficientBurnVal + ((maxBurnVal - efficientBurnVal) * factorVal));
            }
            return roundTo2(maxBurnVal);
        </cfscript>
    </cffunction>

<cffunction name="routegenCanUseAnchoredBurn" access="private" returntype="boolean" output="false">
        <cfargument name="performanceMeta" type="struct" required="true">
        <cfscript>
            var fuelSourceVal = trim(toString(structKeyExists(arguments.performanceMeta, "fuel_source") ? arguments.performanceMeta.fuel_source : ""));
            var speedSourceVal = trim(toString(structKeyExists(arguments.performanceMeta, "speed_source") ? arguments.performanceMeta.speed_source : ""));
            if (fuelSourceVal NEQ "route_inputs" AND fuelSourceVal NEQ "route_inputs_alias") return false;
            if (speedSourceVal NEQ "route_inputs" AND speedSourceVal NEQ "vessel_max") return false;
            return routegenAnchoredBurnInputsValid(
                structKeyExists(arguments.performanceMeta, "max_speed_kn") ? arguments.performanceMeta.max_speed_kn : 0,
                structKeyExists(arguments.performanceMeta, "fuel_burn_gph") ? arguments.performanceMeta.fuel_burn_gph : 0,
                structKeyExists(arguments.performanceMeta, "most_efficient_speed_kn") ? arguments.performanceMeta.most_efficient_speed_kn : 0,
                structKeyExists(arguments.performanceMeta, "most_efficient_burn_gph") ? arguments.performanceMeta.most_efficient_burn_gph : 0
            );
        </cfscript>
    </cffunction>

<cffunction name="calculateFuelEstimate" access="private" returntype="struct" output="false">
        <cfargument name="args" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var out = {
                "paceRatio"=0,
                "effectiveSpeedKnots"=0,
                "paceAdjustedBurnGph"=0,
                "weatherAdjustedSpeedKnots"=0,
                "weatherAdjustedBurnGph"=0,
                "cruiseHours"=0,
                "cruiseFuelGallons"=0,
                "idleFuelGallons"=0,
                "baseFuelGallons"=0,
                "reserveGallons"=0,
                "requiredFuelGallons"=0,
                "totalFuelCost"=0
            };
            var src = (isStruct(arguments.args) ? arguments.args : {});
            var distanceVal = val(structKeyExists(src, "distanceNm") ? src.distanceNm : 0);
            var maxSpeedVal = val(structKeyExists(src, "maxSpeedKnots") ? src.maxSpeedKnots : 0);
            var maxBurnVal = routegenNormalizeFuelBurnGph(structKeyExists(src, "maxBurnGph") ? src.maxBurnGph : 0);
            var efficientSpeedVal = val(structKeyExists(src, "efficientSpeedKnots") ? src.efficientSpeedKnots : 0);
            var efficientBurnVal = routegenNormalizeFuelBurnGph(structKeyExists(src, "efficientBurnGph") ? src.efficientBurnGph : 0);
            var paceRatioVal = 0;
            var pacePctVal = val(structKeyExists(src, "pacePct") ? src.pacePct : 0);
            var paceEnumVal = routegenNormalizePace(structKeyExists(src, "pace") ? src.pace : "");
            var weatherPctVal = val(structKeyExists(src, "weatherPct") ? src.weatherPct : 0);
            var weatherAdj = 0;
            var reservePctVal = val(structKeyExists(src, "reservePct") ? src.reservePct : 0);
            var reserveGallonsVal = val(structKeyExists(src, "reserveGallons") ? src.reserveGallons : 0);
            var idleFuelGallonsVal = val(structKeyExists(src, "idleFuelGallons") ? src.idleFuelGallons : 0);
            var fuelPriceVal = val(structKeyExists(src, "fuelPricePerGallon") ? src.fuelPricePerGallon : 0);
            var useMostEfficientValues = false;
            var allowAnchoredBurn = false;

            if (efficientSpeedVal LT 1) efficientSpeedVal = 0;
            if (efficientSpeedVal GT 60) efficientSpeedVal = 60;
            if (structKeyExists(src, "allowAnchoredBurn")) {
                allowAnchoredBurn = (
                    isBoolean(src.allowAnchoredBurn)
                        ? src.allowAnchoredBurn
                        : (val(src.allowAnchoredBurn) EQ 1)
                );
            }

            useMostEfficientValues = (
                paceEnumVal EQ "BALANCED"
                AND efficientSpeedVal GT 0
                AND efficientBurnVal GT 0
                AND (maxBurnVal LTE 0 OR abs(maxBurnVal - efficientBurnVal) LT 0.01)
            );

            if (distanceVal LTE 0 OR maxSpeedVal LTE 0) {
                return out;
            }
            if (useMostEfficientValues) {
                if (efficientSpeedVal LTE 0 OR efficientBurnVal LTE 0) {
                    return out;
                }
            } else if (maxBurnVal LTE 0) {
                return out;
            }

            // Pace enum is primary source (RELAXED/BALANCED/AGGRESSIVE => 25/50/100).
            if (paceEnumVal EQ "RELAXED") {
                paceRatioVal = 0.25;
            } else if (paceEnumVal EQ "AGGRESSIVE") {
                paceRatioVal = 1.00;
            }

            // Fallback to pacePct or explicit paceRatio if enum was not provided.
            if (!useMostEfficientValues AND paceRatioVal LTE 0) {
                if (pacePctVal GT 1) {
                    paceRatioVal = pacePctVal / 100;
                } else if (pacePctVal GT 0) {
                    paceRatioVal = pacePctVal;
                } else if (structKeyExists(src, "paceRatio")) {
                    paceRatioVal = val(src.paceRatio);
                } else {
                    paceRatioVal = 1;
                }
            }

            if (weatherPctVal LT 0) weatherPctVal = 0;
            if (weatherPctVal GT 60) weatherPctVal = 60;
            if (idleFuelGallonsVal LT 0) idleFuelGallonsVal = 0;
            weatherAdj = weatherPctVal / 100;

            if (useMostEfficientValues) {
                out.effectiveSpeedKnots = roundTo2(efficientSpeedVal);
                out.paceAdjustedBurnGph = roundTo2(efficientBurnVal);
                out.paceRatio = roundTo2(out.effectiveSpeedKnots / maxSpeedVal);
            } else {
                if (paceRatioVal LT 0.05) paceRatioVal = 0.05;
                if (paceRatioVal GT 1) paceRatioVal = 1;
                out.paceRatio = roundTo2(paceRatioVal);
                out.effectiveSpeedKnots = roundTo2(maxSpeedVal * paceRatioVal);
                if (
                    allowAnchoredBurn
                    AND routegenAnchoredBurnInputsValid(
                        maxSpeedVal,
                        maxBurnVal,
                        efficientSpeedVal,
                        efficientBurnVal
                    )
                ) {
                    out.paceAdjustedBurnGph = routegenAnchoredBurnGph(
                        out.effectiveSpeedKnots,
                        maxSpeedVal,
                        maxBurnVal,
                        efficientSpeedVal,
                        efficientBurnVal
                    );
                } else {
                    out.paceAdjustedBurnGph = paceAdjustedBurnGph(maxBurnVal, paceRatioVal, 3.0);
                }
            }
            out.weatherAdjustedSpeedKnots = roundTo2(out.effectiveSpeedKnots * (1 - weatherAdj));
            if (out.weatherAdjustedSpeedKnots LT 0.5) out.weatherAdjustedSpeedKnots = 0.5;
            out.weatherAdjustedBurnGph = roundTo2(out.paceAdjustedBurnGph * (1 + weatherAdj));
            out.cruiseHours = roundTo2(distanceVal / out.weatherAdjustedSpeedKnots);
            out.cruiseFuelGallons = roundTo2(out.cruiseHours * out.weatherAdjustedBurnGph);
            out.idleFuelGallons = roundTo2(idleFuelGallonsVal);
            out.baseFuelGallons = roundTo2(out.cruiseFuelGallons + out.idleFuelGallons);

            if (reserveGallonsVal GT 0) {
                out.reserveGallons = roundTo2(reserveGallonsVal);
            } else {
                if (reservePctVal LTE 0) reservePctVal = 33;
                out.reserveGallons = roundTo2(out.baseFuelGallons * (reservePctVal / 100));
            }

            out.requiredFuelGallons = roundTo2(out.baseFuelGallons + out.reserveGallons);
            out.totalFuelCost = (fuelPriceVal GT 0 ? round((out.requiredFuelGallons * fuelPriceVal) * 100) / 100 : 0);
            return out;
        </cfscript>
    </cffunction>

<cffunction name="routegenHasInputsJsonColumn" access="private" returntype="boolean" output="false">
        <cfscript>
            var qCol = queryNew("");
            var hasCol = false;

            qCol = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.columns
                 WHERE table_schema = DATABASE()
                   AND table_name = 'route_instances'
                   AND column_name = 'routegen_inputs_json'",
                {},
                { datasource = variables.datasource }
            );
            hasCol = (qCol.recordCount GT 0 AND val(qCol.cnt[1]) GT 0);
            return hasCol;
        </cfscript>
    </cffunction>

<cffunction name="routegenHasSegmentExposureLevelColumn" access="private" returntype="boolean" output="false">
        <cfscript>
            var qCol = queryNew("");
            var hasCol = false;
            qCol = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.columns
                 WHERE table_schema = DATABASE()
                   AND table_name = 'segment_library'
                   AND column_name = 'exposure_level'",
                {},
                { datasource = variables.datasource }
            );
            hasCol = (qCol.recordCount GT 0 AND val(qCol.cnt[1]) GT 0);
            return hasCol;
        </cfscript>
    </cffunction>

<cffunction name="routegenParseStoredInputs" access="private" returntype="struct" output="false">
        <cfargument name="rawJson" type="any" required="false" default="">
        <cfscript>
            var parsed = {};
            var normalized = {};
            var aliasMap = {};
            var canonicalKey = "";
            var aliasKeys = [];
            var aliasKey = "";
            var aliasIndex = 0;
            var needsCanonical = true;
            var existingVal = "";
            var candidateVal = "";
            var raw = trim(toString(arguments.rawJson));
            if (!len(raw)) return {};
            try {
                parsed = deserializeJSON(raw, false);
                if (isStruct(parsed)) {
                    normalized = duplicate(parsed);
                    aliasMap = {
                        "underway_hours_per_day" = [ "underwayHoursPerDay", "UNDERWAY_HOURS_PER_DAY" ],
                        "speed_kn" = [ "speedKn", "SPEED_KN" ],
                        "cruising_speed" = [ "cruisingSpeed", "max_speed_kn", "maxSpeedKn", "CRUISING_SPEED", "MAX_SPEED_KN" ],
                        "fuel_burn_gph" = [ "fuelBurnGph", "max_burn_gph", "maxBurnGph", "burn_gph", "burnGph", "FUEL_BURN_GPH" ],
                        "fuel_burn_gph_input" = [ "fuelBurnGphInput", "fuel_burn_input_gph", "fuelBurnInputGph", "FUEL_BURN_GPH_INPUT" ],
                        "fuel_burn_basis" = [ "fuelBurnBasis", "FUEL_BURN_BASIS" ],
                        "idle_burn_gph" = [ "idleBurnGph", "idleBurnGPH", "idle_burn", "idleBurn", "IDLE_BURN_GPH", "IDLE_BURN" ],
                        "idle_hours_total" = [ "idleHoursTotal", "idle_hours", "idleHours", "IDLE_HOURS_TOTAL", "IDLE_HOURS" ],
                        "weather_factor_pct" = [ "weatherFactorPct", "weather_factor", "weatherFactor", "WEATHER_FACTOR_PCT", "WEATHER_FACTOR" ],
                        "reserve_pct" = [ "reservePct", "RESERVE_PCT" ],
                        "fuel_price_per_gal" = [ "fuelPricePerGal", "FUEL_PRICE_PER_GAL" ],
                        "comfort_profile" = [ "comfortProfile", "COMFORT_PROFILE" ],
                        "overnight_bias" = [ "overnightBias", "OVERNIGHT_BIAS" ],
                        "optional_stop_flags" = [ "optionalStopFlags", "OPTIONAL_STOP_FLAGS" ],
                        "start_date" = [ "startDate", "START_DATE" ],
                        "route_type" = [ "routeType", "ROUTE_TYPE" ],
                        "route_id" = [ "routeId", "ROUTE_ID" ],
                        "selected_vessel_id" = [ "selectedVesselId", "SELECTED_VESSEL_ID" ],
                        "start_segment_id" = [ "startSegmentId", "START_SEGMENT_ID" ],
                        "end_segment_id" = [ "endSegmentId", "END_SEGMENT_ID" ],
                        "vessel_max_speed_kn" = [ "vesselMaxSpeedKn", "vessel_max_speed", "vesselMaxSpeed", "VESSEL_MAX_SPEED_KN", "MAX_SPEED" ],
                        "vessel_most_efficient_speed_kn" = [ "vesselMostEfficientSpeedKn", "most_efficient_speed_kn", "mostEfficientSpeedKn", "MOST_EFFICIENT_SPEED_KN", "MOST_EFFICIENT_SPEED" ],
                        "vessel_gph_at_most_efficient_speed" = [ "vesselGphAtMostEfficientSpeed", "gph_at_most_efficient_speed", "gphAtMostEfficientSpeed", "GPH_AT_MOST_EFFICIENT_SPEED", "GALLONS_PER_HOUR" ]
                    };

                    for (canonicalKey in aliasMap) {
                        aliasKeys = aliasMap[canonicalKey];
                        needsCanonical = true;
                        if (structKeyExists(normalized, canonicalKey)) {
                            existingVal = normalized[canonicalKey];
                            if (!isNull(existingVal)) {
                                if (isSimpleValue(existingVal)) {
                                    needsCanonical = !len(trim(toString(existingVal)));
                                } else if (isArray(existingVal)) {
                                    needsCanonical = (arrayLen(existingVal) EQ 0);
                                } else if (isStruct(existingVal)) {
                                    needsCanonical = (structCount(existingVal) EQ 0);
                                } else {
                                    needsCanonical = false;
                                }
                            }
                        }
                        if (!needsCanonical) continue;

                        for (aliasIndex = 1; aliasIndex LTE arrayLen(aliasKeys); aliasIndex++) {
                            aliasKey = aliasKeys[aliasIndex];
                            if (!structKeyExists(normalized, aliasKey)) continue;
                            candidateVal = normalized[aliasKey];
                            if (isNull(candidateVal)) continue;
                            if (isSimpleValue(candidateVal) AND !len(trim(toString(candidateVal)))) continue;
                            if (isArray(candidateVal) AND arrayLen(candidateVal) EQ 0) continue;
                            if (isStruct(candidateVal) AND structCount(candidateVal) EQ 0) continue;
                            normalized[canonicalKey] = candidateVal;
                            break;
                        }
                    }

                    return normalized;
                }
            } catch (any e) {
                return {};
            }
            return {};
        </cfscript>
    </cffunction>

<cffunction name="routegenHasLegOverrideTable" access="private" returntype="boolean" output="false">
        <cfscript>
            var qTbl = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE()
                   AND table_name = 'route_leg_user_overrides'",
                {},
                { datasource = variables.datasource }
            );
            return (qTbl.recordCount GT 0 AND val(qTbl.cnt[1]) GT 0);
        </cfscript>
    </cffunction>

<cffunction name="routegenHasRouteLegLocksTable" access="private" returntype="boolean" output="false">
        <cfscript>
            var qTbl = queryNew("");
            if (structKeyExists(request, "routegenHasRouteLegLocksTable")) {
                return request.routegenHasRouteLegLocksTable;
            }
            qTbl = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE()
                   AND table_name = 'route_leg_locks'",
                {},
                { datasource = variables.datasource }
            );
            request.routegenHasRouteLegLocksTable = (qTbl.recordCount GT 0 AND val(qTbl.cnt[1]) GT 0);
            return request.routegenHasRouteLegLocksTable;
        </cfscript>
    </cffunction>

<cffunction name="routegenHasLockDelayModelTable" access="private" returntype="boolean" output="false">
        <cfscript>
            var qTbl = queryNew("");
            if (structKeyExists(request, "routegenHasLockDelayModelTable")) {
                return request.routegenHasLockDelayModelTable;
            }
            qTbl = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE()
                   AND table_name = 'lock_delay_model'",
                {},
                { datasource = variables.datasource }
            );
            request.routegenHasLockDelayModelTable = (qTbl.recordCount GT 0 AND val(qTbl.cnt[1]) GT 0);
            return request.routegenHasLockDelayModelTable;
        </cfscript>
    </cffunction>

<cffunction name="routegenHasNormalizedTables" access="private" returntype="boolean" output="false">
        <cfscript>
            var qTbl = queryNew("");
            if (structKeyExists(request, "routegenHasNormalizedTables")) {
                return request.routegenHasNormalizedTables;
            }
            qTbl = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE()
                   AND table_name IN (
                       'route_instance_sections',
                       'route_instance_legs',
                       'route_instance_leg_progress'
                   )",
                {},
                { datasource = variables.datasource }
            );
            request.routegenHasNormalizedTables = (qTbl.recordCount GT 0 AND val(qTbl.cnt[1]) GTE 3);
            return request.routegenHasNormalizedTables;
        </cfscript>
    </cffunction>

<cffunction name="routegenHasUserSegmentOverrideTable" access="private" returntype="boolean" output="false">
        <cfscript>
            var qTbl = queryNew("");
            if (structKeyExists(request, "routegenHasUserSegmentOverrideTable")) {
                return request.routegenHasUserSegmentOverrideTable;
            }
            qTbl = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE()
                   AND table_name = 'user_segment_overrides'",
                {},
                { datasource = variables.datasource }
            );
            request.routegenHasUserSegmentOverrideTable = (qTbl.recordCount GT 0 AND val(qTbl.cnt[1]) GT 0);
            return request.routegenHasUserSegmentOverrideTable;
        </cfscript>
    </cffunction>

<cffunction name="routegenHasNormalizedLegRows" access="private" returntype="boolean" output="false">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfscript>
            var q = queryNew("");
            if (!routegenHasNormalizedTables()) return false;
            if (arguments.routeInstanceId LTE 0) return false;
            q = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM route_instance_legs
                 WHERE route_instance_id = :routeInstanceId",
                {
                    routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" }
                },
                { datasource = variables.datasource }
            );
            return (q.recordCount GT 0 AND val(q.cnt[1]) GT 0);
        </cfscript>
    </cffunction>

<cffunction name="routegenToRadians" access="private" returntype="numeric" output="false">
        <cfargument name="deg" type="numeric" required="true">
        <cfreturn arguments.deg * (pi() / 180)>
    </cffunction>

<cffunction name="routegenAtn2Compat" access="private" returntype="numeric" output="false">
        <cfargument name="y" type="numeric" required="true">
        <cfargument name="x" type="numeric" required="true">
        <cfscript>
            var piVal = pi();
            if (arguments.x GT 0) {
                return atn(arguments.y / arguments.x);
            }
            if (arguments.x LT 0 AND arguments.y GTE 0) {
                return atn(arguments.y / arguments.x) + piVal;
            }
            if (arguments.x LT 0 AND arguments.y LT 0) {
                return atn(arguments.y / arguments.x) - piVal;
            }
            if (arguments.x EQ 0 AND arguments.y GT 0) {
                return piVal / 2;
            }
            if (arguments.x EQ 0 AND arguments.y LT 0) {
                return -piVal / 2;
            }
            return 0;
        </cfscript>
    </cffunction>

<cffunction name="routegenHaversineMeters" access="private" returntype="numeric" output="false">
        <cfargument name="lat1" type="numeric" required="true">
        <cfargument name="lon1" type="numeric" required="true">
        <cfargument name="lat2" type="numeric" required="true">
        <cfargument name="lon2" type="numeric" required="true">
        <cfscript>
            var earthRadiusMeters = 6371008.8;
            var dLat = routegenToRadians(arguments.lat2 - arguments.lat1);
            var dLon = routegenToRadians(arguments.lon2 - arguments.lon1);
            var phi1 = routegenToRadians(arguments.lat1);
            var phi2 = routegenToRadians(arguments.lat2);
            var a = (sin(dLat / 2) ^ 2) + cos(phi1) * cos(phi2) * (sin(dLon / 2) ^ 2);
            if (a LT 0) a = 0;
            if (a GT 1) a = 1;
            var c = 2 * routegenAtn2Compat(sqr(a), sqr(1 - a));
            return earthRadiusMeters * c;
        </cfscript>
    </cffunction>

<cffunction name="resolveUserId" access="private" returntype="numeric" output="false">
        <cfargument name="userStruct" type="any" required="true">
        <cfset var uid = 0 />
        <cfif isStruct(arguments.userStruct)>
            <cfif structKeyExists(arguments.userStruct, "userId")>
                <cfset uid = val(arguments.userStruct.userId) />
            <cfelseif structKeyExists(arguments.userStruct, "USERID")>
                <cfset uid = val(arguments.userStruct.USERID) />
            <cfelseif structKeyExists(arguments.userStruct, "id")>
                <cfset uid = val(arguments.userStruct.id) />
            <cfelseif structKeyExists(arguments.userStruct, "ID")>
                <cfset uid = val(arguments.userStruct.ID) />
            </cfif>
        </cfif>
        <cfreturn uid />
    </cffunction>

<cffunction name="createTripTimelineMathService" access="private" returntype="any" output="false">
        <cfscript>
            try {
                return createObject("component", "fpw.api.v1.TripTimelineMathService").init();
            } catch (any primaryPathError) {
                return createObject("component", "api.v1.TripTimelineMathService").init();
            }
        </cfscript>
    </cffunction>

<cffunction name="roundTo2" access="private" returntype="numeric" output="false">
        <cfargument name="n" type="numeric" required="true">
        <cfreturn (round(arguments.n * 100) / 100) />
    </cffunction>

</cfcomponent>
