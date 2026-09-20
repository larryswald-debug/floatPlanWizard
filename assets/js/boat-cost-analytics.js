/* Reuses FPW's Plausible site and analytics wrapper, with a page-local privacy policy. */
(function (window, document) {
  'use strict';
  var bootstrap = window.FPWBoatCostBootstrap;
  if (!bootstrap || !bootstrap.clean || !window.FPWBoatCostState) return;
  if (window.navigator.doNotTrack === '1' || window.navigator.globalPrivacyControl === true) return;
  try { if (window.localStorage.getItem('plausible_ignore') === 'true') return; } catch (err) {}
  var canonical = 'https://floatplanwizard.com/boat-loan-calculator/';
  window.plausible = window.plausible || function () { (window.plausible.q = window.plausible.q || []).push(arguments); };
  window.plausible.init = window.plausible.init || function (options) { window.plausible.o = options; };
  window.plausible.init({
    autoCapturePageviews: false,
    outboundLinks: false,
    fileDownloads: false,
    formSubmissions: false,
    hashBasedRouting: false,
    logging: false,
    transformRequest: function (payload) {
      if (!window.FPWBoatCostBootstrap.clean) return null;
      var safe = payload.n === 'pageview' ? { name: 'pageview', params: {} } : window.FPWBoatCostState.sanitizeEvent(payload.n, payload.p);
      if (!safe) return null;
      // Reconstruct instead of merging: strip URL, referrer and all unexpected fields.
      return { n: safe.name, u: canonical, d: 'floatplanwizard.com', r: null, p: safe.params, v: payload.v };
    }
  });
  window.FPWBoatCostAnalyticsReady = true;
  window.plausible('pageview', { url: canonical });
  var script = document.createElement('script');
  script.async = true;
  script.referrerPolicy = 'no-referrer';
  script.src = 'https://plausible.io/js/pa-RzmzzpwAcdcGg_-4y94nc.js';
  document.head.appendChild(script);
}(window, document));
