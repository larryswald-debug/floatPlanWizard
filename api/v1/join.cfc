<cfcomponent output="false">
    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfsetting showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">
        <cfscript>
            var response={SUCCESS=false,AUTH=false,ERROR="SERVER_ERROR",MESSAGE="Account access is temporarily unavailable."};
            var ticket={};
            var creationTicket={};
            var limiter=createObject("component",componentPath("api.v1.AuthRateLimitService")).init("fpw");
            try {
                var body={};
                var raw=toString(getHttpRequestData().content);
                if (len(trim(raw))) body=deserializeJSON(raw,false);
                else body=duplicate(form);
                if (!isStruct(body)) throw(type="FPW.Auth.InvalidBody");
                var guard=createObject("component",componentPath("api.v1.AuthRequestGuardService"));
                var allowed=guard.validateMutation(body);
                if (!allowed.ALLOWED) {
                    cfheader(statuscode=allowed.STATUSCODE);
                    response={SUCCESS=false,AUTH=false,ERROR=allowed.CODE,MESSAGE=allowed.MESSAGE};
                } else {
                    var email=lcase(trim(toString(body.email ?: "")));
                    var admission=limiter.admit("authenticate",email,guard.getClientIp());
                    if (!admission.ALLOWED) {
                        cfheader(statuscode=admission.STATUSCODE);
                        if (structKeyExists(admission,"RETRYAFTER")) cfheader(name="Retry-After",value=admission.RETRYAFTER);
                        response={SUCCESS=false,AUTH=false,ERROR=admission.CODE,MESSAGE=admission.MESSAGE};
                    } else {
                        ticket=admission.TICKET;
                        var creation=limiter.admit("create_account",email,guard.getClientIp());
                        if (!creation.ALLOWED) {
                            cfheader(statuscode=creation.STATUSCODE);
                            if (structKeyExists(creation,"RETRYAFTER")) cfheader(name="Retry-After",value=creation.RETRYAFTER);
                            response={SUCCESS=false,AUTH=false,ERROR=creation.CODE,MESSAGE=creation.MESSAGE};
                        } else {
                            creationTicket=creation.TICKET;
                            response=createAccount(body,false);
                            if (response.SUCCESS AND (response.AUTH ?: false)) {
                                var continuation=createObject("component",componentPath("includes.AuthContinuationService"));
                                var token=toString(body.intentToken ?: "");
                                var entry=continuation.getIntent(token,response.USERID);
                                if (structIsEmpty(entry)) entry=continuation.createIntent("dashboard");
                                var resolved=continuation.resolve(entry.token,response.USERID,true);
                                response.REDIRECT_URL=resolved.redirectUrl;
                                response.CSRF_TOKEN=guard.rotateCsrfToken();
                            }
                        }
                    }
                }
            } catch (any failure) {
                writeLog(file="fpw_auth",type="error",text="JOIN_FAILED");
            } finally {
                if (!structIsEmpty(creationTicket)) limiter.finish(creationTicket,(response.SUCCESS AND (response.AUTH ?: false)) ? "success" : "error");
                if (!structIsEmpty(ticket)) limiter.finish(ticket,(response.SUCCESS AND (response.AUTH ?: false)) ? "success" : "error");
            }
            writeOutput(serializeJSON(response));
        </cfscript>
    </cffunction>

    <cffunction name="getConsentDisclosure" access="public" returntype="struct" output="false">
        <cfset var root=getDirectoryFromPath(getCurrentTemplatePath()) & "../../">
        <cfset var termsRevision=lcase(hash(fileRead(root & "terms_of_service.cfm","utf-8"),"SHA-256","UTF-8"))>
        <cfset var privacyRevision=lcase(hash(fileRead(root & "privacy_policy.cfm","utf-8"),"SHA-256","UTF-8"))>
        <cfset var disclosureText="By clicking Continue, you agree to the Terms of Use and acknowledge the Privacy Policy.">
        <cfset var revision=lcase(hash("continue_disclosure:v1|" & disclosureText & "|" & termsRevision & "|" & privacyRevision,"SHA-256","UTF-8"))>
        <cfreturn {REVISION=revision,TEXT=disclosureText,TERMS_REVISION=termsRevision,PRIVACY_REVISION=privacyRevision,
            TERMS_URL=resolveFpwBasePath() & "/terms_of_service.cfm",PRIVACY_URL=resolveFpwBasePath() & "/privacy_policy.cfm"}>
    </cffunction>

    <!-- Canonical business operation. Public for auth.cfc, deliberately NOT remote. -->
    <cffunction name="createAccount" access="public" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">
        <cfargument name="unified" type="boolean" default="false">
        <cfset var qExisting="">
        <cfset var newIdQ="">
        <cftry>
            <cfset var firstName = trim(body.firstName ?: body.fName ?: "")>
            <cfset var lastName = trim(body.lastName  ?: body.lName ?: "")>
            <cfset var email = lcase(trim(body.email ?: ""))>
            <cfset var address = trim(body.address   ?: "")>
            <cfset var city = trim(body.city      ?: "")>
            <cfset var state = trim(body.state     ?: "")>
            <cfset var zip = trim(body.zip       ?: "")>
            <cfset var phone = trim(body.phone     ?: "")>
            <cfset var website = trim(body.website   ?: "")>
            <cfset var password = trim(body.password  ?: "")>
            <cfset var confirmPassword = "">
            <cfif structKeyExists(body, "confirmPassword")>
                <cfset var confirmPassword = trim(body.confirmPassword)>
            <cfelseif structKeyExists(body, "passwordConfirm")>
                <cfset var confirmPassword = trim(body.passwordConfirm)>
            </cfif>
            <cfset var termsValue = false>
            <cfif structKeyExists(body, "termsAccepted")>
                <cfset var termsValue = body.termsAccepted>
            <cfelseif structKeyExists(body, "acceptTerms")>
                <cfset var termsValue = body.acceptTerms>
            <cfelseif structKeyExists(body, "terms")>
                <cfset var termsValue = body.terms>
            </cfif>
            <cfset var termsAccepted = isTruthy(termsValue)>
            <cfset var disclosure = getConsentDisclosure()>
            <cfif arguments.unified>
                <cfset var confirmPassword = password>
                <cfset var termsAccepted = compare(toString(body.disclosureRevision ?: ""), disclosure.REVISION) EQ 0>
            </cfif>
            <cfif compare(toString(body.disclosureRevision ?: ""), disclosure.REVISION) NEQ 0>
                <cfreturn {SUCCESS=false,AUTH=false,ERROR="CONSENT_UPDATED",MESSAGE="Please review the current terms disclosure and select Continue again."}>
            </cfif>
            <cfset var signupAttribution = normalizeSignupAttribution(body)>

            <cfif len(website)>
                <cfset var response = {
                    SUCCESS = true,
                    success = true,
                    AUTH = false,
                    auth = false,
                    MESSAGE = "User created successfully."
                }>
                <cfreturn response>
            </cfif>

            <cfset var premiumSendCreditModelEnabled = (
                structKeyExists(application, "premiumSendCreditModelEnabled")
                AND listFindNoCase("1,true,yes,on", lCase(trim(toString(application.premiumSendCreditModelEnabled)))) GT 0
            )>
            <cfset var redirectUrl = resolveFpwBasePath() & "/app/dashboard.cfm">

            <!-- Validate required fields -->
            <cfif NOT len(email)>
                <cfset var response = {
                    SUCCESS = false,
                    MESSAGE = "Email is required.",
                    ERROR   = "MISSING_FIELDS"
                }>
                <cfreturn response>
            </cfif>

            <cfif len(firstName) GT 45 OR len(lastName) GT 45 OR len(email) GT 255>
                <cfreturn {SUCCESS=false,AUTH=false,ERROR="INVALID_FIELDS",MESSAGE="Check the length of the supplied account fields."}>
            </cfif>
            <cfif NOT reFindNoCase("^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$", email)>
                <cfset var response = {
                    SUCCESS = false,
                    MESSAGE = "Enter a valid email address.",
                    ERROR   = "INVALID_EMAIL"
                }>
                <cfreturn response>
            </cfif>

            <cfif NOT len(password)>
                <cfset var response = {
                    SUCCESS = false,
                    MESSAGE = "Password is required.",
                    ERROR   = "PASSWORD_REQUIRED"
                }>
                <cfreturn response>
            </cfif>

            <cfif len(password) LT 8>
                <cfset var response = {
                    SUCCESS = false,
                    MESSAGE = "Password must be at least 8 characters.",
                    ERROR   = "PASSWORD_TOO_SHORT"
                }>
                <cfreturn response>
            </cfif>

            <cfif NOT len(confirmPassword) OR password NEQ confirmPassword>
                <cfset var response = {
                    SUCCESS = false,
                    MESSAGE = "Password and confirmation do not match.",
                    ERROR   = "PASSWORD_MISMATCH"
                }>
                <cfreturn response>
            </cfif>

            <cfif NOT termsAccepted>
                <cfset var response = {
                    SUCCESS = false,
                    MESSAGE = "Agreeing to the Terms of Service is required.",
                    ERROR   = "TERMS_REQUIRED"
                }>
                <cfreturn response>
            </cfif>

            <cfset var phoneValidation = normalizeOptionalUsPhone(phone)>
            <cfif NOT phoneValidation.valid>
                <cfset var response = {
                    SUCCESS = false,
                    MESSAGE = "Please enter a valid US phone number or leave the phone field blank.",
                    ERROR   = "INVALID_PHONE"
                }>
                <cfreturn response>
            </cfif>
            <cfset var phone = phoneValidation.value>

            <!-- Check for duplicate email -->
            <cfquery name="qExisting" datasource="fpw">
                SELECT userId
                FROM users
                WHERE LOWER(email) = LOWER(
                    <cfqueryparam cfsqltype="cf_sql_varchar" value="#email#">
                )
                LIMIT 1
            </cfquery>

            <cfif qExisting.recordCount GT 0>
                <cfset var response = {
                    SUCCESS = false,
                    MESSAGE = "That email is already registered.",
                    ERROR   = "EMAIL_EXISTS"
                }>
                <cfreturn response>
            </cfif>

            <!-- Required for race-safe creation; never fall back to the old check-only path. -->
            <cfset var emailIndex = queryExecute("SELECT IF(COUNT(*)=1 AND SUM(non_unique=0 AND column_name='email' AND seq_in_index=1 AND sub_part IS NULL)=1,1,0) AS n FROM information_schema.statistics WHERE table_schema=DATABASE() AND table_name='users' AND index_name='uq_users_email'", {}, {datasource="fpw"})>
            <cfif val(emailIndex.n[1]) NEQ 1>
                <cfreturn {SUCCESS=false,AUTH=false,ERROR="AUTH_UNAVAILABLE",MESSAGE="Account access is temporarily unavailable. Please try again later."}>
            </cfif>
            <cfset var passwordHash = createObject("component",componentPath("api.v1.PasswordHashService")).hashPassword(password)>
            <cfset var nowStamp = now()>

            <!-- Build values for users insert -->
            <cfset var userValues = {}>
            <cfset userValues.email = email>
            <cfset userValues.username = email>
            <cfset userValues.userName = email>
            <cfset userValues.fname = firstName>
            <cfset userValues.firstname = firstName>
            <cfset userValues.lname = lastName>
            <cfset userValues.lastname = lastName>
            <cfset userValues.password = passwordHash>
            <cfset userValues.passwordcreated = nowStamp>
            <cfset userValues.lastupdate = nowStamp>
            <cfset userValues.created = nowStamp>
            <cfset userValues.mobilephone = phone>

            <cfset var userInsert = buildInsert("users", userValues)>
            <cfif NOT userInsert.ok>
                <cflog
                    file="user_caused_errors"
                    type="error"
                    text="join.cfc INSERT_FAILED | message=#userInsert.message# | detail=unavailable | script=#(structKeyExists(cgi, 'script_name') ? cgi.script_name : 'unavailable')# | template=#getCurrentTemplatePath()# | time=#now()# | line=unavailable">
                <cfset var response = {
                    SUCCESS = false,
                    MESSAGE = "An error has occurred while processing your request. The site administrator has been notified. If you continue to experience this issue, please contact us using the Contact Us form.",
                    ERROR   = "INSERT_FAILED"
                }>
                <cfreturn response>
            </cfif>

            <cftransaction>
                <cfset queryExecute(
                    userInsert.sql,
                    userInsert.params,
                    { datasource = "fpw" }
                )>
                <cfset var newIdQ = queryExecute("SELECT LAST_INSERT_ID() AS newId", {}, { datasource = "fpw" })>
                <cfset var newUserId = val(newIdQ.newId[1])>
                <cfif newUserId LTE 0>
                    <cfthrow type="FPW.Signup.UserInsertFailed" message="The new member id was not created.">
                </cfif>

                <!-- Optional address/phone insert -->
                <cfif len(address) OR len(city) OR len(state) OR len(zip) OR len(phone)>
                    <cfset var addrValues = {}>
                    <cfset addrValues.userid = newUserId>
                    <cfset addrValues.address = address>
                    <cfset addrValues.city = city>
                    <cfset addrValues.state = state>
                    <cfset addrValues.zip = zip>
                    <cfset addrValues.phone = phone>
                    <cfset addrValues.ishomeport = 0>
                    <cfset addrValues.created = nowStamp>
                    <cfset addrValues.lastupdate = nowStamp>

                    <cfset var addrInsert = buildInsert("users_address", addrValues)>
                    <cfif NOT addrInsert.ok>
                        <cfthrow type="FPW.Signup.AddressInsertFailed" message="#addrInsert.message#">
                    </cfif>
                    <cfset queryExecute(
                        addrInsert.sql,
                        addrInsert.params,
                        { datasource = "fpw" }
                    )>
                </cfif>

                <cfquery datasource="fpw">
                    UPDATE users
                    SET lastLogin = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#nowStamp#">
                    WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#newUserId#">
                </cfquery>

                <cfif premiumSendCreditModelEnabled>
                    <cftry>
                        <cfset var creditService = createObject("component", "fpw.api.v1.PremiumSendCreditService").init("fpw")>
                        <cfcatch>
                            <cfset var creditService = createObject("component", "api.v1.PremiumSendCreditService").init("fpw")>
                        </cfcatch>
                    </cftry>
                    <cfset var creditGrant = creditService.grantCreditInCurrentTransaction(
                        userId = newUserId,
                        source = "complimentary_signup",
                        idempotencyKey = "complimentary_signup:user:" & newUserId
                    )>
                    <cfif NOT creditGrant.SUCCESS>
                        <cfthrow
                            type="FPW.Signup.PremiumSendCreditGrantFailed"
                            message="#creditGrant.MESSAGE#"
                            detail="#creditGrant.ERROR#">
                    </cfif>
                </cfif>
            <cfset var signUpEventMetadata = {
                signup_method = "password",
                account_tier = "basic",
                onboarding_model = premiumSendCreditModelEnabled ? "premium_send_credit" : "legacy_trial",
                complimentary_premium_send_credit = premiumSendCreditModelEnabled,
                acceptance_method = arguments.unified ? "continue_disclosure" : "dedicated_checkbox",
                terms_revision = disclosure.TERMS_REVISION,
                privacy_revision = disclosure.PRIVACY_REVISION,
                disclosure_revision = disclosure.REVISION
            }>
            <cfif NOT structIsEmpty(signupAttribution)>
                <cfset structAppend(signUpEventMetadata, signupAttribution, true)>
            </cfif>

            <cfset createObject("component",componentPath("includes.InactiveMemberRecoveryCoverageService")).init(datasource="fpw").recordSignupInCurrentTransaction(
                userId = newUserId,
                signupMetadata = signUpEventMetadata
            )>
            </cftransaction>

            <!-- Enrollment is a noncritical post-commit hook; required signup persistence is complete. -->
            <cfset enrollNewMemberForRecovery(userId = newUserId)>

            <cfset sessionRotate()>
            <cfset session.user = {
                id = newUserId,
                userId = newUserId,
                USERID = newUserId,
                email = email,
                EMAIL = email,
                firstName = firstName,
                FIRSTNAME = firstName,
                lastName = lastName,
                LASTNAME = lastName,
                mobilePhone = phone,
                MOBILEPHONE = phone,
                lastLogin = nowStamp,
                LASTLOGIN = nowStamp
            }>


            <cfset createObject("component",componentPath("includes.AuthContinuationService")).bindMember(newUserId)>
            <cfset createObject("component",componentPath("includes.AuthContinuationService")).markAccountCreated(newUserId,email)>

            <cfif premiumSendCreditModelEnabled>
                <cftry>
                    <cfset createObject("component", componentPath("includes.ProductEventService")).init("fpw").recordEvent(
                        userId = newUserId,
                        eventName = "complimentary_credit_granted",
                        entityType = "user",
                        entityId = newUserId,
                        eventSource = "member_signup",
                        metadata = { credit_source = "complimentary_signup" },
                        idempotencyKey = "complimentary_credit_granted:user:" & newUserId,
                        requestCorrelationId = structKeyExists(request, "fpwRequestId") ? toString(request.fpwRequestId) : ""
                    )>
                    <cfcatch type="any">
                        <cflog file="fpw_product_events" type="error" text="join.cfc PRODUCT_EVENT_CALL_FAILED | event=complimentary_credit_granted">
                    </cfcatch>
                </cftry>
            </cfif>

            <cftry>
                <cfset createObject("component", componentPath("api.v1.email")).init().sendWelcomeMemberEmail(
                    userId = newUserId,
                    toEmail = email,
                    firstName = firstName
                )>
                <cfcatch type="any">
                    <cflog
                        file="fpw_email"
                        type="error"
                        text="join.cfc WELCOME_MEMBER_HOOK_FAILED | userId=#newUserId# | time=#now()#">
                </cfcatch>
            </cftry>

            <cfset var response = {
                SUCCESS = true,
                success = true,
                AUTH = true,
                ACCOUNT_CREATED = true,
                auth = true,
                MESSAGE = "User created successfully.",
                USERID  = newUserId,
                EMAIL   = email,
                USER = session.user,
                user = session.user,
                REDIRECT_URL = redirectUrl,
                redirectUrl = redirectUrl
            }>

            <cfreturn response>


        <cfcatch type="database">
            <cfif (structKeyExists(cfcatch,"NativeErrorCode") AND val(cfcatch.NativeErrorCode) EQ 1062)>
                <cfreturn {SUCCESS=false,AUTH=false,ERROR="EMAIL_EXISTS",MESSAGE="That email is already registered."}>
            </cfif>
            <cflog file="fpw_auth" type="error" text="SIGNUP_TRANSACTION_FAILED">
            <cfreturn {SUCCESS=false,AUTH=false,ERROR="SERVER_ERROR",MESSAGE="Account access is temporarily unavailable."}>
        </cfcatch>
        <cfcatch type="any">
            <cflog file="fpw_auth" type="error" text="SIGNUP_FAILED">
            <cfreturn {SUCCESS=false,AUTH=false,ERROR="SERVER_ERROR",MESSAGE="Account access is temporarily unavailable."}>
        </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="enrollNewMemberForRecovery" access="private" returntype="struct" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="enrollmentService" type="any" required="false" default="">
        <cfscript>
            var outcome = { SUCCESS = false, CODE = "ENROLLMENT_FAILED" };
            try {
                var service = isObject(arguments.enrollmentService) ? arguments.enrollmentService
                    : createObject("component",componentPath("includes.InactiveMemberRecoveryEnrollmentService")).init(datasource="fpw");
                // The identity is the inserted server-side id; no request dates, coverage, or metadata.
                var result = service.ensureEnrolled(userId = arguments.userId);
                if (isStruct(result) AND structKeyExists(result, "SUCCESS") AND isBoolean(result.SUCCESS)
                    AND result.SUCCESS AND structKeyExists(result, "CODE") AND isSimpleValue(result.CODE)
                    AND listFind("ENROLLED,ALREADY_ENROLLED,NOT_ELIGIBLE_FOR_ENROLLMENT,MEMBER_NOT_FOUND", toString(result.CODE))) {
                    outcome = { SUCCESS = true, CODE = toString(result.CODE) };
                }
            } catch (any enrollmentHookFailure) {
                // Enrollment failures cannot roll back or report failure for a committed signup.
            }
            try {
                writeRecoveryEnrollmentAudit(userId = arguments.userId, code = outcome.CODE);
            } catch (any auditFailure) {
                // Logging is also noncritical and never changes the signup response.
            }
            return outcome;
        </cfscript>
    </cffunction>

    <cffunction name="writeRecoveryEnrollmentAudit" access="private" returntype="void" output="false">
        <cfargument name="userId" type="numeric" required="true">
        <cfargument name="code" type="string" required="true">
        <cfscript>
            var logPath=getDirectoryFromPath(getCurrentTemplatePath()) & "../../logs/fpw_recovery_enrollment.log";
            var atUtc=dateTimeFormat(dateConvert("local2utc",now()),"yyyy-mm-dd'T'HH:nn:ss'Z'");
            fileAppend(logPath,atUtc & " join.cfc RECOVERY_ENROLLMENT | userId=" & arguments.userId
                & " | code=" & arguments.code & chr(10),"utf-8");
        </cfscript>
    </cffunction>

    <cffunction name="normalizeSignupAttribution" access="private" returntype="struct" output="false">
        <cfargument name="body" type="struct" required="true">

        <cfset var landingKey = "">
        <cfset var sourceContentType = "">
        <cfset var ctaType = "">

        <cfif
            NOT structKeyExists(arguments.body, "landing_key")
            OR NOT structKeyExists(arguments.body, "source_content_type")
            OR NOT structKeyExists(arguments.body, "cta_type")
            OR NOT isSimpleValue(arguments.body.landing_key)
            OR NOT isSimpleValue(arguments.body.source_content_type)
            OR NOT isSimpleValue(arguments.body.cta_type)
        >
            <cfreturn {}>
        </cfif>

        <cfset landingKey = lCase(trim(toString(arguments.body.landing_key)))>
        <cfset sourceContentType = lCase(trim(toString(arguments.body.source_content_type)))>
        <cfset ctaType = lCase(trim(toString(arguments.body.cta_type)))>

        <cfif landingKey EQ "great_loop_trip_planning" AND sourceContentType EQ "seo_guide" AND ctaType EQ "plan_trip">
            <cfreturn {landing_key=landingKey,source_content_type=sourceContentType,cta_type=ctaType}>
        </cfif>
        <cfif ctaType NEQ "plan_route">
            <cfreturn {}>
        </cfif>
        <cfif
            NOT (
                (landingKey EQ "boat_fuel_calculator" AND sourceContentType EQ "seo_tool")
                OR (landingKey EQ "great_loop_locks" AND sourceContentType EQ "seo_hub")
            )
        >
            <cfreturn {}>
        </cfif>

        <cfreturn {
            landing_key = landingKey,
            source_content_type = sourceContentType,
            cta_type = ctaType
        }>
    </cffunction>

    <cffunction name="buildInsert" access="private" returntype="struct" output="false">
        <cfargument name="tableName" type="string" required="true">
        <cfargument name="valueMap" type="struct" required="true">

        <cfset var colsQ = queryExecute(
            "SELECT COLUMN_NAME, IS_NULLABLE, COLUMN_DEFAULT, EXTRA, DATA_TYPE, COLUMN_TYPE " &
            "FROM information_schema.columns " &
            "WHERE table_schema = DATABASE() AND table_name = :tableName " &
            "ORDER BY ORDINAL_POSITION",
            { tableName = { value = arguments.tableName, cfsqltype = "cf_sql_varchar" } },
            { datasource = "fpw" }
        )>

        <cfset var insertCols = []>
        <cfset var insertVals = []>
        <cfset var params = {}>
        <cfset var usedParams = {}>

        <cfloop query="colsQ">
            <cfset var colName = colsQ.COLUMN_NAME>
            <cfset var colLower = lcase(colName)>
            <cfset var isAuto = findNoCase("auto_increment", colsQ.EXTRA)>
            <cfset var isRequired = (colsQ.IS_NULLABLE EQ "NO" AND isNull(colsQ.COLUMN_DEFAULT))>

            <cfif isAuto>
                <cfcontinue>
            </cfif>

            <cfset var hasValue = structKeyExists(arguments.valueMap, colLower)>
            <cfset var value = "">
            <cfset var includeCol = false>

            <cfif hasValue>
                <cfset value = arguments.valueMap[colLower]>
                <cfif isNull(value)>
                    <cfif isRequired>
                        <cfset value = buildColumnValue(colsQ, colName)>
                        <cfset includeCol = true>
                    <cfelse>
                        <cfset includeCol = false>
                    </cfif>
                <cfelseif isSimpleValue(value) AND len(trim(toString(value))) EQ 0>
                    <cfif isRequired>
                        <cfset value = buildColumnValue(colsQ, colName)>
                        <cfset includeCol = true>
                    <cfelse>
                        <cfset includeCol = false>
                    </cfif>
                <cfelse>
                    <cfset includeCol = true>
                </cfif>
            <cfelseif isRequired>
                <cfset value = buildColumnValue(colsQ, colName)>
                <cfset includeCol = true>
            </cfif>

            <cfif NOT includeCol>
                <cfcontinue>
            </cfif>

            <cfset var paramName = "p_" & reReplace(colLower, "[^A-Za-z0-9_]", "_", "all")>
            <cfif structKeyExists(usedParams, paramName)>
                <cfset paramName = paramName & "_" & arrayLen(insertCols)>
            </cfif>
            <cfset usedParams[paramName] = true>

            <cfset arrayAppend(insertCols, colName)>
            <cfset arrayAppend(insertVals, ":" & paramName)>

            <cfset params[paramName] = {
                value = value,
                cfsqltype = sqlTypeFor(colsQ.DATA_TYPE),
                null = (isNull(value) OR (isSimpleValue(value) AND len(trim(toString(value))) EQ 0))
            }>
        </cfloop>

        <cfif NOT arrayLen(insertCols)>
            <cfreturn { ok = false, message = "No insertable columns for #arguments.tableName#" }>
        </cfif>

        <cfset var sql = "INSERT INTO #arguments.tableName# (" & arrayToList(insertCols, ",") & ") VALUES (" & arrayToList(insertVals, ",") & ")">
        <cfreturn { ok = true, sql = sql, params = params }>
    </cffunction>

    <cffunction name="buildColumnValue" access="private" returntype="any" output="false">
        <cfargument name="column" type="struct" required="true">
        <cfargument name="colName" type="string" required="true">

        <cfset var dataType = lcase(arguments.column.DATA_TYPE ?: "")>
        <cfset var colLower = lcase(arguments.colName)>

        <cfif findNoCase("email", colLower)>
            <cfreturn "test-" & createUUID() & "@example.com">
        </cfif>
        <cfif dataType EQ "enum">
            <cfreturn firstEnumValue(arguments.column.COLUMN_TYPE)>
        </cfif>
        <cfif listFindNoCase("date,datetime,timestamp", dataType)>
            <cfreturn now()>
        </cfif>
        <cfif dataType EQ "time">
            <cfreturn "00:00:00">
        </cfif>
        <cfif listFindNoCase("int,integer,smallint,mediumint,tinyint,bigint,decimal,numeric,float,double,bit,boolean", dataType)>
            <cfreturn 0>
        </cfif>

        <cfreturn "test-" & createUUID()>
    </cffunction>

    <cffunction name="firstEnumValue" access="private" returntype="string" output="false">
        <cfargument name="columnType" type="string" required="true">
        <cfset var matches = reMatch("enum\\('([^']+)'", arguments.columnType)>
        <cfif arrayLen(matches)>
            <cfreturn replace(matches[1], "enum('", "", "one")>
        </cfif>
        <cfreturn "">
    </cffunction>

    <cffunction name="sqlTypeFor" access="private" returntype="string" output="false">
        <cfargument name="dataType" type="string" required="true">
        <cfset var dt = lcase(arguments.dataType)>
        <cfif listFindNoCase("int,integer,smallint,mediumint,tinyint", dt)>
            <cfreturn "cf_sql_integer">
        </cfif>
        <cfif dt EQ "bigint">
            <cfreturn "cf_sql_bigint">
        </cfif>
        <cfif listFindNoCase("decimal,numeric", dt)>
            <cfreturn "cf_sql_decimal">
        </cfif>
        <cfif listFindNoCase("float,double", dt)>
            <cfreturn "cf_sql_double">
        </cfif>
        <cfif listFindNoCase("bit,boolean", dt)>
            <cfreturn "cf_sql_bit">
        </cfif>
        <cfif dt EQ "date">
            <cfreturn "cf_sql_date">
        </cfif>
        <cfif listFindNoCase("datetime,timestamp", dt)>
            <cfreturn "cf_sql_timestamp">
        </cfif>
        <cfreturn "cf_sql_varchar">
    </cffunction>

    <cffunction name="isTruthy" access="private" returntype="boolean" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfif isBoolean(arguments.value)>
            <cfreturn arguments.value>
        </cfif>
        <cfset var normalized = lcase(trim(toString(arguments.value)))>
        <cfreturn listFindNoCase("true,1,yes,on", normalized) GT 0>
    </cffunction>

    <cffunction name="normalizeOptionalUsPhone" access="private" returntype="struct" output="false">
        <cfargument name="phone" type="string" required="true">

        <cfset var rawValue = trim(toString(arguments.phone))>
        <cfset var digits = reReplace(rawValue, "[^0-9]", "", "all")>

        <cfif NOT len(rawValue)>
            <cfreturn { valid = true, value = "" }>
        </cfif>
        <cfif len(digits) EQ 11 AND left(digits, 1) EQ "1">
            <cfset digits = right(digits, 10)>
        </cfif>
        <cfif len(digits) NEQ 10 OR NOT reFind("^[2-9][0-9]{2}[2-9][0-9]{6}$", digits)>
            <cfreturn { valid = false, value = "" }>
        </cfif>

        <cfreturn { valid = true, value = formatUsPhoneDigits(digits) }>
    </cffunction>

    <cffunction name="formatUsPhoneDigits" access="private" returntype="string" output="false">
        <cfargument name="digits" type="string" required="true">

        <cfreturn "(" & left(arguments.digits, 3) & ") " & mid(arguments.digits, 4, 3) & "-" & right(arguments.digits, 4)>
    </cffunction>

    <cffunction name="resolveFpwBasePath" access="private" returntype="string" output="false">
        <cfset var basePath = "">

        <cfif structKeyExists(request, "fpwBase") AND NOT isNull(request.fpwBase)>
            <cfset basePath = trim(toString(request.fpwBase))>
        <cfelse>
            <cfif structKeyExists(cgi, "script_name")>
                <cfset basePath = trim(toString(cgi.script_name))>
            <cfelseif structKeyExists(cgi, "SCRIPT_NAME")>
                <cfset basePath = trim(toString(cgi.SCRIPT_NAME))>
            </cfif>

            <cfset basePath = reReplace(basePath, "[?##].*$", "")>
            <cfset basePath = replace(basePath, "\", "/", "all")>
            <cfset basePath = reReplaceNoCase(basePath, "/api/v1(/.*)?$", "")>
            <cfset basePath = reReplaceNoCase(basePath, "/(app|admin|assets|tests)(/.*)?$", "")>
            <cfset basePath = reReplaceNoCase(basePath, "/[^/]*\.(cfm|cfc)$", "")>
        </cfif>

        <cfset basePath = reReplace(basePath, "/$", "")>
        <cfif basePath EQ "/">
            <cfset basePath = "">
        </cfif>
        <cfif len(basePath) AND left(basePath, 1) NEQ "/">
            <cfset basePath = "/" & basePath>
        </cfif>

        <cfset request.fpwBase = basePath>
        <cfset request.fpwApiBase = basePath & "/api/v1">

        <cfreturn basePath>
    </cffunction>

<cfscript>
  private string function componentPath(required string relativePath) {
    var prefix=reReplaceNoCase(getMetadata(this).name,"(^|[.])api[.]v1[.][^.]+$","");
    return (len(prefix) ? prefix & "." : "") & arguments.relativePath;
  }
</cfscript>
</cfcomponent>
