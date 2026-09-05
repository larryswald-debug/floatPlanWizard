component extends="fpw.includes.InactiveMemberRecoveryLedgerService" output="false" {
  public any function init(string mode="") { super.init("fpw"); variables.mode=arguments.mode; return this; }
  public struct function markSent(required numeric userId,required string stage,required string claimToken) {
    if (variables.mode EQ "CONFIRMATION_UNKNOWN") throw(type="tests.LedgerConfirmationUnknown",message="CONTROLLED_CONFIRMATION_FAILURE");
    var result=super.markSent(argumentCollection=arguments);
    if (variables.mode EQ "COMMITTED_CONFIRMATION_UNKNOWN") throw(type="tests.LedgerConfirmationUnknown",message="CONTROLLED_CONFIRMATION_FAILURE");
    return result;
  }
}
