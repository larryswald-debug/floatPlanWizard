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
            var accessGateService = {};
            var tripAccessGate = {};
            var lockedTripAccessGate = {};

            if (arguments.userId LTE 0 OR arguments.floatPlanId LTE 0) {
                out.SUCCESS = false;
                out.MESSAGE = "Invalid userId or floatPlanId.";
                return out;
            }

            accessGateService = getMemberAccessGateService(arguments.datasource);
            tripAccessGate = accessGateService.requireTripOperationalAccess(
                arguments.userId,
                arguments.floatPlanId
            );
            if (!structKeyExists(tripAccessGate, "allowed") OR !tripAccessGate.allowed) {
                return applyTripAccessDenial(out, tripAccessGate);
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

                if (planStatus NEQ "ACTIVE") {
                    return applyTripAccessDenial(
                        out,
                        accessGateService.requireTripOperationalAccess(arguments.userId, arguments.floatPlanId)
                    );
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

                transaction {
                    lockedTripAccessGate = accessGateService.requireTripOperationalAccessForUpdate(
                        arguments.userId,
                        arguments.floatPlanId
                    );
                    if (structKeyExists(lockedTripAccessGate, "allowed") AND lockedTripAccessGate.allowed) {
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
                    }
                }
                if (!structKeyExists(lockedTripAccessGate, "allowed") OR !lockedTripAccessGate.allowed) {
                    return applyTripAccessDenial(out, lockedTripAccessGate);
                }

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

            if (planStatusClose NEQ "ACTIVE") {
                return applyTripAccessDenial(
                    out,
                    accessGateService.requireTripOperationalAccess(arguments.userId, arguments.floatPlanId)
                );
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

            transaction {
                lockedTripAccessGate = accessGateService.requireTripOperationalAccessForUpdate(
                    arguments.userId,
                    arguments.floatPlanId
                );
                if (structKeyExists(lockedTripAccessGate, "allowed") AND lockedTripAccessGate.allowed) {
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
                }
            }
            if (!structKeyExists(lockedTripAccessGate, "allowed") OR !lockedTripAccessGate.allowed) {
                return applyTripAccessDenial(out, lockedTripAccessGate);
            }

            out.MATCHED = true;
            out.MESSAGE = "Final leg marked complete from close trip.";
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="finalizeCompletedRouteInstanceForFloatPlan" access="public" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var out = {
                SUCCESS = false,
                FINALIZED = false,
                ALREADY_COMPLETE = false,
                ROUTE_INSTANCE_ID = 0,
                STATUS = "",
                COMPLETED_AT = "",
                EXPECTED_LEG_COUNT = 0,
                COMPLETED_LEG_COUNT = 0,
                ACTIVE_LEG_COUNT = 0,
                ERROR = "",
                MESSAGE = "Unable to finalize the route instance."
            };
            var qBinding = queryNew("");
            var qProgressSummary = queryNew("");
            var qFinalLeg = queryNew("");
            var qConcurrentState = queryNew("");
            var routeInstanceId = 0;
            var routeInstanceStatus = "";
            var routeInstanceCompletedAt = "";
            var finalLegStatus = "";
            var finalLegCompletedAt = "";
            var updateResult = {};

            if (arguments.userId LTE 0 OR arguments.floatPlanId LTE 0) {
                out.ERROR = "INVALID_ARGUMENTS";
                out.MESSAGE = "Invalid userId or floatPlanId.";
                return out;
            }

            qBinding = queryExecute(
                "SELECT
                    fp.route_instance_id,
                    UPPER(TRIM(fp.status)) AS float_plan_status,
                    UPPER(TRIM(ri.status)) AS route_instance_status,
                    ri.completed_at
                 FROM floatplans fp
                 INNER JOIN route_instances ri
                    ON ri.id = fp.route_instance_id
                   AND TRIM(CAST(ri.user_id AS CHAR)) = CAST(:userId AS CHAR)
                 WHERE fp.floatPlanId = :floatPlanId
                   AND fp.userId = :userId
                 LIMIT 1
                 FOR UPDATE",
                {
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                    floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = arguments.datasource }
            );

            if (qBinding.recordCount NEQ 1) {
                out.ERROR = "ROUTE_INSTANCE_BINDING_INVALID";
                out.MESSAGE = "The operational route instance is not bound to this float plan and user.";
                return out;
            }

            routeInstanceId = val(qBinding.route_instance_id[1]);
            routeInstanceStatus = uCase(trim(toString(qBinding.route_instance_status[1])));
            routeInstanceCompletedAt = (
                isNull(qBinding.completed_at[1])
                    ? ""
                    : qBinding.completed_at[1]
            );
            out.ROUTE_INSTANCE_ID = routeInstanceId;
            out.STATUS = routeInstanceStatus;
            out.COMPLETED_AT = routeInstanceCompletedAt;

            if (uCase(trim(toString(qBinding.float_plan_status[1]))) NEQ "ACTIVE") {
                out.ERROR = "FLOAT_PLAN_NOT_ACTIVE";
                out.MESSAGE = "Only an active float plan can finalize its route instance.";
                return out;
            }

            qProgressSummary = queryExecute(
                "SELECT
                    COUNT(ril.id) AS expected_leg_count,
                    COALESCE(SUM(
                        CASE
                            WHEN UPPER(TRIM(COALESCE(rilp.status, 'NOT_STARTED'))) = 'COMPLETED'
                            THEN 1 ELSE 0
                        END
                    ), 0) AS completed_leg_count,
                    COALESCE(SUM(
                        CASE
                            WHEN UPPER(TRIM(COALESCE(rilp.status, 'NOT_STARTED'))) IN ('STARTED','IN_PROGRESS')
                              OR (
                                rilp.leg_started_at IS NOT NULL
                                AND UPPER(TRIM(COALESCE(rilp.status, 'NOT_STARTED'))) <> 'COMPLETED'
                              )
                            THEN 1 ELSE 0
                        END
                    ), 0) AS active_leg_count
                 FROM route_instance_legs ril
                 LEFT JOIN route_instance_leg_progress rilp
                    ON rilp.route_instance_id = ril.route_instance_id
                   AND rilp.leg_order = ril.leg_order
                   AND rilp.user_id = :userId
                 WHERE ril.route_instance_id = :routeInstanceId",
                {
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                    routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = arguments.datasource }
            );

            out.EXPECTED_LEG_COUNT = val(qProgressSummary.expected_leg_count[1]);
            out.COMPLETED_LEG_COUNT = val(qProgressSummary.completed_leg_count[1]);
            out.ACTIVE_LEG_COUNT = val(qProgressSummary.active_leg_count[1]);

            if (out.EXPECTED_LEG_COUNT LTE 0) {
                out.ERROR = "ROUTE_LEGS_MISSING";
                out.MESSAGE = "The operational route has no expected legs to finalize.";
                return out;
            }
            if (
                out.COMPLETED_LEG_COUNT NEQ out.EXPECTED_LEG_COUNT
                OR out.ACTIVE_LEG_COUNT GT 0
            ) {
                out.ERROR = "ROUTE_PROGRESS_INCOMPLETE";
                out.MESSAGE = "All expected route legs must be complete before the route instance can be finalized.";
                return out;
            }

            qFinalLeg = queryExecute(
                "SELECT
                    ril.leg_order,
                    UPPER(TRIM(COALESCE(rilp.status, 'NOT_STARTED'))) AS progress_status,
                    rilp.completed_at
                 FROM route_instance_legs ril
                 LEFT JOIN route_instance_leg_progress rilp
                    ON rilp.route_instance_id = ril.route_instance_id
                   AND rilp.leg_order = ril.leg_order
                   AND rilp.user_id = :userId
                 WHERE ril.route_instance_id = :routeInstanceId
                 ORDER BY ril.leg_order DESC, ril.id DESC
                 LIMIT 1",
                {
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                    routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = arguments.datasource }
            );

            finalLegStatus = (
                qFinalLeg.recordCount EQ 1
                    ? uCase(trim(toString(qFinalLeg.progress_status[1])))
                    : ""
            );
            finalLegCompletedAt = (
                qFinalLeg.recordCount EQ 1 AND !isNull(qFinalLeg.completed_at[1])
                    ? qFinalLeg.completed_at[1]
                    : ""
            );
            if (
                finalLegStatus NEQ "COMPLETED"
                OR !isDate(finalLegCompletedAt)
            ) {
                out.ERROR = "ROUTE_COMPLETION_TIMESTAMP_MISSING";
                out.MESSAGE = "The final route leg does not have a canonical completion timestamp.";
                return out;
            }

            if (routeInstanceStatus EQ "COMPLETED") {
                if (!isDate(routeInstanceCompletedAt)) {
                    out.ERROR = "ROUTE_INSTANCE_COMPLETION_INCONSISTENT";
                    out.MESSAGE = "The route instance is completed but has no completion timestamp.";
                    return out;
                }
                out.SUCCESS = true;
                out.ALREADY_COMPLETE = true;
                out.MESSAGE = "Route instance is already completed.";
                return out;
            }

            if (routeInstanceStatus NEQ "ACTIVE") {
                out.ERROR = "ROUTE_INSTANCE_NOT_ACTIVE";
                out.MESSAGE = "Only an active route instance can be finalized.";
                return out;
            }
            if (isDate(routeInstanceCompletedAt)) {
                out.ERROR = "ROUTE_INSTANCE_COMPLETION_INCONSISTENT";
                out.MESSAGE = "The active route instance already has a completion timestamp.";
                return out;
            }

            queryExecute(
                "UPDATE route_instances
                 SET
                    status = 'COMPLETED',
                    completed_at = :completedAt,
                    updated_at = UTC_TIMESTAMP()
                 WHERE id = :routeInstanceId
                   AND TRIM(CAST(user_id AS CHAR)) = CAST(:userId AS CHAR)
                   AND UPPER(TRIM(status)) = 'ACTIVE'
                   AND completed_at IS NULL",
                {
                    completedAt = { value = finalLegCompletedAt, cfsqltype = "cf_sql_timestamp" },
                    routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = arguments.datasource, result = "local.updateResult" }
            );

            if (!structKeyExists(updateResult, "recordCount") OR val(updateResult.recordCount) NEQ 1) {
                qConcurrentState = queryExecute(
                    "SELECT UPPER(TRIM(status)) AS status_value, completed_at
                     FROM route_instances
                     WHERE id = :routeInstanceId
                       AND TRIM(CAST(user_id AS CHAR)) = CAST(:userId AS CHAR)
                     LIMIT 1
                     FOR UPDATE",
                    {
                        routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer" },
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = arguments.datasource }
                );
                if (
                    qConcurrentState.recordCount EQ 1
                    AND uCase(trim(toString(qConcurrentState.status_value[1]))) EQ "COMPLETED"
                    AND !isNull(qConcurrentState.completed_at[1])
                    AND isDate(qConcurrentState.completed_at[1])
                ) {
                    out.SUCCESS = true;
                    out.ALREADY_COMPLETE = true;
                    out.STATUS = "COMPLETED";
                    out.COMPLETED_AT = qConcurrentState.completed_at[1];
                    out.MESSAGE = "Route instance is already completed.";
                    return out;
                }
                out.ERROR = "ROUTE_INSTANCE_FINALIZATION_CONFLICT";
                out.MESSAGE = "The route instance changed before completion could be recorded.";
                return out;
            }

            out.SUCCESS = true;
            out.FINALIZED = true;
            out.STATUS = "COMPLETED";
            out.COMPLETED_AT = finalLegCompletedAt;
            out.MESSAGE = "Route instance finalized from completed route progress.";
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
            var accessGateService = {};
            var tripAccessGate = {};
            var lockedTripAccessGate = {};

            if (arguments.userId LTE 0 OR arguments.floatPlanId LTE 0) {
                out.ERROR = "INVALID_ARGUMENTS";
                out.MESSAGE = "Invalid userId or floatPlanId.";
                return out;
            }

            accessGateService = getMemberAccessGateService(arguments.datasource);
            tripAccessGate = accessGateService.requireTripOperationalAccess(
                arguments.userId,
                arguments.floatPlanId
            );
            if (!structKeyExists(tripAccessGate, "allowed") OR !tripAccessGate.allowed) {
                return applyTripAccessDenial(out, tripAccessGate);
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

            if (planStatus NEQ "ACTIVE") {
                return applyTripAccessDenial(
                    out,
                    accessGateService.requireTripOperationalAccess(arguments.userId, arguments.floatPlanId)
                );
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

            transaction {
                lockedTripAccessGate = accessGateService.requireTripOperationalAccessForUpdate(
                    arguments.userId,
                    arguments.floatPlanId
                );
                if (structKeyExists(lockedTripAccessGate, "allowed") AND lockedTripAccessGate.allowed) {
                    queryExecute("
                        INSERT INTO route_instance_leg_progress (user_id, route_instance_id, leg_order, status, leg_started_at)
                        VALUES (:userId, :routeInstanceId, :legOrder, 'STARTED', NOW())
                        ON DUPLICATE KEY UPDATE
                            status = 'STARTED',
                            leg_started_at = VALUES(leg_started_at),
                            completed_at = NULL
                    ", {
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                        routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer" },
                        legOrder = { value = pendingLegOrder, cfsqltype = "cf_sql_integer" }
                    }, { datasource = arguments.datasource });
                }
            }
            if (!structKeyExists(lockedTripAccessGate, "allowed") OR !lockedTripAccessGate.allowed) {
                return applyTripAccessDenial(out, lockedTripAccessGate);
            }

            out.SUCCESS = true;
            out.STARTED = true;
            out.LEG_ORDER = pendingLegOrder;
            out.MESSAGE = "Next pending leg started.";
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getMemberAccessGateService" access="private" returntype="any" output="false">
        <cfargument name="datasource" type="string" required="true">
        <cfscript>
            try {
                return createObject("component", "fpw.api.v1.MemberAccessGateService").init(arguments.datasource);
            } catch (any primaryPathError) {
                return createObject("component", "api.v1.MemberAccessGateService").init(arguments.datasource);
            }
        </cfscript>
    </cffunction>

    <cffunction name="applyTripAccessDenial" access="private" returntype="struct" output="false">
        <cfargument name="result" type="struct" required="true">
        <cfargument name="gateResult" type="struct" required="true">
        <cfscript>
            arguments.result.SUCCESS = false;
            if (structKeyExists(arguments.gateResult, "allowed") AND arguments.gateResult.allowed) {
                arguments.result.ERROR = "TRIP_NOT_ACTIVE";
                arguments.result.MESSAGE = "This float plan is not active.";
                return arguments.result;
            }
            arguments.result.ERROR = arguments.gateResult.response.ERROR.CODE;
            arguments.result.MESSAGE = arguments.gateResult.response.MESSAGE;
            if (structKeyExists(arguments.gateResult, "tripAccess")) {
                arguments.result.tripAccess = arguments.gateResult.tripAccess;
            }
            return arguments.result;
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
