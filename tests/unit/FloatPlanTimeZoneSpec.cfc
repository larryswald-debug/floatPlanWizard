component extends="testbox.system.BaseSpec" {

  function run() {

    describe("Float Plan timezone handling", function() {

      it("does not shift return time on save", function() {
        if ( !structKeyExists( application, "floatPlanService" ) ) {
          skip( "application.floatPlanService not available in test context" );
        }
        var input = createDateTime(2026,1,3,18,30,0);
        var output = application.floatPlanService.normalizeTime(input);

        expect(output).toBe(input);
      });

    });

  }

}
