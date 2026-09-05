component output="false" {

  variables.datasource = "fpw";
  variables.maxAttempts = 3;

  public any function init(string datasource="fpw") output=false {
    variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
    return this;
  }

  public struct function claimStage(required numeric userId, required string stage) output=false {
    var validated = validateIdentity(arguments.userId, arguments.stage);
    if (!validated.SUCCESS) return validated;
    var token = lCase(hash(createUUID() & createUUID(),"SHA-256"));
    var inserted = false;
    var row = queryNew("");
    transaction {
      if (!lockMember(validated.USER_ID)) return invalid("MEMBER_NOT_FOUND");
      queryExecute(
        "INSERT IGNORE INTO inactive_member_recovery_deliveries (
           user_id,recovery_stage,status,claim_token,claimed_at_utc,sent_at_utc,
           failed_at_utc,attempt_count,last_error_summary,created_at_utc,updated_at_utc
         ) VALUES (
           :userId,:stage,'CLAIMED',:token,UTC_TIMESTAMP(6),NULL,
           NULL,1,NULL,UTC_TIMESTAMP(6),UTC_TIMESTAMP(6)
         )",
        {
          userId={value=validated.USER_ID,cfsqltype="cf_sql_integer"},
          stage={value=validated.STAGE,cfsqltype="cf_sql_char"},
          token={value=token,cfsqltype="cf_sql_char"}
        },
        {datasource=variables.datasource}
      );
      var count = queryExecute("SELECT ROW_COUNT() AS inserted_count",{}, {datasource=variables.datasource});
      inserted = count.recordCount EQ 1 AND val(count.inserted_count[1]) EQ 1;
      row = lockStageRow(validated.USER_ID,validated.STAGE);
      if (row.recordCount NEQ 1) return invalid("CLAIM_NOT_FOUND");
      if (inserted) return claimedResult(row,token,"CLAIMED",false);
      return existingResult(row);
    }
  }

  public struct function retryFailedStage(required numeric userId, required string stage) output=false {
    var validated = validateIdentity(arguments.userId, arguments.stage);
    if (!validated.SUCCESS) return validated;
    var token = lCase(hash(createUUID() & createUUID(),"SHA-256"));
    var row = queryNew("");
    transaction {
      if (!lockMember(validated.USER_ID)) return invalid("MEMBER_NOT_FOUND");
      row = lockStageRow(validated.USER_ID,validated.STAGE);
      if (row.recordCount NEQ 1) return invalid("NO_FAILED_ATTEMPT");
      var status = uCase(toString(row.status[1]));
      if (status EQ "SENT") return stateResult(row,"ALREADY_SENT");
      if (status EQ "CLAIMED") return stateResult(row,"ALREADY_CLAIMED");
      if (status NEQ "FAILED") return invalid("INVALID_LEDGER_STATE");
      if (val(row.attempt_count[1]) GTE variables.maxAttempts) {
        return stateResult(row,"RETRY_EXHAUSTED");
      }
      queryExecute(
        "UPDATE inactive_member_recovery_deliveries
         SET status='CLAIMED',
             claim_token=:token,
             claimed_at_utc=UTC_TIMESTAMP(6),
             sent_at_utc=NULL,
             failed_at_utc=NULL,
             attempt_count=attempt_count+1,
             last_error_summary=NULL,
             updated_at_utc=UTC_TIMESTAMP(6)
         WHERE id=:id AND status='FAILED' AND attempt_count < :maxAttempts",
        {
          token={value=token,cfsqltype="cf_sql_char"},
          id={value=row.id[1],cfsqltype="cf_sql_bigint"},
          maxAttempts={value=variables.maxAttempts,cfsqltype="cf_sql_integer"}
        },
        {datasource=variables.datasource}
      );
      var count = queryExecute("SELECT ROW_COUNT() AS updated_count",{}, {datasource=variables.datasource});
      if (count.recordCount NEQ 1 OR val(count.updated_count[1]) NEQ 1) {
        return invalid("RETRY_NOT_CONFIRMED");
      }
      row = lockStageRow(validated.USER_ID,validated.STAGE);
      return claimedResult(row,token,"FAILED_RETRY",true);
    }
  }

  public struct function markSent(
    required numeric userId,
    required string stage,
    required string claimToken
  ) output=false {
    var validated = validateClaim(arguments.userId,arguments.stage,arguments.claimToken);
    if (!validated.SUCCESS) return validated;
    var row = queryNew("");
    transaction {
      if (!lockMember(validated.USER_ID)) return invalid("MEMBER_NOT_FOUND");
      row = lockStageRow(validated.USER_ID,validated.STAGE);
      if (row.recordCount NEQ 1) return invalid("CLAIM_NOT_FOUND");
      if (uCase(toString(row.status[1])) EQ "SENT") return stateResult(row,"ALREADY_SENT");
      if (uCase(toString(row.status[1])) NEQ "CLAIMED"
        OR compareNoCase(toString(row.claim_token[1]),validated.CLAIM_TOKEN) NEQ 0) {
        return stateResult(row,"CLAIM_MISMATCH");
      }
      queryExecute(
        "UPDATE inactive_member_recovery_deliveries
         SET status='SENT',
             sent_at_utc=UTC_TIMESTAMP(6),
             failed_at_utc=NULL,
             last_error_summary=NULL,
             updated_at_utc=UTC_TIMESTAMP(6)
         WHERE id=:id AND status='CLAIMED' AND claim_token=:token",
        {
          id={value=row.id[1],cfsqltype="cf_sql_bigint"},
          token={value=validated.CLAIM_TOKEN,cfsqltype="cf_sql_char"}
        },
        {datasource=variables.datasource}
      );
      requireOneChanged("SENT_NOT_CONFIRMED");
      row = lockStageRow(validated.USER_ID,validated.STAGE);
      return stateResult(row,"SENT");
    }
  }

  public struct function markFailed(
    required numeric userId,
    required string stage,
    required string claimToken,
    required string errorCode
  ) output=false {
    var validated = validateClaim(arguments.userId,arguments.stage,arguments.claimToken);
    if (!validated.SUCCESS) return validated;
    var safeError = sanitizeErrorCode(arguments.errorCode);
    var row = queryNew("");
    transaction {
      if (!lockMember(validated.USER_ID)) return invalid("MEMBER_NOT_FOUND");
      row = lockStageRow(validated.USER_ID,validated.STAGE);
      if (row.recordCount NEQ 1) return invalid("CLAIM_NOT_FOUND");
      if (uCase(toString(row.status[1])) EQ "SENT") return stateResult(row,"ALREADY_SENT");
      if (uCase(toString(row.status[1])) NEQ "CLAIMED"
        OR compareNoCase(toString(row.claim_token[1]),validated.CLAIM_TOKEN) NEQ 0) {
        return stateResult(row,"CLAIM_MISMATCH");
      }
      queryExecute(
        "UPDATE inactive_member_recovery_deliveries
         SET status='FAILED',
             sent_at_utc=NULL,
             failed_at_utc=UTC_TIMESTAMP(6),
             last_error_summary=:errorCode,
             updated_at_utc=UTC_TIMESTAMP(6)
         WHERE id=:id AND status='CLAIMED' AND claim_token=:token",
        {
          id={value=row.id[1],cfsqltype="cf_sql_bigint"},
          token={value=validated.CLAIM_TOKEN,cfsqltype="cf_sql_char"},
          errorCode={value=safeError,cfsqltype="cf_sql_varchar"}
        },
        {datasource=variables.datasource}
      );
      requireOneChanged("FAILURE_NOT_CONFIRMED");
      row = lockStageRow(validated.USER_ID,validated.STAGE);
      return stateResult(row,"FAILED");
    }
  }

  public struct function getStageState(required numeric userId, required string stage) output=false {
    var validated = validateIdentity(arguments.userId,arguments.stage);
    if (!validated.SUCCESS) return validated;
    if (!memberExists(validated.USER_ID)) return invalid("MEMBER_NOT_FOUND");
    var row = queryExecute(
      "SELECT id,user_id,recovery_stage,status,claimed_at_utc,sent_at_utc,failed_at_utc,
              attempt_count,last_error_summary,created_at_utc,updated_at_utc
       FROM inactive_member_recovery_deliveries
       WHERE user_id=:userId AND recovery_stage=:stage LIMIT 1",
      {
        userId={value=validated.USER_ID,cfsqltype="cf_sql_integer"},
        stage={value=validated.STAGE,cfsqltype="cf_sql_char"}
      },
      {datasource=variables.datasource}
    );
    if (row.recordCount NEQ 1) {
      return {SUCCESS=true,CODE="NOT_CLAIMED",USER_ID=validated.USER_ID,STAGE=validated.STAGE,HAS_ROW=false};
    }
    var result = stateResult(row,"FOUND");
    result.HAS_ROW = true;
    return result;
  }

  public struct function getLastSuccessfulRecoveryUtc(required numeric userId) output=false {
    if (arguments.userId LTE 0 OR arguments.userId NEQ fix(arguments.userId)) return invalid("INVALID_MEMBER");
    if (!memberExists(arguments.userId)) return invalid("MEMBER_NOT_FOUND");
    var latest = queryExecute(
      "SELECT CONCAT(
          DATE_FORMAT(MAX(sent_at_utc),'%Y-%m-%dT%H:%i:%s.'),
          LEFT(DATE_FORMAT(MAX(sent_at_utc),'%f'),3),
          'Z'
        ) AS latest_sent_utc
       FROM inactive_member_recovery_deliveries
       WHERE user_id=:userId AND status='SENT'",
      {userId={value=arguments.userId,cfsqltype="cf_sql_integer"}},
      {datasource=variables.datasource}
    );
    var hasSent = (latest.recordCount EQ 1
      AND !isNull(latest.latest_sent_utc[1])
      AND len(trim(toString(latest.latest_sent_utc[1]))) GT 0) ? true : false;
    return {
      SUCCESS=true,
      CODE=(hasSent ? "FOUND" : "NO_SUCCESSFUL_RECOVERY"),
      USER_ID=fix(arguments.userId),
      HAS_SENT=hasSent,
      LAST_SENT_AT_UTC=(hasSent ? toString(latest.latest_sent_utc[1]) : "")
    };
  }

  private struct function validateIdentity(required numeric userId, required string stage) output=false {
    var normalizedStage = uCase(trim(arguments.stage));
    if (arguments.userId LTE 0 OR arguments.userId NEQ fix(arguments.userId)) return invalid("INVALID_MEMBER");
    if (!listFind("A,B,C,D",normalizedStage)) return invalid("INVALID_STAGE");
    return {SUCCESS=true,USER_ID=fix(arguments.userId),STAGE=normalizedStage};
  }

  private struct function validateClaim(
    required numeric userId,
    required string stage,
    required string claimToken
  ) output=false {
    var result = validateIdentity(arguments.userId,arguments.stage);
    if (!result.SUCCESS) return result;
    var normalizedToken = lCase(trim(arguments.claimToken));
    if (!reFind("^[0-9a-f]{64}$",normalizedToken)) {
      return invalid("INVALID_CLAIM_TOKEN");
    }
    result.CLAIM_TOKEN = normalizedToken;
    return result;
  }

  private boolean function lockMember(required numeric userId) output=false {
    var row = queryExecute(
      "SELECT userId FROM users WHERE userId=:userId FOR UPDATE",
      {userId={value=arguments.userId,cfsqltype="cf_sql_integer"}},
      {datasource=variables.datasource}
    );
    return row.recordCount EQ 1;
  }

  private boolean function memberExists(required numeric userId) output=false {
    var row = queryExecute(
      "SELECT userId FROM users WHERE userId=:userId LIMIT 1",
      {userId={value=arguments.userId,cfsqltype="cf_sql_integer"}},
      {datasource=variables.datasource}
    );
    return row.recordCount EQ 1;
  }

  private query function lockStageRow(required numeric userId, required string stage) output=false {
    return queryExecute(
      "SELECT id,user_id,recovery_stage,status,claim_token,claimed_at_utc,sent_at_utc,
              failed_at_utc,attempt_count,last_error_summary,created_at_utc,updated_at_utc
       FROM inactive_member_recovery_deliveries
       WHERE user_id=:userId AND recovery_stage=:stage LIMIT 1 FOR UPDATE",
      {
        userId={value=arguments.userId,cfsqltype="cf_sql_integer"},
        stage={value=arguments.stage,cfsqltype="cf_sql_char"}
      },
      {datasource=variables.datasource}
    );
  }

  private void function requireOneChanged(required string code) output=false {
    var count = queryExecute("SELECT ROW_COUNT() AS changed_count",{}, {datasource=variables.datasource});
    if (count.recordCount NEQ 1 OR val(count.changed_count[1]) NEQ 1) {
      throw(type="FPW.InactiveRecovery.PersistenceFailed",message=arguments.code);
    }
  }

  private string function sanitizeErrorCode(required string errorCode) output=false {
    var candidate = uCase(trim(arguments.errorCode));
    if (!reFind("^[A-Z][A-Z0-9_]{0,63}$",candidate)) return "RECOVERY_SEND_FAILED";
    return candidate;
  }

  private struct function claimedResult(
    required query row,
    required string token,
    required string code,
    required boolean retry
  ) output=false {
    return {
      SUCCESS=true,
      CLAIMED=true,
      CODE=arguments.code,
      LEDGER_ID=val(arguments.row.id[1]),
      USER_ID=val(arguments.row.user_id[1]),
      STAGE=toString(arguments.row.recovery_stage[1]),
      CLAIM_TOKEN=arguments.token,
      ATTEMPT_COUNT=val(arguments.row.attempt_count[1]),
      RETRY=arguments.retry
    };
  }

  private struct function existingResult(required query row) output=false {
    var status = uCase(toString(arguments.row.status[1]));
    if (status EQ "SENT") return stateResult(arguments.row,"ALREADY_SENT");
    if (status EQ "CLAIMED") return stateResult(arguments.row,"ALREADY_CLAIMED");
    if (status EQ "FAILED") {
      var result = stateResult(arguments.row,"FAILED_PREVIOUSLY");
      result.CAN_RETRY = val(arguments.row.attempt_count[1]) LT variables.maxAttempts;
      return result;
    }
    return invalid("INVALID_LEDGER_STATE");
  }

  private struct function stateResult(required query row, required string code) output=false {
    return {
      SUCCESS=true,
      CLAIMED=false,
      CODE=arguments.code,
      LEDGER_ID=val(arguments.row.id[1]),
      USER_ID=val(arguments.row.user_id[1]),
      STAGE=toString(arguments.row.recovery_stage[1]),
      STATUS=uCase(toString(arguments.row.status[1])),
      ATTEMPT_COUNT=val(arguments.row.attempt_count[1]),
      CAN_RETRY=(uCase(toString(arguments.row.status[1])) EQ "FAILED"
        AND val(arguments.row.attempt_count[1]) LT variables.maxAttempts),
      CLAIMED_AT_UTC=dateText(arguments.row.claimed_at_utc[1]),
      SENT_AT_UTC=(isNull(arguments.row.sent_at_utc[1]) ? "" : dateText(arguments.row.sent_at_utc[1])),
      FAILED_AT_UTC=(isNull(arguments.row.failed_at_utc[1]) ? "" : dateText(arguments.row.failed_at_utc[1])),
      LAST_ERROR_CODE=(isNull(arguments.row.last_error_summary[1]) ? "" : toString(arguments.row.last_error_summary[1]))
    };
  }

  private string function dateText(required any value) output=false {
    if (!isDate(arguments.value)) return "";
    return dateTimeFormat(arguments.value,"yyyy-mm-dd'T'HH:nn:ss.l'Z'");
  }

  private struct function invalid(required string code) output=false {
    return {SUCCESS=false,CLAIMED=false,CODE=arguments.code};
  }
}
