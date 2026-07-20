<cfcomponent output="false" hint="Canonical Premium Trip grant, creation-lease, and lifecycle authority.">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfscript>
      variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
      variables.creationLeaseMinutes = 60;
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="grantIntroductoryTrip" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var userIdValue = int(val(arguments.userId));
      var existing = queryNew("");
      var insertResult = {};
      var created = false;
      var grantEventKey = "introductory:" & userIdValue;
      if (!validUser(userIdValue)) {
        return failure("INVALID_USER", "A valid member is required.");
      }
      transaction {
        queryExecute(
          "INSERT INTO member_premium_trip_entitlements (user_id,grant_source,grant_reference,grant_sequence,status,granted_at_utc,created_at_utc,updated_at_utc)
           VALUES (:userId,'introductory',:reference,1,'AVAILABLE',UTC_TIMESTAMP(),UTC_TIMESTAMP(),UTC_TIMESTAMP())
           ON DUPLICATE KEY UPDATE premium_trip_entitlement_id=LAST_INSERT_ID(premium_trip_entitlement_id)",
          {
            userId={value=userIdValue,cfsqltype="cf_sql_integer"},
            reference={value="introductory:" & userIdValue,cfsqltype="cf_sql_varchar"}
          },
          { datasource=variables.datasource, result="insertResult" }
        );
        existing = loadEntitlementForUpdate(val(insertResult.generatedKey));
        created = !hasEventKey(grantEventKey);
        if (created) {
          writeEvent(existing, "INTRODUCTORY_GRANT", "", "AVAILABLE", "system", 0, 0, "Introductory Premium Trip granted.", grantEventKey);
        }
      }
      return entitlementResponse(existing, created, "Introductory Premium Trip is available.");
    </cfscript>
  </cffunction>

  <cffunction name="grantPurchasedTrip" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="stripeReferences" type="struct" required="true">
    <cfscript>
      var refs = normalizeStripeReferences(arguments.stripeReferences);
      var reference = refs.checkoutSessionId;
      var existing = queryNew("");
      var existingResponse = {};
      if (!len(reference)) reference = refs.paymentIntentId;
      if (!len(reference)) {
        return failure("STRIPE_IDENTITY_REQUIRED", "Checkout Session or PaymentIntent identity is required.");
      }
      existing = findEntitlementByStripeReferences(refs, false);
      if (existing.recordCount) {
        if (val(existing.user_id[1]) NEQ int(val(arguments.userId))) {
          return failure("STRIPE_IDENTITY_CONFLICT", "Stripe payment identity belongs to another member.");
        }
        existingResponse = entitlementResponse(existing, false, "Paid Premium Trip was already granted.");
        existingResponse.duplicate = true;
        existingResponse.replayed = true;
        return existingResponse;
      }
      return grantTrips(
        userId=int(val(arguments.userId)),
        source="stripe_purchase",
        reference=reference,
        quantity=1,
        stripeReferences=refs,
        actorType="stripe",
        actorUserId=0,
        promoCodeId=0,
        adminGrantId=0,
        reason="Paid Premium Trip granted."
      );
    </cfscript>
  </cffunction>

  <cffunction name="grantPromoTrips" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="promoCodeId" type="numeric" required="true">
    <cfargument name="quantity" type="numeric" required="true">
    <cfargument name="grantReference" type="string" required="true">
    <cfscript>
      if (int(val(arguments.promoCodeId)) LTE 0 OR !len(trim(arguments.grantReference))) {
        return failure("INVALID_PROMO_GRANT", "Promo identity is required.");
      }
      return grantTrips(
        userId=int(val(arguments.userId)),
        source="promo",
        reference=trim(arguments.grantReference),
        quantity=int(val(arguments.quantity)),
        stripeReferences={},
        actorType="system",
        actorUserId=0,
        promoCodeId=int(val(arguments.promoCodeId)),
        adminGrantId=0,
        reason="Premium Trip promo redeemed."
      );
    </cfscript>
  </cffunction>

  <cffunction name="grantAdminTrips" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="adminReference" type="string" required="true">
    <cfargument name="quantity" type="numeric" required="true">
    <cfargument name="actorUserId" type="numeric" required="true">
    <cfargument name="reason" type="string" required="true">
    <cfscript>
      if (int(val(arguments.actorUserId)) LTE 0 OR !len(trim(arguments.adminReference)) OR !len(trim(arguments.reason))) {
        return failure("ADMIN_AUTHORITY_REQUIRED", "Administrative actor, reference, and reason are required.");
      }
      return grantTrips(
        userId=int(val(arguments.userId)),
        source="admin",
        reference=trim(arguments.adminReference),
        quantity=int(val(arguments.quantity)),
        stripeReferences={},
        actorType="admin",
        actorUserId=int(val(arguments.actorUserId)),
        promoCodeId=0,
        adminGrantId=0,
        reason=trim(arguments.reason)
      );
    </cfscript>
  </cffunction>

  <cffunction name="grantReferralTrips" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="referralReference" type="string" required="true">
    <cfargument name="quantity" type="numeric" required="false" default="1">
    <cfscript>
      return grantTrips(
        userId=int(val(arguments.userId)), source="referral", reference=trim(arguments.referralReference),
        quantity=int(val(arguments.quantity)), stripeReferences={}, actorType="system", actorUserId=0,
        promoCodeId=0, adminGrantId=0, reason="Referral Premium Trip granted."
      );
    </cfscript>
  </cffunction>

  <cffunction name="getAvailableTrips" access="public" returntype="array" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var rows = queryExecute(
        "SELECT * FROM member_premium_trip_entitlements WHERE user_id=:userId AND status='AVAILABLE' ORDER BY granted_at_utc,premium_trip_entitlement_id",
        { userId={value=int(val(arguments.userId)),cfsqltype="cf_sql_integer"} },
        { datasource=variables.datasource }
      );
      return queryToArray(rows);
    </cfscript>
  </cffunction>

  <cffunction name="getTripEntitlementForCanonicalTrip" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="canonicalTripId" type="numeric" required="true">
    <cfscript>
      var row = queryExecute(
        "SELECT * FROM member_premium_trip_entitlements WHERE user_id=:userId AND canonical_trip_id=:tripId ORDER BY premium_trip_entitlement_id DESC LIMIT 1",
        {
          userId={value=int(val(arguments.userId)),cfsqltype="cf_sql_integer"},
          tripId={value=int(val(arguments.canonicalTripId)),cfsqltype="cf_sql_integer"}
        },
        { datasource=variables.datasource }
      );
      return row.recordCount ? queryRowToStruct(row,1) : {};
    </cfscript>
  </cffunction>

  <cffunction name="getTripCounts" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var q = queryExecute(
        "SELECT status,COUNT(*) AS count_value FROM member_premium_trip_entitlements WHERE user_id=:userId GROUP BY status",
        { userId={value=int(val(arguments.userId)),cfsqltype="cf_sql_integer"} },
        { datasource=variables.datasource }
      );
      var out={ available=0,reserved=0,active=0,consumed=0,revoked=0 };
      var i=0;
      for(i=1;i<=q.recordCount;i++) out[lCase(q.status[i])]=val(q.count_value[i]);
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="getActiveTripId" access="public" returntype="numeric" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfscript>
      var q=queryExecute(
        "SELECT canonical_trip_id FROM member_premium_trip_entitlements WHERE user_id=:userId AND status='ACTIVE' AND canonical_trip_id IS NOT NULL ORDER BY activated_at_utc DESC,premium_trip_entitlement_id DESC LIMIT 1",
        {userId={value=int(val(arguments.userId)),cfsqltype="cf_sql_integer"}},
        {datasource=variables.datasource}
      );
      return q.recordCount?val(q.canonical_trip_id[1]):0;
    </cfscript>
  </cffunction>

  <cffunction name="hasTripPremiumAccess" access="public" returntype="boolean" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="canonicalTripId" type="numeric" required="true">
    <cfscript>
      var q=queryExecute(
        "SELECT premium_trip_entitlement_id FROM member_premium_trip_entitlements WHERE user_id=:userId AND canonical_trip_id=:tripId AND status IN ('RESERVED','ACTIVE') LIMIT 1",
        {userId={value=int(val(arguments.userId)),cfsqltype="cf_sql_integer"},tripId={value=int(val(arguments.canonicalTripId)),cfsqltype="cf_sql_integer"}},
        {datasource=variables.datasource}
      );
      return q.recordCount GT 0;
    </cfscript>
  </cffunction>

  <cffunction name="createCreationSession" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="entitlementId" type="numeric" required="false" default="0">
    <cftry>
    <cfscript>
      var uid=int(val(arguments.userId)); var eid=int(val(arguments.entitlementId));
      var entitlement=queryNew(""); var existing=queryNew(""); var insertResult={};
      var rawToken=""; var tokenHash=""; var sessionRow=queryNew("");
      if(!validUser(uid)) return failure("INVALID_USER","A valid member is required.");
      expireStaleCreationSessions(uid);
      transaction {
        if(eid GT 0) {
          entitlement=queryExecute("SELECT * FROM member_premium_trip_entitlements WHERE premium_trip_entitlement_id=:id AND user_id=:userId LIMIT 1 FOR UPDATE",{id={value=eid,cfsqltype="cf_sql_bigint"},userId={value=uid,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
        } else {
          entitlement=queryExecute("SELECT * FROM member_premium_trip_entitlements WHERE user_id=:userId AND status='AVAILABLE' ORDER BY granted_at_utc,premium_trip_entitlement_id LIMIT 1 FOR UPDATE",{userId={value=uid,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
        }
        if(!entitlement.recordCount OR entitlement.status[1] NEQ "AVAILABLE") throw(type="PremiumTrip.NoAvailable",message="No available Premium Trip is eligible for route preparation.");
        eid=val(entitlement.premium_trip_entitlement_id[1]);
        existing=queryExecute("SELECT * FROM premium_trip_creation_sessions WHERE premium_trip_entitlement_id=:id AND status='ACTIVE' LIMIT 1 FOR UPDATE",{id={value=eid,cfsqltype="cf_sql_bigint"}},{datasource=variables.datasource});
        if(existing.recordCount) throw(type="PremiumTrip.SessionExists",message="This Premium Trip already has an active creation session.");
        rawToken=createOpaqueToken(); tokenHash=hashToken(rawToken);
        queryExecute(
          "INSERT INTO premium_trip_creation_sessions (user_id,premium_trip_entitlement_id,token_hash,status,created_at_utc,last_activity_at_utc,expires_at_utc,updated_at_utc) VALUES (:userId,:entitlementId,:tokenHash,'ACTIVE',UTC_TIMESTAMP(),UTC_TIMESTAMP(),DATE_ADD(UTC_TIMESTAMP(),INTERVAL 60 MINUTE),UTC_TIMESTAMP())",
          {userId={value=uid,cfsqltype="cf_sql_integer"},entitlementId={value=eid,cfsqltype="cf_sql_bigint"},tokenHash={value=tokenHash,cfsqltype="cf_sql_varchar"}},
          {datasource=variables.datasource,result="insertResult"}
        );
        sessionRow=loadCreationSessionForUpdate(val(insertResult.generatedKey));
        writeEvent(entitlement,"CREATION_SESSION_CREATED","AVAILABLE","AVAILABLE","member",uid,val(sessionRow.creation_session_id[1]),"60-minute route creation lease created.","creation-session:" & val(sessionRow.creation_session_id[1]));
      }
      return creationSessionResponse(sessionRow,rawToken,"Premium Trip creation session created.");
    </cfscript>
    <cfcatch type="PremiumTrip.NoAvailable"><cfreturn failure("NO_AVAILABLE_PREMIUM_TRIP",cfcatch.message)></cfcatch>
    <cfcatch type="PremiumTrip.SessionExists"><cfreturn failure("CREATION_SESSION_ALREADY_ACTIVE",cfcatch.message)></cfcatch>
    </cftry>
  </cffunction>

  <cffunction name="authorizeCreationAction" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="rawToken" type="string" required="true">
    <cfargument name="actionName" type="string" required="true">
    <cfargument name="routeInstanceId" type="numeric" required="false" default="0">
    <cftry>
    <cfscript>
      var uid=int(val(arguments.userId)); var action=lCase(trim(arguments.actionName));
      var rid=int(val(arguments.routeInstanceId)); var sessionRow=queryNew(""); var entitlement=queryNew("");
      var actionClaimToken="";
      var allowedActions="routegen_generate,routegen_update,routegen_savelegoverride,routegen_clearlegoverride,buildfloatplansfromroute";
      if(!listFindNoCase(allowedActions,action)) return failure("CREATION_ACTION_NOT_ALLOWED","This creation session cannot authorize the requested action.");
      expireStaleCreationSessions(uid);
      transaction {
        sessionRow=loadCreationSessionByTokenForUpdate(arguments.rawToken);
        validateActiveCreationSession(sessionRow,uid);
        entitlement=loadEntitlementForUpdate(val(sessionRow.premium_trip_entitlement_id[1]));
        if(!entitlement.recordCount OR entitlement.status[1] NEQ "AVAILABLE") throw(type="PremiumTrip.EntitlementUnavailable",message="The Premium Trip is no longer available.");
        if(action EQ "routegen_generate" AND !isNull(sessionRow.prepared_route_instance_id[1]) AND val(sessionRow.prepared_route_instance_id[1]) GT 0) throw(type="PremiumTrip.RouteAlreadyPrepared",message="This creation session already has a prepared route.");
        if(action NEQ "routegen_generate" AND rid LTE 0) throw(type="PremiumTrip.RouteRequired",message="The prepared route is required for this creation action.");
        if(rid GT 0 AND !isNull(sessionRow.prepared_route_instance_id[1]) AND val(sessionRow.prepared_route_instance_id[1]) GT 0 AND val(sessionRow.prepared_route_instance_id[1]) NEQ rid) throw(type="PremiumTrip.RouteMismatch",message="The creation session is locked to a different route.");
        if(val(sessionRow.action_claim_is_active[1]) EQ 1) throw(type="PremiumTrip.ConcurrentUse",message="This creation session is already processing another route action.");
        actionClaimToken=createOpaqueToken();
        queryExecute(
          "UPDATE premium_trip_creation_sessions
           SET action_claim_hash=:claimHash,action_claim_name=:actionName,
               action_claimed_at_utc=UTC_TIMESTAMP(),action_claim_expires_at_utc=DATE_ADD(UTC_TIMESTAMP(),INTERVAL 60 MINUTE),
               last_activity_at_utc=UTC_TIMESTAMP(),expires_at_utc=DATE_ADD(UTC_TIMESTAMP(),INTERVAL 60 MINUTE),
               lock_version=lock_version+1
           WHERE creation_session_id=:id AND status='ACTIVE'",
          {
            claimHash={value=hashToken(actionClaimToken),cfsqltype="cf_sql_varchar"},
            actionName={value=action,cfsqltype="cf_sql_varchar"},
            id={value=val(sessionRow.creation_session_id[1]),cfsqltype="cf_sql_bigint"}
          },
          {datasource=variables.datasource}
        );
        sessionRow=loadCreationSessionForUpdate(val(sessionRow.creation_session_id[1]));
      }
      var sessionView=queryRowToStruct(sessionRow,1);
      structDelete(sessionView,"TOKEN_HASH");
      structDelete(sessionView,"ACTION_CLAIM_HASH");
      return {
        SUCCESS=true,success=true,allowed=true,creationSession=sessionView,
        creationActionClaimToken=actionClaimToken,
        creationActionClaimSessionId=val(sessionRow.creation_session_id[1])
      };
    </cfscript>
    <cfcatch type="PremiumTrip"><cfreturn failure(cfcatch.type,cfcatch.message)></cfcatch>
    </cftry>
  </cffunction>

  <cffunction name="finishCreationAction" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true"><cfargument name="rawToken" type="string" required="true"><cfargument name="actionClaimToken" type="string" required="true">
    <cftry>
    <cfscript>
      var uid=int(val(arguments.userId)); var s=queryNew(""); var releaseResult={};
      if(!len(trim(arguments.actionClaimToken))) return failure("ACTION_CLAIM_REQUIRED","Creation action claim is required.");
      transaction {
        s=loadCreationSessionByTokenForUpdate(arguments.rawToken);
        if(!s.recordCount) throw(type="PremiumTrip.SessionInvalid",message="Creation session is invalid.");
        if(val(s.user_id[1]) NEQ uid) throw(type="PremiumTrip.SessionOwnership",message="Creation session does not belong to this member.");
        if(isNull(s.action_claim_hash[1]) OR !len(s.action_claim_hash[1])) {
          releaseResult={SUCCESS=true,success=true,released=false};
        } else {
          if(compareNoCase(s.action_claim_hash[1],hashToken(arguments.actionClaimToken)) NEQ 0) throw(type="PremiumTrip.ActionClaimMismatch",message="Creation action claim does not match the active request.");
          queryExecute(
            "UPDATE premium_trip_creation_sessions
             SET action_claim_hash=NULL,action_claim_name=NULL,action_claimed_at_utc=NULL,action_claim_expires_at_utc=NULL,
                 lock_version=lock_version+1
             WHERE creation_session_id=:id AND action_claim_hash=:claimHash",
            {
              id={value=val(s.creation_session_id[1]),cfsqltype="cf_sql_bigint"},
              claimHash={value=hashToken(arguments.actionClaimToken),cfsqltype="cf_sql_varchar"}
            },
            {datasource=variables.datasource}
          );
          releaseResult={SUCCESS=true,success=true,released=true};
        }
      }
      return releaseResult;
    </cfscript><cfcatch type="PremiumTrip"><cfreturn failure(cfcatch.type,cfcatch.message)></cfcatch>
    <cfcatch type="any"><cfreturn failure("ACTION_CLAIM_RELEASE_FAILED","Creation action claim could not be released.")></cfcatch>
    </cftry>
  </cffunction>

  <cffunction name="attachPreparedRoute" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true"><cfargument name="rawToken" type="string" required="true"><cfargument name="routeInstanceId" type="numeric" required="true">
    <cftry>
    <cfscript>
      var uid=int(val(arguments.userId)); var rid=int(val(arguments.routeInstanceId)); var s=queryNew(""); var qRoute=queryNew("");
      expireStaleCreationSessions(uid);
      transaction {
        s=loadCreationSessionByTokenForUpdate(arguments.rawToken); validateActiveCreationSession(s,uid);
        if(val(s.action_claim_is_active[1]) NEQ 1 OR compareNoCase(s.action_claim_name[1],"routegen_generate") NEQ 0) throw(type="PremiumTrip.ActionClaimRequired",message="An active route-generation claim is required.");
        qRoute=queryExecute("SELECT id FROM route_instances WHERE id=:id AND user_id=:userId LIMIT 1 FOR UPDATE",{id={value=rid,cfsqltype="cf_sql_integer"},userId={value=toString(uid),cfsqltype="cf_sql_varchar"}},{datasource=variables.datasource});
        if(!qRoute.recordCount) throw(type="PremiumTrip.RouteOwnership",message="Prepared route does not belong to this member.");
        if(!isNull(s.prepared_route_instance_id[1]) AND val(s.prepared_route_instance_id[1]) GT 0 AND val(s.prepared_route_instance_id[1]) NEQ rid) throw(type="PremiumTrip.RouteMismatch",message="The creation session is locked to another route.");
        queryExecute("UPDATE premium_trip_creation_sessions SET prepared_route_instance_id=:routeId,last_activity_at_utc=UTC_TIMESTAMP(),expires_at_utc=DATE_ADD(UTC_TIMESTAMP(),INTERVAL 60 MINUTE),lock_version=lock_version+1 WHERE creation_session_id=:id AND status='ACTIVE'",{routeId={value=rid,cfsqltype="cf_sql_integer"},id={value=val(s.creation_session_id[1]),cfsqltype="cf_sql_bigint"}},{datasource=variables.datasource});
      }
      return {SUCCESS=true,success=true,ROUTE_INSTANCE_ID=rid};
    </cfscript><cfcatch type="PremiumTrip"><cfreturn failure(cfcatch.type,cfcatch.message)></cfcatch>
    </cftry>
  </cffunction>

  <cffunction name="attachPreparedFloatPlan" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true"><cfargument name="rawToken" type="string" required="true"><cfargument name="floatPlanId" type="numeric" required="true"><cfargument name="routeInstanceId" type="numeric" required="true">
    <cftry>
    <cfscript>
      var uid=int(val(arguments.userId)); var fid=int(val(arguments.floatPlanId)); var rid=int(val(arguments.routeInstanceId));
      var s=queryNew(""); var e=queryNew(""); var p=queryNew(""); var oldPlanId=0;
      expireStaleCreationSessions(uid);
      transaction {
        s=loadCreationSessionByTokenForUpdate(arguments.rawToken); validateActiveCreationSession(s,uid);
        if(val(s.action_claim_is_active[1]) NEQ 1 OR compareNoCase(s.action_claim_name[1],"buildfloatplansfromroute") NEQ 0) throw(type="PremiumTrip.ActionClaimRequired",message="An active float-plan build claim is required.");
        e=loadEntitlementForUpdate(val(s.premium_trip_entitlement_id[1]));
        if(!e.recordCount OR e.status[1] NEQ "AVAILABLE") throw(type="PremiumTrip.EntitlementUnavailable",message="The Premium Trip is no longer available.");
        p=loadEligibleDraftForUpdate(uid,fid);
        if(!p.recordCount OR val(p.route_instance_id[1]) NEQ rid) throw(type="PremiumTrip.DraftInvalid",message="The prepared Draft float plan is not eligible.");
        if(!isNull(s.prepared_route_instance_id[1]) AND val(s.prepared_route_instance_id[1]) GT 0 AND val(s.prepared_route_instance_id[1]) NEQ rid) throw(type="PremiumTrip.RouteMismatch",message="The prepared route does not match the creation session.");
        oldPlanId=isNull(s.prepared_float_plan_id[1])?0:val(s.prepared_float_plan_id[1]);
        queryExecute("UPDATE premium_trip_creation_sessions SET prepared_route_instance_id=:routeId,prepared_float_plan_id=:planId,last_activity_at_utc=UTC_TIMESTAMP(),expires_at_utc=DATE_ADD(UTC_TIMESTAMP(),INTERVAL 60 MINUTE),lock_version=lock_version+1 WHERE creation_session_id=:id AND status='ACTIVE'",{routeId={value=rid,cfsqltype="cf_sql_integer"},planId={value=fid,cfsqltype="cf_sql_integer"},id={value=val(s.creation_session_id[1]),cfsqltype="cf_sql_bigint"}},{datasource=variables.datasource});
        writeEvent(e,oldPlanId GT 0 AND oldPlanId NEQ fid?"CREATION_SESSION_FLOATPLAN_UPDATED":"CREATION_SESSION_FLOATPLAN_ATTACHED","AVAILABLE","AVAILABLE","member",uid,val(s.creation_session_id[1]),"Draft float plan prepared without reserving the entitlement.","session-plan:" & val(s.creation_session_id[1]) & ":" & fid);
      }
      return {SUCCESS=true,success=true,FLOATPLAN_ID=fid,ENTITLEMENT_STATUS="AVAILABLE"};
    </cfscript><cfcatch type="PremiumTrip"><cfreturn failure(cfcatch.type,cfcatch.message)></cfcatch>
    </cftry>
  </cffunction>

  <cffunction name="applyCreationSessionToPreparedTrip" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true"><cfargument name="rawToken" type="string" required="true"><cfargument name="floatPlanId" type="numeric" required="true">
    <cftry>
    <cfscript>
      var uid=int(val(arguments.userId)); var fid=int(val(arguments.floatPlanId)); var s=queryNew(""); var e=queryNew(""); var p=queryNew(""); var other=queryNew("");
      var reserveResult={}; var completeResult={}; var returnValue={};
      expireStaleCreationSessions(uid);
      transaction {
        s=loadCreationSessionByTokenForUpdate(arguments.rawToken);
        if(!s.recordCount) throw(type="PremiumTrip.SessionInvalid",message="Creation session is invalid.");
        if(val(s.user_id[1]) NEQ uid) throw(type="PremiumTrip.SessionOwnership",message="Creation session does not belong to this member.");
        if(val(s.action_claim_is_active[1]) EQ 1) throw(type="PremiumTrip.ConcurrentUse",message="This creation session is already processing a route action.");
        e=loadEntitlementForUpdate(val(s.premium_trip_entitlement_id[1]));
        if(s.status[1] EQ "COMPLETED") {
          if(e.recordCount AND e.status[1] EQ "RESERVED" AND !isNull(e.canonical_trip_id[1]) AND val(e.canonical_trip_id[1]) EQ fid AND !isNull(s.prepared_float_plan_id[1]) AND val(s.prepared_float_plan_id[1]) EQ fid) {
            returnValue=entitlementResponse(e,false,"Premium Trip was already reserved for this float plan."); returnValue.duplicate=true; returnValue.replayed=true;
          } else throw(type="PremiumTrip.SessionCompleted",message="Creation session is already completed.");
        } else {
          validateActiveCreationSession(s,uid);
          if(isNull(s.prepared_float_plan_id[1]) OR val(s.prepared_float_plan_id[1]) NEQ fid) throw(type="PremiumTrip.PreparedTripMismatch",message="The requested float plan is not the prepared trip for this session.");
          if(!e.recordCount OR e.user_id[1] NEQ uid OR e.status[1] NEQ "AVAILABLE") throw(type="PremiumTrip.EntitlementUnavailable",message="The Premium Trip is no longer available.");
          p=loadEligibleDraftForUpdate(uid,fid);
          if(!p.recordCount) throw(type="PremiumTrip.DraftInvalid",message="The prepared float plan is not an eligible Draft.");
          if(isNull(p.route_instance_id[1]) OR val(p.route_instance_id[1]) LTE 0 OR (!isNull(s.prepared_route_instance_id[1]) AND val(s.prepared_route_instance_id[1]) GT 0 AND val(s.prepared_route_instance_id[1]) NEQ val(p.route_instance_id[1]))) throw(type="PremiumTrip.RouteMismatch",message="The prepared float plan route does not match the creation session.");
          other=queryExecute("SELECT premium_trip_entitlement_id FROM member_premium_trip_entitlements WHERE canonical_trip_id=:tripId LIMIT 1 FOR UPDATE",{tripId={value=fid,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
          if(other.recordCount) throw(type="PremiumTrip.TripAlreadyAssigned",message="This float plan already has a Premium Trip entitlement.");
          queryExecute("UPDATE member_premium_trip_entitlements SET status='RESERVED',canonical_trip_id=:tripId,reserved_at_utc=UTC_TIMESTAMP(),updated_at_utc=UTC_TIMESTAMP() WHERE premium_trip_entitlement_id=:id AND user_id=:userId AND status='AVAILABLE' AND canonical_trip_id IS NULL",{tripId={value=fid,cfsqltype="cf_sql_integer"},id={value=val(e.premium_trip_entitlement_id[1]),cfsqltype="cf_sql_bigint"},userId={value=uid,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource,result="reserveResult"});
          if(reserveResult.recordCount NEQ 1) throw(type="PremiumTrip.ConcurrentReservation",message="The Premium Trip was reserved by another request.");
          queryExecute("UPDATE premium_trip_creation_sessions SET status='COMPLETED',completed_at_utc=UTC_TIMESTAMP(),last_activity_at_utc=UTC_TIMESTAMP(),action_claim_hash=NULL,action_claim_name=NULL,action_claimed_at_utc=NULL,action_claim_expires_at_utc=NULL,lock_version=lock_version+1 WHERE creation_session_id=:id AND status='ACTIVE'",{id={value=val(s.creation_session_id[1]),cfsqltype="cf_sql_bigint"}},{datasource=variables.datasource,result="completeResult"});
          if(completeResult.recordCount NEQ 1) throw(type="PremiumTrip.ConcurrentCompletion",message="The creation session was completed by another request.");
          e=loadEntitlementForUpdate(val(e.premium_trip_entitlement_id[1]));
          writeEvent(e,"RESERVE","AVAILABLE","RESERVED","member",uid,val(s.creation_session_id[1]),"Premium Trip explicitly applied to prepared float plan.","reserve-session:" & val(s.creation_session_id[1]));
          writeEvent(e,"CREATION_SESSION_COMPLETED","RESERVED","RESERVED","member",uid,val(s.creation_session_id[1]),"Creation session completed at explicit reservation commitment.","complete-session:" & val(s.creation_session_id[1]));
          returnValue=entitlementResponse(e,true,"Premium Trip reserved for the prepared float plan."); returnValue.creationSessionCompleted=true;
        }
      }
      return returnValue;
    </cfscript><cfcatch type="PremiumTrip"><cfreturn failure(cfcatch.type,cfcatch.message)></cfcatch>
    </cftry>
  </cffunction>

  <cffunction name="cancelCreationSession" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true"><cfargument name="rawToken" type="string" required="true"><cfargument name="reason" type="string" required="false" default="Canceled by member.">
    <cftry>
    <cfscript>
      var uid=int(val(arguments.userId)); var s=queryNew(""); var e=queryNew("");
      expireStaleCreationSessions(uid);
      transaction {
        s=loadCreationSessionByTokenForUpdate(arguments.rawToken); validateActiveCreationSession(s,uid); e=loadEntitlementForUpdate(val(s.premium_trip_entitlement_id[1]));
        if(val(s.action_claim_is_active[1]) EQ 1) throw(type="PremiumTrip.ConcurrentUse",message="This creation session is already processing a route action.");
        queryExecute("UPDATE premium_trip_creation_sessions SET status='CANCELED',canceled_at_utc=UTC_TIMESTAMP(),cancellation_reason=:reason,action_claim_hash=NULL,action_claim_name=NULL,action_claimed_at_utc=NULL,action_claim_expires_at_utc=NULL,lock_version=lock_version+1 WHERE creation_session_id=:id AND status='ACTIVE'",{reason={value=left(trim(arguments.reason),500),cfsqltype="cf_sql_varchar"},id={value=val(s.creation_session_id[1]),cfsqltype="cf_sql_bigint"}},{datasource=variables.datasource});
        writeEvent(e,"CREATION_SESSION_CANCELED",e.status[1],e.status[1],"member",uid,val(s.creation_session_id[1]),left(trim(arguments.reason),500),"cancel-session:" & val(s.creation_session_id[1]));
      }
      return {SUCCESS=true,success=true,ENTITLEMENT_STATUS=e.status[1]};
    </cfscript><cfcatch type="PremiumTrip"><cfreturn failure(cfcatch.type,cfcatch.message)></cfcatch>
    </cftry>
  </cffunction>

  <cffunction name="expireStaleCreationSessions" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="false" default="0">
    <cfscript>
      var uid=int(val(arguments.userId)); var q=queryNew(""); var i=0; var e=queryNew(""); var count=0; var expireResult={};
      transaction {
        q=queryExecute("SELECT * FROM premium_trip_creation_sessions WHERE status='ACTIVE' AND expires_at_utc <= UTC_TIMESTAMP()" & (uid GT 0?" AND user_id=:userId":"") & " FOR UPDATE",uid GT 0?{userId={value=uid,cfsqltype="cf_sql_integer"}}:{},{datasource=variables.datasource});
        for(i=1;i<=q.recordCount;i++) {
          queryExecute("UPDATE premium_trip_creation_sessions SET status='EXPIRED',expired_at_utc=UTC_TIMESTAMP(),action_claim_hash=NULL,action_claim_name=NULL,action_claimed_at_utc=NULL,action_claim_expires_at_utc=NULL,lock_version=lock_version+1 WHERE creation_session_id=:id AND status='ACTIVE'",{id={value=val(q.creation_session_id[i]),cfsqltype="cf_sql_bigint"}},{datasource=variables.datasource,result="expireResult"});
          if(expireResult.recordCount EQ 1) { e=loadEntitlementForUpdate(val(q.premium_trip_entitlement_id[i])); writeEvent(e,"CREATION_SESSION_EXPIRED",e.status[1],e.status[1],"system",0,val(q.creation_session_id[i]),"Creation lease expired without reserving the entitlement.","expire-session:" & val(q.creation_session_id[i])); count++; }
        }
      }
      return {SUCCESS=true,success=true,EXPIRED_COUNT=count};
    </cfscript>
  </cffunction>

  <cffunction name="reserveTripEntitlement" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true"><cfargument name="entitlementId" type="numeric" required="true"><cfargument name="canonicalTripId" type="numeric" required="true">
    <cfscript>
      return failure(
        "CREATION_SESSION_REQUIRED",
        "Premium Trips may be reserved only through the explicit apply action for an active creation session."
      );
    </cfscript>
  </cffunction>

  <cffunction name="activateTripEntitlement" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true"><cfargument name="canonicalTripId" type="numeric" required="true"><cfargument name="manageTransaction" type="boolean" required="false" default="true">
    <cfscript>
      var returnValue={};
      if(arguments.manageTransaction) { transaction { returnValue=activateTripInternal(int(val(arguments.userId)),int(val(arguments.canonicalTripId))); } return returnValue; }
      return activateTripInternal(int(val(arguments.userId)),int(val(arguments.canonicalTripId)));
    </cfscript>
  </cffunction>

  <cffunction name="consumeTripEntitlement" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true"><cfargument name="canonicalTripId" type="numeric" required="true"><cfargument name="manageTransaction" type="boolean" required="false" default="true">
    <cfscript>
      var returnValue={};
      if(arguments.manageTransaction) { transaction { returnValue=consumeTripInternal(int(val(arguments.userId)),int(val(arguments.canonicalTripId))); } return returnValue; }
      return consumeTripInternal(int(val(arguments.userId)),int(val(arguments.canonicalTripId)));
    </cfscript>
  </cffunction>

  <cffunction name="releaseReservedTrip" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true"><cfargument name="canonicalTripId" type="numeric" required="true"><cfargument name="manageTransaction" type="boolean" required="false" default="true">
    <cfscript>
      var returnValue={};
      if(arguments.manageTransaction) { transaction { returnValue=releaseTripInternal(int(val(arguments.userId)),int(val(arguments.canonicalTripId))); } return returnValue; }
      return releaseTripInternal(int(val(arguments.userId)),int(val(arguments.canonicalTripId)));
    </cfscript>
  </cffunction>

  <cffunction name="handleCanonicalTripClosure" access="public" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true"><cfargument name="canonicalTripId" type="numeric" required="true"><cfargument name="manageTransaction" type="boolean" required="false" default="true">
    <cfscript>
      var access=getTripEntitlementForCanonicalTrip(arguments.userId,arguments.canonicalTripId);
      if(structIsEmpty(access)) return {SUCCESS=true,success=true,SKIPPED=true,REASON="NO_TRIP_ENTITLEMENT"};
      if(access.status EQ "ACTIVE") return consumeTripEntitlement(arguments.userId,arguments.canonicalTripId,arguments.manageTransaction);
      if(access.status EQ "RESERVED") return releaseReservedTrip(arguments.userId,arguments.canonicalTripId,arguments.manageTransaction);
      return {SUCCESS=true,success=true,SKIPPED=true,STATUS=access.status};
    </cfscript>
  </cffunction>

  <cffunction name="revokeUnusedEntitlement" access="public" returntype="struct" output="false">
    <cfargument name="entitlementId" type="numeric" required="true"><cfargument name="reason" type="string" required="true"><cfargument name="actorUserId" type="numeric" required="false" default="0"><cfargument name="actorType" type="string" required="false" default="system">
    <cftry>
    <cfscript>
      var eid=int(val(arguments.entitlementId)); var e=queryNew(""); var prior=""; var returnValue={};
      transaction { e=loadEntitlementForUpdate(eid); if(!e.recordCount) throw(type="PremiumTrip.NotFound",message="Premium Trip entitlement was not found."); prior=e.status[1]; if(prior EQ "REVOKED") returnValue=entitlementResponse(e,false,"Premium Trip is already revoked."); else { if(!listFind("AVAILABLE,RESERVED",prior)) throw(type="PremiumTrip.ReviewRequired",message="Active or consumed Premium Trips require administrative review."); if(prior EQ "RESERVED" AND hasOperationalStartProof(val(e.user_id[1]),val(e.canonical_trip_id[1]))) throw(type="PremiumTrip.ReviewRequired",message="Started Premium Trips cannot be automatically revoked."); writeEvent(e,"REVOKE",prior,"REVOKED",arguments.actorType,int(val(arguments.actorUserId)),0,left(trim(arguments.reason),500),"revoke:" & eid & ":" & hash(left(trim(arguments.reason),500),"SHA-256")); queryExecute("UPDATE member_premium_trip_entitlements SET status='REVOKED',canonical_trip_id=NULL,revoked_at_utc=UTC_TIMESTAMP(),revocation_reason=:reason,updated_at_utc=UTC_TIMESTAMP() WHERE premium_trip_entitlement_id=:id",{reason={value=left(trim(arguments.reason),500),cfsqltype="cf_sql_varchar"},id={value=eid,cfsqltype="cf_sql_bigint"}},{datasource=variables.datasource}); e=loadEntitlementForUpdate(eid); returnValue=entitlementResponse(e,true,"Unused Premium Trip revoked."); } }
      return returnValue;
    </cfscript><cfcatch type="PremiumTrip"><cfreturn failure(cfcatch.type,cfcatch.message)></cfcatch>
    </cftry>
  </cffunction>

  <cffunction name="restoreEntitlement" access="public" returntype="struct" output="false">
    <cfargument name="entitlementId" type="numeric" required="true"><cfargument name="reason" type="string" required="true"><cfargument name="actorUserId" type="numeric" required="true">
    <cftry>
    <cfscript>
      var eid=int(val(arguments.entitlementId)); var actor=int(val(arguments.actorUserId)); var e=queryNew(""); if(actor LTE 0 OR !len(trim(arguments.reason))) return failure("ADMIN_AUTHORITY_REQUIRED","Administrative actor and reason are required.");
      transaction { e=loadEntitlementForUpdate(eid); if(!e.recordCount OR e.status[1] NEQ "REVOKED") throw(type="PremiumTrip.InvalidTransition",message="Only a revoked Premium Trip may be restored."); queryExecute("UPDATE member_premium_trip_entitlements SET status='AVAILABLE',canonical_trip_id=NULL,revoked_at_utc=NULL,revocation_reason=NULL,restored_at_utc=UTC_TIMESTAMP(),review_required=0,review_reason=NULL,updated_at_utc=UTC_TIMESTAMP() WHERE premium_trip_entitlement_id=:id AND status='REVOKED'",{id={value=eid,cfsqltype="cf_sql_bigint"}},{datasource=variables.datasource}); e=loadEntitlementForUpdate(eid); writeEvent(e,"RESTORE","REVOKED","AVAILABLE","admin",actor,0,left(trim(arguments.reason),500),"restore:" & eid & ":" & actor & ":" & hash(arguments.reason,"SHA-256")); }
      return entitlementResponse(e,true,"Premium Trip restored.");
    </cfscript><cfcatch type="PremiumTrip"><cfreturn failure(cfcatch.type,cfcatch.message)></cfcatch>
    </cftry>
  </cffunction>

  <cffunction name="reconcilePaymentReversal" access="public" returntype="struct" output="false">
    <cfargument name="references" type="struct" required="true"><cfargument name="reason" type="string" required="true"><cfargument name="stripeEventId" type="string" required="true">
    <cftry>
    <cfscript>
      var refs=normalizeStripeReferences(arguments.references); var e=queryNew(""); var prior=""; var returnValue={};
      transaction {
        e=findEntitlementByStripeReferences(refs,true);
        if(!e.recordCount) throw(type="PremiumTrip.NotFound",message="No Premium Trip matched the payment reversal.");
        if(len(refs.chargeId) AND (isNull(e.stripe_charge_id[1]) OR !len(e.stripe_charge_id[1]))) {
          queryExecute("UPDATE member_premium_trip_entitlements SET stripe_charge_id=:chargeId,updated_at_utc=UTC_TIMESTAMP() WHERE premium_trip_entitlement_id=:id",{chargeId={value=refs.chargeId,cfsqltype="cf_sql_varchar"},id={value=val(e.premium_trip_entitlement_id[1]),cfsqltype="cf_sql_bigint"}},{datasource=variables.datasource});
          e=loadEntitlementForUpdate(val(e.premium_trip_entitlement_id[1]));
        }
        prior=e.status[1];
        if(prior EQ "REVOKED") {
          returnValue=entitlementResponse(e,false,"Premium Trip is already revoked after payment reversal.");
          returnValue.reviewRequired=false;
          returnValue.userId=val(e.user_id[1]);
        } else if(listFind("AVAILABLE,RESERVED",prior) AND (prior EQ "AVAILABLE" OR !hasOperationalStartProof(val(e.user_id[1]),val(e.canonical_trip_id[1])))) {
          writeEvent(e,"PAYMENT_REVERSAL_REVOKE",prior,"REVOKED","stripe",0,0,left(trim(arguments.reason),500),"reversal:" & arguments.stripeEventId);
          queryExecute("UPDATE member_premium_trip_entitlements SET status='REVOKED',canonical_trip_id=NULL,revoked_at_utc=UTC_TIMESTAMP(),revocation_reason=:reason,stripe_event_id=COALESCE(stripe_event_id,:eventId),updated_at_utc=UTC_TIMESTAMP() WHERE premium_trip_entitlement_id=:id AND status=:priorStatus",{reason={value=left(trim(arguments.reason),500),cfsqltype="cf_sql_varchar"},eventId={value=trim(arguments.stripeEventId),cfsqltype="cf_sql_varchar",null=!len(trim(arguments.stripeEventId))},id={value=val(e.premium_trip_entitlement_id[1]),cfsqltype="cf_sql_bigint"},priorStatus={value=prior,cfsqltype="cf_sql_varchar"}},{datasource=variables.datasource});
          e=loadEntitlementForUpdate(val(e.premium_trip_entitlement_id[1]));
          returnValue=entitlementResponse(e,true,"Unused Premium Trip revoked after payment reversal.");
          returnValue.reviewRequired=false;
          returnValue.userId=val(e.user_id[1]);
        } else {
          queryExecute("UPDATE member_premium_trip_entitlements SET review_required=1,review_reason=:reason,updated_at_utc=UTC_TIMESTAMP() WHERE premium_trip_entitlement_id=:id",{reason={value=left(trim(arguments.reason),500),cfsqltype="cf_sql_varchar"},id={value=val(e.premium_trip_entitlement_id[1]),cfsqltype="cf_sql_bigint"}},{datasource=variables.datasource});
          writeEvent(e,"PAYMENT_REVERSAL_REVIEW",prior,prior,"stripe",0,0,left(trim(arguments.reason),500),"review:" & arguments.stripeEventId);
          returnValue={SUCCESS=true,success=true,reviewRequired=true,entitlementId=val(e.premium_trip_entitlement_id[1]),status=prior,userId=val(e.user_id[1])};
        }
      }
      return returnValue;
    </cfscript>
    <cfcatch type="PremiumTrip"><cfreturn failure(cfcatch.type,cfcatch.message)></cfcatch>
    </cftry>
  </cffunction>

  <cffunction name="backfillIntroductoryTrips" access="public" returntype="struct" output="false">
    <cfargument name="dryRun" type="boolean" required="false" default="true"><cfargument name="batchSize" type="numeric" required="false" default="100"><cfargument name="afterUserId" type="numeric" required="false" default="0">
    <cfscript>
      var size=max(1,min(500,int(val(arguments.batchSize)))); var afterId=int(val(arguments.afterUserId)); var q=queryNew(""); var i=0; var created=0; var skipped=0; var item={}; var ids=[];
      q=queryExecute("SELECT u.userId FROM users u LEFT JOIN member_premium_trip_entitlements p ON p.user_id=u.userId AND p.grant_source='introductory' WHERE u.userId>:afterId AND p.premium_trip_entitlement_id IS NULL ORDER BY u.userId LIMIT " & size,{afterId={value=afterId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
      for(i=1;i<=q.recordCount;i++){ arrayAppend(ids,val(q.userId[i])); if(!arguments.dryRun){item=grantIntroductoryTrip(val(q.userId[i])); if(item.SUCCESS AND structKeyExists(item,"created") AND item.created) created++; else skipped++;}}
      return {SUCCESS=true,success=true,DRY_RUN=arguments.dryRun,BATCH_SIZE=size,CANDIDATE_COUNT=q.recordCount,CREATED_COUNT=created,SKIPPED_COUNT=skipped,USER_IDS=ids,NEXT_AFTER_USER_ID=q.recordCount?val(q.userId[q.recordCount]):afterId};
    </cfscript>
  </cffunction>

  <cffunction name="grantTrips" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true"><cfargument name="source" type="string" required="true"><cfargument name="reference" type="string" required="true"><cfargument name="quantity" type="numeric" required="true"><cfargument name="stripeReferences" type="struct" required="true"><cfargument name="actorType" type="string" required="true"><cfargument name="actorUserId" type="numeric" required="true"><cfargument name="promoCodeId" type="numeric" required="true"><cfargument name="adminGrantId" type="numeric" required="true"><cfargument name="reason" type="string" required="true">
    <cftry>
    <cfscript>
      var uid=int(val(arguments.userId)); var qty=int(val(arguments.quantity)); var i=0; var existing=queryNew(""); var insertResult={}; var row=queryNew(""); var rows=[]; var refs=normalizeStripeReferences(arguments.stripeReferences); var sourceValue=lCase(trim(arguments.source)); var createdCount=0; var grantEventKey="";
      if(!validUser(uid)) return failure("INVALID_USER","A valid member is required."); if(qty LT 1 OR qty GT 100) return failure("INVALID_QUANTITY","Trip grant quantity must be between 1 and 100."); if(!len(trim(arguments.reference))) return failure("GRANT_REFERENCE_REQUIRED","A durable grant reference is required.");
      transaction {
        for(i=1;i<=qty;i++){
          existing=queryExecute("SELECT * FROM member_premium_trip_entitlements WHERE grant_source=:source AND grant_reference=:reference AND grant_sequence=:sequence LIMIT 1 FOR UPDATE",{source={value=sourceValue,cfsqltype="cf_sql_varchar"},reference={value=trim(arguments.reference),cfsqltype="cf_sql_varchar"},sequence={value=i,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
          if(existing.recordCount){ if(val(existing.user_id[1]) NEQ uid) throw(type="PremiumTrip.ReferenceConflict",message="Grant reference belongs to another member."); arrayAppend(rows,queryRowToStruct(existing,1)); continue; }
          queryExecute("INSERT INTO member_premium_trip_entitlements (user_id,grant_source,grant_reference,grant_sequence,status,granted_at_utc,stripe_checkout_session_id,stripe_payment_intent_id,stripe_charge_id,stripe_price_id,stripe_event_id,promo_code_id,admin_grant_id,created_at_utc,updated_at_utc) VALUES (:userId,:source,:reference,:sequence,'AVAILABLE',UTC_TIMESTAMP(),:checkoutId,:paymentIntentId,:chargeId,:priceId,:eventId,:promoCodeId,:adminGrantId,UTC_TIMESTAMP(),UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE premium_trip_entitlement_id=LAST_INSERT_ID(premium_trip_entitlement_id)",{
            userId={value=uid,cfsqltype="cf_sql_integer"},source={value=sourceValue,cfsqltype="cf_sql_varchar"},reference={value=trim(arguments.reference),cfsqltype="cf_sql_varchar"},sequence={value=i,cfsqltype="cf_sql_integer"},
            checkoutId={value=refs.checkoutSessionId,cfsqltype="cf_sql_varchar",null=!len(refs.checkoutSessionId)},paymentIntentId={value=refs.paymentIntentId,cfsqltype="cf_sql_varchar",null=!len(refs.paymentIntentId)},chargeId={value=refs.chargeId,cfsqltype="cf_sql_varchar",null=!len(refs.chargeId)},priceId={value=refs.priceId,cfsqltype="cf_sql_varchar",null=!len(refs.priceId)},eventId={value=refs.eventId,cfsqltype="cf_sql_varchar",null=!len(refs.eventId)},promoCodeId={value=int(val(arguments.promoCodeId)),cfsqltype="cf_sql_bigint",null=int(val(arguments.promoCodeId)) LTE 0},adminGrantId={value=int(val(arguments.adminGrantId)),cfsqltype="cf_sql_bigint",null=int(val(arguments.adminGrantId)) LTE 0}
          },{datasource=variables.datasource,result="insertResult"}); row=loadEntitlementForUpdate(val(insertResult.generatedKey)); if(val(row.user_id[1]) NEQ uid) throw(type="PremiumTrip.ReferenceConflict",message="Grant identity belongs to another member."); grantEventKey="grant:" & sourceValue & ":" & trim(arguments.reference) & ":" & i; if(compareNoCase(row.grant_source[1],sourceValue) EQ 0 AND compare(row.grant_reference[1],trim(arguments.reference)) EQ 0 AND val(row.grant_sequence[1]) EQ i AND !hasEventKey(grantEventKey)){writeEvent(row,"GRANT","","AVAILABLE",arguments.actorType,int(val(arguments.actorUserId)),0,arguments.reason,grantEventKey); createdCount++;} arrayAppend(rows,queryRowToStruct(row,1));
        }
      }
      return {SUCCESS=true,success=true,created=(createdCount GT 0),createdCount=createdCount,grantCount=arrayLen(rows),entitlements=rows};
    </cfscript><cfcatch type="PremiumTrip"><cfreturn failure(cfcatch.type,cfcatch.message)></cfcatch>
    </cftry>
  </cffunction>

  <cffunction name="activateTripInternal" access="private" returntype="struct" output="false"><cfargument name="userId" type="numeric" required="true"><cfargument name="tripId" type="numeric" required="true"><cfscript>
    var e=loadTripEntitlementForUpdate(arguments.userId,arguments.tripId); if(!e.recordCount) return {SUCCESS=true,success=true,SKIPPED=true,REASON="NO_TRIP_ENTITLEMENT"}; if(e.status[1] EQ "ACTIVE") return entitlementResponse(e,false,"Premium Trip is already active."); if(e.status[1] NEQ "RESERVED") return failedTransition(e,"ACTIVATE","Only a Reserved Premium Trip may become Active."); if(!hasOperationalStartProof(arguments.userId,arguments.tripId)) return failedTransition(e,"ACTIVATE","Canonical operational start proof is required."); queryExecute("UPDATE member_premium_trip_entitlements SET status='ACTIVE',activated_at_utc=COALESCE(activated_at_utc,UTC_TIMESTAMP()),updated_at_utc=UTC_TIMESTAMP() WHERE premium_trip_entitlement_id=:id AND status='RESERVED'",{id={value=val(e.premium_trip_entitlement_id[1]),cfsqltype="cf_sql_bigint"}},{datasource=variables.datasource}); e=loadEntitlementForUpdate(val(e.premium_trip_entitlement_id[1])); writeEvent(e,"ACTIVATE","RESERVED","ACTIVE","system",arguments.userId,0,"Canonical operational trip start succeeded.","activate:" & val(e.premium_trip_entitlement_id[1])); return entitlementResponse(e,true,"Premium Trip activated.");
  </cfscript></cffunction>

  <cffunction name="consumeTripInternal" access="private" returntype="struct" output="false"><cfargument name="userId" type="numeric" required="true"><cfargument name="tripId" type="numeric" required="true"><cfscript>
    var e=loadTripEntitlementForUpdate(arguments.userId,arguments.tripId); var p=loadCanonicalTrip(arguments.userId,arguments.tripId,true); if(!e.recordCount) return {SUCCESS=true,success=true,SKIPPED=true,REASON="NO_TRIP_ENTITLEMENT"}; if(e.status[1] EQ "CONSUMED") return entitlementResponse(e,false,"Premium Trip is already consumed."); if(e.status[1] NEQ "ACTIVE") return failedTransition(e,"CONSUME","Only an Active Premium Trip may be consumed."); if(!p.recordCount OR isNull(p.closedAt[1]) OR !listFindNoCase("CLOSED,CANCELLED,CANCELED",trim(p.status[1]))) return failedTransition(e,"CONSUME","Canonical trip closure proof is required."); queryExecute("UPDATE member_premium_trip_entitlements SET status='CONSUMED',consumed_at_utc=COALESCE(consumed_at_utc,UTC_TIMESTAMP()),updated_at_utc=UTC_TIMESTAMP() WHERE premium_trip_entitlement_id=:id AND status='ACTIVE'",{id={value=val(e.premium_trip_entitlement_id[1]),cfsqltype="cf_sql_bigint"}},{datasource=variables.datasource}); e=loadEntitlementForUpdate(val(e.premium_trip_entitlement_id[1])); writeEvent(e,"CONSUME","ACTIVE","CONSUMED","system",arguments.userId,0,"Canonical trip closed.","consume:" & val(e.premium_trip_entitlement_id[1])); return entitlementResponse(e,true,"Premium Trip consumed.");
  </cfscript></cffunction>

  <cffunction name="releaseTripInternal" access="private" returntype="struct" output="false"><cfargument name="userId" type="numeric" required="true"><cfargument name="tripId" type="numeric" required="true"><cfscript>
    var e=loadTripEntitlementForUpdate(arguments.userId,arguments.tripId); if(!e.recordCount) return {SUCCESS=true,success=true,SKIPPED=true,REASON="NO_TRIP_ENTITLEMENT"}; if(e.status[1] NEQ "RESERVED") return failedTransition(e,"RELEASE","Only a Reserved Premium Trip may return to Available."); if(hasOperationalStartProof(arguments.userId,arguments.tripId)) return failedTransition(e,"RELEASE","A started Premium Trip cannot return to Available."); writeEvent(e,"RELEASE","RESERVED","AVAILABLE","system",arguments.userId,0,"Pre-start trip canceled or closed.","release:" & val(e.premium_trip_entitlement_id[1]) & ":" & arguments.tripId); queryExecute("UPDATE member_premium_trip_entitlements SET status='AVAILABLE',canonical_trip_id=NULL,reserved_at_utc=NULL,updated_at_utc=UTC_TIMESTAMP() WHERE premium_trip_entitlement_id=:id AND status='RESERVED'",{id={value=val(e.premium_trip_entitlement_id[1]),cfsqltype="cf_sql_bigint"}},{datasource=variables.datasource}); e=loadEntitlementForUpdate(val(e.premium_trip_entitlement_id[1])); return entitlementResponse(e,true,"Premium Trip returned to Available.");
  </cfscript></cffunction>

  <cffunction name="validateActiveCreationSession" access="private" returntype="void" output="false"><cfargument name="sessionRow" type="query" required="true"><cfargument name="userId" type="numeric" required="true"><cfscript>
    if(!arguments.sessionRow.recordCount) throw(type="PremiumTrip.SessionInvalid",message="Creation session is invalid."); if(val(arguments.sessionRow.user_id[1]) NEQ arguments.userId) throw(type="PremiumTrip.SessionOwnership",message="Creation session does not belong to this member."); if(arguments.sessionRow.status[1] EQ "EXPIRED") throw(type="PremiumTrip.SessionExpired",message="Creation session has expired."); if(arguments.sessionRow.status[1] NEQ "ACTIVE") throw(type="PremiumTrip.SessionInactive",message="Creation session is not active.");
  </cfscript></cffunction>

  <cffunction name="loadEligibleDraftForUpdate" access="private" returntype="query" output="false"><cfargument name="userId" type="numeric" required="true"><cfargument name="tripId" type="numeric" required="true"><cfreturn queryExecute("SELECT floatPlanId,userId,status,activatedAt,initialSentAt,checkedInAt,closedAt,route_instance_id FROM floatplans WHERE floatPlanId=:tripId AND userId=:userId AND UPPER(TRIM(status))='DRAFT' AND activatedAt IS NULL AND initialSentAt IS NULL AND checkedInAt IS NULL AND closedAt IS NULL AND route_instance_id IS NOT NULL LIMIT 1 FOR UPDATE",{tripId={value=arguments.tripId,cfsqltype="cf_sql_integer"},userId={value=arguments.userId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource})></cffunction>
  <cffunction name="loadCanonicalTrip" access="private" returntype="query" output="false"><cfargument name="userId" type="numeric" required="true"><cfargument name="tripId" type="numeric" required="true"><cfargument name="forUpdate" type="boolean" required="false" default="false"><cfscript>
    return queryExecute("SELECT fp.floatPlanId,fp.userId,fp.status,fp.activatedAt,fp.closedAt,fp.route_instance_id,ri.started_at,ri.completed_at,(SELECT COUNT(*) FROM route_instance_leg_progress rp WHERE rp.route_instance_id=fp.route_instance_id AND rp.user_id=fp.userId AND (rp.leg_started_at IS NOT NULL OR rp.completed_at IS NOT NULL OR UPPER(TRIM(COALESCE(rp.status,''))) IN ('STARTED','IN_PROGRESS','COMPLETED'))) AS progress_started_count FROM floatplans fp LEFT JOIN route_instances ri ON ri.id=fp.route_instance_id AND ri.user_id=fp.userId WHERE fp.floatPlanId=:tripId AND fp.userId=:userId LIMIT 1" & (arguments.forUpdate?" FOR UPDATE":""),{tripId={value=arguments.tripId,cfsqltype="cf_sql_integer"},userId={value=arguments.userId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
  </cfscript></cffunction>
  <cffunction name="hasOperationalStartProof" access="private" returntype="boolean" output="false"><cfargument name="userId" type="numeric" required="true"><cfargument name="tripId" type="numeric" required="true"><cfscript>var p=loadCanonicalTrip(arguments.userId,arguments.tripId,false); return p.recordCount AND ((!isNull(p.started_at[1]) AND isDate(p.started_at[1])) OR val(p.progress_started_count[1]) GT 0);</cfscript></cffunction>
  <cffunction name="loadEntitlementForUpdate" access="private" returntype="query" output="false"><cfargument name="id" type="numeric" required="true"><cfreturn queryExecute("SELECT * FROM member_premium_trip_entitlements WHERE premium_trip_entitlement_id=:id LIMIT 1 FOR UPDATE",{id={value=int(val(arguments.id)),cfsqltype="cf_sql_bigint"}},{datasource=variables.datasource})></cffunction>
  <cffunction name="loadTripEntitlementForUpdate" access="private" returntype="query" output="false"><cfargument name="userId" type="numeric" required="true"><cfargument name="tripId" type="numeric" required="true"><cfreturn queryExecute("SELECT * FROM member_premium_trip_entitlements WHERE user_id=:userId AND canonical_trip_id=:tripId LIMIT 1 FOR UPDATE",{userId={value=arguments.userId,cfsqltype="cf_sql_integer"},tripId={value=arguments.tripId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource})></cffunction>
  <cffunction name="loadCreationSessionForUpdate" access="private" returntype="query" output="false"><cfargument name="id" type="numeric" required="true"><cfreturn queryExecute("SELECT *,CASE WHEN action_claim_hash IS NOT NULL AND action_claim_expires_at_utc>UTC_TIMESTAMP() THEN 1 ELSE 0 END AS action_claim_is_active FROM premium_trip_creation_sessions WHERE creation_session_id=:id LIMIT 1 FOR UPDATE",{id={value=int(val(arguments.id)),cfsqltype="cf_sql_bigint"}},{datasource=variables.datasource})></cffunction>
  <cffunction name="loadCreationSessionByTokenForUpdate" access="private" returntype="query" output="false"><cfargument name="rawToken" type="string" required="true"><cfreturn queryExecute("SELECT *,CASE WHEN action_claim_hash IS NOT NULL AND action_claim_expires_at_utc>UTC_TIMESTAMP() THEN 1 ELSE 0 END AS action_claim_is_active FROM premium_trip_creation_sessions WHERE token_hash=:tokenHash LIMIT 1 FOR UPDATE",{tokenHash={value=hashToken(arguments.rawToken),cfsqltype="cf_sql_varchar"}},{datasource=variables.datasource})></cffunction>
  <cffunction name="refreshCreationSession" access="private" returntype="void" output="false"><cfargument name="id" type="numeric" required="true"><cfset queryExecute("UPDATE premium_trip_creation_sessions SET last_activity_at_utc=UTC_TIMESTAMP(),expires_at_utc=DATE_ADD(UTC_TIMESTAMP(),INTERVAL 60 MINUTE),lock_version=lock_version+1 WHERE creation_session_id=:id AND status='ACTIVE'",{id={value=int(val(arguments.id)),cfsqltype="cf_sql_bigint"}},{datasource=variables.datasource})></cffunction>

  <cffunction name="findEntitlementByStripeReferences" access="private" returntype="query" output="false"><cfargument name="refs" type="struct" required="true"><cfargument name="forUpdate" type="boolean" required="false" default="false"><cfscript>
    var where=[]; var params={}; if(len(arguments.refs.checkoutSessionId)){arrayAppend(where,"stripe_checkout_session_id=:checkoutId");params.checkoutId={value=arguments.refs.checkoutSessionId,cfsqltype="cf_sql_varchar"};} if(len(arguments.refs.paymentIntentId)){arrayAppend(where,"stripe_payment_intent_id=:paymentIntentId");params.paymentIntentId={value=arguments.refs.paymentIntentId,cfsqltype="cf_sql_varchar"};} if(len(arguments.refs.chargeId)){arrayAppend(where,"stripe_charge_id=:chargeId");params.chargeId={value=arguments.refs.chargeId,cfsqltype="cf_sql_varchar"};} if(!arrayLen(where)) return queryNew(""); return queryExecute("SELECT * FROM member_premium_trip_entitlements WHERE " & arrayToList(where," OR ") & " ORDER BY premium_trip_entitlement_id DESC LIMIT 1" & (arguments.forUpdate?" FOR UPDATE":""),params,{datasource=variables.datasource});
  </cfscript></cffunction>

  <cffunction name="hasEventKey" access="private" returntype="boolean" output="false"><cfargument name="idempotencyKey" type="string" required="true"><cfscript>
    var q=queryExecute("SELECT premium_trip_event_id FROM premium_trip_entitlement_events WHERE idempotency_key=:idempotencyKey LIMIT 1",{idempotencyKey={value=left(trim(arguments.idempotencyKey),255),cfsqltype="cf_sql_varchar"}},{datasource=variables.datasource}); return q.recordCount GT 0;
  </cfscript></cffunction>

  <cffunction name="writeEvent" access="private" returntype="void" output="false"><cfargument name="entitlement" type="query" required="true"><cfargument name="action" type="string" required="true"><cfargument name="previousStatus" type="string" required="true"><cfargument name="newStatus" type="string" required="true"><cfargument name="actorType" type="string" required="true"><cfargument name="actorUserId" type="numeric" required="true"><cfargument name="creationSessionId" type="numeric" required="true"><cfargument name="reason" type="string" required="true"><cfargument name="idempotencyKey" type="string" required="true"><cfscript>
    if(!arguments.entitlement.recordCount) return; queryExecute("INSERT INTO premium_trip_entitlement_events (premium_trip_entitlement_id,creation_session_id,actor_type,actor_user_id,user_id,action,canonical_trip_id,previous_status,new_status,source,reason,stripe_event_id,promo_code_id,idempotency_key,created_at_utc) VALUES (:entitlementId,:sessionId,:actorType,:actorUserId,:userId,:action,:tripId,:previousStatus,:newStatus,:source,:reason,:stripeEventId,:promoCodeId,:idempotencyKey,UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE premium_trip_event_id=premium_trip_event_id",{entitlementId={value=val(arguments.entitlement.premium_trip_entitlement_id[1]),cfsqltype="cf_sql_bigint"},sessionId={value=int(val(arguments.creationSessionId)),cfsqltype="cf_sql_bigint",null=int(val(arguments.creationSessionId)) LTE 0},actorType={value=lCase(trim(arguments.actorType)),cfsqltype="cf_sql_varchar"},actorUserId={value=int(val(arguments.actorUserId)),cfsqltype="cf_sql_integer",null=int(val(arguments.actorUserId)) LTE 0},userId={value=val(arguments.entitlement.user_id[1]),cfsqltype="cf_sql_integer"},action={value=uCase(trim(arguments.action)),cfsqltype="cf_sql_varchar"},tripId={value=isNull(arguments.entitlement.canonical_trip_id[1])?0:val(arguments.entitlement.canonical_trip_id[1]),cfsqltype="cf_sql_integer",null=isNull(arguments.entitlement.canonical_trip_id[1]) OR val(arguments.entitlement.canonical_trip_id[1]) LTE 0},previousStatus={value=trim(arguments.previousStatus),cfsqltype="cf_sql_varchar",null=!len(trim(arguments.previousStatus))},newStatus={value=trim(arguments.newStatus),cfsqltype="cf_sql_varchar",null=!len(trim(arguments.newStatus))},source={value=arguments.entitlement.grant_source[1],cfsqltype="cf_sql_varchar"},reason={value=left(trim(arguments.reason),500),cfsqltype="cf_sql_varchar",null=!len(trim(arguments.reason))},stripeEventId={value=isNull(arguments.entitlement.stripe_event_id[1])?"":arguments.entitlement.stripe_event_id[1],cfsqltype="cf_sql_varchar",null=isNull(arguments.entitlement.stripe_event_id[1]) OR !len(arguments.entitlement.stripe_event_id[1])},promoCodeId={value=isNull(arguments.entitlement.promo_code_id[1])?0:val(arguments.entitlement.promo_code_id[1]),cfsqltype="cf_sql_bigint",null=isNull(arguments.entitlement.promo_code_id[1]) OR val(arguments.entitlement.promo_code_id[1]) LTE 0},idempotencyKey={value=left(trim(arguments.idempotencyKey),255),cfsqltype="cf_sql_varchar",null=!len(trim(arguments.idempotencyKey))}},{datasource=variables.datasource});
  </cfscript></cffunction>

  <cffunction name="failedTransition" access="private" returntype="struct" output="false"><cfargument name="entitlement" type="query" required="true"><cfargument name="action" type="string" required="true"><cfargument name="message" type="string" required="true"><cfscript>writeEvent(arguments.entitlement,"FAILED_" & arguments.action,arguments.entitlement.status[1],arguments.entitlement.status[1],"system",0,0,arguments.message,"failed:" & lCase(arguments.action) & ":" & val(arguments.entitlement.premium_trip_entitlement_id[1]) & ":" & hash(arguments.message,"SHA-256")); return failure("INVALID_STATE_TRANSITION",arguments.message);</cfscript></cffunction>
  <cffunction name="validUser" access="private" returntype="boolean" output="false"><cfargument name="userId" type="numeric" required="true"><cfscript>var q=queryExecute("SELECT userId FROM users WHERE userId=:userId LIMIT 1",{userId={value=int(val(arguments.userId)),cfsqltype="cf_sql_integer"}},{datasource=variables.datasource}); return q.recordCount GT 0;</cfscript></cffunction>
  <cffunction name="createOpaqueToken" access="private" returntype="string" output="false"><cfscript>return lCase(hash(createUUID() & ":" & createUUID() & ":" & generateSecretKey("AES"),"SHA-256"));</cfscript></cffunction>
  <cffunction name="hashToken" access="private" returntype="string" output="false"><cfargument name="rawToken" type="string" required="true"><cfreturn lCase(hash(trim(arguments.rawToken),"SHA-256"))></cffunction>
  <cffunction name="normalizeStripeReferences" access="private" returntype="struct" output="false"><cfargument name="refs" type="struct" required="true"><cfscript>var out={checkoutSessionId="",paymentIntentId="",chargeId="",priceId="",eventId=""}; var map={checkoutSessionId="stripeCheckoutSessionId",paymentIntentId="stripePaymentIntentId",chargeId="stripeChargeId",priceId="stripePriceId",eventId="stripeEventId"}; var k=""; for(k in map){if(structKeyExists(arguments.refs,k))out[k]=trim(toString(arguments.refs[k]));else if(structKeyExists(arguments.refs,map[k]))out[k]=trim(toString(arguments.refs[map[k]]));} return out;</cfscript></cffunction>
  <cffunction name="queryToArray" access="private" returntype="array" output="false"><cfargument name="q" type="query" required="true"><cfscript>var out=[];var i=0;for(i=1;i<=arguments.q.recordCount;i++)arrayAppend(out,queryRowToStruct(arguments.q,i));return out;</cfscript></cffunction>
  <cffunction name="queryRowToStruct" access="private" returntype="struct" output="false"><cfargument name="q" type="query" required="true"><cfargument name="row" type="numeric" required="true"><cfscript>var out={};var c="";for(c in listToArray(arguments.q.columnList)){out[c]=isNull(arguments.q[c][arguments.row])?"":arguments.q[c][arguments.row];}return out;</cfscript></cffunction>
  <cffunction name="entitlementResponse" access="private" returntype="struct" output="false"><cfargument name="q" type="query" required="true"><cfargument name="created" type="boolean" required="true"><cfargument name="message" type="string" required="true"><cfscript>var row=arguments.q.recordCount?queryRowToStruct(arguments.q,1):{};return {SUCCESS=true,success=true,created=arguments.created,MESSAGE=arguments.message,entitlement=row,entitlementId=structKeyExists(row,"PREMIUM_TRIP_ENTITLEMENT_ID")?val(row.PREMIUM_TRIP_ENTITLEMENT_ID):0,status=structKeyExists(row,"STATUS")?row.STATUS:""};</cfscript></cffunction>
  <cffunction name="creationSessionResponse" access="private" returntype="struct" output="false"><cfargument name="q" type="query" required="true"><cfargument name="rawToken" type="string" required="true"><cfargument name="message" type="string" required="true"><cfscript>var row=arguments.q.recordCount?queryRowToStruct(arguments.q,1):{};if(structKeyExists(row,"TOKEN_HASH"))structDelete(row,"TOKEN_HASH");return {SUCCESS=true,success=true,MESSAGE=arguments.message,creationSession=row,creationSessionToken=arguments.rawToken,expiresInMinutes=variables.creationLeaseMinutes};</cfscript></cffunction>
  <cffunction name="failure" access="private" returntype="struct" output="false"><cfargument name="code" type="string" required="true"><cfargument name="message" type="string" required="true"><cfreturn {SUCCESS=false,success=false,ERROR=uCase(trim(arguments.code)),errorCode=uCase(trim(arguments.code)),MESSAGE=arguments.message,message=arguments.message}></cffunction>

</cfcomponent>
