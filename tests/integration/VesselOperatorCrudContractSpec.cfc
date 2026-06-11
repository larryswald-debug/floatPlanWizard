component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.api = new fpw.tests.support.FpwApiSupport().init();
    variables.naming = new fpw.tests.support.FpwNamingSupport();
    variables.cleanup = new fpw.tests.support.FpwCleanupSupport();
    variables.cleanup.init( variables.api );
    variables.cleanup.cleanupCurrentRouteFloatPlanGroup();
    variables.created = { vesselId = 0, operatorId = 0, floatPlanId = 0, routeCode = "" };
  }

  function afterAll() {
    if ( len( variables.created.routeCode ) ) {
      variables.cleanup.cleanupRoute( variables.created.routeCode );
    } else if ( variables.created.floatPlanId GT 0 ) {
      variables.cleanup.cleanupFloatPlan( variables.created.floatPlanId );
    }
    if ( variables.created.operatorId GT 0 ) variables.cleanup.cleanupOperator( variables.created.operatorId );
    if ( variables.created.vesselId GT 0 ) variables.cleanup.cleanupVessel( variables.created.vesselId );
  }

  function run() {
    describe( "Vessel and operator CRUD contracts", function() {
      it( "validates required fields, saves records, lists them, and blocks delete while linked", function() {
        var prefix = variables.naming.buildPrefix( "vessel-operator-crud", "linked-delete" );
        var invalidVessel = variables.api.saveVessel( { vesselId = 0 } );
        var invalidOperator = variables.api.saveOperator( { operatorId = 0 } );
        var vesselPayload = variables.api.saveVessel( {
          vesselId = 0,
          vesselName = variables.naming.buildName( prefix, "Vessel" ),
          type = "Cruiser",
          length = 38,
          color = "White",
          registration = "FL-TB-001"
        } );
        var operatorPayload = variables.api.saveOperator( {
          operatorId = 0,
          name = variables.naming.buildName( prefix, "Operator" ),
          phone = "5555551212",
          notes = "Operator notes"
        } );

        variables.created.vesselId = val( vesselPayload.VESSELID ?: 0 );
        variables.created.operatorId = val( operatorPayload.OPERATORID ?: 0 );

        expect( invalidVessel.SUCCESS ).toBeFalse( serializeJSON( invalidVessel ) );
        expect( invalidOperator.SUCCESS ).toBeFalse( serializeJSON( invalidOperator ) );
        expect( variables.created.vesselId ).toBeGT( 0 );
        expect( variables.created.operatorId ).toBeGT( 0 );

        var vesselList = variables.api.listVessels( 1 );
        var operatorList = variables.api.listOperators( 1 );
        expect( arrayLen( vesselList.VESSELS ) ).toBeLTE( 1 );
        expect( arrayLen( operatorList.OPERATORS ) ).toBeLTE( 1 );

        var updatedVessel = variables.api.saveVessel( {
          vesselId = variables.created.vesselId,
          vesselName = variables.naming.buildName( prefix, "Vessel Updated" ),
          type = "Cruiser",
          length = 38,
          color = "Blue"
        } );
        var updatedOperator = variables.api.saveOperator( {
          operatorId = variables.created.operatorId,
          name = variables.naming.buildName( prefix, "Operator Updated" ),
          phone = "5555552222",
          notes = "Updated notes"
        } );
        expect( updatedVessel.SUCCESS ).toBeTrue( serializeJSON( updatedVessel ) );
        expect( updatedOperator.SUCCESS ).toBeTrue( serializeJSON( updatedOperator ) );

        var linkedPlan = createLinkedFloatPlan( prefix, variables.created.vesselId, variables.created.operatorId );
        variables.created.floatPlanId = linkedPlan.planId;
        variables.created.routeCode = linkedPlan.routeCode;
        var vesselDeleteCheck = variables.api.canDeleteVessel( variables.created.vesselId );
        var operatorDeleteCheck = variables.api.canDeleteOperator( variables.created.operatorId );

        expect( vesselDeleteCheck.SUCCESS ).toBeTrue( serializeJSON( vesselDeleteCheck ) );
        expect( vesselDeleteCheck.CANDELETE ).toBeFalse( serializeJSON( vesselDeleteCheck ) );
        expect( operatorDeleteCheck.SUCCESS ).toBeTrue( serializeJSON( operatorDeleteCheck ) );
        expect( operatorDeleteCheck.CANDELETE ).toBeFalse( serializeJSON( operatorDeleteCheck ) );
      } );
    } );
  }

  private struct function createLinkedFloatPlan( required string prefix, required numeric vesselId, required numeric operatorId ) {
    var options = variables.api.routeBuilder( "routegen_getoptions", {
      template_code = "GULF-WEST",
      direction = "CCW"
    } );
    var generate = {};
    var routeCode = "";
    var buildPayload = {};
    var planId = 0;

    expect( options.SUCCESS ).toBeTrue( serializeJSON( options ) );
    generate = variables.api.routeBuilder( "routegen_generate", {
      route_name = variables.naming.buildName( prefix, "Linked Vessel Operator Route" ),
      template_code = "GULF-WEST",
      direction = "CCW",
      start_segment_id = options.DATA.startOptions[ 1 ].segment_id,
      end_segment_id = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].segment_id,
      start_location_label = options.DATA.startOptions[ 1 ].label,
      end_location_label = options.DATA.endOptions[ arrayLen( options.DATA.endOptions ) ].label,
      start_date = "2026-04-09",
      optional_stop_flags = [ "ship_island_out_and_back" ]
    } );
    expect( generate.SUCCESS ).toBeTrue( serializeJSON( generate ) );

    routeCode = trim( toString( generate.ROUTE_CODE ?: generate.DATA.route_code ?: "" ) );
    buildPayload = variables.api.routeBuilder( "buildFloatPlansFromRoute", {
      routeCode = routeCode,
      mode = "DAILY",
      vesselId = arguments.vesselId,
      rebuild = 0
    } );
    expect( buildPayload.SUCCESS ).toBeTrue( serializeJSON( buildPayload ) );
    planId = val( buildPayload.FLOATPLAN_IDS[ 1 ] ?: 0 );
    expect( planId ).toBeGT( 0, serializeJSON( buildPayload ) );
    var bootstrap = variables.api.bootstrapFloatPlan( planId );
    expect( val( bootstrap.FLOATPLAN.ROUTE_INSTANCE_ID ?: 0 ) ).toBeGT( 0, serializeJSON( bootstrap ) );

    var savePayload = variables.api.saveFloatPlan( {
      FLOATPLANID = planId,
      floatPlanId = planId,
      ROUTE_INSTANCE_ID = val( bootstrap.FLOATPLAN.ROUTE_INSTANCE_ID ?: 0 ),
      routeInstanceId = val( bootstrap.FLOATPLAN.ROUTE_INSTANCE_ID ?: 0 ),
      ROUTE_DAY_NUMBER = val( bootstrap.FLOATPLAN.ROUTE_DAY_NUMBER ?: 0 ),
      routeDayNumber = val( bootstrap.FLOATPLAN.ROUTE_DAY_NUMBER ?: 0 ),
      NAME = variables.naming.buildName( prefix, "Linked Vessel Operator Plan" ),
      VESSELID = arguments.vesselId,
      OPERATORID = arguments.operatorId,
      DEPARTING_FROM = "Linked Dock",
      DEPARTURE_TIME = "2026-04-05T09:00",
      DEPARTURE_TIMEZONE = "US/Eastern",
      DEPARTURE_TIME_UTC = "2026-04-05 13:00:00",
      RETURNING_TO = "Linked Dock",
      RETURN_TIME = "2026-04-05T18:00",
      RETURN_TIMEZONE = "US/Eastern",
      RETURN_TIME_UTC = "2026-04-05 22:00:00",
      EMAIL = "linked@example.com",
      RESCUE_AUTHORITY = "USCG",
      RESCUE_AUTHORITY_PHONE = "5555551212"
    }, [], [], [] );
    expect( savePayload.SUCCESS ).toBeTrue( serializeJSON( savePayload ) );

    return {
      planId = planId,
      routeCode = routeCode
    };
  }
}
