<cfcomponent output="false" hint="Read-only public Great Loop lock reference library service.">

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
            variables.columnFlags = {};
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
                cached = getCachedLockLibraryModel();
                if (isStruct(cached) AND structCount(cached) GT 0) {
                    return cached;
                }
            }

            out = {
                "SUCCESS" = true,
                "HAS_PUBLIC_SCHEMA" = hasPublicSchema(),
                "STATS" = getStats(),
                "FILTERS" = normalized,
                "LOCKS" = [],
                "STATES" = [],
                "WATERWAYS" = [],
                "LOCK_SYSTEMS" = []
            };

            out.STATES = getFacets("state");
            out.WATERWAYS = getFacets("waterway");
            out.LOCK_SYSTEMS = getFacets("lock_system");
            out.LOCKS = searchLocks(out.FILTERS).ROWS;

            if (isDefaultPublicLibraryFilters(normalized)) {
                putCachedLockLibraryModel(out);
            }

            return out;
        </cfscript>
    </cffunction>

    <cffunction name="clearLockLibraryCache" access="public" returntype="void" output="false">
        <cfscript>
            try {
                cacheRemove(buildLockLibraryCacheKey());
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
            out["states"] = facetsToOptions(getFacets("state"));
            out["waterways"] = facetsToOptions(getFacets("waterway", { "state" = normalized.state }));
            out["lockSystems"] = facetsToOptions(getFacets("lock_system", {
                "state" = normalized.state,
                "waterway" = normalized.waterway
            }));
            out["message"] = "";
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getLocksApiModel" access="public" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="false" default="#structNew()#">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var normalized = normalizeFilters(arguments.filters);
            var searchResult = searchLocks(normalized);
            var rows = searchResult.ROWS;
            var out = structNew("ordered");

            out["success"] = searchResult.SUCCESS;
            out["filters"] = buildFilterStruct(normalized);
            out["summary"] = buildSummary(rows);
            out["locks"] = locksToApiRows(rows, arguments.basePath);
            out["message"] = "";
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getAdminFacets" access="public" returntype="struct" output="false">
        <cfscript>
            var out = structNew("ordered");

            out["states"] = getAdminFacetOptions("state");
            out["waterways"] = getAdminFacetOptions("waterway");
            out["lockSystems"] = getAdminFacetOptions("lock_system");
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="searchAdminLocks" access="public" returntype="struct" output="false">
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
            var allRows = [];
            var row = {};
            var imageAsset = {};
            var i = 0;
            var startIndex = 0;
            var endIndex = 0;

            if (!hasPublicSchema()) {
                out.SUCCESS = false;
                out.MESSAGE = "Great Loop lock table is not available.";
                return out;
            }

            if (len(normalized.q)) {
                arrayAppend(conditions, "(
                    lock_name LIKE :q
                    OR COALESCE(city, '') LIKE :q
                    OR COALESCE(state, '') LIKE :q
                    OR COALESCE(waterway, '') LIKE :q
                    OR COALESCE(lock_system, '') LIKE :q
                    OR COALESCE(phone, '') LIKE :q
                    OR COALESCE(vhf, '') LIKE :q
                )");
                params.q = { value = "%" & normalized.q & "%", cfsqltype = "cf_sql_varchar" };
            }
            if (len(normalized.state)) {
                arrayAppend(conditions, "state = :state");
                params.state = { value = normalized.state, cfsqltype = "cf_sql_varchar" };
            }
            if (len(normalized.waterway)) {
                arrayAppend(conditions, "waterway = :waterway");
                params.waterway = { value = normalized.waterway, cfsqltype = "cf_sql_varchar" };
            }
            if (len(normalized.lockSystem)) {
                arrayAppend(conditions, "lock_system = :lockSystem");
                params.lockSystem = { value = normalized.lockSystem, cfsqltype = "cf_sql_varchar" };
            }
            if (normalized.publicStatus EQ "public") {
                arrayAppend(conditions, "is_public = 1");
            } else if (normalized.publicStatus EQ "hidden") {
                arrayAppend(conditions, "is_public = 0");
            }

            sql = buildSelectSql() & "
                FROM great_loop_locks
                WHERE " & arrayToList(conditions, " AND ") & "
                " & buildOrderSql() & "
                LIMIT 1000";

            q = queryExecute(sql, params, { datasource = getDatasource() });
            for (i = 1; i LTE q.recordCount; i++) {
                row = rowToStruct(q, i);
                imageAsset = getLockImageAsset(row, arguments.basePath);
                row["image"] = imageAsset;
                row["hasImage"] = imageAsset.hasImage;
                row["imageFileName"] = imageAsset.fileName;

                if (normalized.imageStatus EQ "has" AND !imageAsset.hasImage) {
                    continue;
                }
                if (normalized.imageStatus EQ "missing" AND imageAsset.hasImage) {
                    continue;
                }
                arrayAppend(allRows, row);
            }

            out.TOTAL = arrayLen(allRows);
            startIndex = normalized.offset + 1;
            endIndex = min(normalized.offset + normalized.limit, out.TOTAL);
            if (startIndex LTE endIndex) {
                for (i = startIndex; i LTE endIndex; i++) {
                    arrayAppend(out.ROWS, allRows[i]);
                }
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getLockById" access="public" returntype="struct" output="false">
        <cfargument name="lockId" type="numeric" required="true">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var out = { "SUCCESS" = false, "LOCK" = {} };
            var q = queryNew("");
            var row = {};

            if (val(arguments.lockId) LTE 0 OR !hasPublicSchema()) {
                out.MESSAGE = "Lock not found.";
                return out;
            }

            q = queryExecute(
                buildSelectSql() & "
                 FROM great_loop_locks
                 WHERE id = :lockId
                 LIMIT 1",
                { lockId = { value = val(arguments.lockId), cfsqltype = "cf_sql_bigint" } },
                { datasource = getDatasource() }
            );

            if (q.recordCount EQ 0) {
                out.MESSAGE = "Lock not found.";
                return out;
            }

            row = rowToStruct(q, 1);
            row["image"] = getLockImageAsset(row, arguments.basePath);
            row["hasImage"] = row.image.hasImage;
            row["imageFileName"] = row.image.fileName;
            out.SUCCESS = true;
            out.LOCK = row;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="updateLock" access="public" returntype="struct" output="false">
        <cfargument name="lockData" type="struct" required="true">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var payloadResult = normalizeAdminLockPayload(arguments.lockData);
            var payload = payloadResult.DATA;
            var out = { "SUCCESS" = false, "LOCK" = {}, "ERRORS" = payloadResult.ERRORS, "WARNINGS" = [] };
            var existingResult = {};
            var existingLock = {};
            var savedResult = {};
            var renameResult = {};

            if (arrayLen(out.ERRORS)) {
                out.MESSAGE = "Validation failed.";
                return out;
            }

            existingResult = getLockById(payload.id, arguments.basePath);
            if (!existingResult.SUCCESS) {
                out.MESSAGE = "Lock not found.";
                arrayAppend(out.ERRORS, "Lock not found.");
                return out;
            }
            existingLock = existingResult.LOCK;

            if (!isSlugAvailable(payload.slug, payload.id)) {
                out.MESSAGE = "Validation failed.";
                arrayAppend(out.ERRORS, "Slug is already used by another lock.");
                return out;
            }

            queryExecute(
                "UPDATE great_loop_locks
                 SET lock_name = :lockName,
                     slug = :slug,
                     latitude = :latitude,
                     longitude = :longitude,
                     note = :note,
                     city = :city,
                     state = :state,
                     zip = :zip,
                     phone = :phone,
                     vhf = :vhf,
                     waterway = :waterway,
                     lock_system = :lockSystem,
                     operating_authority = :operatingAuthority,
                     country = :country,
                     approach_notes = :approachNotes,
                     operating_notes = :operatingNotes,
                     special_instructions = :specialInstructions,
                     source_name = :sourceName,
                     source_url = :sourceUrl,
                     last_reviewed_at = :lastReviewedAt,
                     is_public = :isPublic,
                     sort_order = :sortOrder
                 WHERE id = :lockId",
                {
                    lockName = { value = payload.lock_name, cfsqltype = "cf_sql_varchar" },
                    slug = { value = payload.slug, cfsqltype = "cf_sql_varchar" },
                    latitude = { value = payload.latitude, cfsqltype = "cf_sql_decimal", scale = 6 },
                    longitude = { value = payload.longitude, cfsqltype = "cf_sql_decimal", scale = 6 },
                    note = nullableParam(payload.note, "cf_sql_longvarchar"),
                    city = nullableParam(payload.city, "cf_sql_varchar"),
                    state = nullableParam(payload.state, "cf_sql_varchar"),
                    zip = nullableParam(payload.zip, "cf_sql_varchar"),
                    phone = nullableParam(payload.phone, "cf_sql_varchar"),
                    vhf = nullableParam(payload.vhf, "cf_sql_varchar"),
                    waterway = nullableParam(payload.waterway, "cf_sql_varchar"),
                    lockSystem = nullableParam(payload.lock_system, "cf_sql_varchar"),
                    operatingAuthority = nullableParam(payload.operating_authority, "cf_sql_varchar"),
                    country = nullableParam(payload.country, "cf_sql_varchar"),
                    approachNotes = nullableParam(payload.approach_notes, "cf_sql_longvarchar"),
                    operatingNotes = nullableParam(payload.operating_notes, "cf_sql_longvarchar"),
                    specialInstructions = nullableParam(payload.special_instructions, "cf_sql_longvarchar"),
                    sourceName = nullableParam(payload.source_name, "cf_sql_varchar"),
                    sourceUrl = nullableParam(payload.source_url, "cf_sql_varchar"),
                    lastReviewedAt = nullableDateParam(payload.last_reviewed_at),
                    isPublic = { value = payload.is_public, cfsqltype = "cf_sql_tinyint" },
                    sortOrder = nullableIntegerParam(payload.sort_order),
                    lockId = { value = payload.id, cfsqltype = "cf_sql_bigint" }
                },
                { datasource = getDatasource() }
            );

            savedResult = getLockById(payload.id, arguments.basePath);
            if (savedResult.SUCCESS) {
                renameResult = renameImageForSlugChange(existingLock, savedResult.LOCK, arguments.basePath);
                if (structKeyExists(renameResult, "message") AND len(renameResult.message)) {
                    arrayAppend(out.WARNINGS, renameResult.message);
                    savedResult = getLockById(payload.id, arguments.basePath);
                }
                clearLockLibraryCache();
                out.SUCCESS = true;
                out.MESSAGE = "Lock saved.";
                out.LOCK = savedResult.LOCK;
            } else {
                out.MESSAGE = "Lock saved, but the updated row could not be reloaded.";
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="saveUploadedLockImage" access="public" returntype="struct" output="false">
        <cfargument name="lockId" type="numeric" required="true">
        <cfargument name="uploadPath" type="string" required="true">
        <cfargument name="originalFileName" type="string" required="true">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var out = { "SUCCESS" = false, "LOCK" = {}, "IMAGE" = {}, "MESSAGE" = "" };
            var lockResult = getLockById(arguments.lockId, arguments.basePath);
            var lockRow = {};
            var ext = lCase(trim(listLast(arguments.originalFileName, ".")));
            var imageRoot = getLockImageRootPath();
            var thumbnailRoot = getLockThumbnailRootPath();
            var slugKey = "";
            var fileName = "";
            var destinationPath = "";
            var thumbnailPath = "";
            var img = "";

            if (!lockResult.SUCCESS) {
                out.MESSAGE = "Lock not found.";
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

            lockRow = lockResult.LOCK;
            slugKey = normalizeSlug(lockRow.slug);
            if (!len(slugKey)) {
                out.MESSAGE = "The lock must have a valid slug before an image can be saved.";
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

            deleteStaleLockImages(lockRow, fileName);
            if (fileExists(destinationPath)) {
                fileDelete(destinationPath);
            }
            fileCopy(arguments.uploadPath, destinationPath);

            try {
                generateLockThumbnail(destinationPath, thumbnailPath);
            } catch (any thumbnailError) {
                out.MESSAGE = "Image saved, but thumbnail generation failed.";
                out.SUCCESS = false;
                return out;
            }

            lockResult = getLockById(arguments.lockId, arguments.basePath);
            out.SUCCESS = true;
            out.MESSAGE = "Image saved.";
            out.LOCK = lockResult.LOCK;
            out.IMAGE = lockResult.LOCK.image;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="deleteLockImage" access="public" returntype="struct" output="false">
        <cfargument name="lockId" type="numeric" required="true">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var out = { "SUCCESS" = false, "LOCK" = {}, "IMAGE" = {}, "DELETED" = [], "MESSAGE" = "" };
            var lockResult = getLockById(arguments.lockId, arguments.basePath);
            var lockRow = {};
            var imageAsset = {};
            var imageRoot = getLockImageRootPath();
            var thumbnailRoot = getLockThumbnailRootPath();
            var extensions = ["jpg", "jpeg", "png", "webp"];
            var matchKeys = [];
            var candidateFiles = [];
            var slugKey = "";
            var nameKey = "";
            var assetKey = "";
            var candidate = "";
            var sourcePath = "";
            var thumbnailPath = "";
            var deletedCount = 0;
            var i = 0;
            var j = 0;

            if (!lockResult.SUCCESS) {
                out.MESSAGE = "Lock not found.";
                return out;
            }

            lockRow = lockResult.LOCK;
            imageAsset = structKeyExists(lockRow, "image") ? lockRow.image : getLockImageAsset(lockRow, arguments.basePath);
            if (!imageAsset.hasImage OR !len(imageAsset.fileName)) {
                out.MESSAGE = "No lock image was found.";
                out.LOCK = lockRow;
                out.IMAGE = imageAsset;
                return out;
            }

            slugKey = structKeyExists(lockRow, "slug") ? normalizeLockImageKey(lockRow.slug) : "";
            nameKey = structKeyExists(lockRow, "lock_name") ? normalizeLockImageKey(lockRow.lock_name) : "";
            assetKey = normalizeLockImageKey(reReplace(imageAsset.fileName, "\.[^.]+$", ""));

            if (len(slugKey)) arrayAppend(matchKeys, slugKey);
            if (len(nameKey) AND nameKey NEQ slugKey) arrayAppend(matchKeys, nameKey);
            if (len(assetKey) AND !arrayFind(matchKeys, assetKey)) arrayAppend(matchKeys, assetKey);

            for (i = 1; i LTE arrayLen(matchKeys); i++) {
                for (j = 1; j LTE arrayLen(extensions); j++) {
                    candidate = matchKeys[i] & "." & extensions[j];
                    if (!arrayFind(candidateFiles, candidate)) {
                        arrayAppend(candidateFiles, candidate);
                    }
                }
            }

            if (!arrayFind(candidateFiles, imageAsset.fileName)) {
                arrayAppend(candidateFiles, imageAsset.fileName);
            }

            for (i = 1; i LTE arrayLen(candidateFiles); i++) {
                candidate = candidateFiles[i];
                if (!isLockImageFile(candidate)) {
                    continue;
                }

                sourcePath = joinPath(imageRoot, candidate);
                thumbnailPath = joinPath(thumbnailRoot, candidate);

                if (deleteImageFileIfSafe(sourcePath, imageRoot)) {
                    arrayAppend(out.DELETED, candidate);
                    deletedCount++;
                }
                if (deleteImageFileIfSafe(thumbnailPath, thumbnailRoot)) {
                    arrayAppend(out.DELETED, "thumbnails/" & candidate);
                    deletedCount++;
                }
            }

            lockResult = getLockById(arguments.lockId, arguments.basePath);
            out.LOCK = lockResult.SUCCESS ? lockResult.LOCK : lockRow;
            out.IMAGE = structKeyExists(out.LOCK, "image") ? out.LOCK.image : getLockImageAsset(lockRow, arguments.basePath);
            out.SUCCESS = deletedCount GT 0;
            out.MESSAGE = out.SUCCESS ? "Lock image deleted." : "No matching image files were found.";
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getLockImageAsset" access="public" returntype="struct" output="false">
        <cfargument name="lockRow" type="struct" required="true">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var out = {
                "hasImage" = false,
                "fileName" = "",
                "sourceUrl" = "",
                "thumbnailUrl" = "",
                "hasThumbnail" = false
            };
            var imageRootPath = getLockImageRootPath();
            var thumbnailRootPath = getLockThumbnailRootPath();
            var cleanBasePath = reReplace(trim(toString(arguments.basePath)), "/$", "");
            var imageBaseUrl = "";
            var extensions = ["jpg", "jpeg", "png", "webp"];
            var slugKey = structKeyExists(arguments.lockRow, "slug") ? normalizeLockImageKey(arguments.lockRow.slug) : "";
            var nameKey = structKeyExists(arguments.lockRow, "lock_name") ? normalizeLockImageKey(arguments.lockRow.lock_name) : "";
            var candidate = "";
            var i = 0;
            var j = 0;
            var files = queryNew("");
            var fileName = "";
            var fileKey = "";
            var matchKeys = [];

            if (cleanBasePath EQ "/") {
                cleanBasePath = "";
            }
            imageBaseUrl = cleanBasePath & "/assets/images/great-loop-locks";

            if (!directoryExists(imageRootPath)) {
                return out;
            }

            if (len(slugKey)) {
                arrayAppend(matchKeys, slugKey);
            }
            if (len(nameKey) AND nameKey NEQ slugKey) {
                arrayAppend(matchKeys, nameKey);
            }

            for (i = 1; i LTE arrayLen(matchKeys); i++) {
                for (j = 1; j LTE arrayLen(extensions); j++) {
                    candidate = matchKeys[i] & "." & extensions[j];
                    if (fileExists(joinPath(imageRootPath, candidate))) {
                        return buildLockImageAsset(candidate, imageRootPath, thumbnailRootPath, imageBaseUrl);
                    }
                }
            }

            files = directoryList(imageRootPath, false, "query");
            for (i = 1; i LTE files.recordCount; i++) {
                fileName = files.name[i];
                if (!isLockImageFile(fileName)) {
                    continue;
                }
                fileKey = normalizeLockImageKey(reReplace(fileName, "\.[^.]+$", ""));
                if (arrayFind(matchKeys, fileKey)) {
                    return buildLockImageAsset(fileName, imageRootPath, thumbnailRootPath, imageBaseUrl);
                }
            }

            return out;
        </cfscript>
    </cffunction>

    <cffunction name="searchLocks" access="public" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var out = { "SUCCESS" = true, "ROWS" = [], "COUNT" = 0 };
            var normalized = normalizeFilters(arguments.filters);
            var sql = "";
            var params = {};
            var conditions = [ "is_public = 1", "slug IS NOT NULL", "TRIM(slug) <> ''" ];
            var q = queryNew("");
            var i = 0;
            var maxRows = val(normalized.limit);
            var selectSql = buildSelectSql();
            var orderSql = buildOrderSql();

            if (!hasPublicSchema()) {
                return out;
            }

            if (maxRows LTE 0 OR maxRows GT 500) {
                maxRows = 300;
            }

            if (len(normalized.q)) {
                arrayAppend(conditions, "(
                    lock_name LIKE :q
                    OR COALESCE(city, '') LIKE :q
                    OR COALESCE(state, '') LIKE :q
                    OR COALESCE(waterway, '') LIKE :q
                    OR COALESCE(lock_system, '') LIKE :q
                    OR COALESCE(vhf, '') LIKE :q
                )");
                params.q = { value = "%" & normalized.q & "%", cfsqltype = "cf_sql_varchar" };
            }
            if (len(normalized.state)) {
                arrayAppend(conditions, "state = :state");
                params.state = { value = normalized.state, cfsqltype = "cf_sql_varchar" };
            }
            if (len(normalized.waterway)) {
                arrayAppend(conditions, "waterway = :waterway");
                params.waterway = { value = normalized.waterway, cfsqltype = "cf_sql_varchar" };
            }
            if (len(normalized.lockSystem)) {
                arrayAppend(conditions, "lock_system = :lockSystem");
                params.lockSystem = { value = normalized.lockSystem, cfsqltype = "cf_sql_varchar" };
            }
            if (normalized.hasVhf) {
                arrayAppend(conditions, "vhf IS NOT NULL AND TRIM(vhf) <> ''");
            }
            if (normalized.hasPhone) {
                arrayAppend(conditions, "phone IS NOT NULL AND TRIM(phone) <> ''");
            }
            if (normalized.hasNotes) {
                arrayAppend(conditions, "(
                    note IS NOT NULL AND TRIM(note) <> ''
                    OR approach_notes IS NOT NULL AND TRIM(approach_notes) <> ''
                    OR operating_notes IS NOT NULL AND TRIM(operating_notes) <> ''
                    OR special_instructions IS NOT NULL AND TRIM(special_instructions) <> ''
                )");
            }

            sql = selectSql & "
                FROM great_loop_locks
                WHERE " & arrayToList(conditions, " AND ") & "
                " & orderSql & "
                LIMIT :limitRows";
            params.limitRows = { value = maxRows, cfsqltype = "cf_sql_integer" };

            q = queryExecute(sql, params, { datasource = getDatasource() });
            for (i = 1; i LTE q.recordCount; i++) {
                arrayAppend(out.ROWS, rowToStruct(q, i));
            }
            out.COUNT = arrayLen(out.ROWS);
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getLockBySlug" access="public" returntype="struct" output="false">
        <cfargument name="slug" type="string" required="true">
        <cfscript>
            var out = { "SUCCESS" = false, "LOCK" = {}, "PREVIOUS" = {}, "NEXT" = {} };
            var q = queryNew("");
            var nav = {};

            if (!hasPublicSchema() OR !len(normalizeSlug(arguments.slug))) {
                out.MESSAGE = "Lock not found.";
                return out;
            }

            q = queryExecute(
                buildSelectSql() & "
                 FROM great_loop_locks
                 WHERE is_public = 1
                   AND slug = :slug
                 LIMIT 1",
                { slug = { value = normalizeSlug(arguments.slug), cfsqltype = "cf_sql_varchar" } },
                { datasource = getDatasource() }
            );

            if (q.recordCount EQ 0) {
                out.MESSAGE = "Lock not found.";
                return out;
            }

            out.SUCCESS = true;
            out.LOCK = rowToStruct(q, 1);
            nav = getAdjacentLocks(out.LOCK.slug);
            out.PREVIOUS = nav.PREVIOUS;
            out.NEXT = nav.NEXT;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getWaterwayModel" access="public" returntype="struct" output="false">
        <cfargument name="slug" type="string" required="true">
        <cfscript>
            var waterwayName = resolveFacetValueBySlug("waterway", arguments.slug);
            var out = { "SUCCESS" = false, "WATERWAY" = waterwayName, "LOCKS" = [], "STATS" = getStats() };
            if (!len(waterwayName)) {
                out.MESSAGE = "Waterway not found.";
                return out;
            }
            out.LOCKS = searchLocks({ "waterway" = waterwayName, "limit" = 500 }).ROWS;
            out.SUCCESS = true;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getStateModel" access="public" returntype="struct" output="false">
        <cfargument name="state" type="string" required="true">
        <cfscript>
            var stateCode = resolveStateCodeBySlug(arguments.state);
            var out = { "SUCCESS" = false, "STATE" = stateCode, "LOCKS" = [], "STATS" = getStats() };
            if (!len(stateCode) OR !hasFacetValue("state", stateCode)) {
                out.MESSAGE = "State or province not found.";
                return out;
            }
            out.LOCKS = searchLocks({ "state" = stateCode, "limit" = 500 }).ROWS;
            out.SUCCESS = true;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getStateDisplayName" access="public" returntype="string" output="false">
        <cfargument name="state" type="string" required="true">
        <cfscript>
            var stateCode = uCase(trim(toString(arguments.state)));
            var stateNames = getStateNameMap();

            if (structKeyExists(stateNames, stateCode)) {
                return stateNames[stateCode];
            }
            return stateCode;
        </cfscript>
    </cffunction>

    <cffunction name="getStateSlug" access="public" returntype="string" output="false">
        <cfargument name="state" type="string" required="true">
        <cfscript>
            return normalizeSlug(getStateDisplayName(arguments.state));
        </cfscript>
    </cffunction>

    <cffunction name="resolveStateCodeBySlug" access="public" returntype="string" output="false">
        <cfargument name="slug" type="string" required="true">
        <cfscript>
            var target = normalizeSlug(arguments.slug);
            var facets = getFacets("state");
            var i = 0;
            var stateCode = "";

            if (!len(target)) {
                return "";
            }

            for (i = 1; i LTE arrayLen(facets); i++) {
                stateCode = uCase(trim(toString(facets[i].value)));
                if (normalizeSlug(stateCode) EQ target OR getStateSlug(stateCode) EQ target) {
                    return stateCode;
                }
            }
            return "";
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

    <cffunction name="getStats" access="public" returntype="struct" output="false">
        <cfscript>
            var out = { "TOTAL_ROWS" = 0, "PUBLIC_ROWS" = 0, "STATE_COUNT" = 0, "WATERWAY_COUNT" = 0, "SYSTEM_COUNT" = 0 };
            var qTotal = queryExecute("SELECT COUNT(*) AS total_rows FROM great_loop_locks", {}, { datasource = getDatasource() });
            var qPublic = queryNew("");

            out.TOTAL_ROWS = val(qTotal.total_rows[1]);
            if (!hasPublicSchema()) {
                return out;
            }

            qPublic = queryExecute(
                "SELECT
                    COUNT(*) AS public_rows,
                    COUNT(DISTINCT NULLIF(TRIM(state), '')) AS state_count,
                    COUNT(DISTINCT NULLIF(TRIM(waterway), '')) AS waterway_count,
                    COUNT(DISTINCT NULLIF(TRIM(lock_system), '')) AS system_count
                 FROM great_loop_locks
                 WHERE is_public = 1
                   AND slug IS NOT NULL
                   AND TRIM(slug) <> ''",
                {},
                { datasource = getDatasource() }
            );
            out.PUBLIC_ROWS = val(qPublic.public_rows[1]);
            out.STATE_COUNT = val(qPublic.state_count[1]);
            out.WATERWAY_COUNT = val(qPublic.waterway_count[1]);
            out.SYSTEM_COUNT = val(qPublic.system_count[1]);
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="getFacets" access="public" returntype="array" output="false">
        <cfargument name="fieldName" type="string" required="true">
        <cfargument name="filters" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var allowed = "state,waterway,lock_system";
            var facetField = lCase(trim(arguments.fieldName));
            var out = [];
            var q = queryNew("");
            var i = 0;
            var normalized = normalizeFilters(arguments.filters);
            var params = {};
            var conditions = [
                "is_public = 1",
                "slug IS NOT NULL",
                "TRIM(slug) <> ''",
                facetField & " IS NOT NULL",
                "TRIM(" & facetField & ") <> ''"
            ];

            if (!hasPublicSchema() OR !listFindNoCase(allowed, facetField)) {
                return out;
            }

            if (facetField NEQ "state" AND len(normalized.state)) {
                arrayAppend(conditions, "state = :state");
                params.state = { value = normalized.state, cfsqltype = "cf_sql_varchar" };
            }
            if (facetField EQ "lock_system" AND len(normalized.waterway)) {
                arrayAppend(conditions, "waterway = :waterway");
                params.waterway = { value = normalized.waterway, cfsqltype = "cf_sql_varchar" };
            }

            q = queryExecute(
                "SELECT " & facetField & " AS facet_value, COUNT(*) AS row_count
                 FROM great_loop_locks
                 WHERE " & arrayToList(conditions, " AND ") & "
                 GROUP BY " & facetField & "
                 ORDER BY " & facetField & " ASC",
                params,
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
            var allowed = "state,waterway,lock_system";
            var facetField = lCase(trim(arguments.fieldName));
            var out = [];
            var q = queryNew("");
            var i = 0;

            if (!listFindNoCase(allowed, facetField)) {
                return out;
            }

            q = queryExecute(
                "SELECT " & facetField & " AS facet_value, COUNT(*) AS row_count
                 FROM great_loop_locks
                 WHERE " & facetField & " IS NOT NULL
                   AND TRIM(" & facetField & ") <> ''
                 GROUP BY " & facetField & "
                 ORDER BY " & facetField & " ASC",
                {},
                { datasource = getDatasource() }
            );

            for (i = 1; i LTE q.recordCount; i++) {
                arrayAppend(out, {
                    "value" = safeString(q.facet_value[i]),
                    "label" = safeString(q.facet_value[i]) & " (" & val(q.row_count[i]) & ")",
                    "count" = val(q.row_count[i])
                });
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeAdminFilters" access="private" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="true">
        <cfscript>
            var limitValue = val(readAny(arguments.filters, ["limit", "LIMIT"], "50"));
            var offsetValue = val(readAny(arguments.filters, ["offset", "OFFSET"], "0"));
            var publicStatus = lCase(trim(readAny(arguments.filters, ["publicStatus", "PUBLICSTATUS"], "")));
            var imageStatus = lCase(trim(readAny(arguments.filters, ["imageStatus", "IMAGESTATUS"], "")));

            if (limitValue LTE 0) limitValue = 50;
            if (limitValue GT 200) limitValue = 200;
            if (offsetValue LT 0) offsetValue = 0;
            if (!listFindNoCase("public,hidden", publicStatus)) publicStatus = "";
            if (!listFindNoCase("has,missing", imageStatus)) imageStatus = "";

            return {
                "q" = left(trim(readAny(arguments.filters, ["q", "Q", "search", "SEARCH"], "")), 120),
                "state" = left(trim(readAny(arguments.filters, ["state", "STATE"], "")), 16),
                "waterway" = left(trim(readAny(arguments.filters, ["waterway", "WATERWAY"], "")), 160),
                "lockSystem" = left(trim(readAny(arguments.filters, ["lockSystem", "LOCKSYSTEM", "lock_system", "LOCK_SYSTEM"], "")), 160),
                "publicStatus" = publicStatus,
                "imageStatus" = imageStatus,
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
                "state" = arguments.filters.state,
                "waterway" = arguments.filters.waterway,
                "lockSystem" = arguments.filters.lockSystem,
                "publicStatus" = arguments.filters.publicStatus,
                "imageStatus" = arguments.filters.imageStatus,
                "limit" = arguments.filters.limit,
                "offset" = arguments.filters.offset
            };
        </cfscript>
    </cffunction>

    <cffunction name="normalizeAdminLockPayload" access="private" returntype="struct" output="false">
        <cfargument name="payload" type="struct" required="true">
        <cfscript>
            var out = { "DATA" = {}, "ERRORS" = [] };
            var sourceUrl = left(trim(readAny(arguments.payload, ["source_url", "SOURCE_URL", "sourceUrl"], "")), 512);
            var lastReviewed = left(trim(readAny(arguments.payload, ["last_reviewed_at", "LAST_REVIEWED_AT", "lastReviewedAt"], "")), 10);
            var sortValue = trim(readAny(arguments.payload, ["sort_order", "SORT_ORDER", "sortOrder"], ""));
            var publicValue = readAny(arguments.payload, ["is_public", "IS_PUBLIC", "isPublic"], "1");

            out.DATA = {
                "id" = val(readAny(arguments.payload, ["id", "ID"], "0")),
                "lock_name" = left(trim(readAny(arguments.payload, ["lock_name", "LOCK_NAME", "lockName"], "")), 255),
                "slug" = normalizeSlug(readAny(arguments.payload, ["slug", "SLUG"], "")),
                "latitude" = trim(readAny(arguments.payload, ["latitude", "LATITUDE"], "")),
                "longitude" = trim(readAny(arguments.payload, ["longitude", "LONGITUDE"], "")),
                "note" = trim(readAny(arguments.payload, ["note", "NOTE"], "")),
                "city" = left(trim(readAny(arguments.payload, ["city", "CITY"], "")), 128),
                "state" = left(trim(readAny(arguments.payload, ["state", "STATE"], "")), 16),
                "zip" = left(trim(readAny(arguments.payload, ["zip", "ZIP"], "")), 32),
                "phone" = left(trim(readAny(arguments.payload, ["phone", "PHONE"], "")), 64),
                "vhf" = left(trim(readAny(arguments.payload, ["vhf", "VHF"], "")), 64),
                "waterway" = left(trim(readAny(arguments.payload, ["waterway", "WATERWAY"], "")), 160),
                "lock_system" = left(trim(readAny(arguments.payload, ["lock_system", "LOCK_SYSTEM", "lockSystem"], "")), 160),
                "operating_authority" = left(trim(readAny(arguments.payload, ["operating_authority", "OPERATING_AUTHORITY", "operatingAuthority"], "")), 160),
                "country" = uCase(left(trim(readAny(arguments.payload, ["country", "COUNTRY"], "")), 2)),
                "approach_notes" = trim(readAny(arguments.payload, ["approach_notes", "APPROACH_NOTES", "approachNotes"], "")),
                "operating_notes" = trim(readAny(arguments.payload, ["operating_notes", "OPERATING_NOTES", "operatingNotes"], "")),
                "special_instructions" = trim(readAny(arguments.payload, ["special_instructions", "SPECIAL_INSTRUCTIONS", "specialInstructions"], "")),
                "source_name" = left(trim(readAny(arguments.payload, ["source_name", "SOURCE_NAME", "sourceName"], "")), 160),
                "source_url" = sourceUrl,
                "last_reviewed_at" = lastReviewed,
                "is_public" = boolLike(publicValue) ? 1 : 0,
                "sort_order" = sortValue
            };

            if (out.DATA.id LTE 0) {
                arrayAppend(out.ERRORS, "Lock id is required.");
            }
            if (!len(out.DATA.lock_name)) {
                arrayAppend(out.ERRORS, "Lock name is required.");
            }
            if (!len(out.DATA.slug)) {
                arrayAppend(out.ERRORS, "Slug is required.");
            }
            if (!isNumeric(out.DATA.latitude) OR val(out.DATA.latitude) LT -90 OR val(out.DATA.latitude) GT 90) {
                arrayAppend(out.ERRORS, "Latitude must be a number between -90 and 90.");
            } else {
                out.DATA.latitude = val(out.DATA.latitude);
            }
            if (!isNumeric(out.DATA.longitude) OR val(out.DATA.longitude) LT -180 OR val(out.DATA.longitude) GT 180) {
                arrayAppend(out.ERRORS, "Longitude must be a number between -180 and 180.");
            } else {
                out.DATA.longitude = val(out.DATA.longitude);
            }
            if (len(sourceUrl) AND !isSafeHttpUrl(sourceUrl)) {
                arrayAppend(out.ERRORS, "Source URL must start with http:// or https://.");
            }
            if (len(lastReviewed) AND !isDate(lastReviewed)) {
                arrayAppend(out.ERRORS, "Last reviewed date must be a valid date.");
            }
            if (len(sortValue) AND !isNumeric(sortValue)) {
                arrayAppend(out.ERRORS, "Sort order must be numeric.");
            } else if (len(sortValue)) {
                out.DATA.sort_order = int(val(sortValue));
            }

            return out;
        </cfscript>
    </cffunction>

    <cffunction name="isSlugAvailable" access="private" returntype="boolean" output="false">
        <cfargument name="slug" type="string" required="true">
        <cfargument name="lockId" type="numeric" required="true">
        <cfscript>
            var q = queryExecute(
                "SELECT COUNT(*) AS match_count
                 FROM great_loop_locks
                 WHERE slug = :slug
                   AND id <> :lockId",
                {
                    slug = { value = arguments.slug, cfsqltype = "cf_sql_varchar" },
                    lockId = { value = val(arguments.lockId), cfsqltype = "cf_sql_bigint" }
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

    <cffunction name="nullableIntegerParam" access="private" returntype="struct" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfscript>
            var txt = trim(toString(isNull(arguments.value) ? "" : arguments.value));
            if (!len(txt)) {
                return { value = 0, cfsqltype = "cf_sql_integer", null = true };
            }
            return { value = int(val(txt)), cfsqltype = "cf_sql_integer" };
        </cfscript>
    </cffunction>

    <cffunction name="isSafeHttpUrl" access="private" returntype="boolean" output="false">
        <cfargument name="value" type="string" required="true">
        <cfscript>
            var txt = lCase(trim(arguments.value));
            return left(txt, 7) EQ "http://" OR left(txt, 8) EQ "https://";
        </cfscript>
    </cffunction>

    <cffunction name="renameImageForSlugChange" access="private" returntype="struct" output="false">
        <cfargument name="oldLock" type="struct" required="true">
        <cfargument name="newLock" type="struct" required="true">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var out = { "message" = "" };
            var oldSlug = normalizeSlug(arguments.oldLock.slug);
            var newSlug = normalizeSlug(arguments.newLock.slug);
            var oldAsset = {};
            var imageRoot = getLockImageRootPath();
            var thumbnailRoot = getLockThumbnailRootPath();
            var oldPath = "";
            var newFileName = "";
            var newPath = "";
            var oldThumbPath = "";
            var newThumbPath = "";
            var ext = "";

            if (!len(oldSlug) OR !len(newSlug) OR oldSlug EQ newSlug) {
                return out;
            }

            oldAsset = getLockImageAsset(arguments.oldLock, arguments.basePath);
            if (!oldAsset.hasImage) {
                return out;
            }

            ext = lCase(listLast(oldAsset.fileName, "."));
            newFileName = newSlug & "." & ext;
            if (oldAsset.fileName EQ newFileName) {
                return out;
            }

            oldPath = joinPath(imageRoot, oldAsset.fileName);
            newPath = joinPath(imageRoot, newFileName);
            oldThumbPath = joinPath(thumbnailRoot, oldAsset.fileName);
            newThumbPath = joinPath(thumbnailRoot, newFileName);

            if (fileExists(newPath)) {
                out.message = "Lock saved, but the existing image was not renamed because " & newFileName & " already exists.";
                return out;
            }

            try {
                if (fileExists(oldPath)) {
                    fileMove(oldPath, newPath);
                }
                if (fileExists(oldThumbPath) AND !fileExists(newThumbPath)) {
                    fileMove(oldThumbPath, newThumbPath);
                }
                out.message = "Lock saved and image filename was updated to " & newFileName & ".";
            } catch (any renameError) {
                out.message = "Lock saved, but the existing image filename could not be updated.";
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="deleteStaleLockImages" access="private" returntype="void" output="false">
        <cfargument name="lockRow" type="struct" required="true">
        <cfargument name="keepFileName" type="string" required="true">
        <cfscript>
            var imageRoot = getLockImageRootPath();
            var thumbnailRoot = getLockThumbnailRootPath();
            var extensions = ["jpg", "jpeg", "png", "webp"];
            var matchKeys = [];
            var slugKey = structKeyExists(arguments.lockRow, "slug") ? normalizeLockImageKey(arguments.lockRow.slug) : "";
            var nameKey = structKeyExists(arguments.lockRow, "lock_name") ? normalizeLockImageKey(arguments.lockRow.lock_name) : "";
            var candidate = "";
            var i = 0;
            var j = 0;

            if (len(slugKey)) arrayAppend(matchKeys, slugKey);
            if (len(nameKey) AND nameKey NEQ slugKey) arrayAppend(matchKeys, nameKey);

            for (i = 1; i LTE arrayLen(matchKeys); i++) {
                for (j = 1; j LTE arrayLen(extensions); j++) {
                    candidate = matchKeys[i] & "." & extensions[j];
                    if (candidate EQ arguments.keepFileName) {
                        continue;
                    }
                    safeDeleteFile(joinPath(imageRoot, candidate));
                    safeDeleteFile(joinPath(thumbnailRoot, candidate));
                }
            }
        </cfscript>
    </cffunction>

    <cffunction name="generateLockThumbnail" access="private" returntype="void" output="false">
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

    <cffunction name="normalizeLockImageKey" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfscript>
            var key = lCase(trim(toString(isNull(arguments.value) ? "" : arguments.value)));
            key = replace(key, "&", " and ", "all");
            key = reReplace(key, "[^a-z0-9]+", "-", "all");
            key = reReplace(key, "-{2,}", "-", "all");
            key = reReplace(key, "(^-|-$)", "", "all");
            return key;
        </cfscript>
    </cffunction>

    <cffunction name="isLockImageFile" access="private" returntype="boolean" output="false">
        <cfargument name="fileName" type="string" required="true">
        <cfscript>
            return listFindNoCase("jpg,jpeg,png,webp", listLast(arguments.fileName, ".")) GT 0;
        </cfscript>
    </cffunction>

    <cffunction name="buildLockImageAsset" access="private" returntype="struct" output="false">
        <cfargument name="fileName" type="string" required="true">
        <cfargument name="imageRootPath" type="string" required="true">
        <cfargument name="thumbnailRootPath" type="string" required="true">
        <cfargument name="imageBaseUrl" type="string" required="true">
        <cfscript>
            var sourcePath = joinPath(arguments.imageRootPath, arguments.fileName);
            var thumbnailPath = joinPath(arguments.thumbnailRootPath, arguments.fileName);
            var out = {
                "hasImage" = true,
                "fileName" = arguments.fileName,
                "sourceUrl" = imageUrlWithVersion(arguments.imageBaseUrl & "/" & arguments.fileName, sourcePath),
                "thumbnailUrl" = imageUrlWithVersion(arguments.imageBaseUrl & "/" & arguments.fileName, sourcePath),
                "hasThumbnail" = false
            };

            if (fileExists(thumbnailPath)) {
                out.thumbnailUrl = imageUrlWithVersion(arguments.imageBaseUrl & "/thumbnails/" & arguments.fileName, thumbnailPath);
                out.hasThumbnail = true;
            }
            return out;
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
            var normalized = replace(trim(arguments.path), chr(92), "/", "all");
            var prefix = "";
            var parts = [];
            var stack = [];
            var part = "";
            var i = 0;

            if (left(normalized, 2) EQ "//") {
                prefix = "//";
                normalized = mid(normalized, 3, len(normalized));
            } else if (len(normalized) GTE 2 AND mid(normalized, 2, 1) EQ ":") {
                prefix = left(normalized, 2);
                normalized = mid(normalized, 3, len(normalized));
                if (left(normalized, 1) EQ "/") {
                    normalized = mid(normalized, 2, len(normalized));
                }
            } else if (left(normalized, 1) EQ "/") {
                prefix = "/";
                normalized = mid(normalized, 2, len(normalized));
            }

            parts = listToArray(normalized, "/");
            for (i = 1; i LTE arrayLen(parts); i++) {
                part = parts[i];
                if (!len(part) OR part EQ ".") {
                    continue;
                }
                if (part EQ "..") {
                    if (arrayLen(stack)) {
                        arrayDeleteAt(stack, arrayLen(stack));
                    } else if (!len(prefix)) {
                        arrayAppend(stack, part);
                    }
                } else {
                    arrayAppend(stack, part);
                }
            }

            normalized = arrayToList(stack, "/");
            if (prefix EQ "/") {
                return "/" & normalized;
            }
            if (prefix EQ "//") {
                return "//" & normalized;
            }
            if (len(prefix)) {
                return prefix & (len(normalized) ? "/" & normalized : "");
            }
            return normalized;
        </cfscript>
    </cffunction>

    <cffunction name="getLockImageRootPath" access="private" returntype="string" output="false">
        <cfscript>
            var serviceDir = getDirectoryFromPath(getCurrentTemplatePath());
            return normalizeFilesystemPath(serviceDir & "../../assets/images/great-loop-locks");
        </cfscript>
    </cffunction>

    <cffunction name="getLockThumbnailRootPath" access="private" returntype="string" output="false">
        <cfscript>
            return joinPath(getLockImageRootPath(), "thumbnails");
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
            return reReplace(arguments.rootPath, "[/\\]+$", "", "all") & "/" & arguments.fileName;
        </cfscript>
    </cffunction>

    <cffunction name="safeDeleteFile" access="private" returntype="void" output="false">
        <cfargument name="filePath" type="string" required="true">
        <cfscript>
            try {
                if (fileExists(arguments.filePath)) {
                    fileDelete(arguments.filePath);
                }
            } catch (any ignored) {
            }
        </cfscript>
    </cffunction>

    <cffunction name="deleteImageFileIfSafe" access="private" returntype="boolean" output="false">
        <cfargument name="filePath" type="string" required="true">
        <cfargument name="rootPath" type="string" required="true">
        <cfscript>
            var canonicalRoot = "";
            var canonicalFile = "";
            var rootPrefix = "";

            if (!isLockImageFile(arguments.filePath)) {
                return false;
            }

            try {
                canonicalRoot = reReplace(normalizeFilesystemPath(arguments.rootPath), "/+$", "", "all");
                canonicalFile = normalizeFilesystemPath(arguments.filePath);
                rootPrefix = canonicalRoot & "/";

                if (find("/../", "/" & canonicalFile & "/") OR left(canonicalFile, len(rootPrefix)) NEQ rootPrefix) {
                    return false;
                }

                if (fileExists(canonicalFile)) {
                    fileDelete(canonicalFile);
                    return true;
                }
            } catch (any deleteError) {
                return false;
            }

            return false;
        </cfscript>
    </cffunction>

    <cffunction name="facetsToOptions" access="private" returntype="array" output="false">
        <cfargument name="facets" type="array" required="true">
        <cfscript>
            var out = [];
            var i = 0;
            var option = {};

            for (i = 1; i LTE arrayLen(arguments.facets); i++) {
                option = structNew("ordered");
                option["value"] = arguments.facets[i].value;
                option["label"] = arguments.facets[i].value & " (" & arguments.facets[i].count & ")";
                option["count"] = arguments.facets[i].count;
                arrayAppend(out, option);
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="buildFilterStruct" access="private" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="true">
        <cfscript>
            var out = structNew("ordered");

            out["q"] = arguments.filters.q;
            out["state"] = arguments.filters.state;
            out["waterway"] = arguments.filters.waterway;
            out["lockSystem"] = arguments.filters.lockSystem;
            out["hasVhf"] = arguments.filters.hasVhf;
            out["hasPhone"] = arguments.filters.hasPhone;
            out["hasNotes"] = arguments.filters.hasNotes;
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="buildSummary" access="private" returntype="struct" output="false">
        <cfargument name="rows" type="array" required="true">
        <cfscript>
            var out = structNew("ordered");
            var states = {};
            var waterways = {};
            var i = 0;
            var stateValue = "";
            var waterwayValue = "";

            for (i = 1; i LTE arrayLen(arguments.rows); i++) {
                stateValue = safeString(arguments.rows[i].state);
                waterwayValue = safeString(arguments.rows[i].waterway);
                if (len(stateValue)) {
                    states[stateValue] = true;
                }
                if (len(waterwayValue)) {
                    waterways[waterwayValue] = true;
                }
            }

            out["total"] = arrayLen(arguments.rows);
            out["states"] = structCount(states);
            out["waterways"] = structCount(waterways);
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="locksToApiRows" access="private" returntype="array" output="false">
        <cfargument name="rows" type="array" required="true">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var out = [];
            var i = 0;

            for (i = 1; i LTE arrayLen(arguments.rows); i++) {
                arrayAppend(out, lockToApiRow(arguments.rows[i], arguments.basePath));
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="lockToApiRow" access="private" returntype="struct" output="false">
        <cfargument name="lockRow" type="struct" required="true">
        <cfargument name="basePath" type="string" required="false" default="">
        <cfscript>
            var out = structNew("ordered");
            var cleanBasePath = reReplace(trim(toString(arguments.basePath)), "/$", "");

            if (cleanBasePath EQ "/") {
                cleanBasePath = "";
            }

            out["id"] = val(arguments.lockRow.id);
            out["lockName"] = safeString(arguments.lockRow.lock_name);
            out["slug"] = safeString(arguments.lockRow.slug);
            out["city"] = safeString(arguments.lockRow.city);
            out["state"] = safeString(arguments.lockRow.state);
            out["waterway"] = safeString(arguments.lockRow.waterway);
            out["lockSystem"] = safeString(arguments.lockRow.lock_system);
            out["latitude"] = isNumeric(arguments.lockRow.latitude) ? val(arguments.lockRow.latitude) : "";
            out["longitude"] = isNumeric(arguments.lockRow.longitude) ? val(arguments.lockRow.longitude) : "";
            out["phone"] = safeString(arguments.lockRow.phone);
            out["vhf"] = safeString(arguments.lockRow.vhf);
            out["detailUrl"] = cleanBasePath & "/app/great-loop-lock.cfm?slug=" & urlEncodedFormat(out["slug"]);
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeFilters" access="private" returntype="struct" output="false">
        <cfargument name="filters" type="struct" required="true">
        <cfscript>
            return {
                "q" = left(trim(safeGet(arguments.filters, "q")), 120),
                "state" = left(trim(safeGet(arguments.filters, "state")), 16),
                "waterway" = left(trim(safeGet(arguments.filters, "waterway")), 160),
                "lockSystem" = left(trim(safeGet(arguments.filters, "lockSystem")), 160),
                "hasVhf" = boolLike(safeGet(arguments.filters, "hasVhf")),
                "hasPhone" = boolLike(safeGet(arguments.filters, "hasPhone")),
                "hasNotes" = boolLike(safeGet(arguments.filters, "hasNotes")),
                "limit" = val(safeGet(arguments.filters, "limit", "300"))
            };
        </cfscript>
    </cffunction>

    <cffunction name="getAdjacentLocks" access="private" returntype="struct" output="false">
        <cfargument name="slug" type="string" required="true">
        <cfscript>
            var out = { "PREVIOUS" = {}, "NEXT" = {} };
            var q = queryExecute(
                "SELECT slug, lock_name
                 FROM great_loop_locks
                 WHERE is_public = 1
                   AND slug IS NOT NULL
                   AND TRIM(slug) <> ''
                 " & buildOrderSql(),
                {},
                { datasource = getDatasource() }
            );
            var i = 0;
            var currentSlug = normalizeSlug(arguments.slug);

            for (i = 1; i LTE q.recordCount; i++) {
                if (safeString(q.slug[i]) EQ currentSlug) {
                    if (i GT 1) {
                        out.PREVIOUS = { "slug" = safeString(q.slug[i - 1]), "lock_name" = safeString(q.lock_name[i - 1]) };
                    }
                    if (i LT q.recordCount) {
                        out.NEXT = { "slug" = safeString(q.slug[i + 1]), "lock_name" = safeString(q.lock_name[i + 1]) };
                    }
                    break;
                }
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

    <cffunction name="hasFacetValue" access="private" returntype="boolean" output="false">
        <cfargument name="fieldName" type="string" required="true">
        <cfargument name="value" type="string" required="true">
        <cfscript>
            var facets = getFacets(arguments.fieldName);
            var i = 0;
            for (i = 1; i LTE arrayLen(facets); i++) {
                if (compareNoCase(facets[i].value, arguments.value) EQ 0) {
                    return true;
                }
            }
            return false;
        </cfscript>
    </cffunction>

    <cffunction name="getStateNameMap" access="private" returntype="struct" output="false">
        <cfscript>
            return {
                "AL" = "Alabama",
                "FL" = "Florida",
                "IA" = "Iowa",
                "IL" = "Illinois",
                "IN" = "Indiana",
                "KY" = "Kentucky",
                "MN" = "Minnesota",
                "MO" = "Missouri",
                "MS" = "Mississippi",
                "NC" = "North Carolina",
                "NY" = "New York",
                "OH" = "Ohio",
                "ON" = "Ontario",
                "PA" = "Pennsylvania",
                "QC" = "Quebec",
                "TN" = "Tennessee",
                "VA" = "Virginia",
                "WI" = "Wisconsin",
                "WV" = "West Virginia"
            };
        </cfscript>
    </cffunction>

    <cffunction name="buildSelectSql" access="private" returntype="string" output="false">
        <cfscript>
            return "SELECT
                id,
                lock_name,
                " & selectColumn("slug", "''") & " AS slug,
                latitude,
                longitude,
                COALESCE(note, '') AS note,
                COALESCE(city, '') AS city,
                COALESCE(state, '') AS state,
                COALESCE(zip, '') AS zip,
                COALESCE(phone, '') AS phone,
                COALESCE(vhf, '') AS vhf,
                " & selectColumn("waterway", "''") & " AS waterway,
                " & selectColumn("lock_system", "''") & " AS lock_system,
                " & selectColumn("operating_authority", "''") & " AS operating_authority,
                " & selectColumn("country", "''") & " AS country,
                " & selectColumn("approach_notes", "''") & " AS approach_notes,
                " & selectColumn("operating_notes", "''") & " AS operating_notes,
                " & selectColumn("special_instructions", "''") & " AS special_instructions,
                " & selectColumn("source_name", "''") & " AS source_name,
                " & selectColumn("source_url", "''") & " AS source_url,
                " & selectColumn("last_reviewed_at", "NULL") & " AS last_reviewed_at,
                " & selectColumn("is_public", "0") & " AS is_public,
                " & selectColumn("sort_order", "NULL") & " AS sort_order,
                source_filename,
                source_sheet,
                import_batch_id,
                created_at,
                updated_at";
        </cfscript>
    </cffunction>

    <cffunction name="buildOrderSql" access="private" returntype="string" output="false">
        <cfscript>
            if (hasColumn("sort_order")) {
                return "ORDER BY CASE WHEN sort_order IS NULL THEN 1 ELSE 0 END ASC, sort_order ASC, lock_name ASC, id ASC";
            }
            return "ORDER BY lock_name ASC, id ASC";
        </cfscript>
    </cffunction>

    <cffunction name="rowToStruct" access="private" returntype="struct" output="false">
        <cfargument name="q" type="query" required="true">
        <cfargument name="rowIndex" type="numeric" required="true">
        <cfscript>
            return {
                "id" = val(arguments.q.id[arguments.rowIndex]),
                "lock_name" = safeString(arguments.q.lock_name[arguments.rowIndex]),
                "slug" = safeString(arguments.q.slug[arguments.rowIndex]),
                "latitude" = safeString(arguments.q.latitude[arguments.rowIndex]),
                "longitude" = safeString(arguments.q.longitude[arguments.rowIndex]),
                "note" = safeString(arguments.q.note[arguments.rowIndex]),
                "city" = safeString(arguments.q.city[arguments.rowIndex]),
                "state" = safeString(arguments.q.state[arguments.rowIndex]),
                "zip" = safeString(arguments.q.zip[arguments.rowIndex]),
                "phone" = safeString(arguments.q.phone[arguments.rowIndex]),
                "vhf" = safeString(arguments.q.vhf[arguments.rowIndex]),
                "waterway" = safeString(arguments.q.waterway[arguments.rowIndex]),
                "lock_system" = safeString(arguments.q.lock_system[arguments.rowIndex]),
                "operating_authority" = safeString(arguments.q.operating_authority[arguments.rowIndex]),
                "country" = safeString(arguments.q.country[arguments.rowIndex]),
                "approach_notes" = safeString(arguments.q.approach_notes[arguments.rowIndex]),
                "operating_notes" = safeString(arguments.q.operating_notes[arguments.rowIndex]),
                "special_instructions" = safeString(arguments.q.special_instructions[arguments.rowIndex]),
                "source_name" = safeString(arguments.q.source_name[arguments.rowIndex]),
                "source_url" = safeString(arguments.q.source_url[arguments.rowIndex]),
                "last_reviewed_at" = safeDateString(arguments.q.last_reviewed_at[arguments.rowIndex]),
                "is_public" = boolLike(arguments.q.is_public[arguments.rowIndex]),
                "sort_order" = safeString(arguments.q.sort_order[arguments.rowIndex])
            };
        </cfscript>
    </cffunction>

    <cffunction name="selectColumn" access="private" returntype="string" output="false">
        <cfargument name="columnName" type="string" required="true">
        <cfargument name="fallbackSql" type="string" required="true">
        <cfscript>
            if (hasColumn(arguments.columnName)) {
                return "COALESCE(" & arguments.columnName & ", " & arguments.fallbackSql & ")";
            }
            return arguments.fallbackSql;
        </cfscript>
    </cffunction>

    <cffunction name="hasPublicSchema" access="private" returntype="boolean" output="false">
        <cfscript>
            return hasColumn("slug") AND hasColumn("is_public") AND hasColumn("waterway") AND hasColumn("lock_system");
        </cfscript>
    </cffunction>

    <cffunction name="hasColumn" access="private" returntype="boolean" output="false">
        <cfargument name="columnName" type="string" required="true">
        <cfscript>
            var key = lCase(trim(arguments.columnName));
            var q = queryNew("");
            if (structKeyExists(variables.columnFlags, key)) {
                return variables.columnFlags[key];
            }
            q = queryExecute(
                "SELECT COUNT(*) AS column_count
                 FROM information_schema.columns
                 WHERE table_schema = DATABASE()
                   AND table_name = 'great_loop_locks'
                   AND column_name = :columnName",
                { columnName = { value = key, cfsqltype = "cf_sql_varchar" } },
                { datasource = getDatasource() }
            );
            variables.columnFlags[key] = (val(q.column_count[1]) GT 0);
            return variables.columnFlags[key];
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

    <cffunction name="safeDateString" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfscript>
            if (isNull(arguments.value) OR !len(trim(toString(arguments.value)))) {
                return "";
            }
            if (isDate(arguments.value)) {
                return dateFormat(arguments.value, "yyyy-mm-dd");
            }
            return left(trim(toString(arguments.value)), 10);
        </cfscript>
    </cffunction>

    <cffunction name="safeGet" access="private" returntype="string" output="false">
        <cfargument name="data" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfargument name="defaultValue" type="string" required="false" default="">
        <cfscript>
            if (structKeyExists(arguments.data, arguments.key) AND !isNull(arguments.data[arguments.key])) {
                return trim(toString(arguments.data[arguments.key]));
            }
            return arguments.defaultValue;
        </cfscript>
    </cffunction>

    <cffunction name="readAny" access="private" returntype="string" output="false">
        <cfargument name="data" type="struct" required="true">
        <cfargument name="keys" type="array" required="true">
        <cfargument name="defaultValue" type="string" required="false" default="">
        <cfscript>
            var i = 0;
            var keyName = "";
            for (i = 1; i LTE arrayLen(arguments.keys); i++) {
                keyName = arguments.keys[i];
                if (structKeyExists(arguments.data, keyName) AND !isNull(arguments.data[keyName])) {
                    return trim(toString(arguments.data[keyName]));
                }
            }
            return arguments.defaultValue;
        </cfscript>
    </cffunction>

    <cffunction name="boolLike" access="private" returntype="boolean" output="false">
        <cfargument name="value" type="any" required="false" default="">
        <cfscript>
            var txt = lCase(trim(toString(arguments.value)));
            if (!len(txt)) {
                return false;
            }
            if (listFindNoCase("1,true,yes,y,on", txt)) {
                return true;
            }
            if (listFindNoCase("0,false,no,n,off", txt)) {
                return false;
            }
            if (isNumeric(txt)) {
                return val(txt) NEQ 0;
            }
            return false;
        </cfscript>
    </cffunction>

    <cffunction name="isDefaultPublicLibraryFilters" access="private" returntype="boolean" output="false">
        <cfargument name="filters" type="struct" required="true">
        <cfscript>
            return !len(arguments.filters.q)
                AND !len(arguments.filters.state)
                AND !len(arguments.filters.waterway)
                AND !len(arguments.filters.lockSystem)
                AND !arguments.filters.hasVhf
                AND !arguments.filters.hasPhone
                AND !arguments.filters.hasNotes
                AND val(arguments.filters.limit) GTE 300;
        </cfscript>
    </cffunction>

    <cffunction name="buildLockLibraryCacheKey" access="private" returntype="string" output="false">
        <cfscript>
            return "fpw:great-loop-locks:library:v1:" & hash(getDatasource());
        </cfscript>
    </cffunction>

    <cffunction name="getCachedLockLibraryModel" access="private" returntype="struct" output="false">
        <cfscript>
            var cached = "";
            try {
                cached = cacheGet(buildLockLibraryCacheKey());
                if (isStruct(cached)) {
                    return duplicate(cached);
                }
            } catch (any cacheError) {
                return {};
            }
            return {};
        </cfscript>
    </cffunction>

    <cffunction name="putCachedLockLibraryModel" access="private" returntype="void" output="false">
        <cfargument name="model" type="struct" required="true">
        <cfscript>
            var ttl = createTimeSpan(0, 1, 0, 0);
            try {
                cachePut(buildLockLibraryCacheKey(), duplicate(arguments.model), ttl, ttl);
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
