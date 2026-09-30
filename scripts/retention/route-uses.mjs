/**
 * Pure Day 40 lifetime-use normalization. Inputs are a read-only source snapshot.
 * product_events must already have passed the report's provenance validation.
 * trip_beginnings / trip_completions / planning_beginnings are accepted report
 * facts: { user_id, floatplan_id, route_instance_id, at_utc, source_ref }.
 * Legacy *_raw clocks are deliberately never interpreted as UTC.
 */
export function normalizeUtc(value) {
  if (typeof value !== 'string') return null;
  const m = /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?(Z)?$/.exec(value);
  if (!m || (value.includes('T') && !m[8])) return null;
  const [year, month, day, hour, minute, second] = m.slice(1, 7).map(Number);
  if (year < 1000 || month < 1 || month > 12 || day < 1 || day > 31 ||
      hour > 23 || minute > 59 || second > 59) return null;
  const d = new Date(Date.UTC(year, month - 1, day, hour, minute, second));
  if (d.getUTCFullYear() !== year || d.getUTCMonth() !== month - 1 ||
      d.getUTCDate() !== day) return null;
  return `${m[1]}-${m[2]}-${m[3]}T${m[4]}:${m[5]}:${m[6]}.${(m[7] || '').padEnd(6, '0')}Z`;
}

function id(value) {
  const text = String(value ?? '');
  if (!/^[1-9]\d*$/.test(text)) return null;
  const number = Number(text);
  return Number.isSafeInteger(number) ? number : null;
}
const rows = (value) => Array.isArray(value) ? value : [];
const owned = (row, userId) => id(row.user_id) === userId;
const planId = (row) => id(row.floatplan_id ?? row.id);
const legged = (row) => Number.isInteger(Number(row.leg_count)) && Number(row.leg_count) > 0;
const ref = (table, identifier) => `${table}:${identifier}`;

function lineage(row) {
  if (row.lineage_json_valid === false || row.lineage_json_valid === 0 ||
      row.lineage_json_valid === '0') return { invalid: true };
  let json = row.routegen_inputs_json;
  if (json === null || json === undefined || json === '') json = {};
  try { if (typeof json === 'string') json = JSON.parse(json); }
  catch { return { invalid: true }; }
  if (!json || typeof json !== 'object' || Array.isArray(json)) return { invalid: true };
  const normalized = {};
  for (const [key, value] of Object.entries(json)) {
    // The privacy-minimized SQL export emits absent case variants as null.
    if (value === null || value === undefined) continue;
    const lower = key.toLowerCase();
    if (Object.hasOwn(normalized, lower) && String(normalized[lower]) !== String(value)) {
      return { invalid: true };
    }
    normalized[lower] = value;
  }
  const names = ['route_id', 'source_route_instance_id', 'source_generated_route_id', 'source_user_route_id'];
  for (const name of names) {
    const value = normalized[name];
    if (value !== undefined && value !== null && value !== '' && Number(value) !== 0 && !id(value)) {
      return { invalid: true };
    }
  }
  return {
    saved: id(normalized.source_user_route_id) ??
      ((String(normalized.route_type ?? '').toLowerCase() === 'my_route' ||
        String(row.template_route_code ?? '').toUpperCase() === 'MY_ROUTE') ? id(normalized.route_id) : null),
    source_instance: id(normalized.source_route_instance_id),
    source_generated: id(normalized.source_generated_route_id),
    expects_saved: String(normalized.route_type ?? '').toLowerCase() === 'my_route' ||
      String(row.template_route_code ?? '').toUpperCase() === 'MY_ROUTE',
    invalid: false
  };
}

