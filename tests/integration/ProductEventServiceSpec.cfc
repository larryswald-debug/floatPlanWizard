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
    });
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
