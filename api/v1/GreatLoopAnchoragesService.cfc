<cfcomponent output="false" hint="Read-only public Great Loop and Eastern U.S. anchorage reference library service.">

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
            var out = {
                "SUCCESS" = true,
                "HAS_SCHEMA" = hasAnchorageSchema(),
                "FILTERS" = buildFilterStruct(normalized),
                "STATS" = getStats(),
                "ANCHORAGES" = [],
                "FACETS" = getFilterOptions(normalized)
            };

            if (isDefaultPublicLibraryFilters(normalized)) {
                cached = getCachedAnchorageLibraryModel();
                if (isStruct(cached) AND structCount(cached) GT 0) {
                    return cached;
                }
            }

            out.ANCHORAGES = searchPublicAnchorages(normalized).ROWS;
            if (out.SUCCESS AND out.HAS_SCHEMA AND isDefaultPublicLibraryFilters(normalized)) {
                putCachedAnchorageLibraryModel(out);
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="clearAnchorageLibraryCache" access="public" returntype="void" output="false">
        <cfscript>
            try {
                cacheRemove(buildAnchorageLibraryCacheKey());
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
            out["locationGroups"] = facetsToOptions(getFacets("location_group", normalized));
            out["waterways"] = facetsToOptions(getFacets("waterway", normalized));
            out["states"] = facetsToOptions(getFacets("state_province", normalized));
            out["countries"] = facetsToOptions(getFacets("country", normalized));
            out["anchorageTypes"] = facetsToOptions(getFacets("anchorage_type", normalized));
            out["publicStatuses"] = facetsToOptions(getFacets("public_status", normalized));
            out["message"] = "";
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getAnchoragesApiModel" access="public" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="false" default="#structNew()#">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var normalized = normalizeFilters(arguments.filters);
            var result = searchPublicAnchorages(normalized);
            var out = structNew("ordered");

            out["success"] = result.SUCCESS;
            out["filters"] = buildFilterStruct(normalized);
            out["summary"] = buildSummary(result.ROWS);
            out["anchorages"] = anchoragesToApiRows(result.ROWS, arguments.basePath);
            out["message"] = "";
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getAdminFacets" access="public" returntype="struct" output="false">
        <cfscript>
            var out = structNew("ordered");

            out["locationGroups"] = getAdminFacetOptions("location_group");
            out["waterways"] = getAdminFacetOptions("waterway");
            out["states"] = getAdminFacetOptions("state_province");
            out["countries"] = getAdminFacetOptions("country");
            out["anchorageTypes"] = getAdminFacetOptions("anchorage_type");
            out["publicStatuses"] = getAdminFacetOptions("public_status");
            out["verificationStatuses"] = getAdminFacetOptions("verification_status");
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="searchAdminAnchorages" access="public" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="false" default="#structNew()#">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var normalized = normalizeAdminFilters(arguments.filters);
            var out = {
                "SUCCESS" = true,
                "ROWS" = [],
                "TOTAL" = 0,
                "LIMIT" = normalized.limit,
                "OFFSET" = normalized.offset,
                "FILTERS" = buildAdminFilterStruct(normalized)
            };
            var conditions = [ "1=1" ];
            var params = {};
            var sql = "";
            var q = queryNew("");
            var i = 0;
            var startIndex = 0;
            var endIndex = 0;
            var row = {};

            if (!hasAnchorageSchema()) {
                out.SUCCESS = false;
                out.MESSAGE = "Great Loop anchorage table is not available.";
                return out;
            }

            if (len(normalized.q)) {
                arrayAppend(conditions, "(
                    anchorage_id LIKE :q
                    OR slug LIKE :q
                    OR anchorage_name LIKE :q
                    OR COALESCE(nearest_city, '') LIKE :q
                    OR COALESCE(state_province, '') LIKE :q
                    OR COALESCE(country, '') LIKE :q
                    OR COALESCE(location_group, '') LIKE :q
                    OR COALESCE(waterway, '') LIKE :q
                    OR COALESCE(anchorage_type, '') LIKE :q
                    OR COALESCE(public_status, '') LIKE :q
                    OR COALESCE(verification_status, '') LIKE :q
                    OR COALESCE(holding, '') LIKE :q
                    OR COALESCE(protection, '') LIKE :q
                    OR COALESCE(shore_access, '') LIKE :q
                    OR COALESCE(notes, '') LIKE :q
                    OR COALESCE(reviewer_notes, '') LIKE :q
                    OR COALESCE(nav_warning, '') LIKE :q
                )");
                params.q = { value = "%" & normalized.q & "%", cfsqltype = "cf_sql_varchar" };
            }
            if (len(normalized.locationGroup)) {
                arrayAppend(conditions, "location_group = :locationGroup");
                params.locationGroup = { value = normalized.locationGroup, cfsqltype = "cf_sql_varchar" };
            }
            if (len(normalized.waterway)) {
                arrayAppend(conditions, "waterway = :waterway");
                params.waterway = { value = normalized.waterway, cfsqltype = "cf_sql_varchar" };
            }
            if (len(normalized.stateProvince)) {
                arrayAppend(conditions, "state_province = :stateProvince");
                params.stateProvince = { value = normalized.stateProvince, cfsqltype = "cf_sql_varchar" };
            }
            if (len(normalized.country)) {
                arrayAppend(conditions, "country = :country");
                params.country = { value = normalized.country, cfsqltype = "cf_sql_varchar" };
            }
            if (len(normalized.anchorageType)) {
                arrayAppend(conditions, "anchorage_type = :anchorageType");
                params.anchorageType = { value = normalized.anchorageType, cfsqltype = "cf_sql_varchar" };
            }
            if (len(normalized.publicStatus)) {
                arrayAppend(conditions, "public_status = :publicStatus");
                params.publicStatus = { value = normalized.publicStatus, cfsqltype = "cf_sql_varchar" };
            }
            if (len(normalized.verificationStatus)) {
                arrayAppend(conditions, "verification_status = :verificationStatus");
                params.verificationStatus = { value = normalized.verificationStatus, cfsqltype = "cf_sql_varchar" };
            }

            sql = buildSelectSql() & "
                FROM greatLoop_anchorages
                WHERE " & arrayToList(conditions, " AND ") & "
                ORDER BY location_group ASC, waterway ASC, anchorage_name ASC, anchorage_id ASC
                LIMIT 1000";

            q = queryExecute(sql, params, { datasource = getDatasource() });
            out.TOTAL = q.recordCount;
            startIndex = normalized.offset + 1;
            endIndex = min(normalized.offset + normalized.limit, out.TOTAL);
            if (startIndex LTE endIndex) {
                for (i = startIndex; i LTE endIndex; i++) {
                    row = rowToStruct(q, i);
                    row["url"] = buildPublicAnchorageUrl(row.slug, arguments.basePath);
                    arrayAppend(out.ROWS, row);
                }
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getAdminAnchorageById" access="public" returntype="struct" output="false">
        <cfargument name="anchorageId" type="string" required="true">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var out = { "SUCCESS" = false, "ANCHORAGE" = {} };
            var q = queryNew("");
            var row = {};
            var idValue = normalizeAnchorageId(arguments.anchorageId);

            if (!hasAnchorageSchema() OR !len(idValue)) {
                out.MESSAGE = "Anchorage not found.";
                return out;
            }

            q = queryExecute(
                buildSelectSql() & "
                 FROM greatLoop_anchorages
                 WHERE anchorage_id = :anchorageId
                 LIMIT 1",
                { anchorageId = { value = idValue, cfsqltype = "cf_sql_varchar" } },
                { datasource = getDatasource() }
            );

            if (q.recordCount EQ 0) {
                out.MESSAGE = "Anchorage not found.";
                return out;
            }

            row = rowToStruct(q, 1);
            row["url"] = buildPublicAnchorageUrl(row.slug, arguments.basePath);
            out.SUCCESS = true;
            out.ANCHORAGE = row;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="createAdminAnchorage" access="public" returntype="struct" output="false">
        <cfargument name="anchorageData" type="struct" required="true">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var payloadResult = normalizeAdminAnchoragePayload(arguments.anchorageData, false);
            var payload = payloadResult.DATA;
            var out = { "SUCCESS" = false, "ANCHORAGE" = {}, "ERRORS" = payloadResult.ERRORS };
            var attempt = 0;
            var savedResult = {};

            if (arrayLen(out.ERRORS)) {
                out.MESSAGE = "Validation failed.";
                return out;
            }
            if (!hasAnchorageSchema()) {
                out.MESSAGE = "Great Loop anchorage table is not available.";
                arrayAppend(out.ERRORS, out.MESSAGE);
                return out;
            }
            if (!isAnchorageSlugAvailable(payload.slug, "")) {
                out.MESSAGE = "Validation failed.";
                arrayAppend(out.ERRORS, "Slug is already used by another anchorage.");
                return out;
            }

            for (attempt = 0; attempt LT 5; attempt++) {
                payload.anchorage_id = generateNextAnchorageId(attempt);
                if (!isAnchorageIdAvailable(payload.anchorage_id)) {
                    continue;
                }

                try {
                    queryExecute(
                        "INSERT INTO greatLoop_anchorages (
                            anchorage_id, slug, location_group, waterway, state_province, country,
                            nearest_city, anchorage_name, latitude, longitude, anchorage_type,
                            public_status, holding, protection, shore_access, notes, source_name,
                            source_url, verification_status, great_loop_relevance, nav_warning,
                            duplicate_review_note, last_reviewed, is_published, reviewed_by,
                            reviewed_at, reviewer_notes
                         ) VALUES (
                            :anchorageId, :slug, :locationGroup, :waterway, :stateProvince, :country,
                            :nearestCity, :anchorageName, :latitude, :longitude, :anchorageType,
                            :publicStatus, :holding, :protection, :shoreAccess, :notes, :sourceName,
                            :sourceUrl, :verificationStatus, :greatLoopRelevance, :navWarning,
                            :duplicateReviewNote, :lastReviewed, :isPublished, :reviewedBy,
                            :reviewedAt, :reviewerNotes
                         )",
                        buildAdminAnchorageParams(payload),
                        { datasource = getDatasource() }
                    );
                    clearAnchorageLibraryCache();
                    savedResult = getAdminAnchorageById(payload.anchorage_id, arguments.basePath);
                    if (savedResult.SUCCESS) {
                        out.SUCCESS = true;
                        out.MESSAGE = "Anchorage created.";
                        out.ANCHORAGE = savedResult.ANCHORAGE;
                        return out;
                    }
                } catch (any insertError) {
                    if (findNoCase("Duplicate", insertError.message) EQ 0) {
                        rethrow;
                    }
                }
            }

            out.MESSAGE = "Unable to create anchorage id.";
            arrayAppend(out.ERRORS, out.MESSAGE);
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="updateAdminAnchorage" access="public" returntype="struct" output="false">
        <cfargument name="anchorageData" type="struct" required="true">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var payloadResult = normalizeAdminAnchoragePayload(arguments.anchorageData, true);
            var payload = payloadResult.DATA;
            var out = { "SUCCESS" = false, "ANCHORAGE" = {}, "ERRORS" = payloadResult.ERRORS };
            var existingResult = {};
            var savedResult = {};
            var params = {};

            if (arrayLen(out.ERRORS)) {
                out.MESSAGE = "Validation failed.";
                return out;
            }

            existingResult = getAdminAnchorageById(payload.anchorage_id, arguments.basePath);
            if (!existingResult.SUCCESS) {
                out.MESSAGE = "Anchorage not found.";
                arrayAppend(out.ERRORS, "Anchorage not found.");
                return out;
            }
            if (!isAnchorageSlugAvailable(payload.slug, payload.anchorage_id)) {
                out.MESSAGE = "Validation failed.";
                arrayAppend(out.ERRORS, "Slug is already used by another anchorage.");
                return out;
            }

            params = buildAdminAnchorageParams(payload);
            queryExecute(
                "UPDATE greatLoop_anchorages
                 SET slug = :slug,
                     location_group = :locationGroup,
                     waterway = :waterway,
                     state_province = :stateProvince,
                     country = :country,
                     nearest_city = :nearestCity,
                     anchorage_name = :anchorageName,
                     latitude = :latitude,
                     longitude = :longitude,
                     anchorage_type = :anchorageType,
                     public_status = :publicStatus,
                     holding = :holding,
                     protection = :protection,
                     shore_access = :shoreAccess,
                     notes = :notes,
                     source_name = :sourceName,
                     source_url = :sourceUrl,
                     verification_status = :verificationStatus,
                     great_loop_relevance = :greatLoopRelevance,
                     nav_warning = :navWarning,
                     duplicate_review_note = :duplicateReviewNote,
                     last_reviewed = :lastReviewed,
                     is_published = :isPublished,
                     reviewed_by = :reviewedBy,
                     reviewed_at = :reviewedAt,
                     reviewer_notes = :reviewerNotes
                 WHERE anchorage_id = :anchorageId",
                params,
                { datasource = getDatasource() }
            );

            clearAnchorageLibraryCache();
            savedResult = getAdminAnchorageById(payload.anchorage_id, arguments.basePath);
            if (savedResult.SUCCESS) {
                out.SUCCESS = true;
                out.MESSAGE = "Anchorage saved.";
                out.ANCHORAGE = savedResult.ANCHORAGE;
            } else {
                out.MESSAGE = "Anchorage saved, but the updated row could not be reloaded.";
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="deleteAdminAnchorage" access="public" returntype="struct" output="false">
        <cfargument name="anchorageId" type="string" required="true">
        <cfscript>
            var idValue = normalizeAnchorageId(arguments.anchorageId);
            var out = { "SUCCESS" = false, "ANCHORAGE_ID" = idValue };
            var existingResult = {};

            if (!len(idValue)) {
                out.MESSAGE = "Anchorage id is required.";
                return out;
            }

            existingResult = getAdminAnchorageById(idValue);
            if (!existingResult.SUCCESS) {
                out.MESSAGE = "Anchorage not found.";
                return out;
            }

            queryExecute(
                "DELETE FROM greatLoop_anchorages
                 WHERE anchorage_id = :anchorageId",
                { anchorageId = { value = idValue, cfsqltype = "cf_sql_varchar" } },
                { datasource = getDatasource() }
            );

            clearAnchorageLibraryCache();
            out.SUCCESS = true;
            out.MESSAGE = "Anchorage deleted.";
            out.ANCHORAGE = existingResult.ANCHORAGE;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="searchPublicAnchorages" access="public" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var normalized = normalizeFilters(arguments.filters);
            var out = { "SUCCESS" = true, "ROWS" = [], "COUNT" = 0 };
            var sqlParts = buildAnchorageSearchSql(normalized);
            var q = queryNew("");
            var i = 0;

            if (!hasAnchorageSchema()) {
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

    <cffunction name="getAnchorageBySlug" access="public" returntype="struct" output="false">
        <cfargument name="slug" type="string" required="true">
        <cfscript>
            var out = { "SUCCESS" = false, "ANCHORAGE" = {}, "PREVIOUS" = {}, "NEXT" = {}, "NEARBY" = [] };
            var q = queryNew("");
            var slugValue = normalizeSlug(arguments.slug);
            var nav = {};

            if (!hasAnchorageSchema() OR !len(slugValue)) {
                out.MESSAGE = "Anchorage not found.";
                return out;
            }

            q = queryExecute(
                buildSelectSql() & "
                 FROM greatLoop_anchorages
                 WHERE is_published = 1
                   AND slug = :slug
                 LIMIT 1",
                { slug = { value = slugValue, cfsqltype = "cf_sql_varchar" } },
                { datasource = getDatasource() }
            );

            if (!q.recordCount) {
                out.MESSAGE = "Anchorage not found.";
                return out;
            }

            out.SUCCESS = true;
            out.ANCHORAGE = rowToStruct(q, 1);
            nav = getAdjacentAnchorages(out.ANCHORAGE.slug);
            out.PREVIOUS = nav.PREVIOUS;
            out.NEXT = nav.NEXT;
            out.NEARBY = getNearbyAnchorages(out.ANCHORAGE, 4);
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getLocationGroupModel" access="public" returntype="struct" output="false">
        <cfargument name="slug" type="string" required="true">
        <cfscript>
            var value = resolveFacetValueBySlug("location_group", arguments.slug);
            var out = { "SUCCESS" = false, "LOCATION_GROUP" = value, "ANCHORAGES" = [], "STATS" = getStats() };
            if (!len(value)) {
                out.MESSAGE = "Location group not found.";
                return out;
            }
            out.ANCHORAGES = searchPublicAnchorages({ "locationGroup" = value, "limit" = 500 }).ROWS;
            out.SUCCESS = true;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getWaterwayModel" access="public" returntype="struct" output="false">
        <cfargument name="slug" type="string" required="true">
        <cfscript>
            var value = resolveFacetValueBySlug("waterway", arguments.slug);
            var out = { "SUCCESS" = false, "WATERWAY" = value, "ANCHORAGES" = [], "STATS" = getStats() };
            if (!len(value)) {
                out.MESSAGE = "Waterway not found.";
                return out;
            }
            out.ANCHORAGES = searchPublicAnchorages({ "waterway" = value, "limit" = 500 }).ROWS;
            out.SUCCESS = true;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getStateModel" access="public" returntype="struct" output="false">
        <cfargument name="slug" type="string" required="true">
        <cfscript>
            var value = resolveFacetValueBySlug("state_province", arguments.slug);
            var out = { "SUCCESS" = false, "STATE" = value, "ANCHORAGES" = [], "STATS" = getStats() };
            if (!len(value)) {
                out.MESSAGE = "State or province not found.";
                return out;
            }
            out.ANCHORAGES = searchPublicAnchorages({ "stateProvince" = value, "limit" = 500 }).ROWS;
            out.SUCCESS = true;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getCountryModel" access="public" returntype="struct" output="false">
        <cfargument name="slug" type="string" required="true">
        <cfscript>
            var value = resolveFacetValueBySlug("country", arguments.slug);
            var out = { "SUCCESS" = false, "COUNTRY" = value, "ANCHORAGES" = [], "STATS" = getStats() };
            if (!len(value)) {
                out.MESSAGE = "Country not found.";
                return out;
            }
            out.ANCHORAGES = searchPublicAnchorages({ "country" = value, "limit" = 500 }).ROWS;
            out.SUCCESS = true;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getTypeModel" access="public" returntype="struct" output="false">
        <cfargument name="slug" type="string" required="true">
        <cfscript>
            var value = resolveFacetValueBySlug("anchorage_type", arguments.slug);
            var out = { "SUCCESS" = false, "ANCHORAGE_TYPE" = value, "ANCHORAGES" = [], "STATS" = getStats() };
            if (!len(value)) {
                out.MESSAGE = "Anchorage type not found.";
                return out;
            }
            out.ANCHORAGES = searchPublicAnchorages({ "anchorageType" = value, "limit" = 500 }).ROWS;
            out.SUCCESS = true;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getStats" access="public" returntype="struct" output="false">
        <cfscript>
            var out = {
                "TOTAL_ROWS" = 0,
                "PUBLIC_ROWS" = 0,
                "LOCATION_GROUP_COUNT" = 0,
                "WATERWAY_COUNT" = 0,
                "STATE_COUNT" = 0,
                "COUNTRY_COUNT" = 0,
                "TYPE_COUNT" = 0,
                "MARKER_COUNT" = 0
            };
            var q = queryNew("");

            if (!hasAnchorageSchema()) {
                return out;
            }

            q = queryExecute(
                "SELECT
                    COUNT(*) AS total_rows,
                    SUM(CASE WHEN is_published = 1 AND slug IS NOT NULL AND TRIM(slug) <> '' THEN 1 ELSE 0 END) AS public_rows,
                    COUNT(DISTINCT CASE WHEN is_published = 1 AND slug IS NOT NULL AND TRIM(slug) <> '' THEN NULLIF(TRIM(location_group), '') END) AS location_group_count,
                    COUNT(DISTINCT CASE WHEN is_published = 1 AND slug IS NOT NULL AND TRIM(slug) <> '' THEN NULLIF(TRIM(waterway), '') END) AS waterway_count,
                    COUNT(DISTINCT CASE WHEN is_published = 1 AND slug IS NOT NULL AND TRIM(slug) <> '' THEN NULLIF(TRIM(state_province), '') END) AS state_count,
                    COUNT(DISTINCT CASE WHEN is_published = 1 AND slug IS NOT NULL AND TRIM(slug) <> '' THEN NULLIF(TRIM(country), '') END) AS country_count,
                    COUNT(DISTINCT CASE WHEN is_published = 1 AND slug IS NOT NULL AND TRIM(slug) <> '' THEN NULLIF(TRIM(anchorage_type), '') END) AS type_count,
                    SUM(CASE WHEN is_published = 1 AND slug IS NOT NULL AND TRIM(slug) <> '' AND latitude IS NOT NULL AND longitude IS NOT NULL THEN 1 ELSE 0 END) AS marker_count
                 FROM greatLoop_anchorages",
                {},
                { datasource = getDatasource() }
            );

            if (q.recordCount) {
                out.TOTAL_ROWS = val(q.total_rows[1]);
                out.PUBLIC_ROWS = val(q.public_rows[1]);
                out.LOCATION_GROUP_COUNT = val(q.location_group_count[1]);
                out.WATERWAY_COUNT = val(q.waterway_count[1]);
                out.STATE_COUNT = val(q.state_count[1]);
                out.COUNTRY_COUNT = val(q.country_count[1]);
                out.TYPE_COUNT = val(q.type_count[1]);
                out.MARKER_COUNT = val(q.marker_count[1]);
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getFacets" access="public" returntype="array" output="false">
        <cfargument name="fieldName" type="string" required="true">
        <cfargument name="filters" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var allowed = "location_group,waterway,state_province,country,anchorage_type,public_status,verification_status";
            var facetField = lCase(trim(arguments.fieldName));
            var out = [];
            var q = queryNew("");
            var i = 0;

            if (!hasAnchorageSchema() OR !listFindNoCase(allowed, facetField)) {
                return out;
            }

            q = queryExecute(
                "SELECT " & facetField & " AS facet_value, COUNT(*) AS row_count
                 FROM greatLoop_anchorages
                 WHERE is_published = 1
                   AND slug IS NOT NULL
                   AND TRIM(slug) <> ''
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

    <cffunction name="getAdminFacetOptions" access="private" returntype="array" output="false">
        <cfargument name="fieldName" type="string" required="true">
        <cfscript>
            var allowed = "location_group,waterway,state_province,country,anchorage_type,public_status,verification_status";
            var facetField = lCase(trim(arguments.fieldName));
            var out = [];
            var q = queryNew("");
            var i = 0;

            if (!listFindNoCase(allowed, facetField) OR !hasAnchorageSchema()) {
                return out;
            }

            q = queryExecute(
                "SELECT " & facetField & " AS facet_value, COUNT(*) AS row_count
                 FROM greatLoop_anchorages
                 WHERE " & facetField & " IS NOT NULL
                   AND TRIM(" & facetField & ") <> ''
                 GROUP BY " & facetField & "
                 ORDER BY " & facetField & " ASC
                 LIMIT 500",
                {},
                { datasource = getDatasource() }
            );

            for (i = 1; i LTE q.recordCount; i++) {
                arrayAppend(out, {
                    "value" = safeString(q.facet_value[i]),
                    "label" = safeString(q.facet_value[i]) & " (" & val(q.row_count[i]) & ")",
                    "slug" = normalizeSlug(q.facet_value[i]),
                    "count" = val(q.row_count[i])
                });
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
            return left(slug, 180);
        </cfscript>
    </cffunction>

    <cffunction name="buildPublicAnchorageUrl" access="public" returntype="string" output="false">
        <cfargument name="slug" type="string" required="true">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var base = trim(arguments.basePath);
            var slugValue = normalizeSlug(arguments.slug);
            base = reReplace(base, "/$", "");
            if (isLocalDevRequest()) {
                return base & "/great-loop/anchorages/index.cfm?slug=" & urlEncodedFormat(slugValue);
            }
            return base & "/great-loop/anchorages/" & slugValue & "/";
        </cfscript>
    </cffunction>

    <cffunction name="isLocalDevRequest" access="private" returntype="boolean" output="false">
        <cfscript>
            var hostName = "";
            if (structKeyExists(cgi, "http_host")) {
                hostName = lCase(trim(toString(cgi.http_host)));
            } else if (structKeyExists(cgi, "server_name")) {
                hostName = lCase(trim(toString(cgi.server_name)));
            }
            return hostName EQ "localhost"
                OR left(hostName, 10) EQ "localhost:"
                OR hostName EQ "127.0.0.1"
                OR left(hostName, 10) EQ "127.0.0.1:"
                OR hostName EQ "[::1]"
                OR left(hostName, 6) EQ "[::1]:";
        </cfscript>
    </cffunction>

    <cffunction name="getDatasource" access="private" returntype="string" output="false">
        <cfscript>
            return variables.datasource;
        </cfscript>
    </cffunction>

    <cffunction name="hasAnchorageSchema" access="private" returntype="boolean" output="false">
        <cfscript>
            try {
                queryExecute("SELECT COUNT(*) AS row_count FROM greatLoop_anchorages WHERE 1 = 0", {}, { datasource = getDatasource() });
                return true;
            } catch (any schemaError) {
                return false;
            }
        </cfscript>
    </cffunction>

    <cffunction name="buildAnchorageSearchSql" access="private" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="true">
        <cfscript>
            var conditions = [ "is_published = 1", "slug IS NOT NULL", "TRIM(slug) <> ''" ];
            var params = {};
            var maxRows = val(arguments.filters.limit);
            var sql = "";

            if (maxRows LTE 0 OR maxRows GT 500) {
                maxRows = 300;
            }

            if (len(arguments.filters.q)) {
                arrayAppend(conditions, "(
                    anchorage_name LIKE :q
                    OR COALESCE(nearest_city, '') LIKE :q
                    OR COALESCE(state_province, '') LIKE :q
                    OR COALESCE(country, '') LIKE :q
                    OR COALESCE(location_group, '') LIKE :q
                    OR COALESCE(waterway, '') LIKE :q
                    OR COALESCE(anchorage_type, '') LIKE :q
                    OR COALESCE(public_status, '') LIKE :q
                    OR COALESCE(holding, '') LIKE :q
                    OR COALESCE(protection, '') LIKE :q
                    OR COALESCE(shore_access, '') LIKE :q
                    OR COALESCE(notes, '') LIKE :q
                )");
                params.q = { value = "%" & arguments.filters.q & "%", cfsqltype = "cf_sql_varchar" };
            }
            if (len(arguments.filters.locationGroup)) {
                arrayAppend(conditions, "location_group = :locationGroup");
                params.locationGroup = { value = arguments.filters.locationGroup, cfsqltype = "cf_sql_varchar" };
            }
            if (len(arguments.filters.waterway)) {
                arrayAppend(conditions, "waterway = :waterway");
                params.waterway = { value = arguments.filters.waterway, cfsqltype = "cf_sql_varchar" };
            }
            if (len(arguments.filters.stateProvince)) {
                arrayAppend(conditions, "state_province = :stateProvince");
                params.stateProvince = { value = arguments.filters.stateProvince, cfsqltype = "cf_sql_varchar" };
            }
            if (len(arguments.filters.country)) {
                arrayAppend(conditions, "country = :country");
                params.country = { value = arguments.filters.country, cfsqltype = "cf_sql_varchar" };
            }
            if (len(arguments.filters.anchorageType)) {
                arrayAppend(conditions, "anchorage_type = :anchorageType");
                params.anchorageType = { value = arguments.filters.anchorageType, cfsqltype = "cf_sql_varchar" };
            }
            if (len(arguments.filters.publicStatus)) {
                arrayAppend(conditions, "public_status = :publicStatus");
                params.publicStatus = { value = arguments.filters.publicStatus, cfsqltype = "cf_sql_varchar" };
            }

            sql = buildSelectSql() & "
                FROM greatLoop_anchorages
                WHERE " & arrayToList(conditions, " AND ") & "
                ORDER BY location_group ASC, waterway ASC, anchorage_name ASC
                LIMIT :limitRows";
            params.limitRows = { value = maxRows, cfsqltype = "cf_sql_integer" };

            return { "sql" = sql, "params" = params };
        </cfscript>
    </cffunction>

    <cffunction name="buildSelectSql" access="private" returntype="string" output="false">
        <cfscript>
            return "SELECT
                anchorage_id,
                slug,
                location_group,
                waterway,
                state_province,
                country,
                nearest_city,
                anchorage_name,
                latitude,
                longitude,
                anchorage_type,
                public_status,
                holding,
                protection,
                shore_access,
                notes,
                source_name,
                source_url,
                verification_status,
                great_loop_relevance,
                nav_warning,
                duplicate_review_note,
                DATE_FORMAT(last_reviewed, '%Y-%m-%d') AS last_reviewed,
                is_published,
                reviewed_by,
                DATE_FORMAT(reviewed_at, '%Y-%m-%d %H:%i:%s') AS reviewed_at,
                reviewer_notes";
        </cfscript>
    </cffunction>

    <cffunction name="rowToStruct" access="private" returntype="struct" output="false">
        <cfargument name="q" type="query" required="true">
        <cfargument name="rowIndex" type="numeric" required="true">
        <cfscript>
            var row = arguments.rowIndex;
            var out = structNew("ordered");
            out["anchorage_id"] = safeString(arguments.q.anchorage_id[row]);
            out["slug"] = normalizeSlug(arguments.q.slug[row]);
            out["location_group"] = safeString(arguments.q.location_group[row]);
            out["waterway"] = safeString(arguments.q.waterway[row]);
            out["state_province"] = safeString(arguments.q.state_province[row]);
            out["country"] = safeString(arguments.q.country[row]);
            out["nearest_city"] = safeString(arguments.q.nearest_city[row]);
            out["anchorage_name"] = safeString(arguments.q.anchorage_name[row]);
            out["latitude"] = isNumeric(arguments.q.latitude[row]) ? val(arguments.q.latitude[row]) : "";
            out["longitude"] = isNumeric(arguments.q.longitude[row]) ? val(arguments.q.longitude[row]) : "";
            out["anchorage_type"] = safeString(arguments.q.anchorage_type[row]);
            out["public_status"] = safeString(arguments.q.public_status[row]);
            out["holding"] = safeString(arguments.q.holding[row]);
            out["protection"] = safeString(arguments.q.protection[row]);
            out["shore_access"] = safeString(arguments.q.shore_access[row]);
            out["notes"] = safeString(arguments.q.notes[row]);
            out["source_name"] = safeString(arguments.q.source_name[row]);
            out["source_url"] = safeString(arguments.q.source_url[row]);
            out["verification_status"] = safeString(arguments.q.verification_status[row]);
            out["great_loop_relevance"] = safeString(arguments.q.great_loop_relevance[row]);
            out["nav_warning"] = safeString(arguments.q.nav_warning[row]);
            out["duplicate_review_note"] = safeString(arguments.q.duplicate_review_note[row]);
            out["last_reviewed"] = safeString(arguments.q.last_reviewed[row]);
            out["is_published"] = val(arguments.q.is_published[row]);
            out["reviewed_by"] = safeString(arguments.q.reviewed_by[row]);
            out["reviewed_at"] = safeString(arguments.q.reviewed_at[row]);
            out["reviewer_notes"] = safeString(arguments.q.reviewer_notes[row]);
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="anchoragesToApiRows" access="private" returntype="array" output="false">
        <cfargument name="rows" type="array" required="true">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var out = [];
            var item = {};
            var row = {};

            for (row in arguments.rows) {
                item = duplicate(row);
                item["url"] = buildPublicAnchorageUrl(row.slug, arguments.basePath);
                arrayAppend(out, item);
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="buildSummary" access="private" returntype="struct" output="false">
        <cfargument name="rows" type="array" required="true">
        <cfscript>
            var out = structNew("ordered");
            var markerCount = 0;
            var row = {};

            for (row in arguments.rows) {
                if (isNumeric(row.latitude) AND isNumeric(row.longitude)) {
                    markerCount++;
                }
            }
            out["total"] = arrayLen(arguments.rows);
            out["markers"] = markerCount;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="facetsToOptions" access="private" returntype="array" output="false">
        <cfargument name="facets" type="array" required="true">
        <cfscript>
            var out = [];
            var facet = {};
            for (facet in arguments.facets) {
                arrayAppend(out, {
                    "value" = facet.value,
                    "label" = facet.value & " (" & facet.count & ")",
                    "slug" = facet.slug,
                    "count" = facet.count
                });
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeFilters" access="public" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="false" default="#structNew()#">
        <cfscript>
            return {
                "q" = left(trim(safeGet(arguments.filters, "q")), 140),
                "locationGroup" = left(trim(safeGet(arguments.filters, "locationGroup")), 180),
                "waterway" = left(trim(safeGet(arguments.filters, "waterway")), 180),
                "stateProvince" = left(trim(safeGet(arguments.filters, "stateProvince")), 40),
                "country" = left(trim(safeGet(arguments.filters, "country")), 80),
                "anchorageType" = left(trim(safeGet(arguments.filters, "anchorageType")), 180),
                "publicStatus" = left(trim(safeGet(arguments.filters, "publicStatus")), 180),
                "limit" = val(safeGet(arguments.filters, "limit", "300"))
            };
        </cfscript>
    </cffunction>

    <cffunction name="buildFilterStruct" access="private" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="true">
        <cfscript>
            var out = structNew("ordered");
            out["q"] = arguments.filters.q;
            out["locationGroup"] = arguments.filters.locationGroup;
            out["waterway"] = arguments.filters.waterway;
            out["stateProvince"] = arguments.filters.stateProvince;
            out["country"] = arguments.filters.country;
            out["anchorageType"] = arguments.filters.anchorageType;
            out["publicStatus"] = arguments.filters.publicStatus;
            out["limit"] = arguments.filters.limit;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="isDefaultPublicLibraryFilters" access="private" returntype="boolean" output="false">
        <cfargument name="filters" type="struct" required="true">
        <cfscript>
            return !len(arguments.filters.q)
                AND !len(arguments.filters.locationGroup)
                AND !len(arguments.filters.waterway)
                AND !len(arguments.filters.stateProvince)
                AND !len(arguments.filters.country)
                AND !len(arguments.filters.anchorageType)
                AND !len(arguments.filters.publicStatus)
                AND val(arguments.filters.limit) EQ 300;
        </cfscript>
    </cffunction>

    <cffunction name="buildAnchorageLibraryCacheKey" access="private" returntype="string" output="false">
        <cfscript>
            return "fpw:great-loop-anchorages:library:v1:" & hash(getDatasource());
        </cfscript>
    </cffunction>

    <cffunction name="getCachedAnchorageLibraryModel" access="private" returntype="struct" output="false">
        <cfscript>
            var cached = "";
            try {
                cached = cacheGet(buildAnchorageLibraryCacheKey());
            } catch (any cacheError) {
                return {};
            }
            if (isStruct(cached)) {
                return duplicate(cached);
            }
            return {};
        </cfscript>
    </cffunction>

    <cffunction name="putCachedAnchorageLibraryModel" access="private" returntype="void" output="false">
        <cfargument name="model" type="struct" required="true">
        <cfscript>
            var ttl = createTimeSpan(0, 1, 0, 0);
            try {
                cachePut(buildAnchorageLibraryCacheKey(), duplicate(arguments.model), ttl, ttl);
            } catch (any cacheError) {
            }
        </cfscript>
    </cffunction>

    <cffunction name="normalizeAdminFilters" access="private" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="true">
        <cfscript>
            var limitValue = val(readAny(arguments.filters, ["limit", "LIMIT"], "50"));
            var offsetValue = val(readAny(arguments.filters, ["offset", "OFFSET"], "0"));

            if (limitValue LTE 0) limitValue = 50;
            if (limitValue GT 200) limitValue = 200;
            if (offsetValue LT 0) offsetValue = 0;

            return {
                "q" = left(trim(readAny(arguments.filters, ["q", "Q", "search", "SEARCH"], "")), 140),
                "locationGroup" = left(trim(readAny(arguments.filters, ["locationGroup", "LOCATIONGROUP", "location_group"], "")), 120),
                "waterway" = left(trim(readAny(arguments.filters, ["waterway", "WATERWAY"], "")), 120),
                "stateProvince" = left(trim(readAny(arguments.filters, ["stateProvince", "STATEPROVINCE", "state_province"], "")), 32),
                "country" = left(trim(readAny(arguments.filters, ["country", "COUNTRY"], "")), 64),
                "anchorageType" = left(trim(readAny(arguments.filters, ["anchorageType", "ANCHORAGETYPE", "anchorage_type"], "")), 80),
                "publicStatus" = left(trim(readAny(arguments.filters, ["publicStatus", "PUBLICSTATUS", "public_status"], "")), 80),
                "verificationStatus" = left(trim(readAny(arguments.filters, ["verificationStatus", "VERIFICATIONSTATUS", "verification_status"], "")), 80),
                "limit" = limitValue,
                "offset" = offsetValue
            };
        </cfscript>
    </cffunction>

    <cffunction name="buildAdminFilterStruct" access="private" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="true">
        <cfscript>
            return {
                "q" = arguments.filters.q,
                "locationGroup" = arguments.filters.locationGroup,
                "waterway" = arguments.filters.waterway,
                "stateProvince" = arguments.filters.stateProvince,
                "country" = arguments.filters.country,
                "anchorageType" = arguments.filters.anchorageType,
                "publicStatus" = arguments.filters.publicStatus,
                "verificationStatus" = arguments.filters.verificationStatus,
                "limit" = arguments.filters.limit,
                "offset" = arguments.filters.offset
            };
        </cfscript>
    </cffunction>

    <cffunction name="normalizeAdminAnchoragePayload" access="private" returntype="struct" output="false">
        <cfargument name="payload" type="struct" required="true">
        <cfargument name="requireId" type="boolean" required="true">
        <cfscript>
            var out = { "DATA" = {}, "ERRORS" = [] };
            var sourceUrl = left(trim(readAny(arguments.payload, ["source_url", "SOURCE_URL", "sourceUrl"], "")), 500);
            var lastReviewed = left(trim(readAny(arguments.payload, ["last_reviewed", "LAST_REVIEWED", "lastReviewed"], "")), 10);
            var reviewedAt = left(trim(replace(readAny(arguments.payload, ["reviewed_at", "REVIEWED_AT", "reviewedAt"], ""), "T", " ", "one")), 19);
            var latitudeValue = trim(readAny(arguments.payload, ["latitude", "LATITUDE"], ""));
            var longitudeValue = trim(readAny(arguments.payload, ["longitude", "LONGITUDE"], ""));
            var publishedValue = readAny(arguments.payload, ["is_published", "IS_PUBLISHED", "isPublished"], "0");

            out.DATA = {
                "anchorage_id" = normalizeAnchorageId(readAny(arguments.payload, ["anchorage_id", "ANCHORAGE_ID", "anchorageId", "id", "ID"], "")),
                "slug" = left(normalizeSlug(readAny(arguments.payload, ["slug", "SLUG"], "")), 120),
                "location_group" = left(trim(readAny(arguments.payload, ["location_group", "LOCATION_GROUP", "locationGroup"], "")), 120),
                "waterway" = left(trim(readAny(arguments.payload, ["waterway", "WATERWAY"], "")), 120),
                "state_province" = left(trim(readAny(arguments.payload, ["state_province", "STATE_PROVINCE", "stateProvince"], "")), 32),
                "country" = left(trim(readAny(arguments.payload, ["country", "COUNTRY"], "")), 64),
                "nearest_city" = left(trim(readAny(arguments.payload, ["nearest_city", "NEAREST_CITY", "nearestCity"], "")), 120),
                "anchorage_name" = left(trim(readAny(arguments.payload, ["anchorage_name", "ANCHORAGE_NAME", "anchorageName"], "")), 180),
                "latitude" = latitudeValue,
                "longitude" = longitudeValue,
                "anchorage_type" = left(trim(readAny(arguments.payload, ["anchorage_type", "ANCHORAGE_TYPE", "anchorageType"], "")), 80),
                "public_status" = left(trim(readAny(arguments.payload, ["public_status", "PUBLIC_STATUS", "publicStatus"], "")), 80),
                "holding" = left(trim(readAny(arguments.payload, ["holding", "HOLDING"], "")), 80),
                "protection" = left(trim(readAny(arguments.payload, ["protection", "PROTECTION"], "")), 80),
                "shore_access" = left(trim(readAny(arguments.payload, ["shore_access", "SHORE_ACCESS", "shoreAccess"], "")), 80),
                "notes" = trim(readAny(arguments.payload, ["notes", "NOTES"], "")),
                "source_name" = left(trim(readAny(arguments.payload, ["source_name", "SOURCE_NAME", "sourceName"], "")), 180),
                "source_url" = sourceUrl,
                "verification_status" = left(trim(readAny(arguments.payload, ["verification_status", "VERIFICATION_STATUS", "verificationStatus"], "needs_verification")), 80),
                "great_loop_relevance" = left(trim(readAny(arguments.payload, ["great_loop_relevance", "GREAT_LOOP_RELEVANCE", "greatLoopRelevance"], "")), 120),
                "nav_warning" = trim(readAny(arguments.payload, ["nav_warning", "NAV_WARNING", "navWarning"], "")),
                "duplicate_review_note" = left(trim(readAny(arguments.payload, ["duplicate_review_note", "DUPLICATE_REVIEW_NOTE", "duplicateReviewNote"], "")), 80),
                "last_reviewed" = lastReviewed,
                "is_published" = boolLike(publishedValue) ? 1 : 0,
                "reviewed_by" = left(trim(readAny(arguments.payload, ["reviewed_by", "REVIEWED_BY", "reviewedBy"], "")), 100),
                "reviewed_at" = reviewedAt,
                "reviewer_notes" = trim(readAny(arguments.payload, ["reviewer_notes", "REVIEWER_NOTES", "reviewerNotes"], ""))
            };

            if (arguments.requireId AND !len(out.DATA.anchorage_id)) {
                arrayAppend(out.ERRORS, "Anchorage id is required.");
            }
            if (!len(out.DATA.anchorage_name)) {
                arrayAppend(out.ERRORS, "Anchorage name is required.");
            }
            if (!len(out.DATA.slug)) {
                arrayAppend(out.ERRORS, "Slug is required.");
            }
            if (!len(out.DATA.location_group)) {
                arrayAppend(out.ERRORS, "Location group is required.");
            }
            if (!len(out.DATA.verification_status)) {
                out.DATA.verification_status = "needs_verification";
            }
            if (len(out.DATA.latitude)) {
                if (!isNumeric(out.DATA.latitude) OR val(out.DATA.latitude) LT -90 OR val(out.DATA.latitude) GT 90) {
                    arrayAppend(out.ERRORS, "Latitude must be a number between -90 and 90.");
                } else {
                    out.DATA.latitude = val(out.DATA.latitude);
                }
            }
            if (len(out.DATA.longitude)) {
                if (!isNumeric(out.DATA.longitude) OR val(out.DATA.longitude) LT -180 OR val(out.DATA.longitude) GT 180) {
                    arrayAppend(out.ERRORS, "Longitude must be a number between -180 and 180.");
                } else {
                    out.DATA.longitude = val(out.DATA.longitude);
                }
            }
            if (len(sourceUrl) AND !isSafeHttpUrl(sourceUrl)) {
                arrayAppend(out.ERRORS, "Source URL must start with http:// or https://.");
            }
            if (len(lastReviewed) AND !isDate(lastReviewed)) {
                arrayAppend(out.ERRORS, "Last reviewed date must be a valid date.");
            }
            if (len(reviewedAt) AND !isDate(reviewedAt)) {
                arrayAppend(out.ERRORS, "Reviewed at must be a valid date/time.");
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="buildAdminAnchorageParams" access="private" returntype="struct" output="false">
        <cfargument name="payload" type="struct" required="true">
        <cfscript>
            return {
                anchorageId = { value = arguments.payload.anchorage_id, cfsqltype = "cf_sql_varchar" },
                slug = { value = arguments.payload.slug, cfsqltype = "cf_sql_varchar" },
                locationGroup = { value = arguments.payload.location_group, cfsqltype = "cf_sql_varchar" },
                waterway = nullableParam(arguments.payload.waterway, "cf_sql_varchar"),
                stateProvince = nullableParam(arguments.payload.state_province, "cf_sql_varchar"),
                country = nullableParam(arguments.payload.country, "cf_sql_varchar"),
                nearestCity = nullableParam(arguments.payload.nearest_city, "cf_sql_varchar"),
                anchorageName = { value = arguments.payload.anchorage_name, cfsqltype = "cf_sql_varchar" },
                latitude = nullableDecimalParam(arguments.payload.latitude, 7),
                longitude = nullableDecimalParam(arguments.payload.longitude, 7),
                anchorageType = nullableParam(arguments.payload.anchorage_type, "cf_sql_varchar"),
                publicStatus = nullableParam(arguments.payload.public_status, "cf_sql_varchar"),
                holding = nullableParam(arguments.payload.holding, "cf_sql_varchar"),
                protection = nullableParam(arguments.payload.protection, "cf_sql_varchar"),
                shoreAccess = nullableParam(arguments.payload.shore_access, "cf_sql_varchar"),
                notes = nullableParam(arguments.payload.notes, "cf_sql_longvarchar"),
                sourceName = nullableParam(arguments.payload.source_name, "cf_sql_varchar"),
                sourceUrl = nullableParam(arguments.payload.source_url, "cf_sql_varchar"),
                verificationStatus = { value = arguments.payload.verification_status, cfsqltype = "cf_sql_varchar" },
                greatLoopRelevance = nullableParam(arguments.payload.great_loop_relevance, "cf_sql_varchar"),
                navWarning = nullableParam(arguments.payload.nav_warning, "cf_sql_longvarchar"),
                duplicateReviewNote = nullableParam(arguments.payload.duplicate_review_note, "cf_sql_varchar"),
                lastReviewed = nullableDateParam(arguments.payload.last_reviewed),
                isPublished = { value = arguments.payload.is_published, cfsqltype = "cf_sql_tinyint" },
                reviewedBy = nullableParam(arguments.payload.reviewed_by, "cf_sql_varchar"),
                reviewedAt = nullableDatetimeParam(arguments.payload.reviewed_at),
                reviewerNotes = nullableParam(arguments.payload.reviewer_notes, "cf_sql_longvarchar")
            };
        </cfscript>
    </cffunction>

    <cffunction name="normalizeAnchorageId" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfscript>
            return left(uCase(trim(toString(arguments.value))), 16);
        </cfscript>
    </cffunction>

    <cffunction name="generateNextAnchorageId" access="private" returntype="string" output="false">
        <cfargument name="offset" type="numeric" required="false" default="0">
        <cfscript>
            var q = queryExecute(
                "SELECT COALESCE(MAX(CAST(SUBSTRING(anchorage_id, 5) AS UNSIGNED)), 0) AS max_id
                 FROM greatLoop_anchorages
                 WHERE anchorage_id REGEXP '^GLA-[0-9]+$'",
                {},
                { datasource = getDatasource() }
            );
            return formatAnchorageId(val(q.max_id[1]) + 1 + val(arguments.offset));
        </cfscript>
    </cffunction>

    <cffunction name="formatAnchorageId" access="private" returntype="string" output="false">
        <cfargument name="idNumber" type="numeric" required="true">
        <cfscript>
            var txt = trim(toString(int(val(arguments.idNumber))));
            while (len(txt) LT 4) {
                txt = "0" & txt;
            }
            return "GLA-" & txt;
        </cfscript>
    </cffunction>

    <cffunction name="isAnchorageIdAvailable" access="private" returntype="boolean" output="false">
        <cfargument name="anchorageId" type="string" required="true">
        <cfscript>
            var q = queryExecute(
                "SELECT COUNT(*) AS match_count
                 FROM greatLoop_anchorages
                 WHERE anchorage_id = :anchorageId",
                { anchorageId = { value = normalizeAnchorageId(arguments.anchorageId), cfsqltype = "cf_sql_varchar" } },
                { datasource = getDatasource() }
            );
            return val(q.match_count[1]) EQ 0;
        </cfscript>
    </cffunction>

    <cffunction name="isAnchorageSlugAvailable" access="private" returntype="boolean" output="false">
        <cfargument name="slug" type="string" required="true">
        <cfargument name="excludeAnchorageId" type="string" required="false" default="">
        <cfscript>
            var q = queryExecute(
                "SELECT COUNT(*) AS match_count
                 FROM greatLoop_anchorages
                 WHERE slug = :slug
                   AND anchorage_id <> :anchorageId",
                {
                    slug = { value = left(normalizeSlug(arguments.slug), 120), cfsqltype = "cf_sql_varchar" },
                    anchorageId = { value = normalizeAnchorageId(arguments.excludeAnchorageId), cfsqltype = "cf_sql_varchar" }
                },
                { datasource = getDatasource() }
            );
            return val(q.match_count[1]) EQ 0;
        </cfscript>
    </cffunction>

    <cffunction name="nullableParam" access="private" returntype="struct" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfargument name="sqlType" type="string" required="true">
        <cfscript>
            var txt = trim(toString(isNull(arguments.value) ? "" : arguments.value));
            if (!len(txt)) {
                return { value = "", cfsqltype = arguments.sqlType, null = true };
            }
            return { value = txt, cfsqltype = arguments.sqlType };
        </cfscript>
    </cffunction>

    <cffunction name="nullableDecimalParam" access="private" returntype="struct" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfargument name="scale" type="numeric" required="false" default="7">
        <cfscript>
            var txt = trim(toString(isNull(arguments.value) ? "" : arguments.value));
            if (!len(txt)) {
                return { value = 0, cfsqltype = "cf_sql_decimal", scale = arguments.scale, null = true };
            }
            return { value = val(txt), cfsqltype = "cf_sql_decimal", scale = arguments.scale };
        </cfscript>
    </cffunction>

    <cffunction name="nullableDateParam" access="private" returntype="struct" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfscript>
            var txt = trim(toString(isNull(arguments.value) ? "" : arguments.value));
            if (!len(txt)) {
                return { value = "", cfsqltype = "cf_sql_date", null = true };
            }
            return { value = txt, cfsqltype = "cf_sql_date" };
        </cfscript>
    </cffunction>

    <cffunction name="nullableDatetimeParam" access="private" returntype="struct" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfscript>
            var txt = trim(toString(isNull(arguments.value) ? "" : arguments.value));
            if (!len(txt)) {
                return { value = "", cfsqltype = "cf_sql_timestamp", null = true };
            }
            return { value = txt, cfsqltype = "cf_sql_timestamp" };
        </cfscript>
    </cffunction>

    <cffunction name="isSafeHttpUrl" access="private" returntype="boolean" output="false">
        <cfargument name="value" type="string" required="true">
        <cfscript>
            var txt = lCase(trim(arguments.value));
            return left(txt, 7) EQ "http://" OR left(txt, 8) EQ "https://";
        </cfscript>
    </cffunction>

    <cffunction name="boolLike" access="private" returntype="boolean" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfargument name="defaultValue" type="boolean" required="false" default="false">
        <cfscript>
            var txt = lCase(trim(toString(arguments.value)));
            if (!len(txt)) return arguments.defaultValue;
            if (listFindNoCase("1,true,yes,y,on", txt)) return true;
            if (listFindNoCase("0,false,no,n,off", txt)) return false;
            if (isNumeric(txt)) return (val(txt) NEQ 0);
            return arguments.defaultValue;
        </cfscript>
    </cffunction>

    <cffunction name="readAny" access="private" returntype="string" output="false">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="keys" type="array" required="true">
        <cfargument name="fallback" type="string" required="false" default="">
        <cfscript>
            var keyName = "";
            for (keyName in arguments.keys) {
                if (structKeyExists(arguments.source, keyName) AND !isNull(arguments.source[keyName])) {
                    return toString(arguments.source[keyName]);
                }
            }
            return arguments.fallback;
        </cfscript>
    </cffunction>

    <cffunction name="getAdjacentAnchorages" access="private" returntype="struct" output="false">
        <cfargument name="slug" type="string" required="true">
        <cfscript>
            var out = { "PREVIOUS" = {}, "NEXT" = {} };
            var q = queryExecute(
                "SELECT slug, anchorage_name
                 FROM greatLoop_anchorages
                 WHERE is_published = 1
                   AND slug IS NOT NULL
                   AND TRIM(slug) <> ''
                 ORDER BY location_group ASC, waterway ASC, anchorage_name ASC",
                {},
                { datasource = getDatasource() }
            );
            var i = 0;
            var currentSlug = normalizeSlug(arguments.slug);

            for (i = 1; i LTE q.recordCount; i++) {
                if (normalizeSlug(q.slug[i]) EQ currentSlug) {
                    if (i GT 1) {
                        out.PREVIOUS = { "slug" = normalizeSlug(q.slug[i - 1]), "anchorage_name" = safeString(q.anchorage_name[i - 1]) };
                    }
                    if (i LT q.recordCount) {
                        out.NEXT = { "slug" = normalizeSlug(q.slug[i + 1]), "anchorage_name" = safeString(q.anchorage_name[i + 1]) };
                    }
                    break;
                }
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getNearbyAnchorages" access="private" returntype="array" output="false">
        <cfargument name="anchorage" type="struct" required="true">
        <cfargument name="limit" type="numeric" required="false" default="4">
        <cfscript>
            var out = [];
            var q = queryNew("");
            var i = 0;
            var limitRows = max(1, min(val(arguments.limit), 8));

            if (!isNumeric(arguments.anchorage.latitude) OR !isNumeric(arguments.anchorage.longitude)) {
                return searchPublicAnchorages({ "waterway" = arguments.anchorage.waterway, "limit" = limitRows + 1 }).ROWS;
            }

            q = queryExecute(
                buildSelectSql() & ",
                    ((latitude - :lat) * (latitude - :lat) + (longitude - :lng) * (longitude - :lng)) AS distance_sort
                 FROM greatLoop_anchorages
                 WHERE is_published = 1
                   AND slug IS NOT NULL
                   AND TRIM(slug) <> ''
                   AND slug <> :slug
                   AND latitude IS NOT NULL
                   AND longitude IS NOT NULL
                 ORDER BY distance_sort ASC, anchorage_name ASC
                 LIMIT :limitRows",
                {
                    lat = { value = val(arguments.anchorage.latitude), cfsqltype = "cf_sql_double" },
                    lng = { value = val(arguments.anchorage.longitude), cfsqltype = "cf_sql_double" },
                    slug = { value = arguments.anchorage.slug, cfsqltype = "cf_sql_varchar" },
                    limitRows = { value = limitRows, cfsqltype = "cf_sql_integer" }
                },
                { datasource = getDatasource() }
            );
            for (i = 1; i LTE q.recordCount; i++) {
                arrayAppend(out, rowToStruct(q, i));
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="resolveFacetValueBySlug" access="private" returntype="string" output="false">
        <cfargument name="fieldName" type="string" required="true">
        <cfargument name="slug" type="string" required="true">
        <cfscript>
            var target = normalizeSlug(arguments.slug);
            var facets = getFacets(arguments.fieldName);
            var i = 0;

            for (i = 1; i LTE arrayLen(facets); i++) {
                if (facets[i].slug EQ target) {
                    return facets[i].value;
                }
            }
            return "";
        </cfscript>
    </cffunction>

    <cffunction name="safeString" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfscript>
            if (isNull(arguments.value)) {
                return "";
            }
            return trim(toString(arguments.value));
        </cfscript>
    </cffunction>

    <cffunction name="safeGet" access="private" returntype="string" output="false">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfargument name="fallback" type="string" required="false" default="">
        <cfscript>
            if (structKeyExists(arguments.source, arguments.key) AND !isNull(arguments.source[arguments.key])) {
                return toString(arguments.source[arguments.key]);
            }
            return arguments.fallback;
        </cfscript>
    </cffunction>
</cfcomponent>
