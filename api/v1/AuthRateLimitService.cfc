component output=false {
  variables.datasource = "fpw";

  public any function init(string datasource="fpw") {
    variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
    return this;
  }

  public struct function getPolicies() {
    return {
      authenticate={ip={seconds=900,volume=100,failures=0},ip_account={seconds=900,volume=0,failures=10},account={seconds=900,volume=0,failures=20}},
      create_account={ip={seconds=3600,volume=5,failures=0},ip_account={seconds=3600,volume=3,failures=0}},
      reset_request={ip={seconds=3600,volume=20,failures=0},account={seconds=3600,volume=3,failures=0}},
      reset_confirm={ip={seconds=900,volume=30,failures=0},ip_account={seconds=900,volume=0,failures=10},account={seconds=900,volume=0,failures=20}},
      change_password={ip={seconds=3600,volume=60,failures=0},ip_account={seconds=900,volume=0,failures=5},account={seconds=900,volume=0,failures=10}}
    };
  }

  // No raw email or address enters storage or the internal completion ticket.
  public array function buildBuckets(required string actionGroup, string normalizedEmail="", string clientIp="", boolean includeIp=true) {
    var policies = getPolicies();
    if (!structKeyExists(policies, arguments.actionGroup)
        || !len(arguments.clientIp) || len(arguments.clientIp) > 45
        || !reFind("^[0-9A-Fa-f:.]+$", arguments.clientIp)) {
      throw(type="FPW.AuthRate.InvalidSubject", message="Invalid authentication rate-limit subject.");
    }
    var email = lCase(trim(arguments.normalizedEmail));
    var ip = lCase(trim(arguments.clientIp));
    if (len(email) > 255 || (!arguments.includeIp && !len(email))) {
      throw(type="FPW.AuthRate.InvalidSubject", message="Invalid authentication rate-limit subject.");
    }
    var buckets = [];
    for (var scope in ["account", "ip", "ip_account"]) {
      if (!structKeyExists(policies[arguments.actionGroup], scope)
          || (scope == "ip" && !arguments.includeIp)
          || (scope != "ip" && !len(email))) continue;
      // Length-prefix tuple fields: ColdFusion chr(0) may collapse to an empty delimiter.
      var material = scope == "ip" ? len(ip) & ":" & ip
        : (scope == "account" ? len(email) & ":" & email : len(ip) & ":" & ip & len(email) & ":" & email);
      var rule = policies[arguments.actionGroup][scope];
      arrayAppend(buckets, {
        actionGroup=arguments.actionGroup, scope=scope,
        subjectHash=lCase(hash("fpw-auth-rate-v2|" & scope & "|" & material, "SHA-256", "UTF-8")),
        seconds=rule.seconds, volumeLimit=rule.volume, failureLimit=rule.failures
      });
    }
    return buckets;
  }

  public struct function admit(required string actionGroup, string normalizedEmail="", string clientIp="", boolean includeIp=true) {
    var response = unavailable();
    try {
      var buckets = buildBuckets(argumentCollection=arguments);
      if (!isSchemaReady()) return response;
      var reservations = [];
      var retryAfter = 0;
      // All callers lock buckets in the same scope order. Never run PBKDF2 or email in this transaction.
      transaction {
        for (var bucket in buckets) {
          var params = bucketParams(bucket);
          params.seconds = {value=bucket.seconds,cfsqltype="cf_sql_integer"};
          queryExecute(
            "INSERT INTO auth_rate_counters
              (action_group,subject_scope,subject_hash,window_started_at_utc,expires_at_utc,admitted_count,failure_count,inflight_count)
             VALUES (:actionGroup,:scope,UNHEX(:subjectHash),UTC_TIMESTAMP(6),TIMESTAMPADD(SECOND,:seconds,UTC_TIMESTAMP(6)),0,0,0)
             ON DUPLICATE KEY UPDATE subject_hash=auth_rate_counters.subject_hash",
            params, {datasource=variables.datasource});
          var locked = queryExecute(
            "SELECT admitted_count,failure_count,inflight_count,
                    expires_at_utc <= UTC_TIMESTAMP(6) AS expired,
                    DATE_FORMAT(window_started_at_utc,'%Y-%m-%d %H:%i:%s.%f') AS window_key,
                    GREATEST(1,CEIL(TIMESTAMPDIFF(MICROSECOND,UTC_TIMESTAMP(6),expires_at_utc)/1000000)) AS retry_seconds
             FROM auth_rate_counters WHERE action_group=:actionGroup AND subject_scope=:scope AND subject_hash=UNHEX(:subjectHash)
             FOR UPDATE", bucketParams(bucket), {datasource=variables.datasource});
          if (locked.expired[1]) {
            queryExecute(
              "UPDATE auth_rate_counters SET window_started_at_utc=UTC_TIMESTAMP(6),
                expires_at_utc=TIMESTAMPADD(SECOND,:seconds,UTC_TIMESTAMP(6)),
                admitted_count=0,failure_count=0,inflight_count=0
               WHERE action_group=:actionGroup AND subject_scope=:scope AND subject_hash=UNHEX(:subjectHash)",
              params, {datasource=variables.datasource});
            locked = queryExecute(
              "SELECT admitted_count,failure_count,inflight_count,
                 DATE_FORMAT(window_started_at_utc,'%Y-%m-%d %H:%i:%s.%f') AS window_key,
                 GREATEST(1,CEIL(TIMESTAMPDIFF(MICROSECOND,UTC_TIMESTAMP(6),expires_at_utc)/1000000)) AS retry_seconds
               FROM auth_rate_counters WHERE action_group=:actionGroup AND subject_scope=:scope AND subject_hash=UNHEX(:subjectHash)",
              bucketParams(bucket), {datasource=variables.datasource});
          }
          if ((bucket.volumeLimit > 0 && locked.admitted_count[1] >= bucket.volumeLimit)
              || (bucket.failureLimit > 0 && locked.failure_count[1] + locked.inflight_count[1] >= bucket.failureLimit)) {
            retryAfter = max(retryAfter, val(locked.retry_seconds[1]));
          }
          bucket.windowKey = toString(locked.window_key[1]);
          arrayAppend(reservations, bucket);
        }
        if (retryAfter == 0) {
          for (var reserved in reservations) {
            queryExecute(
              "UPDATE auth_rate_counters SET admitted_count=admitted_count+1,inflight_count=inflight_count+1
               WHERE action_group=:actionGroup AND subject_scope=:scope AND subject_hash=UNHEX(:subjectHash)",
              bucketParams(reserved), {datasource=variables.datasource});
          }
          response = {ALLOWED=true,STATUSCODE=200,CODE="",MESSAGE="",RETRYAFTER=0,
            TICKET={buckets=reservations,completed=false}};
        } else {
          response = {ALLOWED=false,STATUSCODE=429,CODE="AUTH_RATE_LIMITED",
            MESSAGE="Please wait before trying again.",RETRYAFTER=retryAfter,TICKET={}};
        }
      }
    } catch (any ignored) {
      // Missing/incompatible schema, contention, and DB outages must never bypass admission.
      response = unavailable();
    }
    cleanupExpired();
    return response;
  }

  // Internal ticket only: never accept tickets from the browser or serialize them into a response.
  public boolean function finish(required struct ticket, string outcome="error") {
    if (!structKeyExists(arguments.ticket, "buckets") || !isArray(arguments.ticket.buckets)
        || !structKeyExists(arguments.ticket, "completed") || arguments.ticket.completed
        || !listFind("failure,success,error", arguments.outcome)) return false;
    arguments.ticket.completed = true;
    try {
      transaction {
        for (var bucket in arguments.ticket.buckets) {
          var params = bucketParams(bucket);
          params.windowKey = {value=bucket.windowKey,cfsqltype="cf_sql_varchar"};
          // Guard unsigned subtraction before evaluating it; GREATEST cannot catch MySQL underflow.
          var failureChange = arguments.outcome == "failure" ? "failure_count+1"
            : (arguments.outcome == "success" ? "CASE WHEN failure_count > 0 THEN failure_count-1 ELSE 0 END" : "failure_count");
          queryExecute(
            "UPDATE auth_rate_counters SET inflight_count=CASE WHEN inflight_count > 0 THEN inflight_count-1 ELSE 0 END,
              failure_count=" & failureChange & "
             WHERE action_group=:actionGroup AND subject_scope=:scope AND subject_hash=UNHEX(:subjectHash)
               AND window_started_at_utc=CAST(:windowKey AS DATETIME(6))
               AND expires_at_utc>UTC_TIMESTAMP(6)",
            params, {datasource=variables.datasource});
        }
      }
      return true;
    } catch (any ignored) {
      // An unreleased reservation expires with its fixed window; it never locks an account permanently.
      return false;
    }
  }

  public boolean function isSchemaReady() {
    var schema = queryExecute(
      "SELECT
        (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE()
          AND TABLE_NAME='auth_rate_counters' AND ENGINE='InnoDB') AS table_ok,
        (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE()
          AND TABLE_NAME='auth_rate_counters'
          AND COLUMN_NAME IN ('action_group','subject_scope','subject_hash','window_started_at_utc',
            'expires_at_utc','admitted_count','failure_count','inflight_count') AND IS_NULLABLE='NO') AS columns_ok,
        (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE()
          AND TABLE_NAME='auth_rate_counters' AND INDEX_NAME='PRIMARY') AS primary_width,
        (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE()
          AND TABLE_NAME='auth_rate_counters' AND INDEX_NAME='PRIMARY'
          AND ((SEQ_IN_INDEX=1 AND COLUMN_NAME='action_group') OR (SEQ_IN_INDEX=2 AND COLUMN_NAME='subject_scope')
            OR (SEQ_IN_INDEX=3 AND COLUMN_NAME='subject_hash'))) AS primary_ok,
        (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE()
          AND TABLE_NAME='auth_rate_counters' AND INDEX_NAME='ix_auth_rate_expiry'
          AND SEQ_IN_INDEX=1 AND COLUMN_NAME='expires_at_utc') AS expiry_ok",
      {}, {datasource=variables.datasource});
    return schema.table_ok[1] == 1 && schema.columns_ok[1] == 8 && schema.primary_width[1] == 3 && schema.primary_ok[1] == 3 && schema.expiry_ok[1] == 1;
  }

  private struct function bucketParams(required struct bucket) {
    return {
      actionGroup={value=arguments.bucket.actionGroup,cfsqltype="cf_sql_varchar"},
      scope={value=arguments.bucket.scope,cfsqltype="cf_sql_varchar"},
      subjectHash={value=arguments.bucket.subjectHash,cfsqltype="cf_sql_varchar"}
    };
  }

  private void function cleanupExpired() {
    try {
      // Bounded request-driven retention: idle sites clean up on their next authentication request.
      queryExecute("DELETE FROM auth_rate_counters WHERE expires_at_utc < TIMESTAMPADD(HOUR,-24,UTC_TIMESTAMP(6))
                    ORDER BY expires_at_utc LIMIT 200", {}, {datasource=variables.datasource});
    } catch (any ignored) { }
  }

  private struct function unavailable() {
    return {ALLOWED=false,STATUSCODE=503,CODE="AUTH_TEMPORARILY_UNAVAILABLE",
      MESSAGE="Please try again shortly.",RETRYAFTER=30,TICKET={}};
  }
}
