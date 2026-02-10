<cffunction name="testCreateFullPlan" access="remote" returntype="void" output="true">
    <cfsetting enablecfoutputonly="true" showdebugoutput="false">
    <cfcontent type="text/html; charset=utf-8">
    <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

    <cfset var token = "" & (structKeyExists(url,"token") ? url.token : "")>
    <cfset var userId = 187>
    <cfset var r = { PASS=true, MSG="", IDS={} }>
    <cfset var dsn = (structKeyExists(application,"dsn") ? application.dsn : "")>

    <cfif NOT structKeyExists(application,"FPW_ALLOW_TEST_ENDPOINTS") OR application.FPW_ALLOW_TEST_ENDPOINTS NEQ true>
        <cfoutput><h3>TEST ENDPOINTS DISABLED</h3></cfoutput>
        <cfreturn>
    </cfif>

    <cfif NOT structKeyExists(application,"FPW_TEST_TOKEN") OR token NEQ application.FPW_TEST_TOKEN>
        <cfoutput><h3>INVALID TEST TOKEN</h3></cfoutput>
        <cfreturn>
    </cfif>

    <cftry>
        <!--- 1) Force-login as user 187 (session) --->
        <cfset forceLoginUser(userId)>

        <!--- 2) Create base float plan (ALL required fields) --->
        <cfset var ctx = ensurePrereqsForUser(userId, dsn)>
        <cfif NOT ctx.PASS>
            <cfoutput>
                <h2>FAIL: Missing prerequisites for user 187</h2>
                <pre>#htmlEditFormat(ctx.MSG)#</pre>
            </cfoutput>
            <cfreturn>
        </cfif>

        <cfset var fp = createDraftFloatPlan(userId, ctx, dsn)>
        <cfset r.IDS.floatPlanId = fp.floatPlanId>

        <!--- 3) Step 3: Attach emergency contacts (required) --->
        <cfset var s3 = attachEmergencyContacts(fp.floatPlanId, userId, ctx, dsn)>
        <cfset r.IDS.step3_contactsLinked = s3.linkedCount>

        <!--- 4) Step 4: Attach passengers (required) --->
        <cfset var s4 = attachPassengers(fp.floatPlanId, userId, ctx, dsn)>
        <cfset r.IDS.step4_passengersLinked = s4.linkedCount>

        <!--- 5) Step 5: Attach waypoints (required) --->
        <cfset var s5 = attachWaypoints(fp.floatPlanId, userId, ctx, dsn)>
        <cfset r.IDS.step5_waypointsLinked = s5.linkedCount>

        <cfoutput>
            <h2>FPW TEST: Create Full Float Plan (User 187)</h2>

            <p><b>Status:</b> PASS</p>

            <h3>Created</h3>
            <pre>#htmlEditFormat(serializeJson(r.IDS))#</pre>

            <h3>Notes</h3>
            <ul>
                <li>Plan created as <b>Draft</b> with required base fields.</li>
                <li>Steps 3/4/5 attach existing user-owned data (contacts/passengers/waypoints).</li>
                <li>If any table name differs, your SQL error will show which line to adjust.</li>
            </ul>
        </cfoutput>

        <cfcatch>
            <cfoutput>
                <h2>FAIL: Exception</h2>
                <pre>#htmlEditFormat(cfcatch.message)#</pre>
                <pre>#htmlEditFormat(cfcatch.detail)#</pre>
            </cfoutput>
        </cfcatch>
    </cftry>
</cffunction>

<!--- ------------------------- HELPERS ------------------------- --->

<cffunction name="forceLoginUser" access="private" returntype="void" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfif NOT structKeyExists(session,"user") OR NOT isStruct(session.user)>
        <cfset session.user = {} >
    </cfif>
    <!--- Minimal session struct your API expects --->
    <cfset session.user.USERID = int(arguments.userId)>
    <cfset session.user.NAME   = "TEST USER 187">
    <cfset session.user.EMAIL  = "test187@example.com">
</cffunction>

