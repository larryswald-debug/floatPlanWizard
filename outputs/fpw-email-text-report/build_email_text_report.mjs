import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const outputDir = "/Users/lawrencewald/Docker/cf-mysql-dev/wwwroot/fpw/outputs/fpw-email-text-report";
const outputPath = path.join(outputDir, "FPW_Email_Text_Report.xlsx");
const generatedAt = "2026-05-28";

const emails = [
  {
    email: "Prelaunch welcome / thank-you",
    format: "text",
    sender: "FloatPlanWizard <no-reply@floatplanwizard.com>",
    recipients: "Signup email address",
    trigger: "POST with action=earlyaccesssignup; valid email; sends only if the address was not already in fpw_early_access.",
    subject: "Thanks for joining the FloatPlanWizard launch list",
    body: `Hello,

Thank you for signing up to be notified about the upcoming launch of FloatPlanWizard.

FloatPlanWizard was originally launched in 2018 and is now being completely rebuilt as a modern platform for recreational boaters who want a better way to organize trips, create detailed float plans, and keep family or friends informed while on the water.

The new version is scheduled to launch in Spring 2026.

Between now and launch you may receive a few brief updates about the progress of the platform and when it becomes available. These messages are limited to launch-related updates only, and your email address will never be sold or shared.

If you were a member of the earlier version of FloatPlanWizard, you will receive instructions after launch explaining how to access the new platform.

If you would prefer not to receive these updates, you can unsubscribe at any time using the link below:

Unsubscribe:
{unsubscribeLink}

Thank you again for your interest in FloatPlanWizard.

- FloatPlanWizard
https://FloatPlanWizard.com

FloatPlanWizard
United States`,
    notes: "Same template appears in index.cfm, preLaunch.cfm, and assets/admin/index.cfm.",
    sources: "index.cfm:117; preLaunch.cfm:115; assets/admin/index.cfm:115"
  },
  {
    email: "Contact-us support email",
    format: "text",
    sender: "no-reply@floatplanwizard.com",
    recipients: "support@floatplanwizard.com",
    trigger: "app/contact.cfm posts to api/v1/contactUs.cfc?method=handle; required fields pass validation; website honeypot is blank.",
    subject: "Float Plan Wizard Contact Us: {firstName} {lastName}",
    body: `First Name: {firstName}
Last Name: {lastName}
Email: {email}

Description:
{description}

Submitted: {mmmm d, yyyy h:nn tt}`,
    notes: "Reply-To is set to the submitter email.",
    sources: "app/contact.cfm:42; api/v1/contactUs.cfc:44"
  },
  {
    email: "Basic float plan PDF delivery",
    format: "html",
    sender: "noreply@floatplanwizard.com",
    recipients: "floatplan_basic_details.notification_contact_email",
    trigger: "API action sendbasic; Basic operational DRAFT plan; valid Basic details; future return time; member gates pass; contact email exists; PDF generation succeeds.",
    subject: "Float Plan Precautionary Delivery: {planName}",
    body: `<p>Hello,</p>
<p>You are receiving the attached Float Plan ({planName}) because you were selected as a contact for this trip.</p>
<p>This delivery is a precaution and nothing is wrong at this time.</p>
<p>Please keep this PDF available. If the member does not return on time, call {rescueLabel}.</p>
{optionalRescueDetails}
<p>Thank you.</p>`,
    notes: "{rescueLabel} is either 'the selected Rescue Authority' or 'the selected Rescue Authority listed below'. {optionalRescueDetails} is blank unless rescue authority/phone exists, then '<p>Rescue Authority: {rescueAuthority} ({rescuePhone})</p>'. PDF is attached.",
    sources: "api/v1/floatplan.cfc:168; api/v1/floatplan.cfc:6864; api/v1/floatplan.cfc:7030"
  },
  {
    email: "Route-backed float plan PDF delivery",
    format: "html",
    sender: "noreply@floatplanwizard.com",
    recipients: "Selected contacts from floatplan_contacts joined to contacts.email",
    trigger: "API action send; route-backed DRAFT plan; valid route/current group; future return time; member and Premium gates pass; selected contacts; route activation precheck; PDF generation succeeds.",
    subject: "Float Plan Precautionary Delivery: {planName}",
    body: `<p>Hello,</p>
<p>You are receiving the attached Float Plan ({planName}) because you were selected as a contact for this trip.</p>
<p>This delivery is a precaution and nothing is wrong at this time.</p>
<p>Please keep this PDF available. If the member does not return on time, call {rescueLabel}.</p>
{optionalRescueDetails}
<p>Thank you.</p>`,
    notes: "Same email body as Basic delivery, but recipients come from selected route-backed plan contacts. PDF is attached.",
    sources: "api/v1/floatplan.cfc:157; api/v1/floatplan.cfc:7131; api/v1/floatplan.cfc:7286"
  },
  {
    email: "Monitoring missed check-in owner alert",
    format: "text",
    sender: "alerts@fpw.test",
    recipients: "Float plan owner email",
    trigger: "monitor.cfc evaluates an active monitoring row; grace_expires_at is past and state is ACTIVE or LATE; state transitions to MISSED; not already SENT for the cycle; fewer than 3 failed attempts.",
    subject: "FPW Monitoring Alert: Missed Check-In - {planName}",
    body: `Status: Missed Check-In
Float Plan: {planName}
Timestamp: {eventLabel}
Float Plan ID: {floatPlanId}
Recipients: {toList}`,
    notes: "Alert history key is MISSED_OWNER plus monitoring cycle fields. Written to floatplan_alert_history.",
    sources: "api/v1/monitor.cfc:776; api/v1/monitor.cfc:1482; api/v1/OverdueAlertService.cfc:259"
  },
  {
    email: "Monitoring escalated contact alert",
    format: "text",
    sender: "alerts@fpw.test",
    recipients: "Basic notification contact plus selected float plan contacts",
    trigger: "Monitoring row is MISSED; missed_at + escalation_delay_minutes is past; state transitions to ESCALATED; not already SENT for the cycle; fewer than 3 failed attempts.",
    subject: "FPW Monitoring Alert: Escalated - {planName}",
    body: `Status: Escalated
Float Plan: {planName}
Timestamp: {eventLabel}
Float Plan ID: {floatPlanId}
Recipients: {toList}`,
    notes: "Alert history key is ESCALATED_CONTACTS plus monitoring cycle fields. Written to floatplan_alert_history.",
    sources: "api/v1/monitor.cfc:739; api/v1/monitor.cfc:1511; api/v1/OverdueAlertService.cfc:343"
  },
  {
    email: "Assistance-needed alert",
    format: "text",
    sender: "alerts@fpw.test",
    recipients: "Owner, Basic notification contact, emergency contacts, and emergency email tables; duplicates removed.",
    trigger: "Active Cruise/check-in path resolves status to NEED_ATTENTION, then calls sendAssistanceNeededEmail.",
    subject: "FPW Assistance Needed Alert: {planName}",
    body: `Status: Assistance Needed
Float Plan: {planName}
Timestamp: {checkinLabel}
{optionalCaptainNote}Float Plan ID: {floatPlanId}
Recipients: {toList}`,
    notes: "{optionalCaptainNote} is blank unless a note exists, then 'Captain Note: {note}' plus a newline. Written to floatplan_alert_history.",
    sources: "api/v1/floatplan.cfc:6074; api/v1/floatplan.cfc:6091; api/v1/OverdueAlertService.cfc:434"
  }
];

