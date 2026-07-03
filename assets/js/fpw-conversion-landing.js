(function () {
  'use strict';

  var previews = {
    route: {
      title: 'Build the route before you go.',
      body: 'Add waypoints, estimate timing, and turn the trip into a plan someone ashore can actually follow.',
      bullets: ['Plan by route legs and stops', 'Estimate distance and timing', 'Use the route inside your float plan'],
      link: 'Try the Route Builder',
      href: '#Try the Route Builder'
    },
    floatplan: {
      title: 'Create the plan people may need later.',
      body: 'Capture the boat, passengers, contacts, route, and expected return in one organized plan.',
      bullets: ['Boat and passenger details', 'Emergency contacts', 'Printable and shareable format'],
      link: 'Create a Float Plan',
      href: '#fpwProductPreview'
    },
    active: {
      title: 'Keep the plan current underway.',
      body: 'Use check-ins and trip updates so the plan does not become stale once the boat leaves the dock.',
      bullets: ['Update trip status', 'Track timing changes', 'Support overdue awareness'],
      link: 'See Active Cruise',
      href: '#fpwProductPreview'
    },
    follow: {
      title: 'Give your shore contact a private trip page.',
      body: 'Share useful trip details without requiring your family or friend to create an account.',
      bullets: ['No shore-contact account required', 'Private shareable access', 'Clear trip status and timing'],
      link: 'View Sample Trip Page',
      href: '#fpwProductPreview'
    }
  };

  function trackEvent(name, params) {
    params = params || {};

    try {
      if (!name) return;

      if (window.FPWAnalytics && typeof window.FPWAnalytics.track === 'function' && typeof window.gtag === 'function') {
        window.FPWAnalytics.track(name, params);
        return;
      }

      if (typeof window.gtag === 'function') {
        window.gtag('event', name, params);
        return;
      }

      if (Array.isArray(window.dataLayer)) {
        var payload = { event: name };
        Object.keys(params).forEach(function (key) {
          payload[key] = params[key];
        });
        window.dataLayer.push(payload);
      }
    } catch (error) {}
  }

  document.addEventListener('click', function (event) {
    var target = event.target.closest('[data-fpw-track]');
    if (!target) return;

    trackEvent(target.getAttribute('data-fpw-track'), {
      label: target.getAttribute('data-fpw-track-label') || '',
      plan: target.getAttribute('data-fpw-track-plan') || '',
      section: target.getAttribute('data-fpw-track-section') || 'homepage'
    });
  });

  function setPreview(root, key) {
    var data = previews[key] || previews.route;
    var title = root.querySelector('[data-preview-title]');
    var body = root.querySelector('[data-preview-body]');
    var list = root.querySelector('[data-preview-list]');
    var link = root.querySelector('[data-preview-link]');

    if (title) title.textContent = data.title;
    if (body) body.textContent = data.body;
    if (link) {
      link.href = data.href;
      link.innerHTML = data.link + ' <svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-arrow"></use></svg>';
    }
    if (list) {
      list.innerHTML = data.bullets.map(function (item) {
        return '<li><span class="fpw-check-dot">✓</span><span>' + item + '</span></li>';
      }).join('');
    }
  }

  document.querySelectorAll('.fpw-preview-shell').forEach(function (root) {
    root.querySelectorAll('[data-preview-tab]').forEach(function (button) {
      button.addEventListener('click', function () {
        root.querySelectorAll('[data-preview-tab]').forEach(function (tab) {
          tab.setAttribute('aria-selected', 'false');
        });
        button.setAttribute('aria-selected', 'true');
        setPreview(root, button.getAttribute('data-preview-tab'));
      });
    });
  });

  document.querySelectorAll('.fpw-faq-question').forEach(function (button) {
    button.addEventListener('click', function () {
      var item = button.closest('.fpw-faq-item');
      if (!item) return;

      var isOpen = item.classList.toggle('is-open');
      button.setAttribute('aria-expanded', isOpen ? 'true' : 'false');

      if (isOpen) {
        trackEvent('homepage_faq_open', {
          label: button.getAttribute('data-fpw-track-label') || button.textContent.trim(),
          section: 'faq'
        });
      }
    });
  });
})();
