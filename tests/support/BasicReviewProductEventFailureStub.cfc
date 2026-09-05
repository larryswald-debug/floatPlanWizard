component output="false" {
  variables.mode = "failure";

  public any function init(string mode="failure") {
    variables.mode = arguments.mode;
    return this;
  }

  public struct function recordEvent(
    required numeric userId, required string eventName, required string entityType,
    required numeric entityId, required string eventSource, struct metadata={},
    string idempotencyKey=""
  ) {
    if (variables.mode EQ "after_insert") {
      var result = createObject("component", "fpw.includes.ProductEventService").init("fpw")
        .recordEvent(argumentCollection=arguments);
      if (!result.SUCCESS) {
        throw(type="FPW.TestEvidenceSetup", message="Test event insert failed.");
      }
      throw(type="FPW.TestEvidenceFailure", message="Controlled failure after event insertion.");
    }
    return { SUCCESS=false, ERROR="TEST_EVENT_FAILURE" };
  }
}
