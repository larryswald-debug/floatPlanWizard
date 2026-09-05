component output="false" {

  // Pure policy only. The caller must supply freshly verified, durable evidence.
  // An ELIGIBLE result is not a send claim or authorization to deliver an email.
  public struct function evaluate(any evidence = {}) {
    var input = arguments.evidence;
    if (!isStruct(input)) return decision("HELD", "INVALID_EVIDENCE");

    // Positive sharing evidence always suppresses recovery, including after deletion.
    if (booleanField(input, "has_successful_share", true)
      || textField(input, "stage", "Shared")
      || textField(input, "highest_verified_stage", "Shared")) {
      return decision("SUPPRESSED", "SHARED");
    }
    if (!booleanField(input, "account_exists", true)) return decision("HELD", "ACCOUNT_NOT_VERIFIED");
    if (!structKeyExists(input, "verification") || !isStruct(input.verification)) {
      return decision("HELD", "INCOMPLETE_VERIFICATION");
    }
    for (var proof in ["stage_history", "activity_coverage", "sharing_history", "recovery_history", "ownership", "lifecycle"]) {
      if (!booleanField(input.verification, proof, true)) return decision("HELD", "INCOMPLETE_VERIFICATION");
    }
    if (!booleanField(input, "has_successful_share", false)) return decision("HELD", "SHARING_NOT_VERIFIED");

    var stage = stageRank(input, "stage");
    var highestStage = stageRank(input, "highest_verified_stage");
    if (stage == 0 || highestStage == 0) return decision("HELD", "STAGE_NOT_VERIFIED");
    if (stage != highestStage) return decision("HELD", "STAGE_HISTORY_CONFLICT");

    if (!structKeyExists(input, "exclusions") || !isStruct(input.exclusions)) {
      return decision("HELD", "EXCLUSIONS_NOT_VERIFIED");
    }
    for (var exclusion in ["opt_out", "administrator_or_test", "invalid_recipient", "active_trip_or_monitoring", "contradictory_lifecycle", "other"]) {
      if (booleanField(input.exclusions, exclusion, true)) return decision("SUPPRESSED", "EXCLUSION_APPLIES");
      if (!booleanField(input.exclusions, exclusion, false)) return decision("HELD", "EXCLUSIONS_NOT_VERIFIED");
    }

    if (textField(input, "current_stage_recovery", "sent")) return decision("SUPPRESSED", "STAGE_ALREADY_SENT");
    if (textField(input, "current_stage_recovery", "possibly_sent")) return decision("HELD", "STAGE_SEND_UNRESOLVED");
    if (!textField(input, "current_stage_recovery", "never_sent")) return decision("HELD", "STAGE_SEND_HISTORY_UNKNOWN");

    var nowClock = utcClock(input, "now_utc");
    var enrollmentClock = utcClock(input, "enrollment_utc");
    var stageClock = utcClock(input, "current_stage_entered_utc");
    if (!nowClock.valid || !enrollmentClock.valid || !stageClock.valid) return decision("HELD", "INVALID_UTC_CLOCK");
    if (enrollmentClock.seconds > nowClock.seconds || stageClock.seconds > nowClock.seconds) {
      return decision("HELD", "FUTURE_CLOCK");
    }
    var anchor = max(enrollmentClock.seconds, stageClock.seconds);

    if (!structKeyExists(input, "latest_activity") || !isStruct(input.latest_activity)) {
      return decision("HELD", "ACTIVITY_HISTORY_UNKNOWN");
    }
    if (textField(input.latest_activity, "state", "recorded")) {
      if (!structKeyExists(input.latest_activity, "action") || !isQualifyingActivity(input.latest_activity.action)) {
        return decision("HELD", "ACTIVITY_NOT_QUALIFYING");
      }
      var activityClock = utcClock(input.latest_activity, "at_utc");
      if (!activityClock.valid) return decision("HELD", "INVALID_UTC_CLOCK");
      if (activityClock.seconds > nowClock.seconds) return decision("HELD", "FUTURE_CLOCK");
      anchor = max(anchor, activityClock.seconds);
    } else if (!textField(input.latest_activity, "state", "none_verified")) {
      return decision("HELD", "ACTIVITY_HISTORY_UNKNOWN");
    } else if (structKeyExists(input.latest_activity, "at_utc") || structKeyExists(input.latest_activity, "action")) {
      return decision("HELD", "ACTIVITY_HISTORY_CONFLICT");
    }

    if (!structKeyExists(input, "last_recovery") || !isStruct(input.last_recovery)) {
      return decision("HELD", "RECOVERY_HISTORY_UNKNOWN");
    }
    // An unresolved attempt at any stage cannot establish safe cross-stage spacing.
    if (textField(input.last_recovery, "state", "possibly_sent")) return decision("HELD", "RECOVERY_SEND_UNRESOLVED");
    if (textField(input.last_recovery, "state", "sent")) {
      var lastStage = stageRank(input.last_recovery, "stage");
      var sentClock = utcClock(input.last_recovery, "at_utc");
      if (!sentClock.valid) return decision("HELD", "INVALID_UTC_CLOCK");
      if (sentClock.seconds > nowClock.seconds) return decision("HELD", "FUTURE_CLOCK");
      if (lastStage == 0 || lastStage >= stage) {
        return decision("HELD", "RECOVERY_HISTORY_CONFLICT");
      }
      anchor = max(anchor, sentClock.seconds);
    } else if (!textField(input.last_recovery, "state", "never_sent")) {
      return decision("HELD", "RECOVERY_HISTORY_UNKNOWN");
    } else if (structKeyExists(input.last_recovery, "at_utc") || structKeyExists(input.last_recovery, "stage")) {
      return decision("HELD", "RECOVERY_HISTORY_CONFLICT");
    }

    var eligibleAt = anchor + 604800;
    var result = nowClock.seconds >= eligibleAt
      ? decision("ELIGIBLE", "INTERVAL_ELAPSED")
      : decision("DEFERRED", "WAITING_FOR_INTERVAL");
    result.anchor_utc = epochToUtc(anchor);
    result.eligible_at_utc = epochToUtc(eligibleAt);
    result.seconds_until_eligible = max(0, eligibleAt - nowClock.seconds);
    return result;
  }

  // Classifies an already verified action, not a browser event or database row.
  public boolean function isQualifyingActivity(any action = {}) {
    var input = arguments.action;
    if (!isStruct(input)) return false;
    for (var proof in ["successful", "member_initiated", "owned", "persisted"]) {
      if (!booleanField(input, proof, true)) return false;
    }
    var entityAllowed = false;
    for (var entity in ["vessel", "shore_contact", "operator", "passenger", "saved_waypoint", "route", "route_leg", "draft", "draft_contacts"]) {
      if (textField(input, "entity", entity)) entityAllowed = true;
    }
    if (!entityAllowed) return false;
    return textField(input, "operation", "create")
      || (textField(input, "operation", "save") && booleanField(input, "changed", true));
  }

  private struct function decision(required string state, required string reason) {
    return {
      eligible = arguments.state == "ELIGIBLE",
      decision = arguments.state,
      reason = arguments.reason,
      interval_seconds = 604800
    };
  }

  // Do not coerce "yes", "true", 1, or other truthy values into verified proof.
  private boolean function booleanField(required struct input, required string key, required boolean expected) {
    if (!structKeyExists(arguments.input, arguments.key) || !isSimpleValue(arguments.input[arguments.key])) return false;
    return compare(serializeJSON(arguments.input[arguments.key]), arguments.expected ? "true" : "false") == 0;
  }

  private boolean function textField(required struct input, required string key, required string expected) {
    return structKeyExists(arguments.input, arguments.key)
      && isSimpleValue(arguments.input[arguments.key])
      && compare(toString(arguments.input[arguments.key]), arguments.expected) == 0;
  }

  private numeric function stageRank(required struct input, required string key) {
    var stages = ["A", "B", "C", "D"];
    for (var index = 1; index <= arrayLen(stages); index++) {
      if (textField(arguments.input, arguments.key, stages[index])) return index;
    }
    return 0;
  }

  // Accept only canonical, whole-second UTC instants. No server/local timezone use.
  private struct function utcClock(required struct input, required string key) {
    var result = {valid = false};
    if (!structKeyExists(arguments.input, arguments.key) || !isSimpleValue(arguments.input[arguments.key])) return result;
    var value = toString(arguments.input[arguments.key]);
    if (!reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", value)) return result;
    try {
      var instant = createObject("java", "java.time.Instant").parse(value);
      if (compare(instant.toString(), value) != 0) return result;
      result.valid = true;
      result.seconds = instant.getEpochSecond();
    } catch (any invalidClock) {
      return result;
    }
    return result;
  }

  private string function epochToUtc(required numeric seconds) {
    return createObject("java", "java.time.Instant").ofEpochSecond(javaCast("long", arguments.seconds)).toString();
  }
}
