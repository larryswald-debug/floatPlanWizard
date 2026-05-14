component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.emailPattern = "signup2a-%@example.test";
  }

  function beforeEach() {
    cleanupRows();
  }

  function afterEach() {
    cleanupRows();
  }

  function run() {
    describe( "Public member signup contract", function() {
      it( "returns the current required-field response", function() {
        var api = new fpw.tests.support.FpwApiSupport().init();
        var payload = api.postJson( "/api/v1/join.cfc?method=handle", {}, false );

        expect( payload.SUCCESS ).toBeFalse( serializeJSON( payload ) );
        expect( payload.MESSAGE ).toBe( "First name, last name, and email are required." );
        expect( payload.ERROR ).toBe( "MISSING_FIELDS" );
      } );

      it( "rejects missing password", function() {
        var api = new fpw.tests.support.FpwApiSupport().init();
        var requestBody = validSignupPayload();
        structDelete( requestBody, "password", false );
        structDelete( requestBody, "confirmPassword", false );

        var payload = api.postJson( "/api/v1/join.cfc?method=handle", requestBody, false );

        expect( payload.SUCCESS ).toBeFalse( serializeJSON( payload ) );
        expect( payload.ERROR ).toBe( "PASSWORD_REQUIRED" );
      } );

      it( "rejects short password", function() {
        var api = new fpw.tests.support.FpwApiSupport().init();
        var requestBody = validSignupPayload();
        requestBody.password = "short";
        requestBody.confirmPassword = "short";

        var payload = api.postJson( "/api/v1/join.cfc?method=handle", requestBody, false );

        expect( payload.SUCCESS ).toBeFalse( serializeJSON( payload ) );
        expect( payload.ERROR ).toBe( "PASSWORD_TOO_SHORT" );
      } );

      it( "rejects password mismatch", function() {
        var api = new fpw.tests.support.FpwApiSupport().init();
        var requestBody = validSignupPayload();
        requestBody.confirmPassword = "DifferentPass123!";

        var payload = api.postJson( "/api/v1/join.cfc?method=handle", requestBody, false );

        expect( payload.SUCCESS ).toBeFalse( serializeJSON( payload ) );
        expect( payload.ERROR ).toBe( "PASSWORD_MISMATCH" );
      } );

      it( "rejects missing Terms and Privacy acceptance", function() {
        var api = new fpw.tests.support.FpwApiSupport().init();
        var requestBody = validSignupPayload();
        structDelete( requestBody, "termsAccepted", false );

        var payload = api.postJson( "/api/v1/join.cfc?method=handle", requestBody, false );

        expect( payload.SUCCESS ).toBeFalse( serializeJSON( payload ) );
        expect( payload.ERROR ).toBe( "TERMS_REQUIRED" );
      } );

      it( "rejects invalid email", function() {
        var api = new fpw.tests.support.FpwApiSupport().init();
        var requestBody = validSignupPayload();
        requestBody.email = "not-an-email";

        var payload = api.postJson( "/api/v1/join.cfc?method=handle", requestBody, false );

        expect( payload.SUCCESS ).toBeFalse( serializeJSON( payload ) );
        expect( payload.ERROR ).toBe( "INVALID_EMAIL" );
      } );

      it( "returns the current duplicate-email response for the approved existing account", function() {
        var api = new fpw.tests.support.FpwApiSupport().init();
        var requestBody = validSignupPayload( "lswald@yahoo.com" );

        var payload = api.postJson( "/api/v1/join.cfc?method=handle", requestBody, false );

        expect( payload.SUCCESS ).toBeFalse( serializeJSON( payload ) );
        expect( payload.MESSAGE ).toBe( "That email is already registered." );
        expect( payload.ERROR ).toBe( "EMAIL_EXISTS" );
      } );

      it( "creates a Basic signed-in user with the submitted password and no Premium side effects", function() {
        var api = new fpw.tests.support.FpwApiSupport().init();
        var password = "LaunchPass123!";
        var requestBody = validSignupPayload( uniqueEmail(), password );
        var payload = api.postJson( "/api/v1/join.cfc?method=handle", requestBody, false );
        var userId = val( payload.USERID ?: 0 );
        var me = {};
        var loginApi = {};
        var login = {};
        var qUser = {};

        expect( payload.SUCCESS ).toBeTrue( serializeJSON( payload ) );
        expect( payload.success ).toBeTrue( serializeJSON( payload ) );
        expect( payload.AUTH ).toBeTrue( serializeJSON( payload ) );
        expect( payload.auth ).toBeTrue( serializeJSON( payload ) );
        expect( userId ).toBeGT( 0 );
        expect( payload.EMAIL ).toBe( requestBody.email );
        expect( payload.REDIRECT_URL ).toBe( "/fpw/app/start-trial.cfm?offer=launch_trial" );
        expect( payload.redirectUrl ).toBe( "/fpw/app/start-trial.cfm?offer=launch_trial" );

        qUser = loadUser( userId );
        expect( qUser.recordCount ).toBe( 1, serializeJSON( payload ) );
        expect( qUser.password[1] ).toBe( ucase( hash( password, "SHA-256", "UTF-8" ) ) );
        expect( qUser.password[1] ).notToBe( ucase( hash( "changeIt", "SHA-256", "UTF-8" ) ) );
        expect( len( trim( toString( qUser.lastLogin[1] ) ) ) ).toBeGT( 0 );

        me = api.getJson( "/api/v1/me.cfc?method=handle" );
        expect( me.SUCCESS ).toBeTrue( serializeJSON( me ) );
        expect( me.AUTH ).toBeTrue( serializeJSON( me ) );
        expect( resolveUserId( me.USER ) ).toBe( userId );
        expect( me.ACCESS.memberLevel ).toBe( "basic" );
        expect( me.ACCESS.hasPremium ).toBeFalse( serializeJSON( me.ACCESS ) );
        expect( me.ACCESS.premiumSource ).toBe( "none" );

        expect( countPremiumEntitlements( userId ) ).toBe( 0 );
        expect( countPromoRedemptions( userId ) ).toBe( 0 );

        loginApi = new fpw.tests.support.FpwApiSupport().init();
        login = loginApi.postJson( "/api/v1/auth.cfc?method=handle", {
          action = "login",
          email = requestBody.email,
          password = password
        }, false );

        expect( login.SUCCESS ).toBeTrue( serializeJSON( login ) );
        expect( login.MESSAGE ).toBe( "Login successful" );
        expect( resolveUserId( login.USER ) ).toBe( userId );
      } );
    } );
  }

  private struct function validSignupPayload( string email="", string password="LaunchPass123!" ) {
    var signupEmail = len( trim( arguments.email ) ) ? trim( arguments.email ) : uniqueEmail();
    return {
      firstName = "Launch",
      lastName = "Signup",
      email = signupEmail,
      password = arguments.password,
      confirmPassword = arguments.password,
      termsAccepted = true
    };
  }

  private string function uniqueEmail() {
    return "signup2a-" & lcase( replace( createUUID(), "-", "", "all" ) ) & "@example.test";
  }

  private query function loadUser( required numeric userId ) {
    return queryExecute(
      "SELECT userId, email, password, lastLogin
       FROM users
       WHERE userId = :userId",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private numeric function countPremiumEntitlements( required numeric userId ) {
    var qCount = queryExecute(
      "SELECT COUNT(*) AS row_count
       FROM member_entitlements
       WHERE user_id = :userId",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    return val( qCount.row_count[1] );
  }

  private numeric function countPromoRedemptions( required numeric userId ) {
    var qCount = queryExecute(
      "SELECT COUNT(*) AS row_count
       FROM fpw_promo_redemptions
       WHERE user_id = :userId",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
    return val( qCount.row_count[1] );
  }

  private numeric function resolveUserId( required struct user ) {
    if ( structKeyExists( arguments.user, "userId" ) AND isNumeric( arguments.user.userId ) ) {
      return val( arguments.user.userId );
    }
    if ( structKeyExists( arguments.user, "id" ) AND isNumeric( arguments.user.id ) ) {
      return val( arguments.user.id );
    }
    if ( structKeyExists( arguments.user, "USERID" ) AND isNumeric( arguments.user.USERID ) ) {
      return val( arguments.user.USERID );
    }
    return 0;
  }

  private void function cleanupRows() {
    var qUsers = queryExecute(
      "SELECT userId
       FROM users
       WHERE email LIKE :emailPattern",
      {
        emailPattern = { value = variables.emailPattern, cfsqltype = "cf_sql_varchar" }
      },
      { datasource = "fpw" }
    );
    var userIds = "";
    var userIdValues = [];
    var i = 0;

    if ( qUsers.recordCount EQ 0 ) {
      return;
    }

    for ( i = 1; i <= qUsers.recordCount; i++ ) {
      arrayAppend( userIdValues, qUsers.userId[i] );
    }
    userIds = arrayToList( userIdValues );

    queryExecute(
      "DELETE FROM fpw_promo_redemptions WHERE user_id IN (:userIds)",
      {
        userIds = { value = userIds, cfsqltype = "cf_sql_integer", list = true }
      },
      { datasource = "fpw" }
    );
    queryExecute(
      "DELETE FROM member_entitlements WHERE user_id IN (:userIds)",
      {
        userIds = { value = userIds, cfsqltype = "cf_sql_integer", list = true }
      },
      { datasource = "fpw" }
    );
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
}
