component extends="testbox.system.BaseSpec" output="false" {

  function beforeAll() {
    ensureProductEventsTable();
    variables.service = new fpw.includes.ProductEventService().init("fpw");
    variables.testUserIds = [];
    variables.userSeed = 910000000 + randRange(1000, 99999);
  }

  function afterEach() {
    cleanupProductEvents();
  }

  function run() {
    describe("ProductEventService Phase 1", function() {
      it("records an allowed event with a server UTC timestamp", function() {
        var userId = nextUserId();
        var result = variables.service.recordEvent(
          userId = userId,
          eventName = "sign_up",
          entityType = "user",
          entityId = userId,
          eventSource = "member_signup",
          metadata = {
            signup_method = "password",
            account_tier = "basic"
          },
          idempotencyKey = "sign_up:user:" & userId,
          requestCorrelationId = lCase(createUUID())
        );
        var qEvent = loadEvents(userId);

        expect(result.SUCCESS).toBeTrue(serializeJSON(result));
        expect(result.RECORDED).toBeTrue(serializeJSON(result));
        expect(result.DUPLICATE).toBeFalse(serializeJSON(result));
        expect(qEvent.recordCount).toBe(1);
        expect(qEvent.event_name[1]).toBe("sign_up");
        expect(val(qEvent.utc_skew_seconds[1])).toBeLTE(5);
      });

      it("rejects unknown events, disallowed metadata keys, and sensitive values", function() {
        var userId = nextUserId();
        var unknown = variables.service.recordEvent(
          userId = userId,
          eventName = "purchase",
          entityType = "user",
          entityId = userId,
          eventSource = "member_signup",
          idempotencyKey = "test:unknown:" & userId
        );
        var disallowedKey = variables.service.recordEvent(
          userId = userId,
          eventName = "sign_up",
          entityType = "user",
          entityId = userId,
          eventSource = "member_signup",
          metadata = { email = "blocked" },
          idempotencyKey = "test:key:" & userId
        );
        var disallowedValue = variables.service.recordEvent(
          userId = userId,
          eventName = "login",
          entityType = "user",
          entityId = userId,
          eventSource = "password_auth",
          metadata = { auth_method = "address@example.test" },
          idempotencyKey = "test:value:" & userId
        );

        expect(unknown.SUCCESS).toBeFalse(serializeJSON(unknown));
        expect(unknown.ERROR).toBe("UNKNOWN_EVENT_NAME");
        expect(disallowedKey.SUCCESS).toBeFalse(serializeJSON(disallowedKey));
        expect(disallowedKey.ERROR).toBe("DISALLOWED_METADATA_KEY");
        expect(disallowedValue.SUCCESS).toBeFalse(serializeJSON(disallowedValue));
        expect(disallowedValue.ERROR).toBe("DISALLOWED_METADATA_VALUE");
        expect(loadEvents(userId).recordCount).toBe(0);
      });

      it("deduplicates repeated idempotency keys", function() {
        var userId = nextUserId();
        var keyValue = "vessel_created:vessel:" & userId;
        var first = variables.service.recordEvent(
          userId = userId,
          eventName = "vessel_created",
          entityType = "vessel",
          entityId = userId,
          eventSource = "member_api",
          metadata = {
            creation_source = "member",
            is_first = "true"
          },
          idempotencyKey = keyValue
        );
        var duplicate = variables.service.recordEvent(
          userId = userId,
          eventName = "vessel_created",
          entityType = "vessel",
          entityId = userId,
          eventSource = "member_api",
          metadata = {
            creation_source = "member",
            is_first = "true"
          },
          idempotencyKey = keyValue
        );

        expect(first.RECORDED).toBeTrue(serializeJSON(first));
        expect(duplicate.SUCCESS).toBeTrue(serializeJSON(duplicate));
        expect(duplicate.RECORDED).toBeFalse(serializeJSON(duplicate));
        expect(duplicate.DUPLICATE).toBeTrue(serializeJSON(duplicate));
        expect(loadEvents(userId).recordCount).toBe(1);
      });

      it("returns ordered member history without internal identifiers", function() {
        var userId = nextUserId();
        variables.service.recordEvent(
          userId = userId,
          eventName = "sign_up",
          entityType = "user",
          entityId = userId,
          eventSource = "member_signup",
          metadata = { signup_method = "password" },
          idempotencyKey = "history:signup:" & userId
        );
        variables.service.recordEvent(
          userId = userId,
          eventName = "login",
          entityType = "user",
          entityId = userId,
          eventSource = "password_auth",
          metadata = { auth_method = "password" },
          idempotencyKey = "history:login:" & userId
        );

        var history = variables.service.getMemberEventHistory(userId);

        expect(history.SUCCESS).toBeTrue(serializeJSON(history));
        expect(arrayLen(history.EVENTS)).toBe(2, serializeJSON(history));
        expect(history.EVENTS[1].eventName).toBe("sign_up");
        expect(history.EVENTS[2].eventName).toBe("login");
        expect(structKeyExists(history.EVENTS[1], "entityId")).toBeFalse(serializeJSON(history));
        expect(structKeyExists(history.EVENTS[1], "eventUuid")).toBeFalse(serializeJSON(history));
        expect(structKeyExists(history.EVENTS[1], "idempotencyKey")).toBeFalse(serializeJSON(history));
        expect(right(history.EVENTS[1].occurredAtUtc, 1)).toBe("Z");
      });

      it("returns aggregate counts by event and UTC date range", function() {
        var userId = nextUserId();
        variables.service.recordEvent(
          userId = userId,
          eventName = "login",
          entityType = "user",
          entityId = userId,
          eventSource = "password_auth",
          metadata = { auth_method = "password" },
          idempotencyKey = "aggregate:login:1:" & userId
        );
        variables.service.recordEvent(
          userId = userId,
          eventName = "login",
          entityType = "user",
          entityId = userId,
          eventSource = "password_auth",
          metadata = { auth_method = "password" },
          idempotencyKey = "aggregate:login:2:" & userId
        );

        var counts = variables.service.getAggregateCounts(
          startUtc = dateAdd("d", -1, now()),
          endUtc = dateAdd("d", 1, now()),
          eventName = "login"
        );
        var total = 0;
        var row = {};

        expect(counts.SUCCESS).toBeTrue(serializeJSON(counts));
        for (row in counts.COUNTS) {
          total += val(row.eventCount);
        }
        expect(total).toBeGTE(2);
      });

      it("returns a logged failure result instead of throwing when persistence is unavailable", function() {
        var userId = nextUserId();
        var failingService = new fpw.includes.ProductEventService().init("fpw_missing_product_events_test");
        var result = {};
        var threw = false;

        try {
          result = failingService.recordEvent(
            userId = userId,
            eventName = "sign_up",
            entityType = "user",
            entityId = userId,
            eventSource = "member_signup",
            metadata = { signup_method = "password" },
            idempotencyKey = "failure:user:" & userId
          );
        } catch (any err) {
          threw = true;
        }

        expect(threw).toBeFalse();
        expect(result.SUCCESS).toBeFalse(serializeJSON(result));
        expect(result.ERROR).toBe("PRODUCT_EVENT_PERSIST_FAILED");
      });

      it("enables forced failure only for the exact true setting in dev or staging", function() {
        var originalState = snapshotProductEventTestState();
        var disabledValue = "";
        var config = {};
        var service = {};

        try {
          setupProductEventTestState("dev", "");
          service = new fpw.includes.ProductEventService().init("fpw", {
            logEntries = application.testProductEventLogEntries
          });
          structDelete(application.settings, "FPW_PRODUCT_EVENTS_FORCE_FAILURE", false);
          config = service.validateForcedFailureConfiguration();
          expect(config.REQUESTED).toBeFalse(serializeJSON(config));
          expect(config.ENABLED).toBeFalse(serializeJSON(config));

          for (disabledValue in ["", "false", "0", "TRUE", "yes"]) {
            application.settings.FPW_PRODUCT_EVENTS_FORCE_FAILURE = disabledValue;
            config = service.validateForcedFailureConfiguration();
            expect(config.ENABLED).toBeFalse(serializeJSON(config));
          }

          application.settings.FPW_PRODUCT_EVENTS_FORCE_FAILURE = "true";
          config = service.validateForcedFailureConfiguration();
          expect(config.REQUESTED).toBeTrue(serializeJSON(config));
          expect(config.ENABLED).toBeTrue(serializeJSON(config));

          application.env = "staging";
          config = service.validateForcedFailureConfiguration();
          expect(config.ENABLED).toBeTrue(serializeJSON(config));
        } finally {
          restoreProductEventTestState(originalState);
        }
      });

      it("forces a safe pre-insert exception and resumes immediately when disabled", function() {
        var originalState = snapshotProductEventTestState();
        var forcedUserId = nextUserId();
        var recoveryUserId = nextUserId();
        var caught = {};
        var threw = false;
        var recovery = {};
        var logText = "";
        var service = {};

        try {
          setupProductEventTestState("dev", "true");
          service = new fpw.includes.ProductEventService().init("fpw", {
            logEntries = application.testProductEventLogEntries
          });

          try {
            service.recordEvent(
              userId = forcedUserId,
              eventName = "sign_up",
              entityType = "user",
              entityId = forcedUserId,
              eventSource = "member_signup",
              metadata = { signup_method = "password" },
              idempotencyKey = "forced:user:" & forcedUserId
            );
          } catch (any forcedError) {
            threw = true;
            caught = forcedError;
          }

          expect(threw).toBeTrue();
          expect(caught.type).toBe("FPW.ProductEvent.ForcedTestFailure");
          expect(caught.message).toBe("Forced product-event failure for controlled staging validation.");
          expect(loadEvents(forcedUserId).recordCount).toBe(0);
          expect(countTestLogs(service, "FORCED_TEST_FAILURE | event=sign_up")).toBe(1);

          logText = service.getCapturedTestLogs()[1].text;
          expect(find(toString(forcedUserId), logText)).toBe(0);
          expect(find("@", logText)).toBe(0);
          expect(findNoCase("555", logText)).toBe(0);
          expect(findNoCase("password", logText)).toBe(0);
          expect(findNoCase("token", logText)).toBe(0);
          expect(findNoCase("stripe", logText)).toBe(0);

          application.settings.FPW_PRODUCT_EVENTS_FORCE_FAILURE = "false";
          recovery = service.recordEvent(
            userId = recoveryUserId,
            eventName = "sign_up",
            entityType = "user",
            entityId = recoveryUserId,
            eventSource = "member_signup",
            metadata = { signup_method = "password" },
            idempotencyKey = "recovery:user:" & recoveryUserId
          );

          expect(recovery.SUCCESS).toBeTrue(serializeJSON(recovery));
          expect(recovery.RECORDED).toBeTrue(serializeJSON(recovery));
          expect(loadEvents(recoveryUserId).recordCount).toBe(1);
        } finally {
          restoreProductEventTestState(originalState);
        }
      });

      it("fails closed in production, warns once, and preserves validation behavior", function() {
        var originalState = snapshotProductEventTestState();
        var productionUserId = nextUserId();
        var invalidUserId = nextUserId();
        var service = {};
        var config = {};
        var recorded = {};
        var invalid = {};

        try {
          setupProductEventTestState("prod", "true");
          service = new fpw.includes.ProductEventService().init("fpw", {
            logEntries = application.testProductEventLogEntries
          });
          config = service.validateForcedFailureConfiguration();
          service.validateForcedFailureConfiguration();

          expect(config.REQUESTED).toBeTrue(serializeJSON(config));
          expect(config.ENABLED).toBeFalse(serializeJSON(config));
          expect(config.WARNING_REQUIRED).toBeTrue(serializeJSON(config));
          expect(countTestLogs(service, "FORCED_TEST_FAILURE_DISABLED")).toBe(1);

          recorded = service.recordEvent(
            userId = productionUserId,
            eventName = "sign_up",
            entityType = "user",
            entityId = productionUserId,
            eventSource = "member_signup",
            metadata = { signup_method = "password" },
            idempotencyKey = "production-guard:user:" & productionUserId
          );
          expect(recorded.SUCCESS).toBeTrue(serializeJSON(recorded));
          expect(loadEvents(productionUserId).recordCount).toBe(1);
          expect(countTestLogs(service, "FORCED_TEST_FAILURE | event=")).toBe(0);

          application.env = "dev";
          invalid = service.recordEvent(
            userId = invalidUserId,
            eventName = "purchase",
            entityType = "user",
            entityId = invalidUserId,
            eventSource = "member_signup",
            idempotencyKey = "forced-invalid:user:" & invalidUserId
          );
          expect(invalid.SUCCESS).toBeFalse(serializeJSON(invalid));
          expect(invalid.ERROR).toBe("UNKNOWN_EVENT_NAME");
          expect(loadEvents(invalidUserId).recordCount).toBe(0);
          expect(countTestLogs(service, "FORCED_TEST_FAILURE | event=")).toBe(0);
        } finally {
          restoreProductEventTestState(originalState);
        }
      });
    });
  }

  private struct function snapshotProductEventTestState() {
    return {
      envExists = structKeyExists(application, "env"),
      env = structKeyExists(application, "env") ? application.env : "",
      settingsExists = structKeyExists(application, "settings") && isStruct(application.settings),
      settings = structKeyExists(application, "settings") && isStruct(application.settings)
        ? duplicate(application.settings)
        : {},
      entriesExist = structKeyExists(application, "testProductEventLogEntries"),
      entries = structKeyExists(application, "testProductEventLogEntries")
        ? application.testProductEventLogEntries
        : []
    };
  }

  private void function setupProductEventTestState(
    required string environment,
    required any settingValue
  ) {
    application.env = arguments.environment;
    if (!structKeyExists(application, "settings") || !isStruct(application.settings)) {
      application.settings = {};
    }
    application.settings.FPW_PRODUCT_EVENTS_FORCE_FAILURE = arguments.settingValue;
    application.testProductEventLogEntries = [];
  }

  private void function restoreProductEventTestState(required struct originalState) {
    if (arguments.originalState.envExists) {
      application.env = arguments.originalState.env;
    } else {
      structDelete(application, "env", false);
    }

    if (arguments.originalState.settingsExists) {
      application.settings = arguments.originalState.settings;
    } else {
      structDelete(application, "settings", false);
    }

    if (arguments.originalState.entriesExist) {
      application.testProductEventLogEntries = arguments.originalState.entries;
    } else {
      structDelete(application, "testProductEventLogEntries", false);
    }
  }

  private numeric function countTestLogs(
    required any service,
    required string pattern
  ) {
    var entry = {};
    var count = 0;

    for (entry in arguments.service.getCapturedTestLogs()) {
      if (findNoCase(arguments.pattern, toString(entry.text))) {
        count++;
      }
    }
    return count;
  }

  private numeric function nextUserId() {
    variables.userSeed++;
    arrayAppend(variables.testUserIds, variables.userSeed);
    return variables.userSeed;
  }

  private query function loadEvents(required numeric userId) {
    return queryExecute(
      "SELECT event_name,
              ABS(TIMESTAMPDIFF(SECOND, occurred_at_utc, UTC_TIMESTAMP())) AS utc_skew_seconds
       FROM product_events
       WHERE user_id = :userId
       ORDER BY occurred_at_utc, id",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = "fpw" }
    );
  }

  private void function cleanupProductEvents() {
    var userId = 0;
    for (userId in variables.testUserIds) {
      queryExecute(
        "DELETE FROM product_events WHERE user_id = :userId",
        {
          userId = { value = userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = "fpw" }
      );
    }
    variables.testUserIds = [];
  }

  private void function ensureProductEventsTable() {
    queryExecute(
      "CREATE TABLE IF NOT EXISTS product_events (
         id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
         event_uuid CHAR(36) NOT NULL,
         user_id INT NOT NULL,
         event_name VARCHAR(64) NOT NULL,
         entity_type VARCHAR(40) NOT NULL,
         entity_id BIGINT UNSIGNED NOT NULL,
         event_source VARCHAR(64) NOT NULL,
         occurred_at_utc DATETIME NOT NULL,
         request_correlation_id VARCHAR(64) NULL,
         metadata_json JSON NULL,
         created_at_utc DATETIME NOT NULL,
         idempotency_key VARCHAR(191) NOT NULL,
         PRIMARY KEY (id),
         UNIQUE KEY uq_product_events_event_uuid (event_uuid),
         UNIQUE KEY uq_product_events_idempotency (idempotency_key),
         KEY idx_product_events_user_time (user_id, occurred_at_utc, id),
         KEY idx_product_events_name_time (event_name, occurred_at_utc, id)
       ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
      {},
      { datasource = "fpw" }
    );
  }

}
