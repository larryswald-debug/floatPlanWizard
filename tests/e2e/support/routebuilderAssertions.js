const { expect } = require("@playwright/test");
const {
  callRouteBuilderAction,
  loadLegGeometryPayload
} = require("./routebuilderHarness");

function normalizeLegRow(row) {
  const source = row || {};
  return {
    order: parseInt(source.order ?? source.ORDER_INDEX ?? source.leg_order ?? source.LEG_ORDER ?? 0, 10) || 0,
    routeLegId: parseInt(source.routeLegId ?? source.route_leg_id ?? source.ROUTE_LEG_ID ?? source.id ?? source.ID ?? 0, 10) || 0,
    segmentId: parseInt(source.segmentId ?? source.segment_id ?? source.SEGMENT_ID ?? 0, 10) || 0,
    hasOverride: !!(
      source.hasOverride
      || source.has_effective_override
      || source.HAS_EFFECTIVE_OVERRIDE
      || source.has_user_override
      || source.HAS_USER_OVERRIDE
      || source.has_override
      || source.HAS_OVERRIDE
    ),
    hasExactOverride: !!(
      source.has_user_override
      || source.HAS_USER_OVERRIDE
      || source.has_override
      || source.HAS_OVERRIDE
    ),
    source: String(
      source.source
      ?? source.override_source
      ?? source.OVERRIDE_SOURCE
      ?? ""
    ).trim(),
    name: String(
      source.name
      ?? source.NAME
      ?? (source.START_NAME && source.END_NAME ? `${source.START_NAME} -> ${source.END_NAME}` : "")
    ).trim(),
    distText: String(
      source.distText
      ?? source.DIST_TEXT
      ?? source.dist_nm
      ?? source.DIST_NM
      ?? ""
    ).trim()
  };
}

function normalizeLegRows(rows) {
  return Array.isArray(rows) ? rows.map(normalizeLegRow) : [];
}

function canonicalLegName(name) {
  let normalized = String(name || "").trim();
  let changed = true;
  while (normalized && changed) {
    changed = false;
    ["Override", "Offshore", "Optional"].forEach((suffix) => {
      if (normalized.endsWith(suffix)) {
        normalized = normalized.slice(0, -suffix.length).trim();
        changed = true;
      }
    });
  }
  return normalized;
}

function routeLegSequence(rows) {
  return normalizeLegRows(rows).map((row) => row.routeLegId);
}

function stableLegIdentity(row) {
  const normalized = normalizeLegRow(row);
  const canonicalName = canonicalLegName(normalized.name);
  if (canonicalName) {
    return `name:${canonicalName}`;
  }
  if (normalized.segmentId > 0) {
    return `segment:${normalized.segmentId}`;
  }
  if (normalized.distText) {
    return `dist:${normalized.distText}`;
  }
  if (normalized.routeLegId > 0) {
    return `route:${normalized.routeLegId}`;
  }
  return `order:${normalized.order}`;
}

function stableOverrideIdentity(row) {
  const normalized = normalizeLegRow(row);
  if (normalized.segmentId > 0) {
    return `segment:${normalized.segmentId}`;
  }
  const canonicalName = canonicalLegName(normalized.name);
  if (canonicalName) {
    return `name:${canonicalName}`;
  }
  if (normalized.routeLegId > 0) {
    return `route:${normalized.routeLegId}`;
  }
  return `order:${normalized.order}`;
}

function stableLegSequence(rows) {
  return normalizeLegRows(rows).map(stableLegIdentity);
}

function segmentSequence(rows) {
  return normalizeLegRows(rows).map((row) => row.segmentId);
}

function overrideRouteLegIds(rows) {
  return normalizeLegRows(rows)
    .filter((row) => row.hasOverride)
    .map(stableOverrideIdentity)
    .sort();
}

function overrideSegmentIds(rows) {
  return normalizeLegRows(rows)
    .filter((row) => row.hasOverride)
    .map((row) => row.segmentId)
    .sort((a, b) => a - b);
}

