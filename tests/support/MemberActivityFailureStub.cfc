component output="false" {
  public any function init(required string mode, string datasource="fpw") {
    variables.mode=arguments.mode;
    variables.datasource=arguments.datasource;
    return this;
  }
  public void function recordRequiredMemberActivity(required numeric userId, required string eventName, required numeric entityId) {
    if (variables.mode EQ "after") {
      createObject("component","fpw.includes.ProductEventService").init(variables.datasource)
        .recordRequiredMemberActivity(argumentCollection=arguments);
    }
    throw(type="FPW.MemberActivity.TestFailure",message="Controlled activity evidence failure.");
  }
}