<cffunction name="ensurePrereqsForUser" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="dsn" type="string" required="true">

    <cfset var out = { PASS=true, MSG="", vesselId=0, operatorId=0 }>

    <!--- Prefer existing vessel/operator for user to avoid guessing your schema --->
    <cfset var qV = queryExecute("
        SELECT vesselId
        FROM vessels
        WHERE userId = :uid
        ORDER BY vesselId DESC
        LIMIT 1
    ", { uid={value=arguments.userId, cfsqltype="cf_sql_integer"} }, { datasource=arguments.dsn })>

    <cfset var qO = queryExecute("
        SELECT operatorId
        FROM operators
        WHERE userId = :uid
        ORDER BY operatorId DESC
        LIMIT 1
    ", { uid={value=arguments.userId, cfsqltype="cf_sql_integer"} }, { datasource=arguments.dsn })>

    <cfif qV.recordCount EQ 0>
        <cfset out.PASS = false>
        <cfset out.MSG &= "User 187 has no vessel record in vessels table. Create a vessel for user 187 first." & chr(10)>
    <cfelse>
        <cfset out.vesselId = qV.vesselId[1]>
    </cfif>

    <cfif qO.recordCount EQ 0>
        <cfset out.PASS = false>
        <cfset out.MSG &= "User 187 has no operator record in operators table. Create an operator for user 187 first." & chr(10)>
    <cfelse>
        <cfset out.operatorId = qO.operatorId[1]>
    </cfif>

    <cfreturn out>
</cffunction>

<cffunction name="createDraftFloatPlan" access="private" returntype="struct" output="false">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="ctx" type="struct" required="true">
    <cfargument name="dsn" type="string" required="true">

    <cfset var tz = "UTC">
    <cfset var depart = dateAdd("n", 5, now())>
    <cfset var ret    = dateAdd("h", 6, depart)>

    <!--- store UTC times; for test we use tz=UTC so local == UTC --->
    <cfset var params = {
        userId = { value=int(arguments.userId), cfsqltype="cf_sql_integer" },
        planName = { value="TEST Full Plan " & dateTimeFormat(now(),"yyyymmdd-HHnnss"), cfsqltype="cf_sql_varchar" },
        vesselId = { value=int(arguments.ctx.vesselId), cfsqltype="cf_sql_integer" },
        operatorId = { value=int(arguments.ctx.operatorId), cfsqltype="cf_sql_integer" },
        operatorHasPfd = { value=1, cfsqltype="cf_sql_bit" },
        email = { value="test187@example.com", cfsqltype="cf_sql_varchar" },
        rescueAuthority = { value="USCG", cfsqltype="cf_sql_varchar" },
        rescuePhone = { value="555-555-1212", cfsqltype="cf_sql_varchar" },
        rescueCenterId = { value=1, cfsqltype="cf_sql_integer" },
        departingFrom = { value="TEST MARINA", cfsqltype="cf_sql_varchar" },
        departureTime = { value=depart, cfsqltype="cf_sql_timestamp" },
        departureTz = { value=tz, cfsqltype="cf_sql_varchar" },
        returningTo = { value="TEST MARINA", cfsqltype="cf_sql_varchar" },
        returnTime = { value=ret, cfsqltype="cf_sql_timestamp" },
        returnTz = { value=tz, cfsqltype="cf_sql_varchar" },
        departureTimeUTC = { value=depart, cfsqltype="cf_sql_timestamp" },
        returnTimeUTC = { value=ret, cfsqltype="cf_sql_timestamp" },
        foodDays = { value=2, cfsqltype="cf_sql_integer" },
        waterDays = { value=2, cfsqltype="cf_sql_integer" },
        notes = { value="Automated end-to-end test plan.", cfsqltype="cf_sql_varchar" }
    }>

    <!--- NOTE: adjust column names here if your schema differs --->
    <cfset var q = queryExecute("
        INSERT INTO floatplans
        (
            userId,
            floatPlanName,
            vesselId,
            operatorId,
            opHasPfd,
            floatPlanEmail,
            rescueAuthority,
            rescueAuthorityPhone,
            rescueCenterId,
            departing,
            departureTime,
            departTimezone,
            returning,
            returnTime,
            returnTimezone,
            departureTimeUTC,
            returnTimeUTC,
            food,
            water,
            notes,
            status,
            dateCreated,
            lastUpdate
        )
        VALUES
        (
            :userId,
            :planName,
            :vesselId,
            :operatorId,
            :operatorHasPfd,
            :email,
            :rescueAuthority,
            :rescuePhone,
            :rescueCenterId,
            :departingFrom,
            :departureTime,
            :departureTz,
            :returningTo,
            :returnTime,
            :returnTz,
            :departureTimeUTC,
            :returnTimeUTC,
            :foodDays,
            :waterDays,
            :notes,
            'Draft',
            NOW(),
            NOW()
        )
    ", params, { datasource=arguments.dsn, result="ins" })>

    <cfreturn { floatPlanId = int(ins.generatedKey) }>
</cffunction>

<cffunction name="attachEmergencyContacts" access="private" returntype="struct" output="false">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="ctx" type="struct" required="true">
    <cfargument name="dsn" type="string" required="true">

    <!--- Pull 1-2 existing contacts for user --->
    <cfset var q = queryExecute("
        SELECT contactId
        FROM contacts
        WHERE userId = :uid
        ORDER BY contactId DESC
        LIMIT 2
    ", { uid={value=arguments.userId, cfsqltype="cf_sql_integer"} }, { datasource=arguments.dsn })>

    <cfif q.recordCount EQ 0>
        <cfthrow message="Step 3 failed: user 187 has no contacts in contacts table. Create at least 1 contact for user 187.">
    </cfif>

    <!--- Common mapping table name; adjust if needed --->
    <cfset var linked = 0>
    <cfloop query="q">
        <cfset queryExecute("
            INSERT INTO floatplan_contacts (floatPlanId, contactId, isEmergency, dateCreated)
            VALUES (:fp, :cid, 1, NOW())
        ", {
            fp  = {value=int(arguments.floatPlanId), cfsqltype="cf_sql_integer"},
            cid = {value=int(q.contactId), cfsqltype="cf_sql_integer"}
        }, { datasource=arguments.dsn })>
        <cfset linked++>
    </cfloop>

    <cfreturn { linkedCount = linked }>
</cffunction>

<cffunction name="attachPassengers" access="private" returntype="struct" output="false">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="ctx" type="struct" required="true">
    <cfargument name="dsn" type="string" required="true">

    <cfset var q = queryExecute("
        SELECT passengerId
        FROM passengers
        WHERE userId = :uid
        ORDER BY passengerId DESC
        LIMIT 4
    ", { uid={value=arguments.userId, cfsqltype="cf_sql_integer"} }, { datasource=arguments.dsn })>

    <cfif q.recordCount EQ 0>
        <cfthrow message="Step 4 failed: user 187 has no passengers in passengers table. Create at least 1 passenger for user 187.">
    </cfif>

    <cfset var linked = 0>
    <cfloop query="q">
        <cfset queryExecute("
            INSERT INTO floatplan_passengers (floatPlanId, passengerId, dateCreated)
            VALUES (:fp, :pid, NOW())
        ", {
            fp  = {value=int(arguments.floatPlanId), cfsqltype="cf_sql_integer"},
            pid = {value=int(q.passengerId), cfsqltype="cf_sql_integer"}
        }, { datasource=arguments.dsn })>
        <cfset linked++>
    </cfloop>

    <cfreturn { linkedCount = linked }>
</cffunction>

<cffunction name="attachWaypoints" access="private" returntype="struct" output="false">
    <cfargument name="floatPlanId" type="numeric" required="true">
    <cfargument name="userId" type="numeric" required="true">
    <cfargument name="ctx" type="struct" required="true">
    <cfargument name="dsn" type="string" required="true">

    <cfset var q = queryExecute("
        SELECT waypointId
        FROM waypoints
        WHERE userId = :uid
        ORDER BY waypointId DESC
        LIMIT 5
    ", { uid={value=arguments.userId, cfsqltype="cf_sql_integer"} }, { datasource=arguments.dsn })>

    <cfif q.recordCount EQ 0>
        <cfthrow message="Step 5 failed: user 187 has no waypoints in waypoints table. Create at least 1 waypoint for user 187.">
    </cfif>

    <cfset var linked = 0>
    <cfloop query="q">
        <cfset queryExecute("
            INSERT INTO floatplan_waypoints (floatPlanId, waypointId, sortOrder, dateCreated)
            VALUES (:fp, :wid, :ord, NOW())
        ", {
            fp  = {value=int(arguments.floatPlanId), cfsqltype="cf_sql_integer"},
            wid = {value=int(q.waypointId), cfsqltype="cf_sql_integer"},
            ord = {value=int(linked+1), cfsqltype="cf_sql_integer"}
        }, { datasource=arguments.dsn })>
        <cfset linked++>
    </cfloop>

    <cfreturn { linkedCount = linked }>
</cffunction>
