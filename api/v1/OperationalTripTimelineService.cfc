<cfcomponent output="false">

    <cffunction name="init" access="public" returntype="any" output="false">
        <cfscript>
            variables.timelineMath = createTripTimelineMathService();
            return this;
        </cfscript>
    </cffunction>

    <cffunction name="calculateScheduledTimeline" access="public" returntype="struct" output="false">
        <cfargument name="snapshot" type="struct" required="true">
        <cfscript>
            var out = {
                "success" = false,
                "message" = "",
                "floatPlanId" = readNumber(arguments.snapshot, "floatPlanId"),
                "routeInstanceId" = readNumber(arguments.snapshot, "routeInstanceId"),
                "sourceTimezone" = readString(arguments.snapshot, "sourceTimezone"),
                "scheduledTripDepartureLocal" = readString(arguments.snapshot, "scheduledDepartureLocal"),
                "scheduledTripDepartureUtc" = "",
                "projectedTripDepartureLocal" = "",
                "projectedTripDepartureUtc" = "",
                "underwayHoursPerDay" = 6.5,
                "resolvedDailyStartTime" = "",
                "dailyStartSource" = "",
                "legs" = [],
                "finalScheduledArrivalLocal" = "",
                "finalScheduledArrivalUtc" = "",
                "totalUnderwayDurationSeconds" = 0,
                "totalElapsedCalendarDurationSeconds" = 0,
                "operationalDayCount" = 0,
                "degradedReason" = "",
                "warnings" = [],
                "lockDurationConsumesDailyWindow" = true
            };
            var scheduledDepartureUtc = readDate(arguments.snapshot, "scheduledDepartureUtc");
            var scheduledDepartureLocal = out.scheduledTripDepartureLocal;
            var underwayRaw = readValue(arguments.snapshot, "underwayHoursPerDay", "");
            var underwayHours = variables.timelineMath.normalizeUnderwayHours(underwayRaw);
            var explicitDailyStart = variables.timelineMath.normalizeLocalTime(readString(arguments.snapshot, "dailyStartLocalTime"));
            var routeDailyStart = variables.timelineMath.normalizeLocalTime(readString(arguments.snapshot, "routePreferredDailyStartTime"));
            var departureClock = "";
            var resolvedDailyStart = "";
            var dailyStartSource = "";
            var manualDelayMinutes = max(0, readNumber(arguments.snapshot, "manualDelayMinutes"));
            var projectedStartUtc = "";
            var projectedStartLocal = "";
            var initialDayUsedSeconds = max(0, readNumber(arguments.snapshot, "initialDayUsedSeconds"));
            var legs = (structKeyExists(arguments.snapshot, "legs") AND isArray(arguments.snapshot.legs) ? arguments.snapshot.legs : []);
            var mathResult = {};

            if (!isDate(scheduledDepartureUtc)) {
                out.message = "Float Plan scheduled departure UTC is required.";
                return out;
            }
            if (!len(out.sourceTimezone)) {
                out.message = "Float Plan departure timezone is required.";
                return out;
            }
            if (!len(scheduledDepartureLocal)) {
                scheduledDepartureLocal = variables.timelineMath.formatLocal(scheduledDepartureUtc, out.sourceTimezone);
                out.scheduledTripDepartureLocal = scheduledDepartureLocal;
            }
            departureClock = extractLocalClock(scheduledDepartureLocal);
            if (len(explicitDailyStart)) {
                resolvedDailyStart = explicitDailyStart;
                dailyStartSource = "floatplans.dailyStartLocalTime";
            } else if (len(routeDailyStart)) {
                resolvedDailyStart = routeDailyStart;
                dailyStartSource = "route_instances.routegen_inputs_json";
            } else {
                resolvedDailyStart = departureClock;
                dailyStartSource = "floatplans.departureTime";
            }
            if (!len(resolvedDailyStart)) {
                out.message = "A subsequent-day start time could not be resolved from the Float Plan or operational route snapshot.";
                return out;
            }

            out.scheduledTripDepartureUtc = variables.timelineMath.formatUtc(scheduledDepartureUtc);
            out.underwayHoursPerDay = underwayHours;
            out.resolvedDailyStartTime = resolvedDailyStart;
            out.dailyStartSource = dailyStartSource;

            if (!isNumeric(underwayRaw) OR val(underwayRaw) LTE 0) {
                out.degradedReason = "UNDERWAY_HOURS_DEFAULTED";
                arrayAppend(out.warnings, {
                    "code" = "UNDERWAY_HOURS_DEFAULTED",
                    "message" = "Underway Hours/Day was missing or invalid and defaulted to 6.5 hours."
                });
            } else if (val(underwayRaw) LT 1 OR val(underwayRaw) GT 24) {
                out.degradedReason = "UNDERWAY_HOURS_CLAMPED";
                arrayAppend(out.warnings, {
                    "code" = "UNDERWAY_HOURS_CLAMPED",
                    "message" = "Underway Hours/Day was clamped to the supported 1 through 24 hour range."
                });
            }

            projectedStartUtc = dateAdd("n", manualDelayMinutes, scheduledDepartureUtc);
            projectedStartLocal = variables.timelineMath.formatLocal(projectedStartUtc, out.sourceTimezone);
            out.projectedTripDepartureUtc = variables.timelineMath.formatUtc(projectedStartUtc);
            out.projectedTripDepartureLocal = projectedStartLocal;

            mathResult = variables.timelineMath.buildTimeline(
                legs = legs,
                startUtc = projectedStartUtc,
                sourceTimezone = out.sourceTimezone,
                underwayHoursPerDay = underwayHours,
                subsequentDayStartTime = resolvedDailyStart,
                initialDayUsedSeconds = initialDayUsedSeconds
            );
            if (!mathResult.success) {
                out.message = mathResult.message;
                return out;
            }

            out.success = true;
            out.legs = mathResult.legs;
            out.finalScheduledArrivalLocal = mathResult.finalArrivalLocal;
            out.finalScheduledArrivalUtc = mathResult.finalArrivalUtc;
            out.totalUnderwayDurationSeconds = mathResult.totalUnderwayDurationSeconds;
            out.operationalDayCount = mathResult.operationalDayCount;
            out.lockDurationConsumesDailyWindow = mathResult.lockDurationConsumesDailyWindow;
            if (len(out.finalScheduledArrivalUtc)) {
                out.totalElapsedCalendarDurationSeconds = max(
                    0,
                    dateDiff("s", scheduledDepartureUtc, parseUtc(out.finalScheduledArrivalUtc))
                );
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="resolveRoutePreferredDailyStartTime" access="public" returntype="string" output="false">
        <cfargument name="routeInputs" type="struct" required="true">
        <cfscript>
            var keys = [
                "preferred_daily_start_time",
                "daily_start_local_time",
                "dailyStartLocalTime"
            ];
            var i = 0;
            var normalized = "";
            for (i = 1; i LTE arrayLen(keys); i++) {
                if (structKeyExists(arguments.routeInputs, keys[i])) {
                    normalized = variables.timelineMath.normalizeLocalTime(arguments.routeInputs[keys[i]]);
                    if (len(normalized)) return normalized;
                }
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="extractLocalClock" access="private" returntype="string" output="false">
        <cfargument name="localDateTime" type="string" required="true">
        <cfscript>
            var normalized = replace(trim(arguments.localDateTime), "T", " ", "one");
            var clockVal = "";
            if (reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}(:[0-9]{2})?$", normalized)) {
                clockVal = listLast(normalized, " ");
            } else if (reFind("^[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?$", normalized)) {
                clockVal = normalized;
            }
            return variables.timelineMath.normalizeLocalTime(clockVal);
        </cfscript>
    </cffunction>

    <cffunction name="readDate" access="private" returntype="any" output="false">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfscript>
            var raw = readValue(arguments.source, arguments.key, "");
            var normalized = "";
            if (isDate(raw)) return raw;
            normalized = replace(trim(toString(raw)), "T", " ", "one");
            normalized = replace(normalized, "Z", "", "one");
            if (len(normalized) GTE 19) normalized = left(normalized, 19);
            if (isDate(normalized)) return parseDateTime(normalized);
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="parseUtc" access="private" returntype="any" output="false">
        <cfargument name="value" type="string" required="true">
        <cfscript>
            var normalized = replace(trim(arguments.value), "T", " ", "one");
            normalized = replace(normalized, "Z", "", "one");
            if (len(normalized) GTE 19) normalized = left(normalized, 19);
            if (isDate(normalized)) return parseDateTime(normalized);
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="readValue" access="private" returntype="any" output="false">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfargument name="fallback" type="any" required="false" default="">
        <cfscript>
            if (!structKeyExists(arguments.source, arguments.key) OR isNull(arguments.source[arguments.key])) {
                return arguments.fallback;
            }
            return arguments.source[arguments.key];
        </cfscript>
    </cffunction>

    <cffunction name="readNumber" access="private" returntype="numeric" output="false">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfscript>
            var valueVal = readValue(arguments.source, arguments.key, 0);
            if (!isNumeric(valueVal)) return 0;
            return val(valueVal);
        </cfscript>
    </cffunction>

    <cffunction name="readString" access="private" returntype="string" output="false">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfscript>
            return trim(toString(readValue(arguments.source, arguments.key, "")));
        </cfscript>
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

</cfcomponent>
