component extends="testbox.system.BaseSpec" output="false" {

  function run() {
    describe("Final-arrival canonical projection contract", function() {

      beforeEach(function() {
        variables.projection = createObject(
          "component",
          "fpw.api.v1.TripProgressProjectionService"
        ).init("fpw");
        makePublic(variables.projection, "buildCurrentLeg", "buildCurrentLegForTest");
        makePublic(variables.projection, "buildCurrentLegProgress", "buildCurrentLegProgressForTest");
        makePublic(variables.projection, "buildEtaProjection", "buildEtaProjectionForTest");
        makePublic(variables.projection, "buildRouteTimeline", "buildRouteTimelineForTest");

        variables.activeCruise = createObject(
          "component",
          "fpw.api.v1.ActiveCruiseViewModelService"
        ).init("fpw");
        makePublic(variables.activeCruise, "buildCurrentLegSection", "buildCurrentLegSectionForTest");

        variables.voyage = createObject(
          "component",
          "fpw.api.v1.voyage"
        );
        makePublic(variables.voyage, "applyPublicAuthorityToFollowBootstrap", "applyPublicAuthorityToFollowBootstrapForTest");
      });

      it("normalizes the selected final completed leg and the overall route to 100 percent", function() {
        var result = buildProjection(
          statuses = [ "COMPLETED", "COMPLETED", "COMPLETED" ],
          startedAt = [
            "2026-08-17 12:00:00",
            "2026-08-17 13:00:00",
            "2026-08-17 14:00:00"
          ],
          completedAt = [
            "2026-08-17 12:45:00",
            "2026-08-17 13:45:00",
            "2026-08-17 14:45:00"
          ],
          segmentLegOrder = 3
        );
        var finalLeg = result.timeline.legs[3];

        expect(result.currentLeg.routeLegOrder).toBe(3);
        expect(result.currentLeg.status).toBe("COMPLETED");
        expect(result.progress.percentComplete).toBe(100);
        expect(result.progress.completedNm).toBe(30);
        expect(result.progress.remainingNm).toBe(0);
        expect(result.progress.statusLabel).toBe("Completed");
        expect(result.progress.paused).toBeFalse();
        expect(result.eta.available).toBeFalse();
        expect(result.eta.etaUtc).toBe("");
        expect(result.eta.remainingDurationSeconds).toBe(0);
        expect(result.timeline.summary.percentComplete).toBe(100);
        expect(result.timeline.summary.remainingNm).toBe(0);
        expect(finalLeg.state).toBe("completed");
        expect(finalLeg.isCompleted).toBeTrue();
        expect(finalLeg.isCurrent).toBeFalse();
        expect(finalLeg.percentComplete).toBe(100);
        expect(finalLeg.remainingNm).toBe(0);
        expect(finalLeg.remainingDurationSeconds).toBe(0);
      });

      it("changes a just-completed final leg from interpolation and ETA to canonical completion", function() {
        var before = buildProjection(
          statuses = [ "COMPLETED", "COMPLETED", "STARTED" ],
          startedAt = [
            "2026-08-17 12:00:00",
            "2026-08-17 13:00:00",
            "2026-08-17 15:30:00"
          ],
          completedAt = [
            "2026-08-17 12:45:00",
            "2026-08-17 13:45:00",
            ""
          ],
          segmentLegOrder = 3
        );
        var after = buildProjection(
          statuses = [ "COMPLETED", "COMPLETED", "COMPLETED" ],
          startedAt = [
            "2026-08-17 12:00:00",
            "2026-08-17 13:00:00",
            "2026-08-17 15:30:00"
          ],
          completedAt = [
            "2026-08-17 12:45:00",
            "2026-08-17 13:45:00",
            "2026-08-17 16:00:00"
          ],
          segmentLegOrder = 3
        );

        expect(before.currentLeg.status).toBe("STARTED");
        expect(before.progress.percentComplete).toBeGT(0);
        expect(before.progress.percentComplete).toBeLT(100);
        expect(before.progress.remainingNm).toBeGT(0);
        expect(before.eta.available).toBeTrue();
        expect(len(before.eta.etaUtc)).toBeGT(0);

        expect(after.currentLeg.status).toBe("COMPLETED");
        expect(after.progress.percentComplete).toBe(100);
        expect(after.progress.remainingNm).toBe(0);
        expect(after.eta.available).toBeFalse();
        expect(after.eta.etaUtc).toBe("");
        expect(after.eta.remainingDurationSeconds).toBe(0);
      });

      it("continues normal interpolation when an earlier leg is complete and a later leg is active", function() {
        var result = buildProjection(
          statuses = [ "COMPLETED", "STARTED", "NOT_STARTED" ],
          startedAt = [
            "2026-08-17 12:00:00",
            "2026-08-17 15:30:00",
            ""
          ],
          completedAt = [
            "2026-08-17 12:45:00",
            "",
            ""
          ],
          segmentLegOrder = 2
        );

        expect(result.currentLeg.routeLegOrder).toBe(2);
        expect(result.currentLeg.status).toBe("STARTED");
        expect(result.progress.statusLabel).toBe("Underway");
        expect(result.progress.percentComplete).toBe(25);
        expect(result.progress.remainingNm).toBe(15);
        expect(result.eta.available).toBeTrue();
        expect(result.timeline.summary.percentComplete).toBeGT(0);
        expect(result.timeline.summary.percentComplete).toBeLT(100);
        expect(result.timeline.legs[1].isCompleted).toBeTrue();
        expect(result.timeline.legs[2].isCurrent).toBeTrue();
        expect(result.timeline.legs[3].isFuture).toBeTrue();
      });

      it("publishes the normalized final leg through the shared Active Cruise and Follow view-model section", function() {
        var result = buildProjection(
          statuses = [ "COMPLETED", "COMPLETED", "COMPLETED" ],
          startedAt = [
            "2026-08-17 12:00:00",
            "2026-08-17 13:00:00",
            "2026-08-17 14:00:00"
          ],
          completedAt = [
            "2026-08-17 12:45:00",
            "2026-08-17 13:45:00",
            "2026-08-17 14:45:00"
          ],
          segmentLegOrder = 3
        );
        var qPlan = queryNew(
          "routegen_inputs_json",
          "varchar",
          [{ routegen_inputs_json = serializeJSON({ weather_factor_pct = 0 }) }]
        );
        var currentLeg = variables.activeCruise.buildCurrentLegSectionForTest(
          qPlan = qPlan,
          projection = {
            currentLeg = result.currentLeg,
            currentLegProgress = result.progress,
            etaProjection = result.eta
          },
          routeTimeline = result.timeline
        );

        expect(currentLeg.status).toBe("COMPLETED");
        expect(currentLeg.statusLabel).toBe("Completed");
        expect(currentLeg.percentComplete).toBe(100);
        expect(currentLeg.completedNm).toBe(30);
        expect(currentLeg.remainingNm).toBe(0);
        expect(currentLeg.remainingDurationSeconds).toBe(0);
        expect(currentLeg.etaUtc).toBe("");

        var activeCruiseSource = fileRead(expandPath("/fpw/app/active-cruise.cfm"), "utf-8");
        expect(findNoCase("activeCruiseV2CurrentLegCompleted", activeCruiseSource)).toBeGT(0);
        expect(findNoCase("Arrived Destination", activeCruiseSource)).toBeGT(0);
        expect(findNoCase("No future stop remains", activeCruiseSource)).toBeGT(0);
        expect(findNoCase("No future ETA remains", activeCruiseSource)).toBeGT(0);
      });

      it("renders an arrived destination as present location and not as a future Follow stop", function() {
        var payload = variables.voyage.applyPublicAuthorityToFollowBootstrapForTest(
          payload = {
            topCards = {
              location_label = "C",
              next_stop = "D",
              eta_utc = "2026-08-17T16:30:00Z",
              eta = "August 17, 2026 12:30 PM"
            },
            map = { next_stop_label = "D" }
          },
          authority = {
            identity = { floatPlanId = 987 },
            monitoring = { publicHealthLabel = "Arrived" },
            timing = {
              etaUtc = "",
              etaLocalLabel = "",
              milesTodayNm = 30,
              hoursToday = 2
            },
            progress = { percentComplete = 100 },
            currentLeg = { fromName = "C", toName = "D", status = "COMPLETED" },
            tripState = { code = "arrived", label = "Arrived", helperText = "The route is complete." }
          }
        );
        var source = fileRead(expandPath("/fpw/assets/js/app/follow/follow.js"), "utf-8");
        var followPageSource = fileRead(expandPath("/fpw/app/follow.cfm"), "utf-8");

        expect(payload.topCards.location_label).toBe("D");
        expect(payload.topCards.next_stop).toBe("");
        expect(payload.topCards.eta_utc).toBe("");
        expect(payload.topCards.eta).toBe("");
        expect(payload.map.next_stop_label).toBe("");
        expect(findNoCase("qa6-001-final-arrival", followPageSource)).toBeGT(0);
        expect(findNoCase('function isArrivedTrip(payload)', source)).toBeGT(0);
        expect(findNoCase('var nextStop = isArrived ? "—" : arrivedDestination', source)).toBeGT(0);
        expect(findNoCase('var etaUtc = isArrived ? "" :', source)).toBeGT(0);
        expect(findNoCase('isArrived ? "No future stop" : nextStopLocalEta', source)).toBeGT(0);
        expect(findNoCase('isArrived ? "Arrived at destination" : ("Heading: " + nextStop)', source)).toBeGT(0);
        expect(findNoCase('isArrived ? "No future stop" : ("Next stop: " + nextStop)', source)).toBeGT(0);
      });
    });
  }

  private struct function buildProjection(
    required array statuses,
    required array startedAt,
    required array completedAt,
    required numeric segmentLegOrder
  ) {
    var qProgress = buildProgressQuery(arguments.statuses, arguments.startedAt, arguments.completedAt);
    var qLegs = buildLegsQuery();
    var out = {
      routeInstanceId = 101,
      eventLedger = { count = 4 },
      authorityWarnings = []
    };
    var currentLeg = variables.projection.buildCurrentLegForTest(qProgress, qLegs, out);
    var segments = [{
      routeInstanceId = 101,
      routeLegOrder = arguments.segmentLegOrder,
      localTimezone = "America/New_York",
      segmentType = "UNDERWAY",
      startedAtUtc = "2026-08-17T15:30:00Z",
      endedAtUtc = "",
      expectedResumeAtUtc = "",
      actualResumeAtUtc = "",
      sourceStartEventId = 1,
      sourceEndEventId = 0,
      authority = "canonical"
    }];
    var asOfUtc = createDateTime(2026, 8, 17, 16, 0, 0);
    var progress = variables.projection.buildCurrentLegProgressForTest(
      currentLeg,
      segments,
      asOfUtc,
      10,
      out
    );
    var eta = variables.projection.buildEtaProjectionForTest(
      currentLeg,
      progress,
      [],
      segments,
      asOfUtc,
      10,
      0
    );
    var timeline = variables.projection.buildRouteTimelineForTest(
      queryNew("manual_delay_minutes_total", "integer", [{ manual_delay_minutes_total = 0 }]),
      qLegs,
      qProgress,
      currentLeg,
      progress,
      eta,
      segments,
      asOfUtc,
      10,
      out,
      { includeOperationalLockTime = false, allowDraftScheduledProjection = false },
      {}
    );

    return {
      currentLeg = currentLeg,
      progress = progress,
      eta = eta,
      timeline = timeline,
      warnings = out.authorityWarnings
    };
  }

  private query function buildProgressQuery(
    required array statuses,
    required array startedAt,
    required array completedAt
  ) {
    var rows = [];
    var i = 0;
    for (i = 1; i LTE arrayLen(arguments.statuses); i++) {
      arrayAppend(rows, {
        id = i,
        leg_order = i,
        status_val = arguments.statuses[i],
        leg_started_at = arguments.startedAt[i],
        completed_at = arguments.completedAt[i]
      });
    }
    return queryNew(
      "id,leg_order,status_val,leg_started_at,completed_at",
      "integer,integer,varchar,varchar,varchar",
      rows
    );
  }

  private query function buildLegsQuery() {
    return queryNew(
      "id,leg_order,start_name,end_name,base_dist_nm,lock_count,lock_route_code,lock_leg_order",
      "integer,integer,varchar,varchar,double,integer,varchar,integer",
      [
        { id = 1, leg_order = 1, start_name = "A", end_name = "B", base_dist_nm = 10, lock_count = 0, lock_route_code = "", lock_leg_order = 0 },
        { id = 2, leg_order = 2, start_name = "B", end_name = "C", base_dist_nm = 20, lock_count = 0, lock_route_code = "", lock_leg_order = 0 },
        { id = 3, leg_order = 3, start_name = "C", end_name = "D", base_dist_nm = 30, lock_count = 0, lock_route_code = "", lock_leg_order = 0 }
      ]
    );
  }
}
