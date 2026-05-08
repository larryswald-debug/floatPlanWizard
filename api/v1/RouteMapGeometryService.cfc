<cfcomponent output="false">

  <cffunction name="init" access="public" returntype="any" output="false">
    <cfargument name="datasource" type="string" required="false" default="fpw">
    <cfscript>
      variables.datasource = arguments.datasource;
      return this;
    </cfscript>
  </cffunction>

  <cffunction name="buildRouteMapData" access="public" returntype="struct" output="false">
    <cfargument name="routeInstanceId" type="numeric" required="true">
    <cfargument name="ownerUserId" type="numeric" required="true">
    <cfargument name="fallbackDays" type="numeric" required="false" default="0">
    <cfscript>
      var out = {
        "route_geo"={ "type"="MultiLineString", "coordinates"=[] },
        "pins"=[],
        "current"={},
        "total_nm"=0,
        "total_locks"=0,
        "total_days"=(arguments.fallbackDays GT 0 ? arguments.fallbackDays : 0),
        "remaining_nm"=0,
        "location_label"="",
        "next_stop_label"="",
        "awaiting_departure"=false,
        "active_leg_order"=0,
        "active_leg_start_name"="",
        "active_leg_end_name"="",
        "active_leg_start_lat"="",
        "active_leg_start_lng"="",
        "active_leg_end_lat"="",
        "active_leg_end_lng"="",
        "geometry_authority"="route_map_geometry_service",
        "override_authority"="route_leg_user_overrides",
        "fallback_authority"="segment_geometries"
      };
      var routeInstanceIdVal = val(arguments.routeInstanceId);
      var ownerUserIdVal = val(arguments.ownerUserId);
      var ds = variables.datasource;
      var qLegs = queryNew("");
      var qProgress = queryNew("");
      var qCurrentLeg = queryNew("");
      var qNextLeg = queryNew("");
      var qRouteInstance = queryNew("");
      var qLegCoords = queryNew("");
      var i = 0;
      var pt = {};
      var pointList = [];
      var routeSegments = [];
      var segmentCoords = [];
      var startLat = 0.0;
      var startLng = 0.0;
      var endLat = 0.0;
      var endLng = 0.0;
      var startName = "";
      var endName = "";
      var completedOrder = 0;
      var hasStartCoord = false;
      var hasEndCoord = false;
      var completedNm = 0;
      var startLatRaw = "";
      var startLngRaw = "";
      var endLatRaw = "";
      var endLngRaw = "";
      var legOrderVal = 0;
      var activeStartedLegOrder = 0;
      var pendingLegOrder = 0;
      var progressStatusByLeg = {};
      var progressStartedByLeg = {};
      var progressKey = "";
      var progressStatusVal = "";
      var generatedRouteId = 0;
      var originalCustomRouteId = 0;
      var routeInstanceInputsRaw = "";
      var routeInstanceInputs = {};
      var templateRouteCode = "";
      var routeLegIdVal = 0;
      var segmentIdVal = 0;
      var routeLookupIdVal = 0;
      var routeLegLookupIdVal = 0;
      var useRouteLegOrderFallback = false;

      if (routeInstanceIdVal LTE 0) {
        return out;
      }

      qRouteInstance = queryExecute(
        "SELECT generated_route_id, template_route_code, routegen_inputs_json
         FROM route_instances
         WHERE id = :routeInstanceId
         LIMIT 1",
        {
          routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" }
        },
        { datasource=ds }
      );
      if (qRouteInstance.recordCount GT 0 AND !isNull(qRouteInstance.generated_route_id[1])) {
        generatedRouteId = val(qRouteInstance.generated_route_id[1]);
      }
      if (qRouteInstance.recordCount GT 0 AND !isNull(qRouteInstance.template_route_code[1])) {
        templateRouteCode = uCase(trim(toString(qRouteInstance.template_route_code[1])));
      }
      if (qRouteInstance.recordCount GT 0 AND !isNull(qRouteInstance.routegen_inputs_json[1])) {
        routeInstanceInputsRaw = trim(toString(qRouteInstance.routegen_inputs_json[1]));
      }
      if (templateRouteCode EQ "MY_ROUTE" AND len(routeInstanceInputsRaw)) {
        try {
          routeInstanceInputs = deserializeJSON(routeInstanceInputsRaw);
        } catch (any routeInputsErr) {
          routeInstanceInputs = {};
        }
        if (
          isStruct(routeInstanceInputs)
          AND structKeyExists(routeInstanceInputs, "route_id")
          AND isNumeric(routeInstanceInputs.route_id)
          AND val(routeInstanceInputs.route_id) GT 0
        ) {
          originalCustomRouteId = val(routeInstanceInputs.route_id);
        }
      }

      qLegs = queryExecute(
        "SELECT
            id,
            leg_order,
            segment_id,
            source_loop_segment_id,
            start_name,
            end_name,
            start_lat,
            start_lng,
            end_lat,
            end_lng,
            base_dist_nm,
            lock_count
         FROM route_instance_legs
         WHERE route_instance_id = :routeInstanceId
         ORDER BY leg_order ASC, id ASC",
        {
          routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" }
        },
        { datasource=ds }
      );

      if (qLegs.recordCount EQ 0) {
        return out;
      }

      out.total_days = max(out.total_days, qLegs.recordCount);

      for (i = 1; i LTE qLegs.recordCount; i++) {
        out.total_nm += (isNull(qLegs.base_dist_nm[i]) ? 0 : val(qLegs.base_dist_nm[i]));
        out.total_locks += (isNull(qLegs.lock_count[i]) ? 0 : val(qLegs.lock_count[i]));

        startLatRaw = (isNull(qLegs.start_lat[i]) ? "" : trim(toString(qLegs.start_lat[i])));
        startLngRaw = (isNull(qLegs.start_lng[i]) ? "" : trim(toString(qLegs.start_lng[i])));
        endLatRaw = (isNull(qLegs.end_lat[i]) ? "" : trim(toString(qLegs.end_lat[i])));
        endLngRaw = (isNull(qLegs.end_lng[i]) ? "" : trim(toString(qLegs.end_lng[i])));
        legOrderVal = (isNull(qLegs.leg_order[i]) ? 0 : val(qLegs.leg_order[i]));
        routeLegIdVal = (
          isNull(qLegs.source_loop_segment_id[i]) OR val(qLegs.source_loop_segment_id[i]) LTE 0
            ? val(qLegs.id[i])
            : val(qLegs.source_loop_segment_id[i])
        );
        segmentIdVal = (isNull(qLegs.segment_id[i]) ? 0 : val(qLegs.segment_id[i]));
        routeLookupIdVal = generatedRouteId;
        routeLegLookupIdVal = routeLegIdVal;
        useRouteLegOrderFallback = false;
        if (
          originalCustomRouteId GT 0
          AND segmentIdVal LTE 0
          AND (
            isNull(qLegs.source_loop_segment_id[i])
            OR val(qLegs.source_loop_segment_id[i]) LTE 0
          )
        ) {
          routeLookupIdVal = originalCustomRouteId;
          routeLegLookupIdVal = 0;
          useRouteLegOrderFallback = (legOrderVal GT 0);
        }
        segmentCoords = loadRouteSegmentCoordinates(
          ownerUserId=ownerUserIdVal,
          routeId=routeLookupIdVal,
          routeLegId=routeLegLookupIdVal,
          routeLegOrder=legOrderVal,
          segmentId=segmentIdVal,
          allowRouteLegOrderFallback=useRouteLegOrderFallback
        );
        if (arrayLen(segmentCoords) GTE 2) {
          arrayAppend(routeSegments, segmentCoords);
        }
        hasStartCoord = (len(startLatRaw) AND len(startLngRaw) AND isNumeric(startLatRaw) AND isNumeric(startLngRaw));
        hasEndCoord = (len(endLatRaw) AND len(endLngRaw) AND isNumeric(endLatRaw) AND isNumeric(endLngRaw));
        startName = (isNull(qLegs.start_name[i]) ? "Start" : trim(toString(qLegs.start_name[i])));
        endName = (isNull(qLegs.end_name[i]) ? "End" : trim(toString(qLegs.end_name[i])));

        if (hasStartCoord) {
          startLat = val(startLatRaw);
          startLng = val(startLngRaw);
          if (arrayLen(pointList) EQ 0) {
            pointList = appendUniqueRoutePoint(
              pointList=pointList,
              lat=startLat,
              lng=startLng,
              label=(len(startName) ? startName : "Start"),
              minDistanceMeters=20
            );
          }
        }

        if (hasEndCoord) {
          endLat = val(endLatRaw);
          endLng = val(endLngRaw);
          pointList = appendUniqueRoutePoint(
            pointList=pointList,
            lat=endLat,
            lng=endLng,
            label=(len(endName) ? endName : "End"),
            minDistanceMeters=20
          );
        }
      }

      if (arrayLen(pointList) EQ 0) {
        try {
          qLegCoords = queryExecute(
            "SELECT
                ril.leg_order,
                COALESCE(
                  NULLIF(TRIM(ril.start_lat), ''),
                  pStart.lat
                ) AS start_lat,
                COALESCE(
                  NULLIF(TRIM(ril.start_lng), ''),
                  pStart.lng
                ) AS start_lng,
                COALESCE(
                  NULLIF(TRIM(ril.end_lat), ''),
                  pEnd.lat
                ) AS end_lat,
                COALESCE(
                  NULLIF(TRIM(ril.end_lng), ''),
                  pEnd.lng
                ) AS end_lng,
                COALESCE(NULLIF(TRIM(ril.start_name), ''), 'Start') AS start_label,
                COALESCE(NULLIF(TRIM(ril.end_name), ''), 'End') AS end_label
             FROM route_instance_legs ril
             LEFT JOIN ports pStart
               ON pStart.id = (
                    SELECT p1.id
                    FROM ports p1
                    WHERE TRIM(p1.name) = TRIM(ril.start_name)
                    ORDER BY p1.id ASC
                    LIMIT 1
               )
             LEFT JOIN ports pEnd
               ON pEnd.id = (
                    SELECT p2.id
                    FROM ports p2
                    WHERE TRIM(p2.name) = TRIM(ril.end_name)
                    ORDER BY p2.id ASC
                    LIMIT 1
               )
             WHERE ril.route_instance_id = :routeInstanceId
             ORDER BY ril.leg_order ASC, ril.id ASC",
            {
              routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" }
            },
            { datasource=ds }
          );

          for (i = 1; i LTE qLegCoords.recordCount; i++) {
            startLatRaw = (isNull(qLegCoords.start_lat[i]) ? "" : trim(toString(qLegCoords.start_lat[i])));
            startLngRaw = (isNull(qLegCoords.start_lng[i]) ? "" : trim(toString(qLegCoords.start_lng[i])));
            endLatRaw = (isNull(qLegCoords.end_lat[i]) ? "" : trim(toString(qLegCoords.end_lat[i])));
            endLngRaw = (isNull(qLegCoords.end_lng[i]) ? "" : trim(toString(qLegCoords.end_lng[i])));

            if (len(startLatRaw) AND len(startLngRaw) AND isNumeric(startLatRaw) AND isNumeric(startLngRaw)) {
              if (arrayLen(pointList) EQ 0) {
                pointList = appendUniqueRoutePoint(
                  pointList=pointList,
                  lat=val(startLatRaw),
                  lng=val(startLngRaw),
                  label=(isNull(qLegCoords.start_label[i]) ? "Start" : trim(toString(qLegCoords.start_label[i]))),
                  minDistanceMeters=20
                );
              }
            }

            if (len(endLatRaw) AND len(endLngRaw) AND isNumeric(endLatRaw) AND isNumeric(endLngRaw)) {
              pointList = appendUniqueRoutePoint(
                pointList=pointList,
                lat=val(endLatRaw),
                lng=val(endLngRaw),
                label=(isNull(qLegCoords.end_label[i]) ? "End" : trim(toString(qLegCoords.end_label[i]))),
                minDistanceMeters=20
              );
            }
          }
        } catch (any fallbackLookupErr) {
          // Keep response additive/safe; if fallback lookup fails, return without pins.
        }
      }

      for (i = 1; i LTE arrayLen(pointList); i++) {
        pt = pointList[i];
        arrayAppend(out.pins, {
          "lat"=pt.lat,
          "lng"=pt.lng,
          "label"=pt.label,
          "seq"=i,
          "sequence"=i,
          "type"=(i EQ 1 ? "start" : (i EQ arrayLen(pointList) ? "end" : "leg_end"))
        });
      }
      out.route_geo = {
        "type"="MultiLineString",
        "coordinates"=routeSegments
      };

      qProgress = queryExecute(
        "SELECT
            leg_order,
            UPPER(TRIM(status)) AS status_val,
            leg_started_at
         FROM route_instance_leg_progress
         WHERE route_instance_id = :routeInstanceId
           AND user_id = :userId
         ORDER BY leg_order ASC, id DESC",
        {
          routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" },
          userId = { value=ownerUserIdVal, cfsqltype="cf_sql_integer" }
        },
        { datasource=ds }
      );

      for (i = 1; i LTE qProgress.recordCount; i++) {
        progressKey = toString(isNull(qProgress.leg_order[i]) ? 0 : val(qProgress.leg_order[i]));
        if (structKeyExists(progressStatusByLeg, progressKey)) {
          continue;
        }
        progressStatusVal = (isNull(qProgress.status_val[i]) ? "" : trim(toString(qProgress.status_val[i])));
        progressStatusByLeg[progressKey] = progressStatusVal;
        if (!isNull(qProgress.leg_started_at[i]) AND isDate(qProgress.leg_started_at[i])) {
          progressStartedByLeg[progressKey] = qProgress.leg_started_at[i];
        }
        if (progressStatusVal EQ "COMPLETED" AND val(qProgress.leg_order[i]) GT completedOrder) {
          completedOrder = val(qProgress.leg_order[i]);
        }
      }

      for (i = 1; i LTE qLegs.recordCount; i++) {
        legOrderVal = (isNull(qLegs.leg_order[i]) ? 0 : val(qLegs.leg_order[i]));
        if (legOrderVal LTE completedOrder) {
          continue;
        }
        if (pendingLegOrder LTE 0) {
          pendingLegOrder = legOrderVal;
        }
        progressKey = toString(legOrderVal);
        progressStatusVal = (structKeyExists(progressStatusByLeg, progressKey) ? progressStatusByLeg[progressKey] : "NOT_STARTED");
        if (
          activeStartedLegOrder LTE 0
          AND (
            structKeyExists(progressStartedByLeg, progressKey)
            OR progressStatusVal EQ "STARTED"
            OR progressStatusVal EQ "IN_PROGRESS"
          )
        ) {
          activeStartedLegOrder = legOrderVal;
        }
        if (activeStartedLegOrder LTE 0 OR legOrderVal NEQ activeStartedLegOrder) {
          continue;
        }
        out.active_leg_order = legOrderVal;
        out.active_leg_start_name = (isNull(qLegs.start_name[i]) ? "" : trim(toString(qLegs.start_name[i])));
        out.active_leg_end_name = (isNull(qLegs.end_name[i]) ? "" : trim(toString(qLegs.end_name[i])));
        startLatRaw = (isNull(qLegs.start_lat[i]) ? "" : trim(toString(qLegs.start_lat[i])));
        startLngRaw = (isNull(qLegs.start_lng[i]) ? "" : trim(toString(qLegs.start_lng[i])));
        endLatRaw = (isNull(qLegs.end_lat[i]) ? "" : trim(toString(qLegs.end_lat[i])));
        endLngRaw = (isNull(qLegs.end_lng[i]) ? "" : trim(toString(qLegs.end_lng[i])));
        if (len(startLatRaw) AND len(startLngRaw) AND isNumeric(startLatRaw) AND isNumeric(startLngRaw)) {
          out.active_leg_start_lat = val(startLatRaw);
          out.active_leg_start_lng = val(startLngRaw);
        }
        if (len(endLatRaw) AND len(endLngRaw) AND isNumeric(endLatRaw) AND isNumeric(endLngRaw)) {
          out.active_leg_end_lat = val(endLatRaw);
          out.active_leg_end_lng = val(endLngRaw);
        }
        break;
      }

      if (completedOrder GT 0 AND pendingLegOrder GT 0 AND activeStartedLegOrder LTE 0) {
        out.awaiting_departure = true;
      }

      if (completedOrder GT 0) {
        qCurrentLeg = queryExecute(
          "SELECT end_name, end_lat, end_lng
           FROM route_instance_legs
           WHERE route_instance_id = :routeInstanceId
             AND leg_order = :legOrder
           LIMIT 1",
          {
            routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" },
            legOrder = { value=completedOrder, cfsqltype="cf_sql_integer" }
          },
          { datasource=ds }
        );
        if (
          qCurrentLeg.recordCount GT 0
          AND !isNull(qCurrentLeg.end_lat[1]) AND !isNull(qCurrentLeg.end_lng[1])
          AND isNumeric(trim(toString(qCurrentLeg.end_lat[1])))
          AND isNumeric(trim(toString(qCurrentLeg.end_lng[1])))
        ) {
          out.current = {
            "lat"=val(trim(toString(qCurrentLeg.end_lat[1]))),
            "lng"=val(trim(toString(qCurrentLeg.end_lng[1]))),
            "label"=(isNull(qCurrentLeg.end_name[1]) ? "Current position" : trim(toString(qCurrentLeg.end_name[1])))
          };
          out.location_label = out.current.label;
        }

        qNextLeg = queryExecute(
          "SELECT end_name
           FROM route_instance_legs
           WHERE route_instance_id = :routeInstanceId
             AND leg_order > :legOrder
           ORDER BY leg_order ASC
           LIMIT 1",
          {
            routeInstanceId = { value=routeInstanceIdVal, cfsqltype="cf_sql_integer" },
            legOrder = { value=completedOrder, cfsqltype="cf_sql_integer" }
          },
          { datasource=ds }
        );
        if (qNextLeg.recordCount GT 0 AND !isNull(qNextLeg.end_name[1])) {
          out.next_stop_label = trim(toString(qNextLeg.end_name[1]));
        }

        if (completedOrder GT 0) {
          for (i = 1; i LTE qLegs.recordCount; i++) {
            if (val(qLegs.leg_order[i]) LTE completedOrder) {
              completedNm += (isNull(qLegs.base_dist_nm[i]) ? 0 : val(qLegs.base_dist_nm[i]));
            }
          }
        }
      }

      if (!structKeyExists(out.current, "lat") AND arrayLen(pointList)) {
        out.current = {
          "lat"=pointList[1].lat,
          "lng"=pointList[1].lng,
          "label"=pointList[1].label
        };
        out.location_label = pointList[1].label;
      }
      if (!len(out.next_stop_label) AND qLegs.recordCount GT 0 AND completedOrder LTE 0) {
        out.next_stop_label = (isNull(qLegs.end_name[1]) ? "" : trim(toString(qLegs.end_name[1])));
      }

      out.total_nm = roundTo2(out.total_nm);
      out.remaining_nm = max(0, roundTo2(out.total_nm - completedNm));
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="loadRouteSegmentCoordinates" access="private" returntype="array" output="false">
    <cfargument name="ownerUserId" type="numeric" required="true">
    <cfargument name="routeId" type="numeric" required="false" default="0">
    <cfargument name="routeLegId" type="numeric" required="false" default="0">
    <cfargument name="routeLegOrder" type="numeric" required="false" default="0">
    <cfargument name="segmentId" type="numeric" required="false" default="0">
    <cfargument name="allowRouteLegOrderFallback" type="boolean" required="false" default="false">
    <cfscript>
      var ds = variables.datasource;
      var q = queryNew("");
      var rawJson = "";
      var coords = [];

      if (arguments.ownerUserId LTE 0) {
        return [];
      }

      if (arguments.routeId GT 0 AND arguments.routeLegId GT 0) {
        q = queryExecute(
          "SELECT geometry_json
           FROM route_leg_user_overrides
           WHERE user_id = :userId
             AND route_id = :routeId
             AND route_leg_id = :routeLegId
           LIMIT 1",
          {
            userId = { value=arguments.ownerUserId, cfsqltype="cf_sql_integer" },
            routeId = { value=arguments.routeId, cfsqltype="cf_sql_integer" },
            routeLegId = { value=arguments.routeLegId, cfsqltype="cf_sql_integer" }
          },
          { datasource=ds }
        );
        if (q.recordCount GT 0 AND !isNull(q.geometry_json[1])) {
          rawJson = toString(q.geometry_json[1]);
          coords = parseGeometryCoordinates(rawJson);
          if (arrayLen(coords) GTE 2) {
            return coords;
          }
        }
      }

      if (
        arguments.allowRouteLegOrderFallback
        AND arguments.routeId GT 0
        AND arguments.routeLegOrder GT 0
        AND arguments.segmentId LTE 0
      ) {
        q = queryExecute(
          "SELECT geometry_json
           FROM route_leg_user_overrides
           WHERE user_id = :userId
             AND route_id = :routeId
             AND route_leg_order = :routeLegOrder
           ORDER BY updated_at DESC, id DESC
           LIMIT 1",
          {
            userId = { value=arguments.ownerUserId, cfsqltype="cf_sql_integer" },
            routeId = { value=arguments.routeId, cfsqltype="cf_sql_integer" },
            routeLegOrder = { value=arguments.routeLegOrder, cfsqltype="cf_sql_integer" }
          },
          { datasource=ds }
        );
        if (q.recordCount GT 0 AND !isNull(q.geometry_json[1])) {
          rawJson = toString(q.geometry_json[1]);
          coords = parseGeometryCoordinates(rawJson);
          if (arrayLen(coords) GTE 2) {
            return coords;
          }
        }
      }

      if (arguments.segmentId GT 0) {
        q = queryExecute(
          "SELECT geometry_json
           FROM route_leg_user_overrides
           WHERE user_id = :userId
             AND segment_id = :segmentId
           ORDER BY updated_at DESC, id DESC
           LIMIT 1",
          {
            userId = { value=arguments.ownerUserId, cfsqltype="cf_sql_integer" },
            segmentId = { value=arguments.segmentId, cfsqltype="cf_sql_integer" }
          },
          { datasource=ds }
        );
        if (q.recordCount GT 0 AND !isNull(q.geometry_json[1])) {
          rawJson = toString(q.geometry_json[1]);
          coords = parseGeometryCoordinates(rawJson);
          if (arrayLen(coords) GTE 2) {
            return coords;
          }
        }

        q = queryExecute(
          "SELECT polyline_json
           FROM segment_geometries
           WHERE segment_id = :segmentId
           ORDER BY version DESC, id DESC
           LIMIT 1",
          {
            segmentId = { value=arguments.segmentId, cfsqltype="cf_sql_integer" }
          },
          { datasource=ds }
        );
        if (q.recordCount GT 0 AND !isNull(q.polyline_json[1])) {
          rawJson = toString(q.polyline_json[1]);
          coords = parseGeometryCoordinates(rawJson);
          if (arrayLen(coords) GTE 2) {
            return coords;
          }
        }
      }

      return [];
    </cfscript>
  </cffunction>

  <cffunction name="parseGeometryCoordinates" access="private" returntype="array" output="false">
    <cfargument name="rawJson" type="any" required="false">
    <cfscript>
      var out = [];
      var raw = (isNull(arguments.rawJson) ? "" : trim(toString(arguments.rawJson)));
      var parsed = "";
      var item = "";
      var latVal = 0.0;
      var lngVal = 0.0;
      var existing = [];
      var i = 0;

      if (!len(raw)) {
        return out;
      }

      try {
        parsed = deserializeJSON(raw, false);
      } catch (any parseErr) {
        return out;
      }

      if (!isArray(parsed)) {
        return out;
      }

      for (i = 1; i LTE arrayLen(parsed); i++) {
        item = parsed[i];
        if (isArray(item) AND arrayLen(item) GTE 2 AND isNumeric(item[1]) AND isNumeric(item[2])) {
          lngVal = val(item[1]);
          latVal = val(item[2]);
        } else if (isStruct(item)) {
          if (
            structKeyExists(item, "lat")
            AND (
              structKeyExists(item, "lng")
              OR structKeyExists(item, "lon")
              OR structKeyExists(item, "longitude")
            )
          ) {
            if (!isNumeric(item.lat)) {
              continue;
            }
            latVal = val(item.lat);
            if (structKeyExists(item, "lng") AND isNumeric(item.lng)) {
              lngVal = val(item.lng);
            } else if (structKeyExists(item, "lon") AND isNumeric(item.lon)) {
              lngVal = val(item.lon);
            } else if (structKeyExists(item, "longitude") AND isNumeric(item.longitude)) {
              lngVal = val(item.longitude);
            } else {
              continue;
            }
          } else if (
            structKeyExists(item, "latitude")
            AND (
              structKeyExists(item, "lng")
              OR structKeyExists(item, "lon")
              OR structKeyExists(item, "longitude")
            )
          ) {
            if (!isNumeric(item.latitude)) {
              continue;
            }
            latVal = val(item.latitude);
            if (structKeyExists(item, "lng") AND isNumeric(item.lng)) {
              lngVal = val(item.lng);
            } else if (structKeyExists(item, "lon") AND isNumeric(item.lon)) {
              lngVal = val(item.lon);
            } else if (structKeyExists(item, "longitude") AND isNumeric(item.longitude)) {
              lngVal = val(item.longitude);
            } else {
              continue;
            }
          } else {
            continue;
          }
        } else {
          continue;
        }

        if (arrayLen(out) GT 0) {
          existing = out[arrayLen(out)];
          if (
            isArray(existing)
            AND arrayLen(existing) GTE 2
            AND existing[1] EQ lngVal
            AND existing[2] EQ latVal
          ) {
            continue;
          }
        }
        arrayAppend(out, [lngVal, latVal]);
      }

      if (arrayLen(out) LT 2) {
        return [];
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="appendUniqueRoutePoint" access="private" returntype="array" output="false">
    <cfargument name="pointList" type="array" required="true">
    <cfargument name="lat" type="numeric" required="true">
    <cfargument name="lng" type="numeric" required="true">
    <cfargument name="label" type="string" required="false" default="">
    <cfargument name="minDistanceMeters" type="numeric" required="false" default="20">
    <cfscript>
      var i = 0;
      var existing = {};
      var distanceMeters = 0.0;
      var threshold = max(1, val(arguments.minDistanceMeters));
      for (i = 1; i LTE arrayLen(arguments.pointList); i++) {
        existing = arguments.pointList[i];
        if (!isStruct(existing)) continue;
        if (!structKeyExists(existing, "lat") OR !structKeyExists(existing, "lng")) continue;
        if (!isNumeric(existing.lat) OR !isNumeric(existing.lng)) continue;
        distanceMeters = haversineMeters(arguments.lat, arguments.lng, val(existing.lat), val(existing.lng));
        if (distanceMeters LTE threshold) {
          return arguments.pointList;
        }
      }
      arrayAppend(arguments.pointList, {
        "lat"=arguments.lat,
        "lng"=arguments.lng,
        "label"=(len(trim(arguments.label)) ? trim(arguments.label) : "Point")
      });
      return arguments.pointList;
    </cfscript>
  </cffunction>

  <cffunction name="haversineMeters" access="private" returntype="numeric" output="false">
    <cfargument name="lat1" type="numeric" required="true">
    <cfargument name="lon1" type="numeric" required="true">
    <cfargument name="lat2" type="numeric" required="true">
    <cfargument name="lon2" type="numeric" required="true">
    <cfscript>
      var earthRadiusMeters = 6371008.8;
      var dLat = toRadians(arguments.lat2 - arguments.lat1);
      var dLon = toRadians(arguments.lon2 - arguments.lon1);
      var phi1 = toRadians(arguments.lat1);
      var phi2 = toRadians(arguments.lat2);
      var a = (sin(dLat / 2) ^ 2) + cos(phi1) * cos(phi2) * (sin(dLon / 2) ^ 2);
      if (a LT 0) a = 0;
      if (a GT 1) a = 1;
      return 2 * earthRadiusMeters * atn2Compat(sqr(a), sqr(1 - a));
    </cfscript>
  </cffunction>

  <cffunction name="toRadians" access="private" returntype="numeric" output="false">
    <cfargument name="deg" type="numeric" required="true">
    <cfscript>
      return arguments.deg * (pi() / 180);
    </cfscript>
  </cffunction>

  <cffunction name="atn2Compat" access="private" returntype="numeric" output="false">
    <cfargument name="y" type="numeric" required="true">
    <cfargument name="x" type="numeric" required="true">
    <cfscript>
      return createObject("java", "java.lang.Math").atan2(arguments.y, arguments.x);
    </cfscript>
  </cffunction>

  <cffunction name="roundTo2" access="private" returntype="numeric" output="false">
    <cfargument name="value" type="any" required="true">
    <cfscript>
      var n = (isNumeric(arguments.value) ? val(arguments.value) : 0);
      return int(n * 100 + 0.5) / 100;
    </cfscript>
  </cffunction>

</cfcomponent>
