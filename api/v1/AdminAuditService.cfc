component output="false" {

  variables.datasource = "fpw";

  public any function init(string datasource="fpw") output="false" {
    variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
    return this;
  }

  public void function record(
    required numeric actorUserId,
    required string action,
    required string targetType,
    string targetId="",
    required boolean success,
    string requestId="",
    struct previousValues={},
    struct newValues={},
    string reason=""
  ) output="false" {
    queryExecute(
      "INSERT INTO fpw_admin_audit_log (
         admin_user_id, admin_email, action, entity_type, entity_id,
         previous_values_json, new_values_json, reason,
         request_id, success, created_at_utc
       ) VALUES (
         :actorUserId, NULL, :action, :targetType, :targetId,
         :previousValues, :newValues, :reason,
         :requestId, :success, UTC_TIMESTAMP()
       )",
      {
        actorUserId = { value = val(arguments.actorUserId), cfsqltype = "cf_sql_integer" },
        action = { value = left(trim(arguments.action), 100), cfsqltype = "cf_sql_varchar" },
        targetType = { value = left(trim(arguments.targetType), 80), cfsqltype = "cf_sql_varchar" },
        targetId = { value = left(trim(arguments.targetId), 100), cfsqltype = "cf_sql_varchar", null = !len(trim(arguments.targetId)) },
        previousValues = { value = serializeJSON(arguments.previousValues), cfsqltype = "cf_sql_longvarchar", null = !structCount(arguments.previousValues) },
        newValues = { value = serializeJSON(arguments.newValues), cfsqltype = "cf_sql_longvarchar", null = !structCount(arguments.newValues) },
        reason = { value = left(trim(arguments.reason), 500), cfsqltype = "cf_sql_varchar", null = !len(trim(arguments.reason)) },
        requestId = { value = left(trim(arguments.requestId), 64), cfsqltype = "cf_sql_varchar", null = !len(trim(arguments.requestId)) },
        success = { value = arguments.success ? 1 : 0, cfsqltype = "cf_sql_tinyint" }
      },
      { datasource = variables.datasource }
    );
  }
}