function applyTitle(sheet, range, title, subtitle) {
  const titleRange = sheet.getRange(range);
  titleRange.format.font = { bold: true, color: "#17324D", size: 16 };
  titleRange.format.horizontalAlignment = "left";
  titleRange.format.verticalAlignment = "middle";
  titleRange.format.rowHeightPx = 34;
  sheet.getRange("A1").values = [[title]];

  const sub = sheet.getRange("A2:G2");
  sub.merge();
  sheet.getRange("A2").values = [[subtitle]];
  sub.format.fill = { color: "#E8F0F7" };
  sub.format.font = { color: "#17324D", italic: true };
  sub.format.wrapText = true;
  sub.format.rowHeightPx = 36;
}

function styleHeader(range) {
  range.format.fill = { color: "#22577A" };
  range.format.font = { bold: true, color: "#FFFFFF" };
  range.format.wrapText = true;
  range.format.verticalAlignment = "middle";
  range.format.rowHeightPx = 32;
}

function styleBody(range) {
  range.format.wrapText = true;
  range.format.verticalAlignment = "top";
  range.format.font = { color: "#111827", size: 10 };
}

const workbook = Workbook.create();
const summary = workbook.worksheets.add("Email Summary");
const textSheet = workbook.worksheets.add("Full Email Text");
const sourceSheet = workbook.worksheets.add("Source Notes");

for (const sheet of [summary, textSheet, sourceSheet]) {
  sheet.showGridLines = false;
}

applyTitle(
  summary,
  "A1:G1",
  "FPW Active Email Audit Summary",
  `Read-only report generated ${generatedAt}. Active application send paths only; legacy _orig templates are excluded.`
);
summary.getRange("A4:G4").values = [[
  "Email",
  "Format",
  "Sender",
  "Recipients",
  "Trigger / Rule",
  "Subject",
  "Sources"
]];
summary.getRange(`A5:G${emails.length + 4}`).values = emails.map((item) => [
  item.email,
  item.format,
  item.sender,
  item.recipients,
  item.trigger,
  item.subject,
  item.sources
]);
styleHeader(summary.getRange("A4:G4"));
styleBody(summary.getRange(`A5:G${emails.length + 4}`));
summary.getRange("A:A").format.columnWidthPx = 190;
summary.getRange("B:B").format.columnWidthPx = 70;
summary.getRange("C:C").format.columnWidthPx = 190;
summary.getRange("D:D").format.columnWidthPx = 260;
summary.getRange("E:E").format.columnWidthPx = 460;
summary.getRange("F:F").format.columnWidthPx = 260;
summary.getRange("G:G").format.columnWidthPx = 320;
summary.getRange(`A5:G${emails.length + 4}`).format.rowHeightPx = 92;
summary.freezePanes.freezeRows(4);
summary.tables.add(`A4:G${emails.length + 4}`, true, "EmailSummaryTable");

