component extends="testbox.system.BaseSpec" output="false" {

  function run() {
    describe( "Non-essential email opt-out service", function() {
      it( "builds and validates a signed non-essential opt-out token", function() {
        var service = createObject( "component", "fpw.api.v1.EmailOptOutService" ).init();
        var email = "email-optout-spec-" & lCase( replace( createUUID(), "-", "", "all" ) ) & "@example.com";
        var token = service.buildSignedOptOutToken(
          email = email,
          userId = 0,
          optOutType = "non_essential"
        );
        var validation = service.validateSignedOptOutToken( token );

        expect( listLen( token, "." ) ).toBe( 2 );
        expect( findNoCase( email, token ) ).toBe( 0 );
        expect( validation.success ).toBeTrue( serializeJSON( validation ) );
        expect( validation.email ).toBe( email );
        expect( validation.optOutType ).toBe( "non_essential" );
      } );

      it( "rejects a tampered token safely", function() {
        var service = createObject( "component", "fpw.api.v1.EmailOptOutService" ).init();
        var email = "email-optout-spec-" & lCase( replace( createUUID(), "-", "", "all" ) ) & "@example.com";
        var token = service.buildSignedOptOutToken( email = email );
        var tampered = left( token, len( token ) - 1 ) & ( right( token, 1 ) EQ "a" ? "b" : "a" );
        var validation = service.validateSignedOptOutToken( tampered );

        expect( validation.success ).toBeFalse( serializeJSON( validation ) );
        expect( validation.errorCode ).toBe( "OPTOUT_TOKEN_INVALID" );
        expect( structKeyExists( validation, "email" ) ).toBeFalse( serializeJSON( validation ) );
      } );

      it( "records the same valid opt-out idempotently in email_optout", function() {
        var service = createObject( "component", "fpw.api.v1.EmailOptOutService" ).init();
        var email = "email-optout-spec-" & lCase( replace( createUUID(), "-", "", "all" ) ) & "@example.com";
        var token = service.buildSignedOptOutToken( email = email );
        var firstResult = service.processOptOutToken( token = token, source = "testbox_email_optout_spec" );
        var secondResult = service.processOptOutToken( token = token, source = "testbox_email_optout_spec" );
        var rowCheck = queryExecute(
          "SELECT COUNT(*) AS row_count FROM email_optout WHERE email_hash = :emailHash AND opt_out_type = :optOutType",
          {
            emailHash = { value = lCase( hash( lCase( trim( email ) ), "SHA-256", "UTF-8" ) ), cfsqltype = "cf_sql_char" },
            optOutType = { value = "non_essential", cfsqltype = "cf_sql_varchar" }
          },
          { datasource = "fpw" }
        );

        expect( firstResult.success ).toBeTrue( serializeJSON( firstResult ) );
        expect( secondResult.success ).toBeTrue( serializeJSON( secondResult ) );
        expect( rowCheck.row_count[ 1 ] ).toBe( 1 );
        expect( service.isOptedOut( email = email, optOutType = "non_essential" ) ).toBeTrue();
      } );

      it( "keeps the public unsubscribe page copy generic and service-email accurate", function() {
        var pageSource = fileRead( expandPath( "/fpw/unsubscribe.cfm" ), "utf-8" );

        expect( findNoCase( "You have been opted out of non-essential FloatPlanWizard.com emails.", pageSource ) ).toBeGT( 0 );
        expect( findNoCase( "Some FloatPlanWizard.com emails are required to operate your account or complete actions you request.", pageSource ) ).toBeGT( 0 );
        expect( findNoCase( "To stop all account-related and service-related emails, you must close your FloatPlanWizard.com account.", pageSource ) ).toBeGT( 0 );
        expect( findNoCase( "We could not process this opt-out link. The link may be invalid or expired. Please contact support@floatplanwizard.com for help.", pageSource ) ).toBeGT( 0 );
        expect( findNoCase( "unsubscribe from all", pageSource ) ).toBe( 0 );
        expect( findNoCase( "cancel the site", pageSource ) ).toBe( 0 );
      } );
    } );
  }

}
