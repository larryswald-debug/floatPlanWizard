component output="false" {
  variables.datasource="fpw";
  variables.maxAttempts=3;
  variables.contactTotal=3;

  public any function init(string datasource="fpw") output=false {
    variables.datasource=len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
    return this;
  }

  // One immutable enrollment owns one bounded contact sequence. Destination is not identity.
  public struct function getSequenceState(required numeric userId,string ownedClaimToken="") output=false {
    var enrollment=new fpw.includes.InactiveMemberRecoveryEnrollmentService(datasource=variables.datasource).getEnrollment(arguments.userId);
    var result={
      SUCCESS=true,CODE="FOUND",ENROLLMENT_EVENT_ID=enrollment.EVENT_ID,CONTACT_TOTAL=3,
      NEXT_CONTACT_NUMBER=1,COMPLETED=false,LATEST_SENT_CONTACT=0,LATEST_SENT_AT_UTC="",
      CURRENT_CONTACT=emptyContact(),HAS_UNRESOLVED_CLAIM=false,OWNS_CURRENT_CLAIM=false
    };
    if (!enrollment.EVENT_ID) { result.SUCCESS=false; result.CODE="ENROLLMENT_EVIDENCE_REQUIRED"; return result; }
    var rows=queryExecute(
      "SELECT id,user_id,recovery_enrollment_event_id,contact_number,destination_stage,status,claim_token,
        DATE_FORMAT(claimed_at_utc,'%Y-%m-%dT%H:%i:%sZ') AS claimed_at_utc,
        DATE_FORMAT(sent_at_utc,'%Y-%m-%dT%H:%i:%sZ') AS sent_at_utc,
        DATE_FORMAT(failed_at_utc,'%Y-%m-%dT%H:%i:%sZ') AS failed_at_utc,
        attempt_count,last_error_summary,(sent_at_utc > UTC_TIMESTAMP(6)) AS accepted_in_future
       FROM inactive_member_recovery_deliveries WHERE user_id=:userId ORDER BY contact_number,id",
      {userId={value=arguments.userId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource}
    );
    var expected=1;
    var pending=false;
    for (var row in rows) {
      if (val(row.contact_number) LT 1 OR val(row.contact_number) GT variables.contactTotal
        OR val(row.recovery_enrollment_event_id) NEQ enrollment.EVENT_ID
        OR val(row.contact_number) NEQ expected OR pending
        OR !listFind("A,B,C,D",toString(row.destination_stage))
        OR !listFind("SENT,CLAIMED,FAILED",toString(row.status))
        OR val(row.attempt_count) LT 1 OR val(row.attempt_count) GT variables.maxAttempts) {
        result.SUCCESS=false; result.CODE="CONTACT_HISTORY_CONFLICT"; return result;
      }
      if (row.status EQ "SENT") {
        if (isNull(row.sent_at_utc) OR !len(toString(row.sent_at_utc)) OR val(row.accepted_in_future)
          OR compare(toString(row.sent_at_utc),enrollment.ENROLLMENT_UTC) LT 0
          OR (len(result.LATEST_SENT_AT_UTC) AND compare(toString(row.sent_at_utc),result.LATEST_SENT_AT_UTC) LT 0)) {
          result.SUCCESS=false; result.CODE="CONTACT_HISTORY_CONFLICT"; return result;
        }
        result.LATEST_SENT_CONTACT=val(row.contact_number);
        result.LATEST_SENT_AT_UTC=toString(row.sent_at_utc);
        expected++;
      } else {
        pending=true;
        result.CURRENT_CONTACT=rowState(row);
        result.HAS_UNRESOLVED_CLAIM=row.status EQ "CLAIMED";
        result.OWNS_CURRENT_CLAIM=result.HAS_UNRESOLVED_CLAIM
          AND len(arguments.ownedClaimToken) AND compareNoCase(toString(row.claim_token),arguments.ownedClaimToken) EQ 0;
      }
    }
    if (expected GT variables.contactTotal) {
      result.COMPLETED=true; result.NEXT_CONTACT_NUMBER=0;
    } else result.NEXT_CONTACT_NUMBER=expected;
    return result;
  }

  public struct function claimContact(required numeric userId,required numeric enrollmentEventId,
    required numeric contactNumber,required string destinationStage) output=false {
    var identity=validateIdentity(arguments.userId,arguments.enrollmentEventId,arguments.contactNumber);
    if (!identity.SUCCESS) return identity;
    if (!listFind("A,B,C,D",arguments.destinationStage)) return invalid("INVALID_DESTINATION_STAGE");
    var token=lCase(hash(createUUID() & createUUID(),"SHA-256"));
    transaction {
      if (!lockMember(arguments.userId)) return invalid("MEMBER_NOT_FOUND");
      var sequence=getSequenceState(arguments.userId);
      if (!sequence.SUCCESS) return invalid(sequence.CODE);
      if (sequence.ENROLLMENT_EVENT_ID NEQ arguments.enrollmentEventId) return invalid("ENROLLMENT_MISMATCH");
      var existing=getContactState(arguments.userId,arguments.enrollmentEventId,arguments.contactNumber);
      if (existing.HAS_ROW) return existingResult(existing);
      if (sequence.COMPLETED OR sequence.NEXT_CONTACT_NUMBER NEQ arguments.contactNumber
        OR sequence.HAS_UNRESOLVED_CLAIM) return invalid("CONTACT_SEQUENCE_CONFLICT");
      queryExecute(
        "INSERT INTO inactive_member_recovery_deliveries
         (user_id,recovery_enrollment_event_id,contact_number,destination_stage,status,claim_token,
          claimed_at_utc,sent_at_utc,failed_at_utc,attempt_count,last_error_summary,created_at_utc,updated_at_utc)
         VALUES (:userId,:enrollmentId,:contact,:stage,'CLAIMED',:token,UTC_TIMESTAMP(6),NULL,NULL,1,NULL,UTC_TIMESTAMP(6),UTC_TIMESTAMP(6))",
        {userId={value=arguments.userId,cfsqltype="cf_sql_integer"},
         enrollmentId={value=arguments.enrollmentEventId,cfsqltype="cf_sql_bigint"},
         contact={value=arguments.contactNumber,cfsqltype="cf_sql_tinyint"},
         stage={value=arguments.destinationStage,cfsqltype="cf_sql_char"},
         token={value=token,cfsqltype="cf_sql_char"}},{datasource=variables.datasource}
      );
      requireOneChanged("CLAIM_NOT_CONFIRMED");
      return claimedResult(getContactState(arguments.userId,arguments.enrollmentEventId,arguments.contactNumber),token,"CLAIMED",false);
    }
  }

  public struct function retryFailedContact(required numeric userId,required numeric enrollmentEventId,
    required numeric contactNumber,required string destinationStage) output=false {
    var identity=validateIdentity(arguments.userId,arguments.enrollmentEventId,arguments.contactNumber);
    if (!identity.SUCCESS) return identity;
    if (!listFind("A,B,C,D",arguments.destinationStage)) return invalid("INVALID_DESTINATION_STAGE");
    var token=lCase(hash(createUUID() & createUUID(),"SHA-256"));
    transaction {
      if (!lockMember(arguments.userId)) return invalid("MEMBER_NOT_FOUND");
      var sequence=getSequenceState(arguments.userId);
      if (!sequence.SUCCESS) return invalid(sequence.CODE);
      if (sequence.ENROLLMENT_EVENT_ID NEQ arguments.enrollmentEventId) return invalid("ENROLLMENT_MISMATCH");
      var existing=getContactState(arguments.userId,arguments.enrollmentEventId,arguments.contactNumber);
      if (!existing.HAS_ROW) return invalid("NO_FAILED_ATTEMPT");
      if (existing.STATUS NEQ "FAILED") return existingResult(existing);
      if (sequence.NEXT_CONTACT_NUMBER NEQ arguments.contactNumber OR sequence.HAS_UNRESOLVED_CLAIM) return invalid("CONTACT_SEQUENCE_CONFLICT");
      if (existing.ATTEMPT_COUNT GTE variables.maxAttempts) { existing.CODE="RETRY_EXHAUSTED"; return existing; }
      queryExecute(
        "UPDATE inactive_member_recovery_deliveries SET status='CLAIMED',claim_token=:token,
         destination_stage=:stage,claimed_at_utc=UTC_TIMESTAMP(6),sent_at_utc=NULL,failed_at_utc=NULL,
         attempt_count=attempt_count+1,last_error_summary=NULL,updated_at_utc=UTC_TIMESTAMP(6)
         WHERE id=:id AND status='FAILED' AND attempt_count < :maxAttempts",
        {token={value=token,cfsqltype="cf_sql_char"},stage={value=arguments.destinationStage,cfsqltype="cf_sql_char"},
         id={value=existing.LEDGER_ID,cfsqltype="cf_sql_bigint"},maxAttempts={value=variables.maxAttempts,cfsqltype="cf_sql_integer"}},
        {datasource=variables.datasource}
      );
      requireOneChanged("RETRY_NOT_CONFIRMED");
      return claimedResult(getContactState(arguments.userId,arguments.enrollmentEventId,arguments.contactNumber),token,"FAILED_RETRY",true);
    }
  }

  public struct function markSent(required numeric userId,required numeric enrollmentEventId,
    required numeric contactNumber,required string claimToken) output=false {
    return transition(arguments.userId,arguments.enrollmentEventId,arguments.contactNumber,arguments.claimToken,"SENT","");
  }

  public struct function markFailed(required numeric userId,required numeric enrollmentEventId,
    required numeric contactNumber,required string claimToken,required string errorCode) output=false {
    return transition(arguments.userId,arguments.enrollmentEventId,arguments.contactNumber,arguments.claimToken,"FAILED",sanitizeErrorCode(arguments.errorCode));
  }

  private struct function transition(required numeric userId,required numeric enrollmentEventId,
    required numeric contactNumber,required string claimToken,required string status,required string errorCode) output=false {
    var identity=validateIdentity(arguments.userId,arguments.enrollmentEventId,arguments.contactNumber);
    if (!identity.SUCCESS) return identity;
    if (!reFind("^[0-9a-f]{64}$",lCase(arguments.claimToken))) return invalid("INVALID_CLAIM_TOKEN");
    transaction {
      if (!lockMember(arguments.userId)) return invalid("MEMBER_NOT_FOUND");
      var sequence=getSequenceState(arguments.userId,arguments.claimToken);
      if (!sequence.SUCCESS) return invalid(sequence.CODE);
      if (sequence.ENROLLMENT_EVENT_ID NEQ arguments.enrollmentEventId) return invalid("ENROLLMENT_MISMATCH");
      var existing=getContactState(arguments.userId,arguments.enrollmentEventId,arguments.contactNumber);
      if (!existing.HAS_ROW) return invalid("CLAIM_NOT_FOUND");
      if (existing.STATUS EQ "SENT") { existing.CODE="ALREADY_SENT"; return existing; }
      if (existing.STATUS NEQ "CLAIMED" OR !sequence.OWNS_CURRENT_CLAIM
        OR sequence.NEXT_CONTACT_NUMBER NEQ arguments.contactNumber) return invalid("CLAIM_MISMATCH");
      var terminal=arguments.status EQ "SENT"
        ? "status='SENT',sent_at_utc=UTC_TIMESTAMP(6),failed_at_utc=NULL,last_error_summary=NULL"
        : "status='FAILED',sent_at_utc=NULL,failed_at_utc=UTC_TIMESTAMP(6),last_error_summary=:errorCode";
      var params={id={value=existing.LEDGER_ID,cfsqltype="cf_sql_bigint"},
        token={value=lCase(arguments.claimToken),cfsqltype="cf_sql_char"}};
      if (arguments.status EQ "FAILED") params.errorCode={value=arguments.errorCode,cfsqltype="cf_sql_varchar"};
      queryExecute("UPDATE inactive_member_recovery_deliveries SET " & terminal & ",
        updated_at_utc=UTC_TIMESTAMP(6) WHERE id=:id AND status='CLAIMED' AND claim_token=:token",
        params,{datasource=variables.datasource});
      requireOneChanged(arguments.status EQ "SENT" ? "SENT_NOT_CONFIRMED" : "FAILURE_NOT_CONFIRMED");
      var changed=getContactState(arguments.userId,arguments.enrollmentEventId,arguments.contactNumber);
      changed.CODE=arguments.status;
      return changed;
    }
  }

  public struct function getContactState(required numeric userId,required numeric enrollmentEventId,required numeric contactNumber) output=false {
    var identity=validateIdentity(arguments.userId,arguments.enrollmentEventId,arguments.contactNumber);
    if (!identity.SUCCESS) return identity;
    var enrollment=new fpw.includes.InactiveMemberRecoveryEnrollmentService(datasource=variables.datasource).getEnrollment(arguments.userId);
    if (enrollment.EVENT_ID NEQ arguments.enrollmentEventId) return invalid("ENROLLMENT_MISMATCH");
    var rows=queryExecute(
      "SELECT id,user_id,recovery_enrollment_event_id,contact_number,destination_stage,status,attempt_count,last_error_summary,
       DATE_FORMAT(claimed_at_utc,'%Y-%m-%dT%H:%i:%sZ') AS claimed_at_utc,
       DATE_FORMAT(sent_at_utc,'%Y-%m-%dT%H:%i:%sZ') AS sent_at_utc,
       DATE_FORMAT(failed_at_utc,'%Y-%m-%dT%H:%i:%sZ') AS failed_at_utc
       FROM inactive_member_recovery_deliveries WHERE user_id=:userId AND recovery_enrollment_event_id=:enrollmentId AND contact_number=:contact LIMIT 1",
      {userId={value=arguments.userId,cfsqltype="cf_sql_integer"},enrollmentId={value=arguments.enrollmentEventId,cfsqltype="cf_sql_bigint"},
       contact={value=arguments.contactNumber,cfsqltype="cf_sql_tinyint"}},{datasource=variables.datasource});
    if (!rows.recordCount) return emptyContact();
    for (var row in rows) return rowState(row);
    return emptyContact();
  }

  public struct function getLastSuccessfulRecoveryUtc(required numeric userId) output=false {
    var sequence=getSequenceState(arguments.userId);
    return {SUCCESS=sequence.SUCCESS,CODE=sequence.LATEST_SENT_CONTACT ? "FOUND" : "NO_SUCCESSFUL_RECOVERY",
      USER_ID=arguments.userId,HAS_SENT=sequence.LATEST_SENT_CONTACT GT 0,LAST_SENT_AT_UTC=sequence.LATEST_SENT_AT_UTC};
  }

  private struct function emptyContact() output=false {
    return {SUCCESS=true,CLAIMED=false,CODE="NOT_CLAIMED",HAS_ROW=false,LEDGER_ID=0,STATUS="NONE",
      ATTEMPT_COUNT=0,CAN_RETRY=false,CLAIMED_AT_UTC="",SENT_AT_UTC="",FAILED_AT_UTC="",LAST_ERROR_CODE=""};
  }
  private struct function rowState(required struct row) output=false {
    return {SUCCESS=true,CLAIMED=false,CODE="FOUND",HAS_ROW=true,LEDGER_ID=val(arguments.row.id),
      USER_ID=val(arguments.row.user_id),ENROLLMENT_EVENT_ID=val(arguments.row.recovery_enrollment_event_id),
      CONTACT_NUMBER=val(arguments.row.contact_number),DESTINATION_STAGE=toString(arguments.row.destination_stage),
      STATUS=toString(arguments.row.status),ATTEMPT_COUNT=val(arguments.row.attempt_count),
      CAN_RETRY=arguments.row.status EQ "FAILED" AND val(arguments.row.attempt_count) LT variables.maxAttempts,
      CLAIMED_AT_UTC=toString(arguments.row.claimed_at_utc),
      SENT_AT_UTC=isNull(arguments.row.sent_at_utc) ? "" : toString(arguments.row.sent_at_utc),
      FAILED_AT_UTC=isNull(arguments.row.failed_at_utc) ? "" : toString(arguments.row.failed_at_utc),
      LAST_ERROR_CODE=isNull(arguments.row.last_error_summary) ? "" : toString(arguments.row.last_error_summary)};
  }
  private struct function claimedResult(required struct state,required string token,required string code,required boolean retry) output=false {
    arguments.state.CLAIMED=true; arguments.state.CODE=arguments.code;
    arguments.state.CLAIM_TOKEN=arguments.token; arguments.state.RETRY=arguments.retry;
    return arguments.state;
  }
  private struct function existingResult(required struct state) output=false {
    arguments.state.CODE=arguments.state.STATUS EQ "SENT" ? "ALREADY_SENT"
      : (arguments.state.STATUS EQ "CLAIMED" ? "ALREADY_CLAIMED" : "FAILED_PREVIOUSLY");
    return arguments.state;
  }
  private struct function validateIdentity(required numeric userId,required numeric enrollmentEventId,required numeric contactNumber) output=false {
    if (arguments.userId LTE 0 OR arguments.userId NEQ fix(arguments.userId)) return invalid("INVALID_MEMBER");
    if (arguments.enrollmentEventId LTE 0 OR arguments.enrollmentEventId NEQ fix(arguments.enrollmentEventId)) return invalid("INVALID_ENROLLMENT");
    if (arguments.contactNumber LT 1 OR arguments.contactNumber GT variables.contactTotal
      OR arguments.contactNumber NEQ fix(arguments.contactNumber)) return invalid("INVALID_CONTACT_NUMBER");
    return {SUCCESS=true};
  }
  private boolean function lockMember(required numeric userId) output=false {
    var row=queryExecute("SELECT userId FROM users WHERE userId=:userId FOR UPDATE",
      {userId={value=arguments.userId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
    return row.recordCount EQ 1;
  }
  private void function requireOneChanged(required string code) output=false {
    var count=queryExecute("SELECT ROW_COUNT() AS changed_count",{},{datasource=variables.datasource});
    if (count.recordCount NEQ 1 OR val(count.changed_count[1]) NEQ 1)
      throw(type="FPW.InactiveRecovery.PersistenceFailed",message=arguments.code);
  }
  private string function sanitizeErrorCode(required string errorCode) output=false {
    var candidate=uCase(trim(arguments.errorCode));
    return reFind("^[A-Z][A-Z0-9_]{0,63}$",candidate) ? candidate : "RECOVERY_SEND_FAILED";
  }
  private struct function invalid(required string code) output=false {
    return {SUCCESS=false,CLAIMED=false,CODE=arguments.code,HAS_ROW=false};
  }
}
