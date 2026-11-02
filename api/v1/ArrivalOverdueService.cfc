component output="false" hint="Independent final-arrival observation. This component has no mail transport." {
    public any function init(string ds="fpw") {
        variables.ds = arguments.ds;
        return this;
    }

    private any function sql(required string statement, struct params={}) {
        return queryExecute(arguments.statement, arguments.params, {datasource=variables.ds});
    }

    private boolean function installed() {
        var tables = sql("SELECT COUNT(*) AS n FROM information_schema.tables
            WHERE table_schema=DATABASE() AND table_name IN
            ('fpw_arrival_rollout','fpw_arrival_watches','fpw_arrival_revisions','fpw_arrival_events')");
        return tables.n[1] == 4;
    }

    public numeric function getRevision(required numeric planId) {
        if (!installed()) return 0;
        var watch = sql("SELECT current_revision FROM fpw_arrival_watches WHERE plan_id=:p", {p=planId});
        return watch.recordCount ? val(watch.current_revision[1]) : 0;
    }

    private struct function outcome(required string state, numeric revision=0) {
        return {success=true, state=arguments.state, revision=arguments.revision};
    }

    // Use UTC SQL strings at the JDBC boundary. A supplied clock is for internal tests only.
    private string function observationClock(string asOfUtc="") {
        if (!len(asOfUtc)) return sql("SELECT DATE_FORMAT(UTC_TIMESTAMP(6),'%Y-%m-%d %H:%i:%s.%f') AS stamp").stamp[1];
        if (!reFind("^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(\.\d{1,6})?$", asOfUtc))
            throw(type="FPW.ArrivalClock",message="Expected a UTC SQL timestamp.");
        return asOfUtc;
    }

    private query function lockedPlan(required numeric planId) {
        return sql("SELECT floatPlanId, userId, UPPER(TRIM(status)) AS plan_status, route_instance_id,
                DATE_FORMAT(returnTimeUTC,'%Y-%m-%d %H:%i:%s') AS deadline,
                COALESCE(NULLIF(TRIM(returnTZ),''), NULLIF(TRIM(returnTimezone),''),'UTC') AS zone,
                closedAt IS NOT NULL AS has_close, expiredAt IS NOT NULL AS has_expiry
            FROM floatplans WHERE floatPlanId=:p FOR UPDATE",{p=planId});
    }

    private query function lockedWatch(required numeric planId) {
        return sql("SELECT owner_id,current_revision,terminal_reason FROM fpw_arrival_watches WHERE plan_id=:p FOR UPDATE",{p=planId});
    }

    private void function addEvent(required numeric planId, required numeric revision, required string event,
            required string atUtc, string reason="", numeric actor=0, numeric slot=-1, numeric skipped=0) {
        sql("INSERT INTO fpw_arrival_events
            (plan_id,revision_no,event_type,event_at_utc,reason,actor_user_id,slot_no,skipped_slots)
            VALUES (:p,:r,:e,:t,NULLIF(:reason,''),NULLIF(:actor,'0'),NULLIF(:slot,-1),:skipped)",
            {p=planId,r=revision,e=event,t=atUtc,reason=reason,actor=actor,slot=slot,skipped=skipped});
    }

    private void function createWatch(required numeric planId, required string owner) {
        sql("INSERT INTO fpw_arrival_watches (plan_id,owner_id,current_revision,created_at_utc,updated_at_utc)
            VALUES (:p,:owner,0,UTC_TIMESTAMP(6),UTC_TIMESTAMP(6))",{p=planId,owner=owner});
    }

    private struct function eligibility(required query plan, required string reason) {
        var p=plan.floatPlanId[1];
        var status=plan.plan_status[1];
        var routeId=val(plan.route_instance_id[1] ?: 0);
        var result={eligible=false, terminal=""};
        if (listFindNoCase("CANCELLED,CANCELED",status)) result.terminal="CANCELLED";
        else if (status=="EXPIRED" || plan.has_expiry[1]) result.terminal="EXPIRED";
        else if (status=="CLOSED" || plan.has_close[1]) result.terminal="CLOSED";
        else if (reason=="ADMIN_STOP" || reason=="MONITOR_STOPPED") result.terminal=reason;
        if (len(result.terminal) || status!="ACTIVE") return result;

        // Check actual, owner-bound leg progress. The last routine checkpoint is irrelevant.
        var routeStarted=false;
        if (routeId>0) {
            var route=sql("SELECT ri.started_at IS NOT NULL AS started,
                    UPPER(ri.status)='COMPLETED' AND ri.completed_at IS NOT NULL AS finished,
                    EXISTS (SELECT 1 FROM route_instance_leg_progress g WHERE g.route_instance_id=ri.id
                        AND g.user_id=:owner AND (g.leg_started_at IS NOT NULL OR g.completed_at IS NOT NULL
                        OR UPPER(g.status) IN ('STARTED','IN_PROGRESS','COMPLETED'))) AS leg_start_proof,
                    (SELECT COUNT(*) FROM route_instance_legs l WHERE l.route_instance_id=ri.id) AS expected_legs,
                    (SELECT COUNT(*) FROM route_instance_legs l JOIN route_instance_leg_progress g
                        ON g.route_instance_id=l.route_instance_id AND g.leg_order=l.leg_order AND g.user_id=:owner
                        WHERE l.route_instance_id=ri.id AND UPPER(g.status)='COMPLETED') AS completed_legs,
                    (SELECT g.completed_at IS NOT NULL FROM route_instance_legs l LEFT JOIN route_instance_leg_progress g
                        ON g.route_instance_id=l.route_instance_id AND g.leg_order=l.leg_order AND g.user_id=:owner
                        WHERE l.route_instance_id=ri.id ORDER BY l.leg_order DESC,l.id DESC LIMIT 1) AS final_stamp
                FROM route_instances ri WHERE ri.id=:routeId AND ri.user_id=:owner",
                {routeId=routeId,owner=plan.userId[1]});
            if (!route.recordCount) return result;
            if (route.finished[1] || (route.expected_legs[1]>0 && route.expected_legs[1]==route.completed_legs[1] && val(route.final_stamp[1] ?: 0))) {
                result.terminal="FINAL_ARRIVAL";
                return result;
            }
            routeStarted=route.started[1] || route.leg_start_proof[1];
        }
        var monitor=sql("SELECT monitoring_mode,is_monitoring_enabled,monitor_state FROM floatplan_monitoring
            WHERE float_plan_id=:p AND user_id=:owner",{p=p,owner=plan.userId[1]});
        if (!monitor.recordCount) return result;
        if (!monitor.is_monitoring_enabled[1] || monitor.monitor_state[1]=="CLOSED") {
            result.terminal="MONITOR_STOPPED";
            return result;
        }
        result.eligible=(routeId<=0 && monitor.monitoring_mode[1]=="basic")
            || (routeId>0 && routeStarted && monitor.monitoring_mode[1]=="active_route");
        return result;
    }

    // Caller holds the transaction until the initial notice or handoff permit commits.
    public struct function lockedDeliveryContext(required numeric planId) {
        var out={eligible=false,reason="INELIGIBLE"};
        var plan=lockedPlan(planId);
        var watch=lockedWatch(planId);
        if (!plan.recordCount || !watch.recordCount || !watch.current_revision[1]) return out;
        if (compare(plan.userId[1],watch.owner_id[1])!=0) return out;
        if (len(watch.terminal_reason[1] ?: "")) {
            out.reason=watch.terminal_reason[1];
            return out;
        }
        var proof=eligibility(plan,"DISPATCH");
        if (!proof.eligible) {
            if (len(proof.terminal)) out.reason=proof.terminal;
            return out;
        }
        var revision=sql("SELECT id,state,historical_only,deadline_zone,
                DATE_FORMAT(deadline_utc,'%Y-%m-%d %H:%i:%s') AS deadline,
                DATE_FORMAT(deadline_utc,'%Y-%m-%d %H:%i:%s.%f') AS precise_deadline
            FROM fpw_arrival_revisions WHERE plan_id=:p AND revision_no=:r FOR UPDATE",
            {p=planId,r=watch.current_revision[1]});
        if (!revision.recordCount || !listFind("PENDING,OVERDUE",revision.state[1])
            || compare(plan.deadline[1] ?: "",revision.deadline[1])!=0) return out;
        return {eligible=true,revisionId=revision.id[1],deadlineUtc=revision.precise_deadline[1],
            zone=revision.deadline_zone[1],historicalOnly=revision.historical_only[1]==1};
    }

    private void function stopUnsubmittedMail(required numeric planId,required numeric revision,required string reason) {
        if (revision>0) createObject("component","fpw.api.v1.ArrivalOverdueDeliveryService")
            .init(variables.ds).suppressRevision(planId,revision,reason);
    }

    private struct function stopWatch(required numeric planId, required numeric revision, required string reason,
            required string atUtc, numeric actor=0) {
        var state=listFind("CLOSED,FINAL_ARRIVAL",reason) ? "RESOLVED" : "SUPPRESSED";
        stopUnsubmittedMail(planId,revision,reason);
        sql("UPDATE fpw_arrival_watches SET terminal_reason=:reason, terminal_at_utc=:atUtc,updated_at_utc=UTC_TIMESTAMP(6)
             WHERE plan_id=:p",{reason=reason,atUtc=atUtc,p=planId});
        if (revision>0) {
            sql("UPDATE fpw_arrival_revisions SET state=:state,next_due_utc=NULL,ended_at_utc=:atUtc,suppression_reason=:reason
                WHERE plan_id=:p AND revision_no=:r",{state=state,atUtc=atUtc,reason=reason,p=planId,r=revision});
        }
        addEvent(planId,revision,state,atUtc,reason,actor);
        return outcome(state,revision);
    }

    private void function appendRevision(required numeric planId,required numeric revision,required string deadline,
            required string zone,required string source,required numeric actor,required boolean armed) {
        var result=sql("SELECT cutoff_utc FROM fpw_arrival_rollout WHERE id=1");
        if (result.recordCount!=1) throw(type="FPW.ArrivalRollout",message="Arrival rollout control is missing.");
        sql("INSERT INTO fpw_arrival_revisions
            (plan_id,revision_no,deadline_utc,deadline_zone,source,actor_user_id,historical_only,state,
             initial_due_utc,next_due_utc,last_slot,created_at_utc)
            SELECT :p,:r,:deadline,:zone,:source,NULLIF(:actor,'0'),CAST(:deadline AS DATETIME)<=cutoff_utc,
                'PENDING',:deadline,CASE WHEN :armed=1 THEN :deadline ELSE NULL END,-1,UTC_TIMESTAMP(6)
            FROM fpw_arrival_rollout WHERE id=1",
            {p=planId,r=revision,deadline=deadline,zone=zone,source=source,actor=actor,armed=armed?1:0});
        sql("UPDATE fpw_arrival_watches SET current_revision=:r,updated_at_utc=UTC_TIMESTAMP(6) WHERE plan_id=:p",{p=planId,r=revision});
        addEvent(planId,revision,"REVISION_CREATED",observationClock(),source,actor);
    }

    // Called under the canonical save's plan lock after an intentional, authorized active-plan update.
    public struct function reviseDeadline(required numeric planId,required numeric actorUserId,required numeric expectedRevision,
            required string oldDeadlineUtc,required string newDeadlineUtc,string oldDeadlineZone="") {
        if (!installed()) throw(type="FPW.ArrivalUnavailable",message="Arrival deadline revision requires the verified arrival migration.");
        transaction {
            var plan=lockedPlan(planId);
            if (!plan.recordCount || actorUserId<=0 || compare(toString(plan.userId[1]),toString(actorUserId))!=0
                || plan.plan_status[1]!="ACTIVE" || !len(newDeadlineUtc) || compare(plan.deadline[1] ?: "",newDeadlineUtc)!=0)
                throw(type="FPW.ArrivalRevisionDenied",message="Arrival deadline revision is invalid.");
            var flags=eligibility(plan,"AUTHORIZE");
            var watch=lockedWatch(planId);
            var revision=watch.recordCount ? val(watch.current_revision[1]) : 0;
            if (expectedRevision!=revision || len(flags.terminal) || (watch.recordCount && (len(watch.terminal_reason[1] ?: "")
                || compare(watch.owner_id[1],plan.userId[1])!=0)))
                throw(type="FPW.ArrivalRevisionConflict",message="Arrival monitoring changed. Reload before revising the deadline.");
            if (!watch.recordCount) createWatch(planId,plan.userId[1]);
            if (!revision && len(oldDeadlineUtc)) {
                revision=1;
                appendRevision(planId,revision,oldDeadlineUtc,len(oldDeadlineZone) ? oldDeadlineZone : "UTC","PRE_REVISION_BASELINE",0,false);
            }
            if (revision) {
                var old=sql("SELECT DATE_FORMAT(deadline_utc,'%Y-%m-%d %H:%i:%s') AS deadline FROM fpw_arrival_revisions
                    WHERE plan_id=:p AND revision_no=:r FOR UPDATE",{p=planId,r=revision});
                if (!old.recordCount || compare(old.deadline[1],oldDeadlineUtc)!=0)
                    throw(type="FPW.ArrivalRevisionConflict",message="Stored deadline does not match its audited revision.");
                stopUnsubmittedMail(planId,revision,"SUPERSEDED");
                sql("UPDATE fpw_arrival_revisions SET state='SUPERSEDED',next_due_utc=NULL,ended_at_utc=UTC_TIMESTAMP(6),
                    suppression_reason='AUTHORIZED_REVISION' WHERE plan_id=:p AND revision_no=:r",{p=planId,r=revision});
                addEvent(planId,revision,"SUPERSEDED",observationClock(),"AUTHORIZED_REVISION",actorUserId);
            }
            appendRevision(planId,revision+1,newDeadlineUtc,plan.zone[1],"AUTHORIZED_REVISION",actorUserId,flags.eligible);
            return outcome("PENDING",revision+1);
        }
    }

    public struct function syncPlan(required numeric planId,required string reason,numeric actorUserId=0) {
        if (!installed()) return outcome("UNAVAILABLE");
        transaction {
            return synchronize(planId,reason,actorUserId,observationClock(),false);
        }
    }

    public struct function evaluatePlan(required numeric planId,string asOfUtc="") {
        if (!installed()) return outcome("UNAVAILABLE");
        transaction {
            var control=sql("SELECT mode FROM fpw_arrival_rollout WHERE id=1");
            if (!control.recordCount || control.mode[1]!="OBSERVE") return outcome("DISABLED");
            return synchronize(planId,"RECONCILE",0,observationClock(asOfUtc),true);
        }
    }

    private struct function synchronize(required numeric planId,required string reason,required numeric actor,
            required string atUtc,required boolean evaluate) {
        var plan=lockedPlan(planId);
        var watch=lockedWatch(planId);
        var revision=watch.recordCount ? val(watch.current_revision[1]) : 0;
        if (watch.recordCount && len(watch.terminal_reason[1] ?: "")) {
            return outcome(listFind("CLOSED,FINAL_ARRIVAL",watch.terminal_reason[1]) ? "RESOLVED" : "SUPPRESSED",revision);
        }
        if (!plan.recordCount) {
            if (watch.recordCount) return stopWatch(planId,revision,"SOURCE_MISSING",atUtc,actor);
            return outcome("INELIGIBLE");
        }
        if (watch.recordCount && compare(watch.owner_id[1],plan.userId[1])!=0)
            return stopWatch(planId,revision,"OWNER_CHANGED",atUtc,actor);
        var flags=eligibility(plan,reason);
        if (len(flags.terminal)) {
            if (!watch.recordCount) {
                if (reason!="ADMIN_STOP" && flags.terminal!="FINAL_ARRIVAL" && flags.terminal!="MONITOR_STOPPED") return outcome("INELIGIBLE");
                createWatch(planId,plan.userId[1]);
            }
            return stopWatch(planId,revision,flags.terminal,atUtc,actor);
        }
        if (!flags.eligible) {
            if (revision) sql("UPDATE fpw_arrival_revisions SET next_due_utc=NULL WHERE plan_id=:p AND revision_no=:r",{p=planId,r=revision});
            return outcome("INELIGIBLE",revision);
        }
        var deadline=plan.deadline[1] ?: "";
        if (!revision) {
            if (!watch.recordCount) createWatch(planId,plan.userId[1]);
            if (!len(deadline)) {
                if (!watch.recordCount) addEvent(planId,0,"BLOCKED",atUtc,"MISSING_DEADLINE",actor);
                return outcome("BLOCKED");
            }
            // A missing authoritative deadline must be set by an authorized save.
            if (watch.recordCount) return outcome("BLOCKED");
            revision=1;
            appendRevision(planId,revision,deadline,plan.zone[1],reason,actor,true);
        }
        var active=sql("SELECT state,historical_only,last_slot,DATE_FORMAT(deadline_utc,'%Y-%m-%d %H:%i:%s') AS deadline,
                TIMESTAMPDIFF(SECOND,deadline_utc,:atUtc) AS elapsed, :atUtc >= deadline_utc AS due_now
            FROM fpw_arrival_revisions WHERE plan_id=:p AND revision_no=:r FOR UPDATE",{p=planId,r=revision,atUtc=atUtc});
        if (!active.recordCount) throw(type="FPW.ArrivalIntegrity",message="Current arrival revision is missing.");
        if (compare(active.deadline[1],deadline)!=0) {
            if (active.state[1]!="BLOCKED") {
                stopUnsubmittedMail(planId,revision,"DEADLINE_DRIFT");
                sql("UPDATE fpw_arrival_revisions SET state='BLOCKED',next_due_utc=NULL,suppression_reason='DEADLINE_DRIFT'
                    WHERE plan_id=:p AND revision_no=:r",{p=planId,r=revision});
                addEvent(planId,revision,"BLOCKED",atUtc,"DEADLINE_DRIFT",actor);
            }
            return outcome("BLOCKED",revision);
        }
        var result=outcome(active.state[1],revision);
        result.historicalOnly=active.historical_only[1]==1;
        result.slot=val(active.last_slot[1]);
        if (active.state[1]=="BLOCKED") return result;
        var slot=int(val(active.elapsed[1])/3600);
        if (!evaluate || !active.due_now[1] || slot<=result.slot) {
            sql("UPDATE fpw_arrival_revisions SET next_due_utc=COALESCE(next_due_utc,
                    TIMESTAMPADD(HOUR,last_slot+1,deadline_utc)),
                    last_eval_utc=CASE WHEN :evaluated=1 AND (last_eval_utc IS NULL OR last_eval_utc<:t)
                        THEN :t ELSE last_eval_utc END
                WHERE plan_id=:p AND revision_no=:r",{p=planId,r=revision,t=atUtc,evaluated=evaluate?1:0});
            return result;
        }
        sql("UPDATE fpw_arrival_revisions SET state='OVERDUE',last_slot=:slot,last_eval_utc=:atUtc,
                next_due_utc=TIMESTAMPADD(HOUR,:nextHour,deadline_utc)
            WHERE plan_id=:p AND revision_no=:r",{p=planId,r=revision,slot=slot,atUtc=atUtc,nextHour=slot+1});
        addEvent(planId,revision,"OVERDUE_OBSERVED",atUtc,result.historicalOnly ? "HISTORICAL" : "OBSERVATION",0,slot,slot-result.slot-1);
        result.state="OVERDUE";
        result.slot=slot;
        return result;
    }

    private array function candidateGroups(required numeric batchSize,required string atUtc) {
        // Independent budgets keep onboarding or reconciliation from displacing due incidents.
        var due=sql("SELECT plan_id FROM fpw_arrival_revisions WHERE state IN ('PENDING','OVERDUE')
            AND next_due_utc<=:t ORDER BY next_due_utc,id LIMIT " & batchSize,{t=atUtc});
        var missing=sql("SELECT fm.float_plan_id AS plan_id FROM floatplan_monitoring fm JOIN floatplans p ON p.floatPlanId=fm.float_plan_id
            LEFT JOIN fpw_arrival_watches w ON w.plan_id=p.floatPlanId
            WHERE w.plan_id IS NULL AND fm.is_monitoring_enabled=1 AND fm.monitor_state<>'CLOSED' AND p.status='ACTIVE'
            AND p.userId=fm.user_id AND ((fm.monitoring_mode='basic' AND COALESCE(p.route_instance_id,0)=0)
            OR (fm.monitoring_mode='active_route' AND EXISTS (SELECT 1 FROM route_instances ri
                WHERE ri.id=p.route_instance_id AND ri.user_id=p.userId AND (ri.started_at IS NOT NULL
                OR EXISTS (SELECT 1 FROM route_instance_leg_progress g WHERE g.route_instance_id=ri.id AND g.user_id=p.userId
                    AND (g.leg_started_at IS NOT NULL OR g.completed_at IS NOT NULL OR g.status IN ('STARTED','IN_PROGRESS','COMPLETED')))))))
            ORDER BY p.floatPlanId LIMIT " & batchSize);
        var changed=sql("SELECT w.plan_id FROM fpw_arrival_watches w JOIN fpw_arrival_revisions r
                ON r.plan_id=w.plan_id AND r.revision_no=w.current_revision LEFT JOIN floatplans p ON p.floatPlanId=w.plan_id
            WHERE w.terminal_reason IS NULL AND r.state IN ('PENDING','OVERDUE') AND (p.floatPlanId IS NULL OR p.userId<>w.owner_id
                OR (p.closedAt IS NOT NULL OR p.expiredAt IS NOT NULL)
                OR EXISTS (SELECT 1 FROM floatplan_monitoring m WHERE m.float_plan_id=w.plan_id
                    AND (m.is_monitoring_enabled=0 OR m.monitor_state='CLOSED'))
                OR p.returnTimeUTC IS NULL OR p.returnTimeUTC<>r.deadline_utc OR p.status IN ('CLOSED','CANCELLED','CANCELED','EXPIRED'))
            ORDER BY w.plan_id LIMIT " & batchSize);
        return [due,missing,changed];
    }

    public struct function evaluateDue(numeric limit=100,string asOfUtc="") {
        var counts={success=true,mode="OFF",evaluated=0,errors=0};
        if (!installed()) return counts;
        var control=sql("SELECT mode FROM fpw_arrival_rollout WHERE id=1");
        if (!control.recordCount || control.mode[1]!="OBSERVE") return counts;
        counts.mode="OBSERVE";
        var atUtc=observationClock(asOfUtc);
        var batchSize=max(1,min(500,int(arguments.limit)));
        var visited={};
        for (var group in candidateGroups(batchSize,atUtc)) {
            for (var row in group) {
                if (structKeyExists(visited,toString(row.plan_id))) continue;
                visited[toString(row.plan_id)]=true;
                try {
                    evaluatePlan(row.plan_id,atUtc);
                    counts.evaluated++;
                } catch (any error) {
                    counts.errors++;
                    counts.success=false;
                    writeLog(file="fpw-monitor",type="error",text="Arrival observation failed for plan " & int(row.plan_id));
                }
            }
        }
        return counts;
    }
}
