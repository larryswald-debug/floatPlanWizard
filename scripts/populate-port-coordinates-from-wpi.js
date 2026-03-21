#!/usr/bin/env node
"use strict";

const fs = require("fs");
const https = require("https");
const { execFileSync } = require("child_process");

const WPI_QUERY_URL =
  "https://vcps.nga.mil/nauticalpubs-feature/rest/services/WPI/World_Port_Index_Viewer/FeatureServer/0/query";

function parseArgs(argv) {
  const opts = {
    apply: false,
    fuzzy: false,
    noBackfill: false,
    limit: 0,
    delayMs: 120,
    names: [],
    file: "",
    reportOut: "",
    dbSchema: process.env.FPW_DB_SCHEMA || "FPW",
    mysqlContainer: process.env.FPW_MYSQL_CONTAINER || "cfdev-mysql",
    mysqlUser: process.env.FPW_MYSQL_USER || "root",
    mysqlPassword: process.env.FPW_MYSQL_PASSWORD || process.env.MYSQL_ROOT_PASSWORD || "rootpassword",
    pretty: true
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--apply") {
      opts.apply = true;
      continue;
    }
    if (arg === "--dry-run") {
      opts.apply = false;
      continue;
    }
    if (arg === "--fuzzy") {
      opts.fuzzy = true;
      continue;
    }
    if (arg === "--no-backfill") {
      opts.noBackfill = true;
      continue;
    }
    if (arg === "--name" || arg === "-n") {
      const val = argv[i + 1];
      if (!val) throw new Error("Missing value for --name");
      opts.names.push(val);
      i += 1;
      continue;
    }
    if (arg === "--file" || arg === "-f") {
      const val = argv[i + 1];
      if (!val) throw new Error("Missing value for --file");
      opts.file = val;
      i += 1;
      continue;
    }
    if (arg === "--limit" || arg === "-l") {
      const val = Number(argv[i + 1]);
      if (!Number.isFinite(val) || val < 0) throw new Error("Invalid value for --limit");
      opts.limit = Math.floor(val);
      i += 1;
      continue;
    }
    if (arg === "--delay-ms") {
      const val = Number(argv[i + 1]);
      if (!Number.isFinite(val) || val < 0) throw new Error("Invalid value for --delay-ms");
      opts.delayMs = Math.floor(val);
      i += 1;
      continue;
    }
    if (arg === "--db-schema") {
      const val = argv[i + 1];
      if (!val) throw new Error("Missing value for --db-schema");
      opts.dbSchema = val;
      i += 1;
      continue;
    }
    if (arg === "--mysql-container") {
      const val = argv[i + 1];
      if (!val) throw new Error("Missing value for --mysql-container");
      opts.mysqlContainer = val;
      i += 1;
      continue;
    }
    if (arg === "--mysql-user") {
      const val = argv[i + 1];
      if (!val) throw new Error("Missing value for --mysql-user");
      opts.mysqlUser = val;
      i += 1;
      continue;
    }
    if (arg === "--mysql-password") {
      const val = argv[i + 1];
      if (!val) throw new Error("Missing value for --mysql-password");
      opts.mysqlPassword = val;
      i += 1;
      continue;
    }
    if (arg === "--report-out" || arg === "-o") {
      const val = argv[i + 1];
      if (!val) throw new Error("Missing value for --report-out");
      opts.reportOut = val;
      i += 1;
      continue;
    }
    if (arg === "--compact") {
      opts.pretty = false;
      continue;
    }
    if (arg === "--help" || arg === "-h") {
      opts.help = true;
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }
  return opts;
}

function usage() {
  return [
    "Populate FPW port coordinates from NGA WPI API.",
    "",
    "Default mode is DRY RUN (no DB writes).",
    "",
    "Examples:",
    "  node scripts/populate-port-coordinates-from-wpi.js",
    "  node scripts/populate-port-coordinates-from-wpi.js --apply",
    "  node scripts/populate-port-coordinates-from-wpi.js --name \"Chicago\" --name \"Mobile\" --apply",
    "  node scripts/populate-port-coordinates-from-wpi.js --file /tmp/ports.txt --fuzzy --apply",
    "",
    "Options:",
    "  --apply                  Write updates to DB (default is dry-run)",
    "  --dry-run                Force dry-run",
    "  --fuzzy                  Allow conservative fallback matching strategies",
    "  --no-backfill            Skip loop_segments backfill step after ports update",
    "  --name, -n               Port name filter (repeatable)",
    "  --file, -f               File with one port name per line",
    "  --limit, -l              Max ports to process (0 = all)",
    "  --delay-ms               Delay between API calls (default 120)",
    "  --db-schema              DB schema (default FPW)",
    "  --mysql-container        Docker MySQL container (default cfdev-mysql)",
    "  --mysql-user             MySQL user (default root)",
    "  --mysql-password         MySQL password (default rootpassword)",
    "  --report-out, -o         Write JSON report to file",
    "  --compact                Compact JSON output",
    "  --help, -h               Show help"
  ].join("\n");
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function readNamesFromFile(filePath) {
  const raw = fs.readFileSync(filePath, "utf8");
  return raw
    .split(/\r?\n/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0 && !s.startsWith("#"));
}

function sqlString(value) {
  return `'${String(value).replace(/'/g, "''")}'`;
}

function sqlNum(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) throw new Error(`Invalid numeric value: ${value}`);
  return n.toFixed(7);
}

