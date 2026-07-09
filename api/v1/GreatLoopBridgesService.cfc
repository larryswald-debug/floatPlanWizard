<cfcomponent output="false" hint="Great Loop bridge reference library service.">

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

    <cffunction name="getLibraryModel" access="public" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var normalized = normalizeFilters(arguments.filters);
            var cached = {};
            var out = {};

            if (isDefaultPublicLibraryFilters(normalized)) {
                cached = getCachedBridgeLibraryModel();
                if (isStruct(cached) AND structCount(cached) GT 0) {
                    return cached;
                }
            }

            out = {
                "SUCCESS" = true,
                "HAS_SCHEMA" = hasBridgeSchema(),
                "FILTERS" = buildFilterStruct(normalized),
                "STATS" = getStats(),
                "BRIDGES" = [],
                "FACETS" = getFilterOptions(normalized)
            };

            out.BRIDGES = searchPublicBridges(normalized).ROWS;

            if (isDefaultPublicLibraryFilters(normalized)) {
                putCachedBridgeLibraryModel(out);
            }

            return out;
        </cfscript>
    </cffunction>

    <cffunction name="clearBridgeLibraryCache" access="public" returntype="void" output="false">
        <cfscript>
            try {
                cacheRemove(buildBridgeLibraryCacheKey());
            } catch (any cacheError) {
            }
        </cfscript>
    </cffunction>

    <cffunction name="getFilterOptions" access="public" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var normalized = normalizeFilters(arguments.filters);
            var out = structNew("ordered");

            out["success"] = true;
            out["routeSegments"] = facetsToOptions(getFacets("route_segment", normalized));
            out["routeVariants"] = facetsToOptions(getFacets("route_variant", normalized));
            out["waterways"] = facetsToOptions(getFacets("waterway", normalized));
            out["states"] = facetsToOptions(getFacets("state_province", normalized));
            out["bridgeTypes"] = facetsToOptions(getFacets("bridge_type", normalized));
            out["verificationStatuses"] = facetsToOptions(getFacets("verification_status", normalized));
            out["publicStatuses"] = [
                { "value" = "published", "label" = "Published" },
                { "value" = "planning_only", "label" = "Planning only" }
            ];
            out["message"] = "";
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getBridgesApiModel" access="public" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="false" default="#structNew()#">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var normalized = normalizeFilters(arguments.filters);
            var result = searchPublicBridges(normalized);
            var out = structNew("ordered");

            out["success"] = result.SUCCESS;
            out["filters"] = buildFilterStruct(normalized);
            out["summary"] = buildSummary(result.ROWS);
            out["bridges"] = bridgesToApiRows(result.ROWS, arguments.basePath);
            out["message"] = "";
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getAdminFacets" access="public" returntype="struct" output="false">
        <cfscript>
            return {
                "routeSegments" = facetsToAdminOptions(getAdminFacet("route_segment")),
                "routeVariants" = facetsToAdminOptions(getAdminFacet("route_variant")),
                "waterways" = facetsToAdminOptions(getAdminFacet("waterway")),
                "states" = facetsToAdminOptions(getAdminFacet("state_province")),
                "bridgeTypes" = facetsToAdminOptions(getAdminFacet("bridge_type")),
                "verificationStatuses" = facetsToAdminOptions(getAdminFacet("verification_status")),
                "publicStatuses" = [
                    { "value" = "published", "label" = "Published" },
                    { "value" = "planning_only", "label" = "Planning only" },
                    { "value" = "admin_review", "label" = "Admin review" },
                    { "value" = "do_not_publish", "label" = "Do not publish" }
                ]
            };
        </cfscript>
    </cffunction>

    <cffunction name="getStats" access="public" returntype="struct" output="false">
        <cfscript>
            var out = {
                "TOTAL_ROWS" = 0,
                "PUBLIC_ROWS" = 0,
                "PUBLISHED_ROWS" = 0,
                "PLANNING_ONLY_ROWS" = 0,
                "ADMIN_REVIEW_ROWS" = 0,
                "DO_NOT_PUBLISH_ROWS" = 0,
                "MISSING_COORDINATES_ROWS" = 0,
                "DRAWBRIDGE_MISSING_CONTACT_ROWS" = 0,
                "APPROVED_IMAGE_ROWS" = 0,
                "ROUTE_SEGMENT_COUNT" = 0,
                "WATERWAY_COUNT" = 0,
                "STATE_COUNT" = 0
            };
            var q = queryNew("");

            if (!hasBridgeSchema()) {
                return out;
            }

            q = queryExecute(
                "SELECT
                    COUNT(*) AS total_rows,
                    SUM(CASE WHEN public_status IN ('published','planning_only') THEN 1 ELSE 0 END) AS public_rows,
                    SUM(CASE WHEN public_status = 'published' THEN 1 ELSE 0 END) AS published_rows,
                    SUM(CASE WHEN public_status = 'planning_only' THEN 1 ELSE 0 END) AS planning_only_rows,
                    SUM(CASE WHEN public_status = 'admin_review' THEN 1 ELSE 0 END) AS admin_review_rows,
                    SUM(CASE WHEN public_status = 'do_not_publish' THEN 1 ELSE 0 END) AS do_not_publish_rows,
                    SUM(CASE WHEN latitude IS NULL OR longitude IS NULL THEN 1 ELSE 0 END) AS missing_coordinates_rows,
                    SUM(CASE WHEN is_drawbridge = 1 AND COALESCE(TRIM(vhf_channel), '') = '' AND COALESCE(TRIM(phone), '') = '' THEN 1 ELSE 0 END) AS drawbridge_missing_contact_rows,
                    SUM(CASE WHEN image_allowed_for_fpw = 1 AND COALESCE(TRIM(local_image_path), '') <> '' THEN 1 ELSE 0 END) AS approved_image_rows,
                    COUNT(DISTINCT NULLIF(TRIM(route_segment), '')) AS route_segment_count,
                    COUNT(DISTINCT NULLIF(TRIM(waterway), '')) AS waterway_count,
                    COUNT(DISTINCT NULLIF(TRIM(state_province), '')) AS state_count
                 FROM great_loop_bridges",
                {},
                { datasource = getDatasource() }
            );

            if (q.recordCount) {
                out.TOTAL_ROWS = val(q.total_rows[1]);
                out.PUBLIC_ROWS = val(q.public_rows[1]);
                out.PUBLISHED_ROWS = val(q.published_rows[1]);
                out.PLANNING_ONLY_ROWS = val(q.planning_only_rows[1]);
                out.ADMIN_REVIEW_ROWS = val(q.admin_review_rows[1]);
                out.DO_NOT_PUBLISH_ROWS = val(q.do_not_publish_rows[1]);
                out.MISSING_COORDINATES_ROWS = val(q.missing_coordinates_rows[1]);
                out.DRAWBRIDGE_MISSING_CONTACT_ROWS = val(q.drawbridge_missing_contact_rows[1]);
                out.APPROVED_IMAGE_ROWS = val(q.approved_image_rows[1]);
                out.ROUTE_SEGMENT_COUNT = val(q.route_segment_count[1]);
                out.WATERWAY_COUNT = val(q.waterway_count[1]);
                out.STATE_COUNT = val(q.state_count[1]);
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="searchPublicBridges" access="public" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var normalized = normalizeFilters(arguments.filters);
            var out = { "SUCCESS" = true, "ROWS" = [], "COUNT" = 0 };
            var sqlParts = buildBridgeSearchSql(normalized, true);
            var q = queryNew("");
            var i = 0;

            if (!hasBridgeSchema()) {
                return out;
            }

            q = queryExecute(sqlParts.sql, sqlParts.params, { datasource = getDatasource() });
            for (i = 1; i LTE q.recordCount; i++) {
                arrayAppend(out.ROWS, rowToStruct(q, i));
            }
            out.COUNT = arrayLen(out.ROWS);
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="searchAdminBridges" access="public" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var normalized = normalizeAdminFilters(arguments.filters);
            var out = { "SUCCESS" = true, "ROWS" = [], "TOTAL" = 0, "LIMIT" = normalized.limit, "OFFSET" = normalized.offset, "FILTERS" = normalized };
            var sqlParts = buildAdminSearchSql(normalized);
            var q = queryNew("");
            var i = 0;

            if (!hasBridgeSchema()) {
                out.SUCCESS = false;
                out.MESSAGE = "Great Loop bridge table is not available.";
                return out;
            }

            q = queryExecute(sqlParts.countSql, sqlParts.params, { datasource = getDatasource() });
            if (q.recordCount) {
                out.TOTAL = val(q.total_rows[1]);
            }

            sqlParts.params.limitRows = { value = normalized.limit, cfsqltype = "cf_sql_integer" };
            sqlParts.params.offsetRows = { value = normalized.offset, cfsqltype = "cf_sql_integer" };
            q = queryExecute(sqlParts.sql, sqlParts.params, { datasource = getDatasource() });
            for (i = 1; i LTE q.recordCount; i++) {
                arrayAppend(out.ROWS, rowToStruct(q, i));
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getBridgeBySlug" access="public" returntype="struct" output="false">
        <cfargument name="slug" type="string" required="true">
        <cfscript>
            var out = { "SUCCESS" = false, "BRIDGE" = {} };
            var q = queryNew("");
            var slugValue = normalizeSlug(arguments.slug);

            if (!hasBridgeSchema() OR !len(slugValue)) {
                out.MESSAGE = "Bridge not found.";
                return out;
            }

            q = queryExecute(
                buildSelectSql() & "
                 FROM great_loop_bridges
                 WHERE slug = :slug
                   AND public_status IN ('published','planning_only')
                 LIMIT 1",
                { slug = { value = slugValue, cfsqltype = "cf_sql_varchar" } },
                { datasource = getDatasource() }
            );

            if (!q.recordCount) {
                out.MESSAGE = "Bridge not found.";
                return out;
            }

            out.SUCCESS = true;
            out.BRIDGE = rowToStruct(q, 1);
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getStateModel" access="public" returntype="struct" output="false">
        <cfargument name="slug" type="string" required="true">
        <cfscript>
            var stateName = resolveFacetValueBySlug("state_province", arguments.slug);
            var out = { "SUCCESS" = false, "STATE" = stateName, "BRIDGES" = [], "STATS" = getStats() };

            if (!len(stateName)) {
                out.MESSAGE = "State or province not found.";
                return out;
            }

            out.BRIDGES = searchPublicBridges({ "stateProvince" = stateName, "limit" = 500 }).ROWS;
            out.SUCCESS = true;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getWaterwayModel" access="public" returntype="struct" output="false">
        <cfargument name="slug" type="string" required="true">
        <cfscript>
            var waterwayName = resolveFacetValueBySlug("waterway", arguments.slug);
            var out = { "SUCCESS" = false, "WATERWAY" = waterwayName, "BRIDGES" = [], "STATS" = getStats() };

            if (!len(waterwayName)) {
                out.MESSAGE = "Waterway not found.";
                return out;
            }

            out.BRIDGES = searchPublicBridges({ "waterway" = waterwayName, "limit" = 500 }).ROWS;
            out.SUCCESS = true;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getRouteSegmentModel" access="public" returntype="struct" output="false">
        <cfargument name="slug" type="string" required="true">
        <cfscript>
            var routeSegmentName = resolveFacetValueBySlug("route_segment", arguments.slug);
            var out = { "SUCCESS" = false, "ROUTE_SEGMENT" = routeSegmentName, "BRIDGES" = [], "STATS" = getStats() };

            if (!len(routeSegmentName)) {
                out.MESSAGE = "Route segment not found.";
                return out;
            }

            out.BRIDGES = searchPublicBridges({ "routeSegment" = routeSegmentName, "limit" = 500 }).ROWS;
            out.SUCCESS = true;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getBridgeById" access="public" returntype="struct" output="false">
        <cfargument name="bridgeId" type="numeric" required="true">
        <cfscript>
            var out = { "SUCCESS" = false, "BRIDGE" = {} };
            var q = queryNew("");

            if (!hasBridgeSchema() OR val(arguments.bridgeId) LTE 0) {
                out.MESSAGE = "Bridge not found.";
                return out;
            }

            q = queryExecute(
                buildSelectSql() & "
                 FROM great_loop_bridges
                 WHERE id = :id
                 LIMIT 1",
                { id = { value = val(arguments.bridgeId), cfsqltype = "cf_sql_bigint" } },
                { datasource = getDatasource() }
            );

            if (!q.recordCount) {
                out.MESSAGE = "Bridge not found.";
                return out;
            }

            out.SUCCESS = true;
            out.BRIDGE = rowToStruct(q, 1);
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="updateBridge" access="public" returntype="struct" output="false">
        <cfargument name="payload" type="struct" required="true">
        <cfscript>
            var row = normalizeBridgePayload(arguments.payload);
            var errors = validateBridge(row, true);
            var existing = {};

            if (arrayLen(errors)) {
                return { "SUCCESS" = false, "MESSAGE" = "Bridge validation failed.", "ERRORS" = errors };
            }
            if (!hasBridgeSchema() OR val(row.id) LTE 0) {
                return { "SUCCESS" = false, "MESSAGE" = "Bridge not found.", "ERRORS" = [ "Bridge id is required." ] };
            }

            existing = getBridgeById(row.id);
            if (!existing.SUCCESS) {
                return { "SUCCESS" = false, "MESSAGE" = "Bridge not found.", "ERRORS" = [ "Bridge not found." ] };
            }

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
                     admin_notes = :admin_notes
                 WHERE id = :id",
                bridgeSqlParams(row),
                { datasource = getDatasource() }
            );

            clearBridgeLibraryCache();

            return {
                "SUCCESS" = true,
                "MESSAGE" = "Bridge saved.",
                "BRIDGE" = getBridgeById(row.id).BRIDGE
            };
        </cfscript>
    </cffunction>

    <cffunction name="bulkUpdatePublicStatus" access="public" returntype="struct" output="false">
        <cfargument name="bridgeIds" type="any" required="true">
        <cfargument name="publicStatus" type="string" required="true">
        <cfscript>
            var out = { "SUCCESS" = false, "MESSAGE" = "", "UPDATED_COUNT" = 0, "ERRORS" = [] };
            var allowedStatuses = "published,planning_only,admin_review,do_not_publish";
            var statusValue = lCase(trim(arguments.publicStatus));
            var rawIds = [];
            var rawIdText = "";
            var cleanIds = [];
            var seenIds = {};
            var placeholders = [];
            var updateParams = {};
            var i = 0;
            var rawValue = "";
            var idValue = 0;
            var idKey = "";
            var paramName = "";
            var countQuery = queryNew("");

            if (!hasBridgeSchema()) {
                out.MESSAGE = "Great Loop bridge table is not available.";
                arrayAppend(out.ERRORS, out.MESSAGE);
                return out;
            }
            if (!listFindNoCase(allowedStatuses, statusValue)) {
                out.MESSAGE = "Choose a valid Public Status.";
                arrayAppend(out.ERRORS, out.MESSAGE);
                return out;
            }

            if (isArray(arguments.bridgeIds)) {
                rawIds = arguments.bridgeIds;
            } else {
                rawIdText = replace(trim(toString(arguments.bridgeIds)), chr(13), "", "all");
                rawIdText = replace(rawIdText, chr(10), ",", "all");
                rawIds = listToArray(rawIdText);
            }

            for (i = 1; i LTE arrayLen(rawIds); i++) {
                rawValue = trim(toString(rawIds[i]));
                if (!len(rawValue)) {
                    continue;
                }
                if (!reFind("^[0-9]+$", rawValue)) {
                    arrayAppend(out.ERRORS, "Bridge id '" & rawValue & "' is not valid.");
                    continue;
                }
                idValue = val(rawValue);
                if (idValue LTE 0) {
                    arrayAppend(out.ERRORS, "Bridge id must be a positive integer.");
                    continue;
                }
                idKey = toString(idValue);
                if (!structKeyExists(seenIds, idKey)) {
                    seenIds[idKey] = true;
                    arrayAppend(cleanIds, idValue);
                }
            }

            if (arrayLen(out.ERRORS)) {
                out.MESSAGE = "Bulk update rejected. Check the selected bridge ids.";
                return out;
            }
            if (!arrayLen(cleanIds)) {
                out.MESSAGE = "Select at least one bridge row.";
                arrayAppend(out.ERRORS, out.MESSAGE);
                return out;
            }

            for (i = 1; i LTE arrayLen(cleanIds); i++) {
                paramName = "bridgeId" & i;
                arrayAppend(placeholders, ":" & paramName);
                updateParams[paramName] = { value = cleanIds[i], cfsqltype = "cf_sql_bigint" };
            }
            updateParams.public_status = { value = statusValue, cfsqltype = "cf_sql_varchar" };

            queryExecute(
                "UPDATE great_loop_bridges
                 SET public_status = :public_status,
                     updated_at = CURRENT_TIMESTAMP
                 WHERE id IN (" & arrayToList(placeholders, ",") & ")",
                updateParams,
                { datasource = getDatasource() }
            );

            countQuery = queryExecute(
                "SELECT COUNT(*) AS row_count
                 FROM great_loop_bridges
                 WHERE public_status = :public_status
                   AND id IN (" & arrayToList(placeholders, ",") & ")",
                updateParams,
                { datasource = getDatasource() }
            );

            clearBridgeLibraryCache();
            out.SUCCESS = true;
            out.UPDATED_COUNT = countQuery.recordCount ? val(countQuery.row_count[1]) : 0;
            out.MESSAGE = "Set Public Status for " & numberFormat(out.UPDATED_COUNT) & " bridge row" & (out.UPDATED_COUNT EQ 1 ? "" : "s") & ".";
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="saveUploadedBridgeImage" access="public" returntype="struct" output="false">
        <cfargument name="bridgeId" type="numeric" required="true">
        <cfargument name="uploadPath" type="string" required="true">
        <cfargument name="originalFileName" type="string" required="true">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var out = { "SUCCESS" = false, "BRIDGE" = {}, "IMAGE" = {}, "MESSAGE" = "" };
            var bridgeResult = getBridgeById(arguments.bridgeId);
            var bridgeRow = {};
            var ext = lCase(trim(listLast(arguments.originalFileName, ".")));
            var imageRoot = getBridgeImageRootPath();
            var thumbnailRoot = getBridgeThumbnailRootPath();
            var slugKey = "";
            var fileName = "";
            var destinationPath = "";
            var thumbnailPath = "";
            var img = "";
            var localPath = "";

            if (!bridgeResult.SUCCESS) {
                out.MESSAGE = "Bridge not found.";
                return out;
            }
            if (!listFindNoCase("jpg,jpeg,png,webp", ext)) {
                out.MESSAGE = "Upload rejected. Use a JPG, PNG, or WEBP image.";
                return out;
            }
            if (!fileExists(arguments.uploadPath)) {
                out.MESSAGE = "Uploaded image was not found.";
                return out;
            }

            bridgeRow = bridgeResult.BRIDGE;
            slugKey = normalizeSlug(readAny(bridgeRow, [ "slug", "SLUG" ], ""));
            if (!len(slugKey)) {
                out.MESSAGE = "The bridge must have a valid slug before an image can be saved.";
                return out;
            }

            try {
                img = imageRead(arguments.uploadPath);
            } catch (any imageReadError) {
                out.MESSAGE = "Upload rejected. The file could not be read as an image.";
                return out;
            }

            ensureDirectory(imageRoot);
            ensureDirectory(thumbnailRoot);
            fileName = slugKey & "." & ext;
            destinationPath = joinPath(imageRoot, fileName);
            thumbnailPath = joinPath(thumbnailRoot, fileName);
            localPath = "assets/images/great-loop-bridges/" & fileName;

            deleteStaleBridgeImages(bridgeRow, fileName);
            if (fileExists(destinationPath)) {
                fileDelete(destinationPath);
            }
            fileCopy(arguments.uploadPath, destinationPath);

            try {
                generateBridgeThumbnail(destinationPath, thumbnailPath);
            } catch (any thumbnailError) {
                out.MESSAGE = "Image saved, but thumbnail generation failed.";
                out.SUCCESS = false;
                return out;
            }

            queryExecute(
                "UPDATE great_loop_bridges
                 SET local_image_path = :local_image_path,
                     image_allowed_for_fpw = 1,
                     updated_at = CURRENT_TIMESTAMP
                 WHERE id = :id",
                {
                    "id" = { value = val(arguments.bridgeId), cfsqltype = "cf_sql_bigint" },
                    "local_image_path" = { value = localPath, cfsqltype = "cf_sql_varchar" }
                },
                { datasource = getDatasource() }
            );

            bridgeResult = getBridgeById(arguments.bridgeId);
            out.SUCCESS = true;
            out.MESSAGE = "Bridge image saved.";
            out.BRIDGE = bridgeResult.BRIDGE;
            out.IMAGE = getBridgeImageAsset(out.BRIDGE, arguments.basePath);
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="deleteBridgeImage" access="public" returntype="struct" output="false">
        <cfargument name="bridgeId" type="numeric" required="true">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var out = { "SUCCESS" = false, "BRIDGE" = {}, "IMAGE" = {}, "DELETED" = [], "MESSAGE" = "" };
            var bridgeResult = getBridgeById(arguments.bridgeId);
            var bridgeRow = {};
            var imageRoot = getBridgeImageRootPath();
            var thumbnailRoot = getBridgeThumbnailRootPath();
            var localPath = "";
            var fileName = "";
            var filePath = "";
            var thumbnailPath = "";

            if (!bridgeResult.SUCCESS) {
                out.MESSAGE = "Bridge not found.";
                return out;
            }

            bridgeRow = bridgeResult.BRIDGE;
            localPath = normalizeBridgeImageRelativePath(readAny(bridgeRow, [ "local_image_path", "LOCAL_IMAGE_PATH" ], ""));
            if (!len(localPath)) {
                out.MESSAGE = "No local bridge image was found.";
                out.BRIDGE = bridgeRow;
                out.IMAGE = getBridgeImageAsset(bridgeRow, arguments.basePath);
                return out;
            }

            fileName = listLast(localPath, "/");
            filePath = joinPath(imageRoot, fileName);
            thumbnailPath = joinPath(thumbnailRoot, fileName);
            if (deleteImageFileIfSafe(filePath, imageRoot)) {
                arrayAppend(out.DELETED, fileName);
            }
            if (deleteImageFileIfSafe(thumbnailPath, thumbnailRoot)) {
                arrayAppend(out.DELETED, "thumbnails/" & fileName);
            }

            queryExecute(
                "UPDATE great_loop_bridges
                 SET local_image_path = NULL,
                     image_allowed_for_fpw = 0,
                     updated_at = CURRENT_TIMESTAMP
                 WHERE id = :id",
                {
                    "id" = { value = val(arguments.bridgeId), cfsqltype = "cf_sql_bigint" }
                },
                { datasource = getDatasource() }
            );

            bridgeResult = getBridgeById(arguments.bridgeId);
            out.SUCCESS = true;
            out.MESSAGE = arrayLen(out.DELETED) ? "Bridge image deleted." : "Bridge image reference cleared.";
            out.BRIDGE = bridgeResult.BRIDGE;
            out.IMAGE = getBridgeImageAsset(out.BRIDGE, arguments.basePath);
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="derivePublicStatus" access="public" returntype="string" output="false">
        <cfargument name="row" type="struct" required="true">
        <cfscript>
            var bridgeName = readAny(arguments.row, [ "bridge_name", "BRIDGE_NAME" ], "");
            var verificationStatus = readAny(arguments.row, [ "verification_status", "VERIFICATION_STATUS" ], "");
            var adminNotes = readAny(arguments.row, [ "admin_notes", "ADMIN_NOTES" ], "");
            var txt = lCase(trim(bridgeName & " " & verificationStatus & " " & adminNotes));

            if (find("do not publish", txt) OR find("do_not_publish", txt)) {
                return "do_not_publish";
            }
            if (find("source-backed public display", txt)) {
                return "published";
            }
            return "planning_only";
        </cfscript>
    </cffunction>

    <cffunction name="getBridgeImageAsset" access="public" returntype="struct" output="false">
        <cfargument name="bridgeRow" type="struct" required="true">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var out = {
                "hasImage" = false,
                "url" = arguments.basePath & "/assets/images/great-loop-bridges/placeholders/bridge-placeholder.svg",
                "fileName" = "",
                "isPlaceholder" = true,
                "sourceUrl" = "",
                "thumbnailUrl" = arguments.basePath & "/assets/images/great-loop-bridges/placeholders/bridge-placeholder.svg",
                "hasThumbnail" = false
            };
            var allowed = boolLike(readAny(arguments.bridgeRow, [ "image_allowed_for_fpw", "IMAGE_ALLOWED_FOR_FPW" ], ""), false);
            var rel = replace(trim(toString(readAny(arguments.bridgeRow, [ "local_image_path", "LOCAL_IMAGE_PATH" ], ""))), "\", "/", "all");
            var ext = "";
            var repoPath = "";
            var thumbnailPath = "";
            var sourceUrl = "";

            if (!allowed OR !len(rel)) {
                return out;
            }

            rel = reReplace(rel, "^/+", "");
            if (find("..", rel)) {
                return out;
            }
            if (findNoCase("assets/images/great-loop-bridges/", rel) NEQ 1) {
                rel = "assets/images/great-loop-bridges/" & listLast(rel, "/");
            }

            ext = lCase(listLast(rel, "."));
            if (!listFindNoCase("jpg,jpeg,png,webp,svg", ext)) {
                return out;
            }

            repoPath = getRepoRootPath() & rel;
            if (!fileExists(repoPath)) {
                return out;
            }

            out.fileName = listLast(rel, "/");
            thumbnailPath = joinPath(getBridgeThumbnailRootPath(), out.fileName);
            sourceUrl = imageUrlWithVersion(arguments.basePath & "/" & rel, repoPath);
            out.hasImage = true;
            out.url = sourceUrl;
            out.sourceUrl = sourceUrl;
            out.thumbnailUrl = sourceUrl;
            out.isPlaceholder = false;
            if (fileExists(thumbnailPath)) {
                out.thumbnailUrl = imageUrlWithVersion(arguments.basePath & "/assets/images/great-loop-bridges/thumbnails/" & out.fileName, thumbnailPath);
                out.hasThumbnail = true;
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeSlug" access="public" returntype="string" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            var slug = lCase(trim(toString(arguments.value)));
            slug = replace(slug, "&", " and ", "all");
            slug = reReplace(slug, "[^a-z0-9]+", "-", "all");
            slug = reReplace(slug, "-{2,}", "-", "all");
            slug = reReplace(slug, "(^-|-$)", "", "all");
            return left(slug, 255);
        </cfscript>
    </cffunction>

    <cffunction name="buildPublicBridgeUrl" access="public" returntype="string" output="false">
        <cfargument name="slug" type="any" required="true">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var slugPath = normalizeSlug(arguments.slug);
            return arguments.basePath & "/great-loop/bridges/" & slugPath & "/";
        </cfscript>
    </cffunction>

    <cffunction name="buildBridgeSearchSql" access="private" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="true">
        <cfargument name="publicOnly" type="boolean" required="true">
        <cfscript>
            var conditions = [];
            var params = {};
            var sql = "";
            var allowedPublic = "published,planning_only";
            var publicStatus = lCase(trim(arguments.filters.publicStatus));
            var common = {};

            if (arguments.publicOnly) {
                arrayAppend(conditions, "public_status IN ('published','planning_only')");
                arrayAppend(conditions, "slug IS NOT NULL AND TRIM(slug) <> ''");
                if (len(publicStatus) AND listFindNoCase(allowedPublic, publicStatus)) {
                    arrayAppend(conditions, "public_status = :publicStatus");
                    params.publicStatus = { value = publicStatus, cfsqltype = "cf_sql_varchar" };
                }
            }

            common = addCommonConditions(conditions, params, arguments.filters);
            conditions = common.conditions;
            params = common.params;
            if (!arrayLen(conditions)) {
                arrayAppend(conditions, "1=1");
            }

            sql = buildSelectSql() & "
                FROM great_loop_bridges
                WHERE " & arrayToList(conditions, " AND ") & "
                ORDER BY COALESCE(display_priority, 100) ASC,
                         COALESCE(route_segment, '') ASC,
                         COALESCE(waterway, '') ASC,
                         COALESCE(CAST(NULLIF(mile_marker, '') AS DECIMAL(10,2)), 99999) ASC,
                         bridge_name ASC
                LIMIT :limitRows";
            params.limitRows = { value = arguments.filters.limit, cfsqltype = "cf_sql_integer" };

            return { "sql" = sql, "params" = params };
        </cfscript>
    </cffunction>

    <cffunction name="buildAdminSearchSql" access="private" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="true">
        <cfscript>
            var conditions = [];
            var params = {};
            var common = {};

            common = addCommonConditions(conditions, params, arguments.filters);
            conditions = common.conditions;
            params = common.params;
            if (len(arguments.filters.publicStatus) AND listFindNoCase("published,planning_only,admin_review,do_not_publish", arguments.filters.publicStatus)) {
                arrayAppend(conditions, "public_status = :publicStatus");
                params.publicStatus = { value = arguments.filters.publicStatus, cfsqltype = "cf_sql_varchar" };
            }
            if (len(arguments.filters.missingCoordinates)) {
                arrayAppend(conditions, "(latitude IS NULL OR longitude IS NULL)");
            }
            if (len(arguments.filters.missingDrawbridgeContact)) {
                arrayAppend(conditions, "(is_drawbridge = 1 AND COALESCE(TRIM(vhf_channel), '') = '' AND COALESCE(TRIM(phone), '') = '')");
            }
            if (arguments.filters.imageStatus EQ "has_image") {
                arrayAppend(conditions, "(image_allowed_for_fpw = 1 AND local_image_path IS NOT NULL AND TRIM(local_image_path) <> '')");
            } else if (arguments.filters.imageStatus EQ "no_image" OR len(arguments.filters.missingImage)) {
                arrayAppend(conditions, "(image_allowed_for_fpw = 0 OR local_image_path IS NULL OR TRIM(local_image_path) = '')");
            }
            if (len(arguments.filters.doNotPublish)) {
                arrayAppend(conditions, "public_status = 'do_not_publish'");
            }
            if (!arrayLen(conditions)) {
                arrayAppend(conditions, "1=1");
            }

            return {
                "countSql" = "SELECT COUNT(*) AS total_rows FROM great_loop_bridges WHERE " & arrayToList(conditions, " AND "),
                "sql" = buildSelectSql() & "
                    FROM great_loop_bridges
                    WHERE " & arrayToList(conditions, " AND ") & "
                    ORDER BY id ASC
                    LIMIT :limitRows OFFSET :offsetRows",
                "params" = params
            };
        </cfscript>
    </cffunction>

    <cffunction name="addCommonConditions" access="private" returntype="struct" output="false">
        <cfargument name="conditions" type="array" required="true">
        <cfargument name="params" type="struct" required="true">
        <cfargument name="filters" type="struct" required="true">
        <cfscript>
            if (len(arguments.filters.q)) {
                arrayAppend(arguments.conditions, "(
                    bridge_name LIKE :q
                    OR COALESCE(bridge_id, '') LIKE :q
                    OR COALESCE(route_segment, '') LIKE :q
                    OR COALESCE(route_variant, '') LIKE :q
                    OR COALESCE(waterway, '') LIKE :q
                    OR COALESCE(state_province, '') LIKE :q
                    OR COALESCE(nearest_city, '') LIKE :q
                    OR COALESCE(bridge_type, '') LIKE :q
                    OR COALESCE(vhf_channel, '') LIKE :q
                    OR COALESCE(phone, '') LIKE :q
                )");
                arguments.params.q = { value = "%" & arguments.filters.q & "%", cfsqltype = "cf_sql_varchar" };
            }
            if (len(trim(arguments.filters.routeSegment))) {
                arrayAppend(arguments.conditions, "route_segment = :routeSegment");
                arguments.params.routeSegment = { value = arguments.filters.routeSegment, cfsqltype = "cf_sql_varchar" };
            }
            if (len(trim(arguments.filters.routeVariant))) {
                arrayAppend(arguments.conditions, "route_variant = :routeVariant");
                arguments.params.routeVariant = { value = arguments.filters.routeVariant, cfsqltype = "cf_sql_varchar" };
            }
            if (len(trim(arguments.filters.waterway))) {
                arrayAppend(arguments.conditions, "waterway = :waterway");
                arguments.params.waterway = { value = arguments.filters.waterway, cfsqltype = "cf_sql_varchar" };
            }
            if (len(trim(arguments.filters.stateProvince))) {
                arrayAppend(arguments.conditions, "state_province = :stateProvince");
                arguments.params.stateProvince = { value = arguments.filters.stateProvince, cfsqltype = "cf_sql_varchar" };
            }
            if (len(trim(arguments.filters.bridgeType))) {
                arrayAppend(arguments.conditions, "bridge_type = :bridgeType");
                arguments.params.bridgeType = { value = arguments.filters.bridgeType, cfsqltype = "cf_sql_varchar" };
            }
            if (len(trim(arguments.filters.verificationStatus))) {
                arrayAppend(arguments.conditions, "verification_status = :verificationStatus");
                arguments.params.verificationStatus = { value = arguments.filters.verificationStatus, cfsqltype = "cf_sql_varchar" };
            }
            if (arguments.filters.drawbridgeOnly) {
                arrayAppend(arguments.conditions, "is_drawbridge = 1");
            }
            if (arguments.filters.airDraftConcern) {
                arrayAppend(arguments.conditions, "((vertical_clearance_closed_ft IS NOT NULL AND vertical_clearance_closed_ft <= 65) OR (air_draft_notes IS NOT NULL AND TRIM(air_draft_notes) <> ''))");
            }
            if (arguments.filters.hasContact) {
                arrayAppend(arguments.conditions, "(COALESCE(TRIM(vhf_channel), '') <> '' OR COALESCE(TRIM(phone), '') <> '')");
            }
            if (arguments.filters.hasCoordinates) {
                arrayAppend(arguments.conditions, "(latitude IS NOT NULL AND longitude IS NOT NULL)");
            }
            return { "conditions" = arguments.conditions, "params" = arguments.params };
        </cfscript>
    </cffunction>

    <cffunction name="addEqualsCondition" access="private" returntype="void" output="false">
        <cfargument name="conditions" type="array" required="true">
        <cfargument name="params" type="struct" required="true">
        <cfargument name="columnName" type="string" required="true">
        <cfargument name="paramName" type="string" required="true">
        <cfargument name="value" type="string" required="true">
        <cfscript>
            if (len(trim(arguments.value))) {
                arrayAppend(arguments.conditions, arguments.columnName & " = :" & arguments.paramName);
                arguments.params[arguments.paramName] = { value = arguments.value, cfsqltype = "cf_sql_varchar" };
            }
        </cfscript>
    </cffunction>

    <cffunction name="buildSelectSql" access="private" returntype="string" output="false">
        <cfscript>
            return "SELECT
                id, bridge_id, bridge_name, slug, route_segment, route_variant, waterway,
                state_province, nearest_city, mile_marker, latitude, longitude, bridge_type,
                is_drawbridge, is_fixed, is_railroad, vertical_clearance_closed_ft,
                vertical_clearance_open_ft, horizontal_clearance_ft, air_draft_notes,
                opening_schedule, vhf_channel, phone, operator_contact, navigation_notes,
                short_description, regulatory_notes, source_primary_url, source_secondary_url,
                image_url, image_source, image_credit, image_license, image_allowed_for_fpw,
                local_image_path, source_confidence, last_verified_date, display_priority,
                verification_status, public_status, admin_notes, source_filename, source_sheet,
                import_batch_id, created_at, updated_at";
        </cfscript>
    </cffunction>

    <cffunction name="rowToStruct" access="private" returntype="struct" output="false">
        <cfargument name="q" type="query" required="true">
        <cfargument name="i" type="numeric" required="true">
        <cfscript>
            var out = structNew("ordered");
            var columns = listToArray(arguments.q.columnList);
            var col = "";
            var idx = 0;

            for (idx = 1; idx LTE arrayLen(columns); idx++) {
                col = lCase(columns[idx]);
                out[col] = isNull(arguments.q[columns[idx]][arguments.i]) ? "" : arguments.q[columns[idx]][arguments.i];
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="bridgesToApiRows" access="private" returntype="array" output="false">
        <cfargument name="rows" type="array" required="true">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var out = [];
            var i = 0;
            var row = {};
            var item = {};
            var image = {};

            for (i = 1; i LTE arrayLen(arguments.rows); i++) {
                row = arguments.rows[i];
                image = getBridgeImageAsset(row, arguments.basePath);
                item = duplicate(row);
                item["url"] = buildPublicBridgeUrl(row.slug, arguments.basePath);
                item["image"] = image;
                item["has_coordinates"] = isNumeric(row.latitude) AND isNumeric(row.longitude);
                item["air_draft_concern"] = isAirDraftConcern(row);
                arrayAppend(out, item);
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="buildSummary" access="private" returntype="struct" output="false">
        <cfargument name="rows" type="array" required="true">
        <cfscript>
            var out = { "total" = arrayLen(arguments.rows), "markers" = 0 };
            var i = 0;
            for (i = 1; i LTE arrayLen(arguments.rows); i++) {
                if (isNumeric(arguments.rows[i].latitude) AND isNumeric(arguments.rows[i].longitude)) {
                    out.markers++;
                }
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getFacets" access="public" returntype="array" output="false">
        <cfargument name="fieldName" type="string" required="true">
        <cfargument name="filters" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var allowed = "route_segment,route_variant,waterway,state_province,bridge_type,verification_status";
            var facetField = lCase(trim(arguments.fieldName));
            var out = [];
            var q = queryNew("");
            var i = 0;

            if (!hasBridgeSchema() OR !listFindNoCase(allowed, facetField)) {
                return out;
            }

            q = queryExecute(
                "SELECT " & facetField & " AS facet_value, COUNT(*) AS row_count
                 FROM great_loop_bridges
                 WHERE public_status IN ('published','planning_only')
                   AND " & facetField & " IS NOT NULL
                   AND TRIM(" & facetField & ") <> ''
                 GROUP BY " & facetField & "
                 ORDER BY " & facetField & " ASC",
                {},
                { datasource = getDatasource() }
            );
            for (i = 1; i LTE q.recordCount; i++) {
                arrayAppend(out, {
                    "value" = safeString(q.facet_value[i]),
                    "slug" = normalizeSlug(q.facet_value[i]),
                    "count" = val(q.row_count[i])
                });
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="resolveFacetValueBySlug" access="public" returntype="string" output="false">
        <cfargument name="fieldName" type="string" required="true">
        <cfargument name="slug" type="string" required="true">
        <cfscript>
            var target = normalizeSlug(arguments.slug);
            var facets = getFacets(arguments.fieldName);
            var i = 0;

            if (!len(target)) {
                return "";
            }

            for (i = 1; i LTE arrayLen(facets); i++) {
                if (normalizeSlug(facets[i].value) EQ target) {
                    return facets[i].value;
                }
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="getAdminFacet" access="private" returntype="array" output="false">
        <cfargument name="fieldName" type="string" required="true">
        <cfscript>
            var allowed = "route_segment,route_variant,waterway,state_province,bridge_type,verification_status";
            var out = [];
            var q = queryNew("");
            var i = 0;
            if (!hasBridgeSchema() OR !listFindNoCase(allowed, arguments.fieldName)) {
                return out;
            }
            q = queryExecute(
                "SELECT " & arguments.fieldName & " AS facet_value, COUNT(*) AS row_count
                 FROM great_loop_bridges
                 WHERE " & arguments.fieldName & " IS NOT NULL
                   AND TRIM(" & arguments.fieldName & ") <> ''
                 GROUP BY " & arguments.fieldName & "
                 ORDER BY " & arguments.fieldName & " ASC",
                {},
                { datasource = getDatasource() }
            );
            for (i = 1; i LTE q.recordCount; i++) {
                arrayAppend(out, { "value" = safeString(q.facet_value[i]), "count" = val(q.row_count[i]) });
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="facetsToOptions" access="private" returntype="array" output="false">
        <cfargument name="facets" type="array" required="true">
        <cfscript>
            var out = [];
            var i = 0;
            for (i = 1; i LTE arrayLen(arguments.facets); i++) {
                arrayAppend(out, {
                    "value" = arguments.facets[i].value,
                    "label" = arguments.facets[i].value & " (" & arguments.facets[i].count & ")"
                });
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="facetsToAdminOptions" access="private" returntype="array" output="false">
        <cfargument name="facets" type="array" required="true">
        <cfscript>
            return facetsToOptions(arguments.facets);
        </cfscript>
    </cffunction>

    <cffunction name="normalizeFilters" access="public" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var limitValue = val(readAny(arguments.filters, [ "limit", "LIMIT" ], "300"));
            if (limitValue LTE 0) limitValue = 300;
            if (limitValue GT 500) limitValue = 500;
            return {
                "q" = trim(readAny(arguments.filters, [ "q", "Q" ], "")),
                "routeSegment" = trim(readAny(arguments.filters, [ "routeSegment", "route_segment", "ROUTESEGMENT" ], "")),
                "routeVariant" = trim(readAny(arguments.filters, [ "routeVariant", "route_variant", "ROUTEVARIANT" ], "")),
                "waterway" = trim(readAny(arguments.filters, [ "waterway", "WATERWAY" ], "")),
                "stateProvince" = trim(readAny(arguments.filters, [ "stateProvince", "state_province", "state", "STATEPROVINCE" ], "")),
                "bridgeType" = trim(readAny(arguments.filters, [ "bridgeType", "bridge_type", "BRIDGETYPE" ], "")),
                "verificationStatus" = trim(readAny(arguments.filters, [ "verificationStatus", "verification_status", "VERIFICATIONSTATUS" ], "")),
                "publicStatus" = lCase(trim(readAny(arguments.filters, [ "publicStatus", "public_status", "PUBLICSTATUS" ], ""))),
                "drawbridgeOnly" = boolLike(readAny(arguments.filters, [ "drawbridgeOnly", "drawbridge_only", "DRAWBRIDGEONLY" ], ""), false),
                "airDraftConcern" = boolLike(readAny(arguments.filters, [ "airDraftConcern", "air_draft_concern", "AIRDRAFTCONCERN" ], ""), false),
                "hasContact" = boolLike(readAny(arguments.filters, [ "hasContact", "has_contact", "HASCONTACT" ], ""), false),
                "hasCoordinates" = boolLike(readAny(arguments.filters, [ "hasCoordinates", "has_coordinates", "HASCOORDINATES" ], ""), false),
                "limit" = limitValue
            };
        </cfscript>
    </cffunction>

    <cffunction name="normalizeAdminFilters" access="private" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var out = normalizeFilters(arguments.filters);
            out.limit = val(readAny(arguments.filters, [ "limit", "LIMIT" ], "50"));
            out.offset = val(readAny(arguments.filters, [ "offset", "OFFSET" ], "0"));
            if (out.limit LTE 0) out.limit = 50;
            if (out.limit GT 200) out.limit = 200;
            if (out.offset LT 0) out.offset = 0;
            out.missingCoordinates = boolLike(readAny(arguments.filters, [ "missingCoordinates", "missing_coordinates" ], ""), false) ? "1" : "";
            out.missingDrawbridgeContact = boolLike(readAny(arguments.filters, [ "missingDrawbridgeContact", "missing_drawbridge_contact" ], ""), false) ? "1" : "";
            out.missingImage = boolLike(readAny(arguments.filters, [ "missingImage", "missing_image" ], ""), false) ? "1" : "";
            out.imageStatus = lCase(trim(readAny(arguments.filters, [ "imageStatus", "image_status" ], "")));
            if (!listFindNoCase("has_image,no_image", out.imageStatus)) {
                out.imageStatus = "";
            }
            if (!len(out.imageStatus) AND len(out.missingImage)) {
                out.imageStatus = "no_image";
            }
            out.doNotPublish = boolLike(readAny(arguments.filters, [ "doNotPublish", "do_not_publish" ], ""), false) ? "1" : "";
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="buildFilterStruct" access="private" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="true">
        <cfscript>
            return duplicate(arguments.filters);
        </cfscript>
    </cffunction>

    <cffunction name="normalizeBridgePayload" access="public" returntype="struct" output="false">
        <cfargument name="payload" type="struct" required="true">
        <cfscript>
            var row = {};
            var fields = bridgeFields();
            var i = 0;
            var fieldName = "";

            for (i = 1; i LTE arrayLen(fields); i++) {
                fieldName = fields[i];
                row[fieldName] = trimText(readAny(arguments.payload, [ fieldName, uCase(fieldName) ], ""));
            }
            row.id = val(readAny(arguments.payload, [ "id", "ID" ], 0));
            if (!len(row.slug) AND len(row.bridge_name)) {
                row.slug = normalizeSlug(row.bridge_name);
            } else {
                row.slug = normalizeSlug(row.slug);
            }
            row.is_drawbridge = boolLike(row.is_drawbridge, false) ? "1" : "0";
            row.is_fixed = boolLike(row.is_fixed, false) ? "1" : "0";
            row.is_railroad = boolLike(row.is_railroad, false) ? "1" : "0";
            row.image_allowed_for_fpw = boolLike(row.image_allowed_for_fpw, false) ? "1" : "0";
            row.display_priority = isNumeric(row.display_priority) ? int(val(row.display_priority)) : 100;
            row.public_status = lCase(trim(row.public_status));
            if (!listFindNoCase("published,planning_only,admin_review,do_not_publish", row.public_status)) {
                row.public_status = derivePublicStatus(row);
            }
            return row;
        </cfscript>
    </cffunction>

    <cffunction name="validateBridge" access="public" returntype="array" output="false">
        <cfargument name="row" type="struct" required="true">
        <cfargument name="requireId" type="boolean" required="false" default="false">
        <cfscript>
            var errors = [];
            if (arguments.requireId AND val(arguments.row.id) LTE 0) {
                arrayAppend(errors, "Bridge id is required.");
            }
            if (!len(arguments.row.bridge_name)) {
                arrayAppend(errors, "Bridge name is required.");
            }
            if (!len(arguments.row.slug)) {
                arrayAppend(errors, "Slug is required.");
            }
            if (len(arguments.row.latitude) AND (!isNumeric(arguments.row.latitude) OR val(arguments.row.latitude) LT -90 OR val(arguments.row.latitude) GT 90)) {
                arrayAppend(errors, "Latitude must be numeric between -90 and 90.");
            }
            if (len(arguments.row.longitude) AND (!isNumeric(arguments.row.longitude) OR val(arguments.row.longitude) LT -180 OR val(arguments.row.longitude) GT 180)) {
                arrayAppend(errors, "Longitude must be numeric between -180 and 180.");
            }
            validateOptionalDecimal(arguments.row.vertical_clearance_closed_ft, "Closed vertical clearance", errors);
            validateOptionalDecimal(arguments.row.vertical_clearance_open_ft, "Open vertical clearance", errors);
            validateOptionalDecimal(arguments.row.horizontal_clearance_ft, "Horizontal clearance", errors);
            if (len(arguments.row.last_verified_date) AND !isDate(arguments.row.last_verified_date)) {
                arrayAppend(errors, "Last verified date must be a valid date.");
            }
            if (len(arguments.row.source_primary_url) AND !isSafeHttpUrl(arguments.row.source_primary_url)) {
                arrayAppend(errors, "Primary source URL must start with http:// or https://.");
            }
            if (len(arguments.row.source_secondary_url) AND !isSafeHttpUrl(arguments.row.source_secondary_url)) {
                arrayAppend(errors, "Secondary source URL must start with http:// or https://.");
            }
            return errors;
        </cfscript>
    </cffunction>

    <cffunction name="validateOptionalDecimal" access="private" returntype="void" output="false">
        <cfargument name="value" type="any" required="true">
        <cfargument name="label" type="string" required="true">
        <cfargument name="errors" type="array" required="true">
        <cfscript>
            if (len(trim(toString(arguments.value))) AND !isNumeric(arguments.value)) {
                arrayAppend(arguments.errors, arguments.label & " must be numeric.");
            }
        </cfscript>
    </cffunction>

    <cffunction name="bridgeSqlParams" access="public" returntype="struct" output="false">
        <cfargument name="row" type="struct" required="true">
        <cfscript>
            return {
                "id" = { value = val(arguments.row.id), cfsqltype = "cf_sql_bigint" },
                "bridge_id" = nullableParam(arguments.row.bridge_id, "cf_sql_varchar"),
                "bridge_name" = { value = arguments.row.bridge_name, cfsqltype = "cf_sql_varchar" },
                "slug" = { value = arguments.row.slug, cfsqltype = "cf_sql_varchar" },
                "route_segment" = nullableParam(arguments.row.route_segment, "cf_sql_varchar"),
                "route_variant" = nullableParam(arguments.row.route_variant, "cf_sql_varchar"),
                "waterway" = nullableParam(arguments.row.waterway, "cf_sql_varchar"),
                "state_province" = nullableParam(arguments.row.state_province, "cf_sql_varchar"),
                "nearest_city" = nullableParam(arguments.row.nearest_city, "cf_sql_varchar"),
                "mile_marker" = nullableParam(arguments.row.mile_marker, "cf_sql_varchar"),
                "latitude" = nullableDecimal(arguments.row.latitude, 8),
                "longitude" = nullableDecimal(arguments.row.longitude, 8),
                "bridge_type" = nullableParam(arguments.row.bridge_type, "cf_sql_varchar"),
                "is_drawbridge" = { value = val(arguments.row.is_drawbridge), cfsqltype = "cf_sql_tinyint" },
                "is_fixed" = { value = val(arguments.row.is_fixed), cfsqltype = "cf_sql_tinyint" },
                "is_railroad" = { value = val(arguments.row.is_railroad), cfsqltype = "cf_sql_tinyint" },
                "vertical_clearance_closed_ft" = nullableDecimal(arguments.row.vertical_clearance_closed_ft, 2),
                "vertical_clearance_open_ft" = nullableDecimal(arguments.row.vertical_clearance_open_ft, 2),
                "horizontal_clearance_ft" = nullableDecimal(arguments.row.horizontal_clearance_ft, 2),
                "air_draft_notes" = nullableParam(arguments.row.air_draft_notes, "cf_sql_longvarchar"),
                "opening_schedule" = nullableParam(arguments.row.opening_schedule, "cf_sql_longvarchar"),
                "vhf_channel" = nullableParam(arguments.row.vhf_channel, "cf_sql_varchar"),
                "phone" = nullableParam(arguments.row.phone, "cf_sql_varchar"),
                "operator_contact" = nullableParam(arguments.row.operator_contact, "cf_sql_varchar"),
                "navigation_notes" = nullableParam(arguments.row.navigation_notes, "cf_sql_longvarchar"),
                "short_description" = nullableParam(arguments.row.short_description, "cf_sql_longvarchar"),
                "regulatory_notes" = nullableParam(arguments.row.regulatory_notes, "cf_sql_longvarchar"),
                "source_primary_url" = nullableParam(arguments.row.source_primary_url, "cf_sql_longvarchar"),
                "source_secondary_url" = nullableParam(arguments.row.source_secondary_url, "cf_sql_longvarchar"),
                "image_url" = nullableParam(arguments.row.image_url, "cf_sql_longvarchar"),
                "image_source" = nullableParam(arguments.row.image_source, "cf_sql_longvarchar"),
                "image_credit" = nullableParam(arguments.row.image_credit, "cf_sql_longvarchar"),
                "image_license" = nullableParam(arguments.row.image_license, "cf_sql_varchar"),
                "image_allowed_for_fpw" = { value = val(arguments.row.image_allowed_for_fpw), cfsqltype = "cf_sql_tinyint" },
                "local_image_path" = nullableParam(arguments.row.local_image_path, "cf_sql_varchar"),
                "source_confidence" = nullableParam(arguments.row.source_confidence, "cf_sql_varchar"),
                "last_verified_date" = nullableDate(arguments.row.last_verified_date),
                "display_priority" = { value = val(arguments.row.display_priority), cfsqltype = "cf_sql_integer" },
                "verification_status" = nullableParam(arguments.row.verification_status, "cf_sql_varchar"),
                "public_status" = { value = arguments.row.public_status, cfsqltype = "cf_sql_varchar" },
                "admin_notes" = nullableParam(arguments.row.admin_notes, "cf_sql_longvarchar")
            };
        </cfscript>
    </cffunction>

    <cffunction name="bridgeFields" access="private" returntype="array" output="false">
        <cfscript>
            return [
                "bridge_id", "bridge_name", "slug", "route_segment", "route_variant", "waterway",
                "state_province", "nearest_city", "mile_marker", "latitude", "longitude", "bridge_type",
                "is_drawbridge", "is_fixed", "is_railroad", "vertical_clearance_closed_ft",
                "vertical_clearance_open_ft", "horizontal_clearance_ft", "air_draft_notes",
                "opening_schedule", "vhf_channel", "phone", "operator_contact", "navigation_notes",
                "short_description", "regulatory_notes", "source_primary_url", "source_secondary_url",
                "image_url", "image_source", "image_credit", "image_license", "image_allowed_for_fpw",
                "local_image_path", "source_confidence", "last_verified_date", "display_priority",
                "verification_status", "public_status", "admin_notes"
            ];
        </cfscript>
    </cffunction>

    <cffunction name="isAirDraftConcern" access="public" returntype="boolean" output="false">
        <cfargument name="row" type="struct" required="true">
        <cfscript>
            return (isNumeric(arguments.row.vertical_clearance_closed_ft) AND val(arguments.row.vertical_clearance_closed_ft) LTE 65)
                OR len(trim(toString(arguments.row.air_draft_notes))) GT 0;
        </cfscript>
    </cffunction>

    <cffunction name="hasBridgeSchema" access="private" returntype="boolean" output="false">
        <cfscript>
            var q = queryNew("");
            try {
                q = queryExecute(
                    "SELECT COUNT(*) AS found_count
                     FROM information_schema.tables
                     WHERE table_schema = DATABASE()
                       AND table_name = 'great_loop_bridges'",
                    {},
                    { datasource = getDatasource() }
                );
                return q.recordCount AND val(q.found_count[1]) GT 0;
            } catch (any e) {
                return false;
            }
        </cfscript>
    </cffunction>

    <cffunction name="getRepoRootPath" access="private" returntype="string" output="false">
        <cfscript>
            var serviceDir = replace(getDirectoryFromPath(getCurrentTemplatePath()), "\", "/", "all");
            return serviceDir & "../../";
        </cfscript>
    </cffunction>

    <cffunction name="getBridgeImageRootPath" access="private" returntype="string" output="false">
        <cfscript>
            return reReplace(normalizeFilesystemPath(getRepoRootPath() & "assets/images/great-loop-bridges"), "/+$", "", "all");
        </cfscript>
    </cffunction>

    <cffunction name="getBridgeThumbnailRootPath" access="private" returntype="string" output="false">
        <cfscript>
            return joinPath(getBridgeImageRootPath(), "thumbnails");
        </cfscript>
    </cffunction>

    <cffunction name="normalizeBridgeImageRelativePath" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfscript>
            var rel = replace(trim(toString(arguments.value)), "\", "/", "all");
            var fileName = "";

            rel = reReplace(rel, "^/+", "", "all");
            if (!len(rel) OR find("..", rel)) {
                return "";
            }
            if (findNoCase("assets/images/great-loop-bridges/", rel) NEQ 1) {
                rel = "assets/images/great-loop-bridges/" & listLast(rel, "/");
            }

            fileName = listLast(rel, "/");
            if (!isBridgeUploadImageFile(fileName)) {
                return "";
            }
            return "assets/images/great-loop-bridges/" & fileName;
        </cfscript>
    </cffunction>

    <cffunction name="deleteStaleBridgeImages" access="private" returntype="void" output="false">
        <cfargument name="bridgeRow" type="struct" required="true">
        <cfargument name="keepFileName" type="string" required="true">
        <cfscript>
            var imageRoot = getBridgeImageRootPath();
            var thumbnailRoot = getBridgeThumbnailRootPath();
            var slugKey = normalizeSlug(readAny(arguments.bridgeRow, [ "slug", "SLUG" ], ""));
            var localPath = normalizeBridgeImageRelativePath(readAny(arguments.bridgeRow, [ "local_image_path", "LOCAL_IMAGE_PATH" ], ""));
            var extensions = [ "jpg", "jpeg", "png", "webp" ];
            var candidateFiles = [];
            var candidate = "";
            var i = 0;

            if (len(localPath)) {
                arrayAppend(candidateFiles, listLast(localPath, "/"));
            }
            if (len(slugKey)) {
                for (i = 1; i LTE arrayLen(extensions); i++) {
                    candidate = slugKey & "." & extensions[i];
                    if (!arrayFind(candidateFiles, candidate)) {
                        arrayAppend(candidateFiles, candidate);
                    }
                }
            }

            for (i = 1; i LTE arrayLen(candidateFiles); i++) {
                candidate = candidateFiles[i];
                if (compareNoCase(candidate, arguments.keepFileName) EQ 0) {
                    continue;
                }
                deleteImageFileIfSafe(joinPath(imageRoot, candidate), imageRoot);
                deleteImageFileIfSafe(joinPath(thumbnailRoot, candidate), thumbnailRoot);
            }
        </cfscript>
    </cffunction>

    <cffunction name="generateBridgeThumbnail" access="private" returntype="void" output="false">
        <cfargument name="sourcePath" type="string" required="true">
        <cfargument name="thumbnailPath" type="string" required="true">
        <cfscript>
            var thumbImage = imageRead(arguments.sourcePath);
            imageScaleToFit(thumbImage, 480, 320);
            if (fileExists(arguments.thumbnailPath)) {
                fileDelete(arguments.thumbnailPath);
            }
            imageWrite(thumbImage, arguments.thumbnailPath, true);
        </cfscript>
    </cffunction>

    <cffunction name="deleteImageFileIfSafe" access="private" returntype="boolean" output="false">
        <cfargument name="filePath" type="string" required="true">
        <cfargument name="rootPath" type="string" required="true">
        <cfscript>
            var normalizedRoot = reReplace(normalizeFilesystemPath(arguments.rootPath), "/+$", "", "all");
            var normalizedFile = normalizeFilesystemPath(arguments.filePath);
            var fileName = listLast(normalizedFile, "/");

            if (!isBridgeUploadImageFile(fileName)) {
                return false;
            }
            if (findNoCase(normalizedRoot & "/", normalizedFile) NEQ 1) {
                return false;
            }
            if (!fileExists(normalizedFile)) {
                return false;
            }

            fileDelete(normalizedFile);
            return true;
        </cfscript>
    </cffunction>

    <cffunction name="isBridgeUploadImageFile" access="private" returntype="boolean" output="false">
        <cfargument name="fileName" type="string" required="true">
        <cfscript>
            var clean = replace(trim(arguments.fileName), "\", "/", "all");
            var ext = lCase(listLast(clean, "."));

            if (!len(clean) OR find("/", clean) OR find("..", clean)) {
                return false;
            }
            return listFindNoCase("jpg,jpeg,png,webp", ext) GT 0;
        </cfscript>
    </cffunction>

    <cffunction name="ensureDirectory" access="private" returntype="void" output="false">
        <cfargument name="path" type="string" required="true">
        <cfscript>
            if (!directoryExists(arguments.path)) {
                directoryCreate(arguments.path);
            }
        </cfscript>
    </cffunction>

    <cffunction name="joinPath" access="private" returntype="string" output="false">
        <cfargument name="rootPath" type="string" required="true">
        <cfargument name="fileName" type="string" required="true">
        <cfscript>
            return reReplace(normalizeFilesystemPath(arguments.rootPath), "/+$", "", "all") & "/" & reReplace(replace(arguments.fileName, "\", "/", "all"), "^/+", "", "all");
        </cfscript>
    </cffunction>

    <cffunction name="imageUrlWithVersion" access="private" returntype="string" output="false">
        <cfargument name="url" type="string" required="true">
        <cfargument name="filePath" type="string" required="true">
        <cfscript>
            var info = {};
            var versionToken = "";

            try {
                if (fileExists(arguments.filePath)) {
                    info = getFileInfo(arguments.filePath);
                    versionToken = hash(toString(info.size) & ":" & dateTimeFormat(info.lastModified, "yyyymmddHHnnsslll"));
                }
            } catch (any ignored) {
                versionToken = "";
            }

            if (!len(versionToken)) {
                return arguments.url;
            }

            return arguments.url & (find("?", arguments.url) ? "&" : "?") & "v=" & lCase(versionToken);
        </cfscript>
    </cffunction>

    <cffunction name="normalizeFilesystemPath" access="private" returntype="string" output="false">
        <cfargument name="path" type="string" required="true">
        <cfscript>
            var out = replace(arguments.path, "\", "/", "all");
            out = replace(out, "//", "/", "all");
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="readAny" access="private" returntype="string" output="false">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="keys" type="array" required="true">
        <cfargument name="defaultValue" type="any" required="false" default="">
        <cfscript>
            var i = 0;
            for (i = 1; i LTE arrayLen(arguments.keys); i++) {
                if (structKeyExists(arguments.source, arguments.keys[i]) AND !isNull(arguments.source[arguments.keys[i]])) {
                    return toString(arguments.source[arguments.keys[i]]);
                }
            }
            return toString(arguments.defaultValue);
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

    <cffunction name="safeString" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfscript>
            return isNull(arguments.value) ? "" : trimText(arguments.value);
        </cfscript>
    </cffunction>

    <cffunction name="boolLike" access="public" returntype="boolean" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfargument name="defaultValue" type="boolean" required="false" default="false">
        <cfscript>
            var txt = lCase(trimText(arguments.value));
            if (!len(txt)) return arguments.defaultValue;
            if (listFindNoCase("1,true,yes,y,on", txt)) return true;
            if (listFindNoCase("0,false,no,n,off", txt)) return false;
            if (isNumeric(txt)) return val(txt) NEQ 0;
            return arguments.defaultValue;
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

    <cffunction name="nullableDecimal" access="private" returntype="struct" output="false">
        <cfargument name="value" type="any" required="true">
        <cfargument name="scale" type="numeric" required="false" default="2">
        <cfscript>
            var txt = trimText(arguments.value);
            if (!len(txt) OR !isNumeric(txt)) {
                return { "value" = "", "cfsqltype" = "cf_sql_decimal", "scale" = arguments.scale, "null" = true };
            }
            return { "value" = val(txt), "cfsqltype" = "cf_sql_decimal", "scale" = arguments.scale };
        </cfscript>
    </cffunction>

    <cffunction name="nullableDate" access="private" returntype="struct" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            var txt = trimText(arguments.value);
            if (!len(txt) OR !isDate(txt)) {
                return { "value" = "", "cfsqltype" = "cf_sql_date", "null" = true };
            }
            return { "value" = txt, "cfsqltype" = "cf_sql_date" };
        </cfscript>
    </cffunction>

    <cffunction name="isSafeHttpUrl" access="private" returntype="boolean" output="false">
        <cfargument name="value" type="string" required="true">
        <cfscript>
            var txt = lCase(trim(arguments.value));
            return find("http://", txt) EQ 1 OR find("https://", txt) EQ 1;
        </cfscript>
    </cffunction>

    <cffunction name="isDefaultPublicLibraryFilters" access="private" returntype="boolean" output="false">
        <cfargument name="filters" type="struct" required="true">
        <cfscript>
            return !len(arguments.filters.q)
                AND !len(arguments.filters.routeSegment)
                AND !len(arguments.filters.routeVariant)
                AND !len(arguments.filters.waterway)
                AND !len(arguments.filters.stateProvince)
                AND !len(arguments.filters.bridgeType)
                AND !len(arguments.filters.verificationStatus)
                AND !len(arguments.filters.publicStatus)
                AND !arguments.filters.drawbridgeOnly
                AND !arguments.filters.airDraftConcern
                AND !arguments.filters.hasContact
                AND !arguments.filters.hasCoordinates
                AND val(arguments.filters.limit) GTE 500;
        </cfscript>
    </cffunction>

    <cffunction name="buildBridgeLibraryCacheKey" access="private" returntype="string" output="false">
        <cfscript>
            return "fpw:great-loop-bridges:library:v1:" & hash(getDatasource());
        </cfscript>
    </cffunction>

    <cffunction name="getCachedBridgeLibraryModel" access="private" returntype="struct" output="false">
        <cfscript>
            var cached = "";
            try {
                cached = cacheGet(buildBridgeLibraryCacheKey());
            } catch (any cacheError) {
                return {};
            }
            if (isStruct(cached)) {
                return duplicate(cached);
            }
            return {};
        </cfscript>
    </cffunction>

    <cffunction name="putCachedBridgeLibraryModel" access="private" returntype="void" output="false">
        <cfargument name="model" type="struct" required="true">
        <cfscript>
            var ttl = createTimeSpan(0, 1, 0, 0);
            try {
                cachePut(buildBridgeLibraryCacheKey(), duplicate(arguments.model), ttl, ttl);
            } catch (any cacheError) {
            }
        </cfscript>
    </cffunction>

    <cffunction name="getDatasource" access="private" returntype="string" output="false">
        <cfscript>
            return variables.datasource;
        </cfscript>
    </cffunction>

</cfcomponent>
