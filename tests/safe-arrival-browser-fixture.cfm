<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">
<cfparam name="url.action" default="setup">
<cfinclude template="../includes/fpw_base_path.cfm">

<cfscript>
expectedConfirmation = "RUN_SAFE_ARRIVAL_BROWSER_FIXTURE";
fixturePrefix = "codex-safe-arrival-browser-";
datasource = "fpw";
serverName = structKeyExists(cgi, "server_name") ? lCase(trim(toString(cgi.server_name))) : "";
httpHost = structKeyExists(cgi, "http_host") ? lCase(trim(toString(cgi.http_host))) : "";
serverPort = structKeyExists(cgi, "server_port") ? val(cgi.server_port) : 0;
isLocal = listFindNoCase("localhost,127.0.0.1,::1", serverName) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$", httpHost) GT 0
  AND serverPort EQ 8500;

function cleanupBrowserFixtures() {
  var params = {
    emailPrefix = { value = fixturePrefix & "%", cfsqltype = "cf_sql_varchar" },
    planPrefix = { value = fixturePrefix & "%", cfsqltype = "cf_sql_varchar" }
  };
  queryExecute(
    "DELETE FROM floatplan_alert_history
     WHERE floatPlanId IN (
       SELECT floatPlanId FROM floatplans WHERE floatPlanName LIKE :planPrefix
     )",
    params,
    { datasource = datasource }
  );
  queryExecute(
    "DELETE FROM voyage_streams
     WHERE floatplan_id IN (
       SELECT floatPlanId FROM floatplans WHERE floatPlanName LIKE :planPrefix
     )",
    params,
    { datasource = datasource }
  );
  queryExecute(
    "DELETE FROM floatplan_contacts
     WHERE floatPlanId IN (
       SELECT floatPlanId FROM floatplans WHERE floatPlanName LIKE :planPrefix
     )",
    params,
    { datasource = datasource }
  );
  queryExecute(
    "DELETE FROM floatplans WHERE floatPlanName LIKE :planPrefix",
    params,
    { datasource = datasource }
  );
  queryExecute(
    "DELETE FROM route_instances
     WHERE CAST(user_id AS UNSIGNED) IN (
       SELECT userId FROM users WHERE email LIKE :emailPrefix
     )",
    params,
    { datasource = datasource }
  );
  queryExecute(
    "DELETE FROM loop_routes WHERE description LIKE :planPrefix",
    params,
    { datasource = datasource }
  );
  queryExecute(
    "DELETE FROM vessels
     WHERE CAST(userId AS UNSIGNED) IN (
       SELECT userId FROM users WHERE email LIKE :emailPrefix
     )",
    params,
    { datasource = datasource }
  );
  queryExecute(
    "DELETE FROM users WHERE email LIKE :emailPrefix",
    params,
    { datasource = datasource }
  );

  if (
    structKeyExists(session, "user")
    AND isStruct(session.user)
    AND structKeyExists(session.user, "email")
    AND findNoCase(fixturePrefix, toString(session.user.email)) EQ 1
  ) {
    structDelete(session, "user");
  }
}
</cfscript>

<cfif trim(toString(url.confirm)) NEQ expectedConfirmation OR NOT isLocal>
  <cfheader statuscode="404">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({ SUCCESS = false, ERROR = "LOCAL_TEST_CONFIRMATION_REQUIRED" })#</cfoutput>
  <cfabort>
</cfif>

