component output=false hint="Resolves published library locations for the existing member waypoint save." {
    public struct function resolve(required struct input) {
        var library = lCase(field(input, "library"));
        var slug = field(input, "slug");
        var result = {};
        switch (library) {
            case "port":
                var portId = field(input, "portId");
                if (!reFind("^[1-9][0-9]{0,9}$", portId) || val(portId) > 2147483647) return unavailable();
                result = new fpw.api.v1.PortsLibraryService().getPortById(portId);
                break;
            case "anchorage":
            case "bridge":
            case "lock":
                if (!len(slug) || len(slug) > 255) return unavailable();
                if (library == "anchorage") result = new fpw.api.v1.GreatLoopAnchoragesService().getAnchorageBySlug(slug);
                if (library == "bridge") result = new fpw.api.v1.GreatLoopBridgesService().getBridgeBySlug(slug);
                if (library == "lock") result = new fpw.api.v1.GreatLoopLocksService().getLockBySlug(slug);
                break;
            default:
                return unavailable();
        }
        if (!result.success || !structKeyExists(result, library)) return unavailable();
        var location = describe(library, result[library]);
        if (len(field(input,"recordId")) && field(input,"recordId") != location.recordId) return unavailable();
        return location;
    }

    public boolean function isBridgeArea(required struct record) {
        return reFindNoCase("system[ _-]?wide|waterway[ _-]?wide|bridge group", field(record, "mile_marker") & " " & field(record, "bridge_name")) > 0
            || reFindNoCase("^multiple[ _-]|bridge group", field(record, "bridge_type")) > 0;
    }

    public struct function describe(required string library, required struct record) {
        arguments.library = lCase(trim(arguments.library));
        var r = arguments.record;
        var labels = {port="Ports", anchorage="Anchorages", bridge="Bridges", lock="Locks"};
        var out = unavailable();
        if (!structKeyExists(labels, library)) return out;
        out.library = library;
        out.recordId = field(r, library == "port" || library == "lock" ? "id" : library & "_id");
        var name = field(r, library == "port" ? "name" : library & "_name");
        var lat = field(r, library == "port" ? "lat" : "latitude");
        var lng = field(r, library == "port" ? "lng" : "longitude");
        if (!len(name) || !len(out.recordId)) return out;
        if (!isNumeric(lat) || !isNumeric(lng) || lat == 0 || lng == 0 || abs(lat) > 90 || abs(lng) > 180) {
            out.message = "Latitude or longitude is missing or invalid for this record.";
            return out;
        }
        out.eligible = true;
        out.message = library == "bridge" && isBridgeArea(r)
            ? "This record covers multiple locations. Its map is for regional planning only." : "";
        out.prefix = "Added from Great Loop " & labels[library] & " Library";
        if (library != "port") out.prefix &= " [" & out.recordId & "]";
        out.prefix &= ": ";
        out.waypoint = {WAYPOINTID=0, WAYPOINTNAME=left(name,45), LATITUDE=lat, LONGITUDE=lng, NOTES=out.prefix & name};
        return out;
    }

    private string function field(required struct r, required string key) {
        return structKeyExists(r,key) && !isNull(r[key]) && isSimpleValue(r[key]) ? trim(toString(r[key])) : "";
    }

    private struct function unavailable() {
        return {eligible=false, recordId="", message="This library record is unavailable."};
    }
}
