component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.userIds = [];
    variables.service = new fpw.api.v1.AdminAuthorizationService().init("fpw");
  }

  function afterEach() {
    structDelete(session, "fpwAdminCsrfToken", false);
  }

  function afterAll() {
    cleanupUsers();
  }

  function run() {
    describe("Database-backed ADMIN authorization", function() {
      it("denies an anonymous session", function() {
        var auth = variables.service.authorizeCurrentSession({});
        expect(auth.authenticated).toBeFalse();
        expect(auth.authorized).toBeFalse();
      });

      it("denies a normal authenticated member and ignores forged session flags", function() {
        var userId = createUser("member");
        var auth = variables.service.authorizeCurrentSession({
          userId = userId,
          isAdmin = true,
          role = "admin",
          email = "admin@example.invalid"
        });
        expect(auth.authenticated).toBeTrue();
        expect(auth.authorized).toBeFalse();
      });

      it("allows only an active ADMIN entitlement and revokes access immediately", function() {
        var userId = createUser("admin");
        var entitlementId = grantAdmin(userId);
        var allowed = variables.service.authorizeCurrentSession({ userId = userId });
        expect(allowed.authorized).toBeTrue();

        queryExecute(
          "UPDATE member_entitlements
              SET status = 'revoked',
                  revoked_at_utc = UTC_TIMESTAMP(),
                  updated_utc = UTC_TIMESTAMP()
            WHERE id = :entitlementId",
          { entitlementId = { value = entitlementId, cfsqltype = "cf_sql_bigint" } },
          { datasource = "fpw" }
        );

        var revoked = variables.service.authorizeCurrentSession({ userId = userId });
        expect(revoked.authorized).toBeFalse();
      });

      it("creates and validates a server-side CSRF token", function() {
        var token = variables.service.getOrCreateCsrfToken();
        expect(len(token)).toBeGT(40);
        expect(variables.service.isValidCsrfToken(token)).toBeTrue();
        expect(variables.service.isValidCsrfToken("forged-token")).toBeFalse();
      });
    });
  }

  private numeric function createUser(required string label) {
    var email = "fpw-admin-auth-" & arguments.label & "-" & lCase(replace(createUUID(), "-", "", "all")) & "@example.test";
    var passwordHash = uCase(hash("DisposablePass123!", "SHA-256", "UTF-8"));
    queryExecute(
      "INSERT INTO users (fName, lName, email, password, passwordCreated, created, lastUpdate)
       VALUES (:fName, :lName, :email, :password, UTC_TIMESTAMP(), UTC_TIMESTAMP(), UTC_TIMESTAMP())",
      {
        fName = { value = "Admin", cfsqltype = "cf_sql_varchar" },
        lName = { value = "Authorization Test", cfsqltype = "cf_sql_varchar" },
        email = { value = email, cfsqltype = "cf_sql_varchar" },
        password = { value = passwordHash, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    var qUser = queryExecute(
      "SELECT userId FROM users WHERE email = :email LIMIT 1",
      { email = { value = email, cfsqltype = "cf_sql_varchar" } },
      { datasource = "fpw" }
    );
    arrayAppend(variables.userIds, val(qUser.userId[1]));
    return val(qUser.userId[1]);
  }

  private numeric function grantAdmin(required numeric userId) {
    queryExecute(
      "INSERT INTO member_entitlements (
         user_id, entitlement_type, source, status,
         starts_at_utc, expires_at_utc, created_utc, updated_utc
       ) VALUES (
         :userId, 'admin', 'authorization_test', 'active',
         UTC_TIMESTAMP(), NULL, UTC_TIMESTAMP(), UTC_TIMESTAMP()
       )",
      { userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" } },
      { datasource = "fpw" }
    );
    var qEntitlement = queryExecute(
      "SELECT id
         FROM member_entitlements
        WHERE user_id = :userId
          AND entitlement_type = 'admin'
          AND source = 'authorization_test'
        ORDER BY id DESC
        LIMIT 1",
      { userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" } },
      { datasource = "fpw" }
    );
    return val(qEntitlement.id[1]);
  }

  private void function cleanupUsers() {
    if (!arrayLen(variables.userIds)) return;
    var ids = arrayToList(variables.userIds);
    queryExecute(
      "DELETE FROM member_entitlements WHERE user_id IN (:ids)",
      { ids = { value = ids, cfsqltype = "cf_sql_integer", list = true } },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM users_address WHERE userId IN (:ids)",
      { ids = { value = ids, cfsqltype = "cf_sql_integer", list = true } },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM users WHERE userId IN (:ids)",
      { ids = { value = ids, cfsqltype = "cf_sql_integer", list = true } },
      { datasource = "fpw" }
    );
    variables.userIds = [];
  }
}



