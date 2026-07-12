component extends="testbox.system.BaseSpec" output="false" {

  function run() {
    describe( "TripProgressProjectionService operational timeline integration", function() {
      it( "uses Underway Hours/Day for pre-departure scheduled projection", function() {
        var service = newProjectionService();
        var qPlan = buildPlanQuery();
        var qLegs = buildLegQuery();
        var qProgress = queryNew( "leg_order,status_val,leg_started_at,completed_at" );
        var currentLeg = {
          routeLegOrder = 1,
          status = "NOT_STARTED",
          startedAtUtc = "",
          completedAtUtc = ""
        };
        var baseTimeline = buildBaseTimeline();
        var out = { routeInstanceId = 7001, authorityWarnings = [] };
        var options = { includeOperationalLockTime = false, allowDraftScheduledProjection = false };
        var asOfUtc = parseUtc( "2026-08-15T12:00:00Z" );

        var fourHours = service.buildScheduledRouteTimelineProjection(
          qPlan, qLegs, qProgress, currentLeg, asOfUtc, 10, baseTimeline, out, options,
          { underway_hours_per_day = 4 }
        );
        var eightHours = service.buildScheduledRouteTimelineProjection(
          qPlan, qLegs, qProgress, currentLeg, asOfUtc, 10, baseTimeline, out, options,
          { underway_hours_per_day = 8 }
        );

        expect( fourHours.available ).toBeTrue( serializeJSON( fourHours ) );
        expect( eightHours.available ).toBeTrue( serializeJSON( eightHours ) );
        expect( fourHours.legs[ 1 ].departureUtc ).toBe( "2026-08-15T13:00:00Z" );
        expect( fourHours.summary.operationalDayCount ).toBe( 3 );
        expect( eightHours.summary.operationalDayCount ).toBe( 2 );
        expect( fourHours.summary.finalArrivalUtc ).toBe( "2026-08-17T17:00:00Z" );
        expect( eightHours.summary.finalArrivalUtc ).toBe( "2026-08-16T17:00:00Z" );
      } );

      it( "keeps completed history fixed and applies daily windows only to current and future legs", function() {
        var service = newProjectionService();
        var qPlan = buildPlanQuery();
        var qLegs = buildLegQuery();
        var qProgress = queryNew(
          "leg_order,status_val,leg_started_at,completed_at",
          "integer,varchar,varchar,varchar",
          [
            { leg_order = 1, status_val = "COMPLETED", leg_started_at = "2026-08-15 13:00:00", completed_at = "2026-08-15 14:00:00" },
            { leg_order = 2, status_val = "STARTED", leg_started_at = "2026-08-15 14:00:00", completed_at = "" }
          ]
        );
        var currentLeg = {
          routeLegOrder = 2,
          status = "STARTED",
          startedAtUtc = "2026-08-15T14:00:00Z",
          completedAtUtc = "",
          distanceNm = 40
        };
        var currentProgress = {
          available = true,
          completedNm = 10,
          remainingNm = 30,
          percentComplete = 25
        };
        var etaProjection = {
          available = true,
          etaUtc = "2026-08-15T18:00:00Z",
          paused = false,
          expectedResumeAtUtc = "",
          remainingDurationSeconds = 10800
        };
        var out = {
          routeInstanceId = 7001,
          eventLedger = { count = 2 },
          authorityWarnings = []
        };

        var timeline = service.buildRouteTimeline(
          qPlan,
          qLegs,
          qProgress,
          currentLeg,
          currentProgress,
          etaProjection,
          [ { segmentType = "UNDERWAY" } ],
          parseUtc( "2026-08-15T15:00:00Z" ),
          10,
          out,
          { includeOperationalLockTime = false, allowDraftScheduledProjection = false },
          {},
          { underway_hours_per_day = 4 },
          { underwaySeconds = 7200 },
          "America/New_York"
        );

        expect( timeline.available ).toBeTrue( serializeJSON( timeline ) );
        expect( timeline.legs[ 1 ].departureUtc ).toBe( "2026-08-15T13:00:00Z" );
        expect( timeline.legs[ 1 ].arrivalUtc ).toBe( "2026-08-15T14:00:00Z" );
        expect( timeline.legs[ 1 ].arrivalSource ).toBe( "route_instance_leg_progress.completed_at" );
        expect( timeline.legs[ 2 ].arrivalUtc ).toBe( "2026-08-16T14:00:00Z" );
        expect( timeline.legs[ 2 ].arrivalSource ).toBe( "OperationalTripTimelineService.current_remaining_projection" );
      } );

      it( "uses Secure for Night expected resume as the unresolved projection anchor", function() {
        var service = newProjectionService();
        var qPlan = buildPlanQuery( "08:30:00" );
        var qLegs = buildLegQuery();
        var qProgress = queryNew(
          "leg_order,status_val,leg_started_at,completed_at",
          "integer,varchar,varchar,varchar",
          [
            { leg_order = 1, status_val = "STARTED", leg_started_at = "2026-08-15 13:00:00", completed_at = "" }
          ]
        );
        var timeline = service.buildRouteTimeline(
          qPlan,
          qLegs,
          qProgress,
          { routeLegOrder = 1, status = "STARTED", startedAtUtc = "2026-08-15T13:00:00Z", completedAtUtc = "", distanceNm = 80 },
          { available = true, completedNm = 20, remainingNm = 60, percentComplete = 25 },
          {
            available = true,
            etaUtc = "2026-08-16T18:30:00Z",
            paused = true,
            expectedResumeAtUtc = "2026-08-16T12:30:00Z",
            remainingDurationSeconds = 21600
          },
          [ { segmentType = "PAUSED_SECURE_FOR_NIGHT" } ],
          parseUtc( "2026-08-15T17:00:00Z" ),
          10,
          { routeInstanceId = 7001, eventLedger = { count = 1 }, authorityWarnings = [] },
          { includeOperationalLockTime = false, allowDraftScheduledProjection = false },
          {},
          { underway_hours_per_day = 4 },
          { underwaySeconds = 14400 },
          "America/New_York"
        );

        expect( timeline.available ).toBeTrue( serializeJSON( timeline ) );
        expect( timeline.legs[ 1 ].dailyWindowSegments[ 1 ].scheduledDepartureUtc ).toBe( "2026-08-16T12:30:00Z" );
        expect( timeline.legs[ 1 ].arrivalUtc ).toBe( "2026-08-17T14:30:00Z" );
        expect( timeline.paused ).toBeTrue();
      } );
    } );
  }

  private any function newProjectionService() {
    var service = new fpw.api.v1.TripProgressProjectionService().init( "fpw" );
    makePublic( service, "buildScheduledRouteTimelineProjection" );
    makePublic( service, "buildRouteTimeline" );
    return service;
  }

  private query function buildPlanQuery( string dailyStart = "" ) {
    return queryNew(
      "floatPlanId,userId,status,route_instance_id,departureTZ,departTimezone,dailyStartLocalTime,departureTime,departureTimeUTC,manual_delay_minutes_total",
      "integer,integer,varchar,integer,varchar,varchar,varchar,timestamp,varchar,integer",
      [ {
        floatPlanId = 9001,
        userId = 1,
        status = "ACTIVE",
        route_instance_id = 7001,
        departureTZ = "America/New_York",
        departTimezone = "America/New_York",
        dailyStartLocalTime = arguments.dailyStart,
        departureTime = parseDateTime( "2026-08-15 09:00:00" ),
        departureTimeUTC = "2026-08-15 13:00:00",
        manual_delay_minutes_total = 0
      } ]
    );
  }

  private query function buildLegQuery() {
    return queryNew(
      "id,leg_order,start_name,end_name,base_dist_nm,lock_route_code,lock_leg_order,lock_count",
      "integer,integer,varchar,varchar,double,varchar,integer,integer",
      [
        { id = 101, leg_order = 1, start_name = "March Preview Start", end_name = "Middle", base_dist_nm = 80, lock_route_code = "", lock_leg_order = 0, lock_count = 0 },
        { id = 102, leg_order = 2, start_name = "Middle", end_name = "August Finish", base_dist_nm = 40, lock_route_code = "", lock_leg_order = 0, lock_count = 0 }
      ]
    );
  }

  private struct function buildBaseTimeline() {
    return {
      available = false,
      authority = "canonical_projection",
      generatedAtUtc = "",
      routeInstanceId = 7001,
      currentLegOrder = 1,
      paused = false,
      expectedResumeAtUtc = "",
      effectiveSpeedKn = 10,
      pace = {},
      manualDelayMinutesTotal = 0,
      usesLatestCheckinAsAnchor = false,
      summary = {},
      legs = [],
      warnings = []
    };
  }

  private date function parseUtc( required string value ) {
    var normalized = replace( arguments.value, "T", " ", "one" );
    normalized = replace( normalized, "Z", "", "one" );
    return parseDateTime( normalized );
  }

}