function normalizeMember(snapshot, userId, T) {
  const reasons = new Set();
  const savedRows = rows(snapshot.user_routes).filter(r => owned(r, userId));
  const instanceRows = rows(snapshot.route_instances).filter(r => owned(r, userId));
  const plans = rows(snapshot.floatplans).filter(r => owned(r, userId));
  const saved = new Map(savedRows.filter(r => id(r.id)).map(r => [id(r.id), r]));
  const instances = new Map(instanceRows.filter(r => id(r.id)).map(r => [id(r.id), r]));
  const planMap = new Map(plans.filter(r => planId(r)).map(r => [planId(r), r]));
  const links = new Map(instanceRows.filter(r => id(r.id)).map(r => [id(r.id), lineage(r)]));
  const groups = new Map();
  const instanceKeys = new Map();
  const planKeys = new Map();
  const rootCache = new Map();

  function root(instanceId, seen = new Set()) {
    if (rootCache.has(instanceId)) return rootCache.get(instanceId);
    const instance = instances.get(instanceId);
    const link = links.get(instanceId);
    const unknown = { key: `unresolved-instance:${instanceId}`, independent: false };
    if (!instance || !link || link.invalid || seen.has(instanceId)) {
      reasons.add(seen.has(instanceId) ? 'CYCLIC_ROUTE_LINEAGE' : 'INVALID_OR_MISSING_ROUTE_LINEAGE');
      return unknown;
    }
    seen = new Set(seen).add(instanceId);
    let result;
    if (link.source_instance) {
      if (!instances.has(link.source_instance)) {
        reasons.add('MISSING_OR_FOREIGN_SOURCE_ROUTE');
        result = unknown;
      } else {
        result = root(link.source_instance, seen);
        // Conflicting explicit saved ancestry is not silently resolved.
        if (link.saved && result.key !== `saved-route:${link.saved}`) {
          reasons.add('CONFLICTING_ROUTE_LINEAGE');
          result = unknown;
        }
      }
    } else if (link.saved) {
      if (!saved.has(link.saved)) {
        reasons.add('MISSING_OR_FOREIGN_SAVED_ROUTE');
        result = unknown;
      } else result = { key: `saved-route:${link.saved}`, independent: true };
    } else if (link.source_generated) {
      const sources = instanceRows.filter(r => id(r.generated_route_id) === link.source_generated && id(r.id) !== instanceId);
      if (sources.length !== 1) {
        reasons.add('AMBIGUOUS_GENERATED_SOURCE_ROUTE');
        result = unknown;
      } else result = root(id(sources[0].id), seen);
    } else if (link.expects_saved) {
      reasons.add('MISSING_SAVED_ROUTE_LINEAGE');
      result = unknown;
    } else if (id(instance.generated_route_id)) {
      result = { key: `generated-route:${id(instance.generated_route_id)}`, independent: true };
    } else {
      reasons.add('MISSING_GENERATED_ROUTE_IDENTITY');
      result = unknown;
    }
    rootCache.set(instanceId, result);
    return result;
  }

  function ensure(key, independent = true) {
    if (!groups.has(key)) groups.set(key, {
      key, independent, source_ids: new Set(), plan_ids: new Set(), route_instance_ids: new Set(),
      beginnings: [], initial_object_creation: [], completions: [], evidence_codes: new Set()
    });
    const result = groups.get(key);
    result.independent &&= independent;
    return result;
  }
  function addBeginning(use, at, source, sourceRef) {
    const normalized = normalizeUtc(at);
    if (!normalized || normalized >= T) {
      reasons.add(normalized >= T ? 'FUTURE_BEGINNING_IGNORED' : 'BEGINNING_UTC_UNKNOWN');
      return;
    }
    use.beginnings.push({ at_utc: normalized, source, source_ref: sourceRef });
  }
  function validFact(fact) {
    if (!owned(fact, userId)) return false;
    const pid = id(fact.floatplan_id);
    if (pid && !planMap.has(pid)) { reasons.add('MISSING_OR_FOREIGN_FACT_PLAN'); return false; }
    const rid = id(fact.route_instance_id);
    if (rid && !instances.has(rid)) { reasons.add('MISSING_OR_FOREIGN_FACT_ROUTE'); return false; }
    const bound = pid ? id(planMap.get(pid).route_instance_id) : null;
    if (pid && bound !== rid) { reasons.add('CONFLICTING_FACT_PLAN_ROUTE'); return false; }
    if (!pid && !rid) { reasons.add('FACT_WITHOUT_USE_IDENTITY'); return false; }
    const at = normalizeUtc(fact.at_utc);
    if (fact.at_utc != null && fact.at_utc !== '' && (!at || at >= T)) {
      reasons.add(at >= T ? 'FUTURE_FACT_IGNORED' : 'INVALID_FACT_UTC');
      return false;
    }
    return true;
  }
  const beginnings = rows(snapshot.trip_beginnings).filter(validFact);
  const planning = rows(snapshot.planning_beginnings).filter(validFact);
  const completions = rows(snapshot.trip_completions).filter(validFact);
  const facts = [...beginnings, ...planning, ...completions];

  for (const route of savedRows) {
    const rid = id(route.id);
    if (!rid) { reasons.add('INVALID_SAVED_ROUTE_ID'); continue; }
    if (!legged(route)) { reasons.add('ZERO_LEG_SAVED_ROUTE_EXCLUDED'); continue; }
    const use = ensure(`saved-route:${rid}`);
    use.source_ids.add(ref('user_routes', rid));
    use.evidence_codes.add('OWNED_SAVED_ROUTE_WITH_LEGS');
  }

  for (const instance of instanceRows) {
    const rid = id(instance.id);
    if (!rid) { reasons.add('INVALID_ROUTE_INSTANCE_ID'); continue; }
    if (!legged(instance)) { reasons.add('ZERO_LEG_ROUTE_INSTANCE_EXCLUDED'); continue; }
    const base = root(rid);
    const link = links.get(rid);
    const isCopy = !!(link?.source_instance || link?.source_generated);
    const hasLaterUseFact = facts.some(f => id(f.route_instance_id) === rid);
    const key = isCopy && hasLaterUseFact ? `subsequent-trip:${rid}` : base.key;
    const use = ensure(key, base.independent);
    use.route_instance_ids.add(rid);
    use.source_ids.add(ref('route_instances', rid));
    use.evidence_codes.add(isCopy && hasLaterUseFact ? 'ACCEPTED_SUBSEQUENT_USE_FACT' : 'OWNED_GENERATED_ROUTE_WITH_LEGS');
    instanceKeys.set(rid, key);
    if (isCopy && !hasLaterUseFact) reasons.add('COPY_WITHOUT_SUBSEQUENT_USE_PROOF_COLLAPSED');
  }

  for (const plan of plans) {
    const pid = planId(plan);
    const rid = id(plan.route_instance_id);
    if (pid && rid && instanceKeys.has(rid)) {
      const key = instanceKeys.get(rid);
      groups.get(key).plan_ids.add(pid);
      planKeys.set(pid, key);
    } else if (pid && !rid && facts.some(f => id(f.floatplan_id) === pid && !id(f.route_instance_id))) {
      const key = `basic-trip:${pid}`;
      const use = ensure(key);
      use.plan_ids.add(pid);
      use.source_ids.add(ref('floatplans', pid));
      use.evidence_codes.add('ACCEPTED_ROUTELESS_TRIP_FACT');
      planKeys.set(pid, key);
    } else if (pid && !rid) {
      reasons.add('ROUTELESS_DRAFT_LEGITIMACY_UNPROVEN');
    }
  }

  for (const event of rows(snapshot.product_events)) {
    if (!owned(event, userId) || event.event_source !== 'member_api') continue;
    const eid = id(event.entity_id);
    const at = normalizeUtc(event.occurred_at_utc);
    if (!at || at >= T) continue;
    let key;
    if (event.event_name === 'user_route_created' && event.entity_type === 'user_route') {
      if (!saved.has(eid)) { reasons.add('DELETED_OR_MISSING_ROUTE_EVENT_TARGET'); continue; }
      key = groups.has(`saved-route:${eid}`) ? `saved-route:${eid}` : null;
      if (key) groups.get(key).initial_object_creation.push({
        at_utc: at, source_ref: ref('product_events', event.id ?? 'unidentified')
      });
      // The named-route command inserts an empty route. Current legs do not
      // retroactively make that initial timestamp a substantive-use beginning.
      continue;
    } else if (event.event_name === 'route_created' && event.entity_type === 'route_instance') {
      if (!instances.has(eid)) { reasons.add('DELETED_OR_MISSING_ROUTE_EVENT_TARGET'); continue; }
      // Copy creation is not accepted as an independent subsequent-use beginning.
      const link = links.get(eid);
      if (link?.source_instance || link?.source_generated) continue;
      key = instanceKeys.get(eid);
    } else continue; // Updates and replacement Draft insertions never create a use.
    if (!key) continue;
    const use = groups.get(key);
    addBeginning(use, at, event.event_name, ref('product_events', event.id ?? 'unidentified'));
    use.evidence_codes.add('VALIDATED_MEMBER_CREATION_EVENT');
  }

  function useForFact(fact) {
    const pid = id(fact.floatplan_id);
    const rid = id(fact.route_instance_id);
    const key = pid ? planKeys.get(pid) : instanceKeys.get(rid);
    if (!key) { reasons.add('FACT_HAS_NO_LEGITIMATE_USE'); return null; }
    return groups.get(key);
  }
  for (const fact of [...beginnings, ...planning]) {
    const use = useForFact(fact);
    if (!use) continue;
    addBeginning(use, fact.at_utc, beginnings.includes(fact) ? 'accepted_trip_beginning' : 'accepted_planning_beginning', fact.source_ref ?? null);
  }
  for (const fact of completions) {
    const use = useForFact(fact);
    if (!use) continue;
    use.completions.push({ at_utc: normalizeUtc(fact.at_utc), source_ref: fact.source_ref ?? null });
    use.evidence_codes.add('ACCEPTED_TRIP_COMPLETION');
    if (!normalizeUtc(fact.at_utc)) reasons.add('COMPLETION_UTC_UNKNOWN');
  }

  const uses = [...groups.values()].map(use => {
    const ordered = use.beginnings.sort((a, b) => a.at_utc.localeCompare(b.at_utc));
    if (!ordered.length) reasons.add('USE_BEGINNING_UTC_UNKNOWN');
    return {
      key: use.key, independent: use.independent,
      source_ids: [...use.source_ids].sort(),
      plan_ids: [...use.plan_ids].sort((a, b) => a - b),
      route_instance_ids: [...use.route_instance_ids].sort((a, b) => a - b),
      begin_at_utc: ordered[0]?.at_utc ?? null,
      begin_source: ordered[0]?.source ?? null,
      beginning_evidence: ordered,
      initial_object_creation: use.initial_object_creation,
      completions: use.completions,
      evidence_codes: [...use.evidence_codes].sort()
    };
  }).sort((a, b) => a.key.localeCompare(b.key));
  const dated = uses.filter(u => u.independent && u.begin_at_utc).sort((a, b) => a.begin_at_utc.localeCompare(b.begin_at_utc) || a.key.localeCompare(b.key));
  const first = dated[0] ?? null;
  const second = first ? dated.find(u => u.key !== first.key && u.begin_at_utc > first.begin_at_utc) ?? null : null;
  const returnEvidence = [];
  for (const completed of uses.filter(u => u.independent)) {
    for (const completion of completed.completions.filter(c => c.at_utc)) {
      for (const next of dated) {
        if (next.key !== completed.key && next.begin_at_utc > completion.at_utc) {
          returnEvidence.push({ completed_use_key: completed.key, completed_at_utc: completion.at_utc,
            subsequent_use_key: next.key, subsequent_begin_at_utc: next.begin_at_utc,
            subsequent_begin_source: next.begin_source });
        }
      }
    }
  }
  if (!uses.length) reasons.add('NO_PROVEN_LEGITIMATE_USE');
  reasons.add('LIFETIME_HISTORY_COMPLETENESS_UNPROVEN');
  return {
    user_id: userId, uses, has_legitimate_use: uses.length ? 'YES' : 'UNKNOWN',
    first_use: first, second_use: second,
    first_use_label: 'EARLIEST_EVIDENCED_USE',
    repeat: second ? 'YES' : 'UNKNOWN',
    returned_after_completion: returnEvidence.length ? 'YES' : 'UNKNOWN',
    return_evidence: returnEvidence,
    reasons: [...reasons].sort()
  };
}

export function normalizeRouteUses(snapshot) {
  const T = normalizeUtc(snapshot.as_of_utc ?? snapshot.T);
  if (!T) throw new Error('A valid fixed UTC report cutoff is required.');
  const source = rows(snapshot.members).length ? snapshot.members : rows(snapshot.users);
  const memberIds = [...new Set(source.map(m => id(m.user_id ?? m.id)).filter(Boolean))].sort((a, b) => a - b);
  return { as_of_utc: T, per_member: memberIds.map(userId => normalizeMember(snapshot, userId, T)) };
}

/** Single-member adapter for callers that validate events separately. */
export function normalizeUses(snapshot, userId, options = {}) {
  const T = normalizeUtc(options.T ?? snapshot.as_of_utc ?? snapshot.T);
  if (!T || !id(userId)) throw new Error('A valid member and fixed UTC report cutoff are required.');
  return normalizeMember({
    ...snapshot,
    product_events: options.validatedEvents ?? snapshot.product_events,
    trip_beginnings: options.trip_beginnings ?? snapshot.trip_beginnings,
    trip_completions: options.trip_completions ?? snapshot.trip_completions,
    planning_beginnings: options.planning_beginnings ?? snapshot.planning_beginnings
  }, id(userId), T);
}
