component output="false" {

  variables.shouldSucceed = true;
  variables.failFloatPlanId = 0;
  variables.calls = [];

  public any function init(boolean shouldSucceed=true, numeric failFloatPlanId=0) {
    variables.shouldSucceed = arguments.shouldSucceed;
    variables.failFloatPlanId = val(arguments.failFloatPlanId);
    variables.calls = [];
    return this;
  }

  public struct function closeMonitoringForFloatPlan(
    required numeric floatPlanId,
    string closeReason=""
  ) {
    arrayAppend(variables.calls, {
      floatPlanId = val(arguments.floatPlanId),
      closeReason = trim(arguments.closeReason)
    });
    if (
      !variables.shouldSucceed
      OR (
        variables.failFloatPlanId GT 0
        AND val(arguments.floatPlanId) EQ variables.failFloatPlanId
      )
    ) {
      return {
        SUCCESS = false,
        CLOSED = false,
        ERROR = "INJECTED_MONITORING_CLOSE_FAILURE"
      };
    }
    return {
      SUCCESS = true,
      CLOSED = true
    };
  }

  public array function getCalls() {
    return duplicate(variables.calls);
  }

}
