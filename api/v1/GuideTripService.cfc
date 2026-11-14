component output=false {
  // Guide-only state. Existing routes never depend on this table or these calculations.
  public any function init(string datasource="fpw") { variables.dsn=arguments.datasource; return this; }

  public boolean function isInstalled() {
    if (!structKeyExists(request,"fpwGuideTablePresent")) {
      var q=db("SELECT COUNT(*) AS n FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='guide_route_imports'");
      request.fpwGuideTablePresent=val(q.n[1]) EQ 1;
    }
    return request.fpwGuideTablePresent;
  }

  public struct function getManifest(required string templateKey,required numeric templateVersion,boolean requirePublished=true) {
    if (arguments.templateKey NEQ "fort-lauderdale-bimini" OR arguments.templateVersion NEQ 1)
      fail("TEMPLATE_UNAVAILABLE","This itinerary version is unavailable.");
    var path=getDirectoryFromPath(getCurrentTemplatePath()) & "../../publishing/bahamas/templates/fort-lauderdale-bimini-v1.json";
    if (!fileExists(path)) fail("TEMPLATE_UNAVAILABLE","This itinerary is not available yet.");
    var manifest=deserializeJSON(fileRead(path,"utf-8"));
    if (!isStruct(manifest) OR manifest.template_key NEQ arguments.templateKey OR val(manifest.template_version) NEQ arguments.templateVersion)
      fail("TEMPLATE_INVALID","This itinerary's source data could not be loaded.");
    var sourcesPath=getDirectoryFromPath(getCurrentTemplatePath()) & "../../publishing/bahamas/sources.json";
    if (fileExists(sourcesPath)) {
      var register=deserializeJSON(fileRead(sourcesPath,"utf-8"));
      if (isStruct(register) AND structKeyExists(register,"sources") AND isArray(register.sources)) manifest["sources"]=register.sources;
    }
    if (arguments.requirePublished) validateManifest(manifest);
    return manifest;
  }

  public void function validateManifest(required struct manifest) {
    var m=arguments.manifest;
    if (!structKeyExists(m,"status") OR m.status NEQ "published")
      fail("TEMPLATE_UNAVAILABLE","This itinerary is still being prepared. Return to the guide for its current status.");
    if (!structKeyExists(m,"stops") OR !isArray(m.stops) OR arrayLen(m.stops) LT 2
      OR !structKeyExists(m,"legs") OR !isArray(m.legs) OR !arrayLen(m.legs) OR arrayLen(m.legs) GT 200)
      fail("TEMPLATE_INVALID","This itinerary has incomplete stop data.");
    var stops={};
    for (var stop in m.stops) {
      if (!isStruct(stop) OR !len(clean(stop,"key",64)) OR structKeyExists(stops,stop.key)
        OR !len(clean(stop,"name",255)) OR !coordinate(stop,"latitude",90) OR !coordinate(stop,"longitude",180)
        OR !listFind("maritime_reference,marina_destination_reference",clean(stop,"coordinate_role",40))
        OR !structKeyExists(stop,"source_ids") OR !isArray(stop.source_ids) OR !arrayLen(stop.source_ids))
        fail("TEMPLATE_INVALID","A source-backed maritime stop is missing. This example cannot be imported yet.");
      stops[stop.key]=stop;
    }
    var prior="";
    var keys={};
    for (var leg in m.legs) {
      if (!isStruct(leg) OR !len(clean(leg,"key",64)) OR structKeyExists(keys,leg.key)
        OR !structKeyExists(stops,clean(leg,"from_stop_key",64)) OR !structKeyExists(stops,clean(leg,"to_stop_key",64))
        OR (len(prior) AND prior NEQ leg.from_stop_key))
        fail("TEMPLATE_INVALID","The itinerary's movement legs are not connected.");
      keys[leg.key]=true;
      prior=leg.to_stop_key;
      if (hasNumber(leg,"distance_nm") AND (leg.distance_nm LTE 0 OR leg.distance_nm GT 100000 OR !listFind("source_reported_estimate,illustrative_estimate",clean(leg,"distance_kind",40)) OR !len(clean(leg,"distance_method",2000))))
        fail("TEMPLATE_INVALID","A planning estimate needs a positive value and its source or calculation method.");
    }
  }

  public struct function importTrip(required numeric userId,required struct body) {
    requireInstalled();
    var key=clean(arguments.body,"template_key",64);
    var version=number(arguments.body,"template_version",0,1,2147483647);
    var requestId=uuidValue(arguments.body,"import_request_id");
    var another=structKeyExists(arguments.body,"create_another") AND isBoolean(arguments.body.create_another) AND arguments.body.create_another;
    var manifest=getManifest(key,version);
    var routeId=0;
    var reused=false;
    transaction {
      lockOwner(arguments.userId);
      var existing=db("SELECT g.*,ur.is_active FROM guide_route_imports g LEFT JOIN user_routes ur ON ur.id=g.user_route_id WHERE g.user_id=:uid AND (g.import_request_id=:rid OR JSON_CONTAINS_PATH(COALESCE(g.request_history_json,'{}'),'one',:requestPath)) FOR UPDATE",
        {uid=intParam(arguments.userId),rid=strParam(requestId),requestPath=strParam('$.imports."' & requestId & '"')});
      if (existing.recordCount) {
        if (existing.template_key[1] NEQ key OR val(existing.template_version[1]) NEQ version)
          fail("REQUEST_CONFLICT","This import request was already used for another itinerary.");
        if (len(trim(toString(existing.deleted_at[1]))) OR isNull(existing.is_active[1]) OR val(existing.is_active[1]) NEQ 1)
          fail("COPY_DELETED","This copy was deleted. Choose Create another copy to start a new itinerary.");
        routeId=val(existing.user_route_id[1]); reused=true;
      } else if (!another) {
        existing=db("SELECT g.user_route_id FROM guide_route_imports g INNER JOIN user_routes ur ON ur.id=g.user_route_id AND ur.is_active=1 WHERE g.user_id=:uid AND g.template_key=:t AND g.template_version=:v AND g.deleted_at IS NULL ORDER BY g.id DESC LIMIT 1 FOR UPDATE",
          {uid=intParam(arguments.userId),t=strParam(key),v=intParam(version)});
        if (existing.recordCount) { routeId=val(existing.user_route_id[1]); reused=true; }
      }
      if (!routeId) {
        var stopIds={};
        for (var stop in manifest.stops) {
          stopIds[stop.key]=insertRow("INSERT INTO waypoints (name,latitude,longitude,userId,notes) VALUES (:n,:lat,:lng,:uid,:notes)",
            {n=strParam(stop.name),lat=strParam(toString(stop.latitude)),lng=strParam(toString(stop.longitude)),uid=strParam(toString(arguments.userId)),
             notes=textParam("Guide planning reference; not a verified navigational waypoint. Sources: " & arrayToList(stop.source_ids,", "))});
        }
        var routeName=left(manifest.title,230); var copyIndex=1;
        var nameQuery=db("SELECT id FROM user_routes WHERE user_id=:uid AND route_name=:n LIMIT 1",{uid=intParam(arguments.userId),n=strParam(routeName)});
        while (nameQuery.recordCount) {
          copyIndex++; routeName=left(manifest.title,230) & " (copy " & copyIndex & ")";
          if (copyIndex GT 100) fail("NAME_CONFLICT","Choose a distinct name for an additional copy.");
          nameQuery=db("SELECT id FROM user_routes WHERE user_id=:uid AND route_name=:n LIMIT 1",{uid=intParam(arguments.userId),n=strParam(routeName)});
        }
        routeId=insertRow("INSERT INTO user_routes (user_id,route_name,start_waypoint_id,is_active) VALUES (:uid,:n,:wp,1)",
          {uid=intParam(arguments.userId),n=strParam(routeName),wp=intParam(stopIds[manifest.legs[1].from_stop_key])});
        var legState={};
        for (var i=1;i LTE arrayLen(manifest.legs);i++) {
          var source=manifest.legs[i];
          var legId=insertRow("INSERT INTO user_route_legs (user_route_id,order_index,segment_id,start_waypoint_id,end_waypoint_id) VALUES (:rid,:ord,NULL,:sw,:ew)",
            {rid=intParam(routeId),ord=intParam(i),sw=intParam(stopIds[source.from_stop_key]),ew=intParam(stopIds[source.to_stop_key])});
          var item={};
          item["leg_key"]=source.key;
          item["distance_nm"]=hasNumber(source,"distance_nm") ? val(source.distance_nm) : "";
          item["distance_kind"]=hasNumber(source,"distance_nm") ? clean(source,"distance_kind",40) : "missing";
          item["distance_method"]=clean(source,"distance_method",2000);
          item["source_ids"]=structKeyExists(source,"source_ids") AND isArray(source.source_ids) ? source.source_ids : [];
          item["source_dates"]=structKeyExists(source,"source_dates") ? duplicate(source.source_dates) : {};
          item["geometry_kind"]="schematic"; item["geometry_fingerprint"]="";
          item["review_status"]="unreviewed"; item["review_fingerprint"]=""; item["reviewed_at"]="";
          legState[toString(legId)]=item;
        }
        var inputs=normalizeInputs(structKeyExists(manifest,"planning_inputs") ? manifest.planning_inputs : {});
        inputs["performance_confirmed"]=false;
        insertRow("INSERT INTO guide_route_imports (user_id,template_key,template_version,import_request_id,user_route_id,source_snapshot_json,leg_state_json,planning_inputs_json,trip_notes,draft_revision,generated_revision,created_at,updated_at) VALUES (:uid,:t,:v,:req,:rid,:src,:legs,:inputs,:notes,1,0,UTC_TIMESTAMP(),UTC_TIMESTAMP())",
          {uid=intParam(arguments.userId),t=strParam(key),v=intParam(version),req=strParam(requestId),rid=intParam(routeId),
           src=textParam(serializeJSON(manifest)),legs=textParam(serializeJSON(legState)),inputs=textParam(serializeJSON(inputs)),
           notes=textParam(clean(manifest,"trip_notes",12000))});
        // Save the initial endpoint fingerprints without claiming member review.
        var draft=getDraft(arguments.userId,routeId);
        persistLegState(arguments.userId,routeId,draft.legs);
        new fpw.includes.ProductEventService().init(variables.dsn).recordRequiredMemberActivity(arguments.userId,"user_route_created",routeId);
      }
      var historyRow=db("SELECT request_history_json FROM guide_route_imports WHERE user_id=:uid AND user_route_id=:rid FOR UPDATE",{uid=intParam(arguments.userId),rid=intParam(routeId)});
      var history=parseObject(isNull(historyRow.request_history_json[1]) ? "" : toString(historyRow.request_history_json[1]));
      if (!structKeyExists(history,"imports")) history["imports"]={};
      history.imports[requestId]={template_key=key,template_version=version};
      db("UPDATE guide_route_imports SET request_history_json=:h WHERE user_id=:uid AND user_route_id=:rid",
        {h=textParam(serializeJSON(history)),uid=intParam(arguments.userId),rid=intParam(routeId)});
    }
    var result=getDraft(arguments.userId,routeId);
    result["reused"]=reused;
    return result;
  }

  public boolean function isGuideRoute(required numeric userId,required numeric routeId) {
    if (!isInstalled() OR arguments.routeId LTE 0) return false;
    return db("SELECT id FROM guide_route_imports WHERE user_id=:uid AND user_route_id=:rid LIMIT 1",
      {uid=intParam(arguments.userId),rid=intParam(arguments.routeId)}).recordCount GT 0;
  }

  public struct function getDraft(required numeric userId,required numeric routeId) {
    requireInstalled();
    var q=db("SELECT g.*,ur.route_name,ur.is_active FROM guide_route_imports g INNER JOIN user_routes ur ON ur.id=g.user_route_id AND ur.user_id=g.user_id WHERE g.user_id=:uid AND g.user_route_id=:rid LIMIT 1",
      {uid=intParam(arguments.userId),rid=intParam(arguments.routeId)});
    if (!q.recordCount OR val(q.is_active[1]) NEQ 1 OR len(trim(toString(q.deleted_at[1]))))
      fail("COPY_UNAVAILABLE","This planning draft is unavailable or does not belong to your account.");
    var stored=parseObject(q.leg_state_json[1]);
    var rows=db("SELECT l.id,l.order_index,l.start_waypoint_id,l.end_waypoint_id,COALESCE(ws.name,ps.name,sl.start_port_name,'') AS start_name,COALESCE(we.name,pe.name,sl.end_port_name,'') AS end_name,COALESCE(ws.latitude,ps.lat) AS start_lat,COALESCE(ws.longitude,ps.lng) AS start_lng,COALESCE(we.latitude,pe.lat) AS end_lat,COALESCE(we.longitude,pe.lng) AS end_lng,o.geometry_json,o.computed_nm FROM user_route_legs l INNER JOIN user_routes ur ON ur.id=l.user_route_id LEFT JOIN waypoints ws ON ws.wpId=l.start_waypoint_id AND ws.userId=ur.user_id LEFT JOIN waypoints we ON we.wpId=l.end_waypoint_id AND we.userId=ur.user_id LEFT JOIN segment_library sl ON sl.id=l.segment_id LEFT JOIN ports ps ON ps.id=sl.start_port_id LEFT JOIN ports pe ON pe.id=sl.end_port_id LEFT JOIN route_leg_user_overrides o ON o.route_id=l.user_route_id AND o.route_leg_id=l.id AND o.user_id=ur.user_id WHERE ur.id=:rid AND ur.user_id=:uid ORDER BY l.order_index,l.id",
      {rid=intParam(arguments.routeId),uid=intParam(arguments.userId)});
    var legs=[];
    for (var i=1;i LTE rows.recordCount;i++) {
      var id=toString(rows.id[i]);
      var leg=structKeyExists(stored,id) ? duplicate(stored[id]) : newLegState("member-" & id);
      leg["user_route_leg_id"]=val(id); leg["order_index"]=i;
      leg["start_waypoint_id"]=isNull(rows.start_waypoint_id[i]) ? 0 : val(rows.start_waypoint_id[i]);
      leg["end_waypoint_id"]=isNull(rows.end_waypoint_id[i]) ? 0 : val(rows.end_waypoint_id[i]);
      leg["start_name"]=rows.start_name[i]; leg["end_name"]=rows.end_name[i];
      for (var coord in ["start_lat","start_lng","end_lat","end_lng"])
        leg[coord]=isNull(rows[coord][i]) ? "" : rows[coord][i];
      var endpoint=endpointFingerprint(leg);
      if (structKeyExists(leg,"endpoint_fingerprint") AND leg.endpoint_fingerprint NEQ endpoint) {
        leg["distance_nm"]=""; leg["distance_kind"]="missing";
        leg["distance_method"]="Endpoints changed; enter a planning distance and its source or calculation method.";
        leg["source_ids"]=[]; leg["source_dates"]={};
        clearReview(leg);
      }
      leg["endpoint_fingerprint"]=endpoint;
      var geometryHash=isNull(rows.geometry_json[i]) OR !len(trim(toString(rows.geometry_json[i]))) ? "" : lCase(hash(rows.geometry_json[i],"SHA-256"));
      if (geometryHash NEQ (structKeyExists(leg,"geometry_fingerprint") ? leg.geometry_fingerprint : "")) {
        if (len(geometryHash) AND !isNull(rows.computed_nm[i]) AND val(rows.computed_nm[i]) GT 0) {
          leg["distance_nm"]=val(rows.computed_nm[i]); leg["distance_kind"]="member_plotted";
          leg["distance_method"]="Length of member-drawn geometry; not independently verified navigation.";
          leg["geometry_kind"]="member_plotted"; leg["source_ids"]=[];
        } else {
          leg["distance_nm"]=""; leg["distance_kind"]="missing";
          leg["distance_method"]="The plotted geometry was removed. Enter or confirm a new planning estimate.";
          leg["geometry_kind"]="schematic";
        }
        leg["geometry_fingerprint"]=geometryHash; clearReview(leg);
      }
      leg["distance_missing"]=!hasNumber(leg,"distance_nm");
      if (leg.distance_missing) { leg["distance_nm"]=""; leg["distance_kind"]="missing"; clearReview(leg); }
      leg["distance_method_missing"]=!leg.distance_missing AND !len(clean(leg,"distance_method",2000));
      leg["missing_input"]=leg.distance_missing ? leg.distance_method : (leg.distance_method_missing ? "Source or calculation method for this mileage." : "");
      leg["content_fingerprint"]=legFingerprint(leg);
      if (!structKeyExists(leg,"review_fingerprint") OR leg.review_fingerprint NEQ leg.content_fingerprint) clearReview(leg);
      arrayAppend(legs,leg);
    }
    var result={};
    result["guide_import_id"]=val(q.id[1]); result["user_route_id"]=arguments.routeId;
    result["route_name"]=q.route_name[1]; result["template_key"]=q.template_key[1]; result["template_version"]=val(q.template_version[1]);
    result["revision"]=val(q.draft_revision[1]); result["generated_revision"]=val(q.generated_revision[1]);
    result["planning_inputs"]=normalizeInputs(parseObject(q.planning_inputs_json[1])); result["trip_notes"]=q.trip_notes[1];
    result["legs"]=legs; result["totals"]=calculateTotals(legs,result.planning_inputs);
    result["generated_route_id"]=isNull(q.generated_route_id[1]) ? 0 : val(q.generated_route_id[1]);
    result["generated_route_instance_id"]=isNull(q.generated_route_instance_id[1]) ? 0 : val(q.generated_route_instance_id[1]);
    result["source_snapshot"]=parseObject(q.source_snapshot_json[1]);
    result["can_create_another_copy"]=false;
    try {
      getManifest(result.template_key,result.template_version,true);
      result.can_create_another_copy=true;
    } catch (any unavailableTemplate) {}
    // Existing waypoint and geometry tools own their data. Materialize their changes into
    // this owned draft revision before exposing it, so a revision always identifies one payload.
    var needsSync=structCount(stored) NEQ arrayLen(legs);
    for (var leg in legs) {
      var key=toString(leg.user_route_leg_id);
      if (!structKeyExists(stored,key)) needsSync=true;
      else if (structKeyExists(stored[key],"content_fingerprint")
        AND (stored[key].content_fingerprint NEQ leg.content_fingerprint OR val(stored[key].order_index) NEQ leg.order_index)) needsSync=true;
    }
    if (needsSync) {
      transaction {
        lockOwner(arguments.userId);
        var current=db("SELECT draft_revision,leg_state_json FROM guide_route_imports WHERE user_id=:uid AND user_route_id=:rid FOR UPDATE",
          {uid=intParam(arguments.userId),rid=intParam(arguments.routeId)});
        if (val(current.draft_revision[1]) NEQ result.revision OR compare(toString(current.leg_state_json[1]),toString(q.leg_state_json[1])) NEQ 0)
          return getDraft(arguments.userId,arguments.routeId);
        persistLegState(arguments.userId,arguments.routeId,legs);
        db("UPDATE guide_route_imports SET draft_revision=draft_revision+1,updated_at=UTC_TIMESTAMP() WHERE user_id=:uid AND user_route_id=:rid",
          {uid=intParam(arguments.userId),rid=intParam(arguments.routeId)});
        result.revision++;
      }
    }
    result["has_newer_draft"]=result.generated_revision LT result.revision;
    return result;
  }

  public struct function saveDraft(required numeric userId,required numeric routeId,required struct body) {
    transaction {
      lockOwner(arguments.userId);
      var draft=getDraft(arguments.userId,arguments.routeId);
      var draftRequestId=uuidValue(arguments.body,"draft_request_id");
      var requestPayload=duplicate(arguments.body); structDelete(requestPayload,"csrfToken"); structDelete(requestPayload,"draft_request_id");
      var draftPayloadHash=lCase(hash(canonicalValue(requestPayload),"SHA-256"));
      var priorRequests=db("SELECT user_route_id,request_history_json FROM guide_route_imports WHERE user_id=:uid AND JSON_CONTAINS_PATH(COALESCE(request_history_json,'{}'),'one',:p) FOR UPDATE",
        {uid=intParam(arguments.userId),p=strParam('$.drafts."' & draftRequestId & '"')});
      for (var priorRow in priorRequests) {
        var priorHistory=parseObject(toString(priorRow.request_history_json));
        var prior=priorHistory.drafts[draftRequestId];
        if (val(priorRow.user_route_id) NEQ arguments.routeId OR prior.payload_hash NEQ draftPayloadHash)
          fail("REQUEST_CONFLICT","This draft request was already used with different details.");
        draft["reused"]=true; draft["saved_revision"]=prior.result_revision;
        return draft;
      }
      if (number(arguments.body,"revision",0,1,2147483647) NEQ draft.revision)
        fail("REVISION_CONFLICT","This draft changed in another tab. Reload it before saving.");
      var input=structKeyExists(arguments.body,"planning_inputs") AND isStruct(arguments.body.planning_inputs) ? normalizeInputs(arguments.body.planning_inputs) : draft.planning_inputs;
      var notes=structKeyExists(arguments.body,"trip_notes") ? clean(arguments.body,"trip_notes",12000) : draft.trip_notes;
      var name=structKeyExists(arguments.body,"route_name") ? clean(arguments.body,"route_name",255) : draft.route_name;
      if (!len(name)) fail("NAME_REQUIRED","Enter a name for your planning draft.");
      if (db("SELECT id FROM user_routes WHERE user_id=:uid AND route_name=:n AND id<>:rid LIMIT 1",
        {uid=intParam(arguments.userId),n=strParam(name),rid=intParam(arguments.routeId)}).recordCount)
        fail("NAME_CONFLICT","Another My Route already uses that name. Choose a distinct name.");
      var submitted=structKeyExists(arguments.body,"legs") AND isArray(arguments.body.legs) ? arguments.body.legs : [];
      var byId={};
      for (var item in submitted) {
        if (!isStruct(item)) fail("INPUT_INVALID","A leg update is invalid.");
        var id=toString(number(item,"user_route_leg_id",0,1,2147483647));
        if (structKeyExists(byId,id)) fail("INPUT_INVALID","A leg was submitted twice.");
        byId[id]=item;
      }
      var beforeContent=canonicalValue({planning_inputs=draft.planning_inputs,trip_notes=draft.trip_notes,route_name=draft.route_name,legs=draft.legs});
      var knownIds={};
      for (var leg in draft.legs) {
        var id=toString(leg.user_route_leg_id); knownIds[id]=true;
        if (!structKeyExists(byId,id)) continue;
        var change=byId[id];
        if (clean(change,"content_fingerprint",64) NEQ leg.content_fingerprint)
          fail("LEG_CHANGED","This leg changed. Reload the draft before editing or confirming its mileage.");
        var dist=optionalNumber(change,"distance_nm",0.01,100000);
        var method=clean(change,"distance_method",2000);
        var mileageChanged=toString(dist) NEQ toString(leg.distance_nm);
        if (mileageChanged) {
          // Attribution for the previous mileage does not describe this new value.
          // Keep only a different source/method explicitly supplied with the edit.
          if (compareNoCase(method,clean(leg,"distance_method",2000)) EQ 0) method="";
          for (var sourceLeg in draft.source_snapshot.legs) {
            if (sourceLeg.key EQ leg.leg_key
              AND compareNoCase(method,clean(sourceLeg,"distance_method",2000)) EQ 0) method="";
          }
        }
        var changed=(mileageChanged OR method NEQ leg.distance_method);
        if (changed) {
          leg["distance_nm"]=dist; leg["distance_method"]=method; leg["distance_kind"]=isNumeric(dist) ? "member_entered" : "missing";
          leg["source_ids"]=[]; leg["source_dates"]={};
          clearReview(leg);
        }
        var review=clean(change,"review_action",20);
        if (len(review) AND !listFind("confirm,replace",review)) fail("INPUT_INVALID","Choose a supported mileage review action.");
        leg["distance_missing"]=!isNumeric(dist);
        leg["distance_method_missing"]=!leg.distance_missing AND !len(method);
        leg["missing_input"]=leg.distance_missing ? leg.distance_method : (leg.distance_method_missing ? "Source or calculation method for this mileage." : "");
        leg["content_fingerprint"]=legFingerprint(leg);
        if (len(review)) {
          if (!isNumeric(dist) OR dist LTE 0) fail("DISTANCE_REQUIRED","Enter a planning distance before recording your review.");
          if (!len(method)) fail("METHOD_REQUIRED","Record the source or calculation method for this mileage before confirming your review.");
          leg["review_status"]=(review EQ "replace" OR changed) ? "member_replaced" : "member_confirmed";
          leg["reviewed_by_user_id"]=arguments.userId;
          leg["reviewed_at"]=dateTimeFormat(dateConvert("local2utc",now()),"yyyy-mm-dd'T'HH:nn:ss'Z'");
          leg["review_fingerprint"]=leg.content_fingerprint;
        }
      }
      for (var id in byId) if (!structKeyExists(knownIds,id)) fail("LEG_UNAVAILABLE","A submitted leg is not part of this owned planning draft.");
      var changedContent=beforeContent NEQ canonicalValue({planning_inputs=input,trip_notes=notes,route_name=name,legs=draft.legs});
      var resultingRevision=draft.revision+(changedContent ? 1 : 0);
      if (changedContent) {
      persistLegState(arguments.userId,arguments.routeId,draft.legs);
      db("UPDATE guide_route_imports SET planning_inputs_json=:p,trip_notes=:n,draft_revision=draft_revision+1,updated_at=UTC_TIMESTAMP() WHERE user_id=:uid AND user_route_id=:rid",
        {p=textParam(serializeJSON(input)),n=textParam(notes),uid=intParam(arguments.userId),rid=intParam(arguments.routeId)});
      db("UPDATE user_routes SET route_name=:n,updated_at=NOW() WHERE id=:rid AND user_id=:uid",
        {n=strParam(name),rid=intParam(arguments.routeId),uid=intParam(arguments.userId)});
      }
      var currentHistory=db("SELECT request_history_json FROM guide_route_imports WHERE user_id=:uid AND user_route_id=:rid",
        {uid=intParam(arguments.userId),rid=intParam(arguments.routeId)});
      var history=parseObject(isNull(currentHistory.request_history_json[1]) ? "" : toString(currentHistory.request_history_json[1]));
      if (!structKeyExists(history,"drafts")) history["drafts"]={};
      history.drafts[draftRequestId]={payload_hash=draftPayloadHash,result_revision=resultingRevision};
      db("UPDATE guide_route_imports SET request_history_json=:h WHERE user_id=:uid AND user_route_id=:rid",
        {h=textParam(serializeJSON(history)),uid=intParam(arguments.userId),rid=intParam(arguments.routeId)});
      if (changedContent) new fpw.includes.ProductEventService().init(variables.dsn).recordRequiredMemberActivity(arguments.userId,"user_route_updated",arguments.routeId);
    }
    return getDraft(arguments.userId,arguments.routeId);
  }

  public struct function calculateTotals(required array legs,required struct inputs) {
    var total={};
    total["complete"]=true; total["missing_leg_count"]=0; total["missing_method_count"]=0; total["missing_inputs"]=[];
    total["known_distance_nm"]=0; total["known_run_hours"]=""; total["known_cruise_fuel_us_gal"]="";
    total["base_fuel_us_gal"]=""; total["reserve_fuel_us_gal"]=""; total["required_fuel_us_gal"]="";
    total["usable_above_requirement_us_gal"]="";
    for (var leg in arguments.legs) {
      if (!hasNumber(leg,"distance_nm") OR leg.distance_nm LTE 0) total.missing_leg_count++;
      else {
        total.known_distance_nm+=val(leg.distance_nm);
        if (!len(clean(leg,"distance_method",2000))) total.missing_method_count++;
      }
    }
    if (!arrayLen(arguments.legs)) arrayAppend(total.missing_inputs,"movement legs");
    if (total.missing_leg_count) arrayAppend(total.missing_inputs,"mileage for " & total.missing_leg_count & " leg(s)");
    if (total.missing_method_count) arrayAppend(total.missing_inputs,"source or calculation method for " & total.missing_method_count & " leg(s)");
    var p=arguments.inputs;
    if (!hasNumber(p,"planning_speed_kn")) arrayAppend(total.missing_inputs,"planning speed in knots");
    else total.known_run_hours=total.known_distance_nm/p.planning_speed_kn;
    if (!hasNumber(p,"underway_burn_us_gph")) arrayAppend(total.missing_inputs,"underway consumption in US gal/h");
    if (!structKeyExists(p,"performance_confirmed") OR !p.performance_confirmed) arrayAppend(total.missing_inputs,"confirmation of planning units and performance");
    if (isNumeric(total.known_run_hours) AND hasNumber(p,"underway_burn_us_gph")) {
      total.known_cruise_fuel_us_gal=total.known_run_hours*p.underway_burn_us_gph;
      total.base_fuel_us_gal=total.known_cruise_fuel_us_gal+p.idle_burn_us_gph*p.idle_hours_total;
      total.reserve_fuel_us_gal=reserveForBase(total.base_fuel_us_gal,p.reserve_mode,p.reserve_pct);
      total.required_fuel_us_gal=total.base_fuel_us_gal+total.reserve_fuel_us_gal;
    }
    total.complete=!arrayLen(total.missing_inputs);
    if (total.complete AND hasNumber(p,"usable_fuel_us_gal") AND isNumeric(total.required_fuel_us_gal))
      total.usable_above_requirement_us_gal=p.usable_fuel_us_gal-total.required_fuel_us_gal;
    total["estimate_label"]=total.complete ? "Planning estimates" : "Incomplete estimate";
    return total;
  }

  // Same reserve semantics as FPW.SharedFuelMath.reserveForBase: thirds adds 0.5 * base.
  public numeric function reserveForBase(required numeric base,required string mode,required numeric pct) {
    return arguments.mode EQ "thirds" ? arguments.base*0.5 : arguments.base*arguments.pct/100;
  }

  public struct function buildPreview(required numeric userId,required numeric routeId) {
    var draft=getDraft(arguments.userId,arguments.routeId);
    if (!draft.totals.complete) fail("INCOMPLETE","Save this as a planning draft until all calculation inputs are present.");
    var p=draft.planning_inputs; var t=draft.totals; var inputs=legacyInputs(draft);
    var legs=[];
    for (var item in draft.legs) {
      var leg=duplicate(item);
      leg["route_leg_id"]=item.user_route_leg_id; leg["leg_order"]=item.order_index;
      leg["dist_nm"]=item.distance_nm; leg["lock_count"]=0; leg["segment_id"]=0; leg["is_offshore"]=true; leg["is_icw"]=false;
      leg["notes"]="Planning estimate; " & item.distance_kind;
      arrayAppend(legs,leg);
    }
    var totals={};
    totals["total_nm"]=t.known_distance_nm; totals["run_hours"]=t.known_run_hours; totals["total_run_hours"]=t.known_run_hours;
    totals["idle_hours"]=p.idle_hours_total; totals["total_hours"]=t.known_run_hours+p.idle_hours_total;
    totals["estimated_days"]=ceiling(totals.total_hours/p.underway_hours_per_day); totals["days_by_time"]=totals.estimated_days;
    totals["lock_count"]=0; totals["offshore_leg_count"]=arrayLen(legs); totals["max_speed_kn"]=p.planning_speed_kn;
    totals["effective_cruising_speed"]=p.planning_speed_kn; totals["weather_adjusted_speed_kn"]=p.planning_speed_kn;
    totals["underway_hours_per_day"]=p.underway_hours_per_day;
    totals["cruise_fuel_gallons"]=t.known_cruise_fuel_us_gal; totals["base_fuel_gallons"]=t.base_fuel_us_gal;
    totals["idle_fuel_gallons"]=p.idle_burn_us_gph*p.idle_hours_total;
    totals["reserve_pct"]=p.reserve_pct; totals["reserve_mode"]=p.reserve_mode;
    totals["reserve_fuel_gallons"]=t.reserve_fuel_us_gal; totals["required_fuel_gallons"]=t.required_fuel_us_gal;
    totals["estimated_fuel_gallons"]=t.required_fuel_us_gal; totals["fuel_price_per_gal"]=0; totals["fuel_cost_estimate"]=0;
    var data={};
    data["route"]={route_id=arguments.routeId,route_name=draft.route_name,is_active=1};
    data["template"]={id=0,code="MY_ROUTE",name=draft.route_name,description="Editable guide planning estimates",is_loop=false};
    data["inputs"]=inputs; data["legs"]=legs; data["totals"]=totals; data["optional_stops"]=[];
    data["GUIDE_CONTEXT"]=draft;
    data["summary_meta"]={effective_speed_kn=p.planning_speed_kn,speed_source="guide_explicit",fuel_source="guide_explicit",burn_model="explicit_constant",most_efficient_speed_kn=p.planning_speed_kn,most_efficient_burn_gph=p.underway_burn_us_gph,pace_ratio=1};
    return {SUCCESS=true,AUTH=true,MESSAGE="Planning estimates",DATA=data};
  }

  public struct function legacyInputs(required struct draft) {
    var d=arguments.draft; var p=d.planning_inputs; var out={};
    out["route_type"]="my_route"; out["route_id"]=d.user_route_id; out["route_name"]=d.route_name;
    out["template_code"]="MY_ROUTE"; out["route_code"]=""; out["direction"]="CCW";
    out["start_segment_id"]=""; out["end_segment_id"]=""; out["start_date"]=p.start_date;
    out["pace"]="BALANCED"; out["cruising_speed"]=p.planning_speed_kn; out["effective_cruising_speed"]=p.planning_speed_kn;
    out["vessel_max_speed_kn"]=p.planning_speed_kn; out["vessel_most_efficient_speed_kn"]=p.planning_speed_kn;
    out["vessel_gph_at_most_efficient_speed"]=p.underway_burn_us_gph;
    out["fuel_burn_gph"]=p.underway_burn_us_gph; out["fuel_burn_gph_input"]=p.underway_burn_us_gph; out["fuel_burn_basis"]="MOST_EFFICIENT";
    out["underway_hours_per_day"]=p.underway_hours_per_day; out["idle_burn_gph"]=p.idle_burn_us_gph; out["idle_hours_total"]=p.idle_hours_total;
    out["reserve_mode"]=p.reserve_mode; out["reserve_pct"]=p.reserve_pct; out["weather_factor_pct"]=0;
    out["comfort_profile"]="PREFER_INSIDE"; out["overnight_bias"]="MARINAS"; out["fuel_price_per_gal"]=0;
    out["selected_vessel_id"]=""; out["optional_stop_flags"]=[]; out["leg_override_drafts"]={};
    out["guide_context"]=snapshot(d);
    return out;
  }

  public struct function snapshot(required struct draft) {
    var d=arguments.draft; var out={};
    out["guide_import_id"]=d.guide_import_id; out["source_user_route_id"]=d.user_route_id;
    out["template_key"]=d.template_key; out["template_version"]=d.template_version; out["draft_revision"]=d.revision;
    out["planning_inputs"]=duplicate(d.planning_inputs); out["trip_notes"]=d.trip_notes; out["legs"]=duplicate(d.legs);
    out["totals"]=duplicate(d.totals); out["estimate_label"]="Planning estimates; member review is not independent navigation verification.";
    out["canonical_url"]=structKeyExists(d.source_snapshot,"canonical_url") ? d.source_snapshot.canonical_url : "";
    out["source_snapshot"]=d.source_snapshot;
    out["sources"]=structKeyExists(d.source_snapshot,"sources") ? d.source_snapshot.sources : [];
    return out;
  }

  public struct function getSnapshotForInstance(required numeric routeInstanceId) {
    var raw=rawSnapshot(arguments.routeInstanceId);
    if (structIsEmpty(raw)) return {};
    var safe=duplicate(raw);
    structDelete(safe,"guide_import_id");
    structDelete(safe,"source_user_route_id");
    for (var leg in safe.legs) { structDelete(leg,"reviewed_by_user_id"); structDelete(leg,"review_fingerprint"); }
    return safe;
  }

  public struct function getInstanceContext(required numeric userId,required numeric routeInstanceId) {
    var q=db("SELECT id FROM route_instances WHERE id=:id AND user_id=:uid",
      {id=intParam(arguments.routeInstanceId),uid=strParam(toString(arguments.userId))});
    if (!q.recordCount) return {};
    return rawSnapshot(arguments.routeInstanceId);
  }

  public struct function validateReadiness(required numeric userId,required numeric routeInstanceId) {
    var q=db("SELECT id FROM route_instances WHERE id=:id AND user_id=:uid",
      {id=intParam(arguments.routeInstanceId),uid=strParam(toString(arguments.userId))});
    if (!q.recordCount) return {allowed=false,code="GUIDE_OWNER_REQUIRED",message="The selected trip is not owned by this account.",guide_context={}};
    var context=rawSnapshot(arguments.routeInstanceId);
    if (structIsEmpty(context)) {
      if (isInstalled() AND db("SELECT id FROM guide_route_imports WHERE generated_route_instance_id=:id",{id=intParam(arguments.routeInstanceId)}).recordCount)
        return {allowed=false,code="GUIDE_CONTEXT_MISSING",message="This guide trip's mileage record is missing. Reopen its planning draft.",guide_context={}};
      return {allowed=true,code="",message="",guide_context={}};
    }
    if (!isInstalled()) return {allowed=false,code="GUIDE_UNAVAILABLE",message="Guide trip review is temporarily unavailable.",guide_context={}};
    try {
      var draft=getDraft(arguments.userId,val(context.source_user_route_id));
      if (val(context.draft_revision) NEQ draft.revision OR draft.generated_revision NEQ draft.revision)
        return {allowed=false,code="GUIDE_DRAFT_CHANGED",message="This itinerary has a newer planning draft. Save the complete trip before creating a float plan.",guide_context=context};
      for (var pendingLeg in draft.legs) {
        if (hasNumber(pendingLeg,"distance_nm") AND !len(clean(pendingLeg,"distance_method",2000)))
          return {allowed=false,code="GUIDE_METHOD_REQUIRED",message="Record a source or calculation method and review every movement leg before continuing.",guide_context=context};
      }
      if (!draft.totals.complete OR !arrayLen(draft.legs))
        return {allowed=false,code="GUIDE_INCOMPLETE",message="Complete every leg's mileage and planning inputs first.",guide_context=context};
      if (arrayLen(context.legs) NEQ arrayLen(draft.legs))
        return {allowed=false,code="GUIDE_LEGS_CHANGED",message="The itinerary's legs changed. Save and review the updated trip.",guide_context=context};
      var normalized=db("SELECT leg_order,base_dist_nm,start_name,end_name,start_lat,start_lng,end_lat,end_lng FROM route_instance_legs WHERE route_instance_id=:id ORDER BY leg_order,id",{id=intParam(arguments.routeInstanceId)});
      if (normalized.recordCount NEQ arrayLen(context.legs))
        return {allowed=false,code="GUIDE_LEGS_CHANGED",message="The saved itinerary legs changed. Reopen and save the planning draft.",guide_context=context};
      for (var i=1;i LTE arrayLen(draft.legs);i++) {
        var leg=draft.legs[i]; var saved=context.legs[i];
        if (isNull(normalized.base_dist_nm[i]) OR abs(val(normalized.base_dist_nm[i])-val(saved.distance_nm)) GT 0.011
          OR compare(toString(normalized.start_name[i]),saved.start_name) NEQ 0 OR compare(toString(normalized.end_name[i]),saved.end_name) NEQ 0)
          return {allowed=false,code="GUIDE_LEGS_CHANGED",message="The saved itinerary mileage or endpoints changed. Review and save the planning draft.",guide_context=context};
        for (var coord in ["start_lat","start_lng","end_lat","end_lng"])
          if (isNull(normalized[coord][i]) OR abs(val(normalized[coord][i])-val(saved[coord])) GT 0.000001)
            return {allowed=false,code="GUIDE_LEGS_CHANGED",message="The saved itinerary coordinates changed. Review and save the planning draft.",guide_context=context};
        if (!hasNumber(leg,"distance_nm") OR !listFind("member_confirmed,member_replaced",leg.review_status)
          OR leg.review_fingerprint NEQ legFingerprint(leg)
          OR saved.leg_key NEQ leg.leg_key OR saved.content_fingerprint NEQ leg.content_fingerprint)
          return {allowed=false,code="GUIDE_REVIEW_REQUIRED",message="Review and confirm or replace the mileage for every movement leg before continuing. Member review does not independently verify a route.",guide_context=context};
      }
      return {allowed=true,code="",message="",guide_context=context};
    } catch (any missing) {
      return {allowed=false,code="GUIDE_REVIEW_UNAVAILABLE",message="This trip's mileage review could not be verified. Reopen its planning draft.",guide_context=context};
    }
  }

  public struct function findByGeneratedCode(required numeric userId,required string routeCode) {
    var q=db("SELECT id FROM route_instances WHERE generated_route_code=:c AND user_id=:uid ORDER BY id DESC LIMIT 1",
      {c=strParam(arguments.routeCode),uid=strParam(toString(arguments.userId))});
    if (!q.recordCount) return {};
    var context=rawSnapshot(val(q.id[1]));
    if (structIsEmpty(context)) return {};
    return getDraft(arguments.userId,val(context.source_user_route_id));
  }

  public struct function prepareSave(required numeric userId,required numeric routeId,required struct body) {
    var draft=getDraft(arguments.userId,arguments.routeId);
    var req=uuidValue(arguments.body,"save_request_id");
    var requestedRevision=number(arguments.body,"revision",0,1,2147483647);
    var q=db("SELECT user_route_id,request_history_json FROM guide_route_imports WHERE user_id=:uid AND (user_route_id=:rid OR JSON_CONTAINS_PATH(COALESCE(request_history_json,'{}'),'one',:p)) FOR UPDATE",
      {uid=intParam(arguments.userId),rid=intParam(arguments.routeId),p=strParam('$.saves."' & req & '"')});
    var payloadHash=lCase(hash(serializeJSON(snapshot(draft)),"SHA-256"));
    for (var row in q) {
      var history=parseObject(isNull(row.request_history_json) ? "" : toString(row.request_history_json));
      if (structKeyExists(history,"saves") AND structKeyExists(history.saves,req)) {
        var prior=history.saves[req];
        if (val(row.user_route_id) NEQ arguments.routeId OR val(prior.revision) NEQ requestedRevision)
          fail("REQUEST_CONFLICT","This save request was already used with different trip details.");
        // Revision identifies immutable submitted content. A late retry returns that existing result, even after later saves.
        return {draft=draft,request_id=req,payload_hash=prior.payload_hash,reused=true,result=prior.result};
      }
    }
    if (requestedRevision NEQ draft.revision) fail("REVISION_CONFLICT","This draft changed. Reload it before saving the trip.");
    if (len(draft.route_name) GT 160) fail("NAME_TOO_LONG","Use a trip name of 160 characters or fewer before saving the complete trip.");
    if (!draft.totals.complete) fail("INCOMPLETE","Save this as a planning draft until mileage and performance inputs are complete.");
    if (!len(draft.planning_inputs.start_date)) fail("DATE_REQUIRED","Choose a start date before saving the trip.");
    return {draft=draft,request_id=req,payload_hash=payloadHash,reused=false};
  }

  // Copy only member geometry from the owned draft; retain explicit planning mileage separately.
  public void function copyGeometryToInstance(required numeric userId,required numeric routeId,required numeric generatedRouteId,required numeric routeInstanceId) {
    var owned=db("SELECT id FROM route_instances WHERE id=:id AND generated_route_id=:gr AND user_id=:uid",
      {id=intParam(arguments.routeInstanceId),gr=intParam(arguments.generatedRouteId),uid=strParam(toString(arguments.userId))});
    if (!owned.recordCount) fail("OWNER_REQUIRED","The saved trip is not owned by this account.");
    var draft=getDraft(arguments.userId,arguments.routeId);
    // The legacy generator binds numeric mileage without scale. Keep guide estimates at the schema's two-decimal precision.
    for (var leg in draft.legs) {
      db("UPDATE route_instance_legs SET base_dist_nm=:nm WHERE route_instance_id=:ri AND leg_order=:ord",
        {nm={value=leg.distance_nm,cfsqltype="cf_sql_decimal",scale=2},ri=intParam(arguments.routeInstanceId),ord=intParam(leg.order_index)});
    }
    db("UPDATE loop_routes SET total_nm=:nm WHERE id=:gr",
      {nm={value=draft.totals.known_distance_nm,cfsqltype="cf_sql_decimal",scale=2},gr=intParam(arguments.generatedRouteId)});
    var geometry=db("SELECT n.id AS target_leg_id,n.leg_order,o.geometry_json,o.computed_nm FROM route_instance_legs n INNER JOIN user_route_legs l ON l.user_route_id=:rid AND l.order_index=n.leg_order INNER JOIN route_leg_user_overrides o ON o.user_id=:uid AND o.route_id=l.user_route_id AND o.route_leg_id=l.id WHERE n.route_instance_id=:ri",
      {rid=intParam(arguments.routeId),uid=intParam(arguments.userId),ri=intParam(arguments.routeInstanceId)});
    db("DELETE o FROM route_leg_user_overrides o INNER JOIN route_instance_legs n ON n.id=o.route_leg_id AND n.route_instance_id=:ri WHERE o.user_id=:uid AND o.route_id=:gr",
      {ri=intParam(arguments.routeInstanceId),uid=intParam(arguments.userId),gr=intParam(arguments.generatedRouteId)});
    for (var i=1;i LTE geometry.recordCount;i++) {
      db("INSERT INTO route_leg_user_overrides (user_id,route_id,route_leg_id,route_leg_order,segment_id,geometry_json,computed_nm,override_fields_json) VALUES (:uid,:gr,:leg,:ord,NULL,:geo,:nm,:meta) ON DUPLICATE KEY UPDATE route_id=VALUES(route_id),route_leg_order=VALUES(route_leg_order),geometry_json=VALUES(geometry_json),computed_nm=VALUES(computed_nm),override_fields_json=VALUES(override_fields_json),updated_at=NOW()",
        {uid=intParam(arguments.userId),gr=intParam(arguments.generatedRouteId),leg=intParam(geometry.target_leg_id[i]),ord=intParam(geometry.leg_order[i]),
         geo=textParam(geometry.geometry_json[i]),nm={value=geometry.computed_nm[i],cfsqltype="cf_sql_decimal",scale=2},
         meta=textParam('{"geometry_kind":"member_plotted","navigation_verified":false}')});
    }
  }

  public void function finishSave(required numeric userId,required numeric routeId,required struct prepared,required numeric generatedRouteId,required numeric routeInstanceId) {
    var q=db("SELECT request_history_json FROM guide_route_imports WHERE user_id=:uid AND user_route_id=:rid FOR UPDATE",
      {uid=intParam(arguments.userId),rid=intParam(arguments.routeId)});
    var history=parseObject(isNull(q.request_history_json[1]) ? "" : toString(q.request_history_json[1]));
    if (!structKeyExists(history,"saves")) history["saves"]={};
    history.saves[arguments.prepared.request_id]={revision=arguments.prepared.draft.revision,payload_hash=arguments.prepared.payload_hash,
      result={route_id=arguments.generatedRouteId,route_instance_id=arguments.routeInstanceId}};
    db("UPDATE guide_route_imports SET request_history_json=:h WHERE user_id=:uid AND user_route_id=:rid",
      {h=textParam(serializeJSON(history)),uid=intParam(arguments.userId),rid=intParam(arguments.routeId)});
    db("UPDATE guide_route_imports SET generated_route_id=:gr,generated_route_instance_id=:ri,generated_revision=draft_revision,save_request_id=:req,save_payload_hash=:h,updated_at=UTC_TIMESTAMP() WHERE user_id=:uid AND user_route_id=:rid",
      {gr=intParam(arguments.generatedRouteId),ri=intParam(arguments.routeInstanceId),req=strParam(arguments.prepared.request_id),h=strParam(arguments.prepared.payload_hash),uid=intParam(arguments.userId),rid=intParam(arguments.routeId)});
  }

  public void function markDeleted(required numeric userId,required numeric routeId) {
    if (!isInstalled()) return;
    db("UPDATE guide_route_imports SET deleted_at=UTC_TIMESTAMP(),updated_at=UTC_TIMESTAMP() WHERE user_id=:uid AND user_route_id=:rid AND deleted_at IS NULL",
      {uid=intParam(arguments.userId),rid=intParam(arguments.routeId)});
  }

  public string function serializeResponse(required struct response) {
    var json=serializeJSON(arguments.response);
    // Null support is disabled in older FPW CF runtimes; missing numeric values remain explicit on the wire.
    return reReplaceNoCase(json,'("(distance_nm|dist_nm|dist_nm_default|known_run_hours|known_cruise_fuel_us_gal|base_fuel_us_gal|reserve_fuel_us_gal|required_fuel_us_gal|usable_above_requirement_us_gal|planning_speed_kn|underway_burn_us_gph|usable_fuel_us_gal)"\s*:)""','\1null',"all");
  }

  private struct function rawSnapshot(required numeric routeInstanceId) {
    var q=db("SELECT routegen_inputs_json FROM route_instances WHERE id=:id LIMIT 1",{id=intParam(arguments.routeInstanceId)});
    if (!q.recordCount OR isNull(q.routegen_inputs_json[1]) OR !len(q.routegen_inputs_json[1])) return {};
    var input=parseObject(q.routegen_inputs_json[1]);
    if (!structKeyExists(input,"guide_context") OR !isStruct(input.guide_context)) return {};
    return input.guide_context;
  }
  private struct function normalizeInputs(required struct source) {
    var p={};
    p["planning_speed_kn"]=optionalNumber(arguments.source,"planning_speed_kn",0.5,60);
    p["underway_burn_us_gph"]=optionalNumber(arguments.source,"underway_burn_us_gph",0.01,1000);
    p["underway_hours_per_day"]=number(arguments.source,"underway_hours_per_day",6.5,1,24);
    p["reserve_mode"]=clean(arguments.source,"reserve_mode",20);
    if (!len(p.reserve_mode)) p.reserve_mode="percentage";
    if (!listFind("percentage,thirds",p.reserve_mode)) fail("INPUT_INVALID","Choose percentage or thirds reserve.");
    p["reserve_pct"]=number(arguments.source,"reserve_pct",20,0,100);
    p["idle_burn_us_gph"]=number(arguments.source,"idle_burn_us_gph",0,0,1000);
    p["idle_hours_total"]=number(arguments.source,"idle_hours_total",0,0,10000);
    p["usable_fuel_us_gal"]=optionalNumber(arguments.source,"usable_fuel_us_gal",0,1000000);
    p["performance_confirmed"]=structKeyExists(arguments.source,"performance_confirmed") AND isBoolean(arguments.source.performance_confirmed) AND arguments.source.performance_confirmed;
    p["start_date"]=clean(arguments.source,"start_date",10);
    if (len(p.start_date) AND (!reFind("^[0-9]{4}-[0-9]{2}-[0-9]{2}$",p.start_date) OR !isDate(p.start_date)))
      fail("INPUT_INVALID","Enter a valid start date.");
    return p;
  }
  private struct function newLegState(required string key) {
    var out={}; out["leg_key"]=arguments.key; out["distance_nm"]=""; out["distance_kind"]="missing";
    out["distance_method"]="Enter a planning distance and its source or calculation method."; out["source_ids"]=[];
    out["geometry_kind"]="schematic"; out["geometry_fingerprint"]=""; clearReview(out); return out;
  }
  private void function clearReview(required struct leg) {
    arguments.leg["review_status"]="unreviewed"; arguments.leg["reviewed_at"]="";
    arguments.leg["review_fingerprint"]=""; structDelete(arguments.leg,"reviewed_by_user_id");
  }
  private string function endpointFingerprint(required struct leg) {
    var v=[]; for (var key in ["start_waypoint_id","end_waypoint_id","start_name","end_name","start_lat","start_lng","end_lat","end_lng"])
      arrayAppend(v,structKeyExists(arguments.leg,key) ? toString(arguments.leg[key]) : "");
    return lCase(hash(arrayToList(v,"|"),"SHA-256"));
  }
  public string function legFingerprint(required struct leg) {
    var v=[endpointFingerprint(arguments.leg)];
    for (var key in ["distance_nm","distance_kind","distance_method","geometry_kind","geometry_fingerprint"])
      arrayAppend(v,structKeyExists(arguments.leg,key) AND !isNull(arguments.leg[key]) ? toString(arguments.leg[key]) : "");
    arrayAppend(v,structKeyExists(arguments.leg,"source_ids") ? serializeJSON(arguments.leg.source_ids) : "[]");
    if (structKeyExists(arguments.leg,"source_dates") AND len(serializeJSON(arguments.leg.source_dates)) GT 2)
      arrayAppend(v,serializeJSON(arguments.leg.source_dates));
    return lCase(hash(serializeJSON(v),"SHA-256"));
  }
  private void function persistLegState(required numeric userId,required numeric routeId,required array legs) {
    var state={}; for (var leg in arguments.legs) state[toString(leg.user_route_leg_id)]=duplicate(leg);
    db("UPDATE guide_route_imports SET leg_state_json=:j WHERE user_id=:uid AND user_route_id=:rid",
      {j=textParam(serializeJSON(state)),uid=intParam(arguments.userId),rid=intParam(arguments.routeId)});
  }
  private void function requireInstalled() { if (!isInstalled()) fail("UNAVAILABLE","Guide planning is not available yet. Return to the guide and try again later."); }
  public void function lockOwner(required numeric userId) {
    var q=db("SELECT userId FROM users WHERE userId=:uid FOR UPDATE",{uid=intParam(arguments.userId)});
    if (!q.recordCount) fail("OWNER_REQUIRED","A valid member account is required.");
  }
  private boolean function coordinate(required struct s,required string key,required numeric maximum) {
    return hasNumber(arguments.s,arguments.key) AND abs(val(arguments.s[arguments.key])) LTE arguments.maximum;
  }
  private boolean function hasNumber(required struct s,required string key) {
    return structKeyExists(arguments.s,arguments.key) AND !isNull(arguments.s[arguments.key]) AND isSimpleValue(arguments.s[arguments.key])
      AND len(trim(toString(arguments.s[arguments.key]))) AND isNumeric(arguments.s[arguments.key]);
  }
  private any function optionalNumber(required struct s,required string key,required numeric minimum,required numeric maximum) {
    if (!structKeyExists(arguments.s,arguments.key) OR isNull(arguments.s[arguments.key]) OR (isSimpleValue(arguments.s[arguments.key]) AND !len(trim(toString(arguments.s[arguments.key]))))) return "";
    if (!hasNumber(arguments.s,arguments.key) OR val(arguments.s[arguments.key]) LT arguments.minimum OR val(arguments.s[arguments.key]) GT arguments.maximum)
      fail("INPUT_INVALID","Invalid " & arguments.key & ". Enter a number in the displayed units.");
    return val(arguments.s[arguments.key]);
  }
  private numeric function number(required struct s,required string key,required numeric defaultValue,required numeric minimum,required numeric maximum) {
    var v=optionalNumber(arguments.s,arguments.key,arguments.minimum,arguments.maximum);
    return isNumeric(v) ? v : arguments.defaultValue;
  }
  private string function clean(required struct s,required string key,required numeric maximum) {
    if (!structKeyExists(arguments.s,arguments.key) OR isNull(arguments.s[arguments.key])) return "";
    if (!isSimpleValue(arguments.s[arguments.key])) fail("INPUT_INVALID","Invalid text field " & arguments.key & ".");
    var v=trim(toString(arguments.s[arguments.key]));
    if (len(v) GT arguments.maximum) fail("INPUT_INVALID","The " & arguments.key & " field is too long.");
    return v;
  }
  private string function uuidValue(required struct s,required string key) {
    var v=lCase(clean(arguments.s,arguments.key,36));
    if (!reFind("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$",v)) fail("REQUEST_REQUIRED","A valid request identifier is required. Reload and try again.");
    return v;
  }
  private string function canonicalValue(required any value) {
    if (isStruct(arguments.value)) {
      var keys=structKeyArray(arguments.value); arraySort(keys,"textnocase");
      var parts=[]; for (var key in keys) arrayAppend(parts,serializeJSON(lCase(key)) & ":" & (isNull(arguments.value[key]) ? "null" : canonicalValue(arguments.value[key])));
      return "{" & arrayToList(parts,",") & "}";
    }
    if (isArray(arguments.value)) {
      var parts=[]; for (var i=1;i LTE arrayLen(arguments.value);i++) arrayAppend(parts,isNull(arguments.value[i]) ? "null" : canonicalValue(arguments.value[i]));
      return "[" & arrayToList(parts,",") & "]";
    }
    return serializeJSON(arguments.value);
  }
  private struct function parseObject(required string value) {
    if (!len(trim(arguments.value))) return {};
    try { var v=deserializeJSON(arguments.value); if (isStruct(v)) return v; } catch (any ignored) {}
    fail("STATE_INVALID","This guide's saved state could not be read."); return {};
  }
  private any function db(required string sql,struct params={}) { return queryExecute(arguments.sql,arguments.params,{datasource=variables.dsn}); }
  private numeric function insertRow(required string sql,required struct params) {
    var result={}; queryExecute(arguments.sql,arguments.params,{datasource=variables.dsn,result="local.result"}); return val(result.generatedKey);
  }
  private struct function intParam(required numeric value) { return {value=arguments.value,cfsqltype="cf_sql_integer"}; }
  private struct function strParam(required string value) { return {value=arguments.value,cfsqltype="cf_sql_varchar"}; }
  private struct function textParam(required string value) { return {value=arguments.value,cfsqltype="cf_sql_longvarchar"}; }
  private void function fail(required string code,required string message) { throw(type="FPW.Guide." & arguments.code,message=arguments.message); }
}
