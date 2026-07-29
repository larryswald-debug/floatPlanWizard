component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.service = new fpw.api.v1.MonitoringConsoleViewModelService().init("fpw");
  }

  function run() {
    describe("MonitoringConsoleViewModelService", function() {
      it("returns the frozen safe empty-state shape for unauthenticated access", function() {
        var model = variables.service.getMonitoringConsoleViewModel(0, 0);
        var forbidden = variables.service.scanForbiddenPrivateKeysForTests(model);

        expect(model.success).toBeFalse(serializeJSON(model));
        expect(model.version).toBe(1);
        expect(model.source).toBe("MonitoringConsoleViewModelService.getMonitoringConsoleViewModel");
        expect(model.emptyState.code).toBe("UNAUTHENTICATED");
        expect(structKeyExists(model, "identity")).toBeTrue();
        expect(structKeyExists(model, "tripState")).toBeTrue();
        expect(structKeyExists(model, "monitoring")).toBeTrue();
        expect(structKeyExists(model, "lastCheckinLocation")).toBeTrue();
        expect(structKeyExists(model, "map")).toBeTrue();
        expect(structKeyExists(model, "auditTimeline")).toBeTrue();
        expect(structKeyExists(model, "gpsHistory")).toBeTrue();
        expect(structKeyExists(model, "technicalSnapshot")).toBeTrue();
        expect(structKeyExists(model, "safetyCopy")).toBeTrue();
        expect(arrayLen(forbidden)).toBe(0, serializeJSON(forbidden));
      });

      it("returns a private monitoring console DTO with captain-safe audit rows for an active route-backed trip", function() {
        var fixture = findMonitoringAuditFixture();
        if (!fixture.hasFixture) {
          skip("No active route-backed monitoring fixture with audit rows is available.");
        }

        var model = variables.service.getMonitoringConsoleViewModel(fixture.userId, fixture.floatPlanId);
        var forbidden = variables.service.scanForbiddenPrivateKeysForTests(model);

        expect(model.success).toBeTrue(serializeJSON(model));
        expect(model.identity.userId).toBe(fixture.userId);
        expect(model.identity.floatPlanId).toBe(fixture.floatPlanId);
        expect(model.identity.routeInstanceId).toBe(fixture.routeInstanceId);
        expect(model.monitoring.hasMonitoringRow).toBeTrue(serializeJSON(model.monitoring));
        expect(arrayLen(model.auditTimeline)).toBeGT(0, serializeJSON(model.auditTimeline));
        expect(findAuditItemBySource(model.auditTimeline, "floatplan_monitor_events").source).toBe("floatplan_monitor_events");
        if (fixture.companionEvents GT 0) {
          expect(findAuditItem(model.auditTimeline, "COMPANION_CHECKIN_RECEIVED").title).toBe("Companion check-in received");
        }
        if (fixture.canonicalEvents GT 0) {
          expect(findAuditItem(model.auditTimeline, "CANONICAL_EVENT_CREATED").title).toBe("Canonical float plan event created");
        }
        if (model.lastCheckinLocation.hasLocation) {
          expect(model.lastCheckinLocation.sourceCode).toBe("COMPANION_APP");
          expect(model.lastCheckinLocation.canonicalEventId).toBe(0);
          expect(isStruct(model.map.lastCheckinMarker)).toBeTrue(serializeJSON(model.map));
          expect(model.map.lastCheckinMarker.label).toBe("Last Check-In Location");
          if (!isNull(model.lastCheckinLocation.accuracyMeters) AND isNumeric(model.lastCheckinLocation.accuracyMeters)) {
            expect(isStruct(model.map.accuracyCircle)).toBeTrue(serializeJSON(model.map));
          }
        }
        expect(arrayLen(model.gpsHistory) LTE 20).toBeTrue(serializeJSON(model.gpsHistory));
        expect(arrayLen(forbidden)).toBe(0, serializeJSON(forbidden));
      });

      it("uses Active Cruise GPS from canonical check-in payloads when that is the latest location source", function() {
        var fixture = findMonitoringAuditFixture();
        var insertedEventId = 0;
        var model = {};
        var activeCruiseHistoryRows = [];
        var forbidden = [];

        if (!fixture.hasFixture) {
          skip("No active route-backed monitoring fixture is available.");
        }

        try {
          insertedEventId = insertActiveCruiseGpsCanonicalEvent(fixture);
          model = variables.service.getMonitoringConsoleViewModel(fixture.userId, fixture.floatPlanId);
          forbidden = variables.service.scanForbiddenPrivateKeysForTests(model);
          activeCruiseHistoryRows = findGpsHistoryRowsBySource(model.gpsHistory, "ACTIVE_CRUISE_WEB");

          expect(model.success).toBeTrue(serializeJSON(model));
          expect(model.lastCheckinLocation.hasLocation).toBeTrue(serializeJSON(model.lastCheckinLocation));
          expect(model.lastCheckinLocation.sourceCode).toBe("ACTIVE_CRUISE_WEB", serializeJSON(model.lastCheckinLocation));
          expect(model.lastCheckinLocation.sourceLabel).toBe("Active Cruise GPS", serializeJSON(model.lastCheckinLocation));
          expect(model.lastCheckinLocation.canonicalEventId).toBe(insertedEventId, serializeJSON(model.lastCheckinLocation));
          expect(model.lastCheckinLocation.companionEventId).toBe(0, serializeJSON(model.lastCheckinLocation));
          expect(numberFormat(val(model.lastCheckinLocation.latitude), "0.0000000")).toBe("30.1234567", serializeJSON(model.lastCheckinLocation));
          expect(numberFormat(val(model.lastCheckinLocation.longitude), "0.0000000")).toBe("-84.1234567", serializeJSON(model.lastCheckinLocation));
          expect(arrayLen(activeCruiseHistoryRows)).toBeGT(0, serializeJSON(model.gpsHistory));
          expect(activeCruiseHistoryRows[1].canonicalEventId).toBe(insertedEventId, serializeJSON(activeCruiseHistoryRows[1]));
          expect(arrayLen(forbidden)).toBe(0, serializeJSON(forbidden));
        } finally {
          if (insertedEventId GT 0) {
            deleteCanonicalEvent(insertedEventId);
          }
        }
      });
    });
  }

  private struct function findMonitoringAuditFixture() {
    var qFixture = queryExecute(
      "SELECT
          fp.floatPlanId,
          fp.userId,
          fp.route_instance_id,
          COUNT(DISTINCT fce.id) AS companion_events,
          COUNT(DISTINCT fme.id) AS monitor_events,
          COUNT(DISTINCT fe.id) AS canonical_events
       FROM floatplans fp
       INNER JOIN route_instances ri
          ON ri.id = fp.route_instance_id
         AND CAST(ri.user_id AS UNSIGNED) = fp.userId
       INNER JOIN floatplan_monitoring fm
          ON fm.float_plan_id = fp.floatPlanId
         AND fm.user_id = fp.userId
         AND UPPER(TRIM(fm.monitor_state)) <> 'CLOSED'
         AND fm.closed_at IS NULL
       LEFT JOIN floatplan_companion_events fce
          ON fce.user_id = fp.userId
         AND fce.floatplan_id = fp.floatPlanId
         AND fce.event_type = 'CHECKIN'
       LEFT JOIN floatplan_monitor_events fme
          ON fme.user_id = fp.userId
         AND fme.float_plan_id = fp.floatPlanId
       LEFT JOIN floatplan_events fe
          ON fe.user_id = fp.userId
         AND fe.floatplan_id = fp.floatPlanId
         AND fe.event_type = 'CHECKIN_RECEIVED'
         AND fe.source = 'active_cruise_checkin'
         AND fe.voided_at_utc IS NULL
       WHERE UPPER(TRIM(fp.status)) = 'ACTIVE'
         AND fp.route_instance_id IS NOT NULL
         AND fp.closedAt IS NULL
       GROUP BY fp.floatPlanId, fp.userId, fp.route_instance_id
       HAVING monitor_events > 0
       ORDER BY (companion_events + canonical_events) DESC, fp.floatPlanId DESC
       LIMIT 1",
      {},
      { datasource = "fpw" }
    );

    if (qFixture.recordCount EQ 0) {
      return { "hasFixture" = false };
    }

    return {
      "hasFixture" = true,
      "floatPlanId" = val(qFixture.floatPlanId[1]),
      "userId" = val(qFixture.userId[1]),
      "routeInstanceId" = val(qFixture.route_instance_id[1]),
      "companionEvents" = val(qFixture.companion_events[1]),
      "monitorEvents" = val(qFixture.monitor_events[1]),
      "canonicalEvents" = val(qFixture.canonical_events[1])
    };
  }

  private struct function findAuditItem(required array items, required string type) {
    var i = 0;
    for (i = 1; i <= arrayLen(arguments.items); i++) {
      if (
        isStruct(arguments.items[i])
        AND structKeyExists(arguments.items[i], "type")
        AND arguments.items[i].type EQ arguments.type
      ) {
        return arguments.items[i];
      }
    }
    return {};
  }

  private struct function findAuditItemBySource(required array items, required string source) {
    var i = 0;
    for (i = 1; i <= arrayLen(arguments.items); i++) {
      if (
        isStruct(arguments.items[i])
        AND structKeyExists(arguments.items[i], "source")
        AND arguments.items[i].source EQ arguments.source
      ) {
        return arguments.items[i];
      }
    }
    return {};
  }

  private numeric function insertActiveCruiseGpsCanonicalEvent(required struct fixture) {
    var payload = {
      status_label = "On Track",
      monitoring_status = "ON_TRACK",
      checkin_context = "",
      note_body = "",
      stream_id = 0,
      source_post_id = 0,
      is_overnight_transition = false,
      legacy_history_not_backfilled = true,
      location = {
        source = "ACTIVE_CRUISE_WEB",
        latitude = 30.1234567,
        longitude = -84.1234567,
        accuracyMeters = 15.2,
        capturedAtUtc = dateTimeFormat(dateAdd("n", 1, now()), "yyyy-mm-dd'T'HH:nn:ss'Z'")
      }
    };
    var eventKey = "monitoring-console-active-cruise-gps-" & replace(createUUID(), "-", "", "all");
    var qInserted = queryNew("");

    queryExecute(
      "INSERT INTO floatplan_events (
          floatplan_id,
          user_id,
          route_instance_id,
          route_leg_order,
          event_type,
          event_status,
          occurred_at_utc,
          source,
          actor_user_id,
          source_checkin_id,
          source_monitoring_id,
          source_post_id,
          idempotency_key,
          payload_json
       ) VALUES (
          :floatPlanId,
          :userId,
          :routeInstanceId,
          NULL,
          'CHECKIN_RECEIVED',
          'ON_TRACK',
          UTC_TIMESTAMP(),
          'active_cruise_checkin',
          :userId,
          NULL,
          0,
          0,
          :eventKey,
          :payloadJson
       )",
      {
        floatPlanId = { value = arguments.fixture.floatPlanId, cfsqltype = "cf_sql_integer" },
        userId = { value = arguments.fixture.userId, cfsqltype = "cf_sql_integer" },
        routeInstanceId = { value = arguments.fixture.routeInstanceId, cfsqltype = "cf_sql_integer" },
        eventKey = { value = eventKey, cfsqltype = "cf_sql_varchar" },
        payloadJson = { value = serializeJSON(payload), cfsqltype = "cf_sql_longvarchar" }
      },
      { datasource = "fpw" }
    );

    qInserted = queryExecute("SELECT LAST_INSERT_ID() AS event_id", {}, { datasource = "fpw" });
    return val(qInserted.event_id[1]);
  }

  private array function findGpsHistoryRowsBySource(required array items, required string sourceCode) {
    var matches = [];
    var i = 0;
    for (i = 1; i <= arrayLen(arguments.items); i++) {
      if (
        isStruct(arguments.items[i])
        AND structKeyExists(arguments.items[i], "sourceCode")
        AND arguments.items[i].sourceCode EQ arguments.sourceCode
      ) {
        arrayAppend(matches, arguments.items[i]);
      }
    }
    return matches;
  }

  private void function deleteCanonicalEvent(required numeric eventId) {
    queryExecute(
      "DELETE FROM floatplan_events WHERE id = :eventId",
      {
        eventId = { value = arguments.eventId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }
}
