<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">
<cfparam name="url.action" default="setup">

<cfscript>
expectedConfirmation = "RUN_FOLLOW_TERMINAL_LOADER_BROWSER_FIXTURE";
serverName = structKeyExists(cgi, "server_name") ? lCase(trim(toString(cgi.server_name))) : "";
httpHost = structKeyExists(cgi, "http_host") ? lCase(trim(toString(cgi.http_host))) : "";
serverPort = structKeyExists(cgi, "server_port") ? val(cgi.server_port) : 0;
isLocal = listFindNoCase("localhost,127.0.0.1,::1", serverName) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$", httpHost) GT 0
  AND serverPort EQ 8500;
datasource = "fpw";
fixtureTokenPrefix = "0a6002";

function fixtureParams() {
  return {
    tokenPrefix = { value = fixtureTokenPrefix & "%", cfsqltype = "cf_sql_varchar" }
  };
}

function cleanupBrowserFixtures() {
  var params = fixtureParams();
  queryExecute("DELETE FROM voyage_comments WHERE post_id IN (SELECT id FROM voyage_posts WHERE stream_id IN (SELECT id FROM voyage_streams WHERE share_token LIKE :tokenPrefix))", params, { datasource = datasource });
  queryExecute("DELETE FROM voyage_reactions WHERE post_id IN (SELECT id FROM voyage_posts WHERE stream_id IN (SELECT id FROM voyage_streams WHERE share_token LIKE :tokenPrefix))", params, { datasource = datasource });
  queryExecute("DELETE FROM voyage_posts WHERE stream_id IN (SELECT id FROM voyage_streams WHERE share_token LIKE :tokenPrefix)", params, { datasource = datasource });
  queryExecute("DELETE FROM voyage_followers WHERE stream_id IN (SELECT id FROM voyage_streams WHERE share_token LIKE :tokenPrefix)", params, { datasource = datasource });
  queryExecute("DELETE FROM voyage_streams WHERE share_token LIKE :tokenPrefix", params, { datasource = datasource });
}

function makeOpaqueSlug(required string stateLabel) {
  return "trip-qa6-002-" & arguments.stateLabel & "-" & lCase(replace(createUUID(), "-", "", "all"));
}

function makeFixtureToken() {
  return left(
    fixtureTokenPrefix
      & lCase(replace(createUUID(), "-", "", "all"))
      & lCase(replace(createUUID(), "-", "", "all")),
    64
  );
}

function insertFixtureStream(required struct source, required string slug, required string shareToken) {
  var insertResult = {};
  queryExecute(
    "INSERT INTO voyage_streams (
       floatplan_id, owner_user_id, slug, share_token, privacy_mode,
       allow_interactions, created_utc, updated_utc
     ) VALUES (
       :floatPlanId, :ownerUserId, :slug, :shareToken, 'invite',
       1, UTC_TIMESTAMP(), UTC_TIMESTAMP()
     )",
    {
      floatPlanId = { value = arguments.source.floatPlanId, cfsqltype = "cf_sql_integer" },
      ownerUserId = { value = arguments.source.ownerUserId, cfsqltype = "cf_sql_integer" },
      slug = { value = arguments.slug, cfsqltype = "cf_sql_varchar" },
      shareToken = { value = arguments.shareToken, cfsqltype = "cf_sql_varchar" }
    },
    { datasource = datasource, result = "local.insertResult" }
  );
  return val(insertResult.generatedKey);
}

