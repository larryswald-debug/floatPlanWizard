component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.api = new fpw.tests.support.FpwApiSupport().init();
  }

  function run() {
    describe( "Route template catalog and direction contracts", function() {
      it( "returns exactly the current three approved templates", function() {
        var payload = variables.api.routeBuilder( "listRouteTemplates", {} );
        var routes = [];
        var codes = [];
        var i = 0;

        expect( payload.SUCCESS ).toBeTrue( serializeJSON( payload ) );
        routes = payload.DATA.ROUTES;
        for ( i = 1; i LTE arrayLen( routes ); i++ ) {
          arrayAppend( codes, routes[ i ].SHORT_CODE );
        }

        expect( arrayLen( routes ) ).toBe( 3 );
        expect( arrayFind( codes, "GL_REUSE_V2" ) ).toBeGT( 0 );
        expect( arrayFind( codes, "GULF-WEST" ) ).toBeGT( 0 );
        expect( arrayFind( codes, "GULF-CORE" ) ).toBeGT( 0 );
      } );

      it( "returns the current GULF-CORE CCW and CW endpoints with no optional stops", function() {
        var ccw = variables.api.routeBuilder( "routegen_getoptions", {
          template_code = "GULF-CORE",
          direction = "CCW"
        } );
        var cw = variables.api.routeBuilder( "routegen_getoptions", {
          template_code = "GULF-CORE",
          direction = "CW"
        } );

        expect( ccw.SUCCESS ).toBeTrue( serializeJSON( ccw ) );
        expect( cw.SUCCESS ).toBeTrue( serializeJSON( cw ) );
        expect( ccw.DATA.startOptions[ 1 ].label ).toBe( "Mobile" );
        expect( ccw.DATA.endOptions[ arrayLen( ccw.DATA.endOptions ) ].label ).toBe( "Tarpon Springs" );
        expect( cw.DATA.startOptions[ 1 ].label ).toBe( "Tarpon Springs" );
        expect( cw.DATA.endOptions[ arrayLen( cw.DATA.endOptions ) ].label ).toBe( "Mobile" );
        expect( arrayLen( ccw.DATA.optionalStops ) ).toBe( 0 );
        expect( arrayLen( cw.DATA.optionalStops ) ).toBe( 0 );
      } );

      it( "returns the current optional-stop codes for GL_REUSE_V2 and GULF-WEST", function() {
        var greatLoop = variables.api.routeBuilder( "routegen_getoptions", {
          template_code = "GL_REUSE_V2",
          direction = "CCW"
        } );
        var gulfWest = variables.api.routeBuilder( "routegen_getoptions", {
          template_code = "GULF-WEST",
          direction = "CW"
        } );
        var greatLoopCodes = [];
        var gulfWestCodes = [];
        var i = 0;

        expect( greatLoop.SUCCESS ).toBeTrue( serializeJSON( greatLoop ) );
        expect( gulfWest.SUCCESS ).toBeTrue( serializeJSON( gulfWest ) );
        for ( i = 1; i LTE arrayLen( greatLoop.DATA.optionalStops ); i++ ) {
          arrayAppend( greatLoopCodes, greatLoop.DATA.optionalStops[ i ].code );
        }
        for ( i = 1; i LTE arrayLen( gulfWest.DATA.optionalStops ); i++ ) {
          arrayAppend( gulfWestCodes, gulfWest.DATA.optionalStops[ i ].code );
        }

        expect( arrayFind( greatLoopCodes, "GLD_KEYS_OUTSIDE" ) ).toBeGT( 0 );
        expect( arrayFind( greatLoopCodes, "GLD_CHAMPLAIN_STLAW" ) ).toBeGT( 0 );
        expect( arrayFind( gulfWestCodes, "ship_island_out_and_back" ) ).toBeGT( 0 );
        expect( arrayFind( gulfWestCodes, "grand_isle_side_trip" ) ).toBeGT( 0 );
      } );
    } );
  }
}
