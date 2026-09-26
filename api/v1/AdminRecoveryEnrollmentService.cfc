component output="false" {
  variables.datasource="fpw";
  variables.enrollment="";
  variables.coverage="";
  variables.audit="";
  variables.authorization="";
  variables.confirmation="ENROLL REVIEWED MEMBERS";

  public any function init(string datasource="fpw", any enrollmentService="", any coverageService="",
    any auditService="", any authorizationService="") output=false {
    variables.datasource=arguments.datasource;
    variables.enrollment=isObject(arguments.enrollmentService) ? arguments.enrollmentService
      : new fpw.includes.InactiveMemberRecoveryEnrollmentService(datasource=variables.datasource);
    variables.coverage=isObject(arguments.coverageService) ? arguments.coverageService
      : new fpw.includes.InactiveMemberRecoveryCoverageService(datasource=variables.datasource);
    variables.audit=isObject(arguments.auditService) ? arguments.auditService
      : new fpw.api.v1.AdminAuditService().init(variables.datasource);
    variables.authorization=isObject(arguments.authorizationService) ? arguments.authorizationService
      : new fpw.api.v1.AdminAuthorizationService().init(variables.datasource);
    return this;
  }

  // GET is read-only for database evidence. Only the reviewed selection lives in session.
  public struct function preview(required string userIds) output=false {
    var admin=requireAdmin("GET");
    lock scope="session" type="exclusive" timeout="10" {
      structDelete(session,"fpwRecoveryEnrollmentReview",false);
    }
    var result=buildPreview(arguments.userIds,admin.userId);
    if (!result.ok) return result;
    var token=lCase(replace(createUUID(),"-","","all")) & lCase(replace(createUUID(),"-","","all"));
    var expiresAt=dateAdd("n",15,now());
    var eligibleIds=[];
    for (var row in result.rows) {
      if (row.code EQ "ENROLLABLE") arrayAppend(eligibleIds,row.userId);
    }
    lock scope="session" type="exclusive" timeout="10" {
      session.fpwRecoveryEnrollmentReview={
        actorUserId=admin.userId, token=token, expiresAt=expiresAt,
        requestedIds=result.requestedIds, eligibleIds=eligibleIds, rows=duplicate(result.rows)
      };
    }
    structDelete(result,"requestedIds",false);
    result.reviewToken=token;
    result.reviewExpiresUtc=dateTimeFormat(dateConvert("local2utc",expiresAt),"yyyy-mm-dd'T'HH:nn:ss'Z'");
    return result;
  }

  // The browser supplies only the review token and explicit confirmation, never commit IDs.
  public struct function enroll(required string reviewToken, required string confirmation) output=false {
    var admin=requireAdmin("POST");
    var snapshot={};
    var rejection="";
    lock scope="session" type="exclusive" timeout="10" {
      if (!structKeyExists(session,"fpwRecoveryEnrollmentReview") OR !isStruct(session.fpwRecoveryEnrollmentReview)) {
        rejection="REVIEW_REQUIRED";
      } else {
        var review=session.fpwRecoveryEnrollmentReview;
        if (review.actorUserId NEQ admin.userId) {
          rejection="REVIEW_ACTOR_CHANGED";
          structDelete(session,"fpwRecoveryEnrollmentReview",false);
        } else if (dateCompare(review.expiresAt,now()) LTE 0) {
          rejection="REVIEW_EXPIRED";
          structDelete(session,"fpwRecoveryEnrollmentReview",false);
        } else if (!reFind("^[a-f0-9]{64}$",arguments.reviewToken)
          OR compare(hash(arguments.reviewToken,"SHA-256"),hash(review.token,"SHA-256")) NEQ 0) {
          rejection="REVIEW_TOKEN_INVALID";
        } else if (compare(arguments.confirmation,variables.confirmation) NEQ 0) {
          rejection="CONFIRMATION_REQUIRED";
        } else {
          snapshot=duplicate(review);
          // Consume before audit or enrollment; a concurrent/replayed request cannot reuse it.
          structDelete(session,"fpwRecoveryEnrollmentReview",false);
        }
      }
    }
    if (len(rejection)) return failureReport("enroll",rejection,"Review the selected members again before enrolling.");
    return executeReviewed(snapshot,admin.userId);
  }

  private struct function requireAdmin(required string method) output=false {
    var user=structKeyExists(session,"user") AND isStruct(session.user) ? session.user : {};
    var admin=variables.authorization.authorizeCurrentSession(user);
    if (!admin.authorized) throw(type="FPW.RecoveryEnrollment.Authorization",message="ADMIN_REQUIRED");
    if (!structKeyExists(cgi,"request_method") OR compareNoCase(toString(cgi.request_method),arguments.method) NEQ 0) {
      throw(type="FPW.RecoveryEnrollment.Authorization",message="METHOD_NOT_ALLOWED");
    }
    if (arguments.method EQ "POST"
      AND !variables.authorization.isValidCsrfToken(variables.authorization.resolveRequestCsrfToken())) {
      throw(type="FPW.RecoveryEnrollment.Authorization",message="CSRF_INVALID");
    }
    return admin;
  }

  private struct function buildPreview(required string userIds, required numeric actorUserId) output=false {
    var ids=parseIds(arguments.userIds);
    if (!arrayLen(ids)) return failureReport("preview","INVALID_CANDIDATES","Enter 1 to 100 distinct positive member IDs, separated by commas or whitespace.");
    var report=newReport("preview");
    report.requestedIds=ids;
    for (var id in ids) {
      arrayAppend(report.rows,assessRow(id));
    }
    summarize(report);
    report.message=report.failures GT 0
      ? "Preview could not verify every member. Resolve the failures and preview again before enrolling."
      : "Preview only. No enrollment evidence was written. Only the members marked ENROLLABLE can be enrolled from this review.";
    return report;
  }

  private array function parseIds(required string userIds) output=false {
    var raw=trim(arguments.userIds);
    var ids=[];
    var seen={};
    if (!len(raw) OR len(raw) GT 2000
      OR !reFind("^[1-9][0-9]{0,9}(?:[ \t\r\n]*(?:,|[ \t\r\n])[ \t\r\n]*[1-9][0-9]{0,9})*$",raw)) return [];
    var parts=listToArray(reReplace(raw,"[, \t\r\n]+",",","all"));
    if (!arrayLen(parts) OR arrayLen(parts) GT 100) return [];
    for (var part in parts) {
      if (val(part) GT 2147483647 OR structKeyExists(seen,part)) return [];
      seen[part]=true;
      arrayAppend(ids,val(part));
    }
    return ids;
  }

  private struct function assessRow(required numeric userId) output=false {
    var row={userId=arguments.userId,code="ENROLLMENT_FAILED",reason="ENROLLMENT_FAILED",errorReference="",enrollmentUtc="",coverageVerified=false};
    try {
      row=outcomeRow(arguments.userId,variables.enrollment.assessEnrollment(arguments.userId));
      var verification=variables.coverage.getCoverageVerification(arguments.userId);
      row.coverageVerified=isStruct(verification);
      for (var key in ["stage_history","activity_coverage","sharing_history","recovery_history"]) {
        if (!isStruct(verification) OR !structKeyExists(verification,key) OR !verification[key]) row.coverageVerified=false;
      }
    } catch (any unavailable) {
      row.code="ENROLLMENT_FAILED"; row.reason="PREVIEW_VERIFICATION_FAILED"; row.errorReference=""; row.enrollmentUtc="";
      row.coverageVerified=false;
    }
    return row;
  }

  private struct function outcomeRow(required numeric userId, required struct outcome) output=false {
    var row={userId=arguments.userId,code="ENROLLMENT_FAILED",reason="ENROLLMENT_FAILED",errorReference="",enrollmentUtc="",coverageVerified=false};
    if (!structKeyExists(arguments.outcome,"SUCCESS") OR !isBoolean(arguments.outcome.SUCCESS)
      OR !structKeyExists(arguments.outcome,"CODE") OR !isSimpleValue(arguments.outcome.CODE)) return row;
    if (!arguments.outcome.SUCCESS) {
      if (compare(toString(arguments.outcome.CODE),"ENROLLMENT_FAILED") NEQ 0) return row;
      // Only fixed diagnostic categories and correlation references reach the admin response.
      if (structKeyExists(arguments.outcome,"REASON") AND isSimpleValue(arguments.outcome.REASON)
        AND listFind("ENROLLMENT_EVIDENCE_INVALID,ENROLLMENT_DATABASE_ERROR,ENROLLMENT_COMPONENT_ERROR,ENROLLMENT_ASSESSMENT_ERROR,ENROLLMENT_WRITE_ERROR",toString(arguments.outcome.REASON))) {
        row.reason=toString(arguments.outcome.REASON);
      }
      if (structKeyExists(arguments.outcome,"ERROR_REFERENCE") AND isSimpleValue(arguments.outcome.ERROR_REFERENCE)
        AND len(toString(arguments.outcome.ERROR_REFERENCE)) LTE 36
        AND ((len(toString(arguments.outcome.ERROR_REFERENCE)) EQ 35
            AND isValid("uuid",toString(arguments.outcome.ERROR_REFERENCE))
            AND reFindNoCase("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{16}$",toString(arguments.outcome.ERROR_REFERENCE)))
          OR (len(toString(arguments.outcome.ERROR_REFERENCE)) EQ 36
            AND reFindNoCase("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$",toString(arguments.outcome.ERROR_REFERENCE))))) {
        row.errorReference=lCase(toString(arguments.outcome.ERROR_REFERENCE));
      }
      return row;
    }
    if (!listFind("ENROLLABLE,ALREADY_ENROLLED,ENROLLED,MEMBER_NOT_FOUND,NOT_ELIGIBLE_FOR_ENROLLMENT",toString(arguments.outcome.CODE))) return row;
    row.code=toString(arguments.outcome.CODE);
    row.reason="";
    if (structKeyExists(arguments.outcome,"REASON") AND isSimpleValue(arguments.outcome.REASON)
      AND reFind("^[A-Z0-9_]{1,100}$",toString(arguments.outcome.REASON))) {
      row.reason=toString(arguments.outcome.REASON);
    }
    if (structKeyExists(arguments.outcome,"ENROLLMENT_UTC") AND isSimpleValue(arguments.outcome.ENROLLMENT_UTC)
      AND reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",toString(arguments.outcome.ENROLLMENT_UTC))) {
      row.enrollmentUtc=toString(arguments.outcome.ENROLLMENT_UTC);
    }
    return row;
  }

  private struct function executeReviewed(required struct snapshot, required numeric actorUserId) output=false {
    var report=newReport("enroll");
    var operationId=lCase(createUUID());
    var reviewed=[];
    var eligible={};
    for (var id in arguments.snapshot.eligibleIds) eligible[toString(id)]=true;
    for (var row in arguments.snapshot.rows) arrayAppend(reviewed,{userId=row.userId,code=row.code,reason=row.reason});
    try {
      writeAudit(arguments.actorUserId,"recovery_enrollment_reviewed",operationId,true,{members=reviewed});
    } catch (any auditUnavailable) {
      report.rows=duplicate(arguments.snapshot.rows);
      for (var row in report.rows) {
        if (structKeyExists(eligible,toString(row.userId))) { row.code="ENROLLMENT_NOT_ATTEMPTED"; row.reason="AUDIT_UNAVAILABLE"; row.errorReference=""; }
      }
      summarize(report);
      report.eligible=arrayLen(arguments.snapshot.eligibleIds);
      if (!report.failures) { report.failures=1; report.reasons["AUDIT_UNAVAILABLE"]=1; }
      report.ok=false;
      report.message="The required audit could not be recorded. No members were enrolled. Review again after audit availability is restored.";
      return report;
    }
    var stopWrites=false;
    for (var original in arguments.snapshot.rows) {
      var row=duplicate(original);
      if (structKeyExists(eligible,toString(row.userId))) {
        if (stopWrites) {
          row.code="ENROLLMENT_NOT_ATTEMPTED"; row.reason="AUDIT_UNAVAILABLE"; row.errorReference="";
        } else {
          try {
            // This existing command locks the member and rechecks current eligibility.
            var current=outcomeRow(row.userId,variables.enrollment.ensureEnrolled(row.userId));
            current.coverageVerified=row.coverageVerified;
            row=current;
          } catch (any enrollmentUnavailable) {
            row.code="ENROLLMENT_FAILED"; row.reason="ENROLLMENT_COMMAND_FAILED"; row.errorReference=""; row.enrollmentUtc="";
          }
        }
      }
      arrayAppend(report.rows,row);
      if (!stopWrites) {
        try {
          writeAudit(arguments.actorUserId,"recovery_enrollment_result",operationId,
            !listFind("ENROLLMENT_FAILED,ENROLLMENT_NOT_ATTEMPTED",row.code),{userId=row.userId,code=row.code,reason=row.reason});
        } catch (any resultAuditUnavailable) {
          // Prior per-member transactions may already be committed. Never roll them back or retry.
          stopWrites=true;
          report.auditIncomplete=true;
        }
      }
    }
    summarize(report);
    report.eligible=arrayLen(arguments.snapshot.eligibleIds);
    if (report.auditIncomplete) {
      report.failures++;
      report.reasons["AUDIT_RESULT_UNAVAILABLE"]=1;
      report.ok=false;
      report.message="Some enrollment results may already be committed, but result auditing failed. Remaining writes stopped. Review current enrollment again; do not replay this request.";
    } else {
      report.message=report.failures GT 0
        ? "Enrollment completed with failures shown below. Existing successful enrollments remain committed; review again before any retry."
        : "Reviewed enrollment completed. No recovery messages were sent. Enrollment alone does not prove coverage or immediate sending eligibility.";
    }
    return report;
  }

  private void function writeAudit(required numeric actorUserId, required string action, required string operationId,
    required boolean success, required struct values) output=false {
    variables.audit.record(actorUserId=arguments.actorUserId,action=arguments.action,
      targetType="recovery_enrollment_cohort",targetId=arguments.operationId,success=arguments.success,
      requestId=structKeyExists(request,"fpwRequestId") ? toString(request.fpwRequestId) : "",
      newValues=arguments.values);
  }

  private struct function newReport(required string mode) output=false {
    return {ok=true,mode=arguments.mode,scanned=0,eligible=0,already_enrolled=0,newly_enrolled=0,
      skipped=0,failures=0,reasons={},rows=[],message="",reviewToken="",reviewExpiresUtc="",auditIncomplete=false};
  }

  private void function summarize(required struct report) output=false {
    arguments.report.scanned=arrayLen(arguments.report.rows);
    arguments.report.eligible=0; arguments.report.already_enrolled=0; arguments.report.newly_enrolled=0;
    arguments.report.skipped=0; arguments.report.failures=0; arguments.report.reasons={};
    for (var row in arguments.report.rows) {
      if (row.code EQ "ENROLLABLE") arguments.report.eligible++;
      else if (row.code EQ "ALREADY_ENROLLED") arguments.report.already_enrolled++;
      else if (row.code EQ "ENROLLED") arguments.report.newly_enrolled++;
      else if (listFind("ENROLLMENT_FAILED,ENROLLMENT_NOT_ATTEMPTED",row.code)) arguments.report.failures++;
      else arguments.report.skipped++;
      var reason=len(row.reason) ? row.reason : row.code;
      arguments.report.reasons[reason]=(structKeyExists(arguments.report.reasons,reason) ? arguments.report.reasons[reason] : 0)+1;
    }
    arguments.report.ok=arguments.report.failures EQ 0;
  }

  private struct function failureReport(required string mode, required string code, required string message) output=false {
    var report=newReport(arguments.mode);
    report.ok=false; report.failures=1; report.reasons[arguments.code]=1; report.message=arguments.message;
    return report;
  }
}
