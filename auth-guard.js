(function() {
  const originalFetch = window.fetch;
  window.fetch = function(...args) {
    return originalFetch.apply(this, args).then(function(res) {
      if (res.status === 401) {
        localStorage.clear();
        window.location.href = 'index.html';
      }
      return res;
    });
  };
})();
