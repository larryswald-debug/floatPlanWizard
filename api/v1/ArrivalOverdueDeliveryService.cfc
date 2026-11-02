component output="false" hint="Initial final-arrival notices only. All public methods are internal application calls." {
    public any function init(string ds="fpw", any captureTransport="", string recipientSecret="") {
        variables.ds=arguments.ds;
        variables.capture=arguments.captureTransport;
        variables.captureMode=isObject(variables.capture);
        variables.observer=createObject("component","fpw.api.v1.ArrivalOverdueService").init(ds);
        variables.mail=createObject("component","fpw.api.v1.ArrivalOverdueMailService").init(ds,recipientSecret);
        variables.gate=createObject("component","fpw.api.v1.ArrivalHandoffGate");
        return this;
    }

    private any function sql(required string statement, struct binds={}) {
        return queryExecute(statement,binds,{datasource=variables.ds});
    }

    private boolean function installed() {
        return sql("SELECT COUNT(*) AS n FROM information_schema.tables WHERE table_schema=DATABASE()
            AND table_name IN ('fpw_arrival_dispatch_control','fpw_arrival_notices','fpw_arrival_deliveries','fpw_arrival_attempts')").n[1]==4;
    }

    private string function clock(string asOfUtc="") {
        if (!len(asOfUtc)) return sql("SELECT DATE_FORMAT(UTC_TIMESTAMP(6),'%Y-%m-%d %H:%i:%s.%f') AS v").v[1];
        if (!variables.captureMode || !reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]{1,6})?$",asOfUtc))
            throw(type="FPW.ArrivalClock",message="Only a capture transport can use a controlled UTC clock.");
        return sql("SELECT DATE_FORMAT(CAST(:t AS DATETIME(6)),'%Y-%m-%d %H:%i:%s.%f') AS v",{t=asOfUtc}).v[1];
    }

    private boolean function liveTransportEnabled() {
        if (variables.captureMode || !listFindNoCase("production,prod",application.env ?: "")) return false;
        var flag=createObject("java","java.lang.System").getenv("FPW_ARRIVAL_EMAIL_ENABLED");
        return !isNull(flag) && compare(flag,"true")==0;
    }

    // Global OFF is never overridden for real mail. CAPTURE requires an injected
    // in-process sink, development environment AND an explicitly selected plan.
    private struct function permission(required numeric planId) {
        var out={enabled=false,generation=0,scopeGeneration=1,cutoff=""};
        var globalRow=sql("SELECT mode,generation,DATE_FORMAT(GREATEST(activated_at_utc,updated_at_utc),'%Y-%m-%d %H:%i:%s.%f') AS cutoff
            FROM fpw_arrival_dispatch_control WHERE plan_id=0 LOCK IN SHARE MODE");
        if (!globalRow.recordCount) return out;
        out.generation=val(globalRow.generation[1]);
        var scope=sql("SELECT mode,generation,DATE_FORMAT(GREATEST(activated_at_utc,updated_at_utc),'%Y-%m-%d %H:%i:%s.%f') AS cutoff
            FROM fpw_arrival_dispatch_control WHERE plan_id=:p LOCK IN SHARE MODE",{p=planId});
        if (scope.recordCount) out.scopeGeneration=val(scope.generation[1]);
        if (variables.captureMode) {
            out.enabled=listFindNoCase("dev,development,local,test",application.env ?: "") && scope.recordCount
                && scope.mode[1]=="CAPTURE" && len(scope.cutoff[1] ?: "");
            if (out.enabled) out.cutoff=scope.cutoff[1];
            return out;
        }
        if (!liveTransportEnabled() || !listFind("ALLOWLIST,LIVE",globalRow.mode[1]) || !len(globalRow.cutoff[1] ?: "")) return out;
        if ((!scope.recordCount && globalRow.mode[1]=="ALLOWLIST") || (scope.recordCount && scope.mode[1]!="ALLOWLIST")) return out;
        var observation=sql("SELECT mode FROM fpw_arrival_rollout WHERE id=1 LOCK IN SHARE MODE");
        out.enabled=observation.recordCount && observation.mode[1]=="OBSERVE";
        out.cutoff=globalRow.cutoff[1];
        if (scope.recordCount && compare(scope.cutoff[1],out.cutoff)>0) out.cutoff=scope.cutoff[1];
        return out;
    }

    private string function ineligibleReason(required struct context,required struct policy,required string t) {
        if (!policy.enabled) return "DISPATCH_DISABLED";
        if (!context.eligible) return context.reason;
        if (context.historicalOnly || compare(context.deadlineUtc,policy.cutoff)<=0) return "HISTORICAL_CUTOFF";
        if (compare(t,context.deadlineUtc)<0) return "NOT_DUE";
        return "";
    }

    // Persist slot zero once, including an auditable no-valid-recipients outcome.
    // Mail handoff never happens in this transaction.
    public struct function evaluatePlan(required numeric planId,string asOfUtc="") {
        var out={state="DISABLED",created=false,noticeId=0,recipientCount=0};
        if (!installed()) return out;
        var t=clock(asOfUtc);
        transaction {
            var ctx=variables.observer.lockedDeliveryContext(planId);
            var policy=permission(planId);
            var reason=ineligibleReason(ctx,policy,t);
            if (len(reason)) {
                out.state=reason;
                return out;
            }
            var old=sql("SELECT id,state,recipient_count FROM fpw_arrival_notices
                WHERE revision_id=:r AND slot_no=0 FOR UPDATE",{r=ctx.revisionId});
            if (old.recordCount) {
                out.noticeId=val(old.id[1]); out.state=old.state[1]; out.recipientCount=val(old.recipient_count[1]);
                return out;
            }
            var recipients=variables.mail.selectedRecipients(planId);
            out.recipientCount=arrayLen(recipients.valid);
            out.state=out.recipientCount ? "READY" : "NO_RECIPIENTS";
            var issue=(recipients.invalidCount>0 ? "INVALID_SELECTION" : (recipients.missingCount>0 ? "MISSING_ADDRESS" : ""));
            if (recipients.invalidCount>0 && recipients.missingCount>0) issue="MISSING_AND_INVALID";
            if (!out.recipientCount && !len(issue)) issue="NO_SELECTION";
            sql("INSERT INTO fpw_arrival_notices(revision_id,slot_no,plan_id,state,reason,recipient_count,invalid_count,created_at_utc)
                VALUES (:r,0,:p,:state,NULLIF(:issue,''),:n,:bad,:t)",
                {r=ctx.revisionId,p=planId,state=out.state,issue=issue,n=out.recipientCount,bad=recipients.invalidCount+recipients.missingCount,t=t});
            out.noticeId=val(sql("SELECT LAST_INSERT_ID() AS id").id[1]);
            for (var recipient in recipients.valid) {
                sql("INSERT INTO fpw_arrival_deliveries(notice_id,recipient_key,state,attempt_count,generation,scope_generation,
                    next_attempt_utc,created_at_utc,updated_at_utc) VALUES (:n,:k,'PENDING',0,:gen,:sg,:t,:t,:t)",
                    {n=out.noticeId,k=recipient.recipientKey,gen=policy.generation,sg=policy.scopeGeneration,t=t});
            }
            out.created=true;
        }
        return out;
    }

    private query function delivery(required numeric id,boolean forUpdate=false) {
        return sql("SELECT d.id,n.plan_id,n.revision_id,d.recipient_key,d.state,d.claim_token,d.attempt_count,
                d.generation,d.scope_generation,DATE_FORMAT(d.next_attempt_utc,'%Y-%m-%d %H:%i:%s.%f') AS next_at,
                DATE_FORMAT(d.lease_until_utc,'%Y-%m-%d %H:%i:%s.%f') AS lease_at
            FROM fpw_arrival_deliveries d JOIN fpw_arrival_notices n ON n.id=d.notice_id WHERE d.id=:id"
            & (forUpdate ? " FOR UPDATE" : ""),{id=id});
    }

    private boolean function sameGeneration(required query row,required struct policy) {
        return row.generation[1]==policy.generation && row.scope_generation[1]==policy.scopeGeneration;
    }

    private struct function suppress(required numeric id,required string reason,required string t) {
        sql("UPDATE fpw_arrival_deliveries SET state='SUPPRESSED',reason=:reason,claim_token=NULL,
            next_attempt_utc=NULL,lease_until_utc=NULL,updated_at_utc=:t WHERE id=:id
            AND state IN ('PENDING','CLAIMED','FAILED_RETRYABLE')",{id=id,reason=reason,t=t});
        return {state="SUPPRESSED",reason=reason};
    }

    public struct function claimDelivery(required numeric deliveryId,string asOfUtc="") {
        var t=clock(asOfUtc);
        transaction {
            var row=delivery(deliveryId,true);
            if (!row.recordCount) return {state="NOT_FOUND"};
            var policy=permission(row.plan_id[1]);
            if (!policy.enabled) return {state="DISABLED"};
            var state=row.state[1];
            if (state=="SUBMITTING") {
                if (compare(row.lease_at[1],t)<=0) {
                    // A delayed but still fenced worker owns its result.
                    if (!variables.gate.isFree(row.plan_id[1],variables.ds)) return {state="BUSY"};
                    // Handoff might have succeeded before the worker disappeared.
                    sql("UPDATE fpw_arrival_attempts SET status='UNKNOWN',reason='HANDOFF_UNCONFIRMED',finished_at_utc=:t
                        WHERE delivery_id=:id AND attempt_no=:n AND status='SUBMITTING'",{id=deliveryId,n=row.attempt_count[1],t=t});
                    sql("UPDATE fpw_arrival_deliveries SET state='UNKNOWN',reason='HANDOFF_UNCONFIRMED',next_attempt_utc=NULL,
                        lease_until_utc=NULL,claim_token=NULL,updated_at_utc=:t WHERE id=:id",{id=deliveryId,t=t});
                    return {state="UNKNOWN"};
                }
                return {state=state};
            }
            if (state=="CLAIMED") {
                if (compare(row.lease_at[1],t)>0) return {state="BUSY"};
            } else if (!listFind("PENDING,FAILED_RETRYABLE",state) || compare(row.next_at[1] ?: "",t)>0) {
                return {state=state};
            }
            if (!sameGeneration(row,policy)) return suppress(deliveryId,"GENERATION_CHANGED",t);
            var token=createUUID();
            sql("UPDATE fpw_arrival_deliveries SET state='CLAIMED',claim_token=:token,lease_until_utc=TIMESTAMPADD(SECOND,90,:t),
                updated_at_utc=:t WHERE id=:id",{token=token,t=t,id=deliveryId});
            return {state="CLAIMED",token=token};
        }
    }

    // The plan and watch are locked before the outbox. The dedicated advisory lock
    // outlives this short transaction and is held only until transport returns.
    private struct function prepareHandoff(required numeric id,required string token,required string t,required struct holder) {
        var found=delivery(id);
        if (!found.recordCount) return {state="NOT_FOUND"};
        transaction {
            var ctx=variables.observer.lockedDeliveryContext(found.plan_id[1]);
            var row=delivery(id,true);
            if (!row.recordCount || row.state[1]!="CLAIMED" || compare(row.claim_token[1] ?: "",token)!=0
                || compare(row.lease_at[1],t)<=0) return {state="STALE_CLAIM"};
            var policy=permission(row.plan_id[1]);
            var reason=ineligibleReason(ctx,policy,t);
            if (len(reason)) return suppress(id,reason,t);
            if (!sameGeneration(row,policy)) return suppress(id,"GENERATION_CHANGED",t);
            if (ctx.revisionId!=row.revision_id[1]) return suppress(id,"SUPERSEDED",t);
            var address=variables.mail.resolveRecipient(row.plan_id[1],row.recipient_key[1]);
            if (!len(address)) return suppress(id,"RECIPIENT_CHANGED",t);
            var message=variables.mail.buildNotice(row.plan_id[1],ctx.deadlineUtc,ctx.zone,t);
            holder.gate=variables.gate.acquire(row.plan_id[1],variables.ds);
            var n=val(row.attempt_count[1])+1;
            sql("INSERT INTO fpw_arrival_attempts(delivery_id,attempt_no,status,started_at_utc)
                VALUES (:id,:n,'SUBMITTING',:t)",{id=id,n=n,t=t});
            sql("UPDATE fpw_arrival_deliveries SET state='SUBMITTING',attempt_count=:n,next_attempt_utc=NULL,
                lease_until_utc=TIMESTAMPADD(SECOND,90,:t),updated_at_utc=:t WHERE id=:id",{n=n,t=t,id=id});
            return {state="SUBMITTING",attempt=n,address=address,message=message};
        }
    }

    private struct function finishHandoff(required numeric id,required string token,required numeric attempt,
            required struct transportResult,required string t) {
        var status=uCase(transportResult.status ?: "UNKNOWN");
        if (!listFind("SUBMITTED,FAILED_RETRYABLE,FAILED_PERMANENT,UNKNOWN",status)) status="UNKNOWN";
        var reason=transportResult.reason ?: "";
        // Persist only our known, non-identifying outcome codes.
        var safeReasons="TRANSPORT_ACCEPTED,TRANSPORT_SUBMITTED,TRANSPORT_UNAVAILABLE,TRANSPORT_CONNECTION_UNAVAILABLE,"
            & "ADDRESS_REJECTED,TRANSPORT_REJECTED,TEMPORARY_SMTP_REJECTION,PERMANENT_SMTP_REJECTION,HANDOFF_UNCONFIRMED,"
            & "TRANSPORT_OUTCOME_UNKNOWN,INVALID_RECIPIENT,INVALID_MESSAGE,LIVE_TRANSPORT_DISABLED";
        if (!listFind(safeReasons,reason)) {
            reason=(status=="SUBMITTED" ? "TRANSPORT_ACCEPTED" : (status=="UNKNOWN" ? "HANDOFF_UNCONFIRMED" : "TRANSPORT_REJECTED"));
        }
        var delayMinutes=0;
        var attemptStatus=status;
        if (status=="FAILED_RETRYABLE") {
            if (attempt>=4) {
                status="FAILED_PERMANENT";
                reason="RETRIES_EXHAUSTED";
            } else {
                var delays=[5,15,30];
                delayMinutes=delays[attempt];
            }
        }
        transaction {
            // Only lock this recipient. A different recipient's dispatcher may
            // hold the notice/plan locks while it waits its turn at the gate.
            var row=sql("SELECT state,claim_token FROM fpw_arrival_deliveries WHERE id=:id FOR UPDATE",{id=id});
            if (!row.recordCount || row.state[1]!="SUBMITTING" || compare(row.claim_token[1] ?: "",token)!=0)
                return {state="STALE_RESULT"};
            sql("UPDATE fpw_arrival_attempts SET status=:s,reason=:reason,finished_at_utc=:t WHERE delivery_id=:id AND attempt_no=:n",
                {s=attemptStatus,reason=reason,t=t,id=id,n=attempt});
            sql("UPDATE fpw_arrival_deliveries SET state=:s,reason=:reason,claim_token=NULL,lease_until_utc=NULL,
                next_attempt_utc=CASE WHEN :delay>0 THEN TIMESTAMPADD(MINUTE,:delay,:t) ELSE NULL END,
                submitted_at_utc=CASE WHEN :s='SUBMITTED' THEN :t ELSE NULL END,updated_at_utc=:t WHERE id=:id",
                {id=id,s=status,reason=reason,t=t,delay=delayMinutes});
        }
        return {state=status,reason=reason,attempt=attempt};
    }

    public struct function submitClaim(required numeric deliveryId,required string token,string asOfUtc="") {
        var t=clock(asOfUtc);
        var holder={};
        try {
            var prepared=prepareHandoff(deliveryId,token,t,holder);
            if (prepared.state!="SUBMITTING") return prepared;
            try {
                var transport=variables.captureMode ? variables.capture : variables.mail;
                var sent=transport.submit(prepared.address,prepared.message);
            } catch (any ignoredTransportError) {
                var sent={status="UNKNOWN",reason="HANDOFF_UNCONFIRMED"};
            }
            // Make a failed attempt visible to a waiting lifecycle writer so it
            // can suppress the retry before committing closure or supersession.
            return finishHandoff(deliveryId,token,prepared.attempt,sent,clock(asOfUtc));
        } finally {
            if (structKeyExists(holder,"gate")) variables.gate.release(holder.gate);
        }
    }

    public struct function dispatchOne(required numeric deliveryId,string asOfUtc="") {
        var claim=claimDelivery(deliveryId,asOfUtc);
        if (!structKeyExists(claim,"token")) return claim;
        return submitClaim(deliveryId,claim.token,asOfUtc);
    }

    private query function dueDeliveries(required numeric maxRows,required string t,numeric planId=0) {
        var binds={t=t};
        var scope="";
        if (planId>0) {scope=" AND n.plan_id=:p";binds.p=planId;}
        else {
            scope=" AND EXISTS (SELECT 1 FROM fpw_arrival_dispatch_control g
                LEFT JOIN fpw_arrival_dispatch_control c ON c.plan_id=n.plan_id
                WHERE g.plan_id=0 AND ((g.mode='LIVE' AND c.plan_id IS NULL)
                    OR (g.mode IN ('LIVE','ALLOWLIST') AND c.mode='ALLOWLIST')))";
        }
        return sql("SELECT d.id FROM fpw_arrival_deliveries d JOIN fpw_arrival_notices n ON n.id=d.notice_id
            WHERE ((d.state IN ('PENDING','FAILED_RETRYABLE') AND d.next_attempt_utc<=:t)
            OR (d.state IN ('CLAIMED','SUBMITTING') AND d.lease_until_utc<=:t))" & scope
            & " ORDER BY COALESCE(d.next_attempt_utc,d.lease_until_utc),d.id LIMIT " & int(maxRows),binds);
    }

    public struct function dispatchPlan(required numeric planId,string asOfUtc="") {
        var t=clock(asOfUtc);
        var outcomes=[];
        for (var row in dueDeliveries(500,t,planId)) arrayAppend(outcomes,dispatchOne(row.id,asOfUtc));
        return {results=outcomes,processed=arrayLen(outcomes)};
    }

    // Called in the original writer transaction, with the operational plan locked.
    // Holding that row prevents a new mail permit until commit. Await any prior
    // handoff, then suppress every unsubmitted delivery of the obsolete revision.
    public void function suppressRevision(required numeric planId,required numeric revisionNo,required string reason) {
        if (!installed() || revisionNo<=0) return;
        // With neither global nor per-plan activation there cannot be a handoff.
        // Use a current locking read: a writer's earlier snapshot may be stale.
        var armed=sql("SELECT activated_at_utc IS NOT NULL AS ever_active FROM fpw_arrival_dispatch_control
            WHERE plan_id IN (0,:p) LOCK IN SHARE MODE",{p=planId});
        var everActive=false;
        for (var entry in armed) if (entry.ever_active) everActive=true;
        if (!everActive) return;
        variables.gate.awaitHandoff(planId,variables.ds);
        sql("UPDATE fpw_arrival_deliveries d JOIN fpw_arrival_notices n ON n.id=d.notice_id
            JOIN fpw_arrival_revisions r ON r.id=n.revision_id
            SET d.state='SUPPRESSED',d.reason=:reason,d.claim_token=NULL,d.lease_until_utc=NULL,
                d.next_attempt_utc=NULL,d.updated_at_utc=UTC_TIMESTAMP(6)
            WHERE r.plan_id=:p AND r.revision_no=:rev AND d.state IN ('PENDING','CLAIMED','FAILED_RETRYABLE')",
            {reason=reason,p=planId,rev=revisionNo});
    }

    private query function duePlans(required numeric maxRows,required string t) {
        return sql("SELECT r.plan_id FROM fpw_arrival_revisions r
            INNER JOIN fpw_arrival_watches w ON w.plan_id=r.plan_id AND w.current_revision=r.revision_no
            INNER JOIN fpw_arrival_dispatch_control g ON g.plan_id=0
            LEFT JOIN fpw_arrival_dispatch_control c ON c.plan_id=r.plan_id
            LEFT JOIN fpw_arrival_notices n ON n.revision_id=r.id AND n.slot_no=0
            WHERE r.state IN ('PENDING','OVERDUE') AND r.historical_only=0 AND w.terminal_reason IS NULL
            AND r.next_due_utc IS NOT NULL AND r.deadline_utc<=:t AND r.deadline_utc>GREATEST(g.activated_at_utc,g.updated_at_utc)
            AND ((g.mode='LIVE' AND c.plan_id IS NULL)
                OR (g.mode IN ('LIVE','ALLOWLIST') AND c.mode='ALLOWLIST' AND r.deadline_utc>GREATEST(c.activated_at_utc,c.updated_at_utc)))
            AND n.id IS NULL ORDER BY r.deadline_utc,r.id LIMIT " & int(maxRows),{t=t});
    }

    public struct function runCycle(numeric limit=100) {
        var summary={enabled=false,created=0,processed=0,submitted=0,retryable=0,
            permanentFailures=0,unknown=0,suppressed=0,missingRecipients=0,errors=0};
        if (!installed() || !liveTransportEnabled()) return summary;
        var globalRow=sql("SELECT mode FROM fpw_arrival_dispatch_control WHERE plan_id=0");
        if (!globalRow.recordCount || !listFind("ALLOWLIST,LIVE",globalRow.mode[1])) return summary;
        var observation=sql("SELECT mode FROM fpw_arrival_rollout WHERE id=1");
        if (!observation.recordCount || observation.mode[1]!="OBSERVE") return summary;
        summary.enabled=true;
        var capped=max(1,min(500,int(arguments.limit)));
        var candidates=duePlans(capped,clock());
        for (var candidate in candidates) {
            try {
                var notice=evaluatePlan(candidate.plan_id);
                if (notice.created) {
                    summary.created++;
                    if (!notice.recipientCount) summary.missingRecipients++;
                }
            } catch (any ignoredCreationError) {summary.errors++;}
        }
        for (var work in dueDeliveries(capped,clock())) {
            try {
                var result=dispatchOne(work.id);
                summary.processed++;
                switch (result.state) {
                    case "SUBMITTED": summary.submitted++; break;
                    case "FAILED_RETRYABLE": summary.retryable++; break;
                    case "FAILED_PERMANENT": summary.permanentFailures++; break;
                    case "UNKNOWN": summary.unknown++; break;
                    case "SUPPRESSED": summary.suppressed++; break;
                }
            }
            catch (any ignoredDispatchError) {summary.errors++;}
        }
        if (summary.errors) writeLog(file="fpw-monitor",type="error",text="Arrival dispatch worker failures: " & int(summary.errors));
        if (summary.permanentFailures || summary.unknown || summary.missingRecipients)
            writeLog(file="fpw-monitor",type="warning",text="Arrival notices requiring review. Permanent failures: "
                & summary.permanentFailures & ", uncertain submissions: " & summary.unknown & ", no recipients: " & summary.missingRecipients);
        return summary;
    }
}
