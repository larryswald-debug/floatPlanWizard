<cfsetting showdebugoutput="false">
<cfcontent type="text/html; charset=utf-8">
<cfinclude template="../includes/fpw_base_path.cfm">
<cfscript>
diagnosticRecipient = "support@floatplanwizard.com";
approvedFromAddresses = [
    "noreply@floatplanwizard.com",
    "support@floatplanwizard.com",
    "info@floatplanwizard.com",
    "lswald@yahoo.com",
    "larry.s.wald@gmail.com",
    "larry@waldmedia.com"
];
defaultReplyTo = "lswald@yahoo.com";
fromAddressLimit = 254;
subjectLimit = 180;
bodyLimit = 5000;
replyToLimit = 254;
requestMethod = structKeyExists(cgi, "request_method") ? uCase(trim(toString(cgi.request_method))) : "GET";
isPostRequest = requestMethod EQ "POST";
formErrors = [];
sendReady = false;
sendResult = {};
copyFromRequested = false;
copyReplyToRequested = false;
diagnosticBccAddresses = [];

function createDiagnosticTestId() {
    return "DKIM-" & dateTimeFormat(now(), "yyyymmdd-HHnnss") & "-" & left(replace(createUUID(), "-", "", "all"), 8);
}

function safeDiagnosticError(required any caughtError) {
    var errorType = structKeyExists(arguments.caughtError, "type")
        ? trim(toString(arguments.caughtError.type))
        : "MailError";
    var errorMessage = structKeyExists(arguments.caughtError, "message")
        ? trim(toString(arguments.caughtError.message))
        : "ColdFusion did not return an SMTP error message.";

    errorType = reReplace(errorType, "[^A-Za-z0-9_.-]", "", "all");
    if (!len(errorType)) {
        errorType = "MailError";
    }

    errorMessage = reReplace(errorMessage, "[\r\n\t]+", " ", "all");
    errorMessage = reReplaceNoCase(
        errorMessage,
        "(password|username|credential|authorization)[[:space:]]*[:=][[:space:]]*[^[:space:],;]+",
        "\1=[redacted]",
        "all"
    );
    errorMessage = reReplaceNoCase(
        errorMessage,
        "://[^/@[:space:]]+:[^/@[:space:]]+@",
        "://[redacted]@",
        "all"
    );
    errorMessage = left(errorMessage, 500);

    return "SMTP submission failed (" & errorType & "): " & errorMessage;
}

serverHost = structKeyExists(cgi, "server_name") ? lCase(trim(toString(cgi.server_name))) : "";
environmentLabel = listFindNoCase("localhost,127.0.0.1", serverHost)
    ? "Local development"
    : (len(serverHost) ? serverHost : "FPW application");

testId = createDiagnosticTestId();
selectedFrom = approvedFromAddresses[1];
replyToValue = defaultReplyTo;
subjectValue = "FPW Email Authentication Test - " & dateTimeFormat(now(), "yyyy-mm-dd HH:nn") & " - " & testId;
messageBodyValue = "FloatPlanWizard outbound email authentication test." & chr(10) & chr(10)
    & "Purpose: Verify Media3 / SmarterMail DKIM signing and outbound mail headers.";

if (!isPostRequest AND structKeyExists(url, "sent") AND len(trim(toString(url.sent)))
    AND structKeyExists(session, "fpwEmailDiagnosticResult")
    AND isStruct(session.fpwEmailDiagnosticResult)
    AND structKeyExists(session.fpwEmailDiagnosticResult, "resultToken")
    AND compare(toString(session.fpwEmailDiagnosticResult.resultToken), trim(toString(url.sent))) EQ 0) {
    sendResult = duplicate(session.fpwEmailDiagnosticResult);
    structDelete(session, "fpwEmailDiagnosticResult", false);
}

