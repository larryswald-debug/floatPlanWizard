component extends="testbox.system.BaseSpec" output="false" {

  function run() {
    describe("Vessel PDF presentation helpers", function() {

      beforeEach(function() {
        variables.pdfUtils = createObject(
          "component",
          "fpw.api.api_assets.floatPlanUtils"
        ).init();
        makePublic(
          variables.pdfUtils,
          "formatPdfGallons",
          "formatPdfGallonsForContractTest"
        );
        makePublic(
          variables.pdfUtils,
          "buildVesselIdentification",
          "buildVesselIdentificationForContractTest"
        );
      });

      it("formats structured capacity values at the PDF boundary", function() {
        expect(variables.pdfUtils.formatPdfGallonsForContractTest(125)).toBe("125 gal");
        expect(variables.pdfUtils.formatPdfGallonsForContractTest("35.5")).toBe("35.5 gal");
        expect(variables.pdfUtils.formatPdfGallonsForContractTest(0)).toBe("0 gal");
        expect(variables.pdfUtils.formatPdfGallonsForContractTest("")).toBe("");
      });

      it("does not present invalid, unit-bearing, or negative capacity values", function() {
        expect(variables.pdfUtils.formatPdfGallonsForContractTest("100 gallons")).toBe("");
        expect(variables.pdfUtils.formatPdfGallonsForContractTest("abc")).toBe("");
        expect(variables.pdfUtils.formatPdfGallonsForContractTest(-1)).toBe("");
      });

      it("combines vessel name with city and normalized state from Account Home Port", function() {
        expect(
          variables.pdfUtils.buildVesselIdentificationForContractTest(
            "Sea Trial",
            { city = "Tampa", state = "fl" }
          )
        ).toBe("Sea Trial — Tampa, FL");
      });

      it("falls back cleanly when the vessel name or Account Home Port is absent", function() {
        expect(
          variables.pdfUtils.buildVesselIdentificationForContractTest(
            "Sea Trial",
            { city = "", state = "" }
          )
        ).toBe("Sea Trial");
        expect(
          variables.pdfUtils.buildVesselIdentificationForContractTest(
            "",
            { city = "Tampa", state = "FL" }
          )
        ).toBe("Tampa, FL");
        expect(
          variables.pdfUtils.buildVesselIdentificationForContractTest("", {})
        ).toBe("");
      });

    });
  }

}
