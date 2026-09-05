component extends="testbox.system.BaseSpec" output="false" {

  function run() {
    describe("Inactive-member recovery pure policy", function() {
      beforeEach(function() {
        variables.policy = createObject("component", "fpw.includes.InactiveMemberRecoveryPolicy");
      });

      it("waits at 167h 59m 59s and becomes eligible at exactly 168h for every stage", function() {
        for (var stage in ["A", "B", "C", "D"]) {
          var input = evidence(stage);
          input.now_utc = "2026-09-07T23:59:59Z";
          var before = variables.policy.evaluate(input);
          expect(before.decision).toBe("DEFERRED");
          expect(before.seconds_until_eligible).toBe(1);
          input.now_utc = "2026-09-08T00:00:00Z";
          var exact = variables.policy.evaluate(input);
          expect(exact.eligible).toBeTrue();
          expect(exact.interval_seconds).toBe(604800);
          expect(exact.seconds_until_eligible).toBe(0);
          expect(exact.eligible_at_utc).toBe("2026-09-08T00:00:00Z");
        }
      });

      it("gives a reliably enrolled historical account a fresh seven-day grace", function() {
        var input = evidence();
        input.current_stage_entered_utc = "2025-01-01T00:00:00Z";
        input.enrollment_utc = input.now_utc;
        var result = variables.policy.evaluate(input);
        expect(result.eligible).toBeFalse();
        expect(result.seconds_until_eligible).toBe(604800);
      });

      it("starts a fresh interval for verified advancement and direct jumps to Draft", function() {
        var input = evidence("D");
        input.current_stage_entered_utc = "2026-09-07T00:00:00Z";
        var result = variables.policy.evaluate(input);
        expect(result.anchor_utc).toBe(input.current_stage_entered_utc);
        expect(result.eligible_at_utc).toBe("2026-09-14T00:00:00Z");
        expect(result.eligible).toBeFalse();
      });

      it("accepts supplied verified Stage C without inspecting or requiring route legs", function() {
        expect(variables.policy.evaluate(evidence("C")).eligible).toBeTrue();
      });

      it("defers another seven days after a qualifying saved edit", function() {
        var input = evidence();
        input.latest_activity = {state = "recorded", at_utc = "2026-09-07T12:00:00Z", action = activity()};
        var result = variables.policy.evaluate(input);
        expect(result.anchor_utc).toBe(input.latest_activity.at_utc);
        expect(result.eligible_at_utc).toBe("2026-09-14T12:00:00Z");
        expect(result.eligible).toBeFalse();
      });

      it("treats another same-stage creation as activity without replacing first stage entry", function() {
        var input = evidence("B");
        var firstEntry = input.current_stage_entered_utc;
        var action = activity();
        action.operation = "create";
        structDelete(action, "changed");
        input.latest_activity = {state = "recorded", at_utc = "2026-09-07T00:00:00Z", action = action};
        expect(variables.policy.evaluate(input).eligible_at_utc).toBe("2026-09-14T00:00:00Z");
        expect(input.current_stage_entered_utc).toBe(firstEntry);
      });

      it("independently applies cross-stage send spacing", function() {
        var input = evidence("D");
        input.last_recovery = {state = "sent", stage = "C", at_utc = "2026-09-07T00:00:00Z"};
        var result = variables.policy.evaluate(input);
        expect(result.anchor_utc).toBe(input.last_recovery.at_utc);
        expect(result.eligible_at_utc).toBe("2026-09-14T00:00:00Z");
        expect(result.eligible).toBeFalse();
      });

      it("uses the latest of all four anchors and never shortens the interval", function() {
        var input = evidence("D");
        input.enrollment_utc = "2026-09-04T00:00:00Z";
        input.current_stage_entered_utc = "2026-09-05T00:00:00Z";
        input.last_recovery = {state = "sent", stage = "B", at_utc = "2026-09-06T00:00:00Z"};
        input.latest_activity = {state = "recorded", at_utc = "2026-09-07T00:00:00Z", action = activity()};
        expect(variables.policy.evaluate(input).anchor_utc).toBe(input.latest_activity.at_utc);
        input.enrollment_utc = input.now_utc;
        expect(variables.policy.evaluate(input).seconds_until_eligible).toBe(604800);
      });

      it("does not use login, page-view, or arbitrary product-event timestamps as anchors", function() {
        var input = evidence();
        input.login_at_utc = input.now_utc;
        input.page_view_at_utc = input.now_utc;
        input.latest_product_event_utc = input.now_utc;
        expect(variables.policy.evaluate(input).eligible).toBeTrue();
      });

      it("requires successful owned persisted member activity for every allowed entity", function() {
        for (var entity in ["vessel", "shore_contact", "operator", "passenger", "saved_waypoint", "route", "route_leg", "draft", "draft_contacts"]) {
          var action = activity();
          action.entity = entity;
          expect(variables.policy.isQualifyingActivity(action)).toBeTrue();
          action.operation = "create";
          structDelete(action, "changed");
          expect(variables.policy.isQualifyingActivity(action)).toBeTrue();
        }
      });

      it("rejects failed, unowned, automated, browser-only and unpersisted actions", function() {
        for (var proof in ["successful", "owned", "member_initiated", "persisted"]) {
          var action = activity();
          action[proof] = false;
          expect(variables.policy.isQualifyingActivity(action)).toBeFalse();
          structDelete(action, proof);
          expect(variables.policy.isQualifyingActivity(action)).toBeFalse();
        }
      });

      it("does not qualify unchanged saves, purchases, logins, views, opens, or deletions", function() {
        var action = activity();
        action.changed = false;
        expect(variables.policy.isQualifyingActivity(action)).toBeFalse();
        structDelete(action, "changed");
        expect(variables.policy.isQualifyingActivity(action)).toBeFalse();
        for (var operation in ["purchase", "login", "page_view", "modal_open", "delete", "unknown"]) {
          action = activity();
          action.operation = operation;
          expect(variables.policy.isQualifyingActivity(action)).toBeFalse();
        }
        action = activity();
        action.entity = "purchase";
        expect(variables.policy.isQualifyingActivity(action)).toBeFalse();
        expect(variables.policy.isQualifyingActivity("vessel_created")).toBeFalse();
      });

      it("holds if a purported latest qualifying activity is actually a no-op", function() {
        var input = evidence();
        var action = activity();
        action.changed = false;
        input.latest_activity = {state = "recorded", at_utc = input.now_utc, action = action};
        expect(variables.policy.evaluate(input).reason).toBe("ACTIVITY_NOT_QUALIFYING");
      });

      it("suppresses positive sharing evidence regardless of current or deleted entities", function() {
        for (var stage in ["A", "B", "C", "D"]) {
          var input = evidence(stage);
          input.has_successful_share = true;
          expect(variables.policy.evaluate(input).reason).toBe("SHARED");
        }
        expect(variables.policy.evaluate({has_successful_share = true}).decision).toBe("SUPPRESSED");
        expect(variables.policy.evaluate({stage = "Shared"}).reason).toBe("SHARED");
        expect(variables.policy.evaluate({highest_verified_stage = "Shared"}).reason).toBe("SHARED");
      });

      it("does not requalify a deleted/recreated entity's already-sent stage", function() {
        for (var stage in ["A", "B", "C", "D"]) {
          var input = evidence(stage);
          input.current_stage_recovery = "sent";
          expect(variables.policy.evaluate(input).reason).toBe("STAGE_ALREADY_SENT");
        }
      });

      it("holds unresolved potentially sent attempts at the current or an earlier stage", function() {
        var input = evidence("D");
        input.current_stage_recovery = "possibly_sent";
        expect(variables.policy.evaluate(input).reason).toBe("STAGE_SEND_UNRESOLVED");
        input.current_stage_recovery = "never_sent";
        input.last_recovery = {state = "possibly_sent"};
        expect(variables.policy.evaluate(input).reason).toBe("RECOVERY_SEND_UNRESOLVED");
      });

      it("holds stage regression or contradictory highest-stage evidence", function() {
        for (var pair in [["A", "B"], ["B", "C"], ["C", "D"], ["D", "A"]]) {
          var input = evidence(pair[1]);
          input.highest_verified_stage = pair[2];
          expect(variables.policy.evaluate(input).reason).toBe("STAGE_HISTORY_CONFLICT");
        }
      });

      it("requires every verification flag including historical and ownership coverage", function() {
        for (var proof in evidence().verification) {
          var input = evidence();
          input.verification[proof] = false;
          expect(variables.policy.evaluate(input).decision).toBe("HELD");
          structDelete(input.verification, proof);
          expect(variables.policy.evaluate(input).decision).toBe("HELD");
        }
      });

      it("suppresses each exclusion and holds missing exclusion checks", function() {
        for (var exclusion in evidence().exclusions) {
          var input = evidence();
          input.exclusions[exclusion] = true;
          expect(variables.policy.evaluate(input).decision).toBe("SUPPRESSED");
          structDelete(input.exclusions, exclusion);
          expect(variables.policy.evaluate(input).decision).toBe("HELD");
        }
      });

      it("fails closed on every missing top-level input", function() {
        for (var key in evidence()) {
          var input = evidence();
          structDelete(input, key);
          expect(variables.policy.evaluate(input).eligible).toBeFalse();
        }
        expect(variables.policy.evaluate().decision).toBe("HELD");
        expect(variables.policy.evaluate([]).decision).toBe("HELD");
        expect(variables.policy.evaluate("not evidence").decision).toBe("HELD");
      });

      it("does not coerce text or numbers into verified boolean proof", function() {
        for (var value in ["true", "yes", "false", "no", 1, 0, "", [], {}]) {
          var input = evidence();
          input.account_exists = value;
          expect(variables.policy.evaluate(input).eligible).toBeFalse();
          input = evidence();
          input.exclusions.opt_out = value;
          expect(variables.policy.evaluate(input).eligible).toBeFalse();
          input = evidence();
          input.has_successful_share = value;
          expect(variables.policy.evaluate(input).eligible).toBeFalse();
        }
      });

      it("holds malformed stage and history states", function() {
        for (var value in ["", "a", "unknown", "C,D", [], {}]) {
          for (var key in ["stage", "highest_verified_stage", "current_stage_recovery"]) {
            var input = evidence();
            input[key] = value;
            expect(variables.policy.evaluate(input).eligible).toBeFalse();
          }
        }
        for (var key in ["latest_activity", "last_recovery", "verification", "exclusions"]) {
          var input = evidence();
          input[key] = "unknown";
          expect(variables.policy.evaluate(input).eligible).toBeFalse();
        }
      });

      it("requires explicit verified absence rather than silently omitting optional clocks", function() {
        var input = evidence();
        input.latest_activity = {};
        expect(variables.policy.evaluate(input).reason).toBe("ACTIVITY_HISTORY_UNKNOWN");
        input = evidence();
        input.last_recovery = {};
        expect(variables.policy.evaluate(input).reason).toBe("RECOVERY_HISTORY_UNKNOWN");
        input = evidence();
        input.latest_activity.at_utc = input.now_utc;
        expect(variables.policy.evaluate(input).reason).toBe("ACTIVITY_HISTORY_CONFLICT");
        input = evidence();
        input.last_recovery.at_utc = input.now_utc;
        expect(variables.policy.evaluate(input).reason).toBe("RECOVERY_HISTORY_CONFLICT");
      });

      it("rejects same/higher-stage or unrecognized last sends that conflict with never-sent", function() {
        for (var stage in ["C", "D", "unknown"]) {
          var input = evidence("C");
          input.last_recovery = {state = "sent", stage = stage, at_utc = "2026-09-01T00:00:00Z"};
          expect(variables.policy.evaluate(input).reason).toBe("RECOVERY_HISTORY_CONFLICT");
        }
      });

      it("rejects ambiguous, invalid, noncanonical, offset and malformed UTC clocks", function() {
        for (var value in ["", "09/01/2026", "2026-09-01T00:00:00", "2026-09-01T00:00:00-04:00", "2026-09-01T00:00:00.000Z", "2026-02-30T00:00:00Z", "2026-09-01T24:00:00Z", "2026-09-01T23:59:60Z", "2026-09-01t00:00:00z", "2026-09-01T00:00:00Z ", 123, true, [], {}]) {
          for (var key in ["now_utc", "enrollment_utc", "current_stage_entered_utc"]) {
            var input = evidence();
            input[key] = value;
            expect(variables.policy.evaluate(input).reason).toBe("INVALID_UTC_CLOCK");
          }
          var input = evidence("D");
          input.latest_activity = {state = "recorded", at_utc = value, action = activity()};
          expect(variables.policy.evaluate(input).reason).toBe("INVALID_UTC_CLOCK");
          input = evidence("D");
          input.last_recovery = {state = "sent", stage = "B", at_utc = value};
          expect(variables.policy.evaluate(input).reason).toBe("INVALID_UTC_CLOCK");
        }
      });

      it("holds future entry, enrollment, activity and sent clocks", function() {
        for (var key in ["enrollment_utc", "current_stage_entered_utc"]) {
          var input = evidence();
          input[key] = "2026-09-08T00:00:01Z";
          expect(variables.policy.evaluate(input).reason).toBe("FUTURE_CLOCK");
        }
        var input = evidence("D");
        input.latest_activity = {state = "recorded", at_utc = "2026-09-08T00:00:01Z", action = activity()};
        expect(variables.policy.evaluate(input).reason).toBe("FUTURE_CLOCK");
        input = evidence("D");
        input.last_recovery = {state = "sent", stage = "C", at_utc = "2026-09-08T00:00:01Z"};
        expect(variables.policy.evaluate(input).reason).toBe("FUTURE_CLOCK");
      });

      it("uses 604800 elapsed UTC seconds across spring and fall DST transitions", function() {
        for (var clocks in [
          ["2026-03-07T17:00:00Z", "2026-03-14T16:59:59Z", "2026-03-14T17:00:00Z"],
          ["2026-10-31T16:00:00Z", "2026-11-07T15:59:59Z", "2026-11-07T16:00:00Z"]
        ]) {
          var input = evidence();
          input.enrollment_utc = clocks[1];
          input.current_stage_entered_utc = clocks[1];
          input.now_utc = clocks[2];
          expect(variables.policy.evaluate(input).seconds_until_eligible).toBe(1);
          input.now_utc = clocks[3];
          expect(variables.policy.evaluate(input).eligible).toBeTrue();
        }
      });

      it("is deterministic, does not mutate input, and returns only policy fields", function() {
        var input = evidence();
        input.email = "not-returned@example.invalid";
        var before = serializeJSON(input);
        var first = variables.policy.evaluate(input);
        expect(serializeJSON(variables.policy.evaluate(input))).toBe(serializeJSON(first));
        expect(serializeJSON(input)).toBe(before);
        expect(structCount(first)).toBe(7);
        expect(structKeyExists(first, "email")).toBeFalse();
        var held = variables.policy.evaluate({});
        expect(structCount(held)).toBe(4);
        expect(structKeyExists(held, "eligible_at_utc")).toBeFalse();
      });

      it("reevaluates fresh evidence rather than treating an earlier result as continuing eligibility", function() {
        var input = evidence();
        expect(variables.policy.evaluate(input).eligible).toBeTrue();
        input.has_successful_share = true;
        expect(variables.policy.evaluate(input).eligible).toBeFalse();
        input = evidence();
        input.current_stage_recovery = "possibly_sent";
        expect(variables.policy.evaluate(input).eligible).toBeFalse();
      });
    });
  }

  private struct function evidence(string stage = "A") {
    return {
      account_exists = true,
      stage = arguments.stage,
      highest_verified_stage = arguments.stage,
      has_successful_share = false,
      verification = {
        stage_history = true, activity_coverage = true, sharing_history = true,
        recovery_history = true, ownership = true, lifecycle = true
      },
      exclusions = {
        opt_out = false, administrator_or_test = false, invalid_recipient = false,
        active_trip_or_monitoring = false, contradictory_lifecycle = false, other = false
      },
      current_stage_recovery = "never_sent",
      now_utc = "2026-09-08T00:00:00Z",
      enrollment_utc = "2026-09-01T00:00:00Z",
      current_stage_entered_utc = "2026-09-01T00:00:00Z",
      latest_activity = {state = "none_verified"},
      last_recovery = {state = "never_sent"}
    };
  }

  private struct function activity() {
    return {
      entity = "vessel", operation = "save", changed = true,
      successful = true, member_initiated = true, owned = true, persisted = true
    };
  }
}
