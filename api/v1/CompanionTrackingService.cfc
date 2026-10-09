component output="false" {
  variables.datasource = "fpw";
  variables.dayMs = 86400000;
  // Independent tracking policies; no global retention or operational lifecycle coupling.
  variables.sampleRetentionDays = 90;
  variables.closedSessionRetentionDays = 90;

  public any function init(string datasource="fpw") {
    variables.datasource = arguments.datasource;
    return this;
  }

  // Internal service entry point. Only companionTracking.handle is remote.
  public struct function handle(required string action, required struct authContext, struct payload={}) {
    var actionName = lCase(arguments.action);
    var result = {};
    if (!structKeyExists(arguments.authContext, "SUCCESS") || !arguments.authContext.SUCCESS
        || !structKeyExists(arguments.authContext, "userId") || !structKeyExists(arguments.authContext, "companionDeviceId")) {
      return failure("TOKEN_INVALID", "A paired-device bearer is required.", 401, false);
    }
    if (!listFind("eligibility,start,batch,status,stop,finish,latest", actionName)) {
      return failure("INVALID_ACTION", "Unsupported tracking action.", 400);
    }
    try {
      if (listFind("eligibility,status,latest", actionName)) {
        return dispatch(actionName, arguments.authContext, arguments.payload, false);
      }
      // Lock order is user, device, receipts, plans, routes, entitlements, credits, session.
      // Locking reads precede access evaluation, so revocation cannot race an insert.
      transaction isolation="repeatable_read" {
        lockMember(arguments.authContext.userId);
        result = dispatch(actionName, arguments.authContext, arguments.payload, true);
      }
      return result;
    } catch (any storageError) {
      // Never return partial ACK arrays after a rolled-back write, or log GPS/bearers.
      writeLog(file="companion-tracking", type="error", text="TRACKING_STORAGE_FAILURE action=" & actionName
        & " userId=" & val(arguments.authContext.userId) & " deviceId=" & val(arguments.authContext.companionDeviceId));
      return failure("STORAGE_UNAVAILABLE", "Tracking storage is temporarily unavailable. Retry the same request.", 503);
    }
  }

  private struct function dispatch(required string actionName, required struct auth, required struct payload, required boolean forUpdate) {
    var device = deviceEvidence(arguments.auth, arguments.forUpdate);
    if (!device.SUCCESS) return device;
    if (arguments.forUpdate) lockOperationalEvidence(arguments.auth.userId);
    var clockMs = databaseNowMs();
    if (clockMs >= min(device.expiresMs, device.inactivityMs)) {
      return failure("TOKEN_EXPIRED", "Companion credential has expired. Re-pair this device.", 401, false);
    }
    var trip = tripEvidence(arguments.auth.userId);
    if (arguments.actionName == "eligibility") {
      if (!trip.SUCCESS) return trip;
      var eligible = success();
      eligible["eligible"] = true;
      eligible["floatPlanId"] = toString(trip.floatPlanId);
      eligible["routeInstanceId"] = toString(trip.routeInstanceId);
      eligible["authorizationValidUntilUtc"] = iso(authorizationDeadline(device, trip, clockMs));
      eligible["serverTimeUtc"] = iso(clockMs);
      return eligible;
    }
    if (arguments.actionName == "start") return startSession(arguments.auth, arguments.payload, device, trip, clockMs);
    if (!validId(arguments.payload, "trackingSessionId")) return failure("INVALID_SESSION_ID", "A tracking session ID is required.", 400);
    var sessionRow = loadSession(arguments.payload.trackingSessionId, arguments.auth, arguments.forUpdate);
    if (!sessionRow.recordCount) return failure("SESSION_NOT_FOUND", "Tracking session is unavailable.", 404);
    var sessionData = sessionResponse(sessionRow, clockMs);
    var eligibility = sessionEligibility(sessionRow, trip, clockMs);
    if (arguments.actionName == "status") {
      sessionData["storedSessionStatus"] = sessionData.sessionStatus;
      sessionData["eligible"] = eligibility.SUCCESS && sessionRow.status[1] != "CLOSED";
      sessionData["authorizationReason"] = !eligibility.SUCCESS ? eligibility.ERROR : (sessionRow.status[1] == "CLOSED" ? "SESSION_CLOSED" : "AUTHORIZED");
      if (!eligibility.SUCCESS) sessionData["sessionStatus"] = "CLOSED";
      return sessionData;
    }
    if (!eligibility.SUCCESS) {
      if (arguments.forUpdate && sessionRow.status[1] != "CLOSED") closeSession(sessionRow.id[1], eligibility.ERROR);
      eligibility["sessionStatus"] = "CLOSED";
      return eligibility;
    }
    if (arguments.actionName == "latest") return latestSample(sessionRow, clockMs);
    if (arguments.actionName == "stop") return stopSession(sessionRow, arguments.payload, clockMs);
    if (arguments.actionName == "finish") {
      if (sessionRow.status[1] == "ACTIVE") return failure("STOP_REQUIRED", "Stop collection before finishing its backlog.", 409);
      if (sessionRow.status[1] != "CLOSED") closeSession(sessionRow.id[1], "CAPTAIN_FINISHED");
      markUsed(arguments.auth.companionDeviceId);
      return sessionResponse(loadSession(sessionRow.id[1], arguments.auth, false), clockMs);
    }
    if (sessionRow.status[1] == "CLOSED") return failure("SESSION_CLOSED", "The tracking session is closed.", 409);
    return ingestBatch(sessionRow, arguments.payload, clockMs);
  }

  private void function lockMember(required numeric userId) {
    sql("SELECT userId FROM users WHERE userId=:uid FOR UPDATE", {uid=p(arguments.userId, "integer")});
  }

  private void function lockOperationalEvidence(required numeric userId) {
    var params = {uid=p(arguments.userId, "integer"), uidText=p(toString(arguments.userId))};
    sql("SELECT id FROM premium_send_receipts WHERE user_id=:uid ORDER BY id FOR UPDATE", params);
    sql("SELECT floatPlanId FROM floatplans WHERE userId=:uidText ORDER BY floatPlanId FOR UPDATE", params);
    sql("SELECT id FROM route_instances WHERE user_id=:uidText ORDER BY id FOR UPDATE", params);
    sql("SELECT id FROM member_entitlements WHERE user_id=:uid ORDER BY id FOR UPDATE", params);
    sql("SELECT id FROM premium_send_credits WHERE user_id=:uid ORDER BY id FOR UPDATE", params);
  }

  private struct function deviceEvidence(required struct auth, boolean forUpdate=false) {
    var q = sql("SELECT id, user_id, scopes, token_prefix,
        CASE WHEN revoked_at_utc IS NOT NULL THEN 1 ELSE 0 END AS revoked,
        CASE WHEN expires_at_utc <= UTC_TIMESTAMP(3)
          OR COALESCE(last_used_at_utc,created_utc) < DATE_SUB(UTC_TIMESTAMP(3), INTERVAL 30 DAY) THEN 1 ELSE 0 END AS expired,
        DATE_FORMAT(expires_at_utc,'%Y-%m-%dT%H:%i:%s.%fZ') AS expiry_iso,
        DATE_FORMAT(DATE_ADD(COALESCE(last_used_at_utc,created_utc), INTERVAL 30 DAY),'%Y-%m-%dT%H:%i:%s.%fZ') AS inactivity_iso
      FROM companion_devices WHERE id=:did AND user_id=:uid" & (arguments.forUpdate ? " FOR UPDATE" : ""),
      {did=p(arguments.auth.companionDeviceId,"bigint"),uid=p(arguments.auth.userId,"integer")});
    if (!q.recordCount) return failure("TOKEN_INVALID", "Companion device is unavailable.", 401, false);
    if (q.revoked[1]) return failure("TOKEN_REVOKED", "Companion credential has been revoked.", 401, false);
    if (q.expired[1]) return failure("TOKEN_EXPIRED", "Companion credential has expired. Re-pair this device.", 401, false);
    if (structKeyExists(arguments.auth,"tokenPrefix") && compare(arguments.auth.tokenPrefix,q.token_prefix[1])) {
      return failure("TOKEN_INVALID", "Companion credential is unavailable.", 401, false);
    }
    if (!listFindNoCase(q.scopes[1],"companion:tracking")) {
      var denied = failure("REPAIR_REQUIRED", "Re-pair this device to enable automatic tracking.", 403, false);
      denied["rePairRequired"] = true;
      return denied;
    }
    return {SUCCESS=true, expiresMs=instantMs(q.expiry_iso[1]), inactivityMs=instantMs(q.inactivity_iso[1])};
  }

  private struct function tripEvidence(required numeric userId) {
    var q = sql("SELECT fp.floatPlanId, fp.route_instance_id
      FROM floatplans fp INNER JOIN route_instances ri ON ri.id=fp.route_instance_id AND ri.user_id=:uidText
      WHERE fp.userId=:uidText AND UPPER(TRIM(fp.status))='ACTIVE'
      ORDER BY fp.floatPlanId LIMIT 2", {uidText=p(toString(arguments.userId))});
    if (!q.recordCount) return failure("NO_ELIGIBLE_TRIP", "No active route-backed trip is eligible for tracking.", 409);
    if (q.recordCount != 1) return failure("MULTIPLE_ACTIVE_TRIPS", "Resolve the multiple active trips before tracking.", 409);
    // false is essential: this path must never expire trips or touch monitoring.
    var access = apiComponent("PremiumTripAccessService").init(variables.datasource)
      .getTripOperationalAccess(arguments.userId, q.floatPlanId[1], false);
    if (!access.allowed) return failure(access.reasonCode, "This trip is not currently authorized for tracking.", 409);
    var result = {SUCCESS=true,floatPlanId=q.floatPlanId[1],routeInstanceId=q.route_instance_id[1],access=access,accessDeadlineMs=0};
    if (access.accessSource == "premium_send_credit" && !access.membershipOverrideActive) {
      var receipt = sql("SELECT DATE_FORMAT(access_expires_at_utc,'%Y-%m-%dT%H:%i:%s.%fZ') AS expiry_iso
        FROM premium_send_receipts WHERE user_id=:uid AND float_plan_id=:fid", {uid=p(arguments.userId,"integer"),fid=p(q.floatPlanId[1],"integer")});
      result.accessDeadlineMs = instantMs(receipt.expiry_iso[1]);
    } else {
      // A conservative known membership boundary. NULL denotes no known expiry.
      // For an override, using the earliest active Premium expiry cannot extend authority.
      var entitlements = sql("SELECT DATE_FORMAT(MIN(expires_at_utc),'%Y-%m-%dT%H:%i:%s.%fZ') AS expiry_iso
        FROM member_entitlements WHERE user_id=:uid AND entitlement_type='premium' AND status='active'
          AND starts_at_utc<=UTC_TIMESTAMP(3) AND (expires_at_utc IS NULL OR expires_at_utc>UTC_TIMESTAMP(3))",
        {uid=p(arguments.userId,"integer")});
      if (!isNull(entitlements.expiry_iso[1]) && len(entitlements.expiry_iso[1])) result.accessDeadlineMs = instantMs(entitlements.expiry_iso[1]);
    }
    return result;
  }

  private numeric function authorizationDeadline(required struct device, required struct trip, required numeric clockMs) {
    var deadline = min(arguments.clockMs + 7*variables.dayMs, min(arguments.device.expiresMs, arguments.device.inactivityMs));
    if (arguments.trip.accessDeadlineMs > 0) deadline = min(deadline, arguments.trip.accessDeadlineMs);
    return deadline;
  }

  private struct function startSession(required struct auth, required struct payload, required struct device, required struct trip, required numeric clockMs) {
    if (!validUUID(arguments.payload,"clientSessionId") || !validId(arguments.payload,"floatPlanId") || !validId(arguments.payload,"routeInstanceId")
        || !structKeyExists(arguments.payload,"consentVersion") || !isSimpleValue(arguments.payload.consentVersion)
        || !reFind("^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$",toString(arguments.payload.consentVersion))) {
      return failure("INVALID_START", "Start requires a session UUID, canonical trip IDs, and consent version.", 400);
    }
    if (!arguments.trip.SUCCESS) return arguments.trip;
    if (toString(arguments.trip.floatPlanId) != toString(arguments.payload.floatPlanId) || toString(arguments.trip.routeInstanceId) != toString(arguments.payload.routeInstanceId)) {
      return failure("TRIP_CONTEXT_CONFLICT", "The requested trip is not the current eligible trip.", 409);
    }
    var existing = sql("SELECT id,floatplan_id,route_instance_id,consent_version FROM companion_tracking_sessions
      WHERE companion_device_id=:did AND client_session_id=:uuid FOR UPDATE",
      {did=p(arguments.auth.companionDeviceId,"bigint"),uuid=p(lCase(arguments.payload.clientSessionId))});
    if (existing.recordCount) {
      if (existing.floatplan_id[1] != arguments.trip.floatPlanId || existing.route_instance_id[1] != arguments.trip.routeInstanceId
          || compare(existing.consent_version[1],arguments.payload.consentVersion)) {
        return failure("SESSION_ID_CONFLICT", "That client session UUID is already bound to different context.", 409);
      }
      var prior = loadSession(existing.id[1],arguments.auth,true);
      var priorEligibility = sessionEligibility(prior,arguments.trip,arguments.clockMs);
      if (!priorEligibility.SUCCESS && prior.status[1] != "CLOSED") closeSession(prior.id[1],priorEligibility.ERROR);
      return sessionResponse(loadSession(existing.id[1],arguments.auth,false),arguments.clockMs);
    }
    // Reconcile only tracking state while releasing stale collection slots.
    var active = sql("SELECT id,user_id,companion_device_id FROM companion_tracking_sessions
      WHERE user_id=:uid AND status='ACTIVE' ORDER BY id FOR UPDATE",{uid=p(arguments.auth.userId,"integer")});
    for (var i=1;i<=active.recordCount;i++) {
      var owner = {userId=active.user_id[i],companionDeviceId=active.companion_device_id[i]};
      var activeRow = loadSession(active.id[i],owner,true);
      var activeDevice = deviceEvidence(owner,true);
      var activeEligibility = activeDevice.SUCCESS ? sessionEligibility(activeRow,arguments.trip,arguments.clockMs) : activeDevice;
      if (!activeEligibility.SUCCESS) closeSession(active.id[i],activeEligibility.ERROR);
    }
    var occupied = sql("SELECT id FROM companion_tracking_sessions WHERE status='ACTIVE'
      AND (companion_device_id=:did OR floatplan_id=:fid) LIMIT 1 FOR UPDATE",
      {did=p(arguments.auth.companionDeviceId,"bigint"),fid=p(arguments.trip.floatPlanId,"integer")});
    if (occupied.recordCount) return failure("TRACKING_ALREADY_ACTIVE", "An active collecting session already occupies this device or trip.", 409);
    var deadline = authorizationDeadline(arguments.device,arguments.trip,arguments.clockMs);
    if (deadline <= arguments.clockMs) return failure("AUTHORIZATION_EXPIRED", "Tracking authorization has expired.", 409);
    sql("INSERT INTO companion_tracking_sessions
        (client_session_id,user_id,companion_device_id,floatplan_id,route_instance_id,status,started_at_utc,
         authorization_valid_until_utc,consent_version,created_utc,updated_utc)
      VALUES (:uuid,:uid,:did,:fid,:rid,'ACTIVE',:started,:deadline,:consent,UTC_TIMESTAMP(3),UTC_TIMESTAMP(3))",
      {uuid=p(lCase(arguments.payload.clientSessionId)),uid=p(arguments.auth.userId,"integer"),did=p(arguments.auth.companionDeviceId,"bigint"),
       fid=p(arguments.trip.floatPlanId,"integer"),rid=p(arguments.trip.routeInstanceId,"integer"),started=p(sqlUtc(iso(arguments.clockMs))),
       deadline=p(sqlUtc(iso(deadline))),consent=p(arguments.payload.consentVersion)});
    var created = sql("SELECT id FROM companion_tracking_sessions WHERE companion_device_id=:did AND client_session_id=:uuid",
      {did=p(arguments.auth.companionDeviceId,"bigint"),uuid=p(lCase(arguments.payload.clientSessionId))});
    markUsed(arguments.auth.companionDeviceId);
    return sessionResponse(loadSession(created.id[1],arguments.auth,false),arguments.clockMs);
  }

  private query function loadSession(required any sessionId, required struct auth, boolean forUpdate=false) {
    return sql("SELECT s.*,
        DATE_FORMAT(started_at_utc,'%Y-%m-%dT%H:%i:%s.%fZ') AS started_iso,
        DATE_FORMAT(authorization_valid_until_utc,'%Y-%m-%dT%H:%i:%s.%fZ') AS authorization_iso,
        DATE_FORMAT(capture_stopped_at_utc,'%Y-%m-%dT%H:%i:%s.%fZ') AS cutoff_iso,
        DATE_FORMAT(drain_until_utc,'%Y-%m-%dT%H:%i:%s.%fZ') AS drain_iso,
        DATE_FORMAT(closed_at_utc,'%Y-%m-%dT%H:%i:%s.%fZ') AS closed_iso
      FROM companion_tracking_sessions s WHERE id=:sid AND user_id=:uid AND companion_device_id=:did" & (arguments.forUpdate ? " FOR UPDATE" : ""),
      {sid=p(arguments.sessionId,"bigint"),uid=p(arguments.auth.userId,"integer"),did=p(arguments.auth.companionDeviceId,"bigint")});
  }

  private struct function sessionEligibility(required query row, required struct trip, required numeric clockMs) {
    if (!arguments.trip.SUCCESS) return arguments.trip;
    if (arguments.row.floatplan_id[1] != arguments.trip.floatPlanId || arguments.row.route_instance_id[1] != arguments.trip.routeInstanceId) {
      return failure("TRIP_INVALIDATED", "The session no longer belongs to the current eligible trip.", 409);
    }
    if (arguments.clockMs >= instantMs(arguments.row.authorization_iso[1])) return failure("AUTHORIZATION_EXPIRED", "The session authorization has expired.", 409);
    if (arguments.row.status[1] == "DRAINING" && arguments.clockMs >= instantMs(arguments.row.drain_iso[1])) {
      return failure("DRAIN_EXPIRED", "The backlog drain window has expired.", 409);
    }
    return success();
  }

  private struct function stopSession(required query row, required struct payload, required numeric clockMs) {
    // Once stopped the original cutoff/deadline is immutable, including retries.
    if (arguments.row.status[1] != "ACTIVE") return sessionResponse(arguments.row,arguments.clockMs);
    if (!structKeyExists(arguments.payload,"captureStoppedAtUtc") || !validTimestamp(arguments.payload.captureStoppedAtUtc)) {
      return failure("INVALID_STOP_CUTOFF", "A canonical UTC capture cutoff is required.", 400);
    }
    var cutoff = instantMs(arguments.payload.captureStoppedAtUtc);
    var bound = instantMs(arguments.row.authorization_iso[1]);
    if (cutoff < instantMs(arguments.row.started_iso[1]) || cutoff > arguments.clockMs+120000 || cutoff > bound) {
      return failure("INVALID_STOP_CUTOFF", "The cutoff must be within this session and the server clock tolerance.", 400);
    }
    var drain = min(bound, min(arguments.clockMs+variables.dayMs,cutoff+variables.dayMs));
    sql("UPDATE companion_tracking_sessions SET status='DRAINING',capture_stopped_at_utc=:cutoff,
      drain_until_utc=:drain,stop_reason='CAPTAIN_STOP',updated_utc=UTC_TIMESTAMP(3) WHERE id=:sid",
      {cutoff=p(sqlUtc(iso(cutoff))),drain=p(sqlUtc(iso(drain))),sid=p(arguments.row.id[1],"bigint")});
    if (drain <= arguments.clockMs) closeSession(arguments.row.id[1],"DRAIN_EXPIRED");
    var owner = {userId=arguments.row.user_id[1],companionDeviceId=arguments.row.companion_device_id[1]};
    markUsed(owner.companionDeviceId);
    return sessionResponse(loadSession(arguments.row.id[1],owner,false),arguments.clockMs);
  }

  private struct function ingestBatch(required query row, required struct payload, required numeric clockMs) {
    if (!validUUID(arguments.payload,"batchId") || !structKeyExists(arguments.payload,"samples") || !isArray(arguments.payload.samples)
        || arrayLen(arguments.payload.samples)<1) return failure("INVALID_BATCH", "A batch UUID and nonempty samples array are required.", 400);
    if (arrayLen(arguments.payload.samples)>100) return failure("BATCH_TOO_LARGE", "At most 100 samples are accepted per request.", 413);
    var result = sessionResponse(arguments.row,arguments.clockMs);
    result["batchId"] = lCase(arguments.payload.batchId);
    result["acceptedSampleIds"] = [];
    result["duplicateSampleIds"] = [];
    result["rejectedSamples"] = [];
    for (var i=1;i<=arrayLen(arguments.payload.samples);i++) {
      if (!arrayIsDefined(arguments.payload.samples,i) || isNull(arguments.payload.samples[i])) {
        arrayAppend(result.rejectedSamples,{"index"=i-1,"reason"="INVALID_SAMPLE"});
        continue;
      }
      var normalized = normalizeSample(arguments.payload.samples[i]);
      if (!normalized.SUCCESS) {
        var rejection = {"index"=i-1,"reason"=normalized.ERROR};
        if (isStruct(arguments.payload.samples[i]) && validUUID(arguments.payload.samples[i],"clientSampleId")) rejection["clientSampleId"] = lCase(arguments.payload.samples[i].clientSampleId);
        arrayAppend(result.rejectedSamples,rejection);
        continue;
      }
      var existing = sql("SELECT payload_hash FROM companion_location_samples WHERE tracking_session_id=:sid AND client_sample_id=:uuid",
        {sid=p(arguments.row.id[1],"bigint"),uuid=p(normalized.clientSampleId)});
      if (existing.recordCount) {
        if (compareNoCase(existing.payload_hash[1],normalized.payloadHash)==0) arrayAppend(result.duplicateSampleIds,normalized.clientSampleId);
        else arrayAppend(result.rejectedSamples,{"index"=i-1,"clientSampleId"=normalized.clientSampleId,"reason"="SAMPLE_ID_CONFLICT"});
      } else {
        var admissionError = captureAdmissionError(normalized,arguments.row,arguments.clockMs);
        if (len(admissionError)) {
          arrayAppend(result.rejectedSamples,{"index"=i-1,"clientSampleId"=normalized.clientSampleId,"reason"=admissionError});
          continue;
        }
        insertSampleRow(arguments.row.id[1],normalized);
        arrayAppend(result.acceptedSampleIds,normalized.clientSampleId);
      }
    }
    if (arrayLen(result.acceptedSampleIds)) {
      sql("UPDATE companion_tracking_sessions SET last_sample_captured_at_utc=
          (SELECT MAX(captured_at_utc) FROM companion_location_samples WHERE tracking_session_id=:sid),
          last_received_at_utc=UTC_TIMESTAMP(3),updated_utc=UTC_TIMESTAMP(3) WHERE id=:sid",{sid=p(arguments.row.id[1],"bigint")});
    }
    markUsed(arguments.row.companion_device_id[1]);
    return result;
  }

  // Public for a nonremote fault-injection subclass in transaction tests; never an API action.
  public void function insertSampleRow(required numeric trackingSessionId, required struct sample) {
    sql("INSERT INTO companion_location_samples
        (tracking_session_id,client_sample_id,latitude,longitude,accuracy_meters,speed_knots,course_degrees,captured_at_utc,received_at_utc,payload_hash)
      VALUES (:sid,:uuid,:lat,:lon,:accuracy,:speed,:course,:captured,UTC_TIMESTAMP(3),:hash)",
      {sid=p(arguments.trackingSessionId,"bigint"),uuid=p(arguments.sample.clientSampleId),lat=p(arguments.sample.latitude),lon=p(arguments.sample.longitude),
       accuracy=p(arguments.sample.accuracyMeters),speed={value=arguments.sample.speedKnots,cfsqltype="cf_sql_varchar",null=!len(arguments.sample.speedKnots)},
       course={value=arguments.sample.courseDegrees,cfsqltype="cf_sql_varchar",null=!len(arguments.sample.courseDegrees)},
       captured=p(sqlUtc(arguments.sample.capturedAtUtc)),hash=p(arguments.sample.payloadHash)});
  }

  private struct function normalizeSample(required any sample) {
    if (!isStruct(arguments.sample)) return {SUCCESS=false,ERROR="INVALID_SAMPLE"};
    if (!validUUID(arguments.sample,"clientSampleId")) return {SUCCESS=false,ERROR="INVALID_SAMPLE_ID"};
    var ranges = [
      {key="latitude",lo=-90,hi=90,scale=7,reason="INVALID_LATITUDE"},
      {key="longitude",lo=-180,hi=180,scale=7,reason="INVALID_LONGITUDE"},
      {key="accuracyMeters",lo=0,hi=500,scale=3,reason="INVALID_ACCURACY"},
      {key="speedKnots",lo=0,hi=200,scale=3,reason="INVALID_SPEED"},
      {key="courseDegrees",lo=0,hi=360,scale=3,reason="INVALID_COURSE"}
    ];
    var normalized = {SUCCESS=true,"clientSampleId"=lCase(arguments.sample.clientSampleId),"speedKnots"="","courseDegrees"=""};
    for (var rule in ranges) {
      var optional = listFind("speedKnots,courseDegrees",rule.key)>0;
      if (optional && (!structKeyExists(arguments.sample,rule.key) || isNull(arguments.sample[rule.key]))) continue;
      if (!structKeyExists(arguments.sample,rule.key) || !jsonNumber(arguments.sample[rule.key])) return {SUCCESS=false,ERROR=rule.reason};
      var n = arguments.sample[rule.key];
      if (n<rule.lo || n>rule.hi || (rule.key=="accuracyMeters" && n<=0) || (rule.key=="courseDegrees" && n>=360)) return {SUCCESS=false,ERROR=rule.reason};
      normalized[rule.key] = decimalValue(n,rule.scale);
      if ((rule.key=="accuracyMeters" && val(normalized[rule.key])<=0) || (rule.key=="courseDegrees" && val(normalized[rule.key])>=360)) return {SUCCESS=false,ERROR=rule.reason};
    }
    if (!structKeyExists(arguments.sample,"capturedAtUtc") || !validTimestamp(arguments.sample.capturedAtUtc)) return {SUCCESS=false,ERROR="INVALID_CAPTURE_TIME"};
    var captured = instantMs(arguments.sample.capturedAtUtc);
    normalized["capturedAtUtc"] = iso(captured);
    normalized["payloadHash"] = lCase(hash(normalized.latitude & "|" & normalized.longitude & "|" & normalized.accuracyMeters & "|"
      & normalized.speedKnots & "|" & normalized.courseDegrees & "|" & normalized.capturedAtUtc,"SHA-256","UTF-8"));
    return normalized;
  }

  private string function captureAdmissionError(required struct sample, required query row, required numeric clockMs) {
    var captured = instantMs(arguments.sample.capturedAtUtc);
    if (captured>arguments.clockMs+120000) return "CAPTURE_IN_FUTURE";
    if (captured<arguments.clockMs-7*variables.dayMs) return "CAPTURE_TOO_OLD";
    if (captured<instantMs(arguments.row.started_iso[1])) return "CAPTURE_BEFORE_START";
    if (captured>=instantMs(arguments.row.authorization_iso[1])) return "CAPTURE_AFTER_AUTHORIZATION";
    if (arguments.row.status[1]=="DRAINING" && captured>instantMs(arguments.row.cutoff_iso[1])) return "CAPTURE_AFTER_STOP";
    return "";
  }

  private struct function latestSample(required query row, required numeric clockMs) {
    var q = sql("SELECT client_sample_id,latitude,longitude,accuracy_meters,speed_knots,course_degrees,
        DATE_FORMAT(captured_at_utc,'%Y-%m-%dT%H:%i:%s.%fZ') AS captured_iso,
        DATE_FORMAT(received_at_utc,'%Y-%m-%dT%H:%i:%s.%fZ') AS received_iso
      FROM companion_location_samples WHERE tracking_session_id=:sid
        AND captured_at_utc >= :started AND captured_at_utc < :authUntil
        AND (:hasCutoff=0 OR captured_at_utc<=:cutoff)
        AND captured_at_utc>=DATE_SUB(UTC_TIMESTAMP(3),INTERVAL :retentionDays DAY)
      ORDER BY captured_at_utc DESC,id DESC LIMIT 1",
      {sid=p(arguments.row.id[1],"bigint"),retentionDays=p(variables.sampleRetentionDays,"integer"),started=p(sqlUtc(iso(instantMs(arguments.row.started_iso[1])))),
       authUntil=p(sqlUtc(iso(instantMs(arguments.row.authorization_iso[1])))),
       hasCutoff=p(len(arguments.row.cutoff_iso[1]) ? 1:0,"integer"),
       cutoff=p(len(arguments.row.cutoff_iso[1]) ? sqlUtc(iso(instantMs(arguments.row.cutoff_iso[1]))) : sqlUtc(iso(arguments.clockMs)))});
    var result = sessionResponse(arguments.row,arguments.clockMs);
    result["hasLocation"] = q.recordCount>0;
    result["location"] = javacast("null","");
    if (q.recordCount) result["location"] = {
      "clientSampleId"=q.client_sample_id[1],"latitude"=val(q.latitude[1]),"longitude"=val(q.longitude[1]),"accuracyMeters"=val(q.accuracy_meters[1]),
      "speedKnots"=len(q.speed_knots[1]) ? val(q.speed_knots[1]) : javacast("null",""),
      "courseDegrees"=len(q.course_degrees[1]) ? val(q.course_degrees[1]) : javacast("null",""),
      "capturedAtUtc"=iso(instantMs(q.captured_iso[1])),"receivedAtUtc"=iso(instantMs(q.received_iso[1]))
    };
    return result;
  }

  public struct function runMaintenance(numeric limit=100) {
    var bounded = max(1,min(500,int(arguments.limit)));
    var result = {SUCCESS=true,"examinedSessions"=0,"closedSessions"=0,"deletedSamples"=0,"deletedSessions"=0,
      "sampleRetentionDays"=variables.sampleRetentionDays,"closedSessionRetentionDays"=variables.closedSessionRetentionDays};
    var candidates = sql("SELECT id,user_id,companion_device_id FROM companion_tracking_sessions
      WHERE status IN ('ACTIVE','DRAINING') ORDER BY updated_utc,id LIMIT " & bounded,{});
    for (var i=1;i<=candidates.recordCount;i++) {
      var owner = {userId=candidates.user_id[i],companionDeviceId=candidates.companion_device_id[i]};
      transaction isolation="repeatable_read" {
        lockMember(owner.userId);
        var device = deviceEvidence(owner,true);
        lockOperationalEvidence(owner.userId);
        var row = loadSession(candidates.id[i],owner,true);
        if (row.recordCount && row.status[1]!="CLOSED") {
          var eligibility = device.SUCCESS ? sessionEligibility(row,tripEvidence(owner.userId),databaseNowMs()) : device;
          result.examinedSessions++;
          if (!eligibility.SUCCESS) { closeSession(row.id[1],eligibility.ERROR); result.closedSessions++; }
          else sql("UPDATE companion_tracking_sessions SET updated_utc=UTC_TIMESTAMP(3) WHERE id=:sid",{sid=p(row.id[1],"bigint")});
        }
      }
    }
    // Independent hard 90-day policies. Never cascade-delete still-retained samples.
    transaction {
      var oldSamples = sql("SELECT id FROM companion_location_samples WHERE captured_at_utc<DATE_SUB(UTC_TIMESTAMP(3),INTERVAL :days DAY)
        ORDER BY captured_at_utc,id LIMIT " & bounded & " FOR UPDATE",{days=p(variables.sampleRetentionDays,"integer")});
      for (var j=1;j<=oldSamples.recordCount;j++) {
        sql("DELETE FROM companion_location_samples WHERE id=:id",{id=p(oldSamples.id[j],"bigint")});
        result.deletedSamples++;
      }
      var oldSessions = sql("SELECT s.id FROM companion_tracking_sessions s
        WHERE s.status='CLOSED' AND s.closed_at_utc<DATE_SUB(UTC_TIMESTAMP(3),INTERVAL :days DAY)
          AND NOT EXISTS(SELECT 1 FROM companion_location_samples p WHERE p.tracking_session_id=s.id)
        ORDER BY s.closed_at_utc,s.id LIMIT " & bounded & " FOR UPDATE",{days=p(variables.closedSessionRetentionDays,"integer")});
      for (var k=1;k<=oldSessions.recordCount;k++) {
        sql("DELETE FROM companion_tracking_sessions WHERE id=:id",{id=p(oldSessions.id[k],"bigint")});
        result.deletedSessions++;
      }
    }
    return result;
  }

  private void function closeSession(required any sessionId, required string reason) {
    sql("UPDATE companion_tracking_sessions SET status='CLOSED',closed_at_utc=UTC_TIMESTAMP(3),stop_reason=:reason,updated_utc=UTC_TIMESTAMP(3)
      WHERE id=:sid AND status<>'CLOSED'", {sid=p(arguments.sessionId,"bigint"),reason=p(left(arguments.reason,64))});
  }
  private void function markUsed(required any deviceId) {
    sql("UPDATE companion_devices SET last_used_at_utc=UTC_TIMESTAMP(),updated_utc=UTC_TIMESTAMP() WHERE id=:id",{id=p(arguments.deviceId,"bigint")});
  }
  private struct function sessionResponse(required query row, required numeric clockMs) {
    var result = success();
    result["trackingSessionId"] = toString(arguments.row.id[1]);
    result["clientSessionId"] = toString(arguments.row.client_session_id[1]);
    result["floatPlanId"] = toString(arguments.row.floatplan_id[1]);
    result["routeInstanceId"] = toString(arguments.row.route_instance_id[1]);
    result["sessionStatus"] = arguments.row.status[1];
    result["startedAtUtc"] = iso(instantMs(arguments.row.started_iso[1]));
    result["authorizationValidUntilUtc"] = iso(instantMs(arguments.row.authorization_iso[1]));
    result["captureStoppedAtUtc"] = len(arguments.row.cutoff_iso[1]) ? iso(instantMs(arguments.row.cutoff_iso[1])) : javacast("null","");
    result["drainUntilUtc"] = len(arguments.row.drain_iso[1]) ? iso(instantMs(arguments.row.drain_iso[1])) : javacast("null","");
    result["closedAtUtc"] = len(arguments.row.closed_iso[1]) ? iso(instantMs(arguments.row.closed_iso[1])) : javacast("null","");
    result["stopReason"] = len(arguments.row.stop_reason[1]) ? arguments.row.stop_reason[1] : javacast("null","");
    result["serverTimeUtc"] = iso(arguments.clockMs);
    return result;
  }
  private struct function success() { return {"SUCCESS"=true,"AUTH"=true,"HTTP_STATUS"=200}; }
  private struct function failure(required string code, required string message, required numeric status, boolean authenticated=true) {
    return {"SUCCESS"=false,"AUTH"=arguments.authenticated,"ERROR"=arguments.code,"MESSAGE"=arguments.message,"HTTP_STATUS"=arguments.status};
  }
  private any function sql(required string statement, required struct params) { return queryExecute(arguments.statement,arguments.params,{datasource=variables.datasource}); }
  private struct function p(required any value, string kind="varchar") { return {value=arguments.value,cfsqltype="cf_sql_" & arguments.kind}; }
  private boolean function validId(required struct source, required string key) {
    return structKeyExists(arguments.source,arguments.key) && isSimpleValue(arguments.source[arguments.key])
      && reFind("^[1-9][0-9]{0,18}$",toString(arguments.source[arguments.key]))>0
      && (len(toString(arguments.source[arguments.key]))<19 || compare(toString(arguments.source[arguments.key]),"9223372036854775807")<=0);
  }
  private boolean function validUUID(required struct source, required string key) {
    return structKeyExists(arguments.source,arguments.key) && isSimpleValue(arguments.source[arguments.key])
      && reFindNoCase("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",toString(arguments.source[arguments.key]))>0;
  }
  private boolean function jsonNumber(required any value) {
    if (!isSimpleValue(arguments.value)) return false;
    return reFind("^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$",serializeJSON(arguments.value))>0;
  }
  private string function decimalValue(required any value, required numeric scale) {
    return createObject("java","java.math.BigDecimal").init(toString(arguments.value)).setScale(javacast("int",arguments.scale),
      createObject("java","java.math.RoundingMode").HALF_UP).toPlainString();
  }
  private boolean function validTimestamp(required any value) {
    if (!isSimpleValue(arguments.value) || !reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z$",toString(arguments.value))) return false;
    try { return compare(iso(instantMs(arguments.value)),arguments.value)==0; } catch (any invalidDate) { return false; }
  }
  private numeric function instantMs(required string value) { return createObject("java","java.time.Instant").parse(arguments.value).toEpochMilli(); }
  private string function iso(required numeric millis) {
    return createObject("java","java.time.format.DateTimeFormatter").ofPattern("uuuu-MM-dd'T'HH:mm:ss.SSS'Z'")
      .withZone(createObject("java","java.time.ZoneOffset").UTC)
      .format(createObject("java","java.time.Instant").ofEpochMilli(javacast("long",arguments.millis)));
  }
  private string function sqlUtc(required string value) { return replace(left(arguments.value,23),"T"," "); }
  private numeric function databaseNowMs() {
    var q = sql("SELECT DATE_FORMAT(UTC_TIMESTAMP(3),'%Y-%m-%dT%H:%i:%s.%fZ') AS now_iso",{});
    return instantMs(q.now_iso[1]);
  }
  private any function apiComponent(required string name) {
    try { return createObject("component","fpw.api.v1." & arguments.name); }
    catch (any pathError) { return createObject("component","api.v1." & arguments.name); }
  }
}
