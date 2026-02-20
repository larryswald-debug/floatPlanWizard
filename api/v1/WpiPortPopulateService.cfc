<cfcomponent output="false" hint="Populate missing FPW port coordinates from NGA WPI and backfill loop segment endpoints.">

    <cfset variables.WPI_QUERY_URL = "https://vcps.nga.mil/nauticalpubs-feature/rest/services/WPI/World_Port_Index_Viewer/FeatureServer/0/query">
    <cfset variables.DEFAULT_REPORT_PATH = "/tmp/fpw-wpi-populate.json">

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

    <cffunction name="run" access="public" returntype="struct" output="false" hint="Dry-run by default. Set options.apply=true to write DB updates.">
        <cfargument name="options" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var opts = normalizeOptions(arguments.options);
            var requestedNames = normalizeRequestedNames(opts.names);
            var ports = getMissingPorts(opts, requestedNames);
            var updates = [];
            var unresolved = [];
            var errored = [];
            var i = 0;
            var port = {};
            var resolved = {};
            var appliedPortUpdates = 0;
            var backfillResult = {};
            var baseline = {};
            var summary = {};
            var reportJson = "";

            for (i = 1; i LTE arrayLen(ports); i++) {
                port = ports[i];
                try {
                    resolved = resolvePort(port.name, opts);
                    if (
                        !resolved.matched
                        OR !isStruct(resolved.match)
                        OR !structKeyExists(resolved.match, "lat")
                        OR !structKeyExists(resolved.match, "lng")
                        OR !isNumeric(resolved.match.lat)
                        OR !isNumeric(resolved.match.lng)
                    ) {
                        arrayAppend(unresolved, {
                            "port_id" = port.id,
                            "port_name" = port.name,
                            "attempts" = resolved.attempts
                        });
                    } else {
                        arrayAppend(updates, {
                            "port_id" = port.id,
                            "port_name" = port.name,
                            "lat" = val(resolved.match.lat),
                            "lng" = val(resolved.match.lng),
                            "matched_port_name" = (structKeyExists(resolved.match, "main_port_name") ? toString(resolved.match.main_port_name) : ""),
                            "unlocode" = (structKeyExists(resolved.match, "unlocode") ? resolved.match.unlocode : javacast("null", "")),
                            "wpinumber" = (structKeyExists(resolved.match, "wpinumber") ? resolved.match.wpinumber : javacast("null", "")),
                            "strategy" = (structKeyExists(resolved, "strategy") ? toString(resolved.strategy) : "")
                        });
                    }
                } catch (any e) {
                    arrayAppend(errored, {
                        "port_id" = port.id,
                        "port_name" = port.name,
                        "error" = toString(e.message)
                    });
                }

                if (opts.delayMs GT 0) {
                    sleep(opts.delayMs);
                }
            }

            if (opts.apply) {
                appliedPortUpdates = applyPortUpdates(updates);
                if (!opts.noBackfill) {
                    backfillResult = backfillLoopSegments();
                }
            } else if (!opts.noBackfill) {
                baseline = getEndpointMissingCounts();
                backfillResult = {
                    "before" = baseline,
                    "after" = baseline,
                    "improvedStart" = 0,
                    "improvedEnd" = 0,
                    "improvedAny" = 0,
                    "note" = "Dry-run; no DB writes."
                };
            }

            summary = {
                "SUCCESS" = true,
                "mode" = (opts.apply ? "apply" : "dry-run"),
                "fuzzy_matching" = opts.fuzzy,
                "queried_at_utc" = nowUtcIso(),
                "datasource" = getDatasource(),
                "total_ports_scanned" = arrayLen(ports),
                "matched_updates_ready" = arrayLen(updates),
                "unresolved_count" = arrayLen(unresolved),
                "error_count" = arrayLen(errored),
                "applied_port_updates" = appliedPortUpdates,
                "backfill" = backfillResult,
                "sample_updates" = arraySliceSafe(updates, 1, 30),
                "unresolved" = arraySliceSafe(unresolved, 1, 80),
                "errors" = errored
            };

            if (len(opts.reportOutPath)) {
                reportJson = serializeJSON(summary);
                try {
                    fileWrite(opts.reportOutPath, reportJson);
                    summary.report_written = opts.reportOutPath;
                } catch (any fwErr) {
                    summary.report_write_error = toString(fwErr.message);
                }
            }

            return summary;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeOptions" access="private" returntype="struct" output="false">
        <cfargument name="raw" type="struct" required="true">
        <cfscript>
            var opts = {
                "apply" = toBoolean(readValue(arguments.raw, "apply", false), false),
                "fuzzy" = toBoolean(readValue(arguments.raw, "fuzzy", false), false),
                "noBackfill" = toBoolean(readValue(arguments.raw, "noBackfill", false), false),
                "limit" = toPositiveInt(readValue(arguments.raw, "limit", 0)),
                "delayMs" = toPositiveInt(readValue(arguments.raw, "delayMs", 120)),
                "names" = readValue(arguments.raw, "names", []),
                "reportOutPath" = trim(toString(readValue(arguments.raw, "reportOutPath", variables.DEFAULT_REPORT_PATH)))
            };

            if (opts.delayMs GT 5000) {
                opts.delayMs = 5000;
            }
            if (opts.limit LT 0) {
                opts.limit = 0;
            }

            return opts;
        </cfscript>
    </cffunction>

    <cffunction name="normalizeRequestedNames" access="private" returntype="array" output="false">
        <cfargument name="namesRaw" type="any" required="true">
        <cfscript>
            var out = [];
            var seen = {};
            var i = 0;
            var value = "";
            var parts = [];
            var p = "";
            var key = "";

            if (isArray(arguments.namesRaw)) {
                for (i = 1; i LTE arrayLen(arguments.namesRaw); i++) {
                    value = trim(toString(arguments.namesRaw[i]));
                    if (!len(value)) {
                        continue;
                    }
                    key = lCase(value);
                    if (!structKeyExists(seen, key)) {
                        seen[key] = true;
                        arrayAppend(out, value);
                    }
                }
                return out;
            }

            if (isSimpleValue(arguments.namesRaw)) {
                value = trim(toString(arguments.namesRaw));
                if (!len(value)) {
                    return out;
                }
                parts = reSplit("[\r\n,]+", value);
                for (i = 1; i LTE arrayLen(parts); i++) {
                    p = trim(toString(parts[i]));
                    if (!len(p)) {
                        continue;
                    }
                    key = lCase(p);
                    if (!structKeyExists(seen, key)) {
                        seen[key] = true;
                        arrayAppend(out, p);
                    }
                }
            }

            return out;
        </cfscript>
    </cffunction>

    <cffunction name="resolvePort" access="private" returntype="struct" output="false">
        <cfargument name="name" type="string" required="true">
        <cfargument name="opts" type="struct" required="true">
        <cfscript>
            var attempts = [];
            var exactWhere = buildWhereEquals(arguments.name);
            var exactRes = queryWpiWithRetry(exactWhere, 10, 3);
            var pick = {};
            var likeWhere = "";
            var likeRes = {};
            var variants = [];
            var tokenResults = [];
            var i = 0;
            var variant = "";
            var tokenWhere = "";
            var tokenRes = {};

            arrayAppend(attempts, {
                "mode" = "exact",
                "where" = exactWhere,
                "count" = arrayLen(exactRes.matches)
            });

            pick = chooseSingleMatch(arguments.name, exactRes.matches);
            if (pick.matched) {
                return {
                    "matched" = true,
                    "strategy" = "exact/" & pick.strategy,
                    "match" = pick.match,
                    "attempts" = attempts
                };
            }

            likeWhere = buildWhereLike(arguments.name);
            likeRes = queryWpiWithRetry(likeWhere, 20, 3);
            arrayAppend(attempts, {
                "mode" = "like",
                "where" = likeWhere,
                "count" = arrayLen(likeRes.matches)
            });

            pick = chooseSingleMatch(arguments.name, likeRes.matches);
            if (pick.matched) {
                return {
                    "matched" = true,
                    "strategy" = "like/" & pick.strategy,
                    "match" = pick.match,
                    "attempts" = attempts
                };
            }

            if (arguments.opts.fuzzy) {
                variants = buildVariants(arguments.name);
                for (i = 1; i LTE arrayLen(variants); i++) {
                    variant = variants[i];
                    if (variant EQ arguments.name) {
                        continue;
                    }
                    tokenWhere = buildWhereEquals(variant);
                    tokenRes = queryWpiWithRetry(tokenWhere, 10, 3);
                    arrayAppend(attempts, {
                        "mode" = "token-exact:" & variant,
                        "where" = tokenWhere,
                        "count" = arrayLen(tokenRes.matches)
                    });
                    if (arrayLen(tokenRes.matches) EQ 1) {
                        arrayAppend(tokenResults, {
                            "variant" = variant,
                            "match" = tokenRes.matches[1]
                        });
                    }
                    if (arguments.opts.delayMs GT 0) {
                        sleep(arguments.opts.delayMs);
                    }
                }
                if (arrayLen(tokenResults) EQ 1) {
                    return {
                        "matched" = true,
                        "strategy" = "fuzzy/token-exact:" & tokenResults[1].variant,
                        "match" = tokenResults[1].match,
                        "attempts" = attempts
                    };
                }
            }

            return {
                "matched" = false,
                "strategy" = "",
                "match" = javacast("null", ""),
                "attempts" = attempts
            };
        </cfscript>
    </cffunction>

    <cffunction name="queryWpiWithRetry" access="private" returntype="struct" output="false">
        <cfargument name="whereClause" type="string" required="true">
        <cfargument name="resultLimit" type="numeric" required="true">
        <cfargument name="maxAttempts" type="numeric" required="false" default="3">
        <cfscript>
            var attempt = 0;
            var limit = (arguments.resultLimit LTE 0 ? 5 : int(arguments.resultLimit));
            var maxTry = (arguments.maxAttempts LTE 0 ? 1 : int(arguments.maxAttempts));
            var out = {};

            for (attempt = 1; attempt LTE maxTry; attempt++) {
                try {
                    out = queryWpi(arguments.whereClause, limit);
                    return out;
                } catch (any e) {
                    if (!isTransientError(e) OR attempt GTE maxTry) {
                        rethrow;
                    }
                    sleep(attempt * 450);
                }
            }

            return { "matches" = [] };
        </cfscript>
    </cffunction>

    <cffunction name="queryWpi" access="private" returntype="struct" output="false">
        <cfargument name="whereClause" type="string" required="true">
        <cfargument name="resultLimit" type="numeric" required="true">
        <cfscript>
            var url = variables.WPI_QUERY_URL
                & "?where=" & urlEncodedFormat(arguments.whereClause)
                & "&outFields=" & urlEncodedFormat("wpinumber,main_port_name,unlocode")
                & "&returnGeometry=true"
                & "&orderByFields=" & urlEncodedFormat("main_port_name ASC")
                & "&resultRecordCount=" & int(arguments.resultLimit)
                & "&f=json";
            var payload = requestJson(url);
            var features = [];
            var matches = [];
            var i = 0;
            var feature = {};
            var attrs = {};
            var geom = {};
            var latVal = javacast("null", "");
            var lngVal = javacast("null", "");

            if (isStruct(payload) AND structKeyExists(payload, "error")) {
                throw(message = "WPI API error: " & serializeJSON(payload.error));
            }

            if (isStruct(payload) AND structKeyExists(payload, "features") AND isArray(payload.features)) {
                features = payload.features;
            }

            for (i = 1; i LTE arrayLen(features); i++) {
                feature = (isStruct(features[i]) ? features[i] : {});
                attrs = (structKeyExists(feature, "attributes") AND isStruct(feature.attributes) ? feature.attributes : {});
                geom = (structKeyExists(feature, "geometry") AND isStruct(feature.geometry) ? feature.geometry : {});

                if (structKeyExists(geom, "y") AND isNumeric(geom.y)) {
                    latVal = val(geom.y);
                } else {
                    latVal = javacast("null", "");
                }

                if (structKeyExists(geom, "x") AND isNumeric(geom.x)) {
                    lngVal = val(geom.x);
                } else {
                    lngVal = javacast("null", "");
                }

                arrayAppend(matches, {
                    "main_port_name" = (structKeyExists(attrs, "main_port_name") ? toString(attrs.main_port_name) : ""),
                    "wpinumber" = (structKeyExists(attrs, "wpinumber") ? attrs.wpinumber : javacast("null", "")),
                    "unlocode" = (structKeyExists(attrs, "unlocode") ? attrs.unlocode : javacast("null", "")),
                    "lat" = latVal,
                    "lng" = lngVal
                });
            }

            return { "matches" = matches };
        </cfscript>
    </cffunction>

    <cffunction name="requestJson" access="private" returntype="struct" output="false">
        <cfargument name="url" type="string" required="true">
        <cfscript>
            var primaryErr = "";

            try {
                return requestJsonByCfhttp(arguments.url);
            } catch (any ePrimary) {
                primaryErr = buildErrorMessage(ePrimary);
                if (!shouldUseInsecureFallback(primaryErr, arguments.url)) {
                    rethrow;
                }
            }

            try {
                return requestJsonByApacheTrustAll(arguments.url);
            } catch (any eFallback) {
                throw(message = "WPI request failed (cfhttp + insecure fallback). Primary: " & primaryErr & " | Fallback: " & buildErrorMessage(eFallback));
            }
        </cfscript>
    </cffunction>

    <cffunction name="requestJsonByCfhttp" access="private" returntype="struct" output="false">
        <cfargument name="url" type="string" required="true">
        <cfscript>
            var httpRes = {};
            var statusCode = 0;
            var statusText = "";
            var body = "";

            cfhttp(url=arguments.url, method="get", result="httpRes", timeout="25", throwOnError="false") {
                cfhttpparam(type="header", name="Accept", value="application/json");
                cfhttpparam(type="header", name="User-Agent", value="FPW-WPI-PortPopulate/1.0");
            }

            statusText = (structKeyExists(httpRes, "statusCode") ? toString(httpRes.statusCode) : "");
            statusCode = parseHttpStatusCode(statusText);
            body = (structKeyExists(httpRes, "fileContent") ? toString(httpRes.fileContent) : "");

            if (statusCode LT 200 OR statusCode GTE 300) {
                if (statusCode EQ 0 AND len(trim(statusText))) {
                    throw(message = "HTTP 0: " & statusText);
                }
                if (len(trim(body))) {
                    throw(message = "HTTP " & statusCode & ": " & left(body, 300));
                }
                throw(message = "HTTP " & statusCode & ": " & (len(trim(statusText)) ? statusText : "Unknown response status"));
            }

            if (!len(trim(body))) {
                return {};
            }

            try {
                return deserializeJSON(body, false);
            } catch (any e) {
                throw(message = "Invalid JSON response: " & e.message);
            }
        </cfscript>
    </cffunction>

    <cffunction name="requestJsonByApacheTrustAll" access="private" returntype="struct" output="false">
        <cfargument name="url" type="string" required="true">
        <cfscript>
            var trustAll = createObject("java", "org.apache.http.conn.ssl.TrustAllStrategy").INSTANCE;
            var noopVerifier = createObject("java", "org.apache.http.conn.ssl.NoopHostnameVerifier").INSTANCE;
            var sslBuilder = createObject("java", "org.apache.http.conn.ssl.SSLContexts").custom();
            var sslContext = "";
            var socketFactory = "";
            var clientBuilder = "";
            var client = "";
            var requestObj = "";
            var response = javacast("null", "");
            var statusCode = 0;
            var statusText = "";
            var body = "";

            sslBuilder.loadTrustMaterial(javacast("null", ""), trustAll);
            sslContext = sslBuilder.build();
            socketFactory = createObject("java", "org.apache.http.conn.ssl.SSLConnectionSocketFactory").init(sslContext, noopVerifier);
            clientBuilder = createObject("java", "org.apache.http.impl.client.HttpClients").custom();
            clientBuilder.setSSLSocketFactory(socketFactory);
            clientBuilder.disableAutomaticRetries();
            client = clientBuilder.build();

            requestObj = createObject("java", "org.apache.http.client.methods.HttpGet").init(arguments.url);
            requestObj.setHeader("Accept", "application/json");
            requestObj.setHeader("User-Agent", "FPW-WPI-PortPopulate/1.0");

            try {
                response = client.execute(requestObj);
                statusCode = response.getStatusLine().getStatusCode();
                statusText = toString(response.getStatusLine().toString());
                body = readHttpEntityBody(response.getEntity());
            } finally {
                if (!isNull(response)) {
                    try { response.close(); } catch (any ignoredCloseResponse) {}
                }
                try { client.close(); } catch (any ignoredCloseClient) {}
            }

            if (statusCode LT 200 OR statusCode GTE 300) {
                if (len(trim(body))) {
                    throw(message = "HTTP " & statusCode & ": " & left(body, 300));
                }
                throw(message = "HTTP " & statusCode & ": " & statusText);
            }

            if (!len(trim(body))) {
                return {};
            }

            try {
                return deserializeJSON(body, false);
            } catch (any e) {
                throw(message = "Invalid JSON response: " & e.message);
            }
        </cfscript>
    </cffunction>

    <cffunction name="readHttpEntityBody" access="private" returntype="string" output="false">
        <cfargument name="entity" type="any" required="true">
        <cfscript>
            var body = "";
            var entityUtils = "";
            var stream = javacast("null", "");
            var scanner = javacast("null", "");

            if (isNull(arguments.entity)) {
                return "";
            }

            try {
                entityUtils = createObject("java", "org.apache.http.util.EntityUtils");
                body = toString(entityUtils.toString(arguments.entity, "UTF-8"));
                return body;
            } catch (any ignoredEntityUtils) {
                // Fallback stream reader if EntityUtils is unavailable.
            }

            stream = arguments.entity.getContent();
            try {
                scanner = createObject("java", "java.util.Scanner").init(stream, "UTF-8");
                scanner = scanner.useDelimiter("\\A");
                if (scanner.hasNext()) {
                    body = toString(scanner.next());
                }
            } finally {
                if (!isNull(scanner)) {
                    try { scanner.close(); } catch (any ignoredScannerClose) {}
                }
                if (!isNull(stream)) {
                    try { stream.close(); } catch (any ignoredStreamClose) {}
                }
            }

            return body;
        </cfscript>
    </cffunction>

    <cffunction name="parseHttpStatusCode" access="private" returntype="numeric" output="false">
        <cfargument name="statusText" type="string" required="true">
        <cfscript>
            var firstToken = trim(listFirst(arguments.statusText, " "));
            if (len(firstToken) AND isNumeric(firstToken)) {
                return int(val(firstToken));
            }
            if (isNumeric(arguments.statusText)) {
                return int(val(arguments.statusText));
            }
            return 0;
        </cfscript>
    </cffunction>

    <cffunction name="buildErrorMessage" access="private" returntype="string" output="false">
        <cfargument name="err" type="any" required="true">
        <cfscript>
            var msg = "";
            var detail = "";

            if (isStruct(arguments.err) AND structKeyExists(arguments.err, "message")) {
                msg = trim(toString(arguments.err.message));
                if (structKeyExists(arguments.err, "detail")) {
                    detail = trim(toString(arguments.err.detail));
                }
            } else {
                msg = trim(toString(arguments.err));
            }

            if (len(detail) AND findNoCase(detail, msg) EQ 0) {
                msg &= " | " & detail;
            }
            if (!len(msg)) {
                msg = "Unknown error";
            }
            if (len(msg) GT 700) {
                msg = left(msg, 700);
            }
            return msg;
        </cfscript>
    </cffunction>

    <cffunction name="shouldUseInsecureFallback" access="private" returntype="boolean" output="false">
        <cfargument name="errMsg" type="string" required="true">
        <cfargument name="url" type="string" required="true">
        <cfscript>
            var msg = lCase(trim(arguments.errMsg));
            var urlVal = lCase(trim(arguments.url));
            var wpiBase = lCase(trim(variables.WPI_QUERY_URL));

            if (left(urlVal, len(wpiBase)) NEQ wpiBase) {
                return false;
            }

            return (
                findNoCase("http 0", msg) GT 0
                OR findNoCase("connection failure", msg) GT 0
                OR findNoCase("certificate", msg) GT 0
                OR findNoCase("handshake", msg) GT 0
                OR findNoCase("ssl", msg) GT 0
                OR findNoCase("socket", msg) GT 0
                OR findNoCase("econnreset", msg) GT 0
                OR findNoCase("empty reply", msg) GT 0
                OR findNoCase("timed out", msg) GT 0
            );
        </cfscript>
    </cffunction>

    <cffunction name="isTransientError" access="private" returntype="boolean" output="false">
        <cfargument name="err" type="any" required="true">
        <cfscript>
            var msg = "";
            if (isStruct(arguments.err) AND structKeyExists(arguments.err, "message")) {
                msg = lCase(toString(arguments.err.message));
            } else {
                msg = lCase(toString(arguments.err));
            }
            return (
                findNoCase("econnreset", msg) GT 0
                OR findNoCase("timed out", msg) GT 0
                OR findNoCase("socket", msg) GT 0
                OR findNoCase("socket hang up", msg) GT 0
                OR findNoCase("connection failure", msg) GT 0
                OR findNoCase("empty reply", msg) GT 0
                OR findNoCase("http 0", msg) GT 0
                OR findNoCase("http 502", msg) GT 0
                OR findNoCase("http 503", msg) GT 0
                OR findNoCase("http 504", msg) GT 0
                OR findNoCase("connection reset", msg) GT 0
            );
        </cfscript>
    </cffunction>

    <cffunction name="chooseSingleMatch" access="private" returntype="struct" output="false">
        <cfargument name="inputName" type="string" required="true">
        <cfargument name="matches" type="array" required="true">
        <cfscript>
            var strict = [];
            var i = 0;
            var item = {};
            var inputKey = strictKey(arguments.inputName);

            if (arrayLen(arguments.matches) EQ 0) {
                return { "matched" = false, "strategy" = "", "match" = javacast("null", "") };
            }
            if (arrayLen(arguments.matches) EQ 1) {
                return { "matched" = true, "strategy" = "single-result", "match" = arguments.matches[1] };
            }

            for (i = 1; i LTE arrayLen(arguments.matches); i++) {
                item = arguments.matches[i];
                if (strictKey(structKeyExists(item, "main_port_name") ? item.main_port_name : "") EQ inputKey) {
                    arrayAppend(strict, item);
                }
            }
            if (arrayLen(strict) EQ 1) {
                return { "matched" = true, "strategy" = "strict-normalized", "match" = strict[1] };
            }

            return { "matched" = false, "strategy" = "", "match" = javacast("null", "") };
        </cfscript>
    </cffunction>

    <cffunction name="getMissingPorts" access="private" returntype="array" output="false">
        <cfargument name="opts" type="struct" required="true">
        <cfargument name="requestedNames" type="array" required="true">
        <cfscript>
            var sql = "
                SELECT id, name, lat, lng
                FROM ports
                WHERE (lat IS NULL OR lng IS NULL)
                  AND name IS NOT NULL
                  AND LENGTH(TRIM(name)) > 0
            ";
            var binds = {};
            var placeholders = [];
            var i = 0;
            var bindName = "";
            var q = queryNew("");
            var rows = [];

            if (arrayLen(arguments.requestedNames)) {
                for (i = 1; i LTE arrayLen(arguments.requestedNames); i++) {
                    bindName = "name" & i;
                    arrayAppend(placeholders, ":" & bindName);
                    binds[bindName] = {
                        "value" = uCase(trim(arguments.requestedNames[i])),
                        "cfsqltype" = "cf_sql_varchar"
                    };
                }
                sql &= " AND UPPER(TRIM(name)) IN (" & arrayToList(placeholders, ",") & ") ";
            }

            sql &= " ORDER BY id ASC ";
            if (arguments.opts.limit GT 0) {
                sql &= " LIMIT " & arguments.opts.limit;
            }

            q = queryExecute(sql, binds, { datasource = getDatasource() });

            for (i = 1; i LTE q.recordCount; i++) {
                arrayAppend(rows, {
                    "id" = val(q.id[i]),
                    "name" = (isNull(q.name[i]) ? "" : toString(q.name[i])),
                    "lat" = (isNull(q.lat[i]) ? javacast("null", "") : val(q.lat[i])),
                    "lng" = (isNull(q.lng[i]) ? javacast("null", "") : val(q.lng[i]))
                });
            }

            return rows;
        </cfscript>
    </cffunction>

    <cffunction name="applyPortUpdates" access="private" returntype="numeric" output="false">
        <cfargument name="updates" type="array" required="true">
        <cfscript>
            var i = 0;
            var u = {};
            var count = 0;

            for (i = 1; i LTE arrayLen(arguments.updates); i++) {
                u = arguments.updates[i];
                queryExecute(
                    "
                    UPDATE ports
                    SET lat = :latVal, lng = :lngVal
                    WHERE id = :portId
                      AND (lat IS NULL OR lng IS NULL)
                    ",
                    {
                        latVal = { value = val(u.lat), cfsqltype = "cf_sql_decimal", scale = 7 },
                        lngVal = { value = val(u.lng), cfsqltype = "cf_sql_decimal", scale = 7 },
                        portId = { value = val(u.port_id), cfsqltype = "cf_sql_integer" }
                    },
                    { datasource = getDatasource() }
                );
                count += 1;
            }

            return count;
        </cfscript>
    </cffunction>

    <cffunction name="getEndpointMissingCounts" access="private" returntype="struct" output="false">
        <cfscript>
            var q = queryExecute(
                "
                SELECT
                  SUM(CASE WHEN start_lat IS NULL OR start_lng IS NULL THEN 1 ELSE 0 END) AS missing_start,
                  SUM(CASE WHEN end_lat IS NULL OR end_lng IS NULL THEN 1 ELSE 0 END) AS missing_end,
                  SUM(CASE WHEN start_lat IS NULL OR start_lng IS NULL OR end_lat IS NULL OR end_lng IS NULL THEN 1 ELSE 0 END) AS missing_any
                FROM loop_segments
                ",
                {},
                { datasource = getDatasource() }
            );

            return {
                "missingStart" = (q.recordCount ? val(q.missing_start[1]) : 0),
                "missingEnd" = (q.recordCount ? val(q.missing_end[1]) : 0),
                "missingAny" = (q.recordCount ? val(q.missing_any[1]) : 0)
            };
        </cfscript>
    </cffunction>

    <cffunction name="backfillLoopSegments" access="private" returntype="struct" output="false">
        <cfscript>
            var before = getEndpointMissingCounts();
            var after = {};

            queryExecute(
                "
                UPDATE loop_segments s
                INNER JOIN (
                  SELECT
                    MD5(LOWER(TRIM(CONVERT(name USING utf8mb4)))) AS normalized_key,
                    MIN(lat) AS lat,
                    MIN(lng) AS lng
                  FROM ports
                  WHERE name IS NOT NULL
                    AND LENGTH(TRIM(name)) > 0
                    AND lat IS NOT NULL
                    AND lng IS NOT NULL
                  GROUP BY MD5(LOWER(TRIM(CONVERT(name USING utf8mb4))))
                  HAVING COUNT(*) = 1
                ) p
                  ON MD5(LOWER(TRIM(CONVERT(s.start_name USING utf8mb4)))) = p.normalized_key
                SET
                  s.start_lat = COALESCE(s.start_lat, p.lat),
                  s.start_lng = COALESCE(s.start_lng, p.lng)
                WHERE s.start_name IS NOT NULL
                  AND LENGTH(TRIM(s.start_name)) > 0
                  AND (s.start_lat IS NULL OR s.start_lng IS NULL)
                ",
                {},
                { datasource = getDatasource() }
            );

            queryExecute(
                "
                UPDATE loop_segments s
                INNER JOIN (
                  SELECT
                    MD5(LOWER(TRIM(CONVERT(name USING utf8mb4)))) AS normalized_key,
                    MIN(lat) AS lat,
                    MIN(lng) AS lng
                  FROM ports
                  WHERE name IS NOT NULL
                    AND LENGTH(TRIM(name)) > 0
                    AND lat IS NOT NULL
                    AND lng IS NOT NULL
                  GROUP BY MD5(LOWER(TRIM(CONVERT(name USING utf8mb4))))
                  HAVING COUNT(*) = 1
                ) p
                  ON MD5(LOWER(TRIM(CONVERT(s.end_name USING utf8mb4)))) = p.normalized_key
                SET
                  s.end_lat = COALESCE(s.end_lat, p.lat),
                  s.end_lng = COALESCE(s.end_lng, p.lng)
                WHERE s.end_name IS NOT NULL
                  AND LENGTH(TRIM(s.end_name)) > 0
                  AND (s.end_lat IS NULL OR s.end_lng IS NULL)
                ",
                {},
                { datasource = getDatasource() }
            );

            after = getEndpointMissingCounts();

            return {
                "before" = before,
                "after" = after,
                "improvedStart" = max(0, before.missingStart - after.missingStart),
                "improvedEnd" = max(0, before.missingEnd - after.missingEnd),
                "improvedAny" = max(0, before.missingAny - after.missingAny)
            };
        </cfscript>
    </cffunction>

    <cffunction name="buildVariants" access="private" returntype="array" output="false">
        <cfargument name="value" type="string" required="true">
        <cfscript>
            var raw = trim(arguments.value);
            var variants = [];
            var seen = {};
            var parts = [];
            var i = 0;
            var part = "";

            if (len(raw)) {
                seen[lCase(raw)] = true;
                arrayAppend(variants, raw);
            }

            parts = reSplit("[/,]", raw);
            for (i = 1; i LTE arrayLen(parts); i++) {
                part = trim(parts[i]);
                if (len(part) LT 3) {
                    continue;
                }
                if (!structKeyExists(seen, lCase(part))) {
                    seen[lCase(part)] = true;
                    arrayAppend(variants, part);
                }
            }

            return variants;
        </cfscript>
    </cffunction>

    <cffunction name="buildWhereEquals" access="private" returntype="string" output="false">
        <cfargument name="name" type="string" required="true">
        <cfscript>
            var clean = replace(uCase(trim(arguments.name)), "'", "''", "all");
            return "UPPER(main_port_name) = '" & clean & "'";
        </cfscript>
    </cffunction>

    <cffunction name="buildWhereLike" access="private" returntype="string" output="false">
        <cfargument name="name" type="string" required="true">
        <cfscript>
            var clean = replace(uCase(trim(arguments.name)), "'", "''", "all");
            return "UPPER(main_port_name) LIKE '%" & clean & "%'";
        </cfscript>
    </cffunction>

    <cffunction name="strictKey" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            var norm = normalizeName(arguments.value);
            return replace(norm, " ", "", "all");
        </cfscript>
    </cffunction>

    <cffunction name="normalizeName" access="private" returntype="string" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            var s = lCase(trim(toString(arguments.value)));
            if (!len(s)) {
                return "";
            }
            s = reReplace(s, "\bst[.]?\b", "saint", "all");
            s = reReplace(s, "\bft[.]?\b", "fort", "all");
            s = reReplace(s, "[^a-z0-9]+", " ", "all");
            s = reReplace(s, "\s+", " ", "all");
            return trim(s);
        </cfscript>
    </cffunction>

    <cffunction name="arraySliceSafe" access="private" returntype="array" output="false">
        <cfargument name="arr" type="array" required="true">
        <cfargument name="startPos" type="numeric" required="true">
        <cfargument name="count" type="numeric" required="true">
        <cfscript>
            var out = [];
            var i = 0;
            var finish = min(arrayLen(arguments.arr), arguments.startPos + arguments.count - 1);
            if (arrayLen(arguments.arr) EQ 0 OR arguments.count LTE 0 OR arguments.startPos LTE 0) {
                return out;
            }
            for (i = arguments.startPos; i LTE finish; i++) {
                arrayAppend(out, arguments.arr[i]);
            }
            return out;
        </cfscript>
    </cffunction>

    <cffunction name="nowUtcIso" access="private" returntype="string" output="false">
        <cfscript>
            var utcNow = dateConvert("local2utc", now());
            return dateTimeFormat(utcNow, "yyyy-mm-dd") & "T" & timeFormat(utcNow, "HH:mm:ss") & "Z";
        </cfscript>
    </cffunction>

    <cffunction name="toBoolean" access="private" returntype="boolean" output="false">
        <cfargument name="value" type="any" required="true">
        <cfargument name="defaultValue" type="boolean" required="false" default="false">
        <cfscript>
            var txt = lCase(trim(toString(arguments.value)));
            if (!len(txt)) return arguments.defaultValue;
            if (listFindNoCase("1,true,yes,y,on", txt)) return true;
            if (listFindNoCase("0,false,no,n,off", txt)) return false;
            if (isNumeric(txt)) return (val(txt) NEQ 0);
            return arguments.defaultValue;
        </cfscript>
    </cffunction>

    <cffunction name="toPositiveInt" access="private" returntype="numeric" output="false">
        <cfargument name="value" type="any" required="true">
        <cfscript>
            var txt = trim(toString(arguments.value));
            if (!len(txt) OR !isNumeric(txt)) {
                return 0;
            }
            if (val(txt) LT 0) {
                return 0;
            }
            return int(val(txt));
        </cfscript>
    </cffunction>

    <cffunction name="readValue" access="private" returntype="any" output="false">
        <cfargument name="source" type="struct" required="true">
        <cfargument name="key" type="string" required="true">
        <cfargument name="defaultValue" type="any" required="false" default="">
        <cfscript>
            if (structKeyExists(arguments.source, arguments.key)) {
                return arguments.source[arguments.key];
            }
            return arguments.defaultValue;
        </cfscript>
    </cffunction>

    <cffunction name="getDatasource" access="private" returntype="string" output="false">
        <cfscript>
            if (structKeyExists(variables, "datasource") AND len(trim(variables.datasource))) {
                return variables.datasource;
            }
            if (structKeyExists(application, "dsn") AND len(trim(application.dsn))) {
                return trim(application.dsn);
            }
            return "fpw";
        </cfscript>
    </cffunction>

</cfcomponent>
