<cfcomponent output="false" hint="Parse and import Great Loop lock XLSX rows for the admin import tool.">

    <cffunction name="init" access="public" returntype="any" output="false">
        <cfargument name="datasource" type="string" required="false" default="">
        <cfscript>
            if (len(trim(arguments.datasource))) {
                variables.datasource = trim(arguments.datasource);
            } else if (structKeyExists(application, "dsn") AND len(trim(application.dsn))) {
                variables.datasource = trim(application.dsn);
            } else {
                variables.datasource = "fpw";
            }

            return this;
        </cfscript>
    </cffunction>

    <cffunction name="parseWorkbook" access="public" returntype="struct" output="false">
        <cfargument name="filePath" type="string" required="true">
        <cfargument name="originalFilename" type="string" required="false" default="">
        <cfargument name="sheetName" type="string" required="false" default="Locks">
        <cfscript>
            var qSheet = queryNew("");
            var result = {};
            var errorText = "";
            var parseMessage = "";
            var parseIssue = "";

            try {
                qSheet = readSpreadsheetQuery(arguments.filePath, arguments.sheetName);
                result = parseSheetQuery(qSheet, arguments.sheetName);
                result.source_filename = safeFilename(arguments.originalFilename);
                result.source_sheet = arguments.sheetName;
                return result;
            } catch (any e) {
                errorText = toString(e.message) & " " & toString(e.detail);
                parseMessage = "The workbook could not be parsed. Confirm the uploaded file is a valid .xlsx workbook with a Locks sheet.";
                parseIssue = "Workbook parse failed.";

                if (findNoCase("spreadsheet package is not installed", errorText)) {
                    parseMessage = "ColdFusion spreadsheet support is not installed. Install the ColdFusion spreadsheet package, then retry the upload.";
                    parseIssue = "ColdFusion spreadsheet package is not installed.";
                }

                return {
                    "SUCCESS" = false,
                    "MESSAGE" = parseMessage,
                    "ERRORS" = [
                        {
                            "row" = 0,
                            "field" = "workbook",
                            "message" = parseIssue
                        }
                    ],
                    "WARNINGS" = [],
                    "ROWS" = [],
                    "ROW_COUNT" = 0,
                    "VALID_ROW_COUNT" = 0,
                    "SOURCE_FILENAME" = safeFilename(arguments.originalFilename),
                    "SOURCE_SHEET" = arguments.sheetName
                };
            }
        </cfscript>
    </cffunction>

    <cffunction name="importRows" access="public" returntype="struct" output="false">
        <cfargument name="rows" type="array" required="true">
        <cfargument name="sourceFilename" type="string" required="true">
        <cfargument name="sourceSheet" type="string" required="false" default="Locks">
        <cfargument name="importBatchId" type="string" required="false" default="">
        <cfscript>
            var validation = validateNormalizedRows(arguments.rows);
            var insertSql = "";
            var row = {};
            var i = 0;
            var batchId = len(trim(arguments.importBatchId)) ? trim(arguments.importBatchId) : createUUID();
            var insertedRows = 0;
            var safeSourceFilename = safeFilename(arguments.sourceFilename);
            var safeSourceSheet = trim(toString(arguments.sourceSheet));
            var columnFlags = getColumnFlags([
                "slug",
                "waterway",
                "lock_system",
                "operating_authority",
                "country",
                "approach_notes",
                "operating_notes",
                "special_instructions",
                "source_name",
                "source_url",
                "last_reviewed_at",
                "is_public",
                "sort_order"
            ]);
            var insertColumns = [
                "lock_name",
                "latitude",
                "longitude",
                "note",
                "city",
                "state",
                "zip",
                "phone",
                "vhf"
            ];
            var insertValues = [
                ":lock_name",
                ":latitude",
                ":longitude",
                ":note",
                ":city",
                ":state",
                ":zip",
                ":phone",
                ":vhf"
            ];
            var rowParams = {};
            var publicColumnName = "";

            if (!validation.SUCCESS) {
                return validation;
            }

            for (publicColumnName in columnFlags) {
                if (columnFlags[publicColumnName]) {
                    arrayAppend(insertColumns, publicColumnName);
                    arrayAppend(insertValues, ":" & publicColumnName);
                }
            }
            arrayAppend(insertColumns, "source_filename");
            arrayAppend(insertValues, ":source_filename");
            arrayAppend(insertColumns, "source_sheet");
            arrayAppend(insertValues, ":source_sheet");
            arrayAppend(insertColumns, "import_batch_id");
            arrayAppend(insertValues, ":import_batch_id");

            insertSql = "
                INSERT INTO great_loop_locks (" & arrayToList(insertColumns, ", ") & ")
                VALUES (" & arrayToList(insertValues, ", ") & ")
            ";

            try {
                transaction {
                    queryExecute(
                        "DELETE FROM great_loop_locks",
                        {},
                        { "datasource" = getDatasource() }
                    );

                    for (i = 1; i LTE arrayLen(arguments.rows); i++) {
                        row = arguments.rows[i];
                        rowParams = {
                            "lock_name" = sqlString(row.lock_name, "cf_sql_varchar"),
                            "latitude" = sqlDecimal(row.latitude),
                            "longitude" = sqlDecimal(row.longitude),
                            "note" = sqlNullableString(row.note, "cf_sql_longvarchar"),
                            "city" = sqlNullableString(row.city, "cf_sql_varchar"),
                            "state" = sqlNullableString(row.state, "cf_sql_varchar"),
                            "zip" = sqlNullableString(row.zip, "cf_sql_varchar"),
                            "phone" = sqlNullableString(row.phone, "cf_sql_varchar"),
                            "vhf" = sqlNullableString(row.vhf, "cf_sql_varchar"),
                            "source_filename" = sqlString(safeSourceFilename, "cf_sql_varchar"),
                            "source_sheet" = sqlString(safeSourceSheet, "cf_sql_varchar"),
                            "import_batch_id" = sqlString(batchId, "cf_sql_char")
                        };
                        if (columnFlags.slug) rowParams.slug = sqlNullableString(optionalRowValue(row, "slug"), "cf_sql_varchar");
                        if (columnFlags.waterway) rowParams.waterway = sqlNullableString(optionalRowValue(row, "waterway"), "cf_sql_varchar");
                        if (columnFlags.lock_system) rowParams.lock_system = sqlNullableString(optionalRowValue(row, "lock_system"), "cf_sql_varchar");
                        if (columnFlags.operating_authority) rowParams.operating_authority = sqlNullableString(optionalRowValue(row, "operating_authority"), "cf_sql_varchar");
                        if (columnFlags.country) rowParams.country = sqlNullableString(optionalRowValue(row, "country"), "cf_sql_varchar");
                        if (columnFlags.approach_notes) rowParams.approach_notes = sqlNullableString(optionalRowValue(row, "approach_notes"), "cf_sql_longvarchar");
                        if (columnFlags.operating_notes) rowParams.operating_notes = sqlNullableString(optionalRowValue(row, "operating_notes"), "cf_sql_longvarchar");
                        if (columnFlags.special_instructions) rowParams.special_instructions = sqlNullableString(optionalRowValue(row, "special_instructions"), "cf_sql_longvarchar");
                        if (columnFlags.source_name) rowParams.source_name = sqlNullableString(optionalRowValue(row, "source_name"), "cf_sql_varchar");
                        if (columnFlags.source_url) rowParams.source_url = sqlNullableString(optionalRowValue(row, "source_url"), "cf_sql_varchar");
                        if (columnFlags.last_reviewed_at) rowParams.last_reviewed_at = sqlNullableDate(optionalRowValue(row, "last_reviewed_at"));
                        if (columnFlags.is_public) rowParams.is_public = sqlBoolean(optionalRowValue(row, "is_public"));
                        if (columnFlags.sort_order) rowParams.sort_order = sqlNullableInt(optionalRowValue(row, "sort_order"));

                        queryExecute(
                            insertSql,
                            rowParams,
                            { "datasource" = getDatasource() }
                        );
                        insertedRows++;
                    }
                }

                return {
                    "SUCCESS" = true,
                    "MESSAGE" = "Great Loop locks import completed.",
                    "INSERTED_ROWS" = insertedRows,
                    "IMPORT_BATCH_ID" = batchId
                };
            } catch (any e) {
                return {
                    "SUCCESS" = false,
                    "MESSAGE" = "Import failed. Confirm the great_loop_locks migration has been run and try again.",
                    "ERRORS" = [
                        {
                            "row" = 0,
                            "field" = "database",
                            "message" = "Database import failed."
                        }
                    ],
                    "INSERTED_ROWS" = 0
                };
            }
        </cfscript>
    </cffunction>

    <cffunction name="readSpreadsheetQuery" access="private" returntype="query" output="false">
        <cfargument name="filePath" type="string" required="true">
        <cfargument name="sheetName" type="string" required="true">
        <cfset var qSheet = queryNew("")>
        <cfspreadsheet action="read" src="#arguments.filePath#" query="qSheet" sheet="1">
        <cfreturn qSheet>
    </cffunction>

    <cffunction name="parseSheetQuery" access="private" returntype="struct" output="false">
        <cfargument name="qSheet" type="query" required="true">
        <cfargument name="sheetName" type="string" required="true">
        <cfscript>
            var result = {
                "SUCCESS" = true,
                "MESSAGE" = "",
                "ERRORS" = [],
                "WARNINGS" = [],
                "ROWS" = [],
                "ROW_COUNT" = 0,
                "VALID_ROW_COUNT" = 0,
                "SOURCE_SHEET" = arguments.sheetName
            };
            var columns = listToArray(arguments.qSheet.columnList);
            var headerMap = {};
            var fieldMap = {};
            var headerText = "";
            var headerKey = "";
            var rowIndex = 0;
            var row = {};
            var errCountBefore = 0;
            var uniqueSeen = {};
            var nameSeen = {};
            var coordSeen = {};
            var slugSeen = {};
            var uniqueKey = "";
            var nameKey = "";
            var coordKeyVal = "";
            var slugKey = "";
            var i = 0;
            var fieldName = "";

            if (arguments.qSheet.recordCount LT 2) {
                result.SUCCESS = false;
                result.MESSAGE = "The Locks sheet must include a header row and at least one data row.";
                arrayAppend(result.ERRORS, issue(0, "workbook", result.MESSAGE));
                return result;
            }

            for (i = 1; i LTE arrayLen(columns); i++) {
                headerText = trim(toString(arguments.qSheet[columns[i]][1]));
                headerKey = normalizeHeader(headerText);
                if (len(headerKey) AND !structKeyExists(headerMap, headerKey)) {
                    headerMap[headerKey] = i;
                }
            }

            fieldMap = resolveFieldMap(headerMap);
            if (arrayLen(fieldMap.errors)) {
                result.SUCCESS = false;
                result.MESSAGE = "The Locks sheet is missing required headers.";
                for (i = 1; i LTE arrayLen(fieldMap.errors); i++) {
                    arrayAppend(result.ERRORS, issue(1, "header", fieldMap.errors[i]));
                }
                return result;
            }

            for (rowIndex = 2; rowIndex LTE arguments.qSheet.recordCount; rowIndex++) {
                row = readMappedRow(arguments.qSheet, columns, fieldMap.fields, rowIndex);
                if (isEmptyRow(row)) {
                    continue;
                }

                result.ROW_COUNT++;
                errCountBefore = arrayLen(result.ERRORS);
                validateRow(row, result.ERRORS, result.WARNINGS);

                if (arrayLen(result.ERRORS) EQ errCountBefore) {
                    uniqueKey = lCase(row.lock_name) & "|" & coordKey(row.latitude, row.longitude);
                    nameKey = lCase(row.lock_name);
                    coordKeyVal = coordKey(row.latitude, row.longitude);

                    if (structKeyExists(uniqueSeen, uniqueKey)) {
                        arrayAppend(result.ERRORS, issue(row.row_number, "duplicate", "Duplicate lock name and coordinates also appear on row " & uniqueSeen[uniqueKey] & "."));
                    } else {
                        uniqueSeen[uniqueKey] = row.row_number;
                    }

                    if (structKeyExists(nameSeen, nameKey)) {
                        arrayAppend(result.WARNINGS, issue(row.row_number, "lock_name", "Lock name also appears on row " & nameSeen[nameKey] & "."));
                    } else {
                        nameSeen[nameKey] = row.row_number;
                    }

                    if (structKeyExists(coordSeen, coordKeyVal)) {
                        arrayAppend(result.WARNINGS, issue(row.row_number, "coordinates", "Coordinates also appear on row " & coordSeen[coordKeyVal] & "."));
                    } else {
                        coordSeen[coordKeyVal] = row.row_number;
                    }

                    slugKey = lCase(trim(toString(row.slug)));
                    if (len(slugKey)) {
                        if (structKeyExists(slugSeen, slugKey)) {
                            arrayAppend(result.ERRORS, issue(row.row_number, "slug", "Slug also appears on row " & slugSeen[slugKey] & "."));
                        } else {
                            slugSeen[slugKey] = row.row_number;
                        }
                    }
                }

                for (fieldName in [ "note", "city", "state", "zip", "phone", "vhf" ]) {
                    if (!len(trim(toString(row[fieldName])))) {
                        arrayAppend(result.WARNINGS, issue(row.row_number, fieldName, "Optional field is blank."));
                    }
                }

                arrayAppend(result.ROWS, row);
            }

            result.VALID_ROW_COUNT = arrayLen(result.ROWS);
            if (arrayLen(result.ERRORS)) {
                result.SUCCESS = false;
                result.MESSAGE = "The workbook has validation errors. Correct the file and preview again.";
            } else if (result.ROW_COUNT EQ 0) {
                result.SUCCESS = false;
                result.MESSAGE = "The Locks sheet did not contain importable rows.";
                arrayAppend(result.ERRORS, issue(0, "workbook", result.MESSAGE));
            } else {
                result.MESSAGE = "Workbook preview is ready.";
            }

            return result;
        </cfscript>
    </cffunction>

    <cffunction name="resolveFieldMap" access="private" returntype="struct" output="false">
        <cfargument name="headerMap" type="struct" required="true">
        <cfscript>
            var out = { "fields" = {}, "errors" = [] };
            var specs = [
                { "field" = "lock_name", "headers" = [ "lock_name" ], "required" = true },
                { "field" = "latitude", "headers" = [ "latitude", "lat" ], "required" = true },
                { "field" = "longitude", "headers" = [ "longitude", "lng", "lon" ], "required" = true },
                { "field" = "note", "headers" = [ "notes", "note" ], "required" = true },
                { "field" = "city", "headers" = [ "city" ], "required" = true },
                { "field" = "state", "headers" = [ "state", "province" ], "required" = true },
                { "field" = "zip", "headers" = [ "zip", "postal_code", "postal" ], "required" = true },
                { "field" = "phone", "headers" = [ "phone" ], "required" = true },
                { "field" = "vhf", "headers" = [ "vhf_channel", "vhf" ], "required" = true },
                { "field" = "slug", "headers" = [ "slug", "url_slug" ], "required" = false },
                { "field" = "waterway", "headers" = [ "waterway", "waterway_system" ], "required" = false },
                { "field" = "lock_system", "headers" = [ "lock_system", "system" ], "required" = false },
                { "field" = "operating_authority", "headers" = [ "operating_authority", "authority", "agency" ], "required" = false },
                { "field" = "country", "headers" = [ "country" ], "required" = false },
                { "field" = "approach_notes", "headers" = [ "approach_notes", "approach_note" ], "required" = false },
                { "field" = "operating_notes", "headers" = [ "operating_notes", "operating_note" ], "required" = false },
                { "field" = "special_instructions", "headers" = [ "special_instructions", "special_instruction", "special_notes" ], "required" = false },
                { "field" = "source_name", "headers" = [ "source_name", "source" ], "required" = false },
                { "field" = "source_url", "headers" = [ "source_url", "official_source_url", "url" ], "required" = false },
                { "field" = "last_reviewed_at", "headers" = [ "last_reviewed_at", "last_reviewed", "reviewed_at" ], "required" = false },
                { "field" = "is_public", "headers" = [ "is_public", "public", "published" ], "required" = false },
                { "field" = "sort_order", "headers" = [ "sort_order", "order", "sequence" ], "required" = false }
            ];
            var i = 0;
            var j = 0;
            var found = 0;
            var spec = {};

            for (i = 1; i LTE arrayLen(specs); i++) {
                spec = specs[i];
                found = 0;
                for (j = 1; j LTE arrayLen(spec.headers); j++) {
                    if (structKeyExists(arguments.headerMap, spec.headers[j])) {
                        found = arguments.headerMap[spec.headers[j]];
                        break;
                    }
                }
                if (found GT 0) {
                    out.fields[spec.field] = found;
                } else if (spec.required) {
                    arrayAppend(out.errors, "Missing required header for " & spec.field & ".");
                }
            }

            return out;
        </cfscript>
    </cffunction>

    <cffunction name="readMappedRow" access="private" returntype="struct" output="false">
        <cfargument name="qSheet" type="query" required="true">
        <cfargument name="columns" type="array" required="true">
        <cfargument name="fieldMap" type="struct" required="true">
        <cfargument name="rowIndex" type="numeric" required="true">
        <cfscript>
            var row = {
                "row_number" = arguments.rowIndex,
                "lock_name" = cellByIndex(arguments.qSheet, arguments.columns, arguments.fieldMap.lock_name, arguments.rowIndex),
                "latitude" = cellByIndex(arguments.qSheet, arguments.columns, arguments.fieldMap.latitude, arguments.rowIndex),
                "longitude" = cellByIndex(arguments.qSheet, arguments.columns, arguments.fieldMap.longitude, arguments.rowIndex),
                "note" = cellByIndex(arguments.qSheet, arguments.columns, arguments.fieldMap.note, arguments.rowIndex),
                "city" = cellByIndex(arguments.qSheet, arguments.columns, arguments.fieldMap.city, arguments.rowIndex),
                "state" = cellByIndex(arguments.qSheet, arguments.columns, arguments.fieldMap.state, arguments.rowIndex),
                "zip" = cellByIndex(arguments.qSheet, arguments.columns, arguments.fieldMap.zip, arguments.rowIndex),
                "phone" = cellByIndex(arguments.qSheet, arguments.columns, arguments.fieldMap.phone, arguments.rowIndex),
                "vhf" = cellByIndex(arguments.qSheet, arguments.columns, arguments.fieldMap.vhf, arguments.rowIndex),
                "slug" = optionalCellByField(arguments.qSheet, arguments.columns, arguments.fieldMap, "slug", arguments.rowIndex),
                "waterway" = optionalCellByField(arguments.qSheet, arguments.columns, arguments.fieldMap, "waterway", arguments.rowIndex),
                "lock_system" = optionalCellByField(arguments.qSheet, arguments.columns, arguments.fieldMap, "lock_system", arguments.rowIndex),
                "operating_authority" = optionalCellByField(arguments.qSheet, arguments.columns, arguments.fieldMap, "operating_authority", arguments.rowIndex),
                "country" = optionalCellByField(arguments.qSheet, arguments.columns, arguments.fieldMap, "country", arguments.rowIndex),
                "approach_notes" = optionalCellByField(arguments.qSheet, arguments.columns, arguments.fieldMap, "approach_notes", arguments.rowIndex),
                "operating_notes" = optionalCellByField(arguments.qSheet, arguments.columns, arguments.fieldMap, "operating_notes", arguments.rowIndex),
                "special_instructions" = optionalCellByField(arguments.qSheet, arguments.columns, arguments.fieldMap, "special_instructions", arguments.rowIndex),
                "source_name" = optionalCellByField(arguments.qSheet, arguments.columns, arguments.fieldMap, "source_name", arguments.rowIndex),
                "source_url" = optionalCellByField(arguments.qSheet, arguments.columns, arguments.fieldMap, "source_url", arguments.rowIndex),
                "last_reviewed_at" = optionalCellByField(arguments.qSheet, arguments.columns, arguments.fieldMap, "last_reviewed_at", arguments.rowIndex),
                "is_public" = optionalCellByField(arguments.qSheet, arguments.columns, arguments.fieldMap, "is_public", arguments.rowIndex),
                "sort_order" = optionalCellByField(arguments.qSheet, arguments.columns, arguments.fieldMap, "sort_order", arguments.rowIndex)
            };

            row.lock_name = trimText(row.lock_name);
            row.latitude = trimText(row.latitude);
            row.longitude = trimText(row.longitude);
            row.note = trimText(row.note);
            row.city = trimText(row.city);
            row.state = trimText(row.state);
            row.zip = trimText(row.zip);
            row.phone = trimText(row.phone);
            row.vhf = trimText(row.vhf);
            row.slug = normalizeSlug(row.slug);
            row.waterway = trimText(row.waterway);
            row.lock_system = trimText(row.lock_system);
            row.operating_authority = trimText(row.operating_authority);
            row.country = uCase(left(trimText(row.country), 2));
            row.approach_notes = trimText(row.approach_notes);
            row.operating_notes = trimText(row.operating_notes);
            row.special_instructions = trimText(row.special_instructions);
            row.source_name = trimText(row.source_name);
            row.source_url = trimText(row.source_url);
            row.last_reviewed_at = trimText(row.last_reviewed_at);
            row.is_public = boolLike(row.is_public, true) ? "1" : "0";
            row.sort_order = trimText(row.sort_order);

            if (isNumeric(row.latitude)) {
                row.latitude = numberFormat(val(row.latitude), "0.000000");
            }
            if (isNumeric(row.longitude)) {
                row.longitude = numberFormat(val(row.longitude), "0.000000");
            }

            return row;
        </cfscript>
    </cffunction>

    <cffunction name="validateNormalizedRows" access="private" returntype="struct" output="false">
        <cfargument name="rows" type="array" required="true">
        <cfscript>
            var result = { "SUCCESS" = true, "MESSAGE" = "", "ERRORS" = [] };
            var i = 0;
            var row = {};

            if (!arrayLen(arguments.rows)) {
                result.SUCCESS = false;
                result.MESSAGE = "No rows are available to import.";
                arrayAppend(result.ERRORS, issue(0, "rows", result.MESSAGE));
                return result;
            }

            for (i = 1; i LTE arrayLen(arguments.rows); i++) {
                row = arguments.rows[i];
                validateRow(row, result.ERRORS, []);
            }

            if (arrayLen(result.ERRORS)) {
                result.SUCCESS = false;
                result.MESSAGE = "Rows failed validation and were not imported.";
            }

            return result;
        </cfscript>
    </cffunction>

    <cffunction name="validateRow" access="private" returntype="void" output="false">
        <cfargument name="row" type="struct" required="true">
        <cfargument name="errors" type="array" required="true">
        <cfargument name="warnings" type="array" required="true">
        <cfscript>
            var rowNumber = structKeyExists(arguments.row, "row_number") ? arguments.row.row_number : 0;

            if (!len(trim(toString(arguments.row.lock_name)))) {
                arrayAppend(arguments.errors, issue(rowNumber, "lock_name", "Lock Name is required."));
            }
            if (!isNumeric(arguments.row.latitude)) {
                arrayAppend(arguments.errors, issue(rowNumber, "latitude", "Latitude must be numeric."));
            } else if (val(arguments.row.latitude) LT -90 OR val(arguments.row.latitude) GT 90) {
                arrayAppend(arguments.errors, issue(rowNumber, "latitude", "Latitude must be between -90 and 90."));
            }
            if (!isNumeric(arguments.row.longitude)) {
                arrayAppend(arguments.errors, issue(rowNumber, "longitude", "Longitude must be numeric."));
            } else if (val(arguments.row.longitude) LT -180 OR val(arguments.row.longitude) GT 180) {
                arrayAppend(arguments.errors, issue(rowNumber, "longitude", "Longitude must be between -180 and 180."));
            }
            if (boolLike((structKeyExists(arguments.row, "is_public") ? arguments.row.is_public : ""), false)
                AND !len(trim(toString(structKeyExists(arguments.row, "slug") ? arguments.row.slug : "")))) {
                arrayAppend(arguments.errors, issue(rowNumber, "slug", "Slug is required when a row is marked public."));
            }
            if (len(trim(toString(structKeyExists(arguments.row, "last_reviewed_at") ? arguments.row.last_reviewed_at : "")))
                AND !isDate(arguments.row.last_reviewed_at)) {
                arrayAppend(arguments.errors, issue(rowNumber, "last_reviewed_at", "Last reviewed date must be a valid date."));
            }
            if (len(trim(toString(structKeyExists(arguments.row, "sort_order") ? arguments.row.sort_order : "")))
                AND !isNumeric(arguments.row.sort_order)) {
                arrayAppend(arguments.errors, issue(rowNumber, "sort_order", "Sort order must be numeric when provided."));
            }
        </cfscript>
    </cffunction>

    <cffunction name="isEmptyRow" access="private" returntype="boolean" output="false">
        <cfargument name="row" type="struct" required="true">
        <cfscript>
            return !len(arguments.row.lock_name)
                AND !len(arguments.row.latitude)
                AND !len(arguments.row.longitude)
                AND !len(arguments.row.note)
                AND !len(arguments.row.city)
                AND !len(arguments.row.state)
                AND !len(arguments.row.zip)
                AND !len(arguments.row.phone)
                AND !len(arguments.row.vhf)
                AND !len(arguments.row.slug)
                AND !len(arguments.row.waterway)
                AND !len(arguments.row.lock_system)
                AND !len(arguments.row.operating_authority)
                AND !len(arguments.row.country)
                AND !len(arguments.row.approach_notes)
                AND !len(arguments.row.operating_notes)
                AND !len(arguments.row.special_instructions)
                AND !len(arguments.row.source_name)
                AND !len(arguments.row.source_url)
                AND !len(arguments.row.last_reviewed_at)
                AND !boolLike(arguments.row.is_public, false)
                AND !len(arguments.row.sort_order);
        </cfscript>
    </cffunction>

    <cffunction name="optionalCellByField" access="private" returntype="string" output="false">
        <cfargument name="qSheet" type="query" required="true">
        <cfargument name="columns" type="array" required="true">
        <cfargument name="fieldMap" type="struct" required="true">
        <cfargument name="fieldName" type="string" required="true">
        <cfargument name="rowIndex" type="numeric" required="true">
        <cfscript>
            if (!structKeyExists(arguments.fieldMap, arguments.fieldName)) {
                return "";
            }
            return cellByIndex(arguments.qSheet, arguments.columns, arguments.fieldMap[arguments.fieldName], arguments.rowIndex);
        </cfscript>
    </cffunction>

    <cffunction name="cellByIndex" access="private" returntype="string" output="false">
        <cfargument name="qSheet" type="query" required="true">
        <cfargument name="columns" type="array" required="true">
        <cfargument name="columnIndex" type="numeric" required="true">
        <cfargument name="rowIndex" type="numeric" required="true">
        <cfscript>
            var columnName = arguments.columns[arguments.columnIndex];

            if (arguments.rowIndex GT arguments.qSheet.recordCount) {
                return "";
            }
            return trimText(arguments.qSheet[columnName][arguments.rowIndex]);
        </cfscript>
    </cffunction>

    <cffunction name="normalizeHeader" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            var txt = lCase(trimText(arguments.value));
            txt = replace(txt, chr(160), " ", "all");
            txt = reReplace(txt, "[^a-z0-9]+", "_", "all");
            txt = reReplace(txt, "^_+|_+$", "", "all");
            return txt;
        </cfscript>
    </cffunction>

    <cffunction name="trimText" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfscript>
            var txt = trim(toString(arguments.value));
            txt = replace(txt, chr(13) & chr(10), chr(10), "all");
            txt = replace(txt, chr(13), chr(10), "all");
            return txt;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeSlug" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfscript>
            var slug = lCase(trimText(arguments.value));
            slug = replace(slug, "&", " and ", "all");
            slug = reReplace(slug, "[^a-z0-9]+", "-", "all");
            slug = reReplace(slug, "-{2,}", "-", "all");
            slug = reReplace(slug, "(^-|-$)", "", "all");
            return left(slug, 180);
        </cfscript>
    </cffunction>

    <cffunction name="boolLike" access="private" returntype="boolean" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfargument name="defaultValue" type="boolean" required="false" default="false">
        <cfscript>
            var txt = lCase(trimText(arguments.value));
            if (!len(txt)) return arguments.defaultValue;
            if (listFindNoCase("1,true,yes,y,on", txt)) return true;
            if (listFindNoCase("0,false,no,n,off", txt)) return false;
            if (isNumeric(txt)) return (val(txt) NEQ 0);
            return arguments.defaultValue;
        </cfscript>
    </cffunction>

    <cffunction name="safeFilename" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfscript>
            return left(listLast(replace(trimText(arguments.value), "\", "/", "all"), "/"), 255);
        </cfscript>
    </cffunction>

    <cffunction name="coordKey" access="private" returntype="string" output="false">
        <cfargument name="latitude" type="any" required="true">
        <cfargument name="longitude" type="any" required="true">
        <cfscript>
            return numberFormat(val(arguments.latitude), "0.000000") & "," & numberFormat(val(arguments.longitude), "0.000000");
        </cfscript>
    </cffunction>

    <cffunction name="issue" access="private" returntype="struct" output="false">
        <cfargument name="row" type="numeric" required="true">
        <cfargument name="field" type="string" required="true">
        <cfargument name="message" type="string" required="true">
        <cfscript>
            return {
                "row" = arguments.row,
                "field" = arguments.field,
                "message" = arguments.message
            };
        </cfscript>
    </cffunction>

    <cffunction name="sqlString" access="private" returntype="struct" output="false">
        <cfargument name="value" type="any" required="true">
        <cfargument name="sqlType" type="string" required="true">
        <cfscript>
            return {
                "value" = trimText(arguments.value),
                "cfsqltype" = arguments.sqlType
            };
        </cfscript>
    </cffunction>

    <cffunction name="sqlNullableString" access="private" returntype="struct" output="false">
        <cfargument name="value" type="any" required="true">
        <cfargument name="sqlType" type="string" required="true">
        <cfscript>
            var txt = trimText(arguments.value);
            if (!len(txt)) {
                return {
                    "value" = "",
                    "cfsqltype" = arguments.sqlType,
                    "null" = true
                };
            }
            return {
                "value" = txt,
                "cfsqltype" = arguments.sqlType
            };
        </cfscript>
    </cffunction>

    <cffunction name="sqlDecimal" access="private" returntype="struct" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            return {
                "value" = val(arguments.value),
                "cfsqltype" = "cf_sql_decimal",
                "scale" = 6
            };
        </cfscript>
    </cffunction>

    <cffunction name="sqlNullableDate" access="private" returntype="struct" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            var txt = trimText(arguments.value);
            if (!len(txt) OR !isDate(txt)) {
                return {
                    "value" = "",
                    "cfsqltype" = "cf_sql_date",
                    "null" = true
                };
            }
            return {
                "value" = dateFormat(txt, "yyyy-mm-dd"),
                "cfsqltype" = "cf_sql_date"
            };
        </cfscript>
    </cffunction>

    <cffunction name="sqlNullableInt" access="private" returntype="struct" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            var txt = trimText(arguments.value);
            if (!len(txt) OR !isNumeric(txt)) {
                return {
                    "value" = "",
                    "cfsqltype" = "cf_sql_integer",
                    "null" = true
                };
            }
            return {
                "value" = val(txt),
                "cfsqltype" = "cf_sql_integer"
            };
        </cfscript>
    </cffunction>

    <cffunction name="sqlBoolean" access="private" returntype="struct" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            return {
                "value" = boolLike(arguments.value, false) ? 1 : 0,
                "cfsqltype" = "cf_sql_tinyint"
            };
        </cfscript>
    </cffunction>

    <cffunction name="optionalRowValue" access="private" returntype="string" output="false">
        <cfargument name="row" type="struct" required="true">
        <cfargument name="fieldName" type="string" required="true">
        <cfscript>
            if (!structKeyExists(arguments.row, arguments.fieldName) OR isNull(arguments.row[arguments.fieldName])) {
                return "";
            }
            return trimText(arguments.row[arguments.fieldName]);
        </cfscript>
    </cffunction>

    <cffunction name="getColumnFlags" access="private" returntype="struct" output="false">
        <cfargument name="columnNames" type="array" required="true">
        <cfscript>
            var out = {};
            var qColumns = queryNew("");
            var i = 0;
            var columnName = "";

            for (i = 1; i LTE arrayLen(arguments.columnNames); i++) {
                out[arguments.columnNames[i]] = false;
            }

            qColumns = queryExecute(
                "SELECT column_name
                 FROM information_schema.columns
                 WHERE table_schema = DATABASE()
                   AND table_name = 'great_loop_locks'",
                {},
                { datasource = getDatasource() }
            );

            for (i = 1; i LTE qColumns.recordCount; i++) {
                columnName = lCase(trim(toString(qColumns.column_name[i])));
                if (structKeyExists(out, columnName)) {
                    out[columnName] = true;
                }
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getDatasource" access="private" returntype="string" output="false">
        <cfscript>
            return variables.datasource;
        </cfscript>
    </cffunction>

</cfcomponent>
