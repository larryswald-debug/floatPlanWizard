<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Admin - Open Float Plans</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <cfinclude template="../includes/header_styles.cfm">

    <style>
        .admin-wrapper {
            padding: 2rem 0 3rem;
        }
        .admin-header {
            display: flex;
            flex-wrap: wrap;
            align-items: center;
            justify-content: space-between;
            gap: 1rem;
            margin-bottom: 1.5rem;
        }
        .table-responsive {
            box-shadow: 0 6px 18px rgba(0,0,0,0.08);
            border-radius: 12px;
            background: #fff;
        }
        .status-badge {
            font-size: 0.75rem;
            letter-spacing: 0.02em;
        }
    </style>
</head>
<body class="bg-light">

<cfinclude template="_auth.cfm">

<cfquery name="qPlans" datasource="fpw">
    SELECT
        floatplanId,
        userId,
        floatPlanName,
        status,
        departureTime,
        returnTime,
        returnTimezone,
        checkedInAt,
        lastUpdate,
        vesselId,
        operatorId
    FROM floatplans
    WHERE UPPER(TRIM(status)) IN ('ACTIVE', 'OVERDUE')
    ORDER BY
        CASE WHEN UPPER(TRIM(status)) = 'OVERDUE' THEN 0 ELSE 1 END,
        returnTime ASC,
        floatplanId DESC
</cfquery>

<div class="container admin-wrapper">
    <div class="admin-header">
        <div>
            <h1 class="h3 mb-1">Open Float Plans</h1>
            <p class="text-muted mb-0">Active and Overdue float plans only.</p>
        </div>
        <div class="d-flex gap-2">
            <a class="btn btn-outline-secondary btn-sm" href="<cfoutput>#request.fpwBase#</cfoutput>/admin/logout.cfm">Log Out</a>
        </div>
    </div>

    <div class="table-responsive p-3">
        <table class="table table-striped align-middle mb-0">
            <thead>
                <tr>
                    <th scope="col">Plan</th>
                    <th scope="col">User</th>
                    <th scope="col">Status</th>
                    <th scope="col">Departure</th>
                    <th scope="col">Return</th>
                    <th scope="col">Last Update</th>
                    <th scope="col"></th>
                </tr>
            </thead>
            <tbody>
                <cfif qPlans.recordCount EQ 0>
                    <tr>
                        <td colspan="7" class="text-center text-muted py-4">
                            No active or overdue float plans found.
                        </td>
                    </tr>
                <cfelse>
                    <cfoutput query="qPlans">
                        <cfset statusUpper = ucase(trim(toString(qPlans.status)))>
                        <cfset badgeClass = statusUpper EQ "OVERDUE" ? "bg-danger" : "bg-success">
                        <tr>
                            <td>
                                <div class="fw-semibold">#encodeForHTML(qPlans.floatPlanName)#</div>
                                <small class="text-muted">## #qPlans.floatplanId#</small>
                            </td>
                            <td>#encodeForHTML(qPlans.userId)#</td>
                            <td>
                                <span class="badge status-badge #badgeClass#">#encodeForHTML(statusUpper)#</span>
                            </td>
                            <td>#encodeForHTML(qPlans.departureTime)#</td>
                            <td>
                                #encodeForHTML(qPlans.returnTime)#
                                <cfif len(trim(toString(qPlans.returnTimezone)))>
                                    <small class="text-muted">(#encodeForHTML(qPlans.returnTimezone)#)</small>
                                </cfif>
                            </td>
                            <td>#encodeForHTML(qPlans.lastUpdate)#</td>
                            <td class="text-end">
                                <a class="btn btn-sm btn-primary" href="#request.fpwBase#/admin/edit-floatplan.cfm?id=#qPlans.floatplanId#">Edit</a>
                            </td>
                        </tr>
                    </cfoutput>
                </cfif>
            </tbody>
        </table>
    </div>
</div>

<cfinclude template="../includes/footer_scripts.cfm">
</body>
</html>
