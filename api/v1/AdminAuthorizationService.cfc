component output="false" {

  variables.datasource = "fpw";

  public any function init(string datasource="fpw") output="false" {
    variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
    return this;
  }

  public struct function authorizeCurrentSession(struct userStruct={}) output="false" {
    var result = {
      "authenticated" = false,
      "authorized" = false,
      "userId" = 0,
      "entitlementId" = 0
    };
    var qAdmin = queryNew("");

    result.userId = resolveUserId(arguments.userStruct);
    result.authenticated = result.userId GT 0;
    if (!result.authenticated) {
      return result;
    }

    qAdmin = queryExecute(
      "SELECT id
         FROM member_entitlements
        WHERE user_id = :userId
          AND LOWER(entitlement_type) = 'admin'
          AND LOWER(status) = 'active'
          AND starts_at_utc <= UTC_TIMESTAMP()
          AND (expires_at_utc IS NULL OR expires_at_utc > UTC_TIMESTAMP())
          AND revoked_at_utc IS NULL
        ORDER BY id DESC
        LIMIT 1",
      {
        userId = { value = result.userId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );

    if (qAdmin.recordCount GT 0) {
      result.authorized = true;
      result.entitlementId = val(qAdmin.id[1]);
    }
    return result;
  }

  public string function getOrCreateCsrfToken() output="false" {
    if (!structKeyExists(session, "fpwAdminCsrfToken") OR !len(trim(toString(session.fpwAdminCsrfToken)))) {
      session.fpwAdminCsrfToken = lCase(replace(createUUID(), "-", "", "all")) & lCase(replace(createUUID(), "-", "", "all"));
    }
    return trim(toString(session.fpwAdminCsrfToken));
  }

  public boolean function isValidCsrfToken(any candidate="") output="false" {
    var supplied = trim(toString(arguments.candidate));
    var expected = structKeyExists(session, "fpwAdminCsrfToken") ? trim(toString(session.fpwAdminCsrfToken)) : "";
    if (!len(supplied) OR !len(expected)) {
      return false;
    }
    return compare(hash(supplied, "SHA-256"), hash(expected, "SHA-256")) EQ 0;
  }

  public string function resolveRequestCsrfToken() output="false" {
    if (structKeyExists(cgi, "http_x_csrf_token") AND len(trim(toString(cgi.http_x_csrf_token)))) {
      return trim(toString(cgi.http_x_csrf_token));
    }
    if (structKeyExists(form, "adminCsrfToken") AND len(trim(toString(form.adminCsrfToken)))) {
      return trim(toString(form.adminCsrfToken));
    }
    return "";
  }

  public numeric function resolveUserId(struct userStruct={}) output="false" {
    var candidate = 0;
    if (structKeyExists(arguments.userStruct, "userId") AND isNumeric(arguments.userStruct.userId)) {
      candidate = val(arguments.userStruct.userId);
    } else if (structKeyExists(arguments.userStruct, "id") AND isNumeric(arguments.userStruct.id)) {
      candidate = val(arguments.userStruct.id);
    } else if (structKeyExists(arguments.userStruct, "USERID") AND isNumeric(arguments.userStruct.USERID)) {
      candidate = val(arguments.userStruct.USERID);
    } else if (structKeyExists(arguments.userStruct, "ID") AND isNumeric(arguments.userStruct.ID)) {
      candidate = val(arguments.userStruct.ID);
    }
    return candidate GT 0 ? candidate : 0;
  }
}


