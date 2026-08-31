component output="false" {
  variables.calls = [];
  variables.shouldSucceed = true;

  public any function init(boolean shouldSucceed=true) output=false {
    variables.calls = [];
    variables.shouldSucceed = arguments.shouldSucceed;
    return this;
  }

  public struct function sendDepartureReminderEmail(
    required numeric userId,
    required string toEmail,
    required numeric floatPlanId,
    string floatPlanName="",
    required string scheduledDepartureLabel,
    required string departureTimezone,
    required string reminderType
  ) output=false {
    arrayAppend(variables.calls, duplicate(arguments));
    if (!variables.shouldSucceed) {
      return {
        success = false,
        errorCode = "TEST_EMAIL_FAILURE",
        message = "Test departure reminder delivery failed."
      };
    }
    return {
      success = true,
      message = "Test departure reminder accepted."
    };
  }

  public array function getCalls() output=false {
    return duplicate(variables.calls);
  }
}
