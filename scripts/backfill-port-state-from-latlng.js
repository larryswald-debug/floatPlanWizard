#!/usr/bin/env node
"use strict";

const fs = require("fs");
const https = require("https");
const { execFileSync } = require("child_process");

const NOMINATIM_REVERSE_URL = "https://nominatim.openstreetmap.org/reverse";
const USER_AGENT = "FloatPlanWizard-StateBackfill/1.0";

function parseArgs(argv) {
  const opts = {
    apply: false,
    limit: 0,
    delayMs: 200,
    portId: 0,
    reportOut: "/tmp/fpw-port-state-backfill.json",
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
    if (arg === "--port-id") {
      const val = Number(argv[i + 1]);
      if (!Number.isFinite(val) || val <= 0) throw new Error("Invalid value for --port-id");
      opts.portId = Math.floor(val);
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
    "Backfill FPW ports.state from existing ports.lat/lng using Nominatim reverse geocoding.",
    "",
    "Default mode is DRY RUN (no DB writes).",
    "",
    "Examples:",
    "  node scripts/backfill-port-state-from-latlng.js",
    "  node scripts/backfill-port-state-from-latlng.js --apply",
    "  node scripts/backfill-port-state-from-latlng.js --apply --limit 50",
    "  node scripts/backfill-port-state-from-latlng.js --port-id 123 --apply",
    "",
    "Options:",
    "  --apply                  Write state updates to DB (default is dry-run)",
    "  --dry-run                Force dry-run mode",
    "  --limit, -l              Max ports to process (0 = all)",
    "  --delay-ms               Delay between API calls (default 200)",
    "  --port-id                Process a single port id",
    "  --db-schema              DB schema (default FPW)",
    "  --mysql-container        Docker MySQL container (default cfdev-mysql)",
    "  --mysql-user             MySQL user (default root)",
    "  --mysql-password         MySQL password (default rootpassword)",
    "  --report-out, -o         Write JSON report file (default /tmp/fpw-port-state-backfill.json)",
    "  --compact                Compact JSON output",
    "  --help, -h               Show help"
  ].join("\n");
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function sqlString(value) {
  return `'${String(value).replace(/'/g, "''")}'`;
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

function getCandidatePorts(opts) {
  let sql = `
    SELECT id, name, lat, lng, state
    FROM ports
    WHERE (state IS NULL OR LENGTH(TRIM(state)) = 0)
      AND lat IS NOT NULL
      AND lng IS NOT NULL
  `;
  if (opts.portId > 0) {
    sql += ` AND id = ${opts.portId} `;
  }
  sql += " ORDER BY id ASC ";
  if (opts.limit > 0) {
    sql += ` LIMIT ${opts.limit} `;
  }

  return mysqlRows(sql, opts).map((r) => ({
    id: Number(r[0]),
    name: r[1] || "",
    lat: r[2] == null ? null : Number(r[2]),
    lng: r[3] == null ? null : Number(r[3]),
    state: r[4] || ""
  }));
}

function applyStateUpdate(portId, stateName, opts) {
  const sql = `
    UPDATE ports
    SET state = ${sqlString(stateName)}
    WHERE id = ${Number(portId)}
      AND (state IS NULL OR LENGTH(TRIM(state)) = 0)
  `;
  mysqlExec(sql, opts);
}

function requestJson(url, insecureTls) {
  return new Promise((resolve, reject) => {
    const req = https.request(
      url,
      {
        method: "GET",
        headers: {
          Accept: "application/json",
          "User-Agent": USER_AGENT
        },
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
    const msg = String(err && err.message ? err.message : err).toLowerCase();
    const certIssue =
      msg.includes("self signed certificate") ||
      msg.includes("unable to verify the first certificate") ||
      msg.includes("certificate");
    if (!certIssue) throw err;
    return { payload: await requestJson(url, true), usedInsecureTls: true };
  }
}

function isTransientNetError(err) {
  const msg = String(err && err.message ? err.message : err).toLowerCase();
  return (
    msg.includes("econnreset") ||
    msg.includes("etimedout") ||
    msg.includes("eai_again") ||
    msg.includes("socket hang up") ||
    msg.includes("http 429") ||
    msg.includes("http 502") ||
    msg.includes("http 503") ||
    msg.includes("http 504")
  );
}

async function reverseGeocode(lat, lng) {
  const params = new URLSearchParams({
    format: "jsonv2",
    addressdetails: "1",
    lat: String(lat),
    lon: String(lng)
  });
  const url = `${NOMINATIM_REVERSE_URL}?${params.toString()}`;
  return requestJsonWithTlsFallback(url);
}

async function reverseGeocodeWithRetry(lat, lng, maxAttempts) {
  const attempts = Math.max(1, maxAttempts || 3);
  let lastErr = null;
  for (let i = 1; i <= attempts; i += 1) {
    try {
      return await reverseGeocode(lat, lng);
    } catch (err) {
      lastErr = err;
      if (!isTransientNetError(err) || i >= attempts) {
        throw err;
      }
      await sleep(i * 500);
    }
  }
  throw lastErr || new Error("Reverse geocode failed.");
}

function deriveStateFromDisplayName(payload) {
  const displayName = String((payload && payload.display_name) || "").trim();
  if (!displayName) return "";
  const parts = displayName
    .split(",")
    .map((s) => String(s || "").trim())
    .filter(Boolean);
  if (parts.length < 2) return "";

  const last = String(parts[parts.length - 1] || "").toLowerCase();
  if (last === "united states" || last === "united states of america" || last === "usa" || last === "us") {
    return parts[parts.length - 2] || "";
  }
  return "";
}

function deriveState(payload) {
  const address = (payload && payload.address) || {};
  const keys = ["state", "region", "state_district"];
  for (const key of keys) {
    const value = String(address[key] || "").trim();
    if (value) return value;
  }
  return deriveStateFromDisplayName(payload);
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.help) {
    process.stdout.write(`${usage()}\n`);
    return;
  }

  const candidates = getCandidatePorts(opts);
  const report = {
    SUCCESS: true,
    mode: opts.apply ? "apply" : "dry-run",
    queried_at_utc: new Date().toISOString(),
    datasource: opts.dbSchema,
    total_candidates: candidates.length,
    processed: 0,
    matched_updates_ready: 0,
    applied_updates: 0,
    unresolved_count: 0,
    error_count: 0,
    used_insecure_tls_count: 0,
    sample_updates: [],
    unresolved: [],
    errors: []
  };

  for (let i = 0; i < candidates.length; i += 1) {
    const port = candidates[i];
    report.processed += 1;
    try {
      const { payload, usedInsecureTls } = await reverseGeocodeWithRetry(port.lat, port.lng, 3);
      if (usedInsecureTls) {
        report.used_insecure_tls_count += 1;
      }

      const resolvedState = deriveState(payload);
      if (!resolvedState) {
        report.unresolved_count += 1;
        if (report.unresolved.length < 100) {
          report.unresolved.push({
            port_id: port.id,
            port_name: port.name,
            lat: port.lat,
            lng: port.lng,
            reason: "No state in reverse geocode response."
          });
        }
      } else {
        report.matched_updates_ready += 1;
        if (opts.apply) {
          applyStateUpdate(port.id, resolvedState, opts);
          report.applied_updates += 1;
        }
        if (report.sample_updates.length < 100) {
          report.sample_updates.push({
            port_id: port.id,
            port_name: port.name,
            lat: port.lat,
            lng: port.lng,
            state: resolvedState,
            source: String((payload && payload.display_name) || "")
          });
        }
      }
    } catch (err) {
      report.error_count += 1;
      if (report.errors.length < 100) {
        report.errors.push({
          port_id: port.id,
          port_name: port.name,
          lat: port.lat,
          lng: port.lng,
          error: String(err && err.message ? err.message : err)
        });
      }
    }

    if (opts.delayMs > 0 && i < candidates.length - 1) {
      await sleep(opts.delayMs);
    }
  }

  if (opts.reportOut) {
    fs.writeFileSync(opts.reportOut, `${JSON.stringify(report, null, opts.pretty ? 2 : 0)}\n`, "utf8");
    report.report_written = opts.reportOut;
  }

  process.stdout.write(`${JSON.stringify(report, null, opts.pretty ? 2 : 0)}\n`);
}

main().catch((err) => {
  const out = {
    SUCCESS: false,
    MESSAGE: "Backfill failed",
    ERROR: String(err && err.message ? err.message : err)
  };
  process.stderr.write(`${JSON.stringify(out)}\n`);
  process.exit(1);
});

