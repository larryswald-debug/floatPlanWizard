<!---
  Local-only runtime rendering of the seven direct-mail variants.
  Extracts the current production body/subject/cfmail attribute blocks at runtime,
  substitutes a no-SMTP custom-tag sink, and evaluates them in ColdFusion.
  This checks final rendering/identity, not DB mutation or send orchestration.
--->
<cfsetting showdebugoutput="false" enablecfoutputonly="true" requesttimeout="120">
<cfparam name="url.confirm" default="">
<cfscript>
serverName = structKeyExists(cgi, "server_name") ? lCase(trim(toString(cgi.server_name))) : "";
httpHost = structKeyExists(cgi, "http_host") ? lCase(trim(toString(cgi.http_host))) : "";
serverPort = structKeyExists(cgi, "server_port") ? val(cgi.server_port) : 0;
isLocalDevRequest = listFindNoCase("localhost,127.0.0.1,::1", serverName) GT 0
  AND reFindNoCase("^(localhost|127\.0\.0\.1|\[::1\])(:8500)?$", httpHost) GT 0
  AND serverPort EQ 8500;
</cfscript>
<cfif trim(toString(url.confirm)) NEQ "CAPTURE_DIRECT_EMAILS_NO_SMTP" OR NOT isLocalDevRequest>
  <cfheader statuscode="404">
  <cfcontent type="application/json; charset=utf-8" reset="true">
  <cfoutput>#serializeJSON({SUCCESS=false,ERROR="LOCAL_TEST_CONFIRMATION_REQUIRED"})#</cfoutput>
  <cfabort>
