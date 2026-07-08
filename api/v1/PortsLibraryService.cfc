<cfcomponent output="false" hint="Read-only public Great Loop ports library service.">

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

  <cffunction name="listPorts" access="public" returntype="struct" output="false">
    <cfargument name="filters" type="struct" required="false" default="#structNew()#">
    <cfscript>
      var normalized = normalizeFilters(arguments.filters);
      var sqlParts = buildListSql(normalized);
      var q = queryExecute(sqlParts.sql, sqlParts.params, { datasource = getDatasource() });
      var tagsByPortId = getAllTagsByPortId();
      var ports = [];
      var i = 0;
      var response = structNew("ordered");

      for (i = 1; i LTE q.recordCount; i++) {
        arrayAppend(ports, queryRowToPort(q, i, false, tagsByPortId));
      }

      response["SUCCESS"] = true;
      response["AUTH"] = true;
      response["COUNT"] = arrayLen(ports);
      response["FILTERS"] = buildFilterStruct(normalized);
      response["PORTS"] = ports;
      return response;
    </cfscript>
  </cffunction>

  <cffunction name="getPortById" access="public" returntype="struct" output="false">
    <cfargument name="id" type="numeric" required="true">
    <cfscript>
      var q = queryExecute(
        buildPortSelectSql() & "
        WHERE p.id = :portId
        LIMIT 1",
        { portId = { value = val(arguments.id), cfsqltype = "cf_sql_integer" } },
        { datasource = getDatasource() }
      );
      return detailResponseFromQuery(q);
    </cfscript>
  </cffunction>

  <cffunction name="getPortBySlug" access="public" returntype="struct" output="false">
    <cfargument name="slug" type="string" required="true">
    <cfscript>
      var cleanSlug = left(trim(arguments.slug), 220);
      var q = queryExecute(
        buildPortSelectSql() & "
        WHERE pp.slug = :slug
        LIMIT 1",
        { slug = { value = cleanSlug, cfsqltype = "cf_sql_varchar" } },
        { datasource = getDatasource() }
      );
      return detailResponseFromQuery(q);
    </cfscript>
  </cffunction>

  <cffunction name="getPortRedirectBySlug" access="public" returntype="struct" output="false">
    <cfargument name="slug" type="string" required="true">
    <cfscript>
      var cleanSlug = left(trim(arguments.slug), 220);
      var response = structNew("ordered");
      var q = "";

      response["SUCCESS"] = false;
      response["AUTH"] = true;

      if (!len(cleanSlug)) {
        return response;
      }

      try {
        q = queryExecute(
          "SELECT
             old_port_id,
             old_slug,
             canonical_port_id,
             canonical_slug
           FROM port_slug_redirects
           WHERE old_slug = :slug
           LIMIT 1",
          { slug = { value = cleanSlug, cfsqltype = "cf_sql_varchar" } },
          { datasource = getDatasource() }
        );
      } catch (any redirectLookupError) {
        return response;
      }

      if (q.recordCount EQ 1) {
        response["SUCCESS"] = true;
        response["REDIRECT"] = {
          "OLD_PORT_ID" = val(q.old_port_id[1]),
          "OLD_SLUG" = q.old_slug[1],
          "CANONICAL_PORT_ID" = val(q.canonical_port_id[1]),
          "CANONICAL_SLUG" = q.canonical_slug[1]
        };
      }

      return response;
    </cfscript>
  </cffunction>

  <cffunction name="getFilters" access="public" returntype="struct" output="false">
    <cfscript>
      var response = structNew("ordered");
      var filters = structNew("ordered");
      var counts = getMajorHiddenGemCounts();

      filters["STATES"] = getDistinctValues("p.state", "ports p INNER JOIN port_profiles pp ON pp.port_id = p.id");
      filters["STATE_CODES"] = getDistinctValues("pp.state_code", "ports p INNER JOIN port_profiles pp ON pp.port_id = p.id");
      filters["COUNTRIES"] = getDistinctValues("pp.country", "ports p INNER JOIN port_profiles pp ON pp.port_id = p.id");
      filters["LOOP_SEGMENTS"] = getDistinctValues("pp.loop_segment", "ports p INNER JOIN port_profiles pp ON pp.port_id = p.id");
      filters["WATERWAYS"] = getDistinctValues("pp.waterway", "ports p INNER JOIN port_profiles pp ON pp.port_id = p.id");
      filters["TAGS"] = getDistinctValues("tag", "port_tags");
      filters["QUALITY_STATUSES"] = getDistinctValues("pp.data_quality_status", "ports p INNER JOIN port_profiles pp ON pp.port_id = p.id");
      filters["COUNTS"] = counts;

      response["SUCCESS"] = true;
      response["AUTH"] = true;
      response["FILTERS"] = filters;
      return response;
    </cfscript>
  </cffunction>

  <cffunction name="getQualitySummary" access="public" returntype="struct" output="false">
    <cfscript>
      var qSummary = queryExecute(
        "SELECT
           COUNT(*) AS total_ports,
           SUM(CASE WHEN p.lat IS NOT NULL
                 AND p.lng IS NOT NULL
                 AND p.lat <> 0
                 AND p.lng <> 0
                 AND COALESCE(pp.data_quality_status, '') NOT IN ('bad_coordinates', 'missing_coordinates')
               THEN 1 ELSE 0 END) AS map_ready_ports,
           SUM(CASE WHEN p.lat IS NULL OR p.lng IS NULL THEN 1 ELSE 0 END) AS missing_coordinates,
           SUM(CASE WHEN pp.data_quality_status = 'bad_coordinates' THEN 1 ELSE 0 END) AS bad_coordinates,
           SUM(CASE WHEN pp.data_quality_status = 'missing_coordinates' THEN 1 ELSE 0 END) AS missing_coordinate_status,
           SUM(CASE WHEN p.lat IS NOT NULL
                 AND p.lng IS NOT NULL
                 AND (p.lat < 20 OR p.lat > 55 OR p.lng < -100 OR p.lng > -55 OR p.lat = 0 OR p.lng = 0)
               THEN 1 ELSE 0 END) AS suspicious_coordinates,
           SUM(CASE WHEN pp.data_quality_status = 'needs_review' THEN 1 ELSE 0 END) AS needs_review,
           SUM(CASE WHEN pp.data_quality_status = 'derived_unverified' THEN 1 ELSE 0 END) AS derived_unverified,
           SUM(CASE WHEN pp.source_url IS NULL OR TRIM(pp.source_url) = '' THEN 1 ELSE 0 END) AS missing_source_url
         FROM ports p
         INNER JOIN port_profiles pp ON pp.port_id = p.id",
        {},
        { datasource = getDatasource() }
      );
      var qDuplicates = queryExecute(
        "SELECT COUNT(*) AS duplicate_name_groups
         FROM (
           SELECT LOWER(TRIM(name)) AS normalized_name
           FROM ports
           GROUP BY LOWER(TRIM(name))
           HAVING COUNT(*) > 1
         ) x",
        {},
        { datasource = getDatasource() }
      );
      var qServices = queryExecute(
        "SELECT COUNT(*) AS service_rows_with_null_fields
         FROM port_services ps
         WHERE ps.fuel_available IS NULL
            OR ps.diesel_available IS NULL
            OR ps.gas_available IS NULL
            OR ps.pumpout_available IS NULL
            OR ps.transient_dockage_available IS NULL
            OR ps.anchorage_available IS NULL
            OR ps.mooring_available IS NULL
            OR ps.provisioning_available IS NULL
            OR ps.restaurants_nearby IS NULL
            OR ps.marine_supply_nearby IS NULL
            OR ps.laundry_nearby IS NULL
            OR ps.transportation_nearby IS NULL",
        {},
        { datasource = getDatasource() }
      );
      var quality = structNew("ordered");
      var response = structNew("ordered");

      quality["TOTAL_PORTS"] = val(qSummary.total_ports[1]);
      quality["MAP_READY_PORTS"] = val(qSummary.map_ready_ports[1]);
      quality["BAD_COORDINATES"] = val(qSummary.bad_coordinates[1]);
      quality["MISSING_COORDINATES"] = val(qSummary.missing_coordinates[1]);
      quality["MISSING_COORDINATE_STATUS"] = val(qSummary.missing_coordinate_status[1]);
      quality["SUSPICIOUS_COORDINATES"] = val(qSummary.suspicious_coordinates[1]);
      quality["NEEDS_REVIEW"] = val(qSummary.needs_review[1]);
      quality["DERIVED_UNVERIFIED"] = val(qSummary.derived_unverified[1]);
      quality["DUPLICATE_NAME_GROUPS"] = val(qDuplicates.duplicate_name_groups[1]);
      quality["MISSING_SOURCE_URL"] = val(qSummary.missing_source_url[1]);
      quality["SERVICE_ROWS_WITH_NULL_FIELDS"] = val(qServices.service_rows_with_null_fields[1]);

      response["SUCCESS"] = true;
      response["AUTH"] = true;
      response["QUALITY"] = quality;
      return response;
    </cfscript>
  </cffunction>

  <cffunction name="detailResponseFromQuery" access="private" returntype="struct" output="false">
    <cfargument name="q" type="query" required="true">
    <cfscript>
      var response = structNew("ordered");
      var tagsByPortId = {};

      if (arguments.q.recordCount EQ 0) {
        response["SUCCESS"] = false;
        response["AUTH"] = true;
        response["ERROR"] = "NOT_FOUND";
        response["MESSAGE"] = "Port not found.";
        return response;
      }

      tagsByPortId[toString(arguments.q.id[1])] = getTagsForPort(arguments.q.id[1]);
      response["SUCCESS"] = true;
      response["AUTH"] = true;
      response["PORT"] = queryRowToPort(arguments.q, 1, true, tagsByPortId);
      return response;
    </cfscript>
  </cffunction>

  <cffunction name="buildListSql" access="private" returntype="struct" output="false">
    <cfargument name="filters" type="struct" required="true">
    <cfscript>
      var conditions = [];
      var params = {};
      var sql = "";
      var parts = {};

      if (arguments.filters.mapReady) {
        arrayAppend(conditions, "p.lat IS NOT NULL");
        arrayAppend(conditions, "p.lng IS NOT NULL");
        arrayAppend(conditions, "p.lat <> 0");
        arrayAppend(conditions, "p.lng <> 0");
        arrayAppend(conditions, "COALESCE(pp.data_quality_status, '') NOT IN ('bad_coordinates', 'missing_coordinates')");
      }

      if (len(arguments.filters.q)) {
        arrayAppend(conditions, "(
          p.name LIKE :q
          OR COALESCE(p.state, '') LIKE :q
          OR COALESCE(pp.state_code, '') LIKE :q
          OR COALESCE(pp.loop_segment, '') LIKE :q
          OR COALESCE(pp.waterway, '') LIKE :q
        )");
        params.q = { value = "%" & arguments.filters.q & "%", cfsqltype = "cf_sql_varchar" };
      }
      if (len(arguments.filters.state)) {
        arrayAppend(conditions, "p.state = :state");
        params.state = { value = arguments.filters.state, cfsqltype = "cf_sql_varchar" };
      }
      if (len(arguments.filters.stateCode)) {
        arrayAppend(conditions, "pp.state_code = :stateCode");
        params.stateCode = { value = arguments.filters.stateCode, cfsqltype = "cf_sql_varchar" };
      }
      if (len(arguments.filters.country)) {
        arrayAppend(conditions, "pp.country = :country");
        params.country = { value = arguments.filters.country, cfsqltype = "cf_sql_varchar" };
      }
      if (len(arguments.filters.loopSegment)) {
        arrayAppend(conditions, "pp.loop_segment = :loopSegment");
        params.loopSegment = { value = arguments.filters.loopSegment, cfsqltype = "cf_sql_varchar" };
      }
      if (len(arguments.filters.waterway)) {
        arrayAppend(conditions, "pp.waterway = :waterway");
        params.waterway = { value = arguments.filters.waterway, cfsqltype = "cf_sql_varchar" };
      }
      if (len(arguments.filters.qualityStatus)) {
        arrayAppend(conditions, "pp.data_quality_status = :qualityStatus");
        params.qualityStatus = { value = arguments.filters.qualityStatus, cfsqltype = "cf_sql_varchar" };
      }
      if (len(arguments.filters.major)) {
        arrayAppend(conditions, "COALESCE(p.is_major_port, 0) = :major");
        params.major = { value = val(arguments.filters.major), cfsqltype = "cf_sql_integer" };
      }
      if (len(arguments.filters.hiddenGem)) {
        arrayAppend(conditions, "COALESCE(p.is_hidden_gem, 0) = :hiddenGem");
        params.hiddenGem = { value = val(arguments.filters.hiddenGem), cfsqltype = "cf_sql_integer" };
      }
      if (len(arguments.filters.tag)) {
        arrayAppend(conditions, "EXISTS (
          SELECT 1
          FROM port_tags pt
          WHERE pt.port_id = p.id
            AND pt.tag = :tag
        )");
        params.tag = { value = arguments.filters.tag, cfsqltype = "cf_sql_varchar" };
      }

      sql = buildPortSelectSql();
      if (arrayLen(conditions)) {
        sql &= " WHERE " & arrayToList(conditions, " AND ");
      }
      sql &= "
        ORDER BY COALESCE(p.is_major_port, 0) DESC,
                 COALESCE(p.is_hidden_gem, 0) DESC,
                 p.name ASC
        LIMIT 1000";

      parts.sql = sql;
      parts.params = params;
      return parts;
    </cfscript>
  </cffunction>

  <cffunction name="buildPortSelectSql" access="private" returntype="string" output="false">
    <cfscript>
      return "SELECT
          p.id,
          p.name,
          p.state,
          p.lat,
          p.lng,
          p.region,
          p.is_major_port,
          p.is_hidden_gem,
          pp.slug,
          pp.state_code,
          pp.country,
          pp.waterway,
          pp.loop_segment,
          pp.mile_marker,
          pp.port_type,
          pp.short_description,
          pp.approach_notes,
          pp.services_summary,
          pp.data_quality_status,
          pp.source_notes,
          pp.source_url,
          pp.last_reviewed_at,
          ps.fuel_available,
          ps.diesel_available,
          ps.gas_available,
          ps.pumpout_available,
          ps.transient_dockage_available,
          ps.anchorage_available,
          ps.mooring_available,
          ps.provisioning_available,
          ps.restaurants_nearby,
          ps.marine_supply_nearby,
          ps.laundry_nearby,
          ps.transportation_nearby,
          pi.local_image_path,
          pi.thumbnail_image_path,
          pi.image_alt,
          pi.image_allowed_for_fpw
        FROM ports p
        INNER JOIN port_profiles pp ON pp.port_id = p.id
        LEFT JOIN port_services ps ON ps.port_id = p.id
        LEFT JOIN port_images pi ON pi.port_id = p.id ";
    </cfscript>
  </cffunction>

  <cffunction name="queryRowToPort" access="private" returntype="struct" output="false">
    <cfargument name="q" type="query" required="true">
    <cfargument name="rowIndex" type="numeric" required="true">
    <cfargument name="includeDetail" type="boolean" required="true">
    <cfargument name="tagsByPortId" type="struct" required="true">
    <cfscript>
      var portId = val(arguments.q.id[arguments.rowIndex]);
      var portKey = toString(portId);
      var slug = getEffectiveSlug(arguments.q, arguments.rowIndex);
      var port = structNew("ordered");

      port["ID"] = portId;
      port["NAME"] = safeString(arguments.q.name[arguments.rowIndex]);
      port["STATE"] = safeString(arguments.q.state[arguments.rowIndex]);
      port["STATE_CODE"] = safeString(arguments.q.state_code[arguments.rowIndex]);
      port["COUNTRY"] = safeString(arguments.q.country[arguments.rowIndex]);
      port["LAT"] = numericOrNull(arguments.q.lat[arguments.rowIndex]);
      port["LNG"] = numericOrNull(arguments.q.lng[arguments.rowIndex]);
      port["REGION"] = safeString(arguments.q.region[arguments.rowIndex]);
      port["LOOP_SEGMENT"] = safeString(arguments.q.loop_segment[arguments.rowIndex]);
      port["WATERWAY"] = safeString(arguments.q.waterway[arguments.rowIndex]);
      port["SLUG"] = slug;
      port["DETAIL_URL"] = buildDetailUrl(portId, slug);
      port["IS_MAJOR_PORT"] = boolLike(arguments.q.is_major_port[arguments.rowIndex]);
      port["IS_HIDDEN_GEM"] = boolLike(arguments.q.is_hidden_gem[arguments.rowIndex]);
      port["DATA_QUALITY_STATUS"] = safeString(arguments.q.data_quality_status[arguments.rowIndex]);
      port["MAP_READY"] = isMapReady(arguments.q, arguments.rowIndex);
      port["TAGS"] = structKeyExists(arguments.tagsByPortId, portKey) ? arguments.tagsByPortId[portKey] : [];
      port["SERVICES"] = buildServices(arguments.q, arguments.rowIndex);

      if (arguments.includeDetail) {
        port["MILE_MARKER"] = safeString(arguments.q.mile_marker[arguments.rowIndex]);
        port["PORT_TYPE"] = safeString(arguments.q.port_type[arguments.rowIndex]);
        port["SHORT_DESCRIPTION"] = safeString(arguments.q.short_description[arguments.rowIndex]);
        port["APPROACH_NOTES"] = safeString(arguments.q.approach_notes[arguments.rowIndex]);
        port["SERVICES_SUMMARY"] = safeString(arguments.q.services_summary[arguments.rowIndex]);
        port["SOURCE_NOTES"] = safeString(arguments.q.source_notes[arguments.rowIndex]);
        port["SOURCE_URL"] = safeString(arguments.q.source_url[arguments.rowIndex]);
        port["LAST_REVIEWED_AT"] = safeDateString(arguments.q.last_reviewed_at[arguments.rowIndex]);
        port["IMAGE"] = buildPortImageAsset(arguments.q, arguments.rowIndex);
        port["NEARBY_ASSETS"] = getNearbyAssetsForPort(portId);
      }

      return port;
    </cfscript>
  </cffunction>

  <cffunction name="buildServices" access="private" returntype="struct" output="false">
    <cfargument name="q" type="query" required="true">
    <cfargument name="rowIndex" type="numeric" required="true">
    <cfscript>
      var services = structNew("ordered");
      services["FUEL_AVAILABLE"] = nullableBoolean(arguments.q.fuel_available[arguments.rowIndex]);
      services["DIESEL_AVAILABLE"] = nullableBoolean(arguments.q.diesel_available[arguments.rowIndex]);
      services["GAS_AVAILABLE"] = nullableBoolean(arguments.q.gas_available[arguments.rowIndex]);
      services["PUMPOUT_AVAILABLE"] = nullableBoolean(arguments.q.pumpout_available[arguments.rowIndex]);
      services["TRANSIENT_DOCKAGE_AVAILABLE"] = nullableBoolean(arguments.q.transient_dockage_available[arguments.rowIndex]);
      services["ANCHORAGE_AVAILABLE"] = nullableBoolean(arguments.q.anchorage_available[arguments.rowIndex]);
      services["MOORING_AVAILABLE"] = nullableBoolean(arguments.q.mooring_available[arguments.rowIndex]);
      services["PROVISIONING_AVAILABLE"] = nullableBoolean(arguments.q.provisioning_available[arguments.rowIndex]);
      services["RESTAURANTS_NEARBY"] = nullableBoolean(arguments.q.restaurants_nearby[arguments.rowIndex]);
      services["MARINE_SUPPLY_NEARBY"] = nullableBoolean(arguments.q.marine_supply_nearby[arguments.rowIndex]);
      services["LAUNDRY_NEARBY"] = nullableBoolean(arguments.q.laundry_nearby[arguments.rowIndex]);
      services["TRANSPORTATION_NEARBY"] = nullableBoolean(arguments.q.transportation_nearby[arguments.rowIndex]);
      return services;
    </cfscript>
  </cffunction>

  <cffunction name="getAllTagsByPortId" access="private" returntype="struct" output="false">
    <cfscript>
      var q = queryExecute(
        "SELECT port_id, tag
         FROM port_tags
         ORDER BY port_id ASC, tag ASC",
        {},
        { datasource = getDatasource() }
      );
      return tagsQueryToStruct(q);
    </cfscript>
  </cffunction>

  <cffunction name="getTagsForPort" access="private" returntype="array" output="false">
    <cfargument name="portId" type="numeric" required="true">
    <cfscript>
      var q = queryExecute(
        "SELECT port_id, tag
         FROM port_tags
         WHERE port_id = :portId
         ORDER BY tag ASC",
        { portId = { value = val(arguments.portId), cfsqltype = "cf_sql_integer" } },
        { datasource = getDatasource() }
      );
      var grouped = tagsQueryToStruct(q);
      var key = toString(val(arguments.portId));
      return structKeyExists(grouped, key) ? grouped[key] : [];
    </cfscript>
  </cffunction>

  <cffunction name="tagsQueryToStruct" access="private" returntype="struct" output="false">
    <cfargument name="q" type="query" required="true">
    <cfscript>
      var out = {};
      var i = 0;
      var key = "";

      for (i = 1; i LTE arguments.q.recordCount; i++) {
        key = toString(val(arguments.q.port_id[i]));
        if (!structKeyExists(out, key)) {
          out[key] = [];
        }
        arrayAppend(out[key], safeString(arguments.q.tag[i]));
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="getNearbyAssetsForPort" access="private" returntype="array" output="false">
    <cfargument name="portId" type="numeric" required="true">
    <cfscript>
      var q = queryExecute(
        "SELECT id, port_id, asset_type, asset_id, asset_name, distance_nm, bearing_deg, source
         FROM port_nearby_assets
         WHERE port_id = :portId
         ORDER BY distance_nm ASC, id ASC",
        { portId = { value = val(arguments.portId), cfsqltype = "cf_sql_integer" } },
        { datasource = getDatasource() }
      );
      var assets = [];
      var asset = {};
      var i = 0;

      for (i = 1; i LTE q.recordCount; i++) {
        asset = structNew("ordered");
        asset["ID"] = val(q.id[i]);
        asset["PORT_ID"] = val(q.port_id[i]);
        asset["ASSET_TYPE"] = safeString(q.asset_type[i]);
        asset["ASSET_ID"] = numericOrNull(q.asset_id[i]);
        asset["ASSET_NAME"] = safeString(q.asset_name[i]);
        asset["DISTANCE_NM"] = numericOrNull(q.distance_nm[i]);
        asset["BEARING_DEG"] = numericOrNull(q.bearing_deg[i]);
        asset["SOURCE"] = safeString(q.source[i]);
        arrayAppend(assets, asset);
      }
      return assets;
    </cfscript>
  </cffunction>

  <cffunction name="getDistinctValues" access="private" returntype="array" output="false">
    <cfargument name="fieldSql" type="string" required="true">
    <cfargument name="fromSql" type="string" required="true">
    <cfscript>
      var allowedFields = "p.state,pp.state_code,pp.country,pp.loop_segment,pp.waterway,tag,pp.data_quality_status";
      var selectedFieldSql = trim(arguments.fieldSql);
      var q = queryNew("");
      var values = [];
      var i = 0;

      if (!listFindNoCase(allowedFields, selectedFieldSql)) {
        return values;
      }

      q = queryExecute(
        "SELECT " & selectedFieldSql & " AS value
         FROM " & arguments.fromSql & "
         WHERE " & selectedFieldSql & " IS NOT NULL
           AND TRIM(" & selectedFieldSql & ") <> ''
         GROUP BY " & selectedFieldSql & "
         ORDER BY " & selectedFieldSql & " ASC",
        {},
        { datasource = getDatasource() }
      );

      for (i = 1; i LTE q.recordCount; i++) {
        arrayAppend(values, safeString(q.value[i]));
      }
      return values;
    </cfscript>
  </cffunction>

  <cffunction name="getMajorHiddenGemCounts" access="private" returntype="struct" output="false">
    <cfscript>
      var q = queryExecute(
        "SELECT
           SUM(CASE WHEN COALESCE(is_major_port, 0) = 1 THEN 1 ELSE 0 END) AS major_ports,
           SUM(CASE WHEN COALESCE(is_hidden_gem, 0) = 1 THEN 1 ELSE 0 END) AS hidden_gems
         FROM ports",
        {},
        { datasource = getDatasource() }
      );
      var counts = structNew("ordered");
      counts["MAJOR_PORTS"] = val(q.major_ports[1]);
      counts["HIDDEN_GEMS"] = val(q.hidden_gems[1]);
      return counts;
    </cfscript>
  </cffunction>

  <cffunction name="normalizeFilters" access="private" returntype="struct" output="false">
    <cfargument name="filters" type="struct" required="true">
    <cfscript>
      var out = structNew("ordered");
      out["q"] = left(trim(readAny(arguments.filters, [ "q", "Q" ], "")), 120);
      out["state"] = left(trim(readAny(arguments.filters, [ "state", "STATE" ], "")), 80);
      out["stateCode"] = left(trim(readAny(arguments.filters, [ "stateCode", "state_code", "STATECODE" ], "")), 10);
      out["country"] = left(trim(readAny(arguments.filters, [ "country", "COUNTRY" ], "")), 80);
      out["loopSegment"] = left(trim(readAny(arguments.filters, [ "loopSegment", "loop_segment", "LOOPSEGMENT" ], "")), 160);
      out["waterway"] = left(trim(readAny(arguments.filters, [ "waterway", "WATERWAY" ], "")), 160);
      out["tag"] = left(trim(readAny(arguments.filters, [ "tag", "TAG" ], "")), 80);
      out["major"] = normalizeFlag(readAny(arguments.filters, [ "major", "MAJOR" ], ""));
      out["hiddenGem"] = normalizeFlag(readAny(arguments.filters, [ "hiddenGem", "hidden_gem", "HIDDENGEM" ], ""));
      out["qualityStatus"] = left(trim(readAny(arguments.filters, [ "qualityStatus", "quality_status", "QUALITYSTATUS" ], "")), 40);
      out["mapReady"] = normalizeMapReady(readAny(arguments.filters, [ "mapReady", "map_ready", "MAPREADY" ], ""));
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="buildFilterStruct" access="private" returntype="struct" output="false">
    <cfargument name="filters" type="struct" required="true">
    <cfscript>
      var out = structNew("ordered");
      out["q"] = arguments.filters.q;
      out["state"] = arguments.filters.state;
      out["stateCode"] = arguments.filters.stateCode;
      out["country"] = arguments.filters.country;
      out["loopSegment"] = arguments.filters.loopSegment;
      out["waterway"] = arguments.filters.waterway;
      out["tag"] = arguments.filters.tag;
      out["major"] = arguments.filters.major;
      out["hiddenGem"] = arguments.filters.hiddenGem;
      out["qualityStatus"] = arguments.filters.qualityStatus;
      out["mapReady"] = arguments.filters.mapReady;
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="getEffectiveSlug" access="private" returntype="string" output="false">
    <cfargument name="q" type="query" required="true">
    <cfargument name="rowIndex" type="numeric" required="true">
    <cfscript>
      var slug = normalizeSlug(safeString(arguments.q.slug[arguments.rowIndex]));
      var fallback = "";

      if (len(slug)) {
        return slug;
      }

      fallback = safeString(arguments.q.name[arguments.rowIndex]) & " " & safeString(arguments.q.state_code[arguments.rowIndex]) & " " & val(arguments.q.id[arguments.rowIndex]);
      slug = normalizeSlug(fallback);
      if (!len(slug)) {
        slug = "port-" & val(arguments.q.id[arguments.rowIndex]);
      }
      return slug;
    </cfscript>
  </cffunction>

  <cffunction name="normalizeSlug" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="false" default="">
    <cfscript>
      var slug = lCase(trim(safeString(arguments.value)));
      slug = reReplace(slug, "[^a-z0-9]+", "-", "all");
      slug = reReplace(slug, "^-+|-+$", "", "all");
      return left(slug, 220);
    </cfscript>
  </cffunction>

  <cffunction name="buildDetailUrl" access="private" returntype="string" output="false">
    <cfargument name="portId" type="numeric" required="true">
    <cfargument name="slug" type="string" required="true">
    <cfscript>
      return "/great-loop/ports/" & val(arguments.portId) & "-" & arguments.slug & "/";
    </cfscript>
  </cffunction>

  <cffunction name="isMapReady" access="private" returntype="boolean" output="false">
    <cfargument name="q" type="query" required="true">
    <cfargument name="rowIndex" type="numeric" required="true">
    <cfscript>
      var status = safeString(arguments.q.data_quality_status[arguments.rowIndex]);
      return !isNull(arguments.q.lat[arguments.rowIndex])
        AND !isNull(arguments.q.lng[arguments.rowIndex])
        AND isNumeric(arguments.q.lat[arguments.rowIndex])
        AND isNumeric(arguments.q.lng[arguments.rowIndex])
        AND val(arguments.q.lat[arguments.rowIndex]) NEQ 0
        AND val(arguments.q.lng[arguments.rowIndex]) NEQ 0
        AND !listFindNoCase("bad_coordinates,missing_coordinates", status);
    </cfscript>
  </cffunction>

  <cffunction name="nullableBoolean" access="private" returntype="any" output="false">
    <cfargument name="value" type="any" required="false" default="">
    <cfscript>
      if (isNull(arguments.value) OR !len(trim(toString(arguments.value)))) {
        return jsonNull();
      }
      return val(arguments.value) NEQ 0;
    </cfscript>
  </cffunction>

  <cffunction name="numericOrNull" access="private" returntype="any" output="false">
    <cfargument name="value" type="any" required="false" default="">
    <cfscript>
      if (isNull(arguments.value) OR !len(trim(toString(arguments.value))) OR !isNumeric(arguments.value)) {
        return jsonNull();
      }
      return val(arguments.value);
    </cfscript>
  </cffunction>

  <cffunction name="jsonNull" access="private" returntype="any" output="false">
    <cfscript>
      return javaCast("null", "");
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

  <cffunction name="boolLike" access="private" returntype="boolean" output="false">
    <cfargument name="value" type="any" required="false" default="">
    <cfscript>
      var txt = lCase(trim(toString(isNull(arguments.value) ? "" : arguments.value)));
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

  <cffunction name="normalizeFlag" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="false" default="">
    <cfscript>
      var txt = lCase(trim(toString(isNull(arguments.value) ? "" : arguments.value)));
      if (!len(txt)) {
        return "";
      }
      if (listFindNoCase("1,true,yes,y,on", txt)) {
        return "1";
      }
      if (listFindNoCase("0,false,no,n,off", txt)) {
        return "0";
      }
      return "";
    </cfscript>
  </cffunction>

  <cffunction name="normalizeMapReady" access="private" returntype="boolean" output="false">
    <cfargument name="value" type="any" required="false" default="">
    <cfscript>
      var txt = lCase(trim(toString(isNull(arguments.value) ? "" : arguments.value)));
      if (!len(txt)) {
        return true;
      }
      if (listFindNoCase("0,false,no,n,off", txt)) {
        return false;
      }
      return true;
    </cfscript>
  </cffunction>

  <cffunction name="readAny" access="private" returntype="string" output="false">
    <cfargument name="source" type="struct" required="true">
    <cfargument name="keys" type="array" required="true">
    <cfargument name="defaultValue" type="string" required="false" default="">
    <cfscript>
      var i = 0;
      var keyName = "";
      for (i = 1; i LTE arrayLen(arguments.keys); i++) {
        keyName = arguments.keys[i];
        if (structKeyExists(arguments.source, keyName) AND !isNull(arguments.source[keyName])) {
          return trim(toString(arguments.source[keyName]));
        }
      }
      return arguments.defaultValue;
    </cfscript>
  </cffunction>

  <cffunction name="buildPortImageAsset" access="private" returntype="struct" output="false">
    <cfargument name="q" type="query" required="true">
    <cfargument name="rowIndex" type="numeric" required="true">
    <cfscript>
      var out = {
        "hasImage" = false,
        "hasThumbnail" = false,
        "fileName" = "",
        "url" = "",
        "sourceUrl" = "",
        "thumbnailUrl" = "",
        "alt" = ""
      };
      var allowed = boolLike(arguments.q.image_allowed_for_fpw[arguments.rowIndex]);
      var rel = normalizePortImageRelativePath(arguments.q.local_image_path[arguments.rowIndex]);
      var thumbRel = normalizePortImageRelativePath(arguments.q.thumbnail_image_path[arguments.rowIndex]);
      var repoRoot = getRepoRootPath();
      var basePath = getPublicBasePath();
      var sourcePath = "";
      var thumbnailPath = "";

      if (!allowed OR !len(rel)) {
        return out;
      }

      sourcePath = joinPath(repoRoot, rel);
      if (!fileExists(sourcePath)) {
        return out;
      }

      out.hasImage = true;
      out.fileName = listLast(rel, "/");
      out.alt = safeString(arguments.q.image_alt[arguments.rowIndex]);
      if (!len(out.alt)) {
        out.alt = safeString(arguments.q.name[arguments.rowIndex]) & " port image";
      }
      out.sourceUrl = imageUrlWithVersion(basePath & "/" & rel, sourcePath);
      out.url = out.sourceUrl;

      if (len(thumbRel)) {
        thumbnailPath = joinPath(repoRoot, thumbRel);
        if (fileExists(thumbnailPath)) {
          out.hasThumbnail = true;
          out.thumbnailUrl = imageUrlWithVersion(basePath & "/" & thumbRel, thumbnailPath);
          out.url = out.thumbnailUrl;
        }
      }
      if (!len(out.thumbnailUrl)) {
        out.thumbnailUrl = out.sourceUrl;
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="normalizePortImageRelativePath" access="private" returntype="string" output="false">
    <cfargument name="value" type="any" required="false" default="">
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

  <cffunction name="getPublicBasePath" access="private" returntype="string" output="false">
    <cfscript>
      var basePath = "";
      if (structKeyExists(request, "fpwBase")) {
        basePath = reReplace(trim(toString(request.fpwBase)), "/$", "", "all");
      }
      if (!len(basePath) OR basePath EQ "/") {
        return "";
      }
      return basePath;
    </cfscript>
  </cffunction>

  <cffunction name="getRepoRootPath" access="private" returntype="string" output="false">
    <cfscript>
      var serviceDir = getDirectoryFromPath(getCurrentTemplatePath());
      return reReplace(normalizeFilesystemPath(serviceDir & "../../"), "/+$", "/", "all");
    </cfscript>
  </cffunction>

  <cffunction name="imageUrlWithVersion" access="private" returntype="string" output="false">
    <cfargument name="url" type="string" required="true">
    <cfargument name="path" type="string" required="true">
    <cfscript>
      var info = {};
      var token = "";
      try {
        if (fileExists(arguments.path)) {
          info = getFileInfo(arguments.path);
          token = dateFormat(info.lastModified, "yyyymmdd") & timeFormat(info.lastModified, "HHmmss");
        }
      } catch (any ignored) {
        token = "";
      }
      return len(token) ? arguments.url & "?v=" & token : arguments.url;
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

  <cffunction name="getDatasource" access="private" returntype="string" output="false">
    <cfscript>
      return variables.datasource;
    </cfscript>
  </cffunction>

</cfcomponent>
