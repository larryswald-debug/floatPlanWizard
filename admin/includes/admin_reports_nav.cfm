<cfscript>
adminNavBase = structKeyExists(request, "fpwBase") ? trim(toString(request.fpwBase)) : "";
if (!structKeyExists(request, "fpwBase")) {
    if (structKeyExists(cgi, "SCRIPT_NAME")) {
        adminNavBase = trim(toString(cgi.SCRIPT_NAME));
    } else if (structKeyExists(cgi, "script_name")) {
        adminNavBase = trim(toString(cgi.script_name));
    }

    adminNavBase = reReplace(adminNavBase, "[?##].*$", "");
    adminNavBase = replace(adminNavBase, "\", "/", "all");
    adminNavBase = reReplaceNoCase(adminNavBase, "/api/v1(/.*)?$", "");
    adminNavBase = reReplaceNoCase(adminNavBase, "/(app|admin|assets|tests)(/.*)?$", "");
    adminNavBase = reReplaceNoCase(adminNavBase, "/[^/]*\.(cfm|cfc)$", "");
    adminNavBase = reReplace(adminNavBase, "/$", "");
    if (adminNavBase EQ "/") {
        adminNavBase = "";
    }
    if (len(adminNavBase) AND left(adminNavBase, 1) NEQ "/") {
        adminNavBase = "/" & adminNavBase;
    }

    request.fpwBase = adminNavBase;
    request.fpwApiBase = adminNavBase & "/api/v1";
}
currentAdminFile = "";
if (structKeyExists(cgi, "SCRIPT_NAME")) {
    currentAdminFile = lCase(listLast(toString(cgi.SCRIPT_NAME), "/"));
}
if (!len(currentAdminFile) AND structKeyExists(cgi, "CF_TEMPLATE_PATH")) {
    currentAdminFile = lCase(listLast(replace(toString(cgi.CF_TEMPLATE_PATH), "\\", "/", "all"), "/"));
}
adminReportPages = [
    { "file" = "floatplan-cleanup.cfm", "label" = "FloatPlan Cleanup" },
    { "file" = "fuel-calculator.cfm", "label" = "Fuel Calculator" },
    { "file" = "great-loop-locks-import.cfm", "label" = "Great Loop Locks Import" },
    { "file" = "metar-seed-test.cfm", "label" = "METAR Seed Test" },
    { "file" = "monitoring-dashboard.cfm", "label" = "Monitoring Dashboard" },
    { "file" = "user-manager.cfm", "label" = "User Manager" },
    { "file" = "operator-manager.cfm", "label" = "Operator Manager" },
    { "file" = "passenger-manager.cfm", "label" = "Passenger Manager" },
    { "file" = "port_state_backfill.cfm", "label" = "Port State Backfill" },
    { "file" = "route-cleanup.cfm", "label" = "Route Cleanup" },
    { "file" = "segment_geometry.cfm", "label" = "Segment Geometry" },
    { "file" = "timeline_exposure_harness.cfm", "label" = "Timeline Exposure Harness" },
    { "file" = "vessel-manager.cfm", "label" = "Vessel Manager" },
    { "file" = "waypoint-manager.cfm", "label" = "Waypoint Manager" },
    { "file" = "wpi_port_populate.cfm", "label" = "WPI Port Populate" }
];
</cfscript>
<style>
    .admin-reports-nav-bar {
        max-width: 1400px;
        margin: 14px auto;
        padding: 0 12px;
    }

    .admin-reports-nav {
        display: flex;
        gap: 8px;
        flex-wrap: wrap;
        padding: 12px;
        border: 1px solid rgba(148, 163, 184, 0.32);
        border-radius: 12px;
        background: rgba(255, 255, 255, 0.92);
        box-shadow: 0 6px 18px rgba(15, 23, 42, 0.08);
    }

    .admin-reports-nav a {
        text-decoration: none;
        border: 1px solid #c8d0db;
        background: #f8fafc;
        color: #1f2937;
        padding: 6px 10px;
        border-radius: 6px;
        font-size: 14px;
        line-height: 1.25;
    }

    .admin-reports-nav a:hover {
        background: #f1f5f9;
        color: #111827;
    }

    .admin-reports-nav a.is-active {
        background: #111827;
        border-color: #111827;
        color: #ffffff;
    }

    @media (max-width: 768px) {
        .admin-reports-nav-bar {
            margin: 12px auto;
        }

        .admin-reports-nav {
            padding: 10px;
        }

        .admin-reports-nav a {
            font-size: 13px;
        }
    }
</style>
<div class="admin-reports-nav-bar">
    <nav class="admin-reports-nav" aria-label="Admin Reports">
        <cfloop array="#adminReportPages#" index="adminPage">
            <cfset isActivePage = (currentAdminFile EQ lCase(adminPage.file))>
            <cfoutput><a href="#adminNavBase#/admin/#adminPage.file#"<cfif isActivePage> class="is-active"</cfif>>#encodeForHtml(adminPage.label)#</a></cfoutput>
        </cfloop>
    </nav>
</div>
