<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">
<cfheader name="Cache-Control" value="no-store">
<cfif NOT structKeyExists(request, "fpwAdminAuthorization")
    OR NOT isStruct(request.fpwAdminAuthorization)
    OR NOT structKeyExists(request.fpwAdminAuthorization, "authorized")
    OR NOT request.fpwAdminAuthorization.authorized>
    <cfheader statuscode="403">
    <cfoutput>Administrative access is required.</cfoutput>
    <cfabort>
</cfif>
<cfinclude template="../includes/fpw_base_path.cfm">
<cfscript>
// Application.cfc authorizes administrators and validates CSRF on every POST.
function scheduledTaskParameter(required struct source, required string key) {
    if (!structKeyExists(arguments.source, arguments.key) OR !isSimpleValue(arguments.source[arguments.key])) {
        return "";
    }
    return trim(toString(arguments.source[arguments.key]));
}

pageUrl = request.fpwBase & "/admin/scheduled-tasks.cfm";
requestMethod = structKeyExists(cgi, "request_method") ? uCase(toString(cgi.request_method)) : "GET";
csrfToken = structKeyExists(request, "fpwAdminCsrfToken") ? toString(request.fpwAdminCsrfToken) : "";
schedulerService = "";
schedulerView = {
    "available" = false, "message" = "The scheduler could not be inspected. No scheduler details are exposed.",
    "environment" = "Unavailable", "engine" = "Unavailable", "timezone" = "Unavailable",
    "timezoneId" = "", "schedulerClock" = "",
    "readOnly" = true, "diagnostics" = [], "tasks" = [], "createOptions" = [],
    "canCreate" = false, "createDefaults" = {}, "scopes" = [], "endpoints" = []
};
flashResult = {};
try {
    schedulerService = new fpw.api.v1.AdminScheduledTaskService().init();
    if (requestMethod EQ "POST") {
        flashResult = schedulerService.mutate(form);
    } else {
        schedulerView = schedulerService.getView();
    }
} catch (any schedulerPageError) {
    // Scheduler exceptions can contain authentication and unrelated task details.
    if (requestMethod EQ "POST") {
        flashResult = { "success" = false, "message" = "The scheduler request could not be completed. Refresh the listing before trying again." };
    }
}

if (requestMethod EQ "POST") {
    flashToken = createUUID();
    session.fpwScheduledTaskFlash = {
        "token" = flashToken,
        "success" = flashResult.success,
        "message" = flashResult.message
    };
    if (!flashResult.success AND listFindNoCase("create,edit", scheduledTaskParameter(form, "action"))) {
        // Retain only form fields; never copy raw request data, URLs, CSRF or confirmation text.
        session.fpwScheduledTaskFlash.editor = {};
        for (flashField in listToArray("action,taskId,taskName,mode,group,endpointId,frequencyMode,recurrence,intervalHours,intervalMinutes,intervalSeconds,startDate,endDate,startTime,endTime,timeout")) {
            session.fpwScheduledTaskFlash.editor[flashField] = left(scheduledTaskParameter(form, flashField), 128);
        }
    }
    location(url=pageUrl & "?result=" & urlEncodedFormat(flashToken), addToken=false, statusCode=303);
}

if (structKeyExists(session, "fpwScheduledTaskFlash") AND isStruct(session.fpwScheduledTaskFlash)
    AND structKeyExists(session.fpwScheduledTaskFlash, "token")
    AND compare(toString(session.fpwScheduledTaskFlash.token), scheduledTaskParameter(url, "result")) EQ 0) {
    flashResult = duplicate(session.fpwScheduledTaskFlash);
    structDelete(session, "fpwScheduledTaskFlash", false);
}