<cftry>
  <cfset actionValue = lCase(trim(toString(url.action)))>
  <cfset cleanupBrowserFixtures()>

  <cfif actionValue EQ "cleanup">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({ SUCCESS = true, CLEANED = true })#</cfoutput>
    <cfabort>
  </cfif>

  <cfset token = lCase(replace(createUUID(), "-", "", "all"))>
  <cfset marker = left(fixturePrefix & token, 180)>
  <cfset ownerEmail = left(marker & "@example.test", 255)>
  <cfset routeCode = left("SAB_" & token, 40)>
  <cfset completedAt = dateAdd("n", -8, now())>

  <cfquery datasource="fpw">
    INSERT INTO users (fName, lName, email, password, passwordCreated, created)
    VALUES (
      'Browser',
      'Captain',
      <cfqueryparam value="#ownerEmail#" cfsqltype="cf_sql_varchar">,
      <cfqueryparam value="#hash(marker, 'SHA-256')#" cfsqltype="cf_sql_varchar">,
      UTC_TIMESTAMP(),
      UTC_TIMESTAMP()
    )
  </cfquery>
  <cfquery name="qUser" datasource="fpw">
    SELECT userId, fName, lName, email
    FROM users
    WHERE email = <cfqueryparam value="#ownerEmail#" cfsqltype="cf_sql_varchar">
    ORDER BY userId DESC
    LIMIT 1
  </cfquery>

  <cfquery datasource="fpw">
    INSERT INTO vessels (userId, vesselName, hailingPort, isDefaultVessel, timezone)
    VALUES (
      <cfqueryparam value="#toString(val(qUser.userId[1]))#" cfsqltype="cf_sql_varchar">,
      <cfqueryparam value="#left(marker & '-vessel', 255)#" cfsqltype="cf_sql_varchar">,
      'Test Harbor',
      1,
      'America/New_York'
    )
  </cfquery>
  <cfquery name="qVessel" datasource="fpw">
    SELECT vesselID
    FROM vessels
    WHERE userId = <cfqueryparam value="#toString(val(qUser.userId[1]))#" cfsqltype="cf_sql_varchar">
    ORDER BY vesselID DESC
    LIMIT 1
  </cfquery>

  <cfquery datasource="fpw">
    INSERT INTO loop_routes (
      code, name, short_code, description,
      is_active, version, is_default, total_nm, total_locks
    ) VALUES (
      <cfqueryparam value="#routeCode#" cfsqltype="cf_sql_varchar">,
      <cfqueryparam value="#left(marker & '-route', 160)#" cfsqltype="cf_sql_varchar">,
      <cfqueryparam value="#routeCode#" cfsqltype="cf_sql_varchar">,
      <cfqueryparam value="#marker#" cfsqltype="cf_sql_varchar">,
      1, 1, 0, 12.50, 0
    )
  </cfquery>
  <cfquery name="qLoopRoute" datasource="fpw">
    SELECT id
    FROM loop_routes
    WHERE short_code = <cfqueryparam value="#routeCode#" cfsqltype="cf_sql_varchar">
    LIMIT 1
  </cfquery>

  <cfquery datasource="fpw">
    INSERT INTO route_instances (
      user_id, template_route_code, generated_route_id, generated_route_code,
      direction, trip_type, start_location, end_location,
      status, started_at, completed_at
    ) VALUES (
      <cfqueryparam value="#toString(val(qUser.userId[1]))#" cfsqltype="cf_sql_varchar">,
      <cfqueryparam value="#routeCode#" cfsqltype="cf_sql_varchar">,
      <cfqueryparam value="#val(qLoopRoute.id[1])#" cfsqltype="cf_sql_integer">,
      <cfqueryparam value="#routeCode#" cfsqltype="cf_sql_varchar">,
      'CCW', 'POINT_TO_POINT', 'Test Marina', 'Test Anchorage',
      'COMPLETED',
      <cfqueryparam value="#dateAdd('h', -3, completedAt)#" cfsqltype="cf_sql_timestamp">,
      <cfqueryparam value="#completedAt#" cfsqltype="cf_sql_timestamp">
    )
  </cfquery>
  <cfquery name="qRoute" datasource="fpw">
    SELECT id
    FROM route_instances
    WHERE generated_route_code = <cfqueryparam value="#routeCode#" cfsqltype="cf_sql_varchar">
    LIMIT 1
  </cfquery>

  <cfquery datasource="fpw">
    INSERT INTO floatplans (
      userId, floatPlanName, vesselId, dateCreated, lastUpdate,
      departing, returning, departureTimeUTC, departureTZ,
      returnTimeUTC, returnTZ, status, lastUpdateStatus,
      activatedAt, checkedInAt, closedAt, route_instance_id,
      route_origin, is_reusable, is_visible_in_route_library
    ) VALUES (
      <cfqueryparam value="#toString(val(qUser.userId[1]))#" cfsqltype="cf_sql_varchar">,
      <cfqueryparam value="#left(marker & '-trip', 255)#" cfsqltype="cf_sql_varchar">,
      <cfqueryparam value="#val(qVessel.vesselID[1])#" cfsqltype="cf_sql_integer">,
      UTC_TIMESTAMP(),
      UTC_TIMESTAMP(),
      'Test Marina',
      'Test Anchorage',
      <cfqueryparam value="#dateAdd('h', -4, completedAt)#" cfsqltype="cf_sql_timestamp">,
      'America/New_York',
      <cfqueryparam value="#completedAt#" cfsqltype="cf_sql_timestamp">,
      'America/New_York',
      'CLOSED',
      UTC_TIMESTAMP(),
      <cfqueryparam value="#dateAdd('h', -3, completedAt)#" cfsqltype="cf_sql_timestamp">,
      <cfqueryparam value="#completedAt#" cfsqltype="cf_sql_timestamp">,
      <cfqueryparam value="#completedAt#" cfsqltype="cf_sql_timestamp">,
      <cfqueryparam value="#val(qRoute.id[1])#" cfsqltype="cf_sql_integer">,
      'premium_saved_route',
      1,
      1
    )
  </cfquery>
  <cfquery name="qPlan" datasource="fpw">
    SELECT floatPlanId, floatPlanName
    FROM floatplans
    WHERE userId = <cfqueryparam value="#toString(val(qUser.userId[1]))#" cfsqltype="cf_sql_varchar">
      AND route_instance_id = <cfqueryparam value="#val(qRoute.id[1])#" cfsqltype="cf_sql_integer">
    ORDER BY floatPlanId DESC
    LIMIT 1
  </cfquery>

  <cfset session.user = {
    userId = val(qUser.userId[1]),
    id = val(qUser.userId[1]),
    fName = toString(qUser.fName[1]),
    lName = toString(qUser.lName[1]),
    email = toString(qUser.email[1])
  }>
  <cfset completedTripService = createObject(
    "component",
    "fpw.api.v1.CompletedTripViewModelService"
  ).init("fpw")>
  <cfset completedTripPath = completedTripService.buildCompletedTripUrl(
    val(qPlan.floatPlanId[1]),
    request.fpwBase
  )>

  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({
    SUCCESS = true,
    USER_ID = val(qUser.userId[1]),
    FLOAT_PLAN_ID = val(qPlan.floatPlanId[1]),
    TRIP_NAME = toString(qPlan.floatPlanName[1]),
    COMPLETED_TRIP_PATH = completedTripPath
  })#</cfoutput>

  <cfcatch type="any">
    <cfset cleanupBrowserFixtures()>
    <cfheader statuscode="500">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfoutput>#serializeJSON({
      SUCCESS = false,
      ERROR = "SAFE_ARRIVAL_BROWSER_FIXTURE_FAILED",
      MESSAGE = cfcatch.message,
      TYPE = cfcatch.type
    })#</cfoutput>
  </cfcatch>
</cftry>


