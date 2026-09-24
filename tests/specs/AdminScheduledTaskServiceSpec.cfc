component extends="testbox.system.BaseSpec" output="false" {
    private struct function baseRow() output="false" {
        return new fpw.tests.support.ScheduledTaskGatewayFake().defaultRow();
    }

    private struct function fixture(array rows, struct configChanges={}, boolean denyList=false, boolean denyExecute=false) output="false" {
        var config = {
            environment="dev", enabled=true, baseUrl="http://localhost:8500/fpw", schedulerTimezone="GMT",
            pausedUpdateVerified=true,
            tasks=[{id="manager-spec", name="FPW_DEV_MANAGER_SPEC", mode="server", group="FPW_DEV_TEST",
                application="", endpointId="development-test", allowCreate=true, parameters={}}]
        };
        structAppend(config, arguments.configChanges, true);
        var fixtureRows = structKeyExists(arguments, "rows") ? arguments.rows : [baseRow()];
        var gateway = new fpw.tests.support.ScheduledTaskGatewayFake().init(fixtureRows, arguments.denyList, arguments.denyExecute);
        return {config=config, gateway=gateway,
            service=new fpw.api.v1.AdminScheduledTaskService().init(config=config, gateway=gateway)};
    }

    private struct function inputFor(required struct fixture, string action="edit") output="false" {
        var view = arguments.fixture.service.getView();
        return {
            action=arguments.action, taskId="manager-spec", endpointId="development-test", scheduleType="daily",
            seconds="300", startDate=dateFormat(dateAdd("d", 2, now()), "yyyy-mm-dd"), startTime="13:15",
            timeout="23", revision=arrayLen(view.tasks) ? view.tasks[1].revision : ""
        };
    }

    private void function expectRejected(required struct fixture, required struct input) output="false" {
        var result = arguments.fixture.service.mutate(arguments.input);
        expect(result.success).toBeFalse();
        expect(arrayLen(arguments.fixture.gateway.getExecuted())).toBe(0);
    }

    private struct function newTaskInput() output="false" {
        return {
            action="create", taskName="FPW_DEV_FORM_SPEC", group="FPW_DEV_FORM_TEST", mode="server",
            endpointId="development-test", frequencyMode="recurring", recurrence="daily",
            startDate=dateFormat(dateAdd("d", 2, now()), "yyyy-mm-dd"), startTime="13:15:00",
            endDate="", endTime="", timeout="23"
        };
    }

    private struct function endpointAt(required struct view, required string path) output="false" {
        for (var endpoint in arguments.view.endpoints) {
            if (compare(endpoint.path, arguments.path) EQ 0) return endpoint;
        }
        return {};
    }

    private struct function folderFixture() output="false" {
        var name = "fpw_folder_spec_" & lCase(replace(createUUID(), "-", "", "all"));
        var root = expandPath("/fpw/app/scheduled/");
        return {name=name, root=root, file=root & name & ".cfm", path="/app/scheduled/" & name & ".cfm"};
    }

    function run() {
        describe("Admin scheduled task service with an isolated in-memory scheduler", function() {
            it("lists verified FPW identities without returning unrelated tasks or raw targets", function() {
                var owned = baseRow();
                var samePrefix = duplicate(owned);
                samePrefix.task = "FPW_DEV_UNREGISTERED";
                samePrefix.url = "https://unrelated.invalid/?token=SIMULATED_SECRET";
                var otherGroup = duplicate(owned);
                otherGroup.group = "UNRELATED_GROUP";
                otherGroup.url = "https://unrelated.invalid/";
                var f = fixture(rows=[owned, samePrefix, otherGroup]);
                var view = f.service.getView();
                expect(arrayLen(view.tasks)).toBe(1);
                expect(view.tasks[1].id).toBe("manager-spec");
                expect(view.tasks[1].endpoint).toBe("/tests/scheduled-task-target.cfm");
                expect(find("SIMULATED_SECRET", serializeJSON(view))).toBe(0);
                expect(structKeyExists(view.tasks[1], "url")).toBeFalse();
                expectRejected(f, {action="pause", taskId="FPW_DEV_UNREGISTERED"});
            });

            it("rejects a same-name task in a different application scope", function() {
                var row = baseRow();
                row.mode = "application";
                row.application = "UnrelatedApplication";
                var f = fixture(rows=[row], configChanges={tasks=[{
                    id="manager-spec", name=row.task, mode="application", group=row.group,
                    application="FPW", endpointId="development-test", allowCreate=false, parameters={}
                }]});
                expect(arrayLen(f.service.getView().tasks)).toBe(0);
                expectRejected(f, {action="pause", taskId="manager-spec", revision="untrusted"});
            });

            it("rejects creating over a registered identity with different name or group capitalization", function() {
                for (var field in ["task", "group"]) {
                    var row = baseRow();
                    row[field] = lCase(row[field]);
                    var f = fixture(rows=[row]);
                    var input = inputFor(fixture(rows=[]), "create");
                    var result = f.service.mutate(input);
                    expect(result.success).toBeFalse();
                    expect(findNoCase("name already exists", result.message) GT 0).toBeTrue();
                    expect(arrayLen(f.gateway.getExecuted())).toBe(0);
                }
            });

            it("lists configured identities despite name or group case differences in either scope", function() {
                for (var mode in ["server", "application"]) {
                    for (var fields in ["task", "group", "task,group"]) {
                        var row = baseRow();
                        row.mode = mode;
                        var configured = {id="manager-spec", name=row.task, mode=mode, group=row.group,
                            application=mode EQ "application" ? "FPW" : "", endpointId="development-test",
                            allowCreate=true, parameters={}};
                        if (mode EQ "application") row.application = "FPW";
                        for (var field in listToArray(fields)) row[field] = lCase(row[field]);
                        var f = fixture(rows=[row], configChanges={tasks=[configured]});
                        var view = f.service.getView();
                        expect(view.available).toBeTrue();
                        expect(view.environment).toBe("dev");
                        expect(view.readOnly).toBeFalse();
                        expect(arrayLen(view.tasks)).toBe(1);
                        expect(view.tasks[1].id).toBe("manager-spec");
                        expect(compare(view.tasks[1].name, row.task)).toBe(0);
                        expect(compare(view.tasks[1].group, row.group)).toBe(0);
                        expect(view.tasks[1].actionable).toBeTrue();
                        expect(view.tasks[1].editable).toBeTrue();
                        expect(compare(f.service.getView().tasks[1].name, row.task)).toBe(0);
                        expect(compare(f.config.tasks[1].name, configured.name)).toBe(0);
                    }
                }
            });

            it("uses the native case for every existing-task action in both scopes", function() {
                for (var mode in ["server", "application"]) {
                    for (var action in ["edit", "pause", "resume", "run", "delete"]) {
                        var row = baseRow();
                        row.task = lCase(row.task);
                        row.group = lCase(row.group);
                        row.mode = mode;
                        if (mode EQ "application") row.application = "FPW";
                        var f = fixture(rows=[row], configChanges={tasks=[{
                            id="manager-spec", name=uCase(row.task), group=uCase(row.group), mode=mode,
                            application=mode EQ "application" ? "FPW" : "", endpointId="development-test",
                            allowCreate=false, parameters={}
                        }]});
                        var input = inputFor(f, action);
                        if (listFind("run,delete", action)) input.confirmation = row.task;
                        expect(f.service.mutate(input).success).toBeTrue();
                        var calls = f.gateway.getExecuted();
                        expect(arrayLen(calls)).toBe(1);
                        expect(compare(calls[1].task, row.task)).toBe(0);
                        expect(compare(calls[1].group, row.group)).toBe(0);
                        expect(calls[1].mode).toBe(mode);
                        expect(calls[1].action).toBe(action EQ "edit" ? "update" : action);
                        if (action EQ "edit") expect(calls[1].url).toBe(row.url);
                    }
                }
            });

            it("requires confirmation to match the displayed native task name exactly", function() {
                for (var action in ["run", "delete"]) {
                    var row = baseRow();
                    row.task = lCase(row.task);
                    var f = fixture(rows=[row]);
                    var input = inputFor(f, action);
                    input.confirmation = uCase(row.task);
                    expectRejected(f, input);
                }
            });

            it("does not relax URL ownership when a configured identity differs only in case", function() {
                for (var target in ["https://unrelated.invalid/", "http://localhost:8500/fpw/unapproved.cfm",
                    baseRow().url & "?force=true"]) {
                    var row = baseRow();
                    row.task = lCase(row.task);
                    row.group = lCase(row.group);
                    row.url = target;
                    var f = fixture(rows=[row]);
                    var view = f.service.getView();
                    expect(view.available).toBeTrue();
                    expect(arrayLen(view.tasks)).toBe(1);
                    expect(view.tasks[1].actionable).toBeFalse();
                    expect(view.tasks[1].canRun).toBeFalse();
                    for (var action in ["edit", "pause", "resume", "run", "delete"]) {
                        var input = inputFor(f, action);
                        if (listFind("run,delete", action)) input.confirmation = row.task;
                        expectRejected(f, input);
                    }
                }
            });

            it("rejects duplicate configured native identities regardless of case or row order", function() {
                for (var field in ["exact", "task", "group"]) {
                    var owned = baseRow();
                    var conflict = duplicate(owned);
                    if (field NEQ "exact") conflict[field] = lCase(conflict[field]);
                    conflict.url = "https://unrelated.invalid/?token=SIMULATED_SECRET";
                    for (var rows in [[owned, conflict], [conflict, owned]]) {
                        var f = fixture(rows=[owned]);
                        var input = inputFor(f, "pause");
                        f.gateway.replaceRows(rows);
                        var rejected = false;
                        try { f.service.getView(); }
                        catch (FPWScheduler.Validation expected) { rejected = true; }
                        expect(rejected).toBeTrue();
                        expectRejected(f, input);
                    }
                }
            });

            it("rejects a stale form when native task capitalization changes after listing", function() {
                var row = baseRow();
                var f = fixture(rows=[row]);
                var input = inputFor(f, "pause");
                row.task = lCase(row.task);
                row.group = lCase(row.group);
                f.gateway.replaceRows([row]);
                expectRejected(f, input);
                expect(compare(f.service.getView().tasks[1].name, row.task)).toBe(0);
                expect(f.service.mutate(inputFor(f, "pause")).success).toBeTrue();
                expect(compare(f.gateway.getExecuted()[1].task, row.task)).toBe(0);
            });

            it("retains configured spelling for a reserved slot after the native task disappears", function() {
                var configuredRow = baseRow();
                var row = duplicate(configuredRow);
                row.task = lCase(row.task);
                row.group = lCase(row.group);
                var f = fixture(rows=[row]);
                expect(compare(f.service.getView().tasks[1].name, row.task)).toBe(0);
                f.gateway.replaceRows([]);
                var view = f.service.getView();
                expect(arrayLen(view.tasks)).toBe(0);
                expect(arrayLen(view.createOptions)).toBe(1);
                expect(compare(view.createOptions[1].name, configuredRow.task)).toBe(0);
                expect(compare(view.createOptions[1].group, configuredRow.group)).toBe(0);
            });

            it("keeps one registered task after explicit repeated initialization", function() {
                var f = fixture();
                f.service.init(config=f.config, gateway=f.gateway);
                var view = f.service.getView();
                expect(arrayLen(view.tasks)).toBe(1);
                expect(view.tasks[1].id).toBe("manager-spec");
                expect(arrayLen(view.createOptions)).toBe(0);
                f = fixture(rows=[]);
                f.service.init(config=f.config, gateway=f.gateway);
                expect(arrayLen(f.service.getView().createOptions)).toBe(1);
            });

            it("creates only an absent registered slot using native update and refreshes state", function() {
                var f = fixture(rows=[]);
                expect(arrayLen(f.service.getView().createOptions)).toBe(1);
                var result = f.service.mutate(inputFor(f, "create"));
                expect(result.success).toBeTrue();
                var calls = f.gateway.getExecuted();
                expect(arrayLen(calls)).toBe(1);
                expect(calls[1].action).toBe("update");
                expect(calls[1].task).toBe("FPW_DEV_MANAGER_SPEC");
                expect(calls[1].group).toBe("FPW_DEV_TEST");
                expect(calls[1].url).toBe("http://localhost:8500/fpw/tests/scheduled-task-target.cfm");
                expect(arrayLen(f.service.getView().tasks)).toBe(1);
                expect(f.gateway.getListCount() GTE 8).toBeTrue();
            });

            it("rejects endpoint substitution and arbitrary URL fields before calling the scheduler", function() {
                var f = fixture();
                var input = inputFor(f);
                input.endpointId = "monitor";
                expectRejected(f, input);
                input = inputFor(f);
                input.url = "https://unrelated.invalid/?token=SIMULATED_SECRET";
                expectRejected(f, input);
                var row = baseRow();
                row.url = "https://unrelated.invalid/?token=SIMULATED_SECRET";
                f = fixture(rows=[row]);
                expect(f.service.getView().tasks[1].actionable).toBeFalse();
                expect(find("SIMULATED_SECRET", serializeJSON(f.service.getView()))).toBe(0);
            });

            it("preserves unexposed supported attributes and paused status during edit", function() {
                var row = baseRow();
                row.status = "Paused";
                var f = fixture(rows=[row]);
                var result = f.service.mutate(inputFor(f));
                expect(result.success).toBeTrue();
                var attrs = f.gateway.getExecuted()[1];
                for (var key in ["enddate", "endtime", "port", "proxyport", "publish", "resolveurl", "overwrite", "priority", "retrycount"]) {
                    expect(toString(attrs[key])).toBe(toString(row[key]));
                }
                expect(attrs.requesttimeout).toBe(23);
                expect(attrs.starttime).toBe("13:15");
                expect(f.service.getView().tasks[1].paused).toBe("Yes");
            });

            it("normalizes a TIMEOUT-only native listing without losing the editable request timeout", function() {
                var row = baseRow();
                row.timeout = row.requesttimeout;
                structDelete(row, "requesttimeout");
                var f = fixture(rows=[row]);
                var view = f.service.getView();
                expect(view.tasks[1].timeout).toBe("17");
                expect(view.tasks[1].editable).toBeTrue();
                expect(f.service.mutate(inputFor(f)).success).toBeTrue();
                expect(f.gateway.getExecuted()[1].requesttimeout).toBe(23);
            });

            it("accepts the native simple daily cron expression and rejects a custom cron", function() {
                var row = baseRow();
                row.crontime = "0 0 12 * * ?";
                var f = fixture(rows=[row]);
                expect(f.service.getView().tasks[1].editable).toBeTrue();
                expect(f.service.mutate(inputFor(f)).success).toBeTrue();
                expect(f.gateway.getExecuted()[1].interval).toBe("daily");
                row = baseRow();
                row.crontime = "0 0 12 ? * MON-FRI";
                f = fixture(rows=[row]);
                expect(f.service.getView().tasks[1].editable).toBeFalse();
                expectRejected(f, inputFor(f));
            });

            it("accepts the native uppercase one-time interval with zero repeats only for a one-time schedule", function() {
                var row = baseRow();
                row.interval = "ONCE";
                row.repeat = "0";
                var f = fixture(rows=[row]);
                var view = f.service.getView();
                expect(view.tasks[1].actionable).toBeTrue();
                expect(view.tasks[1].scheduleType).toBe("once");
                expect(f.service.mutate(inputFor(f, "pause")).success).toBeTrue();
                row = baseRow();
                row.repeat = "0";
                f = fixture(rows=[row]);
                expect(f.service.getView().tasks[1].editable).toBeFalse();
            });

            it("rejects a start date after the preserved existing end date", function() {
                var row = baseRow();
                var f = fixture(rows=[row]);
                var input = inputFor(f);
                input.startDate = dateFormat(dateAdd("d", 1, row.enddate), "yyyy-mm-dd");
                var result = f.service.mutate(input);
                expect(result.success).toBeFalse();
                expect(findNoCase("end date", result.message) GT 0).toBeTrue();
                expect(arrayLen(f.gateway.getExecuted())).toBe(0);
            });

            it("makes unknown and missing scheduler attributes read-only", function() {
                var row = baseRow();
                row.futureAttribute = "SIMULATED_PRIVATE_DETAIL";
                var f = fixture(rows=[row]);
                expect(f.service.getView().tasks[1].editable).toBeFalse();
                expect(f.service.getView().tasks[1].actionable).toBeTrue();
                expect(find("SIMULATED_PRIVATE_DETAIL", serializeJSON(f.service.getView()))).toBe(0);
                expectRejected(f, inputFor(f));
                row = baseRow();
                structDelete(row, "priority");
                f = fixture(rows=[row]);
                expect(f.service.getView().tasks[1].editable).toBeFalse();
                expectRejected(f, inputFor(f));
            });

            it("edits numeric schedules without isDaily and preserves returned timing fields", function() {
                var row = baseRow();
                row.interval = "3600";
                var f = fixture(rows=[row], configChanges={verifiedEngineVersion=""});
                var view = f.service.getView();
                expect(view.readOnly).toBeFalse();
                expect(view.tasks[1].secondsSupported).toBeTrue();
                expect(view.tasks[1].editable).toBeTrue();
                var input = inputFor(f);
                input.scheduleType = "seconds";
                input.seconds = "7200";
                expect(f.service.mutate(input).success).toBeTrue();
                var attrs = f.gateway.getExecuted()[1];
                expect(val(attrs.interval)).toBe(7200);
                expect(structKeyExists(attrs, "isdaily")).toBeFalse();
                expect(dateFormat(attrs.enddate, "yyyy-mm-dd")).toBe(dateFormat(row.enddate, "yyyy-mm-dd"));
                expect(timeFormat(attrs.endtime, "HH:nn:ss")).toBe(timeFormat(row.endtime, "HH:nn:ss"));
                expect(toString(attrs.port)).toBe(toString(row.port));
                expect(attrs.url).toBe(row.url);
            });

            it("preserves an explicitly returned daily-window setting during an interval edit", function() {
                for (var daily in ["YES", "NO"]) {
                    var row = baseRow();
                    row.interval = "3600";
                    row.isdaily = daily;
                    var f = fixture(rows=[row]);
                    var input = inputFor(f);
                    input.scheduleType = "seconds";
                    input.seconds = "7200";
                    expect(f.service.mutate(input).success).toBeTrue();
                    expect(f.gateway.getExecuted()[1].isdaily).toBe(daily);
                }
            });

            it("creates numeric schedules from a listing without isDaily or a verified engine version", function() {
                for (var mode in ["server", "application"]) {
                    var f = fixture(rows=[], configChanges={tasks=[], verifiedEngineVersion="unverified"});
                    var view = f.service.getView();
                    expect(view.canCreate).toBeTrue();
                    for (var scope in view.scopes) expect(scope.secondsSupported).toBeTrue();
                    var input = newTaskInput();
                    input.mode = mode;
                    input.frequencyMode = "seconds";
                    input.intervalHours = "0";
                    input.intervalMinutes = "5";
                    input.intervalSeconds = "0";
                    expect(f.service.mutate(input).success).toBeTrue();
                    var attrs = f.gateway.getExecuted()[1];
                    expect(val(attrs.interval)).toBe(300);
                    expect(attrs.mode).toBe(mode);
                    expect(structKeyExists(attrs, "isdaily")).toBeFalse();
                    expect(f.service.getView().tasks[1].secondsSupported).toBeTrue();
                }
            });

            it("redacts denied list errors and blocks mutation without identity proof", function() {
                var f = fixture(denyList=true);
                var view = f.service.getView();
                expect(view.available).toBeFalse();
                expect(arrayLen(view.tasks)).toBe(0);
                expect(find("SIMULATED_PRIVATE_DETAIL", serializeJSON(view))).toBe(0);
                expectRejected(f, {action="pause", taskId="manager-spec", revision="untrusted"});
            });

            it("returns a sanitized outcome when a native action is denied", function() {
                var f = fixture(denyExecute=true);
                var result = f.service.mutate(inputFor(f, "pause"));
                expect(result.success).toBeFalse();
                expect(arrayLen(f.gateway.getExecuted())).toBe(1);
                expect(find("SIMULATED_PRIVATE_DETAIL", serializeJSON(result))).toBe(0);
                expect(find("SIMULATED_SECRET", serializeJSON(result))).toBe(0);
                expect(findNoCase("unavailable", result.message) GT 0).toBeTrue();
            });

            it("rejects invalid calendar dates times intervals and timeouts", function() {
                var cases = [
                    {startDate="2099-02-30"}, {startTime="24:00"}, {startTime="12:60:00"},
                    {scheduleType="cron"}, {scheduleType="seconds", seconds="59"},
                    {scheduleType="seconds", seconds="31536001"}, {scheduleType="seconds", seconds="60.5"},
                    {timeout="0"}, {timeout="3601"}, {timeout="1.5"}
                ];
                for (var overrides in cases) {
                    var f = fixture();
                    var input = inputFor(f);
                    structAppend(input, overrides, true);
                    expectRejected(f, input);
                }
                var f = fixture(rows=[]);
                var input = inputFor(f, "create");
                var past = dateAdd("n", -5, now());
                input.startDate = dateTimeFormat(past, "yyyy-mm-dd", "GMT");
                input.startTime = dateTimeFormat(past, "HH:nn:ss", "GMT");
                expectRejected(f, input);
            });

            it("compares the full scheduler start time including seconds instead of requiring tomorrow", function() {
                var f = fixture(rows=[]);
                makePublic(f.service, "futureSchedulerStart", "futureStartForTest");
                var reference = parseDateTime("2026-09-12T03:08:45Z");
                expect(f.service.futureStartForTest("2026-09-12", "00:00", reference)).toBeFalse();
                expect(f.service.futureStartForTest("2026-09-12", "03:08:44", reference)).toBeFalse();
                expect(f.service.futureStartForTest("2026-09-12", "03:08:45", reference)).toBeFalse();
                expect(f.service.futureStartForTest("2026-09-12", "03:08:46", reference)).toBeTrue();
                expect(f.service.futureStartForTest("2026-09-12", "04:00", reference)).toBeTrue();
                expect(f.service.futureStartForTest("2026-09-13", "00:00", reference)).toBeTrue();
                expect(f.service.futureStartForTest("2026-09-11", "23:59:59", reference)).toBeFalse();
                expect(f.service.futureStartForTest("2027-01-01", "00:00", parseDateTime("2026-12-31T23:59:59Z"))).toBeTrue();
            });

            it("uses the configured scheduler clock across timezone dates and fractional offsets", function() {
                var reference = parseDateTime("2026-09-12T03:08:45Z");
                for (var example in [
                    {zone="America/New_York", date="2026-09-11", future="23:30", past="23:00"},
                    {zone="GMT", date="2026-09-12", future="03:30", past="03:00"},
                    {zone="Asia/Kolkata", date="2026-09-12", future="08:39", past="08:38:44"}
                ]) {
                    var f = fixture(rows=[], configChanges={schedulerTimezone=example.zone});
                    makePublic(f.service, "futureSchedulerStart", "futureStartForTest");
                    expect(f.service.futureStartForTest(example.date, example.future, reference)).toBeTrue();
                    expect(f.service.futureStartForTest(example.date, example.past, reference)).toBeFalse();
                }
            });

            it("creates every supported frequency later on the same scheduler day", function() {
                // Keep the simulated scheduler before noon so the live-clock regression cannot cross midnight.
                var zone = val(dateTimeFormat(now(), "HH", "GMT")) LT 12 ? "GMT" : "GMT-12:00";
                var future = dateAdd("n", 30, now());
                for (var frequency in ["daily", "weekly", "monthly", "once", "seconds"]) {
                    var f = fixture(rows=[], configChanges={schedulerTimezone=zone});
                    var input = inputFor(f, "create");
                    input.scheduleType = frequency;
                    input.startDate = dateTimeFormat(future, "yyyy-mm-dd", zone);
                    input.startTime = dateTimeFormat(future, "HH:nn:ss", zone);
                    expect(input.startDate).toBe(dateTimeFormat(now(), "yyyy-mm-dd", zone));
                    expect(f.service.mutate(input).success).toBeTrue();
                    var attrs = f.gateway.getExecuted()[1];
                    expect(dateFormat(attrs.startdate, "yyyy-mm-dd")).toBe(input.startDate);
                    expect(attrs.starttime).toBe(input.startTime);
                }
            });

            it("allows later-today one-time edits while rejecting past one-time starts and preserving recurring edits", function() {
                var zone = val(dateTimeFormat(now(), "HH", "GMT")) LT 12 ? "GMT" : "GMT-12:00";
                var future = dateAdd("n", 30, now());
                var f = fixture(configChanges={schedulerTimezone=zone});
                var input = inputFor(f);
                input.scheduleType = "once";
                input.startDate = dateTimeFormat(future, "yyyy-mm-dd", zone);
                input.startTime = dateTimeFormat(future, "HH:nn:ss", zone);
                expect(f.service.mutate(input).success).toBeTrue();
                f = fixture(configChanges={schedulerTimezone=zone});
                input = inputFor(f);
                input.scheduleType = "once";
                input.startDate = "2020-01-01";
                input.startTime = "00:00";
                expectRejected(f, input);
                input.scheduleType = "daily";
                expect(f.service.mutate(input).success).toBeTrue();
            });

            it("rejects stale revisions while ignoring execution-only last-fire changes", function() {
                var f = fixture();
                var input = inputFor(f, "pause");
                var changed = baseRow();
                changed.priority = "9";
                f.gateway.replaceRows([changed]);
                expectRejected(f, input);
                f = fixture();
                input = inputFor(f, "pause");
                changed = baseRow();
                changed.lastfire = now();
                changed.remainingcount = "11";
                f.gateway.replaceRows([changed]);
                expect(f.service.mutate(input).success).toBeTrue();
            });

            it("requires exact task-name confirmation for run and delete", function() {
                for (var action in ["run", "delete"]) {
                    var f = fixture();
                    var input = inputFor(f, action);
                    expectRejected(f, input);
                    input.confirmation = "fpw_dev_manager_spec";
                    expectRejected(f, input);
                    input.confirmation = "FPW_DEV_MANAGER_SPEC";
                    var result = f.service.mutate(input);
                    expect(result.success).toBeTrue();
                    if (action EQ "run") {
                        expect(findNoCase("Run requested", result.message) GT 0).toBeTrue();
                        expect(findNoCase("does not confirm", result.message) GT 0).toBeTrue();
                    } else expect(arrayLen(f.service.getView().tasks)).toBe(0);
                }
            });

            it("uses scoped individual pause and resume actions and refreshes paused status", function() {
                var f = fixture();
                expect(f.service.mutate(inputFor(f, "pause")).success).toBeTrue();
                expect(f.service.getView().tasks[1].paused).toBe("Yes");
                expect(f.service.mutate(inputFor(f, "resume")).success).toBeTrue();
                expect(f.service.getView().tasks[1].paused).toBe("No");
                var calls = f.gateway.getExecuted();
                expect(arrayLen(calls)).toBe(2);
                for (var attrs in calls) {
                    expect(attrs.task).toBe("FPW_DEV_MANAGER_SPEC");
                    expect(attrs.group).toBe("FPW_DEV_TEST");
                    expect(attrs.mode).toBe("server");
                }
            });

            it("allows changes with a missing blank or mismatched verified engine version", function() {
                for (var overrides in [{}, {verifiedEngineVersion=""}, {verifiedEngineVersion="unverified"}]) {
                    var f = fixture(configChanges=overrides);
                    var view = f.service.getView();
                    expect(view.readOnly).toBeFalse();
                    expect(view.engine).toBe(toString(server.coldfusion.productVersion));
                    expect(f.service.mutate(inputFor(f, "pause")).success).toBeTrue();
                }
            });

            it("keeps the enabled and scheduler timezone requirements", function() {
                for (var overrides in [{enabled=false}, {schedulerTimezone=""}]) {
                    var f = fixture(configChanges=overrides);
                    expect(f.service.getView().readOnly).toBeTrue();
                    expectRejected(f, inputFor(f, "pause"));
                }
            });

            it("rejects unsupported actions and identity-attribute injection", function() {
                var f = fixture();
                expectRejected(f, {action="pauseall", taskId="manager-spec"});
                var input = inputFor(f, "pause");
                input.group = "UNRELATED_GROUP";
                expectRejected(f, input);
                input = inputFor(f);
                input.task = "FPW_DEV_RENAMED";
                expectRejected(f, input);
            });

            it("creates an entered task name and discovers it again without a configured slot", function() {
                var f = fixture(rows=[], configChanges={tasks=[]});
                var input = newTaskInput();
                expect(f.service.mutate(input).success).toBeTrue();
                var attrs = f.gateway.getExecuted()[1];
                expect(attrs.task).toBe(input.taskName);
                expect(attrs.group).toBe(input.group);
                expect(attrs.mode).toBe("server");
                expect(attrs.url).toBe("http://localhost:8500/fpw/tests/scheduled-task-target.cfm");
                expect(attrs.interval).toBe("daily");
                var view = f.service.getView();
                expect(arrayLen(view.tasks)).toBe(1);
                expect(view.tasks[1].name).toBe(input.taskName);
                expect(view.tasks[1].actionable).toBeTrue();
                var discoveredId = view.tasks[1].id;
                f.service.init(config=f.config, gateway=f.gateway);
                expect(f.service.getView().tasks[1].id).toBe(discoveredId);
            });

            it("discovers existing FPW targets regardless of legacy name while hiding unrelated scripts", function() {
                var owned = baseRow();
                owned.task = "Legacy local scheduler check";
                owned.group = "default";
                var unrelated = duplicate(owned);
                unrelated.task = "FPW_DEV_UNRELATED";
                unrelated.url = "http://localhost:8500/fpw/tests/not-approved.cfm?token=SIMULATED_SECRET";
                var extraQuery = duplicate(owned);
                extraQuery.task = "FPW_DEV_EXTRA_QUERY";
                extraQuery.url &= "?extra=SIMULATED_SECRET";
                var f = fixture(rows=[owned, unrelated, extraQuery], configChanges={tasks=[]});
                var view = f.service.getView();
                expect(arrayLen(view.tasks)).toBe(1);
                expect(view.tasks[1].name).toBe(owned.task);
                expect(view.tasks[1].group).toBe("default");
                expect(view.tasks[1].canRun).toBeTrue();
                expect(find("SIMULATED_SECRET", serializeJSON(view))).toBe(0);
                expect(find("not-approved", serializeJSON(view))).toBe(0);
            });

            it("rechecks discovered ownership against the current target before every action", function() {
                for (var action in ["pause", "resume", "run", "delete"]) {
                    var row = baseRow();
                    row.task = "Legacy local scheduler check";
                    var f = fixture(rows=[row], configChanges={tasks=[]});
                    var task = f.service.getView().tasks[1];
                    row.url = "https://unrelated.invalid/?token=SIMULATED_SECRET";
                    f.gateway.replaceRows([row]);
                    expectRejected(f, {action=action, taskId=task.id, revision=task.revision, confirmation=task.name});
                    expect(arrayLen(f.service.getView().tasks)).toBe(0);
                }
            });

            it("rejects entered-name collisions with unrelated native identities including case variants", function() {
                for (var variant in ["exact", "name-case", "group-case"]) {
                    var input = newTaskInput();
                    var row = baseRow();
                    row.task = variant EQ "name-case" ? lCase(input.taskName) : input.taskName;
                    row.group = variant EQ "group-case" ? lCase(input.group) : input.group;
                    row.url = "https://unrelated.invalid/?token=SIMULATED_SECRET";
                    var f = fixture(rows=[row], configChanges={tasks=[]});
                    expect(arrayLen(f.service.getView().tasks)).toBe(0);
                    expectRejected(f, input);
                }
            });

            it("rejects invalid entered names scopes and script substitutions", function() {
                var cases = [
                    {taskName=""}, {taskName="FPW_PROD_WRONG_ENV"}, {taskName="FPW_DEV_bad/name"},
                    {group="bad/group"}, {mode="unrelated"}, {application="UnrelatedApplication"},
                    {endpointId="unapproved-script"}, {endpointId="monitor-legacy"},
                    {url="https://unrelated.invalid/?token=SIMULATED_SECRET"}
                ];
                for (var overrides in cases) {
                    var f = fixture(rows=[], configChanges={tasks=[]});
                    var input = newTaskInput();
                    structAppend(input, overrides, true);
                    expectRejected(f, input);
                }
            });

            it("converts form hours minutes and seconds while preserving the entered duration", function() {
                var f = fixture(rows=[], configChanges={tasks=[]});
                var input = newTaskInput();
                input.frequencyMode = "seconds";
                input.intervalHours = "1";
                input.intervalMinutes = "2";
                input.intervalSeconds = "3";
                input.endDate = dateFormat(dateAdd("d", 5, now()), "yyyy-mm-dd");
                input.endTime = "18:45:00";
                expect(f.service.mutate(input).success).toBeTrue();
                var attrs = f.gateway.getExecuted()[1];
                expect(val(attrs.interval)).toBe(3723);
                expect(dateFormat(attrs.enddate, "yyyy-mm-dd")).toBe(input.endDate);
                expect(timeFormat(attrs.endtime, "HH:nn:ss")).toBe(input.endTime);
                var task = f.service.getView().tasks[1];
                expect(task.endDate).toBe(input.endDate);
                expect(task.endTime).toBe(input.endTime);
            });

            it("rejects invalid form duration and interval components", function() {
                var cases = [
                    {endDate="2099-02-30"}, {endDate=dateFormat(dateAdd("d", 1, now()), "yyyy-mm-dd")},
                    {endTime="25:00:00"},
                    {frequencyMode="seconds", intervalHours="0", intervalMinutes="0", intervalSeconds="59"},
                    {frequencyMode="seconds", intervalHours="-1", intervalMinutes="0", intervalSeconds="0"},
                    {frequencyMode="seconds", intervalHours="1.5", intervalMinutes="0", intervalSeconds="0"},
                    {frequencyMode="recurring", recurrence="unsupported"}, {frequencyMode="cron"}
                ];
                for (var overrides in cases) {
                    var f = fixture(rows=[], configChanges={tasks=[]});
                    var input = newTaskInput();
                    structAppend(input, overrides, true);
                    expectRejected(f, input);
                }
            });

            it("keeps controls on a discovered custom schedule without changing its advanced attributes", function() {
                for (var action in ["pause", "resume", "run", "delete"]) {
                    var row = baseRow();
                    row.task = "Existing custom scheduler check";
                    row.crontime = "0 0 12 ? * MON-FRI";
                    var f = fixture(rows=[row], configChanges={tasks=[]});
                    var task = f.service.getView().tasks[1];
                    expect(task.editable).toBeFalse();
                    expect(task.actionable).toBeTrue();
                    expect(task.canRun).toBeTrue();
                    expect(f.service.mutate({action=action, taskId=task.id, revision=task.revision, confirmation=task.name}).success).toBeTrue();
                    var attrs = f.gateway.getExecuted()[1];
                    expect(attrs.action).toBe(action);
                    expect(structKeyExists(attrs, "crontime")).toBeFalse();
                    expect(structKeyExists(attrs, "interval")).toBeFalse();
                    expect(structKeyExists(attrs, "url")).toBeFalse();
                }
            });

            it("blocks running handler or chained schedules while keeping pause and delete available", function() {
                for (var overrides in [{eventhandler="PrivateHandler"}, {oncomplete="PrivateTask"}, {chainedtask="YES"}, {username="PrivateUser"}, {proxyserver="private.invalid"}]) {
                    var row = baseRow();
                    row.task = "Existing advanced scheduler check";
                    structAppend(row, overrides, true);
                    var f = fixture(rows=[row], configChanges={tasks=[]});
                    var task = f.service.getView().tasks[1];
                    expect(task.actionable).toBeTrue();
                    expect(task.canRun).toBeFalse();
                    expect(task.editable).toBeFalse();
                    expectRejected(f, {action="run", taskId=task.id, revision=task.revision, confirmation=task.name});
                    expect(f.service.mutate({action="pause", taskId=task.id, revision=task.revision}).success).toBeTrue();
                    task = f.service.getView().tasks[1];
                    expect(f.service.mutate({action="delete", taskId=task.id, revision=task.revision, confirmation=task.name}).success).toBeTrue();
                }
            });

            it("keeps discovered task identity immutable on edit", function() {
                for (var overrides in [{taskName="FPW_DEV_RENAMED"}, {group="OTHER_GROUP"}, {mode="application"}]) {
                    var row = baseRow();
                    row.task = "Existing local scheduler check";
                    var f = fixture(rows=[row], configChanges={tasks=[]});
                    var task = f.service.getView().tasks[1];
                    var input = newTaskInput();
                    structDelete(input, "taskName");
                    structDelete(input, "group");
                    structDelete(input, "mode");
                    input.action = "edit";
                    input.taskId = task.id;
                    input.revision = task.revision;
                    structAppend(input, overrides, true);
                    expectRejected(f, input);
                }
            });

            it("preserves an existing daily end time when its disabled form field is omitted", function() {
                var row = baseRow();
                var f = fixture(rows=[row]);
                var input = inputFor(f);
                input.frequencyMode = "recurring";
                input.recurrence = "daily";
                input.endDate = dateFormat(row.enddate, "yyyy-mm-dd");
                expect(f.service.mutate(input).success).toBeTrue();
                expect(timeFormat(f.gateway.getExecuted()[1].endtime, "HH:nn:ss")).toBe(timeFormat(row.endtime, "HH:nn:ss"));
            });

            it("clears optional dates and times only when explicitly submitted blank", function() {
                var row = baseRow();
                row.interval = "300";
                row.isdaily = "YES";
                var f = fixture(rows=[row]);
                var input = inputFor(f);
                input.frequencyMode = "seconds";
                input.intervalHours = "0";
                input.intervalMinutes = "1";
                input.intervalSeconds = "0";
                input.endDate = "";
                input.endTime = "";
                expect(f.service.mutate(input).success).toBeTrue();
                var attrs = f.gateway.getExecuted()[1];
                expect(structKeyExists(attrs, "enddate")).toBeFalse();
                expect(structKeyExists(attrs, "endtime")).toBeFalse();
                expect(val(attrs.interval)).toBe(60);
            });

            it("honors configured identity creation permissions and endpoint reservations in the new form", function() {
                var input = newTaskInput();
                input.taskName = "FPW_DEV_MANAGER_SPEC";
                input.group = "FPW_DEV_TEST";
                for (var overrides in [{allowCreate=false}, {endpointId="monitor"}, {name="fpw_dev_manager_spec"}]) {
                    var entry = {id="manager-spec", name="FPW_DEV_MANAGER_SPEC", mode="server", group="FPW_DEV_TEST",
                        application="", endpointId="development-test", allowCreate=true, parameters={}};
                    structAppend(entry, overrides, true);
                    // Existing identities may use lowercase names; creation remains explicitly disabled.
                    if (structKeyExists(overrides, "name")) entry.allowCreate = false;
                    var f = fixture(rows=[], configChanges={tasks=[entry]});
                    expectRejected(f, input);
                }
                var f = fixture(rows=[]);
                expect(f.service.mutate(input).success).toBeTrue();
                expect(f.service.getView().tasks[1].id).toBe("manager-spec");
                expect(f.gateway.getExecuted()[1].url).toBe("http://localhost:8500/fpw/tests/scheduled-task-target.cfm");
            });

            it("rejects discovered case-conflicting identities regardless of native row order", function() {
                var owned = baseRow();
                owned.task = "Existing local scheduler check";
                var conflict = duplicate(owned);
                conflict.task = lCase(owned.task);
                conflict.url = "https://unrelated.invalid/?token=SIMULATED_SECRET";
                for (var rows in [[owned, conflict], [conflict, owned]]) {
                    var f = fixture(rows=[owned], configChanges={tasks=[]});
                    var task = f.service.getView().tasks[1];
                    f.gateway.replaceRows(rows);
                    var rejected = false;
                    try { f.service.getView(); }
                    catch (FPWScheduler.Validation expected) { rejected = true; }
                    expect(rejected).toBeTrue();
                    expectRejected(f, {action="pause", taskId=task.id, revision=task.revision});
                }
            });

            it("automatically approves a new directly contained CFM script without adding authentication", function() {
                var script = folderFixture();
                fileWrite(script.file, '<cfoutput>{"ok":true,"purpose":"scheduler-folder-spec"}</cfoutput>', "utf-8");
                try {
                    var f = fixture(rows=[], configChanges={tasks=[]});
                    var endpoint = endpointAt(f.service.getView(), script.path);
                    expect(structIsEmpty(endpoint)).toBeFalse();
                    expect(endpoint.available).toBeTrue();
                    var input = newTaskInput();
                    input.endpointId = endpoint.id;
                    expect(f.service.mutate(input).success).toBeTrue();
                    expect(f.gateway.getExecuted()[1].url).toBe("http://localhost:8500/fpw" & script.path);
                    expect(find("?", f.gateway.getExecuted()[1].url)).toBe(0);
                    expect(f.service.getView().tasks[1].endpoint).toBe(script.path);
                } finally { if (fileExists(script.file)) fileDelete(script.file); }
            });

            it("refreshes folder approval and rejects a stale selection after the file is removed", function() {
                var script = folderFixture();
                fileWrite(script.file, '<cfoutput>{"ok":true}</cfoutput>', "utf-8");
                try {
                    var f = fixture(rows=[], configChanges={tasks=[]});
                    var endpoint = endpointAt(f.service.getView(), script.path);
                    expect(structIsEmpty(endpoint)).toBeFalse();
                    var input = newTaskInput();
                    input.endpointId = endpoint.id;
                    fileDelete(script.file);
                    expect(structIsEmpty(endpointAt(f.service.getView(), script.path))).toBeTrue();
                    expectRejected(f, input);
                } finally { if (fileExists(script.file)) fileDelete(script.file); }
            });

            it("excludes nested scripts and non-CFM files and rejects traversal and arbitrary endpoint IDs", function() {
                var script = folderFixture();
                var nested = script.root & script.name;
                var nonCfm = script.root & script.name & ".txt";
                directoryCreate(nested);
                fileWrite(nested & "/nested.cfm", '<cfoutput>{"ok":true}</cfoutput>', "utf-8");
                fileWrite(nonCfm, "scheduler-folder-spec", "utf-8");
                try {
                    var f = fixture(rows=[], configChanges={tasks=[]});
                    var view = f.service.getView();
                    expect(structIsEmpty(endpointAt(view, "/app/scheduled/" & script.name & "/nested.cfm"))).toBeTrue();
                    expect(structIsEmpty(endpointAt(view, "/app/scheduled/" & script.name & ".txt"))).toBeTrue();
                    for (var endpointId in ["../run-monitor.cfm", "/app/scheduled/run-monitor.cfm", "..%2Frun-monitor.cfm", "script-unregistered"] ) {
                        var input = newTaskInput();
                        input.endpointId = endpointId;
                        expectRejected(f, input);
                    }
                } finally {
                    if (fileExists(nonCfm)) fileDelete(nonCfm);
                    if (directoryExists(nested)) directoryDelete(nested, true);
                }
            });

            it("preserves the existing runner endpoint aliases during automatic folder discovery", function() {
                var f = fixture(rows=[], configChanges={tasks=[]});
                var view = f.service.getView();
                var aliases = {
                    "/app/scheduled/run-monitor.cfm"="monitor",
                    "/app/scheduled/run-departure-reminders.cfm"="departure-reminders",
                    "/app/scheduled/run-single-trip-expiration.cfm"="single-trip-expiration"
                };
                for (var path in aliases) {
                    var endpoint = endpointAt(view, path);
                    expect(structIsEmpty(endpoint)).toBeFalse();
                    expect(endpoint.id).toBe(aliases[path]);
                }
                var input = newTaskInput();
                input.endpointId = "MONITOR";
                var monitorToken = structKeyExists(application, "monitorToken") ? trim(toString(application.monitorToken)) : "";
                if (len(monitorToken)) {
                    expect(f.service.mutate(input).success).toBeTrue();
                    expect(f.gateway.getExecuted()[1].url).toBe("http://localhost:8500/fpw/app/scheduled/run-monitor.cfm?token=" & urlEncodedFormat(monitorToken));
                } else {
                    expect(f.service.mutate(input).success).toBeTrue();
                    expect(f.gateway.getExecuted()[1].url).toBe("http://localhost:8500/fpw/app/scheduled/run-monitor.cfm");
                }
            });

            it("uses the recovery runner's own settings and keeps new recovery schedules in dry-run mode", function() {
                var f = fixture(rows=[], configChanges={tasks=[]});
                var view = f.service.getView();
                var endpoint = endpointAt(view, "/app/scheduled/run-inactive-member-recovery.cfm");
                var settings = createObject("component", "fpw.api.v1.InactiveMemberRecoveryService").getRunnerSettings();
                expect(structIsEmpty(endpoint)).toBeFalse();
                expect(endpoint.id).toBe("inactive-member-recovery");
                expect(endpoint.available).toBeTrue();
                var input = newTaskInput();
                input.endpointId = endpoint.id;
                if (len(settings.token)) {
                    expect(find(settings.token, serializeJSON(view))).toBe(0);
                    expect(f.service.mutate(input).success).toBeTrue();
                    var target = f.gateway.getExecuted()[1].url;
                    expect(find("token=" & urlEncodedFormat(settings.token), target) GT 0).toBeTrue();
                    expect(findNoCase("dryRun=true", target) GT 0).toBeTrue();
                    expect(findNoCase("dryRun=false", target)).toBe(0);
                } else {
                    expect(f.service.mutate(input).success).toBeTrue();
                    expect(f.gateway.getExecuted()[1].url).toBe("http://localhost:8500/fpw/app/scheduled/run-inactive-member-recovery.cfm?dryRun=true");
                }
                for (var overrides in [{dryRun="false"}, {parameters={dryRun="false"}}, {batchSize="10"}, {token="SIMULATED_SECRET"}]) {
                    f = fixture(rows=[], configChanges={tasks=[]});
                    input = newTaskInput();
                    input.endpointId = endpoint.id;
                    structAppend(input, overrides, true);
                    expectRejected(f, input);
                }
            });

            it("discovers generic folder tasks only at the exact bare approved URL", function() {
                var script = folderFixture();
                fileWrite(script.file, '<cfoutput>{"ok":true}</cfoutput>', "utf-8");
                try {
                    var owned = baseRow();
                    owned.task = "Existing automatically approved script";
                    owned.url = "http://localhost:8500/fpw" & script.path;
                    var extra = duplicate(owned);
                    extra.task = "Extra query is not approved";
                    extra.url &= "?token=SIMULATED_SECRET";
                    var f = fixture(rows=[owned, extra], configChanges={tasks=[]});
                    var view = f.service.getView();
                    expect(arrayLen(view.tasks)).toBe(1);
                    expect(view.tasks[1].name).toBe(owned.task);
                    expect(view.tasks[1].canRun).toBeTrue();
                    expect(find("SIMULATED_SECRET", serializeJSON(view))).toBe(0);
                    var task = view.tasks[1];
                    fileDelete(script.file);
                    expectRejected(f, {action="run", taskId=task.id, revision=task.revision, confirmation=task.name});
                    expect(arrayLen(f.service.getView().tasks)).toBe(0);
                } finally { if (fileExists(script.file)) fileDelete(script.file); }
            });

            it("approves and creates all existing folder runners without requiring credentials", function() {
                for (var endpointId in ["monitor", "departure-reminders", "single-trip-expiration", "inactive-member-recovery"]) {
                    var f = fixture(rows=[], configChanges={tasks=[]});
                    var input = newTaskInput();
                    input.endpointId = endpointId;
                    var endpoint = endpointAt(f.service.getView(), "/app/scheduled/run-" & endpointId & ".cfm");
                    expect(endpoint.available).toBeTrue();
                    expect(f.service.getView().canCreate).toBeTrue();
                    expect(f.service.mutate(input).success).toBeTrue();
                    expect(arrayLen(f.service.getView().tasks)).toBe(1);
                }
            });

            it("keeps existing folder tasks manageable and preserves their URL regardless of runner token configuration", function() {
                for (var endpointId in ["monitor", "departure-reminders", "single-trip-expiration", "inactive-member-recovery"]) {
                    for (var suffix in ["", "?token=SIMULATED_EXISTING_TOKEN"]) {
                        var row = baseRow();
                        row.url = "http://localhost:8500/fpw/app/scheduled/run-" & endpointId & ".cfm" & suffix;
                        var f = fixture(rows=[row], configChanges={tasks=[]});
                        var view = f.service.getView();
                        expect(arrayLen(view.tasks)).toBe(1);
                        var task = view.tasks[1];
                        expect(task.actionable).toBeTrue();
                        expect(task.canRun).toBeTrue();
                        expect(find("SIMULATED_EXISTING_TOKEN", serializeJSON(view))).toBe(0);
                        var input = inputFor(f);
                        input.taskId = task.id;
                        input.endpointId = endpointId;
                        expect(f.service.mutate(input).success).toBeTrue();
                        expect(f.gateway.getExecuted()[1].url).toBe(row.url);
                    }
                }
            });

            it("keeps a configured identity reserved when its approved file disappears", function() {
                var script = folderFixture();
                fileWrite(script.file, '<cfoutput>{"ok":true}</cfoutput>', "utf-8");
                try {
                    var lookup = fixture(rows=[], configChanges={tasks=[]});
                    var endpoint = endpointAt(lookup.service.getView(), script.path);
                    var row = baseRow();
                    var f = fixture(rows=[row], configChanges={tasks=[{
                        id="manager-spec", name=row.task, mode=row.mode, group=row.group,
                        application="", endpointId=endpoint.id, allowCreate=false, parameters={}
                    }]});
                    fileDelete(script.file);
                    // The same identity now targets another valid endpoint, but cannot be adopted.
                    expect(arrayLen(f.service.getView().tasks)).toBe(0);
                    expectRejected(f, {action="pause", taskId="manager-spec", revision="untrusted"});
                } finally { if (fileExists(script.file)) fileDelete(script.file); }
            });

            it("preserves generic filename casing without borrowing registered runner authentication", function() {
                var script = folderFixture();
                script.file = script.root & script.name & ".CFM";
                script.path = "/app/scheduled/" & script.name & ".CFM";
                fileWrite(script.file, '<cfoutput>{"ok":true}</cfoutput>', "utf-8");
                try {
                    var f = fixture(rows=[], configChanges={tasks=[]});
                    var endpoint = endpointAt(f.service.getView(), script.path);
                    expect(structIsEmpty(endpoint)).toBeFalse();
                    expect(left(endpoint.id, 7)).toBe("script-");
                    var input = newTaskInput();
                    input.endpointId = uCase(endpoint.id);
                    expect(f.service.mutate(input).success).toBeTrue();
                    expect(f.gateway.getExecuted()[1].url).toBe("http://localhost:8500/fpw" & script.path);
                } finally { if (fileExists(script.file)) fileDelete(script.file); }
            });
        });
    }
}
