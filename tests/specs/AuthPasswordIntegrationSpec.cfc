component extends="testbox.system.BaseSpec" output=false {
  // Isolated disposable users only; never call application signup, email, billing, or enrollment.
  function run() {
    describe("Password upgrade compare-and-swap",function() {
      beforeEach(function() {
        variables.passwords = new fpw.api.v1.PasswordHashService();
        variables.email = "auth-password-" & lCase(replace(createUUID(),"-","","all")) & "@test.invalid";
        variables.plain = "Disposable Legacy Password 42!";
        variables.observed = hash(variables.plain,"SHA-256","UTF-8");
        queryExecute("INSERT INTO users (email,password,passwordCreated,created)
          VALUES (:email,:password,'2000-01-01 00:00:00',UTC_TIMESTAMP())",
          {email={value=variables.email,cfsqltype="cf_sql_varchar"},
           password={value=variables.observed,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
        var user = queryExecute("SELECT userId FROM users WHERE email=:email",
          {email={value=variables.email,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
        variables.userId = val(user.userId[1]);
      });
      afterEach(function() {
        if (structKeyExists(variables,"userId") && variables.userId > 0) {
          queryExecute("DELETE FROM users WHERE userId=:id AND email=:email",
            {id={value=variables.userId,cfsqltype="cf_sql_integer"},
             email={value=variables.email,cfsqltype="cf_sql_varchar"}},{datasource="fpw"});
        }
      });
      it("upgrades legacy credentials without changing password-created time",function() {
        var result = variables.passwords.verifyAndUpgrade(variables.userId,variables.plain,variables.observed);
        expect(result.VERIFIED).toBeTrue();
        expect(result.UPGRADED).toBeTrue();
        var row = currentPassword();
        expect(variables.passwords.detectPasswordFormat(row.password[1])).toBe("ADAPTIVE");
        expect(variables.passwords.verifyPassword(variables.plain,row.password[1])).toBeTrue();
        expect(row.password_created[1]).toBe("2000-01-01 00:00:00");
      });
      it("does not overwrite or authenticate against an obsolete reset credential",function() {
        var replacement = variables.passwords.hashPassword("Different Reset Password 77!");
        setFixturePassword(replacement);
        var result = variables.passwords.verifyAndUpgrade(variables.userId,variables.plain,variables.observed);
        expect(result.VERIFIED).toBeFalse();
        expect(result.UPGRADED).toBeFalse();
        expect(compare(currentPassword().password[1],replacement)).toBe(0);
      });
      it("uses binary rather than case-insensitive compare-and-swap",function() {
        var lowercaseDigest = lCase(variables.observed);
        setFixturePassword(lowercaseDigest);
        var result = variables.passwords.verifyAndUpgrade(variables.userId,variables.plain,variables.observed);
        expect(result.VERIFIED).toBeTrue();
        expect(result.UPGRADED).toBeFalse();
        expect(compare(currentPassword().password[1],lowercaseDigest)).toBe(0);
      });
      it("allows concurrent successful legacy logins without overwriting a winner",function() {
        var names = [];
        for (var i=1;i<=2;i++) {
          var name = "authhash" & replace(createUUID(),"-","","all");
          arrayAppend(names,name);
          thread action="run" name=name testUser=variables.userId testPlain=variables.plain testObserved=variables.observed {
            thread.result = new fpw.api.v1.PasswordHashService().verifyAndUpgrade(attributes.testUser,attributes.testPlain,attributes.testObserved);
          }
        }
        thread action="join" name=arrayToList(names) timeout=30000;
        var upgrades = 0;
        for (var name in names) {
          expect(structKeyExists(cfthread[name],"result")).toBeTrue();
          expect(cfthread[name].result.VERIFIED).toBeTrue();
          if (cfthread[name].result.UPGRADED) upgrades++;
        }
        expect(upgrades).toBe(1);
        expect(variables.passwords.verifyPassword(variables.plain,currentPassword().password[1])).toBeTrue();
      });
    });
  }
  private query function currentPassword() {
    return queryExecute("SELECT password,DATE_FORMAT(passwordCreated,'%Y-%m-%d %H:%i:%s') AS password_created
      FROM users WHERE userId=:id",{id={value=variables.userId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
  }
  private void function setFixturePassword(required string password) {
    queryExecute("UPDATE users SET password=:password WHERE userId=:id",
      {password={value=arguments.password,cfsqltype="cf_sql_varchar"},
       id={value=variables.userId,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
  }
}
