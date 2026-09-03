component output="false" {

  variables.calls = [];
  variables.failuresRemaining = 0;

  public any function init(numeric failures=0) output=false {
    variables.calls = [];
    variables.failuresRemaining = max(0, int(arguments.failures));
    return this;
  }

  public void function setFailures(required numeric failures) output=false {
    variables.failuresRemaining = max(0, int(arguments.failures));
  }

  public array function getCalls() output=false {
    return duplicate(variables.calls);
  }

  public struct function sendSafeArrivalCaptainEmail() output=false {
    return recordCall("CAPTAIN", arguments);
  }

  public struct function sendSafeArrivalShoreContactEmail() output=false {
    return recordCall("SHORE", arguments);
  }

  private struct function recordCall(
    required string role,
    required struct callArguments
  ) output=false {
    var call = duplicate(arguments.callArguments);
    call.role = arguments.role;
    arrayAppend(variables.calls, call);

    if (variables.failuresRemaining GT 0) {
      variables.failuresRemaining--;
      return {
        success = false,
        errorCode = "TEST_SEND_FAILED",
        message = "Intentional safe-arrival test failure."
      };
    }

    return {
      success = true,
      errorCode = "",
      message = "Accepted by safe-arrival test stub."
    };
  }
}

