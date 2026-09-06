component extends="fpw.includes.ProductEventService" output="false" {
  public any function init(string mode="before") { super.init("fpw");variables.mode=arguments.mode;return this; }
  public struct function recordEvent(required numeric userId,required string eventName,required string entityType,
    required numeric entityId,required string eventSource,struct metadata={},string idempotencyKey="",string requestCorrelationId="") {
    if (arguments.eventName NEQ "recovery_coverage_started") return super.recordEvent(argumentCollection=arguments);
    if (variables.mode EQ "after") super.recordEvent(argumentCollection=arguments);
    throw(type="tests.CoverageFailure",message="CONTROLLED_COVERAGE_FAILURE");
  }
}
