<cfcomponent output="false">

    <cffunction name="exportLiveDatabase" access="remote" returntype="void" output="true">
        <cfsetting showdebugoutput="false">

        <cfset var response = { "SUCCESS" = false, "AUTH" = false, "DATA" = {}, "ERROR" = {} }>
        <cfset var dsn = "">
        <cfset var dbName = "">
        <cfset var backupDir = "">
        <cfset var fileName = "">
        <cfset var filePath = "">
        <cfset var qDb = "">
        <cfset var qTables = "">
        <cfset var fileObj = "">
        <cfset var sizeBytes = 0>
        <cfset var readable = false>
        <cfset var previewLine = "">
        <cfset var reader = "">

        <cftry>
            <cfif NOT isAuthorizedRequest()>
                <cfset response.ERROR = {
                    "CODE" = "UNAUTHORIZED",
                    "MESSAGE" = "A valid backup token is required."
                }>
                <cfset writeJsonResponse(response)>
                <cfreturn>
            </cfif>

            <cfset response.AUTH = true>
            <cfset dsn = resolveDatasourceName()>
            <cfset qDb = queryExecute(
                "SELECT DATABASE() AS db_name",
                {},
                { datasource = dsn }
            )>

            <cfif qDb.recordCount EQ 0 OR NOT len(trim(qDb.db_name[1]))>
                <cfthrow message="Unable to resolve the active database name for export.">
            </cfif>

            <cfset dbName = trim(qDb.db_name[1])>
            <cfset qTables = queryExecute(
                "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'BASE TABLE' ORDER BY TABLE_NAME",
                {},
                { datasource = dsn }
            )>

            <cfset backupDir = resolveBackupDirectory()>
            <cfif NOT directoryExists(backupDir)>
                <cfdirectory action="create" directory="#backupDir#">
            </cfif>

            <cfset fileName = "fpw-live-db-" & dateFormat(now(), "yyyymmdd") & "-" & timeFormat(now(), "HHnnss") & ".sql">
            <cfset filePath = backupDir & "/" & fileName>

            <cffile action="write" file="#filePath#" output="#buildDumpHeader(dbName, qTables.recordCount)#" charset="utf-8">

            <cfloop query="qTables">
                <cfset appendTableDump(filePath, dsn, qTables.TABLE_NAME)>
            </cfloop>

            <cffile action="append" file="#filePath#" output="#chr(10)#SET FOREIGN_KEY_CHECKS=1;#chr(10)#" charset="utf-8">

            <cfset fileObj = createObject("java", "java.io.File").init(filePath)>
            <cfset sizeBytes = javacast("long", fileObj.length())>
            <cfset readable = fileObj.exists() AND fileObj.isFile() AND fileObj.canRead() AND sizeBytes GT 0>

            <cfif readable>
                <cfset reader = fileOpen(filePath, "read", "utf-8")>
                <cfif NOT fileIsEOF(reader)>
                    <cfset previewLine = fileReadLine(reader)>
                </cfif>
                <cfset fileClose(reader)>
            </cfif>

            <cfset response.SUCCESS = readable>
            <cfset response.DATA = {
                "METHOD" = "cfml_sql_export_via_mcpcfc_endpoint",
                "DATABASE_NAME" = dbName,
                "TABLE_COUNT" = qTables.recordCount,
                "BACKUP_FILE" = filePath,
                "FILE_NAME" = fileName,
                "SIZE_BYTES" = sizeBytes,
                "READABLE" = readable,
                "PREVIEW_LINE" = previewLine
            }>

            <cfif NOT readable>
                <cfset response.ERROR = {
                    "CODE" = "BACKUP_VERIFICATION_FAILED",
                    "MESSAGE" = "The backup file was written but could not be verified as readable."
                }>
            </cfif>

            <cfset writeJsonResponse(response)>
        <cfcatch>
            <cfif isDefined("reader") AND isSimpleValue(reader) EQ false>
                <cftry>
                    <cfset fileClose(reader)>
                    <cfcatch></cfcatch>
                </cftry>
            </cfif>
            <cfset response.SUCCESS = false>
            <cflog file="fpw-db-backup" type="error" text="Backup export failed: #cfcatch.message# #cfcatch.detail#">
            <cfset response.ERROR = {
                "CODE" = "BACKUP_EXPORT_FAILED",
                "MESSAGE" = "Database backup export failed."
            }>
            <cfset writeJsonResponse(response)>
        </cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="isAuthorizedRequest" access="private" returntype="boolean" output="false">
        <cfset var token = "">
        <cfif structKeyExists(url, "token")>
            <cfset token = trim(toString(url.token))>
        </cfif>

        <cfif NOT structKeyExists(application, "monitorToken") OR NOT len(trim(toString(application.monitorToken)))>
            <cfreturn false>
        </cfif>

        <cfif NOT structKeyExists(application, "env") OR lCase(toString(application.env)) NEQ "dev">
            <cfreturn false>
        </cfif>

        <cfreturn len(token) GT 0 AND token EQ toString(application.monitorToken)>
    </cffunction>

    <cffunction name="resolveDatasourceName" access="private" returntype="string" output="false">
        <cfif structKeyExists(application, "DSN") AND len(trim(toString(application.DSN)))>
            <cfreturn trim(toString(application.DSN))>
        </cfif>
        <cfif structKeyExists(application, "dsn") AND len(trim(toString(application.dsn)))>
            <cfreturn trim(toString(application.dsn))>
        </cfif>
        <cfreturn "fpw">
    </cffunction>

    <cffunction name="buildDumpHeader" access="private" returntype="string" output="false">
        <cfargument name="dbName" type="string" required="true">
        <cfargument name="tableCount" type="numeric" required="true">
        <cfset var lines = []>
        <cfset arrayAppend(lines, "-- FPW live database backup")>
        <cfset arrayAppend(lines, "-- Database: " & arguments.dbName)>
        <cfset arrayAppend(lines, "-- Exported at: " & dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss"))>
        <cfset arrayAppend(lines, "-- Table count: " & arguments.tableCount)>
        <cfset arrayAppend(lines, "SET FOREIGN_KEY_CHECKS=0;")>
        <cfset arrayAppend(lines, "")>
        <cfreturn arrayToList(lines, chr(10))>
    </cffunction>

    <cffunction name="appendTableDump" access="private" returntype="void" output="false">
        <cfargument name="filePath" type="string" required="true">
        <cfargument name="dsn" type="string" required="true">
        <cfargument name="tableName" type="string" required="true">

        <cfset var quotedTable = quoteIdentifier(arguments.tableName)>
        <cfset var qCreate = "">
        <cfset var createColumnName = "">
        <cfset var createSql = "">
        <cfset var qColumns = "">
        <cfset var qRows = "">
        <cfset var columnNames = []>
        <cfset var columnExprs = []>
        <cfset var insertPrefix = "">
        <cfset var chunk = "">
        <cfset var rowIndex = 0>
        <cfset var selectSql = "">

        <cfset qCreate = queryExecute(
            "SHOW CREATE TABLE " & quotedTable,
            {},
            { datasource = arguments.dsn }
        )>
        <cfset createColumnName = listLast(qCreate.columnList)>
        <cfset createSql = qCreate[ createColumnName ][ 1 ]>

        <cfset qColumns = queryExecute(
            "SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :table_name ORDER BY ORDINAL_POSITION",
            {
                table_name = { value = arguments.tableName, cfsqltype = "cf_sql_varchar" }
            },
            { datasource = arguments.dsn }
        )>

        <cfloop query="qColumns">
            <cfset arrayAppend(columnNames, quoteIdentifier(qColumns.COLUMN_NAME))>
            <cfset arrayAppend(columnExprs, "IF(" & quoteIdentifier(qColumns.COLUMN_NAME) & " IS NULL, 'NULL', QUOTE(" & quoteIdentifier(qColumns.COLUMN_NAME) & "))")>
        </cfloop>

        <cfset chunk = "--" & chr(10) & "-- Table: " & arguments.tableName & chr(10) & "--" & chr(10)>
        <cfset chunk &= "DROP TABLE IF EXISTS " & quotedTable & ";" & chr(10)>
        <cfset chunk &= createSql & ";" & chr(10) & chr(10)>

        <cfif arrayLen(columnExprs) GT 0>
            <cfset selectSql = "SELECT CONCAT('(', " & arrayToList(columnExprs, ", ") & ", ')') AS ROW_SQL FROM " & quotedTable>
            <cfset qRows = queryExecute(selectSql, {}, { datasource = arguments.dsn })>
            <cfset insertPrefix = "INSERT INTO " & quotedTable & " (" & arrayToList(columnNames, ", ") & ") VALUES ">

            <cfloop from="1" to="#qRows.recordCount#" index="rowIndex">
                <cfset chunk &= insertPrefix & qRows.ROW_SQL[ rowIndex ] & ";" & chr(10)>
            </cfloop>
        </cfif>

        <cfset chunk &= chr(10)>
        <cffile action="append" file="#arguments.filePath#" output="#chunk#" charset="utf-8">
    </cffunction>

    <cffunction name="quoteIdentifier" access="private" returntype="string" output="false">
        <cfargument name="value" type="string" required="true">
        <cfreturn "`" & replace(arguments.value, "`", "``", "all") & "`">
    </cffunction>

    <cffunction name="resolveBackupDirectory" access="private" returntype="string" output="false">
        <cfset var apiDir = getDirectoryFromPath(getCurrentTemplatePath())>
        <cfset var repoDir = createObject("java", "java.io.File").init(apiDir & "../../").getCanonicalPath()>
        <cfset var backupDir = createObject("java", "java.io.File").init(repoDir & "/.codex-db-backups").getCanonicalPath()>
        <cfreturn backupDir>
    </cffunction>

    <cffunction name="writeJsonResponse" access="private" returntype="void" output="true">
        <cfargument name="payload" type="struct" required="true">
        <cfset var responseDir = resolveBackupDirectory()>
        <cfset var responsePath = responseDir & "/last-export-response.json">
        <cfif NOT directoryExists(responseDir)>
            <cfdirectory action="create" directory="#responseDir#">
        </cfif>
        <cffile action="write" file="#responsePath#" output="#serializeJSON(arguments.payload)#" charset="utf-8">
        <cfcontent type="application/json; charset=utf-8">
        <cfheader name="Cache-Control" value="no-store, no-cache, must-revalidate">
        <cfoutput>#serializeJSON(arguments.payload)#</cfoutput>
    </cffunction>

</cfcomponent>




