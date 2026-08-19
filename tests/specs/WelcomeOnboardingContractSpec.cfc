component extends="testbox.system.BaseSpec" output="false" {

  variables.datasource = "fpw";
  variables.fixtureEmailPrefix = "codex-welcome-onboarding-";

  function beforeAll() {
    cleanupFixtures();
  }

  function afterAll() {
    cleanupFixtures();
  }

  function run() {
    describe("Welcome Onboarding service and persistence contract", function() {

      beforeEach(function() {
        cleanupFixtures();
        variables.onboardingService = createObject(
          "component",
          "fpw.api.v1.OnboardingService"
        ).init(variables.datasource);
        variables.entitlementService = createObject(
          "component",
          "fpw.api.v1.MemberEntitlementService"
        ).init(variables.datasource);
        variables.creditService = createObject(
          "component",
          "fpw.api.v1.PremiumSendCreditService"
        ).init(variables.datasource);
      });

      afterEach(function() {
        cleanupFixtures();
      });

      it("returns the ordered state contract without acknowledging on read", function() {
        var fixture = createFixture("ordered-state");
        var beforeRead = loadOnboardingTimestamp(fixture.userId);
        var beforePreferenceRead = loadGettingStartedPreference(fixture.userId);
        var state = variables.onboardingService.getState(fixture.userId);
        var afterRead = loadOnboardingTimestamp(fixture.userId);
        var afterPreferenceRead = loadGettingStartedPreference(fixture.userId);

        expectOrderedKeys(
          state,
          [
            "autoOpenWelcome",
            "acknowledgedAt",
            "gettingStartedHidden",
            "messageState",
            "welcomeMessage",
            "checklist",
            "continueTarget"
          ]
        );
        expectOrderedKeys(
          state.checklist,
          [
            "vessel",
            "contact",
            "passengers",
            "operator",
            "waypoints",
            "savedWaypointCount",
            "requiredWaypointCount",
            "remainingWaypointCount",
            "firstIncompleteStep",
            "allComplete"
          ]
        );
        expectOrderedKeys(
          state.continueTarget,
          ["action"]
        );

        expect(state.autoOpenWelcome).toBeTrue();
        expect(isNull(state.acknowledgedAt)).toBeTrue();
        expect(state.gettingStartedHidden).toBeFalse();
        expect(state.checklist.vessel).toBeFalse();
        expect(state.checklist.contact).toBeFalse();
        expect(state.checklist.passengers).toBeFalse();
        expect(state.checklist.operator).toBeFalse();
        expect(state.checklist.waypoints).toBeFalse();
        expect(state.checklist.savedWaypointCount).toBe(0);
        expect(state.checklist.requiredWaypointCount).toBe(2);
        expect(state.checklist.remainingWaypointCount).toBe(2);
        expect(state.checklist.firstIncompleteStep).toBe("vessel");
        expect(state.checklist.allComplete).toBeFalse();
        expect(state.continueTarget.action).toBe("add-vessel");
        expect(val(beforeRead.timestamp_is_null[1])).toBe(1);
        expect(val(afterRead.timestamp_is_null[1])).toBe(1);
        expect(val(beforePreferenceRead.preference_is_null[1])).toBe(1);
        expect(val(afterPreferenceRead.preference_is_null[1])).toBe(1);
      });

      it("stores the first acknowledgment once and scopes it to one member", function() {
        var fixture = createFixture("acknowledge");
        var other = createFixture("acknowledge-other");
        var invalidResult = variables.onboardingService.acknowledgeWelcome(0);
        var firstResult = variables.onboardingService.acknowledgeWelcome(
          fixture.userId
        );
        var firstStored = loadOnboardingTimestamp(fixture.userId);
        var secondResult = variables.onboardingService.acknowledgeWelcome(
          fixture.userId
        );
        var secondStored = loadOnboardingTimestamp(fixture.userId);
        var otherStored = loadOnboardingTimestamp(other.userId);
        var acknowledgedState = variables.onboardingService.getState(
          fixture.userId
        );

        expect(invalidResult.SUCCESS).toBeFalse();
        expect(invalidResult.ERROR).toBe("INVALID_USER_ID");
        expect(firstResult.SUCCESS).toBeTrue();
        expect(secondResult.SUCCESS).toBeTrue();
        expect(val(firstStored.timestamp_is_null[1])).toBe(0);
        expect(val(secondStored.timestamp_is_null[1])).toBe(0);
        expect(toString(secondStored.timestamp_value[1])).toBe(
          toString(firstStored.timestamp_value[1])
        );
        expect(toString(secondResult.acknowledgedAt)).toBe(
          toString(firstResult.acknowledgedAt)
        );
        expect(val(otherStored.timestamp_is_null[1])).toBe(1);
        expect(acknowledgedState.autoOpenWelcome).toBeFalse();
        expect(len(toString(acknowledgedState.acknowledgedAt)) GT 0).toBeTrue();
      });

      it("protects a pre-acknowledged existing fixture from automatic opening", function() {
        var fixture = createFixture("existing");
        var state = {};

        queryExecute(
          "UPDATE users
           SET welcomeOnboardingSeenAt = UTC_TIMESTAMP(6)
           WHERE userId = :userId",
          {
            userId = {
              value = fixture.userId,
              cfsqltype = "cf_sql_integer"
            }
          },
          { datasource = variables.datasource }
        );

        state = variables.onboardingService.getState(fixture.userId);
        expect(state.autoOpenWelcome).toBeFalse();
        expect(len(toString(state.acknowledgedAt)) GT 0).toBeTrue();
        expect(state.checklist.firstIncompleteStep).toBe("vessel");
        expect(state.continueTarget.action).toBe("add-vessel");
      });

      it("advances through the required route setup steps without requiring passengers", function() {
        var fixture = createFixture("route-setup-progression");
        var initialCounts = loadPlanRouteCounts(fixture.userId);
        var initialState = variables.onboardingService.getState(fixture.userId);
        var vesselState = {};
        var contactState = {};
        var operatorState = {};
        var oneWaypointState = {};
        var completeState = {};
        var afterReadCounts = queryNew("");

        expect(initialState.checklist.firstIncompleteStep).toBe("vessel");
        expect(initialState.continueTarget.action).toBe("add-vessel");
        expect(initialState.gettingStartedHidden).toBeFalse();

        addVessel(fixture);
        vesselState = variables.onboardingService.getState(fixture.userId);
        expect(vesselState.checklist.vessel).toBeTrue();
        expect(vesselState.checklist.contact).toBeFalse();
        expect(vesselState.checklist.firstIncompleteStep).toBe("contact");
        expect(vesselState.continueTarget.action).toBe("add-contact");
        expect(vesselState.gettingStartedHidden).toBeFalse();

        addContact(fixture);
        contactState = variables.onboardingService.getState(fixture.userId);
        expect(contactState.checklist.contact).toBeTrue();
        expect(contactState.checklist.passengers).toBeFalse();
        expect(contactState.checklist.firstIncompleteStep).toBe("operator");
        expect(contactState.continueTarget.action).toBe("add-operator");
        expect(contactState.gettingStartedHidden).toBeFalse();

        addOperator(fixture);
        operatorState = variables.onboardingService.getState(fixture.userId);
        expect(operatorState.checklist.operator).toBeTrue();
        expect(operatorState.checklist.waypoints).toBeFalse();
        expect(operatorState.checklist.savedWaypointCount).toBe(0);
        expect(operatorState.checklist.requiredWaypointCount).toBe(2);
        expect(operatorState.checklist.remainingWaypointCount).toBe(2);
        expect(operatorState.checklist.firstIncompleteStep).toBe("waypoints");
        expect(operatorState.continueTarget.action).toBe("add-waypoint");
        expect(operatorState.gettingStartedHidden).toBeFalse();

        addWaypoint(fixture, "shared-name");
        oneWaypointState = variables.onboardingService.getState(fixture.userId);
        expect(oneWaypointState.checklist.waypoints).toBeFalse();
        expect(oneWaypointState.checklist.savedWaypointCount).toBe(1);
        expect(oneWaypointState.checklist.requiredWaypointCount).toBe(2);
        expect(oneWaypointState.checklist.remainingWaypointCount).toBe(1);
        expect(oneWaypointState.checklist.firstIncompleteStep).toBe("waypoints");
        expect(oneWaypointState.continueTarget.action).toBe("add-waypoint");
        expect(oneWaypointState.gettingStartedHidden).toBeFalse();

        addWaypoint(fixture, "shared-name");
        completeState = variables.onboardingService.getState(fixture.userId);
        expect(completeState.checklist.vessel).toBeTrue();
        expect(completeState.checklist.contact).toBeTrue();
        expect(completeState.checklist.passengers).toBeFalse();
        expect(completeState.checklist.operator).toBeTrue();
        expect(completeState.checklist.waypoints).toBeTrue();
        expect(completeState.checklist.savedWaypointCount).toBe(2);
        expect(completeState.checklist.requiredWaypointCount).toBe(2);
        expect(completeState.checklist.remainingWaypointCount).toBe(0);
        expect(completeState.checklist.firstIncompleteStep).toBe("complete");
        expect(completeState.checklist.allComplete).toBeTrue();
        expect(completeState.continueTarget.action).toBe("create-route");
        expect(completeState.gettingStartedHidden).toBeTrue();
        expect(
          val(loadGettingStartedPreference(fixture.userId).preference_is_null[1])
        ).toBe(1);

        afterReadCounts = loadPlanRouteCounts(fixture.userId);
        expect(val(initialCounts.plan_count[1])).toBe(0);
        expect(val(afterReadCounts.plan_count[1])).toBe(0);
        expect(val(initialCounts.route_instance_count[1])).toBe(0);
        expect(val(afterReadCounts.route_instance_count[1])).toBe(0);
      });

      it("reports optional passenger state without changing required readiness", function() {
        var noPassenger = createFixture("passenger-optional-none");
        var passengerWithoutOperator = createFixture("passenger-optional-missing-operator");
        var noPassengerState = {};
        var missingOperatorState = {};
        var passengerState = {};

        addVessel(noPassenger);
        addContact(noPassenger);
        addOperator(noPassenger);
        addWaypoint(noPassenger, "no-passenger-start");
        addWaypoint(noPassenger, "no-passenger-destination");
        noPassengerState = variables.onboardingService.getState(noPassenger.userId);

        expect(noPassengerState.checklist.passengers).toBeFalse();
        expect(noPassengerState.checklist.allComplete).toBeTrue();
        expect(noPassengerState.checklist.firstIncompleteStep).toBe("complete");
        expect(noPassengerState.continueTarget.action).toBe("create-route");

        addVessel(passengerWithoutOperator);
        addContact(passengerWithoutOperator);
        addPassenger(passengerWithoutOperator);
        addWaypoint(passengerWithoutOperator, "passenger-start");
        addWaypoint(passengerWithoutOperator, "passenger-destination");
        missingOperatorState = variables.onboardingService.getState(
          passengerWithoutOperator.userId
        );

        expect(missingOperatorState.checklist.passengers).toBeTrue();
        expect(missingOperatorState.checklist.operator).toBeFalse();
        expect(missingOperatorState.checklist.allComplete).toBeFalse();
        expect(missingOperatorState.checklist.firstIncompleteStep).toBe("operator");
        expect(missingOperatorState.continueTarget.action).toBe("add-operator");

        addOperator(passengerWithoutOperator);
        passengerState = variables.onboardingService.getState(
          passengerWithoutOperator.userId
        );
        expect(passengerState.checklist.passengers).toBeTrue();
        expect(passengerState.checklist.allComplete).toBeTrue();
        expect(passengerState.checklist.firstIncompleteStep).toBe("complete");
        expect(passengerState.continueTarget.action).toBe("create-route");
      });

      it("persists explicit Getting Started hide and show choices per member", function() {
        var fixture = createFixture("visibility-preference");
        var other = createFixture("visibility-preference-other");
        var initialPreference = loadGettingStartedPreference(fixture.userId);
        var otherInitialPreference = loadGettingStartedPreference(other.userId);
        var invalidResult = variables.onboardingService.setGettingStartedHidden(
          0,
          true
        );
        var missingResult = variables.onboardingService.setGettingStartedHidden(
          2147483647,
          true
        );
        var hideResult = variables.onboardingService.setGettingStartedHidden(
          fixture.userId,
          true
        );
        var hiddenState = variables.onboardingService.getState(fixture.userId);
        var hiddenPreference = loadGettingStartedPreference(fixture.userId);
        var repeatedHideResult = variables.onboardingService.setGettingStartedHidden(
          fixture.userId,
          true
        );
        var showResult = variables.onboardingService.setGettingStartedHidden(
          fixture.userId,
          false
        );
        var shownPreference = loadGettingStartedPreference(fixture.userId);
        var freshService = createObject(
          "component",
          "fpw.api.v1.OnboardingService"
        ).init(variables.datasource);
        var shownState = freshService.getState(fixture.userId);
        var otherState = freshService.getState(other.userId);
        var fixtureAcknowledgment = loadOnboardingTimestamp(fixture.userId);
        var otherAcknowledgment = loadOnboardingTimestamp(other.userId);

        expect(val(initialPreference.preference_is_null[1])).toBe(1);
        expect(val(otherInitialPreference.preference_is_null[1])).toBe(1);
        expect(invalidResult.SUCCESS).toBeFalse();
        expect(invalidResult.ERROR).toBe("INVALID_USER_ID");
        expect(missingResult.SUCCESS).toBeFalse();
        expect(missingResult.ERROR).toBe("PREFERENCE_SAVE_FAILED");
        expect(hideResult.SUCCESS).toBeTrue();
        expect(hideResult.gettingStartedHidden).toBeTrue();
        expect(hiddenState.gettingStartedHidden).toBeTrue();
        expect(hiddenState.checklist.allComplete).toBeFalse();
        expect(val(hiddenPreference.preference_is_null[1])).toBe(0);
        expect(val(hiddenPreference.preference_value[1])).toBe(1);
        expect(repeatedHideResult.SUCCESS).toBeTrue();
        expect(showResult.SUCCESS).toBeTrue();
        expect(showResult.gettingStartedHidden).toBeFalse();
        expect(val(shownPreference.preference_is_null[1])).toBe(0);
        expect(val(shownPreference.preference_value[1])).toBe(0);
        expect(shownState.gettingStartedHidden).toBeFalse();
        expect(shownState.checklist.allComplete).toBeFalse();
        expect(otherState.gettingStartedHidden).toBeFalse();
        expect(
          val(
            loadGettingStartedPreference(other.userId).preference_is_null[1]
          )
        ).toBe(1);
        expect(val(fixtureAcknowledgment.timestamp_is_null[1])).toBe(1);
        expect(val(otherAcknowledgment.timestamp_is_null[1])).toBe(1);
      });

      it("keeps an explicit Show choice after route setup becomes complete", function() {
        var explicitFixture = createFixture("visibility-complete-explicit");
        var automaticFixture = createFixture("visibility-complete-automatic");
        var explicitShowResult = variables.onboardingService.setGettingStartedHidden(
          explicitFixture.userId,
          false
        );
        var explicitState = {};
        var automaticState = {};
        var automaticHideResult = {};
        var automaticShowResult = {};
        var freshService = {};

        addVessel(explicitFixture);
        addContact(explicitFixture);
        addPassenger(explicitFixture);
        addOperator(explicitFixture);
        addWaypoint(explicitFixture, "explicit-start");
        addWaypoint(explicitFixture, "explicit-destination");

        addVessel(automaticFixture);
        addContact(automaticFixture);
        addPassenger(automaticFixture);
        addOperator(automaticFixture);
        addWaypoint(automaticFixture, "automatic-start");
        addWaypoint(automaticFixture, "automatic-destination");

        explicitState = variables.onboardingService.getState(
          explicitFixture.userId
        );
        automaticState = variables.onboardingService.getState(
          automaticFixture.userId
        );

        expect(explicitShowResult.SUCCESS).toBeTrue();
        expect(explicitState.checklist.allComplete).toBeTrue();
        expect(explicitState.gettingStartedHidden).toBeFalse();
        expect(
          val(
            loadGettingStartedPreference(
              explicitFixture.userId
            ).preference_value[1]
          )
        ).toBe(0);
        expect(automaticState.checklist.allComplete).toBeTrue();
        expect(automaticState.gettingStartedHidden).toBeTrue();
        expect(
          val(
            loadGettingStartedPreference(
              automaticFixture.userId
            ).preference_is_null[1]
          )
        ).toBe(1);

        automaticHideResult = variables.onboardingService.setGettingStartedHidden(
          automaticFixture.userId,
          true
        );
        automaticShowResult = variables.onboardingService.setGettingStartedHidden(
          automaticFixture.userId,
          false
        );
        freshService = createObject(
          "component",
          "fpw.api.v1.OnboardingService"
        ).init(variables.datasource);
        automaticState = freshService.getState(automaticFixture.userId);

        expect(automaticHideResult.SUCCESS).toBeTrue();
        expect(automaticShowResult.SUCCESS).toBeTrue();
        expect(automaticState.checklist.allComplete).toBeTrue();
        expect(automaticState.gettingStartedHidden).toBeFalse();
        expect(
          val(
            loadGettingStartedPreference(
              automaticFixture.userId
            ).preference_value[1]
          )
        ).toBe(0);
      });

      it("ignores one-time Basic details and all Float Plan state for route setup", function() {
        var fixture = createFixture("basic-plan-independence");
        var plan = createBasicPlan(fixture, "one-time-contact");
        var state = variables.onboardingService.getState(fixture.userId);

        expect(plan.floatPlanId GT 0).toBeTrue();
        expect(state.checklist.vessel).toBeFalse();
        expect(state.checklist.contact).toBeFalse();
        expect(state.checklist.passengers).toBeFalse();
        expect(state.checklist.operator).toBeFalse();
        expect(state.checklist.waypoints).toBeFalse();
        expect(state.checklist.savedWaypointCount).toBe(0);
        expect(state.checklist.firstIncompleteStep).toBe("vessel");
        expect(state.continueTarget.action).toBe("add-vessel");
        expect(structKeyExists(state.checklist, "trip")).toBeFalse();
        expect(structKeyExists(state.checklist, "schedule")).toBeFalse();
        expect(structKeyExists(state.checklist, "share")).toBeFalse();
        expect(structKeyExists(state.continueTarget, "floatPlanId")).toBeFalse();
        expect(structKeyExists(state.continueTarget, "startStep")).toBeFalse();
      });

      it("counts only route setup records owned by the authenticated member", function() {
        var fixture = createFixture("ownership");
        var other = createFixture("ownership-other");
        var state = {};

        addVessel(other);
        addContact(other);
        addPassenger(other);
        addOperator(other);
        addWaypoint(other, "other-start");
        addWaypoint(other, "other-destination");

        state = variables.onboardingService.getState(fixture.userId);
        expect(state.checklist.vessel).toBeFalse();
        expect(state.checklist.contact).toBeFalse();
        expect(state.checklist.passengers).toBeFalse();
        expect(state.checklist.operator).toBeFalse();
        expect(state.checklist.waypoints).toBeFalse();
        expect(state.checklist.savedWaypointCount).toBe(0);
        expect(state.checklist.requiredWaypointCount).toBe(2);
        expect(state.checklist.remainingWaypointCount).toBe(2);
        expect(state.checklist.firstIncompleteStep).toBe("vessel");
        expect(state.checklist.allComplete).toBeFalse();
        expect(state.continueTarget.action).toBe("add-vessel");
      });

      it("derives every welcome message from canonical credit state without mutation", function() {
        var fixture = createFixture("credit-messages");
        var basicState = variables.onboardingService.getState(fixture.userId);
        var complimentaryGrant = {};
        var complimentaryState = {};
        var plan = {};
        var consumed = {};
        var qBeforeConsumedRead = queryNew("");
        var consumedState = {};
        var qAfterConsumedRead = queryNew("");
        var paidGrant = {};
        var paidState = {};

        expect(basicState.messageState).toBe("basic_available");
        expect(findNoCase("Basic float plans", basicState.welcomeMessage) GT 0)
          .toBeTrue();

        complimentaryGrant = variables.creditService.grantCredit(
          userId = fixture.userId,
          source = "complimentary_signup",
          idempotencyKey = fixture.marker & ":complimentary"
        );
        complimentaryState = variables.onboardingService.getState(
          fixture.userId
        );
        expect(complimentaryGrant.SUCCESS).toBeTrue();
        expect(complimentaryState.messageState).toBe(
          "complimentary_available"
        );
        expect(complimentaryState.welcomeMessage).toBe(
          "Your first Premium trip is complimentary."
        );

        plan = createPremiumPlan(fixture, "credit-consumption");
        setPlanActive(plan.floatPlanId);
        consumed = variables.creditService.consumeLockedCredit(
          creditId = complimentaryGrant.creditId,
          userId = fixture.userId,
          floatPlanId = plan.floatPlanId
        );
        expect(consumed.SUCCESS).toBeTrue();

        qBeforeConsumedRead = loadCreditFingerprint(fixture.userId);
        consumedState = variables.onboardingService.getState(fixture.userId);
        qAfterConsumedRead = loadCreditFingerprint(fixture.userId);
        expect(consumedState.messageState).toBe("complimentary_consumed");
        expect(
          findNoCase(
            "complimentary Premium trip has been used",
            consumedState.welcomeMessage
          ) GT 0
        ).toBeTrue();
        expect(
          findNoCase(
            "Basic float plans can still be sent",
            consumedState.welcomeMessage
          ) GT 0
        ).toBeTrue();
        expect(toString(qAfterConsumedRead.credit_fingerprint[1])).toBe(
          toString(qBeforeConsumedRead.credit_fingerprint[1])
        );

        paidGrant = variables.creditService.grantCredit(
          userId = fixture.userId,
          source = "stripe_one_trip",
          idempotencyKey = fixture.marker & ":paid"
        );
        paidState = variables.onboardingService.getState(fixture.userId);
        expect(paidGrant.SUCCESS).toBeTrue();
        expect(paidState.messageState).toBe("premium_available");
        expect(paidState.welcomeMessage).toBe(
          "Premium trip sharing is available for your account."
        );
      });

    });
  }

  private void function expectOrderedKeys(
    required struct actual,
    required array expectedKeys
  ) {
    expect(arrayToList(structKeyArray(arguments.actual), "|")).toBe(
      arrayToList(arguments.expectedKeys, "|")
    );
  }

  private struct function createFixture(required string label) {
    var token = lCase(replace(createUUID(), "-", "", "all"));
    var marker = variables.fixtureEmailPrefix & token;
    var email = marker & "@example.test";
    var qUser = queryNew("");

    queryExecute(
      "INSERT INTO users (
         fName,
         lName,
         email,
         password,
         passwordCreated,
         created
       ) VALUES (
         :firstName,
         :lastName,
         :email,
         :password,
         UTC_TIMESTAMP(),
         UTC_TIMESTAMP()
       )",
      {
        firstName = {
          value = "Codex Welcome",
          cfsqltype = "cf_sql_varchar"
        },
        lastName = {
          value = left(arguments.label & " Contract", 45),
          cfsqltype = "cf_sql_varchar"
        },
        email = {
          value = email,
          cfsqltype = "cf_sql_varchar"
        },
        password = {
          value = hash("not-a-login-" & token, "SHA-256"),
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );

    qUser = queryExecute(
      "SELECT userId
       FROM users
       WHERE email = :email
       LIMIT 1",
      {
        email = {
          value = email,
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );
    if (qUser.recordCount NEQ 1) {
      throw(
        type = "FPW.WelcomeOnboardingFixture",
        message = "Disposable Welcome Onboarding user was not created."
      );
    }

    return {
      marker = marker,
      email = email,
      userId = val(qUser.userId[1])
    };
  }

  private void function addVessel(required struct fixture) {
    queryExecute(
      "INSERT INTO vessels (
         userId,
         vesselName,
         hailingPort,
         isDefaultVessel
       ) VALUES (
         :userId,
         :vesselName,
         'Test Harbor',
         1
       )",
      {
        userId = {
          value = toString(arguments.fixture.userId),
          cfsqltype = "cf_sql_varchar"
        },
        vesselName = {
          value = left(arguments.fixture.marker, 255),
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );
  }

  private void function addContact(required struct fixture) {
    queryExecute(
      "INSERT INTO contacts (
         name,
         phone,
         userId,
         email
       ) VALUES (
         'Codex Shore Contact',
         '202-555-0100',
         :userId,
         :email
       )",
      {
        userId = {
          value = toString(arguments.fixture.userId),
          cfsqltype = "cf_sql_varchar"
        },
        email = {
          value = "shore-" & arguments.fixture.email,
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );
  }

  private void function addPassenger(required struct fixture) {
    queryExecute(
      "INSERT INTO passengers (
         userId,
         name,
         phone,
         age,
         gender,
         notes,
         pfd
       ) VALUES (
         :userId,
         :name,
         '',
         '',
         '',
         '',
         1
       )",
      {
        userId = {
          value = toString(arguments.fixture.userId),
          cfsqltype = "cf_sql_varchar"
        },
        name = {
          value = left(arguments.fixture.marker & "-passenger", 255),
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );
  }

  private void function addOperator(required struct fixture) {
    queryExecute(
      "INSERT INTO operators (
         userId,
         name,
         homePhone,
         notes
       ) VALUES (
         :userId,
         :name,
         '',
         ''
       )",
      {
        userId = {
          value = toString(arguments.fixture.userId),
          cfsqltype = "cf_sql_varchar"
        },
        name = {
          value = left(arguments.fixture.marker & "-operator", 255),
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );
  }

  private void function addWaypoint(
    required struct fixture,
    required string label
  ) {
    queryExecute(
      "INSERT INTO waypoints (
         userId,
         name,
         latitude,
         longitude,
         notes
       ) VALUES (
         :userId,
         :name,
         '',
         '',
         ''
       )",
      {
        userId = {
          value = toString(arguments.fixture.userId),
          cfsqltype = "cf_sql_varchar"
        },
        name = {
          value = left(
            arguments.fixture.marker & "-" & arguments.label,
            255
          ),
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );
  }

  private struct function createBasicPlan(
    required struct fixture,
    required string label
  ) {
    var planName = left(
      arguments.fixture.marker & "-" & arguments.label,
      255
    );
    var qPlan = queryNew("");
    var planId = 0;

    queryExecute(
      "INSERT INTO floatplans (
         userId,
         floatPlanName,
         dateCreated,
         lastUpdate,
         status,
         lastUpdateStatus,
         route_origin,
         is_reusable,
         is_visible_in_route_library
       ) VALUES (
         :userId,
         :planName,
         UTC_TIMESTAMP(),
         UTC_TIMESTAMP(),
         'DRAFT',
         UTC_TIMESTAMP(),
         'basic_float_plan',
         0,
         0
       )",
      {
        userId = {
          value = toString(arguments.fixture.userId),
          cfsqltype = "cf_sql_varchar"
        },
        planName = {
          value = planName,
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );
    qPlan = queryExecute(
      "SELECT floatPlanId
       FROM floatplans
       WHERE userId = :userId
         AND floatPlanName = :planName
       ORDER BY floatPlanId DESC
       LIMIT 1",
      {
        userId = {
          value = toString(arguments.fixture.userId),
          cfsqltype = "cf_sql_varchar"
        },
        planName = {
          value = planName,
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );
    planId = val(qPlan.floatPlanId[1]);

    queryExecute(
      "INSERT INTO floatplan_basic_details (
         floatplan_id,
         vessel_name,
         operator_name,
         captain_name,
         captain_email,
         notification_contact_name,
         notification_contact_email,
         notification_contact_phone,
         launch_location,
         destination_location,
         authority_name_snapshot,
         authority_phone_snapshot
       ) VALUES (
         :floatPlanId,
         'Codex Test Vessel',
         'Codex Test Operator',
         'Codex Test Captain',
         :captainEmail,
         'Codex Shore Contact',
         :contactEmail,
         '202-555-0100',
         'Test Launch',
         'Test Destination',
         'Test Rescue Authority',
         '555-0199'
       )",
      {
        floatPlanId = {
          value = planId,
          cfsqltype = "cf_sql_integer"
        },
        captainEmail = {
          value = arguments.fixture.email,
          cfsqltype = "cf_sql_varchar"
        },
        contactEmail = {
          value = "shore-" & arguments.fixture.email,
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );

    return {
      floatPlanId = planId,
      routeInstanceId = 0,
      routeId = 0,
      kind = "basic"
    };
  }

  private struct function createPremiumPlan(
    required struct fixture,
    required string label
  ) {
    var routeCode = left(
      variables.fixtureEmailPrefix
        & lCase(hash(
          arguments.fixture.marker & "-" & arguments.label,
          "SHA-256"
        )),
      40
    );
    var planName = left(
      arguments.fixture.marker & "-" & arguments.label,
      255
    );
    var qRoute = queryNew("");
    var qInstance = queryNew("");
    var qPlan = queryNew("");
    var routeId = 0;
    var routeInstanceId = 0;
    var planId = 0;

    queryExecute(
      "INSERT INTO loop_routes (
         code,
         name,
         short_code,
         is_active,
         version,
         is_default
       ) VALUES (
         :routeCode,
         :routeName,
         :routeCode,
         0,
         1,
         0
       )",
      {
        routeCode = {
          value = routeCode,
          cfsqltype = "cf_sql_varchar"
        },
        routeName = {
          value = planName,
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );
    qRoute = queryExecute(
      "SELECT id
       FROM loop_routes
       WHERE short_code = :routeCode
       LIMIT 1",
      {
        routeCode = {
          value = routeCode,
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );
    routeId = val(qRoute.id[1]);

    queryExecute(
      "INSERT INTO route_instances (
         user_id,
         template_route_code,
         generated_route_id,
         generated_route_code,
         direction,
         trip_type,
         start_location,
         end_location,
         status
       ) VALUES (
         :userId,
         :routeCode,
         :routeId,
         :routeCode,
         'CCW',
         'POINT_TO_POINT',
         'Test Start',
         'Test Finish',
         'PLANNED'
       )",
      {
        userId = {
          value = toString(arguments.fixture.userId),
          cfsqltype = "cf_sql_varchar"
        },
        routeCode = {
          value = routeCode,
          cfsqltype = "cf_sql_varchar"
        },
        routeId = {
          value = routeId,
          cfsqltype = "cf_sql_integer"
        }
      },
      { datasource = variables.datasource }
    );
    qInstance = queryExecute(
      "SELECT id
       FROM route_instances
       WHERE generated_route_id = :routeId
       LIMIT 1",
      {
        routeId = {
          value = routeId,
          cfsqltype = "cf_sql_integer"
        }
      },
      { datasource = variables.datasource }
    );
    routeInstanceId = val(qInstance.id[1]);

    queryExecute(
      "INSERT INTO floatplans (
         userId,
         floatPlanName,
         dateCreated,
         lastUpdate,
         departing,
         `returning`,
         status,
         lastUpdateStatus,
         route_instance_id,
         route_origin,
         is_reusable,
         is_visible_in_route_library
       ) VALUES (
         :userId,
         :planName,
         UTC_TIMESTAMP(),
         UTC_TIMESTAMP(),
         'Test Start',
         'Test Finish',
         'DRAFT',
         UTC_TIMESTAMP(),
         :routeInstanceId,
         'premium_saved_route',
         1,
         1
       )",
      {
        userId = {
          value = toString(arguments.fixture.userId),
          cfsqltype = "cf_sql_varchar"
        },
        planName = {
          value = planName,
          cfsqltype = "cf_sql_varchar"
        },
        routeInstanceId = {
          value = routeInstanceId,
          cfsqltype = "cf_sql_integer"
        }
      },
      { datasource = variables.datasource }
    );
    qPlan = queryExecute(
      "SELECT floatPlanId
       FROM floatplans
       WHERE userId = :userId
         AND floatPlanName = :planName
       ORDER BY floatPlanId DESC
       LIMIT 1",
      {
        userId = {
          value = toString(arguments.fixture.userId),
          cfsqltype = "cf_sql_varchar"
        },
        planName = {
          value = planName,
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );
    planId = val(qPlan.floatPlanId[1]);

    return {
      floatPlanId = planId,
      routeInstanceId = routeInstanceId,
      routeId = routeId,
      kind = "premium"
    };
  }

  private void function setPlanActive(required numeric floatPlanId) {
    queryExecute(
      "UPDATE floatplans
       SET status = 'ACTIVE',
           activatedAt = UTC_TIMESTAMP(),
           lastUpdate = UTC_TIMESTAMP(),
           lastUpdateStatus = UTC_TIMESTAMP()
       WHERE floatPlanId = :floatPlanId",
      {
        floatPlanId = {
          value = arguments.floatPlanId,
          cfsqltype = "cf_sql_integer"
        }
      },
      { datasource = variables.datasource }
    );
  }

  private query function loadPlanRouteCounts(required numeric userId) {
    return queryExecute(
      "SELECT
          (
            SELECT COUNT(*)
            FROM floatplans
            WHERE userId = :userIdText
          ) AS plan_count,
          (
            SELECT COUNT(*)
            FROM route_instances
            WHERE CAST(user_id AS UNSIGNED) = :userId
          ) AS route_instance_count",
      {
        userIdText = {
          value = toString(arguments.userId),
          cfsqltype = "cf_sql_varchar"
        },
        userId = {
          value = arguments.userId,
          cfsqltype = "cf_sql_integer"
        }
      },
      { datasource = variables.datasource }
    );
  }

  private query function loadOnboardingTimestamp(required numeric userId) {
    return queryExecute(
      "SELECT
          (welcomeOnboardingSeenAt IS NULL) AS timestamp_is_null,
          DATE_FORMAT(
            welcomeOnboardingSeenAt,
            '%Y-%m-%d %H:%i:%s.%f'
          ) AS timestamp_value
       FROM users
       WHERE userId = :userId
       LIMIT 1",
      {
        userId = {
          value = arguments.userId,
          cfsqltype = "cf_sql_integer"
        }
      },
      { datasource = variables.datasource }
    );
  }

  private query function loadGettingStartedPreference(
    required numeric userId
  ) {
    return queryExecute(
      "SELECT
          (gettingStartedHidden IS NULL) AS preference_is_null,
          COALESCE(gettingStartedHidden, -1) AS preference_value
       FROM users
       WHERE userId = :userId
       LIMIT 1",
      {
        userId = {
          value = arguments.userId,
          cfsqltype = "cf_sql_integer"
        }
      },
      { datasource = variables.datasource }
    );
  }

  private query function loadCreditFingerprint(required numeric userId) {
    return queryExecute(
      "SELECT MD5(
          COALESCE(
            GROUP_CONCAT(
              CONCAT_WS(
                '|',
                id,
                source,
                status,
                COALESCE(consumed_float_plan_id, 0),
                COALESCE(
                  DATE_FORMAT(consumed_at_utc, '%Y-%m-%d %H:%i:%s.%f'),
                  ''
                ),
                DATE_FORMAT(updated_at_utc, '%Y-%m-%d %H:%i:%s.%f')
              )
              ORDER BY id
              SEPARATOR '||'
            ),
            ''
          )
        ) AS credit_fingerprint
       FROM premium_send_credits
       WHERE user_id = :userId",
      {
        userId = {
          value = arguments.userId,
          cfsqltype = "cf_sql_integer"
        }
      },
      { datasource = variables.datasource }
    );
  }

  private void function cleanupFixtures() {
    var emailPattern = variables.fixtureEmailPrefix & "%";
    var routePattern = variables.fixtureEmailPrefix & "%";
    var params = {
      emailPattern = {
        value = emailPattern,
        cfsqltype = "cf_sql_varchar"
      }
    };

    queryExecute(
      "DELETE FROM premium_send_receipts
       WHERE user_id IN (
         SELECT userId FROM users WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM premium_send_credits
       WHERE user_id IN (
         SELECT userId FROM users WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM premium_trip_entitlement_events
       WHERE user_id IN (
         SELECT userId FROM users WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM premium_trip_creation_sessions
       WHERE user_id IN (
         SELECT userId FROM users WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM member_premium_trip_entitlements
       WHERE user_id IN (
         SELECT userId FROM users WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM member_entitlements
       WHERE user_id IN (
         SELECT userId FROM users WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM stripe_webhook_events
       WHERE user_id IN (
         SELECT userId FROM users WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM user_stripe_customers
       WHERE user_id IN (
         SELECT userId FROM users WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM product_events
       WHERE user_id IN (
         SELECT userId FROM users WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM route_instance_leg_progress
       WHERE route_instance_id IN (
         SELECT id
         FROM route_instances
         WHERE CAST(user_id AS UNSIGNED) IN (
           SELECT userId
           FROM users
           WHERE email LIKE :emailPattern
         )
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM route_instance_legs
       WHERE route_instance_id IN (
         SELECT id
         FROM route_instances
         WHERE CAST(user_id AS UNSIGNED) IN (
           SELECT userId
           FROM users
           WHERE email LIKE :emailPattern
         )
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM route_instance_sections
       WHERE route_instance_id IN (
         SELECT id
         FROM route_instances
         WHERE CAST(user_id AS UNSIGNED) IN (
           SELECT userId
           FROM users
           WHERE email LIKE :emailPattern
         )
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM floatplan_basic_details
       WHERE floatplan_id IN (
         SELECT floatPlanId
         FROM floatplans
         WHERE CAST(userId AS UNSIGNED) IN (
           SELECT userId
           FROM users
           WHERE email LIKE :emailPattern
         )
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM floatplans
       WHERE CAST(userId AS UNSIGNED) IN (
         SELECT userId
         FROM users
         WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM route_instances
       WHERE CAST(user_id AS UNSIGNED) IN (
         SELECT userId
         FROM users
         WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM loop_routes
       WHERE code LIKE :routePattern",
      {
        routePattern = {
          value = routePattern,
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE vi
       FROM vessel_images vi
       INNER JOIN vessels v ON v.vesselID = vi.vessel_id
       INNER JOIN users u ON CAST(u.userId AS CHAR) = v.userId
       WHERE u.email LIKE :emailPattern",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM waypoints
       WHERE CAST(userId AS UNSIGNED) IN (
         SELECT userId
         FROM users
         WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM operators
       WHERE CAST(userId AS UNSIGNED) IN (
         SELECT userId
         FROM users
         WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM passengers
       WHERE CAST(userId AS UNSIGNED) IN (
         SELECT userId
         FROM users
         WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM contacts
       WHERE CAST(userId AS UNSIGNED) IN (
         SELECT userId
         FROM users
         WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM vessels
       WHERE CAST(userId AS UNSIGNED) IN (
         SELECT userId
         FROM users
         WHERE email LIKE :emailPattern
       )",
      params,
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM users
       WHERE email LIKE :emailPattern",
      params,
      { datasource = variables.datasource }
    );
  }

}
