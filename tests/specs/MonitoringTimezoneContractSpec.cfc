component extends="testbox.system.BaseSpec" output="false" {

  // SELECT-only regression suite. Never invoke the operational console entry point.
  function run() {
    describe("Monitor UTC read boundary", function() {
      beforeEach(function() {
        variables.service = createObject("component", "fpw.api.v1.MonitoringConsoleViewModelService").init("fpw");
        for (var name in [
          "parseStoredUtcDate", "formatUtc", "formatLocalLabel", "firstDate", "resolveTimezone",
          "buildMonitoringSection", "buildLastCheckinLocation", "buildAuditItem",
          "getCurrentUtcTimestamp", "loadMonitoringRow", "loadGpsHistory", "loadMonitoringAudit"
        ]) {
          makePublic(variables.service, name, name & "ForTest");
        }
      });

      it("assigns the known UTC epoch to offset-free SQL text", function() {
        var q = queryExecute(
          "SELECT CAST(CAST('2026-10-10 18:00:00' AS DATETIME) AS CHAR) AS raw_utc",
          {}, { datasource = "fpw" }
        );
        var parsed = variables.service.parseStoredUtcDateForTest(q.raw_utc[1]);
        expect(isInstanceOf(parsed, "java.util.Date")).toBeTrue();
        expect(parsed.getTime()).toBe(1791655200000);
        expect(variables.service.formatUtcForTest(q.raw_utc[1])).toBe("2026-10-10T18:00:00Z");
        expect(variables.service.formatLocalLabelForTest(q.raw_utc[1], "America/New_York")).toBe("Oct 10, 2026 2:00 PM");
        expect(variables.service.formatLocalLabelForTest(q.raw_utc[1], "US/Eastern")).toBe("Oct 10, 2026 2:00 PM");
      });

      it("preserves Z and numeric offsets instead of applying UTC twice", function() {
        for (var value in ["2026-10-10T18:00:00Z", "2026-10-10T14:00:00-04:00", "2026-10-10T23:30:00+05:30"]) {
          var parsed = variables.service.parseStoredUtcDateForTest(value);
          expect(isInstanceOf(parsed, "java.util.Date")).toBeTrue();
          expect(parsed.getTime()).toBe(1791655200000);
          expect(variables.service.formatUtcForTest(value)).toBe("2026-10-10T18:00:00Z");
        }
      });

      it("preserves fractions and existing date object instants", function() {
        var parsed = variables.service.parseStoredUtcDateForTest("2026-10-10 18:00:00.394");
        expect(parsed.getTime()).toBe(1791655200394);
        var instant = parseDateTime("2026-10-10T18:00:00Z");
        expect(variables.service.parseStoredUtcDateForTest(instant).getTime()).toBe(instant.getTime());
        var sqlInstant = createObject("java", "java.sql.Timestamp").init(javacast("long", 1791655200000));
        expect(variables.service.parseStoredUtcDateForTest(sqlInstant).getTime()).toBe(1791655200000);
        expect(variables.service.formatUtcForTest(sqlInstant)).toBe("2026-10-10T18:00:00Z");
      });

      it("keeps absent and invalid timestamps blank", function() {
        for (var value in ["", "   ", "not-a-date"]) {
          expect(variables.service.parseStoredUtcDateForTest(value)).toBe("");
          expect(variables.service.formatUtcForTest(value)).toBe("");
          expect(variables.service.formatLocalLabelForTest(value, "America/New_York")).toBe("");
        }
        var q = queryExecute("SELECT CAST(NULL AS CHAR) AS raw_utc", {}, { datasource = "fpw" });
        expect(variables.service.formatUtcForTest(q.raw_utc[1])).toBe("");
      });

      it("converts Eastern summer and winter without a fixed hour adjustment", function() {
        expect(variables.service.formatLocalLabelForTest("2026-07-10 18:00:00", "America/New_York")).toBe("Jul 10, 2026 2:00 PM");
        expect(variables.service.formatLocalLabelForTest("2026-01-10 18:00:00", "America/New_York")).toBe("Jan 10, 2026 1:00 PM");
      });

      it("handles both sides of spring and fall DST transitions", function() {
        var cases = [
          { utc = "2026-03-08 06:59:00", label = "Mar 8, 2026 1:59 AM" },
          { utc = "2026-03-08 07:00:00", label = "Mar 8, 2026 3:00 AM" },
          { utc = "2026-11-01 05:59:00", label = "Nov 1, 2026 1:59 AM" },
          { utc = "2026-11-01 06:00:00", label = "Nov 1, 2026 1:00 AM" }
        ];
        for (var item in cases) {
          expect(variables.service.formatLocalLabelForTest(item.utc, "America/New_York")).toBe(item.label);
          expect(variables.service.formatLocalLabelForTest(item.utc, "US/Eastern")).toBe(item.label);
        }
      });

      it("uses UTC for an empty trip zone and retains the existing invalid-zone fallback", function() {
        var raw = "2026-10-10 18:00:00";
        expect(variables.service.formatLocalLabelForTest(raw, "")).toBe("Oct 10, 2026 6:00 PM");
        var expected = dateTimeFormat(parseDateTime("2026-10-10T18:00:00Z"), "mmm d, yyyy h:nn tt");
        expect(variables.service.formatLocalLabelForTest(raw, "FPW/Invalid_Time_Zone")).toBe(expected);
      });

      it("preserves trip time zone precedence", function() {
        var names = ["departureTZ", "departTimezone", "returnTZ", "returnTimezone", "vessel_timezone"];
        var q = queryNew(arrayToList(names), "varchar,varchar,varchar,varchar,varchar", [{
          departureTZ = "America/New_York", departTimezone = "America/Chicago",
          returnTZ = "America/Denver", returnTimezone = "America/Los_Angeles", vessel_timezone = "UTC"
        }]);
        var expected = ["America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles", "UTC"];
        for (var i = 1; i LTE arrayLen(names); i++) {
          expect(variables.service.resolveTimezoneForTest(q)).toBe(expected[i]);
          querySetCell(q, names[i], "", 1);
        }
        expect(variables.service.resolveTimezoneForTest(q)).toBe("UTC");
      });

      it("formats every rendered monitoring deadline from raw UTC text", function() {
        var columns = [
          "last_checkin_at", "expected_checkin_at", "grace_expires_at", "missed_at",
          "escalated_at", "next_monitor_eval_at", "secure_for_night_until"
        ];
        var row = { id = 1, monitor_state = "ACTIVE", monitoring_mode = "CHECKIN",
          last_checkin_status = "OK", secure_for_night = 0 };
        for (var column in columns) { row[column] = "2026-10-10 18:00:00"; }
        var q = queryNew(structKeyList(row), "", [row]);
        var model = variables.service.buildMonitoringSectionForTest(q, queryNew("manual_delay_minutes_total", "integer", [{manual_delay_minutes_total = 0}]), "America/New_York");
        for (var field in ["lastCheckinAtUtc", "expectedCheckinAtUtc", "graceUntilUtc", "missedAtUtc", "escalatedAtUtc", "nextMonitorEvalAtUtc", "secureUntilUtc"]) {
          expect(model[field]).toBe("2026-10-10T18:00:00Z");
        }
        for (var field in ["lastCheckinLocalLabel", "expectedCheckinLocalLabel", "graceUntilLocalLabel", "missedAtLocalLabel", "escalatedAtLocalLabel", "nextMonitorEvalLocalLabel", "secureUntilLocalLabel"]) {
          expect(model[field]).toBe("Oct 10, 2026 2:00 PM");
        }
        expect(model.state).toBe("ACTIVE");
        expect(model.secureForNight).toBeFalse();
      });

      it("keeps receipt, creation, and capture fallback priority", function() {
        var receipt = "2026-10-10 18:10:00";
        var created = "2026-10-10 18:05:00";
        var captured = "2026-10-10 18:00:00";
        expect(variables.service.formatUtcForTest(variables.service.firstDateForTest(receipt, created, captured))).toBe("2026-10-10T18:10:00Z");
        expect(variables.service.formatUtcForTest(variables.service.firstDateForTest("", created, captured))).toBe("2026-10-10T18:05:00Z");
        expect(variables.service.formatUtcForTest(variables.service.firstDateForTest("", "", captured))).toBe("2026-10-10T18:00:00Z");
      });

      it("converts audit time without changing event identity or source", function() {
        var item = variables.service.buildAuditItemForTest("test-1", "2026-10-10 18:00:00", "America/New_York", "GPS_CAPTURED", "GPS captured", "fixture", "info", "floatplan_events", 0, 1);
        expect(item.occurredAtUtc).toBe("2026-10-10T18:00:00Z");
        expect(item.occurredAtLocalLabel).toBe("Oct 10, 2026 2:00 PM");
        expect(item.type).toBe("GPS_CAPTURED");
        expect(item.relatedCanonicalEventId).toBe(1);
        expect(item.source).toBe("floatplan_events");
      });

      it("calculates GPS age from capture time and preserves receipt time and stale threshold", function() {
        var gps = gpsFixture("2026-10-10T18:00:00Z", "2026-10-10T18:10:00Z");
        var model = variables.service.buildLastCheckinLocationForTest(gps, "America/New_York", parseDateTime("2026-10-10T18:15:00Z"));
        expect(model.ageMinutes).toBe(15);
        expect(model.capturedAtLocalLabel).toBe("Oct 10, 2026 2:00 PM");
        expect(model.receivedAtLocalLabel).toBe("Oct 10, 2026 2:10 PM");
        expect(model.capturedAtUtc).toBe(gps.capturedAtUtc);
        expect(model.receivedAtUtc).toBe(gps.receivedAtUtc);
        expect(model.isStale).toBeFalse();
        model = variables.service.buildLastCheckinLocationForTest(gps, "America/New_York", parseDateTime("2026-10-11T00:00:00Z"));
        expect(model.ageMinutes).toBe(360);
        expect(model.isStale).toBeFalse();
        model = variables.service.buildLastCheckinLocationForTest(gps, "America/New_York", parseDateTime("2026-10-11T00:01:00Z"));
        expect(model.ageMinutes).toBe(361);
        expect(model.isStale).toBeTrue();
      });

      it("measures elapsed GPS age across daylight-saving transitions", function() {
        for (var pair in [
          { captured = "2026-03-08T06:30:00Z", received = "2026-03-08T09:30:00Z" },
          { captured = "2026-11-01T04:30:00Z", received = "2026-11-01T07:30:00Z" }
        ]) {
          var model = variables.service.buildLastCheckinLocationForTest(gpsFixture(pair.captured, pair.received), "America/New_York", parseDateTime(pair.received));
          expect(model.ageMinutes).toBe(180);
        }
      });

      it("uses an actual UTC instant for the generated timestamp", function() {
        var before = now().getTime();
        var actual = variables.service.getCurrentUtcTimestampForTest().getTime();
        var after = now().getTime();
        expect(actual).toBeGTE(before - 5000);
        expect(actual).toBeLTE(after + 5000);
      });

      it("executes every changed SELECT without invoking operational trip workflows", function() {
        expect(variables.service.loadMonitoringRowForTest(-1, -1).recordCount).toBe(0);
        expect(arrayLen(variables.service.loadGpsHistoryForTest(-1, -1, "America/New_York"))).toBe(0);
        expect(arrayLen(variables.service.loadMonitoringAuditForTest(-1, -1, "America/New_York"))).toBe(0);
      });
    });
  }

  private struct function gpsFixture(required string captured, required string received) {
    return {
      hasGps = true, latitude = 40, longitude = -74, accuracyMeters = 10,
      capturedAtUtc = arguments.captured, receivedAtUtc = arguments.received,
      statusCode = "OK", sourceCode = "COMPANION_APP", sourceLabel = "Companion App GPS",
      notePreview = "", companionEventId = 1, canonicalEventId = 0
    };
  }
}
