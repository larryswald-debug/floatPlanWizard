component output="false" {
  variables.datasource="fpw";
  variables.events="";
  variables.eventName="inactive_member_recovery_enrolled";

  public any function init(string datasource="fpw", any eventService="") output=false {
    variables.datasource=arguments.datasource;
    variables.events=isObject(arguments.eventService) ? arguments.eventService
      : new fpw.includes.ProductEventService(datasource=variables.datasource);
    return this;
  }

  // Read-only. Empty means absent, not verified inactivity. Corruption throws a safe error.
  public string function getEnrollmentUtc(required numeric userId) output=false {
    if (!validId(arguments.userId)) return "";
    var row=queryExecute(
      "SELECT e.user_id,e.event_name,e.entity_type,e.entity_id,e.event_source,e.idempotency_key,
        e.metadata_json,DATE_FORMAT(e.occurred_at_utc,'%Y-%m-%dT%H:%i:%sZ') AS enrollment_utc,
        (e.occurred_at_utc>'1970-01-01' AND e.occurred_at_utc<=UTC_TIMESTAMP()
          AND e.occurred_at_utc=e.created_at_utc) AS valid_clock
       FROM product_events e JOIN users u ON u.userId=:userId
       WHERE (e.user_id=:userId AND e.event_name=:eventName) OR e.idempotency_key=:eventKey",
      eventParams(arguments.userId),{datasource=variables.datasource}
    );
    if (!row.recordCount) return "";
    var valid=row.recordCount EQ 1;
    if (valid) {
      valid=val(row.user_id[1]) EQ arguments.userId AND val(row.entity_id[1]) EQ arguments.userId
        AND compare(toString(row.event_name[1]),variables.eventName) EQ 0
        AND compare(toString(row.entity_type[1]),"user") EQ 0
        AND compare(toString(row.event_source[1]),"recovery_enrollment") EQ 0
        AND compare(toString(row.idempotency_key[1]),eventKey(arguments.userId)) EQ 0
        AND val(row.valid_clock[1]) EQ 1;
    }
    if (valid) {
      try {
        var metadata=deserializeJSON(toString(row.metadata_json[1]));
        valid=isStruct(metadata) AND structIsEmpty(metadata);
      } catch (any invalidMetadata) { valid=false; }
    }
    if (!valid) throw(type="FPW.Recovery.InvalidEnrollment",message="ENROLLMENT_EVIDENCE_INVALID");
    return toString(row.enrollment_utc[1]);
  }

  // Explicit internal command only. Never called by a sender, scan, login, or signup.
  public struct function ensureEnrolled(required numeric userId) output=false {
    if (!validId(arguments.userId)) return outcome("MEMBER_NOT_FOUND");
    try {
      var result={};
      transaction isolation="read_committed" {
        try {
          var member=queryExecute("SELECT userId FROM users WHERE userId=:userId FOR UPDATE",
            {userId={value=arguments.userId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
          if (!member.recordCount) {
            result=outcome("MEMBER_NOT_FOUND");
          } else {
            result=assessEnrollment(arguments.userId);
            if (result.CODE EQ "ENROLLABLE") {
              var recorded=variables.events.recordEvent(
                userId=arguments.userId,eventName=variables.eventName,entityType="user",
                entityId=arguments.userId,eventSource="recovery_enrollment",metadata={},
                idempotencyKey=eventKey(arguments.userId)
              );
              if (!recorded.SUCCESS OR (!recorded.RECORDED AND !recorded.DUPLICATE)) {
                throw(type="FPW.Recovery.EnrollmentFailed",message="ENROLLMENT_NOT_CONFIRMED");
              }
              var enrolledUtc=getEnrollmentUtc(arguments.userId);
              if (!len(enrolledUtc)) throw(type="FPW.Recovery.EnrollmentFailed",message="ENROLLMENT_NOT_CONFIRMED");
              result=outcome(recorded.RECORDED ? "ENROLLED" : "ALREADY_ENROLLED",enrolledUtc);
            } else if (!result.SUCCESS) {
              throw(type="FPW.Recovery.EnrollmentFailed",message="ENROLLMENT_ASSESSMENT_FAILED");
            }
          }
        } catch (any enrollmentError) {
          transaction action="rollback";
          rethrow;
        }
      }
      return result;
    } catch (any enrollmentFailed) {
      return outcome("ENROLLMENT_FAILED","","",false);
    }
  }

  // Reuse the classifier, not a second share/admin/lifecycle classifier. Only these
  // specific holds occur AFTER its broad account gates. Unknown decisions fail closed.
  public struct function assessEnrollment(required numeric userId) output=false {
    if (!validId(arguments.userId)) return outcome("MEMBER_NOT_FOUND");
    try {
      var existing=getEnrollmentUtc(arguments.userId);
      if (len(existing)) return outcome("ALREADY_ENROLLED",existing);
      var clock=queryExecute("SELECT DATE_FORMAT(UTC_TIMESTAMP(),'%Y-%m-%dT%H:%i:%sZ') AS now_utc",{},
        {datasource=variables.datasource});
      var evaluated=new fpw.includes.InactiveMemberRecoveryClassifierService(datasource=variables.datasource)
        .evaluateMember(userId=arguments.userId,nowUtc=toString(clock.now_utc[1]));
      if (evaluated.DECISION_CODE EQ "MEMBER_NOT_FOUND") return outcome("MEMBER_NOT_FOUND");
      if (listFind("ENROLLMENT_EVIDENCE_REQUIRED,HOLD_INCOMPLETE_STAGE_CLOCK",evaluated.DECISION_CODE)) {
        return outcome("ENROLLABLE","",evaluated.DECISION_CODE);
      }
      return outcome("NOT_ELIGIBLE_FOR_ENROLLMENT","",evaluated.DECISION_CODE);
    } catch (any assessmentFailed) {
      return outcome("ENROLLMENT_FAILED","","",false);
    }
  }

  // Explicit, bounded, read-only cohort preview for internal/manual rollout tooling.
  // The caller owns authorization/selection. No identities are returned.
  public struct function previewMembers(required array userIds) output=false {
    var totals={"ok"=true,"scanned"=0,"already_enrolled"=0,"enrollable"=0,
      "held"=0,"shared"=0,"not_eligible"=0,"reasons"={}};
    if (arrayLen(arguments.userIds) GT 100) return {"ok"=false,"error"="INVALID_BATCH_SIZE"};
    var seen={};
    for (var id in arguments.userIds) {
      if (!isNumeric(id) OR !validId(id) OR structKeyExists(seen,toString(id))) {
        return {"ok"=false,"error"="INVALID_CANDIDATES"};
      }
      seen[toString(id)]=true;
    }
    for (var id in arguments.userIds) {
      var result=assessEnrollment(id);
      totals.scanned++;
      if (result.CODE EQ "ALREADY_ENROLLED") totals.already_enrolled++;
      else if (result.CODE EQ "ENROLLABLE") totals.enrollable++;
      else if (result.REASON EQ "SUPPRESSED_ALREADY_SHARED") totals.shared++;
      else if (!result.SUCCESS OR left(result.REASON,5) EQ "HOLD_") totals.held++;
      else totals.not_eligible++;
      var code=len(result.REASON) ? result.REASON : result.CODE;
      totals.reasons[code]=(structKeyExists(totals.reasons,code) ? totals.reasons[code] : 0)+1;
    }
    return totals;
  }

  private boolean function validId(required numeric userId) output=false {
    return arguments.userId GT 0 AND arguments.userId LTE 2147483647 AND arguments.userId EQ fix(arguments.userId);
  }
  private string function eventKey(required numeric userId) output=false {
    return variables.eventName & ":" & fix(arguments.userId);
  }
  private struct function eventParams(required numeric userId) output=false {
    return {userId={value=arguments.userId,cfsqltype="cf_sql_integer"},
      eventName={value=variables.eventName,cfsqltype="cf_sql_varchar"},
      eventKey={value=eventKey(arguments.userId),cfsqltype="cf_sql_varchar"}};
  }
  private struct function outcome(required string code,string atUtc="",string reason="",boolean success=true) output=false {
    return {SUCCESS=arguments.success,CODE=arguments.code,ENROLLMENT_UTC=arguments.atUtc,REASON=arguments.reason};
  }
}
