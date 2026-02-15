<cfcomponent output="false">

    <cffunction name="buildCoverageReport" access="public" returntype="struct" output="false">
        <cfargument name="routeCode" type="string" required="false" default="GREAT_LOOP_CCW">
        <cfscript>
            var out = {
                "SUCCESS"=true,
                "ROUTE_CODE"=trim(arguments.routeCode),
                "TOTAL_SEGMENTS"=0,
                "FULLY_MATCHED_SEGMENTS"=0,
                "PARTIAL_SEGMENTS"=0,
                "UNMATCHED_SEGMENTS"=0,
                "UNMATCHED_POINTS"=[]
            };
            var qRoute = queryExecute(
                "SELECT id
                 FROM loop_routes
                 WHERE short_code = :code
                 LIMIT 1",
                { code = { value=out.ROUTE_CODE, cfsqltype="cf_sql_varchar" } },
                { datasource = application.dsn }
            );
            if (qRoute.recordCount EQ 0) {
                out.SUCCESS = false;
                out.MESSAGE = "Route not found";
                return out;
            }

            var qSeg = queryExecute(
                "SELECT s.id, s.start_name, s.end_name, sec.name AS section_name
                 FROM loop_segments s
                 INNER JOIN loop_sections sec ON sec.id = s.section_id
                 WHERE sec.route_id = :rid
                 ORDER BY sec.order_index ASC, s.order_index ASC",
                { rid = { value=qRoute.id[1], cfsqltype="cf_sql_integer" } },
                { datasource = application.dsn }
            );

            var i = 0;
            var startMatch = {};
            var endMatch = {};
            var waterwayCode = "";
            for (i = 1; i LTE qSeg.recordCount; i++) {
                out.TOTAL_SEGMENTS += 1;
                waterwayCode = inferWaterwayCode(qSeg.section_name[i], qSeg.start_name[i], qSeg.end_name[i]);
                startMatch = resolveLocationRM(waterwayCode, qSeg.start_name[i]);
                endMatch = resolveLocationRM(waterwayCode, qSeg.end_name[i]);

                if (startMatch.FOUND AND endMatch.FOUND) {
                    out.FULLY_MATCHED_SEGMENTS += 1;
                } else if (startMatch.FOUND OR endMatch.FOUND) {
                    out.PARTIAL_SEGMENTS += 1;
                } else {
                    out.UNMATCHED_SEGMENTS += 1;
                }

                if (NOT startMatch.FOUND) {
                    arrayAppend(out.UNMATCHED_POINTS, {
                        "SEGMENT_ID"=qSeg.id[i],
                        "SECTION_NAME"=(isNull(qSeg.section_name[i]) ? "" : qSeg.section_name[i]),
                        "POINT_TYPE"="START",
                        "LOCATION_NAME"=(isNull(qSeg.start_name[i]) ? "" : qSeg.start_name[i]),
                        "WATERWAY_CODE"=waterwayCode
                    });
                }
                if (NOT endMatch.FOUND) {
                    arrayAppend(out.UNMATCHED_POINTS, {
                        "SEGMENT_ID"=qSeg.id[i],
                        "SECTION_NAME"=(isNull(qSeg.section_name[i]) ? "" : qSeg.section_name[i]),
                        "POINT_TYPE"="END",
                        "LOCATION_NAME"=(isNull(qSeg.end_name[i]) ? "" : qSeg.end_name[i]),
                        "WATERWAY_CODE"=waterwayCode
                    });
                }
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="resolveSegmentRM" access="public" returntype="struct" output="false">
        <cfargument name="sectionName" type="string" required="false" default="">
        <cfargument name="startName" type="string" required="false" default="">
        <cfargument name="endName" type="string" required="false" default="">
        <cfscript>
            var out = {
                "WATERWAY_CODE"="",
                "START_FOUND"=false,
                "END_FOUND"=false,
                "RM_START"="",
                "RM_END"="",
                "AUTOFILLED"=false,
                "CONFIDENCE"="none"
            };
            var waterwayCode = inferWaterwayCode(arguments.sectionName, arguments.startName, arguments.endName);
            if (!len(waterwayCode)) {
                return out;
            }
            out.WATERWAY_CODE = waterwayCode;

            var startMatch = resolveLocationRM(waterwayCode, arguments.startName);
            var endMatch = resolveLocationRM(waterwayCode, arguments.endName);
            if (startMatch.FOUND) {
                out.START_FOUND = true;
                out.RM_START = startMatch.RM_VALUE;
            }
            if (endMatch.FOUND) {
                out.END_FOUND = true;
                out.RM_END = endMatch.RM_VALUE;
            }
            out.AUTOFILLED = (out.START_FOUND AND out.END_FOUND);
            if (out.AUTOFILLED) {
                out.CONFIDENCE = "high";
            } else if (out.START_FOUND OR out.END_FOUND) {
                out.CONFIDENCE = "partial";
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="resolveLocationRM" access="public" returntype="struct" output="false">
        <cfargument name="waterwayCode" type="string" required="true">
        <cfargument name="locationName" type="string" required="true">
        <cfscript>
            var out = { "FOUND"=false, "RM_VALUE"="", "MATCH_TYPE"="" };
            var needle = normalizeName(arguments.locationName);
            if (!len(arguments.waterwayCode) OR !len(needle)) {
                return out;
            }

            var qPoints = queryExecute(
                "SELECT location_name, alias_name, rm_value
                 FROM waterway_milepoints
                 WHERE waterway_code = :code
                   AND is_active = 1",
                { code = { value=arguments.waterwayCode, cfsqltype="cf_sql_varchar" } },
                { datasource = application.dsn }
            );

            var i = 0;
            var locNorm = "";
            var aliasNorm = "";
            for (i = 1; i LTE qPoints.recordCount; i++) {
                locNorm = normalizeName(qPoints.location_name[i]);
                aliasNorm = normalizeName(qPoints.alias_name[i]);
                if (needle EQ locNorm) {
                    out.FOUND = true;
                    out.RM_VALUE = val(qPoints.rm_value[i]);
                    out.MATCH_TYPE = "exact";
                    return out;
                }
                if (len(aliasNorm) AND needle EQ aliasNorm) {
                    out.FOUND = true;
                    out.RM_VALUE = val(qPoints.rm_value[i]);
                    out.MATCH_TYPE = "alias";
                    return out;
                }
            }
            for (i = 1; i LTE qPoints.recordCount; i++) {
                locNorm = normalizeName(qPoints.location_name[i]);
                aliasNorm = normalizeName(qPoints.alias_name[i]);
                if ((len(locNorm) AND (findNoCase(needle, locNorm) GT 0 OR findNoCase(locNorm, needle) GT 0))
                    OR (len(aliasNorm) AND (findNoCase(needle, aliasNorm) GT 0 OR findNoCase(aliasNorm, needle) GT 0))) {
                    out.FOUND = true;
                    out.RM_VALUE = val(qPoints.rm_value[i]);
                    out.MATCH_TYPE = "fuzzy";
                    return out;
                }
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="inferWaterwayCode" access="public" returntype="string" output="false">
        <cfargument name="sectionName" type="string" required="false" default="">
        <cfargument name="startName" type="string" required="false" default="">
        <cfargument name="endName" type="string" required="false" default="">
        <cfscript>
            var sectionNorm = normalizeName(arguments.sectionName);
            var startNorm = normalizeName(arguments.startName);
            var endNorm = normalizeName(arguments.endName);
            var nodeNorm = trim(startNorm & " " & endNorm);

            if (findNoCase("great lakes", sectionNorm)) return "GREAT_LAKES";
            if (findNoCase("trent severn", sectionNorm)) return "TRENT_SEVERN";
            if (findNoCase("st lawrence", sectionNorm) OR findNoCase("saint lawrence", sectionNorm)) return "ST_LAWRENCE";
            if (findNoCase("erie canal", sectionNorm) OR findNoCase("oswego", sectionNorm)) return "ERIE_CANAL";
            if (findNoCase("hudson", sectionNorm)) return "HUDSON";
            if (findNoCase("atlantic", sectionNorm) AND findNoCase("icw", sectionNorm)) return "ATLANTIC_ICW";
            if (findNoCase("atlantic intracoastal", sectionNorm)) return "ATLANTIC_ICW";
            if (findNoCase("florida east coast", sectionNorm)) return "ATLANTIC_ICW";
            if (findNoCase("okeechobee", sectionNorm)) return "OKEECHOBEE";
            if (findNoCase("gulf", sectionNorm) AND findNoCase("icw", sectionNorm)) return "GULF_ICW";
            if (findNoCase("crossing", sectionNorm) OR findNoCase("gulf crossing", sectionNorm)) return "GULF_ICW";
            if (findNoCase("illinois", sectionNorm)) return "ILLINOIS";
            if (findNoCase("mississippi", sectionNorm)) return "MISSISSIPPI";
            if (findNoCase("ohio", sectionNorm)) return "OHIO";
            if (findNoCase("tennessee river", sectionNorm)) return "TENNESSEE";
            if (findNoCase("tenn tom", sectionNorm) OR findNoCase("tenn-tom", sectionNorm)) return "TENN_TOM";

            if (containsAny(nodeNorm, ["waterford","amsterdam","utica","syracuse","rochester","lockport","tonawanda","oswego"])) return "ERIE_CANAL";
            if (containsAny(nodeNorm, ["new york harbor","battery","haverstraw","poughkeepsie","catskill","albany","troy"])) return "HUDSON";
            if (containsAny(nodeNorm, ["norfolk","myrtle beach","charleston","savannah","brunswick","saint augustine","st augustine","jacksonville","cape canaveral","miami"])) return "ATLANTIC_ICW";
            if (containsAny(nodeNorm, ["port mayaca","clewiston","stuart"])) return "OKEECHOBEE";
            if (containsAny(nodeNorm, ["sarasota","tampa","tarpon springs","carrabelle","panama city","pensacola"])) return "GULF_ICW";
            if (containsAny(nodeNorm, ["paris landing","clifton","pickwick","chattanooga","knoxville"])) return "TENNESSEE";
            if (containsAny(nodeNorm, ["aliceville","demopolis","coffeeville"])) return "TENN_TOM";
            if (containsAny(nodeNorm, ["pittsburgh","cincinnati","louisville","evansville"])) return "OHIO";
            if (containsAny(nodeNorm, ["cape girardeau","saint louis","st louis","grafton"])) return "MISSISSIPPI";
            if (containsAny(nodeNorm, ["joliet","peoria","lockport","grafton"])) return "ILLINOIS";

            if ((findNoCase("intracoastal", sectionNorm) OR findNoCase("icw", sectionNorm)) AND containsAny(nodeNorm, ["norfolk","charleston","savannah","miami"])) return "ATLANTIC_ICW";
            if ((findNoCase("intracoastal", sectionNorm) OR findNoCase("icw", sectionNorm)) AND containsAny(nodeNorm, ["fort myers","sarasota","tampa","mobile"])) return "GULF_ICW";
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="containsAny" access="private" returntype="boolean" output="false">
        <cfargument name="haystack" type="string" required="true">
        <cfargument name="needles" type="array" required="true">
        <cfscript>
            var i = 0;
            if (!len(arguments.haystack)) return false;
            for (i = 1; i LTE arrayLen(arguments.needles); i++) {
                if (findNoCase(arguments.needles[i], arguments.haystack) GT 0) return true;
            }
            return false;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeName" access="private" returntype="string" output="false">
        <cfargument name="s" type="any" required="true">
        <cfscript>
            var v = lCase(trim(toString(arguments.s)));
            if (!len(v)) return "";
            v = reReplace(v, "\bst[.]?\b", "saint", "all");
            v = reReplace(v, "\bmt[.]?\b", "mount", "all");
            v = reReplace(v, "[^a-z0-9]+", " ", "all");
            v = reReplace(v, "\s+", " ", "all");
            return trim(v);
        </cfscript>
    </cffunction>

</cfcomponent>
