<cfcomponent output="false">

    <cffunction name="init" access="public" returntype="any" output="false">
        <cfreturn this>
    </cffunction>

    <cffunction name="markCompletionFromFloatPlanCheckin" access="public" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="routeCode" type="string" required="false" default="GREAT_LOOP_CCW">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var out = {
                SUCCESS = true,
                MATCHED = false,
                SEGMENT_ID = 0,
                SCORE = 0,
                MESSAGE = "No segment match found."
            };

            if (arguments.userId LTE 0 OR arguments.floatPlanId LTE 0) {
                out.SUCCESS = false;
                out.MESSAGE = "Invalid userId or floatPlanId.";
                return out;
            }

            var qPlan = queryExecute("
                SELECT departing, returning
                FROM floatplans
                WHERE floatplanId = :planId
                  AND userId = :userId
                LIMIT 1
            ", {
                planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
            }, { datasource = arguments.datasource });

            if (qPlan.recordCount EQ 0) {
                out.SUCCESS = false;
                out.MESSAGE = "Float plan not found for user.";
                return out;
            }

            var departNorm = normalizeNodeName(qPlan.departing[1]);
            var returnNorm = normalizeNodeName(qPlan.returning[1]);
            if (!len(departNorm) OR !len(returnNorm)) {
                out.MESSAGE = "Float plan departure/return names are incomplete.";
                return out;
            }

            var qRoute = queryExecute("
                SELECT id
                FROM loop_routes
                WHERE short_code = :code
                LIMIT 1
            ", {
                code = { value = arguments.routeCode, cfsqltype = "cf_sql_varchar" }
            }, { datasource = arguments.datasource });

            if (qRoute.recordCount EQ 0) {
                out.SUCCESS = false;
                out.MESSAGE = "Route not found: " & arguments.routeCode;
                return out;
            }

            var routeId = qRoute.id[1];
            var qSeg = queryExecute("
                SELECT s.id, s.start_name, s.end_name
                FROM loop_segments s
                INNER JOIN loop_sections sec ON sec.id = s.section_id
                WHERE sec.route_id = :routeId
                ORDER BY sec.order_index ASC, s.order_index ASC
            ", {
                routeId = { value = routeId, cfsqltype = "cf_sql_integer" }
            }, { datasource = arguments.datasource });

            var bestId = 0;
            var bestScore = 0;
            var i = 0;
            var segStart = "";
            var segEnd = "";
            var score = 0;

            for (i = 1; i LTE qSeg.recordCount; i++) {
                segStart = normalizeNodeName(qSeg.start_name[i]);
                segEnd = normalizeNodeName(qSeg.end_name[i]);
                score = matchScore(departNorm, returnNorm, segStart, segEnd);
                if (score GT bestScore) {
                    bestScore = score;
                    bestId = qSeg.id[i];
                }
            }

            if (bestScore LT 85 OR bestId LTE 0) {
                out.MESSAGE = "No confident segment match for this check-in.";
                out.SCORE = bestScore;
                return out;
            }

            queryExecute("
                INSERT INTO user_route_progress (user_id, segment_id, status, completed_at)
                VALUES (:userId, :segmentId, 'COMPLETED', NOW())
                ON DUPLICATE KEY UPDATE
                    status = 'COMPLETED',
                    completed_at = NOW()
            ", {
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                segmentId = { value = bestId, cfsqltype = "cf_sql_integer" }
            }, { datasource = arguments.datasource });

            out.MATCHED = true;
            out.SEGMENT_ID = bestId;
            out.SCORE = bestScore;
            out.MESSAGE = "Segment marked complete from float plan check-in.";
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
