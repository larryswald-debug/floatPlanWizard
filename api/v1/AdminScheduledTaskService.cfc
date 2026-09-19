component output="false" {
    variables.config = {};
    variables.gateway = "";
    variables.registry = [];
    variables.engine = "";
    variables.configuredRegistry = [];
    variables.catalog = {};
    variables.catalogLabels = {};
    variables.catalogAvailable = false;

    public any function init(struct config={}, any gateway) output="false" {
        variables.registry = [];
        variables.config = structIsEmpty(arguments.config) ? new fpw.api.v1.AdminScheduledTaskConfig().load() : duplicate(arguments.config);
        variables.gateway = structKeyExists(arguments, "gateway") ? arguments.gateway : new fpw.api.v1.AdminScheduledTaskGateway();
        variables.engine = structKeyExists(server, "coldfusion") ? toString(server.coldfusion.productVersion) : "Unknown";
        refreshCatalog();
        validateConfig();
        variables.configuredRegistry = duplicate(variables.registry);
        return this;
    }

    private void function refreshCatalog() output="false" {
        // Only the deployed folder defines new approvals. No request can choose a directory or URL.
        variables.catalog = {"monitor-legacy"="/api/v1/monitor.cfc", "development-test"="/tests/scheduled-task-target.cfm"};
        variables.catalogLabels = {"development-test"="Development scheduler check (harmless)"};
        variables.catalogAvailable = false;
        var aliases = {"run-monitor.cfm"="monitor", "run-departure-reminders.cfm"="departure-reminders",
            "run-single-trip-expiration.cfm"="single-trip-expiration", "run-inactive-member-recovery.cfm"="inactive-member-recovery"};
        var labels = {"monitor"="Float plan monitor", "departure-reminders"="Departure reminders",
            "single-trip-expiration"="Single-trip expiration", "inactive-member-recovery"="Inactive member recovery (new schedules use dry run)"};
        try {
            var files = directoryList(getDirectoryFromPath(getCurrentTemplatePath()) & "../../app/scheduled", false, "query", "", "name", "file");
            for (var index=1; index LTE files.recordCount; index++) {
                var fileName = toString(files.name[index]);
                if (left(fileName,1) EQ "." OR compareNoCase(fileName,"Application.cfm") EQ 0
                    OR !reFindNoCase("\.cfm$",fileName) OR reFind("[\x00-\x1f/\\]",fileName)) continue;
                // Native directory metadata identifies links without Java/file-system workarounds.
                if (listFindNoCase(files.columnList,"link") AND !isNull(files.link[index])
                    AND len(trim(toString(files.link[index]))) AND !listFindNoCase("false,no,0",toString(files.link[index]))) continue;
                var endpointId = "script-" & lCase(left(hash(fileName,"SHA-256"),32));
                for (var knownFile in aliases) {
                    if (compare(fileName,knownFile) EQ 0) { endpointId = aliases[knownFile]; break; }
                }
                var urlName = reFind("^[A-Za-z0-9_.-]+$",fileName) ? fileName : replace(urlEncodedFormat(fileName),"+","%20","all");
                if (structKeyExists(variables.catalog,endpointId)) fail("The scheduled script folder contains ambiguous filenames.");
                variables.catalog[endpointId] = "/app/scheduled/" & urlName;
                variables.catalogLabels[endpointId] = structKeyExists(labels,endpointId) ? labels[endpointId] : fileName;
            }
            variables.catalogAvailable = true;
        } catch (any ignored) {
            // Never keep a partially discovered catalog or reveal a physical path/exception.
            variables.catalog = {"monitor-legacy"="/api/v1/monitor.cfc", "development-test"="/tests/scheduled-task-target.cfm"};
        }
    }

    private boolean function usesMonitorToken(required string endpointId) output="false" {
        return listFindNoCase("monitor,monitor-legacy,departure-reminders,single-trip-expiration",arguments.endpointId) GT 0;
    }

    private void function validateParameters(required struct entry) output="false" {
        if (!isStruct(arguments.entry.parameters)) fail("Invalid configured runner parameters.");
        for (var key in arguments.entry.parameters) {
            var parameterValue = value(arguments.entry.parameters,key);
            if (usesMonitorToken(arguments.entry.endpointId) AND key EQ "limit"
                AND reFind("^[1-9][0-9]{0,2}$",parameterValue) AND val(parameterValue) LTE 500) continue;
            if (arguments.entry.endpointId EQ "inactive-member-recovery") {
                if (key EQ "batchSize" AND reFind("^[1-9][0-9]{0,2}$",parameterValue) AND val(parameterValue) LTE 100) continue;
                if (key EQ "dryRun" AND listFindNoCase("true,false",parameterValue)) continue;
            }
            fail("Unapproved configured runner parameter.");
        }
    }

    private void function requireAdmin(boolean mutation=false) output="false" {
        var user = structKeyExists(session, "user") AND isStruct(session.user) ? session.user : {};
        var authService = new fpw.api.v1.AdminAuthorizationService().init("fpw");
        var auth = authService.authorizeCurrentSession(user);
        if (!auth.authorized) fail("Administrative access is required.");
        if (arguments.mutation AND (cgi.request_method NEQ "POST" OR !authService.isValidCsrfToken(authService.resolveRequestCsrfToken()))) {
            fail("An administrative POST with a valid request token is required.");
        }
    }

    private void function fail(required string message) output="false" {
        throw(type="FPWScheduler.Validation", message=arguments.message);
    }

    private string function value(required struct source, required string key, string fallback="") output="false" {
        if (!structKeyExists(arguments.source, arguments.key) OR isNull(arguments.source[arguments.key])) return arguments.fallback;
        if (!isSimpleValue(arguments.source[arguments.key])) fail("Invalid scheduler input.");
        return trim(toString(arguments.source[arguments.key]));
    }

    private boolean function flag(required struct source, required string key) output="false" {
        return structKeyExists(arguments.source, arguments.key) AND serializeJSON(arguments.source[arguments.key]) EQ "true";
    }

    private void function validateConfig() output="false" {
        var appEnv = structKeyExists(application, "env") ? lCase(trim(toString(application.env))) : "";
        var env = lCase(value(variables.config, "environment"));
        var seen = {};
        var identities = {};
        var entry = {};
        var key = "";
        if (!structKeyExists(variables.config, "tasks") OR !isArray(variables.config.tasks)) fail("The scheduler identity registry is invalid.");
        if (!len(env) AND !arrayLen(variables.config.tasks) AND !flag(variables.config, "enabled")) env = "unconfigured";
        if (!listFindNoCase("dev,production,unconfigured", env) OR (len(appEnv) AND env NEQ "unconfigured" AND env NEQ appEnv)) fail("Scheduler configuration must match the application environment.");
        if (env EQ "unconfigured" AND (arrayLen(variables.config.tasks) OR flag(variables.config, "enabled"))) fail("An explicit scheduler environment is required.");
        if (env EQ "dev" AND (compareNoCase(toString(server.coldfusion.productLevel), "Developer") NEQ 0
            OR val(cgi.server_port) NEQ 8500 OR !reFindNoCase("^(localhost|127\.0\.0\.1)(:8500)?$", cgi.http_host))) fail("Development scheduler configuration is restricted to the local Developer runtime.");
        variables.config.environment = env;
        variables.config.baseUrl = value(variables.config, "baseUrl");
        variables.config.schedulerTimezone = value(variables.config, "schedulerTimezone");
        variables.config.verifiedEngineVersion = value(variables.config, "verifiedEngineVersion");
        if (env NEQ "unconfigured") {
            if (env EQ "production" AND !reFind("^https://(www\.)?floatplanwizard\.com$", variables.config.baseUrl)) fail("The production scheduler origin is not approved.");
            if (env EQ "dev" AND !reFind("^http://(localhost|127\.0\.0\.1):8500/fpw$", variables.config.baseUrl)) fail("The development scheduler origin is not approved.");
        }
        for (entry in variables.config.tasks) {
            if (!isStruct(entry)) fail("The scheduler identity registry is invalid.");
            for (key in ["id", "name", "mode", "group", "application", "endpointId"]) entry[key] = value(entry, key);
            if (!reFind("^[a-z0-9-]{1,50}$", entry.id) OR !reFind("^[A-Za-z0-9_ .-]{1,60}$", entry.name)
                OR !reFind("^[A-Za-z0-9_ .-]{0,40}$", entry.group) OR !listFindNoCase("server,application", entry.mode)) fail("A registered task identity is invalid.");
            entry.mode = lCase(entry.mode);
            if ((entry.mode EQ "application" AND entry.application NEQ "FPW") OR (entry.mode EQ "server" AND len(entry.application))) fail("A registered task application scope is invalid.");
            if (!reFind("^[a-z0-9-]{1,50}$",entry.endpointId) OR (entry.endpointId EQ "development-test" AND env NEQ "dev")) fail("A registered endpoint is not approved.");
            if (flag(entry, "allowCreate") AND !reFind(env EQ "production" ? "^FPW_PROD_" : "^FPW_DEV_", entry.name)) fail("New tasks require the environment-specific prefix.");
            if (flag(entry, "allowCreate") AND entry.endpointId EQ "monitor-legacy") fail("Legacy endpoints may only be registered for existing tasks.");
            key = lCase(entry.mode & "|" & entry.application & "|" & entry.group & "|" & entry.name);
            if (structKeyExists(seen, entry.id) OR structKeyExists(identities, key)) fail("Duplicate registered scheduler identity.");
            seen[entry.id] = true;
            identities[key] = true;
            entry.parameters = structKeyExists(entry, "parameters") ? entry.parameters : {};
            validateParameters(entry);
            arrayAppend(variables.registry, entry);
        }
    }

    private boolean function mutationsEnabled() output="false" {
        return variables.catalogAvailable AND flag(variables.config, "enabled") AND len(variables.config.schedulerTimezone)
            AND variables.config.verifiedEngineVersion EQ variables.engine;
    }

    private string function targetUrl(required struct entry) output="false" {
        if (!structKeyExists(variables.catalog,arguments.entry.endpointId)) fail("The selected script is no longer available in the approved folder.");
        validateParameters(arguments.entry);
        var target = variables.config.baseUrl & variables.catalog[arguments.entry.endpointId];
        var token = "";
        if (usesMonitorToken(arguments.entry.endpointId)) {
            token = structKeyExists(application,"monitorToken") AND isSimpleValue(application.monitorToken) ? trim(toString(application.monitorToken)) : "";
        } else if (arguments.entry.endpointId EQ "inactive-member-recovery") {
            try {
                var recoverySettings = createObject("component","fpw.api.v1.InactiveMemberRecoveryService").getRunnerSettings();
                token = value(recoverySettings,"token");
            } catch (any ignored) {} // Missing runner configuration never revokes folder approval.
        } else {
            // Future folder scripts run at their own URL. Never guess or disclose a runner secret.
            return target;
        }
        if (arguments.entry.endpointId EQ "monitor-legacy" AND !len(token)) fail("The legacy runner configuration is unavailable.");
        // Reuse configured credentials when present; they are not an approval requirement.
        var queryParts = [];
        if (len(token)) arrayAppend(queryParts, "token=" & urlEncodedFormat(token));
        if (arguments.entry.endpointId EQ "monitor-legacy") arrayAppend(queryParts, "method=runMonitoringEvaluator");
        for (var key in listToArray("limit,batchSize,dryRun")) {
            if (structKeyExists(arguments.entry.parameters,key)) arrayAppend(queryParts, key & "=" & urlEncodedFormat(value(arguments.entry.parameters,key)));
        }
        if (arrayLen(queryParts)) target &= "?" & arrayToList(queryParts, "&");
        return target;
    }

    private boolean function approvedBinding(required struct row, required struct entry) output="false" {
        try { return approvedTarget(value(arguments.row,"url"),targetUrl(arguments.entry),
            listFindNoCase("monitor,departure-reminders,single-trip-expiration,inactive-member-recovery", arguments.entry.endpointId) GT 0); }
        catch (any ignored) { return false; }
    }

    // Verify the native endpoint and allowed parameters. Folder approval does not depend on a runner token.
    private boolean function approvedTarget(required string actual, required string expected, boolean optionalRunnerToken=false) output="false" {
        var leftParts = listToArray(arguments.actual, "?", true);
        var rightParts = listToArray(arguments.expected, "?", true);
        var leftQuery = {};
        var rightQuery = {};
        try {
            if (!arrayLen(leftParts) OR !arrayLen(rightParts) OR arrayLen(leftParts) GT 2 OR arrayLen(rightParts) GT 2
                OR compare(leftParts[1], rightParts[1]) NEQ 0) return false;
            if (arrayLen(leftParts) EQ 2) leftQuery = parseQuery(leftParts[2]);
            if (arrayLen(rightParts) EQ 2) rightQuery = parseQuery(rightParts[2]);
            if (arguments.optionalRunnerToken) {
                structDelete(leftQuery, "token");
                structDelete(rightQuery, "token");
            }
            if (structCount(leftQuery) NEQ structCount(rightQuery)) return false;
            for (var key in rightQuery) if (!structKeyExists(leftQuery, key) OR compare(leftQuery[key], rightQuery[key]) NEQ 0) return false;
            return true;
        } catch (any ignored) { return false; }
    }

    private struct function parseQuery(required string queryString) output="false" {
        var parsed = {};
        var equalsAt = 0;
        var key = "";
        for (var pair in listToArray(arguments.queryString, "&", true)) {
            equalsAt = find("=", pair);
            if (!equalsAt) fail("Invalid target.");
            key = urlDecode(left(pair, equalsAt - 1));
            if (structKeyExists(parsed, key)) fail("Invalid target.");
            parsed[key] = urlDecode(mid(pair, equalsAt + 1, len(pair)));
        }
        return parsed;
    }

    private string function identityKey(required struct entry) output="false" {
        return lCase(arguments.entry.mode & "|" & arguments.entry.group & "|" & arguments.entry.name);
    }

    // Build an exact identity allowlist from server evidence, never a submitted name/prefix.
    // Full origin, folder path and approved parameters must match before discovery.
    private struct function discoverEntry(required struct row) output="false" {
        var entry = {name=value(arguments.row, "task"), group=value(arguments.row, "group"),
            mode=lCase(value(arguments.row, "mode")), application="", parameters={}, allowCreate=false};
        var actual = value(arguments.row, "url");
        var parts = listToArray(actual, "?", true);
        var queryValues = {};
        if (variables.config.environment EQ "unconfigured" OR !reFind("^[A-Za-z0-9_ .-]{1,60}$", entry.name)
            OR !reFind("^[A-Za-z0-9_ .-]{0,40}$", entry.group)) return {};
        if (entry.mode EQ "application") entry.application = "FPW";
        for (var endpointId in variables.catalog) {
            if (endpointId EQ "development-test" AND variables.config.environment NEQ "dev") continue;
            if (!arrayLen(parts) OR compare(parts[1], variables.config.baseUrl & variables.catalog[endpointId]) NEQ 0) continue;
            entry.endpointId = endpointId;
            try {
                if (arrayLen(parts) EQ 2) queryValues = parseQuery(parts[2]);
                for (var parameter in queryValues) {
                    if (!listFindNoCase("token,method",parameter)) entry.parameters[parameter] = queryValues[parameter];
                }
                validateParameters(entry);
                if (!approvedBinding(arguments.row, entry)) return {};
                entry.id = "discovered-" & lCase(left(hash(variables.config.environment & "|" & variables.config.baseUrl & "|"
                    & entry.mode & "|" & entry.group & "|" & entry.name & "|" & endpointId, "SHA-256"), 32));
                return entry;
            } catch (any ignored) { return {}; }
        }
        return {};
    }

    private struct function readState() output="false" {
        var state = {scopes={}, rows={}, identities={}, conflicts={}, seconds={}, diagnostics=[]};
        var q = queryNew("");
        var row = {};
        var key = "";
        refreshCatalog();
        variables.registry = [];
        if (!variables.catalogAvailable) arrayAppend(state.diagnostics,"The scheduled script folder could not be listed. Script approval and scheduler changes are unavailable.");
        for (var configured in variables.configuredRegistry) {
            // Keep unavailable bindings as identity reservations; never adopt them through a different script.
            arrayAppend(variables.registry,duplicate(configured));
            if (!structKeyExists(variables.catalog,configured.endpointId)) arrayAppend(state.diagnostics,"A configured script is no longer available in the scheduled folder; its tasks cannot be managed.");
        }
        for (var mode in ["server", "application"]) {
            state.scopes[mode] = false;
            state.seconds[mode] = false;
            state.rows[mode] = [];
            try {
                if (mode EQ "application" AND getApplicationMetadata().name NEQ "FPW") fail("Application scheduler scope is not FPW.");
                q = variables.gateway.listTasks(mode);
                if (!listFindNoCase(q.columnList, "task") OR !listFindNoCase(q.columnList, "group") OR !listFindNoCase(q.columnList, "mode")) {
                    arrayAppend(state.diagnostics, mode & ": listing lacks fields required to prove task identity; this scope is read-only.");
                    continue;
                }
                state.scopes[mode] = true;
                state.seconds[mode] = listFindNoCase(replace(q.columnList, "_", "", "all"), "isdaily") GT 0 OR variables.engine EQ "2025,0,06,331564";
                arrayAppend(state.diagnostics, mode & ": native list is available.");
                arrayAppend(state.diagnostics, mode & ": " & (state.seconds[mode] ? "numeric intervals have a supported preservation profile." : "numeric intervals are read-only because the daily-window field is unavailable."));
                for (var index = 1; index LTE q.recordCount; index++) {
                    if (compareNoCase(toString(q.mode[index]), mode) NEQ 0) continue;
                    // Retain only identity keys for collision checks, including unrelated tasks.
                    key = identityKey({name=toString(q.task[index]),group=toString(q.group[index]),mode=mode});
                    state.identities[key] = structKeyExists(state.identities, key) ? state.identities[key] + 1 : 1;
                    var matched = {};
                    var configuredIdentity = false;
                    for (var entry in variables.registry) {
                        if (identityKey(entry) NEQ key) continue;
                        configuredIdentity = true;
                        if (compare(toString(q.task[index]), entry.name) NEQ 0 OR compare(toString(q.group[index]), entry.group) NEQ 0) {
                            state.conflicts[entry.id] = true;
                        } else matched = entry;
                        break;
                    }
                    row = {};
                    for (var column in listToArray(q.columnList)) {
                        key = lCase(replace(column, "_", "", "all"));
                        if (!isNull(q[column][index])) row[key] = q[column][index];
                    }
                    if (mode EQ "application" AND ((structKeyExists(row, "application") AND value(row, "application") NEQ "FPW")
                        OR (structKeyExists(row, "applicationname") AND value(row, "applicationname") NEQ "FPW"))) continue;
                    if (structIsEmpty(matched) AND !configuredIdentity) {
                        matched = discoverEntry(row);
                        if (!structIsEmpty(matched)) arrayAppend(variables.registry, matched);
                    }
                    if (structIsEmpty(matched) OR !structKeyExists(variables.catalog,matched.endpointId)) continue;
                    if (!structKeyExists(row, "requesttimeout") AND structKeyExists(row, "timeout")) row.requesttimeout = row.timeout;
                    row.registryId = matched.id;
                    arrayAppend(state.rows[mode], row);
                }
            } catch (any ignored) {
                state.scopes[mode] = false;
                state.rows[mode] = [];
                arrayAppend(state.diagnostics, mode & ": native list is unavailable or denied. No tasks in this scope can be changed.");
            }
        }
        return state;
    }

    private struct function findRow(required struct state, required struct entry) output="false" {
        var found = {};
        if (structKeyExists(arguments.state.identities, identityKey(arguments.entry)) AND arguments.state.identities[identityKey(arguments.entry)] GT 1) fail("The scheduler returned an ambiguous task identity. No action can be taken until its exact identity is verified.");
        if (structKeyExists(arguments.state.conflicts, arguments.entry.id)) fail("A registered identity conflicts with the scheduler. Verify exact name and group capitalization before continuing.");
        for (var row in arguments.state.rows[arguments.entry.mode]) {
            if (row.registryId EQ arguments.entry.id) {
                if (!structIsEmpty(found)) fail("The scheduler returned an ambiguous task identity.");
                found = row;
            }
        }
        return found;
    }

    private string function revision(required struct row) output="false" {
        var parts = [];
        var keys = structKeyArray(arguments.row);
        arraySort(keys, "textnocase");
        for (var key in keys) {
            if (listFindNoCase("lastfire,remainingcount", key)) continue;
            arrayAppend(parts, [key, arguments.row[key]]);
        }
        return hash(serializeJSON(parts), "SHA-256");
    }

    private string function pausedStatus(required struct row) output="false" {
        var status = lCase(value(arguments.row, "status"));
        if (listFindNoCase("paused,paused_blocked", status)) return "Yes";
        if (listFindNoCase("normal,waiting,blocked,running,complete", status)) return "No";
        return "Unavailable";
    }

    private string function unsafeReason(required struct row, required struct entry) output="false" {
        if (!approvedBinding(arguments.row,arguments.entry)) return "The target or parameters do not match an approved script.";
        // Production URLs use HTTPS's default port. Do not turn an ambiguous legacy port
        // into an explicit override during UPDATE. Development URLs carry the verified :8500.
        if (variables.config.environment EQ "production" AND value(arguments.row, "port") NEQ "443") return "The scheduler did not prove the approved HTTPS port. This task is read-only until its transport settings are verified.";
        if (pausedStatus(arguments.row) EQ "Unavailable") return "The scheduler did not return a recognized pause status.";
        if (!listFindNoCase("once,daily,weekly,monthly", value(arguments.row, "interval")) AND !reFind("^[0-9]+$", value(arguments.row, "interval"))) return "This schedule type cannot be safely represented by this manager.";
        // No event handler, chain, cron, finite repeat, cluster or hidden authentication is simplified.
        if (!basicCron(arguments.row)) return "This cron expression cannot be safely represented by the frequency form.";
        for (var key in ["eventhandler", "oncomplete", "exclude", "username", "password", "proxyserver", "proxyuser", "proxypassword"]) {
            if (len(value(arguments.row, key))) return "This schedule has advanced settings or credentials that cannot be safely round-tripped.";
        }
        if (listFindNoCase("true,yes,1", value(arguments.row, "clustered")) OR listFindNoCase("true,yes,1", value(arguments.row, "cluster"))
            OR listFindNoCase("true,yes,1", value(arguments.row, "chainedtask"))
            OR (len(value(arguments.row, "repeat")) AND val(arguments.row.repeat) GTE 0
                AND !(compareNoCase(value(arguments.row, "interval"), "once") EQ 0 AND val(arguments.row.repeat) EQ 0))) return "Clustered, chained and finite-repeat schedules are read-only.";
        return "";
    }

    private boolean function basicCron(required struct row) output="false" {
        var cron = reReplace(value(arguments.row, "crontime"), "\s+", " ", "all");
        var interval = lCase(value(arguments.row, "interval"));
        var expected = "";
        if (!len(cron)) return true;
        if (!listFindNoCase("daily,weekly,monthly", interval) OR !isDate(value(arguments.row, "starttime")) OR !isDate(value(arguments.row, "startdate"))) return false;
        expected = second(arguments.row.starttime) & " " & minute(arguments.row.starttime) & " " & hour(arguments.row.starttime) & " ";
        if (interval EQ "daily") expected &= "* * ?";
        if (interval EQ "weekly") expected &= "? * " & dayOfWeek(arguments.row.startdate);
        if (interval EQ "monthly") expected &= day(arguments.row.startdate) & " * ?";
        return compare(cron, expected) EQ 0;
    }

    private struct function present(required struct row, required struct entry) output="false" {
        var interval = lCase(value(arguments.row, "interval"));
        var item = {id=arguments.entry.id, name=arguments.entry.name, mode=arguments.entry.mode, group=arguments.entry.group,
            endpointId=arguments.entry.endpointId, endpoint=variables.catalog[arguments.entry.endpointId], endpointUrl=variables.config.baseUrl & variables.catalog[arguments.entry.endpointId], frequency="Unavailable",
            endDate="", endTime="", repeat=value(arguments.row, "repeat"), intervalHours="0", intervalMinutes="0", intervalSeconds="0",
            startDate="", startTime="", timeout=value(arguments.row, "requesttimeout", value(arguments.row, "timeout", "Unavailable")),
            paused=pausedStatus(arguments.row), editable=false, actionable=false, reason="", revision=revision(arguments.row),
            scheduleType="", seconds="", secondsSupported=structKeyExists(arguments.row, "isdaily") OR variables.engine EQ "2025,0,06,331564"};
        if (isDate(value(arguments.row, "startdate"))) item.startDate = dateFormat(arguments.row.startdate, "yyyy-mm-dd");
        if (isDate(value(arguments.row, "starttime"))) item.startTime = timeFormat(arguments.row.starttime, "HH:nn:ss");
        if (isDate(value(arguments.row, "enddate"))) item.endDate = dateFormat(arguments.row.enddate, "yyyy-mm-dd");
        if (isDate(value(arguments.row, "endtime"))) item.endTime = timeFormat(arguments.row.endtime, "HH:nn:ss");
        if (reFind("^[0-9]+$", interval)) {
            item.intervalHours = int(val(interval) / 3600);
            item.intervalMinutes = int((val(interval) MOD 3600) / 60);
            item.intervalSeconds = val(interval) MOD 60;
            item.frequency = "Every " & interval & " seconds";
            item.scheduleType = "seconds";
            item.seconds = interval;
        } else if (listFindNoCase("once,daily,weekly,monthly", interval)) {
            item.frequency = interval;
            item.scheduleType = interval;
        } else item.frequency = "Advanced schedule";
        var ownershipMatches = approvedBinding(arguments.row,arguments.entry);
        item.reason = unsafeReason(arguments.row, arguments.entry);
        if (!len(item.reason)) item.reason = editReason(arguments.row);
        item.actionable = mutationsEnabled() AND ownershipMatches;
        item.runUnavailableReason = runReason(arguments.row);
        item.canRun = item.actionable AND !len(item.runUnavailableReason);
        item.editable = item.actionable AND !len(item.reason);
        if (item.editable AND item.paused EQ "Yes" AND !flag(variables.config, "pausedUpdateVerified")) {
            item.editable = false;
            item.reason = "Editing while paused is unavailable until UPDATE pause preservation is verified for this environment. Native Resume remains available.";
        }
        if (!mutationsEnabled() AND !len(item.reason)) item.reason = "Read-only until environment permissions, engine version and scheduler timezone are verified in configuration.";
        return item;
    }

    private string function runReason(required struct row) output="false" {
        for (var key in ["eventhandler", "oncomplete", "username", "password", "proxyserver", "proxyuser", "proxypassword"]) {
            if (!structKeyExists(arguments.row, key) OR len(value(arguments.row, key))) return "Run is unavailable because execution settings cannot be safely verified.";
        }
        if (!structKeyExists(arguments.row, "chainedtask") OR listFindNoCase("true,yes,1", value(arguments.row, "chainedtask"))) return "Run is unavailable for chained or unverified execution settings.";
        if (variables.config.environment EQ "production" AND value(arguments.row, "port") NEQ "443") return "Run is unavailable until the HTTPS transport settings are verified.";
        return "";
    }

    private string function editReason(required struct row) output="false" {
        var known = "registryid,task,group,mode,application,applicationname,url,startdate,starttime,interval,requesttimeout,timeout,enddate,endtime,file,path,port,proxyport,proxyserver,proxyuser,proxypassword,publish,resolveurl,overwrite,oncomplete,onexception,onmisfire,eventhandler,crontime,repeat,priority,exclude,cluster,clustered,retrycount,username,password,chainedtask,status,lastfire,remainingcount,isdaily";
        for (var key in arguments.row) {
            if (!listFindNoCase(known, key)) return "The scheduler returned an unrecognized attribute; this schedule is read-only until its preservation is verified.";
        }
        // Local 2025 U6 ScheduleTag has no isDaily setter/field: the old attribute is ignored.
        // CF2023 is NOT assumed equivalent. Without that flag, its numeric tasks stay read-only.
        if (reFind("^[0-9]+$", value(arguments.row, "interval")) AND !structKeyExists(arguments.row, "isdaily") AND variables.engine NEQ "2025,0,06,331564") return "The scheduler does not return the daily-window setting for numeric intervals. This schedule is read-only to avoid changing its timing.";
        // Exact list profile tested with native UPDATE. Missing fields never acquire guessed defaults.
        for (var key in listToArray("startdate,starttime,interval,requesttimeout,enddate,endtime,file,path,port,proxyport,proxyserver,proxyuser,publish,resolveurl,overwrite,onexception,onmisfire,eventhandler,crontime,repeat,priority,exclude,clustered,retrycount,username,chainedtask,status")) {
            if (!structKeyExists(arguments.row, key)) return "Required scheduler attributes were not returned; editing could discard settings.";
        }
        if (!isDate(arguments.row.startdate) OR !isDate(arguments.row.starttime)) return "The existing start date or time cannot be safely represented.";
        return "";
    }

    public struct function getView() output="false" {
        requireAdmin();
        var state = readState();
        var info = getTimeZoneInfo();
        var view = {available=state.scopes.server OR state.scopes.application, message="", environment=variables.config.environment,
            engine=variables.engine, timezone="Unverified scheduler timezone. ColdFusion request timezone: " & value(info, "timezone", "Unavailable") & " (current offset " & dateTimeFormat(now(), "Z") & ").",
            timezoneId=variables.config.schedulerTimezone, schedulerClock="",
            readOnly=!mutationsEnabled(), diagnostics=state.diagnostics, tasks=[], createOptions=[], endpoints=[], scopes=[], canCreate=false,
            createDefaults={namePrefix=variables.config.environment EQ "production" ? "FPW_PROD_" : "FPW_DEV_", mode="server",
                group=variables.config.environment EQ "production" ? "FPW_PROD" : "FPW_DEV"}};
        if (len(variables.config.schedulerTimezone)) {
            view.timezone = "Scheduler timezone (verified in environment configuration): " & variables.config.schedulerTimezone & ". ColdFusion request clock: " & dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss Z") & ".";
            view.schedulerClock = dateTimeFormat(now(), "yyyy-mm-dd h:nn:ss tt", variables.config.schedulerTimezone);
        }
        for (var mode in ["server", "application"]) {
            if (state.scopes[mode]) arrayAppend(view.scopes, {id=mode,label=mode EQ "server" ? "Server" : "FPW application",secondsSupported=state.seconds[mode]});
        }
        var endpointIds = structKeyArray(variables.catalog);
        arraySort(endpointIds,"textnocase");
        for (var endpointId in endpointIds) {
            if (endpointId EQ "monitor-legacy" OR (endpointId EQ "development-test" AND variables.config.environment NEQ "dev")) continue;
            if (variables.config.environment EQ "unconfigured") continue;
            var endpoint = {id=endpointId,label=variables.catalogLabels[endpointId],path=variables.catalog[endpointId],
                url=variables.config.baseUrl & variables.catalog[endpointId],available=true,reason=""};
            arrayAppend(view.endpoints,endpoint);
        }
        view.canCreate = mutationsEnabled() AND arrayLen(view.scopes) GT 0 AND arrayLen(view.endpoints) GT 0;
        if (!arrayLen(variables.registry)) view.message = "No verified FPW schedules were found. Create a task below, or register an existing FPW identity in the private configuration if its target needs review.";
        if (!view.available) view.message = "Native scheduler listing is unavailable. The manager cannot verify ownership or change schedules.";
        for (var entry in variables.registry) {
            if (!state.scopes[entry.mode] OR !structKeyExists(variables.catalog,entry.endpointId)) continue;
            var row = findRow(state, entry);
            if (!structIsEmpty(row)) arrayAppend(view.tasks, present(row, entry));
            else if (mutationsEnabled() AND flag(entry, "allowCreate")) {
                try {
                    targetUrl(entry);
                    arrayAppend(view.createOptions, {id=entry.id,name=entry.name,mode=entry.mode,group=entry.group,endpointId=entry.endpointId,endpoint=variables.catalog[entry.endpointId],secondsSupported=state.seconds[entry.mode]});
                } catch (any ignored) {}
            }
        }
        return view;
    }

    private struct function resolveEntry(required string id) output="false" {
        for (var entry in variables.registry) if (compare(entry.id, arguments.id) EQ 0) return entry;
        fail("The submitted task identity is not registered for this environment.");
    }

    private struct function newEntry(required struct input) output="false" {
        var entry = {name=value(arguments.input, "taskName"),group=value(arguments.input, "group"),mode=value(arguments.input, "mode"),
            endpointId=value(arguments.input, "endpointId"),application="",parameters={},allowCreate=true};
        var prefix = variables.config.environment EQ "production" ? "FPW_PROD_" : "FPW_DEV_";
        if (!reFind("^" & prefix & "[A-Za-z0-9_ .-]{1," & (60 - len(prefix)) & "}$", entry.name)) fail("Task Name must start with " & prefix & " and contain only letters, numbers, spaces, underscores, periods or hyphens (60 characters maximum).");
        if (!reFind("^[A-Za-z0-9_ .-]{1,40}$", entry.group) OR !listFind("server,application", entry.mode)) fail("Select an available scope and a valid group (40 characters maximum).");
        if (!structKeyExists(variables.catalog, entry.endpointId) OR entry.endpointId EQ "monitor-legacy"
            OR (entry.endpointId EQ "development-test" AND variables.config.environment NEQ "dev")) fail("Select an approved FPW script.");
        if (entry.mode EQ "application") entry.application = "FPW";
        entry.id = "new-task";
        if (entry.endpointId EQ "inactive-member-recovery") entry.parameters.dryRun = "true";
        for (var configured in variables.configuredRegistry) {
            if (identityKey(configured) NEQ identityKey(entry)) continue;
            if (compare(configured.name,entry.name) NEQ 0 OR compare(configured.group,entry.group) NEQ 0) fail("The entered identity conflicts with a configured task. Preserve its exact capitalization.");
            if (!flag(configured,"allowCreate")) fail("This identity is reserved in configuration and cannot be recreated.");
            if (compare(configured.endpointId,entry.endpointId) NEQ 0) fail("This configured identity is reserved for a different approved script.");
            // Honor the existing identity and runner parameters instead of replacing its binding.
            return duplicate(configured);
        }
        targetUrl(entry);
        return entry;
    }

    private string function selectedFrequency(required struct input) output="false" {
        if (!structKeyExists(arguments.input, "frequencyMode")) return value(arguments.input, "scheduleType");
        var mode = value(arguments.input, "frequencyMode");
        if (!listFind("seconds,once,recurring", mode)) fail("Select a supported schedule frequency.");
        if (mode NEQ "recurring") return mode;
        var recurrence = value(arguments.input, "recurrence");
        if (!listFind("daily,weekly,monthly", recurrence)) fail("Select daily, weekly or monthly recurrence.");
        return recurrence;
    }

    private struct function scheduleFields(required struct input) output="false" {
        var scheduleType = selectedFrequency(arguments.input);
        var dateText = value(arguments.input, "startDate");
        var timeText = value(arguments.input, "startTime");
        var seconds = value(arguments.input, "seconds");
        var timeout = value(arguments.input, "timeout");
        var date = "";
        if (scheduleType EQ "seconds" AND structKeyExists(arguments.input, "frequencyMode")) {
            for (var part in ["intervalHours", "intervalMinutes", "intervalSeconds"]) {
                if (!reFind("^[0-9]{1,4}$", value(arguments.input, part))) fail("Enter whole numbers for interval hours, minutes and seconds.");
            }
            if (val(arguments.input.intervalMinutes) GT 59 OR val(arguments.input.intervalSeconds) GT 59) fail("Interval minutes and seconds must be between 0 and 59.");
            seconds = toString(val(arguments.input.intervalHours) * 3600 + val(arguments.input.intervalMinutes) * 60 + val(arguments.input.intervalSeconds));
        }
        if (!listFindNoCase("once,daily,weekly,monthly,seconds", scheduleType)) fail("Select a supported schedule frequency.");
        if (!reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", dateText) OR !reFind("^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$", timeText)) fail("A valid scheduler date and time are required.");
        try {
            date = createDate(val(left(dateText, 4)), val(mid(dateText, 6, 2)), val(right(dateText, 2)));
        } catch (any ignored) { fail("The start date is invalid."); }
        if (dateFormat(date, "yyyy-mm-dd") NEQ dateText OR year(date) LT 2000 OR year(date) GT 2099) fail("The start date must be valid and between 2000 and 2099.");
        if (scheduleType EQ "seconds" AND (!reFind("^[0-9]{2,8}$", seconds) OR val(seconds) LT 60 OR val(seconds) GT 31536000)) fail("The interval must be a whole number from 60 to 31536000 seconds.");
        if (!reFind("^[0-9]{1,4}$", timeout) OR val(timeout) LT 1 OR val(timeout) GT 3600) fail("Timeout must be a whole number from 1 to 3600 seconds.");
        return {startdate=dateFormat(date, "mm/dd/yyyy"), starttime=timeText, interval=scheduleType EQ "seconds" ? seconds : lCase(scheduleType), requesttimeout=val(timeout)};
    }

    private void function durationFields(required struct attrs, required struct input) output="false" {
        if (structKeyExists(arguments.input, "endDate")) {
            var endDateText = value(arguments.input, "endDate");
            structDelete(arguments.attrs, "enddate");
            if (len(endDateText)) {
                if (!reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", endDateText)) fail("Enter a valid end date.");
                var endDateValue = "";
                try { endDateValue = createDate(val(left(endDateText,4)),val(mid(endDateText,6,2)),val(right(endDateText,2))); }
                catch (any ignored) { fail("Enter a valid end date."); }
                if (dateFormat(endDateValue,"yyyy-mm-dd") NEQ endDateText OR year(endDateValue) LT 2000 OR year(endDateValue) GT 2099) fail("Enter a valid end date between 2000 and 2099.");
                arguments.attrs.enddate = dateFormat(endDateValue,"mm/dd/yyyy");
            }
        }
        if (structKeyExists(arguments.input, "endTime")) {
            var endTimeText = value(arguments.input,"endTime");
            structDelete(arguments.attrs,"endtime");
            if (len(endTimeText)) {
                if (!reFind("^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$",endTimeText)) fail("Enter a valid end time.");
                arguments.attrs.endtime = endTimeText;
            }
        }
        if (structKeyExists(arguments.input, "frequencyMode") AND selectedFrequency(arguments.input) NEQ "seconds"
            AND (!structKeyExists(arguments.input, "taskId") OR structKeyExists(arguments.input,"endTime"))) structDelete(arguments.attrs,"endtime");
        if (len(value(arguments.attrs,"enddate")) AND (!isDate(arguments.attrs.enddate) OR dateCompare(arguments.attrs.startdate,arguments.attrs.enddate,"d") GT 0)) fail("The end date cannot be before the start date.");
        if (len(value(arguments.attrs,"endtime")) AND reFind("^[0-9]+$",toString(arguments.attrs.interval))
            AND compare(timeFormat(arguments.attrs.endtime,"HH:nn:ss"),timeFormat(arguments.attrs.starttime,"HH:nn:ss")) LTE 0) fail("The end time must be after the start time.");
    }

    private boolean function futureSchedulerStart(required any date, required string time, required date referenceTime) output="false" {
        // The form supplies scheduler wall time. Compare the complete normalized values in that zone.
        var start = dateFormat(arguments.date, "yyyy-mm-dd") & " " & timeFormat(arguments.time, "HH:nn:ss");
        var schedulerNow = dateTimeFormat(arguments.referenceTime, "yyyy-mm-dd HH:nn:ss", variables.config.schedulerTimezone);
        return compare(start, schedulerNow) GT 0;
    }

    private struct function updateAttributes(required struct row) output="false" {
        var attrs = {};
        var key = "";
        for (key in listToArray("enddate,endtime,file,path,port,proxyport,publish,resolveurl,overwrite,onexception,onmisfire,priority,retrycount,isdaily")) {
            if (len(value(arguments.row, key))) attrs[key] = arguments.row[key];
        }
        return attrs;
    }

    private void function audit(required struct entry, required string action, required boolean success, required string outcome) output="false" {
        var auth = new fpw.api.v1.AdminAuthorizationService().init("fpw").authorizeCurrentSession(session.user);
        new fpw.api.v1.AdminAuditService().init("fpw").record(
            actorUserId=auth.userId, action="scheduler_" & arguments.action, targetType="scheduled_task", targetId=arguments.entry.name,
            success=arguments.success, requestId=structKeyExists(request, "fpwRequestId") ? request.fpwRequestId : "",
            newValues={task=arguments.entry.name, mode=arguments.entry.mode, group=arguments.entry.group, application=arguments.entry.application,
                environment=variables.config.environment, outcome=arguments.outcome}
        );
    }

    public struct function mutate(required struct input) output="false" {
        requireAdmin(true);
        var action = "rejected";
        var entry = {name="unregistered",mode="",group="",application=""};
        var result = {success=false, message="The scheduler request could not be completed."};
        var nativeAttempted = false;
        var nativeSucceeded = false;
        try {
            var submittedAction = value(arguments.input, "action");
            if (!listFindNoCase("create,edit,pause,resume,run,delete", submittedAction)) fail("Unsupported scheduler action.");
            action = lCase(submittedAction);
            if (!mutationsEnabled()) fail("Scheduler changes are disabled until this environment is verified.");
            // The form cannot add scheduler attributes or change the registered identity/endpoint.
            for (var key in arguments.input) {
                if (!listFindNoCase("action,taskId,taskName,group,mode,endpointId,scheduleType,frequencyMode,recurrence,seconds,intervalHours,intervalMinutes,intervalSeconds,startDate,startTime,endDate,endTime,timeout,revision,confirmation,adminCsrfToken,fieldnames", key)) fail("Unapproved scheduler field submitted.");
            }
            lock name="FPW.AdminScheduledTasks.#hash(variables.config.environment)#" type="exclusive" timeout="10" {
                var state = readState();
                if (!mutationsEnabled()) fail("Scheduler changes are disabled until the approved script folder and environment are available.");
                entry = action EQ "create" AND !len(value(arguments.input,"taskId")) ? newEntry(arguments.input) : resolveEntry(value(arguments.input,"taskId"));
                if (structKeyExists(arguments.input, "endpointId") AND value(arguments.input, "endpointId") NEQ entry.endpointId) fail("The submitted endpoint is not approved for this task.");
                if (action NEQ "create" AND (structKeyExists(arguments.input,"taskName") OR structKeyExists(arguments.input,"group") OR structKeyExists(arguments.input,"mode"))) fail("Task identity is immutable while editing or performing an action.");
                if (!state.scopes[entry.mode]) fail("Native listing is unavailable for this task scope.");
                var row = findRow(state, entry);
                var attrs = {task=entry.name, group=entry.group, mode=entry.mode, action=action};
                if (listFindNoCase("create,edit", action) AND selectedFrequency(arguments.input) EQ "seconds" AND !state.seconds[entry.mode]) fail("Numeric intervals cannot be safely managed on this listing profile because the daily-window setting is unavailable.");
                if (action EQ "create") {
                    if (!len(entry.group)) fail("Creation requires an explicit group; use default for the scheduler default group.");
                    if (!flag(entry, "allowCreate") OR !structIsEmpty(row) OR structKeyExists(state.identities,identityKey(entry))) fail("This task cannot be created, or its name already exists in that scope and group. Refresh the list.");
                    attrs.action = "update";
                    structAppend(attrs, scheduleFields(arguments.input), true);
                    durationFields(attrs, arguments.input);
                    // A future start prevents immediate misfire execution during creation.
                    if (!futureSchedulerStart(attrs.startdate, attrs.starttime, now())) fail("The start date and time must be later than the current scheduler time. A later time today is allowed.");
                    attrs.url = targetUrl(entry);
                    attrs.port = variables.config.environment EQ "production" ? 443 : 8500;
                    attrs.operation = "HTTPRequest";
                    attrs.publish = false;
                    attrs.resolveurl = false;
                } else {
                    if (structIsEmpty(row)) fail("The registered task no longer exists. Refresh the list.");
                    var item = present(row, entry);
                    if (!item.actionable) fail(len(item.reason) ? item.reason : "This task is read-only.");
                    if (compare(value(arguments.input, "revision"), item.revision) NEQ 0) fail("The schedule changed after this form was loaded. Refresh and review it again.");
                    if (listFindNoCase("run,delete", action) AND compare(value(arguments.input, "confirmation"), entry.name) NEQ 0) fail("Confirmation must exactly match the task name.");
                    if (action EQ "run" AND !item.canRun) fail(runReason(row));
                    if (action EQ "edit") {
                        if (!item.editable) fail(item.reason);
                        structAppend(attrs, updateAttributes(row), true);
                        structAppend(attrs, scheduleFields(arguments.input), true);
                        if (attrs.interval EQ "once" AND !futureSchedulerStart(attrs.startdate, attrs.starttime, now())) fail("The one-time start date and time must be later than the current scheduler time. A later time today is allowed.");
                        if (structKeyExists(arguments.input,"frequencyMode") AND selectedFrequency(arguments.input) NEQ "seconds" AND reFind("^[0-9]+$",value(row,"interval"))) structDelete(attrs,"endtime");
                        durationFields(attrs, arguments.input);
                        attrs.action = "update";
                        attrs.url = row.url;
                        attrs.operation = "HTTPRequest";
                    }
                }
                // Audit availability is proved before scheduling. Never put form/URL/exception data in audit.
                audit(entry, action, true, "REQUEST_VALIDATED");
                nativeAttempted = true;
                variables.gateway.execute(attrs);
                nativeSucceeded = true;
                result.success = true;
                result.message = action EQ "run" ? "Run requested. This does not confirm job completion or notification delivery." : "Scheduler change accepted.";
                audit(entry, action, true, action EQ "run" ? "RUN_REQUESTED" : "CHANGE_ACCEPTED");
                var refreshed = readState();
                if (!refreshed.scopes[entry.mode]) result.message &= " State refresh is unavailable; verify the task before retrying any action.";
            }
        } catch (FPWScheduler.Validation problem) {
            result.message = problem.message;
            if (!structIsEmpty(entry)) {
                try { audit(entry, action, false, "VALIDATION_REJECTED"); } catch (any ignored) {}
            }
        } catch (any ignored) {
            result.success = nativeSucceeded;
            result.message = nativeSucceeded ? "The scheduler accepted the action, but audit or state verification failed. Refresh before taking further action; do not repeat Run Now automatically."
                : (nativeAttempted ? "The native action is unavailable, denied, or failed. Refresh scheduler state before retrying; a failed response does not prove that no change occurred."
                    : "Audit or scheduler verification is unavailable. No scheduler action was attempted.");
            if (!structIsEmpty(entry)) {
                try { audit(entry, action, nativeSucceeded, nativeSucceeded ? "ACCEPTED_VERIFICATION_UNAVAILABLE" : "ACTION_UNAVAILABLE"); } catch (any auditError) {
                    writeLog(file="fpw-admin-audit", type="error", text="SCHEDULER_AUDIT_UNAVAILABLE");
                }
            }
        }
        return result;
    }
}