selectedTask = {};
selectionMessage = "";
editId = scheduledTaskParameter(url, "edit");
createRequested = scheduledTaskParameter(url, "create") EQ "1";
confirmId = scheduledTaskParameter(url, "taskId");
confirmAction = lCase(scheduledTaskParameter(url, "confirmAction"));
isConfirmation = listFindNoCase("run,delete", confirmAction) GT 0;
canManage = schedulerView.available AND NOT schedulerView.readOnly;
canCreate = canManage AND structKeyExists(schedulerView, "canCreate") AND schedulerView.canCreate;
retainedEditor = structKeyExists(flashResult, "editor") AND isStruct(flashResult.editor) ? flashResult.editor : {};
if (structCount(retainedEditor)) {
    createRequested = scheduledTaskParameter(retainedEditor, "action") EQ "create";
    editId = scheduledTaskParameter(retainedEditor, "action") EQ "edit" ? scheduledTaskParameter(retainedEditor, "taskId") : "";
    isConfirmation = false;
}
if (canManage) {
    for (candidateTask in schedulerView.tasks) {
        candidateCanRun = structKeyExists(candidateTask, "canRun") AND candidateTask.canRun;
        if ((len(editId) AND compare(candidateTask.id, editId) EQ 0 AND candidateTask.editable)
            OR (isConfirmation AND compare(candidateTask.id, confirmId) EQ 0
                AND ((confirmAction EQ "run" AND candidateCanRun) OR (confirmAction EQ "delete" AND candidateTask.actionable)))) {
            selectedTask = candidateTask;
            break;
        }
    }
}
showConfirmation = canManage AND isConfirmation AND structCount(selectedTask) GT 0;
showEdit = canManage AND NOT isConfirmation AND len(editId) AND structCount(selectedTask) GT 0;
showCreate = canCreate AND NOT isConfirmation AND NOT len(editId) AND createRequested;
if ((len(editId) OR createRequested OR len(confirmAction)) AND NOT showConfirmation AND NOT showEdit AND NOT showCreate) {
    selectionMessage = "This task or operation is not currently available. Review the refreshed scheduler listing below.";
}
if (showEdit OR showCreate) {
    editorAction = showEdit ? "edit" : "create";
    editorTask = showEdit ? selectedTask : schedulerView.createDefaults;
    editorFields = {
        "taskName" = showEdit ? editorTask.name : editorTask.namePrefix,
        "mode" = editorTask.mode, "group" = editorTask.group,
        "endpointId" = showEdit ? editorTask.endpointId : "",
        "frequencyMode" = showEdit AND editorTask.scheduleType EQ "seconds" ? "seconds" : (showEdit AND editorTask.scheduleType EQ "once" ? "once" : "recurring"),
        "recurrence" = showEdit AND listFindNoCase("daily,weekly,monthly", editorTask.scheduleType) ? editorTask.scheduleType : "daily",
        "intervalHours" = showEdit ? scheduledTaskParameter(editorTask, "intervalHours") : "0",
        "intervalMinutes" = showEdit ? scheduledTaskParameter(editorTask, "intervalMinutes") : "5",
        "intervalSeconds" = showEdit ? scheduledTaskParameter(editorTask, "intervalSeconds") : "0",
        "startDate" = showEdit ? editorTask.startDate : "",
        "endDate" = showEdit ? scheduledTaskParameter(editorTask, "endDate") : "",
        "startTime" = showEdit ? editorTask.startTime : "",
        "endTime" = showEdit ? scheduledTaskParameter(editorTask, "endTime") : "",
        "timeout" = showEdit ? editorTask.timeout : "60"
    };
    for (retainedField in editorFields) {
        // Identity and endpoint are immutable when editing an existing task.
        if (structKeyExists(retainedEditor, retainedField)
            AND !(showEdit AND listFindNoCase("taskName,mode,group,endpointId", retainedField))) {
            editorFields[retainedField] = retainedEditor[retainedField];
        }
    }
    if (!listFindNoCase("seconds,once,recurring", editorFields.frequencyMode)) editorFields.frequencyMode = "recurring";
    if (!listFindNoCase("daily,weekly,monthly", editorFields.recurrence)) editorFields.recurrence = "daily";
    editorEndpointUrl = showEdit ? scheduledTaskParameter(editorTask, "endpointUrl") : "";
    editorScopeFound = showEdit;
    editorSecondsSupported = showEdit AND structKeyExists(editorTask, "secondsSupported") AND editorTask.secondsSupported;
    for (editorScope in schedulerView.scopes) {
        if (compare(editorScope.id, editorFields.mode) EQ 0) {
            editorScopeFound = true;
            if (!showEdit) editorSecondsSupported = editorScope.secondsSupported;
        }
    }
    if (!editorScopeFound AND arrayLen(schedulerView.scopes)) {
        editorFields.mode = schedulerView.scopes[1].id;
        editorSecondsSupported = schedulerView.scopes[1].secondsSupported;
    }
    editorEndpointFound = false;
    for (editorEndpoint in schedulerView.endpoints) {
        if (compare(editorEndpoint.id, editorFields.endpointId) EQ 0) {
            editorEndpointFound = true;
            editorEndpointUrl = editorEndpoint.url;
        }
    }
    if (!editorEndpointFound) editorFields.endpointId = "";
    editorRevision = showEdit ? editorTask.revision : "";
}

