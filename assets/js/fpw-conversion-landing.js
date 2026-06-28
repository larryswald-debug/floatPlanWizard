(function () {
  'use strict';

  var previews = {
    route: {
      title: 'Build your route',
      body: 'Plan your trip with waypoints, estimated timing, and important details — all on an easy-to-use map.',
      bullets: ['Real destinations & waypoints', 'Estimated arrival times', 'Distance & duration estimates', 'Save and adjust anytime'],
      link: 'Try the Route Builder',
      href: '#fpwProductPreview'
    },
    floatplan: {
      title: 'Create the float plan',
      body: 'Turn your route into a clean trip plan that can be saved, printed, and shared with the person watching from shore.',
      bullets: ['Trip details in one place', 'Captain and vessel information', 'Printable and shareable plan', 'Clear plan for your shore contact'],
      link: 'Create a Float Plan',
      href: '#fpwProductPreview'
    },
    active: {
      title: 'Keep the trip current',
      body: 'Start Active Cruise when you leave and use structured check-ins and timing updates while underway.',
      bullets: ['Check in during the trip', 'Update timing when plans change', 'Track next expected check-in', 'Close the plan when you return'],
      link: 'See Active Cruise',
      href: '#fpwProductPreview'
    },
    follow: {
      title: 'Share a private follow page',
      body: 'Give your shore contact a simple page with the trip details they need, without requiring them to create an account.',
      bullets: ['Private link sharing', 'Shore contacts do not need an account', 'Simple trip status view', 'Useful details without app clutter'],
      link: 'View Sample Trip Page',
      href: '#fpwProductPreview'
    }
  };

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
      item.classList.toggle('is-open');
    });
  });
})();
