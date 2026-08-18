component extends="testbox.system.BaseSpec" output="false" {

  function run() {
    describe("Float plan PDF itinerary timezone formatting", function() {

      beforeEach(function() {
        variables.itineraryService = createObject(
          "component",
          "fpw.api.api_assets.FloatPlanPdfItineraryService"
        ).init("fpw");
        makePublic(
          variables.itineraryService,
          "formatUtcForTimezone",
          "formatUtcForTimezoneForContractTest"
        );
        makePublic(
          variables.itineraryService,
          "normalizePdfTimezone",
          "normalizePdfTimezoneForContractTest"
        );
      });

      it("formats summer and winter route timing without java.time", function() {
        var summer = variables.itineraryService.formatUtcForTimezoneForContractTest(
          "2026-08-02T15:00:00Z",
          "US/Eastern"
        );
        var winter = variables.itineraryService.formatUtcForTimezoneForContractTest(
          "2026-01-15 15:00:00",
          "America/New_York"
        );
        var source = readRepoFile("api/api_assets/FloatPlanPdfItineraryService.cfc");

        expect(summer.valid).toBeTrue();
        expect(summer.date).toBe("08/02/26");
        expect(summer.time).toBe("11:00 EDT");
        expect(winter.valid).toBeTrue();
        expect(winter.date).toBe("01/15/26");
        expect(winter.time).toBe("10:00 EST");
        expect(findNoCase('createObject("java"', source)).toBe(0);
        expect(findNoCase('parseDateTime(replace(rawUtc, " ", "T", "one") & "Z")', source)).toBeGT(0);
      });

      it("normalizes supported legacy timezone identifiers and rejects invalid zones", function() {
        expect(
          variables.itineraryService.normalizePdfTimezoneForContractTest("US/Eastern")
        ).toBe("America/New_York");
        expect(
          variables.itineraryService.normalizePdfTimezoneForContractTest("US/Central")
        ).toBe("America/Chicago");
        expect(
          variables.itineraryService.normalizePdfTimezoneForContractTest("US/Mountain")
        ).toBe("America/Denver");
        expect(
          variables.itineraryService.normalizePdfTimezoneForContractTest("US/Pacific")
        ).toBe("America/Los_Angeles");
        expect(
          variables.itineraryService.normalizePdfTimezoneForContractTest("US/Alaska")
        ).toBe("America/Anchorage");
        expect(
          variables.itineraryService.normalizePdfTimezoneForContractTest("US/Hawaii")
        ).toBe("Pacific/Honolulu");
        expect(
          variables.itineraryService.normalizePdfTimezoneForContractTest("Not/A_Timezone")
        ).toBe("");
        expect(
          variables.itineraryService.formatUtcForTimezoneForContractTest(
            "2026-08-02T15:00:00Z",
            "Not/A_Timezone"
          ).valid
        ).toBeFalse();
      });

      it("keeps missing canonical timing distinct from formatter failures", function() {
        var source = readRepoFile("api/api_assets/FloatPlanPdfItineraryService.cfc");

        expect(findNoCase('if (!len(departureUtc))', source)).toBeGT(0);
        expect(findNoCase('if (!len(arrivalUtc))', source)).toBeGT(0);
        expect(findNoCase('"ROUTE_LEG_DEPARTURE_TIME_MISSING"', source)).toBeGT(0);
        expect(findNoCase('"ROUTE_LEG_ARRIVAL_TIME_MISSING"', source)).toBeGT(0);
        expect(findNoCase('"ROUTE_LEG_DEPARTURE_TIME_FORMAT_FAILED"', source)).toBeGT(0);
        expect(findNoCase('"ROUTE_LEG_ARRIVAL_TIME_FORMAT_FAILED"', source)).toBeGT(0);
      });

    });
  }

  private string function readRepoFile(required string relativePath) {
    return fileRead(expandPath("/fpw/" & arguments.relativePath), "utf-8");
  }

}
