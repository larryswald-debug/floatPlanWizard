component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.api = new fpw.tests.support.FpwApiSupport().init();
    variables.naming = new fpw.tests.support.FpwNamingSupport();
    variables.cleanup = new fpw.tests.support.FpwCleanupSupport();
    variables.cleanup.init( variables.api );
    variables.created = {
      vesselId = 0,
      operatorId = 0,
      floatPlanId = 0,
      routeCode = ""
    };
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
    describe( "Float plan timezone persistence", function() {
      it( "persists the approved supported timezone values on save and bootstrap reload", function() {
        var prefix = variables.naming.buildPrefix( "float-plan-timezone-conversion", "approved-zones" );
        var timezones = [ "America/New_York", "US/Eastern", "US/Central", "US/Mountain", "US/Pacific", "US/Alaska", "US/Hawaii", "America/Puerto_Rico" ];
        var vesselId = createVessel( prefix );
        var operatorId = createOperator( prefix );
        var routeDraft = {};

        variables.created.vesselId = vesselId;
        variables.created.operatorId = operatorId;
        routeDraft = createRouteLinkedDraftPlan( prefix, vesselId );
        variables.created.floatPlanId = routeDraft.planId;
        variables.created.routeCode = routeDraft.routeCode;

        for ( var zone in timezones ) {
          var savePayload = variables.api.saveFloatPlan(
            buildFloatPlanStruct( prefix, vesselId, operatorId, zone, routeDraft.planId, routeDraft.routeInstanceId, routeDraft.routeDayNumber ),
            [],
            [],
            []
          );
          var planId = val( savePayload.FLOATPLAN.FLOATPLANID ?: savePayload.FLOATPLANID ?: 0 );

          var bootstrap = variables.api.bootstrapFloatPlan( planId );
          expect( bootstrap.SUCCESS ).toBeTrue( serializeJSON( bootstrap ) );
          expect( bootstrap.FLOATPLAN.DEPARTURE_TIMEZONE ).toBe( zone );
          expect( bootstrap.FLOATPLAN.RETURN_TIMEZONE ).toBe( zone );
        }
      } );
    } );
  }

  private numeric function createVessel( required string prefix ) {
    var payload = variables.api.saveVessel( {
      vesselId = 0,
      vesselName = variables.naming.buildName( prefix, "Timezone Vessel" ),
      type = "Cruiser",
      length = 34,
      color = "White"
    } );
    return val( payload.VESSELID ?: 0 );
  }

  private numeric function createOperator( required string prefix ) {
    var payload = variables.api.saveOperator( {
      operatorId = 0,
      name = variables.naming.buildName( prefix, "Timezone Operator" )
    } );
    return val( payload.OPERATORID ?: 0 );
  }

  private struct function buildFloatPlanStruct(
    required string prefix,
    required numeric vesselId,
    required numeric operatorId,
    required string timezone,
    required numeric floatPlanId,
    required numeric routeInstanceId,
    required numeric routeDayNumber
  ) {
    return {
      FLOATPLANID = arguments.floatPlanId,
      floatPlanId = arguments.floatPlanId,
      NAME = variables.naming.buildName( prefix, timezone ),
      VESSELID = arguments.vesselId,
      OPERATORID = arguments.operatorId,
      ROUTE_INSTANCE_ID = arguments.routeInstanceId,
      routeInstanceId = arguments.routeInstanceId,
      ROUTE_DAY_NUMBER = arguments.routeDayNumber,
      routeDayNumber = arguments.routeDayNumber,
      DEPARTING_FROM = "Timezone Dock",
      DEPARTURE_TIME = "2026-04-01T09:00",
      DEPARTURE_TIMEZONE = arguments.timezone,
      RETURNING_TO = "Timezone Dock",
      RETURN_TIME = "2026-04-02T17:00",
      RETURN_TIMEZONE = arguments.timezone,
      EMAIL = "timezone@example.com",
      RESCUE_AUTHORITY = "USCG",
      RESCUE_AUTHORITY_PHONE = "5555551212"
    };
  }

  private struct function createRouteLinkedDraftPlan( required string prefix, required numeric vesselId ) {
    var options = variables.api.routeBuilder( "routegen_getoptions", {
      template_code = "GULF-WEST",
      direction = "CCW"
    } );
    expect( options.SUCCESS ).toBeTrue( serializeJSON( options ) );

    var generate = variables.api.routeBuilder( "routegen_generate", {
      route_name = variables.naming.buildName( arguments.prefix, "Timezone Route" ),
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

    var routeCode = trim( toString( generate.ROUTE_CODE ?: generate.DATA.route_code ?: "" ) );
    var buildPayload = variables.api.routeBuilder( "buildFloatPlansFromRoute", {
      routeCode = routeCode,
      mode = "DAILY",
      vesselId = arguments.vesselId,
      rebuild = 0
    } );
    expect( buildPayload.SUCCESS ).toBeTrue( serializeJSON( buildPayload ) );

    var planId = val( buildPayload.FLOATPLAN_IDS[ 1 ] ?: 0 );
    var bootstrap = variables.api.bootstrapFloatPlan( planId );
    expect( bootstrap.SUCCESS ).toBeTrue( serializeJSON( bootstrap ) );

    return {
      planId = planId,
      routeCode = routeCode,
      routeInstanceId = val( bootstrap.FLOATPLAN.ROUTE_INSTANCE_ID ?: 0 ),
      routeDayNumber = val( bootstrap.FLOATPLAN.ROUTE_DAY_NUMBER ?: 0 )
    };
  }
}
