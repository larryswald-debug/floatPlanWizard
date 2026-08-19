component extends="testbox.system.BaseSpec" output="false" {

  variables.datasource = "fpw";
  variables.fixtureEmailPrefix = "codex-qa6-005-follow-";

  function beforeAll() {
    cleanupFixtures();
    variables.voyage = createObject("component", "fpw.api.v1.voyage");
    makePublic(variables.voyage, "generateOpaqueFollowSlug", "generateOpaqueFollowSlugForTest");
    makePublic(variables.voyage, "readStream", "readStreamForTest");
    makePublic(variables.voyage, "canReadStream", "canReadStreamForTest");
    makePublic(variables.voyage, "ownerCreatePost", "ownerCreatePostForTest");
    variables.passwordService = createObject("component", "fpw.api.v1.PasswordHashService").init();
    variables.fixture = createFixture();
  }

  function afterAll() {
    cleanupFixtures();
  }

  function run() {
    describe("QA6-005 public Follow privacy contract", function() {

      it("omits the internal owner user id from the public bootstrap stream DTO", function() {
        var voyageSource = fileRead(expandPath("/fpw/api/v1/voyage.cfc"), "utf-8");
        var streamStart = findNoCase("out.stream = {", voyageSource);
        var streamEnd = findNoCase('out["sidebar"]', voyageSource, streamStart);
        var publicStreamSource = mid(voyageSource, streamStart, streamEnd - streamStart);
        var listPostsStart = findNoCase('<cffunction name="listPosts"', voyageSource);
        var listPostsEnd = findNoCase("</cffunction>", voyageSource, listPostsStart);
        var publicPostsSource = mid(voyageSource, listPostsStart, listPostsEnd - listPostsStart);

        expect(streamStart).toBeGT(0);
        expect(streamEnd).toBeGT(streamStart);
        expect(findNoCase('"owner_user_id"', publicStreamSource)).toBe(0);
        expect(findNoCase('"is_owner"', publicStreamSource)).toBeGT(0);
        expect(findNoCase('"author_user_id"=', publicPostsSource)).toBe(0);
      });

      it("generates opaque non-sequential slugs in every production creation path", function() {
        var voyageSource = fileRead(expandPath("/fpw/api/v1/voyage.cfc"), "utf-8");
        var floatplanSource = fileRead(expandPath("/fpw/api/v1/floatplan.cfc"), "utf-8");
        var ownerStart = findNoCase('<cffunction name="ownerEnsureStream"', voyageSource);
        var ownerEnd = findNoCase("</cffunction>", voyageSource, ownerStart);
        var helperStart = findNoCase('<cffunction name="ensureVoyageStreamForFloatPlan"', floatplanSource);
        var helperEnd = findNoCase("</cffunction>", floatplanSource, helperStart);
        var demoStart = findNoCase('<cffunction name="seedDemoStream"', voyageSource);
        var demoEnd = findNoCase("</cffunction>", voyageSource, demoStart);
        var generated = {};
        var slug = "";
        var i = 0;

        for (i = 1; i LTE 12; i++) {
          slug = variables.voyage.generateOpaqueFollowSlugForTest(variables.datasource);
          expect(reFindNoCase("^trip-[a-f0-9]{32}$", slug)).toBe(1);
          expect(structKeyExists(generated, slug)).toBeFalse();
          generated[slug] = true;
        }

        expect(findNoCase("generateOpaqueFollowSlug(ds)", mid(voyageSource, ownerStart, ownerEnd - ownerStart))).toBeGT(0);
        expect(findNoCase("normalizeSlug(routeCodeVal)", mid(voyageSource, ownerStart, ownerEnd - ownerStart))).toBe(0);
        expect(findNoCase("generateOpaqueFollowSlug(ds)", mid(voyageSource, demoStart, demoEnd - demoStart))).toBeGT(0);
        expect(findNoCase("demo-voyage-", mid(voyageSource, demoStart, demoEnd - demoStart))).toBe(0);
        expect(findNoCase("generateOpaqueFollowSlug(ds)", mid(floatplanSource, helperStart, helperEnd - helperStart))).toBeGT(0);
        expect(findNoCase("floatplan-", mid(floatplanSource, helperStart, helperEnd - helperStart))).toBe(0);
      });

      it("resolves a valid opaque slug and accepts its exact share token", function() {
        var streamRow = variables.voyage.readStreamForTest(variables.fixture.opaqueSlugA, 0);
        var access = variables.voyage.canReadStreamForTest(streamRow, variables.fixture.tokenA, false);

        expect(streamRow.id).toBe(variables.fixture.streamAId);
        expect(streamRow.slug).toBe(variables.fixture.opaqueSlugA);
        expect(access.allowed).toBeTrue();
      });

      it("rejects a valid opaque slug with the wrong token", function() {
        var streamRow = variables.voyage.readStreamForTest(variables.fixture.opaqueSlugA, 0);
        var access = variables.voyage.canReadStreamForTest(streamRow, repeatString("f", 64), false);

        expect(access.allowed).toBeFalse();
        expect(access.code).toBe("INVALID_SHARE_TOKEN");
      });

      it("rejects a cross-trip slug and token mix", function() {
        var streamRow = variables.voyage.readStreamForTest(variables.fixture.opaqueSlugB, 0);
        var access = variables.voyage.canReadStreamForTest(streamRow, variables.fixture.tokenA, false);

        expect(streamRow.id).toBe(variables.fixture.streamBId);
        expect(access.allowed).toBeFalse();
        expect(access.code).toBe("INVALID_SHARE_TOKEN");
      });

      it("continues to resolve and authorize an exact legacy slug", function() {
        var streamRow = variables.voyage.readStreamForTest(variables.fixture.legacySlug, 0);
        var access = variables.voyage.canReadStreamForTest(streamRow, variables.fixture.legacyToken, false);

        expect(streamRow.id).toBe(variables.fixture.legacyStreamId);
        expect(streamRow.slug).toBe(variables.fixture.legacySlug);
        expect(access.allowed).toBeTrue();
      });

      it("keeps owner mutations unavailable to an unauthenticated Follow viewer", function() {
        var beforeCount = loadPostCount(variables.fixture.streamAId);
        var result = variables.voyage.ownerCreatePostForTest(
          streamId = variables.fixture.streamAId,
          body = "This must not be written",
          mediaUrl = "",
          currentUserId = 0
        );
        var afterCount = loadPostCount(variables.fixture.streamAId);

        expect(result.SUCCESS).toBeFalse();
        expect(result.AUTH).toBeFalse();
        expect(result.MESSAGE).toBe("Unauthorized");
        expect(afterCount).toBe(beforeCount);
      });
    });
  }

  private struct function createFixture() {
    var marker = variables.fixtureEmailPrefix & lCase(replace(createUUID(), "-", "", "all"));
    var qUserA = queryNew("");
    var qUserB = queryNew("");
    var qPlanA = queryNew("");
    var qPlanB = queryNew("");
    var qStreamA = queryNew("");
    var qStreamB = queryNew("");
    var qLegacyStream = queryNew("");
    var opaqueSlugA = "";
    var opaqueSlugB = "";
    var tokenA = repeatString("a", 64);
    var tokenB = repeatString("b", 64);
    var legacyToken = repeatString("c", 64);
    var legacySlug = "";

    queryExecute(
      "INSERT INTO users (fName, lName, email, password, passwordCreated, created)
       VALUES ('Codex', 'QA6-005 A', :email, :password, UTC_TIMESTAMP(), UTC_TIMESTAMP())",
      {
        email = { value = marker & "-a@example.test", cfsqltype = "cf_sql_varchar" },
        password = { value = variables.passwordService.hashPassword(marker & "-a"), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    queryExecute(
      "INSERT INTO users (fName, lName, email, password, passwordCreated, created)
       VALUES ('Codex', 'QA6-005 B', :email, :password, UTC_TIMESTAMP(), UTC_TIMESTAMP())",
      {
        email = { value = marker & "-b@example.test", cfsqltype = "cf_sql_varchar" },
        password = { value = variables.passwordService.hashPassword(marker & "-b"), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );

    qUserA = queryExecute(
      "SELECT userId FROM users WHERE email = :email LIMIT 1",
      { email = { value = marker & "-a@example.test", cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );
    qUserB = queryExecute(
      "SELECT userId FROM users WHERE email = :email LIMIT 1",
      { email = { value = marker & "-b@example.test", cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );

    queryExecute(
      "INSERT INTO floatplans (userId, floatPlanName, dateCreated, lastUpdate, status, lastUpdateStatus)
       VALUES (:userId, 'QA6-005 Plan A', UTC_TIMESTAMP(), UTC_TIMESTAMP(), 'DRAFT', UTC_TIMESTAMP())",
      { userId = { value = toString(val(qUserA.userId[1])), cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );
    queryExecute(
      "INSERT INTO floatplans (userId, floatPlanName, dateCreated, lastUpdate, status, lastUpdateStatus)
       VALUES (:userId, 'QA6-005 Plan B', UTC_TIMESTAMP(), UTC_TIMESTAMP(), 'DRAFT', UTC_TIMESTAMP())",
      { userId = { value = toString(val(qUserB.userId[1])), cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );

    qPlanA = queryExecute(
      "SELECT floatPlanId FROM floatplans WHERE userId = :userId ORDER BY floatPlanId DESC LIMIT 1",
      { userId = { value = toString(val(qUserA.userId[1])), cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );
    qPlanB = queryExecute(
      "SELECT floatPlanId FROM floatplans WHERE userId = :userId ORDER BY floatPlanId DESC LIMIT 1",
      { userId = { value = toString(val(qUserB.userId[1])), cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );

    opaqueSlugA = variables.voyage.generateOpaqueFollowSlugForTest(variables.datasource);
    opaqueSlugB = variables.voyage.generateOpaqueFollowSlugForTest(variables.datasource);
    legacySlug = "user-route-" & val(qUserA.userId[1]) & "-qa6-005-legacy";

    insertStream(val(qPlanA.floatPlanId[1]), val(qUserA.userId[1]), opaqueSlugA, tokenA);
    insertStream(val(qPlanB.floatPlanId[1]), val(qUserB.userId[1]), opaqueSlugB, tokenB);
    insertStream(val(qPlanA.floatPlanId[1]), val(qUserA.userId[1]), legacySlug, legacyToken);

    qStreamA = queryExecute(
      "SELECT id FROM voyage_streams WHERE slug = :slug LIMIT 1",
      { slug = { value = opaqueSlugA, cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );
    qStreamB = queryExecute(
      "SELECT id FROM voyage_streams WHERE slug = :slug LIMIT 1",
      { slug = { value = opaqueSlugB, cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );
    qLegacyStream = queryExecute(
      "SELECT id FROM voyage_streams WHERE slug = :slug LIMIT 1",
      { slug = { value = legacySlug, cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );

    return {
      userAId = val(qUserA.userId[1]),
      userBId = val(qUserB.userId[1]),
      opaqueSlugA = opaqueSlugA,
      opaqueSlugB = opaqueSlugB,
      legacySlug = legacySlug,
      tokenA = tokenA,
      tokenB = tokenB,
      legacyToken = legacyToken,
      streamAId = val(qStreamA.id[1]),
      streamBId = val(qStreamB.id[1]),
      legacyStreamId = val(qLegacyStream.id[1])
    };
  }

  private void function insertStream(
    required numeric floatPlanId,
    required numeric ownerUserId,
    required string slug,
    required string shareToken
  ) {
    queryExecute(
      "INSERT INTO voyage_streams (
         floatplan_id, owner_user_id, slug, share_token, privacy_mode,
         allow_interactions, created_utc, updated_utc
       ) VALUES (
         :floatPlanId, :ownerUserId, :slug, :shareToken, 'invite',
         1, UTC_TIMESTAMP(), UTC_TIMESTAMP()
       )",
      {
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
        ownerUserId = { value = arguments.ownerUserId, cfsqltype = "cf_sql_integer" },
        slug = { value = arguments.slug, cfsqltype = "cf_sql_varchar" },
        shareToken = { value = arguments.shareToken, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
  }

  private numeric function loadPostCount(required numeric streamId) {
    var qCount = queryExecute(
      "SELECT COUNT(*) AS cnt FROM voyage_posts WHERE stream_id = :streamId",
      { streamId = { value = arguments.streamId, cfsqltype = "cf_sql_integer" } },
      { datasource = variables.datasource }
    );
    return val(qCount.cnt[1]);
  }

  private void function cleanupFixtures() {
    var pattern = variables.fixtureEmailPrefix & "%";
    var params = { pattern = { value = pattern, cfsqltype = "cf_sql_varchar" } };

    queryExecute("DELETE FROM voyage_comments WHERE post_id IN (SELECT id FROM voyage_posts WHERE stream_id IN (SELECT id FROM voyage_streams WHERE owner_user_id IN (SELECT userId FROM users WHERE email LIKE :pattern)))", params, { datasource = variables.datasource });
    queryExecute("DELETE FROM voyage_reactions WHERE post_id IN (SELECT id FROM voyage_posts WHERE stream_id IN (SELECT id FROM voyage_streams WHERE owner_user_id IN (SELECT userId FROM users WHERE email LIKE :pattern)))", params, { datasource = variables.datasource });
    queryExecute("DELETE FROM voyage_posts WHERE stream_id IN (SELECT id FROM voyage_streams WHERE owner_user_id IN (SELECT userId FROM users WHERE email LIKE :pattern))", params, { datasource = variables.datasource });
    queryExecute("DELETE FROM voyage_followers WHERE stream_id IN (SELECT id FROM voyage_streams WHERE owner_user_id IN (SELECT userId FROM users WHERE email LIKE :pattern))", params, { datasource = variables.datasource });
    queryExecute("DELETE FROM voyage_streams WHERE owner_user_id IN (SELECT userId FROM users WHERE email LIKE :pattern)", params, { datasource = variables.datasource });
    queryExecute("DELETE FROM floatplans WHERE userId IN (SELECT CAST(userId AS CHAR) FROM users WHERE email LIKE :pattern)", params, { datasource = variables.datasource });
    queryExecute("DELETE FROM users WHERE email LIKE :pattern", params, { datasource = variables.datasource });
  }
}