if (isPostRequest) {
    submittedAction = structKeyExists(form, "action") ? lCase(trim(toString(form.action))) : "";
    testId = structKeyExists(form, "testId") ? uCase(trim(toString(form.testId))) : "";
    selectedFrom = structKeyExists(form, "fromAddress") ? lCase(trim(toString(form.fromAddress))) : "";
    replyToValue = structKeyExists(form, "replyTo") ? trim(toString(form.replyTo)) : "";
    copyFromRequested = structKeyExists(form, "copyFromAddress")
        AND compare(trim(toString(form.copyFromAddress)), "1") EQ 0;
    copyReplyToRequested = structKeyExists(form, "copyReplyToAddress")
        AND compare(trim(toString(form.copyReplyToAddress)), "1") EQ 0;
    subjectValue = structKeyExists(form, "subject") ? trim(toString(form.subject)) : "";
    messageBodyValue = structKeyExists(form, "messageBody") ? trim(toString(form.messageBody)) : "";

    if (submittedAction NEQ "send") {
        arrayAppend(formErrors, "Invalid diagnostic action.");
    }

    recipientOverrideFields = ["to", "recipient", "toAddress"];
    for (recipientFieldName in recipientOverrideFields) {
        if (structKeyExists(form, recipientFieldName)
            AND compareNoCase(trim(toString(form[recipientFieldName])), diagnosticRecipient) NEQ 0) {
            arrayAppend(formErrors, "Recipient override rejected. The diagnostic recipient is fixed.");
            break;
        }
    }

    if (!arrayFindNoCase(approvedFromAddresses, selectedFrom)) {
        arrayAppend(formErrors, "The selected From address is not approved for this diagnostic.");
    }

    if (len(replyToValue)) {
        if (len(replyToValue) GT replyToLimit
            OR find(chr(13), replyToValue)
            OR find(chr(10), replyToValue)
            OR !isValid("email", replyToValue)) {
            arrayAppend(formErrors, "Reply-To must be a valid email address of 254 characters or fewer.");
        }
    }

    if (copyReplyToRequested
        AND (!len(replyToValue) OR !arrayFindNoCase(approvedFromAddresses, replyToValue))) {
        arrayAppend(formErrors, "A Reply-To copy can only be sent to an approved allowlisted address.");
    }

    if (!len(subjectValue) OR len(subjectValue) GT subjectLimit
        OR find(chr(13), subjectValue) OR find(chr(10), subjectValue)) {
        arrayAppend(formErrors, "Subject is required, cannot contain line breaks, and must be 180 characters or fewer.");
    }

    mailSubjectValue = findNoCase(testId, subjectValue)
        ? subjectValue
        : subjectValue & " - " & testId;
    if (len(mailSubjectValue) GT subjectLimit) {
        arrayAppend(formErrors, "Subject plus the required test identifier must be 180 characters or fewer.");
    }

    if (!len(messageBodyValue) OR len(messageBodyValue) GT bodyLimit) {
        arrayAppend(formErrors, "Message body is required and must be 5,000 characters or fewer.");
    }

    if (len(testId) GT 80 OR !reFind("^DKIM-[0-9]{8}-[0-9]{6}-[A-F0-9]{8}$", testId)) {
        arrayAppend(formErrors, "The diagnostic test identifier is invalid. Reload the form and try again.");
    }

    if (!arrayLen(formErrors)) {
        if (copyFromRequested AND compareNoCase(selectedFrom, diagnosticRecipient) NEQ 0) {
            arrayAppend(diagnosticBccAddresses, selectedFrom);
        }
        if (copyReplyToRequested
            AND compareNoCase(replyToValue, diagnosticRecipient) NEQ 0
            AND !arrayFindNoCase(diagnosticBccAddresses, replyToValue)) {
            arrayAppend(diagnosticBccAddresses, replyToValue);
        }

        sendTimestamp = dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss");
        diagnosticMailBody = messageBodyValue & chr(10) & chr(10)
            & "Test identifier: " & testId & chr(10)
            & "Test timestamp: " & sendTimestamp & chr(10)
            & "From address: " & selectedFrom & chr(10)
            & "Application/environment: " & environmentLabel & chr(10)
            & "Purpose: Media3 / SmarterMail DKIM diagnostic" & chr(10)
            & "Inspect the received message's raw headers for DKIM-Signature and Authentication-Results.";
        diagnosticMailAttributes = {
            "to" = diagnosticRecipient,
            "from" = selectedFrom,
            "subject" = mailSubjectValue,
            "type" = "text",
            "charset" = "utf-8",
            "spoolenable" = false
        };
        if (len(replyToValue)) {
            diagnosticMailAttributes.replyto = replyToValue;
        }
        if (arrayLen(diagnosticBccAddresses)) {
            diagnosticMailAttributes.bcc = arrayToList(diagnosticBccAddresses, ",");
        }
        sendReady = true;
    }
}
</cfscript>

