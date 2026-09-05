component extends="testbox.system.BaseSpec" output="false" {
  function run() {
    describe("Required member activity", function() {
      it("compiles all instrumented components", function() {
        for (var name in ["fpw.includes.ProductEventService","fpw.api.v1.vessel","fpw.api.v1.contact","fpw.api.v1.operator","fpw.api.v1.passenger","fpw.api.v1.waypoint","fpw.api.v1.VesselImageService","fpw.api.v1.routeBuilder","fpw.api.v1.floatplan"]) {
          expect(isObject(createObject("component",name))).toBeTrue();
        }
      });
      it("rejects nonqualifying names and malformed identities", function() {
        var service = createObject("component","fpw.includes.ProductEventService").init("fpw");
        expect(function() {service.recordRequiredMemberActivity(1,"login",1);}).toThrow();
        expect(function() {service.recordRequiredMemberActivity(0,"vessel_updated",1);}).toThrow();
        expect(function() {service.recordRequiredMemberActivity(1,"vessel_updated",1.5);}).toThrow();
      });
      if (structKeyExists(request,"memberActivityFixtureUserId") AND request.memberActivityFixtureUserId GT 0) {
        describe("Canonical disposable account integration", function() {
          beforeEach(function() {
            variables.uid=request.memberActivityFixtureUserId;
            variables.vesselId=sql("SELECT vesselID FROM vessels WHERE userId=:uid ORDER BY vesselID LIMIT 1").vesselID[1];
          });
          it("uses the exact 17-name contract and fixed source, type and minimal metadata", function() {
            var service=new fpw.includes.ProductEventService().init("fpw");
            makePublic(service,"memberActivityTypes","typesForTest");
            var names=service.typesForTest();
            expect(structCount(names)).toBe(17);
            expect(names.route_created).toBe("route_instance");
            expect(names.user_route_created).toBe("user_route");
            expect(names.route_segment_updated).toBe("user_segment_override");
            var events=sql("SELECT event_name,entity_type,event_source,metadata_json FROM product_events WHERE user_id=:uid AND event_source='member_api'");
            expect(events.recordCount GT 0).toBeTrue();
            for (var row in events) {
              expect(structKeyExists(names,row.event_name)).toBeTrue();
              expect(row.entity_type).toBe(names[row.event_name]);
              var metadata=deserializeJSON(row.metadata_json);
              if (listFind("vessel_created,shore_contact_created",row.event_name)) {
                expect(structCount(metadata)).toBe(1);
                expect(metadata.creation_source).toBe("member");
              } else expect(structCount(metadata)).toBe(0);
            }
          });
          it("requires confirmed insertion and rolls back changes when recordEvent fails", function() {
            var service=prepareMock(new fpw.includes.ProductEventService().init("fpw"));
            service.$("recordEvent",{SUCCESS=false});
            var oldName=sql("SELECT vesselName FROM vessels WHERE vesselID=:vid").vesselName[1];
            expect(function() {
              transaction {
                sql("UPDATE vessels SET vesselName='rollback-only' WHERE vesselID=:vid AND userId=:uid");
                service.recordRequiredMemberActivity(variables.uid,"vessel_updated",variables.vesselId);
              }
            }).toThrow("FPW.MemberActivity.PersistenceFailed");
            expect(sql("SELECT vesselName FROM vessels WHERE vesselID=:vid").vesselName[1]).toBe(oldName);
          });
          it("uses database UTC bounds and filters a newer nonqualifying event from latest activity", function() {
            var names=new fpw.includes.ProductEventService().init("fpw");
            makePublic(names,"memberActivityTypes","typesForTest");
            var allowed=structKeyList(names.typesForTest());
            var utcBefore=sql("SELECT UTC_TIMESTAMP() AS at_utc").at_utc[1];
            var countBefore=eventCount();
            transaction {
              names.recordRequiredMemberActivity(variables.uid,"vessel_updated",variables.vesselId);
              var recorded=sql("SELECT occurred_at_utc FROM product_events WHERE user_id=:uid ORDER BY id DESC LIMIT 1").occurred_at_utc[1];
              var utcAfter=sql("SELECT UTC_TIMESTAMP() AS at_utc").at_utc[1];
              expect(dateCompare(recorded,utcBefore) GTE 0).toBeTrue();
              expect(dateCompare(recorded,utcAfter) LTE 0).toBeTrue();
              var login=names.recordEvent(variables.uid,"login","user",variables.uid,"password_auth",{auth_method="password"});
              expect(login.RECORDED).toBeTrue();
              // Controlled test-only timestamp distinguishes a newer nonqualifying row.
              sql("UPDATE product_events SET occurred_at_utc=DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 HOUR) WHERE user_id=:uid AND event_name='login'");
              var latest=queryExecute("SELECT MAX(occurred_at_utc) AS at_utc FROM product_events
                WHERE user_id=:uid AND event_source='member_api' AND event_name IN (:names)",
                {uid={value=variables.uid,cfsqltype="cf_sql_integer"},names={value=allowed,cfsqltype="cf_sql_varchar",list=true}},
                {datasource="fpw"}).at_utc[1];
              expect(dateCompare(latest,recorded)).toBe(0);
              transaction action="rollback";
            }
            expect(eventCount()).toBe(countBefore);
          });
          it("records real leg reorder/removal and named-route restoration but not no-ops", function() {
            var rb=new fpw.api.v1.routeBuilder();
            for (var name in ["createUserRoute","setUserRouteStartWaypoint","addWaypointLegToUserRoute","reorderUserRouteLegs","removeLegFromUserRoute","deleteUserRoute"])
              makePublic(rb,name,name & "ForTest");
            var wp=sql("SELECT wpId FROM waypoints WHERE userId=:uid ORDER BY wpId LIMIT 2");
            var routeName="Activity reorder " & createUUID();
            var created=rb.createUserRouteForTest(variables.uid,routeName);
            var rid=created.DATA.route_id;
            expect(rb.setUserRouteStartWaypointForTest(variables.uid,rid,wp.wpId[1]).SUCCESS).toBeTrue();
            expect(rb.addWaypointLegToUserRouteForTest(variables.uid,rid,wp.wpId[2]).SUCCESS).toBeTrue();
            expect(rb.addWaypointLegToUserRouteForTest(variables.uid,rid,wp.wpId[1]).SUCCESS).toBeTrue();
            var added=rb.addWaypointLegToUserRouteForTest(variables.uid,rid,wp.wpId[2]);
            expect(added.SUCCESS).toBeTrue();
            var ids=[added.DATA.legs[3].route_leg_id,added.DATA.legs[2].route_leg_id,added.DATA.legs[1].route_leg_id];
            var countBefore=eventCount();
            expect(rb.reorderUserRouteLegsForTest(variables.uid,rid,ids).SUCCESS).toBeTrue();
            expect(eventCount()).toBe(countBefore+1);
            expect(rb.reorderUserRouteLegsForTest(variables.uid,rid,ids).SUCCESS).toBeTrue();
            expect(eventCount()).toBe(countBefore+1);
            expect(rb.removeLegFromUserRouteForTest(variables.uid,rid,ids[3]).SUCCESS).toBeTrue();
            expect(eventCount()).toBe(countBefore+2);
            expect(rb.deleteUserRouteForTest(variables.uid,rid).SUCCESS).toBeTrue();
            expect(eventCount()).toBe(countBefore+2);
            expect(rb.createUserRouteForTest(variables.uid,routeName).SUCCESS).toBeTrue();
            expect(eventCount()).toBe(countBefore+3);
          });
          it("records canonical-segment legs and only one outer event for nested generated overrides", function() {
            var rb=new fpw.api.v1.routeBuilder();
            for (var name in ["createUserRoute","addLegToUserRoute","routegenReadInput","routegenGenerate","routegenSaveLegOverride","routegenClearLegOverride"])
              makePublic(rb,name,name & "ForTest");
            var segment=sql("SELECT id FROM segment_library ORDER BY id LIMIT 1").id[1];
            var route=rb.createUserRouteForTest(variables.uid,"Activity segment " & createUUID());
            var rid=route.DATA.route_id;
            var countBefore=eventCount();
            expect(rb.addLegToUserRouteForTest(variables.uid,rid,segment).SUCCESS).toBeTrue();
            expect(eventCount()).toBe(countBefore+1);
            var geometry=[{lat=38.98,lon=-76.48},{lat=39,lon=-76.4}];
            var drafts={};
            drafts[toString(segment)]={segment_id=segment,geometry=geometry,override_fields={}};
            var input=rb.routegenReadInputForTest({route_type="my_route",route_id=rid,route_name="Activity generated segment",
              selected_vessel_id=variables.vesselId,speed_kn=10,cruising_speed=10,start_date=dateFormat(dateAdd("d",1,now()),"yyyy-mm-dd"),
              leg_override_drafts=drafts});
            countBefore=eventCount();
            var generated=rb.routegenGenerateForTest(variables.uid,input);
            expect(generated.SUCCESS).toBeTrue();
            expect(eventCount()).toBe(countBefore+1);
            var leg=queryExecute("SELECT id,source_loop_segment_id FROM route_instance_legs WHERE route_instance_id=:rid ORDER BY leg_order LIMIT 1",
              {rid={value=generated.ROUTE_INSTANCE_ID,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
            var legId=val(leg.source_loop_segment_id[1]) GT 0 ? val(leg.source_loop_segment_id[1]) : val(leg.id[1]);
            var args={userId=variables.uid,routeCode=generated.ROUTE_CODE,routeLegId=legId,legOrder=1,segmentId=segment,
              geometryRaw=geometry,overrideFieldsRaw={},memberCommand=true};
            // A distinct direct command has its own evidence, unlike nested persistence.
            geometry[2].lat=39.01;
            expect(rb.routegenSaveLegOverrideForTest(argumentCollection=args).SUCCESS).toBeTrue();
            expect(eventCount()).toBe(countBefore+2);
            expect(rb.routegenSaveLegOverrideForTest(argumentCollection=args).SUCCESS).toBeTrue();
            expect(eventCount()).toBe(countBefore+2);
            expect(rb.routegenClearLegOverrideForTest(variables.uid,generated.ROUTE_CODE,legId).SUCCESS).toBeTrue();
            expect(eventCount()).toBe(countBefore+3);
            expect(rb.routegenClearLegOverrideForTest(variables.uid,generated.ROUTE_CODE,legId).SUCCESS).toBeTrue();
            expect(eventCount()).toBe(countBefore+3);
          });
          it("retains evidence after supported named-route archival", function() {
            var rb=new fpw.api.v1.routeBuilder();
            makePublic(rb,"createUserRoute","createForTest");
            makePublic(rb,"deleteUserRoute","deleteForTest");
            var name="Activity retention " & createUUID();
            var created=rb.createForTest(variables.uid,name);
            expect(created.SUCCESS).toBeTrue();
            var removed=rb.deleteForTest(variables.uid,created.DATA.route_id);
            expect(removed.SUCCESS).toBeTrue();
            var evidence=queryExecute("SELECT id FROM product_events WHERE user_id=:uid AND event_name='user_route_created' AND entity_id=:rid",
              {uid={value=variables.uid,cfsqltype="cf_sql_integer"},rid={value=created.DATA.route_id,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
            expect(evidence.recordCount).toBe(1);
          });
          it("atomically saves, deduplicates, replaces and removes member photos", function() {
            var service=new fpw.api.v1.VesselImageService().init("fpw");
            var firstPath=imageFixture("red");
            var secondPath=imageFixture("blue");
            try {
              service.removeVesselImage(variables.vesselId,variables.uid,false);
              var countBefore=eventCount();
              var first=service.saveUploadedVesselImage(variables.vesselId,variables.uid,firstPath,"first.png","",true);
              expect(first.SUCCESS).toBeTrue();
              expect(eventCount()).toBe(countBefore+1);
              var firstStored=imageRow();
              var duplicate=service.saveUploadedVesselImage(variables.vesselId,variables.uid,firstPath,"renamed.png","",true);
              expect(duplicate.SUCCESS).toBeTrue();
              expect(eventCount()).toBe(countBefore+1);
              expect(imageRow().local_image_path[1]).toBe(firstStored.local_image_path[1]);
              var second=service.saveUploadedVesselImage(variables.vesselId,variables.uid,secondPath,"second.png","",true);
              expect(second.SUCCESS).toBeTrue();
              expect(eventCount()).toBe(countBefore+2);
              expect(fileExists(expandPath("/fpw/" & firstStored.local_image_path[1]))).toBeFalse();
              expect(service.removeVesselImage(variables.vesselId,variables.uid,true).SUCCESS).toBeTrue();
              expect(eventCount()).toBe(countBefore+3);
              expect(service.removeVesselImage(variables.vesselId,variables.uid,true).SUCCESS).toBeTrue();
              expect(eventCount()).toBe(countBefore+3);
            } finally {
              service.removeVesselImage(variables.vesselId,variables.uid,false);
              fileDelete(firstPath); fileDelete(secondPath);
            }
          });
          it("preserves photo metadata and files on failures before and after event insertion", function() {
            var normal=new fpw.api.v1.VesselImageService().init("fpw");
            var firstPath=imageFixture("green");
            var secondPath=imageFixture("yellow");
            try {
              expect(normal.saveUploadedVesselImage(variables.vesselId,variables.uid,firstPath,"first.png","",true).SUCCESS).toBeTrue();
              var stored=imageRow();
              var directory=getDirectoryFromPath(expandPath("/fpw/" & stored.local_image_path[1]));
              var fileCount=arrayLen(directoryList(directory,false,"path"));
              var countBefore=eventCount();
              for (var mode in ["before","after"]) {
                var failing=prepareMock(new fpw.api.v1.VesselImageService().init("fpw"));
                failing.$("getMemberActivityEventService",createObject("component","fpw.tests.support.MemberActivityFailureStub").init(mode));
                expect(failing.saveUploadedVesselImage(variables.vesselId,variables.uid,secondPath,"second.png","",true).SUCCESS).toBeFalse();
                expect(imageRow().local_image_path[1]).toBe(stored.local_image_path[1]);
                expect(arrayLen(directoryList(directory,false,"path"))).toBe(fileCount);
                expect(fileExists(expandPath("/fpw/" & stored.local_image_path[1]))).toBeTrue();
                expect(eventCount()).toBe(countBefore);
                expect(failing.removeVesselImage(variables.vesselId,variables.uid,true).SUCCESS).toBeFalse();
                expect(imageRow().local_image_path[1]).toBe(stored.local_image_path[1]);
                expect(eventCount()).toBe(countBefore);
              }
            } finally {
              normal.removeVesselImage(variables.vesselId,variables.uid,false);
              fileDelete(firstPath); fileDelete(secondPath);
            }
          });
          it("does not emit photo evidence without explicit internal member-command context", function() {
            var service=new fpw.api.v1.VesselImageService().init("fpw");
            var path=imageFixture("magenta");
            var countBefore=eventCount();
            try {
              expect(service.saveUploadedVesselImage(variables.vesselId,variables.uid,path,"system.png").SUCCESS).toBeTrue();
              expect(service.removeVesselImage(variables.vesselId,variables.uid).SUCCESS).toBeTrue();
              expect(eventCount()).toBe(countBefore);
            } finally {fileDelete(path);}
          });
        });
      }
    });
  }
  private any function sql(required string statement) {
    return queryExecute(arguments.statement,{uid={value=variables.uid,cfsqltype="cf_sql_integer"},vid={value=variables.vesselId ?: 0,cfsqltype="cf_sql_integer"}},{datasource="fpw"});
  }
  private numeric function eventCount() {return sql("SELECT COUNT(*) AS n FROM product_events WHERE user_id=:uid AND event_source='member_api'").n[1];}
  private query function imageRow() {return sql("SELECT local_image_path,thumbnail_image_path FROM vessel_images WHERE vessel_id=:vid");}
  private string function imageFixture(required string color) {
    var path=getTempDirectory() & "fpw-activity-" & createUUID() & ".png";
    imageWrite(imageNew("",8,8,"rgb",arguments.color),path);
    return path;
  }
}
