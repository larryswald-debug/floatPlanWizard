component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.api = new fpw.tests.support.FpwApiSupport().init();
    variables.naming = new fpw.tests.support.FpwNamingSupport();
    variables.cleanup = new fpw.tests.support.FpwCleanupSupport();
    variables.cleanup.init( variables.api );
    variables.createdRouteCodes = [];
  }

  function afterAll() {
    for ( var i = arrayLen( variables.createdRouteCodes ); i GTE 1; i-- ) {
      variables.cleanup.cleanupRoute( variables.createdRouteCodes[ i ] );
    }
  }

  function run() {
    describe( "Route template preview, generate, edit-context, update, and delete contracts", function() {
      it( "previews, generates, loads edit context, updates, and deletes a GULF-CORE CCW route", function() {
        var options = variables.api.routeBuilder( "routegen_getoptions", {
          template_code = "GULF-CORE",
          direction = "CCW"
        } );
        var input = {
          route_name = variables.naming.buildName( variables.naming.buildPrefix( "route-template-lifecycle", "gulf-core-ccw" ), "Generated Route" ),
          template_code = "GULF-CORE",
          direction = "CCW",
          start_segment_id = options.DATA.startOptions[ 1 ].segment_id,
          end_segment_id = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].segment_id,
          start_location_label = options.DATA.startOptions[ 1 ].label,
          end_location_label = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].label,
          start_date = "2026-04-08"
        };
        var preview = variables.api.routeBuilder( "routegen_preview", input );
        var generate = variables.api.routeBuilder( "routegen_generate", input );
        var routeCode = trim( toString( generate.ROUTE_CODE ?: generate.DATA.route_code ?: "" ) );
        var editContext = variables.api.routeBuilder( "routegen_geteditcontext", { route_code = routeCode } );
        var updateInput = duplicate( input );
        updateInput.route_code = routeCode;
        var updatePayload = variables.api.routeBuilder( "routegen_update", updateInput );

        arrayAppend( variables.createdRouteCodes, routeCode );

        expect( preview.SUCCESS ).toBeTrue( serializeJSON( preview ) );
        expect( arrayLen( preview.DATA.legs ?: [] ) ).toBeGT( 0 );
        expect( generate.SUCCESS ).toBeTrue( serializeJSON( generate ) );
        expect( len( routeCode ) ).toBeGT( 0 );
        expect( editContext.SUCCESS ).toBeTrue( serializeJSON( editContext ) );
        expect( editContext.DATA.inputs.template_code ).toBe( "GULF-CORE" );
        expect( updatePayload.SUCCESS ).toBeTrue( serializeJSON( updatePayload ) );

        expect( variables.api.routeBuilder( "deleteRoute", { routeCode = routeCode } ).SUCCESS ).toBeTrue();
        arrayDeleteAt( variables.createdRouteCodes, arrayFind( variables.createdRouteCodes, routeCode ) );
      } );
    } );
  }
}
