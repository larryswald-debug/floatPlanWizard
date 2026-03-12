<cfscript>
  function fpwActiveCruiseHookValue(required string key) {
    var raw = "";
    if (structKeyExists(url, key) AND isSimpleValue(url[key])) {
      raw = trim(url[key] & "");
    }
    return reReplace(raw, "[\r\n]+", " ", "all");
  }

  function fpwResolveSessionUserId() {
    if (NOT structKeyExists(session, "user") OR NOT isStruct(session.user)) {
      return 0;
    }
    if (structKeyExists(session.user, "userId") AND isNumeric(session.user.userId)) {
      return val(session.user.userId);
    }
    if (structKeyExists(session.user, "id") AND isNumeric(session.user.id)) {
      return val(session.user.id);
    }
    if (structKeyExists(session.user, "USERID") AND isNumeric(session.user.USERID)) {
      return val(session.user.USERID);
    }
    return 0;
  }

  function fpwResolveDatasource() {
    if (structKeyExists(application, "dsn")) {
      var appDsn = trim(toString(application.dsn));
      if (len(appDsn)) {
        return appDsn;
      }
    }
    return "fpw";
  }

  function fpwPickStructValue(required struct source, required array keys, any defaultValue="") {
    var i = 0;
    var k = "";
    for (i = 1; i LTE arrayLen(arguments.keys); i++) {
      k = toString(arguments.keys[i]);
      if (structKeyExists(arguments.source, k) AND NOT isNull(arguments.source[k])) {
        return arguments.source[k];
      }
    }
    return arguments.defaultValue;
  }

  function fpwQueryCell(required query q, required string col, numeric row=1, any defaultValue="") {
    if (NOT listFindNoCase(arguments.q.columnList, arguments.col)) {
      return arguments.defaultValue;
    }
    if (arguments.q.recordCount LT arguments.row) {
      return arguments.defaultValue;
    }
    var value = arguments.q[arguments.col][arguments.row];
    if (isNull(value)) {
      return arguments.defaultValue;
    }
    return value;
  }

  function fpwStartCase(required string inputText) {
    var normalized = lCase(trim(arguments.inputText));
    var words = listToArray(normalized, " ");
    var out = [];
    var i = 0;
    var w = "";
    for (i = 1; i LTE arrayLen(words); i++) {
      w = trim(words[i]);
      if (NOT len(w)) {
        continue;
      }
      arrayAppend(out, uCase(left(w, 1)) & mid(w, 2, len(w)));
    }
    if (NOT arrayLen(out)) {
      return "";
    }
    return arrayToList(out, " ");
  }

  function fpwStatusLabel(required string rawStatus, string activeLabel="Active") {
    var s = uCase(trim(arguments.rawStatus));
    if (NOT len(s)) {
      return "";
    }
    if (s EQ "ACTIVE") {
      return arguments.activeLabel;
    }
    if (listFindNoCase("OVERDUE,DUE_NOW,OVERDUE_1H,OVERDUE_2H,OVERDUE_3H,OVERDUE_4H,OVERDUE_12H,OVERDUE_24H", s)) {
      return "Overdue";
    }
    return fpwStartCase(replace(s, "_", " ", "all"));
  }

  function fpwFormatNm(any nmValue) {
    var nm = val(nmValue);
    if (nm LT 0) {
      nm = 0;
    }
    return numberFormat(nm, "0.0") & " nm";
  }

  function fpwFormatPct(any pctValue) {
    var pct = int(val(pctValue));
    if (pct LT 0) {
      pct = 0;
    }
    if (pct GT 100) {
      pct = 100;
    }
    return pct & "%";
  }

  function fpwFormatClock(any dtValue, string fallback="--") {
    if (isDate(dtValue)) {
      return timeFormat(dtValue, "h:nn tt");
    }
    return arguments.fallback;
  }

  function fpwRoundTo2(any numericValue) {
    if (NOT isNumeric(arguments.numericValue)) {
      return 0;
    }
    return round(val(arguments.numericValue) * 100) / 100;
  }

  function fpwGetNumericFromKeys(any sourceData, required array keys, boolean positiveOnly=true) {
    var source = (isStruct(arguments.sourceData) ? arguments.sourceData : {});
    var i = 0;
    var key = "";
    var raw = "";
    var n = 0;
    if (NOT structCount(source)) {
      return 0;
    }
    for (i = 1; i LTE arrayLen(arguments.keys); i++) {
      key = toString(arguments.keys[i]);
      if (NOT len(key) OR NOT structKeyExists(source, key) OR isNull(source[key])) {
        continue;
      }
      raw = source[key];
      if (isSimpleValue(raw)) {
        raw = trim(toString(raw));
        if (NOT len(raw) OR NOT isNumeric(raw)) {
          continue;
        }
        n = val(raw);
      } else if (isNumeric(raw)) {
        n = val(raw);
      } else {
        continue;
      }
      if (arguments.positiveOnly AND n LTE 0) {
        continue;
      }
      return n;
    }
    return 0;
  }

  function fpwResolveCaptainDisplayName() {
    if (NOT structKeyExists(session, "user") OR NOT isStruct(session.user)) {
      return "Captain";
    }
    var firstName = trim(toString(fpwPickStructValue(session.user, ["firstName", "firstname", "FIRSTNAME", "first_name"], "")));
    var lastName = trim(toString(fpwPickStructValue(session.user, ["lastName", "lastname", "LASTNAME", "last_name"], "")));
    var fullName = trim(toString(fpwPickStructValue(session.user, ["name", "fullName", "displayName", "NAME"], "")));
    var email = trim(toString(fpwPickStructValue(session.user, ["email", "EMAIL"], "")));

    if (len(fullName)) {
      return fullName;
    }
    if (len(firstName) OR len(lastName)) {
      return trim(firstName & " " & lastName);
    }
    if (len(email)) {
      return email;
    }
    return "Captain";
  }

  activeCruiseHooks = {
    context = {
      routeCode = fpwActiveCruiseHookValue("routeCode"),
      routeId = fpwActiveCruiseHookValue("route_id"),
      routeInstanceId = fpwActiveCruiseHookValue("routeInstanceId"),
      floatPlanId = fpwActiveCruiseHookValue("floatPlanId"),
      activeRouteCode = fpwActiveCruiseHookValue("activeRouteCode")
    },
    fields = {}
  };

  activeCruiseContext = {
    routeCode = trim(activeCruiseHooks.context.routeCode),
    routeId = 0,
    routeInstanceId = 0,
    floatPlanId = 0,
    activeRouteCode = trim(activeCruiseHooks.context.activeRouteCode)
  };
  if (len(fpwActiveCruiseHookValue("route_id"))) {
    activeCruiseHooks.context.routeId = fpwActiveCruiseHookValue("route_id");
  }
  if (NOT len(activeCruiseHooks.context.routeId) AND len(fpwActiveCruiseHookValue("routeId"))) {
    activeCruiseHooks.context.routeId = fpwActiveCruiseHookValue("routeId");
  }
  if (isNumeric(activeCruiseHooks.context.routeId)) {
    activeCruiseContext.routeId = val(activeCruiseHooks.context.routeId);
  }
  if (isNumeric(activeCruiseHooks.context.routeInstanceId)) {
    activeCruiseContext.routeInstanceId = val(activeCruiseHooks.context.routeInstanceId);
  }
  if (isNumeric(activeCruiseHooks.context.floatPlanId)) {
    activeCruiseContext.floatPlanId = val(activeCruiseHooks.context.floatPlanId);
  }

  if (NOT len(activeCruiseContext.routeCode) AND len(activeCruiseContext.activeRouteCode)) {
    activeCruiseContext.routeCode = activeCruiseContext.activeRouteCode;
  }
  if (NOT len(activeCruiseContext.routeCode) AND structKeyExists(session, "expeditionRouteCode")) {
    activeCruiseContext.routeCode = trim(toString(session.expeditionRouteCode));
  }

  activeCruiseView = {
    topRouteChip = "Route: Gulf Coast Run",
    topFloatPlanState = "Float Plan: Active",
    heroRouteTitle = "Active Cruise Route",
    heroVoyageStatus = "Underway",
    heroCurrentLegSummary = "4 of 12",
    heroLegMeta = "Day 3 of 9 - Long-range coastal cruise",
    heroDistanceComplete = "142 nm",
    heroPercentComplete = "56% of active route completed",
    heroNextStop = "TBD",
    heroNextStopMeta = "Next planned stop",
    heroEta = "4:40 PM",
    heroEtaMeta = "Weather-adjusted arrival estimate",
    heroLastCheckIn = "1:12 PM",
    heroNextExpectedCheckIn = "Next expected by 5:00 PM",
    legRemainingDistance = "41 nm remaining",
    legPercentComplete = "56% complete",
    legPace = "Pace: 7.4 kt",
    legRemainingFuel = "Fuel est: 6.2 gal remaining",
    monitorStatus = "Normal",
    monitorStatusColor = "var(--good)",
    monitorFollowerState = "Live",
    monitorEmergencyContact = "Abbe",
    legDistance = "82 nm",
    legRemaining = "41 nm",
    legDataPace = "7.4 kt",
    legFuelNeed = "6.2 gal",
    legReserveFuel = "18 gal",
    legArrival = "4:40 PM",
    floatPlanStatus = "Active",
    floatPlanIdLabel = "FP-240318",
    floatPlanLastCheckIn = "1:12 PM",
    floatPlanNextExpected = "5:00 PM",
    captainContact = "Larry Wald • Captain",
    crewContact = "Callie • Onboard Companion",
    emergencyContact = "Abbe • Emergency Contact",
    progressBarWidth = "56%",
    routeStop1Title = "Departure Segment",
    routeStop1Detail = "Route origin for the active cruise.",
    routeStop1Stamp = "Start",
    routeStop2Title = "Current Leg Segment",
    routeStop2Detail = "Current leg in progress.",
    routeStop2Stamp = "Leg",
    routeStop3Title = "Approach Segment",
    routeStop3Detail = "Current leg destination and approach.",
    routeStop3Stamp = "Current",
    routeStop4Title = "Final Destination",
    routeStop4Detail = "Planned end of the active route.",
    routeStop4Stamp = "ETA"
  };

  activeCruiseUserId = fpwResolveSessionUserId();
  activeCruiseDatasource = fpwResolveDatasource();

  if (activeCruiseUserId GT 0) {
    try {
      userIdText = toString(activeCruiseUserId);
      routePrefix = "USER_ROUTE_" & int(activeCruiseUserId) & "_%";
      routeName = "";
      departureName = "";
      destinationName = "";
      totalLegs = 0;
      completedLegs = 0;
      currentLeg = 0;
      totalNm = 0.0;
      completedNm = 0.0;
      remainingNm = 0.0;
      currentLegRemainingNm = 0.0;
      percentComplete = 0;
      nextStop = "";
      currentLegDistNm = 0.0;
      planStatusRaw = "";
      planStatusLabel = "";
      monitorStatus = "";
      paceKn = 0.0;
      streamLive = false;
      captainName = fpwResolveCaptainDisplayName();
      emergencyName = "";
      crewName = "";
      lastCheckInDt = "";
      nextExpectedDt = "";
      etaLabel = "";
      etaMeta = "Weather-adjusted arrival estimate";
      routeCodeDisplay = activeCruiseContext.routeCode;
      currentLegStartName = "";
      currentLegEndName = "";
      nextLegEndName = "";
      qPlan = queryNew("");
      qRouteCtx = queryNew("");
      qRouteById = queryNew("");
      qLegs = queryNew("");
      qProgress = queryNew("");
      qCrew = queryNew("");
      qEmergency = queryNew("");
      qStream = queryNew("");
      qLastPost = queryNew("");
      qVoyageTables = queryNew("");
      qInputsColumn = queryNew("");
      qInstInputs = queryNew("");
      hasVoyageTables = false;
      hasRoutegenInputsCol = false;
      routeInputJsonRaw = "";
      routeInputs = {};
      routeInputSpeedKn = 0.0;
      routeInputFuelBurnGph = 0.0;
      routeInputReservePct = 0.0;
      speedForFuelKn = 0.0;
      currentLegHours = 0.0;
      baseFuelNeedGal = 0.0;
      reserveFuelNeedGal = 0.0;
      requiredFuelNeedGal = 0.0;
      fuelCalcReady = false;
      progressByLeg = {};
      i = 0;
      legOrder = 0;
      legStatus = "";
      isCompletedLeg = false;

      if (activeCruiseContext.floatPlanId GT 0) {
        qPlan = queryExecute(
          "SELECT
             floatplanId,
             floatPlanName,
             status,
             route_instance_id,
             route_day_number,
             checkedInAt,
             returnTime,
             returnTimezone,
             departureTime,
             departureTZ,
             departing,
             returning
           FROM floatplans
           WHERE floatplanId = :planId
             AND userId = :userId
           LIMIT 1",
          {
            planId = { value = activeCruiseContext.floatPlanId, cfsqltype = "cf_sql_integer" },
            userId = { value = activeCruiseUserId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = activeCruiseDatasource }
        );
      }

      if (qPlan.recordCount EQ 1) {
        activeCruiseContext.floatPlanId = val(fpwQueryCell(qPlan, "floatplanId", 1, 0));
        if (activeCruiseContext.routeInstanceId LTE 0) {
          activeCruiseContext.routeInstanceId = val(fpwQueryCell(qPlan, "route_instance_id", 1, 0));
        }
      }

      if (activeCruiseContext.routeInstanceId GT 0) {
        qRouteCtx = queryExecute(
          "SELECT
             ri.id AS route_instance_id,
             COALESCE(NULLIF(TRIM(ri.generated_route_code), ''), lr.short_code, '') AS route_code,
             COALESCE(NULLIF(TRIM(lr.name), ''), '') AS route_name
           FROM route_instances ri
           LEFT JOIN loop_routes lr ON lr.id = ri.generated_route_id
           WHERE ri.id = :routeInstanceId
             AND ri.user_id = :userIdText
           LIMIT 1",
          {
            routeInstanceId = { value = activeCruiseContext.routeInstanceId, cfsqltype = "cf_sql_integer" },
            userIdText = { value = userIdText, cfsqltype = "cf_sql_varchar" }
          },
          { datasource = activeCruiseDatasource }
        );
      }

      if (qRouteCtx.recordCount EQ 0 AND activeCruiseContext.routeId GT 0) {
        qRouteById = queryExecute(
          "SELECT
             ri.id AS route_instance_id,
             COALESCE(NULLIF(TRIM(ri.generated_route_code), ''), lr.short_code, '') AS route_code,
             COALESCE(NULLIF(TRIM(lr.name), ''), '') AS route_name
           FROM route_instances ri
           INNER JOIN loop_routes lr ON lr.id = ri.generated_route_id
           WHERE ri.user_id = :userIdText
             AND lr.id = :routeId
           ORDER BY ri.id DESC
           LIMIT 1",
          {
            userIdText = { value = userIdText, cfsqltype = "cf_sql_varchar" },
            routeId = { value = activeCruiseContext.routeId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = activeCruiseDatasource }
        );
        if (qRouteById.recordCount EQ 1) {
          qRouteCtx = qRouteById;
        }
      }

      if (qRouteCtx.recordCount EQ 0 AND len(activeCruiseContext.routeCode)) {
        qRouteCtx = queryExecute(
          "SELECT
             ri.id AS route_instance_id,
             COALESCE(NULLIF(TRIM(ri.generated_route_code), ''), lr.short_code, '') AS route_code,
             COALESCE(NULLIF(TRIM(lr.name), ''), '') AS route_name
           FROM route_instances ri
           LEFT JOIN loop_routes lr ON lr.id = ri.generated_route_id
           WHERE ri.user_id = :userIdText
             AND (
               ri.generated_route_code = :routeCode
               OR lr.short_code = :routeCode
             )
           ORDER BY ri.id DESC
           LIMIT 1",
          {
            userIdText = { value = userIdText, cfsqltype = "cf_sql_varchar" },
            routeCode = { value = activeCruiseContext.routeCode, cfsqltype = "cf_sql_varchar" }
          },
          { datasource = activeCruiseDatasource }
        );
      }

      if (qRouteCtx.recordCount EQ 0) {
        qRouteCtx = queryExecute(
          "SELECT
             ri.id AS route_instance_id,
             COALESCE(NULLIF(TRIM(ri.generated_route_code), ''), lr.short_code, '') AS route_code,
             COALESCE(NULLIF(TRIM(lr.name), ''), '') AS route_name
           FROM route_instances ri
           LEFT JOIN loop_routes lr ON lr.id = ri.generated_route_id
           WHERE ri.user_id = :userIdText
           ORDER BY ri.id DESC
           LIMIT 1",
          {
            userIdText = { value = userIdText, cfsqltype = "cf_sql_varchar" }
          },
          { datasource = activeCruiseDatasource }
        );
      }

      if (qRouteCtx.recordCount EQ 1) {
        activeCruiseContext.routeInstanceId = val(fpwQueryCell(qRouteCtx, "route_instance_id", 1, 0));
        routeCodeDisplay = trim(toString(fpwQueryCell(qRouteCtx, "route_code", 1, activeCruiseContext.routeCode)));
        routeName = trim(toString(fpwQueryCell(qRouteCtx, "route_name", 1, "")));
      }

      if (qRouteCtx.recordCount EQ 0 AND activeCruiseContext.routeId GT 0) {
        qRouteNameById = queryExecute(
          "SELECT name, short_code
           FROM loop_routes
           WHERE id = :routeId
             AND short_code LIKE :routePrefix
           LIMIT 1",
          {
            routeId = { value = activeCruiseContext.routeId, cfsqltype = "cf_sql_integer" },
            routePrefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" }
          },
          { datasource = activeCruiseDatasource }
        );
        if (qRouteNameById.recordCount EQ 1) {
          routeName = trim(toString(fpwQueryCell(qRouteNameById, "name", 1, "")));
          if (NOT len(routeCodeDisplay)) {
            routeCodeDisplay = trim(toString(fpwQueryCell(qRouteNameById, "short_code", 1, "")));
          }
        }
      }

      if (NOT len(routeName) AND len(routeCodeDisplay)) {
        qRouteName = queryExecute(
          "SELECT name
           FROM loop_routes
           WHERE short_code = :routeCode
             AND short_code LIKE :routePrefix
           LIMIT 1",
          {
            routeCode = { value = routeCodeDisplay, cfsqltype = "cf_sql_varchar" },
            routePrefix = { value = routePrefix, cfsqltype = "cf_sql_varchar" }
          },
          { datasource = activeCruiseDatasource }
        );
        if (qRouteName.recordCount EQ 1) {
          routeName = trim(toString(fpwQueryCell(qRouteName, "name", 1, "")));
        }
      }

      if (qPlan.recordCount EQ 0 AND activeCruiseContext.routeInstanceId GT 0) {
        qPlan = queryExecute(
          "SELECT
             floatplanId,
             floatPlanName,
             status,
             route_instance_id,
             route_day_number,
             checkedInAt,
             returnTime,
             returnTimezone,
             departureTime,
             departureTZ,
             departing,
             returning
           FROM floatplans
           WHERE userId = :userId
             AND route_instance_id = :routeInstanceId
           ORDER BY floatplanId DESC
           LIMIT 1",
          {
            userId = { value = activeCruiseUserId, cfsqltype = "cf_sql_integer" },
            routeInstanceId = { value = activeCruiseContext.routeInstanceId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = activeCruiseDatasource }
        );
      }

      if (qPlan.recordCount EQ 1) {
        activeCruiseContext.floatPlanId = val(fpwQueryCell(qPlan, "floatplanId", 1, 0));
        planStatusRaw = trim(toString(fpwQueryCell(qPlan, "status", 1, "")));
        planStatusLabel = fpwStatusLabel(planStatusRaw, "Active");
        if (NOT len(planStatusLabel)) {
          planStatusLabel = "Unknown";
        }
        monitorStatus = fpwStatusLabel(planStatusRaw, "Normal");
        if (NOT len(monitorStatus)) {
          monitorStatus = "Unknown";
        }
        if (isDate(fpwQueryCell(qPlan, "checkedInAt", 1, ""))) {
          lastCheckInDt = fpwQueryCell(qPlan, "checkedInAt", 1, "");
        }
        if (isDate(fpwQueryCell(qPlan, "returnTime", 1, ""))) {
          etaLabel = fpwFormatClock(fpwQueryCell(qPlan, "returnTime", 1, ""), "--");
          etaMeta = "Float plan return target";
        }
      }

      if (activeCruiseContext.routeInstanceId GT 0) {
        qInputsColumn = queryExecute(
          "SELECT COUNT(*) AS cnt
           FROM information_schema.columns
           WHERE table_schema = DATABASE()
             AND table_name = 'route_instances'
             AND column_name = 'routegen_inputs_json'",
          {},
          { datasource = activeCruiseDatasource }
        );
        hasRoutegenInputsCol = (qInputsColumn.recordCount EQ 1 AND val(fpwQueryCell(qInputsColumn, "cnt", 1, 0)) GT 0);
        if (hasRoutegenInputsCol) {
          qInstInputs = queryExecute(
            "SELECT routegen_inputs_json
             FROM route_instances
             WHERE id = :routeInstanceId
               AND user_id = :userIdText
             LIMIT 1",
            {
              routeInstanceId = { value = activeCruiseContext.routeInstanceId, cfsqltype = "cf_sql_integer" },
              userIdText = { value = userIdText, cfsqltype = "cf_sql_varchar" }
            },
            { datasource = activeCruiseDatasource }
          );
          if (qInstInputs.recordCount EQ 1 AND NOT isNull(qInstInputs.routegen_inputs_json[1])) {
            routeInputJsonRaw = trim(toString(qInstInputs.routegen_inputs_json[1]));
            if (len(routeInputJsonRaw)) {
              try {
                routeInputs = deserializeJSON(routeInputJsonRaw, false);
                if (NOT isStruct(routeInputs)) {
                  routeInputs = {};
                }
              } catch (any parseInputsErr) {
                routeInputs = {};
              }
            }
          }
        }
      }

      if (activeCruiseContext.routeInstanceId GT 0) {
        qLegs = queryExecute(
          "SELECT
             leg_order,
             start_name,
             end_name,
             COALESCE(base_dist_nm, 0) AS dist_nm
           FROM route_instance_legs
           WHERE route_instance_id = :routeInstanceId
           ORDER BY leg_order ASC, id ASC",
          {
            routeInstanceId = { value = activeCruiseContext.routeInstanceId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = activeCruiseDatasource }
        );

        qProgress = queryExecute(
          "SELECT leg_order, status
           FROM route_instance_leg_progress
           WHERE route_instance_id = :routeInstanceId
             AND user_id = :userId
           ORDER BY leg_order ASC",
          {
            routeInstanceId = { value = activeCruiseContext.routeInstanceId, cfsqltype = "cf_sql_integer" },
            userId = { value = activeCruiseUserId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = activeCruiseDatasource }
        );

        for (i = 1; i LTE qProgress.recordCount; i++) {
          progressByLeg[toString(val(fpwQueryCell(qProgress, "leg_order", i, 0)))] = uCase(trim(toString(fpwQueryCell(qProgress, "status", i, ""))));
        }

        totalLegs = qLegs.recordCount;
        if (totalLegs GT 0) {
          departureName = trim(toString(fpwQueryCell(qLegs, "start_name", 1, "")));
          destinationName = trim(toString(fpwQueryCell(qLegs, "end_name", totalLegs, "")));
        }

        for (i = 1; i LTE qLegs.recordCount; i++) {
          legOrder = val(fpwQueryCell(qLegs, "leg_order", i, i));
          legStatus = "NOT_STARTED";
          if (structKeyExists(progressByLeg, toString(legOrder))) {
            legStatus = progressByLeg[toString(legOrder)];
          }
          isCompletedLeg = (legStatus EQ "COMPLETED");
          totalNm += val(fpwQueryCell(qLegs, "dist_nm", i, 0));
          if (isCompletedLeg) {
            completedNm += val(fpwQueryCell(qLegs, "dist_nm", i, 0));
            completedLegs++;
          } else if (NOT len(nextStop)) {
            nextStop = trim(toString(fpwQueryCell(qLegs, "end_name", i, "")));
          }
        }

        if (NOT len(nextStop) AND totalLegs GT 0) {
          nextStop = trim(toString(fpwQueryCell(qLegs, "end_name", totalLegs, "")));
        }

        remainingNm = totalNm - completedNm;
        if (remainingNm LT 0) {
          remainingNm = 0;
        }
        if (totalNm GT 0) {
          percentComplete = int((completedNm / totalNm) * 100);
        } else {
          percentComplete = 0;
        }
        if (percentComplete LT 0) {
          percentComplete = 0;
        }
        if (percentComplete GT 100) {
          percentComplete = 100;
        }

        if (totalLegs GT 0) {
          currentLeg = completedLegs + 1;
          if (currentLeg GT totalLegs) {
            currentLeg = totalLegs;
          }
          currentLegStartName = trim(toString(fpwQueryCell(qLegs, "start_name", currentLeg, "")));
          currentLegEndName = trim(toString(fpwQueryCell(qLegs, "end_name", currentLeg, "")));
          if (currentLeg LT totalLegs) {
            nextLegEndName = trim(toString(fpwQueryCell(qLegs, "end_name", currentLeg + 1, "")));
          }
          currentLegDistNm = val(fpwQueryCell(qLegs, "dist_nm", currentLeg, 0));
        }
      }

      if (activeCruiseContext.floatPlanId GT 0) {
        qCrew = queryExecute(
          "SELECT p.name
           FROM floatplan_passengers fpp
           INNER JOIN passengers p ON p.passId = fpp.passId
           WHERE fpp.floatplanId = :planId
           ORDER BY fpp.recId ASC
           LIMIT 1",
          {
            planId = { value = activeCruiseContext.floatPlanId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = activeCruiseDatasource }
        );
        if (qCrew.recordCount EQ 1) {
          crewName = trim(toString(fpwQueryCell(qCrew, "name", 1, "")));
        }

        qEmergency = queryExecute(
          "SELECT c.name
           FROM floatplan_contacts fpc
           INNER JOIN contacts c ON c.contactId = fpc.contactId
           WHERE fpc.floatplanId = :planId
           ORDER BY fpc.recId ASC
           LIMIT 1",
          {
            planId = { value = activeCruiseContext.floatPlanId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = activeCruiseDatasource }
        );
        if (qEmergency.recordCount EQ 1) {
          emergencyName = trim(toString(fpwQueryCell(qEmergency, "name", 1, "")));
        }

        qVoyageTables = queryExecute(
          "SELECT COUNT(*) AS cnt
           FROM information_schema.tables
           WHERE table_schema = DATABASE()
             AND table_name IN ('voyage_streams', 'voyage_posts')",
          {},
          { datasource = activeCruiseDatasource }
        );
        hasVoyageTables = (qVoyageTables.recordCount EQ 1 AND val(fpwQueryCell(qVoyageTables, "cnt", 1, 0)) GTE 2);

        if (hasVoyageTables) {
          qStream = queryExecute(
            "SELECT id
             FROM voyage_streams
             WHERE floatplan_id = :planId
               AND owner_user_id = :ownerUserId
             ORDER BY id DESC
             LIMIT 1",
            {
              planId = { value = activeCruiseContext.floatPlanId, cfsqltype = "cf_sql_integer" },
              ownerUserId = { value = activeCruiseUserId, cfsqltype = "cf_sql_integer" }
            },
            { datasource = activeCruiseDatasource }
          );
          streamLive = (qStream.recordCount EQ 1);

          if (streamLive AND NOT isDate(lastCheckInDt)) {
            qLastPost = queryExecute(
              "SELECT vp.created_utc
               FROM voyage_posts vp
               WHERE vp.stream_id = :streamId
               ORDER BY vp.created_utc DESC, vp.id DESC
               LIMIT 1",
              {
                streamId = { value = val(fpwQueryCell(qStream, "id", 1, 0)), cfsqltype = "cf_sql_integer" }
              },
              { datasource = activeCruiseDatasource }
            );
            if (qLastPost.recordCount EQ 1 AND isDate(fpwQueryCell(qLastPost, "created_utc", 1, ""))) {
              lastCheckInDt = fpwQueryCell(qLastPost, "created_utc", 1, "");
            }
          }
        }
      }

      if (NOT isDate(lastCheckInDt) AND isDate(fpwQueryCell(qPlan, "checkedInAt", 1, ""))) {
        lastCheckInDt = fpwQueryCell(qPlan, "checkedInAt", 1, "");
      }
      if (isDate(lastCheckInDt)) {
        nextExpectedDt = dateAdd("n", 60, lastCheckInDt);
      }

      if (NOT len(routeName)) {
        routeName = routeCodeDisplay;
      }
      if (NOT len(routeName)) {
        routeName = "Active Route";
      }

      if (len(departureName) AND len(destinationName)) {
        activeCruiseView.heroRouteTitle = departureName & " → " & destinationName;
      } else {
        activeCruiseView.heroRouteTitle = routeName;
      }

      activeCruiseView.topRouteChip = "Route: " & routeName;
      if (percentComplete GTE 100) {
        activeCruiseView.heroVoyageStatus = "Completed";
      } else {
        activeCruiseView.heroVoyageStatus = fpwStatusLabel(planStatusRaw, "Underway");
      }
      if (NOT len(activeCruiseView.heroVoyageStatus)) {
        activeCruiseView.heroVoyageStatus = "Underway";
      }

      if (totalLegs GT 0) {
        activeCruiseView.heroCurrentLegSummary = currentLeg & " of " & totalLegs;
      }
      if (val(fpwQueryCell(qPlan, "route_day_number", 1, 0)) GT 0) {
        activeCruiseView.heroLegMeta = "Day " & val(fpwQueryCell(qPlan, "route_day_number", 1, 0)) & " of active cruise";
      } else if (totalLegs GT 0) {
        activeCruiseView.heroLegMeta = "Leg progress from active route instance";
      }

      activeCruiseView.heroDistanceComplete = fpwFormatNm(completedNm);
      activeCruiseView.heroPercentComplete = fpwFormatPct(percentComplete) & " of active route completed";

      if (len(nextStop)) {
        activeCruiseView.heroNextStop = nextStop;
        activeCruiseView.heroNextStopMeta = "Upcoming planned stop";
      }

      if (len(etaLabel)) {
        activeCruiseView.heroEta = etaLabel;
        activeCruiseView.heroEtaMeta = etaMeta;
        activeCruiseView.legArrival = etaLabel;
      }

      if (isDate(lastCheckInDt)) {
        activeCruiseView.heroLastCheckIn = fpwFormatClock(lastCheckInDt, "--");
        activeCruiseView.floatPlanLastCheckIn = fpwFormatClock(lastCheckInDt, "--");
      }
      if (isDate(nextExpectedDt)) {
        activeCruiseView.heroNextExpectedCheckIn = "Next expected by " & fpwFormatClock(nextExpectedDt, "--");
        activeCruiseView.floatPlanNextExpected = fpwFormatClock(nextExpectedDt, "--");
      }

      activeCruiseView.legRemainingDistance = fpwFormatNm(remainingNm) & " remaining";
      activeCruiseView.legPercentComplete = fpwFormatPct(percentComplete) & " complete";
      activeCruiseView.progressBarWidth = fpwFormatPct(percentComplete);

      if (currentLegDistNm GT 0) {
        activeCruiseView.legDistance = fpwFormatNm(currentLegDistNm);
      }
      currentLegRemainingNm = remainingNm;
      if (currentLegDistNm GT 0) {
        currentLegRemainingNm = currentLegDistNm;
        if (remainingNm GTE 0 AND remainingNm LT currentLegRemainingNm) {
          currentLegRemainingNm = remainingNm;
        }
      }
      if (currentLegRemainingNm LT 0) {
        currentLegRemainingNm = 0;
      }
      activeCruiseView.legRemaining = fpwFormatNm(currentLegRemainingNm);

      if (len(departureName)) {
        activeCruiseView.routeStop1Title = departureName & " Departure";
        activeCruiseView.routeStop1Detail = "Route origin for the active cruise.";
        if (currentLeg GT 1) {
          activeCruiseView.routeStop1Stamp = "Done";
        } else {
          activeCruiseView.routeStop1Stamp = "Current";
        }
      }
      if (len(currentLegStartName) AND len(currentLegEndName)) {
        activeCruiseView.routeStop2Title = currentLegStartName & " -> " & currentLegEndName;
        activeCruiseView.routeStop2Detail = "Current leg in progress.";
        activeCruiseView.routeStop2Stamp = "Leg " & currentLeg;
        activeCruiseView.routeStop3Title = "Approach Segment: " & currentLegEndName;
        activeCruiseView.routeStop3Detail = "Current leg destination and approach.";
        activeCruiseView.routeStop3Stamp = "Current";
      }
      if (len(nextLegEndName)) {
        activeCruiseView.routeStop3Title = "Next Segment: " & currentLegEndName & " -> " & nextLegEndName;
        activeCruiseView.routeStop3Detail = "Upcoming leg after the current destination.";
        activeCruiseView.routeStop3Stamp = "Next";
      }
      if (len(destinationName)) {
        activeCruiseView.routeStop4Title = "Final Destination: " & destinationName;
        activeCruiseView.routeStop4Detail = "Planned end of the active route.";
      } else if (len(currentLegEndName)) {
        activeCruiseView.routeStop4Title = "Final Destination: " & currentLegEndName;
        activeCruiseView.routeStop4Detail = "Planned end of the active route.";
      }
      if (len(activeCruiseView.heroEta)) {
        activeCruiseView.routeStop4Stamp = activeCruiseView.heroEta & " ETA";
      } else {
        activeCruiseView.routeStop4Stamp = "ETA";
      }

      if (isDate(fpwQueryCell(qPlan, "departureTime", 1, "")) AND isDate(fpwQueryCell(qPlan, "returnTime", 1, "")) AND totalNm GT 0) {
        cruiseMinutes = dateDiff("n", fpwQueryCell(qPlan, "departureTime", 1, ""), fpwQueryCell(qPlan, "returnTime", 1, ""));
        if (cruiseMinutes GT 0) {
          paceKn = totalNm / (cruiseMinutes / 60);
          if (paceKn GT 0) {
            activeCruiseView.legPace = "Pace: " & numberFormat(paceKn, "0.0") & " kt";
            activeCruiseView.legDataPace = numberFormat(paceKn, "0.0") & " kt";
          }
        }
      }

      routeInputSpeedKn = fpwGetNumericFromKeys(
        routeInputs,
        [
          "effective_speed_kn",
          "effectiveSpeedKn",
          "weather_adjusted_speed_kn",
          "weatherAdjustedSpeedKn",
          "cruising_speed",
          "cruisingSpeed",
          "max_speed_kn",
          "maxSpeedKn"
        ],
        true
      );
      if (paceKn LTE 0 AND routeInputSpeedKn GT 0) {
        paceKn = routeInputSpeedKn;
        activeCruiseView.legPace = "Pace: " & numberFormat(paceKn, "0.0") & " kt";
        activeCruiseView.legDataPace = numberFormat(paceKn, "0.0") & " kt";
      }

      routeInputFuelBurnGph = fpwGetNumericFromKeys(
        routeInputs,
        [
          "fuel_burn_gph",
          "fuelBurnGph",
          "fuel_burn_gph_input",
          "fuelBurnGphInput",
          "max_burn_gph",
          "maxBurnGph",
          "burn_gph",
          "burnGph",
          "vessel_gph_at_most_efficient_speed",
          "vesselGphAtMostEfficientSpeed",
          "gph_at_most_efficient_speed",
          "gphAtMostEfficientSpeed",
          "GALLONS_PER_HOUR"
        ],
        true
      );
      routeInputReservePct = fpwGetNumericFromKeys(
        routeInputs,
        [ "reserve_pct", "reservePct", "RESERVE_PCT" ],
        false
      );
      if (routeInputReservePct LT 0) {
        routeInputReservePct = 0;
      }
      if (routeInputReservePct GT 100) {
        routeInputReservePct = 100;
      }

      speedForFuelKn = paceKn;
      if (speedForFuelKn LTE 0 AND routeInputSpeedKn GT 0) {
        speedForFuelKn = routeInputSpeedKn;
      }

      if (speedForFuelKn GT 0 AND routeInputFuelBurnGph GT 0 AND currentLegRemainingNm GT 0) {
        currentLegHours = currentLegRemainingNm / speedForFuelKn;
        baseFuelNeedGal = fpwRoundTo2(currentLegHours * routeInputFuelBurnGph);
        reserveFuelNeedGal = 0;
        if (routeInputReservePct GT 0) {
          reserveFuelNeedGal = fpwRoundTo2(baseFuelNeedGal * (routeInputReservePct / 100));
        }
        requiredFuelNeedGal = fpwRoundTo2(baseFuelNeedGal + reserveFuelNeedGal);
        activeCruiseView.legFuelNeed = numberFormat(requiredFuelNeedGal, "0.0") & " gal";
        activeCruiseView.legReserveFuel = numberFormat(reserveFuelNeedGal, "0.0") & " gal";
        activeCruiseView.legRemainingFuel = "Fuel est: " & numberFormat(requiredFuelNeedGal, "0.0") & " gal remaining";
        fuelCalcReady = true;
      }
      if (NOT fuelCalcReady) {
        activeCruiseView.legFuelNeed = "-- gal";
        activeCruiseView.legReserveFuel = "-- gal";
        activeCruiseView.legRemainingFuel = "Fuel est unavailable";
      }

      if (len(planStatusLabel)) {
        activeCruiseView.floatPlanStatus = planStatusLabel;
      } else {
        activeCruiseView.floatPlanStatus = "Unknown";
      }
      if (activeCruiseContext.floatPlanId GT 0) {
        activeCruiseView.floatPlanIdLabel = "FP-" & activeCruiseContext.floatPlanId;
      }
      activeCruiseView.topFloatPlanState = "Float Plan: " & activeCruiseView.floatPlanStatus;

      if (len(monitorStatus)) {
        activeCruiseView.monitorStatus = monitorStatus;
      } else {
        activeCruiseView.monitorStatus = "Unknown";
      }
      if (uCase(activeCruiseView.monitorStatus) EQ "OVERDUE") {
        activeCruiseView.monitorStatusColor = "var(--warn)";
      } else if (uCase(activeCruiseView.monitorStatus) EQ "UNKNOWN") {
        activeCruiseView.monitorStatusColor = "var(--muted)";
      }
      if (streamLive) {
        activeCruiseView.monitorFollowerState = "Live";
      } else {
        activeCruiseView.monitorFollowerState = "Not linked";
      }

      if (len(emergencyName)) {
        activeCruiseView.monitorEmergencyContact = emergencyName;
        activeCruiseView.emergencyContact = emergencyName & " • Emergency Contact";
      }
      if (len(crewName)) {
        activeCruiseView.crewContact = crewName & " • Crew";
      }
      activeCruiseView.captainContact = captainName & " • Captain";

      activeCruiseContext.routeCode = routeCodeDisplay;
      activeCruiseContext.activeRouteCode = routeCodeDisplay;
    } catch (any activeCruiseError) {
      cflog(
        file = "application",
        type = "warning",
        text = "FPW Active Cruise server hydration fallback: " & activeCruiseError.message
      );
      activeCruiseHooks.error = {
        message = activeCruiseError.message
      };
    }
  }

  activeCruiseHooks.context.routeCode = activeCruiseContext.routeCode;
  activeCruiseHooks.context.routeId = activeCruiseContext.routeId;
  activeCruiseHooks.context.routeInstanceId = activeCruiseContext.routeInstanceId;
  activeCruiseHooks.context.floatPlanId = activeCruiseContext.floatPlanId;
  activeCruiseHooks.context.activeRouteCode = activeCruiseContext.activeRouteCode;
  activeCruiseHooks.context.userId = activeCruiseUserId;
  activeCruiseHooks.fields = {
    topRouteChip = activeCruiseView.topRouteChip,
    topFloatPlanState = activeCruiseView.topFloatPlanState,
    heroRouteTitle = activeCruiseView.heroRouteTitle,
    heroVoyageStatus = activeCruiseView.heroVoyageStatus,
    heroCurrentLegSummary = activeCruiseView.heroCurrentLegSummary,
    heroLegMeta = activeCruiseView.heroLegMeta,
    heroDistanceComplete = activeCruiseView.heroDistanceComplete,
    heroPercentComplete = activeCruiseView.heroPercentComplete,
    heroNextStop = activeCruiseView.heroNextStop,
    heroEta = activeCruiseView.heroEta,
    heroLastCheckIn = activeCruiseView.heroLastCheckIn,
    heroNextExpectedCheckIn = activeCruiseView.heroNextExpectedCheckIn,
    legRemainingDistance = activeCruiseView.legRemainingDistance,
    legPercentComplete = activeCruiseView.legPercentComplete,
    monitorStatus = activeCruiseView.monitorStatus,
    monitorFollowerState = activeCruiseView.monitorFollowerState,
    monitorEmergencyContact = activeCruiseView.monitorEmergencyContact,
    floatPlanStatus = activeCruiseView.floatPlanStatus,
    floatPlanId = activeCruiseView.floatPlanIdLabel,
    floatPlanLastCheckIn = activeCruiseView.floatPlanLastCheckIn,
    floatPlanNextExpected = activeCruiseView.floatPlanNextExpected,
    captainContact = activeCruiseView.captainContact,
    crewContact = activeCruiseView.crewContact,
    emergencyContact = activeCruiseView.emergencyContact,
    routeStop1Title = activeCruiseView.routeStop1Title,
    routeStop1Detail = activeCruiseView.routeStop1Detail,
    routeStop1Stamp = activeCruiseView.routeStop1Stamp,
    routeStop2Title = activeCruiseView.routeStop2Title,
    routeStop2Detail = activeCruiseView.routeStop2Detail,
    routeStop2Stamp = activeCruiseView.routeStop2Stamp,
    routeStop3Title = activeCruiseView.routeStop3Title,
    routeStop3Detail = activeCruiseView.routeStop3Detail,
    routeStop3Stamp = activeCruiseView.routeStop3Stamp,
    routeStop4Title = activeCruiseView.routeStop4Title,
    routeStop4Detail = activeCruiseView.routeStop4Detail,
    routeStop4Stamp = activeCruiseView.routeStop4Stamp
  };
  activeCruiseHooksJson = replace(serializeJSON(activeCruiseHooks), "</", "<\/", "all");
</cfscript>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>FPW Active Cruise Console</title>
  <style>
    :root {
      --bg: #06111a;
      --bg2: #0a1824;
      --panel: rgba(11, 27, 39, 0.88);
      --panel-2: rgba(9, 22, 32, 0.96);
      --line: rgba(126, 184, 226, 0.14);
      --line-strong: rgba(126, 184, 226, 0.26);
      --text: #ebf6ff;
      --muted: #9fb9cb;
      --soft: #7e97aa;
      --accent: #43c7ff;
      --accent-2: #18f2d2;
      --accent-3: #ffc661;
      --good: #7df2b7;
      --warn: #ffc661;
      --alert: #ff7f7f;
      --shadow: 0 20px 60px rgba(0,0,0,0.38);
      --radius-xl: 28px;
      --radius-lg: 22px;
      --radius-md: 16px;
      --max: 1480px;
    }

    * { box-sizing: border-box; }
    html { scroll-behavior: smooth; }
    body {
      margin: 0;
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      color: var(--text);
      background:
        radial-gradient(circle at 10% 10%, rgba(24,242,210,0.06), transparent 0 22%),
        radial-gradient(circle at 90% 0%, rgba(67,199,255,0.09), transparent 0 26%),
        linear-gradient(180deg, #051018 0%, #07141e 40%, #091923 100%);
      min-height: 100vh;
    }

    a { color: inherit; text-decoration: none; }
    .shell { width: min(calc(100% - 28px), var(--max)); margin: 0 auto; }

    .topbar {
      position: sticky;
      top: 0;
      z-index: 50;
      backdrop-filter: blur(16px);
      background: rgba(5, 16, 24, 0.74);
      border-bottom: 1px solid rgba(126,184,226,0.1);
    }

    .topbar-inner {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 18px;
      padding: 14px 0;
    }

    .brand {
      display: flex;
      align-items: center;
      gap: 14px;
      min-width: 0;
    }

    .brand-mark {
      width: 44px;
      height: 44px;
      border-radius: 14px;
      display: grid;
      place-items: center;
      background: linear-gradient(145deg, rgba(67,199,255,0.18), rgba(24,242,210,0.14));
      border: 1px solid rgba(126,184,226,0.22);
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.05), 0 10px 24px rgba(0,0,0,0.26);
      font-size: 1.2rem;
    }

    .brand-copy { min-width: 0; }
    .brand-title { font-weight: 800; letter-spacing: 0.02em; }
    .brand-sub { color: var(--muted); font-size: 0.86rem; margin-top: 2px; }

    .top-actions {
      display: flex;
      align-items: center;
      gap: 10px;
      flex-wrap: wrap;
      justify-content: flex-end;
    }

    .chip, .btn {
      border-radius: 999px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      white-space: nowrap;
    }

    .chip {
      padding: 10px 14px;
      background: rgba(126,184,226,0.07);
      border: 1px solid rgba(126,184,226,0.14);
      color: var(--muted);
      font-size: 0.9rem;
      font-weight: 700;
    }

    .btn {
      border: 0;
      cursor: pointer;
      font-weight: 800;
      font-size: 0.94rem;
      padding: 12px 18px;
      transition: 0.18s ease;
    }

    .btn:hover { transform: translateY(-1px); }
    .btn-primary {
      color: #041019;
      background: linear-gradient(135deg, var(--accent-2), var(--accent));
      box-shadow: 0 16px 32px rgba(67,199,255,0.18);
    }
    .btn-secondary {
      color: var(--text);
      background: rgba(126,184,226,0.08);
      border: 1px solid rgba(126,184,226,0.18);
    }

    .main {
      padding: 22px 0 34px;
    }

    .hero {
      display: grid;
      grid-template-columns: 1.18fr 0.82fr;
      gap: 18px;
      margin-bottom: 18px;
    }

    .panel {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: var(--radius-xl);
      box-shadow: var(--shadow);
      backdrop-filter: blur(16px);
    }

    .hero-main {
      padding: 26px 26px 24px;
      position: relative;
      overflow: hidden;
      background:
        radial-gradient(circle at 0% 0%, rgba(67,199,255,0.08), transparent 0 24%),
        linear-gradient(180deg, rgba(255,255,255,0.025), rgba(255,255,255,0.01));
    }

    .eyebrow {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      padding: 8px 14px;
      border-radius: 999px;
      font-size: 0.78rem;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      font-weight: 800;
      background: rgba(125,242,183,0.08);
      color: var(--good);
      border: 1px solid rgba(125,242,183,0.16);
      margin-bottom: 18px;
    }

    .title-row {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      gap: 18px;
      margin-bottom: 18px;
    }

    h1 {
      margin: 0;
      font-size: clamp(2rem, 4vw, 3.5rem);
      line-height: 0.96;
      letter-spacing: -0.045em;
    }

    .subline {
      color: var(--muted);
      font-size: 1.05rem;
      line-height: 1.65;
      margin-top: 14px;
      max-width: 58ch;
    }

    .status-pill {
      padding: 14px 18px;
      border-radius: 18px;
      background: rgba(125,242,183,0.08);
      border: 1px solid rgba(125,242,183,0.18);
      min-width: 170px;
      text-align: center;
    }

    .status-pill b {
      display: block;
      color: var(--good);
      font-size: 0.8rem;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      margin-bottom: 6px;
    }

    .status-pill strong {
      display: block;
      font-size: 1.22rem;
      letter-spacing: -0.03em;
    }

    .header-stats {
      display: grid;
      grid-template-columns: repeat(5, minmax(0, 1fr));
      gap: 14px;
      margin-top: 18px;
    }

    .metric {
      background: rgba(126,184,226,0.05);
      border: 1px solid rgba(126,184,226,0.12);
      border-radius: 18px;
      padding: 16px;
      min-height: 96px;
    }

    .metric span {
      display: block;
      color: var(--soft);
      font-size: 0.78rem;
      text-transform: uppercase;
      letter-spacing: 0.12em;
      margin-bottom: 10px;
      font-weight: 800;
    }

    .metric strong {
      display: block;
      font-size: 1.5rem;
      letter-spacing: -0.045em;
      margin-bottom: 6px;
      line-height: 1;
    }

    .metric small {
      color: var(--muted);
      font-size: 0.88rem;
      line-height: 1.45;
      display: block;
    }

    .hero-side {
      padding: 18px;
      display: grid;
      gap: 16px;
      background:
        linear-gradient(180deg, rgba(255,255,255,0.022), rgba(255,255,255,0.01)),
        radial-gradient(circle at 90% 0%, rgba(24,242,210,0.08), transparent 0 28%);
    }

    .mini-panel {
      border-radius: 22px;
      background: rgba(126,184,226,0.05);
      border: 1px solid rgba(126,184,226,0.12);
      padding: 18px;
    }

    .mini-head {
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 10px;
      margin-bottom: 12px;
    }

    .mini-head h3 {
      margin: 0;
      font-size: 1rem;
      letter-spacing: -0.02em;
    }

    .mini-head span {
      color: var(--soft);
      font-size: 0.78rem;
      text-transform: uppercase;
      letter-spacing: 0.12em;
      font-weight: 800;
    }

    .weather-grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 12px;
    }

    .wx {
      border-radius: 16px;
      padding: 14px;
      background: rgba(255,255,255,0.02);
      border: 1px solid rgba(126,184,226,0.08);
    }

    .wx strong { display: block; font-size: 1.25rem; margin-bottom: 4px; }
    .wx span { color: var(--muted); font-size: 0.86rem; }

    .progress-block {
      display: grid;
      gap: 12px;
    }

    .bar-shell {
      width: 100%;
      height: 14px;
      border-radius: 999px;
      background: rgba(126,184,226,0.1);
      overflow: hidden;
      border: 1px solid rgba(126,184,226,0.12);
    }

    .bar-fill {
      height: 100%;
      width: 56%;
      border-radius: 999px;
      background: linear-gradient(90deg, var(--accent-2), var(--accent));
      box-shadow: 0 0 18px rgba(67,199,255,0.22);
    }

    .split {
      display: flex;
      justify-content: space-between;
      gap: 12px;
      color: var(--muted);
      font-size: 0.92rem;
    }

    .content-grid {
      display: grid;
      grid-template-columns: 1.2fr 0.8fr;
      gap: 18px;
      margin-bottom: 18px;
    }

    .stack { display: grid; gap: 18px; }

    .section-card {
      padding: 22px;
    }

    .section-top {
      display: flex;
      justify-content: space-between;
      gap: 16px;
      align-items: flex-start;
      margin-bottom: 18px;
    }

    .section-top h2 {
      margin: 0;
      font-size: 1.28rem;
      letter-spacing: -0.03em;
    }

    .section-top p {
      margin: 8px 0 0;
      color: var(--muted);
      line-height: 1.6;
      font-size: 0.95rem;
      max-width: 68ch;
    }

    .badge {
      padding: 9px 12px;
      border-radius: 999px;
      font-size: 0.78rem;
      text-transform: uppercase;
      letter-spacing: 0.1em;
      font-weight: 800;
      white-space: nowrap;
      border: 1px solid transparent;
    }

    .badge-accent { background: rgba(67,199,255,0.1); color: var(--accent); border-color: rgba(67,199,255,0.18); }
    .badge-good { background: rgba(125,242,183,0.1); color: var(--good); border-color: rgba(125,242,183,0.18); }
    .badge-warn { background: rgba(255,198,97,0.1); color: var(--warn); border-color: rgba(255,198,97,0.18); }

    .leg-grid {
      display: grid;
      grid-template-columns: 1.15fr 0.85fr;
      gap: 16px;
    }

    .route-box,
    .detail-box,
    .list-box,
    .action-box,
    .log-box,
    .timeline-box,
    .contacts-box,
    .floatplan-box {
      border-radius: 20px;
      background: rgba(126,184,226,0.05);
      border: 1px solid rgba(126,184,226,0.12);
      padding: 18px;
    }

    .route-path {
      display: grid;
      gap: 16px;
      margin-top: 10px;
    }

    .route-stop {
      display: grid;
      grid-template-columns: 18px 1fr auto;
      gap: 14px;
      align-items: center;
    }

    .dot {
      width: 18px;
      height: 18px;
      border-radius: 50%;
      position: relative;
      border: 2px solid var(--accent);
      box-shadow: 0 0 0 5px rgba(67,199,255,0.08);
    }

    .dot.done { border-color: var(--good); }
    .dot.current { border-color: var(--accent-3); }
    .dot.future { border-color: rgba(126,184,226,0.4); box-shadow: none; }

    .route-stop b { display: block; font-size: 0.96rem; }
    .route-stop span { display: block; color: var(--muted); font-size: 0.88rem; margin-top: 2px; }
    .route-stop small { color: var(--soft); font-size: 0.86rem; }

    .data-grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 12px;
    }

    .data-item {
      padding: 14px;
      border-radius: 16px;
      background: rgba(255,255,255,0.02);
      border: 1px solid rgba(126,184,226,0.08);
    }

    .data-item span {
      display: block;
      color: var(--soft);
      font-size: 0.76rem;
      text-transform: uppercase;
      letter-spacing: 0.12em;
      margin-bottom: 8px;
      font-weight: 800;
    }

    .data-item strong {
      display: block;
      font-size: 1.2rem;
      letter-spacing: -0.03em;
      line-height: 1.1;
    }

    .data-item small {
      display: block;
      color: var(--muted);
      font-size: 0.86rem;
      margin-top: 6px;
      line-height: 1.45;
    }

    .timeline {
      display: grid;
      gap: 14px;
    }

    .timeline-row {
      display: grid;
      grid-template-columns: 84px 18px 1fr;
      gap: 14px;
      align-items: start;
    }

    .timeline-time {
      color: var(--soft);
      font-size: 0.86rem;
      font-weight: 700;
      padding-top: 2px;
    }

    .timeline-node {
      width: 18px;
      height: 18px;
      border-radius: 50%;
      border: 2px solid var(--accent);
      position: relative;
      margin-top: 1px;
    }

    .timeline-node::after {
      content: "";
      position: absolute;
      left: 6px;
      top: 18px;
      width: 2px;
      height: 34px;
      background: rgba(126,184,226,0.18);
    }

    .timeline-row:last-child .timeline-node::after { display: none; }

    .timeline-copy b {
      display: block;
      font-size: 0.95rem;
      margin-bottom: 4px;
    }

    .timeline-copy span {
      display: block;
      color: var(--muted);
      line-height: 1.55;
      font-size: 0.9rem;
    }

    .contact-list,
    .quick-actions,
    .log-list {
      display: grid;
      gap: 12px;
    }

    .contact-row,
    .action-row,
    .log-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      padding: 14px 16px;
      border-radius: 16px;
      background: rgba(255,255,255,0.02);
      border: 1px solid rgba(126,184,226,0.08);
    }

    .contact-row b,
    .action-row b,
    .log-row b { display: block; font-size: 0.95rem; }
    .contact-row span,
    .action-row span,
    .log-row span { color: var(--muted); font-size: 0.88rem; display: block; margin-top: 4px; }

    .action-mini {
      padding: 8px 12px;
      border-radius: 999px;
      font-size: 0.8rem;
      font-weight: 800;
      color: var(--accent);
      background: rgba(67,199,255,0.08);
      border: 1px solid rgba(67,199,255,0.16);
      white-space: nowrap;
    }

    .footer-band {
      display: grid;
      grid-template-columns: 1fr 1fr 1fr;
      gap: 18px;
    }

    .foot-card {
      padding: 20px;
      border-radius: 22px;
      background: var(--panel-2);
      border: 1px solid var(--line);
      box-shadow: var(--shadow);
    }

    .foot-card h3 {
      margin: 0 0 10px;
      font-size: 1rem;
      letter-spacing: -0.02em;
    }

    .foot-card p {
      margin: 0;
      color: var(--muted);
      line-height: 1.65;
      font-size: 0.92rem;
    }

    @media (max-width: 1240px) {
      .hero,
      .content-grid,
      .leg-grid,
      .footer-band {
        grid-template-columns: 1fr;
      }

      .header-stats {
        grid-template-columns: repeat(3, minmax(0, 1fr));
      }
    }

    @media (max-width: 860px) {
      .shell { width: min(calc(100% - 18px), var(--max)); }
      .topbar-inner,
      .title-row,
      .section-top {
        flex-direction: column;
        align-items: flex-start;
      }

      .top-actions { justify-content: flex-start; }
      .header-stats,
      .weather-grid,
      .data-grid { grid-template-columns: 1fr 1fr; }
    }

    @media (max-width: 640px) {
      .header-stats,
      .weather-grid,
      .data-grid,
      .footer-band { grid-template-columns: 1fr; }

      .timeline-row {
        grid-template-columns: 72px 16px 1fr;
      }
    }
  </style>
</head>
<body data-fpw-page="active-cruise-console">
  <header class="topbar">
    <div class="shell topbar-inner">
      <div class="brand">
        <div class="brand-mark">⚓</div>
        <div class="brand-copy">
          <div class="brand-title">FloatPlanWizard • Active Cruise Console</div>
          <div class="brand-sub">Private operational view for the captain and trip owner</div>
        </div>
      </div>
      <div class="top-actions">
        <div class="chip" data-fpw-field="top.routeName"><cfoutput>#encodeForHtml(activeCruiseView.topRouteChip)#</cfoutput></div>
        <div class="chip" data-fpw-field="top.floatPlanState"><cfoutput>#encodeForHtml(activeCruiseView.topFloatPlanState)#</cfoutput></div>
        <button class="btn btn-secondary">View Follower Page</button>
        <button class="btn btn-primary">Check In Now</button>
      </div>
    </div>
  </header>

  <main class="main">
    <div class="shell">
      <section class="hero">
        <div class="panel hero-main">
          <div class="eyebrow">Voyage Console • Live Trip View</div>
          <div class="title-row">
            <div>
              <h1 data-fpw-field="hero.routeTitle"><cfoutput>#encodeForHtml(activeCruiseView.heroRouteTitle)#</cfoutput></h1>
              <div class="subline">
                A focused operational page for the active trip. Designed to help the captain quickly see current leg status, route progress, float plan state, weather, contacts, and the next action without digging through planning screens.
              </div>
            </div>
            <div class="status-pill">
              <b>Voyage Status</b>
              <strong data-fpw-field="hero.voyageStatus"><cfoutput>#encodeForHtml(activeCruiseView.heroVoyageStatus)#</cfoutput></strong>
            </div>
          </div>

          <div class="header-stats">
            <div class="metric">
              <span>Current Leg</span>
              <strong data-fpw-field="hero.currentLegSummary"><cfoutput>#encodeForHtml(activeCruiseView.heroCurrentLegSummary)#</cfoutput></strong>
              <small data-fpw-field="hero.legMeta"><cfoutput>#encodeForHtml(activeCruiseView.heroLegMeta)#</cfoutput></small>
            </div>
            <div class="metric">
              <span>Distance Complete</span>
              <strong data-fpw-field="hero.distanceComplete"><cfoutput>#encodeForHtml(activeCruiseView.heroDistanceComplete)#</cfoutput></strong>
              <small data-fpw-field="hero.percentComplete"><cfoutput>#encodeForHtml(activeCruiseView.heroPercentComplete)#</cfoutput></small>
            </div>
            <div class="metric">
              <span>Next Stop</span>
              <strong data-fpw-field="hero.nextStop"><cfoutput>#encodeForHtml(activeCruiseView.heroNextStop)#</cfoutput></strong>
              <small data-fpw-field="hero.nextStopMeta"><cfoutput>#encodeForHtml(activeCruiseView.heroNextStopMeta)#</cfoutput></small>
            </div>
            <div class="metric">
              <span>ETA</span>
              <strong data-fpw-field="hero.eta"><cfoutput>#encodeForHtml(activeCruiseView.heroEta)#</cfoutput></strong>
              <small data-fpw-field="hero.etaMeta"><cfoutput>#encodeForHtml(activeCruiseView.heroEtaMeta)#</cfoutput></small>
            </div>
            <div class="metric">
              <span>Last Check-In</span>
              <strong data-fpw-field="hero.lastCheckIn"><cfoutput>#encodeForHtml(activeCruiseView.heroLastCheckIn)#</cfoutput></strong>
              <small data-fpw-field="hero.nextExpectedCheckIn"><cfoutput>#encodeForHtml(activeCruiseView.heroNextExpectedCheckIn)#</cfoutput></small>
            </div>
          </div>
        </div>

        <aside class="panel hero-side">
          <div class="mini-panel">
            <div class="mini-head">
              <h3>Weather Snapshot</h3>
              <span>Current</span>
            </div>
            <div class="weather-grid">
              <div class="wx"><strong data-fpw-field="weather.wind">12 kt</strong><span>SE wind</span></div>
              <div class="wx"><strong data-fpw-field="weather.gusts">18 kt</strong><span>gusts</span></div>
              <div class="wx"><strong data-fpw-field="weather.waves">2.3 ft</strong><span>wave height</span></div>
              <div class="wx"><strong data-fpw-field="weather.visibility">10 mi</strong><span>visibility</span></div>
            </div>
          </div>

          <div class="mini-panel">
            <div class="mini-head">
              <h3>Leg Progress</h3>
              <span>Live</span>
            </div>
            <div class="progress-block">
              <div class="bar-shell"><div class="bar-fill" style="width:<cfoutput>#encodeForHtmlAttribute(activeCruiseView.progressBarWidth)#</cfoutput>;"></div></div>
              <div class="split"><span data-fpw-field="leg.remainingDistance"><cfoutput>#encodeForHtml(activeCruiseView.legRemainingDistance)#</cfoutput></span><span data-fpw-field="leg.percentComplete"><cfoutput>#encodeForHtml(activeCruiseView.legPercentComplete)#</cfoutput></span></div>
              <div class="split"><span data-fpw-field="leg.pace"><cfoutput>#encodeForHtml(activeCruiseView.legPace)#</cfoutput></span><span data-fpw-field="leg.remainingFuel"><cfoutput>#encodeForHtml(activeCruiseView.legRemainingFuel)#</cfoutput></span></div>
            </div>
          </div>

          <div class="mini-panel">
            <div class="mini-head">
              <h3>Float Plan Monitor</h3>
              <span>Attached</span>
            </div>
            <div class="split"><span>Status</span><strong style="color:<cfoutput>#encodeForHtmlAttribute(activeCruiseView.monitorStatusColor)#</cfoutput>;" data-fpw-field="monitor.status"><cfoutput>#encodeForHtml(activeCruiseView.monitorStatus)#</cfoutput></strong></div>
            <div class="split" style="margin-top:10px;"><span>Follower Page</span><strong style="color:var(--accent);" data-fpw-field="monitor.followerState"><cfoutput>#encodeForHtml(activeCruiseView.monitorFollowerState)#</cfoutput></strong></div>
            <div class="split" style="margin-top:10px;"><span>Emergency Contact</span><strong data-fpw-field="monitor.emergencyContact"><cfoutput>#encodeForHtml(activeCruiseView.monitorEmergencyContact)#</cfoutput></strong></div>
          </div>
        </aside>
      </section>

      <section class="content-grid">
        <div class="stack">
          <div class="panel section-card">
            <div class="section-top">
              <div>
                <h2>Current Leg Overview</h2>
                <p>This area gives the captain the immediate operational picture: departure point, current destination, remaining distance, pace, fuel outlook, and upcoming timing for the leg in progress.</p>
              </div>
              <div class="badge badge-accent">Captain View</div>
            </div>

            <div class="leg-grid">
              <div class="route-box">
                <div class="mini-head" style="margin-bottom:16px;">
                  <h3>Leg Route</h3>
                  <span>Today</span>
                </div>
                <div class="route-path">
                  <div class="route-stop">
                    <div class="dot done"></div>
                    <div>
                      <b data-fpw-field="leg.routeStop1Title"><cfoutput>#encodeForHtml(activeCruiseView.routeStop1Title)#</cfoutput></b>
                      <span data-fpw-field="leg.routeStop1Detail"><cfoutput>#encodeForHtml(activeCruiseView.routeStop1Detail)#</cfoutput></span>
                    </div>
                    <small data-fpw-field="leg.routeStop1Stamp"><cfoutput>#encodeForHtml(activeCruiseView.routeStop1Stamp)#</cfoutput></small>
                  </div>
                  <div class="route-stop">
                    <div class="dot done"></div>
                    <div>
                      <b data-fpw-field="leg.routeStop2Title"><cfoutput>#encodeForHtml(activeCruiseView.routeStop2Title)#</cfoutput></b>
                      <span data-fpw-field="leg.routeStop2Detail"><cfoutput>#encodeForHtml(activeCruiseView.routeStop2Detail)#</cfoutput></span>
                    </div>
                    <small data-fpw-field="leg.routeStop2Stamp"><cfoutput>#encodeForHtml(activeCruiseView.routeStop2Stamp)#</cfoutput></small>
                  </div>
                  <div class="route-stop">
                    <div class="dot current"></div>
                    <div>
                      <b data-fpw-field="leg.routeStop3Title"><cfoutput>#encodeForHtml(activeCruiseView.routeStop3Title)#</cfoutput></b>
                      <span data-fpw-field="leg.routeStop3Detail"><cfoutput>#encodeForHtml(activeCruiseView.routeStop3Detail)#</cfoutput></span>
                    </div>
                    <small data-fpw-field="leg.routeStop3Stamp"><cfoutput>#encodeForHtml(activeCruiseView.routeStop3Stamp)#</cfoutput></small>
                  </div>
                  <div class="route-stop">
                    <div class="dot future"></div>
                    <div>
                      <b data-fpw-field="leg.routeStop4Title"><cfoutput>#encodeForHtml(activeCruiseView.routeStop4Title)#</cfoutput></b>
                      <span data-fpw-field="leg.routeStop4Detail"><cfoutput>#encodeForHtml(activeCruiseView.routeStop4Detail)#</cfoutput></span>
                    </div>
                    <small data-fpw-field="leg.routeStop4Stamp"><cfoutput>#encodeForHtml(activeCruiseView.routeStop4Stamp)#</cfoutput></small>
                  </div>
                </div>
              </div>

              <div class="detail-box">
                <div class="mini-head" style="margin-bottom:16px;">
                  <h3>Leg Data</h3>
                  <span>Computed</span>
                </div>
                <div class="data-grid">
                  <div class="data-item">
                    <span>Distance</span>
                    <strong data-fpw-field="leg.distance"><cfoutput>#encodeForHtml(activeCruiseView.legDistance)#</cfoutput></strong>
                    <small>Total leg length</small>
                  </div>
                  <div class="data-item">
                    <span>Remaining</span>
                    <strong data-fpw-field="leg.remaining"><cfoutput>#encodeForHtml(activeCruiseView.legRemaining)#</cfoutput></strong>
                    <small>Approximate to stop</small>
                  </div>
                  <div class="data-item">
                    <span>Pace</span>
                    <strong data-fpw-field="leg.dataPace"><cfoutput>#encodeForHtml(activeCruiseView.legDataPace)#</cfoutput></strong>
                    <small>Weather-adjusted cruise</small>
                  </div>
                  <div class="data-item">
                    <span>Fuel Need</span>
                    <strong data-fpw-field="leg.fuelNeed"><cfoutput>#encodeForHtml(activeCruiseView.legFuelNeed)#</cfoutput></strong>
                    <small>Estimated for remainder</small>
                  </div>
                  <div class="data-item">
                    <span>Reserve</span>
                    <strong data-fpw-field="leg.reserveFuel"><cfoutput>#encodeForHtml(activeCruiseView.legReserveFuel)#</cfoutput></strong>
                    <small>Target reserve retained</small>
                  </div>
                  <div class="data-item">
                    <span>Arrival</span>
                    <strong data-fpw-field="leg.arrival"><cfoutput>#encodeForHtml(activeCruiseView.legArrival)#</cfoutput></strong>
                    <small>Based on current conditions</small>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class="panel section-card">
            <div class="section-top">
              <div>
                <h2>Route Timeline & Current Notes</h2>
                <p>This section acts as the active voyage log. It gives the member a clean operational history for the current day and makes it easy to see what happened, what changed, and what needs attention next.</p>
              </div>
              <div class="badge badge-good">Operational Log</div>
            </div>

            <div class="leg-grid">
              <div class="timeline-box">
                <div class="mini-head" style="margin-bottom:16px;">
                  <h3>Today’s Timeline</h3>
                  <span>Chronological</span>
                </div>
                <div class="timeline">
                  <div class="timeline-row">
                    <div class="timeline-time">7:15 AM</div>
                    <div class="timeline-node"></div>
                    <div class="timeline-copy">
                      <b>Departed current route origin</b>
                      <span>Trip started on schedule based on the active route instance.</span>
                    </div>
                  </div>
                  <div class="timeline-row">
                    <div class="timeline-time">10:50 AM</div>
                    <div class="timeline-node"></div>
                    <div class="timeline-copy">
                      <b>Fuel / systems check logged</b>
                      <span>Burn rate aligned with route estimate. No issues noted.</span>
                    </div>
                  </div>
                  <div class="timeline-row">
                    <div class="timeline-time">1:12 PM</div>
                    <div class="timeline-node"></div>
                    <div class="timeline-copy">
                      <b>Captain check-in submitted</b>
                      <span>Float plan monitoring updated. Follower page remains active.</span>
                    </div>
                  </div>
                  <div class="timeline-row">
                    <div class="timeline-time">2:05 PM</div>
                    <div class="timeline-node"></div>
                    <div class="timeline-copy">
                      <b>Weather note added</b>
                      <span>Wind forecast suggests tighter docking conditions later in the day.</span>
                    </div>
                  </div>
                </div>
              </div>

              <div class="log-box">
                <div class="mini-head" style="margin-bottom:16px;">
                  <h3>Quick Notes</h3>
                  <span>Editable</span>
                </div>
                <div class="log-list">
                  <div class="log-row">
                    <div>
                      <b>Approach marina before evening wind shift</b>
                      <span>Best arrival window appears before 5 PM.</span>
                    </div>
                    <div class="action-mini">Priority</div>
                  </div>
                  <div class="log-row">
                    <div>
                      <b>Call marina on final approach</b>
                      <span>Slip confirmation and dockside instructions.</span>
                    </div>
                    <div class="action-mini">Docking</div>
                  </div>
                  <div class="log-row">
                    <div>
                      <b>Fuel available after arrival</b>
                      <span>Optional top-off for tomorrow’s departure leg.</span>
                    </div>
                    <div class="action-mini">Fuel</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="stack">
          <div class="panel section-card">
            <div class="section-top">
              <div>
                <h2>Attached Float Plan</h2>
                <p>Keep the active trip tied to the actual filed float plan so the member can instantly verify monitoring status, check-in schedule, and emergency contact setup.</p>
              </div>
              <div class="badge badge-good">Monitoring Active</div>
            </div>
            <div class="floatplan-box">
              <div class="data-grid">
                <div class="data-item">
                  <span>Plan Status</span>
                  <strong data-fpw-field="floatPlan.status"><cfoutput>#encodeForHtml(activeCruiseView.floatPlanStatus)#</cfoutput></strong>
                  <small>Monitoring engaged</small>
                </div>
                <div class="data-item">
                  <span>Plan ID</span>
                  <strong data-fpw-field="floatPlan.id"><cfoutput>#encodeForHtml(activeCruiseView.floatPlanIdLabel)#</cfoutput></strong>
                  <small>Linked to this route instance</small>
                </div>
                <div class="data-item">
                  <span>Last Check-In</span>
                  <strong data-fpw-field="floatPlan.lastCheckIn"><cfoutput>#encodeForHtml(activeCruiseView.floatPlanLastCheckIn)#</cfoutput></strong>
                  <small>Captain confirmed status</small>
                </div>
                <div class="data-item">
                  <span>Next Expected</span>
                  <strong data-fpw-field="floatPlan.nextExpected"><cfoutput>#encodeForHtml(activeCruiseView.floatPlanNextExpected)#</cfoutput></strong>
                  <small>Monitoring schedule</small>
                </div>
              </div>
            </div>
          </div>

          <div class="panel section-card">
            <div class="section-top">
              <div>
                <h2>Crew & Emergency Contacts</h2>
                <p>Quick-reference operational contacts without forcing the user back into edit screens.</p>
              </div>
              <div class="badge badge-warn">Reference</div>
            </div>
            <div class="contacts-box">
              <div class="contact-list">
                <div class="contact-row">
                  <div>
                    <b data-fpw-field="contacts.captain"><cfoutput>#encodeForHtml(activeCruiseView.captainContact)#</cfoutput></b>
                    <span>Primary trip owner and operator</span>
                  </div>
                  <div class="action-mini">Owner</div>
                </div>
                <div class="contact-row">
                  <div>
                    <b data-fpw-field="contacts.crew1"><cfoutput>#encodeForHtml(activeCruiseView.crewContact)#</cfoutput></b>
                    <span>Manifested on current trip</span>
                  </div>
                  <div class="action-mini">Crew</div>
                </div>
                <div class="contact-row">
                  <div>
                    <b data-fpw-field="contacts.emergency"><cfoutput>#encodeForHtml(activeCruiseView.emergencyContact)#</cfoutput></b>
                    <span>Primary monitoring contact for this float plan</span>
                  </div>
                  <div class="action-mini">Alert</div>
                </div>
              </div>
            </div>
          </div>

          <div class="panel section-card">
            <div class="section-top">
              <div>
                <h2>Quick Actions</h2>
                <p>Operational shortcuts that make this page worth keeping open during the trip.</p>
              </div>
              <div class="badge badge-accent">Action Center</div>
            </div>
            <div class="action-box">
              <div class="quick-actions">
                <div class="action-row">
                  <div>
                    <b>Submit Check-In</b>
                    <span>Record current status and satisfy monitoring expectations.</span>
                  </div>
                  <div class="action-mini">Run</div>
                </div>
                <div class="action-row">
                  <div>
                    <b>Update ETA</b>
                    <span>Push an updated arrival expectation to the trip record.</span>
                  </div>
                  <div class="action-mini">Edit</div>
                </div>
                <div class="action-row">
                  <div>
                    <b>Add Log Entry</b>
                    <span>Capture operational notes, conditions, or route observations.</span>
                  </div>
                  <div class="action-mini">Add</div>
                </div>
                <div class="action-row">
                  <div>
                    <b>Open Follower Page</b>
                    <span>Preview what family and friends are seeing right now.</span>
                  </div>
                  <div class="action-mini">View</div>
                </div>
                <div class="action-row">
                  <div>
                    <b>View Full Float Plan</b>
                    <span>Review the attached plan, crew, vessel, and emergency details.</span>
                  </div>
                  <div class="action-mini">Open</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section class="footer-band">
        <div class="foot-card">
          <h3>Why this screen matters</h3>
          <p>This is not just another dashboard. It is the private, active-trip view that gives the member the immediate operational context they need while underway or preparing for the next stop.</p>
        </div>
        <div class="foot-card">
          <h3>Best use case</h3>
          <p>Ideal on a tablet in the cabin, at the helm before departure, or during long-distance cruising where route progress, float plan monitoring, and next actions all need to stay visible.</p>
        </div>
        <div class="foot-card">
          <h3>FPW fit</h3>
          <p>This bridges the gap between route planning and follower sharing. It turns FPW into an actual in-trip companion, not just a pre-departure planning tool.</p>
        </div>
      </section>
    </div>
  </main>
  <script id="fpw-active-cruise-hooks" type="application/json"><cfoutput>#activeCruiseHooksJson#</cfoutput></script>
</body>
</html>
