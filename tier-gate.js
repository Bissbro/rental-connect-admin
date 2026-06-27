(function() {
  const plan = localStorage.getItem('rc_plan') || 'guesthouse';

  // Pages only visible to guesthouse tier
  const guesthouseOnly = ['minibar.html', 'staff-payroll.html'];

  // Pages visible to rental_business AND guesthouse (hidden for homestay)
  const businessAndUp = ['leads.html', 'petty-cash.html', 'promotion.html', 'hero-slides.html', 'promo-banners.html', 'reviews.html', 'experiences.html'];

  let toHide = [];
  if (plan === 'homestay') {
    toHide = guesthouseOnly.concat(businessAndUp);
  } else if (plan === 'rental_business') {
    toHide = guesthouseOnly;
  }

  function hideNavLink(href) {
    document.querySelectorAll('a.nav-item').forEach(a => {
      if (a.getAttribute('href') === href) a.style.display = 'none';
    });
  }

  toHide.forEach(hideNavLink);

  // After hiding items, hide any section header followed by zero visible items before the next section
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
