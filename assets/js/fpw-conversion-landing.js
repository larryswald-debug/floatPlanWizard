(function () {
  'use strict';

  var previews = {
    route: {
      image: 'preview-route-generator.jpg',
      alt: 'FloatPlanWizard route generator showing a planned boating route with waypoints.',
      title: 'Build the route before you go.',
      body: 'Add stops, estimate timing, and turn the trip into a plan someone ashore can actually follow.',
      bullets: ['Plan by route legs and waypoints', 'Estimate distance and arrival times', 'Use the route inside your float plan', 'Estimate fuel usage and cost'],
      link: 'Start Planning'
    },
    active: {
      image: 'preview-active-cruise.jpg',
      alt: 'FloatPlanWizard Active Cruise screen showing live trip tools and monitoring controls.',
      title: 'Keep the trip current while underway.',
      body: 'When timing changes, update the active trip without rebuilding the plan from scratch.',
      bullets: ['Track the active route', 'Adjust delays and timing', 'Keep monitoring aligned with the real trip'],
      link: 'Start a Live Trip'
    },
    follow: {
      image: 'preview-follow-page.jpg',
      alt: 'FloatPlanWizard shared trip status page showing a private trip status view for family and friends.',
      title: 'Give family a private trip page.',
      body: 'Share one private link so family or friends can see the plan, route, and trip status without needing an account.',
      bullets: ['Private trip status page', 'No login needed for followers', 'Better than scattered text messages'],
      link: 'Share a Trip Page'
    },
    dashboard: {
      image: 'preview-dashboard.jpg',
      alt: 'FloatPlanWizard dashboard showing saved routes, trip setup readiness, and boating tools.',
      title: 'Manage the whole trip from one place.',
      body: 'Review routes, float plans, trip setup, monitoring, weather, and cruise tools from one clean dashboard.',
      bullets: ['Saved routes and float plans', 'Trip setup readiness', 'Weather and monitoring tools'],
      link: 'Create Your Account'
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

  function getPreviewImageSrc(root, imageName) {
    var base = root.getAttribute('data-preview-asset-base') || '/assets/images/home/';
    if (base.charAt(base.length - 1) !== '/') {
      base += '/';
    }
    return base + imageName;
  }

  function setPreview(root, key) {
    var data = previews[key] || previews.route;
    var title = root.querySelector('[data-preview-title]');
    var body = root.querySelector('[data-preview-body]');
    var list = root.querySelector('[data-preview-list]');
    var link = root.querySelector('[data-preview-link]');
    var image = root.querySelector('[data-preview-image]');
    var panel = root.querySelector('[role="tabpanel"]');
    var selectedTab = root.querySelector('[data-preview-tab="' + key + '"]');

    if (title) title.textContent = data.title;
    if (body) body.textContent = data.body;
    if (image) {
      image.src = getPreviewImageSrc(root, data.image);
      image.alt = data.alt;
    }
    if (link) {
      link.innerHTML = data.link + ' <svg class="fpw-icon" aria-hidden="true"><use href="#fpw-i-arrow"></use></svg>';
    }
    if (panel && selectedTab && selectedTab.id) {
      panel.setAttribute('aria-labelledby', selectedTab.id);
    }
    if (list) {
      list.innerHTML = data.bullets.map(function (item) {
        return '<li><span class="fpw-check-dot">✓</span><span>' + item + '</span></li>';
      }).join('');
    }
  }

  document.querySelectorAll('.fpw-preview-shell').forEach(function (root) {
    var tabs = Array.prototype.slice.call(root.querySelectorAll('[data-preview-tab]'));

    tabs.forEach(function (button) {
      button.addEventListener('click', function () {
        tabs.forEach(function (tab) {
          tab.setAttribute('aria-selected', 'false');
        });
        button.setAttribute('aria-selected', 'true');
        setPreview(root, button.getAttribute('data-preview-tab'));
      });

      button.addEventListener('keydown', function (event) {
        var currentIndex = tabs.indexOf(button);
        var nextIndex = currentIndex;

        if (event.key === 'ArrowRight') nextIndex = (currentIndex + 1) % tabs.length;
        if (event.key === 'ArrowLeft') nextIndex = (currentIndex - 1 + tabs.length) % tabs.length;
        if (event.key === 'Home') nextIndex = 0;
        if (event.key === 'End') nextIndex = tabs.length - 1;
        if (nextIndex === currentIndex) return;

        event.preventDefault();
        tabs[nextIndex].focus();
        tabs[nextIndex].click();
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
