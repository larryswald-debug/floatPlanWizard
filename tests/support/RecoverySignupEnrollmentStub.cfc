component output="false" {
  variables.result={SUCCESS=true,CODE="ENROLLED"};
  variables.fail=false;
  variables.calls=[];

  public any function init(any result={SUCCESS=true,CODE="ENROLLED"},boolean fail=false) {
    variables.result=arguments.result;
    variables.fail=arguments.fail;
    return this;
  }
  public any function ensureEnrolled(required numeric userId) {
    arrayAppend(variables.calls,duplicate(arguments));
    if (variables.fail) throw(type="tests.RecoverySignupEnrollmentFailure",message="PRIVATE_RAW_FAILURE@example.test");
    return variables.result;
  }
  public array function calls() { return duplicate(variables.calls); }
}
