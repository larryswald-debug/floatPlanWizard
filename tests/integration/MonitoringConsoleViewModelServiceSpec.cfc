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
}
