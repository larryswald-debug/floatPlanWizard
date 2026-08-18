component extends="testbox.system.BaseSpec" {

  function run() {
    describe("Marine name cache normalization", function() {
      it("normalizes a null-like cache miss to a defined empty value", function() {
        var cached = javacast("null", "") ?: "";

        expect(isDefined("cached")).toBeTrue();
        expect(cached).toBe("");
      });

      it("preserves a valid cached response struct", function() {
        var hit = { success=true, name="Test Marine Area" };
        var cached = hit ?: "";

        expect(isStruct(cached)).toBeTrue();
        expect(cached.success).toBeTrue();
        expect(cached.name).toBe("Test Marine Area");
      });

      it("keeps the endpoint cache read normalized at the assignment boundary", function() {
        var source = fileRead(expandPath("/fpw/api/v1/marineName.cfc"), "utf-8");

        expect(find('var cached = "";', source)).toBeGT(0);
        expect(find('cached = cacheGet(cacheKey) ?: "";', source)).toBeGT(0);
        expect(find('cached = cacheGet(cacheKey);', source)).toBe(0);
        expect(find('isStruct(cached) && structKeyExists(cached, "success")', source)).toBeGT(0);
      });
    });
  }
}
