import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const pagePath = join(repoRoot, "admin", "email-test.cfm");
const navPath = join(repoRoot, "admin", "includes", "admin_reports_nav.cfm");
const applicationPath = join(repoRoot, "Application.cfc");
const authorizationPath = join(repoRoot, "api", "v1", "AdminAuthorizationService.cfc");
const contactPath = join(repoRoot, "api", "v1", "contactUs.cfc");
const emailServicePath = join(repoRoot, "api", "v1", "email.cfc");

const [page, nav, application, authorization, contact, emailService] = await Promise.all([
  readFile(pagePath, "utf8"),
  readFile(navPath, "utf8"),
  readFile(applicationPath, "utf8"),
  readFile(authorizationPath, "utf8"),
  readFile(contactPath, "utf8"),
  readFile(emailServicePath, "utf8"),
]);

test("the diagnostic page remains behind the central admin authorization and CSRF gate", () => {
  assert.match(application, /findNoCase\("\/admin\/",\s*scriptName\)/);
  assert.match(application, /AdminAuthorizationService\(\)\.init\("fpw"\)/);
  assert.match(application, /isValidCsrfToken\(/);
  assert.match(authorization, /LOWER\(entitlement_type\)\s*=\s*'admin'/i);
  assert.match(page, /name="adminCsrfToken"/);
  assert.match(page, /toString\(request\.fpwAdminCsrfToken\)/);
});

test("the server-side From allowlist contains exactly the six approved senders", () => {
  const allowlistMatch = page.match(/approvedFromAddresses\s*=\s*\[([\s\S]*?)\];/);
  assert.ok(allowlistMatch, "From allowlist block was not found");
  const addresses = [...allowlistMatch[1].matchAll(/"([^"]+@[^"]+)"/g)].map((match) => match[1]);
  assert.deepEqual(addresses, [
    "noreply@floatplanwizard.com",
    "support@floatplanwizard.com",
    "info@floatplanwizard.com",
    "lswald@yahoo.com",
    "larry.s.wald@gmail.com",
    "larry@waldmedia.com",
  ]);
  assert.match(page, /arrayFindNoCase\(approvedFromAddresses,\s*selectedFrom\)/);
  assert.match(page, /The selected From address is not approved/);
});

test("the From field is editable but limited to server-approved suggestions", () => {
  assert.match(page, /<input[^>]+type="email"[^>]+id="fromAddress"[^>]+name="fromAddress"[^>]+list="approvedFromAddressOptions"/i);
  assert.match(page, /<datalist id="approvedFromAddressOptions">/i);
  assert.match(page, /maxlength="#fromAddressLimit#"/);
  assert.doesNotMatch(page, /<select[^>]+id="fromAddress"/i);
});

test("optional From and Reply-To copies use deduplicated allowlisted BCC recipients", () => {
  assert.match(page, /name="copyFromAddress"\s+value="1"/i);
  assert.match(page, /name="copyReplyToAddress"\s+value="1"/i);
  assert.match(page, /copyReplyToRequested[\s\S]*?!arrayFindNoCase\(approvedFromAddresses,\s*replyToValue\)/);
  assert.match(page, /A Reply-To copy can only be sent to an approved allowlisted address/);
  assert.match(page, /!arrayFindNoCase\(diagnosticBccAddresses,\s*replyToValue\)/);
  assert.match(page, /diagnosticMailAttributes\.bcc\s*=\s*arrayToList\(diagnosticBccAddresses,\s*","\)/);
  assert.doesNotMatch(page, /diagnosticMailAttributes\.cc\s*=/);
});

test("the recipient is a server constant and browser overrides are rejected", () => {
  assert.match(page, /diagnosticRecipient\s*=\s*"support@floatplanwizard\.com"/);
  assert.match(page, /recipientOverrideFields\s*=\s*\["to",\s*"recipient",\s*"toAddress"\]/);
  assert.match(page, /Recipient override rejected/);
  assert.match(page, /"to"\s*=\s*diagnosticRecipient/);
  assert.doesNotMatch(page, /name="(?:to|recipient|toAddress)"/i);
});

test("only a validated POST send action can reach cfmail", () => {
  assert.match(page, /requestMethod\s+EQ\s+"POST"/);
  assert.match(page, /submittedAction\s+NEQ\s+"send"/);
  assert.match(page, /if\s*\(!arrayLen\(formErrors\)\)\s*\{/);
  assert.match(page, /<cfif sendReady>[\s\S]*?<cfmail/i);
  assert.match(page, /method="post"/i);
});

test("subject, body, Reply-To, and output have bounded validation and encoding", () => {
  assert.match(page, /subjectLimit\s*=\s*180/);
  assert.match(page, /bodyLimit\s*=\s*5000/);
  assert.match(page, /replyToLimit\s*=\s*254/);
  assert.match(page, /isValid\("email",\s*replyToValue\)/);
  assert.match(page, /find\(chr\(13\),\s*subjectValue\)/);
  assert.match(page, /encodeForHTML\(/);
  assert.match(page, /encodeForHTMLAttribute\(/);
  assert.match(page, /maxlength="#subjectLimit#"/);
  assert.match(page, /maxlength="#bodyLimit#"/);
  assert.match(page, /mailSubjectValue\s*=\s*findNoCase\(testId,\s*subjectValue\)/);
  assert.match(page, /"subject"\s*=\s*mailSubjectValue/);
});

test("the diagnostic uses configured CF mail without SMTP fields or application DKIM signing", () => {
  const mailSetupMatch = page.match(/diagnosticMailAttributes\s*=\s*\{([\s\S]*?)\n\s*\};/);
  assert.ok(mailSetupMatch, "Diagnostic cfmail attributes were not found");
  assert.match(mailSetupMatch[1], /"from"\s*=\s*selectedFrom/);
  assert.match(mailSetupMatch[1], /"spoolenable"\s*=\s*false/);
  assert.doesNotMatch(mailSetupMatch[1], /"(?:server|host|port|username|password)"\s*=/i);
  assert.doesNotMatch(page, /<cfmailparam[^>]+name=["']DKIM-Signature["']/i);
  assert.match(contact, /<cfmail[\s\S]*?from="noreply@floatplanwizard\.com"/i);
  assert.match(emailService, /<cfmail\s+attributeCollection="#mailAttrs#"/i);
});

test("success uses POST-Redirect-GET and does not expose a stack trace", () => {
  assert.match(page, /session\.fpwEmailDiagnosticResult\s*=\s*\{/);
  assert.match(page, /<cflocation[^>]+statuscode="303"/i);
  assert.match(page, /structDelete\(session,\s*"fpwEmailDiagnosticResult"/);
  assert.match(page, /safeDiagnosticError\(cfcatch\)/);
  assert.doesNotMatch(page, /cfcatch\.(?:detail|stackTrace|tagContext)/i);
});

test("admin navigation links to the diagnostic page", () => {
  assert.match(nav, /\{\s*"file"\s*=\s*"email-test\.cfm",\s*"label"\s*=\s*"Email Delivery Test"\s*\}/);
});
