<cfcomponent output="false">

    <cffunction name="init" access="public" returntype="any" output="false">
        <cfreturn this>
    </cffunction>

    <cffunction name="sendOverdueEmail" access="public" returntype="void" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="escalationLevel" type="string" required="true">
        <cfscript>
            if (arguments.floatPlanId LTE 0) {
                return;
            }

            var plan = loadPlanDetails(arguments.floatPlanId);
            if (structIsEmpty(plan) OR NOT listFindNoCase("ACTIVE,OVERDUE", plan.STATUS)) {
                logNotice("Overdue email skipped (invalid plan/status). PlanId=" & arguments.floatPlanId & " Status=" & (structKeyExists(plan, "STATUS") ? plan.STATUS : "missing"));
                return;
            }

            var contactEmails = loadContactEmails(arguments.floatPlanId);
            if (!arrayLen(contactEmails)) {
                logNotice("Overdue email skipped (no contacts). PlanId=" & arguments.floatPlanId);
                return;
            }

            var escalationInfo = buildOverdueEscalation(arguments.escalationLevel);
            var subject = escalationInfo.subject & " - " & plan.VESSEL_NAME;
            var body = buildOverdueBody(plan, escalationInfo);
            var metaInfo = serializeJSON({
                escalationLevel = arguments.escalationLevel,
                stage = escalationInfo.stage,
                hourMark = escalationInfo.hourMark
            });

            sendEmailBatch(arguments.floatPlanId, contactEmails, subject, body, escalationInfo.stage, escalationInfo.hourMark, metaInfo);
            logNotice("Overdue email processed. PlanId=" & arguments.floatPlanId & " Level=" & arguments.escalationLevel & " Recipients=" & arrayLen(contactEmails));
        </cfscript>
    </cffunction>

    <cffunction name="sendCheckInEmail" access="public" returntype="void" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            if (arguments.floatPlanId LTE 0) {
                return;
            }

            var plan = loadPlanDetails(arguments.floatPlanId);
            if (structIsEmpty(plan)) {
                logNotice("Check-in email skipped (plan not found). PlanId=" & arguments.floatPlanId);
                return;
            }

            var emails = [];
            var contactEmails = loadContactEmails(arguments.floatPlanId);
            var i = 0;

            for (i = 1; i LTE arrayLen(contactEmails); i++) {
                arrayAppend(emails, contactEmails[i]);
            }

            if (len(plan.OPERATOR_EMAIL)) {
                arrayAppend(emails, plan.OPERATOR_EMAIL);
            }

            emails = uniqueEmails(emails);
            if (!arrayLen(emails)) {
                logNotice("Check-in email skipped (no recipients). PlanId=" & arguments.floatPlanId);
                return;
            }

            var subject = "Float Plan Checked In - " & plan.VESSEL_NAME;
            var body = buildCheckInBody(plan);
            var metaInfo = serializeJSON({ stage = "checkin" });

            sendEmailBatch(arguments.floatPlanId, emails, subject, body, "checkin", 0, metaInfo);
            logNotice("Check-in email processed. PlanId=" & arguments.floatPlanId & " Recipients=" & arrayLen(emails));
        </cfscript>
    </cffunction>

    <cffunction name="loadPlanDetails" access="private" returntype="struct" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var details = {};
            var qPlan = queryExecute("
                SELECT
                    fp.floatplanId,
                    fp.userId,
                    fp.floatPlanName,
                    fp.status,
                    fp.returnTime,
                    fp.returnTimezone,
                    fp.floatPlanEmail,
                    fp.vesselId,
                    fp.operatorId,
                    v.vesselName,
                    o.name AS operatorName,
                    u.fName,
                    u.lName,
                    u.email AS userEmail
                FROM floatplans fp
                LEFT JOIN vessels v ON fp.vesselId = v.vesselId
                LEFT JOIN operators o ON fp.operatorId = o.opId
                LEFT JOIN users u ON fp.userId = u.userId
                WHERE fp.floatplanId = :planId
                LIMIT 1
            ", {
                planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
            }, { datasource = "fpw" });

            if (qPlan.recordCount EQ 0) {
                return details;
            }

            var vesselName = "";
            if (structKeyExists(qPlan, "vesselName")) {
                vesselName = trim(toString(qPlan.vesselName[1]));
            }
            if (!len(vesselName)) {
                vesselName = "Vessel";
            }

            var operatorName = "";
            if (structKeyExists(qPlan, "operatorName")) {
                operatorName = trim(toString(qPlan.operatorName[1]));
            }
            if (!len(operatorName)) {
                operatorName = trim(toString((structKeyExists(qPlan, "fName") ? qPlan.fName[1] : ""))) & " " & trim(toString((structKeyExists(qPlan, "lName") ? qPlan.lName[1] : "")));
                operatorName = trim(operatorName);
            }
            if (!len(operatorName)) {
                operatorName = "Operator";
            }

            var operatorEmail = "";
            if (structKeyExists(qPlan, "floatPlanEmail")) {
                operatorEmail = trim(toString(qPlan.floatPlanEmail[1]));
            }
            if (!len(operatorEmail) AND structKeyExists(qPlan, "userEmail")) {
                operatorEmail = trim(toString(qPlan.userEmail[1]));
            }

            details = {
                FLOATPLANID = qPlan.floatplanId[1],
                USERID = qPlan.userId[1],
                PLAN_NAME = trim(toString(qPlan.floatPlanName[1])),
                STATUS = ucase(trim(toString(qPlan.status[1]))),
                RETURN_TIME = qPlan.returnTime[1],
                RETURN_TIMEZONE = trim(toString(qPlan.returnTimezone[1] ?: "")),
                VESSEL_NAME = vesselName,
                OPERATOR_NAME = operatorName,
                OPERATOR_EMAIL = operatorEmail
            };

            return details;
        </cfscript>
    </cffunction>

    <cffunction name="loadContactEmails" access="private" returntype="array" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfscript>
            var emails = [];
            var qContacts = queryExecute("
                SELECT c.email
                FROM floatplan_contacts fc
                INNER JOIN contacts c ON c.contactId = fc.contactId
                WHERE fc.floatplanId = :planId
            ", {
                planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" }
            }, { datasource = "fpw" });

            for (var i = 1; i LTE qContacts.recordCount; i++) {
                var email = trim(toString(qContacts.email[i]));
                if (len(email)) {
                    arrayAppend(emails, email);
                }
            }

            return uniqueEmails(emails);
        </cfscript>
    </cffunction>

    <cffunction name="buildOverdueEscalation" access="private" returntype="struct" output="false">
        <cfargument name="level" type="string" required="true">
        <cfscript>
            var levelKey = lcase(trim(arguments.level));
            var info = {
                subject = "Float Plan Due",
                headline = "The float plan is now due.",
                status = "Due now",
                emergencyText = "This is not an emergency.",
                guidance = "Monitoring is ongoing.",
                stage = "due",
                hourMark = 0
            };

            if (levelKey EQ "overdue-30" OR levelKey EQ "30") {
                info.subject = "Float Plan Overdue - 30 Minutes";
                info.headline = "The float plan is overdue by about 30 minutes.";
                info.status = "30 minutes overdue";
                info.emergencyText = "This is not an emergency.";
                info.guidance = "Please try reaching the vessel by phone or text. Monitoring continues.";
                info.stage = "overdue-30";
                info.hourMark = 30;
            } else if (levelKey EQ "overdue-90" OR levelKey EQ "90") {
                info.subject = "Float Plan Overdue - 90 Minutes";
                info.headline = "The float plan is overdue by about 90 minutes.";
                info.status = "90 minutes overdue";
                info.emergencyText = "This is not an emergency.";
                info.guidance = "It is not unusual for boats to be late, but please be prepared for possible escalation.";
                info.stage = "overdue-90";
                info.hourMark = 90;
            } else if (left(levelKey, 7) EQ "hourly") {
                info.subject = "Float Plan Overdue - Hourly Update";
                info.headline = "The float plan remains overdue.";
                info.status = "Hourly overdue update";
                info.emergencyText = "This is not necessarily an emergency.";
                info.guidance = "Continue attempts to reach the vessel. Monitoring continues.";
                info.stage = "hourly";
            } else if (levelKey EQ "final") {
                info.subject = "Float Plan Overdue - 12+ Hours";
                info.headline = "The float plan is now 12+ hours overdue.";
                info.status = "Final escalation";
                info.emergencyText = "This may be an emergency.";
                info.guidance = "If you have not made contact, consider reaching out to the appropriate authorities.";
                info.stage = "final";
                info.hourMark = 720;
            } else {
                info.subject = "Float Plan Due";
                info.headline = "The float plan is now due.";
                info.status = "Due now";
                info.emergencyText = "This is not an emergency.";
                info.guidance = "Monitoring is ongoing.";
                info.stage = "due";
                info.hourMark = 0;
            }

            if (left(levelKey, 7) EQ "hourly-") {
                var hoursLabel = replace(levelKey, "hourly-", "", "all");
                info.status = hoursLabel & " hours overdue";
                info.hourMark = val(hoursLabel) * 60;
            }

            return info;
        </cfscript>
    </cffunction>

    <cffunction name="buildOverdueBody" access="private" returntype="string" output="false">
        <cfargument name="plan" type="struct" required="true">
        <cfargument name="info" type="struct" required="true">
        <cfscript>
            var returnLabel = formatReturnTime(plan.RETURN_TIME, plan.RETURN_TIMEZONE);
            var html = "";
            html &= "<p>Hello,</p>";
            html &= "<p><strong>" & encodeForHtml(plan.OPERATOR_NAME) & "</strong> is overdue on float plan for <strong>" & encodeForHtml(plan.VESSEL_NAME) & "</strong>.</p>";
            html &= "<p><strong>Status:</strong> " & encodeForHtml(arguments.info.status) & "</p>";
            html &= "<p><strong>Planned return time:</strong> " & encodeForHtml(returnLabel) & "</p>";
            html &= "<p><strong>" & encodeForHtml(arguments.info.emergencyText) & "</strong></p>";
            html &= "<p>" & encodeForHtml(arguments.info.guidance) & "</p>";
            html &= "<p>This notice is being sent because you are listed as a float plan contact. Monitoring continues until the operator checks in.</p>";
            html &= "<p>FloatPlanWizard</p>";
            return html;
        </cfscript>
    </cffunction>

    <cffunction name="buildCheckInBody" access="private" returntype="string" output="false">
        <cfargument name="plan" type="struct" required="true">
        <cfscript>
            var html = "";
            html &= "<p>Hello,</p>";
            html &= "<p><strong>" & encodeForHtml(plan.OPERATOR_NAME) & "</strong> has safely checked in for <strong>" & encodeForHtml(plan.VESSEL_NAME) & "</strong>.</p>";
            html &= "<p>Monitoring has stopped and no further action is required.</p>";
            html &= "<p>This notice is being sent because you are listed as a float plan contact.</p>";
            html &= "<p>FloatPlanWizard</p>";
            return html;
        </cfscript>
    </cffunction>

    <cffunction name="formatReturnTime" access="private" returntype="string" output="false">
        <cfargument name="returnTime" type="any" required="false">
        <cfargument name="returnTimezone" type="string" required="false">
        <cfscript>
            if (!isDate(arguments.returnTime)) {
                return "Not provided";
            }
            var formatted = dateFormat(arguments.returnTime, "mmm d, yyyy") & " " & timeFormat(arguments.returnTime, "h:nn tt");
            if (len(trim(arguments.returnTimezone))) {
                formatted &= " " & trim(arguments.returnTimezone);
            }
            return formatted;
        </cfscript>
    </cffunction>

    <cffunction name="sendEmailBatch" access="private" returntype="void" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="emails" type="array" required="true">
        <cfargument name="subject" type="string" required="true">
        <cfargument name="body" type="string" required="true">
        <cfargument name="stage" type="string" required="true">
        <cfargument name="hourMark" type="numeric" required="true">
        <cfargument name="meta" type="string" required="false" default="{}">
        <cfloop array="#arguments.emails#" index="emailAddr">
            <cfif NOT len(trim(emailAddr))>
                <cfcontinue>
            </cfif>
            <cfif NOT shouldSendNotification(arguments.floatPlanId, emailAddr, arguments.stage, arguments.hourMark, arguments.subject, arguments.meta)>
                <cfset logNotice("Notification skipped (already logged). PlanId=" & arguments.floatPlanId & " Stage=" & arguments.stage & " Email=" & emailAddr)>
                <cfcontinue>
            </cfif>
            <cftry>
                <cfmail
                    from="noreply@floatplanwizard.com"
                    to="#emailAddr#"
                    subject="#arguments.subject#"
                    type="html">
                    #arguments.body#
                </cfmail>
            <cfcatch>
                <cfset logNotice("Email send failed for " & emailAddr & ": " & cfcatch.message)>
            </cfcatch>
            </cftry>
        </cfloop>
    </cffunction>

    <cffunction name="ensureNotificationsTable" access="private" returntype="void" output="false">
        <cfscript>
            if (structKeyExists(application, "fpwNotificationsTableReady") AND application.fpwNotificationsTableReady) {
                return;
            }
            try {
                queryExecute("
                    CREATE TABLE IF NOT EXISTS floatplan_notifications (
                        notifyId INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
                        floatplanId INT NOT NULL,
                        contactEmail VARCHAR(255) NOT NULL DEFAULT '',
                        stage VARCHAR(64) NOT NULL DEFAULT '',
                        hourMark INT NULL,
                        sentAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                        subject VARCHAR(255) NOT NULL DEFAULT '',
                        meta TEXT NULL
                    )
                ", {}, { datasource = "fpw" });
                application.fpwNotificationsTableReady = true;
                logNotice("Notifications table ready (floatplan_notifications).");
            } catch (any e) {
                logNotice("Failed to ensure notification log table: " & e.message & " | " & e.detail);
            }
        </cfscript>
    </cffunction>

    <cffunction name="shouldSendNotification" access="private" returntype="boolean" output="false">
        <cfargument name="floatPlanId" type="numeric" required="true">
        <cfargument name="contactEmail" type="string" required="true">
        <cfargument name="stage" type="string" required="true">
        <cfargument name="hourMark" type="numeric" required="true">
        <cfargument name="subject" type="string" required="true">
        <cfargument name="meta" type="string" required="false" default="{}">
        <cfscript>
            ensureNotificationsTable();

            var qExisting = {};
            try {
                if (arguments.hourMark GT 0) {
                    qExisting = queryExecute("
                        SELECT notifyId
                        FROM floatplan_notifications
                        WHERE floatplanId = :planId
                          AND contactEmail = :contactEmail
                          AND stage = :stage
                          AND hourMark = :hourMark
                        LIMIT 1
                    ", {
                        planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                        contactEmail = { value = arguments.contactEmail, cfsqltype = "cf_sql_varchar" },
                        stage = { value = arguments.stage, cfsqltype = "cf_sql_varchar" },
                        hourMark = { value = arguments.hourMark, cfsqltype = "cf_sql_integer" }
                    }, { datasource = "fpw" });
                } else {
                    qExisting = queryExecute("
                        SELECT notifyId
                        FROM floatplan_notifications
                        WHERE floatplanId = :planId
                          AND contactEmail = :contactEmail
                          AND stage = :stage
                        LIMIT 1
                    ", {
                        planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                        contactEmail = { value = arguments.contactEmail, cfsqltype = "cf_sql_varchar" },
                        stage = { value = arguments.stage, cfsqltype = "cf_sql_varchar" }
                    }, { datasource = "fpw" });
                }
            } catch (any e) {
                logNotice("Notification log lookup failed: " & e.message & " | " & e.detail & " | SQLState=" & (structKeyExists(e, "sqlstate") ? e.sqlstate : "n/a"));
                return false;
            }

            if (qExisting.recordCount GT 0) {
                return false;
            }

            var hourMarkVal = arguments.hourMark;
            var hourMarkNull = (arguments.hourMark LTE 0);
            if (hourMarkNull) {
                hourMarkVal = "";
            }
            var metaJson = trim(arguments.meta);
            if (!len(metaJson)) {
                metaJson = "{}";
            }

            try {
                queryExecute("
                    INSERT INTO floatplan_notifications (
                        floatplanId,
                        contactEmail,
                        stage,
                        hourMark,
                        sentAt,
                        subject,
                        meta
                    )
                    VALUES (
                        :planId,
                        :contactEmail,
                        :stage,
                        :hourMark,
                        UTC_TIMESTAMP(),
                        :subject,
                        :meta
                    )
                ", {
                    planId = { value = arguments.floatPlanId, cfsqltype = "cf_sql_integer" },
                    contactEmail = { value = arguments.contactEmail, cfsqltype = "cf_sql_varchar" },
                    stage = { value = arguments.stage, cfsqltype = "cf_sql_varchar" },
                    hourMark = { value = hourMarkVal, cfsqltype = "cf_sql_integer", null = hourMarkNull },
                    subject = { value = arguments.subject, cfsqltype = "cf_sql_varchar" },
                    meta = { value = metaJson, cfsqltype = "cf_sql_longvarchar" }
                }, { datasource = "fpw" });
            } catch (any e) {
                logNotice("Notification log insert failed: " & e.message & " | " & e.detail & " | SQLState=" & (structKeyExists(e, "sqlstate") ? e.sqlstate : "n/a"));
                return false;
            }

            logNotice("Notification logged. PlanId=" & arguments.floatPlanId & " Stage=" & arguments.stage & " Email=" & arguments.contactEmail);
            return true;
        </cfscript>
    </cffunction>

    <cffunction name="uniqueEmails" access="private" returntype="array" output="false">
        <cfargument name="emails" type="array" required="true">
        <cfscript>
            var seen = {};
            var output = [];
            for (var i = 1; i LTE arrayLen(arguments.emails); i++) {
                var emailAddr = lcase(trim(arguments.emails[i]));
                if (!len(emailAddr)) {
                    continue;
                }
                if (!structKeyExists(seen, emailAddr)) {
                    seen[emailAddr] = true;
                    arrayAppend(output, emailAddr);
                }
            }
            return output;
        </cfscript>
    </cffunction>

    <cffunction name="logNotice" access="private" returntype="void" output="false">
        <cfargument name="message" type="string" required="true">
        <cflog file="application" text="FloatPlanWizard: #arguments.message#">
    </cffunction>

</cfcomponent>
