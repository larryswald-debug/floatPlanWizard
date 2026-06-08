<cfcomponent output="false" hint="CSV import service for Great Loop bridge reference rows.">

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
            variables.bridgeService = createBridgeService();
            return this;
        </cfscript>
    </cffunction>

    <cffunction name="parseCsv" access="public" returntype="struct" output="false">
        <cfargument name="filePath" type="string" required="true">
        <cfargument name="originalFilename" type="string" required="false" default="">
        <cfscript>
            var out = {
                "SUCCESS" = true,
                "MESSAGE" = "CSV preview is ready.",
                "ERRORS" = [],
                "WARNINGS" = [],
                "ROWS" = [],
                "ROW_COUNT" = 0,
                "VALID_ROW_COUNT" = 0,
                "SOURCE_FILENAME" = safeFilename(arguments.originalFilename),
                "SOURCE_SHEET" = "Bridge_Master"
            };
            var csvText = "";
            var parsed = [];
            var headers = [];
            var headerMap = {};
            var required = requiredHeaders();
            var r = 0;
            var c = 0;
            var rowArray = [];
            var row = {};
            var errors = [];

            try {
                csvText = fileRead(arguments.filePath, "utf-8");
            } catch (any eRead) {
                out.SUCCESS = false;
                out.MESSAGE = "CSV file could not be read.";
                arrayAppend(out.ERRORS, issue(0, "file", out.MESSAGE));
                return out;
            }

            parsed = parseCsvText(csvText);
            if (arrayLen(parsed) LTE 1) {
                out.SUCCESS = false;
                out.MESSAGE = "CSV did not contain bridge rows.";
                arrayAppend(out.ERRORS, issue(0, "file", out.MESSAGE));
                return out;
            }

            headers = parsed[1];
            for (c = 1; c LTE arrayLen(headers); c++) {
                headerMap[normalizeHeader(headers[c])] = c;
            }

            for (c = 1; c LTE arrayLen(required); c++) {
                if (!structKeyExists(headerMap, required[c])) {
                    out.SUCCESS = false;
                    arrayAppend(out.ERRORS, issue(1, required[c], "Missing required CSV header."));
                }
            }
            if (!out.SUCCESS) {
                out.MESSAGE = "CSV headers do not match Bridge_Master.";
                return out;
            }

            for (r = 2; r LTE arrayLen(parsed); r++) {
                rowArray = parsed[r];
                if (isEmptyCsvRow(rowArray)) {
                    continue;
                }
                row = {};
                for (c = 1; c LTE arrayLen(required); c++) {
                    row[required[c]] = cellValue(rowArray, headerMap[required[c]]);
                }
                row.row_number = r;
                row.public_status = variables.bridgeService.derivePublicStatus(row);
                row = variables.bridgeService.normalizeBridgePayload(row);
                row.row_number = r;
                errors = variables.bridgeService.validateBridge(row, false);
                if (arrayLen(errors)) {
                    arrayAppend(out.WARNINGS, issue(r, "row", "Row will be skipped: " & arrayToList(errors, " ")));
                }
                arrayAppend(out.ROWS, row);
                out.ROW_COUNT++;
            }

            out.VALID_ROW_COUNT = out.ROW_COUNT - arrayLen(out.WARNINGS);
            if (!out.ROW_COUNT) {
                out.SUCCESS = false;
                out.MESSAGE = "CSV did not contain importable bridge rows.";
                arrayAppend(out.ERRORS, issue(0, "file", out.MESSAGE));
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="importRows" access="public" returntype="struct" output="false">
        <cfargument name="rows" type="array" required="true">
        <cfargument name="sourceFilename" type="string" required="false" default="">
        <cfargument name="createdByUserId" type="numeric" required="false" default="0">
        <cfscript>
            var out = {
                "SUCCESS" = true,
                "MESSAGE" = "Bridge import complete.",
                "ROWS_READ" = arrayLen(arguments.rows),
                "INSERTED" = 0,
                "UPDATED" = 0,
                "SKIPPED" = 0,
                "ERRORED" = 0,
                "DO_NOT_PUBLISH" = 0,
                "PLANNING_ONLY" = 0,
                "PUBLISHED" = 0,
                "ERRORS" = []
            };
            var batchId = createUUID();
            var i = 0;
            var row = {};
            var errors = [];
            var existingId = 0;

            for (i = 1; i LTE arrayLen(arguments.rows); i++) {
                row = arguments.rows[i];
                errors = variables.bridgeService.validateBridge(row, false);
                if (arrayLen(errors)) {
                    out.SKIPPED++;
                    out.ERRORED++;
                    arrayAppend(out.ERRORS, issue(structKeyExists(row, "row_number") ? row.row_number : i, "row", arrayToList(errors, " ")));
                    continue;
                }

                try {
                    row = ensureUniqueImportSlug(row);
                    existingId = findExistingBridgeId(row);
                    if (existingId GT 0) {
                        row.id = existingId;
                        updateExistingBridge(row, arguments.sourceFilename, batchId);
                        out.UPDATED++;
                    } else {
                        insertBridge(row, arguments.sourceFilename, batchId);
                        out.INSERTED++;
                    }
                    if (row.public_status EQ "do_not_publish") out.DO_NOT_PUBLISH++;
                    if (row.public_status EQ "planning_only") out.PLANNING_ONLY++;
                    if (row.public_status EQ "published") out.PUBLISHED++;
                } catch (any eRow) {
                    out.ERRORED++;
                    out.SKIPPED++;
                    arrayAppend(out.ERRORS, issue(structKeyExists(row, "row_number") ? row.row_number : i, "row", "Database write failed: " & eRow.message));
                }
            }

            writeImportLog(out, safeFilename(arguments.sourceFilename), arguments.createdByUserId);
            if (out.ERRORED GT 0) {
                out.MESSAGE = "Bridge import completed with skipped rows.";
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="insertBridge" access="private" returntype="void" output="false">
        <cfargument name="row" type="struct" required="true">
        <cfargument name="sourceFilename" type="string" required="false" default="">
        <cfargument name="batchId" type="string" required="true">
        <cfscript>
            var params = variables.bridgeService.bridgeSqlParams(arguments.row);
            params.source_filename = nullableParam(arguments.sourceFilename, "cf_sql_varchar");
            params.source_sheet = { value = "Bridge_Master", cfsqltype = "cf_sql_varchar" };
            params.import_batch_id = { value = arguments.batchId, cfsqltype = "cf_sql_char" };

            queryExecute(
                "INSERT INTO great_loop_bridges (
                    bridge_id, bridge_name, slug, route_segment, route_variant, waterway,
                    state_province, nearest_city, mile_marker, latitude, longitude, bridge_type,
                    is_drawbridge, is_fixed, is_railroad, vertical_clearance_closed_ft,
                    vertical_clearance_open_ft, horizontal_clearance_ft, air_draft_notes,
                    opening_schedule, vhf_channel, phone, operator_contact, navigation_notes,
                    short_description, regulatory_notes, source_primary_url, source_secondary_url,
                    image_url, image_source, image_credit, image_license, image_allowed_for_fpw,
                    local_image_path, source_confidence, last_verified_date, display_priority,
                    verification_status, public_status, admin_notes, source_filename, source_sheet,
                    import_batch_id
                 ) VALUES (
                    :bridge_id, :bridge_name, :slug, :route_segment, :route_variant, :waterway,
                    :state_province, :nearest_city, :mile_marker, :latitude, :longitude, :bridge_type,
                    :is_drawbridge, :is_fixed, :is_railroad, :vertical_clearance_closed_ft,
                    :vertical_clearance_open_ft, :horizontal_clearance_ft, :air_draft_notes,
                    :opening_schedule, :vhf_channel, :phone, :operator_contact, :navigation_notes,
                    :short_description, :regulatory_notes, :source_primary_url, :source_secondary_url,
                    :image_url, :image_source, :image_credit, :image_license, :image_allowed_for_fpw,
                    :local_image_path, :source_confidence, :last_verified_date, :display_priority,
                    :verification_status, :public_status, :admin_notes, :source_filename, :source_sheet,
                    :import_batch_id
                 )",
                params,
                { datasource = getDatasource() }
            );
        </cfscript>
    </cffunction>

    <cffunction name="updateExistingBridge" access="private" returntype="void" output="false">
        <cfargument name="row" type="struct" required="true">
        <cfargument name="sourceFilename" type="string" required="false" default="">
        <cfargument name="batchId" type="string" required="true">
        <cfscript>
            var params = variables.bridgeService.bridgeSqlParams(arguments.row);
            params.source_filename = nullableParam(arguments.sourceFilename, "cf_sql_varchar");
            params.source_sheet = { value = "Bridge_Master", cfsqltype = "cf_sql_varchar" };
            params.import_batch_id = { value = arguments.batchId, cfsqltype = "cf_sql_char" };

            queryExecute(
                "UPDATE great_loop_bridges
                 SET bridge_id = :bridge_id,
                     bridge_name = :bridge_name,
                     slug = :slug,
                     route_segment = :route_segment,
                     route_variant = :route_variant,
                     waterway = :waterway,
                     state_province = :state_province,
                     nearest_city = :nearest_city,
                     mile_marker = :mile_marker,
                     latitude = :latitude,
                     longitude = :longitude,
                     bridge_type = :bridge_type,
                     is_drawbridge = :is_drawbridge,
                     is_fixed = :is_fixed,
                     is_railroad = :is_railroad,
                     vertical_clearance_closed_ft = :vertical_clearance_closed_ft,
                     vertical_clearance_open_ft = :vertical_clearance_open_ft,
                     horizontal_clearance_ft = :horizontal_clearance_ft,
                     air_draft_notes = :air_draft_notes,
                     opening_schedule = :opening_schedule,
                     vhf_channel = :vhf_channel,
                     phone = :phone,
                     operator_contact = :operator_contact,
                     navigation_notes = :navigation_notes,
                     short_description = :short_description,
                     regulatory_notes = :regulatory_notes,
                     source_primary_url = :source_primary_url,
                     source_secondary_url = :source_secondary_url,
                     image_url = :image_url,
                     image_source = :image_source,
                     image_credit = :image_credit,
                     image_license = :image_license,
                     image_allowed_for_fpw = :image_allowed_for_fpw,
                     local_image_path = :local_image_path,
                     source_confidence = :source_confidence,
                     last_verified_date = :last_verified_date,
                     display_priority = :display_priority,
                     verification_status = :verification_status,
                     public_status = :public_status,
                     admin_notes = :admin_notes,
                     source_filename = :source_filename,
                     source_sheet = :source_sheet,
                     import_batch_id = :import_batch_id
                 WHERE id = :id",
                params,
                { datasource = getDatasource() }
            );
        </cfscript>
    </cffunction>

    <cffunction name="findExistingBridgeId" access="private" returntype="numeric" output="false">
        <cfargument name="row" type="struct" required="true">
        <cfscript>
            var q = queryNew("");
            if (len(trim(arguments.row.bridge_id))) {
                q = queryExecute(
                    "SELECT id FROM great_loop_bridges WHERE bridge_id = :bridge_id LIMIT 1",
                    { bridge_id = { value = arguments.row.bridge_id, cfsqltype = "cf_sql_varchar" } },
                    { datasource = getDatasource() }
                );
                if (q.recordCount) return val(q.id[1]);
            }
            q = queryExecute(
                "SELECT id FROM great_loop_bridges WHERE slug = :slug LIMIT 1",
                { slug = { value = arguments.row.slug, cfsqltype = "cf_sql_varchar" } },
                { datasource = getDatasource() }
            );
            return q.recordCount ? val(q.id[1]) : 0;
        </cfscript>
    </cffunction>

    <cffunction name="ensureUniqueImportSlug" access="private" returntype="struct" output="false">
        <cfargument name="row" type="struct" required="true">
        <cfscript>
            var out = duplicate(arguments.row);
            var baseSlug = trim(out.slug);
            var suffix = "";
            var candidate = baseSlug;
            var q = queryNew("");
            var counter = 1;

            if (!len(baseSlug) OR !len(trim(out.bridge_id))) {
                return out;
            }

            q = queryExecute(
                "SELECT id, bridge_id
                 FROM great_loop_bridges
                 WHERE slug = :slug
                 LIMIT 1",
                { slug = { value = baseSlug, cfsqltype = "cf_sql_varchar" } },
                { datasource = getDatasource() }
            );
            if (!q.recordCount OR trim(q.bridge_id[1]) EQ trim(out.bridge_id)) {
                return out;
            }

            suffix = variables.bridgeService.normalizeSlug(out.bridge_id);
            if (!len(suffix)) {
                suffix = "row-" & (structKeyExists(out, "row_number") ? out.row_number : createUUID());
            }
            candidate = left(baseSlug & "-" & suffix, 255);

            while (slugExistsForDifferentBridge(candidate, out.bridge_id)) {
                counter++;
                candidate = left(baseSlug & "-" & suffix & "-" & counter, 255);
            }
            out.slug = candidate;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="slugExistsForDifferentBridge" access="private" returntype="boolean" output="false">
        <cfargument name="slug" type="string" required="true">
        <cfargument name="bridgeId" type="string" required="true">
        <cfscript>
            var q = queryExecute(
                "SELECT bridge_id
                 FROM great_loop_bridges
                 WHERE slug = :slug
                 LIMIT 1",
                { slug = { value = arguments.slug, cfsqltype = "cf_sql_varchar" } },
                { datasource = getDatasource() }
            );
            return q.recordCount AND trim(q.bridge_id[1]) NEQ trim(arguments.bridgeId);
        </cfscript>
    </cffunction>

    <cffunction name="writeImportLog" access="private" returntype="void" output="false">
        <cfargument name="result" type="struct" required="true">
        <cfargument name="filename" type="string" required="false" default="">
        <cfargument name="createdByUserId" type="numeric" required="false" default="0">
        <cfscript>
            try {
                queryExecute(
                    "INSERT INTO great_loop_bridge_import_logs (
                        import_filename, rows_read, rows_inserted, rows_updated, rows_skipped,
                        rows_errored, do_not_publish_count, planning_only_count, published_count,
                        summary_json, created_by_user_id
                     ) VALUES (
                        :import_filename, :rows_read, :rows_inserted, :rows_updated, :rows_skipped,
                        :rows_errored, :do_not_publish_count, :planning_only_count, :published_count,
                        :summary_json, :created_by_user_id
                     )",
                    {
                        import_filename = nullableParam(arguments.filename, "cf_sql_varchar"),
                        rows_read = { value = arguments.result.ROWS_READ, cfsqltype = "cf_sql_integer" },
                        rows_inserted = { value = arguments.result.INSERTED, cfsqltype = "cf_sql_integer" },
                        rows_updated = { value = arguments.result.UPDATED, cfsqltype = "cf_sql_integer" },
                        rows_skipped = { value = arguments.result.SKIPPED, cfsqltype = "cf_sql_integer" },
                        rows_errored = { value = arguments.result.ERRORED, cfsqltype = "cf_sql_integer" },
                        do_not_publish_count = { value = arguments.result.DO_NOT_PUBLISH, cfsqltype = "cf_sql_integer" },
                        planning_only_count = { value = arguments.result.PLANNING_ONLY, cfsqltype = "cf_sql_integer" },
                        published_count = { value = arguments.result.PUBLISHED, cfsqltype = "cf_sql_integer" },
                        summary_json = nullableParam(serializeJSON(arguments.result), "cf_sql_longvarchar"),
                        created_by_user_id = arguments.createdByUserId GT 0
                            ? { value = arguments.createdByUserId, cfsqltype = "cf_sql_bigint" }
                            : { value = 0, cfsqltype = "cf_sql_bigint", null = true }
                    },
                    { datasource = getDatasource() }
                );
            } catch (any e) {
                // Import log write failure should not fail the import itself.
            }
        </cfscript>
    </cffunction>

    <cffunction name="parseCsvText" access="private" returntype="array" output="false">
        <cfargument name="csvText" type="string" required="true">
        <cfscript>
            var rows = [];
            var row = [];
            var field = "";
            var inQuotes = false;
            var i = 1;
            var ch = "";
            var nextCh = "";
            var textLen = len(arguments.csvText);

            while (i LTE textLen) {
                ch = mid(arguments.csvText, i, 1);
                nextCh = i LT textLen ? mid(arguments.csvText, i + 1, 1) : "";
                if (ch EQ """") {
                    if (inQuotes AND nextCh EQ """") {
                        field &= """";
                        i += 2;
                        continue;
                    }
                    inQuotes = !inQuotes;
                } else if (ch EQ "," AND !inQuotes) {
                    arrayAppend(row, field);
                    field = "";
                } else if ((ch EQ chr(10) OR ch EQ chr(13)) AND !inQuotes) {
                    if (ch EQ chr(13) AND nextCh EQ chr(10)) {
                        i++;
                    }
                    arrayAppend(row, field);
                    if (!isEmptyCsvRow(row)) {
                        arrayAppend(rows, row);
                    }
                    row = [];
                    field = "";
                } else {
                    field &= ch;
                }
                i++;
            }
            arrayAppend(row, field);
            if (!isEmptyCsvRow(row)) {
                arrayAppend(rows, row);
            }
            return rows;
        </cfscript>
    </cffunction>

    <cffunction name="requiredHeaders" access="private" returntype="array" output="false">
        <cfscript>
            return [
                "bridge_id","bridge_name","slug","route_segment","route_variant","waterway",
                "state_province","nearest_city","mile_marker","latitude","longitude","bridge_type",
                "is_drawbridge","is_fixed","is_railroad","vertical_clearance_closed_ft",
                "vertical_clearance_open_ft","horizontal_clearance_ft","air_draft_notes",
                "opening_schedule","vhf_channel","phone","operator_contact","navigation_notes",
                "short_description","regulatory_notes","source_primary_url","source_secondary_url",
                "image_url","image_source","image_credit","image_license","image_allowed_for_fpw",
                "local_image_path","source_confidence","last_verified_date","display_priority",
                "verification_status","admin_notes"
            ];
        </cfscript>
    </cffunction>

    <cffunction name="cellValue" access="private" returntype="string" output="false">
        <cfargument name="rowArray" type="array" required="true">
        <cfargument name="indexValue" type="numeric" required="true">
        <cfscript>
            if (arguments.indexValue LTE 0 OR arguments.indexValue GT arrayLen(arguments.rowArray)) {
                return "";
            }
            return trimText(arguments.rowArray[arguments.indexValue]);
        </cfscript>
    </cffunction>

    <cffunction name="isEmptyCsvRow" access="private" returntype="boolean" output="false">
        <cfargument name="rowArray" type="array" required="true">
        <cfscript>
            var i = 0;
            for (i = 1; i LTE arrayLen(arguments.rowArray); i++) {
                if (len(trimText(arguments.rowArray[i]))) {
                    return false;
                }
            }
            return true;
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

    <cffunction name="createBridgeService" access="private" returntype="any" output="false">
        <cfscript>
            try {
                return createObject("component", "api.v1.GreatLoopBridgesService").init(getDatasource());
            } catch (any ePath) {
                return createObject("component", "fpw.api.v1.GreatLoopBridgesService").init(getDatasource());
            }
        </cfscript>
    </cffunction>

    <cffunction name="safeFilename" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfscript>
            return left(listLast(replace(trimText(arguments.value), "\", "/", "all"), "/"), 255);
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

    <cffunction name="nullableParam" access="private" returntype="struct" output="false">
        <cfargument name="value" type="any" required="true">
        <cfargument name="sqlType" type="string" required="true">
        <cfscript>
            var txt = trimText(arguments.value);
            if (!len(txt)) {
                return { "value" = "", "cfsqltype" = arguments.sqlType, "null" = true };
            }
            return { "value" = txt, "cfsqltype" = arguments.sqlType };
        </cfscript>
    </cffunction>

    <cffunction name="issue" access="private" returntype="struct" output="false">
        <cfargument name="row" type="numeric" required="true">
        <cfargument name="field" type="string" required="true">
        <cfargument name="message" type="string" required="true">
        <cfscript>
            return { "row" = arguments.row, "field" = arguments.field, "message" = arguments.message };
        </cfscript>
    </cffunction>

    <cffunction name="getDatasource" access="private" returntype="string" output="false">
        <cfscript>
            return variables.datasource;
        </cfscript>
    </cffunction>

</cfcomponent>
