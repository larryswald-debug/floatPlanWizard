component extends="testbox.system.BaseSpec" {

  variables.datasource = "fpw";
  variables.fixtureBasePrefix = "codex.qa1001.";
  variables.fixturePrefix = variables.fixtureBasePrefix;

  function beforeAll() {
    variables.runMarker = lCase(replace(createUUID(), "-", "", "all"));
    variables.runStartedAt = now();
    variables.sensitiveProbes = [];
    variables.fixturePrefix = variables.fixturePrefix & variables.runMarker & ".";
    variables.passwordService = createObject(
      "component",
      "fpw.api.v1.PasswordHashService"
    ).init();
    variables.secrets = {
      signup = "Qa1!" & replace(createUUID(), "-", "", "all"),
      shared = "Qa1!" & replace(createUUID(), "-", "", "all"),
      legacy = "Qa1!" & replace(createUUID(), "-", "", "all"),
      legacyWrong = "Qa1!" & replace(createUUID(), "-", "", "all"),
      plaintext = "Qa1!" & replace(createUUID(), "-", "", "all"),
      resetOld = "Qa1!" & replace(createUUID(), "-", "", "all"),
      resetNew = "Qa1!" & replace(createUUID(), "-", "", "all"),
      changeOld = "Qa1!" & replace(createUUID(), "-", "", "all"),
      changeNew = "Qa1!" & replace(createUUID(), "-", "", "all")
    };
    for (var secretName in variables.secrets) {
      appendSensitiveProbe(variables.secrets[secretName]);
    }
    cleanupFixtures();
  }

  function afterAll() {
    cleanupFixtures();
    structClear(variables.secrets);
    arrayClear(variables.sensitiveProbes);
  }

  function run() {
    describe("QA1-001 adaptive password storage and migration", function() {

      it("stores a new signup only in the adaptive format", function() {
        var email = fixtureEmail("signup");
        var signup = postJson(
          "/api/v1/join.cfc?method=handle",
          {
            firstName = "Codex",
            lastName = "QA1001 Signup",
            email = email,
            password = variables.secrets.signup,
            confirmPassword = variables.secrets.signup,
            termsAccepted = true,
            website = ""
          }
        );
        var stored = loadStoredPassword(email);
        appendSensitiveProbe(stored);

        expect(signup.payload.SUCCESS).toBeTrue();
        expect(variables.passwordService.detectPasswordFormat(stored)).toBe("ADAPTIVE");
        expect(stored == variables.secrets.signup).toBeFalse();
        expect(reFindNoCase("^[0-9a-f]{64}$", stored)).toBe(0);
      });

      it("uses unique random salts for the same password", function() {
        var first = createFixtureUser(
          "same-password-1",
          variables.passwordService.hashPassword(variables.secrets.shared)
        );
        var second = createFixtureUser(
          "same-password-2",
          variables.passwordService.hashPassword(variables.secrets.shared)
        );
        var firstLogin = login(first.email, variables.secrets.shared);
        var secondLogin = login(second.email, variables.secrets.shared);

        expect(firstLogin.payload.SUCCESS).toBeTrue();
        expect(secondLogin.payload.SUCCESS).toBeTrue();
        expect(first.storedPassword == second.storedPassword).toBeFalse();
        expect(variables.passwordService.verifyPassword(
          variables.secrets.shared,
          first.storedPassword
        )).toBeTrue();
        expect(variables.passwordService.verifyPassword(
          variables.secrets.shared,
          second.storedPassword
        )).toBeTrue();
      });

      it("accepts the correct adaptive password and rejects the wrong password", function() {
        var email = fixtureEmail("adaptive-login");
        var original = variables.passwordService.hashPassword(variables.secrets.signup);
        createFixtureUser("adaptive-login", original);

        var correct = login(email, variables.secrets.signup);
        var wrong = login(email, variables.secrets.legacyWrong);
        var afterLogin = loadStoredPassword(email);

        expect(correct.payload.SUCCESS).toBeTrue();
        expect(wrong.payload.SUCCESS).toBeFalse();
        expect(afterLogin).toBe(original);
        expect(variables.passwordService.detectPasswordFormat(afterLogin)).toBe("ADAPTIVE");
      });

      it("migrates a verified legacy SHA-256 login exactly once", function() {
        var email = fixtureEmail("legacy-migrate");
        var legacyHash = uCase(hash(variables.secrets.legacy, "SHA-256", "UTF-8"));
        createFixtureUser("legacy-migrate", legacyHash);

        expect(variables.passwordService.detectPasswordFormat(
          loadStoredPassword(email)
        )).toBe("LEGACY_SHA256");

        var firstLogin = login(email, variables.secrets.legacy);
        var migrated = loadStoredPassword(email);
        var secondLogin = login(email, variables.secrets.legacy);
        var afterSecondLogin = loadStoredPassword(email);

        expect(firstLogin.payload.SUCCESS).toBeTrue();
        expect(migrated == legacyHash).toBeFalse();
        expect(variables.passwordService.detectPasswordFormat(migrated)).toBe("ADAPTIVE");
        expect(secondLogin.payload.SUCCESS).toBeTrue();
        expect(afterSecondLogin).toBe(migrated);
      });

      it("does not migrate a legacy SHA-256 row after a wrong password", function() {
        var email = fixtureEmail("legacy-wrong");
        var legacyHash = uCase(hash(variables.secrets.legacy, "SHA-256", "UTF-8"));
        createFixtureUser("legacy-wrong", legacyHash);

        var loginResult = login(email, variables.secrets.legacyWrong);

        expect(loginResult.payload.SUCCESS).toBeFalse();
        expect(loadStoredPassword(email)).toBe(legacyHash);
      });

      it("never authenticates a plaintext-like stored value by direct equality", function() {
        var email = fixtureEmail("plaintext-rejected");
        createFixtureUser("plaintext-rejected", variables.secrets.plaintext);

        var loginResult = login(email, variables.secrets.plaintext);

        expect(loginResult.payload.SUCCESS).toBeFalse();
        expect(loadStoredPassword(email)).toBe(variables.secrets.plaintext);
        expect(variables.passwordService.detectPasswordFormat(
          loadStoredPassword(email)
        )).toBe("LEGACY_PLAINTEXT_OR_UNKNOWN");
      });

      it("stores only an adaptive password after reset completion", function() {
        var email = fixtureEmail("password-reset");
        var token = "qa1001-reset-" & variables.runMarker;
        appendSensitiveProbe(token);
        var fixture = createFixtureUser(
          "password-reset",
          variables.passwordService.hashPassword(variables.secrets.resetOld)
        );

        queryExecute(
          "UPDATE users
           SET resetTokenHash = :tokenHash,
               resetRequestedAt = UTC_TIMESTAMP(),
               resetExpiresAt = DATE_ADD(UTC_TIMESTAMP(), INTERVAL 30 MINUTE),
               requestReset = 1
           WHERE userId = :userId",
          {
            tokenHash = {
              value = uCase(hash(token, "SHA-256", "UTF-8")),
              cfsqltype = "cf_sql_char"
            },
            userId = { value = fixture.userId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = variables.datasource }
        );

        var resetResult = postJson(
          "/api/v1/password_reset.cfc?method=handle",
          {
            action = "confirm",
            token = token,
            newPassword = variables.secrets.resetNew
          }
        );
        var stored = loadStoredPassword(email);
        appendSensitiveProbe(stored);
        var oldLogin = login(email, variables.secrets.resetOld);
        var newLogin = login(email, variables.secrets.resetNew);
        var resetState = queryExecute(
          "SELECT resetTokenHash, resetExpiresAt
           FROM users
           WHERE userId = :userId",
          { userId = { value = fixture.userId, cfsqltype = "cf_sql_integer" } },
          { datasource = variables.datasource }
        );

        expect(resetResult.payload.SUCCESS).toBeTrue();
        expect(variables.passwordService.detectPasswordFormat(stored)).toBe("ADAPTIVE");
        expect(oldLogin.payload.SUCCESS).toBeFalse();
        expect(newLogin.payload.SUCCESS).toBeTrue();
        expect(len(toString(resetState.resetTokenHash[1] ?: ""))).toBe(0);
        expect(len(toString(resetState.resetExpiresAt[1] ?: ""))).toBe(0);
      });

      it("stores only an adaptive password after an authenticated password change", function() {
        var email = fixtureEmail("password-change");
        createFixtureUser(
          "password-change",
          variables.passwordService.hashPassword(variables.secrets.changeOld)
        );

        var authenticated = login(email, variables.secrets.changeOld);
        var changed = postJson(
          "/api/v1/profile.cfc?method=handle",
          {
            action = "changepassword",
            currentPassword = variables.secrets.changeOld,
            newPassword = variables.secrets.changeNew
          },
          authenticated.cookie
        );
        var stored = loadStoredPassword(email);
        appendSensitiveProbe(stored);
        var oldLogin = login(email, variables.secrets.changeOld);
        var newLogin = login(email, variables.secrets.changeNew);

        expect(authenticated.payload.SUCCESS).toBeTrue();
        expect(len(authenticated.cookie)).toBeGT(0);
        expect(changed.payload.SUCCESS).toBeTrue();
        expect(variables.passwordService.detectPasswordFormat(stored)).toBe("ADAPTIVE");
        expect(oldLogin.payload.SUCCESS).toBeFalse();
        expect(newLogin.payload.SUCCESS).toBeTrue();

        var legacyFixture = createFixtureUser(
          "password-change-legacy",
          variables.passwordService.hashPassword(variables.secrets.changeOld)
        );
        var legacyAuthenticated = login(
          legacyFixture.email,
          variables.secrets.changeOld
        );
        var legacyCurrentHash = uCase(
          hash(variables.secrets.changeOld, "SHA-256", "UTF-8")
        );
        appendSensitiveProbe(legacyCurrentHash);
        queryExecute(
          "UPDATE users
           SET password = :password
           WHERE userId = :userId",
          {
            password = {
              value = legacyCurrentHash,
              cfsqltype = "cf_sql_varchar"
            },
            userId = {
              value = legacyFixture.userId,
              cfsqltype = "cf_sql_integer"
            }
          },
          { datasource = variables.datasource }
        );
        var legacyChanged = postJson(
          "/api/v1/profile.cfc?method=handle",
          {
            action = "changepassword",
            currentPassword = variables.secrets.changeOld,
            newPassword = variables.secrets.changeNew
          },
          legacyAuthenticated.cookie
        );
        var legacyStored = loadStoredPassword(legacyFixture.email);
        appendSensitiveProbe(legacyStored);
        var legacyOldLogin = login(
          legacyFixture.email,
          variables.secrets.changeOld
        );
        var legacyNewLogin = login(
          legacyFixture.email,
          variables.secrets.changeNew
        );

        expect(legacyAuthenticated.payload.SUCCESS).toBeTrue();
        expect(legacyChanged.payload.SUCCESS).toBeTrue();
        expect(variables.passwordService.detectPasswordFormat(
          legacyStored
        )).toBe("ADAPTIVE");
        expect(legacyOldLogin.payload.SUCCESS).toBeFalse();
        expect(legacyNewLogin.payload.SUCCESS).toBeTrue();
      });

      it("keeps every active password path on the centralized service contract", function() {
        var authSource = readRepoFile("api/v1/auth.cfc");
        var joinSource = readRepoFile("api/v1/join.cfc");
        var profileSource = readRepoFile("api/v1/profile.cfc");
        var resetSource = readRepoFile("api/v1/password_reset.cfc");

        expect(findNoCase("PasswordHashService", authSource)).toBeGT(0);
        expect(findNoCase("PasswordHashService", joinSource)).toBeGT(0);
        expect(findNoCase("PasswordHashService", profileSource)).toBeGT(0);
        expect(findNoCase("PasswordHashService", resetSource)).toBeGT(0);
        expect(findNoCase("password EQ dbPassword", authSource)).toBe(0);
        expect(findNoCase("currentPassword EQ dbPassword", profileSource)).toBe(0);
        expect(findNoCase('hash(password, "SHA-256"', joinSource)).toBe(0);
        expect(findNoCase('hash(newPassword, "SHA-256"', profileSource)).toBe(0);
        expect(findNoCase('hash(newPassword, "SHA-256"', resetSource)).toBe(0);
      });

      it("does not write password material to ColdFusion logs", function() {
        var logDirectory = "/opt/coldfusion/cfusion/logs";
        var logFiles = directoryList(
          logDirectory,
          false,
          "query",
          "*.log"
        );
        var scanThreshold = dateAdd("n", -1, variables.runStartedAt);
        var scannedFiles = 0;
        var leakDetected = false;
        var logIndex = 0;
        var logText = "";
        var probeValue = "";

        for (logIndex = 1; logIndex LTE logFiles.recordCount; logIndex++) {
          if (
            dateCompare(
              logFiles.dateLastModified[logIndex],
              scanThreshold
            ) LT 0
          ) {
            continue;
          }
          scannedFiles++;
          logText = fileRead(
            logFiles.directory[logIndex]
              & "/"
              & logFiles.name[logIndex],
            "UTF-8"
          );
          for (probeValue in variables.sensitiveProbes) {
            if (len(probeValue) GTE 8 && find(probeValue, logText)) {
              leakDetected = true;
              break;
            }
          }
          if (leakDetected) {
            break;
          }
        }

        expect(scannedFiles).toBeGT(0);
        expect(leakDetected).toBeFalse();
      });

    });
  }

  private void function appendSensitiveProbe(required string probeValue) {
    var normalizedProbe = toString(arguments.probeValue);
    if (
      len(normalizedProbe)
      && !arrayFind(variables.sensitiveProbes, normalizedProbe)
    ) {
      arrayAppend(variables.sensitiveProbes, normalizedProbe);
    }
  }

  private struct function login(required string email, required string password) {
    return postJson(
      "/api/v1/auth.cfc?method=handle",
      { email = arguments.email, password = arguments.password }
    );
  }

  private struct function postJson(
    required string path,
    required struct payload,
    string cookie = ""
  ) {
    var httpResult = {};
    var endpointPath = arguments.path;
    if (
      reFindNoCase("\.cfc(\?|$)", endpointPath)
      && !reFindNoCase("returnformat=", endpointPath)
    ) {
      endpointPath &= (find("?", endpointPath) ? "&" : "?") & "returnFormat=json";
    }
    cfhttp(
      url = "http://localhost:8500/fpw" & endpointPath,
      method = "POST",
      timeout = 60,
      throwOnError = false,
      result = "httpResult"
    ) {
      cfhttpparam(type = "header", name = "Content-Type", value = "application/json");
      cfhttpparam(type = "header", name = "Accept", value = "application/json");
      if (len(arguments.cookie)) {
        cfhttpparam(type = "header", name = "Cookie", value = arguments.cookie);
      }
      cfhttpparam(type = "body", value = serializeJSON(arguments.payload));
    }

    var responseText = toString(httpResult.fileContent ?: "");
    if (!isJSON(responseText)) {
      var safePrefix = reReplace(
        left(trim(responseText), 24),
        "[^A-Za-z0-9<>{}/:._-]",
        "?",
        "all"
      );
      throw(
        type = "FPW.PasswordStorageSecurity.InvalidJson",
        message = "An authentication endpoint returned a non-JSON response.",
        detail = "HTTP status "
          & toString(httpResult.statusCode ?: "unknown")
          & "; response length "
          & len(responseText)
          & "; safe prefix "
          & safePrefix
      );
    }

    return {
      statusCode = val(listFirst(toString(httpResult.statusCode ?: "0"), " ")),
      payload = deserializeJSON(responseText),
      cookie = extractSessionCookie(httpResult)
    };
  }

  private string function extractSessionCookie(required struct httpResult) {
    if (
      !structKeyExists(arguments.httpResult, "responseHeader")
      || !structKeyExists(arguments.httpResult.responseHeader, "Set-Cookie")
    ) {
      return "";
    }

    var rawCookieHeader = arguments.httpResult.responseHeader["Set-Cookie"];
    var headerEntries = [];
    var headerKey = "";
    var headerEntry = "";
    var pairText = "";
    var equalPosition = 0;
    var cookieName = "";
    var cookieValue = "";
    var cookieValues = {};
    var cookies = [];

    if (isSimpleValue(rawCookieHeader)) {
      arrayAppend(headerEntries, rawCookieHeader);
    } else if (isArray(rawCookieHeader)) {
      headerEntries = rawCookieHeader;
    } else if (isStruct(rawCookieHeader)) {
      for (headerKey in rawCookieHeader) {
        if (isSimpleValue(rawCookieHeader[headerKey])) {
          arrayAppend(headerEntries, rawCookieHeader[headerKey]);
        }
      }
    }

    for (headerEntry in headerEntries) {
      pairText = trim(listFirst(toString(headerEntry), ";"));
      equalPosition = find("=", pairText);
      if (equalPosition LTE 1) {
        continue;
      }
      cookieName = trim(left(pairText, equalPosition - 1));
      cookieValue = trim(mid(pairText, equalPosition + 1, len(pairText)));
      if (
        listFindNoCase("JSESSIONID,CFID,CFTOKEN", cookieName)
        && len(cookieValue)
      ) {
        cookieValues[cookieName] = cookieValue;
      }
    }

    for (cookieName in ["JSESSIONID", "CFID", "CFTOKEN"]) {
      if (structKeyExists(cookieValues, cookieName)) {
        arrayAppend(cookies, cookieName & "=" & cookieValues[cookieName]);
      }
    }
    return arrayToList(cookies, "; ");
  }

  private struct function createFixtureUser(
    required string label,
    required string storedPassword
  ) {
    var email = fixtureEmail(arguments.label);
    appendSensitiveProbe(arguments.storedPassword);
    queryExecute(
      "INSERT INTO users (
         fName, lName, email, password, passwordCreated, created, lastUpdate
       ) VALUES (
         'Codex', :lastName, :email, :password,
         UTC_TIMESTAMP(), UTC_TIMESTAMP(), UTC_TIMESTAMP()
       )",
      {
        lastName = {
          value = left("QA1001 " & arguments.label, 45),
          cfsqltype = "cf_sql_varchar"
        },
        email = { value = email, cfsqltype = "cf_sql_varchar" },
        password = {
          value = arguments.storedPassword,
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );

    var qUser = queryExecute(
      "SELECT userId, password
       FROM users
       WHERE email = :email
       LIMIT 1",
      { email = { value = email, cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );
    if (qUser.recordCount != 1) {
      throw(
        type = "FPW.PasswordStorageSecurity.FixtureFailed",
        message = "A disposable password-security user was not created."
      );
    }

    return {
      userId = val(qUser.userId[1]),
      email = email,
      storedPassword = toString(qUser.password[1])
    };
  }

  private string function loadStoredPassword(required string email) {
    var qUser = queryExecute(
      "SELECT password
       FROM users
       WHERE email = :email
       LIMIT 1",
      { email = { value = arguments.email, cfsqltype = "cf_sql_varchar" } },
      { datasource = variables.datasource }
    );
    if (qUser.recordCount != 1) {
      throw(
        type = "FPW.PasswordStorageSecurity.UserNotFound",
        message = "The disposable password-security user was not found."
      );
    }
    return toString(qUser.password[1]);
  }

  private string function fixtureEmail(required string label) {
    return variables.fixturePrefix & lCase(arguments.label) & "@example.test";
  }

  private string function readRepoFile(required string relativePath) {
    return fileRead(expandPath("/fpw/" & arguments.relativePath), "utf-8");
  }

  private void function cleanupFixtures() {
    var qUsers = queryExecute(
      "SELECT userId
       FROM users
       WHERE email LIKE :emailPattern",
      {
        emailPattern = {
          value = variables.fixtureBasePrefix & "%",
          cfsqltype = "cf_sql_varchar"
        }
      },
      { datasource = variables.datasource }
    );
    if (!qUsers.recordCount) {
      return;
    }

    var userIds = valueList(qUsers.userId);
    var idParam = {
      value = userIds,
      cfsqltype = "cf_sql_integer",
      list = true
    };

    queryExecute(
      "DELETE FROM product_events WHERE user_id IN (:userIds)",
      { userIds = idParam },
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM premium_send_credits WHERE user_id IN (:userIds)",
      { userIds = idParam },
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM member_entitlements WHERE user_id IN (:userIds)",
      { userIds = idParam },
      { datasource = variables.datasource }
    );
    queryExecute(
      "DELETE FROM users WHERE userId IN (:userIds)",
      { userIds = idParam },
      { datasource = variables.datasource }
    );
  }
}
