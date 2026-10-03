component output="false" {
  public any function init(required any fixture,string action="") {
    variables.fixture=arguments.fixture;
    variables.action=arguments.action;
    variables.raced=false;
    variables.calls=0;
    variables.real=new fpw.includes.InactiveMemberRecoveryClassifierService(settingsService=arguments.fixture);
    return this;
  }
  public struct function evaluateMember(required numeric userId,required string nowUtc,string enrollmentUtc="",string ownedClaimToken="",boolean evaluateFailedRetry=false,struct coverageVerification={}) {
    variables.calls++;
    if (!variables.raced AND variables.calls EQ 3 AND left(variables.action,6) EQ "final_") {
      variables.raced=true;
      variables.fixture.changeAfterEvaluation(arguments.userId,removeChars(variables.action,1,6));
    }
    var result=variables.real.evaluateMember(argumentCollection=arguments);
    if (!variables.raced AND !len(arguments.ownedClaimToken) AND result.ELIGIBLE AND len(variables.action) AND left(variables.action,6) NEQ "final_") {
      variables.raced=true;
      variables.fixture.changeAfterEvaluation(arguments.userId,variables.action);
    }
    return result;
  }
}