applyTitle(
  textSheet,
  "A1:F1",
  "FPW Full Email Text",
  "Full template text exactly as extracted from active send paths, with runtime placeholders shown in braces."
);
textSheet.getRange("A4:F4").values = [[
  "Email",
  "Format",
  "Subject",
  "Full Body Template",
  "Notes",
  "Sources"
]];
textSheet.getRange(`A5:F${emails.length + 4}`).values = emails.map((item) => [
  item.email,
  item.format,
  item.subject,
  item.body,
  item.notes,
  item.sources
]);
styleHeader(textSheet.getRange("A4:F4"));
styleBody(textSheet.getRange(`A5:F${emails.length + 4}`));
textSheet.getRange("A:A").format.columnWidthPx = 220;
textSheet.getRange("B:B").format.columnWidthPx = 70;
textSheet.getRange("C:C").format.columnWidthPx = 300;
textSheet.getRange("D:D").format.columnWidthPx = 620;
textSheet.getRange("E:E").format.columnWidthPx = 360;
textSheet.getRange("F:F").format.columnWidthPx = 320;
textSheet.getRange("A5:F5").format.rowHeightPx = 340;
textSheet.getRange("A6:F6").format.rowHeightPx = 170;
textSheet.getRange("A7:F8").format.rowHeightPx = 210;
textSheet.getRange("A9:F11").format.rowHeightPx = 145;
textSheet.freezePanes.freezeRows(4);
textSheet.tables.add(`A4:F${emails.length + 4}`, true, "FullEmailTextTable");

applyTitle(
  sourceSheet,
  "A1:D1",
  "FPW Email Audit Source Notes",
  "Scope notes and exclusions for the workbook."
);
const sourceRows = [
  ["Scope", "Included", "Active cfmail send paths in app, api, assets, includes, index.cfm, preLaunch.cfm, and Application.cfc.", ""],
  ["Scope", "Excluded", "api/api_assets/floatPlanUtils_orig.cfc legacy email templates because active code resolves to api.api_assets.floatPlanUtils, not _orig.", ""],
  ["Verification", "Search terms", "cfmail, subject, mailBody, SendGrid, sendgrid, mailgun, postmark, smtp, mailServer, and related sender/recipient strings.", ""],
  ["Database note", "Email-related tables found", "email_optout, emails_sent, floatplan_alert_history, floatplan_emailsent, floatplan_notification_log, floatplan_notifications, fpw_email_log, fpw_notification_log, messages.", ""],
  ["Potential issue", "Sender", "Monitoring and assistance alerts currently use alerts@fpw.test.", ""]
];
sourceSheet.getRange("A4:D4").values = [["Category", "Item", "Detail", "Additional Notes"]];
sourceSheet.getRange(`A5:D${sourceRows.length + 4}`).values = sourceRows;
styleHeader(sourceSheet.getRange("A4:D4"));
styleBody(sourceSheet.getRange(`A5:D${sourceRows.length + 4}`));
sourceSheet.getRange("A:A").format.columnWidthPx = 130;
sourceSheet.getRange("B:B").format.columnWidthPx = 180;
sourceSheet.getRange("C:C").format.columnWidthPx = 650;
sourceSheet.getRange("D:D").format.columnWidthPx = 180;
sourceSheet.getRange(`A5:D${sourceRows.length + 4}`).format.rowHeightPx = 72;
sourceSheet.freezePanes.freezeRows(4);
sourceSheet.tables.add(`A4:D${sourceRows.length + 4}`, true, "SourceNotesTable");

await fs.mkdir(outputDir, { recursive: true });

const inspectSummary = await workbook.inspect({
  kind: "table",
  range: "Full Email Text!A4:F11",
  include: "values",
  tableMaxRows: 8,
  tableMaxCols: 6,
  tableMaxCellChars: 120
});
console.log(inspectSummary.ndjson);

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "final formula error scan"
});
console.log(errors.ndjson);

for (const sheetName of ["Email Summary", "Full Email Text", "Source Notes"]) {
  const preview = await workbook.render({ sheetName, autoCrop: "all", scale: 1, format: "png" });
  const bytes = new Uint8Array(await preview.arrayBuffer());
  await fs.writeFile(path.join(outputDir, `${sheetName.replaceAll(" ", "_")}.png`), bytes);
}

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);
console.log(JSON.stringify({ outputPath }));
