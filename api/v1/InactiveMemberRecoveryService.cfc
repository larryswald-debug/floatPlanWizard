component output="false" {
  variables.datasource="fpw";
  variables.liveEnabled=false;
  variables.classifier="";
  variables.ledger="";
  variables.emailService="";
  variables.transport="";
  variables.contextProvider="";
  variables.candidateSource="";
  variables.clock="";
  variables.observability="";

  // All dependencies are internal objects, never runner request inputs.
  public any function init(
    string datasource="fpw", boolean liveEnabled=false,
    any classifier="", any ledger="", any emailService="", any transport="",
    any contextProvider="", any candidateSource="", any clock="", any observability=""
  ) output=false {
    variables.datasource=arguments.datasource;
    variables.liveEnabled=arguments.liveEnabled;
    variables.classifier=isObject(arguments.classifier) ? arguments.classifier
      : new fpw.includes.InactiveMemberRecoveryClassifierService(datasource=variables.datasource);
    variables.ledger=isObject(arguments.ledger) ? arguments.ledger
      : new fpw.includes.InactiveMemberRecoveryLedgerService(datasource=variables.datasource);
    variables.emailService=isObject(arguments.emailService) ? arguments.emailService : new fpw.api.v1.email();
    variables.transport=isObject(arguments.transport) ? arguments.transport : variables.emailService;
    variables.contextProvider=isObject(arguments.contextProvider) ? arguments.contextProvider
      : new fpw.includes.InactiveMemberRecoveryCoverageService(datasource=variables.datasource);
    variables.candidateSource=arguments.candidateSource;
    variables.clock=arguments.clock;
    variables.observability=arguments.observability;
    if (!isObject(variables.observability)) {
      try { variables.observability=new fpw.includes.InactiveMemberRecoveryObservabilityService(datasource=variables.datasource); }
      catch (any observationUnavailable) { variables.observability=""; }
    }
    return this;
  }

  public struct function processBatch(numeric batchSize=25, boolean dryRun=true,string executionSource="internal") output=false {
    var maintenancePath=getDirectoryFromPath(getCurrentTemplatePath()) & "../../.codex-snapshots/recovery-center-migration.lock";
    if (fileExists(maintenancePath)) return {ok=false,error="RECOVERY_MAINTENANCE"};
    var totals={
      "ok"=true,"mode"=(arguments.dryRun ? "dry_run" : "live"),
      "scanned"=0,"eligible"=0,"claimed"=0,"submitted"=0,"sent"=0,"failed"=0,
      "suppressed"=0,"held"=0,"skipped"=0,"canceled"=0,"ambiguous"=0,
      "destination_stages"={"A"=0,"B"=0,"C"=0,"D"=0},"contacts"={"1"=0,"2"=0,"3"=0},"reasons"={},
      "run_id"=0,"observation_gaps"=0
    };
    if (arguments.batchSize LT 1 OR arguments.batchSize GT 100 OR arguments.batchSize NEQ fix(arguments.batchSize)) {
      totals.ok=false;
      totals.error="INVALID_BATCH_SIZE";
      return totals;
    }
    if (!arguments.dryRun AND !variables.liveEnabled) {
      totals.ok=false;
      totals.error="LIVE_MODE_DISABLED";
      return totals;
    }
    var runId=0;
    var runSettings={};
    try { runSettings=new fpw.includes.InactiveMemberRecoverySettingsService(datasource=variables.datasource).getSettings(); }
    catch (any settingsSnapshotUnavailable) { totals.observation_gaps++; }
    try {
      if (isObject(variables.observability)) runId=variables.observability.beginRun(arguments.executionSource,arguments.dryRun,runSettings);
      else totals.observation_gaps++;
    } catch (any runObservationFailed) { totals.observation_gaps++; }
    totals.run_id=runId;
    if (runId GT 0) {
      try { new fpw.includes.InactiveMemberRecoveryAttributionService(datasource=variables.datasource).reconcileBatch(100); }
      catch (any attributionObservationFailed) { totals.observation_gaps++; }
    }
    var candidates=[];
    try {
      candidates=isObject(variables.candidateSource)
        ? variables.candidateSource.getCandidateIds(fix(arguments.batchSize))
        : discoverCandidates(fix(arguments.batchSize));
      if (!isArray(candidates) OR arrayLen(candidates) GT arguments.batchSize) {
        throw(type="FPW.Recovery.InvalidCandidates",message="CANDIDATE_SOURCE_FAILED");
      }
    } catch (any candidateError) {
      totals.ok=false;
      totals.error="CANDIDATE_SOURCE_FAILED";
      finishObservedRun(runId,totals);
      return totals;
    }
    var seen={};
    for (var userId in candidates) {
      if (!isNumeric(userId) OR userId LTE 0 OR userId NEQ fix(userId) OR structKeyExists(seen,toString(userId))) {
        totals.skipped++;
        addReason(totals,"INVALID_OR_DUPLICATE_CANDIDATE");
        continue;
      }
      seen[toString(userId)]=true;
      totals.scanned++;
      var outcome={};
      try {
        outcome=processMember(fix(userId),arguments.dryRun,runId);
      } catch (any memberError) {
        outcome=result("held","MEMBER_PROCESSING_FAILED");
      }
      if (listFind("A,B,C,D",outcome.stage)) totals.destination_stages[outcome.stage]++;
      if (structKeyExists(outcome,"contact_number") AND outcome.contact_number GTE 1 AND outcome.contact_number LTE 3)
        totals.contacts[toString(outcome.contact_number)]++;
      if (structKeyExists(outcome,"observation_gap") AND outcome.observation_gap) totals.observation_gaps++;
      if (outcome.eligible) totals.eligible++;
      if (outcome.claimed) totals.claimed++;
      if (outcome.submitted) totals.submitted++;
      if (outcome.canceled) totals.canceled++;
      if (outcome.ambiguous) totals.ambiguous++;
      if (listFind("sent,failed,suppressed,held,skipped",outcome.category)) totals[outcome.category]++;
      addReason(totals,outcome.code);
    }
    finishObservedRun(runId,totals);
    return totals;
  }

  private void function finishObservedRun(required numeric runId,required struct totals) output=false {
    try { if (arguments.runId GT 0) variables.observability.finishRun(arguments.runId,arguments.totals); }
    catch (any runObservationFailed) { arguments.totals.observation_gaps++; }
  }

  private struct function processMember(required numeric userId,required boolean dryRun,numeric runId=0) output=false {
    var initial={};
    try { initial=evaluateCandidate(arguments.userId); }
    catch (any evaluationFailed) {
      initial={MEMBER_ID=arguments.userId,CURRENT_STAGE="",CONTACT_NUMBER=0,CONTACT_TOTAL=3,ENROLLMENT_EVENT_ID=0,
        TIMING_REVISION=0,TIMING_SETTINGS={},RECOVERY_STATE_REVISION=0,RECOVERY_START_UTC="",
        DECISION="HELD",DECISION_CODE="MEMBER_EVALUATION_FAILED",ELIGIBLE=false,POLICY_DECISION={},EVIDENCE_SUMMARY={}};
    }
    var evaluationId=0;
    var observationGap=false;
    try { if (arguments.runId GT 0) evaluationId=variables.observability.recordEvaluation(arguments.runId,arguments.userId,initial); }
    catch (any evaluationObservationFailed) { observationGap=true; }
    var outcome={};
    try {
      outcome=processEvaluatedMember(arguments.userId,arguments.dryRun,initial,arguments.runId,evaluationId);
    } catch (any memberFailed) { outcome=result("held","MEMBER_PROCESSING_FAILED",initial.CURRENT_STAGE); }
    outcome.contact_number=initial.CONTACT_NUMBER;
    outcome.contact_total=initial.CONTACT_TOTAL;
    outcome.enrollment_event_id=initial.ENROLLMENT_EVENT_ID;
    outcome.timing_revision=initial.TIMING_REVISION;
    outcome.evaluation_id=evaluationId;
    outcome.observation_gap=observationGap OR (structKeyExists(outcome,"observation_gap") AND outcome.observation_gap);
    try { if (evaluationId GT 0) variables.observability.finalizeEvaluation(evaluationId,outcome); }
    catch (any terminalObservationFailed) { outcome.observation_gap=true; }
    return outcome;
  }

  private struct function processEvaluatedMember(required numeric userId,required boolean dryRun,
    required struct initial,required numeric runId,required numeric evaluationId) output=false {
    var stage=initial.CURRENT_STAGE;
    var contact=initial.CONTACT_NUMBER;
    var enrollmentId=initial.ENROLLMENT_EVENT_ID;
    if (!initial.ELIGIBLE) return classificationResult(initial);
    if (arguments.dryRun) return result("","ELIGIBLE",stage,true);
    var claim={};
    var prepared={};
    var recipient=queryNew("");
    var compliance={};
    var messageId=0;
    var observationGap=false;
    var cancellation=result("held","PRE_SEND_CANCELED",stage,true);
    try {
      // SMTP stays outside this transaction. Cancellation restores exact prior retry state.
      transaction isolation="read_committed" {
        try {
          claim=initial.LEDGER_STATE.STATUS EQ "FAILED"
            ? variables.ledger.retryFailedContact(arguments.userId,enrollmentId,contact,stage)
            : variables.ledger.claimContact(arguments.userId,enrollmentId,contact,stage);
          if (!structKeyExists(claim,"CLAIMED") OR !claim.CLAIMED OR !listFind("CLAIMED,FAILED_RETRY",claim.CODE)) {
            cancellation=result("skipped",claim.CODE,stage,true);
            throw(type="FPW.Recovery.CancelBeforeSend",message="CLAIM_DENIED");
          }
          var fresh=variables.classifier.evaluateMember(
            userId=arguments.userId,nowUtc=nowUtc(),enrollmentUtc=enrollmentUtc(arguments.userId),
            ownedClaimToken=claim.CLAIM_TOKEN,coverageVerification=coverageVerification(arguments.userId));
          if (!matchesPreparedContext(fresh,initial)) {
            cancellation=fresh.ELIGIBLE ? result("held","REVALIDATION_CANCELED",stage,true,false,true) : classificationResult(fresh);
            cancellation.stage=stage; cancellation.eligible=true; cancellation.canceled=true;
            throw(type="FPW.Recovery.CancelBeforeSend",message="REVALIDATION_CANCELED");
          }
          recipient=queryExecute("SELECT email,fName FROM users WHERE userId=:userId LIMIT 1",
            {userId={value=arguments.userId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
          if (recipient.recordCount NEQ 1) {
            cancellation=result("held","MEMBER_NOT_FOUND",stage,true,false,true);
            throw(type="FPW.Recovery.CancelBeforeSend",message="RECIPIENT_MISSING");
          }
          compliance=variables.emailService.checkNonEssentialEmailEligibility(email=toString(recipient.email[1]),userId=arguments.userId);
          if (!compliance.eligible OR compliance.code NEQ "ELIGIBLE") {
            cancellation=result("held",compliance.code,stage,true,false,true);
            throw(type="FPW.Recovery.CancelBeforeSend",message="COMPLIANCE_CANCELED");
          }
          var destinationService=new fpw.includes.InactiveMemberRecoveryDestinationService(datasource=variables.datasource);
          var destinationPath=destinationService.resolveStage(arguments.userId,stage);
          prepared=variables.emailService.buildInactiveMemberRecoveryEmail(
            contactNumber=contact,stage=stage,eligibility=compliance,
            firstName=isNull(recipient.fName[1]) ? "" : toString(recipient.fName[1]),
            verifiedRouteUrl=stage EQ "C" AND find("?recoveryAction=route&",destinationPath) ? destinationPath : "",
            verifiedDraftUrl=stage EQ "D" AND find("?recoveryAction=draft&",destinationPath) ? destinationPath : "");
          if (!prepared.success) {
            cancellation=result("held",prepared.errorCode,stage,true,false,true);
            throw(type="FPW.Recovery.CancelBeforeSend",message="RENDER_CANCELED");
          }
          prepared.toEmail=toString(recipient.email[1]);
          var originalMessage=duplicate(prepared);
          try {
            if (isObject(variables.observability)) {
              var observed=variables.observability.prepareMessage({
                runId=arguments.runId,evaluationId=arguments.evaluationId,userId=arguments.userId,
                enrollmentEventId=enrollmentId,contactNumber=contact,contactTotal=3,destinationStage=stage,
                destinationPath=destinationPath,templateId=prepared.templateId,deliveryId=claim.LEDGER_ID,
                transportAttemptNumber=claim.ATTEMPT_COUNT,timingRevision=initial.TIMING_REVISION,settings=initial.TIMING_SETTINGS
              },prepared);
              messageId=observed.messageId;
              prepared=observed.message;
            } else observationGap=true;
          } catch (any preparationObservationFailed) { prepared=originalMessage; observationGap=true; }

          // Rendering/tracking do not confer authorization: independently check current state and target.
          var finalCheck=variables.classifier.evaluateMember(
            userId=arguments.userId,nowUtc=nowUtc(),enrollmentUtc=enrollmentUtc(arguments.userId),
            ownedClaimToken=claim.CLAIM_TOKEN,coverageVerification=coverageVerification(arguments.userId));
          var finalRecipient=queryExecute("SELECT email FROM users WHERE userId=:userId LIMIT 1",
            {userId={value=arguments.userId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
          if (finalRecipient.recordCount NEQ 1 OR compare(toString(finalRecipient.email[1]),toString(recipient.email[1])) NEQ 0) {
            cancellation=result("held","RECIPIENT_CHANGED",stage,true,false,true);
            throw(type="FPW.Recovery.CancelBeforeSend",message="RECIPIENT_CHANGED");
          }
          var finalCompliance=variables.emailService.checkNonEssentialEmailEligibility(email=toString(finalRecipient.email[1]),userId=arguments.userId);
          if (!matchesPreparedContext(finalCheck,initial) OR !finalCompliance.eligible OR finalCompliance.code NEQ "ELIGIBLE"
            OR compare(destinationService.resolveStage(arguments.userId,finalCheck.CURRENT_STAGE),destinationPath) NEQ 0) {
            cancellation=result("held","FINAL_REVALIDATION_CANCELED",stage,true,false,true);
            throw(type="FPW.Recovery.CancelBeforeSend",message="FINAL_REVALIDATION_CANCELED");
          }
        } catch (any preparationError) { transaction action="rollback"; rethrow; }
      }
    } catch (FPW.Recovery.CancelBeforeSend canceled) {
      observeMessage(messageId,"CANCELED");
      cancellation.observation_gap=observationGap;
      return cancellation;
    } catch (any preparationFailed) {
      observeMessage(messageId,"CANCELED");
      return result("held","PRE_SEND_PREPARATION_FAILED",stage,true);
    }

    var submission={};
    try { submission=variables.transport.submitInactiveMemberRecoveryEmail(toEmail=toString(recipient.email[1]),message=prepared); }
    catch (any unknownTransportResult) {
      return finishObservedMessage(result("held","TRANSPORT_OUTCOME_UNKNOWN",stage,true,true,false,true),messageId,"OUTCOME_UNKNOWN","",observationGap);
    }
    if (!isStruct(submission) OR !structKeyExists(submission,"OUTCOME")) {
      return finishObservedMessage(result("held","TRANSPORT_OUTCOME_UNKNOWN",stage,true,true,false,true),messageId,"OUTCOME_UNKNOWN","",observationGap);
    }
    if (submission.OUTCOME EQ "SUBMITTED") {
      try {
        var sent=variables.ledger.markSent(arguments.userId,enrollmentId,contact,claim.CLAIM_TOKEN);
        if (!sent.SUCCESS OR sent.CODE NEQ "SENT") throw(type="FPW.Recovery.Unconfirmed",message="SENT_NOT_CONFIRMED");
      } catch (any unconfirmedSent) {
        return finishObservedMessage(result("held","SENT_CONFIRMATION_UNKNOWN",stage,true,true,false,true,true),messageId,"OUTCOME_UNKNOWN","",observationGap);
      }
      if (!observeMessage(messageId,"SEND_ACCEPTED",sent.SENT_AT_UTC)) observationGap=true;
      var accepted=result("sent","SENT",stage,true,true,false,false,true);
      accepted.message_id=messageId; accepted.observation_gap=observationGap;
      return accepted;
    }
    if (submission.OUTCOME EQ "FAILED") {
      try {
        var failed=variables.ledger.markFailed(arguments.userId,enrollmentId,contact,claim.CLAIM_TOKEN,
          structKeyExists(submission,"CODE") ? safeCode(submission.CODE) : "SUBMISSION_FAILED");
        if (!failed.SUCCESS OR failed.CODE NEQ "FAILED") throw(type="FPW.Recovery.Unconfirmed",message="FAILURE_NOT_CONFIRMED");
      } catch (any unconfirmedFailure) {
        return finishObservedMessage(result("held","FAILURE_CONFIRMATION_UNKNOWN",stage,true,true,false,true),messageId,"OUTCOME_UNKNOWN","",observationGap);
      }
      return finishObservedMessage(result("failed","FAILED",stage,true,true),messageId,"SEND_FAILED","",observationGap);
    }
    return finishObservedMessage(result("held","TRANSPORT_OUTCOME_UNKNOWN",stage,true,true,false,true),messageId,"OUTCOME_UNKNOWN","",observationGap);
  }

  private struct function finishObservedMessage(required struct outcome,required numeric messageId,
    required string status,string acceptedAtUtc="",boolean observationGap=false) output=false {
    arguments.outcome.message_id=arguments.messageId;
    arguments.outcome.observation_gap=!observeMessage(arguments.messageId,arguments.status,arguments.acceptedAtUtc) OR arguments.observationGap;
    return arguments.outcome;
  }

  private boolean function matchesPreparedContext(required struct fresh,required struct initial) output=false {
    return arguments.fresh.ELIGIBLE AND arguments.fresh.CURRENT_STAGE EQ arguments.initial.CURRENT_STAGE
      AND arguments.fresh.CONTACT_NUMBER EQ arguments.initial.CONTACT_NUMBER
      AND arguments.fresh.ENROLLMENT_EVENT_ID EQ arguments.initial.ENROLLMENT_EVENT_ID
      AND arguments.fresh.TIMING_REVISION EQ arguments.initial.TIMING_REVISION
      AND arguments.fresh.RECOVERY_STATE_REVISION EQ arguments.initial.RECOVERY_STATE_REVISION
      AND compare(arguments.fresh.RECOVERY_START_UTC,arguments.initial.RECOVERY_START_UTC) EQ 0;
  }

  private boolean function observeMessage(required numeric messageId,required string status,string acceptedAtUtc="") output=false {
    if (!arguments.messageId) return false;
    try { variables.observability.finalizeMessage(arguments.messageId,arguments.status,arguments.acceptedAtUtc); return true; }
    catch (any messageObservationFailed) { return false; }
  }

  private struct function evaluateCandidate(required numeric userId) output=false {
    var evaluated=variables.classifier.evaluateMember(
      userId=arguments.userId,nowUtc=nowUtc(),enrollmentUtc=enrollmentUtc(arguments.userId),
      coverageVerification=coverageVerification(arguments.userId)
    );
    if (evaluated.DECISION_CODE EQ "HOLD_RETRY_DECISION_REQUIRED") {
      var state=variables.ledger.getContactState(arguments.userId,evaluated.ENROLLMENT_EVENT_ID,evaluated.CONTACT_NUMBER);
      if (state.SUCCESS AND structKeyExists(state,"CAN_RETRY") AND state.CAN_RETRY) {
        return variables.classifier.evaluateMember(
          userId=arguments.userId,nowUtc=nowUtc(),enrollmentUtc=enrollmentUtc(arguments.userId),
          evaluateFailedRetry=true,coverageVerification=coverageVerification(arguments.userId)
        );
      }
    }
    return evaluated;
  }

  private string function enrollmentUtc(required numeric userId) output=false {
    // No inferred enrollment, signup substitution, blanket date, or backfill.
    return isObject(variables.contextProvider) ? variables.contextProvider.getEnrollmentUtc(arguments.userId) : "";
  }

  private struct function coverageVerification(required numeric userId) output=false {
    // Enrollment service intentionally provides NO coverage attestation. Only a
    // separately reviewed internal provider may supply these proofs in the future.
    if (isObject(variables.contextProvider) AND structKeyExists(variables.contextProvider,"getCoverageVerification")) {
      var proof=variables.contextProvider.getCoverageVerification(arguments.userId);
      if (isStruct(proof)) return proof;
    }
    return {};
  }

  private string function nowUtc() output=false {
    if (isObject(variables.clock)) return variables.clock.nowUtc();
    var clockRow=queryExecute("SELECT DATE_FORMAT(UTC_TIMESTAMP(),'%Y-%m-%dT%H:%i:%sZ') AS now_utc",{}, {datasource=variables.datasource});
    return toString(clockRow.now_utc[1]);
  }

  private array function discoverCandidates(required numeric limit) output=false {
    var ids=[];
    var cursorKey="fpwRecoveryScan_" & hash(variables.datasource,"SHA-256");
    // Ephemeral traversal cursor only; not enrollment, eligibility, or delivery state.
    lock name=cursorKey type="exclusive" timeout=10 {
      var afterId=structKeyExists(application,cursorKey) ? val(application[cursorKey]) : 0;
      var candidates=selectCandidates(afterId,arguments.limit);
      if (!candidates.recordCount AND afterId GT 0) candidates=selectCandidates(0,arguments.limit);
      for (var row in candidates) arrayAppend(ids,val(row.userId));
      application[cursorKey]=arrayLen(ids) ? ids[arrayLen(ids)] : 0;
    }
    return ids;
  }

  private query function selectCandidates(required numeric afterId,required numeric limit) output=false {
    return queryExecute(
      "SELECT u.userId FROM users u WHERE u.userId>:afterId
       AND NOT EXISTS (SELECT 1 FROM member_entitlements m WHERE m.user_id=u.userId
         AND LOWER(m.entitlement_type)='admin' AND LOWER(m.status)='active'
         AND m.starts_at_utc<=UTC_TIMESTAMP() AND (m.expires_at_utc IS NULL OR m.expires_at_utc>UTC_TIMESTAMP())
         AND m.revoked_at_utc IS NULL)
       AND NOT EXISTS (SELECT 1 FROM product_events e WHERE e.user_id=u.userId AND e.entity_type='float_plan'
         AND ((e.event_name='basic_send_completed' AND e.event_source IN ('basic_save_send','basic_review_send'))
           OR (e.event_name='premium_send_completed' AND e.event_source='premium_save_send')))
       ORDER BY u.userId LIMIT " & fix(arguments.limit),
      {afterId={value=arguments.afterId,cfsqltype="cf_sql_integer"}},
      {datasource=variables.datasource}
    );
  }

  private struct function classificationResult(required struct evaluated) output=false {
    var category=arguments.evaluated.DECISION EQ "SUPPRESSED" ? "suppressed"
      : (arguments.evaluated.DECISION EQ "DEFERRED" ? "skipped" : "held");
    return result(category,arguments.evaluated.DECISION_CODE,arguments.evaluated.CURRENT_STAGE);
  }

  private struct function result(
    required string category,required string code,string stage="",boolean eligible=false,
    boolean claimed=false,boolean canceled=false,boolean ambiguous=false,boolean submitted=false
  ) output=false {
    return {
      category=arguments.category,code=safeCode(arguments.code),stage=arguments.stage,
      eligible=arguments.eligible,claimed=arguments.claimed,canceled=arguments.canceled,
      ambiguous=arguments.ambiguous,submitted=arguments.submitted
    };
  }

  private string function safeCode(required any code) output=false {
    var value=isSimpleValue(arguments.code) ? uCase(trim(toString(arguments.code))) : "";
    return reFind("^[A-Z][A-Z0-9_]{0,63}$",value) ? value : "RECOVERY_OPERATION_FAILED";
  }

  private void function addReason(required struct totals,required string code) output=false {
    var key=safeCode(arguments.code);
    arguments.totals.reasons[key]=(structKeyExists(arguments.totals.reasons,key) ? arguments.totals.reasons[key] : 0)+1;
  }

  public struct function getRunnerSettings() output=false {
    var settings={token="",liveEnabled=false};
    var configPath=structKeyExists(application,"stripeConfigPath")
      ? toString(application.stripeConfigPath) : expandPath("/_fpw_private/stripe-config.json");
    try {
      var config=deserializeJSON(fileRead(configPath,"utf-8"));
      if (structKeyExists(config,"FPW_INACTIVE_RECOVERY_RUNNER_TOKEN") AND isSimpleValue(config.FPW_INACTIVE_RECOVERY_RUNNER_TOKEN)) {
        settings.token=trim(toString(config.FPW_INACTIVE_RECOVERY_RUNNER_TOKEN));
      }
      settings.liveEnabled=structKeyExists(config,"FPW_INACTIVE_RECOVERY_LIVE_ENABLED")
        AND compare(serializeJSON(config.FPW_INACTIVE_RECOVERY_LIVE_ENABLED),"true") EQ 0;
    } catch (any configError) {
      return settings;
    }
    return settings;
  }
}
