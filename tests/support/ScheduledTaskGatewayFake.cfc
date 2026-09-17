component output="false" hint="In-memory scheduler adapter for service tests. Never calls cfschedule or runner endpoints." {
    variables.rows = [];
    variables.executed = [];
    variables.listCount = 0;
    variables.denyList = false;
    variables.denyExecute = false;

    public any function init(array rows=[], boolean denyList=false, boolean denyExecute=false) output="false" {
        variables.rows = duplicate(arguments.rows);
        variables.executed = [];
        variables.listCount = 0;
        variables.denyList = arguments.denyList;
        variables.denyExecute = arguments.denyExecute;
        return this;
    }

    public struct function defaultRow() output="false" {
        // Sanitized local CF2025 native LIST profile, with an approved harmless target.
        // Named intervals avoid depending on the numeric daily-window field omitted by native LIST.
        return {
            task="FPW_DEV_MANAGER_SPEC", group="FPW_DEV_TEST", mode="server",
            url="http://localhost:8500/fpw/tests/scheduled-task-target.cfm",
            startdate=dateAdd("d", 2, createDate(year(now()), month(now()), day(now()))),
            starttime=createTime(12, 0, 0), interval="daily", requesttimeout="17",
            enddate=dateAdd("d", 5, createDate(year(now()), month(now()), day(now()))),
            endtime=createTime(14, 30, 0), file="", path="", port="80", proxyport="80",
            proxyserver="", proxyuser="", proxypassword="", username="", password="",
            publish="NO", resolveurl="YES", overwrite="NO", onexception="", onmisfire="",
            eventhandler="", crontime="", repeat="-1", priority="7", exclude="",
            cluster="NO", clustered="NO", retrycount="2", chainedtask="NO", status="Running",
            oncomplete="", lastfire="", remainingcount="12"
        };
    }

    public query function listTasks(required string mode) output="false" {
        variables.listCount++;
        if (variables.denyList) {
            throw(type="Scheduler.Permission", message="SIMULATED_PRIVATE_DETAIL token=SIMULATED_SECRET unrelated-task");
        }
        var selected = [];
        var columns = {task=true, group=true, mode=true};
        for (var row in variables.rows) {
            if (row.mode NEQ arguments.mode) continue;
            arrayAppend(selected, row);
            for (var key in row) columns[key] = true;
        }
        var q = queryNew(structKeyList(columns));
        for (var row in selected) {
            queryAddRow(q);
            for (var key in row) querySetCell(q, key, row[key], q.recordCount);
        }
        return q;
    }

    public void function execute(required struct attributes) output="false" {
        arrayAppend(variables.executed, duplicate(arguments.attributes));
        if (variables.denyExecute) {
            throw(type="Scheduler.Permission", message="SIMULATED_PRIVATE_DETAIL token=SIMULATED_SECRET unrelated-task");
        }
        var selected = 0;
        for (var index = 1; index LTE arrayLen(variables.rows); index++) {
            var row = variables.rows[index];
            if (compare(row.task, arguments.attributes.task) EQ 0
                AND compare(row.group, arguments.attributes.group) EQ 0
                AND compare(row.mode, arguments.attributes.mode) EQ 0) {
                selected = index;
                break;
            }
        }
        if (arguments.attributes.action EQ "update") {
            if (!selected) {
                arrayAppend(variables.rows, defaultRow());
                selected = arrayLen(variables.rows);
            }
            for (var key in arguments.attributes) {
                if (!listFindNoCase("action,operation", key)) variables.rows[selected][key] = arguments.attributes[key];
            }
        } else if (!selected) {
            throw(type="Scheduler.Missing", message="SIMULATED_PRIVATE_DETAIL task missing");
        } else if (arguments.attributes.action EQ "pause") {
            variables.rows[selected].status = "Paused";
        } else if (arguments.attributes.action EQ "resume") {
            variables.rows[selected].status = "Running";
        } else if (arguments.attributes.action EQ "run") {
            // Record only acceptance. No HTTP request or real job runs.
            variables.rows[selected].lastfire = now();
        } else if (arguments.attributes.action EQ "delete") {
            arrayDeleteAt(variables.rows, selected);
        }
    }

    public array function getExecuted() output="false" {
        return duplicate(variables.executed);
    }

    public numeric function getListCount() output="false" {
        return variables.listCount;
    }

    public void function replaceRows(required array rows) output="false" {
        variables.rows = duplicate(arguments.rows);
    }
}
