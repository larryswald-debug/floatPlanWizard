(function (window) {
  'use strict';
  window.FPW = window.FPW || {};
  function roundDeparture(now) {
    var date = new Date(now.getTime());
    if (!Number.isFinite(date.getTime())) throw new Error('Invalid departure time.');
    if (!date.getMinutes() && !date.getSeconds() && !date.getMilliseconds()) return date;
    // Walk forward in real minutes so skipped and repeated local hours retain
    // chronological ordering, including zones with half-hour DST changes.
    date = new Date(Math.ceil(date.getTime() / 60000) * 60000);
    while (date.getMinutes() !== 0) date = new Date(date.getTime() + 60000);
    return date;
  }
  function localValue(date) {
    function pad(n) { return String(n).padStart(2, '0'); }
    return date.getFullYear() + '-' + pad(date.getMonth() + 1) + '-' + pad(date.getDate()) + 'T' + pad(date.getHours()) + ':' + pad(date.getMinutes());
  }
  window.FPW.LoopDepartureClock = { round: roundDeparture, localValue: localValue };

  var root = document.getElementById('loopCruiseTimeline');
  var view = window.FPW.CruiseTimelineView;
  if (!root || !view) return;
  var form = document.getElementById('loopTimelineForm');
  var departure = document.getElementById('loopTimelineDeparture');
  var status = document.getElementById('loopTimelineStatus');
  var summary = document.getElementById('loopTimelineSummary');
  var table = document.getElementById('loopTimelineTable');
  var list = document.getElementById('loopTimelineLegs');
  var initialDeparture = roundDeparture(new Date()); // Capture the clock once per page initialization.
  var state = { sequence: 0, initialized: false, payload: null, legs: [], selected: 1, expanded: 1, fuelAvailable: false, locks: Object.create(null) };
  departure.value = localValue(initialDeparture);
  departure.dataset.initialInstant = initialDeparture.toISOString();
  departure.dataset.departureInstant = initialDeparture.toISOString();
  form.hidden = false;

  function lowerKeys(value) {
    if (Array.isArray(value)) return value.map(lowerKeys);
    if (value && typeof value === 'object') {
      return Object.keys(value).reduce(function (out, key) { out[key.toLowerCase()] = lowerKeys(value[key]); return out; }, {});
    }
    return value;
  }
  function updateTimezone(date) {
    document.getElementById('loopTimelineTimezone').textContent = Intl.DateTimeFormat().resolvedOptions().timeZone + ' · ' + date.toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' });
  }
  updateTimezone(initialDeparture);
  function inputs() {
    var out = {};
    Array.from(form.elements).forEach(function (element) {
      if (element.name && element.name !== 'departure' && element.value !== '') out[element.name] = element.value;
    });
    return out;
  }
  function reserveControl() {
    form.elements.reserve_pct.disabled = form.elements.reserve_mode.value === 'thirds';
  }
  function request(body) {
    return fetch(root.dataset.endpoint, { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
      .then(function (response) { return response.json().then(function (value) {
        var data = lowerKeys(value);
        if (!response.ok || data.success === false) throw new Error(data.message || (data.timeline && data.timeline.message) || 'The cruise timeline is unavailable.');
        return data;
      }); });
  }
  function draw(focusOrder) {
    if (!state.payload) return;
    var active = list.contains(document.activeElement) ? document.activeElement : null;
    var activeWrapper = active && active.closest('[data-leg-order]');
    var restoreOrder = focusOrder || (activeWrapper ? Number(activeWrapper.dataset.legOrder) : 0);
    var restoreAction = !focusOrder && active ? active.dataset.legAction : '';
    list.innerHTML = view.renderLegRows(state.legs, {
      selectedOrder: state.selected, expandedOrder: state.expanded, readOnlyGeometry: true,
      getGeometryLabel: function () { return 'Template'; },
      getLockPanelHtml: function (leg, order) {
        if (order !== state.expanded) return '';
        var cached = state.locks[order] || {};
        var details = cached.data;
        var dayHtml = view.renderDayDetails({ payload: state.payload, leg: leg, order: order, status: 'ready', fuelAvailable: state.fuelAvailable });
        return '<div class="fpw-routegen__leglockpanel is-open" data-leg-order="' + order + '">' + view.renderLockDetails({
          details: details, isLoading: !!cached.loading, errorText: cached.error || '', timelineHtml: dayHtml,
          mappingAvailable: details ? details.mapping_status !== 'unavailable' : undefined,
          delayAvailable: details ? details.delay_estimates_available !== false : undefined,
          expectedLockCount: leg.lock_count
        }) + '</div>';
      }
    });
    if (restoreOrder) {
      var focusTarget = restoreAction ? list.querySelector('.fpw-routegen__leglockpanel[data-leg-order="' + restoreOrder + '"] [data-leg-action="' + restoreAction + '"]') : null;
      if (!focusTarget) focusTarget = list.querySelector('.fpw-routegen__leg[data-leg-order="' + restoreOrder + '"]');
      if (focusTarget) focusTarget.focus({ preventScroll: true });
    }
  }
  function loadLocks(order, reload) {
    if (!order || (!reload && state.locks[order])) return;
    state.locks[order] = { loading: true };
    draw();
    request({ action: 'locks', legOrder: order }).then(function (data) {
      state.locks[order] = { data: data.data };
      if (state.expanded === order) draw();
    }).catch(function (error) {
      state.locks[order] = { error: error.message };
      if (state.expanded === order) draw();
    });
  }
  function recalculate() {
    if (!form.reportValidity()) return;
    var seq = ++state.sequence;
    var planningInputs = state.initialized ? inputs() : {};
    if (!state.initialized) Array.from(form.elements).forEach(function (element) { element.disabled = true; });
    status.textContent = 'Building Cruise Timeline…';
    root.setAttribute('aria-busy', 'true');
    request({ action: 'timeline', startDate: departure.value.slice(0, 10), inputs: planningInputs }).then(function (data) {
      if (seq !== state.sequence) return;
      if (!state.initialized) {
        Object.keys(data.defaults).forEach(function (name) { if (form.elements[name]) form.elements[name].value = data.defaults[name]; });
        state.initialized = true;
        Array.from(form.elements).forEach(function (element) { element.disabled = false; });
        reserveControl();
      }
      state.legs = data.legs;
      state.payload = view.normalizePayload(data.timeline);
      state.fuelAvailable = data.timeline.timeline_meta.fuel_resolved === true;
      var currentInputs = inputs();
      var model = view.buildSummaryModel(state.payload, { maxHoursPerDay: currentInputs.underway_hours_per_day, reservePct: currentInputs.reserve_pct, reserveMode: currentInputs.reserve_mode, fuelAvailable: state.fuelAvailable });
      summary.textContent = model.calcLine;
      table.hidden = false;
      draw();
      loadLocks(state.expanded);
      status.textContent = state.fuelAvailable ? 'Timeline updated.' : 'Timeline updated. Fuel requirements and reserves are unavailable until fuel-burn data is supplied.';
    }).catch(function (error) {
      if (seq === state.sequence) {
        table.hidden = true;
        summary.textContent = 'Timeline unavailable for the current settings.';
        status.textContent = error.message;
      }
    }).finally(function () {
      if (seq === state.sequence) {
        root.removeAttribute('aria-busy');
        if (!state.initialized) form.querySelector('[type=submit]').disabled = false;
      }
    });
  }
  form.addEventListener('submit', function (event) { event.preventDefault(); recalculate(); });
  form.addEventListener('change', function (event) {
    reserveControl();
    if (event.target === departure && departure.value) {
      var chosen = new Date(departure.value);
      if (Number.isFinite(chosen.getTime())) { departure.dataset.departureInstant = chosen.toISOString(); updateTimezone(chosen); }
    }
    if (state.initialized) recalculate();
  });
  function select(event) {
    var action = event.target.closest('[data-leg-action]');
    if (action) {
      if (action.dataset.legAction === 'collapse-locks') { var old = state.expanded; state.expanded = 0; draw(old); }
      if (action.dataset.legAction === 'reload-locks') loadLocks(state.expanded, true);
      return;
    }
    var row = event.target.closest('.fpw-routegen__leg[data-leg-order]');
    if (!row) return;
    var order = Number(row.dataset.legOrder);
    state.selected = order;
    state.expanded = state.expanded === order ? 0 : order;
    draw(order);
    loadLocks(state.expanded);
  }
  list.addEventListener('click', select);
  list.addEventListener('keydown', function (event) {
    if ((event.key === 'Enter' || event.key === ' ') && event.target.matches('.fpw-routegen__leg[data-leg-order]')) { event.preventDefault(); select(event); }
  });
  recalculate();
})(window);
