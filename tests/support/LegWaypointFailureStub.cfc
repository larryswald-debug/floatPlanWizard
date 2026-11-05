component output=false {
    public any function init(numeric failAt=2) { variables.calls=0; variables.failAt=arguments.failAt; return this; }
    public void function recordRequiredMemberActivity(required numeric userId, required string eventName, required numeric entityId) {
        variables.calls++;
        if (variables.calls == variables.failAt) throw(type="FPW.LegWaypoints.ControlledFailure",message="Controlled test-only second-write failure.");
        new fpw.includes.ProductEventService().init("fpw").recordRequiredMemberActivity(argumentCollection=arguments);
    }
}
