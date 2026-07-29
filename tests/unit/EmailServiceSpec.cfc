component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.source = fileRead( expandPath( "/fpw/api/v1/email.cfc" ), "utf-8" );
    variables.optOutSource = fileRead( expandPath( "/fpw/api/v1/EmailOptOutService.cfc" ), "utf-8" );
  }

  function run() {
    describe( "Central FPW email service", function() {
      it( "compiles and returns a safe failure for an invalid welcome recipient", function() {
        var service = createObject( "component", "fpw.api.v1.email" ).init();
        var result = service.sendWelcomeMemberEmail(
          userId = 1,
          toEmail = "not-an-email",
          firstName = "Launch"
        );

        expect( result.success ).toBeFalse( serializeJSON( result ) );
        expect( result.messageType ).toBe( "WELCOME_MEMBER" );
        expect( result.errorCode ).toBe( "INVALID_RECIPIENT" );
        expect( findNoCase( "smtp", result.message ) ).toBe( 0 );
      } );

      it( "uses the approved transactional sender and reply-to in outbound mail attributes", function() {
        expect( findNoCase( 'fromEmail = "info@floatplanwizard.com"', variables.source ) ).toBeGT( 0 );
        expect( findNoCase( 'replyToEmail = "info@floatplanwizard.com"', variables.source ) ).toBeGT( 0 );
        expect( findNoCase( 'from = config.fromValue', variables.source ) ).toBeGT( 0 );
        expect( findNoCase( 'mailAttrs.replyto = config.replyToEmail', variables.source ) ).toBeGT( 0 );
        expect( findNoCase( "noeply@floatplanwizard.com", variables.source ) ).toBe( 0 );
      } );

      it( "contains the required welcome subject, bodies, CTA, and safety notice", function() {
        var requiredText = [
          "Welcome to FloatPlanWizard.com",
          "Hi ",
          "Thank you for joining FloatPlanWizard.com.",
          "FPW helps boaters plan trips, organize float plan details, and keep trusted contacts informed.",
          "Start from your dashboard",
          "phone, tablet, or desktop",
          "The site is mobile-friendly, and the companion app is not required to use the main web tools.",
          "launch/beta period",
          "Go to Your Dashboard",
          "https://www.floatplanwizard.com/app/dashboard.cfm",
          "The FloatPlanWizard.com Team",
          "Float Plan Wizard helps organize and share trip information, but it is not a rescue, emergency dispatch, or distress-response service.",
          "VHF Channel 16, DSC distress, 911, EPIRB/PLB, flares, or other accepted emergency methods."
        ];

        for ( var i = 1; i <= arrayLen( requiredText ); i++ ) {
          expect( findNoCase( requiredText[i], variables.source ) ).toBeGT( 0 );
        }
      } );

      it( "adds the updated service account footer to the welcome HTML and plain text bodies", function() {
        var optOutText = "You may opt out of non-essential emails here";
        var accountClosureText = "To stop all account-related and service-related emails, you must close your FloatPlanWizard.com account.";

        expect( countNoCaseMatches( variables.source, optOutText ) ).toBeGT( 1 );
        expect( countNoCaseMatches( variables.source, accountClosureText ) ).toBeGT( 1 );
        expect( findNoCase( "Some FloatPlanWizard.com emails are required to operate your account or complete actions you request.", variables.source ) ).toBeGT( 0 );
        expect( findNoCase( "For example, sending a float plan requires email delivery.", variables.source ) ).toBeGT( 0 );
        expect( findNoCase( "You can manage non-essential email preferences here", variables.source ) ).toBe( 0 );
        expect( findNoCase( "buildWelcomeMemberOptOutUrl", variables.source ) ).toBeGT( 0 );
        expect( findNoCase( "EmailOptOutService", variables.source ) ).toBeGT( 0 );
        expect( findNoCase( "buildOptOutUrl", variables.source ) ).toBeGT( 0 );
        expect( findNoCase( "/unsubscribe.cfm?t=", variables.optOutSource ) ).toBeGT( 0 );
        expect( findNoCase( "PW_EMAIL_OPTOUT_SECRET", variables.optOutSource ) ).toBeGT( 0 );
        expect( findNoCase( "[FloatPlanWizard.com Mailing Address]", variables.source ) ).toBeGT( 0 );
        expect( findNoCase( "unsubscribe from all", variables.source ) ).toBe( 0 );
      } );

      it( "keeps the marketing footer available but out of the welcome email", function() {
        var welcomeStart = findNoCase( "<cffunction name=""buildWelcomeMemberEmail""", variables.source );
        var layoutStart = findNoCase( "<cffunction name=""renderBaseEmailLayout""", variables.source );
        var welcomeSource = mid( variables.source, welcomeStart, layoutStart - welcomeStart );

        expect( findNoCase( "<cffunction name=""buildEmailComplianceFooter""", variables.source ) ).toBeGT( 0 );
        expect( findNoCase( "footerTypeValue EQ ""marketing""", variables.source ) ).toBeGT( 0 );
        expect( findNoCase( "You may opt out of marketing and promotional emails at any time", variables.source ) ).toBeGT( 0 );
        expect( findNoCase( "buildEmailComplianceFooter(footerType = ""service"")", welcomeSource ) ).toBeGT( 0 );
        expect( findNoCase( "buildEmailComplianceFooter(footerType = ""marketing"")", welcomeSource ) ).toBe( 0 );
        expect( findNoCase( "You may opt out of marketing and promotional emails", welcomeSource ) ).toBe( 0 );
      } );
    } );
  }

  private numeric function countNoCaseMatches( required string source, required string needle ) {
    var count = 0;
    var searchPosition = 1;
    var matchPosition = findNoCase( arguments.needle, arguments.source, searchPosition );

    while ( matchPosition GT 0 ) {
      count++;
      searchPosition = matchPosition + len( arguments.needle );
      matchPosition = findNoCase( arguments.needle, arguments.source, searchPosition );
    }

    return count;
  }

}
