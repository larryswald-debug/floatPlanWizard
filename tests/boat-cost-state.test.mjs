import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const engine = require("../assets/js/boat-cost-engine.js");
const state = require("../assets/js/boat-cost-state.js");
const NOW = Date.parse("2026-09-19T12:00:00.000Z");
const canonical = "https://floatplanwizard.com/boat-loan-calculator/";

function memoryStorage() {
  const values = new Map([["unrelated.feature", "keep me"]]);
  const writes = [];
  const deletions = [];
  return {
    values, writes, deletions,
    getItem(key) { return values.has(key) ? values.get(key) : null; },
    setItem(key, value) { writes.push(key); values.set(key, value); },
    removeItem(key) { deletions.push(key); values.delete(key); },
    clear() { throw new Error("Never clear unrelated browser data"); }
  };
}
function savedEnvelope(scenarios, savedAt = new Date(NOW).toISOString()) {
  return JSON.stringify({ version: 1, savedAt, scenarios });
}
function sharedPayload(scenario = engine.example("B")) {
  const result = state.share(scenario, canonical);
  assert.equal(result.ok, true);
  return JSON.parse(Buffer.from(new URL(result.url).hash.slice(4), "base64url").toString("utf8"));
}
function fragment(payload) { return "#bc=" + Buffer.from(JSON.stringify(payload)).toString("base64url"); }

test("explicit browser save keeps up to three isolated assumptions and dates, never authoritative results", () => {
  const storage = memoryStorage();
  const scenarios = [engine.example("H"), engine.example("B"), engine.example("I")];
  scenarios[0].label = "My local boat";
  assert.equal(storage.writes.length, 0);
  assert.deepEqual(state.save(scenarios, storage, NOW), { ok: true, savedAt: new Date(NOW).toISOString() });
  assert.deepEqual(storage.writes, [state.STORAGE_KEY]);
  const restored = state.restore(storage, NOW + 1);
  assert.equal(restored.ok, true);
  assert.deepEqual(restored.scenarios, scenarios);
  restored.scenarios[0].purchase.price.value = 999;
  assert.equal(scenarios[0].purchase.price.value, 25000);
  assert.equal(state.restore(storage, NOW).scenarios[0].purchase.price.value, 25000);
  assert.deepEqual(Object.keys(JSON.parse(storage.values.get(state.STORAGE_KEY))).sort(), ["savedAt", "scenarios", "version"]);
  assert.equal(storage.values.get("unrelated.feature"), "keep me");
});

test("unknowns, entered zero, illustrative values and exclusions survive save and share distinctly", () => {
  const scenario = engine.example("B");
  scenario.reserves.initial = { value: 0, status: "entered" };
  scenario.reserves.annual = { value: "", status: "unknown" };
  scenario.operating.insurance = { value: "", status: "excluded" };
  const storage = memoryStorage();
  assert.equal(state.save([scenario], storage, NOW).ok, true);
  assert.deepEqual(state.restore(storage, NOW).scenarios[0], scenario);
  const shared = state.share(scenario);
  assert.equal(shared.ok, true);
  assert.deepEqual(state.parse(new URL(shared.url).hash).scenario, { ...scenario, label: "" });
  assert.equal(storage.writes.length, 1, "share and parse must never save automatically");
});

test("all published examples share beneath the 4096-character cap and preserve calculation inputs", () => {
  for (const key of ["H", "B", "I"]) {
    const scenario = engine.example(key);
    scenario.purchase.state = "FL";
    const result = state.share(scenario, canonical + "?price=123456#private");
    assert.equal(result.ok, true, key);
    assert.ok(result.url.length < 4096, `${key} link length: ${result.url.length}`);
    assert.equal(new URL(result.url).search, "");
    assert.equal(new URL(result.url).pathname, "/boat-loan-calculator/");
    const decoded = Buffer.from(new URL(result.url).hash.slice(4), "base64url").toString("utf8");
    assert.equal(decoded.includes(scenario.label), false);
    assert.ok(Buffer.byteLength(decoded) < 8192);
    const imported = state.parse(new URL(result.url).hash);
    assert.equal(imported.ok, true);
    assert.deepEqual(imported.scenario, { ...scenario, label: "" });
    assert.deepEqual(engine.calculate(imported.scenario), engine.calculate(scenario));
    assert.equal(scenario.label, engine.example(key).label, "sharing never changes source label");
  }
});

