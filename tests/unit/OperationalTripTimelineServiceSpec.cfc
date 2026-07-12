component extends="testbox.system.BaseSpec" output="false" {

  function run() {
    describe( "OperationalTripTimelineService", function() {
      it( "uses the Float Plan departure and makes 4 hours span more days than 8 hours", function() {
        var service = newService();
        var fourHours = service.calculateScheduledTimeline( snapshot(
          underwayHours = 4,
          legs = [ leg( 101, 1, 120, 10 ) ]
        ) );
        var eightHours = service.calculateScheduledTimeline( snapshot(
          underwayHours = 8,
          legs = [ leg( 101, 1, 120, 10 ) ]
        ) );

        expect( fourHours.success ).toBeTrue( serializeJSON( fourHours ) );
        expect( eightHours.success ).toBeTrue( serializeJSON( eightHours ) );
        expect( fourHours.scheduledTripDepartureLocal ).toBe( "2026-08-15 09:00:00" );
        expect( fourHours.scheduledTripDepartureUtc ).toBe( "2026-08-15T13:00:00Z" );
        expect( fourHours.operationalDayCount ).toBe( 3 );
        expect( eightHours.operationalDayCount ).toBe( 2 );
        expect( fourHours.finalScheduledArrivalUtc ).toBe( "2026-08-17T17:00:00Z" );
        expect( eightHours.finalScheduledArrivalUtc ).toBe( "2026-08-16T17:00:00Z" );
      } );

      it( "uses the original departure clock on subsequent days when Daily Start Time is absent", function() {
        var result = newService().calculateScheduledTimeline( snapshot(
          underwayHours = 6.5,
          legs = [ leg( 201, 1, 100, 10 ) ]
        ) );

        expect( result.success ).toBeTrue( serializeJSON( result ) );
        expect( result.resolvedDailyStartTime ).toBe( "09:00:00" );
        expect( result.dailyStartSource ).toBe( "floatplans.departureTime" );
        expect( result.legs[ 1 ].dailyWindowSegments[ 2 ].scheduledDepartureLocal ).toBe( "2026-08-16 09:00:00" );
        expect( result.finalScheduledArrivalLocal ).toBe( "2026-08-16 12:30:00" );
      } );

      it( "uses saved Daily Start Time and keeps a split leg identity", function() {
        var result = newService().calculateScheduledTimeline( snapshot(
          underwayHours = 6.5,
          dailyStart = "08:30",
          legs = [ leg( 301, 7, 100, 10 ) ]
        ) );

        expect( result.success ).toBeTrue( serializeJSON( result ) );
        expect( result.resolvedDailyStartTime ).toBe( "08:30:00" );
        expect( result.dailyStartSource ).toBe( "floatplans.dailyStartLocalTime" );
        expect( arrayLen( result.legs ) ).toBe( 1 );
        expect( result.legs[ 1 ].routeLegId ).toBe( 301 );
        expect( result.legs[ 1 ].routeLegOrder ).toBe( 7 );
        expect( arrayLen( result.legs[ 1 ].dailyWindowSegments ) ).toBe( 2 );
        expect( result.legs[ 1 ].dailyWindowSegments[ 2 ].scheduledDepartureLocal ).toBe( "2026-08-16 08:30:00" );
      } );

      it( "keeps multiple legs on the same day and counts lock duration inside the daily window", function() {
        var result = newService().calculateScheduledTimeline( snapshot(
          underwayHours = 4,
          legs = [
            leg( 401, 1, 10, 10 ),
            leg( 402, 2, 20, 10, 60 )
          ]
        ) );

        expect( result.success ).toBeTrue( serializeJSON( result ) );
        expect( result.operationalDayCount ).toBe( 1 );
        expect( result.legs[ 1 ].scheduledArrivalLocal ).toBe( "2026-08-15 10:00:00" );
        expect( result.legs[ 2 ].scheduledDepartureLocal ).toBe( "2026-08-15 10:00:00" );
        expect( result.legs[ 2 ].scheduledArrivalLocal ).toBe( "2026-08-15 13:00:00" );
        expect( result.lockDurationConsumesDailyWindow ).toBeTrue();
      } );

      it( "defaults invalid underway hours and permits a 24-hour window", function() {
        var invalid = newService().calculateScheduledTimeline( snapshot(
          underwayHours = "",
          legs = [ leg( 501, 1, 65, 10 ) ]
        ) );
        var maximum = newService().calculateScheduledTimeline( snapshot(
          underwayHours = 24,
          legs = [ leg( 502, 1, 240, 10 ) ]
        ) );

        expect( invalid.success ).toBeTrue( serializeJSON( invalid ) );
        expect( invalid.underwayHoursPerDay ).toBe( 6.5 );
        expect( invalid.degradedReason ).toBe( "UNDERWAY_HOURS_DEFAULTED" );
        expect( maximum.success ).toBeTrue( serializeJSON( maximum ) );
        expect( maximum.operationalDayCount ).toBe( 1 );
        expect( maximum.finalScheduledArrivalUtc ).toBe( "2026-08-16T13:00:00Z" );
      } );

      it( "anchors route reuse to August and never reuses a March preview date", function() {
        var input = snapshot(
          underwayHours = 6.5,
          legs = [
            leg( 601, 1, 30, 10 ),
            leg( 602, 2, 50, 10 )
          ]
        );
        input.routePlanningPreviewDate = "2026-03-10";

        var result = newService().calculateScheduledTimeline( input );
        var serialized = serializeJSON( result );

        expect( result.success ).toBeTrue( serialized );
        expect( result.legs[ 1 ].routeLegId ).toBe( 601 );
        expect( result.legs[ 2 ].routeLegId ).toBe( 602 );
        expect( result.legs[ 1 ].scheduledDepartureLocal ).toBe( "2026-08-15 09:00:00" );
        expect( findNoCase( "2026-03", serialized ) ).toBe( 0 );
      } );

      it( "converts subsequent local starts across the fall DST boundary", function() {
        var result = newService().calculateScheduledTimeline( {
          floatPlanId = 9002,
          routeInstanceId = 7002,
          sourceTimezone = "America/New_York",
          scheduledDepartureLocal = "2026-10-31 09:00:00",
          scheduledDepartureUtc = "2026-10-31T13:00:00Z",
          underwayHoursPerDay = 8,
          dailyStartLocalTime = "",
          routePreferredDailyStartTime = "",
          manualDelayMinutes = 0,
          initialDayUsedSeconds = 0,
          legs = [ leg( 701, 1, 160, 10 ) ]
        } );

        expect( result.success ).toBeTrue( serializeJSON( result ) );
        expect( result.legs[ 1 ].dailyWindowSegments[ 2 ].scheduledDepartureLocal ).toBe( "2026-11-01 09:00:00" );
        expect( result.legs[ 1 ].dailyWindowSegments[ 2 ].scheduledDepartureUtc ).toBe( "2026-11-01T14:00:00Z" );
        expect( result.finalScheduledArrivalUtc ).toBe( "2026-11-01T22:00:00Z" );
      } );

      it( "applies manual delay once without changing the fallback daily clock", function() {
        var input = snapshot(
          underwayHours = 4,
          legs = [ leg( 801, 1, 60, 10 ) ]
        );
        input.manualDelayMinutes = 60;

        var result = newService().calculateScheduledTimeline( input );

        expect( result.success ).toBeTrue( serializeJSON( result ) );
        expect( result.projectedTripDepartureLocal ).toBe( "2026-08-15 10:00:00" );
        expect( result.resolvedDailyStartTime ).toBe( "09:00:00" );
        expect( result.legs[ 1 ].dailyWindowSegments[ 2 ].scheduledDepartureLocal ).toBe( "2026-08-16 09:00:00" );
        expect( result.finalScheduledArrivalLocal ).toBe( "2026-08-16 11:00:00" );
      } );
    } );
  }

  private any function newService() {
    return new fpw.api.v1.OperationalTripTimelineService().init();
  }

  private struct function snapshot(
    required any underwayHours,
    required array legs,
    string dailyStart = ""
  ) {
    return {
      floatPlanId = 9001,
      routeInstanceId = 7001,
      sourceTimezone = "America/New_York",
      scheduledDepartureLocal = "2026-08-15 09:00:00",
      scheduledDepartureUtc = "2026-08-15T13:00:00Z",
      underwayHoursPerDay = arguments.underwayHours,
      dailyStartLocalTime = arguments.dailyStart,
      routePreferredDailyStartTime = "",
      manualDelayMinutes = 0,
      initialDayUsedSeconds = 0,
      legs = arguments.legs
    };
  }

  private struct function leg(
    required numeric routeLegId,
    required numeric routeLegOrder,
    required numeric distanceNm,
    required numeric effectiveSpeedKn,
    numeric lockDurationMinutes = 0
  ) {
    return {
      routeLegId = arguments.routeLegId,
      routeLegOrder = arguments.routeLegOrder,
      fromName = "Leg " & arguments.routeLegOrder & " Start",
      toName = "Leg " & arguments.routeLegOrder & " End",
      distanceNm = arguments.distanceNm,
      effectiveSpeedKn = arguments.effectiveSpeedKn,
      lockDurationMinutes = arguments.lockDurationMinutes
    };
  }

}
