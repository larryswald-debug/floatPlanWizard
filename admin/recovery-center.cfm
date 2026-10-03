<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">
<cfheader name="Cache-Control" value="no-store">
<cfif NOT structKeyExists(request,"fpwAdminAuthorization") OR NOT isStruct(request.fpwAdminAuthorization)
  OR NOT structKeyExists(request.fpwAdminAuthorization,"authorized") OR NOT request.fpwAdminAuthorization.authorized>
  <cfheader statuscode="403"><cfoutput>Administrative access is required.</cfoutput><cfabort>
</cfif>
<cfinclude template="../includes/fpw_base_path.cfm">
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Recovery Center — FloatPlanWizard</title>
  <cfoutput><link rel="stylesheet" href="#encodeForHTMLAttribute(request.fpwBase)#/assets/css/admin-recovery-center.css?v=20261003"></cfoutput>
</head>
<body>
<cfinclude template="includes/admin_reports_nav.cfm">
<cfoutput><main id="recoveryCenter" data-endpoint="#encodeForHTMLAttribute(request.fpwBase)#/admin/recovery-center-data.cfm"></cfoutput>
  <header class="rc-header"><div><p class="rc-eyebrow">MEMBER SUPPORT</p><h1>Recovery Center</h1><p>Three recovery contacts. Each message uses the member’s current verified destination.</p></div><button type="button" id="rcRefresh">Refresh view</button></header>
  <div id="rcStatus" role="status" aria-live="polite" class="rc-notice" hidden></div>
  <nav class="rc-tabs" aria-label="Recovery Center views" role="tablist">
    <button id="rcTabDashboard" role="tab" aria-selected="true" aria-controls="rcDashboard" data-tab="dashboard">Dashboard</button>
    <button id="rcTabQueue" role="tab" aria-selected="false" aria-controls="rcQueue" data-tab="queue" tabindex="-1">Recovery Queue</button>
    <button id="rcTabRuns" role="tab" aria-selected="false" aria-controls="rcRuns" data-tab="runs" tabindex="-1">Runs</button>
    <button id="rcTabMembers" role="tab" aria-selected="false" aria-controls="rcMembers" data-tab="members" tabindex="-1">Members</button>
    <button id="rcTabPerformance" role="tab" aria-selected="false" aria-controls="rcPerformance" data-tab="performance" tabindex="-1">Performance</button>
    <button id="rcTabSettings" role="tab" aria-selected="false" aria-controls="rcSettings" data-tab="settings" tabindex="-1">Settings</button>
  </nav>
  <section id="rcDashboard" role="tabpanel" aria-labelledby="rcTabDashboard">
    <h2>Recovery overview</h2><p class="rc-muted">Current member eligibility and accepted-message cohorts are separate observations. All timestamps are UTC.</p>
    <div id="rcMetrics" class="rc-metrics"></div>
    <div class="rc-grid"><section class="rc-card"><h3>Recovery funnel</h3><div id="rcFunnel"></div><p class="rc-muted">Opens and clicks can be automated. A member may return without an observed open or click. Engagement after a contact does not establish causation.</p></section>
    <section class="rc-card"><h3>Current timing &amp; last run</h3><div id="rcTimingSummary"></div><div id="rcLastRun"></div></section></div>
    <h3>Needs attention</h3><p class="rc-muted">Failures appear immediately. Unanswered messages are flagged when their frozen attribution window closes.</p><div id="rcAttention"></div>
  </section>
  <section id="rcQueue" role="tabpanel" aria-labelledby="rcTabQueue" hidden>
    <h2>Recovery queue</h2><form id="rcQueueFilter" class="rc-filters">
      <label>Search member<input name="search" type="search" maxlength="160" placeholder="Name, email or member ID"></label>
      <label>Destination stage<select name="destinationStage"><option value="">All stages</option><option>A</option><option>B</option><option>C</option><option>D</option></select></label>
      <label>Next contact<select name="contactNumber"><option value="">All contacts</option><option value="1">#1 of 3</option><option value="2">#2 of 3</option><option value="3">#3 of 3</option></select></label>
      <label>Decision<input name="decision" placeholder="e.g. ELIGIBLE" maxlength="80"></label>
      <label>Recovery state<select name="status"><option value="">All states</option><option value="paused">Paused</option><option value="excluded">Excluded</option><option value="complete">Sequence complete</option><option value="attention">Needs attention</option></select></label>
      <button type="submit">Apply filters</button>
    </form><p id="rcQueueEvaluated" class="rc-muted"></p><div id="rcQueueTable"></div><div id="rcQueuePager" class="rc-pager"></div>
  </section>
  <section id="rcRuns" role="tabpanel" aria-labelledby="rcTabRuns" hidden>
    <h2>Recovery runs</h2><p class="rc-muted">Dry runs record decisions without claiming a contact or sending mail. Incomplete runs retain their incomplete status.</p>
    <div id="rcRunsTable"></div><div id="rcRunsPager" class="rc-pager"></div><section id="rcRunDetail" class="rc-card" hidden></section>
  </section>
  <section id="rcMembers" role="tabpanel" aria-labelledby="rcTabMembers" hidden>
    <h2>Members</h2><form id="rcMemberFilter" class="rc-filters"><label>Search member<input type="search" name="search" maxlength="160" placeholder="Name, email or member ID"></label><button type="submit">Search</button></form>
    <div id="rcMembersTable"></div><div id="rcMembersPager" class="rc-pager"></div>
    <section id="rcMemberDetail" class="rc-card" hidden>
      <h3 id="rcMemberHeading">Member detail</h3><div id="rcMemberContext"></div>
      <div id="rcMemberControls" class="rc-actions"></div>
      <h4>Current message preview</h4><button id="rcPreviewCurrent" type="button">Preview next contact</button>
      <h4>Message history</h4><div id="rcMemberMessages"></div>
      <h4>Eligibility history</h4><div id="rcMemberEvaluations"></div>
      <h4>Activity &amp; recovery timeline</h4><div id="rcTimeline"></div>
      <section class="rc-composer"><h4>Personal follow-up</h4><p class="rc-muted">This message is separate from automated contacts. Pause, exclusion, and email preferences apply. The recipient is selected from the member record.</p>
        <form id="rcPersonalForm"><label for="rcPersonalSubject">Subject</label><input id="rcPersonalSubject" name="subject" maxlength="160" required>
          <label for="rcPersonalBody">Message (plain text)</label><textarea id="rcPersonalBody" name="body" rows="7" maxlength="10000" required></textarea>
          <button type="submit">Review personal follow-up</button>
        </form>
        <div id="rcPersonalReview" class="rc-notice" hidden><div id="rcPersonalReviewSummary"></div><label><input id="rcPersonalConfirm" type="checkbox"> I reviewed the recipient and content and authorize this personal follow-up.</label><button id="rcPersonalSend" type="button" disabled>Send reviewed follow-up</button></div>
      </section>
    </section>
  </section>
  <section id="rcPerformance" role="tabpanel" aria-labelledby="rcTabPerformance" hidden>
    <h2>Recovery performance</h2><form id="rcPerformanceFilter" class="rc-filters">
      <label>Accepted-message cohort<select name="days"><option value="7">Last 7 days</option><option value="30" selected>Last 30 days</option><option value="90">Last 90 days</option><option value="0">All history</option></select></label>
      <label>Contact<select name="contactNumber"><option value="">All contacts</option><option value="1">#1</option><option value="2">#2</option><option value="3">#3</option></select></label>
      <label>Destination stage<select name="destinationStage"><option value="">All stages</option><option>A</option><option>B</option><option>C</option><option>D</option></select></label>
      <label>Template<input name="templateId" maxlength="100" placeholder="Template ID"></label>
      <button type="submit">Apply filters</button></form>
    <p class="rc-muted">Rates use accepted automated messages as the denominator. Opens, clicks, returns and engagement are independent signals; “accepted” is the SMTP result, not proof of delivery or readership.</p>
    <div id="rcPerformanceSummary" class="rc-metrics"></div><div id="rcPerformanceTable"></div><h3>Activity in the selected period</h3><div id="rcPeriodActivity"></div>
  </section>
  <section id="rcSettings" role="tabpanel" aria-labelledby="rcTabSettings" hidden>
    <h2>Recovery timing settings</h2><p class="rc-muted">Each setting accepts whole hours from 1 to 720. Changes affect waiting and future contacts; an accepted message keeps its original attribution window. Saving settings never sends mail.</p>
    <form id="rcSettingsForm" class="rc-settings">
      <label>First Recovery Delay (hours)<input name="firstDelayHours" type="number" min="1" max="720" step="1" required></label>
      <label>Recovery Stage Interval (hours)<input name="stageIntervalHours" type="number" min="1" max="720" step="1" required><span class="rc-muted">Spacing between numbered contacts, not advancement through A/B/C/D.</span></label>
      <label>Recovery Attribution Window (hours)<input name="attributionWindowHours" type="number" min="1" max="720" step="1" required></label>
      <button type="submit">Preview impact</button>
    </form>
    <div id="rcSettingsReview" class="rc-notice" hidden><h3>Review timing impact</h3><div id="rcSettingsImpact"></div><label><input id="rcSettingsConfirm" type="checkbox"> I reviewed the affected members and any immediately eligible contacts.</label><button id="rcSettingsSave" type="button" disabled>Save reviewed timing</button></div>
    <section class="rc-card"><h3>One-time recovery-start reset</h3><p>Apply one shared UTC start to the reviewed existing enrollment cohort. Original enrollment, progress, coverage, and delivery history remain intact. This operation is blocked when delivery history or unresolved claims exist.</p>
      <div id="rcResetState"></div><button id="rcResetPreview" type="button">Preview initial reset</button>
      <div id="rcResetReview" class="rc-notice" hidden><div id="rcResetImpact"></div><label><input id="rcResetConfirm" type="checkbox"> I reviewed the cohort and authorize the one-time recovery-start reset.</label><button id="rcResetCommit" type="button" disabled>Apply reviewed reset</button></div>
    </section><h3>Settings &amp; administrative audit</h3><div id="rcSettingsAudit"></div>
  </section>
  <dialog id="rcPreviewDialog"><div class="rc-dialog-header"><h2 id="rcPreviewTitle">Email preview</h2><button id="rcPreviewClose" type="button" aria-label="Close preview">Close</button></div>
    <p class="rc-muted">Preview only. Links and tracking are disabled; bearer tokens are redacted.</p><div id="rcPreviewMeta"></div>
    <iframe id="rcPreviewFrame" sandbox="" referrerpolicy="no-referrer" title="Safe email preview"></iframe>
    <details><summary>Plain text</summary><pre id="rcPreviewText"></pre></details>
  </dialog>
</main>
<cfoutput><script src="#encodeForHTMLAttribute(request.fpwBase)#/assets/js/admin-recovery-center.js?v=20261003" defer></script></cfoutput>
</body>
</html>
