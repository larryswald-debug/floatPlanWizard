<cfcomponent output="false">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfscript>
      variables.datasource = arguments.datasource;
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="getCurrentActiveCompanionModel" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var result = baseResponse();
      var floatPlanComponent = createApiComponent("floatplan");
      var activeCruiseService = {};
      var currentGroup = {};
      var activeCruiseModel = {};

      result.AUTH = (arguments.userId GT 0);

      if (arguments.userId LTE 0) {
        result.ERROR = "INVALID_USER_ID";
        result.MESSAGE = "A valid user id is required.";
        return result;
      }

      currentGroup = floatPlanComponent.resolveCurrentRouteFloatPlanGroup(arguments.userId);
      if (
        !isStruct(currentGroup)
        OR !structKeyExists(currentGroup, "SUCCESS")
        OR currentGroup.SUCCESS NEQ true
        OR !structKeyExists(currentGroup, "IS_ACTIVE")
        OR currentGroup.IS_ACTIVE NEQ true
      ) {
        result.ERROR = firstNonEmpty([
          readString(currentGroup, "ERROR"),
          "NO_ACTIVE_PLAN"
        ]);
        result.MESSAGE = firstNonEmpty([
          readString(currentGroup, "MESSAGE"),
          "No active trip is available."
        ]);
        result.HAS_ACTIVE_PLAN = false;
        result.currentState = readString(currentGroup, "CURRENT_STATE");
        return result;
      }

      if (readNumber(currentGroup, "ROUTE_INSTANCE_ID") LTE 0) {
        result.ERROR = "ROUTE_REQUIRED";
        result.MESSAGE = "The active float plan must be linked to a route.";
        result.HAS_ACTIVE_PLAN = false;
        return result;
      }

      activeCruiseService = createApiComponent("ActiveCruiseViewModelService").init(variables.datasource);
      activeCruiseModel = activeCruiseService.getActiveCruiseViewModel(arguments.userId, readNumber(currentGroup, "FLOATPLANID"));

      if (
        !isStruct(activeCruiseModel)
        OR !structKeyExists(activeCruiseModel, "success")
        OR activeCruiseModel.success NEQ true
      ) {
        result.ERROR = "ACTIVE_CRUISE_MODEL_UNAVAILABLE";
        result.MESSAGE = firstNonEmpty([
          readString(activeCruiseModel, "message"),
          "The active trip model is unavailable."
        ]);
        result.HAS_ACTIVE_PLAN = true;
        result.activeFloatPlan = buildActiveFloatPlan(activeCruiseModel);
        result.warnings = readArray(activeCruiseModel, "warnings");
        return result;
      }

      result.SUCCESS = true;
      result.success = true;
      result.HAS_ACTIVE_PLAN = true;
      result.MESSAGE = "Companion active trip model generated.";
      result.generatedAtUtc = readString(activeCruiseModel, "generatedAtUtc");
      result.tripState = readString(activeCruiseModel, "tripState");
      result.motionState = readString(activeCruiseModel, "motionState");
      result.safetyState = readString(activeCruiseModel, "safetyState");
      result.activeFloatPlan = buildActiveFloatPlan(activeCruiseModel);
      result.route = buildRoute(activeCruiseModel);
      result.currentLeg = buildCurrentLeg(activeCruiseModel);
      result.monitoring = buildMonitoring(activeCruiseModel);
      result.checkIn = buildCheckIn(activeCruiseModel);
      result.actions = buildActions(activeCruiseModel);
      result.displayAuthority = duplicate(readStruct(activeCruiseModel, "displayAuthority"));
      result.storageAuthority = {
        "activePlanGuard" = "floatplan.resolveCurrentRouteFloatPlanGroup",
        "readModel" = "ActiveCruiseViewModelService",
        "checkInWrite" = "floatplan.cfc?action=checkin"
      };
      result.warnings = readArray(activeCruiseModel, "warnings");

      return result;
    </cfscript>
  </cffunction>

  <cffunction name="baseResponse" access="private" returntype="struct" output="false">
    <cfscript>
      return {
        "SUCCESS" = false,
        "success" = false,
        "AUTH" = false,
        "HAS_ACTIVE_PLAN" = false,
        "ERROR" = "",
        "MESSAGE" = "",
        "generatedAtUtc" = "",
        "tripState" = "",
        "motionState" = "",
        "safetyState" = "",
        "activeFloatPlan" = {},
        "route" = {},
        "currentLeg" = {},
        "monitoring" = {},
        "checkIn" = {},
        "actions" = {},
        "displayAuthority" = {},
        "storageAuthority" = {},
        "warnings" = []
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildActiveFloatPlan" access="private" returntype="struct" output="false">
    <cfargument name="model" type="struct" required="true">
    <cfscript>
      var floatPlan = readStruct(arguments.model, "floatPlan");
      var route = readStruct(arguments.model, "route");
      var floatPlanId = readNumber(floatPlan, "id");

      return {
        "id" = floatPlanId,
        "floatPlanId" = floatPlanId,
        "name" = readString(floatPlan, "name"),
        "status" = readString(floatPlan, "status"),
        "scheduledDepartureUtc" = readString(floatPlan, "scheduledDepartureUtc"),
        "scheduledDepartureLocal" = readString(floatPlan, "scheduledDepartureLocal"),
        "timezone" = readString(floatPlan, "timezone"),
        "checkedInAtUtc" = readString(floatPlan, "checkedInAtUtc"),
        "checkinContext" = readString(floatPlan, "checkinContext"),
        "activatedAtUtc" = readString(floatPlan, "activatedAtUtc"),
        "closedAtUtc" = readString(floatPlan, "closedAtUtc"),
        "routeInstanceId" = readNumber(route, "routeInstanceId"),
        "routeName" = readString(route, "routeName")
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildRoute" access="private" returntype="struct" output="false">
    <cfargument name="model" type="struct" required="true">
    <cfscript>
      var route = readStruct(arguments.model, "route");
      return {
        "routeInstanceId" = readNumber(route, "routeInstanceId"),
        "routeCode" = readString(route, "routeCode"),
        "routeName" = readString(route, "routeName"),
        "status" = readString(route, "status"),
        "startLocation" = readString(route, "startLocation"),
        "endLocation" = readString(route, "endLocation"),
        "totalLegs" = readNumber(route, "totalLegs")
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildCurrentLeg" access="private" returntype="struct" output="false">
    <cfargument name="model" type="struct" required="true">
    <cfscript>
      var currentLeg = readStruct(arguments.model, "currentLeg");
      return {
        "order" = readNumber(currentLeg, "order"),
        "fromName" = readString(currentLeg, "fromName"),
        "toName" = readString(currentLeg, "toName"),
        "distanceNm" = readNumber(currentLeg, "distanceNm"),
        "completedNm" = readNumber(currentLeg, "completedNm"),
        "remainingNm" = readNumber(currentLeg, "remainingNm"),
        "percentComplete" = readNumber(currentLeg, "percentComplete"),
        "etaUtc" = readString(currentLeg, "etaUtc"),
        "status" = readString(currentLeg, "status"),
        "statusLabel" = readString(currentLeg, "statusLabel"),
        "authority" = readString(currentLeg, "authority")
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildMonitoring" access="private" returntype="struct" output="false">
    <cfargument name="model" type="struct" required="true">
    <cfscript>
      var monitoring = readStruct(arguments.model, "monitoring");
      return {
        "available" = readBoolean(monitoring, "available"),
        "mode" = readString(monitoring, "mode"),
        "state" = readString(monitoring, "state"),
        "isEnabled" = readBoolean(monitoring, "isEnabled"),
        "expectedCheckinAtUtc" = readString(monitoring, "expectedCheckinAtUtc"),
        "expectedCheckinLocalLabel" = readString(monitoring, "expectedCheckinLocalLabel"),
        "lastCheckinAtUtc" = readString(monitoring, "lastCheckinAtUtc"),
        "lastCheckinStatus" = readString(monitoring, "lastCheckinStatus"),
        "secureForNight" = readBoolean(monitoring, "secureForNight"),
        "secureForNightUntilUtc" = readString(monitoring, "secureForNightUntilUtc"),
        "manualDelayMinutesTotal" = readNumber(monitoring, "manualDelayMinutesTotal"),
        "manualDelayLabel" = readString(monitoring, "manualDelayLabel"),
        "dailyStartLocalTime" = readString(monitoring, "dailyStartLocalTime"),
        "dailyStartLabel" = readString(monitoring, "dailyStartLabel")
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildCheckIn" access="private" returntype="struct" output="false">
    <cfargument name="model" type="struct" required="true">
    <cfscript>
      var checkIn = readStruct(arguments.model, "checkIn");
      return {
        "context" = readString(checkIn, "context"),
        "lastStatus" = readString(checkIn, "lastStatus"),
        "allowedStatusOptions" = duplicate(readArray(checkIn, "allowedStatusOptions")),
        "validationMessages" = duplicate(readStruct(checkIn, "validationMessages"))
      };
    </cfscript>
  </cffunction>

  <cffunction name="buildActions" access="private" returntype="struct" output="false">
    <cfargument name="model" type="struct" required="true">
    <cfscript>
      var actions = readStruct(arguments.model, "actions");
      var companionActions = {};

      if (structKeyExists(actions, "checkIn") AND isStruct(actions.checkIn)) {
        companionActions.checkIn = duplicate(actions.checkIn);
      }

      return companionActions;
    </cfscript>
  </cffunction>

  <cffunction name="createApiComponent" access="private" returntype="any" output="false">
    <cfargument name="componentName" type="string" required="true">
    <cfscript>
      try {
        return createObject("component", "fpw.api.v1." & arguments.componentName);
      } catch (any primaryError) {
        return createObject("component", "api.v1." & arguments.componentName);
      }
    </cfscript>
  </cffunction>

  <cffunction name="readStruct" access="private" returntype="struct" output="false">
    <cfargument name="source" type="any" required="true">
    <cfargument name="key" type="string" required="true">
    <cfscript>
      if (isStruct(arguments.source) AND structKeyExists(arguments.source, arguments.key) AND isStruct(arguments.source[arguments.key])) {
        return arguments.source[arguments.key];
      }
      return {};
    </cfscript>
  </cffunction>

  <cffunction name="readArray" access="private" returntype="array" output="false">
    <cfargument name="source" type="any" required="true">
    <cfargument name="key" type="string" required="true">
    <cfscript>
      if (isStruct(arguments.source) AND structKeyExists(arguments.source, arguments.key) AND isArray(arguments.source[arguments.key])) {
        return arguments.source[arguments.key];
      }
      return [];
    </cfscript>
  </cffunction>

  <cffunction name="readString" access="private" returntype="string" output="false">
    <cfargument name="source" type="any" required="true">
    <cfargument name="key" type="string" required="true">
    <cfargument name="fallback" type="string" required="false" default="">
    <cfscript>
      if (!isStruct(arguments.source) OR !structKeyExists(arguments.source, arguments.key) OR isNull(arguments.source[arguments.key])) {
        return arguments.fallback;
      }
      return trim(toString(arguments.source[arguments.key]));
    </cfscript>
  </cffunction>

  <cffunction name="readNumber" access="private" returntype="numeric" output="false">
    <cfargument name="source" type="any" required="true">
    <cfargument name="key" type="string" required="true">
    <cfargument name="fallback" type="numeric" required="false" default="0">
    <cfscript>
      if (!isStruct(arguments.source) OR !structKeyExists(arguments.source, arguments.key) OR isNull(arguments.source[arguments.key]) OR !isNumeric(arguments.source[arguments.key])) {
        return arguments.fallback;
      }
      return val(arguments.source[arguments.key]);
    </cfscript>
  </cffunction>

  <cffunction name="readBoolean" access="private" returntype="boolean" output="false">
    <cfargument name="source" type="any" required="true">
    <cfargument name="key" type="string" required="true">
    <cfargument name="fallback" type="boolean" required="false" default="false">
    <cfscript>
      if (!isStruct(arguments.source) OR !structKeyExists(arguments.source, arguments.key) OR isNull(arguments.source[arguments.key])) {
        return arguments.fallback;
      }
      if (isBoolean(arguments.source[arguments.key])) {
        return arguments.source[arguments.key];
      }
      if (isNumeric(arguments.source[arguments.key])) {
        return val(arguments.source[arguments.key]) NEQ 0;
      }
      return listFindNoCase("true,yes,y,on", trim(toString(arguments.source[arguments.key]))) GT 0;
    </cfscript>
  </cffunction>

  <cffunction name="firstNonEmpty" access="private" returntype="string" output="false">
    <cfargument name="values" type="array" required="true">
    <cfscript>
      var i = 0;
      var value = "";
      for (i = 1; i LTE arrayLen(arguments.values); i++) {
        value = trim(toString(arguments.values[i]));
        if (len(value)) {
          return value;
        }
      }
      return "";
    </cfscript>
  </cffunction>

</cfcomponent>
