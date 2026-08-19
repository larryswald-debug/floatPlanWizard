<cfcomponent output="false">

  <cfset variables.datasource = "fpw">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfscript>
      variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="getState" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="access" type="struct" required="false">
    <cfscript>
      var state = buildEmptyState();
      var effectiveAccess = {};
      var qUser = queryNew("");
      var qChecklist = queryNew("");
      var message = {};
      var vesselCount = 0;
      var contactCount = 0;
      var passengerCount = 0;
      var operatorCount = 0;
      var savedWaypointCount = 0;
      var requiredWaypointCount = 2;
      var remainingWaypointCount = 2;
      var vesselComplete = false;
      var contactComplete = false;
      var passengersComplete = false;
      var operatorComplete = false;
      var waypointsComplete = false;
      var firstIncompleteStep = "vessel";
      var allComplete = false;
      var continueAction = "add-vessel";
      var storedVisibilityIsNull = true;
      var storedGettingStartedHidden = false;

      if (arguments.userId LTE 0) {
        return state;
      }

      qUser = queryExecute(
        "SELECT
           welcomeOnboardingSeenAt,
           gettingStartedHidden,
           DATE_FORMAT(
             welcomeOnboardingSeenAt,
             '%Y-%m-%dT%H:%i:%s.%fZ'
           ) AS onboarding_acknowledged_at,
           (welcomeOnboardingSeenAt IS NULL) AS onboarding_unacknowledged,
           (gettingStartedHidden IS NULL) AS getting_started_hidden_is_null
         FROM users
         WHERE userId = :userId
         LIMIT 1",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      if (qUser.recordCount EQ 0) {
        return state;
      }

      storedVisibilityIsNull = val(qUser.getting_started_hidden_is_null[1]) EQ 1;
      if (!storedVisibilityIsNull) {
        storedGettingStartedHidden = val(qUser.gettingStartedHidden[1]) EQ 1;
      }

      if (val(qUser.onboarding_unacknowledged[1]) EQ 0) {
        state["acknowledgedAt"] = toString(qUser.onboarding_acknowledged_at[1]);
        state["autoOpenWelcome"] = false;
      }

      if (structKeyExists(arguments, "access") AND isStruct(arguments.access) AND structCount(arguments.access) GT 0) {
        effectiveAccess = arguments.access;
      } else {
        effectiveAccess = getEntitlementService().getCurrentAccess(arguments.userId);
      }
      message = resolveWelcomeMessage(effectiveAccess);
      state["messageState"] = message["messageState"];
      state["welcomeMessage"] = message["welcomeMessage"];

      qChecklist = queryExecute(
        "SELECT
            (
              SELECT COUNT(*)
              FROM vessels v
              WHERE v.userId = :userIdText
            ) AS vessel_count,
            (
              SELECT COUNT(*)
              FROM contacts c
              WHERE c.userId = :userIdText
                AND COALESCE(NULLIF(TRIM(c.name), ''), '') <> ''
                AND COALESCE(NULLIF(TRIM(c.phone), ''), '') <> ''
                AND COALESCE(NULLIF(TRIM(c.email), ''), '') <> ''
            ) AS contact_count,
            (
              SELECT COUNT(*)
              FROM passengers p
              WHERE p.userId = :userIdText
            ) AS passenger_count,
            (
              SELECT COUNT(*)
              FROM operators o
              WHERE o.userId = :userIdText
            ) AS operator_count,
            (
              SELECT COUNT(*)
              FROM waypoints w
              WHERE w.userId = :userIdText
            ) AS waypoint_count",
        {
          userIdText = { value = toString(val(arguments.userId)), cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );

      if (qChecklist.recordCount GT 0) {
        vesselCount = val(qChecklist.vessel_count[1]);
        contactCount = val(qChecklist.contact_count[1]);
        passengerCount = val(qChecklist.passenger_count[1]);
        operatorCount = val(qChecklist.operator_count[1]);
        savedWaypointCount = val(qChecklist.waypoint_count[1]);
      }

      remainingWaypointCount = savedWaypointCount GTE requiredWaypointCount
        ? 0
        : requiredWaypointCount - savedWaypointCount;
      vesselComplete = vesselCount GT 0;
      contactComplete = contactCount GT 0;
      passengersComplete = passengerCount GT 0;
      operatorComplete = operatorCount GT 0;
      waypointsComplete = savedWaypointCount GTE requiredWaypointCount;
      allComplete = (
        vesselComplete
        AND contactComplete
        AND operatorComplete
        AND waypointsComplete
      );

      if (!vesselComplete) {
        firstIncompleteStep = "vessel";
        continueAction = "add-vessel";
      } else if (!contactComplete) {
        firstIncompleteStep = "contact";
        continueAction = "add-contact";
      } else if (!operatorComplete) {
        firstIncompleteStep = "operator";
        continueAction = "add-operator";
      } else if (!waypointsComplete) {
        firstIncompleteStep = "waypoints";
        continueAction = "add-waypoint";
      } else {
        firstIncompleteStep = "complete";
        continueAction = "create-route";
      }

      state["checklist"]["vessel"] = vesselComplete;
      state["checklist"]["contact"] = contactComplete;
      state["checklist"]["passengers"] = passengersComplete;
      state["checklist"]["operator"] = operatorComplete;
      state["checklist"]["waypoints"] = waypointsComplete;
      state["checklist"]["savedWaypointCount"] = savedWaypointCount;
      state["checklist"]["requiredWaypointCount"] = requiredWaypointCount;
      state["checklist"]["remainingWaypointCount"] = remainingWaypointCount;
      state["checklist"]["firstIncompleteStep"] = firstIncompleteStep;
      state["checklist"]["allComplete"] = allComplete;
      state["gettingStartedHidden"] = storedVisibilityIsNull
        ? allComplete
        : storedGettingStartedHidden;
      state["continueTarget"]["action"] = continueAction;
      return state;
    </cfscript>
  </cffunction>

  <cffunction name="acknowledgeWelcome" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var result = structNew("ordered-casesensitive");
      var qUser = queryNew("");

      result["SUCCESS"] = false;
      result["success"] = false;
      result["acknowledgedAt"] = nullValue();
      if (arguments.userId LTE 0) {
        result["ERROR"] = "INVALID_USER_ID";
        result["errorCode"] = "INVALID_USER_ID";
        result["MESSAGE"] = "A valid authenticated member is required.";
        result["message"] = result["MESSAGE"];
        return result;
      }

      queryExecute(
        "UPDATE users
         SET welcomeOnboardingSeenAt = COALESCE(welcomeOnboardingSeenAt, UTC_TIMESTAMP(6))
         WHERE userId = :userId",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );

      qUser = queryExecute(
        "SELECT
           welcomeOnboardingSeenAt,
           DATE_FORMAT(
             welcomeOnboardingSeenAt,
             '%Y-%m-%dT%H:%i:%s.%fZ'
           ) AS onboarding_acknowledged_at,
           (welcomeOnboardingSeenAt IS NULL) AS onboarding_unacknowledged
         FROM users
         WHERE userId = :userId
         LIMIT 1",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      if (
        qUser.recordCount EQ 0
        OR val(qUser.onboarding_unacknowledged[1]) EQ 1
      ) {
        result["ERROR"] = "ACKNOWLEDGMENT_FAILED";
        result["errorCode"] = "ACKNOWLEDGMENT_FAILED";
        result["MESSAGE"] = "The Welcome acknowledgment could not be saved.";
        result["message"] = result["MESSAGE"];
        return result;
      }

      result["SUCCESS"] = true;
      result["success"] = true;
      result["acknowledgedAt"] = toString(qUser.onboarding_acknowledged_at[1]);
      return result;
    </cfscript>
  </cffunction>

  <cffunction name="setGettingStartedHidden" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="hidden" type="boolean" required="true">
    <cfscript>
      var result = structNew("ordered-casesensitive");
      var desiredValue = arguments.hidden ? 1 : 0;
      var qUser = queryNew("");

      result["SUCCESS"] = false;
      result["success"] = false;
      result["gettingStartedHidden"] = arguments.hidden;
      if (arguments.userId LTE 0) {
        result["ERROR"] = "INVALID_USER_ID";
        result["errorCode"] = "INVALID_USER_ID";
        result["MESSAGE"] = "A valid authenticated member is required.";
        result["message"] = result["MESSAGE"];
        return result;
      }

      queryExecute(
        "UPDATE users
         SET gettingStartedHidden = :hidden
         WHERE userId = :userId",
        {
          hidden = { value = desiredValue, cfsqltype = "cf_sql_tinyint" },
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );

      qUser = queryExecute(
        "SELECT gettingStartedHidden
         FROM users
         WHERE userId = :userId
         LIMIT 1",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      if (
        qUser.recordCount EQ 0
        OR val(qUser.gettingStartedHidden[1]) NEQ desiredValue
      ) {
        result["ERROR"] = "PREFERENCE_SAVE_FAILED";
        result["errorCode"] = "PREFERENCE_SAVE_FAILED";
        result["MESSAGE"] = "The Getting Started preference could not be saved.";
        result["message"] = result["MESSAGE"];
        return result;
      }

      result["SUCCESS"] = true;
      result["success"] = true;
      return result;
    </cfscript>
  </cffunction>

  <cffunction name="buildEmptyState" access="private" returntype="struct" output="false">
    <cfscript>
      var state = structNew("ordered-casesensitive");
      var checklist = structNew("ordered-casesensitive");
      var continueTarget = structNew("ordered-casesensitive");

      checklist["vessel"] = false;
      checklist["contact"] = false;
      checklist["passengers"] = false;
      checklist["operator"] = false;
      checklist["waypoints"] = false;
      checklist["savedWaypointCount"] = 0;
      checklist["requiredWaypointCount"] = 2;
      checklist["remainingWaypointCount"] = 2;
      checklist["firstIncompleteStep"] = "vessel";
      checklist["allComplete"] = false;

      continueTarget["action"] = "add-vessel";

      state["autoOpenWelcome"] = true;
      state["acknowledgedAt"] = nullValue();
      state["gettingStartedHidden"] = false;
      state["messageState"] = "basic_available";
      state["welcomeMessage"] = "Basic float plans can still be sent. Premium sharing requires an available trip credit or membership.";
      state["checklist"] = checklist;
      state["continueTarget"] = continueTarget;
      return state;
    </cfscript>
  </cffunction>

  <cffunction name="resolveWelcomeMessage" access="private" returntype="struct" output="false">
    <cfargument name="access" type="struct" required="true">
    <cfscript>
      var result = structNew("ordered-casesensitive");
      var credits = (
        structKeyExists(arguments.access, "premiumSendCredits")
        AND isStruct(arguments.access["premiumSendCredits"])
      ) ? arguments.access["premiumSendCredits"] : {};
      var complimentaryAvailable = structKeyExists(credits, "complimentaryAvailable") AND credits["complimentaryAvailable"];
      var complimentaryConsumed = structKeyExists(credits, "complimentaryConsumed") AND credits["complimentaryConsumed"];
      var paidTripAvailable = structKeyExists(credits, "paidTripAvailable") AND credits["paidTripAvailable"];
      var premiumSendAvailable = (
        structKeyExists(arguments.access, "canSendPremiumFloatPlan")
        AND arguments.access.canSendPremiumFloatPlan
      );

      if (complimentaryAvailable) {
        result["messageState"] = "complimentary_available";
        result["welcomeMessage"] = "Your first Premium trip is complimentary.";
      } else if (paidTripAvailable OR premiumSendAvailable) {
        result["messageState"] = "premium_available";
        result["welcomeMessage"] = "Premium trip sharing is available for your account.";
      } else if (complimentaryConsumed) {
        result["messageState"] = "complimentary_consumed";
        result["welcomeMessage"] = "Your complimentary Premium trip has been used. Basic float plans can still be sent, and Premium sharing requires an available trip credit or membership.";
      } else {
        result["messageState"] = "basic_available";
        result["welcomeMessage"] = "Basic float plans can still be sent. Premium sharing requires an available trip credit or membership.";
      }
      return result;
    </cfscript>
  </cffunction>

  <cffunction name="getEntitlementService" access="private" returntype="any" output="false">
    <cfscript>
      try {
        return createObject("component", "fpw.api.v1.MemberEntitlementService").init(variables.datasource);
      } catch (any primaryPathError) {
        return createObject("component", "api.v1.MemberEntitlementService").init(variables.datasource);
      }
    </cfscript>
  </cffunction>

  <cffunction name="nullValue" access="private" returntype="any" output="false">
    <cfscript>
      return javacast("null", "");
    </cfscript>
  </cffunction>

</cfcomponent>
