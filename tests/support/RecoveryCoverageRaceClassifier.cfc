component output="false" {
  public any function init(required numeric userId,required numeric planId) {variables.userId=arguments.userId;variables.planId=arguments.planId;variables.done=false;return this;}
  public struct function evaluateMember(required numeric userId,required string nowUtc,string enrollmentUtc="",string ownedClaimToken="",
    boolean evaluateFailedRetry=false,struct coverageVerification={}) {
    var result=new fpw.includes.InactiveMemberRecoveryClassifierService().evaluateMember(argumentCollection=arguments);
    if (result.ELIGIBLE AND !variables.done) {
      variables.done=true;
      new fpw.includes.InactiveMemberRecoveryCoverageService().beginShare(variables.userId,variables.planId,"basic_review_send");
    }
    return result;
  }
}
