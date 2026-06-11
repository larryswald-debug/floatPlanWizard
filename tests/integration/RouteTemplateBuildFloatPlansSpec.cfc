component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.api = new fpw.tests.support.FpwApiSupport().init();
    variables.naming = new fpw.tests.support.FpwNamingSupport();
    variables.cleanup = new fpw.tests.support.FpwCleanupSupport();
    variables.cleanup.init( variables.api );
    variables.created = { vesselId = 0, routeCode = "", floatPlanIds = [] };
  }

  function afterAll() {
    if ( len( variables.created.routeCode ) ) variables.cleanup.cleanupRoute( variables.created.routeCode );
    if ( variables.created.vesselId GT 0 ) variables.cleanup.cleanupVessel( variables.created.vesselId );
  }

  function run() {
    describe( "Build float plans from generated routes", function() {
      it( "builds draft float plans and returns the current existing-drafts guardrail", function() {
        var prefix = variables.naming.buildPrefix( "route-template-build", "daily-drafts" );
        variables.created.vesselId = val( variables.api.saveVessel( {
          vesselId = 0,
          vesselName = variables.naming.buildName( prefix, "Build Vessel" ),
          type = "Cruiser",
          length = 34,
          color = "White"
        } ).VESSELID ?: 0 );

        var options = variables.api.routeBuilder( "routegen_getoptions", {
          template_code = "GULF-WEST",
          direction = "CCW"
        } );
        var input = {
          route_name = variables.naming.buildName( prefix, "Generated Route" ),
          template_code = "GULF-WEST",
          direction = "CCW",
          start_segment_id = options.DATA.startOptions[ 1 ].segment_id,
          end_segment_id = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].segment_id,
          start_location_label = options.DATA.startOptions[ 1 ].label,
          end_location_label = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].label,
          start_date = "2026-04-09",
          optional_stop_flags = [ "ship_island_out_and_back" ]
        };
        var generate = variables.api.routeBuilder( "routegen_generate", input );
        variables.created.routeCode = trim( toString( generate.ROUTE_CODE ?: generate.DATA.route_code ?: "" ) );

        var buildPayload = variables.api.routeBuilder( "buildFloatPlansFromRoute", {
          routeCode = variables.created.routeCode,
          mode = "DAILY",
          vesselId = variables.created.vesselId,
          rebuild = 0
        } );
        for ( var id in buildPayload.FLOATPLAN_IDS ) {
          arrayAppend( variables.created.floatPlanIds, id );
        }

        var buildAgain = variables.api.routeBuilder( "buildFloatPlansFromRoute", {
          routeCode = variables.created.routeCode,
          mode = "DAILY",
          vesselId = variables.created.vesselId,
          rebuild = 0
        } );

        expect( buildPayload.SUCCESS ).toBeTrue( serializeJSON( buildPayload ) );
        expect( val( buildPayload.CREATED_COUNT ) ).toBeGT( 0 );
        expect( buildAgain.SUCCESS ).toBeTrue( serializeJSON( buildAgain ) );
        expect( !!buildAgain.REUSED_EXISTING ).toBeTrue( serializeJSON( buildAgain ) );
        expect( val( buildAgain.FLOATPLAN_IDS[ 1 ] ?: 0 ) ).toBe( val( buildPayload.FLOATPLAN_IDS[ 1 ] ?: 0 ) );
      } );
    } );
  }
}
