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

            <cfset firstName = trim(body.firstName ?: body.fName ?: "")>
            <cfset lastName  = trim(body.lastName  ?: body.lName ?: "")>
            <cfset email     = trim(body.email     ?: "")>
            <cfset address   = trim(body.address   ?: "")>
            <cfset city      = trim(body.city      ?: "")>
            <cfset state     = trim(body.state     ?: "")>
            <cfset zip       = trim(body.zip       ?: "")>
            <cfset phone     = trim(body.phone     ?: "")>
            <cfset password  = trim(body.password  ?: "")>

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

            <cfset usingDefaultPassword = false>
            <cfif NOT len(password)>
                <cfset password = "changeIt">
                <cfset usingDefaultPassword = true>
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
                <cfset response = {
                    SUCCESS = false,
                    MESSAGE = "Unable to create user.",
                    ERROR   = "INSERT_FAILED",
                    DETAIL  = userInsert.message
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

            <cfset response = {
                SUCCESS = true,
                MESSAGE = "User created successfully.",
                USERID  = newUserId,
                EMAIL   = email
            }>
            <cfif usingDefaultPassword>
                <cfset response.TEMP_PASSWORD = "changeIt">
            </cfif>

            <cfoutput>#serializeJSON(response)#</cfoutput>

        <cfcatch type="any">
            <cfset errResponse = {
                SUCCESS = false,
                MESSAGE = "Server error while creating user.",
                ERROR   = "SERVER_ERROR",
                DETAIL  = cfcatch.message
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

</cfcomponent>
