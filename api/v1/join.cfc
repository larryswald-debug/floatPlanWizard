<cfcomponent output="false">

    <cffunction name="handle" access="remote" returntype="void" output="true">
        <cfsetting enablecfoutputonly="true" showdebugoutput="false">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">

        <cftry>

            <!-- Read request body -->
            <cfset httpData = getHttpRequestData()>
            <cfset rawBody  = toString(httpData.content)>
            <cfset body     = {}>

            <cfif len(trim(rawBody))>
                <cfset body = deserializeJSON(rawBody, false)>
            </cfif>

            <!-- Fallback to FORM fields -->
            <cfif NOT structKeyExists(body, "firstName") AND structKeyExists(form, "firstName")>
                <cfset body.firstName = form.firstName>
            </cfif>
            <cfif NOT structKeyExists(body, "lastName") AND structKeyExists(form, "lastName")>
                <cfset body.lastName = form.lastName>
            </cfif>
            <cfif NOT structKeyExists(body, "email") AND structKeyExists(form, "email")>
                <cfset body.email = form.email>
            </cfif>
            <cfif NOT structKeyExists(body, "address") AND structKeyExists(form, "address")>
                <cfset body.address = form.address>
            </cfif>
            <cfif NOT structKeyExists(body, "city") AND structKeyExists(form, "city")>
                <cfset body.city = form.city>
            </cfif>
            <cfif NOT structKeyExists(body, "state") AND structKeyExists(form, "state")>
                <cfset body.state = form.state>
            </cfif>
            <cfif NOT structKeyExists(body, "zip") AND structKeyExists(form, "zip")>
                <cfset body.zip = form.zip>
            </cfif>
            <cfif NOT structKeyExists(body, "phone") AND structKeyExists(form, "phone")>
                <cfset body.phone = form.phone>
            </cfif>
            <cfif NOT structKeyExists(body, "password") AND structKeyExists(form, "password")>
                <cfset body.password = form.password>
            </cfif>
            <cfif NOT structKeyExists(body, "confirmPassword") AND structKeyExists(form, "confirmPassword")>
                <cfset body.confirmPassword = form.confirmPassword>
            </cfif>
            <cfif NOT structKeyExists(body, "termsAccepted") AND structKeyExists(form, "termsAccepted")>
                <cfset body.termsAccepted = form.termsAccepted>
            </cfif>

            <cfset firstName = trim(body.firstName ?: body.fName ?: "")>
            <cfset lastName  = trim(body.lastName  ?: body.lName ?: "")>
            <cfset email     = trim(body.email     ?: "")>
            <cfset address   = trim(body.address   ?: "")>
            <cfset city      = trim(body.city      ?: "")>
            <cfset state     = trim(body.state     ?: "")>
            <cfset zip       = trim(body.zip       ?: "")>
            <cfset phone     = trim(body.phone     ?: "")>
            <cfset password  = trim(body.password  ?: "")>
            <cfset confirmPassword = "">
            <cfif structKeyExists(body, "confirmPassword")>
                <cfset confirmPassword = trim(body.confirmPassword)>
            <cfelseif structKeyExists(body, "passwordConfirm")>
                <cfset confirmPassword = trim(body.passwordConfirm)>
            </cfif>
            <cfset termsValue = false>
            <cfif structKeyExists(body, "termsAccepted")>
                <cfset termsValue = body.termsAccepted>
            <cfelseif structKeyExists(body, "acceptTerms")>
                <cfset termsValue = body.acceptTerms>
            <cfelseif structKeyExists(body, "terms")>
                <cfset termsValue = body.terms>
            </cfif>
            <cfset termsAccepted = isTruthy(termsValue)>
            <cfset redirectUrl = resolveFpwBasePath() & "/app/start-trial.cfm?offer=launch_trial">

            <!-- Validate required fields -->
            <cfif NOT len(firstName) OR NOT len(lastName) OR NOT len(email)>
                <cfset response = {
                    SUCCESS = false,
                    MESSAGE = "First name, last name, and email are required.",
                    ERROR   = "MISSING_FIELDS"
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfif NOT reFindNoCase("^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$", email)>
                <cfset response = {
                    SUCCESS = false,
                    MESSAGE = "Enter a valid email address.",
                    ERROR   = "INVALID_EMAIL"
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfif NOT len(password)>
                <cfset response = {
                    SUCCESS = false,
                    MESSAGE = "Password is required.",
                    ERROR   = "PASSWORD_REQUIRED"
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfif len(password) LT 8>
                <cfset response = {
                    SUCCESS = false,
                    MESSAGE = "Password must be at least 8 characters.",
                    ERROR   = "PASSWORD_TOO_SHORT"
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfif NOT len(confirmPassword) OR password NEQ confirmPassword>
                <cfset response = {
                    SUCCESS = false,
                    MESSAGE = "Password and confirmation do not match.",
                    ERROR   = "PASSWORD_MISMATCH"
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfif NOT termsAccepted>
                <cfset response = {
                    SUCCESS = false,
                    MESSAGE = "Terms of Service and Privacy Policy acceptance is required.",
                    ERROR   = "TERMS_REQUIRED"
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

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
                <cfset response = {
                    SUCCESS = false,
                    MESSAGE = "That email is already registered.",
                    ERROR   = "EMAIL_EXISTS"
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfset passwordHash = ucase(hash(password, "SHA-256", "UTF-8"))>
            <cfset nowStamp = now()>

            <!-- Build values for users insert -->
            <cfset userValues = {}>
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

            <cfset userInsert = buildInsert("users", userValues)>
            <cfif NOT userInsert.ok>
                <cflog
                    file="user_caused_errors"
                    type="error"
                    text="join.cfc INSERT_FAILED | message=#userInsert.message# | detail=unavailable | script=#(structKeyExists(cgi, 'script_name') ? cgi.script_name : 'unavailable')# | template=#getCurrentTemplatePath()# | time=#now()# | line=unavailable">
                <cfset response = {
                    SUCCESS = false,
                    MESSAGE = "An error has occurred while processing your request. The site administrator has been notified. If you continue to experience this issue, please contact us using the Contact Us form.",
                    ERROR   = "INSERT_FAILED"
                }>
                <cfoutput>#serializeJSON(response)#</cfoutput>
                <cfsetting enablecfoutputonly="false">
                <cfabort>
            </cfif>

            <cfset queryExecute(
                userInsert.sql,
                userInsert.params,
                { datasource = "fpw" }
            )>
            <cfset newIdQ = queryExecute("SELECT LAST_INSERT_ID() AS newId", {}, { datasource = "fpw" })>
            <cfset newUserId = val(newIdQ.newId[1])>

            <!-- Optional address/phone insert -->
            <cfif len(address) OR len(city) OR len(state) OR len(zip) OR len(phone)>
                <cfset addrValues = {}>
                <cfset addrValues.userid = newUserId>
                <cfset addrValues.address = address>
                <cfset addrValues.city = city>
                <cfset addrValues.state = state>
                <cfset addrValues.zip = zip>
                <cfset addrValues.phone = phone>
                <cfset addrValues.ishomeport = 0>
                <cfset addrValues.created = nowStamp>
                <cfset addrValues.lastupdate = nowStamp>

                <cfset addrInsert = buildInsert("users_address", addrValues)>
                <cfif addrInsert.ok>
                    <cfset queryExecute(
                        addrInsert.sql,
                        addrInsert.params,
                        { datasource = "fpw" }
                    )>
                </cfif>
            </cfif>

            <cfquery datasource="fpw">
                UPDATE users
                SET lastLogin = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#nowStamp#">
                WHERE userId = <cfqueryparam cfsqltype="cf_sql_integer" value="#newUserId#">
            </cfquery>

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

            <cfset response = {
                SUCCESS = true,
                success = true,
                AUTH = true,
                auth = true,
                MESSAGE = "User created successfully.",
                USERID  = newUserId,
                EMAIL   = email,
                USER = session.user,
                user = session.user,
                REDIRECT_URL = redirectUrl,
                redirectUrl = redirectUrl
            }>

            <cfoutput>#serializeJSON(response)#</cfoutput>

        <cfcatch type="any">
            <cflog
                file="user_caused_errors"
                type="error"
                text="join.cfc SERVER_ERROR | message=#cfcatch.message# | detail=#(structKeyExists(cfcatch, 'detail') ? cfcatch.detail : 'unavailable')# | script=#(structKeyExists(cgi, 'script_name') ? cgi.script_name : 'unavailable')# | template=#(structKeyExists(cfcatch, 'tagContext') AND isArray(cfcatch.tagContext) AND arrayLen(cfcatch.tagContext) AND structKeyExists(cfcatch.tagContext[1], 'template') ? cfcatch.tagContext[1].template : getCurrentTemplatePath())# | time=#now()# | line=#(structKeyExists(cfcatch, 'tagContext') AND isArray(cfcatch.tagContext) AND arrayLen(cfcatch.tagContext) AND structKeyExists(cfcatch.tagContext[1], 'line') ? cfcatch.tagContext[1].line : 'unavailable')#">
            <cfset errResponse = {
                SUCCESS = false,
                MESSAGE = "An error has occurred while processing your request. The site administrator has been notified. If you continue to experience this issue, please contact us using the Contact Us form.",
                ERROR   = "SERVER_ERROR"
            }>
            <cfoutput>#serializeJSON(errResponse)#</cfoutput>
        </cfcatch>

        </cftry>

        <cfsetting enablecfoutputonly="false">
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

</cfcomponent>
