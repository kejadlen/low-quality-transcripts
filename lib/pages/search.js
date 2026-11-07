const instance = window.PagefindComponents.getInstanceManager().getInstance('default');
const sortSelect = document.getElementById('sort-select');
let sortConfig = null;

function applySort(value) {
  sortConfig = value ? { episode_number: value } : null;
  instance.triggerSearch(instance.searchTerm || '');
}

instance.on('results', () => {
  const pf = instance.__pagefind__;
  if (pf && !pf._sortPatched) {
    const orig = pf.search.bind(pf);
    pf.search = (term, opts = {}) => orig(term, sortConfig ? { ...opts, sort: sortConfig } : opts);
    pf._sortPatched = true;
  }
});

sortSelect.addEventListener('change', (e) => applySort(e.target.value));

let searchTimer;
instance.on('results', () => {
  const term = instance.searchTerm;
  if (!term) return;
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    window.goatcounter?.count({ path: 'search:' + term, title: 'Search: ' + term, event: true });
  }, 800);
});
