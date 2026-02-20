<cfcomponent output="false" hint="Backfill missing ports.state from existing ports lat/lng using reverse geocoding.">

    <cfset variables.NOMINATIM_REVERSE_URL = "https://nominatim.openstreetmap.org/reverse">
    <cfset variables.DEFAULT_REPORT_PATH = "/tmp/fpw-port-state-backfill.json">
    <cfset variables.USER_AGENT = "FPW-PortStateBackfill/1.0">

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

    <cffunction name="run" access="public" returntype="struct" output="false" hint="Dry-run by default. Set options.apply=true to write state updates.">
        <cfargument name="options" type="struct" required="false" default="#structNew()#">
        <cfscript>
            var opts = normalizeOptions(arguments.options);
            var ports = getCandidatePorts(opts);
            var sampleUpdates = [];
            var unresolved = [];
            var errors = [];
            var processed = 0;
            var matchedReady = 0;
            var appliedCount = 0;
            var usedInsecureTlsCount = 0;
            var i = 0;
            var port = {};
            var resolved = {};
            var summary = {};
            var reportJson = "";

            for (i = 1; i LTE arrayLen(ports); i++) {
                port = ports[i];
                processed += 1;

                try {
                    resolved = resolveStateForPort(port, opts);
                    if (structKeyExists(resolved, "usedInsecureTls") AND resolved.usedInsecureTls) {
                        usedInsecureTlsCount += 1;
                    }

                    if (resolved.matched) {
                        matchedReady += 1;
                        if (opts.apply) {
                            applyStateUpdate(port.id, resolved.state);
                            appliedCount += 1;
                        }
                        if (arrayLen(sampleUpdates) LT 100) {
                            arrayAppend(sampleUpdates, {
                                "port_id" = port.id,
                                "port_name" = port.name,
                                "lat" = port.lat,
                                "lng" = port.lng,
                                "state" = resolved.state,
                                "source" = (structKeyExists(resolved, "source") ? resolved.source : "")
                            });
                        }
                    } else {
                        if (arrayLen(unresolved) LT 100) {
                            arrayAppend(unresolved, {
                                "port_id" = port.id,
                                "port_name" = port.name,
                                "lat" = port.lat,
                                "lng" = port.lng,
                                "reason" = (structKeyExists(resolved, "reason") ? resolved.reason : "No state in reverse geocode response.")
                            });
                        }
                    }
                } catch (any eResolve) {
                    if (arrayLen(errors) LT 100) {
                        arrayAppend(errors, {
                            "port_id" = port.id,
                            "port_name" = port.name,
                            "lat" = port.lat,
                            "lng" = port.lng,
                            "error" = toString(eResolve.message)
                        });
                    }
                }

                if (opts.delayMs GT 0 AND i LT arrayLen(ports)) {
                    sleep(opts.delayMs);
                }
            }

            summary = {
                "SUCCESS" = true,
                "mode" = (opts.apply ? "apply" : "dry-run"),
                "queried_at_utc" = nowUtcIso(),
                "datasource" = getDatasource(),
                "total_candidates" = arrayLen(ports),
                "processed" = processed,
                "matched_updates_ready" = matchedReady,
                "applied_updates" = appliedCount,
                "unresolved_count" = arrayLen(unresolved),
                "error_count" = arrayLen(errors),
                "used_insecure_tls_count" = usedInsecureTlsCount,
                "sample_updates" = sampleUpdates,
                "unresolved" = unresolved,
                "errors" = errors
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
                "limit" = toPositiveInt(readValue(arguments.raw, "limit", 0)),
                "delayMs" = toPositiveInt(readValue(arguments.raw, "delayMs", 200)),
                "portId" = toPositiveInt(readValue(arguments.raw, "portId", 0)),
                "reportOutPath" = trim(toString(readValue(arguments.raw, "reportOutPath", variables.DEFAULT_REPORT_PATH)))
            };

            if (opts.delayMs GT 5000) {
                opts.delayMs = 5000;
            }

            return opts;
        </cfscript>
    </cffunction>

    <cffunction name="getCandidatePorts" access="private" returntype="array" output="false">
        <cfargument name="opts" type="struct" required="true">
        <cfscript>
            var sql = "
                SELECT id, name, state, lat, lng
                FROM ports
                WHERE (state IS NULL OR LENGTH(TRIM(state)) = 0)
                  AND lat IS NOT NULL
                  AND lng IS NOT NULL
            ";
            var binds = {};
            var q = queryNew("");
            var out = [];
            var i = 0;

            if (arguments.opts.portId GT 0) {
                sql &= " AND id = :portId ";
                binds.portId = { value = arguments.opts.portId, cfsqltype = "cf_sql_integer" };
            }

            sql &= " ORDER BY id ASC ";
            if (arguments.opts.limit GT 0) {
                sql &= " LIMIT " & arguments.opts.limit;
            }

            q = queryExecute(sql, binds, { datasource = getDatasource() });

            for (i = 1; i LTE q.recordCount; i++) {
                arrayAppend(out, {
                    "id" = val(q.id[i]),
                    "name" = (isNull(q.name[i]) ? "" : toString(q.name[i])),
                    "state" = (isNull(q.state[i]) ? "" : toString(q.state[i])),
                    "lat" = (isNull(q.lat[i]) ? javacast("null", "") : val(q.lat[i])),
                    "lng" = (isNull(q.lng[i]) ? javacast("null", "") : val(q.lng[i]))
                });
            }

            return out;
        </cfscript>
    </cffunction>

    <cffunction name="applyStateUpdate" access="private" returntype="void" output="false">
        <cfargument name="portId" type="numeric" required="true">
        <cfargument name="stateName" type="string" required="true">
        <cfscript>
            queryExecute(
                "
                UPDATE ports
                SET state = :stateVal
                WHERE id = :portId
                  AND (state IS NULL OR LENGTH(TRIM(state)) = 0)
                ",
                {
                    stateVal = { value = trim(arguments.stateName), cfsqltype = "cf_sql_varchar" },
                    portId = { value = int(arguments.portId), cfsqltype = "cf_sql_integer" }
                },
                { datasource = getDatasource() }
            );
        </cfscript>
    </cffunction>

    <cffunction name="resolveStateForPort" access="private" returntype="struct" output="false">
        <cfargument name="port" type="struct" required="true">
        <cfargument name="opts" type="struct" required="true">
        <cfscript>
            var response = reverseGeocodeWithRetry(arguments.port.lat, arguments.port.lng, 3);
            var payload = (structKeyExists(response, "payload") AND isStruct(response.payload) ? response.payload : {});
            var stateVal = deriveStateFromPayload(payload);

            return {
                "matched" = len(trim(stateVal)) GT 0,
                "state" = trim(stateVal),
                "source" = (structKeyExists(payload, "display_name") ? toString(payload.display_name) : ""),
                "reason" = (len(trim(stateVal)) ? "" : "No state in reverse geocode response."),
                "usedInsecureTls" = (structKeyExists(response, "usedInsecureTls") ? response.usedInsecureTls : false)
            };
        </cfscript>
    </cffunction>

    <cffunction name="reverseGeocodeWithRetry" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfargument name="maxAttempts" type="numeric" required="false" default="3">
        <cfscript>
            var attempt = 0;
            var maxTry = (arguments.maxAttempts LTE 0 ? 1 : int(arguments.maxAttempts));
            var out = {};

            for (attempt = 1; attempt LTE maxTry; attempt++) {
                try {
                    out = reverseGeocode(arguments.lat, arguments.lng);
                    return out;
                } catch (any e) {
                    if (!isTransientError(e) OR attempt GTE maxTry) {
                        rethrow;
                    }
                    sleep(attempt * 500);
                }
            }

            return { "payload" = {}, "usedInsecureTls" = false };
        </cfscript>
    </cffunction>

    <cffunction name="reverseGeocode" access="private" returntype="struct" output="false">
        <cfargument name="lat" type="numeric" required="true">
        <cfargument name="lng" type="numeric" required="true">
        <cfscript>
            var url = variables.NOMINATIM_REVERSE_URL
                & "?format=jsonv2"
                & "&addressdetails=1"
                & "&lat=" & urlEncodedFormat(toString(arguments.lat))
                & "&lon=" & urlEncodedFormat(toString(arguments.lng));
            return requestJson(url);
        </cfscript>
    </cffunction>

    <cffunction name="deriveStateFromPayload" access="private" returntype="string" output="false">
        <cfargument name="payload" type="struct" required="true">
        <cfscript>
            var address = (structKeyExists(arguments.payload, "address") AND isStruct(arguments.payload.address) ? arguments.payload.address : {});
            var stateVal = trim(toString(readValue(address, "state", "")));

            if (!len(stateVal)) {
                stateVal = trim(toString(readValue(address, "region", "")));
            }
            if (!len(stateVal)) {
                stateVal = trim(toString(readValue(address, "state_district", "")));
            }
            if (!len(stateVal)) {
                stateVal = deriveStateFromDisplayName(readValue(arguments.payload, "display_name", ""));
            }

            return trim(stateVal);
        </cfscript>
    </cffunction>

    <cffunction name="deriveStateFromDisplayName" access="private" returntype="string" output="false">
        <cfargument name="displayName" type="string" required="true">
        <cfscript>
            var parts = [];
            var cleaned = trim(arguments.displayName);
            var lastPart = "";
            if (!len(cleaned)) {
                return "";
            }

            parts = listToArray(cleaned, ",");
            if (arrayLen(parts) LT 2) {
                return "";
            }

            lastPart = lCase(trim(parts[arrayLen(parts)]));
            if (listFindNoCase("united states,united states of america,usa,us", lastPart)) {
                return trim(parts[arrayLen(parts) - 1]);
            }

            return "";
        </cfscript>
    </cffunction>

    <cffunction name="requestJson" access="private" returntype="struct" output="false">
        <cfargument name="url" type="string" required="true">
        <cfscript>
            var primaryErr = "";
            var payload = {};

            try {
                payload = requestJsonByCfhttp(arguments.url);
                return { "payload" = payload, "usedInsecureTls" = false };
            } catch (any ePrimary) {
                primaryErr = buildErrorMessage(ePrimary);
                if (!shouldUseInsecureFallback(primaryErr)) {
                    rethrow;
                }
            }

            try {
                payload = requestJsonByApacheTrustAll(arguments.url);
                return { "payload" = payload, "usedInsecureTls" = true };
            } catch (any eFallback) {
                throw(message = "Reverse geocode request failed (cfhttp + insecure fallback). Primary: " & primaryErr & " | Fallback: " & buildErrorMessage(eFallback));
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
                cfhttpparam(type="header", name="User-Agent", value=variables.USER_AGENT);
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
            requestObj.setHeader("User-Agent", variables.USER_AGENT);

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
        <cfscript>
            var msg = lCase(trim(arguments.errMsg));
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
                OR findNoCase("http 429", msg) GT 0
                OR findNoCase("http 502", msg) GT 0
                OR findNoCase("http 503", msg) GT 0
                OR findNoCase("http 504", msg) GT 0
                OR findNoCase("connection reset", msg) GT 0
            );
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
