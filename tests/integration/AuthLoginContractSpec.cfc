component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.api = new fpw.tests.support.FpwApiSupport().init(inheritCookie = false);
    variables.createdUserIds = [];
    variables.passwordResetEmailPattern = "fpw-auth-pwreset-%@example.test";
    variables.passwordResetGenericMessage = "If an account exists for that email, we sent a password reset link.";
  }

  function beforeEach() {
    cleanupPasswordResetRows();
  }

  function afterEach() {
    cleanupCreatedUsers();
    cleanupPasswordResetRows();
  }

  function run() {
    describe( "Approved login contract", function() {
      it( "logs in with a disposable signed-up user and returns the current user payload", function() {
        var password = "TestPass123!";
        var email = "fpw-login-" & replace(createUUID(), "-", "", "all") & "@example.com";
        var signup = variables.api.postJson( "/api/v1/join.cfc?method=handle", {
          firstName = "FPW",
          lastName = "Login",
          email = email,
          password = password,
          confirmPassword = password,
          termsAccepted = true
        }, false );
        var payload = {};

        expect( signup.SUCCESS ).toBeTrue( serializeJSON( signup ) );
        expect( val( signup.USERID ?: 0 ) ).toBeGT( 0, serializeJSON( signup ) );
        arrayAppend( variables.createdUserIds, val( signup.USERID ) );

        payload = variables.api.postJson( "/api/v1/auth.cfc?method=handle", {
          action = "login",
          email = email,
          password = password
        }, false );

        expect( payload.SUCCESS ).toBeTrue( serializeJSON( payload ) );
        expect( payload.MESSAGE ).toBe( "Login successful" );
        expect( isStruct( payload.USER ) ).toBeTrue( serializeJSON( payload ) );
        expect( val( payload.USER.userId ?: payload.USER.USERID ?: 0 ) ).toBe( val( signup.USERID ) );
        expect( lCase( toString( payload.USER.email ?: payload.USER.EMAIL ?: "" ) ) ).toBe( lCase( email ) );
      } );

      it( "returns a generic forgot-password response and stores only a hashed reset token", function() {
        var email = uniquePasswordResetEmail();
        var userId = createPasswordResetUser( email, "OldPass123!" );
        var payload = variables.api.postJson( "/api/v1/password_reset.cfc?method=handle", {
          action = "request",
          email = email
        }, false );
        var qUser = loadPasswordResetUser( userId );

        expect( payload.SUCCESS ).toBeTrue( serializeJSON( payload ) );
        expect( payload.MESSAGE ).toBe( variables.passwordResetGenericMessage );
        expect( structKeyExists( payload, "TOKEN" ) ).toBeFalse( serializeJSON( payload ) );
        expect( structKeyExists( payload, "RESET_URL" ) ).toBeFalse( serializeJSON( payload ) );
        expect( structKeyExists( payload, "USERID" ) ).toBeFalse( serializeJSON( payload ) );
        expect( structKeyExists( payload, "DETAIL" ) ).toBeFalse( serializeJSON( payload ) );
        expect( structKeyExists( payload, "DBDETAIL" ) ).toBeFalse( serializeJSON( payload ) );
        expect( structKeyExists( payload, "BUILD" ) ).toBeFalse( serializeJSON( payload ) );
        expect( len( trim( toString( qUser.resetTokenHash[1] ) ) ) ).toBe( 64 );
        expect( isDate( qUser.resetRequestedAt[1] ) ).toBeTrue();
        expect( isDate( qUser.resetExpiresAt[1] ) ).toBeTrue();
        expect( len( trim( toString( qUser.resetId[1] ) ) ) ).toBe( 0 );
        expect( len( trim( toString( qUser.requestReset[1] ) ) ) ).toBe( 0 );
      } );

      it( "returns the same generic forgot-password response for a nonexistent email", function() {
        var payload = variables.api.postJson( "/api/v1/password_reset.cfc?method=handle", {
          action = "request",
          email = uniquePasswordResetEmail()
        }, false );

        expect( payload.SUCCESS ).toBeTrue( serializeJSON( payload ) );
        expect( payload.MESSAGE ).toBe( variables.passwordResetGenericMessage );
        expect( structKeyExists( payload, "TOKEN" ) ).toBeFalse( serializeJSON( payload ) );
        expect( structKeyExists( payload, "RESET_URL" ) ).toBeFalse( serializeJSON( payload ) );
        expect( countPasswordResetHashes() ).toBe( 0 );
      } );

      it( "updates the password with a valid reset token and rejects token reuse", function() {
        var email = uniquePasswordResetEmail();
        var oldPassword = "OldPass123!";
        var newPassword = "NewPass456!";
        var userId = createPasswordResetUser( email, oldPassword );
        var token = "test-reset-" & lcase( replace( createUUID(), "-", "", "all" ) );
        var payload = {};
        var loginOld = {};
        var loginNew = {};
        var reuse = {};
        var qUser = {};

        setPasswordResetToken( userId, token, dateAdd( "n", 60, now() ) );

        payload = variables.api.postJson( "/api/v1/password_reset.cfc?method=handle", {
          action = "confirm",
          token = token,
          newPassword = newPassword
        }, false );

        expect( payload.SUCCESS ).toBeTrue( serializeJSON( payload ) );
        expect( payload.MESSAGE ).toBe( "Your password has been reset. You can now sign in." );

        loginOld = variables.api.postJson( "/api/v1/auth.cfc?method=handle", {
          action = "login",
          email = email,
          password = oldPassword
        }, false );
        expect( loginOld.SUCCESS ).toBeFalse( serializeJSON( loginOld ) );

        loginNew = variables.api.postJson( "/api/v1/auth.cfc?method=handle", {
          action = "login",
          email = email,
          password = newPassword
        }, false );
        expect( loginNew.SUCCESS ).toBeTrue( serializeJSON( loginNew ) );

        reuse = variables.api.postJson( "/api/v1/password_reset.cfc?method=handle", {
          action = "confirm",
          token = token,
          newPassword = "AnotherPass789!"
        }, false );
        expect( reuse.SUCCESS ).toBeFalse( serializeJSON( reuse ) );
        expect( reuse.ERROR ).toBe( "INVALID_OR_EXPIRED_LINK" );

        qUser = loadPasswordResetUser( userId );
        expect( len( trim( toString( qUser.resetTokenHash[1] ) ) ) ).toBe( 0 );
      } );

      it( "rejects expired and invalid reset tokens", function() {
        var email = uniquePasswordResetEmail();
        var userId = createPasswordResetUser( email, "OldPass123!" );
        var token = "test-reset-" & lcase( replace( createUUID(), "-", "", "all" ) );
        var expired = {};
        var invalid = {};

        setPasswordResetToken( userId, token, dateAdd( "n", -1, now() ) );

        expired = variables.api.postJson( "/api/v1/password_reset.cfc?method=handle", {
          action = "confirm",
          token = token,
          newPassword = "NewPass456!"
        }, false );
        expect( expired.SUCCESS ).toBeFalse( serializeJSON( expired ) );
        expect( expired.ERROR ).toBe( "INVALID_OR_EXPIRED_LINK" );

        invalid = variables.api.postJson( "/api/v1/password_reset.cfc?method=handle", {
          action = "confirm",
          token = "not-a-real-reset-token",
          newPassword = "NewPass456!"
        }, false );
        expect( invalid.SUCCESS ).toBeFalse( serializeJSON( invalid ) );
        expect( invalid.ERROR ).toBe( "INVALID_OR_EXPIRED_LINK" );
      } );
    } );
  }

  private string function uniquePasswordResetEmail() {
    return "fpw-auth-pwreset-" & lcase( replace( createUUID(), "-", "", "all" ) ) & "@example.test";
  }

  private numeric function createPasswordResetUser( required string email, required string password ) {
    var passwordHash = ucase( hash( arguments.password, "SHA-256", "UTF-8" ) );
    var qUser = "";

    queryExecute(
      "INSERT INTO users (fName, lName, email, password, passwordCreated, created, lastUpdate)
       VALUES (:fName, :lName, :email, :password, :passwordCreated, :created, :lastUpdate)",
      {
        fName = { value = "FPW", cfsqltype = "cf_sql_varchar" },
        lName = { value = "Reset", cfsqltype = "cf_sql_varchar" },
        email = { value = arguments.email, cfsqltype = "cf_sql_varchar" },
        password = { value = passwordHash, cfsqltype = "cf_sql_varchar" },
        passwordCreated = { value = now(), cfsqltype = "cf_sql_timestamp" },
        created = { value = now(), cfsqltype = "cf_sql_timestamp" },
        lastUpdate = { value = now(), cfsqltype = "cf_sql_timestamp" }
      },
      { datasource = "fpw" }
    );

    qUser = queryExecute(
      "SELECT userId FROM users WHERE email = :email LIMIT 1",
      {
        email = { value = arguments.email, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );

    arrayAppend( variables.createdUserIds, val( qUser.userId[1] ) );
    return val( qUser.userId[1] );
  }

  private void function setPasswordResetToken( required numeric userId, required string token, required date expiresAt ) {
    queryExecute(
      "UPDATE users
       SET resetTokenHash = :resetTokenHash,
           resetRequestedAt = :resetRequestedAt,
           resetExpiresAt = :resetExpiresAt,
           requestReset = NULL,
           resetId = NULL,
           lastUpdate = :lastUpdate
       WHERE userId = :userId",
      {
        resetTokenHash = { value = ucase( hash( trim( arguments.token ), "SHA-256", "UTF-8" ) ), cfsqltype = "cf_sql_char" },
        resetRequestedAt = { value = now(), cfsqltype = "cf_sql_timestamp" },
        resetExpiresAt = { value = arguments.expiresAt, cfsqltype = "cf_sql_timestamp" },
        lastUpdate = { value = now(), cfsqltype = "cf_sql_timestamp" },
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private query function loadPasswordResetUser( required numeric userId ) {
    return queryExecute(
      "SELECT userId, email, password, requestReset, resetId, resetTokenHash, resetRequestedAt, resetExpiresAt
       FROM users
       WHERE userId = :userId",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private numeric function countPasswordResetHashes() {
    var qCount = queryExecute(
      "SELECT COUNT(*) AS row_count
       FROM users
       WHERE email LIKE :emailPattern
         AND resetTokenHash IS NOT NULL",
      {
        emailPattern = { value = variables.passwordResetEmailPattern, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );

    return val( qCount.row_count[1] );
  }

  private void function cleanupPasswordResetRows() {
    var qUsers = queryExecute(
      "SELECT userId
       FROM users
       WHERE email LIKE :emailPattern",
      {
        emailPattern = { value = variables.passwordResetEmailPattern, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    var userIdValues = [];
    var userIds = "";
    var i = 0;

    if ( qUsers.recordCount EQ 0 ) {
      return;
    }

    for ( i = 1; i <= qUsers.recordCount; i++ ) {
      arrayAppend( userIdValues, qUsers.userId[i] );
    }
    userIds = arrayToList( userIdValues );

    queryExecute(
      "DELETE FROM users_address WHERE userId IN (:userIds)",
      {
        userIds = { value = userIds, cfsqltype = "cf_sql_integer", list = true }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM users WHERE userId IN (:userIds)",
      {
        userIds = { value = userIds, cfsqltype = "cf_sql_integer", list = true }
      },
      { datasource = "fpw" }
    );
  }

  private void function cleanupCreatedUsers() {
    if ( !arrayLen( variables.createdUserIds ) ) {
      return;
    }

    queryExecute(
      "DELETE FROM member_entitlements WHERE user_id IN (:userIds)",
      { userIds = { value = arrayToList( variables.createdUserIds ), cfsqltype = "cf_sql_integer", list = true } },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM users_address WHERE userId IN (:userIds)",
      { userIds = { value = arrayToList( variables.createdUserIds ), cfsqltype = "cf_sql_integer", list = true } },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM users WHERE userId IN (:userIds)",
      { userIds = { value = arrayToList( variables.createdUserIds ), cfsqltype = "cf_sql_integer", list = true } },
      { datasource = "fpw" }
    );
    variables.createdUserIds = [];
  }
}
