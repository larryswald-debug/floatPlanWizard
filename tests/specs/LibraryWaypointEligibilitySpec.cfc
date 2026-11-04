component extends="testbox.system.BaseSpec" output="false" {
    function run() {
        describe("Great Loop member waypoint location eligibility", function() {
            beforeEach(function() {
                variables.service = new fpw.api.v1.LibraryWaypointService();
                variables.bridge = {bridge_id="B-1", bridge_name="Example Bridge", bridge_type="Fixed",
                    verification_status="verified", public_status="published", latitude=42.5, longitude=-83.4};
                variables.anchorage = {anchorage_id="A-1", anchorage_name="Example Cove", anchorage_type="cove",
                    public_status="public-charted-water", verification_status="needs_chart_review", latitude=42.5, longitude=-83.4};
            });

            it("preserves a named point bridge and source ID", function() {
                var point = service.describe("bridge", bridge);
                expect(point.eligible).toBeTrue();
                expect(point.waypoint.WAYPOINTNAME).toBe("Example Bridge");
                expect(point.waypoint.NOTES).toInclude("[B-1]");
                expect(point.waypoint.LONGITUDE).toBe("-83.4");
            });

            it("rejects missing, zero, malformed and out-of-range coordinate pairs", function() {
                for (var lat in ["", "north", "0", "-90.0001", "91", "NaN"]) {
                    bridge.latitude=lat; expect(service.describe("bridge",bridge).eligible).toBeFalse();
                }
                bridge.latitude=-90; bridge.longitude=180; expect(service.describe("bridge",bridge).eligible).toBeTrue();
                for (var lng in ["", "west", "0", "180.00001", "-181"]) {
                    bridge.longitude=lng; expect(service.describe("bridge",bridge).eligible).toBeFalse();
                }
                structDelete(bridge,"longitude");
                expect(service.describe("bridge",bridge).eligible).toBeFalse();
            });

            it("accepts a bridge with pending review or approximate coordinate evidence", function() {
                bridge.verification_status="needs_coordinate_review";
                bridge.coordinate_review_status="pending";
                bridge.coordinate_confidence="low";
                bridge.coordinate_source_type="estimated";
                bridge.coordinate_notes="Representative map pin";
                expect(service.describe("bridge",bridge).eligible).toBeTrue();
            });

            it("allows a stored regional bridge point for a system, multiple structures or a named group", function() {
                bridge.mile_marker="System-wide";
                expect(service.describe("bridge",bridge).eligible).toBeTrue();
                bridge.mile_marker=""; bridge.bridge_type="Multiple fixed bridges";
                expect(service.describe("bridge",bridge).eligible).toBeTrue();
                bridge.bridge_type="Fixed"; bridge.bridge_name="River Bridge Group";
                expect(service.describe("bridge",bridge).eligible).toBeTrue();
            });

            it("accepts an anchorage area with staging or coordinate-review notes", function() {
                anchorage.public_status="staging-reference";
                anchorage.verification_status="needs_coordinate_review";
                anchorage.anchorage_type="bay/pass area";
                anchorage.notes="Laguna Madre/South Padre staging area; verify the approach.";
                anchorage.nav_warning="Map position is estimated.";
                expect(service.describe("anchorage",anchorage).eligible).toBeTrue();
            });

            it("allows a lock with an approximate position note to be saved at its stored coordinates", function() {
                var lock={id=13, lock_name="Synthetic lock", latitude=37, longitude=-77,
                    note="Coordinates are approximate station locations."};
                var point=service.describe("lock",lock);
                expect(point.eligible).toBeTrue();
                expect(point.waypoint.LATITUDE).toBe("37");
                expect(point.waypoint.LONGITUDE).toBe("-77");
            });

            it("still requires a named library record with an identity", function() {
                anchorage.anchorage_name="";
                var missingName=service.describe("anchorage",anchorage);
                expect(missingName.eligible).toBeFalse();
                expect(missingName.message).toBe("This library record is unavailable.");
                structDelete(bridge,"bridge_id");
                expect(service.describe("bridge",bridge).eligible).toBeFalse();
            });

            it("retains the full lock name in notes beyond the existing waypoint name limit",function() {
                var name=repeatString("Long lock name ",5) & "West";
                var result=service.describe("lock",{id=123, lock_name=name, latitude=38, longitude=-75});
                expect(result.eligible).toBeTrue(); expect(result.waypoint.WAYPOINTNAME).toBe(left(name,45));
                expect(result.waypoint.NOTES).toInclude(name);
            });

            it("renders the real shared panel without a save action for missing or invalid coordinates",function() {
                include "../../includes/fpw_base_path.cfm";
                var fpwLibraryWaypointType="lock";
                var fpwLibraryWaypointRecord={id=13,slug="synthetic-lock",lock_name="Synthetic lock",longitude=-76};
                var panel="";
                for (var testLatitude in ["absent","","north","91"]) {
                    if (testLatitude == "absent") structDelete(fpwLibraryWaypointRecord,"latitude");
                    else fpwLibraryWaypointRecord.latitude=testLatitude;
                    savecontent variable="panel" { include "../../partials/fpw-library-waypoint.cfm"; }
                    expect(panel).toInclude("Latitude or longitude is missing or invalid for this record.");
                    expect(panel).notToInclude("data-library-waypoint-save");
                    expect(panel).notToInclude("library-waypoint.js");
                }
            });

            it("retains Ports notes and accepts stored coordinates independently of map readiness",function() {
                var port={id=8, name="Sample Port", lat=42.5, lng=-83.4, map_ready=true};
                expect(service.describe(" PoRt ",port).library).toBe("port");
                expect(service.describe("port",port).waypoint.NOTES).toBe("Added from Great Loop Ports Library: Sample Port");
                port.map_ready=false; expect(service.describe("port",port).eligible).toBeTrue();
            });
        });
    }
}
