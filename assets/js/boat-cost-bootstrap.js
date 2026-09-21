/* Runs synchronously before any analytics on this page. Never logs URL content. */
(function (window) {
  'use strict';
  var fragment = window.location.hash || '';
  var clean = false;
  try {
    window.history.replaceState(null, '', window.location.pathname);
    clean = !window.location.hash && !window.location.search;
  } catch (err) { /* Keep tracking and sharing disabled if URL cleanup fails. */ }
  window.FPWBoatCostBootstrap = { fragment: fragment, clean: clean };
  // Reserve initial screen space only when JavaScript is available.
  window.document.documentElement.classList.add('bc-js');
  window.FPWAnalytics = window.FPWAnalytics || {};
  // The shared helper respects an existing track function. No shared file changes.
  window.FPWAnalytics.track = function (name, fields) {
    if (!window.FPWBoatCostBootstrap.clean || !window.FPWBoatCostState || !window.FPWBoatCostAnalyticsReady) return;
    var safe = window.FPWBoatCostState.sanitizeEvent(name, fields);
    if (safe && typeof window.plausible === 'function') {
      window.plausible(safe.name, { props: safe.params, url: 'https://floatplanwizard.com/boat-loan-calculator/' });
    }
  };
}(window));
