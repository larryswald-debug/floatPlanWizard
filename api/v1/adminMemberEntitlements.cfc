<cfcomponent output="false" hint="Admin-only member-entitlement management service.">

  <cfset variables.datasource = "fpw">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfscript>
      variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="listEntitlements" access="public" returntype="struct" output="false">
    <cfargument name="filters" type="struct" required="false" default="#structNew()#">
    <cfscript>
      var limitValue = clampInt(readValue(arguments.filters, "limit", 50), 1, 200, 50);
      var offsetValue = clampInt(readValue(arguments.filters, "offset", 0), 0, 500000, 0);
      var searchValue = lCase(left(trim(toString(readValue(arguments.filters, "search", ""))), 255));
      var lifecycleValue = lCase(left(trim(toString(readValue(arguments.filters, "lifecycle", ""))), 40));
      var sourceValue = lCase(left(trim(toString(readValue(arguments.filters, "source", ""))), 40));
      var entitlementTypeValue = lCase(left(trim(toString(readValue(arguments.filters, "entitlementType", ""))), 40));
      var grantKindValue = lCase(left(trim(toString(readValue(arguments.filters, "grantKind", ""))), 40));
      var sortValue = lCase(trim(toString(readValue(arguments.filters, "sort", "updated"))));
      var directionValue = lCase(trim(toString(readValue(arguments.filters, "direction", "desc")))) EQ "asc" ? "ASC" : "DESC";
      var orderMap = {
        "member" = "u.lName",
        "email" = "u.email",
        "source" = "me.source",
        "status" = "effective_status",
        "starts" = "me.starts_at_utc",
        "expires" = "me.expires_at_utc",
        "created" = "me.created_utc",
        "updated" = "me.updated_utc"
      };
      var orderSql = structKeyExists(orderMap, sortValue) ? orderMap[sortValue] : orderMap.updated;
      var whereParts = [ "LOWER(me.entitlement_type) <> 'admin'" ];
      var params = {};
      var qRows = queryNew("");
      var qCount = queryNew("");
      var rows = [];
      var i = 0;

      if (len(searchValue)) {
        arrayAppend(whereParts, "(LOWER(COALESCE(u.email, '')) LIKE :searchLike OR LOWER(CONCAT(COALESCE(u.fName, ''), ' ', COALESCE(u.lName, ''))) LIKE :searchLike OR CAST(me.user_id AS CHAR) LIKE :searchLike OR CAST(me.id AS CHAR) LIKE :searchLike OR LOWER(COALESCE(p.code_normalized, '')) LIKE :searchLike OR LOWER(COALESCE(p.internal_name, '')) LIKE :searchLike OR LOWER(COALESCE(me.stripe_customer_id, '')) LIKE :searchLike OR LOWER(COALESCE(me.stripe_subscription_id, '')) LIKE :searchLike)");
        params.searchLike = { value = "%" & searchValue & "%", cfsqltype = "cf_sql_varchar" };
      }
      if (len(sourceValue)) {
        arrayAppend(whereParts, "LOWER(me.source) = :sourceValue");
        params.sourceValue = { value = sourceValue, cfsqltype = "cf_sql_varchar" };
      }
      if (len(entitlementTypeValue)) {
        arrayAppend(whereParts, "LOWER(me.entitlement_type) = :entitlementTypeValue");
        params.entitlementTypeValue = { value = entitlementTypeValue, cfsqltype = "cf_sql_varchar" };
      }
      if (len(grantKindValue)) {
        arrayAppend(whereParts, "LOWER(COALESCE(me.grant_kind, '')) = :grantKindValue");
        params.grantKindValue = { value = grantKindValue, cfsqltype = "cf_sql_varchar" };
      }
      appendLifecycleWhere(whereParts, lifecycleValue);

      params.limitValue = { value = limitValue, cfsqltype = "cf_sql_integer" };
      params.offsetValue = { value = offsetValue, cfsqltype = "cf_sql_integer" };
      qRows = queryExecute(
        entitlementSelectSql() & "
         WHERE " & arrayToList(whereParts, " AND ") & "
         ORDER BY " & orderSql & " " & directionValue & ", me.id DESC
         LIMIT :limitValue OFFSET :offsetValue",
        params,
        { datasource = variables.datasource }
      );
      structDelete(params, "limitValue");
      structDelete(params, "offsetValue");
      qCount = queryExecute(
        "SELECT COUNT(*) AS total_count
         FROM member_entitlements me
         INNER JOIN users u ON u.userId = me.user_id
         LEFT JOIN fpw_promo_codes p ON p.promo_code_id = me.promo_code_id
         WHERE " & arrayToList(whereParts, " AND "),
        params,
        { datasource = variables.datasource }
      );

      for (i = 1; i LTE qRows.recordCount; i++) arrayAppend(rows, entitlementRow(qRows, i));
      return success("Entitlements loaded.", {
        "items" = rows,
        "total" = qCount.recordCount ? val(qCount.total_count[1]) : 0,
        "limit" = limitValue,
        "offset" = offsetValue,
        "sort" = sortValue,
        "direction" = lCase(directionValue)
      });
    </cfscript>
  </cffunction>

  <cffunction name="searchMembers" access="public" returntype="struct" output="false">
    <cfargument name="search" type="string" required="true">
    <cfargument name="limit" type="numeric" required="false" default="25">
    <cfscript>
      var searchValue = lCase(left(trim(arguments.search), 255));
      var limitValue = clampInt(arguments.limit, 1, 50, 25);
      var qMembers = queryNew("");
      var rows = [];
      var i = 0;

      if (!len(searchValue)) return success("Enter a member search.", { "items" = [] });
      qMembers = queryExecute(
        "SELECT u.userId, u.fName, u.lName, u.email, u.created,
                COUNT(me.id) AS entitlement_count
         FROM users u
         LEFT JOIN member_entitlements me ON me.user_id = u.userId AND LOWER(me.entitlement_type) <> 'admin'
         WHERE LOWER(COALESCE(u.email, '')) LIKE :searchLike
            OR LOWER(CONCAT(COALESCE(u.fName, ''), ' ', COALESCE(u.lName, ''))) LIKE :searchLike
            OR CAST(u.userId AS CHAR) = :exactSearch
         GROUP BY u.userId, u.fName, u.lName, u.email, u.created
         ORDER BY u.userId DESC
         LIMIT :limitValue",
        {
          searchLike = { value = "%" & searchValue & "%", cfsqltype = "cf_sql_varchar" },
          exactSearch = { value = searchValue, cfsqltype = "cf_sql_varchar" },
          limitValue = { value = limitValue, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      for (i = 1; i LTE qMembers.recordCount; i++) {
        arrayAppend(rows, {
          "userId" = val(qMembers.userId[i]),
          "name" = trim(valueOrEmpty(qMembers, "fName", i) & " " & valueOrEmpty(qMembers, "lName", i)),
          "email" = valueOrEmpty(qMembers, "email", i),
          "created" = valueOrNull(qMembers, "created", i),
          "entitlementCount" = val(qMembers.entitlement_count[i])
        });
      }
      return success("Members loaded.", { "items" = rows });
    </cfscript>
  </cffunction>

  <cffunction name="getMemberDetail" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var qUser = loadUser(arguments.userId);
      var qEntitlements = queryNew("");
      var qRedemptions = queryNew("");
      var qAudit = queryNew("");
      var entitlements = [];
      var redemptions = [];
      var audits = [];
      var effectiveAccess = {};
      var i = 0;

      if (qUser.recordCount EQ 0) return failure("MEMBER_NOT_FOUND", "Member was not found.");
      effectiveAccess = new fpw.api.v1.MemberEntitlementService().init(variables.datasource).getCurrentAccess(arguments.userId);
      qEntitlements = queryExecute(
        entitlementSelectSql() & " WHERE me.user_id = :userId AND LOWER(me.entitlement_type) <> 'admin' ORDER BY me.created_utc DESC, me.id DESC",
        { userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" } },
        { datasource = variables.datasource }
      );
      for (i = 1; i LTE qEntitlements.recordCount; i++) arrayAppend(entitlements, entitlementRow(qEntitlements, i));

      qRedemptions = queryExecute(
        "SELECT r.redemption_id, r.promo_code_id, r.user_id, r.result, r.error_code,
                r.entitlement_id, r.stripe_checkout_session_id, r.stripe_customer_id,
                r.stripe_subscription_id, r.attempted_at_utc, r.redeemed_at_utc,
                p.code_normalized, p.code_hash, p.internal_name
         FROM fpw_promo_redemptions r
         LEFT JOIN fpw_promo_codes p ON p.promo_code_id = r.promo_code_id
         WHERE r.user_id = :userId
         ORDER BY r.redemption_id DESC LIMIT 250",
        { userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" } },
        { datasource = variables.datasource }
      );
      for (i = 1; i LTE qRedemptions.recordCount; i++) arrayAppend(redemptions, redemptionRow(qRedemptions, i));

      qAudit = queryExecute(
        "SELECT audit_id, admin_user_id, admin_email, action, entity_type, entity_id,
                previous_values_json, new_values_json, reason, created_at_utc
         FROM fpw_admin_audit_log
         WHERE (entity_type = 'member' AND entity_id = :userEntityId)
            OR (entity_type = 'member_entitlement' AND entity_id IN (SELECT CAST(id AS CHAR) COLLATE utf8mb4_unicode_ci FROM member_entitlements WHERE user_id = :userId AND LOWER(entitlement_type) <> 'admin'))
         ORDER BY audit_id DESC LIMIT 500",
        {
          userEntityId = { value = toString(arguments.userId), cfsqltype = "cf_sql_varchar" },
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      for (i = 1; i LTE qAudit.recordCount; i++) arrayAppend(audits, auditRow(qAudit, i));

      return success("Member entitlement detail loaded.", {
        "member" = {
          "userId" = val(qUser.userId[1]),
          "name" = trim(valueOrEmpty(qUser, "fName", 1) & " " & valueOrEmpty(qUser, "lName", 1)),
          "email" = valueOrEmpty(qUser, "email", 1),
          "created" = valueOrNull(qUser, "created", 1),
          "lastLogin" = valueOrNull(qUser, "lastLogin", 1)
        },
        "effectiveAccess" = effectiveAccess,
        "entitlements" = entitlements,
        "redemptions" = redemptions,
        "audit" = audits
      });
    </cfscript>
  </cffunction>

  <cffunction name="previewOverlap" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="startsAtUtc" required="true">
    <cfargument name="expiresAtUtc" required="false" default="">
    <cfscript>
      var range = validateRange(arguments.startsAtUtc, arguments.expiresAtUtc, true);
      if (!range.SUCCESS) return range;
      return success("Overlap preview loaded.", { "items" = loadOverlaps(arguments.userId, range.DATA.startsAtUtc, range.DATA.expiresAtUtc, range.DATA.hasExpiration) });
    </cfscript>
  </cffunction>

  <cffunction name="grantEntitlement" access="public" returntype="struct" output="false">
    <cfargument name="payload" type="struct" required="true">
    <cfargument name="admin" type="struct" required="true">
    <cfscript>
      var userId = val(readValue(arguments.payload, "userId", 0));
      var grantKind = lCase(left(trim(toString(readValue(arguments.payload, "grantKind", ""))), 40));
      var promoCodeId = val(readValue(arguments.payload, "promoCodeId", 0));
      var durationDays = val(readValue(arguments.payload, "durationDays", 0));
      var startsAtInput = trim(toString(readValue(arguments.payload, "startsAtUtc", "")));
      var expiresAtInput = trim(toString(readValue(arguments.payload, "expiresAtUtc", "")));
      var notes = left(trim(toString(readValue(arguments.payload, "adminNotes", ""))), 10000);
      var reason = left(trim(toString(readValue(arguments.payload, "reason", ""))), 500);
      var confirmOverlap = truthy(readValue(arguments.payload, "confirmOverlap", false));
      var adminUserId = val(readValue(arguments.admin, "userId", 0));
      var adminEmail = left(trim(toString(readValue(arguments.admin, "email", ""))), 255);
      var sourceValue = "admin_comp";
      var range = {};
      var startsAtValue = "";
      var expiresAtValue = "";
      var hasExpiration = false;
      var overlaps = [];
      var qUser = loadUser(userId);
      var qPromo = queryNew("");
      var qPromoUsage = queryNew("");
      var qNewId = queryNew("");
      var entitlementId = 0;
      var current = {};

      if (adminUserId LTE 0) return failure("INVALID_ADMIN", "A valid administrator is required.");
      if (qUser.recordCount EQ 0) return failure("MEMBER_NOT_FOUND", "Member was not found.");
      if (!len(reason)) return failure("REASON_REQUIRED", "An administrative reason is required.");
      if (!listFindNoCase("trial,fixed_duration,fixed_expiration,complimentary,lifetime,manual,promo", grantKind)) return failure("GRANT_KIND_INVALID", "Select a supported grant type.");
      if (!len(startsAtInput)) startsAtInput = dateTimeFormat(dateConvert("local2utc", now()), "yyyy-mm-dd HH:nn:ss");

      if (grantKind EQ "promo") {
        if (promoCodeId LTE 0) return failure("PROMO_REQUIRED", "Select an internal promotion.");
        qPromo = loadAdminGrantPromo(promoCodeId, false);
        if (qPromo.recordCount EQ 0) return failure("PROMO_NOT_AVAILABLE", "The selected internal promotion is not active or is outside its availability window.");
        grantKind = lCase(valueOrEmpty(qPromo, "admin_grant_kind", 1));
        durationDays = val(qPromo.admin_grant_duration_days[1]);
        if (grantKind EQ "fixed_expiration") expiresAtInput = valueOrEmpty(qPromo, "admin_grant_expires_at_utc", 1);
      }

      if (listFindNoCase("trial,fixed_duration,complimentary", grantKind)) {
        if (durationDays LTE 0) return failure("GRANT_DURATION_REQUIRED", "A positive duration in days is required.");
        if (!isDate(startsAtInput)) return failure("GRANT_START_INVALID", "Start date is invalid.");
        expiresAtInput = dateTimeFormat(dateAdd("d", durationDays, parseDateValue(startsAtInput)), "yyyy-mm-dd HH:nn:ss");
      } else if (grantKind EQ "fixed_expiration" AND !len(expiresAtInput)) {
        return failure("GRANT_EXPIRATION_REQUIRED", "An expiration date is required.");
      } else if (grantKind EQ "lifetime") {
        expiresAtInput = "";
        sourceValue = "founder_lifetime";
      } else if (grantKind EQ "manual" AND len(expiresAtInput)) {
        sourceValue = "admin_comp";
      }

      range = validateRange(startsAtInput, expiresAtInput, true);
      if (!range.SUCCESS) return range;
      startsAtValue = range.DATA.startsAtUtc;
      expiresAtValue = range.DATA.expiresAtUtc;
      hasExpiration = range.DATA.hasExpiration;
      overlaps = loadOverlaps(userId, startsAtValue, expiresAtValue, hasExpiration);
      if (arrayLen(overlaps) AND !confirmOverlap) {
        return failureWithData("OVERLAP_CONFIRMATION_REQUIRED", "This grant overlaps existing active or scheduled access. Confirm the overlap to continue.", { "overlaps" = overlaps });
      }

      transaction {
        if (promoCodeId GT 0) {
          qPromo = loadAdminGrantPromo(promoCodeId, true);
          if (qPromo.recordCount EQ 0) return failure("PROMO_NOT_AVAILABLE", "The selected internal promotion is not active or is outside its availability window.");
          if (!isNull(qPromo.max_redemptions[1]) AND val(qPromo.max_redemptions[1]) GT 0 AND val(qPromo.redemptions_count[1]) GTE val(qPromo.max_redemptions[1])) {
            return failure("PROMO_MAX_REDEMPTIONS_REACHED", "The selected promotion has reached its redemption limit.");
          }
          if (truthy(qPromo.one_per_user[1])) {
            qPromoUsage = queryExecute(
              "SELECT COUNT(*) AS row_count FROM fpw_promo_redemptions WHERE promo_code_id = :promoCodeId AND user_id = :userId AND result = 'redeemed'",
              {
                promoCodeId = { value = promoCodeId, cfsqltype = "cf_sql_bigint" },
                userId = { value = userId, cfsqltype = "cf_sql_integer" }
              },
              { datasource = variables.datasource }
            );
            if (val(qPromoUsage.row_count[1]) GT 0) return failure("PROMO_ALREADY_REDEEMED", "This member has already received this promotion.");
          }
        }

        queryExecute(
          "INSERT INTO member_entitlements (
             user_id, entitlement_type, source, promo_code_id, grant_kind, status,
             starts_at_utc, expires_at_utc, admin_notes,
             created_by_user_id, updated_by_user_id, created_utc, updated_utc
           ) VALUES (
             :userId, 'premium', :sourceValue, :promoCodeId, :grantKind, 'active',
             :startsAtUtc, :expiresAtUtc, :adminNotes,
             :adminUserId, :adminUserId, UTC_TIMESTAMP(), UTC_TIMESTAMP()
           )",
          {
            userId = { value = userId, cfsqltype = "cf_sql_integer" },
            sourceValue = { value = sourceValue, cfsqltype = "cf_sql_varchar" },
            promoCodeId = { value = promoCodeId, cfsqltype = "cf_sql_bigint", null = promoCodeId LTE 0 },
            grantKind = { value = grantKind, cfsqltype = "cf_sql_varchar" },
            startsAtUtc = { value = startsAtValue, cfsqltype = "cf_sql_timestamp" },
            expiresAtUtc = { value = expiresAtValue, cfsqltype = "cf_sql_timestamp", null = !hasExpiration },
            adminNotes = { value = notes, cfsqltype = "cf_sql_longvarchar", null = !len(notes) },
            adminUserId = { value = adminUserId, cfsqltype = "cf_sql_integer" }
          },
          { datasource = variables.datasource }
        );
        qNewId = queryExecute("SELECT LAST_INSERT_ID() AS new_id", {}, { datasource = variables.datasource });
        entitlementId = qNewId.recordCount ? val(qNewId.new_id[1]) : 0;

        if (promoCodeId GT 0) {
          queryExecute(
            "INSERT INTO fpw_promo_redemptions (
               promo_code_id, user_id, attempt_code_hash, result, entitlement_id,
               attempted_at_utc, redeemed_at_utc, created_at_utc, updated_at_utc
             ) VALUES (
               :promoCodeId, :userId, :codeHash, 'redeemed', :entitlementId,
               UTC_TIMESTAMP(), UTC_TIMESTAMP(), UTC_TIMESTAMP(), UTC_TIMESTAMP()
             )",
            {
              promoCodeId = { value = promoCodeId, cfsqltype = "cf_sql_bigint" },
              userId = { value = userId, cfsqltype = "cf_sql_integer" },
              codeHash = { value = qPromo.code_hash[1], cfsqltype = "cf_sql_char" },
              entitlementId = { value = entitlementId, cfsqltype = "cf_sql_bigint" }
            },
            { datasource = variables.datasource }
          );
          queryExecute(
            "UPDATE fpw_promo_codes SET redemptions_count = redemptions_count + 1, updated_at_utc = UTC_TIMESTAMP() WHERE promo_code_id = :promoCodeId",
            { promoCodeId = { value = promoCodeId, cfsqltype = "cf_sql_bigint" } },
            { datasource = variables.datasource }
          );
        }

        current = entitlementSnapshot(loadEntitlement(entitlementId, false), 1);
        writeAudit(adminUserId, adminEmail, "entitlement_grant", "member_entitlement", toString(entitlementId), {}, current, reason);
        writeAudit(adminUserId, adminEmail, "member_access_grant", "member", toString(userId), {}, { "entitlementId" = entitlementId, "grantKind" = grantKind }, reason);
      }

      return success("Entitlement granted.", {
        "entitlementId" = entitlementId,
        "entitlement" = current,
        "effectiveAccess" = new fpw.api.v1.MemberEntitlementService().init(variables.datasource).getCurrentAccess(userId)
      });
    </cfscript>
  </cffunction>

  <cffunction name="extendEntitlement" access="public" returntype="struct" output="false">
    <cfargument name="entitlementId" type="numeric" required="true">
    <cfargument name="newExpiresAtUtc" required="true">
    <cfargument name="reason" type="string" required="true">
    <cfargument name="admin" type="struct" required="true">
    <cfscript>
      var reasonValue = left(trim(arguments.reason), 500);
      var adminUserId = val(readValue(arguments.admin, "userId", 0));
      var adminEmail = left(trim(toString(readValue(arguments.admin, "email", ""))), 255);
      var qEntitlement = queryNew("");
      var newExpiry = "";
      var previous = {};
      var current = {};
      var userId = 0;

      if (!len(reasonValue)) return failure("REASON_REQUIRED", "An extension reason is required.");
      if (!isDate(arguments.newExpiresAtUtc)) return failure("EXPIRATION_INVALID", "New expiration date is invalid.");
      newExpiry = parseDateValue(arguments.newExpiresAtUtc);

      transaction {
        qEntitlement = loadEntitlement(arguments.entitlementId, true);
        if (qEntitlement.recordCount EQ 0) return failure("ENTITLEMENT_NOT_FOUND", "Entitlement was not found.");
        if (lCase(qEntitlement.source[1]) EQ "stripe_subscription") return failure("STRIPE_MANAGED_RESTRICTED", "Stripe-managed dates cannot be edited.");
        if (lCase(qEntitlement.status[1]) EQ "revoked") return failure("ENTITLEMENT_REVOKED", "A revoked entitlement cannot be extended.");
        if (isNull(qEntitlement.expires_at_utc[1])) return failure("LIFETIME_EXTENSION_INVALID", "Open-ended or lifetime access does not have an expiration to extend.");
        if (dateCompare(newExpiry, qEntitlement.expires_at_utc[1]) LTE 0) return failure("EXTENSION_MUST_INCREASE", "The new expiration must be later than the current expiration.");
        previous = entitlementSnapshot(qEntitlement, 1);
        userId = val(qEntitlement.user_id[1]);
        queryExecute(
          "UPDATE member_entitlements SET expires_at_utc = :newExpiry, updated_by_user_id = :adminUserId, updated_utc = UTC_TIMESTAMP() WHERE id = :entitlementId",
          {
            newExpiry = { value = newExpiry, cfsqltype = "cf_sql_timestamp" },
            adminUserId = { value = adminUserId, cfsqltype = "cf_sql_integer" },
            entitlementId = { value = arguments.entitlementId, cfsqltype = "cf_sql_bigint" }
          },
          { datasource = variables.datasource }
        );
        current = entitlementSnapshot(loadEntitlement(arguments.entitlementId, false), 1);
        writeAudit(adminUserId, adminEmail, "entitlement_extend", "member_entitlement", toString(arguments.entitlementId), previous, current, reasonValue);
      }
      return success("Entitlement extended.", { "entitlement" = current, "effectiveAccess" = new fpw.api.v1.MemberEntitlementService().init(variables.datasource).getCurrentAccess(userId) });
    </cfscript>
  </cffunction>

  <cffunction name="revokeEntitlement" access="public" returntype="struct" output="false">
    <cfargument name="entitlementId" type="numeric" required="true">
    <cfargument name="reason" type="string" required="true">
    <cfargument name="confirmation" type="string" required="true">
    <cfargument name="admin" type="struct" required="true">
    <cfscript>
      var reasonValue = left(trim(arguments.reason), 500);
      var expected = "REVOKE ENTITLEMENT " & toString(arguments.entitlementId);
      var adminUserId = val(readValue(arguments.admin, "userId", 0));
      var adminEmail = left(trim(toString(readValue(arguments.admin, "email", ""))), 255);
      var qEntitlement = queryNew("");
      var previous = {};
      var current = {};
      var userId = 0;

      if (!len(reasonValue)) return failure("REASON_REQUIRED", "A revocation reason is required.");
      if (trim(arguments.confirmation) NEQ expected) return failure("REVOKE_CONFIRMATION_INVALID", "Type " & expected & " to confirm revocation.");

      transaction {
        qEntitlement = loadEntitlement(arguments.entitlementId, true);
        if (qEntitlement.recordCount EQ 0) return failure("ENTITLEMENT_NOT_FOUND", "Entitlement was not found.");
        if (lCase(qEntitlement.source[1]) EQ "stripe_subscription") return failure("STRIPE_MANAGED_RESTRICTED", "Stripe-managed entitlements cannot be revoked here.");
        if (lCase(qEntitlement.status[1]) EQ "revoked") return failure("ENTITLEMENT_ALREADY_REVOKED", "Entitlement is already revoked.");
        previous = entitlementSnapshot(qEntitlement, 1);
        userId = val(qEntitlement.user_id[1]);
        queryExecute(
          "UPDATE member_entitlements SET status = 'revoked', revoked_at_utc = UTC_TIMESTAMP(),
             revoked_by_user_id = :adminUserId, revocation_reason = :reasonValue,
             updated_by_user_id = :adminUserId, updated_utc = UTC_TIMESTAMP()
           WHERE id = :entitlementId",
          {
            adminUserId = { value = adminUserId, cfsqltype = "cf_sql_integer" },
            reasonValue = { value = reasonValue, cfsqltype = "cf_sql_varchar" },
            entitlementId = { value = arguments.entitlementId, cfsqltype = "cf_sql_bigint" }
          },
          { datasource = variables.datasource }
        );
        current = entitlementSnapshot(loadEntitlement(arguments.entitlementId, false), 1);
        writeAudit(adminUserId, adminEmail, "entitlement_revoke", "member_entitlement", toString(arguments.entitlementId), previous, current, reasonValue);
        writeAudit(adminUserId, adminEmail, "member_access_revoke", "member", toString(userId), { "entitlementId" = arguments.entitlementId }, { "status" = "revoked" }, reasonValue);
      }
      return success("Entitlement revoked. No Stripe subscription was changed.", { "entitlement" = current, "effectiveAccess" = new fpw.api.v1.MemberEntitlementService().init(variables.datasource).getCurrentAccess(userId) });
    </cfscript>
  </cffunction>

  <cffunction name="updateNotes" access="public" returntype="struct" output="false">
    <cfargument name="entitlementId" type="numeric" required="true">
    <cfargument name="adminNotes" type="string" required="true">
    <cfargument name="reason" type="string" required="true">
    <cfargument name="admin" type="struct" required="true">
    <cfscript>
      var notesValue = left(trim(arguments.adminNotes), 10000);
      var reasonValue = left(trim(arguments.reason), 500);
      var adminUserId = val(readValue(arguments.admin, "userId", 0));
      var adminEmail = left(trim(toString(readValue(arguments.admin, "email", ""))), 255);
      var qEntitlement = queryNew("");
      var previous = {};
      var current = {};

      if (!len(reasonValue)) return failure("REASON_REQUIRED", "A note-change reason is required.");
      transaction {
        qEntitlement = loadEntitlement(arguments.entitlementId, true);
        if (qEntitlement.recordCount EQ 0) return failure("ENTITLEMENT_NOT_FOUND", "Entitlement was not found.");
        previous = entitlementSnapshot(qEntitlement, 1);
        queryExecute(
          "UPDATE member_entitlements SET admin_notes = :adminNotes, updated_by_user_id = :adminUserId, updated_utc = UTC_TIMESTAMP() WHERE id = :entitlementId",
          {
            adminNotes = { value = notesValue, cfsqltype = "cf_sql_longvarchar", null = !len(notesValue) },
            adminUserId = { value = adminUserId, cfsqltype = "cf_sql_integer" },
            entitlementId = { value = arguments.entitlementId, cfsqltype = "cf_sql_bigint" }
          },
          { datasource = variables.datasource }
        );
        current = entitlementSnapshot(loadEntitlement(arguments.entitlementId, false), 1);
        writeAudit(adminUserId, adminEmail, "entitlement_notes_update", "member_entitlement", toString(arguments.entitlementId), previous, current, reasonValue);
      }
      return success("Administrative notes updated.", { "entitlement" = current });
    </cfscript>
  </cffunction>

  <cffunction name="entitlementSelectSql" access="private" returntype="string" output="false">
    <cfscript>
      return "SELECT me.*, u.fName, u.lName, u.email,
                p.code_normalized, p.code_hash, p.internal_name AS promo_name,
                CASE
                  WHEN me.status = 'revoked' OR me.revoked_at_utc IS NOT NULL THEN 'revoked'
                  WHEN me.status <> 'active' THEN LOWER(me.status)
                  WHEN me.starts_at_utc > UTC_TIMESTAMP() THEN 'scheduled'
                  WHEN me.expires_at_utc IS NOT NULL AND me.expires_at_utc < UTC_TIMESTAMP() THEN 'expired'
                  ELSE 'active'
                END AS effective_status
              FROM member_entitlements me
              INNER JOIN users u ON u.userId = me.user_id
              LEFT JOIN fpw_promo_codes p ON p.promo_code_id = me.promo_code_id";
    </cfscript>
  </cffunction>

  <cffunction name="appendLifecycleWhere" access="private" returntype="void" output="false">
    <cfargument name="whereParts" type="array" required="true">
    <cfargument name="lifecycle" type="string" required="true">
    <cfscript>
      switch (arguments.lifecycle) {
        case "active": arrayAppend(arguments.whereParts, "me.status = 'active' AND me.starts_at_utc <= UTC_TIMESTAMP() AND (me.expires_at_utc IS NULL OR me.expires_at_utc >= UTC_TIMESTAMP()) AND me.revoked_at_utc IS NULL"); break;
        case "scheduled": arrayAppend(arguments.whereParts, "me.status = 'active' AND me.starts_at_utc > UTC_TIMESTAMP() AND me.revoked_at_utc IS NULL"); break;
        case "expired": arrayAppend(arguments.whereParts, "me.expires_at_utc IS NOT NULL AND me.expires_at_utc < UTC_TIMESTAMP() AND me.revoked_at_utc IS NULL"); break;
        case "revoked": arrayAppend(arguments.whereParts, "(me.status = 'revoked' OR me.revoked_at_utc IS NOT NULL)"); break;
        case "trial": arrayAppend(arguments.whereParts, "(me.grant_kind = 'trial' OR me.source = 'three_day_pass' OR me.stripe_subscription_status = 'trialing')"); break;
        case "complimentary": arrayAppend(arguments.whereParts, "(me.grant_kind = 'complimentary' OR me.source = 'admin_comp')"); break;
        case "lifetime": arrayAppend(arguments.whereParts, "(me.grant_kind = 'lifetime' OR me.source = 'founder_lifetime' OR (me.expires_at_utc IS NULL AND me.source <> 'stripe_subscription'))"); break;
        case "stripe": arrayAppend(arguments.whereParts, "me.source = 'stripe_subscription'"); break;
        case "promo": arrayAppend(arguments.whereParts, "(me.promo_code_id IS NOT NULL OR EXISTS (SELECT 1 FROM fpw_promo_redemptions rr WHERE rr.entitlement_id = me.id))"); break;
      }
    </cfscript>
  </cffunction>

  <cffunction name="loadUser" access="private" returntype="query" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      return queryExecute(
        "SELECT userId, fName, lName, email, created, lastLogin FROM users WHERE userId = :userId LIMIT 1",
        { userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" } },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="loadEntitlement" access="private" returntype="query" output="false">
    <cfargument name="entitlementId" type="numeric" required="true">
    <cfargument name="forUpdate" type="boolean" required="false" default="false">
    <cfscript>
      return queryExecute(
        entitlementSelectSql() & " WHERE me.id = :entitlementId AND LOWER(me.entitlement_type) <> 'admin' LIMIT 1" & (arguments.forUpdate ? " FOR UPDATE" : ""),
        { entitlementId = { value = arguments.entitlementId, cfsqltype = "cf_sql_bigint" } },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="loadAdminGrantPromo" access="private" returntype="query" output="false">
    <cfargument name="promoCodeId" type="numeric" required="true">
    <cfargument name="forUpdate" type="boolean" required="false" default="false">
    <cfscript>
      return queryExecute(
        "SELECT * FROM fpw_promo_codes
         WHERE promo_code_id = :promoCodeId AND promo_type = 'admin_grant'
           AND status = 'active' AND archived_at_utc IS NULL
           AND starts_at_utc <= UTC_TIMESTAMP()
           AND (expires_at_utc IS NULL OR expires_at_utc >= UTC_TIMESTAMP())
         LIMIT 1" & (arguments.forUpdate ? " FOR UPDATE" : ""),
        { promoCodeId = { value = arguments.promoCodeId, cfsqltype = "cf_sql_bigint" } },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="loadOverlaps" access="private" returntype="array" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="startsAtUtc" type="date" required="true">
    <cfargument name="expiresAtUtc" required="true">
    <cfargument name="hasExpiration" type="boolean" required="true">
    <cfscript>
      var endPredicate = arguments.hasExpiration ? "AND me.starts_at_utc <= :newExpiresAtUtc" : "";
      var params = {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        newStartsAtUtc = { value = arguments.startsAtUtc, cfsqltype = "cf_sql_timestamp" }
      };
      var qRows = queryNew("");
      var rows = [];
      var i = 0;
      if (arguments.hasExpiration) params.newExpiresAtUtc = { value = arguments.expiresAtUtc, cfsqltype = "cf_sql_timestamp" };
      qRows = queryExecute(
        entitlementSelectSql() & "
         WHERE me.user_id = :userId AND me.status = 'active' AND me.revoked_at_utc IS NULL
           AND (me.expires_at_utc IS NULL OR me.expires_at_utc >= :newStartsAtUtc)
           " & endPredicate & "
         ORDER BY me.starts_at_utc ASC, me.id ASC",
        params,
        { datasource = variables.datasource }
      );
      for (i = 1; i LTE qRows.recordCount; i++) arrayAppend(rows, entitlementRow(qRows, i));
      return rows;
    </cfscript>
  </cffunction>

  <cffunction name="validateRange" access="private" returntype="struct" output="false">
    <cfargument name="startsAtUtc" required="true">
    <cfargument name="expiresAtUtc" required="true">
    <cfargument name="requireStart" type="boolean" required="true">
    <cfscript>
      var startInput = trim(toString(arguments.startsAtUtc));
      var endInput = trim(toString(arguments.expiresAtUtc));
      var startValue = "";
      var endValue = "";
      if (arguments.requireStart AND (!len(startInput) OR !isDate(startInput))) return failure("START_DATE_INVALID", "A valid UTC start date is required.");
      startValue = parseDateValue(startInput);
      if (len(endInput)) {
        if (!isDate(endInput)) return failure("EXPIRATION_DATE_INVALID", "Expiration date is invalid.");
        endValue = parseDateValue(endInput);
        if (dateCompare(endValue, startValue) LTE 0) return failure("ENTITLEMENT_DATE_RANGE_INVALID", "Expiration must be after the start date.");
      }
      return success("Date range valid.", { "startsAtUtc" = startValue, "expiresAtUtc" = endValue, "hasExpiration" = len(endInput) GT 0 });
    </cfscript>
  </cffunction>

  <cffunction name="entitlementRow" access="private" returntype="struct" output="false">
    <cfargument name="q" type="query" required="true">
    <cfargument name="row" type="numeric" required="true">
    <cfscript>
      var sourceValue = valueOrEmpty(arguments.q, "source", arguments.row);
      var expiresValue = valueOrNull(arguments.q, "expires_at_utc", arguments.row);
      return {
        "entitlementId" = val(arguments.q.id[arguments.row]),
        "userId" = val(arguments.q.user_id[arguments.row]),
        "memberName" = trim(valueOrEmpty(arguments.q, "fName", arguments.row) & " " & valueOrEmpty(arguments.q, "lName", arguments.row)),
        "memberEmail" = valueOrEmpty(arguments.q, "email", arguments.row),
        "entitlementType" = valueOrEmpty(arguments.q, "entitlement_type", arguments.row),
        "membershipLevel" = valueOrEmpty(arguments.q, "entitlement_type", arguments.row) EQ "premium" ? "Premium" : valueOrEmpty(arguments.q, "entitlement_type", arguments.row),
        "source" = sourceValue,
        "grantKind" = valueOrEmpty(arguments.q, "grant_kind", arguments.row),
        "status" = valueOrEmpty(arguments.q, "status", arguments.row),
        "effectiveStatus" = valueOrEmpty(arguments.q, "effective_status", arguments.row),
        "startsAtUtc" = valueOrNull(arguments.q, "starts_at_utc", arguments.row),
        "expiresAtUtc" = expiresValue,
        "isLifetime" = isNull(expiresValue) AND sourceValue NEQ "stripe_subscription",
        "isTrial" = valueOrEmpty(arguments.q, "grant_kind", arguments.row) EQ "trial" OR sourceValue EQ "three_day_pass" OR valueOrEmpty(arguments.q, "stripe_subscription_status", arguments.row) EQ "trialing",
        "isComplimentary" = valueOrEmpty(arguments.q, "grant_kind", arguments.row) EQ "complimentary" OR sourceValue EQ "admin_comp",
        "isStripeManaged" = sourceValue EQ "stripe_subscription",
        "promoCodeId" = valueOrNull(arguments.q, "promo_code_id", arguments.row),
        "promoCode" = valueOrEmpty(arguments.q, "code_normalized", arguments.row),
        "promoHashFingerprint" = len(valueOrEmpty(arguments.q, "code_hash", arguments.row)) ? left(valueOrEmpty(arguments.q, "code_hash", arguments.row), 12) : "",
        "promoName" = valueOrEmpty(arguments.q, "promo_name", arguments.row),
        "stripeCustomerId" = valueOrEmpty(arguments.q, "stripe_customer_id", arguments.row),
        "stripeSubscriptionId" = valueOrEmpty(arguments.q, "stripe_subscription_id", arguments.row),
        "stripeCheckoutSessionId" = valueOrEmpty(arguments.q, "stripe_checkout_session_id", arguments.row),
        "stripePaymentIntentId" = valueOrEmpty(arguments.q, "stripe_payment_intent_id", arguments.row),
        "stripePriceId" = valueOrEmpty(arguments.q, "stripe_price_id", arguments.row),
        "stripeSubscriptionStatus" = valueOrEmpty(arguments.q, "stripe_subscription_status", arguments.row),
        "adminNotes" = valueOrEmpty(arguments.q, "admin_notes", arguments.row),
        "createdByUserId" = valueOrNull(arguments.q, "created_by_user_id", arguments.row),
        "updatedByUserId" = valueOrNull(arguments.q, "updated_by_user_id", arguments.row),
        "revokedAtUtc" = valueOrNull(arguments.q, "revoked_at_utc", arguments.row),
        "revokedByUserId" = valueOrNull(arguments.q, "revoked_by_user_id", arguments.row),
        "revocationReason" = valueOrEmpty(arguments.q, "revocation_reason", arguments.row),
        "createdAtUtc" = valueOrNull(arguments.q, "created_utc", arguments.row),
        "updatedAtUtc" = valueOrNull(arguments.q, "updated_utc", arguments.row)
      };
    </cfscript>
  </cffunction>

  <cffunction name="entitlementSnapshot" access="private" returntype="struct" output="false">
    <cfargument name="q" type="query" required="true">
    <cfargument name="row" type="numeric" required="true">
    <cfscript>
      var out = entitlementRow(arguments.q, arguments.row);
      structDelete(out, "stripePaymentIntentId");
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="redemptionRow" access="private" returntype="struct" output="false">
    <cfargument name="q" type="query" required="true">
    <cfargument name="row" type="numeric" required="true">
    <cfscript>
      return {
        "redemptionId" = val(arguments.q.redemption_id[arguments.row]),
        "promoCodeId" = valueOrNull(arguments.q, "promo_code_id", arguments.row),
        "promoCode" = valueOrEmpty(arguments.q, "code_normalized", arguments.row),
        "promoHashFingerprint" = len(valueOrEmpty(arguments.q, "code_hash", arguments.row)) ? left(valueOrEmpty(arguments.q, "code_hash", arguments.row), 12) : "",
        "promoName" = valueOrEmpty(arguments.q, "internal_name", arguments.row),
        "result" = valueOrEmpty(arguments.q, "result", arguments.row),
        "errorCode" = valueOrEmpty(arguments.q, "error_code", arguments.row),
        "entitlementId" = valueOrNull(arguments.q, "entitlement_id", arguments.row),
        "stripeCheckoutSessionId" = valueOrEmpty(arguments.q, "stripe_checkout_session_id", arguments.row),
        "stripeCustomerId" = valueOrEmpty(arguments.q, "stripe_customer_id", arguments.row),
        "stripeSubscriptionId" = valueOrEmpty(arguments.q, "stripe_subscription_id", arguments.row),
        "attemptedAtUtc" = valueOrNull(arguments.q, "attempted_at_utc", arguments.row),
        "redeemedAtUtc" = valueOrNull(arguments.q, "redeemed_at_utc", arguments.row)
      };
    </cfscript>
  </cffunction>

  <cffunction name="writeAudit" access="private" returntype="void" output="false">
    <cfargument name="adminUserId" type="numeric" required="true">
    <cfargument name="adminEmail" type="string" required="true">
    <cfargument name="action" type="string" required="true">
    <cfargument name="entityType" type="string" required="true">
    <cfargument name="entityId" type="string" required="true">
    <cfargument name="previousValues" type="struct" required="true">
    <cfargument name="newValues" type="struct" required="true">
    <cfargument name="reason" type="string" required="true">
    <cfscript>
      new fpw.api.v1.AdminAuditService().init(variables.datasource).record(
        actorUserId = arguments.adminUserId,
        action = arguments.action,
        targetType = arguments.entityType,
        targetId = arguments.entityId,
        success = true,
        requestId = structKeyExists(request, "fpwRequestId") ? toString(request.fpwRequestId) : "",
        previousValues = arguments.previousValues,
        newValues = arguments.newValues,
        reason = arguments.reason
      );
    </cfscript>
  </cffunction>

  <cffunction name="auditRow" access="private" returntype="struct" output="false">
    <cfargument name="q" type="query" required="true">
    <cfargument name="row" type="numeric" required="true">
    <cfscript>
      return {
        "auditId" = val(arguments.q.audit_id[arguments.row]),
        "adminUserId" = val(arguments.q.admin_user_id[arguments.row]),
        "adminEmail" = valueOrEmpty(arguments.q, "admin_email", arguments.row),
        "action" = valueOrEmpty(arguments.q, "action", arguments.row),
        "entityType" = valueOrEmpty(arguments.q, "entity_type", arguments.row),
        "entityId" = valueOrEmpty(arguments.q, "entity_id", arguments.row),
        "previousValues" = jsonOrEmpty(valueOrEmpty(arguments.q, "previous_values_json", arguments.row)),
        "newValues" = jsonOrEmpty(valueOrEmpty(arguments.q, "new_values_json", arguments.row)),
        "reason" = valueOrEmpty(arguments.q, "reason", arguments.row),
        "createdAtUtc" = valueOrNull(arguments.q, "created_at_utc", arguments.row)
      };
    </cfscript>
  </cffunction>

  <cffunction name="jsonOrEmpty" access="private" returntype="struct" output="false">
    <cfargument name="value" type="string" required="true">
    <cfscript>if (!len(trim(arguments.value))) return {}; try { return deserializeJSON(arguments.value); } catch (any ignored) { return {}; }</cfscript>
  </cffunction>

  <cffunction name="success" access="private" returntype="struct" output="false">
    <cfargument name="message" type="string" required="true">
    <cfargument name="data" type="struct" required="false" default="#structNew()#">
    <cfscript>return { "SUCCESS" = true, "AUTH" = true, "MESSAGE" = arguments.message, "DATA" = arguments.data, "ERROR" = {} };</cfscript>
  </cffunction>

  <cffunction name="failure" access="private" returntype="struct" output="false">
    <cfargument name="code" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfscript>return failureWithData(arguments.code, arguments.message, {});</cfscript>
  </cffunction>

  <cffunction name="failureWithData" access="private" returntype="struct" output="false">
    <cfargument name="code" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfargument name="data" type="struct" required="true">
    <cfscript>return { "SUCCESS" = false, "AUTH" = true, "MESSAGE" = arguments.message, "DATA" = arguments.data, "ERROR" = { "CODE" = arguments.code, "MESSAGE" = arguments.message } };</cfscript>
  </cffunction>

  <cffunction name="readValue" access="private" returntype="any" output="false">
    <cfargument name="source" type="struct" required="true"><cfargument name="key" type="string" required="true"><cfargument name="defaultValue" required="true">
    <cfscript>return structKeyExists(arguments.source, arguments.key) ? arguments.source[arguments.key] : arguments.defaultValue;</cfscript>
  </cffunction>

  <cffunction name="clampInt" access="private" returntype="numeric" output="false">
    <cfargument name="value" required="true"><cfargument name="minimum" type="numeric" required="true"><cfargument name="maximum" type="numeric" required="true"><cfargument name="defaultValue" type="numeric" required="true">
    <cfscript>var out = isNumeric(arguments.value) ? int(val(arguments.value)) : arguments.defaultValue; if (out LT arguments.minimum) out = arguments.minimum; if (out GT arguments.maximum) out = arguments.maximum; return out;</cfscript>
  </cffunction>

  <cffunction name="truthy" access="private" returntype="boolean" output="false">
    <cfargument name="value" required="true"><cfscript>return listFindNoCase("1,true,yes,y,on", trim(toString(arguments.value))) GT 0;</cfscript>
  </cffunction>

  <cffunction name="parseDateValue" access="private" returntype="date" output="false">
    <cfargument name="value" required="true"><cfscript>return parseDateTime(replace(trim(toString(arguments.value)), "T", " ", "all"));</cfscript>
  </cffunction>

  <cffunction name="valueOrEmpty" access="private" returntype="string" output="false">
    <cfargument name="q" type="query" required="true"><cfargument name="column" type="string" required="true"><cfargument name="row" type="numeric" required="true">
    <cfscript>if (listFindNoCase(arguments.q.columnList, arguments.column) AND !isNull(arguments.q[arguments.column][arguments.row])) return toString(arguments.q[arguments.column][arguments.row]); return "";</cfscript>
  </cffunction>

  <cffunction name="valueOrNull" access="private" returntype="any" output="false">
    <cfargument name="q" type="query" required="true"><cfargument name="column" type="string" required="true"><cfargument name="row" type="numeric" required="true">
    <cfscript>if (listFindNoCase(arguments.q.columnList, arguments.column) AND !isNull(arguments.q[arguments.column][arguments.row])) return arguments.q[arguments.column][arguments.row]; return javacast("null", "");</cfscript>
  </cffunction>

</cfcomponent>