</cfscript>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Admin Scheduled Tasks</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" crossorigin="anonymous">
  <style>
    body{margin:24px;background:#f7f7f7;color:#111;font-family:Arial,sans-serif}
    .admin-wrap{max-width:1560px;margin:0 auto;padding:20px;border:1px solid #ddd;border-radius:8px;background:#fff}
    .scheduler-editor{max-width:1120px}
    .scheduler-editor legend{float:none;width:auto;font-size:1.1rem;font-weight:600}
    .scheduler-interval{max-width:120px}
    .scheduler-url{overflow-wrap:anywhere}
    .scheduler-frequency-row{padding:12px 0;border-bottom:1px solid #eee}
    .scheduler-actions{display:flex;flex-wrap:wrap;gap:6px;min-width:180px}
    .scheduler-actions form{margin:0}
    .scheduler-identity{overflow-wrap:anywhere}
    .scheduler-table{font-size:.9rem}
    .scheduler-table td{vertical-align:top}
    @media(max-width:640px){body{margin:10px}.admin-wrap{padding:12px}}
  </style>
</head>
<body>
<div class="admin-wrap">
  <cfinclude template="includes/admin_reports_nav.cfm">
  <h1 class="h3 mb-1">Scheduled Tasks</h1>
  <p class="text-muted">Create and manage FloatPlanWizard schedules in the ColdFusion scheduler.</p>
  <cfoutput>
    <cfif structKeyExists(flashResult, "message")>
      <div class="alert <cfif flashResult.success>alert-success<cfelse>alert-warning</cfif>" role="status">#encodeForHTML(flashResult.message)#</div>
    </cfif>
    <cfif len(selectionMessage)><div class="alert alert-warning" role="status">#encodeForHTML(selectionMessage)#</div></cfif>
    <div class="border rounded p-3 mb-3">
      <dl class="row mb-0">
        <dt class="col-sm-3">Environment</dt><dd class="col-sm-9">#encodeForHTML(schedulerView.environment)#</dd>
        <dt class="col-sm-3">ColdFusion version</dt><dd class="col-sm-9">#encodeForHTML(schedulerView.engine)#</dd>
        <dt class="col-sm-3">Effective scheduler timezone</dt><dd class="col-sm-9">#encodeForHTML(schedulerView.timezone)#</dd>
      </dl>
      <p class="small text-muted mb-0">Start dates and times use the scheduler timezone shown above. Browser time and application UTC handling do not set this timezone.</p>
    </div>
    <cfif len(schedulerView.message)>
      <div class="alert <cfif schedulerView.available>alert-info<cfelse>alert-warning</cfif>" role="status">#encodeForHTML(schedulerView.message)#</div>
    </cfif>
    <cfif schedulerView.readOnly>
      <div class="alert alert-secondary">Read-only inspection is enabled. Schedule changes and Run Now are unavailable.</div>
    </cfif>
    <cfif arrayLen(schedulerView.diagnostics)>
      <ul class="small text-muted">
        <cfloop array="#schedulerView.diagnostics#" index="diagnostic"><li>#encodeForHTML(diagnostic)#</li></cfloop>
      </ul>
    </cfif>
    <p class="small">Run Now reports <strong>Run requested</strong> when ColdFusion accepts the request. It does not confirm that the job completed successfully.</p>

    <cfif showConfirmation>
      <section class="scheduler-editor border rounded p-3 mb-4" aria-labelledby="confirm-heading">
        <h2 id="confirm-heading" class="h5"><cfif confirmAction EQ "run">Confirm Run Now<cfelse>Confirm Delete</cfif></h2>
        <p>Task: <strong class="scheduler-identity">#encodeForHTML(selectedTask.name)#</strong></p>
        <p>Approved endpoint: <code>#encodeForHTML(selectedTask.endpoint)#</code></p>
        <div class="alert alert-warning">
          <cfif confirmAction EQ "run">This task may send real notifications. ColdFusion will receive an immediate run request.
          <cfelse>Deleting this schedule stops its future scheduled runs. This does not cancel work already running.</cfif>
        </div>
        <form method="post" action="#encodeForHTMLAttribute(pageUrl)#">
          <input type="hidden" name="adminCsrfToken" value="#encodeForHTMLAttribute(csrfToken)#">
          <input type="hidden" name="action" value="#encodeForHTMLAttribute(confirmAction)#">
          <input type="hidden" name="taskId" value="#encodeForHTMLAttribute(selectedTask.id)#">
          <input type="hidden" name="revision" value="#encodeForHTMLAttribute(selectedTask.revision)#">
          <label for="task-confirmation" class="form-label">Type the exact task name to confirm</label>
          <input id="task-confirmation" name="confirmation" class="form-control mb-3" type="text" autocomplete="off" required>
          <button type="submit" class="btn btn-danger"><cfif confirmAction EQ "run">Request Run Now<cfelse>Delete Schedule</cfif></button>
          <a class="btn btn-outline-secondary" href="#encodeForHTMLAttribute(pageUrl)#">Cancel</a>
        </form>
      </section>
    <cfelseif showEdit OR showCreate>
      <section class="scheduler-editor border rounded p-3 mb-4" aria-labelledby="editor-heading">
        <h2 id="editor-heading" class="h5 mb-4"><cfif showEdit>Edit Scheduled Task<cfelse>Add Scheduled Task</cfif></h2>
        <form id="scheduled-task-editor" method="post" action="#encodeForHTMLAttribute(pageUrl)#" data-seconds-supported="#editorSecondsSupported ? 'true' : 'false'#">
          <input type="hidden" name="adminCsrfToken" value="#encodeForHTMLAttribute(csrfToken)#">
          <input type="hidden" name="action" value="#editorAction#">
          <cfif showEdit>
            <input type="hidden" name="taskId" value="#encodeForHTMLAttribute(editorTask.id)#">
            <input type="hidden" name="revision" value="#encodeForHTMLAttribute(editorRevision)#">
            <input type="hidden" name="endpointId" value="#encodeForHTMLAttribute(editorTask.endpointId)#">
          </cfif>
          <div class="row g-3 align-items-start mb-3">
            <label for="schedule-name" class="col-sm-3 col-form-label fw-semibold">Task Name</label>
            <div class="col-sm-9">
              <input id="schedule-name" <cfif showCreate>name="taskName"</cfif> type="text" class="form-control" maxlength="60" required value="#encodeForHTMLAttribute(editorFields.taskName)#"<cfif showEdit> readonly<cfelse> pattern="[A-Za-z0-9_ .\-]+"</cfif> aria-describedby="schedule-name-help">
              <div id="schedule-name-help" class="form-text"><cfif showEdit>The task name, group and scope cannot be changed after creation.<cfelse>Enter a unique name beginning with #encodeForHTML(schedulerView.createDefaults.namePrefix)#. Use letters, numbers, spaces, underscores, periods or hyphens.</cfif></div>
            </div>
            <label for="schedule-group" class="col-sm-3 col-form-label fw-semibold">Group</label>
            <div class="col-sm-9">
              <input id="schedule-group" <cfif showCreate>name="group"</cfif> type="text" class="form-control" maxlength="40" value="#encodeForHTMLAttribute(editorFields.group)#"<cfif showEdit> readonly<cfelse> required pattern="[A-Za-z0-9_ .\-]+"</cfif>>
            </div>
            <label for="schedule-scope" class="col-sm-3 col-form-label fw-semibold">Scope</label>
            <div class="col-sm-9">
              <cfif showEdit>
                <input id="schedule-scope" type="text" class="form-control" readonly value="#encodeForHTMLAttribute(editorFields.mode)#">
              <cfelse>
                <select id="schedule-scope" name="mode" class="form-select" required>
                  <cfloop array="#schedulerView.scopes#" index="scopeOption">
                    <option value="#encodeForHTMLAttribute(scopeOption.id)#" data-seconds-supported="#scopeOption.secondsSupported ? 'true' : 'false'#"<cfif editorFields.mode EQ scopeOption.id> selected</cfif>>#encodeForHTML(scopeOption.label)#</option>
                  </cfloop>
                </select>
              </cfif>
            </div>
            <label for="schedule-script" class="col-sm-3 col-form-label fw-semibold">Script to run</label>
            <div class="col-sm-9">
              <cfif showEdit>
                <input id="schedule-script" type="text" class="form-control" readonly value="#encodeForHTMLAttribute(editorEndpointUrl)#">
                <div class="form-text">#encodeForHTML(editorTask.endpoint)# &mdash; the existing runner binding is preserved.</div>
              <cfelse>
                <select id="schedule-script" name="endpointId" class="form-select" required aria-describedby="schedule-script-help">
                  <option value="">Choose an approved FPW script</option>
                  <cfloop array="#schedulerView.endpoints#" index="endpointOption">
                    <option value="#encodeForHTMLAttribute(endpointOption.id)#"<cfif editorFields.endpointId EQ endpointOption.id> selected</cfif>>#encodeForHTML(endpointOption.label)# &mdash; #encodeForHTML(endpointOption.url)#</option>
                  </cfloop>
                </select>
                <div id="schedule-script-help" class="form-text">Every CFM script directly in /app/scheduled is automatically approved for scheduling.</div>
              </cfif>
            </div>
          </div>
          <fieldset class="border-top pt-3 mb-3">
            <legend>Duration</legend>
            <div class="row g-3">
              <div class="col-sm-6">
                <label for="schedule-date" class="form-label">Start Date</label>
                <input id="schedule-date" name="startDate" type="date" class="form-control" min="2000-01-01" max="2099-12-31" required value="#encodeForHTMLAttribute(editorFields.startDate)#">
              </div>
              <div class="col-sm-6">
                <label for="schedule-end-date" class="form-label">End Date (optional)</label>
                <input id="schedule-end-date" name="endDate" type="date" class="form-control" min="2000-01-01" max="2099-12-31" value="#encodeForHTMLAttribute(editorFields.endDate)#">
              </div>
            </div>
          </fieldset>
          <fieldset class="border-top pt-3 mb-3">
            <legend>Frequency</legend>
            <div class="scheduler-frequency-row">
              <div class="form-check mb-2">
                <input id="frequency-seconds" name="frequencyMode" class="form-check-input" type="radio" value="seconds"<cfif editorFields.frequencyMode EQ "seconds"> checked</cfif><cfif NOT editorSecondsSupported> disabled</cfif>>
                <label for="frequency-seconds" class="form-check-label fw-semibold">Every</label>
              </div>
              <div class="d-flex flex-wrap gap-3 ms-4">
                <div class="scheduler-interval"><label for="interval-hours" class="form-label">Hours</label><input id="interval-hours" name="intervalHours" type="number" class="form-control" min="0" max="8760" step="1" value="#encodeForHTMLAttribute(editorFields.intervalHours)#"></div>
                <div class="scheduler-interval"><label for="interval-minutes" class="form-label">Minutes</label><input id="interval-minutes" name="intervalMinutes" type="number" class="form-control" min="0" max="59" step="1" value="#encodeForHTMLAttribute(editorFields.intervalMinutes)#"></div>
                <div class="scheduler-interval"><label for="interval-seconds" class="form-label">Seconds</label><input id="interval-seconds" name="intervalSeconds" type="number" class="form-control" min="0" max="59" step="1" value="#encodeForHTMLAttribute(editorFields.intervalSeconds)#"></div>
              </div>
              <div id="interval-help" class="form-text ms-4"><cfif editorSecondsSupported>Enter a total interval of at least 60 seconds.<cfelse>Interval schedules are unavailable because the scheduler cannot safely report their daily-window setting.</cfif></div>
            </div>
            <div class="scheduler-frequency-row">
              <div class="form-check">
                <input id="frequency-once" name="frequencyMode" class="form-check-input" type="radio" value="once"<cfif editorFields.frequencyMode EQ "once"> checked</cfif>>
                <label for="frequency-once" class="form-check-label fw-semibold">One-Time</label>
              </div>
            </div>
            <div class="scheduler-frequency-row">
              <div class="row align-items-center g-2">
                <div class="col-sm-4"><div class="form-check"><input id="frequency-recurring" name="frequencyMode" class="form-check-input" type="radio" value="recurring"<cfif editorFields.frequencyMode EQ "recurring"> checked</cfif>><label for="frequency-recurring" class="form-check-label fw-semibold">Recurring</label></div></div>
                <div class="col-sm-5"><label for="schedule-recurrence" class="visually-hidden">Recurrence</label><select id="schedule-recurrence" name="recurrence" class="form-select"><cfloop list="daily,weekly,monthly" index="recurrenceOption"><option value="#recurrenceOption#"<cfif editorFields.recurrence EQ recurrenceOption> selected</cfif>>#encodeForHTML(uCase(left(recurrenceOption, 1)) & mid(recurrenceOption, 2, len(recurrenceOption)))#</option></cfloop></select></div>
              </div>
            </div>
            <div class="row g-3 mt-1">
              <div class="col-sm-6">
                <label for="schedule-time" class="form-label">Start Time (#encodeForHTML(schedulerView.timezoneId)#)</label>
                <input id="schedule-time" name="startTime" type="time" class="form-control" step="1" required aria-describedby="schedule-time-help" value="#encodeForHTMLAttribute(editorFields.startTime)#">
                <div id="schedule-time-help" class="form-text">Current #encodeForHTML(schedulerView.timezoneId)# time: <strong>#encodeForHTML(schedulerView.schedulerClock)#</strong> (when this page loaded).</div>
              </div>
              <div class="col-sm-6"><label for="schedule-end-time" class="form-label">End Time (optional, interval schedules only)</label><input id="schedule-end-time" name="endTime" type="time" class="form-control" step="1" value="#encodeForHTMLAttribute(editorFields.endTime)#"></div>
            </div>
            <p class="form-text mt-3 mb-1">Use the effective scheduler timezone shown above. New and one-time schedules must start after the current scheduler date and time. A later time today is allowed.</p>
            <p class="form-text mb-0">Recurring schedules repeat until their end date, if provided. Cron expressions and finite repeat counts are not editable in this manager.</p>
          </fieldset>
          <div class="row g-3 border-top pt-3 mb-3">
            <label for="schedule-timeout" class="col-sm-6 col-form-label fw-semibold">Request timeout in seconds</label>
            <div class="col-sm-6"><input id="schedule-timeout" name="timeout" type="number" class="form-control" min="1" max="3600" step="1" required value="#encodeForHTMLAttribute(editorFields.timeout)#"></div>
          </div>
          <cfif showEdit><p class="small text-muted">Existing settings outside this form are preserved when an edit can be safely applied.</p></cfif>
          <button type="submit" class="btn btn-primary"><cfif showEdit>Save Schedule<cfelse>Create Schedule</cfif></button>
          <a class="btn btn-outline-secondary" href="#encodeForHTMLAttribute(pageUrl)#">Cancel</a>
        </form>
      </section>
    </cfif>

    <div class="d-flex justify-content-between align-items-center mb-2">
      <h2 class="h5 mb-0">Existing FPW tasks</h2>
      <div class="d-flex flex-wrap gap-2">
        <cfif canCreate><a class="btn btn-primary btn-sm" href="#encodeForHTMLAttribute(pageUrl & '?create=1')#">New Scheduled Task</a></cfif>
        <a class="btn btn-outline-secondary btn-sm" href="#encodeForHTMLAttribute(pageUrl)#">Refresh scheduler state</a>
      </div>
    </div>
    <div class="table-responsive">
      <table class="table table-bordered scheduler-table">
        <thead class="table-light"><tr><th scope="col">Task / scope</th><th scope="col">Approved endpoint</th><th scope="col">Frequency</th><th scope="col">Start date / time</th><th scope="col">Timeout</th><th scope="col">Paused</th><th scope="col">Actions</th></tr></thead>
        <tbody>
          <cfloop array="#schedulerView.tasks#" index="listedTask">
            <tr>
              <td class="scheduler-identity"><strong>#encodeForHTML(listedTask.name)#</strong><div class="small text-muted">#encodeForHTML(listedTask.mode)# &middot; Group: <cfif len(listedTask.group)>#encodeForHTML(listedTask.group)#<cfelse>Default</cfif></div></td>
              <td><code>#encodeForHTML(listedTask.endpoint)#</code></td>
              <td>#encodeForHTML(listedTask.frequency)#</td>
              <td><cfif len(listedTask.startDate)>#encodeForHTML(listedTask.startDate)#<cfelse>Unavailable</cfif><br><cfif len(listedTask.startTime)>#encodeForHTML(listedTask.startTime)#<cfelse>Unavailable</cfif></td>
              <td><cfif isNumeric(listedTask.timeout)>#encodeForHTML(toString(listedTask.timeout))# s<cfelse>Unavailable</cfif></td>
              <td>#encodeForHTML(listedTask.paused)#</td>
              <td>
                <div class="scheduler-actions">
                  <cfif canManage AND listedTask.editable>
                    <a class="btn btn-outline-primary btn-sm" href="#encodeForHTMLAttribute(pageUrl & '?edit=' & urlEncodedFormat(listedTask.id))#">Edit</a>
                  </cfif>
                  <cfif canManage AND listedTask.actionable>
                    <cfloop list="pause,resume" index="statusAction">
                      <cfif (statusAction EQ "pause" AND listedTask.paused NEQ "Yes") OR (statusAction EQ "resume" AND listedTask.paused NEQ "No")>
                        <form method="post" action="#encodeForHTMLAttribute(pageUrl)#">
                          <input type="hidden" name="adminCsrfToken" value="#encodeForHTMLAttribute(csrfToken)#">
                          <input type="hidden" name="action" value="#statusAction#">
                          <input type="hidden" name="taskId" value="#encodeForHTMLAttribute(listedTask.id)#">
                          <input type="hidden" name="revision" value="#encodeForHTMLAttribute(listedTask.revision)#">
                          <button type="submit" class="btn btn-outline-secondary btn-sm"><cfif statusAction EQ "pause">Pause<cfelse>Resume</cfif></button>
                        </form>
                      </cfif>
                    </cfloop>
                    <a class="btn btn-outline-danger btn-sm" href="#encodeForHTMLAttribute(pageUrl & '?confirmAction=delete&taskId=' & urlEncodedFormat(listedTask.id))#">Delete</a>
                  </cfif>
                  <cfif canManage AND structKeyExists(listedTask, "canRun") AND listedTask.canRun>
                    <a class="btn btn-outline-warning btn-sm" href="#encodeForHTMLAttribute(pageUrl & '?confirmAction=run&taskId=' & urlEncodedFormat(listedTask.id))#">Run Now</a>
                  </cfif>
                  <cfif NOT canManage OR (NOT listedTask.actionable AND NOT listedTask.editable AND NOT (structKeyExists(listedTask, "canRun") AND listedTask.canRun))>
                    <span class="text-muted">Read-only</span>
                  </cfif>
                </div>
                <cfif len(listedTask.reason)><div class="small text-muted mt-2">#encodeForHTML(listedTask.reason)#</div></cfif>
                <cfif canManage AND listedTask.actionable AND structKeyExists(listedTask,"runUnavailableReason") AND len(listedTask.runUnavailableReason)><div class="small text-muted mt-2">#encodeForHTML(listedTask.runUnavailableReason)#</div></cfif>
              </td>
            </tr>
          </cfloop>
          <cfif NOT arrayLen(schedulerView.tasks)>
            <tr><td colspan="7" class="text-muted"><cfif schedulerView.available>No owned FPW tasks were returned by the scheduler.<cfelse>The FPW task listing is unavailable.</cfif></td></tr>
          </cfif>
        </tbody>
      </table>
    </div>
  </cfoutput>
</div>
<script>
(function () {
  "use strict";
  var editor = document.getElementById("scheduled-task-editor");
  if (!editor) return;
  var scope = document.getElementById("schedule-scope");
  var secondsRadio = document.getElementById("frequency-seconds");
  var recurringRadio = document.getElementById("frequency-recurring");
  var intervalInputs = ["interval-hours", "interval-minutes", "interval-seconds"];
  function updateFrequency() {
    var secondsSupported = editor.dataset.secondsSupported === "true";
    if (scope && scope.tagName === "SELECT" && scope.selectedIndex >= 0) {
      secondsSupported = scope.options[scope.selectedIndex].dataset.secondsSupported === "true";
    }
    secondsRadio.disabled = !secondsSupported;
    if (!secondsSupported && secondsRadio.checked) recurringRadio.checked = true;
    intervalInputs.forEach(function (id) {
      document.getElementById(id).disabled = !secondsRadio.checked || !secondsSupported;
    });
    document.getElementById("schedule-end-time").disabled = !secondsRadio.checked || !secondsSupported;
    document.getElementById("schedule-recurrence").disabled = !recurringRadio.checked;
    document.getElementById("interval-help").textContent = secondsSupported
      ? "Enter a total interval of at least 60 seconds."
      : "Interval schedules are unavailable because the scheduler cannot safely report their daily-window setting.";
  }
  editor.addEventListener("change", function (event) {
    if (event.target.name === "frequencyMode" || event.target.id === "schedule-scope") updateFrequency();
  });
  updateFrequency();
}());
</script>
</body>
</html>
