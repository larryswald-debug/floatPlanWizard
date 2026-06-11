component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    variables.api = new fpw.tests.support.FpwApiSupport().init();
    variables.naming = new fpw.tests.support.FpwNamingSupport();
    variables.cleanup = new fpw.tests.support.FpwCleanupSupport();
    variables.cleanup.init( variables.api );
    variables.cleanup.cleanupCurrentRouteFloatPlanGroup();
    variables.created = { contactId = 0, passengerId = 0, waypointId = 0, vesselId = 0, operatorId = 0, floatPlanId = 0, routeCode = "" };
  }

  function afterAll() {
    if ( len( variables.created.routeCode ) ) {
      variables.cleanup.cleanupRoute( variables.created.routeCode );
    } else if ( variables.created.floatPlanId GT 0 ) {
      variables.cleanup.cleanupFloatPlan( variables.created.floatPlanId );
    }
    if ( variables.created.operatorId GT 0 ) variables.cleanup.cleanupOperator( variables.created.operatorId );
    if ( variables.created.vesselId GT 0 ) variables.cleanup.cleanupVessel( variables.created.vesselId );
    if ( variables.created.contactId GT 0 ) variables.cleanup.cleanupContact( variables.created.contactId );
    if ( variables.created.passengerId GT 0 ) variables.cleanup.cleanupPassenger( variables.created.passengerId );
    if ( variables.created.waypointId GT 0 ) variables.cleanup.cleanupWaypoint( variables.created.waypointId );
  }

  function run() {
    describe( "Contact, passenger, and waypoint CRUD contracts", function() {
      it( "validates required fields, saves records, lists them, and blocks delete while linked", function() {
        var prefix = variables.naming.buildPrefix( "contact-passenger-waypoint", "linked-delete" );
        var invalidContact = variables.api.saveContact( { contactId = 0 } );
        var invalidPassenger = variables.api.savePassenger( { passengerId = 0 } );
        var invalidWaypoint = variables.api.saveWaypoint( { waypointId = 0 } );

        var contactPayload = variables.api.saveContact( {
          contactId = 0,
          name = variables.naming.buildName( prefix, "AAA Contact" ),
          phone = "5555551212",
          email = variables.naming.buildEmail( prefix, "contact" )
        } );
        var passengerPayload = variables.api.savePassenger( {
          passengerId = 0,
          name = variables.naming.buildName( prefix, "AAA Passenger" ),
          phone = "5555551313",
          age = 37,
          gender = "Female",
          notes = "Passenger notes"
        } );
        var waypointPayload = variables.api.saveWaypoint( {
          waypointId = 0,
          name = variables.naming.buildName( prefix, "Waypoint" ),
          latitude = "27.950575",
          longitude = "-82.457178",
          notes = "Waypoint notes"
        } );

        variables.created.contactId = val( contactPayload.CONTACTID ?: 0 );
        variables.created.passengerId = val( passengerPayload.PASSENGERID ?: 0 );
        variables.created.waypointId = val( waypointPayload.WAYPOINTID ?: 0 );
        variables.created.vesselId = createVessel( prefix );
        variables.created.operatorId = createOperator( prefix );

        expect( invalidContact.SUCCESS ).toBeFalse( serializeJSON( invalidContact ) );
        expect( invalidPassenger.SUCCESS ).toBeFalse( serializeJSON( invalidPassenger ) );
        expect( invalidWaypoint.SUCCESS ).toBeFalse( serializeJSON( invalidWaypoint ) );

        expect( arrayLen( variables.api.listContacts( 1 ).CONTACTS ) ).toBeLTE( 1 );
        expect( arrayLen( variables.api.listPassengers( 1 ).PASSENGERS ) ).toBeLTE( 1 );
        expect( arrayLen( variables.api.listWaypoints( 1 ).WAYPOINTS ) ).toBeLTE( 1 );

        var linkedPlan = createLinkedManifestPlan( prefix );
        variables.created.floatPlanId = linkedPlan.planId;
        variables.created.routeCode = linkedPlan.routeCode;

        var contactDeleteCheck = variables.api.canDeleteContact( variables.created.contactId );
        var passengerDeleteCheck = variables.api.canDeletePassenger( variables.created.passengerId );
        var waypointDeleteCheck = variables.api.canDeleteWaypoint( variables.created.waypointId );

        expect( contactDeleteCheck.SUCCESS ).toBeTrue( serializeJSON( contactDeleteCheck ) );
        expect( contactDeleteCheck.CANDELETE ).toBeFalse( serializeJSON( contactDeleteCheck ) );
        expect( passengerDeleteCheck.SUCCESS ).toBeTrue( serializeJSON( passengerDeleteCheck ) );
        expect( passengerDeleteCheck.CANDELETE ).toBeFalse( serializeJSON( passengerDeleteCheck ) );
        expect( waypointDeleteCheck.SUCCESS ).toBeTrue( serializeJSON( waypointDeleteCheck ) );
        expect( waypointDeleteCheck.CANDELETE ).toBeFalse( serializeJSON( waypointDeleteCheck ) );
      } );
    } );
  }

  private numeric function createVessel( required string prefix ) {
    return val( variables.api.saveVessel( {
      vesselId = 0,
      vesselName = variables.naming.buildName( prefix, "Manifest Vessel" ),
      type = "Cruiser",
      length = 33,
      color = "White"
    } ).VESSELID ?: 0 );
  }

  private numeric function createOperator( required string prefix ) {
    return val( variables.api.saveOperator( {
      operatorId = 0,
      name = variables.naming.buildName( prefix, "Manifest Operator" )
    } ).OPERATORID ?: 0 );
  }

  private struct function createLinkedManifestPlan( required string prefix ) {
    var options = variables.api.routeBuilder( "routegen_getoptions", {
      template_code = "GULF-WEST",
      direction = "CCW"
    } );
    expect( options.SUCCESS ).toBeTrue( serializeJSON( options ) );

    var generate = variables.api.routeBuilder( "routegen_generate", {
      route_name = variables.naming.buildName( arguments.prefix, "Manifest Route" ),
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
      vesselId = variables.created.vesselId,
      rebuild = 0
    } );
    expect( buildPayload.SUCCESS ).toBeTrue( serializeJSON( buildPayload ) );

    var planId = val( buildPayload.FLOATPLAN_IDS[ 1 ] ?: 0 );
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
      NAME = variables.naming.buildName( arguments.prefix, "Linked Manifest Plan" ),
      VESSELID = variables.created.vesselId,
      OPERATORID = variables.created.operatorId,
      DEPARTING_FROM = "Manifest Dock",
      DEPARTURE_TIME = "2026-04-06T09:00",
      DEPARTURE_TIMEZONE = "US/Eastern",
      DEPARTURE_TIME_UTC = "2026-04-06 13:00:00",
      RETURNING_TO = "Manifest Dock",
      RETURN_TIME = "2026-04-06T18:00",
      RETURN_TIMEZONE = "US/Eastern",
      RETURN_TIME_UTC = "2026-04-06 22:00:00",
      EMAIL = "manifest@example.com",
      RESCUE_AUTHORITY = "USCG",
      RESCUE_AUTHORITY_PHONE = "5555551212"
    }, [ { PASSENGERID = variables.created.passengerId, SORT_ORDER = 1 } ], [ { CONTACTID = variables.created.contactId, SORT_ORDER = 1 } ], [ { WAYPOINTID = variables.created.waypointId, SORT_ORDER = 1 } ] );
    expect( savePayload.SUCCESS ).toBeTrue( serializeJSON( savePayload ) );

    return {
      planId = planId,
      routeCode = routeCode
    };
  }
}
