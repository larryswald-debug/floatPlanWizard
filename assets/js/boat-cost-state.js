/* Explicit browser persistence and privacy-safe adapters for the boat cost calculator. */
(function (root, factory) {
  "use strict";
  if (typeof module === "object" && module.exports) {
    module.exports = factory(root, require("./boat-cost-engine.js"));
  } else {
    root.FPWBoatCostState = factory(root, root.FPWBoatCost);
  }
}(typeof globalThis !== "undefined" ? globalThis : this, function (root, engine) {
  "use strict";

  var VERSION = 1;
  var STORAGE_KEY = "fpw.boatCost.v1";
  var MAX_AGE_MS = 180 * 24 * 60 * 60 * 1000;
  var MAX_LINK_LENGTH = 4096;
  var MAX_DECODED_BYTES = 8192;
  var MAX_STORAGE_BYTES = 65536;
  var PREFIX = "#bc=";
  var CANONICAL_URL = "https://floatplanwizard.com/boat-loan-calculator/";
  // This versioned dictionary contains property names only. It cannot carry text,
  // identifiers or executable data. The engine independently validates each path.
  var KEYS = ["version", "label", "direction", "view", "origin", "purchase", "budget", "profile", "operating", "preparation", "reserves", "resale", "method", "price", "down", "rate", "term", "tax", "fees", "state", "mode", "input", "treatment", "type", "value", "status", "monthly", "cash", "boatType", "condition", "year", "length", "engineType", "engineCount", "water", "season", "fuel", "storage", "insurance", "maintenance", "registration", "seasonal", "other", "annual", "hours", "gph", "generator", "total", "rows", "basis", "months", "billableFeet", "startMonth", "includedElsewhere", "initial", "five", "ten", "selling"];

  var EVENT_NAMES = ["boat_cost_start", "boat_cost_calculate", "boat_cost_compare", "boat_cost_save", "boat_cost_share", "boat_cost_print", "boat_cost_cta", "boat_cost_error"];
  var EVENT_FIELDS = {
    calculator_version: ["1.0"],
    direction: ["price", "budget"],
    view: ["quick", "detailed"],
    purchase_mode: ["financed", "cash"],
    completeness: ["complete", "partial"],
    origin: ["example", "user"],
    scenario_count: [1, 2, 3],
    destination: ["fuel", "fuel_calculator", "trip_planner", "account"],
    placement: ["right_results", "fuel_help", "after_faq"],
    error_code: ["validation", "incomplete", "storage_unavailable", "expired", "missing", "invalid_state", "invalid_share", "unsupported_version", "oversize", "clipboard_unavailable", "privacy_unverified", "limit", "no_feasible_budget"]
  };

  function failure(error) { return { ok: false, error: error }; }
  function own(value, key) { return Object.prototype.hasOwnProperty.call(value, key); }
  function isPlain(value) {
    if (!value || typeof value !== "object" || Array.isArray(value)) return false;
    var proto = Object.getPrototypeOf(value);
    return proto === Object.prototype || proto === null;
  }
  function hasExactKeys(value, expected) {
    return isPlain(value) && Object.keys(value).length === expected.length && expected.every(function (key) { return own(value, key); });
  }
  function jsonSafe(value, depth, seen, count) {
    if (depth > 16 || ++count.value > 4096) return false;
    if (value === null || typeof value === "boolean") return true;
    if (typeof value === "number") return Number.isFinite(value);
    if (typeof value === "string") return value.length <= MAX_DECODED_BYTES;
    if (typeof value !== "object" || seen.indexOf(value) !== -1) return false;
    if (!Array.isArray(value) && !isPlain(value)) return false;
    if (Object.getOwnPropertySymbols(value).length > 0) return false;
    if (Array.isArray(value) && (value.length > 200 || Object.keys(value).length !== value.length || Object.keys(value).some(function (key, index) { return key !== String(index); }))) return false;
    seen.push(value);
    var keys = Object.keys(value);
    var safe = keys.every(function (key) {
      if (key === "__proto__" || key === "constructor" || key === "prototype") return false;
      var descriptor = Object.getOwnPropertyDescriptor(value, key);
      return descriptor && own(descriptor, "value") && jsonSafe(descriptor.value, depth + 1, seen, count);
    });
    seen.pop();
    return safe;
  }
  function validateScenario(scenario) {
    try {
      return jsonSafe(scenario, 0, [], { value: 0 }) && engine && engine.validateScenario(scenario).valid === true;
    } catch (error) { return false; }
  }
  function clone(value) { return JSON.parse(JSON.stringify(value)); }
  function storageOrDefault(storage) { return storage === undefined ? root.localStorage : storage; }
  function validStorage(storage) { return storage && typeof storage.getItem === "function" && typeof storage.setItem === "function" && typeof storage.removeItem === "function"; }
  function nowValue(now) { return now === undefined ? Date.now() : Number(now); }
  function utf8Bytes(value) {
    var escaped = encodeURIComponent(value);
    return escaped.replace(/%[0-9A-F]{2}|./g, "x").length;
  }

  function save(scenarios, storage, now) {
    if (!Array.isArray(scenarios) || scenarios.length < 1 || scenarios.length > 3 || !jsonSafe(scenarios, 0, [], { value: 0 }) || !scenarios.every(validateScenario)) return failure("invalid_state");
    var timestamp = nowValue(now);
    if (!Number.isFinite(timestamp) || Math.abs(timestamp) > 8640000000000000) return failure("invalid_state");
    try {
      var savedAt = new Date(timestamp).toISOString();
      var serialized = JSON.stringify({ version: VERSION, savedAt: savedAt, scenarios: scenarios });
      if (utf8Bytes(serialized) > MAX_STORAGE_BYTES) return failure("oversize");
      var target = storageOrDefault(storage);
      if (!validStorage(target)) return failure("storage_unavailable");
      target.setItem(STORAGE_KEY, serialized);
      return { ok: true, savedAt: savedAt };
    } catch (error) { return failure("storage_unavailable"); }
  }

  function restore(storage, now) {
    var target;
    var serialized;
    try {
      target = storageOrDefault(storage);
      if (!validStorage(target)) return failure("storage_unavailable");
      serialized = target.getItem(STORAGE_KEY);
    } catch (error) { return failure("storage_unavailable"); }
    if (serialized === null) return failure("missing");
    if (typeof serialized !== "string" || serialized.length > MAX_STORAGE_BYTES) return failure("invalid_state");
    try {
      if (utf8Bytes(serialized) > MAX_STORAGE_BYTES) return failure("invalid_state");
      var document = JSON.parse(serialized);
      if (!hasExactKeys(document, ["version", "savedAt", "scenarios"])) return failure("invalid_state");
      if (document.version !== VERSION) return failure("unsupported_version");
      if (typeof document.savedAt !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(document.savedAt)) return failure("invalid_state");
      var savedTime = Date.parse(document.savedAt);
      var currentTime = nowValue(now);
      if (!Number.isFinite(savedTime) || !Number.isFinite(currentTime) || new Date(savedTime).toISOString() !== document.savedAt || savedTime > currentTime + 300000) return failure("invalid_state");
      if (!Array.isArray(document.scenarios) || document.scenarios.length < 1 || document.scenarios.length > 3 || !document.scenarios.every(validateScenario)) return failure("invalid_state");
      if (currentTime - savedTime >= MAX_AGE_MS) {
        try { target.removeItem(STORAGE_KEY); } catch (error) { /* An expired estimate is never restored, even when deletion is blocked. */ }
        return failure("expired");
      }
      return { ok: true, savedAt: document.savedAt, scenarios: clone(document.scenarios) };
    } catch (error) { return failure("invalid_state"); }
  }

  function remove(storage) {
    try {
      var target = storageOrDefault(storage);
      if (!validStorage(target)) return failure("storage_unavailable");
      target.removeItem(STORAGE_KEY);
      return { ok: true };
    } catch (error) { return failure("storage_unavailable"); }
  }

  function pack(value) {
    if (Array.isArray(value)) return value.map(pack);
    if (!isPlain(value)) return value;
    var result = {};
    Object.keys(value).forEach(function (key) {
      var index = KEYS.indexOf(key);
      if (index < 0) throw new Error("invalid_state");
      result[index.toString(36)] = pack(value[key]);
    });
    return result;
  }
  function unpack(value, depth) {
    if (depth > 16) throw new Error("invalid_share");
    if (Array.isArray(value)) {
      if (value.length > 200) throw new Error("invalid_share");
      return value.map(function (item) { return unpack(item, depth + 1); });
    }
    if (!isPlain(value)) return value;
    var result = {};
    Object.keys(value).forEach(function (key) {
      if (!/^[0-9a-z]{1,2}$/.test(key)) throw new Error("invalid_share");
      var index = parseInt(key, 36);
      if (index.toString(36) !== key || index >= KEYS.length) throw new Error("invalid_share");
      result[KEYS[index]] = unpack(value[key], depth + 1);
    });
    return result;
  }
  function toBase64(text) {
    var bytes = encodeURIComponent(text).replace(/%([0-9A-F]{2})/g, function (all, hex) { return String.fromCharCode(parseInt(hex, 16)); });
    return root.btoa(bytes).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  }
  function fromBase64(encoded) {
    var bytes = root.atob(encoded.replace(/-/g, "+").replace(/_/g, "/"));
    if (bytes.length > MAX_DECODED_BYTES) throw new Error("oversize");
    return decodeURIComponent(Array.prototype.map.call(bytes, function (byte) { return "%" + ("0" + byte.charCodeAt(0).toString(16)).slice(-2); }).join(""));
  }
  function share(scenario, canonicalUrl) {
    if (!validateScenario(scenario)) return failure("invalid_state");
    try {
      var base = new URL(canonicalUrl || CANONICAL_URL);
      if (base.protocol !== "https:" && base.protocol !== "http:" || base.username || base.password || !/\/boat-loan-calculator\/$/.test(base.pathname)) return failure("invalid_share");
      base.search = "";
      base.hash = "";
      var shared = clone(scenario);
      // Labels are device-local even when they resemble harmless boat descriptions.
      delete shared.label;
      var payload = JSON.stringify([VERSION, pack(shared)]);
      if (utf8Bytes(payload) > MAX_DECODED_BYTES) return failure("oversize");
      var url = base.toString() + PREFIX + toBase64(payload);
      if (url.length > MAX_LINK_LENGTH) return failure("oversize");
      return { ok: true, url: url };
    } catch (error) { return failure("invalid_share"); }
  }
  function parse(fragment) {
    if (typeof fragment !== "string" || fragment.slice(0, PREFIX.length) !== PREFIX) return failure("invalid_share");
    if (CANONICAL_URL.length + fragment.length > MAX_LINK_LENGTH) return failure("oversize");
    var encoded = fragment.slice(PREFIX.length);
    if (!encoded || !/^[A-Za-z0-9_-]+$/.test(encoded)) return failure("invalid_share");
    try {
      var text = fromBase64(encoded);
      // Reject noncanonical encodings, malformed UTF-8 and hidden trailing bytes.
      if (toBase64(text) !== encoded) return failure("invalid_share");
      var payload = JSON.parse(text);
      if (!Array.isArray(payload) || payload.length !== 2) return failure("invalid_share");
      if (payload[0] !== VERSION) return failure("unsupported_version");
      var scenario = unpack(payload[1], 0);
      if (!isPlain(scenario) || own(scenario, "label")) return failure("invalid_share");
      scenario.label = "";
      if (!validateScenario(scenario)) return failure("invalid_share");
      return { ok: true, scenario: scenario };
    } catch (error) { return failure("invalid_share"); }
  }

  function sanitizeEvent(name, fields) {
    if (EVENT_NAMES.indexOf(name) === -1) return null;
    var params = { calculator_version: "1.0" };
    if (isPlain(fields)) {
      Object.keys(EVENT_FIELDS).forEach(function (key) {
        var descriptor = Object.getOwnPropertyDescriptor(fields, key);
        if (descriptor && own(descriptor, "value") && EVENT_FIELDS[key].indexOf(descriptor.value) !== -1) params[key] = descriptor.value;
      });
    }
    return { name: name, params: params };
  }
  function track(name, fields) {
    var safe = sanitizeEvent(name, fields);
    if (!safe) return false;
    try {
      if (!root.FPWAnalytics || typeof root.FPWAnalytics.track !== "function") return false;
      root.FPWAnalytics.track(safe.name, safe.params);
      return true;
    } catch (error) { return false; }
  }

  return { VERSION: VERSION, STORAGE_KEY: STORAGE_KEY, MAX_AGE_MS: MAX_AGE_MS, MAX_LINK_LENGTH: MAX_LINK_LENGTH, MAX_DECODED_BYTES: MAX_DECODED_BYTES, save: save, restore: restore, remove: remove, share: share, parse: parse, sanitizeEvent: sanitizeEvent, track: track };
}));
