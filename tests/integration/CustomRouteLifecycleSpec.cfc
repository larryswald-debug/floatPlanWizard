component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.api = new fpw.tests.support.FpwApiSupport().init();
    variables.naming = new fpw.tests.support.FpwNamingSupport();
    variables.cleanup = new fpw.tests.support.FpwCleanupSupport();
    variables.cleanup.init( variables.api );
    variables.created = { waypointIds = [], userRouteIds = [] };
  }

  function afterAll() {
    for ( var i = arrayLen( variables.created.userRouteIds ); i GTE 1; i-- ) {
      variables.cleanup.cleanupUserRoute( variables.created.userRouteIds[ i ] );
    }
    for ( var j = arrayLen( variables.created.waypointIds ); j GTE 1; j-- ) {
      variables.cleanup.cleanupWaypoint( variables.created.waypointIds[ j ] );
    }
  }

  function run() {
    describe( "Custom route lifecycle contracts", function() {
      it( "creates, loads, adds legs, previews, removes a leg, deletes, and reactivates the same route name", function() {
        var prefix = variables.naming.buildPrefix( "custom-route-lifecycle", "reactivate" );
        var startWaypointId = createWaypoint( prefix, "Start", "27.950575", "-82.457178" );
        var middleWaypointId = createWaypoint( prefix, "Middle", "27.771889", "-82.638611" );
        var routeName = variables.naming.buildName( prefix, "My Route" );

        var createPayload = variables.api.routeBuilder( "createUserRoute", { route_name = routeName } );
        var routeId = val( createPayload.DATA.route_id ?: 0 );
        arrayAppend( variables.created.userRouteIds, routeId );

        expect( variables.api.routeBuilder( "setUserRouteStartWaypoint", { route_id = routeId, start_waypoint_id = startWaypointId } ).SUCCESS ).toBeTrue();
        expect( variables.api.routeBuilder( "addWaypointLegToUserRoute", { route_id = routeId, end_waypoint_id = middleWaypointId } ).SUCCESS ).toBeTrue();

        var routePayload = variables.api.routeBuilder( "getUserRoute", { route_id = routeId } );
        var previewPayload = variables.api.routeBuilder( "previewUserRoute", {
          route_id = routeId,
          route_type = "my_route",
          start_date = "2026-04-10"
        } );
        var routeLegId = val( routePayload.DATA.legs[ 1 ].route_leg_id ?: 0 );

        expect( routePayload.SUCCESS ).toBeTrue( serializeJSON( routePayload ) );
        expect( previewPayload.SUCCESS ).toBeTrue( serializeJSON( previewPayload ) );
        expect( routeLegId ).toBeGT( 0 );
        expect( variables.api.routeBuilder( "removeLegFromUserRoute", { route_id = routeId, route_leg_id = routeLegId } ).SUCCESS ).toBeTrue();
        expect( variables.api.routeBuilder( "deleteUserRoute", { route_id = routeId } ).SUCCESS ).toBeTrue();

        var reactivatePayload = variables.api.routeBuilder( "createUserRoute", { route_name = routeName } );
        expect( reactivatePayload.SUCCESS ).toBeTrue( serializeJSON( reactivatePayload ) );
      } );
    } );
  }

  private numeric function createWaypoint( required string prefix, required string label, required string latitude, required string longitude ) {
    var payload = variables.api.saveWaypoint( {
      waypointId = 0,
      name = variables.naming.buildName( prefix, label ),
      latitude = arguments.latitude,
      longitude = arguments.longitude,
      notes = label & " waypoint"
    } );
    var waypointId = val( payload.WAYPOINTID ?: 0 );
    arrayAppend( variables.created.waypointIds, waypointId );
    return waypointId;
  }
}
