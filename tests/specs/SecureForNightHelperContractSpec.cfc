component extends="testbox.system.BaseSpec" output="false" {

  function run() {
    describe("Secure-for-night public Follow helper contract", function() {

      beforeEach(function() {
        variables.service = createObject(
          "component",
          "fpw.api.v1.ActiveCruiseViewModelService"
        ).init("fpw");
        makePublic(
          variables.service,
          "deriveTripState",
          "deriveTripStateForContractTest"
        );
        makePublic(
          variables.service,
          "stateLabel",
          "stateLabelForContractTest"
        );
        makePublic(
          variables.service,
          "publicFollowTripStateHelperText",
          "publicFollowTripStateHelperTextForContractTest"
        );
      });

      it("renders the canonical paused_overnight public state coherently", function() {
        var tripState = variables.service.deriveTripStateForContractTest(
          motionState = "paused_overnight",
          safetyState = "normal"
        );
        var output = {
          code = tripState,
          label = variables.service.stateLabelForContractTest(tripState),
          helperText = variables.service.publicFollowTripStateHelperTextForContractTest(
            tripState = tripState,
            motionState = "paused_overnight",
            safetyState = "normal"
          )
        };

        expect(output.code).toBe("paused_overnight");
        expect(output.label).toBe("Secure for the Night");
        expect(output.helperText).toBe("The trip is secure for the night.");
      });

      it("retains the existing paused_secure_for_night helper alias", function() {
        expect(
          variables.service.publicFollowTripStateHelperTextForContractTest(
            tripState = "paused_secure_for_night",
            motionState = "paused_overnight",
            safetyState = "normal"
          )
        ).toBe("The trip is secure for the night.");
      });

      it("preserves the underway helper after secure-for-night resume", function() {
        expect(
          variables.service.publicFollowTripStateHelperTextForContractTest(
            tripState = "underway",
            motionState = "underway",
            safetyState = "normal"
          )
        ).toBe("The trip is underway on the active route.");
      });

      it("preserves the unknown-state fallback", function() {
        expect(
          variables.service.stateLabelForContractTest("unknown_error")
        ).toBe("Unknown");
        expect(
          variables.service.publicFollowTripStateHelperTextForContractTest(
            tripState = "unknown_error",
            motionState = "unknown",
            safetyState = "normal"
          )
        ).toBe("Trip status is unavailable.");
      });
    });
  }
}
