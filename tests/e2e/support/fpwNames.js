function sanitizeSegment(value, fallback) {
  const raw = String(value || fallback || "item").trim().toLowerCase();
  const collapsed = raw.replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
  return collapsed || String(fallback || "item");
}

function buildUtcStamp() {
  const now = new Date();
  const yyyy = now.getUTCFullYear();
  const mm = String(now.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(now.getUTCDate()).padStart(2, "0");
  const hh = String(now.getUTCHours()).padStart(2, "0");
  const mi = String(now.getUTCMinutes()).padStart(2, "0");
  const ss = String(now.getUTCSeconds()).padStart(2, "0");
  return `${yyyy}${mm}${dd}${hh}${mi}${ss}`;
}

function buildTracePrefix(testInfo, fileSlug, scenarioSlug) {
  const project = sanitizeSegment(testInfo && testInfo.project ? testInfo.project.name : "project", "project");
  const file = sanitizeSegment(fileSlug, "file");
  const scenario = sanitizeSegment(scenarioSlug, "scenario");
  return `PW_${project}_${file}_${scenario}_${buildUtcStamp()}`;
}

function buildEntityName(prefix, label) {
  return `${prefix} ${String(label || "").trim()}`.trim();
}

function buildTraceEmail(prefix, tag) {
  const local = sanitizeSegment(prefix, "pw");
  const suffix = sanitizeSegment(tag, "contact");
  return `${local}.${suffix}@example.com`;
}

module.exports = {
  buildEntityName,
  buildTraceEmail,
  buildTracePrefix,
  buildUtcStamp,
  sanitizeSegment
};
