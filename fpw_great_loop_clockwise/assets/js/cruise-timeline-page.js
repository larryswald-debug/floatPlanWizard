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
  var plannerPrompt = document.getElementById('loopLegPlannerPrompt');
  var waypointAuthDialog = document.getElementById('loopWaypointAuthDialog');
  var waypointStates = Object.create(null);
  var currentTemplateCode = '';
  var authReturnOrder = 0;

  function waypointKey(leg, templateCode) {
    return templateCode + ':' + leg.segment_id + ':' + leg.order_index;
  }
  function refreshWaypointStatus() {
    var leg = state.legs.find(function (item) { return Number(item.order_index) === state.expanded; });
    var panel = list.querySelector('.fpw-routegen__leglockpanel[data-leg-order="' + state.expanded + '"]');
    if (!leg || !panel) return;
    var result = waypointStates[waypointKey(leg, currentTemplateCode)] || {};
    var button = panel.querySelector('[data-leg-action="save-waypoints"]');
    var message = panel.querySelector('#loopWaypointStatus');
    if (button) {
      button.disabled = !!result.pending;
      button.textContent = result.pending ? 'Adding Waypoints…' : (result.label || 'Add to Waypoints');
      button.setAttribute('aria-busy', result.pending ? 'true' : 'false');
    }
    if (message) message.textContent = result.message || '';
  }
  function showWaypointSignIn(order) {
    authReturnOrder = order;
    if (waypointAuthDialog && !waypointAuthDialog.open) waypointAuthDialog.showModal();
  }
  if (waypointAuthDialog) {
    waypointAuthDialog.querySelector('[data-loop-auth-close]').addEventListener('click', function () { waypointAuthDialog.close(); });
    waypointAuthDialog.addEventListener('close', function () {
      var target = list.querySelector('.fpw-routegen__leglockpanel[data-leg-order="' + authReturnOrder + '"] [data-leg-action="save-waypoints"]');
      if (target) target.focus({ preventScroll: true });
    });
  }
  function trackWaypointResult(leg, data, fallbackStatus) {
    var fields = { source_page: 'great_loop_legs', leg_id: Number(leg.segment_id), result_status: data.result || fallbackStatus };
    if (Number.isInteger(data.added_count)) fields.added_count = data.added_count;
    if (Number.isInteger(data.existing_count)) fields.existing_count = data.existing_count;
    try {
      if (window.FPWAnalytics && typeof window.FPWAnalytics.track === 'function') {
        window.FPWAnalytics.track('great_loop_leg_waypoints_saved', fields);
      }
    } catch (ignored) { /* Optional analytics must not interrupt waypoint feedback. */ }
  }
  function saveLegWaypoints(order) {
    var leg = state.legs.find(function (item) { return Number(item.order_index) === order; });
    if (!leg || !currentTemplateCode) return;
    // Capture the selected leg before asynchronous work or a later expansion/redraw.
    var templateCode = currentTemplateCode;
    var key = waypointKey(leg, templateCode);
    if (waypointStates[key] && waypointStates[key].pending) return;
    var result = waypointStates[key] = { pending: true, message: '' };
    refreshWaypointStatus();
    Promise.resolve().then(function () {
      if (!window.Api || typeof window.Api.authBootstrap !== 'function') throw new Error('AUTH_UNAVAILABLE');
      return window.Api.authBootstrap();
    }).then(function (value) {
      var auth = lowerKeys(value);
      if (auth.auth !== true) {
        result.message = 'Sign in to save this leg’s stops to My Waypoints.';
        showWaypointSignIn(order);
        return null;
      }
      if (!auth.success || !auth.csrf_token) throw new Error('AUTH_UNAVAILABLE');
      return fetch(root.dataset.waypointEndpoint, {
        method: 'POST', credentials: 'same-origin', cache: 'no-store',
        headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'X-CSRF-Token': auth.csrf_token },
        body: JSON.stringify({ action: 'savelegstops', templateCode: templateCode, legOrder: order, segmentId: Number(leg.segment_id) })
      }).then(function (response) {
        return response.json().then(function (value) {
          var data = lowerKeys(value);
          if (data.auth === false || response.status === 401) {
            result.message = 'Your session has expired. Sign in again to save these waypoints.';
            showWaypointSignIn(order);
          } else if (response.ok && data.success === true) {
            result.label = data.added_count === 0 ? 'Already in My Waypoints' : 'Waypoints Added';
            result.message = data.message;
          } else {
            result.message = data.message || 'Unable to save these waypoints. Please try again.';
          }
          trackWaypointResult(leg, data, data.success === true ? 'saved' : 'error');
        });
      });
    }).catch(function () {
      result.message = 'Unable to confirm that these waypoints were saved. Please try again; locations already saved will not be duplicated.';
      trackWaypointResult(leg, {}, 'unconfirmed');
    }).finally(function () {
      result.pending = false;
      refreshWaypointStatus();
    });
  }
  var initialDeparture = roundDeparture(new Date()); // Capture the clock once per page initialization.
  var state = { sequence: 0, initialized: false, payload: null, legs: [], selected: 1, expanded: 1, fuelAvailable: false, locks: Object.create(null) };
  departure.value = localValue(initialDeparture);
  departure.dataset.initialInstant = initialDeparture.toISOString();
  departure.dataset.departureInstant = initialDeparture.toISOString();
  form.hidden = false;

  function trackInteraction(eventName, section) {
    try {
      if (window.FPWAnalytics && typeof window.FPWAnalytics.track === 'function') {
        window.FPWAnalytics.track(eventName, { source_page: 'great_loop_legs', section: section });
      }
    } catch (error) { /* Optional analytics must not interrupt the timeline. */ }
  }

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
        }) + (plannerPrompt ? plannerPrompt.innerHTML : '') + '</div>';
      }
    });
    refreshWaypointStatus();
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
  function recalculate(userInitiated) {
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
      currentTemplateCode = data.template_code;
      state.payload = view.normalizePayload(data.timeline);
      state.fuelAvailable = data.timeline.timeline_meta.fuel_resolved === true;
      var currentInputs = inputs();
      var model = view.buildSummaryModel(state.payload, { maxHoursPerDay: currentInputs.underway_hours_per_day, reservePct: currentInputs.reserve_pct, reserveMode: currentInputs.reserve_mode, fuelAvailable: state.fuelAvailable });
      summary.textContent = model.calcLine;
      table.hidden = false;
      draw();
      loadLocks(state.expanded);
      status.textContent = state.fuelAvailable ? 'Timeline updated.' : 'Timeline updated. Fuel requirements and reserves are unavailable until fuel-burn data is supplied.';
      if (userInitiated) trackInteraction('great_loop_timeline_recalculated', 'timeline');
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
  form.addEventListener('submit', function (event) { event.preventDefault(); recalculate(true); });
  form.addEventListener('change', function (event) {
    reserveControl();
    if (event.target === departure && departure.value) {
      var chosen = new Date(departure.value);
      if (Number.isFinite(chosen.getTime())) { departure.dataset.departureInstant = chosen.toISOString(); updateTimezone(chosen); }
    }
    if (state.initialized) recalculate(true);
  });
  function select(event) {
    var action = event.target.closest('[data-leg-action]');
    if (action) {
      if (action.dataset.legAction === 'collapse-locks') { var old = state.expanded; state.expanded = 0; draw(old); }
      if (action.dataset.legAction === 'reload-locks') loadLocks(state.expanded, true);
      if (action.dataset.legAction === 'save-waypoints') {
        var panel = action.closest('.fpw-routegen__leglockpanel[data-leg-order]');
        if (panel) saveLegWaypoints(Number(panel.dataset.legOrder));
      }
      return;
    }
    var row = event.target.closest('.fpw-routegen__leg[data-leg-order]');
    if (!row) return;
    var order = Number(row.dataset.legOrder);
    state.selected = order;
    state.expanded = state.expanded === order ? 0 : order;
    draw(order);
    loadLocks(state.expanded);
    if (state.expanded) trackInteraction('great_loop_leg_expanded', 'leg_list');
  }
  list.addEventListener('click', select);
  list.addEventListener('keydown', function (event) {
    if ((event.key === 'Enter' || event.key === ' ') && event.target.matches('.fpw-routegen__leg[data-leg-order]')) { event.preventDefault(); select(event); }
  });
  recalculate();
})(window);
