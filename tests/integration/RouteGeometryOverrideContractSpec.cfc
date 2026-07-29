component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.api = new fpw.tests.support.FpwApiSupport().init();
    variables.naming = new fpw.tests.support.FpwNamingSupport();
    variables.cleanup = new fpw.tests.support.FpwCleanupSupport();
    variables.cleanup.init( variables.api );
    variables.created = { routeCode = "", waypointIds = [], userRouteId = 0 };
  }

  function afterAll() {
    if ( variables.created.userRouteId GT 0 ) variables.cleanup.cleanupUserRoute( variables.created.userRouteId );
    for ( var i = arrayLen( variables.created.waypointIds ); i GTE 1; i-- ) {
      variables.cleanup.cleanupWaypoint( variables.created.waypointIds[ i ] );
    }
    if ( len( variables.created.routeCode ) ) variables.cleanup.cleanupRoute( variables.created.routeCode );
  }

  function run() {
    describe( "Route geometry override contracts", function() {
      it( "saves and clears a generated-route leg override using current geometry", function() {
        var options = variables.api.routeBuilder( "routegen_getoptions", {
          template_code = "GULF-CORE",
          direction = "CCW"
        } );
        var input = {
          route_name = variables.naming.buildName( variables.naming.buildPrefix( "route-geometry-override", "generated-route" ), "Generated Route" ),
          template_code = "GULF-CORE",
          direction = "CCW",
          start_segment_id = options.DATA.startOptions[ 1 ].segment_id,
          end_segment_id = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].segment_id,
          start_location_label = options.DATA.startOptions[ 1 ].label,
          end_location_label = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].label,
          start_date = "2026-04-11"
        };
        var generate = variables.api.routeBuilder( "routegen_generate", input );
        var routeCode = trim( toString( generate.ROUTE_CODE ?: generate.DATA.route_code ?: "" ) );
        var geometry = variables.api.routeBuilder( "routegen_getleggeometry", {
          route_code = routeCode,
          leg_order = 1,
          segment_id = input.start_segment_id
        } );
        var routeLegId = val( geometry.DATA.route_leg_id ?: 0 );
        var overridePoints = [
          geometry.DATA.leg_start_point,
          geometry.DATA.leg_end_point
        ];
        var savePayload = variables.api.routeBuilder( "routegen_savelegoverride", {
          route_code = routeCode,
          route_leg_id = routeLegId,
          leg_order = 1,
          segment_id = input.start_segment_id,
          geometry = overridePoints
        } );
        var clearPayload = variables.api.routeBuilder( "routegen_clearlegoverride", {
          route_code = routeCode,
          route_leg_id = routeLegId,
          segment_id = input.start_segment_id,
          clear_segment_override = true
        } );

        variables.created.routeCode = routeCode;

        expect( geometry.SUCCESS ).toBeTrue( serializeJSON( geometry ) );
        expect( routeLegId ).toBeGT( 0 );
        expect( savePayload.SUCCESS ).toBeTrue( serializeJSON( savePayload ) );
        expect( clearPayload.SUCCESS ).toBeTrue( serializeJSON( clearPayload ) );
      } );

      it( "saves and clears a My Route leg override using current geometry", function() {
        var prefix = variables.naming.buildPrefix( "route-geometry-override", "my-route" );
        var startWaypointId = createWaypoint( prefix, "Start", "27.950575", "-82.457178" );
        var endWaypointId = createWaypoint( prefix, "End", "27.771889", "-82.638611" );
        var routePayload = variables.api.routeBuilder( "createUserRoute", {
          route_name = variables.naming.buildName( prefix, "Override Route" )
        } );
        var routeId = val( routePayload.DATA.route_id ?: 0 );
        var setStart = variables.api.routeBuilder( "setUserRouteStartWaypoint", {
          route_id = routeId,
          start_waypoint_id = startWaypointId
        } );
        var addLeg = variables.api.routeBuilder( "addWaypointLegToUserRoute", {
          route_id = routeId,
          end_waypoint_id = endWaypointId
        } );
        var routeData = variables.api.routeBuilder( "getUserRoute", { route_id = routeId } );
        var routeLegId = val( routeData.DATA.legs[ 1 ].route_leg_id ?: 0 );
        var currentGeometry = variables.api.routeBuilder( "getRouteLegOverrideGeometry", {
          route_id = routeId,
          route_leg_id = routeLegId
        } );
        var savePayload = variables.api.routeBuilder( "saveRouteLegOverrideGeometry", {
          route_id = routeId,
          route_leg_id = routeLegId,
          points = currentGeometry.DATA.points
        } );
        var clearPayload = variables.api.routeBuilder( "clearRouteLegOverrideGeometry", {
          route_id = routeId,
          route_leg_id = routeLegId
        } );

        variables.created.userRouteId = routeId;

        expect( setStart.SUCCESS ).toBeTrue( serializeJSON( setStart ) );
        expect( addLeg.SUCCESS ).toBeTrue( serializeJSON( addLeg ) );
        expect( savePayload.SUCCESS ).toBeTrue( serializeJSON( savePayload ) );
        expect( clearPayload.SUCCESS ).toBeTrue( serializeJSON( clearPayload ) );
      } );
    } );
  }

  private numeric function createWaypoint( required string prefix, required string label, required string latitude, required string longitude ) {
    var payload = variables.api.saveWaypoint( {
      waypointId = 0,
      name = variables.naming.buildName( prefix, label ),
      latitude = arguments.latitude,
      longitude = arguments.longitude
    } );
    var waypointId = val( payload.WAYPOINTID ?: 0 );
    arrayAppend( variables.created.waypointIds, waypointId );
    return waypointId;
  }
}
