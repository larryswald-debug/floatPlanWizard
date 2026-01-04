<cfcomponent output="false">

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfargument name="action" type="any"    required="false">
        <cfargument name="id"     type="any"    required="false">
        <cfargument name="floatPlanId" type="any" required="false">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

        <cftry>
            <cfset var userStruct = {} >
            <cfif structKeyExists(session, "user") AND isStruct(session.user)>
                <cfset userStruct = session.user>
            </cfif>

            <cfset var userId = resolveUserId(userStruct)>

            <cfif userId LTE 0>
                <cfset var notLoggedResponse = {
                    SUCCESS = false,
                    AUTH    = false,
                    ERROR   = "NOT_LOGGED_IN",
                    MESSAGE = "Not logged in."
                }>
                <cfoutput>#serializeJSON(notLoggedResponse)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfreturn>
            </cfif>

            <cfset var httpData = getHttpRequestData()>
            <cfset var rawBody  = toString(httpData.content)>
            <cfset var body     = {} >

            <cfif len(trim(rawBody))>
                <cftry>
                    <cfset body = deserializeJSON(rawBody)>
                <cfcatch>
                    <cfset body = {}>
                </cfcatch>
                </cftry>
            </cfif>

            <cfset var actionName = "bootstrap">
            <cfif structKeyExists(arguments, "action") AND len(trim(arguments.action))>
                <cfset actionName = lcase(trim(arguments.action))>
            <cfelseif structKeyExists(url, "action") AND len(trim(url.action))>
                <cfset actionName = lcase(trim(url.action))>
            <cfelseif structKeyExists(body, "action") AND len(trim(body.action))>
                <cfset actionName = lcase(trim(body.action))>
            </cfif>

            <cfswitch expression="#actionName#">
                <cfcase value="bootstrap">
                    <cfset var bootstrapId = 0>
                    <cfif structKeyExists(url, "id")>
                        <cfset bootstrapId = val(url.id)>
                    <cfelseif structKeyExists(url, "floatPlanId")>
                        <cfset bootstrapId = val(url.floatPlanId)>
                    <cfelseif structKeyExists(body, "floatPlanId")>
                        <cfset bootstrapId = val(body.floatPlanId)>
                    </cfif>

                    <cfset var bootstrapData = getBootstrapData(userId, bootstrapId)>
                    <cfset bootstrapData.SUCCESS = true>
                    <cfset bootstrapData.AUTH = true>
                    <cfoutput>#serializeJSON(bootstrapData)#</cfoutput>
                </cfcase>

                <cfcase value="save">
                    <cfset var saveResult = saveFloatPlan(userId, body)>
                    <cfset saveResult.AUTH = true>
                    <cfoutput>#serializeJSON(saveResult)#</cfoutput>
                </cfcase>

                <cfcase value="send">
                    <cfset var sendId = 0>
                    <cfif structKeyExists(body, "floatPlanId")>
                        <cfset sendId = val(body.floatPlanId)>
                    <cfelseif structKeyExists(url, "floatPlanId")>
                        <cfset sendId = val(url.floatPlanId)>
                    <cfelseif structKeyExists(url, "id")>
                        <cfset sendId = val(url.id)>
                    </cfif>

                    <cfset var sendResult = sendFloatPlanToContacts(userId, sendId)>
                    <cfset sendResult.AUTH = true>
                    <cfoutput>#serializeJSON(sendResult)#</cfoutput>
                </cfcase>

                <cfcase value="clone">
                    <cfset var cloneId = 0>
                    <cfif structKeyExists(body, "floatPlanId")>
                        <cfset cloneId = val(body.floatPlanId)>
                    <cfelseif structKeyExists(url, "floatPlanId")>
                        <cfset cloneId = val(url.floatPlanId)>
                    <cfelseif structKeyExists(url, "id")>
                        <cfset cloneId = val(url.id)>
                    </cfif>

                    <cfset var cloneResult = cloneFloatPlan(userId, cloneId)>
                    <cfset cloneResult.AUTH = true>
                    <cfoutput>#serializeJSON(cloneResult)#</cfoutput>
                </cfcase>

                <cfcase value="delete">
                    <cfset var deleteId = 0>
                    <cfif structKeyExists(body, "floatPlanId")>
                        <cfset deleteId = val(body.floatPlanId)>
                    <cfelseif structKeyExists(url, "floatPlanId")>
                        <cfset deleteId = val(url.floatPlanId)>
                    <cfelseif structKeyExists(url, "id")>
                        <cfset deleteId = val(url.id)>
                    </cfif>

                    <cfset var deleteResult = deleteFloatPlan(userId, deleteId)>
                    <cfset deleteResult.AUTH = true>
                    <cfoutput>#serializeJSON(deleteResult)#</cfoutput>
                </cfcase>

                <cfcase value="checkin">
                    <cfset var checkinId = 0>
                    <cfif structKeyExists(body, "floatPlanId")>
                        <cfset checkinId = val(body.floatPlanId)>
                    <cfelseif structKeyExists(url, "floatPlanId")>
                        <cfset checkinId = val(url.floatPlanId)>
                    <cfelseif structKeyExists(url, "id")>
                        <cfset checkinId = val(url.id)>
                    </cfif>

                    <cfset var checkinResult = checkInFloatPlan(userId, checkinId)>
                    <cfset checkinResult.AUTH = true>
                    <cfoutput>#serializeJSON(checkinResult)#</cfoutput>
                </cfcase>

                <cfdefaultcase>
                    <cfset var invalidResponse = {
                        SUCCESS = false,
                        AUTH    = true,
                        ERROR   = "INVALID_ACTION",
                        MESSAGE = "Unsupported action."
                    }>
                    <cfoutput>#serializeJSON(invalidResponse)#</cfoutput>
                </cfdefaultcase>
            </cfswitch>

        <cfcatch type="any">
            <cfset var errDetail = {
                message = cfcatch.message,
                detail  = structKeyExists(cfcatch, "detail") ? cfcatch.detail : "",
                sql     = structKeyExists(cfcatch, "sql") ? cfcatch.sql : "",
                tagContext = structKeyExists(cfcatch, "tagContext") ? cfcatch.tagContext : []
            }>

            <cfset var errResponse = {
                SUCCESS = false,
                AUTH    = true,
                ERROR   = "SERVER_ERROR",
                MESSAGE = "Float plan API error.",
                DETAIL  = errDetail
            }>

            <cflog type="error" text="Float plan API error: #serializeJSON(errDetail)#">
            <cfoutput>#serializeJSON(errResponse)#</cfoutput>
        </cfcatch>
        </cftry>

        <cfsetting enablecfoutputonly="false">
    </cffunction>

    <cffunction name="resolveUserId" access="private" returntype="numeric" output="false">
        <cfargument name="userStruct" type="struct" required="true">
        <cfscript>
            var userId = 0;
            if (structKeyExists(arguments.userStruct, "userId")) {
                userId = arguments.userStruct.userId;
            } else if (structKeyExists(arguments.userStruct, "id")) {
                userId = arguments.userStruct.id;
            } else if (structKeyExists(arguments.userStruct, "USERID")) {
                userId = arguments.userStruct.USERID;
            }
            if (NOT isNumeric(userId)) {
                return 0;
            }
            return val(userId);
        </cfscript>
    </cffunction>

    <cffunction name="loadRescueCenters" access="private" returntype="array" output="false">
        <cfscript>
            var centers = [];
            var qCenters = queryExecute("
                SELECT recId, rcName, rcPhone, rcDistrict, rcArea, rcLocation
                FROM rescuecenters
                ORDER BY rcName ASC
            ", {}, { datasource = "fpw" });

            for (var i = 1; i LTE qCenters.recordCount; i++) {
                arrayAppend(centers, {
                    recId      = qCenters.recId[i],
                    rcName     = qCenters.rcName[i],
                    rcPhone    = qCenters.rcPhone[i],
                    rcDistrict = qCenters.rcDistrict[i],
                    rcArea     = qCenters.rcArea[i],
                    rcLocation = qCenters.rcLocation[i]
                });
            }
            return centers;
        </cfscript>
    </cffunction>

    <cffunction name="loadHomePort" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfscript>
            var home = {};
            var qHome = queryExecute("
                SELECT
                    recId,
                    userId,
                    address,
                    city,
                    state,
                    zip,
                    phone,
                    lat,
                    lng,
                    isHomePort
                FROM users_address
                WHERE userId = :userId
                  AND isHomePort = 1
                LIMIT 1
            ", {
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
            }, { datasource = "fpw" });

            if (qHome.recordCount EQ 1) {
                home = {
                    RECID      = qHome.recId[1],
                    USERID     = qHome.userId[1],
                    ADDRESS    = qHome.address[1],
                    CITY       = qHome.city[1],
                    STATE      = qHome.state[1],
                    ZIP        = qHome.zip[1],
                    PHONE      = qHome.phone[1],
                    LAT        = qHome.lat[1],
                    LNG        = qHome.lng[1],
                    ISHOMEPORT = qHome.isHomePort[1]
                };
            }

            return home;
        </cfscript>
    </cffunction>

    <cffunction name="getBootstrapData" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var response = {
                FLOATPLAN       = getDefaultFloatPlan(arguments.userId),
                PLAN_PASSENGERS = [],
                PLAN_CONTACTS   = [],
                PLAN_WAYPOINTS  = []
            };

            if (arguments.floatPlanId GT 0) {
                var planData = loadFloatPlan(arguments.userId, arguments.floatPlanId);
                if (structKeyExists(planData, "FLOATPLANID")) {
                    response.FLOATPLAN = planData;
                    var selections = loadPlanSelections(arguments.userId, arguments.floatPlanId);
                    response.PLAN_PASSENGERS = selections.PASSENGERS;
                    response.PLAN_CONTACTS   = selections.CONTACTS;
                    response.PLAN_WAYPOINTS  = selections.WAYPOINTS;
                }
            }

            response.VESSELS        = loadVessels(arguments.userId);
            response.OPERATORS      = loadOperators(arguments.userId);
            response.PASSENGERS     = loadPassengers(arguments.userId);
            response.CONTACTS       = loadContacts(arguments.userId);
            response.WAYPOINTS      = loadWaypoints(arguments.userId);
            response.RESCUE_CENTERS = loadRescueCenters();
            response.HOME_PORT      = loadHomePort(arguments.userId);

            return response;
        </cfscript>
    </cffunction>

    <cffunction name="saveFloatPlan" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="payload" type="struct" required="true">
        <cfscript>
            var result = { SUCCESS = false };
            if (NOT structKeyExists(arguments.payload, "FLOATPLAN")) {
                result.ERROR = "MISSING_FLOATPLAN";
                result.MESSAGE = "FLOATPLAN payload is required.";
                return result;
            }

            var floatPlan = arguments.payload.FLOATPLAN;
            var selectedPassengers = structKeyExists(arguments.payload, "PASSENGERS") ? arguments.payload.PASSENGERS : [];
            var selectedContacts   = structKeyExists(arguments.payload, "CONTACTS") ? arguments.payload.CONTACTS : [];
            var selectedWaypoints  = structKeyExists(arguments.payload, "WAYPOINTS") ? arguments.payload.WAYPOINTS : [];

            var planId    = val(pickValue(floatPlan, ["floatPlanId", "FLOATPLANID"], 0));
            var planName  = trim(pickValue(floatPlan, ["floatPlanName", "NAME"], ""));
            var vesselId  = val(pickValue(floatPlan, ["vesselId", "VESSELID"], 0));
            var operatorId = val(pickValue(floatPlan, ["operatorId", "OPERATORID"], 0));
            var operatorHasPfd = booleanValue(pickValue(floatPlan, ["operatorHasPfd", "OPERATOR_HAS_PFD"], false));
            var email     = trim(pickValue(floatPlan, ["email", "EMAIL"], ""));
            var rescueAuthority = trim(pickValue(floatPlan, ["rescueAuthority", "RESCUE_AUTHORITY"], ""));
            var rescuePhone     = trim(pickValue(floatPlan, ["rescueAuthorityPhone", "RESCUE_AUTHORITY_PHONE"], ""));
            var rescueCenterId  = val(pickValue(floatPlan, ["rescueCenterId", "RESCUE_CENTERID"], 0));
            var departingFrom   = trim(pickValue(floatPlan, ["departingFrom", "DEPARTING_FROM"], ""));
            var departureTime   = trim(pickValue(floatPlan, ["departureTime", "DEPARTURE_TIME"], ""));
            var departureTz     = trim(pickValue(floatPlan, ["departureTimezone", "DEPARTURE_TIMEZONE"], ""));
            var returningTo     = trim(pickValue(floatPlan, ["returningTo", "RETURNING_TO"], ""));
            var returnTime      = trim(pickValue(floatPlan, ["returnTime", "RETURN_TIME"], ""));
            var returnTz        = trim(pickValue(floatPlan, ["returnTimezone", "RETURN_TIMEZONE"], ""));
            var foodDays        = trim(pickValue(floatPlan, ["foodDaysPerPerson", "FOOD_DAYS_PER_PERSON"], ""));
            var waterDays       = trim(pickValue(floatPlan, ["waterDaysPerPerson", "WATER_DAYS_PER_PERSON"], ""));
            var notes           = trim(pickValue(floatPlan, ["notes", "NOTES"], ""));
            var doNotSend       = booleanValue(pickValue(floatPlan, ["doNotSend", "DO_NOT_SEND"], false));

            if (NOT len(planName)) {
                result.ERROR = "VALIDATION";
                result.MESSAGE = "Float plan name is required.";
                return result;
            }

            if (vesselId LTE 0) {
                result.ERROR = "VALIDATION";
                result.MESSAGE = "Please select a vessel.";
                return result;
            }

            var ds = "fpw";

            planName = ensureUniquePlanName(arguments.userId, planId, planName, ds);

            transaction {
                if (planId LTE 0) {
                    queryExecute("
                        INSERT INTO floatplans
                        (
                            userId,
                            floatPlanName,
                            vesselId,
                            operatorId,
                            opHasPfd,
                            floatPlanEmail,
                            rescueAuthority,
                            rescueAuthorityPhone,
                            rescueCenterId,
                            departing,
                            departureTime,
                            departTimezone,
                            returning,
                            returnTime,
                            returnTimezone,
                            food,
                            water,
                            notes,
                            status,
                            dateCreated,
                            lastUpdate
                        )
                        VALUES
                        (
                            :userId,
                            :planName,
                            :vesselId,
                            :operatorId,
                            :operatorHasPfd,
                            :email,
                            :rescueAuthority,
                            :rescuePhone,
                            :rescueCenterId,
                            :departingFrom,
                            :departureTime,
                            :departureTz,
                            :returningTo,
                            :returnTime,
                            :returnTz,
                            :foodDays,
                            :waterDays,
                            :notes,
                            'Draft',
                            NOW(),
                            NOW()
                        )
                    ", {
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                        planName = { value = planName, cfsqltype = "cf_sql_varchar" },
                        vesselId = { value = vesselId, cfsqltype = "cf_sql_integer" },
                        operatorId = { value = operatorId, cfsqltype = "cf_sql_integer", null = (operatorId LTE 0) },
                        operatorHasPfd = { value = operatorHasPfd, cfsqltype = "cf_sql_bit" },
                        email = { value = email, cfsqltype = "cf_sql_varchar", null = NOT len(email) },
                        rescueAuthority = { value = rescueAuthority, cfsqltype = "cf_sql_varchar", null = NOT len(rescueAuthority) },
                        rescuePhone = { value = rescuePhone, cfsqltype = "cf_sql_varchar", null = NOT len(rescuePhone) },
                        rescueCenterId = { value = rescueCenterId, cfsqltype = "cf_sql_integer", null = (rescueCenterId LTE 0) },
                        departingFrom = { value = departingFrom, cfsqltype = "cf_sql_varchar", null = NOT len(departingFrom) },
                        departureTime = { value = departureTime, cfsqltype = "cf_sql_timestamp", null = NOT len(departureTime) },
                        departureTz = { value = departureTz, cfsqltype = "cf_sql_varchar", null = NOT len(departureTz) },
                        returningTo = { value = returningTo, cfsqltype = "cf_sql_varchar", null = NOT len(returningTo) },
                        returnTime = { value = returnTime, cfsqltype = "cf_sql_timestamp", null = NOT len(returnTime) },
                        returnTz = { value = returnTz, cfsqltype = "cf_sql_varchar", null = NOT len(returnTz) },
                        foodDays = { value = foodDays, cfsqltype = "cf_sql_varchar", null = NOT len(foodDays) },
                        waterDays = { value = waterDays, cfsqltype = "cf_sql_varchar", null = NOT len(waterDays) },
                        notes = { value = notes, cfsqltype = "cf_sql_varchar", null = NOT len(notes) },
                        doNotSend = { value = doNotSend, cfsqltype = "cf_sql_bit" }
                    }, { datasource = ds });

                    var newIdQuery = queryExecute("SELECT LAST_INSERT_ID() AS newId", {}, { datasource = ds });
                    planId = newIdQuery.newId;
                } else {
                    queryExecute("
                        UPDATE floatplans
                           SET floatPlanName        = :planName,
                               vesselId            = :vesselId,
                               operatorId          = :operatorId,
                               opHasPfd            = :operatorHasPfd,
                               floatPlanEmail      = :email,
                               rescueAuthority     = :rescueAuthority,
                               rescueAuthorityPhone= :rescuePhone,
                               rescueCenterId      = :rescueCenterId,
                               departing           = :departingFrom,
                               departureTime       = :departureTime,
                               departTimezone      = :departureTz,
                               returning           = :returningTo,
                               returnTime          = :returnTime,
                               returnTimezone      = :returnTz,
                               food                = :foodDays,
                               water               = :waterDays,
                               notes               = :notes,
                               lastUpdate          = NOW()
                         WHERE floatplanId = :planId
                           AND userId = :userId
                    ", {
                        planId = { value = planId, cfsqltype = "cf_sql_integer" },
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                        planName = { value = planName, cfsqltype = "cf_sql_varchar" },
                        vesselId = { value = vesselId, cfsqltype = "cf_sql_integer" },
                        operatorId = { value = operatorId, cfsqltype = "cf_sql_integer", null = (operatorId LTE 0) },
                        operatorHasPfd = { value = operatorHasPfd, cfsqltype = "cf_sql_bit" },
                        email = { value = email, cfsqltype = "cf_sql_varchar", null = NOT len(email) },
                        rescueAuthority = { value = rescueAuthority, cfsqltype = "cf_sql_varchar", null = NOT len(rescueAuthority) },
                        rescuePhone = { value = rescuePhone, cfsqltype = "cf_sql_varchar", null = NOT len(rescuePhone) },
                        rescueCenterId = { value = rescueCenterId, cfsqltype = "cf_sql_integer", null = (rescueCenterId LTE 0) },
                        departingFrom = { value = departingFrom, cfsqltype = "cf_sql_varchar", null = NOT len(departingFrom) },
                        departureTime = { value = departureTime, cfsqltype = "cf_sql_timestamp", null = NOT len(departureTime) },
                        departureTz = { value = departureTz, cfsqltype = "cf_sql_varchar", null = NOT len(departureTz) },
                        returningTo = { value = returningTo, cfsqltype = "cf_sql_varchar", null = NOT len(returningTo) },
                        returnTime = { value = returnTime, cfsqltype = "cf_sql_timestamp", null = NOT len(returnTime) },
                        returnTz = { value = returnTz, cfsqltype = "cf_sql_varchar", null = NOT len(returnTz) },
                        foodDays = { value = foodDays, cfsqltype = "cf_sql_varchar", null = NOT len(foodDays) },
                        waterDays = { value = waterDays, cfsqltype = "cf_sql_varchar", null = NOT len(waterDays) },
                        notes = { value = notes, cfsqltype = "cf_sql_varchar", null = NOT len(notes) },
                        doNotSend = { value = doNotSend, cfsqltype = "cf_sql_bit" }
                    }, { datasource = ds });

                    // remove existing selections
                    queryExecute("DELETE FROM floatplan_passengers WHERE floatplanId = :planId", { planId = { value = planId, cfsqltype = "cf_sql_integer" } }, { datasource = ds });
                    queryExecute("DELETE FROM floatplan_contacts WHERE floatplanId = :planId", { planId = { value = planId, cfsqltype = "cf_sql_integer" } }, { datasource = ds });
                    queryExecute("DELETE FROM floatplan_waypoints WHERE floatplanId = :planId", { planId = { value = planId, cfsqltype = "cf_sql_integer" } }, { datasource = ds });
                }

                // Reinsert passengers
                for (var pIndex = 1; pIndex LTE arrayLen(selectedPassengers); pIndex++) {
                    var p = selectedPassengers[pIndex];
                    var passengerId = val(pickValue(p, ["PASSENGERID", "passengerId", "passId"], 0));
                    if (passengerId LTE 0) continue;
                    var hasPfd = booleanValue(pickValue(p, ["HAS_PFD", "hasPfd"], true));
                    queryExecute("
                        INSERT INTO floatplan_passengers (passId, floatplanId, hasPdf)
                        VALUES (:passengerId, :planId, :hasPfd)
                    ", {
                        planId = { value = planId, cfsqltype = "cf_sql_integer" },
                        passengerId = { value = passengerId, cfsqltype = "cf_sql_integer" },
                        hasPfd = { value = hasPfd, cfsqltype = "cf_sql_bit" }
                    }, { datasource = ds });
                }

                // Reinsert contacts
                for (var cIndex = 1; cIndex LTE arrayLen(selectedContacts); cIndex++) {
                    var c = selectedContacts[cIndex];
                    var contactId = val(pickValue(c, ["CONTACTID", "contactId"], 0));
                    if (contactId LTE 0) continue;
                    queryExecute("
                        INSERT INTO floatplan_contacts (contactId, floatplanId)
                        VALUES (:contactId, :planId)
                    ", {
                        contactId = { value = contactId, cfsqltype = "cf_sql_integer" },
                        planId = { value = planId, cfsqltype = "cf_sql_integer" }
                    }, { datasource = ds });
                }

                // Reinsert waypoints
                for (var wIndex = 1; wIndex LTE arrayLen(selectedWaypoints); wIndex++) {
                    var w = selectedWaypoints[wIndex];
                    var waypointId = val(pickValue(w, ["WAYPOINTID", "waypointId", "wpId"], 0));
                    if (waypointId LTE 0) continue;
                    var reason = trim(pickValue(w, ["REASON_FOR_STOP", "reasonForStop"], ""));
                    var departMode = trim(pickValue(w, ["DEPART_MODE", "departMode"], ""));
                    var arrivalAt = trim(pickValue(w, ["ARRIVAL_TIME", "arrivalTime"], ""));
                    var departAt = trim(pickValue(w, ["DEPARTURE_TIME", "departureTime"], ""));

                    queryExecute("
                        INSERT INTO floatplan_waypoints
                            (wayPointId, floatPlanId, reason, departType, arrival, departure)
                        VALUES
                            (:waypointId, :planId, :reason, :departMode, :arrivalAt, :departAt)
                    ", {
                        planId = { value = planId, cfsqltype = "cf_sql_integer" },
                        waypointId = { value = waypointId, cfsqltype = "cf_sql_integer" },
                        reason = { value = reason, cfsqltype = "cf_sql_varchar", null = NOT len(reason) },
                        departMode = { value = departMode, cfsqltype = "cf_sql_varchar", null = NOT len(departMode) },
                        arrivalAt = { value = arrivalAt, cfsqltype = "cf_sql_timestamp", null = NOT len(arrivalAt) },
                        departAt = { value = departAt, cfsqltype = "cf_sql_timestamp", null = NOT len(departAt) }
                    }, { datasource = ds });
                }
            }

            var savedPlan = loadFloatPlan(arguments.userId, planId);
            var savedSelections = loadPlanSelections(arguments.userId, planId);

            result.SUCCESS = true;
            result.FLOATPLANID = planId;
            result.FLOATPLAN = savedPlan;
            result.PLAN_PASSENGERS = savedSelections.PASSENGERS;
            result.PLAN_CONTACTS = savedSelections.CONTACTS;
            result.PLAN_WAYPOINTS = savedSelections.WAYPOINTS;

            return result;
        </cfscript>
    </cffunction>

    <cffunction name="ensureUniquePlanName" access="private" returntype="string" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="planId" type="numeric" required="true">
        <cfargument name="planName" type="string" required="true">
        <cfargument name="datasource" type="string" required="true">
        <cfscript>
            var baseNameRaw = trim(arguments.planName);
            var baseName = baseNameRaw;
            var suffix = 0;
            var candidate = baseNameRaw;
            var dupCheck = {};

            if (NOT len(baseNameRaw)) {
                return baseNameRaw;
            }

            var lastSegment = listLast(baseNameRaw, "_");
            if (listLen(baseNameRaw, "_") GT 1 AND isNumeric(lastSegment)) {
                baseName = left(baseNameRaw, len(baseNameRaw) - len(lastSegment) - 1);
                if (len(baseName)) {
                    suffix = val(lastSegment);
                } else {
                    baseName = baseNameRaw;
                    suffix = 0;
                }
            }

            do {
                dupCheck = queryExecute(
                    "SELECT COUNT(*) AS nameCount
                     FROM floatplans
                     WHERE userId = ?
                       AND floatPlanName = ?
                       AND floatplanId <> ?",
                    [
                        { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                        { value = candidate, cfsqltype = "cf_sql_varchar" },
                        { value = arguments.planId, cfsqltype = "cf_sql_integer" }
                    ],
                    { datasource = arguments.datasource }
                );

                if (dupCheck.recordCount EQ 0 OR dupCheck.nameCount[1] EQ 0) {
                    return candidate;
                }

                suffix = suffix + 1;
                candidate = baseName & "_" & suffix;
            } while (true);
        </cfscript>
    </cffunction>

    <cffunction name="cloneFloatPlan" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = { SUCCESS = false };
            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }

            var planExists = queryExecute("
                SELECT floatplanId, UPPER(TRIM(`status`)) AS statusValue
                  FROM floatplans
                 WHERE floatplanId = :planId
                   AND userId = :userId
                 LIMIT 1
            ", {
                planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
            }, { datasource = "fpw" });

            if (planExists.recordCount EQ 0) {
                result.ERROR = "NOT_FOUND";
                result.MESSAGE = "Float plan not found.";
                return result;
            }

            var planData = loadFloatPlan(arguments.userId, arguments.floatPlanId);
            var selections = loadPlanSelections(arguments.userId, arguments.floatPlanId);
            var ds = "fpw";

            var baseName = trim(pickValue(planData, ["NAME"], "Float Plan"));
            if (NOT len(baseName)) {
                baseName = "Float Plan";
            }

            var cloneName = ensureUniquePlanName(arguments.userId, 0, baseName, ds);
            var newPlanId = 0;

            var vesselId = val(pickValue(planData, ["VESSELID"], 0));
            var operatorId = val(pickValue(planData, ["OPERATORID"], 0));
            var operatorHasPfd = booleanValue(pickValue(planData, ["OPERATOR_HAS_PFD"], true));
            var email = trim(pickValue(planData, ["EMAIL"], ""));
            var rescueAuthority = trim(pickValue(planData, ["RESCUE_AUTHORITY"], ""));
            var rescuePhone = trim(pickValue(planData, ["RESCUE_AUTHORITY_PHONE"], ""));
            var rescueCenterId = val(pickValue(planData, ["RESCUE_CENTERID"], 0));
            var departingFrom = trim(pickValue(planData, ["DEPARTING_FROM"], ""));
            var departureTime = trim(pickValue(planData, ["DEPARTURE_TIME"], ""));
            var departureTz = trim(pickValue(planData, ["DEPARTURE_TIMEZONE"], ""));
            var returningTo = trim(pickValue(planData, ["RETURNING_TO"], ""));
            var returnTime = trim(pickValue(planData, ["RETURN_TIME"], ""));
            var returnTz = trim(pickValue(planData, ["RETURN_TIMEZONE"], ""));
            var foodDays = trim(pickValue(planData, ["FOOD_DAYS_PER_PERSON"], ""));
            var waterDays = trim(pickValue(planData, ["WATER_DAYS_PER_PERSON"], ""));
            var notes = trim(pickValue(planData, ["NOTES"], ""));
            var status = "Draft";

            transaction {
                queryExecute("
                    INSERT INTO floatplans
                    (
                        userId,
                        floatPlanName,
                        vesselId,
                        operatorId,
                        opHasPfd,
                        floatPlanEmail,
                        rescueAuthority,
                        rescueAuthorityPhone,
                        rescueCenterId,
                        departing,
                        departureTime,
                        departTimezone,
                        returning,
                        returnTime,
                        returnTimezone,
                        food,
                        water,
                        notes,
                        status,
                        activatedAt,
                        checkedInAt,
                        closedAt,
                        lastUpdateStatus,
                        dateCreated,
                        lastUpdate
                    )
                    VALUES
                    (
                        :userId,
                        :planName,
                        :vesselId,
                        :operatorId,
                        :operatorHasPfd,
                        :email,
                        :rescueAuthority,
                        :rescuePhone,
                        :rescueCenterId,
                        :departingFrom,
                        :departureTime,
                        :departureTz,
                        :returningTo,
                        :returnTime,
                        :returnTz,
                        :foodDays,
                        :waterDays,
                        :notes,
                        :status,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NOW(),
                        NOW()
                    )
                ", {
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                    planName = { value = cloneName, cfsqltype = "cf_sql_varchar" },
                    vesselId = { value = vesselId, cfsqltype = "cf_sql_integer" },
                    operatorId = { value = operatorId, cfsqltype = "cf_sql_integer", null = (operatorId LTE 0) },
                    operatorHasPfd = { value = operatorHasPfd, cfsqltype = "cf_sql_bit" },
                    email = { value = email, cfsqltype = "cf_sql_varchar", null = NOT len(email) },
                    rescueAuthority = { value = rescueAuthority, cfsqltype = "cf_sql_varchar", null = NOT len(rescueAuthority) },
                    rescuePhone = { value = rescuePhone, cfsqltype = "cf_sql_varchar", null = NOT len(rescuePhone) },
                    rescueCenterId = { value = rescueCenterId, cfsqltype = "cf_sql_integer", null = (rescueCenterId LTE 0) },
                    departingFrom = { value = departingFrom, cfsqltype = "cf_sql_varchar", null = NOT len(departingFrom) },
                    departureTime = { value = departureTime, cfsqltype = "cf_sql_timestamp", null = NOT len(departureTime) },
                    departureTz = { value = departureTz, cfsqltype = "cf_sql_varchar", null = NOT len(departureTz) },
                    returningTo = { value = returningTo, cfsqltype = "cf_sql_varchar", null = NOT len(returningTo) },
                    returnTime = { value = returnTime, cfsqltype = "cf_sql_timestamp", null = NOT len(returnTime) },
                    returnTz = { value = returnTz, cfsqltype = "cf_sql_varchar", null = NOT len(returnTz) },
                    foodDays = { value = foodDays, cfsqltype = "cf_sql_varchar", null = NOT len(foodDays) },
                    waterDays = { value = waterDays, cfsqltype = "cf_sql_varchar", null = NOT len(waterDays) },
                    notes = { value = notes, cfsqltype = "cf_sql_varchar", null = NOT len(notes) },
                    status = { value = status, cfsqltype = "cf_sql_varchar", null = NOT len(status) }
                }, { datasource = ds });

                var newIdQuery = queryExecute("SELECT LAST_INSERT_ID() AS newId", {}, { datasource = ds });
                newPlanId = newIdQuery.newId;

                for (var pIndex = 1; pIndex LTE arrayLen(selections.PASSENGERS); pIndex++) {
                    var p = selections.PASSENGERS[pIndex];
                    var passengerId = val(pickValue(p, ["PASSENGERID", "passengerId"], 0));
                    if (passengerId LTE 0) continue;
                    var hasPfd = booleanValue(pickValue(p, ["HAS_PFD", "hasPfd"], true));
                    queryExecute("
                        INSERT INTO floatplan_passengers (passId, floatplanId, hasPdf)
                        VALUES (:passengerId, :planId, :hasPfd)
                    ", {
                        planId = { value = newPlanId, cfsqltype = "cf_sql_integer" },
                        passengerId = { value = passengerId, cfsqltype = "cf_sql_integer" },
                        hasPfd = { value = hasPfd, cfsqltype = "cf_sql_bit" }
                    }, { datasource = ds });
                }

                for (var cIndex = 1; cIndex LTE arrayLen(selections.CONTACTS); cIndex++) {
                    var c = selections.CONTACTS[cIndex];
                    var contactId = val(pickValue(c, ["CONTACTID", "contactId"], 0));
                    if (contactId LTE 0) continue;
                    queryExecute("
                        INSERT INTO floatplan_contacts (contactId, floatplanId)
                        VALUES (:contactId, :planId)
                    ", {
                        contactId = { value = contactId, cfsqltype = "cf_sql_integer" },
                        planId = { value = newPlanId, cfsqltype = "cf_sql_integer" }
                    }, { datasource = ds });
                }

                for (var wIndex = 1; wIndex LTE arrayLen(selections.WAYPOINTS); wIndex++) {
                    var w = selections.WAYPOINTS[wIndex];
                    var waypointId = val(pickValue(w, ["WAYPOINTID", "waypointId"], 0));
                    if (waypointId LTE 0) continue;
                    var reason = trim(pickValue(w, ["REASON_FOR_STOP", "reasonForStop"], ""));
                    var departMode = trim(pickValue(w, ["DEPART_MODE", "departMode"], ""));
                    var arrivalAt = trim(pickValue(w, ["ARRIVAL_TIME", "arrivalTime"], ""));
                    var departAt = trim(pickValue(w, ["DEPARTURE_TIME", "departureTime"], ""));

                    queryExecute("
                        INSERT INTO floatplan_waypoints
                            (wayPointId, floatPlanId, reason, departType, arrival, departure)
                        VALUES
                            (:waypointId, :planId, :reason, :departMode, :arrivalAt, :departAt)
                    ", {
                        planId = { value = newPlanId, cfsqltype = "cf_sql_integer" },
                        waypointId = { value = waypointId, cfsqltype = "cf_sql_integer" },
                        reason = { value = reason, cfsqltype = "cf_sql_varchar", null = NOT len(reason) },
                        departMode = { value = departMode, cfsqltype = "cf_sql_varchar", null = NOT len(departMode) },
                        arrivalAt = { value = arrivalAt, cfsqltype = "cf_sql_timestamp", null = NOT len(arrivalAt) },
                        departAt = { value = departAt, cfsqltype = "cf_sql_timestamp", null = NOT len(departAt) }
                    }, { datasource = ds });
                }
            }

            result.SUCCESS = true;
            result.FLOATPLANID = newPlanId;
            result.CLONED_NAME = cloneName;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="deleteFloatPlan" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = { SUCCESS = false };
            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }

            var planExists = queryExecute("
                SELECT floatplanId, UPPER(TRIM(`status`)) AS statusValue
                  FROM floatplans
                 WHERE floatplanId = :planId
                   AND userId = :userId
                 LIMIT 1
            ", {
                planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
            }, { datasource = "fpw" });

            if (planExists.recordCount EQ 0) {
                result.ERROR = "NOT_FOUND";
                result.MESSAGE = "Float plan not found.";
                return result;
            }

            var planStatus = "";
            if (listFindNoCase(planExists.columnList, "statusValue") GT 0) {
                planStatus = trim(toString(planExists["statusValue"][1]));
            }
            if (listFindNoCase("DRAFT,CLOSED", planStatus) EQ 0) {
                result.ERROR = "DELETE_BLOCKED";
                result.MESSAGE = "Only draft or closed float plans can be deleted.";
                return result;
            }

            transaction {
                queryExecute("DELETE FROM floatplan_passengers WHERE floatplanId = :planId", { planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" } }, { datasource = "fpw" });
                queryExecute("DELETE FROM floatplan_contacts WHERE floatplanId = :planId", { planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" } }, { datasource = "fpw" });
                queryExecute("DELETE FROM floatplan_waypoints WHERE floatplanId = :planId", { planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" } }, { datasource = "fpw" });
                queryExecute("DELETE FROM floatplans WHERE floatplanId = :planId AND userId = :userId AND UPPER(TRIM(`status`)) IN ('DRAFT','CLOSED')", {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                }, { datasource = "fpw" });
            }

            result.SUCCESS = true;
            result.FLOATPLANID = arguments.floatPlanId;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="checkInFloatPlan" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = { SUCCESS = false };
            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }

            queryExecute("
                UPDATE floatplans
                SET
                    `status` = 'CLOSED',
                    checkedInAt = UTC_TIMESTAMP(),
                    closedAt = UTC_TIMESTAMP(),
                    lastUpdateStatus = UTC_TIMESTAMP()
                WHERE floatplanId = :planId
                  AND userId = :userId
                  AND UPPER(TRIM(`status`)) IN ('ACTIVE', 'OVERDUE')
            ", {
                planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
            }, { datasource = "fpw" });

            result.SUCCESS = true;
            result.FLOATPLANID = arguments.floatPlanId;
            result.STATUS = "CLOSED";
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="loadFloatPlan" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var planStruct = {};
            var qPlan = queryExecute("
                SELECT
                    floatplanId,
                    userId,
                    floatPlanName,
                    vesselId,
                    operatorId,
                    opHasPfd,
                    floatPlanEmail,
                    rescueAuthority,
                    rescueAuthorityPhone,
                    rescueCenterId,
                    departing,
                    departureTime,
                    departTimezone,
                    returning,
                    returnTime,
                    returnTimezone,
                    food,
                    water,
                    notes,
                    status
                FROM floatplans
                WHERE floatplanId = :planId
                  AND userId = :userId
                LIMIT 1
            ", {
                planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
            }, { datasource = "fpw" });

            if (qPlan.recordCount EQ 1) {
                planStruct = {
                    FLOATPLANID          = qPlan.floatplanId,
                    USERID               = qPlan.userId,
                    NAME                 = qPlan.floatPlanName,
                    VESSELID             = qPlan.vesselId,
                    OPERATORID           = qPlan.operatorId,
                    OPERATOR_HAS_PFD     = qPlan.opHasPfd,
                    EMAIL                = qPlan.floatPlanEmail,
                    RESCUE_AUTHORITY     = qPlan.rescueAuthority,
                    RESCUE_AUTHORITY_PHONE = qPlan.rescueAuthorityPhone,
                    RESCUE_CENTERID      = qPlan.rescueCenterId,
                    DEPARTING_FROM       = qPlan.departing,
                    DEPARTURE_TIME       = qPlan.departureTime,
                    DEPARTURE_TIMEZONE   = qPlan.departTimezone,
                    RETURNING_TO         = qPlan.returning,
                    RETURN_TIME          = qPlan.returnTime,
                    RETURN_TIMEZONE      = qPlan.returnTimezone,
                    FOOD_DAYS_PER_PERSON = qPlan.food,
                    WATER_DAYS_PER_PERSON= qPlan.water,
                    NOTES                = qPlan.notes,
                    DO_NOT_SEND          = false,
                    STATUS               = qPlan.status
                };
            }

            if (structIsEmpty(planStruct)) {
                planStruct = getDefaultFloatPlan(arguments.userId);
            }

            return planStruct;
        </cfscript>
    </cffunction>

    <cffunction name="loadPlanSelections" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var selections = {
                PASSENGERS = [],
                CONTACTS = [],
                WAYPOINTS = []
            };

            if (arguments.floatPlanId LTE 0) {
                return selections;
            }

            var qPassengers = queryExecute("
                SELECT recId, passId, hasPdf
                FROM floatplan_passengers
                WHERE floatplanId = :planId
                ORDER BY recId ASC
            ", { planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" } }, { datasource = "fpw" });

            for (var i = 1; i LTE qPassengers.recordCount; i++) {
                arrayAppend(selections.PASSENGERS, {
                    PASSENGERID = qPassengers.passId[i],
                    HAS_PFD     = qPassengers.hasPdf[i],
                    SORT_ORDER  = i
                });
            }

            var qContacts = queryExecute("
                SELECT recId, contactId
                FROM floatplan_contacts
                WHERE floatplanId = :planId
                ORDER BY recId ASC
            ", { planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" } }, { datasource = "fpw" });

            for (var j = 1; j LTE qContacts.recordCount; j++) {
                arrayAppend(selections.CONTACTS, {
                    CONTACTID = qContacts.contactId[j],
                    SORT_ORDER = j
                });
            }

            var qWaypoints = queryExecute("
                SELECT recId, wayPointId, reason, departType, arrival, departure
                FROM floatplan_waypoints
                WHERE floatplanId = :planId
                ORDER BY recId ASC
            ", { planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" } }, { datasource = "fpw" });

            for (var k = 1; k LTE qWaypoints.recordCount; k++) {
                arrayAppend(selections.WAYPOINTS, {
                    WAYPOINTID      = qWaypoints.wayPointId[k],
                    SORT_ORDER      = k,
                    REASON_FOR_STOP = qWaypoints.reason[k],
                    DEPART_MODE     = qWaypoints.departType[k],
                    ARRIVAL_TIME    = qWaypoints.arrival[k],
                    DEPARTURE_TIME  = qWaypoints.departure[k]
                });
            }

            return selections;
        </cfscript>
    </cffunction>

    <cffunction name="loadPlanContactEmails" access="private" returntype="array" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var contacts = [];
            if (arguments.floatPlanId LTE 0) {
                return contacts;
            }

            var qContacts = queryExecute("
                SELECT c.contactId, c.name, c.email
                FROM floatplan_contacts fc
                INNER JOIN floatplans fp ON fp.floatplanId = fc.floatplanId
                INNER JOIN contacts c ON c.contactId = fc.contactId
                WHERE fp.userId = :userId
                  AND fp.floatplanId = :planId
                ORDER BY fc.recId ASC
            ", {
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
            }, { datasource = "fpw" });

            for (var i = 1; i LTE qContacts.recordCount; i++) {
                arrayAppend(contacts, {
                    CONTACTID = qContacts.contactId[i],
                    NAME      = qContacts.name[i],
                    EMAIL     = qContacts.email[i]
                });
            }
            return contacts;
        </cfscript>
    </cffunction>

    <cffunction name="buildFloatPlanPdfPath" access="private" returntype="string" output="false">
        <cfargument name="fileName" type="string" required="true">
        <cfscript>
            var outputDir = "";
            try {
                outputDir = expandPath("/fpw/floatPlans/user_float_plans/");
            } catch (any e) {
                outputDir = "";
            }
            if (!len(trim(outputDir))) {
                var baseDir = getDirectoryFromPath(getCurrentTemplatePath());
                var apiDir = getDirectoryFromPath(baseDir);
                var rootDir = getDirectoryFromPath(apiDir);
                outputDir = rootDir & "floatPlans/user_float_plans/";
            }
            if (right(outputDir, 1) NEQ "/" AND right(outputDir, 1) NEQ "\") {
                outputDir = outputDir & "/";
            }
            return outputDir & arguments.fileName;
        </cfscript>
    </cffunction>

    <cffunction name="resolveFloatPlanUtilsComponentPath" access="private" returntype="string" output="false">
        <cfscript>
            var webRoot = "";
            var templatePath = getCurrentTemplatePath();
            var relativePath = "";
            var firstSegment = "";
            var prefix = "";
            try {
                webRoot = expandPath("/");
            } catch (any e) {
                webRoot = "";
            }

            if (len(webRoot)) {
                relativePath = replaceNoCase(templatePath, webRoot, "", "one");
            } else {
                relativePath = templatePath;
            }

            relativePath = replace(relativePath, "\", "/", "all");
            if (left(relativePath, 1) EQ "/") {
                relativePath = right(relativePath, len(relativePath) - 1);
            }

            firstSegment = listFirst(relativePath, "/");
            if (len(firstSegment) AND firstSegment NEQ "api") {
                prefix = firstSegment;
            }

            return (len(prefix) ? prefix & "." : "") & "api.api_assets.floatPlanUtils";
        </cfscript>
    </cffunction>

    <cffunction name="sendFloatPlanToContacts" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = {
                SUCCESS = false,
                MESSAGE = ""
            };

            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "MISSING_PLAN_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }

            var plan = loadFloatPlan(arguments.userId, arguments.floatPlanId);
            if (structIsEmpty(plan)) {
                result.ERROR = "PLAN_NOT_FOUND";
                result.MESSAGE = "Float plan not found.";
                return result;
            }

            var statusVal = "";
            if (structKeyExists(plan, "STATUS") AND NOT isNull(plan.STATUS)) {
                statusVal = ucase(trim(toString(plan.STATUS)));
            }
            if (listFindNoCase("DRAFT,CLOSED", statusVal) EQ 0) {
                result.ERROR = "INVALID_STATUS";
                result.MESSAGE = "Only draft or closed float plans can be sent.";
                return result;
            }

            if (NOT structKeyExists(plan, "RETURN_TIME") OR NOT isDate(plan.RETURN_TIME)) {
                result.ERROR = "RETURN_TIME_REQUIRED";
                result.MESSAGE = "Return time is required before sending a float plan.";
                return result;
            }

            var returnTimeInFuture = true;
            try {
                var returnTz = trim(structKeyExists(plan, "RETURN_TIMEZONE") ? plan.RETURN_TIMEZONE : "");
                if (len(returnTz)) {
                    var zone = createObject("java", "java.time.ZoneId").of(returnTz);
                    var returnLocal = createObject("java", "java.time.LocalDateTime").of(
                        datePart("yyyy", plan.RETURN_TIME),
                        datePart("m", plan.RETURN_TIME),
                        datePart("d", plan.RETURN_TIME),
                        datePart("h", plan.RETURN_TIME),
                        datePart("n", plan.RETURN_TIME),
                        datePart("s", plan.RETURN_TIME)
                    );
                    var returnZoned = returnLocal.atZone(zone);
                    var nowZoned = createObject("java", "java.time.ZonedDateTime").now(zone);
                    returnTimeInFuture = returnZoned.isAfter(nowZoned);
                } else {
                    returnTimeInFuture = (dateCompare(now(), plan.RETURN_TIME) LT 0);
                }
            } catch (any e) {
                returnTimeInFuture = (dateCompare(now(), plan.RETURN_TIME) LT 0);
            }

            if (NOT returnTimeInFuture) {
                result.ERROR = "RETURN_TIME_PAST";
                result.MESSAGE = "Return time must be in the future before sending a float plan.";
                return result;
            }

            var contacts = loadPlanContactEmails(arguments.userId, arguments.floatPlanId);
            if (!arrayLen(contacts)) {
                result.ERROR = "NO_CONTACTS";
                result.MESSAGE = "No contacts are selected for this float plan.";
                return result;
            }

            var floatPlanUtils = createObject("component", resolveFloatPlanUtilsComponentPath()).init();
            var pdfFileName = floatPlanUtils.createPDF(arguments.floatPlanId);
            if (!len(trim(pdfFileName))) {
                result.ERROR = "PDF_FAILED";
                result.MESSAGE = "Unable to generate float plan PDF.";
                return result;
            }

            var pdfPath = floatPlanUtils.getPdfPath(pdfFileName);
            var planName = trim(structKeyExists(plan, "NAME") ? plan.NAME : "");
            if (!len(planName)) {
                planName = "Float Plan";
            }

            var rescueAuthority = trim(structKeyExists(plan, "RESCUE_AUTHORITY") ? plan.RESCUE_AUTHORITY : "");
            var rescuePhone = trim(structKeyExists(plan, "RESCUE_AUTHORITY_PHONE") ? plan.RESCUE_AUTHORITY_PHONE : "");
            var safePlanName = encodeForHtml(planName);
            var safeRescueAuthority = encodeForHtml(rescueAuthority);
            var safeRescuePhone = encodeForHtml(rescuePhone);
            var rescueDetails = "";
            var rescueLabel = "the selected Rescue Authority";

            if (len(rescueAuthority) OR len(rescuePhone)) {
                rescueLabel = "the selected Rescue Authority listed below";
                rescueDetails = "<p>Rescue Authority: " & safeRescueAuthority;
                if (len(rescuePhone)) {
                    rescueDetails &= " (" & safeRescuePhone & ")";
                }
                rescueDetails &= "</p>";
            }

            var message = "<p>Hello,</p>" &
                "<p>You are receiving the attached Float Plan (" & safePlanName & ") because you were selected as a contact for this trip.</p>" &
                "<p>This delivery is a precaution and nothing is wrong at this time.</p>" &
                "<p>Please keep this PDF available. If the member does not return on time, call " & rescueLabel & ".</p>" &
                rescueDetails &
                "<p>Thank you.</p>";

            var subject = "Float Plan Precautionary Delivery: " & planName;
            var emailList = "";
            for (var i = 1; i LTE arrayLen(contacts); i++) {
                var contactEmail = "";
                if (structKeyExists(contacts[i], "EMAIL") AND NOT isNull(contacts[i].EMAIL)) {
                    contactEmail = contacts[i].EMAIL;
                }
                var emailAddr = trim(toString(contactEmail));
                if (len(emailAddr)) {
                    emailList = listAppend(emailList, emailAddr);
                }
            }

            var sentCount = listLen(emailList);
            var skippedCount = arrayLen(contacts) - sentCount;
            if (!sentCount) {
                result.ERROR = "NO_EMAILS";
                result.MESSAGE = "No contact emails were available.";
                return result;
            }
        </cfscript>

        <cfloop list="#emailList#" index="emailAddr">
            <cfmail
                from="noreply@floatplanwizard.com"
                to="#emailAddr#"
                subject="#subject#"
                type="html">
                <cfmailparam type="application/pdf" file="#pdfPath#">
                #message#
            </cfmail>
        </cfloop>

        <cfscript>
            queryExecute("
                UPDATE floatplans
                SET
                    `status` = 'ACTIVE',
                    activatedAt = UTC_TIMESTAMP(),
                    lastUpdateStatus = UTC_TIMESTAMP()
                WHERE floatplanId = :planId
                  AND userId = :userId
                  AND UPPER(TRIM(`status`)) IN ('DRAFT', 'CLOSED')
            ", {
                planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
            }, { datasource = "fpw" });

            result.SUCCESS = true;
            result.SENT_COUNT = sentCount;
            result.SKIPPED_COUNT = skippedCount;
            result.MESSAGE = "Float plan sent to " & sentCount & " contact" & (sentCount EQ 1 ? "" : "s") & ".";
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="getDefaultFloatPlan" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfscript>
            return {
                FLOATPLANID          = 0,
                USERID               = arguments.userId,
                NAME                 = "",
                VESSELID             = 0,
                OPERATORID           = 0,
                OPERATOR_HAS_PFD     = true,
                EMAIL                = "",
                RESCUE_AUTHORITY     = "",
                RESCUE_AUTHORITY_PHONE = "",
                RESCUE_CENTERID      = 0,
                DEPARTING_FROM       = "",
                DEPARTURE_TIME       = "",
                DEPARTURE_TIMEZONE   = "",
                RETURNING_TO         = "",
                RETURN_TIME          = "",
                RETURN_TIMEZONE      = "",
                FOOD_DAYS_PER_PERSON = "",
                WATER_DAYS_PER_PERSON= "",
                NOTES                = "",
                DO_NOT_SEND          = false,
                STATUS               = "Draft"
            };
        </cfscript>
    </cffunction>

    <cffunction name="loadVessels" access="private" returntype="array" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfscript>
            var vessels = [];
            var qVessels = queryExecute("
                SELECT vesselId, userId, vesselName, registration, typeOfVessel, make, model,
                       lengthOfVessel, hullColor, hailingPort
                FROM vessels
                WHERE userId = :userId
                ORDER BY vesselName ASC
            ", { userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" } }, { datasource = "fpw" });

            for (var i = 1; i LTE qVessels.recordCount; i++) {
                arrayAppend(vessels, {
                    VESSELID     = qVessels.vesselId[i],
                    USERID       = qVessels.userId[i],
                    VESSELNAME   = qVessels.vesselName[i],
                    REGISTRATION = qVessels.registration[i],
                    TYPE         = qVessels.typeOfVessel[i],
                    MAKE         = qVessels.make[i],
                    MODEL        = qVessels.model[i],
                    LENGTH       = qVessels.lengthOfVessel[i],
                    COLOR        = qVessels.hullColor[i],
                    HOMEPORT     = qVessels.hailingPort[i]
                });
            }
            return vessels;
        </cfscript>
    </cffunction>

    <cffunction name="loadOperators" access="private" returntype="array" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfscript>
            var operators = [];
            var qOps = queryExecute("
                SELECT opId, name, homePhone, notes
                FROM operators
                WHERE userId = :userId
                ORDER BY name ASC
            ", { userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" } }, { datasource = "fpw" });

            for (var i = 1; i LTE qOps.recordCount; i++) {
                arrayAppend(operators, {
                    OPERATORID = qOps.opId[i],
                    OPERATORNAME = qOps.name[i],
                    PHONE = qOps.homePhone[i],
                    NOTES = qOps.notes[i]
                });
            }
            return operators;
        </cfscript>
    </cffunction>

    <cffunction name="loadPassengers" access="private" returntype="array" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfscript>
            var passengers = [];
            var qPassengers = queryExecute("
                SELECT passId, name, phone, age, gender, notes, pfd
                FROM passengers
                WHERE userId = :userId
                ORDER BY name ASC
            ", { userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" } }, { datasource = "fpw" });

            for (var i = 1; i LTE qPassengers.recordCount; i++) {
                arrayAppend(passengers, {
                    PASSENGERID   = qPassengers.passId[i],
                    PASSENGERNAME = qPassengers.name[i],
                    PHONE         = qPassengers.phone[i],
                    AGE           = qPassengers.age[i],
                    GENDER        = qPassengers.gender[i],
                    NOTES         = qPassengers.notes[i],
                    HAS_PFD       = qPassengers.pfd[i]
                });
            }
            return passengers;
        </cfscript>
    </cffunction>

    <cffunction name="loadContacts" access="private" returntype="array" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfscript>
            var contacts = [];
            var qContacts = queryExecute("
                SELECT contactId, name, phone, email
                FROM contacts
                WHERE userId = :userId
                ORDER BY name ASC
            ", { userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" } }, { datasource = "fpw" });

            for (var i = 1; i LTE qContacts.recordCount; i++) {
                arrayAppend(contacts, {
                    CONTACTID   = qContacts.contactId[i],
                    CONTACTNAME = qContacts.name[i],
                    PHONE       = qContacts.phone[i],
                    EMAIL       = qContacts.email[i]
                });
            }
            return contacts;
        </cfscript>
    </cffunction>

    <cffunction name="loadWaypoints" access="private" returntype="array" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfscript>
            var waypoints = [];
            var qWaypoints = queryExecute("
                SELECT wpId, name, latitude, longitude, notes
                FROM waypoints
                WHERE userId = :userId
                ORDER BY name ASC
            ", { userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" } }, { datasource = "fpw" });

            for (var i = 1; i LTE qWaypoints.recordCount; i++) {
                arrayAppend(waypoints, {
                    WAYPOINTID      = qWaypoints.wpId[i],
                    WAYPOINTNAME    = qWaypoints.name[i],
                    LATITUDE        = qWaypoints.latitude[i],
                    LONGITUDE       = qWaypoints.longitude[i],
                    NOTES           = qWaypoints.notes[i]
                });
            }
            return waypoints;
        </cfscript>
    </cffunction>

    <cffunction name="pickValue" access="private" returntype="any" output="false">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="keys" type="array" required="true">
        <cfargument name="defaultValue" required="false">
        <cfscript>
            for (var idx = 1; idx LTE arrayLen(arguments.keys); idx++) {
                var key = arguments.keys[idx];
                if (structKeyExists(arguments.source, key)) {
                    return arguments.source[key];
                }
            }
            return structKeyExists(arguments, "defaultValue") ? arguments.defaultValue : "";
        </cfscript>
    </cffunction>

    <cffunction name="booleanValue" access="private" returntype="boolean" output="false">
        <cfargument name="value" required="true">
        <cfscript>
            if (isBoolean(arguments.value)) {
                return arguments.value;
            }
            if (isNumeric(arguments.value)) {
                return val(arguments.value) NEQ 0;
            }
            var strVal = lcase(trim(arguments.value & ""));
            return listFindNoCase("true,yes,on,1", strVal) GT 0;
        </cfscript>
    </cffunction>

</cfcomponent>
