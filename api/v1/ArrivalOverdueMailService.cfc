<cfcomponent output="false" hint="Internal recipient selection, initial arrival notice rendering and single-address transport.">
    <cffunction name="init" access="public" returntype="any" output="false">
        <cfargument name="ds" type="string" required="false" default="fpw">
        <cfargument name="recipientSecret" type="string" required="false" default="">
        <cfscript>
            variables.datasource = arguments.ds;
            if (len(arguments.recipientSecret)) {
                if (!listFindNoCase("dev,development,local,test", application.env ?: ""))
                    throw(type="FPW.ArrivalMailConfiguration",message="Fixture keys require a local test environment.");
                variables.secret = arguments.recipientSecret;
            } else {
                variables.secret = environmentValue("FPW_ARRIVAL_RECIPIENT_KEY");
            }
            return this;
        </cfscript>
    </cffunction>

    <cffunction name="environmentValue" access="private" returntype="string" output="false">
        <cfargument name="name" type="string" required="true">
        <cfscript>
            try {
                var value = createObject("java","java.lang.System").getenv(arguments.name);
                return isNull(value) ? "" : toString(value);
            } catch (any unavailable) {
                return "";
            }
        </cfscript>
    </cffunction>

    <cffunction name="singleAddress" access="private" returntype="boolean" output="false">
        <cfargument name="address" type="string" required="true">
        <cfreturn len(arguments.address) GT 0 AND len(arguments.address) LTE 254
            AND NOT reFind("[[:cntrl:],;<>]",arguments.address) AND isValid("email",arguments.address)>
    </cffunction>

    <!--- Addresses live only in this call's memory. Only the plan-bound HMAC is stored by the outbox. --->
    <cffunction name="selectedRecipients" access="public" returntype="struct" output="false">
        <cfargument name="planId" type="numeric" required="true">
        <cfscript>
            if (len(variables.secret) LT 32)
                throw(type="FPW.ArrivalMailConfiguration",message="A stable arrival recipient key is required.");
            var bundle = {valid=[],invalidCount=0,missingCount=0};
            var selected = queryExecute("
                SELECT c.email AS address
                FROM floatplans p
                JOIN floatplan_contacts fc ON fc.floatPlanId=p.floatPlanId
                LEFT JOIN contacts c ON c.contactId=fc.contactId AND c.userId=p.userId
                WHERE p.floatPlanId=:p
                UNION ALL
                SELECT bd.notification_contact_email AS address
                FROM floatplans p
                JOIN floatplan_basic_details bd ON bd.floatplan_id=p.floatPlanId
                WHERE p.floatPlanId=:p AND COALESCE(p.route_instance_id,0)=0",
                {p={value=arguments.planId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
            if (!selected.recordCount) bundle.missingCount=1;
            var seen={};
            for (var row in selected) {
                var address=lCase(trim(row.address ?: ""));
                if (!len(address)) {
                    bundle.missingCount++;
                } else if (!singleAddress(address)) {
                    bundle.invalidCount++;
                } else {
                    var key=lCase(hmac("arrival:v1:" & int(arguments.planId) & ":" & address,
                        variables.secret,"HmacSHA256","utf-8"));
                    if (!structKeyExists(seen,key)) {
                        seen[key]=true;
                        arrayAppend(bundle.valid,{recipientKey=key,address=address});
                    }
                }
            }
            return bundle;
        </cfscript>
    </cffunction>

    <cffunction name="resolveRecipient" access="public" returntype="string" output="false">
        <cfargument name="planId" type="numeric" required="true">
        <cfargument name="recipientKey" type="string" required="true">
        <cfscript>
            if (!reFind("^[a-f0-9]{64}$",arguments.recipientKey)) return "";
            var selected=selectedRecipients(arguments.planId);
            for (var recipient in selected.valid) {
                if (compare(recipient.recipientKey,arguments.recipientKey)==0) return recipient.address;
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="utcText" access="private" returntype="string" output="false">
        <cfargument name="value" type="string" required="true">
        <cfscript>
            var raw=trim(arguments.value);
            if (!reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]{1,6})?Z?$",raw))
                throw(type="FPW.ArrivalMailContent",message="Arrival notice requires valid UTC timestamps.");
            return replace(left(raw,19),"T"," ");
        </cfscript>
    </cffunction>

    <cffunction name="safeLabel" access="private" returntype="string" output="false">
        <cfargument name="value" type="string" required="true">
        <cfscript>
            var label=left(trim(reReplace(arguments.value,"[[:cntrl:]]+"," ","all")),120);
            if (reFindNoCase("(://|www[.]|@|[[:alnum:]-]+[.][[:alpha:]]{2,})",label)) return "";
            return label;
        </cfscript>
    </cffunction>

    <!--- Follow's public read path accepts an existing slug without a bearer token.
          Contact selection alone does not grant a password, invite, or owner share token. --->
    <cffunction name="existingPublicFollowUrl" access="private" returntype="string" output="false">
        <cfargument name="planId" type="numeric" required="true">
        <cfscript>
            try {
                // Choose the current stream first; an older public stream cannot override a later private one.
                var stream=queryExecute("
                    SELECT vs.slug,vs.privacy_mode,p.userId FROM floatplans p
                    JOIN voyage_streams vs ON vs.floatplan_id=p.floatPlanId AND vs.owner_user_id=p.userId
                    WHERE p.floatPlanId=:p AND p.route_instance_id>0 AND UPPER(TRIM(p.status))='ACTIVE'
                    AND p.closedAt IS NULL AND p.expiredAt IS NULL ORDER BY vs.id DESC LIMIT 1",
                    {p={value=arguments.planId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
                if (stream.recordCount!=1 || compareNoCase(trim(stream.privacy_mode[1] ?: ""),"public")!=0) return "";
                var slug=trim(stream.slug[1] ?: "");
                if (len(slug)>120 || !reFind("^[a-z0-9]+(-[a-z0-9]+)*$",slug)) return "";
                var grant=createObject("component","fpw.api.v1.PremiumTripAccessService").init(variables.datasource)
                    .getTripOperationalAccess(val(stream.userId[1]),arguments.planId,false);
                if (!grant.allowed) return "";
                var origin=createObject("component","fpw.api.v1.email").getPublicBaseUrl();
                return origin & "/app/follow.cfm?slug=" & urlEncodedFormat(slug);
            } catch (any optionalLinkUnavailable) {
                return "";
            }
        </cfscript>
    </cffunction>

    <cffunction name="buildNotice" access="public" returntype="struct" output="false">
        <cfargument name="planId" type="numeric" required="true">
        <cfargument name="deadlineUtc" type="string" required="true">
        <cfargument name="deadlineZone" type="string" required="true">
        <cfargument name="generatedUtc" type="string" required="true">
        <cfscript>
            var trip=queryExecute("
                SELECT p.floatPlanName,CASE WHEN COALESCE(p.route_instance_id,0)=0 THEN bd.vessel_name
                    ELSE v.vesselName END AS vessel_label
                FROM floatplans p LEFT JOIN floatplan_basic_details bd ON bd.floatplan_id=p.floatPlanId
                LEFT JOIN vessels v ON v.vesselId=p.vesselId AND v.userId=p.userId
                WHERE p.floatPlanId=:p LIMIT 1",
                {p={value=arguments.planId,cfsqltype="cf_sql_integer"}},{datasource=variables.datasource});
            if (trip.recordCount!=1) throw(type="FPW.ArrivalMailContent",message="Arrival notice plan unavailable.");
            var deadline=utcText(arguments.deadlineUtc);
            var generated=utcText(arguments.generatedUtc);
            var zone=trim(arguments.deadlineZone);
            if (!len(zone) || reFind("[^A-Za-z0-9_+/:-]",zone))
                throw(type="FPW.ArrivalMailContent",message="Arrival notice time zone unavailable.");
            var instant=parseDateTime(replace(deadline," ","T") & "Z");
            var localDeadline=dateTimeFormat(instant,"mmm d, yyyy h:nn tt",zone);
            var tripName=safeLabel(trip.floatPlanName[1] ?: "");
            if (!len(tripName)) tripName="Float Plan " & int(arguments.planId);
            var vessel=safeLabel(trip.vessel_label[1] ?: "");
            var bodyLines=[
                "Notice Source: FPW automated final-arrival monitoring",
                "Status: Expected final arrival time has passed. Final arrival has not been confirmed.",
                "Float Plan: " & tripName
            ];
            if (len(vessel)) arrayAppend(bodyLines,"Vessel: " & vessel);
            arrayAppend(bodyLines,"Scheduled final arrival: " & localDeadline & " (" & zone & "), " & deadline & " UTC");
            arrayAppend(bodyLines,"Notice generated: " & generated & " UTC");
            arrayAppend(bodyLines,"");
            arrayAppend(bodyLines,"Attempt to contact the captain and follow the response plan you agreed upon.");
            arrayAppend(bodyLines,"FPW has not independently verified an emergency and does not dispatch assistance.");
            arrayAppend(bodyLines,"Electronic-message delivery and receipt are not guaranteed.");
            var followUrl=existingPublicFollowUrl(arguments.planId);
            if (len(followUrl)) arrayAppend(bodyLines,"Public trip page: " & followUrl);
            return {subject="FloatPlanWizard Alert: Expected Arrival Time Has Passed",body=arrayToList(bodyLines,chr(10))};
        </cfscript>
    </cffunction>

    <cffunction name="submit" access="public" returntype="struct" output="false">
        <cfargument name="address" type="string" required="true">
        <cfargument name="message" type="struct" required="true">
        <cfset var destination=lCase(trim(arguments.address))>
        <cfif NOT listFindNoCase("prod,production",application.env ?: "")
            OR compareNoCase(trim(environmentValue("FPW_ARRIVAL_EMAIL_ENABLED")),"true") NEQ 0>
            <cfreturn {status="FAILED_PERMANENT",reason="LIVE_TRANSPORT_DISABLED"}>
        </cfif>
        <cfif NOT singleAddress(destination)>
            <cfreturn {status="FAILED_PERMANENT",reason="INVALID_RECIPIENT"}>
        </cfif>
        <cfif (arguments.message.subject ?: "") NEQ "FloatPlanWizard Alert: Expected Arrival Time Has Passed"
            OR NOT len(trim(arguments.message.body ?: ""))>
            <cfreturn {status="FAILED_PERMANENT",reason="INVALID_MESSAGE"}>
        </cfif>
        <!--- Dispatcher owns the plan fence. Network I/O is outside its DB transactions. --->
        <cftry>
            <cfmail to="#destination#" from="noreply@floatplanwizard.com"
                subject="FloatPlanWizard Alert: Expected Arrival Time Has Passed"
                type="text" charset="utf-8" spoolenable="false" timeout="10">#arguments.message.body#</cfmail>
            <cfreturn {status="SUBMITTED",reason="TRANSPORT_ACCEPTED"}>
            <cfcatch type="any">
                <cfreturn classifyTransportException(cfcatch)>
            </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="classifyTransportException" access="private" returntype="struct" output="false">
        <cfargument name="failure" required="true">
        <cfscript>
            // Do not inspect or persist free-form SMTP text, which can contain addresses.
            try {
                var pending=[arguments.failure];
                // Adobe may wrap native errors in CF catch structs. JavaMail also
                // has a nested-exception chain separate from Throwable.getCause().
                for (var i=1;i<=arrayLen(pending) && i<=20;i++) {
                    var cause=pending[i];
                    if (!isObject(cause)) {
                        if (isStruct(cause)) {
                            if (structKeyExists(cause,"rootCause") && !isNull(cause.rootCause)) arrayAppend(pending,cause.rootCause);
                            if (structKeyExists(cause,"cause") && !isNull(cause.cause)) arrayAppend(pending,cause.cause);
                        }
                        continue;
                    }
                    var kind=cause.getClass().getName();
                    if (kind=="java.net.SocketTimeoutException" || kind=="java.io.EOFException")
                        return {status="UNKNOWN",reason="HANDOFF_UNCONFIRMED"};
                    if (listFind("java.net.ConnectException,java.net.UnknownHostException,java.net.NoRouteToHostException",kind))
                        return {status="FAILED_RETRYABLE",reason="TRANSPORT_UNAVAILABLE"};
                    if (reFind("(SMTPAddressFailedException|SMTPSendFailedException)$",kind)) {
                        var command=left(uCase(trim(cause.getCommand())),4);
                        var reply=cause.getReturnCode();
                        if (command=="RCPT" || command=="MAIL") {
                            if (reply>=400 && reply<500) return {status="FAILED_RETRYABLE",reason="TRANSPORT_UNAVAILABLE"};
                            if (reply>=500 && reply<600) return {status="FAILED_PERMANENT",reason=(command=="RCPT" ? "ADDRESS_REJECTED" : "TRANSPORT_REJECTED")};
                        }
                    }
                    var chained=cause.getCause();
                    if (!isNull(chained)) arrayAppend(pending,chained);
                    if (findNoCase("mail",kind)) {
                        try {
                            var nested=cause.getNextException();
                            if (!isNull(nested)) arrayAppend(pending,nested);
                        } catch (any noMailChain) {}
                    }
                }
            } catch (any nonInspectable) {}
            return {status="UNKNOWN",reason="HANDOFF_UNCONFIRMED"};
        </cfscript>
    </cffunction>
</cfcomponent>
