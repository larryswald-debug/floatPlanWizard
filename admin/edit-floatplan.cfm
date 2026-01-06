<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Admin - Edit Float Plan</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <cfinclude template="../includes/header_styles.cfm">

    <style>
        .admin-wrapper {
            padding: 2rem 0 3rem;
        }
        .form-card {
            background: #fff;
            border-radius: 14px;
            box-shadow: 0 6px 18px rgba(0,0,0,0.08);
        }
        .field-row {
            border-bottom: 1px solid #eef1f4;
            padding: 0.75rem 0;
        }
        .field-row:last-child {
            border-bottom: none;
        }
        .field-meta {
            font-size: 0.75rem;
        }
        textarea.form-control {
            min-height: 120px;
        }
    </style>
</head>
<body class="bg-light">

<cfinclude template="_auth.cfm">

<cfscript>
alertMessage = "";
alertType = "info";
planId = 0;
if (structKeyExists(form, "floatplanId") AND isNumeric(form.floatplanId)) {
    planId = val(form.floatplanId);
} else if (structKeyExists(url, "id") AND isNumeric(url.id)) {
    planId = val(url.id);
}

qColumns = queryExecute("
    SELECT column_name, data_type, is_nullable, column_key, extra
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'floatplans'
    ORDER BY ordinal_position
", {}, { datasource = "fpw" });

function sqlTypeFor(dataType) {
    var dt = lcase(dataType);
    if (listFindNoCase("int,integer,smallint,mediumint,bigint,tinyint", dt)) {
        return "cf_sql_integer";
    }
    if (listFindNoCase("decimal,numeric", dt)) {
        return "cf_sql_decimal";
    }
    if (listFindNoCase("float,double", dt)) {
        return "cf_sql_double";
    }
    if (dt EQ "bit") {
        return "cf_sql_bit";
    }
    if (dt EQ "date") {
        return "cf_sql_date";
    }
    if (listFindNoCase("datetime,timestamp", dt)) {
        return "cf_sql_timestamp";
    }
    if (dt EQ "time") {
        return "cf_sql_time";
    }
    return "cf_sql_varchar";
}

if (structKeyExists(form, "action") AND form.action EQ "save") {
    errors = [];
    if (planId LTE 0) {
        arrayAppend(errors, "A valid float plan id is required.");
    }

    setClauses = [];
    params = {};

    if (!arrayLen(errors)) {
        for (row = 1; row LTE qColumns.recordCount; row++) {
            colName = qColumns.column_name[row];
            colKey = qColumns.column_key[row];
            if (colKey EQ "PRI") {
                continue;
            }
            paramName = "col_" & colName;
            rawValue = structKeyExists(form, colName) ? form[colName] : "";
            trimmedValue = trim(toString(rawValue));
            isNullable = (qColumns.is_nullable[row] EQ "YES");
            dataType = qColumns.data_type[row];
            shouldNull = (trimmedValue EQ "");

            if (shouldNull AND NOT isNullable) {
                arrayAppend(errors, "Column " & colName & " cannot be empty.");
                continue;
            }

            paramValue = trimmedValue;
            if (!shouldNull) {
                dtLower = lcase(dataType);
                if (listFindNoCase("int,integer,smallint,mediumint,bigint,tinyint", dtLower)) {
                    paramValue = val(trimmedValue);
                } else if (dtLower EQ "bit") {
                    paramValue = (listFindNoCase("1,true,yes,on", trimmedValue) GT 0);
                }
            }

            params[paramName] = {
                value = paramValue,
                cfsqltype = sqlTypeFor(dataType),
                null = shouldNull
            };
            arrayAppend(setClauses, colName & " = :" & paramName);
        }
    }

    if (!arrayLen(errors)) {
        params.planId = { value = planId, cfsqltype = "cf_sql_integer" };
        updateSql = "UPDATE floatplans SET " & arrayToList(setClauses, ", ") & " WHERE floatplanId = :planId";
        queryExecute(updateSql, params, { datasource = "fpw" });
        alertMessage = "Float plan updated.";
        alertType = "success";
    } else {
        alertMessage = arrayToList(errors, "<br>");
        alertType = "danger";
    }
}

qPlan = queryExecute("
    SELECT *
    FROM floatplans
    WHERE floatplanId = :planId
    LIMIT 1
", { planId = { value = planId, cfsqltype = "cf_sql_integer" } }, { datasource = "fpw" });

vesselName = "";
if (qPlan.recordCount EQ 1 AND structKeyExists(qPlan, "vesselId") AND isNumeric(qPlan.vesselId[1]) AND qPlan.vesselId[1] GT 0) {
    qVessel = queryExecute("
        SELECT vesselName
        FROM vessels
        WHERE vesselId = :vesselId
        LIMIT 1
    ", { vesselId = { value = qPlan.vesselId[1], cfsqltype = "cf_sql_integer" } }, { datasource = "fpw" });
    if (qVessel.recordCount EQ 1 AND structKeyExists(qVessel, "vesselName")) {
        vesselName = toString(qVessel.vesselName[1]);
    }
}
</cfscript>

<div class="container admin-wrapper">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
        <div>
            <h1 class="h3 mb-1">Edit Float Plan</h1>
            <p class="text-muted mb-0">Override any float plan value.</p>
            <cfif len(trim(toString(vesselName)))>
                <p class="text-muted mb-0">Vessel: <strong><cfoutput>#encodeForHTML(vesselName)#</cfoutput></strong></p>
            </cfif>
        </div>
        <div class="d-flex gap-2">
            <a class="btn btn-outline-secondary btn-sm" href="<cfoutput>#request.fpwBase#</cfoutput>/admin/index.cfm">Back to List</a>
            <a class="btn btn-outline-secondary btn-sm" href="<cfoutput>#request.fpwBase#</cfoutput>/admin/logout.cfm">Log Out</a>
        </div>
    </div>

    <cfif len(alertMessage)>
        <div class="alert alert-#alertType#" role="alert">
            <cfoutput>#alertMessage#</cfoutput>
        </div>
    </cfif>

    <cfif planId LTE 0 OR qPlan.recordCount EQ 0>
        <div class="alert alert-warning" role="alert">
            Float plan not found. Return to the list and choose another plan.
        </div>
    <cfelse>
        <div class="form-card p-4">
            <form method="post">
                <input type="hidden" name="action" value="save">
                <input type="hidden" name="floatplanId" value="<cfoutput>#planId#</cfoutput>">

                <cfoutput query="qColumns">
                    <cfset colName = qColumns.column_name>
                    <cfset colType = qColumns.data_type>
                    <cfset colNullable = qColumns.is_nullable>
                    <cfset colKey = qColumns.column_key>
                    <cfset isIdField = reFindNoCase("id$", colName) GT 0>
                    <cfset colValue = "">
                    <cfif structKeyExists(qPlan, colName)>
                        <cfset colValue = qPlan[colName][1]>
                    </cfif>
                    <cfset displayValue = isNull(colValue) ? "" : toString(colValue)>

                    <div class="field-row">
                        <div class="row g-3 align-items-start">
                            <div class="col-12 col-md-4">
                                <label class="form-label fw-semibold" for="field_#encodeForHTMLAttribute(colName)#">#encodeForHTML(colName)#</label>
                                <div class="text-muted field-meta">
                                    #encodeForHTML(colType)#<cfif colKey EQ "PRI"> • primary key</cfif><cfif colNullable EQ "NO"> • required</cfif>
                                </div>
                            </div>
                            <div class="col-12 col-md-8">
                                <cfif listFindNoCase("text,mediumtext,longtext", colType)>
                                    <textarea
                                        class="form-control"
                                        id="field_#encodeForHTMLAttribute(colName)#"
                                        name="#encodeForHTMLAttribute(colName)#"
                                        <cfif colKey EQ "PRI">disabled</cfif>
                                    >#encodeForHTML(displayValue)#</textarea>
                                <cfelse>
                                    <input
                                        type="text"
                                        class="form-control"
                                        id="field_#encodeForHTMLAttribute(colName)#"
                                        name="#encodeForHTMLAttribute(colName)#"
                                        value="#encodeForHTMLAttribute(displayValue)#"
                                        <cfif colKey EQ "PRI" OR isIdField>readonly</cfif>
                                    >
                                </cfif>
                            </div>
                        </div>
                    </div>
                </cfoutput>

                <div class="d-flex justify-content-end mt-4">
                    <button type="submit" class="btn btn-primary">Save Changes</button>
                </div>
            </form>
        </div>
    </cfif>
</div>

<cfinclude template="../includes/footer_scripts.cfm">
</body>
</html>
