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

  function fpwNormalizeCheckInContext(any rawValue) {
    var contextVal = lCase(trim(toString(arguments.rawValue)));
    if (contextVal EQ "overnight") {
      return "overnight";
    }
    return "";
  }

  function fpwFormatElapsedCheckIn(any dtValue, string fallback="-- since last check-in") {
    var elapsedMinutes = 0;
    var hours = 0;
    var minutes = 0;

    if (!isDate(arguments.dtValue)) {
      return arguments.fallback;
    }

    elapsedMinutes = dateDiff("n", arguments.dtValue, now());
    if (elapsedMinutes LT 0) {
      elapsedMinutes = 0;
    }
    if (elapsedMinutes LT 60) {
      return elapsedMinutes & " min since last check-in";
    }

    hours = int(elapsedMinutes / 60);
    minutes = elapsedMinutes MOD 60;
    if (minutes LTE 0) {
      return hours & "h since last check-in";
    }
    return hours & "h " & minutes & "m since last check-in";
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

  function fpwFormatUtcIso(any dtValue) {
    if (!isDate(arguments.dtValue)) {
      return "";
    }
    return dateTimeFormat(dateConvert("local2Utc", arguments.dtValue), "yyyy-mm-dd'T'HH:nn:ss'Z'");
  }

  function fpwBuildTripLocalTime(any referenceDt, string timeZoneId, numeric hourValue=8, numeric minuteValue=0, numeric secondValue=0, boolean advanceDay=false) {
    var tzId = trim(arguments.timeZoneId);
    var localCalendar = "";
    var localTimeZone = "";
    if (!isDate(arguments.referenceDt) OR !len(tzId)) {
      return "";
    }
    try {
      localTimeZone = createObject("java", "java.util.TimeZone").getTimeZone(tzId);
      localCalendar = createObject("java", "java.util.GregorianCalendar").init(localTimeZone);
      localCalendar.setTime(arguments.referenceDt);
      if (arguments.advanceDay) {
        localCalendar.add(5, 1);
      }
      localCalendar.set(11, int(arguments.hourValue));
      localCalendar.set(12, int(arguments.minuteValue));
      localCalendar.set(13, int(arguments.secondValue));
      localCalendar.set(14, 0);
      return localCalendar.getTime();
    } catch (any tripLocalHourErr) {
      return "";
    }
  }

  function fpwNormalizeLocalTimeValue(any rawValue, string defaultValue="08:00:00") {
    var normalized = trim(toString(arguments.rawValue));
    var parts = [];
    var hh = 0;
    var mm = 0;
    var ss = 0;
    if (!len(normalized)) {
      return arguments.defaultValue;
    }
    parts = listToArray(normalized, ":");
    if (arrayLen(parts) LT 2 OR arrayLen(parts) GT 3) {
      return arguments.defaultValue;
    }
    if (!isNumeric(parts[1]) OR !isNumeric(parts[2]) OR (arrayLen(parts) EQ 3 AND !isNumeric(parts[3]))) {
      return arguments.defaultValue;
    }
    hh = val(parts[1]);
    mm = val(parts[2]);
    ss = (arrayLen(parts) EQ 3 ? val(parts[3]) : 0);
    if (hh LT 0 OR hh GT 23 OR mm LT 0 OR mm GT 59 OR ss LT 0 OR ss GT 59) {
      return arguments.defaultValue;
    }
    return numberFormat(hh, "00") & ":" & numberFormat(mm, "00") & ":" & numberFormat(ss, "00");
  }

  function fpwLocalTimePart(string timeValue, numeric indexValue=1, numeric defaultValue=0) {
    var normalized = fpwNormalizeLocalTimeValue(arguments.timeValue, "");
    var parts = [];
    if (!len(normalized)) {
      return int(arguments.defaultValue);
    }
    parts = listToArray(normalized, ":");
    if (arguments.indexValue LT 1 OR arguments.indexValue GT arrayLen(parts)) {
      return int(arguments.defaultValue);
    }
    return int(val(parts[arguments.indexValue]));
  }

  function fpwFormatLocalTimeLabel(any rawValue, string fallback="8:00 AM") {
    var normalized = fpwNormalizeLocalTimeValue(arguments.rawValue, "");
    var displayDt = "";
    if (!len(normalized)) {
      return arguments.fallback;
    }
    displayDt = createDateTime(
      2000,
      1,
      1,
      fpwLocalTimePart(normalized, 1, 8),
      fpwLocalTimePart(normalized, 2, 0),
      fpwLocalTimePart(normalized, 3, 0)
    );
    return timeFormat(displayDt, "h:nn tt");
  }

  function fpwFormatLocalTimeInput(any rawValue, string fallback="08:00") {
    var normalized = fpwNormalizeLocalTimeValue(arguments.rawValue, "");
    if (!len(normalized)) {
      return arguments.fallback;
    }
    return left(normalized, 5);
  }

  function fpwComputeExperimentalElapsedHours(any nowDt, any startDt, any pauseStartDt="", any resumeDt="") {
    var elapsedMinutes = 0;
    var pauseMinutes = 0;
    var pauseEndDt = "";
    if (!isDate(arguments.nowDt) OR !isDate(arguments.startDt)) {
      return 0;
    }
    elapsedMinutes = dateDiff("n", arguments.startDt, arguments.nowDt);
    if (elapsedMinutes LT 0) {
      elapsedMinutes = 0;
    }
    if (isDate(arguments.pauseStartDt) AND dateCompare(arguments.nowDt, arguments.pauseStartDt, "s") GT 0) {
      pauseEndDt = arguments.nowDt;
      if (isDate(arguments.resumeDt) AND dateCompare(arguments.nowDt, arguments.resumeDt, "s") GT 0) {
        pauseEndDt = arguments.resumeDt;
      }
      pauseMinutes = dateDiff("n", arguments.pauseStartDt, pauseEndDt);
      if (pauseMinutes GT 0) {
        elapsedMinutes -= pauseMinutes;
      }
    }
    if (elapsedMinutes LT 0) {
      elapsedMinutes = 0;
    }
    return fpwRoundTo2(elapsedMinutes / 60);
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

  function fpwEnsureScheduledTripStart(required numeric userId, required numeric floatPlanId) {
    var result = {
      SUCCESS = false,
      TRIP_STARTED = true,
      PENDING_START = false,
      MESSAGE = "Unable to evaluate the scheduled departure gate."
    };
    var floatPlanComponent = "";

    if (arguments.userId LTE 0 OR arguments.floatPlanId LTE 0) {
      result.MESSAGE = "A valid owner and float plan are required.";
      return result;
    }

    try {
      floatPlanComponent = createObject("component", "fpw.api.v1.floatplan");
    } catch (any floatPlanPathErr) {
      floatPlanComponent = createObject("component", "api.v1.floatplan");
    }

    result = floatPlanComponent.ensureOperationalStartForScheduledPlan(arguments.userId, arguments.floatPlanId);
    if (!isStruct(result)) {
      result = {
        SUCCESS = false,
        TRIP_STARTED = true,
        PENDING_START = false,
        MESSAGE = "Unable to evaluate the scheduled departure gate."
      };
    }
    return result;
  }

  function fpwGetCanonicalFuelEstimate(required struct routeInputs, required numeric distanceNm, any idleFuelGallons=0) {
    var result = {
      SUCCESS = false,
      MESSAGE = "Unable to calculate canonical fuel estimate.",
      FUEL_ESTIMATE = {}
    };
    var routeBuilderComponent = "";

    if (!isStruct(arguments.routeInputs) OR !structCount(arguments.routeInputs)) {
      result.MESSAGE = "Route inputs are required.";
      return result;
    }

    try {
      routeBuilderComponent = createObject("component", "fpw.api.v1.routeBuilder");
    } catch (any routeBuilderPathErr) {
      routeBuilderComponent = createObject("component", "api.v1.routeBuilder");
    }

    try {
      result = routeBuilderComponent.routegenEstimateFuelForDistance(
        routeInputs = duplicate(arguments.routeInputs),
        distanceNm = arguments.distanceNm,
        idleFuelGallons = arguments.idleFuelGallons
      );
    } catch (any routeBuilderFuelErr) {
      result = {
        SUCCESS = false,
        MESSAGE = "Unable to calculate canonical fuel estimate.",
        FUEL_ESTIMATE = {}
      };
    }

    if (!isStruct(result)) {
      result = {
        SUCCESS = false,
        MESSAGE = "Unable to calculate canonical fuel estimate.",
        FUEL_ESTIMATE = {}
      };
    }
    return result;
  }

  activeCruiseHooks = {
    context = {
      floatPlanId = fpwActiveCruiseHookValue("floatPlanId")
    },
    fields = {}
  };

  activeCruiseContext = {
    routeCode = "",
    routeId = 0,
    routeInstanceId = 0,
    floatPlanId = 0,
    requestedFloatPlanId = 0,
    activeRouteCode = ""
  };
  if (isNumeric(activeCruiseHooks.context.floatPlanId)) {
    activeCruiseContext.requestedFloatPlanId = val(activeCruiseHooks.context.floatPlanId);
  }

  activeCruiseAccessValid = false;
  activeCruiseAccessTitle = "No Active Trip";
  activeCruiseAccessMessage = "Active Cruise is available only for your current monitored trip.";
  activeCruiseAccessDetail = "Open this page from the one active float plan tied to your trip.";

  activeCruiseView = {
    topRouteChip = "Route: Gulf Coast Run",
    topFloatPlanState = "Float Plan: Active",
    heroRouteTitle = "Active Cruise Route",
    heroVoyageStatus = "Underway",
    heroVoyageStatusVariant = "good",
    heroCurrentLegSummary = "4 of 12",
    heroLegMeta = "Day 3 of 9 - Long-range coastal cruise",
    heroDistanceComplete = "142 nm",
    heroPercentComplete = "56% of active route completed",
    heroNextStop = "TBD",
    heroNextStopMeta = "Next planned stop",
    heroEta = "4:40 PM",
    heroEtaMeta = "Weather-adjusted arrival estimate",
    heroLastCheckIn = "--",
    heroNextExpectedCheckIn = "-- since last check-in",
    heroTripStart = "Trip Start: --",
    legRemainingDistance = "41 nm remaining",
    legPercentComplete = "56% complete",
    legPace = "Pace: 7.4 kt",
    legRemainingFuel = "Fuel est: 6.2 gal remaining",
    experimentalLegStatus = "Beta current-leg model unavailable",
    experimentalLegRemainingDistance = "—",
    experimentalLegPercentComplete = "—",
    experimentalLegPace = "Exp pace: —",
    experimentalLegRemainingFuel = "Exp fuel unavailable",
    experimentalLegMeta = "Assumes an 8:00 AM departure-timezone leg start for display only.",
    experimentalProgressBarWidth = "0%",
    monitorStatus = "Normal",
    monitorStatusColor = "var(--good)",
    monitorFollowerState = "Live",
    monitorEmergencyContact = "Abbe",
    monitorWeatherFactor = "—",
    monitorDailyStartLabel = "8:00 AM",
    monitorDailyStartInput = "08:00",
    legDistance = "82 nm",
    legRemaining = "41 nm",
    legDataPace = "7.4 kt",
    legFuelNeed = "6.2 gal",
    legReserveFuel = "18 gal",
    legArrival = "4:40 PM",
    floatPlanStatus = "Active",
    floatPlanIdLabel = "FP-240318",
    floatPlanLastCheckIn = "--",
    floatPlanNextExpected = "-- since last check-in",
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
  activeCruiseExperimental = {
    available = false,
    departureTimeZone = "",
    generatedAtUtc = "",
    baseStartUtc = "",
    pauseStartUtc = "",
    pauseResumeUtc = "",
    currentLegDistanceNm = 0,
    speedKn = 0,
    fuelBurnGph = 0,
    reservePct = 0,
    isOvernight = false,
    assumptionLabel = "Assumes an 8:00 AM departure-timezone leg start for display only.",
    statusLabel = "Beta current-leg model unavailable"
  };

  activeCruiseTimelineItems = [
    {
      time = "7:15 AM",
      title = "Departed current route origin",
      detail = "Trip started on schedule based on the active route instance."
    },
    {
      time = "10:50 AM",
      title = "Fuel / systems check logged",
      detail = "Burn rate aligned with route estimate. No issues noted."
    },
    {
      time = "1:12 PM",
      title = "Captain check-in submitted",
      detail = "Float plan monitoring updated. Follower page remains active."
    },
    {
      time = "2:05 PM",
      title = "Weather note added",
      detail = "Wind forecast suggests tighter docking conditions later in the day."
    }
  ];
  activeCruiseTripStartState = {};
  activeCruiseTripStarted = true;
  activeCruiseHasOperationalCheckIn = false;
  activeCruiseEyebrowLabel = "Voyage Console • Live Trip View";
  activeCruiseHeroSubline = "A focused operational page for the active trip.";
  activeCruiseProgressWindowLabel = "Live";
  activeCruiseLegRouteWindowLabel = "Today";
  activeCruiseCurrentLegCopy = "This area gives the captain the immediate operational picture: departure point, current destination, remaining distance, pace, fuel outlook, and upcoming timing for the leg in progress.";
  activeCruiseFloatPlanBadgeLabel = "Monitoring Active";
  activeCruiseFloatPlanStatusNote = "Monitoring engaged";
  activeCruiseFloatPlanNextExpectedNote = "Current check-in state";
  activeCruiseRouteStop1DotClass = "dot done";
  activeCruiseRouteStop2DotClass = "dot done";
  activeCruiseRouteStop3DotClass = "dot current";

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
      tripProgressPercentComplete = 0;
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
      expectedCheckInDt = "";
      dailyStartLocalTimeVal = "08:00:00";
      dailyStartHourVal = 8;
      dailyStartMinuteVal = 0;
      dailyStartSecondVal = 0;
      checkInContextVal = "";
      elapsedCheckInLabel = "-- since last check-in";
      isOvernightCheckIn = false;
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
      qTimelinePosts = queryNew("");
      qVoyageTables = queryNew("");
      qInputsColumn = queryNew("");
      qInstInputs = queryNew("");
      qTripStart = queryNew("");
      qPlanSql = "";
      qCanonicalPlan = queryNew("");
      requestedFloatPlanId = activeCruiseContext.requestedFloatPlanId;
      hasVoyageTables = false;
      hasRoutegenInputsCol = false;
      routeInputJsonRaw = "";
      routeInputs = {};
      routeInputCardSpeedKn = 0.0;
      routeInputSpeedKn = 0.0;
      routeInputFuelBurnGph = 0.0;
      routeInputReservePct = 0.0;
      routeWeatherFactorRaw = "";
      speedForFuelKn = 0.0;
      canonicalTripStartDt = "";
      currentLegHours = 0.0;
      baseFuelNeedGal = 0.0;
      reserveFuelNeedGal = 0.0;
      requiredFuelNeedGal = 0.0;
      fuelCalcReady = false;
	      progressByLeg = {};
	      progressStartedAtByLeg = {};
	      progressCompletedAtByLeg = {};
	      i = 0;
	      legOrder = 0;
	      legStatus = "";
	      isCompletedLeg = false;
	      highestCompletedLegOrder = 0;
	      currentLegOrder = 0;
	      currentLegStartedAt = "";
	      currentLegStartedAtCandidate = "";
	      priorLegCompletedAt = "";
	      priorLegCompletedAtCandidate = "";
	      activeLegRow = 0;
	      pendingLegRow = 0;
	      pendingLegOrder = 0;
	      awaitingDepartureStop = false;
	      activeCruiseCanCompleteLeg = false;
	      activeCruiseCanStartNextLeg = false;
	      displayLegRow = 0;
      timelineItems = [];
      timelinePostDt = "";

      qPlanSql =
        "SELECT
           fp.floatplanId,
           fp.floatPlanName,
           fp.status,
           fp.route_instance_id,
           fp.route_day_number,
           fp.checkedInAt,"
           & "
           fp.checkin_context,
           fp.returnTime,
           fp.returnTimezone,
           fp.departureTime,
           fp.departureTZ,
           fp.dailyStartLocalTime,
           fp.departing,
           fp.returning,
           (
             SELECT
               COALESCE(
                 CONVERT_TZ(
                   m.expected_checkin_at,
                   'UTC',
                   NULLIF(COALESCE(NULLIF(fp.departureTZ, ''), NULLIF(fp.departTimezone, ''), 'UTC'), '')
                 ),
                 m.expected_checkin_at
               )
             FROM floatplan_monitoring m
             WHERE m.float_plan_id = fp.floatplanId
               AND m.is_monitoring_enabled = 1
               AND UPPER(TRIM(m.monitor_state)) <> 'CLOSED'
             ORDER BY m.id DESC
             LIMIT 1
           ) AS expected_checkin_at
         FROM floatplans fp
         WHERE fp.userId = :userId
           AND UPPER(TRIM(fp.status)) IN (
             'ACTIVE',
             'DUE_NOW',
             'OVERDUE',
             'OVERDUE_1H',
             'OVERDUE_2H',
             'OVERDUE_3H',
             'OVERDUE_4H',
             'OVERDUE_12H',
             'OVERDUE_24H'
           )
         ORDER BY floatplanId DESC
         LIMIT 2";
      qCanonicalPlan = queryExecute(
        qPlanSql,
        {
          userId = { value = activeCruiseUserId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = activeCruiseDatasource }
      );

      if (qCanonicalPlan.recordCount EQ 0) {
        activeCruiseAccessMessage = "No active trip is available for this account.";
        activeCruiseAccessDetail = "Active Cruise only loads the current monitored float plan.";
      } else if (qCanonicalPlan.recordCount GT 1) {
        activeCruiseAccessMessage = "Active Cruise is unavailable because more than one monitored float plan is active.";
        activeCruiseAccessDetail = "Resolve the extra monitored trip before using this page.";
      } else {
        activeCruiseContext.floatPlanId = val(fpwQueryCell(qCanonicalPlan, "floatplanId", 1, 0));
        activeCruiseContext.routeInstanceId = val(fpwQueryCell(qCanonicalPlan, "route_instance_id", 1, 0));

        if (requestedFloatPlanId GT 0 AND requestedFloatPlanId NEQ activeCruiseContext.floatPlanId) {
          activeCruiseAccessMessage = "This Active Cruise link does not match your current active trip.";
          activeCruiseAccessDetail = "Open Active Cruise from the canonical active float plan only.";
          activeCruiseContext.floatPlanId = 0;
          activeCruiseContext.routeInstanceId = 0;
        } else if (activeCruiseContext.routeInstanceId LTE 0) {
          activeCruiseAccessMessage = "The current active float plan is missing its route link.";
          activeCruiseAccessDetail = "Active Cruise requires a route-linked active float plan.";
          activeCruiseContext.floatPlanId = 0;
        } else {
          qPlan = qCanonicalPlan;
          activeCruiseAccessValid = true;
          activeCruiseTripStartState = fpwEnsureScheduledTripStart(activeCruiseUserId, activeCruiseContext.floatPlanId);
          if (
            isStruct(activeCruiseTripStartState)
            AND structKeyExists(activeCruiseTripStartState, "SUCCESS")
            AND activeCruiseTripStartState.SUCCESS
            AND structKeyExists(activeCruiseTripStartState, "TRIP_STARTED")
          ) {
            activeCruiseTripStarted = (activeCruiseTripStartState.TRIP_STARTED EQ true);
          }
        }
      }

      if (activeCruiseAccessValid AND activeCruiseContext.routeInstanceId GT 0) {
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

      if (activeCruiseAccessValid AND qRouteCtx.recordCount EQ 1) {
        activeCruiseContext.routeInstanceId = val(fpwQueryCell(qRouteCtx, "route_instance_id", 1, 0));
        routeCodeDisplay = trim(toString(fpwQueryCell(qRouteCtx, "route_code", 1, activeCruiseContext.routeCode)));
        routeName = trim(toString(fpwQueryCell(qRouteCtx, "route_name", 1, "")));
      } else if (activeCruiseAccessValid) {
        activeCruiseAccessValid = false;
        activeCruiseAccessMessage = "The active trip could not load its route instance.";
        activeCruiseAccessDetail = "Active Cruise requires route data derived from the canonical active float plan.";
        activeCruiseContext.floatPlanId = 0;
        activeCruiseContext.routeInstanceId = 0;
      }

      if (activeCruiseAccessValid AND NOT len(routeName) AND len(routeCodeDisplay)) {
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

      if (qPlan.recordCount EQ 1) {
        activeCruiseContext.floatPlanId = val(fpwQueryCell(qPlan, "floatplanId", 1, 0));
        if (isDate(fpwQueryCell(qPlan, "departureTime", 1, ""))) {
          canonicalTripStartDt = fpwQueryCell(qPlan, "departureTime", 1, "");
        }
        planStatusRaw = trim(toString(fpwQueryCell(qPlan, "status", 1, "")));
        planStatusLabel = fpwStatusLabel(planStatusRaw, "Active");
        if (NOT len(planStatusLabel)) {
          planStatusLabel = "Unknown";
        }
        monitorStatus = fpwStatusLabel(planStatusRaw, "Normal");
        if (NOT len(monitorStatus)) {
          monitorStatus = "Unknown";
        }
        if (!activeCruiseTripStarted) {
          planStatusLabel = "Scheduled";
          monitorStatus = "Scheduled";
        }
        checkInContextVal = fpwNormalizeCheckInContext(fpwQueryCell(qPlan, "checkin_context", 1, ""));
        if (isDate(fpwQueryCell(qPlan, "checkedInAt", 1, ""))) {
          lastCheckInDt = fpwQueryCell(qPlan, "checkedInAt", 1, "");
        }
        if (isDate(fpwQueryCell(qPlan, "expected_checkin_at", 1, ""))) {
          expectedCheckInDt = fpwQueryCell(qPlan, "expected_checkin_at", 1, "");
        }
        dailyStartLocalTimeVal = fpwNormalizeLocalTimeValue(fpwQueryCell(qPlan, "dailyStartLocalTime", 1, ""), "08:00:00");
        dailyStartHourVal = fpwLocalTimePart(dailyStartLocalTimeVal, 1, 8);
        dailyStartMinuteVal = fpwLocalTimePart(dailyStartLocalTimeVal, 2, 0);
        dailyStartSecondVal = fpwLocalTimePart(dailyStartLocalTimeVal, 3, 0);
        activeCruiseHasOperationalCheckIn = (activeCruiseTripStarted AND isDate(lastCheckInDt));
        if (activeCruiseHasOperationalCheckIn AND isDate(canonicalTripStartDt)) {
          activeCruiseHasOperationalCheckIn = (dateCompare(lastCheckInDt, canonicalTripStartDt, "s") GTE 0);
        }
        if (!activeCruiseHasOperationalCheckIn) {
          lastCheckInDt = "";
        }
        isOvernightCheckIn = (activeCruiseHasOperationalCheckIn AND checkInContextVal EQ "overnight");
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
          "SELECT
             leg_order,
             status,
             completed_at,
             leg_started_at
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
          legOrder = val(fpwQueryCell(qProgress, "leg_order", i, 0));
          progressByLeg[toString(legOrder)] = uCase(trim(toString(fpwQueryCell(qProgress, "status", i, ""))));
          if (isDate(fpwQueryCell(qProgress, "leg_started_at", i, ""))) {
            progressStartedAtByLeg[toString(legOrder)] = fpwQueryCell(qProgress, "leg_started_at", i, "");
          }
          if (isDate(fpwQueryCell(qProgress, "completed_at", i, ""))) {
            progressCompletedAtByLeg[toString(legOrder)] = fpwQueryCell(qProgress, "completed_at", i, "");
          }
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
	            if (legOrder GT highestCompletedLegOrder) {
	              highestCompletedLegOrder = legOrder;
	            }
	          }
	        }

	        for (i = 1; i LTE qLegs.recordCount; i++) {
	          legOrder = val(fpwQueryCell(qLegs, "leg_order", i, i));
	          if (legOrder LTE highestCompletedLegOrder) {
	            continue;
	          }
	          if (pendingLegRow LTE 0) {
	            pendingLegRow = i;
	          }
	          legStatus = (structKeyExists(progressByLeg, toString(legOrder)) ? progressByLeg[toString(legOrder)] : "NOT_STARTED");
	          if (
	            structKeyExists(progressStartedAtByLeg, toString(legOrder))
	            OR legStatus EQ "STARTED"
	            OR legStatus EQ "IN_PROGRESS"
	          ) {
	            activeLegRow = i;
	            break;
	          }
	        }
	        if (activeCruiseTripStarted AND activeLegRow LTE 0 AND pendingLegRow GT 0 AND highestCompletedLegOrder GT 0 AND highestCompletedLegOrder LT totalLegs) {
	          awaitingDepartureStop = true;
	        }
	        if (pendingLegRow GT 0) {
	          pendingLegOrder = val(fpwQueryCell(qLegs, "leg_order", pendingLegRow, 0));
	        }
	        if (activeLegRow GT 0) {
	          nextStop = trim(toString(fpwQueryCell(qLegs, "end_name", activeLegRow, "")));
	        } else if (pendingLegRow GT 0) {
	          nextStop = trim(toString(fpwQueryCell(qLegs, "end_name", pendingLegRow, "")));
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
          tripProgressPercentComplete = round((completedLegs / totalLegs) * 100);
        } else {
          tripProgressPercentComplete = 0;
        }
        if (tripProgressPercentComplete LT 0) {
          tripProgressPercentComplete = 0;
        }
        if (tripProgressPercentComplete GT 100) {
          tripProgressPercentComplete = 100;
        }

	        if (totalLegs GT 0) {
	          displayLegRow = (activeLegRow GT 0 ? activeLegRow : (pendingLegRow GT 0 ? pendingLegRow : totalLegs));
	          currentLeg = displayLegRow;
	          currentLegOrder = val(fpwQueryCell(qLegs, "leg_order", displayLegRow, displayLegRow));
	          currentLegStartName = trim(toString(fpwQueryCell(qLegs, "start_name", displayLegRow, "")));
	          currentLegEndName = trim(toString(fpwQueryCell(qLegs, "end_name", displayLegRow, "")));
	          if (displayLegRow LT totalLegs) {
	            nextLegEndName = trim(toString(fpwQueryCell(qLegs, "end_name", displayLegRow + 1, "")));
	          }
          currentLegDistNm = val(fpwQueryCell(qLegs, "dist_nm", displayLegRow, 0));
          if (structKeyExists(progressStartedAtByLeg, toString(currentLegOrder)) AND isDate(progressStartedAtByLeg[toString(currentLegOrder)])) {
            currentLegStartedAtCandidate = progressStartedAtByLeg[toString(currentLegOrder)];
            if (!isDate(canonicalTripStartDt) OR dateCompare(currentLegStartedAtCandidate, canonicalTripStartDt, "s") GTE 0) {
              currentLegStartedAt = currentLegStartedAtCandidate;
            }
          }
	          if (highestCompletedLegOrder GT 0 AND structKeyExists(progressCompletedAtByLeg, toString(highestCompletedLegOrder)) AND isDate(progressCompletedAtByLeg[toString(highestCompletedLegOrder)])) {
	            priorLegCompletedAtCandidate = progressCompletedAtByLeg[toString(highestCompletedLegOrder)];
	            if (!isDate(canonicalTripStartDt) OR dateCompare(priorLegCompletedAtCandidate, canonicalTripStartDt, "s") GTE 0) {
	              priorLegCompletedAt = priorLegCompletedAtCandidate;
	            }
	          }
	        }
	        activeCruiseCanCompleteLeg = (activeLegRow GT 0);
	        activeCruiseCanStartNextLeg = (awaitingDepartureStop AND activeLegRow LTE 0 AND pendingLegOrder GT 0);
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

          if (streamLive) {
            qTimelinePosts = queryExecute(
              "SELECT recent.title, recent.body, recent.created_utc
               FROM (
                 SELECT id, title, body, created_utc
                 FROM voyage_posts
                 WHERE stream_id = :streamId
                 ORDER BY created_utc DESC, id DESC
                 LIMIT 4
               ) recent
               ORDER BY recent.created_utc ASC, recent.id ASC",
              {
                streamId = { value = val(fpwQueryCell(qStream, "id", 1, 0)), cfsqltype = "cf_sql_integer" }
              },
              { datasource = activeCruiseDatasource }
            );

	            if (qTimelinePosts.recordCount GT 0) {
	              timelineItems = [];
	              for (i = 1; i LTE qTimelinePosts.recordCount; i++) {
	                timelinePostDt = fpwQueryCell(qTimelinePosts, "created_utc", i, "");
                  if (isDate(canonicalTripStartDt) AND isDate(timelinePostDt) AND dateCompare(timelinePostDt, canonicalTripStartDt, "s") LT 0) {
                    continue;
                  }
	                arrayAppend(timelineItems, {
	                  time = fpwFormatClock(timelinePostDt, "--"),
	                  timeUtc = (isDate(timelinePostDt) ? dateTimeFormat(timelinePostDt, "yyyy-mm-dd'T'HH:nn:ss'Z'") : ""),
	                  title = trim(toString(fpwQueryCell(qTimelinePosts, "title", i, "Update"))),
	                  detail = trim(toString(fpwQueryCell(qTimelinePosts, "body", i, "")))
	                });
	              }
                if (arrayLen(timelineItems)) {
                  activeCruiseTimelineItems = timelineItems;
                }
            }
          }
        }
      }

      if (NOT activeCruiseHasOperationalCheckIn AND NOT activeCruiseTripStarted) {
        lastCheckInDt = "";
      } else if (NOT isDate(lastCheckInDt) AND isDate(fpwQueryCell(qPlan, "checkedInAt", 1, ""))) {
        lastCheckInDt = fpwQueryCell(qPlan, "checkedInAt", 1, "");
      }
      if (activeCruiseHasOperationalCheckIn AND isDate(lastCheckInDt)) {
        elapsedCheckInLabel = fpwFormatElapsedCheckIn(lastCheckInDt);
      } else if (activeCruiseTripStarted) {
        elapsedCheckInLabel = "Awaiting first check-in after departure.";
      } else {
        elapsedCheckInLabel = "Monitoring begins at scheduled departure.";
      }
      if (isOvernightCheckIn) {
        elapsedCheckInLabel = "Arrived and secure for the night. Next update expected tomorrow morning.";
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
      activeCruiseCanonicalHero = {};
      if (activeCruiseAccessValid AND activeCruiseUserId GT 0 AND activeCruiseContext.floatPlanId GT 0) {
        try {
          activeCruiseCanonicalHero = createObject("component", "fpw.api.v1.voyage").getActiveCruiseHeroCanonical(activeCruiseUserId, activeCruiseContext.floatPlanId);
        } catch (any activeCruiseCanonicalErr) {
          activeCruiseCanonicalHero = {};
        }
      }
      if (isStruct(activeCruiseCanonicalHero) AND structKeyExists(activeCruiseCanonicalHero, "SUCCESS") AND activeCruiseCanonicalHero.SUCCESS AND len(trim(toString(activeCruiseCanonicalHero.heroVoyageStatus)))) {
        activeCruiseView.heroVoyageStatus = trim(toString(activeCruiseCanonicalHero.heroVoyageStatus));
        if (structKeyExists(activeCruiseCanonicalHero, "heroVoyageStatusVariant") AND len(trim(toString(activeCruiseCanonicalHero.heroVoyageStatusVariant)))) {
          activeCruiseView.heroVoyageStatusVariant = trim(toString(activeCruiseCanonicalHero.heroVoyageStatusVariant));
        }
      } else {
        activeCruiseView.heroVoyageStatus = "Status Unavailable";
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

	      activeCruiseView.heroNextStop = (
	        isStruct(activeCruiseCanonicalHero) AND structKeyExists(activeCruiseCanonicalHero, "SUCCESS") AND activeCruiseCanonicalHero.SUCCESS AND len(trim(toString(activeCruiseCanonicalHero.heroNextStop)))
	          ? trim(toString(activeCruiseCanonicalHero.heroNextStop))
	          : nextStop
	      );
	      activeCruiseView.heroNextStopMeta = (len(activeCruiseView.heroNextStop) AND activeCruiseView.heroNextStop NEQ "n/a" ? "Upcoming planned stop" : "");

      if (len(etaLabel)) {
        activeCruiseView.legArrival = etaLabel;
      }
      if (isStruct(activeCruiseCanonicalHero) AND structKeyExists(activeCruiseCanonicalHero, "SUCCESS") AND activeCruiseCanonicalHero.SUCCESS AND len(trim(toString(activeCruiseCanonicalHero.heroEta))) AND trim(toString(activeCruiseCanonicalHero.heroEta)) NEQ "--") {
        activeCruiseView.heroEta = trim(toString(activeCruiseCanonicalHero.heroEta));
        activeCruiseView.heroEtaMeta = (activeCruiseTripStarted ? "Active leg ETA" : "Scheduled arrival from departure time");
      } else {
        activeCruiseView.heroEta = "--";
        activeCruiseView.heroEtaMeta = (activeCruiseTripStarted ? "Active leg ETA unavailable" : "Scheduled arrival unavailable");
      }

      if (activeCruiseTripStarted AND isStruct(activeCruiseCanonicalHero) AND structKeyExists(activeCruiseCanonicalHero, "SUCCESS") AND activeCruiseCanonicalHero.SUCCESS AND len(trim(toString(activeCruiseCanonicalHero.heroLastCheckIn))) AND trim(toString(activeCruiseCanonicalHero.heroLastCheckIn)) NEQ "--") {
        activeCruiseView.heroLastCheckIn = trim(toString(activeCruiseCanonicalHero.heroLastCheckIn));
        activeCruiseView.floatPlanLastCheckIn = activeCruiseView.heroLastCheckIn;
      } else {
        activeCruiseView.heroLastCheckIn = "--";
        if (activeCruiseHasOperationalCheckIn AND isDate(lastCheckInDt)) {
          activeCruiseView.floatPlanLastCheckIn = fpwFormatClock(lastCheckInDt, "--");
        } else {
          activeCruiseView.floatPlanLastCheckIn = "--";
        }
      }
      activeCruiseView.heroNextExpectedCheckIn = elapsedCheckInLabel;
      activeCruiseView.heroTripStart = "Trip Start: " & (isDate(canonicalTripStartDt) ? dateTimeFormat(canonicalTripStartDt, "mmm d, yyyy h:nn tt") : "--");
      activeCruiseView.floatPlanNextExpected = elapsedCheckInLabel;
      activeCruiseView.monitorNextExpectedCheckIn = (isDate(expectedCheckInDt) ? dateTimeFormat(expectedCheckInDt, "mmm d, yyyy h:nn tt") : "--");
      activeCruiseView.monitorDailyStartLabel = fpwFormatLocalTimeLabel(dailyStartLocalTimeVal, "8:00 AM");
      activeCruiseView.monitorDailyStartInput = fpwFormatLocalTimeInput(dailyStartLocalTimeVal, "08:00");
      if (isStruct(routeInputs) AND structCount(routeInputs) AND structKeyExists(routeInputs, "weather_factor_pct") AND !isNull(routeInputs.weather_factor_pct)) {
        routeWeatherFactorRaw = trim(toString(routeInputs.weather_factor_pct));
        if (len(routeWeatherFactorRaw)) {
          activeCruiseView.monitorWeatherFactor = numberFormat(val(routeWeatherFactorRaw), "0") & "%";
        }
      }

      activeCruiseView.legRemainingDistance = fpwFormatNm(remainingNm) & " remaining";
      activeCruiseView.legPercentComplete = fpwFormatPct(tripProgressPercentComplete) & " complete";
      activeCruiseView.progressBarWidth = fpwFormatPct(tripProgressPercentComplete);

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
      if (awaitingDepartureStop) {
        activeCruiseView.heroCurrentLegSummary = "Awaiting Departure";
        activeCruiseView.heroLegMeta = "Arrived at current stop. Next leg has not started.";
        activeCruiseView.heroNextStopMeta = (len(activeCruiseView.heroNextStop) AND activeCruiseView.heroNextStop NEQ "n/a" ? "Next planned stop after departure" : "Awaiting departure");
        activeCruiseView.heroEta = "--";
        activeCruiseView.heroEtaMeta = "ETA available after departure";
        activeCruiseView.legArrival = "--";
        activeCruiseView.routeStop2Detail = "Awaiting departure for this leg.";
        activeCruiseView.routeStop2Stamp = "Pending";
        if (len(currentLegStartName)) {
          activeCruiseView.routeStop3Title = "Current Stop: " & currentLegStartName;
          activeCruiseView.routeStop3Detail = "Arrived at the current destination. Awaiting departure.";
          activeCruiseView.routeStop3Stamp = "Stopped";
        }
        activeCruiseRouteStop1DotClass = "dot done";
        activeCruiseRouteStop2DotClass = "dot future";
        activeCruiseRouteStop3DotClass = "dot current";
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

      routeInputCardSpeedKn = fpwGetNumericFromKeys(
        routeInputs,
        [
          "weather_adjusted_speed_kn",
          "weatherAdjustedSpeedKn",
          "effective_speed_kn",
          "effectiveSpeedKn",
          "effective_cruising_speed",
          "effectiveCruisingSpeed"
        ],
        true
      );
      if (routeInputCardSpeedKn GT 0) {
        activeCruiseView.legPace = "Pace: " & numberFormat(routeInputCardSpeedKn, "0.0") & " kt";
        activeCruiseView.legDataPace = numberFormat(routeInputCardSpeedKn, "0.0") & " kt";
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

      experimentalDisplaySpeedKn = fpwRoundTo2(
        routeInputCardSpeedKn GT 0 ? routeInputCardSpeedKn : routeInputSpeedKn
      );
      experimentalDisplayFuelBurnGph = 0;
      experimentalDisplayReservePct = fpwRoundTo2(routeInputReservePct);

      canonicalFuelEstimateResult = {};
      canonicalFuelEstimate = {};
      if (currentLegRemainingNm GT 0 AND isStruct(routeInputs) AND structCount(routeInputs)) {
        canonicalFuelEstimateResult = fpwGetCanonicalFuelEstimate(routeInputs, currentLegRemainingNm, 0);
      }
      if (
        isStruct(canonicalFuelEstimateResult)
        AND structKeyExists(canonicalFuelEstimateResult, "SUCCESS")
        AND canonicalFuelEstimateResult.SUCCESS
        AND structKeyExists(canonicalFuelEstimateResult, "FUEL_ESTIMATE")
        AND isStruct(canonicalFuelEstimateResult.FUEL_ESTIMATE)
      ) {
        canonicalFuelEstimate = canonicalFuelEstimateResult.FUEL_ESTIMATE;
        reserveFuelNeedGal = fpwRoundTo2(
          structKeyExists(canonicalFuelEstimate, "reserveGallons")
            ? canonicalFuelEstimate.reserveGallons
            : 0
        );
        requiredFuelNeedGal = fpwRoundTo2(
          structKeyExists(canonicalFuelEstimate, "requiredFuelGallons")
            ? canonicalFuelEstimate.requiredFuelGallons
            : 0
        );
        activeCruiseView.legFuelNeed = numberFormat(requiredFuelNeedGal, "0.0") & " gal";
        activeCruiseView.legReserveFuel = numberFormat(reserveFuelNeedGal, "0.0") & " gal";
        activeCruiseView.legRemainingFuel = "Fuel est: " & numberFormat(requiredFuelNeedGal, "0.0") & " gal remaining";
        fuelCalcReady = true;
        if (structKeyExists(canonicalFuelEstimate, "weatherAdjustedSpeedKnots")) {
          experimentalDisplaySpeedKn = fpwRoundTo2(canonicalFuelEstimate.weatherAdjustedSpeedKnots);
        }
        if (structKeyExists(canonicalFuelEstimate, "weatherAdjustedBurnGph")) {
          experimentalDisplayFuelBurnGph = fpwRoundTo2(canonicalFuelEstimate.weatherAdjustedBurnGph);
        }
        if (structKeyExists(canonicalFuelEstimateResult, "RESERVE_PCT")) {
          experimentalDisplayReservePct = fpwRoundTo2(canonicalFuelEstimateResult.RESERVE_PCT);
        }
      }
      if (NOT fuelCalcReady) {
        activeCruiseView.legFuelNeed = "-- gal";
        activeCruiseView.legReserveFuel = "-- gal";
        activeCruiseView.legRemainingFuel = "Fuel est unavailable";
      }

      experimentalDepartureTimeZone = trim(toString(fpwQueryCell(qPlan, "departureTZ", 1, "")));
      experimentalRenderDt = now();
      experimentalReferenceDt = experimentalRenderDt;
      experimentalStartDt = "";
      experimentalPauseStartDt = "";
      experimentalPauseResumeDt = "";
      experimentalElapsedHours = 0;
      experimentalDistanceTraveledNm = 0;
      experimentalRemainingNm = 0;
      experimentalPercentComplete = 0;
      experimentalFuelBaseGal = 0;
      experimentalFuelReserveGal = 0;
      experimentalFuelRequiredGal = 0;
      experimentalPauseActive = false;
      experimentalStatusLabel = "Beta current-leg model unavailable";
      experimentalAssumptionLabel = "Assumes a " & fpwFormatLocalTimeLabel(dailyStartLocalTimeVal, "8:00 AM") & " departure-timezone leg start for display only.";

      activeCruiseExperimental.departureTimeZone = experimentalDepartureTimeZone;
      activeCruiseExperimental.generatedAtUtc = fpwFormatUtcIso(experimentalRenderDt);
      activeCruiseExperimental.currentLegDistanceNm = fpwRoundTo2(currentLegDistNm);
      activeCruiseExperimental.speedKn = fpwRoundTo2(experimentalDisplaySpeedKn);
      activeCruiseExperimental.fuelBurnGph = fpwRoundTo2(experimentalDisplayFuelBurnGph);
      activeCruiseExperimental.reservePct = fpwRoundTo2(experimentalDisplayReservePct);
      activeCruiseExperimental.isOvernight = isOvernightCheckIn;

	      if (!len(experimentalDepartureTimeZone)) {
	        experimentalStatusLabel = "Waiting on departure timezone";
	      } else if (currentLegDistNm LTE 0) {
	        experimentalStatusLabel = "Waiting on current leg distance";
	      } else if (experimentalDisplaySpeedKn LTE 0) {
	        experimentalStatusLabel = "Waiting on route-input speed";
	      } else {
	        if (isDate(currentLegStartedAt)) {
	          experimentalStartDt = currentLegStartedAt;
	        } else if (isDate(priorLegCompletedAt)) {
	          experimentalStartDt = priorLegCompletedAt;
	        } else {
	          if (isOvernightCheckIn AND isDate(lastCheckInDt)) {
	            experimentalReferenceDt = lastCheckInDt;
	          }
	          experimentalStartDt = fpwBuildTripLocalTime(experimentalReferenceDt, experimentalDepartureTimeZone, dailyStartHourVal, dailyStartMinuteVal, dailyStartSecondVal, false);
	        }
	        if (isOvernightCheckIn AND isDate(lastCheckInDt)) {
	          experimentalPauseStartDt = lastCheckInDt;
	          if (isDate(expectedCheckInDt)) {
	            experimentalPauseResumeDt = expectedCheckInDt;
	          } else {
	            experimentalPauseResumeDt = fpwBuildTripLocalTime(lastCheckInDt, experimentalDepartureTimeZone, dailyStartHourVal, dailyStartMinuteVal, dailyStartSecondVal, true);
	          }
	        }
        if (isDate(experimentalStartDt)) {
          experimentalElapsedHours = fpwComputeExperimentalElapsedHours(
            experimentalRenderDt,
            experimentalStartDt,
            experimentalPauseStartDt,
            experimentalPauseResumeDt
          );
          experimentalDistanceTraveledNm = fpwRoundTo2(experimentalElapsedHours * experimentalDisplaySpeedKn);
          if (experimentalDistanceTraveledNm GT currentLegDistNm) {
            experimentalDistanceTraveledNm = fpwRoundTo2(currentLegDistNm);
          }
          if (experimentalDistanceTraveledNm LT 0) {
            experimentalDistanceTraveledNm = 0;
          }
          experimentalRemainingNm = fpwRoundTo2(currentLegDistNm - experimentalDistanceTraveledNm);
          if (experimentalRemainingNm LT 0) {
            experimentalRemainingNm = 0;
          }
          if (currentLegDistNm GT 0) {
            experimentalPercentComplete = int((experimentalDistanceTraveledNm / currentLegDistNm) * 100);
          }
          if (experimentalPercentComplete LT 0) {
            experimentalPercentComplete = 0;
          }
          if (experimentalPercentComplete GT 100) {
            experimentalPercentComplete = 100;
          }

          experimentalPauseActive = (
            isDate(experimentalPauseStartDt)
            AND (
              NOT isDate(experimentalPauseResumeDt)
              OR dateCompare(experimentalRenderDt, experimentalPauseResumeDt, "s") LT 0
            )
          );
          if (experimentalPauseActive) {
            experimentalStatusLabel = "Paused overnight";
          } else if (isDate(experimentalPauseStartDt) AND isDate(experimentalPauseResumeDt)) {
            experimentalStatusLabel = "Resumed after overnight pause";
          } else {
            experimentalStatusLabel = "Browser-time display";
          }
          experimentalAssumptionLabel = "Assumes a " & fpwFormatLocalTimeLabel(dailyStartLocalTimeVal, "8:00 AM") & " start in " & experimentalDepartureTimeZone & " for display only.";

          activeCruiseView.experimentalLegStatus = experimentalStatusLabel;
          activeCruiseView.experimentalLegRemainingDistance = fpwFormatNm(experimentalRemainingNm) & " exp remaining";
          activeCruiseView.experimentalLegPercentComplete = fpwFormatPct(experimentalPercentComplete) & " exp complete";
          activeCruiseView.experimentalLegPace = "Exp pace: " & numberFormat(experimentalDisplaySpeedKn, "0.0") & " kt";
          activeCruiseView.experimentalProgressBarWidth = fpwFormatPct(experimentalPercentComplete);
          if (experimentalDisplayFuelBurnGph GT 0 AND experimentalDisplaySpeedKn GT 0 AND experimentalRemainingNm GT 0) {
            experimentalFuelBaseGal = fpwRoundTo2((experimentalRemainingNm / experimentalDisplaySpeedKn) * experimentalDisplayFuelBurnGph);
            if (experimentalDisplayReservePct GT 0) {
              experimentalFuelReserveGal = fpwRoundTo2(experimentalFuelBaseGal * (experimentalDisplayReservePct / 100));
            }
            experimentalFuelRequiredGal = fpwRoundTo2(experimentalFuelBaseGal + experimentalFuelReserveGal);
            activeCruiseView.experimentalLegRemainingFuel = "Exp fuel: " & numberFormat(experimentalFuelRequiredGal, "0.0") & " gal";
          } else {
            activeCruiseView.experimentalLegRemainingFuel = "Exp fuel unavailable";
          }
          activeCruiseView.experimentalLegMeta = experimentalAssumptionLabel;
          if (experimentalPauseActive AND isDate(experimentalPauseResumeDt)) {
            activeCruiseView.experimentalLegMeta &= " Paused until " & fpwFormatClock(experimentalPauseResumeDt, "8:00 AM") & ".";
          } else if (isDate(experimentalPauseStartDt) AND isDate(experimentalPauseResumeDt)) {
            activeCruiseView.experimentalLegMeta &= " Overnight pause excluded until " & fpwFormatClock(experimentalPauseResumeDt, "8:00 AM") & ".";
          }

          activeCruiseExperimental.available = true;
          activeCruiseExperimental.baseStartUtc = fpwFormatUtcIso(experimentalStartDt);
          activeCruiseExperimental.pauseStartUtc = fpwFormatUtcIso(experimentalPauseStartDt);
          activeCruiseExperimental.pauseResumeUtc = fpwFormatUtcIso(experimentalPauseResumeDt);
          activeCruiseExperimental.assumptionLabel = activeCruiseView.experimentalLegMeta;
          activeCruiseExperimental.statusLabel = experimentalStatusLabel;
        } else {
          experimentalStatusLabel = "Unable to build 8:00 AM leg basis";
        }
      }

      if (NOT activeCruiseExperimental.available) {
        activeCruiseView.experimentalLegStatus = experimentalStatusLabel;
        activeCruiseView.experimentalLegMeta = experimentalAssumptionLabel;
        activeCruiseExperimental.statusLabel = experimentalStatusLabel;
        activeCruiseExperimental.assumptionLabel = experimentalAssumptionLabel;
      }
      if (awaitingDepartureStop) {
        activeCruiseView.experimentalLegStatus = "Awaiting departure";
        activeCruiseView.experimentalLegRemainingDistance = "—";
        activeCruiseView.experimentalLegPercentComplete = "—";
        activeCruiseView.experimentalLegPace = "Exp pace: —";
        activeCruiseView.experimentalLegRemainingFuel = "Exp fuel unavailable";
        activeCruiseView.experimentalLegMeta = "The next leg begins once departure is confirmed.";
        activeCruiseView.experimentalProgressBarWidth = "0%";
        activeCruiseExperimental.available = false;
        activeCruiseExperimental.baseStartUtc = "";
        activeCruiseExperimental.pauseStartUtc = "";
        activeCruiseExperimental.pauseResumeUtc = "";
        activeCruiseExperimental.statusLabel = activeCruiseView.experimentalLegStatus;
        activeCruiseExperimental.assumptionLabel = activeCruiseView.experimentalLegMeta;
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

      if (!activeCruiseTripStarted) {
        activeCruiseEyebrowLabel = "Voyage Console • Scheduled Start";
        activeCruiseHeroSubline = "This trip is scheduled and has not started yet. Use this page to confirm the planned departure, first-leg ETA, float plan status, and monitoring state before getting underway.";
        activeCruiseProgressWindowLabel = "Scheduled";
        activeCruiseLegRouteWindowLabel = "Scheduled";
        activeCruiseCurrentLegCopy = "This area shows the planned departure point, first leg, scheduled ETA, and monitoring state before the trip begins.";
        activeCruiseFloatPlanBadgeLabel = "Monitoring Scheduled";
        activeCruiseFloatPlanStatusNote = "Monitoring begins at scheduled departure";
        activeCruiseFloatPlanNextExpectedNote = "Scheduled departure pending";
        activeCruiseRouteStop1DotClass = "dot current";
        activeCruiseRouteStop2DotClass = "dot future";
        activeCruiseRouteStop3DotClass = "dot future";
        activeCruiseView.heroLegMeta = "Scheduled departure pending";
        activeCruiseView.heroNextStopMeta = (len(activeCruiseView.heroNextStop) AND activeCruiseView.heroNextStop NEQ "n/a" ? "First planned stop after departure" : "");
        activeCruiseView.heroLastCheckIn = "--";
        activeCruiseView.floatPlanLastCheckIn = "--";
        activeCruiseView.routeStop1Detail = "Scheduled departure point.";
        activeCruiseView.routeStop1Stamp = "Scheduled";
        activeCruiseView.routeStop2Detail = "First leg begins at scheduled departure.";
        activeCruiseView.routeStop2Stamp = "Leg 1";
        activeCruiseView.routeStop3Detail = "First planned destination after departure.";
        activeCruiseView.routeStop3Stamp = "Planned";
        activeCruiseView.monitorStatus = "Scheduled";
        activeCruiseView.monitorStatusColor = "var(--muted)";
        activeCruiseView.monitorFollowerState = "Pending Start";
        activeCruiseView.experimentalLegStatus = "Scheduled departure pending";
        activeCruiseView.experimentalLegRemainingDistance = "—";
        activeCruiseView.experimentalLegPercentComplete = "—";
        activeCruiseView.experimentalLegPace = "Exp pace: —";
        activeCruiseView.experimentalLegRemainingFuel = "Exp fuel unavailable";
        activeCruiseView.experimentalLegMeta = "The trip has not started yet. Operational timing begins at scheduled departure.";
        activeCruiseView.experimentalProgressBarWidth = "0%";
        if (len(activeCruiseView.heroEta) AND activeCruiseView.heroEta NEQ "--") {
          activeCruiseView.legArrival = activeCruiseView.heroEta;
        }
        activeCruiseExperimental.available = false;
        activeCruiseExperimental.baseStartUtc = "";
        activeCruiseExperimental.pauseStartUtc = "";
        activeCruiseExperimental.pauseResumeUtc = "";
        activeCruiseExperimental.assumptionLabel = activeCruiseView.experimentalLegMeta;
        activeCruiseExperimental.statusLabel = activeCruiseView.experimentalLegStatus;
        activeCruiseTimelineItems = [
          {
            time = (isDate(canonicalTripStartDt) ? fpwFormatClock(canonicalTripStartDt, "--") : "--"),
            title = "Scheduled departure",
            detail = "Trip start and monitoring begin at the scheduled departure time."
          }
        ];
        if (len(activeCruiseView.heroEta) AND activeCruiseView.heroEta NEQ "--") {
          arrayAppend(activeCruiseTimelineItems, {
            time = activeCruiseView.heroEta,
            title = "Planned first-leg arrival",
            detail = "Based on scheduled departure time plus planned leg duration."
          });
        }
      }

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
  activeCruiseHooks.context.awaitingDepartureStop = awaitingDepartureStop;
  activeCruiseHooks.context.pendingLegOrder = pendingLegOrder;
  activeCruiseHooks.experimentalLeg = activeCruiseExperimental;
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
    heroEtaUtc = (
      isStruct(activeCruiseCanonicalHero)
      AND structKeyExists(activeCruiseCanonicalHero, "SUCCESS")
      AND activeCruiseCanonicalHero.SUCCESS
      AND structKeyExists(activeCruiseCanonicalHero, "heroEtaUtc")
        ? trim(toString(activeCruiseCanonicalHero.heroEtaUtc))
        : ""
    ),
    heroTripStartUtc = (
      isStruct(activeCruiseCanonicalHero)
      AND structKeyExists(activeCruiseCanonicalHero, "SUCCESS")
      AND activeCruiseCanonicalHero.SUCCESS
      AND structKeyExists(activeCruiseCanonicalHero, "heroTripStartUtc")
        ? trim(toString(activeCruiseCanonicalHero.heroTripStartUtc))
        : ""
    ),
    heroLastCheckIn = activeCruiseView.heroLastCheckIn,
    heroLastCheckInUtc = (
      isStruct(activeCruiseCanonicalHero)
      AND structKeyExists(activeCruiseCanonicalHero, "SUCCESS")
      AND activeCruiseCanonicalHero.SUCCESS
      AND structKeyExists(activeCruiseCanonicalHero, "heroLastCheckInUtc")
        ? trim(toString(activeCruiseCanonicalHero.heroLastCheckInUtc))
        : ""
    ),
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
    legArrivalUtc = (
      isStruct(activeCruiseCanonicalHero)
      AND structKeyExists(activeCruiseCanonicalHero, "SUCCESS")
      AND activeCruiseCanonicalHero.SUCCESS
      AND structKeyExists(activeCruiseCanonicalHero, "legArrivalUtc")
        ? trim(toString(activeCruiseCanonicalHero.legArrivalUtc))
        : ""
    ),
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
  if (
    !activeCruiseTripStarted
    AND structKeyExists(activeCruiseHooks.fields, "heroEtaUtc")
    AND len(trim(toString(activeCruiseHooks.fields.heroEtaUtc)))
  ) {
    activeCruiseHooks.fields.legArrivalUtc = trim(toString(activeCruiseHooks.fields.heroEtaUtc));
  }
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

    .checkin-modal {
      position: fixed;
      inset: 0;
      display: none;
      align-items: center;
      justify-content: center;
      padding: 20px;
      background: rgba(3, 10, 16, 0.78);
      z-index: 120;
    }

    .checkin-modal.is-open {
      display: flex;
    }

    .checkin-modal__dialog {
      width: min(100%, 560px);
      background: var(--panel-2);
      border: 1px solid var(--line-strong);
      border-radius: var(--radius-lg);
      box-shadow: var(--shadow);
      padding: 22px;
    }

    .checkin-modal__head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      margin-bottom: 18px;
    }

    .checkin-modal__title {
      margin: 0;
      font-size: 1.2rem;
      font-weight: 800;
      letter-spacing: 0.02em;
    }

    .checkin-modal__close {
      appearance: none;
      border: 0;
      background: transparent;
      color: var(--muted);
      cursor: pointer;
      font-size: 1.5rem;
      line-height: 1;
      padding: 0;
    }

    .checkin-modal__section {
      display: grid;
      gap: 12px;
    }

    .checkin-modal__label {
      font-size: 0.82rem;
      font-weight: 800;
      letter-spacing: 0.14em;
      text-transform: uppercase;
      color: var(--muted);
    }

    .checkin-modal__status-grid {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
    }

    .checkin-modal__status {
      appearance: none;
      border: 1px solid rgba(126,184,226,0.18);
      background: rgba(126,184,226,0.07);
      color: var(--text);
      border-radius: 999px;
      cursor: pointer;
      font-size: 0.92rem;
      font-weight: 700;
      padding: 11px 16px;
      transition: 0.18s ease;
    }

    .checkin-modal__status.is-selected {
      color: #041019;
      background: linear-gradient(135deg, var(--accent-2), var(--accent));
      border-color: transparent;
      box-shadow: 0 16px 32px rgba(67,199,255,0.18);
    }

    .checkin-modal__note-toggle {
      appearance: none;
      border: 0;
      background: transparent;
      color: var(--accent-2);
      cursor: pointer;
      font-size: 0.95rem;
      font-weight: 700;
      padding: 0;
      text-align: left;
    }

    .checkin-modal__option {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-top: 18px;
      color: var(--text);
      font-size: 0.95rem;
      font-weight: 700;
    }

    .checkin-modal__option input {
      width: 18px;
      height: 18px;
      accent-color: var(--accent-2);
      margin: 0;
    }

    .checkin-modal__note {
      display: none;
      margin-top: 18px;
    }

    .checkin-modal__note.is-open {
      display: grid;
      gap: 10px;
    }

    .checkin-modal__textarea {
      width: 100%;
      min-height: 116px;
      resize: vertical;
      border-radius: var(--radius-md);
      border: 1px solid rgba(126,184,226,0.18);
      background: rgba(126,184,226,0.06);
      color: var(--text);
      font: inherit;
      line-height: 1.5;
      padding: 14px 16px;
    }

    .checkin-modal__textarea::placeholder {
      color: var(--soft);
    }

    .checkin-modal__actions {
      display: flex;
      justify-content: flex-end;
      margin-top: 22px;
    }

    .main {
      padding: 22px 0 34px;
    }

    .hero {
      display: grid;
      grid-template-columns: 1.2fr 0.8fr;
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

    .status-pill.status-pill--warning {
      background: rgba(255,198,97,0.08);
      border-color: rgba(255,198,97,0.18);
    }

    .status-pill.status-pill--warning b,
    .status-pill.status-pill--warning strong {
      color: var(--warn);
    }

    .status-pill.status-pill--danger {
      background: rgba(255,127,127,0.08);
      border-color: rgba(255,127,127,0.18);
    }

    .status-pill.status-pill--danger b,
    .status-pill.status-pill--danger strong {
      color: var(--alert);
    }

    .header-stats {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 14px;
      margin-top: 18px;
      margin-bottom: 18px;
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
      align-self: start;
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

    .hero > .stack:last-child {
      align-self: start;
    }

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
        <cfif activeCruiseAccessValid>
          <div class="chip" data-fpw-field="top.routeName"><cfoutput>#encodeForHtml(activeCruiseView.topRouteChip)#</cfoutput></div>
          <div class="chip" data-fpw-field="top.floatPlanState"><cfoutput>#encodeForHtml(activeCruiseView.topFloatPlanState)#</cfoutput></div>
          <button class="btn btn-secondary">View Follower Page</button>
          <cfif activeCruiseCanStartNextLeg>
            <button class="btn btn-secondary" id="fpwStartNextLegBtn">Start Next Leg</button>
          </cfif>
          <cfif activeCruiseCanCompleteLeg>
            <button class="btn btn-secondary" id="fpwCompleteLegBtn">Arrived / Complete Leg</button>
          </cfif>
          <button class="btn btn-primary" id="fpwCheckInBtn">Check In Now</button>
        <cfelse>
          <div class="chip">No active trip</div>
        </cfif>
      </div>
    </div>
  </header>

  <main class="main">
    <div class="shell">
      <cfif activeCruiseAccessValid>
	      <section class="hero">
	        <div class="stack">
	          <div class="panel hero-main">
          <div class="eyebrow"><cfoutput>#encodeForHtml(activeCruiseEyebrowLabel)#</cfoutput></div>
          <div class="title-row">
            <div>
              <h1 data-fpw-field="hero.routeTitle"><cfoutput>#encodeForHtml(activeCruiseView.heroRouteTitle)#</cfoutput></h1>
              <div class="subline"><cfoutput>#encodeForHtml(activeCruiseHeroSubline)#</cfoutput></div>
            </div>
            <div class="status-pill<cfoutput><cfif len(trim(activeCruiseView.heroVoyageStatusVariant))> status-pill--#encodeForHtmlAttribute(activeCruiseView.heroVoyageStatusVariant)#</cfif></cfoutput>">
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
	          </div>

	          <div class="mini-panel">
	            <div class="mini-head">
	              <h3>Completed Legs</h3>
	              <span><cfoutput>#encodeForHtml(activeCruiseProgressWindowLabel)#</cfoutput></span>
	            </div>
	            <div class="progress-block">
	              <div class="bar-shell"><div class="bar-fill" style="width:<cfoutput>#encodeForHtmlAttribute(activeCruiseView.progressBarWidth)#</cfoutput>;"></div></div>
	              <div class="split"><span data-fpw-field="leg.remainingDistance"><cfoutput>#encodeForHtml(activeCruiseView.legRemainingDistance)#</cfoutput></span><span data-fpw-field="leg.percentComplete"><cfoutput>#encodeForHtml(activeCruiseView.legPercentComplete)#</cfoutput></span></div>
	              <div class="split"><span data-fpw-field="leg.pace"><cfoutput>#encodeForHtml(activeCruiseView.legPace)#</cfoutput></span><span data-fpw-field="leg.remainingFuel"><cfoutput>#encodeForHtml(activeCruiseView.legRemainingFuel)#</cfoutput></span></div>
	              <div class="progress-block" style="margin-top:12px;padding-top:12px;border-top:1px solid rgba(126,184,226,0.14);">
	                <div class="split"><span>Current Leg (Beta)</span><span id="fpwExperimentalLegStatus"><cfoutput>#encodeForHtml(activeCruiseView.experimentalLegStatus)#</cfoutput></span></div>
	                <div class="bar-shell" style="margin-top:10px;"><div class="bar-fill" id="fpwExperimentalLegBar" style="width:<cfoutput>#encodeForHtmlAttribute(activeCruiseView.experimentalProgressBarWidth)#</cfoutput>;"></div></div>
	                <div class="split" style="margin-top:10px;"><span id="fpwExperimentalLegRemaining"><cfoutput>#encodeForHtml(activeCruiseView.experimentalLegRemainingDistance)#</cfoutput></span><span id="fpwExperimentalLegPercent"><cfoutput>#encodeForHtml(activeCruiseView.experimentalLegPercentComplete)#</cfoutput></span></div>
	                <div class="split" style="margin-top:10px;"><span id="fpwExperimentalLegPace"><cfoutput>#encodeForHtml(activeCruiseView.experimentalLegPace)#</cfoutput></span><span id="fpwExperimentalLegFuel"><cfoutput>#encodeForHtml(activeCruiseView.experimentalLegRemainingFuel)#</cfoutput></span></div>
	                <div id="fpwExperimentalLegMeta" style="margin-top:8px;color:var(--muted);font-size:0.86rem;"><cfoutput>#encodeForHtml(activeCruiseView.experimentalLegMeta)#</cfoutput></div>
		              </div>
		            </div>
			          </div>
		          </div>
	          <div class="panel section-card">
	            <div class="section-top">
	              <div>
                <h2>Current Leg Overview</h2>
              </div>
              <div class="badge badge-accent">Captain View</div>
            </div>

            <div class="leg-grid">
              <div class="route-box">
                <div class="mini-head" style="margin-bottom:16px;">
                  <h3>Leg Route</h3>
                  <span><cfoutput>#encodeForHtml(activeCruiseLegRouteWindowLabel)#</cfoutput></span>
                </div>
                <div class="route-path">
                  <div class="route-stop">
                    <div class="<cfoutput>#encodeForHtmlAttribute(activeCruiseRouteStop1DotClass)#</cfoutput>"></div>
                    <div>
                      <b data-fpw-field="leg.routeStop1Title"><cfoutput>#encodeForHtml(activeCruiseView.routeStop1Title)#</cfoutput></b>
                      <span data-fpw-field="leg.routeStop1Detail"><cfoutput>#encodeForHtml(activeCruiseView.routeStop1Detail)#</cfoutput></span>
                    </div>
                    <small data-fpw-field="leg.routeStop1Stamp"><cfoutput>#encodeForHtml(activeCruiseView.routeStop1Stamp)#</cfoutput></small>
                  </div>
                  <div class="route-stop">
                    <div class="<cfoutput>#encodeForHtmlAttribute(activeCruiseRouteStop2DotClass)#</cfoutput>"></div>
                    <div>
                      <b data-fpw-field="leg.routeStop2Title"><cfoutput>#encodeForHtml(activeCruiseView.routeStop2Title)#</cfoutput></b>
                      <span data-fpw-field="leg.routeStop2Detail"><cfoutput>#encodeForHtml(activeCruiseView.routeStop2Detail)#</cfoutput></span>
                    </div>
                    <small data-fpw-field="leg.routeStop2Stamp"><cfoutput>#encodeForHtml(activeCruiseView.routeStop2Stamp)#</cfoutput></small>
                  </div>
                  <div class="route-stop">
                    <div class="<cfoutput>#encodeForHtmlAttribute(activeCruiseRouteStop3DotClass)#</cfoutput>"></div>
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
                  <h3>Current Leg Data</h3>
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
                    <small>Approximate to next stop</small>
                  </div>
                  <div class="data-item">
                    <span>Pace</span>
                    <strong data-fpw-field="leg.dataPace"><cfoutput>#encodeForHtml(activeCruiseView.legDataPace)#</cfoutput></strong>
                    <small>Weather-adjusted</small>
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
	                  <cfoutput>
	                    <cfloop array="#activeCruiseTimelineItems#" index="timelineItem">
	                      <div class="timeline-row">
	                        <div class="timeline-time"<cfif structKeyExists(timelineItem, "timeUtc") AND len(trim(toString(timelineItem.timeUtc)))> data-time-utc="#encodeForHtmlAttribute(toString(timelineItem.timeUtc))#"</cfif>>#encodeForHtml(toString(timelineItem.time))#</div>
	                        <div class="timeline-node"></div>
	                        <div class="timeline-copy">
	                          <b>#encodeForHtml(toString(timelineItem.title))#</b>
	                          <cfif len(trim(toString(timelineItem.detail)))>
	                            <span>#encodeForHtml(toString(timelineItem.detail))#</span>
                          </cfif>
                        </div>
                      </div>
                    </cfloop>
                  </cfoutput>
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
                <h2>Monitoring Status</h2>
              </div>
              <div class="badge badge-good"><cfoutput>#encodeForHtml(activeCruiseFloatPlanBadgeLabel)#</cfoutput></div>
            </div>
            <div class="floatplan-box">
              <div class="data-grid">
                <div class="data-item">
                  <span>Last Check-In</span>
                  <strong data-fpw-field="floatPlan.lastCheckIn"><cfoutput>#encodeForHtml(activeCruiseView.floatPlanLastCheckIn)#</cfoutput></strong>
                  <small>Captain confirmed status</small>
                </div>
                <div class="data-item">
                  <span>Since Check-In</span>
                  <strong data-fpw-field="floatPlan.nextExpected"><cfoutput>#encodeForHtml(activeCruiseView.floatPlanNextExpected)#</cfoutput></strong>
                  <small><cfoutput>#encodeForHtml(activeCruiseFloatPlanNextExpectedNote)#</cfoutput></small>
                </div>
                <div class="data-item">
                  <span>Next Expected Check-In</span>
                  <strong data-fpw-field="monitor.nextExpectedCheckIn"><cfoutput>#encodeForHtml(activeCruiseView.monitorNextExpectedCheckIn)#</cfoutput></strong>
                  <small>Canonical monitoring checkpoint</small>
                </div>
                <div class="data-item">
                  <span>Daily Start Time</span>
                  <strong data-fpw-field="monitor.dailyStartLabel"><cfoutput>#encodeForHtml(activeCruiseView.monitorDailyStartLabel)#</cfoutput></strong>
                  <small>Applied to overnight resume and next-day monitoring.</small>
                  <div style="margin-top:10px; display:flex; gap:8px; align-items:center;">
                    <input
                      type="time"
                      id="fpwMonitorDailyStartInput"
                      value="<cfoutput>#encodeForHtmlAttribute(activeCruiseView.monitorDailyStartInput)#</cfoutput>"
                      step="60"
                      style="min-width:128px; padding:8px 10px; border-radius:10px; border:1px solid rgba(126,184,226,0.18); background:rgba(8,18,28,0.82); color:var(--text);"
                    >
                    <button
                      type="button"
                      id="fpwMonitorDailyStartSaveBtn"
                      class="action-btn"
                      style="padding:8px 14px; min-height:auto;"
                    >Save</button>
                  </div>
                  <small id="fpwMonitorDailyStartNote">If you change this while secured for the night, the next resume/check-in time updates from the new local start.</small>
                </div>
              </div>
            </div>
          </div>

	          <aside class="panel hero-side">
	            <div class="mini-panel">
	              <div class="mini-head">
	                <h3>Float Plan Monitor</h3>
	                <span>Attached</span>
	              </div>
	              <div class="split"><span>Status</span><strong style="color:<cfoutput>#encodeForHtmlAttribute(activeCruiseView.monitorStatusColor)#</cfoutput>;" data-fpw-field="monitor.status"><cfoutput>#encodeForHtml(activeCruiseView.monitorStatus)#</cfoutput></strong></div>
	              <div class="split" style="margin-top:10px;"><span>Follower Page</span><strong style="color:var(--accent);" data-fpw-field="monitor.followerState"><cfoutput>#encodeForHtml(activeCruiseView.monitorFollowerState)#</cfoutput></strong></div>
	              <div class="split" style="margin-top:10px;"><span>Emergency Contact</span><strong data-fpw-field="monitor.emergencyContact"><cfoutput>#encodeForHtml(activeCruiseView.monitorEmergencyContact)#</cfoutput></strong></div>
	              <div style="margin-top:12px;">
	                <div class="split" style="align-items:center; gap:10px; flex-wrap:wrap;">
	                  <span>Weather Lookup</span>
	                  <div style="display:flex; gap:12px; flex-wrap:wrap; align-items:center;">
	                    <label style="display:inline-flex; align-items:center; gap:6px;"><input type="radio" name="fpwMonitorWeatherPoint" value="start"><cfoutput>#encodeForHtml(len(trim(currentLegStartName)) ? currentLegStartName : "Start")#</cfoutput></label>
	                    <label style="display:inline-flex; align-items:center; gap:6px;"><input type="radio" name="fpwMonitorWeatherPoint" value="end"><cfoutput>#encodeForHtml(len(trim(currentLegEndName)) ? currentLegEndName : "End")#</cfoutput></label>
	                  </div>
	                </div>
	                <div style="margin-top:10px; display:flex; justify-content:flex-end;">
	                  <button class="btn btn-secondary" type="button" id="fpwMonitorWeatherBtn">Check Conditions</button>
	                </div>
	                <div id="fpwMonitorWeatherMessage" style="margin-top:10px; color:var(--muted); font-size:0.9rem;" aria-live="polite"></div>
	                <div id="fpwMonitorWeatherResult" style="margin-top:10px;" hidden>
	                  <div class="split"><span>Point</span><strong id="fpwMonitorWeatherPointLabel">—</strong></div>
	                  <div class="split" style="margin-top:10px;"><span>Wind</span><strong id="fpwMonitorWeatherWind">—</strong></div>
	                  <div class="split" style="margin-top:10px;"><span>Gusts</span><strong id="fpwMonitorWeatherGusts">—</strong></div>
	                  <div class="split" style="margin-top:10px;"><span>Waves</span><strong id="fpwMonitorWeatherWaves">—</strong></div>
	                  <div class="split" style="margin-top:10px;"><span>Visibility</span><strong id="fpwMonitorWeatherVisibility">—</strong></div>
	                  <div class="split" style="margin-top:10px;"><span>Weather % Factor</span><strong id="fpwMonitorWeatherFactor" data-fpw-field="monitor.weatherFactor"><cfoutput>#encodeForHtml(activeCruiseView.monitorWeatherFactor)#</cfoutput></strong></div>
	                  <div style="margin-top:10px;">
	                    <div class="split"><span>Alerts</span><strong id="fpwMonitorWeatherAlertsSummary">No alerts</strong></div>
	                    <div id="fpwMonitorWeatherAlerts" style="margin-top:10px;"></div>
	                  </div>
	                  <div id="fpwMonitorWeatherApplyWrap" style="margin-top:12px; display:flex; justify-content:flex-end;" hidden>
	                    <button class="btn btn-secondary" type="button" id="fpwMonitorWeatherApplyBtn" disabled>Apply Weather to Route</button>
	                  </div>
	                </div>
	              </div>
	            </div>
	          </aside>

          <div class="panel section-card">
            <div class="section-top">
              <div>
                <h2>Attached Float Plan</h2>
              </div>
              <div class="badge badge-good"><cfoutput>#encodeForHtml(activeCruiseFloatPlanBadgeLabel)#</cfoutput></div>
            </div>
            <div class="floatplan-box">
              <div class="data-grid">
                <div class="data-item">
                  <span>Plan Status</span>
                  <strong data-fpw-field="floatPlan.status"><cfoutput>#encodeForHtml(activeCruiseView.floatPlanStatus)#</cfoutput></strong>
                  <small><cfoutput>#encodeForHtml(activeCruiseFloatPlanStatusNote)#</cfoutput></small>
                </div>
                <div class="data-item">
                  <span>Plan ID</span>
                  <strong data-fpw-field="floatPlan.id"><cfoutput>#encodeForHtml(activeCruiseView.floatPlanIdLabel)#</cfoutput></strong>
                  <small>Linked to this route instance</small>
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
      <cfelse>
      <section class="panel section-card">
        <div class="section-top">
          <div>
            <h2><cfoutput>#encodeForHtml(activeCruiseAccessTitle)#</cfoutput></h2>
            <p><cfoutput>#encodeForHtml(activeCruiseAccessMessage)#</cfoutput></p>
          </div>
          <div class="badge badge-warn">Active Cruise Unavailable</div>
        </div>
        <div class="floatplan-box">
          <p style="margin:0; color:var(--muted); line-height:1.6;"><cfoutput>#encodeForHtml(activeCruiseAccessDetail)#</cfoutput></p>
        </div>
      </section>
      </cfif>
    </div>
  </main>
  <cfif activeCruiseAccessValid>
  <div class="checkin-modal" id="fpwCheckInModal" aria-hidden="true">
    <div class="checkin-modal__dialog" role="dialog" aria-modal="true" aria-labelledby="fpwCheckInModalTitle">
      <div class="checkin-modal__head">
        <h2 class="checkin-modal__title" id="fpwCheckInModalTitle">Check In</h2>
        <button class="checkin-modal__close" type="button" id="fpwCheckInCloseBtn" aria-label="Close">&times;</button>
      </div>

      <div class="checkin-modal__section">
        <div class="checkin-modal__label">Status</div>
        <div class="checkin-modal__status-grid" id="fpwCheckInStatusGroup">
          <button class="checkin-modal__status is-selected" type="button" data-status="On Track" aria-pressed="true">On Track</button>
          <button class="checkin-modal__status" type="button" data-status="Delayed" aria-pressed="false">Delayed</button>
          <button class="checkin-modal__status" type="button" data-status="Changed Plan" aria-pressed="false">Changed Plan</button>
          <button class="checkin-modal__status" type="button" data-status="Assistance Needed" aria-pressed="false">Assistance Needed</button>
          <button class="checkin-modal__status" type="button" data-status="Secure for the Night" aria-pressed="false">Secure for the Night</button>
          <button class="checkin-modal__status" type="button" data-status="Arrived" aria-pressed="false">Arrived</button>
        </div>
      </div>

      <div class="checkin-modal__note-toggle-wrap" style="margin-top:18px;">
        <button class="checkin-modal__note-toggle" type="button" id="fpwCheckInNoteToggle">Add Note</button>
      </div>

      <div class="checkin-modal__note" id="fpwCheckInNoteWrap">
        <label class="checkin-modal__label" for="fpwCheckInNote">Add Note (optional)</label>
        <textarea class="checkin-modal__textarea" id="fpwCheckInNote" placeholder=""></textarea>
      </div>

      <div class="checkin-modal__actions">
        <button class="btn btn-primary" type="button" id="fpwCheckInSubmitBtn">Check In</button>
      </div>
    </div>
  </div>
  <script src="../assets/js/app/api.js?v=20260320a"></script>
  <script src="../assets/js/app/dashboard/routebuilder.js?v=20260414a"></script>
  <script id="fpw-active-cruise-hooks" type="application/json"><cfoutput>#activeCruiseHooksJson#</cfoutput></script>
  <script>
    (function (window, document) {
      "use strict";

      var hooksEl = document.getElementById("fpw-active-cruise-hooks");
      var startNextLegButton = document.getElementById("fpwStartNextLegBtn");
      var completeLegButton = document.getElementById("fpwCompleteLegBtn");
      var checkInButton = document.getElementById("fpwCheckInBtn");
      var modalEl = document.getElementById("fpwCheckInModal");
      var closeBtn = document.getElementById("fpwCheckInCloseBtn");
      var statusGroupEl = document.getElementById("fpwCheckInStatusGroup");
      var noteToggleBtn = document.getElementById("fpwCheckInNoteToggle");
      var noteWrapEl = document.getElementById("fpwCheckInNoteWrap");
      var noteInput = document.getElementById("fpwCheckInNote");
      var submitBtn = document.getElementById("fpwCheckInSubmitBtn");
      var selectedStatus = "On Track";
      var pageHooks = {};
      var pageContext = {};
      var experimentalLegModel = {};
      var floatPlanId = 0;
      var weatherButton = document.getElementById("fpwMonitorWeatherBtn");
      var weatherMessageEl = document.getElementById("fpwMonitorWeatherMessage");
      var weatherResultEl = document.getElementById("fpwMonitorWeatherResult");
      var weatherPointLabelEl = document.getElementById("fpwMonitorWeatherPointLabel");
      var weatherWindEl = document.getElementById("fpwMonitorWeatherWind");
      var weatherGustsEl = document.getElementById("fpwMonitorWeatherGusts");
      var weatherWavesEl = document.getElementById("fpwMonitorWeatherWaves");
      var weatherVisibilityEl = document.getElementById("fpwMonitorWeatherVisibility");
      var weatherFactorEl = document.getElementById("fpwMonitorWeatherFactor");
      var weatherAlertsSummaryEl = document.getElementById("fpwMonitorWeatherAlertsSummary");
      var weatherAlertsEl = document.getElementById("fpwMonitorWeatherAlerts");
      var weatherApplyWrapEl = document.getElementById("fpwMonitorWeatherApplyWrap");
      var weatherApplyButton = document.getElementById("fpwMonitorWeatherApplyBtn");
      var routeWeatherAssist = (window.FPW && window.FPW.RouteWeatherAssist) ? window.FPW.RouteWeatherAssist : null;
      var weatherLookupState = {
        point: "",
        data: null
      };
      var experimentalLegStatusEl = document.getElementById("fpwExperimentalLegStatus");
      var experimentalLegBarEl = document.getElementById("fpwExperimentalLegBar");
      var experimentalLegRemainingEl = document.getElementById("fpwExperimentalLegRemaining");
      var experimentalLegPercentEl = document.getElementById("fpwExperimentalLegPercent");
      var experimentalLegPaceEl = document.getElementById("fpwExperimentalLegPace");
      var experimentalLegFuelEl = document.getElementById("fpwExperimentalLegFuel");
      var experimentalLegMetaEl = document.getElementById("fpwExperimentalLegMeta");
      var heroEtaEl = document.querySelector('[data-fpw-field="hero.eta"]');
      var heroTripStartEl = document.querySelector('[data-fpw-field="hero.tripStart"]');
      var heroLastCheckInEl = document.querySelector('[data-fpw-field="hero.lastCheckIn"]');
      var floatPlanLastCheckInEl = document.querySelector('[data-fpw-field="floatPlan.lastCheckIn"]');
      var monitorDailyStartInputEl = document.getElementById("fpwMonitorDailyStartInput");
      var monitorDailyStartSaveBtn = document.getElementById("fpwMonitorDailyStartSaveBtn");
      var legArrivalEl = document.querySelector('[data-fpw-field="leg.arrival"]');
      var routeStop4StampEl = document.querySelector('[data-fpw-field="leg.routeStop4Stamp"]');

      if (!checkInButton || !modalEl || !closeBtn || !statusGroupEl || !noteToggleBtn || !noteWrapEl || !noteInput || !submitBtn) {
        return;
      }

      function normalizeExperimentalLegModel(rawModel) {
        var model = (rawModel && typeof rawModel === "object") ? rawModel : {};
        return {
          available: model.available === true || model.AVAILABLE === true,
          departureTimeZone: model.departureTimeZone || model.DEPARTURETIMEZONE || "",
          generatedAtUtc: model.generatedAtUtc || model.GENERATEDATUTC || "",
          baseStartUtc: model.baseStartUtc || model.BASESTARTUTC || "",
          pauseStartUtc: model.pauseStartUtc || model.PAUSESTARTUTC || "",
          pauseResumeUtc: model.pauseResumeUtc || model.PAUSERESUMEUTC || "",
          currentLegDistanceNm: model.currentLegDistanceNm || model.CURRENTLEGDISTANCENM || 0,
          speedKn: model.speedKn || model.SPEEDKN || 0,
          fuelBurnGph: model.fuelBurnGph || model.FUELBURNGPH || 0,
          reservePct: model.reservePct || model.RESERVEPCT || 0,
          isOvernight: model.isOvernight === true || model.ISOVERNIGHT === true,
          assumptionLabel: model.assumptionLabel || model.ASSUMPTIONLABEL || "",
          statusLabel: model.statusLabel || model.STATUSLABEL || ""
        };
      }

      function applyHookPayload(rawHooks) {
        pageHooks = (rawHooks && typeof rawHooks === "object") ? rawHooks : {};
        pageContext = (pageHooks && (pageHooks.context || pageHooks.CONTEXT)) || {};
        experimentalLegModel = normalizeExperimentalLegModel(
          (pageHooks && (pageHooks.experimentalLeg || pageHooks.EXPERIMENTALLEG)) || {}
        );
        if (pageContext) {
          floatPlanId = parseInt(pageContext.floatPlanId || pageContext.FLOATPLANID, 10);
        }
        if (!Number.isFinite(floatPlanId)) {
          floatPlanId = 0;
        }
      }

      if (hooksEl) {
        try {
          applyHookPayload(JSON.parse(hooksEl.textContent || "{}"));
        } catch (err) {
          applyHookPayload({});
        }
      } else {
        applyHookPayload({});
      }

	      function formatTimelineLocalTime(input) {
	        var raw = String(input || "").trim();
	        var date = raw ? new Date(raw) : null;
	        if (!date || Number.isNaN(date.getTime())) {
	          return "";
	        }
	        return date.toLocaleTimeString([], {
	          hour: "numeric",
	          minute: "2-digit"
	        });
	      }

	      function hydrateTimelineTimes() {
	        document.querySelectorAll(".timeline-time[data-time-utc]").forEach(function (el) {
	          var label = formatTimelineLocalTime(el.getAttribute("data-time-utc"));
	          if (label) {
	            el.textContent = label;
	          }
	        });
	      }

      function formatHeroEtaLabel(input) {
        var raw = String(input || "").trim();
        var date = raw ? new Date(raw) : null;
        var monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        var hours = 0;
        var displayHour = 0;
        var minutes = "";
        var suffix = "";

        if (!date || Number.isNaN(date.getTime())) {
          return "";
        }

        hours = date.getHours();
        displayHour = hours % 12;
        if (displayHour === 0) {
          displayHour = 12;
        }
        minutes = String(date.getMinutes());
        if (minutes.length < 2) {
          minutes = "0" + minutes;
        }
        suffix = hours >= 12 ? "PM" : "AM";

        return monthNames[date.getMonth()] + " " + date.getDate() + ", " + date.getFullYear() + " " + displayHour + ":" + minutes + " " + suffix;
      }

      function hydrateHeroEta() {
        var fields = (pageHooks && (pageHooks.fields || pageHooks.FIELDS)) || {};
        var heroEtaUtc = String(fields.heroEtaUtc || fields.HEROETAUTC || "").trim();
        var label = formatHeroEtaLabel(heroEtaUtc);

        if (!heroEtaEl || !label) {
          return;
        }

        heroEtaEl.textContent = label;
      }

      function hydrateHeroTripStart() {
        var fields = (pageHooks && (pageHooks.fields || pageHooks.FIELDS)) || {};
        var heroTripStartUtc = String(fields.heroTripStartUtc || fields.HEROTRIPSTARTUTC || "").trim();
        var label = formatHeroEtaLabel(heroTripStartUtc);

        if (!heroTripStartEl || !label) {
          return;
        }

        heroTripStartEl.textContent = "Trip Start: " + label;
      }

      function hydrateLastCheckinLabels() {
        var fields = (pageHooks && (pageHooks.fields || pageHooks.FIELDS)) || {};
        var heroLastCheckInUtc = String(fields.heroLastCheckInUtc || fields.HEROLASTCHECKINUTC || "").trim();
        var label = formatHeroEtaLabel(heroLastCheckInUtc);

        if (!label) {
          return;
        }
        if (heroLastCheckInEl) {
          heroLastCheckInEl.textContent = label;
        }
        if (floatPlanLastCheckInEl) {
          floatPlanLastCheckInEl.textContent = label;
        }
      }

      function hydrateLegArrival() {
        var fields = (pageHooks && (pageHooks.fields || pageHooks.FIELDS)) || {};
        var legArrivalUtc = String(fields.legArrivalUtc || fields.LEGARRIVALUTC || "").trim();
        var label = formatTimelineLocalTime(legArrivalUtc);

        if (!legArrivalEl || !label) {
          return;
        }

        legArrivalEl.textContent = label;
      }

      function hydrateRouteStop4Stamp() {
        var fields = (pageHooks && (pageHooks.fields || pageHooks.FIELDS)) || {};
        var heroEtaUtc = String(fields.heroEtaUtc || fields.HEROETAUTC || "").trim();
        var label = formatHeroEtaLabel(heroEtaUtc);

        if (!routeStop4StampEl || !label) {
          return;
        }

        routeStop4StampEl.textContent = label + " ETA";
      }

      hydrateTimelineTimes();
      hydrateHeroEta();
      hydrateHeroTripStart();
      hydrateLastCheckinLabels();
      hydrateLegArrival();
      hydrateRouteStop4Stamp();

      function parseExperimentalDate(value) {
        var raw = String(value || "").trim();
        var parsed = raw ? new Date(raw) : null;
        if (!parsed || Number.isNaN(parsed.getTime())) {
          return null;
        }
        return parsed;
      }

      function formatExperimentalNm(value) {
        var numeric = Number(value);
        if (!Number.isFinite(numeric) || numeric < 0) {
          numeric = 0;
        }
        return numeric.toFixed(1) + " nm";
      }

      function formatExperimentalPct(value) {
        var numeric = Math.floor(Number(value));
        if (!Number.isFinite(numeric) || numeric < 0) {
          numeric = 0;
        }
        if (numeric > 100) {
          numeric = 100;
        }
        return String(numeric) + "%";
      }

      function computeExperimentalLegState(model, nowDate) {
        var distanceNm = Number(model && model.currentLegDistanceNm);
        var speedKn = Number(model && model.speedKn);
        var fuelBurnGph = Number(model && model.fuelBurnGph);
        var reservePct = Number(model && model.reservePct);
        var startDt = parseExperimentalDate(model && model.baseStartUtc);
        var pauseStartDt = parseExperimentalDate(model && model.pauseStartUtc);
        var pauseResumeDt = parseExperimentalDate(model && model.pauseResumeUtc);
        var elapsedMs = 0;
        var pauseMs = 0;
        var traveledNm = 0;
        var remainingNm = 0;
        var percentComplete = 0;
        var baseFuelGal = 0;
        var reserveFuelGal = 0;
        var requiredFuelGal = 0;
        var pauseActive = false;

        if (!Number.isFinite(distanceNm) || distanceNm <= 0 || !Number.isFinite(speedKn) || speedKn <= 0 || !startDt) {
          return null;
        }

        elapsedMs = nowDate.getTime() - startDt.getTime();
        if (elapsedMs < 0) {
          elapsedMs = 0;
        }
        if (pauseStartDt && nowDate.getTime() > pauseStartDt.getTime()) {
          pauseActive = !pauseResumeDt || nowDate.getTime() < pauseResumeDt.getTime();
          pauseMs = (pauseActive ? nowDate.getTime() : Math.min(nowDate.getTime(), pauseResumeDt.getTime())) - pauseStartDt.getTime();
          if (pauseMs > 0) {
            elapsedMs -= pauseMs;
          }
        }
        if (elapsedMs < 0) {
          elapsedMs = 0;
        }

        traveledNm = (elapsedMs / 3600000) * speedKn;
        if (traveledNm > distanceNm) {
          traveledNm = distanceNm;
        }
        if (traveledNm < 0) {
          traveledNm = 0;
        }
        remainingNm = distanceNm - traveledNm;
        if (remainingNm < 0) {
          remainingNm = 0;
        }
        percentComplete = distanceNm > 0 ? Math.floor((traveledNm / distanceNm) * 100) : 0;
        if (percentComplete < 0) {
          percentComplete = 0;
        }
        if (percentComplete > 100) {
          percentComplete = 100;
        }

        if (Number.isFinite(fuelBurnGph) && fuelBurnGph > 0 && remainingNm > 0) {
          baseFuelGal = (remainingNm / speedKn) * fuelBurnGph;
          if (!Number.isFinite(baseFuelGal) || baseFuelGal < 0) {
            baseFuelGal = 0;
          }
          if (Number.isFinite(reservePct) && reservePct > 0) {
            reserveFuelGal = baseFuelGal * (reservePct / 100);
          }
          requiredFuelGal = baseFuelGal + reserveFuelGal;
        }

        return {
          remainingNm: remainingNm,
          percentComplete: percentComplete,
          paceKn: speedKn,
          requiredFuelGal: requiredFuelGal,
          pauseActive: pauseActive
        };
      }

      function renderExperimentalLegProgress() {
        var nowDate = new Date();
        var state = computeExperimentalLegState(experimentalLegModel, nowDate);
        var assumptionLabel = String((experimentalLegModel && experimentalLegModel.assumptionLabel) || "").trim();
        var statusLabel = String((experimentalLegModel && experimentalLegModel.statusLabel) || "").trim();
        var pauseResumeDt = parseExperimentalDate(experimentalLegModel && experimentalLegModel.pauseResumeUtc);

        if (!experimentalLegStatusEl || !experimentalLegBarEl || !experimentalLegRemainingEl || !experimentalLegPercentEl || !experimentalLegPaceEl || !experimentalLegFuelEl || !experimentalLegMetaEl) {
          return;
        }

        if (!experimentalLegModel || experimentalLegModel.available !== true || !state) {
          experimentalLegStatusEl.textContent = statusLabel || "Beta current-leg model unavailable";
          experimentalLegBarEl.style.width = "0%";
          experimentalLegRemainingEl.textContent = "—";
          experimentalLegPercentEl.textContent = "—";
          experimentalLegPaceEl.textContent = "Exp pace: —";
          experimentalLegFuelEl.textContent = "Exp fuel unavailable";
          experimentalLegMetaEl.textContent = assumptionLabel || "Assumes an 8:00 AM departure-timezone leg start for display only.";
          return;
        }

        experimentalLegStatusEl.textContent = state.pauseActive
          ? "Paused overnight"
          : (statusLabel || "Browser-time display");
        experimentalLegBarEl.style.width = formatExperimentalPct(state.percentComplete);
        experimentalLegRemainingEl.textContent = formatExperimentalNm(state.remainingNm) + " exp remaining";
        experimentalLegPercentEl.textContent = formatExperimentalPct(state.percentComplete) + " exp complete";
        experimentalLegPaceEl.textContent = "Exp pace: " + state.paceKn.toFixed(1) + " kt";
        experimentalLegFuelEl.textContent = state.requiredFuelGal > 0
          ? "Exp fuel: " + state.requiredFuelGal.toFixed(1) + " gal"
          : "Exp fuel unavailable";
        experimentalLegMetaEl.textContent = assumptionLabel;
        if (
          state.pauseActive
          && pauseResumeDt
          && assumptionLabel.toLowerCase().indexOf("paused until") === -1
          && assumptionLabel.toLowerCase().indexOf("overnight pause excluded until") === -1
        ) {
          experimentalLegMetaEl.textContent += " Paused until " + pauseResumeDt.toLocaleTimeString([], {
            hour: "numeric",
            minute: "2-digit"
          }) + ".";
        }
      }

      renderExperimentalLegProgress();
      if (experimentalLegModel && experimentalLegModel.available === true) {
        window.setInterval(renderExperimentalLegProgress, 60000);
      }

      function buildRouteBuilderApiUrl(action) {
        return new URL(
          "../api/v1/routeBuilder.cfc?method=handle&action=" + encodeURIComponent(action) + "&returnFormat=json",
          window.location.href
        ).toString();
      }

      function cloneData(value) {
        return JSON.parse(JSON.stringify(value || {}));
      }

      function parseJsonResponse(response, fallbackMessage) {
        return response.text().then(function (text) {
          var payload = {};
          try {
            payload = text ? JSON.parse(text) : {};
          } catch (err) {
            payload = {
              SUCCESS: false,
              MESSAGE: fallbackMessage || "Request failed."
            };
          }
          if (!response.ok || payload.SUCCESS === false || payload.success === false) {
            throw payload;
          }
          return payload;
        });
      }

      function postJson(url, payload, fallbackMessage) {
        return fetch(url, {
          method: "POST",
          credentials: "include",
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json"
          },
          body: JSON.stringify(payload || {})
        }).then(function (response) {
          return parseJsonResponse(response, fallbackMessage);
        });
      }

      function readCanonicalRouteCode() {
        return String(
          pageContext.routeCode ||
          pageContext.ROUTECODE ||
          pageContext.activeRouteCode ||
          pageContext.ACTIVEROUTECODE ||
          ""
        ).trim();
      }

      function isMyRouteType(rawValue) {
        var routeType = String(rawValue || "").trim().toLowerCase();
        return routeType === "my_route" || routeType === "my_routes" || routeType === "custom";
      }

      function setWeatherApplyButtonState(options) {
        var opts = (options && typeof options === "object") ? options : {};
        var isVisible = opts.visible === true;
        var isLoading = opts.loading === true;
        var isDisabled = opts.disabled === true || isLoading;
        var label = String(opts.label || "Apply Weather to Route");

        if (weatherApplyWrapEl) {
          weatherApplyWrapEl.hidden = !isVisible;
        }
        if (!weatherApplyButton) {
          return;
        }
        weatherApplyButton.disabled = isDisabled;
        weatherApplyButton.textContent = isLoading ? "Applying..." : label;
      }

      function requestRouteEditContext(routeCode) {
        return postJson(
          buildRouteBuilderApiUrl("routegen_geteditcontext"),
          {
            route_code: routeCode
          },
          "Route edit context unavailable."
        );
      }

      function requestRoutePreview(inputs) {
        var previewInputs = cloneData(inputs);
        var previewAction = isMyRouteType(previewInputs.route_type) ? "previewuserroute" : "routegen_preview";
        return postJson(
          buildRouteBuilderApiUrl(previewAction),
          previewInputs,
          "Route preview unavailable."
        );
      }

      function requestRouteUpdate(payload) {
        return postJson(
          buildRouteBuilderApiUrl("routegen_update"),
          payload,
          "Unable to apply weather to this route."
        );
      }

      function refreshActiveCruiseFieldsFromDocument(sourceDoc) {
        var sourceHooksEl = sourceDoc ? sourceDoc.getElementById("fpw-active-cruise-hooks") : null;
        var sourceFieldNodes = null;
        var sourceFieldNode = null;
        var fieldName = "";
        var idx = 0;
        var nextHooks = {};
        var sourceDailyStartInput = null;
        var sourceTimelineNodes = null;
        var targetTimelineNodes = null;
        var timelineLimit = 0;

        if (!sourceDoc || !sourceHooksEl) {
          throw new Error("Active Cruise refresh data unavailable.");
        }

        sourceFieldNodes = sourceDoc.querySelectorAll("[data-fpw-field]");
        for (idx = 0; idx < sourceFieldNodes.length; idx += 1) {
          sourceFieldNode = sourceFieldNodes[idx];
          fieldName = String(sourceFieldNode.getAttribute("data-fpw-field") || "").trim();
          if (!fieldName) {
            continue;
          }
          document.querySelectorAll('[data-fpw-field="' + fieldName + '"]').forEach(function (targetNode) {
            targetNode.textContent = sourceFieldNode.textContent;
            if (sourceFieldNode.hasAttribute("style")) {
              targetNode.setAttribute("style", sourceFieldNode.getAttribute("style"));
            } else {
              targetNode.removeAttribute("style");
            }
          });
        }

        if (hooksEl) {
          hooksEl.textContent = sourceHooksEl.textContent || "{}";
          try {
            nextHooks = JSON.parse(hooksEl.textContent || "{}");
          } catch (err) {
            nextHooks = {};
          }
          applyHookPayload(nextHooks);
        }

        sourceDailyStartInput = sourceDoc.getElementById("fpwMonitorDailyStartInput");
        if (monitorDailyStartInputEl && sourceDailyStartInput) {
          monitorDailyStartInputEl.value = String(sourceDailyStartInput.value || "").trim();
        }

        sourceTimelineNodes = sourceDoc.querySelectorAll(".timeline-time");
        targetTimelineNodes = document.querySelectorAll(".timeline-time");
        timelineLimit = Math.min(sourceTimelineNodes.length, targetTimelineNodes.length);
        for (idx = 0; idx < timelineLimit; idx += 1) {
          targetTimelineNodes[idx].textContent = sourceTimelineNodes[idx].textContent;
          if (sourceTimelineNodes[idx].hasAttribute("data-time-utc")) {
            targetTimelineNodes[idx].setAttribute("data-time-utc", sourceTimelineNodes[idx].getAttribute("data-time-utc"));
          } else {
            targetTimelineNodes[idx].removeAttribute("data-time-utc");
          }
        }

        hydrateTimelineTimes();
        hydrateHeroEta();
        hydrateHeroTripStart();
        hydrateLastCheckinLabels();
        hydrateLegArrival();
        hydrateRouteStop4Stamp();
        renderExperimentalLegProgress();
      }

      function refreshActiveCruiseViewAfterWeatherApply() {
        return fetch(window.location.href, {
          method: "GET",
          credentials: "include",
          cache: "no-store",
          headers: {
            "Accept": "text/html"
          }
        }).then(function (response) {
          if (!response.ok) {
            throw new Error("Active Cruise refresh failed.");
          }
          return response.text();
        }).then(function (html) {
          var parser = new window.DOMParser();
          var refreshedDoc = parser.parseFromString(html, "text/html");
          refreshActiveCruiseFieldsFromDocument(refreshedDoc);
        });
      }

      function resolveWeatherSuggestionForLookup() {
        var routeCode = readCanonicalRouteCode();
        var editContextData = {};
        var editInputs = {};
        var previewData = {};
        var previewLegs = [];
        var routeContext = {};
        var weatherEnvelope = {};
        var suggestion = {};
        var routeName = "";
        var suggestedPct = 0;

        if (!routeWeatherAssist || typeof routeWeatherAssist.normalizeWeatherEnvelope !== "function" || typeof routeWeatherAssist.computeLiveWeatherFactorPct !== "function" || typeof routeWeatherAssist.buildRouteWeatherContextFromLegs !== "function") {
          return Promise.reject({ MESSAGE: "Route weather helper unavailable." });
        }
        if (!routeCode) {
          return Promise.reject({ MESSAGE: "Unable to resolve the active route code." });
        }
        if (!weatherLookupState.data || weatherLookupState.data.available !== true || !weatherLookupState.data.weather) {
          return Promise.reject({ MESSAGE: "Check current-leg conditions before applying weather to the route." });
        }

        return requestRouteEditContext(routeCode)
          .then(function (editContextPayload) {
            editContextData = (editContextPayload && (editContextPayload.DATA || editContextPayload.data)) || {};
            editInputs = cloneData((editContextData && (editContextData.inputs || editContextData.INPUTS)) || {});
            routeName = String(
              editInputs.route_name ||
              ((editContextData.route || {}).route_name) ||
              ((editContextData.route || {}).ROUTE_NAME) ||
              ""
            ).trim();
            if (!routeName) {
              throw { MESSAGE: "Route name unavailable for route update." };
            }
            editInputs.route_name = routeName;
            if (!String(editInputs.route_code || "").trim()) {
              editInputs.route_code = routeCode;
            }
            return requestRoutePreview(editInputs);
          })
          .then(function (previewPayload) {
            previewData = (previewPayload && (previewPayload.DATA || previewPayload.data)) || {};
            previewLegs = Array.isArray(previewData.legs) ? previewData.legs : (Array.isArray(previewData.LEGS) ? previewData.LEGS : []);
            if (!previewLegs.length) {
              throw { MESSAGE: "Route preview returned no legs." };
            }
            routeContext = routeWeatherAssist.buildRouteWeatherContextFromLegs(previewLegs);
            weatherEnvelope = routeWeatherAssist.normalizeWeatherEnvelope(weatherLookupState.data.weather || {}, "");
            suggestion = routeWeatherAssist.computeLiveWeatherFactorPct(weatherEnvelope, routeContext);
            suggestedPct = parseInt(suggestion.suggestedPct, 10);
            if (!suggestion.available || !Number.isFinite(suggestedPct)) {
              throw { MESSAGE: "Weather factor suggestion unavailable for this route." };
            }
            return {
              routeCode: routeCode,
              routeName: routeName,
              editInputs: editInputs,
              suggestedPct: suggestedPct
            };
          });
      }

      function applyWeatherToRouteFromLookup() {
        var updatedPayload = {};

        return resolveWeatherSuggestionForLookup()
          .then(function (suggestionResult) {
            updatedPayload = cloneData(suggestionResult.editInputs);
            updatedPayload.weather_factor_pct = suggestionResult.suggestedPct;
            updatedPayload.route_code = suggestionResult.routeCode;
            updatedPayload.route_name = suggestionResult.routeName;
            return requestRouteUpdate(updatedPayload).then(function () {
              return suggestionResult.suggestedPct;
            });
          });
      }

      function getSelectedWeatherPoint() {
        var selected = document.querySelector('input[name="fpwMonitorWeatherPoint"]:checked');
        return selected ? String(selected.value || "").trim().toLowerCase() : "";
      }

      function normalizeWeatherValue(value) {
        if (value === 0) {
          return "0";
        }
        if (value === null || value === undefined) {
          return "—";
        }
        value = String(value).trim();
        return value.length ? value : "—";
      }

      function resetWeatherResults() {
        weatherLookupState.point = "";
        weatherLookupState.data = null;
        if (weatherPointLabelEl) {
          weatherPointLabelEl.textContent = "—";
        }
        if (weatherWindEl) {
          weatherWindEl.textContent = "—";
        }
        if (weatherGustsEl) {
          weatherGustsEl.textContent = "—";
        }
        if (weatherWavesEl) {
          weatherWavesEl.textContent = "—";
        }
        if (weatherVisibilityEl) {
          weatherVisibilityEl.textContent = "—";
        }
        if (weatherFactorEl) {
          weatherFactorEl.textContent = "—";
        }
        if (weatherAlertsSummaryEl) {
          weatherAlertsSummaryEl.textContent = "No alerts";
        }
        if (weatherAlertsEl) {
          weatherAlertsEl.textContent = "";
        }
        if (weatherResultEl) {
          weatherResultEl.hidden = true;
        }
        setWeatherApplyButtonState({
          visible: false,
          disabled: true
        });
      }

      function setWeatherMessage(message) {
        if (weatherMessageEl) {
          weatherMessageEl.textContent = String(message || "");
        }
      }

      function setWeatherButtonLoading(isLoading) {
        if (!weatherButton) {
          return;
        }
        weatherButton.disabled = !!isLoading;
        weatherButton.textContent = isLoading ? "Checking..." : "Check Conditions";
      }

      function buildWeatherApiUrl() {
        return new URL("../api/v1/voyage.cfc?method=handle&action=getactivecruiseweather&returnFormat=json", window.location.href).toString();
      }

      function buildDailyStartApiUrl() {
        return new URL("../api/v1/floatplan.cfc?method=handle&action=updatedailystart&returnFormat=json", window.location.href).toString();
      }

      function renderWeatherAlerts(alerts) {
        var i = 0;
        var alertItem = null;
        var row = null;
        var title = null;
        var meta = null;
        var ends = null;
        var detail = null;
        var metaParts = [];

        if (!weatherAlertsEl || !weatherAlertsSummaryEl) {
          return;
        }

        weatherAlertsEl.textContent = "";
        if (!Array.isArray(alerts) || !alerts.length) {
          weatherAlertsSummaryEl.textContent = "No alerts";
          return;
        }

        weatherAlertsSummaryEl.textContent = alerts.length === 1 ? "1 alert" : String(alerts.length) + " alerts";
        for (i = 0; i < alerts.length; i += 1) {
          alertItem = alerts[i] || {};
          row = document.createElement("div");
          row.style.marginTop = i === 0 ? "10px" : "12px";
          row.style.paddingTop = "10px";
          row.style.borderTop = "1px solid rgba(126,184,226,0.12)";

          title = document.createElement("div");
          title.style.fontWeight = "700";
          title.style.color = "var(--text)";
          title.textContent = String(alertItem.headline || alertItem.event || "Alert");
          row.appendChild(title);

          metaParts = [];
          if (alertItem.severity) {
            metaParts.push(String(alertItem.severity));
          }
          if (alertItem.urgency) {
            metaParts.push(String(alertItem.urgency));
          }
          if (alertItem.certainty) {
            metaParts.push(String(alertItem.certainty));
          }
          if (metaParts.length) {
            meta = document.createElement("div");
            meta.style.marginTop = "4px";
            meta.style.color = "var(--muted)";
            meta.style.fontSize = "0.88rem";
            meta.textContent = metaParts.join(" • ");
            row.appendChild(meta);
          }

          if (alertItem.ends) {
            ends = document.createElement("div");
            ends.style.marginTop = "4px";
            ends.style.color = "var(--muted)";
            ends.style.fontSize = "0.88rem";
            ends.textContent = "Ends: " + String(alertItem.ends);
            row.appendChild(ends);
          }

          if (alertItem.instruction || alertItem.description) {
            detail = document.createElement("div");
            detail.style.marginTop = "6px";
            detail.style.color = "var(--muted)";
            detail.style.fontSize = "0.88rem";
            detail.textContent = String(alertItem.instruction || alertItem.description);
            row.appendChild(detail);
          }

          weatherAlertsEl.appendChild(row);
        }
      }

      function renderWeatherResults(data) {
        var weather = (data && data.weather) || {};
        var forecast = Array.isArray(weather.FORECAST) && weather.FORECAST.length ? (weather.FORECAST[0] || {}) : {};
        var windParts = [];
        var windLabel = "";
        var alerts = Array.isArray(weather.ALERTS) ? weather.ALERTS : [];

        if (weatherPointLabelEl) {
          weatherPointLabelEl.textContent = normalizeWeatherValue(data && data.point_label);
        }

        if (forecast.windDirection) {
          windParts.push(String(forecast.windDirection).trim());
        }
        if (forecast.windSpeed) {
          windParts.push(String(forecast.windSpeed).trim());
        }
        windLabel = windParts.join(" ").trim();

        if (weatherWindEl) {
          weatherWindEl.textContent = normalizeWeatherValue(windLabel);
        }
        if (weatherGustsEl) {
          weatherGustsEl.textContent = normalizeWeatherValue(forecast.gustMph);
        }
        if (weatherWavesEl) {
          weatherWavesEl.textContent = normalizeWeatherValue(weather.MARINE && weather.MARINE.wave_height_ft);
        }
        if (weatherVisibilityEl) {
          weatherVisibilityEl.textContent = normalizeWeatherValue(weather.surface && weather.surface.visibility_mi);
        }
        if (weatherFactorEl) {
          weatherFactorEl.textContent = "—";
        }

        renderWeatherAlerts(alerts);

        if (weatherResultEl) {
          weatherResultEl.hidden = false;
        }
        setWeatherApplyButtonState({
          visible: true,
          disabled: false
        });
      }

      function requestWeather(point) {
        return fetch(buildWeatherApiUrl(), {
          method: "POST",
          credentials: "include",
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json"
          },
          body: JSON.stringify({
            floatPlanId: floatPlanId,
            point: point
          })
        }).then(function (response) {
          return response.text().then(function (text) {
            var payload = {};
            try {
              payload = text ? JSON.parse(text) : {};
            } catch (err) {
              payload = {
                SUCCESS: false,
                MESSAGE: "Unable to load weather right now."
              };
            }
            if (!response.ok || payload.SUCCESS === false) {
              throw payload;
            }
            return payload;
          });
        });
      }

	      function applySelectedStatus(nextStatus) {
	        var buttons = statusGroupEl.querySelectorAll("[data-status]");
        selectedStatus = nextStatus;
        buttons.forEach(function (button) {
          var isSelected = String(button.getAttribute("data-status") || "") === selectedStatus;
          button.classList.toggle("is-selected", isSelected);
          button.setAttribute("aria-pressed", isSelected ? "true" : "false");
        });
      }

      function resetCheckInForm() {
        applySelectedStatus("On Track");
        noteWrapEl.classList.remove("is-open");
        noteInput.value = "";
        noteToggleBtn.hidden = false;
      }

      function openModal() {
        resetCheckInForm();
        modalEl.classList.add("is-open");
        modalEl.setAttribute("aria-hidden", "false");
      }

      function closeModal() {
        modalEl.classList.remove("is-open");
        modalEl.setAttribute("aria-hidden", "true");
      }

      checkInButton.addEventListener("click", function () {
        openModal();
      });

      if (completeLegButton) {
        completeLegButton.addEventListener("click", function () {
          var fields = (pageHooks && (pageHooks.fields || pageHooks.FIELDS)) || {};
          var summary = String(fields.heroCurrentLegSummary || fields.HEROCURRENTLEGSUMMARY || "").trim();
          var match = summary.match(/^(\d+)\s+of\s+\d+$/i);
          var expectedLegOrder = match ? parseInt(match[1], 10) : 0;
          var originalText = completeLegButton.textContent;

          if (!floatPlanId) {
            window.alert("Unable to find the active float plan for this trip.");
            return;
          }
          if (expectedLegOrder <= 0) {
            window.alert("Unable to resolve the current leg for this trip.");
            return;
          }
          if (!window.Api || typeof window.Api.completeActiveCruiseLeg !== "function") {
            window.alert("Leg completion service is unavailable.");
            return;
          }
          if (!window.confirm("Mark the current leg as arrived and complete?")) {
            return;
          }

          completeLegButton.disabled = true;
          completeLegButton.textContent = "Completing...";

          window.Api.completeActiveCruiseLeg({
            floatPlanId: floatPlanId,
            expectedLegOrder: expectedLegOrder
          })
            .then(function (resp) {
              if (!resp || resp.SUCCESS !== true) {
                throw resp || new Error("Leg completion failed.");
              }
              if (resp.ALREADY_COMPLETE) {
                window.alert(resp.MESSAGE || "This leg is already completed.");
              }
              window.location.reload();
            })
            .catch(function (err) {
              var message = (err && err.MESSAGE) || (err && err.message) || "Leg completion failed.";
              window.alert(message);
            })
            .finally(function () {
              completeLegButton.disabled = false;
              completeLegButton.textContent = originalText;
            });
        });
      }

      if (startNextLegButton) {
        startNextLegButton.addEventListener("click", function () {
          var originalText = startNextLegButton.textContent;

          if (!floatPlanId) {
            window.alert("Unable to find the active float plan for this trip.");
            return;
          }
          if (!window.Api || typeof window.Api.startNextActiveCruiseLeg !== "function") {
            window.alert("Next-leg start service is unavailable.");
            return;
          }
          if (!window.confirm("Start the next pending leg now?")) {
            return;
          }

          startNextLegButton.disabled = true;
          startNextLegButton.textContent = "Starting...";

          window.Api.startNextActiveCruiseLeg({
            floatPlanId: floatPlanId
          })
            .then(function (resp) {
              if (!resp || resp.SUCCESS !== true) {
                throw resp || new Error("Unable to start the next leg.");
              }
              window.location.reload();
            })
            .catch(function (err) {
              var message = (err && err.MESSAGE) || (err && err.message) || "Unable to start the next leg.";
              window.alert(message);
            })
            .finally(function () {
              startNextLegButton.disabled = false;
              startNextLegButton.textContent = originalText;
            });
        });
      }

      if (weatherButton) {
        weatherButton.addEventListener("click", function () {
          var selectedPoint = getSelectedWeatherPoint();
          var data = {};

          resetWeatherResults();

          if (!selectedPoint) {
            setWeatherMessage("Select Start or End to check conditions.");
            return;
          }

          if (!floatPlanId) {
            setWeatherMessage("Unable to find the active float plan for this trip.");
            return;
          }

          setWeatherMessage("");
          setWeatherButtonLoading(true);

          requestWeather(selectedPoint)
            .then(function (resp) {
              data = (resp && (resp.data || resp.DATA)) || {};
              if (!data.available) {
                setWeatherMessage("Conditions unavailable for selected leg point.");
                return;
              }
              weatherLookupState.point = selectedPoint;
              weatherLookupState.data = cloneData(data);
              setWeatherMessage("");
              renderWeatherResults(data);
              return resolveWeatherSuggestionForLookup()
                .then(function (suggestionResult) {
                  if (weatherFactorEl) {
                    weatherFactorEl.textContent = String(suggestionResult.suggestedPct) + "%";
                  }
                  return null;
                })
                .catch(function () {
                  if (weatherFactorEl) {
                    weatherFactorEl.textContent = "—";
                  }
                  return null;
                });
            })
            .catch(function (err) {
              var message = (err && err.MESSAGE) || (err && err.message) || "Unable to load weather right now.";
              setWeatherMessage(message);
              resetWeatherResults();
            })
            .finally(function () {
              setWeatherButtonLoading(false);
            });
        });
      }

      document.querySelectorAll('input[name="fpwMonitorWeatherPoint"]').forEach(function (input) {
        input.addEventListener("change", function () {
          resetWeatherResults();
          setWeatherMessage("");
        });
      });

      if (weatherApplyButton) {
        weatherApplyButton.addEventListener("click", function () {
          var appliedPct = null;

          setWeatherMessage("");
          setWeatherApplyButtonState({
            visible: true,
            loading: true
          });

          applyWeatherToRouteFromLookup()
            .then(function (suggestedPct) {
              appliedPct = suggestedPct;
              if (weatherFactorEl) {
                weatherFactorEl.textContent = String(appliedPct) + "%";
              }
              return refreshActiveCruiseViewAfterWeatherApply();
            })
            .then(function () {
              setWeatherMessage("Applied " + appliedPct + "% weather factor to route.");
            })
            .catch(function (err) {
              var message = (err && err.MESSAGE) || (err && err.message) || "Unable to apply weather to the route.";
              if (appliedPct !== null) {
                message = "Applied " + appliedPct + "% weather factor to route, but Active Cruise refresh did not complete.";
              }
              setWeatherMessage(message);
            })
            .finally(function () {
              setWeatherApplyButtonState({
                visible: !!weatherLookupState.data,
                disabled: !weatherLookupState.data
              });
            });
        });
      }

      closeBtn.addEventListener("click", function () {
        closeModal();
      });

      modalEl.addEventListener("click", function (event) {
        if (event.target === modalEl) {
          closeModal();
        }
      });

      statusGroupEl.addEventListener("click", function (event) {
        var button = event.target.closest("[data-status]");
        var nextStatus = "";
        if (!button) {
          return;
        }
        nextStatus = String(button.getAttribute("data-status") || "");
        if (!nextStatus) {
          return;
        }
        applySelectedStatus(nextStatus);
      });

      noteToggleBtn.addEventListener("click", function () {
        noteWrapEl.classList.add("is-open");
        noteToggleBtn.hidden = true;
        noteInput.focus();
      });

      submitBtn.addEventListener("click", function () {
        var payload = {
          status: selectedStatus,
          note: String(noteInput.value || ""),
          checkinContext: ""
        };
        var apiPayload = {
          floatPlanId: floatPlanId,
          status: payload.status,
          note: payload.note,
          checkinContext: payload.checkinContext
        };
        var shouldConfirmAssistance = (payload.status === "Assistance Needed");

        if (!floatPlanId) {
          window.alert("Unable to find the active float plan for this trip.");
          return;
        }
        if (!window.Api || typeof window.Api.submitFloatPlanCheckIn !== "function") {
          window.alert("Check-in service is unavailable.");
          return;
        }
        if (shouldConfirmAssistance && !window.confirm("Confirm Assistance Needed? This will immediately alert your float plan contacts.")) {
          return;
        }

        window.Api.submitFloatPlanCheckIn(apiPayload)
          .then(function (resp) {
            if (!resp || (resp.success !== true && resp.SUCCESS !== true)) {
              throw resp || new Error("Check-in failed.");
            }
            closeModal();
            window.location.reload();
          })
          .catch(function (err) {
            var message = (err && err.MESSAGE) || (err && err.message) || "Check-in failed.";
            window.alert(message);
          });
      });

      if (monitorDailyStartInputEl && monitorDailyStartSaveBtn) {
        monitorDailyStartSaveBtn.addEventListener("click", function () {
          var dailyStartLocalTime = String(monitorDailyStartInputEl.value || "").trim();

          if (!floatPlanId) {
            window.alert("Unable to find the active float plan for this trip.");
            return;
          }
          if (!dailyStartLocalTime) {
            window.alert("Daily start time is required.");
            return;
          }

          monitorDailyStartSaveBtn.disabled = true;
          monitorDailyStartSaveBtn.textContent = "Saving...";

          fetch(buildDailyStartApiUrl(), {
            method: "POST",
            credentials: "include",
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json"
            },
            body: JSON.stringify({
              floatPlanId: floatPlanId,
              dailyStartLocalTime: dailyStartLocalTime
            })
          }).then(function (response) {
            return response.text().then(function (text) {
              var payload = {};
              try {
                payload = text ? JSON.parse(text) : {};
              } catch (err) {
                payload = {
                  SUCCESS: false,
                  MESSAGE: "Daily start update failed."
                };
              }
              if (!response.ok || payload.SUCCESS === false) {
                throw payload;
              }
              return payload;
            });
          }).then(function () {
            window.location.reload();
          }).catch(function (err) {
            var message = (err && err.MESSAGE) || (err && err.message) || "Daily start update failed.";
            window.alert(message);
          }).finally(function () {
            monitorDailyStartSaveBtn.disabled = false;
            monitorDailyStartSaveBtn.textContent = "Save";
          });
        });
      }
    })(window, document);
  </script>
  </cfif>
</body>
</html>
