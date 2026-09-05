component output="false" {
  public any function init(required any fixture,string action="") {
    variables.fixture=arguments.fixture;
    variables.action=arguments.action;
    variables.raced=false;
    variables.real=new fpw.includes.InactiveMemberRecoveryClassifierService();
    return this;
  }
  public struct function evaluateMember(required numeric userId,required string nowUtc,string enrollmentUtc="",string ownedClaimToken="",boolean evaluateFailedRetry=false) {
    var result=variables.real.evaluateMember(argumentCollection=arguments);
    if (!variables.raced AND !len(arguments.ownedClaimToken) AND result.ELIGIBLE AND len(variables.action)) {
      variables.raced=true;
      variables.fixture.changeAfterEvaluation(arguments.userId,variables.action);
    }
    return result;
  }
}
