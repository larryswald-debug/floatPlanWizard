<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">
<cfparam name="url.action" default="setup">

<cfscript>
expectedConfirmation = "RUN_PUBLIC_FOLLOW_PRIVACY_BROWSER_FIXTURE";
serverName = structKeyExists(cgi, "server_name") ? lCase(trim(toString(cgi.server_name))) : "";
httpHost = structKeyExists(cgi, "http_host") ? lCase(trim(toString(cgi.http_host))) : "";
serverPort = structKeyExists(cgi, "server_port") ? val(cgi.server_port) : 0;
isLocal = listFindNoCase("localhost,127.0.0.1,::1", serverName) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$", httpHost) GT 0
  AND serverPort EQ 8500;
datasource = "fpw";
fixtureTokenPrefix = "0a6005";

function cleanupBrowserFixtures() {
  var params = {
    tokenPrefix = { value = fixtureTokenPrefix & "%", cfsqltype = "cf_sql_varchar" }
  };
  queryExecute("DELETE FROM voyage_comments WHERE post_id IN (SELECT id FROM voyage_posts WHERE stream_id IN (SELECT id FROM voyage_streams WHERE share_token LIKE :tokenPrefix))", params, { datasource = datasource });
  queryExecute("DELETE FROM voyage_reactions WHERE post_id IN (SELECT id FROM voyage_posts WHERE stream_id IN (SELECT id FROM voyage_streams WHERE share_token LIKE :tokenPrefix))", params, { datasource = datasource });
  queryExecute("DELETE FROM voyage_posts WHERE stream_id IN (SELECT id FROM voyage_streams WHERE share_token LIKE :tokenPrefix)", params, { datasource = datasource });
  queryExecute("DELETE FROM voyage_followers WHERE stream_id IN (SELECT id FROM voyage_streams WHERE share_token LIKE :tokenPrefix)", params, { datasource = datasource });
  queryExecute("DELETE FROM voyage_streams WHERE share_token LIKE :tokenPrefix", params, { datasource = datasource });
}

function makeOpaqueSlug() {
  var slug = "";
  var qSlug = queryNew("");
  do {
    slug = "trip-" & lCase(replace(createUUID(), "-", "", "all"));
    qSlug = queryExecute(
      "SELECT id FROM voyage_streams WHERE slug = :slug LIMIT 1",
      { slug = { value = slug, cfsqltype = "cf_sql_varchar" } },
      { datasource = datasource }
    );
  } while (qSlug.recordCount GT 0);
  return slug;
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
    { datasource = datasource }
  );
}

function buildFollowPath(required string slug, required string shareToken, string page = "follow.cfm") {
  return "/app/" & arguments.page
    & "?slug=" & urlEncodedFormat(arguments.slug)
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
  <cfset cleanupBrowserFixtures()>

  <cfif actionVal EQ "cleanup">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({ SUCCESS = true, CLEANED = true })#</cfoutput>
    <cfabort>
  </cfif>

  <cfset qSources = queryExecute(
    "SELECT
       vs.id,
       vs.floatplan_id,
       vs.owner_user_id,
       vs.slug,
       vs.share_token
     FROM voyage_streams vs
     INNER JOIN floatplans fp ON fp.floatplanId = vs.floatplan_id
     WHERE UPPER(TRIM(fp.status)) = 'ACTIVE'
       AND fp.route_instance_id IS NOT NULL
       AND fp.route_instance_id > 0
       AND vs.owner_user_id >= 100
       AND vs.share_token NOT LIKE :fixtureTokenPrefix
       AND EXISTS (
         SELECT 1
         FROM premium_send_receipts psr
         WHERE psr.float_plan_id = vs.floatplan_id
           AND psr.access_ended_at_utc IS NULL
           AND (psr.access_expires_at_utc IS NULL OR psr.access_expires_at_utc > UTC_TIMESTAMP(6))
       )
     ORDER BY vs.id",
    {
      fixtureTokenPrefix = { value = fixtureTokenPrefix & "%", cfsqltype = "cf_sql_varchar" }
    },
    { datasource = datasource }
  )>

  <cfif qSources.recordCount LT 2>
    <cfheader statuscode="409">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({ SUCCESS = false, ERROR = "TWO_ACTIVE_SOURCE_STREAMS_REQUIRED" })#</cfoutput>
    <cfabort>
  </cfif>

  <cfset sourceA = {
    id = val(qSources.id[1]),
    floatPlanId = val(qSources.floatplan_id[1]),
    ownerUserId = val(qSources.owner_user_id[1]),
    slug = toString(qSources.slug[1]),
    shareToken = toString(qSources.share_token[1])
  }>
  <cfset sourceB = {}>
  <cfloop from="2" to="#qSources.recordCount#" index="sourceIndex">
    <cfif val(qSources.owner_user_id[sourceIndex]) NEQ sourceA.ownerUserId>
      <cfset sourceB = {
        id = val(qSources.id[sourceIndex]),
        floatPlanId = val(qSources.floatplan_id[sourceIndex]),
        ownerUserId = val(qSources.owner_user_id[sourceIndex]),
        slug = toString(qSources.slug[sourceIndex]),
        shareToken = toString(qSources.share_token[sourceIndex])
      }>
      <cfbreak>
    </cfif>
  </cfloop>

  <cfif NOT structCount(sourceB)>
    <cfheader statuscode="409">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({ SUCCESS = false, ERROR = "TWO_DISTINCT_ACTIVE_OWNERS_REQUIRED" })#</cfoutput>
    <cfabort>
  </cfif>

  <cfset slugA = makeOpaqueSlug()>
  <cfset slugB = makeOpaqueSlug()>
  <cfset tokenA = makeFixtureToken()>
  <cfset tokenB = makeFixtureToken()>
  <cfset insertFixtureStream(sourceA, slugA, tokenA)>
  <cfset insertFixtureStream(sourceB, slugB, tokenB)>

  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({
    SUCCESS = true,
    NEW_A = {
      SLUG = slugA,
      TOKEN = tokenA,
      OWNER_USER_ID_FOR_ASSERTION = sourceA.ownerUserId,
      URL = buildFollowPath(slugA, tokenA),
      FULL_MAP_URL = buildFollowPath(slugA, tokenA, "follow-full-map.cfm")
    },
    NEW_B = {
      SLUG = slugB,
      TOKEN = tokenB,
      OWNER_USER_ID_FOR_ASSERTION = sourceB.ownerUserId,
      URL = buildFollowPath(slugB, tokenB)
    },
    LEGACY_A = {
      SLUG = sourceA.slug,
      TOKEN = sourceA.shareToken,
      URL = buildFollowPath(sourceA.slug, sourceA.shareToken)
    }
  })#</cfoutput>
  <cfcatch type="any">
    <cfset cleanupBrowserFixtures()>
    <cfheader statuscode="500">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({ SUCCESS = false, ERROR = "BROWSER_FIXTURE_EXCEPTION", MESSAGE = cfcatch.message, TYPE = cfcatch.type })#</cfoutput>
  </cfcatch>
</cftry>
