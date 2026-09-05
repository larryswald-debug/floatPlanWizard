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

  // All dependencies are internal objects, never runner request inputs.
  public any function init(
    string datasource="fpw", boolean liveEnabled=false,
    any classifier="", any ledger="", any emailService="", any transport="",
    any contextProvider="", any candidateSource="", any clock=""
  ) output=false {
    variables.datasource=arguments.datasource;
    variables.liveEnabled=arguments.liveEnabled;
    variables.classifier=isObject(arguments.classifier) ? arguments.classifier
      : new fpw.includes.InactiveMemberRecoveryClassifierService(datasource=variables.datasource);
    variables.ledger=isObject(arguments.ledger) ? arguments.ledger
      : new fpw.includes.InactiveMemberRecoveryLedgerService(datasource=variables.datasource);
    variables.emailService=isObject(arguments.emailService) ? arguments.emailService : new fpw.api.v1.email();
    variables.transport=isObject(arguments.transport) ? arguments.transport : variables.emailService;
    variables.contextProvider=arguments.contextProvider;
    variables.candidateSource=arguments.candidateSource;
    variables.clock=arguments.clock;
    return this;
  }

  public struct function processBatch(numeric batchSize=25, boolean dryRun=true) output=false {
    var totals={
      "ok"=true,"mode"=(arguments.dryRun ? "dry_run" : "live"),
      "scanned"=0,"eligible"=0,"claimed"=0,"submitted"=0,"sent"=0,"failed"=0,
      "suppressed"=0,"held"=0,"skipped"=0,"canceled"=0,"ambiguous"=0,
      "stages"={"A"=0,"B"=0,"C"=0,"D"=0},"reasons"={}
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
        outcome=processMember(fix(userId),arguments.dryRun);
      } catch (any memberError) {
        outcome=result("held","MEMBER_PROCESSING_FAILED");
      }
      if (listFind("A,B,C,D",outcome.stage)) totals.stages[outcome.stage]++;
      if (outcome.eligible) totals.eligible++;
      if (outcome.claimed) totals.claimed++;
      if (outcome.submitted) totals.submitted++;
      if (outcome.canceled) totals.canceled++;
      if (outcome.ambiguous) totals.ambiguous++;
      if (listFind("sent,failed,suppressed,held,skipped",outcome.category)) totals[outcome.category]++;
      addReason(totals,outcome.code);
    }
    return totals;
  }

  private struct function processMember(required numeric userId, required boolean dryRun) output=false {
    var initial=evaluateCandidate(arguments.userId);
    var stage=initial.CURRENT_STAGE;
    if (!initial.ELIGIBLE) return classificationResult(initial);
    if (arguments.dryRun) return result("","ELIGIBLE",stage,true);

    var claim={};
    var prepared={};
    var recipient=queryNew("");
    var compliance={};
    var cancellation=result("held","PRE_SEND_CANCELED",stage,true);
    try {
      // Never include SMTP in this transaction. Rollback cancels a new claim or
      // restores an exact prior FAILED retry (including its count/timestamps).
      transaction isolation="read_committed" {
        try {
          claim=initial.LEDGER_STATE.STATUS EQ "FAILED"
            ? variables.ledger.retryFailedStage(arguments.userId,stage)
            : variables.ledger.claimStage(arguments.userId,stage);
          if (!structKeyExists(claim,"CLAIMED") OR !claim.CLAIMED
            OR !listFind("CLAIMED,FAILED_RETRY",claim.CODE)) {
            cancellation=result("skipped",claim.CODE,stage,true);
            throw(type="FPW.Recovery.CancelBeforeSend",message="CLAIM_DENIED");
          }

          var fresh=variables.classifier.evaluateMember(
            userId=arguments.userId, nowUtc=nowUtc(), enrollmentUtc=enrollmentUtc(arguments.userId),
            ownedClaimToken=claim.CLAIM_TOKEN
          );
          if (fresh.CURRENT_STAGE NEQ stage OR !fresh.ELIGIBLE) {
            cancellation=classificationResult(fresh);
            cancellation.stage=stage;
            cancellation.eligible=true;
            cancellation.canceled=true;
            throw(type="FPW.Recovery.CancelBeforeSend",message="REVALIDATION_CANCELED");
          }
          recipient=queryExecute(
            "SELECT email,fName FROM users WHERE userId=:userId LIMIT 1",
            {userId={value=arguments.userId,cfsqltype="cf_sql_integer"}},
            {datasource=variables.datasource}
          );
          if (recipient.recordCount NEQ 1) {
            cancellation=result("held","MEMBER_NOT_FOUND",stage,true,false,true);
            throw(type="FPW.Recovery.CancelBeforeSend",message="RECIPIENT_MISSING");
          }
          compliance=variables.emailService.checkNonEssentialEmailEligibility(
            email=toString(recipient.email[1]),userId=arguments.userId
          );
          if (!compliance.eligible OR compliance.code NEQ "ELIGIBLE") {
            cancellation=result("held",compliance.code,stage,true,false,true);
            throw(type="FPW.Recovery.CancelBeforeSend",message="COMPLIANCE_CANCELED");
          }
          // Classifier supplies no authorized Draft identity: use its approved Dashboard fallback.
          prepared=variables.emailService.buildInactiveMemberRecoveryEmail(
            stage=stage,eligibility=compliance,
            firstName=(isNull(recipient.fName[1]) ? "" : toString(recipient.fName[1]))
          );
          if (!prepared.success) {
            cancellation=result("held",prepared.errorCode,stage,true,false,true);
            throw(type="FPW.Recovery.CancelBeforeSend",message="RENDER_CANCELED");
          }
        } catch (any preparationError) {
          transaction action="rollback";
          rethrow;
        }
      }
    } catch (FPW.Recovery.CancelBeforeSend canceled) {
      return cancellation;
    } catch (any preparationFailed) {
      // No submission has occurred. An uncertain DB commit is held, never sent.
      return result("held","PRE_SEND_PREPARATION_FAILED",stage,true);
    }

    var submission={};
    try {
      submission=variables.transport.submitInactiveMemberRecoveryEmail(
        toEmail=toString(recipient.email[1]),message=prepared
      );
    } catch (any unknownTransportResult) {
      return result("held","TRANSPORT_OUTCOME_UNKNOWN",stage,true,true,false,true);
    }
    if (!isStruct(submission) OR !structKeyExists(submission,"OUTCOME")) {
      return result("held","TRANSPORT_OUTCOME_UNKNOWN",stage,true,true,false,true);
    }
    if (submission.OUTCOME EQ "SUBMITTED") {
      try {
        var sent=variables.ledger.markSent(arguments.userId,stage,claim.CLAIM_TOKEN);
        if (!sent.SUCCESS OR sent.CODE NEQ "SENT") throw(type="FPW.Recovery.Unconfirmed",message="SENT_NOT_CONFIRMED");
      } catch (any unconfirmedSent) {
        return result("held","SENT_CONFIRMATION_UNKNOWN",stage,true,true,false,true,true);
      }
      return result("sent","SENT",stage,true,true,false,false,true);
    }
    if (submission.OUTCOME EQ "FAILED") {
      try {
        var failed=variables.ledger.markFailed(
          arguments.userId,stage,claim.CLAIM_TOKEN,
          (structKeyExists(submission,"CODE") ? safeCode(submission.CODE) : "RECOVERY_SEND_FAILED")
        );
        if (!failed.SUCCESS OR failed.CODE NEQ "FAILED") throw(type="FPW.Recovery.Unconfirmed",message="FAILED_NOT_CONFIRMED");
      } catch (any unconfirmedFailure) {
        return result("held","FAILURE_CONFIRMATION_UNKNOWN",stage,true,true,false,true);
      }
      return result("failed","FAILED",stage,true,true);
    }
    return result("held","TRANSPORT_OUTCOME_UNKNOWN",stage,true,true,false,true);
  }

  private struct function evaluateCandidate(required numeric userId) output=false {
    var evaluated=variables.classifier.evaluateMember(arguments.userId,nowUtc(),enrollmentUtc(arguments.userId));
    if (evaluated.DECISION_CODE EQ "HOLD_RETRY_DECISION_REQUIRED") {
      var state=variables.ledger.getStageState(arguments.userId,evaluated.CURRENT_STAGE);
      if (state.SUCCESS AND structKeyExists(state,"CAN_RETRY") AND state.CAN_RETRY) {
        return variables.classifier.evaluateMember(
          userId=arguments.userId,nowUtc=nowUtc(),enrollmentUtc=enrollmentUtc(arguments.userId),
          evaluateFailedRetry=true
        );
      }
    }
    return evaluated;
  }

  private string function enrollmentUtc(required numeric userId) output=false {
    // No inferred enrollment, signup substitution, blanket date, or backfill.
    return isObject(variables.contextProvider) ? variables.contextProvider.getEnrollmentUtc(arguments.userId) : "";
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
