component output="false" hint="Final-arrival and arrival-time change notices. All public methods are internal application calls." {
    public any function init(string ds="fpw", any captureTransport="", string recipientSecret="") {
        variables.ds=arguments.ds;
        variables.changeSlot=1;
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

    private boolean function changeSlotInstalled() {
        var q=sql("SELECT cc.CHECK_CLAUSE AS rule_text FROM information_schema.TABLE_CONSTRAINTS tc
            JOIN information_schema.CHECK_CONSTRAINTS cc ON cc.CONSTRAINT_SCHEMA=tc.CONSTRAINT_SCHEMA AND cc.CONSTRAINT_NAME=tc.CONSTRAINT_NAME
            WHERE tc.TABLE_SCHEMA=BINARY DATABASE() AND tc.TABLE_NAME='fpw_arrival_notices' AND tc.CONSTRAINT_NAME='ck_arrival_notice_slot'");
        return q.recordCount==1 && reReplace(replace(lCase(q.rule_text[1]),chr(96),"","all"),"[[:space:]()]","","all")=="slot_noin0,1";
    }

    // Called in the transaction that activates either kind of float plan.
    public void function allowlistActivatedPlan(required numeric planId) {
        if (planId>0 && installed()) {
            insertActiveScope(planId);
            armCaptainReminder(planId);
        }
    }

    private void function insertActiveScope(required numeric planId) {
        sql("INSERT INTO fpw_arrival_dispatch_control (plan_id,mode,updated_at_utc)
            SELECT f.floatPlanId,'ALLOWLIST',UTC_TIMESTAMP(6) FROM floatplans f
            JOIN fpw_arrival_dispatch_control g ON g.plan_id=0
            WHERE f.floatPlanId=:p AND f.status='ACTIVE' AND f.closedAt IS NULL AND f.expiredAt IS NULL
            ON DUPLICATE KEY UPDATE plan_id=fpw_arrival_dispatch_control.plan_id",{p=planId});
    }

    // Recheck the plan at insertion. A concurrent closure or explicit scope wins.
    private numeric function enrollMissingActivePlans(required numeric maxRows) {
        var missing=sql("SELECT f.floatPlanId FROM floatplans f
            LEFT JOIN fpw_arrival_dispatch_control c ON c.plan_id=f.floatPlanId
            WHERE f.status='ACTIVE' AND f.closedAt IS NULL AND f.expiredAt IS NULL
            AND f.floatPlanId>0 AND c.plan_id IS NULL ORDER BY f.floatPlanId LIMIT " & int(maxRows));
        var errors=0;
        for (var plan in missing) {
            try { insertActiveScope(plan.floatPlanId); }
            catch (any enrollmentError) { errors++; }
        }
        return errors;
    }

    // The receipt is also the start of this plan's reminder coverage. Re-enrollment
    // cannot reset it or turn an already-overdue plan into a catch-up email.
    private void function armCaptainReminder(required numeric planId) {
        sql("INSERT INTO floatplan_alert_history (floatPlanId,alertType,status,createdAtUTC,attemptCount)
            SELECT f.floatPlanId,'CAPTAIN_CLOSEOUT','PENDING',UTC_TIMESTAMP(),0 FROM floatplans f
            JOIN fpw_arrival_dispatch_control c ON c.plan_id=f.floatPlanId AND c.mode IN ('ALLOWLIST','CAPTURE')
            WHERE f.floatPlanId=:p AND f.status='ACTIVE' AND f.closedAt IS NULL AND f.expiredAt IS NULL
            ON DUPLICATE KEY UPDATE id=floatplan_alert_history.id",{p=planId});
    }

    private numeric function enrollMissingCaptainReminders(required numeric maxRows) {
        var missing=sql("SELECT f.floatPlanId FROM floatplans f JOIN fpw_arrival_dispatch_control c
            ON c.plan_id=f.floatPlanId AND c.mode IN ('ALLOWLIST','CAPTURE')
            LEFT JOIN floatplan_alert_history h ON h.floatPlanId=f.floatPlanId AND h.alertType='CAPTAIN_CLOSEOUT'
            WHERE f.status='ACTIVE' AND f.closedAt IS NULL AND f.expiredAt IS NULL AND h.id IS NULL
            ORDER BY f.floatPlanId LIMIT " & int(maxRows));
        var errors=0;
        for (var plan in missing) {
            try { armCaptainReminder(plan.floatPlanId); }
            catch (any enrollmentError) { errors++; }
        }
        return errors;
    }

    // Use the saved deadline even for an unstarted trip or a finished final leg.
    // An explicit stop, a stale revision, or either rollout cutoff still blocks mail.
    private query function dueCaptainReminders(required numeric maxRows,required string t,numeric planId=0) {
        var binds={t=t};
        var scope=variables.captureMode ? "c.mode='CAPTURE'" :
            "c.mode='ALLOWLIST' AND g.mode IN ('ALLOWLIST','LIVE') AND o.mode='OBSERVE'
             AND f.returnTimeUTC>GREATEST(g.activated_at_utc,g.updated_at_utc)";
        var filter="";
        var fields="f.floatPlanId AS plan_id";
        if (planId>0) {
            filter=" AND f.floatPlanId=:p";
            binds.p=planId;
            fields&=",h.id,h.attemptCount,u.email,DATE_FORMAT(f.returnTimeUTC,'%Y-%m-%d %H:%i:%s') AS deadline,
                COALESCE(NULLIF(TRIM(f.returnTZ),''),NULLIF(TRIM(f.returnTimezone),''),'UTC') AS zone";
        }
        return sql("SELECT " & fields & " FROM floatplans f
            JOIN floatplan_alert_history h ON h.floatPlanId=f.floatPlanId AND h.alertType='CAPTAIN_CLOSEOUT'
            LEFT JOIN users u ON u.userId=f.userId
            JOIN fpw_arrival_dispatch_control c ON c.plan_id=f.floatPlanId
            JOIN fpw_arrival_dispatch_control g ON g.plan_id=0 JOIN fpw_arrival_rollout o ON o.id=1
            LEFT JOIN fpw_arrival_watches w ON w.plan_id=f.floatPlanId
            LEFT JOIN fpw_arrival_revisions r ON r.plan_id=w.plan_id AND r.revision_no=w.current_revision
            WHERE f.status='ACTIVE' AND f.closedAt IS NULL AND f.expiredAt IS NULL AND " & scope & "
            AND f.returnTimeUTC<=:t AND f.returnTimeUTC>GREATEST(h.createdAtUTC,o.cutoff_utc,c.activated_at_utc,c.updated_at_utc)
            AND (w.plan_id IS NULL OR (w.owner_id=f.userId AND (w.terminal_reason IS NULL OR w.terminal_reason='FINAL_ARRIVAL')
                AND (r.deadline_utc=f.returnTimeUTC AND r.historical_only=0 AND r.state IN ('PENDING','OVERDUE','RESOLVED')
                     OR w.current_revision=0 AND w.terminal_reason='FINAL_ARRIVAL')))
            AND NOT EXISTS (SELECT 1 FROM floatplan_monitoring m WHERE m.float_plan_id=f.floatPlanId
                AND (m.is_monitoring_enabled=0 OR m.monitor_state='CLOSED'))
            AND (h.status='PENDING' OR (h.status='FAILED_RETRYABLE' AND h.attemptCount BETWEEN 1 AND 3
                AND TIMESTAMPADD(MINUTE,CASE h.attemptCount WHEN 1 THEN 5 WHEN 2 THEN 15 ELSE 30 END,h.lastAttemptAtUTC)<=:t))"
            & filter & " ORDER BY f.returnTimeUTC,f.floatPlanId LIMIT " & int(maxRows) & (planId>0 ? " FOR UPDATE" : ""),binds);
    }

    public struct function dispatchCaptainReminder(required numeric planId,string asOfUtc="") {
        if (planId<=0) return {state="INELIGIBLE"};
        var t=clock(asOfUtc);
        var holder={};
        try {
            transaction {
                sql("SELECT floatPlanId FROM floatplans WHERE floatPlanId=:p FOR UPDATE",{p=planId});
                var due=dueCaptainReminders(1,t,planId);
                if (!due.recordCount) return {state="INELIGIBLE"};
                var policy=permission(planId);
                if (!policy.enabled) return {state="DISABLED"};
                var address=lCase(trim(due.email[1] ?: ""));
                if (!isValid("email",address)) {
                    sql("UPDATE floatplan_alert_history SET status='FAILED_PERMANENT',lastError='INVALID_RECIPIENT' WHERE id=:id",
                        {id=due.id[1]});
                    return {state="FAILED_PERMANENT"};
                }
                var message=variables.mail.buildNotice(planId,due.deadline[1],due.zone[1],t,true);
                holder.gate=variables.gate.acquire(planId,variables.ds);
                var attempt=val(due.attemptCount[1])+1;
                // A worker lost across SMTP may have submitted the message. Only a
                // definite transient outcome below may reopen this receipt for retry.
                sql("UPDATE floatplan_alert_history SET status='UNKNOWN',lastError='HANDOFF_UNCONFIRMED',
                    lastAttemptAtUTC=:t,attemptCount=:attempt WHERE id=:id",{id=due.id[1],t=t,attempt=attempt});
            }
            try {
                var result=variables.captureMode ? variables.capture.submit(address,message)
                    : variables.mail.submit(address,message,policy.mailHogOnly);
            } catch (any uncertainHandoff) { var result={status="UNKNOWN"}; }
            var state=uCase(result.status ?: "UNKNOWN");
            if (!listFind("SUBMITTED,FAILED_RETRYABLE,FAILED_PERMANENT,UNKNOWN",state)) state="UNKNOWN";
            var exhausted=state=="FAILED_RETRYABLE" && attempt>=4;
            if (exhausted) state="FAILED_PERMANENT";
            var reason=exhausted ? "RETRIES_EXHAUSTED" : (state=="UNKNOWN" ? "HANDOFF_UNCONFIRMED" : state);
            sql("UPDATE floatplan_alert_history SET status=:state,lastAttemptAtUTC=:t,
                sentAtUTC=CASE WHEN :state='SENT' THEN :t ELSE NULL END,
                lastError=CASE WHEN :state='SENT' THEN NULL ELSE :reason END
                WHERE id=:id AND status='UNKNOWN' AND attemptCount=:attempt",
                {id=due.id[1],state=state=="SUBMITTED" ? "SENT" : state,t=clock(asOfUtc),reason=reason,attempt=attempt});
            return {state=state};
        } finally {
            if (structKeyExists(holder,"gate")) variables.gate.release(holder.gate);
        }
    }

    private string function clock(string asOfUtc="") {
        if (!len(asOfUtc)) return sql("SELECT DATE_FORMAT(UTC_TIMESTAMP(6),'%Y-%m-%d %H:%i:%s.%f') AS v").v[1];
        if (!variables.captureMode || !reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]{1,6})?$",asOfUtc))
            throw(type="FPW.ArrivalClock",message="Only a capture transport can use a controlled UTC clock.");
        return sql("SELECT DATE_FORMAT(CAST(:t AS DATETIME(6)),'%Y-%m-%d %H:%i:%s.%f') AS v",{t=asOfUtc}).v[1];
    }

    private boolean function permitsGlobalMode(required string mode,required string transport) {
        if (transport=="MAILHOG") return mode=="ALLOWLIST";
        return transport=="PRODUCTION" && listFind("ALLOWLIST,LIVE",mode)>0;
    }

    // Global OFF is never overridden for real mail. CAPTURE requires an injected
    // in-process sink, development environment AND an explicitly selected plan.
    private struct function permission(required numeric planId,string queuedAt="") {
        var out={enabled=false,generation=0,scopeGeneration=1,cutoff="",mailHogOnly=false};
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
        var transport=variables.mail.scheduledTransport();
        if (!permitsGlobalMode(globalRow.mode[1],transport) || !len(globalRow.cutoff[1] ?: "")) return out;
        var liveQueue=globalRow.mode[1]=="LIVE" && len(queuedAt)>0;
        if ((!scope.recordCount && !liveQueue) || (scope.recordCount && scope.mode[1]!="ALLOWLIST")) return out;
        var observation=sql("SELECT mode FROM fpw_arrival_rollout WHERE id=1 LOCK IN SHARE MODE");
        out.enabled=observation.recordCount && observation.mode[1]=="OBSERVE";
        out.mailHogOnly=(transport=="MAILHOG");
        out.cutoff=globalRow.cutoff[1];
        if (scope.recordCount && compare(scope.cutoff[1],out.cutoff)>0) {
            // A durable delivery queued under blanket LIVE before this first scope
            // already had permission. Later generations must always use their own cutoff.
            if (!liveQueue || out.scopeGeneration!=1 || compare(queuedAt,scope.cutoff[1])>=0)
                out.cutoff=scope.cutoff[1];
        }
        return out;
    }

    private string function ineligibleReason(required struct context,required struct policy,required string t,boolean deadlineChange=false) {
        if (!policy.enabled) return "DISPATCH_DISABLED";
        if (!context.eligible) return context.reason;
        if (deadlineChange) {
            if (compare(context.changedAtUtc,policy.cutoff)<=0) return "HISTORICAL_CUTOFF";
            return compare(t,context.changedAtUtc)<0 ? "NOT_DUE" : "";
        }
        if (context.historicalOnly || compare(context.deadlineUtc,policy.cutoff)<=0) return "HISTORICAL_CUTOFF";
        if (compare(t,context.deadlineUtc)<0) return "NOT_DUE";
        return "";
    }

    // Only the save that authored changedRevision can enqueue its update. The monitor
    // creates slot zero and drains pending deliveries; it never backfills old edits.
    public struct function evaluatePlan(required numeric planId,string asOfUtc="",numeric changedRevision=0) {
        var out={state="DISABLED",created=false,noticeId=0,recipientCount=0};
        var deadlineChange=changedRevision>0;
        var slot=deadlineChange ? variables.changeSlot : 0;
        if (!installed() || (deadlineChange && !changeSlotInstalled())) return out;
        var t=clock(asOfUtc);
        transaction {
            var ctx=variables.observer.lockedDeliveryContext(planId,deadlineChange);
            var policy=permission(planId);
            var reason=ineligibleReason(ctx,policy,t,deadlineChange);
            if (!len(reason) && deadlineChange && ctx.revisionNo!=changedRevision) reason="SUPERSEDED";
            if (len(reason)) {
                out.state=reason;
                return out;
            }
            var old=sql("SELECT id,state,recipient_count FROM fpw_arrival_notices
                WHERE revision_id=:r AND slot_no=:slot FOR UPDATE",{r=ctx.revisionId,slot=slot});
            if (old.recordCount) {
                out.noticeId=val(old.id[1]); out.state=old.state[1]; out.recipientCount=val(old.recipient_count[1]);
                return out;
            }
            var recipients=variables.mail.selectedRecipients(planId,deadlineChange);
            out.recipientCount=arrayLen(recipients.valid);
            out.state=out.recipientCount ? "READY" : "NO_RECIPIENTS";
            var issue=(recipients.invalidCount>0 ? "INVALID_SELECTION" : (recipients.missingCount>0 ? "MISSING_ADDRESS" : ""));
            if (recipients.invalidCount>0 && recipients.missingCount>0) issue="MISSING_AND_INVALID";
            if (!out.recipientCount && !len(issue)) issue="NO_SELECTION";
            sql("INSERT INTO fpw_arrival_notices(revision_id,slot_no,plan_id,state,reason,recipient_count,invalid_count,created_at_utc)
                VALUES (:r,:slot,:p,:state,NULLIF(:issue,''),:n,:bad,:t)",
                {r=ctx.revisionId,slot=slot,p=planId,state=out.state,issue=issue,n=out.recipientCount,bad=recipients.invalidCount+recipients.missingCount,t=t});
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
        return sql("SELECT d.id,n.plan_id,n.revision_id,n.slot_no,d.recipient_key,d.state,d.claim_token,d.attempt_count,
                d.generation,d.scope_generation,DATE_FORMAT(d.created_at_utc,'%Y-%m-%d %H:%i:%s.%f') AS queued_at,
                DATE_FORMAT(d.next_attempt_utc,'%Y-%m-%d %H:%i:%s.%f') AS next_at,
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
            var policy=permission(row.plan_id[1],row.queued_at[1]);
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
            var deadlineChange=found.slot_no[1]==variables.changeSlot;
            var ctx=variables.observer.lockedDeliveryContext(found.plan_id[1],deadlineChange);
            var row=delivery(id,true);
            if (!row.recordCount || row.state[1]!="CLAIMED" || compare(row.claim_token[1] ?: "",token)!=0
                || compare(row.lease_at[1],t)<=0) return {state="STALE_CLAIM"};
            var policy=permission(row.plan_id[1],row.queued_at[1]);
            var reason=ineligibleReason(ctx,policy,t,deadlineChange);
            if (len(reason)) return suppress(id,reason,t);
            if (!sameGeneration(row,policy)) return suppress(id,"GENERATION_CHANGED",t);
            if (ctx.revisionId!=row.revision_id[1]) return suppress(id,"SUPERSEDED",t);
            var address=variables.mail.resolveRecipient(row.plan_id[1],row.recipient_key[1],deadlineChange);
            if (!len(address)) return suppress(id,"RECIPIENT_CHANGED",t);
            var message=deadlineChange ? variables.mail.buildDeadlineChangeNotice(row.plan_id[1],ctx)
                : variables.mail.buildNotice(row.plan_id[1],ctx.deadlineUtc,ctx.zone,t);
            holder.gate=variables.gate.acquire(row.plan_id[1],variables.ds);
            var n=val(row.attempt_count[1])+1;
            sql("INSERT INTO fpw_arrival_attempts(delivery_id,attempt_no,status,started_at_utc)
                VALUES (:id,:n,'SUBMITTING',:t)",{id=id,n=n,t=t});
            sql("UPDATE fpw_arrival_deliveries SET state='SUBMITTING',attempt_count=:n,next_attempt_utc=NULL,
                lease_until_utc=TIMESTAMPADD(SECOND,90,:t),updated_at_utc=:t WHERE id=:id",{n=n,t=t,id=id});
            return {state="SUBMITTING",attempt=n,address=address,message=message,mailHogOnly=policy.mailHogOnly};
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
                var sent=variables.captureMode ? variables.capture.submit(prepared.address,prepared.message)
                    : variables.mail.submit(prepared.address,prepared.message,prepared.mailHogOnly);
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

    private query function dueDeliveries(required numeric maxRows,required string t,numeric planId=0,numeric slot=0,numeric noticeId=0) {
        var binds={t=t,slot=slot};
        var scope="";
        if (noticeId>0) {scope=" AND n.id=:n";binds.n=noticeId;}
        else if (planId>0) {scope=" AND n.plan_id=:p";binds.p=planId;}
        else {
            scope=" AND EXISTS (SELECT 1 FROM fpw_arrival_dispatch_control g
                LEFT JOIN fpw_arrival_dispatch_control c ON c.plan_id=n.plan_id
                WHERE g.plan_id=0 AND ((g.mode='LIVE' AND c.plan_id IS NULL)
                    OR (g.mode IN ('LIVE','ALLOWLIST') AND c.mode='ALLOWLIST')))";
        }
        return sql("SELECT d.id FROM fpw_arrival_deliveries d JOIN fpw_arrival_notices n ON n.id=d.notice_id
            WHERE n.slot_no=:slot AND ((d.state IN ('PENDING','FAILED_RETRYABLE') AND d.next_attempt_utc<=:t)
            OR (d.state IN ('CLAIMED','SUBMITTING') AND d.lease_until_utc<=:t))" & scope
            & " ORDER BY COALESCE(d.next_attempt_utc,d.lease_until_utc),d.id LIMIT " & int(maxRows),binds);
    }

    public struct function dispatchPlan(required numeric planId,string asOfUtc="") {
        var t=clock(asOfUtc);
        var outcomes=[];
        for (var row in dueDeliveries(500,t,planId)) arrayAppend(outcomes,dispatchOne(row.id,asOfUtc));
        return {results=outcomes,processed=arrayLen(outcomes)};
    }

    private void function dispatchBatch(required query rows,required struct counts,string asOfUtc="") {
        for (var work in rows) {
            try {
                var result=dispatchOne(work.id,asOfUtc);
                counts.processed++;
                switch (result.state) {
                    case "SUBMITTED": counts.submitted++; break;
                    case "FAILED_RETRYABLE": counts.retryable++; break;
                    case "FAILED_PERMANENT": counts.permanentFailures++; break;
                    case "UNKNOWN": counts.unknown++; break;
                    case "SUPPRESSED": counts.suppressed++; break;
                }
            } catch (any dispatchError) {counts.errors++;}
        }
    }

    // A save dispatches only its committed notice. The monitor retries the same
    // durable recipient rows with a separate batch budget from overdue alerts.
    public struct function dispatchDeadlineChanges(numeric noticeId=0,numeric limit=100,string asOfUtc="") {
        var counts={processed=0,submitted=0,retryable=0,permanentFailures=0,unknown=0,suppressed=0,errors=0};
        if (variables.captureMode && noticeId<=0) return counts;
        var rows=dueDeliveries(max(1,min(500,int(limit))),clock(asOfUtc),0,variables.changeSlot,noticeId);
        dispatchBatch(rows,counts,asOfUtc);
        if (counts.errors || counts.permanentFailures || counts.unknown)
            writeLog(file="fpw-monitor",type="warning",text="Arrival time change delivery needs review. Errors: " & counts.errors
                & ", permanent failures: " & counts.permanentFailures & ", uncertain submissions: " & counts.unknown);
        return counts;
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
            INNER JOIN fpw_arrival_dispatch_control c ON c.plan_id=r.plan_id
            LEFT JOIN fpw_arrival_notices n ON n.revision_id=r.id AND n.slot_no=0
            WHERE r.state IN ('PENDING','OVERDUE') AND r.historical_only=0 AND w.terminal_reason IS NULL
            AND r.next_due_utc IS NOT NULL AND r.deadline_utc<=:t AND r.deadline_utc>GREATEST(g.activated_at_utc,g.updated_at_utc)
            AND g.mode IN ('LIVE','ALLOWLIST') AND c.mode='ALLOWLIST'
            AND r.deadline_utc>GREATEST(c.activated_at_utc,c.updated_at_utc)
            AND n.id IS NULL ORDER BY r.deadline_utc,r.id LIMIT " & int(maxRows),{t=t});
    }

    public struct function runCycle(numeric limit=100) {
        var summary={enabled=false,created=0,processed=0,submitted=0,retryable=0,
            permanentFailures=0,unknown=0,suppressed=0,missingRecipients=0,errors=0,
            captainReminders={submitted=0,retryable=0,permanentFailures=0,unknown=0,errors=0}};
        if (!installed() || variables.captureMode) return summary;
        var capped=max(1,min(500,int(arguments.limit)));
        summary.errors=enrollMissingActivePlans(capped);
        if (summary.errors) writeLog(file="fpw-monitor",type="error",text="Active trip allowlist enrollment failures: " & int(summary.errors));
        try { summary.captainReminders.errors=enrollMissingCaptainReminders(capped); }
        catch (any enrollmentError) {summary.captainReminders.errors++;}
        if (summary.captainReminders.errors)
            writeLog(file="fpw-monitor",type="error",text="Captain closeout reminder enrollment failed.");
        var transport=variables.mail.scheduledTransport();
        if (!len(transport)) return summary;
        var globalRow=sql("SELECT mode FROM fpw_arrival_dispatch_control WHERE plan_id=0");
        if (!globalRow.recordCount || !permitsGlobalMode(globalRow.mode[1],transport)) return summary;
        var observation=sql("SELECT mode FROM fpw_arrival_rollout WHERE id=1");
        if (!observation.recordCount || observation.mode[1]!="OBSERVE") return summary;
        summary.enabled=true;
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
        dispatchBatch(dueDeliveries(capped,clock()),summary);
        var dueCaptains=queryNew("plan_id");
        try { dueCaptains=dueCaptainReminders(capped,clock()); }
        catch (any selectionError) {summary.captainReminders.errors++;}
        for (var captain in dueCaptains) {
            try {
                var reminder=dispatchCaptainReminder(captain.plan_id);
                switch (reminder.state) {
                    case "SUBMITTED": summary.captainReminders.submitted++; break;
                    case "FAILED_RETRYABLE": summary.captainReminders.retryable++; break;
                    case "FAILED_PERMANENT": summary.captainReminders.permanentFailures++; break;
                    case "UNKNOWN": summary.captainReminders.unknown++; break;
                }
            } catch (any reminderError) {summary.captainReminders.errors++;}
        }
        summary.errors+=summary.captainReminders.errors;
        try {
            summary.deadlineChanges=dispatchDeadlineChanges(limit=capped);
            summary.errors+=summary.deadlineChanges.errors;
        } catch (any changeDispatchError) {summary.errors++;}
        if (summary.captainReminders.permanentFailures || summary.captainReminders.unknown)
            writeLog(file="fpw-monitor",type="warning",text="Captain closeout reminders requiring review: "
                & (summary.captainReminders.permanentFailures+summary.captainReminders.unknown));
        if (summary.errors) writeLog(file="fpw-monitor",type="error",text="Arrival dispatch worker failures: " & int(summary.errors));
        if (summary.permanentFailures || summary.unknown || summary.missingRecipients)
            writeLog(file="fpw-monitor",type="warning",text="Arrival notices requiring review. Permanent failures: "
                & summary.permanentFailures & ", uncertain submissions: " & summary.unknown & ", no recipients: " & summary.missingRecipients);
        return summary;
    }
}
