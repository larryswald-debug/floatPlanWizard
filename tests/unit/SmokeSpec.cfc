component extends="testbox.system.BaseSpec" {

  function run() {
    describe("Smoke Test", function() {
      it("discovers and runs", function() {
        expect(1).toBe(1);
      });
    });
  }

}
