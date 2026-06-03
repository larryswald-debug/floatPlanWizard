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

            <cfif listFindNoCase("checkin,savecaptainlogentry,updatedailystart,adddelay,cleardelay,updateactivepace,updatepace,completeleg,startnextleg", actionName) GT 0>
                <cfset var activeCruiseAccessGate = getMemberAccessGateService().requirePremium(
                    userId = userId,
                    errorCode = "BASIC_ACTIVE_CRUISE_RESTRICTED",
                    message = "Upgrade to Premium to use Active Cruise actions and route-backed cruise updates."
                )>
                <cfif NOT activeCruiseAccessGate.allowed>
                    <cfoutput>#serializeJSON(activeCruiseAccessGate.response)#</cfoutput>
                    <cfsetting enablecfoutputonly="false">
                    <cfreturn>
                </cfif>
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
                    <cfif NOT structKeyExists(bootstrapData, "SUCCESS")>
                        <cfset bootstrapData.SUCCESS = true>
                    </cfif>
                    <cfset bootstrapData.AUTH = true>
                    <cfoutput>#serializeJSON(bootstrapData)#</cfoutput>
                </cfcase>

                <cfcase value="save">
                    <cfset var saveResult = saveFloatPlan(userId, body)>
                    <cfset saveResult.AUTH = true>
                    <cfoutput>#serializeJSON(saveResult)#</cfoutput>
                </cfcase>

                <cfcase value="savebasic">
                    <cfset var saveBasicResult = saveBasicFloatPlan(userId, body)>
                    <cfset saveBasicResult.AUTH = true>
                    <cfoutput>#serializeJSON(saveBasicResult)#</cfoutput>
                </cfcase>

                <cfcase value="getbasiccurrent">
                    <cfset var basicCurrentResult = getBasicOperationalCurrentPlan(userId)>
                    <cfset basicCurrentResult.AUTH = true>
                    <cfoutput>#serializeJSON(basicCurrentResult)#</cfoutput>
                </cfcase>

                <cfcase value="getbasicrescueauthorities">
                    <cfset var basicAuthorityResult = listBasicRescueAuthorities()>
                    <cfset basicAuthorityResult.AUTH = true>
                    <cfoutput>#serializeJSON(basicAuthorityResult)#</cfoutput>
                </cfcase>

                <cfcase value="listbasicdrafts">
                    <cfset var basicDraftsResult = listBasicOperationalDrafts(userId)>
                    <cfset basicDraftsResult.AUTH = true>
                    <cfoutput>#serializeJSON(basicDraftsResult)#</cfoutput>
                </cfcase>

                <cfcase value="getbasicdraft">
                    <cfset var basicDraftId = 0>
                    <cfif structKeyExists(body, "floatPlanId")>
                        <cfset basicDraftId = val(body.floatPlanId)>
                    <cfelseif structKeyExists(url, "floatPlanId")>
                        <cfset basicDraftId = val(url.floatPlanId)>
                    <cfelseif structKeyExists(url, "id")>
                        <cfset basicDraftId = val(url.id)>
                    </cfif>

                    <cfset var basicDraftResult = getBasicOperationalDraft(userId, basicDraftId)>
                    <cfset basicDraftResult.AUTH = true>
                    <cfoutput>#serializeJSON(basicDraftResult)#</cfoutput>
                </cfcase>

                <cfcase value="downloadbasicpdf">
                    <cfset var downloadBasicId = 0>
                    <cfif structKeyExists(body, "floatPlanId")>
                        <cfset downloadBasicId = val(body.floatPlanId)>
                    <cfelseif structKeyExists(url, "floatPlanId")>
                        <cfset downloadBasicId = val(url.floatPlanId)>
                    <cfelseif structKeyExists(url, "id")>
                        <cfset downloadBasicId = val(url.id)>
                    </cfif>

                    <cfset var downloadBasicResult = prepareBasicOperationalPdfDownload(userId, downloadBasicId)>
                    <cfif NOT downloadBasicResult.SUCCESS>
                        <cfset downloadBasicResult.AUTH = true>
                        <cfoutput>#serializeJSON(downloadBasicResult)#</cfoutput>
                    <cfelse>
                        <cfheader name="Content-Disposition" value="attachment; filename=""#downloadBasicResult.FILE_NAME#""">
                        <cfheader name="X-Content-Type-Options" value="nosniff">
                        <cfcontent type="application/pdf" file="#downloadBasicResult.FILE_PATH#" deletefile="false" reset="true">
                        <cfsetting enablecfoutputonly="false">
                        <cfreturn>
                    </cfif>
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

                <cfcase value="sendbasic">
                    <cfset var sendBasicId = 0>
                    <cfif structKeyExists(body, "floatPlanId")>
                        <cfset sendBasicId = val(body.floatPlanId)>
                    <cfelseif structKeyExists(url, "floatPlanId")>
                        <cfset sendBasicId = val(url.floatPlanId)>
                    <cfelseif structKeyExists(url, "id")>
                        <cfset sendBasicId = val(url.id)>
                    </cfif>

                    <cfset var sendBasicResult = sendBasicFloatPlanToContacts(userId, sendBasicId)>
                    <cfset sendBasicResult.AUTH = true>
                    <cfoutput>#serializeJSON(sendBasicResult)#</cfoutput>
                </cfcase>

                <cfcase value="closebasic">
                    <cfset var closeBasicId = 0>
                    <cfif structKeyExists(body, "floatPlanId")>
                        <cfset closeBasicId = val(body.floatPlanId)>
                    <cfelseif structKeyExists(url, "floatPlanId")>
                        <cfset closeBasicId = val(url.floatPlanId)>
                    <cfelseif structKeyExists(url, "id")>
                        <cfset closeBasicId = val(url.id)>
                    </cfif>

                    <cfset var closeBasicResult = closeBasicFloatPlan(userId, closeBasicId)>
                    <cfset closeBasicResult.AUTH = true>
                    <cfoutput>#serializeJSON(closeBasicResult)#</cfoutput>
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

                <cfcase value="cancel">
                    <cfset var cancelId = 0>
                    <cfif structKeyExists(body, "floatPlanId")>
                        <cfset cancelId = val(body.floatPlanId)>
                    <cfelseif structKeyExists(url, "floatPlanId")>
                        <cfset cancelId = val(url.floatPlanId)>
                    <cfelseif structKeyExists(url, "id")>
                        <cfset cancelId = val(url.id)>
                    </cfif>

                    <cfset var cancelResult = cancelFloatPlan(userId, cancelId)>
                    <cfset cancelResult.AUTH = true>
                    <cfoutput>#serializeJSON(cancelResult)#</cfoutput>
                </cfcase>

                <cfcase value="deleteallbyuser,deleteallbyuserid">
                    <cfset var targetUserId = 0>
                    <cfif structKeyExists(body, "targetUserId")>
                        <cfset targetUserId = val(body.targetUserId)>
                    <cfelseif structKeyExists(body, "userId")>
                        <cfset targetUserId = val(body.userId)>
                    <cfelseif structKeyExists(url, "targetUserId")>
                        <cfset targetUserId = val(url.targetUserId)>
                    <cfelseif structKeyExists(url, "userId")>
                        <cfset targetUserId = val(url.userId)>
                    </cfif>

                    <cfset var bulkDeleteResult = deleteAllFloatPlansByUser(userId, targetUserId)>
                    <cfset bulkDeleteResult.AUTH = true>
                    <cfoutput>#serializeJSON(bulkDeleteResult)#</cfoutput>
                </cfcase>

                <cfcase value="checkin">
                    <cfset var checkinId = 0>
                    <cfset var checkinStatus = trim(structKeyExists(body, "status") ? toString(body.status) : "")>
                    <cfset var checkinNote = (structKeyExists(body, "note") ? toString(body.note) : "")>
                    <cfset var checkinContext = trim(
                        structKeyExists(body, "checkinContext")
                            ? toString(body.checkinContext)
                            : (structKeyExists(body, "checkin_context") ? toString(body.checkin_context) : "")
                    )>
                    <cfif structKeyExists(body, "floatPlanId")>
                        <cfset checkinId = val(body.floatPlanId)>
                    <cfelseif structKeyExists(url, "floatPlanId")>
                        <cfset checkinId = val(url.floatPlanId)>
                    <cfelseif structKeyExists(url, "id")>
                        <cfset checkinId = val(url.id)>
                    </cfif>
                    <cfset var activeCruiseCheckinGuard = resolveCanonicalActiveFloatPlan(userId, checkinId)>
                    <cfif NOT activeCruiseCheckinGuard.SUCCESS>
                        <cfset activeCruiseCheckinGuard.AUTH = true>
                        <cfoutput>#serializeJSON(activeCruiseCheckinGuard)#</cfoutput>
                    <cfelseif compareNoCase(checkinStatus, "Arrived") EQ 0>
                        <cfset var arrivedCheckinResult = checkInFloatPlan(userId, checkinId)>
                        <cfset arrivedCheckinResult.AUTH = true>
                        <cfoutput>#serializeJSON(arrivedCheckinResult)#</cfoutput>
                    <cfelseif len(checkinStatus) OR structKeyExists(body, "note")>
                        <cfset var checkinLocation = (structKeyExists(body, "location") ? body.location : "")>
                        <cfset var cruiseCheckinResult = submitActiveCruiseCheckIn(userId, checkinId, checkinStatus, checkinNote, checkinContext, checkinLocation)>
                        <cfif structKeyExists(cruiseCheckinResult, "success") AND NOT structKeyExists(cruiseCheckinResult, "SUCCESS")>
                            <cfset cruiseCheckinResult.SUCCESS = cruiseCheckinResult.success>
                        </cfif>
                        <cfif structKeyExists(cruiseCheckinResult, "SUCCESS") AND NOT structKeyExists(cruiseCheckinResult, "success")>
                            <cfset cruiseCheckinResult.success = cruiseCheckinResult.SUCCESS>
                        </cfif>
                        <cfset cruiseCheckinResult.AUTH = true>
                        <cfset var cruiseCheckinJson = serializeJSON(cruiseCheckinResult)>
                        <cfcontent type="application/json; charset=utf-8" reset="true"><cfoutput>#cruiseCheckinJson#</cfoutput>
                        <cfsetting enablecfoutputonly="false">
                        <cfreturn>
                    <cfelse>
                        <cfset var checkinResult = checkInFloatPlan(userId, checkinId)>
                        <cfset checkinResult.AUTH = true>
                        <cfoutput>#serializeJSON(checkinResult)#</cfoutput>
                    </cfif>
                </cfcase>

                <cfcase value="savecaptainlogentry">
                    <cfset var captainLogResult = saveCaptainLogEntry(userId, body)>
                    <cfset captainLogResult.AUTH = true>
                    <cfoutput>#serializeJSON(captainLogResult)#</cfoutput>
                </cfcase>

                <cfcase value="updatedailystart">
                    <cfset var dailyStartId = 0>
                    <cfset var dailyStartValue = trim(
                        structKeyExists(body, "dailyStartLocalTime")
                            ? toString(body.dailyStartLocalTime)
                            : (structKeyExists(body, "daily_start_local_time") ? toString(body.daily_start_local_time) : "")
                    )>
                    <cfif structKeyExists(body, "floatPlanId")>
                        <cfset dailyStartId = val(body.floatPlanId)>
                    <cfelseif structKeyExists(url, "floatPlanId")>
                        <cfset dailyStartId = val(url.floatPlanId)>
                    <cfelseif structKeyExists(url, "id")>
                        <cfset dailyStartId = val(url.id)>
                    </cfif>
                    <cfset var activeCruiseDailyStartGuard = resolveCanonicalActiveFloatPlan(userId, dailyStartId)>
                    <cfif NOT activeCruiseDailyStartGuard.SUCCESS>
                        <cfset activeCruiseDailyStartGuard.AUTH = true>
                        <cfoutput>#serializeJSON(activeCruiseDailyStartGuard)#</cfoutput>
                    <cfelse>
                        <cfset var dailyStartResult = updateActiveCruiseDailyStart(userId, dailyStartId, dailyStartValue)>
                        <cfset dailyStartResult.AUTH = true>
                        <cfoutput>#serializeJSON(dailyStartResult)#</cfoutput>
                    </cfif>
                </cfcase>

                <cfcase value="adddelay">
                    <cfset var addDelayId = 0>
                    <cfset var addDelayMinutes = structKeyExists(body, "minutes") ? body.minutes : (structKeyExists(url, "minutes") ? url.minutes : "")>
                    <cfif structKeyExists(body, "floatPlanId")>
                        <cfset addDelayId = val(body.floatPlanId)>
                    <cfelseif structKeyExists(url, "floatPlanId")>
                        <cfset addDelayId = val(url.floatPlanId)>
                    <cfelseif structKeyExists(url, "id")>
                        <cfset addDelayId = val(url.id)>
                    </cfif>
                    <cfset var activeCruiseDelayGuard = resolveCanonicalActiveFloatPlan(userId, addDelayId)>
                    <cfif NOT activeCruiseDelayGuard.SUCCESS>
                        <cfset activeCruiseDelayGuard.AUTH = true>
                        <cfoutput>#serializeJSON(activeCruiseDelayGuard)#</cfoutput>
                    <cfelse>
                        <cfset var addDelayResult = addActiveCruiseDelayMinutes(userId, addDelayId, addDelayMinutes)>
                        <cfset addDelayResult.AUTH = true>
                        <cfoutput>#serializeJSON(addDelayResult)#</cfoutput>
                    </cfif>
                </cfcase>

                <cfcase value="cleardelay">
                    <cfset var clearDelayId = 0>
                    <cfif structKeyExists(body, "floatPlanId")>
                        <cfset clearDelayId = val(body.floatPlanId)>
                    <cfelseif structKeyExists(url, "floatPlanId")>
                        <cfset clearDelayId = val(url.floatPlanId)>
                    <cfelseif structKeyExists(url, "id")>
                        <cfset clearDelayId = val(url.id)>
                    </cfif>
                    <cfset var activeCruiseClearDelayGuard = resolveCanonicalActiveFloatPlan(userId, clearDelayId)>
                    <cfif NOT activeCruiseClearDelayGuard.SUCCESS>
                        <cfset activeCruiseClearDelayGuard.AUTH = true>
                        <cfoutput>#serializeJSON(activeCruiseClearDelayGuard)#</cfoutput>
                    <cfelse>
                        <cfset var clearDelayResult = clearActiveCruiseDelayMinutes(userId, clearDelayId)>
                        <cfset clearDelayResult.AUTH = true>
                        <cfoutput>#serializeJSON(clearDelayResult)#</cfoutput>
                    </cfif>
                </cfcase>

                <cfcase value="updateactivepace,updatepace">
                    <cfset var paceFloatPlanId = 0>
                    <cfset var paceValue = trim(
                        structKeyExists(body, "pace")
                            ? toString(body.pace)
                            : (structKeyExists(url, "pace") ? toString(url.pace) : "")
                    )>
                    <cfif structKeyExists(body, "floatPlanId")>
                        <cfset paceFloatPlanId = val(body.floatPlanId)>
                    <cfelseif structKeyExists(url, "floatPlanId")>
                        <cfset paceFloatPlanId = val(url.floatPlanId)>
                    <cfelseif structKeyExists(url, "id")>
                        <cfset paceFloatPlanId = val(url.id)>
                    </cfif>
                    <cfset var activeCruisePaceGuard = resolveCanonicalActiveFloatPlan(userId, paceFloatPlanId)>
                    <cfif NOT activeCruisePaceGuard.SUCCESS>
                        <cfset activeCruisePaceGuard.AUTH = true>
                        <cfoutput>#serializeJSON(activeCruisePaceGuard)#</cfoutput>
                    <cfelse>
                        <cfset var activeTripPaceService = createObject("component", resolveApiV1ComponentPath("ActiveTripPaceService")).init("fpw")>
                        <cfset var paceUpdateResult = activeTripPaceService.persistActiveTripPace(userId, paceFloatPlanId, paceValue)>
                        <cfset paceUpdateResult.AUTH = true>
                        <cfoutput>#serializeJSON(paceUpdateResult)#</cfoutput>
                    </cfif>
                </cfcase>

                <cfcase value="completeleg">
                    <cfset var completeLegId = 0>
                    <cfset var expectedLegOrder = 0>
                    <cfset var completeLegMonitoringService = {}>
                    <cfset var completeLegMonitoringRefreshResult = {}>
                    <cfset var completeLegCanonicalActivityService = {}>
                    <cfset var completeLegCanonicalActivityResult = {}>
                    <cfif structKeyExists(body, "floatPlanId")>
                        <cfset completeLegId = val(body.floatPlanId)>
                    <cfelseif structKeyExists(url, "floatPlanId")>
                        <cfset completeLegId = val(url.floatPlanId)>
                    <cfelseif structKeyExists(url, "id")>
                        <cfset completeLegId = val(url.id)>
                    </cfif>
                    <cfif structKeyExists(body, "expectedLegOrder")>
                        <cfset expectedLegOrder = val(body.expectedLegOrder)>
                    <cfelseif structKeyExists(url, "expectedLegOrder")>
                        <cfset expectedLegOrder = val(url.expectedLegOrder)>
                    </cfif>

                    <cfset var activeCruiseLegGuard = resolveCanonicalActiveFloatPlan(userId, completeLegId)>
                    <cfif NOT activeCruiseLegGuard.SUCCESS>
                        <cfset activeCruiseLegGuard.AUTH = true>
                        <cfoutput>#serializeJSON(activeCruiseLegGuard)#</cfoutput>
                    <cfelse>
                        <cfset var routeProgressService = createObject("component", resolveApiV1ComponentPath("RouteProgressService")).init()>
                        <cfset var completeLegResult = routeProgressService.markCompletionFromFloatPlanCheckin(
                            userId = userId,
                            floatPlanId = completeLegId,
                            datasource = "fpw",
                            completionMode = "active_leg",
                            expectedLegOrder = expectedLegOrder
                        )>

                        <cfif structKeyExists(completeLegResult, "SUCCESS") AND completeLegResult.SUCCESS EQ true AND structKeyExists(completeLegResult, "COMPLETED") AND completeLegResult.COMPLETED EQ true>
                            <cftry>
                                <cfset completeLegMonitoringService = createObject("component", resolveApiV1ComponentPath("monitor")).init()>
                                <cfset completeLegMonitoringRefreshResult = completeLegMonitoringService.refreshActiveRouteCheckpointFromLegCompletion(
                                    floatPlanId = completeLegId,
                                    routeInstanceId = (structKeyExists(completeLegResult, "ROUTE_INSTANCE_ID") ? val(completeLegResult.ROUTE_INSTANCE_ID) : 0),
                                    legOrder = (structKeyExists(completeLegResult, "LEG_ORDER") ? val(completeLegResult.LEG_ORDER) : 0)
                                )>
                                <cfcatch type="any">
                                    <cfset completeLegMonitoringRefreshResult = {
                                        SUCCESS = false,
                                        UPDATED = false,
                                        ERROR = "MONITORING_COMPLETION_REFRESH_FAILED",
                                        MESSAGE = cfcatch.message
                                    }>
                                </cfcatch>
                            </cftry>
                            <cfset completeLegResult.MONITORING_REFRESH = completeLegMonitoringRefreshResult>
                            <cftry>
                                <cfset completeLegCanonicalActivityService = createObject("component", resolveApiV1ComponentPath("TripActivityWriterService")).init("fpw")>
                                <cfset completeLegCanonicalActivityResult = completeLegCanonicalActivityService.recordActiveCruiseRouteAction(
                                    floatPlanId = completeLegId,
                                    userId = userId,
                                    eventType = "ROUTE_LEG_COMPLETED",
                                    actionLabel = "Complete Current Leg / Arrived",
                                    statusLabel = "Leg completed",
                                    occurredAtUtc = now(),
                                    routeInstanceId = (structKeyExists(completeLegResult, "ROUTE_INSTANCE_ID") ? val(completeLegResult.ROUTE_INSTANCE_ID) : 0),
                                    routeLegOrder = (structKeyExists(completeLegResult, "LEG_ORDER") ? val(completeLegResult.LEG_ORDER) : 0),
                                    endpointResult = completeLegResult,
                                    payload = {
                                        "completion_mode" = "active_leg"
                                    }
                                )>
                                <cfif NOT structKeyExists(completeLegCanonicalActivityResult, "SUCCESS") OR completeLegCanonicalActivityResult.SUCCESS NEQ true>
                                    <cfset writeLog(
                                        file = "fpw-canonical-activity",
                                        type = "warning",
                                        text = "Route action event write failed for completeleg floatPlanId=" & completeLegId & " result=" & left(serializeJSON(completeLegCanonicalActivityResult), 1000)
                                    )>
                                </cfif>
                                <cfcatch type="any">
                                    <cfset writeLog(
                                        file = "fpw-canonical-activity",
                                        type = "warning",
                                        text = "Route action event writer exception for completeleg floatPlanId=" & completeLegId & " message=" & left(trim(toString(cfcatch.message)), 500)
                                    )>
                                </cfcatch>
                            </cftry>
                        </cfif>

                        <cfset completeLegResult.AUTH = true>
                        <cfoutput>#serializeJSON(completeLegResult)#</cfoutput>
                    </cfif>
                </cfcase>

                <cfcase value="startnextleg">
                    <cfset var startNextLegId = 0>
                    <cfset var activeCruiseStartGuard = {}>
                    <cfset var startNextLegRouteProgressService = {}>
                    <cfset var startNextLegMonitoringService = {}>
                    <cfset var startNextLegResult = {}>
                    <cfset var startNextLegMonitoringRefreshResult = {}>
                    <cfset var qStartNextLegPlan = queryNew("")>
                    <cfset var startNextLegCheckInContext = "">
                    <cfset var startNextLegCanonicalActivityService = {}>
                    <cfset var startNextLegCanonicalActivityResult = {}>
                    <cfif structKeyExists(body, "floatPlanId")>
                        <cfset startNextLegId = val(body.floatPlanId)>
                    <cfelseif structKeyExists(url, "floatPlanId")>
                        <cfset startNextLegId = val(url.floatPlanId)>
                    <cfelseif structKeyExists(url, "id")>
                        <cfset startNextLegId = val(url.id)>
                    </cfif>

                    <cfset activeCruiseStartGuard = resolveCanonicalActiveFloatPlan(userId, startNextLegId)>
                    <cfif NOT activeCruiseStartGuard.SUCCESS>
                        <cfset activeCruiseStartGuard.AUTH = true>
                        <cfoutput>#serializeJSON(activeCruiseStartGuard)#</cfoutput>
                    <cfelse>
                        <cfset qStartNextLegPlan = queryExecute(
                            "SELECT checkin_context
                             FROM floatplans
                             WHERE floatplanId = :planId
                               AND userId = :userId
                             LIMIT 1",
                            {
                                planId = { value = startNextLegId, cfsqltype = "cf_sql_integer" },
                                userId = { value = userId, cfsqltype = "cf_sql_integer" }
                            },
                            { datasource = "fpw" }
                        )>
                        <cfif qStartNextLegPlan.recordCount EQ 1>
                            <cfset startNextLegCheckInContext = normalizeCheckInContext(isNull(qStartNextLegPlan.checkin_context[1]) ? "" : qStartNextLegPlan.checkin_context[1])>
                        </cfif>

                        <cfset startNextLegRouteProgressService = createObject("component", resolveApiV1ComponentPath("RouteProgressService")).init()>
                        <cfset startNextLegResult = startNextLegRouteProgressService.startNextPendingLegForFloatPlan(
                            userId = userId,
                            floatPlanId = startNextLegId,
                            datasource = "fpw"
                        )>

                        <cfif structKeyExists(startNextLegResult, "SUCCESS") AND startNextLegResult.SUCCESS EQ true>
                            <cfset queryExecute(
                                "UPDATE floatplans
                                 SET checkin_context = NULL,
                                     lastUpdateStatus = UTC_TIMESTAMP()
                                 WHERE floatplanId = :planId
                                   AND userId = :userId",
                                {
                                    planId = { value = startNextLegId, cfsqltype = "cf_sql_integer" },
                                    userId = { value = userId, cfsqltype = "cf_sql_integer" }
                                },
                                { datasource = "fpw" }
                            )>
                            <cfset startNextLegResult.CLEARED_CHECKIN_CONTEXT = (len(startNextLegCheckInContext) GT 0)>

                            <cftry>
                                <cfset startNextLegMonitoringService = createObject("component", resolveApiV1ComponentPath("monitor")).init()>
                                <cfset startNextLegMonitoringRefreshResult = startNextLegMonitoringService.refreshActiveRouteCheckpointFromLegStart(
                                    floatPlanId = startNextLegId,
                                    routeInstanceId = (structKeyExists(startNextLegResult, "ROUTE_INSTANCE_ID") ? val(startNextLegResult.ROUTE_INSTANCE_ID) : 0),
                                    legOrder = (structKeyExists(startNextLegResult, "LEG_ORDER") ? val(startNextLegResult.LEG_ORDER) : 0)
                                )>
                                <cfcatch type="any">
                                    <cfset startNextLegMonitoringRefreshResult = {
                                        SUCCESS = false,
                                        UPDATED = false,
                                        ERROR = "MONITORING_REFRESH_FAILED",
                                        MESSAGE = cfcatch.message
                                    }>
                                </cfcatch>
                            </cftry>
                            <cfset startNextLegResult.MONITORING_REFRESH = startNextLegMonitoringRefreshResult>
                            <cfif structKeyExists(startNextLegResult, "STARTED") AND startNextLegResult.STARTED EQ true>
                                <cftry>
                                    <cfset startNextLegCanonicalActivityService = createObject("component", resolveApiV1ComponentPath("TripActivityWriterService")).init("fpw")>
                                    <cfset startNextLegCanonicalActivityResult = startNextLegCanonicalActivityService.recordActiveCruiseRouteAction(
                                        floatPlanId = startNextLegId,
                                        userId = userId,
                                        eventType = "ROUTE_LEG_STARTED",
                                        actionLabel = "Start Next Leg",
                                        statusLabel = "Leg started",
                                        occurredAtUtc = now(),
                                        routeInstanceId = (structKeyExists(startNextLegResult, "ROUTE_INSTANCE_ID") ? val(startNextLegResult.ROUTE_INSTANCE_ID) : 0),
                                        routeLegOrder = (structKeyExists(startNextLegResult, "LEG_ORDER") ? val(startNextLegResult.LEG_ORDER) : 0),
                                        endpointResult = startNextLegResult,
                                        payload = {
                                            "cleared_checkin_context" = (structKeyExists(startNextLegResult, "CLEARED_CHECKIN_CONTEXT") ? startNextLegResult.CLEARED_CHECKIN_CONTEXT : false)
                                        }
                                    )>
                                    <cfif NOT structKeyExists(startNextLegCanonicalActivityResult, "SUCCESS") OR startNextLegCanonicalActivityResult.SUCCESS NEQ true>
                                        <cfset writeLog(
                                            file = "fpw-canonical-activity",
                                            type = "warning",
                                            text = "Route action event write failed for startnextleg floatPlanId=" & startNextLegId & " result=" & left(serializeJSON(startNextLegCanonicalActivityResult), 1000)
                                        )>
                                    </cfif>
                                    <cfcatch type="any">
                                        <cfset writeLog(
                                            file = "fpw-canonical-activity",
                                            type = "warning",
                                            text = "Route action event writer exception for startnextleg floatPlanId=" & startNextLegId & " message=" & left(trim(toString(cfcatch.message)), 500)
                                        )>
                                    </cfcatch>
                                </cftry>
                            </cfif>
                        </cfif>

                        <cfset startNextLegResult.AUTH = true>
                        <cfoutput>#serializeJSON(startNextLegResult)#</cfoutput>
                    </cfif>
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
                PLAN_WAYPOINTS  = [],
                ROUTE_DEFAULTS  = {}
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

            var routeDefaults = buildRouteDefaults(
                userId = arguments.userId,
                floatPlan = response.FLOATPLAN,
                operators = response.OPERATORS,
                waypoints = response.WAYPOINTS
            );
            response.ROUTE_DEFAULTS = routeDefaults;

            if (routeDefaults.IS_FROM_ROUTE) {
                if (!arrayLen(response.PLAN_WAYPOINTS) AND arrayLen(routeDefaults.WAYPOINT_SELECTIONS)) {
                    response.PLAN_WAYPOINTS = routeDefaults.WAYPOINT_SELECTIONS;
                }
                if (arrayLen(routeDefaults.WAYPOINT_OPTIONS)) {
                    response.WAYPOINTS = mergeWaypointOptions(response.WAYPOINTS, routeDefaults.WAYPOINT_OPTIONS);
                }

                if (val(response.FLOATPLAN.OPERATORID) LTE 0 AND val(routeDefaults.OPERATOR_ID) GT 0) {
                    response.FLOATPLAN.OPERATORID = val(routeDefaults.OPERATOR_ID);
                }
                if (!len(trim(toString(response.FLOATPLAN.DEPARTING_FROM))) AND len(trim(toString(routeDefaults.DEPARTING_FROM_DEFAULT)))) {
                    response.FLOATPLAN.DEPARTING_FROM = routeDefaults.DEPARTING_FROM_DEFAULT;
                }
                if (!len(trim(toString(response.FLOATPLAN.RETURNING_TO))) AND len(trim(toString(routeDefaults.RETURNING_TO_DEFAULT)))) {
                    response.FLOATPLAN.RETURNING_TO = routeDefaults.RETURNING_TO_DEFAULT;
                }

            }

            return response;
        </cfscript>
    </cffunction>

    <cffunction name="userOwnsRouteInstance" access="private" returntype="boolean" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfscript>
            if (arguments.userId LTE 0 OR arguments.routeInstanceId LTE 0) {
                return false;
            }

            var qRouteInstance = queryExecute(
                "SELECT id
                   FROM route_instances
                  WHERE id = :routeInstanceId
                    AND user_id = :userId
                  LIMIT 1",
                {
                    routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" },
                    userId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" }
                },
                { datasource = "fpw" }
            );

            return qRouteInstance.recordCount GT 0;
        </cfscript>
    </cffunction>

    <cffunction name="buildFreshOperationalRouteCode" access="private" returntype="string" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var attempt = 0;
            var candidate = "";
            var qExists = queryNew("");

            for (attempt = 1; attempt LTE 10; attempt++) {
                candidate = left("FPWOP_" & arguments.floatPlanId & "_" & lCase(replace(createUUID(), "-", "", "all")), 40);
                qExists = queryExecute(
                    "SELECT
                        (
                            SELECT COUNT(*)
                            FROM loop_routes
                            WHERE code = :code
                               OR short_code = :code
                        ) +
                        (
                            SELECT COUNT(*)
                            FROM route_instances
                            WHERE generated_route_code = :code
                        ) AS code_count",
                    {
                        code = { value = candidate, cfsqltype = "cf_sql_varchar" }
                    },
                    { datasource = "fpw" }
                );
                if (qExists.recordCount EQ 1 AND val(qExists.code_count[1]) EQ 0) {
                    return candidate;
                }
            }

            throw(type = "RouteActivationFreshRouteCode", message = "Unable to generate a unique operational route code.");
        </cfscript>
    </cffunction>

    <cffunction name="loadRouteInstanceActivationHistory" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfscript>
            var result = {
                SUCCESS = false,
                ROUTE_INSTANCE_ID = arguments.routeInstanceId,
                ROUTE_LEG_COUNT = 0,
                PROGRESS_ROW_COUNT = 0,
                OPERATIONAL_PROGRESS_COUNT = 0,
                VALID_MONITORING_FOR_PLAN_COUNT = 0,
                OTHER_MONITORING_COUNT = 0,
                ACTIVITY_SEGMENT_COUNT = 0,
                ROUTE_EVENT_COUNT = 0,
                HISTORICAL_PLAN_COUNT = 0,
                HAS_OPERATIONAL_HISTORY = false
            };
            var qHistory = queryNew("");

            if (arguments.userId LTE 0 OR arguments.floatPlanId LTE 0 OR arguments.routeInstanceId LTE 0) {
                result.ERROR = "INVALID_ROUTE_HISTORY_INPUT";
                result.MESSAGE = "A valid user, float plan, and route instance are required.";
                return result;
            }

            qHistory = queryExecute(
                "SELECT
                    COUNT(DISTINCT ril.id) AS route_leg_count,
                    COUNT(DISTINCT rilp.id) AS progress_row_count,
                    SUM(
                        CASE
                            WHEN rilp.id IS NOT NULL
                             AND (
                                rilp.leg_started_at IS NOT NULL
                                OR rilp.completed_at IS NOT NULL
                                OR UPPER(TRIM(COALESCE(rilp.status, ''))) <> 'NOT_STARTED'
                             )
                            THEN 1 ELSE 0
                        END
                    ) AS operational_progress_count,
                    (
                        SELECT COUNT(*)
                        FROM floatplan_monitoring fm
                        INNER JOIN floatplans mfp
                           ON mfp.floatPlanId = fm.float_plan_id
                        WHERE mfp.userId = :userId
                          AND mfp.route_instance_id = :routeInstanceId
                          AND mfp.floatPlanId = :floatPlanId
                          AND fm.monitor_state = 'ACTIVE'
                          AND fm.is_monitoring_enabled = 1
                          AND fm.closed_at IS NULL
                    ) AS valid_monitoring_for_plan_count,
                    (
                        SELECT COUNT(*)
                        FROM floatplan_monitoring fm
                        INNER JOIN floatplans mfp
                           ON mfp.floatPlanId = fm.float_plan_id
                        WHERE mfp.userId = :userId
                          AND mfp.route_instance_id = :routeInstanceId
                          AND mfp.floatPlanId <> :floatPlanId
                    ) AS other_monitoring_count,
                    (
                        SELECT COUNT(*)
                        FROM floatplan_activity_segments fas
                        WHERE fas.user_id = :userId
                          AND fas.route_instance_id = :routeInstanceId
                    ) AS activity_segment_count,
                    (
                        SELECT COUNT(*)
                        FROM floatplan_events fe
                        WHERE fe.user_id = :userId
                          AND fe.route_instance_id = :routeInstanceId
                    ) AS route_event_count,
                    (
                        SELECT COUNT(*)
                        FROM floatplans hfp
                        WHERE hfp.userId = :userId
                          AND hfp.route_instance_id = :routeInstanceId
                          AND hfp.floatPlanId <> :floatPlanId
                          AND (
                              hfp.activatedAt IS NOT NULL
                              OR hfp.initialSentAt IS NOT NULL
                              OR hfp.closedAt IS NOT NULL
                              OR UPPER(TRIM(COALESCE(hfp.`status`, ''))) IN ('ACTIVE', 'CLOSED', 'CANCELLED', 'CANCELED')
                          )
                    ) AS historical_plan_count
                 FROM route_instance_legs ril
                 LEFT JOIN route_instance_leg_progress rilp
                   ON rilp.route_instance_id = ril.route_instance_id
                  AND rilp.leg_order = ril.leg_order
                  AND rilp.user_id = :userId
                 WHERE ril.route_instance_id = :routeInstanceId",
                {
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                    floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = "fpw" }
            );

            if (qHistory.recordCount NEQ 1) {
                result.ERROR = "ROUTE_HISTORY_NOT_FOUND";
                result.MESSAGE = "Route activation history could not be loaded.";
                return result;
            }

            result.SUCCESS = true;
            result.ROUTE_LEG_COUNT = val(qHistory.route_leg_count[1]);
            result.PROGRESS_ROW_COUNT = val(qHistory.progress_row_count[1]);
            result.OPERATIONAL_PROGRESS_COUNT = val(qHistory.operational_progress_count[1]);
            result.VALID_MONITORING_FOR_PLAN_COUNT = val(qHistory.valid_monitoring_for_plan_count[1]);
            result.OTHER_MONITORING_COUNT = val(qHistory.other_monitoring_count[1]);
            result.ACTIVITY_SEGMENT_COUNT = val(qHistory.activity_segment_count[1]);
            result.ROUTE_EVENT_COUNT = val(qHistory.route_event_count[1]);
            result.HISTORICAL_PLAN_COUNT = val(qHistory.historical_plan_count[1]);
            result.HAS_OPERATIONAL_HISTORY = (
                result.OPERATIONAL_PROGRESS_COUNT GT 0
                OR result.OTHER_MONITORING_COUNT GT 0
                OR result.ACTIVITY_SEGMENT_COUNT GT 0
                OR result.ROUTE_EVENT_COUNT GT 0
                OR result.HISTORICAL_PLAN_COUNT GT 0
            );
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="ensureRouteInstanceCleanProgressRows" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfscript>
            var result = {
                SUCCESS = false,
                ROUTE_INSTANCE_ID = arguments.routeInstanceId,
                ROUTE_LEG_COUNT = 0,
                PROGRESS_ROW_COUNT = 0,
                NOT_STARTED_ROWS = 0,
                OPERATIONAL_PROGRESS_COUNT = 0
            };
            var qCounts = queryNew("");

            queryExecute(
                "INSERT INTO route_instance_leg_progress
                    (user_id, route_instance_id, leg_order, status, leg_started_at, completed_at)
                 SELECT
                    :userId,
                    ril.route_instance_id,
                    ril.leg_order,
                    'NOT_STARTED',
                    NULL,
                    NULL
                 FROM route_instance_legs ril
                 WHERE ril.route_instance_id = :routeInstanceId
                   AND NOT EXISTS (
                       SELECT 1
                       FROM route_instance_leg_progress existing
                       WHERE existing.user_id = :userId
                         AND existing.route_instance_id = ril.route_instance_id
                         AND existing.leg_order = ril.leg_order
                   )
                 ORDER BY ril.leg_order ASC",
                {
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                    routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = "fpw" }
            );

            qCounts = queryExecute(
                "SELECT
                    COUNT(DISTINCT ril.id) AS route_leg_count,
                    COUNT(DISTINCT rilp.id) AS progress_row_count,
                    SUM(
                        CASE
                            WHEN rilp.id IS NOT NULL
                             AND UPPER(TRIM(COALESCE(rilp.status, ''))) = 'NOT_STARTED'
                             AND rilp.leg_started_at IS NULL
                             AND rilp.completed_at IS NULL
                            THEN 1 ELSE 0
                        END
                    ) AS not_started_rows,
                    SUM(
                        CASE
                            WHEN rilp.id IS NOT NULL
                             AND (
                                rilp.leg_started_at IS NOT NULL
                                OR rilp.completed_at IS NOT NULL
                                OR UPPER(TRIM(COALESCE(rilp.status, ''))) <> 'NOT_STARTED'
                             )
                            THEN 1 ELSE 0
                        END
                    ) AS operational_progress_count
                 FROM route_instance_legs ril
                 LEFT JOIN route_instance_leg_progress rilp
                   ON rilp.route_instance_id = ril.route_instance_id
                  AND rilp.leg_order = ril.leg_order
                  AND rilp.user_id = :userId
                 WHERE ril.route_instance_id = :routeInstanceId",
                {
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                    routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = "fpw" }
            );

            result.ROUTE_LEG_COUNT = val(qCounts.route_leg_count[1]);
            result.PROGRESS_ROW_COUNT = val(qCounts.progress_row_count[1]);
            result.NOT_STARTED_ROWS = val(qCounts.not_started_rows[1]);
            result.OPERATIONAL_PROGRESS_COUNT = val(qCounts.operational_progress_count[1]);

            if (result.ROUTE_LEG_COUNT LTE 0) {
                result.ERROR = "ROUTE_LEGS_REQUIRED";
                result.MESSAGE = "Route legs are required before activating this float plan.";
                return result;
            }
            if (
                result.PROGRESS_ROW_COUNT NEQ result.ROUTE_LEG_COUNT
                OR result.NOT_STARTED_ROWS NEQ result.ROUTE_LEG_COUNT
                OR result.OPERATIONAL_PROGRESS_COUNT GT 0
            ) {
                result.ERROR = "ROUTE_PROGRESS_NOT_CLEAN";
                result.MESSAGE = "Route progress must be clean before scheduled monitoring can be initialized.";
                return result;
            }

            result.SUCCESS = true;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="createFreshOperationalRouteInstanceFromTemplate" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="sourceRouteInstanceId" type="numeric" required="true">
        <cfscript>
            var result = {
                SUCCESS = false,
                SOURCE_ROUTE_INSTANCE_ID = arguments.sourceRouteInstanceId,
                ROUTE_INSTANCE_ID = 0,
                ROUTE_CODE = "",
                GENERATED_ROUTE_ID = 0
            };
            var qSource = queryNew("");
            var qSections = queryNew("");
            var qLegs = queryNew("");
            var routeCode = "";
            var routeName = "";
            var routeDescription = "";
            var templateRouteCode = "";
            var directionVal = "";
            var tripTypeVal = "";
            var startLocationVal = "";
            var endLocationVal = "";
            var inputsJson = "";
            var sourceDescription = "";
            var totalNmIsNull = true;
            var totalLocksIsNull = true;
            var totalNmVal = 0;
            var totalLocksVal = 0;
            var newRouteId = 0;
            var newRouteInstanceId = 0;
            var sectionIdBySource = {};
            var sectionIndex = 0;
            var legIndex = 0;
            var sourceSectionId = 0;
            var newSectionId = 0;
            var segmentId = 0;
            var sourceLoopSegmentId = 0;
            var detourCode = "";
            var startName = "";
            var endName = "";
            var startLatIsNull = true;
            var startLngIsNull = true;
            var endLatIsNull = true;
            var endLngIsNull = true;
            var baseDistIsNull = true;
            var lockCountIsNull = true;
            var notesVal = "";
            var freshRouteInsertResult = {};
            var freshInstanceInsertResult = {};
            var freshSectionInsertResult = {};
            var sourceInputs = {};
            var sourceInputKeys = [];
            var sourceInputIndex = 0;
            var sourceInputKey = "";
            var sourceGeneratedRouteId = 0;
            var sourceRouteCode = "";
            var sourceUserRouteId = 0;

            try {
                qSource = queryExecute(
                    "SELECT
                        ri.id,
                        ri.generated_route_id,
                        ri.generated_route_code,
                        ri.template_route_code,
                        ri.direction,
                        ri.trip_type,
                        ri.start_location,
                        ri.end_location,
                        ri.routegen_inputs_json,
                        lr.short_code AS route_short_code,
                        lr.name AS route_name,
                        lr.description AS route_description,
                        lr.total_nm,
                        lr.total_locks
                     FROM route_instances ri
                     LEFT JOIN loop_routes lr
                       ON lr.id = ri.generated_route_id
                     WHERE ri.id = :routeInstanceId
                       AND ri.user_id = :userId
                     LIMIT 1",
                    {
                        routeInstanceId = { value = arguments.sourceRouteInstanceId, cfsqltype = "cf_sql_integer" },
                        userId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" }
                    },
                    { datasource = "fpw" }
                );

                if (qSource.recordCount NEQ 1) {
                    result.ERROR = "SOURCE_ROUTE_INSTANCE_NOT_FOUND";
                    result.MESSAGE = "The source route instance could not be found.";
                    return result;
                }

                qSections = queryExecute(
                    "SELECT id, section_order, name, phase_num, source_section_id
                     FROM route_instance_sections
                     WHERE route_instance_id = :routeInstanceId
                     ORDER BY section_order ASC, id ASC",
                    {
                        routeInstanceId = { value = arguments.sourceRouteInstanceId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = "fpw" }
                );

                qLegs = queryExecute(
                    "SELECT
                        route_instance_section_id,
                        leg_order,
                        segment_id,
                        source_loop_segment_id,
                        is_reversed,
                        is_optional,
                        detour_code,
                        start_name,
                        end_name,
                        start_lat,
                        start_lng,
                        end_lat,
                        end_lng,
                        base_dist_nm,
                        lock_count,
                        notes
                     FROM route_instance_legs
                     WHERE route_instance_id = :routeInstanceId
                     ORDER BY leg_order ASC, id ASC",
                    {
                        routeInstanceId = { value = arguments.sourceRouteInstanceId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = "fpw" }
                );

                if (qLegs.recordCount LTE 0) {
                    result.ERROR = "SOURCE_ROUTE_LEGS_REQUIRED";
                    result.MESSAGE = "The source route instance has no normalized legs.";
                    return result;
                }

                routeCode = buildFreshOperationalRouteCode(arguments.floatPlanId);
                routeName = trim(toString(qSource.route_name[1]));
                if (!len(routeName)) {
                    routeName = "Float Plan Route";
                }
                sourceDescription = isNull(qSource.route_description[1]) ? "" : trim(toString(qSource.route_description[1]));
                routeDescription = "Operational copy for float plan " & arguments.floatPlanId & " from route instance " & arguments.sourceRouteInstanceId;
                if (len(sourceDescription)) {
                    routeDescription = left(routeDescription & ". " & sourceDescription, 255);
                }
                templateRouteCode = trim(toString(qSource.template_route_code[1]));
                directionVal = trim(toString(qSource.direction[1]));
                if (!len(directionVal)) {
                    directionVal = "CCW";
                }
                tripTypeVal = trim(toString(qSource.trip_type[1]));
                if (!len(tripTypeVal)) {
                    tripTypeVal = "POINT_TO_POINT";
                }
                startLocationVal = trim(toString(qSource.start_location[1]));
                endLocationVal = isNull(qSource.end_location[1]) ? "" : trim(toString(qSource.end_location[1]));
                inputsJson = isNull(qSource.routegen_inputs_json[1]) ? "" : toString(qSource.routegen_inputs_json[1]);
                sourceInputs = parseRouteInputs(inputsJson);
                sourceInputKeys = structKeyArray(sourceInputs);
                for (sourceInputIndex = 1; sourceInputIndex LTE arrayLen(sourceInputKeys); sourceInputIndex++) {
                    sourceInputKey = sourceInputKeys[sourceInputIndex];
                    if (left(uCase(sourceInputKey), 12) EQ "ACTIVE_TRIP_") {
                        structDelete(sourceInputs, sourceInputKey, false);
                    }
                }
                sourceGeneratedRouteId = isNull(qSource.generated_route_id[1]) ? 0 : val(qSource.generated_route_id[1]);
                sourceRouteCode = trim(toString(isNull(qSource.route_short_code[1]) ? "" : qSource.route_short_code[1]));
                if (!len(sourceRouteCode)) {
                    sourceRouteCode = trim(toString(isNull(qSource.generated_route_code[1]) ? "" : qSource.generated_route_code[1]));
                }
                sourceUserRouteId = structKeyExists(sourceInputs, "route_id") ? val(sourceInputs.route_id) : 0;
                sourceInputs.source_route_instance_id = arguments.sourceRouteInstanceId;
                if (sourceGeneratedRouteId GT 0) {
                    sourceInputs.source_generated_route_id = sourceGeneratedRouteId;
                }
                if (len(sourceRouteCode)) {
                    sourceInputs.source_route_code = sourceRouteCode;
                }
                if (sourceUserRouteId GT 0) {
                    sourceInputs.source_user_route_id = sourceUserRouteId;
                }
                if (len(templateRouteCode)) {
                    sourceInputs.source_template_route_code = templateRouteCode;
                }
                try {
                    inputsJson = serializeJSON(sourceInputs);
                } catch (any sourceInputsSerializeErr) {
                    result.ERROR = "FRESH_ROUTE_SOURCE_METADATA_FAILED";
                    result.MESSAGE = "Unable to prepare source metadata for this activation.";
                    result.DETAIL = sourceInputsSerializeErr.message;
                    return result;
                }
                totalNmIsNull = (isNull(qSource.total_nm[1]) OR !len(trim(toString(qSource.total_nm[1]))));
                totalLocksIsNull = (isNull(qSource.total_locks[1]) OR !len(trim(toString(qSource.total_locks[1]))));
                totalNmVal = totalNmIsNull ? 0 : val(qSource.total_nm[1]);
                totalLocksVal = totalLocksIsNull ? 0 : val(qSource.total_locks[1]);

                transaction {
                    queryExecute(
                        "INSERT INTO loop_routes
                            (code, name, short_code, description, is_active, version, is_default, total_nm, total_locks)
                         VALUES
                            (:code, :name, :shortCode, :description, 1, 1, 0, :totalNm, :totalLocks)",
                        {
                            code = { value = routeCode, cfsqltype = "cf_sql_varchar" },
                            name = { value = routeName, cfsqltype = "cf_sql_varchar" },
                            shortCode = { value = routeCode, cfsqltype = "cf_sql_varchar" },
                            description = { value = routeDescription, cfsqltype = "cf_sql_varchar", null = NOT len(routeDescription) },
                            totalNm = { value = totalNmVal, cfsqltype = "cf_sql_decimal", null = totalNmIsNull },
                            totalLocks = { value = totalLocksVal, cfsqltype = "cf_sql_integer", null = totalLocksIsNull }
                        },
                        { datasource = "fpw", result = "freshRouteInsertResult" }
                    );
                    newRouteId = val(freshRouteInsertResult.generatedKey);

                    queryExecute(
                        "INSERT INTO route_instances
                            (user_id, template_route_code, generated_route_id, generated_route_code, direction, trip_type, start_location, end_location, routegen_inputs_json, status)
                         VALUES
                            (:userId, :templateRouteCode, :generatedRouteId, :generatedRouteCode, :direction, :tripType, :startLocation, :endLocation, :routegenInputsJson, 'PLANNED')",
                        {
                            userId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" },
                            templateRouteCode = { value = templateRouteCode, cfsqltype = "cf_sql_varchar" },
                            generatedRouteId = { value = newRouteId, cfsqltype = "cf_sql_integer" },
                            generatedRouteCode = { value = routeCode, cfsqltype = "cf_sql_varchar" },
                            direction = { value = directionVal, cfsqltype = "cf_sql_varchar" },
                            tripType = { value = tripTypeVal, cfsqltype = "cf_sql_varchar" },
                            startLocation = { value = startLocationVal, cfsqltype = "cf_sql_varchar" },
                            endLocation = { value = endLocationVal, cfsqltype = "cf_sql_varchar", null = NOT len(endLocationVal) },
                            routegenInputsJson = { value = inputsJson, cfsqltype = "cf_sql_longvarchar", null = NOT len(inputsJson) }
                        },
                        { datasource = "fpw", result = "freshInstanceInsertResult" }
                    );
                    newRouteInstanceId = val(freshInstanceInsertResult.generatedKey);

                    for (sectionIndex = 1; sectionIndex LTE qSections.recordCount; sectionIndex++) {
                        queryExecute(
                            "INSERT INTO route_instance_sections
                                (route_instance_id, section_order, name, phase_num, source_section_id)
                             VALUES
                                (:routeInstanceId, :sectionOrder, :name, :phaseNum, :sourceSectionId)",
                            {
                                routeInstanceId = { value = newRouteInstanceId, cfsqltype = "cf_sql_integer" },
                                sectionOrder = { value = val(qSections.section_order[sectionIndex]), cfsqltype = "cf_sql_integer" },
                                name = { value = trim(toString(qSections.name[sectionIndex])), cfsqltype = "cf_sql_varchar" },
                                phaseNum = {
                                    value = (isNull(qSections.phase_num[sectionIndex]) ? 0 : val(qSections.phase_num[sectionIndex])),
                                    cfsqltype = "cf_sql_integer",
                                    null = isNull(qSections.phase_num[sectionIndex])
                                },
                                sourceSectionId = {
                                    value = (isNull(qSections.source_section_id[sectionIndex]) ? 0 : val(qSections.source_section_id[sectionIndex])),
                                    cfsqltype = "cf_sql_integer",
                                    null = isNull(qSections.source_section_id[sectionIndex])
                                }
                            },
                            { datasource = "fpw", result = "freshSectionInsertResult" }
                        );
                        sectionIdBySource[toString(qSections.id[sectionIndex])] = val(freshSectionInsertResult.generatedKey);
                    }

                    for (legIndex = 1; legIndex LTE qLegs.recordCount; legIndex++) {
                        sourceSectionId = isNull(qLegs.route_instance_section_id[legIndex]) ? 0 : val(qLegs.route_instance_section_id[legIndex]);
                        newSectionId = 0;
                        if (sourceSectionId GT 0 AND structKeyExists(sectionIdBySource, toString(sourceSectionId))) {
                            newSectionId = val(sectionIdBySource[toString(sourceSectionId)]);
                        }
                        segmentId = isNull(qLegs.segment_id[legIndex]) ? 0 : val(qLegs.segment_id[legIndex]);
                        sourceLoopSegmentId = isNull(qLegs.source_loop_segment_id[legIndex]) ? 0 : val(qLegs.source_loop_segment_id[legIndex]);
                        detourCode = isNull(qLegs.detour_code[legIndex]) ? "" : trim(toString(qLegs.detour_code[legIndex]));
                        startName = isNull(qLegs.start_name[legIndex]) ? "" : trim(toString(qLegs.start_name[legIndex]));
                        endName = isNull(qLegs.end_name[legIndex]) ? "" : trim(toString(qLegs.end_name[legIndex]));
                        startLatIsNull = (isNull(qLegs.start_lat[legIndex]) OR !len(trim(toString(qLegs.start_lat[legIndex]))));
                        startLngIsNull = (isNull(qLegs.start_lng[legIndex]) OR !len(trim(toString(qLegs.start_lng[legIndex]))));
                        endLatIsNull = (isNull(qLegs.end_lat[legIndex]) OR !len(trim(toString(qLegs.end_lat[legIndex]))));
                        endLngIsNull = (isNull(qLegs.end_lng[legIndex]) OR !len(trim(toString(qLegs.end_lng[legIndex]))));
                        baseDistIsNull = (isNull(qLegs.base_dist_nm[legIndex]) OR !len(trim(toString(qLegs.base_dist_nm[legIndex]))));
                        lockCountIsNull = (isNull(qLegs.lock_count[legIndex]) OR !len(trim(toString(qLegs.lock_count[legIndex]))));
                        notesVal = isNull(qLegs.notes[legIndex]) ? "" : trim(toString(qLegs.notes[legIndex]));

                        queryExecute(
                            "INSERT INTO route_instance_legs
                                (route_instance_id, route_instance_section_id, leg_order, segment_id, source_loop_segment_id, is_reversed, is_optional, detour_code, start_name, end_name, start_lat, start_lng, end_lat, end_lng, base_dist_nm, lock_count, notes)
                             VALUES
                                (:routeInstanceId, :sectionId, :legOrder, :segmentId, :sourceLoopSegmentId, :isReversed, :isOptional, :detourCode, :startName, :endName, :startLat, :startLng, :endLat, :endLng, :baseDistNm, :lockCount, :notes)",
                            {
                                routeInstanceId = { value = newRouteInstanceId, cfsqltype = "cf_sql_integer" },
                                sectionId = { value = newSectionId, cfsqltype = "cf_sql_integer", null = (newSectionId LTE 0) },
                                legOrder = { value = val(qLegs.leg_order[legIndex]), cfsqltype = "cf_sql_integer" },
                                segmentId = { value = segmentId, cfsqltype = "cf_sql_integer", null = (segmentId LTE 0) },
                                sourceLoopSegmentId = { value = sourceLoopSegmentId, cfsqltype = "cf_sql_integer", null = (sourceLoopSegmentId LTE 0) },
                                isReversed = { value = val(qLegs.is_reversed[legIndex]), cfsqltype = "cf_sql_bit" },
                                isOptional = { value = val(qLegs.is_optional[legIndex]), cfsqltype = "cf_sql_bit" },
                                detourCode = { value = detourCode, cfsqltype = "cf_sql_varchar", null = NOT len(detourCode) },
                                startName = { value = startName, cfsqltype = "cf_sql_varchar", null = NOT len(startName) },
                                endName = { value = endName, cfsqltype = "cf_sql_varchar", null = NOT len(endName) },
                                startLat = {
                                    value = (startLatIsNull ? 0 : val(qLegs.start_lat[legIndex])),
                                    cfsqltype = "cf_sql_decimal",
                                    null = startLatIsNull
                                },
                                startLng = {
                                    value = (startLngIsNull ? 0 : val(qLegs.start_lng[legIndex])),
                                    cfsqltype = "cf_sql_decimal",
                                    null = startLngIsNull
                                },
                                endLat = {
                                    value = (endLatIsNull ? 0 : val(qLegs.end_lat[legIndex])),
                                    cfsqltype = "cf_sql_decimal",
                                    null = endLatIsNull
                                },
                                endLng = {
                                    value = (endLngIsNull ? 0 : val(qLegs.end_lng[legIndex])),
                                    cfsqltype = "cf_sql_decimal",
                                    null = endLngIsNull
                                },
                                baseDistNm = {
                                    value = (baseDistIsNull ? 0 : val(qLegs.base_dist_nm[legIndex])),
                                    cfsqltype = "cf_sql_decimal",
                                    null = baseDistIsNull
                                },
                                lockCount = {
                                    value = (lockCountIsNull ? 0 : val(qLegs.lock_count[legIndex])),
                                    cfsqltype = "cf_sql_integer",
                                    null = lockCountIsNull
                                },
                                notes = { value = notesVal, cfsqltype = "cf_sql_varchar", null = NOT len(notesVal) }
                            },
                            { datasource = "fpw" }
                        );
                    }

                    queryExecute(
                        "INSERT INTO route_instance_leg_progress
                            (user_id, route_instance_id, leg_order, status, leg_started_at, completed_at)
                         SELECT
                            :userId,
                            :routeInstanceId,
                            ril.leg_order,
                            'NOT_STARTED',
                            NULL,
                            NULL
                         FROM route_instance_legs ril
                         WHERE ril.route_instance_id = :routeInstanceId
                         ORDER BY ril.leg_order ASC",
                        {
                            userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                            routeInstanceId = { value = newRouteInstanceId, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = "fpw" }
                    );
                }

                result.SUCCESS = true;
                result.ROUTE_INSTANCE_ID = newRouteInstanceId;
                result.ROUTE_CODE = routeCode;
                result.GENERATED_ROUTE_ID = newRouteId;
                return result;
            } catch (any createFreshRouteErr) {
                result.ERROR = "FRESH_ROUTE_INSTANCE_CREATE_FAILED";
                result.MESSAGE = "Unable to create a fresh route instance for this activation.";
                result.DETAIL = createFreshRouteErr.message;
                return result;
            }
        </cfscript>
    </cffunction>

    <cffunction name="ensureCleanRouteInstanceForActivation" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfscript>
            var result = {
                SUCCESS = false,
                ROUTE_INSTANCE_ID = arguments.routeInstanceId,
                ORIGINAL_ROUTE_INSTANCE_ID = arguments.routeInstanceId,
                CREATED_FRESH = false,
                ROUTE_CODE = ""
            };
            var history = loadRouteInstanceActivationHistory(
                userId = arguments.userId,
                floatPlanId = arguments.floatPlanId,
                routeInstanceId = arguments.routeInstanceId
            );
            var freshRoute = {};
            var cleanProgress = {};
            var qVerify = queryNew("");

            if (!history.SUCCESS) {
                return history;
            }

            if (history.HAS_OPERATIONAL_HISTORY AND history.VALID_MONITORING_FOR_PLAN_COUNT EQ 0) {
                freshRoute = createFreshOperationalRouteInstanceFromTemplate(
                    userId = arguments.userId,
                    floatPlanId = arguments.floatPlanId,
                    sourceRouteInstanceId = arguments.routeInstanceId
                );
                if (!freshRoute.SUCCESS) {
                    return freshRoute;
                }

                queryExecute(
                    "UPDATE floatplans
                     SET route_instance_id = :routeInstanceId,
                         lastUpdate = UTC_TIMESTAMP()
                     WHERE floatPlanId = :floatPlanId
                       AND userId = :userId
                       AND UPPER(TRIM(`status`)) = 'DRAFT'",
                    {
                        routeInstanceId = { value = freshRoute.ROUTE_INSTANCE_ID, cfsqltype = "cf_sql_integer" },
                        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = "fpw" }
                );

                qVerify = queryExecute(
                    "SELECT route_instance_id, UPPER(TRIM(`status`)) AS status_value
                     FROM floatplans
                     WHERE floatPlanId = :floatPlanId
                       AND userId = :userId
                     LIMIT 1",
                    {
                        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = "fpw" }
                );
                if (
                    qVerify.recordCount NEQ 1
                    OR val(qVerify.route_instance_id[1]) NEQ freshRoute.ROUTE_INSTANCE_ID
                    OR trim(toString(qVerify.status_value[1])) NEQ "DRAFT"
                ) {
                    result.ERROR = "FRESH_ROUTE_ASSIGNMENT_FAILED";
                    result.MESSAGE = "The fresh route instance could not be assigned before activation.";
                    return result;
                }

                cleanProgress = ensureRouteInstanceCleanProgressRows(arguments.userId, freshRoute.ROUTE_INSTANCE_ID);
                if (!cleanProgress.SUCCESS) {
                    return cleanProgress;
                }

                result.SUCCESS = true;
                result.ROUTE_INSTANCE_ID = freshRoute.ROUTE_INSTANCE_ID;
                result.ORIGINAL_ROUTE_INSTANCE_ID = arguments.routeInstanceId;
                result.CREATED_FRESH = true;
                result.ROUTE_CODE = freshRoute.ROUTE_CODE;
                result.HISTORY = history;
                result.CLEAN_PROGRESS = cleanProgress;
                return result;
            }

            cleanProgress = ensureRouteInstanceCleanProgressRows(arguments.userId, arguments.routeInstanceId);
            if (!cleanProgress.SUCCESS) {
                return cleanProgress;
            }

            result.SUCCESS = true;
            result.HISTORY = history;
            result.CLEAN_PROGRESS = cleanProgress;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="revertRouteActivationWithoutMonitoring" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = { SUCCESS = false, REVERTED = false };
            var qMonitoring = queryExecute(
                "SELECT COUNT(*) AS monitor_count
                 FROM floatplan_monitoring
                 WHERE float_plan_id = :floatPlanId
                   AND monitor_state <> 'CLOSED'
                   AND is_monitoring_enabled = 1",
                {
                    floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = "fpw" }
            );

            if (val(qMonitoring.monitor_count[1]) GT 0) {
                result.SUCCESS = true;
                result.REVERTED = false;
                result.REASON = "MONITORING_ROW_EXISTS";
                return result;
            }

            queryExecute(
                "UPDATE floatplans
                 SET `status` = 'DRAFT',
                     activatedAt = NULL,
                     initialSentAt = NULL,
                     lastUpdateStatus = UTC_TIMESTAMP()
                 WHERE floatPlanId = :floatPlanId
                   AND userId = :userId
                   AND UPPER(TRIM(`status`)) = 'ACTIVE'",
                {
                    floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = "fpw" }
            );

            result.SUCCESS = true;
            result.REVERTED = true;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="countEffectivePayloadWaypoints" access="private" returntype="numeric" output="false">
        <cfargument name="selectedWaypoints" type="array" required="true">
        <cfscript>
            var countValue = 0;
            var wIndex = 0;
            var waypointId = 0;

            for (wIndex = 1; wIndex LTE arrayLen(arguments.selectedWaypoints); wIndex++) {
                if (!isStruct(arguments.selectedWaypoints[wIndex])) {
                    continue;
                }
                waypointId = val(pickValue(arguments.selectedWaypoints[wIndex], ["WAYPOINTID", "waypointId", "wpId"], 0));
                if (waypointId GT 0) {
                    countValue++;
                }
            }

            return countValue;
        </cfscript>
    </cffunction>

    <cffunction name="countStoredFloatPlanWaypoints" access="private" returntype="numeric" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var qCount = queryExecute(
                "SELECT COUNT(*) AS waypointCount
                   FROM floatplan_waypoints
                  WHERE floatplanId = :planId",
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = "fpw" }
            );
            return val(qCount.waypointCount[1]);
        </cfscript>
    </cffunction>

    <cffunction name="validateBasicSavedWaypointLimit" access="private" returntype="struct" output="false">
        <cfargument name="waypointCount" type="numeric" required="true">
	        <cfscript>
	            if (arguments.waypointCount GT 2) {
	                return {
	                    "allowed" = false,
	                    "SUCCESS" = false,
	                    "success" = false,
	                    "response" = getMemberAccessGateService().buildDeniedResponse(
	                        errorCode = "BASIC_WAYPOINT_LIMIT",
	                        message = "Basic float plans can include up to 2 saved waypoints.",
	                        auth = true,
	                        statusCode = 403,
	                        includeUpgradeOptions = true
	                    )
	                };
	            }
	            return { "allowed" = true, "SUCCESS" = true, "success" = true };
	        </cfscript>
    </cffunction>

    <cffunction name="loadStoredFloatPlanTimes" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = {};
            var qPlan = queryExecute(
                "SELECT
                        DATE_FORMAT(departureTime, '%Y-%m-%d %H:%i:%s') AS departureTime,
                        DATE_FORMAT(departureTimeUTC, '%Y-%m-%d %H:%i:%s') AS departureTimeUTC,
                        DATE_FORMAT(returnTime, '%Y-%m-%d %H:%i:%s') AS returnTime,
                        DATE_FORMAT(returnTimeUTC, '%Y-%m-%d %H:%i:%s') AS returnTimeUTC
                   FROM floatplans
                  WHERE floatplanId = :planId
                    AND userId = :userId
                  LIMIT 1",
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = "fpw" }
            );

            if (qPlan.recordCount EQ 1) {
                result.departureTime = isNull(qPlan.departureTime[1]) ? "" : qPlan.departureTime[1];
                result.departureTimeUTC = isNull(qPlan.departureTimeUTC[1]) ? "" : qPlan.departureTimeUTC[1];
                result.returnTime = isNull(qPlan.returnTime[1]) ? "" : qPlan.returnTime[1];
                result.returnTimeUTC = isNull(qPlan.returnTimeUTC[1]) ? "" : qPlan.returnTimeUTC[1];
            }

            return result;
        </cfscript>
    </cffunction>

    <cffunction name="hasBasicOperationalFloatPlanColumns" access="private" returntype="boolean" output="false">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var cacheKey = "fpwBasicOperationalFloatPlanColumns:" & arguments.datasource;
            var qCols = queryNew("");

            if (structKeyExists(request, cacheKey)) {
                return booleanValue(request[cacheKey]);
            }

            qCols = queryExecute(
                "SELECT COUNT(*) AS colCount
                   FROM information_schema.columns
                  WHERE table_schema = DATABASE()
                    AND table_name = 'floatplans'
                    AND column_name IN ('route_origin','is_reusable','is_visible_in_route_library')",
                {},
                { datasource = arguments.datasource }
            );

            request[cacheKey] = (qCols.recordCount EQ 1 AND val(qCols.colCount[1]) EQ 3);
            return request[cacheKey];
        </cfscript>
    </cffunction>

    <cffunction name="loadBasicOperationalPlanScope" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var result = {
                EXISTS = false,
                HAS_SCOPE_COLUMNS = hasBasicOperationalFloatPlanColumns(arguments.datasource),
                FLOATPLANID = arguments.floatPlanId,
                ROUTE_INSTANCE_ID = 0,
                STATUS = "",
                ROUTE_ORIGIN = "",
                IS_REUSABLE = false,
                IS_VISIBLE_IN_ROUTE_LIBRARY = false,
                IS_BASIC_OPERATIONAL = false
            };
            var selectSql = "";
            var qPlan = queryNew("");

            if (arguments.floatPlanId LTE 0) {
                return result;
            }

            selectSql = "
                SELECT
                    floatplanId,
                    route_instance_id,
                    UPPER(TRIM(`status`)) AS statusValue";

            if (result.HAS_SCOPE_COLUMNS) {
                selectSql &= ",
                    route_origin,
                    is_reusable,
                    is_visible_in_route_library";
            } else {
                selectSql &= ",
                    '' AS route_origin,
                    0 AS is_reusable,
                    0 AS is_visible_in_route_library";
            }

            selectSql &= "
                FROM floatplans
                WHERE floatplanId = :planId
                  AND userId = :userId
                LIMIT 1";

            qPlan = queryExecute(
                selectSql,
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = arguments.datasource }
            );

            if (qPlan.recordCount EQ 0) {
                return result;
            }

            result.EXISTS = true;
            result.FLOATPLANID = val(qPlan.floatplanId[1]);
            result.ROUTE_INSTANCE_ID = isNull(qPlan.route_instance_id[1]) ? 0 : val(qPlan.route_instance_id[1]);
            result.STATUS = isNull(qPlan.statusValue[1]) ? "" : trim(toString(qPlan.statusValue[1]));
            result.ROUTE_ORIGIN = isNull(qPlan.route_origin[1]) ? "" : trim(toString(qPlan.route_origin[1]));
            result.IS_REUSABLE = !isNull(qPlan.is_reusable[1]) AND booleanValue(qPlan.is_reusable[1]);
            result.IS_VISIBLE_IN_ROUTE_LIBRARY = !isNull(qPlan.is_visible_in_route_library[1]) AND booleanValue(qPlan.is_visible_in_route_library[1]);
            result.IS_BASIC_OPERATIONAL = (
                result.ROUTE_INSTANCE_ID LTE 0
                AND (
                    !result.HAS_SCOPE_COLUMNS
                    OR (
                        compareNoCase(result.ROUTE_ORIGIN, "basic_float_plan") EQ 0
                        AND !result.IS_REUSABLE
                        AND !result.IS_VISIBLE_IN_ROUTE_LIBRARY
                    )
                )
            );
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="getBasicOperationalSingletonState" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var result = {
                HAS_SCOPE_COLUMNS = hasBasicOperationalFloatPlanColumns(arguments.datasource),
                HAS_ACTIVE = false,
                ACTIVE_FLOATPLANID = 0,
                HAS_DRAFT = false,
                DRAFT_FLOATPLANID = 0
            };
            var qPlans = queryNew("");
            var rowIndex = 0;
            var statusValue = "";

            if (arguments.userId LTE 0 OR !result.HAS_SCOPE_COLUMNS) {
                return result;
            }

            qPlans = queryExecute(
                "SELECT fp.floatplanId,
                        UPPER(TRIM(fp.`status`)) AS statusValue
                   FROM floatplans fp
                  WHERE fp.userId = :userId
                    AND fp.route_instance_id IS NULL
                    AND fp.route_origin = 'basic_float_plan'
                    AND fp.is_reusable = 0
                    AND fp.is_visible_in_route_library = 0
                    AND fp.closedAt IS NULL
                    AND (
                        UPPER(TRIM(fp.`status`)) = 'ACTIVE'
                        OR (
                            UPPER(TRIM(fp.`status`)) = 'DRAFT'
                            AND fp.activatedAt IS NULL
                            AND fp.initialSentAt IS NULL
                        )
                    )
                  ORDER BY CASE WHEN UPPER(TRIM(fp.`status`)) = 'ACTIVE' THEN 1 ELSE 2 END,
                           COALESCE(fp.activatedAt, fp.lastUpdateStatus, fp.lastUpdate, fp.dateCreated) DESC,
                           fp.floatplanId DESC
                  LIMIT 20",
                {
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = arguments.datasource }
            );

            for (rowIndex = 1; rowIndex LTE qPlans.recordCount; rowIndex++) {
                statusValue = trim(toString(qPlans.statusValue[rowIndex]));
                if (statusValue EQ "ACTIVE" AND !result.HAS_ACTIVE) {
                    result.HAS_ACTIVE = true;
                    result.ACTIVE_FLOATPLANID = val(qPlans.floatplanId[rowIndex]);
                } else if (statusValue EQ "DRAFT" AND !result.HAS_DRAFT) {
                    result.HAS_DRAFT = true;
                    result.DRAFT_FLOATPLANID = val(qPlans.floatplanId[rowIndex]);
                }
            }

            return result;
        </cfscript>
    </cffunction>

    <cffunction name="prepareBasicOperationalPdfDownload" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var result = {
                SUCCESS = false,
                MESSAGE = ""
            };
            var scope = {};
            var plan = {};
            var floatPlanUtils = {};
            var pdfFileName = "";
            var pdfPath = "";
            var planName = "";

            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "MISSING_PLAN_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }

            scope = loadBasicOperationalPlanScope(arguments.userId, arguments.floatPlanId, arguments.datasource);
            if (!scope.EXISTS) {
                result.ERROR = "PLAN_NOT_FOUND";
                result.MESSAGE = "Float plan not found.";
                return result;
            }

            if (!scope.IS_BASIC_OPERATIONAL) {
                return getMemberAccessGateService().buildDeniedResponse(
                    errorCode = "BASIC_SAVED_ROUTE_RESTRICTED",
                    message = "Basic PDF download is only available for route-less operational Basic float plans.",
                    auth = true,
                    statusCode = 403,
                    includeUpgradeOptions = true
                );
            }

            if (compareNoCase(scope.STATUS, "ACTIVE") NEQ 0) {
                result.ERROR = "BASIC_PDF_UNAVAILABLE";
                result.MESSAGE = "Only sent Basic float plans can be downloaded.";
                return result;
            }

            plan = loadFloatPlan(arguments.userId, arguments.floatPlanId);
            floatPlanUtils = createObject("component", resolveFloatPlanUtilsComponentPath()).init();
            pdfFileName = floatPlanUtils.createPDF(arguments.floatPlanId);
            if (!len(trim(pdfFileName))) {
                result.ERROR = "PDF_FAILED";
                result.MESSAGE = "Unable to generate float plan PDF.";
                return result;
            }

            pdfPath = floatPlanUtils.getPdfPath(pdfFileName);
            if (!fileExists(pdfPath)) {
                result.ERROR = "PDF_FAILED";
                result.MESSAGE = "Unable to locate generated float plan PDF.";
                return result;
            }

            planName = trim(toString(pickValue(plan, ["NAME", "floatPlanName"], "")));

            result.SUCCESS = true;
            result.FILE_PATH = pdfPath;
            result.FILE_NAME = buildBasicOperationalPdfDownloadFileName(planName, arguments.floatPlanId);
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="buildBasicOperationalPdfDownloadFileName" access="private" returntype="string" output="false">
        <cfargument name="planName" type="string" required="false" default="">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var fileBase = trim(arguments.planName);
            if (!len(fileBase)) {
                fileBase = "basic-float-plan-" & arguments.floatPlanId;
            }

            fileBase = reReplace(fileBase, "[^A-Za-z0-9._-]+", "-", "all");
            fileBase = reReplace(fileBase, "-{2,}", "-", "all");
            fileBase = reReplace(fileBase, "(^-|-$)", "", "all");

            if (!len(fileBase)) {
                fileBase = "basic-float-plan-" & arguments.floatPlanId;
            }

            if (right(lCase(fileBase), 4) NEQ ".pdf") {
                fileBase &= ".pdf";
            }

            return fileBase;
        </cfscript>
    </cffunction>

    <cffunction name="markBasicOperationalFloatPlanScope" access="private" returntype="void" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            if (arguments.floatPlanId LTE 0 OR !hasBasicOperationalFloatPlanColumns(arguments.datasource)) {
                return;
            }

            queryExecute(
                "UPDATE floatplans
                    SET route_origin = 'basic_float_plan',
                        is_reusable = 0,
                        is_visible_in_route_library = 0
                  WHERE floatplanId = :planId
                    AND route_instance_id IS NULL",
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = arguments.datasource }
            );
        </cfscript>
    </cffunction>

    <cffunction name="hasBasicDetailsTable" access="private" returntype="boolean" output="false">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var cacheKey = "fpwBasicDetailsTable:" & arguments.datasource;
            var qTable = queryNew("");

            if (structKeyExists(request, cacheKey)) {
                return booleanValue(request[cacheKey]);
            }

            qTable = queryExecute(
                "SELECT COUNT(*) AS tableCount
                   FROM information_schema.tables
                  WHERE table_schema = DATABASE()
                    AND table_name = 'floatplan_basic_details'",
                {},
                { datasource = arguments.datasource }
            );

            request[cacheKey] = (qTable.recordCount EQ 1 AND val(qTable.tableCount[1]) EQ 1);
            return request[cacheKey];
        </cfscript>
    </cffunction>

    <cffunction name="listBasicRescueAuthorities" access="private" returntype="struct" output="false">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var result = { SUCCESS = true, AUTHORITIES = [] };
            var qAuthorities = queryExecute(
                "SELECT recId, rcName, rcDistrict, rcLocation, rcArea, rcPhone
                   FROM rescuecenters
                  ORDER BY rcName ASC, recId ASC",
                {},
                { datasource = arguments.datasource }
            );
            var i = 0;

            for (i = 1; i LTE qAuthorities.recordCount; i++) {
                arrayAppend(result.AUTHORITIES, {
                    AUTHORITY_ID = val(qAuthorities.recId[i]),
                    NAME = isNull(qAuthorities.rcName[i]) ? "" : trim(toString(qAuthorities.rcName[i])),
                    DISTRICT = isNull(qAuthorities.rcDistrict[i]) ? "" : trim(toString(qAuthorities.rcDistrict[i])),
                    LOCATION = isNull(qAuthorities.rcLocation[i]) ? "" : trim(toString(qAuthorities.rcLocation[i])),
                    AREA = isNull(qAuthorities.rcArea[i]) ? "" : trim(toString(qAuthorities.rcArea[i])),
                    PHONE = isNull(qAuthorities.rcPhone[i]) ? "" : trim(toString(qAuthorities.rcPhone[i]))
                });
            }

            return result;
        </cfscript>
    </cffunction>

    <cffunction name="resolveBasicRescueAuthority" access="private" returntype="struct" output="false">
        <cfargument name="authorityId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var result = { SUCCESS = false };
            var qAuthority = queryNew("");

            if (arguments.authorityId LTE 0) {
                result.ERROR = "VALIDATION";
                result.MESSAGE = "Official Emergency Authority is required.";
                return result;
            }

            qAuthority = queryExecute(
                "SELECT recId, rcName, rcPhone
                   FROM rescuecenters
                  WHERE recId = :authorityId
                  LIMIT 1",
                {
                    authorityId = { value = arguments.authorityId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = arguments.datasource }
            );

            if (qAuthority.recordCount EQ 0) {
                result.ERROR = "VALIDATION";
                result.MESSAGE = "Selected Official Emergency Authority could not be found.";
                return result;
            }

            result.SUCCESS = true;
            result.AUTHORITY_ID = val(qAuthority.recId[1]);
            result.AUTHORITY_NAME = isNull(qAuthority.rcName[1]) ? "" : trim(toString(qAuthority.rcName[1]));
            result.AUTHORITY_PHONE = isNull(qAuthority.rcPhone[1]) ? "" : trim(toString(qAuthority.rcPhone[1]));
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeBasicDetailsPayload" access="private" returntype="struct" output="false">
        <cfargument name="payload" type="struct" required="true">
        <cfargument name="floatPlan" type="struct" required="true">
        <cfscript>
            var source = {};
            if (structKeyExists(arguments.payload, "BASIC_DETAILS") AND isStruct(arguments.payload.BASIC_DETAILS)) {
                source = arguments.payload.BASIC_DETAILS;
            } else if (structKeyExists(arguments.payload, "basicDetails") AND isStruct(arguments.payload.basicDetails)) {
                source = arguments.payload.basicDetails;
            }

            return {
                VESSEL_NAME = trim(pickValue(source, ["VESSEL_NAME", "vesselName"], "")),
                OPERATOR_NAME = trim(pickValue(source, ["OPERATOR_NAME", "operatorName"], "")),
                CAPTAIN_NAME = trim(pickValue(source, ["CAPTAIN_NAME", "captainName"], "")),
                CAPTAIN_EMAIL = trim(pickValue(source, ["CAPTAIN_EMAIL", "captainEmail"], pickValue(arguments.floatPlan, ["EMAIL", "email"], ""))),
                NOTIFICATION_CONTACT_NAME = trim(pickValue(source, ["NOTIFICATION_CONTACT_NAME", "notificationContactName"], "")),
                NOTIFICATION_CONTACT_EMAIL = trim(pickValue(source, ["NOTIFICATION_CONTACT_EMAIL", "notificationContactEmail"], "")),
                NOTIFICATION_CONTACT_PHONE = trim(pickValue(source, ["NOTIFICATION_CONTACT_PHONE", "notificationContactPhone"], "")),
                LAUNCH_LOCATION = trim(pickValue(source, ["LAUNCH_LOCATION", "launchLocation"], pickValue(arguments.floatPlan, ["DEPARTING_FROM", "departingFrom"], ""))),
                DESTINATION_LOCATION = trim(pickValue(source, ["DESTINATION_LOCATION", "destinationLocation"], pickValue(arguments.floatPlan, ["RETURNING_TO", "returningTo"], ""))),
                AUTHORITY_ID = val(pickValue(source, ["AUTHORITY_ID", "authorityId"], pickValue(arguments.floatPlan, ["RESCUE_CENTERID", "rescueCenterId"], 0)))
            };
        </cfscript>
    </cffunction>

    <cffunction name="validateBasicDetailsPayload" access="private" returntype="struct" output="false">
        <cfargument name="details" type="struct" required="true">
        <cfscript>
            var requiredFields = [
                ["VESSEL_NAME", "Vessel name is required."],
                ["OPERATOR_NAME", "Operator name is required."],
                ["CAPTAIN_NAME", "Captain name is required."],
                ["CAPTAIN_EMAIL", "Captain email is required."],
                ["NOTIFICATION_CONTACT_NAME", "Notification contact name is required."],
                ["NOTIFICATION_CONTACT_EMAIL", "Notification contact email is required."],
                ["LAUNCH_LOCATION", "Launch location is required."],
                ["DESTINATION_LOCATION", "Destination / turnaround point is required."]
            ];
            var i = 0;

            for (i = 1; i LTE arrayLen(requiredFields); i++) {
                if (!len(trim(toString(arguments.details[requiredFields[i][1]])))) {
                    return {
                        SUCCESS = false,
                        ERROR = "VALIDATION",
                        MESSAGE = requiredFields[i][2]
                    };
                }
            }

            if (!isValid("email", arguments.details.CAPTAIN_EMAIL)) {
                return { SUCCESS = false, ERROR = "VALIDATION", MESSAGE = "Captain email is invalid." };
            }
            if (!isValid("email", arguments.details.NOTIFICATION_CONTACT_EMAIL)) {
                return { SUCCESS = false, ERROR = "VALIDATION", MESSAGE = "Notification contact email is invalid." };
            }
            if (val(arguments.details.AUTHORITY_ID) LTE 0) {
                return { SUCCESS = false, ERROR = "VALIDATION", MESSAGE = "Official Emergency Authority is required." };
            }

            return { SUCCESS = true };
        </cfscript>
    </cffunction>

    <cffunction name="upsertBasicDetails" access="private" returntype="void" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="details" type="struct" required="true">
        <cfargument name="authority" type="struct" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            queryExecute(
                "INSERT INTO floatplan_basic_details (
                    floatplan_id,
                    vessel_name,
                    operator_name,
                    captain_name,
                    captain_email,
                    notification_contact_name,
                    notification_contact_email,
                    notification_contact_phone,
                    launch_location,
                    destination_location,
                    authority_id,
                    authority_name_snapshot,
                    authority_phone_snapshot,
                    created_at,
                    updated_at
                ) VALUES (
                    :floatPlanId,
                    :vesselName,
                    :operatorName,
                    :captainName,
                    :captainEmail,
                    :contactName,
                    :contactEmail,
                    :contactPhone,
                    :launchLocation,
                    :destinationLocation,
                    :authorityId,
                    :authorityName,
                    :authorityPhone,
                    UTC_TIMESTAMP(),
                    UTC_TIMESTAMP()
                )
                ON DUPLICATE KEY UPDATE
                    vessel_name = VALUES(vessel_name),
                    operator_name = VALUES(operator_name),
                    captain_name = VALUES(captain_name),
                    captain_email = VALUES(captain_email),
                    notification_contact_name = VALUES(notification_contact_name),
                    notification_contact_email = VALUES(notification_contact_email),
                    notification_contact_phone = VALUES(notification_contact_phone),
                    launch_location = VALUES(launch_location),
                    destination_location = VALUES(destination_location),
                    authority_id = VALUES(authority_id),
                    authority_name_snapshot = VALUES(authority_name_snapshot),
                    authority_phone_snapshot = VALUES(authority_phone_snapshot),
                    updated_at = UTC_TIMESTAMP()",
                {
                    floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    vesselName = { value = left(arguments.details.VESSEL_NAME, 255), cfsqltype = "cf_sql_varchar" },
                    operatorName = { value = left(arguments.details.OPERATOR_NAME, 255), cfsqltype = "cf_sql_varchar" },
                    captainName = { value = left(arguments.details.CAPTAIN_NAME, 255), cfsqltype = "cf_sql_varchar" },
                    captainEmail = { value = left(arguments.details.CAPTAIN_EMAIL, 255), cfsqltype = "cf_sql_varchar" },
                    contactName = { value = left(arguments.details.NOTIFICATION_CONTACT_NAME, 255), cfsqltype = "cf_sql_varchar" },
                    contactEmail = { value = left(arguments.details.NOTIFICATION_CONTACT_EMAIL, 255), cfsqltype = "cf_sql_varchar" },
                    contactPhone = { value = left(arguments.details.NOTIFICATION_CONTACT_PHONE, 45), cfsqltype = "cf_sql_varchar", null = NOT len(arguments.details.NOTIFICATION_CONTACT_PHONE) },
                    launchLocation = { value = left(arguments.details.LAUNCH_LOCATION, 255), cfsqltype = "cf_sql_varchar" },
                    destinationLocation = { value = left(arguments.details.DESTINATION_LOCATION, 255), cfsqltype = "cf_sql_varchar" },
                    authorityId = { value = arguments.authority.AUTHORITY_ID, cfsqltype = "cf_sql_integer" },
                    authorityName = { value = left(arguments.authority.AUTHORITY_NAME, 255), cfsqltype = "cf_sql_varchar" },
                    authorityPhone = { value = left(arguments.authority.AUTHORITY_PHONE, 45), cfsqltype = "cf_sql_varchar" }
                },
                { datasource = arguments.datasource }
            );
        </cfscript>
    </cffunction>

    <cffunction name="loadBasicDetails" access="private" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var result = {};
            var qDetails = queryNew("");

            if (arguments.floatPlanId LTE 0 OR !hasBasicDetailsTable(arguments.datasource)) {
                return result;
            }

            qDetails = queryExecute(
                "SELECT *
                   FROM floatplan_basic_details
                  WHERE floatplan_id = :planId
                  LIMIT 1",
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = arguments.datasource }
            );

            if (qDetails.recordCount EQ 0) {
                return result;
            }

            result.FLOATPLAN_ID = val(qDetails.floatplan_id[1]);
            result.VESSEL_NAME = isNull(qDetails.vessel_name[1]) ? "" : trim(toString(qDetails.vessel_name[1]));
            result.OPERATOR_NAME = isNull(qDetails.operator_name[1]) ? "" : trim(toString(qDetails.operator_name[1]));
            result.CAPTAIN_NAME = isNull(qDetails.captain_name[1]) ? "" : trim(toString(qDetails.captain_name[1]));
            result.CAPTAIN_EMAIL = isNull(qDetails.captain_email[1]) ? "" : trim(toString(qDetails.captain_email[1]));
            result.NOTIFICATION_CONTACT_NAME = isNull(qDetails.notification_contact_name[1]) ? "" : trim(toString(qDetails.notification_contact_name[1]));
            result.NOTIFICATION_CONTACT_EMAIL = isNull(qDetails.notification_contact_email[1]) ? "" : trim(toString(qDetails.notification_contact_email[1]));
            result.NOTIFICATION_CONTACT_PHONE = isNull(qDetails.notification_contact_phone[1]) ? "" : trim(toString(qDetails.notification_contact_phone[1]));
            result.LAUNCH_LOCATION = isNull(qDetails.launch_location[1]) ? "" : trim(toString(qDetails.launch_location[1]));
            result.DESTINATION_LOCATION = isNull(qDetails.destination_location[1]) ? "" : trim(toString(qDetails.destination_location[1]));
            result.AUTHORITY_ID = isNull(qDetails.authority_id[1]) ? 0 : val(qDetails.authority_id[1]);
            result.AUTHORITY_NAME_SNAPSHOT = isNull(qDetails.authority_name_snapshot[1]) ? "" : trim(toString(qDetails.authority_name_snapshot[1]));
            result.AUTHORITY_PHONE_SNAPSHOT = isNull(qDetails.authority_phone_snapshot[1]) ? "" : trim(toString(qDetails.authority_phone_snapshot[1]));
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="loadBasicPlanSelections" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var selections = loadPlanSelections(arguments.userId, arguments.floatPlanId);
            var details = loadBasicDetails(arguments.floatPlanId, arguments.datasource);

            selections.CONTACTS = [];
            if (!structIsEmpty(details) AND len(details.NOTIFICATION_CONTACT_EMAIL)) {
                arrayAppend(selections.CONTACTS, {
                    CONTACTID = 0,
                    NAME = details.NOTIFICATION_CONTACT_NAME,
                    EMAIL = details.NOTIFICATION_CONTACT_EMAIL,
                    PHONE = details.NOTIFICATION_CONTACT_PHONE,
                    SORT_ORDER = 1,
                    BASIC_ONE_TIME = true
                });
            }

            return selections;
        </cfscript>
    </cffunction>

    <cffunction name="loadBasicPlanContactEmails" access="private" returntype="array" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var contacts = [];
            var details = loadBasicDetails(arguments.floatPlanId, arguments.datasource);

            if (!structIsEmpty(details) AND len(details.NOTIFICATION_CONTACT_EMAIL)) {
                arrayAppend(contacts, {
                    CONTACTID = 0,
                    NAME = details.NOTIFICATION_CONTACT_NAME,
                    EMAIL = details.NOTIFICATION_CONTACT_EMAIL,
                    PHONE = details.NOTIFICATION_CONTACT_PHONE,
                    BASIC_ONE_TIME = true
                });
            }

            return contacts;
        </cfscript>
    </cffunction>

    <cffunction name="getBasicOperationalCurrentPlan" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var result = {
                SUCCESS = true,
                HAS_BASIC_PLAN = false,
                HAS_ACTIVE_PLAN = false,
                HAS_DRAFT = false,
                STATE = "empty",
                FLOATPLANID = 0,
                BASIC_PLAN = {},
                FLOATPLAN = {},
                PLAN_PASSENGERS = [],
                PLAN_CONTACTS = [],
                PLAN_WAYPOINTS = [],
                MONITORING = {},
                BASIC_OPERATIONAL_ONLY = true,
                ROUTE_ORIGIN = "basic_float_plan"
            };
            var qActive = queryNew("");
            var qDraft = queryNew("");

            if (arguments.userId LTE 0) {
                result.SUCCESS = false;
                result.ERROR = "INVALID_USER_ID";
                result.MESSAGE = "A valid user id is required.";
                return result;
            }

            if (!hasBasicOperationalFloatPlanColumns(arguments.datasource)) {
                return result;
            }

            qActive = queryExecute(
                "SELECT fp.floatplanId
                   FROM floatplans fp
                  WHERE fp.userId = :userId
                    AND fp.route_instance_id IS NULL
                    AND fp.route_origin = 'basic_float_plan'
                    AND fp.is_reusable = 0
                    AND fp.is_visible_in_route_library = 0
                    AND UPPER(TRIM(fp.`status`)) = 'ACTIVE'
                    AND fp.closedAt IS NULL
                  ORDER BY COALESCE(fp.activatedAt, fp.lastUpdateStatus, fp.lastUpdate, fp.dateCreated) DESC,
                           fp.floatplanId DESC
                  LIMIT 1",
                {
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = arguments.datasource }
            );

            if (qActive.recordCount GT 0) {
                return buildBasicOperationalCurrentResponse(
                    userId = arguments.userId,
                    floatPlanId = val(qActive.floatplanId[1]),
                    stateName = "active",
                    datasource = arguments.datasource
                );
            }

            qDraft = queryExecute(
                "SELECT fp.floatplanId
                   FROM floatplans fp
                  WHERE fp.userId = :userId
                    AND fp.route_instance_id IS NULL
                    AND fp.route_origin = 'basic_float_plan'
                    AND fp.is_reusable = 0
                    AND fp.is_visible_in_route_library = 0
                    AND UPPER(TRIM(fp.`status`)) = 'DRAFT'
                    AND fp.activatedAt IS NULL
                    AND fp.initialSentAt IS NULL
                    AND fp.closedAt IS NULL
                  ORDER BY fp.lastUpdate DESC,
                           fp.dateCreated DESC,
                           fp.floatplanId DESC
                  LIMIT 1",
                {
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = arguments.datasource }
            );

            if (qDraft.recordCount GT 0) {
                return buildBasicOperationalCurrentResponse(
                    userId = arguments.userId,
                    floatPlanId = val(qDraft.floatplanId[1]),
                    stateName = "draft",
                    datasource = arguments.datasource
                );
            }

            return result;
        </cfscript>
    </cffunction>

    <cffunction name="buildBasicOperationalCurrentResponse" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="stateName" type="string" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var stateValue = lCase(trim(arguments.stateName));
            var savedPlan = loadFloatPlan(arguments.userId, arguments.floatPlanId);
            var savedSelections = loadBasicPlanSelections(arguments.userId, arguments.floatPlanId, arguments.datasource);
            var monitoring = loadBasicOperationalMonitoringSummary(arguments.floatPlanId, arguments.datasource);
            var basicDetails = loadBasicDetails(arguments.floatPlanId, arguments.datasource);
            var summary = buildBasicOperationalPlanSummary(
                userId = arguments.userId,
                floatPlanId = arguments.floatPlanId,
                stateName = stateValue,
                plan = savedPlan,
                selections = savedSelections,
                basicDetails = basicDetails,
                monitoring = monitoring,
                datasource = arguments.datasource
            );

            return {
                SUCCESS = true,
                HAS_BASIC_PLAN = true,
                HAS_ACTIVE_PLAN = (stateValue EQ "active"),
                HAS_DRAFT = (stateValue EQ "draft"),
                STATE = stateValue,
                FLOATPLANID = arguments.floatPlanId,
                BASIC_PLAN = summary,
                FLOATPLAN = savedPlan,
                BASIC_DETAILS = basicDetails,
                PLAN_PASSENGERS = savedSelections.PASSENGERS,
                PLAN_CONTACTS = savedSelections.CONTACTS,
                PLAN_WAYPOINTS = savedSelections.WAYPOINTS,
                MONITORING = monitoring,
                BASIC_OPERATIONAL_ONLY = true,
                ROUTE_ORIGIN = "basic_float_plan"
            };
        </cfscript>
    </cffunction>

    <cffunction name="buildBasicOperationalPlanSummary" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="stateName" type="string" required="true">
        <cfargument name="plan" type="struct" required="true">
        <cfargument name="selections" type="struct" required="true">
        <cfargument name="basicDetails" type="struct" required="false" default="#structNew()#">
        <cfargument name="monitoring" type="struct" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var hasDetails = !structIsEmpty(arguments.basicDetails);
            var summary = {
                FLOATPLANID = arguments.floatPlanId,
                NAME = trim(toString(pickValue(arguments.plan, ["NAME", "floatPlanName"], "Basic Float Plan"))),
                STATUS = trim(toString(pickValue(arguments.plan, ["STATUS", "status"], ""))),
                STATE = lCase(trim(arguments.stateName)),
                DEPARTING_FROM = hasDetails ? arguments.basicDetails.LAUNCH_LOCATION : trim(toString(pickValue(arguments.plan, ["DEPARTING_FROM", "departingFrom"], ""))),
                RETURNING_TO = hasDetails ? arguments.basicDetails.LAUNCH_LOCATION : trim(toString(pickValue(arguments.plan, ["RETURNING_TO", "returningTo"], ""))),
                DESTINATION_LOCATION = hasDetails ? arguments.basicDetails.DESTINATION_LOCATION : "",
                CAPTAIN_NAME = hasDetails ? arguments.basicDetails.CAPTAIN_NAME : "",
                CAPTAIN_EMAIL = hasDetails ? arguments.basicDetails.CAPTAIN_EMAIL : trim(toString(pickValue(arguments.plan, ["EMAIL", "email"], ""))),
                AUTHORITY_NAME = hasDetails ? arguments.basicDetails.AUTHORITY_NAME_SNAPSHOT : trim(toString(pickValue(arguments.plan, ["RESCUE_AUTHORITY", "rescueAuthority"], ""))),
                AUTHORITY_PHONE = hasDetails ? arguments.basicDetails.AUTHORITY_PHONE_SNAPSHOT : trim(toString(pickValue(arguments.plan, ["RESCUE_AUTHORITY_PHONE", "rescueAuthorityPhone"], ""))),
                DEPARTURE_TIME = structKeyExists(arguments.plan, "DEPARTURE_TIME") ? arguments.plan.DEPARTURE_TIME : "",
                RETURN_TIME = structKeyExists(arguments.plan, "RETURN_TIME") ? arguments.plan.RETURN_TIME : "",
                DEPARTURE_TIMEZONE = trim(toString(pickValue(arguments.plan, ["DEPARTURE_TIMEZONE", "departureTimezone"], ""))),
                RETURN_TIMEZONE = trim(toString(pickValue(arguments.plan, ["RETURN_TIMEZONE", "returnTimezone"], ""))),
                WAYPOINT_COUNT = arrayLen(arguments.selections.WAYPOINTS),
                CONTACT_COUNT = (hasDetails AND len(arguments.basicDetails.NOTIFICATION_CONTACT_EMAIL)) ? 1 : arrayLen(arguments.selections.CONTACTS),
                PASSENGER_COUNT = arrayLen(arguments.selections.PASSENGERS),
                WAYPOINT_SUMMARY = buildBasicOperationalWaypointSummary(arguments.userId, arguments.floatPlanId, arguments.datasource),
                ROUTE_ORIGIN = "basic_float_plan",
                IS_REUSABLE = false,
                IS_VISIBLE_IN_ROUTE_LIBRARY = false,
                IS_SENDABLE = false,
                MONITORING = arguments.monitoring
            };

            if (compareNoCase(summary.STATE, "draft") EQ 0) {
                summary.IS_SENDABLE = isBasicOperationalDraftSendable(arguments.floatPlanId, arguments.datasource);
            }

            if (structKeyExists(arguments.monitoring, "MONITORING_MODE")) {
                summary.MONITORING_MODE = arguments.monitoring.MONITORING_MODE;
            }
            if (structKeyExists(arguments.monitoring, "MONITOR_STATE")) {
                summary.MONITOR_STATE = arguments.monitoring.MONITOR_STATE;
            }

            return summary;
        </cfscript>
    </cffunction>

    <cffunction name="buildBasicOperationalWaypointSummary" access="private" returntype="string" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var names = [];
            var qWaypoints = queryExecute(
                "SELECT COALESCE(NULLIF(TRIM(w.name), ''), CONCAT('Waypoint ', fpw.wayPointId)) AS waypoint_name
                   FROM floatplan_waypoints fpw
                   LEFT JOIN waypoints w
                     ON w.wpId = fpw.wayPointId
                    AND w.userId = :userId
                  WHERE fpw.floatPlanId = :planId
                  ORDER BY fpw.recId ASC",
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" }
                },
                { datasource = arguments.datasource }
            );
            var i = 0;

            for (i = 1; i LTE qWaypoints.recordCount; i++) {
                arrayAppend(names, trim(toString(qWaypoints.waypoint_name[i])));
            }

            return arrayToList(names, " / ");
        </cfscript>
    </cffunction>

    <cffunction name="isBasicOperationalDraftSendable" access="private" returntype="boolean" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var qSendable = queryExecute(
                "SELECT CASE
                          WHEN returnTime IS NOT NULL
                           AND returnTime > UTC_TIMESTAMP()
                          THEN 1 ELSE 0
                        END AS is_sendable
                   FROM floatplans
                  WHERE floatplanId = :planId
                    AND route_instance_id IS NULL
                    AND route_origin = 'basic_float_plan'
                    AND is_reusable = 0
                    AND is_visible_in_route_library = 0
                    AND UPPER(TRIM(`status`)) = 'DRAFT'",
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = arguments.datasource }
            );

            return qSendable.recordCount GT 0 AND val(qSendable.is_sendable[1]) EQ 1;
        </cfscript>
    </cffunction>

    <cffunction name="loadBasicOperationalMonitoringSummary" access="private" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var result = {};
            var qMonitoring = queryExecute(
                "SELECT monitoring_mode,
                        monitor_state,
                        is_monitoring_enabled,
                        expected_checkin_at,
                        grace_expires_at,
                        last_checkin_at,
                        last_checkin_status
                   FROM floatplan_monitoring
                  WHERE float_plan_id = :planId
                  ORDER BY id DESC
                  LIMIT 1",
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = arguments.datasource }
            );

            if (qMonitoring.recordCount EQ 0) {
                return result;
            }

            result.MONITORING_MODE = isNull(qMonitoring.monitoring_mode[1]) ? "" : trim(toString(qMonitoring.monitoring_mode[1]));
            result.MONITOR_STATE = isNull(qMonitoring.monitor_state[1]) ? "" : trim(toString(qMonitoring.monitor_state[1]));
            result.IS_MONITORING_ENABLED = !isNull(qMonitoring.is_monitoring_enabled[1]) AND val(qMonitoring.is_monitoring_enabled[1]) NEQ 0;
            result.EXPECTED_CHECKIN_AT = isNull(qMonitoring.expected_checkin_at[1]) ? "" : qMonitoring.expected_checkin_at[1];
            result.GRACE_EXPIRES_AT = isNull(qMonitoring.grace_expires_at[1]) ? "" : qMonitoring.grace_expires_at[1];
            result.LAST_CHECKIN_AT = isNull(qMonitoring.last_checkin_at[1]) ? "" : qMonitoring.last_checkin_at[1];
            result.LAST_CHECKIN_STATUS = isNull(qMonitoring.last_checkin_status[1]) ? "" : trim(toString(qMonitoring.last_checkin_status[1]));

            return result;
        </cfscript>
    </cffunction>

    <cffunction name="listBasicOperationalDrafts" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var result = {
                SUCCESS = true,
                BASIC_DRAFTS = [],
                HAS_DRAFT = false,
                LATEST_DRAFT = {}
            };
            var qDrafts = queryNew("");
            var row = {};
            var i = 0;

            if (arguments.userId LTE 0) {
                result.SUCCESS = false;
                result.ERROR = "INVALID_USER_ID";
                result.MESSAGE = "A valid user id is required.";
                return result;
            }

            if (!hasBasicOperationalFloatPlanColumns(arguments.datasource)) {
                return result;
            }

            qDrafts = queryExecute(
                "SELECT
                    fp.floatplanId,
                    fp.floatPlanName,
                    fp.status,
                    fp.departing,
                    fp.`returning`,
                    fp.departureTime,
                    fp.returnTime,
                    fp.departureTZ,
                    fp.returnTZ,
                    fp.departTimezone,
                    fp.returnTimezone,
                    fp.dateCreated,
                    fp.lastUpdate,
                    (
                        SELECT COUNT(*)
                        FROM floatplan_waypoints fpw
                        WHERE fpw.floatPlanId = fp.floatplanId
                    ) AS waypoint_count,
                    (
                        SELECT COUNT(*)
                        FROM floatplan_contacts fpc
                        WHERE fpc.floatPlanId = fp.floatplanId
                    ) AS contact_count
                 FROM floatplans fp
                 WHERE fp.userId = :userId
                   AND fp.route_instance_id IS NULL
                   AND fp.route_origin = 'basic_float_plan'
                   AND fp.is_reusable = 0
                   AND fp.is_visible_in_route_library = 0
                   AND UPPER(TRIM(fp.`status`)) = 'DRAFT'
                   AND fp.activatedAt IS NULL
                   AND fp.initialSentAt IS NULL
                   AND fp.closedAt IS NULL
                 ORDER BY fp.lastUpdate DESC, fp.floatplanId DESC
                 LIMIT 10",
                {
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = arguments.datasource }
            );

            for (i = 1; i LTE qDrafts.recordCount; i++) {
                row = {
                    FLOATPLANID = val(qDrafts.floatplanId[i]),
                    NAME = isNull(qDrafts.floatPlanName[i]) ? "" : trim(toString(qDrafts.floatPlanName[i])),
                    STATUS = isNull(qDrafts.status[i]) ? "" : trim(toString(qDrafts.status[i])),
                    DEPARTING_FROM = isNull(qDrafts.departing[i]) ? "" : trim(toString(qDrafts.departing[i])),
                    RETURNING_TO = isNull(qDrafts.returning[i]) ? "" : trim(toString(qDrafts.returning[i])),
                    DEPARTURE_TIME = isNull(qDrafts.departureTime[i]) ? "" : qDrafts.departureTime[i],
                    RETURN_TIME = isNull(qDrafts.returnTime[i]) ? "" : qDrafts.returnTime[i],
                    DEPARTURE_TIMEZONE = isNull(qDrafts.departureTZ[i]) ? "" : trim(toString(qDrafts.departureTZ[i])),
                    RETURN_TIMEZONE = isNull(qDrafts.returnTZ[i]) ? "" : trim(toString(qDrafts.returnTZ[i])),
                    STORED_DEPARTURE_TIMEZONE = isNull(qDrafts.departTimezone[i]) ? "" : trim(toString(qDrafts.departTimezone[i])),
                    STORED_RETURN_TIMEZONE = isNull(qDrafts.returnTimezone[i]) ? "" : trim(toString(qDrafts.returnTimezone[i])),
                    DATE_CREATED = isNull(qDrafts.dateCreated[i]) ? "" : qDrafts.dateCreated[i],
                    LAST_UPDATE = isNull(qDrafts.lastUpdate[i]) ? "" : qDrafts.lastUpdate[i],
                    WAYPOINT_COUNT = val(qDrafts.waypoint_count[i]),
                    CONTACT_COUNT = val(qDrafts.contact_count[i]),
                    ROUTE_ORIGIN = "basic_float_plan",
                    IS_REUSABLE = false,
                    IS_VISIBLE_IN_ROUTE_LIBRARY = false
                };
                arrayAppend(result.BASIC_DRAFTS, row);
                if (!result.HAS_DRAFT) {
                    result.HAS_DRAFT = true;
                    result.LATEST_DRAFT = row;
                }
            }

            return result;
        </cfscript>
    </cffunction>

    <cffunction name="getBasicOperationalDraft" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var result = { SUCCESS = false };
            var scope = {};
            var savedPlan = {};
            var savedSelections = {};

            if (arguments.userId LTE 0 OR arguments.floatPlanId LTE 0) {
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Basic float plan draft id is required.";
                return result;
            }

            scope = loadBasicOperationalPlanScope(arguments.userId, arguments.floatPlanId, arguments.datasource);
            if (!scope.EXISTS) {
                result.ERROR = "NOT_FOUND";
                result.MESSAGE = "Basic float plan draft not found.";
                return result;
            }

            if (!scope.IS_BASIC_OPERATIONAL) {
                result.ERROR = "BASIC_SAVED_ROUTE_RESTRICTED";
                result.MESSAGE = "This float plan is not a Basic operational draft.";
                return result;
            }

            if (compareNoCase(scope.STATUS, "DRAFT") NEQ 0) {
                result.ERROR = "BASIC_DRAFT_UNAVAILABLE";
                result.MESSAGE = "Only draft Basic float plans can be resumed.";
                return result;
            }

            savedPlan = loadFloatPlan(arguments.userId, arguments.floatPlanId);
            savedSelections = loadBasicPlanSelections(arguments.userId, arguments.floatPlanId, arguments.datasource);

            result.SUCCESS = true;
            result.FLOATPLANID = arguments.floatPlanId;
            result.FLOATPLAN = savedPlan;
            result.BASIC_DETAILS = loadBasicDetails(arguments.floatPlanId, arguments.datasource);
            result.PLAN_PASSENGERS = savedSelections.PASSENGERS;
            result.PLAN_CONTACTS = savedSelections.CONTACTS;
            result.PLAN_WAYPOINTS = savedSelections.WAYPOINTS;
            result.BASIC_OPERATIONAL_ONLY = true;
            result.ROUTE_ORIGIN = "basic_float_plan";

            return result;
        </cfscript>
    </cffunction>

    <cffunction name="resolveCurrentRouteFloatPlanGroup" access="public" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="routeInstanceId" type="numeric" required="false" default="0">
        <cfscript>
            var result = {
                SUCCESS = false,
                success = false,
                HAS_CURRENT_GROUP = false,
                CURRENT_STATE = "",
                MESSAGE = "No current route/float-plan group is available.",
                FLOATPLANID = 0,
                FLOATPLAN_NAME = "",
                STATUS = "",
                ROUTE_INSTANCE_ID = 0,
                ROUTE_DAY_NUMBER = 0,
                ROUTE_CODE = "",
                ROUTE_NAME = "",
                IS_DRAFT = false,
                IS_ACTIVE = false,
                IS_ROUTE_MATCH = false
            };
            var qDraft = queryNew("");
            var qActive = queryNew("");
            var useRouteInstanceId = val(arguments.routeInstanceId);
            var row = {};

            if (arguments.userId LTE 0) {
                result.ERROR = "INVALID_USER_ID";
                result.MESSAGE = "A valid user id is required.";
                return result;
            }

            qDraft = queryExecute(
                "SELECT
                    fp.floatplanId,
                    fp.floatPlanName,
                    fp.route_instance_id,
                    fp.route_day_number,
                    UPPER(TRIM(fp.`status`)) AS statusValue,
                    COALESCE(NULLIF(TRIM(ri.generated_route_code), ''), NULLIF(TRIM(lr.short_code), '')) AS route_code,
                    COALESCE(NULLIF(TRIM(lr.name), ''), NULLIF(TRIM(ri.generated_route_code), ''), CONCAT('Route ##', ri.id)) AS route_name
                 FROM floatplans fp
                 INNER JOIN route_instances ri
                    ON ri.id = fp.route_instance_id
                   AND ri.user_id = :routeUserId
                 LEFT JOIN loop_routes lr ON lr.id = ri.generated_route_id
                 WHERE fp.userId = :planUserId
                   AND UPPER(TRIM(fp.`status`)) = 'DRAFT'
                   AND fp.activatedAt IS NULL
                   AND fp.initialSentAt IS NULL
                   AND fp.checkedInAt IS NULL
                   AND fp.closedAt IS NULL
                 ORDER BY fp.floatplanId DESC
                 LIMIT 2",
                {
                    planUserId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                    routeUserId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" }
                },
                { datasource = "fpw" }
            );

            qActive = queryExecute(
                "SELECT
                    fp.floatplanId,
                    fp.floatPlanName,
                    fp.route_instance_id,
                    fp.route_day_number,
                    'ACTIVE' AS statusValue,
                    COALESCE(NULLIF(TRIM(ri.generated_route_code), ''), NULLIF(TRIM(lr.short_code), '')) AS route_code,
                    COALESCE(NULLIF(TRIM(lr.name), ''), NULLIF(TRIM(ri.generated_route_code), ''), CONCAT('Route ##', ri.id)) AS route_name
                 FROM floatplans fp
                 INNER JOIN route_instances ri
                    ON ri.id = fp.route_instance_id
                   AND ri.user_id = :routeUserId
                 LEFT JOIN loop_routes lr ON lr.id = ri.generated_route_id
                 WHERE fp.userId = :planUserId
                   AND UPPER(TRIM(fp.`status`)) = 'ACTIVE'
                   AND fp.route_instance_id IS NOT NULL
                 ORDER BY fp.activatedAt DESC, fp.floatplanId DESC
                 LIMIT 2",
                {
                    planUserId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                    routeUserId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" }
                },
                { datasource = "fpw" }
            );

            if (qDraft.recordCount GT 1) {
                result.ERROR = "MULTIPLE_CURRENT_DRAFT_GROUPS";
                result.MESSAGE = "Multiple current draft route/float-plan groups exist for this user.";
                return result;
            }

            if (qActive.recordCount GT 1) {
                result.ERROR = "MULTIPLE_ACTIVE_GROUPS";
                result.MESSAGE = "Multiple active route/float-plan groups exist for this user.";
                return result;
            }

            if (qDraft.recordCount GT 0 AND qActive.recordCount GT 0) {
                result.ERROR = "CURRENT_GROUP_CONFLICT";
                result.MESSAGE = "A current draft group and an active group both exist for this user.";
                return result;
            }

            if (qDraft.recordCount EQ 0 AND qActive.recordCount EQ 0) {
                return result;
            }

            if (qDraft.recordCount EQ 1) {
                row = qDraft;
                result.CURRENT_STATE = "DRAFT";
                result.IS_DRAFT = true;
            } else {
                row = qActive;
                result.CURRENT_STATE = "ACTIVE";
                result.IS_ACTIVE = true;
            }

            result.SUCCESS = true;
            result.success = true;
            result.HAS_CURRENT_GROUP = true;
            result.MESSAGE = "OK";
            result.FLOATPLANID = val(row.floatplanId[1]);
            result.FLOATPLAN_NAME = isNull(row.floatPlanName[1]) ? "" : trim(toString(row.floatPlanName[1]));
            result.STATUS = isNull(row.statusValue[1]) ? "" : trim(toString(row.statusValue[1]));
            result.ROUTE_INSTANCE_ID = isNull(row.route_instance_id[1]) ? 0 : val(row.route_instance_id[1]);
            result.ROUTE_DAY_NUMBER = isNull(row.route_day_number[1]) ? 0 : val(row.route_day_number[1]);
            result.ROUTE_CODE = isNull(row.route_code[1]) ? "" : trim(toString(row.route_code[1]));
            result.ROUTE_NAME = isNull(row.route_name[1]) ? "" : trim(toString(row.route_name[1]));
            result.IS_ROUTE_MATCH = (useRouteInstanceId GT 0 AND result.ROUTE_INSTANCE_ID EQ useRouteInstanceId);
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="resolveCanonicalActiveFloatPlan" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = {
                SUCCESS = false,
                success = false,
                MESSAGE = ""
            };
            var currentGroup = {};

            if (arguments.userId LTE 0 OR arguments.floatPlanId LTE 0) {
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }

            currentGroup = resolveCurrentRouteFloatPlanGroup(arguments.userId);
            if (!currentGroup.SUCCESS OR !currentGroup.IS_ACTIVE) {
                result.ERROR = "NO_ACTIVE_PLAN";
                result.MESSAGE = "No active trip is available.";
                return result;
            }

            result.FLOATPLANID = currentGroup.FLOATPLANID;
            result.ROUTE_INSTANCE_ID = currentGroup.ROUTE_INSTANCE_ID;
            result.STATUS = currentGroup.STATUS;

            if (result.FLOATPLANID NEQ arguments.floatPlanId) {
                result.ERROR = "ACTIVE_PLAN_MISMATCH";
                result.MESSAGE = "Only the current active trip can be updated from Active Cruise.";
                return result;
            }

            if (result.ROUTE_INSTANCE_ID LTE 0) {
                result.ERROR = "ROUTE_REQUIRED";
                result.MESSAGE = "The active float plan must be linked to a route.";
                return result;
            }

            result.SUCCESS = true;
            result.success = true;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="submitCanonicalCompanionCheckin" access="public" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="payload" type="struct" required="true">
        <cfscript>
            var checkinId = 0;
            var checkinStatus = trim(structKeyExists(arguments.payload, "status") ? toString(arguments.payload.status) : "");
            var checkinNote = (structKeyExists(arguments.payload, "note") ? toString(arguments.payload.note) : "");
            var checkinContext = trim(
                structKeyExists(arguments.payload, "checkinContext")
                    ? toString(arguments.payload.checkinContext)
                    : (structKeyExists(arguments.payload, "checkin_context") ? toString(arguments.payload.checkin_context) : "")
            );
            var activeCruiseCheckinGuard = {};
            var cruiseCheckinResult = {};

            if (structKeyExists(arguments.payload, "floatPlanId")) {
                checkinId = val(arguments.payload.floatPlanId);
            } else if (structKeyExists(arguments.payload, "id")) {
                checkinId = val(arguments.payload.id);
            }

            activeCruiseCheckinGuard = resolveCanonicalActiveFloatPlan(arguments.userId, checkinId);
            if (!activeCruiseCheckinGuard.SUCCESS) {
                activeCruiseCheckinGuard.AUTH = true;
                return activeCruiseCheckinGuard;
            }

            cruiseCheckinResult = submitActiveCruiseCheckIn(arguments.userId, checkinId, checkinStatus, checkinNote, checkinContext);
            if (structKeyExists(cruiseCheckinResult, "success") AND !structKeyExists(cruiseCheckinResult, "SUCCESS")) {
                cruiseCheckinResult.SUCCESS = cruiseCheckinResult.success;
            }
            if (structKeyExists(cruiseCheckinResult, "SUCCESS") AND !structKeyExists(cruiseCheckinResult, "success")) {
                cruiseCheckinResult.success = cruiseCheckinResult.SUCCESS;
            }
            cruiseCheckinResult.AUTH = true;
            return cruiseCheckinResult;
        </cfscript>
    </cffunction>

    <cffunction name="mergeWaypointOptions" access="private" returntype="array" output="false">
        <cfargument name="baseWaypoints" type="array" required="true">
        <cfargument name="routeOptions" type="array" required="true">
        <cfscript>
            var out = [];
            var seen = {};
            var i = 0;
            var idVal = 0;
            var key = "";

            for (i = 1; i LTE arrayLen(arguments.baseWaypoints); i++) {
                idVal = val(arguments.baseWaypoints[i].WAYPOINTID);
                key = toString(idVal);
                if (structKeyExists(seen, key)) {
                    continue;
                }
                seen[key] = true;
                arrayAppend(out, arguments.baseWaypoints[i]);
            }

            for (i = 1; i LTE arrayLen(arguments.routeOptions); i++) {
                idVal = val(arguments.routeOptions[i].WAYPOINTID);
                key = toString(idVal);
                if (structKeyExists(seen, key)) {
                    continue;
                }
                seen[key] = true;
                arrayAppend(out, arguments.routeOptions[i]);
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="buildRouteDefaults" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlan" type="struct" required="true">
        <cfargument name="operators" type="array" required="true">
        <cfargument name="waypoints" type="array" required="true">
        <cfscript>
            var defaults = {
                IS_FROM_ROUTE = false,
                ROUTE_INSTANCE_ID = 0,
                ROUTE_DAY_NUMBER = 0,
                ROUTE_TYPE = "",
                ROUTE_CODE = "",
                ROUTE_START_DATE = "",
                LEG_COUNT = 0,
                OPERATOR_ID = 0,
                OPERATOR_SOURCE = "",
                DATES_SOURCE = "",
                DEPARTING_FROM_DEFAULT = "",
                RETURNING_TO_DEFAULT = "",
                DEPARTURE_TIME_DEFAULT = "",
                RETURN_TIME_DEFAULT = "",
                WAYPOINT_SOURCE = "",
                WAYPOINT_OPTIONS = [],
                WAYPOINT_SELECTIONS = []
            };
            var routeInstanceId = val(pickValue(arguments.floatPlan, ["ROUTE_INSTANCE_ID", "route_instance_id"], 0));
            var routeDayNumber = val(pickValue(arguments.floatPlan, ["ROUTE_DAY_NUMBER", "route_day_number"], 0));
            var qInst = queryNew("");
            var qLegs = queryNew("");
            var routeInputs = {};
            var routeTypeRaw = "";
            var routeStartDate = "";
            var startDateSource = "";
            var legCount = 0;
            var i = 0;
            var routeType = "";
            var routeIdFromInput = 0;
            var waypointById = {};
            var waypointByName = {};
            var waypointNameKey = "";
            var wp = {};
            var routeOptions = [];
            var routeSelections = [];
            var uniqueIds = {};
            var routeWaypointIds = [];
            var qCustomLegs = queryNew("");
            var candidateNames = [];
            var legStartName = "";
            var legEndName = "";
            var candidateName = "";
            var seenNameKeys = {};
            var selectedId = 0;
            var optionEntry = {};
            var selectionEntry = {};
            var nextVirtualId = -900000;
            var arrTime = "";
            var depTime = "";

            if (routeInstanceId LTE 0) {
                return defaults;
            }

            defaults.IS_FROM_ROUTE = true;
            defaults.ROUTE_INSTANCE_ID = routeInstanceId;
            defaults.ROUTE_DAY_NUMBER = routeDayNumber;

            qInst = queryExecute(
                "SELECT id, generated_route_code, routegen_inputs_json
                 FROM route_instances
                 WHERE id = :routeInstanceId
                   AND user_id = :userId
                 LIMIT 1",
                {
                    routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer" },
                    userId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" }
                },
                { datasource = "fpw" }
            );
            if (qInst.recordCount EQ 0) {
                return defaults;
            }

            defaults.ROUTE_CODE = (isNull(qInst.generated_route_code[1]) ? "" : trim(toString(qInst.generated_route_code[1])));
            routeInputs = parseRouteInputs(isNull(qInst.routegen_inputs_json[1]) ? "" : qInst.routegen_inputs_json[1]);

            routeTypeRaw = lCase(trim(toString(structKeyExists(routeInputs, "route_type") ? routeInputs.route_type : "")));
            if (routeTypeRaw EQ "my_route" OR routeTypeRaw EQ "my_routes" OR routeTypeRaw EQ "custom") {
                routeType = "custom";
            } else {
                routeType = "template";
            }
            defaults.ROUTE_TYPE = routeType;

            routeStartDate = normalizeIsoDate(toString(structKeyExists(routeInputs, "start_date") ? routeInputs.start_date : ""));
            if (len(routeStartDate)) {
                startDateSource = "route_start_date";
            } else {
                routeStartDate = dateFormat(now(), "yyyy-mm-dd");
                startDateSource = "fallback_today_noon";
            }
            defaults.ROUTE_START_DATE = routeStartDate;
            defaults.DATES_SOURCE = startDateSource;

            qLegs = queryExecute(
                "SELECT leg_order, start_name, end_name
                 FROM route_instance_legs
                 WHERE route_instance_id = :routeInstanceId
                 ORDER BY leg_order ASC, id ASC",
                {
                    routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = "fpw" }
            );
            legCount = qLegs.recordCount;
            defaults.LEG_COUNT = legCount;
            if (legCount GT 0) {
                defaults.DEPARTING_FROM_DEFAULT = (isNull(qLegs.start_name[1]) ? "" : trim(toString(qLegs.start_name[1])));
                defaults.RETURNING_TO_DEFAULT = (isNull(qLegs.end_name[legCount]) ? "" : trim(toString(qLegs.end_name[legCount])));
            }

            defaults.DEPARTURE_TIME_DEFAULT = buildNoonTimestampFromIsoDate(routeStartDate, 0);
            defaults.RETURN_TIME_DEFAULT = buildNoonTimestampFromIsoDate(routeStartDate, legCount);

            if (val(arguments.floatPlan.OPERATORID) GT 0) {
                defaults.OPERATOR_ID = val(arguments.floatPlan.OPERATORID);
                defaults.OPERATOR_SOURCE = "existing_plan";
            } else if (arrayLen(arguments.operators) GT 0 AND val(arguments.operators[1].OPERATORID) GT 0) {
                defaults.OPERATOR_ID = val(arguments.operators[1].OPERATORID);
                defaults.OPERATOR_SOURCE = "first_available";
            } else {
                defaults.OPERATOR_ID = 0;
                defaults.OPERATOR_SOURCE = "none_available";
            }

            for (i = 1; i LTE arrayLen(arguments.waypoints); i++) {
                wp = arguments.waypoints[i];
                selectedId = val(wp.WAYPOINTID);
                if (selectedId GT 0) {
                    waypointById[toString(selectedId)] = wp;
                }
                waypointNameKey = lCase(trim(toString(wp.WAYPOINTNAME)));
                if (len(waypointNameKey) AND !structKeyExists(waypointByName, waypointNameKey)) {
                    waypointByName[waypointNameKey] = wp;
                }
            }

            if (routeType EQ "custom") {
                routeIdFromInput = val(structKeyExists(routeInputs, "route_id") ? routeInputs.route_id : 0);
                if (routeIdFromInput GT 0 AND hasUserRouteWaypointColumns()) {
                    qCustomLegs = queryExecute(
                        "SELECT start_waypoint_id, end_waypoint_id
                         FROM user_route_legs
                         WHERE user_route_id = :routeId
                         ORDER BY order_index ASC, id ASC",
                        {
                            routeId = { value = routeIdFromInput, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = "fpw" }
                    );
                    if (qCustomLegs.recordCount GT 0) {
                        selectedId = (isNull(qCustomLegs.start_waypoint_id[1]) ? 0 : val(qCustomLegs.start_waypoint_id[1]));
                        if (selectedId GT 0) {
                            arrayAppend(routeWaypointIds, selectedId);
                        }
                        for (i = 1; i LTE qCustomLegs.recordCount; i++) {
                            selectedId = (isNull(qCustomLegs.end_waypoint_id[i]) ? 0 : val(qCustomLegs.end_waypoint_id[i]));
                            if (selectedId GT 0) {
                                arrayAppend(routeWaypointIds, selectedId);
                            }
                        }
                    }
                }

                for (i = 1; i LTE arrayLen(routeWaypointIds); i++) {
                    selectedId = val(routeWaypointIds[i]);
                    if (selectedId LTE 0) {
                        continue;
                    }
                    if (structKeyExists(uniqueIds, toString(selectedId))) {
                        continue;
                    }
                    uniqueIds[toString(selectedId)] = true;
                    if (structKeyExists(waypointById, toString(selectedId))) {
                        optionEntry = duplicate(waypointById[toString(selectedId)]);
                        optionEntry.IS_ROUTE_DEFAULT = true;
                        arrayAppend(routeOptions, optionEntry);
                        arrayAppend(routeSelections, {
                            WAYPOINTID = selectedId,
                            SORT_ORDER = arrayLen(routeSelections) + 1,
                            REASON_FOR_STOP = "",
                            DEPART_MODE = "",
                            ARRIVAL_TIME = "",
                            DEPARTURE_TIME = ""
                        });
                    }
                }

                if (!arrayLen(routeOptions) AND legCount GT 0) {
                    arrayAppend(candidateNames, (isNull(qLegs.start_name[1]) ? "" : trim(toString(qLegs.start_name[1]))));
                    for (i = 1; i LTE legCount; i++) {
                        arrayAppend(candidateNames, (isNull(qLegs.end_name[i]) ? "" : trim(toString(qLegs.end_name[i]))));
                    }
                    for (i = 1; i LTE arrayLen(candidateNames); i++) {
                        candidateName = trim(toString(candidateNames[i]));
                        if (!len(candidateName)) {
                            continue;
                        }
                        waypointNameKey = lCase(candidateName);
                        if (structKeyExists(seenNameKeys, waypointNameKey)) {
                            continue;
                        }
                        seenNameKeys[waypointNameKey] = true;
                        if (structKeyExists(waypointByName, waypointNameKey)) {
                            selectedId = val(waypointByName[waypointNameKey].WAYPOINTID);
                            if (structKeyExists(uniqueIds, toString(selectedId))) {
                                continue;
                            }
                            uniqueIds[toString(selectedId)] = true;
                            optionEntry = duplicate(waypointByName[waypointNameKey]);
                            optionEntry.IS_ROUTE_DEFAULT = true;
                            arrayAppend(routeOptions, optionEntry);
                            arrayAppend(routeSelections, {
                                WAYPOINTID = selectedId,
                                SORT_ORDER = arrayLen(routeSelections) + 1,
                                REASON_FOR_STOP = "",
                                DEPART_MODE = "",
                                ARRIVAL_TIME = "",
                                DEPARTURE_TIME = ""
                            });
                        } else {
                            optionEntry = {
                                WAYPOINTID = nextVirtualId,
                                WAYPOINTNAME = candidateName,
                                LATITUDE = "",
                                LONGITUDE = "",
                                NOTES = "",
                                IS_ROUTE_DEFAULT = true,
                                IS_ROUTE_VIRTUAL = true
                            };
                            arrayAppend(routeOptions, optionEntry);
                            arrayAppend(routeSelections, {
                                WAYPOINTID = nextVirtualId,
                                SORT_ORDER = arrayLen(routeSelections) + 1,
                                REASON_FOR_STOP = "",
                                DEPART_MODE = "",
                                ARRIVAL_TIME = "",
                                DEPARTURE_TIME = ""
                            });
                            nextVirtualId = nextVirtualId - 1;
                        }
                    }
                }

                defaults.WAYPOINT_SOURCE = (arrayLen(routeOptions) ? "custom_route_ordered" : "none");
            } else {
                for (i = 1; i LTE legCount; i++) {
                    legStartName = (isNull(qLegs.start_name[i]) ? "" : trim(toString(qLegs.start_name[i])));
                    legEndName = (isNull(qLegs.end_name[i]) ? "" : trim(toString(qLegs.end_name[i])));
                    optionEntry = {
                        WAYPOINTID = nextVirtualId,
                        WAYPOINTNAME = "Leg " & i & ": " & (len(legStartName) ? legStartName : "Start") & " -> " & (len(legEndName) ? legEndName : "End"),
                        LATITUDE = "",
                        LONGITUDE = "",
                        NOTES = "",
                        IS_ROUTE_DEFAULT = true,
                        IS_ROUTE_TEMPLATE_LEG = true
                    };
                    arrayAppend(routeOptions, optionEntry);
                    arrTime = buildNoonTimestampFromIsoDate(routeStartDate, i);
                    depTime = arrTime;
                    selectionEntry = {
                        WAYPOINTID = nextVirtualId,
                        SORT_ORDER = i,
                        REASON_FOR_STOP = "",
                        DEPART_MODE = "",
                        ARRIVAL_TIME = arrTime,
                        DEPARTURE_TIME = depTime
                    };
                    arrayAppend(routeSelections, selectionEntry);
                    nextVirtualId = nextVirtualId - 1;
                }
                defaults.WAYPOINT_SOURCE = (arrayLen(routeOptions) ? "template_leg_entries" : "none");
            }

            defaults.WAYPOINT_OPTIONS = routeOptions;
            defaults.WAYPOINT_SELECTIONS = routeSelections;
            return defaults;
        </cfscript>
    </cffunction>

    <cffunction name="hasUserRouteWaypointColumns" access="private" returntype="boolean" output="false">
        <cfscript>
            var qCol = queryNew("");
            if (structKeyExists(request, "hasUserRouteWaypointColumns")) {
                return request.hasUserRouteWaypointColumns;
            }
            qCol = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.columns
                 WHERE table_schema = DATABASE()
                   AND table_name = 'user_route_legs'
                   AND column_name IN ('start_waypoint_id', 'end_waypoint_id')",
                {},
                { datasource = "fpw" }
            );
            request.hasUserRouteWaypointColumns = (qCol.recordCount GT 0 AND val(qCol.cnt[1]) GTE 2);
            return request.hasUserRouteWaypointColumns;
        </cfscript>
    </cffunction>

    <cffunction name="parseRouteInputs" access="private" returntype="struct" output="false">
        <cfargument name="rawJson" required="false" default="">
        <cfscript>
            var parsed = {};
            var raw = trim(toString(arguments.rawJson));
            if (!len(raw)) {
                return {};
            }
            try {
                parsed = deserializeJSON(raw, false);
                if (isStruct(parsed)) {
                    return parsed;
                }
            } catch (any ignored) {}
            return {};
        </cfscript>
    </cffunction>

    <cffunction name="normalizeIsoDate" access="private" returntype="string" output="false">
        <cfargument name="value" required="true">
        <cfscript>
            var raw = trim(toString(arguments.value));
            if (!len(raw)) {
                return "";
            }
            if (reFind("^\d{4}-\d{2}-\d{2}$", raw)) {
                return raw;
            }
            if (reFind("^\d{4}-\d{2}-\d{2}T", raw)) {
                return left(raw, 10);
            }
            if (isDate(raw)) {
                return dateFormat(parseDateTime(raw), "yyyy-mm-dd");
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="buildNoonTimestampFromIsoDate" access="private" returntype="string" output="false">
        <cfargument name="isoDate" type="string" required="true">
        <cfargument name="dayOffset" type="numeric" required="false" default="0">
        <cfscript>
            var d = trim(arguments.isoDate);
            var y = 0;
            var m = 0;
            var dayNum = 0;
            var dt = "";
            if (!reFind("^\d{4}-\d{2}-\d{2}$", d)) {
                return "";
            }
            y = val(left(d, 4));
            m = val(mid(d, 6, 2));
            dayNum = val(right(d, 2));
            if (y LTE 0 OR m LTE 0 OR dayNum LTE 0) {
                return "";
            }
            dt = createDateTime(y, m, dayNum, 12, 0, 0);
            dt = dateAdd("d", val(arguments.dayOffset), dt);
            return dateFormat(dt, "yyyy-mm-dd") & " " & timeFormat(dt, "HH:mm:ss");
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
            var departureTimeUtcInput = trim(pickValue(floatPlan, ["departureTimeUtc", "DEPARTURE_TIME_UTC"], ""));
            var returnTimeUtcInput = trim(pickValue(floatPlan, ["returnTimeUtc", "RETURN_TIME_UTC"], ""));
            var foodDays        = trim(pickValue(floatPlan, ["foodDaysPerPerson", "FOOD_DAYS_PER_PERSON"], ""));
            var waterDays       = trim(pickValue(floatPlan, ["waterDaysPerPerson", "WATER_DAYS_PER_PERSON"], ""));
            var notes           = trim(pickValue(floatPlan, ["notes", "NOTES"], ""));
            var routeInstanceId = val(pickValue(floatPlan, ["routeInstanceId", "ROUTE_INSTANCE_ID", "route_instance_id"], 0));
            var routeDayNumber  = val(pickValue(floatPlan, ["routeDayNumber", "ROUTE_DAY_NUMBER", "route_day_number"], 0));
            var doNotSend       = booleanValue(pickValue(floatPlan, ["doNotSend", "DO_NOT_SEND"], false));
            var departureTimeUtc = "";
            var returnTimeUtc = "";
            var departureTimeLocal = "";
            var returnTimeLocal = "";
            var departureTimeUtcStore = "";
            var returnTimeUtcStore = "";
            var departureTzStore = departureTz;
            var returnTzStore = returnTz;
            var departureSourceTz = departureTz;
            var returnSourceTz = returnTz;
            var existingPlanRow = queryNew("");
            var existingRouteInstanceId = 0;
            var existingStatus = "";
            var currentGroup = {};
            var memberGateResult = {};

            if (planId GT 0) {
                existingPlanRow = queryExecute(
                    "SELECT floatplanId, route_instance_id, UPPER(TRIM(`status`)) AS statusValue
                       FROM floatplans
                      WHERE floatplanId = :planId
                        AND userId = :userId
                      LIMIT 1",
                    {
                        planId = { value = planId, cfsqltype = "cf_sql_integer" },
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = "fpw" }
                );

                if (existingPlanRow.recordCount EQ 0) {
                    result.ERROR = "NOT_FOUND";
                    result.MESSAGE = "Float plan not found.";
                    return result;
                }

                existingRouteInstanceId = isNull(existingPlanRow.route_instance_id[1])
                    ? 0
                    : val(existingPlanRow.route_instance_id[1]);
                existingStatus = isNull(existingPlanRow.statusValue[1])
                    ? ""
                    : trim(toString(existingPlanRow.statusValue[1]));
            }

            if (planId LTE 0) {
                if (routeInstanceId GT 0 AND !userOwnsRouteInstance(arguments.userId, routeInstanceId)) {
                    result.ERROR = "INVALID_ROUTE";
                    result.MESSAGE = "A valid route is required to create a float plan.";
                    return result;
                }
                if (routeInstanceId LTE 0) {
                    result.ERROR = "ROUTE_REQUIRED";
                    result.MESSAGE = "A valid route is required to create a float plan.";
                    return result;
                }
            } else if (existingRouteInstanceId GT 0) {
                if (routeInstanceId LTE 0) {
                    result.ERROR = "ROUTE_REQUIRED";
                    result.MESSAGE = "Route linkage cannot be removed from an existing float plan.";
                    return result;
                }
                if (routeInstanceId NEQ existingRouteInstanceId) {
                    result.ERROR = "ROUTE_LOCKED";
                    result.MESSAGE = "Route linkage cannot be changed from the float plan wizard.";
                    return result;
                }
                if (!userOwnsRouteInstance(arguments.userId, routeInstanceId)) {
                    result.ERROR = "INVALID_ROUTE";
                    result.MESSAGE = "A valid route is required to update this float plan.";
                    return result;
                }
            } else {
                result.ERROR = "ROUTE_REQUIRED";
                result.MESSAGE = "Legacy route-less float plans cannot be updated from the float plan wizard.";
                return result;
            }

            currentGroup = resolveCurrentRouteFloatPlanGroup(arguments.userId, routeInstanceId);
            if (
                structKeyExists(currentGroup, "ERROR")
                AND listFindNoCase("MULTIPLE_CURRENT_DRAFT_GROUPS,MULTIPLE_ACTIVE_GROUPS,CURRENT_GROUP_CONFLICT", trim(toString(currentGroup.ERROR))) GT 0
            ) {
                return currentGroup;
            }

            if (planId LTE 0) {
                if (currentGroup.SUCCESS AND currentGroup.HAS_CURRENT_GROUP) {
                    if (currentGroup.IS_ROUTE_MATCH) {
                        result.ERROR = "CURRENT_GROUP_ALREADY_EXISTS";
                        result.MESSAGE = "This route already has a current route/float-plan group.";
                        result.EXISTING_FLOATPLANID = currentGroup.FLOATPLANID;
                    } else {
                        result.ERROR = "ANOTHER_CURRENT_GROUP_EXISTS";
                        result.MESSAGE = "End the current route/float-plan group before starting another route.";
                        result.EXISTING_FLOATPLANID = currentGroup.FLOATPLANID;
                        result.EXISTING_ROUTE_INSTANCE_ID = currentGroup.ROUTE_INSTANCE_ID;
                        result.EXISTING_ROUTE_CODE = currentGroup.ROUTE_CODE;
                    }
                    return result;
                }
            } else if (currentGroup.SUCCESS AND currentGroup.HAS_CURRENT_GROUP) {
                if (currentGroup.FLOATPLANID NEQ planId) {
                    if (currentGroup.IS_ROUTE_MATCH) {
                        result.ERROR = "CURRENT_GROUP_ALREADY_EXISTS";
                        result.MESSAGE = "This route already has a different current route/float-plan group.";
                        result.EXISTING_FLOATPLANID = currentGroup.FLOATPLANID;
                    } else {
                        result.ERROR = "ANOTHER_CURRENT_GROUP_EXISTS";
                        result.MESSAGE = "End the current route/float-plan group before editing another route.";
                        result.EXISTING_FLOATPLANID = currentGroup.FLOATPLANID;
                        result.EXISTING_ROUTE_INSTANCE_ID = currentGroup.ROUTE_INSTANCE_ID;
                        result.EXISTING_ROUTE_CODE = currentGroup.ROUTE_CODE;
                    }
                    return result;
                }
            } else if (listFindNoCase("CLOSED,CANCELLED,CANCELED", existingStatus) GT 0) {
                result.ERROR = "HISTORICAL_GROUP_READ_ONLY";
                result.MESSAGE = "Closed or cancelled route-linked float plans are preserved as history and cannot be edited.";
                return result;
            }

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

            if (len(departureTime)) {
                if (NOT len(departureTz)) {
                    result.ERROR = "VALIDATION";
                    result.MESSAGE = "Departure time zone is required when departure time is provided.";
                    return result;
                }
                departureTimeLocal = normalizeLocalWallClockInput(departureTime);
                departureTimeUtcStore = normalizeTimestampInput(departureTimeUtcInput);
                departureTimeUtc = parseUtcTimestampInput(departureTimeUtcStore);
                if (!len(departureTimeLocal) OR !len(departureTimeUtcStore) OR NOT isDate(departureTimeUtc)) {
                    result.ERROR = "VALIDATION";
                    result.MESSAGE = "Invalid departure time or timezone.";
                    return result;
                }
                departureTzStore = departureTz;
            }

            if (len(returnTime)) {
                if (NOT len(returnTz)) {
                    result.ERROR = "VALIDATION";
                    result.MESSAGE = "Return time zone is required when return time is provided.";
                    return result;
                }
                returnTimeLocal = normalizeLocalWallClockInput(returnTime);
                returnTimeUtcStore = normalizeTimestampInput(returnTimeUtcInput);
                returnTimeUtc = parseUtcTimestampInput(returnTimeUtcStore);
                if (!len(returnTimeLocal) OR !len(returnTimeUtcStore) OR NOT isDate(returnTimeUtc)) {
                    result.ERROR = "VALIDATION";
                    result.MESSAGE = "Invalid return time or timezone.";
                    return result;
                }
                returnTzStore = returnTz;
            }

            memberGateResult = getMemberAccessGateService().validateWaypointLimit(
                userId = arguments.userId,
                waypointCount = countEffectivePayloadWaypoints(selectedWaypoints)
            );
            if (!memberGateResult.allowed) {
                return memberGateResult.response;
            }

            memberGateResult = getMemberAccessGateService().validateTripDurationLimit(
                userId = arguments.userId,
                departureAt = departureTimeUtc,
                returnAt = returnTimeUtc
            );
            if (!memberGateResult.allowed) {
                return memberGateResult.response;
            }

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
                            departureTimeUTC,
                            departTimezone,
                            departureTZ,
                            `returning`,
                            returnTime,
                            returnTimeUTC,
                            returnTimezone,
                            returnTZ,
                            food,
                            water,
                            notes,
                            route_instance_id,
                            route_day_number,
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
                            :departureTimeUtc,
                            :departureTz,
                            :departureSourceTz,
                            :returningTo,
                            :returnTime,
                            :returnTimeUtc,
                            :returnTz,
                            :returnSourceTz,
                            :foodDays,
                            :waterDays,
                            :notes,
                            :routeInstanceId,
                            :routeDayNumber,
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
                        departureTime = { value = departureTimeLocal, cfsqltype = "cf_sql_varchar", null = NOT len(departureTimeLocal) },
                        departureTimeUtc = { value = departureTimeUtcStore, cfsqltype = "cf_sql_varchar", null = NOT len(departureTimeUtcStore) },
                        departureTz = { value = departureTzStore, cfsqltype = "cf_sql_varchar", null = NOT len(departureTzStore) },
                        departureSourceTz = { value = departureSourceTz, cfsqltype = "cf_sql_varchar", null = NOT len(departureSourceTz) },
                        returningTo = { value = returningTo, cfsqltype = "cf_sql_varchar", null = NOT len(returningTo) },
                        returnTime = { value = returnTimeLocal, cfsqltype = "cf_sql_varchar", null = NOT len(returnTimeLocal) },
                        returnTimeUtc = { value = returnTimeUtcStore, cfsqltype = "cf_sql_varchar", null = NOT len(returnTimeUtcStore) },
                        returnTz = { value = returnTzStore, cfsqltype = "cf_sql_varchar", null = NOT len(returnTzStore) },
                        returnSourceTz = { value = returnSourceTz, cfsqltype = "cf_sql_varchar", null = NOT len(returnSourceTz) },
                        foodDays = { value = foodDays, cfsqltype = "cf_sql_varchar", null = NOT len(foodDays) },
                        waterDays = { value = waterDays, cfsqltype = "cf_sql_varchar", null = NOT len(waterDays) },
                        notes = { value = notes, cfsqltype = "cf_sql_varchar", null = NOT len(notes) },
                        routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer", null = (routeInstanceId LTE 0) },
                        routeDayNumber = { value = routeDayNumber, cfsqltype = "cf_sql_integer", null = (routeDayNumber LTE 0) },
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
                               departureTimeUTC    = :departureTimeUtc,
                               departTimezone      = :departureTz,
                               departureTZ         = :departureSourceTz,
                               `returning`         = :returningTo,
                               returnTime          = :returnTime,
                               returnTimeUTC       = :returnTimeUtc,
                               returnTimezone      = :returnTz,
                               returnTZ            = :returnSourceTz,
                               food                = :foodDays,
                               water               = :waterDays,
                               notes               = :notes,
                               route_instance_id   = :routeInstanceId,
                               route_day_number    = :routeDayNumber,
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
                        departureTime = { value = departureTimeLocal, cfsqltype = "cf_sql_varchar", null = NOT len(departureTimeLocal) },
                        departureTimeUtc = { value = departureTimeUtcStore, cfsqltype = "cf_sql_varchar", null = NOT len(departureTimeUtcStore) },
                        departureTz = { value = departureTzStore, cfsqltype = "cf_sql_varchar", null = NOT len(departureTzStore) },
                        departureSourceTz = { value = departureSourceTz, cfsqltype = "cf_sql_varchar", null = NOT len(departureSourceTz) },
                        returningTo = { value = returningTo, cfsqltype = "cf_sql_varchar", null = NOT len(returningTo) },
                        returnTime = { value = returnTimeLocal, cfsqltype = "cf_sql_varchar", null = NOT len(returnTimeLocal) },
                        returnTimeUtc = { value = returnTimeUtcStore, cfsqltype = "cf_sql_varchar", null = NOT len(returnTimeUtcStore) },
                        returnTz = { value = returnTzStore, cfsqltype = "cf_sql_varchar", null = NOT len(returnTzStore) },
                        returnSourceTz = { value = returnSourceTz, cfsqltype = "cf_sql_varchar", null = NOT len(returnSourceTz) },
                        foodDays = { value = foodDays, cfsqltype = "cf_sql_varchar", null = NOT len(foodDays) },
                        waterDays = { value = waterDays, cfsqltype = "cf_sql_varchar", null = NOT len(waterDays) },
                        notes = { value = notes, cfsqltype = "cf_sql_varchar", null = NOT len(notes) },
                        routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer", null = (routeInstanceId LTE 0) },
                        routeDayNumber = { value = routeDayNumber, cfsqltype = "cf_sql_integer", null = (routeDayNumber LTE 0) },
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

    <cffunction name="saveBasicFloatPlan" access="private" returntype="struct" output="false">
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
            var selectedWaypoints  = structKeyExists(arguments.payload, "WAYPOINTS") ? arguments.payload.WAYPOINTS : [];
            var basicDetails = normalizeBasicDetailsPayload(arguments.payload, floatPlan);
            var detailsValidation = {};
            var authority = {};

            var planId    = val(pickValue(floatPlan, ["floatPlanId", "FLOATPLANID"], 0));
            var planName  = trim(pickValue(floatPlan, ["floatPlanName", "NAME"], ""));
            var vesselId  = 0;
            var operatorId = 0;
            var operatorHasPfd = booleanValue(pickValue(floatPlan, ["operatorHasPfd", "OPERATOR_HAS_PFD"], false));
            var email     = basicDetails.CAPTAIN_EMAIL;
            var rescueAuthority = "";
            var rescuePhone     = "";
            var rescueCenterId  = basicDetails.AUTHORITY_ID;
            var departingFrom   = basicDetails.LAUNCH_LOCATION;
            var departureTime   = trim(pickValue(floatPlan, ["departureTime", "DEPARTURE_TIME"], ""));
            var departureTz     = trim(pickValue(floatPlan, ["departureTimezone", "DEPARTURE_TIMEZONE"], ""));
            var returningTo     = basicDetails.LAUNCH_LOCATION;
            var returnTime      = trim(pickValue(floatPlan, ["returnTime", "RETURN_TIME"], ""));
            var returnTz        = trim(pickValue(floatPlan, ["returnTimezone", "RETURN_TIMEZONE"], ""));
            var departureTimeUtcInput = trim(pickValue(floatPlan, ["departureTimeUtc", "DEPARTURE_TIME_UTC"], ""));
            var returnTimeUtcInput = trim(pickValue(floatPlan, ["returnTimeUtc", "RETURN_TIME_UTC"], ""));
            var foodDays        = trim(pickValue(floatPlan, ["foodDaysPerPerson", "FOOD_DAYS_PER_PERSON"], ""));
            var waterDays       = trim(pickValue(floatPlan, ["waterDaysPerPerson", "WATER_DAYS_PER_PERSON"], ""));
            var notes           = trim(pickValue(floatPlan, ["notes", "NOTES"], ""));
            var routeInstanceId = val(pickValue(floatPlan, ["routeInstanceId", "ROUTE_INSTANCE_ID", "route_instance_id"], 0));
            var departureTimeUtc = "";
            var returnTimeUtc = "";
            var departureTimeLocal = "";
            var returnTimeLocal = "";
            var departureTimeUtcStore = "";
            var returnTimeUtcStore = "";
            var departureTzStore = departureTz;
            var returnTzStore = returnTz;
            var departureSourceTz = departureTz;
            var returnSourceTz = returnTz;
            var memberGateResult = {};
            var existingScope = {};
            var singletonState = {};
            var ds = "fpw";

            if (routeInstanceId GT 0) {
                return getMemberAccessGateService().buildDeniedResponse(
                    errorCode = "BASIC_SAVED_ROUTE_RESTRICTED",
                    message = "Basic float plans must use route-less operational trip details, not reusable saved routes.",
                    auth = true,
                    statusCode = 403,
                    includeUpgradeOptions = true
                );
            }

            if (planId GT 0) {
                existingScope = loadBasicOperationalPlanScope(arguments.userId, planId, ds);
                if (!existingScope.EXISTS) {
                    result.ERROR = "NOT_FOUND";
                    result.MESSAGE = "Float plan not found.";
                    return result;
                }
                if (!existingScope.IS_BASIC_OPERATIONAL) {
                    return getMemberAccessGateService().buildDeniedResponse(
                        errorCode = "BASIC_SAVED_ROUTE_RESTRICTED",
                        message = "Basic members cannot update route-backed or reusable float plans through the Basic path.",
                        auth = true,
                        statusCode = 403,
                        includeUpgradeOptions = true
                    );
                }
                if (listFindNoCase("CLOSED,CANCELLED,CANCELED,ACTIVE", existingScope.STATUS) GT 0) {
                    result.ERROR = "BASIC_PLAN_READ_ONLY";
                    result.MESSAGE = "Only draft Basic float plans can be updated.";
                    return result;
                }
            }

            singletonState = getBasicOperationalSingletonState(arguments.userId, ds);
            if (singletonState.HAS_ACTIVE AND singletonState.ACTIVE_FLOATPLANID NEQ planId) {
                result.ERROR = "BASIC_ACTIVE_PLAN_EXISTS";
                result.MESSAGE = "You already have an active Basic Float Plan. Close it before creating a new one.";
                result.EXISTING_FLOATPLANID = singletonState.ACTIVE_FLOATPLANID;
                return result;
            }
            if (singletonState.HAS_DRAFT AND singletonState.DRAFT_FLOATPLANID NEQ planId) {
                result.ERROR = "BASIC_DRAFT_EXISTS";
                result.MESSAGE = "You already have a Basic Float Plan draft. Resume that draft instead of creating a new one.";
                result.EXISTING_FLOATPLANID = singletonState.DRAFT_FLOATPLANID;
                return result;
            }

            if (NOT len(planName)) {
                result.ERROR = "VALIDATION";
                result.MESSAGE = "Float plan name is required.";
                return result;
            }

            if (!hasBasicDetailsTable(ds)) {
                result.ERROR = "BASIC_DETAILS_SCHEMA_REQUIRED";
                result.MESSAGE = "Basic float plan details table is not available.";
                return result;
            }

            detailsValidation = validateBasicDetailsPayload(basicDetails);
            if (!detailsValidation.SUCCESS) {
                return detailsValidation;
            }

            authority = resolveBasicRescueAuthority(basicDetails.AUTHORITY_ID, ds);
            if (!authority.SUCCESS) {
                return authority;
            }
            rescueCenterId = authority.AUTHORITY_ID;
            rescueAuthority = authority.AUTHORITY_NAME;
            rescuePhone = authority.AUTHORITY_PHONE;
            basicDetails.AUTHORITY_ID = rescueCenterId;

            planName = ensureUniquePlanName(arguments.userId, planId, planName, ds);

            if (len(departureTime)) {
                if (NOT len(departureTz)) {
                    result.ERROR = "VALIDATION";
                    result.MESSAGE = "Departure time zone is required when departure time is provided.";
                    return result;
                }
                departureTimeLocal = normalizeLocalWallClockInput(departureTime);
                departureTimeUtc = resolvePayloadUtcTimestamp(departureTime, departureTz, departureTimeUtcInput);
                departureTimeUtcStore = normalizeTimestampInput(departureTimeUtcInput);
                if (!len(departureTimeUtcStore) AND listFindNoCase("UTC,Etc/UTC,GMT", departureTz)) {
                    departureTimeUtcStore = departureTimeLocal;
                }
                if (!len(departureTimeLocal) OR !len(departureTimeUtcStore) OR NOT isDate(departureTimeUtc)) {
                    result.ERROR = "VALIDATION";
                    result.MESSAGE = "Invalid departure time or timezone.";
                    return result;
                }
                departureTzStore = departureTz;
            }

            if (len(returnTime)) {
                if (NOT len(returnTz)) {
                    result.ERROR = "VALIDATION";
                    result.MESSAGE = "Return time zone is required when return time is provided.";
                    return result;
                }
                returnTimeLocal = normalizeLocalWallClockInput(returnTime);
                returnTimeUtc = resolvePayloadUtcTimestamp(returnTime, returnTz, returnTimeUtcInput);
                returnTimeUtcStore = normalizeTimestampInput(returnTimeUtcInput);
                if (!len(returnTimeUtcStore) AND listFindNoCase("UTC,Etc/UTC,GMT", returnTz)) {
                    returnTimeUtcStore = returnTimeLocal;
                }
                if (!len(returnTimeLocal) OR !len(returnTimeUtcStore) OR NOT isDate(returnTimeUtc)) {
                    result.ERROR = "VALIDATION";
                    result.MESSAGE = "Invalid return time or timezone.";
                    return result;
                }
                returnTzStore = returnTz;
            }

            memberGateResult = validateBasicSavedWaypointLimit(
                waypointCount = countEffectivePayloadWaypoints(selectedWaypoints)
            );
            if (!memberGateResult.allowed) {
                return memberGateResult.response;
            }

            memberGateResult = getMemberAccessGateService().validateTripDurationLimit(
                userId = arguments.userId,
                departureAt = departureTimeUtc,
                returnAt = returnTimeUtc
            );
            if (!memberGateResult.allowed) {
                return memberGateResult.response;
            }

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
                            departureTimeUTC,
                            departTimezone,
                            departureTZ,
                            `returning`,
                            returnTime,
                            returnTimeUTC,
                            returnTimezone,
                            returnTZ,
                            food,
                            water,
                            notes,
                            route_instance_id,
                            route_day_number,
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
                            :departureTimeUtc,
                            :departureTz,
                            :departureSourceTz,
                            :returningTo,
                            :returnTime,
                            :returnTimeUtc,
                            :returnTz,
                            :returnSourceTz,
                            :foodDays,
                            :waterDays,
                            :notes,
                            NULL,
                            NULL,
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
                        departureTime = { value = departureTimeLocal, cfsqltype = "cf_sql_varchar", null = NOT len(departureTimeLocal) },
                        departureTimeUtc = { value = departureTimeUtcStore, cfsqltype = "cf_sql_varchar", null = NOT len(departureTimeUtcStore) },
                        departureTz = { value = departureTzStore, cfsqltype = "cf_sql_varchar", null = NOT len(departureTzStore) },
                        departureSourceTz = { value = departureSourceTz, cfsqltype = "cf_sql_varchar", null = NOT len(departureSourceTz) },
                        returningTo = { value = returningTo, cfsqltype = "cf_sql_varchar", null = NOT len(returningTo) },
                        returnTime = { value = returnTimeLocal, cfsqltype = "cf_sql_varchar", null = NOT len(returnTimeLocal) },
                        returnTimeUtc = { value = returnTimeUtcStore, cfsqltype = "cf_sql_varchar", null = NOT len(returnTimeUtcStore) },
                        returnTz = { value = returnTzStore, cfsqltype = "cf_sql_varchar", null = NOT len(returnTzStore) },
                        returnSourceTz = { value = returnSourceTz, cfsqltype = "cf_sql_varchar", null = NOT len(returnSourceTz) },
                        foodDays = { value = foodDays, cfsqltype = "cf_sql_varchar", null = NOT len(foodDays) },
                        waterDays = { value = waterDays, cfsqltype = "cf_sql_varchar", null = NOT len(waterDays) },
                        notes = { value = notes, cfsqltype = "cf_sql_varchar", null = NOT len(notes) }
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
                               departureTimeUTC    = :departureTimeUtc,
                               departTimezone      = :departureTz,
                               departureTZ         = :departureSourceTz,
                               `returning`         = :returningTo,
                               returnTime          = :returnTime,
                               returnTimeUTC       = :returnTimeUtc,
                               returnTimezone      = :returnTz,
                               returnTZ            = :returnSourceTz,
                               food                = :foodDays,
                               water               = :waterDays,
                               notes               = :notes,
                               route_instance_id   = NULL,
                               route_day_number    = NULL,
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
                        departureTime = { value = departureTimeLocal, cfsqltype = "cf_sql_varchar", null = NOT len(departureTimeLocal) },
                        departureTimeUtc = { value = departureTimeUtcStore, cfsqltype = "cf_sql_varchar", null = NOT len(departureTimeUtcStore) },
                        departureTz = { value = departureTzStore, cfsqltype = "cf_sql_varchar", null = NOT len(departureTzStore) },
                        departureSourceTz = { value = departureSourceTz, cfsqltype = "cf_sql_varchar", null = NOT len(departureSourceTz) },
                        returningTo = { value = returningTo, cfsqltype = "cf_sql_varchar", null = NOT len(returningTo) },
                        returnTime = { value = returnTimeLocal, cfsqltype = "cf_sql_varchar", null = NOT len(returnTimeLocal) },
                        returnTimeUtc = { value = returnTimeUtcStore, cfsqltype = "cf_sql_varchar", null = NOT len(returnTimeUtcStore) },
                        returnTz = { value = returnTzStore, cfsqltype = "cf_sql_varchar", null = NOT len(returnTzStore) },
                        returnSourceTz = { value = returnSourceTz, cfsqltype = "cf_sql_varchar", null = NOT len(returnSourceTz) },
                        foodDays = { value = foodDays, cfsqltype = "cf_sql_varchar", null = NOT len(foodDays) },
                        waterDays = { value = waterDays, cfsqltype = "cf_sql_varchar", null = NOT len(waterDays) },
                        notes = { value = notes, cfsqltype = "cf_sql_varchar", null = NOT len(notes) }
                    }, { datasource = ds });

                    queryExecute("DELETE FROM floatplan_passengers WHERE floatplanId = :planId", { planId = { value = planId, cfsqltype = "cf_sql_integer" } }, { datasource = ds });
                    queryExecute("DELETE FROM floatplan_contacts WHERE floatplanId = :planId", { planId = { value = planId, cfsqltype = "cf_sql_integer" } }, { datasource = ds });
                    queryExecute("DELETE FROM floatplan_waypoints WHERE floatplanId = :planId", { planId = { value = planId, cfsqltype = "cf_sql_integer" } }, { datasource = ds });
                }

                markBasicOperationalFloatPlanScope(planId, ds);
                upsertBasicDetails(planId, basicDetails, authority, ds);

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
            var savedSelections = loadBasicPlanSelections(arguments.userId, planId, ds);

            result.SUCCESS = true;
            result.FLOATPLANID = planId;
            result.FLOATPLAN = savedPlan;
            result.BASIC_DETAILS = loadBasicDetails(planId, ds);
            result.PLAN_PASSENGERS = savedSelections.PASSENGERS;
            result.PLAN_CONTACTS = savedSelections.CONTACTS;
            result.PLAN_WAYPOINTS = savedSelections.WAYPOINTS;
            result.BASIC_OPERATIONAL_ONLY = true;
            result.ROUTE_ORIGIN = "basic_float_plan";
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
            result.ERROR = "CLONE_DISABLED";
            result.MESSAGE = "Clone Float Plan is no longer supported.";
            return result;

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
            var departureTimeUtcInput = trim(pickValue(planData, ["DEPARTURE_TIME_UTC"], ""));
            var returnTimeUtcInput = trim(pickValue(planData, ["RETURN_TIME_UTC"], ""));
            var departureTimeUtc = "";
            var returnTimeUtc = "";
            var departureTimeLocal = "";
            var returnTimeLocal = "";
            var departureTimeUtcStore = "";
            var returnTimeUtcStore = "";
            var departureTzStore = departureTz;
            var returnTzStore = returnTz;
            var departureSourceTz = departureTz;
            var returnSourceTz = returnTz;
            var foodDays = trim(pickValue(planData, ["FOOD_DAYS_PER_PERSON"], ""));
            var waterDays = trim(pickValue(planData, ["WATER_DAYS_PER_PERSON"], ""));
            var notes = trim(pickValue(planData, ["NOTES"], ""));
            var status = "Draft";

            if (len(departureTime)) {
                departureTimeLocal = normalizeLocalWallClockInput(departureTime);
                departureTimeUtcStore = normalizeTimestampInput(departureTimeUtcInput);
                if (len(departureTz)) {
                    departureTimeUtc = len(departureTimeUtcStore) ? parseUtcTimestampInput(departureTimeUtcStore) : "";
                    if (!len(departureTimeLocal) OR !len(departureTimeUtcStore) OR NOT isDate(departureTimeUtc)) {
                        result.ERROR = "INVALID_DEPARTURE_TIME";
                        result.MESSAGE = "Unable to copy departure UTC anchor for clone.";
                        return result;
                    }
                    departureTzStore = departureTz;
                } else {
                    departureTimeUtc = parseUtcTimestampInput(departureTimeUtcStore);
                }
            }

            if (len(returnTime)) {
                returnTimeLocal = normalizeLocalWallClockInput(returnTime);
                returnTimeUtcStore = normalizeTimestampInput(returnTimeUtcInput);
                if (len(returnTz)) {
                    returnTimeUtc = len(returnTimeUtcStore) ? parseUtcTimestampInput(returnTimeUtcStore) : "";
                    if (!len(returnTimeLocal) OR !len(returnTimeUtcStore) OR NOT isDate(returnTimeUtc)) {
                        result.ERROR = "INVALID_RETURN_TIME";
                        result.MESSAGE = "Unable to copy return UTC anchor for clone.";
                        return result;
                    }
                    returnTzStore = returnTz;
                } else {
                    returnTimeUtc = parseUtcTimestampInput(returnTimeUtcStore);
                }
            }

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
                        departureTimeUTC,
                        departTimezone,
                        departureTZ,
                        `returning`,
                        returnTime,
                        returnTimeUTC,
                        returnTimezone,
                        returnTZ,
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
                        :departureTimeUtc,
                        :departureTz,
                        :departureSourceTz,
                        :returningTo,
                        :returnTime,
                        :returnTimeUtc,
                        :returnTz,
                        :returnSourceTz,
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
                    departureTime = { value = departureTimeLocal, cfsqltype = "cf_sql_varchar", null = NOT len(departureTimeLocal) },
                    departureTimeUtc = { value = departureTimeUtcStore, cfsqltype = "cf_sql_varchar", null = NOT len(departureTimeUtcStore) },
                    departureTz = { value = departureTzStore, cfsqltype = "cf_sql_varchar", null = NOT len(departureTzStore) },
                    departureSourceTz = { value = departureSourceTz, cfsqltype = "cf_sql_varchar", null = NOT len(departureSourceTz) },
                    returningTo = { value = returningTo, cfsqltype = "cf_sql_varchar", null = NOT len(returningTo) },
                    returnTime = { value = returnTimeLocal, cfsqltype = "cf_sql_varchar", null = NOT len(returnTimeLocal) },
                    returnTimeUtc = { value = returnTimeUtcStore, cfsqltype = "cf_sql_varchar", null = NOT len(returnTimeUtcStore) },
                    returnTz = { value = returnTzStore, cfsqltype = "cf_sql_varchar", null = NOT len(returnTzStore) },
                    returnSourceTz = { value = returnSourceTz, cfsqltype = "cf_sql_varchar", null = NOT len(returnSourceTz) },
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

    <cffunction name="purgeFloatPlansByIds" access="public" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanIds" type="array" required="true">
        <cfscript>
            var result = {
                SUCCESS = true,
                DELETED_COUNT = 0,
                FLOATPLAN_IDS = []
            };
            var cleanIds = [];
            var i = 0;
            var planId = 0;
            var idList = "";

            for (i = 1; i LTE arrayLen(arguments.floatPlanIds); i++) {
                planId = int(val(arguments.floatPlanIds[i]));
                if (planId LTE 0) {
                    continue;
                }
                if (listFind(idList, planId) GT 0) {
                    continue;
                }
                arrayAppend(cleanIds, planId);
                idList = listAppend(idList, planId);
            }

            if (!arrayLen(cleanIds)) {
                return result;
            }

            queryExecute(
                "DELETE FROM floatplan_monitor_events
                 WHERE float_plan_id IN (:planIds)",
                {
                    planIds = { value = idList, cfsqltype = "cf_sql_integer", list = true }
                },
                { datasource = "fpw" }
            );
            queryExecute(
                "DELETE FROM floatplan_monitoring
                 WHERE float_plan_id IN (:planIds)",
                {
                    planIds = { value = idList, cfsqltype = "cf_sql_integer", list = true }
                },
                { datasource = "fpw" }
            );
            queryExecute(
                "DELETE FROM floatplan_alert_history
                 WHERE floatPlanId IN (:planIds)",
                {
                    planIds = { value = idList, cfsqltype = "cf_sql_integer", list = true }
                },
                { datasource = "fpw" }
            );
            queryExecute(
                "DELETE FROM floatplan_history
                 WHERE floatPlanId IN (:planIds)",
                {
                    planIds = { value = idList, cfsqltype = "cf_sql_integer", list = true }
                },
                { datasource = "fpw" }
            );
            queryExecute(
                "DELETE FROM floatplan_notification_log
                 WHERE floatplanId IN (:planIds)",
                {
                    planIds = { value = idList, cfsqltype = "cf_sql_integer", list = true }
                },
                { datasource = "fpw" }
            );
            queryExecute(
                "DELETE FROM floatplan_notifications
                 WHERE floatplanId IN (:planIds)",
                {
                    planIds = { value = idList, cfsqltype = "cf_sql_integer", list = true }
                },
                { datasource = "fpw" }
            );
            queryExecute(
                "DELETE FROM floatplan_contacts
                 WHERE floatPlanId IN (:planIds)",
                {
                    planIds = { value = idList, cfsqltype = "cf_sql_integer", list = true }
                },
                { datasource = "fpw" }
            );
            queryExecute(
                "DELETE FROM floatplan_operators
                 WHERE floatPlanId IN (:planIds)",
                {
                    planIds = { value = idList, cfsqltype = "cf_sql_integer", list = true }
                },
                { datasource = "fpw" }
            );
            queryExecute(
                "DELETE FROM floatplan_passengers
                 WHERE floatPlanId IN (:planIds)",
                {
                    planIds = { value = idList, cfsqltype = "cf_sql_integer", list = true }
                },
                { datasource = "fpw" }
            );
            queryExecute(
                "DELETE FROM floatplan_vessels
                 WHERE floatPlanId IN (:planIds)",
                {
                    planIds = { value = idList, cfsqltype = "cf_sql_integer", list = true }
                },
                { datasource = "fpw" }
            );
            queryExecute(
                "DELETE FROM floatplan_waypoints
                 WHERE floatPlanId IN (:planIds)",
                {
                    planIds = { value = idList, cfsqltype = "cf_sql_integer", list = true }
                },
                { datasource = "fpw" }
            );
            queryExecute(
                "DELETE FROM floatplans_tosend
                 WHERE floatPlanId IN (:planIds)",
                {
                    planIds = { value = idList, cfsqltype = "cf_sql_integer", list = true }
                },
                { datasource = "fpw" }
            );
            queryExecute(
                "DELETE FROM fpw_notification_log
                 WHERE floatPlanId IN (:planIds)",
                {
                    planIds = { value = idList, cfsqltype = "cf_sql_integer", list = true }
                },
                { datasource = "fpw" }
            );
            if (hasBasicDetailsTable("fpw")) {
                queryExecute(
                    "DELETE FROM floatplan_basic_details
                     WHERE floatplan_id IN (:planIds)",
                    {
                        planIds = { value = idList, cfsqltype = "cf_sql_integer", list = true }
                    },
                    { datasource = "fpw" }
                );
            }
            queryExecute(
                "DELETE FROM floatplans
                 WHERE floatplanId IN (:planIds)
                   AND userId = :userId",
                {
                    planIds = { value = idList, cfsqltype = "cf_sql_integer", list = true },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = "fpw" }
            );

            result.DELETED_COUNT = arrayLen(cleanIds);
            result.FLOATPLAN_IDS = cleanIds;
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
                SELECT floatplanId, route_instance_id, UPPER(TRIM(`status`)) AS statusValue
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
            var routeInstanceId = 0;
            if (listFindNoCase(planExists.columnList, "statusValue") GT 0) {
                planStatus = trim(toString(planExists["statusValue"][1]));
            }
            if (listFindNoCase(planExists.columnList, "route_instance_id") GT 0) {
                routeInstanceId = isNull(planExists.route_instance_id[1]) ? 0 : val(planExists.route_instance_id[1]);
            }
            if (routeInstanceId GT 0) {
                result.ERROR = "ROUTE_GROUP_DELETE_REQUIRED";
                result.MESSAGE = "Delete the parent route to remove a route-linked float plan.";
                return result;
            }
            if (listFindNoCase("DRAFT,CLOSED,CANCELLED,CANCELED", planStatus) EQ 0) {
                result.ERROR = "DELETE_BLOCKED";
                result.MESSAGE = "Only draft or closed float plans can be deleted.";
                return result;
            }

            transaction {
                purgeFloatPlansByIds(arguments.userId, [ arguments.floatPlanId ]);
            }

            result.SUCCESS = true;
            result.FLOATPLANID = arguments.floatPlanId;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="deleteAllFloatPlansByUser" access="private" returntype="struct" output="false">
        <cfargument name="requestingUserId" type="numeric" required="true">
        <cfargument name="targetUserId" type="numeric" required="true">
        <cfscript>
            var result = {
                SUCCESS = false,
                TARGET_USER_ID = arguments.targetUserId,
                DELETED_COUNT = 0,
                SKIPPED_COUNT = 0,
                DELETED_IDS = [],
                SKIPPED = []
            };
            var qPlans = queryNew("");
            var i = 0;
            var planId = 0;
            var planStatus = "";
            var deleteRes = {};

            if (arguments.targetUserId LTE 0) {
                result.ERROR = "INVALID_USER_ID";
                result.MESSAGE = "A valid target userId is required.";
                return result;
            }

            if (!isAdminBulkDeleteUser(arguments.requestingUserId)) {
                result.ERROR = "FORBIDDEN";
                result.MESSAGE = "This action is restricted to admin access.";
                return result;
            }

            qPlans = queryExecute(
                "SELECT floatplanId, UPPER(TRIM(`status`)) AS statusValue
                   FROM floatplans
                  WHERE userId = :userId
                  ORDER BY floatplanId DESC",
                {
                    userId = { value = arguments.targetUserId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = "fpw" }
            );

            if (qPlans.recordCount EQ 0) {
                result.SUCCESS = true;
                result.MESSAGE = "No float plans found for user.";
                return result;
            }

            for (i = 1; i LTE qPlans.recordCount; i++) {
                planId = val(qPlans.floatplanId[i]);
                planStatus = trim(toString(qPlans.statusValue[i]));
                deleteRes = deleteFloatPlan(arguments.targetUserId, planId);
                if (structKeyExists(deleteRes, "SUCCESS") AND deleteRes.SUCCESS) {
                    arrayAppend(result.DELETED_IDS, planId);
                } else {
                    arrayAppend(result.SKIPPED, {
                        FLOATPLANID = planId,
                        STATUS = planStatus,
                        ERROR = structKeyExists(deleteRes, "ERROR") ? deleteRes.ERROR : "DELETE_FAILED",
                        MESSAGE = structKeyExists(deleteRes, "MESSAGE") ? deleteRes.MESSAGE : "Unable to delete float plan."
                    });
                }
            }

            result.DELETED_COUNT = arrayLen(result.DELETED_IDS);
            result.SKIPPED_COUNT = arrayLen(result.SKIPPED);
            result.SUCCESS = true;
            result.MESSAGE = "Processed " & qPlans.recordCount & " plan(s): " & result.DELETED_COUNT & " deleted, " & result.SKIPPED_COUNT & " skipped.";
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="isAdminBulkDeleteUser" access="private" returntype="boolean" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfscript>
            var allowedIds = "187";
            if (structKeyExists(application, "adminBulkDeleteUserIds")) {
                allowedIds = toString(application.adminBulkDeleteUserIds);
            }
            return listFindNoCase(allowedIds, trim(toString(arguments.userId))) GT 0;
        </cfscript>
    </cffunction>

    <cffunction name="checkInFloatPlan" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = { SUCCESS = false };
            var updateSql = "";
            var monitoringService = {};
            var monitoringResult = {};
            var qPlan = queryNew("");
            var planStatus = "";
            var routeInstanceId = 0;
            var requiresRouteCloseValidation = false;
            var scheduledStartState = {};
            var allowMissingMonitoringClose = false;
            var hasOpenMonitoring = false;
            var closeCanonicalActivityService = {};
            var closeCanonicalActivityResult = {};
            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }

            qPlan = queryExecute(
                "SELECT
                    fp.route_instance_id,
                    UPPER(TRIM(fp.`status`)) AS statusValue,
                    m.id AS monitoringId,
                    UPPER(TRIM(m.monitor_state)) AS monitorState
                 FROM floatplans fp
                 LEFT JOIN (
                    SELECT m1.id, m1.float_plan_id, m1.monitor_state
                    FROM floatplan_monitoring m1
                    INNER JOIN (
                        SELECT MAX(id) AS id
                        FROM floatplan_monitoring
                        WHERE float_plan_id = :planId
                          AND is_monitoring_enabled = 1
                          AND UPPER(TRIM(monitor_state)) <> 'CLOSED'
                        GROUP BY float_plan_id
                    ) latest ON latest.id = m1.id
                 ) m ON m.float_plan_id = fp.floatplanId
                 WHERE fp.floatplanId = :planId
                   AND fp.userId = :userId
                 LIMIT 1",
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = "fpw" }
            );

            if (qPlan.recordCount EQ 0) {
                result.ERROR = "NOT_FOUND";
                result.MESSAGE = "Float plan not found.";
                return result;
            }

            planStatus = trim(toString(qPlan.statusValue[1]));
            routeInstanceId = isNull(qPlan.route_instance_id[1]) ? 0 : val(qPlan.route_instance_id[1]);
            requiresRouteCloseValidation = (routeInstanceId GT 0);
            hasOpenMonitoring = (!isNull(qPlan.monitoringId[1]) AND val(qPlan.monitoringId[1]) GT 0);

            if (requiresRouteCloseValidation) {
                if (!hasOpenMonitoring) {
                    if (planStatus EQ "ACTIVE") {
                        allowMissingMonitoringClose = true;
                    } else {
                        scheduledStartState = getScheduledStartStateForFloatPlan(arguments.userId, arguments.floatPlanId);
                        if (
                            structKeyExists(scheduledStartState, "SUCCESS")
                            AND scheduledStartState.SUCCESS
                            AND structKeyExists(scheduledStartState, "TRIP_STARTED")
                            AND !booleanValue(scheduledStartState.TRIP_STARTED)
                        ) {
                            allowMissingMonitoringClose = true;
                        }
                    }
                    if (!allowMissingMonitoringClose) {
                        result.ERROR = "NO_ACTIVE_PLAN";
                        result.MESSAGE = "No active float plan is available for check-in.";
                        return result;
                    }
                }
            } else if (!hasOpenMonitoring AND planStatus NEQ "ACTIVE") {
                result.ERROR = "NO_ACTIVE_PLAN";
                result.MESSAGE = "No active float plan is available for check-in.";
                return result;
            }

            if (requiresRouteCloseValidation) {
                try {
                    var routeProgressService = createObject("component", resolveApiV1ComponentPath("RouteProgressService")).init();
                    result.ROUTE_PROGRESS = routeProgressService.markCompletionFromFloatPlanCheckin(
                        userId = arguments.userId,
                        floatPlanId = arguments.floatPlanId,
                        datasource = "fpw"
                    );
                } catch (any routeErr) {
                    result.SUCCESS = false;
                    result.ERROR = "CLOSE_TRIP_VALIDATION_FAILED";
                    result.MESSAGE = "Unable to validate final route state for closure.";
                    result.ROUTE_PROGRESS = {
                        SUCCESS = false,
                        MATCHED = false,
                        MESSAGE = "Route progress close validation failed",
                        ERROR = routeErr.message
                    };
                    return result;
                }
            } else {
                result.ROUTE_PROGRESS = {
                    SUCCESS = true,
                    MATCHED = false,
                    SKIPPED = true,
                    MESSAGE = "Route progress close validation is not required for route-less float plans."
                };
            }

            if (NOT structKeyExists(result, "ROUTE_PROGRESS") OR NOT structKeyExists(result.ROUTE_PROGRESS, "SUCCESS") OR NOT result.ROUTE_PROGRESS.SUCCESS) {
                result.SUCCESS = false;
                result.ERROR = "CLOSE_TRIP_BLOCKED";
                result.MESSAGE = (
                    structKeyExists(result, "ROUTE_PROGRESS") AND structKeyExists(result.ROUTE_PROGRESS, "MESSAGE")
                        ? result.ROUTE_PROGRESS.MESSAGE
                        : "Close Trip is unavailable."
                );
                return result;
            }

            updateSql =
                "UPDATE floatplans
                 SET
                    `status` = 'CLOSED',
                    checkedInAt = UTC_TIMESTAMP(),"
                    & "
                    checkin_context = NULL,
                    closedAt = UTC_TIMESTAMP(),
                    lastUpdateStatus = UTC_TIMESTAMP()
                 WHERE floatplanId = :planId
                   AND userId = :userId
                   AND UPPER(TRIM(`status`)) NOT IN ('DRAFT','CLOSED')";

            transaction {
                queryExecute(updateSql, {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                }, { datasource = "fpw" });

                monitoringService = createObject("component", resolveApiV1ComponentPath("monitor")).init();
                monitoringResult = monitoringService.closeMonitoringForFloatPlan(arguments.floatPlanId, "final_arrival");
                if (
                    !structKeyExists(monitoringResult, "SUCCESS")
                    OR (
                        monitoringResult.SUCCESS NEQ true
                        AND (
                            (requiresRouteCloseValidation AND !allowMissingMonitoringClose)
                            OR !structKeyExists(monitoringResult, "ERROR")
                            OR uCase(trim(toString(monitoringResult.ERROR))) NEQ "MONITORING_NOT_FOUND"
                        )
                    )
                ) {
                    throw(
                        message = "Monitoring close failed.",
                        detail = serializeJSON(monitoringResult)
                    );
                }
            }

            result.SUCCESS = true;
            result.FLOATPLANID = arguments.floatPlanId;
            result.STATUS = "CLOSED";
            try {
                closeCanonicalActivityService = createObject("component", resolveApiV1ComponentPath("TripActivityWriterService")).init("fpw");
                closeCanonicalActivityResult = closeCanonicalActivityService.recordActiveCruiseRouteAction(
                    floatPlanId = arguments.floatPlanId,
                    userId = arguments.userId,
                    eventType = "FLOATPLAN_CLOSED",
                    actionLabel = "Close Float Plan",
                    statusLabel = "Float plan closed",
                    occurredAtUtc = now(),
                    routeInstanceId = routeInstanceId,
                    routeLegOrder = (
                        structKeyExists(result, "ROUTE_PROGRESS")
                        AND isStruct(result.ROUTE_PROGRESS)
                        AND structKeyExists(result.ROUTE_PROGRESS, "LEG_ORDER")
                            ? val(result.ROUTE_PROGRESS.LEG_ORDER)
                            : 0
                    ),
                    endpointResult = (
                        structKeyExists(result, "ROUTE_PROGRESS")
                        AND isStruct(result.ROUTE_PROGRESS)
                            ? result.ROUTE_PROGRESS
                            : result
                    ),
                    payload = {
                        "close_reason" = "final_arrival"
                    }
                );
                if (NOT structKeyExists(closeCanonicalActivityResult, "SUCCESS") OR closeCanonicalActivityResult.SUCCESS NEQ true) {
                    writeLog(
                        file = "fpw-canonical-activity",
                        type = "warning",
                        text = "Route action event write failed for close floatPlanId=" & arguments.floatPlanId & " result=" & left(serializeJSON(closeCanonicalActivityResult), 1000)
                    );
                }
            } catch (any closeCanonicalActivityErr) {
                writeLog(
                    file = "fpw-canonical-activity",
                    type = "warning",
                    text = "Route action event writer exception for close floatPlanId=" & arguments.floatPlanId & " message=" & left(trim(toString(closeCanonicalActivityErr.message)), 500)
                );
            }
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="cancelFloatPlan" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = { SUCCESS = false };
            var currentGroup = {};
            var monitoringService = {};
            var monitoringResult = {};

            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }

            currentGroup = resolveCurrentRouteFloatPlanGroup(arguments.userId);
            if (!currentGroup.SUCCESS OR !currentGroup.HAS_CURRENT_GROUP OR !currentGroup.IS_ACTIVE) {
                result.ERROR = "NO_ACTIVE_GROUP";
                result.MESSAGE = "No active route/float-plan group is available to cancel.";
                return result;
            }

            if (currentGroup.FLOATPLANID NEQ arguments.floatPlanId) {
                result.ERROR = "ACTIVE_GROUP_MISMATCH";
                result.MESSAGE = "Only the current active route/float-plan group can be cancelled.";
                result.EXISTING_FLOATPLANID = currentGroup.FLOATPLANID;
                result.EXISTING_ROUTE_INSTANCE_ID = currentGroup.ROUTE_INSTANCE_ID;
                result.EXISTING_ROUTE_CODE = currentGroup.ROUTE_CODE;
                return result;
            }

            transaction {
                queryExecute(
                    "UPDATE floatplans
                        SET `status` = 'CANCELLED',
                            checkin_context = NULL,
                            closedAt = UTC_TIMESTAMP(),
                            lastUpdateStatus = UTC_TIMESTAMP()
                      WHERE floatplanId = :planId
                        AND userId = :userId
                        AND UPPER(TRIM(`status`)) = 'ACTIVE'",
                    {
                        planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = "fpw" }
                );

                monitoringService = createObject("component", resolveApiV1ComponentPath("monitor")).init();
                monitoringResult = monitoringService.closeMonitoringForFloatPlan(arguments.floatPlanId, "manual_cancel");
                if (
                    !structKeyExists(monitoringResult, "SUCCESS")
                    OR (
                        monitoringResult.SUCCESS NEQ true
                        AND (
                            !structKeyExists(monitoringResult, "ERROR")
                            OR uCase(trim(toString(monitoringResult.ERROR))) NEQ "MONITORING_NOT_FOUND"
                        )
                    )
                ) {
                    throw(
                        message = "Monitoring close failed.",
                        detail = serializeJSON(monitoringResult)
                    );
                }
            }

            result.SUCCESS = true;
            result.FLOATPLANID = arguments.floatPlanId;
            result.STATUS = "CANCELLED";
            result.MESSAGE = "The active route/float-plan group was cancelled.";
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="addActiveCruiseDelayMinutes" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="minutesValue" type="any" required="false" default="">
        <cfscript>
            var result = {
                SUCCESS = false,
                success = false
            };
            var ds = "fpw";
            var rawMinutes = trim(toString(arguments.minutesValue));
            var minutesToAdd = 0;
            var totalDelayMinutes = 0;
            var streamCtx = {};
            var titleVal = "";
            var bodyVal = "";
            var qTotal = queryNew("");

            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }

            if (!len(rawMinutes) OR !reFind("^[0-9]+$", rawMinutes)) {
                result.ERROR = "INVALID_MINUTES";
                result.MESSAGE = "Delay minutes must be a positive whole number.";
                return result;
            }

            minutesToAdd = val(rawMinutes);
            if (minutesToAdd LTE 0) {
                result.ERROR = "INVALID_MINUTES";
                result.MESSAGE = "Delay minutes must be a positive whole number.";
                return result;
            }

            titleVal = "Delay added: " & minutesToAdd & " minutes";
            bodyVal = "Captain added " & minutesToAdd & " manual delay minutes to the trip timeline.";

            transaction {
                queryExecute(
                    "UPDATE floatplans
                     SET manual_delay_minutes_total = manual_delay_minutes_total + :minutesToAdd
                     WHERE floatplanId = :planId
                       AND userId = :userId",
                    {
                        minutesToAdd = { value = minutesToAdd, cfsqltype = "cf_sql_integer" },
                        planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = ds }
                );

                qTotal = queryExecute(
                    "SELECT manual_delay_minutes_total
                     FROM floatplans
                     WHERE floatplanId = :planId
                       AND userId = :userId
                     LIMIT 1",
                    {
                        planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = ds }
                );

                if (qTotal.recordCount EQ 0) {
                    throw(
                        message = "Float plan not found after delay update.",
                        detail = "No float plan row was returned after incrementing manual delay minutes."
                    );
                }

                totalDelayMinutes = val(qTotal.manual_delay_minutes_total[1]);

                streamCtx = ensureVoyageStreamForFloatPlan(arguments.userId, arguments.floatPlanId, ds);

                queryExecute(
                    "INSERT INTO voyage_posts (
                        stream_id,
                        author_type,
                        author_user_id,
                        title,
                        body,
                        post_type,
                        event_type,
                        created_utc
                     ) VALUES (
                        :streamId,
                        'system',
                        :userId,
                        :title,
                        :body,
                        'system_event',
                        'delay_added',
                        UTC_TIMESTAMP()
                     )",
                    {
                        streamId = { value = streamCtx.streamId, cfsqltype = "cf_sql_integer" },
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                        title = { value = titleVal, cfsqltype = "cf_sql_varchar" },
                        body = { value = bodyVal, cfsqltype = "cf_sql_longvarchar" }
                    },
                    { datasource = ds }
                );

                queryExecute(
                    "UPDATE voyage_streams
                     SET updated_utc = UTC_TIMESTAMP()
                     WHERE id = :streamId",
                    {
                        streamId = { value = streamCtx.streamId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = ds }
                );
            }

            result.SUCCESS = true;
            result.success = true;
            result.FLOATPLANID = arguments.floatPlanId;
            result.ADDED_MINUTES = minutesToAdd;
            result.MANUAL_DELAY_MINUTES_TOTAL = totalDelayMinutes;
            result.EVENT_LOGGED = true;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="clearActiveCruiseDelayMinutes" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = {
                SUCCESS = false,
                success = false
            };
            var ds = "fpw";
            var totalDelayMinutes = 0;
            var qTotal = queryNew("");

            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }

            transaction {
                queryExecute(
                    "UPDATE floatplans
                     SET manual_delay_minutes_total = 0
                     WHERE floatplanId = :planId
                       AND userId = :userId",
                    {
                        planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = ds }
                );

                qTotal = queryExecute(
                    "SELECT manual_delay_minutes_total
                     FROM floatplans
                     WHERE floatplanId = :planId
                       AND userId = :userId
                     LIMIT 1",
                    {
                        planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = ds }
                );

                if (qTotal.recordCount EQ 0) {
                    throw(
                        message = "Float plan not found after delay reset.",
                        detail = "No float plan row was returned after clearing manual delay minutes."
                    );
                }

                totalDelayMinutes = val(qTotal.manual_delay_minutes_total[1]);
            }

            result.SUCCESS = true;
            result.success = true;
            result.FLOATPLANID = arguments.floatPlanId;
            result.MANUAL_DELAY_MINUTES_TOTAL = totalDelayMinutes;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="saveCaptainLogEntry" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="body" type="struct" required="true">
        <cfscript>
            var result = {
                SUCCESS = false,
                success = false
            };
            var ds = "fpw";
            var floatPlanId = val(pickValue(arguments.body, ["floatPlanId", "floatplanId", "floatplan_id"], 0));
            var routeInstanceId = val(pickValue(arguments.body, ["routeInstanceId", "route_instance_id"], 0));
            var routeLegOrder = val(pickValue(arguments.body, ["routeLegOrder", "route_leg_order", "currentLegOrder"], 0));
            var noteBody = trim(toString(pickValue(arguments.body, ["noteBody", "note_body", "body", "note"], "")));
            var noteTag = left(trim(toString(pickValue(arguments.body, ["noteTag", "note_tag", "tag"], ""))), 64);
            var postToFollowStream = booleanValue(pickValue(arguments.body, ["postToFollowStream", "post_to_follow_stream", "postToFollow", "post_to_stream"], false));
            var qPlan = queryNew("");
            var qSaved = queryNew("");
            var insertResult = {};
            var postInsertResult = {};
            var streamCtx = {};
            var captainLogId = 0;
            var voyagePostId = 0;
            var titleVal = "";
            var savedNote = {};

            if (arguments.userId LTE 0) {
                result.ERROR = "NOT_LOGGED_IN";
                result.MESSAGE = "A logged-in captain is required.";
                return result;
            }
            if (floatPlanId LTE 0) {
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }
            if (!len(noteBody)) {
                result.ERROR = "NOTE_REQUIRED";
                result.MESSAGE = "A captain note is required.";
                return result;
            }

            qPlan = queryExecute(
                "SELECT floatplanId, userId, route_instance_id
                 FROM floatplans
                 WHERE floatplanId = :planId
                   AND userId = :userId
                 LIMIT 1",
                {
                    planId = { value = floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = ds }
            );
            if (qPlan.recordCount EQ 0) {
                result.ERROR = "NOT_FOUND";
                result.MESSAGE = "Float plan not found.";
                return result;
            }
            if (routeInstanceId LTE 0 AND !isNull(qPlan.route_instance_id[1])) {
                routeInstanceId = val(qPlan.route_instance_id[1]);
            }

            titleVal = left(noteBody, 80);

            transaction {
                queryExecute(
                    "INSERT INTO floatplan_captain_log_entries (
                        floatplan_id,
                        user_id,
                        route_instance_id,
                        route_leg_order,
                        note_body,
                        note_tag,
                        posted_to_stream,
                        voyage_post_id,
                        created_utc,
                        updated_utc
                     ) VALUES (
                        :floatPlanId,
                        :userId,
                        :routeInstanceId,
                        :routeLegOrder,
                        :noteBody,
                        :noteTag,
                        0,
                        NULL,
                        UTC_TIMESTAMP(),
                        UTC_TIMESTAMP()
                     )",
                    {
                        floatPlanId = { value = floatPlanId, cfsqltype = "cf_sql_integer" },
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                        routeInstanceId = { value = routeInstanceId, cfsqltype = "cf_sql_integer", null = (routeInstanceId LTE 0) },
                        routeLegOrder = { value = routeLegOrder, cfsqltype = "cf_sql_integer", null = (routeLegOrder LTE 0) },
                        noteBody = { value = noteBody, cfsqltype = "cf_sql_longvarchar" },
                        noteTag = { value = noteTag, cfsqltype = "cf_sql_varchar", null = NOT len(noteTag) }
                    },
                    { datasource = ds, result = "insertResult" }
                );

                if (structKeyExists(insertResult, "generatedKey") AND isNumeric(insertResult.generatedKey)) {
                    captainLogId = val(insertResult.generatedKey);
                }

                if (postToFollowStream) {
                    streamCtx = ensureVoyageStreamForFloatPlan(arguments.userId, floatPlanId, ds);
                    queryExecute(
                        "INSERT INTO voyage_posts (
                            stream_id,
                            author_type,
                            author_user_id,
                            title,
                            body,
                            post_type,
                            event_type,
                            created_utc
                         ) VALUES (
                            :streamId,
                            'owner',
                            :userId,
                            :title,
                            :body,
                            'text',
                            'captain_log',
                            UTC_TIMESTAMP()
                         )",
                        {
                            streamId = { value = streamCtx.streamId, cfsqltype = "cf_sql_integer" },
                            userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                            title = { value = titleVal, cfsqltype = "cf_sql_varchar" },
                            body = { value = noteBody, cfsqltype = "cf_sql_longvarchar" }
                        },
                        { datasource = ds, result = "postInsertResult" }
                    );
                    if (structKeyExists(postInsertResult, "generatedKey") AND isNumeric(postInsertResult.generatedKey)) {
                        voyagePostId = val(postInsertResult.generatedKey);
                    }

                    queryExecute(
                        "UPDATE floatplan_captain_log_entries
                         SET posted_to_stream = 1,
                             voyage_post_id = :voyagePostId,
                             updated_utc = UTC_TIMESTAMP()
                         WHERE id = :captainLogId
                           AND user_id = :userId",
                        {
                            voyagePostId = { value = voyagePostId, cfsqltype = "cf_sql_integer", null = (voyagePostId LTE 0) },
                            captainLogId = { value = captainLogId, cfsqltype = "cf_sql_integer" },
                            userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = ds }
                    );

                    queryExecute(
                        "UPDATE voyage_streams
                         SET updated_utc = UTC_TIMESTAMP()
                         WHERE id = :streamId",
                        {
                            streamId = { value = streamCtx.streamId, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = ds }
                    );
                }

                qSaved = queryExecute(
                    "SELECT id,
                            floatplan_id,
                            user_id,
                            route_instance_id,
                            route_leg_order,
                            note_body,
                            note_tag,
                            posted_to_stream,
                            voyage_post_id,
                            created_utc,
                            updated_utc
                     FROM floatplan_captain_log_entries
                     WHERE id = :captainLogId
                       AND user_id = :userId
                     LIMIT 1",
                    {
                        captainLogId = { value = captainLogId, cfsqltype = "cf_sql_integer" },
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = ds }
                );
            }

            if (qSaved.recordCount EQ 1) {
                savedNote = buildCaptainLogEntryPayload(qSaved, 1);
            }

            result.SUCCESS = true;
            result.success = true;
            result.NOTE = savedNote;
            result.note = savedNote;
            result.POSTED_TO_STREAM = postToFollowStream;
            result.VOYAGE_POST_ID = voyagePostId;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="buildCaptainLogEntryPayload" access="private" returntype="struct" output="false">
        <cfargument name="qNote" type="query" required="true">
        <cfargument name="rowIndex" type="numeric" required="true">
        <cfscript>
            var postedVal = (
                listFindNoCase(arguments.qNote.columnList, "posted_to_stream")
                AND arguments.qNote.recordCount GTE arguments.rowIndex
                AND !isNull(arguments.qNote.posted_to_stream[arguments.rowIndex])
                AND val(arguments.qNote.posted_to_stream[arguments.rowIndex]) EQ 1
            );
            var createdVal = (
                listFindNoCase(arguments.qNote.columnList, "created_utc")
                AND arguments.qNote.recordCount GTE arguments.rowIndex
                AND !isNull(arguments.qNote.created_utc[arguments.rowIndex])
                    ? arguments.qNote.created_utc[arguments.rowIndex]
                    : ""
            );

            return {
                id = val(arguments.qNote.id[arguments.rowIndex]),
                floatPlanId = val(arguments.qNote.floatplan_id[arguments.rowIndex]),
                userId = val(arguments.qNote.user_id[arguments.rowIndex]),
                routeInstanceId = (
                    listFindNoCase(arguments.qNote.columnList, "route_instance_id")
                    AND !isNull(arguments.qNote.route_instance_id[arguments.rowIndex])
                        ? val(arguments.qNote.route_instance_id[arguments.rowIndex])
                        : 0
                ),
                routeLegOrder = (
                    listFindNoCase(arguments.qNote.columnList, "route_leg_order")
                    AND !isNull(arguments.qNote.route_leg_order[arguments.rowIndex])
                        ? val(arguments.qNote.route_leg_order[arguments.rowIndex])
                        : 0
                ),
                noteBody = trim(toString(arguments.qNote.note_body[arguments.rowIndex])),
                noteTag = (
                    listFindNoCase(arguments.qNote.columnList, "note_tag")
                    AND !isNull(arguments.qNote.note_tag[arguments.rowIndex])
                        ? trim(toString(arguments.qNote.note_tag[arguments.rowIndex]))
                        : ""
                ),
                postedToStream = postedVal,
                voyagePostId = (
                    listFindNoCase(arguments.qNote.columnList, "voyage_post_id")
                    AND !isNull(arguments.qNote.voyage_post_id[arguments.rowIndex])
                        ? val(arguments.qNote.voyage_post_id[arguments.rowIndex])
                        : 0
                ),
                createdUtc = (isDate(createdVal) ? dateTimeFormat(createdVal, "yyyy-mm-dd'T'HH:nn:ss'Z'") : ""),
                createdLabel = (isDate(createdVal) ? timeFormat(createdVal, "h:nn tt") : "--"),
                badge = (postedVal ? "POSTED" : "PRIVATE")
            };
        </cfscript>
    </cffunction>

    <cffunction name="submitActiveCruiseCheckIn" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="status" type="string" required="true">
        <cfargument name="note" type="string" required="false" default="">
        <cfargument name="checkinContext" type="string" required="false" default="">
        <cfargument name="location" type="any" required="false" default="">
        <cfscript>
            var result = { "success" = false };
            var allowedStatuses = "On Track,Delayed,Changed Plan,Assistance Needed,Secure for the Night";
            var statusVal = trim(arguments.status);
            var noteVal = toString(arguments.note);
            var contextVal = lCase(trim(arguments.checkinContext));
            var streamCtx = {};
            var titleVal = "";
            var ds = "fpw";
            var qPlan = queryNew("");
            var qUpdatedPlan = queryNew("");
            var updateSql = "";
            var updateParams = {};
            var currentContextVal = "";
            var departureTimeZoneVal = "";
            var dailyStartLocalTimeVal = "";
            var overnightPauseMinutesToAdd = 0;
            var updatedCheckInDt = "";
            var isOvernightTransition = false;
            var storedCheckInDt = "";
            var expectedCheckInDt = "";
            var overnightResumeDt = "";
            var isOvernightPauseActive = false;
            var monitoringService = {};
            var monitoringResult = {};
            var monitoringStatusVal = "";
            var planNameVal = "";
            var assistanceAlertService = {};
            var assistanceAlertResult = {};
            var qVoyagePost = queryNew("");
            var voyagePostId = 0;
            var canonicalActivityService = {};
            var canonicalActivityResult = {};
            var canonicalPayload = {};
            var planStatusVal = "";
            var routeInstanceIdVal = 0;
            var departureTimeVal = "";
            var scheduledStartState = {};
            var qRouteProgress = queryNew("");
            var routeProgressStarted = false;
            var isOperationallyUnstarted = false;
            var isPreDepartureUnstarted = false;
            var scheduledMonitoringResult = {};
            var shouldStartOperationallyForCheckin = false;
            var operationalStartResult = {};
            var activeCruiseLocation = {};
            var activeCruiseCapturedAtRaw = "";
            var activeCruiseCapturedAt = {};
            var activeCruiseCapturedAtDriftMinutes = 0;

            if (arguments.floatPlanId LTE 0) {
                result.SUCCESS = false;
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }

            if (compareNoCase(statusVal, "Secure for the Night") EQ 0 AND !len(contextVal)) {
                contextVal = "overnight";
            }

            if (!listFindNoCase(allowedStatuses, statusVal)) {
                result.SUCCESS = false;
                result.ERROR = "INVALID_STATUS";
                result.MESSAGE = "Status must be one of On Track, Delayed, Changed Plan, Assistance Needed, or Secure for the Night.";
                return result;
            }
            if (len(contextVal) AND contextVal NEQ "overnight") {
                result.SUCCESS = false;
                result.ERROR = "INVALID_CHECKIN_CONTEXT";
                result.MESSAGE = "checkinContext must be blank or overnight.";
                return result;
            }

            activeCruiseLocation = validateActiveCruiseCheckinLocation(arguments.location);
            if (
                !structKeyExists(activeCruiseLocation, "SUCCESS")
                OR activeCruiseLocation.SUCCESS NEQ true
            ) {
                return activeCruiseLocation;
            }

            qPlan = queryExecute(
                "SELECT
                    floatPlanName,
                    floatplanId,
                    checkedInAt,
                    `status`,
                    route_instance_id,
                    departureTime,
                    departureTZ,
                    departTimezone,
                    dailyStartLocalTime,
                    (
                        SELECT m.expected_checkin_at
                        FROM floatplan_monitoring m
                        WHERE m.float_plan_id = floatplans.floatplanId
                          AND m.is_monitoring_enabled = 1
                          AND UPPER(TRIM(m.monitor_state)) <> 'CLOSED'
                        ORDER BY m.id DESC
                        LIMIT 1
                    ) AS expected_checkin_at,
                    checkin_context
                 FROM floatplans
                 WHERE floatplanId = :planId
                   AND userId = :userId
                 LIMIT 1",
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = ds }
            );

            if (qPlan.recordCount EQ 0) {
                result.SUCCESS = false;
                result.ERROR = "NOT_FOUND";
                result.MESSAGE = "Float plan not found.";
                return result;
            }

            planStatusVal = (isNull(qPlan.status[1]) ? "" : uCase(trim(toString(qPlan.status[1]))));
            routeInstanceIdVal = (isNull(qPlan.route_instance_id[1]) ? 0 : val(qPlan.route_instance_id[1]));
            if (!isNull(qPlan.departureTime[1]) AND isDate(qPlan.departureTime[1])) {
                departureTimeVal = qPlan.departureTime[1];
            }
            currentContextVal = normalizeCheckInContext(isNull(qPlan.checkin_context[1]) ? "" : qPlan.checkin_context[1]);
            if (!isNull(qPlan.checkedInAt[1]) AND isDate(qPlan.checkedInAt[1])) {
                storedCheckInDt = qPlan.checkedInAt[1];
            }
            departureTimeZoneVal = (isNull(qPlan.departureTZ[1]) ? "" : trim(toString(qPlan.departureTZ[1])));
            if (!len(departureTimeZoneVal)) {
                departureTimeZoneVal = (isNull(qPlan.departTimezone[1]) ? "" : trim(toString(qPlan.departTimezone[1])));
            }
            dailyStartLocalTimeVal = (isNull(qPlan.dailyStartLocalTime[1]) ? "" : trim(toString(qPlan.dailyStartLocalTime[1])));
            if (!isNull(qPlan.expected_checkin_at[1]) AND isDate(qPlan.expected_checkin_at[1])) {
                expectedCheckInDt = qPlan.expected_checkin_at[1];
            }
            planNameVal = trim(toString(isNull(qPlan.floatPlanName[1]) ? "" : qPlan.floatPlanName[1]));
            if (!len(planNameVal)) {
                planNameVal = "Float Plan";
            }
            isOvernightTransition = (contextVal EQ "overnight" AND currentContextVal NEQ "overnight");
            if (currentContextVal EQ "overnight" AND isDate(storedCheckInDt)) {
                if (isDate(expectedCheckInDt)) {
                    overnightResumeDt = expectedCheckInDt;
                    if (dateCompare(now(), overnightResumeDt, "s") LT 0) {
                        isOvernightPauseActive = true;
                    }
                }
            }

            titleVal = "Check-in: " & statusVal;
            monitoringStatusVal = mapMonitoringCheckinStatus(statusVal, contextVal);
            if (!len(monitoringStatusVal)) {
                result.SUCCESS = false;
                result.ERROR = "INVALID_MONITORING_STATUS";
                result.MESSAGE = "Unable to map this check-in to a monitoring status.";
                return result;
            }

            if (
                planStatusVal EQ "ACTIVE"
                AND routeInstanceIdVal GT 0
                AND isDate(departureTimeVal)
            ) {
                qRouteProgress = queryExecute(
                    "SELECT COUNT(*) AS started_count
                     FROM route_instance_leg_progress
                     WHERE route_instance_id = :routeInstanceId
                       AND user_id = :userId
                       AND (
                           leg_started_at IS NOT NULL
                           OR completed_at IS NOT NULL
                           OR UPPER(TRIM(status)) <> 'NOT_STARTED'
                       )",
                    {
                        routeInstanceId = { value = routeInstanceIdVal, cfsqltype = "cf_sql_integer" },
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = ds }
                );
                routeProgressStarted = (
                    qRouteProgress.recordCount GT 0
                    AND val(qRouteProgress.started_count[1]) GT 0
                );
                isOperationallyUnstarted = !routeProgressStarted;

                scheduledStartState = getScheduledStartStateForFloatPlan(arguments.userId, arguments.floatPlanId);
                if (scheduledStartState.SUCCESS) {
                    isPreDepartureUnstarted = (
                        !booleanValue(scheduledStartState.TRIP_STARTED)
                        AND isOperationallyUnstarted
                    );
                }

                monitoringService = createObject("component", resolveApiV1ComponentPath("monitor")).init();
                scheduledMonitoringResult = monitoringService.startScheduledRouteMonitoringForFloatPlan(arguments.floatPlanId);
                if (
                    !structKeyExists(scheduledMonitoringResult, "SUCCESS")
                    OR scheduledMonitoringResult.SUCCESS NEQ true
                ) {
                    result.SUCCESS = false;
                    result.ERROR = "MONITORING_INIT_REQUIRED_DATA_MISSING";
                    result.MESSAGE = "Scheduled monitoring could not be initialized for this active route-backed float plan.";
                    result.MONITORING_RESULT = scheduledMonitoringResult;
                    return result;
                }
            }

            if (isPreDepartureUnstarted) {
                if (monitoringStatusVal EQ "DELAYED") {
                    result.SUCCESS = false;
                    result.ERROR = "PRE_DEPARTURE_DELAY_REQUIRES_NEW_TIME";
                    result.MESSAGE = "Please provide a new expected departure time before marking the trip delayed.";
                    return result;
                }
                if (monitoringStatusVal EQ "CHANGED_PLAN") {
                    result.SUCCESS = false;
                    result.ERROR = "PRE_DEPARTURE_PLAN_CHANGE_REQUIRES_UPDATE";
                    result.MESSAGE = "Please update and resend the plan if the route or schedule changed.";
                    return result;
                }
                if (monitoringStatusVal EQ "SECURE_FOR_NIGHT") {
                    result.SUCCESS = false;
                    result.ERROR = "PRE_DEPARTURE_SECURE_NOT_ALLOWED";
                    result.MESSAGE = "Secure for the Night is available after the cruise has started.";
                    return result;
                }
                if (monitoringStatusVal EQ "ON_TRACK") {
                    shouldStartOperationallyForCheckin = true;
                }
            }
            if (
                isOperationallyUnstarted
                AND monitoringStatusVal EQ "ON_TRACK"
            ) {
                shouldStartOperationallyForCheckin = true;
            }

            if (isOvernightPauseActive) {
                updateSql =
                    "UPDATE floatplans
                     SET checkedInAt = UTC_TIMESTAMP(),
                         checkin_context = :checkinContext,
                         lastUpdateStatus = UTC_TIMESTAMP()
                     WHERE floatplanId = :planId
                       AND userId = :userId";
                updateParams = {
                    checkinContext = { value = contextVal, cfsqltype = "cf_sql_varchar", null = NOT len(contextVal) },
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                };
            } else {
                updateSql =
                    "UPDATE floatplans
                     SET checkedInAt = UTC_TIMESTAMP(),
                         checkin_context = :checkinContext,
                         lastUpdateStatus = UTC_TIMESTAMP()
                     WHERE floatplanId = :planId
                       AND userId = :userId";
                updateParams = {
                    checkinContext = { value = contextVal, cfsqltype = "cf_sql_varchar", null = NOT len(contextVal) },
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                };
            }

            transaction {
                if (shouldStartOperationallyForCheckin) {
                    operationalStartResult = startOperationalTripNow(arguments.userId, arguments.floatPlanId, routeInstanceIdVal);
                    if (
                        !structKeyExists(operationalStartResult, "SUCCESS")
                        OR operationalStartResult.SUCCESS NEQ true
                    ) {
                        throw(
                            message = "Operational trip start failed.",
                            detail = serializeJSON(operationalStartResult)
                        );
                    }
                }

                queryExecute(
                    updateSql,
                    updateParams,
                    { datasource = ds }
                );

                if (isOvernightTransition) {
                    qUpdatedPlan = queryExecute(
                        "SELECT checkedInAt
                         FROM floatplans
                         WHERE floatplanId = :planId
                           AND userId = :userId
                         LIMIT 1",
                        {
                            planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                            userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = ds }
                    );
                    if (qUpdatedPlan.recordCount GT 0 AND !isNull(qUpdatedPlan.checkedInAt[1]) AND isDate(qUpdatedPlan.checkedInAt[1])) {
                        updatedCheckInDt = qUpdatedPlan.checkedInAt[1];
                    }
                }

                streamCtx = ensureVoyageStreamForFloatPlan(arguments.userId, arguments.floatPlanId, ds);

                queryExecute(
                    "INSERT INTO voyage_posts (
                        stream_id,
                        author_type,
                        author_user_id,
                        title,
                        body,
                        post_type,
                        event_type,
                        created_utc
                     ) VALUES (
                        :streamId,
                        'system',
                        :userId,
                        :title,
                        :body,
                        'system_event',
                        'checkin',
                        UTC_TIMESTAMP()
                     )",
                    {
                        streamId = { value = streamCtx.streamId, cfsqltype = "cf_sql_integer" },
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                        title = { value = titleVal, cfsqltype = "cf_sql_varchar" },
                        body = { value = noteVal, cfsqltype = "cf_sql_longvarchar" }
                    },
                    { datasource = ds }
                );
                qVoyagePost = queryExecute(
                    "SELECT LAST_INSERT_ID() AS post_id",
                    {},
                    { datasource = ds }
                );
                if (qVoyagePost.recordCount GT 0) {
                    voyagePostId = val(qVoyagePost.post_id[1]);
                }

                queryExecute(
                    "UPDATE voyage_streams
                     SET updated_utc = UTC_TIMESTAMP()
                     WHERE id = :streamId",
                    {
                        streamId = { value = streamCtx.streamId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = ds }
                );

                monitoringService = createObject("component", resolveApiV1ComponentPath("monitor")).init();
                monitoringResult = monitoringService.recordMonitoringCheckin(arguments.floatPlanId, monitoringStatusVal);
                if (
                    !structKeyExists(monitoringResult, "SUCCESS")
                    OR monitoringResult.SUCCESS NEQ true
                ) {
                    throw(
                        message = "Monitoring check-in failed.",
                        detail = serializeJSON(monitoringResult)
                    );
                }
                if (isOvernightTransition AND isDate(updatedCheckInDt)) {
                    qUpdatedPlan = queryExecute(
                        "SELECT expected_checkin_at, secure_for_night_until
                         FROM floatplan_monitoring
                         WHERE float_plan_id = :planId
                         LIMIT 1",
                        {
                            planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = ds }
                    );
                    if (
                        qUpdatedPlan.recordCount GT 0
                        AND (
                            (!isNull(qUpdatedPlan.secure_for_night_until[1]) AND isDate(qUpdatedPlan.secure_for_night_until[1]))
                            OR (!isNull(qUpdatedPlan.expected_checkin_at[1]) AND isDate(qUpdatedPlan.expected_checkin_at[1]))
                        )
                    ) {
                        overnightResumeDt = (
                            !isNull(qUpdatedPlan.secure_for_night_until[1])
                            AND isDate(qUpdatedPlan.secure_for_night_until[1])
                        )
                            ? qUpdatedPlan.secure_for_night_until[1]
                            : qUpdatedPlan.expected_checkin_at[1];
                        overnightPauseMinutesToAdd = computeOvernightPauseMinutes(updatedCheckInDt, overnightResumeDt);
                        if (overnightPauseMinutesToAdd GT 0) {
                            queryExecute(
                                "UPDATE floatplans
                                 SET overnight_pause_minutes_total = overnight_pause_minutes_total + :pauseMinutes
                                 WHERE floatplanId = :planId
                                   AND userId = :userId",
                                {
                                    pauseMinutes = { value = overnightPauseMinutesToAdd, cfsqltype = "cf_sql_integer" },
                                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                                },
                                { datasource = ds }
                            );
                        }
                    }
                }
            }

            qUpdatedPlan = queryExecute(
                "SELECT checkedInAt
                 FROM floatplans
                 WHERE floatplanId = :planId
                   AND userId = :userId
                 LIMIT 1",
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = ds }
            );
            if (qUpdatedPlan.recordCount GT 0 AND !isNull(qUpdatedPlan.checkedInAt[1]) AND isDate(qUpdatedPlan.checkedInAt[1])) {
                updatedCheckInDt = qUpdatedPlan.checkedInAt[1];
            }

            if (
                isDate(updatedCheckInDt)
                AND listFindNoCase("ON_TRACK,DELAYED,CHANGED_PLAN,NEED_ATTENTION,SECURE_FOR_NIGHT", monitoringStatusVal)
            ) {
                try {
                    canonicalPayload = {
                        "status_label" = statusVal,
                        "monitoring_status" = monitoringStatusVal,
                        "checkin_context" = contextVal,
                        "note_body" = noteVal,
                        "stream_id" = (structKeyExists(streamCtx, "streamId") ? val(streamCtx.streamId) : 0),
                        "source_post_id" = voyagePostId,
                        "is_overnight_transition" = isOvernightTransition,
                        "legacy_history_not_backfilled" = true
                    };
                    if (
                        structKeyExists(activeCruiseLocation, "hasLocation")
                        AND activeCruiseLocation.hasLocation
                        AND structKeyExists(activeCruiseLocation, "location")
                        AND isStruct(activeCruiseLocation.location)
                    ) {
                        canonicalPayload.location = duplicate(activeCruiseLocation.location);
                        activeCruiseCapturedAtRaw = readActiveCruiseLocationString(canonicalPayload.location, "capturedAtUtc");
                        if (len(activeCruiseCapturedAtRaw)) {
                            activeCruiseCapturedAt = parseActiveCruiseUtcDate(activeCruiseCapturedAtRaw);
                            if (
                                structKeyExists(activeCruiseCapturedAt, "SUCCESS")
                                AND activeCruiseCapturedAt.SUCCESS
                                AND isDate(activeCruiseCapturedAt.value)
                            ) {
                                activeCruiseCapturedAtDriftMinutes = dateDiff("n", activeCruiseCapturedAt.value, updatedCheckInDt);
                                if (activeCruiseCapturedAtDriftMinutes GT 1440 OR activeCruiseCapturedAtDriftMinutes LT -5) {
                                    canonicalPayload.location.capturedAtUtc = dateTimeFormat(updatedCheckInDt, "yyyy-mm-dd'T'HH:nn:ss'Z'");
                                }
                            }
                        }
                    }
                    canonicalActivityService = createObject("component", resolveApiV1ComponentPath("TripActivityWriterService")).init(ds);
                    canonicalActivityResult = canonicalActivityService.recordActiveCruiseCheckin(
                        floatPlanId = arguments.floatPlanId,
                        userId = arguments.userId,
                        status = monitoringStatusVal,
                        checkinContext = contextVal,
                        occurredAtUtc = updatedCheckInDt,
                        monitoringId = (
                            structKeyExists(monitoringResult, "MONITORING_ID")
                            ? val(monitoringResult.MONITORING_ID)
                            : 0
                        ),
                        sourcePostId = voyagePostId,
                        payload = canonicalPayload
                    );
                    if (
                        !structKeyExists(canonicalActivityResult, "SUCCESS")
                        OR canonicalActivityResult.SUCCESS NEQ true
                    ) {
                        writeLog(
                            file = "fpw-canonical-activity",
                            type = "warning",
                            text = "Canonical activity write skipped/failed for floatPlanId=" & arguments.floatPlanId & " status=" & monitoringStatusVal & " result=" & left(serializeJSON(canonicalActivityResult), 1000)
                        );
                    }
                } catch (any canonicalActivityErr) {
                    writeLog(
                        file = "fpw-canonical-activity",
                        type = "warning",
                        text = "Canonical activity writer exception for floatPlanId=" & arguments.floatPlanId & " status=" & monitoringStatusVal & " message=" & left(trim(toString(canonicalActivityErr.message)), 500)
                    );
                }
            }

            result.success = true;
            result.SUCCESS = true;
            result.AUTH = true;
            result.MESSAGE = "Check-in recorded.";
            if (monitoringStatusVal EQ "NEED_ATTENTION") {
                qUpdatedPlan = queryExecute(
                    "SELECT checkedInAt
                     FROM floatplans
                     WHERE floatplanId = :planId
                       AND userId = :userId
                     LIMIT 1",
                    {
                        planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = ds }
                );
                if (qUpdatedPlan.recordCount GT 0 AND !isNull(qUpdatedPlan.checkedInAt[1]) AND isDate(qUpdatedPlan.checkedInAt[1])) {
                    updatedCheckInDt = qUpdatedPlan.checkedInAt[1];
                }
                try {
                    assistanceAlertService = createObject("component", resolveApiV1ComponentPath("OverdueAlertService")).init();
                    assistanceAlertResult = assistanceAlertService.sendAssistanceNeededEmail(
                        arguments.floatPlanId,
                        planNameVal,
                        updatedCheckInDt,
                        noteVal
                    );
                    result.ALERT_SENT = (
                        structKeyExists(assistanceAlertResult, "SUCCESS")
                        AND assistanceAlertResult.SUCCESS EQ true
                    );
                    result.ALERT_RECIPIENT_COUNT = (
                        structKeyExists(assistanceAlertResult, "RECIPIENT_COUNT")
                        ? val(assistanceAlertResult.RECIPIENT_COUNT)
                        : 0
                    );
                } catch (any assistanceAlertErr) {
                    result.ALERT_SENT = false;
                    result.ALERT_ERROR = left(trim(toString(assistanceAlertErr.message)), 500);
                }
            }
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="validateActiveCruiseCheckinLocation" access="private" returntype="struct" output="false">
        <cfargument name="location" type="any" required="false" default="">
        <cfscript>
            var rawLocation = {};
            var result = {
                "SUCCESS" = true,
                "success" = true,
                "AUTH" = true,
                "hasLocation" = false,
                "location" = {}
            };
            var capturedAtRaw = "";
            var capturedAt = {};

            if (!isStruct(arguments.location) OR structCount(arguments.location) EQ 0) {
                return result;
            }

            rawLocation = arguments.location;

            if (!hasActiveCruiseNumericField(rawLocation, "latitude") OR val(rawLocation.latitude) LT -90 OR val(rawLocation.latitude) GT 90) {
                return activeCruiseLocationError("Latitude must be between -90 and 90.");
            }
            if (!hasActiveCruiseNumericField(rawLocation, "longitude") OR val(rawLocation.longitude) LT -180 OR val(rawLocation.longitude) GT 180) {
                return activeCruiseLocationError("Longitude must be between -180 and 180.");
            }

            capturedAtRaw = readActiveCruiseLocationString(rawLocation, "capturedAtUtc");
            if (!len(capturedAtRaw)) {
                return activeCruiseLocationError("Location capturedAtUtc is required.");
            }
            capturedAt = parseActiveCruiseUtcDate(capturedAtRaw);
            if (!capturedAt.SUCCESS) {
                return activeCruiseLocationError("Location capturedAtUtc must be parseable.");
            }

            result.hasLocation = true;
            result.location = {
                "source" = "ACTIVE_CRUISE_WEB",
                "latitude" = val(rawLocation.latitude),
                "longitude" = val(rawLocation.longitude),
                "capturedAtUtc" = dateTimeFormat(capturedAt.value, "yyyy-mm-dd'T'HH:nn:ss'Z'")
            };

            if (hasActiveCruiseOptionalValue(rawLocation, "accuracyMeters")) {
                if (!isNumeric(rawLocation.accuracyMeters) OR val(rawLocation.accuracyMeters) LT 0) {
                    return activeCruiseLocationError("GPS accuracy must be numeric and non-negative.");
                }
                result.location.accuracyMeters = val(rawLocation.accuracyMeters);
            }
            if (hasActiveCruiseOptionalValue(rawLocation, "altitudeMeters")) {
                if (!isNumeric(rawLocation.altitudeMeters)) {
                    return activeCruiseLocationError("GPS altitude must be numeric.");
                }
                result.location.altitudeMeters = val(rawLocation.altitudeMeters);
            }
            if (hasActiveCruiseOptionalValue(rawLocation, "speedKnots")) {
                if (!isNumeric(rawLocation.speedKnots) OR val(rawLocation.speedKnots) LT 0) {
                    return activeCruiseLocationError("Speed must be numeric and non-negative.");
                }
                result.location.speedKnots = val(rawLocation.speedKnots);
            }
            if (hasActiveCruiseOptionalValue(rawLocation, "headingDegrees")) {
                if (!isNumeric(rawLocation.headingDegrees) OR val(rawLocation.headingDegrees) LT 0 OR val(rawLocation.headingDegrees) GT 360) {
                    return activeCruiseLocationError("Heading must be between 0 and 360 degrees.");
                }
                result.location.headingDegrees = val(rawLocation.headingDegrees);
            }

            return result;
        </cfscript>
    </cffunction>

    <cffunction name="activeCruiseLocationError" access="private" returntype="struct" output="false">
        <cfargument name="message" type="string" required="true">
        <cfscript>
            return {
                "SUCCESS" = false,
                "success" = false,
                "AUTH" = true,
                "ERROR" = "INVALID_LOCATION",
                "MESSAGE" = arguments.message
            };
        </cfscript>
    </cffunction>

    <cffunction name="hasActiveCruiseNumericField" access="private" returntype="boolean" output="false">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfscript>
            return (
                structKeyExists(arguments.source, arguments.key)
                AND !isNull(arguments.source[arguments.key])
                AND len(trim(toString(arguments.source[arguments.key])))
                AND isNumeric(arguments.source[arguments.key])
            );
        </cfscript>
    </cffunction>

    <cffunction name="hasActiveCruiseOptionalValue" access="private" returntype="boolean" output="false">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfscript>
            if (!structKeyExists(arguments.source, arguments.key) OR isNull(arguments.source[arguments.key]) OR !len(trim(toString(arguments.source[arguments.key])))) {
                return false;
            }
            return true;
        </cfscript>
    </cffunction>

    <cffunction name="readActiveCruiseLocationString" access="private" returntype="string" output="false">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfscript>
            if (!structKeyExists(arguments.source, arguments.key) OR isNull(arguments.source[arguments.key])) {
                return "";
            }
            return trim(toString(arguments.source[arguments.key]));
        </cfscript>
    </cffunction>

    <cffunction name="parseActiveCruiseUtcDate" access="private" returntype="struct" output="false">
        <cfargument name="rawValue" type="string" required="true">
        <cfscript>
            var raw = trim(arguments.rawValue);
            var normalized = "";

            if (!len(raw)) {
                return { "SUCCESS" = false, "success" = false, "value" = "" };
            }

            normalized = replace(raw, "T", " ", "one");
            normalized = reReplace(normalized, "Z$", "", "one");
            normalized = reReplace(normalized, "\.\d+", "", "one");
            normalized = reReplace(normalized, "([+-]\d{2}:\d{2})$", "", "one");

            if (!isDate(normalized)) {
                return { "SUCCESS" = false, "success" = false, "value" = "" };
            }

            return { "SUCCESS" = true, "success" = true, "value" = parseDateTime(normalized) };
        </cfscript>
    </cffunction>

    <cffunction name="computeOvernightPauseMinutes" access="private" returntype="numeric" output="false">
        <cfargument name="checkInDt" type="any" required="false">
        <cfargument name="resumeDt" type="any" required="false">
        <cfscript>
            var pauseMinutes = 0;
            if (!isDate(arguments.checkInDt) OR !isDate(arguments.resumeDt)) {
                return 0;
            }
            pauseMinutes = dateDiff("n", arguments.checkInDt, arguments.resumeDt);
            if (pauseMinutes LT 0) {
                pauseMinutes = 0;
            }
            return pauseMinutes;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeCheckInContext" access="private" returntype="string" output="false">
        <cfargument name="rawValue" type="any" required="false">
        <cfscript>
            var contextVal = lCase(trim(toString(arguments.rawValue)));
            if (contextVal EQ "overnight") {
                return "overnight";
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="mapMonitoringCheckinStatus" access="private" returntype="string" output="false">
        <cfargument name="statusValue" type="string" required="true">
        <cfargument name="checkinContext" type="string" required="false" default="">
        <cfscript>
            var contextVal = normalizeCheckInContext(arguments.checkinContext);
            var normalizedStatus = trim(arguments.statusValue);
            if (contextVal EQ "overnight") {
                return "SECURE_FOR_NIGHT";
            }
            switch (normalizedStatus) {
                case "On Track":
                    return "ON_TRACK";
                case "Delayed":
                    return "DELAYED";
                case "Changed Plan":
                    return "CHANGED_PLAN";
                case "Assistance Needed":
                    return "NEED_ATTENTION";
                case "Secure for the Night":
                    return "SECURE_FOR_NIGHT";
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="updateActiveCruiseDailyStart" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="dailyStartLocalTime" type="string" required="false" default="">
        <cfscript>
            var result = { SUCCESS = false };
            var ds = "fpw";
            var qPlan = queryNew("");
            var overnightTimingService = createObject("component", resolveApiV1ComponentPath("OvernightTimingService")).init();
            var normalizedDailyStart = overnightTimingService.normalizeLocalDayStartTime(arguments.dailyStartLocalTime);
            var monitoringService = {};
            var refreshResult = {};

            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "INVALID_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }

            if (!len(normalizedDailyStart)) {
                result.ERROR = "INVALID_DAILY_START";
                result.MESSAGE = "Daily start time must be provided in HH:MM format.";
                return result;
            }

            qPlan = queryExecute(
                "SELECT floatplanId
                 FROM floatplans
                 WHERE floatplanId = :planId
                   AND userId = :userId
                 LIMIT 1",
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = ds }
            );

            if (qPlan.recordCount EQ 0) {
                result.ERROR = "NOT_FOUND";
                result.MESSAGE = "Float plan not found.";
                return result;
            }

            transaction {
                queryExecute(
                    "UPDATE floatplans
                     SET dailyStartLocalTime = :dailyStartLocalTime,
                         lastUpdate = NOW()
                     WHERE floatplanId = :planId
                       AND userId = :userId",
                    {
                        dailyStartLocalTime = { value = normalizedDailyStart, cfsqltype = "cf_sql_varchar" },
                        planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = ds }
                );

                monitoringService = createObject("component", resolveApiV1ComponentPath("monitor")).init();
                refreshResult = monitoringService.refreshSecureForNightCheckpoint(arguments.floatPlanId);
                if (!structKeyExists(refreshResult, "SUCCESS") OR refreshResult.SUCCESS NEQ true) {
                    throw(
                        message = "Unable to refresh overnight monitoring timing.",
                        detail = serializeJSON(refreshResult)
                    );
                }
            }

            result.SUCCESS = true;
            result.MESSAGE = "Daily start time updated.";
            result.DAILYSTARTLOCALTIME = normalizedDailyStart;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="loadOvernightTimingRule" access="private" returntype="struct" output="false">
        <cfargument name="dailyStartLocalTime" type="string" required="false" default="">
        <cfscript>
            var cacheKey = "fpwOvernightTimingRule:" & trim(arguments.dailyStartLocalTime);
            var overnightTimingService = {};
            if (structKeyExists(request, cacheKey) AND isStruct(request[cacheKey])) {
                return duplicate(request[cacheKey]);
            }
            overnightTimingService = createObject("component", resolveApiV1ComponentPath("OvernightTimingService")).init();
            request[cacheKey] = overnightTimingService.getLocalDayStartRule(arguments.dailyStartLocalTime);
            return duplicate(request[cacheKey]);
        </cfscript>
    </cffunction>

    <cffunction name="ensureVoyageStreamForFloatPlan" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var out = { "streamId" = 0 };
            var ds = trim(arguments.datasource);
            var qStream = queryNew("");
            var slugVal = "floatplan-" & arguments.floatPlanId;
            var shareTokenVal = replace(createUUID(), "-", "", "all") & replace(createUUID(), "-", "", "all");

            qStream = queryExecute(
                "SELECT id
                 FROM voyage_streams
                 WHERE floatplan_id = :planId
                   AND owner_user_id = :userId
                 ORDER BY id DESC
                 LIMIT 1",
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = ds }
            );

            if (qStream.recordCount EQ 0) {
                queryExecute(
                    "INSERT INTO voyage_streams (
                        floatplan_id,
                        owner_user_id,
                        slug,
                        share_token,
                        privacy_mode,
                        allow_interactions,
                        created_utc,
                        updated_utc
                     ) VALUES (
                        :floatPlanId,
                        :ownerUserId,
                        :slug,
                        :shareToken,
                        'public',
                        1,
                        UTC_TIMESTAMP(),
                        UTC_TIMESTAMP()
                     )",
                    {
                        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                        ownerUserId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                        slug = { value = slugVal, cfsqltype = "cf_sql_varchar" },
                        shareToken = { value = left(shareTokenVal, 64), cfsqltype = "cf_sql_varchar" }
                    },
                    { datasource = ds }
                );

                qStream = queryExecute(
                    "SELECT id
                     FROM voyage_streams
                     WHERE floatplan_id = :planId
                       AND owner_user_id = :userId
                     ORDER BY id DESC
                     LIMIT 1",
                    {
                        planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = ds }
                );
            }

            if (qStream.recordCount EQ 0) {
                throw(message = "Unable to create or load voyage stream for this float plan.");
            }

            out.streamId = val(qStream.id[1]);
            return out;
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
                    DATE_FORMAT(departureTime, '%Y-%m-%d %H:%i:%s') AS departureTime,
                    DATE_FORMAT(departureTimeUTC, '%Y-%m-%d %H:%i:%s') AS departureTimeUTC,
                    departTimezone,
                    departureTZ,
                    `returning`,
                    DATE_FORMAT(returnTime, '%Y-%m-%d %H:%i:%s') AS returnTime,
                    DATE_FORMAT(returnTimeUTC, '%Y-%m-%d %H:%i:%s') AS returnTimeUTC,
                    returnTimezone,
                    returnTZ,
                    food,
                    water,
                    notes,
                    route_instance_id,
                    route_day_number,
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
                var departureDisplayTz = trim(toString(qPlan.departureTZ[1]));
                if (!len(departureDisplayTz)) {
                    departureDisplayTz = trim(toString(qPlan.departTimezone[1]));
                    if (ucase(departureDisplayTz) EQ "UTC") {
                        departureDisplayTz = "";
                    }
                }

                var returnDisplayTz = trim(toString(qPlan.returnTZ[1]));
                if (!len(returnDisplayTz)) {
                    returnDisplayTz = trim(toString(qPlan.returnTimezone[1]));
                    if (ucase(returnDisplayTz) EQ "UTC") {
                        returnDisplayTz = "";
                    }
                }

                var departureDisplayTime = isNull(qPlan.departureTime[1]) ? "" : trim(toString(qPlan.departureTime[1]));
                var returnDisplayTime = isNull(qPlan.returnTime[1]) ? "" : trim(toString(qPlan.returnTime[1]));

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
                    DEPARTURE_TIME       = departureDisplayTime,
                    DEPARTURE_TIME_UTC   = isNull(qPlan.departureTimeUTC[1]) ? "" : trim(toString(qPlan.departureTimeUTC[1])),
                    DEPARTURE_TIMEZONE   = departureDisplayTz,
                    RETURNING_TO         = qPlan.returning,
                    RETURN_TIME          = returnDisplayTime,
                    RETURN_TIME_UTC      = isNull(qPlan.returnTimeUTC[1]) ? "" : trim(toString(qPlan.returnTimeUTC[1])),
                    RETURN_TIMEZONE      = returnDisplayTz,
                    FOOD_DAYS_PER_PERSON = qPlan.food,
                    WATER_DAYS_PER_PERSON= qPlan.water,
                    NOTES                = qPlan.notes,
                    ROUTE_INSTANCE_ID    = qPlan.route_instance_id,
                    ROUTE_DAY_NUMBER     = qPlan.route_day_number,
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
            var baseDir = getDirectoryFromPath(getCurrentTemplatePath());
            var apiDir = getDirectoryFromPath(baseDir);
            var rootDir = getDirectoryFromPath(apiDir);
            var outputDir = rootDir & "floatPlans/user_float_plans/";
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

    <cffunction name="resolveApiV1ComponentPath" access="private" returntype="string" output="false">
        <cfargument name="componentName" type="string" required="true">
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

            return (len(prefix) ? prefix & "." : "") & "api.v1." & arguments.componentName;
        </cfscript>
    </cffunction>

    <cffunction name="getMemberAccessGateService" access="private" returntype="any" output="false">
        <cfscript>
            try {
                return createObject("component", resolveApiV1ComponentPath("MemberAccessGateService")).init("fpw");
            } catch (any e1) {
                try {
                    return createObject("component", "fpw.api.v1.MemberAccessGateService").init("fpw");
                } catch (any e2) {
                    return createObject("component", "api.v1.MemberAccessGateService").init("fpw");
                }
            }
        </cfscript>
    </cffunction>

    <cffunction name="closeBasicFloatPlan" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = {
                SUCCESS = false,
                MESSAGE = ""
            };
            var ds = "fpw";
            var basicScope = {};
            var monitoringService = {};
            var monitoringResult = {};

            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "MISSING_PLAN_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }

            basicScope = loadBasicOperationalPlanScope(arguments.userId, arguments.floatPlanId, ds);
            if (!basicScope.EXISTS) {
                result.ERROR = "PLAN_NOT_FOUND";
                result.MESSAGE = "Float plan not found.";
                return result;
            }
            if (!basicScope.IS_BASIC_OPERATIONAL) {
                return getMemberAccessGateService().buildDeniedResponse(
                    errorCode = "BASIC_SAVED_ROUTE_RESTRICTED",
                    message = "Basic close-out is only available for route-less operational Basic float plans.",
                    auth = true,
                    statusCode = 403,
                    includeUpgradeOptions = true
                );
            }
            if (basicScope.STATUS NEQ "ACTIVE") {
                result.ERROR = "INVALID_STATUS";
                result.MESSAGE = "Only active Basic float plans can be closed.";
                return result;
            }

            try {
                transaction {
                    queryExecute(
                        "UPDATE floatplans
                            SET `status` = 'CLOSED',
                                checkedInAt = COALESCE(checkedInAt, UTC_TIMESTAMP()),
                                checkin_context = NULL,
                                closedAt = UTC_TIMESTAMP(),
                                lastUpdateStatus = UTC_TIMESTAMP()
                          WHERE floatplanId = :planId
                            AND userId = :userId
                            AND route_instance_id IS NULL
                            AND route_origin = 'basic_float_plan'
                            AND is_reusable = 0
                            AND is_visible_in_route_library = 0
                            AND UPPER(TRIM(`status`)) = 'ACTIVE'",
                        {
                            planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                            userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                        },
                        { datasource = ds }
                    );

                    monitoringService = createObject("component", resolveApiV1ComponentPath("monitor")).init();
                    monitoringResult = monitoringService.closeMonitoringForFloatPlan(arguments.floatPlanId, "basic_close");
                    if (
                        !structKeyExists(monitoringResult, "SUCCESS")
                        OR monitoringResult.SUCCESS NEQ true
                    ) {
                        throw(message = "Basic monitoring close failed.", detail = serializeJSON(monitoringResult));
                    }
                }
            } catch (any closeErr) {
                result.ERROR = "BASIC_MONITORING_CLOSE_FAILED";
                result.MESSAGE = "Basic monitoring close failed.";
                result.MONITORING_RESULT = monitoringResult;
                result.DETAIL = closeErr.message;
                return result;
            }

            result.SUCCESS = true;
            result.FLOATPLANID = arguments.floatPlanId;
            result.STATUS = "CLOSED";
            result.MESSAGE = "Basic float plan closed. Basic monitoring has ended.";
            result.MONITORING_RESULT = monitoringResult;
            result.BASIC_OPERATIONAL_ONLY = true;
            result.CURRENT = getBasicOperationalCurrentPlan(arguments.userId, ds);
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="sendBasicFloatPlanToContacts" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = {
                SUCCESS = false,
                MESSAGE = ""
            };
            var ds = "fpw";
            var basicScope = {};
            var memberGateResult = {};
            var storedPlanTimes = {};
            var monitoringService = {};
            var monitoringResult = {};
            var singletonState = {};
            var basicDetails = {};
            var detailsValidation = {};
            var authority = {};

            if (arguments.floatPlanId LTE 0) {
                result.ERROR = "MISSING_PLAN_ID";
                result.MESSAGE = "Float plan id is required.";
                return result;
            }

            basicScope = loadBasicOperationalPlanScope(arguments.userId, arguments.floatPlanId, ds);
            if (!basicScope.EXISTS) {
                result.ERROR = "PLAN_NOT_FOUND";
                result.MESSAGE = "Float plan not found.";
                return result;
            }
            if (!basicScope.IS_BASIC_OPERATIONAL) {
                return getMemberAccessGateService().buildDeniedResponse(
                    errorCode = "BASIC_SAVED_ROUTE_RESTRICTED",
                    message = "Basic send is only available for route-less operational Basic float plans.",
                    auth = true,
                    statusCode = 403,
                    includeUpgradeOptions = true
                );
            }
            if (basicScope.STATUS NEQ "DRAFT") {
                result.ERROR = "INVALID_STATUS";
                result.MESSAGE = "Only draft Basic float plans can be sent.";
                return result;
            }

            singletonState = getBasicOperationalSingletonState(arguments.userId, ds);
            if (singletonState.HAS_ACTIVE AND singletonState.ACTIVE_FLOATPLANID NEQ arguments.floatPlanId) {
                result.ERROR = "BASIC_ACTIVE_PLAN_EXISTS";
                result.MESSAGE = "You already have an active Basic Float Plan. Close it before creating a new one.";
                result.EXISTING_FLOATPLANID = singletonState.ACTIVE_FLOATPLANID;
                return result;
            }
            if (singletonState.HAS_DRAFT AND singletonState.DRAFT_FLOATPLANID NEQ arguments.floatPlanId) {
                result.ERROR = "BASIC_DRAFT_EXISTS";
                result.MESSAGE = "You already have a Basic Float Plan draft. Resume that draft instead of creating a new one.";
                result.EXISTING_FLOATPLANID = singletonState.DRAFT_FLOATPLANID;
                return result;
            }

            var plan = loadFloatPlan(arguments.userId, arguments.floatPlanId);
            basicDetails = loadBasicDetails(arguments.floatPlanId, ds);
            if (structIsEmpty(basicDetails)) {
                result.ERROR = "BASIC_DETAILS_REQUIRED";
                result.MESSAGE = "Basic float plan details are required before sending.";
                return result;
            }

            detailsValidation = validateBasicDetailsPayload(basicDetails);
            if (!detailsValidation.SUCCESS) {
                return detailsValidation;
            }

            authority = resolveBasicRescueAuthority(basicDetails.AUTHORITY_ID, ds);
            if (!authority.SUCCESS) {
                return authority;
            }
            basicDetails.AUTHORITY_ID = authority.AUTHORITY_ID;
            upsertBasicDetails(arguments.floatPlanId, basicDetails, authority, ds);

            queryExecute("
                UPDATE floatplans
                   SET floatPlanEmail = :captainEmail,
                       rescueAuthority = :rescueAuthority,
                       rescueAuthorityPhone = :rescuePhone,
                       rescueCenterId = :rescueCenterId,
                       departing = :launchLocation,
                       `returning` = :launchLocation,
                       lastUpdate = NOW()
                 WHERE floatplanId = :planId
                   AND userId = :userId
                   AND route_instance_id IS NULL
            ", {
                planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                captainEmail = { value = basicDetails.CAPTAIN_EMAIL, cfsqltype = "cf_sql_varchar" },
                rescueAuthority = { value = authority.AUTHORITY_NAME, cfsqltype = "cf_sql_varchar" },
                rescuePhone = { value = authority.AUTHORITY_PHONE, cfsqltype = "cf_sql_varchar" },
                rescueCenterId = { value = authority.AUTHORITY_ID, cfsqltype = "cf_sql_integer" },
                launchLocation = { value = basicDetails.LAUNCH_LOCATION, cfsqltype = "cf_sql_varchar" }
            }, { datasource = ds });

            plan = loadFloatPlan(arguments.userId, arguments.floatPlanId);

            if (NOT structKeyExists(plan, "RETURN_TIME_UTC") OR NOT isDate(plan.RETURN_TIME_UTC)) {
                result.ERROR = "RETURN_TIME_REQUIRED";
                result.MESSAGE = "Return time is required before sending a float plan.";
                return result;
            }

            var returnComparison = getReturnTimeComparisonValues(plan.RETURN_TIME_UTC, "UTC");
            var nowLocal = returnComparison.nowValue;
            var returnLocal = returnComparison.returnValue;

            if (dateCompare(nowLocal, returnLocal) GTE 0) {
                result.ERROR = "RETURN_TIME_PAST";
                result.MESSAGE = "Return time must be in the future before sending a float plan.";
                return result;
            }

            memberGateResult = validateBasicSavedWaypointLimit(
                waypointCount = countStoredFloatPlanWaypoints(arguments.floatPlanId)
            );
            if (!memberGateResult.allowed) {
                return memberGateResult.response;
            }

            storedPlanTimes = loadStoredFloatPlanTimes(arguments.userId, arguments.floatPlanId);
            memberGateResult = getMemberAccessGateService().validateTripDurationLimit(
                userId = arguments.userId,
                departureAt = (structKeyExists(storedPlanTimes, "departureTimeUTC") ? storedPlanTimes.departureTimeUTC : ""),
                returnAt = (structKeyExists(storedPlanTimes, "returnTimeUTC") ? storedPlanTimes.returnTimeUTC : "")
            );
            if (!memberGateResult.allowed) {
                return memberGateResult.response;
            }

            memberGateResult = getMemberAccessGateService().validateMonitoringMode(
                userId = arguments.userId,
                monitoringMode = "basic"
            );
            if (!memberGateResult.allowed) {
                return memberGateResult.response;
            }

            var contacts = loadBasicPlanContactEmails(arguments.floatPlanId, ds);
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

            var rescueAuthority = authority.AUTHORITY_NAME;
            var rescuePhone = authority.AUTHORITY_PHONE;
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
            transaction {
                queryExecute("
                    UPDATE floatplans
                    SET
                        `status` = 'ACTIVE',
                        activatedAt = COALESCE(activatedAt, UTC_TIMESTAMP()),
                        initialSentAt = COALESCE(initialSentAt, UTC_TIMESTAMP()),
                        lastUpdateStatus = UTC_TIMESTAMP()
                    WHERE floatplanId = :planId
                      AND userId = :userId
                      AND route_instance_id IS NULL
                      AND UPPER(TRIM(`status`)) = 'DRAFT'
                ", {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                }, { datasource = ds });

                markBasicOperationalFloatPlanScope(arguments.floatPlanId, ds);
            }

            monitoringService = createObject("component", resolveApiV1ComponentPath("monitor")).init();
            monitoringResult = monitoringService.startMonitoringForFloatPlan(arguments.floatPlanId, "basic");
            if (
                !structKeyExists(monitoringResult, "SUCCESS")
                OR monitoringResult.SUCCESS NEQ true
            ) {
                result.ERROR = "BASIC_MONITORING_INITIALIZATION_FAILED";
                result.MESSAGE = "Basic monitoring initialization failed.";
                result.MONITORING_RESULT = monitoringResult;
                return result;
            }

            result.SUCCESS = true;
            result.SENT_COUNT = sentCount;
            result.SKIPPED_COUNT = skippedCount;
            result.MESSAGE = "Basic float plan sent to " & sentCount & " contact" & (sentCount EQ 1 ? "" : "s") & ".";
            result.MONITORING_RESULT = monitoringResult;
            result.MONITORING_MODE = "basic";
            result.BASIC_OPERATIONAL_ONLY = true;
            return result;
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
            var qActivationLeg = queryNew("");
            var activationLegOrder = 0;
            var monitoringService = {};
            var monitoringResult = {};
            var startGateState = {};
            var shouldStartOperationally = false;
            var operationalStartResult = {};
            var currentGroup = {};
            var memberGateResult = {};
            var storedPlanTimes = {};
            var routeActivationResult = {};
            var monitoringInitError = {};

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
            if (statusVal NEQ "DRAFT") {
                result.ERROR = "INVALID_STATUS";
                result.MESSAGE = "Only the current draft route/float-plan group can be activated.";
                return result;
            }

            var routeInstanceId = val(pickValue(plan, ["ROUTE_INSTANCE_ID", "route_instance_id"], 0));
            if (routeInstanceId LTE 0 OR !userOwnsRouteInstance(arguments.userId, routeInstanceId)) {
                result.ERROR = "ROUTE_REQUIRED_FOR_ACTIVATION";
                result.MESSAGE = "A valid route is required before activating this float plan.";
                return result;
            }

            currentGroup = resolveCurrentRouteFloatPlanGroup(arguments.userId, routeInstanceId);
            if (
                structKeyExists(currentGroup, "ERROR")
                AND listFindNoCase("MULTIPLE_CURRENT_DRAFT_GROUPS,MULTIPLE_ACTIVE_GROUPS,CURRENT_GROUP_CONFLICT", trim(toString(currentGroup.ERROR))) GT 0
            ) {
                return currentGroup;
            }

            if (!currentGroup.SUCCESS OR !currentGroup.HAS_CURRENT_GROUP) {
                result.ERROR = "CURRENT_GROUP_REQUIRED";
                result.MESSAGE = "Activate Route must open the current draft route/float-plan group before sending.";
                return result;
            }

            if (currentGroup.FLOATPLANID NEQ arguments.floatPlanId) {
                if (currentGroup.IS_ACTIVE) {
                    result.ERROR = "ACTIVE_PLAN_EXISTS";
                    result.MESSAGE = "Another active route/float-plan group is already open. End it before activating this route.";
                } else {
                    result.ERROR = "ANOTHER_CURRENT_GROUP_EXISTS";
                    result.MESSAGE = "Another draft route/float-plan group already exists. Delete or finish it before activating a different route.";
                }
                result.EXISTING_FLOATPLANID = currentGroup.FLOATPLANID;
                result.EXISTING_ROUTE_INSTANCE_ID = currentGroup.ROUTE_INSTANCE_ID;
                result.EXISTING_ROUTE_CODE = currentGroup.ROUTE_CODE;
                result.EXISTING_STATUS = currentGroup.STATUS;
                return result;
            }

            storedPlanTimes = loadStoredFloatPlanTimes(arguments.userId, arguments.floatPlanId);
            if (NOT structKeyExists(storedPlanTimes, "returnTimeUTC") OR NOT isDate(storedPlanTimes.returnTimeUTC)) {
                result.ERROR = "RETURN_TIME_REQUIRED";
                result.MESSAGE = "Return time is required before sending a float plan.";
                return result;
            }

            var returnComparison = getReturnTimeComparisonValues(storedPlanTimes.returnTimeUTC, "UTC");
            var nowLocal = returnComparison.nowValue;
            var returnLocal = returnComparison.returnValue;

            if (dateCompare(nowLocal, returnLocal) GTE 0) {
                result.ERROR = "RETURN_TIME_PAST";
                result.MESSAGE = "Return time must be in the future before sending a float plan.";
                return result;
            }

            memberGateResult = getMemberAccessGateService().validateWaypointLimit(
                userId = arguments.userId,
                waypointCount = countStoredFloatPlanWaypoints(arguments.floatPlanId)
            );
            if (!memberGateResult.allowed) {
                return memberGateResult.response;
            }

            memberGateResult = getMemberAccessGateService().validateTripDurationLimit(
                userId = arguments.userId,
                departureAt = (structKeyExists(storedPlanTimes, "departureTimeUTC") ? storedPlanTimes.departureTimeUTC : ""),
                returnAt = (structKeyExists(storedPlanTimes, "returnTimeUTC") ? storedPlanTimes.returnTimeUTC : "")
            );
            if (!memberGateResult.allowed) {
                return memberGateResult.response;
            }

            memberGateResult = getMemberAccessGateService().requirePremium(
                userId = arguments.userId,
                errorCode = "BASIC_ADVANCED_MONITORING_RESTRICTED",
                message = "Upgrade to Premium to activate route-backed monitoring for this float plan."
            );
            if (!memberGateResult.allowed) {
                return memberGateResult.response;
            }

            var contacts = loadPlanContactEmails(arguments.userId, arguments.floatPlanId);
            if (!arrayLen(contacts)) {
                result.ERROR = "NO_CONTACTS";
                result.MESSAGE = "No contacts are selected for this float plan.";
                return result;
            }

            routeActivationResult = ensureCleanRouteInstanceForActivation(
                userId = arguments.userId,
                floatPlanId = arguments.floatPlanId,
                routeInstanceId = routeInstanceId
            );
            if (!routeActivationResult.SUCCESS) {
                result.ERROR = structKeyExists(routeActivationResult, "ERROR") ? routeActivationResult.ERROR : "ROUTE_REACTIVATION_PRECHECK_FAILED";
                result.MESSAGE = structKeyExists(routeActivationResult, "MESSAGE") ? routeActivationResult.MESSAGE : "Route activation preflight failed.";
                result.ROUTE_ACTIVATION_RESULT = routeActivationResult;
                return result;
            }
            routeInstanceId = routeActivationResult.ROUTE_INSTANCE_ID;

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
            transaction {
                queryExecute("
                    UPDATE floatplans
                    SET
                        `status` = 'ACTIVE',
                        activatedAt = COALESCE(activatedAt, UTC_TIMESTAMP()),
                        initialSentAt = COALESCE(initialSentAt, UTC_TIMESTAMP()),
                        lastUpdateStatus = UTC_TIMESTAMP()
                    WHERE floatplanId = :planId
                      AND userId = :userId
                      AND UPPER(TRIM(`status`)) = 'DRAFT'
                ", {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                }, { datasource = "fpw" });

            }

            monitoringService = createObject("component", resolveApiV1ComponentPath("monitor")).init();
            try {
                monitoringResult = monitoringService.startScheduledRouteMonitoringForFloatPlan(arguments.floatPlanId);
            } catch (any monitoringInitErr) {
                monitoringInitError = monitoringInitErr;
                monitoringResult = {
                    SUCCESS = false,
                    ERROR = "SCHEDULED_MONITORING_EXCEPTION",
                    MESSAGE = monitoringInitErr.message
                };
            }
            if (
                !structKeyExists(monitoringResult, "SUCCESS")
                OR monitoringResult.SUCCESS NEQ true
            ) {
                revertRouteActivationWithoutMonitoring(arguments.userId, arguments.floatPlanId);
                result.ERROR = "SCHEDULED_MONITORING_INITIALIZATION_FAILED";
                result.MESSAGE = "Scheduled monitoring initialization failed.";
                result.MONITORING_RESULT = monitoringResult;
                if (structKeyExists(monitoringInitError, "detail") AND len(trim(toString(monitoringInitError.detail)))) {
                    result.MONITORING_DETAIL = monitoringInitError.detail;
                }
                return result;
            }

            result.SUCCESS = true;
            result.SENT_COUNT = sentCount;
            result.SKIPPED_COUNT = skippedCount;
            result.MESSAGE = "Float plan sent to " & sentCount & " contact" & (sentCount EQ 1 ? "" : "s") & ".";
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="ensureOperationalStartForScheduledPlan" access="public" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = {
                SUCCESS = false,
                MESSAGE = "Unable to evaluate the scheduled trip start gate.",
                TRIP_STARTED = true,
                PENDING_START = false,
                MONITORING_STARTED = false
            };
            var startState = {};
            var monitoringService = {};
            var monitoringResult = {};

            startState = getScheduledStartStateForFloatPlan(arguments.userId, arguments.floatPlanId);
            if (!startState.SUCCESS) {
                return startState;
            }

            result = duplicate(startState);
            result.SUCCESS = true;
            if (!result.TRIP_STARTED) {
                result.PENDING_START = true;
                result.MESSAGE = "Scheduled departure is still pending.";
                return result;
            }

            if (listFindNoCase("DRAFT,CLOSED", result.STATUS) GT 0) {
                result.MESSAGE = "Float plan is not in an operational monitoring state.";
                return result;
            }

            monitoringService = createObject("component", resolveApiV1ComponentPath("monitor")).init();
            monitoringResult = monitoringService.startScheduledRouteMonitoringForFloatPlan(arguments.floatPlanId);
            if (
                !structKeyExists(monitoringResult, "SUCCESS")
                OR monitoringResult.SUCCESS NEQ true
            ) {
                return monitoringResult;
            }
            result.MONITORING_STARTED = (
                structKeyExists(monitoringResult, "SCHEDULED_MONITORING_STARTED")
                AND booleanValue(monitoringResult.SCHEDULED_MONITORING_STARTED)
            );
            result.MESSAGE = "Scheduled departure is due; awaiting captain check-in.";
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
                ROUTE_INSTANCE_ID    = 0,
                ROUTE_DAY_NUMBER     = 0,
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

    <cffunction name="normalizeTimestampInput" access="private" returntype="string" output="false">
        <cfargument name="value" required="true">
        <cfscript>
            var normalized = trim(toString(arguments.value));
            if (isDate(arguments.value)) {
                return dateFormat(arguments.value, "yyyy-mm-dd") & " " & timeFormat(arguments.value, "HH:mm:ss");
            }
            if (NOT len(normalized)) {
                return "";
            }
            normalized = replace(normalized, "T", " ", "all");
            normalized = reReplace(normalized, "Z$", "", "one");
            normalized = reReplace(normalized, "([+-]\d{2}:?\d{2})$", "", "one");
            normalized = reReplace(normalized, "\.\d+$", "", "one");
            if (reFind("^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$", normalized)) {
                normalized &= ":00";
            }
            return normalized;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeLocalWallClockInput" access="private" returntype="string" output="false">
        <cfargument name="value" required="true">
        <cfscript>
            var raw = "";
            var datePart = "";
            var timePart = "";
            var meridiem = "";
            var monthVal = 0;
            var dayVal = 0;
            var yearVal = 0;
            var hourVal = 0;
            var minuteVal = 0;
            var secondVal = 0;

            if (!isSimpleValue(arguments.value)) {
                return "";
            }

            raw = trim(toString(arguments.value));
            if (!len(raw)) {
                return "";
            }

            raw = replace(raw, "T", " ", "all");
            raw = reReplace(raw, "Z$", "", "one");
            raw = reReplace(raw, "([+-]\d{2}:?\d{2})$", "", "one");
            raw = reReplace(raw, "\.\d+$", "", "one");
            raw = reReplace(raw, ",", " ", "all");
            raw = trim(reReplace(raw, "\s+", " ", "all"));

            if (reFind("^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$", raw)) {
                raw &= ":00";
            }
            if (reFind("^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$", raw)) {
                return raw;
            }

            if (listLen(raw, " ") LT 2 OR listLen(listFirst(raw, " "), "/") NEQ 3 OR listLen(listGetAt(raw, 2, " "), ":") LT 2) {
                return "";
            }

            datePart = listFirst(raw, " ");
            timePart = listGetAt(raw, 2, " ");
            meridiem = (listLen(raw, " ") GTE 3 ? uCase(listGetAt(raw, 3, " ")) : "");

            monthVal = val(listGetAt(datePart, 1, "/"));
            dayVal = val(listGetAt(datePart, 2, "/"));
            yearVal = val(listGetAt(datePart, 3, "/"));
            hourVal = val(listGetAt(timePart, 1, ":"));
            minuteVal = val(listGetAt(timePart, 2, ":"));
            secondVal = (listLen(timePart, ":") GTE 3 ? val(listGetAt(timePart, 3, ":")) : 0);

            if (monthVal LT 1 OR monthVal GT 12 OR dayVal LT 1 OR dayVal GT 31 OR yearVal LT 1000 OR minuteVal LT 0 OR minuteVal GT 59 OR secondVal LT 0 OR secondVal GT 59) {
                return "";
            }

            if (meridiem EQ "AM" OR meridiem EQ "PM") {
                if (hourVal LT 1 OR hourVal GT 12) {
                    return "";
                }
                if (meridiem EQ "AM" AND hourVal EQ 12) {
                    hourVal = 0;
                } else if (meridiem EQ "PM" AND hourVal LT 12) {
                    hourVal += 12;
                }
            } else if (hourVal LT 0 OR hourVal GT 23) {
                return "";
            }

            return yearVal & "-" & right("0" & monthVal, 2) & "-" & right("0" & dayVal, 2) & " " & right("0" & hourVal, 2) & ":" & right("0" & minuteVal, 2) & ":" & right("0" & secondVal, 2);
        </cfscript>
    </cffunction>

    <cffunction name="parseUtcTimestampInput" access="private" returntype="any" output="false">
        <cfargument name="value" required="true">
        <cfscript>
            var normalizedInput = normalizeTimestampInput(arguments.value);
            if (!len(normalizedInput) OR !isDate(normalizedInput)) {
                return "";
            }
            return parseDateTime(normalizedInput);
        </cfscript>
    </cffunction>

    <cffunction name="resolvePayloadUtcTimestamp" access="private" returntype="any" output="false">
        <cfargument name="localDateTime" type="string" required="true">
        <cfargument name="sourceTimeZone" type="string" required="true">
        <cfargument name="clientUtcDateTime" type="string" required="false" default="">
        <cfscript>
            var sourceZone = uCase(trim(arguments.sourceTimeZone));
            var clientUtc = parseUtcTimestampInput(arguments.clientUtcDateTime);
            var normalizedLocal = normalizeTimestampInput(arguments.localDateTime);

            if (isDate(clientUtc)) {
                return clientUtc;
            }
            if (listFindNoCase("UTC,Etc/UTC,GMT", sourceZone) AND len(normalizedLocal) AND isDate(normalizedLocal)) {
                return parseDateTime(normalizedLocal);
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="toUtcTimestamp" access="private" returntype="any" output="false">
        <cfargument name="localDateTime" type="string" required="true">
        <cfargument name="sourceTimeZone" type="string" required="true">
        <cfargument name="datasource" type="string" required="true">
        <cfscript>
            var normalizedInput = normalizeTimestampInput(arguments.localDateTime);
            if (NOT len(normalizedInput) OR NOT len(trim(arguments.sourceTimeZone))) {
                return "";
            }

            if (!isDate(normalizedInput)) {
                return "";
            }
            return parseDateTime(normalizedInput);
        </cfscript>
    </cffunction>

    <cffunction name="fromUtcTimestamp" access="private" returntype="any" output="false">
        <cfargument name="utcDateTime" required="true">
        <cfargument name="targetTimeZone" type="string" required="true">
        <cfargument name="datasource" type="string" required="true">
        <cfscript>
            if (!isDate(arguments.utcDateTime) OR NOT len(trim(arguments.targetTimeZone))) {
                return arguments.utcDateTime;
            }
            try {
                return parseDateTime(dateTimeFormat(arguments.utcDateTime, "yyyy-mm-dd HH:nn:ss", trim(arguments.targetTimeZone)));
            } catch (any convertError) {
                return arguments.utcDateTime;
            }
        </cfscript>
    </cffunction>

    <cffunction name="currentTimestampForTimeZone" access="private" returntype="any" output="false">
        <cfargument name="timeZoneId" type="string" required="true">
        <cfscript>
            var utcNow = dateConvert("local2utc", now());
            try {
                if (listFindNoCase("UTC,Etc/UTC,GMT", trim(arguments.timeZoneId))) {
                    return utcNow;
                }
                return parseDateTime(dateTimeFormat(utcNow, "yyyy-mm-dd HH:nn:ss", trim(arguments.timeZoneId)));
            } catch (any nowError) {
                return "";
            }
        </cfscript>
    </cffunction>

    <cffunction name="getReturnTimeComparisonValues" access="private" returntype="struct" output="false">
        <cfargument name="returnTime" required="true">
        <cfargument name="returnTimeZone" type="string" required="false" default="">
        <cfscript>
            var comparison = {
                nowValue = now(),
                returnValue = arguments.returnTime
            };
            var nowUtc = "";

            nowUtc = currentTimestampForTimeZone("UTC");
            if (isDate(arguments.returnTime) AND isDate(nowUtc)) {
                comparison.nowValue = nowUtc;
                comparison.returnValue = arguments.returnTime;
            }
            return comparison;
        </cfscript>
    </cffunction>

    <cffunction name="startOperationalTripNow" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfscript>
            var result = {
                SUCCESS = false,
                MONITORING_STARTED = false
            };
            var qActivationLeg = queryNew("");
            var qCompletedLeg = queryNew("");
            var qMonitoring = queryNew("");
            var qStartClock = queryNew("");
            var activationLegOrder = 0;
            var hasCompletedLeg = false;
            var monitoringService = {};
            var monitoringResult = {};
            var operationalStartAtUtc = "";

            qStartClock = queryExecute(
                "SELECT UTC_TIMESTAMP() AS operational_start_at_utc",
                {},
                { datasource = "fpw" }
            );
            if (
                qStartClock.recordCount EQ 0
                OR isNull(qStartClock.operational_start_at_utc[1])
                OR !isDate(qStartClock.operational_start_at_utc[1])
            ) {
                result.ERROR = "OPERATIONAL_START_TIMESTAMP_UNAVAILABLE";
                result.MESSAGE = "Operational trip start timestamp could not be established.";
                return result;
            }
            operationalStartAtUtc = qStartClock.operational_start_at_utc[1];

            queryExecute(
                "UPDATE floatplans
                 SET lastUpdateStatus = CASE
                         WHEN activatedAt IS NULL THEN :operationalStartAtUtc
                         ELSE lastUpdateStatus
                     END,
                     activatedAt = COALESCE(activatedAt, :operationalStartAtUtc)
                 WHERE floatplanId = :planId
                   AND userId = :userId
                   AND UPPER(TRIM(`status`)) NOT IN ('DRAFT','CLOSED')",
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                    operationalStartAtUtc = { value = operationalStartAtUtc, cfsqltype = "cf_sql_timestamp" }
                },
                { datasource = "fpw" }
            );

            if (arguments.routeInstanceId GT 0) {
                qActivationLeg = queryExecute(
                    "SELECT ril.leg_order
                     FROM route_instance_legs ril
                     LEFT JOIN route_instance_leg_progress rilp
                        ON rilp.route_instance_id = ril.route_instance_id
                       AND rilp.leg_order = ril.leg_order
                       AND rilp.user_id = :userId
                     WHERE ril.route_instance_id = :routeInstanceId
                       AND COALESCE(UPPER(TRIM(rilp.status)), 'NOT_STARTED') <> 'COMPLETED'
                     ORDER BY ril.leg_order ASC, ril.id ASC
                     LIMIT 1",
                    {
                        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                        routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = "fpw" }
                );
                if (qActivationLeg.recordCount EQ 1) {
                    activationLegOrder = val(qActivationLeg.leg_order[1]);
                    if (activationLegOrder GT 0) {
                        qCompletedLeg = queryExecute(
                            "SELECT 1
                             FROM route_instance_leg_progress
                             WHERE route_instance_id = :routeInstanceId
                               AND user_id = :userId
                               AND UPPER(TRIM(status)) = 'COMPLETED'
                             LIMIT 1",
                            {
                                routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" },
                                userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                            },
                            { datasource = "fpw" }
                        );
                        hasCompletedLeg = (qCompletedLeg.recordCount GT 0);
                        if (!hasCompletedLeg) {
                            queryExecute(
                                "UPDATE route_instance_leg_progress
                                 SET status = CASE
                                         WHEN UPPER(TRIM(status)) = 'NOT_STARTED' THEN 'STARTED'
                                         ELSE status
                                     END,
                                     leg_started_at = COALESCE(leg_started_at, :operationalStartAtUtc)
                                 WHERE route_instance_id = :routeInstanceId
                                   AND user_id = :userId
                                   AND leg_order = :legOrder
                                   AND UPPER(TRIM(status)) = 'NOT_STARTED'",
                                {
                                    routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" },
                                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                                    legOrder = { value = activationLegOrder, cfsqltype = "cf_sql_integer" },
                                    operationalStartAtUtc = { value = operationalStartAtUtc, cfsqltype = "cf_sql_timestamp" }
                                },
                                { datasource = "fpw" }
                            );

                            queryExecute(
                                "UPDATE route_instances
                                 SET status = CASE
                                         WHEN UPPER(TRIM(status)) = 'PLANNED' THEN 'ACTIVE'
                                         ELSE status
                                     END,
                                     started_at = COALESCE(started_at, :operationalStartAtUtc)
                                 WHERE id = :routeInstanceId
                                   AND user_id = :userId
                                   AND UPPER(TRIM(COALESCE(status, ''))) IN ('PLANNED','ACTIVE')",
                                {
                                    routeInstanceId = { value = arguments.routeInstanceId, cfsqltype = "cf_sql_integer" },
                                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
                                    operationalStartAtUtc = { value = operationalStartAtUtc, cfsqltype = "cf_sql_timestamp" }
                                },
                                { datasource = "fpw" }
                            );
                        }
                    }
                }
            }

            qMonitoring = queryExecute(
                "SELECT id
                 FROM floatplan_monitoring
                 WHERE float_plan_id = :planId
                   AND is_monitoring_enabled = 1
                   AND UPPER(TRIM(monitor_state)) <> 'CLOSED'
                 ORDER BY id DESC
                 LIMIT 1",
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = "fpw" }
            );
            if (qMonitoring.recordCount EQ 0) {
                monitoringService = createObject("component", resolveApiV1ComponentPath("monitor")).init();
                monitoringResult = monitoringService.startMonitoringForFloatPlan(arguments.floatPlanId, "active_route");
                if (
                    !structKeyExists(monitoringResult, "SUCCESS")
                    OR monitoringResult.SUCCESS NEQ true
                ) {
                    return monitoringResult;
                }
                result.MONITORING_STARTED = true;
            }

            result.SUCCESS = true;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="getScheduledStartStateForFloatPlan" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var result = {
                SUCCESS = false,
                MESSAGE = "Float plan not found.",
                TRIP_STARTED = true,
                PENDING_START = false,
                STATUS = "",
                ROUTE_INSTANCE_ID = 0,
                DEPARTURE_TIME = "",
                DEPARTURE_TIMEZONE = "",
                STORED_DEPARTURE_TIMEZONE = ""
            };
            var qPlan = queryNew("");
            var gate = {};

            qPlan = queryExecute(
                "SELECT
                    floatplanId,
                    userId,
                    route_instance_id,
                    departureTime,
                    departureTZ,
                    departTimezone,
                    UPPER(TRIM(`status`)) AS statusValue
                 FROM floatplans
                 WHERE floatplanId = :planId
                   AND userId = :userId
                 LIMIT 1",
                {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
                },
                { datasource = "fpw" }
            );
            if (qPlan.recordCount EQ 0) {
                result.ERROR = "PLAN_NOT_FOUND";
                return result;
            }

            result.STATUS = (isNull(qPlan.statusValue[1]) ? "" : trim(toString(qPlan.statusValue[1])));
            result.ROUTE_INSTANCE_ID = (isNull(qPlan.route_instance_id[1]) ? 0 : val(qPlan.route_instance_id[1]));
            result.DEPARTURE_TIME = (!isNull(qPlan.departureTime[1]) AND isDate(qPlan.departureTime[1])) ? qPlan.departureTime[1] : "";
            result.DEPARTURE_TIMEZONE = (isNull(qPlan.departureTZ[1]) ? "" : trim(toString(qPlan.departureTZ[1])));
            if (!len(result.DEPARTURE_TIMEZONE)) {
                result.DEPARTURE_TIMEZONE = (isNull(qPlan.departTimezone[1]) ? "" : trim(toString(qPlan.departTimezone[1])));
            }
            result.STORED_DEPARTURE_TIMEZONE = (isNull(qPlan.departTimezone[1]) ? "" : trim(toString(qPlan.departTimezone[1])));

            gate = evaluateScheduledStartGate(
                result.DEPARTURE_TIME,
                result.DEPARTURE_TIMEZONE,
                result.STORED_DEPARTURE_TIMEZONE,
                "fpw"
            );
            result.TRIP_STARTED = gate.trip_started;
            result.PENDING_START = !result.TRIP_STARTED;
            result.SUCCESS = true;
            result.MESSAGE = (result.TRIP_STARTED ? "Scheduled departure is due." : "Scheduled departure is still pending.");
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="evaluateScheduledStartGate" access="private" returntype="struct" output="false">
        <cfargument name="departureTime" required="true">
        <cfargument name="departureTimeZone" type="string" required="false" default="">
        <cfargument name="storedDepartureTimeZone" type="string" required="false" default="">
        <cfargument name="datasource" type="string" required="false" default="fpw">
        <cfscript>
            var result = { trip_started = true };
            var comparisonNow = "";
            var timeZoneId = trim(arguments.departureTimeZone);
            var storedTimeZoneId = uCase(trim(arguments.storedDepartureTimeZone));

            if (!isDate(arguments.departureTime)) {
                return result;
            }

            if (storedTimeZoneId EQ "UTC") {
                comparisonNow = currentTimestampForTimeZone("UTC");
            } else if (len(timeZoneId)) {
                comparisonNow = currentTimestampForTimeZone(timeZoneId);
            }

            if (!isDate(comparisonNow)) {
                comparisonNow = now();
            }

            result.trip_started = (dateCompare(comparisonNow, arguments.departureTime, "s") GTE 0);
            return result;
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