test("a detailed scenario with every allowed storage and other-cost row can share", () => {
  const scenario = engine.example("B");
  scenario.view = "detailed";
  scenario.operating.storage.mode = "details";
  scenario.operating.storage.rows = ["slip", "dryStack", "land", "trailer"].map(type => ({
    type, basis: "annual", input: { value: 500, status: "entered" }, months: 12, billableFeet: 30, startMonth: 1
  }));
  scenario.operating.other.mode = "details";
  scenario.operating.other.rows = ["utilities", "pumpouts", "trailer", "towing", "launch", "subscriptions", "other"].map(type => ({
    type, input: { value: 50, status: "entered" }
  }));
  const result = state.share(scenario);
  assert.equal(result.ok, true);
  assert.ok(result.url.length < 4096);
  assert.deepEqual(state.parse(new URL(result.url).hash).scenario, { ...scenario, label: "" });
});

test("browser deletion and 180-day expiry delete only this feature's key", () => {
  const storage = memoryStorage();
  assert.deepEqual(state.restore(storage, NOW), { ok: false, error: "missing" });
  state.save([engine.example("B")], storage, NOW);
  assert.equal(state.restore(storage, NOW + state.MAX_AGE_MS - 1).ok, true);
  assert.deepEqual(state.restore(storage, NOW + state.MAX_AGE_MS), { ok: false, error: "expired" });
  assert.deepEqual(storage.deletions, [state.STORAGE_KEY]);
  assert.equal(storage.values.get("unrelated.feature"), "keep me");
  state.save([engine.example("H")], storage, NOW);
  assert.deepEqual(state.remove(storage), { ok: true });
  assert.equal(storage.values.has(state.STORAGE_KEY), false);
  assert.equal(storage.values.get("unrelated.feature"), "keep me");
});

test("blocked, unavailable and quota-limited storage do not affect the model", () => {
  const blocked = {
    getItem() { throw new Error("private mode"); },
    setItem() { throw new Error("quota"); },
    removeItem() { throw new Error("blocked"); }
  };
  for (const storage of [null, {}, blocked]) {
    assert.deepEqual(state.save([engine.example("B")], storage, NOW), { ok: false, error: "storage_unavailable" });
    assert.deepEqual(state.restore(storage, NOW), { ok: false, error: "storage_unavailable" });
    assert.deepEqual(state.remove(storage), { ok: false, error: "storage_unavailable" });
  }
  assert.equal(engine.validateScenario(engine.example("B")).valid, true);
  assert.equal(state.share(engine.example("B")).ok, true);
});

test("storage validation rejects the whole document for bad dates, versions, counts and fields", () => {
  const storage = memoryStorage();
  const documents = [
    "not json", "", "null", "[]",
    JSON.stringify({ version: 2, savedAt: new Date(NOW).toISOString(), scenarios: [engine.example("B")] }),
    JSON.stringify({ version: 1, savedAt: new Date(NOW).toISOString(), scenarios: [engine.example("B")], token: "secret" }),
    savedEnvelope([]),
    savedEnvelope([engine.example("B"), engine.example("B"), engine.example("B"), engine.example("B")]),
    savedEnvelope([engine.example("B")], "2026-02-31T12:00:00.000Z"),
    savedEnvelope([engine.example("B")], "2026-09-19"),
    savedEnvelope([engine.example("B")], new Date(NOW + 300001).toISOString())
  ];
  for (const document of documents) {
    storage.values.set(state.STORAGE_KEY, document);
    const restored = state.restore(storage, NOW);
    assert.equal(restored.ok, false);
    assert.equal("scenarios" in restored, false);
  }
  assert.equal(storage.deletions.length, 0);
  assert.equal(state.save(new Array(1), storage, NOW).ok, false);
  const sparse = engine.example("B");
  delete sparse.purchase.fees[1];
  assert.equal(state.save([sparse], storage, NOW).ok, false);
  assert.equal(state.share(sparse).ok, false);
});

test("untrusted scenario schema, enum, bounds, row counts and hostile values fail atomically", () => {
  const mutations = [
    s => { s.extra = 1; },
    s => { s.version = 99; },
    s => { s.label = "<img src=x onerror=alert(1)>"; },
    s => { s.label = "x".repeat(61); },
    s => { s.purchase.state = "private contact@example.com"; },
    s => { s.purchase.method = "balloon"; },
    s => { s.purchase.price.value = -1; },
    s => { s.purchase.price.value = 5000001; },
    s => { s.purchase.price.value = NaN; },
    s => { s.purchase.price.value = Infinity; },
    s => { s.purchase.price.value = "1,2,3"; },
    s => { s.purchase.price.value = "<script>alert(1)</script>"; },
    s => { s.purchase.rate.status = "live-rate"; },
    s => { s.purchase.fees.push(s.purchase.fees[0]); },
    s => { delete s.reserves; },
    s => { Object.defineProperty(s, "__proto__", { enumerable: true, value: { polluted: true } }); }
  ];
  for (const mutate of mutations) {
    const scenario = engine.example("B");
    mutate(scenario);
    const storage = memoryStorage();
    assert.equal(state.save([engine.example("H"), scenario], storage, NOW).ok, false);
    assert.equal(storage.writes.length, 0);
    assert.equal(state.share(scenario).ok, false);
    storage.values.set(state.STORAGE_KEY, savedEnvelope([engine.example("H"), scenario]));
    assert.equal(state.restore(storage, NOW).ok, false);
  }
  assert.equal({}.polluted, undefined);
});