</cfif>
<cfscript>
function exactMatch(required string source, required string expression, required string label) {
  var matches = reMatch(arguments.expression, arguments.source);
  if (arrayLen(matches) NEQ 1) throw(message="Capture source boundary changed: " & arguments.label);
  return matches[1];
}
function sourceFunction(required string source, required string name) {
  return exactMatch(arguments.source, '(?is)<cffunction\s+name="' & arguments.name & '"[^>]*>.*?</cffunction>', arguments.name);
}
function sinkMail(required string source, required string variant, required string sinkPath) {
  var mail = exactMatch(arguments.source, "(?is)<cfmail\b[^>]*>.*?</cfmail>", arguments.variant & " mail");
  mail = reReplace(mail, "(?is)<cfmailparam\b[^>]*>", "", "all");
  mail = reReplace(mail, "(?is)^<cfmail\b", '<cfmodule template="' & arguments.sinkPath & '" variant="' & arguments.variant & '"', "one");
  var openEnd = find(">", mail);
  mail = left(mail, openEnd) & "<cfoutput>" & mid(mail, openEnd + 1, len(mail));
  return replaceNoCase(mail, "</cfmail>", "</cfoutput></cfmodule>", "one");
}
function assertion(required boolean condition, required string label) {
  if (!arguments.condition) throw(message="Direct email capture assertion failed: " & arguments.label);
  arrayAppend(request.fpwDirectEmailAssertions, arguments.label);
}
testDirectory = getDirectoryFromPath(getCurrentTemplatePath());
repoDirectory = getDirectoryFromPath(left(testDirectory, len(testDirectory)-1));
sinkPath = "DirectEmailCaptureSink.cfm";
generatedName = "DirectEmailCapture" & reReplace(createUUID(), "[^A-Za-z0-9]", "", "all");
generatedPath = testDirectory & "support/" & generatedName & ".cfc";
diagnosticPath = testDirectory & "support/" & generatedName & ".cfm";
diagnosticValidationPath = testDirectory & "support/" & generatedName & "Validation.cfm";
savedForm = duplicate(form);
request.fpwDirectEmailCaptureEnabled = true;
request.fpwDirectEmailCaptures = [];
request.fpwDirectEmailAssertions = [];
response = {SUCCESS=false};
status = 500;
</cfscript>
<cftry>
<cfscript>
  alertSource = fileRead(repoDirectory & "api/v1/OverdueAlertService.cfc", "utf-8");
  floatPlanSource = fileRead(repoDirectory & "api/v1/floatplan.cfc", "utf-8");
  contactSource = fileRead(repoDirectory & "api/v1/contactUs.cfc", "utf-8");
  diagnosticSource = fileRead(repoDirectory & "admin/email-test.cfm", "utf-8");
  componentSource = '<cfcomponent output="false">';
  alertFunctions = [
    {name="sendMonitoringMissedOwnerEmail",variant="monitoring_missed_owner"},
    {name="sendMonitoringEscalatedContactEmail",variant="monitoring_escalated_contacts"},
    {name="sendAssistanceNeededEmail",variant="monitoring_assistance_needed"}
  ];
  for (item in alertFunctions) {
    source = sourceFunction(alertSource, item.name);
    setup = '<cfset var planName = "Capture Harbor Run"><cfset var eventLabel = "Oct 7, 2026 4:00 PM UTC"><cfset var toList = "capture-owner@example.test"><cfset var body = "">';
    if (item.name EQ "sendAssistanceNeededEmail") {
      setup = '<cfset var toList = "capture-owner@example.test">';
      bodyCode = exactMatch(source, '(?is)<cfset var resolvedPlanName =.*?<cfset var body =.*?>', item.name & " body");
    } else {
      bodyCode = exactMatch(source, '(?is)<cfset var subject =.*?>', item.name & " subject")
        & exactMatch(source, '(?is)<cfset body =.*?>', item.name & " body");
    }
    componentSource &= '<cffunction name="' & item.variant & '" access="public" returntype="void" output="false">'
      & '<cfargument name="floatPlanId" type="numeric" default="42">'
      & (item.name EQ "sendAssistanceNeededEmail" ? '<cfargument name="planName" default="Capture Harbor Run">' : '')
      & '<cfargument name="checkinAt" default="2026-10-07 16:00:00"><cfargument name="note" default="Disposable rendering fixture only.">'
      & setup & bodyCode & sinkMail(source,item.variant,sinkPath) & '</cffunction>';
  }
  for (item in [
    {name="performBasicFloatPlanSend",variant="basic_operational_delivery"},
    {name="performPremiumFloatPlanSend",variant="premium_initial_delivery"}
  ]) {
    source = sourceFunction(floatPlanSource,item.name);
    bodyCode = exactMatch(source, '(?is)var safePlanName =.*?var subject =[^;]+;', item.name & " body");
    componentSource &= '<cffunction name="' & item.variant & '" access="public" returntype="void" output="false"><cfscript>'
      & 'var planName="Capture Harbor & Cove";var rescueAuthority="Fixture Authority";var rescuePhone="555-0100";'
      & 'var memberProfile={displayName="Fixture Captain"};var emailAddr="capture-contact@example.test";'
      & bodyCode & '</cfscript>' & sinkMail(source,item.variant,sinkPath) & '</cffunction>';
  }
  componentSource &= '<cffunction name="contact_us" access="public" returntype="void" output="false">'
    & '<cfset var firstName="Capture"><cfset var lastName="Visitor"><cfset var email="visitor@example.test">'
    & '<cfset var description="Disposable contact rendering fixture.">'
    & sinkMail(contactSource,"contact_us",sinkPath) & '</cffunction></cfcomponent>';
  assertion(!reFindNoCase("<cfmail\b", componentSource), "Generated component contains no SMTP tag");
  fileWrite(generatedPath, componentSource, "utf-8");
  captureComponent = createObject("component", "fpw.tests.support." & generatedName);
  captureComponent.monitoring_missed_owner();
  captureComponent.monitoring_escalated_contacts();
  captureComponent.monitoring_assistance_needed();
  captureComponent.basic_operational_delivery();
  captureComponent.premium_initial_delivery();
  captureComponent.contact_us();

  // Evaluate the diagnostic's actual validation/attribute-building script.
  // Only the request-method input is replaced; no production mail/send branch runs.
  diagnosticScript = exactMatch(diagnosticSource, "(?is)<cfscript>\s*diagnosticRecipient.*?</cfscript>", "diagnostic setup script");
  diagnosticScript = reReplace(diagnosticScript, '(?m)^requestMethod = [^\r\n]+;', 'requestMethod = "POST";', "one");
  diagnosticMail = exactMatch(diagnosticSource, "(?is)<cfmail\b[^>]*>.*?</cfmail>", "diagnostic mail");
  diagnosticSink = '<cfif sendReady>' & sinkMail(diagnosticMail,"admin_email_diagnostic",sinkPath) & '</cfif>';
  assertion(!reFindNoCase("<cfmail\b", diagnosticScript & diagnosticSink), "Generated diagnostic contains no SMTP tag");
  fileWrite(diagnosticPath, diagnosticScript & diagnosticSink, "utf-8");
  // The first include declares the two existing helpers once. Subsequent
  // validation includes reuse them because CF disallows duplicate declarations.
  helperStart = find("function createDiagnosticTestId(",diagnosticScript);
  helperEnd = find("serverHost =",diagnosticScript);
  assertion(helperStart GT 0 AND helperEnd GT helperStart,"Diagnostic helper boundaries found");
  diagnosticValidationScript = removeChars(diagnosticScript,helperStart,helperEnd-helperStart);
  fileWrite(diagnosticValidationPath,diagnosticValidationScript & diagnosticSink,"utf-8");
  structClear(form);
  form.action="send";
  form.testId="DKIM-20261007-160000-ABCDEF12";
  form.fromAddress="noreply@floatplanwizard.com";
  form.replyTo="support@floatplanwizard.com";
  form.subject="Disposable direct email capture";
  form.messageBody="No SMTP submission occurs in this test.";
