<cfcomponent output="false">

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfargument name="action" type="string" required="false" default="getStreamBootstrap">
        <cfargument name="slug" type="string" required="false" default="">
        <cfargument name="t" type="string" required="false" default="">
        <cfargument name="stream_id" type="numeric" required="false" default="0">
        <cfargument name="cursor" type="numeric" required="false" default="0">
        <cfargument name="limit" type="numeric" required="false" default="20">
        <cfargument name="routeCode" type="string" required="false" default="">
        <cfargument name="routeInstanceId" type="string" required="false" default="">
        <cfargument name="floatplan_id" type="numeric" required="false" default="0">
        <cfargument name="as_of_utc" type="string" required="false" default="">

        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

        <cflog
            file="fpw-upload-debug"
            text="ENTER handle(): method=#cgi.request_method#, contentType=#cgi.content_type#, query=#cgi.query_string#">
        <cftry>
            <cfset var contentTypeVal = structKeyExists(cgi, "content_type") ? lCase(toString(cgi.content_type)) : "">
            <cfset var isMultipartRequest = findNoCase("multipart/form-data", contentTypeVal) GT 0>
            <cfset var body = isMultipartRequest ? {} : getBodyJson()>
            <cfset var act = lCase(trim(arguments.action))>
            <cfset var currentUserId = resolveSessionUserId()>
            <cfset var payload = {}>
            <cfset var slugVal = "">
            <cfset var tokenVal = "">
            <cfset var streamIdVal = 0>
            <cfset var cursorVal = 0>
            <cfset var limitVal = 20>
            <cfset var displayNameVal = "">
            <cfset var emailVal = "">
            <cfset var passwordVal = "">
            <cfset var followerTokenVal = "">
            <cfset var emojiVal = "">
            <cfset var bodyTextVal = "">
            <cfset var mediaUrlVal = "">
            <cfset var postIdVal = 0>
            <cfset var commentIdVal = 0>
            <cfset var followerIdVal = 0>
            <cfset var floatPlanIdVal = 0>
            <cfset var pointVal = "">
            <cfset var routeLegOrderVal = "">
            <cfset var asOfUtcVal = "">
            <cfset var memberGateResult = {}>
            <cfif act EQ "getstreambootstrap">
                <cfset slugVal = trim(toString(pickArg(body, "slug", "route_slug", arguments.slug)))>
                <cfset tokenVal = trim(toString(pickArg(body, "t", "token", arguments.t)))>
                <cfset streamIdVal = val(pickArg(body, "stream_id", "streamId", arguments.stream_id))>
                <cfset payload = getStreamBootstrap(slugVal, tokenVal, streamIdVal, currentUserId)>
                <cfoutput>#serializeJSON(payload)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "getactivecruiseweather">
                <cfset floatPlanIdVal = val(pickArg(body, "floatPlanId", "float_plan_id", 0))>
                <cfset pointVal = lCase(trim(toString(pickArg(body, "point", "leg_point", ""))))>
                <cfset routeLegOrderVal = trim(toString(pickArg(body, "routeLegOrder", "route_leg_order", "")))>
                <cfset memberGateResult = requireMemberPremiumAccess(currentUserId, "BASIC_ACTIVE_CRUISE_RESTRICTED", "Upgrade to Premium to use Active Cruise weather.")>
                <cfif NOT memberGateResult.SUCCESS>
                    <cfoutput>#serializeJSON(memberGateResult)#</cfoutput>
                    <cfreturn>
                </cfif>
                <cfset payload = getActiveCruiseWeatherCanonical(currentUserId, floatPlanIdVal, pointVal, routeLegOrderVal)>
                <cfoutput>#serializeJSON(payload)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "gettripprogressprojection">
                <cfset streamIdVal = val(pickArg(body, "stream_id", "streamId", arguments.stream_id))>
                <cfset floatPlanIdVal = val(pickArg(body, "floatplan_id", "floatPlanId", arguments.floatplan_id))>
                <cfset asOfUtcVal = trim(toString(pickArg(body, "as_of_utc", "asOfUtc", arguments.as_of_utc)))>
                <cfset memberGateResult = requireMemberPremiumAccess(currentUserId, "BASIC_ACTIVE_CRUISE_RESTRICTED", "Upgrade to Premium to use Active Cruise trip projections.")>
                <cfif NOT memberGateResult.SUCCESS>
                    <cfoutput>#serializeJSON(memberGateResult)#</cfoutput>
                    <cfreturn>
                </cfif>
                <cfset payload = getTripProgressProjectionDiagnostic(streamIdVal, floatPlanIdVal, asOfUtcVal, currentUserId)>
                <cfoutput>#serializeJSON(payload)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "listposts">
                <cfset tokenVal = trim(toString(pickArg(body, "t", "token", arguments.t)))>
                <cfset streamIdVal = val(pickArg(body, "stream_id", "streamId", arguments.stream_id))>
                <cfset cursorVal = val(pickArg(body, "cursor", "before_id", arguments.cursor))>
                <cfset limitVal = val(pickArg(body, "limit", "page_size", arguments.limit))>
                <cfset followerTokenVal = trim(toString(pickArg(body, "follower_token", "followerToken", "")))>
                <cfset payload = listPosts(streamIdVal, cursorVal, limitVal, tokenVal, followerTokenVal, currentUserId)>
                <cfoutput>#serializeJSON(payload)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "followeridentify">
                <cfset streamIdVal = val(pickArg(body, "stream_id", "streamId", arguments.stream_id))>
                <cfset tokenVal = trim(toString(pickArg(body, "t", "token", arguments.t)))>
                <cfset displayNameVal = trim(toString(pickArg(body, "display_name", "displayName", "")))>
                <cfset emailVal = trim(toString(pickArg(body, "email", "emailAddress", "")))>
                <cfset passwordVal = trim(toString(pickArg(body, "password", "streamPassword", "")))>
                <cfset payload = followerIdentify(streamIdVal, tokenVal, displayNameVal, emailVal, passwordVal)>
                <cfoutput>#serializeJSON(payload)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "togglereaction">
                <cfset postIdVal = val(pickArg(body, "post_id", "postId", 0))>
                <cfset emojiVal = lCase(trim(toString(pickArg(body, "emoji", "reaction", ""))))>
                <cfset followerTokenVal = trim(toString(pickArg(body, "follower_token", "followerToken", "")))>
                <cfset payload = toggleReaction(postIdVal, emojiVal, followerTokenVal, currentUserId)>
                <cfoutput>#serializeJSON(payload)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "addcomment">
                <cfset postIdVal = val(pickArg(body, "post_id", "postId", 0))>
                <cfset bodyTextVal = trim(toString(pickArg(body, "body", "comment", "")))>
                <cfset followerTokenVal = trim(toString(pickArg(body, "follower_token", "followerToken", "")))>
                <cfset payload = addComment(postIdVal, bodyTextVal, followerTokenVal, currentUserId)>
                <cfoutput>#serializeJSON(payload)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "ownercreatepost">
                <cfset streamIdVal = val(pickArg(body, "stream_id", "streamId", arguments.stream_id))>
                <cfset bodyTextVal = trim(toString(pickArg(body, "body", "text", "")))>
                <cfset mediaUrlVal = trim(toString(pickArg(body, "media_url", "mediaUrl", "")))>
                <cfset memberGateResult = requireMemberPremiumAccess(currentUserId, "BASIC_FOLLOW_RESTRICTED", "Upgrade to Premium to publish Follow Page updates.")>
                <cfif NOT memberGateResult.SUCCESS>
                    <cfoutput>#serializeJSON(memberGateResult)#</cfoutput>
                    <cfreturn>
                </cfif>
                <cfset payload = ownerCreatePost(streamIdVal, bodyTextVal, mediaUrlVal, currentUserId)>
                <cfoutput>#serializeJSON(payload)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "ownercreatepostwithmedia">
                <cfset streamIdVal = val(structKeyExists(form, "stream_id") ? form.stream_id : pickArg(body, "stream_id", "streamId", arguments.stream_id))>
                <cfset bodyTextVal = trim(toString(structKeyExists(form, "body") ? form.body : pickArg(body, "body", "text", "")))>
                <cfset memberGateResult = requireMemberPremiumAccess(currentUserId, "BASIC_FOLLOW_RESTRICTED", "Upgrade to Premium to publish Follow Page updates.")>
                <cfif NOT memberGateResult.SUCCESS>
                    <cfoutput>#serializeJSON(memberGateResult)#</cfoutput>
                    <cfreturn>
                </cfif>
                <cfset payload = ownerCreatePostWithMediaInternal(streamIdVal, bodyTextVal, currentUserId)>
                <cfoutput>#serializeJSON(payload)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "ownerdeletepost">
                <cfset postIdVal = val(pickArg(body, "post_id", "postId", 0))>
                <cfset memberGateResult = requireMemberPremiumAccess(currentUserId, "BASIC_FOLLOW_RESTRICTED", "Upgrade to Premium to manage Follow Page posts.")>
                <cfif NOT memberGateResult.SUCCESS>
                    <cfoutput>#serializeJSON(memberGateResult)#</cfoutput>
                    <cfreturn>
                </cfif>
                <cfset payload = ownerDeletePost(postIdVal, currentUserId)>
                <cfoutput>#serializeJSON(payload)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "ownerdeletecomment">
                <cfset commentIdVal = val(pickArg(body, "comment_id", "commentId", 0))>
                <cfset memberGateResult = requireMemberPremiumAccess(currentUserId, "BASIC_FOLLOW_RESTRICTED", "Upgrade to Premium to manage Follow Page comments.")>
                <cfif NOT memberGateResult.SUCCESS>
                    <cfoutput>#serializeJSON(memberGateResult)#</cfoutput>
                    <cfreturn>
                </cfif>
                <cfset payload = ownerDeleteComment(commentIdVal, currentUserId)>
                <cfoutput>#serializeJSON(payload)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "ownerblockfollower">
                <cfset followerIdVal = val(pickArg(body, "follower_id", "followerId", 0))>
                <cfset memberGateResult = requireMemberPremiumAccess(currentUserId, "BASIC_FOLLOW_RESTRICTED", "Upgrade to Premium to manage Follow Page followers.")>
                <cfif NOT memberGateResult.SUCCESS>
                    <cfoutput>#serializeJSON(memberGateResult)#</cfoutput>
                    <cfreturn>
                </cfif>
                <cfset payload = ownerBlockFollower(followerIdVal, currentUserId)>
                <cfoutput>#serializeJSON(payload)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "ownerensurestream">
                <cfset memberGateResult = requireMemberPremiumAccess(currentUserId, "BASIC_FOLLOW_RESTRICTED", "Upgrade to Premium to create or manage Follow Page streams.")>
                <cfif NOT memberGateResult.SUCCESS>
                    <cfoutput>#serializeJSON(memberGateResult)#</cfoutput>
                    <cfreturn>
                </cfif>
                <cfset payload = ownerEnsureStream(currentUserId)>
                <cfoutput>#serializeJSON(payload)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "seeddemostream">
                <cfset slugVal = trim(toString(pickArg(body, "slug", "route_slug", arguments.slug)))>
                <cfset payload = seedDemoStream(slugVal, currentUserId)>
                <cfoutput>#serializeJSON(payload)#</cfoutput>
                <cfreturn>

            <cfelse>
                <cfoutput>#serializeJSON({
                    "SUCCESS"=false,
                    "AUTH"=(currentUserId GT 0),
                    "MESSAGE"="Unknown action",
                    "ERROR"={"MESSAGE"="Unsupported action: " & arguments.action}
                })#</cfoutput>
                <cfreturn>
            </cfif>

            <cfcatch>
                <cfoutput>#serializeJSON({
                    "SUCCESS"=false,
                    "AUTH"=(resolveSessionUserId() GT 0),
                    "MESSAGE"="Application error",
                    "ERROR"={"MESSAGE"=cfcatch.message, "DETAIL"=cfcatch.detail}
                })#</cfoutput>
            </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="ownerCreatePostWithMedia" access="remote" returntype="void" output="true">
        <cflog
            file="fpw-upload-debug"
            text="ENTER ownerCreatePostWithMedia(): method=#cgi.request_method#, contentType=#cgi.content_type#, query=#cgi.query_string#">
        <cfset var currentUserId = resolveSessionUserId()>
        <cfset var streamIdVal = val(structKeyExists(form, "stream_id") ? form.stream_id : 0)>
        <cfset var bodyTextVal = trim(toString(structKeyExists(form, "body") ? form.body : ""))>
        <cfset var requestMethodVal = structKeyExists(cgi, "request_method") ? uCase(toString(cgi.request_method)) : "">
        <cfset var memberGateResult = {}>
        <cfset var payload = {
            "SUCCESS"=false,
            "AUTH"=(currentUserId GT 0),
            "STATUS_CODE"=500,
            "MESSAGE"="Unhandled request path",
            "ERROR"={"MESSAGE"="Unhandled request path."}
        }>
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">
        <cfset memberGateResult = requireMemberPremiumAccess(currentUserId, "BASIC_FOLLOW_RESTRICTED", "Upgrade to Premium to publish Follow Page updates.")>
        <cfif NOT memberGateResult.SUCCESS>
            <cfif structKeyExists(memberGateResult, "STATUS_CODE")>
                <cfheader statuscode="#val(memberGateResult.STATUS_CODE)#">
            </cfif>
            <cfoutput>#serializeJSON(memberGateResult)#</cfoutput>
            <cfreturn>
        </cfif>
        <cfif requestMethodVal EQ "POST">
            <cfset payload = {
                "SUCCESS"=false,
                "AUTH"=(currentUserId GT 0),
                "STATUS_CODE"=405,
                "MESSAGE"="Use handle action for media uploads",
                "ERROR"={"MESSAGE"="POST image uploads must use method=handle&action=ownerCreatePostWithMedia."}
            }>
        <cfelse>
        <cftry>
            <cfset payload = ownerCreatePostWithMediaInternal(streamIdVal, bodyTextVal, currentUserId)>
            <cfcatch>
                <cfset payload = {
                    "SUCCESS"=false,
                    "AUTH"=(currentUserId GT 0),
                    "STATUS_CODE"=500,
                    "MESSAGE"="Application error",
                    "ERROR"={"MESSAGE"=cfcatch.message, "DETAIL"=cfcatch.detail}
                }>
            </cfcatch>
        </cftry>
        </cfif>
        <cfif !payload.SUCCESS>
            <cfheader statuscode="#(structKeyExists(payload, 'STATUS_CODE') ? val(payload.STATUS_CODE) : 400)#">
        </cfif>
        <cfoutput>#serializeJSON(payload)#</cfoutput>
        <cfreturn>
    </cffunction>

    <cffunction name="diagnosticEcho" access="remote" returntype="void" output="true">
        <cfset var result = {
            "method"=(structKeyExists(cgi, "request_method") ? toString(cgi.request_method) : ""),
            "contentType"=(structKeyExists(cgi, "content_type") ? toString(cgi.content_type) : ""),
            "query"=(structKeyExists(cgi, "query_string") ? toString(cgi.query_string) : ""),
            "hasFormProbe"=structKeyExists(form, "probe"),
            "formProbe"=(structKeyExists(form, "probe") ? toString(form.probe) : ""),
            "formKeys"=structKeyList(form)
        }>

        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">
        <cfoutput>#serializeJSON(result)#</cfoutput>
    </cffunction>

    <cffunction name="getTripProgressProjectionDiagnostic" access="private" returntype="struct" output="false">
        <cfargument name="streamId" type="numeric" required="false" default="0">
        <cfargument name="floatPlanId" type="numeric" required="false" default="0">
        <cfargument name="asOfUtc" type="string" required="false" default="">
        <cfargument name="currentUserId" type="numeric" required="false" default="0">
        <cfscript>
            var projectionService = "";
            var projection = {};

            if (!isLocalTripProjectionDiagnosticRequest()) {
                return {
                    "success" = false,
                    "auth" = (arguments.currentUserId GT 0),
                    "message" = "Trip progress projection diagnostics are available only from the local FPW runtime.",
                    "error" = { "message" = "Local diagnostics only." }
                };
            }

            if (arguments.streamId LTE 0 AND arguments.floatPlanId LTE 0) {
                return {
                    "success" = false,
                    "auth" = (arguments.currentUserId GT 0),
                    "message" = "stream_id or floatplan_id is required.",
                    "error" = { "message" = "Missing stream_id or floatplan_id." }
                };
            }

            try {
                projectionService = createTripProgressProjectionService();
                if (arguments.streamId GT 0) {
                    projection = projectionService.getProjectionForStream(arguments.streamId, arguments.asOfUtc);
                } else {
                    projection = projectionService.getProjection(arguments.floatPlanId, arguments.asOfUtc);
                }
            } catch (any projectionErr) {
                return {
                    "success" = false,
                    "auth" = (arguments.currentUserId GT 0),
                    "message" = "Trip progress projection failed.",
                    "error" = { "message" = projectionErr.message, "detail" = projectionErr.detail }
                };
            }

            if (!isStruct(projection)) {
                projection = {
                    "success" = false,
                    "message" = "Trip progress projection returned an invalid payload."
                };
            }

            projection["auth"] = (arguments.currentUserId GT 0);
            projection["diagnosticAccess"] = "local-read-only";
            return projection;
        </cfscript>
    </cffunction>

    <cffunction name="createTripProgressProjectionService" access="private" returntype="any" output="false">
        <cfscript>
            try {
                return createObject("component", "fpw.api.v1.TripProgressProjectionService").init("fpw");
            } catch (any projectionPathErr) {
                return createObject("component", "api.v1.TripProgressProjectionService").init("fpw");
            }
        </cfscript>
    </cffunction>

    <cffunction name="createActiveTripPaceService" access="private" returntype="any" output="false">
        <cfscript>
            try {
                return createObject("component", "fpw.api.v1.ActiveTripPaceService").init(resolveDatasource());
            } catch (any pacePathErr) {
                return createObject("component", "api.v1.ActiveTripPaceService").init(resolveDatasource());
            }
        </cfscript>
    </cffunction>

    <cffunction name="createRouteMapGeometryService" access="private" returntype="any" output="false">
        <cfscript>
            try {
                return createObject("component", "fpw.api.v1.RouteMapGeometryService").init("fpw");
            } catch (any routeMapGeometryPathErr) {
                return createObject("component", "api.v1.RouteMapGeometryService").init("fpw");
            }
        </cfscript>
    </cffunction>

    <cffunction name="isLocalTripProjectionDiagnosticRequest" access="private" returntype="boolean" output="false">
        <cfscript>
            var hostVal = structKeyExists(cgi, "http_host") ? lCase(toString(cgi.http_host)) : "";
            var serverNameVal = structKeyExists(cgi, "server_name") ? lCase(toString(cgi.server_name)) : "";
            var remoteAddrVal = structKeyExists(cgi, "remote_addr") ? lCase(toString(cgi.remote_addr)) : "";

            return (
                find("localhost", hostVal) GT 0
                OR left(hostVal, 9) EQ "127.0.0.1"
                OR left(hostVal, 5) EQ "[::1]"
                OR find("localhost", serverNameVal) GT 0
                OR serverNameVal EQ "127.0.0.1"
                OR remoteAddrVal EQ "127.0.0.1"
                OR remoteAddrVal EQ "::1"
            );
        </cfscript>
    </cffunction>

    <cffunction name="ownerCreatePostWithMediaFromForm" access="public" returntype="struct" output="false">
        <cfargument name="streamId" type="numeric" required="false" default="0">
        <cfargument name="body" type="string" required="false" default="">
        <cfscript>
            return ownerCreatePostWithMediaInternal(
                val(arguments.streamId),
                trim(arguments.body),
                resolveSessionUserId()
            );
        </cfscript>
    </cffunction>

    <cffunction name="ensureScheduledPlanOperationalStart" access="private" returntype="struct" output="false">
        <cfargument name="ownerUserId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "TRIP_STARTED"=true,
                "PENDING_START"=false,
                "MESSAGE"="Unable to evaluate the scheduled departure gate."
            };
            var floatPlanComponent = "";

            if (arguments.ownerUserId LTE 0 OR arguments.floatPlanId LTE 0) {
                out.MESSAGE = "A valid owner and float plan are required.";
                return out;
            }

            try {
                floatPlanComponent = createObject("component", "fpw.api.v1.floatplan");
            } catch (any floatPlanPathErr) {
                floatPlanComponent = createObject("component", "api.v1.floatplan");
            }

            out = floatPlanComponent.ensureOperationalStartForScheduledPlan(arguments.ownerUserId, arguments.floatPlanId);
            if (!isStruct(out)) {
                out = {
                    "SUCCESS"=false,
                    "TRIP_STARTED"=true,
                    "PENDING_START"=false,
                    "MESSAGE"="Unable to evaluate the scheduled departure gate."
                };
            }
            return out;
        </cfscript>
    </cffunction>

	    <cffunction name="getStreamBootstrap" access="private" returntype="struct" output="false">
	        <cfargument name="slug" type="string" required="false" default="">
	        <cfargument name="shareToken" type="string" required="false" default="">
	        <cfargument name="streamId" type="numeric" required="false" default="0">
	        <cfargument name="currentUserId" type="numeric" required="false" default="0">
	        <cfscript>
	            var tTotalStart = getTickCount();
	            var tSectionStart = 0;
	            var tMap = 0;
	            var tTimeline = 0;
	            var tWeather = 0;
	            var out = {
	                "SUCCESS"=false,
	                "AUTH"=true,
	                "MESSAGE"="Unable to load voyage stream",
                "stream"={},
                "topCards"={},
                "map"={"routeGeo"={}, "pins"=[], "current"={}},
                "legWeather"={},
                "pinned"={},
                "timeline"={"summary"={}, "legs"=[], "meta"={}},
                "body"={},
                "publicAuthority"={}
            };
            var streamRow = readStream(arguments.slug, arguments.streamId);
            var canRead = {};
            var ds = resolveDatasource();
            var qPlan = queryNew("");
            var qPlanSql = "";
            var qLastPost = queryNew("");
            var qWildlife = queryNew("");
            var qViewerCount = queryNew("");
            var routeMap = {};
            var topCards = {};
            var pinned = {};
            var followTimeline = {"summary"={}, "legs"=[], "meta"={}};
            var isOwner = false;
            var statusLabel = "Status Unavailable";
            var monitorStateVal = "";
            var monitoringCheckinStatusVal = "";
            var monitoringSummary = "Monitoring unavailable";
            var monitorStateTextHtml = "<strong>Monitoring unavailable</strong><br />No active monitoring state is available.";
            var monitorStateLabel = "Unavailable";
            var lastCheckinLabel = "n/a";
            var lastCheckinUtc = "";
            var etaLabel = "n/a";
            var etaUtc = "";
            var routeTotalMiles = 0;
            var routeTotalDays = 0;
            var routeTotalLocks = 0;
            var wildlifeCount = 0;
            var streamTitle = "Voyage";
            var viewerCountVal = 0;
            var vesselNameVal = "";
            var privacyLabel = "";
            var body = {};
            var actualCheckInLabel = "";
            var actualCheckInUtc = "";
            var checkedInAtVal = "";
            var expectedCheckInDt = "";
            var checkInContextVal = "";
            var isOvernightCheckIn = false;
            var actualResumeAt = "";
            var actualResumeAtLocal = "";
            var hasActualResumeAt = false;
            var departureTimeZoneVal = "";
            var dailyStartLocalTimeVal = "";
            var storedOvernightPauseMinutes = 0;
            var storedManualDelayMinutes = 0;
            var followProjection = {};
            var publicAuthority = {};
            var publicAuthorityService = "";
            var useCanonicalFollowProjection = false;
            var canonicalFollowProjectionBlocked = false;
            var followProjectionWarningIndex = 0;
            var followProjectionWarning = {};
            var followProjectionWarningCode = "";
            var followProjectionLegIndex = 0;
            var followProjectionLegOrder = 0;
            var followProjectionEtaUtc = "";
            var followProjectionEtaLocalInput = "";
            var qFollowProjectionEtaLocal = queryNew("");
            var elapsedCheckInLabel = "-- since last check-in";
            var nextStopLabelVal = "";
            var nextStopEtaBaseDt = "";
            var nextStopEtaDt = "";
            var nextStopEtaMinutes = 0;
            var nextStopCumulativeMinutes = 0;
            var activeLegEtaBaseDt = "";
            var activeLegEtaMinutes = 0;
            var overnightPauseMinutes = 0;
            var nextMorningResumeDt = "";
            var resumeTimeZone = "";
            var resumeCalendar = "";
            var localDayStartRule = loadOvernightTimingRule();
            var plannedNextStopEtaDt = "";
            var nextStopLeg = {};
            var qTripStart = queryNew("");
            var journeyDepartedDt = "";
            var qLegTiming = queryNew("");
            var qMilesTodayTiming = queryNew("");
            var qActualResumeLocal = queryNew("");
            var currentLegStartedAt = "";
            var priorLegCompletedAt = "";
            var scheduledDepartureRawDt = "";
            var hasOperationalCheckIn = false;
            var hasValidCurrentLegStart = false;
            var hasValidPriorLegCompletion = false;
            var tripStartState = {};
            var tripStarted = true;
            var routeInstanceIdVal = 0;
            var memberGateResult = {};
            var weatherComponent = "";
            var weatherComponentPath = "";
            var legWeather = {
                "start"={ "available"=false, "summary"="", "alerts_count"=0, "top_alert_severity"="", "forecast_short"="", "wind_speed"="", "wind_direction"="", "wave_height_ft"="", "visibility_mi"="" },
                "end"={ "available"=false, "summary"="", "alerts_count"=0, "top_alert_severity"="", "forecast_short"="", "wind_speed"="", "wind_direction"="", "wave_height_ft"="", "visibility_mi"="" },
                "conditions"={ "available"=false, "basis"="worse_of_start_end_advisory", "headline"="", "summary"="", "meta"="" }
            };
            var pointDefs = {};
            var pointKey = "";
            var pointDef = {};
            var pointResults = {};
            var roundedLat = 0;
            var roundedLng = 0;
            var pointCacheKey = "";
            var pointRaw = {};
            var pointOut = {};
            var alertIdx = 0;
            var alertItem = {};
            var severityTxt = "";
            var severityRank = 0;
            var pointSummary = "";
            var pointForecast = {};
            var pointMarine = {};
            var pointSurface = {};
            var startRank = 0;
            var endRank = 0;
            var worsePointKey = "";
            var worsePoint = {};
            var timelineSummary = {};
            var timelineLeg = {};
            var timelineLegDistanceNm = 0.0;
            var timelineLegProgressPct = 0.0;
            var timelineTotalNm = 0.0;
            var timelineTotalHours = 0.0;
            var timelineEffectiveSpeedKn = 0.0;
            var completedMilesSoFarNm = 0.0;
            var milesLeftNm = 0.0;
            var expectedMilesByNowNm = 0.0;
            var progressMilesForConfidenceNm = 0.0;
            var achievedPaceKn = 0.0;
            var elapsedTripMinutes = 0;
            var elapsedTripHours = 0.0;
            var confidenceNowDt = now();
            var nextStopRemainingNm = -1.0;
            var projectedNextStopMinutes = 0;
            var projectedFinalMinutes = 0;
            var projectedNextStopEtaDt = "";
            var plannedNextStopEtaWithGraceDt = "";
            var plannedFinalEtaDt = "";
            var projectedFinalEtaDt = "";
            var plannedFinalEtaWithGraceDt = "";
            var progressRatio = 1.0;
            var tripConfidenceScore = 50;
            var tripConfidenceLabel = "Moderate";
            var nextStopOnTime = false;
            var finalDestinationOnTime = false;
            var comparisonElapsedHours = 0.0;
            var tripConfidenceGraceWindowMinutes = 60;
            var hasActiveTrip = false;
            var hasNextStop = false;
            var hoursSinceLastCheckin = -1.0;
            var etaDriftHours = -1.0;
            var etaUnknown = true;
            var hasFreshSignal = false;
            var hasRecentSignal = false;
            var severeProgressMismatch = false;
            var newlyStartedTrip = false;
            var localNowQuery = queryNew("");
            var localNowDt = "";
            var utcNowDt = "";
            var milesTodayWindowStartDt = "";
            var milesTodayWindowEndDt = "";
            var milesTodayNm = "";
            var hoursTodayTotal = "";
            var milesTodayTimingByOrder = {};
            var milesTodayTiming = {};
            var milesTodayLegOrder = 0;
            var milesTodayLegKey = "";
            var milesTodayLegDistanceNm = 0.0;
            var milesTodayLegHours = 0.0;
            var milesTodayLegStartDt = "";
            var milesTodayLegEndDt = "";
            var milesTodayOverlapStartDt = "";
            var milesTodayOverlapEndDt = "";
            var milesTodayOverlapMinutes = 0;
            var milesTodayActualLegMinutes = 0;
            var milesTodayPlannedLegMinutes = 0;
            var milesTodayLegNm = 0.0;
            var hoursTodayLegHours = 0.0;
            var routeMapActiveLegOrder = 0;
            var actualResumeLegOrder = 0;
            var awaitingDepartureState = false;
            var usingActiveLegEta = false;

	            if (!structCount(streamRow)) {
	                out.MESSAGE = "Stream not found";
	                out.ERROR = { "MESSAGE"="No voyage stream matched the provided slug or stream id." };
	                writeLog(file="fpw-bootstrap-timing", text="[FPW_BOOTSTRAP_TIMING] total=" & (getTickCount() - tTotalStart) & "ms map=" & tMap & "ms timeline=" & tTimeline & "ms weather=" & tWeather & "ms", type="information");
	                return out;
	            }

            isOwner = (arguments.currentUserId GT 0 AND arguments.currentUserId EQ streamRow.owner_user_id);
            canRead = canReadStream(streamRow, arguments.shareToken, isOwner);
	            if (!canRead.allowed) {
	                out.MESSAGE = "Forbidden";
	                out.STATUS_CODE = 403;
	                out.ERROR = { "CODE"=canRead.code, "MESSAGE"=canRead.message };
	                writeLog(file="fpw-bootstrap-timing", text="[FPW_BOOTSTRAP_TIMING] total=" & (getTickCount() - tTotalStart) & "ms map=" & tMap & "ms timeline=" & tTimeline & "ms weather=" & tWeather & "ms", type="information");
	                return out;
	            }

            memberGateResult = requireOwnerPremiumFollowAccess(streamRow.owner_user_id);
            if (!memberGateResult.SUCCESS) {
                writeLog(file="fpw-bootstrap-timing", text="[FPW_BOOTSTRAP_TIMING] total=" & (getTickCount() - tTotalStart) & "ms map=" & tMap & "ms timeline=" & tTimeline & "ms weather=" & tWeather & "ms", type="information");
                return memberGateResult;
            }

	            if (streamRow.floatplan_id LTE 0) {
	                out.MESSAGE = "No active trip";
	                out.STATUS_CODE = 404;
	                out.ERROR = {
	                    "CODE"="INVALID_STREAM",
	                    "MESSAGE"="This Trip Page is not linked to an active trip."
	                };
	                writeLog(file="fpw-bootstrap-timing", text="[FPW_BOOTSTRAP_TIMING] total=" & (getTickCount() - tTotalStart) & "ms map=" & tMap & "ms timeline=" & tTimeline & "ms weather=" & tWeather & "ms", type="information");
	                return out;
	            }

            qPlanSql =
                "SELECT
                    fp.floatplanId,
                    fp.userId,
                    fp.floatPlanName,
                    fp.status,
                    fp.departing,
                    fp.departureTime,
                    fp.departTimezone,
                    fp.departureTZ,
                    fp.`returning`,
                    fp.returnTime,
                    fp.route_instance_id,
                    fp.route_day_number,
                    fp.lastUpdate,
                    fp.checkedInAt,"
                    & "
                    fp.checkin_context,
                    fp.dailyStartLocalTime,
                    (
                        SELECT
                            COALESCE(
                                CONVERT_TZ(
                                    m.expected_checkin_at,
                                    'UTC',
                                    NULLIF(COALESCE(NULLIF(fp.departureTZ, ''), NULLIF(fp.departTimezone, ''), 'UTC'), '')
                                ),
                                m.expected_checkin_at
                            )
                        FROM floatplan_monitoring m
                        WHERE m.float_plan_id = fp.floatplanId
                          AND m.is_monitoring_enabled = 1
                          AND UPPER(TRIM(m.monitor_state)) <> 'CLOSED'
                        ORDER BY m.id DESC
                        LIMIT 1
                    ) AS expected_checkin_at,
                    (
                        SELECT
                            NULLIF(UPPER(TRIM(m.monitor_state)), '')
                        FROM floatplan_monitoring m
                        WHERE m.float_plan_id = fp.floatplanId
                          AND m.is_monitoring_enabled = 1
                          AND UPPER(TRIM(m.monitor_state)) <> 'CLOSED'
                        ORDER BY m.id DESC
                        LIMIT 1
                    ) AS monitor_state,
                    (
                        SELECT
                            m.last_checkin_status
                        FROM floatplan_monitoring m
                        WHERE m.float_plan_id = fp.floatplanId
                          AND m.is_monitoring_enabled = 1
                          AND UPPER(TRIM(m.monitor_state)) <> 'CLOSED'
                        ORDER BY m.id DESC
                        LIMIT 1
                    ) AS last_checkin_status,
                    fp.overnight_pause_minutes_total,
                    fp.manual_delay_minutes_total,
                    fp.vesselId,
                    v.vesselName
                 FROM floatplans fp
                 LEFT JOIN vessels v ON v.vesselId = fp.vesselId
                 WHERE fp.floatplanId = :planId
                 LIMIT 1";

            qPlan = queryExecute(
                qPlanSql,
                {
                    planId = { value=streamRow.floatplan_id, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

	            if (qPlan.recordCount EQ 0) {
	                out.MESSAGE = "No active trip";
	                out.STATUS_CODE = 404;
	                out.ERROR = {
	                    "CODE"="FLOATPLAN_NOT_FOUND",
	                    "MESSAGE"="This Trip Page is not linked to an active trip."
	                };
	                writeLog(file="fpw-bootstrap-timing", text="[FPW_BOOTSTRAP_TIMING] total=" & (getTickCount() - tTotalStart) & "ms map=" & tMap & "ms timeline=" & tTimeline & "ms weather=" & tWeather & "ms", type="information");
	                return out;
	            }

	            if (val(qPlan.userId[1]) LTE 0 OR val(qPlan.userId[1]) NEQ streamRow.owner_user_id) {
	                out.MESSAGE = "No active trip";
	                out.STATUS_CODE = 403;
	                out.ERROR = {
	                    "CODE"="STREAM_OWNER_MISMATCH",
	                    "MESSAGE"="This Trip Page is not linked to the owner's active trip."
	                };
	                writeLog(file="fpw-bootstrap-timing", text="[FPW_BOOTSTRAP_TIMING] total=" & (getTickCount() - tTotalStart) & "ms map=" & tMap & "ms timeline=" & tTimeline & "ms weather=" & tWeather & "ms", type="information");
	                return out;
	            }

	            var canonicalPlan = resolveCanonicalActiveFloatPlan(streamRow.owner_user_id, streamRow.floatplan_id);
	            if (!canonicalPlan.SUCCESS) {
	                out.MESSAGE = canonicalPlan.MESSAGE;
	                out.STATUS_CODE = 403;
	                out.ERROR = {
	                    "CODE"=(structKeyExists(canonicalPlan, "ERROR") ? canonicalPlan.ERROR : "FOLLOW_UNAVAILABLE"),
	                    "MESSAGE"=canonicalPlan.MESSAGE
	                };
	                writeLog(file="fpw-bootstrap-timing", text="[FPW_BOOTSTRAP_TIMING] total=" & (getTickCount() - tTotalStart) & "ms map=" & tMap & "ms timeline=" & tTimeline & "ms weather=" & tWeather & "ms", type="information");
	                return out;
	            }

            tripStartState = ensureScheduledPlanOperationalStart(streamRow.owner_user_id, streamRow.floatplan_id);
            if (
                structKeyExists(tripStartState, "SUCCESS")
                AND tripStartState.SUCCESS
                AND structKeyExists(tripStartState, "TRIP_STARTED")
            ) {
                tripStarted = (tripStartState.TRIP_STARTED EQ true);
            }

            streamTitle = trim(toString(isNull(qPlan.floatPlanName[1]) ? "" : qPlan.floatPlanName[1]));
            if (!isNull(qPlan.monitor_state[1])) {
                monitorStateVal = uCase(trim(toString(qPlan.monitor_state[1])));
            }
            if (!isNull(qPlan.last_checkin_status[1])) {
                monitoringCheckinStatusVal = uCase(trim(toString(qPlan.last_checkin_status[1])));
            }
            routeInstanceIdVal = (!isNull(qPlan.route_instance_id[1]) ? val(qPlan.route_instance_id[1]) : 0);
            try {
                try {
                    publicAuthorityService = createObject("component", "fpw.api.v1.ActiveCruiseViewModelService").init(ds);
                } catch (any publicAuthorityPathErr) {
                    publicAuthorityService = createObject("component", "api.v1.ActiveCruiseViewModelService").init(ds);
                }
                publicAuthority = publicAuthorityService.getPublicFollowAuthority(streamRow.owner_user_id, streamRow.floatplan_id);
            } catch (any publicAuthorityErr) {
                publicAuthority = {};
            }
            checkInContextVal = normalizeCheckInContext(isNull(qPlan.checkin_context[1]) ? "" : qPlan.checkin_context[1]);
            isOvernightCheckIn = (checkInContextVal EQ "overnight");
            storedOvernightPauseMinutes = (
                !isNull(qPlan.overnight_pause_minutes_total[1]) AND isNumeric(qPlan.overnight_pause_minutes_total[1])
                    ? val(qPlan.overnight_pause_minutes_total[1])
                    : 0
            );
            if (storedOvernightPauseMinutes LT 0) {
                storedOvernightPauseMinutes = 0;
            }
            storedManualDelayMinutes = (
                !isNull(qPlan.manual_delay_minutes_total[1]) AND isNumeric(qPlan.manual_delay_minutes_total[1])
                    ? val(qPlan.manual_delay_minutes_total[1])
                    : 0
            );
            if (storedManualDelayMinutes LT 0) {
                storedManualDelayMinutes = 0;
            }
            departureTimeZoneVal = (isNull(qPlan.departureTZ[1]) ? "" : trim(toString(qPlan.departureTZ[1])));
            if (!len(departureTimeZoneVal)) {
                departureTimeZoneVal = (isNull(qPlan.departTimezone[1]) ? "" : trim(toString(qPlan.departTimezone[1])));
            }
            dailyStartLocalTimeVal = (isNull(qPlan.dailyStartLocalTime[1]) ? "" : trim(toString(qPlan.dailyStartLocalTime[1])));
            localDayStartRule = loadOvernightTimingRule(dailyStartLocalTimeVal);
            if (!isNull(qPlan.departureTime[1]) AND isDate(qPlan.departureTime[1])) {
                scheduledDepartureRawDt = qPlan.departureTime[1];
                journeyDepartedDt = qPlan.departureTime[1];
            }
            if (!isNull(qPlan.checkedInAt[1]) AND isDate(qPlan.checkedInAt[1])) {
                checkedInAtVal = qPlan.checkedInAt[1];
            }
            if (!isNull(qPlan.expected_checkin_at[1]) AND isDate(qPlan.expected_checkin_at[1])) {
                expectedCheckInDt = qPlan.expected_checkin_at[1];
            }
            hasOperationalCheckIn = (tripStarted AND isDate(checkedInAtVal));
            if (hasOperationalCheckIn AND isDate(scheduledDepartureRawDt)) {
                hasOperationalCheckIn = (dateCompare(checkedInAtVal, scheduledDepartureRawDt, "s") GTE 0);
            }
            if (hasOperationalCheckIn) {
                actualCheckInLabel = dateTimeFormat(checkedInAtVal, "mmm d, yyyy h:nn tt");
                actualCheckInUtc = formatUtcDate(checkedInAtVal);
                elapsedCheckInLabel = formatElapsedCheckIn(checkedInAtVal);
            } else if (tripStarted) {
                checkedInAtVal = "";
                elapsedCheckInLabel = "Awaiting first check-in after departure.";
            } else {
                checkedInAtVal = "";
                elapsedCheckInLabel = "Monitoring begins at scheduled departure.";
            }
            isOvernightCheckIn = (hasOperationalCheckIn AND checkInContextVal EQ "overnight");
            // Follow display authority only: a non-secure check-in after overnight pause is the actual resume time.
            if (
                tripStarted
                AND storedOvernightPauseMinutes GT 0
                AND hasOperationalCheckIn
                AND !isOvernightCheckIn
                AND len(monitoringCheckinStatusVal)
                AND ucase(monitoringCheckinStatusVal) NEQ "SECURE_FOR_NIGHT"
                AND isDate(checkedInAtVal)
            ) {
                actualResumeAt = checkedInAtVal;
                hasActualResumeAt = true;
            }
            if (!tripStarted) {
                statusLabel = "Scheduled";
            } else {
                switch (monitorStateVal) {
                    case "LATE":
                        statusLabel = "Late";
                        break;
                    case "MISSED":
                        statusLabel = "Missed Check-In";
                        break;
                    case "ESCALATED":
                        statusLabel = "Escalated";
                        break;
                    case "ACTIVE":
                        statusLabel = "All Good";
                        break;
                    default:
                        statusLabel = "Status Unavailable";
                }
            }
            if (!hasOperationalCheckIn) {
                storedOvernightPauseMinutes = 0;
            }
            monitoringCheckinStatusVal = uCase(trim(isNull(qPlan.last_checkin_status[1]) ? "" : qPlan.last_checkin_status[1]));
            voyageProgressStatusLabel = statusLabel;
            voyageProgressStatusVariant = "good";
            voyageProgressStatusCopy = "Monitoring is active and the trip is reporting normally.";
            monitoringSummary = "Monitoring unavailable";
            monitorStateTextHtml = "<strong>Monitoring unavailable</strong><br />No active monitoring state is available.";
            monitorStateLabel = "Unavailable";
            if (!tripStarted) {
                monitoringSummary = "Monitoring starts at scheduled departure";
                monitorStateTextHtml = "<strong>Monitoring pending</strong><br />The trip begins at the scheduled departure time.";
                monitorStateLabel = "Pending";
            } else {
                switch (monitorStateVal) {
                    case "LATE":
                        voyageProgressStatusVariant = "warning";
                        voyageProgressStatusCopy = "A check-in is due and the grace window is still open.";
                        monitoringSummary = "A check-in is due and the grace window is open";
                        monitorStateTextHtml = "<strong>Check-in late</strong><br />A new update is due and the grace window is still open.";
                        monitorStateLabel = "Late";
                        break;
                    case "MISSED":
                        voyageProgressStatusVariant = "danger";
                        voyageProgressStatusCopy = "A required check-in was missed and monitoring alerts are active.";
                        monitoringSummary = "A required check-in was missed";
                        monitorStateTextHtml = "<strong>Missed check-in</strong><br />The grace window expired without a new update.";
                        monitorStateLabel = "Missed";
                        break;
                    case "ESCALATED":
                        voyageProgressStatusVariant = "danger";
                        voyageProgressStatusCopy = "The missed check-in has escalated to selected contacts.";
                        monitoringSummary = "Selected contacts have been alerted";
                        monitorStateTextHtml = "<strong>Escalated</strong><br />The missed check-in has escalated to selected contacts.";
                        monitorStateLabel = "Escalated";
                        break;
                    case "ACTIVE":
                        monitoringSummary = "Active with missed check-in rules enabled";
                        monitorStateTextHtml = "<strong>Monitoring active</strong><br />No missed check-ins on this voyage";
                        monitorStateLabel = "Active";
                        break;
                    default:
                        monitoringSummary = "Monitoring unavailable";
                        monitorStateTextHtml = "<strong>Monitoring unavailable</strong><br />No active monitoring state is available.";
                        monitorStateLabel = "Unavailable";
                }

                if (hasOperationalCheckIn) {
                    switch (monitoringCheckinStatusVal) {
                        case "DELAYED":
                            voyageProgressStatusLabel = "Delayed";
                            voyageProgressStatusVariant = "warning";
                            voyageProgressStatusCopy = "Latest check-in reported Delayed.";
                            monitoringSummary = "Latest check-in reported delayed progress";
                            monitorStateTextHtml = "<strong>Delayed</strong><br />Latest check-in reported Delayed.";
                            monitorStateLabel = "Delayed";
                            break;
                        case "CHANGED_PLAN":
                            voyageProgressStatusLabel = "Changed Plan";
                            voyageProgressStatusVariant = "warning";
                            voyageProgressStatusCopy = "Latest check-in reported Changed Plan.";
                            monitoringSummary = "Latest check-in reported a changed plan";
                            monitorStateTextHtml = "<strong>Changed Plan</strong><br />Latest check-in reported Changed Plan.";
                            monitorStateLabel = "Changed Plan";
                            break;
                        case "NEED_ATTENTION":
                            voyageProgressStatusLabel = "Assistance Needed";
                            voyageProgressStatusVariant = "danger";
                            voyageProgressStatusCopy = "Latest check-in reported Assistance Needed.";
                            monitoringSummary = "Latest check-in requested assistance";
                            monitorStateTextHtml = "<strong>Assistance Needed</strong><br />Latest check-in reported Assistance Needed.";
                            monitorStateLabel = "Assistance Needed";
                            break;
                        case "SECURE_FOR_NIGHT":
                            voyageProgressStatusLabel = "Secure for the Night";
                            voyageProgressStatusVariant = "good";
                            voyageProgressStatusCopy = "The latest check-in secured the trip for the night until the next local morning check-in.";
                            monitoringSummary = "Secure for the night until the next local morning check-in";
                            monitorStateTextHtml = "<strong>Secure for the night</strong><br />Monitoring resumes at the next local morning check-in.";
                            monitorStateLabel = "Secure for the Night";
                            break;
                    }
                }
            }
            if (tripStarted) {
                statusLabel = voyageProgressStatusLabel;
            }
			if (routeInstanceIdVal LTE 0) {
	                out.MESSAGE = "No active trip";
	                out.STATUS_CODE = 403;
	                out.ERROR = {
	                    "CODE"="ROUTE_REQUIRED",
	                    "MESSAGE"="The active trip must be linked to a route."
	                };
	                writeLog(file="fpw-bootstrap-timing", text="[FPW_BOOTSTRAP_TIMING] total=" & (getTickCount() - tTotalStart) & "ms map=" & tMap & "ms timeline=" & tTimeline & "ms weather=" & tWeather & "ms", type="information");
	                return out;
	            }
            if (!len(streamTitle)) {
                streamTitle = "Voyage " & streamRow.slug;
            }

	            tSectionStart = getTickCount();
	            routeMap = buildRouteMapData(
	                routeInstanceId=routeInstanceIdVal,
	                ownerUserId=streamRow.owner_user_id,
	                fallbackDays=(qPlan.recordCount GT 0 AND !isNull(qPlan.route_day_number[1]) ? val(qPlan.route_day_number[1]) : 0)
	            );
	            tMap = getTickCount() - tSectionStart;
	            tSectionStart = getTickCount();
		            followTimeline = buildFollowCruiseTimeline(
		                routeInstanceId=routeInstanceIdVal,
		                ownerUserId=streamRow.owner_user_id,
		                opts={}
		            );
                    routeMapActiveLegOrder = (structKeyExists(routeMap, "active_leg_order") ? val(routeMap.active_leg_order) : 0);
                    awaitingDepartureState = (tripStarted AND structKeyExists(routeMap, "awaiting_departure") AND routeMap.awaiting_departure EQ true);
                    if (awaitingDepartureState AND hasActualResumeAt) {
                        awaitingDepartureState = false;
                    }
		            tTimeline = getTickCount() - tSectionStart;

            routeTotalMiles = roundTo1(routeMap.total_nm * 1.15078);
            routeTotalDays = (routeMap.total_days GT 0 ? routeMap.total_days : 0);
            routeTotalLocks = routeMap.total_locks;

            qLastPost = queryExecute(
                "SELECT id, created_utc
                 FROM voyage_posts
                 WHERE stream_id = :streamId
                 ORDER BY created_utc DESC, id DESC
                 LIMIT 1",
                {
                    streamId = { value=streamRow.id, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            if (qLastPost.recordCount GT 0 AND !isNull(qLastPost.created_utc[1])) {
                lastCheckinLabel = dateTimeFormat(qLastPost.created_utc[1], "mmm d, yyyy h:nn tt");
                lastCheckinUtc = formatUtcDate(qLastPost.created_utc[1]);
            }

            qWildlife = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM voyage_posts
                 WHERE stream_id = :streamId
                   AND event_type = 'wildlife'",
                {
                    streamId = { value=streamRow.id, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );
            wildlifeCount = (qWildlife.recordCount GT 0 AND !isNull(qWildlife.cnt[1]) ? val(qWildlife.cnt[1]) : 0);

            qViewerCount = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM voyage_followers
                 WHERE stream_id = :streamId",
                {
                    streamId = { value=streamRow.id, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );
            viewerCountVal = (qViewerCount.recordCount GT 0 AND !isNull(qViewerCount.cnt[1]) ? val(qViewerCount.cnt[1]) : 0);
            vesselNameVal = (qPlan.recordCount GT 0 AND !isNull(qPlan.vesselName[1]) ? trim(toString(qPlan.vesselName[1])) : "");

            if (streamRow.privacy_mode EQ "public") {
                privacyLabel = "Public share page";
            } else if (streamRow.privacy_mode EQ "password") {
                privacyLabel = "Password protected share page";
            } else if (streamRow.privacy_mode EQ "invite") {
                privacyLabel = "Invite-only share page";
            }

            nextStopLabelVal = (len(routeMap.next_stop_label) ? trim(toString(routeMap.next_stop_label)) : "");
            if (
                qPlan.recordCount GT 0
                AND !isNull(qPlan.departureTime[1])
                AND isDate(qPlan.departureTime[1])
                AND len(nextStopLabelVal)
                AND (!tripStarted OR routeMapActiveLegOrder GT 0 OR hasActualResumeAt)
                AND isStruct(followTimeline)
                AND structKeyExists(followTimeline, "legs")
                AND isArray(followTimeline.legs)
            ) {
                nextStopEtaBaseDt = qPlan.departureTime[1];
                storedDepartureTimeZoneVal = (isNull(qPlan.departTimezone[1]) ? "" : trim(toString(qPlan.departTimezone[1])));
                if (
                    isDate(nextStopEtaBaseDt)
                    AND ucase(storedDepartureTimeZoneVal) EQ "UTC"
                    AND len(departureTimeZoneVal)
                    AND ucase(departureTimeZoneVal) NEQ "UTC"
                ) {
                    qLocalDeparture = queryExecute("
                        SELECT CONVERT_TZ(:utcDateTime, 'UTC', :targetTimeZone) AS localDateTime
                    ", {
                        utcDateTime = { value = nextStopEtaBaseDt, cfsqltype = "cf_sql_timestamp" },
                        targetTimeZone = { value = departureTimeZoneVal, cfsqltype = "cf_sql_varchar" }
                    }, { datasource = ds });
                    if (qLocalDeparture.recordCount GT 0 AND !isNull(qLocalDeparture.localDateTime[1])) {
                        nextStopEtaBaseDt = qLocalDeparture.localDateTime[1];
                    }
                }
                actualResumeAtLocal = "";
                if (hasActualResumeAt AND isDate(actualResumeAt)) {
                    actualResumeAtLocal = actualResumeAt;
                    if (
                        ucase(storedDepartureTimeZoneVal) EQ "UTC"
                        AND len(departureTimeZoneVal)
                        AND ucase(departureTimeZoneVal) NEQ "UTC"
                    ) {
                        qActualResumeLocal = queryExecute("
                            SELECT CONVERT_TZ(:utcDateTime, 'UTC', :targetTimeZone) AS localDateTime
                        ", {
                            utcDateTime = { value = actualResumeAt, cfsqltype = "cf_sql_timestamp" },
                            targetTimeZone = { value = departureTimeZoneVal, cfsqltype = "cf_sql_varchar" }
                        }, { datasource = ds });
                        if (qActualResumeLocal.recordCount GT 0 AND !isNull(qActualResumeLocal.localDateTime[1]) AND isDate(qActualResumeLocal.localDateTime[1])) {
                            actualResumeAtLocal = qActualResumeLocal.localDateTime[1];
                        }
                    }
                }
                for (i = 1; i LTE arrayLen(followTimeline.legs); i++) {
                    nextStopLeg = followTimeline.legs[i];
                    if (!isStruct(nextStopLeg)) {
                        continue;
                    }
                    if (!structKeyExists(nextStopLeg, "end_name")) {
                        continue;
                    }
                    if (
                        tripStarted
                        AND routeMapActiveLegOrder GT 0
                        AND (
                            !structKeyExists(nextStopLeg, "leg_order")
                            OR !isNumeric(nextStopLeg.leg_order)
                            OR val(nextStopLeg.leg_order) NEQ routeMapActiveLegOrder
                        )
                    ) {
                        continue;
                    }
                    if (trim(toString(nextStopLeg.end_name)) NEQ nextStopLabelVal) {
                        continue;
                    }
                    nextStopEtaMinutes = 0;
                    nextStopCumulativeMinutes = 0;
                    activeLegEtaMinutes = 0;
                    activeLegEtaBaseDt = nextStopEtaBaseDt;

                    if (structKeyExists(nextStopLeg, "cumulative_hours") AND isNumeric(nextStopLeg.cumulative_hours) AND val(nextStopLeg.cumulative_hours) GTE 0) {
                        nextStopCumulativeMinutes = int(round(val(nextStopLeg.cumulative_hours) * 60));
                    }
                    if (structKeyExists(nextStopLeg, "hours") AND isNumeric(nextStopLeg.hours) AND val(nextStopLeg.hours) GTE 0) {
                        activeLegEtaMinutes = int(round(val(nextStopLeg.hours) * 60));
                    }
                    currentLegStartedAt = "";
                    currentLegStartedAtLocal = "";
                    priorLegCompletedAt = "";
                    priorLegCompletedAtLocal = "";
                    if (structKeyExists(nextStopLeg, "leg_order") AND isNumeric(nextStopLeg.leg_order) AND val(nextStopLeg.leg_order) GT 0) {
                        qLegTiming = queryExecute(
                            "SELECT
                                curr.leg_started_at AS current_leg_started_at,
                                COALESCE(CONVERT_TZ(curr.leg_started_at, 'UTC', :targetTimeZone), curr.leg_started_at) AS current_leg_started_at_local,
                                prev.completed_at AS prior_leg_completed_at,
                                COALESCE(CONVERT_TZ(prev.completed_at, 'UTC', :targetTimeZone), prev.completed_at) AS prior_leg_completed_at_local
                             FROM route_instance_leg_progress curr
                             LEFT JOIN route_instance_leg_progress prev
                               ON prev.route_instance_id = curr.route_instance_id
                              AND prev.user_id = curr.user_id
                              AND prev.leg_order = curr.leg_order - 1
                             WHERE curr.route_instance_id = :routeInstanceId
                               AND curr.user_id = :ownerUserId
                               AND curr.leg_order = :legOrder
                             LIMIT 1",
                            {
                                routeInstanceId = { value = routeInstanceIdVal, cfsqltype = "cf_sql_integer" },
                                ownerUserId = { value = streamRow.owner_user_id, cfsqltype = "cf_sql_integer" },
                                legOrder = { value = val(nextStopLeg.leg_order), cfsqltype = "cf_sql_integer" },
                                targetTimeZone = { value = (len(departureTimeZoneVal) ? departureTimeZoneVal : "UTC"), cfsqltype = "cf_sql_varchar" }
                            },
                            { datasource = ds }
                        );
                        if (qLegTiming.recordCount GT 0) {
                            if (!isNull(qLegTiming.current_leg_started_at[1]) AND isDate(qLegTiming.current_leg_started_at[1])) {
                                currentLegStartedAt = qLegTiming.current_leg_started_at[1];
                                currentLegStartedAtLocal = currentLegStartedAt;
                                if (
                                    ucase(storedDepartureTimeZoneVal) EQ "UTC"
                                    AND len(departureTimeZoneVal)
                                    AND ucase(departureTimeZoneVal) NEQ "UTC"
                                    AND !isNull(qLegTiming.current_leg_started_at_local[1])
                                    AND isDate(qLegTiming.current_leg_started_at_local[1])
                                ) {
                                    currentLegStartedAtLocal = qLegTiming.current_leg_started_at_local[1];
                                }
                            }
                            if (!isNull(qLegTiming.prior_leg_completed_at[1]) AND isDate(qLegTiming.prior_leg_completed_at[1])) {
                                priorLegCompletedAt = qLegTiming.prior_leg_completed_at[1];
                                priorLegCompletedAtLocal = priorLegCompletedAt;
                                if (
                                    ucase(storedDepartureTimeZoneVal) EQ "UTC"
                                    AND len(departureTimeZoneVal)
                                    AND ucase(departureTimeZoneVal) NEQ "UTC"
                                    AND !isNull(qLegTiming.prior_leg_completed_at_local[1])
                                    AND isDate(qLegTiming.prior_leg_completed_at_local[1])
                                ) {
                                    priorLegCompletedAtLocal = qLegTiming.prior_leg_completed_at_local[1];
                                }
                            }
                        }
                    }

                    if (nextStopCumulativeMinutes GT 0) {
                        plannedNextStopEtaDt = dateAdd("n", nextStopCumulativeMinutes, nextStopEtaBaseDt);
                        if (tripStarted AND storedOvernightPauseMinutes GT 0) {
                            plannedNextStopEtaDt = dateAdd("n", storedOvernightPauseMinutes, plannedNextStopEtaDt);
                        }
                    }

                    hasValidCurrentLegStart = (tripStarted AND isDate(currentLegStartedAt));
                    if (hasValidCurrentLegStart AND isDate(scheduledDepartureRawDt)) {
                        hasValidCurrentLegStart = (dateCompare(currentLegStartedAt, scheduledDepartureRawDt, "s") GTE 0);
                    }
                    hasValidPriorLegCompletion = (tripStarted AND isDate(priorLegCompletedAt));
                    if (hasValidPriorLegCompletion AND isDate(scheduledDepartureRawDt)) {
                        hasValidPriorLegCompletion = (dateCompare(priorLegCompletedAt, scheduledDepartureRawDt, "s") GTE 0);
                    }

                    resumeDayStartDt = "";
                    resumeAnchorDt = "";
                    useResumedDayStartEtaBase = false;
                    if (tripStarted AND storedOvernightPauseMinutes GT 0 AND hasOperationalCheckIn AND !hasActualResumeAt AND isDate(checkedInAtVal)) {
                        resumeDayStartDt = createDateTime(
                            year(checkedInAtVal),
                            month(checkedInAtVal),
                            day(checkedInAtVal),
                            localDayStartRule.local_day_start_hour,
                            localDayStartRule.local_day_start_minute,
                            localDayStartRule.local_day_start_second
                        );
                        if (hasValidCurrentLegStart) {
                            resumeAnchorDt = currentLegStartedAtLocal;
                        } else if (hasValidPriorLegCompletion) {
                            resumeAnchorDt = priorLegCompletedAtLocal;
                        }
                        if (
                            isDate(resumeAnchorDt)
                            AND isDate(resumeDayStartDt)
                            AND dateCompare(resumeAnchorDt, resumeDayStartDt, "s") LT 0
                            AND dateCompare(checkedInAtVal, resumeDayStartDt, "s") GTE 0
                        ) {
                            activeLegEtaBaseDt = resumeDayStartDt;
                            useResumedDayStartEtaBase = true;
                        }
                    }

                    if (!useResumedDayStartEtaBase AND tripStarted AND isOvernightCheckIn AND hasOperationalCheckIn AND len(departureTimeZoneVal)) {
                        try {
                            if (isDate(expectedCheckInDt)) {
                                nextMorningResumeDt = expectedCheckInDt;
                            } else {
                                nextMorningResumeDt = dateAdd("d", 1, checkedInAtVal);
                                nextMorningResumeDt = createDateTime(
                                    year(nextMorningResumeDt),
                                    month(nextMorningResumeDt),
                                    day(nextMorningResumeDt),
                                    localDayStartRule.local_day_start_hour,
                                    localDayStartRule.local_day_start_minute,
                                    localDayStartRule.local_day_start_second
                                );
                            }
                            if (isDate(nextMorningResumeDt)) {
                                activeLegEtaBaseDt = nextMorningResumeDt;
                            }
                            if (isOvernightCheckIn AND hasOperationalCheckIn AND isDate(checkedInAtVal)) {
                                overnightPauseMinutes = dateDiff("n", checkedInAtVal, nextMorningResumeDt);
                                if (storedOvernightPauseMinutes LTE 0 AND isDate(plannedNextStopEtaDt) AND overnightPauseMinutes GT 0) {
                                    plannedNextStopEtaDt = dateAdd("n", overnightPauseMinutes, plannedNextStopEtaDt);
                                }
                            }
                        } catch (any overnightEtaErr) {
                            if (hasValidCurrentLegStart) {
                                activeLegEtaBaseDt = currentLegStartedAtLocal;
                            } else if (hasValidPriorLegCompletion) {
                                activeLegEtaBaseDt = priorLegCompletedAtLocal;
                            }
                        }
                    } else if (
                        !useResumedDayStartEtaBase
                        AND hasActualResumeAt
                        AND isDate(actualResumeAt)
                        AND isDate(actualResumeAtLocal)
                        AND (
                            !hasValidCurrentLegStart
                            OR !isDate(currentLegStartedAt)
                            OR dateCompare(currentLegStartedAt, actualResumeAt, "s") LT 0
                        )
                    ) {
                        activeLegEtaBaseDt = actualResumeAtLocal;
                    } else if (!useResumedDayStartEtaBase AND hasValidCurrentLegStart) {
                        activeLegEtaBaseDt = currentLegStartedAtLocal;
                    } else if (!useResumedDayStartEtaBase AND hasValidPriorLegCompletion) {
                        activeLegEtaBaseDt = priorLegCompletedAtLocal;
                    }

                    usingActiveLegEta = false;
                    if (activeLegEtaMinutes GT 0 AND isDate(activeLegEtaBaseDt)) {
                        usingActiveLegEta = true;
                        nextStopEtaMinutes = activeLegEtaMinutes;
                        nextStopEtaDt = dateAdd("n", activeLegEtaMinutes, activeLegEtaBaseDt);
                    } else {
                        nextStopEtaMinutes = nextStopCumulativeMinutes;
                        nextStopEtaDt = plannedNextStopEtaDt;
                    }
                    if (usingActiveLegEta AND tripStarted AND storedManualDelayMinutes GT 0 AND isDate(nextStopEtaDt)) {
                        nextStopEtaDt = dateAdd("n", storedManualDelayMinutes, nextStopEtaDt);
                    }
                    if (isDate(nextStopEtaDt)) {
                        etaLabel = dateTimeFormat(nextStopEtaDt, "mmm d, yyyy h:nn tt");
                        etaUtc = formatUtcInstantFromLocalTime(nextStopEtaDt, departureTimeZoneVal);
                    }
                    break;
                }
            }

            timelineSummary = (
                isStruct(followTimeline) AND structKeyExists(followTimeline, "summary") AND isStruct(followTimeline.summary)
                    ? followTimeline.summary
                    : {}
            );
            timelineTotalNm = (
                structKeyExists(timelineSummary, "total_nm") AND isNumeric(timelineSummary.total_nm)
                    ? val(timelineSummary.total_nm)
                    : 0
            );
            timelineTotalHours = (
                structKeyExists(timelineSummary, "total_hours") AND isNumeric(timelineSummary.total_hours)
                    ? val(timelineSummary.total_hours)
                    : 0
            );
            timelineEffectiveSpeedKn = (
                structKeyExists(timelineSummary, "effective_speed_kn") AND isNumeric(timelineSummary.effective_speed_kn)
                    ? val(timelineSummary.effective_speed_kn)
                    : 0
            );
            actualResumeLegOrder = routeMapActiveLegOrder;
            if (hasActualResumeAt AND actualResumeLegOrder LTE 0 AND structKeyExists(timelineSummary, "completed_legs") AND isNumeric(timelineSummary.completed_legs)) {
                actualResumeLegOrder = val(timelineSummary.completed_legs) + 1;
            }

            // Canonical projection is used only for streams with real canonical segments; legacy diagnostics remain fallback-only.
            try {
                followProjection = createTripProgressProjectionService().getProjectionForStream(streamRow.id);
            } catch (any followProjectionErr) {
                followProjection = {};
            }
            if (
                isStruct(followProjection)
                AND structKeyExists(followProjection, "authorityWarnings")
                AND isArray(followProjection.authorityWarnings)
            ) {
                for (followProjectionWarningIndex = 1; followProjectionWarningIndex LTE arrayLen(followProjection.authorityWarnings); followProjectionWarningIndex++) {
                    followProjectionWarning = followProjection.authorityWarnings[followProjectionWarningIndex];
                    if (!isStruct(followProjectionWarning) OR !structKeyExists(followProjectionWarning, "code")) {
                        continue;
                    }
                    followProjectionWarningCode = trim(toString(followProjectionWarning.code));
                    if (listFindNoCase("MULTIPLE_OPEN_SEGMENTS,CANONICAL_ACTIVITY_SEGMENT_TABLE_MISSING,CANONICAL_EVENT_TABLE_MISSING", followProjectionWarningCode)) {
                        canonicalFollowProjectionBlocked = true;
                        break;
                    }
                }
            }
            useCanonicalFollowProjection = (
                isStruct(followProjection)
                AND structKeyExists(followProjection, "success")
                AND followProjection.success
                AND structKeyExists(followProjection, "activitySegments")
                AND isArray(followProjection.activitySegments)
                AND arrayLen(followProjection.activitySegments) GT 0
                AND structKeyExists(followProjection, "eventLedger")
                AND isStruct(followProjection.eventLedger)
                AND structKeyExists(followProjection.eventLedger, "count")
                AND val(followProjection.eventLedger.count) GT 0
                AND structKeyExists(followProjection, "todayProgress")
                AND isStruct(followProjection.todayProgress)
                AND structKeyExists(followProjection.todayProgress, "authority")
                AND lCase(trim(toString(followProjection.todayProgress.authority))) EQ "canonical"
                AND !canonicalFollowProjectionBlocked
            );
            if (useCanonicalFollowProjection) {
                if (structKeyExists(followProjection.todayProgress, "milesTodayNm") AND isNumeric(followProjection.todayProgress.milesTodayNm)) {
                    milesTodayNm = val(followProjection.todayProgress.milesTodayNm);
                }
                if (structKeyExists(followProjection.todayProgress, "hoursToday") AND isNumeric(followProjection.todayProgress.hoursToday)) {
                    hoursTodayTotal = val(followProjection.todayProgress.hoursToday);
                }
                if (
                    structKeyExists(followProjection, "etaProjection")
                    AND isStruct(followProjection.etaProjection)
                    AND structKeyExists(followProjection.etaProjection, "available")
                    AND followProjection.etaProjection.available
                    AND structKeyExists(followProjection.etaProjection, "etaUtc")
                    AND len(trim(toString(followProjection.etaProjection.etaUtc)))
                ) {
                    followProjectionEtaUtc = trim(toString(followProjection.etaProjection.etaUtc));
                    etaUtc = followProjectionEtaUtc;
                    etaLabel = "";
                    followProjectionEtaLocalInput = replace(replace(followProjectionEtaUtc, "T", " ", "one"), "Z", "", "one");
                    etaLabel = formatVoyageUtcDisplayLabel(followProjectionEtaUtc, departureTimeZoneVal);
                }
                if (
                    structKeyExists(followProjection, "currentLeg")
                    AND isStruct(followProjection.currentLeg)
                    AND structKeyExists(followProjection.currentLeg, "routeLegOrder")
                    AND isNumeric(followProjection.currentLeg.routeLegOrder)
                    AND structKeyExists(followProjection, "currentLegProgress")
                    AND isStruct(followProjection.currentLegProgress)
                    AND structKeyExists(followProjection.currentLegProgress, "percentComplete")
                    AND isNumeric(followProjection.currentLegProgress.percentComplete)
                    AND isStruct(followTimeline)
                    AND structKeyExists(followTimeline, "legs")
                    AND isArray(followTimeline.legs)
                ) {
                    followProjectionLegOrder = val(followProjection.currentLeg.routeLegOrder);
                    for (followProjectionLegIndex = 1; followProjectionLegIndex LTE arrayLen(followTimeline.legs); followProjectionLegIndex++) {
                        timelineLeg = followTimeline.legs[followProjectionLegIndex];
                        if (
                            !isStruct(timelineLeg)
                            OR !structKeyExists(timelineLeg, "leg_order")
                            OR !isNumeric(timelineLeg.leg_order)
                            OR val(timelineLeg.leg_order) NEQ followProjectionLegOrder
                        ) {
                            continue;
                        }
                        if (!structKeyExists(timelineLeg, "progress") OR !isStruct(timelineLeg.progress)) {
                            timelineLeg.progress = {};
                        }
                        timelineLeg.progress.percent_complete = val(followProjection.currentLegProgress.percentComplete);
                        if (structKeyExists(followProjection.currentLeg, "startedAtUtc") AND len(trim(toString(followProjection.currentLeg.startedAtUtc)))) {
                            timelineLeg.progress.last_update_ts = trim(toString(followProjection.currentLeg.startedAtUtc));
                        }
                        followTimeline.legs[followProjectionLegIndex] = timelineLeg;
                        break;
                    }
                }
            }

            if (isStruct(followTimeline) AND structKeyExists(followTimeline, "legs") AND isArray(followTimeline.legs)) {
                for (i = 1; i LTE arrayLen(followTimeline.legs); i++) {
                    timelineLeg = followTimeline.legs[i];
                    if (!isStruct(timelineLeg)) {
                        continue;
                    }
                    timelineLegDistanceNm = (
                        structKeyExists(timelineLeg, "dist_nm") AND isNumeric(timelineLeg.dist_nm)
                            ? val(timelineLeg.dist_nm)
                            : 0
                    );
                    timelineLegProgressPct = (
                        structKeyExists(timelineLeg, "progress")
                        AND isStruct(timelineLeg.progress)
                        AND structKeyExists(timelineLeg.progress, "percent_complete")
                        AND isNumeric(timelineLeg.progress.percent_complete)
                            ? val(timelineLeg.progress.percent_complete)
                            : 0
                    );

                    if (timelineLegProgressPct GTE 100) {
                        completedMilesSoFarNm += timelineLegDistanceNm;
                    } else if (nextStopRemainingNm LT 0) {
                        nextStopRemainingNm = timelineLegDistanceNm;
                    }
                }
            }

            completedMilesSoFarNm = roundTo2(completedMilesSoFarNm);
            if (timelineTotalNm LTE 0 AND structKeyExists(routeMap, "total_nm") AND isNumeric(routeMap.total_nm)) {
                timelineTotalNm = val(routeMap.total_nm);
            }
            milesLeftNm = max(0, roundTo2(timelineTotalNm - completedMilesSoFarNm));
            if (nextStopRemainingNm LT 0) {
                nextStopRemainingNm = 0;
            } else {
                nextStopRemainingNm = roundTo2(nextStopRemainingNm);
            }

            hasActiveTrip = (len(trim(statusLabel)) AND statusLabel NEQ "Status Unavailable");
            hasNextStop = len(nextStopLabelVal);
            if (isDate(checkedInAtVal)) {
                hoursSinceLastCheckin = roundTo2(dateDiff("n", checkedInAtVal, confidenceNowDt) / 60);
                if (hoursSinceLastCheckin LT 0) {
                    hoursSinceLastCheckin = 0;
                }
            }

            if (
                qPlan.recordCount GT 0
                AND !isNull(qPlan.departureTime[1])
                AND isDate(qPlan.departureTime[1])
            ) {
                elapsedTripMinutes = dateDiff("n", qPlan.departureTime[1], confidenceNowDt);
                if (elapsedTripMinutes LT 0) {
                    elapsedTripMinutes = 0;
                }
                elapsedTripHours = roundTo2(elapsedTripMinutes / 60);
                comparisonElapsedHours = elapsedTripHours;
                if (timelineTotalHours GT 0 AND comparisonElapsedHours GT timelineTotalHours) {
                    comparisonElapsedHours = timelineTotalHours;
                }

                if (timelineTotalNm GT 0 AND timelineTotalHours GT 0 AND comparisonElapsedHours GT 0) {
                    expectedMilesByNowNm = roundTo2(timelineTotalNm * (comparisonElapsedHours / timelineTotalHours));
                }

                if (completedMilesSoFarNm GT 0 AND elapsedTripHours GT 0) {
                    achievedPaceKn = roundTo2(completedMilesSoFarNm / elapsedTripHours);
                    progressMilesForConfidenceNm = completedMilesSoFarNm;
                } else if (timelineEffectiveSpeedKn GT 0 AND elapsedTripHours GT 0) {
                    achievedPaceKn = roundTo2(timelineEffectiveSpeedKn);
                    progressMilesForConfidenceNm = min(timelineTotalNm, roundTo2(achievedPaceKn * comparisonElapsedHours));
                }

                if (expectedMilesByNowNm GT 0) {
                    progressRatio = progressMilesForConfidenceNm / expectedMilesByNowNm;
                }

                if (isDate(plannedNextStopEtaDt) AND achievedPaceKn GT 0 AND !isOvernightCheckIn) {
                    projectedNextStopMinutes = int(round((nextStopRemainingNm / achievedPaceKn) * 60));
                    projectedNextStopEtaDt = dateAdd("n", projectedNextStopMinutes, confidenceNowDt);
                }
            }

            if (hoursSinceLastCheckin GTE 0) {
                if (isOvernightCheckIn) {
                    hasFreshSignal = (hoursSinceLastCheckin LTE 18);
                    hasRecentSignal = (hoursSinceLastCheckin LTE 18);
                } else {
                    hasFreshSignal = (hoursSinceLastCheckin LTE 6);
                    hasRecentSignal = (hoursSinceLastCheckin LTE 12);
                }
            }

            if (isDate(plannedNextStopEtaDt) AND isDate(projectedNextStopEtaDt)) {
                etaUnknown = false;
                etaDriftHours = roundTo2(abs(dateDiff("n", projectedNextStopEtaDt, plannedNextStopEtaDt)) / 60);
            }

            severeProgressMismatch = (
                progressRatio GT 0
                AND (progressRatio LT 0.5 OR progressRatio GT 1.5)
            );
            newlyStartedTrip = (hasRecentSignal AND completedMilesSoFarNm LTE 0);

            if (
                !hasActiveTrip
                OR !hasNextStop
                OR !isDate(plannedNextStopEtaDt)
                OR (!isOvernightCheckIn AND hoursSinceLastCheckin GT 12)
                OR (!etaUnknown AND etaDriftHours GT 6)
                OR (
                    hoursSinceLastCheckin GT (isOvernightCheckIn ? 18 : 12)
                    AND severeProgressMismatch
                )
            ) {
                tripConfidenceLabel = "Low";
            } else if (
                hasFreshSignal
                AND (
                    (!etaUnknown AND etaDriftHours LTE 2)
                    OR (etaUnknown AND hasFreshSignal)
                )
            ) {
                tripConfidenceLabel = "High";
            } else if (
                hasActiveTrip
                AND hasNextStop
                AND (
                    (!isOvernightCheckIn AND hoursSinceLastCheckin GT 6 AND hoursSinceLastCheckin LTE 12)
                    OR (isOvernightCheckIn AND hoursSinceLastCheckin GT 18)
                    OR (!etaUnknown AND etaDriftHours GT 2 AND etaDriftHours LTE 6)
                    OR (etaUnknown AND hasRecentSignal)
                    OR newlyStartedTrip
                    OR severeProgressMismatch
                )
            ) {
                tripConfidenceLabel = "Moderate";
            } else {
                tripConfidenceLabel = "Moderate";
            }

	            tSectionStart = getTickCount();
	            if (
	                routeInstanceIdVal GT 0
	                AND structKeyExists(routeMap, "active_leg_order")
	                AND val(routeMap.active_leg_order) GT 0
            ) {
                try {
                    weatherComponent = createObject("component", "fpw.api.v1.weather");
                    weatherComponentPath = "fpw.api.v1.weather";
                } catch (any weatherComponentErrA) {
                    try {
                        weatherComponent = createObject("component", "api.v1.weather");
                        weatherComponentPath = "api.v1.weather";
                    } catch (any weatherComponentErrB) {
                        weatherComponent = "";
                        weatherComponentPath = "";
                    }
                }

                if (isObject(weatherComponent) AND len(weatherComponentPath)) {
                    pointDefs = {
                        "start"={
                            "lat"=(structKeyExists(routeMap, "active_leg_start_lat") ? routeMap.active_leg_start_lat : ""),
                            "lng"=(structKeyExists(routeMap, "active_leg_start_lng") ? routeMap.active_leg_start_lng : "")
                        },
                        "end"={
                            "lat"=(structKeyExists(routeMap, "active_leg_end_lat") ? routeMap.active_leg_end_lat : ""),
                            "lng"=(structKeyExists(routeMap, "active_leg_end_lng") ? routeMap.active_leg_end_lng : "")
                        }
                    };

                    for (pointKey in pointDefs) {
                        pointDef = pointDefs[pointKey];
                        pointOut = {
                            "available"=false,
                            "summary"="",
                            "alerts_count"=0,
                            "top_alert_severity"="",
                            "forecast_short"="",
                            "wind_speed"="",
                            "wind_direction"="",
                            "wave_height_ft"="",
                            "visibility_mi"=""
                        };

                        if (
                            !structKeyExists(pointDef, "lat")
                            OR !structKeyExists(pointDef, "lng")
                            OR !isNumeric(pointDef.lat)
                            OR !isNumeric(pointDef.lng)
                        ) {
                            legWeather[pointKey] = pointOut;
                            continue;
                        }

                        roundedLat = round(val(pointDef.lat) * 1000) / 1000;
                        roundedLng = round(val(pointDef.lng) * 1000) / 1000;
                        pointCacheKey = "lat=" & numberFormat(roundedLat, "0.000") & ":lng=" & numberFormat(roundedLng, "0.000");

                        if (!structKeyExists(pointResults, pointCacheKey)) {
                            try {
                                pointResults[pointCacheKey] = weatherComponent.getFollowConditionsSummary(val(pointDef.lat), val(pointDef.lng));
                            } catch (any pointWeatherErr) {
                                pointResults[pointCacheKey] = { "SUCCESS"=false, "MESSAGE"=pointWeatherErr.message };
                            }
                        }

                        pointRaw = (
                            structKeyExists(pointResults, pointCacheKey) AND isStruct(pointResults[pointCacheKey])
                                ? duplicate(pointResults[pointCacheKey])
                                : {}
                        );

                        if (structKeyExists(pointRaw, "SUCCESS") AND pointRaw.SUCCESS) {
                            pointOut.available = true;
                            pointSummary = (structKeyExists(pointRaw, "SUMMARY") ? trim(toString(pointRaw.SUMMARY)) : "");
                            pointOut.summary = pointSummary;
                            pointOut.forecast_short = (structKeyExists(pointRaw, "FORECAST_SHORT") ? trim(toString(pointRaw.FORECAST_SHORT)) : "");
                            pointOut.wind_speed = (structKeyExists(pointRaw, "WIND_SPEED") ? trim(toString(pointRaw.WIND_SPEED)) : "");
                            pointOut.wind_direction = (structKeyExists(pointRaw, "WIND_DIRECTION") ? trim(toString(pointRaw.WIND_DIRECTION)) : "");
                        }

                        legWeather[pointKey] = pointOut;
                    }

                    worsePointKey = "";
                    if (legWeather.end.available) {
                        worsePointKey = "end";
                    } else if (legWeather.start.available) {
                        worsePointKey = "start";
                    }

                    if (len(worsePointKey) AND structKeyExists(legWeather, worsePointKey)) {
                        worsePoint = legWeather[worsePointKey];
                        legWeather.conditions.available = true;
                        if (legWeather.start.available AND legWeather.end.available) {
                            legWeather.conditions.headline = "Current leg endpoint conditions";
                        } else if (worsePointKey EQ "end") {
                            legWeather.conditions.headline = "Next-stop point conditions";
                        } else {
                            legWeather.conditions.headline = "Leg-start point conditions";
                        }
                        legWeather.conditions.summary = (len(worsePoint.summary) ? worsePoint.summary : "No active hazards reported");
                        legWeather.conditions.meta = (
                            legWeather.start.available AND legWeather.end.available
                                ? "Based on current leg start and next stop point weather."
                                : "Based on available current leg point weather."
                        );
	                    }
	                }
	            }
	            tWeather = getTickCount() - tSectionStart;

            topCards = {
                "status"=statusLabel,
                "voyage_progress_status"=voyageProgressStatusLabel,
                "voyage_progress_status_variant"=voyageProgressStatusVariant,
                "last_checkin"=lastCheckinLabel,
                "last_checkin_utc"=lastCheckinUtc,
                "location_label"=(len(routeMap.location_label) ? routeMap.location_label : "n/a"),
                "next_stop"=(len(routeMap.next_stop_label) ? routeMap.next_stop_label : "n/a"),
                "eta"=etaLabel,
                "eta_utc"=etaUtc,
                "conditions"="No active hazards reported"
            };

            pinned = {
                "miles"=routeTotalMiles,
                "miles_today_nm"=(isNumeric(milesTodayNm) ? milesTodayNm : ""),
                "hours_today"=(isNumeric(hoursTodayTotal) ? hoursTodayTotal : ""),
                "days"=routeTotalDays,
                "locks"=routeTotalLocks,
                "wildlife"=wildlifeCount,
                "updated_label"=lastCheckinLabel
            };

            body = {
                "page_subtitle"="Follow along in real time: location, progress, updates, comments, and trip confidence.",
                "journey_subtitle"="Current leg is active.",
                "journey_departed_value"=(qPlan.recordCount GT 0 AND !isNull(qPlan.departing[1]) ? trim(toString(qPlan.departing[1])) : ""),
                "journey_departed_meta"=(isDate(journeyDepartedDt) ? dateTimeFormat(journeyDepartedDt, "mmm d, yyyy h:nn tt") : ""),
                "journey_departed_meta_utc"=(isDate(journeyDepartedDt) ? formatUtcDate(journeyDepartedDt) : ""),
                "journey_checkin_value"=(len(actualCheckInLabel) ? "Checked in at " & actualCheckInLabel : "Checked in at --"),
                "journey_checkin_meta"=(isOvernightCheckIn ? "Arrived and secure for the night. Next update expected tomorrow morning." : elapsedCheckInLabel),
                "card_status_copy"=voyageProgressStatusCopy,
                "voyage_progress_status_copy"=voyageProgressStatusCopy,
                "card_location_copy"="Heading toward the current active route target.",
                "card_destination_copy"="Next major stop and expected overnight destination.",
                "card_arrival_copy"="Approximate based on current pace, route progress, and last update.",
                "card_conditions_copy"="Current trip conditions and caution state.",
                "trip_summary_confidence"="Tracking confidence: " & tripConfidenceLabel,
                "trip_summary_mode"="Trip mode: Route-based monitoring",
                "trip_summary_safety"="Safety state: Normal",
                "family_confidence_subtitle"="Built to reassure viewers with plain-language trip and safety status.",
                "timeline_next_update"="Within 1 hr"
            };

            out.SUCCESS = true;
            out.MESSAGE = "OK";
            out.stream = {
                "id"=streamRow.id,
                "stream_id"=streamRow.id,
                "title"=streamTitle,
                "status"=statusLabel,
                "privacy_mode"=streamRow.privacy_mode,
                "allow_interactions"=(streamRow.allow_interactions GT 0),
                "slug"=streamRow.slug,
                "is_owner"=isOwner,
                "owner_user_id"=streamRow.owner_user_id
            };
            out["sidebar"] = {
                "viewer_count"=viewerCountVal,
                "vessel_name"=vesselNameVal,
                "last_checkin"=(len(actualCheckInLabel) ? actualCheckInLabel : ""),
                "last_checkin_utc"=actualCheckInUtc,
                "privacy_label"=privacyLabel,
                "monitoring_summary"=monitoringSummary,
                "monitor_state_text_html"=monitorStateTextHtml,
                "monitor_state_label"=monitorStateLabel
            };
            out.topCards = topCards;
            out.map = {
                "routeGeo"=routeMap.route_geo,
                "pins"=routeMap.pins,
                "current"=routeMap.current
            };
	            out.legWeather = legWeather;
	            out.pinned = pinned;
            out.timeline = followTimeline;
            out.body = body;
            out.publicAuthority = publicAuthority;
            if (!tripStarted) {
                out.stream.status = "Scheduled";
                out.topCards.status = "Scheduled";
                out.topCards.voyage_progress_status = "Scheduled";
                out.topCards.voyage_progress_status_variant = "good";
                out.topCards.last_checkin = "";
                out.topCards.last_checkin_utc = "";
                out.topCards.conditions = "Monitoring pending";
                out.pinned.updated_label = "";
                out.pinned.miles_today_nm = "";
                out.sidebar.last_checkin = "";
                out.sidebar.last_checkin_utc = "";
                out.sidebar.monitoring_summary = "Monitoring starts at scheduled departure";
                out.sidebar.monitor_state_text_html = "<strong>Monitoring pending</strong><br />The trip begins at the scheduled departure time.";
                out.sidebar.monitor_state_label = "Pending";
                out.body.page_subtitle = "Follow the scheduled departure and planned route timing before the trip is underway.";
                out.body.journey_subtitle = "Scheduled departure pending.";
                out.body.journey_checkin_meta = "Monitoring begins at scheduled departure.";
                out.body.card_status_copy = "Monitoring starts at the scheduled departure time.";
                out.body.voyage_progress_status_copy = out.body.card_status_copy;
                out.body.card_location_copy = "Departure is scheduled and the trip has not started yet.";
                out.body.card_destination_copy = "First planned stop after scheduled departure.";
                out.body.card_arrival_copy = "Based on scheduled departure time plus planned leg duration.";
                out.body.trip_summary_confidence = "Tracking confidence: Scheduled departure pending";
                out.body.trip_summary_mode = "Trip mode: Scheduled departure pending";
                out.body.trip_summary_safety = "Safety state: Monitoring not started";
                out.body.family_confidence_subtitle = "The trip is scheduled and has not started yet.";
                out.body.timeline_next_update = "At scheduled departure";
                if (
                    isStruct(out.timeline)
                    AND structKeyExists(out.timeline, "summary")
                    AND isStruct(out.timeline.summary)
                ) {
                    out.timeline.summary.effective_speed_kn = "";
                }
            } else if (!hasOperationalCheckIn) {
                out.topCards.last_checkin = "";
                out.topCards.last_checkin_utc = "";
                out.pinned.updated_label = "";
                out.sidebar.last_checkin = "";
                out.sidebar.last_checkin_utc = "";
                out.body.journey_checkin_meta = "Awaiting first check-in after departure.";
            } else if (awaitingDepartureState) {
                out.topCards.eta = "--";
                out.topCards.eta_utc = "";
                out.body.journey_subtitle = "Awaiting departure from the current stop.";
                out.body.journey_checkin_meta = "Arrived at the current stop. The next leg has not started yet.";
                out.body.card_location_copy = "The trip is paused at the current stop and awaiting the next departure.";
                out.body.card_destination_copy = "Next planned stop after the next leg actually starts.";
                out.body.card_arrival_copy = "ETA becomes available once the next leg starts.";
                out.body.trip_summary_mode = "Trip mode: Awaiting departure";
                out.body.timeline_next_update = "At next departure";
            }
	            writeLog(file="fpw-bootstrap-timing", text="[FPW_BOOTSTRAP_TIMING] total=" & (getTickCount() - tTotalStart) & "ms map=" & tMap & "ms timeline=" & tTimeline & "ms weather=" & tWeather & "ms", type="information");
	            return out;
	        </cfscript>
		    </cffunction>

    <cffunction name="getActiveCruiseHeroCanonical" access="public" returntype="struct" output="false">
        <cfargument name="currentUserId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "MESSAGE"="Unable to load canonical Active Cruise hero values.",
                "heroVoyageStatus"="Status Unavailable",
                "heroVoyageStatusVariant"="good",
                "heroNextStop"="",
                "heroEta"="--",
                "heroEtaUtc"="",
                "heroTripStartUtc"="",
                "legArrivalUtc"="",
                "heroLastCheckIn"="--",
                "heroLastCheckInUtc"="",
                "manualDelayMinutesTotal"=0,
                "canonicalProjectionAvailable"=false,
                "projectionAuthority"="",
                "projectionWarnings"=[],
                "etaProjection"={},
                "todayProgress"={},
                "currentLegProgress"={},
                "routeTimeline"={ "available"=false }
            };
            var canonicalPlan = {};
            var ds = resolveDatasource();
            var qPlan = queryNew("");
            var routeMap = {};
            var followTimeline = { "summary"={}, "legs"=[], "meta"={} };
            var statusLabel = "Status Unavailable";
            var statusVariant = "good";
            var checkedInAtVal = "";
            var expectedCheckInDt = "";
            var actualCheckInLabel = "";
            var actualCheckInUtc = "";
            var checkInContextVal = "";
            var isOvernightCheckIn = false;
            var actualResumeAt = "";
            var actualResumeAtLocal = "";
            var hasActualResumeAt = false;
            var storedOvernightPauseMinutes = 0;
            var storedManualDelayMinutes = 0;
            var departureTimeZoneVal = "";
            var dailyStartLocalTimeVal = "";
            var storedDepartureTimeZoneVal = "";
            var returnTimeZoneVal = "";
            var storedReturnTimeZoneVal = "";
            var nextStopLabelVal = "";
            var nextStopEtaBaseDt = "";
            var nextStopEtaDt = "";
            var nextStopCumulativeMinutes = 0;
            var activeLegEtaBaseDt = "";
            var activeLegEtaMinutes = 0;
            var overnightPauseMinutes = 0;
            var nextMorningResumeDt = "";
            var localDayStartRule = loadOvernightTimingRule();
            var plannedNextStopEtaDt = "";
            var nextStopLeg = {};
            var qLegTiming = queryNew("");
            var currentLegStartedAt = "";
            var priorLegCompletedAt = "";
            var etaLabel = "";
            var etaUtc = "";
            var heroTripStartUtc = "";
            var legArrivalUtc = "";
            var tripStartLocalDt = "";
            var legArrivalLocalDt = "";
            var qLocalDeparture = queryNew("");
            var qLocalTripStart = queryNew("");
            var qLocalLegArrival = queryNew("");
            var qActualResumeLocal = queryNew("");
            var scheduledDepartureRawDt = "";
            var hasOperationalCheckIn = false;
            var hasValidCurrentLegStart = false;
            var hasValidPriorLegCompletion = false;
            var tripStartState = {};
            var tripStarted = true;
            var routeMapActiveLegOrder = 0;
            var awaitingDepartureState = false;
            var monitorStateVal = "";
            var lastCheckinStatusVal = "";
            var usingActiveLegEta = false;
            var activeCruiseProjection = {};
            var canonicalActiveCruiseProjectionBlocked = false;
            var useCanonicalActiveCruiseProjection = false;
            var useRouteTimelineActiveCruiseProjection = false;
            var activeCruiseRouteTimelineAuthority = "";
            var activeCruiseProjectionWarningIndex = 0;
            var activeCruiseProjectionWarning = {};
            var activeCruiseProjectionWarningCode = "";
            var activeCruiseProjectionEtaUtc = "";
            var activeCruiseProjectionEtaLocalInput = "";
            var qActiveCruiseProjectionEtaLocal = queryNew("");
            var i = 0;

            if (arguments.currentUserId LTE 0 OR arguments.floatPlanId LTE 0) {
                out.MESSAGE = "Active Cruise requires a valid owner and float plan.";
                return out;
            }

            canonicalPlan = resolveCanonicalActiveFloatPlan(arguments.currentUserId, arguments.floatPlanId);
            if (!canonicalPlan.SUCCESS) {
                out.MESSAGE = canonicalPlan.MESSAGE;
                return out;
            }

            tripStartState = ensureScheduledPlanOperationalStart(arguments.currentUserId, arguments.floatPlanId);
            if (
                structKeyExists(tripStartState, "SUCCESS")
                AND tripStartState.SUCCESS
                AND structKeyExists(tripStartState, "TRIP_STARTED")
            ) {
                tripStarted = (tripStartState.TRIP_STARTED EQ true);
            }

            qPlan = queryExecute(
                "SELECT
                    floatplanId,
                    userId,
                    status,
                    route_instance_id,
                    departureTime,
                    departureTimeUTC,
                    departTimezone,
                    departureTZ,
                    returnTime,
                    returnTimeUTC,
                    returnTimezone,
                    returnTZ,
                    checkedInAt,
                    checkin_context,
                    dailyStartLocalTime,
                    (
                        SELECT NULLIF(UPPER(TRIM(m.monitor_state)), '')
                        FROM floatplan_monitoring m
                        WHERE m.float_plan_id = floatplans.floatplanId
                          AND m.is_monitoring_enabled = 1
                          AND UPPER(TRIM(m.monitor_state)) <> 'CLOSED'
                        ORDER BY m.id DESC
                        LIMIT 1
                    ) AS monitor_state,
                    (
                        SELECT NULLIF(UPPER(TRIM(m.last_checkin_status)), '')
                        FROM floatplan_monitoring m
                        WHERE m.float_plan_id = floatplans.floatplanId
                          AND m.is_monitoring_enabled = 1
                          AND UPPER(TRIM(m.monitor_state)) <> 'CLOSED'
                        ORDER BY m.id DESC
                        LIMIT 1
                    ) AS last_checkin_status,
                    (
                        SELECT
                            COALESCE(
                                CONVERT_TZ(
                                    m.expected_checkin_at,
                                    'UTC',
                                    NULLIF(COALESCE(NULLIF(floatplans.departureTZ, ''), NULLIF(floatplans.departTimezone, ''), 'UTC'), '')
                                ),
                                m.expected_checkin_at
                            )
                        FROM floatplan_monitoring m
                        WHERE m.float_plan_id = floatplans.floatplanId
                          AND m.is_monitoring_enabled = 1
                          AND UPPER(TRIM(m.monitor_state)) <> 'CLOSED'
                        ORDER BY m.id DESC
                        LIMIT 1
                    ) AS expected_checkin_at,
                    overnight_pause_minutes_total,
                    manual_delay_minutes_total
                 FROM floatplans
                 WHERE floatplanId = :planId
                   AND userId = :userId
                 LIMIT 1",
                {
                    planId = { value=arguments.floatPlanId, cfsqltype="cf_sql_integer" },
                    userId = { value=arguments.currentUserId, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            if (qPlan.recordCount EQ 0) {
                out.MESSAGE = "Active Cruise hero values could not load the active float plan.";
                return out;
            }

            if (!isNull(qPlan.departureTime[1]) AND isDate(qPlan.departureTime[1])) {
                scheduledDepartureRawDt = qPlan.departureTime[1];
            }
            if (!isNull(qPlan.monitor_state[1])) {
                monitorStateVal = uCase(trim(toString(qPlan.monitor_state[1])));
            }
            if (!isNull(qPlan.last_checkin_status[1])) {
                lastCheckinStatusVal = uCase(trim(toString(qPlan.last_checkin_status[1])));
            }
            if (!tripStarted) {
                statusLabel = "Scheduled";
            } else {
                switch (monitorStateVal) {
                    case "LATE":
                        statusLabel = "Late";
                        statusVariant = "warning";
                        break;
                    case "MISSED":
                        statusLabel = "Missed Check-In";
                        statusVariant = "danger";
                        break;
                    case "ESCALATED":
                        statusLabel = "Escalated";
                        statusVariant = "danger";
                        break;
                    case "ACTIVE":
                        statusLabel = "All Good";
                        statusVariant = "good";
                        break;
                    default:
                        statusLabel = "Status Unavailable";
                        statusVariant = "good";
                }

                if (lastCheckinStatusVal EQ "DELAYED") {
                    statusLabel = "Delayed";
                    statusVariant = "warning";
                } else if (lastCheckinStatusVal EQ "CHANGED_PLAN") {
                    statusLabel = "Changed Plan";
                    statusVariant = "warning";
                } else if (lastCheckinStatusVal EQ "NEED_ATTENTION") {
                    statusLabel = "Assistance Needed";
                    statusVariant = "danger";
                } else if (lastCheckinStatusVal EQ "SECURE_FOR_NIGHT" OR normalizeCheckInContext(isNull(qPlan.checkin_context[1]) ? "" : qPlan.checkin_context[1]) EQ "overnight") {
                    statusLabel = "Secure for the Night";
                    statusVariant = "good";
                }
            }
            out.heroVoyageStatus = statusLabel;
            out.heroVoyageStatusVariant = statusVariant;

            if (!isNull(qPlan.checkedInAt[1]) AND isDate(qPlan.checkedInAt[1])) {
                checkedInAtVal = qPlan.checkedInAt[1];
            }
            if (!isNull(qPlan.expected_checkin_at[1]) AND isDate(qPlan.expected_checkin_at[1])) {
                expectedCheckInDt = qPlan.expected_checkin_at[1];
            }
            hasOperationalCheckIn = (tripStarted AND isDate(checkedInAtVal));
            if (hasOperationalCheckIn AND isDate(scheduledDepartureRawDt)) {
                hasOperationalCheckIn = (dateCompare(checkedInAtVal, scheduledDepartureRawDt, "s") GTE 0);
            }
            if (hasOperationalCheckIn) {
                actualCheckInLabel = dateTimeFormat(checkedInAtVal, "mmm d, yyyy h:nn tt");
                actualCheckInUtc = formatUtcDate(checkedInAtVal);
                out.heroLastCheckIn = actualCheckInLabel;
                out.heroLastCheckInUtc = actualCheckInUtc;
            } else {
                checkedInAtVal = "";
            }

            checkInContextVal = normalizeCheckInContext(isNull(qPlan.checkin_context[1]) ? "" : qPlan.checkin_context[1]);
            isOvernightCheckIn = (hasOperationalCheckIn AND checkInContextVal EQ "overnight");
            storedOvernightPauseMinutes = (
                !isNull(qPlan.overnight_pause_minutes_total[1]) AND isNumeric(qPlan.overnight_pause_minutes_total[1])
                    ? val(qPlan.overnight_pause_minutes_total[1])
                    : 0
            );
            if (storedOvernightPauseMinutes LT 0) {
                storedOvernightPauseMinutes = 0;
            }
            if (!hasOperationalCheckIn) {
                storedOvernightPauseMinutes = 0;
            }
            if (
                tripStarted
                AND storedOvernightPauseMinutes GT 0
                AND hasOperationalCheckIn
                AND !isOvernightCheckIn
                AND len(lastCheckinStatusVal)
                AND lastCheckinStatusVal NEQ "SECURE_FOR_NIGHT"
                AND isDate(checkedInAtVal)
            ) {
                actualResumeAt = checkedInAtVal;
                hasActualResumeAt = true;
            }
            storedManualDelayMinutes = (
                !isNull(qPlan.manual_delay_minutes_total[1]) AND isNumeric(qPlan.manual_delay_minutes_total[1])
                    ? val(qPlan.manual_delay_minutes_total[1])
                    : 0
            );
            if (storedManualDelayMinutes LT 0) {
                storedManualDelayMinutes = 0;
            }
            out.manualDelayMinutesTotal = storedManualDelayMinutes;

            departureTimeZoneVal = (isNull(qPlan.departureTZ[1]) ? "" : trim(toString(qPlan.departureTZ[1])));
            if (!len(departureTimeZoneVal)) {
                departureTimeZoneVal = (isNull(qPlan.departTimezone[1]) ? "" : trim(toString(qPlan.departTimezone[1])));
            }
            dailyStartLocalTimeVal = (isNull(qPlan.dailyStartLocalTime[1]) ? "" : trim(toString(qPlan.dailyStartLocalTime[1])));
            localDayStartRule = loadOvernightTimingRule(dailyStartLocalTimeVal);
            storedDepartureTimeZoneVal = (isNull(qPlan.departTimezone[1]) ? "" : trim(toString(qPlan.departTimezone[1])));
            returnTimeZoneVal = (isNull(qPlan.returnTZ[1]) ? "" : trim(toString(qPlan.returnTZ[1])));
            if (!len(returnTimeZoneVal)) {
                returnTimeZoneVal = (isNull(qPlan.returnTimezone[1]) ? "" : trim(toString(qPlan.returnTimezone[1])));
            }
            storedReturnTimeZoneVal = (isNull(qPlan.returnTimezone[1]) ? "" : trim(toString(qPlan.returnTimezone[1])));

            if (!isNull(qPlan.departureTimeUTC[1]) AND isDate(qPlan.departureTimeUTC[1])) {
                heroTripStartUtc = formatUtcDate(qPlan.departureTimeUTC[1]);
                if (len(heroTripStartUtc)) {
                    out.heroTripStartUtc = heroTripStartUtc;
                }
            }

            if (!isNull(qPlan.returnTimeUTC[1]) AND isDate(qPlan.returnTimeUTC[1])) {
                legArrivalUtc = formatUtcDate(qPlan.returnTimeUTC[1]);
                if (len(legArrivalUtc)) {
                    out.legArrivalUtc = legArrivalUtc;
                }
            }

            routeMap = buildRouteMapData(canonicalPlan.ROUTE_INSTANCE_ID, arguments.currentUserId);
            followTimeline = buildFollowCruiseTimeline(canonicalPlan.ROUTE_INSTANCE_ID, arguments.currentUserId);
            routeMapActiveLegOrder = (structKeyExists(routeMap, "active_leg_order") ? val(routeMap.active_leg_order) : 0);
            awaitingDepartureState = (tripStarted AND structKeyExists(routeMap, "awaiting_departure") AND routeMap.awaiting_departure EQ true);

            nextStopLabelVal = (len(routeMap.next_stop_label) ? trim(toString(routeMap.next_stop_label)) : "");
            out.heroNextStop = (len(nextStopLabelVal) ? nextStopLabelVal : "n/a");

            if (
                !isNull(qPlan.departureTime[1])
                AND isDate(qPlan.departureTime[1])
                AND len(nextStopLabelVal)
                AND (!tripStarted OR routeMapActiveLegOrder GT 0)
                AND isStruct(followTimeline)
                AND structKeyExists(followTimeline, "legs")
                AND isArray(followTimeline.legs)
            ) {
                nextStopEtaBaseDt = qPlan.departureTime[1];
                if (
                    isDate(nextStopEtaBaseDt)
                    AND ucase(storedDepartureTimeZoneVal) EQ "UTC"
                    AND len(departureTimeZoneVal)
                    AND ucase(departureTimeZoneVal) NEQ "UTC"
                ) {
                    qLocalDeparture = queryExecute("
                        SELECT CONVERT_TZ(:utcDateTime, 'UTC', :targetTimeZone) AS localDateTime
                    ", {
                        utcDateTime = { value = nextStopEtaBaseDt, cfsqltype = "cf_sql_timestamp" },
                        targetTimeZone = { value = departureTimeZoneVal, cfsqltype = "cf_sql_varchar" }
                    }, { datasource = ds });
                    if (qLocalDeparture.recordCount GT 0 AND !isNull(qLocalDeparture.localDateTime[1])) {
                        nextStopEtaBaseDt = qLocalDeparture.localDateTime[1];
                    }
                }
                actualResumeAtLocal = actualResumeAt;
                if (
                    hasActualResumeAt
                    AND isDate(actualResumeAtLocal)
                    AND ucase(storedDepartureTimeZoneVal) EQ "UTC"
                    AND len(departureTimeZoneVal)
                    AND ucase(departureTimeZoneVal) NEQ "UTC"
                ) {
                    qActualResumeLocal = queryExecute("
                        SELECT CONVERT_TZ(:utcDateTime, 'UTC', :targetTimeZone) AS localDateTime
                    ", {
                        utcDateTime = { value = actualResumeAtLocal, cfsqltype = "cf_sql_timestamp" },
                        targetTimeZone = { value = departureTimeZoneVal, cfsqltype = "cf_sql_varchar" }
                    }, { datasource = ds });
                    if (qActualResumeLocal.recordCount GT 0 AND !isNull(qActualResumeLocal.localDateTime[1]) AND isDate(qActualResumeLocal.localDateTime[1])) {
                        actualResumeAtLocal = qActualResumeLocal.localDateTime[1];
                    }
                }

                for (i = 1; i LTE arrayLen(followTimeline.legs); i++) {
                    nextStopLeg = followTimeline.legs[i];
                    if (!isStruct(nextStopLeg) OR !structKeyExists(nextStopLeg, "end_name")) {
                        continue;
                    }
                    if (
                        tripStarted
                        AND routeMapActiveLegOrder GT 0
                        AND (
                            !structKeyExists(nextStopLeg, "leg_order")
                            OR !isNumeric(nextStopLeg.leg_order)
                            OR val(nextStopLeg.leg_order) NEQ routeMapActiveLegOrder
                        )
                    ) {
                        continue;
                    }
                    if (trim(toString(nextStopLeg.end_name)) NEQ nextStopLabelVal) {
                        continue;
                    }

                    nextStopCumulativeMinutes = 0;
                    activeLegEtaMinutes = 0;
                    activeLegEtaBaseDt = nextStopEtaBaseDt;
                    plannedNextStopEtaDt = "";
                    nextStopEtaDt = "";

                    if (structKeyExists(nextStopLeg, "cumulative_hours") AND isNumeric(nextStopLeg.cumulative_hours) AND val(nextStopLeg.cumulative_hours) GTE 0) {
                        nextStopCumulativeMinutes = int(round(val(nextStopLeg.cumulative_hours) * 60));
                    }
                    if (structKeyExists(nextStopLeg, "hours") AND isNumeric(nextStopLeg.hours) AND val(nextStopLeg.hours) GTE 0) {
                        activeLegEtaMinutes = int(round(val(nextStopLeg.hours) * 60));
                    }
                    currentLegStartedAt = "";
                    currentLegStartedAtLocal = "";
                    priorLegCompletedAt = "";
                    priorLegCompletedAtLocal = "";
                    if (structKeyExists(nextStopLeg, "leg_order") AND isNumeric(nextStopLeg.leg_order) AND val(nextStopLeg.leg_order) GT 0) {
                        qLegTiming = queryExecute(
                            "SELECT
                                curr.leg_started_at AS current_leg_started_at,
                                COALESCE(CONVERT_TZ(curr.leg_started_at, 'UTC', :targetTimeZone), curr.leg_started_at) AS current_leg_started_at_local,
                                prev.completed_at AS prior_leg_completed_at,
                                COALESCE(CONVERT_TZ(prev.completed_at, 'UTC', :targetTimeZone), prev.completed_at) AS prior_leg_completed_at_local
                             FROM route_instance_leg_progress curr
                             LEFT JOIN route_instance_leg_progress prev
                               ON prev.route_instance_id = curr.route_instance_id
                              AND prev.user_id = curr.user_id
                              AND prev.leg_order = curr.leg_order - 1
                             WHERE curr.route_instance_id = :routeInstanceId
                               AND curr.user_id = :ownerUserId
                               AND curr.leg_order = :legOrder
                             LIMIT 1",
                            {
                                routeInstanceId = { value = canonicalPlan.ROUTE_INSTANCE_ID, cfsqltype = "cf_sql_integer" },
                                ownerUserId = { value = arguments.currentUserId, cfsqltype = "cf_sql_integer" },
                                legOrder = { value = val(nextStopLeg.leg_order), cfsqltype = "cf_sql_integer" },
                                targetTimeZone = { value = (len(departureTimeZoneVal) ? departureTimeZoneVal : "UTC"), cfsqltype = "cf_sql_varchar" }
                            },
                            { datasource = ds }
                        );
                        if (qLegTiming.recordCount GT 0) {
                            if (!isNull(qLegTiming.current_leg_started_at[1]) AND isDate(qLegTiming.current_leg_started_at[1])) {
                                currentLegStartedAt = qLegTiming.current_leg_started_at[1];
                                currentLegStartedAtLocal = currentLegStartedAt;
                                if (
                                    ucase(storedDepartureTimeZoneVal) EQ "UTC"
                                    AND len(departureTimeZoneVal)
                                    AND ucase(departureTimeZoneVal) NEQ "UTC"
                                    AND !isNull(qLegTiming.current_leg_started_at_local[1])
                                    AND isDate(qLegTiming.current_leg_started_at_local[1])
                                ) {
                                    currentLegStartedAtLocal = qLegTiming.current_leg_started_at_local[1];
                                }
                            }
                            if (!isNull(qLegTiming.prior_leg_completed_at[1]) AND isDate(qLegTiming.prior_leg_completed_at[1])) {
                                priorLegCompletedAt = qLegTiming.prior_leg_completed_at[1];
                                priorLegCompletedAtLocal = priorLegCompletedAt;
                                if (
                                    ucase(storedDepartureTimeZoneVal) EQ "UTC"
                                    AND len(departureTimeZoneVal)
                                    AND ucase(departureTimeZoneVal) NEQ "UTC"
                                    AND !isNull(qLegTiming.prior_leg_completed_at_local[1])
                                    AND isDate(qLegTiming.prior_leg_completed_at_local[1])
                                ) {
                                    priorLegCompletedAtLocal = qLegTiming.prior_leg_completed_at_local[1];
                                }
                            }
                        }
                    }

                    if (nextStopCumulativeMinutes GT 0) {
                        plannedNextStopEtaDt = dateAdd("n", nextStopCumulativeMinutes, nextStopEtaBaseDt);
                        if (tripStarted AND storedOvernightPauseMinutes GT 0) {
                            plannedNextStopEtaDt = dateAdd("n", storedOvernightPauseMinutes, plannedNextStopEtaDt);
                        }
                    }

                    hasValidCurrentLegStart = (tripStarted AND isDate(currentLegStartedAt));
                    if (hasValidCurrentLegStart AND isDate(scheduledDepartureRawDt)) {
                        hasValidCurrentLegStart = (dateCompare(currentLegStartedAt, scheduledDepartureRawDt, "s") GTE 0);
                    }
                    hasValidPriorLegCompletion = (tripStarted AND isDate(priorLegCompletedAt));
                    if (hasValidPriorLegCompletion AND isDate(scheduledDepartureRawDt)) {
                        hasValidPriorLegCompletion = (dateCompare(priorLegCompletedAt, scheduledDepartureRawDt, "s") GTE 0);
                    }

                    resumeDayStartDt = "";
                    resumeAnchorDt = "";
                    useResumedDayStartEtaBase = false;
                    if (tripStarted AND storedOvernightPauseMinutes GT 0 AND hasOperationalCheckIn AND !hasActualResumeAt AND isDate(checkedInAtVal)) {
                        resumeDayStartDt = createDateTime(
                            year(checkedInAtVal),
                            month(checkedInAtVal),
                            day(checkedInAtVal),
                            localDayStartRule.local_day_start_hour,
                            localDayStartRule.local_day_start_minute,
                            localDayStartRule.local_day_start_second
                        );
                        if (hasValidCurrentLegStart) {
                            resumeAnchorDt = currentLegStartedAtLocal;
                        } else if (hasValidPriorLegCompletion) {
                            resumeAnchorDt = priorLegCompletedAtLocal;
                        }
                        if (
                            isDate(resumeAnchorDt)
                            AND isDate(resumeDayStartDt)
                            AND dateCompare(resumeAnchorDt, resumeDayStartDt, "s") LT 0
                            AND dateCompare(checkedInAtVal, resumeDayStartDt, "s") GTE 0
                        ) {
                            activeLegEtaBaseDt = resumeDayStartDt;
                            useResumedDayStartEtaBase = true;
                        }
                    }

                    if (!useResumedDayStartEtaBase AND tripStarted AND isOvernightCheckIn AND hasOperationalCheckIn AND len(departureTimeZoneVal)) {
                        try {
                            if (isDate(expectedCheckInDt)) {
                                nextMorningResumeDt = expectedCheckInDt;
                            } else if (isDate(checkedInAtVal)) {
                                nextMorningResumeDt = dateAdd("d", 1, checkedInAtVal);
                                nextMorningResumeDt = createDateTime(
                                    year(nextMorningResumeDt),
                                    month(nextMorningResumeDt),
                                    day(nextMorningResumeDt),
                                    localDayStartRule.local_day_start_hour,
                                    localDayStartRule.local_day_start_minute,
                                    localDayStartRule.local_day_start_second
                                );
                            }
                            if (isDate(nextMorningResumeDt)) {
                                activeLegEtaBaseDt = nextMorningResumeDt;
                            }
                            overnightPauseMinutes = dateDiff("n", checkedInAtVal, nextMorningResumeDt);
                            if (storedOvernightPauseMinutes LTE 0 AND isDate(plannedNextStopEtaDt) AND overnightPauseMinutes GT 0) {
                                plannedNextStopEtaDt = dateAdd("n", overnightPauseMinutes, plannedNextStopEtaDt);
                            }
                        } catch (any overnightEtaErr) {
                            // Preserve additive behavior if overnight resume derivation fails.
                        }
                    } else if (
                        !useResumedDayStartEtaBase
                        AND hasActualResumeAt
                        AND isDate(actualResumeAt)
                        AND isDate(actualResumeAtLocal)
                        AND (
                            !hasValidCurrentLegStart
                            OR !isDate(currentLegStartedAt)
                            OR dateCompare(currentLegStartedAt, actualResumeAt, "s") LT 0
                        )
                    ) {
                        activeLegEtaBaseDt = actualResumeAtLocal;
                    } else if (!useResumedDayStartEtaBase AND hasValidCurrentLegStart) {
                        activeLegEtaBaseDt = currentLegStartedAtLocal;
                    } else if (!useResumedDayStartEtaBase AND hasValidPriorLegCompletion) {
                        activeLegEtaBaseDt = priorLegCompletedAtLocal;
                    }

                    usingActiveLegEta = false;
                    if (activeLegEtaMinutes GT 0 AND isDate(activeLegEtaBaseDt)) {
                        usingActiveLegEta = true;
                        nextStopEtaDt = dateAdd("n", activeLegEtaMinutes, activeLegEtaBaseDt);
                    } else {
                        nextStopEtaDt = plannedNextStopEtaDt;
                    }
                    if (usingActiveLegEta AND tripStarted AND storedManualDelayMinutes GT 0 AND isDate(nextStopEtaDt)) {
                        nextStopEtaDt = dateAdd("n", storedManualDelayMinutes, nextStopEtaDt);
                    }

                    if (isDate(nextStopEtaDt)) {
                        etaLabel = dateTimeFormat(nextStopEtaDt, "mmm d, yyyy h:nn tt");
                        etaUtc = formatUtcInstantFromLocalTime(nextStopEtaDt, departureTimeZoneVal);
                    }
                    break;
                }
            }

            if (len(etaLabel)) {
                out.heroEta = etaLabel;
            }
            if (len(etaUtc)) {
                out.heroEtaUtc = etaUtc;
            }
            // Canonical hooks expose real canonical segments or scheduled route timelines; legacy diagnostics remain fallback-only.
            try {
                activeCruiseProjection = createTripProgressProjectionService().getProjection(arguments.floatPlanId);
            } catch (any activeCruiseProjectionErr) {
                activeCruiseProjection = {};
            }
            if (
                isStruct(activeCruiseProjection)
                AND structKeyExists(activeCruiseProjection, "authorityWarnings")
                AND isArray(activeCruiseProjection.authorityWarnings)
            ) {
                for (activeCruiseProjectionWarningIndex = 1; activeCruiseProjectionWarningIndex LTE arrayLen(activeCruiseProjection.authorityWarnings); activeCruiseProjectionWarningIndex++) {
                    activeCruiseProjectionWarning = activeCruiseProjection.authorityWarnings[activeCruiseProjectionWarningIndex];
                    if (!isStruct(activeCruiseProjectionWarning) OR !structKeyExists(activeCruiseProjectionWarning, "code")) {
                        continue;
                    }
                    activeCruiseProjectionWarningCode = trim(toString(activeCruiseProjectionWarning.code));
                    if (listFindNoCase("MULTIPLE_OPEN_SEGMENTS,CANONICAL_ACTIVITY_SEGMENT_TABLE_MISSING,CANONICAL_EVENT_TABLE_MISSING", activeCruiseProjectionWarningCode)) {
                        canonicalActiveCruiseProjectionBlocked = true;
                        break;
                    }
                }
            }
            useCanonicalActiveCruiseProjection = (
                isStruct(activeCruiseProjection)
                AND structKeyExists(activeCruiseProjection, "success")
                AND activeCruiseProjection.success
                AND structKeyExists(activeCruiseProjection, "activitySegments")
                AND isArray(activeCruiseProjection.activitySegments)
                AND arrayLen(activeCruiseProjection.activitySegments) GT 0
                AND structKeyExists(activeCruiseProjection, "eventLedger")
                AND isStruct(activeCruiseProjection.eventLedger)
                AND structKeyExists(activeCruiseProjection.eventLedger, "count")
                AND val(activeCruiseProjection.eventLedger.count) GT 0
                AND structKeyExists(activeCruiseProjection, "todayProgress")
                AND isStruct(activeCruiseProjection.todayProgress)
                AND structKeyExists(activeCruiseProjection.todayProgress, "authority")
                AND lCase(trim(toString(activeCruiseProjection.todayProgress.authority))) EQ "canonical"
                AND !canonicalActiveCruiseProjectionBlocked
            );
            if (
                isStruct(activeCruiseProjection)
                AND structKeyExists(activeCruiseProjection, "routeTimeline")
                AND isStruct(activeCruiseProjection.routeTimeline)
                AND structKeyExists(activeCruiseProjection.routeTimeline, "available")
                AND activeCruiseProjection.routeTimeline.available
                AND structKeyExists(activeCruiseProjection.routeTimeline, "authority")
            ) {
                activeCruiseRouteTimelineAuthority = lCase(trim(toString(activeCruiseProjection.routeTimeline.authority)));
            }
            useRouteTimelineActiveCruiseProjection = (
                isStruct(activeCruiseProjection)
                AND structKeyExists(activeCruiseProjection, "success")
                AND activeCruiseProjection.success
                AND listFindNoCase("canonical_projection,scheduled_projection", activeCruiseRouteTimelineAuthority)
                AND !canonicalActiveCruiseProjectionBlocked
            );
            if (
                isStruct(activeCruiseProjection)
                AND structKeyExists(activeCruiseProjection, "authorityWarnings")
                AND isArray(activeCruiseProjection.authorityWarnings)
            ) {
                out.projectionWarnings = duplicate(activeCruiseProjection.authorityWarnings);
            }
            if (useCanonicalActiveCruiseProjection OR useRouteTimelineActiveCruiseProjection) {
                out.canonicalProjectionAvailable = true;
                out.projectionAuthority = (len(activeCruiseRouteTimelineAuthority) ? activeCruiseRouteTimelineAuthority : "canonical_projection");
                if (structKeyExists(activeCruiseProjection, "etaProjection") AND isStruct(activeCruiseProjection.etaProjection)) {
                    out.etaProjection = duplicate(activeCruiseProjection.etaProjection);
                }
                if (structKeyExists(activeCruiseProjection, "todayProgress") AND isStruct(activeCruiseProjection.todayProgress)) {
                    out.todayProgress = duplicate(activeCruiseProjection.todayProgress);
                }
                if (structKeyExists(activeCruiseProjection, "currentLegProgress") AND isStruct(activeCruiseProjection.currentLegProgress)) {
                    out.currentLegProgress = duplicate(activeCruiseProjection.currentLegProgress);
                }
                if (
                    structKeyExists(activeCruiseProjection, "routeTimeline")
                    AND isStruct(activeCruiseProjection.routeTimeline)
                    AND structKeyExists(activeCruiseProjection.routeTimeline, "available")
                    AND activeCruiseProjection.routeTimeline.available
                ) {
                    out.routeTimeline = duplicate(activeCruiseProjection.routeTimeline);
                }
            }
            if (
                useCanonicalActiveCruiseProjection
                AND structKeyExists(activeCruiseProjection, "etaProjection")
                AND isStruct(activeCruiseProjection.etaProjection)
                AND structKeyExists(activeCruiseProjection.etaProjection, "available")
                AND activeCruiseProjection.etaProjection.available
                AND structKeyExists(activeCruiseProjection.etaProjection, "etaUtc")
                AND len(trim(toString(activeCruiseProjection.etaProjection.etaUtc)))
            ) {
                activeCruiseProjectionEtaUtc = trim(toString(activeCruiseProjection.etaProjection.etaUtc));
                out.heroEtaUtc = activeCruiseProjectionEtaUtc;
                out.legArrivalUtc = activeCruiseProjectionEtaUtc;
                out.heroEta = "";
                activeCruiseProjectionEtaLocalInput = replace(replace(activeCruiseProjectionEtaUtc, "T", " ", "one"), "Z", "", "one");
                out.heroEta = formatVoyageUtcDisplayLabel(activeCruiseProjectionEtaUtc, departureTimeZoneVal);
            }
            if (awaitingDepartureState) {
                out.heroEta = "--";
                out.heroEtaUtc = "";
            }

            out.SUCCESS = true;
            out.MESSAGE = "OK";
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getActiveCruiseWeatherCanonical" access="private" returntype="struct" output="false">
        <cfargument name="currentUserId" type="numeric" required="true">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="point" type="string" required="true">
        <cfargument name="routeLegOrder" type="string" required="false" default="">
        <cfscript>
            var canonicalPlan = {};
            var routeMap = {};
            var pointKey = lCase(trim(arguments.point));
            var routeLegOrderRaw = trim(toString(arguments.routeLegOrder));
            var routeLegOrderProvided = len(routeLegOrderRaw) GT 0;
            var routeLegOrderVal = val(routeLegOrderRaw);
            var ds = resolveDatasource();
            var qRouteLeg = queryNew("");
            var pointLabel = "";
            var pointLat = "";
            var pointLng = "";
            var weatherComponent = "";
            var weatherPayload = {};
            var weatherData = {
                "FORECAST"=[],
                "MARINE"={ "wave_height_ft"="" },
                "surface"={ "visibility_mi"="" },
                "ALERTS"=[]
            };
            var firstForecast = {};
            var firstForecastOut = {
                "windSpeed"="",
                "windDirection"="",
                "gustMph"=""
            };
            var hasForecastData = false;
            var hasWaveData = false;
            var hasVisibilityData = false;
            var hasAlerts = false;
            var hasWeatherData = false;

            if (arguments.currentUserId LTE 0) {
                return buildApiEnvelope(
                    success=false,
                    code="UNAUTHORIZED",
                    message="Owner session required.",
                    data={},
                    auth=false
                );
            }

            if (!listFindNoCase("start,end", pointKey)) {
                return buildApiEnvelope(
                    success=false,
                    code="INVALID_POINT",
                    message="Select Start or End to check conditions.",
                    data={},
                    auth=true
                );
            }

            if (arguments.floatPlanId LTE 0) {
                return buildApiEnvelope(
                    success=false,
                    code="FLOATPLAN_REQUIRED",
                    message="Unable to find the active float plan for this trip.",
                    data={},
                    auth=true
                );
            }

            canonicalPlan = resolveCanonicalActiveFloatPlan(arguments.currentUserId, arguments.floatPlanId);
            if (!canonicalPlan.SUCCESS) {
                return buildApiEnvelope(
                    success=false,
                    code=(structKeyExists(canonicalPlan, "ERROR") ? toString(canonicalPlan.ERROR) : "ACTIVE_PLAN_UNAVAILABLE"),
                    message=canonicalPlan.MESSAGE,
                    data={},
                    auth=true
                );
            }

            if (routeLegOrderProvided) {
                if (routeLegOrderVal GT 0) {
                    qRouteLeg = queryExecute(
                        "SELECT start_name, end_name, start_lat, start_lng, end_lat, end_lng
                         FROM route_instance_legs
                         WHERE route_instance_id = :routeInstanceId
                           AND leg_order = :legOrder
                         ORDER BY id ASC
                         LIMIT 1",
                        {
                            routeInstanceId = { value=canonicalPlan.ROUTE_INSTANCE_ID, cfsqltype="cf_sql_integer" },
                            legOrder = { value=routeLegOrderVal, cfsqltype="cf_sql_integer" }
                        },
                        { datasource=ds }
                    );
                }
                if (qRouteLeg.recordCount GT 0) {
                    if (pointKey EQ "start") {
                        pointLabel = (isNull(qRouteLeg.start_name[1]) ? "" : trim(toString(qRouteLeg.start_name[1])));
                        pointLat = (isNull(qRouteLeg.start_lat[1]) ? "" : qRouteLeg.start_lat[1]);
                        pointLng = (isNull(qRouteLeg.start_lng[1]) ? "" : qRouteLeg.start_lng[1]);
                    } else {
                        pointLabel = (isNull(qRouteLeg.end_name[1]) ? "" : trim(toString(qRouteLeg.end_name[1])));
                        pointLat = (isNull(qRouteLeg.end_lat[1]) ? "" : qRouteLeg.end_lat[1]);
                        pointLng = (isNull(qRouteLeg.end_lng[1]) ? "" : qRouteLeg.end_lng[1]);
                    }
                }
            } else {
                routeMap = buildRouteMapData(canonicalPlan.ROUTE_INSTANCE_ID, arguments.currentUserId);
                if (pointKey EQ "start") {
                    pointLabel = (structKeyExists(routeMap, "active_leg_start_name") ? trim(toString(routeMap.active_leg_start_name)) : "");
                    pointLat = (structKeyExists(routeMap, "active_leg_start_lat") ? routeMap.active_leg_start_lat : "");
                    pointLng = (structKeyExists(routeMap, "active_leg_start_lng") ? routeMap.active_leg_start_lng : "");
                } else {
                    pointLabel = (structKeyExists(routeMap, "active_leg_end_name") ? trim(toString(routeMap.active_leg_end_name)) : "");
                    pointLat = (structKeyExists(routeMap, "active_leg_end_lat") ? routeMap.active_leg_end_lat : "");
                    pointLng = (structKeyExists(routeMap, "active_leg_end_lng") ? routeMap.active_leg_end_lng : "");
                }
            }

            if (!isNumeric(pointLat) OR !isNumeric(pointLng)) {
                return buildApiEnvelope(
                    success=true,
                    code="OK",
                    message="Conditions unavailable for selected leg point.",
                    data={
                        "point"=pointKey,
                        "point_label"=pointLabel,
                        "available"=false,
                        "weather"=weatherData
                    },
                    auth=true
                );
            }

            try {
                weatherComponent = createObject("component", "fpw.api.v1.weather");
            } catch (any weatherComponentErrA) {
                try {
                    weatherComponent = createObject("component", "api.v1.weather");
                } catch (any weatherComponentErrB) {
                    weatherComponent = "";
                }
            }

            if (!isObject(weatherComponent)) {
                return buildApiEnvelope(
                    success=false,
                    code="WEATHER_SERVICE_UNAVAILABLE",
                    message="Weather service is unavailable.",
                    data={},
                    auth=true
                );
            }

            try {
                weatherPayload = weatherComponent.getWeatherForCoordinates(val(pointLat), val(pointLng));
            } catch (any weatherLookupErr) {
                return buildApiEnvelope(
                    success=false,
                    code="WEATHER_LOOKUP_FAILED",
                    message=(len(trim(weatherLookupErr.message)) ? weatherLookupErr.message : "Unable to load weather right now."),
                    data={},
                    auth=true
                );
            }

            if (structKeyExists(weatherPayload, "FORECAST") AND isArray(weatherPayload.FORECAST) AND arrayLen(weatherPayload.FORECAST) GTE 1 AND isStruct(weatherPayload.FORECAST[1])) {
                firstForecast = duplicate(weatherPayload.FORECAST[1]);
                if (structKeyExists(firstForecast, "windSpeed")) {
                    firstForecastOut.windSpeed = firstForecast.windSpeed;
                }
                if (structKeyExists(firstForecast, "windDirection")) {
                    firstForecastOut.windDirection = firstForecast.windDirection;
                }
                if (structKeyExists(firstForecast, "gustMph")) {
                    firstForecastOut.gustMph = firstForecast.gustMph;
                }
                arrayAppend(weatherData.FORECAST, firstForecastOut);
            }

            if (structKeyExists(weatherPayload, "MARINE") AND isStruct(weatherPayload.MARINE) AND structKeyExists(weatherPayload.MARINE, "wave_height_ft")) {
                weatherData.MARINE.wave_height_ft = weatherPayload.MARINE.wave_height_ft;
            }

            if (structKeyExists(weatherPayload, "surface") AND isStruct(weatherPayload.surface) AND structKeyExists(weatherPayload.surface, "visibility_mi")) {
                weatherData.surface.visibility_mi = weatherPayload.surface.visibility_mi;
            }

            if (structKeyExists(weatherPayload, "ALERTS") AND isArray(weatherPayload.ALERTS)) {
                weatherData.ALERTS = duplicate(weatherPayload.ALERTS);
            }

            hasForecastData = (
                arrayLen(weatherData.FORECAST)
                AND (
                    len(trim(toString(weatherData.FORECAST[1].windSpeed)))
                    OR len(trim(toString(weatherData.FORECAST[1].windDirection)))
                    OR isNumeric(weatherData.FORECAST[1].gustMph)
                    OR len(trim(toString(weatherData.FORECAST[1].gustMph)))
                )
            );
            hasWaveData = (
                structKeyExists(weatherData.MARINE, "wave_height_ft")
                AND (
                    isNumeric(weatherData.MARINE.wave_height_ft)
                    OR len(trim(toString(weatherData.MARINE.wave_height_ft)))
                )
            );
            hasVisibilityData = (
                structKeyExists(weatherData.surface, "visibility_mi")
                AND (
                    isNumeric(weatherData.surface.visibility_mi)
                    OR len(trim(toString(weatherData.surface.visibility_mi)))
                )
            );
            hasAlerts = arrayLen(weatherData.ALERTS) GT 0;
            hasWeatherData = (hasForecastData OR hasWaveData OR hasVisibilityData OR hasAlerts);

            return buildApiEnvelope(
                success=true,
                code="OK",
                message=(hasWeatherData ? "OK" : "Conditions unavailable for selected leg point."),
                data={
                    "point"=pointKey,
                    "point_label"=pointLabel,
                    "available"=hasWeatherData,
                    "weather"=weatherData
                },
                auth=true
            );
        </cfscript>
    </cffunction>

    <cffunction name="listPosts" access="private" returntype="struct" output="false">
        <cfargument name="streamId" type="numeric" required="true">
        <cfargument name="cursor" type="numeric" required="false" default="0">
        <cfargument name="limit" type="numeric" required="false" default="20">
        <cfargument name="shareToken" type="string" required="false" default="">
        <cfargument name="followerToken" type="string" required="false" default="">
        <cfargument name="currentUserId" type="numeric" required="false" default="0">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unable to load posts",
                "posts"=[],
                "next_cursor"=0
            };
            var streamIdVal = val(arguments.streamId);
            var cursorVal = val(arguments.cursor);
            var limitVal = val(arguments.limit);
            var streamRow = {};
            var isOwner = false;
            var canRead = {};
            var ds = resolveDatasource();
            var qPosts = queryNew("");
            var qReacts = queryNew("");
            var qComments = queryNew("");
            var qViewerReacts = queryNew("");
            var i = 0;
            var j = 0;
            var postIdVal = 0;
            var postObj = {};
            var comments = [];
            var reactions = { "like"=0, "love"=0, "boat"=0, "wave"=0 };
            var viewerReactionMap = {};
            var followerRow = {};
            var sql = "";
            var params = {};
            var commentObj = {};
            var memberGateResult = {};

            if (streamIdVal LTE 0) {
                out.MESSAGE = "stream_id required";
                out.ERROR = { "MESSAGE"="stream_id is required." };
                return out;
            }
            if (limitVal LTE 0) limitVal = 20;
            if (limitVal GT 50) limitVal = 50;

            streamRow = readStream("", streamIdVal);
            if (!structCount(streamRow)) {
                out.MESSAGE = "Stream not found";
                out.ERROR = { "MESSAGE"="No voyage stream matched the provided stream id." };
                return out;
            }

            isOwner = (arguments.currentUserId GT 0 AND arguments.currentUserId EQ streamRow.owner_user_id);
            canRead = canReadStream(streamRow, arguments.shareToken, isOwner);
            if (!canRead.allowed) {
                out.MESSAGE = "Forbidden";
                out.STATUS_CODE = 403;
                out.ERROR = { "CODE"=canRead.code, "MESSAGE"=canRead.message };
                return out;
            }

            memberGateResult = requireOwnerPremiumFollowAccess(streamRow.owner_user_id);
            if (!memberGateResult.SUCCESS) {
                return memberGateResult;
            }

            if (isOwner) {
                followerRow = findOwnerInteractionFollower(streamIdVal, arguments.currentUserId);
            } else {
                followerRow = resolveFollowerByToken(arguments.followerToken);
                if (structCount(followerRow) AND followerRow.stream_id NEQ streamIdVal) {
                    followerRow = {};
                }
            }

            sql =
                "SELECT
                    id,
                    stream_id,
                    author_type,
                    author_user_id,
                    follower_id,
                    title,
                    body,
                    post_type,
                    event_type,
                    location_label,
                    lat,
                    lng,
                    media_url,
                    media_thumb_url,
                    created_utc
                 FROM voyage_posts
                 WHERE stream_id = :streamId";
            params = {
                streamId = { value=streamIdVal, cfsqltype="cf_sql_integer" },
                lim = { value=limitVal, cfsqltype="cf_sql_integer" }
            };
            if (cursorVal GT 0) {
                sql &= " AND id < :cursor";
                params.cursor = { value=cursorVal, cfsqltype="cf_sql_integer" };
            }
            sql &= " ORDER BY id DESC LIMIT :lim";

            qPosts = queryExecute(sql, params, { datasource=ds });

            for (i = 1; i LTE qPosts.recordCount; i++) {
                postIdVal = val(qPosts.id[i]);
                reactions = { "like"=0, "love"=0, "boat"=0, "wave"=0 };
                comments = [];
                viewerReactionMap = {};

                qReacts = queryExecute(
                    "SELECT emoji, COUNT(*) AS cnt
                     FROM voyage_reactions
                     WHERE post_id = :postId
                     GROUP BY emoji",
                    {
                        postId = { value=postIdVal, cfsqltype="cf_sql_integer" }
                    },
                    { datasource=ds }
                );
                for (j = 1; j LTE qReacts.recordCount; j++) {
                    reactions[lCase(trim(toString(qReacts.emoji[j])))] = val(qReacts.cnt[j]);
                }

                if (structCount(followerRow)) {
                    qViewerReacts = queryExecute(
                        "SELECT emoji
                         FROM voyage_reactions
                         WHERE post_id = :postId
                           AND follower_id = :followerId",
                        {
                            postId = { value=postIdVal, cfsqltype="cf_sql_integer" },
                            followerId = { value=followerRow.id, cfsqltype="cf_sql_integer" }
                        },
                        { datasource=ds }
                    );
                    for (j = 1; j LTE qViewerReacts.recordCount; j++) {
                        viewerReactionMap[lCase(trim(toString(qViewerReacts.emoji[j])))] = true;
                    }
                }

                qComments = queryExecute(
                    "SELECT
                        vc.id,
                        vc.body,
                        vc.created_utc,
                        vf.display_name
                     FROM voyage_comments vc
                     LEFT JOIN voyage_followers vf ON vf.id = vc.follower_id
                     WHERE vc.post_id = :postId
                       AND vc.is_deleted = 0
                     ORDER BY vc.created_utc DESC, vc.id DESC
                     LIMIT 3",
                    {
                        postId = { value=postIdVal, cfsqltype="cf_sql_integer" }
                    },
                    { datasource=ds }
                );
                for (j = qComments.recordCount; j GTE 1; j--) {
                    commentObj = {
                        "id"=val(qComments.id[j]),
                        "body"=(isNull(qComments.body[j]) ? "" : toString(qComments.body[j])),
                        "display_name"=(isNull(qComments.display_name[j]) ? "Viewer" : toString(qComments.display_name[j])),
                        "created_utc"=formatUtcDate(qComments.created_utc[j])
                    };
                    arrayAppend(comments, commentObj);
                }

                postObj = {
                    "id"=postIdVal,
                    "stream_id"=val(qPosts.stream_id[i]),
                    "author_type"=(isNull(qPosts.author_type[i]) ? "" : toString(qPosts.author_type[i])),
                    "author_user_id"=(isNull(qPosts.author_user_id[i]) ? 0 : val(qPosts.author_user_id[i])),
                    "follower_id"=(isNull(qPosts.follower_id[i]) ? 0 : val(qPosts.follower_id[i])),
                    "title"=(isNull(qPosts.title[i]) ? "" : toString(qPosts.title[i])),
                    "body"=(isNull(qPosts.body[i]) ? "" : toString(qPosts.body[i])),
                    "post_type"=(isNull(qPosts.post_type[i]) ? "text" : toString(qPosts.post_type[i])),
                    "event_type"=(isNull(qPosts.event_type[i]) ? "" : toString(qPosts.event_type[i])),
                    "location_label"=(isNull(qPosts.location_label[i]) ? "" : toString(qPosts.location_label[i])),
                    "lat"=(isNull(qPosts.lat[i]) ? "" : qPosts.lat[i]),
                    "lng"=(isNull(qPosts.lng[i]) ? "" : qPosts.lng[i]),
                    "media_url"=(isNull(qPosts.media_url[i]) ? "" : toString(qPosts.media_url[i])),
                    "media_thumb_url"=(isNull(qPosts.media_thumb_url[i]) ? "" : toString(qPosts.media_thumb_url[i])),
                    "created_utc"=formatUtcDate(qPosts.created_utc[i]),
                    "reaction_counts"=reactions,
                    "viewer_reactions"=viewerReactionMap,
                    "comments"=comments
                };
                arrayAppend(out.posts, postObj);
                out.next_cursor = postIdVal;
            }

            out.SUCCESS = true;
            out.MESSAGE = "OK";
            out.stream_id = streamIdVal;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="followerIdentify" access="private" returntype="struct" output="false">
        <cfargument name="streamId" type="numeric" required="true">
        <cfargument name="shareToken" type="string" required="false" default="">
        <cfargument name="displayName" type="string" required="true">
        <cfargument name="email" type="string" required="false" default="">
        <cfargument name="password" type="string" required="false" default="">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unable to identify follower"
            };
            var streamIdVal = val(arguments.streamId);
            var streamRow = readStream("", streamIdVal);
            var canRead = {};
            var ds = resolveDatasource();
            var displayNameVal = trim(arguments.displayName);
            var emailVal = lCase(trim(arguments.email));
            var passwordVal = trim(arguments.password);
            var qFollower = queryNew("");
            var followerToken = "";
            var followerId = 0;
            var hashVal = "";
            var memberGateResult = {};

            if (streamIdVal LTE 0) {
                out.MESSAGE = "stream_id required";
                out.ERROR = { "MESSAGE"="stream_id is required." };
                return out;
            }
            if (!structCount(streamRow)) {
                out.MESSAGE = "Stream not found";
                out.ERROR = { "MESSAGE"="No voyage stream matched the provided stream id." };
                return out;
            }

            canRead = canReadStream(streamRow, arguments.shareToken, false);
            if (!canRead.allowed) {
                out.MESSAGE = "Forbidden";
                out.STATUS_CODE = 403;
                out.ERROR = { "CODE"=canRead.code, "MESSAGE"=canRead.message };
                return out;
            }

            memberGateResult = requireOwnerPremiumFollowAccess(streamRow.owner_user_id);
            if (!memberGateResult.SUCCESS) {
                return memberGateResult;
            }

            if (!len(displayNameVal)) {
                out.MESSAGE = "Display name required";
                out.ERROR = { "MESSAGE"="display_name is required." };
                return out;
            }
            if (len(displayNameVal) GT 120) {
                displayNameVal = left(displayNameVal, 120);
            }

            if (streamRow.privacy_mode EQ "password") {
                if (!len(trim(streamRow.password_hash))) {
                    out.MESSAGE = "Password configuration invalid";
                    out.ERROR = { "MESSAGE"="Stream password mode is enabled but no password hash is set." };
                    return out;
                }
                if (!len(passwordVal)) {
                    out.MESSAGE = "Password required";
                    out.STATUS_CODE = 403;
                    out.ERROR = { "CODE"="PASSWORD_REQUIRED", "MESSAGE"="Password is required for this stream." };
                    return out;
                }
                hashVal = uCase(hash(passwordVal, "SHA-256", "UTF-8"));
                if (hashVal NEQ uCase(trim(streamRow.password_hash))) {
                    out.MESSAGE = "Invalid password";
                    out.STATUS_CODE = 403;
                    out.ERROR = { "CODE"="INVALID_PASSWORD", "MESSAGE"="The password is incorrect." };
                    return out;
                }
            }

            if (len(emailVal)) {
                qFollower = queryExecute(
                    "SELECT id, access_token, is_blocked
                     FROM voyage_followers
                     WHERE stream_id = :streamId
                       AND email = :email
                     LIMIT 1",
                    {
                        streamId = { value=streamIdVal, cfsqltype="cf_sql_integer" },
                        email = { value=emailVal, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource=ds }
                );
            }

            if (qFollower.recordCount GT 0) {
                if (val(qFollower.is_blocked[1]) GT 0) {
                    out.MESSAGE = "Follower blocked";
                    out.STATUS_CODE = 403;
                    out.ERROR = { "CODE"="FOLLOWER_BLOCKED", "MESSAGE"="This follower has been blocked." };
                    return out;
                }

                followerId = val(qFollower.id[1]);
                followerToken = toString(qFollower.access_token[1]);

                queryExecute(
                    "UPDATE voyage_followers
                     SET display_name = :displayName,
                         last_seen_utc = UTC_TIMESTAMP()
                     WHERE id = :id",
                    {
                        displayName = { value=displayNameVal, cfsqltype="cf_sql_varchar" },
                        id = { value=followerId, cfsqltype="cf_sql_integer" }
                    },
                    { datasource=ds }
                );
            } else {
                followerToken = randomToken(40);
                queryExecute(
                    "INSERT INTO voyage_followers (
                        stream_id,
                        display_name,
                        email,
                        access_token,
                        is_blocked,
                        created_utc,
                        last_seen_utc
                     ) VALUES (
                        :streamId,
                        :displayName,
                        :email,
                        :accessToken,
                        0,
                        UTC_TIMESTAMP(),
                        UTC_TIMESTAMP()
                     )",
                    {
                        streamId = { value=streamIdVal, cfsqltype="cf_sql_integer" },
                        displayName = { value=displayNameVal, cfsqltype="cf_sql_varchar" },
                        email = { value=(len(emailVal) ? emailVal : ""), cfsqltype="cf_sql_varchar", null=!len(emailVal) },
                        accessToken = { value=followerToken, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource=ds }
                );

                qFollower = queryExecute(
                    "SELECT id
                     FROM voyage_followers
                     WHERE access_token = :accessToken
                     LIMIT 1",
                    {
                        accessToken = { value=followerToken, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource=ds }
                );
                followerId = (qFollower.recordCount GT 0 ? val(qFollower.id[1]) : 0);
            }

            out.SUCCESS = true;
            out.MESSAGE = "OK";
            out.follower_id = followerId;
            out.follower_token = followerToken;
            out.follower = {
                "id"=followerId,
                "display_name"=displayNameVal,
                "email"=emailVal
            };
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="toggleReaction" access="private" returntype="struct" output="false">
        <cfargument name="postId" type="numeric" required="true">
        <cfargument name="emoji" type="string" required="true">
        <cfargument name="followerToken" type="string" required="false" default="">
        <cfargument name="currentUserId" type="numeric" required="false" default="0">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unable to toggle reaction"
            };
            var postIdVal = val(arguments.postId);
            var emojiVal = lCase(trim(arguments.emoji));
            var ctx = {};
            var ds = resolveDatasource();
            var qExisting = queryNew("");
            var qCounts = queryNew("");
            var reactions = { "like"=0, "love"=0, "boat"=0, "wave"=0 };
            var limitRes = {};
            var i = 0;
            var nowActive = false;

            if (postIdVal LTE 0) {
                out.MESSAGE = "post_id required";
                out.ERROR = { "MESSAGE"="post_id is required." };
                return out;
            }
            if (!listFindNoCase("like,love,boat,wave", emojiVal)) {
                out.MESSAGE = "Invalid reaction";
                out.ERROR = { "MESSAGE"="emoji must be one of like,love,boat,wave." };
                return out;
            }

            ctx = resolveInteractionContext(postIdVal, arguments.followerToken, arguments.currentUserId);
            if (!ctx.SUCCESS) {
                return ctx;
            }

            limitRes = enforceRateLimit("reaction:" & ctx.follower.id & ":" & postIdVal, 1);
            if (!limitRes.allowed) {
                out.MESSAGE = "Too many requests";
                out.STATUS_CODE = 429;
                out.ERROR = { "CODE"="RATE_LIMIT", "MESSAGE"="Please wait before reacting again." };
                out.retry_after_seconds = limitRes.retry_after;
                return out;
            }

            qExisting = queryExecute(
                "SELECT id
                 FROM voyage_reactions
                 WHERE post_id = :postId
                   AND follower_id = :followerId
                   AND emoji = :emoji
                 LIMIT 1",
                {
                    postId = { value=postIdVal, cfsqltype="cf_sql_integer" },
                    followerId = { value=ctx.follower.id, cfsqltype="cf_sql_integer" },
                    emoji = { value=emojiVal, cfsqltype="cf_sql_varchar" }
                },
                { datasource=ds }
            );

            if (qExisting.recordCount GT 0) {
                queryExecute(
                    "DELETE FROM voyage_reactions
                     WHERE id = :id",
                    {
                        id = { value=val(qExisting.id[1]), cfsqltype="cf_sql_integer" }
                    },
                    { datasource=ds }
                );
                nowActive = false;
            } else {
                queryExecute(
                    "INSERT INTO voyage_reactions (post_id, follower_id, emoji, created_utc)
                     VALUES (:postId, :followerId, :emoji, UTC_TIMESTAMP())",
                    {
                        postId = { value=postIdVal, cfsqltype="cf_sql_integer" },
                        followerId = { value=ctx.follower.id, cfsqltype="cf_sql_integer" },
                        emoji = { value=emojiVal, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource=ds }
                );
                nowActive = true;
            }

            qCounts = queryExecute(
                "SELECT emoji, COUNT(*) AS cnt
                 FROM voyage_reactions
                 WHERE post_id = :postId
                 GROUP BY emoji",
                {
                    postId = { value=postIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );
            for (i = 1; i LTE qCounts.recordCount; i++) {
                reactions[lCase(trim(toString(qCounts.emoji[i])))] = val(qCounts.cnt[i]);
            }

            out.SUCCESS = true;
            out.MESSAGE = "OK";
            out.post_id = postIdVal;
            out.emoji = emojiVal;
            out.active = nowActive;
            out.reaction_counts = reactions;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="addComment" access="private" returntype="struct" output="false">
        <cfargument name="postId" type="numeric" required="true">
        <cfargument name="body" type="string" required="true">
        <cfargument name="followerToken" type="string" required="false" default="">
        <cfargument name="currentUserId" type="numeric" required="false" default="0">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unable to add comment"
            };
            var postIdVal = val(arguments.postId);
            var textVal = trim(arguments.body);
            var ctx = {};
            var ds = resolveDatasource();
            var insertResult = {};
            var commentId = 0;
            var qCreated = queryNew("");
            var limitRes = {};

            if (postIdVal LTE 0) {
                out.MESSAGE = "post_id required";
                out.ERROR = { "MESSAGE"="post_id is required." };
                return out;
            }
            if (!len(textVal)) {
                out.MESSAGE = "Comment required";
                out.ERROR = { "MESSAGE"="Comment text is required." };
                return out;
            }
            if (len(textVal) GT 500) {
                out.MESSAGE = "Comment too long";
                out.ERROR = { "MESSAGE"="Comment must be 500 characters or less." };
                return out;
            }

            ctx = resolveInteractionContext(postIdVal, arguments.followerToken, arguments.currentUserId);
            if (!ctx.SUCCESS) {
                return ctx;
            }

            limitRes = enforceRateLimit("comment:" & ctx.follower.id, 4);
            if (!limitRes.allowed) {
                out.MESSAGE = "Too many requests";
                out.STATUS_CODE = 429;
                out.ERROR = { "CODE"="RATE_LIMIT", "MESSAGE"="Please wait before posting another comment." };
                out.retry_after_seconds = limitRes.retry_after;
                return out;
            }

            queryExecute(
                "INSERT INTO voyage_comments (
                    post_id,
                    follower_id,
                    body,
                    is_deleted,
                    created_utc
                 ) VALUES (
                    :postId,
                    :followerId,
                    :body,
                    0,
                    UTC_TIMESTAMP()
                 )",
                {
                    postId = { value=postIdVal, cfsqltype="cf_sql_integer" },
                    followerId = { value=ctx.follower.id, cfsqltype="cf_sql_integer" },
                    body = { value=textVal, cfsqltype="cf_sql_varchar" }
                },
                { datasource=ds, result="insertResult" }
            );

            if (structKeyExists(insertResult, "generatedKey") AND isNumeric(insertResult.generatedKey)) {
                commentId = val(insertResult.generatedKey);
            }
            if (commentId LTE 0) {
                qCreated = queryExecute(
                    "SELECT id
                     FROM voyage_comments
                     WHERE post_id = :postId
                       AND follower_id = :followerId
                     ORDER BY id DESC
                     LIMIT 1",
                    {
                        postId = { value=postIdVal, cfsqltype="cf_sql_integer" },
                        followerId = { value=ctx.follower.id, cfsqltype="cf_sql_integer" }
                    },
                    { datasource=ds }
                );
                if (qCreated.recordCount GT 0) {
                    commentId = val(qCreated.id[1]);
                }
            }

            out.SUCCESS = true;
            out.MESSAGE = "OK";
            out.comment = {
                "id"=commentId,
                "post_id"=postIdVal,
                "display_name"=ctx.follower.display_name,
                "body"=textVal,
                "created_utc"=formatUtcDate(now())
            };
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="ownerCreatePost" access="private" returntype="struct" output="false">
        <cfargument name="streamId" type="numeric" required="true">
        <cfargument name="body" type="string" required="false" default="">
        <cfargument name="mediaUrl" type="string" required="false" default="">
        <cfargument name="currentUserId" type="numeric" required="false" default="0">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=(arguments.currentUserId GT 0),
                "MESSAGE"="Unable to create post"
            };
            var streamIdVal = val(arguments.streamId);
            var bodyVal = trim(arguments.body);
            var mediaUrlVal = trim(arguments.mediaUrl);
            var streamRow = {};
            var ds = resolveDatasource();
            var insertResult = {};
            var postIdVal = 0;
            var postTypeVal = "text";
            var titleVal = "";

            if (arguments.currentUserId LTE 0) {
                out.MESSAGE = "Unauthorized";
                out.AUTH = false;
                out.ERROR = { "MESSAGE"="Owner session required." };
                return out;
            }
            if (streamIdVal LTE 0) {
                out.MESSAGE = "stream_id required";
                out.ERROR = { "MESSAGE"="stream_id is required." };
                return out;
            }
            if (!len(bodyVal) AND !len(mediaUrlVal)) {
                out.MESSAGE = "Post content required";
                out.ERROR = { "MESSAGE"="Provide body text or media URL." };
                return out;
            }

            streamRow = readStream("", streamIdVal);
            if (!structCount(streamRow)) {
                out.MESSAGE = "Stream not found";
                out.ERROR = { "MESSAGE"="No voyage stream matched the provided stream id." };
                return out;
            }
            if (streamRow.owner_user_id NEQ arguments.currentUserId) {
                out.MESSAGE = "Forbidden";
                out.STATUS_CODE = 403;
                out.ERROR = { "MESSAGE"="Only the stream owner can create posts." };
                return out;
            }

            if (len(mediaUrlVal)) {
                postTypeVal = "photo";
            }
            if (len(bodyVal)) {
                titleVal = left(bodyVal, 80);
            } else {
                titleVal = "Photo update";
            }

            queryExecute(
                "INSERT INTO voyage_posts (
                    stream_id,
                    author_type,
                    author_user_id,
                    title,
                    body,
                    post_type,
                    media_url,
                    created_utc
                 ) VALUES (
                    :streamId,
                    'owner',
                    :ownerUserId,
                    :title,
                    :body,
                    :postType,
                    :mediaUrl,
                    UTC_TIMESTAMP()
                 )",
                {
                    streamId = { value=streamIdVal, cfsqltype="cf_sql_integer" },
                    ownerUserId = { value=arguments.currentUserId, cfsqltype="cf_sql_integer" },
                    title = { value=titleVal, cfsqltype="cf_sql_varchar" },
                    body = { value=bodyVal, cfsqltype="cf_sql_longvarchar" },
                    postType = { value=postTypeVal, cfsqltype="cf_sql_varchar" },
                    mediaUrl = { value=mediaUrlVal, cfsqltype="cf_sql_varchar" }
                },
                { datasource=ds, result="insertResult" }
            );

            if (structKeyExists(insertResult, "generatedKey") AND isNumeric(insertResult.generatedKey)) {
                postIdVal = val(insertResult.generatedKey);
            }

            out.SUCCESS = true;
            out.MESSAGE = "Post created";
            out.post_id = postIdVal;
            out.post = {
                "id"=postIdVal,
                "stream_id"=streamIdVal,
                "author_type"="owner",
                "title"=titleVal,
                "body"=bodyVal,
                "post_type"=postTypeVal,
                "media_url"=mediaUrlVal,
                "created_utc"=formatUtcDate(now()),
                "reaction_counts"={ "like"=0, "love"=0, "boat"=0, "wave"=0 },
                "viewer_reactions"={},
                "comments"=[]
            };
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="ownerCreatePostWithMediaInternal" access="private" returntype="struct" output="false">
        <cfargument name="streamId" type="numeric" required="true">
        <cfargument name="body" type="string" required="false" default="">
        <cfargument name="currentUserId" type="numeric" required="false" default="0">
        <cfset var out = {
            "SUCCESS"=false,
            "AUTH"=(arguments.currentUserId GT 0),
            "MESSAGE"="Unable to create post"
        }>
        <cfset var streamIdVal = val(arguments.streamId)>
        <cfset var bodyVal = trim(arguments.body)>
        <cfset var streamRow = {}>
        <cfset var uploadDir = "">
        <cfset var uploadResult = {}>
        <cfset var sourcePath = "">
        <cfset var generatedName = "">
        <cfset var finalPath = "">
        <cfset var fileExt = "">
        <cfset var mimeVal = "">
        <cfset var mediaUrlVal = "">
        <cfset var createRes = {}>
        <cfset var maxBytes = 5 * 1024 * 1024>
        <cfif arguments.currentUserId LTE 0>
            <cfset out.MESSAGE = "Unauthorized">
            <cfset out.AUTH = false>
            <cfset out.STATUS_CODE = 401>
            <cfset out.ERROR = { "MESSAGE"="Owner session required." }>
            <cfreturn out>
        </cfif>
        <cfif streamIdVal LTE 0>
            <cfset out.MESSAGE = "stream_id required">
            <cfset out.STATUS_CODE = 400>
            <cfset out.ERROR = { "MESSAGE"="stream_id is required." }>
            <cfreturn out>
        </cfif>
        <cfif !structKeyExists(form, "media_file") OR !len(trim(toString(form.media_file)))>
            <cfset out.MESSAGE = "Image file required">
            <cfset out.STATUS_CODE = 400>
            <cfset out.ERROR = { "MESSAGE"="Select one image to upload." }>
            <cfreturn out>
        </cfif>

        <cfset streamRow = readStream("", streamIdVal)>
        <cfif !structCount(streamRow)>
            <cfset out.MESSAGE = "Stream not found">
            <cfset out.STATUS_CODE = 404>
            <cfset out.ERROR = { "MESSAGE"="No voyage stream matched the provided stream id." }>
            <cfreturn out>
        </cfif>
        <cfif streamRow.owner_user_id NEQ arguments.currentUserId>
            <cfset out.MESSAGE = "Forbidden">
            <cfset out.STATUS_CODE = 403>
            <cfset out.ERROR = { "MESSAGE"="Only the stream owner can create posts." }>
            <cfreturn out>
        </cfif>

        <cfset uploadDir = resolveVoyageUploadDirectory(streamIdVal)>
        <cfif !directoryExists(uploadDir)>
            <cfset directoryCreate(uploadDir)>
        </cfif>

        <cftry>
            <cffile action="upload"
                fileField="media_file"
                destination="#uploadDir#"
                nameConflict="makeunique"
                accept="image/jpeg,image/pjpeg,image/png,image/webp,image/x-webp"
                result="uploadResult">
            <cfcatch>
                <cfset out.MESSAGE = "Invalid image upload">
                <cfset out.STATUS_CODE = 400>
                <cfset out.ERROR = { "MESSAGE"="Only JPG, PNG, and WebP images up to 5MB are allowed." }>
                <cfreturn out>
            </cfcatch>
        </cftry>

        <cfset sourcePath = uploadResult.serverDirectory & "/" & uploadResult.serverFile>
        <cfif val(uploadResult.fileSize) GT maxBytes>
            <cfif fileExists(sourcePath)><cfset fileDelete(sourcePath)></cfif>
            <cfset out.MESSAGE = "Image too large">
            <cfset out.STATUS_CODE = 400>
            <cfset out.ERROR = { "MESSAGE"="Image must be 5MB or smaller." }>
            <cfreturn out>
        </cfif>

        <cfset fileExt = lCase(trim(toString(uploadResult.serverFileExt)))>
        <cfset mimeVal = lCase(trim(toString((structKeyExists(uploadResult, "contentType") ? uploadResult.contentType : "") & "/" & (structKeyExists(uploadResult, "contentSubType") ? uploadResult.contentSubType : ""))))>
        <cfif !listFindNoCase("jpg,jpeg,png,webp", fileExt)>
            <cfif fileExists(sourcePath)><cfset fileDelete(sourcePath)></cfif>
            <cfset out.MESSAGE = "Invalid image type">
            <cfset out.STATUS_CODE = 400>
            <cfset out.ERROR = { "MESSAGE"="Only JPG, PNG, and WebP images are allowed." }>
            <cfreturn out>
        </cfif>
        <cfif len(mimeVal) AND !reFindNoCase("^image/(jpeg|pjpeg|png|webp|x-webp)$", mimeVal)>
            <cfif fileExists(sourcePath)><cfset fileDelete(sourcePath)></cfif>
            <cfset out.MESSAGE = "Invalid image type">
            <cfset out.STATUS_CODE = 400>
            <cfset out.ERROR = { "MESSAGE"="Only JPG, PNG, and WebP images are allowed." }>
            <cfreturn out>
        </cfif>

        <cfset generatedName = "post-" & dateTimeFormat(now(), "yyyymmddHHnnss") & "-" & lCase(left(replace(createUUID(), "-", "", "all"), 12)) & "." & fileExt>
        <cfset finalPath = uploadDir & "/" & generatedName>
        <cfset fileMove(sourcePath, finalPath)>
        <cfset mediaUrlVal = buildVoyageUploadUrl(streamIdVal, generatedName)>
        <cfset createRes = ownerCreatePost(streamIdVal, bodyVal, mediaUrlVal, arguments.currentUserId)>
        <cfif !createRes.SUCCESS AND fileExists(finalPath)>
            <cfset fileDelete(finalPath)>
        </cfif>
        <cfreturn createRes>
    </cffunction>

    <cffunction name="ownerDeletePost" access="private" returntype="struct" output="false">
        <cfargument name="postId" type="numeric" required="true">
        <cfargument name="currentUserId" type="numeric" required="false" default="0">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=(arguments.currentUserId GT 0),
                "MESSAGE"="Unable to delete post"
            };
            var postIdVal = val(arguments.postId);
            var ds = resolveDatasource();
            var qCheck = queryNew("");
            var mediaUrlVal = "";
            var streamIdVal = 0;
            var authorTypeVal = "";
            var postTypeVal = "";
            var eventTypeVal = "";

            if (arguments.currentUserId LTE 0) {
                out.MESSAGE = "Unauthorized";
                out.AUTH = false;
                out.ERROR = { "MESSAGE"="Owner session required." };
                return out;
            }
            if (postIdVal LTE 0) {
                out.MESSAGE = "post_id required";
                out.ERROR = { "MESSAGE"="post_id is required." };
                return out;
            }

            qCheck = queryExecute(
                "SELECT
                    vp.id,
                    vp.stream_id,
                    vp.author_type,
                    vp.post_type,
                    vp.event_type,
                    vp.media_url,
                    vs.owner_user_id
                 FROM voyage_posts vp
                 INNER JOIN voyage_streams vs ON vs.id = vp.stream_id
                 WHERE vp.id = :postId
                 LIMIT 1",
                {
                    postId = { value=postIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            if (qCheck.recordCount EQ 0) {
                out.MESSAGE = "Post not found";
                out.ERROR = { "MESSAGE"="No post matched the provided id." };
                return out;
            }
            if (val(qCheck.owner_user_id[1]) NEQ arguments.currentUserId) {
                out.MESSAGE = "Forbidden";
                out.STATUS_CODE = 403;
                out.ERROR = { "MESSAGE"="Only the stream owner can delete posts." };
                return out;
            }

            authorTypeVal = lCase(trim(toString(qCheck.author_type[1])));
            postTypeVal = lCase(trim(toString(qCheck.post_type[1])));
            eventTypeVal = trim(toString(qCheck.event_type[1]));
            if (authorTypeVal NEQ "owner" OR postTypeVal EQ "system_event" OR len(eventTypeVal)) {
                out.MESSAGE = "Post cannot be deleted";
                out.ERROR = { "MESSAGE"="Only owner-authored manual posts can be deleted." };
                return out;
            }

            mediaUrlVal = trim(toString(qCheck.media_url[1]));
            streamIdVal = val(qCheck.stream_id[1]);

            queryExecute(
                "DELETE FROM voyage_reactions
                 WHERE post_id = :postId",
                {
                    postId = { value=postIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            queryExecute(
                "DELETE FROM voyage_comments
                 WHERE post_id = :postId",
                {
                    postId = { value=postIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            deleteVoyageUploadFile(mediaUrlVal, streamIdVal);

            queryExecute(
                "DELETE FROM voyage_posts
                 WHERE id = :postId",
                {
                    postId = { value=postIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            out.SUCCESS = true;
            out.MESSAGE = "Post deleted";
            out.post_id = postIdVal;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="ownerDeleteComment" access="private" returntype="struct" output="false">
        <cfargument name="commentId" type="numeric" required="true">
        <cfargument name="currentUserId" type="numeric" required="false" default="0">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=(arguments.currentUserId GT 0),
                "MESSAGE"="Unable to delete comment"
            };
            var commentIdVal = val(arguments.commentId);
            var ds = resolveDatasource();
            var qCheck = queryNew("");

            if (arguments.currentUserId LTE 0) {
                out.MESSAGE = "Unauthorized";
                out.AUTH = false;
                out.ERROR = { "MESSAGE"="Owner session required." };
                return out;
            }
            if (commentIdVal LTE 0) {
                out.MESSAGE = "comment_id required";
                out.ERROR = { "MESSAGE"="comment_id is required." };
                return out;
            }

            qCheck = queryExecute(
                "SELECT
                    vc.id,
                    vs.owner_user_id
                 FROM voyage_comments vc
                 INNER JOIN voyage_posts vp ON vp.id = vc.post_id
                 INNER JOIN voyage_streams vs ON vs.id = vp.stream_id
                 WHERE vc.id = :commentId
                 LIMIT 1",
                {
                    commentId = { value=commentIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            if (qCheck.recordCount EQ 0) {
                out.MESSAGE = "Comment not found";
                out.ERROR = { "MESSAGE"="No comment matched the provided id." };
                return out;
            }
            if (val(qCheck.owner_user_id[1]) NEQ arguments.currentUserId) {
                out.MESSAGE = "Forbidden";
                out.STATUS_CODE = 403;
                out.ERROR = { "MESSAGE"="Only the stream owner can delete comments." };
                return out;
            }

            queryExecute(
                "UPDATE voyage_comments
                 SET is_deleted = 1,
                     deleted_utc = UTC_TIMESTAMP()
                 WHERE id = :commentId",
                {
                    commentId = { value=commentIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            out.SUCCESS = true;
            out.MESSAGE = "Comment deleted";
            out.comment_id = commentIdVal;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="ownerBlockFollower" access="private" returntype="struct" output="false">
        <cfargument name="followerId" type="numeric" required="true">
        <cfargument name="currentUserId" type="numeric" required="false" default="0">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=(arguments.currentUserId GT 0),
                "MESSAGE"="Unable to block follower"
            };
            var followerIdVal = val(arguments.followerId);
            var ds = resolveDatasource();
            var qCheck = queryNew("");

            if (arguments.currentUserId LTE 0) {
                out.MESSAGE = "Unauthorized";
                out.AUTH = false;
                out.ERROR = { "MESSAGE"="Owner session required." };
                return out;
            }
            if (followerIdVal LTE 0) {
                out.MESSAGE = "follower_id required";
                out.ERROR = { "MESSAGE"="follower_id is required." };
                return out;
            }

            qCheck = queryExecute(
                "SELECT
                    vf.id,
                    vs.owner_user_id
                 FROM voyage_followers vf
                 INNER JOIN voyage_streams vs ON vs.id = vf.stream_id
                 WHERE vf.id = :followerId
                 LIMIT 1",
                {
                    followerId = { value=followerIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            if (qCheck.recordCount EQ 0) {
                out.MESSAGE = "Follower not found";
                out.ERROR = { "MESSAGE"="No follower matched the provided id." };
                return out;
            }
            if (val(qCheck.owner_user_id[1]) NEQ arguments.currentUserId) {
                out.MESSAGE = "Forbidden";
                out.STATUS_CODE = 403;
                out.ERROR = { "MESSAGE"="Only the stream owner can block followers." };
                return out;
            }

            queryExecute(
                "UPDATE voyage_followers
                 SET is_blocked = 1
                 WHERE id = :followerId",
                {
                    followerId = { value=followerIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            out.SUCCESS = true;
            out.MESSAGE = "Follower blocked";
            out.follower_id = followerIdVal;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="ownerEnsureStream" access="private" returntype="struct" output="false">
        <cfargument name="currentUserId" type="numeric" required="false" default="0">
        <cfscript>
            var ds = resolveDatasource();
            var storageCheck = checkVoyageStorageReady();
            var userIdText = toString(arguments.currentUserId);
            var canonicalPlan = {};
            var qInst = queryNew("");
            var qPlan = queryNew("");
            var qStream = queryNew("");
            var qSlug = queryNew("");
            var streamIdVal = 0;
            var slugVal = "";
            var shareTokenVal = "";
            var slugBase = "";
            var slugCandidate = "";
            var routeMap = {};
            var ensurePins = [];
            var followPath = "";
            var followUrl = "";
            var responseData = {};
            var routeNameVal = "";
            var floatPlanIdVal = 0;
            var routeInstanceIdVal = 0;
            var routeCodeVal = "";
            var fpwBasePath = resolveFpwBasePath();
            var createSuffix = "";

            if (arguments.currentUserId LTE 0) {
                return buildApiEnvelope(
                    success=false,
                    code="UNAUTHORIZED",
                    message="Owner session required.",
                    data={},
                    auth=false
                );
            }

            if (!storageCheck.ready) {
                return buildApiEnvelope(
                    success=false,
                    code="STREAM_STORAGE_NOT_READY",
                    message="Voyage stream tables not installed.",
                    data={ "missing_tables"=storageCheck.missing_tables },
                    auth=true
                );
            }

            canonicalPlan = resolveCanonicalActiveFloatPlan(arguments.currentUserId, 0);
            if (!canonicalPlan.SUCCESS) {
                return buildApiEnvelope(
                    success=false,
                    code=(structKeyExists(canonicalPlan, "ERROR") ? canonicalPlan.ERROR : "NO_ACTIVE_PLAN"),
                    message=canonicalPlan.MESSAGE,
                    data={},
                    auth=true
                );
            }

            floatPlanIdVal = canonicalPlan.FLOATPLANID;
            routeInstanceIdVal = canonicalPlan.ROUTE_INSTANCE_ID;

            qPlan = queryExecute(
                "SELECT floatplanId, floatPlanName
                 FROM floatplans
                 WHERE floatplanId = :floatplanId
                   AND userId = :uid
                 LIMIT 1",
                {
                    floatplanId = { value=floatPlanIdVal, cfsqltype="cf_sql_integer" },
                    uid = { value=arguments.currentUserId, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            if (qInst.recordCount EQ 0) {
                qInst = queryExecute(
                    "SELECT
                        ri.id,
                        ri.generated_route_id,
                        ri.generated_route_code,
                        lr.name AS route_name,
                        lr.short_code AS route_code
                     FROM route_instances ri
                     LEFT JOIN loop_routes lr ON lr.id = ri.generated_route_id
                     WHERE ri.id = :routeInstanceId
                       AND ri.user_id = :uidText
                     LIMIT 1",
                    {
                        routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" },
                        uidText = { value=userIdText, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource=ds }
                );
            }

            if (qInst.recordCount EQ 0) {
                return buildApiEnvelope(
                    success=false,
                    code="ROUTE_INSTANCE_NOT_FOUND",
                    message="No route instance found for the active trip.",
                    data={ "floatplan_id"=floatPlanIdVal, "routeInstanceId"=routeInstanceIdVal },
                    auth=true
                );
            }

            routeInstanceIdVal = val(qInst.id[1]);
            routeCodeVal = trim(toString(isNull(qInst.generated_route_code[1]) ? "" : qInst.generated_route_code[1]));
            if (!len(routeCodeVal)) {
                routeCodeVal = trim(toString(isNull(qInst.route_code[1]) ? "" : qInst.route_code[1]));
            }
            routeNameVal = trim(toString(isNull(qInst.route_name[1]) ? "" : qInst.route_name[1]));
            if (!len(routeNameVal) AND qPlan.recordCount GT 0) {
                routeNameVal = trim(toString(isNull(qPlan.floatPlanName[1]) ? "" : qPlan.floatPlanName[1]));
            }

            qStream = queryExecute(
                "SELECT
                    id,
                    slug,
                    share_token,
                    privacy_mode,
                    allow_interactions
                 FROM voyage_streams
                 WHERE floatplan_id = :floatplanId
                   AND owner_user_id = :ownerUserId
                 ORDER BY id DESC
                 LIMIT 1",
                {
                    floatplanId = { value=floatPlanIdVal, cfsqltype="cf_sql_integer" },
                    ownerUserId = { value=arguments.currentUserId, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            if (qStream.recordCount EQ 0) {
                slugBase = normalizeSlug(routeCodeVal);
                if (!len(slugBase)) {
                    slugBase = "trip-" & floatPlanIdVal;
                }
                if (len(slugBase) GT 104) {
                    slugBase = left(slugBase, 104);
                }

                do {
                    createSuffix = lCase(left(replace(createUUID(), "-", "", "all"), 6));
                    slugCandidate = slugBase & "-" & createSuffix;
                    qSlug = queryExecute(
                        "SELECT id
                         FROM voyage_streams
                         WHERE slug = :slug
                         LIMIT 1",
                        {
                            slug = { value=slugCandidate, cfsqltype="cf_sql_varchar" }
                        },
                        { datasource=ds }
                    );
                    if (qSlug.recordCount EQ 0) {
                        break;
                    }
                } while (true);

                shareTokenVal = randomToken(64);
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
                        :floatplanId,
                        :ownerUserId,
                        :slug,
                        :shareToken,
                        'public',
                        1,
                        UTC_TIMESTAMP(),
                        UTC_TIMESTAMP()
                     )",
                    {
                        floatplanId = { value=floatPlanIdVal, cfsqltype="cf_sql_integer" },
                        ownerUserId = { value=arguments.currentUserId, cfsqltype="cf_sql_integer" },
                        slug = { value=slugCandidate, cfsqltype="cf_sql_varchar" },
                        shareToken = { value=shareTokenVal, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource=ds }
                );

                qStream = queryExecute(
                    "SELECT
                        id,
                        slug,
                        share_token,
                        privacy_mode,
                        allow_interactions
                     FROM voyage_streams
                     WHERE floatplan_id = :floatplanId
                       AND owner_user_id = :ownerUserId
                     ORDER BY id DESC
                     LIMIT 1",
                    {
                        floatplanId = { value=floatPlanIdVal, cfsqltype="cf_sql_integer" },
                        ownerUserId = { value=arguments.currentUserId, cfsqltype="cf_sql_integer" }
                    },
                    { datasource=ds }
                );
            }

            if (qStream.recordCount EQ 0) {
                return buildApiEnvelope(
                    success=false,
                    code="STREAM_CREATE_FAILED",
                    message="Unable to create or load voyage stream.",
                    data={ "routeInstanceId"=routeInstanceIdVal, "floatplan_id"=floatPlanIdVal },
                    auth=true
                );
            }

            streamIdVal = val(qStream.id[1]);
            slugVal = (isNull(qStream.slug[1]) ? "" : toString(qStream.slug[1]));
            shareTokenVal = (isNull(qStream.share_token[1]) ? "" : toString(qStream.share_token[1]));

            routeMap = buildRouteMapData(routeInstanceIdVal, arguments.currentUserId, 0);
            ensurePins = normalizeEnsurePins(structKeyExists(routeMap, "pins") ? routeMap.pins : []);

            followPath = fpwBasePath & "/app/follow.cfm?slug=" & urlEncodedFormat(slugVal) & "&t=" & urlEncodedFormat(shareTokenVal);
            followUrl = buildAbsoluteUrl(followPath);

            responseData = {
                "stream"={
                    "id"=streamIdVal,
                    "slug"=slugVal,
                    "share_token"=shareTokenVal,
                    "privacy_mode"=(isNull(qStream.privacy_mode[1]) ? "public" : toString(qStream.privacy_mode[1])),
                    "allow_interactions"=(isNull(qStream.allow_interactions[1]) ? 0 : val(qStream.allow_interactions[1]))
                },
                "follow"={
                    "path"=followPath,
                    "url"=followUrl
                },
                "route"={
                    "routeCode"=routeCodeVal,
                    "route_name"=routeNameVal,
                    "routeInstanceId"=routeInstanceIdVal,
                    "floatplan_id"=floatPlanIdVal
                },
                "map"={
                    "pins"=ensurePins,
                    "routeGeo"=(structKeyExists(routeMap, "route_geo") ? routeMap.route_geo : { "type"="MultiLineString", "coordinates"=[] })
                }
            };

            return buildApiEnvelope(
                success=true,
                code="OK",
                message="Follower page ready.",
                data=responseData,
                auth=true
            );
        </cfscript>
    </cffunction>

    <cffunction name="resolveCanonicalActiveFloatPlan" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="expectedFloatPlanId" type="numeric" required="false" default="0">
        <cfscript>
            var result = {
                "SUCCESS"=false,
                "success"=false,
                "MESSAGE"="No active trip is available."
            };
            var floatPlanComponent = "";
            var currentGroup = {};

            if (arguments.userId LTE 0) {
                result.ERROR = "UNAUTHORIZED";
                result.MESSAGE = "Owner session required.";
                return result;
            }

            try {
                floatPlanComponent = createObject("component", "fpw.api.v1.floatplan");
            } catch (any floatPlanPathErr) {
                floatPlanComponent = createObject("component", "api.v1.floatplan");
            }

            currentGroup = floatPlanComponent.resolveCurrentRouteFloatPlanGroup(arguments.userId);
            if (!isStruct(currentGroup)) {
                result.ERROR = "NO_ACTIVE_PLAN";
                result.MESSAGE = "No active trip is available.";
                return result;
            }

            if (structKeyExists(currentGroup, "ERROR") AND trim(toString(currentGroup.ERROR)) EQ "MULTIPLE_ACTIVE_GROUPS") {
                result.ERROR = "MULTIPLE_ACTIVE_PLANS";
                result.MESSAGE = "Multiple active trips were found. Trip Page is unavailable.";
                return result;
            }

            if (!currentGroup.SUCCESS OR !currentGroup.IS_ACTIVE) {
                result.ERROR = "NO_ACTIVE_PLAN";
                result.MESSAGE = "No active trip is available.";
                return result;
            }

            result.FLOATPLANID = val(currentGroup.FLOATPLANID);
            result.USERID = arguments.userId;
            result.FLOATPLANNAME = trim(toString(structKeyExists(currentGroup, "FLOATPLAN_NAME") ? currentGroup.FLOATPLAN_NAME : ""));
            result.ROUTE_INSTANCE_ID = val(structKeyExists(currentGroup, "ROUTE_INSTANCE_ID") ? currentGroup.ROUTE_INSTANCE_ID : 0);
            result.ROUTE_DAY_NUMBER = val(structKeyExists(currentGroup, "ROUTE_DAY_NUMBER") ? currentGroup.ROUTE_DAY_NUMBER : 0);
            result.STATUS = trim(toString(structKeyExists(currentGroup, "STATUS") ? currentGroup.STATUS : ""));

            if (arguments.expectedFloatPlanId GT 0 AND result.FLOATPLANID NEQ arguments.expectedFloatPlanId) {
                result.ERROR = "ACTIVE_PLAN_MISMATCH";
                result.MESSAGE = "This Trip Page is not linked to the active trip.";
                return result;
            }

            if (result.ROUTE_INSTANCE_ID LTE 0) {
                result.ERROR = "ROUTE_REQUIRED";
                result.MESSAGE = "The active trip must be linked to a route.";
                return result;
            }

            result.SUCCESS = true;
            result.success = true;
            return result;
        </cfscript>
    </cffunction>

    <cffunction name="seedDemoStream" access="private" returntype="struct" output="false">
        <cfargument name="slug" type="string" required="false" default="">
        <cfargument name="currentUserId" type="numeric" required="false" default="0">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=(arguments.currentUserId GT 0),
                "MESSAGE"="Unable to seed demo stream"
            };
            var ds = resolveDatasource();
            var canonicalPlan = {};
            var qPlan = queryNew("");
            var qStream = queryNew("");
            var qPostCount = queryNew("");
            var streamIdVal = 0;
            var slugVal = normalizeSlug(arguments.slug);
            var tokenVal = "";
            var candidateSlug = "";
            var qSlug = queryNew("");
            var followerToken = "";
            var qFollower = queryNew("");
            var followerIdVal = 0;
            var qPosts = queryNew("");
            var firstPostId = 0;
            var secondPostId = 0;
            var thirdPostId = 0;

            if (!isDevEnv()) {
                out.MESSAGE = "Disabled";
                out.STATUS_CODE = 403;
                out.ERROR = { "CODE"="DEV_ONLY", "MESSAGE"="seedDemoStream is available in local dev only." };
                return out;
            }
            if (arguments.currentUserId LTE 0) {
                out.MESSAGE = "Unauthorized";
                out.AUTH = false;
                out.ERROR = { "MESSAGE"="A logged-in owner session is required." };
                return out;
            }

            canonicalPlan = resolveCanonicalActiveFloatPlan(arguments.currentUserId, 0);
            if (!canonicalPlan.SUCCESS) {
                out.MESSAGE = canonicalPlan.MESSAGE;
                out.ERROR = {
                    "CODE"=(structKeyExists(canonicalPlan, "ERROR") ? canonicalPlan.ERROR : "NO_ACTIVE_PLAN"),
                    "MESSAGE"=canonicalPlan.MESSAGE
                };
                return out;
            }

            qPlan = queryExecute(
                "SELECT floatplanId, floatPlanName
                 FROM floatplans
                 WHERE floatplanId = :floatplanId
                   AND userId = :uid
                 LIMIT 1",
                {
                    floatplanId = { value=canonicalPlan.FLOATPLANID, cfsqltype="cf_sql_integer" },
                    uid = { value=arguments.currentUserId, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            if (qPlan.recordCount EQ 0) {
                out.MESSAGE = "No float plan found";
                out.ERROR = { "MESSAGE"="The active trip could not be loaded for the demo stream." };
                return out;
            }

            if (!len(slugVal)) {
                slugVal = "demo-voyage-" & arguments.currentUserId;
            }

            qStream = queryExecute(
                "SELECT id, slug, share_token
                 FROM voyage_streams
                 WHERE owner_user_id = :uid
                   AND floatplan_id = :planId
                 ORDER BY id DESC
                 LIMIT 1",
                {
                    uid = { value=arguments.currentUserId, cfsqltype="cf_sql_integer" },
                    planId = { value=val(qPlan.floatplanId[1]), cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            if (qStream.recordCount GT 0) {
                streamIdVal = val(qStream.id[1]);
                slugVal = toString(qStream.slug[1]);
                tokenVal = toString(qStream.share_token[1]);
            } else {
                candidateSlug = slugVal;
                do {
                    qSlug = queryExecute(
                        "SELECT id
                         FROM voyage_streams
                         WHERE slug = :slug
                         LIMIT 1",
                        {
                            slug = { value=candidateSlug, cfsqltype="cf_sql_varchar" }
                        },
                        { datasource=ds }
                    );
                    if (qSlug.recordCount EQ 0) {
                        slugVal = candidateSlug;
                        break;
                    }
                    candidateSlug = slugVal & "-" & lCase(left(replace(createUUID(), "-", "", "all"), 4));
                } while (true);

                tokenVal = randomToken(32);
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
                        :floatplanId,
                        :ownerUserId,
                        :slug,
                        :shareToken,
                        'public',
                        1,
                        UTC_TIMESTAMP(),
                        UTC_TIMESTAMP()
                     )",
                    {
                        floatplanId = { value=val(qPlan.floatplanId[1]), cfsqltype="cf_sql_integer" },
                        ownerUserId = { value=arguments.currentUserId, cfsqltype="cf_sql_integer" },
                        slug = { value=slugVal, cfsqltype="cf_sql_varchar" },
                        shareToken = { value=tokenVal, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource=ds }
                );

                qStream = queryExecute(
                    "SELECT id
                     FROM voyage_streams
                     WHERE slug = :slug
                     LIMIT 1",
                    {
                        slug = { value=slugVal, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource=ds }
                );
                streamIdVal = (qStream.recordCount GT 0 ? val(qStream.id[1]) : 0);
            }

            qPostCount = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM voyage_posts
                 WHERE stream_id = :streamId",
                {
                    streamId = { value=streamIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            followerToken = "";
            qFollower = queryExecute(
                "SELECT id, access_token
                 FROM voyage_followers
                 WHERE stream_id = :streamId
                 ORDER BY id ASC
                 LIMIT 1",
                {
                    streamId = { value=streamIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );
            if (qFollower.recordCount GT 0) {
                followerIdVal = val(qFollower.id[1]);
                followerToken = toString(qFollower.access_token[1]);
            } else {
                followerToken = randomToken(40);
                queryExecute(
                    "INSERT INTO voyage_followers (
                        stream_id,
                        display_name,
                        email,
                        access_token,
                        is_blocked,
                        created_utc,
                        last_seen_utc
                     ) VALUES (
                        :streamId,
                        'Family Viewer',
                        NULL,
                        :accessToken,
                        0,
                        UTC_TIMESTAMP(),
                        UTC_TIMESTAMP()
                     )",
                    {
                        streamId = { value=streamIdVal, cfsqltype="cf_sql_integer" },
                        accessToken = { value=followerToken, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource=ds }
                );
                qFollower = queryExecute(
                    "SELECT id
                     FROM voyage_followers
                     WHERE access_token = :accessToken
                     LIMIT 1",
                    {
                        accessToken = { value=followerToken, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource=ds }
                );
                followerIdVal = (qFollower.recordCount GT 0 ? val(qFollower.id[1]) : 0);
            }

            if (qPostCount.recordCount GT 0 AND val(qPostCount.cnt[1]) EQ 0) {
                queryExecute(
                    "INSERT INTO voyage_posts (
                        stream_id,
                        author_type,
                        author_user_id,
                        title,
                        body,
                        post_type,
                        event_type,
                        location_label,
                        created_utc
                     ) VALUES
                     (:streamId, 'system', :ownerUserId, 'Checked in - All good', 'Crew checked in safely and remains on schedule.', 'system_event', 'checkin', 'Current position updated', DATE_SUB(UTC_TIMESTAMP(), INTERVAL 2 HOUR)),
                     (:streamId, 'system', :ownerUserId, 'Lock completed', 'Completed lock transit without delays.', 'system_event', 'lock_complete', 'Lock zone', DATE_SUB(UTC_TIMESTAMP(), INTERVAL 4 HOUR)),
                     (:streamId, 'owner', :ownerUserId, 'Morning update', 'Calm water this morning and making steady progress.', 'photo', 'wildlife', 'Near ICW marker', DATE_SUB(UTC_TIMESTAMP(), INTERVAL 6 HOUR))",
                    {
                        streamId = { value=streamIdVal, cfsqltype="cf_sql_integer" },
                        ownerUserId = { value=arguments.currentUserId, cfsqltype="cf_sql_integer" }
                    },
                    { datasource=ds }
                );

                qPosts = queryExecute(
                    "SELECT id
                     FROM voyage_posts
                     WHERE stream_id = :streamId
                     ORDER BY id DESC
                     LIMIT 3",
                    {
                        streamId = { value=streamIdVal, cfsqltype="cf_sql_integer" }
                    },
                    { datasource=ds }
                );

                if (qPosts.recordCount GTE 1) firstPostId = val(qPosts.id[1]);
                if (qPosts.recordCount GTE 2) secondPostId = val(qPosts.id[2]);
                if (qPosts.recordCount GTE 3) thirdPostId = val(qPosts.id[3]);

                if (followerIdVal GT 0 AND firstPostId GT 0) {
                    queryExecute(
                        "INSERT IGNORE INTO voyage_reactions (post_id, follower_id, emoji, created_utc)
                         VALUES
                         (:p1, :fid, 'like', UTC_TIMESTAMP()),
                         (:p1, :fid, 'love', UTC_TIMESTAMP())",
                        {
                            p1 = { value=firstPostId, cfsqltype="cf_sql_integer" },
                            fid = { value=followerIdVal, cfsqltype="cf_sql_integer" }
                        },
                        { datasource=ds }
                    );
                }
                if (followerIdVal GT 0 AND secondPostId GT 0) {
                    queryExecute(
                        "INSERT IGNORE INTO voyage_comments (post_id, follower_id, body, is_deleted, created_utc)
                         VALUES (:postId, :fid, 'Following along. Great update!', 0, UTC_TIMESTAMP())",
                        {
                            postId = { value=secondPostId, cfsqltype="cf_sql_integer" },
                            fid = { value=followerIdVal, cfsqltype="cf_sql_integer" }
                        },
                        { datasource=ds }
                    );
                }
                if (followerIdVal GT 0 AND thirdPostId GT 0) {
                    queryExecute(
                        "INSERT IGNORE INTO voyage_reactions (post_id, follower_id, emoji, created_utc)
                         VALUES (:postId, :fid, 'wave', UTC_TIMESTAMP())",
                        {
                            postId = { value=thirdPostId, cfsqltype="cf_sql_integer" },
                            fid = { value=followerIdVal, cfsqltype="cf_sql_integer" }
                        },
                        { datasource=ds }
                    );
                }
            }

            out.SUCCESS = true;
            out.MESSAGE = "Demo stream ready";
            out.stream = {
                "id"=streamIdVal,
                "slug"=slugVal,
                "share_token"=tokenVal,
                "follower_token"=followerToken,
                "floatplan_id"=val(qPlan.floatplanId[1]),
                "title"=(isNull(qPlan.floatPlanName[1]) ? "Voyage" : toString(qPlan.floatPlanName[1]))
            };
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="buildRouteMapData" access="public" returntype="struct" output="false">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfargument name="ownerUserId" type="numeric" required="true">
        <cfargument name="fallbackDays" type="numeric" required="false" default="0">
        <cfscript>
            var routeMapGeometryService = createRouteMapGeometryService();
            return routeMapGeometryService.buildRouteMapData(
                routeInstanceId=arguments.routeInstanceId,
                ownerUserId=arguments.ownerUserId,
                fallbackDays=arguments.fallbackDays
            );

            var out = {
                "route_geo"={ "type"="MultiLineString", "coordinates"=[] },
                "pins"=[],
                "current"={},
                "total_nm"=0,
                "total_locks"=0,
                "total_days"=(arguments.fallbackDays GT 0 ? arguments.fallbackDays : 0),
                "remaining_nm"=0,
                "location_label"="",
                "next_stop_label"="",
                "awaiting_departure"=false,
                "active_leg_order"=0,
                "active_leg_start_name"="",
                "active_leg_end_name"="",
                "active_leg_start_lat"="",
                "active_leg_start_lng"="",
                "active_leg_end_lat"="",
                "active_leg_end_lng"=""
            };
            var routeInstanceIdVal = val(arguments.routeInstanceId);
            var ds = resolveDatasource();
            var qLegs = queryNew("");
            var qProgress = queryNew("");
            var qCurrentLeg = queryNew("");
            var qNextLeg = queryNew("");
            var qRouteInstance = queryNew("");
            var qLegCoords = queryNew("");
            var i = 0;
            var pt = {};
            var pointList = [];
            var routeSegments = [];
            var segmentCoords = [];
            var startLat = 0.0;
            var startLng = 0.0;
            var endLat = 0.0;
            var endLng = 0.0;
            var startName = "";
            var endName = "";
            var completedOrder = 0;
            var hasStartCoord = false;
            var hasEndCoord = false;
            var completedNm = 0;
            var startLatRaw = "";
            var startLngRaw = "";
            var endLatRaw = "";
            var endLngRaw = "";
            var legOrderVal = 0;
            var activeStartedLegOrder = 0;
            var pendingLegOrder = 0;
            var progressStatusByLeg = {};
            var progressStartedByLeg = {};
            var progressKey = "";
            var progressStatusVal = "";
            var generatedRouteId = 0;
            var originalCustomRouteId = 0;
            var routeInstanceInputsRaw = "";
            var routeInstanceInputs = {};
            var templateRouteCode = "";
            var routeLegIdVal = 0;
            var segmentIdVal = 0;
            var routeLookupIdVal = 0;
            var routeLegLookupIdVal = 0;
            var useRouteLegOrderFallback = false;

            if (routeInstanceIdVal LTE 0) {
                return out;
            }

            qRouteInstance = queryExecute(
                "SELECT generated_route_id, template_route_code, routegen_inputs_json
                 FROM route_instances
                 WHERE id = :routeInstanceId
                 LIMIT 1",
                {
                    routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );
            if (qRouteInstance.recordCount GT 0 AND !isNull(qRouteInstance.generated_route_id[1])) {
                generatedRouteId = val(qRouteInstance.generated_route_id[1]);
            }
            if (qRouteInstance.recordCount GT 0 AND !isNull(qRouteInstance.template_route_code[1])) {
                templateRouteCode = uCase(trim(toString(qRouteInstance.template_route_code[1])));
            }
            if (qRouteInstance.recordCount GT 0 AND !isNull(qRouteInstance.routegen_inputs_json[1])) {
                routeInstanceInputsRaw = trim(toString(qRouteInstance.routegen_inputs_json[1]));
            }
            if (templateRouteCode EQ "MY_ROUTE" AND len(routeInstanceInputsRaw)) {
                try {
                    routeInstanceInputs = deserializeJSON(routeInstanceInputsRaw);
                } catch (any routeInputsErr) {
                    routeInstanceInputs = {};
                }
                if (
                    isStruct(routeInstanceInputs)
                    AND structKeyExists(routeInstanceInputs, "route_id")
                    AND isNumeric(routeInstanceInputs.route_id)
                    AND val(routeInstanceInputs.route_id) GT 0
                ) {
                    originalCustomRouteId = val(routeInstanceInputs.route_id);
                }
            }

            qLegs = queryExecute(
                "SELECT
                    id,
                    leg_order,
                    segment_id,
                    source_loop_segment_id,
                    start_name,
                    end_name,
                    start_lat,
                    start_lng,
                    end_lat,
                    end_lng,
                    base_dist_nm,
                    lock_count
                 FROM route_instance_legs
                 WHERE route_instance_id = :routeInstanceId
                 ORDER BY leg_order ASC, id ASC",
                {
                    routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            if (qLegs.recordCount EQ 0) {
                return out;
            }

            out.total_days = max(out.total_days, qLegs.recordCount);

            for (i = 1; i LTE qLegs.recordCount; i++) {
                out.total_nm += (isNull(qLegs.base_dist_nm[i]) ? 0 : val(qLegs.base_dist_nm[i]));
                out.total_locks += (isNull(qLegs.lock_count[i]) ? 0 : val(qLegs.lock_count[i]));

                startLatRaw = (isNull(qLegs.start_lat[i]) ? "" : trim(toString(qLegs.start_lat[i])));
                startLngRaw = (isNull(qLegs.start_lng[i]) ? "" : trim(toString(qLegs.start_lng[i])));
                endLatRaw = (isNull(qLegs.end_lat[i]) ? "" : trim(toString(qLegs.end_lat[i])));
                endLngRaw = (isNull(qLegs.end_lng[i]) ? "" : trim(toString(qLegs.end_lng[i])));
                legOrderVal = (isNull(qLegs.leg_order[i]) ? 0 : val(qLegs.leg_order[i]));
                routeLegIdVal = (
                    isNull(qLegs.source_loop_segment_id[i]) OR val(qLegs.source_loop_segment_id[i]) LTE 0
                        ? val(qLegs.id[i])
                        : val(qLegs.source_loop_segment_id[i])
                );
                segmentIdVal = (isNull(qLegs.segment_id[i]) ? 0 : val(qLegs.segment_id[i]));
                routeLookupIdVal = generatedRouteId;
                routeLegLookupIdVal = routeLegIdVal;
                useRouteLegOrderFallback = false;
                if (
                    originalCustomRouteId GT 0
                    AND segmentIdVal LTE 0
                    AND (
                        isNull(qLegs.source_loop_segment_id[i])
                        OR val(qLegs.source_loop_segment_id[i]) LTE 0
                    )
                ) {
                    routeLookupIdVal = originalCustomRouteId;
                    routeLegLookupIdVal = 0;
                    useRouteLegOrderFallback = (legOrderVal GT 0);
                }
                segmentCoords = loadFollowRouteSegmentCoordinates(
                    ownerUserId=arguments.ownerUserId,
                    routeId=routeLookupIdVal,
                    routeLegId=routeLegLookupIdVal,
                    routeLegOrder=legOrderVal,
                    segmentId=segmentIdVal,
                    allowRouteLegOrderFallback=useRouteLegOrderFallback
                );
                if (arrayLen(segmentCoords) GTE 2) {
                    arrayAppend(routeSegments, segmentCoords);
                }
                hasStartCoord = (len(startLatRaw) AND len(startLngRaw) AND isNumeric(startLatRaw) AND isNumeric(startLngRaw));
                hasEndCoord = (len(endLatRaw) AND len(endLngRaw) AND isNumeric(endLatRaw) AND isNumeric(endLngRaw));
                startName = (isNull(qLegs.start_name[i]) ? "Start" : trim(toString(qLegs.start_name[i])));
                endName = (isNull(qLegs.end_name[i]) ? "End" : trim(toString(qLegs.end_name[i])));

                if (hasStartCoord) {
                    startLat = val(startLatRaw);
                    startLng = val(startLngRaw);
                    if (arrayLen(pointList) EQ 0) {
                        pointList = appendUniqueRoutePoint(
                            pointList=pointList,
                            lat=startLat,
                            lng=startLng,
                            label=(len(startName) ? startName : "Start"),
                            minDistanceMeters=20
                        );
                    }
                }

                if (hasEndCoord) {
                    endLat = val(endLatRaw);
                    endLng = val(endLngRaw);
                    pointList = appendUniqueRoutePoint(
                        pointList=pointList,
                        lat=endLat,
                        lng=endLng,
                        label=(len(endName) ? endName : "End"),
                        minDistanceMeters=20
                    );
                }
            }

            if (arrayLen(pointList) EQ 0) {
                try {
                    qLegCoords = queryExecute(
                        "SELECT
                            ril.leg_order,
                            COALESCE(
                                NULLIF(TRIM(ril.start_lat), ''),
                                pStart.lat
                            ) AS start_lat,
                            COALESCE(
                                NULLIF(TRIM(ril.start_lng), ''),
                                pStart.lng
                            ) AS start_lng,
                            COALESCE(
                                NULLIF(TRIM(ril.end_lat), ''),
                                pEnd.lat
                            ) AS end_lat,
                            COALESCE(
                                NULLIF(TRIM(ril.end_lng), ''),
                                pEnd.lng
                            ) AS end_lng,
                            COALESCE(NULLIF(TRIM(ril.start_name), ''), 'Start') AS start_label,
                            COALESCE(NULLIF(TRIM(ril.end_name), ''), 'End') AS end_label
                         FROM route_instance_legs ril
                         LEFT JOIN ports pStart
                           ON pStart.id = (
                                SELECT p1.id
                                FROM ports p1
                                WHERE TRIM(p1.name) = TRIM(ril.start_name)
                                ORDER BY p1.id ASC
                                LIMIT 1
                           )
                         LEFT JOIN ports pEnd
                           ON pEnd.id = (
                                SELECT p2.id
                                FROM ports p2
                                WHERE TRIM(p2.name) = TRIM(ril.end_name)
                                ORDER BY p2.id ASC
                                LIMIT 1
                           )
                         WHERE ril.route_instance_id = :routeInstanceId
                         ORDER BY ril.leg_order ASC, ril.id ASC",
                        {
                            routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" }
                        },
                        { datasource=ds }
                    );

                    for (i = 1; i LTE qLegCoords.recordCount; i++) {
                        startLatRaw = (isNull(qLegCoords.start_lat[i]) ? "" : trim(toString(qLegCoords.start_lat[i])));
                        startLngRaw = (isNull(qLegCoords.start_lng[i]) ? "" : trim(toString(qLegCoords.start_lng[i])));
                        endLatRaw = (isNull(qLegCoords.end_lat[i]) ? "" : trim(toString(qLegCoords.end_lat[i])));
                        endLngRaw = (isNull(qLegCoords.end_lng[i]) ? "" : trim(toString(qLegCoords.end_lng[i])));

                        if (len(startLatRaw) AND len(startLngRaw) AND isNumeric(startLatRaw) AND isNumeric(startLngRaw)) {
                            if (arrayLen(pointList) EQ 0) {
                                pointList = appendUniqueRoutePoint(
                                    pointList=pointList,
                                    lat=val(startLatRaw),
                                    lng=val(startLngRaw),
                                    label=(isNull(qLegCoords.start_label[i]) ? "Start" : trim(toString(qLegCoords.start_label[i]))),
                                    minDistanceMeters=20
                                );
                            }
                        }

                        if (len(endLatRaw) AND len(endLngRaw) AND isNumeric(endLatRaw) AND isNumeric(endLngRaw)) {
                            pointList = appendUniqueRoutePoint(
                                pointList=pointList,
                                lat=val(endLatRaw),
                                lng=val(endLngRaw),
                                label=(isNull(qLegCoords.end_label[i]) ? "End" : trim(toString(qLegCoords.end_label[i]))),
                                minDistanceMeters=20
                            );
                        }
                    }
                } catch (any fallbackLookupErr) {
                    // Keep response additive/safe; if fallback lookup fails, return without pins.
                }
            }

            for (i = 1; i LTE arrayLen(pointList); i++) {
                pt = pointList[i];
                arrayAppend(out.pins, {
                    "lat"=pt.lat,
                    "lng"=pt.lng,
                    "label"=pt.label,
                    "seq"=i,
                    "sequence"=i,
                    "type"=(i EQ 1 ? "start" : (i EQ arrayLen(pointList) ? "end" : "leg_end"))
                });
            }
            out.route_geo = {
                "type"="MultiLineString",
                "coordinates"=routeSegments
            };

            qProgress = queryExecute(
                "SELECT
                    leg_order,
                    UPPER(TRIM(status)) AS status_val,
                    leg_started_at
                 FROM route_instance_leg_progress
                 WHERE route_instance_id = :routeInstanceId
                   AND user_id = :userId
                 ORDER BY leg_order ASC, id DESC",
                {
                    routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" },
                    userId = { value=arguments.ownerUserId, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            for (i = 1; i LTE qProgress.recordCount; i++) {
                progressKey = toString(isNull(qProgress.leg_order[i]) ? 0 : val(qProgress.leg_order[i]));
                if (structKeyExists(progressStatusByLeg, progressKey)) {
                    continue;
                }
                progressStatusVal = (isNull(qProgress.status_val[i]) ? "" : trim(toString(qProgress.status_val[i])));
                progressStatusByLeg[progressKey] = progressStatusVal;
                if (!isNull(qProgress.leg_started_at[i]) AND isDate(qProgress.leg_started_at[i])) {
                    progressStartedByLeg[progressKey] = qProgress.leg_started_at[i];
                }
                if (progressStatusVal EQ "COMPLETED" AND val(qProgress.leg_order[i]) GT completedOrder) {
                    completedOrder = val(qProgress.leg_order[i]);
                }
            }

            for (i = 1; i LTE qLegs.recordCount; i++) {
                legOrderVal = (isNull(qLegs.leg_order[i]) ? 0 : val(qLegs.leg_order[i]));
                if (legOrderVal LTE completedOrder) {
                    continue;
                }
                if (pendingLegOrder LTE 0) {
                    pendingLegOrder = legOrderVal;
                }
                progressKey = toString(legOrderVal);
                progressStatusVal = (structKeyExists(progressStatusByLeg, progressKey) ? progressStatusByLeg[progressKey] : "NOT_STARTED");
                if (
                    activeStartedLegOrder LTE 0
                    AND (
                        structKeyExists(progressStartedByLeg, progressKey)
                        OR progressStatusVal EQ "STARTED"
                        OR progressStatusVal EQ "IN_PROGRESS"
                    )
                ) {
                    activeStartedLegOrder = legOrderVal;
                }
                if (activeStartedLegOrder LTE 0 OR legOrderVal NEQ activeStartedLegOrder) {
                    continue;
                }
                out.active_leg_order = legOrderVal;
                out.active_leg_start_name = (isNull(qLegs.start_name[i]) ? "" : trim(toString(qLegs.start_name[i])));
                out.active_leg_end_name = (isNull(qLegs.end_name[i]) ? "" : trim(toString(qLegs.end_name[i])));
                startLatRaw = (isNull(qLegs.start_lat[i]) ? "" : trim(toString(qLegs.start_lat[i])));
                startLngRaw = (isNull(qLegs.start_lng[i]) ? "" : trim(toString(qLegs.start_lng[i])));
                endLatRaw = (isNull(qLegs.end_lat[i]) ? "" : trim(toString(qLegs.end_lat[i])));
                endLngRaw = (isNull(qLegs.end_lng[i]) ? "" : trim(toString(qLegs.end_lng[i])));
                if (len(startLatRaw) AND len(startLngRaw) AND isNumeric(startLatRaw) AND isNumeric(startLngRaw)) {
                    out.active_leg_start_lat = val(startLatRaw);
                    out.active_leg_start_lng = val(startLngRaw);
                }
                if (len(endLatRaw) AND len(endLngRaw) AND isNumeric(endLatRaw) AND isNumeric(endLngRaw)) {
                    out.active_leg_end_lat = val(endLatRaw);
                    out.active_leg_end_lng = val(endLngRaw);
                }
                break;
            }

            if (completedOrder GT 0 AND pendingLegOrder GT 0 AND activeStartedLegOrder LTE 0) {
                out.awaiting_departure = true;
            }

            if (completedOrder GT 0) {
                qCurrentLeg = queryExecute(
                    "SELECT end_name, end_lat, end_lng
                     FROM route_instance_legs
                     WHERE route_instance_id = :routeInstanceId
                       AND leg_order = :legOrder
                     LIMIT 1",
                    {
                        routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" },
                        legOrder = { value=completedOrder, cfsqltype="cf_sql_integer" }
                    },
                    { datasource=ds }
                );
                if (
                    qCurrentLeg.recordCount GT 0
                    AND !isNull(qCurrentLeg.end_lat[1]) AND !isNull(qCurrentLeg.end_lng[1])
                    AND isNumeric(trim(toString(qCurrentLeg.end_lat[1])))
                    AND isNumeric(trim(toString(qCurrentLeg.end_lng[1])))
                ) {
                    out.current = {
                        "lat"=val(trim(toString(qCurrentLeg.end_lat[1]))),
                        "lng"=val(trim(toString(qCurrentLeg.end_lng[1]))),
                        "label"=(isNull(qCurrentLeg.end_name[1]) ? "Current position" : trim(toString(qCurrentLeg.end_name[1])))
                    };
                    out.location_label = out.current.label;
                }

                qNextLeg = queryExecute(
                    "SELECT end_name
                     FROM route_instance_legs
                     WHERE route_instance_id = :routeInstanceId
                       AND leg_order > :legOrder
                     ORDER BY leg_order ASC
                     LIMIT 1",
                    {
                        routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" },
                        legOrder = { value=completedOrder, cfsqltype="cf_sql_integer" }
                    },
                    { datasource=ds }
                );
                if (qNextLeg.recordCount GT 0 AND !isNull(qNextLeg.end_name[1])) {
                    out.next_stop_label = trim(toString(qNextLeg.end_name[1]));
                }

                if (completedOrder GT 0) {
                    for (i = 1; i LTE qLegs.recordCount; i++) {
                        if (val(qLegs.leg_order[i]) LTE completedOrder) {
                            completedNm += (isNull(qLegs.base_dist_nm[i]) ? 0 : val(qLegs.base_dist_nm[i]));
                        }
                    }
                }
            }

            if (!structKeyExists(out.current, "lat") AND arrayLen(pointList)) {
                out.current = {
                    "lat"=pointList[1].lat,
                    "lng"=pointList[1].lng,
                    "label"=pointList[1].label
                };
                out.location_label = pointList[1].label;
            }
            if (!len(out.next_stop_label) AND qLegs.recordCount GT 0 AND completedOrder LTE 0) {
                out.next_stop_label = (isNull(qLegs.end_name[1]) ? "" : trim(toString(qLegs.end_name[1])));
            }

            out.total_nm = roundTo2(out.total_nm);
            out.remaining_nm = max(0, roundTo2(out.total_nm - completedNm));
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="loadFollowRouteSegmentCoordinates" access="private" returntype="array" output="false">
        <cfargument name="ownerUserId" type="numeric" required="true">
        <cfargument name="routeId" type="numeric" required="false" default="0">
        <cfargument name="routeLegId" type="numeric" required="false" default="0">
        <cfargument name="routeLegOrder" type="numeric" required="false" default="0">
        <cfargument name="segmentId" type="numeric" required="false" default="0">
        <cfargument name="allowRouteLegOrderFallback" type="boolean" required="false" default="false">
        <cfscript>
            var ds = resolveDatasource();
            var q = queryNew("");
            var rawJson = "";
            var coords = [];

            if (arguments.ownerUserId LTE 0) {
                return [];
            }

            if (arguments.routeId GT 0 AND arguments.routeLegId GT 0) {
                q = queryExecute(
                    "SELECT geometry_json
                     FROM route_leg_user_overrides
                     WHERE user_id = :userId
                       AND route_id = :routeId
                       AND route_leg_id = :routeLegId
                     LIMIT 1",
                    {
                        userId = { value=arguments.ownerUserId, cfsqltype="cf_sql_integer" },
                        routeId = { value=arguments.routeId, cfsqltype="cf_sql_integer" },
                        routeLegId = { value=arguments.routeLegId, cfsqltype="cf_sql_integer" }
                    },
                    { datasource=ds }
                );
                if (q.recordCount GT 0 AND !isNull(q.geometry_json[1])) {
                    rawJson = toString(q.geometry_json[1]);
                    coords = parseFollowGeometryCoordinates(rawJson);
                    if (arrayLen(coords) GTE 2) {
                        return coords;
                    }
                }
            }

            if (
                arguments.allowRouteLegOrderFallback
                AND arguments.routeId GT 0
                AND arguments.routeLegOrder GT 0
                AND arguments.segmentId LTE 0
            ) {
                q = queryExecute(
                    "SELECT geometry_json
                     FROM route_leg_user_overrides
                     WHERE user_id = :userId
                       AND route_id = :routeId
                       AND route_leg_order = :routeLegOrder
                     ORDER BY updated_at DESC, id DESC
                     LIMIT 1",
                    {
                        userId = { value=arguments.ownerUserId, cfsqltype="cf_sql_integer" },
                        routeId = { value=arguments.routeId, cfsqltype="cf_sql_integer" },
                        routeLegOrder = { value=arguments.routeLegOrder, cfsqltype="cf_sql_integer" }
                    },
                    { datasource=ds }
                );
                if (q.recordCount GT 0 AND !isNull(q.geometry_json[1])) {
                    rawJson = toString(q.geometry_json[1]);
                    coords = parseFollowGeometryCoordinates(rawJson);
                    if (arrayLen(coords) GTE 2) {
                        return coords;
                    }
                }
            }

            if (arguments.segmentId GT 0) {
                q = queryExecute(
                    "SELECT geometry_json
                     FROM route_leg_user_overrides
                     WHERE user_id = :userId
                       AND segment_id = :segmentId
                     ORDER BY updated_at DESC, id DESC
                     LIMIT 1",
                    {
                        userId = { value=arguments.ownerUserId, cfsqltype="cf_sql_integer" },
                        segmentId = { value=arguments.segmentId, cfsqltype="cf_sql_integer" }
                    },
                    { datasource=ds }
                );
                if (q.recordCount GT 0 AND !isNull(q.geometry_json[1])) {
                    rawJson = toString(q.geometry_json[1]);
                    coords = parseFollowGeometryCoordinates(rawJson);
                    if (arrayLen(coords) GTE 2) {
                        return coords;
                    }
                }

                q = queryExecute(
                    "SELECT polyline_json
                     FROM segment_geometries
                     WHERE segment_id = :segmentId
                     ORDER BY version DESC, id DESC
                     LIMIT 1",
                    {
                        segmentId = { value=arguments.segmentId, cfsqltype="cf_sql_integer" }
                    },
                    { datasource=ds }
                );
                if (q.recordCount GT 0 AND !isNull(q.polyline_json[1])) {
                    rawJson = toString(q.polyline_json[1]);
                    coords = parseFollowGeometryCoordinates(rawJson);
                    if (arrayLen(coords) GTE 2) {
                        return coords;
                    }
                }
            }

            return [];
        </cfscript>
    </cffunction>

    <cffunction name="buildFollowCruiseTimeline" access="private" returntype="struct" output="false">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfargument name="ownerUserId" type="numeric" required="true">
        <cfargument name="opts" type="struct" required="false" default="#{}#">
        <cfscript>
            var out = {
                "summary"={
                    "total_nm"=0,
                    "total_locks"=0,
                    "total_hours"=0,
                    "total_days"=0,
                    "fuel_est"=0,
                    "reserve_est"=0,
                    "required_fuel_est"=0,
                    "max_hours_per_day"=0,
                    "effective_speed_kn"=0,
                    "fuel_burn_gph"=0,
                    "reserve_pct"=0
                },
                "legs"=[],
                "meta"={
                    "inputs_source"="default",
                    "missing_inputs"=[],
                    "zero_speed_guard"=false,
                    "progress_source"="route_instance_leg_progress",
                    "formula"="leg_hours=dist_nm/effective_speed_kn;day_bucket=ceil(cumulative_hours/max_hours_per_day)",
                    "rounding"={"nm_decimals"=2, "hours_decimals"=2, "fuel_decimals"=2}
                }
            };
            var routeInstanceIdVal = val(arguments.routeInstanceId);
            var ownerUserIdVal = val(arguments.ownerUserId);
            var ds = resolveDatasource();
            var qLegs = queryNew("");
            var qProgress = queryNew("");
            var qPlans = queryNew("");
            var storedInputs = {};
            var vesselDefaults = {};
            var lockDetailsByOrder = {};
            var progressByOrder = {};
            var i = 0;
            var key = "";
            var statusVal = "";
            var orderVal = 0;
            var lockCount = 0;
            var distNm = 0.0;
            var legHours = 0.0;
            var lockTimeHours = 0.0;
            var baseCycleMin = 0.0;
            var typicalWaitMin = 0.0;
            var cumulativeHours = 0.0;
            var dayBucket = 0;
            var startName = "";
            var endName = "";
            var progressPct = 0;
            var lastUpdateTs = "";
            var lastUpdateRaw = "";
            var maxHoursPerDay = 0.0;
            var effectiveSpeedKn = 0.0;
            var fuelBurnGph = 0.0;
            var reservePct = 0.0;
            var totalNm = 0.0;
            var totalLocks = 0;
            var totalDaysHint = 0;
            var fuelEst = 0.0;
            var reserveEst = 0.0;
            var completedLegs = 0;
            var missingInputs = [];
            var inputsSource = "";
            var depRaw = "";
            var retRaw = "";
            var depDt = "";
            var retDt = "";
            var dayMinutes = 0;
            var optsLocal = (isStruct(arguments.opts) ? arguments.opts : {});
            var routeInputMaxHours = 0;
            var routeInputSpeedKn = 0;
            var routeInputFuelBurn = 0;
            var routeInputReservePct = 0;
            var usedOpts = false;
            var usedRouteInputs = false;
            var usedVesselDefaults = false;
            var usedFloatplans = false;
            var planVesselId = 0;
            var legLockDetails = {};
            var canonicalActivePlan = {};
            var activePaceFloatPlanId = 0;
            var qActivePlanDelay = queryNew("");
            var manualDelayMinutesTotal = 0;
            var manualDelayHoursTotal = 0.0;
            var adjustedCumulativeHours = 0.0;
            var adjustedDayBucket = 0;
            var adjustedTotalHours = 0.0;

            if (routeInstanceIdVal LTE 0 OR ownerUserIdVal LTE 0) {
                return out;
            }

            qLegs = queryExecute(
                "SELECT
                    leg_order,
                    segment_id,
                    start_name,
                    end_name,
                    base_dist_nm,
                    lock_count
                 FROM route_instance_legs
                 WHERE route_instance_id = :routeInstanceId
                 ORDER BY leg_order ASC, id ASC",
                {
                    routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );
            if (qLegs.recordCount EQ 0) {
                return out;
            }

            qPlans = queryExecute(
                "SELECT
                    floatplanId,
                    vesselId,
                    route_day_number,
                    departureTime,
                    returnTime
                 FROM floatplans
                 WHERE route_instance_id = :routeInstanceId
                   AND userId = :ownerUserId
                 ORDER BY route_day_number ASC, floatplanId ASC",
                {
                    routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" },
                    ownerUserId = { value=ownerUserIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );
            storedInputs = loadRouteInstanceTimelineInputs(routeInstanceIdVal, ownerUserIdVal);
            lockDetailsByOrder = loadFollowLegLockDetailsMap(routeInstanceIdVal, ownerUserIdVal, qLegs);
            canonicalActivePlan = resolveCanonicalActiveFloatPlan(ownerUserIdVal, 0);
            if (
                structKeyExists(canonicalActivePlan, "SUCCESS")
                AND canonicalActivePlan.SUCCESS
                AND structKeyExists(canonicalActivePlan, "ROUTE_INSTANCE_ID")
                AND val(canonicalActivePlan.ROUTE_INSTANCE_ID) EQ routeInstanceIdVal
            ) {
                activePaceFloatPlanId = val(canonicalActivePlan.FLOATPLANID);
                qActivePlanDelay = queryExecute(
                    "SELECT manual_delay_minutes_total
                     FROM floatplans
                     WHERE floatplanId = :planId
                       AND userId = :ownerUserId
                     LIMIT 1",
                    {
                        planId = { value = val(canonicalActivePlan.FLOATPLANID), cfsqltype = "cf_sql_integer" },
                        ownerUserId = { value = ownerUserIdVal, cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = ds }
                );
                if (
                    qActivePlanDelay.recordCount GT 0
                    AND !isNull(qActivePlanDelay.manual_delay_minutes_total[1])
                    AND isNumeric(qActivePlanDelay.manual_delay_minutes_total[1])
                ) {
                    manualDelayMinutesTotal = val(qActivePlanDelay.manual_delay_minutes_total[1]);
                }
            }
            if (manualDelayMinutesTotal LT 0) {
                manualDelayMinutesTotal = 0;
            }
            if (manualDelayMinutesTotal GT 0) {
                manualDelayHoursTotal = roundTo2(manualDelayMinutesTotal / 60);
            }

            qProgress = queryExecute(
                "SELECT
                    leg_order,
                    UPPER(TRIM(status)) AS status_val,
                    COALESCE(updated_at, completed_at, created_at) AS last_update_ts
                 FROM route_instance_leg_progress
                 WHERE route_instance_id = :routeInstanceId
                   AND user_id = :ownerUserId
                 ORDER BY leg_order ASC, id DESC",
                {
                    routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" },
                    ownerUserId = { value=ownerUserIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            for (i = 1; i LTE qProgress.recordCount; i++) {
                key = toString(val(qProgress.leg_order[i]));
                if (structKeyExists(progressByOrder, key)) {
                    continue;
                }
                progressByOrder[key] = {
                    "status"=(isNull(qProgress.status_val[i]) ? "" : trim(toString(qProgress.status_val[i]))),
                    "last_update_ts"=(isNull(qProgress.last_update_ts[i]) ? "" : qProgress.last_update_ts[i])
                };
            }

            if (structKeyExists(optsLocal, "max_hours_per_day") AND isNumeric(optsLocal.max_hours_per_day) AND val(optsLocal.max_hours_per_day) GT 0) {
                maxHoursPerDay = roundTo2(optsLocal.max_hours_per_day);
                usedOpts = true;
            }
            if (structKeyExists(optsLocal, "effective_speed_kn") AND isNumeric(optsLocal.effective_speed_kn) AND val(optsLocal.effective_speed_kn) GT 0) {
                effectiveSpeedKn = roundTo2(optsLocal.effective_speed_kn);
                usedOpts = true;
            }
            if (structKeyExists(optsLocal, "fuel_burn_gph") AND isNumeric(optsLocal.fuel_burn_gph) AND val(optsLocal.fuel_burn_gph) GT 0) {
                fuelBurnGph = roundTo2(optsLocal.fuel_burn_gph);
                usedOpts = true;
            }
            if (structKeyExists(optsLocal, "reserve_pct") AND isNumeric(optsLocal.reserve_pct) AND val(optsLocal.reserve_pct) GT 0) {
                reservePct = roundTo2(optsLocal.reserve_pct);
                usedOpts = true;
            }

            if (maxHoursPerDay LTE 0) {
                routeInputMaxHours = getNumericFromKeys(
                    storedInputs,
                    [ "max_hours_per_day", "maxHoursPerDay", "underway_hours_per_day", "underwayHoursPerDay" ],
                    true
                );
                if (routeInputMaxHours GT 0) {
                    maxHoursPerDay = roundTo2(routeInputMaxHours);
                    usedRouteInputs = true;
                }
            }
            if (effectiveSpeedKn LTE 0) {
                routeInputSpeedKn = deriveEffectiveSpeedFromInputs(storedInputs, activePaceFloatPlanId);
                if (routeInputSpeedKn GT 0) {
                    effectiveSpeedKn = roundTo2(routeInputSpeedKn);
                    usedRouteInputs = true;
                }
            }
            if (fuelBurnGph LTE 0) {
                routeInputFuelBurn = getNumericFromKeys(
                    storedInputs,
                    [
                        "fuel_burn_gph",
                        "fuelBurnGph",
                        "fuel_burn_gph_input",
                        "fuelBurnGphInput",
                        "max_burn_gph",
                        "maxBurnGph",
                        "burn_gph",
                        "burnGph",
                        "FUEL_BURN_GPH"
                    ],
                    true
                );
                if (routeInputFuelBurn LTE 0) {
                    routeInputFuelBurn = getNumericFromKeys(
                        storedInputs,
                        [
                            "vessel_gph_at_most_efficient_speed",
                            "vesselGphAtMostEfficientSpeed",
                            "gph_at_most_efficient_speed",
                            "gphAtMostEfficientSpeed",
                            "gallons_per_hour",
                            "GALLONS_PER_HOUR"
                        ],
                        true
                    );
                }
                if (routeInputFuelBurn GT 0) {
                    fuelBurnGph = roundTo2(routeInputFuelBurn);
                    usedRouteInputs = true;
                }
            }
            if (reservePct LTE 0) {
                routeInputReservePct = getNumericFromKeys(storedInputs, [ "reserve_pct", "reservePct", "RESERVE_PCT" ], true);
                if (routeInputReservePct GT 0) {
                    reservePct = roundTo2(routeInputReservePct);
                    usedRouteInputs = true;
                }
            }

            for (i = 1; i LTE qLegs.recordCount; i++) {
                distNm = roundTo2(isNull(qLegs.base_dist_nm[i]) ? 0 : val(qLegs.base_dist_nm[i]));
                lockCount = (isNull(qLegs.lock_count[i]) ? 0 : val(qLegs.lock_count[i]));
                if (distNm LT 0) distNm = 0;
                if (lockCount LT 0) lockCount = 0;
                totalNm += distNm;
                totalLocks += lockCount;
            }
            totalNm = roundTo2(totalNm);

            for (i = 1; i LTE qPlans.recordCount; i++) {
                if (
                    planVesselId LTE 0
                    AND !isNull(qPlans.vesselId[i])
                    AND isNumeric(qPlans.vesselId[i])
                    AND val(qPlans.vesselId[i]) GT 0
                ) {
                    planVesselId = val(qPlans.vesselId[i]);
                }
                if (!isNull(qPlans.route_day_number[i]) AND isNumeric(qPlans.route_day_number[i])) {
                    totalDaysHint = max(totalDaysHint, val(qPlans.route_day_number[i]));
                }
                if (maxHoursPerDay GT 0) {
                    continue;
                }
                depRaw = (isNull(qPlans.departureTime[i]) ? "" : trim(toString(qPlans.departureTime[i])));
                retRaw = (isNull(qPlans.returnTime[i]) ? "" : trim(toString(qPlans.returnTime[i])));
                if (!len(depRaw) OR !len(retRaw)) {
                    continue;
                }
                try {
                    depDt = parseDateTime(depRaw);
                    retDt = parseDateTime(retRaw);
                    if (isDate(depDt) AND isDate(retDt)) {
                        dayMinutes = abs(dateDiff("n", depDt, retDt));
                        if (dayMinutes GT 0 AND dayMinutes LTE 1440) {
                            maxHoursPerDay = roundTo2(dayMinutes / 60);
                            usedFloatplans = true;
                        }
                    }
                } catch (any parseErr) {
                    // Keep timeline deterministic; unresolved time fields stay as defaults.
                }
            }

            vesselDefaults = loadPreferredVesselDefaults(ownerUserIdVal, planVesselId);
            if (effectiveSpeedKn LTE 0) {
                if (structKeyExists(vesselDefaults, "vessel_most_efficient_speed_kn") AND val(vesselDefaults.vessel_most_efficient_speed_kn) GT 0) {
                    effectiveSpeedKn = roundTo2(vesselDefaults.vessel_most_efficient_speed_kn);
                    usedVesselDefaults = true;
                } else if (structKeyExists(vesselDefaults, "vessel_max_speed_kn") AND val(vesselDefaults.vessel_max_speed_kn) GT 0) {
                    effectiveSpeedKn = roundTo2(vesselDefaults.vessel_max_speed_kn);
                    usedVesselDefaults = true;
                }
            }
            if (fuelBurnGph LTE 0 AND structKeyExists(vesselDefaults, "vessel_gph_at_most_efficient_speed") AND val(vesselDefaults.vessel_gph_at_most_efficient_speed) GT 0) {
                fuelBurnGph = roundTo2(vesselDefaults.vessel_gph_at_most_efficient_speed);
                usedVesselDefaults = true;
            }

            if (effectiveSpeedKn LTE 0 AND totalDaysHint GT 0 AND maxHoursPerDay GT 0 AND totalNm GT 0) {
                effectiveSpeedKn = roundTo2(totalNm / (totalDaysHint * maxHoursPerDay));
                if (effectiveSpeedKn GT 0) {
                    usedFloatplans = true;
                }
            }

            if (effectiveSpeedKn LTE 0) {
                effectiveSpeedKn = 0;
                arrayAppend(missingInputs, "effective_speed_kn");
            }
            if (maxHoursPerDay LTE 0) {
                maxHoursPerDay = 0;
                arrayAppend(missingInputs, "max_hours_per_day");
            }
            if (fuelBurnGph LTE 0) {
                fuelBurnGph = 0;
                arrayAppend(missingInputs, "fuel_burn_gph");
            }
            if (reservePct LTE 0) {
                reservePct = 0;
                arrayAppend(missingInputs, "reserve_pct");
            }
            if (arrayLen(missingInputs)) {
                inputsSource = "default";
            } else if (usedOpts) {
                inputsSource = "opts";
            } else if (usedRouteInputs AND usedVesselDefaults) {
                inputsSource = "route_instances.routegen_inputs_json+vessel_defaults";
            } else if (usedRouteInputs) {
                inputsSource = "route_instances.routegen_inputs_json";
            } else if (usedVesselDefaults) {
                inputsSource = "vessel_defaults";
            } else if (usedFloatplans) {
                inputsSource = "floatplans";
            } else if (!len(inputsSource)) {
                inputsSource = "floatplans";
            }

            for (i = 1; i LTE qLegs.recordCount; i++) {
                orderVal = (isNull(qLegs.leg_order[i]) ? i : val(qLegs.leg_order[i]));
                if (orderVal LTE 0) orderVal = i;
                key = toString(orderVal);
                startName = (isNull(qLegs.start_name[i]) ? "Start" : trim(toString(qLegs.start_name[i])));
                endName = (isNull(qLegs.end_name[i]) ? "End" : trim(toString(qLegs.end_name[i])));
                if (!len(startName)) startName = "Start";
                if (!len(endName)) endName = "End";

                distNm = roundTo2(isNull(qLegs.base_dist_nm[i]) ? 0 : val(qLegs.base_dist_nm[i]));
                if (distNm LT 0) distNm = 0;
                lockCount = (isNull(qLegs.lock_count[i]) ? 0 : val(qLegs.lock_count[i]));
                if (lockCount LT 0) lockCount = 0;
                legLockDetails = (
                    structKeyExists(lockDetailsByOrder, key)
                        ? duplicate(lockDetailsByOrder[key])
                        : {
                            "lock_count"=lockCount,
                            "lock_message"=(lockCount GT 0 ? "Lock details unavailable for this leg." : "No locks mapped for this leg."),
                            "totals"={
                                "base_cycle_min"=0,
                                "best_wait_min"=0,
                                "typical_wait_min"=0,
                                "worst_wait_min"=0
                            },
                            "locks"=[]
                        }
                );
                if (!structKeyExists(legLockDetails, "lock_count") OR !isNumeric(legLockDetails.lock_count) OR val(legLockDetails.lock_count) LT lockCount) {
                    legLockDetails.lock_count = lockCount;
                }
                if (!structKeyExists(legLockDetails, "totals") OR !isStruct(legLockDetails.totals)) {
                    legLockDetails.totals = {
                        "base_cycle_min"=0,
                        "best_wait_min"=0,
                        "typical_wait_min"=0,
                        "worst_wait_min"=0
                    };
                }
                if (!structKeyExists(legLockDetails, "locks") OR !isArray(legLockDetails.locks)) {
                    legLockDetails.locks = [];
                }

                baseCycleMin = val(structKeyExists(legLockDetails.totals, "base_cycle_min") ? legLockDetails.totals.base_cycle_min : 0);
                if (baseCycleMin LT 0) baseCycleMin = 0;
                typicalWaitMin = val(structKeyExists(legLockDetails.totals, "typical_wait_min") ? legLockDetails.totals.typical_wait_min : 0);
                if (typicalWaitMin LT 0) typicalWaitMin = 0;
                lockTimeHours = roundTo2((baseCycleMin + typicalWaitMin) / 60);
                legHours = lockTimeHours;
                if (effectiveSpeedKn GT 0 AND distNm GT 0) {
                    legHours = roundTo2(legHours + (distNm / effectiveSpeedKn));
                } else if (distNm GT 0 AND effectiveSpeedKn LTE 0) {
                    out.meta.zero_speed_guard = true;
                }
                cumulativeHours = roundTo2(cumulativeHours + legHours);
                if (maxHoursPerDay GT 0 AND cumulativeHours GT 0) {
                    dayBucket = int(ceiling(cumulativeHours / maxHoursPerDay));
                } else {
                    dayBucket = 0;
                }

                statusVal = "";
                progressPct = 0;
                lastUpdateTs = "";
                if (structKeyExists(progressByOrder, key)) {
                    statusVal = trim(toString(progressByOrder[key].status));
                    if (statusVal EQ "COMPLETED") {
                        progressPct = 100;
                        completedLegs += 1;
                    } else if (statusVal EQ "IN_PROGRESS") {
                        progressPct = 50;
                    } else if (statusVal EQ "STARTED") {
                        progressPct = 25;
                    }

                    lastUpdateRaw = progressByOrder[key].last_update_ts;
                    if (!isNull(lastUpdateRaw)) {
                        if (isDate(lastUpdateRaw)) {
                            lastUpdateTs = formatUtcDate(lastUpdateRaw);
                        } else {
                            lastUpdateTs = trim(toString(lastUpdateRaw));
                        }
                    }
                }
                adjustedCumulativeHours = cumulativeHours;
                adjustedDayBucket = dayBucket;
                if (manualDelayHoursTotal GT 0 AND statusVal NEQ "COMPLETED") {
                    adjustedCumulativeHours = roundTo2(cumulativeHours + manualDelayHoursTotal);
                    if (maxHoursPerDay GT 0 AND adjustedCumulativeHours GT 0) {
                        adjustedDayBucket = int(ceiling(adjustedCumulativeHours / maxHoursPerDay));
                    }
                }

                arrayAppend(out.legs, {
                    "day_bucket"=adjustedDayBucket,
                    "leg_order"=orderVal,
                    "label"=startName & " -> " & endName,
                    "start_name"=startName,
                    "end_name"=endName,
                    "dist_nm"=distNm,
                    "hours"=legHours,
                    "locks"=lockCount,
                    "lock_details"=legLockDetails,
                    "cumulative_hours"=adjustedCumulativeHours,
                    "progress"={
                        "percent_complete"=progressPct,
                        "last_update_ts"=lastUpdateTs
                    }
                });
            }

            fuelEst = 0;
            reserveEst = 0;
            if (fuelBurnGph GT 0 AND cumulativeHours GT 0) {
                fuelEst = roundTo2(cumulativeHours * fuelBurnGph);
                if (reservePct GT 0) {
                    reserveEst = roundTo2(fuelEst * (reservePct / 100));
                }
            }

            adjustedTotalHours = roundTo2(cumulativeHours + manualDelayHoursTotal);
            out.summary = {
                "total_nm"=totalNm,
                "total_locks"=totalLocks,
                "total_hours"=adjustedTotalHours,
                "total_days"=(maxHoursPerDay GT 0 AND adjustedTotalHours GT 0 ? int(ceiling(adjustedTotalHours / maxHoursPerDay)) : 0),
                "fuel_est"=fuelEst,
                "reserve_est"=reserveEst,
                "required_fuel_est"=roundTo2(fuelEst + reserveEst),
                "max_hours_per_day"=maxHoursPerDay,
                "effective_speed_kn"=effectiveSpeedKn,
                "fuel_burn_gph"=fuelBurnGph,
                "reserve_pct"=reservePct,
                "completed_legs"=completedLegs
            };
            out.meta.inputs_source = inputsSource;
            out.meta.missing_inputs = missingInputs;
            out.meta.total_days_hint = totalDaysHint;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="hasRouteInstanceInputsJsonColumn" access="private" returntype="boolean" output="false">
        <cfscript>
            var cacheKey = "voyageHasRouteInstanceInputsJsonColumn";
            var qCol = queryNew("");
            if (structKeyExists(request, cacheKey) AND isBoolean(request[cacheKey])) {
                return request[cacheKey];
            }
            qCol = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.columns
                 WHERE table_schema = DATABASE()
                   AND table_name = 'route_instances'
                   AND column_name = 'routegen_inputs_json'",
                {},
                { datasource=resolveDatasource() }
            );
            request[cacheKey] = (qCol.recordCount GT 0 AND val(qCol.cnt[1]) GT 0);
            return request[cacheKey];
        </cfscript>
    </cffunction>

    <cffunction name="loadRouteInstanceTimelineInputs" access="private" returntype="struct" output="false">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfargument name="ownerUserId" type="numeric" required="true">
        <cfscript>
            var out = {};
            var routeInstanceIdVal = val(arguments.routeInstanceId);
            var ownerUserIdVal = val(arguments.ownerUserId);
            var qInst = queryNew("");
            var rawJson = "";
            if (routeInstanceIdVal LTE 0 OR ownerUserIdVal LTE 0) return out;
            if (!hasRouteInstanceInputsJsonColumn()) return out;

            qInst = queryExecute(
                "SELECT routegen_inputs_json
                 FROM route_instances
                 WHERE id = :routeInstanceId
                   AND user_id = :ownerUserIdText
                 LIMIT 1",
                {
                    routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" },
                    ownerUserIdText = { value=toString(ownerUserIdVal), cfsqltype="cf_sql_varchar" }
                },
                { datasource=resolveDatasource() }
            );
            if (qInst.recordCount EQ 0 OR isNull(qInst.routegen_inputs_json[1])) return out;
            rawJson = trim(toString(qInst.routegen_inputs_json[1]));
            if (!len(rawJson)) return out;
            out = parseRouteInstanceInputs(rawJson);
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="parseRouteInstanceInputs" access="private" returntype="struct" output="false">
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
                if (!isStruct(parsed)) return {};
                normalized = duplicate(parsed);
                aliasMap = {
                    "underway_hours_per_day" = [ "underwayHoursPerDay", "max_hours_per_day", "maxHoursPerDay", "UNDERWAY_HOURS_PER_DAY" ],
                    "effective_speed_kn" = [ "weather_adjusted_speed_kn", "weatherAdjustedSpeedKn", "effectiveSpeedKn", "effective_cruising_speed", "effectiveCruisingSpeed" ],
                    "cruising_speed" = [ "cruisingSpeed", "max_speed_kn", "maxSpeedKn", "CRUISING_SPEED", "MAX_SPEED_KN" ],
                    "fuel_burn_gph" = [ "fuelBurnGph", "fuel_burn_gph_input", "fuelBurnGphInput", "max_burn_gph", "maxBurnGph", "burn_gph", "burnGph", "FUEL_BURN_GPH" ],
                    "reserve_pct" = [ "reservePct", "RESERVE_PCT" ],
                    "weather_factor_pct" = [ "weatherFactorPct", "weather_factor", "weatherFactor", "WEATHER_FACTOR_PCT", "WEATHER_FACTOR" ],
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
                        normalized[canonicalKey] = candidateVal;
                        break;
                    }
                }
                return normalized;
            } catch (any parseErr) {
                return {};
            }
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
            if (!structCount(source)) return 0;
            for (i = 1; i LTE arrayLen(arguments.keys); i++) {
                key = toString(arguments.keys[i]);
                if (!len(key) OR !structKeyExists(source, key) OR isNull(source[key])) continue;
                rawVal = source[key];
                if (!isNumeric(rawVal)) continue;
                n = val(rawVal);
                if (arguments.positiveOnly AND n LTE 0) continue;
                return roundTo2(n);
            }
            return 0;
        </cfscript>
    </cffunction>

    <cffunction name="resolvePaceFactor" access="private" returntype="numeric" output="false">
        <cfargument name="pace" type="any" required="false" default="RELAXED">
        <cfscript>
            var paceVal = uCase(trim(toString(arguments.pace)));
            if (paceVal EQ "AGGRESSIVE") return 1.0;
            if (paceVal EQ "BALANCED") return 0.5;
            return 0.25;
        </cfscript>
    </cffunction>

    <cffunction name="deriveEffectiveSpeedFromInputs" access="private" returntype="numeric" output="false">
        <cfargument name="routeInputs" type="any" required="false" default="#{}#">
        <cfargument name="floatPlanId" type="numeric" required="false" default="0">
        <cfscript>
            var src = (isStruct(arguments.routeInputs) ? arguments.routeInputs : {});
            var activePaceSpeed = 0;
            var directSpeed = getNumericFromKeys(
                src,
                [ "weather_adjusted_speed_kn", "weatherAdjustedSpeedKn", "effective_speed_kn", "effectiveSpeedKn", "effective_cruising_speed", "effectiveCruisingSpeed" ],
                true
            );
            var maxSpeed = 0;
            var mostEfficientSpeed = 0;
            var paceFactor = 0.25;
            var paceVal = "";
            var weatherPct = 0;
            var out = 0;

            if (arguments.floatPlanId GT 0) {
                activePaceSpeed = createActiveTripPaceService().resolveEffectiveSpeedKn(src, arguments.floatPlanId);
                if (activePaceSpeed GT 0) {
                    return roundTo2(activePaceSpeed);
                }
            }
            if (directSpeed GT 0) return roundTo2(directSpeed);

            maxSpeed = getNumericFromKeys(
                src,
                [
                    "cruising_speed",
                    "cruisingSpeed",
                    "max_speed_kn",
                    "maxSpeedKn",
                    "vessel_max_speed_kn",
                    "vesselMaxSpeedKn",
                    "vessel_max_speed",
                    "vesselMaxSpeed"
                ],
                true
            );
            if (maxSpeed LTE 0) return 0;

            paceVal = (structKeyExists(src, "pace") ? uCase(trim(toString(src.pace))) : "RELAXED");
            mostEfficientSpeed = getNumericFromKeys(
                src,
                [ "vessel_most_efficient_speed_kn", "vesselMostEfficientSpeedKn", "most_efficient_speed_kn", "mostEfficientSpeedKn", "MOST_EFFICIENT_SPEED_KN", "MOST_EFFICIENT_SPEED" ],
                true
            );
            if (paceVal EQ "BALANCED" AND mostEfficientSpeed GTE 1) {
                out = roundTo2(min(60, mostEfficientSpeed));
            } else {
                paceFactor = resolvePaceFactor(paceVal);
                out = roundTo2(maxSpeed * paceFactor);
            }
            if (out LT 0.5) out = 0.5;

            weatherPct = getNumericFromKeys(
                src,
                [ "weather_factor_pct", "weatherFactorPct", "weather_factor", "weatherFactor" ],
                false
            );
            if (weatherPct LT 0) weatherPct = 0;
            if (weatherPct GT 70) weatherPct = 70;
            if (weatherPct GT 0) {
                out = roundTo2(out * (1 - (weatherPct / 100)));
                if (out LT 0.5) out = 0.5;
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getVesselPerformanceColumnMap" access="private" returntype="struct" output="false">
        <cfscript>
            var cacheKey = "voyageVesselPerformanceColumnMap";
            var out = {
                "max_speed_col"="",
                "most_efficient_speed_col"="",
                "most_efficient_gph_col"=""
            };
            var qCols = queryNew("");
            var hasCol = {};
            var i = 0;
            if (structKeyExists(request, cacheKey) AND isStruct(request[cacheKey])) {
                return request[cacheKey];
            }
            qCols = queryExecute(
                "SELECT column_name
                 FROM information_schema.columns
                 WHERE table_schema = DATABASE()
                   AND table_name = 'vessels'
                   AND column_name IN (
                     'max_speed_kn',
                     'max_speed',
                     'most_efficient_speed_kn',
                     'most_efficient_speed',
                     'gph_at_most_efficient_speed',
                     'gallons_per_hour'
                   )",
                {},
                { datasource=resolveDatasource() }
            );
            for (i = 1; i LTE qCols.recordCount; i++) {
                hasCol[lCase(trim(toString(qCols.column_name[i])))] = true;
            }
            if (structKeyExists(hasCol, "max_speed_kn")) {
                out.max_speed_col = "max_speed_kn";
            } else if (structKeyExists(hasCol, "max_speed")) {
                out.max_speed_col = "max_speed";
            }
            if (structKeyExists(hasCol, "most_efficient_speed_kn")) {
                out.most_efficient_speed_col = "most_efficient_speed_kn";
            } else if (structKeyExists(hasCol, "most_efficient_speed")) {
                out.most_efficient_speed_col = "most_efficient_speed";
            }
            if (structKeyExists(hasCol, "gph_at_most_efficient_speed")) {
                out.most_efficient_gph_col = "gph_at_most_efficient_speed";
            } else if (structKeyExists(hasCol, "gallons_per_hour")) {
                out.most_efficient_gph_col = "gallons_per_hour";
            }
            request[cacheKey] = out;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="loadPreferredVesselDefaults" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="preferredVesselId" type="numeric" required="false" default="0">
        <cfscript>
            var out = {
                "vessel_max_speed_kn"=0,
                "vessel_most_efficient_speed_kn"=0,
                "vessel_gph_at_most_efficient_speed"=0
            };
            var userIdVal = val(arguments.userId);
            var preferredVesselIdVal = val(arguments.preferredVesselId);
            var cacheKey = "";
            var columnMap = {};
            var maxExpr = "0";
            var effExpr = "0";
            var gphExpr = "0";
            var qVessel = queryNew("");
            if (userIdVal LTE 0) return out;

            cacheKey = "voyageVesselDefaults_" & toString(userIdVal) & "_" & toString(preferredVesselIdVal);
            if (structKeyExists(request, cacheKey) AND isStruct(request[cacheKey])) {
                return request[cacheKey];
            }

            columnMap = getVesselPerformanceColumnMap();
            if (!len(columnMap.max_speed_col) AND !len(columnMap.most_efficient_speed_col) AND !len(columnMap.most_efficient_gph_col)) {
                request[cacheKey] = out;
                return out;
            }
            if (len(columnMap.max_speed_col)) {
                maxExpr = "COALESCE(v." & columnMap.max_speed_col & ", 0)";
            }
            if (len(columnMap.most_efficient_speed_col)) {
                effExpr = "COALESCE(v." & columnMap.most_efficient_speed_col & ", 0)";
            }
            if (len(columnMap.most_efficient_gph_col)) {
                gphExpr = "COALESCE(v." & columnMap.most_efficient_gph_col & ", 0)";
            }

            if (preferredVesselIdVal GT 0) {
                qVessel = queryExecute(
                    "SELECT
                        " & maxExpr & " AS vessel_max_speed_kn,
                        " & effExpr & " AS vessel_most_efficient_speed_kn,
                        " & gphExpr & " AS vessel_gph_at_most_efficient_speed
                     FROM vessels v
                     WHERE v.userId = :uid
                       AND v.vesselID = :vesselId
                     LIMIT 1",
                    {
                        uid = { value=userIdVal, cfsqltype="cf_sql_integer" },
                        vesselId = { value=preferredVesselIdVal, cfsqltype="cf_sql_integer" }
                    },
                    { datasource=resolveDatasource() }
                );
            }

            if (qVessel.recordCount EQ 0) {
                qVessel = queryExecute(
                    "SELECT
                        " & maxExpr & " AS vessel_max_speed_kn,
                        " & effExpr & " AS vessel_most_efficient_speed_kn,
                        " & gphExpr & " AS vessel_gph_at_most_efficient_speed
                     FROM vessels v
                     WHERE v.userId = :uid
                     ORDER BY v.vesselID ASC
                     LIMIT 1",
                    {
                        uid = { value=userIdVal, cfsqltype="cf_sql_integer" }
                    },
                    { datasource=resolveDatasource() }
                );
            }

            if (qVessel.recordCount GT 0) {
                out.vessel_max_speed_kn = roundTo2(val(qVessel.vessel_max_speed_kn[1]));
                if (out.vessel_max_speed_kn LT 1) out.vessel_max_speed_kn = 0;
                if (out.vessel_max_speed_kn GT 60) out.vessel_max_speed_kn = 60;

                out.vessel_most_efficient_speed_kn = roundTo2(val(qVessel.vessel_most_efficient_speed_kn[1]));
                if (out.vessel_most_efficient_speed_kn LT 1) out.vessel_most_efficient_speed_kn = 0;
                if (out.vessel_most_efficient_speed_kn GT 60) out.vessel_most_efficient_speed_kn = 60;

                out.vessel_gph_at_most_efficient_speed = roundTo2(val(qVessel.vessel_gph_at_most_efficient_speed[1]));
                if (out.vessel_gph_at_most_efficient_speed LT 0) out.vessel_gph_at_most_efficient_speed = 0;
            }

            request[cacheKey] = out;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="hasFollowRouteLegLocksTable" access="private" returntype="boolean" output="false">
        <cfscript>
            var cacheKey = "voyageHasRouteLegLocksTable";
            var qCol = queryNew("");
            if (structKeyExists(request, cacheKey) AND isBoolean(request[cacheKey])) {
                return request[cacheKey];
            }
            qCol = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE()
                   AND table_name = 'route_leg_locks'",
                {},
                { datasource=resolveDatasource() }
            );
            request[cacheKey] = (qCol.recordCount GT 0 AND val(qCol.cnt[1]) GT 0);
            return request[cacheKey];
        </cfscript>
    </cffunction>

    <cffunction name="hasFollowCanonicalLocksTable" access="private" returntype="boolean" output="false">
        <cfscript>
            var cacheKey = "voyageHasCanonicalLocksTable";
            var qCol = queryNew("");
            if (structKeyExists(request, cacheKey) AND isBoolean(request[cacheKey])) {
                return request[cacheKey];
            }
            qCol = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE()
                   AND table_name = 'canonical_locks'",
                {},
                { datasource=resolveDatasource() }
            );
            request[cacheKey] = (qCol.recordCount GT 0 AND val(qCol.cnt[1]) GT 0);
            return request[cacheKey];
        </cfscript>
    </cffunction>

    <cffunction name="hasFollowLockDelayModelTable" access="private" returntype="boolean" output="false">
        <cfscript>
            var cacheKey = "voyageHasLockDelayModelTable";
            var qCol = queryNew("");
            if (structKeyExists(request, cacheKey) AND isBoolean(request[cacheKey])) {
                return request[cacheKey];
            }
            qCol = queryExecute(
                "SELECT COUNT(*) AS cnt
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE()
                   AND table_name = 'lock_delay_model'",
                {},
                { datasource=resolveDatasource() }
            );
            request[cacheKey] = (qCol.recordCount GT 0 AND val(qCol.cnt[1]) GT 0);
            return request[cacheKey];
        </cfscript>
    </cffunction>

    <cffunction name="loadFollowLegLockDetailsMap" access="private" returntype="struct" output="false">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfargument name="ownerUserId" type="numeric" required="true">
        <cfargument name="legsQuery" type="any" required="false" default="">
        <cfscript>
            var out = {};
            var routeInstanceIdVal = val(arguments.routeInstanceId);
            var ownerUserIdVal = val(arguments.ownerUserId);
            var legsQ = (isQuery(arguments.legsQuery) ? arguments.legsQuery : queryNew(""));
            var ds = resolveDatasource();
            var i = 0;
            var orderKey = "";
            var lockCount = 0;
            var qInst = queryNew("");
            var qLegTemplate = queryNew("");
            var templateCodeVal = "";
            var hasRouteLegLocks = hasFollowRouteLegLocksTable();
            var hasCanonicalLocks = hasFollowCanonicalLocksTable();
            var hasDelayModel = hasFollowLockDelayModelTable();
            var templateByOrder = {};
            var shortCodeVal = "";
            var templateLegVal = 0;
            var pairKey = "";
            var detailCache = {};
            var details = {};
            var mapSql = "";
            var mapParams = {};

            if (routeInstanceIdVal LTE 0 OR ownerUserIdVal LTE 0) return out;

            for (i = 1; i LTE legsQ.recordCount; i++) {
                orderKey = toString(val(legsQ.leg_order[i]));
                if (!len(orderKey)) continue;
                lockCount = (isNull(legsQ.lock_count[i]) ? 0 : val(legsQ.lock_count[i]));
                if (lockCount LT 0) lockCount = 0;
                out[orderKey] = {
                    "lock_count"=lockCount,
                    "lock_message"=(lockCount GT 0 ? "Lock details unavailable for this leg." : "No locks mapped for this leg."),
                    "totals"={
                        "base_cycle_min"=0,
                        "best_wait_min"=0,
                        "typical_wait_min"=0,
                        "worst_wait_min"=0
                    },
                    "locks"=[]
                };
            }

            if (!hasRouteLegLocks OR !hasCanonicalLocks) {
                return out;
            }

            qInst = queryExecute(
                "SELECT template_route_code
                 FROM route_instances
                 WHERE id = :routeInstanceId
                   AND user_id = :ownerUserIdText
                 LIMIT 1",
                {
                    routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" },
                    ownerUserIdText = { value=toString(ownerUserIdVal), cfsqltype="cf_sql_varchar" }
                },
                { datasource=ds }
            );
            if (qInst.recordCount GT 0 AND !isNull(qInst.template_route_code[1])) {
                templateCodeVal = trim(toString(qInst.template_route_code[1]));
            }

            mapSql =
                "SELECT
                    ril.leg_order,
                    rt.short_code AS template_short_code,
                    rts.order_index AS template_leg_order
                 FROM route_instance_legs ril
                 LEFT JOIN route_template_segments rts ON rts.segment_id = ril.segment_id
                 LEFT JOIN loop_routes rt ON rt.id = rts.route_id
                 WHERE ril.route_instance_id = :routeInstanceId";
            mapParams = {
                routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" }
            };
            if (len(templateCodeVal)) {
                mapSql &= "
                    AND (rt.short_code = :templateCode OR rt.code = :templateCode)";
                mapParams.templateCode = { value=templateCodeVal, cfsqltype="cf_sql_varchar" };
            }
            mapSql &= "
                 ORDER BY
                    ril.leg_order ASC,
                    CASE
                        WHEN rt.short_code = :templateCodeSort THEN 0
                        WHEN rt.code = :templateCodeSort THEN 1
                        ELSE 2
                    END,
                    rt.is_default DESC,
                    rt.id ASC,
                    rts.order_index ASC";
            mapParams.templateCodeSort = { value=templateCodeVal, cfsqltype="cf_sql_varchar" };
            qLegTemplate = queryExecute(mapSql, mapParams, { datasource=ds });

            for (i = 1; i LTE qLegTemplate.recordCount; i++) {
                orderKey = toString(val(qLegTemplate.leg_order[i]));
                if (!len(orderKey) OR structKeyExists(templateByOrder, orderKey)) {
                    continue;
                }
                shortCodeVal = (isNull(qLegTemplate.template_short_code[i]) ? "" : trim(toString(qLegTemplate.template_short_code[i])));
                templateLegVal = (isNull(qLegTemplate.template_leg_order[i]) ? 0 : val(qLegTemplate.template_leg_order[i]));
                if (!len(shortCodeVal) OR templateLegVal LTE 0) {
                    continue;
                }
                templateByOrder[orderKey] = {
                    "template_short_code"=shortCodeVal,
                    "template_leg_order"=templateLegVal
                };
            }

            for (orderKey in templateByOrder) {
                shortCodeVal = templateByOrder[orderKey].template_short_code;
                templateLegVal = val(templateByOrder[orderKey].template_leg_order);
                pairKey = shortCodeVal & "|" & toString(templateLegVal);
                if (!structKeyExists(detailCache, pairKey)) {
                    detailCache[pairKey] = fetchFollowLegLockDetails(shortCodeVal, templateLegVal, hasDelayModel);
                }
                details = duplicate(detailCache[pairKey]);
                if (structKeyExists(out, orderKey) AND isStruct(out[orderKey]) AND isNumeric(out[orderKey].lock_count) AND val(out[orderKey].lock_count) GT val(details.lock_count)) {
                    details.lock_count = val(out[orderKey].lock_count);
                }
                out[orderKey] = details;
            }

            return out;
        </cfscript>
    </cffunction>

    <cffunction name="fetchFollowLegLockDetails" access="private" returntype="struct" output="false">
        <cfargument name="templateShortCode" type="string" required="true">
        <cfargument name="templateLegOrder" type="numeric" required="true">
        <cfargument name="hasDelayModel" type="boolean" required="false" default="false">
        <cfscript>
            var out = {
                "lock_count"=0,
                "lock_message"="No locks mapped for this leg.",
                "totals"={
                    "base_cycle_min"=0,
                    "best_wait_min"=0,
                    "typical_wait_min"=0,
                    "worst_wait_min"=0
                },
                "locks"=[]
            };
            var shortCodeVal = trim(arguments.templateShortCode);
            var templateLegVal = val(arguments.templateLegOrder);
            var ds = resolveDatasource();
            var qLocks = queryNew("");
            var lockSql = "";
            var i = 0;
            var lockRow = {};
            var totalBaseCycleMin = 0;
            var totalBestWaitMin = 0;
            var totalTypicalWaitMin = 0;
            var totalWorstWaitMin = 0;

            if (!len(shortCodeVal) OR templateLegVal LTE 0) return out;

            lockSql =
                "SELECT
                    rll.seq,
                    rll.lock_code,
                    COALESCE(cl.name, rll.lock_code) AS lock_name,
                    COALESCE(cl.waterway, '') AS waterway,
                    COALESCE(cl.state, '') AS state_code,
                    COALESCE(cl.country, '') AS country_code,
                    cl.lat,
                    cl.lng,
                    COALESCE(cl.lock_type, '') AS lock_type,
                    cl.chamber_length_ft,
                    cl.chamber_width_ft,
                    COALESCE(cl.agency, '') AS agency,
                    COALESCE(cl.source, '') AS source_url,
                    COALESCE(cl.notes, '') AS lock_notes,"
                    & (arguments.hasDelayModel ? "
                    ldm.base_cycle_min,
                    ldm.best_wait_min,
                    ldm.typical_wait_min,
                    ldm.worst_wait_min,
                    COALESCE(ldm.notes, '') AS delay_notes" : "
                    NULL AS base_cycle_min,
                    NULL AS best_wait_min,
                    NULL AS typical_wait_min,
                    NULL AS worst_wait_min,
                    '' AS delay_notes")
                    & "
                 FROM route_leg_locks rll
                 LEFT JOIN canonical_locks cl ON cl.lock_code = rll.lock_code"
                    & (arguments.hasDelayModel ? "
                 LEFT JOIN lock_delay_model ldm ON ldm.lock_code = rll.lock_code" : "")
                    & "
                 WHERE rll.route_code COLLATE utf8mb4_unicode_ci = :routeShortCode
                   AND rll.leg = :templateLeg
                 ORDER BY rll.seq ASC, rll.lock_code ASC";
            qLocks = queryExecute(
                lockSql,
                {
                    routeShortCode = { value=shortCodeVal, cfsqltype="cf_sql_varchar" },
                    templateLeg = { value=templateLegVal, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            for (i = 1; i LTE qLocks.recordCount; i++) {
                lockRow = {
                    "seq"=(isNull(qLocks.seq[i]) ? i : val(qLocks.seq[i])),
                    "lock_code"=(isNull(qLocks.lock_code[i]) ? "" : trim(toString(qLocks.lock_code[i]))),
                    "name"=(isNull(qLocks.lock_name[i]) ? "" : trim(toString(qLocks.lock_name[i]))),
                    "waterway"=(isNull(qLocks.waterway[i]) ? "" : trim(toString(qLocks.waterway[i]))),
                    "state_code"=(isNull(qLocks.state_code[i]) ? "" : trim(toString(qLocks.state_code[i]))),
                    "country_code"=(isNull(qLocks.country_code[i]) ? "" : trim(toString(qLocks.country_code[i]))),
                    "lat"=(isNull(qLocks.lat[i]) ? javacast("null", "") : val(qLocks.lat[i])),
                    "lng"=(isNull(qLocks.lng[i]) ? javacast("null", "") : val(qLocks.lng[i])),
                    "lock_type"=(isNull(qLocks.lock_type[i]) ? "" : trim(toString(qLocks.lock_type[i]))),
                    "chamber_length_ft"=(isNull(qLocks.chamber_length_ft[i]) ? 0 : val(qLocks.chamber_length_ft[i])),
                    "chamber_width_ft"=(isNull(qLocks.chamber_width_ft[i]) ? 0 : val(qLocks.chamber_width_ft[i])),
                    "agency"=(isNull(qLocks.agency[i]) ? "" : trim(toString(qLocks.agency[i]))),
                    "source_url"=(isNull(qLocks.source_url[i]) ? "" : trim(toString(qLocks.source_url[i]))),
                    "lock_notes"=(isNull(qLocks.lock_notes[i]) ? "" : trim(toString(qLocks.lock_notes[i]))),
                    "base_cycle_min"=(isNull(qLocks.base_cycle_min[i]) ? 0 : val(qLocks.base_cycle_min[i])),
                    "best_wait_min"=(isNull(qLocks.best_wait_min[i]) ? 0 : val(qLocks.best_wait_min[i])),
                    "typical_wait_min"=(isNull(qLocks.typical_wait_min[i]) ? 0 : val(qLocks.typical_wait_min[i])),
                    "worst_wait_min"=(isNull(qLocks.worst_wait_min[i]) ? 0 : val(qLocks.worst_wait_min[i])),
                    "delay_notes"=(isNull(qLocks.delay_notes[i]) ? "" : trim(toString(qLocks.delay_notes[i])))
                };
                arrayAppend(out.locks, lockRow);
                totalBaseCycleMin += val(lockRow.base_cycle_min);
                totalBestWaitMin += val(lockRow.best_wait_min);
                totalTypicalWaitMin += val(lockRow.typical_wait_min);
                totalWorstWaitMin += val(lockRow.worst_wait_min);
            }

            out.lock_count = arrayLen(out.locks);
            out.totals = {
                "base_cycle_min"=totalBaseCycleMin,
                "best_wait_min"=totalBestWaitMin,
                "typical_wait_min"=totalTypicalWaitMin,
                "worst_wait_min"=totalWorstWaitMin
            };
            if (out.lock_count GT 0) {
                out.lock_message = "OK";
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="readStream" access="private" returntype="struct" output="false">
        <cfargument name="slug" type="string" required="false" default="">
        <cfargument name="streamId" type="numeric" required="false" default="0">
        <cfscript>
            var out = {};
            var ds = resolveDatasource();
            var q = queryNew("");
            var streamIdVal = val(arguments.streamId);
            var slugVal = normalizeSlug(arguments.slug);

            if (streamIdVal GT 0) {
                q = queryExecute(
                    "SELECT
                        id,
                        floatplan_id,
                        owner_user_id,
                        slug,
                        share_token,
                        privacy_mode,
                        password_hash,
                        allow_interactions,
                        created_utc,
                        updated_utc
                     FROM voyage_streams
                     WHERE id = :streamId
                     LIMIT 1",
                    {
                        streamId = { value=streamIdVal, cfsqltype="cf_sql_integer" }
                    },
                    { datasource=ds }
                );
            } else if (len(slugVal)) {
                q = queryExecute(
                    "SELECT
                        id,
                        floatplan_id,
                        owner_user_id,
                        slug,
                        share_token,
                        privacy_mode,
                        password_hash,
                        allow_interactions,
                        created_utc,
                        updated_utc
                     FROM voyage_streams
                     WHERE slug = :slug
                     LIMIT 1",
                    {
                        slug = { value=slugVal, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource=ds }
                );
            }

            if (q.recordCount EQ 0) {
                return out;
            }

            out = {
                "id"=val(q.id[1]),
                "floatplan_id"=val(q.floatplan_id[1]),
                "owner_user_id"=val(q.owner_user_id[1]),
                "slug"=(isNull(q.slug[1]) ? "" : toString(q.slug[1])),
                "share_token"=(isNull(q.share_token[1]) ? "" : toString(q.share_token[1])),
                "privacy_mode"=normalizePrivacyMode(isNull(q.privacy_mode[1]) ? "public" : toString(q.privacy_mode[1])),
                "password_hash"=(isNull(q.password_hash[1]) ? "" : toString(q.password_hash[1])),
                "allow_interactions"=(isNull(q.allow_interactions[1]) ? 0 : val(q.allow_interactions[1])),
                "created_utc"=formatUtcDate(q.created_utc[1]),
                "updated_utc"=formatUtcDate(q.updated_utc[1])
            };
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="canReadStream" access="private" returntype="struct" output="false">
        <cfargument name="streamRow" type="struct" required="true">
        <cfargument name="shareToken" type="string" required="false" default="">
        <cfargument name="isOwner" type="boolean" required="false" default="false">
        <cfscript>
            var out = {
                "allowed"=false,
                "code"="FORBIDDEN",
                "message"="Access denied"
            };
            var modeVal = normalizePrivacyMode(
                structKeyExists(arguments.streamRow, "privacy_mode") ? arguments.streamRow.privacy_mode : "public"
            );
            var tokenVal = trim(arguments.shareToken);
            var expectedToken = trim(
                toString(structKeyExists(arguments.streamRow, "share_token") ? arguments.streamRow.share_token : "")
            );

            if (arguments.isOwner) {
                out.allowed = true;
                out.code = "OK";
                out.message = "OK";
                return out;
            }

            if (modeVal EQ "public") {
                out.allowed = true;
                out.code = "OK";
                out.message = "OK";
                return out;
            }

            if (!len(tokenVal) OR tokenVal NEQ expectedToken) {
                out.allowed = false;
                out.code = "INVALID_SHARE_TOKEN";
                out.message = "A valid share token is required for this stream.";
                return out;
            }

            out.allowed = true;
            out.code = "OK";
            out.message = "OK";
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="resolveInteractionContext" access="private" returntype="struct" output="false">
        <cfargument name="postId" type="numeric" required="true">
        <cfargument name="followerToken" type="string" required="false" default="">
        <cfargument name="currentUserId" type="numeric" required="false" default="0">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Interaction not allowed"
            };
            var postIdVal = val(arguments.postId);
            var tokenVal = trim(arguments.followerToken);
            var ds = resolveDatasource();
            var q = queryNew("");
            var ownerFollower = {};
            var memberGateResult = {};

            if (postIdVal LTE 0) {
                out.MESSAGE = "post_id required";
                out.ERROR = { "MESSAGE"="post_id is required." };
                return out;
            }
            if (len(tokenVal)) {
                q = queryExecute(
                    "SELECT
                        vp.id AS post_id,
                        vp.stream_id,
                        vs.owner_user_id,
                        vs.allow_interactions,
                        vf.id AS follower_id,
                        vf.display_name,
                        vf.is_blocked
                     FROM voyage_posts vp
                     INNER JOIN voyage_streams vs ON vs.id = vp.stream_id
                     INNER JOIN voyage_followers vf ON vf.stream_id = vs.id
                     WHERE vp.id = :postId
                       AND vf.access_token = :token
                     LIMIT 1",
                    {
                        postId = { value=postIdVal, cfsqltype="cf_sql_integer" },
                        token = { value=tokenVal, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource=ds }
                );

                if (q.recordCount EQ 0) {
                    out.MESSAGE = "Follower not found";
                    out.STATUS_CODE = 403;
                    out.ERROR = { "CODE"="FOLLOWER_NOT_FOUND", "MESSAGE"="Follower token is invalid for this stream." };
                    return out;
                }
                if (val(q.is_blocked[1]) GT 0) {
                    out.MESSAGE = "Follower blocked";
                    out.STATUS_CODE = 403;
                    out.ERROR = { "CODE"="FOLLOWER_BLOCKED", "MESSAGE"="This follower has been blocked." };
                    return out;
                }
                if (val(q.allow_interactions[1]) LTE 0) {
                    out.MESSAGE = "Interactions disabled";
                    out.STATUS_CODE = 403;
                    out.ERROR = { "CODE"="INTERACTIONS_DISABLED", "MESSAGE"="Interactions are disabled for this stream." };
                    return out;
                }

                memberGateResult = requireOwnerPremiumFollowAccess(val(q.owner_user_id[1]));
                if (!memberGateResult.SUCCESS) {
                    return memberGateResult;
                }

                queryExecute(
                    "UPDATE voyage_followers
                     SET last_seen_utc = UTC_TIMESTAMP()
                     WHERE id = :id",
                    {
                        id = { value=val(q.follower_id[1]), cfsqltype="cf_sql_integer" }
                    },
                    { datasource=ds }
                );

                out.SUCCESS = true;
                out.MESSAGE = "OK";
                out.stream_id = val(q.stream_id[1]);
                out.post_id = val(q.post_id[1]);
                out.follower = {
                    "id"=val(q.follower_id[1]),
                    "display_name"=(isNull(q.display_name[1]) ? "Viewer" : toString(q.display_name[1]))
                };
                return out;
            }

            if (arguments.currentUserId GT 0) {
                q = queryExecute(
                    "SELECT
                        vp.id AS post_id,
                        vp.stream_id,
                        vs.owner_user_id
                     FROM voyage_posts vp
                     INNER JOIN voyage_streams vs ON vs.id = vp.stream_id
                     WHERE vp.id = :postId
                     LIMIT 1",
                    {
                        postId = { value=postIdVal, cfsqltype="cf_sql_integer" }
                    },
                    { datasource=ds }
                );

                if (q.recordCount GT 0 AND val(q.owner_user_id[1]) EQ arguments.currentUserId) {
                    memberGateResult = requireOwnerPremiumFollowAccess(val(q.owner_user_id[1]));
                    if (!memberGateResult.SUCCESS) {
                        return memberGateResult;
                    }
                    ownerFollower = ensureOwnerInteractionFollower(val(q.stream_id[1]), arguments.currentUserId);
                    if (!structCount(ownerFollower)) {
                        out.MESSAGE = "Owner interaction unavailable";
                        out.STATUS_CODE = 500;
                        out.ERROR = { "CODE"="OWNER_ACTOR_UNAVAILABLE", "MESSAGE"="Unable to resolve the owner interaction identity." };
                        return out;
                    }

                    out.SUCCESS = true;
                    out.MESSAGE = "OK";
                    out.stream_id = val(q.stream_id[1]);
                    out.post_id = val(q.post_id[1]);
                    out.follower = {
                        "id"=ownerFollower.id,
                        "display_name"=ownerFollower.display_name
                    };
                    return out;
                }
            }

            out.MESSAGE = "follower_token required";
            out.STATUS_CODE = 403;
            out.ERROR = { "CODE"="FOLLOWER_TOKEN_REQUIRED", "MESSAGE"="follower_token is required." };
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="findOwnerInteractionFollower" access="private" returntype="struct" output="false">
        <cfargument name="streamId" type="numeric" required="true">
        <cfargument name="currentUserId" type="numeric" required="true">
        <cfscript>
            var out = {};
            var streamIdVal = val(arguments.streamId);
            var currentUserIdVal = val(arguments.currentUserId);
            var profile = {};
            var ds = resolveDatasource();
            var q = queryNew("");

            if (streamIdVal LTE 0 OR currentUserIdVal LTE 0) {
                return out;
            }

            profile = resolveOwnerInteractionProfile(currentUserIdVal);
            if (!len(profile.internal_email)) {
                return out;
            }

            q = queryExecute(
                "SELECT id, stream_id, display_name, is_blocked, access_token
                 FROM voyage_followers
                 WHERE stream_id = :streamId
                   AND email = :email
                 LIMIT 1",
                {
                    streamId = { value=streamIdVal, cfsqltype="cf_sql_integer" },
                    email = { value=profile.internal_email, cfsqltype="cf_sql_varchar" }
                },
                { datasource=ds }
            );
            if (q.recordCount EQ 0) {
                return out;
            }

            out = {
                "id"=val(q.id[1]),
                "stream_id"=val(q.stream_id[1]),
                "display_name"=(isNull(q.display_name[1]) ? profile.display_name : toString(q.display_name[1])),
                "is_blocked"=(isNull(q.is_blocked[1]) ? 0 : val(q.is_blocked[1])),
                "access_token"=(isNull(q.access_token[1]) ? "" : toString(q.access_token[1]))
            };
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="ensureOwnerInteractionFollower" access="private" returntype="struct" output="false">
        <cfargument name="streamId" type="numeric" required="true">
        <cfargument name="currentUserId" type="numeric" required="true">
        <cfscript>
            var out = {};
            var streamIdVal = val(arguments.streamId);
            var currentUserIdVal = val(arguments.currentUserId);
            var profile = {};
            var ds = resolveDatasource();
            var accessToken = "";

            if (streamIdVal LTE 0 OR currentUserIdVal LTE 0) {
                return out;
            }

            profile = resolveOwnerInteractionProfile(currentUserIdVal);
            if (!len(profile.internal_email)) {
                return out;
            }

            lock name=("voyage_owner_actor_" & streamIdVal & "_" & currentUserIdVal) type="exclusive" timeout="5" {
                out = findOwnerInteractionFollower(streamIdVal, currentUserIdVal);
                if (structCount(out)) {
                    queryExecute(
                        "UPDATE voyage_followers
                         SET display_name = :displayName,
                             is_blocked = 0,
                             last_seen_utc = UTC_TIMESTAMP()
                         WHERE id = :id",
                        {
                            displayName = { value=left(profile.display_name, 120), cfsqltype="cf_sql_varchar" },
                            id = { value=out.id, cfsqltype="cf_sql_integer" }
                        },
                        { datasource=ds }
                    );
                } else {
                    accessToken = randomToken(40);
                    queryExecute(
                        "INSERT INTO voyage_followers (
                            stream_id,
                            display_name,
                            email,
                            access_token,
                            is_blocked,
                            created_utc,
                            last_seen_utc
                         ) VALUES (
                            :streamId,
                            :displayName,
                            :email,
                            :accessToken,
                            0,
                            UTC_TIMESTAMP(),
                            UTC_TIMESTAMP()
                         )",
                        {
                            streamId = { value=streamIdVal, cfsqltype="cf_sql_integer" },
                            displayName = { value=left(profile.display_name, 120), cfsqltype="cf_sql_varchar" },
                            email = { value=profile.internal_email, cfsqltype="cf_sql_varchar" },
                            accessToken = { value=accessToken, cfsqltype="cf_sql_varchar" }
                        },
                        { datasource=ds }
                    );
                }

                out = findOwnerInteractionFollower(streamIdVal, currentUserIdVal);
                if (structCount(out)) {
                    out.display_name = left(profile.display_name, 120);
                    out.is_blocked = 0;
                }
            }

            return out;
        </cfscript>
    </cffunction>

    <cffunction name="resolveFollowerByToken" access="private" returntype="struct" output="false">
        <cfargument name="token" type="string" required="false" default="">
        <cfscript>
            var out = {};
            var tokenVal = trim(arguments.token);
            var ds = resolveDatasource();
            var q = queryNew("");

            if (!len(tokenVal)) return out;

            q = queryExecute(
                "SELECT id, stream_id, display_name, is_blocked
                 FROM voyage_followers
                 WHERE access_token = :token
                 LIMIT 1",
                {
                    token = { value=tokenVal, cfsqltype="cf_sql_varchar" }
                },
                { datasource=ds }
            );
            if (q.recordCount EQ 0) return out;

            out = {
                "id"=val(q.id[1]),
                "stream_id"=val(q.stream_id[1]),
                "display_name"=(isNull(q.display_name[1]) ? "Viewer" : toString(q.display_name[1])),
                "is_blocked"=(isNull(q.is_blocked[1]) ? 0 : val(q.is_blocked[1]))
            };
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="enforceRateLimit" access="private" returntype="struct" output="false">
        <cfargument name="key" type="string" required="true">
        <cfargument name="windowSeconds" type="numeric" required="false" default="1">
        <cfscript>
            var out = {
                "allowed"=true,
                "retry_after"=0
            };
            var nowTs = getTickCount();
            var keyVal = trim(arguments.key);
            var windowMs = max(1, val(arguments.windowSeconds)) * 1000;
            var lastTs = 0;
            if (!len(keyVal)) return out;

            lock name="voyage_rate_limit_lock" type="exclusive" timeout="5" {
                if (!structKeyExists(application, "voyageRateLimit") OR !isStruct(application.voyageRateLimit)) {
                    application.voyageRateLimit = {};
                }

                if (structKeyExists(application.voyageRateLimit, keyVal)) {
                    lastTs = val(application.voyageRateLimit[keyVal]);
                    if ((nowTs - lastTs) LT windowMs) {
                        out.allowed = false;
                        out.retry_after = ceiling((windowMs - (nowTs - lastTs)) / 1000);
                    }
                }

                if (out.allowed) {
                    application.voyageRateLimit[keyVal] = nowTs;
                }
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="buildApiEnvelope" access="private" returntype="struct" output="false">
        <cfargument name="success" type="boolean" required="true">
        <cfargument name="code" type="string" required="true">
        <cfargument name="message" type="string" required="true">
        <cfargument name="data" type="struct" required="false" default="#{}#">
        <cfargument name="auth" type="boolean" required="false" default="true">
        <cfscript>
            var payloadData = (isStruct(arguments.data) ? arguments.data : {});
            var out = {
                "ok"=arguments.success,
                "success"=arguments.success,
                "SUCCESS"=arguments.success,
                "code"=arguments.code,
                "CODE"=arguments.code,
                "message"=arguments.message,
                "MESSAGE"=arguments.message,
                "AUTH"=arguments.auth,
                "data"=payloadData,
                "DATA"=payloadData
            };
            if (!arguments.success) {
                out.ERROR = { "CODE"=arguments.code, "MESSAGE"=arguments.message };
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="checkVoyageStorageReady" access="private" returntype="struct" output="false">
        <cfscript>
            var out = { "ready"=false, "missing_tables"=[] };
            var ds = resolveDatasource();
            var qDb = queryNew("");
            var qTables = queryNew("");
            var schemaName = "";
            var requiredTables = [ "voyage_streams", "voyage_followers", "voyage_posts", "voyage_reactions", "voyage_comments" ];
            var foundTables = {};
            var i = 0;
            var nameVal = "";

            try {
                qDb = queryExecute(
                    "SELECT DATABASE() AS db_name",
                    {},
                    { datasource=ds }
                );
                if (qDb.recordCount GT 0 AND !isNull(qDb.db_name[1])) {
                    schemaName = trim(toString(qDb.db_name[1]));
                }
                if (!len(schemaName)) {
                    out.missing_tables = requiredTables;
                    return out;
                }

                qTables = queryExecute(
                    "SELECT table_name
                     FROM information_schema.tables
                     WHERE table_schema = :schemaName
                       AND table_name IN ('voyage_streams','voyage_followers','voyage_posts','voyage_reactions','voyage_comments')",
                    {
                        schemaName = { value=schemaName, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource=ds }
                );

                for (i = 1; i LTE qTables.recordCount; i++) {
                    nameVal = lCase(trim(toString(qTables.table_name[i])));
                    if (len(nameVal)) {
                        foundTables[nameVal] = true;
                    }
                }

                for (i = 1; i LTE arrayLen(requiredTables); i++) {
                    if (!structKeyExists(foundTables, requiredTables[i])) {
                        arrayAppend(out.missing_tables, requiredTables[i]);
                    }
                }

                out.ready = (arrayLen(out.missing_tables) EQ 0);
                return out;
            } catch (any e) {
                out.ready = false;
                out.missing_tables = requiredTables;
                return out;
            }
        </cfscript>
    </cffunction>

    <cffunction name="normalizeEnsurePins" access="private" returntype="array" output="false">
        <cfargument name="pinsRaw" type="any" required="true">
        <cfscript>
            var out = [];
            var list = (isArray(arguments.pinsRaw) ? arguments.pinsRaw : []);
            var i = 0;
            var pin = {};
            var latVal = 0.0;
            var lngVal = 0.0;
            var seqVal = 0;
            var typeVal = "";
            var labelVal = "";

            for (i = 1; i LTE arrayLen(list); i++) {
                pin = (isStruct(list[i]) ? list[i] : {});
                if (!structCount(pin)) continue;
                if (!structKeyExists(pin, "lat") OR !structKeyExists(pin, "lng")) continue;
                if (!isNumeric(pin.lat) OR !isNumeric(pin.lng)) continue;

                latVal = val(pin.lat);
                lngVal = val(pin.lng);
                seqVal = (
                    structKeyExists(pin, "seq") AND isNumeric(pin.seq)
                        ? val(pin.seq)
                        : (
                            structKeyExists(pin, "sequence") AND isNumeric(pin.sequence)
                                ? val(pin.sequence)
                                : i
                        )
                );

                typeVal = lCase(trim(toString(structKeyExists(pin, "type") ? pin.type : "leg_end")));
                if (typeVal EQ "intermediate") {
                    typeVal = "leg_end";
                }
                if (!listFindNoCase("start,end,leg_end,waypoint", typeVal)) {
                    typeVal = (seqVal EQ 1 ? "start" : "leg_end");
                }
                labelVal = trim(toString(structKeyExists(pin, "label") ? pin.label : ""));
                if (!len(labelVal)) {
                    if (typeVal EQ "start") labelVal = "Start";
                    else if (typeVal EQ "end") labelVal = "End";
                    else labelVal = "Leg " & seqVal & " End";
                }

                arrayAppend(out, {
                    "type"=typeVal,
                    "seq"=seqVal,
                    "label"=labelVal,
                    "lat"=latVal,
                    "lng"=lngVal
                });
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="resolveFpwBasePath" access="private" returntype="string" output="false">
        <cfscript>
            var scriptPath = "";
            var basePath = "";
            if (structKeyExists(cgi, "script_name")) {
                scriptPath = toString(cgi.script_name);
            }
            if (!len(scriptPath)) {
                return "";
            }
            basePath = reReplace(scriptPath, "/api/v1/[^/]+$", "");
            basePath = reReplace(basePath, "/$", "");
            if (basePath EQ "/") {
                basePath = "";
            }
            return basePath;
        </cfscript>
    </cffunction>

    <cffunction name="resolveVoyageUploadDirectory" access="private" returntype="string" output="false">
        <cfargument name="streamId" type="numeric" required="true">
        <cfscript>
            var apiDir = getDirectoryFromPath(getCurrentTemplatePath());
            return apiDir & "../../assets/uploads/voyage/" & val(arguments.streamId);
        </cfscript>
    </cffunction>

    <cffunction name="buildVoyageUploadUrl" access="private" returntype="string" output="false">
        <cfargument name="streamId" type="numeric" required="true">
        <cfargument name="fileName" type="string" required="true">
        <cfscript>
            var basePath = resolveFpwBasePath();
            var safeName = trim(toString(arguments.fileName));
            return basePath & "/assets/uploads/voyage/" & val(arguments.streamId) & "/" & safeName;
        </cfscript>
    </cffunction>

    <cffunction name="deleteVoyageUploadFile" access="private" returntype="boolean" output="false">
        <cfargument name="mediaUrl" type="string" required="false" default="">
        <cfargument name="streamId" type="numeric" required="true">
        <cfscript>
            var mediaUrlVal = trim(toString(arguments.mediaUrl));
            var expectedPrefix = buildVoyageUploadUrl(arguments.streamId, "");
            var fileName = "";
            var filePath = "";

            if (!len(mediaUrlVal)) {
                return false;
            }
            if (right(expectedPrefix, 1) NEQ "/") {
                expectedPrefix &= "/";
            }
            if (left(mediaUrlVal, len(expectedPrefix)) NEQ expectedPrefix) {
                return false;
            }

            fileName = listLast(mediaUrlVal, "/");
            if (!reFind("^[A-Za-z0-9._-]+$", fileName)) {
                return false;
            }

            filePath = resolveVoyageUploadDirectory(arguments.streamId) & "/" & fileName;
            if (!fileExists(filePath)) {
                return false;
            }

            try {
                fileDelete(filePath);
                return true;
            } catch (any deleteErr) {
                return false;
            }
        </cfscript>
    </cffunction>

    <cffunction name="buildAbsoluteUrl" access="private" returntype="string" output="false">
        <cfargument name="path" type="string" required="true">
        <cfscript>
            var scheme = "http";
            var host = "";
            var pathVal = trim(arguments.path);
            if (structKeyExists(cgi, "https") AND lCase(toString(cgi.https)) EQ "on") {
                scheme = "https";
            } else if (structKeyExists(cgi, "server_port_secure") AND val(cgi.server_port_secure) EQ 1) {
                scheme = "https";
            }
            host = (
                structKeyExists(cgi, "http_host") AND len(trim(toString(cgi.http_host)))
                    ? trim(toString(cgi.http_host))
                    : trim(toString(cgi.server_name))
            );
            if (!len(host)) host = "localhost";
            if (left(pathVal, 1) NEQ "/") {
                pathVal = "/" & pathVal;
            }
            return scheme & "://" & host & pathVal;
        </cfscript>
    </cffunction>

    <cffunction name="parseFollowGeometryCoordinates" access="private" returntype="array" output="false">
        <cfargument name="rawJson" type="any" required="false">
        <cfscript>
            var out = [];
            var raw = (isNull(arguments.rawJson) ? "" : trim(toString(arguments.rawJson)));
            var parsed = "";
            var item = "";
            var latVal = 0.0;
            var lngVal = 0.0;
            var existing = [];
            var i = 0;

            if (!len(raw)) {
                return out;
            }

            try {
                parsed = deserializeJSON(raw, false);
            } catch (any parseErr) {
                return out;
            }

            if (!isArray(parsed)) {
                return out;
            }

            for (i = 1; i LTE arrayLen(parsed); i++) {
                item = parsed[i];
                if (isArray(item) AND arrayLen(item) GTE 2 AND isNumeric(item[1]) AND isNumeric(item[2])) {
                    lngVal = val(item[1]);
                    latVal = val(item[2]);
                } else if (isStruct(item)) {
                    if (
                        structKeyExists(item, "lat")
                        AND (
                            structKeyExists(item, "lng")
                            OR structKeyExists(item, "lon")
                            OR structKeyExists(item, "longitude")
                        )
                    ) {
                        if (!isNumeric(item.lat)) {
                            continue;
                        }
                        latVal = val(item.lat);
                        if (structKeyExists(item, "lng") AND isNumeric(item.lng)) {
                            lngVal = val(item.lng);
                        } else if (structKeyExists(item, "lon") AND isNumeric(item.lon)) {
                            lngVal = val(item.lon);
                        } else if (structKeyExists(item, "longitude") AND isNumeric(item.longitude)) {
                            lngVal = val(item.longitude);
                        } else {
                            continue;
                        }
                    } else if (
                        structKeyExists(item, "latitude")
                        AND (
                            structKeyExists(item, "lng")
                            OR structKeyExists(item, "lon")
                            OR structKeyExists(item, "longitude")
                        )
                    ) {
                        if (!isNumeric(item.latitude)) {
                            continue;
                        }
                        latVal = val(item.latitude);
                        if (structKeyExists(item, "lng") AND isNumeric(item.lng)) {
                            lngVal = val(item.lng);
                        } else if (structKeyExists(item, "lon") AND isNumeric(item.lon)) {
                            lngVal = val(item.lon);
                        } else if (structKeyExists(item, "longitude") AND isNumeric(item.longitude)) {
                            lngVal = val(item.longitude);
                        } else {
                            continue;
                        }
                    } else {
                        continue;
                    }
                } else {
                    continue;
                }

                if (arrayLen(out) GT 0) {
                    existing = out[arrayLen(out)];
                    if (
                        isArray(existing)
                        AND arrayLen(existing) GTE 2
                        AND existing[1] EQ lngVal
                        AND existing[2] EQ latVal
                    ) {
                        continue;
                    }
                }
                arrayAppend(out, [lngVal, latVal]);
            }

            if (arrayLen(out) LT 2) {
                return [];
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="appendUniqueRoutePoint" access="private" returntype="array" output="false">
        <cfargument name="pointList" type="array" required="true">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfargument name="label" type="string" required="false" default="">
        <cfargument name="minDistanceMeters" type="numeric" required="false" default="20">
        <cfscript>
            var i = 0;
            var existing = {};
            var distanceMeters = 0.0;
            var threshold = max(1, val(arguments.minDistanceMeters));
            for (i = 1; i LTE arrayLen(arguments.pointList); i++) {
                existing = arguments.pointList[i];
                if (!isStruct(existing)) continue;
                if (!structKeyExists(existing, "lat") OR !structKeyExists(existing, "lng")) continue;
                if (!isNumeric(existing.lat) OR !isNumeric(existing.lng)) continue;
                distanceMeters = haversineMeters(arguments.lat, arguments.lng, val(existing.lat), val(existing.lng));
                if (distanceMeters LTE threshold) {
                    return arguments.pointList;
                }
            }
            arrayAppend(arguments.pointList, {
                "lat"=arguments.lat,
                "lng"=arguments.lng,
                "label"=(len(trim(arguments.label)) ? trim(arguments.label) : "Point")
            });
            return arguments.pointList;
        </cfscript>
    </cffunction>

    <cffunction name="haversineMeters" access="private" returntype="numeric" output="false">
        <cfargument name="lat1" type="numeric" required="true">
        <cfargument name="lon1" type="numeric" required="true">
        <cfargument name="lat2" type="numeric" required="true">
        <cfargument name="lon2" type="numeric" required="true">
        <cfscript>
            var earthRadiusMeters = 6371008.8;
            var dLat = toRadians(arguments.lat2 - arguments.lat1);
            var dLon = toRadians(arguments.lon2 - arguments.lon1);
            var phi1 = toRadians(arguments.lat1);
            var phi2 = toRadians(arguments.lat2);
            var a = (sin(dLat / 2) ^ 2) + cos(phi1) * cos(phi2) * (sin(dLon / 2) ^ 2);
            if (a LT 0) a = 0;
            if (a GT 1) a = 1;
            return 2 * earthRadiusMeters * atn2Compat(sqr(a), sqr(1 - a));
        </cfscript>
    </cffunction>

    <cffunction name="toRadians" access="private" returntype="numeric" output="false">
        <cfargument name="deg" type="numeric" required="true">
        <cfscript>
            return arguments.deg * (pi() / 180);
        </cfscript>
    </cffunction>

    <cffunction name="atn2Compat" access="private" returntype="numeric" output="false">
        <cfargument name="y" type="numeric" required="true">
        <cfargument name="x" type="numeric" required="true">
        <cfscript>
            if (arguments.x GT 0) {
                return atn(arguments.y / arguments.x);
            }
            if (arguments.x LT 0 AND arguments.y GTE 0) {
                return atn(arguments.y / arguments.x) + pi();
            }
            if (arguments.x LT 0 AND arguments.y LT 0) {
                return atn(arguments.y / arguments.x) - pi();
            }
            if (arguments.x EQ 0 AND arguments.y GT 0) {
                return pi() / 2;
            }
            if (arguments.x EQ 0 AND arguments.y LT 0) {
                return -pi() / 2;
            }
            return 0;
        </cfscript>
    </cffunction>

    <cffunction name="friendlyStatusLabel" access="private" returntype="string" output="false">
        <cfargument name="rawStatus" type="string" required="false" default="">
        <cfscript>
            var s = uCase(trim(arguments.rawStatus));
            if (s EQ "ACTIVE") return "All Good";
            if (s EQ "OVERDUE") return "Attention Needed";
            if (s EQ "CLOSED") return "Voyage Closed";
            if (s EQ "DRAFT") return "Draft";
            if (!len(s)) return "Status Unavailable";
            return s;
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

    <cffunction name="formatElapsedCheckIn" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="false">
        <cfscript>
            var elapsedMinutes = 0;
            var hours = 0;
            var minutes = 0;

            if (!isDate(arguments.value)) {
                return "-- since last check-in";
            }

            elapsedMinutes = dateDiff("n", arguments.value, now());
            if (elapsedMinutes LT 0) {
                elapsedMinutes = 0;
            }
            if (elapsedMinutes LT 60) {
                return elapsedMinutes & " min since last check-in";
            }

            hours = int(elapsedMinutes / 60);
            minutes = elapsedMinutes MOD 60;
            if (minutes LTE 0) {
                return hours & "h since last check-in";
            }
            return hours & "h " & minutes & "m since last check-in";
        </cfscript>
    </cffunction>

    <cffunction name="formatUtcInstantFromLocalTime" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="false">
        <cfargument name="timeZoneId" type="string" required="false" default="">
        <cfscript>
            if (isNull(arguments.value) OR !isDate(arguments.value) OR !len(trim(toString(arguments.timeZoneId)))) {
                return "";
            }
            return formatUtcDate(arguments.value);
        </cfscript>
    </cffunction>

    <cffunction name="normalizeVoyageDisplayTimezone" access="private" returntype="string" output="false">
        <cfargument name="timeZoneId" type="string" required="false" default="">
        <cfscript>
            var tz = trim(toString(arguments.timeZoneId));
            var tzKey = uCase(tz);

            if (!len(tz)) {
                return "";
            }

            switch (tzKey) {
                case "US/EASTERN":
                    return "America/New_York";
                case "US/CENTRAL":
                    return "America/Chicago";
                case "US/MOUNTAIN":
                    return "America/Denver";
                case "US/PACIFIC":
                    return "America/Los_Angeles";
                case "US/ALASKA":
                    return "America/Anchorage";
                case "US/HAWAII":
                    return "Pacific/Honolulu";
                case "+00:00":
                case "UTC":
                case "ETC/UTC":
                case "GMT":
                    return "UTC";
            }

            try {
                dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss", tz);
                return tz;
            } catch (any invalidVoyageDisplayTimezoneErr) {
                return "";
            }
        </cfscript>
    </cffunction>

    <cffunction name="formatVoyageUtcDisplayLabel" access="private" returntype="string" output="false">
        <cfargument name="utcValue" type="any" required="false">
        <cfargument name="timeZoneId" type="string" required="false" default="">
        <cfscript>
            var tz = normalizeVoyageDisplayTimezone(arguments.timeZoneId);
            var raw = "";
            var normalized = "";
            var utcDt = "";

            if (!len(tz) OR isNull(arguments.utcValue)) {
                return "";
            }

            if (isDate(arguments.utcValue)) {
                utcDt = arguments.utcValue;
            } else {
                raw = trim(toString(arguments.utcValue));
                if (!len(raw)) {
                    return "";
                }
                normalized = replace(raw, "T", " ", "one");
                if (
                    reFindNoCase("([+-][0-9]{2}:?[0-9]{2})$", normalized)
                    AND !reFindNoCase("([+-]00:?00)$", normalized)
                ) {
                    return "";
                }
                normalized = reReplaceNoCase(normalized, "Z$", "", "one");
                normalized = reReplaceNoCase(normalized, "([+-]00:?00)$", "", "one");
                normalized = reReplace(normalized, "\.[0-9]+$", "", "one");
                if (reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}$", normalized)) {
                    normalized &= ":00";
                }
                if (!isDate(normalized)) {
                    return "";
                }
                utcDt = parseDateTime(normalized);
            }

            try {
                return dateTimeFormat(utcDt, "mmm d, yyyy h:nn tt", tz);
            } catch (any voyageUtcDisplayLabelErr) {
                return "";
            }
        </cfscript>
    </cffunction>

    <cffunction name="formatUtcDate" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="false">
        <cfscript>
            if (isNull(arguments.value)) return "";
            if (!isDate(arguments.value)) {
                return trim(toString(arguments.value));
            }
            return dateTimeFormat(arguments.value, "yyyy-mm-dd'T'HH:nn:ss'Z'");
        </cfscript>
    </cffunction>

    <cffunction name="loadOvernightTimingRule" access="private" returntype="struct" output="false">
        <cfargument name="dailyStartLocalTime" type="string" required="false" default="">
        <cfscript>
            var cacheKey = "fpwOvernightTimingRule:" & trim(arguments.dailyStartLocalTime);
            var overnightTimingService = "";
            if (structKeyExists(request, cacheKey) AND isStruct(request[cacheKey])) {
                return duplicate(request[cacheKey]);
            }
            try {
                overnightTimingService = createObject("component", "fpw.api.v1.OvernightTimingService").init();
            } catch (any overnightTimingErr) {
                overnightTimingService = createObject("component", "api.v1.OvernightTimingService").init();
            }
            request[cacheKey] = overnightTimingService.getLocalDayStartRule(arguments.dailyStartLocalTime);
            return duplicate(request[cacheKey]);
        </cfscript>
    </cffunction>

    <cffunction name="roundTo1" access="private" returntype="numeric" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            var n = (isNumeric(arguments.value) ? val(arguments.value) : 0);
            return int(n * 10 + 0.5) / 10;
        </cfscript>
    </cffunction>

    <cffunction name="roundTo2" access="private" returntype="numeric" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            var n = (isNumeric(arguments.value) ? val(arguments.value) : 0);
            return int(n * 100 + 0.5) / 100;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeSlug" access="private" returntype="string" output="false">
        <cfargument name="value" type="string" required="false" default="">
        <cfscript>
            var slug = lCase(trim(arguments.value));
            slug = reReplace(slug, "[^a-z0-9\-]", "-", "all");
            slug = reReplace(slug, "-{2,}", "-", "all");
            slug = reReplace(slug, "(^-|-$)", "", "all");
            if (len(slug) GT 120) slug = left(slug, 120);
            return slug;
        </cfscript>
    </cffunction>

    <cffunction name="normalizePrivacyMode" access="private" returntype="string" output="false">
        <cfargument name="value" type="string" required="false" default="public">
        <cfscript>
            var mode = lCase(trim(arguments.value));
            if (!listFindNoCase("public,password,invite", mode)) {
                return "public";
            }
            return mode;
        </cfscript>
    </cffunction>

    <cffunction name="randomToken" access="private" returntype="string" output="false">
        <cfargument name="length" type="numeric" required="false" default="32">
        <cfscript>
            var desired = max(8, val(arguments.length));
            var token = "";
            while (len(token) LT desired) {
                token &= lCase(replace(createUUID(), "-", "", "all"));
            }
            return left(token, desired);
        </cfscript>
    </cffunction>

    <cffunction name="resolveDatasource" access="private" returntype="string" output="false">
        <cfscript>
            if (structKeyExists(application, "dsn") AND len(trim(toString(application.dsn)))) {
                return trim(toString(application.dsn));
            }
            if (structKeyExists(application, "DSN") AND len(trim(toString(application.DSN)))) {
                return trim(toString(application.DSN));
            }
            return "fpw";
        </cfscript>
    </cffunction>

    <cffunction name="requireOwnerPremiumFollowAccess" access="private" returntype="struct" output="false">
        <cfargument name="ownerUserId" type="numeric" required="true">
        <cfscript>
            return requireMemberPremiumAccess(
                userId = arguments.ownerUserId,
                errorCode = "BASIC_FOLLOW_RESTRICTED",
                message = "Upgrade to Premium to share a Follow Page."
            );
        </cfscript>
    </cffunction>

    <cffunction name="requireMemberPremiumAccess" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="errorCode" type="string" required="true">
        <cfargument name="message" type="string" required="true">
        <cfscript>
            var gateResult = getMemberAccessGateService().requirePremium(
                userId = arguments.userId,
                errorCode = arguments.errorCode,
                message = arguments.message
            );
            if (gateResult.allowed) {
                return { "SUCCESS" = true, "success" = true, "AUTH" = true };
            }
            return gateResult.response;
        </cfscript>
    </cffunction>

    <cffunction name="getMemberAccessGateService" access="private" returntype="any" output="false">
        <cfscript>
            try {
                return createObject("component", "fpw.api.v1.MemberAccessGateService").init(resolveDatasource());
            } catch (any e1) {
                return createObject("component", "api.v1.MemberAccessGateService").init(resolveDatasource());
            }
        </cfscript>
    </cffunction>

    <cffunction name="resolveSessionUserId" access="private" returntype="numeric" output="false">
        <cfscript>
            var uid = 0;
            if (structKeyExists(session, "user") AND isStruct(session.user)) {
                if (structKeyExists(session.user, "userId") AND isNumeric(session.user.userId)) {
                    uid = val(session.user.userId);
                } else if (structKeyExists(session.user, "id") AND isNumeric(session.user.id)) {
                    uid = val(session.user.id);
                } else if (structKeyExists(session.user, "USERID") AND isNumeric(session.user.USERID)) {
                    uid = val(session.user.USERID);
                }
            }
            return uid;
        </cfscript>
    </cffunction>

    <cffunction name="resolveSessionUserValue" access="private" returntype="string" output="false">
        <cfargument name="keys" type="array" required="true">
        <cfargument name="defaultValue" type="string" required="false" default="">
        <cfscript>
            var userData = {};
            var i = 0;
            var keyName = "";
            var textVal = "";

            if (!structKeyExists(session, "user") OR !isStruct(session.user)) {
                return arguments.defaultValue;
            }

            userData = session.user;
            for (i = 1; i LTE arrayLen(arguments.keys); i++) {
                keyName = toString(arguments.keys[i]);
                if (!len(keyName) OR !structKeyExists(userData, keyName) OR isNull(userData[keyName])) {
                    continue;
                }
                textVal = trim(toString(userData[keyName]));
                if (len(textVal)) {
                    return textVal;
                }
            }

            return arguments.defaultValue;
        </cfscript>
    </cffunction>

    <cffunction name="resolveOwnerInteractionProfile" access="private" returntype="struct" output="false">
        <cfargument name="currentUserId" type="numeric" required="false" default="0">
        <cfscript>
            var out = {
                "display_name"="Captain",
                "email"="",
                "internal_email"=""
            };
            var firstName = resolveSessionUserValue(["firstName", "firstname", "FIRSTNAME", "first_name"], "");
            var lastName = resolveSessionUserValue(["lastName", "lastname", "LASTNAME", "last_name"], "");
            var fullName = resolveSessionUserValue(["name", "fullName", "displayName", "NAME"], "");
            var emailVal = lCase(trim(resolveSessionUserValue(["email", "EMAIL"], "")));

            if (len(fullName)) {
                out.display_name = fullName;
            } else if (len(firstName) OR len(lastName)) {
                out.display_name = trim(firstName & " " & lastName);
            } else if (len(emailVal)) {
                out.display_name = emailVal;
            }

            out.email = emailVal;
            if (arguments.currentUserId GT 0) {
                out.internal_email = "owner+" & int(arguments.currentUserId) & "@fpw-owner.local";
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="isDevEnv" access="private" returntype="boolean" output="false">
        <cfscript>
            var envVal = "";
            var hostVal = "";
            if (structKeyExists(application, "env")) {
                envVal = lCase(trim(toString(application.env)));
            }
            if (listFindNoCase("dev,local,test", envVal)) {
                return true;
            }
            hostVal = lCase(trim(toString(cgi.server_name)));
            if (find("localhost", hostVal) OR find("127.0.0.1", hostVal)) {
                return true;
            }
            return false;
        </cfscript>
    </cffunction>

    <cffunction name="getBodyJson" access="private" returntype="struct" output="false">
        <cfscript>
            var req = getHttpRequestData();
            var raw = "";
            var body = {};
            if (structKeyExists(req, "content") AND !isNull(req.content)) {
                raw = toString(req.content);
            }
            if (!len(trim(raw))) {
                return body;
            }
            try {
                body = deserializeJSON(raw);
                if (!isStruct(body)) {
                    body = {};
                }
            } catch (any e) {
                body = {};
            }
            return body;
        </cfscript>
    </cffunction>

    <cffunction name="pickArg" access="private" returntype="any" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfargument name="primaryKey" type="string" required="true">
        <cfargument name="secondaryKey" type="string" required="false" default="">
        <cfargument name="defaultValue" type="any" required="false">
        <cfscript>
            if (structKeyExists(arguments.body, arguments.primaryKey)) {
                return arguments.body[arguments.primaryKey];
            }
            if (len(arguments.secondaryKey) AND structKeyExists(arguments.body, arguments.secondaryKey)) {
                return arguments.body[arguments.secondaryKey];
            }
            if (structKeyExists(url, arguments.primaryKey)) {
                return url[arguments.primaryKey];
            }
            if (len(arguments.secondaryKey) AND structKeyExists(url, arguments.secondaryKey)) {
                return url[arguments.secondaryKey];
            }
            if (structKeyExists(form, arguments.primaryKey)) {
                return form[arguments.primaryKey];
            }
            if (len(arguments.secondaryKey) AND structKeyExists(form, arguments.secondaryKey)) {
                return form[arguments.secondaryKey];
            }
            return arguments.defaultValue;
        </cfscript>
    </cffunction>

</cfcomponent>
