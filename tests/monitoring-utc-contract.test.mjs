import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));
const read = (relativePath) => readFileSync(path.join(repositoryRoot, relativePath), "utf8");

function cfFunction(source, name) {
  const match = source.match(
    new RegExp(`<cffunction\\s+name="${name}"[\\s\\S]*?<\\/cffunction>`, "i")
  );
  assert.ok(match, `Missing CFML function: ${name}`);
  return match[0];
}

test("Active Cruise preserves the instant in timezone-aware GPS timestamps", () => {
  const source = read("api/v1/floatplan.cfc");
  const parser = cfFunction(source, "parseActiveCruiseUtcDate");
  const validator = cfFunction(source, "validateActiveCruiseCheckinLocation");

  assert.match(parser, /parsedValue\s*=\s*parseDateTime\(raw\)/);
  assert.doesNotMatch(parser, /reReplace[^\n]+(?:Z\$|\[\+\-\])/i);
  assert.match(
    validator,
    /dateTimeFormat\(capturedAt\.value,\s*"yyyy-mm-dd'T'HH:nn:ss'Z'",\s*"UTC"\)/
  );
});

test("Monitoring serializes UTC explicitly and never strips an ISO timezone", () => {
  const source = read("api/v1/MonitoringConsoleViewModelService.cfc");
  const formatter = cfFunction(source, "formatUtc");
  const parser = cfFunction(source, "parseStoredUtcDate");
  const summary = cfFunction(source, "buildLastCheckinLocation");

  assert.match(
    formatter,
    /dateTimeFormat\(arguments\.value,\s*"yyyy-mm-dd'T'HH:nn:ss'Z'",\s*"UTC"\)/
  );
  assert.match(parser, /parsedValue\s*=\s*parseDateTime\(raw\)/);
  assert.doesNotMatch(parser, /reReplace[^\n]+(?:Z\$|\[\+\-\])/i);
  assert.match(summary, /capturedAt\s*=\s*parseStoredUtcDate/);
  assert.match(summary, /dateDiff\("n",\s*capturedAt,\s*arguments\.nowUtc\)/);
});
