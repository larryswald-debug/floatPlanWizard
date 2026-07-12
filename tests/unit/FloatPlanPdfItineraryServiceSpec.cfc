component extends="testbox.system.BaseSpec" output="false" {

  function run() {
    describe( "FloatPlanPdfItineraryService", function() {
      beforeEach( function() {
        variables.service = new fpw.api.api_assets.FloatPlanPdfItineraryService().init( "fpw" );
      } );

      it( "builds a one-leg itinerary without continuation pages", function() {
        var model = buildModel( 1 );

        expect( arrayLen( model.legs ) ).toBe( 1 );
        expect( arrayLen( model.stops ) ).toBe( 2 );
        expect( model.stops[ 1 ].location ).toBe( "Stop 1" );
        expect( model.stops[ 2 ].location ).toBe( "Stop 2" );
        expect( model.stops[ 2 ].departureDate ).toBe( "" );
        expect( arrayLen( model.officialLegs ) ).toBe( 1 );
        expect( arrayLen( model.continuationPages ) ).toBe( 0 );
      } );

      it( "maps each intermediate stop arrival and next-leg departure", function() {
        var model = buildModel( 5 );

        expect( arrayLen( model.legs ) ).toBe( 5 );
        expect( arrayLen( model.stops ) ).toBe( 6 );
        expect( model.stops[ 2 ].arrivalTime ).toBe( model.legs[ 1 ].arrivalTime );
        expect( model.stops[ 2 ].departureTime ).toBe( model.legs[ 2 ].departureTime );
        expect( model.stops[ 6 ].arrivalTime ).toBe( model.legs[ 5 ].arrivalTime );
        expect( model.stops[ 6 ].departureTime ).toBe( "" );
      } );

      it( "uses the official page only for exactly twenty legs", function() {
        var model = buildModel( 20 );

        expect( arrayLen( model.officialLegs ) ).toBe( 20 );
        expect( arrayLen( model.continuationPages ) ).toBe( 0 );
        expect( model.officialLegs[ 20 ].routeLegOrder ).toBe( 20 );
      } );

      it( "puts leg twenty-one on one continuation page", function() {
        var model = buildModel( 21 );

        expect( arrayLen( model.officialLegs ) ).toBe( 20 );
        expect( arrayLen( model.continuationPages ) ).toBe( 1 );
        expect( arrayLen( model.continuationPages[ 1 ] ) ).toBe( 1 );
        expect( model.continuationPages[ 1 ][ 1 ].routeLegOrder ).toBe( 21 );
      } );

      it( "paginates forty-five legs without omission or duplication", function() {
        var model = buildModel( 45 );
        var emittedOrders = [];
        var pageIndex = 0;
        var rowIndex = 0;

        expect( arrayLen( model.officialLegs ) ).toBe( 20 );
        expect( arrayLen( model.continuationPages ) ).toBe( 2 );
        expect( arrayLen( model.continuationPages[ 1 ] ) ).toBe( 20 );
        expect( arrayLen( model.continuationPages[ 2 ] ) ).toBe( 5 );

        for ( rowIndex = 1; rowIndex LTE arrayLen( model.officialLegs ); rowIndex++ ) {
          arrayAppend( emittedOrders, model.officialLegs[ rowIndex ].routeLegOrder );
        }
        for ( pageIndex = 1; pageIndex LTE arrayLen( model.continuationPages ); pageIndex++ ) {
          for ( rowIndex = 1; rowIndex LTE arrayLen( model.continuationPages[ pageIndex ] ); rowIndex++ ) {
            arrayAppend( emittedOrders, model.continuationPages[ pageIndex ][ rowIndex ].routeLegOrder );
          }
        }

        expect( arrayLen( emittedOrders ) ).toBe( 45 );
        for ( rowIndex = 1; rowIndex LTE 45; rowIndex++ ) {
          expect( emittedOrders[ rowIndex ] ).toBe( rowIndex );
        }
      } );

      it( "converts overnight and multiday UTC timing into the trip timezone", function() {
        var startUtc = createDateTime( 2026, 7, 2, 2, 30, 0 );
        var model = buildModel( 8, startUtc );

        expect( model.legs[ 1 ].departureDate ).toBe( "07/01/26" );
        expect( model.legs[ 1 ].departureTime ).toBe( "22:30 EDT" );
        expect( model.legs[ 1 ].arrivalDate ).toBe( "07/02/26" );
        expect( model.legs[ 1 ].arrivalTime ).toBe( "01:30 EDT" );
        expect( model.legs[ 8 ].arrivalDate ).notToBe( model.legs[ 1 ].arrivalDate );
      } );

      it( "keeps legs and leaves values blank when canonical timing is missing", function() {
        var routeLegs = buildRouteLegs( 5 );
        var routeTimeline = buildRouteTimeline( 5, createDateTime( 2026, 7, 1, 12, 0, 0 ) );
        routeTimeline.legs[ 3 ].departureUtc = "";
        routeTimeline.legs[ 4 ].arrivalUtc = "";

        var model = variables.service.buildItineraryModel(
          routeLegs = routeLegs,
          routeTimeline = routeTimeline,
          timezone = "America/New_York",
          floatPlanId = 100,
          routeInstanceId = 200,
          planName = "Missing Timing"
        );

        expect( arrayLen( model.legs ) ).toBe( 5 );
        expect( model.legs[ 3 ].departureDate ).toBe( "" );
        expect( model.legs[ 3 ].departureTime ).toBe( "" );
        expect( model.legs[ 4 ].arrivalDate ).toBe( "" );
        expect( model.legs[ 4 ].arrivalTime ).toBe( "" );
        expect( arrayLen( model.warnings ) ).toBe( 2 );
      } );

      it( "rejects duplicate or missing canonical leg sequence values", function() {
        var routeLegs = buildRouteLegs( 5 );
        var thrownType = "";
        routeLegs[ 3 ].routeLegOrder = 4;

        try {
          variables.service.buildItineraryModel(
            routeLegs = routeLegs,
            routeTimeline = buildRouteTimeline( 5, createDateTime( 2026, 7, 1, 12, 0, 0 ) ),
            timezone = "America/New_York"
          );
        } catch ( any sequenceErr ) {
          thrownType = sequenceErr.type;
        }

        expect( findNoCase( "InvalidRouteSequence", thrownType ) ).toBeGT( 0 );
      } );

      it( "rejects broken origin-to-destination continuity", function() {
        var routeLegs = buildRouteLegs( 5 );
        var thrownType = "";
        routeLegs[ 3 ].fromName = "Different Stop";

        try {
          variables.service.buildItineraryModel(
            routeLegs = routeLegs,
            routeTimeline = buildRouteTimeline( 5, createDateTime( 2026, 7, 1, 12, 0, 0 ) ),
            timezone = "America/New_York"
          );
        } catch ( any continuityErr ) {
          thrownType = continuityErr.type;
        }

        expect( findNoCase( "RouteContinuityFailure", thrownType ) ).toBeGT( 0 );
      } );
    } );
  }

  private struct function buildModel(
    required numeric legCount,
    date startUtc = createDateTime( 2026, 7, 1, 12, 0, 0 )
  ) {
    return variables.service.buildItineraryModel(
      routeLegs = buildRouteLegs( arguments.legCount ),
      routeTimeline = buildRouteTimeline( arguments.legCount, arguments.startUtc ),
      timezone = "America/New_York",
      floatPlanId = 100,
      routeInstanceId = 200,
      planName = "Itinerary Test"
    );
  }

  private array function buildRouteLegs( required numeric legCount ) {
    var legs = [];
    var i = 0;

    for ( i = 1; i LTE arguments.legCount; i++ ) {
      arrayAppend( legs, {
        routeLegOrder = i,
        fromName = "Stop " & i,
        toName = "Stop " & ( i + 1 )
      } );
    }
    return legs;
  }

  private struct function buildRouteTimeline(
    required numeric legCount,
    required date startUtc
  ) {
    var timeline = { legs = [] };
    var i = 0;
    var departureUtc = "";
    var arrivalUtc = "";

    for ( i = 1; i LTE arguments.legCount; i++ ) {
      departureUtc = dateAdd( "h", ( i - 1 ) * 4, arguments.startUtc );
      arrivalUtc = dateAdd( "h", 3, departureUtc );
      arrayAppend( timeline.legs, {
        routeLegOrder = i,
        departureUtc = formatUtc( departureUtc ),
        arrivalUtc = formatUtc( arrivalUtc )
      } );
    }
    return timeline;
  }

  private string function formatUtc( required date value ) {
    return dateTimeFormat( arguments.value, "yyyy-mm-dd'T'HH:nn:ss'Z'" );
  }
}



