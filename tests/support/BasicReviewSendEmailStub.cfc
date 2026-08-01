component output="false" {
  variables.calls = [];
  variables.shouldSucceed = true;

  public any function init(boolean shouldSucceed=true) output=false {
    variables.calls = [];
    variables.shouldSucceed = arguments.shouldSucceed;
    return this;
  }

  public struct function sendBasicReviewFloatPlanEmail(
    required numeric userId,
    required string toEmail,
    required string contactName,
    required string floatPlanName,
    required string captainName,
    required string pdfPath
  ) output=false {
    arrayAppend(variables.calls, duplicate(arguments));
    if (!variables.shouldSucceed) {
      return {
        success = false,
        errorCode = "TEST_EMAIL_FAILURE",
        message = "Test email delivery failed."
      };
    }
    return {
      success = true,
      message = "Test email accepted."
    };
  }

  public array function getCalls() output=false {
    return duplicate(variables.calls);
  }
}
