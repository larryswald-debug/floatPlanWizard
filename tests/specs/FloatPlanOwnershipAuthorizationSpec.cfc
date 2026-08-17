component extends="testbox.system.BaseSpec" output="false" {

  variables.datasource = "fpw";
  variables.fixtureEmailPrefix = "codex-floatplan-ownership-";

  function beforeAll() {
    cleanupFixtures();
  }

  function afterAll() {
    cleanupFixtures();
  }

  function run() {
    describe("Float Plan ownership authorization contract", function() {

      beforeEach(function() {
        cleanupFixtures();
        variables.fixture = createFixture();
        variables.floatPlanService = createObject("component", "fpw.api.v1.floatplan");
        makePublic(variables.floatPlanService, "getBootstrapData", "getBootstrapDataForTest");
        makePublic(variables.floatPlanService, "loadFloatPlan", "loadFloatPlanForTest");
        makePublic(variables.floatPlanService, "loadPlanSelections", "loadPlanSelectionsForTest");
        makePublic(variables.floatPlanService, "sendFloatPlanToContacts", "sendFloatPlanToContactsForTest");
      });

      afterEach(function() {
        cleanupFixtures();
      });

      it("rejects a cross-user bootstrap without returning plan or selection data", function() {
        var result = variables.floatPlanService.getBootstrapDataForTest(
          variables.fixture.userBId,
          variables.fixture.floatPlanId
        );

        expect(result.SUCCESS).toBeFalse();
        expect(result.ERROR).toBe("PLAN_NOT_FOUND");
        expect(structKeyExists(result, "FLOATPLAN")).toBeFalse();
        expect(structKeyExists(result, "PLAN_CONTACTS")).toBeFalse();
        expect(structKeyExists(result, "PLAN_PASSENGERS")).toBeFalse();
        expect(structKeyExists(result, "PLAN_WAYPOINTS")).toBeFalse();
        expect(structKeyExists(result, "ROUTE_DEFAULTS")).toBeFalse();
      });

      it("loads an owned plan and its exact saved selections", function() {
        var result = variables.floatPlanService.getBootstrapDataForTest(
          variables.fixture.userAId,
          variables.fixture.floatPlanId
        );

        expect(result.FLOATPLAN.FLOATPLANID).toBe(variables.fixture.floatPlanId);
        expect(result.FLOATPLAN.USERID).toBe(toString(variables.fixture.userAId));
        expect(result.FLOATPLAN.VESSELID).toBe(variables.fixture.vesselId);
        expect(result.FLOATPLAN.OPERATORID).toBe(variables.fixture.operatorId);
        expect(arrayLen(result.PLAN_CONTACTS)).toBe(1);
        expect(result.PLAN_CONTACTS[1].CONTACTID).toBe(variables.fixture.contactId);
        expect(arrayLen(result.PLAN_PASSENGERS)).toBe(1);
        expect(result.PLAN_PASSENGERS[1].PASSENGERID).toBe(variables.fixture.passengerId);
      });

      it("preserves the explicit new-plan bootstrap default", function() {
        var result = variables.floatPlanService.getBootstrapDataForTest(
          variables.fixture.userBId,
          0
        );

        expect(result.FLOATPLAN.FLOATPLANID).toBe(0);
        expect(result.FLOATPLAN.USERID).toBe(variables.fixture.userBId);
        expect(arrayLen(result.PLAN_CONTACTS)).toBe(0);
        expect(arrayLen(result.PLAN_PASSENGERS)).toBe(0);
        expect(arrayLen(result.PLAN_WAYPOINTS)).toBe(0);
      });

      it("ownership-scopes direct selection loading through the parent plan", function() {
        var crossUserPlan = variables.floatPlanService.loadFloatPlanForTest(
          variables.fixture.userBId,
          variables.fixture.floatPlanId
        );
        var crossUserSelections = variables.floatPlanService.loadPlanSelectionsForTest(
          variables.fixture.userBId,
          variables.fixture.floatPlanId
        );
        var ownerSelections = variables.floatPlanService.loadPlanSelectionsForTest(
          variables.fixture.userAId,
          variables.fixture.floatPlanId
        );

        expect(structIsEmpty(crossUserPlan)).toBeTrue();
        expect(arrayLen(crossUserSelections.CONTACTS)).toBe(0);
        expect(arrayLen(crossUserSelections.PASSENGERS)).toBe(0);
        expect(arrayLen(crossUserSelections.WAYPOINTS)).toBe(0);
        expect(ownerSelections.CONTACTS[1].CONTACTID).toBe(variables.fixture.contactId);
        expect(ownerSelections.PASSENGERS[1].PASSENGERID).toBe(variables.fixture.passengerId);
      });

      it("rejects a cross-user Premium send before any lifecycle mutation", function() {
        var beforeState = loadInvariantState();
        var result = variables.floatPlanService.sendFloatPlanToContactsForTest(
          variables.fixture.userBId,
          variables.fixture.floatPlanId
        );
        var afterState = loadInvariantState();

        expect(result.SUCCESS).toBeFalse();
        expect(result.ERROR).toBe("PLAN_NOT_FOUND");
        expect(afterState.plan_status).toBe(beforeState.plan_status);
        expect(afterState.plan_last_update_status).toBe(beforeState.plan_last_update_status);
        expect(afterState.float_plan_count).toBe(beforeState.float_plan_count);
        expect(afterState.contact_association_count).toBe(beforeState.contact_association_count);
        expect(afterState.passenger_association_count).toBe(beforeState.passenger_association_count);
        expect(afterState.credit_count).toBe(beforeState.credit_count);
        expect(afterState.premium_receipt_count).toBe(beforeState.premium_receipt_count);
        expect(afterState.basic_receipt_count).toBe(beforeState.basic_receipt_count);
        expect(afterState.route_instance_count).toBe(beforeState.route_instance_count);
        expect(afterState.monitoring_count).toBe(beforeState.monitoring_count);
        expect(afterState.voyage_stream_count).toBe(beforeState.voyage_stream_count);
      });
    });
  }

  private struct function createFixture() {
    var marker = variables.fixtureEmailPrefix & lCase(reReplace(createUUID(), "[^A-Za-z0-9]", "", "all"));
    var userAEmail = marker & "-a@example.test";
    var userBEmail = marker & "-b@example.test";
    var qUserA = queryNew("");
    var qUserB = queryNew("");
    var qVessel = queryNew("");
    var qOperator = queryNew("");
    var qPlan = queryNew("");
    var qContact = queryNew("");
    var qPassenger = queryNew("");

    queryExecute(
      "INSERT INTO users (fName, lName, email, password, passwordCreated, created)
       VALUES ('Codex', 'Ownership A', :email, :password, UTC_TIMESTAMP(), UTC_TIMESTAMP())",
      {
        email = { value = userAEmail, cfsqltype = "cf_sql_varchar" },
        password = { value = hash(marker & "-a", "SHA-256"), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    queryExecute(
      "INSERT INTO users (fName, lName, email, password, passwordCreated, created)
       VALUES ('Codex', 'Ownership B', :email, :password, UTC_TIMESTAMP(), UTC_TIMESTAMP())",
      {
        email = { value = userBEmail, cfsqltype = "cf_sql_varchar" },
        password = { value = hash(marker & "-b", "SHA-256"), cfsqltype = "cf_sql_varchar" }
      },
      { datasource = variables.datasource }
    );
    qUserA = queryExecute(
      "SELECT userId FROM users WHERE email = :email LIMIT 1",
      { email = { value = userAEmail, cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );
    qUserB = queryExecute(
      "SELECT userId FROM users WHERE email = :email LIMIT 1",
      { email = { value = userBEmail, cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );

    queryExecute(
      "INSERT INTO vessels (userId, vesselName, hailingPort, isDefaultVessel, timezone)
       VALUES (:userId, 'Ownership Vessel A', 'Test Harbor', 1, 'America/New_York')",
      { userId = { value = toString(val(qUserA.userId[1])), cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );
    qVessel = queryExecute(
      "SELECT vesselID FROM vessels WHERE userId = :userId ORDER BY vesselID DESC LIMIT 1",
      { userId = { value = toString(val(qUserA.userId[1])), cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );

    queryExecute(
      "INSERT INTO operators (userId, name) VALUES (:userId, 'Ownership Operator A')",
      { userId = { value = toString(val(qUserA.userId[1])), cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );
    qOperator = queryExecute(
      "SELECT opId FROM operators WHERE userId = :userId ORDER BY opId DESC LIMIT 1",
      { userId = { value = toString(val(qUserA.userId[1])), cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );

    queryExecute(
      "INSERT INTO floatplans (
         userId, floatPlanName, vesselId, operatorId, dateCreated, lastUpdate,
         status, lastUpdateStatus, route_origin, is_reusable, is_visible_in_route_library
       ) VALUES (
         :userId, 'Ownership Plan A', :vesselId, :operatorId, UTC_TIMESTAMP(), UTC_TIMESTAMP(),
         'DRAFT', UTC_TIMESTAMP(), 'premium_saved_route', 1, 1
       )",
      {
        userId = { value = toString(val(qUserA.userId[1])), cfsqltype = "cf_sql_varchar" },
        vesselId = { value = val(qVessel.vesselID[1]), cfsqltype = "cf_sql_integer" },
        operatorId = { value = val(qOperator.opId[1]), cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );
    qPlan = queryExecute(
      "SELECT floatPlanId FROM floatplans WHERE userId = :userId ORDER BY floatPlanId DESC LIMIT 1",
      { userId = { value = toString(val(qUserA.userId[1])), cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );

    queryExecute(
      "INSERT INTO contacts (name, phone, userId, email)
       VALUES ('Ownership Contact A', '', :userId, 'ownership-contact-a@example.test')",
      { userId = { value = toString(val(qUserA.userId[1])), cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );
    qContact = queryExecute(
      "SELECT contactId FROM contacts WHERE userId = :userId ORDER BY contactId DESC LIMIT 1",
      { userId = { value = toString(val(qUserA.userId[1])), cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );

    queryExecute(
      "INSERT INTO passengers (userId, name, phone)
       VALUES (:userId, 'Ownership Passenger A', '')",
      { userId = { value = toString(val(qUserA.userId[1])), cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );
    qPassenger = queryExecute(
      "SELECT passId FROM passengers WHERE userId = :userId ORDER BY passId DESC LIMIT 1",
      { userId = { value = toString(val(qUserA.userId[1])), cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );

    queryExecute(
      "INSERT INTO floatplan_contacts (contactId, floatPlanId) VALUES (:contactId, :floatPlanId)",
      {
        contactId = { value = val(qContact.contactId[1]), cfsqltype = "cf_sql_integer" },
        floatPlanId = { value = val(qPlan.floatPlanId[1]), cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );
    queryExecute(
      "INSERT INTO floatplan_passengers (passId, floatPlanId, hasPdf)
       VALUES (:passengerId, :floatPlanId, 1)",
      {
        passengerId = { value = val(qPassenger.passId[1]), cfsqltype = "cf_sql_integer" },
        floatPlanId = { value = val(qPlan.floatPlanId[1]), cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );

    return {
      userAId = val(qUserA.userId[1]),
      userBId = val(qUserB.userId[1]),
      floatPlanId = val(qPlan.floatPlanId[1]),
      vesselId = val(qVessel.vesselID[1]),
      operatorId = val(qOperator.opId[1]),
      contactId = val(qContact.contactId[1]),
      passengerId = val(qPassenger.passId[1])
    };
  }

  private struct function loadInvariantState() {
    var qState = queryExecute(
      "SELECT
         (SELECT UPPER(TRIM(status)) FROM floatplans WHERE floatPlanId = :floatPlanId) AS plan_status,
         (SELECT DATE_FORMAT(lastUpdateStatus, '%Y-%m-%d %H:%i:%s') FROM floatplans WHERE floatPlanId = :floatPlanId) AS plan_last_update_status,
         (SELECT COUNT(*) FROM floatplans WHERE userId IN (:userAId, :userBId)) AS float_plan_count,
         (SELECT COUNT(*) FROM floatplan_contacts WHERE floatPlanId = :floatPlanId) AS contact_association_count,
         (SELECT COUNT(*) FROM floatplan_passengers WHERE floatPlanId = :floatPlanId) AS passenger_association_count,
         (SELECT COUNT(*) FROM premium_send_credits WHERE user_id IN (:userAId, :userBId)) AS credit_count,
         (SELECT COUNT(*) FROM premium_send_receipts WHERE user_id IN (:userAId, :userBId)) AS premium_receipt_count,
         (SELECT COUNT(*) FROM basic_review_send_receipts WHERE user_id IN (:userAId, :userBId)) AS basic_receipt_count,
         (SELECT COUNT(*) FROM route_instances WHERE user_id IN (:userAId, :userBId)) AS route_instance_count,
         (SELECT COUNT(*) FROM floatplan_monitoring WHERE user_id IN (:userAId, :userBId) OR float_plan_id = :floatPlanId) AS monitoring_count,
         (SELECT COUNT(*) FROM voyage_streams WHERE owner_user_id IN (:userAId, :userBId) OR floatplan_id = :floatPlanId) AS voyage_stream_count",
      {
        userAId = { value = variables.fixture.userAId, cfsqltype = "cf_sql_integer" },
        userBId = { value = variables.fixture.userBId, cfsqltype = "cf_sql_integer" },
        floatPlanId = { value = variables.fixture.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );

    return {
      plan_status = qState.plan_status[1],
      plan_last_update_status = qState.plan_last_update_status[1],
      float_plan_count = val(qState.float_plan_count[1]),
      contact_association_count = val(qState.contact_association_count[1]),
      passenger_association_count = val(qState.passenger_association_count[1]),
      credit_count = val(qState.credit_count[1]),
      premium_receipt_count = val(qState.premium_receipt_count[1]),
      basic_receipt_count = val(qState.basic_receipt_count[1]),
      route_instance_count = val(qState.route_instance_count[1]),
      monitoring_count = val(qState.monitoring_count[1]),
      voyage_stream_count = val(qState.voyage_stream_count[1])
    };
  }

  private void function cleanupFixtures() {
    var pattern = variables.fixtureEmailPrefix & "%";
    var params = { pattern = { value = pattern, cfsqltype = "cf_sql_varchar" } };

    queryExecute("DELETE FROM basic_review_send_receipts WHERE user_id IN (SELECT userId FROM users WHERE email LIKE :pattern)", params, { datasource = variables.datasource });
    queryExecute("DELETE FROM premium_send_receipts WHERE user_id IN (SELECT userId FROM users WHERE email LIKE :pattern)", params, { datasource = variables.datasource });
    queryExecute("DELETE FROM floatplan_monitoring WHERE user_id IN (SELECT userId FROM users WHERE email LIKE :pattern)", params, { datasource = variables.datasource });
    queryExecute("DELETE FROM voyage_streams WHERE owner_user_id IN (SELECT userId FROM users WHERE email LIKE :pattern)", params, { datasource = variables.datasource });
    queryExecute("DELETE FROM premium_send_credits WHERE user_id IN (SELECT userId FROM users WHERE email LIKE :pattern)", params, { datasource = variables.datasource });
    queryExecute("DELETE FROM floatplan_contacts WHERE floatPlanId IN (SELECT floatPlanId FROM floatplans WHERE userId IN (SELECT CAST(userId AS CHAR) FROM users WHERE email LIKE :pattern))", params, { datasource = variables.datasource });
    queryExecute("DELETE FROM floatplan_passengers WHERE floatPlanId IN (SELECT floatPlanId FROM floatplans WHERE userId IN (SELECT CAST(userId AS CHAR) FROM users WHERE email LIKE :pattern))", params, { datasource = variables.datasource });
    queryExecute("DELETE FROM floatplan_waypoints WHERE floatPlanId IN (SELECT floatPlanId FROM floatplans WHERE userId IN (SELECT CAST(userId AS CHAR) FROM users WHERE email LIKE :pattern))", params, { datasource = variables.datasource });
    queryExecute("DELETE FROM floatplans WHERE userId IN (SELECT CAST(userId AS CHAR) FROM users WHERE email LIKE :pattern)", params, { datasource = variables.datasource });
    queryExecute("DELETE FROM contacts WHERE userId IN (SELECT CAST(userId AS CHAR) FROM users WHERE email LIKE :pattern)", params, { datasource = variables.datasource });
    queryExecute("DELETE FROM passengers WHERE userId IN (SELECT CAST(userId AS CHAR) FROM users WHERE email LIKE :pattern)", params, { datasource = variables.datasource });
    queryExecute("DELETE FROM operators WHERE userId IN (SELECT CAST(userId AS CHAR) FROM users WHERE email LIKE :pattern)", params, { datasource = variables.datasource });
    queryExecute("DELETE FROM vessels WHERE userId IN (SELECT CAST(userId AS CHAR) FROM users WHERE email LIKE :pattern)", params, { datasource = variables.datasource });
    queryExecute("DELETE FROM users WHERE email LIKE :pattern", params, { datasource = variables.datasource });
  }
}
