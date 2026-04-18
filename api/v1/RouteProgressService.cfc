<cfcomponent output="false">

    <cffunction name="init" access="public" returntype="any" output="false">
        <cfreturn this>
    </cffunction>

    <cffunction name="markCompletionFromFloatPlanCheckin" access="public" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="routeCode" type="string" required="false" default="GREAT_LOOP_CCW">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfargument name="completionMode" type="string" required="false" default="checkin_match">
        <cfargument name="expectedLegOrder" type="numeric" required="false" default="0">
        <cfscript>
            var out = {
                SUCCESS = true,
                MATCHED = false,
                SEGMENT_ID = 0,
                SCORE = 0,
                MESSAGE = "No segment match found."
            };
            var modeVal = lCase(trim(arguments.completionMode));

            if (arguments.userId LTE 0 OR arguments.floatPlanId LTE 0) {
                out.SUCCESS = false;
                out.MESSAGE = "Invalid userId or floatPlanId.";
                return out;
            }

            if (modeVal EQ "active_leg") {
                out.LEG_ORDER = 0;
                out.ROUTE_INSTANCE_ID = 0;
                out.COMPLETED = false;
                out.ALREADY_COMPLETE = false;

                var qPlanActive = queryExecute("
                    SELECT route_instance_id, status
                    FROM floatplans
                    WHERE floatplanId = :planId
                      AND userId = :userId
                    LIMIT 1
                ", {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                }, { datasource = arguments.datasource });

                if (qPlanActive.recordCount EQ 0) {
                    out.SUCCESS = false;
                    out.ERROR = "NOT_FOUND";
                    out.MESSAGE = "Float plan not found for user.";
                    return out;
                }

                var planStatus = uCase(trim(toString(qPlanActive.status[1])));
                var routeInstanceId = val(qPlanActive.route_instance_id[1]);
                out.ROUTE_INSTANCE_ID = routeInstanceId;

                if (planStatus EQ "CLOSED") {
                    out.SUCCESS = false;
                    out.ERROR = "TRIP_CLOSED";
                    out.MESSAGE = "Trip is already closed.";
                    return out;
                }

                if (routeInstanceId LTE 0) {
                    out.SUCCESS = false;
                    out.ERROR = "NO_ROUTE_INSTANCE";
                    out.MESSAGE = "No route instance attached to this float plan.";
                    return out;
                }

                var qLegs = queryExecute("
                    SELECT leg_order
                    FROM route_instance_legs
                    WHERE route_instance_id = :routeInstanceId
                    ORDER BY leg_order ASC, id ASC
                ", {
                    routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer" }
                }, { datasource = arguments.datasource });

                if (qLegs.recordCount EQ 0) {
                    out.SUCCESS = false;
                    out.ERROR = "NO_ACTIVE_LEG";
                    out.MESSAGE = "No active leg could be resolved for this route instance.";
                    return out;
                }

                var qProgress = queryExecute("
                    SELECT leg_order, status, leg_started_at
                    FROM route_instance_leg_progress
                    WHERE route_instance_id = :routeInstanceId
                      AND user_id = :userId
                    ORDER BY leg_order ASC
                ", {
                    routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                }, { datasource = arguments.datasource });

                var highestCompletedLegOrder = 0;
                var i = 0;
                var legOrder = 0;
                var legStatus = "";
                var legStartedAt = "";
                var activeLegOrder = 0;
                var finalLegOrder = 0;
                var progressStatusByLeg = {};
                var progressStartedByLeg = {};

                for (i = 1; i LTE qProgress.recordCount; i++) {
                    legOrder = val(qProgress.leg_order[i]);
                    legStatus = uCase(trim(toString(qProgress.status[i])));
                    legStartedAt = (isNull(qProgress.leg_started_at[i]) ? "" : qProgress.leg_started_at[i]);
                    progressStatusByLeg[toString(legOrder)] = legStatus;
                    if (isDate(legStartedAt)) {
                        progressStartedByLeg[toString(legOrder)] = legStartedAt;
                    }
                    if (legStatus EQ "COMPLETED" AND legOrder GT highestCompletedLegOrder) {
                        highestCompletedLegOrder = legOrder;
                    }
                }

                if (qLegs.recordCount GT 0) {
                    finalLegOrder = val(qLegs.leg_order[qLegs.recordCount]);
                }

                for (i = 1; i LTE qLegs.recordCount; i++) {
                    legOrder = val(qLegs.leg_order[i]);
                    legStatus = (structKeyExists(progressStatusByLeg, toString(legOrder)) ? progressStatusByLeg[toString(legOrder)] : "NOT_STARTED");
                    if (
                        legOrder GT highestCompletedLegOrder
                        AND (
                            structKeyExists(progressStartedByLeg, toString(legOrder))
                            OR legStatus EQ "STARTED"
                            OR legStatus EQ "IN_PROGRESS"
                        )
                    ) {
                        activeLegOrder = legOrder;
                        break;
                    }
                }

                if (arguments.expectedLegOrder GT 0) {
                    if (activeLegOrder GT 0 AND activeLegOrder NEQ arguments.expectedLegOrder) {
                        if (highestCompletedLegOrder GTE arguments.expectedLegOrder) {
                            out.ALREADY_COMPLETE = true;
                            out.LEG_ORDER = arguments.expectedLegOrder;
                            out.MESSAGE = "This leg is already completed.";
                            return out;
                        }
                        out.SUCCESS = false;
                        out.ERROR = "ACTIVE_LEG_MISMATCH";
                        out.LEG_ORDER = activeLegOrder;
                        out.MESSAGE = "Active leg changed. Reload and try again.";
                        return out;
                    }
                    if (activeLegOrder LTE 0 AND highestCompletedLegOrder GTE arguments.expectedLegOrder) {
                        out.ALREADY_COMPLETE = true;
                        out.LEG_ORDER = arguments.expectedLegOrder;
                        out.MESSAGE = "All legs are already completed.";
                        return out;
                    }
                }

                if (activeLegOrder LTE 0) {
                    if (finalLegOrder GT 0 AND highestCompletedLegOrder GTE finalLegOrder) {
                        out.ALREADY_COMPLETE = true;
                        out.MESSAGE = "All legs are already completed.";
                        return out;
                    }
                    out.SUCCESS = false;
                    out.ERROR = "LEG_NOT_STARTED";
                    out.MESSAGE = "No started leg is available to complete.";
                    return out;
                }

                queryExecute("
                    INSERT INTO route_instance_leg_progress (user_id, route_instance_id, leg_order, status, completed_at)
                    VALUES (:userId, :routeInstanceId, :legOrder, 'COMPLETED', NOW())
                    ON DUPLICATE KEY UPDATE
                        status = 'COMPLETED',
                        completed_at = NOW()
                ", {
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                    routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer" },
                    legOrder = { value = activeLegOrder, cfsqltype = "cf_sql_integer" }
                }, { datasource = arguments.datasource });

                out.MATCHED = true;
                out.COMPLETED = true;
                out.LEG_ORDER = activeLegOrder;
                out.MESSAGE = "Current leg marked complete.";
                return out;
            }

            var qPlanClose = queryExecute("
                SELECT route_instance_id, status
                FROM floatplans
                WHERE floatplanId = :planId
                  AND userId = :userId
                LIMIT 1
            ", {
                planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
            }, { datasource = arguments.datasource });

            if (qPlanClose.recordCount EQ 0) {
                out.SUCCESS = false;
                out.MESSAGE = "Float plan not found for user.";
                return out;
            }

            var planStatusClose = uCase(trim(toString(qPlanClose.status[1])));
            var routeInstanceIdClose = val(qPlanClose.route_instance_id[1]);
            var qLegsClose = queryNew("");
            var qProgressClose = queryNew("");
            var finalLegOrder = 0;
            var highestCompletedLegOrderClose = 0;
            var activeLegOrderClose = 0;
            var closeLegOrder = 0;
            var closeLegStatus = "";
            var closeLegStartedAt = "";
            var i = 0;
            var progressStatusByLegClose = {};
            var progressStartedByLegClose = {};

            if (planStatusClose EQ "CLOSED") {
                out.MESSAGE = "Trip already closed.";
                return out;
            }

            if (routeInstanceIdClose LTE 0) {
                out.MESSAGE = "No route attached; closure may proceed.";
                return out;
            }

            qLegsClose = queryExecute("
                SELECT leg_order
                FROM route_instance_legs
                WHERE route_instance_id = :routeInstanceId
                ORDER BY leg_order ASC, id ASC
            ", {
                routeInstanceId = { value = routeInstanceIdClose, cfsqltype = "cf_sql_integer" }
            }, { datasource = arguments.datasource });

            if (qLegsClose.recordCount EQ 0) {
                out.MESSAGE = "No route legs found; closure may proceed.";
                return out;
            }

            finalLegOrder = val(qLegsClose.leg_order[qLegsClose.recordCount]);

            qProgressClose = queryExecute("
                SELECT leg_order, status, leg_started_at
                FROM route_instance_leg_progress
                WHERE route_instance_id = :routeInstanceId
                  AND user_id = :userId
                ORDER BY leg_order ASC
            ", {
                routeInstanceId = { value = routeInstanceIdClose, cfsqltype = "cf_sql_integer" },
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
            }, { datasource = arguments.datasource });

            for (i = 1; i LTE qProgressClose.recordCount; i++) {
                closeLegOrder = val(qProgressClose.leg_order[i]);
                closeLegStatus = uCase(trim(toString(qProgressClose.status[i])));
                closeLegStartedAt = (isNull(qProgressClose.leg_started_at[i]) ? "" : qProgressClose.leg_started_at[i]);
                progressStatusByLegClose[toString(closeLegOrder)] = closeLegStatus;
                if (isDate(closeLegStartedAt)) {
                    progressStartedByLegClose[toString(closeLegOrder)] = closeLegStartedAt;
                }
                if (closeLegStatus EQ "COMPLETED" AND closeLegOrder GT highestCompletedLegOrderClose) {
                    highestCompletedLegOrderClose = closeLegOrder;
                }
            }

            if (highestCompletedLegOrderClose GTE finalLegOrder AND finalLegOrder GT 0) {
                out.MESSAGE = "Final leg already completed.";
                return out;
            }

            for (i = 1; i LTE qLegsClose.recordCount; i++) {
                closeLegOrder = val(qLegsClose.leg_order[i]);
                closeLegStatus = (structKeyExists(progressStatusByLegClose, toString(closeLegOrder)) ? progressStatusByLegClose[toString(closeLegOrder)] : "NOT_STARTED");
                if (
                    closeLegOrder GT highestCompletedLegOrderClose
                    AND (
                        structKeyExists(progressStartedByLegClose, toString(closeLegOrder))
                        OR closeLegStatus EQ "STARTED"
                        OR closeLegStatus EQ "IN_PROGRESS"
                    )
                ) {
                    activeLegOrderClose = closeLegOrder;
                    break;
                }
            }

            if (activeLegOrderClose LTE 0) {
                out.SUCCESS = false;
                out.MESSAGE = "Close Trip is only available once the final leg is active.";
                return out;
            }

            if (activeLegOrderClose NEQ finalLegOrder) {
                out.SUCCESS = false;
                out.MESSAGE = "Close Trip is only available once the final leg is active.";
                return out;
            }

            queryExecute("
                INSERT INTO route_instance_leg_progress (user_id, route_instance_id, leg_order, status, completed_at)
                VALUES (:userId, :routeInstanceId, :legOrder, 'COMPLETED', NOW())
                ON DUPLICATE KEY UPDATE
                    status = 'COMPLETED',
                    completed_at = NOW()
            ", {
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                routeInstanceId = { value = routeInstanceIdClose, cfsqltype = "cf_sql_integer" },
                legOrder = { value = activeLegOrderClose, cfsqltype = "cf_sql_integer" }
            }, { datasource = arguments.datasource });

            out.MATCHED = true;
            out.MESSAGE = "Final leg marked complete from close trip.";
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="startNextPendingLegForFloatPlan" access="public" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var out = {
                SUCCESS = false,
                STARTED = false,
                LEG_ORDER = 0,
                ROUTE_INSTANCE_ID = 0,
                ERROR = "",
                MESSAGE = "Unable to start the next leg."
            };
            var qPlan = queryNew("");
            var qLegs = queryNew("");
            var qProgress = queryNew("");
            var planStatus = "";
            var routeInstanceId = 0;
            var highestCompletedLegOrder = 0;
            var activeLegOrder = 0;
            var pendingLegOrder = 0;
            var finalLegOrder = 0;
            var progressStatusByLeg = {};
            var progressStartedByLeg = {};
            var i = 0;
            var legOrder = 0;
            var legStatus = "";
            var legStartedAt = "";

            if (arguments.userId LTE 0 OR arguments.floatPlanId LTE 0) {
                out.ERROR = "INVALID_ARGUMENTS";
                out.MESSAGE = "Invalid userId or floatPlanId.";
                return out;
            }

            qPlan = queryExecute("
                SELECT route_instance_id, status
                FROM floatplans
                WHERE floatplanId = :planId
                  AND userId = :userId
                LIMIT 1
            ", {
                planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
            }, { datasource = arguments.datasource });

            if (qPlan.recordCount EQ 0) {
                out.ERROR = "NOT_FOUND";
                out.MESSAGE = "Float plan not found for user.";
                return out;
            }

            planStatus = uCase(trim(toString(qPlan.status[1])));
            routeInstanceId = val(qPlan.route_instance_id[1]);
            out.ROUTE_INSTANCE_ID = routeInstanceId;

            if (planStatus EQ "CLOSED") {
                out.ERROR = "TRIP_CLOSED";
                out.MESSAGE = "Trip is already closed.";
                return out;
            }

            if (routeInstanceId LTE 0) {
                out.ERROR = "NO_ROUTE_INSTANCE";
                out.MESSAGE = "No route instance attached to this float plan.";
                return out;
            }

            qLegs = queryExecute("
                SELECT leg_order
                FROM route_instance_legs
                WHERE route_instance_id = :routeInstanceId
                ORDER BY leg_order ASC, id ASC
            ", {
                routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer" }
            }, { datasource = arguments.datasource });

            if (qLegs.recordCount EQ 0) {
                out.ERROR = "NO_PENDING_LEG";
                out.MESSAGE = "No pending leg could be resolved for this route instance.";
                return out;
            }

            qProgress = queryExecute("
                SELECT leg_order, status, leg_started_at
                FROM route_instance_leg_progress
                WHERE route_instance_id = :routeInstanceId
                  AND user_id = :userId
                ORDER BY leg_order ASC
            ", {
                routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer" },
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
            }, { datasource = arguments.datasource });

            for (i = 1; i LTE qProgress.recordCount; i++) {
                legOrder = val(qProgress.leg_order[i]);
                legStatus = uCase(trim(toString(qProgress.status[i])));
                legStartedAt = (isNull(qProgress.leg_started_at[i]) ? "" : qProgress.leg_started_at[i]);
                progressStatusByLeg[toString(legOrder)] = legStatus;
                if (isDate(legStartedAt)) {
                    progressStartedByLeg[toString(legOrder)] = legStartedAt;
                }
                if (legStatus EQ "COMPLETED" AND legOrder GT highestCompletedLegOrder) {
                    highestCompletedLegOrder = legOrder;
                }
            }

            if (qLegs.recordCount GT 0) {
                finalLegOrder = val(qLegs.leg_order[qLegs.recordCount]);
            }

            for (i = 1; i LTE qLegs.recordCount; i++) {
                legOrder = val(qLegs.leg_order[i]);
                legStatus = (structKeyExists(progressStatusByLeg, toString(legOrder)) ? progressStatusByLeg[toString(legOrder)] : "NOT_STARTED");
                if (
                    legOrder GT highestCompletedLegOrder
                    AND (
                        structKeyExists(progressStartedByLeg, toString(legOrder))
                        OR legStatus EQ "STARTED"
                        OR legStatus EQ "IN_PROGRESS"
                    )
                ) {
                    activeLegOrder = legOrder;
                    break;
                }
            }

            if (activeLegOrder GT 0) {
                out.ERROR = "LEG_ALREADY_ACTIVE";
                out.LEG_ORDER = activeLegOrder;
                out.MESSAGE = "A leg is already underway.";
                return out;
            }

            if (finalLegOrder GT 0 AND highestCompletedLegOrder GTE finalLegOrder) {
                out.ERROR = "NO_PENDING_LEG";
                out.MESSAGE = "All legs are already completed.";
                return out;
            }

            if (highestCompletedLegOrder LTE 0) {
                out.ERROR = "TRIP_NOT_AWAITING_DEPARTURE";
                out.MESSAGE = "Trip is not awaiting departure for the next leg.";
                return out;
            }

            for (i = 1; i LTE qLegs.recordCount; i++) {
                legOrder = val(qLegs.leg_order[i]);
                if (legOrder GT highestCompletedLegOrder) {
                    pendingLegOrder = legOrder;
                    break;
                }
            }

            if (pendingLegOrder LTE 0) {
                out.ERROR = "NO_PENDING_LEG";
                out.MESSAGE = "No pending leg is available to start.";
                return out;
            }

            queryExecute("
                INSERT INTO route_instance_leg_progress (user_id, route_instance_id, leg_order, leg_started_at)
                VALUES (:userId, :routeInstanceId, :legOrder, NOW())
                ON DUPLICATE KEY UPDATE
                    leg_started_at = COALESCE(route_instance_leg_progress.leg_started_at, VALUES(leg_started_at))
            ", {
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer" },
                legOrder = { value = pendingLegOrder, cfsqltype = "cf_sql_integer" }
            }, { datasource = arguments.datasource });

            out.SUCCESS = true;
            out.STARTED = true;
            out.LEG_ORDER = pendingLegOrder;
            out.MESSAGE = "Next pending leg started.";
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="matchScore" access="private" returntype="numeric" output="false">
        <cfargument name="dep" type="string" required="true">
        <cfargument name="ret" type="string" required="true">
        <cfargument name="segStart" type="string" required="true">
        <cfargument name="segEnd" type="string" required="true">
        <cfscript>
            if (!len(arguments.dep) OR !len(arguments.ret) OR !len(arguments.segStart) OR !len(arguments.segEnd)) {
                return 0;
            }
            if (arguments.dep EQ arguments.segStart AND arguments.ret EQ arguments.segEnd) {
                return 100;
            }
            if (
                (
                    findNoCase(arguments.dep, arguments.segStart) GT 0
                    OR findNoCase(arguments.segStart, arguments.dep) GT 0
                )
                AND
                (
                    findNoCase(arguments.ret, arguments.segEnd) GT 0
                    OR findNoCase(arguments.segEnd, arguments.ret) GT 0
                )
            ) {
                return 85;
            }
            return 0;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeNodeName" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            var s = lCase(trim(toString(arguments.value)));
            if (!len(s)) {
                return "";
            }
            s = reReplace(s, "\bst[.]?\b", "saint", "all");
            s = reReplace(s, "\bmt[.]?\b", "mount", "all");
            s = reReplace(s, "[^a-z0-9]+", " ", "all");
            s = reReplace(s, "\s+", " ", "all");
            return trim(s);
        </cfscript>
    </cffunction>

</cfcomponent>