function loadFixtureSnapshot() {
  var params = fixtureParams();
  var qSnapshot = queryExecute(
    "SELECT
       (SELECT COUNT(*) FROM voyage_streams WHERE share_token LIKE :tokenPrefix) AS fixture_stream_count,
       (SELECT COUNT(*) FROM voyage_posts WHERE stream_id IN (SELECT id FROM voyage_streams WHERE share_token LIKE :tokenPrefix)) AS voyage_post_count,
       (SELECT COUNT(*) FROM voyage_followers WHERE stream_id IN (SELECT id FROM voyage_streams WHERE share_token LIKE :tokenPrefix)) AS voyage_follower_count,
       (SELECT COUNT(*) FROM floatplan_monitoring WHERE float_plan_id IN (SELECT floatplan_id FROM voyage_streams WHERE share_token LIKE :tokenPrefix)) AS monitoring_count,
       (SELECT COUNT(*) FROM floatplan_monitor_events WHERE float_plan_id IN (SELECT floatplan_id FROM voyage_streams WHERE share_token LIKE :tokenPrefix)) AS monitor_event_count,
       (SELECT COUNT(*) FROM floatplan_notifications WHERE floatplanId IN (SELECT floatplan_id FROM voyage_streams WHERE share_token LIKE :tokenPrefix)) AS notification_count,
       (SELECT COUNT(*) FROM floatplan_notification_log WHERE floatplanId IN (SELECT floatplan_id FROM voyage_streams WHERE share_token LIKE :tokenPrefix)) AS notification_log_count,
       (SELECT COUNT(*) FROM fpw_notification_log WHERE floatPlanId IN (SELECT floatplan_id FROM voyage_streams WHERE share_token LIKE :tokenPrefix)) AS fpw_notification_log_count,
       (SELECT COUNT(*) FROM premium_send_receipts WHERE float_plan_id IN (SELECT floatplan_id FROM voyage_streams WHERE share_token LIKE :tokenPrefix)) AS receipt_count,
       (SELECT COUNT(*) FROM premium_send_credits WHERE consumed_float_plan_id IN (SELECT floatplan_id FROM voyage_streams WHERE share_token LIKE :tokenPrefix)) AS consumed_credit_count,
       (SELECT COUNT(*) FROM route_instances WHERE id IN (
          SELECT fp.route_instance_id
          FROM floatplans fp
          WHERE fp.floatPlanId IN (SELECT floatplan_id FROM voyage_streams WHERE share_token LIKE :tokenPrefix)
       )) AS route_instance_count,
       (SELECT COUNT(*) FROM route_instance_leg_progress WHERE route_instance_id IN (
          SELECT fp.route_instance_id
          FROM floatplans fp
          WHERE fp.floatPlanId IN (SELECT floatplan_id FROM voyage_streams WHERE share_token LIKE :tokenPrefix)
       )) AS route_progress_count",
    params,
    { datasource = datasource }
  );
  return {
    FIXTURE_STREAM_COUNT = val(qSnapshot.fixture_stream_count[1]),
    VOYAGE_POST_COUNT = val(qSnapshot.voyage_post_count[1]),
    VOYAGE_FOLLOWER_COUNT = val(qSnapshot.voyage_follower_count[1]),
    MONITORING_COUNT = val(qSnapshot.monitoring_count[1]),
    MONITOR_EVENT_COUNT = val(qSnapshot.monitor_event_count[1]),
    NOTIFICATION_COUNT = val(qSnapshot.notification_count[1]),
    NOTIFICATION_LOG_COUNT = val(qSnapshot.notification_log_count[1]),
    FPW_NOTIFICATION_LOG_COUNT = val(qSnapshot.fpw_notification_log_count[1]),
    RECEIPT_COUNT = val(qSnapshot.receipt_count[1]),
    CONSUMED_CREDIT_COUNT = val(qSnapshot.consumed_credit_count[1]),
    ROUTE_INSTANCE_COUNT = val(qSnapshot.route_instance_count[1]),
    ROUTE_PROGRESS_COUNT = val(qSnapshot.route_progress_count[1])
  };
}

function buildFollowPath(required string slug, required string shareToken) {
  return "/app/follow.cfm?slug=" & urlEncodedFormat(arguments.slug)
    & "&t=" & urlEncodedFormat(arguments.shareToken);
}
</cfscript>

<cfif trim(toString(url.confirm)) NEQ expectedConfirmation OR NOT isLocal>
  <cfheader statuscode="404">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({ SUCCESS = false, ERROR = "LOCAL_TEST_CONFIRMATION_REQUIRED" })#</cfoutput>
  <cfabort>
</cfif>

