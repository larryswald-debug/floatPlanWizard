component extends="testbox.system.BaseSpec" output="false" {
  // No database writes or SMTP. Production entrypoints render into MockBox's transport boundary.
  public struct function capture(string environment="development", string mount="/fpw") {
    var mail = prepareMock(new fpw.api.v1.email());
    mail.$("getPublicUrlSettings", {environment=arguments.environment,developmentBaseUrl=""});
    mail.$("resolveFpwBasePath", arguments.mount);
    mail.$("getConfiguredBusinessMailingAddress", "TEST-ONLY BUSINESS ADDRESS");
    makePublic(mail,"getEmailConfig","captureConfig");
    var config = mail.captureConfig();
    var eligibility = {eligible=true,code="ELIGIBLE",unsubscribeUrl=config.publicBaseUrl & "/unsubscribe.cfm?t=TEST_ONLY_PAYLOAD." & repeatString("a",64)};
    mail.$("buildWelcomeMemberOptOutUrl",eligibility.unsubscribeUrl);
    mail.$("checkNonEssentialEmailEligibility",eligibility);
    mail.$("sendMultipartEmail");
    var messages = [];
    var labels = [];
    var toEmail="email-reliability@example.test";
    var result = mail.sendWelcomeMemberEmail(userId=1,toEmail=toEmail,firstName="Casey");
    requireSuccess(result); arrayAppend(labels,"Welcome");
    var reset = prepareMock(new fpw.api.v1.password_reset());
    makePublic(reset,"buildPasswordResetUrl","captureResetUrl");
    reset.$("resolvePublicBaseUrl", config.publicBaseUrl);
    var resetUrl=reset.captureResetUrl("TEST_ONLY_TOKEN") & "&continuationToken=TEST_ONLY_CONTINUATION";
    requireSuccess(mail.sendPasswordResetEmail(userId=1,toEmail=toEmail,resetUrl=resetUrl));
    arrayAppend(labels,"Password reset");
    var pdf=getTempDirectory() & "email-reliability-" & createUUID() & ".pdf";
    try {
      fileWrite(pdf,"%PDF-1.4 TEST-ONLY TRANSPORT STUB","utf-8");
      requireSuccess(mail.sendBasicReviewFloatPlanEmail(userId=1,toEmail=toEmail,contactName="Casey",floatPlanName="Fixture Trip",captainName="Captain",senderName="Member",pdfPath=pdf));
      arrayAppend(labels,"Basic review");
    } finally { if(fileExists(pdf)) fileDelete(pdf); }
    for(var kind in ["PRE_DEPARTURE","NOT_STARTED"]) {
      requireSuccess(mail.sendDepartureReminderEmail(userId=1,toEmail=toEmail,floatPlanId=42,floatPlanName="Fixture Trip",scheduledDepartureLabel="October 7, 2026 12:00 PM",departureTimezone="America/New_York",reminderType=kind));
      arrayAppend(labels,"Departure " & kind);
    }
    requireSuccess(mail.sendSafeArrivalCaptainEmail(userId=1,toEmail=toEmail,floatPlanId=42,tripName="Fixture Trip",completionLabel="October 7, 2026 2:00 PM",completionTimezone="America/New_York",completedTripPath=arguments.mount & "/app/completed-trip.cfm?id=42"));
    arrayAppend(labels,"Safe arrival captain");
    requireSuccess(mail.sendSafeArrivalShoreContactEmail(userId=1,toEmail=toEmail,floatPlanId=42,tripName="Fixture Trip",completionLabel="October 7, 2026 2:00 PM",completionTimezone="America/New_York",followPath=arguments.mount & "/app/follow.cfm?slug=fixture-trip&t=TEST_ONLY_TOKEN"));
    arrayAppend(labels,"Safe arrival shore");
    var tracking=new fpw.includes.InactiveMemberRecoveryTrackingService();
    for(var stage in ["A","B","C","D"]) {
      for(var contact=1;contact LTE 3;contact++) {
        var message=mail.buildInactiveMemberRecoveryEmail(stage=stage,contactNumber=contact,eligibility=eligibility,firstName="Casey");
        requireSuccess(message);
        message=tracking.decorate(message,repeatString("b",64),repeatString("c",64)).message;
        var submitted=mail.submitInactiveMemberRecoveryEmail(toEmail=toEmail,message=message);
        if(submitted.outcome NEQ "SUBMITTED") throw(message="Stub recovery submission failed.");
        arrayAppend(labels,"Recovery " & stage & contact);
      }
    }
    var personal=mail.buildRecoveryPersonalEmail(eligibility=eligibility,subject="Fixture personal follow-up",body="Continue planning when ready.");
    requireSuccess(personal);
    var personalResult=mail.submitRecoveryPersonalEmail(toEmail=toEmail,message=personal);
    if(personalResult.outcome NEQ "SUBMITTED") throw(message="Stub personal submission failed.");
    arrayAppend(labels,"Recovery personal");
    var calls=mail.$callLog().sendMultipartEmail;
    if(arrayLen(calls) NEQ 20) throw(message="Expected 20 shared transport captures.");
    var envelope=new fpw.tests.support.SharedEmailEnvelopeCapture();
    for(var i=1;i LTE arrayLen(calls);i++) {
      var record=envelope.capture(config,calls[i]);
      record.variant=labels[i];
      arrayAppend(messages,record);
    }
    var earlyCopies=[];
    for(var handlerPath in ["index.cfm","assets/admin/index.cfm"]) {
      var handler=new fpw.tests.support.EarlyAccessHandlerHarness().load(handlerPath);
      var transport=new fpw.tests.support.EarlyAccessMailTransportStub();
      var early=handler.send(recipientEmail=toEmail,mailConfig=handler.config,emailService=mail,mailTransport=transport);
      if(!early.sent) throw(message="Early access stub failed.");
      var captured=transport.getMessages()[1];
      arrayAppend(earlyCopies,{source=handlerPath,from=captured.mailAttributes.from,replyTo=(captured.mailAttributes.replyto ?: ""),subject=captured.mailAttributes.subject,htmlBody="",textBody=captured.body});
    }
    var earlyRecord=duplicate(earlyCopies[1]); earlyRecord.variant="Early access"; earlyRecord.mode="both retained helpers with stubbed SMTP";
    arrayAppend(messages,earlyRecord);
    return {messages=messages,earlyAccessCopies=earlyCopies,publicBaseUrl=config.publicBaseUrl,emailPreferencesUrl=config.emailPreferencesUrl};
  }

  private void function requireSuccess(required struct result) {
    if(!arguments.result.success) throw(message="Render capture failed: " & (arguments.result.errorCode ?: "UNKNOWN"));
  }
}
