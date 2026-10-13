component extends="testbox.system.BaseSpec" output="false" {
  variables.datasource = "fpw";
  variables.fixtures = [];

  function run() {
    describe("Companion pairing status", function() {
      beforeEach(function() {
        variables.fixtures = [];
        variables.service = new fpw.api.v1.CompanionAuthService().init(variables.datasource);
        variables.f = createFixture();
      });
      afterEach(function() { cleanupFixtures(); });

      it("returns exact authoritative metadata without requiring a trip", function() {
        var response = status();
        expect(response.status).toBe(200);
        expect(response.body.SUCCESS).toBeTrue();
        expect(response.body.AUTH).toBeTrue();
        expect(response.body.DEVICE.id).toBe(f.deviceId);
        expect(response.body.DEVICE.userId).toBe(f.userId);
        expect(response.body.DEVICE.deviceUuid).toBe(f.deviceUuid);
        expect(response.body.DEVICE.deviceName).toBe("Pairing status fixture");
        expect(response.body.DEVICE.platform).toBe("web");
        expect(response.body.DEVICE.appVersion).toBe("pairing-status-test");
        expect(response.body.EXPIRES_AT_UTC).toBe(f.expiresAtUtc);
        expect(response.body.DEVICE.expiresAtUtc).toBe(f.expiresAtUtc);
        expect(val(q("SELECT COUNT(*) n FROM floatplans WHERE userId=:u", {u=txt(f.userId)}).n[1])).toBe(0);
      });
      it("supports the current-device alias", function() {
        expect(httpCall("current-device", "GET", {}, "Bearer " & f.token).body.SUCCESS).toBeTrue();
      });
      it("does not update usage or any device record during status reads", function() {
        var before = deviceSnapshot();
        status(); status();
        expect(deviceSnapshot()).toBe(before);
      });
      it("accepts existing manual-check-in scopes without adding tracking scope", function() {
        q("UPDATE companion_devices SET scopes='companion:current,companion:checkin' WHERE id=:id", {id=num(f.deviceId)});
        var before = deviceSnapshot();
        var response = status().body;
        expect(response.SUCCESS).toBeTrue();
        expect(response.DEVICE.scopes).toBe("companion:current,companion:checkin");
        expect(deviceSnapshot()).toBe(before);
      });
      it("rejects a missing bearer", function() {
        expectFailure(httpCall("currentDevice", "GET"), "TOKEN_MISSING");
      });
      it("rejects a malformed bearer", function() {
        expectFailure(httpCall("currentDevice", "GET", {}, "Basic invalid"), "TOKEN_INVALID");
      });
      it("rejects an unknown bearer", function() {
        expectFailure(httpCall("currentDevice", "GET", {}, "Bearer fpwc_unknown.invalid"), "TOKEN_INVALID");
      });
      it("rejects an expired pairing without mutating the record", function() {
        q("UPDATE companion_devices SET expires_at_utc=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 1 SECOND) WHERE id=:id", {id=num(f.deviceId)});
        var before = deviceSnapshot();
        expectFailure(status(), "TOKEN_EXPIRED");
        expect(deviceSnapshot()).toBe(before);
      });
      it("preserves the existing inactivity expiration check", function() {
        q("UPDATE companion_devices SET last_used_at_utc=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 31 DAY) WHERE id=:id", {id=num(f.deviceId)});
        expectFailure(status(), "TOKEN_EXPIRED");
      });
      it("detects server-side owner revocation", function() {
        expect(service.revokeDevice(f.userId, f.deviceId, "disposable pairing test").SUCCESS).toBeTrue();
        expectFailure(status(), "TOKEN_REVOKED");
      });
      it("detects manual disconnection through revoke-current", function() {
        var response = httpCall("revoke-current", "POST", {reason="disposable pairing test"}, "Bearer " & f.token);
        expect(response.body.SUCCESS).toBeTrue();
        expectFailure(status(), "TOKEN_REVOKED");
      });
      it("does not accept an authenticated web session in place of a bearer", function() {
        var hadUser = structKeyExists(session, "user");
        var savedUser = hadUser ? duplicate(session.user) : {};
        try {
          session.user = {USERID=f.userId};
          var body = "";
          savecontent variable="body" { new fpw.api.v1.companionAuth().handle(action="currentDevice"); }
          var response = deserializeJSON(body);
          expect(response.SUCCESS).toBeFalse();
          expect(response.AUTH).toBeFalse();
          expect(response.ERROR).toBe("TOKEN_MISSING");
        } finally {
          if (hadUser) session.user = savedUser; else structDelete(session, "user");
        }
      });
      it("rejects POST for current-device reads", function() {
        expectFailure(httpCall("currentDevice", "POST", {}, "Bearer " & f.token), "METHOD_NOT_ALLOWED");
      });
      it("does not expose the bearer, prefix, hash, or credential fields", function() {
        var response = status();
        var stored = q("SELECT token_hash,token_prefix FROM companion_devices WHERE id=:id", {id=num(f.deviceId)});
        expect(findNoCase(f.token, response.raw) GT 0).toBeFalse();
        expect(findNoCase(stored.token_hash[1], response.raw) GT 0).toBeFalse();
        expect(findNoCase(stored.token_prefix[1], response.raw) GT 0).toBeFalse();
        expect(reFindNoCase('"(TOKEN|TOKEN_TYPE|TOKEN_PREFIX|TOKEN_HASH|TOKENPREFIX|TOKENHASH)"[[:space:]]*:', response.raw) GT 0).toBeFalse();
      });
      it("returns unavailable optional metadata as empty rather than inventing it", function() {
        q("UPDATE companion_devices SET device_uuid=NULL,device_name=NULL,platform=NULL,app_version=NULL WHERE id=:id", {id=num(f.deviceId)});
        var response = status().body;
        expect(response.SUCCESS).toBeTrue();
        for (var key in ["deviceUuid","deviceName","platform","appVersion"]) expect(response.DEVICE[key]).toBe("");
      });
      it("preserves device ownership on revocation", function() {
        var other = createFixture();
        expect(service.revokeDevice(other.userId, f.deviceId, "wrong owner").ERROR).toBe("DEVICE_NOT_FOUND");
        expect(status().body.SUCCESS).toBeTrue();
      });
      it("keeps independent bearer device records scoped to their owners", function() {
        var other = createFixture();
        var first = status().body;
        var second = httpCall("currentDevice", "GET", {}, "Bearer " & other.token).body;
        expect(first.DEVICE.id).toBe(f.deviceId);
        expect(first.DEVICE.userId).toBe(f.userId);
        expect(second.DEVICE.id).toBe(other.deviceId);
        expect(second.DEVICE.userId).toBe(other.userId);
      });
      it("preserves existing bearer resolver defaults", function() {
        var response = service.resolveBearerToken("Bearer " & f.token);
        expect(response.SUCCESS).toBeTrue();
        expect(structKeyExists(response, "DEVICE")).toBeFalse();
        expect(val(q("SELECT CASE WHEN last_used_at_utc IS NOT NULL THEN 1 ELSE 0 END used FROM companion_devices WHERE id=:id", {id=num(f.deviceId)}).used[1])).toBe(1);
      });
      it("preserves single-use pairing codes after real HTTP exchange", function() {
        var response = httpCall("exchange-pairing-code", "POST", {pairingCode=f.pairingCode,device={deviceUuid=uuid()}});
        expect(response.body.SUCCESS).toBeFalse();
        expect(response.body.ERROR).toBe("PAIRING_CODE_USED");
        expect(status().body.SUCCESS).toBeTrue();
      });
    });
  }

  private any function q(required string sql, struct params={}) {
    return queryExecute(arguments.sql, arguments.params, {datasource=variables.datasource});
  }
  private struct function num(required any value) { return {value=val(arguments.value),cfsqltype="cf_sql_bigint"}; }
  private struct function txt(required any value) { return {value=toString(arguments.value),cfsqltype="cf_sql_varchar"}; }
  private string function uuid() { return lcase(createObject("java","java.util.UUID").randomUUID().toString()); }
  private struct function status() { return httpCall("currentDevice", "GET", {}, "Bearer " & f.token); }
  private string function deviceSnapshot() {
    return hash(serializeJSON(q("SELECT * FROM companion_devices WHERE id=:id", {id=num(f.deviceId)})), "SHA-256");
  }
  private void function expectFailure(required struct response, required string code) {
    expect(arguments.response.status).toBe(200);
    expect(arguments.response.body.SUCCESS).toBeFalse();
    expect(arguments.response.body.AUTH).toBeFalse();
    expect(arguments.response.body.ERROR).toBe(arguments.code);
    expect(structKeyExists(arguments.response.body, "DEVICE")).toBeFalse();
  }
  private struct function httpCall(required string action, required string method, struct payload={}, string authorization="") {
    var result = {};
    cfhttp(url="http://127.0.0.1:8500/fpw/api/v1/companionAuth.cfc?method=handle&returnFormat=json&action=" & arguments.action,
      method=arguments.method, result="result", redirect=false, timeout=30) {
      if (len(arguments.authorization)) cfhttpparam(type="header", name="Authorization", value=arguments.authorization);
      if (arguments.method == "GET") for (var key in arguments.payload) {
        cfhttpparam(type="url", name=key, value=toString(arguments.payload[key]));
      }
      if (arguments.method == "POST") {
        cfhttpparam(type="header", name="Content-Type", value="application/json");
        cfhttpparam(type="body", value=serializeJSON(arguments.payload));
      }
    }
    expect(isJSON(result.fileContent), "Companion auth response must be JSON").toBeTrue();
    return {status=val(result.statusCode),body=deserializeJSON(result.fileContent),raw=toString(result.fileContent)};
  }
  private struct function createFixture() {
    var item = {userId=0,email="codex-pairing-status-" & replace(uuid(),"-","","all") & "@example.test",deviceUuid=uuid()};
    arrayAppend(variables.fixtures, item);
    q("INSERT INTO users(fName,lName,email,password,passwordCreated,created) VALUES('Pairing','Disposable',:email,:password,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
      {email=txt(item.email),password=txt(new fpw.api.v1.PasswordHashService().hashPassword(uuid() & "!Fixture"))});
    item.userId = val(q("SELECT userId FROM users WHERE email=:email", {email=txt(item.email)}).userId[1]);
    var code = service.createPairingCode(item.userId);
    expect(code.SUCCESS).toBeTrue();
    item.pairingCode = code.PAIRING_CODE;
    var paired = httpCall("exchange-pairing-code", "POST", {pairingCode=item.pairingCode,
      device={deviceUuid=item.deviceUuid,deviceName="Pairing status fixture",platform="web",appVersion="pairing-status-test"}}).body;
    expect(paired.SUCCESS).toBeTrue();
    item.deviceId = paired.DEVICE.id;
    item.token = paired.TOKEN;
    item.expiresAtUtc = paired.EXPIRES_AT_UTC;
    return item;
  }
  private void function cleanupFixtures() {
    for (var item in variables.fixtures) {
      if (item.userId LTE 0) continue;
      var params = {u=num(item.userId),email=txt(item.email)};
      if (q("SELECT userId FROM users WHERE userId=:u AND email=:email", params).recordCount NEQ 1) {
        throw(type="FPW.PairingFixture.Scope", message="Disposable pairing fixture identity check failed.");
      }
      q("DELETE FROM companion_pairing_codes WHERE user_id=:u", params);
      q("DELETE FROM companion_devices WHERE user_id=:u", params);
      q("DELETE FROM users WHERE userId=:u AND email=:email", params);
    }
    variables.fixtures = [];
  }
}
