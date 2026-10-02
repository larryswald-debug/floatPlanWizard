component extends="testbox.system.BaseSpec" output=false {
  // Only run through the local, explicitly confirmed mutation runner after migration 001.
  function run() {
    describe("Database authentication rate counters", function() {
      beforeEach(function() {
        variables.rate = new fpw.api.v1.AuthRateLimitService().init("fpw");
        variables.email = "auth-rate-" & lCase(replace(createUUID(),"-","","all")) & "@test.invalid";
        variables.ip = "198.18." & randRange(1,254) & "." & randRange(1,254);
        variables.allBuckets = [];
        for (var action in ["authenticate","create_account","reset_request","reset_confirm","change_password"]) {
          for (var bucket in variables.rate.buildBuckets(action,variables.email,variables.ip)) arrayAppend(variables.allBuckets,bucket);
        }
        if (!variables.rate.isSchemaReady()) throw(type="FPW.Test.SchemaRequired",message="Apply approved auth rate migration before this integration suite.");
      });
      afterEach(function() {
        for (var bucket in variables.allBuckets) {
          queryExecute("DELETE FROM auth_rate_counters WHERE action_group=:actionGroup AND subject_scope=:scope AND subject_hash=UNHEX(:subjectHash)",
            paramsFor(bucket),{datasource="fpw"});
        }
      });
      it("reserves in-flight attempts atomically and preserves counters across service instances",function() {
        var attempts = [];
        for (var i=1;i<=5;i++) {
          var result = variables.rate.admit("change_password",variables.email,variables.ip);
          expect(result.ALLOWED).toBeTrue();
          arrayAppend(attempts,result.TICKET);
        }
        var restarted = new fpw.api.v1.AuthRateLimitService().init("fpw");
        var blocked = restarted.admit("change_password",variables.email,variables.ip);
        expect(blocked.ALLOWED).toBeFalse();
        expect(blocked.STATUSCODE).toBe(429);
        expect(blocked.RETRYAFTER > 0).toBeTrue();
        expect(restarted.finish(attempts[1],"error")).toBeTrue();
        expect(restarted.finish(attempts[1],"error")).toBeFalse();
        var released = restarted.admit("change_password",variables.email,variables.ip);
        expect(released.ALLOWED).toBeTrue();
        for (var ticket in attempts) restarted.finish(ticket,"error");
        restarted.finish(released.TICKET,"error");
      });
      it("releases a first successful request with zero failures in every bucket",function() {
        for (var action in ["authenticate","create_account","reset_request","reset_confirm","change_password"]) {
          var admitted = variables.rate.admit(action,variables.email,variables.ip);
          expect(admitted.ALLOWED).toBeTrue();
          expect(variables.rate.finish(admitted.TICKET,"success")).toBeTrue();
          for (var bucket in admitted.TICKET.buckets) {
            var row = queryExecute("SELECT failure_count,inflight_count,admitted_count FROM auth_rate_counters
              WHERE action_group=:actionGroup AND subject_scope=:scope AND subject_hash=UNHEX(:subjectHash)",
              paramsFor(bucket),{datasource="fpw"});
            expect(row.failure_count[1]).toBe(0);
            expect(row.inflight_count[1]).toBe(0);
            expect(row.admitted_count[1]).toBe(1);
          }
        }
      });
      it("retains failure limits but successful authentication reduces applicable failures",function() {
        for (var i=1;i<=4;i++) {
          var failed = variables.rate.admit("change_password",variables.email,variables.ip);
          expect(failed.ALLOWED).toBeTrue();
          variables.rate.finish(failed.TICKET,"failure");
        }
        var success = variables.rate.admit("change_password",variables.email,variables.ip);
        expect(success.ALLOWED).toBeTrue();
        variables.rate.finish(success.TICKET,"success");
        var one = variables.rate.admit("change_password",variables.email,variables.ip);
        var two = variables.rate.admit("change_password",variables.email,variables.ip);
        var blocked = variables.rate.admit("change_password",variables.email,variables.ip);
        expect(one.ALLOWED).toBeTrue();
        expect(two.ALLOWED).toBeTrue();
        expect(blocked.STATUSCODE).toBe(429);
        variables.rate.finish(one.TICKET,"error");
        variables.rate.finish(two.TICKET,"error");
      });
      it("does not reset reset-email volume after success",function() {
        for (var i=1;i<=3;i++) {
          var admitted = variables.rate.admit("reset_request",variables.email,variables.ip);
          expect(admitted.ALLOWED).toBeTrue();
          variables.rate.finish(admitted.TICKET,"success");
        }
        expect(variables.rate.admit("reset_request",variables.email,variables.ip).STATUSCODE).toBe(429);
      });
      it("expires fixed windows and ignores stale completion tickets",function() {
        var old = variables.rate.admit("change_password",variables.email,variables.ip);
        expect(old.ALLOWED).toBeTrue();
        for (var bucket in old.TICKET.buckets) {
          queryExecute("UPDATE auth_rate_counters SET window_started_at_utc=TIMESTAMPADD(HOUR,-2,UTC_TIMESTAMP(6)),
             expires_at_utc=TIMESTAMPADD(HOUR,-1,UTC_TIMESTAMP(6))
             WHERE action_group=:actionGroup AND subject_scope=:scope AND subject_hash=UNHEX(:subjectHash)",
             paramsFor(bucket),{datasource="fpw"});
        }
        var fresh = variables.rate.admit("change_password",variables.email,variables.ip);
        expect(fresh.ALLOWED).toBeTrue();
        variables.rate.finish(old.TICKET,"failure");
        for (var bucket in fresh.TICKET.buckets) {
          var row = queryExecute("SELECT failure_count,inflight_count,admitted_count FROM auth_rate_counters
            WHERE action_group=:actionGroup AND subject_scope=:scope AND subject_hash=UNHEX(:subjectHash)",
            paramsFor(bucket),{datasource="fpw"});
          expect(row.failure_count[1]).toBe(0);
          expect(row.inflight_count[1]).toBe(1);
          expect(row.admitted_count[1]).toBe(1);
        }
        variables.rate.finish(fresh.TICKET,"error");
      });
      it("does not over-admit concurrent callers beyond the pair limit",function() {
        var names = [];
        for (var i=1;i<=12;i++) {
          var name = "authrate" & replace(createUUID(),"-","","all");
          arrayAppend(names,name);
          thread action="run" name=name testEmail=variables.email testIp=variables.ip {
            thread.result = new fpw.api.v1.AuthRateLimitService().init("fpw").admit("change_password",attributes.testEmail,attributes.testIp);
          }
        }
        thread action="join" name=arrayToList(names) timeout=30000;
        var admitted = 0;
        for (var name in names) {
          expect(structKeyExists(cfthread[name],"result")).toBeTrue();
          if (cfthread[name].result.ALLOWED) admitted++;
        }
        expect(admitted).toBe(5);
        for (var name in names) {
          if (cfthread[name].result.ALLOWED) variables.rate.finish(cfthread[name].result.TICKET,"error");
        }
      });
      it("cleans expired counters after retention without extending a denied window",function() {
        var old = variables.rate.admit("create_account",variables.email,variables.ip);
        expect(old.ALLOWED).toBeTrue();
        variables.rate.finish(old.TICKET,"error");
        for (var bucket in old.TICKET.buckets) {
          queryExecute("UPDATE auth_rate_counters SET window_started_at_utc=TIMESTAMPADD(HOUR,-26,UTC_TIMESTAMP(6)),
             expires_at_utc=TIMESTAMPADD(HOUR,-25,UTC_TIMESTAMP(6))
             WHERE action_group=:actionGroup AND subject_scope=:scope AND subject_hash=UNHEX(:subjectHash)",
             paramsFor(bucket),{datasource="fpw"});
        }
        var trigger = variables.rate.admit("reset_confirm","",variables.ip);
        expect(trigger.ALLOWED).toBeTrue();
        variables.rate.finish(trigger.TICKET,"error");
        for (var bucket in old.TICKET.buckets) {
          var remaining = queryExecute("SELECT COUNT(*) AS n FROM auth_rate_counters
            WHERE action_group=:actionGroup AND subject_scope=:scope AND subject_hash=UNHEX(:subjectHash)",
            paramsFor(bucket),{datasource="fpw"});
          expect(remaining.n[1]).toBe(0);
        }
        var tickets = [];
        for (var i=1;i<=5;i++) arrayAppend(tickets,variables.rate.admit("change_password",variables.email,variables.ip).TICKET);
        var pair = tickets[1].buckets[3];
        var before = queryExecute("SELECT DATE_FORMAT(expires_at_utc,'%Y-%m-%d %H:%i:%s.%f') AS expiry FROM auth_rate_counters
          WHERE action_group=:actionGroup AND subject_scope=:scope AND subject_hash=UNHEX(:subjectHash)",paramsFor(pair),{datasource="fpw"});
        expect(variables.rate.admit("change_password",variables.email,variables.ip).STATUSCODE).toBe(429);
        var after = queryExecute("SELECT DATE_FORMAT(expires_at_utc,'%Y-%m-%d %H:%i:%s.%f') AS expiry FROM auth_rate_counters
          WHERE action_group=:actionGroup AND subject_scope=:scope AND subject_hash=UNHEX(:subjectHash)",paramsFor(pair),{datasource="fpw"});
        expect(after.expiry[1]).toBe(before.expiry[1]);
        for (var ticket in tickets) variables.rate.finish(ticket,"error");
      });
      it("fails closed when its database datasource is unavailable",function() {
        var unavailable = new fpw.api.v1.AuthRateLimitService().init("fpw_auth_nonexistent_test_datasource");
        var response = unavailable.admit("authenticate",variables.email,variables.ip);
        expect(response.ALLOWED).toBeFalse();
        expect(response.STATUSCODE).toBe(503);
        expect(response.CODE).toBe("AUTH_TEMPORARILY_UNAVAILABLE");
        expect(structIsEmpty(response.TICKET)).toBeTrue();
      });
      it("uses prelookup IP admission and separate account admission without doubling IP volume",function() {
        var ipTicket = variables.rate.admit("reset_confirm","",variables.ip);
        var accountTicket = variables.rate.admit("reset_confirm",variables.email,variables.ip,false);
        expect(ipTicket.ALLOWED).toBeTrue();
        expect(accountTicket.ALLOWED).toBeTrue();
        var row = queryExecute("SELECT admitted_count FROM auth_rate_counters
          WHERE action_group=:actionGroup AND subject_scope=:scope AND subject_hash=UNHEX(:subjectHash)",
          paramsFor(ipTicket.TICKET.buckets[1]),{datasource="fpw"});
        expect(row.admitted_count[1]).toBe(1);
        variables.rate.finish(ipTicket.TICKET,"error");
        variables.rate.finish(accountTicket.TICKET,"error");
      });
    });
  }
  private struct function paramsFor(required struct bucket) {
    return {actionGroup={value=arguments.bucket.actionGroup,cfsqltype="cf_sql_varchar"},
      scope={value=arguments.bucket.scope,cfsqltype="cf_sql_varchar"},
      subjectHash={value=arguments.bucket.subjectHash,cfsqltype="cf_sql_varchar"}};
  }
}
