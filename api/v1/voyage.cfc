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

        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

        <cftry>
            <cfset var body = getBodyJson()>
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
            <cfset var routeCodeVal = "">
            <cfset var routeInstanceIdRaw = "">

            <cfif act EQ "getstreambootstrap">
                <cfset slugVal = trim(toString(pickArg(body, "slug", "route_slug", arguments.slug)))>
                <cfset tokenVal = trim(toString(pickArg(body, "t", "token", arguments.t)))>
                <cfset streamIdVal = val(pickArg(body, "stream_id", "streamId", arguments.stream_id))>
                <cfset payload = getStreamBootstrap(slugVal, tokenVal, streamIdVal, currentUserId)>
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
                <cfset payload = toggleReaction(postIdVal, emojiVal, followerTokenVal)>
                <cfoutput>#serializeJSON(payload)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "addcomment">
                <cfset postIdVal = val(pickArg(body, "post_id", "postId", 0))>
                <cfset bodyTextVal = trim(toString(pickArg(body, "body", "comment", "")))>
                <cfset followerTokenVal = trim(toString(pickArg(body, "follower_token", "followerToken", "")))>
                <cfset payload = addComment(postIdVal, bodyTextVal, followerTokenVal)>
                <cfoutput>#serializeJSON(payload)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "ownercreatepost">
                <cfset streamIdVal = val(pickArg(body, "stream_id", "streamId", arguments.stream_id))>
                <cfset bodyTextVal = trim(toString(pickArg(body, "body", "text", "")))>
                <cfset mediaUrlVal = trim(toString(pickArg(body, "media_url", "mediaUrl", "")))>
                <cfset payload = ownerCreatePost(streamIdVal, bodyTextVal, mediaUrlVal, currentUserId)>
                <cfoutput>#serializeJSON(payload)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "ownerdeletecomment">
                <cfset commentIdVal = val(pickArg(body, "comment_id", "commentId", 0))>
                <cfset payload = ownerDeleteComment(commentIdVal, currentUserId)>
                <cfoutput>#serializeJSON(payload)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "ownerblockfollower">
                <cfset followerIdVal = val(pickArg(body, "follower_id", "followerId", 0))>
                <cfset payload = ownerBlockFollower(followerIdVal, currentUserId)>
                <cfoutput>#serializeJSON(payload)#</cfoutput>
                <cfreturn>

            <cfelseif act EQ "ownerensurestream">
                <cfset routeCodeVal = trim(toString(pickArg(body, "routeCode", "route_code", arguments.routeCode)))>
                <cfset routeInstanceIdRaw = trim(toString(pickArg(body, "routeInstanceId", "route_instance_id", arguments.routeInstanceId)))>
                <cfset payload = ownerEnsureStream(routeCodeVal, routeInstanceIdRaw, currentUserId)>
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

    <cffunction name="getStreamBootstrap" access="private" returntype="struct" output="false">
        <cfargument name="slug" type="string" required="false" default="">
        <cfargument name="shareToken" type="string" required="false" default="">
        <cfargument name="streamId" type="numeric" required="false" default="0">
        <cfargument name="currentUserId" type="numeric" required="false" default="0">
        <cfscript>
            var out = {
                "SUCCESS"=false,
                "AUTH"=true,
                "MESSAGE"="Unable to load voyage stream",
                "stream"={},
                "topCards"={},
                "map"={"routeGeo"={}, "pins"=[], "current"={}},
                "pinned"={},
                "timeline"={"summary"={}, "legs"=[], "meta"={}}
            };
            var streamRow = readStream(arguments.slug, arguments.streamId);
            var canRead = {};
            var ds = resolveDatasource();
            var qPlan = queryNew("");
            var qLastPost = queryNew("");
            var qWildlife = queryNew("");
            var routeMap = {};
            var topCards = {};
            var pinned = {};
            var followTimeline = {"summary"={}, "legs"=[], "meta"={}};
            var isOwner = false;
            var statusLabel = "Status Unavailable";
            var lastCheckinLabel = "n/a";
            var etaLabel = "n/a";
            var routeTotalMiles = 0;
            var routeTotalDays = 0;
            var routeTotalLocks = 0;
            var wildlifeCount = 0;
            var streamTitle = "Voyage";

            if (!structCount(streamRow)) {
                out.MESSAGE = "Stream not found";
                out.ERROR = { "MESSAGE"="No voyage stream matched the provided slug or stream id." };
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

            qPlan = queryExecute(
                "SELECT
                    floatplanId,
                    userId,
                    floatPlanName,
                    status,
                    departing,
                    returning,
                    returnTime,
                    route_instance_id,
                    route_day_number,
                    lastUpdate
                 FROM floatplans
                 WHERE floatplanId = :planId
                 LIMIT 1",
                {
                    planId = { value=streamRow.floatplan_id, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            if (qPlan.recordCount GT 0) {
                streamTitle = trim(toString(isNull(qPlan.floatPlanName[1]) ? "" : qPlan.floatPlanName[1]));
                statusLabel = friendlyStatusLabel(isNull(qPlan.status[1]) ? "" : qPlan.status[1]);
            }
            if (!len(streamTitle)) {
                streamTitle = "Voyage " & streamRow.slug;
            }

            routeMap = buildRouteMapData(
                routeInstanceId=(qPlan.recordCount GT 0 AND !isNull(qPlan.route_instance_id[1]) ? val(qPlan.route_instance_id[1]) : 0),
                ownerUserId=streamRow.owner_user_id,
                fallbackDays=(qPlan.recordCount GT 0 AND !isNull(qPlan.route_day_number[1]) ? val(qPlan.route_day_number[1]) : 0)
            );
            followTimeline = buildFollowCruiseTimeline(
                routeInstanceId=(qPlan.recordCount GT 0 AND !isNull(qPlan.route_instance_id[1]) ? val(qPlan.route_instance_id[1]) : 0),
                ownerUserId=streamRow.owner_user_id,
                opts={}
            );

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

            if (routeMap.remaining_nm GT 0) {
                etaLabel = "~" & int(ceiling(routeMap.remaining_nm / 45)) & " days";
            }

            topCards = {
                "status"=statusLabel,
                "last_checkin"=lastCheckinLabel,
                "location_label"=(len(routeMap.location_label) ? routeMap.location_label : "n/a"),
                "next_stop"=(len(routeMap.next_stop_label) ? routeMap.next_stop_label : "n/a"),
                "eta"=etaLabel,
                "conditions"="No active hazards reported"
            };

            pinned = {
                "miles"=routeTotalMiles,
                "days"=routeTotalDays,
                "locks"=routeTotalLocks,
                "wildlife"=wildlifeCount,
                "updated_label"=lastCheckinLabel
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
            out.topCards = topCards;
            out.map = {
                "routeGeo"=routeMap.route_geo,
                "pins"=routeMap.pins,
                "current"=routeMap.current
            };
            out.pinned = pinned;
            out.timeline = followTimeline;
            return out;
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

            followerRow = resolveFollowerByToken(arguments.followerToken);
            if (structCount(followerRow) AND followerRow.stream_id NEQ streamIdVal) {
                followerRow = {};
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
                        email = { value=emailVal, cfsqltype="cf_sql_varchar" },
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
        <cfargument name="followerToken" type="string" required="true">
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

            ctx = resolveInteractionContext(postIdVal, arguments.followerToken);
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
        <cfargument name="followerToken" type="string" required="true">
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

            ctx = resolveInteractionContext(postIdVal, arguments.followerToken);
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
        <cfargument name="routeCode" type="string" required="true">
        <cfargument name="routeInstanceId" type="any" required="false" default="">
        <cfargument name="currentUserId" type="numeric" required="false" default="0">
        <cfscript>
            var ds = resolveDatasource();
            var storageCheck = checkVoyageStorageReady();
            var routeCodeVal = trim(arguments.routeCode);
            var routeInstanceRaw = trim(toString(arguments.routeInstanceId));
            var routeInstanceIdVal = (len(routeInstanceRaw) ? val(routeInstanceRaw) : 0);
            var userIdText = toString(arguments.currentUserId);
            var routePrefix = "USER_ROUTE_" & int(arguments.currentUserId) & "_%";
            var qRoute = queryNew("");
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
            var fpwBasePath = resolveFpwBasePath();
            var createSuffix = "";

            if (arguments.currentUserId LTE 0) {
                return buildApiEnvelope(
                    success=false,
                    code="UNAUTHORIZED",
                    message="Owner session required.",
                    data={ "routeCode"=routeCodeVal },
                    auth=false
                );
            }

            if (!storageCheck.ready) {
                return buildApiEnvelope(
                    success=false,
                    code="STREAM_STORAGE_NOT_READY",
                    message="Voyage stream tables not installed.",
                    data={ "missing_tables"=storageCheck.missing_tables, "routeCode"=routeCodeVal },
                    auth=true
                );
            }

            if (!len(routeCodeVal)) {
                return buildApiEnvelope(
                    success=false,
                    code="ROUTE_CODE_REQUIRED",
                    message="routeCode is required.",
                    data={},
                    auth=true
                );
            }

            if (!reFind("^[A-Za-z0-9_-]+$", routeCodeVal)) {
                return buildApiEnvelope(
                    success=false,
                    code="INVALID_ROUTE_CODE",
                    message="routeCode can only include letters, numbers, underscores, and dashes.",
                    data={ "routeCode"=routeCodeVal },
                    auth=true
                );
            }

            if (len(routeInstanceRaw) AND !isNumeric(routeInstanceRaw)) {
                return buildApiEnvelope(
                    success=false,
                    code="INVALID_ROUTE_INSTANCE_ID",
                    message="routeInstanceId must be numeric when provided.",
                    data={ "routeCode"=routeCodeVal, "routeInstanceId"=routeInstanceRaw },
                    auth=true
                );
            }

            qRoute = queryExecute(
                "SELECT
                    r.id AS route_id,
                    r.name AS route_name,
                    r.short_code AS route_code
                 FROM loop_routes r
                 LEFT JOIN route_instances ri ON ri.generated_route_id = r.id
                 WHERE r.short_code = :routeCode
                   AND (
                        r.short_code LIKE :routePrefix
                        OR (ri.generated_route_code = r.short_code AND ri.user_id = :uidText)
                   )
                 ORDER BY ri.id DESC, r.id DESC
                 LIMIT 1",
                {
                    routeCode = { value=routeCodeVal, cfsqltype="cf_sql_varchar" },
                    routePrefix = { value=routePrefix, cfsqltype="cf_sql_varchar" },
                    uidText = { value=userIdText, cfsqltype="cf_sql_varchar" }
                },
                { datasource=ds }
            );

            if (qRoute.recordCount EQ 0) {
                return buildApiEnvelope(
                    success=false,
                    code="ROUTE_NOT_FOUND",
                    message="Route not found for this user.",
                    data={ "routeCode"=routeCodeVal },
                    auth=true
                );
            }
            routeNameVal = (isNull(qRoute.route_name[1]) ? "" : trim(toString(qRoute.route_name[1])));

            if (routeInstanceIdVal GT 0) {
                qInst = queryExecute(
                    "SELECT id, generated_route_id, generated_route_code
                     FROM route_instances
                     WHERE id = :routeInstanceId
                       AND user_id = :uidText
                     LIMIT 1",
                    {
                        routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" },
                        uidText = { value=userIdText, cfsqltype="cf_sql_varchar" }
                    },
                    { datasource=ds }
                );
            } else {
                qInst = queryExecute(
                    "SELECT id, generated_route_id, generated_route_code
                     FROM route_instances
                     WHERE user_id = :uidText
                       AND (
                            generated_route_code = :routeCode
                            OR generated_route_id = :routeId
                       )
                     ORDER BY id DESC
                     LIMIT 1",
                    {
                        uidText = { value=userIdText, cfsqltype="cf_sql_varchar" },
                        routeCode = { value=routeCodeVal, cfsqltype="cf_sql_varchar" },
                        routeId = { value=val(qRoute.route_id[1]), cfsqltype="cf_sql_integer" }
                    },
                    { datasource=ds }
                );
            }

            if (qInst.recordCount EQ 0) {
                return buildApiEnvelope(
                    success=false,
                    code="ROUTE_INSTANCE_NOT_FOUND",
                    message="No route instance found for this route.",
                    data={ "routeCode"=routeCodeVal },
                    auth=true
                );
            }

            routeInstanceIdVal = val(qInst.id[1]);
            if (
                val(qInst.generated_route_id[1]) GT 0
                AND val(qInst.generated_route_id[1]) NEQ val(qRoute.route_id[1])
                AND compareNoCase(trim(toString(qInst.generated_route_code[1])), routeCodeVal) NEQ 0
            ) {
                return buildApiEnvelope(
                    success=false,
                    code="ROUTE_INSTANCE_MISMATCH",
                    message="The provided routeInstanceId does not match routeCode.",
                    data={ "routeCode"=routeCodeVal, "routeInstanceId"=routeInstanceIdVal },
                    auth=true
                );
            }

            qPlan = queryExecute(
                "SELECT floatplanId, floatPlanName
                 FROM floatplans
                 WHERE userId = :uid
                   AND route_instance_id = :routeInstanceId
                 ORDER BY floatplanId DESC
                 LIMIT 1",
                {
                    uid = { value=arguments.currentUserId, cfsqltype="cf_sql_integer" },
                    routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            if (qPlan.recordCount EQ 0) {
                return buildApiEnvelope(
                    success=false,
                    code="NO_FLOATPLAN_FOR_ROUTE",
                    message="No float plan exists for this route. Build float plans first.",
                    data={ "routeCode"=routeCodeVal, "routeInstanceId"=routeInstanceIdVal },
                    auth=true
                );
            }
            floatPlanIdVal = val(qPlan.floatplanId[1]);

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
                    slugBase = "route-" & routeInstanceIdVal;
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
                    data={ "routeCode"=routeCodeVal, "routeInstanceId"=routeInstanceIdVal, "floatplan_id"=floatPlanIdVal },
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
                    "routeGeo"=(structKeyExists(routeMap, "route_geo") ? routeMap.route_geo : { "type"="LineString", "coordinates"=[] })
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

            qPlan = queryExecute(
                "SELECT floatplanId, floatPlanName
                 FROM floatplans
                 WHERE userId = :uid
                 ORDER BY floatplanId DESC
                 LIMIT 1",
                {
                    uid = { value=arguments.currentUserId, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );

            if (qPlan.recordCount EQ 0) {
                out.MESSAGE = "No float plan found";
                out.ERROR = { "MESSAGE"="Create at least one float plan before seeding a demo stream." };
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

    <cffunction name="buildRouteMapData" access="private" returntype="struct" output="false">
        <cfargument name="routeInstanceId" type="numeric" required="true">
        <cfargument name="ownerUserId" type="numeric" required="true">
        <cfargument name="fallbackDays" type="numeric" required="false" default="0">
        <cfscript>
            var out = {
                "route_geo"={ "type"="LineString", "coordinates"=[] },
                "pins"=[],
                "current"={},
                "total_nm"=0,
                "total_locks"=0,
                "total_days"=(arguments.fallbackDays GT 0 ? arguments.fallbackDays : 0),
                "remaining_nm"=0,
                "location_label"="",
                "next_stop_label"=""
            };
            var routeInstanceIdVal = val(arguments.routeInstanceId);
            var ds = resolveDatasource();
            var qLegs = queryNew("");
            var qProgress = queryNew("");
            var qCurrentLeg = queryNew("");
            var qNextLeg = queryNew("");
            var qLegCoords = queryNew("");
            var i = 0;
            var pt = {};
            var pointList = [];
            var coords = [];
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

            if (routeInstanceIdVal LTE 0) {
                return out;
            }

            qLegs = queryExecute(
                "SELECT
                    id,
                    leg_order,
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
                arrayAppend(coords, [pt.lng, pt.lat]);
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
                "type"="LineString",
                "coordinates"=coords
            };

            qProgress = queryExecute(
                "SELECT MAX(leg_order) AS max_leg
                 FROM route_instance_leg_progress
                 WHERE route_instance_id = :routeInstanceId
                   AND user_id = :userId
                   AND UPPER(TRIM(status)) = 'COMPLETED'",
                {
                    routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" },
                    userId = { value=arguments.ownerUserId, cfsqltype="cf_sql_integer" }
                },
                { datasource=ds }
            );
            completedOrder = (qProgress.recordCount GT 0 AND !isNull(qProgress.max_leg[1]) ? val(qProgress.max_leg[1]) : 0);

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
            if (!len(out.next_stop_label) AND qLegs.recordCount GT 0) {
                out.next_stop_label = (isNull(qLegs.end_name[1]) ? "" : trim(toString(qLegs.end_name[1])));
            }

            out.total_nm = roundTo2(out.total_nm);
            out.remaining_nm = max(0, roundTo2(out.total_nm - completedNm));
            return out;
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
                routeInputSpeedKn = deriveEffectiveSpeedFromInputs(storedInputs);
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

                if (effectiveSpeedKn GT 0 AND distNm GT 0) {
                    legHours = roundTo2(distNm / effectiveSpeedKn);
                } else {
                    legHours = 0;
                    if (distNm GT 0 AND effectiveSpeedKn LTE 0) {
                        out.meta.zero_speed_guard = true;
                    }
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

                arrayAppend(out.legs, {
                    "day_bucket"=dayBucket,
                    "leg_order"=orderVal,
                    "label"=startName & " -> " & endName,
                    "start_name"=startName,
                    "end_name"=endName,
                    "dist_nm"=distNm,
                    "hours"=legHours,
                    "locks"=lockCount,
                    "lock_details"=legLockDetails,
                    "cumulative_hours"=cumulativeHours,
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

            out.summary = {
                "total_nm"=totalNm,
                "total_locks"=totalLocks,
                "total_hours"=roundTo2(cumulativeHours),
                "total_days"=(maxHoursPerDay GT 0 AND cumulativeHours GT 0 ? int(ceiling(cumulativeHours / maxHoursPerDay)) : 0),
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
                    "effective_speed_kn" = [ "effectiveSpeedKn", "effective_cruising_speed", "effectiveCruisingSpeed", "weather_adjusted_speed_kn", "weatherAdjustedSpeedKn" ],
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
        <cfscript>
            var src = (isStruct(arguments.routeInputs) ? arguments.routeInputs : {});
            var directSpeed = getNumericFromKeys(
                src,
                [ "effective_speed_kn", "effectiveSpeedKn", "effective_cruising_speed", "effectiveCruisingSpeed", "weather_adjusted_speed_kn", "weatherAdjustedSpeedKn" ],
                true
            );
            var maxSpeed = 0;
            var paceFactor = 0.25;
            var weatherPct = 0;
            var out = 0;
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

            paceFactor = resolvePaceFactor(structKeyExists(src, "pace") ? src.pace : "RELAXED");
            out = roundTo2(maxSpeed * paceFactor);
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
        <cfargument name="followerToken" type="string" required="true">
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

            if (postIdVal LTE 0) {
                out.MESSAGE = "post_id required";
                out.ERROR = { "MESSAGE"="post_id is required." };
                return out;
            }
            if (!len(tokenVal)) {
                out.MESSAGE = "follower_token required";
                out.STATUS_CODE = 403;
                out.ERROR = { "CODE"="FOLLOWER_TOKEN_REQUIRED", "MESSAGE"="follower_token is required." };
                return out;
            }

            q = queryExecute(
                "SELECT
                    vp.id AS post_id,
                    vp.stream_id,
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
            return createObject("java", "java.lang.Math").atan2(arguments.y, arguments.x);
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
