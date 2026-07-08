<cfcomponent output="false" hint="Admin Great Loop ports management service.">

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

  <cffunction name="searchAdminPorts" access="public" returntype="struct" output="false">
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
        "FILTERS" = normalized
      };
      var conditions = [ "1=1" ];
      var params = {};
      var countParams = {};
      var sqlWhere = "";
      var qRows = queryNew("");
      var qCount = queryNew("");
      var row = {};
      var i = 0;

      if (len(normalized.q)) {
        arrayAppend(conditions, "(
          p.name LIKE :q
          OR COALESCE(p.state, '') LIKE :q
          OR COALESCE(p.region, '') LIKE :q
          OR COALESCE(pp.state_code, '') LIKE :q
          OR COALESCE(pp.country, '') LIKE :q
          OR COALESCE(pp.waterway, '') LIKE :q
          OR COALESCE(pp.loop_segment, '') LIKE :q
          OR COALESCE(pp.port_type, '') LIKE :q
        )");
        params.q = { value = "%" & normalized.q & "%", cfsqltype = "cf_sql_varchar" };
      }
      if (len(normalized.state)) {
        arrayAppend(conditions, "p.state = :state");
        params.state = { value = normalized.state, cfsqltype = "cf_sql_varchar" };
      }
      if (len(normalized.stateCode)) {
        arrayAppend(conditions, "pp.state_code = :stateCode");
        params.stateCode = { value = normalized.stateCode, cfsqltype = "cf_sql_varchar" };
      }
      if (len(normalized.loopSegment)) {
        arrayAppend(conditions, "pp.loop_segment = :loopSegment");
        params.loopSegment = { value = normalized.loopSegment, cfsqltype = "cf_sql_varchar" };
      }
      if (len(normalized.waterway)) {
        arrayAppend(conditions, "pp.waterway = :waterway");
        params.waterway = { value = normalized.waterway, cfsqltype = "cf_sql_varchar" };
      }
      if (len(normalized.qualityStatus)) {
        arrayAppend(conditions, "pp.data_quality_status = :qualityStatus");
        params.qualityStatus = { value = normalized.qualityStatus, cfsqltype = "cf_sql_varchar" };
      }
      if (normalized.coordStatus EQ "missing") {
        arrayAppend(conditions, "(p.lat IS NULL OR p.lng IS NULL OR p.lat = 0 OR p.lng = 0)");
      } else if (normalized.coordStatus EQ "has") {
        arrayAppend(conditions, "(p.lat IS NOT NULL AND p.lng IS NOT NULL AND p.lat <> 0 AND p.lng <> 0)");
      }
      if (normalized.imageStatus EQ "has") {
        arrayAppend(conditions, "(pi.image_allowed_for_fpw = 1 AND pi.local_image_path IS NOT NULL AND TRIM(pi.local_image_path) <> '')");
      } else if (normalized.imageStatus EQ "missing") {
        arrayAppend(conditions, "(pi.port_id IS NULL OR pi.image_allowed_for_fpw = 0 OR pi.local_image_path IS NULL OR TRIM(pi.local_image_path) = '')");
      }

      sqlWhere = arrayToList(conditions, " AND ");
      params.pageLimit = { value = normalized.limit, cfsqltype = "cf_sql_integer" };
      params.pageOffset = { value = normalized.offset, cfsqltype = "cf_sql_integer" };

      qRows = queryExecute(
        buildSelectSql() & "
        WHERE " & sqlWhere & "
        ORDER BY p.name ASC, p.state ASC, p.id ASC
        LIMIT :pageLimit
        OFFSET :pageOffset",
        params,
        { datasource = getDatasource() }
      );

      countParams = duplicate(params);
      structDelete(countParams, "pageLimit", false);
      structDelete(countParams, "pageOffset", false);
      qCount = queryExecute(
        "SELECT COUNT(*) AS total_count
         FROM ports p
         LEFT JOIN port_profiles pp ON pp.port_id = p.id
         LEFT JOIN port_images pi ON pi.port_id = p.id
         WHERE " & sqlWhere,
        countParams,
        { datasource = getDatasource() }
      );

      out.TOTAL = qCount.recordCount ? val(qCount.total_count[1]) : 0;
      for (i = 1; i LTE qRows.recordCount; i++) {
        row = rowToStruct(qRows, i, arguments.basePath);
        arrayAppend(out.ROWS, row);
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="getAdminFacets" access="public" returntype="struct" output="false">
    <cfscript>
      var out = structNew("ordered");
      out["states"] = getFacetOptions("p.state", "ports p INNER JOIN port_profiles pp ON pp.port_id = p.id");
      out["stateCodes"] = getFacetOptions("pp.state_code", "ports p INNER JOIN port_profiles pp ON pp.port_id = p.id");
      out["loopSegments"] = getFacetOptions("pp.loop_segment", "ports p INNER JOIN port_profiles pp ON pp.port_id = p.id");
      out["waterways"] = getFacetOptions("pp.waterway", "ports p INNER JOIN port_profiles pp ON pp.port_id = p.id");
      out["qualityStatuses"] = getFacetOptions("pp.data_quality_status", "ports p INNER JOIN port_profiles pp ON pp.port_id = p.id");
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="getPortById" access="public" returntype="struct" output="false">
    <cfargument name="portId" type="numeric" required="true">
    <cfargument name="basePath" type="string" required="false" default="">
    <cfscript>
      var out = { "SUCCESS" = false, "PORT" = {} };
      var q = queryExecute(
        buildSelectSql() & "
        WHERE p.id = :portId
        LIMIT 1",
        { portId = { value = val(arguments.portId), cfsqltype = "cf_sql_integer" } },
        { datasource = getDatasource() }
      );
      if (q.recordCount EQ 0) {
        out.MESSAGE = "Port not found.";
        return out;
      }
      out.SUCCESS = true;
      out.PORT = rowToStruct(q, 1, arguments.basePath);
      out.PORT.tagsText = arrayToList(getTagsForPort(arguments.portId), chr(10));
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="updatePort" access="public" returntype="struct" output="false">
    <cfargument name="portData" type="struct" required="true">
    <cfargument name="basePath" type="string" required="false" default="">
    <cfscript>
      var payloadResult = normalizePortPayload(arguments.portData);
      var payload = payloadResult.DATA;
      var out = { "SUCCESS" = false, "PORT" = {}, "ERRORS" = payloadResult.ERRORS };
      var savedResult = {};
      var i = 0;

      if (arrayLen(out.ERRORS)) {
        out.MESSAGE = "Validation failed.";
        return out;
      }
      if (!getPortById(payload.id, arguments.basePath).SUCCESS) {
        out.MESSAGE = "Port not found.";
        arrayAppend(out.ERRORS, "Port not found.");
        return out;
      }

      transaction {
        queryExecute(
          "UPDATE ports
           SET name = :name,
               state = :state,
               lat = :lat,
               lng = :lng,
               region = :region,
               is_major_port = :isMajorPort,
               is_hidden_gem = :isHiddenGem
           WHERE id = :portId",
          {
            name = { value = payload.name, cfsqltype = "cf_sql_varchar" },
            state = nullableParam(payload.state, "cf_sql_varchar"),
            lat = nullableDecimalParam(payload.lat, 7),
            lng = nullableDecimalParam(payload.lng, 7),
            region = nullableParam(payload.region, "cf_sql_varchar"),
            isMajorPort = { value = payload.is_major_port, cfsqltype = "cf_sql_tinyint" },
            isHiddenGem = { value = payload.is_hidden_gem, cfsqltype = "cf_sql_tinyint" },
            portId = { value = payload.id, cfsqltype = "cf_sql_integer" }
          },
          { datasource = getDatasource() }
        );

        queryExecute(
          "INSERT INTO port_profiles (
             port_id, state_code, country, waterway, loop_segment, mile_marker, port_type,
             short_description, approach_notes, services_summary, data_quality_status,
             source_notes, source_url, last_reviewed_at
           ) VALUES (
             :portId, :stateCode, :country, :waterway, :loopSegment, :mileMarker, :portType,
             :shortDescription, :approachNotes, :servicesSummary, :dataQualityStatus,
             :sourceNotes, :sourceUrl, :lastReviewedAt
           )
           ON DUPLICATE KEY UPDATE
             state_code = VALUES(state_code),
             country = VALUES(country),
             waterway = VALUES(waterway),
             loop_segment = VALUES(loop_segment),
             mile_marker = VALUES(mile_marker),
             port_type = VALUES(port_type),
             short_description = VALUES(short_description),
             approach_notes = VALUES(approach_notes),
             services_summary = VALUES(services_summary),
             data_quality_status = VALUES(data_quality_status),
             source_notes = VALUES(source_notes),
             source_url = VALUES(source_url),
             last_reviewed_at = VALUES(last_reviewed_at)",
          {
            portId = { value = payload.id, cfsqltype = "cf_sql_integer" },
            stateCode = nullableParam(payload.state_code, "cf_sql_varchar"),
            country = nullableParam(payload.country, "cf_sql_varchar"),
            waterway = nullableParam(payload.waterway, "cf_sql_varchar"),
            loopSegment = nullableParam(payload.loop_segment, "cf_sql_varchar"),
            mileMarker = nullableParam(payload.mile_marker, "cf_sql_varchar"),
            portType = nullableParam(payload.port_type, "cf_sql_varchar"),
            shortDescription = nullableParam(payload.short_description, "cf_sql_longvarchar"),
            approachNotes = nullableParam(payload.approach_notes, "cf_sql_longvarchar"),
            servicesSummary = nullableParam(payload.services_summary, "cf_sql_longvarchar"),
            dataQualityStatus = { value = payload.data_quality_status, cfsqltype = "cf_sql_varchar" },
            sourceNotes = nullableParam(payload.source_notes, "cf_sql_longvarchar"),
            sourceUrl = nullableParam(payload.source_url, "cf_sql_varchar"),
            lastReviewedAt = nullableDateTimeParam(payload.last_reviewed_at)
          },
          { datasource = getDatasource() }
        );

        queryExecute(
          "INSERT INTO port_services (
             port_id, fuel_available, diesel_available, gas_available, pumpout_available,
             transient_dockage_available, anchorage_available, mooring_available,
             provisioning_available, restaurants_nearby, marine_supply_nearby,
             laundry_nearby, transportation_nearby
           ) VALUES (
             :portId, :fuelAvailable, :dieselAvailable, :gasAvailable, :pumpoutAvailable,
             :transientDockageAvailable, :anchorageAvailable, :mooringAvailable,
             :provisioningAvailable, :restaurantsNearby, :marineSupplyNearby,
             :laundryNearby, :transportationNearby
           )
           ON DUPLICATE KEY UPDATE
             fuel_available = VALUES(fuel_available),
             diesel_available = VALUES(diesel_available),
             gas_available = VALUES(gas_available),
             pumpout_available = VALUES(pumpout_available),
             transient_dockage_available = VALUES(transient_dockage_available),
             anchorage_available = VALUES(anchorage_available),
             mooring_available = VALUES(mooring_available),
             provisioning_available = VALUES(provisioning_available),
             restaurants_nearby = VALUES(restaurants_nearby),
             marine_supply_nearby = VALUES(marine_supply_nearby),
             laundry_nearby = VALUES(laundry_nearby),
             transportation_nearby = VALUES(transportation_nearby)",
          {
            portId = { value = payload.id, cfsqltype = "cf_sql_integer" },
            fuelAvailable = nullableTinyintParam(payload.fuel_available),
            dieselAvailable = nullableTinyintParam(payload.diesel_available),
            gasAvailable = nullableTinyintParam(payload.gas_available),
            pumpoutAvailable = nullableTinyintParam(payload.pumpout_available),
            transientDockageAvailable = nullableTinyintParam(payload.transient_dockage_available),
            anchorageAvailable = nullableTinyintParam(payload.anchorage_available),
            mooringAvailable = nullableTinyintParam(payload.mooring_available),
            provisioningAvailable = nullableTinyintParam(payload.provisioning_available),
            restaurantsNearby = nullableTinyintParam(payload.restaurants_nearby),
            marineSupplyNearby = nullableTinyintParam(payload.marine_supply_nearby),
            laundryNearby = nullableTinyintParam(payload.laundry_nearby),
            transportationNearby = nullableTinyintParam(payload.transportation_nearby)
          },
          { datasource = getDatasource() }
        );

        queryExecute(
          "DELETE FROM port_tags WHERE port_id = :portId",
          { portId = { value = payload.id, cfsqltype = "cf_sql_integer" } },
          { datasource = getDatasource() }
        );
        for (i = 1; i LTE arrayLen(payload.tags); i++) {
          queryExecute(
            "INSERT INTO port_tags (port_id, tag) VALUES (:portId, :tag)",
            {
              portId = { value = payload.id, cfsqltype = "cf_sql_integer" },
              tag = { value = payload.tags[i], cfsqltype = "cf_sql_varchar" }
            },
            { datasource = getDatasource() }
          );
        }
      }

      savedResult = getPortById(payload.id, arguments.basePath);
      if (savedResult.SUCCESS) {
        out.SUCCESS = true;
        out.MESSAGE = "Port saved.";
        out.PORT = savedResult.PORT;
      } else {
        out.MESSAGE = "Port saved, but the updated row could not be reloaded.";
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="saveUploadedPortImage" access="public" returntype="struct" output="false">
    <cfargument name="portId" type="numeric" required="true">
    <cfargument name="uploadPath" type="string" required="true">
    <cfargument name="originalFileName" type="string" required="true">
    <cfargument name="basePath" type="string" required="false" default="">
    <cfscript>
      var out = { "SUCCESS" = false, "PORT" = {}, "IMAGE" = {}, "MESSAGE" = "" };
      var portResult = getPortById(arguments.portId, arguments.basePath);
      var portRow = {};
      var ext = lCase(trim(listLast(arguments.originalFileName, ".")));
      var img = "";
      var imageRoot = getPortImageRootPath();
      var thumbnailRoot = getPortThumbnailRootPath();
      var slugKey = "";
      var fileName = "";
      var localPath = "";
      var thumbPath = "";
      var relPath = "";
      var thumbRelPath = "";
      var mimeType = mimeTypeFromExtension(ext);

      if (!portResult.SUCCESS) {
        out.MESSAGE = "Port not found.";
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

      portRow = portResult.PORT;
      slugKey = normalizeSlug(readAny(portRow, ["slug", "SLUG"], ""));
      if (!len(slugKey)) {
        out.MESSAGE = "The port must have a valid slug before an image can be saved.";
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
      localPath = joinPath(imageRoot, fileName);
      thumbPath = joinPath(thumbnailRoot, fileName);
      relPath = "assets/images/great-loop-ports/" & fileName;
      thumbRelPath = "assets/images/great-loop-ports/thumbnails/" & fileName;

      deleteStalePortImages(portRow, fileName);
      if (fileExists(localPath)) {
        fileDelete(localPath);
      }
      fileCopy(arguments.uploadPath, localPath);

      try {
        generatePortThumbnail(localPath, thumbPath);
      } catch (any thumbnailError) {
        out.MESSAGE = "Image saved, but thumbnail generation failed.";
        return out;
      }

      queryExecute(
        "INSERT INTO port_images (
           port_id, local_image_path, thumbnail_image_path, original_filename,
           mime_type, image_alt, image_allowed_for_fpw
         ) VALUES (
           :portId, :localImagePath, :thumbnailImagePath, :originalFilename,
           :mimeType, :imageAlt, 1
         )
         ON DUPLICATE KEY UPDATE
           local_image_path = VALUES(local_image_path),
           thumbnail_image_path = VALUES(thumbnail_image_path),
           original_filename = VALUES(original_filename),
           mime_type = VALUES(mime_type),
           image_alt = VALUES(image_alt),
           image_allowed_for_fpw = 1",
        {
          portId = { value = val(arguments.portId), cfsqltype = "cf_sql_integer" },
          localImagePath = { value = relPath, cfsqltype = "cf_sql_varchar" },
          thumbnailImagePath = { value = thumbRelPath, cfsqltype = "cf_sql_varchar" },
          originalFilename = { value = left(trim(arguments.originalFileName), 255), cfsqltype = "cf_sql_varchar" },
          mimeType = { value = mimeType, cfsqltype = "cf_sql_varchar" },
          imageAlt = { value = left(safeString(portRow.name) & " port image", 255), cfsqltype = "cf_sql_varchar" }
        },
        { datasource = getDatasource() }
      );

      portResult = getPortById(arguments.portId, arguments.basePath);
      out.SUCCESS = true;
      out.MESSAGE = "Image saved.";
      out.PORT = portResult.PORT;
      out.IMAGE = portResult.PORT.image;
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="deletePortImage" access="public" returntype="struct" output="false">
    <cfargument name="portId" type="numeric" required="true">
    <cfargument name="basePath" type="string" required="false" default="">
    <cfscript>
      var out = { "SUCCESS" = false, "PORT" = {}, "IMAGE" = {}, "DELETED" = [], "MESSAGE" = "" };
      var portResult = getPortById(arguments.portId, arguments.basePath);
      var imageAsset = {};
      var localPath = "";
      var thumbPath = "";

      if (!portResult.SUCCESS) {
        out.MESSAGE = "Port not found.";
        return out;
      }
      imageAsset = portResult.PORT.image;
      if (!imageAsset.hasImage) {
        out.MESSAGE = "No port image was found.";
        out.PORT = portResult.PORT;
        out.IMAGE = imageAsset;
        return out;
      }

      localPath = imageAsset.localFilesystemPath;
      thumbPath = imageAsset.thumbnailFilesystemPath;
      if (len(localPath) AND fileExists(localPath)) {
        fileDelete(localPath);
        arrayAppend(out.DELETED, imageAsset.localImagePath);
      }
      if (len(thumbPath) AND fileExists(thumbPath)) {
        fileDelete(thumbPath);
        arrayAppend(out.DELETED, imageAsset.thumbnailImagePath);
      }

      queryExecute(
        "UPDATE port_images
         SET local_image_path = NULL,
             thumbnail_image_path = NULL,
             image_allowed_for_fpw = 0
         WHERE port_id = :portId",
        { portId = { value = val(arguments.portId), cfsqltype = "cf_sql_integer" } },
        { datasource = getDatasource() }
      );

      portResult = getPortById(arguments.portId, arguments.basePath);
      out.SUCCESS = true;
      out.MESSAGE = "Image deleted.";
      out.PORT = portResult.PORT;
      out.IMAGE = portResult.PORT.image;
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="deletePortById" access="public" returntype="struct" output="false">
    <cfargument name="portId" type="numeric" required="true">
    <cfargument name="basePath" type="string" required="false" default="">
    <cfscript>
      var portIdValue = toInt(arguments.portId);
      var out = { "SUCCESS" = false, "PORT" = {}, "PORT_ID" = portIdValue, "DELETED_FILES" = [], "MESSAGE" = "" };
      var portResult = {};
      var portParams = { portId = { value = portIdValue, cfsqltype = "cf_sql_integer" } };

      if (portIdValue LTE 0) {
        out.MESSAGE = "Port id is required.";
        return out;
      }

      portResult = getPortById(portIdValue, arguments.basePath);
      if (!portResult.SUCCESS) {
        out.MESSAGE = "Port not found.";
        return out;
      }

      transaction {
        queryExecute("DELETE FROM port_tags WHERE port_id = :portId", portParams, { datasource = getDatasource() });
        queryExecute("DELETE FROM port_nearby_assets WHERE port_id = :portId", portParams, { datasource = getDatasource() });
        queryExecute("DELETE FROM port_images WHERE port_id = :portId", portParams, { datasource = getDatasource() });
        queryExecute("DELETE FROM port_services WHERE port_id = :portId", portParams, { datasource = getDatasource() });
        queryExecute("DELETE FROM port_profiles WHERE port_id = :portId", portParams, { datasource = getDatasource() });
        queryExecute("DELETE FROM ports WHERE id = :portId", portParams, { datasource = getDatasource() });
      }

      out.DELETED_FILES = deletePortImageFiles(portResult.PORT);
      out.SUCCESS = true;
      out.MESSAGE = "Port deleted.";
      out.PORT = portResult.PORT;
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="buildSelectSql" access="private" returntype="string" output="false">
    <cfscript>
      return "SELECT
          p.id, p.name, p.state, p.lat, p.lng, p.region, p.is_major_port, p.is_hidden_gem,
          pp.slug, pp.state_code, pp.country, pp.waterway, pp.loop_segment, pp.mile_marker,
          pp.port_type, pp.short_description, pp.approach_notes, pp.services_summary,
          pp.data_quality_status, pp.source_notes, pp.source_url, pp.last_reviewed_at,
          pp.created_at AS profile_created_at, pp.updated_at AS profile_updated_at,
          ps.fuel_available, ps.diesel_available, ps.gas_available, ps.pumpout_available,
          ps.transient_dockage_available, ps.anchorage_available, ps.mooring_available,
          ps.provisioning_available, ps.restaurants_nearby, ps.marine_supply_nearby,
          ps.laundry_nearby, ps.transportation_nearby,
          pi.local_image_path, pi.thumbnail_image_path, pi.original_filename, pi.mime_type,
          pi.image_alt, pi.image_credit, pi.image_license, pi.image_source,
          pi.image_allowed_for_fpw, pi.updated_at AS image_updated_at
        FROM ports p
        LEFT JOIN port_profiles pp ON pp.port_id = p.id
        LEFT JOIN port_services ps ON ps.port_id = p.id
        LEFT JOIN port_images pi ON pi.port_id = p.id ";
    </cfscript>
  </cffunction>

  <cffunction name="rowToStruct" access="private" returntype="struct" output="false">
    <cfargument name="q" type="query" required="true">
    <cfargument name="rowIndex" type="numeric" required="true">
    <cfargument name="basePath" type="string" required="false" default="">
    <cfscript>
      var row = structNew("ordered");
      row["id"] = val(arguments.q.id[arguments.rowIndex]);
      row["name"] = safeString(arguments.q.name[arguments.rowIndex]);
      row["state"] = safeString(arguments.q.state[arguments.rowIndex]);
      row["lat"] = numericOrBlank(arguments.q.lat[arguments.rowIndex]);
      row["lng"] = numericOrBlank(arguments.q.lng[arguments.rowIndex]);
      row["region"] = safeString(arguments.q.region[arguments.rowIndex]);
      row["is_major_port"] = boolLike(arguments.q.is_major_port[arguments.rowIndex], false) ? 1 : 0;
      row["is_hidden_gem"] = boolLike(arguments.q.is_hidden_gem[arguments.rowIndex], false) ? 1 : 0;
      row["slug"] = safeString(arguments.q.slug[arguments.rowIndex]);
      row["state_code"] = safeString(arguments.q.state_code[arguments.rowIndex]);
      row["country"] = safeString(arguments.q.country[arguments.rowIndex]);
      row["waterway"] = safeString(arguments.q.waterway[arguments.rowIndex]);
      row["loop_segment"] = safeString(arguments.q.loop_segment[arguments.rowIndex]);
      row["mile_marker"] = safeString(arguments.q.mile_marker[arguments.rowIndex]);
      row["port_type"] = safeString(arguments.q.port_type[arguments.rowIndex]);
      row["short_description"] = safeString(arguments.q.short_description[arguments.rowIndex]);
      row["approach_notes"] = safeString(arguments.q.approach_notes[arguments.rowIndex]);
      row["services_summary"] = safeString(arguments.q.services_summary[arguments.rowIndex]);
      row["data_quality_status"] = safeString(arguments.q.data_quality_status[arguments.rowIndex]);
      row["source_notes"] = safeString(arguments.q.source_notes[arguments.rowIndex]);
      row["source_url"] = safeString(arguments.q.source_url[arguments.rowIndex]);
      row["last_reviewed_at"] = dateString(arguments.q.last_reviewed_at[arguments.rowIndex]);
      row["profile_updated_at"] = dateString(arguments.q.profile_updated_at[arguments.rowIndex]);
      row["fuel_available"] = nullableBoolValue(arguments.q.fuel_available[arguments.rowIndex]);
      row["diesel_available"] = nullableBoolValue(arguments.q.diesel_available[arguments.rowIndex]);
      row["gas_available"] = nullableBoolValue(arguments.q.gas_available[arguments.rowIndex]);
      row["pumpout_available"] = nullableBoolValue(arguments.q.pumpout_available[arguments.rowIndex]);
      row["transient_dockage_available"] = nullableBoolValue(arguments.q.transient_dockage_available[arguments.rowIndex]);
      row["anchorage_available"] = nullableBoolValue(arguments.q.anchorage_available[arguments.rowIndex]);
      row["mooring_available"] = nullableBoolValue(arguments.q.mooring_available[arguments.rowIndex]);
      row["provisioning_available"] = nullableBoolValue(arguments.q.provisioning_available[arguments.rowIndex]);
      row["restaurants_nearby"] = nullableBoolValue(arguments.q.restaurants_nearby[arguments.rowIndex]);
      row["marine_supply_nearby"] = nullableBoolValue(arguments.q.marine_supply_nearby[arguments.rowIndex]);
      row["laundry_nearby"] = nullableBoolValue(arguments.q.laundry_nearby[arguments.rowIndex]);
      row["transportation_nearby"] = nullableBoolValue(arguments.q.transportation_nearby[arguments.rowIndex]);
      row["local_image_path"] = safeString(arguments.q.local_image_path[arguments.rowIndex]);
      row["thumbnail_image_path"] = safeString(arguments.q.thumbnail_image_path[arguments.rowIndex]);
      row["original_filename"] = safeString(arguments.q.original_filename[arguments.rowIndex]);
      row["mime_type"] = safeString(arguments.q.mime_type[arguments.rowIndex]);
      row["image_alt"] = safeString(arguments.q.image_alt[arguments.rowIndex]);
      row["image_credit"] = safeString(arguments.q.image_credit[arguments.rowIndex]);
      row["image_license"] = safeString(arguments.q.image_license[arguments.rowIndex]);
      row["image_source"] = safeString(arguments.q.image_source[arguments.rowIndex]);
      row["image_allowed_for_fpw"] = boolLike(arguments.q.image_allowed_for_fpw[arguments.rowIndex], false) ? 1 : 0;
      row["image"] = getPortImageAsset(row, arguments.basePath);
      row["hasImage"] = row.image.hasImage;
      row["imageFileName"] = row.image.fileName;
      return row;
    </cfscript>
  </cffunction>

  <cffunction name="normalizeAdminFilters" access="private" returntype="struct" output="false">
    <cfargument name="filters" type="struct" required="true">
    <cfscript>
      var out = {
        "q" = left(trim(toString(readAny(arguments.filters, ["q", "Q", "search"], ""))), 160),
        "state" = left(trim(toString(readAny(arguments.filters, ["state", "STATE"], ""))), 80),
        "stateCode" = left(trim(toString(readAny(arguments.filters, ["stateCode", "state_code", "STATE_CODE"], ""))), 10),
        "loopSegment" = left(trim(toString(readAny(arguments.filters, ["loopSegment", "loop_segment", "LOOP_SEGMENT"], ""))), 160),
        "waterway" = left(trim(toString(readAny(arguments.filters, ["waterway", "WATERWAY"], ""))), 160),
        "qualityStatus" = left(trim(toString(readAny(arguments.filters, ["qualityStatus", "data_quality_status", "DATA_QUALITY_STATUS"], ""))), 40),
        "coordStatus" = lCase(left(trim(toString(readAny(arguments.filters, ["coordStatus", "coord_status"], ""))), 20)),
        "imageStatus" = lCase(left(trim(toString(readAny(arguments.filters, ["imageStatus", "image_status"], ""))), 20)),
        "limit" = toInt(readAny(arguments.filters, ["limit", "LIMIT"], 50)),
        "offset" = toInt(readAny(arguments.filters, ["offset", "OFFSET"], 0))
      };
      if (out.limit LTE 0) out.limit = 50;
      if (out.limit GT 200) out.limit = 200;
      if (out.offset LT 0) out.offset = 0;
      if (!listFindNoCase("has,missing", out.coordStatus)) out.coordStatus = "";
      if (!listFindNoCase("has,missing", out.imageStatus)) out.imageStatus = "";
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="normalizePortPayload" access="private" returntype="struct" output="false">
    <cfargument name="payload" type="struct" required="true">
    <cfscript>
      var out = { "DATA" = {}, "ERRORS" = [] };
      var sourceUrl = left(trim(toString(readAny(arguments.payload, ["source_url", "SOURCE_URL", "sourceUrl"], ""))), 500);
      var lastReviewedAt = left(trim(toString(readAny(arguments.payload, ["last_reviewed_at", "LAST_REVIEWED_AT", "lastReviewedAt"], ""))), 25);
      var qualityStatus = lCase(left(trim(toString(readAny(arguments.payload, ["data_quality_status", "DATA_QUALITY_STATUS", "dataQualityStatus"], "needs_review"))), 40));
      var serviceKeys = [
        "fuel_available", "diesel_available", "gas_available", "pumpout_available",
        "transient_dockage_available", "anchorage_available", "mooring_available",
        "provisioning_available", "restaurants_nearby", "marine_supply_nearby",
        "laundry_nearby", "transportation_nearby"
      ];
      var key = "";
      var serviceValue = "";
      var i = 0;

      out.DATA = {
        "id" = val(readAny(arguments.payload, ["id", "ID", "port_id", "PORT_ID"], 0)),
        "name" = left(trim(toString(readAny(arguments.payload, ["name", "NAME"], ""))), 160),
        "state" = left(trim(toString(readAny(arguments.payload, ["state", "STATE"], ""))), 80),
        "lat" = trim(toString(readAny(arguments.payload, ["lat", "LAT"], ""))),
        "lng" = trim(toString(readAny(arguments.payload, ["lng", "LNG"], ""))),
        "region" = left(trim(toString(readAny(arguments.payload, ["region", "REGION"], ""))), 80),
        "is_major_port" = boolLike(readAny(arguments.payload, ["is_major_port", "IS_MAJOR_PORT", "isMajorPort"], 0), false) ? 1 : 0,
        "is_hidden_gem" = boolLike(readAny(arguments.payload, ["is_hidden_gem", "IS_HIDDEN_GEM", "isHiddenGem"], 0), false) ? 1 : 0,
        "state_code" = left(trim(toString(readAny(arguments.payload, ["state_code", "STATE_CODE", "stateCode"], ""))), 10),
        "country" = left(trim(toString(readAny(arguments.payload, ["country", "COUNTRY"], ""))), 80),
        "waterway" = left(trim(toString(readAny(arguments.payload, ["waterway", "WATERWAY"], ""))), 160),
        "loop_segment" = left(trim(toString(readAny(arguments.payload, ["loop_segment", "LOOP_SEGMENT", "loopSegment"], ""))), 160),
        "mile_marker" = left(trim(toString(readAny(arguments.payload, ["mile_marker", "MILE_MARKER", "mileMarker"], ""))), 80),
        "port_type" = left(trim(toString(readAny(arguments.payload, ["port_type", "PORT_TYPE", "portType"], ""))), 80),
        "short_description" = trim(toString(readAny(arguments.payload, ["short_description", "SHORT_DESCRIPTION", "shortDescription"], ""))),
        "approach_notes" = trim(toString(readAny(arguments.payload, ["approach_notes", "APPROACH_NOTES", "approachNotes"], ""))),
        "services_summary" = trim(toString(readAny(arguments.payload, ["services_summary", "SERVICES_SUMMARY", "servicesSummary"], ""))),
        "data_quality_status" = len(qualityStatus) ? qualityStatus : "needs_review",
        "source_notes" = trim(toString(readAny(arguments.payload, ["source_notes", "SOURCE_NOTES", "sourceNotes"], ""))),
        "source_url" = sourceUrl,
        "last_reviewed_at" = lastReviewedAt,
        "tags" = normalizeTags(readAny(arguments.payload, ["tagsText", "tags", "TAGS"], ""))
      };

      for (i = 1; i LTE arrayLen(serviceKeys); i++) {
        key = serviceKeys[i];
        serviceValue = trim(toString(readAny(arguments.payload, [key, uCase(key)], "")));
        if (len(serviceValue) AND !listFindNoCase("0,1,true,false,yes,no", serviceValue)) {
          arrayAppend(out.ERRORS, replace(key, "_", " ", "all") & " must be yes, no, or unknown.");
        }
        out.DATA[key] = normalizeNullableTinyintValue(serviceValue);
      }

      if (out.DATA.id LTE 0) {
        arrayAppend(out.ERRORS, "Port id is required.");
      }
      if (!len(out.DATA.name)) {
        arrayAppend(out.ERRORS, "Port name is required.");
      }
      if (len(out.DATA.lat)) {
        if (!isNumeric(out.DATA.lat) OR val(out.DATA.lat) LT -90 OR val(out.DATA.lat) GT 90) {
          arrayAppend(out.ERRORS, "Latitude must be a number between -90 and 90.");
        } else {
          out.DATA.lat = val(out.DATA.lat);
        }
      }
      if (len(out.DATA.lng)) {
        if (!isNumeric(out.DATA.lng) OR val(out.DATA.lng) LT -180 OR val(out.DATA.lng) GT 180) {
          arrayAppend(out.ERRORS, "Longitude must be a number between -180 and 180.");
        } else {
          out.DATA.lng = val(out.DATA.lng);
        }
      }
      if (len(sourceUrl) AND !isSafeHttpUrl(sourceUrl)) {
        arrayAppend(out.ERRORS, "Source URL must start with http:// or https://.");
      }
      if (len(lastReviewedAt) AND !isDate(lastReviewedAt)) {
        arrayAppend(out.ERRORS, "Last reviewed must be a valid date or datetime.");
      }
      if (!listFindNoCase("verified,derived_unverified,needs_review,bad_coordinates,missing_coordinates,duplicate_name_review", out.DATA.data_quality_status)) {
        arrayAppend(out.ERRORS, "Data quality status is not recognized.");
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="getFacetOptions" access="private" returntype="array" output="false">
    <cfargument name="fieldExpression" type="string" required="true">
    <cfargument name="fromSql" type="string" required="true">
    <cfscript>
      var q = queryExecute(
        "SELECT DISTINCT " & arguments.fieldExpression & " AS value
         FROM " & arguments.fromSql & "
         WHERE " & arguments.fieldExpression & " IS NOT NULL
           AND TRIM(" & arguments.fieldExpression & ") <> ''
         ORDER BY " & arguments.fieldExpression & " ASC",
        {},
        { datasource = getDatasource() }
      );
      var out = [];
      var i = 0;
      for (i = 1; i LTE q.recordCount; i++) {
        arrayAppend(out, { "value" = safeString(q.value[i]), "label" = safeString(q.value[i]) });
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="getTagsForPort" access="private" returntype="array" output="false">
    <cfargument name="portId" type="numeric" required="true">
    <cfscript>
      var q = queryExecute(
        "SELECT tag FROM port_tags WHERE port_id = :portId ORDER BY tag ASC",
        { portId = { value = val(arguments.portId), cfsqltype = "cf_sql_integer" } },
        { datasource = getDatasource() }
      );
      var out = [];
      var i = 0;
      for (i = 1; i LTE q.recordCount; i++) {
        arrayAppend(out, safeString(q.tag[i]));
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="normalizeTags" access="private" returntype="array" output="false">
    <cfargument name="value" required="false" default="">
    <cfscript>
      var raw = "";
      var parts = [];
      var seen = {};
      var out = [];
      var tag = "";
      var key = "";
      var i = 0;

      if (isArray(arguments.value)) {
        parts = arguments.value;
      } else {
        raw = replace(toString(arguments.value), chr(13), chr(10), "all");
        raw = replace(raw, ",", chr(10), "all");
        parts = listToArray(raw, chr(10), false, true);
      }

      for (i = 1; i LTE arrayLen(parts); i++) {
        tag = left(trim(toString(parts[i])), 80);
        if (!len(tag)) continue;
        key = lCase(tag);
        if (!structKeyExists(seen, key)) {
          seen[key] = true;
          arrayAppend(out, tag);
        }
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="getPortImageAsset" access="public" returntype="struct" output="false">
    <cfargument name="portRow" type="struct" required="true">
    <cfargument name="basePath" type="string" required="false" default="">
    <cfscript>
      var out = {
        "hasImage" = false,
        "hasThumbnail" = false,
        "fileName" = "",
        "url" = "",
        "sourceUrl" = "",
        "thumbnailUrl" = "",
        "localImagePath" = "",
        "thumbnailImagePath" = "",
        "localFilesystemPath" = "",
        "thumbnailFilesystemPath" = "",
        "isPlaceholder" = false
      };
      var allowed = boolLike(readAny(arguments.portRow, ["image_allowed_for_fpw", "IMAGE_ALLOWED_FOR_FPW"], ""), false);
      var rel = normalizePortImageRelativePath(readAny(arguments.portRow, ["local_image_path", "LOCAL_IMAGE_PATH"], ""));
      var thumbRel = normalizePortImageRelativePath(readAny(arguments.portRow, ["thumbnail_image_path", "THUMBNAIL_IMAGE_PATH"], ""));
      var repoRoot = getRepoRootPath();
      var cleanBasePath = reReplace(trim(toString(arguments.basePath)), "/$", "");
      var sourcePath = "";
      var thumbnailPath = "";

      if (!len(cleanBasePath) OR cleanBasePath EQ "/") cleanBasePath = "";
      if (!allowed OR !len(rel)) {
        return out;
      }

      sourcePath = joinPath(repoRoot, rel);
      if (!fileExists(sourcePath)) {
        return out;
      }

      out.hasImage = true;
      out.fileName = listLast(rel, "/");
      out.localImagePath = rel;
      out.localFilesystemPath = sourcePath;
      out.sourceUrl = imageUrlWithVersion(cleanBasePath & "/" & rel, sourcePath);
      out.url = out.sourceUrl;

      if (len(thumbRel)) {
        thumbnailPath = joinPath(repoRoot, thumbRel);
        out.thumbnailImagePath = thumbRel;
        out.thumbnailFilesystemPath = thumbnailPath;
        if (fileExists(thumbnailPath)) {
          out.hasThumbnail = true;
          out.thumbnailUrl = imageUrlWithVersion(cleanBasePath & "/" & thumbRel, thumbnailPath);
          out.url = out.thumbnailUrl;
        }
      }
      if (!len(out.thumbnailUrl)) {
        out.thumbnailUrl = out.sourceUrl;
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="deletePortImageFiles" access="private" returntype="array" output="false">
    <cfargument name="portRow" type="struct" required="true">
    <cfscript>
      var deleted = [];
      var repoRoot = getRepoRootPath();
      var rel = normalizePortImageRelativePath(readAny(arguments.portRow, ["local_image_path", "LOCAL_IMAGE_PATH"], ""));
      var thumbRel = normalizePortImageRelativePath(readAny(arguments.portRow, ["thumbnail_image_path", "THUMBNAIL_IMAGE_PATH"], ""));
      var localPath = "";
      var thumbPath = "";

      if (len(rel)) {
        localPath = joinPath(repoRoot, rel);
        if (fileExists(localPath)) {
          safeDeleteFile(localPath);
          if (!fileExists(localPath)) {
            arrayAppend(deleted, rel);
          }
        }
      }
      if (len(thumbRel)) {
        thumbPath = joinPath(repoRoot, thumbRel);
        if (fileExists(thumbPath)) {
          safeDeleteFile(thumbPath);
          if (!fileExists(thumbPath)) {
            arrayAppend(deleted, thumbRel);
          }
        }
      }
      return deleted;
    </cfscript>
  </cffunction>

  <cffunction name="deleteStalePortImages" access="private" returntype="void" output="false">
    <cfargument name="portRow" type="struct" required="true">
    <cfargument name="keepFileName" type="string" required="true">
    <cfscript>
      var imageRoot = getPortImageRootPath();
      var thumbnailRoot = getPortThumbnailRootPath();
      var slugKey = normalizeSlug(readAny(arguments.portRow, ["slug", "SLUG"], ""));
      var extensions = ["jpg", "jpeg", "png", "webp"];
      var candidate = "";
      var i = 0;
      if (!len(slugKey)) return;
      for (i = 1; i LTE arrayLen(extensions); i++) {
        candidate = slugKey & "." & extensions[i];
        if (candidate EQ arguments.keepFileName) continue;
        safeDeleteFile(joinPath(imageRoot, candidate));
        safeDeleteFile(joinPath(thumbnailRoot, candidate));
      }
    </cfscript>
  </cffunction>

  <cffunction name="generatePortThumbnail" access="private" returntype="void" output="false">
    <cfargument name="sourcePath" type="string" required="true">
    <cfargument name="thumbnailPath" type="string" required="true">
    <cfscript>
      var thumbImage = imageRead(arguments.sourcePath);
      imageScaleToFit(thumbImage, 480, 320);
      if (fileExists(arguments.thumbnailPath)) {
        fileDelete(arguments.thumbnailPath);
      }
      imageWrite(thumbImage, arguments.thumbnailPath);
    </cfscript>
  </cffunction>

  <cffunction name="normalizePortImageRelativePath" access="private" returntype="string" output="false">
    <cfargument name="value" required="false" default="">
    <cfscript>
      var rel = replace(trim(toString(isNull(arguments.value) ? "" : arguments.value)), "\", "/", "all");
      var fileName = "";
      if (!len(rel)) return "";
      if (find("..", rel)) return "";
      fileName = listLast(rel, "/");
      if (!len(fileName)) return "";
      if (findNoCase("assets/images/great-loop-ports/", rel) NEQ 1) {
        rel = "assets/images/great-loop-ports/" & fileName;
      }
      return rel;
    </cfscript>
  </cffunction>

  <cffunction name="getPortImageRootPath" access="private" returntype="string" output="false">
    <cfscript>
      return reReplace(normalizeFilesystemPath(getRepoRootPath() & "assets/images/great-loop-ports"), "/+$", "", "all");
    </cfscript>
  </cffunction>

  <cffunction name="getPortThumbnailRootPath" access="private" returntype="string" output="false">
    <cfscript>
      return joinPath(getPortImageRootPath(), "thumbnails");
    </cfscript>
  </cffunction>

  <cffunction name="getRepoRootPath" access="private" returntype="string" output="false">
    <cfscript>
      var serviceDir = getDirectoryFromPath(getCurrentTemplatePath());
      return reReplace(normalizeFilesystemPath(serviceDir & "../../"), "/+$", "/", "all");
    </cfscript>
  </cffunction>

  <cffunction name="ensureDirectory" access="private" returntype="void" output="false">
    <cfargument name="path" type="string" required="true">
    <cfscript>
      if (!directoryExists(arguments.path)) {
        directoryCreate(arguments.path, true, true);
      }
    </cfscript>
  </cffunction>

  <cffunction name="safeDeleteFile" access="private" returntype="void" output="false">
    <cfargument name="path" type="string" required="true">
    <cfscript>
      try {
        if (len(trim(arguments.path)) AND fileExists(arguments.path)) {
          fileDelete(arguments.path);
        }
      } catch (any ignored) {
      }
    </cfscript>
  </cffunction>

  <cffunction name="normalizeSlug" access="private" returntype="string" output="false">
    <cfargument name="value" required="false" default="">
    <cfscript>
      var txt = lCase(trim(toString(isNull(arguments.value) ? "" : arguments.value)));
      txt = reReplace(txt, "[^a-z0-9]+", "-", "all");
      txt = reReplace(txt, "^-+|-+$", "", "all");
      return left(txt, 220);
    </cfscript>
  </cffunction>

  <cffunction name="imageUrlWithVersion" access="private" returntype="string" output="false">
    <cfargument name="url" type="string" required="true">
    <cfargument name="path" type="string" required="true">
    <cfscript>
      var token = "";
      try {
        token = dateFormat(getFileInfo(arguments.path).lastModified, "yyyymmdd") & timeFormat(getFileInfo(arguments.path).lastModified, "HHmmss");
      } catch (any ignored) {
        token = createUUID();
      }
      return arguments.url & "?v=" & token;
    </cfscript>
  </cffunction>

  <cffunction name="joinPath" access="private" returntype="string" output="false">
    <cfargument name="leftPath" type="string" required="true">
    <cfargument name="rightPath" type="string" required="true">
    <cfscript>
      return reReplace(normalizeFilesystemPath(arguments.leftPath), "/+$", "", "all") & "/" & reReplace(normalizeFilesystemPath(arguments.rightPath), "^/+", "", "all");
    </cfscript>
  </cffunction>

  <cffunction name="normalizeFilesystemPath" access="private" returntype="string" output="false">
    <cfargument name="path" type="string" required="true">
    <cfscript>
      return replace(arguments.path, "\", "/", "all");
    </cfscript>
  </cffunction>

  <cffunction name="nullableParam" access="private" returntype="struct" output="false">
    <cfargument name="value" required="false" default="">
    <cfargument name="sqlType" type="string" required="true">
    <cfscript>
      var txt = trim(toString(isNull(arguments.value) ? "" : arguments.value));
      if (!len(txt)) return { value = "", cfsqltype = arguments.sqlType, null = true };
      return { value = txt, cfsqltype = arguments.sqlType };
    </cfscript>
  </cffunction>

  <cffunction name="nullableDecimalParam" access="private" returntype="struct" output="false">
    <cfargument name="value" required="false" default="">
    <cfargument name="scale" type="numeric" required="false" default="7">
    <cfscript>
      var txt = trim(toString(isNull(arguments.value) ? "" : arguments.value));
      if (!len(txt)) return { value = 0, cfsqltype = "cf_sql_decimal", scale = arguments.scale, null = true };
      return { value = val(txt), cfsqltype = "cf_sql_decimal", scale = arguments.scale };
    </cfscript>
  </cffunction>

  <cffunction name="nullableTinyintParam" access="private" returntype="struct" output="false">
    <cfargument name="value" required="false" default="">
    <cfscript>
      var txt = trim(toString(isNull(arguments.value) ? "" : arguments.value));
      if (!len(txt)) return { value = 0, cfsqltype = "cf_sql_tinyint", null = true };
      return { value = normalizeNullableTinyintValue(txt), cfsqltype = "cf_sql_tinyint" };
    </cfscript>
  </cffunction>

  <cffunction name="nullableDateTimeParam" access="private" returntype="struct" output="false">
    <cfargument name="value" required="false" default="">
    <cfscript>
      var txt = trim(toString(isNull(arguments.value) ? "" : arguments.value));
      if (!len(txt)) return { value = "", cfsqltype = "cf_sql_timestamp", null = true };
      return { value = txt, cfsqltype = "cf_sql_timestamp" };
    </cfscript>
  </cffunction>

  <cffunction name="normalizeNullableTinyintValue" access="private" returntype="string" output="false">
    <cfargument name="value" required="false" default="">
    <cfscript>
      var txt = lCase(trim(toString(isNull(arguments.value) ? "" : arguments.value)));
      if (!len(txt)) return "";
      if (listFindNoCase("1,true,yes,y,on", txt)) return "1";
      if (listFindNoCase("0,false,no,n,off", txt)) return "0";
      return txt;
    </cfscript>
  </cffunction>

  <cffunction name="nullableBoolValue" access="private" returntype="string" output="false">
    <cfargument name="value" required="false" default="">
    <cfscript>
      if (isNull(arguments.value) OR !len(trim(toString(arguments.value)))) return "";
      return boolLike(arguments.value, false) ? "1" : "0";
    </cfscript>
  </cffunction>

  <cffunction name="numericOrBlank" access="private" returntype="string" output="false">
    <cfargument name="value" required="false" default="">
    <cfscript>
      if (isNull(arguments.value) OR !len(trim(toString(arguments.value)))) return "";
      return toString(arguments.value);
    </cfscript>
  </cffunction>

  <cffunction name="dateString" access="private" returntype="string" output="false">
    <cfargument name="value" required="false" default="">
    <cfscript>
      if (isNull(arguments.value) OR !len(trim(toString(arguments.value)))) return "";
      try {
        return dateTimeFormat(arguments.value, "yyyy-mm-dd HH:nn:ss");
      } catch (any ignored) {
        return trim(toString(arguments.value));
      }
    </cfscript>
  </cffunction>

  <cffunction name="safeString" access="private" returntype="string" output="false">
    <cfargument name="value" required="false" default="">
    <cfscript>
      if (isNull(arguments.value)) return "";
      return trim(toString(arguments.value));
    </cfscript>
  </cffunction>

  <cffunction name="isSafeHttpUrl" access="private" returntype="boolean" output="false">
    <cfargument name="value" type="string" required="true">
    <cfscript>
      var txt = lCase(trim(arguments.value));
      return left(txt, 7) EQ "http://" OR left(txt, 8) EQ "https://";
    </cfscript>
  </cffunction>

  <cffunction name="mimeTypeFromExtension" access="private" returntype="string" output="false">
    <cfargument name="extension" type="string" required="true">
    <cfscript>
      var ext = lCase(trim(arguments.extension));
      if (ext EQ "jpg" OR ext EQ "jpeg") return "image/jpeg";
      if (ext EQ "png") return "image/png";
      if (ext EQ "webp") return "image/webp";
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="readAny" access="private" returntype="any" output="false">
    <cfargument name="source" type="struct" required="true">
    <cfargument name="keys" type="array" required="true">
    <cfargument name="defaultValue" required="false" default="">
    <cfscript>
      var i = 0;
      for (i = 1; i LTE arrayLen(arguments.keys); i++) {
        if (structKeyExists(arguments.source, arguments.keys[i])) {
          return arguments.source[arguments.keys[i]];
        }
      }
      return arguments.defaultValue;
    </cfscript>
  </cffunction>

  <cffunction name="boolLike" access="private" returntype="boolean" output="false">
    <cfargument name="value" required="false" default="">
    <cfargument name="defaultValue" type="boolean" required="false" default="false">
    <cfscript>
      var txt = lCase(trim(toString(isNull(arguments.value) ? "" : arguments.value)));
      if (!len(txt)) return arguments.defaultValue;
      if (listFindNoCase("1,true,yes,y,on", txt)) return true;
      if (listFindNoCase("0,false,no,n,off", txt)) return false;
      if (isNumeric(txt)) return val(txt) NEQ 0;
      return arguments.defaultValue;
    </cfscript>
  </cffunction>

  <cffunction name="toInt" access="private" returntype="numeric" output="false">
    <cfargument name="value" required="false" default="0">
    <cfscript>
      if (!isNumeric(arguments.value)) return 0;
      return int(val(arguments.value));
    </cfscript>
  </cffunction>

  <cffunction name="getDatasource" access="private" returntype="string" output="false">
    <cfscript>
      return variables.datasource;
    </cfscript>
  </cffunction>

</cfcomponent>


