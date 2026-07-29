component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.datasource = "fpw";
    variables.service = new fpw.api.v1.PremiumTripEntitlementService().init(variables.datasource);
    variables.createdUserIds = [];
    variables.schemaReady = premiumTripSchemaExists();
  }

  function afterEach() {
    cleanupFixtures();
  }

  function afterAll() {
    cleanupFixtures();
  }

  function run() {
    describe("PremiumTripEntitlementService", function() {
      it("grants the introductory trip exactly once and never auto-expires AVAILABLE grants", function() {
        requirePremiumTripSchema();
        var userId = createTestUser();
        var first = variables.service.grantIntroductoryTrip(userId);
        var replay = variables.service.grantIntroductoryTrip(userId);

        expect(first.SUCCESS).toBeTrue(serializeJSON(first));
        expect(first.created).toBeTrue(serializeJSON(first));
        expect(replay.SUCCESS).toBeTrue(serializeJSON(replay));
        expect(replay.created).toBeFalse(serializeJSON(replay));

        queryExecute(
          "UPDATE member_premium_trip_entitlements
           SET granted_at_utc=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 90 DAY)
           WHERE user_id=:userId",
          { userId={value=userId,cfsqltype="cf_sql_integer"} },
          { datasource=variables.datasource }
        );

        var counts = variables.service.getTripCounts(userId);
        expect(counts.available).toBe(1, serializeJSON(counts));
        expect(arrayLen(variables.service.getAvailableTrips(userId))).toBe(1);
      });

      it("stores only a token hash and restricts a creation lease to its action allowlist", function() {
        requirePremiumTripSchema();
        var userId = createTestUser();
        variables.service.grantIntroductoryTrip(userId);
        var created = variables.service.createCreationSession(userId);
        var token = created.creationSessionToken;
        var sessionId = val(created.creationSession.CREATION_SESSION_ID);
        var stored = loadCreationSession(sessionId);
        var generalPremiumGate = new fpw.api.v1.MemberAccessGateService()
          .init(variables.datasource)
          .requirePremium(userId);
        var unboundTripGate = new fpw.api.v1.MemberAccessGateService()
          .init(variables.datasource)
          .requirePremiumForTrip(userId, 0);
        var allowed = variables.service.authorizeCreationAction(userId, token, "routegen_generate");
        var denied = variables.service.authorizeCreationAction(userId, token, "sendFloatPlanToContacts");

        expect(created.SUCCESS).toBeTrue(serializeJSON(created));
        expect(len(token)).toBeGT(32);
        expect(structKeyExists(created.creationSession, "TOKEN_HASH")).toBeFalse(serializeJSON(created));
        expect(stored.recordCount).toBe(1);
        expect(stored.token_hash[1]).notToBe(token);
        expect(stored.token_hash[1]).toBe(lCase(hash(token, "SHA-256")));
        expect(generalPremiumGate.allowed).toBeFalse(serializeJSON(generalPremiumGate));
        expect(unboundTripGate.allowed).toBeFalse(serializeJSON(unboundTripGate));
        expect(allowed.SUCCESS).toBeTrue(serializeJSON(allowed));
        expect(denied.SUCCESS).toBeFalse(serializeJSON(denied));
        expect(denied.ERROR).toBe("CREATION_ACTION_NOT_ALLOWED");
        expect(loadEntitlementForUser(userId).status[1]).toBe("AVAILABLE");
        expect(
          variables.service.finishCreationAction(
            userId,
            token,
            allowed.creationActionClaimToken
          ).SUCCESS
        ).toBeTrue();
      });

      it("holds one server-side action claim across the full authorized route request", function() {
        requirePremiumTripSchema();
        var userId = createTestUser();
        variables.service.grantIntroductoryTrip(userId);
        var created = variables.service.createCreationSession(userId);
        var token = created.creationSessionToken;
        var first = variables.service.authorizeCreationAction(userId, token, "routegen_generate");
        var concurrent = variables.service.authorizeCreationAction(userId, token, "routegen_generate");

        expect(first.SUCCESS).toBeTrue(serializeJSON(first));
        expect(concurrent.SUCCESS).toBeFalse(serializeJSON(concurrent));
        expect(errorContains(concurrent, "CONCURRENTUSE")).toBeTrue(serializeJSON(concurrent));

        var finished = variables.service.finishCreationAction(
          userId,
          token,
          first.creationActionClaimToken
        );
        var next = variables.service.authorizeCreationAction(userId, token, "routegen_generate");

        expect(finished.SUCCESS).toBeTrue(serializeJSON(finished));
        expect(next.SUCCESS).toBeTrue(serializeJSON(next));
        expect(
          variables.service.finishCreationAction(
            userId,
            token,
            next.creationActionClaimToken
          ).SUCCESS
        ).toBeTrue();
      });

      it("permits only one concurrently created active session per entitlement", function() {
        requirePremiumTripSchema();
        var userId = createTestUser();
        var grant = variables.service.grantIntroductoryTrip(userId);
        var entitlementId = val(grant.entitlementId);
        var threadA = uniqueThreadName("premiumTripCreateA");
        var threadB = uniqueThreadName("premiumTripCreateB");

        thread name=threadA action="run" userId=userId entitlementId=entitlementId datasource=variables.datasource {
          thread.result = new fpw.api.v1.PremiumTripEntitlementService()
            .init(attributes.datasource)
            .createCreationSession(attributes.userId, attributes.entitlementId);
        }
        thread name=threadB action="run" userId=userId entitlementId=entitlementId datasource=variables.datasource {
          thread.result = new fpw.api.v1.PremiumTripEntitlementService()
            .init(attributes.datasource)
            .createCreationSession(attributes.userId, attributes.entitlementId);
        }
        thread action="join" name=threadA & "," & threadB;

        var resultA = cfthread[threadA].result;
        var resultB = cfthread[threadB].result;
        var successCount = (resultA.SUCCESS ? 1 : 0) + (resultB.SUCCESS ? 1 : 0);
        var active = queryExecute(
          "SELECT COUNT(*) AS row_count
           FROM premium_trip_creation_sessions
           WHERE premium_trip_entitlement_id=:entitlementId AND status='ACTIVE'",
          { entitlementId={value=entitlementId,cfsqltype="cf_sql_bigint"} },
          { datasource=variables.datasource }
        );

        expect(successCount).toBe(1, serializeJSON({a=resultA,b=resultB}));
        expect(val(active.row_count[1])).toBe(1);
        expect(loadEntitlementForUser(userId).status[1]).toBe("AVAILABLE");
        expect(
          (!resultA.SUCCESS && errorContains(resultA, "SESSION"))
          || (!resultB.SUCCESS && errorContains(resultB, "SESSION"))
        ).toBeTrue(serializeJSON({a=resultA,b=resultB}));
      });

      it("expires stale sessions without reserving and releases the active-session lock", function() {
        requirePremiumTripSchema();
        var userId = createTestUser();
        variables.service.grantIntroductoryTrip(userId);
        var created = variables.service.createCreationSession(userId);
        var sessionId = val(created.creationSession.CREATION_SESSION_ID);

        queryExecute(
          "UPDATE premium_trip_creation_sessions
           SET expires_at_utc=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 MINUTE)
           WHERE creation_session_id=:sessionId",
          { sessionId={value=sessionId,cfsqltype="cf_sql_bigint"} },
          { datasource=variables.datasource }
        );

        var expired = variables.service.expireStaleCreationSessions(userId);
        var replacement = variables.service.createCreationSession(userId);

        expect(expired.SUCCESS).toBeTrue(serializeJSON(expired));
        expect(expired.EXPIRED_COUNT).toBe(1);
        expect(loadCreationSession(sessionId).status[1]).toBe("EXPIRED");
        expect(loadEntitlementForUser(userId).status[1]).toBe("AVAILABLE");
        expect(replacement.SUCCESS).toBeTrue(serializeJSON(replacement));
        expect(countAuditAction(userId, "CREATION_SESSION_EXPIRED")).toBe(1);
      });

      it("cancels a session without reserving and rejects token replay", function() {
        requirePremiumTripSchema();
        var userId = createTestUser();
        variables.service.grantIntroductoryTrip(userId);
        var created = variables.service.createCreationSession(userId);
        var token = created.creationSessionToken;
        var sessionId = val(created.creationSession.CREATION_SESSION_ID);
        var canceled = variables.service.cancelCreationSession(userId, token, "Test cancellation.");
        var replay = variables.service.authorizeCreationAction(userId, token, "routegen_generate");

        expect(canceled.SUCCESS).toBeTrue(serializeJSON(canceled));
        expect(loadCreationSession(sessionId).status[1]).toBe("CANCELED");
        expect(loadEntitlementForUser(userId).status[1]).toBe("AVAILABLE");
        expect(replay.SUCCESS).toBeFalse(serializeJSON(replay));
        expect(errorContains(replay, "SESSIONINACTIVE")).toBeTrue(serializeJSON(replay));
        expect(countAuditAction(userId, "CREATION_SESSION_CANCELED")).toBe(1);
      });

      it("rejects creation-session ownership and prepared-Draft ownership tampering", function() {
        requirePremiumTripSchema();
        var ownerId = createTestUser();
        var attackerId = createTestUser();
        variables.service.grantIntroductoryTrip(ownerId);
        var created = variables.service.createCreationSession(ownerId);
        var token = created.creationSessionToken;
        var attackerRouteId = createRoute(attackerId);
        var attackerPlanId = createDraftFloatPlan(attackerId, attackerRouteId);
        var sessionTamper = variables.service.authorizeCreationAction(attackerId, token, "routegen_generate");
        var ownerRouteId = createRoute(ownerId);
        var routeClaim = variables.service.authorizeCreationAction(ownerId, token, "routegen_generate");
        expect(variables.service.attachPreparedRoute(ownerId, token, ownerRouteId).SUCCESS).toBeTrue();
        expect(variables.service.finishCreationAction(ownerId, token, routeClaim.creationActionClaimToken).SUCCESS).toBeTrue();
        var buildClaim = variables.service.authorizeCreationAction(ownerId, token, "buildfloatplansfromroute", ownerRouteId);
        var draftTamper = variables.service.attachPreparedFloatPlan(ownerId, token, attackerPlanId, attackerRouteId);

        expect(sessionTamper.SUCCESS).toBeFalse(serializeJSON(sessionTamper));
        expect(errorContains(sessionTamper, "SESSIONOWNERSHIP")).toBeTrue(serializeJSON(sessionTamper));
        expect(draftTamper.SUCCESS).toBeFalse(serializeJSON(draftTamper));
        expect(errorContains(draftTamper, "DRAFTINVALID")).toBeTrue(serializeJSON(draftTamper));
        expect(variables.service.finishCreationAction(ownerId, token, buildClaim.creationActionClaimToken).SUCCESS).toBeTrue();
        expect(loadEntitlementForUser(ownerId).status[1]).toBe("AVAILABLE");
      });

      it("updates the prepared floatPlanId during pre-commit rebuild without changing AVAILABLE", function() {
        requirePremiumTripSchema();
        var userId = createTestUser();
        variables.service.grantIntroductoryTrip(userId);
        var created = variables.service.createCreationSession(userId);
        var token = created.creationSessionToken;
        var sessionId = val(created.creationSession.CREATION_SESSION_ID);
        var routeId = createRoute(userId);
        var firstPlanId = createDraftFloatPlan(userId, routeId);

        var routeClaim = variables.service.authorizeCreationAction(userId, token, "routegen_generate");
        expect(variables.service.attachPreparedRoute(userId, token, routeId).SUCCESS).toBeTrue();
        expect(variables.service.finishCreationAction(userId, token, routeClaim.creationActionClaimToken).SUCCESS).toBeTrue();
        var firstBuildClaim = variables.service.authorizeCreationAction(userId, token, "buildfloatplansfromroute", routeId);
        expect(variables.service.attachPreparedFloatPlan(userId, token, firstPlanId, routeId).SUCCESS).toBeTrue();
        expect(variables.service.finishCreationAction(userId, token, firstBuildClaim.creationActionClaimToken).SUCCESS).toBeTrue();

        queryExecute(
          "DELETE FROM floatplans WHERE floatPlanId=:floatPlanId",
          { floatPlanId={value=firstPlanId,cfsqltype="cf_sql_integer"} },
          { datasource=variables.datasource }
        );
        var secondPlanId = createDraftFloatPlan(userId, routeId);
        var rebuildClaim = variables.service.authorizeCreationAction(userId, token, "buildfloatplansfromroute", routeId);
        var rebuilt = variables.service.attachPreparedFloatPlan(userId, token, secondPlanId, routeId);
        expect(variables.service.finishCreationAction(userId, token, rebuildClaim.creationActionClaimToken).SUCCESS).toBeTrue();
        var sessionRow = loadCreationSession(sessionId);

        expect(rebuilt.SUCCESS).toBeTrue(serializeJSON(rebuilt));
        expect(rebuilt.ENTITLEMENT_STATUS).toBe("AVAILABLE");
        expect(val(sessionRow.prepared_float_plan_id[1])).toBe(secondPlanId);
        expect(loadEntitlementForUser(userId).status[1]).toBe("AVAILABLE");
        expect(countAuditAction(userId, "CREATION_SESSION_FLOATPLAN_ATTACHED")).toBe(2);
      });

      it("atomically reserves at explicit apply and makes duplicate apply an idempotent replay", function() {
        requirePremiumTripSchema();
        var fixture = createPreparedFixture();
        var applied = variables.service.applyCreationSessionToPreparedTrip(
          fixture.userId,
          fixture.token,
          fixture.floatPlanId
        );
        var replay = variables.service.applyCreationSessionToPreparedTrip(
          fixture.userId,
          fixture.token,
          fixture.floatPlanId
        );
        var differentPlanId = createDraftFloatPlan(fixture.userId, fixture.routeId);
        var mismatchReplay = variables.service.applyCreationSessionToPreparedTrip(
          fixture.userId,
          fixture.token,
          differentPlanId
        );
        var entitlement = loadEntitlementForUser(fixture.userId);
        var sessionRow = loadCreationSession(fixture.sessionId);

        expect(applied.SUCCESS).toBeTrue(serializeJSON(applied));
        expect(applied.status).toBe("RESERVED");
        expect(replay.SUCCESS).toBeTrue(serializeJSON(replay));
        expect(replay.duplicate).toBeTrue(serializeJSON(replay));
        expect(replay.replayed).toBeTrue(serializeJSON(replay));
        expect(mismatchReplay.SUCCESS).toBeFalse(serializeJSON(mismatchReplay));
        expect(errorContains(mismatchReplay, "SESSIONCOMPLETED")).toBeTrue(serializeJSON(mismatchReplay));
        expect(entitlement.status[1]).toBe("RESERVED");
        expect(val(entitlement.canonical_trip_id[1])).toBe(fixture.floatPlanId);
        expect(sessionRow.status[1]).toBe("COMPLETED");
        expect(countAuditAction(fixture.userId, "RESERVE")).toBe(1);
        expect(countAuditAction(fixture.userId, "CREATION_SESSION_COMPLETED")).toBe(1);
      });

      it("serializes concurrent apply requests into one reservation and one replay", function() {
        requirePremiumTripSchema();
        var fixture = createPreparedFixture();
        var threadA = uniqueThreadName("premiumTripApplyA");
        var threadB = uniqueThreadName("premiumTripApplyB");

        thread name=threadA action="run" fixture=fixture datasource=variables.datasource {
          thread.result = new fpw.api.v1.PremiumTripEntitlementService()
            .init(attributes.datasource)
            .applyCreationSessionToPreparedTrip(
              attributes.fixture.userId,
              attributes.fixture.token,
              attributes.fixture.floatPlanId
            );
        }
        thread name=threadB action="run" fixture=fixture datasource=variables.datasource {
          thread.result = new fpw.api.v1.PremiumTripEntitlementService()
            .init(attributes.datasource)
            .applyCreationSessionToPreparedTrip(
              attributes.fixture.userId,
              attributes.fixture.token,
              attributes.fixture.floatPlanId
            );
        }
        thread action="join" name=threadA & "," & threadB;

        var resultA = cfthread[threadA].result;
        var resultB = cfthread[threadB].result;
        var replayCount = (
          structKeyExists(resultA, "replayed") && resultA.replayed ? 1 : 0
        ) + (
          structKeyExists(resultB, "replayed") && resultB.replayed ? 1 : 0
        );
        var assignedCount = queryExecute(
          "SELECT COUNT(*) AS row_count
           FROM member_premium_trip_entitlements
           WHERE canonical_trip_id=:floatPlanId AND status='RESERVED'",
          { floatPlanId={value=fixture.floatPlanId,cfsqltype="cf_sql_integer"} },
          { datasource=variables.datasource }
        );

        expect(resultA.SUCCESS).toBeTrue(serializeJSON(resultA));
        expect(resultB.SUCCESS).toBeTrue(serializeJSON(resultB));
        expect(replayCount).toBe(1, serializeJSON({a=resultA,b=resultB}));
        expect(val(assignedCount.row_count[1])).toBe(1);
        expect(countAuditAction(fixture.userId, "RESERVE")).toBe(1);
      });

      it("rejects apply from a stale session and keeps the entitlement AVAILABLE", function() {
        requirePremiumTripSchema();
        var fixture = createPreparedFixture();
        queryExecute(
          "UPDATE premium_trip_creation_sessions
           SET expires_at_utc=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 MINUTE)
           WHERE creation_session_id=:sessionId",
          { sessionId={value=fixture.sessionId,cfsqltype="cf_sql_bigint"} },
          { datasource=variables.datasource }
        );

        var applied = variables.service.applyCreationSessionToPreparedTrip(
          fixture.userId,
          fixture.token,
          fixture.floatPlanId
        );

        expect(applied.SUCCESS).toBeFalse(serializeJSON(applied));
        expect(errorContains(applied, "SESSIONEXPIRED")).toBeTrue(serializeJSON(applied));
        expect(loadEntitlementForUser(fixture.userId).status[1]).toBe("AVAILABLE");
        expect(loadCreationSession(fixture.sessionId).status[1]).toBe("EXPIRED");
      });

      it("rolls back entitlement reservation when creation-session completion fails", function() {
        requirePremiumTripSchema();
        var fixture = createPreparedFixture();
        var caught = {};

        queryExecute(
          "UPDATE premium_trip_creation_sessions
           SET lock_version=4294967295
           WHERE creation_session_id=:sessionId",
          { sessionId={value=fixture.sessionId,cfsqltype="cf_sql_bigint"} },
          { datasource=variables.datasource }
        );

        try {
          variables.service.applyCreationSessionToPreparedTrip(
            fixture.userId,
            fixture.token,
            fixture.floatPlanId
          );
        } catch (any e) {
          caught = e;
        }

        var entitlement = loadEntitlementForUser(fixture.userId);
        var sessionRow = loadCreationSession(fixture.sessionId);
        expect(structIsEmpty(caught)).toBeFalse("Expected lock_version overflow to fail the transaction.");
        expect(entitlement.status[1]).toBe("AVAILABLE");
        expect(val(entitlement.canonical_trip_id[1])).toBe(0, serializeJSON(queryRow(entitlement)));
        expect(sessionRow.status[1]).toBe("ACTIVE");
        expect(countAuditAction(fixture.userId, "RESERVE")).toBe(0);
      });

      it("returns a pre-start RESERVED trip to AVAILABLE without consuming it", function() {
        requirePremiumTripSchema();
        var fixture = createPreparedFixture();
        expect(
          variables.service.applyCreationSessionToPreparedTrip(
            fixture.userId,
            fixture.token,
            fixture.floatPlanId
          ).SUCCESS
        ).toBeTrue();

        var released = variables.service.releaseReservedTrip(fixture.userId, fixture.floatPlanId);
        var entitlement = loadEntitlementForUser(fixture.userId);

        expect(released.SUCCESS).toBeTrue(serializeJSON(released));
        expect(entitlement.status[1]).toBe("AVAILABLE");
        expect(val(entitlement.canonical_trip_id[1])).toBe(0);
        expect(countAuditAction(fixture.userId, "RELEASE")).toBe(1);
      });

      it("transitions RESERVED to ACTIVE only after start proof and consumes on canonical closure", function() {
        requirePremiumTripSchema();
        var fixture = createPreparedFixture();
        expect(
          variables.service.applyCreationSessionToPreparedTrip(
            fixture.userId,
            fixture.token,
            fixture.floatPlanId
          ).SUCCESS
        ).toBeTrue();

        var premature = variables.service.activateTripEntitlement(fixture.userId, fixture.floatPlanId);
        expect(premature.SUCCESS).toBeFalse(serializeJSON(premature));
        expect(loadEntitlementForUser(fixture.userId).status[1]).toBe("RESERVED");

        queryExecute(
          "UPDATE route_instances SET started_at=UTC_TIMESTAMP() WHERE id=:routeId",
          { routeId={value=fixture.routeId,cfsqltype="cf_sql_integer"} },
          { datasource=variables.datasource }
        );
        var activated = variables.service.activateTripEntitlement(fixture.userId, fixture.floatPlanId);
        expect(activated.SUCCESS).toBeTrue(serializeJSON(activated));
        expect(loadEntitlementForUser(fixture.userId).status[1]).toBe("ACTIVE");

        queryExecute(
          "UPDATE floatplans SET status='CLOSED',closedAt=UTC_TIMESTAMP() WHERE floatPlanId=:floatPlanId",
          { floatPlanId={value=fixture.floatPlanId,cfsqltype="cf_sql_integer"} },
          { datasource=variables.datasource }
        );
        var closed = variables.service.handleCanonicalTripClosure(fixture.userId, fixture.floatPlanId);
        var entitlement = loadEntitlementForUser(fixture.userId);

        expect(closed.SUCCESS).toBeTrue(serializeJSON(closed));
        expect(entitlement.status[1]).toBe("CONSUMED");
        expect(val(entitlement.canonical_trip_id[1])).toBe(fixture.floatPlanId);
        expect(countAuditAction(fixture.userId, "ACTIVATE")).toBe(1);
        expect(countAuditAction(fixture.userId, "CONSUME")).toBe(1);
      });

      it("keeps account-wide Premium independent from an AVAILABLE Premium Trip", function() {
        requirePremiumTripSchema();
        var userId = createTestUser();
        variables.service.grantIntroductoryTrip(userId);
        queryExecute(
          "INSERT INTO member_entitlements
           (user_id,entitlement_type,source,status,starts_at_utc,created_utc,updated_utc)
           VALUES (:userId,'premium','stripe_subscription','active',UTC_TIMESTAMP(),UTC_TIMESTAMP(),UTC_TIMESTAMP())",
          { userId={value=userId,cfsqltype="cf_sql_integer"} },
          { datasource=variables.datasource }
        );

        var access = new fpw.api.v1.MemberPremiumAccessService()
          .init(variables.datasource)
          .getEffectiveAccess(userId, 0);
        var entitlement = loadEntitlementForUser(userId);

        expect(access.accountWidePremium).toBeTrue(serializeJSON(access));
        expect(access.tripPremium).toBeFalse(serializeJSON(access));
        expect(access.availableTripCount).toBe(1);
        expect(entitlement.status[1]).toBe("AVAILABLE");
        expect(val(entitlement.canonical_trip_id[1])).toBe(0);
      });
    });
  }

  private struct function createPreparedFixture() {
    var userId = createTestUser();
    variables.service.grantIntroductoryTrip(userId);
    var created = variables.service.createCreationSession(userId);
    var routeId = createRoute(userId);
    var floatPlanId = createDraftFloatPlan(userId, routeId);
    var routeClaim = variables.service.authorizeCreationAction(
      userId,
      created.creationSessionToken,
      "routegen_generate"
    );
    var routeAttached = variables.service.attachPreparedRoute(userId, created.creationSessionToken, routeId);
    var routeFinished = variables.service.finishCreationAction(
      userId,
      created.creationSessionToken,
      routeClaim.creationActionClaimToken
    );
    var buildClaim = variables.service.authorizeCreationAction(
      userId,
      created.creationSessionToken,
      "buildfloatplansfromroute",
      routeId
    );
    var planAttached = variables.service.attachPreparedFloatPlan(
      userId,
      created.creationSessionToken,
      floatPlanId,
      routeId
    );
    var buildFinished = variables.service.finishCreationAction(
      userId,
      created.creationSessionToken,
      buildClaim.creationActionClaimToken
    );
    if (
      !routeClaim.SUCCESS
      || !routeAttached.SUCCESS
      || !routeFinished.SUCCESS
      || !buildClaim.SUCCESS
      || !planAttached.SUCCESS
      || !buildFinished.SUCCESS
    ) {
      throw(
        type="PremiumTripEntitlementServiceSpec.FixtureFailed",
        message=serializeJSON({
          routeClaim=routeClaim,
          route=routeAttached,
          routeFinished=routeFinished,
          buildClaim=buildClaim,
          plan=planAttached,
          buildFinished=buildFinished
        })
      );
    }
    return {
      userId=userId,
      entitlementId=val(created.creationSession.PREMIUM_TRIP_ENTITLEMENT_ID),
      sessionId=val(created.creationSession.CREATION_SESSION_ID),
      token=created.creationSessionToken,
      routeId=routeId,
      floatPlanId=floatPlanId
    };
  }

  private numeric function createTestUser() {
    var email = "premium-trip-spec+" & lCase(replace(createUUID(), "-", "", "all")) & "@example.invalid";
    var result = {};
    queryExecute(
      "INSERT INTO users (email,password,passwordCreated,lastUpdate,created)
       VALUES (:email,:password,UTC_TIMESTAMP(),UTC_TIMESTAMP(),UTC_TIMESTAMP())",
      {
        email={value=email,cfsqltype="cf_sql_varchar"},
        password={value=hash(createUUID(), "SHA-256"),cfsqltype="cf_sql_varchar"}
      },
      { datasource=variables.datasource,result="result" }
    );
    var userId = val(result.generatedKey);
    arrayAppend(variables.createdUserIds, userId);
    return userId;
  }

  private numeric function createRoute(required numeric userId) {
    var result = {};
    var generatedId = 100000000 + randRange(1000, 899999999);
    queryExecute(
      "INSERT INTO route_instances
       (user_id,template_route_code,generated_route_id,generated_route_code,direction,trip_type,start_location,status)
       VALUES (:userId,'TEST',:generatedId,:generatedCode,'CCW','POINT_TO_POINT','Test Start','PLANNED')",
      {
        userId={value=toString(arguments.userId),cfsqltype="cf_sql_varchar"},
        generatedId={value=generatedId,cfsqltype="cf_sql_integer"},
        generatedCode={value="PTRIP-" & replace(createUUID(), "-", "", "all"),cfsqltype="cf_sql_varchar"}
      },
      { datasource=variables.datasource,result="result" }
    );
    return val(result.generatedKey);
  }

  private numeric function createDraftFloatPlan(required numeric userId, required numeric routeId) {
    var result = {};
    queryExecute(
      "INSERT INTO floatplans
       (userId,floatPlanName,dateCreated,lastUpdate,status,route_instance_id,route_origin,is_reusable,is_visible_in_route_library)
       VALUES (:userId,:name,UTC_TIMESTAMP(),UTC_TIMESTAMP(),'DRAFT',:routeId,'premium_saved_route',1,1)",
      {
        userId={value=toString(arguments.userId),cfsqltype="cf_sql_varchar"},
        name={value="Premium Trip Spec " & createUUID(),cfsqltype="cf_sql_varchar"},
        routeId={value=arguments.routeId,cfsqltype="cf_sql_integer"}
      },
      { datasource=variables.datasource,result="result" }
    );
    return val(result.generatedKey);
  }

  private query function loadEntitlementForUser(required numeric userId) {
    return queryExecute(
      "SELECT * FROM member_premium_trip_entitlements
       WHERE user_id=:userId
       ORDER BY premium_trip_entitlement_id
       LIMIT 1",
      { userId={value=arguments.userId,cfsqltype="cf_sql_integer"} },
      { datasource=variables.datasource }
    );
  }

  private query function loadCreationSession(required numeric sessionId) {
    return queryExecute(
      "SELECT * FROM premium_trip_creation_sessions
       WHERE creation_session_id=:sessionId
       LIMIT 1",
      { sessionId={value=arguments.sessionId,cfsqltype="cf_sql_bigint"} },
      { datasource=variables.datasource }
    );
  }

  private numeric function countAuditAction(required numeric userId, required string actionName) {
    var q = queryExecute(
      "SELECT COUNT(*) AS row_count
       FROM premium_trip_entitlement_events
       WHERE user_id=:userId AND action=:actionName",
      {
        userId={value=arguments.userId,cfsqltype="cf_sql_integer"},
        actionName={value=uCase(arguments.actionName),cfsqltype="cf_sql_varchar"}
      },
      { datasource=variables.datasource }
    );
    return val(q.row_count[1]);
  }

  private boolean function errorContains(required struct result, required string fragment) {
    var code = structKeyExists(arguments.result, "ERROR") ? toString(arguments.result.ERROR) : "";
    return findNoCase(arguments.fragment, code) GT 0;
  }

  private string function uniqueThreadName(required string prefix) {
    return arguments.prefix & replace(createUUID(), "-", "", "all");
  }

  private struct function queryRow(required query q) {
    var out = {};
    if (!arguments.q.recordCount) return out;
    for (var columnName in listToArray(arguments.q.columnList)) {
      out[columnName] = isNull(arguments.q[columnName][1]) ? "" : arguments.q[columnName][1];
    }
    return out;
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

  private void function requirePremiumTripSchema() {
    if (!variables.schemaReady) {
      skip("Apply db/migrations/20260720_01_premium_trip_entitlements.sql before running this specification.");
    }
  }

  private void function cleanupFixtures() {
    if (!structKeyExists(variables, "createdUserIds") || !arrayLen(variables.createdUserIds)) return;
    var userIds = arrayToList(variables.createdUserIds);
    var params = {
      userIds={value=userIds,cfsqltype="cf_sql_integer",list=true}
    };
    transaction {
      if (variables.schemaReady) {
        queryExecute("DELETE FROM premium_trip_entitlement_events WHERE user_id IN (:userIds)", params, {datasource=variables.datasource});
        queryExecute("DELETE FROM premium_trip_creation_sessions WHERE user_id IN (:userIds)", params, {datasource=variables.datasource});
        queryExecute("DELETE FROM member_premium_trip_entitlements WHERE user_id IN (:userIds)", params, {datasource=variables.datasource});
      }
      queryExecute("DELETE FROM member_entitlements WHERE user_id IN (:userIds)", params, {datasource=variables.datasource});
      queryExecute("DELETE FROM floatplans WHERE userId IN (:userIds)", params, {datasource=variables.datasource});
      queryExecute("DELETE FROM route_instances WHERE user_id IN (:userIds)", params, {datasource=variables.datasource});
      queryExecute("DELETE FROM users WHERE userId IN (:userIds)", params, {datasource=variables.datasource});
    }
    variables.createdUserIds = [];
  }
}
