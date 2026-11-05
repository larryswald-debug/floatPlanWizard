component extends="testbox.system.BaseSpec" output=false {
    public any function controller(numeric failAt=0) {
        var target=prepareMock(new fpw.api.v1.waypoint());
        if (arguments.failAt > 0) target.$("getMemberActivityEventService",new fpw.tests.support.LegWaypointFailureStub().init(arguments.failAt));
        makePublic(target,"saveResolvedLegWaypoints","saveForTest");
        makePublic(target,"persistWaypoint","singleForTest");
        return target;
    }
}
