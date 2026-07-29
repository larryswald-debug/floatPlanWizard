<cfcomponent output="false" hint="Admin-only promo-code management service.">

  <cfset variables.datasource = "fpw">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfscript>
      variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="listPromos" access="public" returntype="struct" output="false">
    <cfargument name="filters" type="struct" required="false" default="#structNew()#">
    <cfscript>
      var limitValue = clampInt(readValue(arguments.filters, "limit", 50), 1, 200, 50);
      var offsetValue = clampInt(readValue(arguments.filters, "offset", 0), 0, 500000, 0);
      var searchValue = lCase(left(trim(toString(readValue(arguments.filters, "search", ""))), 255));
      var lifecycleValue = lCase(left(trim(toString(readValue(arguments.filters, "lifecycle", ""))), 40));
      var promoTypeValue = lCase(left(trim(toString(readValue(arguments.filters, "promoType", ""))), 40));
      var grantKindValue = lCase(left(trim(toString(readValue(arguments.filters, "grantKind", ""))), 40));
      var sortValue = lCase(trim(toString(readValue(arguments.filters, "sort", "updated"))));
      var directionValue = lCase(trim(toString(readValue(arguments.filters, "direction", "desc")))) EQ "asc" ? "ASC" : "DESC";
      var orderMap = {
        "code" = "p.code_normalized",
        "name" = "p.internal_name",
        "type" = "p.promo_type",
        "status" = "effective_status",
        "starts" = "p.starts_at_utc",
        "expires" = "p.expires_at_utc",
        "redemptions" = "p.redemptions_count",
        "created" = "p.created_at_utc",
        "updated" = "p.updated_at_utc"
      };
      var orderSql = structKeyExists(orderMap, sortValue) ? orderMap[sortValue] : orderMap.updated;
      var whereParts = [ "1=1" ];
      var params = {};
      var qRows = queryNew("");
      var qCount = queryNew("");
      var rows = [];
      var i = 0;

      if (len(searchValue)) {
        arrayAppend(whereParts, "(LOWER(COALESCE(p.code_normalized, '')) LIKE :searchLike OR LOWER(COALESCE(p.internal_name, '')) LIKE :searchLike OR LOWER(COALESCE(p.public_description, '')) LIKE :searchLike OR LOWER(COALESCE(p.stripe_promotion_code_id, '')) LIKE :searchLike OR LOWER(COALESCE(p.stripe_coupon_id, '')) LIKE :searchLike OR LOWER(p.code_hash) LIKE :searchLike)");
        params.searchLike = { value = "%" & searchValue & "%", cfsqltype = "cf_sql_varchar" };
      }
      if (len(promoTypeValue)) {
        arrayAppend(whereParts, "LOWER(p.promo_type) = :promoType");
        params.promoType = { value = promoTypeValue, cfsqltype = "cf_sql_varchar" };
      }
      if (len(grantKindValue)) {
        arrayAppend(whereParts, "LOWER(COALESCE(p.admin_grant_kind, '')) = :grantKind");
        params.grantKind = { value = grantKindValue, cfsqltype = "cf_sql_varchar" };
      }
      appendLifecycleWhere(whereParts, lifecycleValue);

      params.limitValue = { value = limitValue, cfsqltype = "cf_sql_integer" };
      params.offsetValue = { value = offsetValue, cfsqltype = "cf_sql_integer" };

      qRows = queryExecute(
        "SELECT
           p.*,
           CASE
             WHEN p.status = 'archived' OR p.archived_at_utc IS NOT NULL THEN 'archived'
             WHEN p.status <> 'active' THEN 'inactive'
             WHEN p.starts_at_utc > UTC_TIMESTAMP() THEN 'scheduled'
             WHEN p.expires_at_utc IS NOT NULL AND p.expires_at_utc < UTC_TIMESTAMP() THEN 'expired'
             ELSE 'active'
           END AS effective_status,
           CASE WHEN p.code_normalized IS NULL OR p.code_normalized = '' THEN 0 ELSE 1 END AS code_available
         FROM fpw_promo_codes p
         WHERE " & arrayToList(whereParts, " AND ") & "
         ORDER BY " & orderSql & " " & directionValue & ", p.promo_code_id DESC
         LIMIT :limitValue OFFSET :offsetValue",
        params,
        { datasource = variables.datasource }
      );
      structDelete(params, "limitValue");
      structDelete(params, "offsetValue");
      qCount = queryExecute(
        "SELECT COUNT(*) AS total_count FROM fpw_promo_codes p WHERE " & arrayToList(whereParts, " AND "),
        params,
        { datasource = variables.datasource }
      );

      for (i = 1; i LTE qRows.recordCount; i++) {
        arrayAppend(rows, promoRow(qRows, i));
      }

      return success("Promotions loaded.", {
        "items" = rows,
        "total" = qCount.recordCount ? val(qCount.total_count[1]) : 0,
        "limit" = limitValue,
        "offset" = offsetValue,
        "sort" = sortValue,
        "direction" = lCase(directionValue)
      });
    </cfscript>
  </cffunction>

  <cffunction name="getPromo" access="public" returntype="struct" output="false">
    <cfargument name="promoCodeId" type="numeric" required="true">
    <cfscript>
      var qPromo = loadPromo(arguments.promoCodeId, false);
      var qHistory = queryNew("");
      var qAudit = queryNew("");
      var history = [];
      var audits = [];
      var i = 0;

      if (qPromo.recordCount EQ 0) {
        return failure("PROMO_NOT_FOUND", "Promotion was not found.");
      }

      qHistory = queryExecute(
        "SELECT r.redemption_id, r.user_id, u.fName, u.lName, u.email,
                r.result, r.error_code, r.entitlement_id,
                r.stripe_checkout_session_id, r.stripe_customer_id,
                r.stripe_subscription_id, r.attempted_at_utc, r.redeemed_at_utc,
                me.starts_at_utc AS entitlement_starts_at_utc,
                me.expires_at_utc AS entitlement_expires_at_utc
         FROM fpw_promo_redemptions r
         LEFT JOIN users u ON u.userId = r.user_id
         LEFT JOIN member_entitlements me ON me.id = r.entitlement_id
         WHERE r.promo_code_id = :promoCodeId
         ORDER BY r.redemption_id DESC
         LIMIT 250",
        { promoCodeId = { value = arguments.promoCodeId, cfsqltype = "cf_sql_bigint" } },
        { datasource = variables.datasource }
      );
      for (i = 1; i LTE qHistory.recordCount; i++) {
        arrayAppend(history, redemptionRow(qHistory, i));
      }

      qAudit = loadAudit("promo_code", toString(arguments.promoCodeId));
      for (i = 1; i LTE qAudit.recordCount; i++) {
        arrayAppend(audits, auditRow(qAudit, i));
      }

      return success("Promotion loaded.", {
        "promo" = promoRow(qPromo, 1),
        "redemptions" = history,
        "audit" = audits
      });
    </cfscript>
  </cffunction>

  <cffunction name="listRedemptions" access="public" returntype="struct" output="false">
    <cfargument name="filters" type="struct" required="false" default="#structNew()#">
    <cfscript>
      var limitValue = clampInt(readValue(arguments.filters, "limit", 50), 1, 200, 50);
      var offsetValue = clampInt(readValue(arguments.filters, "offset", 0), 0, 500000, 0);
      var searchValue = lCase(left(trim(toString(readValue(arguments.filters, "search", ""))), 255));
      var resultValue = lCase(left(trim(toString(readValue(arguments.filters, "result", ""))), 40));
      var whereParts = [ "1=1" ];
      var params = {};
      var qRows = queryNew("");
      var qCount = queryNew("");
      var rows = [];
      var i = 0;

      if (len(searchValue)) {
        arrayAppend(whereParts, "(LOWER(COALESCE(p.code_normalized, '')) LIKE :searchLike OR LOWER(COALESCE(p.internal_name, '')) LIKE :searchLike OR LOWER(COALESCE(u.email, '')) LIKE :searchLike OR LOWER(CONCAT(COALESCE(u.fName, ''), ' ', COALESCE(u.lName, ''))) LIKE :searchLike OR CAST(r.user_id AS CHAR) LIKE :searchLike OR LOWER(COALESCE(r.stripe_checkout_session_id, '')) LIKE :searchLike)");
        params.searchLike = { value = "%" & searchValue & "%", cfsqltype = "cf_sql_varchar" };
      }
      if (len(resultValue)) {
        arrayAppend(whereParts, "LOWER(r.result) = :resultValue");
        params.resultValue = { value = resultValue, cfsqltype = "cf_sql_varchar" };
      }
      params.limitValue = { value = limitValue, cfsqltype = "cf_sql_integer" };
      params.offsetValue = { value = offsetValue, cfsqltype = "cf_sql_integer" };

      qRows = queryExecute(
        "SELECT r.*, p.code_normalized, p.code_hash, p.internal_name,
                u.fName, u.lName, u.email,
                me.starts_at_utc AS entitlement_starts_at_utc,
                me.expires_at_utc AS entitlement_expires_at_utc
         FROM fpw_promo_redemptions r
         LEFT JOIN fpw_promo_codes p ON p.promo_code_id = r.promo_code_id
         LEFT JOIN users u ON u.userId = r.user_id
         LEFT JOIN member_entitlements me ON me.id = r.entitlement_id
         WHERE " & arrayToList(whereParts, " AND ") & "
         ORDER BY r.created_at_utc DESC, r.redemption_id DESC
         LIMIT :limitValue OFFSET :offsetValue",
        params,
        { datasource = variables.datasource }
      );
      structDelete(params, "limitValue");
      structDelete(params, "offsetValue");
      qCount = queryExecute(
        "SELECT COUNT(*) AS total_count
         FROM fpw_promo_redemptions r
         LEFT JOIN fpw_promo_codes p ON p.promo_code_id = r.promo_code_id
         LEFT JOIN users u ON u.userId = r.user_id
         WHERE " & arrayToList(whereParts, " AND "),
        params,
        { datasource = variables.datasource }
      );

      for (i = 1; i LTE qRows.recordCount; i++) {
        arrayAppend(rows, redemptionRow(qRows, i));
      }
      return success("Redemption history loaded.", {
        "items" = rows,
        "total" = qCount.recordCount ? val(qCount.total_count[1]) : 0,
        "limit" = limitValue,
        "offset" = offsetValue
      });
    </cfscript>
  </cffunction>

  <cffunction name="savePromo" access="public" returntype="struct" output="false">
    <cfargument name="payload" type="struct" required="true">
    <cfargument name="admin" type="struct" required="true">
    <cfscript>
      var promoCodeId = val(readValue(arguments.payload, "promoCodeId", 0));
      var codeInput = left(trim(toString(readValue(arguments.payload, "code", ""))), 120);
      var normalizedCode = len(codeInput) ? new fpw.api.v1.PromoCodeService().init(variables.datasource).normalizeCode(codeInput) : "";
      var codeHash = len(normalizedCode) ? new fpw.api.v1.PromoCodeService().init(variables.datasource).hashPromoCode(normalizedCode) : "";
      var promoType = lCase(left(trim(toString(readValue(arguments.payload, "promoType", ""))), 40));
      var benefitType = lCase(left(trim(toString(readValue(arguments.payload, "benefitType", ""))), 40));
      var benefitQuantity = val(readValue(arguments.payload, "benefitQuantity", 0));
      var statusValue = lCase(left(trim(toString(readValue(arguments.payload, "status", "active"))), 40));
      var internalName = left(trim(toString(readValue(arguments.payload, "internalName", ""))), 160);
      var publicDescription = left(trim(toString(readValue(arguments.payload, "publicDescription", ""))), 500);
      var grantKind = lCase(left(trim(toString(readValue(arguments.payload, "adminGrantKind", ""))), 40));
      var grantDurationDays = val(readValue(arguments.payload, "adminGrantDurationDays", 0));
      var durationMonths = val(readValue(arguments.payload, "durationMonths", 0));
      var maxRedemptions = val(readValue(arguments.payload, "maxRedemptions", 0));
      var onePerUser = truthy(readValue(arguments.payload, "onePerUser", true));
      var startsAtInput = trim(toString(readValue(arguments.payload, "startsAtUtc", "")));
      var expiresAtInput = trim(toString(readValue(arguments.payload, "expiresAtUtc", "")));
      var grantExpiresInput = trim(toString(readValue(arguments.payload, "adminGrantExpiresAtUtc", "")));
      var startsAtValue = "";
      var expiresAtValue = "";
      var grantExpiresValue = "";
      var stripePromotionId = left(trim(toString(readValue(arguments.payload, "stripePromotionCodeId", ""))), 255);
      var stripeCouponId = left(trim(toString(readValue(arguments.payload, "stripeCouponId", ""))), 255);
      var entitlementType = lCase(left(trim(toString(readValue(arguments.payload, "entitlementType", "premium"))), 40));
      var entitlementSource = lCase(left(trim(toString(readValue(arguments.payload, "entitlementSource", ""))), 40));
      var adminNotes = left(trim(toString(readValue(arguments.payload, "adminNotes", ""))), 10000);
      var qExisting = queryNew("");
      var qDuplicate = queryNew("");
      var qNewId = queryNew("");
      var previous = {};
      var current = {};
      var auditCurrent = {};
      var existingType = "";
      var historyCount = 0;
      var adminUserId = val(readValue(arguments.admin, "userId", 0));
      var adminEmail = left(trim(toString(readValue(arguments.admin, "email", ""))), 255);
      var reason = left(trim(toString(readValue(arguments.payload, "reason", ""))), 500);
      var params = {};
      var updateParams = {};

      if (adminUserId LTE 0) return failure("INVALID_ADMIN", "A valid administrator is required.");
      if (promoCodeId LTE 0 AND !len(normalizedCode)) return failure("PROMO_CODE_REQUIRED", "Code is required.");
      if (!len(internalName)) return failure("PROMO_NAME_REQUIRED", "Internal name is required.");
      if (!reFind("^[a-z0-9_]{1,40}$", promoType)) return failure("PROMO_TYPE_INVALID", "Promotion type must use lowercase letters, numbers, and underscores.");
      if (!listFindNoCase("active,disabled,archived", statusValue)) return failure("PROMO_STATUS_INVALID", "Status must be active, disabled, or archived.");
      if (!len(startsAtInput) OR !isDate(startsAtInput)) return failure("PROMO_START_INVALID", "A valid UTC start date is required.");
      startsAtValue = parseDateValue(startsAtInput);
      if (len(expiresAtInput)) {
        if (!isDate(expiresAtInput)) return failure("PROMO_EXPIRATION_INVALID", "Expiration date is invalid.");
        expiresAtValue = parseDateValue(expiresAtInput);
        if (dateCompare(expiresAtValue, startsAtValue) LTE 0) return failure("PROMO_DATE_RANGE_INVALID", "Expiration must be after the start date.");
      }
      if (len(grantExpiresInput)) {
        if (!isDate(grantExpiresInput)) return failure("PROMO_GRANT_EXPIRATION_INVALID", "Grant expiration date is invalid.");
        grantExpiresValue = parseDateValue(grantExpiresInput);
      }
      if (maxRedemptions LT 0 OR grantDurationDays LT 0 OR durationMonths LT 0) return failure("PROMO_NEGATIVE_VALUE", "Durations and redemption limits cannot be negative.");
      if (entitlementType NEQ "premium") return failure("PROMO_ENTITLEMENT_INVALID", "Only the current premium entitlement type is supported.");

      if (promoCodeId GT 0) {
        qExisting = loadPromo(promoCodeId, true);
        if (qExisting.recordCount EQ 0) return failure("PROMO_NOT_FOUND", "Promotion was not found.");
        previous = promoSnapshot(qExisting, 1);
        existingType = lCase(trim(toString(qExisting.promo_type[1])));
        historyCount = redemptionHistoryCount(promoCodeId);
        if (!listFindNoCase("founder_lifetime,stripe_free_months,premium_trip,admin_grant", promoType) AND promoType NEQ existingType) {
          return failure("PROMO_TYPE_UNSUPPORTED", "New promotion types are limited to the supported public types and admin_grant.");
        }
        if (!len(normalizedCode)) {
          codeHash = trim(toString(qExisting.code_hash[1]));
          normalizedCode = valueOrEmpty(qExisting, "code_normalized", 1);
        } else if (compareNoCase(codeHash, trim(toString(qExisting.code_hash[1]))) NEQ 0 AND historyCount GT 0) {
          return failure("PROMO_CODE_IMMUTABLE", "A promotion code with redemption history cannot be changed.");
        }
      } else if (!listFindNoCase("founder_lifetime,stripe_free_months,premium_trip,admin_grant", promoType)) {
        return failure("PROMO_TYPE_UNSUPPORTED", "New promotion types are limited to founder_lifetime, stripe_free_months, premium_trip, and admin_grant.");
      }

      if (promoType EQ "founder_lifetime") {
        grantKind = "lifetime";
        grantDurationDays = 0;
        grantExpiresInput = "";
        grantExpiresValue = "";
        durationMonths = 0;
        entitlementSource = "founder_lifetime";
        benefitType = "";
        benefitQuantity = 0;
      } else if (promoType EQ "stripe_free_months") {
        if (!listFindNoCase("1,2", toString(durationMonths))) return failure("PROMO_TRIAL_DURATION_INVALID", "Stripe free-month promotions support one or two months.");
        grantKind = "trial";
        grantDurationDays = 0;
        grantExpiresInput = "";
        grantExpiresValue = "";
        benefitType = "";
        benefitQuantity = 0;
      } else if (promoType EQ "premium_trip") {
        if (benefitType NEQ "premium_trip") return failure("PROMO_BENEFIT_INVALID", "Premium Trip promotions require benefit_type premium_trip.");
        if (benefitQuantity LT 1 OR benefitQuantity GT 100 OR benefitQuantity NEQ int(benefitQuantity)) return failure("PROMO_BENEFIT_QUANTITY_INVALID", "Premium Trip quantity must be a whole number between 1 and 100.");
        grantKind = "";
        grantDurationDays = 0;
        grantExpiresInput = "";
        grantExpiresValue = "";
        durationMonths = 0;
        entitlementSource = "premium_trip";
      } else if (promoType EQ "admin_grant") {
        if (!listFindNoCase("trial,fixed_duration,fixed_expiration,complimentary,lifetime,manual", grantKind)) return failure("PROMO_GRANT_KIND_INVALID", "Select a supported internal grant type.");
        if (listFindNoCase("trial,fixed_duration,complimentary", grantKind) AND grantDurationDays LTE 0) return failure("PROMO_GRANT_DURATION_REQUIRED", "This internal grant requires a positive duration in days.");
        if (grantKind EQ "fixed_expiration" AND !len(grantExpiresInput)) return failure("PROMO_GRANT_EXPIRATION_REQUIRED", "This internal grant requires a fixed UTC expiration.");
        if (grantKind EQ "lifetime" AND (grantDurationDays GT 0 OR len(grantExpiresInput))) return failure("PROMO_LIFETIME_CONFLICT", "Lifetime access cannot have a finite grant duration or expiration.");
        entitlementSource = grantKind EQ "lifetime" ? "founder_lifetime" : "admin_comp";
        durationMonths = 0;
        benefitType = "";
        benefitQuantity = 0;
      }

      qDuplicate = queryExecute(
        "SELECT promo_code_id FROM fpw_promo_codes WHERE code_hash = :codeHash AND promo_code_id <> :promoCodeId LIMIT 1",
        {
          codeHash = { value = codeHash, cfsqltype = "cf_sql_char" },
          promoCodeId = { value = promoCodeId, cfsqltype = "cf_sql_bigint" }
        },
        { datasource = variables.datasource }
      );
      if (qDuplicate.recordCount) return failure("PROMO_CODE_DUPLICATE", "That normalized promotion code already exists.");

      params = {
        codeHash = { value = codeHash, cfsqltype = "cf_sql_char" },
        codeNormalized = { value = normalizedCode, cfsqltype = "cf_sql_varchar", null = !len(normalizedCode) },
        internalName = { value = internalName, cfsqltype = "cf_sql_varchar" },
        publicDescription = { value = publicDescription, cfsqltype = "cf_sql_varchar", null = !len(publicDescription) },
        promoType = { value = promoType, cfsqltype = "cf_sql_varchar" },
        benefitType = { value = benefitType, cfsqltype = "cf_sql_varchar", null = !len(benefitType) },
        benefitQuantity = { value = int(benefitQuantity), cfsqltype = "cf_sql_integer", null = benefitQuantity LTE 0 },
        statusValue = { value = statusValue, cfsqltype = "cf_sql_varchar" },
        startsAtUtc = { value = startsAtValue, cfsqltype = "cf_sql_timestamp" },
        expiresAtUtc = { value = expiresAtValue, cfsqltype = "cf_sql_timestamp", null = !len(expiresAtInput) },
        maxRedemptions = { value = maxRedemptions, cfsqltype = "cf_sql_integer", null = maxRedemptions LTE 0 },
        onePerUser = { value = onePerUser ? 1 : 0, cfsqltype = "cf_sql_tinyint" },
        durationMonths = { value = durationMonths, cfsqltype = "cf_sql_integer", null = durationMonths LTE 0 },
        stripePromotionId = { value = stripePromotionId, cfsqltype = "cf_sql_varchar", null = !len(stripePromotionId) },
        stripeCouponId = { value = stripeCouponId, cfsqltype = "cf_sql_varchar", null = !len(stripeCouponId) },
        entitlementType = { value = entitlementType, cfsqltype = "cf_sql_varchar" },
        entitlementSource = { value = entitlementSource, cfsqltype = "cf_sql_varchar", null = !len(entitlementSource) },
        grantKind = { value = grantKind, cfsqltype = "cf_sql_varchar", null = !len(grantKind) },
        grantDurationDays = { value = grantDurationDays, cfsqltype = "cf_sql_integer", null = grantDurationDays LTE 0 },
        grantExpiresAtUtc = { value = grantExpiresValue, cfsqltype = "cf_sql_timestamp", null = !len(grantExpiresInput) },
        adminNotes = { value = adminNotes, cfsqltype = "cf_sql_longvarchar", null = !len(adminNotes) },
        adminUserId = { value = adminUserId, cfsqltype = "cf_sql_integer" }
      };

      try {
        transaction {
          if (promoCodeId GT 0) {
            updateParams = duplicate(params);
            updateParams.promoCodeId = { value = promoCodeId, cfsqltype = "cf_sql_bigint" };
            queryExecute(
              "UPDATE fpw_promo_codes SET
                 code_hash = :codeHash, code_normalized = :codeNormalized,
                 internal_name = :internalName, public_description = :publicDescription,
                 promo_type = :promoType, benefit_type = :benefitType, benefit_quantity = :benefitQuantity, status = :statusValue,
                 starts_at_utc = :startsAtUtc, expires_at_utc = :expiresAtUtc,
                 max_redemptions = :maxRedemptions, one_per_user = :onePerUser,
                 duration_months = :durationMonths,
                 stripe_promotion_code_id = :stripePromotionId, stripe_coupon_id = :stripeCouponId,
                 entitlement_type = :entitlementType, entitlement_source = :entitlementSource,
                 admin_grant_kind = :grantKind, admin_grant_duration_days = :grantDurationDays,
                 admin_grant_expires_at_utc = :grantExpiresAtUtc, admin_notes = :adminNotes,
                 updated_by_user_id = :adminUserId,
                 archived_at_utc = IF(:statusValue = 'archived', COALESCE(archived_at_utc, UTC_TIMESTAMP()), NULL),
                 archived_by_user_id = IF(:statusValue = 'archived', :adminUserId, NULL),
                 updated_at_utc = UTC_TIMESTAMP()
               WHERE promo_code_id = :promoCodeId",
              updateParams,
              { datasource = variables.datasource }
            );
          } else {
            queryExecute(
              "INSERT INTO fpw_promo_codes (
                 code_hash, code_normalized, internal_name, public_description,
                 promo_type, benefit_type, benefit_quantity, status, starts_at_utc, expires_at_utc,
                 max_redemptions, redemptions_count, one_per_user, duration_months,
                 stripe_promotion_code_id, stripe_coupon_id,
                 entitlement_type, entitlement_source,
                 admin_grant_kind, admin_grant_duration_days, admin_grant_expires_at_utc,
                 admin_notes, created_by_user_id, updated_by_user_id,
                 archived_at_utc, archived_by_user_id, created_at_utc, updated_at_utc
               ) VALUES (
                 :codeHash, :codeNormalized, :internalName, :publicDescription,
                 :promoType, :benefitType, :benefitQuantity, :statusValue, :startsAtUtc, :expiresAtUtc,
                 :maxRedemptions, 0, :onePerUser, :durationMonths,
                 :stripePromotionId, :stripeCouponId,
                 :entitlementType, :entitlementSource,
                 :grantKind, :grantDurationDays, :grantExpiresAtUtc,
                 :adminNotes, :adminUserId, :adminUserId,
                 IF(:statusValue = 'archived', UTC_TIMESTAMP(), NULL),
                 IF(:statusValue = 'archived', :adminUserId, NULL),
                 UTC_TIMESTAMP(), UTC_TIMESTAMP()
               )",
              params,
              { datasource = variables.datasource }
            );
            qNewId = queryExecute("SELECT LAST_INSERT_ID() AS new_id", {}, { datasource = variables.datasource });
            promoCodeId = qNewId.recordCount ? val(qNewId.new_id[1]) : 0;
          }

          qExisting = loadPromo(promoCodeId, false);
          current = promoRow(qExisting, 1);
          auditCurrent = promoSnapshot(qExisting, 1);
          writeAudit(adminUserId, adminEmail, promoCodeId GT 0 AND structCount(previous) ? "promo_update" : "promo_create", "promo_code", toString(promoCodeId), previous, auditCurrent, reason);
        }
      } catch (database dbErr) {
        if (structKeyExists(dbErr, "nativeErrorCode") AND val(dbErr.nativeErrorCode) EQ 1062) {
          return failure("PROMO_CODE_DUPLICATE", "That normalized promotion code already exists.");
        }
        rethrow;
      }

      return success(structCount(previous) ? "Promotion updated." : "Promotion created.", { "promoCodeId" = promoCodeId, "promo" = current });
    </cfscript>
  </cffunction>

  <cffunction name="changePromoState" access="public" returntype="struct" output="false">
    <cfargument name="promoCodeId" type="numeric" required="true">
    <cfargument name="newStatus" type="string" required="true">
    <cfargument name="reason" type="string" required="true">
    <cfargument name="admin" type="struct" required="true">
    <cfscript>
      var statusValue = lCase(trim(arguments.newStatus));
      var reasonValue = left(trim(arguments.reason), 500);
      var adminUserId = val(readValue(arguments.admin, "userId", 0));
      var adminEmail = left(trim(toString(readValue(arguments.admin, "email", ""))), 255);
      var qPromo = queryNew("");
      var previous = {};
      var current = {};
      var auditCurrent = {};

      if (!listFindNoCase("active,disabled,archived", statusValue)) return failure("PROMO_STATUS_INVALID", "Status must be active, disabled, or archived.");
      if (!len(reasonValue)) return failure("REASON_REQUIRED", "A reason is required.");
      if (adminUserId LTE 0) return failure("INVALID_ADMIN", "A valid administrator is required.");

      transaction {
        qPromo = loadPromo(arguments.promoCodeId, true);
        if (qPromo.recordCount EQ 0) return failure("PROMO_NOT_FOUND", "Promotion was not found.");
        previous = promoSnapshot(qPromo, 1);
        queryExecute(
          "UPDATE fpw_promo_codes SET status = :statusValue,
             updated_by_user_id = :adminUserId,
             archived_at_utc = IF(:statusValue = 'archived', COALESCE(archived_at_utc, UTC_TIMESTAMP()), NULL),
             archived_by_user_id = IF(:statusValue = 'archived', :adminUserId, NULL),
             updated_at_utc = UTC_TIMESTAMP()
           WHERE promo_code_id = :promoCodeId",
          {
            statusValue = { value = statusValue, cfsqltype = "cf_sql_varchar" },
            adminUserId = { value = adminUserId, cfsqltype = "cf_sql_integer" },
            promoCodeId = { value = arguments.promoCodeId, cfsqltype = "cf_sql_bigint" }
          },
          { datasource = variables.datasource }
        );
        qPromo = loadPromo(arguments.promoCodeId, false);
        current = promoRow(qPromo, 1);
        auditCurrent = promoSnapshot(qPromo, 1);
        writeAudit(adminUserId, adminEmail, "promo_" & statusValue, "promo_code", toString(arguments.promoCodeId), previous, auditCurrent, reasonValue);
      }
      return success("Promotion status updated.", { "promo" = current });
    </cfscript>
  </cffunction>

  <cffunction name="deleteUnusedPromo" access="public" returntype="struct" output="false">
    <cfargument name="promoCodeId" type="numeric" required="true">
    <cfargument name="confirmation" type="string" required="true">
    <cfargument name="reason" type="string" required="true">
    <cfargument name="admin" type="struct" required="true">
    <cfscript>
      var expected = "DELETE PROMO " & toString(arguments.promoCodeId);
      var reasonValue = left(trim(arguments.reason), 500);
      var qPromo = queryNew("");
      var qRefs = queryNew("");
      var previous = {};
      var adminUserId = val(readValue(arguments.admin, "userId", 0));
      var adminEmail = left(trim(toString(readValue(arguments.admin, "email", ""))), 255);

      if (trim(arguments.confirmation) NEQ expected) return failure("DELETE_CONFIRMATION_INVALID", "Type " & expected & " to confirm deletion.");
      if (!len(reasonValue)) return failure("REASON_REQUIRED", "A reason is required.");

      transaction {
        qPromo = loadPromo(arguments.promoCodeId, true);
        if (qPromo.recordCount EQ 0) return failure("PROMO_NOT_FOUND", "Promotion was not found.");
        qRefs = queryExecute(
          "SELECT
             (SELECT COUNT(*) FROM fpw_promo_redemptions WHERE promo_code_id = :promoCodeId) AS redemption_count,
             (SELECT COUNT(*) FROM member_entitlements WHERE promo_code_id = :promoCodeId) AS entitlement_count,
             (SELECT COUNT(*) FROM fpw_admin_audit_log WHERE entity_type = 'promo_code' AND entity_id = :entityId) AS audit_count",
          {
            promoCodeId = { value = arguments.promoCodeId, cfsqltype = "cf_sql_bigint" },
            entityId = { value = toString(arguments.promoCodeId), cfsqltype = "cf_sql_varchar" }
          },
          { datasource = variables.datasource }
        );
        if (val(qRefs.redemption_count[1]) GT 0 OR val(qRefs.entitlement_count[1]) GT 0 OR val(qRefs.audit_count[1]) GT 0) {
          return failure("PROMO_DELETE_BLOCKED", "Promotion history exists. Deactivate or archive this promotion instead.");
        }
        previous = promoSnapshot(qPromo, 1);
        queryExecute(
          "DELETE FROM fpw_promo_codes WHERE promo_code_id = :promoCodeId",
          { promoCodeId = { value = arguments.promoCodeId, cfsqltype = "cf_sql_bigint" } },
          { datasource = variables.datasource }
        );
        writeAudit(adminUserId, adminEmail, "promo_delete", "promo_code_deleted", toString(arguments.promoCodeId), previous, {}, reasonValue);
      }
      return success("Unused promotion deleted.", { "promoCodeId" = arguments.promoCodeId });
    </cfscript>
  </cffunction>

  <cffunction name="loadPromo" access="private" returntype="query" output="false">
    <cfargument name="promoCodeId" type="numeric" required="true">
    <cfargument name="forUpdate" type="boolean" required="false" default="false">
    <cfscript>
      return queryExecute(
        "SELECT p.*,
           CASE
             WHEN p.status = 'archived' OR p.archived_at_utc IS NOT NULL THEN 'archived'
             WHEN p.status <> 'active' THEN 'inactive'
             WHEN p.starts_at_utc > UTC_TIMESTAMP() THEN 'scheduled'
             WHEN p.expires_at_utc IS NOT NULL AND p.expires_at_utc < UTC_TIMESTAMP() THEN 'expired'
             ELSE 'active'
           END AS effective_status,
           CASE WHEN p.code_normalized IS NULL OR p.code_normalized = '' THEN 0 ELSE 1 END AS code_available
         FROM fpw_promo_codes p WHERE p.promo_code_id = :promoCodeId LIMIT 1" & (arguments.forUpdate ? " FOR UPDATE" : ""),
        { promoCodeId = { value = arguments.promoCodeId, cfsqltype = "cf_sql_bigint" } },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="redemptionHistoryCount" access="private" returntype="numeric" output="false">
    <cfargument name="promoCodeId" type="numeric" required="true">
    <cfscript>
      var qCount = queryExecute(
        "SELECT COUNT(*) AS row_count FROM fpw_promo_redemptions WHERE promo_code_id = :promoCodeId",
        { promoCodeId = { value = arguments.promoCodeId, cfsqltype = "cf_sql_bigint" } },
        { datasource = variables.datasource }
      );
      return qCount.recordCount ? val(qCount.row_count[1]) : 0;
    </cfscript>
  </cffunction>

  <cffunction name="appendLifecycleWhere" access="private" returntype="void" output="false">
    <cfargument name="whereParts" type="array" required="true">
    <cfargument name="lifecycle" type="string" required="true">
    <cfscript>
      switch (arguments.lifecycle) {
        case "active": arrayAppend(arguments.whereParts, "p.status = 'active' AND p.starts_at_utc <= UTC_TIMESTAMP() AND (p.expires_at_utc IS NULL OR p.expires_at_utc >= UTC_TIMESTAMP()) AND p.archived_at_utc IS NULL"); break;
        case "inactive": arrayAppend(arguments.whereParts, "p.status = 'disabled'"); break;
        case "scheduled": arrayAppend(arguments.whereParts, "p.status = 'active' AND p.starts_at_utc > UTC_TIMESTAMP() AND p.archived_at_utc IS NULL"); break;
        case "expired": arrayAppend(arguments.whereParts, "p.status = 'active' AND p.expires_at_utc IS NOT NULL AND p.expires_at_utc < UTC_TIMESTAMP() AND p.archived_at_utc IS NULL"); break;
        case "archived": arrayAppend(arguments.whereParts, "(p.status = 'archived' OR p.archived_at_utc IS NOT NULL)"); break;
        case "lifetime": arrayAppend(arguments.whereParts, "(p.promo_type = 'founder_lifetime' OR p.admin_grant_kind = 'lifetime')"); break;
        case "trial": arrayAppend(arguments.whereParts, "(p.promo_type = 'stripe_free_months' OR p.admin_grant_kind = 'trial')"); break;
        case "complimentary": arrayAppend(arguments.whereParts, "p.admin_grant_kind = 'complimentary'"); break;
        case "stripe": arrayAppend(arguments.whereParts, "((p.stripe_promotion_code_id IS NOT NULL AND p.stripe_promotion_code_id <> '') OR (p.stripe_coupon_id IS NOT NULL AND p.stripe_coupon_id <> ''))"); break;
        case "internal": arrayAppend(arguments.whereParts, "p.promo_type = 'admin_grant'"); break;
      }
    </cfscript>
  </cffunction>

  <cffunction name="promoRow" access="private" returntype="struct" output="false">
    <cfargument name="q" type="query" required="true">
    <cfargument name="row" type="numeric" required="true">
    <cfscript>
      var hashValue = valueOrEmpty(arguments.q, "code_hash", arguments.row);
      var normalized = valueOrEmpty(arguments.q, "code_normalized", arguments.row);
      return {
        "promoCodeId" = val(arguments.q.promo_code_id[arguments.row]),
        "code" = normalized,
        "codeAvailable" = len(normalized) GT 0,
        "codeHashFingerprint" = len(hashValue) ? left(hashValue, 12) : "",
        "internalName" = valueOrEmpty(arguments.q, "internal_name", arguments.row),
        "publicDescription" = valueOrEmpty(arguments.q, "public_description", arguments.row),
        "promoType" = valueOrEmpty(arguments.q, "promo_type", arguments.row),
        "benefitType" = valueOrEmpty(arguments.q, "benefit_type", arguments.row),
        "benefitQuantity" = valueOrNull(arguments.q, "benefit_quantity", arguments.row),
        "status" = valueOrEmpty(arguments.q, "status", arguments.row),
        "effectiveStatus" = valueOrEmpty(arguments.q, "effective_status", arguments.row),
        "startsAtUtc" = valueOrNull(arguments.q, "starts_at_utc", arguments.row),
        "expiresAtUtc" = valueOrNull(arguments.q, "expires_at_utc", arguments.row),
        "maxRedemptions" = valueOrNull(arguments.q, "max_redemptions", arguments.row),
        "redemptionsCount" = val(arguments.q.redemptions_count[arguments.row]),
        "onePerUser" = truthy(arguments.q.one_per_user[arguments.row]),
        "durationMonths" = valueOrNull(arguments.q, "duration_months", arguments.row),
        "stripePromotionCodeId" = valueOrEmpty(arguments.q, "stripe_promotion_code_id", arguments.row),
        "stripeCouponId" = valueOrEmpty(arguments.q, "stripe_coupon_id", arguments.row),
        "entitlementType" = valueOrEmpty(arguments.q, "entitlement_type", arguments.row),
        "entitlementSource" = valueOrEmpty(arguments.q, "entitlement_source", arguments.row),
        "adminGrantKind" = valueOrEmpty(arguments.q, "admin_grant_kind", arguments.row),
        "adminGrantDurationDays" = valueOrNull(arguments.q, "admin_grant_duration_days", arguments.row),
        "adminGrantExpiresAtUtc" = valueOrNull(arguments.q, "admin_grant_expires_at_utc", arguments.row),
        "adminNotes" = valueOrEmpty(arguments.q, "admin_notes", arguments.row),
        "createdByUserId" = valueOrNull(arguments.q, "created_by_user_id", arguments.row),
        "updatedByUserId" = valueOrNull(arguments.q, "updated_by_user_id", arguments.row),
        "archivedAtUtc" = valueOrNull(arguments.q, "archived_at_utc", arguments.row),
        "archivedByUserId" = valueOrNull(arguments.q, "archived_by_user_id", arguments.row),
        "createdAtUtc" = valueOrNull(arguments.q, "created_at_utc", arguments.row),
        "updatedAtUtc" = valueOrNull(arguments.q, "updated_at_utc", arguments.row),
        "runtimeSupport" = runtimeSupport(valueOrEmpty(arguments.q, "promo_type", arguments.row))
      };
    </cfscript>
  </cffunction>

  <cffunction name="promoSnapshot" access="private" returntype="struct" output="false">
    <cfargument name="q" type="query" required="true">
    <cfargument name="row" type="numeric" required="true">
    <cfscript>
      var out = promoRow(arguments.q, arguments.row);
      structDelete(out, "code");
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="redemptionRow" access="private" returntype="struct" output="false">
    <cfargument name="q" type="query" required="true">
    <cfargument name="row" type="numeric" required="true">
    <cfscript>
      var codeValue = valueOrEmpty(arguments.q, "code_normalized", arguments.row);
      var hashValue = valueOrEmpty(arguments.q, "code_hash", arguments.row);
      return {
        "redemptionId" = val(arguments.q.redemption_id[arguments.row]),
        "promoCodeId" = valueOrNull(arguments.q, "promo_code_id", arguments.row),
        "promoCode" = codeValue,
        "promoHashFingerprint" = len(hashValue) ? left(hashValue, 12) : "",
        "promoName" = valueOrEmpty(arguments.q, "internal_name", arguments.row),
        "userId" = val(arguments.q.user_id[arguments.row]),
        "memberName" = trim(valueOrEmpty(arguments.q, "fName", arguments.row) & " " & valueOrEmpty(arguments.q, "lName", arguments.row)),
        "memberEmail" = valueOrEmpty(arguments.q, "email", arguments.row),
        "result" = valueOrEmpty(arguments.q, "result", arguments.row),
        "errorCode" = valueOrEmpty(arguments.q, "error_code", arguments.row),
        "entitlementId" = valueOrNull(arguments.q, "entitlement_id", arguments.row),
        "premiumTripGrantCount" = valueOrNull(arguments.q, "premium_trip_grant_count", arguments.row),
        "entitlementStartsAtUtc" = valueOrNull(arguments.q, "entitlement_starts_at_utc", arguments.row),
        "entitlementExpiresAtUtc" = valueOrNull(arguments.q, "entitlement_expires_at_utc", arguments.row),
        "stripeCheckoutSessionId" = valueOrEmpty(arguments.q, "stripe_checkout_session_id", arguments.row),
        "stripeCustomerId" = valueOrEmpty(arguments.q, "stripe_customer_id", arguments.row),
        "stripeSubscriptionId" = valueOrEmpty(arguments.q, "stripe_subscription_id", arguments.row),
        "attemptedAtUtc" = valueOrNull(arguments.q, "attempted_at_utc", arguments.row),
        "redeemedAtUtc" = valueOrNull(arguments.q, "redeemed_at_utc", arguments.row)
      };
    </cfscript>
  </cffunction>

  <cffunction name="runtimeSupport" access="private" returntype="string" output="false">
    <cfargument name="promoType" type="string" required="true">
    <cfscript>
      if (listFindNoCase("founder_lifetime,stripe_free_months,premium_trip", arguments.promoType)) return "public_redemption";
      if (arguments.promoType EQ "admin_grant") return "admin_grant_only";
      return "legacy_unsupported";
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

  <cffunction name="loadAudit" access="private" returntype="query" output="false">
    <cfargument name="entityType" type="string" required="true">
    <cfargument name="entityId" type="string" required="true">
    <cfscript>
      return queryExecute(
        "SELECT audit_id, admin_user_id, admin_email, action, entity_type, entity_id,
                previous_values_json, new_values_json, reason, created_at_utc
         FROM fpw_admin_audit_log
         WHERE entity_type = :entityType AND entity_id = :entityId
         ORDER BY audit_id DESC LIMIT 250",
        {
          entityType = { value = arguments.entityType, cfsqltype = "cf_sql_varchar" },
          entityId = { value = arguments.entityId, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
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
    <cfscript>
      if (!len(trim(arguments.value))) return {};
      try { return deserializeJSON(arguments.value); } catch (any ignored) { return {}; }
    </cfscript>
  </cffunction>

  <cffunction name="success" access="private" returntype="struct" output="false">
    <cfargument name="message" type="string" required="true">
    <cfargument name="data" type="struct" required="false" default="#structNew()#">
    <cfscript>return { "SUCCESS" = true, "AUTH" = true, "MESSAGE" = arguments.message, "DATA" = arguments.data, "ERROR" = {} };</cfscript>
  </cffunction>

  <cffunction name="failure" access="private" returntype="struct" output="false">
    <cfargument name="code" type="string" required="true">
    <cfargument name="message" type="string" required="true">
    <cfscript>return { "SUCCESS" = false, "AUTH" = true, "MESSAGE" = arguments.message, "DATA" = {}, "ERROR" = { "CODE" = arguments.code, "MESSAGE" = arguments.message } };</cfscript>
  </cffunction>

  <cffunction name="readValue" access="private" returntype="any" output="false">
    <cfargument name="source" type="struct" required="true">
    <cfargument name="key" type="string" required="true">
    <cfargument name="defaultValue" type="any" required="true">
    <cfscript>return structKeyExists(arguments.source, arguments.key) ? arguments.source[arguments.key] : arguments.defaultValue;</cfscript>
  </cffunction>

  <cffunction name="clampInt" access="private" returntype="numeric" output="false">
    <cfargument name="value" required="true">
    <cfargument name="minimum" type="numeric" required="true">
    <cfargument name="maximum" type="numeric" required="true">
    <cfargument name="defaultValue" type="numeric" required="true">
    <cfscript>
      var out = isNumeric(arguments.value) ? int(val(arguments.value)) : arguments.defaultValue;
      if (out LT arguments.minimum) out = arguments.minimum;
      if (out GT arguments.maximum) out = arguments.maximum;
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="truthy" access="private" returntype="boolean" output="false">
    <cfargument name="value" required="true">
    <cfscript>return listFindNoCase("1,true,yes,y,on", trim(toString(arguments.value))) GT 0;</cfscript>
  </cffunction>

  <cffunction name="parseDateValue" access="private" returntype="date" output="false">
    <cfargument name="value" required="true">
    <cfscript>return parseDateTime(replace(trim(toString(arguments.value)), "T", " ", "all"));</cfscript>
  </cffunction>

  <cffunction name="valueOrEmpty" access="private" returntype="string" output="false">
    <cfargument name="q" type="query" required="true">
    <cfargument name="column" type="string" required="true">
    <cfargument name="row" type="numeric" required="true">
    <cfscript>
      if (listFindNoCase(arguments.q.columnList, arguments.column) AND !isNull(arguments.q[arguments.column][arguments.row])) return toString(arguments.q[arguments.column][arguments.row]);
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="valueOrNull" access="private" returntype="any" output="false">
    <cfargument name="q" type="query" required="true">
    <cfargument name="column" type="string" required="true">
    <cfargument name="row" type="numeric" required="true">
    <cfscript>
      if (listFindNoCase(arguments.q.columnList, arguments.column) AND !isNull(arguments.q[arguments.column][arguments.row])) return arguments.q[arguments.column][arguments.row];
      return javacast("null", "");
    </cfscript>
  </cffunction>

</cfcomponent>