function normalizeName(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/\bst[.]?\b/g, "saint")
    .replace(/\bft[.]?\b/g, "fort")
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function strictKey(value) {
  return normalizeName(value).replace(/\s+/g, "");
}

function buildVariants(value) {
  const raw = String(value || "").trim();
  const variants = new Set([raw]);
  raw
    .split(/[\/,]/)
    .map((s) => s.trim())
    .filter((s) => s.length >= 3)
    .forEach((s) => variants.add(s));
  return Array.from(variants).filter(Boolean);
}

function buildWhereEquals(name) {
  const clean = String(name || "").trim().replace(/'/g, "''").toUpperCase();
  return `UPPER(main_port_name) = '${clean}'`;
}

function buildWhereLike(name) {
  const clean = String(name || "").trim().replace(/'/g, "''").toUpperCase();
  return `UPPER(main_port_name) LIKE '%${clean}%'`;
}

function requestJson(url, insecureTls) {
  return new Promise((resolve, reject) => {
    const req = https.request(
      url,
      {
        method: "GET",
        headers: { Accept: "application/json" },
        rejectUnauthorized: !insecureTls
      },
      (res) => {
        let body = "";
        res.setEncoding("utf8");
        res.on("data", (chunk) => {
          body += chunk;
        });
        res.on("end", () => {
          if (res.statusCode < 200 || res.statusCode >= 300) {
            return reject(new Error(`HTTP ${res.statusCode}: ${body.slice(0, 250)}`));
          }
          try {
            resolve(JSON.parse(body));
          } catch (err) {
            reject(new Error(`Invalid JSON response: ${err.message}`));
          }
        });
      }
    );
    req.on("error", reject);
    req.end();
  });
}

async function requestJsonWithTlsFallback(url) {
  try {
    return { payload: await requestJson(url, false), usedInsecureTls: false };
  } catch (err) {
    const msg = String(err && err.message ? err.message : err);
    const certIssue =
      msg.includes("self signed certificate") ||
      msg.includes("unable to verify the first certificate") ||
      msg.includes("certificate");
    if (!certIssue) throw err;
    return { payload: await requestJson(url, true), usedInsecureTls: true };
  }
}

async function queryWpi(where, resultLimit) {
  const params = new URLSearchParams({
    where,
    outFields: "wpinumber,main_port_name,unlocode",
    returnGeometry: "true",
    orderByFields: "main_port_name ASC",
    resultRecordCount: String(resultLimit),
    f: "json"
  });
  const url = `${WPI_QUERY_URL}?${params.toString()}`;
  const { payload, usedInsecureTls } = await requestJsonWithTlsFallback(url);
  if (payload && payload.error) {
    throw new Error(`WPI API error: ${JSON.stringify(payload.error)}`);
  }
  const features = Array.isArray(payload && payload.features) ? payload.features : [];
  const matches = features.map((f) => {
    const attrs = f && f.attributes ? f.attributes : {};
    const geom = f && f.geometry ? f.geometry : {};
    return {
      main_port_name: attrs.main_port_name || "",
      wpinumber: attrs.wpinumber == null ? null : Number(attrs.wpinumber),
      unlocode: attrs.unlocode || null,
      lat: geom.y == null ? null : Number(geom.y),
      lng: geom.x == null ? null : Number(geom.x)
    };
  });
  return { matches, usedInsecureTls };
}

function isTransientNetError(err) {
  const msg = String(err && err.message ? err.message : err).toLowerCase();
  return (
    msg.includes("econnreset") ||
    msg.includes("etimedout") ||
    msg.includes("eai_again") ||
    msg.includes("socket hang up") ||
    msg.includes("http 502") ||
    msg.includes("http 503") ||
    msg.includes("http 504")
  );
}

async function queryWpiWithRetry(where, resultLimit, maxAttempts) {
  let lastErr = null;
  const attempts = Math.max(1, maxAttempts || 3);
  for (let i = 1; i <= attempts; i += 1) {
    try {
      return await queryWpi(where, resultLimit);
    } catch (err) {
      lastErr = err;
      if (!isTransientNetError(err) || i >= attempts) {
        throw err;
      }
      await sleep(i * 450);
    }
  }
  throw lastErr || new Error("Unknown WPI query failure");
}

function chooseSingleMatch(inputName, matches) {
  if (!matches.length) return { match: null, strategy: "" };
  if (matches.length === 1) return { match: matches[0], strategy: "single-result" };

  const inputKey = strictKey(inputName);
  const strict = matches.filter((m) => strictKey(m.main_port_name) === inputKey);
  if (strict.length === 1) return { match: strict[0], strategy: "strict-normalized" };

  return { match: null, strategy: "" };
}

function mysqlExec(sql, opts) {
  const args = [
    "exec",
    "-e",
    `MYSQL_PWD=${opts.mysqlPassword}`,
    opts.mysqlContainer,
    "mysql",
    `-u${opts.mysqlUser}`,
    "-N",
    "-B",
    "-D",
    opts.dbSchema,
    "-e",
    sql
  ];
  return execFileSync("docker", args, { encoding: "utf8" }).trim();
}

function mysqlRows(sql, opts) {
  const out = mysqlExec(sql, opts);
  if (!out) return [];
  return out
    .split(/\r?\n/)
    .filter(Boolean)
    .map((line) => line.split("\t"));
}

function getMissingPorts(opts, requestedNames) {
  let sql = `
    SELECT id, name, lat, lng
    FROM ports
    WHERE (lat IS NULL OR lng IS NULL)
      AND name IS NOT NULL
      AND LENGTH(TRIM(name)) > 0
  `;
  if (requestedNames.length) {
    const names = requestedNames.map((n) => sqlString(n.trim().toUpperCase())).join(",");
    sql += ` AND UPPER(TRIM(name)) IN (${names}) `;
  }
  sql += " ORDER BY id ASC ";
  if (opts.limit > 0) {
    sql += ` LIMIT ${opts.limit} `;
  }
  return mysqlRows(sql, opts).map((r) => ({
    id: Number(r[0]),
    name: r[1] || "",
    lat: r[2] ? Number(r[2]) : null,
    lng: r[3] ? Number(r[3]) : null
  }));
}

function getEndpointMissingCounts(opts) {
  const rows = mysqlRows(
    `
    SELECT
      SUM(CASE WHEN start_lat IS NULL OR start_lng IS NULL THEN 1 ELSE 0 END) AS missing_start,
      SUM(CASE WHEN end_lat IS NULL OR end_lng IS NULL THEN 1 ELSE 0 END) AS missing_end,
      SUM(CASE WHEN start_lat IS NULL OR start_lng IS NULL OR end_lat IS NULL OR end_lng IS NULL THEN 1 ELSE 0 END) AS missing_any
    FROM loop_segments
    `,
    opts
  );
  const first = rows[0] || ["0", "0", "0"];
  return {
    missingStart: Number(first[0] || 0),
    missingEnd: Number(first[1] || 0),
    missingAny: Number(first[2] || 0)
  };
}

function applyPortUpdates(updates, opts) {
  let updated = 0;
  for (const u of updates) {
    const sql = `
      UPDATE ports
      SET lat = ${sqlNum(u.lat)}, lng = ${sqlNum(u.lng)}
      WHERE id = ${Number(u.port_id)}
        AND (lat IS NULL OR lng IS NULL)
    `;
    mysqlExec(sql, opts);
    updated += 1;
  }
  return updated;
}

function backfillLoopSegments(opts) {
  const before = getEndpointMissingCounts(opts);

  mysqlExec(
    `
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
    `,
    opts
  );

  mysqlExec(
    `
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
    `,
    opts
  );

  const after = getEndpointMissingCounts(opts);
  return {
    before,
    after,
    improvedStart: Math.max(0, before.missingStart - after.missingStart),
    improvedEnd: Math.max(0, before.missingEnd - after.missingEnd),
    improvedAny: Math.max(0, before.missingAny - after.missingAny)
  };
}

async function resolvePort(name, opts) {
  const attempts = [];
  let usedInsecureTls = false;

  const exactWhere = buildWhereEquals(name);
  const exactRes = await queryWpiWithRetry(exactWhere, 10, 3);
  usedInsecureTls = usedInsecureTls || exactRes.usedInsecureTls;
  attempts.push({ mode: "exact", where: exactWhere, count: exactRes.matches.length });
  let pick = chooseSingleMatch(name, exactRes.matches);
  if (pick.match) {
    return {
      matched: true,
      strategy: `exact/${pick.strategy}`,
      match: pick.match,
      attempts,
      usedInsecureTls
    };
  }

  const likeWhere = buildWhereLike(name);
  const likeRes = await queryWpiWithRetry(likeWhere, 20, 3);
  usedInsecureTls = usedInsecureTls || likeRes.usedInsecureTls;
  attempts.push({ mode: "like", where: likeWhere, count: likeRes.matches.length });
  pick = chooseSingleMatch(name, likeRes.matches);
  if (pick.match) {
    return {
      matched: true,
      strategy: `like/${pick.strategy}`,
      match: pick.match,
      attempts,
      usedInsecureTls
    };
  }

  if (opts.fuzzy) {
    const tokenResults = [];
    const variants = buildVariants(name).filter((v) => v !== name);
    for (const variant of variants) {
      const where = buildWhereEquals(variant);
      const res = await queryWpiWithRetry(where, 10, 3);
      usedInsecureTls = usedInsecureTls || res.usedInsecureTls;
      attempts.push({ mode: `token-exact:${variant}`, where, count: res.matches.length });
      if (res.matches.length === 1) {
        tokenResults.push({ variant, match: res.matches[0] });
      }
      if (opts.delayMs > 0) {
        await sleep(opts.delayMs);
      }
    }
    if (tokenResults.length === 1) {
      return {
        matched: true,
        strategy: `fuzzy/token-exact:${tokenResults[0].variant}`,
        match: tokenResults[0].match,
        attempts,
        usedInsecureTls
      };
    }
  }

  return {
    matched: false,
    strategy: "",
    match: null,
    attempts,
    usedInsecureTls
  };
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.help) {
    process.stdout.write(`${usage()}\n`);
    return;
  }

  let requestedNames = opts.names.slice();
  if (opts.file) {
    requestedNames = requestedNames.concat(readNamesFromFile(opts.file));
  }
  requestedNames = Array.from(
    new Set(
      requestedNames
        .map((s) => String(s || "").trim())
        .filter(Boolean)
    )
  );

  const ports = getMissingPorts(opts, requestedNames);
  const updates = [];
  const unresolved = [];
  const errored = [];
  let tlsFallbackUsed = false;

  for (let i = 0; i < ports.length; i += 1) {
    const port = ports[i];
    try {
      const resolved = await resolvePort(port.name, opts);
      tlsFallbackUsed = tlsFallbackUsed || resolved.usedInsecureTls;
      if (!resolved.matched || !resolved.match || !Number.isFinite(resolved.match.lat) || !Number.isFinite(resolved.match.lng)) {
        unresolved.push({
          port_id: port.id,
          port_name: port.name,
          attempts: resolved.attempts
        });
      } else {
        updates.push({
          port_id: port.id,
          port_name: port.name,
          lat: resolved.match.lat,
          lng: resolved.match.lng,
          matched_port_name: resolved.match.main_port_name,
          unlocode: resolved.match.unlocode,
          wpinumber: resolved.match.wpinumber,
          strategy: resolved.strategy
        });
      }
    } catch (err) {
      errored.push({
        port_id: port.id,
        port_name: port.name,
        error: String(err && err.message ? err.message : err)
      });
    }

    if (opts.delayMs > 0) {
      await sleep(opts.delayMs);
    }
  }

  let appliedPortUpdates = 0;
  let backfillResult = null;
  if (opts.apply) {
    appliedPortUpdates = applyPortUpdates(updates, opts);
    if (!opts.noBackfill) {
      backfillResult = backfillLoopSegments(opts);
    }
  } else if (!opts.noBackfill) {
    // In dry-run include current baseline only.
    const baseline = getEndpointMissingCounts(opts);
    backfillResult = {
      before: baseline,
      after: baseline,
      improvedStart: 0,
      improvedEnd: 0,
      improvedAny: 0,
      note: "Dry-run; no DB writes."
    };
  }

  const summary = {
    mode: opts.apply ? "apply" : "dry-run",
    fuzzy_matching: opts.fuzzy,
    mysql: {
      container: opts.mysqlContainer,
      schema: opts.dbSchema,
      user: opts.mysqlUser
    },
    queried_at_utc: new Date().toISOString(),
    total_ports_scanned: ports.length,
    matched_updates_ready: updates.length,
    unresolved_count: unresolved.length,
    error_count: errored.length,
    tls_note: tlsFallbackUsed ? "Used insecure TLS fallback for NGA certificate chain." : "",
    applied_port_updates: appliedPortUpdates,
    backfill: backfillResult,
    sample_updates: updates.slice(0, 30),
    unresolved: unresolved.slice(0, 80),
    errors: errored
  };

  const out = JSON.stringify(summary, null, opts.pretty ? 2 : 0);
  if (opts.reportOut) {
    fs.writeFileSync(opts.reportOut, out);
    process.stdout.write(`Wrote report: ${opts.reportOut}\n`);
  }
  process.stdout.write(`${out}\n`);
}

main().catch((err) => {
  process.stderr.write(`ERROR: ${err.message}\n`);
  process.stderr.write(`${usage()}\n`);
  process.exit(1);
});
