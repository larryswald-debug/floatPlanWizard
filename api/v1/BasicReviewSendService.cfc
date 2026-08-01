component output="false" {

  variables.datasource = "fpw";
  variables.emailService = 0;
  variables.pdfService = 0;

  public any function init(
    string datasource="fpw",
    any emailService="",
    any pdfService=""
  ) output=false {
    variables.datasource = len(trim(arguments.datasource)) ? trim(arguments.datasource) : "fpw";
    variables.emailService = isObject(arguments.emailService)
      ? arguments.emailService
      : createEmailService();
    variables.pdfService = isObject(arguments.pdfService)
      ? arguments.pdfService
      : createPdfService();
    return this;
  }

  public struct function getConfirmation(
    required numeric userId,
    required numeric floatPlanId
  ) output=false {
    var plan = loadOwnedDraftPlan(arguments.userId, arguments.floatPlanId);
    var contacts = [];
    var validCount = 0;
    var index = 0;

    if (!plan.SUCCESS) {
      return plan;
    }

    contacts = loadSavedContacts(arguments.userId, arguments.floatPlanId);
    if (!arrayLen(contacts)) {
      return failure("NO_CONTACTS", "Select a notification contact and save the float plan before using Basic Send.");
    }

    for (index = 1; index LTE arrayLen(contacts); index++) {
      if (contacts[index].VALID_EMAIL) {
        validCount++;
      }
    }

    if (arrayLen(contacts) EQ 1 AND !contacts[1].VALID_EMAIL) {
      return failure("CONTACT_EMAIL_REQUIRED", "The selected contact needs a valid email address before using Basic Send.");
    }
    if (validCount EQ 0) {
      return failure("NO_VALID_CONTACT_EMAILS", "None of the selected contacts has a valid email address.");
    }

    return {
      SUCCESS = true,
      FLOATPLANID = val(arguments.floatPlanId),
      FLOAT_PLAN_NAME = plan.FLOAT_PLAN_NAME,
      CAPTAIN_NAME = plan.CAPTAIN_NAME,
      STATUS = plan.STATUS,
      CONTACTS = contacts,
      CONTACT_COUNT = arrayLen(contacts),
      VALID_CONTACT_COUNT = validCount,
      REQUIRES_SELECTION = arrayLen(contacts) GT 1,
      SELECTED_CONTACT_ID = arrayLen(contacts) EQ 1 ? contacts[1].CONTACTID : 0
    };
  }

  public struct function send(
    required numeric userId,
    required numeric floatPlanId,
    required numeric contactId,
    required string idempotencyKey,
    string requestCorrelationId=""
  ) output=false {
    var confirmation = {};
    var contact = {};
    var cleanKey = trim(arguments.idempotencyKey);
    var cleanCorrelationId = left(trim(arguments.requestCorrelationId), 64);
    var claim = {};
    var pdfFileName = "";
    var pdfPath = "";
    var emailResult = {};
    var response = {};
    var errorResponse = {};

    if (!reFind("^[A-Za-z0-9_-]{20,191}$", cleanKey)) {
      return failure("INVALID_IDEMPOTENCY_KEY", "A valid Basic Send request token is required.");
    }

    confirmation = getConfirmation(arguments.userId, arguments.floatPlanId);
    if (!confirmation.SUCCESS) {
      return confirmation;
    }

    contact = findContact(confirmation.CONTACTS, arguments.contactId);
    if (structIsEmpty(contact)) {
      return failure("CONTACT_NOT_SELECTED", "Choose one of the contacts saved with this float plan.");
    }
    if (!contact.VALID_EMAIL) {
      return failure("CONTACT_EMAIL_REQUIRED", "The selected contact needs a valid email address before using Basic Send.");
    }

    claim = claimReceipt(
      userId = arguments.userId,
      floatPlanId = arguments.floatPlanId,
      contact = contact,
      idempotencyKey = cleanKey,
      requestCorrelationId = cleanCorrelationId
    );
    if (!claim.SUCCESS) {
      return claim;
    }
    if (!structKeyExists(claim, "CLAIMED") OR !claim.CLAIMED) {
      return claim;
    }

    logDelivery(
      userId = arguments.userId,
      floatPlanId = arguments.floatPlanId,
      contactId = contact.CONTACTID,
      recipientEmail = contact.EMAIL,
      status = "PROCESSING",
      errorCode = ""
    );

    try {
      pdfFileName = variables.pdfService.createPDF(arguments.floatPlanId, arguments.userId);
      if (!len(trim(pdfFileName))) {
        errorResponse = failure("PDF_FAILED", "Unable to generate the Basic float-plan PDF.");
        failReceipt(claim.RECEIPT_ID, errorResponse, "");
        logDelivery(arguments.userId, arguments.floatPlanId, contact.CONTACTID, contact.EMAIL, "FAILED", errorResponse.ERROR);
        return errorResponse;
      }

      pdfPath = variables.pdfService.getPdfPath(pdfFileName);
      if (!len(trim(pdfPath)) OR !fileExists(pdfPath)) {
        errorResponse = failure("PDF_NOT_FOUND", "The generated Basic float-plan PDF is unavailable.");
        failReceipt(claim.RECEIPT_ID, errorResponse, pdfFileName);
        logDelivery(arguments.userId, arguments.floatPlanId, contact.CONTACTID, contact.EMAIL, "FAILED", errorResponse.ERROR);
        return errorResponse;
      }

      emailResult = variables.emailService.sendBasicReviewFloatPlanEmail(
        userId = arguments.userId,
        toEmail = contact.EMAIL,
        contactName = contact.NAME,
        floatPlanName = confirmation.FLOAT_PLAN_NAME,
        captainName = confirmation.CAPTAIN_NAME,
        pdfPath = pdfPath
      );
      if (!structKeyExists(emailResult, "success") OR emailResult.success NEQ true) {
        errorResponse = failure(
          structKeyExists(emailResult, "errorCode") AND len(trim(toString(emailResult.errorCode)))
            ? trim(toString(emailResult.errorCode))
            : "EMAIL_SEND_FAILED",
          structKeyExists(emailResult, "message") AND len(trim(toString(emailResult.message)))
            ? trim(toString(emailResult.message))
            : "The Basic float-plan email could not be sent."
        );
        failReceipt(claim.RECEIPT_ID, errorResponse, pdfFileName);
        logDelivery(arguments.userId, arguments.floatPlanId, contact.CONTACTID, contact.EMAIL, "FAILED", errorResponse.ERROR);
        return errorResponse;
      }

      response = {
        SUCCESS = true,
        MESSAGE = "Basic float plan emailed to " & contact.EMAIL & ".",
        FLOATPLANID = val(arguments.floatPlanId),
        STATUS = "DRAFT",
        SENT_COUNT = 1,
        RECIPIENT = {
          CONTACTID = contact.CONTACTID,
          NAME = contact.NAME,
          EMAIL = contact.EMAIL
        },
        RECEIPT_ID = claim.RECEIPT_ID,
        IDEMPOTENT_REPLAY = false,
        CREDIT_CONSUMED = false,
        MONITORING_ACTIVATED = false,
        ACTIVE_CRUISE_ACTIVATED = false,
        TRIP_FOLLOW_CREATED = false
      };
      completeReceipt(claim.RECEIPT_ID, response, pdfFileName);
      logDelivery(arguments.userId, arguments.floatPlanId, contact.CONTACTID, contact.EMAIL, "SENT", "");
      return response;
    } catch (any sendError) {
      errorResponse = failure("BASIC_REVIEW_SEND_FAILED", "The Basic float plan could not be sent. Please reopen Basic Send and try again.");
      failReceipt(claim.RECEIPT_ID, errorResponse, pdfFileName);
      logDelivery(arguments.userId, arguments.floatPlanId, contact.CONTACTID, contact.EMAIL, "FAILED", errorResponse.ERROR);
      return errorResponse;
    }
  }

  private struct function loadOwnedDraftPlan(
    required numeric userId,
    required numeric floatPlanId
  ) output=false {
    var qPlan = queryNew("");
    var statusValue = "";
    var planName = "";
    var captainName = "";

    if (arguments.userId LTE 0 OR arguments.floatPlanId LTE 0) {
      return failure("PLAN_NOT_FOUND", "Float plan not found.");
    }

    qPlan = queryExecute(
      "SELECT
         fp.floatPlanId,
         fp.floatPlanName,
         fp.status,
         fp.route_instance_id,
         o.name AS operator_name,
         u.fName,
         u.lName
       FROM floatplans fp
       INNER JOIN users u ON u.userId = :userId
       LEFT JOIN operators o
         ON o.opId = fp.operatorId
        AND TRIM(CAST(o.userId AS CHAR)) = CAST(:userId AS CHAR)
       WHERE fp.floatPlanId = :floatPlanId
         AND TRIM(CAST(fp.userId AS CHAR)) = CAST(:userId AS CHAR)
       LIMIT 1",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );

    if (qPlan.recordCount NEQ 1) {
      return failure("PLAN_NOT_FOUND", "Float plan not found.");
    }
    statusValue = uCase(trim(toString(qPlan.status[1])));
    if (statusValue NEQ "DRAFT") {
      return failure("INVALID_STATUS", "Basic Send from Review is available only while this float plan is a Draft.");
    }
    if (isNull(qPlan.route_instance_id[1]) OR val(qPlan.route_instance_id[1]) LTE 0) {
      return failure("ROUTE_PLAN_REQUIRED", "Basic Send from Review requires the saved route-backed float plan.");
    }

    planName = isNull(qPlan.floatPlanName[1]) ? "" : trim(toString(qPlan.floatPlanName[1]));
    captainName = isNull(qPlan.operator_name[1]) ? "" : trim(toString(qPlan.operator_name[1]));
    if (!len(captainName)) {
      captainName = trim(
        (isNull(qPlan.fName[1]) ? "" : toString(qPlan.fName[1]))
        & " "
        & (isNull(qPlan.lName[1]) ? "" : toString(qPlan.lName[1]))
      );
    }

    return {
      SUCCESS = true,
      FLOATPLANID = val(qPlan.floatPlanId[1]),
      FLOAT_PLAN_NAME = len(planName) ? planName : "Float Plan",
      CAPTAIN_NAME = len(captainName) ? captainName : "FPW member",
      STATUS = statusValue
    };
  }

  private array function loadSavedContacts(
    required numeric userId,
    required numeric floatPlanId
  ) output=false {
    var contacts = [];
    var qContacts = queryExecute(
      "SELECT c.contactId, c.name, c.email
       FROM floatplan_contacts fpc
       INNER JOIN floatplans fp
         ON fp.floatPlanId = fpc.floatPlanId
        AND TRIM(CAST(fp.userId AS CHAR)) = CAST(:userId AS CHAR)
       INNER JOIN contacts c
         ON c.contactId = fpc.contactId
        AND TRIM(CAST(c.userId AS CHAR)) = CAST(:userId AS CHAR)
       WHERE fpc.floatPlanId = :floatPlanId
       ORDER BY fpc.recId ASC",
      {
        userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
        floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
      },
      { datasource = variables.datasource }
    );
    var index = 0;
    var emailAddress = "";

    for (index = 1; index LTE qContacts.recordCount; index++) {
      emailAddress = isNull(qContacts.email[index]) ? "" : lCase(trim(toString(qContacts.email[index])));
      arrayAppend(contacts, {
        CONTACTID = val(qContacts.contactId[index]),
        NAME = isNull(qContacts.name[index]) ? "" : trim(toString(qContacts.name[index])),
        EMAIL = emailAddress,
        VALID_EMAIL = len(emailAddress) AND isValid("email", emailAddress)
      });
    }
    return contacts;
  }

  private struct function findContact(required array contacts, required numeric contactId) output=false {
    var index = 0;
    for (index = 1; index LTE arrayLen(arguments.contacts); index++) {
      if (val(arguments.contacts[index].CONTACTID) EQ val(arguments.contactId)) {
        return arguments.contacts[index];
      }
    }
    return {};
  }

  private struct function claimReceipt(
    required numeric userId,
    required numeric floatPlanId,
    required struct contact,
    required string idempotencyKey,
    string requestCorrelationId=""
  ) output=false {
    var qInsertCount = queryNew("");
    var qReceipt = queryNew("");
    var wasInserted = false;
    var storedResponse = {};

    transaction {
      queryExecute(
        "INSERT IGNORE INTO basic_review_send_receipts (
           user_id,
           float_plan_id,
           contact_id,
           idempotency_key,
           status,
           recipient_email,
           pdf_file_name,
           error_code,
           response_json,
           request_correlation_id,
           created_at_utc,
           updated_at_utc,
           completed_at_utc
         ) VALUES (
           :userId,
           :floatPlanId,
           :contactId,
           :idempotencyKey,
           'PROCESSING',
           :recipientEmail,
           NULL,
           NULL,
           NULL,
           :requestCorrelationId,
           UTC_TIMESTAMP(6),
           UTC_TIMESTAMP(6),
           NULL
         )",
        {
          userId = { value = arguments.userId, cfsqltype = "cf_sql_integer" },
          floatPlanId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
          contactId = { value = arguments.contact.CONTACTID, cfsqltype = "cf_sql_integer" },
          idempotencyKey = { value = arguments.idempotencyKey, cfsqltype = "cf_sql_varchar" },
          recipientEmail = { value = arguments.contact.EMAIL, cfsqltype = "cf_sql_varchar" },
          requestCorrelationId = nullableVarchar(arguments.requestCorrelationId)
        },
        { datasource = variables.datasource }
      );
      qInsertCount = queryExecute(
        "SELECT ROW_COUNT() AS inserted_count",
        {},
        { datasource = variables.datasource }
      );
      wasInserted = qInsertCount.recordCount EQ 1 AND val(qInsertCount.inserted_count[1]) EQ 1;

      qReceipt = queryExecute(
        "SELECT id, user_id, float_plan_id, contact_id, status, recipient_email, response_json, error_code
         FROM basic_review_send_receipts
         WHERE idempotency_key = :idempotencyKey
         LIMIT 1
         FOR UPDATE",
        {
          idempotencyKey = { value = arguments.idempotencyKey, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = variables.datasource }
      );

      if (qReceipt.recordCount NEQ 1) {
        return failure("RECEIPT_CLAIM_FAILED", "The Basic Send request could not be reserved.");
      }
      if (
        val(qReceipt.user_id[1]) NEQ val(arguments.userId)
        OR val(qReceipt.float_plan_id[1]) NEQ val(arguments.floatPlanId)
        OR val(qReceipt.contact_id[1]) NEQ val(arguments.contact.CONTACTID)
      ) {
        return failure("IDEMPOTENCY_CONFLICT", "The Basic Send request token is already assigned.");
      }
      if (wasInserted) {
        return {
          SUCCESS = true,
          CLAIMED = true,
          RECEIPT_ID = val(qReceipt.id[1])
        };
      }

      if (uCase(trim(toString(qReceipt.status[1]))) EQ "SENT") {
        if (!isNull(qReceipt.response_json[1]) AND len(trim(toString(qReceipt.response_json[1])))) {
          storedResponse = deserializeJSON(toString(qReceipt.response_json[1]));
        } else {
          storedResponse = {
            SUCCESS = true,
            MESSAGE = "This Basic Send request was already completed.",
            RECEIPT_ID = val(qReceipt.id[1])
          };
        }
        storedResponse.IDEMPOTENT_REPLAY = true;
        storedResponse.idempotentReplay = true;
        return storedResponse;
      }

      if (uCase(trim(toString(qReceipt.status[1]))) EQ "FAILED") {
        if (!isNull(qReceipt.response_json[1]) AND len(trim(toString(qReceipt.response_json[1])))) {
          storedResponse = deserializeJSON(toString(qReceipt.response_json[1]));
          storedResponse.IDEMPOTENT_REPLAY = true;
          return storedResponse;
        }
        return failure("REQUEST_PREVIOUSLY_FAILED", "This Basic Send request did not complete. Reopen Basic Send to start a new request.");
      }

      return failure("REQUEST_IN_PROGRESS", "This Basic Send request is already in progress.");
    }
  }

  private void function completeReceipt(
    required numeric receiptId,
    required struct response,
    required string pdfFileName
  ) output=false {
    queryExecute(
      "UPDATE basic_review_send_receipts
       SET status = 'SENT',
           pdf_file_name = :pdfFileName,
           error_code = NULL,
           response_json = :responseJson,
           updated_at_utc = UTC_TIMESTAMP(6),
           completed_at_utc = UTC_TIMESTAMP(6)
       WHERE id = :receiptId
         AND status = 'PROCESSING'",
      {
        receiptId = { value = arguments.receiptId, cfsqltype = "cf_sql_bigint" },
        pdfFileName = nullableVarchar(arguments.pdfFileName),
        responseJson = { value = serializeJSON(arguments.response), cfsqltype = "cf_sql_longvarchar" }
      },
      { datasource = variables.datasource }
    );
  }

  private void function failReceipt(
    required numeric receiptId,
    required struct response,
    string pdfFileName=""
  ) output=false {
    queryExecute(
      "UPDATE basic_review_send_receipts
       SET status = 'FAILED',
           pdf_file_name = :pdfFileName,
           error_code = :errorCode,
           response_json = :responseJson,
           updated_at_utc = UTC_TIMESTAMP(6),
           completed_at_utc = UTC_TIMESTAMP(6)
       WHERE id = :receiptId
         AND status = 'PROCESSING'",
      {
        receiptId = { value = arguments.receiptId, cfsqltype = "cf_sql_bigint" },
        pdfFileName = nullableVarchar(arguments.pdfFileName),
        errorCode = { value = left(trim(toString(arguments.response.ERROR)), 64), cfsqltype = "cf_sql_varchar" },
        responseJson = { value = serializeJSON(arguments.response), cfsqltype = "cf_sql_longvarchar" }
      },
      { datasource = variables.datasource }
    );
  }

  private void function logDelivery(
    required numeric userId,
    required numeric floatPlanId,
    required numeric contactId,
    required string recipientEmail,
    required string status,
    string errorCode=""
  ) output=false {
    writeLog(
      file = "fpw_basic_review_send",
      type = uCase(arguments.status) EQ "FAILED" ? "error" : "information",
      text = "BASIC_REVIEW_SEND"
        & " | memberId=" & val(arguments.userId)
        & " | floatPlanId=" & val(arguments.floatPlanId)
        & " | contactId=" & val(arguments.contactId)
        & " | destination=" & replace(replace(lCase(trim(arguments.recipientEmail)), chr(13), "", "all"), chr(10), "", "all")
        & " | sendType=BASIC"
        & " | status=" & uCase(trim(arguments.status))
        & " | errorCode=" & left(reReplace(trim(arguments.errorCode), "[^A-Za-z0-9_-]", "", "all"), 64)
        & " | timestamp=" & dateTimeFormat(now(), "yyyy-mm-dd'T'HH:nn:ss")
    );
  }

  private struct function failure(required string errorCode, required string message) output=false {
    return {
      SUCCESS = false,
      success = false,
      ERROR = trim(arguments.errorCode),
      errorCode = trim(arguments.errorCode),
      MESSAGE = trim(arguments.message),
      message = trim(arguments.message),
      CREDIT_CONSUMED = false,
      MONITORING_ACTIVATED = false,
      ACTIVE_CRUISE_ACTIVATED = false,
      TRIP_FOLLOW_CREATED = false
    };
  }

  private struct function nullableVarchar(required string value) output=false {
    var cleanValue = trim(arguments.value);
    return {
      value = cleanValue,
      cfsqltype = "cf_sql_varchar",
      null = !len(cleanValue)
    };
  }

  private any function createEmailService() output=false {
    try {
      return createObject("component", "fpw.api.v1.email").init();
    } catch (any prefixedError) {
      return createObject("component", "api.v1.email").init();
    }
  }

  private any function createPdfService() output=false {
    try {
      return createObject("component", "fpw.api.api_assets.floatPlanUtils").init();
    } catch (any prefixedError) {
      return createObject("component", "api.api_assets.floatPlanUtils").init();
    }
  }
}