<cfif sendReady>
    <cftry>
        <cfmail attributeCollection="#diagnosticMailAttributes#">#diagnosticMailBody#</cfmail>
        <cfscript>
        resultToken = lCase(replace(createUUID(), "-", "", "all"));
        session.fpwEmailDiagnosticResult = {
            "resultToken" = resultToken,
            "toAddress" = diagnosticRecipient,
            "fromAddress" = selectedFrom,
            "replyTo" = replyToValue,
            "bccAddresses" = arrayToList(diagnosticBccAddresses, ", "),
            "subject" = mailSubjectValue,
            "sendTimestamp" = sendTimestamp,
            "testId" = testId
        };
        successLocation = request.fpwBase & "/admin/email-test.cfm?sent=" & urlEncodedFormat(resultToken);
        </cfscript>
        <cflocation url="#successLocation#" addtoken="false" statuscode="303">
        <cfcatch type="any">
            <cfscript>
            arrayAppend(formErrors, safeDiagnosticError(cfcatch));
            sendReady = false;
            </cfscript>
        </cfcatch>
    </cftry>
</cfif>

<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Admin Email Delivery Test</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" crossorigin="anonymous">
  <style>
    body{margin:24px;background:#f7f7f7;color:#111;font-family:Arial,sans-serif}
    .admin-wrap{max-width:1560px;margin:0 auto;padding:20px;border:1px solid #ddd;border-radius:8px;background:#fff}
    .diagnostic-panel{max-width:860px}
    .fixed-value{padding:.75rem;border:1px solid #ced4da;border-radius:.375rem;background:#f8f9fa}
    .form-text code{color:inherit}
    @media(max-width:640px){body{margin:10px}.admin-wrap{padding:12px}}
  </style>
</head>
<body>
  <div class="admin-wrap">
    <cfinclude template="includes/admin_reports_nav.cfm">
    <main class="diagnostic-panel">
      <h1 class="h3 mb-1">Email Delivery Test</h1>
      <p class="text-muted">Submit controlled messages through FPW's configured mail server, then compare the received authentication headers.</p>

      <div class="alert alert-warning" role="note">
        This tool does not create DKIM signatures. Media3 / SmarterMail remains responsible for signing the outbound message.
      </div>

      <cfif structCount(sendResult)>
        <div class="alert alert-success" role="status">
          <h2 class="h5">Test email sent</h2>
          <dl class="row mb-2">
            <dt class="col-sm-3">Test identifier</dt>
            <dd class="col-sm-9"><cfoutput>#encodeForHTML(toString(sendResult.testId))#</cfoutput></dd>
            <dt class="col-sm-3">To</dt>
            <dd class="col-sm-9"><cfoutput>#encodeForHTML(toString(sendResult.toAddress))#</cfoutput></dd>
            <dt class="col-sm-3">From</dt>
            <dd class="col-sm-9"><cfoutput>#encodeForHTML(toString(sendResult.fromAddress))#</cfoutput></dd>
            <dt class="col-sm-3">Reply-To</dt>
            <dd class="col-sm-9"><cfoutput>#len(toString(sendResult.replyTo)) ? encodeForHTML(toString(sendResult.replyTo)) : "Not set"#</cfoutput></dd>
            <dt class="col-sm-3">BCC copies</dt>
            <dd class="col-sm-9"><cfoutput>#len(toString(sendResult.bccAddresses)) ? encodeForHTML(toString(sendResult.bccAddresses)) : "No separate copy required"#</cfoutput></dd>
            <dt class="col-sm-3">Subject</dt>
            <dd class="col-sm-9"><cfoutput>#encodeForHTML(toString(sendResult.subject))#</cfoutput></dd>
            <dt class="col-sm-3">Send timestamp</dt>
            <dd class="col-sm-9"><cfoutput>#encodeForHTML(toString(sendResult.sendTimestamp))#</cfoutput></dd>
          </dl>
          <p class="mb-0">Check the raw message headers at the receiving mailbox for <code>DKIM-Signature</code> and <code>Authentication-Results</code>.</p>
        </div>
      </cfif>

      <cfif arrayLen(formErrors)>
        <div class="alert alert-danger" role="alert">
          <h2 class="h5">Test email was not sent</h2>
          <ul class="mb-0">
            <cfloop array="#formErrors#" index="formError">
              <cfoutput><li>#encodeForHTML(toString(formError))#</li></cfoutput>
            </cfloop>
          </ul>
        </div>
      </cfif>

      <form method="post" action="<cfoutput>#encodeForHTMLAttribute(request.fpwBase)#</cfoutput>/admin/email-test.cfm" novalidate>
        <cfoutput>
          <input type="hidden" name="adminCsrfToken" value="#encodeForHTMLAttribute(toString(request.fpwAdminCsrfToken))#">
          <input type="hidden" name="action" value="send">
          <input type="hidden" name="testId" value="#encodeForHTMLAttribute(testId)#">
        </cfoutput>

        <div class="mb-3">
          <label class="form-label">To</label>
          <div class="fixed-value"><cfoutput>#encodeForHTML(diagnosticRecipient)#</cfoutput></div>
          <div class="form-text">The server fixes every diagnostic message to this recipient; it is not submitted by the browser.</div>
        </div>

        <div class="mb-3">
          <label class="form-label" for="fromAddress">From address</label>
          <cfoutput><input class="form-control" type="email" id="fromAddress" name="fromAddress" list="approvedFromAddressOptions" maxlength="#fromAddressLimit#" value="#encodeForHTMLAttribute(selectedFrom)#" required></cfoutput>
          <datalist id="approvedFromAddressOptions">
            <cfloop array="#approvedFromAddresses#" index="approvedFromAddress">
              <cfoutput><option value="#encodeForHTMLAttribute(approvedFromAddress)#"></cfoutput>
            </cfloop>
          </datalist>
          <div class="form-text">Type or choose an approved sender address. Every submitted value is checked against the server-side allowlist.</div>
        </div>

        <div class="mb-3">
          <label class="form-label" for="replyTo">Reply-To <span class="text-muted">(optional)</span></label>
          <cfoutput><input class="form-control" type="email" id="replyTo" name="replyTo" maxlength="#replyToLimit#" value="#encodeForHTMLAttribute(replyToValue)#"></cfoutput>
        </div>

        <fieldset class="mb-3">
          <legend class="h6">Copies</legend>
          <div class="form-check">
            <cfoutput><input class="form-check-input" type="checkbox" id="copyFromAddress" name="copyFromAddress" value="1"<cfif copyFromRequested> checked</cfif>></cfoutput>
            <label class="form-check-label" for="copyFromAddress">Send a BCC copy to the From address</label>
          </div>
          <div class="form-check">
            <cfoutput><input class="form-check-input" type="checkbox" id="copyReplyToAddress" name="copyReplyToAddress" value="1"<cfif copyReplyToRequested> checked</cfif>></cfoutput>
            <label class="form-check-label" for="copyReplyToAddress">Send a BCC copy to the Reply-To address</label>
          </div>
          <div class="form-text">Copies are limited to approved allowlisted addresses. No duplicate BCC is added when an address already receives the primary message or another copy.</div>
        </fieldset>

        <div class="mb-3">
          <label class="form-label" for="subject">Subject</label>
          <cfoutput><input class="form-control" type="text" id="subject" name="subject" maxlength="#subjectLimit#" value="#encodeForHTMLAttribute(subjectValue)#" required></cfoutput>
        </div>

        <div class="mb-3">
          <label class="form-label" for="messageBody">Message body</label>
          <cfoutput><textarea class="form-control" id="messageBody" name="messageBody" rows="8" maxlength="#bodyLimit#" required>#encodeForHTML(messageBodyValue)#</textarea></cfoutput>
          <div class="form-text">The server appends the test identifier, timestamp, selected From address, environment, and diagnostic purpose.</div>
        </div>

        <div class="mb-3">
          <strong>Test identifier:</strong> <cfoutput>#encodeForHTML(testId)#</cfoutput>
        </div>

        <button class="btn btn-primary" type="submit">Send Test Email</button>
      </form>
    </main>
  </div>
</body>
</html>