test("share import rejects versions, unknown keys, label injection and malformed encodings", () => {
  const original = sharedPayload();
  const variants = [
    null, {}, [], [1], [1, original[1], "unexpected"],
    [2, original[1]],
    [1, { ...original[1], unknown: "<script>" }],
    [1, { ...original[1], "1": "A private name" }],
    [1, { ...original[1], "00": 1 }],
    [1, { ...original[1], "zz": 1 }],
    [1, { ...original[1], "5": { ...original[1]["5"], "d": { "o": -1, "p": "entered" } } }]
  ];
  for (const value of variants) {
    const result = state.parse(fragment(value));
    assert.equal(result.ok, false);
    assert.equal("scenario" in result, false);
  }
  for (const value of [null, "", "#", "#bc=", "#bc=!!!", "#bc=%41", "#bc=YWJj=", "?bc=YWJj", "#bc=_w", "#bc=abcde"]) {
    assert.equal(state.parse(value).ok, false);
  }
  const hostile = '#bc=' + Buffer.from('[1,{"__proto__":{"polluted":true}}]').toString("base64url");
  assert.equal(state.parse(hostile).ok, false);
  assert.equal({}.polluted, undefined);
});

test("oversized share state fails with an actionable error and is never truncated", () => {
  const scenario = engine.example("B");
  scenario.purchase.price.value = "0".repeat(8000) + "1";
  scenario.purchase.down.input.value = 0;
  assert.equal(engine.validateScenario(scenario).valid, true);
  assert.deepEqual(state.share(scenario), { ok: false, error: "oversize" });
  assert.deepEqual(state.parse("#bc=" + "A".repeat(4096)), { ok: false, error: "oversize" });
  assert.equal(state.share(engine.example("B"), "javascript:alert(1)").ok, false);
  assert.equal(state.share(engine.example("B"), "https://user:password@example.com/boat-loan-calculator/").ok, false);
  assert.equal(state.share(engine.example("B"), "https://floatplanwizard.com/other-page/").ok, false);
});

test("analytics allowlists contain enumerated values only, never financial or free-text data", () => {
  const safe = state.sanitizeEvent("boat_cost_calculate", {
    calculator_version: "1.0", direction: "price", view: "detailed", purchase_mode: "financed",
    completeness: "complete", origin: "example", scenario_count: 3,
    destination: "trip_planner", error_code: "validation",
    price: 50000, amount: "10000", label: "My private boat", url: canonical + "#secret", email: "private@example.com"
  });
  assert.deepEqual(safe, {
    name: "boat_cost_calculate",
    params: { calculator_version: "1.0", direction: "price", view: "detailed", purchase_mode: "financed", completeness: "complete", origin: "example", scenario_count: 3, destination: "trip_planner", error_code: "validation" }
  });
  assert.equal(state.sanitizeEvent("arbitrary_event_with_50000", {}), null);
  assert.deepEqual(state.sanitizeEvent("boat_cost_error", { error_code: "User entered $50000", scenario_count: 50000, direction: "my secret" }), { name: "boat_cost_error", params: { calculator_version: "1.0" } });
  const getter = {};
  Object.defineProperty(getter, "direction", { get() { throw new Error("do not evaluate untrusted accessors"); } });
  assert.deepEqual(state.sanitizeEvent("boat_cost_start", getter), { name: "boat_cost_start", params: { calculator_version: "1.0" } });
});

test("analytics wrapper respects absent or blocked tracking and forwards only sanitized fields", () => {
  const previous = globalThis.FPWAnalytics;
  try {
    delete globalThis.FPWAnalytics;
    assert.equal(state.track("boat_cost_start", { direction: "price" }), false);
    globalThis.FPWAnalytics = { track() { throw new Error("tracking blocked"); } };
    assert.equal(state.track("boat_cost_calculate", { price: 50000 }), false);
    const sent = [];
    globalThis.FPWAnalytics = { track(name, params) { sent.push({ name, params }); } };
    assert.equal(state.track("boat_cost_save", { scenario_count: 2, amount: 50000 }), true);
    assert.equal(state.track("unknown", { scenario_count: 2 }), false);
    assert.deepEqual(sent, [{ name: "boat_cost_save", params: { calculator_version: "1.0", scenario_count: 2 } }]);
  } finally {
    if (previous === undefined) delete globalThis.FPWAnalytics;
    else globalThis.FPWAnalytics = previous;
  }
});