</cfscript>
<cfinclude template="support/#generatedName#.cfm">
<cfscript>
  assertion(sendReady, "Approved diagnostic identities pass actual runtime validation");
  assertion(arrayLen(request.fpwDirectEmailCaptures) EQ 7, "Seven current direct email variants rendered");
  captureCount = arrayLen(request.fpwDirectEmailCaptures);
  form.fromAddress="external@example.test";
</cfscript>
<cfinclude template="support/#generatedName#Validation.cfm">
<cfscript>
  assertion(!sendReady AND arrayLen(formErrors) GT 0, "External diagnostic From is rejected at runtime");
  assertion(arrayLen(request.fpwDirectEmailCaptures) EQ captureCount, "Rejected From never reaches capture transport");
  form.fromAddress="noreply@floatplanwizard.com";
  form.replyTo="external@example.test";
</cfscript>
<cfinclude template="support/#generatedName#Validation.cfm">
<cfscript>
  assertion(!sendReady AND arrayLen(formErrors) GT 0, "External diagnostic Reply-To is rejected at runtime");
  assertion(arrayLen(request.fpwDirectEmailCaptures) EQ captureCount, "Rejected Reply-To never reaches capture transport");
  for (record in request.fpwDirectEmailCaptures) {
    assertion(reFindNoCase("^[^@[:space:]]+@floatplanwizard\.com$", record.from) GT 0, record.variant & " approved From");
    if (record.variant EQ "contact_us") {
      assertion(record.replyTo EQ "visitor@example.test", "Contact Us approved visitor Reply-To exception preserved");
    } else {
      assertion(!len(record.replyTo) OR reFindNoCase("^[^@[:space:]]+@floatplanwizard\.com$",record.replyTo) GT 0, record.variant & " approved FPW Reply-To");
    }
    assertion(len(record.subject) GT 0 AND len(record.htmlBody & record.textBody) GT 0, record.variant & " final body and subject captured");
  }
  response = {
    SUCCESS=true,
    captureMode="Exact production body and mail-attribute blocks evaluated by ColdFusion; no-SMTP sink replaces cfmail; DB/send orchestration excluded.",
    variants=request.fpwDirectEmailCaptures,
    assertions=request.fpwDirectEmailAssertions,
    count=arrayLen(request.fpwDirectEmailCaptures)
  };
  status = 200;
</cfscript>
<cfcatch type="any">
<cfscript>
  response = {SUCCESS=false,ERROR="DIRECT_EMAIL_CAPTURE_FAILED",MESSAGE=cfcatch.message,DETAIL=cfcatch.detail};
</cfscript>
</cfcatch>
<cffinally>
<cfscript>
  structClear(form);
  structAppend(form,savedForm,true);
  if (fileExists(generatedPath)) fileDelete(generatedPath);
  if (fileExists(diagnosticPath)) fileDelete(diagnosticPath);
  if (fileExists(diagnosticValidationPath)) fileDelete(diagnosticValidationPath);
  structDelete(request,"fpwDirectEmailCaptureEnabled",false);
</cfscript>
</cffinally>
</cftry>
<cfheader statuscode="#status#">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfoutput>#serializeJSON(response)#</cfoutput>