function overrideOrders(rows) {
  return normalizeLegRows(rows)
    .filter((row) => row.hasOverride)
    .map((row) => row.order)
    .sort((a, b) => a - b);
}

function expectRouteLegSequenceEqual(actualRows, expectedRows, message) {
  expect(stableLegSequence(actualRows), message || "Route leg sequence mismatch.").toEqual(stableLegSequence(expectedRows));
}

function expectRouteLegSequenceChanged(beforeRows, afterRows, message) {
  expect(stableLegSequence(afterRows), message || "Route leg sequence did not change.").not.toEqual(stableLegSequence(beforeRows));
}

function expectRouteLegSequenceReversed(beforeRows, afterRows, message) {
  expect(stableLegSequence(afterRows), message || "Route leg sequence did not reverse.").toEqual(stableLegSequence(beforeRows).slice().reverse());
}

function expectOverrideRouteLegIds(rows, expectedRouteLegIds, message) {
  const normalizedExpected = Array.from(expectedRouteLegIds || [])
    .map((value) => String(value || "").trim())
    .filter((value) => value.length)
    .sort();
  expect(overrideRouteLegIds(rows), message || "Override route_leg_id set mismatch.").toEqual(normalizedExpected);
}

function expectOverrideSegmentIds(rows, expectedSegmentIds, message) {
  const normalizedExpected = Array.from(expectedSegmentIds || [])
    .map((value) => parseInt(value || 0, 10) || 0)
    .filter((value) => value > 0)
    .sort((a, b) => a - b);
  expect(overrideSegmentIds(rows), message || "Override segment_id set mismatch.").toEqual(normalizedExpected);
}

function expectOverrideOrdersEqual(actualRows, expectedRowsOrOrders, message) {
  const expectedOrders = Array.isArray(expectedRowsOrOrders)
    ? (
      expectedRowsOrOrders.length
      && typeof expectedRowsOrOrders[0] === "object"
        ? overrideOrders(expectedRowsOrOrders)
        : expectedRowsOrOrders
    )
    : [];
  const normalizedExpected = Array.from(expectedOrders || [])
    .map((value) => parseInt(value || 0, 10) || 0)
    .filter((value) => value > 0)
    .sort((a, b) => a - b);
  expect(overrideOrders(actualRows), message || "Override order set mismatch.").toEqual(normalizedExpected);
}

function findLegByOrder(rows, order) {
  return normalizeLegRows(rows).find((row) => row.order === order) || null;
}

function findLegByRouteLegId(rows, routeLegId) {
  return normalizeLegRows(rows).find((row) => row.routeLegId === routeLegId) || null;
}

function findLegBySegmentId(rows, segmentId) {
  return normalizeLegRows(rows).find((row) => row.segmentId === segmentId) || null;
}

function flattenTimelineSegments(payload) {
  const sections = Array.isArray(payload?.SECTIONS) ? payload.SECTIONS : [];
  return sections
    .flatMap((section) => Array.isArray(section?.SEGMENTS) ? section.SEGMENTS : [])
    .map((segment) => normalizeLegRow({
      ORDER_INDEX: segment.ORDER_INDEX,
      ID: segment.ID,
      SEGMENT_ID: segment.SEGMENT_ID ?? segment.segment_id,
      HAS_USER_OVERRIDE: segment.HAS_USER_OVERRIDE,
      HAS_EFFECTIVE_OVERRIDE: segment.HAS_EFFECTIVE_OVERRIDE,
      OVERRIDE_SOURCE: segment.OVERRIDE_SOURCE,
      START_NAME: segment.START_NAME,
      END_NAME: segment.END_NAME,
      DIST_NM: segment.DIST_NM
    }))
    .sort((a, b) => a.order - b.order || a.routeLegId - b.routeLegId);
}

