component output="false" hint="Observe actual FPW scheduler fires without modifying any task or trigger." {
    // Install once per FPW application lifetime, and retry on the admin page if the scheduler started later.
    public boolean function ensureInstalled(boolean replace=false) {
        try {
            lock name="FPW.ScheduledTaskRunObserver" type="exclusive" timeout=5 {
                var config=new fpw.api.v1.AdminScheduledTaskConfig().load();
                if (!listFindNoCase("dev,production",config.environment ?: "") OR !len(config.baseUrl ?: "")) {
                    if (structKeyExists(application,"fpwTaskRunObserver")) {
                        application.fpwTaskRunObserver.detach();
                        structDelete(application,"fpwTaskRunObserver");
                    }
                    return false;
                }
                // The listener needs ownership rules, never scheduler credentials or the arrival recipient key.
                var rules={environment=config.environment,baseUrl=config.baseUrl,tasks=config.tasks ?: [],enabled=false};
                var signature=hash(serializeJSON(rules),"SHA-256");
                var replaceListener=arguments.replace OR !structKeyExists(application,"fpwTaskRunObserver")
                    OR signature NEQ (application.fpwTaskRunRules ?: "");
                if (replaceListener) {
                    var policy=new fpw.api.v1.AdminScheduledTaskService().init(config=rules);
                    var observer=new fpw.api.v1.ScheduledTaskRunHistory().forSite(rules.environment,policy);
                    if (!observer.attach(true)) return false;
                    if (structKeyExists(application,"fpwTaskRunObserver") AND application.fpwTaskRunObserver.getName()!=observer.getName())
                        application.fpwTaskRunObserver.detach();
                    application.fpwTaskRunObserver=observer;
                    application.fpwTaskRunRules=signature;
                    return true;
                }
                return application.fpwTaskRunObserver.attach();
            }
        } catch (any unavailable) {
            return false;
        }
    }

    public any function forSite(required string environment,required any policy) {
        variables.environment=lCase(arguments.environment);
        variables.policy=arguments.policy;
        variables.listener=createDynamicProxy(this,["org.quartz.JobListener"]);
        return this;
    }

    public boolean function attach(boolean replace=false) {
        // Observe already running scheduler instances. Never start, stop or reconfigure one.
        var engines=createObject("java","org.quartz.impl.SchedulerRepository").getInstance().lookupAll().iterator();
        var installed=false;
        while (engines.hasNext()) {
            var engine=engines.next();
            var manager=engine.getListenerManager();
            var nativeListeners=manager.getJobListeners().iterator();
            var isColdFusion=false;
            while (nativeListeners.hasNext()) {
                if (nativeListeners.next().getClass().getName()=="coldfusion.scheduling.mod.CronListener") {
                    isColdFusion=true;
                    break;
                }
            }
            if (!isColdFusion) continue;
            if (arguments.replace OR isNull(manager.getJobListener(getName()))) {
                // Adobe namespaces Quartz groups by application (SERVERSCHEDULETASK for server jobs).
                // Let Quartz discard other application groups before invoking any FPW code.
                var groups=createObject("java","org.quartz.impl.matchers.GroupMatcher");
                var match=createObject("java","org.quartz.impl.matchers.OrMatcher")
                    .or(groups.jobGroupStartsWith("SERVERSCHEDULETASK"),groups.jobGroupStartsWith("FPW"));
                manager.addJobListener(variables.listener,match);
                // An FPW runner can itself be the request that starts the application.
                var running=engine.getCurrentlyExecutingJobs().iterator();
                while (running.hasNext()) jobToBeExecuted(running.next());
            }
            installed=true;
        }
        return installed;
    }

    public string function getName() {
        return "FPW.ScheduledTaskRunHistory." & variables.environment;
    }

    public void function detach() {
        var engines=createObject("java","org.quartz.impl.SchedulerRepository").getInstance().lookupAll().iterator();
        while (engines.hasNext()) engines.next().getListenerManager().removeJobListener(getName());
    }

    public void function jobToBeExecuted(required any context) {
        try {
            var data=arguments.context.getMergedJobDataMap().get("metadata");
            if (isNull(data) OR data.getClass().getName() NEQ "coldfusion.scheduling.mod.ScheduleTagData") return;
            var scope=lCase(data.getMode());
            if (!listFind("application,server",scope)) return;
            var appName=scope=="application" ? toString(data.getAppname()) : "";
            if (scope=="application" AND compareNoCase(appName,"FPW")!=0) return;
            var row={mode=scope,application=appName,task=toString(data.getTask()),group=toString(data.getGroup()),
                url=toString(data.getUrl() ?: ""),port=toString(data.getPort() ?: "")};
            if (!variables.policy.ownsObservedExecution(row)) return;
            recordStart(variables.environment,row,arguments.context.getFireTime());
        } catch (any historyFailure) {
            // Observation must never veto, retry, or prevent the existing job.
            try { writeLog(file="fpw-scheduler-history",type="warning",
                text="Scheduled task execution history could not be recorded (" &
                    reReplace(left(historyFailure.type,80),"[^A-Za-z0-9_.-]","","all") & ", line " &
                    (arrayLen(historyFailure.tagContext) ? val(historyFailure.tagContext[1].line) : 0) & ")."); }
            catch (any logUnavailable) {}
        }
    }

    public void function jobWasExecuted(required any context,any failure) {}
    public void function jobExecutionVetoed(required any context) {}

    private struct function identityParams(required string environment,required struct row) {
        return {env=environment, scope=lCase(row.mode), app=row.mode=="application" ? row.application : "",
            grp=row.group, task=row.task};
    }

    // Bind UTC text to DATETIME(3) so CF/JDBC/SQL session timezones cannot reinterpret it.
    private string function utcStamp(required date instant) {
        return dateTimeFormat(arguments.instant,"yyyy-mm-dd HH:nn:ss","UTC")
            & "." & numberFormat(datePart("l",arguments.instant),"000");
    }

    public void function recordStart(required string environment, required struct row, required date startedAt) {
        var p=identityParams(arguments.environment,arguments.row);
        p.stamp={value=utcStamp(arguments.startedAt),cfsqltype="cf_sql_varchar"};
        queryExecute("INSERT INTO fpw_scheduled_task_last_run
            (environment,task_scope,application_name,task_group,task_name,last_run_utc)
            VALUES (:env,:scope,:app,:grp,:task,:stamp)
            ON DUPLICATE KEY UPDATE last_run_utc=CASE
              WHEN (valid_from_utc IS NULL OR CAST(:stamp AS DATETIME(3)) >= valid_from_utc)
               AND (last_run_utc IS NULL OR CAST(:stamp AS DATETIME(3)) > last_run_utc)
              THEN :stamp ELSE last_run_utc END",p,{datasource="fpw",timeout=2});
    }

    public void function resetForCreate(required string environment, required struct row, required date createdAt) {
        // On a successful create, retain only starts at or after this incarnation's boundary.
        var p=identityParams(arguments.environment,arguments.row);
        p.cutoff={value=utcStamp(arguments.createdAt),cfsqltype="cf_sql_varchar"};
        queryExecute("INSERT INTO fpw_scheduled_task_last_run
            (environment,task_scope,application_name,task_group,task_name,valid_from_utc)
            VALUES (:env,:scope,:app,:grp,:task,:cutoff)
            ON DUPLICATE KEY UPDATE last_run_utc=CASE WHEN last_run_utc < CAST(:cutoff AS DATETIME(3)) THEN NULL ELSE last_run_utc END,
              valid_from_utc=CASE WHEN valid_from_utc IS NULL OR valid_from_utc < CAST(:cutoff AS DATETIME(3))
                                  THEN :cutoff ELSE valid_from_utc END",p,{datasource="fpw",timeout=2});
    }

    public struct function latest(required string environment) {
        var result={};
        var q=queryExecute("SELECT task_scope,application_name,task_group,task_name,
            CONCAT(LEFT(DATE_FORMAT(last_run_utc,'%Y-%m-%dT%H:%i:%s.%f'),23),'Z') AS started_at
            FROM fpw_scheduled_task_last_run WHERE environment=:env AND last_run_utc>'1970-01-01 00:00:00'",
            {env=arguments.environment},{datasource="fpw"});
        for (var row in q) {
            result[lCase(row.task_scope & "|" & row.application_name & "|" & row.task_group & "|" & row.task_name)]=row.started_at;
        }
        return result;
    }
}
