component extends="testbox.system.BaseSpec" output="false" {
  public struct function runShare(required numeric userId,required string source,required string mode) output=false {
    if (!listFind("basic_save_send,basic_review_send,premium_save_send",arguments.source)
      OR !listFind("success,definite,ambiguous,partial,confirmation_failure",arguments.mode)) throw(message="INVALID_CASE");
    var p={uid={value=arguments.userId,cfsqltype="cf_sql_integer"}};
    var plan=queryExecute("SELECT floatplanId FROM floatplans WHERE userId=:uid",p,{datasource="fpw"});
    if (plan.recordCount NEQ 1) throw(message="EXACTLY_ONE_OWNED_PLAN_REQUIRED");
    var id=val(plan.floatplanId[1]);
    request.recoveryShareProbe={source=arguments.source,mode=arguments.mode,startedAtPdf=-1,startedAtTransport=-1,realSubmissionAccepted=false,files=[]};
    var response={};var errorType="";var errorMessage="";
    if (arguments.source EQ "basic_review_send") {
      var contacts=queryExecute("SELECT c.contactId FROM contacts c JOIN floatplan_contacts fc ON fc.contactId=c.contactId
        JOIN floatplans fp ON fp.floatplanId=fc.floatPlanId WHERE fp.userId=:uid AND c.userId=:uid",p,{datasource="fpw"});
      if (contacts.recordCount NEQ 1) throw(message="EXACTLY_ONE_OWNED_CONTACT_REQUIRED");
      var email=new fpw.api.v1.email();
      if (arguments.mode EQ "ambiguous") {
        variables.realEmail=email;email=this;
      }
      var eventService=arguments.mode EQ "confirmation_failure" ? new fpw.tests.support.BasicReviewProductEventFailureStub("after_insert") : "";
      var service=new fpw.api.v1.BasicReviewSendService(emailService=email,pdfService=new fpw.tests.support.RecoverySharePdfProbe(),productEventService=eventService);
      response=service.send(arguments.userId,id,val(contacts.contactId[1]),"recovery_share_" & replace(createUUID(),"-","","all"));
    } else {
      var controller=prepareMock(new fpw.api.v1.floatplan());
      controller.$("resolveFloatPlanUtilsComponentPath","fpw.tests.support.RecoverySharePdfProbe");
      if (arguments.mode EQ "partial") {
        var member=queryExecute("SELECT email FROM users WHERE userId=:uid",p,{datasource="fpw"});
        var recipients=[{EMAIL=toString(member.email[1])},{EMAIL="invalid@@example.test"}];
        controller.$(arguments.source EQ "basic_save_send" ? "loadBasicPlanContactEmails" : "loadPlanContactEmails",recipients);
      }
      makePublic(controller,arguments.source EQ "basic_save_send" ? "sendBasicFloatPlanToContacts" : "sendFloatPlanToContacts","shareForTest");
      try {response=controller.shareForTest(arguments.userId,id);}
      catch(any err){errorType=err.type;errorMessage=err.message;response={SUCCESS=false,ERROR="CONTROLLED_SHARE_EXCEPTION"};}
    }
    var state=readState(arguments.userId);
    state.responseSuccess=structKeyExists(response,"SUCCESS") AND response.SUCCESS EQ true;
    state.responseError=structKeyExists(response,"ERROR") AND isSimpleValue(response.ERROR) ? response.ERROR : "";
    state.exceptionType=errorType;
    state.exceptionMessage=errorMessage;
    state.probe={startedAtPdf=request.recoveryShareProbe.startedAtPdf,startedAtTransport=request.recoveryShareProbe.startedAtTransport,realSubmissionAccepted=request.recoveryShareProbe.realSubmissionAccepted};
    return state;
  }
  public struct function sendBasicReviewFloatPlanEmail(required numeric userId,required string toEmail,required string contactName,
    required string floatPlanName,required string captainName,required string pdfPath) output=false {
    var rows=queryExecute("SELECT COUNT(*) AS n FROM product_events WHERE user_id=:uid AND event_name='recovery_share_started'",
      {uid={value=arguments.userId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
    request.recoveryShareProbe.startedAtTransport=val(rows.n[1]);
    var result=variables.realEmail.sendBasicReviewFloatPlanEmail(argumentCollection=arguments);
    if (!result.success) throw(message="REAL_LOCAL_SUBMISSION_REQUIRED");
    request.recoveryShareProbe.realSubmissionAccepted=true;
    // Lose the application's acknowledgement only after real synchronous local SMTP accepted the message.
    throw(type="FPW.TestLostMailAcknowledgement",message="LOCAL_TEST_ACKNOWLEDGEMENT_LOST_AFTER_MAILHOG_SUBMISSION");
  }
  public struct function readState(required numeric userId) output=false {
    var p={uid={value=arguments.userId,cfsqltype="cf_sql_integer"}};
    var q=queryExecute("SELECT event_name,event_source,entity_type,entity_id,metadata_json,
      DATE_FORMAT(occurred_at_utc,'%Y-%m-%dT%H:%i:%sZ') AS utc FROM product_events
      WHERE user_id=:uid AND event_name LIKE 'recovery_share_%' ORDER BY id",p,{datasource="fpw"});
    var events=[];for(var row in q)arrayAppend(events,row);
    var at=toString(queryExecute("SELECT DATE_FORMAT(UTC_TIMESTAMP(),'%Y-%m-%dT%H:%i:%sZ') AS utc",{},{datasource="fpw"}).utc[1]);
    var coverage=new fpw.includes.InactiveMemberRecoveryCoverageService();
    var classifier=new fpw.includes.InactiveMemberRecoveryClassifierService();
    var plans=queryExecute("SELECT floatplanId,status FROM floatplans WHERE userId=:uid",p,{datasource="fpw"});
    var receipts=queryExecute("SELECT (SELECT COUNT(*) FROM premium_send_receipts WHERE user_id=:uid) AS premium,
      (SELECT COUNT(*) FROM basic_review_send_receipts WHERE user_id=:uid) AS basic,
      (SELECT COUNT(*) FROM premium_send_credits WHERE user_id=:uid AND status='consumed') AS consumed",p,{datasource="fpw"});
    return {ok=true,events=events,evidence=coverage.getShareEvidence(arguments.userId),decision=classifier.evaluateMember(arguments.userId,at).DECISION_CODE,
      planCount=plans.recordCount,planStatus=plans.recordCount ? toString(plans.status[1]) : "",premiumReceipts=val(receipts.premium[1]),basicReceipts=val(receipts.basic[1]),consumedCredits=val(receipts.consumed[1])};
  }
  public struct function dueState(required numeric userId) output=false {
    var enrollment=new fpw.includes.InactiveMemberRecoveryEnrollmentService().ensureEnrolled(arguments.userId);
    if (!enrollment.SUCCESS OR !len(enrollment.ENROLLMENT_UTC)) return {enrollment=enrollment.CODE,eligible=false};
    var at=createObject("java","java.time.Instant").parse(enrollment.ENROLLMENT_UTC).plusSeconds(javaCast("long",604800)).toString();
    var evaluated=new fpw.includes.InactiveMemberRecoveryClassifierService().evaluateMember(arguments.userId,at);
    return {enrollment=enrollment.CODE,eligible=evaluated.ELIGIBLE,decision=evaluated.DECISION_CODE,stage=evaluated.CURRENT_STAGE};
  }
  public struct function purgePlanningForRetentionTest(required numeric userId) output=false {
    // Explicit disposable-fixture destruction, not a production deletion API or history repair.
    var p={uid={value=arguments.userId,cfsqltype="cf_sql_integer"}};
    transaction {
      for(var table in ["floatplan_contacts","floatplan_passengers","floatplan_waypoints","floatplan_notifications","floatplan_notification_log","fpw_notification_log","floatplan_alert_history"])
        queryExecute("DELETE FROM " & table & " WHERE floatPlanId IN (SELECT floatplanId FROM floatplans WHERE userId=:uid)",p,{datasource="fpw"});
      queryExecute("DELETE FROM floatplan_basic_details WHERE floatplan_id IN (SELECT floatplanId FROM floatplans WHERE userId=:uid)",p,{datasource="fpw"});
      for(var table in ["floatplan_activity_segments","floatplan_events","floatplan_monitor_events","floatplan_monitoring","premium_trip_entitlement_events","premium_trip_creation_sessions","member_premium_trip_entitlements","premium_send_receipts","basic_review_send_receipts","premium_send_credits"])
        queryExecute("DELETE FROM " & table & " WHERE user_id=:uid",p,{datasource="fpw"});
      queryExecute("DELETE FROM floatplans WHERE userId=:uid",p,{datasource="fpw"});
    }
    return readState(arguments.userId);
  }
}
