<cfcomponent output="false">

  <cfset variables.datasource = "fpw">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfscript>
      variables.datasource = arguments.datasource;
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="getCurrentAccess" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var access = {
        "authenticated" = false,
        "userId" = 0,
        "memberLevel" = "basic",
        "hasPremium" = false,
        "premiumSource" = "none",
        "premiumExpiresAt" = nullValue(),
        "premiumEntitlementId" = 0,
        "premiumSources" = [],
        "hasStripeBilling" = false,
        "limits" = getBasicLimits()
      };
      var qPremium = queryNew("");

      if (arguments.userId LTE 0) {
        return access;
      }

      access.authenticated = true;
      access.userId = val(arguments.userId);
      access.premiumSources = loadCurrentPremiumSources(arguments.userId);
      access.hasStripeBilling = hasStripeBilling(arguments.userId);

      qPremium = loadCurrentPremiumEntitlement(arguments.userId);
      if (qPremium.recordCount GT 0) {
        access.memberLevel = "premium";
        access.hasPremium = true;
        access.premiumSource = normalizeEntitlementSource(qPremium.source[1]);
        access.premiumExpiresAt = queryValueOrNull(qPremium, "expires_at_utc", 1);
        access.premiumEntitlementId = val(qPremium.id[1]);
        access.limits = getPremiumLimits();
      }

      return access;
    </cfscript>
  </cffunction>

  <cffunction name="hasPremiumAccess" access="public" returntype="boolean" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      return getCurrentAccess(arguments.userId).hasPremium;
    </cfscript>
  </cffunction>

  <cffunction name="getFeatureLimits" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      return getCurrentAccess(arguments.userId).limits;
    </cfscript>
  </cffunction>

  <cffunction name="getBasicLimits" access="public" returntype="struct" output="false">
    <cfscript>
      return {
        "maxWaypoints" = 2,
        "maxTripDays" = 1,
        "canSaveRoutes" = false,
        "canUseRouteLibrary" = false,
        "canUseActiveCruise" = false,
        "canUseFollowPage" = false,
        "monitoringLevel" = "basic",
        "canUseAdvancedMonitoring" = false,
        "canUseMultiDayTrips" = false
      };
    </cfscript>
  </cffunction>

  <cffunction name="getPremiumLimits" access="public" returntype="struct" output="false">
    <cfscript>
      return {
        "maxWaypoints" = nullValue(),
        "maxTripDays" = nullValue(),
        "canSaveRoutes" = true,
        "canUseRouteLibrary" = true,
        "canUseActiveCruise" = true,
        "canUseFollowPage" = true,
        "monitoringLevel" = "advanced",
        "canUseAdvancedMonitoring" = true,
        "canUseMultiDayTrips" = true
      };
    </cfscript>
  </cffunction>

  <cffunction name="expireElapsedPasses" access="public" returntype="struct" output="false">
    <cfscript>
      var qElapsed = queryExecute(
        "SELECT COUNT(*) AS elapsed_count
         FROM member_entitlements
         WHERE entitlement_type = 'premium'
           AND source = 'three_day_pass'
           AND status = 'active'
           AND expires_at_utc IS NOT NULL
           AND expires_at_utc < UTC_TIMESTAMP()",
        {},
        { datasource = variables.datasource }
      );
      var elapsedCount = qElapsed.recordCount ? val(qElapsed.elapsed_count[1]) : 0;

      queryExecute(
        "UPDATE member_entitlements
         SET status = 'expired',
             updated_utc = UTC_TIMESTAMP()
         WHERE entitlement_type = 'premium'
           AND source = 'three_day_pass'
           AND status = 'active'
           AND expires_at_utc IS NOT NULL
           AND expires_at_utc < UTC_TIMESTAMP()",
        {},
        { datasource = variables.datasource }
      );

      return {
        "SUCCESS" = true,
        "success" = true,
        "expiredCount" = elapsedCount
      };
    </cfscript>
  </cffunction>

  <cffunction name="createAdminCompEntitlement" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="expiresAt" type="any" required="false" default="">
    <cfscript>
      return createPremiumEntitlement(
        userId = arguments.userId,
        source = "admin_comp",
        startsAt = "",
        expiresAt = arguments.expiresAt
      );
    </cfscript>
  </cffunction>

  <cffunction name="createFounderLifetimeEntitlement" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="startsAt" type="any" required="false" default="">
    <cfscript>
      return createPremiumEntitlement(
        userId = arguments.userId,
        source = "founder_lifetime",
        startsAt = arguments.startsAt,
        expiresAt = ""
      );
    </cfscript>
  </cffunction>

  <cffunction name="createThreeDayPassEntitlement" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="startsAt" type="any" required="false" default="">
    <cfscript>
      var startAtUtc = isDate(arguments.startsAt) ? arguments.startsAt : "";
      var expiresAtUtc = isDate(startAtUtc) ? dateAdd("h", 72, startAtUtc) : "";
      return createPremiumEntitlement(
        userId = arguments.userId,
        source = "three_day_pass",
        startsAt = startAtUtc,
        expiresAt = expiresAtUtc
      );
    </cfscript>
  </cffunction>

  <cffunction name="createSubscriptionEntitlement" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="stripeIdentifiers" type="struct" required="false" default="#structNew()#">
    <cfscript>
      return createPremiumEntitlement(
        userId = arguments.userId,
        source = "stripe_subscription",
        startsAt = "",
        expiresAt = "",
        stripeCustomerId = getIdentifier(arguments.stripeIdentifiers, "stripeCustomerId", "stripe_customer_id"),
        stripeSubscriptionId = getIdentifier(arguments.stripeIdentifiers, "stripeSubscriptionId", "stripe_subscription_id"),
        stripeCheckoutSessionId = getIdentifier(arguments.stripeIdentifiers, "stripeCheckoutSessionId", "stripe_checkout_session_id"),
        stripePaymentIntentId = getIdentifier(arguments.stripeIdentifiers, "stripePaymentIntentId", "stripe_payment_intent_id")
      );
    </cfscript>
  </cffunction>

  <cffunction name="loadCurrentPremiumEntitlement" access="private" returntype="query" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      return queryExecute(
        "SELECT
            id,
            user_id,
            entitlement_type,
            source,
            status,
            starts_at_utc,
            expires_at_utc
         FROM member_entitlements
         WHERE user_id = :userId
           AND entitlement_type = 'premium'
           AND status = 'active'
           AND starts_at_utc <= UTC_TIMESTAMP()
           AND (expires_at_utc IS NULL OR expires_at_utc >= UTC_TIMESTAMP())
         ORDER BY
           CASE source
             WHEN 'founder_lifetime' THEN 1
             WHEN 'stripe_subscription' THEN 2
             WHEN 'three_day_pass' THEN 3
             WHEN 'admin_comp' THEN 4
             ELSE 99
           END ASC,
           CASE WHEN expires_at_utc IS NULL THEN 1 ELSE 0 END DESC,
           expires_at_utc DESC,
           id DESC
         LIMIT 1",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
    </cfscript>
  </cffunction>

  <cffunction name="loadCurrentPremiumSources" access="private" returntype="array" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var qSources = queryExecute(
        "SELECT source
         FROM member_entitlements
         WHERE user_id = :userId
           AND entitlement_type = 'premium'
           AND status = 'active'
           AND starts_at_utc <= UTC_TIMESTAMP()
           AND (expires_at_utc IS NULL OR expires_at_utc >= UTC_TIMESTAMP())
         GROUP BY source
         ORDER BY
           CASE source
             WHEN 'founder_lifetime' THEN 1
             WHEN 'stripe_subscription' THEN 2
             WHEN 'three_day_pass' THEN 3
             WHEN 'admin_comp' THEN 4
             ELSE 99
           END ASC",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );
      var sources = [];
      var i = 0;

      for (i = 1; i <= qSources.recordCount; i++) {
        arrayAppend(sources, normalizeEntitlementSource(qSources.source[i]));
      }

      return sources;
    </cfscript>
  </cffunction>

  <cffunction name="hasStripeBilling" access="private" returntype="boolean" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var qBilling = queryExecute(
        "SELECT COUNT(*) AS billing_count
         FROM member_entitlements
         WHERE user_id = :userId
           AND entitlement_type = 'premium'
           AND source = 'stripe_subscription'
           AND stripe_customer_id IS NOT NULL
           AND stripe_customer_id <> ''",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" }
        },
        { datasource = variables.datasource }
      );

      return qBilling.recordCount GT 0 AND val(qBilling.billing_count[1]) GT 0;
    </cfscript>
  </cffunction>

  <cffunction name="createPremiumEntitlement" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="source" type="string" required="true">
    <cfargument name="startsAt" type="any" required="false" default="">
    <cfargument name="expiresAt" type="any" required="false" default="">
    <cfargument name="stripeCustomerId" type="string" required="false" default="">
    <cfargument name="stripeSubscriptionId" type="string" required="false" default="">
    <cfargument name="stripeCheckoutSessionId" type="string" required="false" default="">
    <cfargument name="stripePaymentIntentId" type="string" required="false" default="">
    <cfscript>
      var sourceValue = normalizeEntitlementSource(arguments.source);
      var hasStartsAtValue = isDate(arguments.startsAt);
      var hasExpiresAtValue = isDate(arguments.expiresAt);
      var startsAtValue = hasStartsAtValue ? arguments.startsAt : "";
      var expiresAtValue = hasExpiresAtValue ? arguments.expiresAt : "";
      var startsAtSql = hasStartsAtValue ? ":startsAtUtc" : "UTC_TIMESTAMP()";
      var expiresAtSql = hasExpiresAtValue
        ? ":expiresAtUtc"
        : (sourceValue EQ "three_day_pass" ? "DATE_ADD(UTC_TIMESTAMP(), INTERVAL 72 HOUR)" : "NULL");
      var params = {};
      var qNewId = queryNew("");
      var qCreated = queryNew("");
      var entitlementId = 0;

      if (arguments.userId LTE 0) {
        return {
          "SUCCESS" = false,
          "success" = false,
          "ERROR" = "INVALID_USER_ID",
          "message" = "A valid userId is required."
        };
      }

      if (!listFindNoCase("founder_lifetime,stripe_subscription,three_day_pass,admin_comp", sourceValue)) {
        return {
          "SUCCESS" = false,
          "success" = false,
          "ERROR" = "INVALID_ENTITLEMENT_SOURCE",
          "message" = "Entitlement source is not supported."
        };
      }

      params = {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        source = { value = sourceValue, cfsqltype = "cf_sql_varchar" },
        stripeCustomerId = { value = trim(arguments.stripeCustomerId), cfsqltype = "cf_sql_varchar", null = !len(trim(arguments.stripeCustomerId)) },
        stripeSubscriptionId = { value = trim(arguments.stripeSubscriptionId), cfsqltype = "cf_sql_varchar", null = !len(trim(arguments.stripeSubscriptionId)) },
        stripeCheckoutSessionId = { value = trim(arguments.stripeCheckoutSessionId), cfsqltype = "cf_sql_varchar", null = !len(trim(arguments.stripeCheckoutSessionId)) },
        stripePaymentIntentId = { value = trim(arguments.stripePaymentIntentId), cfsqltype = "cf_sql_varchar", null = !len(trim(arguments.stripePaymentIntentId)) }
      };
      if (hasStartsAtValue) {
        params.startsAtUtc = { value = startsAtValue, cfsqltype = "cf_sql_timestamp" };
      }
      if (hasExpiresAtValue) {
        params.expiresAtUtc = { value = expiresAtValue, cfsqltype = "cf_sql_timestamp" };
      }

      queryExecute(
        "INSERT INTO member_entitlements (
           user_id,
           entitlement_type,
           source,
           status,
           starts_at_utc,
           expires_at_utc,
           stripe_customer_id,
           stripe_subscription_id,
           stripe_checkout_session_id,
           stripe_payment_intent_id,
           created_utc,
           updated_utc
         ) VALUES (
           :userId,
           'premium',
           :source,
           'active',
           " & startsAtSql & ",
           " & expiresAtSql & ",
           :stripeCustomerId,
           :stripeSubscriptionId,
           :stripeCheckoutSessionId,
           :stripePaymentIntentId,
           UTC_TIMESTAMP(),
           UTC_TIMESTAMP()
         )",
        params,
        { datasource = variables.datasource }
      );

      qNewId = queryExecute(
        "SELECT LAST_INSERT_ID() AS new_id",
        {},
        { datasource = variables.datasource }
      );
      entitlementId = qNewId.recordCount ? val(qNewId.new_id[1]) : 0;
      if (entitlementId GT 0) {
        qCreated = queryExecute(
          "SELECT starts_at_utc, expires_at_utc
           FROM member_entitlements
           WHERE id = :id
           LIMIT 1",
          {
            id = { value = entitlementId, cfsqltype = "cf_sql_bigint" }
          },
          { datasource = variables.datasource }
        );
      }

      return {
        "SUCCESS" = true,
        "success" = true,
        "entitlementId" = entitlementId,
        "userId" = val(arguments.userId),
        "entitlementType" = "premium",
        "source" = sourceValue,
        "status" = "active",
        "startsAtUtc" = qCreated.recordCount ? qCreated.starts_at_utc[1] : nullValue(),
        "expiresAtUtc" = qCreated.recordCount ? queryValueOrNull(qCreated, "expires_at_utc", 1) : nullValue()
      };
    </cfscript>
  </cffunction>

  <cffunction name="normalizeEntitlementSource" access="private" returntype="string" output="false">
    <cfargument name="source" type="any" required="true">
    <cfscript>
      return lCase(trim(toString(arguments.source)));
    </cfscript>
  </cffunction>

  <cffunction name="getIdentifier" access="private" returntype="string" output="false">
    <cfargument name="source" type="struct" required="true">
    <cfargument name="camelKey" type="string" required="true">
    <cfargument name="snakeKey" type="string" required="true">
    <cfscript>
      if (structKeyExists(arguments.source, arguments.camelKey)) {
        return trim(toString(arguments.source[arguments.camelKey]));
      }
      if (structKeyExists(arguments.source, arguments.snakeKey)) {
        return trim(toString(arguments.source[arguments.snakeKey]));
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="queryValueOrNull" access="private" returntype="any" output="false">
    <cfargument name="q" type="query" required="true">
    <cfargument name="column" type="string" required="true">
    <cfargument name="row" type="numeric" required="true">
    <cfscript>
      if (
        arguments.q.recordCount GTE arguments.row
        AND listFindNoCase(arguments.q.columnList, arguments.column)
        AND !isNull(arguments.q[arguments.column][arguments.row])
      ) {
        return arguments.q[arguments.column][arguments.row];
      }
      return nullValue();
    </cfscript>
  </cffunction>

  <cffunction name="currentUtc" access="private" returntype="date" output="false">
    <cfscript>
      return dateConvert("local2utc", now());
    </cfscript>
  </cffunction>

  <cffunction name="nullValue" access="private" returntype="any" output="false">
    <cfscript>
      return javacast("null", "");
    </cfscript>
  </cffunction>

</cfcomponent>
