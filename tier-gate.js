(function() {
  let features = [];
  try {
    features = JSON.parse(localStorage.getItem('rc_features') || '[]');
  } catch(e) { features = []; }

  const pageToFeature = {
    'bookings.html': 'bookings',
    'leads.html': 'leads',
    'block-dates.html': 'block_dates',
    'calendar.html': 'calendar',
    'units.html': 'units',
    'minibar.html': 'minibar',
    'hero-slides.html': 'hero_slides',
    'promo-banners.html': 'promo_banners',
    'promotion.html': 'promotion',
    'reviews.html': 'reviews',
    'experiences.html': 'experiences',
    'invoice.html': 'invoice',
    'finance.html': 'finance',
    'reports.html': 'reports',
    'petty-cash.html': 'petty_cash',
    'staff-payroll.html': 'staff_payroll',
    'dashboard.html': 'dashboard',
    'settings.html': 'settings'
  };

  document.querySelectorAll('a.nav-item').forEach(a => {
    const href = a.getAttribute('href');
    const featureKey = pageToFeature[href];
    // view-site-link has no static href match (uses '#'), always shown if 'view_site' is in features
    if (a.id === 'view-site-link') {
      if (!features.includes('view_site')) a.style.display = 'none';
      return;
    }
    if (featureKey && !features.includes(featureKey)) {
      a.style.display = 'none';
    }
  });

  // Hide any section header left with zero visible items before the next section
  const nav = document.querySelector('.sidebar-nav');
  if (nav) {
    const children = Array.from(nav.children);
    children.forEach((el, i) => {
      if (el.classList.contains('nav-section')) {
        let hasVisibleItem = false;
        for (let j = i + 1; j < children.length; j++) {
          if (children[j].classList.contains('nav-section')) break;
          if (children[j].style.display !== 'none') { hasVisibleItem = true; break; }
        }
        el.style.display = hasVisibleItem ? '' : 'none';
      }
    });
  }
})();
