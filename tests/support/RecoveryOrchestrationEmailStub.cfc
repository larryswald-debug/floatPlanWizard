component extends="fpw.api.v1.email" output="false" {
  public any function init(string mode="") { variables.mode=arguments.mode; return this; }
  public struct function checkNonEssentialEmailEligibility(required string email,numeric userId=0,any optOutService="") {
    if (listFind("OPTED_OUT,PREFERENCE_LOOKUP_FAILED,UNSUBSCRIBE_URL_FAILED",variables.mode)) {
      return {eligible=false,code=variables.mode,unsubscribeUrl=""};
    }
    return super.checkNonEssentialEmailEligibility(email=arguments.email,userId=arguments.userId);
  }
  public struct function buildInactiveMemberRecoveryEmail(required string stage,required struct eligibility,string firstName="",string verifiedDraftUrl="") {
    if (variables.mode EQ "MISSING_ADDRESS") return {success=false,errorCode="NON_ESSENTIAL_COMPLIANCE_REQUIRED"};
    if (variables.mode EQ "RENDER_FAILURE") throw(type="tests.ControlledRender",message="CONTROLLED_RENDER_FAILURE");
    return super.buildInactiveMemberRecoveryEmail(argumentCollection=arguments);
  }
}
