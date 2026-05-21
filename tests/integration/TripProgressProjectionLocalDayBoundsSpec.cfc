component extends="testbox.system.BaseSpec" output="false" {

  function run() {
    describe("TripProgressProjectionService local-day bounds", function() {
      it("builds America/New_York winter bounds without MySQL timezone conversion", function() {
        var service = newProjectionService();
        var bounds = service.getLocalDayBounds(parseUtc("2026-01-15T12:00:00Z"), "America/New_York");

        expect(bounds.localDate).toBe("2026-01-15");
        expect(formatUtc(bounds.startUtc)).toBe("2026-01-15T05:00:00Z");
        expect(formatUtc(bounds.endUtc)).toBe("2026-01-16T05:00:00Z");
      });

      it("builds America/New_York summer bounds without MySQL timezone conversion", function() {
        var service = newProjectionService();
        var bounds = service.getLocalDayBounds(parseUtc("2026-07-15T12:00:00Z"), "America/New_York");

        expect(bounds.localDate).toBe("2026-07-15");
        expect(formatUtc(bounds.startUtc)).toBe("2026-07-15T04:00:00Z");
        expect(formatUtc(bounds.endUtc)).toBe("2026-07-16T04:00:00Z");
      });

      it("normalizes US/Eastern to America/New_York", function() {
        var service = newProjectionService();
        var canonical = service.getLocalDayBounds(parseUtc("2026-07-15T12:00:00Z"), "America/New_York");
        var alias = service.getLocalDayBounds(parseUtc("2026-07-15T12:00:00Z"), "US/Eastern");

        expect(alias.localDate).toBe(canonical.localDate);
        expect(formatUtc(alias.startUtc)).toBe(formatUtc(canonical.startUtc));
        expect(formatUtc(alias.endUtc)).toBe(formatUtc(canonical.endUtc));
      });

      it("keeps UTC and +00:00 on UTC day boundaries", function() {
        var service = newProjectionService();
        var utcBounds = service.getLocalDayBounds(parseUtc("2026-07-15T12:00:00Z"), "UTC");
        var offsetBounds = service.getLocalDayBounds(parseUtc("2026-07-15T12:00:00Z"), "+00:00");

        expect(utcBounds.localDate).toBe("2026-07-15");
        expect(formatUtc(utcBounds.startUtc)).toBe("2026-07-15T00:00:00Z");
        expect(formatUtc(utcBounds.endUtc)).toBe("2026-07-16T00:00:00Z");
        expect(offsetBounds.localDate).toBe(utcBounds.localDate);
        expect(formatUtc(offsetBounds.startUtc)).toBe(formatUtc(utcBounds.startUtc));
        expect(formatUtc(offsetBounds.endUtc)).toBe(formatUtc(utcBounds.endUtc));
      });

      it("fails closed with a zero-length window for unsafe named timezones", function() {
        var service = newProjectionService();
        var asOfUtc = parseUtc("2026-07-15T12:00:00Z");
        var bounds = service.getLocalDayBounds(asOfUtc, "Not/AZone");

        expect(bounds.localDate).toBe("");
        expect(formatUtc(bounds.startUtc)).toBe("2026-07-15T12:00:00Z");
        expect(formatUtc(bounds.endUtc)).toBe("2026-07-15T12:00:00Z");
      });

      it("feeds Today Progress with a nonblank UTC local-day window for supported zones", function() {
        var service = newProjectionService();
        var asOfUtc = parseUtc("2026-07-15T12:00:00Z");
        var bounds = service.getLocalDayBounds(asOfUtc, "America/New_York");
        var out = { "authorityWarnings" = [] };
        var today = service.buildTodayProgress([
          {
            "authority" = "test",
            "segmentType" = "UNDERWAY",
            "startedAtUtc" = "2026-07-15T05:00:00Z",
            "endedAtUtc" = "2026-07-15T07:00:00Z"
          }
        ], bounds, asOfUtc, 10, out);

        expect(formatUtc(bounds.startUtc)).toBe("2026-07-15T04:00:00Z");
        expect(formatUtc(bounds.endUtc)).toBe("2026-07-16T04:00:00Z");
        expect(today.hoursToday).toBe(2);
        expect(today.milesTodayNm).toBe(20);
      });

      it("keeps raw operational UTC timestamps unshifted for current leg projection math", function() {
        var service = newProjectionService();
        var out = { "authorityWarnings" = [] };
        var legStartUtc = service.formatUtc("2026-05-20 22:01:55");
        var projection = {};

        expect(legStartUtc).toBe("2026-05-20T22:01:55Z");

        projection = service.buildCurrentLegProgress(
          {
            "startedAtUtc" = legStartUtc,
            "distanceNm" = 35
          },
          [
            {
              "segmentType" = "UNDERWAY",
              "startedAtUtc" = legStartUtc,
              "endedAtUtc" = "",
              "expectedResumeAtUtc" = ""
            }
          ],
          parseUtc("2026-05-20T22:15:16Z"),
          5.5,
          out
        );

        expect(projection.underwaySeconds).toBe(801);
        expect(projection.completedNm).toBe(1.2);
        expect(projection.remainingNm).toBe(33.8);
        expect(projection.percentComplete).toBe(3.5);
      });
    });
  }

  private any function newProjectionService() {
    var service = new fpw.api.v1.TripProgressProjectionService().init("fpw");
    makePublic(service, "getLocalDayBounds");
    makePublic(service, "buildTodayProgress");
    makePublic(service, "buildCurrentLegProgress");
    makePublic(service, "formatUtc");
    return service;
  }

  private date function parseUtc(required string value) {
    var normalized = replace(arguments.value, "T", " ", "one");
    normalized = replace(normalized, "Z", "", "one");
    return parseDateTime(normalized);
  }

  private string function formatUtc(required any value) {
    if (!isDate(arguments.value)) {
      return "";
    }
    return dateTimeFormat(arguments.value, "yyyy-mm-dd'T'HH:nn:ss'Z'");
  }

}
