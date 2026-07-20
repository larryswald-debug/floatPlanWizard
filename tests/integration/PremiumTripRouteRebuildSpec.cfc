component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.datasource = "fpw";
    variables.ctx = {
      schemaReady = premiumTripSchemaExists(),
      sessionReady = true,
      userId = 0,
      vesselId = 0,
      routeCodes = []
    };

    if (structKeyExists(CGI, "SCRIPT_NAME") && findNoCase("/testbox/", CGI.SCRIPT_NAME)) {
      variables.ctx.sessionReady = false;
      return;
    }

    try {
      variables.ctx.hadOriginalSessionUser = structKeyExists(session, "user");
      variables.ctx.originalSessionUser = variables.ctx.hadOriginalSessionUser
        ? duplicate(session.user)
        : {};
    } catch (any e) {
      variables.ctx.sessionReady = false;
      variables.ctx.sessionError = e.message;
      return;
    }

    var scheme = (structKeyExists(CGI, "https") && CGI.https == "on") ? "https" : "http";
    var portPart = "";
    if (!(scheme == "http" && CGI.server_port == 80) && !(scheme == "https" && CGI.server_port == 443)) {
      portPart = ":" & CGI.server_port;
    }
    variables.ctx.baseUrl = scheme & "://" & CGI.server_name & portPart;
    variables.ctx.actionBase = variables.ctx.baseUrl & "/fpw/api/v1/routeBuilder.cfc?method=handle&action=";

    if (variables.ctx.schemaReady) {
      variables.ctx.userId = createTestUser();
      variables.ctx.vesselId = createTestVessel(variables.ctx.userId);
      var grant = new fpw.api.v1.PremiumTripEntitlementService()
        .init(variables.datasource)
        .grantIntroductoryTrip(variables.ctx.userId);
      if (!grant.SUCCESS) {
        throw(type="PremiumTripRouteRebuildSpec.GrantFailed", message=serializeJSON(grant));
      }
      session.user = {
        userId=variables.ctx.userId,
        id=variables.ctx.userId,
        USERID=variables.ctx.userId
      };
    }
  }

  function afterAll() {
    if (!structKeyExists(variables, "ctx")) return;
    try {
      cleanupRouteBuilderFixtures();
    } finally {
      if (structKeyExists(variables.ctx, "hadOriginalSessionUser")) {
        if (variables.ctx.hadOriginalSessionUser) {
          session.user = variables.ctx.originalSessionUser;
        } else if (structKeyExists(session, "user")) {
          structDelete(session, "user");
        }
      }
    }
  }

  function run() {
    describe("Premium Trip route rebuild lifecycle", function() {
      it("replaces the prepared Draft before apply and preserves canonical floatPlanId after reservation", function() {
        requireRuntime();

        var startSession = apiPostJson(variables.ctx.actionBase & "startPremiumTripCreation", {});
        expect(pickBool(startSession, "SUCCESS")).toBeTrue(serializeJSON(startSession));
        var token = trim(toString(pickFirst(startSession, ["creationSessionToken"], "")));
        var sessionView = pickFirst(startSession, ["creationSession"], {});
        var sessionId = val(pickFirst(sessionView, ["CREATION_SESSION_ID"], 0));
        expect(len(token)).toBeGT(32);
        expect(sessionId).toBeGT(0);

        var optionsRes = apiPostJson(variables.ctx.actionBase & "routegen_getoptions", {
          direction="CCW"
        });
        expect(pickBool(optionsRes, "SUCCESS")).toBeTrue(serializeJSON(optionsRes));
        var optionsData = pickFirst(optionsRes, ["DATA"], {});
        var template = pickFirst(optionsData, ["template"], {});
        var startOptions = pickFirst(optionsData, ["startOptions"], []);
        var endOptions = pickFirst(optionsData, ["endOptions"], []);
        var templateCode = trim(toString(pickFirst(template, ["code","CODE","short_code","SHORT_CODE"], "")));
        expect(len(templateCode)).toBeGT(0, serializeJSON(optionsRes));
        expect(arrayLen(startOptions)).toBeGT(0, serializeJSON(optionsRes));
        expect(arrayLen(endOptions)).toBeGT(0, serializeJSON(optionsRes));

        var startSegmentId = val(pickFirst(startOptions[1], ["segment_id","SEGMENT_ID"], 0));
        var endIndex = arrayLen(endOptions) GTE 2 ? 2 : 1;
        var endSegmentId = val(pickFirst(endOptions[endIndex], ["segment_id","SEGMENT_ID"], 0));
        if (endSegmentId LTE 0) endSegmentId = startSegmentId;

        var generated = apiPostJson(variables.ctx.actionBase & "routegen_generate", {
          route_name="Premium Trip Rebuild Spec " & createUUID(),
          template_code=templateCode,
          start_segment_id=startSegmentId,
          end_segment_id=endSegmentId,
          start_date=dateFormat(now(), "yyyy-mm-dd"),
          direction="CCW",
          premiumTripCreationToken=token
        });
        expect(pickBool(generated, "SUCCESS")).toBeTrue(serializeJSON(generated));
        var routeId = val(pickFirst(generated, ["ROUTE_INSTANCE_ID","route_instance_id"], 0));
        var routeCode = trim(toString(pickFirst(generated, ["ROUTE_CODE","route_code"], "")));
        expect(routeId).toBeGT(0, serializeJSON(generated));
        expect(len(routeCode)).toBeGT(0, serializeJSON(generated));
        arrayAppend(variables.ctx.routeCodes, routeCode);

        var firstBuild = apiPostJson(variables.ctx.actionBase & "buildFloatPlansFromRoute", {
          routeCode=routeCode,
          mode="SINGLE_MASTER",
          vesselId=variables.ctx.vesselId,
          premiumTripCreationToken=token
        });
        expect(pickBool(firstBuild, "SUCCESS")).toBeTrue(serializeJSON(firstBuild));
        var firstPlanId = extractFirstId(firstBuild);
        expect(firstPlanId).toBeGT(0, serializeJSON(firstBuild));
        expect(toString(pickFirst(firstBuild, ["PREMIUM_TRIP_ENTITLEMENT_STATUS"], ""))).toBe("AVAILABLE");
        expect(loadEntitlementStatus()).toBe("AVAILABLE");
        expect(loadPreparedFloatPlanId(sessionId)).toBe(firstPlanId);

        var preCommitRebuild = apiPostJson(variables.ctx.actionBase & "buildFloatPlansFromRoute", {
          routeCode=routeCode,
          mode="SINGLE_MASTER",
          vesselId=variables.ctx.vesselId,
          rebuild=true,
          premiumTripCreationToken=token
        });
        expect(pickBool(preCommitRebuild, "SUCCESS")).toBeTrue(serializeJSON(preCommitRebuild));
        var preparedPlanId = extractFirstId(preCommitRebuild);
        expect(preparedPlanId).toBeGT(0, serializeJSON(preCommitRebuild));
        expect(preparedPlanId).notToBe(firstPlanId, serializeJSON(preCommitRebuild));
        expect(loadEntitlementStatus()).toBe("AVAILABLE");
        expect(loadPreparedFloatPlanId(sessionId)).toBe(preparedPlanId);

        var applied = apiPostJson(variables.ctx.actionBase & "applyPremiumTripToTrip", {
          floatPlanId=preparedPlanId,
          premiumTripCreationToken=token
        });
        expect(pickBool(applied, "SUCCESS")).toBeTrue(serializeJSON(applied));
        expect(toString(pickFirst(applied, ["status","STATUS"], ""))).toBe("RESERVED");
        expect(loadEntitlementStatus()).toBe("RESERVED");
        expect(loadCanonicalFloatPlanId()).toBe(preparedPlanId);
        expect(loadCreationSessionStatus(sessionId)).toBe("COMPLETED");

        var postCommitRebuild = apiPostJson(variables.ctx.actionBase & "buildFloatPlansFromRoute", {
          routeCode=routeCode,
          mode="SINGLE_MASTER",
          vesselId=variables.ctx.vesselId,
          rebuild=true
        });
        expect(pickBool(postCommitRebuild, "SUCCESS")).toBeTrue(serializeJSON(postCommitRebuild));
        expect(!!pickFirst(postCommitRebuild, ["REBUILT_IN_PLACE"], false)).toBeTrue(serializeJSON(postCommitRebuild));
        expect(val(pickFirst(postCommitRebuild, ["PRESERVED_CANONICAL_FLOATPLAN_ID"], 0))).toBe(preparedPlanId);
        expect(extractFirstId(postCommitRebuild)).toBe(preparedPlanId);
        expect(loadCanonicalFloatPlanId()).toBe(preparedPlanId);
        expect(floatPlanExists(preparedPlanId)).toBeTrue();
      });
    });
  }

  private void function requireRuntime() {
    if (!variables.ctx.schemaReady) {
      skip("Apply db/migrations/20260720_01_premium_trip_entitlements.sql before running this specification.");
    }
    if (!variables.ctx.sessionReady) {
      skip("Session scope is required; run through /fpw/tests/runner.cfm.");
    }
  }

  private numeric function createTestUser() {
    var result = {};
    queryExecute(
      "INSERT INTO users (email,password,passwordCreated,lastUpdate,created)
       VALUES (:email,:password,UTC_TIMESTAMP(),UTC_TIMESTAMP(),UTC_TIMESTAMP())",
      {
        email={value="premium-trip-route+" & replace(createUUID(), "-", "", "all") & "@example.invalid",cfsqltype="cf_sql_varchar"},
        password={value=hash(createUUID(), "SHA-256"),cfsqltype="cf_sql_varchar"}
      },
      { datasource=variables.datasource,result="result" }
    );
    return val(result.generatedKey);
  }

  private numeric function createTestVessel(required numeric userId) {
    var result = {};
    queryExecute(
      "INSERT INTO vessels (userId,vesselName,hailingPort,isDefaultVessel)
       VALUES (:userId,:vesselName,'Test Port',1)",
      {
        userId={value=toString(arguments.userId),cfsqltype="cf_sql_varchar"},
        vesselName={value="Premium Trip Test Vessel " & createUUID(),cfsqltype="cf_sql_varchar"}
      },
      { datasource=variables.datasource,result="result" }
    );
    return val(result.generatedKey);
  }

  private string function loadEntitlementStatus() {
    var q = loadEntitlement();
    return q.recordCount ? trim(toString(q.status[1])) : "";
  }

  private numeric function loadCanonicalFloatPlanId() {
    var q = loadEntitlement();
    return q.recordCount && !isNull(q.canonical_trip_id[1]) ? val(q.canonical_trip_id[1]) : 0;
  }

  private query function loadEntitlement() {
    return queryExecute(
      "SELECT status,canonical_trip_id
       FROM member_premium_trip_entitlements
       WHERE user_id=:userId
       ORDER BY premium_trip_entitlement_id
       LIMIT 1",
      { userId={value=variables.ctx.userId,cfsqltype="cf_sql_integer"} },
      { datasource=variables.datasource }
    );
  }

  private numeric function loadPreparedFloatPlanId(required numeric sessionId) {
    var q = queryExecute(
      "SELECT prepared_float_plan_id
       FROM premium_trip_creation_sessions
       WHERE creation_session_id=:sessionId",
      { sessionId={value=arguments.sessionId,cfsqltype="cf_sql_bigint"} },
      { datasource=variables.datasource }
    );
    return q.recordCount && !isNull(q.prepared_float_plan_id[1]) ? val(q.prepared_float_plan_id[1]) : 0;
  }

  private string function loadCreationSessionStatus(required numeric sessionId) {
    var q = queryExecute(
      "SELECT status
       FROM premium_trip_creation_sessions
       WHERE creation_session_id=:sessionId",
      { sessionId={value=arguments.sessionId,cfsqltype="cf_sql_bigint"} },
      { datasource=variables.datasource }
    );
    return q.recordCount ? trim(toString(q.status[1])) : "";
  }

  private boolean function floatPlanExists(required numeric floatPlanId) {
    var q = queryExecute(
      "SELECT floatPlanId FROM floatplans WHERE floatPlanId=:floatPlanId LIMIT 1",
      { floatPlanId={value=arguments.floatPlanId,cfsqltype="cf_sql_integer"} },
      { datasource=variables.datasource }
    );
    return q.recordCount GT 0;
  }

  private numeric function extractFirstId(required struct payload) {
    var ids = pickFirst(arguments.payload, ["FLOATPLAN_IDS","floatplan_ids"], []);
    return isArray(ids) && arrayLen(ids) ? val(ids[1]) : 0;
  }

  private array function getSessionCookies() {
    var cookiePairs = [];
    var cookieNames = ["CFID","CFTOKEN","JSESSIONID"];
    var runtimeCfid = "";
    var runtimeCftoken = "";
    try { runtimeCfid = trim(toString(CFID)); } catch (any e) {}
    try { runtimeCftoken = trim(toString(CFTOKEN)); } catch (any e) {}
    for (var name in cookieNames) {
      var value = "";
      if (structKeyExists(cookie, name)) value = trim(toString(cookie[name]));
      else if (name EQ "CFID" && len(runtimeCfid)) value = runtimeCfid;
      else if (name EQ "CFTOKEN" && len(runtimeCftoken)) value = runtimeCftoken;
      else if (name EQ "JSESSIONID" && structKeyExists(session, "sessionid")) value = trim(toString(session.sessionid));
      if (len(value)) arrayAppend(cookiePairs, {name=name,value=value});
    }
    return cookiePairs;
  }

  private struct function apiPostJson(required string url, required struct body) {
    var response = {};
    var sessionCookies = getSessionCookies();
    cfhttp(method="POST",url=arguments.url,timeout="60",result="response") {
      cfhttpparam(type="header",name="Accept",value="application/json");
      cfhttpparam(type="header",name="Content-Type",value="application/json; charset=utf-8");
      cfhttpparam(type="body",value=serializeJSON(arguments.body));
      for (var cookiePair in sessionCookies) {
        cfhttpparam(type="cookie",name=cookiePair.name,value=cookiePair.value);
      }
    }
    return decodeJsonResponse(response);
  }

  private struct function decodeJsonResponse(required struct response) {
    var raw = structKeyExists(arguments.response, "fileContent")
      ? toString(arguments.response.fileContent)
      : "";
    try {
      var parsed = deserializeJSON(raw);
      return isStruct(parsed) ? parsed : {SUCCESS=false,MESSAGE="Response JSON was not an object.",RAW=raw};
    } catch (any e) {
      return {SUCCESS=false,MESSAGE="Response was not JSON.",RAW=raw,ERROR_DETAIL=e.message};
    }
  }

  private boolean function pickBool(required struct payload, required string key) {
    return structKeyExists(arguments.payload, arguments.key) ? !!arguments.payload[arguments.key] : false;
  }

  private any function pickFirst(required struct source, required array keys, any defaultValue="") {
    for (var key in arguments.keys) {
      if (structKeyExists(arguments.source, key)) return arguments.source[key];
    }
    return arguments.defaultValue;
  }

  private boolean function premiumTripSchemaExists() {
    var q = queryExecute(
      "SELECT COUNT(*) AS table_count
       FROM information_schema.tables
       WHERE table_schema=DATABASE()
       AND table_name IN (
         'member_premium_trip_entitlements',
         'premium_trip_creation_sessions',
         'premium_trip_entitlement_events'
       )",
      {},
      { datasource=variables.datasource }
    );
    return val(q.table_count[1]) EQ 3;
  }

  private void function cleanupRouteBuilderFixtures() {
    if (!structKeyExists(variables.ctx, "userId") || variables.ctx.userId LTE 0) return;
    queryExecute(
      "INSERT INTO member_entitlements
       (user_id,entitlement_type,source,status,starts_at_utc,created_utc,updated_utc)
       VALUES (:userId,'premium','admin_comp','active',UTC_TIMESTAMP(),UTC_TIMESTAMP(),UTC_TIMESTAMP())",
      { userId={value=variables.ctx.userId,cfsqltype="cf_sql_integer"} },
      { datasource=variables.datasource }
    );
    for (var routeCode in variables.ctx.routeCodes) {
      try {
        apiPostJson(variables.ctx.actionBase & "deleteRoute", {routeCode=routeCode});
      } catch (any e) {}
    }
    transaction {
      if (variables.ctx.schemaReady) {
        queryExecute("DELETE FROM premium_trip_entitlement_events WHERE user_id=:userId",{userId={value=variables.ctx.userId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
        queryExecute("DELETE FROM premium_trip_creation_sessions WHERE user_id=:userId",{userId={value=variables.ctx.userId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
        queryExecute("DELETE FROM member_premium_trip_entitlements WHERE user_id=:userId",{userId={value=variables.ctx.userId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
      }
      queryExecute("DELETE FROM member_entitlements WHERE user_id=:userId",{userId={value=variables.ctx.userId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
      queryExecute("DELETE FROM vessels WHERE userId=:userId",{userId={value=toString(variables.ctx.userId),cfsqltype="cf_sql_varchar"}},{datasource=variables.datasource});
      queryExecute("DELETE FROM users WHERE userId=:userId",{userId={value=variables.ctx.userId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
    }
  }
}
