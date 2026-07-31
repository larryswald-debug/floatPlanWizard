(function () {
  'use strict';

  var previews = {
    route: {
      image: 'preview-route-generator.jpg',
      alt: 'FloatPlanWizard route generator showing a planned boating route with waypoints.',
      title: 'Plan the route before you leave.',
      body: 'Build route legs and waypoints, organize stops and timing, and estimate the time and fuel behind the trip.',
      bullets: ['Plan route legs, stops, and waypoints', 'Estimate time, distance, and fuel', 'Use the route in the float plan and Trip Page'],
      link: 'Plan Your Trip'
    },
    active: {
      image: 'preview-active-cruise.jpg',
      alt: 'Representative FloatPlanWizard Active Cruise view showing trip status, check-in, and route-management controls.',
      title: 'Manage your trip underway.',
      body: 'Check in, record delays or changed plans, mark secure for the night, and manage route legs as the cruise progresses.',
      bullets: ['Report On Track, Delayed, or Changed Plan', 'Manage route legs and overnight status', 'Stay on schedule with expected check-ins'],
      link: 'Plan Your Trip'
    },
    follow: {
      image: 'preview-follow-page.png',
      alt: 'Representative FloatPlanWizard private Trip Page showing a planned route, estimated trip progress, and latest check-in.',
      title: 'Share the journey.',
      body: 'Friends and family can use one invitation link to see the planned route, stops, estimated trip progress, latest check-in, and trip updates.',
      bullets: ['Only people you invite can view the trip   ', 'No FPW account needed for followers', 'Latest check-ins, updates, photos, and comments'],
      link: 'Plan Your Trip'
    },
    dashboard: {
      image: 'preview-dashboard.jpg',
      alt: 'FloatPlanWizard dashboard showing saved routes, trip setup readiness, and boating tools.',
      title: 'Your planning and trip-management home base.',
      body: 'Review routes, float plans, trip readiness, weather, check-ins, and active-trip tools from one dashboard.',
      bullets: ['Saved routes and float plans', 'Trip setup and readiness', 'Weather, check-in, and Active Cruise tools'],
      link: 'Plan Your Trip'
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

  function selectPreview(root, key) {
    var tabs = Array.prototype.slice.call(root.querySelectorAll('[data-preview-tab]'));
    var selectedTab = root.querySelector('[data-preview-tab="' + key + '"]');

    tabs.forEach(function (tab) {
      tab.setAttribute('aria-selected', 'false');
    });

    if (selectedTab) {
      selectedTab.setAttribute('aria-selected', 'true');
    }

    setPreview(root, key);
    return selectedTab;
  }

  document.querySelectorAll('.fpw-preview-shell').forEach(function (root) {
    var tabs = Array.prototype.slice.call(root.querySelectorAll('[data-preview-tab]'));

    tabs.forEach(function (button) {
      button.addEventListener('click', function () {
        selectPreview(root, button.getAttribute('data-preview-tab'));
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

  document.querySelectorAll('[data-fpw-open-preview]').forEach(function (link) {
    link.addEventListener('keydown', function (event) {
      if (event.key !== 'Enter' && event.key !== ' ') return;

      event.preventDefault();
      link.click();
    });

    link.addEventListener('click', function (event) {
      var root = document.querySelector('.fpw-preview-shell');
      if (!root) return;

      event.preventDefault();

      var key = link.getAttribute('data-fpw-open-preview') || 'follow';
      var selectedTab = selectPreview(root, key);
      var section = root.closest('.fpw-product-preview') || root;
      var reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

      if (event.detail === 0 && selectedTab) {
        selectedTab.focus({ preventScroll: true });
      }

      section.scrollIntoView({
        behavior: reduceMotion ? 'auto' : 'smooth',
        block: 'start'
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