async function fetchTimelinePayload(page, routeCode) {
  const payload = await callRouteBuilderAction(page, "gettimeline", { routeCode });
  expect(!!payload?.SUCCESS, `getTimeline failed for ${routeCode}: ${payload?.MESSAGE || "unknown error"}`).toBeTruthy();
  return payload;
}

async function fetchTimelineSegments(page, routeCode) {
  const payload = await fetchTimelinePayload(page, routeCode);
  return {
    payload,
    segments: flattenTimelineSegments(payload)
  };
}

async function fetchLegOverrides(page, routeCode) {
  const payload = await callRouteBuilderAction(page, "routegen_listlegoverrides", { routeCode });
  expect(!!payload?.SUCCESS, `routegen_listlegoverrides failed for ${routeCode}: ${payload?.MESSAGE || "unknown error"}`).toBeTruthy();
  const overrides = Array.isArray(payload?.DATA?.overrides) ? payload.DATA.overrides : [];
  return {
    payload,
    overrides: overrides.map((row) => ({
      routeLegId: parseInt(row.route_leg_id || 0, 10) || 0,
      legOrder: parseInt(row.leg_order || 0, 10) || 0,
      segmentId: parseInt(row.segment_id || 0, 10) || 0,
      computedNm: Number(row.computed_nm || 0) || 0
    }))
  };
}

async function assertMapTruthForOrder(page, order, expected, contextLabel) {
  const payload = await loadLegGeometryPayload(page, order);
  const data = payload?.DATA || {};
  const label = contextLabel || `leg order ${order}`;
  if (expected.routeLegId !== undefined) {
    expect(parseInt(data.route_leg_id || 0, 10) || 0, `${label} route_leg_id mismatch.`).toBe(parseInt(expected.routeLegId || 0, 10) || 0);
  }
  if (expected.segmentId !== undefined) {
    expect(parseInt(data.segment_id || 0, 10) || 0, `${label} segment_id mismatch.`).toBe(parseInt(expected.segmentId || 0, 10) || 0);
  }
  if (expected.hasOverride !== undefined) {
    expect(!!data.has_override, `${label} exact override truth mismatch.`).toBe(!!expected.hasOverride);
  }
  if (expected.hasEffectiveOverride !== undefined) {
    expect(!!data.has_effective_override, `${label} effective override truth mismatch.`).toBe(!!expected.hasEffectiveOverride);
  }
  if (expected.hasSegmentOverride !== undefined) {
    expect(!!data.has_segment_override, `${label} segment override truth mismatch.`).toBe(!!expected.hasSegmentOverride);
  }
  if (expected.source !== undefined) {
    expect(String(data.source || "").trim(), `${label} geometry source mismatch.`).toBe(String(expected.source || "").trim());
  }
  return payload;
}

function describeLegRows(rows) {
  return normalizeLegRows(rows).map((row) => ({
    order: row.order,
    routeLegId: row.routeLegId,
    segmentId: row.segmentId,
    hasOverride: row.hasOverride,
    hasExactOverride: row.hasExactOverride,
    source: row.source,
    name: row.name,
    distText: row.distText
  }));
}

module.exports = {
  assertMapTruthForOrder,
  describeLegRows,
  canonicalLegName,
  expectOverrideRouteLegIds,
  expectOverrideOrdersEqual,
  expectOverrideSegmentIds,
  expectRouteLegSequenceChanged,
  expectRouteLegSequenceEqual,
  expectRouteLegSequenceReversed,
  fetchLegOverrides,
  fetchTimelinePayload,
  fetchTimelineSegments,
  findLegByOrder,
  findLegByRouteLegId,
  findLegBySegmentId,
  flattenTimelineSegments,
  normalizeLegRow,
  normalizeLegRows,
  overrideRouteLegIds,
  overrideOrders,
  overrideSegmentIds,
  routeLegSequence,
  stableLegIdentity,
  stableOverrideIdentity,
  stableLegSequence,
  segmentSequence
};
