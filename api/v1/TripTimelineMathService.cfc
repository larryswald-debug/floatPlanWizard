<cfcomponent output="false">

    <cffunction name="init" access="public" returntype="any" output="false">
        <cfscript>
            return this;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeUnderwayHours" access="public" returntype="numeric" output="false">
        <cfargument name="hours" type="any" required="false" default="6.5">
        <cfscript>
            var valueVal = val(arguments.hours);
            if (valueVal LTE 0) valueVal = 6.5;
            if (valueVal LT 1) valueVal = 1;
            if (valueVal GT 24) valueVal = 24;
            return valueVal;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeLocalTime" access="public" returntype="string" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfscript>
            var raw = trim(toString(arguments.value));
            var parts = [];
            var hourVal = 0;
            var minuteVal = 0;
            var secondVal = 0;

            if (!len(raw) OR !reFind("^\d{1,2}:\d{2}(:\d{2})?$", raw)) {
                return "";
            }

            parts = listToArray(raw, ":");
            hourVal = val(parts[1]);
            minuteVal = val(parts[2]);
            secondVal = (arrayLen(parts) GTE 3 ? val(parts[3]) : 0);
            if (
                hourVal LT 0 OR hourVal GT 23
                OR minuteVal LT 0 OR minuteVal GT 59
                OR secondVal LT 0 OR secondVal GT 59
            ) {
                return "";
            }

            return numberFormat(hourVal, "00") & ":" & numberFormat(minuteVal, "00") & ":" & numberFormat(secondVal, "00");
        </cfscript>
    </cffunction>

    <cffunction name="calculateDurationSeconds" access="public" returntype="numeric" output="false">
        <cfargument name="distanceNm" type="numeric" required="true">
        <cfargument name="speedKn" type="numeric" required="true">
        <cfargument name="lockMinutes" type="numeric" required="false" default="0">
        <cfscript>
            var distanceVal = max(0, val(arguments.distanceNm));
            var speedVal = val(arguments.speedKn);
            var lockMinutesVal = max(0, val(arguments.lockMinutes));

            if (distanceVal GT 0 AND speedVal LTE 0) {
                return 0;
            }
            return round((distanceVal GT 0 ? (distanceVal / speedVal) * 3600 : 0) + (lockMinutesVal * 60));
        </cfscript>
    </cffunction>

    <cffunction name="getWindowAllocation" access="public" returntype="struct" output="false">
        <cfargument name="remainingSeconds" type="numeric" required="true">
        <cfargument name="usedSeconds" type="numeric" required="true">
        <cfargument name="maximumSeconds" type="numeric" required="true">
        <cfscript>
            var remainingVal = max(0, val(arguments.remainingSeconds));
            var maximumVal = max(1, val(arguments.maximumSeconds));
            var usedVal = min(maximumVal, max(0, val(arguments.usedSeconds)));
            var availableVal = max(0, maximumVal - usedVal);

            return {
                "advanceDay" = (remainingVal GT 0 AND availableVal LTE 0),
                "availableSeconds" = availableVal,
                "sliceSeconds" = min(remainingVal, availableVal)
            };
        </cfscript>
    </cffunction>

    <cffunction name="advanceLocalDate" access="public" returntype="date" output="false">
        <cfargument name="localDate" type="date" required="true">
        <cfscript>
            return dateAdd("d", 1, arguments.localDate);
        </cfscript>
    </cffunction>

    <cffunction name="buildTimeline" access="public" returntype="struct" output="false">
        <cfargument name="legs" type="array" required="true">
        <cfargument name="startUtc" type="any" required="true">
        <cfargument name="sourceTimezone" type="string" required="true">
        <cfargument name="underwayHoursPerDay" type="any" required="false" default="6.5">
        <cfargument name="subsequentDayStartTime" type="string" required="true">
        <cfargument name="initialDayUsedSeconds" type="numeric" required="false" default="0">
        <cfscript>
            var out = {
                "success" = false,
                "message" = "",
                "legs" = [],
                "finalArrivalUtc" = "",
                "finalArrivalLocal" = "",
                "totalUnderwayDurationSeconds" = 0,
                "totalElapsedCalendarDurationSeconds" = 0,
                "operationalDayCount" = 0,
                "lockDurationConsumesDailyWindow" = true
            };
            var timezoneVal = normalizeTimezone(arguments.sourceTimezone);
            var dailyStartVal = normalizeLocalTime(arguments.subsequentDayStartTime);
            var hoursVal = normalizeUnderwayHours(arguments.underwayHoursPerDay);
            var maximumSeconds = hoursVal * 3600;
            var currentUtc = normalizeUtcDate(arguments.startUtc);
            var firstUtc = "";
            var currentLocalDate = "";
            var currentDayNumber = 1;
            var usedSeconds = min(maximumSeconds, max(0, val(arguments.initialDayUsedSeconds)));
            var i = 0;
            var leg = {};
            var durationSeconds = 0;
            var remainingSeconds = 0;
            var allocation = {};
            var sliceDepartureUtc = "";
            var sliceArrivalUtc = "";
            var sliceSeconds = 0;
            var legDepartureUtc = "";
            var legArrivalUtc = "";
            var legSegments = [];
            var nextLocalDate = "";
            var nextStartUtc = "";
            var routeLegId = 0;
            var routeLegOrder = 0;
            var distanceNm = 0;
            var effectiveSpeedKn = 0;
            var lockMinutes = 0;

            if (!len(timezoneVal)) {
                out.message = "A supported source timezone is required.";
                return out;
            }
            if (!len(dailyStartVal)) {
                out.message = "A valid subsequent-day start time is required.";
                return out;
            }
            if (!isDate(currentUtc)) {
                out.message = "A valid scheduled start UTC timestamp is required.";
                return out;
            }

            firstUtc = currentUtc;
            currentLocalDate = parseDateTime(dateTimeFormat(currentUtc, "yyyy-mm-dd", timezoneVal));

            for (i = 1; i LTE arrayLen(arguments.legs); i++) {
                leg = arguments.legs[i];
                routeLegId = readNumber(leg, "routeLegId");
                routeLegOrder = readNumber(leg, "routeLegOrder");
                if (routeLegOrder LTE 0) routeLegOrder = i;
                distanceNm = readNumber(leg, "distanceNm");
                effectiveSpeedKn = readNumber(leg, "effectiveSpeedKn");
                lockMinutes = readNumber(leg, "lockDurationMinutes");
                durationSeconds = (
                    structKeyExists(leg, "durationSeconds") AND isNumeric(leg.durationSeconds)
                        ? max(0, val(leg.durationSeconds))
                        : calculateDurationSeconds(distanceNm, effectiveSpeedKn, lockMinutes)
                );
                if (distanceNm GT 0 AND effectiveSpeedKn LTE 0 AND durationSeconds LTE 0) {
                    out.message = "Every route leg with distance requires a positive effective speed.";
                    return out;
                }

                remainingSeconds = durationSeconds;
                legDepartureUtc = "";
                legArrivalUtc = "";
                legSegments = [];

                while (remainingSeconds GT 0) {
                    allocation = getWindowAllocation(remainingSeconds, usedSeconds, maximumSeconds);
                    if (allocation.advanceDay) {
                        nextLocalDate = advanceLocalDate(currentLocalDate);
                        nextStartUtc = localWallToUtc(
                            dateFormat(nextLocalDate, "yyyy-mm-dd") & " " & dailyStartVal,
                            timezoneVal
                        );
                        if (!isDate(nextStartUtc)) {
                            out.message = "The next operational-day start could not be converted to UTC.";
                            return out;
                        }
                        currentLocalDate = nextLocalDate;
                        currentUtc = nextStartUtc;
                        currentDayNumber += 1;
                        usedSeconds = 0;
                        allocation = getWindowAllocation(remainingSeconds, usedSeconds, maximumSeconds);
                    }

                    sliceSeconds = allocation.sliceSeconds;
                    if (sliceSeconds LTE 0) {
                        out.message = "The daily underway window could not allocate remaining duration.";
                        return out;
                    }

                    sliceDepartureUtc = currentUtc;
                    sliceArrivalUtc = dateAdd("s", sliceSeconds, sliceDepartureUtc);
                    if (!isDate(legDepartureUtc)) legDepartureUtc = sliceDepartureUtc;
                    legArrivalUtc = sliceArrivalUtc;
                    arrayAppend(legSegments, {
                        "operationalDayNumber" = currentDayNumber,
                        "scheduledDepartureUtc" = formatUtc(sliceDepartureUtc),
                        "scheduledDepartureLocal" = formatLocal(sliceDepartureUtc, timezoneVal),
                        "scheduledArrivalUtc" = formatUtc(sliceArrivalUtc),
                        "scheduledArrivalLocal" = formatLocal(sliceArrivalUtc, timezoneVal),
                        "durationSeconds" = sliceSeconds
                    });

                    currentUtc = sliceArrivalUtc;
                    usedSeconds += sliceSeconds;
                    remainingSeconds -= sliceSeconds;
                    if (remainingSeconds LT 0.001) remainingSeconds = 0;
                }

                if (durationSeconds LTE 0) {
                    legDepartureUtc = currentUtc;
                    legArrivalUtc = currentUtc;
                }

                arrayAppend(out.legs, {
                    "routeLegId" = routeLegId,
                    "routeLegOrder" = routeLegOrder,
                    "sequence" = i,
                    "fromName" = readString(leg, "fromName"),
                    "toName" = readString(leg, "toName"),
                    "distanceNm" = distanceNm,
                    "effectiveSpeedKn" = effectiveSpeedKn,
                    "lockDurationMinutes" = lockMinutes,
                    "durationSeconds" = durationSeconds,
                    "scheduledDepartureUtc" = formatUtc(legDepartureUtc),
                    "scheduledDepartureLocal" = formatLocal(legDepartureUtc, timezoneVal),
                    "scheduledArrivalUtc" = formatUtc(legArrivalUtc),
                    "scheduledArrivalLocal" = formatLocal(legArrivalUtc, timezoneVal),
                    "operationalDayNumber" = (arrayLen(legSegments) ? legSegments[1].operationalDayNumber : currentDayNumber),
                    "dailyWindowSegments" = legSegments
                });
                out.totalUnderwayDurationSeconds += durationSeconds;
            }

            out.success = true;
            out.operationalDayCount = (arrayLen(arguments.legs) ? currentDayNumber : 0);
            out.finalArrivalUtc = (arrayLen(out.legs) ? out.legs[arrayLen(out.legs)].scheduledArrivalUtc : formatUtc(firstUtc));
            out.finalArrivalLocal = (arrayLen(out.legs) ? out.legs[arrayLen(out.legs)].scheduledArrivalLocal : formatLocal(firstUtc, timezoneVal));
            out.totalElapsedCalendarDurationSeconds = max(0, dateDiff("s", firstUtc, currentUtc));
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="localWallToUtc" access="public" returntype="any" output="false">
        <cfargument name="localDateTime" type="string" required="true">
        <cfargument name="sourceTimezone" type="string" required="true">
        <cfscript>
            var timezoneVal = normalizeTimezone(arguments.sourceTimezone);
            var normalizedLocal = replace(trim(arguments.localDateTime), "T", " ", "one");
            var localDateTimeClass = "";
            var zoneIdClass = "";
            var localValue = "";
            var zoneValue = "";
            var instantValue = "";
            var dateValue = "";
            var utcSql = "";

            if (
                !len(timezoneVal)
                OR !reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$", normalizedLocal)
            ) {
                return "";
            }

            try {
                localDateTimeClass = createObject("java", "java.time.LocalDateTime");
                zoneIdClass = createObject("java", "java.time.ZoneId");
                localValue = localDateTimeClass.parse(replace(normalizedLocal, " ", "T", "one"));
                zoneValue = zoneIdClass.of(timezoneVal);
                instantValue = localValue.atZone(zoneValue).toInstant();
                dateValue = createObject("java", "java.util.Date").from(instantValue);
                utcSql = dateTimeFormat(dateValue, "yyyy-mm-dd HH:nn:ss", "UTC");
                return parseDateTime(utcSql);
            } catch (any conversionError) {
                return "";
            }
        </cfscript>
    </cffunction>

    <cffunction name="formatLocal" access="public" returntype="string" output="false">
        <cfargument name="utcValue" type="any" required="true">
        <cfargument name="targetTimezone" type="string" required="true">
        <cfscript>
            var timezoneVal = normalizeTimezone(arguments.targetTimezone);
            if (!isDate(arguments.utcValue) OR !len(timezoneVal)) return "";
            try {
                return dateTimeFormat(arguments.utcValue, "yyyy-mm-dd HH:nn:ss", timezoneVal);
            } catch (any formatError) {
                return "";
            }
        </cfscript>
    </cffunction>

    <cffunction name="formatUtc" access="public" returntype="string" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            if (!isDate(arguments.value)) return "";
            return dateTimeFormat(arguments.value, "yyyy-mm-dd'T'HH:nn:ss'Z'");
        </cfscript>
    </cffunction>

    <cffunction name="normalizeTimezone" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            var timezoneVal = trim(toString(arguments.value));
            if (!len(timezoneVal)) return "";
            if (uCase(timezoneVal) EQ "US/EASTERN") timezoneVal = "America/New_York";
            if (uCase(timezoneVal) EQ "+00:00") timezoneVal = "UTC";
            try {
                dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss", timezoneVal);
                return timezoneVal;
            } catch (any invalidTimezoneError) {
                return "";
            }
        </cfscript>
    </cffunction>

    <cffunction name="normalizeUtcDate" access="private" returntype="any" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            var normalized = "";
            if (isDate(arguments.value)) return arguments.value;
            normalized = trim(toString(arguments.value));
            normalized = replace(normalized, "T", " ", "one");
            normalized = replace(normalized, "Z", "", "one");
            if (len(normalized) GTE 19) normalized = left(normalized, 19);
            if (isDate(normalized)) return parseDateTime(normalized);
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="readNumber" access="private" returntype="numeric" output="false">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfscript>
            if (!structKeyExists(arguments.source, arguments.key) OR !isNumeric(arguments.source[arguments.key])) return 0;
            return val(arguments.source[arguments.key]);
        </cfscript>
    </cffunction>

    <cffunction name="readString" access="private" returntype="string" output="false">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfscript>
            if (!structKeyExists(arguments.source, arguments.key) OR isNull(arguments.source[arguments.key])) return "";
            return trim(toString(arguments.source[arguments.key]));
        </cfscript>
    </cffunction>

</cfcomponent>
