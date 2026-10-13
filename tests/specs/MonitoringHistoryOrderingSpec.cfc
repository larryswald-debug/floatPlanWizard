component extends="testbox.system.BaseSpec" output="false" {

  function run() {
    describe("Monitor merged history ordering", function() {
      beforeEach(function() {
        variables.service = createObject("component", "fpw.api.v1.MonitoringConsoleViewModelService").init("fpw");
        for (var name in ["sortGpsHistoryItemsDesc", "sortAuditItemsDesc", "findLatestGpsHistoryLocation", "limitArray"]) {
          makePublic(variables.service, name, name & "ForTest");
        }
      });

      it("returns the newest GPS check-in across companion and Active Cruise sources", function() {
        var items = [
          { id = "companion-old", checkinAtUtc = "2026-10-10T13:33:14Z", hasGps = true },
          { id = "active-cruise-new", checkinAtUtc = "2026-10-11T21:17:52Z", hasGps = true },
          { id = "active-cruise-older", checkinAtUtc = "2026-10-09T22:12:55Z", hasGps = false }
        ];
        var sorted = variables.service.sortGpsHistoryItemsDescForTest(items);
        expect(isNull(sorted)).toBeFalse();
        expect(sorted[1].id).toBe("active-cruise-new");
        expect(sorted[2].id).toBe("companion-old");
        expect(sorted[3].id).toBe("active-cruise-older");
        expect(variables.service.findLatestGpsHistoryLocationForTest(sorted).id).toBe("active-cruise-new");
      });

      it("keeps the newest check-in first while selecting the latest check-in with GPS", function() {
        var items = [
          { id = "old-gps", checkinAtUtc = "2026-10-09T12:00:00Z", hasGps = true },
          { id = "new-without-gps", checkinAtUtc = "2026-10-11T22:00:00Z", hasGps = false },
          { id = "latest-gps", checkinAtUtc = "2026-10-11T21:00:00Z", hasGps = true }
        ];
        var sorted = variables.service.sortGpsHistoryItemsDescForTest(items);
        expect(isNull(sorted)).toBeFalse();
        expect(sorted[1].id).toBe("new-without-gps");
        expect(variables.service.findLatestGpsHistoryLocationForTest(sorted).id).toBe("latest-gps");
      });

      it("retains a newer check-in appended after twenty older entries when limiting history", function() {
        var items = [];
        for (var i = 1; i LTE 25; i++) {
          arrayAppend(items, { id = "older-" & i, checkinAtUtc = "2026-10-10T13:33:14Z", hasGps = true });
        }
        arrayAppend(items, { id = "newest", checkinAtUtc = "2026-10-11T21:17:52Z", hasGps = true });
        var sorted = variables.service.sortGpsHistoryItemsDescForTest(items);
        expect(isNull(sorted)).toBeFalse();
        var limited = variables.service.limitArrayForTest(sorted, 20);
        expect(arrayLen(limited)).toBe(20);
        expect(limited[1].id).toBe("newest");
        expect(variables.service.findLatestGpsHistoryLocationForTest(limited).id).toBe("newest");
      });

      it("returns audit events in descending time order across all three sources", function() {
        var items = [
          { id = "companion", occurredAtUtc = "2026-10-10T13:33:14Z" },
          { id = "monitor", occurredAtUtc = "2026-10-11T20:00:00Z" },
          { id = "canonical", occurredAtUtc = "2026-10-11T21:17:52Z" }
        ];
        var sorted = variables.service.sortAuditItemsDescForTest(items);
        expect(isNull(sorted)).toBeFalse();
        expect(sorted[1].id).toBe("canonical");
        expect(sorted[2].id).toBe("monitor");
        expect(sorted[3].id).toBe("companion");
      });

      it("retains new canonical audit events before the twenty-entry limit", function() {
        var items = [];
        for (var i = 1; i LTE 25; i++) {
          arrayAppend(items, { id = "older-" & i, occurredAtUtc = "2026-10-10T13:33:14Z" });
        }
        arrayAppend(items, { id = "canonical-new", occurredAtUtc = "2026-10-11T21:17:52Z" });
        var sorted = variables.service.sortAuditItemsDescForTest(items);
        expect(isNull(sorted)).toBeFalse();
        var limited = variables.service.limitArrayForTest(sorted, 20);
        expect(arrayLen(limited)).toBe(20);
        expect(limited[1].id).toBe("canonical-new");
      });

      it("returns empty and single-entry histories without inventing or dropping entries", function() {
        var gps = variables.service.sortGpsHistoryItemsDescForTest([]);
        var audit = variables.service.sortAuditItemsDescForTest([]);
        expect(isNull(gps)).toBeFalse();
        expect(isNull(audit)).toBeFalse();
        expect(arrayLen(gps)).toBe(0);
        expect(arrayLen(audit)).toBe(0);
        gps = variables.service.sortGpsHistoryItemsDescForTest([{ id = "only", checkinAtUtc = "2026-10-11T21:17:52Z" }]);
        audit = variables.service.sortAuditItemsDescForTest([{ id = "only", occurredAtUtc = "2026-10-11T21:17:52Z" }]);
        expect(arrayLen(gps)).toBe(1);
        expect(arrayLen(audit)).toBe(1);
        expect(gps[1].id).toBe("only");
        expect(audit[1].id).toBe("only");
      });
    });
  }
}
