<cfcomponent output="false">

    <cffunction name="init" access="public" returntype="any" output="false">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            variables.datasource = arguments.datasource;
            return this;
        </cfscript>
    </cffunction>

    <cffunction name="persistActiveTripPace" access="public" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="pace" type="any" required="true">
        <cfscript>
            var result = {
                "SUCCESS" = false,
                "success" = false,
                "MESSAGE" = "",
                "MONITORING_EXPECTED_CHECKIN_CHANGED" = false
            };
            var paceVal = uCase(trim(toString(arguments.pace)));
            var qPlan = queryNew("");
            var qRouteLock = queryNew("");
            var routeInputs = {};
            var merged = {};
            var updatedJson = "";
            var accessGateService = {};
            var tripAccessGate = {};
            var lockedTripAccessGate = {};

            if (arguments.userId LTE 0) {
                result.ERROR = "NOT_LOGGED_IN";
                result.MESSAGE = "A logged-in captain is required.";
                return result;
            }
            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "INVALID_FLOATPLAN_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }
            if (!isValidPace(paceVal)) {
                result.ERROR = "INVALID_PACE";
                result.MESSAGE = "Pace must be RELAXED, BALANCED, or AGGRESSIVE.";
                return result;
            }

            accessGateService = getMemberAccessGateService();
            tripAccessGate = accessGateService.requireTripOperationalAccess(
                arguments.userId,
                arguments.floatPlanId
            );
            if (!structKeyExists(tripAccessGate, "allowed") OR !tripAccessGate.allowed) {
                result.ERROR = tripAccessGate.response.ERROR.CODE;
                result.MESSAGE = tripAccessGate.response.MESSAGE;
                result.tripAccess = tripAccessGate.tripAccess;
                return result;
            }

            qPlan = queryExecute("
                SELECT fp.floatPlanId, fp.userId, fp.status, fp.closedAt, fp.route_instance_id,
                       ri.routegen_inputs_json
                FROM floatplans fp
                INNER JOIN route_instances ri
                    ON ri.id = fp.route_instance_id
                WHERE fp.floatPlanId = :floatPlanId
                  AND fp.userId = :userId
                LIMIT 1
            ", {
                floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
            }, { datasource = variables.datasource });

            if (qPlan.recordCount EQ 0) {
                result.ERROR = "ACTIVE_ROUTE_FLOATPLAN_NOT_FOUND";
                result.MESSAGE = "Active route-backed float plan was not found for this user.";
                return result;
            }
            if (safeNumber(qPlan.route_instance_id[1]) LTE 0) {
                result.ERROR = "ROUTE_INSTANCE_REQUIRED";
                result.MESSAGE = "A route-backed active float plan is required.";
                return result;
            }
            if (isDate(qPlan.closedAt[1])) {
                result.ERROR = "FLOATPLAN_CLOSED";
                result.MESSAGE = "Float plan is closed.";
                return result;
            }
            if (compareNoCase(safeString(qPlan.status[1]), "ACTIVE") NEQ 0) {
                tripAccessGate = accessGateService.requireTripOperationalAccess(
                    arguments.userId,
                    arguments.floatPlanId
                );
                result.ERROR = tripAccessGate.allowed ? "TRIP_NOT_ACTIVE" : tripAccessGate.response.ERROR.CODE;
                result.MESSAGE = tripAccessGate.allowed ? "This float plan is not active." : tripAccessGate.response.MESSAGE;
                if (structKeyExists(tripAccessGate, "tripAccess")) {
                    result.tripAccess = tripAccessGate.tripAccess;
                }
                return result;
            }

            transaction {
                lockedTripAccessGate = accessGateService.requireTripOperationalAccessForUpdate(
                    arguments.userId,
                    arguments.floatPlanId
                );
                if (structKeyExists(lockedTripAccessGate, "allowed") AND lockedTripAccessGate.allowed) {
                    qRouteLock = queryExecute("
                        SELECT ri.id, ri.routegen_inputs_json
                        FROM floatplans fp
                        INNER JOIN route_instances ri
                            ON ri.id = fp.route_instance_id
                        WHERE fp.floatPlanId = :floatPlanId
                          AND fp.userId = :userIdText
                          AND UPPER(TRIM(fp.status)) = 'ACTIVE'
                          AND fp.closedAt IS NULL
                          AND fp.route_instance_id = :routeInstanceId
                          AND ri.user_id = :userIdText
                        LIMIT 1
                        FOR UPDATE
                    ", {
                        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                        routeInstanceId = { value = safeNumber(qPlan.route_instance_id[1]), cfsqltype = "cf_sql_integer" },
                        userIdText = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" }
                    }, { datasource = variables.datasource });
                    if (qRouteLock.recordCount EQ 1) {
                        routeInputs = parseJsonStruct(qRouteLock.routegen_inputs_json[1]);
                        merged = mergeActiveTripOverride(routeInputs, arguments.floatPlanId, paceVal);
                        updatedJson = serializeJSON(merged.inputs);
                        queryExecute("
                            UPDATE route_instances
                            SET routegen_inputs_json = :routeInputsJson
                            WHERE id = :routeInstanceId
                              AND user_id = :userIdText
                        ", {
                            routeInputsJson = { value = updatedJson, cfsqltype = "cf_sql_longvarchar" },
                            routeInstanceId = { value = safeNumber(qRouteLock.id[1]), cfsqltype = "cf_sql_integer" },
                            userIdText = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" }
                        }, { datasource = variables.datasource });
                    }
                }
            }
            if (!structKeyExists(lockedTripAccessGate, "allowed") OR !lockedTripAccessGate.allowed) {
                result.ERROR = lockedTripAccessGate.response.ERROR.CODE;
                result.MESSAGE = lockedTripAccessGate.response.MESSAGE;
                result.tripAccess = lockedTripAccessGate.tripAccess;
                return result;
            }
            if (qRouteLock.recordCount NEQ 1) {
                result.ERROR = "ACTIVE_ROUTE_FLOATPLAN_CHANGED";
                result.MESSAGE = "The active route changed before its pace could be updated. Please retry.";
                return result;
            }

            result.SUCCESS = true;
            result.success = true;
            result.MESSAGE = "Active-trip pace updated.";
            result.FLOATPLANID = arguments.floatPlanId;
            result.ROUTE_INSTANCE_ID = safeNumber(qRouteLock.id[1]);
            result.PACE = paceVal;
            result.pace = paceVal;
            result.PACE_META = merged.paceMeta;
            result.paceMeta = merged.paceMeta;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="mergeActiveTripOverride" access="public" returntype="struct" output="false">
        <cfargument name="routeInputs" type="struct" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="pace" type="any" required="true">
        <cfscript>
            var inputs = duplicate(arguments.routeInputs);
            var paceMeta = buildPaceMeta(inputs, arguments.floatPlanId, arguments.pace);

            inputs.active_trip_pace = paceMeta.currentValue;
            inputs.active_trip_effective_speed_kn = paceMeta.effectiveSpeedKn;
            inputs.active_trip_weather_adjusted_speed_kn = paceMeta.weatherAdjustedSpeedKn;
            inputs.active_trip_speed_source = paceMeta.speedSource;
            inputs.active_trip_floatplan_id = arguments.floatPlanId;
            inputs.active_trip_updated_at_utc = formatUtc(now());
            inputs.active_trip_weather_factor_pct = paceMeta.weatherFactorPct;
            inputs.active_trip_max_speed_kn = paceMeta.maxSpeedKn;
            inputs.active_trip_most_efficient_speed_kn = paceMeta.mostEfficientSpeedKn;

            return {
                "inputs" = inputs,
                "paceMeta" = paceMeta
            };
        </cfscript>
    </cffunction>

    <cffunction name="buildPaceMeta" access="public" returntype="struct" output="false">
        <cfargument name="routeInputs" type="struct" required="true">
        <cfargument name="floatPlanId" type="numeric" required="false" default="0">
        <cfargument name="requestedPace" type="any" required="false" default="">
        <cfscript>
            var plannedPace = normalizePace(getStructValue(arguments.routeInputs, "pace", "RELAXED"));
            var requestedPaceVal = uCase(trim(toString(arguments.requestedPace)));
            var activePace = normalizePace(getStructValue(arguments.routeInputs, "active_trip_pace", ""));
            var activeFloatPlanId = safeNumber(getStructValue(arguments.routeInputs, "active_trip_floatplan_id", 0));
            var selectedPace = plannedPace;
            var usingActiveOverride = false;
            var maxSpeed = resolveMaxSpeed(arguments.routeInputs);
            var mostEfficientSpeed = resolveMostEfficientSpeed(arguments.routeInputs);
            var weatherFactorPct = resolveWeatherFactorPct(arguments.routeInputs);
            var directSpeed = getNumericFromKeys(
                arguments.routeInputs,
                [ "weather_adjusted_speed_kn", "weatherAdjustedSpeedKn", "effective_speed_kn", "effectiveSpeedKn", "effective_cruising_speed", "effectiveCruisingSpeed", "cruising_speed", "cruisingSpeed" ],
                true
            );
            var effectiveSpeed = 0;
            var weatherAdjustedSpeed = 0;
            var sourceVal = "";
            var labelVal = "";

            if (isValidPace(requestedPaceVal)) {
                selectedPace = requestedPaceVal;
                usingActiveOverride = true;
            } else if (activeFloatPlanId GT 0 AND activeFloatPlanId EQ safeNumber(arguments.floatPlanId) AND isValidPace(activePace)) {
                selectedPace = activePace;
                usingActiveOverride = true;
            }

            if (!usingActiveOverride AND directSpeed GT 0) {
                effectiveSpeed = roundTo2(directSpeed);
                weatherAdjustedSpeed = roundTo2(directSpeed);
                sourceVal = "route_inputs_effective_speed";
            } else {
                effectiveSpeed = computePaceSpeed(maxSpeed, mostEfficientSpeed, selectedPace);
                weatherAdjustedSpeed = applyWeatherFactor(effectiveSpeed, weatherFactorPct);
                sourceVal = buildSpeedSource(selectedPace, mostEfficientSpeed);
            }
            labelVal = paceLabel(selectedPace);

            return {
                "available" = (weatherAdjustedSpeed GT 0),
                "currentValue" = selectedPace,
                "currentLabel" = labelVal,
                "plannedValue" = plannedPace,
                "plannedLabel" = paceLabel(plannedPace),
                "isActiveTripOverride" = usingActiveOverride,
                "activeTripFloatPlanId" = (usingActiveOverride ? safeNumber(arguments.floatPlanId) : 0),
                "effectiveSpeedKn" = effectiveSpeed,
                "weatherAdjustedSpeedKn" = weatherAdjustedSpeed,
                "speedSource" = sourceVal,
                "weatherFactorPct" = weatherFactorPct,
                "maxSpeedKn" = maxSpeed,
                "mostEfficientSpeedKn" = mostEfficientSpeed,
                "updatedAtUtc" = safeString(getStructValue(arguments.routeInputs, "active_trip_updated_at_utc", "")),
                "options" = paceOptions()
            };
        </cfscript>
    </cffunction>

    <cffunction name="resolveEffectiveSpeedKn" access="public" returntype="numeric" output="false">
        <cfargument name="routeInputs" type="struct" required="true">
        <cfargument name="floatPlanId" type="numeric" required="false" default="0">
        <cfscript>
            var paceMeta = buildPaceMeta(arguments.routeInputs, arguments.floatPlanId);
            var directSpeed = 0;

            if (paceMeta.isActiveTripOverride AND paceMeta.weatherAdjustedSpeedKn GT 0) {
                return paceMeta.weatherAdjustedSpeedKn;
            }

            directSpeed = getNumericFromKeys(
                arguments.routeInputs,
                [ "weather_adjusted_speed_kn", "weatherAdjustedSpeedKn", "effective_speed_kn", "effectiveSpeedKn", "effective_cruising_speed", "effectiveCruisingSpeed", "cruising_speed", "cruisingSpeed", "vessel_most_efficient_speed_kn", "vesselMostEfficientSpeedKn" ],
                true
            );
            if (directSpeed GT 0) {
                return roundTo2(directSpeed);
            }
            return paceMeta.weatherAdjustedSpeedKn;
        </cfscript>
    </cffunction>

    <cffunction name="normalizePace" access="public" returntype="string" output="false">
        <cfargument name="pace" type="any" required="false" default="RELAXED">
        <cfscript>
            var paceVal = uCase(trim(toString(arguments.pace)));
            if (paceVal EQ "BALANCED") return "BALANCED";
            if (paceVal EQ "AGGRESSIVE") return "AGGRESSIVE";
            return "RELAXED";
        </cfscript>
    </cffunction>

    <cffunction name="isValidPace" access="public" returntype="boolean" output="false">
        <cfargument name="pace" type="any" required="true">
        <cfscript>
            return listFindNoCase("RELAXED,BALANCED,AGGRESSIVE", trim(toString(arguments.pace))) GT 0;
        </cfscript>
    </cffunction>

    <cffunction name="paceOptions" access="public" returntype="array" output="false">
        <cfscript>
            return [
                { "value" = "RELAXED", "label" = "Relaxed", "index" = 0 },
                { "value" = "BALANCED", "label" = "Efficient Speed", "index" = 1 },
                { "value" = "AGGRESSIVE", "label" = "Max Speed", "index" = 2 }
            ];
        </cfscript>
    </cffunction>

    <cffunction name="paceIndex" access="public" returntype="numeric" output="false">
        <cfargument name="pace" type="any" required="false" default="RELAXED">
        <cfscript>
            var paceVal = normalizePace(arguments.pace);
            if (paceVal EQ "BALANCED") return 1;
            if (paceVal EQ "AGGRESSIVE") return 2;
            return 0;
        </cfscript>
    </cffunction>

    <cffunction name="paceLabel" access="public" returntype="string" output="false">
        <cfargument name="pace" type="any" required="false" default="RELAXED">
        <cfscript>
            var paceVal = normalizePace(arguments.pace);
            if (paceVal EQ "BALANCED") return "Efficient Speed";
            if (paceVal EQ "AGGRESSIVE") return "Max Speed";
            return "Relaxed";
        </cfscript>
    </cffunction>

    <cffunction name="getMemberAccessGateService" access="private" returntype="any" output="false">
        <cfscript>
            try {
                return createObject("component", "fpw.api.v1.MemberAccessGateService").init(variables.datasource);
            } catch (any primaryPathError) {
                return createObject("component", "api.v1.MemberAccessGateService").init(variables.datasource);
            }
        </cfscript>
    </cffunction>

    <cffunction name="computePaceSpeed" access="private" returntype="numeric" output="false">
        <cfargument name="maxSpeedKn" type="numeric" required="true">
        <cfargument name="mostEfficientSpeedKn" type="numeric" required="true">
        <cfargument name="pace" type="any" required="true">
        <cfscript>
            var paceVal = normalizePace(arguments.pace);
            var factor = 0.25;
            var maxSpeed = normalizeCruisingSpeed(arguments.maxSpeedKn, 20);
            var out = 0;

            if (paceVal EQ "BALANCED" AND arguments.mostEfficientSpeedKn GTE 1) {
                out = min(60, arguments.mostEfficientSpeedKn);
                return roundTo2(out);
            }
            if (paceVal EQ "BALANCED") {
                factor = 0.50;
            } else if (paceVal EQ "AGGRESSIVE") {
                factor = 1.00;
            }
            out = maxSpeed * factor;
            if (out LT 1) out = 1;
            return roundTo2(out);
        </cfscript>
    </cffunction>

    <cffunction name="applyWeatherFactor" access="private" returntype="numeric" output="false">
        <cfargument name="speedKn" type="numeric" required="true">
        <cfargument name="weatherFactorPct" type="numeric" required="true">
        <cfscript>
            var weatherPct = arguments.weatherFactorPct;
            var out = arguments.speedKn;
            if (weatherPct LT 0) weatherPct = 0;
            if (weatherPct GT 70) weatherPct = 70;
            if (out LTE 0) return 0;
            if (weatherPct GT 0) {
                out = out * (1 - (weatherPct / 100));
            }
            if (out LT 0.5) out = 0.5;
            return roundTo2(out);
        </cfscript>
    </cffunction>

    <cffunction name="resolveMaxSpeed" access="private" returntype="numeric" output="false">
        <cfargument name="routeInputs" type="struct" required="true">
        <cfscript>
            return normalizeCruisingSpeed(
                getNumericFromKeys(
                    arguments.routeInputs,
                    [ "cruising_speed", "cruisingSpeed", "max_speed_kn", "maxSpeedKn", "vessel_max_speed_kn", "vesselMaxSpeedKn", "vessel_max_speed", "vesselMaxSpeed" ],
                    true
                ),
                20
            );
        </cfscript>
    </cffunction>

    <cffunction name="resolveMostEfficientSpeed" access="private" returntype="numeric" output="false">
        <cfargument name="routeInputs" type="struct" required="true">
        <cfscript>
            var valOut = getNumericFromKeys(
                arguments.routeInputs,
                [ "vessel_most_efficient_speed_kn", "vesselMostEfficientSpeedKn", "most_efficient_speed_kn", "mostEfficientSpeedKn", "MOST_EFFICIENT_SPEED_KN", "MOST_EFFICIENT_SPEED" ],
                true
            );
            if (valOut GT 60) valOut = 60;
            if (valOut LT 1) valOut = 0;
            return roundTo2(valOut);
        </cfscript>
    </cffunction>

    <cffunction name="resolveWeatherFactorPct" access="private" returntype="numeric" output="false">
        <cfargument name="routeInputs" type="struct" required="true">
        <cfscript>
            var weatherPct = getNumericFromKeys(
                arguments.routeInputs,
                [ "weather_factor_pct", "weatherFactorPct", "weather_factor", "weatherFactor", "WEATHER_FACTOR_PCT", "WEATHER_FACTOR" ],
                false
            );
            if (weatherPct LT 0) weatherPct = 0;
            if (weatherPct GT 70) weatherPct = 70;
            return roundTo2(weatherPct);
        </cfscript>
    </cffunction>

    <cffunction name="buildSpeedSource" access="private" returntype="string" output="false">
        <cfargument name="pace" type="any" required="true">
        <cfargument name="mostEfficientSpeedKn" type="numeric" required="true">
        <cfscript>
            var paceVal = normalizePace(arguments.pace);
            if (paceVal EQ "BALANCED" AND arguments.mostEfficientSpeedKn GTE 1) {
                return "vessel_most_efficient";
            }
            if (paceVal EQ "BALANCED") {
                return "vessel_max_speed_balanced_fallback";
            }
            return "vessel_max_speed_pace_factor";
        </cfscript>
    </cffunction>

    <cffunction name="normalizeCruisingSpeed" access="private" returntype="numeric" output="false">
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

    <cffunction name="getNumericFromKeys" access="private" returntype="numeric" output="false">
        <cfargument name="src" type="any" required="false" default="#{}#">
        <cfargument name="keys" type="array" required="true">
        <cfargument name="positiveOnly" type="boolean" required="false" default="true">
        <cfscript>
            var source = (isStruct(arguments.src) ? arguments.src : {});
            var i = 0;
            var key = "";
            var rawVal = "";
            var n = 0;
            for (i = 1; i LTE arrayLen(arguments.keys); i++) {
                key = arguments.keys[i];
                if (!structKeyExists(source, key) OR isNull(source[key])) continue;
                rawVal = source[key];
                if (!isNumeric(rawVal)) continue;
                n = val(rawVal);
                if (arguments.positiveOnly AND n LTE 0) continue;
                return roundTo2(n);
            }
            return 0;
        </cfscript>
    </cffunction>

    <cffunction name="getStructValue" access="private" returntype="any" output="false">
        <cfargument name="src" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfargument name="fallback" type="any" required="false" default="">
        <cfscript>
            if (structKeyExists(arguments.src, arguments.key) AND !isNull(arguments.src[arguments.key])) {
                return arguments.src[arguments.key];
            }
            return arguments.fallback;
        </cfscript>
    </cffunction>

    <cffunction name="parseJsonStruct" access="private" returntype="struct" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfscript>
            var raw = safeString(arguments.value);
            var parsed = {};
            if (!len(raw)) {
                return {};
            }
            try {
                parsed = deserializeJSON(raw);
                if (isStruct(parsed)) {
                    return parsed;
                }
            } catch (any parseErr) {}
            return {};
        </cfscript>
    </cffunction>

    <cffunction name="safeString" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfscript>
            if (isNull(arguments.value)) {
                return "";
            }
            return trim(toString(arguments.value));
        </cfscript>
    </cffunction>

    <cffunction name="safeNumber" access="private" returntype="numeric" output="false">
        <cfargument name="value" type="any" required="false" default="0">
        <cfscript>
            if (isNull(arguments.value) OR !isNumeric(arguments.value)) {
                return 0;
            }
            return val(arguments.value);
        </cfscript>
    </cffunction>

    <cffunction name="roundTo2" access="private" returntype="numeric" output="false">
        <cfargument name="value" type="numeric" required="true">
        <cfscript>
            return round(arguments.value * 100) / 100;
        </cfscript>
    </cffunction>

    <cffunction name="formatUtc" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfscript>
            if (!isDate(arguments.value)) {
                return "";
            }
            return dateTimeFormat(arguments.value, "yyyy-mm-dd'T'HH:nn:ss'Z'");
        </cfscript>
    </cffunction>

</cfcomponent>