<cftry>
  <cfset actionVal = lCase(trim(toString(url.action)))>

  <cfif actionVal EQ "cleanup">
    <cfset cleanupBrowserFixtures()>
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({ SUCCESS = true, CLEANED = true })#</cfoutput>
    <cfabort>
  </cfif>

  <cfif actionVal EQ "snapshot">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({ SUCCESS = true, SNAPSHOT = loadFixtureSnapshot() })#</cfoutput>
    <cfabort>
  </cfif>

  <cfset cleanupBrowserFixtures()>
  <cfset qActiveSource = queryExecute(
    "SELECT vs.floatplan_id, vs.owner_user_id
     FROM voyage_streams vs
     INNER JOIN floatplans fp ON fp.floatPlanId = vs.floatplan_id
     WHERE UPPER(TRIM(fp.status)) = 'ACTIVE'
       AND fp.route_instance_id IS NOT NULL
       AND fp.route_instance_id > 0
       AND vs.owner_user_id >= 100
       AND vs.share_token NOT LIKE :tokenPrefix
       AND EXISTS (
         SELECT 1 FROM premium_send_receipts psr
         WHERE psr.float_plan_id = vs.floatplan_id
           AND psr.access_ended_at_utc IS NULL
           AND (psr.access_expires_at_utc IS NULL OR psr.access_expires_at_utc > UTC_TIMESTAMP(6))
       )
     ORDER BY vs.id DESC
     LIMIT 1",
    fixtureParams(),
    { datasource = datasource }
  )>
  <cfset qEndedSource = queryExecute(
    "SELECT vs.floatplan_id, vs.owner_user_id
     FROM voyage_streams vs
     INNER JOIN floatplans fp ON fp.floatPlanId = vs.floatplan_id
     WHERE UPPER(TRIM(fp.status)) IN ('CLOSED', 'CANCELLED', 'CANCELED')
       AND fp.route_instance_id IS NOT NULL
       AND fp.route_instance_id > 0
       AND vs.owner_user_id >= 100
       AND vs.share_token NOT LIKE :tokenPrefix
       AND EXISTS (
         SELECT 1 FROM premium_send_receipts psr
         WHERE psr.float_plan_id = vs.floatplan_id
           AND psr.access_ended_at_utc IS NOT NULL
       )
     ORDER BY vs.id DESC
     LIMIT 1",
    fixtureParams(),
    { datasource = datasource }
  )>

  <cfif qActiveSource.recordCount NEQ 1 OR qEndedSource.recordCount NEQ 1>
    <cfheader statuscode="409">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({ SUCCESS = false, ERROR = "ACTIVE_AND_ENDED_CANONICAL_SOURCES_REQUIRED" })#</cfoutput>
    <cfabort>
  </cfif>

  <cfset activeSource = {
    floatPlanId = val(qActiveSource.floatplan_id[1]),
    ownerUserId = val(qActiveSource.owner_user_id[1])
  }>
  <cfset endedSource = {
    floatPlanId = val(qEndedSource.floatplan_id[1]),
    ownerUserId = val(qEndedSource.owner_user_id[1])
  }>
  <cfset activeSlug = makeOpaqueSlug("active")>
  <cfset endedSlug = makeOpaqueSlug("ended")>
  <cfset activeToken = makeFixtureToken()>
  <cfset endedToken = makeFixtureToken()>
  <cfset activeStreamId = insertFixtureStream(activeSource, activeSlug, activeToken)>
  <cfset endedStreamId = insertFixtureStream(endedSource, endedSlug, endedToken)>

  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({
    SUCCESS = true,
    ACTIVE = {
      STREAM_ID = activeStreamId,
      SLUG = activeSlug,
      TOKEN = activeToken,
      URL = buildFollowPath(activeSlug, activeToken)
    },
    ENDED = {
      STREAM_ID = endedStreamId,
      SLUG = endedSlug,
      TOKEN = endedToken,
      URL = buildFollowPath(endedSlug, endedToken)
    },
    SNAPSHOT = loadFixtureSnapshot()
  })#</cfoutput>
  <cfcatch type="any">
    <cfset cleanupBrowserFixtures()>
    <cfheader statuscode="500">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({ SUCCESS = false, ERROR = "BROWSER_FIXTURE_EXCEPTION", MESSAGE = cfcatch.message, TYPE = cfcatch.type })#</cfoutput>
  </cfcatch>
</cftry>
