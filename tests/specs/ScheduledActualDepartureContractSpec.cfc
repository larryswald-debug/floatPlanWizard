component extends="testbox.system.BaseSpec" output="false" {

  function run() {
    describe("Scheduled versus actual departure contract", function() {

      beforeEach(function() {
        variables.activeCruiseService = createObject(
          "component",
          "fpw.api.v1.ActiveCruiseViewModelService"
        ).init("fpw");
        makePublic(
          variables.activeCruiseService,
          "buildFloatPlanSection",
          "buildFloatPlanSectionForContractTest"
        );
      });

      it("exposes the five additive fields and keeps Actual Departure null before route start", function() {
        var model = variables.activeCruiseService.buildFloatPlanSectionForContractTest(
          buildPlanQuery(
            "2026-08-02 14:00:00",
            "2026-08-02 10:00:00",
            "",
            ""
          )
        );

        expect(structKeyExists(model, "scheduledDepartureAtUtc")).toBeTrue();
        expect(structKeyExists(model, "scheduledDepartureLocalLabel")).toBeTrue();
        expect(structKeyExists(model, "actualDepartureLocalLabel")).toBeTrue();
        expect(structKeyExists(model, "hasActualDeparture")).toBeTrue();
        expect(model.scheduledDepartureAtUtc).toBe("2026-08-02T14:00:00Z");
        expect(findNoCase("Aug 2, 2026 10:00 AM", model.scheduledDepartureLocalLabel)).toBeGT(0);
        expect(isNull(model.actualDepartureAtUtc)).toBeTrue();
        expect(findNoCase('"actualDepartureAtUtc":null', serializeJSON(model))).toBeGT(0);
        expect(model.actualDepartureLocalLabel).toBe("");
        expect(model.hasActualDeparture).toBeFalse();
      });

      it("uses route_instances.started_at as Actual Departure and does not fallback to first-leg start", function() {
        var startedModel = variables.activeCruiseService.buildFloatPlanSectionForContractTest(
          buildPlanQuery(
            "2026-08-02 14:00:00",
            "2026-08-02 10:00:00",
            "2026-08-02 12:30:00",
            "2026-08-02 12:30:00"
          )
        );
        var inconsistentModel = variables.activeCruiseService.buildFloatPlanSectionForContractTest(
          buildPlanQuery(
            "2026-08-02 14:00:00",
            "2026-08-02 10:00:00",
            "",
            "2026-08-02 12:30:00"
          )
        );
        var source = readRepoFile("api/v1/ActiveCruiseViewModelService.cfc");

        expect(startedModel.scheduledDepartureAtUtc).toBe("2026-08-02T14:00:00Z");
        expect(startedModel.actualDepartureAtUtc).toBe("2026-08-02T12:30:00Z");
        expect(findNoCase("Aug 2, 2026 8:30 AM", startedModel.actualDepartureLocalLabel)).toBeGT(0);
        expect(startedModel.hasActualDeparture).toBeTrue();
        expect(isNull(inconsistentModel.actualDepartureAtUtc)).toBeTrue();
        expect(findNoCase('"actualDepartureAtUtc":null', serializeJSON(inconsistentModel))).toBeGT(0);
        expect(inconsistentModel.hasActualDeparture).toBeFalse();
        expect(findNoCase(
          "var actualDepartureAtUtc = formatRawUtc(arguments.qPlan.routeStartedAtUtcRaw[1])",
          source
        )).toBeGT(0);
        expect(findNoCase(
          "DATE_FORMAT(ri.started_at, '%Y-%m-%d %H:%i:%s') AS routeStartedAtUtcRaw",
          source
        )).toBeGT(0);
        expect(findNoCase("AND ri.user_id = fp.userId", source)).toBeGT(0);
      });

      it("formats UTC departure labels without java.time and preserves Eastern DST", function() {
        var summerModel = variables.activeCruiseService.buildFloatPlanSectionForContractTest(
          buildPlanQuery(
            "2026-08-02 15:00:00",
            "2026-08-02 11:00:00",
            "2026-08-02 17:55:41",
            "",
            "US/Eastern"
          )
        );
        var winterModel = variables.activeCruiseService.buildFloatPlanSectionForContractTest(
          buildPlanQuery(
            "2026-01-15 15:00:00",
            "2026-01-15 10:00:00",
            "2026-01-15 17:55:41",
            "",
            "US/Eastern"
          )
        );
        var source = readRepoFile("api/v1/ActiveCruiseViewModelService.cfc");

        expect(findNoCase("Aug 2, 2026 1:55 PM", summerModel.actualDepartureLocalLabel)).toBeGT(0);
        expect(findNoCase("Aug 2, 2026 11:00 AM", summerModel.scheduledDepartureLocalLabel)).toBeGT(0);
        expect(findNoCase("Jan 15, 2026 12:55 PM", winterModel.actualDepartureLocalLabel)).toBeGT(0);
        expect(findNoCase("Jan 15, 2026 10:00 AM", winterModel.scheduledDepartureLocalLabel)).toBeGT(0);
        expect(findNoCase('createObject("java"', source)).toBe(0);
        expect(findNoCase('parseDateTime(replace(rawUtc, " ", "T", "one") & "Z")', source)).toBeGT(0);
        expect(findNoCase('case "US/EASTERN":', source)).toBeGT(0);
        expect(findNoCase('return "America/New_York"', source)).toBeGT(0);
      });

      it("publishes the same five fields through the public Follow timing authority", function() {
        var source = readRepoFile("api/v1/ActiveCruiseViewModelService.cfc");

        expect(findNoCase('"scheduledDepartureAtUtc" = safeString(floatPlan.scheduledDepartureAtUtc)', source)).toBeGT(0);
        expect(findNoCase('"scheduledDepartureLocalLabel" = safeString(floatPlan.scheduledDepartureLocalLabel)', source)).toBeGT(0);
        expect(findNoCase('"actualDepartureAtUtc" = (', source)).toBeGT(0);
        expect(findNoCase('? safeString(floatPlan.actualDepartureAtUtc)', source)).toBeGT(0);
        expect(findNoCase(': javacast("null", "")', source)).toBeGT(0);
        expect(findNoCase('"actualDepartureLocalLabel" = safeString(floatPlan.actualDepartureLocalLabel)', source)).toBeGT(0);
        expect(findNoCase('"hasActualDeparture" = (structKeyExists(floatPlan, "hasActualDeparture")', source)).toBeGT(0);
        expect(findNoCase('"scheduledDepartureUtc" = safeString(arguments.qPlan.departureTimeUtcRaw[1])', source)).toBeGT(0);
        expect(findNoCase('"scheduledDepartureLocalRaw" = safeString(arguments.qPlan.departureTimeLocalRaw[1])', source)).toBeGT(0);
      });

      it("renders explicit Scheduled and Actual Departure inputs without relabeling schedule as departure", function() {
        var pageSource = readRepoFile("app/follow.cfm");
        var scriptSource = readRepoFile("assets/js/app/follow/follow.js");

        expect(findNoCase('data-fpw-field="journey-departure-label">Scheduled Departure', pageSource)).toBeGT(0);
        expect(findNoCase('function explicitActualDepartureState(payload)', scriptSource)).toBeGT(0);
        expect(findNoCase('authorityTiming.scheduledDepartureLocalLabel', scriptSource)).toBeGT(0);
        expect(findNoCase('authorityTiming.actualDepartureLocalLabel', scriptSource)).toBeGT(0);
        expect(findNoCase(
          'setHookText("journey-departure-label", actualDepartureState ? "Actual Departure" : "Scheduled Departure")',
          scriptSource
        )).toBeGT(0);
        expect(findNoCase(
          'setHookText("journey-departed-value", actualDepartureState ? (actualDepartureLocalLabel || "—") : (scheduledDepartureLocalLabel || "—"))',
          scriptSource
        )).toBeGT(0);
        expect(findNoCase(
          'setHookText("journey-departed-meta", actualDepartureState ? ("Scheduled for " + (scheduledDepartureLocalLabel || "—")) : "Trip scheduled")',
          scriptSource
        )).toBeGT(0);
        expect(findNoCase(
          'scheduledDepartureLocalLabel = scheduledDepartureLocalLabel || scheduledDepartureMeta(body)',
          scriptSource
        )).toBe(0);
        expect(findNoCase('"Departing from " + legacyDepartureValue', scriptSource)).toBe(0);
      });

      it("anchors Follow elapsed progress to route start and does not suppress an early explicit start", function() {
        var source = readRepoFile("api/v1/voyage.cfc");

        expect(findNoCase("DATE_FORMAT(ri.started_at, '%Y-%m-%d %H:%i:%s') AS actualDepartureAtUtcRaw", source)).toBeGT(0);
        expect(findNoCase("TIMESTAMPDIFF(MINUTE, ri.started_at, UTC_TIMESTAMP())", source)).toBeGT(0);
        expect(findNoCase("hasActualDeparture = len(actualDepartureAtUtcRaw) GT 0", source)).toBeGT(0);
        expect(findNoCase("tripStarted = hasActualDeparture", source)).toBeGT(0);
        expect(findNoCase("hasOperationalCheckIn = (hasActualDeparture AND isDate(checkedInAtVal))", source)).toBeGT(0);
        expect(findNoCase("? val(qPlan.actualDepartureElapsedMinutes[1])", source)).toBeGT(0);
        expect(findNoCase('dateCompare(checkedInAtVal, scheduledDepartureRawDt, "s") GTE 0', source)).toBe(0);
      });

      it("locks only semantic schedule changes after route start and preserves unchanged stored schedule fields", function() {
        var source = readRepoFile("api/v1/floatplan.cfc");
        var wizardScript = readRepoFile("assets/js/app/floatplanWizard.js");
        var wizardPage = readRepoFile("app/floatplan-wizard.cfm");
        var dashboardPage = readRepoFile("app/dashboard.cfm");
        var errorCode = "SCHEDULED_DEPARTURE_LOCKED_AFTER_START";
        var errorMessage = "Scheduled departure cannot be changed after the trip has started.";

        expect(countOccurrences(source, errorCode)).toBeGTE(2);
        expect(countOccurrences(source, errorMessage)).toBeGTE(2);
        expect(findNoCase("SELECT started_at", source)).toBeGT(0);
        expect(findNoCase("lockedRouteRow = queryExecute", source)).toBeGT(0);
        expect(findNoCase("FOR UPDATE", source)).toBeGT(0);
        expect(findNoCase("!isNull(lockedRouteRow.started_at[1])", source)).toBeGT(0);
        expect(findNoCase("AND isDate(lockedRouteRow.started_at[1])", source)).toBeGT(0);
        expect(findNoCase("scheduledDepartureChanged = (", source)).toBeGT(0);
        expect(findNoCase("compare(left(departureTimeLocal, 16), left(lockedDepartureTimeLocal, 16))", source)).toBeGT(0);
        expect(findNoCase("compare(left(departureTimeUtcStore, 16), left(lockedDepartureTimeUtc, 16))", source)).toBeGT(0);
        expect(findNoCase("compareNoCase(departureTzStore, lockedDepartureTimezone)", source)).toBeGT(0);
        expect(findNoCase("preserveLockedDepartureSchedule = true", source)).toBeGT(0);
        expect(findNoCase("CASE WHEN :preserveDepartureSchedule = 1 THEN departureTime ELSE :departureTime END", source)).toBeGT(0);
        expect(findNoCase("CASE WHEN :preserveDepartureSchedule = 1 THEN departureTimeUTC ELSE :departureTimeUtc END", source)).toBeGT(0);
        expect(findNoCase("CASE WHEN :preserveDepartureSchedule = 1 THEN departTimezone ELSE :departureTz END", source)).toBeGT(0);
        expect(findNoCase("CASE WHEN :preserveDepartureSchedule = 1 THEN departureTZ ELSE :departureSourceTz END", source)).toBeGT(0);
        expect(findNoCase("isScheduledDepartureReadOnly: function ()", wizardScript)).toBeGT(0);
        expect(findNoCase("return hasActualDeparture(this.fp.FLOATPLAN)", wizardScript)).toBeGT(0);
        expect(countOccurrences(wizardPage, ':disabled="isScheduledDepartureReadOnly"')).toBe(2);
        expect(findNoCase(errorMessage, wizardPage)).toBeGT(0);
        expect(countOccurrences(dashboardPage, ':disabled="isScheduledDepartureReadOnly"')).toBe(2);
        expect(findNoCase(errorMessage, dashboardPage)).toBeGT(0);
      });

      it("preserves idempotent operational-start writes and monitoring initialization authority", function() {
        var floatPlanSource = readRepoFile("api/v1/floatplan.cfc");
        var monitoringSource = readRepoFile("api/v1/monitor.cfc");

        expect(findNoCase("SELECT UTC_TIMESTAMP() AS operational_start_at_utc", floatPlanSource)).toBeGT(0);
        expect(findNoCase("leg_started_at = COALESCE(leg_started_at, :operationalStartAtUtc)", floatPlanSource)).toBeGT(0);
        expect(findNoCase("started_at = COALESCE(started_at, :operationalStartAtUtc)", floatPlanSource)).toBeGT(0);
        expect(findNoCase('startMonitoringForFloatPlan(arguments.floatPlanId, "active_route", {', floatPlanSource)).toBeGT(0);
        expect(findNoCase("baseAt = operationalStartAtUtc", floatPlanSource)).toBeGT(0);
        expect(findNoCase('structKeyExists(arguments.options, "baseAt")', monitoringSource)).toBeGT(0);
        expect(findNoCase("monitoringBaseAt = arguments.options.baseAt", monitoringSource)).toBeGT(0);
        expect(findNoCase("expectedCheckinOptions.baseAt = monitoringBaseAt", monitoringSource)).toBeGT(0);
      });

      it("prepares a clean Draft route before exposing the new plan group", function() {
        var floatPlanSource = readRepoFile("api/v1/floatplan.cfc");
        var routeBuilderSource = readRepoFile("api/v1/routeBuilder.cfc");
        var insertAt = findNoCase("INSERT INTO floatplans", routeBuilderSource);
        var prepareAt = findNoCase("floatPlanService.prepareDraftRouteInstanceForEditing(", routeBuilderSource);
        var appendAt = findNoCase("arrayAppend(out.FLOATPLAN_IDS, newPlanId)", routeBuilderSource);

        expect(findNoCase("ROUTE_STARTED_COUNT = 0", floatPlanSource)).toBeGT(0);
        expect(findNoCase("started_ri.started_at IS NOT NULL", floatPlanSource)).toBeGT(0);
        expect(findNoCase("result.ROUTE_STARTED_COUNT GT 0", floatPlanSource)).toBeGT(0);
        expect(findNoCase('name="prepareDraftRouteInstanceForEditing" access="public"', floatPlanSource)).toBeGT(0);
        expect(findNoCase("AND route_instance_id = :originalRouteInstanceId", floatPlanSource)).toBeGT(0);
        expect(findNoCase('type = "FPW.DraftRoutePreparationAbort"', routeBuilderSource)).toBeGT(0);
        expect(insertAt).toBeGT(0);
        expect(prepareAt).toBeGT(insertAt);
        expect(appendAt).toBeGT(prepareAt);
        expect(findNoCase("routeInstanceIdVal = val(draftRoutePreparation.ROUTE_INSTANCE_ID)", routeBuilderSource)).toBeGT(0);
        expect(findNoCase("currentGroup.ROUTE_INSTANCE_ID GT 0", routeBuilderSource)).toBeGT(0);
        expect(findNoCase("currentGroup.HAS_CURRENT_GROUP AND structCount(activeRouteSource) GT 0", routeBuilderSource)).toBeGT(0);
      });

    });
  }

  private query function buildPlanQuery(
    required string scheduledUtc,
    required string scheduledLocal,
    string actualRouteStartUtc = "",
    string firstLegStartUtc = "",
    string timezone = "America/New_York"
  ) {
    var qPlan = queryNew(
      "floatPlanId,status,floatPlanName,departureTimeUtcRaw,departureTimeLocalRaw,departureTZ,departTimezone,vessel_timezone,routeStartedAtUtcRaw,leg_started_at,checkedInAt,checkin_context,activatedAt,closedAt",
      "integer,varchar,varchar,varchar,varchar,varchar,varchar,varchar,varchar,varchar,varchar,varchar,varchar,varchar"
    );

    queryAddRow(qPlan, 1);
    querySetCell(qPlan, "floatPlanId", 42, 1);
    querySetCell(qPlan, "status", "ACTIVE", 1);
    querySetCell(qPlan, "floatPlanName", "Scheduled and Actual Departure Contract", 1);
    querySetCell(qPlan, "departureTimeUtcRaw", arguments.scheduledUtc, 1);
    querySetCell(qPlan, "departureTimeLocalRaw", arguments.scheduledLocal, 1);
    querySetCell(qPlan, "departureTZ", arguments.timezone, 1);
    querySetCell(qPlan, "departTimezone", arguments.timezone, 1);
    querySetCell(qPlan, "vessel_timezone", arguments.timezone, 1);
    querySetCell(qPlan, "routeStartedAtUtcRaw", arguments.actualRouteStartUtc, 1);
    querySetCell(qPlan, "leg_started_at", arguments.firstLegStartUtc, 1);
    querySetCell(qPlan, "checkedInAt", "", 1);
    querySetCell(qPlan, "checkin_context", "", 1);
    querySetCell(qPlan, "activatedAt", "", 1);
    querySetCell(qPlan, "closedAt", "", 1);
    return qPlan;
  }

  private numeric function countOccurrences(required string source, required string token) {
    var count = 0;
    var offset = 1;
    var matchAt = 0;

    while (offset LTE len(arguments.source)) {
      matchAt = findNoCase(arguments.token, arguments.source, offset);
      if (matchAt LTE 0) {
        break;
      }
      count++;
      offset = matchAt + len(arguments.token);
    }
    return count;
  }

  private string function readRepoFile(required string relativePath) {
    return fileRead(expandPath("/fpw/" & arguments.relativePath), "utf-8");
  }

}
