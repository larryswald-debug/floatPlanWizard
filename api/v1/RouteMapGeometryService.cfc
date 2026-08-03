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
    <cfargument name="preferOperationalSnapshot" type="boolean" required="false" default="true">
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
        "geometry_authority"="live_route_geometry_resolver",
        "override_authority"="route_leg_user_overrides",
        "fallback_authority"="segment_geometries",
        "snapshot_status"="not_checked",
        "operational_snapshot_used"=false,
        "legacy_geometry_fallback"=false,
        "legacy_endpoint_fallback_used"=false
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
      var snapshotState = {};
      var useOperationalSnapshot = false;
      var snapshotPinIndex = 0;
      var snapshotPin = {};
      var hasOperationalPlan = false;
      var segmentStart = [];
      var segmentEnd = [];
      var completedPin = {};

      if (routeInstanceIdVal LTE 0) {
        return out;
      }

      qRouteInstance = queryExecute(
        "SELECT
            ri.generated_route_id,
            ri.template_route_code,
            ri.routegen_inputs_json,
            EXISTS(
              SELECT 1
              FROM floatplans fp
              WHERE fp.route_instance_id = ri.id
                AND (
                  UPPER(TRIM(COALESCE(fp.status, ''))) <> 'DRAFT'
                  OR fp.activatedAt IS NOT NULL
                  OR fp.initialSentAt IS NOT NULL
                )
            ) AS has_operational_plan
         FROM route_instances ri
         WHERE ri.id = :routeInstanceId
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
      if (qRouteInstance.recordCount GT 0 AND !isNull(qRouteInstance.has_operational_plan[1])) {
        hasOperationalPlan = (val(qRouteInstance.has_operational_plan[1]) GT 0);
      }
      originalCustomRouteId = resolveOriginalCustomRouteId(templateRouteCode, routeInstanceInputsRaw);

      if (arguments.preferOperationalSnapshot) {
        snapshotState = loadOperationalGeometrySnapshot(routeInstanceIdVal);
        out.snapshot_status = snapshotState.status;
        if (snapshotState.valid) {
          useOperationalSnapshot = true;
          out.route_geo = snapshotState.route_geo;
          out.pins = snapshotState.pins;
          out.geometry_authority = "route_instance_geometry_snapshot";
          out.operational_snapshot_used = true;
          out.legacy_geometry_fallback = false;
          for (snapshotPinIndex = 1; snapshotPinIndex LTE arrayLen(out.pins); snapshotPinIndex++) {
            snapshotPin = out.pins[snapshotPinIndex];
            if (
              isStruct(snapshotPin)
              AND structKeyExists(snapshotPin, "lat")
              AND structKeyExists(snapshotPin, "lng")
              AND isNumeric(snapshotPin.lat)
              AND isNumeric(snapshotPin.lng)
            ) {
              arrayAppend(pointList, {
                "lat"=val(snapshotPin.lat),
                "lng"=val(snapshotPin.lng),
                "label"=(structKeyExists(snapshotPin, "label") ? trim(toString(snapshotPin.label)) : "Point")
              });
            }
          }
        } else if (hasOperationalPlan) {
          out.geometry_authority = "legacy_route_geometry_fallback";
          out.legacy_geometry_fallback = true;
        }
      } else {
        out.snapshot_status = "bypassed";
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

      if (qLegs.recordCount EQ 0 AND !useOperationalSnapshot) {
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
        hasStartCoord = (len(startLatRaw) AND len(startLngRaw) AND isNumeric(startLatRaw) AND isNumeric(startLngRaw));
        hasEndCoord = (len(endLatRaw) AND len(endLngRaw) AND isNumeric(endLatRaw) AND isNumeric(endLngRaw));
        startName = (isNull(qLegs.start_name[i]) ? "Start" : trim(toString(qLegs.start_name[i])));
        endName = (isNull(qLegs.end_name[i]) ? "End" : trim(toString(qLegs.end_name[i])));

        if (!useOperationalSnapshot) {
          segmentIdVal = (isNull(qLegs.segment_id[i]) ? 0 : val(qLegs.segment_id[i]));
          segmentCoords = resolveRouteInstanceLegCoordinates(
            ownerUserId=ownerUserIdVal,
            generatedRouteId=generatedRouteId,
            originalCustomRouteId=originalCustomRouteId,
            routeInstanceLegId=val(qLegs.id[i]),
            sourceLoopSegmentId=(isNull(qLegs.source_loop_segment_id[i]) ? 0 : val(qLegs.source_loop_segment_id[i])),
            routeLegOrder=legOrderVal,
            segmentId=segmentIdVal
          );

          if (hasOperationalPlan AND arrayLen(segmentCoords) GTE 2) {
            segmentStart = segmentCoords[1];
            segmentEnd = segmentCoords[arrayLen(segmentCoords)];
            if (
              isArray(segmentStart)
              AND arrayLen(segmentStart) GTE 2
              AND isNumeric(segmentStart[1])
              AND isNumeric(segmentStart[2])
              AND (
                !hasStartCoord
                OR (
                  isWholeCoordinatePair(val(startLatRaw), val(startLngRaw))
                  AND haversineMeters(val(startLatRaw), val(startLngRaw), val(segmentStart[2]), val(segmentStart[1])) GT 20
                )
              )
            ) {
              startLatRaw = toString(val(segmentStart[2]));
              startLngRaw = toString(val(segmentStart[1]));
              hasStartCoord = true;
              out.legacy_endpoint_fallback_used = true;
            }
            if (
              isArray(segmentEnd)
              AND arrayLen(segmentEnd) GTE 2
              AND isNumeric(segmentEnd[1])
              AND isNumeric(segmentEnd[2])
              AND (
                !hasEndCoord
                OR (
                  isWholeCoordinatePair(val(endLatRaw), val(endLngRaw))
                  AND haversineMeters(val(endLatRaw), val(endLngRaw), val(segmentEnd[2]), val(segmentEnd[1])) GT 20
                )
              )
            ) {
              endLatRaw = toString(val(segmentEnd[2]));
              endLngRaw = toString(val(segmentEnd[1]));
              hasEndCoord = true;
              out.legacy_endpoint_fallback_used = true;
            }
          }

          if (arrayLen(segmentCoords) GTE 2) {
            arrayAppend(routeSegments, segmentCoords);
          }

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
      }

      if (!useOperationalSnapshot AND arrayLen(pointList) EQ 0) {
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

      if (!useOperationalSnapshot) {
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
      }

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
        if (useOperationalSnapshot) {
          completedPin = findSnapshotEndPin(out.pins, completedOrder);
        }
        if (
          isStruct(completedPin)
          AND structKeyExists(completedPin, "lat")
          AND structKeyExists(completedPin, "lng")
          AND isNumeric(completedPin.lat)
          AND isNumeric(completedPin.lng)
        ) {
          out.current = {
            "lat"=val(completedPin.lat),
            "lng"=val(completedPin.lng),
            "label"=(structKeyExists(completedPin, "label") ? trim(toString(completedPin.label)) : "Estimated route progress")
          };
          out.location_label = out.current.label;
        } else {
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
              "label"=(isNull(qCurrentLeg.end_name[1]) ? "Estimated route progress" : trim(toString(qCurrentLeg.end_name[1])))
            };
            out.location_label = out.current.label;
          }
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

  <cffunction name="ensureOperationalGeometrySnapshot" access="public" returntype="struct" output="false">
    <cfargument name="routeInstanceId" type="numeric" required="true">
    <cfargument name="ownerUserId" type="numeric" required="true">
    <cfscript>
      var result = {
        "SUCCESS"=false,
        "CREATED"=false,
        "REUSED"=false,
        "ROUTE_INSTANCE_ID"=val(arguments.routeInstanceId),
        "SNAPSHOT_VERSION"=1,
        "LEG_COUNT"=0,
        "MARKER_COUNT"=0
      };
      var qRouteLock = queryNew("");
      var existing = {};
      var payloadResult = {};
      var snapshotJson = "";

      if (arguments.routeInstanceId LTE 0 OR arguments.ownerUserId LTE 0) {
        result.ERROR = "INVALID_OPERATIONAL_GEOMETRY_SNAPSHOT_INPUT";
        result.MESSAGE = "A valid route instance and owner are required for operational geometry capture.";
        return result;
      }

      try {
        qRouteLock = queryExecute(
          "SELECT id
           FROM route_instances
           WHERE id = :routeInstanceId
             AND user_id = :userId
           LIMIT 1
           FOR UPDATE",
          {
            routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" },
            userId = { value=toString(arguments.ownerUserId), cfsqltype="cf_sql_varchar" }
          },
          { datasource=variables.datasource }
        );
        if (qRouteLock.recordCount NEQ 1) {
          result.ERROR = "OPERATIONAL_GEOMETRY_ROUTE_NOT_FOUND";
          result.MESSAGE = "The operational route instance could not be found for geometry capture.";
          return result;
        }

        existing = loadOperationalGeometrySnapshot(arguments.routeInstanceId);
        if (existing.valid) {
          result.SUCCESS = true;
          result.REUSED = true;
          result.LEG_COUNT = existing.leg_count;
          result.MARKER_COUNT = arrayLen(existing.pins);
          return result;
        }
        if (existing.status NEQ "missing") {
          result.ERROR = (
            existing.status EQ "unavailable"
              ? "OPERATIONAL_GEOMETRY_SNAPSHOT_STORE_UNAVAILABLE"
              : "OPERATIONAL_GEOMETRY_SNAPSHOT_INVALID"
          );
          result.MESSAGE = "The operational geometry snapshot store is unavailable or contains an invalid immutable row.";
          return result;
        }

        payloadResult = buildOperationalGeometrySnapshotPayload(
          routeInstanceId=arguments.routeInstanceId,
          ownerUserId=arguments.ownerUserId
        );
        if (!payloadResult.SUCCESS) {
          return payloadResult;
        }

        snapshotJson = serializeJSON(payloadResult.SNAPSHOT);
        queryExecute(
          "INSERT INTO route_instance_geometry_snapshots
              (route_instance_id, snapshot_version, snapshot_json, created_at_utc)
           VALUES
              (:routeInstanceId, 1, :snapshotJson, UTC_TIMESTAMP(6))",
          {
            routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" },
            snapshotJson = { value=snapshotJson, cfsqltype="cf_sql_longvarchar" }
          },
          { datasource=variables.datasource }
        );

        result.SUCCESS = true;
        result.CREATED = true;
        result.LEG_COUNT = payloadResult.LEG_COUNT;
        result.MARKER_COUNT = payloadResult.MARKER_COUNT;
        return result;
      } catch (any snapshotCreateErr) {
        existing = loadOperationalGeometrySnapshot(arguments.routeInstanceId);
        if (existing.valid) {
          result.SUCCESS = true;
          result.REUSED = true;
          result.LEG_COUNT = existing.leg_count;
          result.MARKER_COUNT = arrayLen(existing.pins);
          return result;
        }
        result.ERROR = "OPERATIONAL_GEOMETRY_SNAPSHOT_CREATE_FAILED";
        result.MESSAGE = "Unable to create the immutable operational geometry snapshot.";
        return result;
      }
    </cfscript>
  </cffunction>

  <cffunction name="buildOperationalGeometrySnapshotPayload" access="private" returntype="struct" output="false">
    <cfargument name="routeInstanceId" type="numeric" required="true">
    <cfargument name="ownerUserId" type="numeric" required="true">
    <cfscript>
      var result = {
        "SUCCESS"=false,
        "ROUTE_INSTANCE_ID"=val(arguments.routeInstanceId),
        "LEG_COUNT"=0,
        "MARKER_COUNT"=0
      };
      var qRoute = queryNew("");
      var qLegs = queryNew("");
      var generatedRouteId = 0;
      var originalCustomRouteId = 0;
      var routeInputsRaw = "";
      var templateRouteCode = "";
      var segments = [];
      var markers = [];
      var coords = [];
      var anchoredCoords = [];
      var segmentStart = [];
      var segmentEnd = [];
      var startLatRaw = "";
      var startLngRaw = "";
      var endLatRaw = "";
      var endLngRaw = "";
      var startLat = 0.0;
      var startLng = 0.0;
      var endLat = 0.0;
      var endLng = 0.0;
      var hasStart = false;
      var hasEnd = false;
      var startLabel = "";
      var endLabel = "";
      var legOrder = 0;
      var routeInstanceLegId = 0;
      var segmentId = 0;
      var sourceLoopSegmentId = 0;
      var previousMarker = {};
      var markerIndex = 0;
      var i = 0;

      qRoute = queryExecute(
        "SELECT generated_route_id, template_route_code, routegen_inputs_json
         FROM route_instances
         WHERE id = :routeInstanceId
           AND user_id = :userId
         LIMIT 1",
        {
          routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" },
          userId = { value=toString(arguments.ownerUserId), cfsqltype="cf_sql_varchar" }
        },
        { datasource=variables.datasource }
      );
      if (qRoute.recordCount NEQ 1) {
        result.ERROR = "OPERATIONAL_GEOMETRY_ROUTE_NOT_FOUND";
        result.MESSAGE = "The operational route instance could not be resolved for geometry capture.";
        return result;
      }

      generatedRouteId = (isNull(qRoute.generated_route_id[1]) ? 0 : val(qRoute.generated_route_id[1]));
      templateRouteCode = (isNull(qRoute.template_route_code[1]) ? "" : uCase(trim(toString(qRoute.template_route_code[1]))));
      routeInputsRaw = (isNull(qRoute.routegen_inputs_json[1]) ? "" : trim(toString(qRoute.routegen_inputs_json[1])));
      originalCustomRouteId = resolveOriginalCustomRouteId(templateRouteCode, routeInputsRaw);

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
            end_lng
         FROM route_instance_legs
         WHERE route_instance_id = :routeInstanceId
         ORDER BY leg_order ASC, id ASC",
        {
          routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" }
        },
        { datasource=variables.datasource }
      );
      if (qLegs.recordCount LTE 0) {
        result.ERROR = "OPERATIONAL_GEOMETRY_LEGS_REQUIRED";
        result.MESSAGE = "Operational route legs are required before geometry can be captured.";
        return result;
      }

      for (i = 1; i LTE qLegs.recordCount; i++) {
        routeInstanceLegId = val(qLegs.id[i]);
        legOrder = val(qLegs.leg_order[i]);
        segmentId = (isNull(qLegs.segment_id[i]) ? 0 : val(qLegs.segment_id[i]));
        sourceLoopSegmentId = (isNull(qLegs.source_loop_segment_id[i]) ? 0 : val(qLegs.source_loop_segment_id[i]));
        startLabel = (isNull(qLegs.start_name[i]) ? "Start" : trim(toString(qLegs.start_name[i])));
        endLabel = (isNull(qLegs.end_name[i]) ? "End" : trim(toString(qLegs.end_name[i])));
        startLatRaw = (isNull(qLegs.start_lat[i]) ? "" : trim(toString(qLegs.start_lat[i])));
        startLngRaw = (isNull(qLegs.start_lng[i]) ? "" : trim(toString(qLegs.start_lng[i])));
        endLatRaw = (isNull(qLegs.end_lat[i]) ? "" : trim(toString(qLegs.end_lat[i])));
        endLngRaw = (isNull(qLegs.end_lng[i]) ? "" : trim(toString(qLegs.end_lng[i])));
        hasStart = (len(startLatRaw) AND len(startLngRaw) AND isNumeric(startLatRaw) AND isNumeric(startLngRaw));
        hasEnd = (len(endLatRaw) AND len(endLngRaw) AND isNumeric(endLatRaw) AND isNumeric(endLngRaw));

        coords = resolveRouteInstanceLegCoordinates(
          ownerUserId=arguments.ownerUserId,
          generatedRouteId=generatedRouteId,
          originalCustomRouteId=originalCustomRouteId,
          routeInstanceLegId=routeInstanceLegId,
          sourceLoopSegmentId=sourceLoopSegmentId,
          routeLegOrder=legOrder,
          segmentId=segmentId
        );
        if (arrayLen(coords) GTE 2) {
          segmentStart = coords[1];
          segmentEnd = coords[arrayLen(coords)];
        } else {
          segmentStart = [];
          segmentEnd = [];
        }

        if (!hasStart AND arrayLen(segmentStart) GTE 2 AND isNumeric(segmentStart[1]) AND isNumeric(segmentStart[2])) {
          startLatRaw = toString(val(segmentStart[2]));
          startLngRaw = toString(val(segmentStart[1]));
          hasStart = true;
        }
        if (!hasEnd AND arrayLen(segmentEnd) GTE 2 AND isNumeric(segmentEnd[1]) AND isNumeric(segmentEnd[2])) {
          endLatRaw = toString(val(segmentEnd[2]));
          endLngRaw = toString(val(segmentEnd[1]));
          hasEnd = true;
        }
        if (!hasStart OR !hasEnd) {
          result.ERROR = "OPERATIONAL_GEOMETRY_ENDPOINTS_REQUIRED";
          result.MESSAGE = "Every operational leg requires valid start and end coordinates before geometry can be captured.";
          return result;
        }

        startLat = val(startLatRaw);
        startLng = val(startLngRaw);
        endLat = val(endLatRaw);
        endLng = val(endLngRaw);
        if (!isValidCoordinatePair(startLat, startLng) OR !isValidCoordinatePair(endLat, endLng)) {
          result.ERROR = "OPERATIONAL_GEOMETRY_ENDPOINTS_INVALID";
          result.MESSAGE = "An operational leg contains invalid geographic coordinates.";
          return result;
        }

        anchoredCoords = anchorSegmentCoordinates(
          coordinates=coords,
          startLat=startLat,
          startLng=startLng,
          endLat=endLat,
          endLng=endLng
        );
        if (arrayLen(anchoredCoords) LT 2) {
          result.ERROR = "OPERATIONAL_GEOMETRY_SEGMENT_REQUIRED";
          result.MESSAGE = "Every operational leg requires displayable line geometry.";
          return result;
        }

        arrayAppend(segments, {
          "route_instance_leg_id"=routeInstanceLegId,
          "leg_order"=legOrder,
          "coordinates"=anchoredCoords,
          "start_endpoint"={
            "lat"=startLat,
            "lng"=startLng,
            "label"=(len(startLabel) ? startLabel : "Start")
          },
          "end_endpoint"={
            "lat"=endLat,
            "lng"=endLng,
            "label"=(len(endLabel) ? endLabel : "End")
          }
        });

        if (arrayLen(markers) EQ 0) {
          arrayAppend(markers, {
            "lat"=startLat,
            "lng"=startLng,
            "label"=(len(startLabel) ? startLabel : "Start"),
            "route_instance_leg_id"=routeInstanceLegId,
            "leg_order"=legOrder,
            "endpoint_role"="start"
          });
        } else {
          previousMarker = markers[arrayLen(markers)];
          if (
            !isStruct(previousMarker)
            OR !structKeyExists(previousMarker, "lat")
            OR !structKeyExists(previousMarker, "lng")
            OR haversineMeters(val(previousMarker.lat), val(previousMarker.lng), startLat, startLng) GT 1
          ) {
            arrayAppend(markers, {
              "lat"=startLat,
              "lng"=startLng,
              "label"=(len(startLabel) ? startLabel : "Waypoint"),
              "route_instance_leg_id"=routeInstanceLegId,
              "leg_order"=legOrder,
              "endpoint_role"="start"
            });
          }
        }
        arrayAppend(markers, {
          "lat"=endLat,
          "lng"=endLng,
          "label"=(len(endLabel) ? endLabel : "End"),
          "route_instance_leg_id"=routeInstanceLegId,
          "leg_order"=legOrder,
          "endpoint_role"="end"
        });
      }

      for (markerIndex = 1; markerIndex LTE arrayLen(markers); markerIndex++) {
        markers[markerIndex].seq = markerIndex;
        markers[markerIndex].sequence = markerIndex;
        markers[markerIndex].type = (
          markerIndex EQ 1
            ? "start"
            : (markerIndex EQ arrayLen(markers) ? "end" : "leg_end")
        );
      }

      result.SUCCESS = true;
      result.LEG_COUNT = arrayLen(segments);
      result.MARKER_COUNT = arrayLen(markers);
      result.SNAPSHOT = {
        "schema_version"=1,
        "route_instance_id"=val(arguments.routeInstanceId),
        "geometry_authority"="route_instance_geometry_snapshot",
        "endpoint_policy"="saved_waypoints_anchor_resolved_segments",
        "source_precedence"=[
          "route_leg_user_overrides_exact_leg",
          "route_leg_user_overrides_custom_route_order",
          "route_leg_user_overrides_segment",
          "segment_geometries",
          "route_instance_leg_endpoints"
        ],
        "segments"=segments,
        "markers"=markers
      };
      return result;
    </cfscript>
  </cffunction>

  <cffunction name="loadOperationalGeometrySnapshot" access="private" returntype="struct" output="false">
    <cfargument name="routeInstanceId" type="numeric" required="true">
    <cfscript>
      var state = {
        "valid"=false,
        "status"="missing",
        "route_geo"={ "type"="MultiLineString", "coordinates"=[] },
        "pins"=[],
        "leg_count"=0,
        "created_at_utc"=""
      };
      var qSnapshot = queryNew("");
      var rawJson = "";
      var parsed = {};
      var segments = [];
      var markers = [];
      var coordinates = [];
      var segment = {};
      var marker = {};
      var routeSegments = [];
      var pins = [];
      var legOrder = 0;
      var priorLegOrder = 0;
      var sequence = 0;
      var markerType = "";
      var i = 0;

      try {
        qSnapshot = queryExecute(
          "SELECT snapshot_version, snapshot_json, created_at_utc
           FROM route_instance_geometry_snapshots
           WHERE route_instance_id = :routeInstanceId
           LIMIT 1",
          {
            routeInstanceId = { value=arguments.routeInstanceId, cfsqltype="cf_sql_integer" }
          },
          { datasource=variables.datasource }
        );
      } catch (any snapshotLookupErr) {
        state.status = "unavailable";
        return state;
      }
      if (qSnapshot.recordCount EQ 0) {
        return state;
      }
      if (isNull(qSnapshot.snapshot_version[1]) OR val(qSnapshot.snapshot_version[1]) NEQ 1) {
        state.status = "unsupported_version";
        return state;
      }
      rawJson = (isNull(qSnapshot.snapshot_json[1]) ? "" : trim(toString(qSnapshot.snapshot_json[1])));
      if (!len(rawJson)) {
        state.status = "malformed";
        return state;
      }
      try {
        parsed = deserializeJSON(rawJson, false);
      } catch (any snapshotParseErr) {
        state.status = "malformed";
        return state;
      }
      if (
        !isStruct(parsed)
        OR !structKeyExists(parsed, "schema_version")
        OR val(parsed.schema_version) NEQ 1
        OR !structKeyExists(parsed, "route_instance_id")
        OR val(parsed.route_instance_id) NEQ val(arguments.routeInstanceId)
        OR !structKeyExists(parsed, "segments")
        OR !isArray(parsed.segments)
        OR !arrayLen(parsed.segments)
        OR !structKeyExists(parsed, "markers")
        OR !isArray(parsed.markers)
        OR arrayLen(parsed.markers) LT 2
      ) {
        state.status = "malformed";
        return state;
      }

      segments = parsed.segments;
      for (i = 1; i LTE arrayLen(segments); i++) {
        segment = segments[i];
        if (
          !isStruct(segment)
          OR !structKeyExists(segment, "route_instance_leg_id")
          OR val(segment.route_instance_leg_id) LTE 0
          OR !structKeyExists(segment, "leg_order")
          OR !isNumeric(segment.leg_order)
          OR !structKeyExists(segment, "coordinates")
          OR !isArray(segment.coordinates)
        ) {
          state.status = "malformed";
          return state;
        }
        legOrder = val(segment.leg_order);
        if (legOrder LTE priorLegOrder) {
          state.status = "malformed";
          return state;
        }
        priorLegOrder = legOrder;
        coordinates = parseGeometryCoordinates(serializeJSON(segment.coordinates));
        if (arrayLen(coordinates) LT 2) {
          state.status = "malformed";
          return state;
        }
        arrayAppend(routeSegments, coordinates);
      }

      markers = parsed.markers;
      for (i = 1; i LTE arrayLen(markers); i++) {
        marker = markers[i];
        if (
          !isStruct(marker)
          OR !structKeyExists(marker, "lat")
          OR !structKeyExists(marker, "lng")
          OR !isNumeric(marker.lat)
          OR !isNumeric(marker.lng)
          OR !isValidCoordinatePair(val(marker.lat), val(marker.lng))
        ) {
          state.status = "malformed";
          return state;
        }
        sequence = (
          structKeyExists(marker, "sequence") AND isNumeric(marker.sequence)
            ? val(marker.sequence)
            : i
        );
        if (sequence NEQ i) {
          state.status = "malformed";
          return state;
        }
        markerType = lCase(trim(toString(structKeyExists(marker, "type") ? marker.type : "leg_end")));
        if (!listFindNoCase("start,end,leg_end,waypoint", markerType)) {
          state.status = "malformed";
          return state;
        }
        arrayAppend(pins, {
          "lat"=val(marker.lat),
          "lng"=val(marker.lng),
          "label"=(structKeyExists(marker, "label") ? trim(toString(marker.label)) : "Point"),
          "seq"=i,
          "sequence"=i,
          "type"=markerType,
          "route_instance_leg_id"=(structKeyExists(marker, "route_instance_leg_id") ? val(marker.route_instance_leg_id) : 0),
          "leg_order"=(structKeyExists(marker, "leg_order") ? val(marker.leg_order) : 0),
          "endpoint_role"=(structKeyExists(marker, "endpoint_role") ? lCase(trim(toString(marker.endpoint_role))) : "")
        });
      }
      if (pins[1].type NEQ "start" OR pins[arrayLen(pins)].type NEQ "end") {
        state.status = "malformed";
        return state;
      }

      state.valid = true;
      state.status = "valid";
      state.route_geo = { "type"="MultiLineString", "coordinates"=routeSegments };
      state.pins = pins;
      state.leg_count = arrayLen(routeSegments);
      state.created_at_utc = (isNull(qSnapshot.created_at_utc[1]) ? "" : qSnapshot.created_at_utc[1]);
      return state;
    </cfscript>
  </cffunction>

  <cffunction name="resolveOriginalCustomRouteId" access="private" returntype="numeric" output="false">
    <cfargument name="templateRouteCode" type="string" required="false" default="">
    <cfargument name="routeInputsRaw" type="string" required="false" default="">
    <cfscript>
      var routeInputs = {};
      if (uCase(trim(arguments.templateRouteCode)) NEQ "MY_ROUTE" OR !len(trim(arguments.routeInputsRaw))) {
        return 0;
      }
      try {
        routeInputs = deserializeJSON(arguments.routeInputsRaw);
      } catch (any routeInputsErr) {
        return 0;
      }
      if (
        isStruct(routeInputs)
        AND structKeyExists(routeInputs, "route_id")
        AND isNumeric(routeInputs.route_id)
        AND val(routeInputs.route_id) GT 0
      ) {
        return val(routeInputs.route_id);
      }
      return 0;
    </cfscript>
  </cffunction>

  <cffunction name="resolveRouteInstanceLegCoordinates" access="private" returntype="array" output="false">
    <cfargument name="ownerUserId" type="numeric" required="true">
    <cfargument name="generatedRouteId" type="numeric" required="false" default="0">
    <cfargument name="originalCustomRouteId" type="numeric" required="false" default="0">
    <cfargument name="routeInstanceLegId" type="numeric" required="true">
    <cfargument name="sourceLoopSegmentId" type="numeric" required="false" default="0">
    <cfargument name="routeLegOrder" type="numeric" required="false" default="0">
    <cfargument name="segmentId" type="numeric" required="false" default="0">
    <cfscript>
      var routeLegId = (arguments.sourceLoopSegmentId GT 0 ? arguments.sourceLoopSegmentId : arguments.routeInstanceLegId);
      var routeId = arguments.generatedRouteId;
      var allowRouteLegOrderFallback = false;
      if (
        arguments.originalCustomRouteId GT 0
        AND arguments.segmentId LTE 0
        AND arguments.sourceLoopSegmentId LTE 0
      ) {
        routeId = arguments.originalCustomRouteId;
        routeLegId = 0;
        allowRouteLegOrderFallback = (arguments.routeLegOrder GT 0);
      }
      return loadRouteSegmentCoordinates(
        ownerUserId=arguments.ownerUserId,
        routeId=routeId,
        routeLegId=routeLegId,
        routeLegOrder=arguments.routeLegOrder,
        segmentId=arguments.segmentId,
        allowRouteLegOrderFallback=allowRouteLegOrderFallback
      );
    </cfscript>
  </cffunction>

  <cffunction name="anchorSegmentCoordinates" access="private" returntype="array" output="false">
    <cfargument name="coordinates" type="array" required="true">
    <cfargument name="startLat" type="numeric" required="true">
    <cfargument name="startLng" type="numeric" required="true">
    <cfargument name="endLat" type="numeric" required="true">
    <cfargument name="endLng" type="numeric" required="true">
    <cfscript>
      var out = duplicate(arguments.coordinates);
      var firstPoint = [];
      var lastPoint = [];
      var forwardDistanceMeters = 0;
      var reverseDistanceMeters = 0;
      var reversedCoordinates = [];
      var coordinateIndex = 0;
      if (arrayLen(out) LT 2) {
        return [
          [val(arguments.startLng), val(arguments.startLat)],
          [val(arguments.endLng), val(arguments.endLat)]
        ];
      }
      firstPoint = out[1];
      lastPoint = out[arrayLen(out)];
      if (
        isArray(firstPoint)
        AND arrayLen(firstPoint) GTE 2
        AND isNumeric(firstPoint[1])
        AND isNumeric(firstPoint[2])
        AND isArray(lastPoint)
        AND arrayLen(lastPoint) GTE 2
        AND isNumeric(lastPoint[1])
        AND isNumeric(lastPoint[2])
      ) {
        forwardDistanceMeters = haversineMeters(arguments.startLat, arguments.startLng, firstPoint[2], firstPoint[1])
          + haversineMeters(arguments.endLat, arguments.endLng, lastPoint[2], lastPoint[1]);
        reverseDistanceMeters = haversineMeters(arguments.startLat, arguments.startLng, lastPoint[2], lastPoint[1])
          + haversineMeters(arguments.endLat, arguments.endLng, firstPoint[2], firstPoint[1]);
        if (reverseDistanceMeters LT forwardDistanceMeters) {
          for (coordinateIndex = arrayLen(out); coordinateIndex GTE 1; coordinateIndex--) {
            arrayAppend(reversedCoordinates, out[coordinateIndex]);
          }
          out = reversedCoordinates;
          firstPoint = out[1];
        }
      }
      if (
        !isArray(firstPoint)
        OR arrayLen(firstPoint) LT 2
        OR val(firstPoint[1]) NEQ val(arguments.startLng)
        OR val(firstPoint[2]) NEQ val(arguments.startLat)
      ) {
        arrayInsertAt(out, 1, [val(arguments.startLng), val(arguments.startLat)]);
      }
      lastPoint = out[arrayLen(out)];
      if (
        !isArray(lastPoint)
        OR arrayLen(lastPoint) LT 2
        OR val(lastPoint[1]) NEQ val(arguments.endLng)
        OR val(lastPoint[2]) NEQ val(arguments.endLat)
      ) {
        arrayAppend(out, [val(arguments.endLng), val(arguments.endLat)]);
      }
      return out;
    </cfscript>
  </cffunction>

  <cffunction name="findSnapshotEndPin" access="private" returntype="struct" output="false">
    <cfargument name="pins" type="array" required="true">
    <cfargument name="legOrder" type="numeric" required="true">
    <cfscript>
      var i = 0;
      var pin = {};
      for (i = 1; i LTE arrayLen(arguments.pins); i++) {
        pin = arguments.pins[i];
        if (
          isStruct(pin)
          AND structKeyExists(pin, "leg_order")
          AND val(pin.leg_order) EQ val(arguments.legOrder)
          AND structKeyExists(pin, "endpoint_role")
          AND lCase(trim(toString(pin.endpoint_role))) EQ "end"
        ) {
          return pin;
        }
      }
      return {};
    </cfscript>
  </cffunction>

  <cffunction name="isValidCoordinatePair" access="private" returntype="boolean" output="false">
    <cfargument name="lat" type="numeric" required="true">
    <cfargument name="lng" type="numeric" required="true">
    <cfscript>
      return (
        arguments.lat GTE -90
        AND arguments.lat LTE 90
        AND arguments.lng GTE -180
        AND arguments.lng LTE 180
      );
    </cfscript>
  </cffunction>

  <cffunction name="isWholeCoordinatePair" access="private" returntype="boolean" output="false">
    <cfargument name="lat" type="numeric" required="true">
    <cfargument name="lng" type="numeric" required="true">
    <cfscript>
      return (
        abs(arguments.lat - round(arguments.lat)) LT 0.00000005
        AND abs(arguments.lng - round(arguments.lng)) LT 0.00000005
      );
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
      if (arguments.x GT 0) {
        return atn(arguments.y / arguments.x);
      }
      if (arguments.x LT 0 AND arguments.y GTE 0) {
        return atn(arguments.y / arguments.x) + pi();
      }
      if (arguments.x LT 0 AND arguments.y LT 0) {
        return atn(arguments.y / arguments.x) - pi();
      }
      if (arguments.x EQ 0 AND arguments.y GT 0) {
        return pi() / 2;
      }
      if (arguments.x EQ 0 AND arguments.y LT 0) {
        return -pi() / 2;
      }
      return 0;
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
