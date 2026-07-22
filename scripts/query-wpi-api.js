#!/usr/bin/env node
"use strict";

const fs = require("fs");
const https = require("https");

const WPI_QUERY_URL =
  "https://vcps.nga.mil/nauticalpubs-feature/rest/services/WPI/World_Port_Index_Viewer/FeatureServer/0/query";

function parseArgs(argv) {
  const opts = {
    names: [],
    file: "",
    exact: false,
    limit: 5,
    out: "",
    pretty: true
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
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
      if (!Number.isFinite(val) || val <= 0) throw new Error("Invalid value for --limit");
      opts.limit = Math.floor(val);
      i += 1;
      continue;
    }
    if (arg === "--exact") {
      opts.exact = true;
      continue;
    }
    if (arg === "--out" || arg === "-o") {
      const val = argv[i + 1];
      if (!val) throw new Error("Missing value for --out");
      opts.out = val;
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
    "Query NGA World Port Index (WPI) API for port coordinates.",
    "",
    "Usage:",
    "  node scripts/query-wpi-api.js --name \"Chicago\"",
    "  node scripts/query-wpi-api.js --name \"Chicago\" --name \"Mobile\" --limit 3",
    "  node scripts/query-wpi-api.js --file /tmp/ports.txt --out /tmp/wpi-results.json",
    "  node scripts/query-wpi-api.js --name \"Cedar Key\" --exact",
    "",
    "Options:",
    "  --name, -n     Port name to search (repeatable)",
    "  --file, -f     Text file with one port name per line",
    "  --limit, -l    Max matches per name (default: 5)",
    "  --exact        Exact name match instead of LIKE",
    "  --out, -o      Write JSON output to file",
    "  --compact      Emit compact JSON",
    "  --help, -h     Show this help"
  ].join("\n");
}

function readNamesFromFile(filePath) {
  const raw = fs.readFileSync(filePath, "utf8");
  return raw
    .split(/\r?\n/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0 && !s.startsWith("#"));
}

function escapeSqlLikeLiteral(value) {
  return String(value || "")
    .trim()
    .replace(/'/g, "''")
    .toUpperCase();
}

function buildWhereClause(name, exact) {
  const clean = escapeSqlLikeLiteral(name);
  if (!clean) throw new Error("Empty port name");
  if (exact) {
    return `UPPER(main_port_name) = '${clean}'`;
  }
  return `UPPER(main_port_name) LIKE '%${clean}%'`;
}

function requestJson(url, insecure) {
  return new Promise((resolve, reject) => {
    const req = https.request(
      url,
      {
        method: "GET",
        headers: { Accept: "application/json" },
        rejectUnauthorized: !insecure
      },
      (res) => {
        let body = "";
        res.setEncoding("utf8");
        res.on("data", (chunk) => {
          body += chunk;
        });
        res.on("end", () => {
          if (res.statusCode < 200 || res.statusCode >= 300) {
            return reject(new Error(`HTTP ${res.statusCode}: ${body.slice(0, 300)}`));
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

async function requestJsonWithFallback(url) {
  try {
    return {
      payload: await requestJson(url, false),
      usedInsecureTls: false
    };
  } catch (err) {
    const msg = String(err && err.message ? err.message : err);
    const isCertErr =
      msg.includes("self signed certificate") ||
      msg.includes("unable to verify the first certificate") ||
      msg.includes("certificate");
    if (!isCertErr) throw err;
    return {
      payload: await requestJson(url, true),
      usedInsecureTls: true
    };
  }
}

async function queryName(name, opts) {
  const where = buildWhereClause(name, opts.exact);
  const params = new URLSearchParams({
    where,
    outFields: "wpinumber,main_port_name,unlocode",
    returnGeometry: "true",
    orderByFields: "main_port_name ASC",
    resultRecordCount: String(opts.limit),
    f: "json"
  });
  const url = `${WPI_QUERY_URL}?${params.toString()}`;
  const { payload, usedInsecureTls } = await requestJsonWithFallback(url);
  if (payload && payload.error) {
    throw new Error(`API error for "${name}": ${JSON.stringify(payload.error)}`);
  }
  const features = Array.isArray(payload && payload.features) ? payload.features : [];
  const matches = features.map((f) => {
    const attrs = f && f.attributes ? f.attributes : {};
    const geom = f && f.geometry ? f.geometry : {};
    return {
      main_port_name: attrs.main_port_name || "",
      wpinumber: attrs.wpinumber == null ? null : attrs.wpinumber,
      unlocode: attrs.unlocode || null,
      lat: geom.y == null ? null : Number(geom.y),
      lng: geom.x == null ? null : Number(geom.x)
    };
  });
  return {
    query: name,
    where,
    count: matches.length,
    matches,
    tls_note: usedInsecureTls ? "Used insecure TLS fallback for NGA certificate chain." : ""
  };
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.help) {
    process.stdout.write(`${usage()}\n`);
    return;
  }

  let names = opts.names.slice();
  if (opts.file) {
    names = names.concat(readNamesFromFile(opts.file));
  }
  names = names
    .map((s) => String(s || "").trim())
    .filter(Boolean);

  if (!names.length) {
    throw new Error("No names supplied. Use --name or --file.");
  }

  const uniqueNames = Array.from(new Set(names));
  const results = [];
  for (const name of uniqueNames) {
    try {
      const row = await queryName(name, opts);
      results.push(row);
    } catch (err) {
      results.push({
        query: name,
        error: String(err && err.message ? err.message : err),
        count: 0,
        matches: []
      });
    }
  }

  const output = {
    source: "NGA WPI FeatureServer",
    endpoint: WPI_QUERY_URL,
    queried_at_utc: new Date().toISOString(),
    exact: opts.exact,
    limit: opts.limit,
    total_queries: uniqueNames.length,
    results
  };

  const json = JSON.stringify(output, null, opts.pretty ? 2 : 0);
  if (opts.out) {
    fs.writeFileSync(opts.out, json);
    process.stdout.write(`Wrote ${uniqueNames.length} query result(s) to ${opts.out}\n`);
    return;
  }
  process.stdout.write(`${json}\n`);
}

main().catch((err) => {
  process.stderr.write(`ERROR: ${err.message}\n`);
  process.stderr.write(`${usage()}\n`);
  process.exit(1);
});
